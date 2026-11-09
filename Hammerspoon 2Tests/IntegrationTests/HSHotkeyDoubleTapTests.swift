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

    @Test("bind and bindSpec reject wrong-typed mods with TypeError and accept valid string array")
    func testBindCollectionValidation() {
        let h = JSTestHarness()
        h.loadModule(HSHotkeyModule.self, as: "hotkey")
        let result = h.eval("""
        (function() {
            var bindThrew = false;
            var bindSpecThrew = false;
            try { hs.hotkey.bind('cmd', 'f19', function() {}, null); }
            catch (e) { bindThrew = (e instanceof TypeError) && /hs\\.hotkey\\.bind.*mods/.test(e.message); }
            try { hs.hotkey.bindSpec([42], 'f19', 'msg', function() {}, null); }
            catch (e) { bindSpecThrew = (e instanceof TypeError) && /hs\\.hotkey\\.bindSpec.*mods/.test(e.message); }
            // Valid call after caught TypeErrors: pass unknown key so no system hotkey is registered,
            // confirming context remains usable and valid array passes bridge validation without throwing.
            var afterValid = hs.hotkey.bind(['cmd', 'shift'], 'unknown_key_for_test', function() {}, null);
            return bindThrew && bindSpecThrew && (afterValid === null || afterValid === undefined);
        })()
        """)
        #expect(h.hasException == false)
        #expect(result as? Bool == true)
    }
}
