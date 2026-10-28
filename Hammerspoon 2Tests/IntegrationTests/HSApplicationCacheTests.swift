import XCTest
import JavaScriptCore
import AppKit
import CoreServices
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
        let missing = try XCTUnwrap(h.evalValue("hs.application.iconForBundleID('invalid.application.cache')"))
        XCTAssertTrue(missing.isNull || missing.isUndefined)
        XCTAssertEqual(HSApplicationModule.iconRenderCount, renders + 2)
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

    @MainActor
    private func iconData(_ color: NSColor, in root: URL, assetCatalog: Bool = false) throws -> Data {
        let scratch = root.appendingPathComponent(UUID().uuidString)
        let iconset = scratch.appendingPathComponent("Fixture.iconset")
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        var images: [[String: String]] = []
        for side in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let pixels = side * scale
                let bitmap = try XCTUnwrap(NSBitmapImageRep(
                    bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32))
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
                color.setFill()
                NSRect(x: 0, y: 0, width: pixels, height: pixels).fill()
                // Different corner details distinguish representations; solid
                // colors alone cannot catch a change in image selection.
                NSColor(calibratedWhite: CGFloat(pixels) / 1024, alpha: 1).setFill()
                NSRect(x: 0, y: 0, width: pixels / 4, height: pixels / 4).fill()
                NSGraphicsContext.restoreGraphicsState()
                let filename = "icon_\(side)x\(side)\(scale == 2 ? "@2x" : "").png"
                let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: iconset.appendingPathComponent(filename))
                images.append(["idiom": "mac", "size": "\(side)x\(side)", "scale": "\(scale)x", "filename": filename])
            }
        }
        if assetCatalog {
            let assets = scratch.appendingPathComponent("Fixture.xcassets")
            let appIcon = assets.appendingPathComponent("AppIcon.appiconset")
            let output = scratch.appendingPathComponent("catalog")
            try FileManager.default.createDirectory(at: appIcon, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            for image in images {
                let filename = try XCTUnwrap(image["filename"])
                try FileManager.default.copyItem(at: iconset.appendingPathComponent(filename), to: appIcon.appendingPathComponent(filename))
            }
            let metadata: [String: Any] = [
                "info": ["version": 1, "author": "xcode"],
                "images": images,
            ]
            try JSONSerialization.data(withJSONObject: metadata).write(to: appIcon.appendingPathComponent("Contents.json"))
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["actool", assets.path, "--compile", output.path,
                                 "--platform", "macosx", "--minimum-deployment-target", "15.6",
                                 "--app-icon", "AppIcon", "--output-partial-info-plist", scratch.appendingPathComponent("partial.plist").path]
            process.standardOutput = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            XCTAssertEqual(process.terminationStatus, 0)
            return try Data(contentsOf: output.appendingPathComponent("Assets.car"))
        }
        let output = scratch.appendingPathComponent("Fixture.icns")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", "-o", output.path, iconset.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        return try Data(contentsOf: output)
    }

    @MainActor
    func testInPlaceIconResourceUpdatePreservesBundleDateAndInvalidatesCache() throws {
        try checkIconResourceUpdate(iconKey: "CFBundleIconFile", iconName: "AppIcon.icns")
    }

    @MainActor
    func testInPlaceNamedIconUpdateInvalidatesCache() throws {
        try checkIconResourceUpdate(iconKey: "CFBundleIconName", iconName: "AppIcon")
    }

    @MainActor
    private func checkIconResourceUpdate(iconKey: String, iconName: String) throws {
        // Launch Services does not discover application fixtures in the
        // system temporary directory. Keep this fixture in build artifacts.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("artifacts/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let assetCatalog = iconKey == "CFBundleIconName"
        let red = try iconData(.red, in: root, assetCatalog: assetCatalog)
        let blue = try iconData(.blue, in: root, assetCatalog: assetCatalog)
        XCTAssertFalse(red == blue, "Fixture resources must contain different images")
        let app = root.appendingPathComponent("IconFixture.app")
        let contents = app.appendingPathComponent("Contents")
        let resources = contents.appendingPathComponent("Resources")
        let executables = contents.appendingPathComponent("MacOS")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: executables, withIntermediateDirectories: true)
        let executable = executables.appendingPathComponent("Fixture")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let bundleID = "test.application.cache.icon.\(UUID().uuidString)"
        let info = try PropertyListSerialization.data(fromPropertyList: [
            "CFBundleIdentifier": bundleID, "CFBundleName": "IconFixture",
            "CFBundleExecutable": "Fixture", "CFBundlePackageType": "APPL",
            "CFBundleVersion": "1", "CFBundleShortVersionString": "1.0",
            iconKey: iconName,
        ], format: .xml, options: 0)
        let infoPath = contents.appendingPathComponent("Info.plist")
        try info.write(to: infoPath)
        let infoDate = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
        try FileManager.default.setAttributes([.modificationDate: infoDate], ofItemAtPath: infoPath.path)
        let icon = resources.appendingPathComponent(assetCatalog ? "Assets.car" : "AppIcon.icns")
        try red.write(to: icon)
        let iconDate = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
        try FileManager.default.setAttributes([.modificationDate: iconDate], ofItemAtPath: icon.path)
        XCTAssertEqual(Bundle(url: app)?.bundleIdentifier, bundleID)
        XCTAssertEqual(LSRegisterURL(app as CFURL, true), noErr)
        let h = makeHarness()
        defer { cleanup(h) }
        h.context.setObject(bundleID, forKeyedSubscript: "fixtureBundleID" as NSString)
        XCTAssertTrue(h.waitFor(timeout: 3) {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
        }, "Registered fixture must be discoverable before priming the icon cache: \(NSWorkspace.shared.urlsForApplications(withBundleIdentifier: bundleID))")
        let before = try XCTUnwrap(h.eval("hs.application.iconForBundleID(fixtureBundleID)") as? String)
        let originalBitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(Data(base64Encoded: before))))
        let originalCenter = try XCTUnwrap(originalBitmap.colorAt(x: 44, y: 44)?.usingColorSpace(.deviceRGB))
        XCTAssertGreaterThan(originalCenter.redComponent, 0.9)
        XCTAssertLessThan(originalCenter.blueComponent, 0.1)
        let renders = HSApplicationModule.iconRenderCount
        let appDate = try FileManager.default.attributesOfItem(atPath: app.path)[.modificationDate] as? Date
        let rootDate = try FileManager.default.attributesOfItem(atPath: root.path)[.modificationDate] as? Date
        try blue.write(to: icon, options: .atomic)
        // Keep the resource times in distinct whole seconds for Icon Services,
        // while leaving the application and its parent's dates unchanged.
        try FileManager.default.setAttributes([.modificationDate: iconDate.addingTimeInterval(2)], ofItemAtPath: icon.path)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: app.path)[.modificationDate] as? Date, appDate)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: root.path)[.modificationDate] as? Date, rootDate)
        // The cache must rerender, but Icon Services can keep stale native
        // artwork. Compare against the original uncached drawing operation.
        let expected = try XCTUnwrap(nativeIconPNG(at: app.path))
        let after = try XCTUnwrap(h.eval("hs.application.iconForBundleID(fixtureBundleID)") as? String)
        XCTAssertTrue(after == expected, "Resource changes must rerender using the native drawing path")
        XCTAssertEqual(HSApplicationModule.iconRenderCount, renders + 1)

        // A valid plist can change size while retaining its modification date.
        // The cached icon must still be regenerated, even though pixels match.
        try (info + Data("\n ".utf8)).write(to: infoPath)
        try FileManager.default.setAttributes([.modificationDate: infoDate], ofItemAtPath: infoPath.path)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: infoPath.path)[.modificationDate] as? Date, infoDate)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: app.path)[.modificationDate] as? Date, appDate)
        let metadataExpected = try XCTUnwrap(nativeIconPNG(at: app.path))
        XCTAssertTrue(h.eval("hs.application.iconForBundleID(fixtureBundleID)") as? String == metadataExpected)
        XCTAssertEqual(HSApplicationModule.iconRenderCount, renders + 2)

        try red.write(to: icon, options: .atomic)
        try FileManager.default.setAttributes([.modificationDate: iconDate.addingTimeInterval(4)], ofItemAtPath: icon.path)
        h.eval("hs.application.invalidateInstalledAppsCache()")
        let invalidationExpected = try XCTUnwrap(nativeIconPNG(at: app.path))
        let invalidated = try XCTUnwrap(h.eval("hs.application.iconForBundleID(fixtureBundleID)") as? String)
        XCTAssertTrue(invalidated == invalidationExpected, "Explicit invalidation must use the native drawing path")
        XCTAssertEqual(HSApplicationModule.iconRenderCount, renders + 3)
        XCTAssertFalse(h.hasException)
    }

    @MainActor
    private func nativeIconPNG(at path: String) -> String? {
        let icon = NSWorkspace.shared.icon(forFile: path)
        let target = NSSize(width: 44, height: 44)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 88, pixelsHigh: 88,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32) else { return nil }
        bitmap.size = target
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        icon.draw(in: NSRect(origin: .zero, size: target))
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])?.base64EncodedString()
    }

    @MainActor
    func testColdIconPNGsMatchNativeRenderer() throws {
        let h = makeHarness()
        defer { cleanup(h) }
        let ids = try XCTUnwrap(h.eval("hs.application.installedApps().map(app => app.bundleID)") as? [String])
        var checked = 0
        for id in ids {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { continue }
            let expected = try XCTUnwrap(nativeIconPNG(at: url.path))
            h.context.setObject(id, forKeyedSubscript: "bundleID" as NSString)
            let actual = try XCTUnwrap(h.eval("hs.application.iconForBundleID(bundleID)") as? String)
            XCTAssertTrue(actual == expected, "PNG bytes must match native drawing")
            checked += 1
            if checked == 8 { break }
        }
        XCTAssertEqual(checked, 8)
        XCTAssertFalse(h.hasException)
    }

    @MainActor
    func testIconCacheHitTiming() throws {
        let h = makeHarness()
        defer { cleanup(h) }
        h.loadModule(HSTimerModule.self, as: "timer")
        h.eval("hs.application.iconForBundleID('com.apple.finder')")
        let renders = HSApplicationModule.iconRenderCount
        let timings = try XCTUnwrap(h.eval("""
            (() => {
                const samples = [];
                for (let run = 0; run < 6; run++) {
                    const start = hs.timer.absoluteTime();
                    for (let i = 0; i < 200; i++) hs.application.iconForBundleID('com.apple.finder');
                    samples.push((hs.timer.absoluteTime() - start) / 200 / 1000);
                }
                return JSON.stringify({callsPerSample: 200, microsecondsPerHit: samples});
            })()
            """) as? String)
        print("Icon cache hit timing: \(timings)")
        XCTAssertEqual(HSApplicationModule.iconRenderCount, renders)
        XCTAssertFalse(h.hasException)
    }
}
