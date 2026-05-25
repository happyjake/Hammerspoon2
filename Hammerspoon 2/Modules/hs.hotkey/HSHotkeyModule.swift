//
//  HotkeyModule.swift
//  Hammerspoon 2
//
//  Created by Chris Jones on 13/11/2025.
//

import Foundation
import JavaScriptCore
import Carbon
import AppKit

// MARK: - Declare our JavaScript API

/// Module for creating and managing system-wide hotkeys
@objc protocol HSHotkeyModuleAPI: JSExport {
    /// Bind a hotkey
    /// - Parameters:
    ///   - mods: An array of modifier key strings (e.g., ["cmd", "shift"])
    ///   - key: The key name or character (e.g., "a", "space", "return")
    ///   - callbackPressed: A JavaScript function to call when the hotkey is pressed
    ///   - callbackReleased: A JavaScript function to call when the hotkey is released
    /// - Returns: A hotkey object, or nil if binding failed
    /// - Example:
    /// ```js
    /// hs.hotkey.bind(["cmd","shift"], "h", () => {
    ///     console.log("Hello!")
    /// })
    /// ```
    @objc func bind(_ mods: JSValue, _ key: String, _ callbackPressed: JSValue, _ callbackReleased: JSValue) -> HSHotkey?

    /// Bind a hotkey with a message description
    /// - Parameters:
    ///   - mods: An array of modifier key strings
    ///   - key: The key name or character
    ///   - message: A description of what this hotkey does (currently unused, for future features)
    ///   - callbackPressed: A JavaScript function to call when the hotkey is pressed
    ///   - callbackReleased: A JavaScript function to call when the hotkey is released
    /// - Returns: A hotkey object, or nil if binding failed
    /// - Example:
    /// ```js
    /// hs.hotkey.bindSpec(["cmd"], "space", "Spotlight-like", () => {
    ///     console.log("pressed")
    /// }, null)
    /// ```
    @objc(bindSpec:::::)
    func bindSpec(_ mods: JSValue, _ key: String, _ message: String?, _ callbackPressed: JSValue, _ callbackReleased: JSValue) -> HSHotkey?

    /// Get the system-wide mapping of key names to key codes
    /// - Returns: A dictionary mapping key names to numeric key codes
    /// - Example:
    /// ```js
    /// console.log(hs.hotkey.getKeyCodeMap())
    /// ```
    @objc func getKeyCodeMap() -> [String: UInt32]

    /// Drive a `DoubleTapDetector` through a synthetic event sequence and
    /// report how many times the trigger fired. For testing only.
    /// - Parameter modifier: 'shift', 'ctrl', 'cmd', or 'alt'.
    /// - Parameter sequence: array of events, each `{type, mods, atMs}`.
    ///   - `type`: 'flagsChanged' or 'keyDown'
    ///   - `mods`: array of modifier names currently held (e.g. ['ctrl'])
    ///   - `atMs`: milliseconds elapsed since the synthetic clock origin
    /// - Returns: integer fire count.
    @objc func testDoubleTapSequence(_ modifier: String, _ sequence: JSValue) -> Int

    /// Get the mapping of modifier names to modifier flags
    /// - Returns: A dictionary mapping modifier names to their numeric values
    /// - Example:
    /// ```js
    /// console.log(hs.hotkey.getModifierMap())
    /// ```
    @objc func getModifierMap() -> [String: UInt32]

    /// Bind a callback to a double-tap of a bare modifier key.
    /// Detects modifier-down → all-up → modifier-down within 300ms, with no
    /// intervening key press. Fires on the second release.
    /// - Parameter modifier: One of 'shift', 'ctrl', 'cmd', 'opt'
    /// - Parameter callback: Function to invoke
    /// - Returns: An HSDoubleTapHotkey with .unbind()
    /// - Example:
    /// ```js
    /// hs.hotkey.bindDoubleTap('shift', () => console.log('shift!'))
    /// ```
    @objc func bindDoubleTap(_ modifier: String, _ callback: JSValue) -> HSDoubleTapHotkey?
}

// MARK: - DoubleTap Support Types

/// Object representing a double-tap hotkey binding. Use .unbind() to remove it.
@objc protocol HSDoubleTapHotkeyAPI: HSTypeAPI, JSExport {
    /// Remove the double-tap binding
    /// - Example:
    /// ```js
    /// const hk = hs.hotkey.bindDoubleTap('shift', () => {})
    /// hk.unbind()
    /// ```
    @objc func unbind()
}

@_documentation(visibility: private)
@MainActor
@objc class HSDoubleTapHotkey: NSObject, HSDoubleTapHotkeyAPI {
    @objc var typeName = "HSDoubleTapHotkey"
    private let unbinder: () -> Void

