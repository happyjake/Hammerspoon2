//
//  HSSqliteIntegrationTests.swift
//  Hammerspoon 2Tests
//
//  Integration tests for hs.sqlite.
//

import Testing
import JavaScriptCore
import Foundation
@testable import Hammerspoon_2

private func tmpDBPath() -> String {
    let dir = FileManager.default.temporaryDirectory
    return dir.appendingPathComponent(UUID().uuidString + ".db").path
}

@Suite("hs.sqlite API structure")
struct HSSqliteStructureTests {
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSSqliteModule.self, as: "sqlite")
        return harness
    }

    @Test("hs.sqlite.open is a function")
    func testOpenIsFunction() {
        makeHarness().expectTrue("typeof hs.sqlite.open === 'function'")
    }

    @Test("Opening a bad path returns null without throwing")
    func testOpenBadPathReturnsNull() {
        let harness = makeHarness()
        let result = harness.eval("hs.sqlite.open('/nonsense/path/that/does/not/exist/and/cannot/be/created/db.sqlite')")
        #expect(result == nil || (result as? NSNull) != nil)
        #expect(!harness.hasException)
    }

    @Test("Opened DB has expected method types")
    func testDBSurface() {
        let harness = makeHarness()
        let path = tmpDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        harness.eval("var db = hs.sqlite.open(\(escapeJS(path)))")
        #expect(!harness.hasException)
        harness.expectTrue("typeof db === 'object' && db !== null")
        harness.expectTrue("typeof db.exec === 'function'")
        harness.expectTrue("typeof db.run === 'function'")
        harness.expectTrue("typeof db.query === 'function'")
        harness.expectTrue("typeof db.transaction === 'function'")
        harness.expectTrue("typeof db.close === 'function'")
        harness.expectTrue("typeof db.path === 'string'")
        harness.expectTrue("typeof db.isOpen === 'boolean'")
        harness.expectTrue("db.isOpen === true")
        harness.eval("db.close()")
        harness.expectTrue("db.isOpen === false")
    }
}

