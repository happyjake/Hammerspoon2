//
//  HSEventTapIntegrationTests.swift
//  Hammerspoon 2Tests
//

import AppKit
import Foundation
import Synchronization
import Testing
import CoreGraphics
import IOKit.hidsystem
import JavaScriptCore
@testable import Hammerspoon_2

@Suite("hs.eventtap tests", .serialized)
struct HSEventTapIntegrationTests {
    @Test("make() returns an HSEventTap object")
    func testMake() {
        let h = JSTestHarness()
        h.loadModule(HSEventTapModule.self, as: "eventtap")
        let result = h.eval("typeof hs.eventtap.make(['keyDown'], () => false)")
        #expect(result as? String == "object")
    }

    @Test("tap.isRunning starts false")
    func testInitialState() {
        let h = JSTestHarness()
        h.loadModule(HSEventTapModule.self, as: "eventtap")
        let result = h.eval("hs.eventtap.make(['keyDown'], () => false).isRunning")
        #expect(result as? Bool == false)
    }

    @Test("tap.start() and tap.stop() do not throw")
    func testStartStop() {
        let h = JSTestHarness()
        h.loadModule(HSEventTapModule.self, as: "eventtap")
        // start() may return false without Input Monitoring permission, but should not throw
        _ = h.eval("""
            const tap = hs.eventtap.make(['keyDown'], () => false)
            tap.start()
            tap.stop()
        """)
        #expect(h.hasException == false)
    }

    @Test("keyStroke and typeText are callable (M1 stubs)")
    func testStubs() {
        let h = JSTestHarness()
        h.loadModule(HSEventTapModule.self, as: "eventtap")
        _ = h.eval("hs.eventtap.keyStroke(['cmd'], 'v')")
        _ = h.eval("hs.eventtap.typeText('hello')")
        #expect(h.hasException == false)
    }

    @Test("scrollWheel and leftClick are functions")
    func testSynthesisFunctionsExist() {
        let h = JSTestHarness()
        h.loadModule(HSEventTapModule.self, as: "eventtap")
        #expect(h.eval("typeof hs.eventtap.scrollWheel") as? String == "function")
        #expect(h.eval("typeof hs.eventtap.leftClick") as? String == "function")
    }

    @Test("scrollWheel accepts all unit forms without throwing")
    func testScrollWheelUnits() throws {
        let (h, _, recorder) = try makeChordHarness()
        _ = h.eval("""
            hs.eventtap.scrollWheel(0, 0)            // unit omitted → pixel
            hs.eventtap.scrollWheel(0, 0, 'pixel')
            hs.eventtap.scrollWheel(0, 0, 'line')
            hs.eventtap.scrollWheel(0, 0, 'bogus')   // warns, falls back to pixel
        """)
        #expect(h.hasException == false)
        #expect(recorder.actions.count == 4)
    }

    @Test("scrollWheel tolerates non-finite deltas")
    func testScrollWheelNonFinite() throws {
        let (h, _, recorder) = try makeChordHarness()
        _ = h.eval("""
            hs.eventtap.scrollWheel(NaN, NaN, 'pixel')
            hs.eventtap.scrollWheel(Infinity, -Infinity, 'pixel')
        """)
        #expect(h.hasException == false)
        #expect(recorder.actions.count == 2)
    }

    @Test("leftClick rejects malformed points without throwing or posting")
    func testLeftClickValidation() {
        let h = JSTestHarness()
        h.loadModule(HSEventTapModule.self, as: "eventtap")
        // All invalid → AKError + early return. No synthetic click ever reaches
        // the desktop from this suite (a real click would hit whatever is under
        // the test runner — behaviour is verified manually on hardware instead).
        _ = h.eval("""
            hs.eventtap.leftClick({})                  // missing x/y
            hs.eventtap.leftClick({ x: 10 })           // missing y
            hs.eventtap.leftClick({ x: NaN, y: 5 })    // non-finite
            hs.eventtap.leftClick({ x: NaN, y: 5, extra: undefined }) // undefined key omitted
            hs.eventtap.leftClick({ x: true })         // boolean x bridged, missing y
        """)
        #expect(h.hasException == false)
    }

