//
//  HSHttpModule.swift
//  Hammerspoon 2
//
//  A general-purpose async HTTP client built on URLSession.
//
//  Design goals (CrossWin needs all three, but the module is general):
//   • a cancellable request HANDLE — long-polls must be torn down on window
//     close / reconfigure, which a bare Promise cannot express;
//   • stream UP from a file (`bodyFile`) and DOWN to a file (`saveTo`) so
//     multi-MB transfers never pass through a JS string;
//   • ergonomic Promise sugar (`hs.http.get/post/fetch`) layered on top in
//     the companion hs.http.js.
//
//  Concurrency: URLSession delivers completions on a background queue. We
//  extract only Sendable values inside the @Sendable completion, then hop to
//  the main actor (where JS lives) to invoke the callback — JSValue is never
//  captured across the isolation boundary.
//

import Foundation
import JavaScriptCore

// MARK: - JavaScript API

/// Module for making HTTP(S) requests.
@objc protocol HSHttpModuleAPI: JSExport {
    /// Start an HTTP request. Returns immediately with a cancellable handle; the
    /// result is delivered to `callback(err, res)`.
    /// - Parameter options: An object with: `url` (absolute URL, required); `method`
    ///   (default `'GET'`); `headers` (object); `timeout` (seconds, default 30); `body`
    ///   (string, for small payloads); `bodyFile` (path to stream the request body FROM —
    ///   large uploads; wins over `body`); `saveTo` (path to stream the response body TO —
    ///   large downloads; omits `res.body`); `directConnection` (bool — bypass any
    ///   system HTTP proxy, for talking to a loopback SSH tunnel).
    /// - Parameter callback: `(err, res)` — `err` is a string or null; `res` is
    ///   `{ status, headers, bytes, body?, path? }` or null on error.
    /// - Returns: a request handle with `.cancel()` and `.isRunning`.
    /// - Example:
    /// ```js
    /// const req = hs.http.request({ url: 'http://127.0.0.1:8473/clip?wait=25000', timeout: 30 },
    ///   (err, res) => { if (!err) console.log(res.status + ' ' + res.body) })
    /// // later: req.cancel()
    /// ```
    @objc(request::)
    func request(_ options: JSValue, _ callback: JSValue?) -> HSHttpClientRequest

    /// Promise sugar: `hs.http.fetch(options) -> Promise<res>`. Swift-retained storage for the JS implementation.
    /// - Example:
    /// ```js
    /// const res = await hs.http.fetch({ url: 'http://127.0.0.1:8473/healthz' })
    /// ```
    @objc var fetch: JSValue? { get set }

    /// Promise sugar: `hs.http.get(url, options?) -> Promise<res>`. Swift-retained storage for the JS implementation.
    /// - Example:
    /// ```js
    /// const res = await hs.http.get('http://127.0.0.1:8473/clip')
    /// ```
    @objc var get: JSValue? { get set }

    /// Promise sugar: `hs.http.post(url, body, options?) -> Promise<res>`. Swift-retained storage for the JS implementation.
    /// - Example:
    /// ```js
    /// await hs.http.post('http://127.0.0.1:8473/clip', JSON.stringify({ value: 'hi' }))
    /// ```
    @objc var post: JSValue? { get set }
}

// MARK: - Implementation

/// Sendable snapshot of a completed request, handed across the actor boundary.
private struct HTTPOutcome: Sendable {
    var errString: String?
    var status: Int = 0
    var headers: [String: String] = [:]
    var bytes: Int = 0
    var body: String?
    var path: String?
}

/// Per-request main-actor context, looked up by id when the outcome arrives.
@MainActor
private final class PendingRequest {
    let callback: JSValue?
    let handle: HSHttpClientRequest
    init(callback: JSValue?, handle: HSHttpClientRequest) {
        self.callback = callback
        self.handle = handle
    }
}

@_documentation(visibility: private)
@MainActor
@objc class HSHttpModule: NSObject, HSModuleAPI, HSHttpModuleAPI {
    var name = "hs.http"
    let engineID: UUID

    // Swift-retained storage for JS-defined Promise wrappers (see hs.http.js).
    @objc var fetch: JSValue? = nil
    @objc var get: JSValue? = nil
    @objc var post: JSValue? = nil

    private let session: URLSession        // honours the system proxy
    private let directSession: URLSession  // bypasses the system proxy (loopback tunnels)
    private var pending: [String: PendingRequest] = [:]

