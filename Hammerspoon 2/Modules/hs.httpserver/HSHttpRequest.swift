//
//  HSHttpRequest.swift
//  Hammerspoon 2
//
//  Fetch-spec `Request` shape. Constructor is not exposed to JS — the server
//  builds one and passes it into the user's `fetch` handler. Body methods
//  `text()` / `json()` return Promises (resolved synchronously since the body
//  is already buffered when the handler runs).
//

import Foundation
import JavaScriptCore

/// One incoming HTTP request as observed by `hs.httpserver`. Models the
/// WHATWG Fetch `Request` shape: `method`, `url`, `pathname`, `headers`,
/// and a body-as-string/json accessor. Passed to the user's `fetch`
/// handler to produce a Response.
@objc protocol HSHttpRequestAPI: HSTypeAPI, JSExport {
    /// HTTP method, upper-cased (e.g. `"GET"`, `"POST"`).
    @objc var method: String { get }

    /// Absolute URL of the request (e.g. `"http://127.0.0.1:9876/path?q=1"`).
    @objc var url: String { get }

    /// Path component of the URL, without query string (e.g. `"/path"`).
    @objc var pathname: String { get }

    /// Request headers.
    @objc var headers: HSHttpHeaders { get }

    /// Remote IP address of the client (e.g. `"127.0.0.1"`).
    @objc var remoteAddress: String { get }

    /// True if the body has already been consumed by `text()` or `json()`.
    @objc var bodyUsed: Bool { get }

    /// Decode the request body as UTF-8 text.
    /// - Returns: {Promise<string>} A Promise resolving to the body text. Rejects
    ///   with TypeError if the body has already been read.
    @objc func text() -> JSPromise?

    /// Decode and JSON.parse the request body.
    /// - Returns: {Promise<any>} A Promise resolving to the parsed JSON value.
    @objc func json() -> JSPromise?

    /// Raw query string from the URL (without leading `?`), or empty string.
    /// The JS-side shim in `hs.httpserver.js` wraps this as `URLSearchParams`.
    @objc var search: String { get }
}

@_documentation(visibility: private)
@MainActor
@objc class HSHttpRequest: NSObject, HSHttpRequestAPI {
    @objc var typeName = "HSHttpRequest"
    @objc let method: String
    @objc let url: String
    @objc let pathname: String
    @objc let headers: HSHttpHeaders
    @objc let remoteAddress: String
    @objc let search: String
    @objc private(set) var bodyUsed: Bool = false
    private let bodyBytes: Data

    init(method: String, url: String, pathname: String, search: String,
         headers: HSHttpHeaders, remoteAddress: String, body: Data) {
        self.method = method
        self.url = url
        self.pathname = pathname
        self.search = search
        self.headers = headers
        self.remoteAddress = remoteAddress
        self.bodyBytes = body
        super.init()
    }

    @objc func text() -> JSPromise? {
        guard let ctx = JSContext.current() else { return nil }
        if bodyUsed {
            return ctx.createRejectedPromise(with: "TypeError: body already used")
        }
        bodyUsed = true
        let s = String(data: bodyBytes, encoding: .utf8) ?? ""
        return ctx.createResolvedPromise(with: s)
    }

    @objc func json() -> JSPromise? {
        guard let ctx = JSContext.current() else { return nil }
        if bodyUsed {
            return ctx.createRejectedPromise(with: "TypeError: body already used")
        }
        bodyUsed = true
        let s = String(data: bodyBytes, encoding: .utf8) ?? ""
        // Use JSON.parse from the calling context so we get a real JS object.
        guard let parsed = ctx.evaluateScript("JSON.parse(\(jsonStringLiteral(s)))"),
              !parsed.isUndefined else {
            return ctx.createRejectedPromise(with: "SyntaxError: invalid JSON")
        }
        if ctx.exception != nil {
            let msg = ctx.exception?.toString() ?? "invalid JSON"
            ctx.exception = nil
            return ctx.createRejectedPromise(with: msg)
        }
        return ctx.createResolvedPromise(with: parsed)
    }

    // Encode an arbitrary Swift String as a JS string literal we can embed in
    // `JSON.parse(<this>)`. Escapes the JSON-string special chars only — the
    // contents are themselves JSON, so we only need to make a valid *outer*
    // JS string containing it.
    private func jsonStringLiteral(_ s: String) -> String {
        var out = "\""
        for ch in s.unicodeScalars {
            switch ch {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{0008}": out += "\\b"
            case "\u{000C}": out += "\\f"
            default:
                if ch.value < 0x20 {
                    out += String(format: "\\u%04x", ch.value)
                } else {
                    out += String(ch)
                }
            }
        }
        out += "\""
        return out
    }
}
