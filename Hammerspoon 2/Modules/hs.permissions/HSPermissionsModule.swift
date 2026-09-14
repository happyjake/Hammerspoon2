//
//  PermissionsModule.swift
//  Hammerspoon 2
//
//  Created by Chris Jones on 06/11/2025.
//

import Foundation
import JavaScriptCore
import AVFoundation
import IOKit.hid

// MARK: - Declare our JavaScript API

/// Module for checking and requesting system permissions
@objc protocol HSPermissionsModuleAPI: JSExport {
    /// Check if the app has Accessibility permission
    /// - Returns: true if permission is granted, false otherwise
    /// - Example:
    /// ```js
    /// console.log(hs.permissions.checkAccessibility())
    /// ```
    @objc func checkAccessibility() -> Bool

    /// Request Accessibility permission (shows system dialog if not granted)
    /// - Example:
    /// ```js
    /// hs.permissions.requestAccessibility()
    /// ```
    @objc func requestAccessibility()

    /// Check if the app has Screen Recording permission
    /// - Returns: true if permission is granted, false otherwise
    /// - Example:
    /// ```js
    /// console.log(hs.permissions.checkScreenRecording())
    /// ```
    @objc func checkScreenRecording() -> Bool

    /// Request Screen Recording permission
    /// - Note: This will trigger a screen capture which prompts the system dialog
    /// - Example:
    /// ```js
    /// hs.permissions.requestScreenRecording()
    /// ```
    @objc func requestScreenRecording()

    /// Check if the app has Camera permission
    /// - Returns: true if permission is granted, false otherwise
    /// - Example:
    /// ```js
    /// console.log(hs.permissions.checkCamera())
    /// ```
    @objc func checkCamera() -> Bool

    /// Request Camera permission (shows system dialog if not granted)
    /// - Returns: {Promise<boolean>} A Promise that resolves to true if granted, false if denied
    /// - Example:
    /// ```js
    /// hs.permissions.requestCamera().then(granted => console.log(granted))
    /// ```
    @objc func requestCamera() -> JSPromise?

    /// Check if the app has Microphone permission
    /// - Returns: true if permission is granted, false otherwise
    /// - Example:
    /// ```js
    /// console.log(hs.permissions.checkMicrophone())
    /// ```
    @objc func checkMicrophone() -> Bool

    /// Request Microphone permission (shows system dialog if not granted)
    /// - Returns: {Promise<boolean>} A Promise that resolves to true if granted, false if denied
    /// - Example:
    /// ```js
    /// hs.permissions.requestMicrophone().then(granted => console.log(granted))
    /// ```
    @objc func requestMicrophone() -> JSPromise?

    /// Check if the app has permission to display notifications.
    ///
    /// The result is cached from the last request or check; the cache is refreshed asynchronously,
    /// so the very first call in a session may return `false` before the cached value is populated.
    /// Use `requestNotifications()` on first launch to ensure the result is accurate.
    /// - Returns: true if notification permission is granted
    /// - Example:
    /// ```js
    /// console.log(hs.permissions.checkNotifications())
    /// ```
    @objc func checkNotifications() -> Bool

    /// Request notification permission (shows the system dialog if the user has not yet decided).
    ///
    /// It is safe to call this on every launch — the dialog only appears once; subsequent calls
    /// resolve immediately with the previously granted or denied state.
    /// - Returns: {Promise<boolean>} A Promise that resolves to true if granted, false if denied
    /// - Example:
    /// ```js
    /// hs.permissions.requestNotifications().then(granted => console.log(granted))
    /// ```
    @objc func requestNotifications() -> JSPromise?

    /// Check if the app has Location permission.
    /// - Returns: true if permission is granted, false otherwise
    /// - Example:
    /// ```js
    /// console.log(hs.permissions.checkLocation())
    /// ```
    @objc func checkLocation() -> Bool

    /// Request Location permission (shows the system dialog if the user has not yet decided).
    /// - Returns: {Promise<boolean>} A Promise that resolves to true if granted, false if denied
    /// - Example:
    /// ```js
    /// hs.permissions.requestLocation().then(granted => {
    ///     if (granted) console.log(hs.location.get())
    /// })
    /// ```
    @objc func requestLocation() -> JSPromise?

    /// Check whether the app has full Calendar access.
    /// - Returns: true if full Calendar access is granted, false otherwise
    /// - Example:
    /// ```js
    /// console.log(hs.permissions.checkCalendar())
    /// ```
    @objc func checkCalendar() -> Bool

    /// Request full Calendar access (shows the system dialog if the user has not yet decided).
    ///
    /// It is safe to call this on every launch — macOS only shows the dialog once for this scope;
    /// subsequent calls resolve with the durable authorization state.
    /// - Returns: {Promise<boolean>} A Promise that resolves to true if full access is granted, false otherwise
    /// - Example:
    /// ```js
    /// hs.permissions.requestCalendar().then(granted => console.log(granted))
    /// ```
    @objc func requestCalendar() -> JSPromise?

