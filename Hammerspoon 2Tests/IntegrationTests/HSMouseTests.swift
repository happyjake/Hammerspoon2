//
//  HSMouseTests.swift
//  Hammerspoon 2Tests
//

import Testing
import JavaScriptCore
@testable import Hammerspoon_2

/// Integration tests for hs.mouse module
struct HSMouseTests {

    @Test("position() returns numeric x and y coordinates")
    func positionReturnsCoords() {
        let harness = JSTestHarness()
        harness.loadModule(HSMouseModule.self, as: "mouse")
        harness.expectTrue("typeof hs.mouse.position().x === 'number' && typeof hs.mouse.position().y === 'number'")
    }

    @Test("hideCursor, showCursor, and setAssociated return true")
    func hideShowAndAssociateReturnTrue() {
        let harness = JSTestHarness()
        harness.loadModule(HSMouseModule.self, as: "mouse")
        harness.expectTrue("hs.mouse.hideCursor() === true")
        harness.expectTrue("hs.mouse.showCursor() === true")   // restore so cursor isn't left hidden
        harness.expectTrue("hs.mouse.setAssociated(true) === true")
    }
}
