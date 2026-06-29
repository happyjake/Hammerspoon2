//
//  HSEventTap.swift
//  Hammerspoon 2
//

import Foundation
import JavaScriptCore
import AppKit

/// Object representing a CGEventTap-based global key event tap.
@objc protocol HSEventTapAPI: HSTypeAPI, JSExport {
    /// Start the event tap. Returns true on success.
    /// Requires Accessibility permission (active event taps). Returns false if permission is missing.
    /// - Returns: true if the tap was started successfully
    /// - Example:
    /// ```js
    /// const tap = hs.eventtap.new(['keyDown'], e => false)
    /// tap.start()
    /// ```
    @objc func start() -> Bool

    /// Stop the event tap.
    /// - Example:
    /// ```js
    /// tap.stop()
    /// ```
    @objc func stop()

    /// Whether the tap is currently running.
    /// - Returns: true if the tap is active
    /// - Example:
    /// ```js
    /// console.log(tap.isRunning)
    /// ```
    @objc var isRunning: Bool { get }
}

@_documentation(visibility: private)
@MainActor
@objc class HSEventTap: NSObject, HSEventTapAPI {
    @objc var typeName = "HSEventTap"
    private let callback: JSValue
    private let eventMask: CGEventMask
    private let wantsGesture: Bool   // caller tapped 'gesture' (raw touch frames)
    private let wantsMagnify: Bool   // caller tapped 'magnify' (pinch-zoom)
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(eventTypes: [String], callback: JSValue) {
        self.callback = callback
        self.wantsGesture = eventTypes.contains("gesture")
        self.wantsMagnify = eventTypes.contains("magnify")
        var mask: CGEventMask = 0
        for t in eventTypes {
            switch t {
            case "keyDown":           mask |= CGEventMask(1 << CGEventType.keyDown.rawValue)
            case "keyUp":             mask |= CGEventMask(1 << CGEventType.keyUp.rawValue)
            case "flagsChanged":      mask |= CGEventMask(1 << CGEventType.flagsChanged.rawValue)
            // Mouse event types
            case "mouseMoved":        mask |= CGEventMask(1 << CGEventType.mouseMoved.rawValue)
            case "leftMouseDown":     mask |= CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
            case "leftMouseUp":       mask |= CGEventMask(1 << CGEventType.leftMouseUp.rawValue)
            case "rightMouseDown":    mask |= CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
            case "rightMouseUp":      mask |= CGEventMask(1 << CGEventType.rightMouseUp.rawValue)
            case "otherMouseDown":    mask |= CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
            case "otherMouseUp":      mask |= CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
            case "leftMouseDragged":  mask |= CGEventMask(1 << CGEventType.leftMouseDragged.rawValue)
            case "rightMouseDragged": mask |= CGEventMask(1 << CGEventType.rightMouseDragged.rawValue)
            case "otherMouseDragged": mask |= CGEventMask(1 << CGEventType.otherMouseDragged.rawValue)
            case "scrollWheel":       mask |= CGEventMask(1 << CGEventType.scrollWheel.rawValue)
            // NSEvent-layer types — CGEventType has no cases for these, but CGEventTap
            // delivers them when the mask bit is set (mask bit == NSEvent.EventType raw value).
            case "systemDefined":     mask |= CGEventMask(1 << NSEvent.EventType.systemDefined.rawValue) // media keys (NX aux control buttons)
            // A trackpad pinch is delivered as a GESTURE (29) event whose bridged NSEvent.type is
            // .magnify — there is NO standalone magnify (30) event at the session-tap layer. So both
            // 'gesture' (raw touches) and 'magnify' (pinch) ride the same 29 mask bit; handleGesture()
            // splits them by the bridged NSEvent type. (Mirrors Hammerspoon 1.)
            case "gesture", "magnify": mask |= CGEventMask(1 << NSEvent.EventType.gesture.rawValue)
            default: break
            }
        }
        self.eventMask = mask
        super.init()
    }

