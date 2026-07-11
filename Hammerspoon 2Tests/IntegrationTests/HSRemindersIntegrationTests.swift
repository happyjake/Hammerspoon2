//
//  HSRemindersIntegrationTests.swift
//  Hammerspoon 2Tests
//

import EventKit
import Testing
@testable import Hammerspoon_2

private nonisolated func hasRemindersModuleFullAccess() -> Bool {
    EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
}

@Suite("hs.reminders API structure tests")
struct HSRemindersIntegrationTests {
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSRemindersModule.self, as: "reminders")
        return harness
    }

    @Test("hs.reminders is registered on the module root")
    func testModuleRootRegistration() {
        let harness = JSTestHarness()
        harness.loadModuleRoot()
        harness.expectTrue("typeof hs.reminders === 'object'")
    }

    @Test("authorizationStatus is a function")
    func testAuthorizationStatusIsFunction() {
        makeHarness().expectTrue("typeof hs.reminders.authorizationStatus === 'function'")
    }

    @Test("authorizationStatus returns a documented Reminders status")
    func testAuthorizationStatusReturnsDocumentedStatus() {
        makeHarness().expectTrue("['fullAccess', 'denied', 'restricted', 'notDetermined'].includes(hs.reminders.authorizationStatus())")
    }

    @Test("listReminderLists is a function that returns an array")
    func testListReminderListsIsFunctionReturningArray() {
        makeHarness().expectTrue("""
            typeof hs.reminders.listReminderLists === 'function' &&
            Array.isArray(hs.reminders.listReminderLists())
            """)
    }

    @Test("listReminders is a function that returns a Promise")
    func testListRemindersIsFunctionReturningPromise() {
        makeHarness().expectTrue("""
            typeof hs.reminders.listReminders === 'function' &&
            typeof hs.reminders.listReminders().then === 'function'
            """)
    }

    @Test("createReminder is a function")
    func testCreateReminderIsFunction() {
        makeHarness().expectTrue("typeof hs.reminders.createReminder === 'function'")
    }

    @Test("completeReminder is a function")
    func testCompleteReminderIsFunction() {
        makeHarness().expectTrue("typeof hs.reminders.completeReminder === 'function'")
    }

    @Test("deleteReminder is a function")
    func testDeleteReminderIsFunction() {
        makeHarness().expectTrue("typeof hs.reminders.deleteReminder === 'function'")
    }

    @Test("createReminder rejects a timed due value without an offset")
    func testCreateReminderRejectsNakedTimedDue() {
        let harness = makeHarness()
        harness.eval("""
            var nakedDueError = null
            try {
                hs.reminders.createReminder({
                    title: 'Invalid due fixture',
                    due: '2026-07-14T15:30:00'
                })
            } catch (error) {
                nakedDueError = String(error)
            }
            """)
        harness.expectTrue("""
            nakedDueError !== null &&
            nakedDueError.includes('explicit offset or Z')
            """)
    }
}

@Suite(
    "hs.reminders live CRUD tests",
    .serialized,
    .disabled(if: !hasRemindersModuleFullAccess(), "Reminders full access is not granted")
)
struct HSRemindersLiveAuthorizationTests {
    @Test("authorizationStatus reports fullAccess when Reminders access is granted")
    func testAuthorizationStatusReportsFullAccess() {
        let harness = JSTestHarness()
        harness.loadModule(HSRemindersModule.self, as: "reminders")
        harness.expectEqual("hs.reminders.authorizationStatus()", "fullAccess")
    }

    @Test("listReminderLists returns the exact throwaway Reminder List summary")
    func testListReminderListsReturnsReminderListSummaries() throws {
        let eventStore = HSEventStore.shared.eventStore
        let testList = EKCalendar(for: .reminder, eventStore: eventStore)
        testList.title = "Hammerspoon 2 listReminderLists test \(UUID().uuidString)"
        testList.source = try #require(
            eventStore.defaultCalendarForNewReminders()?.source ??
                eventStore.sources.first(where: { $0.sourceType == .local }),
            "A writable Reminder List source is required for the live test"
        )

        try eventStore.saveCalendar(testList, commit: true)
        defer {
            do {
                try eventStore.removeCalendar(testList, commit: true)
            } catch {
                Issue.record("Could not remove the live-test Reminder List: \(error)")
            }
        }

