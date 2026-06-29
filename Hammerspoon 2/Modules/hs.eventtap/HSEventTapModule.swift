//
//  HSEventTapModule.swift
//  Hammerspoon 2
//

import Foundation
import JavaScriptCore
import CoreGraphics

// MARK: - Declare our JavaScript API

/// Module for creating CGEventTap-based global keyboard event monitors
@objc protocol HSEventTapModuleAPI: JSExport {
    /// Create a new event tap for the specified event types.
    /// Call .start() on the returned object to begin receiving events.
    /// Requires Accessibility permission (active event taps; keyboard monitoring may also need Input Monitoring).
    /// - Parameter eventTypes: Array of event type strings: 'keyDown', 'keyUp', 'flagsChanged', 'mouseMoved', 'leftMouseDown', 'leftMouseUp', 'rightMouseDown', 'rightMouseUp', 'otherMouseDown', 'otherMouseUp', 'leftMouseDragged', 'rightMouseDragged', 'scrollWheel', 'systemDefined', 'gesture', 'magnify'.
    ///   'systemDefined' delivers media-key events (brightness, volume, play/pause…): `{type, subtype, modifiers}` plus — for subtype 8 (aux control buttons) — `key` (e.g. 'BRIGHTNESS_UP'), `nxKeyCode`, `down`, `isRepeat`.
    ///   'gesture' delivers raw trackpad touch frames: `{type, modifiers, touchCount, touches: [{id, phase, x, y}]}` with x/y normalized to the pad (origin bottom-left).
    ///   'magnify' delivers trackpad pinch-zoom gestures: `{type, modifiers, magnification, phase}` where `magnification` is the incremental scale delta for the frame (positive = zoom in) and `phase` is 'began' | 'changed' | 'ended' | 'cancelled'.
    /// - Parameter callback: Function called with an event object. Return true to consume (suppress) the event.
    /// - Returns: An HSEventTap instance
    /// - Example:
    /// ```js
    /// const tap = hs.eventtap.make(['keyDown'], e => {
    ///   console.log(e.keyCode, e.modifiers)
    ///   return false // don't consume
    /// })
    /// tap.start()
    ///
    /// // Watch media keys (volume/brightness):
    /// const media = hs.eventtap.make(['systemDefined'], e => {
    ///   if (e.subtype === 8 && e.down) console.log(e.key)
    ///   return false
    /// })
    /// media.start()
    /// ```
    @objc(make::) func makeTap(_ eventTypes: [String], _ callback: JSValue) -> HSEventTap

    /// Synthesise a key stroke: press the modifiers + key, hold, then release.
    /// - Parameter mods: Array of modifier strings, e.g. ['cmd']
    /// - Parameter key: Key name, e.g. 'v'
    /// - Parameter delay: Optional number of microseconds the key is held between keyDown
    ///   and keyUp. Defaults to 200000 (200 ms), matching upstream Hammerspoon's
    ///   `hs.eventtap.keyStroke`. A zero/too-short hold is frequently dropped by the target
    ///   app — the clipboard gets set but the paste never lands.
    /// - Example:
    /// ```js
    /// hs.eventtap.keyStroke(['cmd'], 'v')          // 200 ms default hold
    /// hs.eventtap.keyStroke(['cmd'], 'v', 10000)   // 10 ms hold
    /// ```
    @objc(keyStroke:::) func keyStroke(_ mods: [String], _ key: String, _ delay: JSValue)

    /// Synthesise a scroll-wheel event at the current mouse position.
    /// The window server routes scroll events to the window under the cursor —
    /// independent of keyboard focus — so this scrolls whatever the mouse is over.
    /// - Parameter dx: Horizontal scroll amount (positive scrolls left, like a physical wheel tilt-left)
    /// - Parameter dy: Vertical scroll amount (positive scrolls up, like a physical wheel-up)
    /// - Parameter unit: Optional unit string: 'pixel' (default) or 'line'
    /// - Example:
    /// ```js
    /// hs.eventtap.scrollWheel(0, -450, 'pixel')  // scroll down 450px under the cursor
    /// hs.eventtap.scrollWheel(0, 3, 'line')      // scroll up 3 lines
    /// ```
    @objc(scrollWheel:::) func scrollWheel(_ dx: Double, _ dy: Double, _ unit: JSValue)

