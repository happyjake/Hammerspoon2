//
//  HSSwitcherHandoffTests.swift
//  Hammerspoon 2Tests
//
//  Created by Claude on 11/06/2026.
//

import Testing
import Foundation
import JavaScriptCore
@testable import Hammerspoon_2

/// Tab-while-filtering hands the typed query off to the launcher via the
/// `onHandoff` callback. These exercise the config parsing and the session's
/// emit path directly — no eventtap, so no Accessibility permission needed
/// (the switcher's key tap can't be installed in the test runner anyway).
@Suite("HSSwitcher Tab handoff")
@MainActor
struct HSSwitcherHandoffTests {

    /// Builds an HSSwitcherConfig from a JS object whose `onHandoff` records
    /// the query it receives into `globalThis.__capturedQuery`.
    private func makeRecordingConfig(_ ctx: JSContext) -> HSSwitcherConfig {
        ctx.evaluateScript("""
            globalThis.__capturedQuery = null;
            globalThis.__handoffCalls = 0;
            var cfg = { onHandoff: function(p) { globalThis.__handoffCalls++; globalThis.__capturedQuery = p && p.query; } };
        """)
        return HSSwitcherConfig(jsValue: ctx.objectForKeyedSubscript("cfg"))
    }

    @Test("config parses onHandoff when provided")
    func testConfigParsesOnHandoff() {
        let ctx = JSContext()!
        let config = makeRecordingConfig(ctx)
        #expect(config.onHandoff != nil)
    }

    @Test("config onHandoff is nil when absent")
    func testConfigOnHandoffNilWhenAbsent() {
        let ctx = JSContext()!
        let cfg = ctx.evaluateScript("({ commitDelayMs: 100 })")!
        let config = HSSwitcherConfig(jsValue: cfg)
        #expect(config.onHandoff == nil)
    }

    @Test("emitHandoff fires onHandoff with the current filter text")
    func testEmitHandoffCarriesFilterText() {
        let ctx = JSContext()!
        let config = makeRecordingConfig(ctx)

        var closed = false
        let session = HSSwitcherSession(config: config) { closed = true }
        session.state.mode = .filter
        session.state.filterText = "safari"

        session.emitHandoff()

        let calls = ctx.evaluateScript("globalThis.__handoffCalls")?.toInt32() ?? 0
        let captured = ctx.evaluateScript("globalThis.__capturedQuery")?.toString()
        #expect(calls == 1)
        #expect(captured == "safari")
        #expect(closed, "emitHandoff must run onClose so the binding clears its active session")
    }

    @Test("emitHandoff fires at most once")
    func testEmitHandoffIdempotent() {
        let ctx = JSContext()!
        let config = makeRecordingConfig(ctx)
        let session = HSSwitcherSession(config: config) { }
        session.state.filterText = "x"

        session.emitHandoff()
        session.emitHandoff()   // second call must be a no-op (already closed)

        let calls = ctx.evaluateScript("globalThis.__handoffCalls")?.toInt32() ?? 0
        #expect(calls == 1)
    }
}