    /// Check whether the app has full Reminders access.
    /// - Returns: true if full Reminders access is granted, false otherwise
    /// - Example:
    /// ```js
    /// console.log(hs.permissions.checkReminders())
    /// ```
    @objc func checkReminders() -> Bool

    /// Request full Reminders access (shows its independent system dialog if the user has not yet decided).
    ///
    /// It is safe to call this on every launch — macOS only shows the dialog once for this scope;
    /// subsequent calls resolve with the durable authorization state.
    /// - Returns: {Promise<boolean>} A Promise that resolves to true if full access is granted, false otherwise
    /// - Example:
    /// ```js
    /// hs.permissions.requestReminders().then(granted => console.log(granted))
    /// ```
    @objc func requestReminders() -> JSPromise?

    /// Check whether the user has granted Input Monitoring access to this app.
    /// Required for hs.eventtap to receive global key events.
    /// - Returns: true if granted, false if denied or unknown
    /// - Example:
    /// ```js
    /// if (!hs.permissions.checkInputMonitoring()) {
    ///   hs.notify.show('VibeCast', 'Grant Input Monitoring in System Settings')
    /// }
    /// ```
    @objc func checkInputMonitoring() -> Bool

    /// Trigger the macOS Input Monitoring permission prompt.
    /// - Example:
    /// ```js
    /// hs.permissions.requestInputMonitoring()
    /// ```
    @objc func requestInputMonitoring()

    /// Check whether the app may use Bluetooth (needed by hs.ble).
    /// - Returns: true if granted, false if denied or not yet decided
    /// - Example:
    /// ```js
    /// console.log(hs.permissions.checkBluetooth())
    /// ```
    @objc func checkBluetooth() -> Bool

    /// Request Bluetooth access (shows the system dialog if the user has not yet decided).
    /// - Returns: {Promise<boolean>} A Promise that resolves to true if granted, false otherwise
    /// - Example:
    /// ```js
    /// hs.permissions.requestBluetooth().then(granted => console.log(granted))
    /// ```
    @objc func requestBluetooth() -> JSPromise?

    /// Check whether the app has Full Disk Access.
    ///
    /// macOS offers no API for this, so the check opens the user's TCC database for reading —
    /// exactly the processes that hold Full Disk Access can. There is no prompt to request it:
    /// grant it in System Settings → Privacy & Security → Full Disk Access, then relaunch.
    /// - Returns: true if granted, false otherwise
    /// - Example:
    /// ```js
    /// console.log(hs.permissions.checkFullDiskAccess())
    /// ```
    @objc func checkFullDiskAccess() -> Bool

    /// Check whether the app may send Apple Events to one target app (Automation).
    ///
    /// Automation is granted per target. A target that is not running cannot be checked.
    /// - Parameter bundleID: the target's bundle identifier, e.g. "com.apple.Safari"
    /// - Returns: "granted", "denied", "notDetermined", "notRunning", or "error(<code>)"
    /// - Example:
    /// ```js
    /// console.log(hs.permissions.checkAutomation("com.google.Chrome"))
    /// ```
    @objc func checkAutomation(_ bundleID: String) -> String

    /// Ask for permission to automate one target app (shows the consent dialog if undecided).
    /// The target must be running.
    /// - Parameter bundleID: the target's bundle identifier
    /// - Returns: {Promise<boolean>} A Promise that resolves to true if granted, false otherwise
    /// - Example:
    /// ```js
    /// hs.permissions.requestAutomation("com.apple.Safari").then(granted => console.log(granted))
    /// ```
    @objc func requestAutomation(_ bundleID: String) -> JSPromise?

    /// Everything this build's features need, in one object — the same rows the
    /// Settings → Permissions panel shows: live state, whether it is granted, which features
    /// use it, whether a fresh grant needs a relaunch, and the System Settings URL.
    /// - Returns: an object keyed by permission id (`accessibility`, `inputMonitoring`,
    ///   `notifications`, `calendar`, `reminders`, `bluetooth`, `fullDiskAccess`, `automation`),
    ///   each `{ name, state, granted, usedBy, relaunch, settings }` where `state` is
    ///   "trusted", "notTrusted" or "unknown" and `relaunch` is a note or an empty string
    /// - Example:
    /// ```js
    /// const p = hs.permissions.summary()
    /// Object.values(p).filter(x => !x.granted).forEach(x => console.log(x.name, '—', x.usedBy))
    /// ```
    @objc func summary() -> [String: Any]
}

// MARK: - Implementation

@_documentation(visibility: private)
@MainActor
@objc class HSPermissionsModule: NSObject, HSModuleAPI, HSPermissionsModuleAPI {
    var name = "hs.permissions"
    let engineID: UUID

