//
//  HSSqliteDB.swift
//  Hammerspoon 2
//
//  Per-connection SQLite database object. Holds the sqlite3 handle, a small
//  prepared-statement cache, and the synchronous exec / run / query /
//  transaction surface exposed to JavaScript.
//

import Foundation
import JavaScriptCore
import SQLite3

// SQLite's destructor sentinel for "make a copy of the bound bytes before the
// bind call returns". Required when binding Swift strings whose underlying
// buffer may not survive the call.
private let SQLITE_TRANSIENT = unsafeBitCast(
    OpaquePointer(bitPattern: -1),
    to: sqlite3_destructor_type.self
)

/// A per-connection SQLite database object returned by `hs.sqlite.open()`.
/// Wraps a sqlite3 handle and exposes synchronous exec, parameterized run/query,
/// and transaction helpers to JavaScript.
@objc protocol HSSqliteDBAPI: HSTypeAPI, JSExport {
    /// The filesystem path of the database.
    @objc var path: String { get }

    /// Whether the database is currently open. Becomes false after `close()`.
    @objc var isOpen: Bool { get }

    /// Execute one or more SQL statements with no parameters. Returns true on
    /// success, false on error (logged via AKError). Use this for DDL
    /// (CREATE/DROP/PRAGMA) and other parameter-less statements.
    /// - Parameter sql: SQL text, possibly containing multiple `;`-separated statements
    /// - Returns: True on success
    /// - Example:
    /// ```js
    /// db.exec('CREATE TABLE IF NOT EXISTS t (id INTEGER PRIMARY KEY, name TEXT)')
    /// ```
    @objc func exec(_ sql: String) -> Bool

    /// Run a parameterized write. Returns an object `{ changes, lastInsertRowid }`
    /// on success, or null on error.
    /// - Parameter sql: Parameterized SQL with `?` placeholders
    /// - Parameter params: Array of values to bind (or null/undefined for no params)
    /// - Returns: `{ changes: number, lastInsertRowid: number }` or null
    /// - Example:
    /// ```js
    /// db.run('INSERT INTO t (name) VALUES (?)', ['alice'])
    /// ```
    @objc(run::) func run(_ sql: String, _ params: JSValue) -> JSValue?

    /// Run a parameterized read. Returns an array of plain JS objects keyed by
    /// column name. Empty array if no rows.
    /// - Parameter sql: Parameterized SELECT
    /// - Parameter params: Array of values to bind
    /// - Returns: {Record<string, any>[]} An array of objects
    /// - Example:
    /// ```js
    /// const rows = db.query('SELECT * FROM t WHERE name LIKE ?', ['a%'])
    /// ```
    @objc(query::) func query(_ sql: String, _ params: JSValue) -> JSValue

    /// Run a JS function inside a BEGIN/COMMIT pair. If the function throws,
    /// the transaction is rolled back and the exception is re-thrown to the
    /// caller. Returns the function's return value on success.
    /// Nested transactions throw — savepoints are not supported in v1.
    /// - Parameter fn: A function with no arguments
    /// - Returns: The function's return value, or null on rollback
    /// - Example:
    /// ```js
    /// db.transaction(() => {
    ///   db.run('UPDATE t SET name = ? WHERE id = ?', ['bob', 1])
    ///   db.run('DELETE FROM t WHERE id = ?', [2])
    /// })
    /// ```
    @objc func transaction(_ fn: JSValue) -> JSValue?

    /// Close the database. Idempotent — second call is a no-op. Throws if
    /// called inside a transaction.
    /// - Example:
    /// ```js
    /// db.close()
    /// ```
    @objc func close()
}

@_documentation(visibility: private)
@MainActor
@objc final class HSSqliteDB: NSObject, HSSqliteDBAPI {
    @objc var typeName = "HSSqliteDB"

    @objc let path: String
    @objc var isOpen: Bool { db != nil }

