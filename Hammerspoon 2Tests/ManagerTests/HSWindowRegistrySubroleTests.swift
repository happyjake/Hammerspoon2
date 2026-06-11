//
//  HSWindowRegistrySubroleTests.swift
//  Hammerspoon 2Tests
//
//  Created by Claude on 11/06/2026.
//

import Testing
import AXSwift
@testable import Hammerspoon_2

/// The switcher's window registry decides which windows are switch targets by
/// subrole. The decision MUST fail open on an unreadable (`nil`) subrole:
/// `.subrole` reads time out and return nil during startup seeding, and
/// rejecting nil dropped every real window — the switcher showed zero windows
/// for every app. Real windows report `.standardWindow` when readable and
/// `nil` when not; only positively-identified non-windows (the app's own
/// `.unknown` overlay panels) are dropped.
@Suite("HSWindowRegistry subrole switchability")
struct HSWindowRegistrySubroleTests {

    @Test("standard windows are switchable")
    func testStandardIsSwitchable() {
        #expect(HSWindowRegistry.isSwitchableSubrole(.standardWindow) == true)
    }

    @Test("unreadable (nil) subrole fails open — switchable")
    func testNilIsSwitchable() {
        // The regression: nil was rejected, which emptied the switcher because
        // seed-time reads time out to nil under the AX messaging timeout.
        #expect(HSWindowRegistry.isSwitchableSubrole(nil) == true)
    }

    @Test("dialog/floating windows are not dropped by the subrole gate")
    func testDialogIsSwitchable() {
        #expect(HSWindowRegistry.isSwitchableSubrole(.dialog) == true)
        #expect(HSWindowRegistry.isSwitchableSubrole(.floatingWindow) == true)
    }

    @Test("explicit AXUnknown (the app's own overlay panels) is dropped")
    func testUnknownIsNotSwitchable() {
        #expect(HSWindowRegistry.isSwitchableSubrole(.unknown) == false)
    }
}
