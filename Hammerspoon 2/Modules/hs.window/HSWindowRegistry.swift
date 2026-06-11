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
            if addWindow(element, to: entry) {
                try? entry.observer?.addNotification(.uiElementDestroyed, forElement: element)
                try? entry.observer?.addNotification(.titleChanged, forElement: element)
            }

        case .uiElementDestroyed:
            removeWindow(matching: element, from: entry)

        case .titleChanged:
            if let win = entry.windows.first(where: { $0.axElement.element == element.element }) {
                let newTitle: String? = try? element.attribute(.title)
                win.title = newTitle ?? win.title
            }

        case .focusedWindowChanged:
            // The focused element is ground truth: if the registry doesn't know
            // this window (its app seeded cold and the retries lost the race
            // too), adopt it now instead of just failing the MRU bump. The app
            // is frontmost, so its a11y server is warm and the reads are cheap.
            if !entry.windows.contains(where: { $0.axElement.element == element.element }) {
                AXUIElementSetMessagingTimeout(element.element, 0.1)
                if addWindow(element, to: entry) {
                    AKTrace("hs.window registry: adopted focused window of \(entry.name) (missed at seed)")
                    try? entry.observer?.addNotification(.uiElementDestroyed, forElement: element)
                    try? entry.observer?.addNotification(.titleChanged, forElement: element)
                }
            }
            bumpWindowMRU(matching: element, in: entry)

        default:
            break
        }
    }

    // MARK: - Window mutations

    /// The registry feeds switchers, and a switcher only ever targets
    /// standard windows. Finder's desktop window, Firefox's hidden helper
    /// window, sheets, tooltips and similar AX flotsam report a different
    /// subrole (or none) and would surface as phantom "(untitled)" rows in
    /// the picker — keep them out of the registry entirely. Real windows
    /// that merely have an empty title (e.g. WeChat's main window) are
    /// AXStandardWindow and stay. Every skip is traced so a wrongly-dropped
    /// window can be diagnosed from the console.
    /// Pure switchability decision, extracted so it can be unit-tested without
    /// AX. See `isSwitchableSubrole` for the rationale.
    private func isSwitchableWindow(subrole: Role.Subrole?, appName: String, title: String) -> Bool {
        let ok = Self.isSwitchableSubrole(subrole)
        if !ok {
            AKTrace("hs.window registry: skipping \(appName) window (subrole=\(subrole?.rawValue ?? "none"), title=\"\(title)\")")
        }
        return ok
    }

    /// Whether a window with this subrole should be tracked as a switch target.
    ///
    /// Fails OPEN: a window is switchable unless its subrole *positively*
    /// identifies a non-window surface. This is deliberate — `.subrole` reads
    /// are unreliable during startup seeding (they run on a background queue
    /// under a 0.1s AX messaging timeout and return `nil` under the launch
    /// storm), and a real window's subrole only resolves to `.standardWindow`
    /// once reads are calm. An earlier allowlist (`== .standardWindow`)
    /// therefore dropped every real window at seed time and left the switcher
    /// empty for every already-running app, with no event to re-evaluate it.
    ///
    /// So: keep `.standardWindow`, keep `nil` (unreadable — don't punish a real
    /// window for a slow read), keep dialogs/floating panels. Drop only the
    /// app's own `.unknown` overlay windows (e.g. this app's switcher/HUD
    /// panels), which set that subrole explicitly and are never switch targets.
    nonisolated static func isSwitchableSubrole(_ subrole: Role.Subrole?) -> Bool {
        switch subrole {
        case .unknown: return false
        default:       return true
        }
    }

    /// Returns true if the window was actually added (callers only subscribe
    /// to per-window AX notifications for windows we track).
    @discardableResult
    private func addWindow(_ element: UIElement, to entry: HSAppEntry) -> Bool {
        if entry.windows.contains(where: { $0.axElement.element == element.element }) { return false }
        let title: String = (try? element.attribute(.title)) ?? ""
        let subrole: Role.Subrole? = (try? element.subrole()) ?? nil
        guard isSwitchableWindow(subrole: subrole, appName: entry.name, title: title) else { return false }
        let win = HSWindowEntry(stableID: mintWindowID(), axElement: element, title: title, subrole: subrole)
        entry.windows.insert(win, at: 0)
        return true
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
            let seeded: [(UIElement, String, Role.Subrole?)] = windows.map { w in
                AXUIElementSetMessagingTimeout(w.element, 0.1)
                let t: String? = (try? w.attribute(.title))
                let subrole: Role.Subrole? = (try? w.subrole()) ?? nil
                return (w, t ?? "", subrole)
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.applySeed(pid: pid, seeded: seeded)
                }
            }
        }
    }

    private func applySeed(pid: pid_t, seeded: [(UIElement, String, Role.Subrole?)]) {
        guard let entry = appsByPid[pid] else { return }
        for (element, title, subrole) in seeded {
            if let existing = entry.windows.first(where: { $0.axElement.element == element.element }) {
                // A re-seed can heal reads that timed out under the original
                // launch storm — but never downgrade a good value to a failed read.
                if existing.title.isEmpty && !title.isEmpty { existing.title = title }
                if existing.subrole == nil { existing.subrole = subrole }
                continue
            }
            guard isSwitchableWindow(subrole: subrole, appName: entry.name, title: title) else { continue }
            let win = HSWindowEntry(stableID: mintWindowID(), axElement: element, title: title, subrole: subrole)
            entry.windows.append(win)
            try? entry.observer?.addNotification(.uiElementDestroyed, forElement: element)
            try? entry.observer?.addNotification(.titleChanged, forElement: element)
        }
        scheduleSeedRetryIfEmpty(for: entry)
    }

    /// An app whose a11y server was cold at seed time returns an empty window
    /// list under the 0.1s timeout — Gecko (Firefox) instantiates its engine
    /// lazily on the first AX query, so the very query that came back empty is
    /// what woke it up. Nothing event-driven re-lists pre-existing windows
    /// (`windowCreated` only fires for new ones), so retry the seed a bounded
    /// number of times; the second pass runs against a warm engine and harvests.
    private func scheduleSeedRetryIfEmpty(for entry: HSAppEntry) {
        guard entry.windows.isEmpty, entry.seedRetriesLeft > 0 else { return }
        entry.seedRetriesLeft -= 1
        AKTrace("hs.window registry: \(entry.name) seeded 0 windows — retrying in 3s (\(entry.seedRetriesLeft) retries left after this)")
        let pid = entry.pid
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, let entry = self.appsByPid[pid] else { return }
                guard entry.windows.isEmpty else { return }
                self.seedWindows(for: entry)
            }
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