    private var db: OpaquePointer?
    private var stmtCache: [String: OpaquePointer] = [:]
    private var stmtOrder: [String] = []  // insertion order = LRU order
    private let stmtCacheCap = 64
    private var inTransaction = false
    private var resultPrototypeCheck: JSValue?

    init?(path: String) {
        self.path = path
        super.init()
        var handle: OpaquePointer?
        let rc = sqlite3_open_v2(
            path,
            &handle,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard rc == SQLITE_OK, let handle else {
            let msg = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "rc=\(rc)"
            AKError("hs.sqlite.open: failed to open \(path): \(msg)")
            if handle != nil { sqlite3_close_v2(handle) }
            return nil
        }
        self.db = handle
        AKTrace("hs.sqlite: opened \(path)")
    }

    isolated deinit {
        if db != nil {
            // Best-effort cleanup; on deinit we're past the point of throwing.
            for stmt in stmtCache.values { sqlite3_finalize(stmt) }
            sqlite3_close_v2(db)
        }
        AKTrace("Deinit of HSSqliteDB")
    }

    // MARK: - JS-exposed API

    @objc func exec(_ sql: String) -> Bool {
        guard let db else {
            AKError("hs.sqlite.exec: database is closed")
            return false
        }
        var errmsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errmsg)
        if rc != SQLITE_OK {
            let msg = errmsg.map { String(cString: $0) } ?? "rc=\(rc)"
            sqlite3_free(errmsg)
            AKError("hs.sqlite.exec: \(msg) — SQL: \(sql.prefix(200))")
            return false
        }
        return true
    }

    @objc(run::) func run(_ sql: String, _ params: JSValue) -> JSValue? {
        guard let db else {
            AKError("hs.sqlite.run: database is closed")
            return nil
        }
        guard let stmt = cachedPrepare(sql) else { return nil }
        defer { sqlite3_reset(stmt); sqlite3_clear_bindings(stmt) }

        if !bindParams(stmt: stmt, params: params, sql: sql) { return nil }

        let rc = sqlite3_step(stmt)
        if rc != SQLITE_DONE && rc != SQLITE_ROW {
            AKError("hs.sqlite.run: step failed (\(rc)): \(String(cString: sqlite3_errmsg(db))) — SQL: \(sql.prefix(200))")
            return nil
        }

        let changes = sqlite3_changes64(db)
        let lastRowid = sqlite3_last_insert_rowid(db)
        guard let ctx = JSContext.current() else { return nil }
        let result = JSValue(newObjectIn: ctx)!
        result.setValue(NSNumber(value: changes), forProperty: "changes")
        result.setValue(NSNumber(value: lastRowid), forProperty: "lastInsertRowid")
        return result
    }

