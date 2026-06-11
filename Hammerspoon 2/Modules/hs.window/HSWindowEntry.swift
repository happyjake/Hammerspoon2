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
    /// The subrole as last read. `nil` means the read failed (cold a11y under
    /// the seed timeout) — distinct from a positive `.standardWindow`, which
    /// the switcher uses to keep real-but-untitled windows pickable.
    var subrole: Role.Subrole?
    var lastFocusedAt: Date

    init(stableID: UInt64, axElement: UIElement, title: String,
         subrole: Role.Subrole? = nil, lastFocusedAt: Date = Date()) {
        self.stableID = stableID
        self.axElement = axElement
        self.title = title
        self.subrole = subrole
        self.lastFocusedAt = lastFocusedAt
    }
}
