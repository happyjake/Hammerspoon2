//
//  HSMenubarModule.swift
//  Hammerspoon 2
//
//  `hs.menubar` namespace. Single factory: `new()` returns an HSMenubarItem
//  that wraps an NSStatusItem in the macOS menu bar with a builder-style chain.
//

import Foundation
import JavaScriptCore
import AppKit

@objc protocol HSMenubarModuleAPI: JSExport {
    /// Create a new status item in the macOS menu bar.
    /// - Returns: an `HSMenubarItem`. Chain `.setIcon(...)`, `.setTitle(...)`,
    ///   `.setCallback(fn)`, `.highlight(bool)`, and later `.remove()`.
    /// - Example:
    /// ```js
    /// const item = hs.menubar.create()
    ///     .setIcon('eye', {})
    ///     .setCallback(() => { /* open a popover */ })
    /// ```
    @objc func create() -> HSMenubarItem
}

@_documentation(visibility: private)
@MainActor
@objc class HSMenubarModule: NSObject, HSModuleAPI, HSMenubarModuleAPI {
    var name = "hs.menubar"
    let engineID: UUID

    private var items: [UUID: HSMenubarItem] = [:]

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {
        // Iterate a snapshot: item.remove() calls back into unregister(id:),
        // which mutates `items`.
        for item in Array(items.values) { item.remove() }
        items.removeAll()
    }

    isolated deinit {
        AKTrace("Deinit of hs.menubar: \(engineID)")
    }

    @objc func create() -> HSMenubarItem {
        let item = HSMenubarItem(module: self)
        items[item.id] = item
        return item
    }

    func unregister(id: UUID) {
        items.removeValue(forKey: id)
    }
}
