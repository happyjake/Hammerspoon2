//
//  HSUIWindow.swift
//  Hammerspoon 2
//
//  Created by Claude Code on 12/02/2026.
//

import Foundation
import JavaScriptCore
import AppKit
import SwiftUI

/// # HSUIWindow
///
/// **A custom window with declarative UI building**
///
/// `HSUIWindow` allows you to create custom borderless windows with a SwiftUI-like
/// declarative syntax. Build interfaces using shapes, text, images, and layout containers.
///
/// ## Building UI Elements
///
/// - **Shapes**: `rectangle()`, `circle()`
/// - **Text**: `text(content)`
/// - **Buttons**: `button(label)` — uses SwiftUI's native Button for press-state feedback
/// - **Images**: `image(imageValue)`
/// - **Layout**: `vstack()`, `hstack()`, `zstack()`, `spacer()`
///
/// ## Modifying Elements
///
/// - **Shape modifiers**: `fill()`, `stroke()`, `strokeWidth()`, `cornerRadius()`
/// - **Text modifiers**: `font()`, `foregroundColor()`
/// - **Image modifiers**: `resizable()`, `aspectRatio(mode)`
/// - **Layout modifiers**: `frame()`, `opacity()`, `padding()`, `spacing()`
///
/// ## Examples
///
/// **Simple window with text and shapes:**
/// ```javascript
/// hs.ui.window({x: 100, y: 100, w: 300, h: 200})
///     .vstack()
///         .spacing(10)
///         .padding(20)
///         .text("Dashboard")
///             .font(HSFont.largeTitle())
///             .foregroundColor("#FFFFFF")
///         .rectangle()
///             .fill("#4A90E2")
///             .cornerRadius(10)
///             .frame({w: "90%", h: 80})
///     .end()
///     .backgroundColor("#2C3E50")
///     .show();
/// ```
///
/// **Window with image:**
/// ```javascript
/// const img = HSImage.fromPath("~/Pictures/photo.jpg")
/// hs.ui.window({x: 100, y: 100, w: 400, h: 300})
///     .vstack()
///         .padding(20)
///         .image(img)
///             .resizable()
///             .aspectRatio("fit")
///             .frame({w: 360, h: 240})
///     .end()
///     .show();
/// ```
@objc protocol HSUIWindowAPI: HSTypeAPI, JSExport {
    // MARK: Window Management

    /// Show the window
    /// - Returns: Self for chaining
    @objc func show() -> HSUIWindow

    /// Hide the window (keeps it in memory)
    @objc func hide()

    /// Close and destroy the window
    @objc func close()

    /// Return the window's actual on-screen frame after show(), as
    /// `{x, y, w, h}` in bottom-origin (NSWindow) coordinates. Returns null
    /// if the window has not been shown. For debugging/testing only.
    /// - Returns: `{x, y, w, h}` on-screen frame in NSWindow coordinates, or null if not shown
    @objc func currentFrame() -> [String: Double]?

    /// Render this window's content view to a PNG file at the given path.
    /// Uses NSView.cacheDisplay — this does NOT capture the screen, only
    /// re-renders this view's own drawing, so no Screen Recording permission
    /// is required and only this window's pixels are produced.
    /// - Parameter path: absolute filesystem path to write
    /// - Returns: true on success
    @objc func snapshotToPNG(_ path: String) -> Bool

    // MARK: Window Styling

    /// Set the window's background color
    /// - Parameter colorValue: Color as hex string (e.g., "#FF0000") or HSColor object
    /// - Returns: Self for chaining
    @objc func backgroundColor(_ colorValue: JSValue) -> HSUIWindow

    // MARK: Shape Elements

    /// Add a rectangle shape
    /// - Returns: Self for chaining (apply modifiers like `fill()`, `frame()`)
    @objc func rectangle() -> HSUIWindow

    /// Add a circle shape
    /// - Returns: Self for chaining (apply modifiers like `fill()`, `frame()`)
    @objc func circle() -> HSUIWindow

    /// Add a text element
    /// - Parameter content: The text to display — a plain JS string for static text,
    ///   or an `HSString` object (from `hs.ui.string()`) for reactive text
    /// - Returns: Self for chaining (apply modifiers like `font()`, `foregroundColor()`)
    @objc func text(_ content: JSValue) -> HSUIWindow

