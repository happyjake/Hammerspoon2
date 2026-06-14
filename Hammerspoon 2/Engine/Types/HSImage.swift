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
///     .then(image => console.log("Image loaded:", image.size()))
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
/// const size = img.size()  // Returns HSSize
///
/// // Resize image
/// const resized = img.setSize({w: 100, h: 100}, false)  // Proportional
///
/// // Crop image
/// const cropped = img.croppedCopy({x: 10, y: 10, w: 50, h: 50})
///
/// // Save to file
/// img.saveToFile("/path/to/output.png")
/// ```
@objc protocol HSImageAPI: HSTypeAPI, JSExport {
    /// Load an image from a file path
    /// - Parameter path: Path to the image file
    /// - Returns: An HSImage object, or null if the file couldn't be loaded
    @objc static func fromPath(_ path: String) -> HSImage?

    /// Load a system image by name
    /// - Parameter name: Name of the system image (e.g., "NSComputer", "NSFolder")
    /// - Returns: An HSImage object, or null if the image couldn't be found
    @objc static func fromName(_ name: String) -> HSImage?

    /// Load an app's icon by bundle identifier
    /// - Parameter bundleID: Bundle identifier of the application
    /// - Returns: An HSImage object, or null if the app couldn't be found
    @objc static func fromAppBundle(_ bundleID: String) -> HSImage?

    /// Get the icon for a file
    /// - Parameter path: Path to the file
    /// - Returns: An HSImage object representing the file's icon
    @objc static func iconForFile(_ path: String) -> HSImage?

    /// Get the icon for a file type
    /// - Parameter fileType: File extension or UTI (e.g., "png", "public.png")
    /// - Returns: An HSImage object representing the file type's icon
    @objc static func iconForFileType(_ fileType: String) -> HSImage?

    /// Create an image from an SF Symbol name (e.g. "magnifyingglass",
    /// "gearshape", "terminal", "arrow.up.right.square"). Returns nil if
    /// the symbol name is not recognised by the system.
    /// - Parameter name: SF Symbol identifier
    /// - Returns: An HSImage wrapping the SF Symbol, or nil if the symbol name is not found
    /// - Example:
    /// ```js
    /// const img = HSImage.fromSymbol('magnifyingglass')
    /// ```
    @objc static func fromSymbol(_ name: String) -> HSImage?

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

    /// Get or set the image size
    /// - Parameter size: Optional HSSize to set (if provided, returns a resized copy)
    /// - Returns: The current size as HSSize, or a resized copy if size was provided
    @objc func size(_ size: JSValue) -> JSValue

    /// Get or set the image name
    /// - Parameter name: Optional name to set
    /// - Returns: The current or new name
    @objc func name(_ name: JSValue) -> String?

    /// Create a resized copy of the image
    /// - Parameters:
    ///   - size: Target size as HSSize
    ///   - absolute: If true, resize exactly to specified dimensions. If false, maintain aspect ratio
    /// - Returns: A new resized HSImage
    @objc func setSize(_ size: JSValue, _ absolute: Bool) -> HSImage?

    /// Create a copy of the image
    /// - Returns: A new HSImage copy
    @objc func copyImage() -> HSImage?

    /// Create a cropped copy of the image
    /// - Parameter rect: HSRect defining the crop area
    /// - Returns: A new cropped HSImage, or null if cropping failed
    @objc func croppedCopy(_ rect: JSValue) -> HSImage?

    /// Save the image to a file
    /// - Parameter path: Destination file path (extension determines format: png, jpg, tiff, bmp, gif)
    /// - Returns: true if saved successfully, false otherwise
    @objc func saveToFile(_ path: String) -> Bool

    /// Get or set the template image flag
    /// - Parameter state: Optional boolean to set template state
    /// - Returns: Current template state
    @objc func template(_ state: JSValue) -> Bool

