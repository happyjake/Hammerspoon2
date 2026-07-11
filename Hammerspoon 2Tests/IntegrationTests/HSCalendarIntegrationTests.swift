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

private func makeThrowawayCalendar(
    in eventStore: EKEventStore,
    purpose: String
) throws -> EKCalendar {
    let calendar = EKCalendar(for: .event, eventStore: eventStore)
    calendar.title = "Hammerspoon 2 issue 9 \(purpose) \(UUID().uuidString)"
    calendar.source = try #require(
        eventStore.sources.first(where: { $0.sourceType == .local }) ??
            eventStore.defaultCalendarForNewEvents?.source,
        "A writable Calendar source is required for the live test"
    )
    try eventStore.saveCalendar(calendar, commit: true)
    return calendar
}

private func removeThrowawayCalendar(_ calendar: EKCalendar, from eventStore: EKEventStore) {
    do {
        try eventStore.removeCalendar(calendar, commit: true)
    } catch {
        Issue.record("Could not remove the live-test Calendar: \(error)")
    }
}

private func instant(_ value: String) throws -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return try #require(formatter.date(from: value), "Invalid test fixture instant: \(value)")
}

private func localDate(year: Int, month: Int, day: Int) throws -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = .current
    components.year = year
    components.month = month
    components.day = day
    return try #require(components.date, "Could not construct the all-day test fixture date")
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

    @Test("listEvents is a function")
    func testListEventsIsFunction() {
        makeHarness().expectTrue("typeof hs.calendar.listEvents === 'function'")
    }

    @Test("searchEvents is a function")
    func testSearchEventsIsFunction() {
        makeHarness().expectTrue("typeof hs.calendar.searchEvents === 'function'")
    }

    @Test("Event query windows reject datetimes without an offset")
    func testEventQueriesRejectOffsetlessDatetimes() {
        makeHarness().expectTrue("""
            (() => {
                try {
                    hs.calendar.listEvents(
                        'Calendar is not consulted for invalid dates',
                        '2026-07-12T09:00:00',
                        '2026-07-12T10:00:00Z'
                    )
                    return false
                } catch (error) {
                    return String(error).includes('explicit UTC offset or Z')
                }
            })()
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
        let testCalendar = try makeThrowawayCalendar(in: eventStore, purpose: "listCalendars")
        defer { removeThrowawayCalendar(testCalendar, from: eventStore) }

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

    @Test("listEvents reads exact timed and all-day fixtures with the documented output shape")
    func testListEventsReturnsFixtureSummaries() throws {
        let eventStore = HSEventStore.shared.eventStore
        let calendar = try makeThrowawayCalendar(in: eventStore, purpose: "listEvents")
        defer { removeThrowawayCalendar(calendar, from: eventStore) }

        let timed = EKEvent(eventStore: eventStore)
        timed.calendar = calendar
        timed.title = "Hammerspoon 2 timed read fixture \(UUID().uuidString)"
        timed.startDate = try instant("2040-02-03T04:05:06Z")
        timed.endDate = try instant("2040-02-03T05:35:06Z")
        timed.location = "Issue 9 test room"
        timed.notes = "Issue 9 test notes"
        timed.url = URL(string: "https://example.test/vibecast/issue-9")
        timed.availability = .free
        try eventStore.save(timed, span: .thisEvent, commit: true)

        let allDay = EKEvent(eventStore: eventStore)
        allDay.calendar = calendar
        allDay.title = "Hammerspoon 2 all-day read fixture \(UUID().uuidString)"
        allDay.isAllDay = true
        allDay.startDate = try localDate(year: 2040, month: 2, day: 4)
        allDay.endDate = try localDate(year: 2040, month: 2, day: 5)
        try eventStore.save(allDay, span: .thisEvent, commit: true)

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(calendar.calendarIdentifier, forKeyedSubscript: "fixtureCalendarID" as NSString)
        harness.context.setObject(calendar.title, forKeyedSubscript: "fixtureCalendarTitle" as NSString)
        harness.context.setObject(timed.eventIdentifier, forKeyedSubscript: "timedFixtureID" as NSString)
        harness.context.setObject(timed.title, forKeyedSubscript: "timedFixtureTitle" as NSString)
        harness.context.setObject(allDay.eventIdentifier, forKeyedSubscript: "allDayFixtureID" as NSString)
        harness.context.setObject(allDay.title, forKeyedSubscript: "allDayFixtureTitle" as NSString)

        harness.expectTrue("""
            (() => {
                const byID = hs.calendar.listEvents(
                    fixtureCalendarID,
                    '2040-02-03T00:00:00Z',
                    '2040-02-06T00:00:00Z'
                )
                const byTitle = hs.calendar.listEvents(
                    fixtureCalendarTitle,
                    '2040-02-03T00:00:00Z',
                    '2040-02-06T00:00:00Z'
                )
                const timed = byID.find(event => event.id === timedFixtureID)
                const allDay = byTitle.find(event => event.id === allDayFixtureID)

                return timed !== undefined &&
                    timed.title === timedFixtureTitle &&
                    timed.start === '2040-02-03T04:05:06Z' &&
                    timed.end === '2040-02-03T05:35:06Z' &&
                    timed.allDay === false &&
                    timed.location === 'Issue 9 test room' &&
                    timed.notes === 'Issue 9 test notes' &&
                    timed.url === 'https://example.test/vibecast/issue-9' &&
                    timed.recurring === false &&
                    timed.occurrenceStart === null &&
                    Array.isArray(timed.attendees) &&
                    timed.organizer === null &&
                    ['none', 'confirmed', 'tentative', 'canceled'].includes(timed.status) &&
                    ['notSupported', 'busy', 'free', 'tentative', 'unavailable'].includes(timed.availability) &&
                    allDay !== undefined &&
                    allDay.title === allDayFixtureTitle &&
                    allDay.start === '2040-02-04' &&
                    allDay.end === '2040-02-05' &&
                    allDay.allDay === true &&
                    allDay.recurring === false &&
                    allDay.occurrenceStart === null
            })()
            """)
    }

    @Test("searchEvents finds the uniquely named fixture by title text")
    func testSearchEventsFindsFixtureByTitle() throws {
        let eventStore = HSEventStore.shared.eventStore
        let calendar = try makeThrowawayCalendar(in: eventStore, purpose: "searchEvents")
        defer { removeThrowawayCalendar(calendar, from: eventStore) }

        let uniqueNeedle = "needle-\(UUID().uuidString)"
        let matching = EKEvent(eventStore: eventStore)
        matching.calendar = calendar
        matching.title = "Hammerspoon 2 search \(uniqueNeedle)"
        matching.startDate = try instant("2040-04-10T08:00:00Z")
        matching.endDate = try instant("2040-04-10T09:00:00Z")
        try eventStore.save(matching, span: .thisEvent, commit: true)

        let decoy = EKEvent(eventStore: eventStore)
        decoy.calendar = calendar
        decoy.title = "Hammerspoon 2 unrelated search fixture \(UUID().uuidString)"
        decoy.startDate = try instant("2040-04-10T10:00:00Z")
        decoy.endDate = try instant("2040-04-10T11:00:00Z")
        try eventStore.save(decoy, span: .thisEvent, commit: true)

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(uniqueNeedle, forKeyedSubscript: "fixtureNeedle" as NSString)
        harness.context.setObject(matching.eventIdentifier, forKeyedSubscript: "matchingFixtureID" as NSString)
        harness.context.setObject(matching.title, forKeyedSubscript: "matchingFixtureTitle" as NSString)
        harness.context.setObject(decoy.eventIdentifier, forKeyedSubscript: "decoyFixtureID" as NSString)

        harness.expectTrue("""
            (() => {
                const events = hs.calendar.searchEvents(
                    fixtureNeedle.toUpperCase(),
                    '2040-04-10T00:00:00Z',
                    '2040-04-11T00:00:00Z'
                )
                const match = events.find(event => event.id === matchingFixtureID)
                return match !== undefined &&
                    match.title === matchingFixtureTitle &&
                    !events.some(event => event.id === decoyFixtureID)
            })()
            """)
    }

    @Test("listEvents expands a recurring fixture into exact Occurrences")
    func testListEventsExpandsRecurringFixture() throws {
        let eventStore = HSEventStore.shared.eventStore
        let calendar = try makeThrowawayCalendar(in: eventStore, purpose: "recurring Occurrences")
        defer { removeThrowawayCalendar(calendar, from: eventStore) }

        let recurring = EKEvent(eventStore: eventStore)
        recurring.calendar = calendar
        recurring.title = "Hammerspoon 2 recurring read fixture \(UUID().uuidString)"
        recurring.startDate = try instant("2040-03-01T10:00:00Z")
        recurring.endDate = try instant("2040-03-01T10:30:00Z")
        recurring.addRecurrenceRule(EKRecurrenceRule(
            recurrenceWith: .daily,
            interval: 1,
            end: EKRecurrenceEnd(occurrenceCount: 3)
        ))
        try eventStore.save(recurring, span: .thisEvent, commit: true)

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(calendar.calendarIdentifier, forKeyedSubscript: "fixtureCalendarID" as NSString)
        harness.context.setObject(recurring.title, forKeyedSubscript: "recurringFixtureTitle" as NSString)

        harness.expectTrue("""
            (() => {
                const occurrences = hs.calendar.listEvents(
                    fixtureCalendarID,
                    '2040-03-01T00:00:00Z',
                    '2040-03-05T00:00:00Z'
                ).filter(event => event.title === recurringFixtureTitle)
                const starts = occurrences.map(event => event.occurrenceStart).sort()
                return occurrences.length === 3 &&
                    occurrences.every(event => event.recurring === true) &&
                    new Set(occurrences.map(event => event.id)).size === 1 &&
                    JSON.stringify(starts) === JSON.stringify([
                        '2040-03-01T10:00:00Z',
                        '2040-03-02T10:00:00Z',
                        '2040-03-03T10:00:00Z'
                    ])
            })()
            """)
    }
}
