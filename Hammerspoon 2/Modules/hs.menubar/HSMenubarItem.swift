//
//  HSMenubarItem.swift
//  Hammerspoon 2
//
//  A single NSStatusItem in the macOS menu bar, created via hs.menubar.new().
//  Builder-style: set an icon (SF Symbol or template PNG) and/or a title (the
//  live countdown), register a click callback, query its on-screen frame so
//  callers can anchor a popover beneath it, and remove it.
//

import Foundation
import JavaScriptCore
import AppKit

/// A single status item in the macOS menu bar, created via `hs.menubar.new()`.
/// Provides a builder-style API for setting an icon, title, click callback, and
/// querying the on-screen frame so callers can anchor a popover beneath it.
@objc protocol HSMenubarItemAPI: HSTypeAPI, JSExport {
    /// Set the status-item title (e.g. a `mm:ss` countdown). Empty string clears it.
    /// - Parameters:
    ///   - text: the string to display
    ///   - opts: `{ color?: hex string, monospaced?: bool }` — both optional
    /// - Returns: self for chaining
    /// - Example:
    /// ```js
    /// item.setTitle('47:12', { monospaced: true, color: '#5BE08B' })
    /// ```
    @objc(setTitle::) func setTitle(_ text: String, _ opts: JSValue) -> HSMenubarItem

    /// Set the status-item icon from an SF Symbol name.
    /// - Parameters:
    ///   - symbolName: an SF Symbol name (e.g. `'eye'`, `'eye.slash'`)
    ///   - opts: `{ pointSize?: number, color?: hex string, accessibilityLabel?: string }` — all optional.
    ///     When `color` is omitted the icon is a template (adapts to the menu bar).
    /// - Returns: self for chaining
    /// - Example:
    /// ```js
    /// item.setIcon('eye', { color: '#5BE08B' })
    /// ```
    @objc(setIcon::) func setIcon(_ symbolName: String, _ opts: JSValue) -> HSMenubarItem

    /// Set the status-item image from a base64-encoded PNG.
    /// - Parameters:
    ///   - base64PNG: PNG bytes, base64-encoded (a leading `data:image/png;base64,` is tolerated)
    ///   - opts: `{ template?: bool }` — template images adapt to light/dark menu bars (default true)
    /// - Returns: self for chaining
    /// - Example:
    /// ```js
    /// item.setImage(myBase64Png, { template: true })
    /// ```
    @objc(setImage::) func setImage(_ base64PNG: String, _ opts: JSValue) -> HSMenubarItem

    /// Set the status-item image from an SVG document string. Rendered as a
    /// template by default so macOS draws it adaptively (white on the dark menu
    /// bar, black on light). Ideal for a vector glyph you regenerate over time
    /// (e.g. a progress ring).
    /// - Parameters:
    ///   - svg: an SVG document string (should include an `xmlns`)
    ///   - opts: `{ template?: bool, size?: number }` — template defaults true, size defaults 18 (pt)
    /// - Returns: self for chaining
    /// - Example:
    /// ```js
    /// item.setSVG('<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24"><circle cx="12" cy="12" r="8" fill="none" stroke="#000" stroke-width="2"/></svg>', {})
    /// ```
    @objc(setSVG::) func setSVG(_ svg: String, _ opts: JSValue) -> HSMenubarItem

    /// Register a function called (with no arguments) when the item is clicked.
    /// - Parameter fn: a JavaScript function
    /// - Returns: self for chaining
    /// - Example:
    /// ```js
    /// item.setCallback(() => { /* toggle the popover */ })
    /// ```
    @objc func setCallback(_ fn: JSValue) -> HSMenubarItem

    /// Highlight (or un-highlight) the status-item button background.
    /// - Parameter on: whether to draw the highlighted background
    /// - Returns: self for chaining
    /// - Example:
    /// ```js
    /// item.highlight(true)
    /// ```
    @objc func highlight(_ on: Bool) -> HSMenubarItem

    /// The on-screen rect of the status-item button as `{x, y, w, h}`, in
    /// NSWindow (bottom-left origin) coordinates — the same convention as
    /// `hs.webview` `currentFrame()`/`setFrame()`, so a webview can be anchored
    /// to it. Returns null if the item has no realized on-screen button.
    /// - Returns: `{x, y, w, h}` or null
    /// - Example:
    /// ```js
    /// const f = item.frame()
    /// ```
    @objc func frame() -> [String: Double]?

    /// Remove the status item from the menu bar.
    /// - Example:
    /// ```js
    /// item.remove()
    /// ```
    @objc func remove()
}

@_documentation(visibility: private)
@MainActor
@objc class HSMenubarItem: NSObject, HSMenubarItemAPI {
    @objc var typeName = "HSMenubarItem"
    let id = UUID()

    private weak var module: HSMenubarModule?
    private var statusItem: NSStatusItem?
    private var clickCallback: JSValue?

    init(module: HSMenubarModule) {
        self.module = module
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = ""
        AKTrace("Init of HSMenubarItem: \(id)")
    }

