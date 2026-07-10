//
//  HSImage.swift
//  Hammerspoon 2
//
//  Created by Claude Code on 26/02/2026.
//

import Foundation
import JavaScriptCore
import AppKit
import ImageIO
import UniformTypeIdentifiers
import Observation

// ---------------------------------------------------------------
// MARK: - Bridge Class (JavaScript Interface)
// ---------------------------------------------------------------

/// Bridge type for working with images in JavaScript
///
/// HSImage provides a comprehensive API for loading, manipulating, and saving images.
/// It supports various image sources including files, system icons, app bundles, and URLs.
///
/// ## Loading Images
///
/// ```javascript
/// // Load from file
/// const img = HSImage.fromPath("/path/to/image.png")
///
/// // Load system image
/// const icon = HSImage.fromName("NSComputer")
///
/// // Load app icon
/// const appIcon = HSImage.fromAppBundle("com.apple.Safari")
///
/// // Load from URL (asynchronous with Promise)
/// HSImage.fromURL("https://example.com/image.png")
///     .then(image => console.log("Image loaded:", image.size))
///     .catch(err => console.error("Failed to load image:", err))
///
/// // Or with async/await
/// const image = await HSImage.fromURL("https://example.com/image.png")
/// ```
///
/// ## Image Manipulation
///
/// ```javascript
/// const img = HSImage.fromPath("/path/to/image.png")
///
/// // Get size
/// const size = img.size  // Returns HSSize
///
/// // Resize image (mutates in place)
/// img.size = HSSize(100, 100)
///
/// // Crop image
/// const cropped = img.croppedCopy(HSRect(10, 10, 50, 50))
///
/// // Save to file
/// img.saveToFile("/path/to/output.png")
/// ```
@objc protocol HSImageAPI: HSTypeAPI, JSExport {
    /// Load an image from a file path
    /// - Parameter path: Path to the image file
    /// - Returns: An HSImage object, or null if the file couldn't be loaded
    /// - Example:
    /// ```js
    /// const img = HSImage.fromPath("/path/to/image.png")
    /// ```
    @objc static func fromPath(_ path: String) -> HSImage?

    /// Load a system image by name
    /// - Parameter name: Name of the system image (e.g., "NSComputer", "NSFolder")
    /// - Returns: An HSImage object, or null if the image couldn't be found
    /// - Example:
    /// ```js
    /// const icon = HSImage.fromName("NSComputer")
    /// ```
    @objc static func fromName(_ name: String) -> HSImage?

    /// Load a system symbol by name
    /// - Parameter name: Name of the symbol (e.g., "hammer", "questionmark.circle")
    /// - Returns: An HSImage object, or null if the symbol couldn't be found
    /// - Example:
    /// ```js
    /// const sym = HSImage.fromSymbol("star.fill")
    /// ```
    @objc static func fromSymbol(_ name: String) -> HSImage?

    /// Load an app's icon by bundle identifier
    /// - Parameters:
    ///   - bundleID: Bundle identifier of the application
    ///   - withFallbackSymbol?: The name of an SF Symbol to use if no bundle image could be loaded. Defaults to questionmark.circle
    /// - Returns: An HSImage object, or null if the app couldn't be found
    /// - Example:
    /// ```js
    /// const appIcon = HSImage.fromAppBundle("com.apple.Safari")
    /// ```
    @objc static func fromAppBundle(_ bundleID: String, _ withFallbackSymbol: String) -> HSImage?

    /// Get the icon for a file
    /// - Parameter path: Path to the file
    /// - Returns: An HSImage object representing the file's icon
    /// - Example:
    /// ```js
    /// const icon = HSImage.iconForFile("/Applications/Safari.app")
    /// ```
    @objc static func iconForFile(_ path: String) -> HSImage?

    /// Get the icon for a file type
    /// - Parameter fileType: File extension or UTI (e.g., "png", "public.png")
    /// - Returns: An HSImage object representing the file type's icon
    /// - Example:
    /// ```js
    /// const icon = HSImage.iconForFileType("pdf")
    /// ```
    @objc static func iconForFileType(_ fileType: String) -> HSImage?

    /// Create an empty (fully transparent) image. Useful as a placeholder
    /// for pre-allocated image slots that should render nothing when no
    /// content is bound.
    /// - Returns: An HSImage wrapping a 1×1 fully-transparent NSImage
    /// - Example:
    /// ```js
    /// const blank = HSImage.empty()
    /// ```
    @objc static func empty() -> HSImage

