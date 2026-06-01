//
//  HSMenubarIntegrationTests.swift
//  Hammerspoon 2Tests
//
//  JS API surface tests for hs.menubar. We don't assert on the live menu bar
//  (the status item's hosting window may be unrealized under the test host),
//  so the checks here are: function existence, builder chains return the same
//  object, setters/callback accept input without throwing, frame() has the
//  right shape, and remove() is clean.
//

import Testing
import JavaScriptCore
import AppKit
@testable import Hammerspoon_2

@Suite("hs.menubar API structure tests")
struct HSMenubarStructureTests {
    @MainActor
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSMenubarModule.self, as: "menubar")
        return harness
    }

    @Test("new is a function") @MainActor func testNewIsFunction() {
        makeHarness().expectTrue("typeof hs.menubar.new === 'function'")
    }

    @Test("new() returns an item with builder methods") @MainActor func testNewReturnsItem() {
        let h = makeHarness()
        h.eval("globalThis.it = hs.menubar.new()")
        h.expectTrue("typeof it.setTitle === 'function'")
        h.expectTrue("typeof it.setIcon === 'function'")
        h.expectTrue("typeof it.setImage === 'function'")
        h.expectTrue("typeof it.setCallback === 'function'")
        h.expectTrue("typeof it.highlight === 'function'")
        h.expectTrue("typeof it.frame === 'function'")
        h.expectTrue("typeof it.remove === 'function'")
        h.eval("it.remove()")
    }

    @Test("builder methods chain (return same object)") @MainActor func testBuilderChain() {
        let h = makeHarness()
        h.eval("globalThis.it = hs.menubar.new()")
        h.expectTrue("it.setIcon('eye', {}) === it")
        h.expectTrue("it.setTitle('47:12', {monospaced:true, color:'#5BE08B'}) === it")
        h.expectTrue("it.highlight(true) === it")
        h.expectTrue("it.setCallback(function(){}) === it")
        h.eval("it.remove()")
    }

    @Test("setters accept input (incl. missing opts) without throwing") @MainActor func testSettersNoThrow() {
        let h = makeHarness()
        h.eval("globalThis.it = hs.menubar.new()")
        // Calling setIcon with an undefined opts arg must be tolerated.
        h.expectTrue("(function(){ try { it.setIcon('eye.slash', undefined); it.setTitle('', {}); it.setImage('not-base64', {}); return true } catch (e) { return false } })()")
        h.eval("it.remove()")
    }

    @Test("frame() returns null or an {x,y,w,h} object") @MainActor func testFrameShape() {
        let h = makeHarness()
        h.eval("globalThis.it = hs.menubar.new()")
        // Under the test host the hosting window may be unrealized → null is OK.
        h.expectTrue("(function(){ const f = it.frame(); return f === null || (typeof f === 'object' && 'x' in f && 'y' in f && 'w' in f && 'h' in f) })()")
        h.eval("it.remove()")
    }
}
