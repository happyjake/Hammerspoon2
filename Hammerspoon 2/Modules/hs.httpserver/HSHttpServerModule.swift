//
//  HSHttpServerModule.swift
//  Hammerspoon 2
//
//  `hs.httpserver` namespace. Single entry point: `serve({...})`. Tracks live
//  servers so users don't need to hold their own references.
//

import Foundation
import JavaScriptCore

@objc protocol HSHttpServerModuleAPI: JSExport {
    /// Start an HTTP server.
    /// - Parameter opts: `{ port, hostname?, maxBodyBytes?, fetch }`
    ///   - `port`: TCP port to bind (required, 1..65535)
    ///   - `hostname`: bind address (default `'127.0.0.1'`; use `'0.0.0.0'` for LAN)
    ///   - `maxBodyBytes`: request body cap, over → 413 (default 32 MiB)
    ///   - `fetch`: handler `(request) => Response | Promise<Response>` (required)
    /// - Returns: a server handle with `.hostname`, `.port`, `.url`, `.stop()`
    /// - Example:
    /// ```js
    /// const server = hs.httpserver.serve({
    ///   port: 9876,
    ///   fetch: async (req) => new Response('hi', { status: 200 })
    /// })
    /// ```
    @objc func serve(_ opts: JSValue) -> HSHttpServer?
}

@_documentation(visibility: private)
@MainActor
@objc class HSHttpServerModule: NSObject, HSModuleAPI, HSHttpServerModuleAPI {
    var name = "hs.httpserver"
    let engineID: UUID

    private var servers: Set<HSHttpServer> = []

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {
        for s in servers { s.stop() }
        servers.removeAll()
    }

    isolated deinit {
        AKTrace("Deinit of hs.httpserver: \(engineID)")
    }

    @objc func serve(_ opts: JSValue) -> HSHttpServer? {
        guard opts.isObject else {
            JSContext.current()?.exception = JSValue(newErrorFromMessage:
                "hs.httpserver.serve: options object required", in: opts.context)
            return nil
        }

        // port (required)
        let portVal = opts.objectForKeyedSubscript("port")
        guard let portVal, !portVal.isUndefined, !portVal.isNull else {
            JSContext.current()?.exception = JSValue(newErrorFromMessage:
                "hs.httpserver.serve: 'port' is required", in: opts.context)
            return nil
        }
        let port = Int(portVal.toInt32())
        guard port >= 1, port <= 65535 else {
            JSContext.current()?.exception = JSValue(newErrorFromMessage:
                "hs.httpserver.serve: 'port' must be 1..65535", in: opts.context)
            return nil
        }

        // hostname (optional)
        let hostname: String = {
            let h = opts.objectForKeyedSubscript("hostname")
            if let h, !h.isUndefined, !h.isNull, h.isString, let s = h.toString(), !s.isEmpty {
                return s
            }
            return "127.0.0.1"
        }()

        // maxBodyBytes (optional)
        let maxBodyBytes: Int = {
            let m = opts.objectForKeyedSubscript("maxBodyBytes")
            if let m, !m.isUndefined, !m.isNull {
                let n = Int(m.toInt32())
                if n > 0 { return n }
            }
            return 32 * 1024 * 1024
        }()

        // fetch (required, callable)
        let fetchVal = opts.objectForKeyedSubscript("fetch")
        guard let fetchVal, fetchVal.isObject else {
            JSContext.current()?.exception = JSValue(newErrorFromMessage:
                "hs.httpserver.serve: 'fetch' callback required", in: opts.context)
            return nil
        }

        do {
            let server = try HSHttpServer(hostname: hostname, port: port, maxBodyBytes: maxBodyBytes, fetch: fetchVal)
            server.module = self
            servers.insert(server)
            AKTrace("hs.httpserver: serving on \(hostname):\(port)")
            return server
        } catch {
            JSContext.current()?.exception = JSValue(newErrorFromMessage:
                "hs.httpserver.serve: bind failed: \(error.localizedDescription)", in: opts.context)
            return nil
        }
    }

    func unregister(_ server: HSHttpServer) {
        servers.remove(server)
    }
}