    /// Load an image from a URL (asynchronous)
    /// - Parameter url: URL string of the image
    /// - Returns: {Promise<HSImage>} A Promise that resolves to the loaded image, or rejects on error
    /// - Example:
    /// ```js
    /// const img = await HSImage.fromURL("https://example.com/image.png")
    /// ```
    @objc static func fromURL(_ url: String) -> JSPromise?

    /// Create an image from base64-encoded image data (PNG, JPEG, TIFF, GIF, etc.).
    /// This is the inverse of `encode()` — any base64 string produced by `encode()` round-trips.
    /// Whitespace/newlines in the base64 input are ignored.
    /// - Parameter base64: Image file data encoded as a base64 string
    /// - Returns: An HSImage object, or null if the data is not valid base64 or not a decodable image
    /// - Example:
    /// ```js
    /// const img = HSImage.fromBase64(b64)
    /// if (img) hs.pasteboard.writeImage(img)
    /// ```
    @objc static func fromBase64(_ base64: String) -> HSImage?

    /// Decode an image (from raw bytes or a file), optionally downscale it, and
    /// re-encode it to a destination file — entirely off the main thread.
    ///
    /// Use this instead of `saveToFile()` / `encode()` for any large or
    /// untrusted image. Those run a **synchronous, full-bitmap** decode+encode on
    /// the main thread: a single large photo can block the whole app for tens of
    /// seconds and spike memory into the gigabytes. `transcodeToFileAsync` runs on
    /// a background queue via ImageIO and, when `maxEdge` is set, **downsamples
    /// during decode** — it never materialises the full-resolution bitmap.
    ///
    /// - Parameter options: A configuration object:
    ///     - `src`: the source, as `{ dataB64: "<base64 image bytes>" }` **or** `{ path: "/abs/path" }`
    ///     - `dest`: destination file path (required)
    ///     - `maxEdge`: longest-side pixel cap; omit or `0` to keep full resolution
    ///     - `format`: `"jpeg"` or `"png"`; if omitted, inferred from `dest`'s extension (default `png`)
    ///     - `quality`: JPEG quality `0.0`–`1.0` (default `0.8`; ignored for png)
    /// - Returns: {Promise<Object>} resolves to `{ path, width, height, bytes }`; rejects with an error string
    /// - Example:
    /// ```js
    /// // Make a 512px thumbnail of a clipboard image without blocking the UI:
    /// const info = await HSImage.transcodeToFileAsync({
    ///   src: { dataB64: hs.pasteboard.readData('public.png') },
    ///   dest: '/tmp/thumb.jpg', maxEdge: 512, format: 'jpeg', quality: 0.85,
    /// })
    /// console.log(info.width, info.height, info.bytes)
    /// ```
    @objc static func transcodeToFileAsync(_ options: JSValue) -> JSPromise?

    /// Decode an image (from raw bytes or a file), optionally downscale it, and
    /// re-encode it to a **base64 string returned directly** — entirely off the
    /// main thread, with no temp file.
    ///
    /// This is the in-memory sibling of `transcodeToFileAsync`. Use it when the
    /// caller needs the encoded bytes back as base64 (a webview `data:` URL, a
    /// network payload) rather than on disk — it avoids the
    /// transcode-to-file → read-back → delete round-trip. Same ImageIO core: with
    /// `maxEdge` set it **downsamples during decode** and never materialises the
    /// full-resolution bitmap, and the base64 encode also runs off-main.
    ///
    /// - Parameter options: A configuration object:
    ///     - `src`: the source, as `{ dataB64: "<base64 image bytes>" }` **or** `{ path: "/abs/path" }`
    ///     - `maxEdge`: longest-side pixel cap; omit or `0` to keep full resolution
    ///     - `format`: `"jpeg"` or `"png"` (default `png`)
    ///     - `quality`: JPEG quality `0.0`–`1.0` (default `0.8`; ignored for png)
    /// - Returns: {Promise<Object>} resolves to `{ b64, width, height, bytes }`; rejects with an error string
    /// - Example:
    /// ```js
    /// // Build a 600px JPEG thumbnail and drop it straight into a webview <img>:
    /// const info = await HSImage.transcodeToBase64Async({
    ///   src: { dataB64: hs.pasteboard.readData('public.png') },
    ///   maxEdge: 600, format: 'jpeg', quality: 0.82,
    /// })
    /// img.src = 'data:image/jpeg;base64,' + info.b64
    /// ```
    @objc static func transcodeToBase64Async(_ options: JSValue) -> JSPromise?

