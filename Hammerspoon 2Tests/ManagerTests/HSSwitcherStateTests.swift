//
//  HSSwitcherStateTests.swift
//  Hammerspoon 2Tests
//
//  Created by Claude on 11/06/2026.
//

import Testing
import Foundation
import ApplicationServices
import AXSwift
@testable import Hammerspoon_2

/// Unit tests for the switcher's selection state machine — pure logic, no AX
/// reads, no UI. Window entries carry a dummy AXUIElement that is never
/// dereferenced by the state layer.
@Suite("HSSwitcherState linear navigation")
@MainActor
struct HSSwitcherStateLinearNavTests {

    private func makeApp(_ name: String, pid: pid_t, windowTitles: [String]) -> HSAppEntry {
        let app = HSAppEntry(testOnlyName: name, pid: pid)
        for (i, title) in windowTitles.enumerated() {
            app.windows.append(HSWindowEntry(
                stableID: UInt64(pid) * 100 + UInt64(i),
                axElement: UIElement(AXUIElementCreateSystemWide()),
                title: title
            ))
        }
        return app
    }

    /// Alpha(2 windows), Beta(0 windows), Gamma(1 window) — the flat row list
    /// is: (0,0) (0,1) (1,-1) (2,0).
    private func makeState() -> HSSwitcherState {
        let state = HSSwitcherState()
        state.apps = [
            makeApp("Alpha", pid: 100, windowTitles: ["a1", "a2"]),
            makeApp("Beta", pid: 200, windowTitles: []),
            makeApp("Gamma", pid: 300, windowTitles: ["g1"]),
        ]
        return state
    }

    @Test("down walks windows, windowless app headers, and wraps")
    func testDownTraversesFlatList() {
        let state = makeState()
        state.selectedAppIndex = 0
        state.selectedWindowIndex = 0

        state.moveLinearSelection(by: 1)
        #expect(state.selectedAppIndex == 0 && state.selectedWindowIndex == 1)

        state.moveLinearSelection(by: 1)   // crosses into windowless Beta
        #expect(state.selectedAppIndex == 1 && state.selectedWindowIndex == -1)

        state.moveLinearSelection(by: 1)   // crosses into Gamma's first window
        #expect(state.selectedAppIndex == 2 && state.selectedWindowIndex == 0)

        state.moveLinearSelection(by: 1)   // wraps to the top
        #expect(state.selectedAppIndex == 0 && state.selectedWindowIndex == 0)
    }

    @Test("up from the first row wraps to the last row")
    func testUpWraps() {
        let state = makeState()
        state.selectedAppIndex = 0
        state.selectedWindowIndex = 0

        state.moveLinearSelection(by: -1)
        #expect(state.selectedAppIndex == 2 && state.selectedWindowIndex == 0)

        state.moveLinearSelection(by: -1)
        #expect(state.selectedAppIndex == 1 && state.selectedWindowIndex == -1)
    }

    @Test("unset selection lands on first row going down, last row going up")
    func testUnsetSelection() {
        let down = makeState()
        down.moveLinearSelection(by: 1)
        #expect(down.selectedAppIndex == 0 && down.selectedWindowIndex == 0)

        let up = makeState()
        up.moveLinearSelection(by: -1)
        #expect(up.selectedAppIndex == 2 && up.selectedWindowIndex == 0)
    }

    @Test("linear movement respects the active filter")
    func testFilterNarrowsTraversal() {
        let state = makeState()
        state.mode = .filter
        state.filterText = "gam"          // only Gamma matches
        state.selectedAppIndex = 0        // index into filteredApps() == [Gamma]
        state.selectedWindowIndex = 0

        state.moveLinearSelection(by: 1)  // only one row → stays put (wraps onto itself)
        #expect(state.selectedAppIndex == 0 && state.selectedWindowIndex == 0)
    }

    @Test("empty app list is a no-op")
    func testEmptyList() {
        let state = HSSwitcherState()
        state.moveLinearSelection(by: 1)
        #expect(state.selectedAppIndex == -1 && state.selectedWindowIndex == -1)
    }
}

/// Browser-tab rows in the switcher: tabs extend an app's row list after its
/// windows; selection, traversal, filtering and the visible cap all treat
/// them as first-class rows.
@Suite("HSSwitcherState browser-tab rows")
@MainActor
struct HSSwitcherStateTabTests {

