//
//  HSWindowRegistry.swift
//  Hammerspoon 2
//

import Foundation
import AppKit
import ApplicationServices
import AXSwift

// No-op C callback used only by the AXObserverCreate probe in
// installObserver(for:). AXObserverCreate expects an @convention(c) function
// pointer; a `let` of typealias `AXObserverCallback` satisfies the bridge.
private let axProbeCallback: AXObserverCallback = { _, _, _, _ in }

/// Long-lived, in-memory cache of running apps and their windows, maintained
/// by NSWorkspace notifications and per-app AXObservers. The switcher reads
/// snapshots from here on the hot path — no AX calls at trigger time.
///
/// Process-wide singleton: running apps are global OS state, not per-engine.
/// This also lets `hs.switcher` access the registry without depending on JS
/// having touched `hs.window` first (which would leave it un-instantiated).
@MainActor
final class HSWindowRegistry {
    static let shared = HSWindowRegistry()

    private var appsByPid: [pid_t: HSAppEntry] = [:]
    private var appMRU: [pid_t] = []          // most-recent first
    private var nextWindowID: UInt64 = 1
    private var nsObservers: [NSObjectProtocol] = []
    private let seedQueue = DispatchQueue(label: "hs.window.registry.seed", qos: .userInitiated)

    init() {
        installWorkspaceObservers()
        seedInitialApps()
    }

    // MARK: - Snapshot (hot path; no AX, no blocking work)

    /// Returns the current MRU-ordered list of apps with their windows. Reads
    /// directly from cache; safe to call at picker-trigger time.
    func snapshot() -> [HSAppEntry] {
        return appMRU.compactMap { appsByPid[$0] }
    }

    // MARK: - Workspace observers

