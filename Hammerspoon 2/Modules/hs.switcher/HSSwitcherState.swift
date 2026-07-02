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

    /// Index into the selected app's row list: `0..<windows.count` are window
    /// rows, then `windows.count..<windows.count+visibleTabs.count` are the
    /// browser-tab rows shown beneath them. -1 if the app has no rows at all.
    var selectedWindowIndex: Int = -1

    /// Cap on tab rows shown per browser app — keeps a tab-hoarder window
    /// from turning its column into a wall.
    static let maxVisibleTabs = 6

    /// Cycle mode by default; filter mode entered on first non-cycle keystroke.
    var mode: Mode = .cycle

    /// Filter text. Empty in cycle mode; populated in filter mode.
    var filterText: String = ""

    /// Computed filtered view. In cycle mode this is `apps`; in filter mode,
    /// apps whose name matches (literal substring OR pinyin substring), or
    /// that have at least one window-title or browser-tab match (same rules).
    func filteredApps() -> [HSAppEntry] {
        guard mode == .filter, !filterText.isEmpty else { return apps }
        let needle = filterText.lowercased()
        return apps.filter { app in
            if Self.matches(app.name, needle: needle) { return true }
            if app.windows.contains(where: { Self.matches($0.title, needle: needle) }) { return true }
            return app.switcherTabs.contains { Self.matches($0.title, needle: needle) }
        }
    }

    /// The browser-tab rows displayed for `app` right now: all of them in
    /// cycle mode, only the matching ones while filtering (a filter that
    /// matched the app by name still shows every tab), capped at
    /// `maxVisibleTabs` either way.
    func visibleTabs(for app: HSAppEntry) -> [HSSwitcherTab] {
        if app.switcherTabs.isEmpty { return [] }
        var tabs = app.switcherTabs
        if mode == .filter, !filterText.isEmpty {
            let needle = filterText.lowercased()
            let matching = tabs.filter { Self.matches($0.title, needle: needle) }
            if !matching.isEmpty { tabs = matching }
        }
        return Array(tabs.prefix(Self.maxVisibleTabs))
    }

    /// Total selectable rows in `app`'s column: its windows plus its visible
    /// tab rows.
    func rowCount(for app: HSAppEntry) -> Int {
        app.windows.count + visibleTabs(for: app).count
    }

    /// Substring match against the literal string and against its pinyin
    /// form so typing "weixin" matches "微信". Pinyin lookups are cached
    /// process-wide (PinyinCache).
    private static func matches(_ hay: String, needle: String) -> Bool {
        if hay.lowercased().contains(needle) { return true }
        let py = PinyinCache.shared.get(hay)
        return !py.isEmpty && py != hay.lowercased() && py.contains(needle)
    }

    /// Move app selection forward (delta=+1) or back (delta=-1), wrapping.
    func moveAppSelection(by delta: Int) {
        let list = filteredApps()
        guard !list.isEmpty else { return }
        if selectedAppIndex < 0 {
            selectedAppIndex = 0
            selectedWindowIndex = rowCount(for: list[0]) == 0 ? -1 : 0
            return
        }
        let n = list.count
        let clamped = max(0, min(selectedAppIndex, n - 1))
        let next = ((clamped + delta) % n + n) % n
        selectedAppIndex = next
        selectedWindowIndex = rowCount(for: list[next]) == 0 ? -1 : 0
    }

    /// Flat list of selectable rows in display order: one stop per window and
    /// per visible tab, plus one header stop (windowIndex -1) for each app
    /// with no rows at all.
    private func linearStops(in list: [HSAppEntry]) -> [(appIndex: Int, windowIndex: Int)] {
        var stops: [(appIndex: Int, windowIndex: Int)] = []
        for (a, app) in list.enumerated() {
            let rows = rowCount(for: app)
            if rows == 0 {
                stops.append((a, -1))
            } else {
                for r in 0..<rows { stops.append((a, r)) }
            }
        }
        return stops
    }

    /// Move the selection through the flat row list — what Up/Down should
    /// feel like in a vertical picker: windows in display order, crossing
    /// app boundaries, windowless apps as single header stops, wrapping at
    /// both ends.
    func moveLinearSelection(by delta: Int) {
        let stops = linearStops(in: filteredApps())
        guard !stops.isEmpty else { return }
        let next: Int
        if let cur = stops.firstIndex(where: {
            $0.appIndex == selectedAppIndex && $0.windowIndex == selectedWindowIndex
        }) {
            let n = stops.count
            next = ((cur + delta) % n + n) % n
        } else {
            // Unset or out-of-sync selection: enter the list at the end
            // nearest the travel direction.
            next = delta >= 0 ? 0 : stops.count - 1
        }
        (selectedAppIndex, selectedWindowIndex) = stops[next]
    }

    /// Move row selection (windows, then tabs) within the highlighted app.
    func moveWindowSelection(by delta: Int) {
        let list = filteredApps()
        guard selectedAppIndex >= 0, selectedAppIndex < list.count else { return }
        let n = rowCount(for: list[selectedAppIndex])
        guard n > 0 else { return }
        let clamped = max(0, min(selectedWindowIndex, n - 1))
        let next = ((clamped + delta) % n + n) % n
        selectedWindowIndex = next
    }

    /// Returns the currently-highlighted (app, window, tab) triple, if any.
    /// Exactly one of `window`/`tab` is non-nil for a row selection; both are
    /// nil when the app header is highlighted (no rows) — caller should fall
    /// back to app activation.
    func currentSelection() -> (app: HSAppEntry, window: HSWindowEntry?, tab: HSSwitcherTab?)? {
        let list = filteredApps()
        guard selectedAppIndex >= 0, selectedAppIndex < list.count else { return nil }
        let app = list[selectedAppIndex]
        if selectedWindowIndex >= 0, selectedWindowIndex < app.windows.count {
            return (app, app.windows[selectedWindowIndex], nil)
        }
        let tabs = visibleTabs(for: app)
        let tabIdx = selectedWindowIndex - app.windows.count
        if tabIdx >= 0, tabIdx < tabs.count {
            return (app, nil, tabs[tabIdx])
        }
        return (app, nil, nil)
    }

    /// Land the selection on what a just-changed filter is naming. Priority:
    /// the first matching browser TAB (switching into content beats raising a
    /// window — and a browser window's title is usually just its active tab's
    /// title, in which case that tab matches too and both land on the same
    /// page), then the first matching window title, then the first filtered
    /// app's first row (an app-name match). No-op on an empty filter.
    func selectBestFilterMatch() {
        guard mode == .filter, !filterText.isEmpty else { return }
        let list = filteredApps()
        guard !list.isEmpty else {
            selectedAppIndex = -1
            selectedWindowIndex = -1
            return
        }
        let needle = filterText.lowercased()
        // Tabs first — the user's target is the page, not the window frame.
        for (a, app) in list.enumerated() {
            let tabs = visibleTabs(for: app)
            if let t = tabs.firstIndex(where: { Self.matches($0.title, needle: needle) }) {
                selectedAppIndex = a
                selectedWindowIndex = app.windows.count + t
                return
            }
        }
        for (a, app) in list.enumerated() {
            if let w = app.windows.firstIndex(where: { Self.matches($0.title, needle: needle) }) {
                selectedAppIndex = a
                selectedWindowIndex = w
                return
            }
        }
        selectedAppIndex = 0
        selectedWindowIndex = rowCount(for: list[0]) == 0 ? -1 : 0
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
