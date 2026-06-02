//
//  HSMultipeerTests.swift
//  Hammerspoon 2Tests
//
//  API-shape integration tests for hs.multipeer. Real peer discovery/transfer
//  needs two machines + AWDL/Wi-Fi + Local Network TCC, so these only assert the
//  JS bridge surface and that the no-peer paths don't throw. Creating the session
//  (MCSession/advertiser/browser) is safe headless; start() fails gracefully
//  (didNotStart) rather than throwing when there's no network.
//

import Testing
import JavaScriptCore
@testable import Hammerspoon_2

@Suite("hs.multipeer module API structure")
struct HSMultipeerModuleAPITests {

    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSMultipeerModule.self, as: "multipeer")
        return harness
    }

    @Test("hs.multipeer is an object")
    func moduleIsObject() {
        makeHarness().expectTrue("typeof hs.multipeer === 'object'")
    }

    @Test("session is a function")
    func sessionIsFunction() {
        makeHarness().expectTrue("typeof hs.multipeer.session === 'function'")
    }

    @Test("session() returns an HSMPCSession object")
    func sessionReturnsObject() {
        let h = makeHarness()
        h.eval("var s = hs.multipeer.session({ displayName: 'TestMac' })")
        h.expectTrue("typeof s === 'object'")
        h.expectEqual("s.typeName", "HSMPCSession")
        #expect(!h.hasException)
    }

    @Test("session exposes start/stop/reset/send/onPeer/onReceive + peers array")
    func sessionMethods() {
        let h = makeHarness()
        h.eval("var s = hs.multipeer.session({ displayName: 'TestMac' })")
        h.expectTrue("typeof s.start === 'function'")
        h.expectTrue("typeof s.stop === 'function'")
        h.expectTrue("typeof s.reset === 'function'")
        h.expectTrue("typeof s.send === 'function'")
        h.expectTrue("typeof s.onPeer === 'function'")
        h.expectTrue("typeof s.onReceive === 'function'")
        h.expectTrue("Array.isArray(s.peers)")
        #expect(!h.hasException)
    }

    @Test("peers is empty before any connection")
    func peersEmptyInitially() {
        let h = makeHarness()
        h.eval("var s = hs.multipeer.session({ displayName: 'TestMac' })")
        h.expectTrue("s.peers.length === 0")
        #expect(!h.hasException)
    }

    @Test("onPeer and onReceive return the session for chaining")
    func callbacksChain() {
        let h = makeHarness()
        h.expectTrue("(function(){ var s = hs.multipeer.session({displayName:'T'}); return s.onPeer(function(){}) === s && s.onReceive(function(){}) === s })()")
        #expect(!h.hasException)
    }

    @Test("send returns false when there are no peers")
    func sendFalseNoPeers() {
        let h = makeHarness()
        h.eval("var s = hs.multipeer.session({ displayName: 'TestMac' })")
        h.expectTrue("s.send('aGVsbG8=', { reliable: true }) === false")
        #expect(!h.hasException)
    }

    @Test("send returns false on invalid base64")
    func sendFalseBadBase64() {
        let h = makeHarness()
        h.eval("var s = hs.multipeer.session({ displayName: 'TestMac' })")
        h.expectTrue("s.send('not valid base64!!', {}) === false")
        #expect(!h.hasException)
    }

    @Test("start() then stop() does not throw")
    func startStopNoThrow() {
        let h = makeHarness()
        h.eval("var s = hs.multipeer.session({ displayName: 'TestMac' }); s.start(); s.stop();")
        #expect(!h.hasException)
    }

    @Test("reset() does not throw")
    func resetNoThrow() {
        let h = makeHarness()
        h.eval("var s = hs.multipeer.session({ displayName: 'TestMac' }); s.reset();")
        #expect(!h.hasException)
    }
}
