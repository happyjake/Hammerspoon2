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
    /// Requires Input Monitoring permission. Returns false if permission is missing.
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
            case "keyDown":      mask |= CGEventMask(1 << CGEventType.keyDown.rawValue)
            case "keyUp":        mask |= CGEventMask(1 << CGEventType.keyUp.rawValue)
            case "flagsChanged": mask |= CGEventMask(1 << CGEventType.flagsChanged.rawValue)
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
            AKError("HSEventTap.start(): CGEvent.tapCreate returned nil. Check Input Monitoring permission.")
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
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        var mods: [String] = []
        if flags.contains(.maskShift)     { mods.append("shift") }
        if flags.contains(.maskControl)   { mods.append("ctrl") }
        if flags.contains(.maskCommand)   { mods.append("cmd") }
        if flags.contains(.maskAlternate) { mods.append("opt") }

        let typeName: String
        switch type {
        case .keyDown:      typeName = "keyDown"
        case .keyUp:        typeName = "keyUp"
        case .flagsChanged: typeName = "flagsChanged"
        default:            typeName = "other"
        }

        var chars = ""
        let maxLen: Int = 4
        var actualLen: Int = 0
        var buf = [UniChar](repeating: 0, count: maxLen)
        event.keyboardGetUnicodeString(maxStringLength: maxLen, actualStringLength: &actualLen, unicodeString: &buf)
        if actualLen > 0 {
            chars = String(utf16CodeUnits: buf, count: actualLen)
        }

        let jsEvent: [String: Any] = [
            "type": typeName,
            "keyCode": Int(keyCode),
            "characters": chars,
            "modifiers": mods,
            "isRepeat": event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
        ]

        let result = callback.callSafely(withArguments: [jsEvent], context: "hs.eventtap \(typeName)")
        let consume = result?.toBool() ?? false
        return consume ? nil : Unmanaged.passUnretained(event)
    }
}
