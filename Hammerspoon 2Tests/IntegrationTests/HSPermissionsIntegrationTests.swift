//
//  HSPermissionsIntegrationTests.swift
//  Hammerspoon 2Tests
//

import Testing
import EventKit
@testable import Hammerspoon_2

private nonisolated func hasCalendarFullAccess() -> Bool {
    EKEventStore.authorizationStatus(for: .event) == .fullAccess
}

private nonisolated func hasRemindersFullAccess() -> Bool {
    EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
}

@Suite("hs.permissions API structure tests")
struct HSPermissionsIntegrationTests {
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSPermissionsModule.self, as: "permissions")
        return harness
    }

    @Test("checkInputMonitoring returns a boolean")
    func testCheckInputMonitoringReturnsBoolean() {
        let h = makeHarness()
        let result = h.eval("typeof hs.permissions.checkInputMonitoring()")
        #expect(result as? String == "boolean")
    }

    @Test("requestInputMonitoring is callable without throwing")
    func testRequestInputMonitoringIsCallable() {
        let h = makeHarness()
        _ = h.eval("hs.permissions.requestInputMonitoring()")
        #expect(h.hasException == false)
    }

    @Test("Calendar permission functions exist")
    func testCalendarPermissionFunctionsExist() {
        let h = makeHarness()
        h.expectTrue("typeof hs.permissions.checkCalendar === 'function'")
        h.expectTrue("typeof hs.permissions.requestCalendar === 'function'")
    }

    @Test("checkCalendar returns a boolean without requesting access")
    func testCheckCalendarReturnsBoolean() {
        makeHarness().expectTrue("typeof hs.permissions.checkCalendar() === 'boolean'")
    }

    @Test("Reminders permission functions exist")
    func testRemindersPermissionFunctionsExist() {
        let h = makeHarness()
        h.expectTrue("typeof hs.permissions.checkReminders === 'function'")
        h.expectTrue("typeof hs.permissions.requestReminders === 'function'")
    }

    @Test("checkReminders returns a boolean without requesting access")
    func testCheckRemindersReturnsBoolean() {
        makeHarness().expectTrue("typeof hs.permissions.checkReminders() === 'boolean'")
    }
}

@Suite(
    "hs.permissions live Calendar tests",
    .serialized,
    .disabled(if: !hasCalendarFullAccess(), "Calendar full access is not granted")
)
struct HSPermissionsCalendarLiveTests {
    @Test("requestCalendar returns a Promise that resolves true when access is granted")
    func testRequestCalendarPromise() {
        let h = JSTestHarness()
        h.loadModule(HSPermissionsModule.self, as: "permissions")
        h.eval("var calendarResult; var calendarPromise = hs.permissions.requestCalendar(); calendarPromise.then(function(value) { calendarResult = value; });")

        h.expectTrue("calendarPromise instanceof Promise")
        #expect(h.waitFor(timeout: 1) { h.eval("calendarResult") as? Bool == true })
    }
}

@Suite(
    "hs.permissions live Reminders tests",
    .serialized,
    .disabled(if: !hasRemindersFullAccess(), "Reminders full access is not granted")
)
struct HSPermissionsRemindersLiveTests {
    @Test("requestReminders returns a Promise that resolves true when access is granted")
    func testRequestRemindersPromise() {
        let h = JSTestHarness()
        h.loadModule(HSPermissionsModule.self, as: "permissions")
        h.eval("var remindersResult; var remindersPromise = hs.permissions.requestReminders(); remindersPromise.then(function(value) { remindersResult = value; });")

        h.expectTrue("remindersPromise instanceof Promise")
        #expect(h.waitFor(timeout: 1) { h.eval("remindersResult") as? Bool == true })
    }
}
