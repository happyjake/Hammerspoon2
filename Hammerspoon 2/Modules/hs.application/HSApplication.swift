//
//  HSApplication.swift
//  Hammerspoon 2
//
//  Created by Chris Jones on 20/10/2025.
//

import Foundation
import JavaScriptCore
import Cocoa
import AXSwift

/// Object representing an application. You should not instantiate this directly in JavaScript, but rather, use the methods from hs.application which will return appropriate HSApplication objects.
@objc protocol HSApplicationAPI: HSTypeAPI, JSExport {
    /// POSIX Process Identifier
    /// - Example:
    /// ```js
    /// const app = hs.application.frontmost()
    /// console.log(app.pid)
    /// ```
    @objc var pid: Int { get }

    /// Bundle Identifier (e.g. com.apple.Safari)
    /// - Example:
    /// ```js
    /// const app = hs.application.frontmost()
    /// console.log(app.bundleID)
    /// ```
    @objc var bundleID: String? { get }

    /// The application's title
    /// - Example:
    /// ```js
    /// const app = hs.application.frontmost()
    /// console.log(app.title)
    /// ```
    @objc var title: String? { get }

    /// Location of the application on disk
    /// - Example:
    /// ```js
    /// const app = hs.application.frontmost()
    /// console.log(app.bundlePath)
    /// ```
    @objc var bundlePath: String? { get }

    /// Is the application hidden
    /// - Example:
    /// ```js
    /// const app = hs.application.matchingName("Safari")
    /// app.isHidden = true
    /// ```
    @objc var isHidden: Bool { get set }

    /// Is the application focused
    /// - Example:
    /// ```js
    /// const app = hs.application.frontmost()
    /// console.log(app.isActive)
    /// ```
    @objc var isActive: Bool { get }

    /// Terminate the application
    /// - Returns: True if the application was terminated, otherwise false
    /// - Example:
    /// ```js
    /// const app = hs.application.matchingName("Calculator")
    /// app.kill()
    /// ```
    @objc func kill() -> Bool

    /// Force-terminate the application
    /// - Returns: True if the application was force-terminated, otherwise false
    /// - Example:
    /// ```js
    /// const app = hs.application.matchingName("Calculator")
    /// app.kill9()
    /// ```
    @objc func kill9() -> Bool

    /// The main window of this application, or nil if there is no main window
    /// - Example:
    /// ```js
    /// const app = hs.application.frontmost()
    /// const win = app.mainWindow
    /// ```
    @objc var mainWindow: HSWindow? { get }

    /// The focused window of this application, or nil if there is no focused window
    /// - Example:
    /// ```js
    /// const app = hs.application.frontmost()
    /// const win = app.focusedWindow
    /// ```
    @objc var focusedWindow: HSWindow? { get }

    /// All windows of this application
    /// - Example:
    /// ```js
    /// const app = hs.application.frontmost()
    /// app.allWindows.forEach(w => console.log(w.title))
    /// ```
    @objc var allWindows: [HSWindow] { get }

    /// All visible (ie non-hidden) windows of this application
    /// - Example:
    /// ```js
    /// const app = hs.application.frontmost()
    /// console.log(app.visibleWindows.length)
    /// ```
    @objc var visibleWindows: [HSWindow] { get }

    /// The application's HSAXElement object, for use with the hs.ax APIs
    /// - Returns: An HSAXElement object, or nil if it could not be obtained
    /// - Example:
    /// ```js
    /// const app = hs.application.frontmost()
    /// const ax = app.axElement()
    /// ```
    @objc func axElement() -> HSAXElement?

    /// Bring this application to the foreground
    /// - Parameter allWindows: Pass true to raise all application windows. Defaults to false.
    /// - Example:
    /// ```js
    /// const app = hs.application.matchingName("Safari")
    /// app.activate()
    /// app.activate(true)
    /// ```
    @objc func activate(_ allWindows: Bool)

    /// Hide this application and all its windows
    /// - Example:
    /// ```js
    /// const app = hs.application.matchingName("Safari")
    /// app.hide()
    /// ```
    @objc func hide()

    /// Unhide this application
    /// - Example:
    /// ```js
    /// const app = hs.application.matchingName("Safari")
    /// app.unhide()
    /// ```
    @objc func unhide()

    /// Whether the application process is still running
    /// - Returns: true if the application is running, false if it has terminated
    /// - Example:
    /// ```js
    /// const app = hs.application.matchingName("Calculator")
    /// app.kill()
    /// console.log(app.isRunning)
    /// ```
    @objc var isRunning: Bool { get }

    /// The kind of application: "standard" (regular dock app), "accessory" (no dock), or "background" (agent)
    /// - Example:
    /// ```js
    /// const app = hs.application.frontmost()
    /// console.log(app.kind)
    /// ```
    @objc var kind: String { get }