    // MARK: - Module lifecycle
    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKDebug("Init of \(name): \(engineID)")
    }

    func shutdown() {}

    isolated deinit {
        AKDebug("Deinit of \(name): \(engineID)")
    }

    // MARK: - Accessibility

    @objc func checkAccessibility() -> Bool {
        return PermissionsManager.shared.check(.accessibility)
    }

    @objc func requestAccessibility() {
        PermissionsManager.shared.request(.accessibility)
    }

    // MARK: - Screen Recording
    @objc func checkScreenRecording() -> Bool {
        return PermissionsManager.shared.check(.screencapture)
    }

    @objc func requestScreenRecording() {
        PermissionsManager.shared.request(.screencapture)
    }

    // MARK: - Camera

    @objc func checkCamera() -> Bool {
        return PermissionsManager.shared.check(.camera)
    }

    @objc func requestCamera() -> JSPromise? {
        guard let context = JSContext.current() else { return nil }
        return wrapAsyncInJSPromise(in: context) { holder in
            PermissionsManager.shared.request(.camera) { result in
                Task { @MainActor in holder.resolveWith(result) }
            }
        }
    }

    // MARK: - Microphone

    @objc func checkMicrophone() -> Bool {
        return PermissionsManager.shared.check(.microphone)
    }

    @objc func requestMicrophone() -> JSPromise? {
        guard let context = JSContext.current() else { return nil }
        return wrapAsyncInJSPromise(in: context) { holder in
            PermissionsManager.shared.request(.microphone) { result in
                Task { @MainActor in holder.resolveWith(result) }
            }
        }
    }

    // MARK: - Notifications

    @objc func checkNotifications() -> Bool {
        return PermissionsManager.shared.check(.notifications)
    }

    @objc func requestNotifications() -> JSPromise? {
        guard let context = JSContext.current() else { return nil }
        return wrapAsyncInJSPromise(in: context) { holder in
            PermissionsManager.shared.request(.notifications) { result in
                Task { @MainActor in holder.resolveWith(result) }
            }
        }
    }

    // MARK: - Location

    @objc func checkLocation() -> Bool {
        return PermissionsManager.shared.check(.location)
    }

    @objc func requestLocation() -> JSPromise? {
        guard let context = JSContext.current() else { return nil }
        return wrapAsyncInJSPromise(in: context) { holder in
            PermissionsManager.shared.request(.location) { result in
                Task { @MainActor in holder.resolveWith(result) }
            }
        }
    }

    // MARK: - Calendar

    @objc func checkCalendar() -> Bool {
        PermissionsManager.shared.check(.calendar)
    }

    @objc func requestCalendar() -> JSPromise? {
        guard let context = JSContext.current() else { return nil }
        return wrapAsyncInJSPromise(in: context) { holder in
            PermissionsManager.shared.request(.calendar) { result in
                Task { @MainActor in holder.resolveWith(result) }
            }
        }
    }

    // MARK: - Reminders

    @objc func checkReminders() -> Bool {
        PermissionsManager.shared.check(.reminders)
    }

    @objc func requestReminders() -> JSPromise? {
        guard let context = JSContext.current() else { return nil }
        return wrapAsyncInJSPromise(in: context) { holder in
            PermissionsManager.shared.request(.reminders) { result in
                Task { @MainActor in holder.resolveWith(result) }
            }
        }
    }

    // MARK: - Input Monitoring

    @objc func checkInputMonitoring() -> Bool {
        let result = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        return result == kIOHIDAccessTypeGranted
    }

    @objc func requestInputMonitoring() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    // MARK: - Bluetooth

    @objc func checkBluetooth() -> Bool {
        PermissionsManager.shared.check(.bluetooth)
    }

    @objc func requestBluetooth() -> JSPromise? {
        guard let context = JSContext.current() else { return nil }
        return wrapAsyncInJSPromise(in: context) { holder in
            PermissionsManager.shared.request(.bluetooth) { result in
                Task { @MainActor in holder.resolveWith(result) }
            }
        }
    }

    // MARK: - Full Disk Access

    @objc func checkFullDiskAccess() -> Bool {
        PermissionsManager.shared.check(.fullDiskAccess)
    }

    // MARK: - Automation

    @objc func checkAutomation(_ bundleID: String) -> String {
        PermissionsManager.automationStatus(bundleID: bundleID, ask: false).name
    }

    @objc func requestAutomation(_ bundleID: String) -> JSPromise? {
        guard let context = JSContext.current() else { return nil }
        return wrapAsyncInJSPromise(in: context) { holder in
            DispatchQueue.global(qos: .userInitiated).async {
                let status = PermissionsManager.automationStatus(bundleID: bundleID, ask: true)
                let granted: Bool
                if case .granted = status { granted = true } else { granted = false }
                Task { @MainActor in holder.resolveWith(granted) }
            }
        }
    }

    // MARK: - Summary

    @objc func summary() -> [String: Any] {
        var out: [String: Any] = [:]
        for type in PermissionsType.panel {
            let state = PermissionsManager.shared.state(type)
            let stateName: String
            switch state {
            case .trusted:    stateName = "trusted"
            case .notTrusted: stateName = "notTrusted"
            case .unknown:    stateName = "unknown"
            }
            out[type.id] = [
                "name": type.displayName,
                "state": stateName,
                "granted": PermissionsManager.shared.check(type),
                "usedBy": type.usedBy,
                "relaunch": type.relaunchNote ?? "",
                "settings": type.settingsURL.absoluteString,
            ] as [String: Any]
        }
        return out
    }
}
