//
//  HSWebview.swift
//  Hammerspoon 2
//
//  One WKWebView hosted inside a borderless NSWindow. Builder-style chain
//  for URL/HTML, window styling, level, message handlers, and lifecycle.
//
//  Bridge model: register named handlers via `setMessageHandler(name, fn)`.
//  JS in the page calls `window.webkit.messageHandlers.<name>.postMessage(body)`
//  and the registered callback fires with the deserialized body. Replies go
//  the other way via `evaluateJavaScript(code)`.
//

import Foundation
import JavaScriptCore
import AppKit
import SwiftUI
import WebKit

/// A WKWebView hosted inside a borderless NSWindow, created via `hs.webview.new()`.
/// Provides a builder-style API for loading URLs or HTML, styling the window,
/// registering JS message handlers, evaluating JavaScript, and managing the window lifecycle.
@objc protocol HSWebviewAPI: HSTypeAPI, JSExport {

    // MARK: - Content loading

    /// Load a URL into the webview. Accepts `https://`, `http://`, and `file://` URLs.
    /// File URLs must be absolute paths; tilde is expanded.
    /// - Parameter urlString: the URL to load
    /// - Returns: self for chaining
    /// - Example:
    /// ```js
    /// hs.webview.new({x:0,y:0,w:600,h:400}).url('https://example.com').show()
    /// ```
    @objc func url(_ urlString: String) -> HSWebview

    /// Load HTML source directly into the webview.
    /// - Parameters:
    ///   - html: HTML source string
    ///   - baseURL: optional base URL (string) for resolving relative refs; null to use about:blank
    /// - Returns: self for chaining
    /// - Example:
    /// ```js
    /// wv.html('<h1>hi</h1>').show()
    /// ```
    @objc(html::) func html(_ html: String, _ baseURL: JSValue) -> HSWebview

    /// Reload the currently-loaded content.
    /// - Returns: self for chaining
    @objc func reload() -> HSWebview

    // MARK: - Window styling

    /// Configure window chrome.
    /// - Parameter opts: `{ titled?, closable?, resizable?, miniaturizable?, transparent? }` — all optional booleans.
    ///   `transparent: true` makes the NSWindow opaque-bg false so the page's own background shows through.
    /// - Returns: self for chaining
    /// - Example:
    /// ```js
    /// wv.windowStyle({ titled: false, closable: false, transparent: true })
    /// ```
    @objc func windowStyle(_ opts: JSValue) -> HSWebview

    /// Set the window level by name. Same vocabulary as `hs.ui.window.level()`.
    /// - Parameter name: `'normal' | 'floating' | 'modal' | 'popup' | 'screensaver' | 'mainmenu' | 'status'`
    /// - Returns: self for chaining
    @objc func level(_ name: String) -> HSWebview

    /// Allow this window to become key (capture keyboard focus). Default true for webviews.
    /// - Parameter value: whether the window can become key
    /// - Returns: self for chaining
    @objc func canBecomeKey(_ value: Bool) -> HSWebview

    /// Never activate Hammerspoon 2 when this window is shown or clicked. The
    /// webview is hosted in a non-activating panel: the page still gets mouse
    /// events (buttons click, CSS `:hover` fires) but the frontmost app keeps
    /// focus throughout — what you want for a toast or notification overlay.
    /// Combine with `canBecomeKey(true)` for a Spotlight-style panel that takes
    /// keyboard input while the previous app stays active, or with
    /// `canBecomeKey(false)` so the page never captures keyboard at all.
    /// Must be set before `show()`.
    /// - Parameter value: true to host the webview in a non-activating panel
    /// - Returns: self for chaining
    /// - Example:
    /// ```js
    /// const toast = hs.webview.new({x: 100, y: 100, w: 400, h: 200})
    ///   .windowStyle({ titled: false, transparent: true })
    ///   .nonActivating(true)
    ///   .canBecomeKey(false)
    ///   .url('file://~/toast/index.html')
    ///   .show()  // appears without stealing focus from the current app
    /// ```
    @objc func nonActivating(_ value: Bool) -> HSWebview