    /// Add an inline multi-color text element. The content is an `HSString`
    /// whose value is a JSON-encoded array of `{ text, accent }` segments;
    /// segments render as one concatenated SwiftUI Text with per-segment
    /// color. Use for per-character match highlighting where some letters
    /// (the matched query chars) get the accent color.
    /// - Parameter content: A plain JS string OR an `HSString` carrying the
    ///   JSON segments. The segment shape is `[{ text: string, accent: bool }, …]`.
    /// - Returns: Self for chaining (apply `.font()`, `.foregroundColor()` for
    ///   the default color, `.accentColor()` for the matched-segment color,
    ///   and `.frame()`).
    /// - Example:
    /// ```js
    /// const segs = hs.ui.string(JSON.stringify([
    ///   { text: 'Sa',  accent: true  },
    ///   { text: 'fari', accent: false }
    /// ]))
    /// win.attributedText(segs)
    ///    .font(HSFont.body())
    ///    .foregroundColor('#F2F2F4')
    ///    .accentColor('#7B9CFF')
    ///    .frame({ w: 400, h: 18 })
    /// ```
    @objc func attributedText(_ content: JSValue) -> HSUIWindow

    /// Set the accent color used for `accent: true` segments inside an
    /// `attributedText()` element. No effect on other elements.
    /// - Parameter colorValue: Color as hex string or HSColor
    /// - Returns: Self for chaining
    @objc func accentColor(_ colorValue: JSValue) -> HSUIWindow

    /// Add an image element
    /// - Parameter imageValue: Image as HSImage object or file path string
    /// - Returns: Self for chaining (apply modifiers like `resizable()`, `aspectRatio()`, `frame()`)
    @objc func image(_ imageValue: JSValue) -> HSUIWindow

    /// Add a button element
    /// - Parameter label: The button label — a plain JS string for static text,
    ///   or an `HSString` object (from `hs.ui.string()`) for reactive text
    /// - Returns: Self for chaining (apply `.fill()`, `.cornerRadius()`, `.font()`,
    ///   `.foregroundColor()`, `.frame()`, `.onClick()` etc.)
    @objc func button(_ label: JSValue) -> HSUIWindow

    /// Add a single-line text input field
    /// - Parameter initial: The initial value — a plain JS string OR an `HSString`
    ///   (from `hs.ui.string()`). When you pass an HSString, the field is two-way
    ///   bound: typing updates the HSString and `hsString.set(...)` updates the field.
    /// - Returns: Self for chaining (apply `.placeholder()`, `.focused()`,
    ///   `.onChange()`, `.onSubmit()`, `.onKey()`, `.font()`, `.foregroundColor()`,
    ///   `.frame()` etc.)
    /// - Example:
    /// ```js
    /// const query = hs.ui.string('')
    /// hs.ui.window().textField(query)
    ///   .placeholder('Search…')
    ///   .focused(true)
    ///   .onChange(v => console.log(v))
    ///   .onSubmit(v => launch(v))
    ///   .onKey((key, mods) => key === 'ArrowDown' ? true : false)
    /// .end().show()
    /// ```
    @objc func textField(_ initial: JSValue) -> HSUIWindow

    /// Set placeholder text for the current text field (greyed-out hint when empty)
    /// - Parameter text: The placeholder string
    /// - Returns: Self for chaining
    @objc func placeholder(_ text: String) -> HSUIWindow

    /// Control whether the current text field grabs first-responder when shown.
    /// Default is true.
    /// - Parameter enabled: true to autofocus
    /// - Returns: Self for chaining
    @objc func focused(_ enabled: Bool) -> HSUIWindow

    /// Register a callback that fires whenever the current text field's value changes.
    /// Called with the new string.
    /// - Parameter callback: `(value: string) => void`
    /// - Returns: Self for chaining
    @objc func onChange(_ callback: JSValue) -> HSUIWindow

    /// Register a callback that fires when the current text field submits (Enter pressed
    /// and not consumed by `onKey`). Called with the current value.
    /// - Parameter callback: `(value: string) => void`
    /// - Returns: Self for chaining
    @objc func onSubmit(_ callback: JSValue) -> HSUIWindow

    // MARK: Layout Containers

    /// Begin a vertical stack (elements arranged top to bottom)
    /// - Returns: Self for chaining (call `end()` when done)
    @objc func vstack() -> HSUIWindow

