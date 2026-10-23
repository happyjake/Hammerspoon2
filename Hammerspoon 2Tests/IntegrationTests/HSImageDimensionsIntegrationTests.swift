import Testing
import JavaScriptCore
import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import Hammerspoon_2

@Suite("HSImage.dimensionsOfFile")
@MainActor
struct HSImageDimensionsIntegrationTests {
    private func makeHarness(path: String) -> JSTestHarness {
        let harness = JSTestHarness()
        harness.context.setObject(HSImage.self, forKeyedSubscript: "HSImage" as NSString)
        harness.context.setObject(path, forKeyedSubscript: "imagePath" as NSString)
        return harness
    }

    // A pixel-sized bitmap avoids display scale and window-server dependencies.
    private func makeFixture(_ ext: String, dpi: Double = 72, orientation: Int = 1) throws -> URL {
        let context = try #require(CGContext(
            data: nil, width: 120, height: 80, bitsPerComponent: 8, bytesPerRow: 480,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        let image = try #require(context.makeImage())
        let type = try #require(UTType(filenameExtension: ext))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        let destination = try #require(CGImageDestinationCreateWithURL(
            url as CFURL, type.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi,
            kCGImagePropertyOrientation: orientation,
        ] as CFDictionary)
        let finalized = CGImageDestinationFinalize(destination)
        if !finalized { try? FileManager.default.removeItem(at: url) }
        try #require(finalized)
        return url
    }

    private func expectDimensions(_ harness: JSTestHarness, width: Double, height: Double) {
        harness.eval("var dimensions = HSImage.dimensionsOfFile(imagePath)")
        harness.expectTrue("dimensions !== null && typeof dimensions === 'object'")
        harness.expectTrue("Object.keys(dimensions).sort().join(',') === 'h,w'")
        harness.expectTrue("Math.abs(dimensions.w - \(width)) < 1e-9")
        harness.expectTrue("Math.abs(dimensions.h - \(height)) < 1e-9")
        harness.eval("var legacySize = HSImage.fromPath(imagePath).size")
        harness.expectTrue("Math.abs(dimensions.w - legacySize.w) < 1e-9")
        harness.expectTrue("Math.abs(dimensions.h - legacySize.h) < 1e-9")
        #expect(!harness.hasException)
    }

    @Test("reads dimensions of supported raster formats through JavaScript",
          arguments: ["png", "jpeg", "heic", "tiff"])
    func supportedFormats(_ ext: String) throws {
        let url = try makeFixture(ext)
        defer { try? FileManager.default.removeItem(at: url) }
        expectDimensions(makeHarness(path: url.path), width: 120, height: 80)
    }

    @Test("matches the oriented size of JPEG images", arguments: [
        (1, 120.0, 80.0), (2, 120.0, 80.0), (3, 120.0, 80.0), (4, 120.0, 80.0),
        (5, 80.0, 120.0), (6, 80.0, 120.0), (7, 80.0, 120.0), (8, 80.0, 120.0),
    ])
    func jpegOrientation(orientation: Int, width: Double, height: Double) throws {
        let url = try makeFixture("jpeg", orientation: orientation)
        defer { try? FileManager.default.removeItem(at: url) }
        expectDimensions(makeHarness(path: url.path), width: width, height: height)
    }

    @Test("matches resolution-adjusted PNG sizes", arguments: [(144.0, 60.0, 40.0), (300.0, 28.8, 19.2)])
    func pngResolution(dpi: Double, width: Double, height: Double) throws {
        let url = try makeFixture("png", dpi: dpi)
        defer { try? FileManager.default.removeItem(at: url) }
        expectDimensions(makeHarness(path: url.path), width: width, height: height)
    }

    @Test("applies both resolution and orientation")
    func rotatedHighResolutionJPEG() throws {
        let url = try makeFixture("jpeg", dpi: 144, orientation: 6)
        defer { try? FileManager.default.removeItem(at: url) }
        expectDimensions(makeHarness(path: url.path), width: 40, height: 60)
    }

    @Test("expands a home-relative path")
    func expandsTilde() throws {
        let url = try makeFixture("png")
        defer { try? FileManager.default.removeItem(at: url) }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let parents = home.pathComponents.dropFirst().map { _ in ".." }.joined(separator: "/")
        let path = "~/" + parents + url.path
        expectDimensions(makeHarness(path: path), width: 120, height: 80)
    }

    @Test("returns null for missing and non-image files")
    func invalidFiles() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
        defer { try? FileManager.default.removeItem(at: url) }
        let harness = makeHarness(path: url.path)
        harness.expectTrue("HSImage.dimensionsOfFile(imagePath) === null")
        try "not an image".write(to: url, atomically: true, encoding: .utf8)
        harness.expectTrue("HSImage.dimensionsOfFile(imagePath) === null")
        #expect(!harness.hasException)
    }
}