    @Test("make() with mouse event types returns an HSEventTap object")
    func testMakeMouseTypes() {
        let h = JSTestHarness()
        h.loadModule(HSEventTapModule.self, as: "eventtap")
        // Each mouse type name must resolve to a tap object without throwing
        let mouseTypes = [
            "mouseMoved", "leftMouseDown", "leftMouseUp",
            "rightMouseDown", "rightMouseUp",
            "otherMouseDown", "otherMouseUp",
            "leftMouseDragged", "rightMouseDragged",
            "scrollWheel",
        ]
        for typeName in mouseTypes {
            let result = h.eval("typeof hs.eventtap.make(['\(typeName)'], () => false)")
            #expect(result as? String == "object", "Expected object for type '\(typeName)'")
        }
        #expect(h.hasException == false)
    }

    @Test("make() with mixed keyboard and mouse types returns an HSEventTap object")
    func testMakeMixedTypes() {
        let h = JSTestHarness()
        h.loadModule(HSEventTapModule.self, as: "eventtap")
        let result = h.eval("typeof hs.eventtap.make(['keyDown', 'mouseMoved', 'scrollWheel'], () => false)")
        #expect(result as? String == "object")
        #expect(h.hasException == false)
    }

    @Test("make() with systemDefined and gesture types returns an HSEventTap object")
    func testMakeSystemDefinedAndGestureTypes() {
        let h = JSTestHarness()
        h.loadModule(HSEventTapModule.self, as: "eventtap")
        // 'systemDefined' = media keys (brightness/volume…), 'gesture' = trackpad touches.
        for typeName in ["systemDefined", "gesture"] {
            let result = h.eval("typeof hs.eventtap.make(['\(typeName)'], () => false)")
            #expect(result as? String == "object", "Expected object for type '\(typeName)'")
        }
        _ = h.eval("""
            const tap = hs.eventtap.make(['systemDefined', 'gesture'], () => false)
            tap.start()
            tap.stop()
        """)
        #expect(h.hasException == false)
    }

    @Test("make, keyStroke, and leftClick throw TypeError on wrong-typed collection arguments and keep context usable")
    func testCollectionArgumentValidation() {
        let h = JSTestHarness()
        h.loadModule(HSEventTapModule.self, as: "eventtap")
        let result = h.eval("""
        (function() {
            var makeThrew = false;
            var keyStrokeThrew = false;
            var leftClickThrew = false;
            try { hs.eventtap.make('keyDown', function() { return false; }); }
            catch (e) { makeThrew = (e instanceof TypeError) && /hs\\.eventtap\\.make.*eventTypes/.test(e.message); }
            try { hs.eventtap.keyStroke('cmd', 'a', 0); }
            catch (e) { keyStrokeThrew = (e instanceof TypeError) && /hs\\.eventtap\\.keyStroke.*mods/.test(e.message); }
            try { hs.eventtap.leftClick({ x: 'bad', y: 10 }, 0); }
            catch (e) { leftClickThrew = (e instanceof TypeError) && /hs\\.eventtap\\.leftClick.*point/.test(e.message); }
            // Valid calls after caught TypeErrors:
            var validTap = hs.eventtap.make(['keyDown'], function() { return false; });
            return makeThrew && keyStrokeThrew && leftClickThrew && typeof validTap === 'object';
        })()
        """)
        #expect(h.hasException == false)
        #expect(result as? Bool == true)
    }

    // MARK: - chordStroke

    nonisolated private enum RecordedChordAction: Equatable, Sendable {
        case post(tap: CGEventTapLocation, type: CGEventType, keyCode: CGKeyCode, flags: CGEventFlags)
        case sleep(useconds_t)
    }

