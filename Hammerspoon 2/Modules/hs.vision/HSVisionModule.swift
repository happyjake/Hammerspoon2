//
//  HSVisionModule.swift
//  Hammerspoon 2
//
//  On-device image analysis via Apple's Vision framework. The first capability
//  is text recognition (OCR) — the same engine that powers macOS Live Text.
//  Recognition runs entirely on-device; no network access and no TCC prompt.
//

import Foundation
import JavaScriptCore
import Vision
import AppKit
import ImageIO

@objc protocol HSVisionModuleAPI: JSExport {
    /// Recognize text in an image (OCR), returning each detected line of text with its
    /// position inside the image.
    ///
    /// The position of each line is reported as percentages of the image's size with a
    /// top-left origin — i.e. `x`/`y`/`w`/`h` can be used directly as CSS
    /// `left`/`top`/`width`/`height` percentage values for a Live Text-style overlay.
    ///
    /// - Parameter image: The image to analyse — either a file path string (`~` is expanded)
    ///   or an `HSImage` object
    /// - Parameter options: Optional settings object:
    ///   - `level`: `"accurate"` (default) or `"fast"`
    ///   - `languages`: array of language identifiers (e.g. `["en-US", "zh-Hans"]`).
    ///     When omitted, the language is detected automatically.
    ///   - `autoDetectLanguage`: automatically detect the language (default `true`)
    ///   - `correction`: apply language-model correction to the results (default `true`)
    ///   - `minConfidence`: drop lines with confidence below this `0.0`–`1.0` threshold (default `0`)
    ///   - `minTextHeight`: minimum text height to recognise, as a fraction of image height `0.0`–`1.0` (default `0`)
    ///   - `customWords`: array of out-of-lexicon words to recognise (e.g. product names)
    /// - Returns: {Promise<object>} A Promise resolving to
    ///   `{ text, width, height, lines }` where `text` is every recognized line joined with
    ///   newlines, `width`/`height` are the image's pixel dimensions, and `lines` is an array
    ///   of `{ text, confidence, x, y, w, h }` with coordinates in percent of the image size
    ///   (top-left origin)
    /// - Example:
    /// ```js
    /// const result = await hs.vision.recognizeText('~/Desktop/screenshot.png')
    /// console.log(`Found ${result.lines.length} lines of text`)
    /// for (const line of result.lines) {
    ///     console.log(`${line.text} @ ${line.x}%,${line.y}% (confidence ${line.confidence})`)
    /// }
    /// ```
    @objc func recognizeText(_ image: JSValue, _ options: JSValue) -> JSPromise?

    /// List the languages the text recognizer supports on this system.
    /// - Parameter level: Optional recognition level the query applies to —
    ///   `"accurate"` (default) or `"fast"` (the fast path supports fewer languages)
    /// - Returns: An array of language identifiers (e.g. `["en-US", "zh-Hans", ...]`)
    /// - Example:
    /// ```js
    /// const langs = hs.vision.supportedTextLanguages()
    /// console.log('OCR languages: ' + langs.join(', '))
    /// ```
    @objc func supportedTextLanguages(_ level: JSValue) -> [String]
}

@_documentation(visibility: private)
@MainActor
@objc class HSVisionModule: NSObject, HSModuleAPI, HSVisionModuleAPI {
    var name = "hs.vision"
    let engineID: UUID

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {}

    isolated deinit {
        AKTrace("Deinit of \(name): \(engineID)")
    }

    // What we hand to Vision. Both payloads are Sendable, so the actual
    // recognition can run off the main actor without ceremony.
    private enum VisionInput {
        case url(URL)
        case data(Data)
    }

    // MARK: - HSVisionModuleAPI

    @objc func recognizeText(_ image: JSValue, _ options: JSValue) -> JSPromise? {
        guard let context = JSContext.current() else { return nil }

        let input: VisionInput
        if image.isString, let path = image.toString() {
            let expanded = NSString(string: path).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expanded) else {
                AKError("hs.vision.recognizeText: no file at \(expanded)")
                return context.createRejectedPromise(with: "hs.vision.recognizeText: no file at \(expanded)")
            }
            input = .url(URL(fileURLWithPath: expanded))
        } else if let hsImage = image.toObjectOf(HSImage.self) as? HSImage {
            // TIFF data rather than a CGImage: Data is Sendable, so it crosses
            // into Vision's executor without concurrency friction.
            guard let tiff = hsImage.image.tiffRepresentation else {
                AKError("hs.vision.recognizeText: could not read bitmap data from HSImage")
                return context.createRejectedPromise(with: "hs.vision.recognizeText: could not read bitmap data from HSImage")
            }
            input = .data(tiff)
        } else {
            AKError("hs.vision.recognizeText: expected a file path string or an HSImage")
            return context.createRejectedPromise(with: "hs.vision.recognizeText: expected a file path string or an HSImage")
        }

        let request = Self.makeRequest(options: options)
        let minConfidence = Self.doubleOption(options, "minConfidence") ?? 0
        let visionInput = input

