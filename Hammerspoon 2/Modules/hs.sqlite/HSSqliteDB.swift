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
    private final class PreparedStatement {
        let handle: OpaquePointer
        private(set) var columnNames: [String]
        private var generation: Int32 = 0

        init(_ handle: OpaquePointer) {
            self.handle = handle
            columnNames = (0..<sqlite3_column_count(handle)).map { String(cString: sqlite3_column_name(handle, $0)) }
        }

        func reset() {
            // Reprepare changes SQLite's metadata during step(). Keep the names
            // from before this execution for its rows, then refresh for the next.
            let current = sqlite3_stmt_status(handle, SQLITE_STMTSTATUS_REPREPARE, 0)
            if current != generation {
                columnNames = (0..<sqlite3_column_count(handle)).map { String(cString: sqlite3_column_name(handle, $0)) }
                generation = current
            }
            sqlite3_reset(handle)
            sqlite3_clear_bindings(handle)
        }
    }

    private var stmtCache: [String: PreparedStatement] = [:]
    private var stmtOrder: [String] = []  // insertion order = LRU order
    private let stmtCacheCap = 64
    private var inTransaction = false

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
            for stmt in stmtCache.values { sqlite3_finalize(stmt.handle) }
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
        guard let statement = cachedPrepare(sql) else { return nil }
        let stmt = statement.handle
        defer { statement.reset() }

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
        guard let db else {
            AKError("hs.sqlite.query: database is closed")
            return JSValue(newArrayIn: context)
        }
        guard let statement = cachedPrepare(sql) else { return JSValue(newArrayIn: context) }
        let stmt = statement.handle
        var needsReset = true
        defer {
            if needsReset { statement.reset() }
        }

        if !bindParams(stmt: stmt, params: params, sql: sql) {
            return JSValue(newArrayIn: context)
        }

        var rc = sqlite3_step(stmt)
        if rc != SQLITE_ROW {
            if rc != SQLITE_DONE {
                AKError("hs.sqlite.query: step failed (\(rc)): \(String(cString: sqlite3_errmsg(db))) — SQL: \(sql.prefix(200))")
            }
            return JSValue(newArrayIn: context)
        }

        let ctx = context.jsGlobalContextRef!
        let names = statement.columnNames
        var columns: [(name: String, key: JSStringRef, index: Int32)] = []
        var columnPositions: [String: Int] = [:]
        for (i, name) in names.enumerated() {
            if let position = columnPositions[name] {
                // Swift Dictionary keeps the first key's spelling and the last
                // value, including canonically equivalent Unicode column names.
                columns[position].index = Int32(i)
            } else {
                columnPositions[name] = columns.count
                columns.append((name, name.withCString { JSStringCreateWithUTF8CString($0)! }, Int32(i)))
            }
        }
        defer { columns.forEach { JSStringRelease($0.key) } }

        // Native buffers are invisible to JSC's collector. Root the cells until
        // the result owns them, and finish SQLite before any JS property writes.
        var values: [JSValueRef] = []
        values.reserveCapacity(columns.count)
        defer { values.forEach { JSValueUnprotect(ctx, $0) } }
        var rowCount = 0
        while rc == SQLITE_ROW {
            for column in columns {
                let value = columnValue(stmt: stmt, index: column.index, context: context)
                JSValueProtect(ctx, value)
                values.append(value)
            }
            rowCount += 1
            rc = sqlite3_step(stmt)
        }
        let stepError = rc == SQLITE_DONE ? nil : String(cString: sqlite3_errmsg(db))
        statement.reset()
        needsReset = false
        if let stepError {
            AKError("hs.sqlite.query: step failed (\(rc)): \(stepError) — SQL: \(sql.prefix(200))")
            return JSValue(newArrayIn: context)
        }

        let rows = JSObjectMakeArray(ctx, 0, nil, nil)!
        JSValueProtect(ctx, rows)
        defer { JSValueUnprotect(ctx, rows) }
        if !canAssignResultsDirectly(columns: columns.map(\.key), rowCount: rowCount, rows: rows, context: context) {
            // Preserve the collection bridge's ordering and setter behavior for
            // intercepted assignments. Wrapping a cell keeps its existing value,
            // including Data's Objective-C wrapper, without converting it again.
            var collection: [[String: Any]] = []
            for rowIndex in 0..<rowCount {
                var row: [String: Any] = [:]
                for (index, column) in columns.enumerated() {
                    row[column.name] = JSValue(jsValueRef: values[rowIndex * columns.count + index], in: context)!
                }
                collection.append(row)
            }
            return JSValue(object: collection, in: context)
        }

        for rowIndex in 0..<rowCount {
            let row = JSObjectMake(ctx, nil, nil)!
            JSValueProtect(ctx, row)
            for (index, column) in columns.enumerated() {
                let value = values[rowIndex * columns.count + index]
                // Match the NSDictionary bridge's ordinary property assignment.
                JSObjectSetProperty(ctx, row, column.key, value, 0, nil)
            }
            JSObjectSetPropertyAtIndex(ctx, rows, UInt32(rowIndex), row, nil)
            JSValueUnprotect(ctx, row)
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
        for stmt in stmtCache.values { sqlite3_finalize(stmt.handle) }
        stmtCache.removeAll()
        stmtOrder.removeAll()
        sqlite3_close_v2(db)
        db = nil
        AKTrace("hs.sqlite: closed \(path)")
    }

    // MARK: - Internal helpers

    private func canAssignResultsDirectly(columns: [JSStringRef], rowCount: Int, rows: JSObjectRef, context: JSContext) -> Bool {
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

        // Check only indices that will be assigned. HasProperty includes
        // non-enumerable keys without invoking getters or enumerating prototypes.
        for index in 0..<rowCount {
            if JSObjectHasPropertyForKey(ctx, arrayProto, JSValueMakeNumber(ctx, Double(index)), nil) {
                return false
            }
        }
        return true
    }

    private func cachedPrepare(_ sql: String) -> PreparedStatement? {
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
                sqlite3_finalize(old.handle)
            }
        }
        let statement = PreparedStatement(stmt)
        stmtCache[sql] = statement
        stmtOrder.append(sql)
        return statement
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
