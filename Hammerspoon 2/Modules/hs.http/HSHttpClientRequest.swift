//
//  HSHttpClientRequest.swift
//  Hammerspoon 2
//
//  A handle for an in-flight hs.http request. Returned synchronously from
//  `hs.http.request(...)` so the caller can `.cancel()` it — essential for
//  tearing down long-polls when a window closes or the connection reconfigures.
//
//  (Named "ClientRequest" to avoid colliding with hs.httpserver's HSHttpRequest,
//  which models an INCOMING server request.)
//

import Foundation
import JavaScriptCore

/// A handle to an in-flight HTTP request.
@objc protocol HSHttpClientRequestAPI: HSTypeAPI, JSExport {
    /// Cancel the request. The callback (if any) fires with err `'cancelled'`.
    /// - Example:
    /// ```js
    /// const req = hs.http.request({ url }, cb)
    /// req.cancel()
    /// ```
    @objc func cancel()

    /// Whether the request is still running.
    /// - Example:
    /// ```js
    /// if (req.isRunning) req.cancel()
    /// ```
    @objc var isRunning: Bool { get }

    /// A unique identifier for this request.
    /// - Example:
    /// ```js
    /// console.log(req.identifier)
    /// ```
    @objc var identifier: String { get }
}

@_documentation(visibility: private)
@MainActor
@objc class HSHttpClientRequest: NSObject, HSHttpClientRequestAPI {
    @objc var typeName = "HSHttpClientRequest"
    @objc let identifier = UUID().uuidString

    private weak var task: URLSessionTask?
    private var finished = false

    func bind(task: URLSessionTask) { self.task = task }
    func markFinished() { finished = true }

    @objc var isRunning: Bool {
        guard !finished, let state = task?.state else { return false }
        return state == .running || state == .suspended
    }

    @objc func cancel() {
        task?.cancel()
    }
}
