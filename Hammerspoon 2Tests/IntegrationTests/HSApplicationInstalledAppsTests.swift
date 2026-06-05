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

    @Test("iconPath, when present, points to an existing icon file inside the bundle")
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
            // .icns for macOS bundles; iOS wrapper apps carry .png app icons.
            #expect(path.hasSuffix(".icns") || path.hasSuffix(".png"))
        }
        // Apps without a declared icon are valid — don't fail the suite.
        #expect(!h.hasException)
    }
}

// MARK: - Fixture helpers (shared by the wrapper + freshness suites)

/// Creates a minimal macOS app bundle: <root>/<name>.app/Contents/Info.plist
private func makeMacAppFixture(root: URL, name: String, bundleID: String,
                               displayName: String? = nil) throws {
    let contents = root.appendingPathComponent("\(name).app/Contents")
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    var info: [String: Any] = [
        "CFBundleIdentifier": bundleID,
        "CFBundleName": name,
        "CFBundleShortVersionString": "1.0",
    ]
    if let displayName { info["CFBundleDisplayName"] = displayName }
    let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
    try data.write(to: contents.appendingPathComponent("Info.plist"))
}

/// Creates an iOS/iPadOS wrapper bundle the way the App Store installs iPhone
/// apps on Apple silicon:
///   <root>/<outerName>.app/Wrapper/<innerName>.app/Info.plist   (flat iOS layout)
///   <root>/<outerName>.app/WrappedBundle -> Wrapper/<innerName>.app
private func makeWrapperAppFixture(root: URL, outerName: String, innerName: String,
                                   bundleID: String, displayName: String,
                                   withSymlink: Bool = true) throws -> URL {
    let outer = root.appendingPathComponent("\(outerName).app")
    let inner = outer.appendingPathComponent("Wrapper/\(innerName).app")
    try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
    let info: [String: Any] = [
        "CFBundleIdentifier": bundleID,
        "CFBundleName": innerName,
        "CFBundleDisplayName": displayName,
        "CFBundleShortVersionString": "2.5",
    ]
    let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
    try data.write(to: inner.appendingPathComponent("Info.plist"))
    if withSymlink {
        try FileManager.default.createSymbolicLink(
            atPath: outer.appendingPathComponent("WrappedBundle").path,
            withDestinationPath: "Wrapper/\(innerName).app")
    }
    return outer
}

private func makeTempRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("hs-installedapps-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

@Suite("hs.application.installedApps iOS wrapper bundles")
struct HSApplicationWrapperAppTests {
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSApplicationModule.self, as: "application")
        return harness
    }

    @Test("iOS wrapper app is discovered with inner-bundle metadata and outer path")
    func testWrapperAppDiscovered() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let outer = try makeWrapperAppFixture(
            root: root, outerName: "rednote", innerName: "discover",
            bundleID: "test.wrapper.discover", displayName: "小红书")

        let h = makeHarness()
        h.eval("var apps = hs.application.installedApps(['\(root.path)'])")
        h.expectTrue("apps.some(a => a.bundleID === 'test.wrapper.discover')")
        h.eval("var hit = apps.find(a => a.bundleID === 'test.wrapper.discover')")
        h.expectEqual("hit ? hit.displayName : '(missing)'", "小红书")
        h.expectEqual("hit ? hit.name : '(missing)'", "discover")
        // path must be the OUTER wrapper (what Finder shows / what you launch).
        // Compare canonicalized: the scan may spell temp dirs /private/var/…
        // while the fixture says /var/… (same file, symlinked prefix).
        let jsPath = h.eval("hit ? hit.path : '(missing)'") as? String ?? "(missing)"
        #expect(URL(fileURLWithPath: jsPath).resolvingSymlinksInPath().path
                == outer.resolvingSymlinksInPath().path)
        #expect(jsPath.hasSuffix("/rednote.app"))
        h.expectEqual("hit ? hit.version : '(missing)'", "2.5")
        #expect(!h.hasException)
    }

    @Test("wrapper app without WrappedBundle symlink is still discovered via Wrapper/*.app")
    func testWrapperAppWithoutSymlink() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try makeWrapperAppFixture(
            root: root, outerName: "NoLink", innerName: "InnerThing",
            bundleID: "test.wrapper.nolink", displayName: "No Link",
            withSymlink: false)

        let h = makeHarness()
        h.eval("var apps = hs.application.installedApps(['\(root.path)'])")
        h.expectTrue("apps.some(a => a.bundleID === 'test.wrapper.nolink')")
        #expect(!h.hasException)
    }

    @Test("malformed .app (no Contents, no Wrapper) is skipped without throwing")
    func testMalformedAppSkipped() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Broken.app"), withIntermediateDirectories: true)
        try makeMacAppFixture(root: root, name: "Good", bundleID: "test.good.app")

        let h = makeHarness()
        h.eval("var apps = hs.application.installedApps(['\(root.path)'])")
        h.expectTrue("apps.some(a => a.bundleID === 'test.good.app')")
        h.expectFalse("apps.some(a => a.path.indexOf('Broken.app') !== -1)")
        #expect(!h.hasException)
    }
}

@Suite("hs.application.installedApps freshness", .serialized)
struct HSApplicationFreshnessTests {
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSApplicationModule.self, as: "application")
        return harness
    }

    @Test("newly added app appears without manual cache invalidation")
    func testNewAppAppearsAutomatically() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try makeMacAppFixture(root: root, name: "First", bundleID: "test.fresh.first")

        let h = makeHarness()
        // Prime the cache: First is there, Second is not.
        h.eval("var apps = hs.application.installedApps(['\(root.path)'])")
        h.expectTrue("apps.some(a => a.bundleID === 'test.fresh.first')")
        h.expectFalse("apps.some(a => a.bundleID === 'test.fresh.second')")

        // Install a new app while the 30s TTL cache is still warm.
        try makeMacAppFixture(root: root, name: "Second", bundleID: "test.fresh.second")

        let appeared = h.waitFor(timeout: 3.0) {
            (h.eval("hs.application.installedApps(['\(root.path)']).some(a => a.bundleID === 'test.fresh.second')") as? Bool) == true
        }
        #expect(appeared, "newly installed app should appear without invalidateInstalledAppsCache()")
        #expect(!h.hasException)
    }

    @Test("deleted app disappears without manual cache invalidation")
    func testDeletedAppDisappearsAutomatically() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try makeMacAppFixture(root: root, name: "Keep", bundleID: "test.fresh.keep")
        try makeMacAppFixture(root: root, name: "Doomed", bundleID: "test.fresh.doomed")

        let h = makeHarness()
        h.eval("var apps = hs.application.installedApps(['\(root.path)'])")
        h.expectTrue("apps.some(a => a.bundleID === 'test.fresh.doomed')")

        // Delete the app while the 30s TTL cache is still warm.
        try FileManager.default.removeItem(at: root.appendingPathComponent("Doomed.app"))

        let disappeared = h.waitFor(timeout: 3.0) {
            (h.eval("hs.application.installedApps(['\(root.path)']).some(a => a.bundleID === 'test.fresh.doomed')") as? Bool) == false
        }
        #expect(disappeared, "deleted app should disappear without invalidateInstalledAppsCache()")
        h.expectTrue("hs.application.installedApps(['\(root.path)']).some(a => a.bundleID === 'test.fresh.keep')")
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
