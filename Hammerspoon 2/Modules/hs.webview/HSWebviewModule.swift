//
//  HSWebviewModule.swift
//  Hammerspoon 2
//
//  `hs.webview` namespace. Single factory: `new(rect)` returns an HSWebview
//  that hosts a WKWebView inside an NSWindow with a builder-style chain.
//

import Foundation
import JavaScriptCore
import AppKit

@objc protocol HSWebviewModuleAPI: JSExport {
    /// Create a new webview hosted in a borderless NSWindow.
    /// - Parameter rect: `{ x, y, w, h }` in NSWindow coordinates
    /// - Returns: an `HSWebview` configured to host a WKWebView. Chain
    ///   `.url(...)`, `.html(...)`, `.windowStyle(...)`, `.level(...)`,
    ///   `.setMessageHandler(name, fn)`, then `.show()`.
    /// - Example:
    /// ```js
    /// const wv = hs.webview.new({ x: 100, y: 100, w: 800, h: 600 })
    ///     .url('https://example.com')
    ///     .level('floating')
    ///     .show()
    /// ```
    @objc func new(_ rect: JSValue) -> HSWebview?
}

@_documentation(visibility: private)
@MainActor
@objc class HSWebviewModule: NSObject, HSModuleAPI, HSWebviewModuleAPI {
    var name = "hs.webview"
    let engineID: UUID

    private var activeWebviews: [UUID: HSWebview] = [:]

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {
        for wv in activeWebviews.values { wv.close() }
        activeWebviews.removeAll()
    }

    isolated deinit {
        AKTrace("Deinit of hs.webview: \(engineID)")
    }

    @objc func new(_ rect: JSValue) -> HSWebview? {
        guard rect.isObject else {
            AKWarning("hs.webview.new: rect object {x, y, w, h} required")
            return nil
        }
        let x = rect.objectForKeyedSubscript("x")?.toDouble() ?? 0
        let y = rect.objectForKeyedSubscript("y")?.toDouble() ?? 0
        let w = rect.objectForKeyedSubscript("w")?.toDouble() ?? 800
        let h = rect.objectForKeyedSubscript("h")?.toDouble() ?? 600
        let frame = CGRect(x: x, y: y, width: w, height: h)
        let wv = HSWebview(frame: frame, module: self)
        return wv
    }

    // MARK: - Registration

    func register(_ wv: HSWebview, id: UUID) { activeWebviews[id] = wv }
    func unregister(id: UUID)              { activeWebviews.removeValue(forKey: id) }
}