    /// Get the full menu structure of this application
    /// - Note: This traverses the accessibility hierarchy and may be slow for apps with large menus.
    /// - Returns: An array of top-level menu objects, each with title and items keys, or null if unavailable
    /// - Example:
    /// ```js
    /// const app = hs.application.frontmost()
    /// app.getMenuItems().forEach(m => console.log(m.title))
    /// ```
    @objc func getMenuItems() -> [[String: Any]]?

    /// Find a menu item by title search or hierarchical path
    /// - Parameter item: A string to search for (case-insensitive) across all menus, or an array of strings forming a path such as ["Edit", "Select All"]
    /// - Returns: An object with title and enabled keys, or null if not found
    /// - Example:
    /// ```js
    /// const app = hs.application.frontmost()
    /// const item = app.findMenuItem(["Edit", "Select All"])
    /// console.log(item.enabled)
    /// ```
    @objc func findMenuItem(_ item: JSValue) -> [String: Any]?

    /// Click a menu item found by title search or hierarchical path
    /// - Parameter item: A string to search for (case-insensitive) across all menus, or an array of strings forming a path such as ["File", "New Window"]
    /// - Returns: true if the menu item was found and clicked, false otherwise
    /// - Example:
    /// ```js
    /// const safari = hs.application.matchingName("Safari")
    /// safari.selectMenuItem(["File", "New Window"])
    /// ```
    @objc func selectMenuItem(_ item: JSValue) -> Bool

    /// Find windows whose title contains the given string (case-insensitive)
    /// - Parameter pattern: A string to search for in window titles
    /// - Returns: An array of matching HSWindow objects
    /// - Example:
    /// ```js
    /// const app = hs.application.frontmost()
    /// app.findWindow("untitled").forEach(w => console.log(w.title))
    /// ```
    @objc func findWindow(_ pattern: String) -> [HSWindow]

    /// Get the first window with exactly the given title
    /// - Parameter title: The exact window title to search for
    /// - Returns: The matching HSWindow, or null if not found
    /// - Example:
    /// ```js
    /// const app = hs.application.frontmost()
    /// const win = app.getWindow("index.html")
    /// ```
    @objc func getWindow(_ title: String) -> HSWindow?
}

@_documentation(visibility: private)
@objc class HSApplication: NSObject, HSApplicationAPI {
    @objc var typeName = "HSApplication"
    let runningApplication: NSRunningApplication
    let axUIElement: Application?

    init(runningApplication: NSRunningApplication) {
        self.runningApplication = runningApplication
        self.axUIElement = Application(runningApplication)
    }

    deinit {
//        print("deinit of \(self): \(self.runningApplication.localizedName ?? "UNKNOWN")")
    }

    @objc var pid: Int { Int(self.runningApplication.processIdentifier) }
    @objc var bundleID: String? { self.runningApplication.bundleIdentifier }
    @objc var title: String? { self.runningApplication.localizedName }
    @objc var bundlePath: String? { self.runningApplication.bundleURL?.path(percentEncoded: false) }

    @objc var isHidden: Bool {
        get {
            let value = try? self.axUIElement?.attribute(.hidden) as Bool?
            return value ?? false
        }
        set { try? self.axUIElement?.setAttribute(.hidden, value: newValue) }
    }
    @objc var isActive: Bool { self.runningApplication.isActive }

    @objc func kill() -> Bool {
        return self.runningApplication.terminate()
    }

    @objc func kill9() -> Bool {
        return self.runningApplication.forceTerminate()
    }

    @objc var mainWindow: HSWindow? {
        guard let mainWindow: UIElement = try? self.axUIElement?.attribute(.mainWindow) else {
            return nil
        }
        return HSWindow(element: mainWindow, app: self.runningApplication)
    }

    @objc var focusedWindow: HSWindow? {
        guard let focusedWindow: UIElement = try? self.axUIElement?.attribute(.focusedWindow) else {
            return nil
        }
        return HSWindow(element: focusedWindow, app: self.runningApplication)
    }

    @objc var allWindows: [HSWindow] {
        guard let allWindows: [UIElement] = try? self.axUIElement?.arrayAttribute(.windows) else {
            return []
        }
        return allWindows.compactMap { HSWindow(element: $0, app: self.runningApplication) }
    }

    @objc var visibleWindows: [HSWindow] {
        return allWindows.filter { $0.isVisible }
    }

    @objc func axElement() -> HSAXElement? {
        guard let axApp = Application(self.runningApplication) else {
            AKError("hs.application.axElement(): Failed to create AXElement for \(self.title ?? "unknown")")
            return nil
        }
        return HSAXElement(element: axApp)
    }

    // MARK: - Focus and visibility

    @objc func activate(_ allWindows: Bool) {
        let options: NSApplication.ActivationOptions = allWindows ? [.activateAllWindows] : []
        runningApplication.activate(options: options)
    }

