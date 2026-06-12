//
//  HSSwitcherSession.swift
//  Hammerspoon 2
//

import Foundation
import AppKit
import SwiftUI
import AXSwift

/// Per-invocation switcher session. Owns the eventtap, the picker window, the
/// safety timer, and the state. All teardown paths (commit / cancel / safety
/// timeout / focus loss) funnel through `tearDown()` exactly once.
@MainActor
final class HSSwitcherSession {
    private let config: HSSwitcherConfig
    private let onClose: () -> Void
    let state = HSSwitcherState()

    private var keyHandler: HSSwitcherKeyHandler?
    private var safetyTimer: Timer?
    private var resignKeyObserver: NSObjectProtocol?
    private var window: NSWindow?
    private var isClosed = false

    init(config: HSSwitcherConfig, onClose: @escaping () -> Void) {
        self.config = config
        self.onClose = onClose
    }

    /// Open the picker. Returns false (and self-closes) if the snapshot is
    /// empty or the eventtap can't be installed.
    @discardableResult
    func start(snapshot: [HSAppEntry]) -> Bool {
        state.apps = snapshot
        state.applyDefaultSelection()
        guard !state.apps.isEmpty else { close(callbackKind: .none); return false }

        // Eventtap first — if Input Monitoring is denied we shouldn't open a
        // picker we can't dismiss.
        let handler = HSSwitcherKeyHandler(
            commitDelayMs: config.commitDelayMs
        ) { [weak self] intent in
            self?.handle(intent: intent)
        }
        guard handler.install() else { close(callbackKind: .none); return false }
        self.keyHandler = handler

        // Picker window
        showWindow()

        // Safety: max 15s session, no matter what.
        safetyTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.cancel() }
        }
        return true
    }

    func commit() {
        guard !isClosed else { return }
        guard let (app, window) = state.currentSelection() else { cancel(); return }
        let payload: [String: Any] = [
            "appName": app.name,
            "appPid": Int(app.pid),
            "windowTitle": window?.title as Any,
            "windowID": window?.stableID as Any,
        ]
        // Tear down the picker FIRST so we don't compete with the target for
        // key window status when we activate. close() calls tearDown() which
        // orderOut's the picker, then we focus.
        isClosed = true
        tearDown()
        focus(app: app, window: window)
        config.onCommit?.callSafely(withArguments: [payload], context: "hs.switcher onCommit")
        onClose()
    }

    func cancel() {
        guard !isClosed else { return }
        close(callbackKind: .cancel)
    }

    /// Tab while filtering: tear the picker down and hand the typed query to the
    /// launcher via `onHandoff`, so the user can launch an app that isn't
    /// running (and therefore can't appear in this running-windows picker).
    /// Mirrors `commit()`'s discipline — close FIRST, then fire the callback.
    /// `internal` (not private) so it can be unit-tested without an eventtap.
    func emitHandoff() {
        guard !isClosed else { return }
        isClosed = true
        tearDown()
        let payload: [String: Any] = ["query": state.filterText]
        config.onHandoff?.callSafely(withArguments: [payload], context: "hs.switcher onHandoff")
        onClose()
    }

    // MARK: - Internals

    private enum CallbackKind {
        case commit([String: Any])
        case cancel
        case none
    }

    private func close(callbackKind: CallbackKind) {
        guard !isClosed else { return }
        isClosed = true
        tearDown()
        switch callbackKind {
        case .commit(let payload):
            config.onCommit?.callSafely(withArguments: [payload], context: "hs.switcher onCommit")
        case .cancel:
            config.onCancel?.callSafely(withArguments: [], context: "hs.switcher onCancel")
        case .none:
            break
        }
        onClose()
    }

    // MARK: - Debug introspection

    func debugState() -> [String: Any] {
        var dict: [String: Any] = [
            "selectedAppIndex": state.selectedAppIndex,
            "selectedWindowIndex": state.selectedWindowIndex,
            "mode": state.mode == .filter ? "filter" : "cycle",
            "filterText": state.filterText,
            "appCount": state.apps.count,
        ]
        if let w = window {
            let f = w.frame
            dict["windowFrame"] = ["x": f.origin.x, "y": f.origin.y, "w": f.width, "h": f.height]
        }
        // Report the screen the panel actually landed on (pointer may have
        // moved since); pre-show, the screen it would land on.
        if let screen = window?.screen ?? hostScreen {
            let f = screen.visibleFrame
            dict["screenVisibleFrame"] = ["x": f.origin.x, "y": f.origin.y, "w": f.width, "h": f.height]
        }
        let apps = state.apps.prefix(20).map { app -> [String: Any] in
            return [
                "name": app.name,
                "pid": Int(app.pid),
                "windowCount": app.windows.count,
                "windowTitles": app.windows.prefix(5).map { $0.title },
            ]
        }
        dict["apps"] = Array(apps)
        if let (selApp, selWin) = state.currentSelection() {
            dict["currentSelectionApp"] = selApp.name
            dict["currentSelectionWindow"] = selWin?.title ?? "(no window)"
        }
        return dict
    }

    func debugMove(axis: String, delta: Int) {
        switch axis {
        case "app":    state.moveAppSelection(by: delta)
        case "window": state.moveWindowSelection(by: delta)
        case "linear": state.moveLinearSelection(by: delta)
        default: break
        }
    }

    /// Captures pre-commit state, runs commit, returns details so a test
    /// harness can compare against NSWorkspace state after the fact.
    func debugCommit() -> [String: Any] {
        let beforeApp = NSWorkspace.shared.frontmostApplication
        guard let (app, window) = state.currentSelection() else {
            return [
                "committed": false,
                "reason": "no selection",
                "frontmostBefore": beforeApp?.localizedName ?? "?",
                "frontmostBeforePid": Int(beforeApp?.processIdentifier ?? 0),
            ]
        }
        let dict: [String: Any] = [
            "committed": true,
            "frontmostBefore": beforeApp?.localizedName ?? "?",
            "frontmostBeforePid": Int(beforeApp?.processIdentifier ?? 0),
            "targetApp": app.name,
            "targetPid": Int(app.pid),
            "targetWindow": window?.title as Any,
        ]
        commit()
        return dict
    }

    private func tearDown() {
        keyHandler?.stop()
        keyHandler = nil
        safetyTimer?.invalidate()
        safetyTimer = nil
        if let o = resignKeyObserver {
            NotificationCenter.default.removeObserver(o)
            resignKeyObserver = nil
        }
        window?.orderOut(nil)
        window = nil
    }

    private func handle(intent: HSSwitcherKeyHandler.Intent) {
        switch intent {
        case .nextApp:     state.moveAppSelection(by: 1)
        case .prevApp:     state.moveAppSelection(by: -1)
        case .nextRow:     state.moveLinearSelection(by: 1)
        case .prevRow:     state.moveLinearSelection(by: -1)
        case .commit:      commit()
        case .cancel:      cancel()
        case .handoff:     emitHandoff()
        case .enterFilter(let s):
            state.mode = .filter
            state.filterText = s
            keyHandler?.setFilterMode(true)
            // First letter entered the filter — make sure the user is typing
            // Latin even if their IME was Chinese / Japanese / Korean.
            _ = switchToASCIIInputSource()
            ensureSelectionInBounds()
        case .filterAppend(let s):
            state.filterText += s
            ensureSelectionInBounds()
        case .filterBackspace:
            if !state.filterText.isEmpty {
                state.filterText.removeLast()
                if state.filterText.isEmpty {
                    state.mode = .cycle
                    keyHandler?.setFilterMode(false)
                }
                ensureSelectionInBounds()
            }
        }
    }

    /// After filter changes, the current selection index may now point past
    /// the end of the filtered list — clamp it back into bounds.
    private func ensureSelectionInBounds() {
        let list = state.filteredApps()
        if list.isEmpty {
            state.selectedAppIndex = -1
            state.selectedWindowIndex = -1
            return
        }
        if state.selectedAppIndex < 0 || state.selectedAppIndex >= list.count {
            state.selectedAppIndex = 0
        }
        let w = list[state.selectedAppIndex].windows
        if w.isEmpty {
            state.selectedWindowIndex = -1
        } else if state.selectedWindowIndex < 0 || state.selectedWindowIndex >= w.count {
            state.selectedWindowIndex = 0
        }
    }

    /// The screen that should host the picker: the one under the mouse
    /// pointer, so the panel opens where the user is working on multi-display
    /// setups. Falls back to the active-app screen when the pointer sits on
    /// no display (mid-transition between screens).
    private var hostScreen: NSScreen? {
        let loc = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(loc, $0.frame, false) } ?? NSScreen.main
    }

    private func showWindow() {
        let view = HSSwitcherView(
            state: state,
            placeholder: config.filterPlaceholder
        ) { [weak self] appIdx, winIdx in
            guard let self else { return }
            self.state.selectedAppIndex = appIdx
            self.state.selectedWindowIndex = winIdx
            self.commit()
        }
        let hosting = NSHostingController(rootView: view)
        let win = HSSwitcherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        win.contentViewController = hosting
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .modalPanel
        win.hasShadow = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        win.hidesOnDeactivate = false
        // Center on the screen under the mouse pointer (hostScreen) — the
        // panel follows the cursor across displays. Use visibleFrame so
        // we sit below the menu bar / above the Dock.
        //
        // IMPORTANT: use literal constants for w/h, not `win.frame.{width,height}`.
        // After assigning an NSHostingController as `contentViewController`, the
        // panel's frame can be reported as 0×0 until SwiftUI completes its first
        // layout pass — which hasn't happened yet at this point. Reading the
        // frame here produced a 0-sized window centered on the screen.
        let panelW: CGFloat = 640
        let panelH: CGFloat = 480
        if let screen = hostScreen {
            let f = screen.visibleFrame
            win.setFrame(
                NSRect(x: f.midX - panelW/2, y: f.midY - panelH/2, width: panelW, height: panelH),
                display: true
            )
        }
        win.makeKeyAndOrderFront(nil)
        win.orderFrontRegardless()
        self.window = win

        // NOTE: deliberately NOT observing didResignKeyNotification to cancel
        // the session. With a nonactivatingPanel, the picker frequently loses
        // key status moments after opening — the actual frontmost app reclaims
        // it — which would kill the session before the user could commit. The
        // user cancels explicitly via Escape, click-outside (via the safety
        // timer), or the 15s timeout.
    }

    private func focus(app: HSAppEntry, window: HSWindowEntry?) {
        // Raise the specific window first (so it's the one that's front when
        // the app activates), then activate the app.
        if let win = window {
            AXUIElementSetMessagingTimeout(win.axElement.element, 0.1)
            try? win.axElement.performAction(.raise)
        }

        // macOS 14+ blocks `NSRunningApplication.activate(...)` from a
        // background process — that's the same restriction that broke
        // cross-app activation here. `NSWorkspace.shared.openApplication(at:)`
        // goes through LaunchServices instead and is the modern, allowed
        // path. (It's what `hs.application.launchOrFocus()` uses too.)
        guard let running = NSRunningApplication(processIdentifier: app.pid),
              let bundleURL = running.bundleURL else { return }
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: cfg) { _, error in
            if let error = error {
                AKError("hs.switcher: openApplication failed for \(app.name): \(error.localizedDescription)")
            }
        }
    }
}

/// Panel subclass that can become key without making Hammerspoon 2 the
/// foreground app. Necessary so the picker can receive mouse events without
/// stealing focus permanently from the user's previous app.
final class HSSwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
