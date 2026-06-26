//
//  HSHttpIntegrationTests.swift
//  Hammerspoon 2Tests
//
//  Integration tests for the hs.http client. They drive a real in-process
//  hs.httpserver over loopback (127.0.0.1), which also exercises the ATS
//  NSAllowsLocalNetworking exception the CrossWin tunnel relies on.
//

import Testing
import JavaScriptCore
@testable import Hammerspoon_2

@Suite(.serialized) struct HSHttpIntegrationTests {

    init() async {
        await JSTestHarness.drainMainActorQueue()
    }

    private func harness() -> JSTestHarness {
        let h = JSTestHarness()
        h.loadModule(HSHttpModule.self, as: "http")
        h.loadModule(HSHttpServerModule.self, as: "httpserver")
        h.loadModule(HSTimerModule.self, as: "timer")
        return h
    }

    // MARK: - shape / synchronous error

    @Test("request() returns a cancellable handle and rejects an empty URL synchronously")
    func testHandleShapeAndBadURL() {
        let h = harness()
        h.eval("""
        globalThis.__err = null;
        const r = hs.http.request({ url: '' }, (err, res) => { globalThis.__err = err; });
        globalThis.__hasCancel = (typeof r.cancel === 'function');
        globalThis.__isRunningBool = (typeof r.isRunning === 'boolean');
        globalThis.__hasId = (typeof r.identifier === 'string' && r.identifier.length > 0);
        """)
        h.expectTrue("globalThis.__hasCancel")
        h.expectTrue("globalThis.__isRunningBool")
        h.expectTrue("globalThis.__hasId")
        h.expectTrue("typeof globalThis.__err === 'string' && globalThis.__err.length > 0")
    }

    // MARK: - GET round-trip

    @Test("hs.http.get round-trips status, body and a response header")
    func testGetRoundTrip() async {
        let h = harness()
        h.eval("""
        globalThis.__done = false;
        const s = hs.httpserver.serve({ port: 19871, fetch: (req) =>
          new Response('pong', { status: 200, headers: { 'X-Echo': 'abc' } }) });
        hs.http.get('http://127.0.0.1:19871/ping').then(res => {
          globalThis.__status = res.status;
          globalThis.__body = res.body;
          globalThis.__bytes = res.bytes;
          globalThis.__hdr = res.headers['X-Echo'] || res.headers['x-echo'] || '';
          s.stop(); globalThis.__done = true;
        }).catch(e => { globalThis.__error = String(e); s.stop(); globalThis.__done = true; });
        """)
        let ok = await h.waitForAsync(timeout: 5) { h.evalValue("globalThis.__done")?.toBool() == true }
        #expect(ok, "GET did not complete in time (err: \(h.eval("globalThis.__error") ?? "nil"))")
        h.expectEqual("globalThis.__status", 200)
        h.expectEqual("globalThis.__body", "pong")
        h.expectEqual("globalThis.__hdr", "abc")
        h.expectEqual("globalThis.__bytes", 4)
    }

    // MARK: - POST body upload + echo

    @Test("hs.http.post sends the request body")
    func testPostBodyEcho() async {
        let h = harness()
        h.eval("""
        globalThis.__done = false;
        const s = hs.httpserver.serve({ port: 19872, fetch: async (req) => {
          const t = await req.text();
          return new Response('echo:' + t, { status: 200 });
        }});
        hs.http.post('http://127.0.0.1:19872/x', 'hello-body').then(res => {
          globalThis.__body = res.body; s.stop(); globalThis.__done = true;
        }).catch(e => { globalThis.__error = String(e); s.stop(); globalThis.__done = true; });
        """)
        let ok = await h.waitForAsync(timeout: 5) { h.evalValue("globalThis.__done")?.toBool() == true }
        #expect(ok, "POST did not complete (err: \(h.eval("globalThis.__error") ?? "nil"))")
        h.expectEqual("globalThis.__body", "echo:hello-body")
    }

    // MARK: - saveTo streams the response to a file

    @Test("saveTo writes the response to disk and omits the in-memory body")
    func testSaveToFile() async {
        let h = harness()
        let dest = (NSTemporaryDirectory() as NSString).appendingPathComponent("cwin-http-\(UUID().uuidString).bin")
        h.eval("globalThis.__dest = '\(dest)';")
        h.eval("""
        globalThis.__done = false;
        const s = hs.httpserver.serve({ port: 19873, fetch: () =>
          new Response('FILE-CONTENTS-123', { status: 200 }) });
        hs.http.request({ url: 'http://127.0.0.1:19873/f', saveTo: globalThis.__dest }, (err, res) => {
          globalThis.__err = err; globalThis.__path = res ? res.path : null;
          globalThis.__hasBody = res ? (typeof res.body !== 'undefined') : true;
          s.stop(); globalThis.__done = true;
        });
        """)
        let ok = await h.waitForAsync(timeout: 5) { h.evalValue("globalThis.__done")?.toBool() == true }
        #expect(ok, "download did not complete (err: \(h.eval("globalThis.__err") ?? "nil"))")
        h.expectTrue("typeof globalThis.__path === 'string' && globalThis.__path.length > 0")
        h.expectFalse("globalThis.__hasBody")   // body omitted when streamed to disk
        let contents = (try? String(contentsOfFile: dest, encoding: .utf8)) ?? ""
        #expect(contents == "FILE-CONTENTS-123", "file contents were '\(contents)'")
        try? FileManager.default.removeItem(atPath: dest)
    }

    // MARK: - non-2xx resolves (does not reject)

    @Test("a non-2xx status resolves with the status, not a rejection")
    func testNon2xxResolves() async {
        let h = harness()
        h.eval("""
        globalThis.__done = false; globalThis.__rejected = false;
        const s = hs.httpserver.serve({ port: 19874, fetch: () =>
          new Response('nope', { status: 404 }) });
        hs.http.get('http://127.0.0.1:19874/missing').then(res => {
          globalThis.__status = res.status; globalThis.__body = res.body;
          s.stop(); globalThis.__done = true;
        }).catch(e => { globalThis.__rejected = true; s.stop(); globalThis.__done = true; });
        """)
        let ok = await h.waitForAsync(timeout: 5) { h.evalValue("globalThis.__done")?.toBool() == true }
        #expect(ok)
        h.expectFalse("globalThis.__rejected")
        h.expectEqual("globalThis.__status", 404)
        h.expectEqual("globalThis.__body", "nope")
    }

    // MARK: - cancel a long-poll

    @Test("cancel() aborts an in-flight request with err 'cancelled'")
    func testCancel() async {
        let h = harness()
        h.eval("""
        globalThis.__done = false;
        const s = hs.httpserver.serve({ port: 19875, fetch: () => new Promise(() => {}) }); // never resolves
        const r = hs.http.request({ url: 'http://127.0.0.1:19875/hang', timeout: 30 }, (err, res) => {
          globalThis.__cancelErr = err; s.stop(); globalThis.__done = true;
        });
        hs.timer.doAfter(0.2, () => r.cancel());
        """)
        let ok = await h.waitForAsync(timeout: 5) { h.evalValue("globalThis.__done")?.toBool() == true }
        #expect(ok, "cancel did not deliver in time")
        h.expectEqual("globalThis.__cancelErr", "cancelled")
    }
}
