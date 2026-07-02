//
//  HSSwitcherModule.swift
//  Hammerspoon 2
//

import Foundation
import JavaScriptCore
import AppKit

// MARK: - JS API

/// Module for a cmd+Tab-replacement window/app switcher. Backed by the live
/// `HSWindowRegistry` (MRU observer cache) and Swift-owned eventtap, so
/// trigger latency and cycle latency stay sub-frame regardless of how many
/// apps are running.
@objc protocol HSSwitcherModuleAPI: JSExport {
    /// Enable the switcher with the given configuration.
    ///
    /// - Parameter cfg: Object with optional keys:
    ///   - `commitDelayMs` (number, default 250) — milliseconds of ctrl-idle
    ///     after which the highlighted selection is committed.
    ///   - `filterPlaceholder` (string, default "Type to filter…")
    ///   - `onCommit` (function, args: `{ appName, appPid, windowTitle, windowID }`)
    ///   - `onCancel` (function, no args)
    ///   - `onHandoff` (function, args: `{ query }`) — fired when the user
    ///     presses Tab while filtering. The picker closes and the typed filter
    ///     text is handed off so a host launcher can search installed (not just
    ///     running) apps — letting the user launch something that isn't open yet.
    ///   - `tabsProvider` (function, no args) — called synchronously each time
    ///     the picker opens; returns an array of `{ bundleID, title, url,
    ///     windowIndex, tabIndex }` browser tabs. Tabs are listed under their
    ///     browser's app (matched by bundleID) beneath its window rows, and
    ///     committing one fires `onCommit` with `kind: 'tab'` plus the tab's
    ///     coordinates — the host is expected to focus it (e.g. AppleScript);
    ///     the switcher does not raise anything itself for tab commits.
    ///
    /// - Returns: `{ disable: function }` on success, or `{ error: string }`
    ///   on failure. The `error` is one of `"accessibility"`,
    ///   `"inputMonitoring"`, or a free-form string describing what went wrong.
    ///
    /// - Example:
    /// ```js
    /// const sw = hs.switcher.enable({
    ///   onCommit: e => console.log('switched to', e.appName)
    /// })
    /// if (sw.error) console.warn('switcher unavailable:', sw.error)
    /// // later: sw.disable()
    /// ```
    @objc func enable(_ cfg: JSValue) -> [String: Any]

    /// Open the picker right now, as if the user had triggered ctrl×2.
    /// Uses the first active binding's config; no-op if `enable()` has not
    /// been called. Intended for testing / custom hotkey wiring.
    /// - Returns: true if the picker opened, false otherwise.
    /// - Example:
    /// ```js
    /// hs.switcher.show()
    /// ```
    @objc func show() -> Bool

    /// Diagnostic snapshot of the live picker (if open) and the registry.
    /// Returns null if no session is active.
    /// - Returns: object with `windowFrame`, `screenVisibleFrame`,
    ///   `selectedAppIndex`, `selectedWindowIndex`, `mode`, `filterText`,
    ///   `apps` (array of `{name, pid, windowTitles}`)
    /// - Example:
    /// ```js
    /// hs.switcher.show(); const s = hs.switcher.debugState()
    /// ```
    @objc func debugState() -> [String: Any]?

    /// Programmatically move the current session's selection (no UI events).
    /// - Parameter axis: `'app'` to move between apps, `'window'` to move between windows within an app, `'linear'` to move through the flat row list the way the ↑/↓ arrow keys do
    /// - Parameter delta: direction to move — `+1` for forward, `-1` for backward
    /// - Returns: true if a session was active to move.
    @objc func debugMove(_ axis: String, _ delta: Int) -> Bool

    /// Programmatically set the current session's filter text — the same
    /// path as typing while the picker is open, including the best-match
    /// selection (tab → window → app). An empty string returns to cycle mode.
    /// - Parameter text: The filter text to apply.
    /// - Returns: true if a session was active to filter.
    /// - Example:
    /// ```js
    /// hs.switcher.show(); hs.switcher.debugFilter('github')
    /// ```
    @objc func debugFilter(_ text: String) -> Bool

    /// Programmatically commit the current selection (same path as Enter).
    /// Returns a dict with `frontmostBefore`, `targetApp`, `targetPid`,
    /// `committed` (bool), and the caller can poll `frontmostAfter` via
    /// `hs.application.frontmost()` shortly after.
    /// - Returns: `{ frontmostBefore, targetApp, targetPid, committed }` describing the commit outcome
    @objc func debugCommit() -> [String: Any]
}

