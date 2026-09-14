//
//  SettingsPermissionsView.swift
//  Hammerspoon 2
//
//  Created by Claude on 20/03/2026.
//  Reworked 2026-09-14: every permission this build's features need, each with why it is
//  needed, whether a fresh grant needs a relaunch, and a Relaunch button — the page a person
//  lands on after "permissions incomplete". The Settings window is a fixed 750×400, so the
//  list scrolls and never assumes a width of its own.
//

import SwiftUI

@_documentation(visibility: private)
struct PermissionRowView: View {
    let permType: PermissionsType
    let state: PermissionsState

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle.fill")
                .foregroundStyle(stateColor)
                .font(.system(size: 10))
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(permType.displayName)
                        .fontWeight(.medium)
                    Text(stateLabel)
                        .font(.caption)
                        .foregroundStyle(stateColor)
                }
                Text(permType.permissionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Used by: \(permType.usedBy)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let note = permType.relaunchNote {
                    Label(note, systemImage: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            actionButton
                .frame(width: 118, alignment: .trailing)
                .padding(.top, 1)
        }
        .padding(.vertical, 4)
    }

    private var stateLabel: String {
        switch state {
        case .trusted:    return "granted"
        case .notTrusted: return "not granted"
        case .unknown:    return "not decided"
        }
    }

    private var stateColor: Color {
        switch state {
        case .trusted:    return .green
        case .notTrusted: return .red
        case .unknown:    return .orange
        }
    }

    // Some permissions have a system prompt ("Request"), the rest only the pane.
    private var hasPrompt: Bool {
        switch permType {
        case .fullDiskAccess: return false
        default:              return true
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .trusted:
            Button("Granted") {}
                .disabled(true)
        case .unknown:
            if hasPrompt {
                Button("Request") { PermissionsManager.shared.request(permType) }
            } else {
                Button("Open Settings") { NSWorkspace.shared.open(permType.settingsURL) }
            }
        case .notTrusted:
            Button("Open Settings") { NSWorkspace.shared.open(permType.settingsURL) }
        }
    }
}

@_documentation(visibility: private)
struct SettingsPermissionsView: View {
    @State private var permissionStates: [PermissionsType: PermissionsState] = [:]
    @State private var refreshTimer: Timer?
    @State private var remainingAllowedAutoRefreshes = 100

    private var missingCount: Int {
        PermissionsType.panel.filter { (permissionStates[$0] ?? .unknown) != .trusted }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Verdict line + relaunch, pinned above the scrolling list.
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(missingCount == 0
                     ? "Every permission this build needs is granted."
                     : "\(missingCount) to grant. Rows are live: a grant that System Settings shows as on but tccd rejects reads as not granted here.")
                    .font(.callout)
                    .foregroundStyle(missingCount == 0 ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Relaunch Hammerspoon 2") { PermissionsManager.relaunchApp() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(PermissionsType.panel, id: \.self) { permType in
                        PermissionRowView(
                            permType: permType,
                            state: permissionStates[permType] ?? .unknown
                        )
                        if permType != PermissionsType.panel.last {
                            Divider()
                        }
                    }
                    Text("Grants are bound to this build’s signing certificate. After a reinstall under a different certificate they read as not granted even though System Settings shows them on: remove the stale entry (or `tccutil reset`), grant again, relaunch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            remainingAllowedAutoRefreshes = 100
            refreshPermissions()
            startObserving()
        }
        .onDisappear {
            stopObserving()
        }
    }

    private func refreshPermissions() {
        for permType in PermissionsType.panel {
            permissionStates[permType] = PermissionsManager.shared.state(permType)
        }
    }

    private func startObserving() {
        guard refreshTimer == nil else { return }
        guard remainingAllowedAutoRefreshes > 0 else { return }

        let timer = Timer(timeInterval: 5.0, repeats: true) { [self] _ in
            Task { @MainActor in
                refreshPermissions()
                remainingAllowedAutoRefreshes -= 1
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func stopObserving() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

#Preview {
    SettingsPermissionsView()
}