    /// Begin a horizontal stack (elements arranged left to right)
    /// - Returns: Self for chaining (call `end()` when done)
    @objc func hstack() -> HSUIWindow

    /// Begin a z-stack (overlapping elements)
    /// - Returns: Self for chaining (call `end()` when done)
    @objc func zstack() -> HSUIWindow

    /// Add flexible spacing that expands to fill available space
    /// - Returns: Self for chaining
    @objc func spacer() -> HSUIWindow

    /// End the current layout container
    /// - Returns: Self for chaining
    @objc func end() -> HSUIWindow

    // MARK: Shape Modifiers

    /// Fill a shape with a color
    /// - Parameter colorValue: Color as hex string or HSColor
    /// - Returns: Self for chaining
    @objc func fill(_ colorValue: JSValue) -> HSUIWindow

    /// Add a stroke (border) to a shape
    /// - Parameter colorValue: Color as hex string or HSColor
    /// - Returns: Self for chaining
    @objc func stroke(_ colorValue: JSValue) -> HSUIWindow

    /// Set the stroke width
    /// - Parameter width: Width in points
    /// - Returns: Self for chaining
    @objc func strokeWidth(_ width: Double) -> HSUIWindow

    /// Round the corners of a shape
    /// - Parameter radius: Corner radius in points
    /// - Returns: Self for chaining
    @objc func cornerRadius(_ radius: Double) -> HSUIWindow

    /// Set the frame (size) of an element
    /// - Parameter dict: Dictionary with `w` and/or `h` (can be numbers or percentage strings like "50%")
    /// - Returns: Self for chaining
    @objc func frame(_ dict: [String: Any]) -> HSUIWindow

    /// Set the opacity of an element
    /// - Parameter value: Opacity from 0.0 (transparent) to 1.0 (opaque)
    /// - Returns: Self for chaining
    @objc func opacity(_ value: Double) -> HSUIWindow

    // MARK: Text Modifiers

    /// Set the font for a text element
    /// - Parameter font: An HSFont object (e.g., `HSFont.title()`)
    /// - Returns: Self for chaining
    @objc func font(_ font: HSFont) -> HSUIWindow

    /// Set the text color
    /// - Parameter colorValue: Color as hex string or HSColor
    /// - Returns: Self for chaining
    @objc func foregroundColor(_ colorValue: JSValue) -> HSUIWindow

    // MARK: Image Modifiers

    /// Make an image resizable (allows it to scale with frame size)
    /// - Returns: Self for chaining
    @objc func resizable() -> HSUIWindow

    /// Set the aspect ratio mode for an image
    /// - Parameter mode: "fit" (scales to fit within frame) or "fill" (scales to fill frame)
    /// - Returns: Self for chaining
    @objc func aspectRatio(_ mode: String) -> HSUIWindow

    // MARK: Layout Modifiers

    /// Add padding around a layout container
    /// - Parameter value: Padding in points
    /// - Returns: Self for chaining
    @objc func padding(_ value: Double) -> HSUIWindow

    /// Set spacing between elements in a stack
    /// - Parameter value: Spacing in points
    /// - Returns: Self for chaining
    @objc func spacing(_ value: Double) -> HSUIWindow

    // MARK: Interaction Callbacks

    /// Set a callback to fire when the element is clicked
    /// - Parameter callback: A JavaScript function to call on click
    /// - Returns: Self for chaining
    @objc func onClick(_ callback: JSValue) -> HSUIWindow

    /// Set a callback to fire when the cursor enters or leaves the element
    /// - Parameter callback: A JavaScript function called with a boolean: true when entering, false when leaving
    /// - Returns: Self for chaining
    @objc func onHover(_ callback: JSValue) -> HSUIWindow

    // MARK: Window Styling Additions

    /// Remove the window's title bar and chrome, making it completely borderless.
    /// - Returns: Self for chaining
    /// - Example:
    /// ```js
    /// hs.ui.window().borderless().show()
    /// ```
    @objc func borderless() -> HSUIWindow

    /// Set the window level by name.
    /// - Parameter name: One of 'normal', 'floating', 'popUpMenu', 'screenSaver'
    /// - Returns: Self for chaining
    /// - Example:
    /// ```js
    /// hs.ui.window().level('floating').show()
    /// ```
    @objc func level(_ name: String) -> HSUIWindow