// MARK: - Implementation

@_documentation(visibility: private)
@MainActor
@objc class HSSwitcherModule: NSObject, HSModuleAPI, HSSwitcherModuleAPI {
    var name = "hs.switcher"
    let engineID: UUID
    private var activeBindings: [HSSwitcherBinding] = []

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {
        for b in activeBindings { b.disable() }
        activeBindings.removeAll()
    }

    isolated deinit {
        AKTrace("Deinit of \(name): \(engineID)")
    }

    @objc func show() -> Bool {
        guard let binding = activeBindings.first else {
            AKWarning("hs.switcher.show(): no active binding — call enable() first")
            return false
        }
        return binding.triggerNow()
    }

    @objc func debugState() -> [String: Any]? {
        guard let binding = activeBindings.first else { return nil }
        return binding.debugState()
    }

    @objc func debugMove(_ axis: String, _ delta: Int) -> Bool {
        guard let binding = activeBindings.first else { return false }
        return binding.debugMove(axis: axis, delta: delta)
    }

    @objc func debugFilter(_ text: String) -> Bool {
        guard let binding = activeBindings.first else { return false }
        return binding.debugFilter(text)
    }

    @objc func debugCommit() -> [String: Any] {
        guard let binding = activeBindings.first else {
            return ["committed": false, "reason": "no active binding"]
        }
        return binding.debugCommit()
    }

    @objc func enable(_ cfg: JSValue) -> [String: Any] {
        guard AXIsProcessTrusted() else {
            return ["error": "accessibility"]
        }
        let config = HSSwitcherConfig(jsValue: cfg)
        let binding = HSSwitcherBinding(config: config)
        guard binding.install() else {
            return ["error": "inputMonitoring"]
        }
        activeBindings.append(binding)

        // Wrap disable as a JS-callable block.
        let disableBlock: @convention(block) () -> Void = { [weak self, weak binding] in
            MainActor.assumeIsolated {
                binding?.disable()
                if let b = binding { self?.activeBindings.removeAll { $0 === b } }
            }
        }
        return [
            "disable": unsafeBitCast(disableBlock, to: AnyObject.self),
        ]
    }
}

// MARK: - Config

/// Parsed config; defaults applied here so the session never sees a missing
/// field.
struct HSSwitcherConfig: @unchecked Sendable {
    let commitDelayMs: Int
    let filterPlaceholder: String
    let onCommit: JSValue?
    let onCancel: JSValue?
    let onHandoff: JSValue?
    let tabsProvider: JSValue?

    init(jsValue: JSValue) {
        guard jsValue.isObject else {
            commitDelayMs = 250
            filterPlaceholder = "Type to filter…"
            onCommit = nil
            onCancel = nil
            onHandoff = nil
            tabsProvider = nil
            return
        }
        let v = jsValue.forProperty("commitDelayMs")
        commitDelayMs = (v?.isNumber == true) ? Int(v!.toInt32()) : 250

        let fp = jsValue.forProperty("filterPlaceholder")
        filterPlaceholder = (fp?.isString == true) ? (fp!.toString() ?? "Type to filter…") : "Type to filter…"

        let oc = jsValue.forProperty("onCommit")
        onCommit = (oc?.isObject == true && !(oc?.isNull ?? true) && !(oc?.isUndefined ?? true)) ? oc : nil

        let on = jsValue.forProperty("onCancel")
        onCancel = (on?.isObject == true && !(on?.isNull ?? true) && !(on?.isUndefined ?? true)) ? on : nil

        let oh = jsValue.forProperty("onHandoff")
        onHandoff = (oh?.isObject == true && !(oh?.isNull ?? true) && !(oh?.isUndefined ?? true)) ? oh : nil

        let tp = jsValue.forProperty("tabsProvider")
        tabsProvider = (tp?.isObject == true && !(tp?.isNull ?? true) && !(tp?.isUndefined ?? true)) ? tp : nil
    }
}

// MARK: - Binding

/// One `enable()` call's binding: owns the double-tap detector and creates a
/// fresh session each time the user triggers the switcher.
@MainActor
final class HSSwitcherBinding {
    let config: HSSwitcherConfig
    private var detector: DoubleTapDetector?
    private var activeSession: HSSwitcherSession?

