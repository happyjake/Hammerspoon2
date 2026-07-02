//
//  HSAppEntry.swift
//  Hammerspoon 2
//

import Foundation
import AppKit
import AXSwift

/// One browser tab shown by hs.switcher under its browser app, next to the
/// window rows. Display data only: it is attached to switcher *display
/// copies* (never to live registry entries), and committing one is handled
/// by the JS side (AppleScript), not by AX.
struct HSSwitcherTab {
    let title: String
    let url: String
    let windowIndex: Int    // AppleScript window index within the browser
    let tabIndex: Int       // AppleScript tab index within that window
}

/// One app inside the live registry. Holds the AXObserver subscription for that
/// app's window lifecycle events.
@MainActor
final class HSAppEntry {
    let pid: pid_t
    let name: String
    let bundleID: String?
    let activationPolicy: NSApplication.ActivationPolicy
    var icon: NSImage?
    var windows: [HSWindowEntry]      // MRU-ordered, most-recent first
    /// Browser tabs for the switcher, populated only on `switcherDisplayCopy()`
    /// results by hs.switcher's tabsProvider. Always empty on registry entries.
    var switcherTabs: [HSSwitcherTab] = []
    var lastActivatedAt: Date
    var observer: Observer?           // nil if AXObserverCreate failed for this pid
    var pollTimer: Timer?             // non-nil only when using the polled fallback
    /// Remaining re-seed attempts for an app whose window list seeded empty.
    /// A cold a11y server (Gecko creates its engine lazily, on the first AX
    /// query) returns nothing under the seed timeout — and that first failed
    /// query is what wakes the engine, so a bounded retry usually harvests.
    var seedRetriesLeft = 2

    init(runningApp: NSRunningApplication) {
        self.pid = runningApp.processIdentifier
        self.name = runningApp.localizedName ?? "Unknown"
        self.bundleID = runningApp.bundleIdentifier
        self.activationPolicy = runningApp.activationPolicy
        self.icon = runningApp.icon
        self.windows = []
        self.lastActivatedAt = Date()
        self.observer = nil
        self.pollTimer = nil
    }

    /// True for "switchable" apps — i.e. ones a cmd+Tab-style picker should
    /// include. Matches cmd+Tab default: regular apps only (excludes
    /// accessory / menu-bar utilities, system helpers like loginwindow /
    /// WindowManager / Notification Center, etc.) and excludes Hammerspoon
    /// 2 itself (the switcher's own host process).
    var isSwitchable: Bool {
        if activationPolicy != .regular { return false }
        if pid == ProcessInfo.processInfo.processIdentifier { return false }
        return true
    }

    /// Metadata-only copy with a caller-supplied window list. Reuses the
    /// original `HSWindowEntry` references (so commit still targets the real
    /// window) and drops the AX subscription/timer (a display copy owns nothing).
    private init(copyingMetadataFrom other: HSAppEntry, windows: [HSWindowEntry]) {
        self.pid = other.pid
        self.name = other.name
        self.bundleID = other.bundleID
        self.activationPolicy = other.activationPolicy
        self.icon = other.icon
        self.windows = windows
        self.lastActivatedAt = other.lastActivatedAt
        self.observer = nil
        self.pollTimer = nil
        self.seedRetriesLeft = 0
    }

    /// A display copy for the switcher with un-pickable windows removed.
    /// Ghost surfaces (an app's helper windows, the host's own overlays) show
    /// up as untitled windows whose subrole never positively read — drop those.
    /// But a real main window can be genuinely untitled (WeChat's is) while its
    /// subrole DID read `.standardWindow`; that one must stay pickable, so the
    /// filter is: keep a window if it has a usable title OR a positively-read
    /// standard subrole. Filtering here (not in the registry) keeps
    /// `hs.window.snapshot()` whole and happens at display time, where stale
    /// seed-time reads have had every chance to heal.
    func switcherDisplayCopy() -> HSAppEntry {
        let pickable = windows.filter {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || $0.subrole == .standardWindow
        }
        return HSAppEntry(copyingMetadataFrom: self, windows: pickable)
    }

    #if DEBUG
    /// Test-only init for state-machine unit tests that don't need a real
    /// NSRunningApplication.
    init(testOnlyName: String, pid: pid_t) {
        self.pid = pid
        self.name = testOnlyName
        self.bundleID = nil
        self.activationPolicy = .regular
        self.icon = nil
        self.windows = []
        self.lastActivatedAt = Date()
        self.observer = nil
        self.pollTimer = nil
    }
    #endif
}
