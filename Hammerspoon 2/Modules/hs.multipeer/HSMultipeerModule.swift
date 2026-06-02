//
//  HSMultipeerModule.swift
//  Hammerspoon 2
//

import Foundation
import JavaScriptCore
import MultipeerConnectivity

// MARK: - Declare our JavaScript API

/// Module providing a best-effort MultipeerConnectivity data link.
///
/// This is the CrossMac **data plane** (bulk clipboard / images) — the reliable
/// **control plane** rides the ESP32 relay (`hs.serial` / `hs.ble`), never this.
/// `MCSession` runs over AWDL / peer-to-peer Wi-Fi / infrastructure, so no shared
/// router is required. Discovery uses Bonjour, so `NSBonjourServices` and
/// `NSLocalNetworkUsageDescription` must be present in Info.plist.
///
/// Recovery *policy* (when to `reset()`) lives in JavaScript; this module only
/// exposes honest peer events plus `start` / `stop` / `reset`.
@objc protocol HSMultipeerModuleAPI: JSExport {
    /// Create a Multipeer session.
    /// - Parameter config: `{ serviceType?, displayName?, context?, encryption? }`.
    ///   `serviceType` defaults to `"voicekb-cs"` (≤15 chars, `[a-z0-9-]`);
    ///   `displayName` defaults to this host's name; `context` (the shared invite
    ///   secret both peers must match) defaults to `"voicekb-mpc-v1"`;
    ///   `encryption` is `"required"` (default), `"optional"`, or `"none"`.
    /// - Returns: an `HSMPCSession` (call `start()` to begin advertising + browsing).
    /// - Example:
    /// ```js
    /// const s = hs.multipeer.session({ displayName: 'MacA-' + hs.appinfo.pid })
    /// s.onPeer((peer, state) => console.log(peer, state)).start()
    /// ```
    @objc func session(_ config: [String: Any]) -> HSMPCSession
}

// MARK: - Implementation

@_documentation(visibility: private)
@MainActor
@objc class HSMultipeerModule: NSObject, HSModuleAPI, HSMultipeerModuleAPI {
    var name = "hs.multipeer"
    let engineID: UUID

    private var sessions: [HSMPCSession] = []

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {
        for s in sessions { s.stop() }
        sessions.removeAll()
    }

    isolated deinit {
        AKTrace("Deinit of \(name): \(engineID)")
    }

    @objc func session(_ config: [String: Any]) -> HSMPCSession {
        let s = HSMPCSession(
            serviceType: (config["serviceType"] as? String) ?? "voicekb-cs",
            displayName: (config["displayName"] as? String) ?? (Host.current().localizedName ?? "Mac"),
            context: (config["context"] as? String) ?? "voicekb-mpc-v1",
            encryption: (config["encryption"] as? String) ?? "required")
        sessions.append(s)
        return s
    }
}
