//
//  HSMouseModule.swift
//  Hammerspoon 2
//

import Foundation
import JavaScriptCore
import CoreGraphics
import AppKit

// MARK: - Declare our JavaScript API

/// Module for controlling the mouse cursor
@objc protocol HSMouseModuleAPI: JSExport {
    /// The current mouse cursor position in global screen coordinates (top-left origin, points).
    ///
    /// Coordinates match `hs.screen` convention: `(0,0)` is the top-left of the primary
    /// display and `y` increases downward.
    /// - Returns: An object `{ x, y }`.
    /// - Example:
    /// ```js
    /// const p = hs.mouse.position(); console.log(p.x, p.y)
    /// ```
    @objc func position() -> [String: Double]

    /// Move (warp) the cursor to a global screen position (top-left origin).
    ///
    /// Coordinates use the same convention as `hs.screen`: `(0,0)` is the top-left of
    /// the primary display.
    /// - Parameter point: An object `{ x, y }`.
    /// - Returns: true.
    /// - Example:
    /// ```js
    /// hs.mouse.setPosition({ x: 200, y: 200 })
    /// ```
    @objc func setPosition(_ point: [String: Double]) -> Bool

    /// Hide the system mouse cursor.
    /// - Returns: true on success.
    /// - Example:
    /// ```js
    /// hs.mouse.hideCursor()
    /// ```
    @objc func hideCursor() -> Bool

    /// Show the system mouse cursor.
    /// - Returns: true on success.
    /// - Example:
    /// ```js
    /// hs.mouse.showCursor()
    /// ```
    @objc func showCursor() -> Bool

    /// Connect or disconnect physical mouse movement from the on-screen cursor.
    ///
    /// Pass `false` to decouple movement from the cursor position (useful for
    /// relative-delta capture, e.g. seamless hand-off to a remote machine).
    /// - Parameter connected: false to decouple movement from the cursor.
    /// - Returns: true.
    /// - Example:
    /// ```js
    /// hs.mouse.setAssociated(false)
    /// ```
    @objc func setAssociated(_ connected: Bool) -> Bool
}

// MARK: - Implementation

@_documentation(visibility: private)
@MainActor
@objc class HSMouseModule: NSObject, HSModuleAPI, HSMouseModuleAPI {
    var name = "hs.mouse"
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

    // MARK: - Coordinate helpers

    /// Height of the primary display in points, used to flip CG (y-up) to HS (y-down).
    private var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// Converts a CG point (bottom-left origin, y-up) to Hammerspoon coordinates
    /// (top-left origin, y-down) by flipping the Y axis against the primary screen height.
    private func cgToHS(_ pt: CGPoint) -> CGPoint {
        CGPoint(x: pt.x, y: primaryScreenHeight - pt.y)
    }

    /// Converts a Hammerspoon point (top-left origin, y-down) back to CG coordinates
    /// (bottom-left origin, y-up).
    private func hsToCG(_ pt: CGPoint) -> CGPoint {
        CGPoint(x: pt.x, y: primaryScreenHeight - pt.y)
    }

    // MARK: - HSMouseModuleAPI

    @objc func position() -> [String: Double] {
        let cgLoc = CGEvent(source: nil)?.location ?? .zero
        let hsLoc = cgToHS(cgLoc)
        return ["x": Double(hsLoc.x), "y": Double(hsLoc.y)]
    }

    @objc func setPosition(_ point: [String: Double]) -> Bool {
        let hsPoint = CGPoint(x: point["x"] ?? 0, y: point["y"] ?? 0)
        let cgPoint = hsToCG(hsPoint)
        CGWarpMouseCursorPosition(cgPoint)
        return true
    }

    @objc func hideCursor() -> Bool {
        CGDisplayHideCursor(CGMainDisplayID()) == .success
    }

    @objc func showCursor() -> Bool {
        CGDisplayShowCursor(CGMainDisplayID()) == .success
    }

    @objc func setAssociated(_ connected: Bool) -> Bool {
        CGAssociateMouseAndMouseCursorPosition(connected ? 1 : 0) == .success
        return true
    }
}
