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

    @Test("write() sends bytes to the device")
    func writeReachesDevice() throws {
        var master: Int32 = 0, slave: Int32 = 0
        #expect(openpty(&master, &slave, nil, nil, nil) == 0)
        defer { Darwin.close(master); Darwin.close(slave) }
        let slavePath = String(cString: ttyname(slave))
        let harness = JSTestHarness()
        harness.loadModule(HSSerialModule.self, as: "serial")
        harness.expectTrue("serial.open('\(slavePath)').write('ping\\n') === true")

        // Read what the module wrote, from the master side (short poll for the tty layer).
        var got = ""
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline && !got.contains("ping") {
            var buf = [UInt8](repeating: 0, count: 64)
            let n = read(master, &buf, buf.count)
            if n > 0 { got += String(decoding: buf[0..<n], as: UTF8.self) }
            else { usleep(10_000) }
        }
        #expect(got.contains("ping\n"))
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
