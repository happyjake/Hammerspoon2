//
//  SettingsPermissionsView.swift
//  Hammerspoon 2
//
//  Created by Claude on 20/03/2026.
//  Reworked 2026-09-14: every permission this build's features need, each with why it is
//  needed, whether a fresh grant needs a relaunch, and a Relaunch button — the page a person
//  lands on after "permissions incomplete".
//

import SwiftUI

@_documentation(visibility: private)
struct PermissionRowView: View {
    let permType: PermissionsType
    let state: PermissionsState

    var body: some View {
        GridRow {
            trafficLight
                .gridColumnAlignment(.center)
            VStack(alignment: .leading, spacing: 3) {
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
            .gridColumnAlignment(.leading)
            actionButton
                .gridColumnAlignment(.trailing)
        }
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

    @ViewBuilder
    private var trafficLight: some View {
        Image(systemName: "circle.fill")
            .foregroundStyle(stateColor)
    }
}

@_documentation(visibility: private)
struct SettingsPermissionsView: View {
    @State private var permissionStates: [PermissionsType: PermissionsState] = [:]
    @State private var refreshTimer: Timer?
    @State private var isRefreshing = true
    @State private var remainingAllowedAutoRefreshes = 100

    private var missingCount: Int {
        PermissionsType.panel.filter { (permissionStates[$0] ?? .unknown) != .trusted }.count
    }

    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .frame(height: 12.0)
            .opacity(isRefreshing ? 1.0 : 0.0)
            .padding([.top])

        HStack {
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                Text(missingCount == 0
                     ? "Every permission this build needs is granted."
                     : "\(missingCount) permission\(missingCount == 1 ? "" : "s") still to grant. Rows are live: a grant that System Settings shows as on but tccd rejects reads as not granted here.")
                    .font(.callout)
                    .foregroundStyle(missingCount == 0 ? .secondary : .primary)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                    ForEach(PermissionsType.panel, id: \.self) { permType in
                        PermissionRowView(
                            permType: permType,
                            state: permissionStates[permType] ?? .unknown
                        )
                    }
                }

                Divider()

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Grants are bound to this build’s signing certificate. After a reinstall under a different certificate they read as not granted even though System Settings shows them on: remove the stale entry (or `tccutil reset`) and grant again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Accessibility and Input Monitoring only take effect for event taps opened after the grant — relaunch once you have granted them.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Relaunch Hammerspoon 2") { PermissionsManager.relaunchApp() }
                }
                Spacer()
            }
            .frame(width: 760)
            .padding(.vertical)
            Spacer()
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
                isRefreshing = false
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