    @objc(setTitle::) func setTitle(_ text: String, _ opts: JSValue) -> HSMenubarItem {
        guard let button = statusItem?.button else { return self }
        var attrs: [NSAttributedString.Key: Any] = [:]
        let monospaced = opts.isObject && (opts.forProperty("monospaced")?.toBool() ?? false)
        attrs[.font] = monospaced
            ? NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize - 1, weight: .medium)
            : NSFont.menuBarFont(ofSize: 0)
        if opts.isObject, let hex = opts.forProperty("color")?.toString(), let c = HSMenubarItem.color(fromHex: hex) {
            attrs[.foregroundColor] = c
        }
        button.attributedTitle = NSAttributedString(string: text, attributes: attrs)
        return self
    }

    @objc(setIcon::) func setIcon(_ symbolName: String, _ opts: JSValue) -> HSMenubarItem {
        guard let button = statusItem?.button else { return self }
        let label = (opts.isObject ? opts.forProperty("accessibilityLabel")?.toString() : nil) ?? symbolName
        var image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label)
        if opts.isObject, let pt = opts.forProperty("pointSize")?.toNumber()?.doubleValue, pt > 0 {
            image = image?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: pt, weight: .regular))
        }
        if opts.isObject, let hex = opts.forProperty("color")?.toString(), let c = HSMenubarItem.color(fromHex: hex) {
            image?.isTemplate = false
            button.contentTintColor = c
        } else {
            image?.isTemplate = true
            button.contentTintColor = nil
        }
        button.image = image
        return self
    }

    @objc(setImage::) func setImage(_ base64PNG: String, _ opts: JSValue) -> HSMenubarItem {
        guard let button = statusItem?.button else { return self }
        // Strip any `data:<mime>;base64,` prefix, then decode tolerantly — wrapped
        // base64 (newlines every 76 chars) is common from CLI `base64` output.
        var cleaned = base64PNG
        if let r = cleaned.range(of: ";base64,") { cleaned = String(cleaned[r.upperBound...]) }
        guard let data = Data(base64Encoded: cleaned, options: .ignoreUnknownCharacters),
              let image = NSImage(data: data) else {
            AKWarning("hs.menubar setImage: could not decode base64 PNG")
            return self
        }
        image.isTemplate = !(opts.isObject && opts.forProperty("template")?.toBool() == false)
        button.image = image
        return self
    }

    @objc(setSVG::) func setSVG(_ svg: String, _ opts: JSValue) -> HSMenubarItem {
        guard let button = statusItem?.button else { return self }
        guard let data = svg.data(using: .utf8), let svgImage = NSImage(data: data) else {
            AKWarning("hs.menubar setSVG: could not parse SVG")
            return self
        }
        let wantsTemplate = !(opts.isObject && opts.forProperty("template")?.toBool() == false)
        let size = (opts.isObject ? opts.forProperty("size")?.toNumber()?.doubleValue : nil) ?? 18
        let dim = size > 0 ? size : 18
        let target = NSSize(width: dim, height: dim)

        if wantsTemplate {
            button.image = HSMenubarItem.templateBitmap(from: svgImage, size: dim)
        } else {
            svgImage.size = target
            svgImage.isTemplate = false
            button.image = svgImage
        }
        return self
    }

    /// Rasterize an (SVG-backed) NSImage into a bitmap and mark it a template.
    ///
    /// An NSImage backed by an SVG representation does NOT honor `isTemplate` in
    /// a status button — it draws the SVG's literal colors (e.g. black), which is
    /// invisible on a dark menu bar. Drawing into a bitmap and marking THAT a
    /// template makes AppKit ignore the RGB and tint the alpha mask with the
    /// system-decided menu-bar color (white on dark, black on light,
    /// highlight-aware) — exactly like an SF Symbol template.
    static func templateBitmap(from image: NSImage, size: CGFloat) -> NSImage {
        let target = NSSize(width: size, height: size)
        let bitmap = NSImage(size: target)
        bitmap.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: target),
                   from: .zero, operation: .sourceOver, fraction: 1.0)
        bitmap.unlockFocus()
        bitmap.isTemplate = true
        return bitmap
    }

    @objc func setCallback(_ fn: JSValue) -> HSMenubarItem {
        if fn.isObject {
            clickCallback = fn
            statusItem?.button?.target = self
            statusItem?.button?.action = #selector(handleClick(_:))
        } else {
            // Nullish arg unregisters: drop the callback and make the button inert.
            clickCallback = nil
            statusItem?.button?.target = nil
            statusItem?.button?.action = nil
        }
        return self
    }

    @objc func highlight(_ on: Bool) -> HSMenubarItem {
        statusItem?.button?.highlight(on)
        return self
    }

    @objc func frame() -> [String: Double]? {
        guard let button = statusItem?.button, let window = button.window else { return nil }
        let inWindow = button.convert(button.bounds, to: nil)
        let onScreen = window.convertToScreen(inWindow)
        return ["x": onScreen.minX, "y": onScreen.minY, "w": onScreen.width, "h": onScreen.height]
    }

    @objc func remove() {
        if let item = statusItem { NSStatusBar.system.removeStatusItem(item) }
        statusItem = nil
        clickCallback = nil
        module?.unregister(id: id)
    }

    @objc private func handleClick(_ sender: Any?) {
        // callSafely formats + logs any JS exception and clears it from the
        // engine's exception slot (raw .call would leave it dangling).
        _ = clickCallback?.callSafely(withArguments: [], context: "hs.menubar click")
    }

    // #rrggbb → NSColor (sRGB). Returns nil for malformed input.
    static func color(fromHex hex: String) -> NSColor? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255.0,
                       green: CGFloat((v >> 8) & 0xFF) / 255.0,
                       blue: CGFloat(v & 0xFF) / 255.0,
                       alpha: 1.0)
    }

    isolated deinit {
        AKTrace("Deinit of HSMenubarItem: \(id)")
    }
}
