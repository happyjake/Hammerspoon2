//
//  HSWebviewIntegrationTests.swift
//  Hammerspoon 2Tests
//
//  JS API surface tests for hs.webview. We don't drive the actual WKWebView
//  in unit tests (no UI loop), so the checks here are: function existence,
//  builder chains return the same object, level/style/handler accept input
//  without throwing, and the module shuts down cleanly.
//

import Testing
import JavaScriptCore
import AppKit
@testable import Hammerspoon_2

@Suite("hs.webview API structure tests")
struct HSWebviewStructureTests {
    @MainActor
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSWebviewModule.self, as: "webview")
        return harness
    }

    @Test("new is a function") @MainActor func testNewIsFunction() {
        makeHarness().expectTrue("typeof hs.webview.new === 'function'")
    }

    @Test("new() returns an object with builder methods") @MainActor func testNewReturnsBuilder() {
        let h = makeHarness()
        h.eval("const wv = hs.webview.new({x:0,y:0,w:400,h:300})")
        h.expectTrue("typeof wv.url === 'function'")
        h.expectTrue("typeof wv.html === 'function'")
        h.expectTrue("typeof wv.reload === 'function'")
        h.expectTrue("typeof wv.show === 'function'")
        h.expectTrue("typeof wv.hide === 'function'")
        h.expectTrue("typeof wv.close === 'function'")
        h.expectTrue("typeof wv.level === 'function'")
        h.expectTrue("typeof wv.windowStyle === 'function'")
        h.expectTrue("typeof wv.canBecomeKey === 'function'")
        h.expectTrue("typeof wv.nonActivating === 'function'")
        h.expectTrue("typeof wv.center === 'function'")
        h.expectTrue("typeof wv.windowCornerRadius === 'function'")
        h.expectTrue("typeof wv.developerExtras === 'function'")
        h.expectTrue("typeof wv.setMessageHandler === 'function'")
        h.expectTrue("typeof wv.injectUserScript === 'function'")
        h.expectTrue("typeof wv.evaluateJavaScript === 'function'")
        h.expectTrue("typeof wv.windowCallback === 'function'")
        h.expectTrue("typeof wv.currentFrame === 'function'")
        h.expectTrue("typeof wv.bringToFront === 'function'")
    }

    @Test("new() without a rect returns null") @MainActor func testNewWithoutRect() {
        let h = makeHarness()
        // Loose-equality null check tolerates undefined vs null bridging.
        h.expectTrue("hs.webview.new('not-an-object') == null")
    }

    @Test("builder methods chain (return same object)") @MainActor func testBuilderChain() {
        let h = makeHarness()
        h.eval("const wv = hs.webview.new({x:0,y:0,w:400,h:300})")
        h.expectTrue("wv.url('about:blank') === wv")
        h.expectTrue("wv.level('floating') === wv")
        h.expectTrue("wv.windowStyle({titled:false, closable:false}) === wv")
        h.expectTrue("wv.canBecomeKey(true) === wv")
        h.expectTrue("wv.nonActivating(true) === wv")
        h.expectTrue("wv.nonActivating(false) === wv")
        h.expectTrue("wv.center() === wv")
        h.expectTrue("wv.windowCornerRadius(12) === wv")
        h.expectTrue("wv.developerExtras(false) === wv")
        h.expectTrue("wv.injectUserScript('window.__x = 1') === wv")
        h.expectTrue("wv.setMessageHandler('vc', (m) => {}) === wv")
        h.expectTrue("wv.windowCallback((e) => {}) === wv")
    }

    @Test("setMessageHandler accepts null to unregister") @MainActor func testUnregisterHandler() {
        let h = makeHarness()
        h.eval("const wv = hs.webview.new({x:0,y:0,w:400,h:300})")
        h.eval("wv.setMessageHandler('vc', (m) => {})")
        h.expectTrue("wv.setMessageHandler('vc', null) === wv")
    }

    @Test("level accepts named values without throwing") @MainActor func testLevelNames() {
        let h = makeHarness()
        h.eval("const wv = hs.webview.new({x:0,y:0,w:400,h:300})")
        for level in ["normal", "floating", "modal", "popup", "screensaver", "mainmenu", "status", "garbage"] {
            h.expectTrue("wv.level('\(level)') === wv")
        }
    }

    @Test("windowStyle accepts partial dictionaries") @MainActor func testPartialStyle() {
        let h = makeHarness()
        h.eval("const wv = hs.webview.new({x:0,y:0,w:400,h:300})")
        h.expectTrue("wv.windowStyle({}) === wv")
        h.expectTrue("wv.windowStyle({titled:true}) === wv")
        h.expectTrue("wv.windowStyle({transparent:true, closable:false}) === wv")
    }

    @Test("currentFrame is null before show()") @MainActor func testCurrentFrameNullBeforeShow() {
        let h = makeHarness()
        h.eval("const wv = hs.webview.new({x:0,y:0,w:400,h:300})")
        h.expectTrue("wv.currentFrame() == null")
    }

    @Test("evaluateJavaScript before show() warns but does not crash") @MainActor func testEvalBeforeShow() {
        let h = makeHarness()
        h.eval("const wv = hs.webview.new({x:0,y:0,w:400,h:300})")
        // Just verify it does not throw a JS exception.
        h.eval("wv.evaluateJavaScript('1+1', null)")
        #expect(h.lastException == nil, "evaluateJavaScript before show should not throw, got: \(h.exceptionMessage ?? "nil")")
    }

    @Test("html() chains and accepts null baseURL") @MainActor func testHtmlChain() {
        let h = makeHarness()
        h.eval("const wv = hs.webview.new({x:0,y:0,w:400,h:300})")
        h.expectTrue("wv.html('<h1>hi</h1>', null) === wv")
        h.expectTrue("wv.html('<h1>hi</h1>', 'about:blank') === wv")
    }
}

