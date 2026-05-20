//
//  HSHotkeyDoubleTapTests.swift
//  Hammerspoon 2Tests
//

import Testing
@testable import Hammerspoon_2

struct HSHotkeyDoubleTapTests {
    @Test("bindDoubleTap returns a non-null object for valid modifier")
    func testBindReturns() {
        let h = JSTestHarness()
        h.loadModule(HSHotkeyModule.self, as: "hotkey")
        let result = h.eval("hs.hotkey.bindDoubleTap('shift', () => {}) !== null")
        #expect(result as? Bool == true)
    }

    @Test("bindDoubleTap returns null for unknown modifier")
    func testRejectsUnknownModifier() {
        let h = JSTestHarness()
        h.loadModule(HSHotkeyModule.self, as: "hotkey")
        let result = h.eval("hs.hotkey.bindDoubleTap('nope', () => {})")
        let isNullish = (result == nil) || (result as? NSNull) != nil
        #expect(isNullish == true)
    }

    @Test("returned hotkey supports unbind without throwing")
    func testUnbind() {
        let h = JSTestHarness()
        h.loadModule(HSHotkeyModule.self, as: "hotkey")
        _ = h.eval("""
            const hk = hs.hotkey.bindDoubleTap('ctrl', () => {})
            hk.unbind()
        """)
        #expect(h.hasException == false)
    }
}
