import XCTest
import Foundation
import Network
import JavaScriptCore
import Darwin
import Synchronization
@testable import Hammerspoon_2

// Raw TCP keeps connection reuse, pipelining and EOF visible to the tests.
@MainActor
private final class HTTPTestClient {
    private let connection: NWConnection
    private var buffered = Data()
    private var ended = false

    init(port: UInt16) {
        connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
    }

    func connect() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { [connection] state in
                switch state {
                case .ready:
                    connection.stateUpdateHandler = nil
                    continuation.resume()
                case .failed(let error):
                    connection.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                case .cancelled:
                    connection.stateUpdateHandler = nil
                    continuation.resume(throwing: CancellationError())
                default: break
                }
            }
            connection.start(queue: .main)
        }
    }

    func close() { connection.cancel() }

    func send(_ bytes: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: bytes, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            })
        }
    }

    func send(_ text: String) async throws { try await send(Data(text.utf8)) }

    private func receive() async throws {
        guard !ended else { throw Failure.unexpectedEOF }
        let result: (Data?, Bool) = try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, complete, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: (data, complete)) }
            }
        }
        if let data = result.0 { buffered.append(data) }
        ended = result.1
    }

    func response() async throws -> String {
        let separator = Data("\r\n\r\n".utf8)
        while buffered.range(of: separator) == nil { try await receive() }
        let range = buffered.range(of: separator)!
        let headers = String(decoding: buffered[..<range.lowerBound], as: UTF8.self)
        guard headers.hasPrefix("HTTP/1.1 200 "),
              let lengthLine = headers.components(separatedBy: "\r\n").first(where: {
                  $0.lowercased().hasPrefix("content-length:")
              }), let length = Int(lengthLine.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces))
        else { throw Failure.invalidResponse }
        let headerBytes = buffered.distance(from: buffered.startIndex, to: range.upperBound)
        while buffered.count < headerBytes + length { try await receive() }
        let body = String(decoding: buffered.dropFirst(headerBytes).prefix(length), as: UTF8.self)
        buffered = Data(buffered.dropFirst(headerBytes + length))
        return body
    }

    func expectGracefulEOF() async throws {
        while !ended { try await receive() }
        XCTAssertTrue(buffered.isEmpty, "Unexpected bytes after the last response")
    }

    private enum Failure: Error { case unexpectedEOF, invalidResponse }
}

