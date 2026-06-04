//
//  HSHttpServer.swift
//  Hammerspoon 2
//
//  One bound port. Owns an NWListener, accepts connections, dispatches each
//  parsed request to the user's JS `fetch` handler via callSafely (which logs
//  any thrown JS exception with stack), and writes the returned Response.
//
//  Threading: this class is `nonisolated final class @unchecked Sendable`
//  because Network.framework callbacks fire on `listenerQueue` (a private
//  serial queue), not @MainActor. All mutable connection state is touched
//  only from `listenerQueue`, so the @unchecked Sendable claim holds. The
//  JS-side @objc properties are `let` Sendable types; the JS-side methods
//  hop to main internally where needed.
//

import Foundation
import Network
import JavaScriptCore

/// A bound HTTP server listening on a configured hostname/port. Returned
/// by `hs.httpserver.serve(...)`. Lifecycle: `start` happens implicitly on
/// creation; call `stop()` to shut it down. Each accepted connection
/// dispatches to the user-supplied `fetch` handler.
@objc protocol HSHttpServerAPI: HSTypeAPI, JSExport {
    /// Hostname the server is bound to (e.g. `"127.0.0.1"` or `"0.0.0.0"`).
    @objc var hostname: String { get }

    /// TCP port the server is listening on.
    @objc var port: Int { get }

    /// Base URL of the server (e.g. `"http://127.0.0.1:9876/"`).
    @objc var url: String { get }

    /// Stop the server. Idempotent.
    /// - Example:
    /// ```js
    /// server.stop()
    /// ```
    @objc func stop()
}