    @objc(query::) func query(_ sql: String, _ params: JSValue) -> JSValue {
        let context = params.context!
        let ctx = context.jsGlobalContextRef!
        let rows = JSObjectMakeArray(ctx, 0, nil, nil)!
        JSValueProtect(ctx, rows)
        defer { JSValueUnprotect(ctx, rows) }

        guard let db else {
            AKError("hs.sqlite.query: database is closed")
            return JSValue(jsValueRef: rows, in: context)
        }
        guard let stmt = cachedPrepare(sql) else { return JSValue(jsValueRef: rows, in: context) }
        var needsReset = true
        defer {
            if needsReset { sqlite3_reset(stmt); sqlite3_clear_bindings(stmt) }
        }

        if !bindParams(stmt: stmt, params: params, sql: sql) {
            return JSValue(jsValueRef: rows, in: context)
        }

        let columnCount = Int(sqlite3_column_count(stmt))
        var columns: [(name: JSStringRef, index: Int32)] = []
        var columnPositions: [String: Int] = [:]
        for i in 0..<columnCount {
            let name = String(cString: sqlite3_column_name(stmt, Int32(i)))
            if let position = columnPositions[name] {
                // Swift Dictionary keeps the first key's spelling and the last
                // value, including canonically equivalent Unicode column names.
                columns[position].index = Int32(i)
            } else {
                columnPositions[name] = columns.count
                columns.append((name.withCString { JSStringCreateWithUTF8CString($0)! }, Int32(i)))
            }
        }
        defer { columns.forEach { JSStringRelease($0.name) } }

        if !canAssignResultsDirectly(columns: columns.map(\.name), rows: rows, context: context) {
            // The collection bridge can invoke inherited setters. Finish and
            // reset SQLite before entering JS, including on a later step error.
            let values = collectionRows(stmt: stmt, db: db, sql: sql)
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            needsReset = false
            return JSValue(object: values, in: context)
        }

        var rowIndex: UInt32 = 0
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            if rc != SQLITE_ROW {
                AKError("hs.sqlite.query: step failed (\(rc)): \(String(cString: sqlite3_errmsg(db))) — SQL: \(sql.prefix(200))")
                return JSValue(newArrayIn: context)
            }
            let row = JSObjectMake(ctx, nil, nil)!
            JSValueProtect(ctx, row)
            for column in columns {
                let value = columnValue(stmt: stmt, index: column.index, context: context)
                // Match the NSDictionary bridge's ordinary property assignment.
                JSObjectSetProperty(ctx, row, column.name, value, 0, nil)
            }
            JSObjectSetPropertyAtIndex(ctx, rows, rowIndex, row, nil)
            JSValueUnprotect(ctx, row)
            rowIndex += 1
        }
        return JSValue(jsValueRef: rows, in: context)
    }

    @objc func transaction(_ fn: JSValue) -> JSValue? {
        guard db != nil else {
            AKError("hs.sqlite.transaction: database is closed")
            return nil
        }
        guard let context = fn.context else { return nil }
        if inTransaction {
            throwJSError("hs.sqlite.transaction: nested transactions are not supported", on: context)
            return nil
        }
        guard fn.isObject else {
            throwJSError("hs.sqlite.transaction: argument must be a function", on: context)
            return nil
        }
        if !exec("BEGIN") { return nil }
        inTransaction = true

        // Temporarily swap in our own exception handler. JSC's documented
        // behavior is that the installed handler is invoked when an unhandled
        // exception crosses back into Swift; after the handler returns, JSC
        // clears `context.exception`. By replacing the handler with one that
        // captures into a local var, we reliably detect a JS throw inside the
        // transaction body even when the host (test harness, JSEngine, …)
        // installs its own clearing handler.
        let savedHandler = context.exceptionHandler
        var caughtException: JSValue?
        context.exceptionHandler = { _, exception in
            caughtException = exception
        }

        let result = fn.call(withArguments: [])

        context.exceptionHandler = savedHandler

        if let exc = caughtException {
            _ = exec("ROLLBACK")
            inTransaction = false
            context.exception = exc          // re-throw to the JS caller
            return nil
        }

        if !exec("COMMIT") {
            inTransaction = false
            return nil
        }
        inTransaction = false
        return result
    }

    @objc func close() {
        guard db != nil else { return }
        if inTransaction, let ctx = JSContext.current() {
            throwJSError("hs.sqlite.close: cannot close inside an open transaction", on: ctx)
            return
        }
        for stmt in stmtCache.values { sqlite3_finalize(stmt) }
        stmtCache.removeAll()
        stmtOrder.removeAll()
        sqlite3_close_v2(db)
        db = nil
        resultPrototypeCheck = nil
        AKTrace("hs.sqlite: closed \(path)")
    }

    // MARK: - Internal helpers

    private func canAssignResultsDirectly(columns: [JSStringRef], rows: JSObjectRef, context: JSContext) -> Bool {
        let ctx = context.jsGlobalContextRef!
        let object = JSObjectMake(ctx, nil, nil)!
        let objectPrototype = JSObjectGetPrototype(ctx, object)!
        let arrayPrototype = JSObjectGetPrototype(ctx, rows)!
        guard JSValueIsObject(ctx, objectPrototype), JSValueIsObject(ctx, arrayPrototype) else { return false }
        let objectProto = JSValueToObject(ctx, objectPrototype, nil)!
        let arrayProto = JSValueToObject(ctx, arrayPrototype, nil)!
        // Intrinsic prototypes are ordinary objects; do not traverse an added
        // prototype, which could be a Proxy with arbitrary JS traps.
        guard JSValueIsNull(ctx, JSObjectGetPrototype(ctx, objectProto)),
              JSValueIsStrictEqual(ctx, JSObjectGetPrototype(ctx, arrayProto), objectPrototype) else { return false }
        for column in columns where JSObjectHasProperty(ctx, objectProto, column) { return false }

        if resultPrototypeCheck?.context.virtualMachine !== context.virtualMachine {
            // Use pristine reflection builtins even if the user config replaced
            // Object.getOwnPropertyNames. The helper shares the VM, not globals.
            let helper = JSContext(virtualMachine: context.virtualMachine)!
            resultPrototypeCheck = helper.evaluateScript("""
                ((ownNames) => (objectPrototype, arrayPrototype) => {
                    const indexed = name => /^(0|[1-9][0-9]*)$/.test(name);
                    return !ownNames(objectPrototype).some(indexed) &&
                           !ownNames(arrayPrototype).some(indexed);
                })(Object.getOwnPropertyNames)
                """)
        }
        return resultPrototypeCheck?.call(withArguments: [
            JSValue(jsValueRef: objectPrototype, in: context)!,
            JSValue(jsValueRef: arrayPrototype, in: context)!
        ])?.toBool() == true
    }

    private func collectionRows(stmt: OpaquePointer, db: OpaquePointer, sql: String) -> [[String: Any]] {
        let names = (0..<sqlite3_column_count(stmt)).map { String(cString: sqlite3_column_name(stmt, $0)) }
        var rows: [[String: Any]] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { return rows }
            if rc != SQLITE_ROW {
                AKError("hs.sqlite.query: step failed (\(rc)): \(String(cString: sqlite3_errmsg(db))) — SQL: \(sql.prefix(200))")
                return []
            }
            var row: [String: Any] = [:]
            for (index, name) in names.enumerated() {
                let column = Int32(index)
                switch sqlite3_column_type(stmt, column) {
                case SQLITE_INTEGER:
                    row[name] = NSNumber(value: sqlite3_column_int64(stmt, column))
                case SQLITE_FLOAT:
                    row[name] = NSNumber(value: sqlite3_column_double(stmt, column))
                case SQLITE_TEXT:
                    row[name] = sqlite3_column_text(stmt, column).map { String(cString: $0) } ?? ""
                case SQLITE_BLOB:
                    row[name] = columnData(stmt: stmt, index: column)
                default:
                    row[name] = NSNull()
                }
            }
            rows.append(row)
        }
    }

    private func cachedPrepare(_ sql: String) -> OpaquePointer? {
        if let stmt = stmtCache[sql] {
            // Promote to most-recently-used.
            stmtOrder.removeAll { $0 == sql }
            stmtOrder.append(sql)
            return stmt
        }
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let stmt else {
            let errmsg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "(no handle)"
            AKError("hs.sqlite: prepare failed (\(rc)): \(errmsg) — SQL: \(sql.prefix(200))")
            return nil
        }
        if stmtCache.count >= stmtCacheCap {
            let evict = stmtOrder.removeFirst()
            if let old = stmtCache.removeValue(forKey: evict) {
                sqlite3_finalize(old)
            }
        }
        stmtCache[sql] = stmt
        stmtOrder.append(sql)
        return stmt
    }

    private func bindParams(stmt: OpaquePointer, params: JSValue, sql: String) -> Bool {
        guard !params.isUndefined && !params.isNull else { return true }
        if !params.isArray {
            throwJSError("hs.sqlite: params must be an array", on: params.context)
            return false
        }
        let count = Int(params.objectForKeyedSubscript("length")?.toInt32() ?? 0)
        for i in 0..<count {
            let v = params.atIndex(i)!
            let idx = Int32(i + 1)
            if v.isNull || v.isUndefined {
                sqlite3_bind_null(stmt, idx)
            } else if v.isBoolean {
                sqlite3_bind_int64(stmt, idx, v.toBool() ? 1 : 0)
            } else if v.isNumber {
                let d = v.toDouble()
                if d.rounded() == d && abs(d) <= 9_007_199_254_740_992 /* 2^53 */ {
                    sqlite3_bind_int64(stmt, idx, Int64(d))
                } else {
                    sqlite3_bind_double(stmt, idx, d)
                }
            } else if v.isString {
                let s = v.toString() ?? ""
                sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT)
            } else if v.isObject {
                // Try ArrayBuffer / Uint8Array — anything with a numeric `length`
                // and indexed byte access. JSC bridges typed arrays this way.
                if let lengthVal = v.objectForKeyedSubscript("length"), lengthVal.isNumber {
                    let length = Int(lengthVal.toInt32())
                    if length >= 0 {
                        var bytes = [UInt8](repeating: 0, count: length)
                        for j in 0..<length {
                            bytes[j] = UInt8(v.atIndex(j)?.toUInt32() ?? 0 & 0xff)
                        }
                        bytes.withUnsafeBytes { buf in
                            sqlite3_bind_blob(stmt, idx, buf.baseAddress, Int32(length), SQLITE_TRANSIENT)
                        }
                        continue
                    }
                }
                throwJSError("hs.sqlite: cannot bind value at index \(i): unsupported object type", on: params.context)
                return false
            } else {
                throwJSError("hs.sqlite: cannot bind value at index \(i): unsupported type", on: params.context)
                return false
            }
        }
        return true
    }

    private func columnValue(stmt: OpaquePointer, index: Int32, context: JSContext) -> JSValueRef {
        let ctx = context.jsGlobalContextRef!
        switch sqlite3_column_type(stmt, index) {
        case SQLITE_INTEGER:
            // NSNumber's bridge uses doubleValue, including rounding above 2^53.
            return JSValueMakeNumber(ctx, Double(sqlite3_column_int64(stmt, index)))
        case SQLITE_FLOAT:
            return JSValueMakeNumber(ctx, sqlite3_column_double(stmt, index))
        case SQLITE_TEXT:
            if let cstr = sqlite3_column_text(stmt, index) {
                let string = JSStringCreateWithUTF8CString(UnsafeRawPointer(cstr).assumingMemoryBound(to: CChar.self))!
                defer { JSStringRelease(string) }
                // Both paths stop at the first NUL. JSC returns an empty string
                // for malformed UTF-8; preserve Swift's replacement characters
                // only on that uncommon path, without copying valid text in Swift.
                if cstr.pointee != 0 && JSStringGetLength(string) == 0 {
                    return JSValue(object: String(cString: cstr), in: context).jsValueRef
                }
                return JSValueMakeString(ctx, string)
            }
            let empty = JSStringCreateWithUTF8CString("")!
            defer { JSStringRelease(empty) }
            return JSValueMakeString(ctx, empty)
        case SQLITE_BLOB:
            // Keep Data's existing Objective-C wrapper representation.
            return JSValue(object: columnData(stmt: stmt, index: index), in: context).jsValueRef
        default:
            return JSValueMakeNull(ctx)
        }
    }

    private func columnData(stmt: OpaquePointer, index: Int32) -> Data {
        let len = Int(sqlite3_column_bytes(stmt, index))
        guard len > 0, let raw = sqlite3_column_blob(stmt, index) else { return Data() }
        return Data(bytes: raw, count: len)
    }

    private func throwJSError(_ message: String, on context: JSContext?) {
        guard let context else { return }
        let err = context.evaluateScript("new Error(\(jsonString(message)))")
        context.exception = err
    }

    private func jsonString(_ s: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: s, options: .fragmentsAllowed)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }
}
