//
//  HSBLEPeripheral.swift
//  Hammerspoon 2
//
//  JS-facing handle for the relay peripheral. All CoreBluetooth work lives in
//  HSBLECentral; this wrapper just holds the JS callbacks and forwards
//  write/disconnect/uuid back to the central. Both classes are @MainActor.
//

import Foundation
import JavaScriptCore

// MARK: - Declare our JavaScript API

/// A handle to the relay peripheral on the bonded ESP32.
///
/// Returned by `HSBLECentral.connect(...)`. Register `onConnect` / `onDisconnect` /
/// `onNotify`, and `write` lines to the controller. `onConnect` fires once the relay
/// notify characteristic is subscribed (the channel is live).
@objc protocol HSBLEPeripheralAPI: HSTypeAPI, JSExport {
    /// The peripheral's system UUID. Persist this (e.g. in your config) and pass it
    /// back as `connect({ peerUUID })` for instant re-attach to the non-advertising
    /// bonded peer. Empty until first connected.
    /// - Example:
    /// ```js
    /// p.onConnect(() => saveConfig({ peerUUID: p.uuid }))
    /// ```
    @objc var uuid: String { get }

    /// Register a callback fired when the relay channel becomes live (notify subscribed).
    /// - Parameter cb: `function()`.
    /// - Returns: self, for chaining.
    /// - Example:
    /// ```js
    /// p.onConnect(() => console.log('relay up'))
    /// ```
    @objc @discardableResult func onConnect(_ cb: JSValue) -> HSBLEPeripheral

    /// Register a callback fired when the peripheral disconnects.
    /// - Parameter cb: `function(reason)` — `reason` is the disconnect error text, or `"clean"`.
    /// - Returns: self, for chaining.
    /// - Example:
    /// ```js
    /// p.onDisconnect(reason => console.log('relay down:', reason))
    /// ```
    @objc @discardableResult func onDisconnect(_ cb: JSValue) -> HSBLEPeripheral

    /// Register a callback fired for each notify payload from the controller.
    /// - Parameter cb: `function(line)` — `line` is the UTF-8 payload (a JSON string the relay layer parses).
    /// - Returns: self, for chaining.
    /// - Example:
    /// ```js
    /// p.onNotify(line => { const msg = JSON.parse(line); /* ... */ })
    /// ```
    @objc @discardableResult func onNotify(_ cb: JSValue) -> HSBLEPeripheral

    /// Write a line to the relay write characteristic (target → controller), `.withoutResponse`.
    /// - Parameter s: the UTF-8 payload (caller-supplied JSON; keep it under the ATT MTU, ~240 B).
    /// - Returns: `true` if queued; `false` if not connected or the payload exceeds the MTU.
    /// - Example:
    /// ```js
    /// p.write(JSON.stringify({ clip: 'hello' }))
    /// ```
    @objc func write(_ s: String) -> Bool

    /// Disconnect the peripheral and stop auto-reconnect.
    /// - Example:
    /// ```js
    /// p.disconnect()
    /// ```
    @objc func disconnect()
}

// MARK: - Implementation

@_documentation(visibility: private)
@MainActor
@objc class HSBLEPeripheral: NSObject, HSBLEPeripheralAPI {
    @objc var typeName = "HSBLEPeripheral"

    private weak var central: HSBLECentral?
    private var onConnectCb: JSValue?
    private var onDisconnectCb: JSValue?
    private var onNotifyCb: JSValue?

    @objc var uuid: String { central?.peripheralUUID ?? "" }

    init(central: HSBLECentral) {
        self.central = central
        super.init()
    }

    // MARK: - HSBLEPeripheralAPI

    @objc @discardableResult func onConnect(_ cb: JSValue) -> HSBLEPeripheral {
        onConnectCb = cb.isObject ? cb : nil
        return self
    }

    @objc @discardableResult func onDisconnect(_ cb: JSValue) -> HSBLEPeripheral {
        onDisconnectCb = cb.isObject ? cb : nil
        return self
    }

    @objc @discardableResult func onNotify(_ cb: JSValue) -> HSBLEPeripheral {
        onNotifyCb = cb.isObject ? cb : nil
        return self
    }

    @objc func write(_ s: String) -> Bool {
        central?.writeToTx(s) ?? false
    }

    @objc func disconnect() {
        central?.disconnectPeripheral()
    }

    // MARK: - Fired by HSBLECentral (already on the main actor)

    func fireConnect()              { _ = onConnectCb?.callSafely(withArguments: [], context: "hs.ble") }
    func fireDisconnect(_ r: String) { _ = onDisconnectCb?.callSafely(withArguments: [r], context: "hs.ble") }
    func fireNotify(_ s: String)    { _ = onNotifyCb?.callSafely(withArguments: [s], context: "hs.ble") }
}
