//
//  HSMPCSession.swift
//  Hammerspoon 2
//
//  Ported from the proven ~/.hammerspoon/lib/ble_bridge.swift `MPCBridge`.
//  MCSession / advertiser / browser delegate callbacks arrive on a private
//  serial queue (NOT the main thread), so those methods are `nonisolated` and
//  hop to the main actor (via `Task { @MainActor }`) before touching JS / logging.
//
//  The invitation + foundPeer handlers must read the session synchronously on
//  that private queue. MCSession is not Sendable, so `session` is
//  `nonisolated(unsafe)`; every access is marked `unsafe` per the project's
//  strict-memory-safety house style. The session ref is only reassigned on the
//  main actor (during reset(), which is rare), so a slightly-stale read in an
//  invitation handler at worst accepts into a session that's being replaced —
//  harmless (the peer reconnects). The self-check and invite context use
//  Sendable mirrors (`myDisplayName`: String, `inviteContext`: Data).
//

import Foundation
import JavaScriptCore
import MultipeerConnectivity

// MARK: - Declare our JavaScript API

/// A MultipeerConnectivity session — the CrossMac data plane.
///
/// Obtain via `hs.multipeer.session(...)`. Call `start()` to advertise + browse;
/// both peers advertise and browse, and whichever sees the other first invites,
/// authenticated by the shared `context` string. Payloads cross the JS bridge as
/// base64 strings (pairs with `HSImage.encode`).
@objc protocol HSMPCSessionAPI: HSTypeAPI, JSExport {
    /// Start advertising and browsing for peers.
    /// - Example:
    /// ```js
    /// s.start()
    /// ```
    @objc func start()

    /// Stop advertising/browsing and disconnect the session.
    /// - Example:
    /// ```js
    /// s.stop()
    /// ```
    @objc func stop()

    /// Tear down and recreate the underlying session/advertiser/browser, then
    /// resume if it was started. The JS watchdog calls this to clear a wedged
    /// AWDL/MPC state.
    /// - Example:
    /// ```js
    /// if (peerlessForTooLong) s.reset()
    /// ```
    @objc func reset()

    /// Register a callback for peer connection-state changes.
    /// - Parameter cb: `function(peerName, state)` — state is `"connected"`, `"connecting"`, or `"disconnected"`.
    /// - Returns: self, for chaining.
    /// - Example:
    /// ```js
    /// s.onPeer((peer, state) => console.log(peer, state))
    /// ```
    @objc @discardableResult func onPeer(_ cb: JSValue) -> HSMPCSession

    /// Register a callback for received payloads.
    /// - Parameter cb: `function(base64, peerName)` — `base64` is the received bytes, base64-encoded.
    /// - Returns: self, for chaining.
    /// - Example:
    /// ```js
    /// s.onReceive((b64, peer) => { /* decode + use */ })
    /// ```
    @objc @discardableResult func onReceive(_ cb: JSValue) -> HSMPCSession

    /// Send a payload to all connected peers.
    /// - Parameter base64: the payload bytes, base64-encoded.
    /// - Parameter opts: `{ reliable }` — `reliable` defaults to `true`.
    /// - Returns: `true` if sent to at least one peer; `false` if there are no peers, the base64 is invalid, or send failed.
    /// - Example:
    /// ```js
    /// s.send(img.encode('jpeg', 0.8), { reliable: true })
    /// ```
    @objc func send(_ base64: String, _ opts: JSValue) -> Bool

    /// The display names of all currently connected peers.
    /// - Example:
    /// ```js
    /// console.log('peers:', s.peers.join(', '))
    /// ```
    @objc var peers: [String] { get }
}

// MARK: - Implementation

