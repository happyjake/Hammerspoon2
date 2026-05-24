//
//  HSSqliteModule.swift
//  Hammerspoon 2
//
//  JavaScript bridge to the system libsqlite3. Mirrors the Bun.sqlite /
//  better-sqlite3 surface: open a database, exec schema, run parameterized
//  writes, query parameterized reads, group writes in a transaction that
//  auto-rolls-back on JS throw.
//

import Foundation
import JavaScriptCore
import SQLite3

@objc protocol HSSqliteModuleAPI: JSExport {
    /// Open an SQLite database file. Returns an HSSqliteDB on success, null on failure.
    /// `~` is expanded; parent directories must already exist.
    /// - Parameter path: Filesystem path to the database file
    /// - Returns: An open HSSqliteDB, or null if the open failed
    /// - Example:
    /// ```js
    /// const db = hs.sqlite.open('~/Library/Application Support/VibeCast/vibecast.db')
    /// ```
    @objc func open(_ path: String) -> HSSqliteDB?
}

@_documentation(visibility: private)
@MainActor
@objc class HSSqliteModule: NSObject, HSModuleAPI, HSSqliteModuleAPI {
    var name = "hs.sqlite"
    let engineID: UUID
    private var openDatabases: [Weak<HSSqliteDB>] = []

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {
        for weak in openDatabases {
            weak.value?.close()
        }
        openDatabases.removeAll()
    }

    isolated deinit {
        AKTrace("Deinit of \(name): \(engineID)")
    }

    @objc func open(_ path: String) -> HSSqliteDB? {
        let expanded = NSString(string: path).expandingTildeInPath
        guard let db = HSSqliteDB(path: expanded) else {
            return nil
        }
        openDatabases.append(Weak(db))
        return db
    }
}

private final class Weak<T: AnyObject> {
    weak var value: T?
    init(_ value: T) { self.value = value }
}
