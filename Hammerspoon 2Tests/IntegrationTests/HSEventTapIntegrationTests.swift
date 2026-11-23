//
//  HSEventTapIntegrationTests.swift
//  Hammerspoon 2Tests
//

import Testing
import CoreGraphics
import IOKit.hidsystem
@testable import Hammerspoon_2

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
    func testScrollWheelUnits() {
        let h = JSTestHarness()
        h.loadModule(HSEventTapModule.self, as: "eventtap")
        // Zero deltas: posts a harmless no-op scroll — never scrolls the desktop mid-run.
        _ = h.eval("""
            hs.eventtap.scrollWheel(0, 0)            // unit omitted → pixel
            hs.eventtap.scrollWheel(0, 0, 'pixel')
            hs.eventtap.scrollWheel(0, 0, 'line')
            hs.eventtap.scrollWheel(0, 0, 'bogus')   // warns, falls back to pixel
        """)
        #expect(h.hasException == false)
    }

    @Test("scrollWheel tolerates non-finite deltas")
    func testScrollWheelNonFinite() {
        let h = JSTestHarness()
        h.loadModule(HSEventTapModule.self, as: "eventtap")
        // NaN/Infinity become 0-delta — no throw, no desktop scroll.
        _ = h.eval("""
            hs.eventtap.scrollWheel(NaN, NaN, 'pixel')
            hs.eventtap.scrollWheel(Infinity, -Infinity, 'pixel')
        """)
        #expect(h.hasException == false)
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

    @Test("chordStroke exists and validates arguments without posting events")
    func testChordStrokeJSValidation() {
        let h = JSTestHarness()
        h.loadModule(HSEventTapModule.self, as: "eventtap")
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
        #expect(h.hasException == false)
        #expect(result as? Bool == true)
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
        #expect(cgEvents.count == expected.count)
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
        #expect(cgEvents.count == 2)
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
