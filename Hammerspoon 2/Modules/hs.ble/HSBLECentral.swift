//
//  HSBLECentral.swift
//  Hammerspoon 2
//
//  Ported from the proven ~/.hammerspoon/lib/ble_bridge.swift `Bridge` class.
//  CoreBluetooth delivers all delegate callbacks on the main queue (we create
//  the manager with `queue: nil`), so — like HSBonjourSearch with NetService —
//  the delegate methods are left to infer @MainActor isolation and the params
//  arrive already on the main actor.
//

import Foundation
import JavaScriptCore
import CoreBluetooth

// Relay GATT UUIDs (firmware/main/ble_relay.c). The connect() config may
// override these; these are the shipping firmware defaults.
private let DEFAULT_SVC_UUID    = "7C4A8B30-5D2E-4F1A-9C87-1B3D0E6F5A01"
private let DEFAULT_WRITE_UUID  = "7C4A8B30-5D2E-4F1A-9C87-1B3D0E6F5A02"  // us → ESP32 (becomes relay_in on the controller)
private let DEFAULT_NOTIFY_UUID = "7C4A8B30-5D2E-4F1A-9C87-1B3D0E6F5A03"  // ESP32 → us (the controller's relay_out)
private let HID_UUID = CBUUID(string: "1812")

// MARK: - Declare our JavaScript API

/// A CoreBluetooth central that attaches to the already-bonded ESP32 relay service.
///
/// Obtain via `hs.ble.central()`. Register `onState`, then `connect(...)` to attach
/// to the bonded peripheral and start the relay. The returned `HSBLEPeripheral`
/// reports connection and notify events.
@objc protocol HSBLECentralAPI: HSTypeAPI, JSExport {
    /// Register a callback for CoreBluetooth manager state changes.
    ///
    /// Fires immediately with the current state if one is already known, then again
    /// on every change. Use it to wait for `"poweredOn"` before calling `connect`,
    /// and to surface `"unauthorized"` (missing Bluetooth permission) to the user.
    /// - Parameter cb: `function(state)` — one of `"poweredOn"`, `"poweredOff"`,
    ///   `"unauthorized"`, `"unsupported"`, `"resetting"`, `"unknown"`.
    /// - Returns: self, for chaining.
    /// - Example:
    /// ```js
    /// hs.ble.central().onState(s => { if (s === 'poweredOn') connect() })
    /// ```
    @objc @discardableResult func onState(_ cb: JSValue) -> HSBLECentral

    /// Attach to the bonded ESP32 relay peripheral and bring up the relay channel.
    ///
    /// Connection strategy (mirrors the proven helper): fast-attach via
    /// `retrievePeripherals` when a `peerUUID` is known, else
    /// `retrieveConnectedPeripherals`, else scan. Discovers the relay service,
    /// subscribes the notify characteristic, and fires the peripheral's
    /// `onConnect` once subscribed. Auto-reconnects on drop unless `autoReconnect`
    /// is `false`.
    /// - Parameter config: `{ name?, peerUUID?, service?, notifyChar?, writeChar?, autoReconnect? }`.
    ///   `name` defaults to `"VoiceKB"`; the UUIDs default to the firmware relay
    ///   UUIDs; `autoReconnect` defaults to `true`. Pass `peerUUID` (from a prior
    ///   `peripheral.uuid`) for instant re-attach to the non-advertising bonded peer.
    /// - Returns: an `HSBLEPeripheral`.
    /// - Example:
    /// ```js
    /// const p = c.connect({ name: 'VoiceKB', peerUUID: saved, autoReconnect: true })
    /// p.onNotify(line => relay.ingest(line))
    /// ```
    @objc func connect(_ config: [String: Any]) -> HSBLEPeripheral
}

// MARK: - Implementation

@_documentation(visibility: private)
@MainActor
@objc class HSBLECentral: NSObject, HSBLECentralAPI, CBCentralManagerDelegate, CBPeripheralDelegate {
    @objc var typeName = "HSBLECentral"

