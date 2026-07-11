//
//  HSRemindersModule.swift
//  Hammerspoon 2
//

import EventKit
import Foundation
import JavaScriptCore

/// Module for accessing Reminders.
@objc protocol HSRemindersModuleAPI: JSExport {
    /// Return the app's current Reminders authorization status.
    /// - Returns: One of `fullAccess`, `denied`, `restricted`, or `notDetermined`
    /// - Example:
    /// ```js
    /// const status = hs.reminders.authorizationStatus()
    /// console.log(status)
    /// ```
    @objc func authorizationStatus() -> String
}

@_documentation(visibility: private)
@MainActor
@objc class HSRemindersModule: NSObject, HSModuleAPI, HSRemindersModuleAPI {
    var name = "hs.reminders"
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
        switch eventStore.authorizationStatus(for: .reminder) {
        case .fullAccess:    return "fullAccess"
        case .denied:        return "denied"
        case .restricted:    return "restricted"
        case .notDetermined: return "notDetermined"
        case .writeOnly:     return "denied"
        @unknown default:    return "notDetermined"
        }
    }
}
