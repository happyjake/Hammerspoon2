//
//  HSSerialTests.swift
//  Hammerspoon 2Tests
//

import Testing
import JavaScriptCore
@testable import Hammerspoon_2

/// Integration tests for hs.serial module
struct HSSerialTests {

    @Test("list() returns an array")
    func testListReturnsArray() {
        let harness = JSTestHarness()
        harness.loadModule(HSSerialModule.self, as: "serial")
        harness.expectTrue("Array.isArray(hs.serial.list())")
        harness.expectTrue("hs.serial.list().every(p => typeof p.path === 'string' && typeof p.name === 'string')")
    }
}