@_documentation(visibility: private)
nonisolated final class HSHttpServer: NSObject, HSHttpServerAPI, @unchecked Sendable {
    @objc let typeName = "HSHttpServer"
    @objc let hostname: String
    @objc let port: Int
    @objc var url: String { "http://\(hostname):\(port)/" }

    private let listener: NWListener
    private let listenerQueue: DispatchQueue
    private var connectionsByID: [ObjectIdentifier: HSHttpConnection] = [:]    // touched only on listenerQueue
    private let fetchCallback: JSValue
    private let maxBodyBytes: Int
    weak var module: HSHttpServerModule?
    private var stopped = false                                                 // touched only on listenerQueue

    init(hostname: String, port: Int, maxBodyBytes: Int, fetch: JSValue) throws {
        self.hostname = hostname
        self.port = port
        self.maxBodyBytes = maxBodyBytes
        self.fetchCallback = fetch
        self.listenerQueue = DispatchQueue(label: "net.tenshu.Hammerspoon-2.httpserver", qos: .userInitiated)

        let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) ?? NWEndpoint.Port.any
        let params = NWParameters.tcp
        if hostname != "0.0.0.0" {
            params.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(hostname),
                port: nwPort
            )
        }
        let listener = try NWListener(using: params, on: nwPort)
        self.listener = listener
        super.init()

        listener.stateUpdateHandler = { [weak self] state in
            if case .failed(let err) = state {
                let msg = "hs.httpserver: listener failed: \(err)"
                Task { @MainActor in
                    AKError(msg)
                    self?.stop()
                }
            }
        }
        listener.newConnectionHandler = { [weak self] conn in
            guard let self else { conn.cancel(); return }
            self.acceptConnection(conn)
        }
        listener.start(queue: listenerQueue)
    }

    @objc func stop() {
        listenerQueue.async { [weak self] in
            guard let self else { return }
            if self.stopped { return }
            self.stopped = true
            self.listener.cancel()
            for (_, c) in self.connectionsByID { c.close() }
            self.connectionsByID.removeAll()

            let weakModule = self.module
            let weakSelf = self
            DispatchQueue.main.async {
                weakModule?.unregister(weakSelf)
            }
        }
    }

    // MARK: - Connection management (called on listenerQueue)

    private func acceptConnection(_ conn: NWConnection) {
        let connection = HSHttpConnection(connection: conn, server: self, queue: listenerQueue, maxBodyBytes: maxBodyBytes)
        let id = ObjectIdentifier(connection)
        connectionsByID[id] = connection
        connection.start()
    }

    func connectionDidClose(_ connection: HSHttpConnection) {
        let id = ObjectIdentifier(connection)
        connectionsByID.removeValue(forKey: id)
    }

    // MARK: - Request dispatch
    //
    // Called from listenerQueue. Hops to main for the JS fetch invocation,
    // then back to listenerQueue (via the completion closure) for the write.

    func dispatch(parsed: HSHttpParsedRequest, remoteAddress: String, completion: @escaping @Sendable (Data) -> Void) {
        let urlString = buildURL(target: parsed.target)
        let (pathname, search) = splitTargetPath(parsed.target)
        let serverQueue = listenerQueue
        let fetchCb = self.fetchCallback
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                let headers = HSHttpHeaders()
                for h in parsed.headers { headers.append(h.name, h.value) }

                let request = HSHttpRequest(
                    method: parsed.method.uppercased(),
                    url: urlString,
                    pathname: pathname,
                    search: search,
                    headers: headers,
                    remoteAddress: remoteAddress,
                    body: parsed.body
                )

                let result = fetchCb.callSafely(withArguments: [request], context: "hs.httpserver fetch")
                guard let result, !result.isUndefined, !result.isNull else {
                    let bytes = HSHttpConnection.serialize(HSHttpServer.makeErrorResponse(500, message: "fetch returned no Response"))
                    serverQueue.async { completion(bytes) }
                    return
                }

                if HSHttpServer.isPromise(result) {
                    let onFulfilled: @convention(block) (JSValue?) -> Any? = { val in
                        MainActor.assumeIsolated {
                            let bytes = HSHttpServer.bytesForReturnedResponse(val)
                            serverQueue.async { completion(bytes) }
                        }
                        return nil
                    }
                    let onRejected: @convention(block) (JSValue?) -> Any? = { err in
                        let msg = MainActor.assumeIsolated { err?.toString() ?? "fetch rejected" }
                        Task { @MainActor in AKError("hs.httpserver: fetch promise rejected: \(msg)") }
                        let bytes = MainActor.assumeIsolated {
                            HSHttpConnection.serialize(HSHttpServer.makeErrorResponse(500, message: "fetch rejected"))
                        }
                        serverQueue.async { completion(bytes) }
                        return nil
                    }
                    let ctx = result.context!
                    result.invokeMethod("then", withArguments: [
                        JSValue(object: onFulfilled, in: ctx) as Any,
                        JSValue(object: onRejected, in: ctx) as Any,
                    ])
                } else {
                    let bytes = HSHttpServer.bytesForReturnedResponse(result)
                    serverQueue.async { completion(bytes) }
                }
            }
        }
    }

    @MainActor
    static func bytesForReturnedResponse(_ value: JSValue?) -> Data {
        guard let value, !value.isUndefined, !value.isNull else {
            return HSHttpConnection.serialize(makeErrorResponse(500, message: "fetch returned no Response"))
        }
        if let response = value.toObjectOf(HSHttpResponse.self) as? HSHttpResponse {
            return HSHttpConnection.serialize(response)
        }
        AKError("hs.httpserver: fetch returned non-Response (\(value.toString() ?? "?"))")
        return HSHttpConnection.serialize(makeErrorResponse(500, message: "fetch returned non-Response"))
    }

    @MainActor
    static func makeErrorResponse(_ status: Int, message: String) -> HSHttpResponse {
        let h = HSHttpHeaders()
        h.set("content-type", "text/plain;charset=UTF-8")
        return HSHttpResponse.swiftMake(status: status, headers: h, body: message.data(using: .utf8) ?? Data())
    }

    private func buildURL(target: String) -> String {
        if target.hasPrefix("/") {
            return "http://\(hostname == "0.0.0.0" ? "127.0.0.1" : hostname):\(port)\(target)"
        }
        return "http://\(hostname):\(port)/\(target)"
    }

    private func splitTargetPath(_ target: String) -> (pathname: String, search: String) {
        if let q = target.firstIndex(of: "?") {
            return (String(target[..<q]), String(target[target.index(after: q)...]))
        }
        return (target, "")
    }

    @MainActor
    static func isPromise(_ value: JSValue) -> Bool {
        guard value.isObject else { return false }
        let then = value.objectForKeyedSubscript("then")
        return then?.isObject == true
    }
}
