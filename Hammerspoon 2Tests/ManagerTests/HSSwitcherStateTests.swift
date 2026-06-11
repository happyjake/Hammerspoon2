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
