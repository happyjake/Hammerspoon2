//
//  HSSerialTests.swift
//  Hammerspoon 2Tests
//

import Testing
import JavaScriptCore
import Darwin
@testable import Hammerspoon_2

/// Integration tests for hs.serial module
struct HSSerialTests {

    @Test("list() returns an array")
    func testListReturnsArray() {
        let harness = JSTestHarness()
        harness.loadModule(HSSerialModule.self, as: "serial")
        harness.expectTrue("Array.isArray(hs.serial.list())")
        harness.expectTrue("hs.serial.list().every(p => typeof p.path === 'string' && typeof p.name === 'string')")
        // Prove it returns a real array regardless of device presence (not vacuously true)
        harness.expectTrue("typeof hs.serial.list().length === 'number'")
    }

    @Test("open() with bad path returns null, openFirst() with no match returns null")
    func testOpenBadPathReturnsNull() {
        let harness = JSTestHarness()
        harness.loadModule(HSSerialModule.self, as: "serial")
        // JSCore bridges Swift nil as undefined; use == null (loose) which covers both null and undefined
        harness.expectTrue("hs.serial.open('/dev/cu.this-does-not-exist') == null")
        harness.expectTrue("hs.serial.openFirst('definitely-no-such-device') == null")
    }

    @Test("open() on a pty slave returns a live port, close() marks it closed")
    func testOpenPtyPortThenClose() {
        var m: Int32 = -1
        var s: Int32 = -1
        let rc = openpty(&m, &s, nil, nil, nil)
        guard rc == 0 else {
            Issue.record("openpty failed: \(rc)")
            return
        }
        defer {
            Darwin.close(m)
            Darwin.close(s)
        }

        let slavePath = String(cString: ttyname(s))

        let harness = JSTestHarness()
        harness.loadModule(HSSerialModule.self, as: "serial")

        // Store the port in a JS global so we can query it multiple times
        harness.eval("var port = hs.serial.open('\(slavePath)')")

        harness.expectTrue("port != null")
        harness.expectTrue("port.isOpen === true")
        harness.expectTrue("port.path === '\(slavePath)'")

        harness.eval("port.close()")
        harness.expectTrue("port.isOpen === false")
    }
}
