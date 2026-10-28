import XCTest
import JavaScriptCore
import SQLite3
@testable import Hammerspoon_2

nonisolated final class HSSqliteQueryTests: XCTestCase {
    @MainActor
    private final class WeakConnection {
        weak var database: HSSqliteDB?
        weak var context: JSContext?
        weak var vm: JSVirtualMachine?

        init(_ harness: JSTestHarness) {
            database = harness.evalValue("db")?.toObject() as? HSSqliteDB
            context = harness.context
            vm = harness.vm
        }
    }

    @MainActor
    func testDiscardedContextsReleaseConnectionsWithoutClose() async throws {
        for sql in ["SELECT 1 AS v", "WITH RECURSIVE t(n) AS (VALUES(1) UNION ALL SELECT n+1 FROM t WHERE n<100) SELECT n AS v FROM t"] {
            var connections: [WeakConnection] = []
            for _ in 0..<6 {
                autoreleasepool {
                    let harness = makeHarness()
                    harness.context.setObject(sql, forKeyedSubscript: "sql" as NSString)
                    XCTAssertEqual(harness.evalValue("db.query(sql)[0].v")?.toInt32(), 1)
                    XCTAssertFalse(harness.hasException)
                    let connection = WeakConnection(harness)
                    XCTAssertNotNil(connection.database)
                    XCTAssertNotNil(connection.context)
                    XCTAssertNotNil(connection.vm)
                    connections.append(connection)
                }
            }
            let deadline = ContinuousClock.now.advanced(by: .seconds(3))
            while connections.contains(where: { $0.database != nil || $0.context != nil || $0.vm != nil }),
                  ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertEqual(connections.filter { $0.database != nil }.count, 0, "Discarded contexts retained connections")
            XCTAssertEqual(connections.filter { $0.context != nil }.count, 0, "Discarded contexts remained alive")
            XCTAssertEqual(connections.filter { $0.vm != nil }.count, 0, "Discarded contexts retained VMs")
        }
    }

    @MainActor
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSSqliteModule.self, as: "sqlite")
        harness.eval("var db = hs.sqlite.open(':memory:')")
        XCTAssertFalse(harness.hasException)
        return harness
    }

    // The original Swift collection conversion, retained as an independent
    // reference for the Objective-C bridge's numeric, string and Data behavior.
    @MainActor
    private func referenceRows(_ sql: String) throws -> [[String: Any]] {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(":memory:", &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, sql, -1, &stmt, nil), SQLITE_OK)
        let statement = try XCTUnwrap(stmt)
        defer { sqlite3_finalize(statement) }
        let names = (0..<sqlite3_column_count(statement)).map {
            String(cString: sqlite3_column_name(statement, $0))
        }
        var rows: [[String: Any]] = []
        var rc = sqlite3_step(statement)
        while rc == SQLITE_ROW {
            var row: [String: Any] = [:]
            for (index, name) in names.enumerated() {
                let column = Int32(index)
                switch sqlite3_column_type(statement, column) {
                case SQLITE_INTEGER:
                    row[name] = NSNumber(value: sqlite3_column_int64(statement, column))
                case SQLITE_FLOAT:
                    row[name] = NSNumber(value: sqlite3_column_double(statement, column))
                case SQLITE_TEXT:
                    row[name] = sqlite3_column_text(statement, column).map { String(cString: $0) } ?? ""
                case SQLITE_BLOB:
                    let count = Int(sqlite3_column_bytes(statement, column))
                    if count > 0, let bytes = sqlite3_column_blob(statement, column) {
                        row[name] = Data(bytes: bytes, count: count)
                    } else {
                        row[name] = Data()
                    }
                default:
                    row[name] = NSNull()
                }
            }
            rows.append(row)
            rc = sqlite3_step(statement)
        }
        XCTAssertEqual(rc, SQLITE_DONE)
        return rows
    }

    @MainActor
    private func compareWithReference(_ sql: String, in harness: JSTestHarness) throws {
        harness.context.setObject(try referenceRows(sql), forKeyedSubscript: "expected" as NSString)
        harness.context.setObject(sql, forKeyedSubscript: "sql" as NSString)
        harness.eval("var actual = db.query(sql)")
        XCTAssertFalse(harness.hasException)
        // Dictionary enumeration order was unspecified. Compare names and values,
        // while preserving result row order and distinguishing -0 from +0.
        let equal = harness.evalValue("""
            Array.isArray(actual) && actual.length === expected.length &&
            actual.every((row, i) => {
                const keys = Object.keys(row).sort();
                const other = expected[i];
                return Object.getPrototypeOf(row) === Object.getPrototypeOf(other) &&
                    JSON.stringify(keys) === JSON.stringify(Object.keys(other).sort()) &&
                    keys.every(key => {
                        const a = row[key], b = other[key];
                        if (a !== null && typeof a === 'object') {
                            return typeof b === 'object' && b !== null &&
                                Object.getPrototypeOf(a) === Object.getPrototypeOf(b) &&
                                Object.prototype.toString.call(a) === Object.prototype.toString.call(b) &&
                                JSON.stringify(Object.keys(a)) === JSON.stringify(Object.keys(b));
                        }
                        return Object.is(a, b);
                    });
            })
            """)
        XCTAssertFalse(harness.hasException)
        XCTAssertEqual(equal?.toBool(), true)
    }

    @MainActor
    private func compareSmallAndLarge(_ sql: String, in harness: JSTestHarness) throws {
        try compareWithReference(sql, in: harness)
        try compareWithReference("""
            WITH RECURSIVE repetitions(n) AS (VALUES(1) UNION ALL SELECT n+1 FROM repetitions WHERE n<40)
            \(sql) FROM repetitions
            """, in: harness)
    }

    @MainActor
    func testStorageClassParity() throws {
        let harness = makeHarness()
        defer { harness.eval("db.close()") }
        try compareSmallAndLarge("""
            SELECT 0 AS zero, 1 AS one, -42 AS negative,
                9007199254740991 AS safe, 9007199254740993 AS rounded,
                9223372036854775807 AS maximum, -9223372036854775808 AS minimum,
                -9007199254740993 AS negativeRounded, 3.125 AS real,
                -0.0 AS negativeZero, 1e999 AS infinity, -1e999 AS negativeInfinity,
                5e-324 AS subnormal, NULL AS missing, '' AS empty,
                'ASCII café 日本語 😀 é' AS unicode,
                CAST(X'610062' AS TEXT) AS embeddedNul,
                CAST(X'00FF' AS TEXT) AS leadingNul,
                CAST(X'61FF62' AS TEXT) AS invalidByte,
                CAST(X'E282' AS TEXT) AS truncated,
                CAST(X'EDA080' AS TEXT) AS surrogate,
                CAST(X'F0808080' AS TEXT) AS overlong
            """, in: harness)
        XCTAssertEqual(harness.evalValue("typeof actual[0].one")?.toString(), "number")
        XCTAssertEqual(harness.evalValue("actual[0].rounded === 9007199254740992")?.toBool(), true)
        XCTAssertEqual(harness.evalValue("actual[0].embeddedNul")?.toString(), "a")
        XCTAssertEqual(harness.evalValue("actual[0].invalidByte")?.toString(), "a\u{fffd}b")
    }

    @MainActor
    func testBlobNullAndDuplicateNames() throws {
        let harness = makeHarness()
        defer { harness.eval("db.close()") }
        try compareSmallAndLarge("""
            SELECT X'00017FFF80' AS bytes, X'' AS emptyBlob, NULL AS missing,
                1 AS repeated, 'last' AS repeated, 2 AS "é", 3 AS "é",
                'two' AS "2", 'one' AS "1", 4 AS ""
            """, in: harness)
        for key in ["bytes", "emptyBlob"] {
            let actual = harness.evalValue("actual[39].\(key)")?.toObject() as? Data
            let expected = harness.evalValue("expected[39].\(key)")?.toObject() as? Data
            XCTAssertNotNil(actual)
            XCTAssertEqual(actual, expected)
        }
        XCTAssertEqual(harness.evalValue("actual[0].bytes")?.toObject() as? Data, Data([0, 1, 127, 255, 128]))
        XCTAssertEqual(harness.evalValue("actual[0].repeated")?.toString(), "last")
        XCTAssertEqual(harness.evalValue("actual[0]['é']")?.toInt32(), 3)
        XCTAssertEqual(harness.evalValue("Object.hasOwn(actual[0], 'é')")?.toBool(), false)
        XCTAssertEqual(harness.evalValue("actual[0].missing === null")?.toBool(), true)
        try compareSmallAndLarge("SELECT 5 AS constructor, 6 AS toString, 7 AS __proto__", in: harness)
        try compareSmallAndLarge("SELECT 1 AS __proto__, NULL AS __proto__", in: harness)
    }

    private var largeQuery: String {
        """
        WITH RECURSIVE source(n) AS (VALUES(1) UNION ALL SELECT n+1 FROM source WHERE n<10000)
        SELECT n AS c0, n*2 AS c1, n/4.0 AS c2, NULL AS c3, 'row-'||n AS c4,
            'café 😀' AS c5, printf('%02048d', n) AS c6, -n AS c7,
            9007199254740993 AS c8, '' AS c9, n%2 AS c10, n*0.5 AS c11,
            'tail' AS c12, CAST(X'610062' AS TEXT) AS c13, n+1 AS c14, n+2 AS c15
        FROM source
        """
    }

    @MainActor
    func testLargeResultShapeAndValues() throws {
        let harness = makeHarness()
        defer { harness.eval("db.close()") }
        try compareWithReference(largeQuery, in: harness)
        XCTAssertEqual(harness.evalValue("actual.length")?.toInt32(), 10_000)
        XCTAssertEqual(harness.evalValue("actual.every(row => Object.keys(row).length === 16)")?.toBool(), true)
        XCTAssertEqual(harness.evalValue("actual[9999].c0")?.toInt32(), 10_000)
        harness.forceSynchronousGC()
        XCTAssertEqual(harness.evalValue("actual[9999].c6.length")?.toInt32(), 2048)
    }

    @MainActor
    func testBoundParametersAndStatementReuse() {
        let harness = makeHarness()
        defer { harness.eval("db.close()") }
        let result = harness.evalValue("""
            (() => {
                const sql = 'SELECT ? AS a, ? AS b, ? AS c, ? AS d, ? AS e, ? AS f';
                const first = db.query(sql, [null, true, 42, 1.25, 'text', new Uint8Array([0, 128, 255])])[0];
                const second = db.query(sql, [false, undefined, -7, 0.5, 'next', null])[0];
                const unbound = db.query(sql)[0];
                return first.a === null && first.b === 1 && first.c === 42 && first.d === 1.25 &&
                    first.e === 'text' && typeof first.f === 'object' && first.f !== null &&
                    second.a === 0 && second.b === null && second.c === -7 && second.d === 0.5 &&
                    second.e === 'next' && second.f === null && Object.values(unbound).every(v => v === null);
            })()
            """)
        XCTAssertFalse(harness.hasException)
        XCTAssertEqual(result?.toBool(), true)
        XCTAssertEqual(harness.evalValue("db.query('SELECT ? AS bytes', [new Uint8Array([0, 128, 255])])[0].bytes")?.toObject() as? Data,
                       Data([0, 128, 255]))
    }

    @MainActor
    func testEmptyResultsAndErrors() {
        let harness = makeHarness()
        defer { harness.eval("db.close()") }
        let result = harness.evalValue("""
            (() => {
                const empty = value => Array.isArray(value) && value.length === 0;
                const message = params => {
                    try { db.query('SELECT ? AS value', params); return 'did not throw'; }
                    catch (error) { return error.message; }
                };
                const ok = empty(db.query('SELECT 1 WHERE 0')) && empty(db.query('INVALID SQL')) &&
                    empty(db.query('')) && empty(db.query('CREATE TABLE t (n)')) &&
                    empty(db.query('SELECT 1 AS n UNION ALL SELECT abs(-9223372036854775808)')) &&
                    message({}) === 'hs.sqlite: params must be an array' &&
                    message([{}]) === 'hs.sqlite: cannot bind value at index 0: unsupported object type' &&
                    message([Symbol('x')]) === 'hs.sqlite: cannot bind value at index 0: unsupported type' &&
                    db.query('SELECT ? AS value', [9])[0].value === 9;
                db.close();
                return ok && empty(db.query('SELECT 1'));
            })()
            """)
        XCTAssertFalse(harness.hasException)
        XCTAssertEqual(result?.toBool(), true)
    }

    @MainActor
    func testConnectionCanQueryFromAnotherVirtualMachine() throws {
        let first = makeHarness()
        defer { first.eval("db.close()") }
        let sql = "WITH RECURSIVE t(n) AS (VALUES(1) UNION ALL SELECT n+1 FROM t WHERE n<40) SELECT n AS value FROM t"
        first.context.setObject(sql, forKeyedSubscript: "sql" as NSString)
        XCTAssertEqual(first.evalValue("db.query(sql)[39].value")?.toInt32(), 40)
        let connection = try XCTUnwrap(first.evalValue("db")?.toObject())
        let second = JSTestHarness()
        second.context.setObject(connection, forKeyedSubscript: "db" as NSString)
        second.context.setObject(sql, forKeyedSubscript: "sql" as NSString)
        XCTAssertEqual(second.evalValue("db.query(sql)[39].value")?.toInt32(), 40)
        XCTAssertFalse(second.hasException)
        XCTAssertEqual(first.evalValue("db.query(sql)[39].value")?.toInt32(), 40)
        XCTAssertFalse(first.hasException)
    }

    @MainActor
    func testInheritedSettersRunAfterSQLiteFinishes() {
        for (prototype, property) in [("Object.prototype", "value"), ("Array.prototype", "0"), ("Object.prototype", "0")] {
            let harness = makeHarness()
            defer { harness.eval("db.close()") }
            let result = harness.evalValue("""
                (() => {
                    let calls = 0;
                    const prototype = \(prototype), property = '\(property)';
                    const sql = 'WITH RECURSIVE t(n) AS (VALUES(1) UNION ALL SELECT n+1 FROM t WHERE n<40) SELECT n AS value FROM t';
                    db.query(sql);
                    Object.defineProperty(prototype, property, {
                        configurable: true,
                        set(value) {
                            calls++;
                            db.close();
                            Object.defineProperty(this, property, {value, configurable: true, writable: true, enumerable: true});
                        }
                    });
                    try {
                        const rows = db.query(sql);
                        return rows.length === 40 && rows[0].value === 1 && rows[39].value === 40 &&
                            calls > 0 && !db.isOpen;
                    } finally { delete prototype[property]; }
                })()
                """)
            XCTAssertFalse(harness.hasException)
            XCTAssertEqual(result?.toBool(), true)
        }
    }

    @MainActor
    func testInheritedSetterCanReenterQueryAndDoesNotRunOnStepFailure() {
        let harness = makeHarness()
        defer { harness.eval("db.close()") }
        let result = harness.evalValue("""
            (() => {
                let calls = 0, nested = null;
                const sql = 'WITH RECURSIVE t(n) AS (VALUES(1) UNION ALL SELECT n+1 FROM t WHERE n<40) SELECT n AS value FROM t';
                const descriptor = {configurable: true, set(value) {
                    calls++;
                    delete Object.prototype.value;
                    try { nested = db.query(sql); }
                    finally { Object.defineProperty(Object.prototype, 'value', descriptor); }
                    Object.defineProperty(this, 'value', {value, configurable: true, writable: true, enumerable: true});
                }};
                Object.defineProperty(Object.prototype, 'value', descriptor);
                try {
                    const failed = db.query(sql + ' UNION ALL SELECT abs(-9223372036854775808)');
                    if (failed.length !== 0 || calls !== 0) return false;
                    const rows = db.query(sql);
                    return calls === 40 && rows.length === 40 && rows[39].value === 40 &&
                        nested.length === 40 && nested[39].value === 40;
                } finally { delete Object.prototype.value; }
            })()
            """)
        XCTAssertFalse(harness.hasException)
        XCTAssertEqual(result?.toBool(), true)
    }

    @MainActor
    func testReturningWritesAcrossResultSizes() {
        let harness = makeHarness()
        defer { harness.eval("db.close()") }
        let result = harness.evalValue("""
            (() => {
                db.exec('CREATE TABLE writes (id INTEGER PRIMARY KEY)');
                for (const count of [0, 1, 20, 32, 33, 40]) {
                    db.exec('DELETE FROM writes');
                    const rows = db.query(`WITH RECURSIVE t(n) AS (
                        VALUES(1) UNION ALL SELECT n+1 FROM t WHERE n<${count}
                    ) INSERT INTO writes SELECT n FROM t WHERE n<=${count} RETURNING id`);
                    if (rows.length !== count || rows.some((row,i) => row.id !== i+1) ||
                        db.query('SELECT count(*) AS n FROM writes')[0].n !== count) return false;
                }
                return true;
            })()
            """)
        XCTAssertFalse(harness.hasException)
        XCTAssertEqual(result?.toBool(), true)
    }

    @MainActor
    func testColumnMetadataRefreshesAfterSchemaChangesAndEviction() {
        let harness = makeHarness()
        defer { harness.eval("db.close()") }
        let result = harness.evalValue("""
            (() => {
                const sql = 'SELECT * FROM changing';
                db.exec('CREATE TABLE changing (a); INSERT INTO changing VALUES (1)');
                if (db.query(sql)[0].a !== 1) return false;
                db.exec('ALTER TABLE changing ADD COLUMN b DEFAULT 2');
                if (db.query(sql)[0].a !== 1) return false;
                const expanded = db.query(sql)[0];
                if (expanded.a !== 1 || expanded.b !== 2) return false;
                db.exec('ALTER TABLE changing RENAME COLUMN a TO c');
                db.run(sql);
                if (db.query(sql)[0].c !== 1) return false;
                for (let i = 0; i < 70; i++) db.query('SELECT ' + i + ' AS other');
                const refreshed = db.query(sql)[0];
                return refreshed.c === 1 && refreshed.b === 2 && Object.keys(refreshed).length === 2;
            })()
            """)
        XCTAssertFalse(harness.hasException)
        XCTAssertEqual(result?.toBool(), true)
    }

    @MainActor
    func testQuerySizeThroughput() {
        let harness = makeHarness()
        defer { harness.eval("db.close()") }
        harness.context.setObject("CREATE TABLE bench AS " + largeQuery.replacingOccurrences(of: "n<10000", with: "n<2000"),
                                  forKeyedSubscript: "setupSQL" as NSString)
        XCTAssertEqual(harness.evalValue("db.exec(setupSQL)")?.toBool(), true)
        let cases = [
            ("empty", "SELECT 1 AS v WHERE 0", 0, 20_000),
            ("one", "SELECT 1 AS v", 1, 20_000),
            ("twenty", "SELECT c0 AS v FROM bench LIMIT 20", 20, 2_000),
            ("wide", "SELECT * FROM bench", 2_000, 30)
        ]
        for (name, sql, count, calls) in cases {
            harness.context.setObject(sql, forKeyedSubscript: "sql" as NSString)
            harness.eval("for (let i = 0; i < 20; i++) db.query(sql)")
            XCTAssertFalse(harness.hasException)
            var samples: [Double] = []
            for _ in 0..<6 {
                let start = ContinuousClock.now
                let result = harness.evalValue("""
                    (() => {
                        let count = 0;
                        for (let i = 0; i < \(calls); i++) count += db.query(sql).length;
                        return count;
                    })()
                    """)
                let elapsed = start.duration(to: .now).components
                let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
                samples.append(seconds * 1e6 / Double(calls))
                XCTAssertFalse(harness.hasException)
                XCTAssertEqual(result?.toInt32(), Int32(count * calls))
            }
            let sorted = samples.sorted()
            print("SQLite size benchmark \(name): median \((sorted[2] + sorted[3]) / 2) us/call; samples \(samples); \(calls) calls/sample")
        }
    }

    @MainActor
    func testQueryThroughput() {
        let harness = makeHarness()
        defer { harness.eval("db.close()") }
        harness.context.setObject(largeQuery, forKeyedSubscript: "sql" as NSString)
        harness.eval("db.query(sql); db.query(sql)")
        XCTAssertFalse(harness.hasException)
        let calls = 6
        let start = ContinuousClock.now
        let rows = harness.evalValue("""
            (() => {
                let count = 0;
                for (let i = 0; i < \(calls); ++i) count += db.query(sql).length;
                return count;
            })()
            """)
        let elapsed = start.duration(to: .now).components
        let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        XCTAssertFalse(harness.hasException)
        XCTAssertEqual(rows?.toInt32(), Int32(calls * 10_000))
        print("SQLite query: \(Double(calls * 10_000) / seconds) rows/s, \(seconds * 1000 / Double(calls)) ms/call (10000 rows x 16 columns, \(calls) calls)")
    }
}