        let harness = JSTestHarness()
        harness.loadModule(HSRemindersModule.self, as: "reminders")
        harness.context.setObject(testList.calendarIdentifier, forKeyedSubscript: "testListID" as NSString)
        harness.context.setObject(testList.title, forKeyedSubscript: "testListTitle" as NSString)
        harness.expectTrue("""
            (() => {
                const lists = hs.reminders.listReminderLists()
                const list = lists.find(item => item.id === testListID)
                return list !== undefined &&
                    list.title === testListTitle &&
                    typeof list.id === 'string' &&
                    typeof list.title === 'string' &&
                    typeof list.writable === 'boolean' &&
                    typeof list.isDefault === 'boolean'
            })()
            """)
    }

    @Test("listReminders returns the exact seeded incomplete Reminder")
    @MainActor
    func testListRemindersReturnsSeededIncompleteReminder() async throws {
        let eventStore = HSEventStore.shared.eventStore
        let testList = EKCalendar(for: .reminder, eventStore: eventStore)
        testList.title = "Hammerspoon 2 listReminders test \(UUID().uuidString)"
        testList.source = try #require(
            eventStore.defaultCalendarForNewReminders()?.source ??
                eventStore.sources.first(where: { $0.sourceType == .local }),
            "A writable Reminder List source is required for the live test"
        )
        try eventStore.saveCalendar(testList, commit: true)
        defer {
            do {
                try eventStore.removeCalendar(testList, commit: true)
            } catch {
                Issue.record("Could not remove the live-test Reminder List: \(error)")
            }
        }

        let testReminder = EKReminder(eventStore: eventStore)
        testReminder.calendar = testList
        testReminder.title = "Seeded incomplete Reminder \(UUID().uuidString)"
        testReminder.notes = "known fixture notes"
        testReminder.priority = 1
        try eventStore.save(testReminder, commit: true)

        let harness = JSTestHarness()
        harness.loadModule(HSRemindersModule.self, as: "reminders")
        harness.context.setObject(testList.calendarIdentifier, forKeyedSubscript: "testListID" as NSString)
        harness.context.setObject(testReminder.calendarItemIdentifier, forKeyedSubscript: "testReminderID" as NSString)
        harness.context.setObject(testReminder.title, forKeyedSubscript: "testReminderTitle" as NSString)
        harness.eval("""
            var listedReminders = null
            var listRemindersError = null
            var listRemindersDone = false
            hs.reminders.listReminders(testListID).then(function(reminders) {
                listedReminders = reminders
                listRemindersDone = true
            }).catch(function(error) {
                listRemindersError = String(error)
                listRemindersDone = true
            })
            """)

        let completed = await harness.waitForAsync(timeout: 5.0) {
            harness.eval("listRemindersDone") as? Bool ?? false
        }
        #expect(completed, "listReminders did not settle within 5 seconds")
        harness.expectTrue("listRemindersError === null")
        harness.expectTrue("""
            (() => {
                const reminder = listedReminders.find(item => item.id === testReminderID)
                return reminder !== undefined &&
                    reminder.title === testReminderTitle &&
                    reminder.listId === testListID &&
                    reminder.listTitle.length > 0 &&
                    reminder.notes === 'known fixture notes' &&
                    reminder.priority === 'high' &&
                    reminder.due === null &&
                    reminder.completed === false &&
                    reminder.completionDate === null
            })()
            """)
    }

    @Test("createReminder round-trips a high-priority date-only Reminder")
    @MainActor
    func testCreateReminderRoundTripsDateOnlyAndPriority() async throws {
        let eventStore = HSEventStore.shared.eventStore
        let testList = EKCalendar(for: .reminder, eventStore: eventStore)
        testList.title = "Hammerspoon 2 createReminder test \(UUID().uuidString)"
        testList.source = try #require(
            eventStore.defaultCalendarForNewReminders()?.source ??
                eventStore.sources.first(where: { $0.sourceType == .local }),
            "A writable Reminder List source is required for the live test"
        )
        try eventStore.saveCalendar(testList, commit: true)
        defer {
            do {
                try eventStore.removeCalendar(testList, commit: true)
            } catch {
                Issue.record("Could not remove the live-test Reminder List: \(error)")
            }
        }

        let title = "Created Reminder \(UUID().uuidString)"
        let harness = JSTestHarness()
        harness.loadModule(HSRemindersModule.self, as: "reminders")
        harness.context.setObject(testList.calendarIdentifier, forKeyedSubscript: "createListID" as NSString)
        harness.context.setObject(title, forKeyedSubscript: "createReminderTitle" as NSString)
        harness.eval("""
            var createdReminder = hs.reminders.createReminder({
                list: createListID,
                title: createReminderTitle,
                due: '2026-07-14',
                priority: 'high',
                notes: 'created fixture notes'
            })
            """)
        #expect(!harness.hasException, "createReminder should not throw")
        harness.expectTrue("""
            createdReminder.id.length > 0 &&
            createdReminder.listId === createListID &&
            createdReminder.title === createReminderTitle &&
            createdReminder.due === '2026-07-14' &&
            createdReminder.priority === 'high' &&
            createdReminder.notes === 'created fixture notes' &&
            createdReminder.completed === false
            """)

        harness.eval("""
            var createdListResult = null
            var createdListDone = false
            hs.reminders.listReminders(createListID).then(function(reminders) {
                createdListResult = reminders
                createdListDone = true
            }).catch(function() { createdListDone = true })
            """)
        let completed = await harness.waitForAsync(timeout: 5.0) {
            harness.eval("createdListDone") as? Bool ?? false
        }
        #expect(completed, "listReminders did not settle within 5 seconds")
        harness.expectTrue("createdListResult.some(item => item.id === createdReminder.id && item.priority === 'high')")
    }

    @Test("completeReminder moves the exact fixture between completion filters")
    @MainActor
    func testCompleteReminderUpdatesCompletionFilters() async throws {
        let eventStore = HSEventStore.shared.eventStore
        let testList = EKCalendar(for: .reminder, eventStore: eventStore)
        testList.title = "Hammerspoon 2 completeReminder test \(UUID().uuidString)"
        testList.source = try #require(
            eventStore.defaultCalendarForNewReminders()?.source ??
                eventStore.sources.first(where: { $0.sourceType == .local }),
            "A writable Reminder List source is required for the live test"
        )
        try eventStore.saveCalendar(testList, commit: true)
        defer {
            do {
                try eventStore.removeCalendar(testList, commit: true)
            } catch {
                Issue.record("Could not remove the live-test Reminder List: \(error)")
            }
        }

        let harness = JSTestHarness()
        harness.loadModule(HSRemindersModule.self, as: "reminders")
        harness.context.setObject(testList.calendarIdentifier, forKeyedSubscript: "completeListID" as NSString)
        harness.eval("""
            var reminderToComplete = hs.reminders.createReminder({
                list: completeListID,
                title: 'Completion fixture'
            })
            var completedReminder = hs.reminders.completeReminder(reminderToComplete.id)
            """)
        #expect(!harness.hasException, "completeReminder should not throw")
        harness.expectTrue("""
            completedReminder.id === reminderToComplete.id &&
            completedReminder.completed === true &&
            /^\\d{4}-\\d{2}-\\d{2}T.*Z$/.test(completedReminder.completionDate)
            """)

        harness.eval("""
            var completionFilterResults = null
            var completionFilterError = null
            var completionFilterDone = false
            Promise.all([
                hs.reminders.listReminders(completeListID, false),
                hs.reminders.listReminders(completeListID, true)
            ]).then(function(results) {
                completionFilterResults = results
                completionFilterDone = true
            }).catch(function(error) {
                completionFilterError = String(error)
                completionFilterDone = true
            })
            """)
        let settled = await harness.waitForAsync(timeout: 5.0) {
            harness.eval("completionFilterDone") as? Bool ?? false
        }
        #expect(settled, "completion-filter queries did not settle within 5 seconds")
        harness.expectTrue("completionFilterError === null")
        harness.expectTrue("""
            !completionFilterResults[0].some(item => item.id === reminderToComplete.id) &&
            completionFilterResults[1].some(item => item.id === reminderToComplete.id && item.completed === true)
            """)
    }

    @Test("deleteReminder removes a fixture that was first observed through the public API")
    @MainActor
    func testDeleteReminderRemovesObservedFixture() async throws {
        let eventStore = HSEventStore.shared.eventStore
        let testList = EKCalendar(for: .reminder, eventStore: eventStore)
        testList.title = "Hammerspoon 2 deleteReminder test \(UUID().uuidString)"
        testList.source = try #require(
            eventStore.defaultCalendarForNewReminders()?.source ??
                eventStore.sources.first(where: { $0.sourceType == .local }),
            "A writable Reminder List source is required for the live test"
        )
        try eventStore.saveCalendar(testList, commit: true)
        defer {
            do {
                try eventStore.removeCalendar(testList, commit: true)
            } catch {
                Issue.record("Could not remove the live-test Reminder List: \(error)")
            }
        }

        let harness = JSTestHarness()
        harness.loadModule(HSRemindersModule.self, as: "reminders")
        harness.context.setObject(testList.calendarIdentifier, forKeyedSubscript: "deleteListID" as NSString)
        harness.eval("""
            var reminderToDelete = hs.reminders.createReminder({
                list: deleteListID,
                title: 'Deletion fixture'
            })
            var beforeDelete = null
            var afterDelete = null
            var deleteResult = null
            var deleteError = null
            var deleteDone = false
            hs.reminders.listReminders(deleteListID, false).then(function(reminders) {
                beforeDelete = reminders
                deleteResult = hs.reminders.deleteReminder(reminderToDelete.id)
                return hs.reminders.listReminders(deleteListID, false)
            }).then(function(reminders) {
                afterDelete = reminders
                deleteDone = true
            }).catch(function(error) {
                deleteError = String(error)
                deleteDone = true
            })
            """)

        let settled = await harness.waitForAsync(timeout: 5.0) {
            harness.eval("deleteDone") as? Bool ?? false
        }
        #expect(settled, "delete round-trip did not settle within 5 seconds")
        harness.expectTrue("deleteError === null")
        harness.expectTrue("""
            beforeDelete.some(item => item.id === reminderToDelete.id) &&
            deleteResult === true &&
            !afterDelete.some(item => item.id === reminderToDelete.id)
            """)
    }

    @Test("raw EventKit priorities are returned in friendly buckets")
    @MainActor
    func testRawPrioritiesAreBucketedOnRead() async throws {
        let eventStore = HSEventStore.shared.eventStore
        let testList = EKCalendar(for: .reminder, eventStore: eventStore)
        testList.title = "Hammerspoon 2 priority bucket test \(UUID().uuidString)"
        testList.source = try #require(
            eventStore.defaultCalendarForNewReminders()?.source ??
                eventStore.sources.first(where: { $0.sourceType == .local }),
            "A writable Reminder List source is required for the live test"
        )
        try eventStore.saveCalendar(testList, commit: true)
        defer {
            do {
                try eventStore.removeCalendar(testList, commit: true)
            } catch {
                Issue.record("Could not remove the live-test Reminder List: \(error)")
            }
        }

        var expectedBuckets: [String: String] = [:]
        for (rawPriority, bucket) in [(0, "none"), (2, "high"), (5, "medium"), (8, "low")] {
            let reminder = EKReminder(eventStore: eventStore)
            reminder.calendar = testList
            reminder.title = "Raw priority \(rawPriority) fixture \(UUID().uuidString)"
            reminder.priority = rawPriority
            try eventStore.save(reminder, commit: true)
            expectedBuckets[reminder.calendarItemIdentifier] = bucket
        }

        let harness = JSTestHarness()
        harness.loadModule(HSRemindersModule.self, as: "reminders")
        harness.context.setObject(testList.calendarIdentifier, forKeyedSubscript: "priorityListID" as NSString)
        harness.context.setObject(expectedBuckets, forKeyedSubscript: "expectedPriorityBuckets" as NSString)
        harness.eval("""
            var priorityResults = null
            var priorityError = null
            var priorityDone = false
            hs.reminders.listReminders(priorityListID, false).then(function(reminders) {
                priorityResults = reminders
                priorityDone = true
            }).catch(function(error) {
                priorityError = String(error)
                priorityDone = true
            })
            """)
        let settled = await harness.waitForAsync(timeout: 5.0) {
            harness.eval("priorityDone") as? Bool ?? false
        }
        #expect(settled, "priority query did not settle within 5 seconds")
        harness.expectTrue("priorityError === null")
        harness.expectTrue("""
            Object.keys(expectedPriorityBuckets).length === 4 &&
            Object.entries(expectedPriorityBuckets).every(function(entry) {
                return priorityResults.some(function(reminder) {
                    return reminder.id === entry[0] && reminder.priority === entry[1]
                })
            })
            """)
    }

    @Test("timed due values are accepted only as instants and returned in UTC")
    func testTimedDueRoundTripsAsUTC() throws {
        let eventStore = HSEventStore.shared.eventStore
        let testList = EKCalendar(for: .reminder, eventStore: eventStore)
        testList.title = "Hammerspoon 2 timed due test \(UUID().uuidString)"
        testList.source = try #require(
            eventStore.defaultCalendarForNewReminders()?.source ??
                eventStore.sources.first(where: { $0.sourceType == .local }),
            "A writable Reminder List source is required for the live test"
        )
        try eventStore.saveCalendar(testList, commit: true)
        defer {
            do {
                try eventStore.removeCalendar(testList, commit: true)
            } catch {
                Issue.record("Could not remove the live-test Reminder List: \(error)")
            }
        }

        let harness = JSTestHarness()
        harness.loadModule(HSRemindersModule.self, as: "reminders")
        harness.context.setObject(testList.calendarIdentifier, forKeyedSubscript: "timedDueListID" as NSString)
        harness.eval("""
            var timedDueReminder = hs.reminders.createReminder({
                list: timedDueListID,
                title: 'Timed due fixture',
                due: '2026-07-14T15:30:00+08:00'
            })
            """)
        #expect(!harness.hasException, "strict timed due should be accepted")
        harness.expectTrue("timedDueReminder.due === '2026-07-14T07:30:00Z'")
    }

    @Test("an ambiguous Reminder List title reports every candidate id")
    func testAmbiguousReminderListTitleReportsCandidates() throws {
        let eventStore = HSEventStore.shared.eventStore
        let sharedTitle = "Hammerspoon 2 ambiguous list \(UUID().uuidString)"
        let firstList = EKCalendar(for: .reminder, eventStore: eventStore)
        let secondList = EKCalendar(for: .reminder, eventStore: eventStore)
        let source = try #require(
            eventStore.defaultCalendarForNewReminders()?.source ??
                eventStore.sources.first(where: { $0.sourceType == .local }),
            "A writable Reminder List source is required for the live test"
        )
        firstList.title = sharedTitle
        firstList.source = source
        secondList.title = sharedTitle
        secondList.source = source
        try eventStore.saveCalendar(firstList, commit: true)
        try eventStore.saveCalendar(secondList, commit: true)
        defer {
            for list in [firstList, secondList] {
                do {
                    try eventStore.removeCalendar(list, commit: true)
                } catch {
                    Issue.record("Could not remove an ambiguous live-test Reminder List: \(error)")
                }
            }
        }

        let harness = JSTestHarness()
        harness.loadModule(HSRemindersModule.self, as: "reminders")
        harness.context.setObject(sharedTitle, forKeyedSubscript: "ambiguousListTitle" as NSString)
        harness.context.setObject(firstList.calendarIdentifier, forKeyedSubscript: "firstAmbiguousListID" as NSString)
        harness.context.setObject(secondList.calendarIdentifier, forKeyedSubscript: "secondAmbiguousListID" as NSString)
        harness.eval("""
            var ambiguousListError = null
            try {
                hs.reminders.createReminder({
                    list: ambiguousListTitle,
                    title: 'Must not be created'
                })
            } catch (error) {
                ambiguousListError = String(error)
            }
            """)
        harness.expectTrue("""
            ambiguousListError !== null &&
            ambiguousListError.includes('ambiguous') &&
            ambiguousListError.includes(firstAmbiguousListID) &&
            ambiguousListError.includes(secondAmbiguousListID)
            """)
    }

    @Test("omitting list creates in the default Reminder List")
    func testOmittedListUsesDefaultReminderList() throws {
        let eventStore = HSEventStore.shared.eventStore
        let defaultList = try #require(
            eventStore.defaultCalendarForNewReminders(),
            "A default Reminder List is required for the live test"
        )
        let title = "Hammerspoon 2 default-list Reminder \(UUID().uuidString)"
        var createdIdentifier: String?
        defer {
            if let createdIdentifier,
               let reminder = eventStore.calendarItem(withIdentifier: createdIdentifier) as? EKReminder {
                do {
                    try eventStore.remove(reminder, commit: true)
                } catch {
                    Issue.record("Could not remove the live-test Reminder from the default list: \(error)")
                }
            }
        }

        let harness = JSTestHarness()
        harness.loadModule(HSRemindersModule.self, as: "reminders")
        harness.context.setObject(defaultList.calendarIdentifier, forKeyedSubscript: "defaultListID" as NSString)
        harness.context.setObject(title, forKeyedSubscript: "defaultListReminderTitle" as NSString)
        harness.eval("""
            var defaultListReminder = hs.reminders.createReminder({
                title: defaultListReminderTitle
            })
            """)
        #expect(!harness.hasException, "createReminder without a list should not throw")
        createdIdentifier = harness.eval("defaultListReminder.id") as? String
        harness.expectTrue("""
            defaultListReminder.id.length > 0 &&
            defaultListReminder.title === defaultListReminderTitle &&
            defaultListReminder.listId === defaultListID
            """)
    }
}