    private func makeApp(_ name: String, pid: pid_t, windowTitles: [String],
                         tabs: [(String, String)] = []) -> HSAppEntry {
        let app = HSAppEntry(testOnlyName: name, pid: pid)
        for (i, title) in windowTitles.enumerated() {
            app.windows.append(HSWindowEntry(
                stableID: UInt64(pid) * 100 + UInt64(i),
                axElement: UIElement(AXUIElementCreateSystemWide()),
                title: title
            ))
        }
        app.switcherTabs = tabs.enumerated().map { i, t in
            HSSwitcherTab(title: t.0, url: t.1, windowIndex: 1, tabIndex: i + 1)
        }
        return app
    }

    /// Safari(1 window, 2 tabs), Notes(1 window). Flat rows:
    /// (0,0)=win (0,1)=tab1 (0,2)=tab2 (1,0)=win.
    private func makeState() -> HSSwitcherState {
        let state = HSSwitcherState()
        state.apps = [
            makeApp("Safari", pid: 100, windowTitles: ["Gmail"],
                    tabs: [("Hacker News", "https://news.ycombinator.com/"),
                           ("Docs", "https://docs.example/")]),
            makeApp("Notes", pid: 200, windowTitles: ["My Note"]),
        ]
        return state
    }

    @Test("linear traversal walks windows, then tabs, then the next app")
    func testLinearWalksTabs() {
        let state = makeState()
        state.selectedAppIndex = 0
        state.selectedWindowIndex = 0

        state.moveLinearSelection(by: 1)
        #expect(state.selectedAppIndex == 0 && state.selectedWindowIndex == 1)   // tab 1
        state.moveLinearSelection(by: 1)
        #expect(state.selectedAppIndex == 0 && state.selectedWindowIndex == 2)   // tab 2
        state.moveLinearSelection(by: 1)
        #expect(state.selectedAppIndex == 1 && state.selectedWindowIndex == 0)   // Notes window
        state.moveLinearSelection(by: 1)
        #expect(state.selectedAppIndex == 0 && state.selectedWindowIndex == 0)   // wrap
    }

    @Test("currentSelection returns the tab for tab rows")
    func testCurrentSelectionTab() {
        let state = makeState()
        state.selectedAppIndex = 0
        state.selectedWindowIndex = 1
        let sel = state.currentSelection()
        #expect(sel?.window == nil)
        #expect(sel?.tab?.title == "Hacker News")
        #expect(sel?.tab?.tabIndex == 1)
    }

    @Test("within-app movement wraps across windows and tabs")
    func testWindowAxisWrapsOverTabs() {
        let state = makeState()
        state.selectedAppIndex = 0
        state.selectedWindowIndex = 2
        state.moveWindowSelection(by: 1)
        #expect(state.selectedWindowIndex == 0)   // wraps back to the window
        state.moveWindowSelection(by: -1)
        #expect(state.selectedWindowIndex == 2)   // and back onto the last tab
    }

    @Test("filter matches apps by tab title")
    func testFilterMatchesTabTitle() {
        let state = makeState()
        state.mode = .filter
        state.filterText = "hacker"
        let apps = state.filteredApps()
        #expect(apps.count == 1)
        #expect(apps.first?.name == "Safari")
        // And only the matching tab is a visible row while filtering.
        let tabs = state.visibleTabs(for: apps[0])
        #expect(tabs.count == 1)
        #expect(tabs.first?.title == "Hacker News")
    }

    @Test("app-name match keeps every tab visible while filtering")
    func testAppNameMatchShowsAllTabs() {
        let state = makeState()
        state.mode = .filter
        state.filterText = "safari"
        let apps = state.filteredApps()
        #expect(apps.count == 1)
        #expect(state.visibleTabs(for: apps[0]).count == 2)
    }

    @Test("visible tabs are capped")
    func testVisibleCap() {
        let many = (1...20).map { ("Tab \($0)", "https://x.example/\($0)") }
        let app = makeApp("Safari", pid: 100, windowTitles: ["W"], tabs: many)
        let state = HSSwitcherState()
        state.apps = [app]
        #expect(state.visibleTabs(for: app).count == HSSwitcherState.maxVisibleTabs)
        #expect(state.rowCount(for: app) == 1 + HSSwitcherState.maxVisibleTabs)
    }

    @Test("default selection ignores tabs (MRU windows first)")
    func testDefaultSelection() {
        let state = makeState()
        state.applyDefaultSelection()
        #expect(state.selectedAppIndex == 1)
        #expect(state.selectedWindowIndex == 0)
        let sel = state.currentSelection()
        #expect(sel?.window != nil && sel?.tab == nil)
    }
}
