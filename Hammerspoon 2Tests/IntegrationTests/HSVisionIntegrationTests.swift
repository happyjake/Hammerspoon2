//
//  HSVisionIntegrationTests.swift
//  Hammerspoon 2Tests
//
//  Integration tests for hs.vision — on-device OCR via the Vision framework.
//  Recognition runs fully offline with no permission prompts, so the behaviour
//  suite renders its own fixture images and asserts on real recognition output.
//

import Testing
import JavaScriptCore
import AppKit
@testable import Hammerspoon_2

// MARK: - Fixture rendering

/// Draws lines of large black-on-white text into a PNG and returns its path.
/// Each entry in `lines` is (text, baselineY) in the 480×240 point canvas —
/// remember AppKit drawing is bottom-left origin, so larger y = higher up.
@MainActor
private func makeTextFixture(_ lines: [(text: String, y: CGFloat)]) -> String? {
    let size = NSSize(width: 480, height: 240)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: size).fill()
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 42, weight: .bold),
        .foregroundColor: NSColor.black,
    ]
    for line in lines {
        (line.text as NSString).draw(at: NSPoint(x: 24, y: line.y), withAttributes: attrs)
    }
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return nil }
    let path = NSTemporaryDirectory() + "hsvision-test-\(UUID().uuidString).png"
    do {
        try png.write(to: URL(fileURLWithPath: path))
        return path
    } catch {
        return nil
    }
}

// MARK: - Suite 1: API structure

@Suite("hs.vision API structure tests")
struct HSVisionStructureTests {
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSVisionModule.self, as: "vision")
        return harness
    }

    @Test("recognizeText is a function")
    func testRecognizeTextIsFunction() {
        makeHarness().expectTrue("typeof hs.vision.recognizeText === 'function'")
    }

    @Test("supportedTextLanguages is a function")
    func testSupportedTextLanguagesIsFunction() {
        makeHarness().expectTrue("typeof hs.vision.supportedTextLanguages === 'function'")
    }

    @Test("recognizeText returns a thenable Promise")
    func testRecognizeTextReturnsPromise() {
        let harness = makeHarness()
        // Missing file still returns a (rejected) Promise, not null.
        harness.eval("var p = hs.vision.recognizeText('/nonexistent/nope.png'); p.catch(() => {})")
        harness.expectTrue("typeof p === 'object' && typeof p.then === 'function'")
        #expect(!harness.hasException)
    }

    @Test("recognizeText rejects on a missing file")
    func testRecognizeTextRejectsMissingFile() async {
        let harness = makeHarness()
        var rejected = false
        harness.registerCallback("onReject") { rejected = true }
        harness.eval("""
        var err;
        hs.vision.recognizeText('/nonexistent/nope.png').catch(function(e) {
            err = String(e);
            __test_callback('onReject');
        });
        """)
        let completed = await harness.waitForAsync(timeout: 5.0) { rejected }
        #expect(completed, "Promise should reject for a missing file")
        harness.expectTrue("err.indexOf('no file at') !== -1")
    }

    @Test("recognizeText rejects on invalid input type")
    func testRecognizeTextRejectsInvalidInput() async {
        let harness = makeHarness()
        var rejected = false
        harness.registerCallback("onReject") { rejected = true }
        harness.eval("hs.vision.recognizeText(42).catch(() => __test_callback('onReject'))")
        let completed = await harness.waitForAsync(timeout: 5.0) { rejected }
        #expect(completed, "Promise should reject for a numeric input")
    }

    @Test("supportedTextLanguages returns a non-empty array including en-US")
    func testSupportedTextLanguages() {
        let harness = makeHarness()
        harness.eval("var langs = hs.vision.supportedTextLanguages()")
        harness.expectTrue("Array.isArray(langs)")
        harness.expectTrue("langs.length > 0")
        harness.expectTrue("langs.indexOf('en-US') !== -1")
        #expect(!harness.hasException)
    }
}

// MARK: - Suite 2: recognition behaviour

