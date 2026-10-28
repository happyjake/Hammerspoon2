import XCTest
import JavaScriptCore
import AppKit
@testable import Hammerspoon_2

nonisolated final class HSApplicationCacheTests: XCTestCase {
    @MainActor
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSApplicationModule.self, as: "application")
        return harness
    }

    @MainActor
    private func shutdown(_ harness: JSTestHarness) {
        let module = harness.context.objectForKeyedSubscript("hs")?
            .objectForKeyedSubscript("application")?.toObject() as? HSApplicationModule
        module?.shutdown()
    }

    @MainActor
    private func cleanup(_ harness: JSTestHarness) {
        harness.eval("hs.application.invalidateInstalledAppsCache()")
        shutdown(harness)
    }

    @MainActor
    func testCacheHitReusesFrozenArrayAndRecords() {
        let h = makeHarness()
        defer { cleanup(h) }
        h.eval("""
            hs.application.invalidateInstalledAppsCache();
            var first = hs.application.installedApps();
            var before = JSON.stringify(first);
            var second = hs.application.installedApps([]);
            var mutationRejected = false;
            try { first.push({}); } catch (_) { mutationRejected = true; }
            first[0].name = 'Changed';
            """)
        XCTAssertEqual(h.eval("first === second") as? Bool, true)
        XCTAssertEqual(h.eval("Object.isFrozen(first) && first.every(Object.isFrozen)") as? Bool, true)
        XCTAssertEqual(h.eval("mutationRejected && JSON.stringify(second) === before") as? Bool, true)
        XCTAssertFalse(h.hasException)
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func writeApp(in root: URL, name: String = "Fixture", version: String = "1.0") throws {
        let contents = root.appendingPathComponent("\(name).app/Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: [
            "CFBundleIdentifier": "test.application.cache.\(name)",
            "CFBundleName": name,
            "CFBundleShortVersionString": version,
        ], format: .xml, options: 0)
        // An in-place metadata edit does not change the watched root directory.
        try data.write(to: contents.appendingPathComponent("Info.plist"))
    }

    @MainActor
    private func setRoots(_ roots: [URL], in h: JSTestHarness) {
        h.context.setObject(roots.map(\.path), forKeyedSubscript: "roots" as NSString)
    }

    @MainActor
    func testExtraRootsKeepOrderAndSeparateCacheEntries() throws {
        let a = try makeRoot()
        let b = try makeRoot()
        defer {
            try? FileManager.default.removeItem(at: a)
            try? FileManager.default.removeItem(at: b)
        }
        try writeApp(in: a, version: "1.0")
        try writeApp(in: b, version: "2.0")
        let h = makeHarness()
        defer { cleanup(h) }
        setRoots([a, b], in: h)
        h.eval("""
            hs.application.invalidateInstalledAppsCache();
            var ab = hs.application.installedApps(roots);
            var ba = hs.application.installedApps(roots.slice().reverse());
            var plain = hs.application.installedApps();
            var fixture = apps => apps.find(a => a.bundleID === 'test.application.cache.Fixture');
            """)
        XCTAssertEqual(h.eval("fixture(ab).version") as? String, "1.0")
        XCTAssertEqual(h.eval("fixture(ba).version") as? String, "2.0")
        XCTAssertEqual(h.eval("fixture(plain) === undefined") as? Bool, true)
        XCTAssertEqual(h.eval("hs.application.installedApps(roots) === ab") as? Bool, true)
        XCTAssertFalse(h.hasException)
    }

    @MainActor
    func testExtraRootsWithNewlinesDoNotCollide() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("first")
        let second = root.appendingPathComponent("second")
        let joined = URL(fileURLWithPath: first.path + "\n" + second.path)
        try writeApp(in: first, name: "Separate")
        try writeApp(in: joined, name: "Joined")
        let h = makeHarness()
        defer { cleanup(h) }
        setRoots([first, second], in: h)
        h.eval(#"""
            var separate = hs.application.installedApps(roots);
            var joined = hs.application.installedApps([roots.join('\n')]);
            """#)
        XCTAssertEqual(h.eval("separate.some(a => a.name === 'Separate')") as? Bool, true)
        XCTAssertEqual(h.eval("joined.some(a => a.name === 'Joined')") as? Bool, true)
        XCTAssertEqual(h.eval("joined.some(a => a.name === 'Separate')") as? Bool, false)
        XCTAssertFalse(h.hasException)
    }

    @MainActor
    func testInvalidationRescansMetadataAndReplacesJavaScriptValue() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeApp(in: root)
        let h = makeHarness()
        defer { cleanup(h) }
        setRoots([root], in: h)
        h.eval("var before = hs.application.installedApps(roots)")
        try writeApp(in: root, version: "2.0")
        XCTAssertEqual(h.eval("hs.application.installedApps(roots) === before") as? Bool, true)
        h.eval("hs.application.invalidateInstalledAppsCache(); var after = hs.application.installedApps(roots)")
        XCTAssertEqual(h.eval("after !== before") as? Bool, true)
        XCTAssertEqual(h.eval("after.find(a => a.name === 'Fixture').version") as? String, "2.0")
        XCTAssertEqual(h.eval("before.find(a => a.name === 'Fixture').version") as? String, "1.0")
        XCTAssertFalse(h.hasException)
    }

    @MainActor
    func testNativeCacheSurvivesContextReplacementAndInvalidatesAcrossContexts() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeApp(in: root)
        autoreleasepool {
            let old = makeHarness()
            setRoots([root], in: old)
            old.eval("hs.application.installedApps(roots)")
            shutdown(old)
        }
        // If the new context rescans instead of using process data, it sees 2.0.
        try writeApp(in: root, version: "2.0")
        let h = makeHarness()
        let other = makeHarness()
        defer { cleanup(h); shutdown(other) }
        setRoots([root], in: h)
        h.eval("var cached = hs.application.installedApps(roots)")
        XCTAssertEqual(h.eval("cached.find(a => a.name === 'Fixture').version") as? String, "1.0")
        other.eval("hs.application.invalidateInstalledAppsCache()")
        h.eval("var refreshed = hs.application.installedApps(roots)")
        XCTAssertEqual(h.eval("refreshed.find(a => a.name === 'Fixture').version") as? String, "2.0")
        XCTAssertEqual(h.eval("cached !== refreshed") as? Bool, true)
        XCTAssertFalse(h.hasException)
        XCTAssertFalse(other.hasException)
    }

    @MainActor
    func testRootWatcherSurvivesModuleShutdown() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeApp(in: root)
        autoreleasepool {
            let old = makeHarness()
            setRoots([root], in: old)
            old.eval("hs.application.installedApps(roots)")
            shutdown(old)
        }
        try writeApp(in: root, name: "Added")
        let h = makeHarness()
        defer { cleanup(h) }
        setRoots([root], in: h)
        XCTAssertTrue(h.waitFor(timeout: 3) {
            h.eval("hs.application.installedApps(roots).some(a => a.name === 'Added')") as? Bool == true
        })
        XCTAssertFalse(h.hasException)
    }

    @MainActor
    func testShutdownReleasesCachedJavaScriptContext() {
        weak var context: JSContext?
        autoreleasepool {
            let h = makeHarness()
            context = h.context
            h.eval("hs.application.installedApps()")
            shutdown(h)
        }
        XCTAssertNil(context)
    }

    @MainActor
    func testIconBytesRemainIdenticalAcrossHitsInvalidationAndContexts() throws {
        let h = makeHarness()
        defer { cleanup(h) }
        h.eval("hs.application.invalidateInstalledAppsCache()")
        let renders = HSApplicationModule.iconRenderCount
        let first = try XCTUnwrap(h.eval("hs.application.iconForBundleID('com.apple.finder')") as? String)
        XCTAssertEqual(HSApplicationModule.iconRenderCount, renders + 1)
        for _ in 0..<5 {
            XCTAssertEqual(h.eval("hs.application.iconForBundleID('com.apple.finder')") as? String, first)
        }
        let other = makeHarness()
        defer { shutdown(other) }
        XCTAssertEqual(other.eval("hs.application.iconForBundleID('com.apple.finder')") as? String, first)
        XCTAssertEqual(HSApplicationModule.iconRenderCount, renders + 1)
        other.eval("hs.application.invalidateInstalledAppsCache()")
        XCTAssertEqual(h.eval("hs.application.iconForBundleID('com.apple.finder')") as? String, first)
        XCTAssertEqual(HSApplicationModule.iconRenderCount, renders + 2)
        let bytes = try XCTUnwrap(Data(base64Encoded: first))
        XCTAssertEqual(Array(bytes.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
        let image = try XCTUnwrap(NSBitmapImageRep(data: bytes))
        XCTAssertEqual(image.pixelsWide, 88)
        XCTAssertEqual(image.pixelsHigh, 88)
        XCTAssertEqual(h.eval("hs.application.iconForBundleID('invalid.application.cache') === null") as? Bool, true)
        XCTAssertFalse(h.hasException)
        XCTAssertFalse(other.hasException)
    }

    @MainActor
    func testRootWatcherInvalidatesIconsBeforeInstalledAppsIsCalledAgain() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeApp(in: root)
        let h = makeHarness()
        defer { cleanup(h) }
        setRoots([root], in: h)
        h.eval("hs.application.installedApps(roots)")
        let icon = try XCTUnwrap(h.eval("hs.application.iconForBundleID('com.apple.finder')") as? String)
        let renders = HSApplicationModule.iconRenderCount
        try writeApp(in: root, name: "Added")
        XCTAssertTrue(h.waitFor(timeout: 3) {
            XCTAssertEqual(h.eval("hs.application.iconForBundleID('com.apple.finder')") as? String, icon)
            return HSApplicationModule.iconRenderCount > renders
        })
        XCTAssertFalse(h.hasException)
    }
}
