//
//  HSSwitcherView.swift
//  Hammerspoon 2
//

import SwiftUI
import AppKit

/// SwiftUI list view for the switcher picker. @Bindable on `state` means
/// only the rows whose `isSelected` state changes will re-render on a
/// selection move.
struct HSSwitcherView: View {
    @Bindable var state: HSSwitcherState
    let placeholder: String
    let onPick: (_ appIdx: Int, _ windowIdx: Int) -> Void

    var body: some View {
        let apps = state.filteredApps()
        VStack(alignment: .leading, spacing: 0) {
            if state.mode == .filter || !state.filterText.isEmpty {
                searchHeader
                Divider()
            }
            if apps.isEmpty {
                Text("No matches")
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16).padding(.vertical, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(apps.enumerated()), id: \.element.pid) { appIdx, app in
                                appHeader(app: app, idx: appIdx)
                                    .id("a\(app.pid)")
                                ForEach(Array(app.windows.enumerated()), id: \.element.stableID) { winIdx, win in
                                    windowRow(app: app, win: win, appIdx: appIdx, winIdx: winIdx)
                                        .id("w\(win.stableID)")
                                }
                            }
                        }
                    }
                    .onChange(of: state.selectedAppIndex) { scrollToSelection(proxy) }
                    .onChange(of: state.selectedWindowIndex) { scrollToSelection(proxy) }
                }
            }
        }
        .frame(width: 640, height: 480, alignment: .topLeading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var searchHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            Text(state.filterText.isEmpty ? placeholder : state.filterText)
                .foregroundColor(state.filterText.isEmpty ? .secondary : .primary)
                .font(.system(size: 15, weight: .medium))
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    @ViewBuilder
    private func appHeader(app: HSAppEntry, idx: Int) -> some View {
        let isHighlighted = (idx == state.selectedAppIndex) && app.windows.isEmpty
        HStack(spacing: 10) {
            iconView(app: app)
            Text(app.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isHighlighted ? .white : .primary)
            Text("(\(app.windows.count))")
                .font(.system(size: 11))
                .foregroundColor(isHighlighted ? .white.opacity(0.7) : .secondary)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(isHighlighted ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onPick(idx, -1) }
    }

    @ViewBuilder
    private func windowRow(app: HSAppEntry, win: HSWindowEntry, appIdx: Int, winIdx: Int) -> some View {
        let isSelected = (appIdx == state.selectedAppIndex) && (winIdx == state.selectedWindowIndex)
        HStack(spacing: 10) {
            Spacer().frame(width: 32)
            Text(win.title.isEmpty ? "(untitled)" : win.title)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
        .background(isSelected ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onPick(appIdx, winIdx) }
    }

    /// Keep the highlighted row visible as arrow keys move it through the list.
    private func scrollToSelection(_ proxy: ScrollViewProxy) {
        let apps = state.filteredApps()
        guard state.selectedAppIndex >= 0, state.selectedAppIndex < apps.count else { return }
        let app = apps[state.selectedAppIndex]
        if state.selectedWindowIndex >= 0, state.selectedWindowIndex < app.windows.count {
            proxy.scrollTo("w\(app.windows[state.selectedWindowIndex].stableID)")
        } else {
            proxy.scrollTo("a\(app.pid)")
        }
    }

    @ViewBuilder
    private func iconView(app: HSAppEntry) -> some View {
        if let icon = app.icon {
            Image(nsImage: icon).resizable().frame(width: 22, height: 22)
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 22, height: 22)
        }
    }
}
