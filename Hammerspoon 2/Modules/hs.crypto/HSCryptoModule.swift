//
//  HSCryptoModule.swift
//  Hammerspoon 2
//
//  Minimal AES-256-GCM binding via CryptoKit. Designed for authenticating
//  webhook payloads matching the Android `Cipher.getInstance("AES/GCM/NoPadding")`
//  envelope shape (PSK → SHA-256 → 32-byte key; ciphertext||tag layout).
//
//  All bytes pass through as base64 strings (the *B64 variants) — JSC doesn't
//  natively bridge raw Uint8Array bytes and base64 is what webhooks already use.
//  For raw-byte use cases, callers can decode/encode base64 themselves.
//

import Foundation
import CryptoKit
import JavaScriptCore

@objc protocol HSCryptoModuleAPI: JSExport {
    /// AES-256-GCM encrypt. Inputs and outputs are base64 strings.
    /// - Parameter opts: `{ keyB64: string, nonceB64: string, plaintext: string }`
    ///   - `keyB64`: base64-encoded 32-byte key
    ///   - `nonceB64`: base64-encoded 12-byte nonce (reuse-once invariant on caller)
    ///   - `plaintext`: UTF-8 string to encrypt
    /// - Returns: `{ nonceB64, ciphertextB64 }` where ciphertextB64 includes the 16-byte tag at the end
    /// - Example:
    /// ```js
    /// const { ciphertextB64 } = hs.crypto.aesGcmEncryptB64({ keyB64, nonceB64, plaintext: 'hi' })
    /// ```
    @objc func aesGcmEncryptB64(_ opts: JSValue) -> [String: String]?

    /// AES-256-GCM authenticate-and-decrypt. Returns the plaintext UTF-8 string,
    /// or null on auth failure / bad input. Designed to round-trip with Android's
    /// Cipher.getInstance("AES/GCM/NoPadding") output (ciphertext+tag concatenated).
    /// - Parameter opts: `{ keyB64: string, nonceB64: string, ciphertextB64: string }`
    /// - Returns: the decoded UTF-8 plaintext, or null if authentication failed
    /// - Example:
    /// ```js
    /// const plain = hs.crypto.aesGcmDecryptB64({ keyB64, nonceB64, ciphertextB64 })
    /// if (plain === null) { /* auth failed */ }
    /// ```
    @objc func aesGcmDecryptB64(_ opts: JSValue) -> String?

    /// SHA-256 of a UTF-8 string, returned as base64. Useful for PSK → key
    /// derivation that matches Android's `MessageDigest.getInstance("SHA-256")
    /// .digest(passphrase.toByteArray())` shape.
    /// - Parameter input: a UTF-8 string
    /// - Returns: base64-encoded 32-byte digest
    /// - Example:
    /// ```js
    /// const keyB64 = hs.crypto.sha256B64('my-passphrase')
    /// ```
    @objc func sha256B64(_ input: String) -> String
}

@_documentation(visibility: private)
@MainActor
@objc class HSCryptoModule: NSObject, HSModuleAPI, HSCryptoModuleAPI {
    var name = "hs.crypto"
    let engineID: UUID

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {}

    isolated deinit {
        AKTrace("Deinit of \(name): \(engineID)")
    }

    @objc func aesGcmEncryptB64(_ opts: JSValue) -> [String: String]? {
        guard opts.isObject,
              let keyB64 = opts.objectForKeyedSubscript("keyB64")?.toString(),
              let nonceB64 = opts.objectForKeyedSubscript("nonceB64")?.toString(),
              let plaintext = opts.objectForKeyedSubscript("plaintext")?.toString() else {
            AKError("hs.crypto.aesGcmEncryptB64: missing opts.keyB64 / opts.nonceB64 / opts.plaintext")
            return nil
        }
        guard let keyData = Data(base64Encoded: keyB64), keyData.count == 32 else {
            AKError("hs.crypto.aesGcmEncryptB64: bad keyB64 (must be 32 bytes after decode)")
            return nil
        }
        guard let nonceData = Data(base64Encoded: nonceB64), nonceData.count == 12 else {
            AKError("hs.crypto.aesGcmEncryptB64: bad nonceB64 (must be 12 bytes after decode)")
            return nil
        }
        guard let pt = plaintext.data(using: .utf8) else { return nil }
        do {
            let nonce = try AES.GCM.Nonce(data: nonceData)
            let box = try AES.GCM.seal(pt, using: SymmetricKey(data: keyData), nonce: nonce)
            // ciphertext || tag (matches Android Cipher.doFinal output)
            var combined = box.ciphertext
            combined.append(box.tag)
            return [
                "nonceB64":       nonceData.base64EncodedString(),
                "ciphertextB64":  combined.base64EncodedString(),
            ]
        } catch {
            AKError("hs.crypto.aesGcmEncryptB64: seal failed: \(error)")
            return nil
        }
    }

    @objc func aesGcmDecryptB64(_ opts: JSValue) -> String? {
        guard opts.isObject,
              let keyB64 = opts.objectForKeyedSubscript("keyB64")?.toString(),
              let nonceB64 = opts.objectForKeyedSubscript("nonceB64")?.toString(),
              let ciphertextB64 = opts.objectForKeyedSubscript("ciphertextB64")?.toString() else {
            return nil
        }
        guard let keyData = Data(base64Encoded: keyB64), keyData.count == 32 else { return nil }
        guard let nonceData = Data(base64Encoded: nonceB64), nonceData.count == 12 else { return nil }
        guard let combined = Data(base64Encoded: ciphertextB64), combined.count >= 16 else { return nil }
        let tag = combined.suffix(16)
        let cipher = combined.prefix(combined.count - 16)
        do {
            let nonce = try AES.GCM.Nonce(data: nonceData)
            let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: cipher, tag: tag)
            let plaintext = try AES.GCM.open(box, using: SymmetricKey(data: keyData))
            return String(data: plaintext, encoding: .utf8)
        } catch {
            // Auth fail, wrong key, corruption — all return null silently.
            return nil
        }
    }

    @objc func sha256B64(_ input: String) -> String {
        let data = input.data(using: .utf8) ?? Data()
        let digest = SHA256.hash(data: data)
        return Data(digest).base64EncodedString()
    }
}