    // MARK: - Lifecycle
    required init(engineID: UUID) {
        self.engineID = engineID
        func makeConfig(direct: Bool) -> URLSessionConfiguration {
            let cfg = URLSessionConfiguration.ephemeral
            cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
            cfg.waitsForConnectivity = false
            // A loopback SSH tunnel must not be routed through a system HTTP
            // proxy (e.g. Surge/Proxyman), which would intercept 127.0.0.1. An
            // empty dictionary is treated as "use system config" on some macOS
            // versions, so disable each proxy type explicitly.
            if direct {
                cfg.connectionProxyDictionary = [
                    kCFNetworkProxiesHTTPEnable as String: 0,
                    kCFNetworkProxiesHTTPSEnable as String: 0,
                    kCFNetworkProxiesSOCKSEnable as String: 0,
                ]
            }
            return cfg
        }
        self.session = URLSession(configuration: makeConfig(direct: false))
        self.directSession = URLSession(configuration: makeConfig(direct: true))
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {
        for (_, p) in pending { p.handle.cancel() }
        pending.removeAll()
        session.invalidateAndCancel()
        directSession.invalidateAndCancel()
    }

    isolated deinit {
        AKTrace("Deinit of \(name): \(engineID)")
    }

    // MARK: - request

    @objc(request::)
    func request(_ options: JSValue, _ callback: JSValue?) -> HSHttpClientRequest {
        let handle = HSHttpClientRequest()

        guard let urlStr = string(options, "url"), !urlStr.isEmpty, let url = URL(string: urlStr) else {
            deliver(callback, handle, HTTPOutcome(errString: "hs.http.request: missing or invalid 'url'"))
            return handle
        }

        var req = URLRequest(url: url)
        req.httpMethod = (string(options, "method") ?? "GET").uppercased()
        if let t = options.objectForKeyedSubscript("timeout"), t.isNumber, t.toDouble() > 0 {
            req.timeoutInterval = t.toDouble()
        } else {
            req.timeoutInterval = 30
        }
        if let hv = options.objectForKeyedSubscript("headers"), hv.isObject,
           let dict = hv.toDictionary() {
            for (k, v) in dict {
                if let ks = k as? String { req.setValue("\(v)", forHTTPHeaderField: ks) }
            }
        }

        let bodyFile = string(options, "bodyFile")
        let saveTo = string(options, "saveTo")
        let id = handle.identifier
        let useSession = (options.objectForKeyedSubscript("directConnection")?.toBool() ?? false)
            ? directSession : session

        let task: URLSessionTask
        if let bodyFile {
            let src = URL(fileURLWithPath: (bodyFile as NSString).expandingTildeInPath)
            task = useSession.uploadTask(with: req, fromFile: src) { [weak self] data, resp, err in
                let outcome = Self.makeOutcome(data: data, resp: resp, err: err, downloadTmp: nil, saveTo: saveTo)
                Task { @MainActor in self?.finish(id: id, outcome: outcome) }
            }
        } else if let saveTo {
            task = useSession.downloadTask(with: req) { [weak self] tmp, resp, err in
                let outcome = Self.makeOutcome(data: nil, resp: resp, err: err, downloadTmp: tmp, saveTo: saveTo)
                Task { @MainActor in self?.finish(id: id, outcome: outcome) }
            }
        } else {
            if let body = string(options, "body") { req.httpBody = body.data(using: .utf8) }
            task = useSession.dataTask(with: req) { [weak self] data, resp, err in
                let outcome = Self.makeOutcome(data: data, resp: resp, err: err, downloadTmp: nil, saveTo: nil)
                Task { @MainActor in self?.finish(id: id, outcome: outcome) }
            }
        }

        handle.bind(task: task)
        pending[id] = PendingRequest(callback: callback, handle: handle)
        task.resume()
        return handle
    }

    // MARK: - completion (off-main → builds a Sendable outcome)

    /// Runs on URLSession's background queue. Touches only the closure-local
    /// params (never the module's main-actor state) and returns a Sendable value.
    nonisolated private static func makeOutcome(data: Data?, resp: URLResponse?, err: Error?,
                                                downloadTmp: URL?, saveTo: String?) -> HTTPOutcome {
        if let err = err as NSError? {
            let msg = err.code == NSURLErrorCancelled ? "cancelled" : err.localizedDescription
            return HTTPOutcome(errString: msg)
        }
        var out = HTTPOutcome()
        if let http = resp as? HTTPURLResponse {
            out.status = http.statusCode
            for (k, v) in http.allHeaderFields { out.headers["\(k)"] = "\(v)" }
        }
        let fm = FileManager.default
        // On an error status, never write the (error-body) response to the
        // caller's destination file — surface the status instead.
        let isError = out.status >= 400
        if let downloadTmp {
            if isError {
                try? fm.removeItem(at: downloadTmp)
                return out
            }
            guard let saveTo else { out.errString = "internal: download without saveTo"; return out }
            let dest = URL(fileURLWithPath: (saveTo as NSString).expandingTildeInPath)
            do {
                try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
                try fm.moveItem(at: downloadTmp, to: dest)
                out.bytes = (try? fm.attributesOfItem(atPath: dest.path)[.size] as? Int) ?? out.bytes
                out.path = dest.path
            } catch {
                out.errString = "saveTo failed: \(error.localizedDescription)"
            }
            return out
        }
        if let data {
            out.bytes = data.count
            if let saveTo, !isError {
                let dest = URL(fileURLWithPath: (saveTo as NSString).expandingTildeInPath)
                do {
                    try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: dest)
                    out.path = dest.path
                } catch {
                    out.errString = "saveTo failed: \(error.localizedDescription)"
                }
            } else {
                out.body = String(data: data, encoding: .utf8) ?? ""
            }
        } else {
            out.body = ""
        }
        return out
    }

    @MainActor
    private func finish(id: String, outcome: HTTPOutcome) {
        guard let p = pending.removeValue(forKey: id) else { return }
        p.handle.markFinished()
        deliver(p.callback, p.handle, outcome)
    }

    @MainActor
    private func deliver(_ callback: JSValue?, _ handle: HSHttpClientRequest, _ outcome: HTTPOutcome) {
        guard let callback, callback.isObject else { return }
        if let err = outcome.errString {
            callback.call(withArguments: [err, NSNull()])
            return
        }
        var res: [String: Any] = [
            "status": outcome.status,
            "headers": outcome.headers,
            "bytes": outcome.bytes,
        ]
        if let body = outcome.body { res["body"] = body }
        if let path = outcome.path { res["path"] = path }
        callback.call(withArguments: [NSNull(), res])
    }

    // MARK: - option parsing

    /// Returns the string value for `key`, or nil if absent/undefined/null.
    private func string(_ options: JSValue, _ key: String) -> String? {
        guard let v = options.objectForKeyedSubscript(key), !v.isUndefined, !v.isNull else { return nil }
        return v.toString()
    }
}