@Suite("hs.vision text recognition tests", .serialized)
struct HSVisionRecognitionTests {
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.loadModule(HSVisionModule.self, as: "vision")
        return harness
    }

    @Test("recognizes rendered text from a file path with sane geometry")
    func testRecognizeFromPath() async throws {
        let path = try #require(await makeTextFixture([("HELLO WORLD 42", 100)]))
        defer { try? FileManager.default.removeItem(atPath: path) }

        let harness = makeHarness()
        var resolved = false
        harness.registerCallback("onResolve") { resolved = true }
        harness.eval("""
        var r;
        hs.vision.recognizeText('\(path)').then(function(result) {
            r = result;
            __test_callback('onResolve');
        }).catch(function(e) {
            r = { error: String(e) };
            __test_callback('onResolve');
        });
        """)

        // First call loads the recognition model — allow generous headroom.
        let completed = await harness.waitForAsync(timeout: 15.0) { resolved }
        #expect(completed, "recognizeText should settle")
        harness.expectTrue("r && !r.error")
        harness.expectTrue("r.text.indexOf('HELLO') !== -1")
        harness.expectTrue("r.text.indexOf('42') !== -1")
        harness.expectTrue("Array.isArray(r.lines) && r.lines.length >= 1")
        harness.expectTrue("typeof r.width === 'number' && r.width > 0")
        harness.expectTrue("typeof r.height === 'number' && r.height > 0")
        // Geometry: percentages with a top-left origin, sane confidence.
        harness.expectTrue("""
        r.lines.every(function(l) {
            return l.x >= 0 && l.x <= 100 && l.y >= 0 && l.y <= 100 &&
                   l.w > 0 && l.w <= 100 && l.h > 0 && l.h <= 100 &&
                   l.confidence >= 0 && l.confidence <= 1 &&
                   typeof l.text === 'string' && l.text.length > 0;
        })
        """)
        #expect(!harness.hasException)
    }

    @Test("two stacked lines come out in top-to-bottom order (upper-left origin)")
    func testCoordinateOriginIsTopLeft() async throws {
        // AppKit draw() is bottom-left origin: y=160 is the UPPER line.
        let path = try #require(await makeTextFixture([
            ("FIRST TITLE LINE", 160),
            ("second body line", 50),
        ]))
        defer { try? FileManager.default.removeItem(atPath: path) }

        let harness = makeHarness()
        var resolved = false
        harness.registerCallback("onResolve") { resolved = true }
        harness.eval("""
        var r;
        hs.vision.recognizeText('\(path)').then(function(result) {
            r = result;
            __test_callback('onResolve');
        }).catch(function(e) {
            r = { error: String(e), lines: [] };
            __test_callback('onResolve');
        });
        """)

        let completed = await harness.waitForAsync(timeout: 15.0) { resolved }
        #expect(completed, "recognizeText should settle")
        harness.expectTrue("r && !r.error")
        harness.expectTrue("r.lines.length >= 2")
        // The FIRST line (drawn higher on the canvas) must have the smaller y.
        harness.expectTrue("""
        (function() {
            var first = r.lines.filter(function(l) { return l.text.indexOf('FIRST') !== -1; })[0];
            var second = r.lines.filter(function(l) { return l.text.indexOf('second') !== -1; })[0];
            return first && second && first.y < second.y;
        })()
        """)
        #expect(!harness.hasException)
    }

    @Test("accepts an HSImage as input")
    func testRecognizeFromHSImage() async throws {
        let path = try #require(await makeTextFixture([("BRIDGE INPUT", 100)]))
        defer { try? FileManager.default.removeItem(atPath: path) }

        let harness = makeHarness()
        var resolved = false
        harness.registerCallback("onResolve") { resolved = true }
        harness.eval("""
        var r;
        var img = HSImage.fromPath('\(path)');
        hs.vision.recognizeText(img).then(function(result) {
            r = result;
            __test_callback('onResolve');
        }).catch(function(e) {
            r = { error: String(e) };
            __test_callback('onResolve');
        });
        """)

        let completed = await harness.waitForAsync(timeout: 15.0) { resolved }
        #expect(completed, "recognizeText should settle")
        harness.expectTrue("r && !r.error")
        harness.expectTrue("r.text.indexOf('BRIDGE') !== -1")
        #expect(!harness.hasException)
    }

    @Test("minConfidence: 1.1 threshold filters every line out")
    func testMinConfidenceFilters() async throws {
        let path = try #require(await makeTextFixture([("FILTER ME OUT", 100)]))
        defer { try? FileManager.default.removeItem(atPath: path) }

        let harness = makeHarness()
        var resolved = false
        harness.registerCallback("onResolve") { resolved = true }
        harness.eval("""
        var r;
        hs.vision.recognizeText('\(path)', { minConfidence: 1.1 }).then(function(result) {
            r = result;
            __test_callback('onResolve');
        }).catch(function(e) {
            r = { error: String(e) };
            __test_callback('onResolve');
        });
        """)

        let completed = await harness.waitForAsync(timeout: 15.0) { resolved }
        #expect(completed, "recognizeText should settle")
        harness.expectTrue("r && !r.error")
        harness.expectTrue("r.lines.length === 0")
        harness.expectTrue("r.text === ''")
        #expect(!harness.hasException)
    }
}