    init(config: HSSwitcherConfig) {
        self.config = config
    }

    func install() -> Bool {
        // Touch the window registry now so it can begin seeding apps + AX
        // observers immediately — by the time the user triggers ctrl×2,
        // the snapshot will already be populated. Without this, the first
        // trigger runs against a near-empty registry (only the apps whose
        // windowCreated AX events have fired since seed) and the picker
        // shows half-empty.
        _ = HSWindowRegistry.shared

        let det = DoubleTapDetector(modifier: .control, swiftCallback: { [weak self] in
            self?.onTrigger()
        })
        det.start()
        self.detector = det
        AKTrace("hs.switcher: installed ctrl×2 detector")
        return true
    }

    func disable() {
        activeSession?.cancel()
        activeSession = nil
        detector?.stop()
        detector = nil
    }

    /// Programmatic trigger used by `hs.switcher.show()`. Returns true if
    /// the picker actually opened.
    @discardableResult
    func triggerNow() -> Bool {
        if activeSession != nil { return false }
        // Filter out system helpers / menubar apps that aren't sensible
        // switch targets (loginwindow, WindowManager, agents with 0 windows),
        // then take a display copy of each that drops untitled ghost windows
        // (Finder desktop, helper surfaces) so the picker shows no "(untitled)"
        // rows. The copy reuses the real window refs, so commit still works.
        let snap = HSWindowRegistry.shared.snapshot()
            .filter { $0.isSwitchable }
            .map { $0.switcherDisplayCopy() }
        attachTabs(to: snap)
        AKTrace("hs.switcher: triggered with \(snap.count) switchable apps")
        let session = HSSwitcherSession(config: config) { [weak self] in
            self?.activeSession = nil
        }
        if !session.start(snapshot: snap) {
            AKError("hs.switcher: session.start() returned false")
            return false
        }
        activeSession = session
        return true
    }

    private func onTrigger() { _ = triggerNow() }

    /// Ask the host's tabsProvider (if any) for browser tabs and attach them
    /// to the matching display copies by bundleID. Synchronous — the provider
    /// is expected to return a cached inventory instantly (and refresh it in
    /// the background for the next trigger). Cap per app well above the
    /// state's visible cap so filtering has a full haystack to match against.
    private func attachTabs(to apps: [HSAppEntry]) {
        guard let provider = config.tabsProvider else { return }
        guard let result = provider.callSafely(withArguments: [], context: "hs.switcher tabsProvider"),
              result.isArray,
              let rows = result.toArray() as? [[String: Any]] else { return }
        var byBundle: [String: [HSSwitcherTab]] = [:]
        for row in rows {
            guard let bundleID = row["bundleID"] as? String,
                  let title = row["title"] as? String else { continue }
            let tab = HSSwitcherTab(
                title: title,
                url: row["url"] as? String ?? "",
                windowIndex: (row["windowIndex"] as? NSNumber)?.intValue ?? 1,
                tabIndex: (row["tabIndex"] as? NSNumber)?.intValue ?? 1
            )
            byBundle[bundleID, default: []].append(tab)
        }
        guard !byBundle.isEmpty else { return }
        for app in apps {
            if let bundleID = app.bundleID, let tabs = byBundle[bundleID] {
                app.switcherTabs = Array(tabs.prefix(40))
            }
        }
    }

    /// Returns a JS-friendly snapshot of the current session's state, or nil.
    func debugState() -> [String: Any]? {
        guard let session = activeSession else { return nil }
        return session.debugState()
    }

    /// Programmatically move selection on the active session. Returns false
    /// if no session is active.
    func debugMove(axis: String, delta: Int) -> Bool {
        guard let session = activeSession else { return false }
        session.debugMove(axis: axis, delta: delta)
        return true
    }

    /// Programmatically drive the active session's filter (same code path as
    /// typing). Returns false if no session is active.
    func debugFilter(_ text: String) -> Bool {
        guard let session = activeSession else { return false }
        session.debugFilter(text)
        return true
    }

    /// Programmatically run commit() on the active session, returning the
    /// pre-state so the caller can compare against NSWorkspace state after.
    func debugCommit() -> [String: Any] {
        guard let session = activeSession else {
            return ["committed": false, "reason": "no active session"]
        }
        return session.debugCommit()
    }
}
