//
//  HSUITextFieldTests.swift
//  Hammerspoon 2Tests
//
//  Builder/API tests for hs.ui's textField element. The actual rendering and
//  key-event handling happen in SwiftUI and need manual smoke testing.
//

import Testing
@testable import Hammerspoon_2

struct HSUITextFieldTests {
    @Test("textField is chainable and returns the window")
    func testTextFieldChainable() {
        let h = JSTestHarness()
        h.loadModuleRoot()
        let result = h.eval("typeof hs.ui.window().textField('')")
        #expect(result as? String == "object")
        #expect(!h.hasException)
    }

    @Test("textField accepts a plain JS string as initial value")
    func testInitialString() {
        let h = JSTestHarness()
        h.loadModuleRoot()
        _ = h.eval("hs.ui.window().textField('hello').end()")
        #expect(!h.hasException)
    }

    @Test("textField accepts an HSString as initial value (reactive binding)")
    func testInitialHSString() {
        let h = JSTestHarness()
        h.loadModuleRoot()
        _ = h.eval("""
            var s = hs.ui.string('init')
            hs.ui.window().textField(s).end()
            s.set('mutated')
        """)
        h.expectEqual("s.value", "mutated")
        #expect(!h.hasException)
    }

    @Test("placeholder, focused, onChange, onSubmit, onKey all chain")
    func testModifiersChain() {
        let h = JSTestHarness()
        h.loadModuleRoot()
        _ = h.eval("""
            hs.ui.window()
              .vstack()
                .textField('')
                  .placeholder('Search…')
                  .focused(true)
                  .onChange(v => {})
                  .onSubmit(v => {})
                  .onKey((k, m) => false)
                .end()
              .end()
        """)
        #expect(!h.hasException)
    }

    @Test("Modifiers applied to a non-textField element warn but don't crash")
    func testModifiersOnWrongElement() {
        let h = JSTestHarness()
        h.loadModuleRoot()
        _ = h.eval("""
            hs.ui.window()
              .rectangle()
              .onChange(v => {})
              .onSubmit(v => {})
        """)
        #expect(!h.hasException)
    }

    @Test("Full launcher-style builder compiles and runs")
    func testLauncherShape() {
        let h = JSTestHarness()
        h.loadModuleRoot()
        _ = h.eval("""
            var query = hs.ui.string('')
            hs.ui.window()
              .borderless()
              .level('floating')
              .frame({w: 640, h: 480})
              .center()
              .canBecomeKey(true)
              .vstack()
                .padding(16)
                .textField(query)
                  .placeholder('Search apps, commands, math…')
                  .focused(true)
                  .onChange(v => {})
                  .onSubmit(v => {})
                  .onKey((k, m) => k === 'ArrowDown')
                .end()
              .end()
              .onBlur(() => {})
        """)
        #expect(!h.hasException)
    }
}
