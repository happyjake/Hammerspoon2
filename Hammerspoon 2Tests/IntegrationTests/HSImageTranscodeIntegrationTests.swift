//
//  HSImageTranscodeIntegrationTests.swift
//  Hammerspoon 2Tests
//
//  Integration tests for HSImage.transcodeToFileAsync — the off-main-thread
//  ImageIO transcode/downscale used so large clipboard images never freeze the
//  app. Exercises the JS→Swift Promise bridge with real files on disk.
//

import Testing
import JavaScriptCore
import AppKit
@testable import Hammerspoon_2

// MARK: - Fixtures

/// Write a solid-colour PNG of the given pixel size to a temp path. Returns the
/// path, or nil on failure.
@MainActor
private func makeSolidPNG(width: Int, height: Int) -> String? {
    let size = NSSize(width: width, height: height)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.systemTeal.setFill()
    NSRect(origin: .zero, size: size).fill()
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return nil }
    let path = NSTemporaryDirectory() + "hsimg-src-\(UUID().uuidString).png"
    do {
        try png.write(to: URL(fileURLWithPath: path))
        return path
    } catch {
        return nil
    }
}

private func tempDest(_ ext: String) -> String {
    NSTemporaryDirectory() + "hsimg-out-\(UUID().uuidString).\(ext)"
}

// MARK: - Suite

@Suite("HSImage.transcodeToFileAsync")
struct HSImageTranscodeIntegrationTests {
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        // HSImage is a user-instantiable type bridge, not an hs.* module, so the
        // harness doesn't auto-inject it — register it the way TypeBridgesInstaller does.
        harness.context.setObject(HSImage.self, forKeyedSubscript: "HSImage" as NSString)
        return harness
    }

    @Test("transcodeToFileAsync is a function")
    func testIsFunction() {
        makeHarness().expectTrue("typeof HSImage.transcodeToFileAsync === 'function'")
    }

    @Test("downscales a source file and resolves with path/width/height/bytes")
    @MainActor
    func testDownscaleFromPath() async throws {
        let harness = makeHarness()
        let src = try #require(makeSolidPNG(width: 400, height: 200))
        let dst = tempDest("jpg")
        defer { try? FileManager.default.removeItem(atPath: src) }
        defer { try? FileManager.default.removeItem(atPath: dst) }

        var done = false
        harness.registerCallback("onDone") { done = true }
        harness.eval("""
        var res, errv;
        HSImage.transcodeToFileAsync({
            src: { path: '\(src)' }, dest: '\(dst)', maxEdge: 64, format: 'jpeg', quality: 0.8
        }).then(function (r) { res = r; __test_callback('onDone'); })
          .catch(function (e) { errv = String(e); __test_callback('onDone'); });
        """)

        let completed = await harness.waitForAsync(timeout: 5.0) { done }
        #expect(completed, "Promise should resolve")
        harness.expectTrue("!errv")
        // Longest edge clamped to 64; aspect ratio preserved (400×200 → 64×32).
        harness.expectTrue("res && res.width === 64 && res.height === 32")
        harness.expectTrue("res.bytes > 0")
        harness.expectEqual("res.path", dst)
        #expect(FileManager.default.fileExists(atPath: dst), "output JPEG should exist on disk")
    }

    @Test("transcodes from base64 data with no downscale")
    @MainActor
    func testFromDataB64FullSize() async throws {
        let harness = makeHarness()
        let src = try #require(makeSolidPNG(width: 120, height: 90))
        let b64 = try Data(contentsOf: URL(fileURLWithPath: src)).base64EncodedString()
        let dst = tempDest("png")
        defer { try? FileManager.default.removeItem(atPath: src) }
        defer { try? FileManager.default.removeItem(atPath: dst) }

        var done = false
        harness.registerCallback("onDone") { done = true }
        harness.eval("""
        var res, errv;
        HSImage.transcodeToFileAsync({
            src: { dataB64: '\(b64)' }, dest: '\(dst)', format: 'png'
        }).then(function (r) { res = r; __test_callback('onDone'); })
          .catch(function (e) { errv = String(e); __test_callback('onDone'); });
        """)

        let completed = await harness.waitForAsync(timeout: 5.0) { done }
        #expect(completed, "Promise should resolve")
        harness.expectTrue("!errv")
        // No maxEdge → full resolution. The test host may render the fixture at 2×
        // (Retina), so assert positivity + the preserved 4:3 aspect ratio rather
        // than exact pixels.
        harness.expectTrue("res && res.width > 0 && res.height > 0 && res.bytes > 0")
        harness.expectTrue("Math.abs((res.width / res.height) - (120 / 90)) < 0.02")
        #expect(FileManager.default.fileExists(atPath: dst), "output PNG should exist on disk")
    }

    @Test("rejects when dest is missing")
    func testRejectsMissingDest() async {
        let harness = makeHarness()
        var done = false
        harness.registerCallback("onDone") { done = true }
        harness.eval("""
        var errv;
        HSImage.transcodeToFileAsync({ src: { path: '/tmp/whatever.png' } })
            .catch(function (e) { errv = String(e); __test_callback('onDone'); });
        """)
        let completed = await harness.waitForAsync(timeout: 5.0) { done }
        #expect(completed, "Promise should reject")
        harness.expectTrue("errv.indexOf('dest') !== -1")
    }

    @Test("rejects when the source cannot be read")
    func testRejectsUnreadableSource() async {
        let harness = makeHarness()
        let dst = tempDest("png")
        defer { try? FileManager.default.removeItem(atPath: dst) }
        var done = false
        harness.registerCallback("onDone") { done = true }
        harness.eval("""
        var errv;
        HSImage.transcodeToFileAsync({ src: { path: '/nonexistent/nope.png' }, dest: '\(dst)' })
            .catch(function (e) { errv = String(e); __test_callback('onDone'); });
        """)
        let completed = await harness.waitForAsync(timeout: 5.0) { done }
        #expect(completed, "Promise should reject")
        harness.expectTrue("errv.indexOf('source') !== -1")
    }
}