    /// Center the window on the main screen when shown.
    /// - Returns: Self for chaining
    /// - Example:
    /// ```js
    /// hs.ui.window().center().show()
    /// ```
    @objc func center() -> HSUIWindow

    /// Anchor the window to an edge of the active screen's *visible* area —
    /// the region excluding the menu bar and Dock — centered on the cross axis.
    /// Use this instead of `center()` for status/HUD strips that should sit out
    /// of the way at the bottom (or top) rather than over your content.
    /// - Parameter edge: 'bottom', 'top', or 'center'
    /// - Returns: Self for chaining
    /// - Example:
    /// ```js
    /// hs.ui.window().borderless().frame({ w: 900, h: 36 }).anchor('bottom').text('…').end().show()
    /// ```
    @objc func anchor(_ edge: String) -> HSUIWindow

    /// Control whether the window can become the key window (receive keyboard events).
    /// - Parameter enabled: true to allow the window to become key
    /// - Returns: Self for chaining
    /// - Example:
    /// ```js
    /// hs.ui.window().canBecomeKey(true).show()
    /// ```
    @objc func canBecomeKey(_ enabled: Bool) -> HSUIWindow

    /// Make the window click-through: mouse events pass straight to whatever is beneath it.
    /// Essential for a transparent full-screen overlay (otherwise it would swallow every click).
    /// - Parameter enabled: true to ignore mouse events (overlay/HUD); false for a normal window
    /// - Returns: Self for chaining
    /// - Example:
    /// ```js
    /// hs.ui.window().borderless().ignoresMouseEvents(true).show()
    /// ```
    @objc func ignoresMouseEvents(_ enabled: Bool) -> HSUIWindow

    /// Register a callback that fires on local key events while this window is key.
    /// - Parameter callback: Function called with (key, modifiers) where key is a character string
    ///   and modifiers is an array of strings like 'shift', 'cmd', etc.
    /// - Returns: Self for chaining
    /// - Example:
    /// ```js
    /// hs.ui.window().onKey((key, mods) => console.log(key, mods)).show()
    /// ```
    @objc func onKey(_ callback: JSValue) -> HSUIWindow

    /// Register a callback that fires when the window loses key status (blurs).
    /// - Parameter callback: Function to invoke when the window resigns key
    /// - Returns: Self for chaining
    /// - Example:
    /// ```js
    /// hs.ui.window().onBlur(() => console.log('blurred')).show()
    /// ```
    @objc func onBlur(_ callback: JSValue) -> HSUIWindow

    /// Round the window's outer corners (Spotlight/Raycast popup look).
    /// Applies layer cornerRadius + masksToBounds to the window's content view
    /// and makes the NSWindow background fully transparent so the corners
    /// outside the rounded shape are see-through.
    /// - Parameter radius: Corner radius in points. 0 disables rounding.
    /// - Returns: Self for chaining
    /// - Example:
    /// ```js
    /// hs.ui.window().borderless().windowCornerRadius(12).show()
    /// ```
    @objc func windowCornerRadius(_ radius: Double) -> HSUIWindow
}

@MainActor
@objc class HSUIWindow: NSObject, HSUIWindowAPI, NSWindowDelegate {
    @objc var typeName = "HSUIWindow"

    // Window properties
    private var windowFrame: CGRect
    private var nsWindow: NSWindow?
    private var windowBackgroundColor: Color = .clear
    private let windowID: UUID = UUID()
    private weak var module: HSUIModule?

    // Element tree
    private var rootElement: (any HSUIElement)?
    private var currentElement: (any HSUIElement)?
    private var containerStack: [any UIContainer] = []

    // Styling state (applied in show())
    private var isBorderless: Bool = true          // default: borderless (matches existing behaviour)
    private var windowLevel: NSWindow.Level = .floating  // default: floating (matches existing behaviour)
    private var shouldCenter: Bool = false
    private var anchorEdge: String? = nil   // 'bottom' | 'top' | 'center' (visible-frame anchored)
    private var canBecomeKeyOverride: Bool = false
    private var ignoresMouseEventsValue: Bool = false
    private var windowCornerRadiusValue: CGFloat = 0
    private var keyCallback: JSValue?
    private var blurCallback: JSValue?
    private var keyMonitor: Any?
    private var blurObserver: NSObjectProtocol?