    /// Synthesise a left mouse click (press + release) at a point in global
    /// top-left screen coordinates (the same space as `hs.mouse.position()` and
    /// window frames). Does not move the visible cursor.
    /// - Parameter point: A point object `{x, y}` to click at
    /// - Parameter delay: Optional number of microseconds between mouseDown and mouseUp.
    ///   Defaults to 200000 (200 ms), matching upstream Hammerspoon's `hs.eventtap.leftClick`.
    /// - Example:
    /// ```js
    /// hs.eventtap.leftClick({ x: 800, y: 450 })         // 200 ms default hold
    /// hs.eventtap.leftClick({ x: 800, y: 450 }, 10000)  // 10 ms hold
    /// ```
    @objc(leftClick::) func leftClick(_ point: [String: Double], _ delay: JSValue)

    /// Type a string by synthesising key events (M1 stub — lands in M4).
    /// - Parameter text: Text to type
    /// - Example:
    /// ```js
    /// hs.eventtap.typeText('Hello!')
    /// ```
    @objc func typeText(_ text: String)
}

// MARK: - Implementation

@_documentation(visibility: private)
@MainActor
@objc class HSEventTapModule: NSObject, HSModuleAPI, HSEventTapModuleAPI {
    var name = "hs.eventtap"
    let engineID: UUID

    private var createdTaps: [HSEventTap] = []

    // MARK: - Module lifecycle

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {
        for t in createdTaps { t.stop() }
        createdTaps.removeAll()
        AKTrace("Shutdown of \(name): \(engineID)")
    }

    isolated deinit {
        AKTrace("Deinit of \(name): \(engineID)")
    }

    // MARK: - API

    @objc(make::) func makeTap(_ eventTypes: [String], _ callback: JSValue) -> HSEventTap {
        let t = HSEventTap(eventTypes: eventTypes, callback: callback)
        createdTaps.append(t)
        return t
    }

    @objc(keyStroke:::) func keyStroke(_ mods: [String], _ key: String, _ delay: JSValue) {
        guard let keyCode = HSEventTapModule.keyCode(for: key) else {
            AKError("hs.eventtap.keyStroke: unknown key '\(key)'")
            return
        }

        var flags: CGEventFlags = []
        for m in mods {
            switch m.lowercased() {
            case "cmd", "command":    flags.insert(.maskCommand)
            case "ctrl", "control":   flags.insert(.maskControl)
            case "alt", "opt", "option": flags.insert(.maskAlternate)
            case "shift":             flags.insert(.maskShift)
            case "fn":                flags.insert(.maskSecondaryFn)
            default:
                AKWarning("hs.eventtap.keyStroke: unknown modifier '\(m)'")
            }
        }

        let src = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
              let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false) else {
            AKError("hs.eventtap.keyStroke: failed to create CGEvent")
            return
        }
        down.flags = flags
        up.flags = flags

