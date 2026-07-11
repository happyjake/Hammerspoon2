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
    try makeThrowawayCalendar(
        in: eventStore,
        named: "Hammerspoon 2 \(purpose) \(UUID().uuidString)"
    )
}

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

    @Test("Event query windows reject ranges longer than four years")
    func testEventQueriesRejectWindowsLongerThanFourYears() {
        makeHarness().expectTrue("""
            (() => {
                try {
                    hs.calendar.listEvents(
                        'Calendar is not consulted for invalid windows',
                        '2020-01-01T00:00:00Z',
                        '2024-01-02T00:00:00Z'
                    )
                    return false
                } catch (error) {
                    return String(error).includes('must not exceed four years')
                }
            })()
            """)
    }

    @Test("Event query windows reject impossible calendar dates")
    func testEventQueriesRejectImpossibleCalendarDates() {
        makeHarness().expectTrue("""
            (() => {
                try {
                    hs.calendar.listEvents(
                        'Calendar is not consulted for invalid dates',
                        '2026-02-30T09:00:00Z',
                        '2026-03-03T10:00:00Z'
                    )
                    return false
                } catch (error) {
                    return String(error).includes('valid ISO 8601')
                }
            })()
            """)
    }

    @Test("Event query windows reject UTC offsets beyond 14 hours")
    func testEventQueriesRejectOutOfRangeUTCOffsets() {
        makeHarness().expectTrue("""
            (() => {
                try {
                    hs.calendar.searchEvents(
                        'Calendar is not consulted for invalid dates',
                        '2026-07-12T09:00:00+15:00',
                        '2026-07-12T10:00:00Z'
                    )
                    return false
                } catch (error) {
                    return String(error).includes('valid ISO 8601')
                }
            })()
            """)
    }

    @Test("createEvent is a function")
    func testCreateEventIsFunction() {
        makeHarness().expectTrue("typeof hs.calendar.createEvent === 'function'")
    }

    @Test("updateEvent is a function")
    func testUpdateEventIsFunction() {
        makeHarness().expectTrue("typeof hs.calendar.updateEvent === 'function'")
    }

    @Test("deleteEvent is a function")
    func testDeleteEventIsFunction() {
        makeHarness().expectTrue("typeof hs.calendar.deleteEvent === 'function'")
    }

    @Test("updateEvent rejects a timed Event change without an explicit UTC offset")
    func testUpdateEventRejectsNakedDatetime() {
        let harness = makeHarness()
        harness.eval("""
            hs.calendar.updateEvent('Event lookup must not run', {
                allDay: false,
                start: '2026-07-13T09:00:00',
                end: '2026-07-13T10:00:00'
            })
            """)

        #expect(harness.hasException)
        #expect(harness.exceptionMessage?.contains("UTC offset or Z") == true)
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

    @Test("updateEvent reschedules a uniquely named fixture and updates writable fields")
    func testUpdateEventReschedulesFixture() throws {
        let eventStore = HSEventStore.shared.eventStore
        let sourceCalendar = try makeThrowawayCalendar(in: eventStore, purpose: "updateEvent source")
        defer { removeThrowawayCalendar(sourceCalendar, from: eventStore) }
        let destinationCalendar = try makeThrowawayCalendar(in: eventStore, purpose: "updateEvent destination")
        defer { removeThrowawayCalendar(destinationCalendar, from: eventStore) }

        let originalTitle = "Hammerspoon 2 updateEvent original \(UUID().uuidString)"
        let updatedTitle = "Hammerspoon 2 updateEvent updated \(UUID().uuidString)"
        let fixture = EKEvent(eventStore: eventStore)
        fixture.calendar = sourceCalendar
        fixture.title = originalTitle
        fixture.startDate = try instant("2041-05-06T01:00:00Z")
        fixture.endDate = try instant("2041-05-06T02:00:00Z")
        try eventStore.save(fixture, span: .thisEvent, commit: true)
        let fixtureID = fixture.calendarItemIdentifier

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(fixtureID, forKeyedSubscript: "fixtureEventID" as NSString)
        harness.context.setObject(updatedTitle, forKeyedSubscript: "updatedFixtureTitle" as NSString)
        harness.context.setObject(
            destinationCalendar.title,
            forKeyedSubscript: "destinationCalendarTitle" as NSString
        )
        harness.eval("""
            updatedEvent = hs.calendar.updateEvent(fixtureEventID, {
                calendar: destinationCalendarTitle,
                title: updatedFixtureTitle,
                start: '2041-05-06T12:00:00+08:00',
                end: '2041-05-06T13:30:00+08:00',
                location: 'Issue 11 update room',
                notes: 'Updated by the hs.calendar live suite',
                url: 'https://example.test/vibecast/issue-11',
                alarms: [15]
            })
            """)
        #expect(!harness.hasException, "updateEvent threw: \(harness.exceptionMessage ?? "unknown error")")
        harness.expectTrue("""
            updatedEvent &&
            typeof updatedEvent.id === 'string' && updatedEvent.id.length > 0 &&
            updatedEvent.title === updatedFixtureTitle &&
            updatedEvent.start === '2041-05-06T04:00:00.000Z' &&
            updatedEvent.end === '2041-05-06T05:30:00.000Z' &&
            updatedEvent.allDay === false &&
            updatedEvent.location === 'Issue 11 update room' &&
            updatedEvent.notes === 'Updated by the hs.calendar live suite' &&
            updatedEvent.url === 'https://example.test/vibecast/issue-11' &&
            Array.isArray(updatedEvent.alarms) && updatedEvent.alarms.length === 1 &&
            updatedEvent.alarms[0] === 15
            """)

        harness.context.setObject(
            sourceCalendar.calendarIdentifier,
            forKeyedSubscript: "sourceCalendarID" as NSString
        )
        harness.context.setObject(
            destinationCalendar.calendarIdentifier,
            forKeyedSubscript: "destinationCalendarID" as NSString
        )
        harness.context.setObject(originalTitle, forKeyedSubscript: "originalFixtureTitle" as NSString)
        harness.expectTrue("""
            (() => {
                const inDestination = hs.calendar.listEvents(
                    destinationCalendarID,
                    '2041-05-06T00:00:00Z',
                    '2041-05-07T00:00:00Z'
                ).filter(event => event.title === updatedFixtureTitle)
                const stillInSource = hs.calendar.listEvents(
                    sourceCalendarID,
                    '2041-05-06T00:00:00Z',
                    '2041-05-07T00:00:00Z'
                ).filter(event => event.title === originalFixtureTitle)
                return inDestination.length === 1 &&
                    inDestination[0].start === '2041-05-06T04:00:00Z' &&
                    inDestination[0].end === '2041-05-06T05:30:00Z' &&
                    stillInSource.length === 0
            })()
            """)

        let updatedID = try #require(harness.eval("updatedEvent.id") as? String)
        let persisted = try #require(eventStore.calendarItem(withIdentifier: updatedID) as? EKEvent)
        #expect(persisted.calendar.calendarIdentifier == destinationCalendar.calendarIdentifier)
        #expect(persisted.title == updatedTitle)
        #expect((persisted.alarms ?? []).map { -$0.relativeOffset / 60 } == [15])
    }

    @Test("updateEvent preserves omitted timezone state")
    func testUpdateEventPreservesOmittedTimezone() throws {
        let eventStore = HSEventStore.shared.eventStore
        let calendar = try makeThrowawayCalendar(in: eventStore, purpose: "updateEvent timezone preservation")
        defer { removeThrowawayCalendar(calendar, from: eventStore) }

        let originalTimeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let fixture = EKEvent(eventStore: eventStore)
        fixture.calendar = calendar
        fixture.title = "Hammerspoon 2 timezone preservation \(UUID().uuidString)"
        fixture.startDate = try instant("2041-05-07T01:00:00Z")
        fixture.endDate = try instant("2041-05-07T02:00:00Z")
        fixture.timeZone = originalTimeZone
        try eventStore.save(fixture, span: .thisEvent, commit: true)
        let fixtureID = fixture.calendarItemIdentifier
        let originalStart = fixture.startDate
        let originalEnd = fixture.endDate

        let updatedTitle = "Hammerspoon 2 timezone preserved \(UUID().uuidString)"
        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(fixtureID, forKeyedSubscript: "fixtureEventID" as NSString)
        harness.context.setObject(updatedTitle, forKeyedSubscript: "updatedFixtureTitle" as NSString)
        harness.eval("""
            hs.calendar.updateEvent(fixtureEventID, { title: updatedFixtureTitle })
            """)
        #expect(!harness.hasException, "updateEvent threw: \(harness.exceptionMessage ?? "unknown error")")

        let persisted = try #require(eventStore.calendarItem(withIdentifier: fixtureID) as? EKEvent)
        #expect(persisted.title == updatedTitle)
        #expect(persisted.timeZone?.identifier == originalTimeZone.identifier)
        #expect(persisted.startDate == originalStart)
        #expect(persisted.endDate == originalEnd)
    }

    @Test("deleteEvent removes the exact uniquely named fixture")
    func testDeleteEventRemovesFixture() throws {
        let eventStore = HSEventStore.shared.eventStore
        let calendar = try makeThrowawayCalendar(in: eventStore, purpose: "deleteEvent")
        defer { removeThrowawayCalendar(calendar, from: eventStore) }

        let fixture = EKEvent(eventStore: eventStore)
        fixture.calendar = calendar
        fixture.title = "Hammerspoon 2 deleteEvent fixture \(UUID().uuidString)"
        fixture.startDate = try instant("2041-06-07T03:00:00Z")
        fixture.endDate = try instant("2041-06-07T04:00:00Z")
        try eventStore.save(fixture, span: .thisEvent, commit: true)
        let fixtureEventID = try #require(fixture.eventIdentifier)
        let fixtureCalendarItemID = fixture.calendarItemIdentifier

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(
            calendar.calendarIdentifier,
            forKeyedSubscript: "fixtureCalendarID" as NSString
        )
        harness.context.setObject(fixtureEventID, forKeyedSubscript: "fixtureEventID" as NSString)
        harness.context.setObject(fixture.title, forKeyedSubscript: "fixtureEventTitle" as NSString)
        harness.expectTrue("""
            hs.calendar.listEvents(
                fixtureCalendarID,
                '2041-06-07T00:00:00Z',
                '2041-06-08T00:00:00Z'
            ).filter(event => event.id === fixtureEventID && event.title === fixtureEventTitle).length === 1
            """)

        harness.eval("deletedFixture = hs.calendar.deleteEvent(fixtureEventID)")
        #expect(!harness.hasException, "deleteEvent threw: \(harness.exceptionMessage ?? "unknown error")")
        harness.expectTrue("deletedFixture === true")
        #expect(eventStore.calendarItem(withIdentifier: fixtureCalendarItemID) == nil)
        harness.expectTrue("""
            !hs.calendar.listEvents(
                fixtureCalendarID,
                '2041-06-07T00:00:00Z',
                '2041-06-08T00:00:00Z'
            ).some(event => event.id === fixtureEventID || event.title === fixtureEventTitle)
            """)
    }

    @Test("updateEvent and deleteEvent reject a recurring series without changing it")
    func testRecurringSeriesMutationGuard() throws {
        let eventStore = HSEventStore.shared.eventStore
        let calendar = try makeThrowawayCalendar(in: eventStore, purpose: "recurring mutation guard")
        defer { removeThrowawayCalendar(calendar, from: eventStore) }

        let fixture = EKEvent(eventStore: eventStore)
        fixture.calendar = calendar
        fixture.title = "Hammerspoon 2 recurring mutation guard \(UUID().uuidString)"
        fixture.startDate = try instant("2041-07-08T05:00:00Z")
        fixture.endDate = try instant("2041-07-08T06:00:00Z")
        fixture.addRecurrenceRule(EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            end: EKRecurrenceEnd(occurrenceCount: 3)
        ))
        try eventStore.save(fixture, span: .thisEvent, commit: true)
        let fixtureEventID = try #require(fixture.eventIdentifier)
        let fixtureCalendarItemID = fixture.calendarItemIdentifier
        let originalTitle = try #require(fixture.title)

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(fixtureEventID, forKeyedSubscript: "recurringFixtureID" as NSString)
        harness.eval("""
            hs.calendar.updateEvent(recurringFixtureID, { title: 'Must not change the series' })
            """)
        #expect(harness.hasException)
        #expect(harness.exceptionMessage?.contains("recurring Event series editing is not supported in v1") == true)

        harness.eval("hs.calendar.deleteEvent(recurringFixtureID)")
        #expect(harness.hasException)
        #expect(harness.exceptionMessage?.contains("recurring Event series deletion is not supported in v1") == true)

        let persisted = try #require(
            eventStore.calendarItem(withIdentifier: fixtureCalendarItemID) as? EKEvent
        )
        #expect(persisted.hasRecurrenceRules)
        #expect(persisted.title == originalTitle)
    }

    @Test("updateEvent and deleteEvent report the exact unknown Event id")
    func testMutationReportsUnknownEventID() throws {
        let missingID = "Hammerspoon-2-missing-Event-\(UUID().uuidString)"
        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(missingID, forKeyedSubscript: "missingEventID" as NSString)

        harness.eval("hs.calendar.updateEvent(missingEventID, { title: 'Still missing' })")
        #expect(harness.hasException)
        let updateError = try #require(harness.exceptionMessage)
        #expect(updateError.contains("was not found"))
        #expect(updateError.contains(missingID))

        harness.eval("hs.calendar.deleteEvent(missingEventID)")
        #expect(harness.hasException)
        let deleteError = try #require(harness.exceptionMessage)
        #expect(deleteError.contains("was not found"))
        #expect(deleteError.contains(missingID))
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
