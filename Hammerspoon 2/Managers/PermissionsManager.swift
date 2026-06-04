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
import UserNotifications
import IOKit.hid

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
    case inputMonitoring   // appended last so existing raw values don't shift

    /// The subset shown in Settings → Permissions, in display order. The enum still carries
    /// every permission the hs.permissions JS module can query (camera/microphone/screen/
    /// location); the panel intentionally lists only what this build's features actually need.
    static let panel: [PermissionsType] = [.accessibility, .inputMonitoring, .notifications]

    var displayName: String {
        switch self {
        case .accessibility:  return "Accessibility"
        case .camera:         return "Camera"
        case .microphone:     return "Microphone"
        case .notifications:  return "Notifications"
        case .screencapture:  return "Screen Recording"
        case .location:       return "Location"
        case .inputMonitoring: return "Input Monitoring"
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

    // Notification authorization has no synchronous status API, so we cache the last known state.
    // The cache is populated on first check and after every request.
    private var cachedNotificationState: PermissionsState = .unknown

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
