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

    @Test("createEvent is a function")
    func testCreateEventIsFunction() {
        makeHarness().expectTrue("typeof hs.calendar.createEvent === 'function'")
    }

    @Test("createEvent rejects a timed Event without an explicit UTC offset")
    func testCreateEventRejectsNakedDatetime() {
        let harness = makeHarness()
        harness.eval("""
            hs.calendar.createEvent({
                title: 'Naked datetime must fail',
                start: '2026-07-13T09:00:00',
                end: '2026-07-13T10:00:00'
            })
            """)

        #expect(harness.hasException)
        #expect(harness.exceptionMessage?.contains("UTC offset or Z") == true)
    }

    @Test(
        "createEvent rejects an out-of-range UTC offset",
        arguments: ["+99:99", "+14:01", "+00:60"]
    )
    func testCreateEventRejectsInvalidUTCOffset(offset: String) {
        let harness = makeHarness()
        harness.eval("""
            hs.calendar.createEvent({
                title: 'Invalid offset must fail',
                start: '2026-07-13T09:00:00\(offset)',
                end: '2026-07-13T10:00:00\(offset)'
            })
            """)

        #expect(harness.hasException)
        #expect(harness.exceptionMessage?.contains("valid ISO 8601 datetime") == true)
    }

    @Test("createEvent requires date-only values for an all-day Event")
    func testCreateEventRejectsDatetimeForAllDayEvent() {
        let harness = makeHarness()
        harness.eval("""
            hs.calendar.createEvent({
                title: 'All-day datetime must fail',
                start: '2026-07-13T00:00:00Z',
                end: '2026-07-14T00:00:00Z',
                allDay: true
            })
            """)

        #expect(harness.hasException)
        #expect(harness.exceptionMessage?.contains("date-only YYYY-MM-DD") == true)
    }

    @Test("createEvent rejects recurrence authoring")
    func testCreateEventRejectsRecurrence() {
        let harness = makeHarness()
        harness.eval("""
            hs.calendar.createEvent({
                title: 'Recurring Event must fail',
                start: '2026-07-13T01:00:00Z',
                end: '2026-07-13T02:00:00Z',
                recurrence: { frequency: 'weekly' }
            })
            """)

        #expect(harness.hasException)
        #expect(harness.exceptionMessage?.contains("recurring Event creation is not supported") == true)
    }

    @Test("createEvent rejects alarms that are not minutes before the Event")
    func testCreateEventRejectsNegativeAlarm() {
        let harness = makeHarness()
        harness.eval("""
            hs.calendar.createEvent({
                title: 'Invalid alarm must fail',
                start: '2026-07-13T01:00:00Z',
                end: '2026-07-13T02:00:00Z',
                alarms: [-10]
            })
            """)

        #expect(harness.hasException)
        #expect(harness.exceptionMessage?.contains("non-negative minutes-before") == true)
    }

    @Test("createEvent rejects an alarms array with an absurd length")
    func testCreateEventRejectsHugeSparseAlarmArray() {
        let harness = makeHarness()
        harness.eval("""
            const alarms = []
            alarms.length = 2147483648
            hs.calendar.createEvent({
                title: 'Huge sparse alarms array must fail',
                start: '2026-07-13T01:00:00Z',
                end: '2026-07-13T02:00:00Z',
                alarms
            })
            """)

        #expect(harness.hasException)
        #expect(harness.exceptionMessage?.contains("array of non-negative minutes-before numbers") == true)
    }
}

