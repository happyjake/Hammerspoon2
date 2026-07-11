//
//  HSEventStore.swift
//  Hammerspoon 2
//

import EventKit

/// The long-lived EventKit store shared by Calendar, Reminders, and permission requests.
@_documentation(visibility: private)
@MainActor
final class HSEventStore {
    static let shared = HSEventStore()

    let eventStore: EKEventStore

    private init() {
        eventStore = EKEventStore()
    }

    func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: entityType)
    }
}
