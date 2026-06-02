//
//  HSBLETests.swift
//  Hammerspoon 2Tests
//
//  API-shape integration tests for hs.ble. The actual relay (attach to a bonded
//  ESP32, subscribe/notify/write) needs hardware + Bluetooth TCC, so these only
//  assert the JS bridge surface and that the no-hardware paths don't throw.
//  CoreBluetooth reports .unsupported/.unauthorized in a headless test host, so
//  central()/connect() return their objects without scanning.
//

import Testing
import JavaScriptCore
@testable import Hammerspoon_2

@Suite("hs.ble module API structure")
struct HSBLEModuleAPITests {

    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSBLEModule.self, as: "ble")
        return harness
    }

    @Test("hs.ble is an object")
    func moduleIsObject() {
        makeHarness().expectTrue("typeof hs.ble === 'object'")
    }

    @Test("central is a function")
    func centralIsFunction() {
        makeHarness().expectTrue("typeof hs.ble.central === 'function'")
    }

    @Test("central() returns an HSBLECentral object")
    func centralReturnsObject() {
        let h = makeHarness()
        h.expectTrue("typeof hs.ble.central() === 'object'")
        h.expectEqual("hs.ble.central().typeName", "HSBLECentral")
        #expect(!h.hasException)
    }

    @Test("central exposes onState and connect functions")
    func centralMethods() {
        let h = makeHarness()
        h.eval("var c = hs.ble.central()")
        h.expectTrue("typeof c.onState === 'function'")
        h.expectTrue("typeof c.connect === 'function'")
        #expect(!h.hasException)
    }

    @Test("onState returns the central for chaining")
    func onStateChains() {
        let h = makeHarness()
        h.expectTrue("(function(){ var c = hs.ble.central(); return c.onState(function(){}) === c })()")
        #expect(!h.hasException)
    }
}

@Suite("hs.ble peripheral API structure")
struct HSBLEPeripheralAPITests {

    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSBLEModule.self, as: "ble")
        return harness
    }

    @Test("connect() returns an HSBLEPeripheral object")
    func connectReturnsPeripheral() {
        let h = makeHarness()
        h.eval("var p = hs.ble.central().connect({ name: 'VoiceKB' })")
        h.expectTrue("typeof p === 'object'")
        h.expectEqual("p.typeName", "HSBLEPeripheral")
        #expect(!h.hasException)
    }

    @Test("peripheral exposes the documented methods + uuid")
    func peripheralMethods() {
        let h = makeHarness()
        h.eval("var p = hs.ble.central().connect({})")
        h.expectTrue("typeof p.onConnect === 'function'")
        h.expectTrue("typeof p.onDisconnect === 'function'")
        h.expectTrue("typeof p.onNotify === 'function'")
        h.expectTrue("typeof p.write === 'function'")
        h.expectTrue("typeof p.disconnect === 'function'")
        h.expectTrue("typeof p.uuid === 'string'")
        #expect(!h.hasException)
    }

    @Test("onNotify returns the peripheral for chaining")
    func onNotifyChains() {
        let h = makeHarness()
        h.expectTrue("(function(){ var p = hs.ble.central().connect({}); return p.onNotify(function(){}) === p })()")
        #expect(!h.hasException)
    }

    @Test("write() returns false when not connected")
    func writeFalseWhenDisconnected() {
        let h = makeHarness()
        h.eval("var p = hs.ble.central().connect({})")
        h.expectTrue("p.write('{\"clip\":\"hi\"}') === false")
        #expect(!h.hasException)
    }

    @Test("uuid is an empty string before connecting")
    func uuidEmptyInitially() {
        let h = makeHarness()
        h.eval("var p = hs.ble.central().connect({})")
        h.expectTrue("p.uuid === ''")
        #expect(!h.hasException)
    }
}
