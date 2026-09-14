//
//  PermissionsManager.swift
//  Hammerspoon 2
//
//  Created by Chris Jones on 09/10/2025.
//

import Foundation
@unsafe @preconcurrency import ApplicationServices.HIServices.AXUIElement
import AVFoundation
import CoreLocation
import EventKit
import UserNotifications
import IOKit.hid
import CoreBluetooth
import CoreServices
import AppKit

@_documentation(visibility: private)
enum PermissionsState: Int {
    case notTrusted = 0
    case trusted
    case unknown
}

@_documentation(visibility: private)
enum PermissionsType: Int, CaseIterable {
    case accessibility = 0
    case camera
    case microphone
    case notifications
    case screencapture
    case location
    case inputMonitoring
    // New cases remain append-only so existing raw values don't shift.
    case calendar
    case reminders
    case bluetooth
    case fullDiskAccess
    case automation

    /// The subset shown in Settings → Permissions, in display order. The enum still carries
    /// every permission the hs.permissions JS module can query (camera/microphone/screen/
    /// location); the panel intentionally lists only what this build's features actually need.
    static let panel: [PermissionsType] = [
        .accessibility,
        .inputMonitoring,
        .notifications,
        .calendar,
        .reminders,
        .bluetooth,
        .fullDiskAccess,
        .automation,
    ]

    /// The apps VibeCast sends Apple Events to: Finder (reveal), Safari and the Chromium
    /// family (launcher tabs, herdr's Chrome tab). Firefox is NOT here — its tabs are read from
    /// its session store, no Apple Events. Automation is granted per target and only a running
    /// target can be asked, so the check walks this list and skips what is not running.
    static let automationTargets: [String] = [
        "com.apple.finder", "com.apple.Safari", "com.google.Chrome", "com.microsoft.edgemac",
        "com.brave.Browser", "com.vivaldi.Vivaldi", "com.operasoftware.Opera", "company.thebrowser.Browser",
    ]

    var displayName: String {
        switch self {
        case .accessibility:  return "Accessibility"
        case .camera:         return "Camera"
        case .microphone:     return "Microphone"
        case .notifications:  return "Notifications"
        case .screencapture:  return "Screen Recording"
        case .location:       return "Location"
        case .inputMonitoring: return "Input Monitoring"
        case .calendar:       return "Calendars"
        case .reminders:      return "Reminders"
        case .bluetooth:      return "Bluetooth"
        case .fullDiskAccess: return "Full Disk Access"
        case .automation:     return "Automation"
        }
    }

    /// Stable identifier for JS (`hs.permissions.summary()`) and logs.
    var id: String {
        switch self {
        case .accessibility:  return "accessibility"
        case .camera:         return "camera"
        case .microphone:     return "microphone"
        case .notifications:  return "notifications"
        case .screencapture:  return "screenRecording"
        case .location:       return "location"
        case .inputMonitoring: return "inputMonitoring"
        case .calendar:       return "calendar"
        case .reminders:      return "reminders"
        case .bluetooth:      return "bluetooth"
        case .fullDiskAccess: return "fullDiskAccess"
        case .automation:     return "automation"
        }
    }

    /// Why this build needs the permission — the VibeCast features behind it. The panel shows
    /// it under the description so a person can decide whether a red row matters to them.
    var usedBy: String {
        switch self {
        case .accessibility:  return "Windows, launcher, snippets, CrossMac — window control and the event taps behind every hotkey"
        case .inputMonitoring: return "Snippets expander, CrossMac capture, the launcher’s double-tap Ctrl — global key event taps"
        case .notifications:  return "Alerts from every feature (hs.notify)"
        case .calendar:       return "calendar-mcp"
        case .reminders:      return "calendar-mcp"
        case .bluetooth:      return "CrossMac’s ESP32 relay (hs.ble) — target Macs only; a controller talks to the relay over USB, so ‘not decided’ is fine there"
        case .fullDiskAccess: return "The launcher’s Safari favorites and history index"
        case .automation:     return "Launcher browser tabs (Safari, Chrome and other Chromium browsers), herdr’s Chrome tab, Finder reveal — per app, checked against the ones running now; each asks once on first use"
        case .camera, .microphone, .screencapture, .location:
            return "Not used by any VibeCast feature"
        }
    }