@Suite(
    "hs.calendar live tests",
    .serialized,
    .disabled(if: !hasCalendarModuleFullAccess(), "Calendar full access is not granted")
)
struct HSCalendarLiveTests {
    private func makeThrowawayCalendar(
        in eventStore: EKEventStore,
        named name: String
    ) throws -> EKCalendar {
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = name
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

    @Test("authorizationStatus reports fullAccess when Calendar access is granted")
    func testAuthorizationStatusReportsFullAccess() {
        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.expectEqual("hs.calendar.authorizationStatus()", "fullAccess")
    }

    @Test("listCalendars returns Calendar summary objects")
    func testListCalendarsReturnsCalendarSummaries() throws {
        let eventStore = HSEventStore.shared.eventStore
        let testCalendar = try makeThrowawayCalendar(
            in: eventStore,
            named: "Hammerspoon 2 listCalendars test \(UUID().uuidString)"
        )
        defer {
            removeThrowawayCalendar(testCalendar, from: eventStore)
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

    @Test("createEvent writes a timed Event and returns the alarms EventKit persisted")
    func testCreateTimedEventByCalendarID() throws {
        let eventStore = HSEventStore.shared.eventStore
        let testCalendar = try makeThrowawayCalendar(
            in: eventStore,
            named: "Hammerspoon 2 createEvent timed test \(UUID().uuidString)"
        )
        defer {
            removeThrowawayCalendar(testCalendar, from: eventStore)
        }

        let eventTitle = "Hammerspoon 2 timed Event \(UUID().uuidString)"
        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(testCalendar.calendarIdentifier, forKeyedSubscript: "testCalendarID" as NSString)
        harness.context.setObject(eventTitle, forKeyedSubscript: "testEventTitle" as NSString)
        harness.eval("""
            createdEvent = hs.calendar.createEvent({
                calendar: testCalendarID,
                title: testEventTitle,
                start: '2036-02-03T09:00:00+08:00',
                end: '2036-02-03T10:30:00+08:00',
                location: 'Test Room',
                notes: 'Created by the hs.calendar live suite',
                url: 'https://example.com/calendar-test',
                alarms: [10, 60]
            })
            """)
        #expect(!harness.hasException, "createEvent threw: \(harness.exceptionMessage ?? "unknown error")")
        harness.expectTrue("""
            createdEvent &&
            typeof createdEvent.id === 'string' && createdEvent.id.length > 0 &&
            createdEvent.title === testEventTitle &&
            createdEvent.start === '2036-02-03T01:00:00.000Z' &&
            createdEvent.end === '2036-02-03T02:30:00.000Z' &&
            createdEvent.allDay === false &&
            createdEvent.location === 'Test Room' &&
            createdEvent.notes === 'Created by the hs.calendar live suite' &&
            createdEvent.url === 'https://example.com/calendar-test' &&
            Array.isArray(createdEvent.alarms)
            """)

        let eventID = try #require(harness.eval("createdEvent.id") as? String)
        let persisted = try #require(eventStore.calendarItem(withIdentifier: eventID) as? EKEvent)
        let persistedAlarmMinutes = (persisted.alarms ?? [])
            .map { -$0.relativeOffset / 60 }
            .sorted()
        #expect(persisted.calendar.calendarIdentifier == testCalendar.calendarIdentifier)
        #expect(persisted.title == eventTitle)
        #expect(!persistedAlarmMinutes.isEmpty)

        harness.context.setObject(
            persistedAlarmMinutes,
            forKeyedSubscript: "persistedAlarmMinutes" as NSString
        )
        harness.expectTrue("""
            JSON.stringify([...createdEvent.alarms].sort((a, b) => a - b)) ===
            JSON.stringify(persistedAlarmMinutes)
            """)
    }

    @Test("createEvent resolves a Calendar title and round-trips all-day dates")
    func testCreateAllDayEventByCalendarTitle() throws {
        let eventStore = HSEventStore.shared.eventStore
        let testCalendar = try makeThrowawayCalendar(
            in: eventStore,
            named: "Hammerspoon 2 createEvent all-day test \(UUID().uuidString)"
        )
        defer {
            removeThrowawayCalendar(testCalendar, from: eventStore)
        }

        let eventTitle = "Hammerspoon 2 all-day Event \(UUID().uuidString)"
        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(testCalendar.title, forKeyedSubscript: "testCalendarTitle" as NSString)
        harness.context.setObject(eventTitle, forKeyedSubscript: "testEventTitle" as NSString)
        harness.eval("""
            createdEvent = hs.calendar.createEvent({
                calendar: testCalendarTitle,
                title: testEventTitle,
                start: '2036-02-03',
                end: '2036-02-04',
                allDay: true
            })
            """)
        #expect(!harness.hasException, "createEvent threw: \(harness.exceptionMessage ?? "unknown error")")
        harness.expectTrue("""
            createdEvent &&
            createdEvent.title === testEventTitle &&
            createdEvent.start === '2036-02-03' &&
            createdEvent.end === '2036-02-04' &&
            createdEvent.allDay === true &&
            createdEvent.location === null &&
            createdEvent.notes === null &&
            createdEvent.url === null &&
            Array.isArray(createdEvent.alarms) && createdEvent.alarms.length === 0
            """)

        let eventID = try #require(harness.eval("createdEvent.id") as? String)
        let persisted = try #require(eventStore.calendarItem(withIdentifier: eventID) as? EKEvent)
        #expect(persisted.calendar.calendarIdentifier == testCalendar.calendarIdentifier)
        #expect(persisted.isAllDay)
    }

    @Test("createEvent reports every candidate when a Calendar title is ambiguous")
    func testCreateEventRejectsAmbiguousCalendarTitle() throws {
        let eventStore = HSEventStore.shared.eventStore
        let sharedTitle = "Hammerspoon 2 ambiguous Calendar test \(UUID().uuidString)"
        let firstCalendar = try makeThrowawayCalendar(in: eventStore, named: sharedTitle)
        defer {
            removeThrowawayCalendar(firstCalendar, from: eventStore)
        }
        let secondCalendar = try makeThrowawayCalendar(in: eventStore, named: sharedTitle)
        defer {
            removeThrowawayCalendar(secondCalendar, from: eventStore)
        }

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(sharedTitle, forKeyedSubscript: "ambiguousCalendarTitle" as NSString)
        harness.eval("""
            hs.calendar.createEvent({
                calendar: ambiguousCalendarTitle,
                title: 'Must not be created',
                start: '2036-02-03T01:00:00Z',
                end: '2036-02-03T02:00:00Z'
            })
            """)

        #expect(harness.hasException)
        let message = try #require(harness.exceptionMessage)
        #expect(message.contains("ambiguous"))
        #expect(message.contains(firstCalendar.calendarIdentifier))
        #expect(message.contains(secondCalendar.calendarIdentifier))
    }
}
