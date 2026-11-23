//
//  HSEventTapModule.swift
//  Hammerspoon 2
//

import AppKit
import Foundation
import JavaScriptCore
import JavaScriptCoreExtras
import CoreGraphics
import IOKit.hidsystem
import Synchronization

// MARK: - Declare our JavaScript API

/// Module for creating CGEventTap-based global keyboard event monitors
@objc protocol HSEventTapModuleAPI: JSExport {
    /// Create a new event tap for the specified event types.
    /// Call .start() on the returned object to begin receiving events.
    /// Requires Accessibility permission (active event taps; keyboard monitoring may also need Input Monitoring).
    /// - Parameter eventTypes: {string[]} Array of event type strings: 'keyDown', 'keyUp', 'flagsChanged', 'mouseMoved', 'leftMouseDown', 'leftMouseUp', 'rightMouseDown', 'rightMouseUp', 'otherMouseDown', 'otherMouseUp', 'leftMouseDragged', 'rightMouseDragged', 'scrollWheel', 'systemDefined', 'gesture', 'magnify'.
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
    @objc(make::) func makeTap(_ eventTypes: JSValue, _ callback: JSValue) -> HSEventTap?

    /// Synthesise a key stroke: press the modifiers + key, hold, then release.
    ///
    /// Waits for any queued or in-flight `chordStroke` to finish before posting so
    /// keys are not typed while chord modifiers are still down. Overlapping a
    /// `chordStroke` with `keyStroke` blocks the main thread until the chord
    /// finishes, which can compress the chord's timing at Hammerspoon's own event
    /// taps; sequence inside `chordStroke`'s completion callback if timing matters.
    /// - Parameter mods: {string[]} Array of modifier strings, e.g. ['cmd']
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
    @objc(keyStroke:::) func keyStroke(_ mods: JSValue, _ key: String, _ delay: JSValue)

    /// Synthesise a chord stroke by pressing each modifier's left key (`flagsChanged`
    /// with device-dependent side bits), pressing and releasing the key, then releasing
    /// the modifiers in reverse order. Use this instead of `keyStroke` for input methods
    /// or shortcut recorders that inspect `flagsChanged` or left/right modifier bits.
    ///
    /// Events are validated synchronously and then built and posted in order on a shared
    /// background serial queue (with ~5 ms between modifier transitions and `delay`
    /// hold), so this method returns immediately without stalling Hammerspoon's main
    /// run-loop event taps. Synchronous posters (`keyStroke`, `typeText`, `leftClick`,
    /// `scrollWheel`) wait for the queue to drain before posting, which blocks the main
    /// thread and may compress an overlapped chord's delivery; sequence follow-up work
    /// with `callback` when chord timing must be preserved.
    /// - Parameter mods: {string[]} Array of modifier strings (`'ctrl'`, `'shift'`, `'alt'`/`'opt'`, `'cmd'`, `'fn'`)
    /// - Parameter key: Key name, e.g. `'9'`
    /// - Parameter delay?: {number} Optional number of microseconds the key is held between `keyDown` and `keyUp`. Defaults to 200000 (200 ms), matching `keyStroke`.
    /// - Parameter callback?: {() => void} Optional completion callback invoked on the main thread after the final modifier release is posted. Dropped if the module or JS context shuts down before it runs.
    /// - Example:
    /// ```js
    /// hs.eventtap.chordStroke(['alt', 'cmd'], '9')                        // 200 ms default hold
    /// hs.eventtap.chordStroke(['alt', 'cmd'], '9', 10000)                 // 10 ms hold
    /// hs.eventtap.chordStroke(['alt', 'cmd'], '9', 10000, () => {
    ///   hs.eventtap.keyStroke(['cmd'], 'v')
    /// })
    /// ```
    @objc(chordStroke::::) func chordStroke(_ mods: JSValue, _ key: String, _ delay: JSValue, _ callback: JSValue)

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
    /// - Parameter point: {Object<string, number>} A point object `{x, y}` to click at
    /// - Parameter delay: Optional number of microseconds between mouseDown and mouseUp.
    ///   Defaults to 200000 (200 ms), matching upstream Hammerspoon's `hs.eventtap.leftClick`.
    /// - Example:
    /// ```js
    /// hs.eventtap.leftClick({ x: 800, y: 450 })         // 200 ms default hold
    /// hs.eventtap.leftClick({ x: 800, y: 450 }, 10000)  // 10 ms hold
    /// ```
    @objc(leftClick::) func leftClick(_ point: JSValue, _ delay: JSValue)

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