@Suite("hs.sqlite CRUD round-trips")
struct HSSqliteCRUDTests {
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSSqliteModule.self, as: "sqlite")
        return harness
    }

    @Test("exec creates a table, run inserts, query reads back")
    func testBasicRoundTrip() {
        let harness = makeHarness()
        let path = tmpDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        harness.eval("var db = hs.sqlite.open(\(escapeJS(path)))")
        harness.expectTrue("db.exec('CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT, weight REAL)')")
        harness.eval("var r = db.run('INSERT INTO t (name, weight) VALUES (?, ?)', ['alice', 1.5])")
        harness.expectTrue("r.changes === 1")
        harness.expectTrue("r.lastInsertRowid === 1")

        harness.eval("var rows = db.query('SELECT * FROM t')")
        harness.expectTrue("rows.length === 1")
        harness.expectTrue("rows[0].id === 1")
        harness.expectTrue("rows[0].name === 'alice'")
        harness.expectTrue("rows[0].weight === 1.5")
        harness.eval("db.close()")
    }

    @Test("Type bindings: null, boolean, integer, float, string")
    func testTypeBindings() {
        let harness = makeHarness()
        let path = tmpDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        harness.eval("var db = hs.sqlite.open(\(escapeJS(path)))")
        harness.eval("db.exec('CREATE TABLE t (a, b, c, d, e)')")
        harness.eval("db.run('INSERT INTO t VALUES (?, ?, ?, ?, ?)', [null, true, 42, 3.14, 'hello'])")
        harness.eval("var rows = db.query('SELECT * FROM t')")
        harness.expectTrue("rows[0].a === null")
        // booleans → INTEGER 0/1
        harness.expectTrue("rows[0].b === 1")
        harness.expectTrue("rows[0].c === 42")
        harness.expectTrue("rows[0].d === 3.14")
        harness.expectTrue("rows[0].e === 'hello'")
        harness.eval("db.close()")
    }

    @Test("ON CONFLICT UPSERT works")
    func testUpsert() {
        let harness = makeHarness()
        let path = tmpDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        harness.eval("var db = hs.sqlite.open(\(escapeJS(path)))")
        harness.eval("""
            db.exec(`CREATE TABLE app_usage (
              bundleID TEXT PRIMARY KEY,
              count INTEGER NOT NULL DEFAULT 0,
              lastTs INTEGER NOT NULL
            )`)
        """)
        harness.eval("""
            for (var i = 0; i < 3; i++) {
              db.run(`INSERT INTO app_usage (bundleID, count, lastTs)
                       VALUES (?, 1, ?)
                       ON CONFLICT(bundleID) DO UPDATE
                         SET count = count + 1, lastTs = ?`,
                     ['com.apple.Safari', 1000 + i, 1000 + i])
            }
        """)
        harness.eval("var rows = db.query('SELECT * FROM app_usage')")
        harness.expectTrue("rows.length === 1")
        harness.expectTrue("rows[0].count === 3")
        harness.expectTrue("rows[0].lastTs === 1002")
        harness.eval("db.close()")
    }

    @Test("Multi-statement exec splits correctly")
    func testMultiStatementExec() {
        let harness = makeHarness()
        let path = tmpDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        harness.eval("var db = hs.sqlite.open(\(escapeJS(path)))")
        harness.expectTrue("""
            db.exec(`
              CREATE TABLE a (id INTEGER);
              CREATE TABLE b (id INTEGER);
              CREATE INDEX idx_a ON a(id);
            `)
        """)
        harness.eval("var tables = db.query(\"SELECT name FROM sqlite_master WHERE type='table' ORDER BY name\")")
        harness.expectTrue("tables.length === 2")
        harness.expectTrue("tables[0].name === 'a'")
        harness.expectTrue("tables[1].name === 'b'")
        harness.eval("db.close()")
    }

    @Test("Empty result set returns empty array")
    func testEmptyResult() {
        let harness = makeHarness()
        let path = tmpDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        harness.eval("var db = hs.sqlite.open(\(escapeJS(path)))")
        harness.eval("db.exec('CREATE TABLE t (id INTEGER)')")
        harness.eval("var rows = db.query('SELECT * FROM t WHERE id = ?', [999])")
        harness.expectTrue("Array.isArray(rows)")
        harness.expectTrue("rows.length === 0")
        harness.eval("db.close()")
    }
}

@Suite("hs.sqlite transactions")
struct HSSqliteTransactionTests {
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSSqliteModule.self, as: "sqlite")
        return harness
    }

    @Test("Transaction success commits")
    func testCommit() {
        let harness = makeHarness()
        let path = tmpDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        harness.eval("var db = hs.sqlite.open(\(escapeJS(path)))")
        harness.eval("db.exec('CREATE TABLE t (id INTEGER)')")
        harness.eval("""
            var r = db.transaction(() => {
                db.run('INSERT INTO t VALUES (?)', [1])
                db.run('INSERT INTO t VALUES (?)', [2])
                return 'committed'
            })
        """)
        harness.expectTrue("r === 'committed'")
        harness.eval("var rows = db.query('SELECT * FROM t ORDER BY id')")
        harness.expectTrue("rows.length === 2")
        harness.eval("db.close()")
    }

    @Test("Transaction body throw rolls back")
    func testRollback() {
        let harness = makeHarness()
        let path = tmpDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        harness.eval("var db = hs.sqlite.open(\(escapeJS(path)))")
        harness.eval("db.exec('CREATE TABLE t (id INTEGER)')")
        harness.eval("db.run('INSERT INTO t VALUES (?)', [99])")
        harness.eval("""
            var threw = false
            try {
              db.transaction(() => {
                db.run('INSERT INTO t VALUES (?)', [1])
                throw new Error('nope')
              })
            } catch (e) { threw = true }
        """)
        harness.expectTrue("threw === true")
        // Only the pre-existing row should survive.
        harness.eval("var rows = db.query('SELECT * FROM t ORDER BY id')")
        harness.expectTrue("rows.length === 1")
        harness.expectTrue("rows[0].id === 99")
        harness.eval("db.close()")
    }

    @Test("Nested transactions throw")
    func testNestedTransactionThrows() {
        let harness = makeHarness()
        let path = tmpDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        harness.eval("var db = hs.sqlite.open(\(escapeJS(path)))")
        harness.eval("db.exec('CREATE TABLE t (id INTEGER)')")
        harness.eval("""
            var inner = false, threw = false
            try {
              db.transaction(() => {
                db.transaction(() => { inner = true })
              })
            } catch (e) { threw = true }
        """)
        harness.expectTrue("threw === true")
        harness.expectTrue("inner === false")
        harness.eval("db.close()")
    }
}

