//
//  HSEventTapIntegrationTests.swift
//  Hammerspoon 2Tests
//

import Testing
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
}