    /// Make the window click-through: mouse events pass to whatever is beneath it. Essential for a
    /// transparent, screen-covering HUD overlay so it never steals the user's input.
    /// - Parameter value: true to ignore mouse events
    /// - Returns: self for chaining
    @objc func ignoresMouseEvents(_ value: Bool) -> HSWebview

    /// Make the window appear on every Space and stay put across Space switches (HUD overlay).
    /// - Parameter value: true to join all Spaces (canJoinAllSpaces + stationary)
    /// - Returns: self for chaining
    @objc func canJoinAllSpaces(_ value: Bool) -> HSWebview

    /// Center the window on the main screen on `show()`.
    /// - Returns: self for chaining
    @objc func center() -> HSWebview

    /// Set window corner radius. Applied to the contentView (clipped) so the
    /// rounded shape is preserved when the window is transparent.
    /// - Parameter radius: pixel radius
    /// - Returns: self for chaining
    @objc func windowCornerRadius(_ radius: Double) -> HSWebview

    /// Set the background color used by the host NSWindow and content wrapper.
    /// This color is what users see during the brief window between window
    /// creation and the page's own background painting — set it to match your
    /// page's body background to eliminate the "white flash" on open. Also
    /// disables the WKWebView's own opaque background so the window color is
    /// visible through any gaps before/around the page content.
    /// - Parameter color: hex string (e.g. `'#18181C'`) or an `HSColor`
    /// - Returns: self for chaining
    /// - Example:
    /// ```js
    /// hs.webview.new({x:0,y:0,w:600,h:400}).backgroundColor('#18181C').url(...).show()
    /// ```
    @objc func backgroundColor(_ color: JSValue) -> HSWebview

    // MARK: - Lifecycle

    /// Keep the page rendering even when the window is inactive or considered
    /// not visible. By default WebKit suspends a page whose window is non-key /
    /// occluded — for a transparent, click-through HUD overlay (which can never
    /// become key) the compositor parks after a few seconds and JS-driven UI
    /// changes stop painting. Pass `true` BEFORE `show()` to opt the page out
    /// of that suspension (`WKPreferences.inactiveSchedulingPolicy = .none`).
    /// - Parameter value: whether to keep rendering while inactive
    /// - Returns: self for chaining
    /// - Example:
    /// ```js
    /// const hud = hs.webview.new({x:0, y:0, w:800, h:600})
    ///   .windowStyle({ transparent: true })
    ///   .ignoresMouseEvents(true)
    ///   .keepsRenderingWhenInactive(true)
    /// ```
    @objc func keepsRenderingWhenInactive(_ value: Bool) -> HSWebview

    /// Show the window. If already shown, brings it to front.
    /// - Returns: self for chaining
    @objc func show() -> HSWebview

    /// Hide the window. Keeps the WKWebView and its loaded page in memory.
    /// - Returns: self for chaining
    @objc func hide() -> HSWebview

    /// Close and destroy the window. Drops the WKWebView and frees handlers.
    @objc func close()

    /// Bring the window to the foreground without reordering across spaces.
    /// - Returns: self for chaining
    @objc func bringToFront() -> HSWebview

    /// Return the current on-screen frame as `{x, y, w, h}`, or null if not shown.
    /// - Returns: `{x, y, w, h}` in NSWindow (bottom-left origin) coordinates, or null if not shown
    @objc func currentFrame() -> [String: Double]?

    /// Resize and/or move the on-screen window.
    /// - Parameter rect: `{ x, y, w, h }` in NSWindow coordinates
    /// - Returns: self for chaining
    @objc func setFrame(_ rect: JSValue) -> HSWebview