// MARK: - Lifecycle smoke tests (driving the real NSWindow + WKWebView)

@Suite("hs.webview lifecycle")
struct HSWebviewLifecycleTests {
    @MainActor
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSWebviewModule.self, as: "webview")
        return harness
    }

    @Test("nonActivating show() then close() does not crash") @MainActor func testNonActivatingShowClose() {
        // Focus behavior (the frontmost app keeping key status) can't be verified
        // in the test runner; this drives the NSPanel host through its lifecycle.
        let h = makeHarness()
        h.eval("""
            const wv = hs.webview.new({x:200, y:200, w:380, h:240})
                .windowStyle({titled:false, closable:false, transparent:true})
                .nonActivating(true)
                .canBecomeKey(false)
                .level('status')
                .html('<!doctype html><html><body>toast</body></html>', null)
                .show()
        """)
        #expect(!h.hasException)
        h.expectTrue("wv.currentFrame() != null")
        h.expectTrue("wv.currentFrame().w === 380")
        h.eval("wv.close()")
        #expect(!h.hasException)
        h.expectTrue("wv.currentFrame() == null")
    }

    @Test("nonActivating hover forwarding does not recurse") @MainActor func testHoverForwardingNoRecursion() {
        // Regression: the hover-forwarding wrapper used to re-dispatch
        // mouseEntered into the WKWebView, which doesn't implement it —
        // NSResponder forwarded it back to the wrapper, recursing to a stack
        // overflow the moment a real pointer entered the panel.
        let h = makeHarness()
        h.eval("""
            const wv = hs.webview.new({x:220, y:220, w:390, h:250})
                .windowStyle({titled:false, closable:false, transparent:true})
                .nonActivating(true)
                .canBecomeKey(false)
                .html('<!doctype html><html><body>hover</body></html>', null)
                .show()
        """)
        let panel = NSApp.windows.first { $0.styleMask.contains(.nonactivatingPanel) && $0.frame.width == 390 }
        #expect(panel != nil, "non-activating panel should be on screen")
        if let panel, let content = panel.contentView {
            let loc = NSPoint(x: 50, y: 50)
            if let entered = NSEvent.enterExitEvent(
                with: .mouseEntered, location: loc, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil,
                eventNumber: 0, trackingNumber: 0, userData: nil) {
                content.mouseEntered(with: entered)
            }
            if let moved = NSEvent.mouseEvent(
                with: .mouseMoved, location: loc, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil,
                eventNumber: 0, clickCount: 0, pressure: 0) {
                content.mouseMoved(with: moved)
            }
            if let exited = NSEvent.enterExitEvent(
                with: .mouseExited, location: loc, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil,
                eventNumber: 0, trackingNumber: 0, userData: nil) {
                content.mouseExited(with: exited)
            }
        }
        h.eval("wv.close()")
        #expect(!h.hasException)
    }

    @Test("show() then close() does not crash") @MainActor func testShowClose() {
        let h = makeHarness()
        h.eval("""
            const wv = hs.webview.new({x:200, y:200, w:400, h:300})
                .windowStyle({titled:false, closable:false, transparent:true})
                .level('floating')
                .html('<!doctype html><html><body style="background:#222;color:#0f0">hi</body></html>', null)
                .show()
        """)
        // Frame is reported now.
        h.expectTrue("wv.currentFrame() != null")
        h.expectTrue("wv.currentFrame().w === 400")
        h.expectTrue("wv.currentFrame().h === 300")
        h.eval("wv.close()")
        // After close, currentFrame should be null again.
        h.expectTrue("wv.currentFrame() == null")
    }
}