    @objc func hide() {
        runningApplication.hide()
    }

    @objc func unhide() {
        runningApplication.unhide()
    }

    @objc var isRunning: Bool {
        !runningApplication.isTerminated
    }

    @objc var kind: String {
        switch runningApplication.activationPolicy {
        case .regular:    return "standard"
        case .accessory:  return "accessory"
        case .prohibited: return "background"
        @unknown default: return "unknown"
        }
    }

    // MARK: - Window search

    @objc func findWindow(_ pattern: String) -> [HSWindow] {
        let lower = pattern.lowercased()
        return allWindows.filter { ($0.title ?? "").lowercased().contains(lower) }
    }

    @objc func getWindow(_ title: String) -> HSWindow? {
        return allWindows.first { $0.title == title }
    }

    // MARK: - Menu traversal

    @objc func getMenuItems() -> [[String: Any]]? {
        guard let menuBar: UIElement = try? axUIElement?.attribute(.menuBar) else {
            AKError("hs.application.getMenuItems: Failed to get menu bar for \(self.title ?? "unknown")")
            return nil
        }
        guard let menuBarItems: [UIElement] = try? menuBar.attribute(.children) else {
            return []
        }
        return menuBarItems.compactMap { menuBarItemToDict($0) }
    }

    @objc func findMenuItem(_ item: JSValue) -> [String: Any]? {
        guard let element = findMenuElement(matching: item) else { return nil }
        let title: String = (try? element.attribute(.title)) ?? ""
        let enabled: Bool = (try? element.attribute(.enabled)) ?? false
        return ["title": title, "enabled": enabled]
    }

    @objc func selectMenuItem(_ item: JSValue) -> Bool {
        guard let element = findMenuElement(matching: item) else { return false }
        do {
            try element.performAction(.press)
            return true
        } catch {
            AKError("hs.application.selectMenuItem: \(error.localizedDescription)")
            return false
        }
    }

    private func findMenuElement(matching item: JSValue) -> UIElement? {
        guard let menuBar: UIElement = try? axUIElement?.attribute(.menuBar),
              let menuBarItems: [UIElement] = try? menuBar.attribute(.children) else {
            return nil
        }

        if item.isString {
            let target = (item.toString() ?? "").lowercased()
            for barItem in menuBarItems {
                if let found = searchMenuElement(withTitle: target, in: barItem) {
                    return found
                }
            }
            return nil
        }

        if item.isArray {
            let path = (item.toArray() ?? []).compactMap { $0 as? String }
            guard let first = path.first else { return nil }
            guard let topItem = menuBarItems.first(where: {
                ((try? $0.attribute(.title) as String?) ?? "").lowercased() == first.lowercased()
            }) else { return nil }
            return path.count == 1 ? topItem : navigateMenuPath(Array(path.dropFirst()), from: topItem)
        }

        return nil
    }

    private func searchMenuElement(withTitle title: String, in element: UIElement) -> UIElement? {
        guard let children: [UIElement] = try? element.attribute(.children) else { return nil }
        for child in children {
            let childTitle = ((try? child.attribute(.title) as String?) ?? "").lowercased()
            if childTitle == title { return child }
            if let found = searchMenuElement(withTitle: title, in: child) { return found }
        }
        return nil
    }

    private func navigateMenuPath(_ path: [String], from element: UIElement) -> UIElement? {
        guard let children: [UIElement] = try? element.attribute(.children) else { return nil }
        let target = path[0].lowercased()
        for child in children {
            let childTitle = ((try? child.attribute(.title) as String?) ?? "").lowercased()
            if childTitle == target {
                return path.count == 1 ? child : navigateMenuPath(Array(path.dropFirst()), from: child)
            }
        }
        return nil
    }

    private func menuBarItemToDict(_ element: UIElement) -> [String: Any]? {
        let title: String = (try? element.attribute(.title)) ?? ""
        var dict: [String: Any] = ["title": title]
        if let children: [UIElement] = try? element.attribute(.children),
           let menu = children.first,
           let items: [UIElement] = try? menu.attribute(.children) {
            dict["items"] = items.compactMap { menuItemToDict($0) }
        }
        return dict
    }

    private func menuItemToDict(_ element: UIElement) -> [String: Any]? {
        if (try? element.role()?.rawValue) == "AXMenuItemSeparator" {
            return ["title": "-", "isSeparator": true]
        }
        let title: String = (try? element.attribute(.title)) ?? ""
        let enabled: Bool = (try? element.attribute(.enabled)) ?? false
        var dict: [String: Any] = ["title": title, "enabled": enabled]
        if let children: [UIElement] = try? element.attribute(.children),
           let submenu = children.first,
           let submenuItems: [UIElement] = try? submenu.attribute(.children) {
            dict["items"] = submenuItems.compactMap { menuItemToDict($0) }
        }
        return dict
    }
}
