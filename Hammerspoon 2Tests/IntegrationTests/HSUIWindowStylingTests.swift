//
//  HSUIWindowStylingTests.swift
//  Hammerspoon 2Tests
//

import Testing
@testable import Hammerspoon_2

struct HSUIWindowStylingTests {
    @Test("borderless() is chainable")
    func testBorderlessChainable() {
        let h = JSTestHarness()
        h.loadModuleRoot()
        let result = h.eval("typeof hs.ui.window().borderless()")
        #expect(result as? String == "object")
    }

    @Test("level() accepts all four name values")
    func testLevelAcceptsNames() {
        let h = JSTestHarness()
        h.loadModuleRoot()
        for name in ["normal", "floating", "popUpMenu", "screenSaver"] {
            _ = h.eval("hs.ui.window().level('\(name)')")
            #expect(h.hasException == false)
        }
    }

    @Test("center() returns the window builder")
    func testCenter() {
        let h = JSTestHarness()
        h.loadModuleRoot()
        let result = h.eval("typeof hs.ui.window().center()")
        #expect(result as? String == "object")
    }

    @Test("full builder chain compiles and runs")
    func testFullChain() {
        let h = JSTestHarness()
        h.loadModuleRoot()
        _ = h.eval("""
            hs.ui.window()
              .borderless()
              .level('floating')
              .frame({w: 400, h: 200})
              .center()
              .canBecomeKey(true)
              .onKey((key, mods) => {})
              .onBlur(() => {})
        """)
        #expect(h.hasException == false)
    }
}