    nonisolated final class ModuleCancelScope: Sendable {
        private let cancelled = Mutex(false)

        var isCancelled: Bool { cancelled.withLock { $0 } }
        func cancel() { cancelled.withLock { $0 = true } }
    }

    private struct ActiveChord: Sendable {
        let moduleID: UUID
        let engineID: UUID
        let scope: ModuleCancelScope
        let token: ChordToken
    }

    private struct ChordRegistry: Sendable {
        var terminationGeneration: UInt64 = 0
        var retiredEngines: Set<UUID> = []
        var activeChords: [UUID: ActiveChord] = [:]
    }

    nonisolated private static let postQueue = DispatchQueue(
        label: "net.tenshu.Hammerspoon-2.eventtap.post",
        qos: .userInteractive
    )
    nonisolated private static let chordRegistry = Mutex(ChordRegistry())

    private static let installTerminationObserver: Void = {
        _ = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: nil
        ) { _ in
            cancelAllChordsAndDrain()
        }
    }()

    private let instanceID = UUID()
    private let cancelScope = ModuleCancelScope()
    private var isShutDown = false
    private var createdTaps: [HSEventTap] = []
    private var pendingCallbacks: [UUID: JSValue] = [:]
    var chordDispatcher = ChordDispatcher()

    private var isAlive: Bool {
        !isShutDown && !cancelScope.isCancelled && !Self.isEngineRetired(engineID)
    }

    // MARK: - Module lifecycle

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        _ = Self.installTerminationObserver
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {
        guard !isShutDown else { return }
        isShutDown = true

        for t in createdTaps { t.stop() }
        createdTaps.removeAll()

        pendingCallbacks.removeAll()

        Self.cancelAndDrain(
            where: { $0.moduleID == instanceID },
            mutateRegistry: { _ in cancelScope.cancel() }
        )

        AKTrace("Shutdown of \(name): \(engineID)")
    }

    isolated deinit {
        pendingCallbacks.removeAll()
        AKTrace("Deinit of \(name): \(engineID)")
    }

    /// Retires an engine ID, cancels any active/queued chords from that engine,
    /// and drains the posting queue. Called during engine teardown even if `globalThis.hs` was replaced.
    nonisolated static func invalidateEngine(_ engineID: UUID) {
        cancelAndDrain(
            where: { $0.engineID == engineID },
            mutateRegistry: { reg in
                reg.retiredEngines.insert(engineID)
            }
        )
    }

    /// Cancels all queued or in-flight chords across the process and drains the
    /// posting queue. Called during app termination.
    nonisolated static func cancelAllChordsAndDrain() {
        cancelAndDrain(
            where: { _ in true },
            mutateRegistry: { reg in
                reg.terminationGeneration &+= 1
            }
        )
    }

    nonisolated private static func cancelAndDrain(
        where predicate: (ActiveChord) -> Bool,
        mutateRegistry: (inout ChordRegistry) -> Void
    ) {
        // Mark the shared scope/generation and every matching token cancelled under
        // one lock BEFORE broadcasting, so an in-flight worker cannot finish and start
        // a queued chord before that queued chord's token is marked cancelled.
        let tokens = chordRegistry.withLock { reg -> [ChordToken] in
            mutateRegistry(&reg)
            var matched: [ChordToken] = []
            for entry in reg.activeChords.values where predicate(entry) {
                entry.scope.cancel()
                entry.token.markCancelled()
                matched.append(entry.token)
            }
            return matched
        }
        for token in tokens {
            token.broadcast()
        }
        postQueue.sync {}
    }

    nonisolated private static func isEngineRetired(_ engineID: UUID) -> Bool {
        chordRegistry.withLock { $0.retiredEngines.contains(engineID) }
    }

    /// Waits for all queued chord work on the shared posting queue to finish.
    nonisolated static func drainPostQueue() {
        postQueue.sync {}
    }

    private static func waitForPostQueue() {
        postQueue.sync {}
    }

    private static func isCallable(_ value: JSValue) -> Bool {
        guard value.isObject,
              !value.isNull,
              !value.isUndefined,
              let ctx = value.context else {
            return false
        }
        let ctxRef = ctx.jsGlobalContextRef
        guard let objRef = unsafe JSValueToObject(ctxRef, value.jsValueRef, nil) else {
            return false
        }
        return unsafe JSObjectIsFunction(ctxRef, objRef)
    }

    // MARK: - API

    @objc(make::) func makeTap(_ eventTypes: JSValue, _ callback: JSValue) -> HSEventTap? {
        guard let bridgedEventTypes = eventTypes.toStringArray(method: "hs.eventtap.make", parameter: "eventTypes") else {
            return nil
        }
        let t = HSEventTap(eventTypes: bridgedEventTypes, callback: callback)
        createdTaps.append(t)
        return t
    }

    @objc(keyStroke:::) func keyStroke(_ mods: JSValue, _ key: String, _ delay: JSValue) {
        guard let bridgedMods = mods.toStringArray(method: "hs.eventtap.keyStroke", parameter: "mods") else {
            return
        }
        guard let keyCode = HSEventTapModule.keyCode(for: key) else {
            AKError("hs.eventtap.keyStroke: unknown key '\(key)'")
            return
        }

        var flags: CGEventFlags = []
        for m in bridgedMods {
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

        let dispatcher = chordDispatcher
        Self.waitForPostQueue()

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
        let hold = Self.parseHoldMicroseconds(delay)
        dispatcher.post(down, .cghidEventTap)
        if hold > 0 { dispatcher.performSleep(hold) }
        dispatcher.post(up, .cghidEventTap)
    }

    @objc(chordStroke::::) func chordStroke(_ mods: JSValue, _ key: String, _ delay: JSValue, _ callback: JSValue) {
        guard isAlive else { return }

        guard let bridgedMods = mods.toStringArray(method: "hs.eventtap.chordStroke", parameter: "mods") else {
            return
        }
        guard let keyCode = Self.keyCode(for: key) else {
            AKError("hs.eventtap.chordStroke: unknown key '\(key)'")
            return
        }
        let hold = Self.parseHoldMicroseconds(delay)

        // Re-check liveness after potentially reentrant JS reads (e.g. array getters
        // or valueOf hooks triggering hs.reload() / shutdown()).
        guard isAlive else { return }

        let callbackID: UUID?
        if Self.isCallable(callback) {
            let id = UUID()
            pendingCallbacks[id] = callback
            callbackID = id
        } else {
            if !callback.isUndefined && !callback.isNull {
                AKWarning("hs.eventtap.chordStroke: callback must be a function")
            }
            callbackID = nil
        }

        let sequence = Self.buildChordSequence(mods: bridgedMods, keyCode: keyCode)
        let interEventDelay = Self.chordInterEventDelayMicroseconds
        let dispatcher = chordDispatcher
        let chordID = UUID()
        let token = ChordToken()
        let scope = cancelScope
        let engID = engineID

        let generation = Self.chordRegistry.withLock { reg -> UInt64 in
            reg.activeChords[chordID] = ActiveChord(
                moduleID: instanceID,
                engineID: engID,
                scope: scope,
                token: token
            )
            return reg.terminationGeneration
        }

        Self.postQueue.async { [weak self] in
            defer {
                _ = Self.chordRegistry.withLock { $0.activeChords.removeValue(forKey: chordID) }
            }

            let isCancelledByScope: @Sendable () -> Bool = {
                if scope.isCancelled { return true }
                return Self.chordRegistry.withLock { reg in
                    reg.terminationGeneration != generation || reg.retiredEngines.contains(engID)
                }
            }

            let completedNormally = Self.dispatchChord(
                sequence: sequence,
                holdMicroseconds: hold,
                interEventDelayMicroseconds: interEventDelay,
                dispatcher: dispatcher,
                token: token,
                isScopeCancelled: isCancelledByScope
            )

            guard let callbackID else { return }
            let shouldInvoke = completedNormally && !token.isCancelled && !isCancelledByScope()
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let cb = self.pendingCallbacks.removeValue(forKey: callbackID)
                    guard shouldInvoke, self.isAlive else { return }
                    cb?.callSafely(withArguments: [], context: "hs.eventtap chordStroke")
                }
            }
        }
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

        let dispatcher = chordDispatcher
        Self.waitForPostQueue()

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
        dispatcher.post(ev, .cghidEventTap)
    }

    @objc(leftClick::) func leftClick(_ point: JSValue, _ delay: JSValue) {
        guard let bridgedPoint = point.toDoubleDictionary(method: "hs.eventtap.leftClick", parameter: "point") else {
            return
        }
        guard let x = bridgedPoint["x"], let y = bridgedPoint["y"], x.isFinite, y.isFinite else {
            AKError("hs.eventtap.leftClick: point must be {x, y} with finite numbers")
            return
        }
        let location = CGPoint(x: x, y: y)

        let dispatcher = chordDispatcher
        Self.waitForPostQueue()

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
        let hold = Self.parseHoldMicroseconds(delay)
        dispatcher.post(down, .cghidEventTap)
        if hold > 0 { dispatcher.performSleep(hold) }
        dispatcher.post(up, .cghidEventTap)
    }

    @objc func typeText(_ text: String) {
        Self.waitForPostQueue()
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

    // MARK: - Chord sequence & key-code helpers

    private enum ChordModifier: CaseIterable {
        case ctrl, shift, alt, cmd, fn

        var keyCode: CGKeyCode {
            switch self {
            case .ctrl:  return 59 // kVK_Control
            case .shift: return 56 // kVK_Shift
            case .alt:   return 58 // kVK_Option
            case .cmd:   return 55 // kVK_Command
            case .fn:    return 63 // kVK_Function
            }
        }

        var flags: CGEventFlags {
            switch self {
            case .ctrl:  return CGEventFlags(rawValue: CGEventFlags.maskControl.rawValue | UInt64(NX_DEVICELCTLKEYMASK))
            case .shift: return CGEventFlags(rawValue: CGEventFlags.maskShift.rawValue | UInt64(NX_DEVICELSHIFTKEYMASK))
            case .alt:   return CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | UInt64(NX_DEVICELALTKEYMASK))
            case .cmd:   return CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | UInt64(NX_DEVICELCMDKEYMASK))
            case .fn:    return .maskSecondaryFn
            }
        }

        static func parse(_ name: String) -> ChordModifier? {
            switch name.lowercased() {
            case "ctrl", "control":      return .ctrl
            case "shift":                return .shift
            case "alt", "opt", "option": return .alt
            case "cmd", "command":       return .cmd
            case "fn":                   return .fn
            default:                     return nil
            }
        }
    }

    /// Thread-safe cancellation token for a single queued or in-flight chord.
    nonisolated final class ChordToken: @unchecked Sendable {
        private let condition = NSCondition()
        private var cancelled = false

        var isCancelled: Bool {
            condition.lock()
            defer { condition.unlock() }
            return cancelled
        }

        func markCancelled() {
            condition.lock()
            cancelled = true
            condition.unlock()
        }

        func broadcast() {
            condition.lock()
            condition.broadcast()
            condition.unlock()
        }

        func cancel() {
            condition.lock()
            cancelled = true
            condition.broadcast()
            condition.unlock()
        }

        /// Sleeps up to `microseconds` unless cancelled first. Returns `true` if cancelled.
        func wait(microseconds: useconds_t) -> Bool {
            condition.lock()
            defer { condition.unlock() }
            if cancelled { return true }
            guard microseconds > 0 else { return false }
            let deadline = Date(timeIntervalSinceNow: Double(microseconds) / 1_000_000.0)
            while !cancelled {
                if !condition.wait(until: deadline) {
                    break
                }
            }
            return cancelled
        }

        /// Blocks until `cancel()` is called.
        func waitUntilCancelled() {
            condition.lock()
            while !cancelled {
                condition.wait()
            }
            condition.unlock()
        }
    }

    nonisolated struct ChordDispatcher: Sendable {
        var post: @Sendable (CGEvent, CGEventTapLocation) -> Void = { event, tap in
            event.post(tap: tap)
        }
        var sleep: (@Sendable (useconds_t) -> Void)? = nil
        var wait: (@Sendable (useconds_t, ChordToken) -> Void)? = nil
        var makeEvent: @Sendable (SyntheticKeyEvent, CGEventSource?) -> CGEvent? = HSEventTapModule.buildChordCGEvent

        func performSleep(_ microseconds: useconds_t) {
            if let sleep {
                sleep(microseconds)
            } else if let wait {
                wait(microseconds, ChordToken())
            } else {
                usleep(microseconds)
            }
        }
    }

    nonisolated private static func logErrorAsync(_ message: String) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                AKError(message)
            }
        }
    }

    @discardableResult
    nonisolated private static func dispatchChord(
        sequence: [SyntheticKeyEvent],
        holdMicroseconds: useconds_t,
        interEventDelayMicroseconds: useconds_t,
        dispatcher: ChordDispatcher,
        token: ChordToken,
        isScopeCancelled: @Sendable () -> Bool
    ) -> Bool {
        func isCancelled() -> Bool {
            token.isCancelled || isScopeCancelled()
        }

        guard !sequence.isEmpty, sequence.count.isMultiple(of: 2), !isCancelled() else {
            return false
        }

        let source = CGEventSource(stateID: .combinedSessionState)
        let pressCount = sequence.count / 2
        var reservedReleases: [CGEvent] = []
        reservedReleases.reserveCapacity(pressCount)

        func postReservedReleases() {
            while let fallback = reservedReleases.popLast() {
                fallback.timestamp = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
                dispatcher.post(fallback, .cghidEventTap)
            }
        }

        func sleepGap(_ gap: useconds_t) {
            guard gap > 0 else { return }
            if let wait = dispatcher.wait {
                wait(gap, token)
            } else if let sleep = dispatcher.sleep {
                sleep(gap)
            } else {
                _ = token.wait(microseconds: gap)
            }
        }

        // Press phase: pre-build and reserve each press's matching release before posting.
        for i in 0..<pressCount {
            if isCancelled() {
                postReservedReleases()
                return false
            }
            let releaseSpec = sequence[sequence.count - 1 - i]
            guard let reservedRelease = dispatcher.makeEvent(releaseSpec, source) else {
                logErrorAsync("hs.eventtap.chordStroke: failed to reserve release CGEvent")
                postReservedReleases()
                return false
            }
            guard let pressEvent = dispatcher.makeEvent(sequence[i], source) else {
                logErrorAsync("hs.eventtap.chordStroke: failed to create CGEvent")
                postReservedReleases()
                return false
            }
            reservedReleases.append(reservedRelease)
            dispatcher.post(pressEvent, .cghidEventTap)

            let gap = (sequence[i].type == .keyDown) ? holdMicroseconds : interEventDelayMicroseconds
            sleepGap(gap)
            if isCancelled() {
                postReservedReleases()
                return false
            }
        }

        // Release phase: prefer a fresh release CGEvent for accurate timestamps, falling back
        // to the pre-reserved event if creation fails.
        for i in pressCount..<sequence.count {
            if isCancelled() {
                postReservedReleases()
                return false
            }
            let fallback = reservedReleases.removeLast()
            let releaseEvent: CGEvent
            if let fresh = dispatcher.makeEvent(sequence[i], source) {
                releaseEvent = fresh
            } else {
                logErrorAsync("hs.eventtap.chordStroke: failed to create release CGEvent; using reserved fallback")
                fallback.timestamp = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
                releaseEvent = fallback
            }
            dispatcher.post(releaseEvent, .cghidEventTap)

            if i < sequence.count - 1 {
                sleepGap(interEventDelayMicroseconds)
                if isCancelled() {
                    postReservedReleases()
                    return false
                }
            }
        }

        return true
    }

    nonisolated struct SyntheticKeyEvent: Equatable, Sendable {
        let type: CGEventType
        let keyCode: CGKeyCode
        let flags: CGEventFlags
    }

    /// Inter-event spacing between modifier flagsChanged events and the key stroke
    /// so downstream event taps and input methods observe each event in order.
    private static let chordInterEventDelayMicroseconds: useconds_t = 5_000

    static func parseHoldMicroseconds(_ delay: JSValue) -> useconds_t {
        var hold: useconds_t = 200_000
        if delay.isNumber {
            let v = delay.toDouble()
            if v.isFinite && v >= 0 {
                hold = useconds_t(min(v, 5_000_000))
            }
        }
        return hold
    }

    static func buildChordSequence(mods: [String], keyCode: CGKeyCode) -> [SyntheticKeyEvent] {
        var requested: Set<ChordModifier> = []
        for m in mods {
            if let parsed = ChordModifier.parse(m) {
                requested.insert(parsed)
            } else {
                AKWarning("hs.eventtap.chordStroke: unknown modifier '\(m)'")
            }
        }

        let activeModifiers = ChordModifier.allCases.filter { requested.contains($0) }
        guard !activeModifiers.isEmpty else {
            return [
                SyntheticKeyEvent(type: .keyDown, keyCode: keyCode, flags: []),
                SyntheticKeyEvent(type: .keyUp, keyCode: keyCode, flags: []),
            ]
        }

        var events: [SyntheticKeyEvent] = []
        events.reserveCapacity(activeModifiers.count * 2 + 2)

        var flags: CGEventFlags = .maskNonCoalesced
        for mod in activeModifiers {
            flags.insert(mod.flags)
            events.append(SyntheticKeyEvent(type: .flagsChanged, keyCode: mod.keyCode, flags: flags))
        }

        events.append(SyntheticKeyEvent(type: .keyDown, keyCode: keyCode, flags: flags))
        events.append(SyntheticKeyEvent(type: .keyUp, keyCode: keyCode, flags: flags))

        for mod in activeModifiers.reversed() {
            flags.remove(mod.flags)
            events.append(SyntheticKeyEvent(type: .flagsChanged, keyCode: mod.keyCode, flags: flags))
        }

        return events
    }

    nonisolated static func buildChordCGEvent(spec: SyntheticKeyEvent, source: CGEventSource?) -> CGEvent? {
        let keyDown = (spec.type != .keyUp)
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: spec.keyCode, keyDown: keyDown) else {
            return nil
        }
        if spec.type == .flagsChanged {
            event.type = .flagsChanged
        }
        event.flags = spec.flags
        return event
    }

    static func buildChordCGEvents(sequence: [SyntheticKeyEvent], source: CGEventSource?) -> [CGEvent]? {
        var result: [CGEvent] = []
        result.reserveCapacity(sequence.count)

        for spec in sequence {
            guard let event = buildChordCGEvent(spec: spec, source: source) else {
                return nil
            }
            result.append(event)
        }

        return result
    }

    static func keyCode(for name: String) -> CGKeyCode? {
        return virtualKeyCodes[name.lowercased()]
    }
}
