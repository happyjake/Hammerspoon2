//
//  HSSwitcherTests.swift
//  Hammerspoon 2Tests
//

import Testing
import Foundation
@testable import Hammerspoon_2

struct HSSwitcherTests {
    @Test("enable returns exactly one of {disable function} | {error string}")
    func testEnableShape() async {
        await MainActor.run {
            let h = JSTestHarness()
            h.loadModule(HSSwitcherModule.self, as: "switcher")
            let raw = h.eval("""
                const r = hs.switcher.enable({})
                JSON.stringify({
                  hasDisable: typeof r.disable === 'function',
                  hasError: typeof r.error === 'string',
                })
            """)
            let s = raw as? String
            let data = s.flatMap { $0.data(using: .utf8) }
            let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            let hasDisable = (json?["hasDisable"] as? Bool) ?? false
            let hasError = (json?["hasError"] as? Bool) ?? false
            // Must be exactly one, never both, never neither.
            #expect(hasDisable != hasError, "Expected exactly one of disable/error in: \(s ?? "nil")")
        }
    }

    @Test("disable() does not throw")
    func testDisable() async {
        await MainActor.run {
            let h = JSTestHarness()
            h.loadModule(HSSwitcherModule.self, as: "switcher")
            _ = h.eval("""
                const r = hs.switcher.enable({})
                if (typeof r.disable === 'function') r.disable()
            """)
            #expect(h.lastException == nil)
        }
    }

    @Test("invalid config still returns a structured response object")
    func testRobustToBadConfig() async {
        await MainActor.run {
            let h = JSTestHarness()
            h.loadModule(HSSwitcherModule.self, as: "switcher")
            let result = h.eval("""
                const r = hs.switcher.enable("not an object")
                typeof r === 'object' && r !== null
            """)
            #expect(result as? Bool == true)
        }
    }
}