nonisolated final class HSHttpServerIntegrationTests: XCTestCase {
    @MainActor
    private func makeServer(timeout: Double = 60, handler: String = "req => new Response(req.pathname)") async throws
        -> (JSTestHarness, HSHttpServer, UInt16) {
        let harness = JSTestHarness()
        harness.loadModule(HSHttpServerModule.self, as: "httpserver")
        harness.loadModule(HSTimerModule.self, as: "timer")
        let fetch = try XCTUnwrap(harness.evalValue("(\(handler))"))
        XCTAssertFalse(harness.hasException)
        // Native port zero gives each test a distinct kernel-selected port.
        let server = try HSHttpServer(hostname: "127.0.0.1", port: 0,
                                      maxBodyBytes: 32 * 1024 * 1024, idleTimeout: timeout, fetch: fetch)
        harness.context.setObject(server, forKeyedSubscript: "server" as NSString)
        for _ in 0..<200 {
            if let port = server.listeningPortForTesting { return (harness, server, port) }
            try await Task.sleep(for: .milliseconds(10))
        }
        server.stop()
        throw TestFailure.listenerNotReady
    }

    @MainActor
    private func assertRemoved(_ server: HSHttpServer) async throws {
        for _ in 0..<200 {
            if server.connectionCountForTesting == 0 { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(server.connectionCountForTesting, 0)
    }

    // The watchdog bounds failures without blocking the main actor or spinning.
    @MainActor
    private func withClient(port: UInt16, _ body: (HTTPTestClient) async throws -> Void) async throws {
        let client = HTTPTestClient(port: port)
        let watchdog = Task { @MainActor in
            try await Task.sleep(for: .seconds(10))
            client.close()
        }
        defer { watchdog.cancel(); client.close() }
        try await client.connect()
        try await body(client)
    }

    @MainActor
    func testReuseThenGracefulIdleExpiryAndRemoval() async throws {
        let (harness, server, port) = try await makeServer(timeout: 0.5)
        defer { server.stop(); withExtendedLifetime(harness) {} }
        try await withClient(port: port) { client in
            try await client.send("GET /first HTTP/1.1\r\n\r\n")
            let first = try await client.response()
            XCTAssertEqual(first, "/first")
            try await Task.sleep(for: .milliseconds(50))
            try await client.send("GET /second HTTP/1.1\r\n\r\n")
            let second = try await client.response()
            XCTAssertEqual(second, "/second")
            XCTAssertEqual(server.connectionCountForTesting, 1)
            let start = ContinuousClock.now
            try await client.expectGracefulEOF()
            XCTAssertGreaterThanOrEqual(start.duration(to: .now), .milliseconds(300))
        }
        try await assertRemoved(server)
    }

    @MainActor
    func testStopDuringPendingGracefulCloseCancelsTransport() async throws {
        let (harness, server, port) = try await makeServer(timeout: 0.1)
        let cancelled = XCTestExpectation(description: "Transport cancelled after server shutdown")
        let observedTransport = Mutex<NWConnection?>(nil)
        defer {
            observedTransport.withLock { $0?.cancel(); $0 = nil }
            server.stop()
            withExtendedLifetime(harness) {}
        }
        server.observeGracefulCloseForTesting { [weak server] transport in
            // Retain the transport, not its wrapper, so cancellation is observed
            // independently of the server releasing its connection collection.
            observedTransport.withLock { $0 = transport }
            let previousHandler = transport.stateUpdateHandler
            transport.stateUpdateHandler = { state in
                previousHandler?(state)
                if case .cancelled = state { cancelled.fulfill() }
            }
            // The idle timer has entered closing on the listener queue. Enqueue
            // stop before submitting FIN, so it precedes the send completion.
            server?.stop()
        }
        try await withClient(port: port) { client in
            try await client.send("GET / HTTP/1.1\r\n\r\n")
            let body = try await client.response()
            XCTAssertEqual(body, "/")
            // Keep the peer's sending direction open; EOF alone would only
            // prove that FIN was sent, not that the transport was cancelled.
            let result = await XCTWaiter.fulfillment(of: [cancelled], timeout: 3)
            XCTAssertEqual(result, .completed)
            XCTAssertEqual(server.connectionCountForTesting, 0)
        }
    }

    @MainActor
    func testSlowHandlerAndPipelinedResponsesStayOrdered() async throws {
        let (harness, server, port) = try await makeServer(timeout: 0.1, handler: """
            req => req.pathname === '/slow'
                ? new Promise(resolve => hs.timer.doAfter(0.4, () => resolve(new Response('slow'))))
                : new Response('fast')
            """)
        defer { server.stop(); withExtendedLifetime(harness) {} }
        try await withClient(port: port) { client in
            try await client.send("GET /warmup HTTP/1.1\r\n\r\n")
            let warmup = try await client.response()
            XCTAssertEqual(warmup, "fast")
            try await client.send("GET /slow HTTP/1.1\r\n\r\nGET /fast HTTP/1.1\r\n\r\n")
            let slow = try await client.response()
            let fast = try await client.response()
            XCTAssertEqual(slow, "slow")
            XCTAssertEqual(fast, "fast")
            try await client.expectGracefulEOF()
        }
        try await assertRemoved(server)
    }

    @MainActor
    func testFragmentedRequestDoesNotExpireWhileReading() async throws {
        let (harness, server, port) = try await makeServer(timeout: 0.2,
            handler: "async req => new Response(await req.text())")
        defer { server.stop(); withExtendedLifetime(harness) {} }
        try await withClient(port: port) { client in
            try await client.send("GET / HTTP/1.1\r\n\r\n")
            _ = try await client.response()
            try await client.send("POST /fragmented HTTP/1.1\r\nContent-Length: 3\r\n\r\na")
            try await Task.sleep(for: .milliseconds(500))
            XCTAssertEqual(server.connectionCountForTesting, 1)
            try await client.send("bc")
            let body = try await client.response()
            XCTAssertEqual(body, "abc")
            try await client.expectGracefulEOF()
        }
    }

    @MainActor
    func testLargeResponseIsFullyWrittenBeforeIdleClose() async throws {
        let (harness, server, port) = try await makeServer(timeout: 0.1,
            handler: "req => new Response(req.pathname === '/large' ? 'x'.repeat(8388608) : 'ok')")
        defer { server.stop(); withExtendedLifetime(harness) {} }
        try await withClient(port: port) { client in
            try await client.send("GET / HTTP/1.1\r\n\r\n")
            _ = try await client.response()
            try await client.send("GET /large HTTP/1.1\r\n\r\n")
            // Leave the socket unread beyond the timeout to apply backpressure.
            try await Task.sleep(for: .milliseconds(400))
            let body = try await client.response()
            XCTAssertEqual(body.utf8.count, 8 * 1024 * 1024)
            XCTAssertTrue(body.allSatisfy { $0 == "x" })
            try await client.expectGracefulEOF()
        }
    }

    @MainActor
    func testExtendingTimeoutCancelsThePreviousDeadline() async throws {
        let (harness, server, port) = try await makeServer(timeout: 0.2)
        defer { server.stop() }
        try await withClient(port: port) { client in
            try await client.send("GET /before HTTP/1.1\r\n\r\n")
            _ = try await client.response()
            harness.eval("server.idleTimeout = 1")
            XCTAssertFalse(harness.hasException)
            try await Task.sleep(for: .milliseconds(400))
            try await client.send("GET /after HTTP/1.1\r\n\r\n")
            let body = try await client.response()
            XCTAssertEqual(body, "/after")
            harness.eval("server.idleTimeout = 0.1")
            try await client.expectGracefulEOF()
        }
    }

    @MainActor
    func testTimeoutSetterUpdatesIdleConnectionsAndRejectsInvalidValues() async throws {
        let (harness, server, port) = try await makeServer()
        defer { server.stop() }
        XCTAssertEqual(harness.evalValue("server.idleTimeout")?.toDouble(), 60)
        harness.eval("""
            var rejected = [0, -1, NaN, Infinity].every(value => {
                try { server.idleTimeout = value; return false; }
                catch (_) { return server.idleTimeout === 60; }
            });
            """)
        XCTAssertEqual(harness.evalValue("rejected")?.toBool(), true)
        XCTAssertFalse(harness.hasException)
        try await withClient(port: port) { client in
            try await client.send("GET / HTTP/1.1\r\n\r\n")
            _ = try await client.response()
            try await Task.sleep(for: .milliseconds(300))
            harness.eval("server.idleTimeout = 0.1")
            XCTAssertFalse(harness.hasException)
            try await client.expectGracefulEOF()
        }
        try await assertRemoved(server)
    }

    @MainActor
    func testServeTimeoutOptionValidation() {
        let harness = JSTestHarness()
        harness.loadModule(HSHttpServerModule.self, as: "httpserver")
        let result = harness.evalValue("""
            [0, -1, NaN, Infinity, '2', false].every(idleTimeout => {
                try {
                    const s = hs.httpserver.serve({port: 19880, idleTimeout, fetch: () => new Response('ok')});
                    if (s) s.stop();
                    return false;
                } catch (_) { return true; }
            })
            """)
        XCTAssertEqual(result?.toBool(), true)
        XCTAssertFalse(harness.hasException)
        harness.eval("""
            var configured = hs.httpserver.serve({port: 19880, idleTimeout: 0.25, fetch: () => new Response('ok')});
            var configuredTimeout = configured.idleTimeout;
            configured.stop();
            """)
        XCTAssertEqual(harness.evalValue("configuredTimeout")?.toDouble(), 0.25)
        XCTAssertFalse(harness.hasException)
    }

    @MainActor
    func testTenLargeKeepAliveRequestsReleaseStorageBeforeTimeout() async throws {
        let (harness, server, port) = try await makeServer(handler: "() => new Response('ok')")
        var clients: [HTTPTestClient] = []
        let watchdog = Task { @MainActor in
            try await Task.sleep(for: .seconds(30))
            server.stop()
        }
        defer {
            watchdog.cancel()
            for client in clients { client.close() }
            server.stop()
        }
        // Warm JSC and Network.framework before measuring the retained overhead.
        for _ in 0..<10 {
            let client = HTTPTestClient(port: port)
            clients.append(client)
            try await client.connect()
            try await client.send("GET / HTTP/1.1\r\n\r\n")
            _ = try await client.response()
        }
        unsafe HSTestSynchronousGC(harness.context.jsGlobalContextRef)
        let baseline = allocatedBytes()
        for client in clients {
            // Keep the upload allocation out of the final measurement.
            try await uploadLargeBody(client)
            let body = try await client.response()
            XCTAssertEqual(body, "ok")
        }
        unsafe HSTestSynchronousGC(harness.context.jsGlobalContextRef)
        XCTAssertEqual(server.connectionCountForTesting, 10)
        XCTAssertLessThan(allocatedBytes() - baseline, 16 * 1024 * 1024)
        for client in clients {
            try await client.send("GET /small HTTP/1.1\r\n\r\n")
            let body = try await client.response()
            XCTAssertEqual(body, "ok")
        }
    }

    @MainActor
    private func uploadLargeBody(_ client: HTTPTestClient) async throws {
        try await client.send("POST /large HTTP/1.1\r\nContent-Length: 8388608\r\n\r\n")
        try await client.send(Data(repeating: 120, count: 8 * 1024 * 1024))
    }

    private func allocatedBytes() -> Int {
        var stats = malloc_statistics_t()
        unsafe malloc_zone_statistics(nil, &stats)
        return Int(stats.size_in_use)
    }

    private enum TestFailure: Error { case listenerNotReady }
}