    // Initialization
    init(frame: CGRect, module: HSUIModule) {
        self.windowFrame = frame
        self.module = module
        super.init()
    }

    convenience init(dict: [String: Any], module: HSUIModule) {
        let x = (dict["x"] as? NSNumber)?.doubleValue ?? 0
        let y = (dict["y"] as? NSNumber)?.doubleValue ?? 0
        let w = (dict["w"] as? NSNumber)?.doubleValue ?? 200
        let h = (dict["h"] as? NSNumber)?.doubleValue ?? 200

        self.init(frame: CGRect(x: x, y: y, width: w, height: h), module: module)
    }

    isolated deinit {
        close()
        AKTrace("deinit of HSUIWindow: \(windowID)")
    }

    // MARK: - Window Management

    @objc func show() -> HSUIWindow {
        guard let root = rootElement else {
            AKError("hs.ui.window: Cannot show window without content")
            return self
        }

        let styleMask: NSWindow.StyleMask = isBorderless ? [.borderless] : [.titled, .closable, .miniaturizable, .resizable]
        let window = canBecomeKeyOverride
            ? HSKeyAcceptingWindow(contentRect: windowFrame, styleMask: styleMask, backing: .buffered, defer: false)
            : NSWindow(contentRect: windowFrame, styleMask: styleMask, backing: .buffered, defer: false)

        let contentView = UICanvasView(
            element: root,
            backgroundColor: windowBackgroundColor,
            containerSize: windowFrame.size
        )
        // Use NSHostingView wrapped in a generic NSView with explicit frame.
        // The wrapper insulates the window from NSHostingView's
        // intrinsicContentSize propagation — which otherwise grows the
        // window taller than the configured windowFrame whenever the
        // SwiftUI content has a larger preferred height.
        let host = NSHostingView(rootView: contentView)
        host.autoresizingMask = [.width, .height]
        host.frame = NSRect(origin: .zero, size: windowFrame.size)
        let wrapper = NSView(frame: NSRect(origin: .zero, size: windowFrame.size))
        wrapper.autoresizesSubviews = true
        wrapper.addSubview(host)
        window.contentView = wrapper
        window.setContentSize(windowFrame.size)
        window.isOpaque = false
        if windowCornerRadiusValue > 0 {
            // Clip the contentView to a rounded shape and make the NSWindow's
            // own background fully transparent — otherwise the rectangular
            // window BG would render the corners outside the rounded mask.
            window.backgroundColor = .clear
            wrapper.wantsLayer = true
            wrapper.layer?.cornerRadius = windowCornerRadiusValue
            wrapper.layer?.masksToBounds = true
            wrapper.layer?.backgroundColor = NSColor(windowBackgroundColor).cgColor
        } else {
            window.backgroundColor = NSColor(windowBackgroundColor)
        }
        window.level = windowLevel
        window.ignoresMouseEvents = ignoresMouseEventsValue
        window.isReleasedWhenClosed = false
        window.delegate = self

        if let edge = anchorEdge, let screen = NSScreen.main {
            // Anchor within the visible frame (excludes menu bar + Dock) so a
            // bottom HUD clears the Dock and a top HUD clears the menu bar.
            let w = windowFrame.size.width
            let h = windowFrame.size.height
            let vis = screen.visibleFrame
            let inset: CGFloat = 22
            let x = vis.midX - w / 2
            let y: CGFloat
            switch edge {
            case "top":    y = vis.maxY - h - inset
            case "bottom": y = vis.minY + inset
            default:       y = vis.midY - h / 2   // 'center' within the visible area
            }
            window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: false)
        } else if shouldCenter, let screen = NSScreen.main {
            let w = windowFrame.size.width
            let h = windowFrame.size.height
            let x = screen.frame.midX - w / 2
            let y = screen.frame.midY - h / 2
            window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: false)
        }

        // When the host app (HS2) is in the background — which it usually is
        // when a window is shown from a hotkey — macOS will not automatically
        // route key events to a key-accepting window. We must explicitly
        // activate the app first. Without this, the launcher/textField
        // appears but the user's typing goes to whatever app WAS foreground
        // (Spotlight-style focus stealing requires this on macOS 14+).
        if canBecomeKeyOverride {
            NSApp.activate(ignoringOtherApps: true)
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        self.nsWindow = window

        // Install key event monitor scoped to this window
        if let cb = keyCallback {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak window] event in
                guard let win = window, event.window === win else { return event }
                let key = event.charactersIgnoringModifiers ?? ""
                var mods: [String] = []
                if event.modifierFlags.contains(.shift)   { mods.append("shift") }
                if event.modifierFlags.contains(.control) { mods.append("ctrl") }
                if event.modifierFlags.contains(.command) { mods.append("cmd") }
                if event.modifierFlags.contains(.option)  { mods.append("opt") }
                cb.callSafely(withArguments: [key, mods], context: "hs.ui.window onKey")
                return event
            }
        }

        // Install blur (resign key) observer scoped to this window
        if let cb = blurCallback {
            blurObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                cb.callSafely(withArguments: [], context: "hs.ui.window onBlur")
            }
        }

        // Register with module to prevent premature deallocation
        module?.register(self, id: windowID)

        return self
    }

    @objc func hide() {
        nsWindow?.orderOut(nil)
    }

    @objc func currentFrame() -> [String: Double]? {
        guard let w = nsWindow else { return nil }
        let f = w.frame
        return ["x": f.origin.x, "y": f.origin.y, "w": f.size.width, "h": f.size.height]
    }

    @objc func snapshotToPNG(_ path: String) -> Bool {
        guard let win = nsWindow else {
            AKError("snapshotToPNG: no nsWindow")
            return false
        }
        guard let view = win.contentView else {
            AKError("snapshotToPNG: no contentView")
            return false
        }
        let bounds = view.bounds
        AKWarning("snapshotToPNG: view.bounds = \(bounds)")
        // Force layout/display so the cached bitmap captures the latest tree.
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()

        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            AKError("snapshotToPNG: bitmapImageRepForCachingDisplay returned nil")
            return false
        }
        view.cacheDisplay(in: bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            AKError("snapshotToPNG: PNG conversion failed")
            return false
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
            AKWarning("snapshotToPNG: wrote \(png.count) bytes to \(path)")
            return true
        } catch {
            AKError("snapshotToPNG: write failed: \(error.localizedDescription)")
            return false
        }
    }

    @objc func close() {
        guard nsWindow != nil else { return } // Already closed

        // Remove key monitor
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }

        // Remove blur observer
        if let observer = blurObserver {
            NotificationCenter.default.removeObserver(observer)
            blurObserver = nil
        }

        // Unregister from module
        module?.unregister(window: windowID)

        nsWindow?.delegate = nil
        nsWindow?.close()
        nsWindow = nil
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        // Window is being closed (by user or system)
        Task { @MainActor in
            self.close()
        }
    }

    // MARK: - Background Styling

    @objc func backgroundColor(_ colorValue: JSValue) -> HSUIWindow {
        if let color = colorValue.toColor() {
            windowBackgroundColor = color
        }
        return self
    }

    // MARK: - Shape Constructors

    @objc func rectangle() -> HSUIWindow {
        let rect = UIRectangle()
        currentElement = rect
        addToCurrentContainer(rect)
        return self
    }

    @objc func circle() -> HSUIWindow {
        let circle = UICircle()
        currentElement = circle
        addToCurrentContainer(circle)
        return self
    }

    @objc func text(_ content: JSValue) -> HSUIWindow {
        guard let hsString = HSString.fromJSValue(content) else { return self }
        let textElement = UIText(content: hsString)
        currentElement = textElement
        addToCurrentContainer(textElement)
        return self
    }

    @objc func attributedText(_ content: JSValue) -> HSUIWindow {
        guard let hsString = HSString.fromJSValue(content) else { return self }
        let element = UIAttributedText(content: hsString)
        currentElement = element
        addToCurrentContainer(element)
        return self
    }

    @objc func image(_ imageValue: JSValue) -> HSUIWindow {
        let hsImage = HSImage.fromJSValue(imageValue)
        let imageElement = UIImage(hsImage: hsImage)
        currentElement = imageElement
        addToCurrentContainer(imageElement)
        return self
    }

    @objc func button(_ label: JSValue) -> HSUIWindow {
        guard let hsString = HSString.fromJSValue(label) else { return self }
        let buttonElement = UIButton(label: hsString)
        currentElement = buttonElement
        addToCurrentContainer(buttonElement)
        return self
    }

    @objc func textField(_ initial: JSValue) -> HSUIWindow {
        guard let hsString = HSString.fromJSValue(initial) else { return self }
        let field = UITextField(content: hsString)
        currentElement = field
        addToCurrentContainer(field)
        return self
    }

    @objc func placeholder(_ text: String) -> HSUIWindow {
        if let field = currentElement as? UITextField {
            field.placeholderText = text
        }
        return self
    }

    @objc func focused(_ enabled: Bool) -> HSUIWindow {
        if let field = currentElement as? UITextField {
            field.startFocused = enabled
        }
        return self
    }

    @objc func onChange(_ callback: JSValue) -> HSUIWindow {
        if let field = currentElement as? UITextField {
            field.onChangeCallback = callback
        } else {
            AKWarning("hs.ui: onChange() called on an element that does not support it")
        }
        return self
    }

    @objc func onSubmit(_ callback: JSValue) -> HSUIWindow {
        if let field = currentElement as? UITextField {
            field.onSubmitCallback = callback
        } else {
            AKWarning("hs.ui: onSubmit() called on an element that does not support it")
        }
        return self
    }

    // MARK: - Layout Containers

    @objc func vstack() -> HSUIWindow {
        let stack = UIVStack()
        currentElement = stack
        containerStack.append(stack)

        if rootElement == nil {
            rootElement = stack
        } else if !containerStack.isEmpty && containerStack.count >= 2 {
            containerStack[containerStack.count - 2].addChild(stack)
        }

        return self
    }

    @objc func hstack() -> HSUIWindow {
        let stack = UIHStack()
        currentElement = stack
        containerStack.append(stack)

        if rootElement == nil {
            rootElement = stack
        } else if !containerStack.isEmpty && containerStack.count >= 2 {
            containerStack[containerStack.count - 2].addChild(stack)
        }

        return self
    }

    @objc func zstack() -> HSUIWindow {
        let stack = UIZStack()
        currentElement = stack
        containerStack.append(stack)

        if rootElement == nil {
            rootElement = stack
        } else if !containerStack.isEmpty && containerStack.count >= 2 {
            containerStack[containerStack.count - 2].addChild(stack)
        }

        return self
    }

    @objc func spacer() -> HSUIWindow {
        let spacer = UISpacer()
        currentElement = spacer
        addToCurrentContainer(spacer)
        return self
    }

    @objc func end() -> HSUIWindow {
        if !containerStack.isEmpty {
            containerStack.removeLast()
        }
        currentElement = containerStack.last
        return self
    }

    // MARK: - Shape Modifiers

    @objc func fill(_ colorValue: JSValue) -> HSUIWindow {
        if let shapeable = currentElement as? any ShapeModifiable,
           let hsColor = HSColor.fromJSValue(colorValue) {
            shapeable.fillColor = hsColor
        }
        return self
    }

    @objc func stroke(_ colorValue: JSValue) -> HSUIWindow {
        if let shapeable = currentElement as? any ShapeModifiable,
           let hsColor = HSColor.fromJSValue(colorValue) {
            shapeable.strokeColor = hsColor
        }
        return self
    }

    @objc func strokeWidth(_ width: Double) -> HSUIWindow {
        if let shapeable = currentElement as? any ShapeModifiable {
            shapeable.strokeWidth = CGFloat(width)
        }
        return self
    }

    @objc func cornerRadius(_ radius: Double) -> HSUIWindow {
        if let shapeable = currentElement as? any ShapeModifiable {
            shapeable.cornerRadius = CGFloat(radius)
        }
        return self
    }

    @objc func frame(_ dict: [String: Any]) -> HSUIWindow {
        if let frameable = currentElement as? any FrameModifiable,
           let uiFrame = UIFrame.from(dict: dict) {
            frameable.elementFrame = uiFrame
        }
        return self
    }

    @objc func opacity(_ value: Double) -> HSUIWindow {
        if let modifiable = currentElement as? any OpacityModifiable {
            modifiable.elementOpacity = value
        }
        return self
    }

    // MARK: - Text Modifiers

    @objc func font(_ font: HSFont) -> HSUIWindow {
        if let textable = currentElement as? any TextModifiable {
            textable.font = font.font
        }
        return self
    }

    @objc func foregroundColor(_ colorValue: JSValue) -> HSUIWindow {
        if let textable = currentElement as? any TextModifiable,
           let hsColor = HSColor.fromJSValue(colorValue) {
            textable.foregroundColor = hsColor
        }
        return self
    }

    @objc func accentColor(_ colorValue: JSValue) -> HSUIWindow {
        if let accentable = currentElement as? any AccentColorModifiable,
           let hsColor = HSColor.fromJSValue(colorValue) {
            accentable.accentColor = hsColor
        }
        return self
    }

    // MARK: - Image Modifiers

    @objc func resizable() -> HSUIWindow {
        if let imageElement = currentElement as? UIImage {
            imageElement.resizable = true
        }
        return self
    }

    @objc func aspectRatio(_ mode: String) -> HSUIWindow {
        if let imageElement = currentElement as? UIImage {
            switch mode.lowercased() {
            case "fit":
                imageElement.aspectRatio = .fit
            case "fill":
                imageElement.aspectRatio = .fill
            default:
                AKError("hs.ui: Invalid aspect ratio mode: \(mode), use 'fit' or 'fill'")
            }
        }
        return self
    }

    // MARK: - Layout Modifiers

    @objc func padding(_ value: Double) -> HSUIWindow {
        if let container = currentElement as? PaddingModifiable {
            container.elementPadding = CGFloat(value)
        }
        return self
    }

    @objc func spacing(_ value: Double) -> HSUIWindow {
        if let container = currentElement as? SpacingModifiable {
            container.elementSpacing = CGFloat(value)
        }
        return self
    }

    // MARK: - Interaction Callbacks

    @objc func onClick(_ callback: JSValue) -> HSUIWindow {
        if let interactive = currentElement as? any InteractiveModifiable {
            interactive.clickCallback = { callback.callSafely(withArguments: [], context: "hs.ui onClick") }
        } else {
            AKWarning("hs.ui: onClick() called on an element that does not support interactions")
        }
        return self
    }

    @objc func onHover(_ callback: JSValue) -> HSUIWindow {
        if let interactive = currentElement as? any InteractiveModifiable {
            interactive.hoverCallback = { isHovered in callback.callSafely(withArguments: [isHovered], context: "hs.ui onHover") }
        } else {
            AKWarning("hs.ui: onHover() called on an element that does not support interactions")
        }
        return self
    }

    // MARK: - Window Styling Additions

    @objc func borderless() -> HSUIWindow {
        isBorderless = true
        return self
    }

    @objc func level(_ name: String) -> HSUIWindow {
        switch name {
        case "normal":      windowLevel = .normal
        case "floating":    windowLevel = .floating
        case "popUpMenu":   windowLevel = .popUpMenu
        case "screenSaver": windowLevel = .screenSaver
        default:            windowLevel = .normal
        }
        return self
    }

    @objc func center() -> HSUIWindow {
        shouldCenter = true
        return self
    }

    @objc func anchor(_ edge: String) -> HSUIWindow {
        anchorEdge = edge.lowercased()
        return self
    }

    @objc func canBecomeKey(_ enabled: Bool) -> HSUIWindow {
        canBecomeKeyOverride = enabled
        return self
    }

    @objc func ignoresMouseEvents(_ enabled: Bool) -> HSUIWindow {
        ignoresMouseEventsValue = enabled
        return self
    }

    @objc func onKey(_ callback: JSValue) -> HSUIWindow {
        if let field = currentElement as? UITextField {
            field.onKeyCallback = callback
        } else {
            keyCallback = callback
        }
        return self
    }

    @objc func onBlur(_ callback: JSValue) -> HSUIWindow {
        blurCallback = callback
        return self
    }

    @objc func windowCornerRadius(_ radius: Double) -> HSUIWindow {
        windowCornerRadiusValue = max(0, CGFloat(radius))
        return self
    }

    // MARK: - Helper Methods

    private func addToCurrentContainer(_ element: any HSUIElement) {
        if rootElement == nil {
            rootElement = element
        } else if let container = containerStack.last {
            container.addChild(element)
        }
    }
}

// MARK: - HSKeyAcceptingWindow

/// NSWindow subclass that can be configured to accept key window status,
/// enabling it to receive keyboard events.
final class HSKeyAcceptingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
