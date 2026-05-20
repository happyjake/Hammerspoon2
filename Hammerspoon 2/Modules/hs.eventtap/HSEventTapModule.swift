//
//  HSEventTapModule.swift
//  Hammerspoon 2
//

import Foundation
import JavaScriptCore

// MARK: - Declare our JavaScript API

/// Module for creating CGEventTap-based global keyboard event monitors
@objc protocol HSEventTapModuleAPI: JSExport {
    /// Create a new event tap for the specified event types.
    /// Call .start() on the returned object to begin receiving events.
    /// Requires Input Monitoring permission.
    /// - Parameter eventTypes: Array of event type strings: 'keyDown', 'keyUp', 'flagsChanged'
    /// - Parameter callback: Function called with an event object. Return true to consume (suppress) the event.
    /// - Returns: An HSEventTap instance
    /// - Example:
    /// ```js
    /// const tap = hs.eventtap.make(['keyDown'], e => {
    ///   console.log(e.keyCode, e.modifiers)
    ///   return false // don't consume
    /// })
    /// tap.start()
    /// ```
    @objc(make::) func makeTap(_ eventTypes: [String], _ callback: JSValue) -> HSEventTap

    /// Synthesise a key stroke (M1 stub — lands in M3/M4).
    /// - Parameter mods: Array of modifier strings, e.g. ['cmd']
    /// - Parameter key: Key name, e.g. 'v'
    /// - Example:
    /// ```js
    /// hs.eventtap.keyStroke(['cmd'], 'v')
    /// ```
    @objc(keyStroke::) func keyStroke(_ mods: [String], _ key: String)

    /// Type a string by synthesising key events (M1 stub — lands in M4).
    /// - Parameter text: Text to type
    /// - Example:
    /// ```js
    /// hs.eventtap.typeText('Hello!')
    /// ```
    @objc func typeText(_ text: String)
}

// MARK: - Implementation

@_documentation(visibility: private)
@MainActor
@objc class HSEventTapModule: NSObject, HSModuleAPI, HSEventTapModuleAPI {
    var name = "hs.eventtap"
    let engineID: UUID

    private var createdTaps: [HSEventTap] = []

    // MARK: - Module lifecycle

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {
        for t in createdTaps { t.stop() }
        createdTaps.removeAll()
        AKTrace("Shutdown of \(name): \(engineID)")
    }

    isolated deinit {
        AKTrace("Deinit of \(name): \(engineID)")
    }

    // MARK: - API

    @objc(make::) func makeTap(_ eventTypes: [String], _ callback: JSValue) -> HSEventTap {
        let t = HSEventTap(eventTypes: eventTypes, callback: callback)
        createdTaps.append(t)
        return t
    }

    @objc(keyStroke::) func keyStroke(_ mods: [String], _ key: String) {
        AKWarning("hs.eventtap.keyStroke is not yet implemented in M1 — lands with M3/M4.")
    }

    @objc func typeText(_ text: String) {
        AKWarning("hs.eventtap.typeText is not yet implemented in M1 — lands with M4.")
    }
}