    /// The size of the image. Setting this resizes the image in place to the exact dimensions.
    /// - Example:
    /// ```js
    /// const img = HSImage.fromPath("/path/to/image.png")
    /// console.log(img.size)       // HSSize { w: 200, h: 150 }
    /// img.size = HSSize(100, 75)  // resize in place
    /// ```
    @objc var size: HSSize { get set }

    /// The name of the image, or null if not set.
    /// - Example:
    /// ```js
    /// const img = HSImage.fromName("NSComputer")
    /// console.log(img.name)  // "NSComputer"
    /// img.name = "MyIcon"
    /// ```
    @objc var name: String? { get set }

    /// Whether the image is a template image.
    ///
    /// Template images are tinted by the system to match the appearance context (e.g. menu bar icons).
    /// - Example:
    /// ```js
    /// const img = HSImage.fromSymbol("star.fill")
    /// img.template = true
    /// ```
    @objc var template: Bool { get set }

    /// Create a copy of the image
    /// - Returns: A new HSImage copy
    /// - Example:
    /// ```js
    /// const copy = img.copyImage()
    /// copy.size = HSSize(64, 64)
    /// ```
    @objc func copyImage() -> HSImage?

    /// Create a cropped copy of the image
    /// - Parameter rect: HSRect defining the crop area (x, y, w, h)
    /// - Returns: A new cropped HSImage, or null if the rect falls outside the image bounds
    /// - Example:
    /// ```js
    /// const cropped = img.croppedCopy(HSRect(10, 10, 80, 60))
    /// ```
    @objc func croppedCopy(_ rect: HSRect) -> HSImage?

    /// Save the image to a file
    /// - Parameter path: Destination file path (extension determines format: png, jpg, tiff, bmp, gif)
    /// - Returns: true if saved successfully, false otherwise
    /// - Example:
    /// ```js
    /// img.saveToFile("/tmp/output.png")
    /// ```
    @objc func saveToFile(_ path: String) -> Bool

    /// Replace this image's content.
    ///
    /// If this image is bound to a UI element, the canvas re-renders automatically.
    /// - Parameter value: {string | HSImage} A file path string (`~` is expanded) or another HSImage object
    /// - Example:
    /// ```js
    /// const reactive = HSImage.fromName("NSStatusAvailable")
    /// reactive.set("/path/to/image.png")
    /// reactive.set(HSImage.fromName("NSStatusUnavailable"))
    /// ```
    @objc func set(_ value: JSValue)

    /// Encode the image to a base64 string.
    /// - Parameters:
    ///   - format: `"jpeg"` or `"png"` (case-insensitive). Any other value is treated as `"png"`.
    ///   - quality: JPEG compression quality in the range `0.0` (maximum compression) to `1.0`
    ///     (maximum quality). Ignored when `format` is `"png"`.
    /// - Returns: A base64-encoded string of the encoded image data, or `null` if encoding failed.
    /// - Example:
    /// ```js
    /// const b64 = img.encode('jpeg', 0.8)
    /// ```
    @objc func encode(_ format: String, _ quality: Double) -> String?
}

@Observable
@objc class HSImage: NSObject, HSImageAPI {
    @objc var typeName = "HSImage"

    var image: NSImage

    init(image: NSImage) {
        self.image = image
        super.init()
    }

    // MARK: - Factory Methods

    @objc static func fromPath(_ path: String) -> HSImage? {
        let expandedPath = NSString(string: path).expandingTildeInPath
        guard let image = NSImage(contentsOfFile: expandedPath) else {
            AKError("HSImage: Failed to load image from path: \(path)")
            return nil
        }
        return image.toBridge()
    }

    @objc static func fromName(_ name: String) -> HSImage? {
        guard let image = NSImage(named: NSImage.Name(name)) else {
            AKError("HSImage: Failed to find system image named: \(name)")
            return nil
        }
        return image.toBridge()
    }