    /// Render the page to a PNG file at the given path. Uses WKWebView's own
    /// `takeSnapshot`, which renders in the web content process — so it sees the
    /// real page even when WebKit composites it out-of-process (GPU-accelerated
    /// layers), where an AppKit `cacheDisplay` capture intermittently came back
    /// blank/white. No Screen Recording permission is required. The capture is
    /// asynchronous: pass a callback to learn when the file is written.
    /// - Parameters:
    ///   - path: absolute filesystem path to write
    ///   - callback: optional `(ok, errorMessage)` — `ok` is true once the PNG is
    ///     written; on failure `errorMessage` describes why. Pass `null` to skip.
    /// - Example:
    /// ```js
    /// wv.snapshotToPNG('/tmp/page.png', (ok, err) => console.log('snapshot: ' + (ok ? 'ok' : err)))
    /// ```
    @objc(snapshotToPNG::) func snapshotToPNG(_ path: String, _ callback: JSValue)

    // MARK: - Bridge

    /// Register a named handler for messages posted from JS.
    /// In the page, call `window.webkit.messageHandlers.<name>.postMessage(body)`.
    /// The Swift callback fires with the deserialized body (object/string/number).
    /// Pass `null` to unregister.
    /// - Parameters:
    ///   - name: handler name (matches the page's `messageHandlers.<name>`)
    ///   - callback: function to call with each message body, or null to remove
    /// - Returns: self for chaining
    /// - Example:
    /// ```js
    /// wv.setMessageHandler('vibecast', (msg) => {
    ///   const { id, op, args } = msg
    ///   const reply = JSON.stringify({ ok: true })
    ///   wv.evaluateJavaScript(`__vc.resolve(${id}, ${reply})`)
    /// })
    /// ```
    @objc(setMessageHandler::) func setMessageHandler(_ name: String, _ callback: JSValue) -> HSWebview

    /// Inject JavaScript that runs at document-start, before the page's own scripts.
    /// Use to install a bridge client so postMessage calls work from page load.
    /// - Parameter source: JavaScript source
    /// - Returns: self for chaining
    @objc func injectUserScript(_ source: String) -> HSWebview

    /// Evaluate a JS expression inside the page. Optional callback receives
    /// `(result, errorMessage)` — result is the stringified JS value (null if
    /// not representable as JSON), errorMessage is null on success.
    /// - Parameters:
    ///   - script: JS expression or block
    ///   - callback: optional completion `(result, error) => void`
    @objc(evaluateJavaScript::) func evaluateJavaScript(_ script: String, _ callback: JSValue)

    /// Register a callback for window lifecycle events. Currently fires with
    /// the string `'closing'` when the window is about to close.
    /// - Parameter callback: `(event) => void`
    /// - Returns: self for chaining
    @objc func windowCallback(_ callback: JSValue) -> HSWebview

    /// Enable Safari "Inspect Element" right-click for this webview. Off by default.
    /// - Parameter enabled: whether to enable
    /// - Returns: self for chaining
    @objc func developerExtras(_ enabled: Bool) -> HSWebview
}

