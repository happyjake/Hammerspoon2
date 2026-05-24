//
//  HSSwitcherState.swift
//  Hammerspoon 2
//

import Foundation
import Observation

/// Per-session state for the switcher picker. Pure data + selection logic —
/// no AX, no UI, no events. SwiftUI views observe this via @Bindable; the
/// session mutates it in response to key intents.
@MainActor
@Observable
final class HSSwitcherState {
    enum Mode { case cycle, filter }

    /// Snapshot taken at session start. Frozen for the session's duration —
    /// changes to the registry after open don't reflow the picker.
    var apps: [HSAppEntry] = []

    /// Index into `filteredApps()`. -1 if no apps.
    var selectedAppIndex: Int = -1

    /// Index into `filteredApps()[selectedAppIndex].windows`. -1 if no windows.
    var selectedWindowIndex: Int = -1

    /// Cycle mode by default; filter mode entered on first non-cycle keystroke.
    var mode: Mode = .cycle

    /// Filter text. Empty in cycle mode; populated in filter mode.
    var filterText: String = ""

    /// Computed filtered view. In cycle mode this is `apps`; in filter mode,
    /// apps whose name matches or that have at least one window-title match.
    func filteredApps() -> [HSAppEntry] {
        guard mode == .filter, !filterText.isEmpty else { return apps }
        let needle = filterText.lowercased()
        return apps.filter { app in
            if app.name.lowercased().contains(needle) { return true }
            return app.windows.contains { $0.title.lowercased().contains(needle) }
        }
    }

    /// Move app selection forward (delta=+1) or back (delta=-1), wrapping.
    func moveAppSelection(by delta: Int) {
        let list = filteredApps()
        guard !list.isEmpty else { return }
        if selectedAppIndex < 0 {
            selectedAppIndex = 0
            selectedWindowIndex = list[0].windows.isEmpty ? -1 : 0
            return
        }
        let n = list.count
        let clamped = max(0, min(selectedAppIndex, n - 1))
        let next = ((clamped + delta) % n + n) % n
        selectedAppIndex = next
        selectedWindowIndex = list[next].windows.isEmpty ? -1 : 0
    }

    /// Move window selection within the highlighted app.
    func moveWindowSelection(by delta: Int) {
        let list = filteredApps()
        guard selectedAppIndex >= 0, selectedAppIndex < list.count else { return }
        let windows = list[selectedAppIndex].windows
        guard !windows.isEmpty else { return }
        let n = windows.count
        let clamped = max(0, min(selectedWindowIndex, n - 1))
        let next = ((clamped + delta) % n + n) % n
        selectedWindowIndex = next
    }

    /// Returns the currently-highlighted (app, window) pair, if any.
    /// `window` may be nil if the app has no windows visible to AX — caller
    /// should fall back to app activation.
    func currentSelection() -> (HSAppEntry, HSWindowEntry?)? {
        let list = filteredApps()
        guard selectedAppIndex >= 0, selectedAppIndex < list.count else { return nil }
        let app = list[selectedAppIndex]
        if selectedWindowIndex < 0 || selectedWindowIndex >= app.windows.count {
            return (app, nil)
        }
        return (app, app.windows[selectedWindowIndex])
    }

    /// Apply default cmd+Tab-style selection: MRU[1] app's MRU[0] window.
    /// If only one app is visible, fall back to its MRU[1] window if any.
    func applyDefaultSelection() {
        guard !apps.isEmpty else { return }
        if apps.count >= 2 {
            selectedAppIndex = 1
            let w = apps[1].windows
            selectedWindowIndex = w.isEmpty ? -1 : 0
        } else {
            selectedAppIndex = 0
            let w = apps[0].windows
            selectedWindowIndex = w.count >= 2 ? 1 : (w.isEmpty ? -1 : 0)
        }
    }
}
