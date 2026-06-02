//
//  HSBLEModule.swift
//  Hammerspoon 2
//

import Foundation
import JavaScriptCore

// MARK: - Declare our JavaScript API

/// Module providing a single CoreBluetooth central for the CrossMac control relay.
///
/// On the **target** Mac, this module attaches to the ESP32 "VoiceKB" peripheral that
/// the OS is already BLE-bonded to for HID, discovers the custom relay GATT service,
/// subscribes its notify characteristic (controller → target) and writes its write
/// characteristic (target → controller). It never touches HID — the OS owns that.
///
/// This is deliberately *not* a general GATT stack: one service, one notify char, one
/// write char, on a device we are already bonded to.
@objc protocol HSBLEModuleAPI: JSExport {
    /// Create the BLE central used to attach to the bonded ESP32 relay service.
    ///
    /// Each call returns a fresh `HSBLECentral`; in practice one central is enough.
    /// All centrals are torn down when the module shuts down (JS reload).
    /// - Returns: an `HSBLECentral`.
    /// - Example:
    /// ```js
    /// const c = hs.ble.central()
    /// c.onState(s => console.log('ble', s))
    /// ```
    @objc func central() -> HSBLECentral
}

// MARK: - Implementation

@_documentation(visibility: private)
@MainActor
@objc class HSBLEModule: NSObject, HSModuleAPI, HSBLEModuleAPI {
    var name = "hs.ble"
    let engineID: UUID

    private var centrals: [HSBLECentral] = []

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {
        for c in centrals { c.teardown() }
        centrals.removeAll()
    }

    isolated deinit {
        AKTrace("Deinit of \(name): \(engineID)")
    }

    @objc func central() -> HSBLECentral {
        let c = HSBLECentral()
        centrals.append(c)
        return c
    }
}