    /// When a fresh grant only takes effect after Hammerspoon 2 is relaunched, say so.
    var relaunchNote: String? {
        switch self {
        case .accessibility:  return "Relaunch after granting — event taps opened before the grant stay dead"
        case .inputMonitoring: return "Relaunch after granting — takes effect at the next launch"
        case .screencapture:  return "Relaunch after granting"
        case .fullDiskAccess: return "Relaunch recommended — the indexer remembers a refusal until its next run"
        case .camera, .microphone, .notifications, .location, .calendar, .reminders, .bluetooth, .automation:
            return nil
        }
    }

    var permissionDescription: String {
        switch self {
        case .accessibility:  return "Allows controlling and monitoring other applications"
        case .camera:         return "Allows accessing the camera"
        case .microphone:     return "Allows accessing the microphone"
        case .notifications:  return "Allows displaying system notifications"
        case .screencapture:  return "Allows capturing screen content"
        case .location:       return "Allows accessing this computer's location"
        case .inputMonitoring: return "Allows monitoring keyboard and other input devices (required for global hotkeys/eventtaps that consume keys)"
        case .calendar:       return "Allows reading and modifying Events in your Calendars"
        case .reminders:      return "Allows reading and modifying Reminders in your Reminder Lists"
        case .bluetooth:      return "Allows connecting to Bluetooth devices"
        case .fullDiskAccess: return "Allows reading protected files (Safari data, Mail, Messages, the TCC database)"
        case .automation:     return "Allows sending Apple Events to other apps (scripting them)"
        }
    }

    var settingsURL: URL {
        let path: String
        switch self {
        case .accessibility:  path = "Privacy_Accessibility"
        case .camera:         path = "Privacy_Camera"
        case .microphone:     path = "Privacy_Microphone"
        case .notifications:  return URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!
        case .screencapture:  path = "Privacy_ScreenCapture"
        case .location:       path = "Privacy_LocationServices"
        case .inputMonitoring: path = "Privacy_ListenEvent"
        case .calendar:       path = "Privacy_Calendars"
        case .reminders:      path = "Privacy_Reminders"
        case .bluetooth:      path = "Privacy_Bluetooth"
        case .fullDiskAccess: path = "Privacy_AllFiles"
        case .automation:     path = "Privacy_Automation"
        }
        // swiftlint:disable:next force_unwrapping
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(path)")!
    }
}

@_documentation(visibility: private)
@MainActor
class PermissionsManager: NSObject {
    static let shared = PermissionsManager()

    private var locationManager: CLLocationManager?
    private var locationCallback: (@Sendable (Bool) -> Void)?
    /// Instantiating a central manager is what makes macOS ask for Bluetooth; it is kept
    /// alive until the answer lands.
    private var bluetoothManager: CBCentralManager?

    // Notification authorization has no synchronous status API, so we cache the last known state.
    // The cache is populated on first check and after every request.
    private var cachedNotificationState: PermissionsState = .unknown

    isolated deinit {
        locationManager?.delegate = nil
    }

