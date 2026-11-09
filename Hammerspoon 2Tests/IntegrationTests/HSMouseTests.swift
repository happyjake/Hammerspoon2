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

    @Test("setPosition throws TypeError for wrong-typed point and accepts valid point")
    func setPositionValidation() {
        let harness = JSTestHarness()
        harness.loadModule(HSMouseModule.self, as: "mouse")
        let result = harness.eval("""
        (function() {
            var pos = hs.mouse.position();
            var threwNonObj = false;
            var threwBadVal = false;
            try { hs.mouse.setPosition('not-a-point'); }
            catch (e) { threwNonObj = (e instanceof TypeError) && /hs\\.mouse\\.setPosition.*point/.test(e.message); }
            try { hs.mouse.setPosition({ x: 'bad', y: 10 }); }
            catch (e) { threwBadVal = (e instanceof TypeError) && /hs\\.mouse\\.setPosition.*point/.test(e.message); }
            var validOk = hs.mouse.setPosition(pos) === true;
            var validWithUndefined = hs.mouse.setPosition({ x: pos.x, y: pos.y, extra: undefined }) === true;
            return threwNonObj && threwBadVal && validOk && validWithUndefined;
        })()
        """)
        #expect(harness.hasException == false)
        #expect(result as? Bool == true)
    }
}
