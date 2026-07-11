//
//  HSCalendarIntegrationTests.swift
//  Hammerspoon 2Tests
//

import EventKit
import Testing
@testable import Hammerspoon_2

private nonisolated func hasCalendarModuleFullAccess() -> Bool {
    EKEventStore.authorizationStatus(for: .event) == .fullAccess
}

@Suite("hs.calendar API structure tests")
struct HSCalendarIntegrationTests {
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        return harness
    }

    @Test("hs.calendar is registered on the module root")
    func testModuleRootRegistration() {
        let harness = JSTestHarness()
        harness.loadModuleRoot()
        harness.expectTrue("typeof hs.calendar === 'object'")
    }

    @Test("authorizationStatus is a function")
    func testAuthorizationStatusIsFunction() {
        makeHarness().expectTrue("typeof hs.calendar.authorizationStatus === 'function'")
    }

    @Test("authorizationStatus returns a documented Calendar status")
    func testAuthorizationStatusReturnsDocumentedStatus() {
        makeHarness().expectTrue("['fullAccess', 'writeOnly', 'denied', 'restricted', 'notDetermined'].includes(hs.calendar.authorizationStatus())")
    }

    @Test("listCalendars is a function that returns an array")
    func testListCalendarsIsFunctionReturningArray() {
        makeHarness().expectTrue("""
            typeof hs.calendar.listCalendars === 'function' &&
            Array.isArray(hs.calendar.listCalendars())
            """)
    }
}

@Suite(
    "hs.calendar live tests",
    .serialized,
    .disabled(if: !hasCalendarModuleFullAccess(), "Calendar full access is not granted")
)
struct HSCalendarLiveTests {
    @Test("authorizationStatus reports fullAccess when Calendar access is granted")
    func testAuthorizationStatusReportsFullAccess() {
        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.expectEqual("hs.calendar.authorizationStatus()", "fullAccess")
    }

    @Test("listCalendars returns Calendar summary objects")
    func testListCalendarsReturnsCalendarSummaries() throws {
        let eventStore = HSEventStore.shared.eventStore
        let testCalendar = EKCalendar(for: .event, eventStore: eventStore)
        testCalendar.title = "Hammerspoon 2 listCalendars test \(UUID().uuidString)"
        testCalendar.source = try #require(
            eventStore.sources.first(where: { $0.sourceType == .local }) ??
                eventStore.defaultCalendarForNewEvents?.source,
            "A writable Calendar source is required for the live test"
        )

        try eventStore.saveCalendar(testCalendar, commit: true)
        defer {
            do {
                try eventStore.removeCalendar(testCalendar, commit: true)
            } catch {
                Issue.record("Could not remove the live-test Calendar: \(error)")
            }
        }

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(testCalendar.calendarIdentifier, forKeyedSubscript: "testCalendarID" as NSString)
        harness.context.setObject(testCalendar.title, forKeyedSubscript: "testCalendarTitle" as NSString)
        harness.expectTrue("""
            (() => {
                const calendars = hs.calendar.listCalendars()
                const calendar = calendars.find(item => item.id === testCalendarID)
                return calendars.length > 0 &&
                    calendar !== undefined &&
                    calendar.title === testCalendarTitle &&
                    typeof calendar.id === 'string' &&
                    typeof calendar.title === 'string' &&
                    typeof calendar.writable === 'boolean' &&
                    typeof calendar.isDefault === 'boolean'
            })()
            """)
    }
}
