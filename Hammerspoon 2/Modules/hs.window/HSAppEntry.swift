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
    var icon: NSImage?
    var windows: [HSWindowEntry]      // MRU-ordered, most-recent first
    var lastActivatedAt: Date
    var observer: Observer?           // nil if AXObserverCreate failed for this pid
    var pollTimer: Timer?             // non-nil only when using the polled fallback

    init(runningApp: NSRunningApplication) {
        self.pid = runningApp.processIdentifier
        self.name = runningApp.localizedName ?? "Unknown"
        self.bundleID = runningApp.bundleIdentifier
        self.icon = runningApp.icon
        self.windows = []
        self.lastActivatedAt = Date()
        self.observer = nil
        self.pollTimer = nil
    }

    #if DEBUG
    /// Test-only init for state-machine unit tests that don't need a real
    /// NSRunningApplication.
    init(testOnlyName: String, pid: pid_t) {
        self.pid = pid
        self.name = testOnlyName
        self.bundleID = nil
        self.icon = nil
        self.windows = []
        self.lastActivatedAt = Date()
        self.observer = nil
        self.pollTimer = nil
    }
    #endif
}
