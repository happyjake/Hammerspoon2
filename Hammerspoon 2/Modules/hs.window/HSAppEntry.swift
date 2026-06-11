//
//  HSAppEntry.swift
//  Hammerspoon 2
//

import Foundation
import AppKit
import AXSwift

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
    var lastActivatedAt: Date
    var observer: Observer?           // nil if AXObserverCreate failed for this pid
    var pollTimer: Timer?             // non-nil only when using the polled fallback

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
    }

    /// A display copy for the switcher with un-pickable windows removed —
    /// windows with no usable title (the Finder desktop, an app's ghost/helper
    /// surfaces) would otherwise show as "(untitled)" rows you can't identify.
    /// Filtering here (not in the registry) keeps `hs.window.snapshot()` whole
    /// and happens at display time, where titles have loaded — unlike seed time,
    /// where a real window's title can still be empty.
    func switcherDisplayCopy() -> HSAppEntry {
        let titled = windows.filter {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return HSAppEntry(copyingMetadataFrom: self, windows: titled)
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