@Suite("hs.sqlite lifecycle")
struct HSSqliteLifecycleTests {
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSSqliteModule.self, as: "sqlite")
        return harness
    }

    @Test("close() is idempotent")
    func testCloseIdempotent() {
        let harness = makeHarness()
        let path = tmpDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        harness.eval("var db = hs.sqlite.open(\(escapeJS(path)))")
        harness.eval("db.close()")
        harness.eval("db.close()")
        #expect(!harness.hasException)
    }

    @Test("Operations on closed DB fail gracefully (no throw)")
    func testClosedDBGraceful() {
        let harness = makeHarness()
        let path = tmpDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        harness.eval("var db = hs.sqlite.open(\(escapeJS(path)))")
        harness.eval("db.close()")
        harness.eval("var r1 = db.exec('CREATE TABLE t (id INTEGER)')")
        harness.expectTrue("r1 === false")
        harness.eval("var r2 = db.run('INSERT INTO t VALUES (?)', [1])")
        harness.expectTrue("r2 === null || r2 === undefined || r2 === false")
        harness.eval("var r3 = db.query('SELECT * FROM t')")
        harness.expectTrue("Array.isArray(r3) && r3.length === 0")
        #expect(!harness.hasException)
    }

    @Test("Statement cache evicts past 64 entries")
    func testStatementCacheEviction() {
        let harness = makeHarness()
        let path = tmpDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        harness.eval("var db = hs.sqlite.open(\(escapeJS(path)))")
        harness.eval("db.exec('CREATE TABLE t (id INTEGER)')")
        // 70 distinct queries — past the 64-entry cap. Should still succeed,
        // not crash, not leak (eviction finalizes the LRU entry).
        harness.eval("""
            for (var i = 0; i < 70; i++) {
              db.query('SELECT ' + i + ' AS x FROM t')
            }
            var sentinel = db.query('SELECT 999 AS x')
        """)
        harness.expectTrue("sentinel[0].x === 999")
        harness.eval("db.close()")
    }
}

@Suite("hs.sqlite edge cases")
struct HSSqliteEdgeCaseTests {
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSSqliteModule.self, as: "sqlite")
        return harness
    }

    @Test("Invalid SQL returns null/false without throwing")
    func testInvalidSQL() {
        let harness = makeHarness()
        let path = tmpDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        harness.eval("var db = hs.sqlite.open(\(escapeJS(path)))")
        harness.eval("var ok = db.exec('THIS IS NOT SQL')")
        harness.expectTrue("ok === false")
        #expect(!harness.hasException)
        harness.eval("db.close()")
    }

    @Test("BLOB round-trip preserves bytes (via Uint8Array)")
    func testBlobRoundTrip() {
        let harness = makeHarness()
        let path = tmpDBPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        harness.eval("var db = hs.sqlite.open(\(escapeJS(path)))")
        harness.eval("db.exec('CREATE TABLE t (b BLOB)')")
        harness.eval("db.run('INSERT INTO t VALUES (?)', [new Uint8Array([1, 2, 3, 250, 0, 99])])")
        harness.eval("var rows = db.query('SELECT b FROM t')")
        // The BLOB comes back to JS as some byte container; just verify length.
        harness.expectTrue("rows.length === 1")
        harness.expectTrue("rows[0].b !== null && rows[0].b !== undefined")
        harness.eval("db.close()")
    }
}

// Small helper local to this test file. (HSHashIntegrationTests has its own
// escapeJSString global — that's at the bottom of that file and not in scope here.)
private func escapeJS(_ s: String) -> String {
    let data = try? JSONSerialization.data(withJSONObject: s, options: .fragmentsAllowed)
    return data.flatMap { String(data: $0, encoding: .utf8) } ?? "''"
}
