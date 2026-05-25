//
//  HSHttpResponse.swift
//  Hammerspoon 2
//
//  Fetch-spec `Response` class. v1 body type: string only (binary deferred —
//  base64-encode and set Content-Type if you need bytes). Static `Response.json`
//  and `Response.redirect` helpers per Fetch.
//
//  Design note: JSC's class-export model has trouble binding a JS constructor
//  when the Obj-C init takes JSValue arguments (the `HSColor` precedent uses
//  static factories like `.rgb()` / `.hex()` and exposes no @objc init).
//  We follow the same pattern: expose static factories from Swift, and
//  recreate the Fetch `new Response(...)` ergonomics in JS via a wrapper
//  function in `hs.httpserver.js` that delegates to `HSHttpResponse.make`.
//

import Foundation
import JavaScriptCore

/// One outgoing HTTP response. Models the WHATWG Fetch `Response` shape:
/// `status`, `statusText`, `headers`, and a body-as-bytes accessor.
/// Returned by the user's `fetch` handler.
@objc protocol HSHttpResponseAPI: HSTypeAPI, JSExport {
    /// HTTP status code (e.g. 200, 404).
    @objc var status: Int { get }

    /// HTTP status text. Defaults from `status` per RFC 7231 if not provided.
    @objc var statusText: String { get }

    /// Response headers.
    @objc var headers: HSHttpHeaders { get }

    // -- statics (JSExport sees @objc class func as JS static class methods) --

    /// Factory equivalent to `new Response(body, init)`. The JS wrapper in
    /// `hs.httpserver.js` delegates here so users can write the canonical
    /// `new Response('hi', { status: 200 })` form.
    @objc(make::) static func make(_ body: JSValue, _ init_: JSValue) -> HSHttpResponse

    /// JSON convenience: `Response.json({ok: true})` → JSON-stringified body
    /// with `Content-Type: application/json`.
    @objc(json::) static func json(_ value: JSValue, _ init_: JSValue?) -> HSHttpResponse

    /// Redirect: sets `Location` header and a 3xx status (default 302).
    @objc(redirect::) static func redirect(_ url: String, _ status: NSNumber?) -> HSHttpResponse
}

@_documentation(visibility: private)
@MainActor
@objc class HSHttpResponse: NSObject, HSHttpResponseAPI {
    @objc let typeName = "HSHttpResponse"
    @objc private(set) var status: Int = 200
    @objc private(set) var statusText: String = "OK"
    @objc private(set) var headers: HSHttpHeaders = HSHttpHeaders()
    private(set) var bodyBytes: Data = Data()

    // RFC 7231 reason phrases for the codes we're likely to produce.
    static let defaultStatusText: [Int: String] = [
        100: "Continue", 200: "OK", 201: "Created", 204: "No Content",
        301: "Moved Permanently", 302: "Found", 303: "See Other", 304: "Not Modified",
        307: "Temporary Redirect", 308: "Permanent Redirect",
        400: "Bad Request", 401: "Unauthorized", 403: "Forbidden", 404: "Not Found",
        405: "Method Not Allowed", 413: "Payload Too Large", 415: "Unsupported Media Type",
        429: "Too Many Requests", 431: "Request Header Fields Too Large",
        500: "Internal Server Error", 501: "Not Implemented", 502: "Bad Gateway",
        503: "Service Unavailable",
    ]

    override init() { super.init() }

    // Swift-side factory used by HSHttpServer error-response builders.
    static func swiftMake(status: Int = 200,
                          statusText: String? = nil,
                          headers: HSHttpHeaders? = nil,
                          body: Data = Data()) -> HSHttpResponse {
        let r = HSHttpResponse()
        r.status = status
        r.statusText = statusText ?? HSHttpResponse.defaultStatusText[status] ?? ""
        if let headers { r.headers = headers }
        r.bodyBytes = body
        return r
    }

    private static func copyHeaders(from src: JSValue, into target: HSHttpHeaders) {
        if let other = src.toObjectOf(HSHttpHeaders.self) as? HSHttpHeaders {
            for name in other.orderedNames {
                for v in other.storage[name] ?? [] { target.append(name, v) }
            }
            return
        }
        if src.isObject {
            let names = (src.context?.objectForKeyedSubscript("Object")?
                .invokeMethod("keys", withArguments: [src])?
                .toArray() as? [String]) ?? []
            for name in names {
                if let value = src.objectForKeyedSubscript(name)?.toString() {
                    target.append(name, value)
                }
            }
        }
    }

    // --- JS-callable statics ---

    @objc(make::) static func make(_ body: JSValue, _ initOpts: JSValue) -> HSHttpResponse {
        let r = HSHttpResponse()

        if initOpts.isObject {
            if let st = initOpts.objectForKeyedSubscript("status"), !st.isUndefined, !st.isNull {
                r.status = Int(st.toInt32())
            }
            if let stxtVal = initOpts.objectForKeyedSubscript("statusText"),
               !stxtVal.isUndefined, !stxtVal.isNull {
                r.statusText = stxtVal.toString() ?? ""
            } else {
                r.statusText = HSHttpResponse.defaultStatusText[r.status] ?? ""
            }
            if let hdrs = initOpts.objectForKeyedSubscript("headers"), !hdrs.isUndefined, !hdrs.isNull {
                copyHeaders(from: hdrs, into: r.headers)
            }
        } else {
            r.statusText = HSHttpResponse.defaultStatusText[r.status] ?? ""
        }

        if !body.isUndefined, !body.isNull {
            let bodyString = body.toString() ?? ""
            r.bodyBytes = bodyString.data(using: .utf8) ?? Data()
            if !r.headers.has("content-type") {
                r.headers.set("content-type", "text/plain;charset=UTF-8")
            }
        }
        return r
    }

    @objc(json::) static func json(_ value: JSValue, _ initOpts: JSValue?) -> HSHttpResponse {
        let bodyString: String
        if let ctx = value.context,
           let stringify = ctx.objectForKeyedSubscript("JSON")?.objectForKeyedSubscript("stringify"),
           let result = stringify.call(withArguments: [value]),
           let s = result.toString() {
            bodyString = s
        } else {
            bodyString = "null"
        }

        let headers = HSHttpHeaders()
        var status = 200
        var statusText: String? = nil

        if let initOpts, initOpts.isObject {
            if let st = initOpts.objectForKeyedSubscript("status"), !st.isUndefined, !st.isNull {
                status = Int(st.toInt32())
            }
            if let stxtVal = initOpts.objectForKeyedSubscript("statusText"),
               !stxtVal.isUndefined, !stxtVal.isNull {
                statusText = stxtVal.toString()
            }
            if let hdrs = initOpts.objectForKeyedSubscript("headers"), !hdrs.isUndefined, !hdrs.isNull {
                copyHeaders(from: hdrs, into: headers)
            }
        }

        headers.set("content-type", "application/json")
        return HSHttpResponse.swiftMake(
            status: status,
            statusText: statusText,
            headers: headers,
            body: bodyString.data(using: .utf8) ?? Data()
        )
    }

    @objc(redirect::) static func redirect(_ url: String, _ statusBox: NSNumber?) -> HSHttpResponse {
        let s = statusBox?.intValue ?? 302
        let h = HSHttpHeaders()
        h.set("location", url)
        return HSHttpResponse.swiftMake(status: s, headers: h)
    }
}