    @objc static func fromSymbol(_ name: String) -> HSImage? {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            AKError("HSImage: Failed to find symbol named: \(name)")
            return nil
        }
        return image.toBridge()
    }

    @objc static func fromAppBundle(_ bundleID: String, _ withFallbackSymbol: String) -> HSImage? {
        let fallbackSymbol = withFallbackSymbol == "undefined" ? "questionmark.circle" : withFallbackSymbol

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: appURL.path).toBridge()
        }
        return NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: nil)?.toBridge()
    }

    @objc static func iconForFile(_ path: String) -> HSImage? {
        let expandedPath = NSString(string: path).expandingTildeInPath
        return NSWorkspace.shared.icon(forFile: expandedPath).toBridge()
    }

    @objc static func iconForFileType(_ fileType: String) -> HSImage? {
        let image: NSImage
        if let uti = UTType(fileType) {
            image = NSWorkspace.shared.icon(for: uti)
        } else if let uti = UTType(filenameExtension: fileType) {
            image = NSWorkspace.shared.icon(for: uti)
        } else {
            AKError("HSImage: Failed to find icon for file type: \(fileType)")
            return nil
        }
        return image.toBridge()
    }

    @objc static func empty() -> HSImage {
        // 1×1 transparent NSImage — renders as nothing in Image(nsImage:).
        let image = NSImage(size: NSSize(width: 1, height: 1))
        return image.toBridge()
    }

    @objc static func fromURL(_ urlString: String) -> JSPromise? {
        guard let url = URL(string: urlString) else {
            AKError("HSImage: Invalid URL: \(urlString)")
            return JSEngine.shared.createRejectedPromise(with: "Invalid URL: \(urlString)")
        }

        return JSEngine.shared.createPromise { holder in
            Task { @MainActor in
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    guard let image = NSImage(data: data) else {
                        AKError("HSImage: Failed to create image from URL data")
                        holder.rejectWithMessage("Failed to create image from URL data")
                        return
                    }
                    holder.resolveWith(image.toBridge())
                } catch {
                    AKError("HSImage: Failed to load image from URL: \(error.localizedDescription)")
                    holder.rejectWithMessage("Failed to load image: \(error.localizedDescription)")
                }
            }
        }
    }

    // Primitive, Sendable result of an off-thread transcode — built off the main
    // thread, then handed back to JS on the main thread.
    private struct TranscodeOutput: Sendable {
        let path: String
        let width: Int
        let height: Int
        let bytes: Int
    }

    private enum TranscodeOutcome: Sendable {
        case success(TranscodeOutput)
        case failure(String)
    }

    // Same, for the in-memory (base64) variant — no file path, the bytes ride back
    // as a base64 string built off the main thread.
    private struct TranscodeB64Output: Sendable {
        let b64: String
        let width: Int
        let height: Int
        let bytes: Int
    }

    private enum TranscodeB64Outcome: Sendable {
        case success(TranscodeB64Output)
        case failure(String)
    }

    // Build the Promise in the CALLER's context (not JSEngine.shared's) so it is a
    // real thenable in whatever context invoked us — matters for tests, and for any
    // future multi-context use. The class is main-actor isolated by default, so the
    // @MainActor Promise helpers are usable directly; only the ImageIO transcode is
    // forced off-main (via a continuation), and `holder` never leaves the main actor.
    @objc static func transcodeToFileAsync(_ options: JSValue) -> JSPromise? {
        guard let context = JSContext.current() else { return nil }

        guard options.isObject else {
            return context.createRejectedPromise(with: "transcodeToFileAsync: options must be an object")
        }

        // Parse everything up-front on the main thread (JSValue must not cross threads).
        // A missing JS property reads back as a JSValue whose toString() is the literal
        // "undefined", so require a real string before accepting it.
        let destProp = options.forProperty("dest")
        let destRaw = (destProp?.isString == true) ? (destProp?.toString() ?? "") : ""
        guard !destRaw.isEmpty else {
            return context.createRejectedPromise(with: "transcodeToFileAsync: missing dest")
        }
        let destPath = NSString(string: destRaw).expandingTildeInPath

        var srcDataParsed: Data? = nil
        var srcURLParsed: URL? = nil
        if let src = options.forProperty("src"), src.isObject {
            if let b64 = src.forProperty("dataB64"), b64.isString,
               let data = Data(base64Encoded: b64.toString(), options: .ignoreUnknownCharacters) {
                srcDataParsed = data
            } else if let p = src.forProperty("path"), p.isString, !(p.toString().isEmpty) {
                srcURLParsed = URL(fileURLWithPath: NSString(string: p.toString()).expandingTildeInPath)
            }
        }
        guard srcDataParsed != nil || srcURLParsed != nil else {
            return context.createRejectedPromise(with: "transcodeToFileAsync: src must be { dataB64 } or { path }")
        }

        let maxEdge = Int(options.forProperty("maxEdge")?.toInt32() ?? 0)
        let fmt = (options.forProperty("format")?.toString() ?? "").lowercased()
        let lowerDest = destPath.lowercased()
        let isJpeg = fmt == "jpeg" || fmt == "jpg"
            || (fmt.isEmpty && (lowerDest.hasSuffix(".jpg") || lowerDest.hasSuffix(".jpeg")))
        let qualityValue = options.forProperty("quality")
        let quality = (qualityValue != nil && qualityValue!.isNumber) ? qualityValue!.toDouble() : 0.8

        // Capture only Sendable primitives in the off-main closure below.
        let srcData = srcDataParsed
        let srcURL = srcURLParsed
        return wrapAsyncInJSPromise(in: context) { holder in
            Task { @MainActor in
                let outcome: TranscodeOutcome = await withCheckedContinuation { cont in
                    DispatchQueue.global(qos: .userInitiated).async {
                        cont.resume(returning: HSImage.transcodeSync(
                            data: srcData, url: srcURL, destPath: destPath,
                            maxEdge: maxEdge, isJpeg: isJpeg, quality: quality
                        ))
                    }
                }
                switch outcome {
                case .success(let out):
                    holder.resolveWith([
                        "path": out.path,
                        "width": out.width,
                        "height": out.height,
                        "bytes": out.bytes,
                    ] as [String: Any])
                case .failure(let message):
                    AKError("HSImage.transcodeToFileAsync: \(message)")
                    holder.rejectWithMessage(message)
                }
            }
        }
    }

    @objc static func transcodeToBase64Async(_ options: JSValue) -> JSPromise? {
        guard let context = JSContext.current() else { return nil }

        guard options.isObject else {
            return context.createRejectedPromise(with: "transcodeToBase64Async: options must be an object")
        }

        // Parse the source on the main thread (JSValue must not cross threads).
        var srcDataParsed: Data? = nil
        var srcURLParsed: URL? = nil
        if let src = options.forProperty("src"), src.isObject {
            if let b64 = src.forProperty("dataB64"), b64.isString,
               let data = Data(base64Encoded: b64.toString(), options: .ignoreUnknownCharacters) {
                srcDataParsed = data
            } else if let p = src.forProperty("path"), p.isString, !(p.toString().isEmpty) {
                srcURLParsed = URL(fileURLWithPath: NSString(string: p.toString()).expandingTildeInPath)
            }
        }
        guard srcDataParsed != nil || srcURLParsed != nil else {
            return context.createRejectedPromise(with: "transcodeToBase64Async: src must be { dataB64 } or { path }")
        }

        let maxEdge = Int(options.forProperty("maxEdge")?.toInt32() ?? 0)
        // No dest extension to infer from, so default to png unless asked for jpeg.
        let fmt = (options.forProperty("format")?.toString() ?? "").lowercased()
        let isJpeg = fmt == "jpeg" || fmt == "jpg"
        let qualityValue = options.forProperty("quality")
        let quality = (qualityValue != nil && qualityValue!.isNumber) ? qualityValue!.toDouble() : 0.8

        let srcData = srcDataParsed
        let srcURL = srcURLParsed
        return wrapAsyncInJSPromise(in: context) { holder in
            Task { @MainActor in
                let outcome: TranscodeB64Outcome = await withCheckedContinuation { cont in
                    DispatchQueue.global(qos: .userInitiated).async {
                        cont.resume(returning: HSImage.transcodeToBase64Sync(
                            data: srcData, url: srcURL,
                            maxEdge: maxEdge, isJpeg: isJpeg, quality: quality
                        ))
                    }
                }
                switch outcome {
                case .success(let out):
                    holder.resolveWith([
                        "b64": out.b64,
                        "width": out.width,
                        "height": out.height,
                        "bytes": out.bytes,
                    ] as [String: Any])
                case .failure(let message):
                    AKError("HSImage.transcodeToBase64Async: \(message)")
                    holder.rejectWithMessage(message)
                }
            }
        }
    }

    // Shared decode core — runs off the main thread (nonisolated). Decodes through
    // CGImageSourceCreateThumbnailAtIndex so the source's EXIF orientation is baked
    // into the output pixels (kCGImageSourceCreateThumbnailWithTransform), so rotated
    // phone photos come out upright. Cap the longest edge at maxEdge when downscaling,
    // else at the source's own longest edge so a full-size pass is neither up- nor
    // downscaled. With `maxEdge` set it downsamples *during* decode, so a huge source
    // never inflates into a full-resolution bitmap.
    // String isn't Error, so (like TranscodeOutcome) use a small purpose enum
    // rather than Result. Not Sendable — it never crosses the continuation, the
    // two callers consume it synchronously on the same background queue.
    private enum DecodeOutcome {
        case success(CGImage)
        case failure(String)
    }

    private nonisolated static func decodeThumbnail(
        data: Data?, url: URL?, maxEdge: Int
    ) -> DecodeOutcome {
        let source: CGImageSource?
        if let data = data {
            source = CGImageSourceCreateWithData(data as CFData, nil)
        } else if let url = url {
            source = CGImageSourceCreateWithURL(url as CFURL, nil)
        } else {
            source = nil
        }
        guard let source = source, CGImageSourceGetCount(source) > 0 else {
            return .failure("could not read source image")
        }
        var opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        let thumbMax: Int
        if maxEdge > 0 {
            thumbMax = maxEdge
        } else {
            let srcProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            let srcW = (srcProps?[kCGImagePropertyPixelWidth] as? Int) ?? 0
            let srcH = (srcProps?[kCGImagePropertyPixelHeight] as? Int) ?? 0
            thumbMax = max(srcW, srcH)
        }
        if thumbMax > 0 {
            opts[kCGImageSourceThumbnailMaxPixelSize] = thumbMax
        }
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary) else {
            return .failure("could not decode source image")
        }
        return .success(image)
    }

    // File variant — encode straight to disk (CGImageDestinationCreateWithURL streams
    // to the file, so the full-size archive path never buffers the whole image).
    private nonisolated static func transcodeSync(
        data: Data?, url: URL?, destPath: String,
        maxEdge: Int, isJpeg: Bool, quality: Double
    ) -> TranscodeOutcome {
        let image: CGImage
        switch decodeThumbnail(data: data, url: url, maxEdge: maxEdge) {
        case .failure(let message): return .failure(message)
        case .success(let img): image = img
        }

        let utType: UTType = isJpeg ? .jpeg : .png
        let destURL = URL(fileURLWithPath: destPath)
        guard let dest = CGImageDestinationCreateWithURL(
            destURL as CFURL, utType.identifier as CFString, 1, nil
        ) else {
            return .failure("could not create destination at \(destPath)")
        }
        var destProps: [CFString: Any] = [:]
        if isJpeg {
            destProps[kCGImageDestinationLossyCompressionQuality] = max(0.0, min(1.0, quality))
        }
        CGImageDestinationAddImage(dest, image, destProps as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            return .failure("could not write \(destPath)")
        }

        let bytes = (try? FileManager.default.attributesOfItem(atPath: destPath)[.size]) as? Int ?? 0
        return .success(TranscodeOutput(
            path: destPath, width: image.width, height: image.height, bytes: bytes
        ))
    }

    // In-memory variant — encode to a CFData buffer, then base64 it. Everything here
    // runs on the background queue, so neither the encode nor the base64 touch main.
    private nonisolated static func transcodeToBase64Sync(
        data: Data?, url: URL?,
        maxEdge: Int, isJpeg: Bool, quality: Double
    ) -> TranscodeB64Outcome {
        let image: CGImage
        switch decodeThumbnail(data: data, url: url, maxEdge: maxEdge) {
        case .failure(let message): return .failure(message)
        case .success(let img): image = img
        }

        let utType: UTType = isJpeg ? .jpeg : .png
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            out as CFMutableData, utType.identifier as CFString, 1, nil
        ) else {
            return .failure("could not create image destination")
        }
        var destProps: [CFString: Any] = [:]
        if isJpeg {
            destProps[kCGImageDestinationLossyCompressionQuality] = max(0.0, min(1.0, quality))
        }
        CGImageDestinationAddImage(dest, image, destProps as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            return .failure("could not encode image")
        }

        let b64 = (out as Data).base64EncodedString()
        return .success(TranscodeB64Output(
            b64: b64, width: image.width, height: image.height, bytes: out.length
        ))
    }

    @objc static func fromBase64(_ base64: String) -> HSImage? {
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            AKError("HSImage: fromBase64 input is not valid base64")
            return nil
        }
        guard let image = NSImage(data: data) else {
            AKError("HSImage: Failed to decode image from base64 data (\(data.count) bytes)")
            return nil
        }
        return image.toBridge()
    }

    // MARK: - Properties

    @objc var size: HSSize {
        get { image.size.toBridge() }
        set { image = resizeImage(image, to: newValue.size) }
    }

    @objc var name: String? {
        get { image.name() }
        set { _ = image.setName(newValue) }
    }

    @objc var template: Bool {
        get { image.isTemplate }
        set { image.isTemplate = newValue }
    }

    // MARK: - Image Manipulation

    @objc func copyImage() -> HSImage? {
        guard let copiedImage = image.copy() as? NSImage else { return nil }
        return copiedImage.toBridge()
    }

    @objc func croppedCopy(_ rect: HSRect) -> HSImage? {
        guard let croppedImage = cropImage(image, to: rect.rect) else {
            AKError("HSImage: Failed to crop image (rect may fall outside image bounds)")
            return nil
        }
        return croppedImage.toBridge()
    }

    @objc func saveToFile(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)

        let fileType: NSBitmapImageRep.FileType
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": fileType = .jpeg
        case "tiff", "tif": fileType = .tiff
        case "bmp":         fileType = .bmp
        case "gif":         fileType = .gif
        default:            fileType = .png
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let imageData = bitmapRep.representation(using: fileType, properties: [:]) else {
            AKError("HSImage: Failed to convert image for saving")
            return false
        }

        do {
            try imageData.write(to: url)
            return true
        } catch {
            AKError("HSImage: Failed to save image: \(error.localizedDescription)")
            return false
        }
    }

    @objc func encode(_ format: String, _ quality: Double) -> String? {
        let fileType: NSBitmapImageRep.FileType = format.lowercased() == "jpeg" ? .jpeg : .png
        let properties: [NSBitmapImageRep.PropertyKey: Any] = fileType == .jpeg
            ? [.compressionFactor: quality]
            : [:]

        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let imageData = bitmapImage.representation(using: fileType, properties: properties) else {
            AKError("HSImage: Failed to encode image as \(format)")
            return nil
        }

        return imageData.base64EncodedString()
    }

    // MARK: - Reactive Mutation

    @objc func set(_ value: JSValue) {
        if let newImage = HSImage.fromJSValue(value) {
            image = newImage.image
        }
    }

    // MARK: - Internal Helpers

    /// Create an HSImage from a JSValue (supports HSImage objects or file path strings).
    /// Used by the hs.ui builder.
    static func fromJSValue(_ value: JSValue) -> HSImage? {
        if let hsImage = value.toObjectOf(HSImage.self) as? HSImage {
            return hsImage
        } else if value.isString, let path = value.toString() {
            return HSImage.fromPath(path)
        }
        return nil
    }

    private func resizeImage(_ source: NSImage, to targetSize: CGSize) -> NSImage {
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        source.draw(in: NSRect(origin: .zero, size: targetSize),
                    from: NSRect(origin: .zero, size: source.size),
                    operation: .copy,
                    fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    private func cropImage(_ source: NSImage, to rect: CGRect) -> NSImage? {
        guard CGRect(origin: .zero, size: source.size).contains(rect) else { return nil }

        let croppedImage = NSImage(size: rect.size)
        croppedImage.lockFocus()
        source.draw(in: NSRect(origin: .zero, size: rect.size),
                    from: NSRect(origin: rect.origin, size: rect.size),
                    operation: .copy,
                    fraction: 1.0)
        croppedImage.unlockFocus()
        return croppedImage
    }
}

// ---------------------------------------------------------------
// MARK: - Bridge Extension
// ---------------------------------------------------------------

extension NSImage {
    func toBridge() -> HSImage {
        HSImage(image: self)
    }
}
