//
//  HSSwitcherModule.swift
//  Hammerspoon 2
//

import Foundation
import JavaScriptCore
import AppKit

// MARK: - JS API

/// Module for a cmd+Tab-replacement window/app switcher. Backed by the live
/// `HSWindowRegistry` (MRU observer cache) and Swift-owned eventtap, so
/// trigger latency and cycle latency stay sub-frame regardless of how many
/// apps are running.
@objc protocol HSSwitcherModuleAPI: JSExport {
    /// Enable the switcher with the given configuration.
    ///
    /// - Parameter cfg: Object with optional keys:
    ///   - `commitDelayMs` (number, default 250) — milliseconds of ctrl-idle
    ///     after which the highlighted selection is committed.
    ///   - `filterPlaceholder` (string, default "Type to filter…")
    ///   - `onCommit` (function, args: `{ appName, appPid, windowTitle, windowID }`)
    ///   - `onCancel` (function, no args)
    ///
    /// - Returns: `{ disable: function }` on success, or `{ error: string }`
    ///   on failure. The `error` is one of `"accessibility"`,
    ///   `"inputMonitoring"`, or a free-form string describing what went wrong.
    ///
    /// - Example:
    /// ```js
    /// const sw = hs.switcher.enable({
    ///   onCommit: e => console.log('switched to', e.appName)
    /// })
    /// if (sw.error) console.warn('switcher unavailable:', sw.error)
    /// // later: sw.disable()
    /// ```
    @objc func enable(_ cfg: JSValue) -> [String: Any]
}

// MARK: - Implementation

@_documentation(visibility: private)
@MainActor
@objc class HSSwitcherModule: NSObject, HSModuleAPI, HSSwitcherModuleAPI {
    var name = "hs.switcher"
    let engineID: UUID
    private var activeBindings: [HSSwitcherBinding] = []

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {
        for b in activeBindings { b.disable() }
        activeBindings.removeAll()
    }

    isolated deinit {
        AKTrace("Deinit of \(name): \(engineID)")
    }

    @objc func enable(_ cfg: JSValue) -> [String: Any] {
        guard AXIsProcessTrusted() else {
            return ["error": "accessibility"]
        }
        let config = HSSwitcherConfig(jsValue: cfg)
        let binding = HSSwitcherBinding(config: config)
        guard binding.install() else {
            return ["error": "inputMonitoring"]
        }
        activeBindings.append(binding)

        // Wrap disable as a JS-callable block.
        let disableBlock: @convention(block) () -> Void = { [weak self, weak binding] in
            MainActor.assumeIsolated {
                binding?.disable()
                if let b = binding { self?.activeBindings.removeAll { $0 === b } }
            }
        }
        return [
            "disable": unsafeBitCast(disableBlock, to: AnyObject.self),
        ]
    }
}

// MARK: - Config

/// Parsed config; defaults applied here so the session never sees a missing
/// field.
struct HSSwitcherConfig: @unchecked Sendable {
    let commitDelayMs: Int
    let filterPlaceholder: String
    let onCommit: JSValue?
    let onCancel: JSValue?

    init(jsValue: JSValue) {
        guard jsValue.isObject else {
            commitDelayMs = 250
            filterPlaceholder = "Type to filter…"
            onCommit = nil
            onCancel = nil
            return
        }
        let v = jsValue.forProperty("commitDelayMs")
        commitDelayMs = (v?.isNumber == true) ? Int(v!.toInt32()) : 250

        let fp = jsValue.forProperty("filterPlaceholder")
        filterPlaceholder = (fp?.isString == true) ? (fp!.toString() ?? "Type to filter…") : "Type to filter…"

        let oc = jsValue.forProperty("onCommit")
        onCommit = (oc?.isObject == true && !(oc?.isNull ?? true) && !(oc?.isUndefined ?? true)) ? oc : nil

        let on = jsValue.forProperty("onCancel")
        onCancel = (on?.isObject == true && !(on?.isNull ?? true) && !(on?.isUndefined ?? true)) ? on : nil
    }
}

// MARK: - Binding

/// One `enable()` call's binding: owns the double-tap detector and creates a
/// fresh session each time the user triggers the switcher.
@MainActor
final class HSSwitcherBinding {
    let config: HSSwitcherConfig
    private var detector: DoubleTapDetector?
    private var activeSession: HSSwitcherSession?

    init(config: HSSwitcherConfig) {
        self.config = config
    }

    func install() -> Bool {
        let det = DoubleTapDetector(modifier: .control, swiftCallback: { [weak self] in
            self?.onTrigger()
        })
        det.start()
        self.detector = det
        return true
    }

    func disable() {
        activeSession?.cancel()
        activeSession = nil
        detector?.stop()
        detector = nil
    }

    private func onTrigger() {
        if activeSession != nil { return }   // ignore re-triggers
        guard let registry = HSWindowModule.sharedRegistry() else { return }
        let session = HSSwitcherSession(config: config) { [weak self] in
            self?.activeSession = nil
        }
        _ = session.start(snapshot: registry.snapshot())
        activeSession = session
    }
}