    /// Replace the image with a new one, triggering a re-render if bound to a UI element
    /// - Parameter value: New image as an HSImage object or a file path string
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

    @objc static func fromAppBundle(_ bundleID: String) -> HSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            AKError("HSImage: Failed to find app with bundle ID: \(bundleID)")
            return nil
        }
        let image = NSWorkspace.shared.icon(forFile: appURL.path)
        return image.toBridge()
    }

    @objc static func iconForFile(_ path: String) -> HSImage? {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let image = NSWorkspace.shared.icon(forFile: expandedPath)
        return image.toBridge()
    }

    @objc static func iconForFileType(_ fileType: String) -> HSImage? {
        let image: NSImage

        // Try as UTI first
        if let uti = UTType(fileType) {
            image = NSWorkspace.shared.icon(for: uti)
        } else if let uti = UTType(filenameExtension: fileType) {
            // Try as file extension
            image = NSWorkspace.shared.icon(for: uti)
        } else {
            AKError("HSImage: Failed to find icon for file type: \(fileType)")
            return nil
        }

        return image.toBridge()
    }

    @objc static func fromSymbol(_ name: String) -> HSImage? {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            AKError("HSImage: Failed to find SF Symbol: \(name)")
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

    // Pure ImageIO transcode — runs off the main thread (nonisolated). With
    // `maxEdge` set, CGImageSourceCreateThumbnailAtIndex downsamples *during*
    // decode, so a huge source never inflates into a full-resolution bitmap.
    private nonisolated static func transcodeSync(
        data: Data?, url: URL?, destPath: String,
        maxEdge: Int, isJpeg: Bool, quality: Double
    ) -> TranscodeOutcome {
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

        let cgImage: CGImage?
        if maxEdge > 0 {
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxEdge,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary)
        } else {
            let opts: [CFString: Any] = [kCGImageSourceShouldCacheImmediately: true]
            cgImage = CGImageSourceCreateImageAtIndex(source, 0, opts as CFDictionary)
        }
        guard let image = cgImage else {
            return .failure("could not decode source image")
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

        let bytes = (try? FileManager.default.attributesOfItem(atPath: destPath)[.size] as? Int) ?? 0
        return .success(TranscodeOutput(
            path: destPath, width: image.width, height: image.height, bytes: bytes ?? 0
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

    @objc func size(_ sizeValue: JSValue) -> JSValue {
        if sizeValue.isUndefined || sizeValue.isNull {
            // Getter - return current size as HSSize
            let size = image.size
            let hsSize = CGSize(width: size.width, height: size.height).toBridge()
            if let context = JSContext.current() {
                return JSValue(object: hsSize, in: context)
            }
            return JSValue()
        } else {
            // Setter - return resized copy
            if let newSize = sizeValue.toCGSize() {
                let resizedImage = resizeImage(image, to: newSize, absolute: false)
                let hsImage = resizedImage.toBridge()
                if let context = JSContext.current() {
                    return JSValue(object: hsImage, in: context)
                }
            }
            return JSValue()
        }
    }

    @objc func name(_ nameValue: JSValue) -> String? {
        if nameValue.isUndefined || nameValue.isNull {
            // Getter
            return image.name()
        } else {
            // Setter
            if let newName = nameValue.toString() {
                image.setName(newName)
                return newName
            }
            return image.name()
        }
    }

    // MARK: - Image Manipulation

    @objc func setSize(_ sizeValue: JSValue, _ absolute: Bool) -> HSImage? {
        guard let targetSize = sizeValue.toCGSize() else {
            AKError("HSImage: Invalid size provided to setSize")
            return nil
        }

        let resizedImage = resizeImage(image, to: targetSize, absolute: absolute)
        return resizedImage.toBridge()
    }

    @objc func copyImage() -> HSImage? {
        guard let copiedImage = image.copy() as? NSImage else {
            return nil
        }
        return copiedImage.toBridge()
    }

    @objc func croppedCopy(_ rectValue: JSValue) -> HSImage? {
        guard let cropRect = rectValue.toCGRect() else {
            AKError("HSImage: Invalid rect provided to croppedCopy")
            return nil
        }

        guard let croppedImage = cropImage(image, to: cropRect) else {
            AKError("HSImage: Failed to crop image")
            return nil
        }

        return croppedImage.toBridge()
    }

    @objc func saveToFile(_ path: String) -> Bool {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)

        // Determine file type from extension
        let fileType: NSBitmapImageRep.FileType
        switch url.pathExtension.lowercased() {
        case "png":
            fileType = .png
        case "jpg", "jpeg":
            fileType = .jpeg
        case "tiff", "tif":
            fileType = .tiff
        case "bmp":
            fileType = .bmp
        case "gif":
            fileType = .gif
        default:
            fileType = .png  // Default to PNG
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let imageData = bitmapImage.representation(using: fileType, properties: [:]) else {
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

    @objc func template(_ stateValue: JSValue) -> Bool {
        if stateValue.isUndefined || stateValue.isNull {
            // Getter
            return image.isTemplate
        } else {
            // Setter
            if stateValue.isBoolean {
                let newState = stateValue.toBool()
                image.isTemplate = newState
                return newState
            }
            return image.isTemplate
        }
    }

    // MARK: - Mutation

    @objc func set(_ value: JSValue) {
        if let newImage = HSImage.fromJSValue(value) {
            image = newImage.image
        }
    }

    // MARK: - Helper Methods

    /// Create an HSImage from a JSValue (supports HSImage objects or file path strings)
    static func fromJSValue(_ value: JSValue) -> HSImage? {
        if let hsImage = value.toObjectOf(HSImage.self) as? HSImage {
            return hsImage
        } else if value.isString, let path = value.toString() {
            return HSImage.fromPath(path)
        }
        return nil
    }

    private func resizeImage(_ image: NSImage, to targetSize: CGSize, absolute: Bool) -> NSImage {
        let originalSize = image.size

        let newSize: CGSize
        if absolute {
            // Absolute sizing - use exact dimensions
            newSize = targetSize
        } else {
            // Proportional sizing - maintain aspect ratio
            let widthRatio = targetSize.width / originalSize.width
            let heightRatio = targetSize.height / originalSize.height
            let ratio = min(widthRatio, heightRatio)

            newSize = CGSize(
                width: originalSize.width * ratio,
                height: originalSize.height * ratio
            )
        }

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: originalSize),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()

        return newImage
    }

    private func cropImage(_ image: NSImage, to rect: CGRect) -> NSImage? {
        let imageRect = CGRect(origin: .zero, size: image.size)

        // Ensure crop rect is within image bounds
        guard imageRect.contains(rect) else {
            return nil
        }

        let croppedImage = NSImage(size: rect.size)
        croppedImage.lockFocus()

        let sourceRect = NSRect(x: rect.origin.x,
                               y: rect.origin.y,
                               width: rect.size.width,
                               height: rect.size.height)
        let destRect = NSRect(origin: .zero, size: rect.size)

        image.draw(in: destRect,
                   from: sourceRect,
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
    /// Convert NSImage to HSImage bridge type
    func toBridge() -> HSImage {
        HSImage(image: self)
    }
}

// ---------------------------------------------------------------
// MARK: - JSValue Convenience Extension
// ---------------------------------------------------------------

extension JSValue {
    /// Convert a JSValue to an NSImage
    /// Supports:
    /// - HSImage objects
    /// - File paths (strings)
    func toNSImage() -> NSImage? {
        if let bridge = self.toObjectOf(HSImage.self) as? HSImage {
            return bridge.image
        } else if self.isString, let path = self.toString() {
            return NSImage(contentsOfFile: NSString(string: path).expandingTildeInPath)
        }
        return nil
    }
}

