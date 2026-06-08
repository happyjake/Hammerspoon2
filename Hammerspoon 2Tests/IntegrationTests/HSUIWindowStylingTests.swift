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

    @Test("anchor() accepts edge values and is chainable")
    func testAnchor() {
        let h = JSTestHarness()
        h.loadModuleRoot()
        for edge in ["bottom", "top", "center", "BOTTOM", "nonsense"] {
            let result = h.eval("typeof hs.ui.window().anchor('\(edge)')")
            #expect(result as? String == "object", "anchor('\(edge)') should return the builder")
            #expect(h.hasException == false)
        }
    }

    @Test("anchor('bottom') drives a full borderless HUD chain without throwing")
    func testAnchorHUDChain() {
        let h = JSTestHarness()
        h.loadModuleRoot()
        _ = h.eval("""
            hs.ui.window()
              .borderless()
              .level('floating')
              .frame({ w: 900, h: 36 })
              .anchor('bottom')
              .canBecomeKey(false)
              .ignoresMouseEvents(true)
              .text('CHAT  j/k scroll  Esc exit').end()
        """)
        #expect(h.hasException == false)
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
