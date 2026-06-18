//
//  HSSerialModule.swift
//  Hammerspoon 2
//

import Foundation
import IOKit
import IOKit.serial
import JavaScriptCore

// MARK: - Declare our JavaScript API

/// Module for enumerating and opening serial ports (e.g. a USB-attached ESP32).
@objc protocol HSSerialModuleAPI: JSExport {
    /// List available serial ports (devices matching `/dev/cu.*`).
    /// - Returns: An array of port objects (empty if none are present). Each object
    ///   always includes `path` and `name`; USB-backed devices may also include
    ///   `serialNumber`, `location`, `locationId`, `usbVendor`, `usbProduct`,
    ///   `vendorId`, and `productId`.
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

    /// Open the first serial port whose name, path, USB serial number, or USB
    /// location contains the given string.
    /// - Parameter match: A substring to search for in each port.
    /// - Returns: An `HSSerialPort` object, or `null` if no matching port was found or could not be opened.
    /// - Example:
    /// ```js
    /// const p = hs.serial.openFirst('usbmodem')
    /// if (p) { console.log('opened', p.path) }
    /// ```
    @objc func openFirst(_ match: String) -> HSSerialPort?

    /// Register a listener for serial device add/remove events.
    ///
    /// The listener receives an event name string and a port object. The port object
    /// always includes `path` and `name`; USB-backed devices may also include
    /// `serialNumber`, `location`, `locationId`, `usbVendor`, `usbProduct`,
    /// `vendorId`, and `productId`.
    /// - `"dev+"` — a serial device was added
    /// - `"dev-"` — a serial device was removed
    ///
    /// - Parameter listener: A JavaScript function called as `fn(event, port)`
    /// - Example:
    /// ```js
    /// const fn = (event, port) => console.log(event, port.path)
    /// hs.serial.addWatcher(fn)
    /// // later:
    /// hs.serial.removeWatcher(fn)
    /// ```
    @objc func addWatcher(_ listener: JSValue)

    /// Remove a previously registered serial device listener.
    /// - Parameter listener: The JavaScript function that was passed to ``addWatcher(_:)``
    /// - Example:
    /// ```js
    /// hs.serial.removeWatcher(fn)
    /// ```
    @objc func removeWatcher(_ listener: JSValue)
}

// MARK: - Implementation

@safe @_documentation(visibility: private)
@MainActor
@objc class HSSerialModule: NSObject, HSModuleAPI, HSSerialModuleAPI {
    var name = "hs.serial"
    let engineID: UUID

    private var ports: [HSSerialPort] = []
    private var watchers: [JSValue] = []
    private var notificationPort: IONotificationPortRef?
    private var matchedIterator: io_iterator_t = 0
    private var terminatedIterator: io_iterator_t = 0
    private var serialWatcherDrainDepth = 0
    private var stopSerialWatcherAfterDrain = false

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {
        for p in ports { p.close() }
        ports.removeAll()
        watchers.removeAll()
        stopSerialWatcherWhenIdle()
    }

    isolated deinit {
        AKTrace("Deinit of \(name): \(engineID)")
    }

