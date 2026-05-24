//
//  HSKeychainModule.swift
//  Hammerspoon 2
//
//  Minimal binding to macOS Keychain Generic Password items via SecItem*.
//  All items are namespaced under the HS2 bundle identifier as the service,
//  so they don't collide with non-HS2 software using the same account names.
//

import Foundation
import Security
import JavaScriptCore

@objc protocol HSKeychainModuleAPI: JSExport {
    /// Store a value under the given account name in the Keychain.
    /// - Parameters:
    ///   - account: account name (user-facing key)
    ///   - value: secret string to store
    /// - Returns: true if the item was saved successfully
    /// - Example:
    /// ```js
    /// hs.keychain.set('webhook_psk', 'my-secret')
    /// ```
    @objc func set(_ account: String, _ value: String) -> Bool

    /// Retrieve the value for an account name.
    /// - Parameter account: account name
    /// - Returns: the stored string, or null if the item does not exist
    /// - Example:
    /// ```js
    /// const psk = hs.keychain.get('webhook_psk')
    /// ```
    @objc func get(_ account: String) -> String?

    /// Check whether an item exists under the given account name.
    /// - Parameter account: account name
    /// - Returns: true if the item is present
    /// - Example:
    /// ```js
    /// if (!hs.keychain.has('webhook_psk')) { /* prompt */ }
    /// ```
    @objc func has(_ account: String) -> Bool

    /// Delete the item under the given account name.
    /// - Parameter account: account name
    /// - Returns: true if an item was deleted; false if no item existed
    /// - Example:
    /// ```js
    /// hs.keychain.delete('webhook_psk')
    /// ```
    @objc(delete:) func deleteAccount(_ account: String) -> Bool

    /// List all account names belonging to this app's Keychain namespace.
    /// - Returns: array of account names
    /// - Example:
    /// ```js
    /// console.log(hs.keychain.list())
    /// ```
    @objc func list() -> [String]
}

@_documentation(visibility: private)
@MainActor
@objc class HSKeychainModule: NSObject, HSModuleAPI, HSKeychainModuleAPI {
    var name = "hs.keychain"
    let engineID: UUID

    private static var service: String {
        Bundle.main.bundleIdentifier ?? "net.tenshu.Hammerspoon-2"
    }

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {}

    isolated deinit {
        AKTrace("Deinit of \(name): \(engineID)")
    }

    // MARK: - API

    @objc func set(_ account: String, _ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: data,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus == errSecSuccess { return true }
            AKError("hs.keychain.set: SecItemAdd failed for '\(account)': OSStatus \(addStatus)")
            return false
        }
        AKError("hs.keychain.set: SecItemUpdate failed for '\(account)': OSStatus \(updateStatus)")
        return false
    }

    @objc func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        if status != errSecSuccess {
            AKError("hs.keychain.get: SecItemCopyMatching failed for '\(account)': OSStatus \(status)")
            return nil
        }
        guard let data = item as? Data, let s = String(data: data, encoding: .utf8) else {
            return nil
        }
        return s
    }

    @objc func has(_ account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    @objc(delete:) func deleteAccount(_ account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess { return true }
        if status == errSecItemNotFound { return false }
        AKError("hs.keychain.delete: SecItemDelete failed for '\(account)': OSStatus \(status)")
        return false
    }

    @objc func list() -> [String] {
        let query: [String: Any] = [
            kSecClass as String:                kSecClassGenericPassword,
            kSecAttrService as String:          Self.service,
            kSecReturnAttributes as String:     true,
            kSecMatchLimit as String:           kSecMatchLimitAll,
        ]
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        if status == errSecItemNotFound { return [] }
        if status != errSecSuccess {
            AKError("hs.keychain.list: SecItemCopyMatching failed: OSStatus \(status)")
            return []
        }
        guard let arr = items as? [[String: Any]] else { return [] }
        return arr.compactMap { $0[kSecAttrAccount as String] as? String }
    }
}
