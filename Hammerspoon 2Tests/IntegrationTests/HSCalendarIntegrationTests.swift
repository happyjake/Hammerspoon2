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

private func makeDailyRecurringEvent(
    in eventStore: EKEventStore,
    calendar: EKCalendar,
    title: String,
    start: String,
    end: String,
    count: Int = 3
) throws -> EKEvent {
    let event = EKEvent(eventStore: eventStore)
    event.calendar = calendar
    event.title = title
    event.startDate = try instant(start)
    event.endDate = try instant(end)
    event.addRecurrenceRule(EKRecurrenceRule(
        recurrenceWith: .daily,
        interval: 1,
        end: EKRecurrenceEnd(occurrenceCount: count)
    ))
    try eventStore.save(event, span: .thisEvent, commit: true)
    return event
}

private func makeDailyAllDayRecurringEvent(
    in eventStore: EKEventStore,
    calendar: EKCalendar,
    title: String,
    year: Int,
    month: Int,
    day: Int,
    count: Int = 3
) throws -> EKEvent {
    let event = EKEvent(eventStore: eventStore)
    event.calendar = calendar
    event.title = title
    event.isAllDay = true
    event.startDate = try localDate(year: year, month: month, day: day)
    event.endDate = event.startDate
    event.addRecurrenceRule(EKRecurrenceRule(
        recurrenceWith: .daily,
        interval: 1,
        end: EKRecurrenceEnd(occurrenceCount: count)
    ))
    try eventStore.save(event, span: .thisEvent, commit: true)
    return event
}

