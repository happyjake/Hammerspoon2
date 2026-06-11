//
//  HSAppEntrySwitcherCopyTests.swift
//  Hammerspoon 2Tests
//
//  Created by Claude on 11/06/2026.
//

import Testing
import Foundation
import ApplicationServices
import AXSwift
@testable import Hammerspoon_2

/// The switcher must not show "(untitled)" ghost rows (the Finder desktop, an
/// app's helper/ghost surfaces). `switcherDisplayCopy()` drops windows with no
/// usable title — unless their subrole positively read `.standardWindow`
/// (WeChat's main window is real, standard, and genuinely untitled) — while
/// reusing the real window references so commit still works.
@Suite("HSAppEntry switcher display copy")
@MainActor
struct HSAppEntrySwitcherCopyTests {

    private func window(_ title: String, id: UInt64, subrole: Role.Subrole? = nil) -> HSWindowEntry {
        HSWindowEntry(stableID: id,
                      axElement: UIElement(AXUIElementCreateSystemWide()),
                      title: title,
                      subrole: subrole)
    }

    private func app(_ titles: [String]) -> HSAppEntry {
        let a = HSAppEntry(testOnlyName: "Ghostty", pid: 4242)
        for (i, t) in titles.enumerated() { a.windows.append(window(t, id: UInt64(100 + i))) }
        return a
    }

    @Test("untitled and whitespace-only windows are dropped, titled ones kept in order")
    func testDropsUntitled() {
        let copy = app(["Real One", "", "  ", "Real Two"]).switcherDisplayCopy()
        #expect(copy.windows.map(\.title) == ["Real One", "Real Two"])
    }

    @Test("an app whose only window is untitled (e.g. Finder desktop) becomes window-less")
    func testAllUntitledBecomesEmpty() {
        let copy = app([""]).switcherDisplayCopy()
        #expect(copy.windows.isEmpty)
    }

    @Test("an untitled window whose subrole positively read standard stays pickable (WeChat main window)")
    func testUntitledStandardWindowKept() {
        let a = HSAppEntry(testOnlyName: "WeChat", pid: 4243)
        a.windows.append(window("", id: 200, subrole: .standardWindow))
        a.windows.append(window("", id: 201))                       // ghost: untitled, subrole never read
        let copy = a.switcherDisplayCopy()
        #expect(copy.windows.map(\.stableID) == [200])
    }

    @Test("a non-standard positively-read subrole does not rescue an untitled window")
    func testUntitledDialogStillDropped() {
        let a = HSAppEntry(testOnlyName: "Ghostty", pid: 4244)
        a.windows.append(window("", id: 300, subrole: .dialog))
        #expect(a.switcherDisplayCopy().windows.isEmpty)
    }

    @Test("reuses the original window references so commit targets the real window")
    func testReusesWindowRefs() {
        let original = app(["Keep"])
        let keptID = original.windows[0].stableID
        let copy = original.switcherDisplayCopy()
        #expect(copy.windows.count == 1)
        #expect(copy.windows[0].stableID == keptID)
        #expect(copy.windows[0] === original.windows[0])
    }

    @Test("app metadata is preserved")
    func testMetadataPreserved() {
        let copy = app(["x"]).switcherDisplayCopy()
        #expect(copy.name == "Ghostty")
        #expect(copy.pid == 4242)
        #expect(copy.isSwitchable == true)
    }
}