        return wrapAsyncInJSPromise(in: context) { holder in
            Task { @MainActor in
                do {
                    // perform() is nonisolated async — it hops off the main actor
                    // for the heavy lifting, so JS keeps running while we await.
                    let observations: [RecognizedTextObservation]
                    switch visionInput {
                    case .url(let url):   observations = try await request.perform(on: url)
                    case .data(let data): observations = try await request.perform(on: data)
                    }

                    var lines: [[String: Any]] = []
                    for observation in observations {
                        guard let candidate = observation.topCandidates(1).first else { continue }
                        guard Double(candidate.confidence) >= minConfidence else { continue }
                        // Project the normalized box into a 100×100 space with an
                        // upper-left origin: the result *is* CSS-ready percentages.
                        let box = observation.boundingBox.toImageCoordinates(
                            CGSize(width: 100, height: 100), origin: .upperLeft)
                        lines.append([
                            "text": candidate.string,
                            "confidence": (Double(candidate.confidence) * 100).rounded() / 100,
                            "x": Self.pct(box.origin.x),
                            "y": Self.pct(box.origin.y),
                            "w": Self.pct(box.width),
                            "h": Self.pct(box.height),
                        ])
                    }

                    let dimensions = Self.pixelDimensions(of: visionInput)
                    holder.resolveWith([
                        "text": lines.compactMap { $0["text"] as? String }.joined(separator: "\n"),
                        "width": Int(dimensions.width),
                        "height": Int(dimensions.height),
                        "lines": lines,
                    ] as [String: Any])
                } catch {
                    AKError("hs.vision.recognizeText: \(error.localizedDescription)")
                    holder.rejectWithMessage("hs.vision.recognizeText: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc func supportedTextLanguages(_ level: JSValue) -> [String] {
        var request = RecognizeTextRequest()
        if level.isString, level.toString()?.lowercased() == "fast" {
            request.recognitionLevel = .fast
        }
        return request.supportedRecognitionLanguages.map { Self.identifier(for: $0) }
    }

    // MARK: - Helpers

    private static func makeRequest(options: JSValue) -> RecognizeTextRequest {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        guard options.isObject else { return request }

        if let level = stringOption(options, "level"), level.lowercased() == "fast" {
            request.recognitionLevel = .fast
        }
        if let correction = boolOption(options, "correction") {
            request.usesLanguageCorrection = correction
        }
        if let autoDetect = boolOption(options, "autoDetectLanguage") {
            request.automaticallyDetectsLanguage = autoDetect
        }
        if let languages = options.objectForKeyedSubscript("languages")?.toArray() as? [String],
           !languages.isEmpty {
            request.recognitionLanguages = languages.map { Locale.Language(identifier: $0) }
            // An explicit language list overrides auto-detection unless the
            // caller also asked for it explicitly.
            if boolOption(options, "autoDetectLanguage") == nil {
                request.automaticallyDetectsLanguage = false
            }
        }
        if let minHeight = doubleOption(options, "minTextHeight") {
            request.minimumTextHeightFraction = Float(min(max(minHeight, 0), 1))
        }
        if let words = options.objectForKeyedSubscript("customWords")?.toArray() as? [String],
           !words.isEmpty {
            request.customWords = words
        }
        return request
    }

    private static func stringOption(_ options: JSValue, _ key: String) -> String? {
        guard options.isObject, let value = options.objectForKeyedSubscript(key), value.isString else { return nil }
        return value.toString()
    }

    private static func boolOption(_ options: JSValue, _ key: String) -> Bool? {
        guard options.isObject, let value = options.objectForKeyedSubscript(key), value.isBoolean else { return nil }
        return value.toBool()
    }

    private static func doubleOption(_ options: JSValue, _ key: String) -> Double? {
        guard options.isObject, let value = options.objectForKeyedSubscript(key), value.isNumber else { return nil }
        return value.toDouble()
    }

    private static func pct(_ value: CGFloat) -> Double {
        (Double(value) * 100).rounded() / 100
    }

    /// Reconstructs the conventional identifier ("en-US", "zh-Hans") from a
    /// Locale.Language. Vision reports fully-expanded languages ("en-Latn-US");
    /// the conventional form keeps the script only when there is no region to
    /// disambiguate ("zh-Hans" vs "zh-Hant"), matching the identifiers the
    /// classic VNRecognizeTextRequest API used.
    private static func identifier(for language: Locale.Language) -> String {
        guard let code = language.languageCode?.identifier else { return language.maximalIdentifier }
        if let region = language.region?.identifier { return "\(code)-\(region)" }
        if let script = language.script?.identifier { return "\(code)-\(script)" }
        return code
    }

    /// Pixel dimensions read from image metadata (no full decode), honoring
    /// EXIF orientation so they match the space Vision reports boxes in.
    private static func pixelDimensions(of input: VisionInput) -> CGSize {
        let source: CGImageSource?
        switch input {
        case .url(let url):   source = CGImageSourceCreateWithURL(url as CFURL, nil)
        case .data(let data): source = CGImageSourceCreateWithData(data as CFData, nil)
        }
        guard let source,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double else {
            return .zero
        }
        // EXIF orientations 5–8 are 90° rotations: width and height swap.
        if let orientation = properties[kCGImagePropertyOrientation] as? UInt32, orientation >= 5 {
            return CGSize(width: height, height: width)
        }
        return CGSize(width: width, height: height)
    }
}
