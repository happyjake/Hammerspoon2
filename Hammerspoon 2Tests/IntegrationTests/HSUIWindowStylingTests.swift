//
//  HSUIWindowStylingTests.swift
//  Hammerspoon 2Tests
//

import Testing
@testable import Hammerspoon_2

struct HSUIWindowStylingTests {
    @Test("borderless() is chainable")
    func testBorderlessChainable() {
        let h = JSTestHarness()
        h.loadModuleRoot()
        let result = h.eval("typeof hs.ui.window().borderless()")
        #expect(result as? String == "object")
    }

    @Test("level() accepts all four name values")
    func testLevelAcceptsNames() {
        let h = JSTestHarness()
        h.loadModuleRoot()
        for name in ["normal", "floating", "popUpMenu", "screenSaver"] {
            _ = h.eval("hs.ui.window().level('\(name)')")
            #expect(h.hasException == false)
        }
    }

    @Test("center() returns the window builder")
    func testCenter() {
        let h = JSTestHarness()
        h.loadModuleRoot()
        let result = h.eval("typeof hs.ui.window().center()")
        #expect(result as? String == "object")
    }

    @Test("anchor() accepts edge values and is chainable")
    func testAnchor() {
        let h = JSTestHarness()
        h.loadModuleRoot()
        for edge in ["bottom", "top", "center", "BOTTOM", "nonsense"] {
            let result = h.eval("typeof hs.ui.window().anchor('\(edge)')")
            #expect(result as? String == "object", "anchor('\(edge)') should return the builder")
            #expect(h.hasException == false)
        }
    }

    @Test("anchor('bottom') drives a full borderless HUD chain without throwing")
    func testAnchorHUDChain() {
        let h = JSTestHarness()
        h.loadModuleRoot()
        _ = h.eval("""
            hs.ui.window()
              .borderless()
              .level('floating')
              .frame({ w: 900, h: 36 })
              .anchor('bottom')
              .canBecomeKey(false)
              .ignoresMouseEvents(true)
              .text('CHAT  j/k scroll  Esc exit').end()
        """)
        #expect(h.hasException == false)
    }

    @Test("full builder chain compiles and runs")
    func testFullChain() {
        let h = JSTestHarness()
        h.loadModuleRoot()
        _ = h.eval("""
            hs.ui.window()
              .borderless()
              .level('floating')
              .frame({w: 400, h: 200})
              .center()
              .canBecomeKey(true)
              .onKey((key, mods) => {})
              .onBlur(() => {})
        """)
        #expect(h.hasException == false)
    }

