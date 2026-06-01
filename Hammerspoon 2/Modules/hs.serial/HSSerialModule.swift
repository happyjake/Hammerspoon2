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

    /// Open a serial port by device path.
    /// - Parameter path: The device path, e.g. `/dev/cu.usbmodem1`.
    /// - Returns: An `HSSerialPort` object, or `null` if the port could not be opened.
    /// - Example:
    /// ```js
    /// const p = hs.serial.open('/dev/cu.usbmodem1')
    /// if (p) { console.log('opened', p.path) }
    /// ```
    @objc func open(_ path: String) -> HSSerialPort?

    /// Open the first serial port whose name contains the given string.
    /// - Parameter match: A substring to search for in each port's name.
    /// - Returns: An `HSSerialPort` object, or `null` if no matching port was found or could not be opened.
    /// - Example:
    /// ```js
    /// const p = hs.serial.openFirst('usbmodem')
    /// if (p) { console.log('opened', p.path) }
    /// ```
    @objc func openFirst(_ match: String) -> HSSerialPort?
}

// MARK: - Implementation

@_documentation(visibility: private)
@MainActor
@objc class HSSerialModule: NSObject, HSModuleAPI, HSSerialModuleAPI {
    var name = "hs.serial"
    let engineID: UUID

    private var ports: [HSSerialPort] = []

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {
        for p in ports { p.close() }
        ports.removeAll()
    }

    isolated deinit {
        AKTrace("Deinit of \(name): \(engineID)")
    }

    @objc func list() -> [[String: String]] {
        let dev = "/dev"
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dev)) ?? []
        return names.filter { $0.hasPrefix("cu.") }.sorted()
            .map { ["path": "\(dev)/\($0)", "name": $0] }
    }

    @objc func open(_ path: String) -> HSSerialPort? {
        ports.removeAll { !$0.isOpen }
        guard let port = HSSerialPort(path: path) else { return nil }
        ports.append(port)
        return port
    }

    @objc func openFirst(_ match: String) -> HSSerialPort? {
        guard let hit = list().first(where: { ($0["name"] ?? "").contains(match) }),
              let p = hit["path"] else { return nil }
        return open(p)
    }
}
