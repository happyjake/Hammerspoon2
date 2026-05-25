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