        // Microseconds to hold the key between keyDown and keyUp, inserted with usleep —
        // matching upstream Hammerspoon's hs.eventtap.keyStroke (default 200000). A zero/
        // too-short hold is frequently dropped by the target app: the clipboard gets set
        // but the paste never lands. Clamped to [0, 5s].
        var hold: useconds_t = 200000
        if delay.isNumber {
            let v = delay.toDouble()
            if v.isFinite && v >= 0 { hold = useconds_t(min(v, 5_000_000)) }
        }
        down.post(tap: .cghidEventTap)
        if hold > 0 { usleep(hold) }
        up.post(tap: .cghidEventTap)
    }

    @objc(scrollWheel:::) func scrollWheel(_ dx: Double, _ dy: Double, _ unit: JSValue) {
        var cgUnit = CGScrollEventUnit.pixel
        if unit.isString, let s = unit.toString()?.lowercased() {
            switch s {
            case "pixel": cgUnit = .pixel
            case "line":  cgUnit = .line
            default:
                AKWarning("hs.eventtap.scrollWheel: unknown unit '\(s)' — using 'pixel'")
            }
        }

        // Wheel deltas are Int32 on the CG side; reject NaN/Inf, clamp the rest.
        func wheelDelta(_ v: Double) -> Int32 {
            guard v.isFinite else { return 0 }
            return Int32(max(Double(Int32.min), min(Double(Int32.max), v.rounded())))
        }
        let wheelVertical = wheelDelta(dy)
        let wheelHorizontal = wheelDelta(dx)

        let src = CGEventSource(stateID: .combinedSessionState)
        // wheel1 = vertical axis, wheel2 = horizontal (CGEvent convention).
        guard let ev = CGEvent(scrollWheelEvent2Source: src,
                               units: cgUnit,
                               wheelCount: 2,
                               wheel1: wheelVertical,
                               wheel2: wheelHorizontal,
                               wheel3: 0) else {
            AKError("hs.eventtap.scrollWheel: failed to create CGEvent")
            return
        }
        // Programmatically-created events get a (0,0) location; set it to the
        // cursor so the window server routes the scroll to the window under it.
        ev.location = CGEvent(source: nil)?.location ?? .zero
        ev.post(tap: .cghidEventTap)
    }

    @objc(leftClick::) func leftClick(_ point: [String: Double], _ delay: JSValue) {
        guard let x = point["x"], let y = point["y"], x.isFinite, y.isFinite else {
            AKError("hs.eventtap.leftClick: point must be {x, y} with finite numbers")
            return
        }
        let location = CGPoint(x: x, y: y)

        let src = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown,
                                 mouseCursorPosition: location, mouseButton: .left),
              let up   = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp,
                                 mouseCursorPosition: location, mouseButton: .left) else {
            AKError("hs.eventtap.leftClick: failed to create CGEvent")
            return
        }
        // Single click — apps ignore mouse events whose click state is 0.
        down.setIntegerValueField(.mouseEventClickState, value: 1)
        up.setIntegerValueField(.mouseEventClickState, value: 1)

        // Microseconds between mouseDown and mouseUp, matching upstream Hammerspoon's
        // hs.eventtap.leftClick (default 200000). Clamped to [0, 5s].
        var hold: useconds_t = 200000
        if delay.isNumber {
            let v = delay.toDouble()
            if v.isFinite && v >= 0 { hold = useconds_t(min(v, 5_000_000)) }
        }
        down.post(tap: .cghidEventTap)
        if hold > 0 { usleep(hold) }
        up.post(tap: .cghidEventTap)
    }

    @objc func typeText(_ text: String) {
        AKWarning("hs.eventtap.typeText is not yet implemented in M1 — lands with M4.")
    }

    // US-QWERTY virtual key codes (Carbon kVK_* constants). Covers the keys
    // any reasonable webhook/automation flow needs; extend as more land.
    private static let virtualKeyCodes: [String: CGKeyCode] = [
        // Letters
        "a": 0,  "s": 1,  "d": 2,  "f": 3,  "h": 4,  "g": 5,  "z": 6,  "x": 7,
        "c": 8,  "v": 9,  "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16,
        "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23,
        "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29, "]": 30, "o": 31,
        "u": 32, "[": 33, "i": 34, "p": 35, "l": 37, "j": 38, "'": 39,
        "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46,
        ".": 47, "`": 50,
        // Named keys
        "return": 36, "enter": 36, "tab": 48, "space": 49, " ": 49,
        "delete": 51, "backspace": 51, "escape": 53, "esc": 53,
        "left": 123, "right": 124, "down": 125, "up": 126,
        "home": 115, "pageup": 116, "forwarddelete": 117, "end": 119, "pagedown": 121,
        // Function keys
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
        "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
    ]

    private static func keyCode(for name: String) -> CGKeyCode? {
        return virtualKeyCodes[name.lowercased()]
    }
}