    init(unbinder: @escaping () -> Void) {
        self.unbinder = unbinder
        super.init()
    }

    @objc func unbind() { unbinder() }
}

/// Detects double-press of a bare modifier key within 300ms with no intervening key.
/// Reused by `hs.hotkey.bindDoubleTap` (JS callback) and `hs.switcher` (Swift callback).
internal final class DoubleTapDetector {
    private let modifierMask: NSEvent.ModifierFlags
    private let callback: JSValue?
    private let swiftCallback: (@MainActor () -> Void)?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var state: Int = 0
    private var firstReleaseAt: Date?
    private static let windowSeconds: TimeInterval = 0.3
    private static let trackedMask: NSEvent.ModifierFlags = [.shift, .control, .command, .option]

    init(modifier: NSEvent.ModifierFlags, callback: JSValue) {
        self.modifierMask = modifier
        self.callback = callback
        self.swiftCallback = nil
    }

    init(modifier: NSEvent.ModifierFlags, swiftCallback: @escaping @MainActor () -> Void) {
        self.modifierMask = modifier
        self.callback = nil
        self.swiftCallback = swiftCallback
    }

    func start() {
        let handler: (NSEvent) -> Void = { [weak self] e in self?.handle(e) }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { e in
            handler(e)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { e in
            handler(e)
            return e
        }
    }

    func stop() {
        if let g = globalMonitor { NSEvent.removeMonitor(g); globalMonitor = nil }
        if let l = localMonitor  { NSEvent.removeMonitor(l); localMonitor  = nil }
    }

    private func handle(_ event: NSEvent) {
        feed(eventType: event.type, flags: event.modifierFlags.intersection(Self.trackedMask), now: Date())
    }

    /// Pure entry point — testable without an NSEvent. `flags` should already
    /// be intersected with `trackedMask`. `now` is injectable for time-based
    /// behaviour (state-2 expiry).
    internal func feed(eventType: NSEvent.EventType, flags: NSEvent.ModifierFlags, now: Date) {
        if eventType == .keyDown {
            state = 0; firstReleaseAt = nil
            return
        }
        let isOurModOnly = flags == modifierMask
        let isOurModDown = flags.contains(modifierMask)
        let allUp = flags.isEmpty

        // Expire stale state-2 BEFORE evaluating the switch, so the current
        // event participates in state-0 logic instead of being dropped. This
        // matters for the ctrl×2 → switcher path: after a commit the user is
        // typically in another app for seconds before re-triggering, leaving
        // firstReleaseAt deeply stale. Without this restructure, the first
        // ctrl-down "wakes up" the detector but doesn't count toward the new
        // double-tap, requiring a phantom ctrl tap before ctrl×2 works again.
        if state == 2, let t = firstReleaseAt, now.timeIntervalSince(t) > Self.windowSeconds {
            state = 0; firstReleaseAt = nil
        }

        switch state {
        case 0:
            if isOurModDown && isOurModOnly { state = 1 }
        case 1:
            if allUp { state = 2; firstReleaseAt = now }
            else { state = 0 }
        case 2:
            if isOurModDown && isOurModOnly {
                state = 3
            } else if !allUp {
                state = 0; firstReleaseAt = nil
            }
        case 3:
            if allUp {
                if let swift = swiftCallback {
                    DispatchQueue.main.async { swift() }
                } else if let cb = self.callback {
                    DispatchQueue.main.async { cb.callSafely(withArguments: [], context: "hs.hotkey doubletap") }
                }
                state = 0; firstReleaseAt = nil
            } else if !isOurModDown {
                state = 0; firstReleaseAt = nil
            }
        default:
            state = 0; firstReleaseAt = nil
        }
    }
}

// MARK: - Implementation

@_documentation(visibility: private)
@objc class HSHotkeyModule: NSObject, HSModuleAPI, HSHotkeyModuleAPI {
    var name = "hs.hotkey"
    let engineID: UUID

    // Track active hotkeys for cleanup
    private var activeHotkeys: [HSHotkey] = []

    // Track active double-tap detectors for cleanup
    private var doubleTapDetectors: [DoubleTapDetector] = []

    // MARK: - Module lifecycle

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {
        // Disable all active hotkeys
        for hotkey in activeHotkeys {
            hotkey.disable()
        }
        activeHotkeys.removeAll()

        // Stop all double-tap detectors
        for detector in doubleTapDetectors {
            detector.stop()
        }
        doubleTapDetectors.removeAll()
    }

    isolated deinit {
        AKTrace("Deinit of \(name): \(engineID)")
    }

    // MARK: - Hotkey binding

