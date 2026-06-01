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
}
