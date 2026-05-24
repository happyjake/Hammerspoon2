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
        focus(app: app, window: window)
        let payload: [String: Any] = [
            "appName": app.name,
            "appPid": Int(app.pid),
            "windowTitle": window?.title as Any,
            "windowID": window?.stableID as Any,
        ]
        close(callbackKind: .commit(payload))
    }

    func cancel() {
        guard !isClosed else { return }
        close(callbackKind: .cancel)
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
        case .nextWindow:  state.moveWindowSelection(by: 1)
        case .prevWindow:  state.moveWindowSelection(by: -1)
        case .commit:      commit()
        case .cancel:      cancel()
        case .enterFilter(let s):
            state.mode = .filter
            state.filterText = s
            keyHandler?.setFilterMode(true)
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
        if let screen = NSScreen.main {
            let f = screen.frame
            let w = win.frame.width
            let h = win.frame.height
            win.setFrame(NSRect(x: f.midX - w/2, y: f.midY - h/2, width: w, height: h), display: false)
        }
        win.makeKeyAndOrderFront(nil)
        win.orderFrontRegardless()
        self.window = win

        // Cancel if user switches apps via something else (cmd-tab, click on
        // another window, etc.)
        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: win, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.cancel() }
        }
    }

    private func focus(app: HSAppEntry, window: HSWindowEntry?) {
        if let win = window {
            AXUIElementSetMessagingTimeout(win.axElement.element, 0.1)
            try? win.axElement.performAction(.raise)
        }
        if let running = NSRunningApplication(processIdentifier: app.pid) {
            running.activate(options: [])
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