    @objc func bind(_ mods: JSValue, _ key: String, _ callbackPressed: JSValue, _ callbackReleased: JSValue) -> HSHotkey? {
        return bindSpec(mods, key, nil, callbackPressed, callbackReleased)
    }

    @objc func bindSpec(_ mods: JSValue, _ key: String, _ message: String?, _ callbackPressed: JSValue, _ callbackReleased: JSValue) -> HSHotkey? {
        // Parse modifiers
        guard let modifierFlags = parseModifiers(mods) else {
            AKError("hs.hotkey.bind: Invalid modifiers")
            return nil
        }

        // Get key code
        guard let keyCode = keyNameToKeyCode(key) else {
            AKError("hs.hotkey.bind: Unknown key '\(key)'")
            return nil
        }

        // Validate callbacks
        guard callbackPressed.isObject || callbackPressed.isNull else {
            AKError("hs.hotkey.bind: callbackPressed must be either a function or null")
            return nil
        }
        guard callbackReleased.isObject || callbackReleased.isNull else {
            AKError("hs.hotkey.bind: callbackReleased must be either a function or null")
            return nil
        }

        // Create and enable the hotkey
        let hotkey = HSHotkey(keyCode: keyCode, modifiers: modifierFlags, callbackPressed: callbackPressed, callbackReleased: callbackReleased)

        if !hotkey.enable() {
            AKError("hs.hotkey.bind: Failed to enable hotkey")
            return nil
        }

        // Track for cleanup
        activeHotkeys.append(hotkey)

        return hotkey
    }

    // MARK: - Double-tap binding

    @objc func bindDoubleTap(_ modifierName: String, _ callback: JSValue) -> HSDoubleTapHotkey? {
        let mask: NSEvent.ModifierFlags
        switch modifierName.lowercased() {
        case "shift":                     mask = .shift
        case "ctrl", "control":           mask = .control
        case "cmd", "command":            mask = .command
        case "opt", "alt", "option":      mask = .option
        default:
            AKError("bindDoubleTap: unknown modifier '\(modifierName)'")
            return nil
        }
        let detector = DoubleTapDetector(modifier: mask, callback: callback)
        detector.start()
        doubleTapDetectors.append(detector)

        return HSDoubleTapHotkey(unbinder: { [weak self, weak detector] in
            detector?.stop()
            if let d = detector { self?.doubleTapDetectors.removeAll { $0 === d } }
        })
    }

    // MARK: - Helper methods

    @objc func getKeyCodeMap() -> [String: UInt32] {
        return KeyCodeMapper.keyMap
    }

    @objc func testDoubleTapSequence(_ modifier: String, _ sequence: JSValue) -> Int {
        let mask: NSEvent.ModifierFlags
        switch modifier.lowercased() {
        case "shift":                     mask = .shift
        case "ctrl", "control":           mask = .control
        case "cmd", "command":            mask = .command
        case "opt", "alt", "option":      mask = .option
        default: return -1
        }
        var fires = 0
        let det = DoubleTapDetector(modifier: mask, swiftCallback: { fires += 1 })
        guard sequence.isArray, let arr = sequence.toArray() as? [[String: Any]] else { return -2 }
        let origin = Date(timeIntervalSinceReferenceDate: 0)
        for ev in arr {
            let typeStr = (ev["type"] as? String) ?? "flagsChanged"
            let atMs = (ev["atMs"] as? Int) ?? 0
            let now = origin.addingTimeInterval(TimeInterval(atMs) / 1000.0)
            let modsArr = (ev["mods"] as? [String]) ?? []
            var flags: NSEvent.ModifierFlags = []
            for m in modsArr {
                switch m.lowercased() {
                case "shift":  flags.insert(.shift)
                case "ctrl", "control": flags.insert(.control)
                case "cmd", "command":  flags.insert(.command)
                case "opt", "alt", "option": flags.insert(.option)
                default: break
                }
            }
            let evType: NSEvent.EventType = (typeStr == "keyDown") ? .keyDown : .flagsChanged
            det.feed(eventType: evType, flags: flags, now: now)
            // DispatchQueue.main.async (which the detector uses to fire its
            // callback) won't have run yet — but for our internal swift
            // callback we don't actually go through main.async on test path;
            // it's just `fires += 1`. Wait — yes we DO. Fix: do a runloop spin
            // after each event so the async fires.
            RunLoop.current.run(until: Date().addingTimeInterval(0.001))
        }
        return fires
    }

    @objc func getModifierMap() -> [String: UInt32] {
        return ModifierMapper.modifierMap
    }

