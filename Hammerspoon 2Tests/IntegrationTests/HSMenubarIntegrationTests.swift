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

    @Test("setSVG chains and tolerates input") @MainActor func testSetSVG() {
        let h = makeHarness()
        h.eval("globalThis.it = hs.menubar.new()")
        let svg = "<svg xmlns=\\\"http://www.w3.org/2000/svg\\\" width=\\\"18\\\" height=\\\"18\\\" viewBox=\\\"0 0 24 24\\\"><circle cx=\\\"12\\\" cy=\\\"12\\\" r=\\\"8\\\" fill=\\\"none\\\" stroke=\\\"#000\\\" stroke-width=\\\"2\\\"/></svg>"
        h.expectTrue("typeof it.setSVG === 'function'")
        h.expectTrue("it.setSVG('\(svg)', {}) === it")
        h.expectTrue("it.setSVG('not-svg', {}) === it") // malformed → no throw
        h.eval("it.remove()")
    }

    // The whole eye-ring-progress feature hinges on NSImage parsing SVG. Verify
    // that directly so a macOS without SVG support fails loudly here, not silently
    // as a blank menu-bar item.
    @Test("NSImage parses an SVG document") @MainActor func testNSImageParsesSVG() {
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"18\" height=\"18\" viewBox=\"0 0 24 24\"><circle cx=\"12\" cy=\"12\" r=\"8\" fill=\"none\" stroke=\"#000\" stroke-width=\"2\"/><circle cx=\"12\" cy=\"12\" r=\"3\" fill=\"#000\"/></svg>"
        let data = svg.data(using: .utf8)!
        let image = NSImage(data: data)
        #expect(image != nil)
        #expect((image?.size.width ?? 0) > 0)
    }

    // setSVG renders the icon as a TEMPLATE so macOS picks the color. A raw SVG
    // NSImage ignores isTemplate (→ black); rasterizing to a bitmap template
    // fixes it. Verify the helper yields a real, tintable template bitmap.
    @Test("SVG rasterizes to a tintable template bitmap") @MainActor func testTemplateBitmap() {
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"18\" height=\"18\" viewBox=\"0 0 24 24\"><circle cx=\"12\" cy=\"12\" r=\"8\" fill=\"none\" stroke=\"#000\" stroke-width=\"2\"/></svg>"
        let svgImage = NSImage(data: svg.data(using: .utf8)!)!
        let bmp = HSMenubarItem.templateBitmap(from: svgImage, size: 18)
        #expect(bmp.isTemplate == true)            // → system tints it (adaptive)
        #expect(bmp.size.width == 18)
        #expect(bmp.representations.isEmpty == false) // actually rasterized content
    }
}
