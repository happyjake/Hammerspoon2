//
//  WindowModule.swift
//  Hammerspoon 2
//
//  Created by Claude Code
//

import Foundation
import JavaScriptCore
import AppKit
import AXSwift

// MARK: - Declare our JavaScript API

/// Module for interacting with windows
@objc protocol HSWindowModuleAPI: JSExport {
    /// Get the currently focused window
    /// - Returns: The focused window, or nil if none
    /// - Example:
    /// ```js
    /// const win = hs.window.focusedWindow()
    /// console.log(win && win.title)
    /// ```
    @objc func focusedWindow() -> HSWindow?

    /// Get all windows from all applications
    /// - Returns: An array of all windows
    /// - Example:
    /// ```js
    /// const wins = hs.window.allWindows()
    /// console.log(wins.length)
    /// ```
    @objc func allWindows() -> [HSWindow]

    /// Get all visible (not minimized) windows
    /// - Returns: An array of visible windows
    /// - Example:
    /// ```js
    /// const vis = hs.window.visibleWindows()
    /// ```
    @objc func visibleWindows() -> [HSWindow]

    /// Get windows for a specific application
    /// - Parameter app: An HSApplication object
    /// - Returns: An array of windows for that application
    /// - Example:
    /// ```js
    /// const app = hs.application.frontmost()
    /// const wins = hs.window.windowsForApp(app)
    /// ```
    @objc func windowsForApp(_ app: HSApplication) -> [HSWindow]

    /// Get all windows on a specific screen
    /// - Parameter screenIndex: The screen index (0 for main screen)
    /// - Returns: An array of windows on that screen
    /// - Example:
    /// ```js
    /// const wins = hs.window.windowsOnScreen(0)
    /// ```
    @objc func windowsOnScreen(_ screenIndex: Int) -> [HSWindow]

    /// Get the window at a specific screen position
    /// - Parameters:
    ///   - point: An HSPoint containing the coordinates
    /// - Returns: The topmost window at that position, or nil if none
    /// - Example:
    /// ```js
    /// const win = hs.window.windowAtPoint({x: 500, y: 300})
    /// ```
    @objc func windowAtPoint(_ point: HSPoint) -> HSWindow?

    /// Get ordered windows (front to back)
    /// - Returns: An array of windows in z-order
    /// - Example:
    /// ```js
    /// const wins = hs.window.orderedWindows()
    /// ```
    @objc func orderedWindows() -> [HSWindow]

    /// Get a snapshot of the live window registry — apps and their windows in
    /// MRU order, populated from observers. Reads from cache; no AX calls on
    /// the hot path. Use this in latency-sensitive code like switchers.
    /// - Returns: An array of dictionaries: `[{pid, name, bundleID, iconBase64, windows: [{id, title}]}]`
    /// - Example:
    /// ```js
    /// const snap = hs.window.snapshot()
    /// console.log(snap[0].name, snap[0].windows.length)
    /// ```
    @objc func snapshot() -> [[String: Any]]
}

// MARK: - Implementation

@_documentation(visibility: private)
@MainActor
@objc class HSWindowModule: NSObject, HSModuleAPI, HSWindowModuleAPI {
    var name = "hs.window"
    let engineID: UUID

    /// Live, in-memory MRU cache of running apps/windows. Maintained by
    /// observers (NSWorkspace + AXObserver). Process-wide singleton — see
    /// `HSWindowRegistry.shared`. Cached locally for convenience.
    private var registry: HSWindowRegistry { HSWindowRegistry.shared }