    private func parseModifiers(_ modsValue: JSValue) -> UInt32? {
        guard modsValue.isArray else {
            AKError("hs.hotkey.bind(): Modifiers must be an array.")
            return nil
        }

        var flags: UInt32 = 0

        if let modsArray = modsValue.toArray() as? [String] {
            for mod in modsArray {
                guard let modFlag = ModifierMapper.modifierMap[mod.lowercased()] else {
                    AKError("hs.hotkey: Unknown modifier '\(mod)'")
                    return nil
                }
                flags |= modFlag
            }
        }

        return flags
    }

    private func keyNameToKeyCode(_ key: String) -> UInt32? {
        let lowercaseKey = key.lowercased()

        // Check the key map first
        if let keyCode = KeyCodeMapper.keyMap[lowercaseKey] {
            return keyCode
        }

        // For single characters, try to map them
        if key.count == 1,
           let scalar = key.unicodeScalars.first {
            // This handles simple ASCII characters
            // Note: For more complex mappings, we'd need a fuller implementation
            return KeyCodeMapper.charToKeyCode(Character(scalar))
        }

        return nil
    }
}

// MARK: - Modifier Mapping

private struct ModifierMapper {
    static let modifierMap: [String: UInt32] = [
        "cmd": UInt32(cmdKey),
        "command": UInt32(cmdKey),
        "⌘": UInt32(cmdKey),

        "ctrl": UInt32(controlKey),
        "control": UInt32(controlKey),
        "⌃": UInt32(controlKey),

        "alt": UInt32(optionKey),
        "option": UInt32(optionKey),
        "⌥": UInt32(optionKey),

        "shift": UInt32(shiftKey),
        "⇧": UInt32(shiftKey),
    ]
}

// MARK: - Key Code Mapping

private struct KeyCodeMapper {
    // Map of key names to their virtual key codes
    // Based on Events.h from Carbon framework
    static let keyMap: [String: UInt32] = [
        // Letters
        "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02,
        "e": 0x0E, "f": 0x03, "g": 0x05, "h": 0x04,
        "i": 0x22, "j": 0x26, "k": 0x28, "l": 0x25,
        "m": 0x2E, "n": 0x2D, "o": 0x1F, "p": 0x23,
        "q": 0x0C, "r": 0x0F, "s": 0x01, "t": 0x11,
        "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07,
        "y": 0x10, "z": 0x06,

        // Numbers
        "0": 0x1D, "1": 0x12, "2": 0x13, "3": 0x14,
        "4": 0x15, "5": 0x17, "6": 0x16, "7": 0x1A,
        "8": 0x1C, "9": 0x19,

        // Function keys
        "f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76,
        "f5": 0x60, "f6": 0x61, "f7": 0x62, "f8": 0x64,
        "f9": 0x65, "f10": 0x6D, "f11": 0x67, "f12": 0x6F,
        "f13": 0x69, "f14": 0x6B, "f15": 0x71, "f16": 0x6A,
        "f17": 0x40, "f18": 0x4F, "f19": 0x50, "f20": 0x5A,

        // Special keys
        "space": 0x31,
        "return": 0x24,
        "tab": 0x30,
        "delete": 0x33,
        "forwarddelete": 0x75,
        "escape": 0x35,
        "help": 0x72,
        "home": 0x73,
        "end": 0x77,
        "pageup": 0x74,
        "pagedown": 0x79,

        // Arrow keys
        "left": 0x7B,
        "right": 0x7C,
        "down": 0x7D,
        "up": 0x7E,

        // Symbols and punctuation
        "minus": 0x1B,
        "-": 0x1B,
        "equal": 0x18,
        "=": 0x18,
        "leftbracket": 0x21,
        "[": 0x21,
        "rightbracket": 0x1E,
        "]": 0x1E,
        "backslash": 0x2A,
        "\\": 0x2A,
        "semicolon": 0x29,
        ";": 0x29,
        "quote": 0x27,
        "'": 0x27,
        "comma": 0x2B,
        ",": 0x2B,
        "period": 0x2F,
        ".": 0x2F,
        "slash": 0x2C,
        "/": 0x2C,
        "grave": 0x32,
        "`": 0x32,

        // Keypad
        "pad0": 0x52,
        "pad1": 0x53,
        "pad2": 0x54,
        "pad3": 0x55,
        "pad4": 0x56,
        "pad5": 0x57,
        "pad6": 0x58,
        "pad7": 0x59,
        "pad8": 0x5B,
        "pad9": 0x5C,
        "pad*": 0x43,
        "pad+": 0x45,
        "pad/": 0x4B,
        "pad-": 0x4E,
        "pad=": 0x51,
        "pad.": 0x41,
        "padclear": 0x47,
        "padenter": 0x4C,
    ]

    /// Convert a character to its key code (for simple ASCII characters)
    static func charToKeyCode(_ char: Character) -> UInt32? {
        let lowercased = String(char).lowercased()
        return keyMap[lowercased]
    }
}
