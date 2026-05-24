//
//  HSWindowEntry.swift
//  Hammerspoon 2
//

import Foundation
import AppKit
import AXSwift

/// One window inside the live registry. Reference type so AXObserver callbacks
/// can mutate `title` / `lastFocusedAt` in place without copy semantics.
@MainActor
final class HSWindowEntry {
    let stableID: UInt64
    let axElement: UIElement
    var title: String
    var lastFocusedAt: Date

    init(stableID: UInt64, axElement: UIElement, title: String, lastFocusedAt: Date = Date()) {
        self.stableID = stableID
        self.axElement = axElement
        self.title = title
        self.lastFocusedAt = lastFocusedAt
    }
}