@_documentation(visibility: private)
@MainActor
@objc class HSWebview: NSObject, HSWebviewAPI, NSWindowDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    @objc var typeName = "HSWebview"

    private let webviewID = UUID()
    private weak var module: HSWebviewModule?

    // Window/view state
    private var windowFrame: CGRect
    private var nsWindow: NSWindow?
    private var webView: WKWebView?
    private var configuration: WKWebViewConfiguration
    private var pendingUserScripts: [WKUserScript] = []
    private var pendingHandlers: [String: JSValue] = [:]
    private var installedHandlerNames: Set<String> = []

    // Styling
    private var isBorderless: Bool = true
    private var isClosable: Bool = true
    private var isResizable: Bool = false
    private var isMiniaturizable: Bool = false
    private var isTransparent: Bool = false
    private var windowLevel: NSWindow.Level = .floating
    private var canBecomeKeyOverride: Bool = true
    private var isNonActivating: Bool = false
    private var ignoresMouseEventsValue: Bool = false
    private var keepsRenderingInactive: Bool = false
    private var joinAllSpaces: Bool = false
    private var shouldCenter: Bool = false
    private var cornerRadius: CGFloat = 0
    private var developerExtrasEnabled: Bool = false
    private var bgColor: NSColor? = nil

    // Pending content
    private enum PendingContent {
        case url(URL)
        case html(String, URL?)
    }
    private var pendingContent: PendingContent?

    // Callbacks
    private var lifecycleCallback: JSValue?

    init(frame: CGRect, module: HSWebviewModule) {
        self.windowFrame = frame
        self.module = module
        self.configuration = WKWebViewConfiguration()
        super.init()
    }

    isolated deinit {
        close()
        AKTrace("deinit of HSWebview: \(webviewID)")
    }

    // MARK: - Content loading

    @objc func url(_ urlString: String) -> HSWebview {
        if let u = parseURL(urlString) {
            if let wv = webView {
                wv.load(URLRequest(url: u))
            } else {
                pendingContent = .url(u)
            }
        } else {
            AKWarning("hs.webview.url: could not parse '\(urlString)'")
        }
        return self
    }

    @objc(html::) func html(_ htmlSource: String, _ baseURLValue: JSValue) -> HSWebview {
        var baseURL: URL? = nil
        if !baseURLValue.isUndefined, !baseURLValue.isNull, baseURLValue.isString,
           let s = baseURLValue.toString(), !s.isEmpty {
            baseURL = parseURL(s)
        }
        if let wv = webView {
            wv.loadHTMLString(htmlSource, baseURL: baseURL)
        } else {
            pendingContent = .html(htmlSource, baseURL)
        }
        return self
    }

    @objc func reload() -> HSWebview {
        webView?.reload()
        return self
    }

    private func parseURL(_ s: String) -> URL? {
        // file://... paths can contain a tilde; expand it.
        if s.hasPrefix("file://") {
            let path = String(s.dropFirst("file://".count))
            let expanded = NSString(string: path).expandingTildeInPath
            return URL(fileURLWithPath: expanded)
        }
        return URL(string: s)
    }

    // MARK: - Window styling

    @objc func windowStyle(_ opts: JSValue) -> HSWebview {
        guard opts.isObject else { return self }
        if let b = boolFor(opts, "titled")          { isBorderless = !b }
        if let b = boolFor(opts, "closable")        { isClosable = b }
        if let b = boolFor(opts, "resizable")       { isResizable = b }
        if let b = boolFor(opts, "miniaturizable") { isMiniaturizable = b }
        if let b = boolFor(opts, "transparent")     { isTransparent = b }
        return self
    }

    private func boolFor(_ opts: JSValue, _ key: String) -> Bool? {
        guard let v = opts.objectForKeyedSubscript(key), !v.isUndefined, !v.isNull else { return nil }
        return v.toBool()
    }

    @objc func level(_ name: String) -> HSWebview {
        switch name {
        case "normal":      windowLevel = .normal
        case "floating":    windowLevel = .floating
        case "modal":       windowLevel = .modalPanel
        case "popup":       windowLevel = .popUpMenu
        case "screensaver": windowLevel = .screenSaver
        case "mainmenu":    windowLevel = .mainMenu
        case "status":      windowLevel = .statusBar
        default:            windowLevel = .floating
        }
        return self
    }

    @objc func canBecomeKey(_ value: Bool) -> HSWebview {
        canBecomeKeyOverride = value
        return self
    }

    @objc func nonActivating(_ value: Bool) -> HSWebview {
        isNonActivating = value
        return self
    }

    @objc func ignoresMouseEvents(_ value: Bool) -> HSWebview {
        ignoresMouseEventsValue = value
        return self
    }

    @objc func canJoinAllSpaces(_ value: Bool) -> HSWebview {
        joinAllSpaces = value
        return self
    }

    @objc func center() -> HSWebview {
        shouldCenter = true
        return self
    }

    @objc func windowCornerRadius(_ radius: Double) -> HSWebview {
        cornerRadius = CGFloat(radius)
        return self
    }

    @objc func developerExtras(_ enabled: Bool) -> HSWebview {
        developerExtrasEnabled = enabled
        // Configure now; takes effect on the WKWebView created in show().
        configuration.preferences.setValue(enabled, forKey: "developerExtrasEnabled")
        return self
    }

    @objc func backgroundColor(_ value: JSValue) -> HSWebview {
        if let swiftColor = value.toColor() {
            bgColor = NSColor(swiftColor)
        }
        // If the window is already up, apply immediately.
        if let win = nsWindow, let bg = bgColor {
            applyBackground(window: win, color: bg)
        }
        return self
    }

    private func applyBackground(window: NSWindow, color: NSColor) {
        // Paint the wrapper layer rather than the NSWindow itself. The NSWindow
        // stays clear so anything outside the wrapper's rounded-corner mask
        // (if cornerRadius > 0) is transparent — otherwise the rectangular
        // NSWindow bg would render outside the rounded mask, producing visible
        // dark squares at the corners.
        window.backgroundColor = .clear
        window.isOpaque = false
        if let wrapper = window.contentView {
            wrapper.wantsLayer = true
            wrapper.layer?.backgroundColor = color.cgColor
            // Defensive: ensure the corner mask is in place even if
            // backgroundColor() was called before show() set it.
            if cornerRadius > 0 {
                wrapper.layer?.cornerRadius = cornerRadius
                wrapper.layer?.masksToBounds = true
            }
        }
        // Make WKWebView transparent so the wrapper color shows during
        // the brief load gap — eliminates the default "white flash".
        webView?.setValue(false, forKey: "drawsBackground")
        webView?.wantsLayer = true
        webView?.layer?.backgroundColor = color.cgColor
    }

    // MARK: - Lifecycle

    @objc func keepsRenderingWhenInactive(_ value: Bool) -> HSWebview {
        keepsRenderingInactive = value
        // Applies to the WKWebView built in show(); set live too if already up.
        configuration.preferences.inactiveSchedulingPolicy = value ? .none : .suspend
        if let wv = webView { applyOcclusionOptOut(wv) }
        return self
    }

    /// WebKit suspends a page whose window it deems not visible — and an always-on-top
    /// transparent HUD usually IS "not visible": the window server drops fully-clear
    /// surfaces from its visible set, so `NSApp.occlusionState` lacks `.visible` for a
    /// menu-bar app whose only window is the HUD. The page then parks (visibilityState
    /// 'hidden', rAF stopped) and JS-driven UI changes execute but never paint.
    /// `inactiveSchedulingPolicy` does NOT cover this case (measured); the only switch is
    /// WebKit's occlusion-detection SPI — the same private-KVC family as the long-standing
    /// `drawsBackground` above. Guarded by responds(to:): a future WebKit that removes the
    /// SPI degrades to the old (suspending) behavior instead of crashing on KVC.
    private func applyOcclusionOptOut(_ wv: WKWebView) {
        guard keepsRenderingInactive else { return }
        if wv.responds(to: NSSelectorFromString("_setWindowOcclusionDetectionEnabled:")) {
            wv.setValue(false, forKey: "windowOcclusionDetectionEnabled")
        } else {
            AKWarning("hs.webview.keepsRenderingWhenInactive: occlusion-detection SPI unavailable — page may suspend while the window is considered not visible")
        }
    }

    @objc func show() -> HSWebview {
        if nsWindow != nil {
            // Already shown — just bring forward.
            return bringToFront()
        }
        if keepsRenderingInactive {
            configuration.preferences.inactiveSchedulingPolicy = .none
        }
        defer { if let wv = webView { applyOcclusionOptOut(wv) } }

        // Install the user content controller + any pending handlers.
        let ucc = WKUserContentController()
        for (name, cb) in pendingHandlers {
            ucc.add(WeakScriptHandler(target: self), name: name)
            installedHandlerNames.insert(name)
            pendingHandlers[name] = cb        // keep callback retained via handlerCallbacks below
        }
        for s in pendingUserScripts { ucc.addUserScript(s) }
        configuration.userContentController = ucc

        // Build the WKWebView and configure its visual style first.
        let wv = WKWebView(frame: CGRect(origin: .zero, size: windowFrame.size),
                           configuration: configuration)
        wv.autoresizingMask = [.width, .height]
        wv.navigationDelegate = self
        if isTransparent {
            wv.setValue(false, forKey: "drawsBackground")
        }
        self.webView = wv

        // Move stashed handler callbacks (pendingHandlers) into handlerCallbacks
        // — the actual JSValue refs live here, the WKUserContentController only
        // knows the names.
        handlerCallbacks = pendingHandlers
        pendingHandlers.removeAll()

        // Build the host NSWindow.
        var styleMask: NSWindow.StyleMask = isBorderless ? [.borderless] : [.titled]
        if !isBorderless {
            if isClosable        { styleMask.insert(.closable) }
            if isResizable       { styleMask.insert(.resizable) }
            if isMiniaturizable  { styleMask.insert(.miniaturizable) }
        }
        let window: NSWindow
        if isNonActivating {
            // .nonactivatingPanel requires an NSPanel host: clicks reach the page
            // without activating the app, so the frontmost app keeps focus.
            styleMask.insert(.nonactivatingPanel)
            let panel = HSWebviewNonActivatingPanel(contentRect: windowFrame, styleMask: styleMask, backing: .buffered, defer: false)
            panel.allowKey = canBecomeKeyOverride
            // NSPanel hides itself when the app deactivates by default — fatal
            // for a background app's overlay, which must survive focus changes.
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = true
            // CSS :hover in the page depends on mouse-moved events arriving even
            // though the window never becomes key.
            panel.acceptsMouseMovedEvents = true
            window = panel
        } else if canBecomeKeyOverride {
            window = HSWebviewKeyAcceptingWindow(contentRect: windowFrame, styleMask: styleMask, backing: .buffered, defer: false)
        } else {
            window = NSWindow(contentRect: windowFrame, styleMask: styleMask, backing: .buffered, defer: false)
        }
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.level = windowLevel
        window.ignoresMouseEvents = ignoresMouseEventsValue
        if joinAllSpaces { window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle] }

        // Host view = a wrapper that contains the WKWebView. We need a wrapper
        // when applying corner radius so the webview's own layer doesn't fight us.
        let wrapper = NSView(frame: NSRect(origin: .zero, size: windowFrame.size))
        wrapper.autoresizesSubviews = true
        wrapper.addSubview(wv)
        window.contentView = wrapper

        if isTransparent {
            window.backgroundColor = .clear
            window.isOpaque = false
        }
        if cornerRadius > 0 {
            wrapper.wantsLayer = true
            wrapper.layer?.cornerRadius = cornerRadius
            wrapper.layer?.masksToBounds = true
            window.backgroundColor = .clear
            window.isOpaque = false
            wv.layer?.cornerRadius = cornerRadius
            wv.layer?.masksToBounds = true
        }
        // If the user gave us a background color, paint it on the window + wrapper
        // + webview backing layer *before* makeKeyAndOrderFront so there is no
        // white default-WKWebView flash while the page loads.
        if let bg = bgColor {
            applyBackground(window: window, color: bg)
        }

        if shouldCenter, let screen = NSScreen.main {
            let w = windowFrame.size.width
            let h = windowFrame.size.height
            let x = screen.frame.midX - w / 2
            let y = screen.frame.midY - h / 2
            window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: false)
        }

        // Push pending URL/HTML now that the webview is alive.
        switch pendingContent {
        case .url(let u):
            // file:// URLs: allow read access broadly enough that <img src="file://…">
            // for assets outside the page's own directory (e.g. an image cache
            // under ~/Library/Application Support) resolves. We grant access to
            // the user's home directory by default — WKWebView will still
            // sandbox the page from network/cross-origin tricks.
            if u.isFileURL {
                let home = FileManager.default.homeDirectoryForCurrentUser
                wv.loadFileURL(u, allowingReadAccessTo: home)
            } else {
                wv.load(URLRequest(url: u))
            }
        case .html(let s, let base):
            wv.loadHTMLString(s, baseURL: base)
        case .none:
            break
        }

        if canBecomeKeyOverride && !isNonActivating {
            NSApp.activate(ignoringOtherApps: true)
        }
        // A non-activating panel with canBecomeKey(true) takes keyboard here
        // without activating the app (Spotlight-style). Windows that refuse key
        // status (canBecomeKey false, or plain borderless NSWindows) skip the
        // makeKey attempt — AppKit logs a warning otherwise.
        if window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
        }
        window.orderFrontRegardless()

        self.nsWindow = window
        module?.register(self, id: webviewID)
        return self
    }

    @objc func hide() -> HSWebview {
        nsWindow?.orderOut(nil)
        return self
    }

    @objc func close() {
        guard nsWindow != nil else { return }

        // Tell JS first so any cleanup runs.
        lifecycleCallback?.callSafely(withArguments: ["closing"], context: "hs.webview close")

        // Tear down userContentController handlers to drop strong refs.
        for n in installedHandlerNames {
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: n)
        }
        installedHandlerNames.removeAll()
        handlerCallbacks.removeAll()

        webView?.navigationDelegate = nil
        webView?.removeFromSuperview()
        webView = nil

        nsWindow?.delegate = nil
        nsWindow?.close()
        nsWindow = nil

        module?.unregister(id: webviewID)
    }

    @objc func bringToFront() -> HSWebview {
        nsWindow?.orderFrontRegardless()
        return self
    }

    @objc func currentFrame() -> [String: Double]? {
        guard let w = nsWindow else { return nil }
        let f = w.frame
        return ["x": f.origin.x, "y": f.origin.y, "w": f.size.width, "h": f.size.height]
    }

    @objc func setFrame(_ rect: JSValue) -> HSWebview {
        guard rect.isObject else { return self }
        let x = rect.objectForKeyedSubscript("x")?.toDouble() ?? windowFrame.origin.x
        let y = rect.objectForKeyedSubscript("y")?.toDouble() ?? windowFrame.origin.y
        let w = rect.objectForKeyedSubscript("w")?.toDouble() ?? windowFrame.size.width
        let h = rect.objectForKeyedSubscript("h")?.toDouble() ?? windowFrame.size.height
        let newFrame = CGRect(x: x, y: y, width: w, height: h)
        windowFrame = newFrame
        if let win = nsWindow {
            win.setFrame(newFrame, display: true, animate: false)
        }
        return self
    }

    @objc(snapshotToPNG::) func snapshotToPNG(_ path: String, _ callback: JSValue) {
        let cb: JSValue? = (callback.isObject) ? callback : nil
        func fail(_ msg: String) {
            AKWarning("hs.webview.snapshotToPNG: \(msg)")
            cb?.callSafely(withArguments: [false, msg], context: "hs.webview snapshotToPNG")
        }
        guard let wv = webView else {
            fail("webview not shown yet — call show() first")
            return
        }
        wv.takeSnapshot(with: nil) { image, err in
            // WKWebView calls completion on main, but be explicit (same as evaluateJavaScript).
            MainActor.assumeIsolated {
                guard err == nil, let image else {
                    fail(err?.localizedDescription ?? "no image returned")
                    return
                }
                guard let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    fail("PNG encode failed")
                    return
                }
                do {
                    try png.write(to: URL(fileURLWithPath: path))
                    cb?.callSafely(withArguments: [true, NSNull()], context: "hs.webview snapshotToPNG")
                } catch {
                    fail("write failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Bridge

    private var handlerCallbacks: [String: JSValue] = [:]

    @objc(setMessageHandler::) func setMessageHandler(_ name: String, _ callback: JSValue) -> HSWebview {
        let isNullish = callback.isNull || callback.isUndefined
        if isNullish {
            // Remove
            if let wv = webView, installedHandlerNames.contains(name) {
                wv.configuration.userContentController.removeScriptMessageHandler(forName: name)
            }
            installedHandlerNames.remove(name)
            handlerCallbacks.removeValue(forKey: name)
            pendingHandlers.removeValue(forKey: name)
            return self
        }
        guard callback.isObject else {
            AKWarning("hs.webview.setMessageHandler: callback must be a function for '\(name)'")
            return self
        }
        if let wv = webView {
            // Replace if already installed
            if installedHandlerNames.contains(name) {
                wv.configuration.userContentController.removeScriptMessageHandler(forName: name)
            }
            wv.configuration.userContentController.add(WeakScriptHandler(target: self), name: name)
            installedHandlerNames.insert(name)
            handlerCallbacks[name] = callback
        } else {
            // Defer until show()
            pendingHandlers[name] = callback
        }
        return self
    }

    @objc func injectUserScript(_ source: String) -> HSWebview {
        let script = WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        if let wv = webView {
            wv.configuration.userContentController.addUserScript(script)
        } else {
            pendingUserScripts.append(script)
        }
        return self
    }

    @objc(evaluateJavaScript::) func evaluateJavaScript(_ script: String, _ callback: JSValue) {
        guard let wv = webView else {
            AKWarning("hs.webview.evaluateJavaScript: webview not shown yet — call show() first")
            return
        }
        let cb: JSValue? = (callback.isObject) ? callback : nil
        wv.evaluateJavaScript(script) { result, err in
            // WKWebView calls completion on main, but be explicit.
            MainActor.assumeIsolated {
                guard let cb else { return }
                let resultArg: Any = result ?? NSNull()
                let errArg: Any
                if let err {
                    errArg = err.localizedDescription
                } else {
                    errArg = NSNull()
                }
                cb.callSafely(withArguments: [resultArg, errArg], context: "hs.webview evaluateJavaScript")
            }
        }
    }

    @objc func windowCallback(_ callback: JSValue) -> HSWebview {
        lifecycleCallback = (callback.isObject) ? callback : nil
        return self
    }

    // MARK: - WKScriptMessageHandler dispatch (via WeakScriptHandler)

    fileprivate func dispatchScriptMessage(_ message: WKScriptMessage) {
        guard let cb = handlerCallbacks[message.name] else { return }
        // Body is bridged automatically (Dictionary/Array/String/Number/null).
        let body = message.body
        cb.callSafely(withArguments: [body], context: "hs.webview message handler \(message.name)")
    }

    // MARK: - WKScriptMessageHandler

    nonisolated func userContentController(_ userContentController: WKUserContentController,
                                           didReceive message: WKScriptMessage) {
        // WKWebView guarantees this fires on the main thread.
        MainActor.assumeIsolated {
            dispatchScriptMessage(message)
        }
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            lifecycleCallback?.callSafely(withArguments: ["closing"], context: "hs.webview windowWillClose")
            // Mark internal state as closed without re-firing the callback.
            for n in installedHandlerNames {
                webView?.configuration.userContentController.removeScriptMessageHandler(forName: n)
            }
            installedHandlerNames.removeAll()
            handlerCallbacks.removeAll()
            webView = nil
            nsWindow?.delegate = nil
            nsWindow = nil
            module?.unregister(id: webviewID)
        }
    }
}

// MARK: - Borderless window helpers

@MainActor
private final class HSWebviewKeyAcceptingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Host for `nonActivating(true)` webviews. NSPanel + .nonactivatingPanel lets
/// the page take mouse (and, when allowed, keyboard) input while the frontmost
/// app stays active. Never main: an overlay must not capture the main-window
/// role from real document windows.
@MainActor
private final class HSWebviewNonActivatingPanel: NSPanel {
    var allowKey = false
    override var canBecomeKey: Bool { allowKey }
    override var canBecomeMain: Bool { false }
}

/// WKUserContentController retains its script message handler strongly. To
/// avoid a cycle (handler → webview → config → ucc → handler), bridge through
/// a weak holder.
@MainActor
private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: HSWebview?
    init(target: HSWebview) {
        self.target = target
        super.init()
    }
    nonisolated func userContentController(_ userContentController: WKUserContentController,
                                           didReceive message: WKScriptMessage) {
        MainActor.assumeIsolated {
            target?.userContentController(userContentController, didReceive: message)
        }
    }
}