    @objc func start() -> Bool {
        if tap != nil { return true }
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()
        let cb: CGEventTapCallBack = { _, type, cgEvent, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(cgEvent) }
            let me = Unmanaged<HSEventTap>.fromOpaque(refcon).takeUnretainedValue()
            return me.handle(type: type, event: cgEvent)
        }
        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: cb,
            userInfo: opaqueSelf
        ) else {
            AKError("HSEventTap.start(): CGEvent.tapCreate returned nil. Grant Accessibility permission (active event taps require Accessibility; keyboard monitoring may also need Input Monitoring).")
            return false
        }
        self.tap = t
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        self.runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    @objc func stop() {
        if let t = tap {
            CGEvent.tapEnable(tap: t, enable: false)
            if let s = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes)
            }
            self.tap = nil
            self.runLoopSource = nil
        }
    }

    @objc var isRunning: Bool { tap != nil }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS auto-disables a tap that runs slow OR when the user out-types it
        // (kCGEventTapDisabledByUserInput — e.g. panic key-mashing). If we don't re-enable it the
        // tap goes silently dead: events stop flowing, so anything riding this tap (most critically
        // a panic-escape gesture in a remote-control/forwarding mode) becomes impossible. These two
        // lifecycle events are delivered to the callback regardless of the event mask. (Mirrors
        // HSSwitcherKeyHandler's re-enable.)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let flags = event.flags
        var mods: [String] = []
        if flags.contains(.maskShift)     { mods.append("shift") }
        if flags.contains(.maskControl)   { mods.append("ctrl") }
        if flags.contains(.maskCommand)   { mods.append("cmd") }
        if flags.contains(.maskAlternate) { mods.append("opt") }

        // NSEvent-layer types (no CGEventType case): media keys + trackpad gestures.
        // Parsed via NSEvent(cgEvent:) — the CGEvent field accessors don't cover them.
        switch UInt(type.rawValue) {
        case NSEvent.EventType.systemDefined.rawValue:
            return dispatch(Self.systemDefinedJSEvent(event: event, modifiers: mods), typeName: "systemDefined", event: event)
        case NSEvent.EventType.gesture.rawValue:
            return handleGesture(event: event, modifiers: mods)
        default:
            break
        }

        let typeName: String
        switch type {
        case .keyDown:           typeName = "keyDown"
        case .keyUp:             typeName = "keyUp"
        case .flagsChanged:      typeName = "flagsChanged"
        case .mouseMoved:        typeName = "mouseMoved"
        case .leftMouseDown:     typeName = "leftMouseDown"
        case .leftMouseUp:       typeName = "leftMouseUp"
        case .rightMouseDown:    typeName = "rightMouseDown"
        case .rightMouseUp:      typeName = "rightMouseUp"
        case .otherMouseDown:    typeName = "otherMouseDown"
        case .otherMouseUp:      typeName = "otherMouseUp"
        case .leftMouseDragged:  typeName = "leftMouseDragged"
        case .rightMouseDragged: typeName = "rightMouseDragged"
        case .otherMouseDragged: typeName = "otherMouseDragged"
        case .scrollWheel:       typeName = "scrollWheel"
        default:                 typeName = "other"
        }

        let jsEvent: [String: Any]

        switch type {
        case .mouseMoved, .leftMouseDown, .leftMouseUp,
             .rightMouseDown, .rightMouseUp,
             .otherMouseDown, .otherMouseUp,
             .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            let loc = event.location
            jsEvent = [
                "type":      typeName,
                "modifiers": mods,
                "x":         loc.x,
                "y":         loc.y,
                "dx":        Int(event.getIntegerValueField(.mouseEventDeltaX)),
                "dy":        Int(event.getIntegerValueField(.mouseEventDeltaY)),
                "buttons":   Int(event.getIntegerValueField(.mouseEventButtonNumber)),
            ]

        case .scrollWheel:
            let loc = event.location
            jsEvent = [
                "type":      typeName,
                "modifiers": mods,
                "x":         loc.x,
                "y":         loc.y,
                "scrollDy":  Int(event.getIntegerValueField(.scrollWheelEventDeltaAxis1)),
                "scrollDx":  Int(event.getIntegerValueField(.scrollWheelEventDeltaAxis2)),
            ]

        default:
            // Keyboard / flagsChanged / other — original keyboard fields
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            var chars = ""
            let maxLen: Int = 4
            var actualLen: Int = 0
            var buf = [UniChar](repeating: 0, count: maxLen)
            event.keyboardGetUnicodeString(maxStringLength: maxLen, actualStringLength: &actualLen, unicodeString: &buf)
            if actualLen > 0 {
                chars = String(utf16CodeUnits: buf, count: actualLen)
            }
            jsEvent = [
                "type":       typeName,
                "keyCode":    Int(keyCode),
                "characters": chars,
                "modifiers":  mods,
                "isRepeat":   event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
            ]
        }

        return dispatch(jsEvent, typeName: typeName, event: event)
    }

    /// Deliver a JS event dict to the callback; returning true from JS consumes the event.
    private func dispatch(_ jsEvent: [String: Any], typeName: String, event: CGEvent) -> Unmanaged<CGEvent>? {
        let result = callback.callSafely(withArguments: [jsEvent], context: "hs.eventtap \(typeName)")
        let consume = result?.toBool() ?? false
        return consume ? nil : Unmanaged.passUnretained(event)
    }

    // NX aux-control key codes (IOKit/hidsystem/ev_keymap.h) → stable JS names.
    private static let nxKeyNames: [Int: String] = [
        0: "SOUND_UP", 1: "SOUND_DOWN", 2: "BRIGHTNESS_UP", 3: "BRIGHTNESS_DOWN",
        4: "CAPS_LOCK", 5: "HELP", 6: "POWER", 7: "MUTE", 10: "NUM_LOCK",
        11: "CONTRAST_UP", 12: "CONTRAST_DOWN", 13: "LAUNCH_PANEL", 14: "EJECT",
        15: "VIDMIRROR", 16: "PLAY", 17: "NEXT", 18: "PREVIOUS", 19: "FAST",
        20: "REWIND", 21: "ILLUMINATION_UP", 22: "ILLUMINATION_DOWN", 23: "ILLUMINATION_TOGGLE",
    ]

    /// NSSystemDefined (type 14). Subtype 8 = NX_SUBTYPE_AUX_CONTROL_BUTTONS — the media keys
    /// (brightness, volume, play/pause…). data1 packs: NX key code in the high word; key state
    /// (0x0A down / 0x0B up) and the repeat flag in the low word. Other subtypes (e.g. 7 = aux
    /// mouse buttons) are delivered with just `type`/`subtype`/`modifiers` so JS can ignore them.
    private static func systemDefinedJSEvent(event: CGEvent, modifiers: [String]) -> [String: Any] {
        var js: [String: Any] = ["type": "systemDefined", "modifiers": modifiers]
        guard let ns = NSEvent(cgEvent: event) else { return js }
        let subtype = Int(ns.subtype.rawValue)
        js["subtype"] = subtype
        if subtype == 8 {
            let data1 = ns.data1
            let nxKeyCode = (data1 & 0xFFFF_0000) >> 16
            let keyFlags = data1 & 0x0000_FFFF
            js["nxKeyCode"] = nxKeyCode
            js["key"] = nxKeyNames[nxKeyCode] ?? String(nxKeyCode)
            js["down"] = ((keyFlags & 0xFF00) >> 8) == 0x0A
            js["isRepeat"] = (keyFlags & 0x1) != 0
        }
        return js
    }

    /// A trackpad gesture (CG type 29). Its BRIDGED NSEvent type tells a pinch (`.magnify`) apart
    /// from raw touch frames — at the session-tap layer the CG type is always 29, so we can't switch
    /// on it. Deliver whichever the tap asked for: 'magnify' → the pinch's `magnification`, 'gesture'
    /// → the touch set. A pinch reports BOTH (it has touches too), so a 'gesture' tap still sees the
    /// touches during a pinch, while a 'magnify' tap ignores non-pinch gesture frames (passes through).
    private func handleGesture(event: CGEvent, modifiers: [String]) -> Unmanaged<CGEvent>? {
        let ns = NSEvent(cgEvent: event)
        if wantsMagnify, ns?.type == .magnify {
            return dispatch(Self.magnifyJSEvent(ns: ns, modifiers: modifiers), typeName: "magnify", event: event)
        }
        if wantsGesture {
            return dispatch(Self.gestureJSEvent(event: event, modifiers: modifiers), typeName: "gesture", event: event)
        }
        return Unmanaged.passUnretained(event)   // requested the other variant — don't consume
    }

    /// NSEventTypeGesture (type 29) — raw trackpad touch frames. Each touch carries a per-finger
    /// stable `id`, its phase, and its normalized pad position (x/y in 0–1, origin bottom-left).
    private static func gestureJSEvent(event: CGEvent, modifiers: [String]) -> [String: Any] {
        var js: [String: Any] = ["type": "gesture", "modifiers": modifiers, "touches": [[String: Any]](), "touchCount": 0]
        guard let ns = NSEvent(cgEvent: event) else { return js }
        let touches = ns.touches(matching: .any, in: nil)
        let arr: [[String: Any]] = touches.map { t in
            [
                "id": t.identity.hash,   // identity object is stable for the finger's lifetime
                "phase": phaseName(t.phase),
                "x": Double(t.normalizedPosition.x),
                "y": Double(t.normalizedPosition.y),
            ]
        }
        js["touches"] = arr
        js["touchCount"] = arr.count
        return js
    }

    /// A pinch frame — a gesture (CG type 29) event whose bridged NSEvent type is `.magnify`.
    /// `magnification` is the per-frame scale delta (positive = fingers apart = zoom in; sum it for
    /// the total — see Apple's `NSEvent.magnification`). `phase` is derived from the gesture's TOUCH
    /// set, because `NSEvent.phase` is unreliable for tapped gesture events; it brackets the pinch
    /// began → changed → ended so the JS consumer can drive a zoom modifier.
    private static func magnifyJSEvent(ns: NSEvent?, modifiers: [String]) -> [String: Any] {
        var js: [String: Any] = ["type": "magnify", "modifiers": modifiers, "magnification": 0.0, "phase": "changed"]
        guard let ns = ns else { return js }
        js["magnification"] = Double(ns.magnification)
        js["phase"] = touchPhase(ns.touches(matching: .any, in: nil))
        return js
    }

    private static func phaseName(_ p: NSTouch.Phase) -> String {
        switch p {
        case .began: return "began"
        case .moved: return "moved"
        case .stationary: return "stationary"
        case .ended: return "ended"
        case .cancelled: return "cancelled"
        default: return "touching"
        }
    }

    /// Aggregate a gesture's TOUCH set into one lifecycle phase. Terminal first: an empty/all-lifted
    /// set ends the gesture (so the JS side always releases the zoom modifier); a newly-landed finger
    /// begins it; otherwise it's changing. NSTouch.phase is the reliable signal here (NSEvent.phase
    /// is not, for tapped gesture events), and the watchdog on the JS side covers any missed end.
    private static func touchPhase(_ touches: Set<NSTouch>) -> String {
        if touches.isEmpty { return "ended" }
        var anyBegan = false
        var allEnded = true
        for t in touches {
            switch t.phase {
            case .began: anyBegan = true; allEnded = false
            case .ended, .cancelled: break
            default: allEnded = false
            }
        }
        if allEnded { return "ended" }
        if anyBegan { return "began" }
        return "changed"
    }
}