    @Test("hs.ui collection parameters reject wrong types with TypeError without side effects")
    @MainActor
    func testCollectionParameterValidation() {
        let h = JSTestHarness()
        h.loadModuleRoot()

        // 1. hs.ui.window(dict)
        for bad in ["'not-an-object'", "123", "[1, 2]", "null"] {
            let caught = h.eval("""
                (function() {
                    try {
                        hs.ui.window(\(bad));
                        return 'no-throw';
                    } catch (e) {
                        return e.name + ': ' + e.message;
                    }
                })()
                """) as? String
            #expect(caught?.hasPrefix("TypeError: hs.ui.window:") == true, "Expected TypeError for window(\(bad)), got \(String(describing: caught))")
            #expect(!h.hasException)
        }
        let validWin = h.eval("hs.ui.window({x: 10, y: 20, w: 300, h: 400})") as? HSUIWindow
        #expect(validWin != nil)
        #expect(!h.hasException)

        // 2. hs.ui.window.frame(dict)
        for bad in ["'not-an-object'", "123", "[1, 2]", "null", "undefined"] {
            let caught = h.eval("""
                (function() {
                    try {
                        hs.ui.window().rectangle().frame(\(bad));
                        return 'no-throw';
                    } catch (e) {
                        return e.name + ': ' + e.message;
                    }
                })()
                """) as? String
            #expect(caught?.hasPrefix("TypeError: hs.ui.window.frame:") == true, "Expected TypeError for frame(\(bad)), got \(String(describing: caught))")
            #expect(!h.hasException)
        }
        let framedWin = h.eval("hs.ui.window().rectangle().frame({w: 120, h: 80})") as? HSUIWindow
        #expect(framedWin != nil)
        #expect(!h.hasException)

        // 3. hs.ui.alert.position(dict)
        let alert = h.eval("var a = hs.ui.alert('hello'); a") as? HSUIAlert
        #expect(alert?.position == nil)
        for bad in ["'not-an-object'", "123", "[1, 2]", "null", "undefined"] {
            let caught = h.eval("""
                (function() {
                    try {
                        a.position(\(bad));
                        return 'no-throw';
                    } catch (e) {
                        return e.name + ': ' + e.message;
                    }
                })()
                """) as? String
            #expect(caught?.hasPrefix("TypeError: hs.ui.alert.position:") == true, "Expected TypeError for alert.position(\(bad)), got \(String(describing: caught))")
            #expect(!h.hasException)
        }
        #expect(alert?.position == nil)
        _ = h.eval("a.position({x: 42, y: 84})")
        #expect(!h.hasException)
        #expect(alert?.position?.x == 42)
        #expect(alert?.position?.y == 84)

        // 4. hs.ui.dialog.buttons(labels)
        let dialog = h.eval("var d = hs.ui.dialog('Save?'); d") as? HSUIDialog
        #expect(dialog?.buttons == ["OK"])
        for bad in ["'not-an-array'", "123", "{a: 'b'}", "[1, 2]", "null", "undefined"] {
            let caught = h.eval("""
                (function() {
                    try {
                        d.buttons(\(bad));
                        return 'no-throw';
                    } catch (e) {
                        return e.name + ': ' + e.message;
                    }
                })()
                """) as? String
            #expect(caught?.hasPrefix("TypeError: hs.ui.dialog.buttons:") == true, "Expected TypeError for dialog.buttons(\(bad)), got \(String(describing: caught))")
            #expect(!h.hasException)
        }
        #expect(dialog?.buttons == ["OK"])
        _ = h.eval("d.buttons(['Save', 'Cancel'])")
        #expect(!h.hasException)
        #expect(dialog?.buttons == ["Save", "Cancel"])

        // 5. hs.ui.filePicker.allowedFileTypes(types)
        let picker = h.eval("var fp = hs.ui.filePicker(); fp") as? HSUIFilePicker
        #expect(picker?.allowedFileTypes == nil)
        for bad in ["'txt'", "123", "{a: 'txt'}", "[1, 2]", "null", "undefined"] {
            let caught = h.eval("""
                (function() {
                    try {
                        fp.allowedFileTypes(\(bad));
                        return 'no-throw';
                    } catch (e) {
                        return e.name + ': ' + e.message;
                    }
                })()
                """) as? String
            #expect(caught?.hasPrefix("TypeError: hs.ui.filePicker.allowedFileTypes:") == true, "Expected TypeError for allowedFileTypes(\(bad)), got \(String(describing: caught))")
            #expect(!h.hasException)
        }
        #expect(picker?.allowedFileTypes == nil)
        _ = h.eval("fp.allowedFileTypes(['txt', 'md'])")
        #expect(!h.hasException)
        #expect(picker?.allowedFileTypes == ["txt", "md"])

        // 6. hs.ui.textPrompt.buttons(labels)
        let prompt = h.eval("var tp = hs.ui.textPrompt('Name?'); tp") as? HSUITextPrompt
        #expect(prompt?.buttons == ["OK", "Cancel"])
        for bad in ["'Yes'", "123", "{a: 'Yes'}", "[1, 2]", "null", "undefined"] {
            let caught = h.eval("""
                (function() {
                    try {
                        tp.buttons(\(bad));
                        return 'no-throw';
                    } catch (e) {
                        return e.name + ': ' + e.message;
                    }
                })()
                """) as? String
            #expect(caught?.hasPrefix("TypeError: hs.ui.textPrompt.buttons:") == true, "Expected TypeError for textPrompt.buttons(\(bad)), got \(String(describing: caught))")
            #expect(!h.hasException)
        }
        #expect(prompt?.buttons == ["OK", "Cancel"])
        _ = h.eval("tp.buttons(['Submit', 'Skip'])")
        #expect(!h.hasException)
        #expect(prompt?.buttons == ["Submit", "Skip"])
    }
}