// MARK: - Base64 variant

/// Integration tests for HSImage.transcodeToBase64Async — the in-memory sibling
/// that hands the encoded bytes back as base64 (no temp file), used where the
/// caller needs a webview data: URL or a network payload rather than a file.
@Suite("HSImage.transcodeToBase64Async")
struct HSImageTranscodeBase64IntegrationTests {
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.context.setObject(HSImage.self, forKeyedSubscript: "HSImage" as NSString)
        return harness
    }

    @Test("transcodeToBase64Async is a function")
    func testIsFunction() {
        makeHarness().expectTrue("typeof HSImage.transcodeToBase64Async === 'function'")
    }

    @Test("downscales and resolves with b64/width/height/bytes — no file on disk")
    @MainActor
    func testDownscaleToBase64() async throws {
        let harness = makeHarness()
        let src = try #require(makeSolidPNG(width: 400, height: 200))
        let b64 = try Data(contentsOf: URL(fileURLWithPath: src)).base64EncodedString()
        defer { try? FileManager.default.removeItem(atPath: src) }

        var done = false
        harness.registerCallback("onDone") { done = true }
        harness.eval("""
        var res, errv;
        HSImage.transcodeToBase64Async({
            src: { dataB64: '\(b64)' }, maxEdge: 64, format: 'jpeg', quality: 0.8
        }).then(function (r) { res = r; __test_callback('onDone'); })
          .catch(function (e) { errv = String(e); __test_callback('onDone'); });
        """)

        let completed = await harness.waitForAsync(timeout: 5.0) { done }
        #expect(completed, "Promise should resolve")
        harness.expectTrue("!errv")
        // Longest edge clamped to 64; aspect ratio preserved (400×200 → 64×32).
        harness.expectTrue("res && res.width === 64 && res.height === 32")
        harness.expectTrue("res.bytes > 0")
        // The payload comes back as a non-empty base64 string (no `path` field).
        harness.expectTrue("typeof res.b64 === 'string' && res.b64.length > 0")
        harness.expectTrue("res.path === undefined")
    }

    @Test("the returned base64 round-trips back into a decodable image")
    @MainActor
    func testBase64RoundTrips() async throws {
        let harness = makeHarness()
        let src = try #require(makeSolidPNG(width: 200, height: 200))
        let b64 = try Data(contentsOf: URL(fileURLWithPath: src)).base64EncodedString()
        defer { try? FileManager.default.removeItem(atPath: src) }

        var done = false
        harness.registerCallback("onDone") { done = true }
        // Feed the result straight back through fromBase64 — proves the bytes are a
        // real encoded image, not a mangled string.
        harness.eval("""
        var ok, errv;
        HSImage.transcodeToBase64Async({ src: { dataB64: '\(b64)' }, maxEdge: 96, format: 'jpeg' })
          .then(function (r) { ok = !!HSImage.fromBase64(r.b64); __test_callback('onDone'); })
          .catch(function (e) { errv = String(e); __test_callback('onDone'); });
        """)

        let completed = await harness.waitForAsync(timeout: 5.0) { done }
        #expect(completed, "Promise should resolve")
        harness.expectTrue("!errv")
        harness.expectTrue("ok === true")
    }

    @Test("rejects when src is missing")
    func testRejectsMissingSrc() async {
        let harness = makeHarness()
        var done = false
        harness.registerCallback("onDone") { done = true }
        harness.eval("""
        var errv;
        HSImage.transcodeToBase64Async({ maxEdge: 64 })
            .catch(function (e) { errv = String(e); __test_callback('onDone'); });
        """)
        let completed = await harness.waitForAsync(timeout: 5.0) { done }
        #expect(completed, "Promise should reject")
        harness.expectTrue("errv.indexOf('src') !== -1")
    }
}
