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
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(eventTypes: [String], callback: JSValue) {
        self.callback = callback
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
        let flags = event.flags
        var mods: [String] = []
        if flags.contains(.maskShift)     { mods.append("shift") }
        if flags.contains(.maskControl)   { mods.append("ctrl") }
        if flags.contains(.maskCommand)   { mods.append("cmd") }
        if flags.contains(.maskAlternate) { mods.append("opt") }

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

        let result = callback.callSafely(withArguments: [jsEvent], context: "hs.eventtap \(typeName)")
        let consume = result?.toBool() ?? false
        return consume ? nil : Unmanaged.passUnretained(event)
    }
}