    private func installWorkspaceObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        // Extract pid/app from the notification on the delivery thread (queue: .main),
        // then hop into the MainActor with just Sendable values. This avoids the
        // Swift 6 "sending Notification risks data races" error.
        nsObservers.append(nc.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notif in
            let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let app else { return }
            let pid = app.processIdentifier
            Task { @MainActor [weak self] in self?.addAppFromPid(pid) }
        })
        nsObservers.append(nc.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notif in
            let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let app else { return }
            let pid = app.processIdentifier
            Task { @MainActor [weak self] in self?.removeApp(pid: pid) }
        })
        nsObservers.append(nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notif in
            let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let app else { return }
            let pid = app.processIdentifier
            Task { @MainActor [weak self] in self?.markActivated(pid: pid) }
        })
    }

    /// Re-resolve the NSRunningApplication on main actor (Sendable trampoline
    /// for the workspace observers).
    private func addAppFromPid(_ pid: pid_t) {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        addApp(app)
    }

    // MARK: - App mutations

    private func addApp(_ runningApp: NSRunningApplication) {
        let pid = runningApp.processIdentifier
        guard appsByPid[pid] == nil else { return }
        guard runningApp.activationPolicy != .prohibited else { return }
        let entry = HSAppEntry(runningApp: runningApp)
        appsByPid[pid] = entry
        appMRU.append(pid)
        installObserver(for: entry)
        seedWindows(for: entry)
    }

    private func removeApp(pid: pid_t) {
        if let entry = appsByPid[pid] {
            entry.observer?.stop()
            entry.observer = nil
            entry.pollTimer?.invalidate()
            entry.pollTimer = nil
        }
        appsByPid.removeValue(forKey: pid)
        appMRU.removeAll { $0 == pid }
    }

    private func markActivated(pid: pid_t) {
        guard let entry = appsByPid[pid] else { return }
        entry.lastActivatedAt = Date()
        appMRU.removeAll { $0 == pid }
        appMRU.insert(pid, at: 0)
    }

    // MARK: - Boot seed

    private func seedInitialApps() {
        let running = NSWorkspace.shared.runningApplications
        for app in running where app.activationPolicy != .prohibited {
            addApp(app)
        }
        if let front = NSWorkspace.shared.frontmostApplication {
            markActivated(pid: front.processIdentifier)
        }
    }

    // MARK: - Window ID minting

    func mintWindowID() -> UInt64 {
        defer { nextWindowID &+= 1 }
        return nextWindowID
    }

    // MARK: - AXObserver

    private func installObserver(for entry: HSAppEntry) {
        // Pre-flight: AXSwift's `Observer.init` is a throwing initializer that
        // assigns `self.axObserver` *before* the throw, so when AXObserverCreate
        // fails the object is considered fully initialized — Swift then runs
        // `deinit → stop()`, which dereferences the (nil) AXObserver! IUO and
        // crashes via assertion. The most common trigger is a freshly-deployed
        // ad-hoc-signed build whose cdhash changed, so macOS hasn't re-granted
        // Accessibility yet. Probe AXObserverCreate ourselves first; on any
        // failure, go straight to the poll fallback without ever letting the
        // broken AXSwift init run.
        var probe: AXObserver?
        let probeErr = unsafe AXObserverCreate(entry.pid, axProbeCallback, &probe)
        guard probeErr == .success, probe != nil else {
            AKTrace("AXObserverCreate probe failed for pid \(entry.pid) (\(entry.name)): \(probeErr); falling back to polled refresh")
            installPollFallback(for: entry)
            return
        }
        probe = nil   // discard; AXSwift will create its own below

        do {
            let observer = try Observer(processID: entry.pid) { [weak self, weak entry] _, element, notif in
                MainActor.assumeIsolated {
                    guard let self, let entry else { return }
                    self.handleAXEvent(entry: entry, element: element, notification: notif)
                }
            }
            guard let axApp = Application(forProcessID: entry.pid) else {
                observer.stop()
                return
            }
            AXUIElementSetMessagingTimeout(axApp.element, 0.1)
            try? observer.addNotification(.windowCreated, forElement: axApp)
            try? observer.addNotification(.focusedWindowChanged, forElement: axApp)
            entry.observer = observer
        } catch {
            AKTrace("AXObserverCreate failed for pid \(entry.pid) (\(entry.name)): \(error); falling back to polled refresh")
            installPollFallback(for: entry)
        }
    }

    private func handleAXEvent(entry: HSAppEntry, element: UIElement, notification: UIElement.AXNotification) {
        switch notification {
        case .windowCreated:
            AXUIElementSetMessagingTimeout(element.element, 0.1)
            addWindow(element, to: entry)
            try? entry.observer?.addNotification(.uiElementDestroyed, forElement: element)
            try? entry.observer?.addNotification(.titleChanged, forElement: element)

        case .uiElementDestroyed:
            removeWindow(matching: element, from: entry)

        case .titleChanged:
            if let win = entry.windows.first(where: { $0.axElement.element == element.element }) {
                let newTitle: String? = try? element.attribute(.title)
                win.title = newTitle ?? win.title
            }

        case .focusedWindowChanged:
            bumpWindowMRU(matching: element, in: entry)

        default:
            break
        }
    }

    // MARK: - Window mutations

    private func addWindow(_ element: UIElement, to entry: HSAppEntry) {
        if entry.windows.contains(where: { $0.axElement.element == element.element }) { return }
        let title: String = (try? element.attribute(.title)) ?? ""
        let win = HSWindowEntry(stableID: mintWindowID(), axElement: element, title: title)
        entry.windows.insert(win, at: 0)
    }

    private func removeWindow(matching element: UIElement, from entry: HSAppEntry) {
        entry.windows.removeAll { $0.axElement.element == element.element }
    }

    private func bumpWindowMRU(matching element: UIElement, in entry: HSAppEntry) {
        guard let idx = entry.windows.firstIndex(where: { $0.axElement.element == element.element }) else { return }
        let win = entry.windows.remove(at: idx)
        win.lastFocusedAt = Date()
        entry.windows.insert(win, at: 0)
    }

    // MARK: - Window seeding (initial AX query off-main; results applied on main)

    private func seedWindows(for entry: HSAppEntry) {
        let pid = entry.pid
        seedQueue.async { [weak self] in
            guard let axApp = Application(forProcessID: pid) else { return }
            AXUIElementSetMessagingTimeout(axApp.element, 0.1)
            let windows: [UIElement] = (try? axApp.windows()) ?? []
            let seeded: [(UIElement, String)] = windows.map { w in
                AXUIElementSetMessagingTimeout(w.element, 0.1)
                let t: String? = (try? w.attribute(.title))
                return (w, t ?? "")
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.applySeed(pid: pid, seeded: seeded)
                }
            }
        }
    }

    private func applySeed(pid: pid_t, seeded: [(UIElement, String)]) {
        guard let entry = appsByPid[pid] else { return }
        for (element, title) in seeded {
            if entry.windows.contains(where: { $0.axElement.element == element.element }) { continue }
            let win = HSWindowEntry(stableID: mintWindowID(), axElement: element, title: title)
            entry.windows.append(win)
            try? entry.observer?.addNotification(.uiElementDestroyed, forElement: element)
            try? entry.observer?.addNotification(.titleChanged, forElement: element)
        }
    }

    // MARK: - Polled fallback for AX-hostile apps

    private func installPollFallback(for entry: HSAppEntry) {
        entry.pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self, weak entry] _ in
            MainActor.assumeIsolated {
                guard let self, let entry else { return }
                self.seedWindows(for: entry)
            }
        }
    }
}