private func moveRecurringOccurrence(
    in eventStore: EKEventStore,
    calendar: EKCalendar,
    eventID: String,
    occurrenceStart: String,
    movedStart: String
) throws -> EKEvent {
    let originalOccurrenceDate = try instant(occurrenceStart)
    let predicate = eventStore.predicateForEvents(
        withStart: originalOccurrenceDate.addingTimeInterval(-1),
        end: originalOccurrenceDate.addingTimeInterval(1),
        calendars: [calendar]
    )
    let occurrence = try #require(
        eventStore.events(matching: predicate).first { event in
            event.eventIdentifier == eventID &&
                abs((event.occurrenceDate ?? event.startDate).timeIntervalSince(originalOccurrenceDate)) < 1
        },
        "Could not resolve the recurring Occurrence before moving it"
    )
    let duration = occurrence.endDate.timeIntervalSince(occurrence.startDate)
    occurrence.startDate = try instant(movedStart)
    occurrence.endDate = occurrence.startDate.addingTimeInterval(duration)
    try eventStore.save(occurrence, span: .thisEvent, commit: true)
    return occurrence
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

    // A detached Occurrence carries a `/RID=<seconds>` suffix that a read of the
    // series never reports, so a caller addressing it a second time holds only
    // the bare series identifier. These are the exact identifiers observed on an
    // iCloud calendar, before and after a `span: this` update detached it.
    @Test("a detached Occurrence identifier still resolves to its series")
    func testDetachedOccurrenceIdentifierMatchesSeries() {
        let series = "2971FDC7-B766-4146-A3C2-247CD01BB2B4:DF4BC021-4DA8-4E76-876E-29606877D68B"
        let detached = "\(series)/RID=807408000"

        #expect(HSCalendarModule.seriesIdentifier(detached) == series)
        #expect(HSCalendarModule.seriesIdentifier(series) == series)
        #expect(HSCalendarModule.isSameSeries(detached, as: series))
        #expect(HSCalendarModule.isSameSeries(series, as: series))

        // A second detached Occurrence of the SAME series also matches — the
        // ±1s occurrenceDate check is what tells the two apart, not the id.
        #expect(HSCalendarModule.isSameSeries("\(series)/RID=808012800", as: series))

        // A different series never matches, and an absent or empty identifier
        // must not match anything.
        let other = "2971FDC7-B766-4146-A3C2-247CD01BB2B4:11111111-2222-3333-4444-555555555555"
        #expect(!HSCalendarModule.isSameSeries(other, as: series))
        #expect(!HSCalendarModule.isSameSeries("\(other)/RID=807408000", as: series))
        #expect(!HSCalendarModule.isSameSeries(nil, as: series))
        #expect(!HSCalendarModule.isSameSeries("", as: series))
        #expect(!HSCalendarModule.isSameSeries(series, as: ""))

        // Only a trailing, well-formed suffix is a suffix. Anything else is part
        // of the identifier and must survive untouched, or two distinct series
        // could collapse onto one.
        for identifier in [
            "\(series)/RID=",
            "\(series)/RID=abc",
            "\(series)/RID=807408000/tail",
            "\(series)-RID=807408000",
        ] {
            #expect(HSCalendarModule.seriesIdentifier(identifier) == identifier)
            #expect(!HSCalendarModule.isSameSeries(identifier, as: series))
        }
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

    @Test("recurring mutation arguments are required together")
    func testRecurringMutationArgumentsAreRequiredTogether() {
        let harness = makeHarness()
        harness.eval("""
            hs.calendar.updateEvent(
                'Event lookup must not run',
                { title: 'Must not update' },
                '2026-07-13T02:00:00Z'
            )
            """)
        #expect(harness.hasException)
        #expect(harness.exceptionMessage?.contains("occurrenceStart and span must be supplied together") == true)

        harness.eval("""
            hs.calendar.deleteEvent(
                'Event lookup must not run',
                null,
                'future'
            )
            """)
        #expect(harness.hasException)
        #expect(harness.exceptionMessage?.contains("occurrenceStart and span must be supplied together") == true)
    }

    @Test("recurring mutation arguments require an ISO instant and an EventKit Span")
    func testRecurringMutationArgumentsRejectInvalidValues() {
        let harness = makeHarness()
        harness.eval("""
            hs.calendar.updateEvent(
                'Event lookup must not run',
                { title: 'Must not update' },
                '2026-07-13T02:00:00Z',
                'all'
            )
            """)
        #expect(harness.hasException)
        #expect(harness.exceptionMessage?.contains("'span' must be 'this' or 'future'") == true)

        // A date-only day IS a valid selector — an all-day Occurrence reports no
        // other form — so the day itself still has to be real and exactly the
        // shape a read emits.
        for occurrenceStart in ["2026-07-00", "2026-13-01", "2026-02-30", "2026-7-13", "13-07-2026"] {
            harness.eval("""
                hs.calendar.deleteEvent(
                    'Event lookup must not run',
                    '\(occurrenceStart)',
                    'this'
                )
                """)
            #expect(harness.hasException)
            #expect(harness.exceptionMessage?.contains("'occurrenceStart' must be a valid ISO 8601 instant") == true)
        }
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

    @Test("updateEvent updates an ordinary single Event")
    func testUpdateEventReschedulesSingleFixture() throws {
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
        let resolvedFixture = try #require(
            eventStore.calendarItem(withIdentifier: fixtureID) as? EKEvent
        )
        #expect(!resolvedFixture.hasRecurrenceRules)
        #expect(!resolvedFixture.isDetached)
        #expect(resolvedFixture.occurrenceDate != nil)

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

    @Test("updateEvent converts an all-day Event to exact timed instants")
    func testUpdateEventConvertsAllDayToTimed() throws {
        let eventStore = HSEventStore.shared.eventStore
        let calendar = try makeThrowawayCalendar(in: eventStore, purpose: "updateEvent all-day to timed")
        defer { removeThrowawayCalendar(calendar, from: eventStore) }

        let fixture = EKEvent(eventStore: eventStore)
        fixture.calendar = calendar
        fixture.title = "Hammerspoon 2 all-day to timed \(UUID().uuidString)"
        fixture.isAllDay = true
        fixture.startDate = try localDate(year: 2042, month: 1, day: 10)
        fixture.endDate = try localDate(year: 2042, month: 1, day: 11)
        try eventStore.save(fixture, span: .thisEvent, commit: true)
        let fixtureID = fixture.calendarItemIdentifier

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(fixtureID, forKeyedSubscript: "fixtureEventID" as NSString)
        harness.eval("""
            convertedEvent = hs.calendar.updateEvent(fixtureEventID, {
                allDay: false,
                start: '2042-01-10T09:15:00+08:00',
                end: '2042-01-10T10:45:00+08:00'
            })
            """)
        #expect(!harness.hasException, "updateEvent threw: \(harness.exceptionMessage ?? "unknown error")")
        harness.expectTrue("""
            convertedEvent &&
            convertedEvent.allDay === false &&
            convertedEvent.start === '2042-01-10T01:15:00.000Z' &&
            convertedEvent.end === '2042-01-10T02:45:00.000Z'
            """)

        let persisted = try #require(eventStore.calendarItem(withIdentifier: fixtureID) as? EKEvent)
        let expectedStart = try instant("2042-01-10T01:15:00Z")
        let expectedEnd = try instant("2042-01-10T02:45:00Z")
        #expect(!persisted.isAllDay)
        #expect(persisted.startDate == expectedStart)
        #expect(persisted.endDate == expectedEnd)
    }

    @Test("updateEvent converts a timed Event to exact all-day dates")
    func testUpdateEventConvertsTimedToAllDay() throws {
        let eventStore = HSEventStore.shared.eventStore
        let calendar = try makeThrowawayCalendar(in: eventStore, purpose: "updateEvent timed to all-day")
        defer { removeThrowawayCalendar(calendar, from: eventStore) }

        let fixture = EKEvent(eventStore: eventStore)
        fixture.calendar = calendar
        fixture.title = "Hammerspoon 2 timed to all-day \(UUID().uuidString)"
        fixture.startDate = try instant("2042-02-10T01:00:00Z")
        fixture.endDate = try instant("2042-02-10T02:00:00Z")
        fixture.timeZone = TimeZone(secondsFromGMT: 0)
        try eventStore.save(fixture, span: .thisEvent, commit: true)
        let fixtureID = fixture.calendarItemIdentifier

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(fixtureID, forKeyedSubscript: "fixtureEventID" as NSString)
        harness.eval("""
            convertedEvent = hs.calendar.updateEvent(fixtureEventID, {
                allDay: true,
                start: '2042-02-12',
                end: '2042-02-14'
            })
            """)
        #expect(!harness.hasException, "updateEvent threw: \(harness.exceptionMessage ?? "unknown error")")
        harness.expectTrue("""
            convertedEvent &&
            convertedEvent.allDay === true &&
            convertedEvent.start === '2042-02-12' &&
            convertedEvent.end === '2042-02-14'
            """)

        let persisted = try #require(eventStore.calendarItem(withIdentifier: fixtureID) as? EKEvent)
        let expectedStart = try localDate(year: 2042, month: 2, day: 12)
        let expectedEnd = try localDate(year: 2042, month: 2, day: 14)
        #expect(persisted.isAllDay)
        #expect(persisted.startDate == expectedStart)
        #expect(persisted.endDate == expectedEnd)
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

    @Test("updateEvent applies the this Span to the addressed recurring Occurrence")
    func testUpdateRecurringThisOccurrence() throws {
        let eventStore = HSEventStore.shared.eventStore
        let calendar = try makeThrowawayCalendar(in: eventStore, purpose: "update recurring this")
        defer { removeThrowawayCalendar(calendar, from: eventStore) }

        let originalTitle = "Hammerspoon 2 recurring this original \(UUID().uuidString)"
        let updatedTitle = "Hammerspoon 2 recurring this updated \(UUID().uuidString)"
        let fixture = try makeDailyRecurringEvent(
            in: eventStore,
            calendar: calendar,
            title: originalTitle,
            start: "2043-01-10T10:00:00Z",
            end: "2043-01-10T10:30:00Z"
        )
        let fixtureEventID = try #require(fixture.eventIdentifier)

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(fixtureEventID, forKeyedSubscript: "fixtureEventID" as NSString)
        harness.context.setObject(calendar.calendarIdentifier, forKeyedSubscript: "fixtureCalendarID" as NSString)
        harness.context.setObject(originalTitle, forKeyedSubscript: "originalFixtureTitle" as NSString)
        harness.context.setObject(updatedTitle, forKeyedSubscript: "updatedFixtureTitle" as NSString)
        harness.eval("""
            hs.calendar.updateEvent(
                fixtureEventID,
                { title: updatedFixtureTitle },
                '2043-01-11T10:00:00Z',
                'this'
            )
            """)
        #expect(!harness.hasException, "updateEvent threw: \(harness.exceptionMessage ?? "unknown error")")
        harness.expectTrue("""
            (() => {
                const occurrences = hs.calendar.listEvents(
                    fixtureCalendarID,
                    '2043-01-10T00:00:00Z',
                    '2043-01-14T00:00:00Z'
                ).filter(event =>
                    event.title === originalFixtureTitle ||
                    event.title === updatedFixtureTitle
                )
                const titleAt = start =>
                    occurrences.find(event => event.occurrenceStart === start)?.title
                return occurrences.length === 3 &&
                    titleAt('2043-01-10T10:00:00Z') === originalFixtureTitle &&
                    titleAt('2043-01-11T10:00:00Z') === updatedFixtureTitle &&
                    titleAt('2043-01-12T10:00:00Z') === originalFixtureTitle
            })()
            """)
    }

    // An all-day Occurrence reports `occurrenceStart` through formatEventDate as
    // a date-only day, so that day is the only value a caller can hand back.
    // Requiring an instant left every all-day Occurrence readable and
    // unmutatable; this addresses one by exactly the string a read returned.
    @Test("updateEvent addresses an all-day Occurrence by its date-only occurrenceStart")
    func testUpdateAllDayRecurringOccurrenceByDay() throws {
        let eventStore = HSEventStore.shared.eventStore
        let calendar = try makeThrowawayCalendar(in: eventStore, purpose: "update recurring all-day")
        defer { removeThrowawayCalendar(calendar, from: eventStore) }

        let originalTitle = "Hammerspoon 2 all-day recurring original \(UUID().uuidString)"
        let updatedTitle = "Hammerspoon 2 all-day recurring updated \(UUID().uuidString)"
        let fixture = try makeDailyAllDayRecurringEvent(
            in: eventStore,
            calendar: calendar,
            title: originalTitle,
            year: 2044,
            month: 3,
            day: 7
        )
        let fixtureEventID = try #require(fixture.eventIdentifier)

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(fixtureEventID, forKeyedSubscript: "fixtureEventID" as NSString)
        harness.context.setObject(calendar.calendarIdentifier, forKeyedSubscript: "fixtureCalendarID" as NSString)
        harness.context.setObject(originalTitle, forKeyedSubscript: "originalFixtureTitle" as NSString)
        harness.context.setObject(updatedTitle, forKeyedSubscript: "updatedFixtureTitle" as NSString)
        harness.eval("""
            hs.calendar.updateEvent(
                fixtureEventID,
                { title: updatedFixtureTitle },
                '2044-03-08',
                'this'
            )
            """)
        #expect(!harness.hasException, "updateEvent threw: \(harness.exceptionMessage ?? "unknown error")")
        harness.expectTrue("""
            (() => {
                const occurrences = hs.calendar.listEvents(
                    fixtureCalendarID,
                    '2044-03-01T00:00:00Z',
                    '2044-03-15T00:00:00Z'
                ).filter(event =>
                    event.title === originalFixtureTitle ||
                    event.title === updatedFixtureTitle
                )
                const titleAt = start =>
                    occurrences.find(event => event.occurrenceStart === start)?.title
                return occurrences.length === 3 &&
                    occurrences.every(event => event.allDay === true) &&
                    titleAt('2044-03-07') === originalFixtureTitle &&
                    titleAt('2044-03-08') === updatedFixtureTitle &&
                    titleAt('2044-03-09') === originalFixtureTitle
            })()
            """)
    }

    @Test("updateEvent applies the future Span from the addressed recurring Occurrence")
    func testUpdateRecurringThisAndFutureOccurrences() throws {
        let eventStore = HSEventStore.shared.eventStore
        let calendar = try makeThrowawayCalendar(in: eventStore, purpose: "update recurring future")
        defer { removeThrowawayCalendar(calendar, from: eventStore) }

        let originalTitle = "Hammerspoon 2 recurring future original \(UUID().uuidString)"
        let updatedTitle = "Hammerspoon 2 recurring future updated \(UUID().uuidString)"
        let fixture = try makeDailyRecurringEvent(
            in: eventStore,
            calendar: calendar,
            title: originalTitle,
            start: "2043-02-10T10:00:00Z",
            end: "2043-02-10T10:30:00Z"
        )
        let fixtureEventID = try #require(fixture.eventIdentifier)

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(fixtureEventID, forKeyedSubscript: "fixtureEventID" as NSString)
        harness.context.setObject(calendar.calendarIdentifier, forKeyedSubscript: "fixtureCalendarID" as NSString)
        harness.context.setObject(originalTitle, forKeyedSubscript: "originalFixtureTitle" as NSString)
        harness.context.setObject(updatedTitle, forKeyedSubscript: "updatedFixtureTitle" as NSString)
        harness.eval("""
            hs.calendar.updateEvent(
                fixtureEventID,
                { title: updatedFixtureTitle },
                '2043-02-11T10:00:00Z',
                'future'
            )
            """)
        #expect(!harness.hasException, "updateEvent threw: \(harness.exceptionMessage ?? "unknown error")")
        harness.expectTrue("""
            (() => {
                const occurrences = hs.calendar.listEvents(
                    fixtureCalendarID,
                    '2043-02-10T00:00:00Z',
                    '2043-02-14T00:00:00Z'
                ).filter(event =>
                    event.title === originalFixtureTitle ||
                    event.title === updatedFixtureTitle
                )
                const titleAt = start =>
                    occurrences.find(event => event.occurrenceStart === start)?.title
                return occurrences.length === 3 &&
                    titleAt('2043-02-10T10:00:00Z') === originalFixtureTitle &&
                    titleAt('2043-02-11T10:00:00Z') === updatedFixtureTitle &&
                    titleAt('2043-02-12T10:00:00Z') === updatedFixtureTitle
            })()
            """)
    }

    @Test("updateEvent addresses a moved detached Occurrence by its original occurrenceStart")
    func testUpdateMovedDetachedOccurrence() throws {
        let eventStore = HSEventStore.shared.eventStore
        let calendar = try makeThrowawayCalendar(in: eventStore, purpose: "update moved recurring Occurrence")
        defer { removeThrowawayCalendar(calendar, from: eventStore) }

        let originalTitle = "Hammerspoon 2 moved recurring update original \(UUID().uuidString)"
        let updatedTitle = "Hammerspoon 2 moved recurring update changed \(UUID().uuidString)"
        let fixture = try makeDailyRecurringEvent(
            in: eventStore,
            calendar: calendar,
            title: originalTitle,
            start: "2043-06-10T10:00:00Z",
            end: "2043-06-10T10:30:00Z"
        )
        let fixtureEventID = try #require(fixture.eventIdentifier)
        let originalOccurrenceStart = "2043-06-11T10:00:00Z"
        let movedStart = "2043-07-25T14:00:00Z"
        let moved = try moveRecurringOccurrence(
            in: eventStore,
            calendar: calendar,
            eventID: fixtureEventID,
            occurrenceStart: originalOccurrenceStart,
            movedStart: movedStart
        )
        let expectedOccurrenceDate = try instant(originalOccurrenceStart)
        let expectedMovedStart = try instant(movedStart)
        #expect(moved.isDetached)
        #expect(moved.occurrenceDate == expectedOccurrenceDate)
        #expect(moved.startDate == expectedMovedStart)

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(fixtureEventID, forKeyedSubscript: "fixtureEventID" as NSString)
        harness.context.setObject(calendar.calendarIdentifier, forKeyedSubscript: "fixtureCalendarID" as NSString)
        harness.context.setObject(updatedTitle, forKeyedSubscript: "updatedFixtureTitle" as NSString)
        harness.eval("""
            hs.calendar.updateEvent(
                fixtureEventID,
                { title: updatedFixtureTitle },
                '2043-06-11T10:00:00Z',
                'this'
            )
            """)
        #expect(!harness.hasException, "updateEvent threw: \(harness.exceptionMessage ?? "unknown error")")
        harness.expectTrue("""
            (() => {
                const matches = hs.calendar.listEvents(
                    fixtureCalendarID,
                    '2043-07-25T00:00:00Z',
                    '2043-07-26T00:00:00Z'
                ).filter(event =>
                    event.title === updatedFixtureTitle &&
                    event.occurrenceStart === '2043-06-11T10:00:00Z'
                )
                return matches.length === 1 &&
                    matches[0].start === '2043-07-25T14:00:00Z'
            })()
            """)
    }

    @Test("deleteEvent removes an ordinary single Event")
    func testDeleteEventRemovesSingleFixture() throws {
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
        let resolvedFixture = try #require(eventStore.event(withIdentifier: fixtureEventID))
        #expect(!resolvedFixture.hasRecurrenceRules)
        #expect(!resolvedFixture.isDetached)
        #expect(resolvedFixture.occurrenceDate != nil)

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

    @Test("deleteEvent applies the this Span to the addressed recurring Occurrence")
    func testDeleteRecurringThisOccurrence() throws {
        let eventStore = HSEventStore.shared.eventStore
        let calendar = try makeThrowawayCalendar(in: eventStore, purpose: "delete recurring this")
        defer { removeThrowawayCalendar(calendar, from: eventStore) }

        let title = "Hammerspoon 2 delete recurring this \(UUID().uuidString)"
        let fixture = try makeDailyRecurringEvent(
            in: eventStore,
            calendar: calendar,
            title: title,
            start: "2043-03-10T10:00:00Z",
            end: "2043-03-10T10:30:00Z"
        )
        let fixtureEventID = try #require(fixture.eventIdentifier)

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(fixtureEventID, forKeyedSubscript: "fixtureEventID" as NSString)
        harness.context.setObject(calendar.calendarIdentifier, forKeyedSubscript: "fixtureCalendarID" as NSString)
        harness.context.setObject(title, forKeyedSubscript: "fixtureTitle" as NSString)
        harness.eval("""
            deletedOccurrence = hs.calendar.deleteEvent(
                fixtureEventID,
                '2043-03-11T10:00:00Z',
                'this'
            )
            """)
        #expect(!harness.hasException, "deleteEvent threw: \(harness.exceptionMessage ?? "unknown error")")
        harness.expectTrue("deletedOccurrence === true")
        harness.expectTrue("""
            (() => {
                const starts = hs.calendar.listEvents(
                    fixtureCalendarID,
                    '2043-03-10T00:00:00Z',
                    '2043-03-14T00:00:00Z'
                )
                    .filter(event => event.title === fixtureTitle)
                    .map(event => event.occurrenceStart)
                    .sort()
                return JSON.stringify(starts) === JSON.stringify([
                    '2043-03-10T10:00:00Z',
                    '2043-03-12T10:00:00Z'
                ])
            })()
            """)
    }

    @Test("deleteEvent applies the future Span at the first Occurrence to remove a whole series")
    func testDeleteRecurringWholeSeries() throws {
        let eventStore = HSEventStore.shared.eventStore
        let calendar = try makeThrowawayCalendar(in: eventStore, purpose: "delete recurring whole series")
        defer { removeThrowawayCalendar(calendar, from: eventStore) }

        let title = "Hammerspoon 2 delete recurring series \(UUID().uuidString)"
        let fixture = try makeDailyRecurringEvent(
            in: eventStore,
            calendar: calendar,
            title: title,
            start: "2043-04-10T10:00:00Z",
            end: "2043-04-10T10:30:00Z"
        )
        let fixtureEventID = try #require(fixture.eventIdentifier)

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(fixtureEventID, forKeyedSubscript: "fixtureEventID" as NSString)
        harness.context.setObject(calendar.calendarIdentifier, forKeyedSubscript: "fixtureCalendarID" as NSString)
        harness.context.setObject(title, forKeyedSubscript: "fixtureTitle" as NSString)
        harness.eval("""
            deletedSeries = hs.calendar.deleteEvent(
                fixtureEventID,
                '2043-04-10T10:00:00Z',
                'future'
            )
            """)
        #expect(!harness.hasException, "deleteEvent threw: \(harness.exceptionMessage ?? "unknown error")")
        harness.expectTrue("deletedSeries === true")
        harness.expectTrue("""
            !hs.calendar.listEvents(
                fixtureCalendarID,
                '2043-04-10T00:00:00Z',
                '2043-04-14T00:00:00Z'
            ).some(event => event.title === fixtureTitle)
            """)
    }

    @Test("deleteEvent addresses a moved detached Occurrence by its original occurrenceStart")
    func testDeleteMovedDetachedOccurrence() throws {
        let eventStore = HSEventStore.shared.eventStore
        let calendar = try makeThrowawayCalendar(in: eventStore, purpose: "delete moved recurring Occurrence")
        defer { removeThrowawayCalendar(calendar, from: eventStore) }

        let title = "Hammerspoon 2 moved recurring delete \(UUID().uuidString)"
        let fixture = try makeDailyRecurringEvent(
            in: eventStore,
            calendar: calendar,
            title: title,
            start: "2043-08-10T10:00:00Z",
            end: "2043-08-10T10:30:00Z"
        )
        let fixtureEventID = try #require(fixture.eventIdentifier)
        let originalOccurrenceStart = "2043-08-11T10:00:00Z"
        let movedStart = "2043-09-25T14:00:00Z"
        let moved = try moveRecurringOccurrence(
            in: eventStore,
            calendar: calendar,
            eventID: fixtureEventID,
            occurrenceStart: originalOccurrenceStart,
            movedStart: movedStart
        )
        let expectedOccurrenceDate = try instant(originalOccurrenceStart)
        let expectedMovedStart = try instant(movedStart)
        #expect(moved.isDetached)
        #expect(moved.occurrenceDate == expectedOccurrenceDate)
        #expect(moved.startDate == expectedMovedStart)

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(fixtureEventID, forKeyedSubscript: "fixtureEventID" as NSString)
        harness.context.setObject(calendar.calendarIdentifier, forKeyedSubscript: "fixtureCalendarID" as NSString)
        harness.context.setObject(title, forKeyedSubscript: "fixtureTitle" as NSString)
        harness.eval("""
            deletedOccurrence = hs.calendar.deleteEvent(
                fixtureEventID,
                '2043-08-11T10:00:00Z',
                'this'
            )
            """)
        #expect(!harness.hasException, "deleteEvent threw: \(harness.exceptionMessage ?? "unknown error")")
        harness.expectTrue("deletedOccurrence === true")
        harness.expectTrue("""
            !hs.calendar.listEvents(
                fixtureCalendarID,
                '2043-09-25T00:00:00Z',
                '2043-09-26T00:00:00Z'
            ).some(event =>
                event.title === fixtureTitle &&
                event.occurrenceStart === '2043-08-11T10:00:00Z'
            )
            """)
        harness.expectTrue("""
            hs.calendar.listEvents(
                fixtureCalendarID,
                '2043-08-10T00:00:00Z',
                '2043-08-13T00:00:00Z'
            ).filter(event => event.title === fixtureTitle).length === 2
            """)
    }

    @Test("updateEvent and deleteEvent require an Occurrence and Span for recurring Events")
    func testRecurringMutationRequiresOccurrenceAndSpan() throws {
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
        #expect(harness.exceptionMessage?.contains("recurring Events require occurrenceStart and span") == true)

        harness.eval("hs.calendar.deleteEvent(recurringFixtureID)")
        #expect(harness.hasException)
        #expect(harness.exceptionMessage?.contains("recurring Events require occurrenceStart and span") == true)

        let persisted = try #require(
            eventStore.calendarItem(withIdentifier: fixtureCalendarItemID) as? EKEvent
        )
        #expect(persisted.hasRecurrenceRules)
        #expect(persisted.title == originalTitle)
    }

    @Test("updateEvent refuses an occurrenceStart that does not address the recurring Event")
    func testRecurringMutationRefusesUnknownOccurrence() throws {
        let eventStore = HSEventStore.shared.eventStore
        let calendar = try makeThrowawayCalendar(in: eventStore, purpose: "unknown recurring Occurrence")
        defer { removeThrowawayCalendar(calendar, from: eventStore) }

        let title = "Hammerspoon 2 unknown recurring Occurrence \(UUID().uuidString)"
        let fixture = try makeDailyRecurringEvent(
            in: eventStore,
            calendar: calendar,
            title: title,
            start: "2043-05-10T10:00:00Z",
            end: "2043-05-10T10:30:00Z"
        )
        let fixtureEventID = try #require(fixture.eventIdentifier)

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(fixtureEventID, forKeyedSubscript: "fixtureEventID" as NSString)
        harness.eval("""
            hs.calendar.updateEvent(
                fixtureEventID,
                { title: 'Must not change the series' },
                '2043-05-11T10:05:00Z',
                'this'
            )
            """)
        #expect(harness.hasException)
        let message = try #require(harness.exceptionMessage)
        #expect(message.contains("Occurrence"))
        #expect(message.contains(fixtureEventID))
        #expect(message.contains("2043-05-11T10:05:00Z"))

        let persisted = try #require(eventStore.event(withIdentifier: fixtureEventID))
        #expect(persisted.title == title)
        #expect(persisted.hasRecurrenceRules)
    }

    @Test("updateEvent and deleteEvent refuse an Occurrence and Span for a non-recurring Event")
    func testNonRecurringMutationRefusesOccurrenceAndSpan() throws {
        let eventStore = HSEventStore.shared.eventStore
        let calendar = try makeThrowawayCalendar(in: eventStore, purpose: "non-recurring mutation guard")
        defer { removeThrowawayCalendar(calendar, from: eventStore) }

        let fixture = EKEvent(eventStore: eventStore)
        fixture.calendar = calendar
        fixture.title = "Hammerspoon 2 non-recurring mutation guard \(UUID().uuidString)"
        fixture.startDate = try instant("2041-08-09T05:00:00Z")
        fixture.endDate = try instant("2041-08-09T06:00:00Z")
        try eventStore.save(fixture, span: .thisEvent, commit: true)
        let fixtureEventID = try #require(fixture.eventIdentifier)
        let fixtureCalendarItemID = fixture.calendarItemIdentifier
        let originalTitle = try #require(fixture.title)

        let harness = JSTestHarness()
        harness.loadModule(HSCalendarModule.self, as: "calendar")
        harness.context.setObject(fixtureEventID, forKeyedSubscript: "fixtureEventID" as NSString)
        harness.eval("""
            hs.calendar.updateEvent(
                fixtureEventID,
                { title: 'Must not change the Event' },
                '2041-08-09T05:00:00Z',
                'this'
            )
            """)
        #expect(harness.hasException)
        #expect(harness.exceptionMessage?.contains(
            "occurrenceStart and span are refused for non-recurring Events"
        ) == true)

        harness.eval("""
            hs.calendar.deleteEvent(
                fixtureEventID,
                '2041-08-09T05:00:00Z',
                'future'
            )
            """)
        #expect(harness.hasException)
        #expect(harness.exceptionMessage?.contains(
            "occurrenceStart and span are refused for non-recurring Events"
        ) == true)

        let persisted = try #require(
            eventStore.calendarItem(withIdentifier: fixtureCalendarItemID) as? EKEvent
        )
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