@_documentation(visibility: private)
@MainActor
@objc class HSMPCSession: NSObject, HSMPCSessionAPI,
                          MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @objc var typeName = "HSMPCSession"

    // Read synchronously from the MPC private queue → nonisolated(unsafe).
    nonisolated(unsafe) private var session: MCSession
    // Sendable mirrors the bg delegate queue may read freely.
    nonisolated private let inviteContext: Data
    nonisolated private let myDisplayName: String
    // Unique per-launch identity used to break the invite "glare" tie. displayName
    // alone is ambiguous (two Macs can share one), so tiebreak on this instead.
    nonisolated private let myInstanceToken: String

    private let myPeerID: MCPeerID
    private let encPref: MCEncryptionPreference
    private let serviceType: String
    private let allowPeers: [String]   // displayName prefixes we'll pair with; empty = any peer
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser
    private var started = false

    private var peerCb: JSValue?
    private var receiveCb: JSValue?

    init(serviceType: String, displayName: String, context: String, encryption: String, allowPeers: [String] = []) {
        // Validate before constructing MPC objects: an over-long displayName crashes
        // MCPeerID, and an out-of-spec serviceType crashes the advertiser/browser — both
        // with uncaught exceptions. These values come straight from public config, so
        // clamp the name and fall back to the known-good default serviceType on bad input.
        let dn = Self.clampPeerName(displayName)
        let svc = Self.isValidServiceType(serviceType) ? serviceType : "voicekb-cs"
        let token = UUID().uuidString
        self.serviceType = svc
        self.allowPeers = allowPeers
        self.myDisplayName = dn
        self.myInstanceToken = token
        self.inviteContext = context.data(using: .utf8) ?? Data()
        let enc: MCEncryptionPreference
        switch encryption {
        case "none":     enc = .none
        case "optional": enc = .optional
        default:         enc = .required
        }
        self.encPref = enc
        let pid = MCPeerID(displayName: dn)
        self.myPeerID = pid
        unsafe self.session = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: enc)
        self.advertiser = MCNearbyServiceAdvertiser(peer: pid, discoveryInfo: ["id": token], serviceType: svc)
        self.browser = MCNearbyServiceBrowser(peer: pid, serviceType: svc)
        super.init()
        unsafe session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
        if svc != serviceType {
            AKWarning("hs.multipeer: invalid serviceType '\(serviceType)', using default '\(svc)'")
        }
        if !displayName.isEmpty && dn != displayName {
            AKWarning("hs.multipeer: displayName exceeds 63 UTF-8 bytes, clamped to '\(dn)'")
        }
    }

    // MARK: - HSMPCSessionAPI

    @objc func start() {
        guard !started else { return }
        started = true
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        AKTrace("hs.multipeer: started as \(myDisplayName)")
    }

    @objc func stop() {
        started = false
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        unsafe session.disconnect()
    }

    @objc func reset() {
        let wasStarted = started
        stop()
        let fresh = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: encPref)
        unsafe session = fresh
        unsafe session.delegate = self
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["id": myInstanceToken], serviceType: serviceType)
        advertiser.delegate = self
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
        AKTrace("hs.multipeer: reset (recreated session/advertiser/browser)")
        if wasStarted { start() }
    }

    @objc @discardableResult func onPeer(_ cb: JSValue) -> HSMPCSession {
        peerCb = cb.isObject ? cb : nil
        return self
    }

    @objc @discardableResult func onReceive(_ cb: JSValue) -> HSMPCSession {
        receiveCb = cb.isObject ? cb : nil
        return self
    }

    @objc func send(_ base64: String, _ opts: JSValue) -> Bool {
        guard let data = Data(base64Encoded: base64) else { return false }
        let peerList = unsafe session.connectedPeers
        guard !peerList.isEmpty else { return false }
        var reliable = true
        if opts.isObject, let r = opts.objectForKeyedSubscript("reliable"), r.isBoolean { reliable = r.toBool() }
        do {
            try unsafe session.send(data, toPeers: peerList, with: reliable ? .reliable : .unreliable)
            return true
        } catch {
            AKWarning("hs.multipeer: send threw: \(error.localizedDescription)")
            return false
        }
    }

    @objc var peers: [String] { unsafe session.connectedPeers.map { $0.displayName } }

    // MARK: - Fire JS (on the main actor)

    private func firePeer(_ name: String, _ state: String) {
        _ = peerCb?.callSafely(withArguments: [name, state], context: "hs.multipeer")
    }

    private func fireReceive(_ base64: String, _ name: String) {
        _ = receiveCb?.callSafely(withArguments: [base64, name], context: "hs.multipeer")
    }

    // A peer is acceptable iff its displayName has one of the allowPeers prefixes — or the list
    // is empty (= pair with anyone on this service+context). Lets a caller (e.g. CrossMac) pair
    // only with its intended counterpart and ignore other advertisers (an unrelated Mac/VM) that
    // happen to share the serviceType + context on the LAN.
    private nonisolated func isAllowedPeer(_ peerID: MCPeerID) -> Bool {
        if allowPeers.isEmpty { return true }
        let name = peerID.displayName
        return allowPeers.contains { !$0.isEmpty && name.hasPrefix($0) }
    }

    // MARK: - Public-config validation (a bad value here would crash MPC, not just fail)

    /// A MultipeerConnectivity service type must be a valid Bonjour service name:
    /// 1–15 chars of ASCII lowercase letters / digits / hyphens, at least one letter,
    /// no leading/trailing or adjacent hyphens. Anything else makes the advertiser /
    /// browser raise an uncaught exception, so reject it and fall back to the default.
    private nonisolated static func isValidServiceType(_ s: String) -> Bool {
        guard (1...15).contains(s.count) else { return false }
        guard !s.hasPrefix("-"), !s.hasSuffix("-"), !s.contains("--") else { return false }
        var hasLetter = false
        for u in s.unicodeScalars {
            switch u {
            case "a"..."z":      hasLetter = true
            case "0"..."9", "-": break
            default:             return false
            }
        }
        return hasLetter
    }

    /// MCPeerID requires a 1–63 byte UTF-8 display name; an empty or over-long name
    /// crashes it. Default empties to "Mac" and truncate longer names on a character
    /// boundary (a clean prefix — never a torn multi-byte scalar).
    private nonisolated static func clampPeerName(_ s: String) -> String {
        let name = s.isEmpty ? "Mac" : s
        guard name.utf8.count > 63 else { return name }
        var out = ""
        for ch in name {
            if out.utf8.count + String(ch).utf8.count > 63 { break }
            out.append(ch)
        }
        return out.isEmpty ? "Mac" : out
    }

    // MARK: - MCSessionDelegate (private queue → hop to main)

    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let name = peerID.displayName
        let s: String
        switch state {
        case .notConnected: s = "disconnected"
        case .connecting:   s = "connecting"
        case .connected:    s = "connected"
        @unknown default:   s = "unknown"
        }
        Task { @MainActor in self.firePeer(name, s) }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let b64 = data.base64EncodedString()
        let name = peerID.displayName
        Task { @MainActor in self.fireReceive(b64, name) }
    }

    // Required protocol stubs (we use only didReceive:data:).
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    // MARK: - MCNearbyServiceAdvertiserDelegate (private queue)

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let ok = (context == inviteContext) && isAllowedPeer(peerID)
        // Accept synchronously on the MPC queue (allowed by MPC) into the current session.
        unsafe invitationHandler(ok, ok ? session : nil)
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        let msg = error.localizedDescription
        Task { @MainActor in AKWarning("hs.multipeer: advertiser didNotStart: \(msg)") }
    }

    // MARK: - MCNearbyServiceBrowserDelegate (private queue)

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let peerToken = info?["id"]
        // Skip our own rediscovered advertisement. Prefer the unique token; only if a
        // peer advertised none do we fall back to the (ambiguous) displayName match.
        if peerToken == myInstanceToken || (peerToken == nil && peerID.displayName == myDisplayName) { return }
        if unsafe session.connectedPeers.contains(peerID) { return }
        guard isAllowedPeer(peerID) else { return }   // ignore advertisers that aren't our counterpart
        // Tiebreaker: avoid a symmetric-invite race. If both peers invite each other into
        // their own sessions, MCSession resolves the "glare" unreliably and often never
        // reaches .connected. Make invitation one-directional — only one side initiates.
        // Tiebreak on the unique per-launch token, NOT displayName: two Macs can share a
        // display name, which would make both sides skip (each seeing the other as itself
        // or losing the string compare) so they'd never pair. Fall back to displayName
        // only for a peer that advertised no token.
        let theirs = peerToken ?? peerID.displayName
        guard myInstanceToken > theirs else { return }
        unsafe browser.invitePeer(peerID, to: session, withContext: inviteContext, timeout: 30)
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        let name = peerID.displayName
        Task { @MainActor in AKTrace("hs.multipeer: lost peer \(name)") }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        let msg = error.localizedDescription
        Task { @MainActor in AKWarning("hs.multipeer: browser didNotStart: \(msg)") }
    }
}
