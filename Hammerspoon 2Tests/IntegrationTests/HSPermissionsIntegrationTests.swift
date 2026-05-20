//
//  HSPermissionsIntegrationTests.swift
//  Hammerspoon 2Tests
//

import Testing
@testable import Hammerspoon_2

struct HSPermissionsIntegrationTests {
    @Test("checkInputMonitoring returns a boolean")
    func testCheckInputMonitoringReturnsBoolean() {
        let h = JSTestHarness()
        h.loadModule(HSPermissionsModule.self, as: "permissions")
        let result = h.eval("typeof hs.permissions.checkInputMonitoring()")
        #expect(result as? String == "boolean")
    }

    @Test("requestInputMonitoring is callable without throwing")
    func testRequestInputMonitoringIsCallable() {
        let h = JSTestHarness()
        h.loadModule(HSPermissionsModule.self, as: "permissions")
        _ = h.eval("hs.permissions.requestInputMonitoring()")
        #expect(h.hasException == false)
    }
}
