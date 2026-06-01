//
//  HSSerialModule.swift
//  Hammerspoon 2
//

import Foundation
import JavaScriptCore

// MARK: - Declare our JavaScript API

/// Module for enumerating and opening serial ports (e.g. a USB-attached ESP32).
@objc protocol HSSerialModuleAPI: JSExport {
    /// List available serial ports (devices matching `/dev/cu.*`).
    /// - Returns: An array of `{ path, name }` objects (empty if none are present).
    /// - Example:
    /// ```js
    /// hs.serial.list().forEach(p => console.log(p.path))
    /// ```
    @objc func list() -> [[String: String]]
}

// MARK: - Implementation

@_documentation(visibility: private)
@MainActor
@objc class HSSerialModule: NSObject, HSModuleAPI, HSSerialModuleAPI {
    var name = "hs.serial"
    let engineID: UUID

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {}

    @objc func list() -> [[String: String]] {
        let dev = "/dev"
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dev)) ?? []
        return names.filter { $0.hasPrefix("cu.") }.sorted()
            .map { ["path": "\(dev)/\($0)", "name": $0] }
    }
}
