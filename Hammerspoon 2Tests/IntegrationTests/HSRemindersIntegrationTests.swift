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
}

@Suite(
    "hs.reminders live authorization tests",
    .disabled(if: !hasRemindersModuleFullAccess(), "Reminders full access is not granted")
)
struct HSRemindersLiveAuthorizationTests {
    @Test("authorizationStatus reports fullAccess when Reminders access is granted")
    func testAuthorizationStatusReportsFullAccess() {
        let harness = JSTestHarness()
        harness.loadModule(HSRemindersModule.self, as: "reminders")
        harness.expectEqual("hs.reminders.authorizationStatus()", "fullAccess")
    }
}
