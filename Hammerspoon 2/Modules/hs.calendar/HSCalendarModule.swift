//
//  HSCalendarModule.swift
//  Hammerspoon 2
//

import EventKit
import Foundation
import JavaScriptCore

/// Module for accessing Calendar Events.
@objc protocol HSCalendarModuleAPI: JSExport {
    /// Return the app's current Calendar authorization status.
    /// - Returns: One of `fullAccess`, `writeOnly`, `denied`, `restricted`, or `notDetermined`
    /// - Example:
    /// ```js
    /// const status = hs.calendar.authorizationStatus()
    /// console.log(status)
    /// ```
    @objc func authorizationStatus() -> String
}

@_documentation(visibility: private)
@MainActor
@objc class HSCalendarModule: NSObject, HSModuleAPI, HSCalendarModuleAPI {
    var name = "hs.calendar"
    let engineID: UUID

    private let eventStore = HSEventStore.shared

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKDebug("Init of \(name): \(engineID)")
    }

    func shutdown() {}

    isolated deinit {
        AKDebug("Deinit of \(name): \(engineID)")
    }

    @objc func authorizationStatus() -> String {
        switch eventStore.authorizationStatus(for: .event) {
        case .fullAccess:    return "fullAccess"
        case .writeOnly:     return "writeOnly"
        case .denied:        return "denied"
        case .restricted:    return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default:    return "notDetermined"
        }
    }
}
