//
//  HSApplicationInstalledAppsTests.swift
//  Hammerspoon 2Tests
//
//  Tests for installedApps() and killPid() extensions to hs.application.
//

import Testing
import Foundation
@testable import Hammerspoon_2

@Suite("hs.application.installedApps API structure")
struct HSApplicationInstalledAppsStructureTests {
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSApplicationModule.self, as: "application")
        return harness
    }

    @Test("installedApps is a function")
    func testInstalledAppsIsFunction() {
        makeHarness().expectTrue("typeof hs.application.installedApps === 'function'")
    }

    @Test("invalidateInstalledAppsCache is a function")
    func testInvalidateIsFunction() {
        makeHarness().expectTrue("typeof hs.application.invalidateInstalledAppsCache === 'function'")
    }

    @Test("killPid is a function")
    func testKillPidIsFunction() {
        makeHarness().expectTrue("typeof hs.application.killPid === 'function'")
    }

    @Test("installedApps() returns an array")
    func testReturnsArray() {
        let h = makeHarness()
        h.eval("var apps = hs.application.installedApps()")
        h.expectTrue("Array.isArray(apps)")
        #expect(!h.hasException)
    }
}

@Suite("hs.application.installedApps content")
struct HSApplicationInstalledAppsContentTests {
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSApplicationModule.self, as: "application")
        return harness
    }

    @Test("Result includes at least one standard system app (Calculator)")
    func testSystemAppPresent() {
        // Finder lives at /System/Library/CoreServices and is intentionally not
        // surfaced — that's a CoreServices helper, not a user-facing app under
        // the standard roots. Calculator at /System/Applications is a good
        // sentinel for "we found user-facing system apps".
        let h = makeHarness()
        h.eval("var apps = hs.application.installedApps()")
        h.expectTrue("apps.some(a => a.bundleID === 'com.apple.calculator')")
        #expect(!h.hasException)
    }

    @Test("Every entry has required keys with right types")
    func testShape() {
        let h = makeHarness()
        h.eval("var apps = hs.application.installedApps()")
        h.expectTrue("apps.length > 0")
        h.expectTrue("apps.every(a => typeof a.name === 'string')")
        h.expectTrue("apps.every(a => typeof a.displayName === 'string')")
        h.expectTrue("apps.every(a => typeof a.bundleID === 'string' && a.bundleID.length > 0)")
        h.expectTrue("apps.every(a => typeof a.path === 'string' && a.path.endsWith('.app'))")
        h.expectTrue("apps.every(a => typeof a.version === 'string')")
        #expect(!h.hasException)
    }

    @Test("No duplicate bundleIDs")
    func testNoDuplicates() {
        let h = makeHarness()
        h.eval("var apps = hs.application.installedApps()")
        h.expectTrue("(new Set(apps.map(a => a.bundleID))).size === apps.length")
    }

    @Test("Cache returns same content within TTL")
    func testCached() {
        let h = makeHarness()
        h.eval("var a = hs.application.installedApps(); var b = hs.application.installedApps()")
        h.expectTrue("a.length === b.length")
        h.expectTrue("a[0].bundleID === b[0].bundleID")
    }

    @Test("invalidateInstalledAppsCache forces a rescan")
    func testInvalidate() {
        let h = makeHarness()
        h.eval("""
            var a = hs.application.installedApps()
            hs.application.invalidateInstalledAppsCache()
            var b = hs.application.installedApps()
        """)
        h.expectTrue("a.length === b.length")
        #expect(!h.hasException)
    }

    @Test("Extra roots argument is accepted (empty array no-op)")
    func testExtraRootsAccepted() {
        let h = makeHarness()
        h.eval("var apps = hs.application.installedApps([])")
        h.expectTrue("Array.isArray(apps) && apps.length > 0")
        #expect(!h.hasException)
    }

    @Test("iconPath, when present, points to an existing .icns inside the bundle")
    func testIconPathPointsToFile() {
        let h = makeHarness()
        h.eval("""
            var apps = hs.application.installedApps()
            var withIcons = apps.filter(a => typeof a.iconPath === 'string' && a.iconPath.length > 0)
            var first = withIcons[0]
            var iconPath = first && first.iconPath
        """)
        if let path = h.eval("iconPath") as? String, !path.isEmpty {
            #expect(FileManager.default.fileExists(atPath: path))
            #expect(path.hasSuffix(".icns"))
        }
        // Apps without a declared icon are valid — don't fail the suite.
        #expect(!h.hasException)
    }
}

@Suite("hs.application.killPid")
struct HSApplicationKillPidTests {
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSApplicationModule.self, as: "application")
        return harness
    }

    @Test("Refuses PID 0")
    func testRefusePidZero() {
        let h = makeHarness()
        h.expectFalse("hs.application.killPid(0, false)")
    }

    @Test("Refuses PID 1 (launchd)")
    func testRefusePidOne() {
        let h = makeHarness()
        h.expectFalse("hs.application.killPid(1, false)")
    }

    @Test("Refuses own PID")
    func testRefuseSelf() {
        let h = makeHarness()
        let pid = ProcessInfo.processInfo.processIdentifier
        h.expectFalse("hs.application.killPid(\(pid), false)")
    }

    @Test("Returns false for nonexistent PID")
    func testNonexistentPid() {
        let h = makeHarness()
        // PIDs > 99999 are almost certainly unused on a fresh boot.
        h.expectFalse("hs.application.killPid(999999, false)")
    }

    @Test("Successfully terminates a spawned sleep process")
    func testKillSpawned() throws {
        // Spawn a background process via Foundation Process so we have a real PID
        // we can kill without depending on hs.task being loaded.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["30"]
        try process.run()
        let pid = Int(process.processIdentifier)
        defer { if process.isRunning { process.terminate() } }

        let h = makeHarness()
        let ok = h.eval("hs.application.killPid(\(pid), false)") as? Bool ?? false
        #expect(ok == true)

        // Give the process a moment to actually exit.
        let deadline = Date().addingTimeInterval(1.5)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        #expect(process.isRunning == false)
    }
}
