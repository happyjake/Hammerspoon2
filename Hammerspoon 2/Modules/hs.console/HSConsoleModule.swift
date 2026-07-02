//
//  ConsoleModule.swift
//  Hammerspoon 2
//
//  Created by Chris Jones on 06/11/2025.
//

// TODO: Rename this to hs.log and have the UI talk about it as a Log Window. "Console" is more confusing than ever, given JavaScript.

import Foundation
import JavaScriptCore
import AppKit

// MARK: - Declare our JavaScript API

/// Module for controlling the Hammerspoon console
@objc protocol HSConsoleModuleAPI: JSExport {
    /// Open the console window
    /// - Example:
    /// ```js
    /// hs.console.open()
    /// ```
    @objc func open()

    /// Close the console window
    /// - Example:
    /// ```js
    /// hs.console.close()
    /// ```
    @objc func close()

    /// Clear all console output
    /// - Example:
    /// ```js
    /// hs.console.clear()
    /// ```
    @objc func clear()
}

// MARK: - Implementation

@_documentation(visibility: private)
@objc class HSConsoleModule: NSObject, HSModuleAPI, HSConsoleModuleAPI {
    var name = "hs.console"
    let engineID: UUID

    // MARK: - Module lifecycle
    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKDebug("Init of \(name): \(engineID)")
    }

    func shutdown() {}

    isolated deinit {
        AKDebug("Deinit of \(name): \(engineID)")
    }

    // MARK: - Window management

    @objc func open() {
        if let url = URL(string:"hammerspoon2://openConsole") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func close() {
        if let url = URL(string:"hammerspoon2://closeConsole") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Console output

    @objc func clear() {
        Task { @MainActor in
            HammerspoonLog.shared.clearLog()
        }
    }
}