    nonisolated private final class ChordRecorder: Sendable {
        private struct State: Sendable {
            var actions: [RecordedChordAction] = []
            var postedOnMainThread = false
        }

        private let state = Mutex(State())

        var actions: [RecordedChordAction] {
            state.withLock { $0.actions }
        }

        var postedOnMainThread: Bool {
            state.withLock { $0.postedOnMainThread }
        }

        func append(_ action: RecordedChordAction, isMainThread: Bool = false) {
            state.withLock { s in
                s.actions.append(action)
                if isMainThread { s.postedOnMainThread = true }
            }
        }

        func makeDispatcher(
            onSleep: (@Sendable (useconds_t) -> Void)? = nil,
            onWait: (@Sendable (useconds_t, HSEventTapModule.ChordToken) -> Void)? = nil,
            onBarrier: @escaping @Sendable () -> Void = {}
        ) -> HSEventTapModule.ChordDispatcher {
            let waitClosure: (@Sendable (useconds_t, HSEventTapModule.ChordToken) -> Void)?
            if let onWait {
                waitClosure = { [weak self] (microseconds: useconds_t, token: HSEventTapModule.ChordToken) in
                    self?.append(.sleep(microseconds))
                    onWait(microseconds, token)
                }
            } else {
                waitClosure = nil
            }

            return HSEventTapModule.ChordDispatcher(
                post: { [weak self] event, tap in
                    let action = RecordedChordAction.post(
                        tap: tap,
                        type: event.type,
                        keyCode: CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)),
                        flags: event.flags
                    )
                    self?.append(action, isMainThread: Thread.isMainThread)
                },
                sleep: { [weak self] microseconds in
                    self?.append(.sleep(microseconds))
                    onSleep?(microseconds)
                },
                wait: waitClosure,
                onBarrier: onBarrier
            )
        }

        var dispatcher: HSEventTapModule.ChordDispatcher {
            makeDispatcher()
        }
    }

    private func makeChordHarness(
        onSleep: (@Sendable (useconds_t) -> Void)? = nil,
        onWait: (@Sendable (useconds_t, HSEventTapModule.ChordToken) -> Void)? = nil,
        onBarrier: @escaping @Sendable () -> Void = {}
    ) throws -> (harness: JSTestHarness, module: HSEventTapModule, recorder: ChordRecorder) {
        let h = JSTestHarness()
        h.loadModule(HSEventTapModule.self, as: "eventtap")
        let module = try #require(
            h.context.objectForKeyedSubscript("hs")?
                .objectForKeyedSubscript("eventtap")?
                .toObject() as? HSEventTapModule
        )
        let recorder = ChordRecorder()
        module.chordDispatcher = recorder.makeDispatcher(
            onSleep: onSleep,
            onWait: onWait,
            onBarrier: onBarrier
        )
        return (h, module, recorder)
    }

    @Test("chordStroke exists and validates arguments without posting events")
    func testChordStrokeJSValidation() throws {
        let (h, _, recorder) = try makeChordHarness()
        #expect(h.eval("typeof hs.eventtap.chordStroke") as? String == "function")

        let result = h.eval("""
        (function() {
            var badMods = ['cmd', 123, null, undefined, {}, ['cmd', 42]];
            var allModsRejected = badMods.every(function(m) {
                try {
                    hs.eventtap.chordStroke(m, '9', 0);
                    return false;
                } catch (e) {
                    return (e instanceof TypeError) &&
                           /hs\\.eventtap\\.chordStroke/.test(e.message) &&
                           /mods/.test(e.message);
                }
            });

            // Unknown key must return cleanly without throwing a JS exception.
            hs.eventtap.chordStroke(['alt', 'cmd'], 'not_a_real_key', 0);
            hs.eventtap.chordStroke([], 'not_a_real_key', 0);

            return allModsRejected;
        })()
        """)
        HSEventTapModule.drainPostQueue()
        #expect(h.hasException == false)
        #expect(result as? Bool == true)
        #expect(recorder.actions.isEmpty)
    }

    @Test("chordStroke from JS posts exact events, .cghidEventTap destination, and gaps on background queue")
    func testChordStrokeJSToSwiftPostingBoundary() throws {
        let (h, _, recorder) = try makeChordHarness()

        _ = h.eval("hs.eventtap.chordStroke(['alt', 'cmd'], '9', 10000)")
        #expect(h.hasException == false)

        HSEventTapModule.drainPostQueue()
        #expect(recorder.postedOnMainThread == false)

        let altBits = CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | UInt64(NX_DEVICELALTKEYMASK))
        let cmdBits = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | UInt64(NX_DEVICELCMDKEYMASK))
        let nonCoalesced = CGEventFlags.maskNonCoalesced

        let expected: [RecordedChordAction] = [
            .post(tap: .cghidEventTap, type: .flagsChanged, keyCode: 58, flags: [nonCoalesced, altBits]),
            .sleep(5_000),
            .post(tap: .cghidEventTap, type: .flagsChanged, keyCode: 55, flags: [nonCoalesced, altBits, cmdBits]),
            .sleep(5_000),
            .post(tap: .cghidEventTap, type: .keyDown, keyCode: 25, flags: [nonCoalesced, altBits, cmdBits]),
            .sleep(10_000),
            .post(tap: .cghidEventTap, type: .keyUp, keyCode: 25, flags: [nonCoalesced, altBits, cmdBits]),
            .sleep(5_000),
            .post(tap: .cghidEventTap, type: .flagsChanged, keyCode: 55, flags: [nonCoalesced, altBits]),
            .sleep(5_000),
            .post(tap: .cghidEventTap, type: .flagsChanged, keyCode: 58, flags: [nonCoalesced]),
        ]

        #expect(recorder.actions == expected)
    }

    @Test("chordStroke returns immediately before background posting finishes")
    func testChordStrokeReturnsImmediately() throws {
        let enteredFirstSleep = DispatchSemaphore(value: 0)
        let allowContinue = DispatchSemaphore(value: 0)
        let firstSleepOnly = Mutex(true)

        let (h, _, recorder) = try makeChordHarness(onSleep: { _ in
            let isFirst = firstSleepOnly.withLock { flag -> Bool in
                let was = flag
                flag = false
                return was
            }
            if isFirst {
                enteredFirstSleep.signal()
                allowContinue.wait()
            }
        })
        defer { allowContinue.signal() }

        _ = h.eval("hs.eventtap.chordStroke(['alt', 'cmd'], '9', 10000)")
        #expect(h.hasException == false)

        enteredFirstSleep.wait()
        #expect(recorder.actions.count == 2) // 1st post + 1st sleep recorded, 5 more posts remain

        allowContinue.signal()
        HSEventTapModule.drainPostQueue()
        #expect(recorder.actions.count == 11)
    }

    nonisolated private final class AsyncSignal: Sendable {
        private let state = Mutex<(signaled: Bool, waiters: [CheckedContinuation<Void, Never>])>((false, []))

        func signal() {
            let waiters = state.withLock { s -> [CheckedContinuation<Void, Never>] in
                s.signaled = true
                let w = s.waiters
                s.waiters.removeAll()
                return w
            }
            for w in waiters { w.resume() }
        }

        func wait() async {
            await withCheckedContinuation { cont in
                let shouldResume = state.withLock { s -> Bool in
                    if s.signaled { return true }
                    s.waiters.append(cont)
                    return false
                }
                if shouldResume { cont.resume() }
            }
        }
    }

    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }

    @Test("chordStroke completion callback runs on main thread after last release and survives GC")
    func testChordStrokeCompletionCallbackOnMain() async throws {
        let enteredFirstSleep = AsyncSignal()
        let allowContinue = DispatchSemaphore(value: 0)
        let firstSleepOnly = Mutex(true)

        let (h, _, recorder) = try makeChordHarness(onSleep: { _ in
            let isFirst = firstSleepOnly.withLock { flag -> Bool in
                let was = flag
                flag = false
                return was
            }
            if isFirst {
                enteredFirstSleep.signal()
                allowContinue.wait()
            }
        })
        defer { allowContinue.signal() }

        let callbackState = Mutex<(count: Int, onMain: Bool, actionsAtCallback: Int)>((0, false, 0))
        let recordCallback: @convention(block) () -> Void = {
            let count = recorder.actions.count
            let isMain = Thread.isMainThread
            callbackState.withLock { s in
                s.count += 1
                s.onMain = isMain
                s.actionsAtCallback = count
            }
        }
        h.context.setObject(recordCallback, forKeyedSubscript: "__recordCallback" as NSString)

        _ = h.eval("hs.eventtap.chordStroke(['alt', 'cmd'], '9', 10000, () => __recordCallback())")
        #expect(h.hasException == false)

        await enteredFirstSleep.wait()
        // Force GC while the chord is in-flight to verify the anonymous callback stays rooted.
        h.forceSynchronousGC()
        #expect(callbackState.withLock { $0.count } == 0)

        allowContinue.signal()
        HSEventTapModule.drainPostQueue()
        await drainMainQueue()

        let finalState = callbackState.withLock { $0 }
        #expect(finalState.count == 1)
        #expect(finalState.onMain == true)
        #expect(finalState.actionsAtCallback == 11)
    }

    @Test("keyStroke waits for an in-flight chord before posting and preserves keyStroke behaviour")
    func testKeyStrokeWaitsForInFlightChord() throws {
        let enteredFirstSleep = DispatchSemaphore(value: 0)
        let barrierEntered = DispatchSemaphore(value: 0)
        let allowContinue = DispatchSemaphore(value: 0)
        let firstSleepOnly = Mutex(true)
        let actionsBeforeUnblock = Mutex<[RecordedChordAction]>([])

        let recorder = ChordRecorder()
        let h = JSTestHarness()
        h.loadModule(HSEventTapModule.self, as: "eventtap")
        let module = try #require(
            h.context.objectForKeyedSubscript("hs")?
                .objectForKeyedSubscript("eventtap")?
                .toObject() as? HSEventTapModule
        )
        module.chordDispatcher = recorder.makeDispatcher(
            onSleep: { _ in
                let isFirst = firstSleepOnly.withLock { flag -> Bool in
                    let was = flag
                    flag = false
                    return was
                }
                if isFirst {
                    enteredFirstSleep.signal()
                    allowContinue.wait()
                }
            },
            onBarrier: {
                barrierEntered.signal()
            }
        )
        defer { allowContinue.signal() }

        _ = h.eval("hs.eventtap.chordStroke(['alt', 'cmd'], '9', 10000)")
        #expect(h.hasException == false)
        enteredFirstSleep.wait()

        // Wait on a background thread for keyStroke to reach the barrier, snapshot actions
        // before releasing the in-flight chord, then let the chord finish.
        let coordinatorDone = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            barrierEntered.wait()
            actionsBeforeUnblock.withLock { $0 = recorder.actions }
            allowContinue.signal()
            coordinatorDone.signal()
        }

        _ = h.eval("hs.eventtap.keyStroke(['cmd'], 'v', 10000)")
        #expect(h.hasException == false)
        coordinatorDone.wait()

        let altBits = CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | UInt64(NX_DEVICELALTKEYMASK))
        let cmdBits = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | UInt64(NX_DEVICELCMDKEYMASK))
        let nonCoalesced = CGEventFlags.maskNonCoalesced

        // Before unblocking, only the first chord event and sleep were recorded (keyStroke had not posted).
        #expect(actionsBeforeUnblock.withLock { $0 } == [
            .post(tap: .cghidEventTap, type: .flagsChanged, keyCode: 58, flags: [nonCoalesced, altBits]),
            .sleep(5_000),
        ])

        let expected: [RecordedChordAction] = [
            .post(tap: .cghidEventTap, type: .flagsChanged, keyCode: 58, flags: [nonCoalesced, altBits]),
            .sleep(5_000),
            .post(tap: .cghidEventTap, type: .flagsChanged, keyCode: 55, flags: [nonCoalesced, altBits, cmdBits]),
            .sleep(5_000),
            .post(tap: .cghidEventTap, type: .keyDown, keyCode: 25, flags: [nonCoalesced, altBits, cmdBits]),
            .sleep(10_000),
            .post(tap: .cghidEventTap, type: .keyUp, keyCode: 25, flags: [nonCoalesced, altBits, cmdBits]),
            .sleep(5_000),
            .post(tap: .cghidEventTap, type: .flagsChanged, keyCode: 55, flags: [nonCoalesced, altBits]),
            .sleep(5_000),
            .post(tap: .cghidEventTap, type: .flagsChanged, keyCode: 58, flags: [nonCoalesced]),
            .post(tap: .cghidEventTap, type: .keyDown, keyCode: 9, flags: .maskCommand),
            .sleep(10_000),
            .post(tap: .cghidEventTap, type: .keyUp, keyCode: 9, flags: .maskCommand),
        ]
        #expect(recorder.actions == expected)
    }

    @Test("shutdown mid-hold cancels unstarted chords and releases only keys that are down")
    func testShutdownMidHoldReleasesOnlyDownKeys() throws {
        let enteredHold = DispatchSemaphore(value: 0)
        let (h, module, recorder) = try makeChordHarness(onWait: { microseconds, token in
            if microseconds == 10_000 {
                enteredHold.signal()
                token.waitUntilCancelled()
            }
        })

        _ = h.eval("hs.eventtap.chordStroke(['alt', 'cmd'], '9', 10000)")
        _ = h.eval("hs.eventtap.chordStroke(['shift'], 'a', 10000)")
        #expect(h.hasException == false)

        enteredHold.wait()
        module.shutdown()

        let altBits = CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | UInt64(NX_DEVICELALTKEYMASK))
        let cmdBits = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | UInt64(NX_DEVICELCMDKEYMASK))
        let nonCoalesced = CGEventFlags.maskNonCoalesced

        let expected: [RecordedChordAction] = [
            .post(tap: .cghidEventTap, type: .flagsChanged, keyCode: 58, flags: [nonCoalesced, altBits]),
            .sleep(5_000),
            .post(tap: .cghidEventTap, type: .flagsChanged, keyCode: 55, flags: [nonCoalesced, altBits, cmdBits]),
            .sleep(5_000),
            .post(tap: .cghidEventTap, type: .keyDown, keyCode: 25, flags: [nonCoalesced, altBits, cmdBits]),
            .sleep(10_000),
            .post(tap: .cghidEventTap, type: .keyUp, keyCode: 25, flags: [nonCoalesced, altBits, cmdBits]),
            .post(tap: .cghidEventTap, type: .flagsChanged, keyCode: 55, flags: [nonCoalesced, altBits]),
            .post(tap: .cghidEventTap, type: .flagsChanged, keyCode: 58, flags: [nonCoalesced]),
        ]
        #expect(recorder.actions == expected)
    }

    @Test("shutdown during modifier press releases only the modifiers already pressed")
    func testShutdownMidPressReleasesOnlyPressedModifier() throws {
        let enteredFirstSleep = DispatchSemaphore(value: 0)
        let firstSleepOnly = Mutex(true)
        let (h, module, recorder) = try makeChordHarness(onWait: { _, token in
            let isFirst = firstSleepOnly.withLock { flag -> Bool in
                let was = flag
                flag = false
                return was
            }
            if isFirst {
                enteredFirstSleep.signal()
                token.waitUntilCancelled()
            }
        })

        _ = h.eval("hs.eventtap.chordStroke(['alt', 'cmd'], '9', 10000)")
        #expect(h.hasException == false)

        enteredFirstSleep.wait()
        module.shutdown()

        let altBits = CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | UInt64(NX_DEVICELALTKEYMASK))
        let nonCoalesced = CGEventFlags.maskNonCoalesced

        let expected: [RecordedChordAction] = [
            .post(tap: .cghidEventTap, type: .flagsChanged, keyCode: 58, flags: [nonCoalesced, altBits]),
            .sleep(5_000),
            .post(tap: .cghidEventTap, type: .flagsChanged, keyCode: 58, flags: [nonCoalesced]),
        ]
        #expect(recorder.actions == expected)
    }

    @Test("completion callback is dropped when module shuts down in-flight or before main delivery")
    func testCallbackDroppedAfterShutdown() async throws {
        // Case 1: Cancelled mid-flight by shutdown()
        do {
            let enteredHold = AsyncSignal()
            let (h, module, _) = try makeChordHarness(onWait: { microseconds, token in
                if microseconds == 10_000 {
                    enteredHold.signal()
                    token.waitUntilCancelled()
                }
            })

            let cbCount = Mutex(0)
            let inc: @convention(block) () -> Void = { cbCount.withLock { $0 += 1 } }
            h.context.setObject(inc, forKeyedSubscript: "__cb" as NSString)

            _ = h.eval("hs.eventtap.chordStroke(['alt', 'cmd'], '9', 10000, () => __cb())")
            await enteredHold.wait()
            module.shutdown()
            await drainMainQueue()
            #expect(cbCount.withLock { $0 } == 0)
        }

        // Case 2: Chord already finished on postQueue and queued callback on main,
        // then shutdown() runs on main before the queued callback executes.
        do {
            let (h, module, recorder) = try makeChordHarness()
            let cbCount = Mutex(0)
            let inc: @convention(block) () -> Void = { cbCount.withLock { $0 += 1 } }
            h.context.setObject(inc, forKeyedSubscript: "__cb" as NSString)

            _ = h.eval("hs.eventtap.chordStroke(['alt', 'cmd'], '9', 0, () => __cb())")
            HSEventTapModule.drainPostQueue()
            #expect(recorder.actions.count == 10) // 6 posts + 4 inter-event sleeps (0 hold)

            module.shutdown()
            await drainMainQueue()
            #expect(cbCount.withLock { $0 } == 0)
        }
    }

    @Test("app termination notification cancels in-flight chords, releases down keys, and drops callbacks")
    func testAppTerminationCancelsAndReleasesDownKeys() async throws {
        let enteredHold = AsyncSignal()
        let (h, _, recorder) = try makeChordHarness(onWait: { microseconds, token in
            if microseconds == 10_000 {
                enteredHold.signal()
                token.waitUntilCancelled()
            }
        })

        let cbCount = Mutex(0)
        let inc: @convention(block) () -> Void = { cbCount.withLock { $0 += 1 } }
        h.context.setObject(inc, forKeyedSubscript: "__cb" as NSString)

        _ = h.eval("hs.eventtap.chordStroke(['alt', 'cmd'], '9', 10000, () => __cb())")
        _ = h.eval("hs.eventtap.chordStroke(['shift'], 'a', 10000, () => __cb())")
        await enteredHold.wait()

        NotificationCenter.default.post(name: NSApplication.willTerminateNotification, object: nil)
        await drainMainQueue()

        #expect(cbCount.withLock { $0 } == 0)
        // First chord released 9, cmd, alt; second queued chord never started (9 actions total).
        #expect(recorder.actions.count == 9)
    }

    @Test("chordStroke sequence for alt+cmd+9 presses and releases left modifier keys in fixed order")
    func testChordStrokeAltCmdSequence() throws {
        let keyCode9 = try #require(HSEventTapModule.keyCode(for: "9"))
        #expect(keyCode9 == 25)

        let altBits = CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | UInt64(NX_DEVICELALTKEYMASK))
        let cmdBits = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | UInt64(NX_DEVICELCMDKEYMASK))
        let nonCoalesced = CGEventFlags.maskNonCoalesced

        let expected: [HSEventTapModule.SyntheticKeyEvent] = [
            .init(type: .flagsChanged, keyCode: 58, flags: [nonCoalesced, altBits]),
            .init(type: .flagsChanged, keyCode: 55, flags: [nonCoalesced, altBits, cmdBits]),
            .init(type: .keyDown, keyCode: 25, flags: [nonCoalesced, altBits, cmdBits]),
            .init(type: .keyUp, keyCode: 25, flags: [nonCoalesced, altBits, cmdBits]),
            .init(type: .flagsChanged, keyCode: 55, flags: [nonCoalesced, altBits]),
            .init(type: .flagsChanged, keyCode: 58, flags: [nonCoalesced]),
        ]

        let sequence = HSEventTapModule.buildChordSequence(mods: ["alt", "cmd"], keyCode: keyCode9)
        #expect(sequence == expected)

        // Reverse order, aliases, and duplicates normalize to the exact same sequence.
        let normalizedSequence = HSEventTapModule.buildChordSequence(mods: ["COMMAND", "opt", "cmd"], keyCode: keyCode9)
        #expect(normalizedSequence == expected)

        // Verify unposted CGEvents preserve exact types, keycodes, and flags.
        let cgEvents = try #require(HSEventTapModule.buildChordCGEvents(sequence: sequence, source: nil))
        try #require(cgEvents.count == expected.count)
        for (ev, exp) in zip(cgEvents, expected) {
            #expect(ev.type == exp.type)
            #expect(CGKeyCode(ev.getIntegerValueField(.keyboardEventKeycode)) == exp.keyCode)
            #expect(ev.flags == exp.flags)
        }
    }

    @Test("chordStroke sequence for single modifier wraps keyDown/keyUp with flagsChanged")
    func testChordStrokeSingleModifiers() throws {
        let keyCodeV = try #require(HSEventTapModule.keyCode(for: "v"))
        let nonCoalesced = CGEventFlags.maskNonCoalesced

        let cases: [(mod: String, modKeyCode: CGKeyCode, modFlags: CGEventFlags)] = [
            ("ctrl", 59, CGEventFlags(rawValue: CGEventFlags.maskControl.rawValue | UInt64(NX_DEVICELCTLKEYMASK))),
            ("shift", 56, CGEventFlags(rawValue: CGEventFlags.maskShift.rawValue | UInt64(NX_DEVICELSHIFTKEYMASK))),
            ("alt", 58, CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | UInt64(NX_DEVICELALTKEYMASK))),
            ("cmd", 55, CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | UInt64(NX_DEVICELCMDKEYMASK))),
            ("fn", 63, .maskSecondaryFn),
        ]

        for entry in cases {
            let expected: [HSEventTapModule.SyntheticKeyEvent] = [
                .init(type: .flagsChanged, keyCode: entry.modKeyCode, flags: [nonCoalesced, entry.modFlags]),
                .init(type: .keyDown, keyCode: keyCodeV, flags: [nonCoalesced, entry.modFlags]),
                .init(type: .keyUp, keyCode: keyCodeV, flags: [nonCoalesced, entry.modFlags]),
                .init(type: .flagsChanged, keyCode: entry.modKeyCode, flags: [nonCoalesced]),
            ]
            let actual = HSEventTapModule.buildChordSequence(mods: [entry.mod], keyCode: keyCodeV)
            #expect(actual == expected, "Mismatch for modifier '\(entry.mod)'")
        }
    }

    @Test("chordStroke sequence for all modifiers orders ctrl, shift, alt, cmd, fn and releases in reverse")
    func testChordStrokeAllModifiersOrder() throws {
        let keyCodeA = try #require(HSEventTapModule.keyCode(for: "a"))
        let sequence = HSEventTapModule.buildChordSequence(
            mods: ["fn", "cmd", "alt", "shift", "ctrl"],
            keyCode: keyCodeA
        )
        #expect(sequence.count == 12)
        #expect(sequence.map(\.type) == [
            .flagsChanged, .flagsChanged, .flagsChanged, .flagsChanged, .flagsChanged,
            .keyDown, .keyUp,
            .flagsChanged, .flagsChanged, .flagsChanged, .flagsChanged, .flagsChanged,
        ])
        #expect(sequence.map(\.keyCode) == [59, 56, 58, 55, 63, keyCodeA, keyCodeA, 63, 55, 58, 56, 59])
        #expect(sequence.last?.flags == .maskNonCoalesced)
    }

    @Test("chordStroke sequence with no modifiers matches keyStroke (keyDown/keyUp with empty flags)")
    func testChordStrokeNoModifiers() throws {
        let keyCode9 = try #require(HSEventTapModule.keyCode(for: "9"))
        let expected: [HSEventTapModule.SyntheticKeyEvent] = [
            .init(type: .keyDown, keyCode: keyCode9, flags: []),
            .init(type: .keyUp, keyCode: keyCode9, flags: []),
        ]

        let emptySeq = HSEventTapModule.buildChordSequence(mods: [], keyCode: keyCode9)
        #expect(emptySeq == expected)

        let unknownOnlySeq = HSEventTapModule.buildChordSequence(mods: ["unknown"], keyCode: keyCode9)
        #expect(unknownOnlySeq == expected)

        let cgEvents = try #require(HSEventTapModule.buildChordCGEvents(sequence: emptySeq, source: nil))
        try #require(cgEvents.count == 2)
        #expect(cgEvents[0].type == .keyDown)
        #expect(cgEvents[0].flags == [])
        #expect(cgEvents[1].type == .keyUp)
        #expect(cgEvents[1].flags == [])
    }

    @Test("chordStroke delay parsing matches keyStroke defaults and clamping")
    func testChordStrokeDelayParsing() {
        let h = JSTestHarness()
        let undef = h.evalValue("undefined")!
        let nullVal = h.evalValue("null")!
        let nanVal = h.evalValue("NaN")!
        let negVal = h.evalValue("-10")!
        let zeroVal = h.evalValue("0")!
        let customVal = h.evalValue("15000")!
        let overMaxVal = h.evalValue("9999999")!

        #expect(HSEventTapModule.parseHoldMicroseconds(undef) == 200_000)
        #expect(HSEventTapModule.parseHoldMicroseconds(nullVal) == 200_000)
        #expect(HSEventTapModule.parseHoldMicroseconds(nanVal) == 200_000)
        #expect(HSEventTapModule.parseHoldMicroseconds(negVal) == 200_000)
        #expect(HSEventTapModule.parseHoldMicroseconds(zeroVal) == 0)
        #expect(HSEventTapModule.parseHoldMicroseconds(customVal) == 15_000)
        #expect(HSEventTapModule.parseHoldMicroseconds(overMaxVal) == 5_000_000)
    }
}