    private var manager: CBCentralManager!
    private var cbPeripheral: CBPeripheral?
    private var txChr: CBCharacteristic?   // we write here (us → ESP32)
    private var rxChr: CBCharacteristic?   // we subscribe here (ESP32 → us)
    private var scanning = false

    private var stateCb: JSValue?
    private(set) var wrapper: HSBLEPeripheral?

    // connect() config
    private var svcUUID = CBUUID(string: DEFAULT_SVC_UUID)
    private var txUUID  = CBUUID(string: DEFAULT_WRITE_UUID)
    private var rxUUID  = CBUUID(string: DEFAULT_NOTIFY_UUID)
    private var deviceName = "VoiceKB"
    private var peerUUID: UUID?
    private var autoReconnect = true

    /// The attached peripheral's system UUID (persist for fast re-attach).
    var peripheralUUID: String { cbPeripheral?.identifier.uuidString ?? "" }

    override init() {
        super.init()
        manager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - HSBLECentralAPI

    @objc @discardableResult func onState(_ cb: JSValue) -> HSBLECentral {
        stateCb = cb.isObject ? cb : nil
        // Fire the current state immediately if CoreBluetooth has already settled,
        // so a late listener doesn't miss the initial poweredOn.
        if let m = manager, m.state != .unknown {
            _ = stateCb?.callSafely(withArguments: [Self.stateName(m.state)], context: "hs.ble")
        }
        return self
    }

    @objc func connect(_ config: [String: Any]) -> HSBLEPeripheral {
        deviceName = (config["name"] as? String) ?? "VoiceKB"
        svcUUID = CBUUID(string: (config["service"] as? String) ?? DEFAULT_SVC_UUID)
        txUUID  = CBUUID(string: (config["writeChar"] as? String) ?? DEFAULT_WRITE_UUID)
        rxUUID  = CBUUID(string: (config["notifyChar"] as? String) ?? DEFAULT_NOTIFY_UUID)
        autoReconnect = (config["autoReconnect"] as? Bool) ?? true
        if let s = config["peerUUID"] as? String { peerUUID = UUID(uuidString: s) }

        let w = HSBLEPeripheral(central: self)
        wrapper = w
        if manager.state == .poweredOn { attachExistingOrScan() }
        return w
    }

    // MARK: - Connection bring-up

    private func attachExistingOrScan() {
        // 1) Fast path: resolve the bonded peer directly by its system UUID.
        //    Works even though the peripheral is HID-connected and therefore
        //    not advertising.
        if let uuid = peerUUID {
            let cached = manager.retrievePeripherals(withIdentifiers: [uuid])
            AKTrace("hs.ble: retrievePeripherals(\(uuid.uuidString)) → \(cached.count)")
            if let p = cached.first {
                attach(p)
                scheduleCachedAttachTimeout()
                return
            }
        }
        // 2) Same-system: peripheral is HID-connected to this Mac. macOS may
        //    surface it via the HID/relay service query.
        let connected = manager.retrieveConnectedPeripherals(withServices: [HID_UUID, svcUUID])
        AKTrace("hs.ble: retrieveConnected([HID,SVC]) → \(connected.count)")
        if let match = connected.first(where: { $0.name == deviceName }) {
            attach(match)
            return
        }
        // 3) Fallback: scan (only works while the peripheral is advertising).
        AKTrace("hs.ble: scanning for HID-service peripherals")
        scanning = true
        manager.scanForPeripherals(withServices: [HID_UUID], options: nil)
    }

    private func attach(_ p: CBPeripheral) {
        if scanning { manager.stopScan(); scanning = false }
        cbPeripheral = p
        p.delegate = self
        manager.connect(p, options: nil)
    }

    // If a cached UUID is stale (firmware reflashed, bond cleared), connect can
    // hang silently. Drop the cache and rescan after 5s so we self-heal.
    private func scheduleCachedAttachTimeout() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let p = self.cbPeripheral, p.state == .connected { return }
                AKTrace("hs.ble: cached-UUID attach timed out — clearing, rescanning")
                self.peerUUID = nil
                if let p = self.cbPeripheral { self.manager.cancelPeripheralConnection(p) }
                self.cbPeripheral = nil
                self.txChr = nil
                self.rxChr = nil
                self.attachExistingOrScan()
            }
        }
    }

    // MARK: - Called by HSBLEPeripheral

    func writeToTx(_ s: String) -> Bool {
        guard let p = cbPeripheral, let chr = txChr else { return false }
        let data = Data(s.utf8)
        let maxLen = p.maximumWriteValueLength(for: .withoutResponse)
        if data.count > maxLen {
            AKWarning("hs.ble: write \(data.count)B exceeds MTU cap \(maxLen)B — dropped")
            return false
        }
        p.writeValue(data, for: chr, type: .withoutResponse)
        return true
    }

    func disconnectPeripheral() {
        autoReconnect = false
        if let p = cbPeripheral { manager.cancelPeripheralConnection(p) }
    }

    func teardown() {
        autoReconnect = false
        if scanning { manager.stopScan(); scanning = false }
        if let p = cbPeripheral { manager.cancelPeripheralConnection(p) }
        manager.delegate = nil
        stateCb = nil
        wrapper = nil
        cbPeripheral = nil
        txChr = nil
        rxChr = nil
    }

    // MARK: - State helper

    private static func stateName(_ state: CBManagerState) -> String {
        switch state {
        case .poweredOn:    return "poweredOn"
        case .poweredOff:   return "poweredOff"
        case .unauthorized: return "unauthorized"
        case .unsupported:  return "unsupported"
        case .resetting:    return "resetting"
        case .unknown:      return "unknown"
        @unknown default:   return "unknown"
        }
    }

    // MARK: - CBCentralManagerDelegate
    // CoreBluetooth (queue: nil) delivers on the main thread, so these infer
    // @MainActor — same approach as HSBonjourSearch's NetService delegates.

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        _ = stateCb?.callSafely(withArguments: [Self.stateName(central.state)], context: "hs.ble")
        if central.state == .poweredOn, wrapper != nil, cbPeripheral == nil {
            attachExistingOrScan()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if peripheral.name == deviceName { attach(peripheral) }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Full on-the-wire service walk (nil) — filtered discovery can return a
        // stale cached list when the GATT db changed since the bond was made.
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        AKWarning("hs.ble: connect failed: \(error?.localizedDescription ?? "unknown") — retrying")
        manager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        txChr = nil
        rxChr = nil
        wrapper?.fireDisconnect(error?.localizedDescription ?? "clean")
        if autoReconnect {
            // CoreBluetooth queues this until the peripheral is reachable again.
            manager.connect(peripheral, options: nil)
        }
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let e = error { AKWarning("hs.ble: discoverServices: \(e.localizedDescription)"); return }
        guard let svc = peripheral.services?.first(where: { $0.uuid == svcUUID }) else {
            AKWarning("hs.ble: relay service not present (old firmware or stale GATT cache?)")
            return
        }
        peripheral.discoverCharacteristics([txUUID, rxUUID], for: svc)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let e = error { AKWarning("hs.ble: discoverChrs: \(e.localizedDescription)"); return }
        for chr in service.characteristics ?? [] {
            if chr.uuid == txUUID { txChr = chr }
            if chr.uuid == rxUUID {
                rxChr = chr
                peripheral.setNotifyValue(true, for: chr)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let e = error { AKWarning("hs.ble: subscribe: \(e.localizedDescription)"); return }
        if characteristic.uuid == rxUUID && characteristic.isNotifying {
            // Subscribed → the relay channel is live; report connected.
            wrapper?.fireConnect()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        // Firmware sent a Service Changed indication — re-walk services.
        txChr = nil
        rxChr = nil
        peripheral.discoverServices(nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let e = error { AKWarning("hs.ble: notify: \(e.localizedDescription)"); return }
        guard characteristic.uuid == rxUUID, let data = characteristic.value, !data.isEmpty else { return }
        // The relay channel always carries UTF-8 JSON text; hand the raw line
        // to JS (relay.js parses), mirroring hs.serial.onLine.
        wrapper?.fireNotify(String(decoding: data, as: UTF8.self))
    }
}
