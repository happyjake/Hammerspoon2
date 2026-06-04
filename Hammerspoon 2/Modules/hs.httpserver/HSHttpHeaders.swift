//
//  HSHttpHeaders.swift
//  Hammerspoon 2
//
//  Fetch-spec `Headers` class. Case-insensitive name lookup, multi-value via
//  comma-join on `get()` (per RFC 7230 §3.2.2) but `append()` to record each
//  separately. Iteration is via .entries()/.keys()/.values() returning plain
//  arrays — JSC doesn't support custom @@iterator protocol on Obj-C objects.
//
//  Following the HSColor pattern: no JS-callable @objc init (JSC has trouble
//  binding constructors for JSValue-taking inits). Instead, a static `make`
//  factory is exposed; `hs.httpserver.js` wraps it as `new Headers(init)`.
//

import Foundation
import JavaScriptCore

/// Multi-map of HTTP header name → value(s), with case-insensitive lookup
/// per RFC 7230 §3.2. Backs both incoming `HSHttpRequest.headers` and
/// outgoing `HSHttpResponse.headers`. Mirrors the WHATWG Fetch `Headers`
/// API: `get`, `set`, `append`, `delete`, `has`, iteration.
@objc protocol HSHttpHeadersAPI: HSTypeAPI, JSExport {
    /// Factory equivalent to `new Headers(init)`. The JS wrapper in
    /// `hs.httpserver.js` delegates here.
    /// - Parameter init_: plain JS object `{name: value}` or another Headers
    /// - Returns: a new Headers instance
    @objc(make:) static func make(_ init_: JSValue) -> HSHttpHeaders

    /// Get the combined value for a header name (case-insensitive). Multi-value
    /// headers are joined with `, ` per RFC 7230 §3.2.2.
    /// - Parameter name: the header name to look up (case-insensitive)
    /// - Returns: the combined header value, or null if the header is not present
    @objc func get(_ name: String) -> String?

    /// Set a header to a single value, replacing any prior value(s).
    /// - Parameter name: the header name (case-insensitive)
    /// - Parameter value: the value to set
    @objc func set(_ name: String, _ value: String)

    /// True if the header is present.
    /// - Parameter name: the header name to test (case-insensitive)
    /// - Returns: true if the header is present
    @objc func has(_ name: String) -> Bool

    /// Remove a header.
    /// - Parameter name: the header name to remove (case-insensitive)
    @objc(delete:) func deleteHeader(_ name: String)

    /// Append a value to a header; the prior value(s) are kept.
    /// - Parameter name: the header name (case-insensitive)
    /// - Parameter value: the value to append
    @objc func append(_ name: String, _ value: String)

    /// All header names (lower-cased).
    /// - Returns: all header names, lower-cased
    @objc func keys() -> [String]

    /// All header values, in the same order as `keys()`.
    /// - Returns: all header values, in the same order as `keys()`
    @objc func values() -> [String]

    /// `[[name, value], …]` pairs.
    /// - Returns: `[[name, value], …]` pairs of every header
    @objc func entries() -> [[String]]
}

@_documentation(visibility: private)
@MainActor
@objc class HSHttpHeaders: NSObject, HSHttpHeadersAPI {
    @objc var typeName = "HSHttpHeaders"

    // Lowercased name → array of values. Insertion order is preserved.
    private(set) var orderedNames: [String] = []
    private(set) var storage: [String: [String]] = [:]

    override init() { super.init() }

    @objc(make:) static func make(_ initVal: JSValue) -> HSHttpHeaders {
        let h = HSHttpHeaders()
        if initVal.isUndefined || initVal.isNull { return h }

        if let other = initVal.toObjectOf(HSHttpHeaders.self) as? HSHttpHeaders {
            h.orderedNames = other.orderedNames
            h.storage = other.storage
            return h
        }

        if initVal.isObject {
            let names = (initVal.context?.objectForKeyedSubscript("Object")?
                .invokeMethod("keys", withArguments: [initVal])?
                .toArray() as? [String]) ?? []
            for name in names {
                if let value = initVal.objectForKeyedSubscript(name)?.toString() {
                    h.append(name, value)
                }
            }
        }
        return h
    }

    @objc func get(_ name: String) -> String? {
        guard let values = storage[name.lowercased()] else { return nil }
        return values.joined(separator: ", ")
    }

    @objc func set(_ name: String, _ value: String) {
        let key = name.lowercased()
        if storage[key] == nil { orderedNames.append(key) }
        storage[key] = [value]
    }

    @objc func has(_ name: String) -> Bool {
        return storage[name.lowercased()] != nil
    }

    @objc(delete:) func deleteHeader(_ name: String) {
        let key = name.lowercased()
        storage.removeValue(forKey: key)
        orderedNames.removeAll { $0 == key }
    }

    @objc func append(_ name: String, _ value: String) {
        let key = name.lowercased()
        if storage[key] == nil {
            orderedNames.append(key)
            storage[key] = [value]
        } else {
            storage[key]!.append(value)
        }
    }

    @objc func keys() -> [String] {
        var out: [String] = []
        for name in orderedNames {
            for _ in storage[name] ?? [] { out.append(name) }
        }
        return out
    }

    @objc func values() -> [String] {
        var out: [String] = []
        for name in orderedNames {
            out.append(contentsOf: storage[name] ?? [])
        }
        return out
    }

    @objc func entries() -> [[String]] {
        var out: [[String]] = []
        for name in orderedNames {
            for v in storage[name] ?? [] { out.append([name, v]) }
        }
        return out
    }
}
