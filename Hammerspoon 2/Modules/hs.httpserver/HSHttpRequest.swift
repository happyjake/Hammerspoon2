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

@objc protocol HSHttpRequestAPI: HSTypeAPI, JSExport {
    @objc var method: String { get }
    @objc var url: String { get }
    @objc var pathname: String { get }
    @objc var headers: HSHttpHeaders { get }
    @objc var remoteAddress: String { get }
    @objc var bodyUsed: Bool { get }

    /// Decode the request body as UTF-8 text.
    /// - Returns: {Promise<string>} A Promise resolving to the body text. Rejects
    ///   with TypeError if the body has already been read.
    @objc func text() -> JSPromise?

    /// Decode and JSON.parse the request body.
    /// - Returns: {Promise<any>} A Promise resolving to the parsed JSON value.
    @objc func json() -> JSPromise?

    /// URLSearchParams for the URL's query string — exposed via the JS-side
    /// polyfill (hs.httpserver.js). Returns the raw query string here; the JS
    /// shim wraps it.
    /// - Returns: query string (without leading '?'), or empty
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