    @objc func list() -> [[String: String]] {
        let dev = "/dev"
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dev)) ?? []
        let iokitInfo = serialPortInfosByPath()
        return names.filter { $0.hasPrefix("cu.") }.sorted()
            .map { name in
                let path = "\(dev)/\(name)"
                var info = iokitInfo[path] ?? [:]
                info["path"] = info["path"] ?? path
                info["name"] = info["name"] ?? name
                return info
            }
    }

    @objc func open(_ path: String) -> HSSerialPort? {
        ports.removeAll { !$0.isOpen }
        guard let port = HSSerialPort(path: path) else { return nil }
        ports.append(port)
        return port
    }

    @objc func openFirst(_ match: String) -> HSSerialPort? {
        guard let hit = list().first(where: { portInfo($0, matches: match) }),
              let p = hit["path"] else { return nil }
        return open(p)
    }

    @objc func addWatcher(_ listener: JSValue) {
        guard listener.isObject else { return }
        guard !watchers.contains(where: { $0 === listener || $0.isEqual(listener) }) else { return }
        watchers.append(listener)
        startSerialWatcherIfNeeded()
    }

    @objc func removeWatcher(_ listener: JSValue) {
        watchers.removeAll { $0 === listener || $0.isEqual(listener) }
        if watchers.isEmpty { stopSerialWatcherWhenIdle() }
    }

    private func startSerialWatcherIfNeeded() {
        guard unsafe notificationPort == nil else { return }
        guard let port = unsafe IONotificationPortCreate(kIOMainPortDefault) else {
            AKWarning("hs.serial.addWatcher(): IONotificationPortCreate failed")
            return
        }

        unsafe notificationPort = port
        unsafe IONotificationPortSetDispatchQueue(port, .main)
        let refCon = unsafe Unmanaged.passUnretained(self).toOpaque()

        var addIterator: io_iterator_t = 0
        let addResult = unsafe IOServiceAddMatchingNotification(
            port,
            kIOFirstMatchNotification,
            serialMatchingDictionary(),
            HSSerialModule.deviceMatched,
            refCon,
            &addIterator
        )

        var removeIterator: io_iterator_t = 0
        let removeResult = unsafe IOServiceAddMatchingNotification(
            port,
            kIOTerminatedNotification,
            serialMatchingDictionary(),
            HSSerialModule.deviceTerminated,
            refCon,
            &removeIterator
        )

        guard addResult == KERN_SUCCESS, removeResult == KERN_SUCCESS else {
            AKWarning("hs.serial.addWatcher(): IOServiceAddMatchingNotification failed add=\(addResult) remove=\(removeResult)")
            if addIterator != 0 { IOObjectRelease(addIterator) }
            if removeIterator != 0 { IOObjectRelease(removeIterator) }
            stopSerialWatcher()
            return
        }

        matchedIterator = addIterator
        terminatedIterator = removeIterator
        drain(iterator: matchedIterator, event: nil)
        drain(iterator: terminatedIterator, event: nil)
    }

    private func stopSerialWatcher() {
        stopSerialWatcherAfterDrain = false
        if matchedIterator != 0 {
            IOObjectRelease(matchedIterator)
            matchedIterator = 0
        }
        if terminatedIterator != 0 {
            IOObjectRelease(terminatedIterator)
            terminatedIterator = 0
        }
        if let port = unsafe notificationPort {
            unsafe IONotificationPortDestroy(port)
            unsafe notificationPort = nil
        }
    }

    private func stopSerialWatcherWhenIdle() {
        let hasNotificationPort = unsafe notificationPort != nil
        guard matchedIterator != 0 || terminatedIterator != 0 || hasNotificationPort else { return }
        // IOKit callbacks continue using their iterator after JS callbacks return.
        guard serialWatcherDrainDepth == 0 else {
            stopSerialWatcherAfterDrain = true
            return
        }
        stopSerialWatcher()
    }

    private func serialMatchingDictionary() -> CFMutableDictionary {
        let dict = unsafe IOServiceMatching(kIOSerialBSDServiceValue) as NSMutableDictionary
        dict[kIOSerialBSDTypeKey] = kIOSerialBSDAllTypes
        return dict
    }

    private func serialPortInfosByPath() -> [String: [String: String]] {
        var iterator: io_iterator_t = 0
        let result = unsafe IOServiceGetMatchingServices(
            kIOMainPortDefault,
            serialMatchingDictionary(),
            &iterator
        )
        guard result == KERN_SUCCESS else { return [:] }
        defer {
            if iterator != 0 { IOObjectRelease(iterator) }
        }

        var infos: [String: [String: String]] = [:]
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            let info = serialPortInfo(for: service)
            IOObjectRelease(service)
            if let path = info["path"], !path.isEmpty {
                infos[path] = info
            }
        }
        return infos
    }

    private func portInfo(_ info: [String: String], matches match: String) -> Bool {
        let needle = match.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        let keys = [
            "name", "path", "serialNumber", "location", "locationId",
            "usbVendor", "usbProduct", "vendorId", "productId",
        ]
        return keys.contains { key in
            guard let value = info[key] else { return false }
            return value.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private static let deviceMatched: IOServiceMatchingCallback = { refCon, iterator in
        guard let refCon = unsafe refCon else {
            releaseServices(in: iterator)
            return
        }
        let module = unsafe Unmanaged<HSSerialModule>.fromOpaque(refCon).takeUnretainedValue()
        MainActor.assumeIsolated {
            module.drain(iterator: iterator, event: "dev+")
        }
    }

    private static let deviceTerminated: IOServiceMatchingCallback = { refCon, iterator in
        guard let refCon = unsafe refCon else {
            releaseServices(in: iterator)
            return
        }
        let module = unsafe Unmanaged<HSSerialModule>.fromOpaque(refCon).takeUnretainedValue()
        MainActor.assumeIsolated {
            module.drain(iterator: iterator, event: "dev-")
        }
    }

    private func drain(iterator: io_iterator_t, event: String?) {
        serialWatcherDrainDepth += 1
        defer {
            serialWatcherDrainDepth -= 1
            if serialWatcherDrainDepth == 0 && stopSerialWatcherAfterDrain {
                if watchers.isEmpty {
                    stopSerialWatcher()
                } else {
                    stopSerialWatcherAfterDrain = false
                }
            }
        }

        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            let info = serialPortInfo(for: service)
            IOObjectRelease(service)
            guard let event else { continue }
            for watcher in watchers {
                _ = watcher.callSafely(withArguments: [event, info], context: "hs.serial watcher")
            }
        }
    }

    private static func releaseServices(in iterator: io_iterator_t) {
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            IOObjectRelease(service)
        }
    }

    private func serialPortInfo(for service: io_object_t) -> [String: String] {
        let path = copyStringProperty(kIOCalloutDeviceKey, from: service) ?? ""
        let name = path.isEmpty ? (copyStringProperty(kIOTTYDeviceKey, from: service) ?? "") : URL(fileURLWithPath: path).lastPathComponent
        var info = ["path": path, "name": name]
        if let serialNumber = firstAncestorStringProperty(["USB Serial Number", "kUSBSerialNumberString"], from: service) {
            info["serialNumber"] = serialNumber
        }
        if let locationId = firstAncestorUInt32Property(["locationID"], from: service) {
            info["locationId"] = String(format: "0x%08X", locationId)
            if let location = usbLocationString(from: locationId) {
                info["location"] = location
            }
        }
        if let vendor = firstAncestorStringProperty(["USB Vendor Name", "kUSBVendorString"], from: service) {
            info["usbVendor"] = vendor
        }
        if let product = firstAncestorStringProperty(["USB Product Name", "kUSBProductString"], from: service) {
            info["usbProduct"] = product
        }
        if let vendorId = firstAncestorUInt32Property(["idVendor"], from: service) {
            info["vendorId"] = String(format: "0x%04X", vendorId)
        }
        if let productId = firstAncestorUInt32Property(["idProduct"], from: service) {
            info["productId"] = String(format: "0x%04X", productId)
        }
        return info
    }

    private func copyStringProperty(_ key: String, from service: io_object_t) -> String? {
        guard let unmanaged = unsafe IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        let value = unsafe unmanaged.takeRetainedValue()
        return value as? String
    }

    private func copyUInt32Property(_ key: String, from service: io_object_t) -> UInt32? {
        guard let unmanaged = unsafe IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        let value = unsafe unmanaged.takeRetainedValue()
        return (value as? NSNumber)?.uint32Value
    }

    private func firstAncestorStringProperty(_ keys: [String], from service: io_object_t) -> String? {
        for key in keys {
            if let value = ancestorStringProperty(key, from: service), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func firstAncestorUInt32Property(_ keys: [String], from service: io_object_t) -> UInt32? {
        for key in keys {
            if let value = ancestorUInt32Property(key, from: service) {
                return value
            }
        }
        return nil
    }

    private func ancestorStringProperty(_ key: String, from service: io_object_t) -> String? {
        var current: io_registry_entry_t = service
        var releaseCurrent = false
        while current != 0 {
            if let value = copyStringProperty(key, from: current) {
                if releaseCurrent { IOObjectRelease(current) }
                return value
            }
            var parent: io_registry_entry_t = 0
            let result = IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent)
            if releaseCurrent { IOObjectRelease(current) }
            guard result == KERN_SUCCESS, parent != 0 else { return nil }
            current = parent
            releaseCurrent = true
        }
        return nil
    }

    private func ancestorUInt32Property(_ key: String, from service: io_object_t) -> UInt32? {
        var current: io_registry_entry_t = service
        var releaseCurrent = false
        while current != 0 {
            if let value = copyUInt32Property(key, from: current) {
                if releaseCurrent { IOObjectRelease(current) }
                return value
            }
            var parent: io_registry_entry_t = 0
            let result = IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent)
            if releaseCurrent { IOObjectRelease(current) }
            guard result == KERN_SUCCESS, parent != 0 else { return nil }
            current = parent
            releaseCurrent = true
        }
        return nil
    }

    private func usbLocationString(from locationId: UInt32) -> String? {
        var parts: [String] = []
        for shift in stride(from: 20, through: 0, by: -4) {
            let port = (locationId >> UInt32(shift)) & 0xF
            if port != 0 { parts.append(String(port)) }
        }
        guard !parts.isEmpty else { return nil }
        return "\(locationId >> 24)-\(parts.joined(separator: "."))"
    }
}