    private func refreshNotificationState() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            // Extract the Sendable enum value before crossing into the main actor task.
            let status = settings.authorizationStatus
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch status {
                case .authorized, .provisional: self.cachedNotificationState = .trusted
                case .denied:                   self.cachedNotificationState = .notTrusted
                default:                        self.cachedNotificationState = .unknown
                }
            }
        }
    }

    func state(_ permType: PermissionsType) -> PermissionsState {
        switch permType {
        case .accessibility:
            return AXIsProcessTrusted() ? .trusted : .notTrusted
        case .camera:
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:    return .trusted
            case .notDetermined: return .unknown
            default:             return .notTrusted
            }
        case .microphone:
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:    return .trusted
            case .notDetermined: return .unknown
            default:             return .notTrusted
            }
        case .notifications:
            if cachedNotificationState == .unknown { refreshNotificationState() }
            return cachedNotificationState
        case .screencapture:
            return CGPreflightScreenCaptureAccess() ? .trusted : .notTrusted
        case .location:
            switch CLLocationManager().authorizationStatus {
            case .authorized, .authorizedAlways: return .trusted
            case .notDetermined:                 return .unknown
            default:                             return .notTrusted
            }
        case .inputMonitoring:
            return IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted ? .trusted : .notTrusted
        case .calendar:
            return eventKitState(for: .event)
        case .reminders:
            return eventKitState(for: .reminder)
        case .bluetooth:
            switch CBManager.authorization {
            case .allowedAlways: return .trusted
            case .notDetermined: return .unknown
            default:             return .notTrusted
            }
        case .fullDiskAccess:
            return Self.hasFullDiskAccess() ? .trusted : .notTrusted
        case .automation:
            return automationAggregateState()
        }
    }

    func check(_ permType: PermissionsType) -> Bool {
        switch permType {
        case .accessibility:
            return AXIsProcessTrusted()
        case .camera:
            return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        case .microphone:
            return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        case .notifications:
            if cachedNotificationState == .unknown { refreshNotificationState() }
            return cachedNotificationState == .trusted
        case .screencapture:
            return CGPreflightScreenCaptureAccess()
        case .location:
            let status = CLLocationManager().authorizationStatus
            return status == .authorized || status == .authorizedAlways
        case .inputMonitoring:
            return IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        case .calendar:
            return HSEventStore.shared.authorizationStatus(for: .event) == .fullAccess
        case .reminders:
            return HSEventStore.shared.authorizationStatus(for: .reminder) == .fullAccess
        case .bluetooth:
            return CBManager.authorization == .allowedAlways
        case .fullDiskAccess:
            return Self.hasFullDiskAccess()
        case .automation:
            return automationAggregateState() == .trusted
        }
    }

    func request(_ permType: PermissionsType, callback: (@Sendable (Bool) -> Void)? = nil) {
        switch permType {
        case .accessibility:
            let options = unsafe [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        case .camera:
            let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)

            switch currentStatus {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video, completionHandler: callback ?? { _ in })
            case .authorized:
                callback?(true)
            default:
                callback?(false)
            }
        case .microphone:
            let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)

            switch currentStatus {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio, completionHandler: callback ?? { _ in })
            case .authorized:
                callback?(true)
            default:
                callback?(false)
            }
        case .notifications:
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
                if let error {
                    Task { @MainActor in
                        AKError("hs.permissions.requestNotifications(): \(error.localizedDescription)")
                    }
                }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.cachedNotificationState = granted ? .trusted : .notTrusted
                    callback?(granted)
                }
            }
        case .screencapture:
            CGRequestScreenCaptureAccess()
        case .location:
            let manager = CLLocationManager()
            switch manager.authorizationStatus {
            case .authorized, .authorizedAlways:
                callback?(true)
            case .notDetermined:
                locationManager = manager
                locationCallback = callback
                manager.delegate = self
                manager.requestAlwaysAuthorization()
            default:
                callback?(false)
            }
        case .inputMonitoring:
            // IOHIDRequestAccess adds us to the Input Monitoring list and prompts; the grant
            // typically takes effect on next launch, so the returned value may be false now.
            let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            callback?(granted)
        case .calendar:
            requestCalendarAccess(callback: callback)
        case .reminders:
            requestRemindersAccess(callback: callback)
        case .bluetooth:
            if CBManager.authorization == .notDetermined {
                bluetoothManager = CBCentralManager(delegate: nil, queue: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    _ = self
                    callback?(CBManager.authorization == .allowedAlways)
                }
            } else {
                callback?(CBManager.authorization == .allowedAlways)
            }
        case .fullDiskAccess:
            // macOS has no prompt for Full Disk Access: the pane is the only door.
            NSWorkspace.shared.open(permType.settingsURL)
            callback?(Self.hasFullDiskAccess())
        case .automation:
            // Asking blocks while the consent dialog is up, so ask off the main thread,
            // one running target at a time; targets that are not running cannot be asked.
            let targets = PermissionsType.automationTargets
            DispatchQueue.global(qos: .userInitiated).async {
                var allGranted = true
                for id in targets {
                    switch Self.automationStatus(bundleID: id, ask: true) {
                    case .granted, .notRunning: break
                    default: allGranted = false
                    }
                }
                DispatchQueue.main.async { callback?(allGranted) }
            }
        }
    }

    // MARK: - Bluetooth / Full Disk Access / Automation helpers

    /// Full Disk Access has no API. The user TCC database is readable by exactly the
    /// processes that hold it, so opening it for reading is the honest probe.
    nonisolated static func hasFullDiskAccess() -> Bool {
        let path = NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db"
        guard let handle = FileHandle(forReadingAtPath: path) else { return false }
        try? handle.close()
        return true
    }

    enum AutomationStatus {
        case granted, denied, consentNeeded, notRunning
        case failed(OSStatus)

        var name: String {
            switch self {
            case .granted:       return "granted"
            case .denied:        return "denied"
            case .consentNeeded: return "notDetermined"
            case .notRunning:    return "notRunning"
            case .failed(let code): return "error(\(code))"
            }
        }
    }

    /// Automation is granted per target app. With `ask` false this never shows a dialog;
    /// with `ask` true macOS asks for consent when it has not been decided yet (blocking).
    /// A target that is not running cannot be asked and reports `notRunning`.
    nonisolated static func automationStatus(bundleID: String, ask: Bool) -> AutomationStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        let status = AEDeterminePermissionToAutomateTarget(
            target.aeDesc, AEEventClass(typeWildCard), AEEventID(typeWildCard), ask)
        switch status {
        case noErr:  return .granted
        case -600:   return .notRunning      // procNotFound
        case -1743:  return .denied          // errAEEventNotPermitted
        case -1744:  return .consentNeeded   // errAEEventWouldRequireUserConsent
        default:     return .failed(status)
        }
    }

    /// One traffic light for all automation targets: red if any running target denied us,
    /// orange if any still needs consent (or none is running to ask), green when every
    /// running target has said yes.
    private func automationAggregateState() -> PermissionsState {
        var sawGranted = false
        var sawConsent = false
        for id in PermissionsType.automationTargets {
            switch Self.automationStatus(bundleID: id, ask: false) {
            case .granted:       sawGranted = true
            case .denied:        return .notTrusted
            case .consentNeeded: sawConsent = true
            case .notRunning, .failed: break
            }
        }
        if sawConsent { return .unknown }
        return sawGranted ? .trusted : .unknown
    }

    /// Relaunch this app: a shell waits for our pid to exit, then opens the bundle again by
    /// its explicit path (never `open -a`, which can resolve to a stale copy).
    static func relaunchApp() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let path = Bundle.main.bundlePath
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "while kill -0 \(pid) 2>/dev/null; do sleep 0.05; done; open '\(escaped)'"]
        try? task.run()
        NSApplication.shared.terminate(nil)
    }

    private func eventKitState(for entityType: EKEntityType) -> PermissionsState {
        switch HSEventStore.shared.authorizationStatus(for: entityType) {
        case .fullAccess:   return .trusted
        case .notDetermined: return .unknown
        case .restricted, .denied, .writeOnly: return .notTrusted
        @unknown default: return .unknown
        }
    }

    private func requestCalendarAccess(callback: (@Sendable (Bool) -> Void)?) {
        switch HSEventStore.shared.authorizationStatus(for: .event) {
        case .notDetermined, .writeOnly:
            HSEventStore.shared.eventStore.requestFullAccessToEvents { granted, error in
                if let error {
                    Task { @MainActor in
                        AKError("hs.permissions.requestCalendar(): \(error.localizedDescription)")
                    }
                }
                callback?(granted)
            }
        case .fullAccess:
            callback?(true)
        case .restricted, .denied:
            callback?(false)
        @unknown default:
            callback?(false)
        }
    }

    private func requestRemindersAccess(callback: (@Sendable (Bool) -> Void)?) {
        switch HSEventStore.shared.authorizationStatus(for: .reminder) {
        case .notDetermined:
            HSEventStore.shared.eventStore.requestFullAccessToReminders { granted, error in
                if let error {
                    Task { @MainActor in
                        AKError("hs.permissions.requestReminders(): \(error.localizedDescription)")
                    }
                }
                callback?(granted)
            }
        case .fullAccess:
            callback?(true)
        case .restricted, .denied, .writeOnly:
            callback?(false)
        @unknown default:
            callback?(false)
        }
    }
}

extension PermissionsManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status != .notDetermined else { return }
        let granted = status == .authorized || status == .authorizedAlways
        Task { @MainActor [weak self] in
            guard let self else { return }
            let callback = self.locationCallback
            self.locationCallback = nil
            self.locationManager = nil
            callback?(granted)
        }
    }
}
