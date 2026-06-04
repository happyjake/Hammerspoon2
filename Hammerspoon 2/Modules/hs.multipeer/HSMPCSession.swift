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

    private let myPeerID: MCPeerID
    private let encPref: MCEncryptionPreference
    private let serviceType: String
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser
    private var started = false

    private var peerCb: JSValue?
    private var receiveCb: JSValue?

    init(serviceType: String, displayName: String, context: String, encryption: String) {
        let dn = displayName.isEmpty ? "Mac" : displayName
        self.serviceType = serviceType
        self.myDisplayName = dn
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
        self.advertiser = MCNearbyServiceAdvertiser(peer: pid, discoveryInfo: nil, serviceType: serviceType)
        self.browser = MCNearbyServiceBrowser(peer: pid, serviceType: serviceType)
        super.init()
        unsafe session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
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
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
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
        let ok = (context == inviteContext)
        // Accept synchronously on the MPC queue (allowed by MPC) into the current session.
        unsafe invitationHandler(ok, ok ? session : nil)
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        let msg = error.localizedDescription
        Task { @MainActor in AKWarning("hs.multipeer: advertiser didNotStart: \(msg)") }
    }

    // MARK: - MCNearbyServiceBrowserDelegate (private queue)

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        if peerID.displayName == myDisplayName { return }
        if unsafe session.connectedPeers.contains(peerID) { return }
        // Tiebreaker: avoid a symmetric-invite race. If both peers invite each other into
        // their own sessions, MCSession resolves the "glare" unreliably and often never
        // reaches .connected. Make invitation one-directional — only the peer with the
        // greater displayName initiates; the other only advertises and accepts the invite.
        guard myDisplayName > peerID.displayName else { return }
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