    // MARK: - Module lifecycle
    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        // Touch the shared registry so observers are wired up early, even if
        // JS hasn't called any hs.window API yet (hs.switcher reads it on the
        // first ctrl×2 trigger).
        _ = HSWindowRegistry.shared
        AKTrace("Init of \(name): \(engineID)")
    }

    /// Internal accessor for other modules (e.g. `hs.switcher`).
    func internalRegistry() -> HSWindowRegistry { registry }

    /// Returns the process-wide window registry. Always available — does not
    /// depend on JS having touched `hs.window` first.
    static func sharedRegistry() -> HSWindowRegistry? {
        return HSWindowRegistry.shared
    }

    func shutdown() {
        // No cleanup needed for this module
    }

    isolated deinit {
        AKTrace("Deinit of \(name): \(engineID)")
    }

    // MARK: - Helper Methods
    private func checkAccessibility() -> Bool {
        guard AXIsProcessTrusted() else {
            AKError("hs.window: Accessibility permissions not granted")
            return false
        }
        return true
    }

    private func getWindowElements(for app: NSRunningApplication) -> [UIElement] {
        guard let axApp = Application(app) else {
            return []
        }
        // Bound AX messaging: a misbehaving app cannot freeze the main thread for more
        // than 100ms per call. Default is 6s, which froze the UI when Preview hung.
        AXUIElementSetMessagingTimeout(axApp.element, 0.1)

        do {
            let windows: [UIElement] = try axApp.windows() ?? []
            for w in windows {
                AXUIElementSetMessagingTimeout(w.element, 0.1)
            }
            return windows
        } catch {
            AKTrace("Failed to get windows for \(app.localizedName ?? "unknown"): \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - API Implementation

    @objc func focusedWindow() -> HSWindow? {
        guard checkAccessibility() else { return nil }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        guard let axApp = Application(frontApp) else {
            return nil
        }

        do {
            guard let focusedWindow: UIElement = try axApp.attribute(.focusedWindow) else {
                return nil
            }

            return HSWindow(element: focusedWindow, app: frontApp)
        } catch {
            AKTrace("Failed to get focused window: \(error.localizedDescription)")
            return nil
        }
    }

    @objc func allWindows() -> [HSWindow] {
        guard checkAccessibility() else { return [] }

        var windows: [HSWindow] = []

        for app in NSWorkspace.shared.runningApplications {
            let windowElements = getWindowElements(for: app)
            windows.append(contentsOf: windowElements.map { HSWindow(element: $0, app: app) })
        }

        return windows
    }

    @objc func visibleWindows() -> [HSWindow] {
        return allWindows().filter { !$0.isMinimized }
    }

    @objc func windowsForApp(_ app: HSApplication) -> [HSWindow] {
        guard checkAccessibility() else { return [] }

        let windowElements = getWindowElements(for: app.runningApplication)
        return windowElements.map { HSWindow(element: $0, app: app.runningApplication) }
    }

    @objc func windowsOnScreen(_ screenIndex: Int) -> [HSWindow] {
        let screens = NSScreen.screens
        guard screenIndex >= 0 && screenIndex < screens.count else {
            AKWarning("hs.window.windowsOnScreen(): Invalid screen index \(screenIndex)")
            return []
        }

        let screen = screens[screenIndex]
        let screenFrame = screen.frame

        let result = visibleWindows().filter { window in
            guard let frame = window.frame else {
                return false
            }

            let windowRect = CGRect(x: frame.x, y: frame.y, width: frame.w, height: frame.h)
            return screenFrame.intersects(windowRect)
        }

        return result
    }

    @objc func windowAtPoint(_ point: HSPoint) -> HSWindow? {
        guard checkAccessibility() else { return nil }

        do {
            let systemWide = SystemWideElement(AXUIElementCreateSystemWide())
            let position = point.point

            guard let element: UIElement = try systemWide.elementAtPosition(position) else {
                return nil
            }

            // Walk up the hierarchy to find the window
            var current: UIElement? = element
            while let elem = current {
                if let role = try? elem.role(), role == .window {
                    // Find the app for this window
                    let pid = try? elem.pid()
                    if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
                        return HSWindow(element: elem, app: app)
                    }
                }

                current = try? elem.attribute(.parent)
            }

            return nil
        } catch {
            AKError("hs.window.windowAtPosition(): Failed: \(error.localizedDescription)")
            return nil
        }
    }

    @objc func snapshot() -> [[String: Any]] {
        return registry.snapshot().map { app in
            var dict: [String: Any] = [
                "pid": Int(app.pid),
                "name": app.name,
                "bundleID": app.bundleID as Any,
                "windows": app.windows.map { win in
                    [
                        "id": win.stableID,
                        "title": win.title,
                    ] as [String: Any]
                },
            ]
            if let icon = app.icon, let png = icon.pngDataRepresentation() {
                dict["iconBase64"] = png.base64EncodedString()
            }
            return dict
        }
    }

    @objc func orderedWindows() -> [HSWindow] {
        guard checkAccessibility() else { return [] }

        // Get windows from apps in activation order
        var orderedApps: [NSRunningApplication] = []

        // Start with frontmost app
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            orderedApps.append(frontApp)
        }

        // Add other apps
        for app in NSWorkspace.shared.runningApplications {
            if app.activationPolicy == .regular && !orderedApps.contains(app) {
                orderedApps.append(app)
            }
        }

        var windows: [HSWindow] = []
        for app in orderedApps {
            let appWindows = getWindowElements(for: app).map { HSWindow(element: $0, app: app) }
            windows.append(contentsOf: appWindows)
        }

        return windows
    }
}

private extension NSImage {
    /// PNG-encoded data for the (first) bitmap representation. Used to embed
    /// app icons in `hs.window.snapshot()` results.
    func pngDataRepresentation() -> Data? {
        guard let tiff = self.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
