//
//  Applications.swift
//  Hammerspoon 2
//
//  Created by Chris Jones on 13/10/2025.
//

import Foundation
import JavaScriptCore
import AppKit
import AXSwift
import UniformTypeIdentifiers

// MARK: - Declare our JavaScript API

/// Module for interacting with applications
@objc protocol HSApplicationModuleAPI: JSExport {
    /// Fetch all running applications
    /// - Returns: An array of all currently running applications
    /// - Example:
    /// ```js
    /// const apps = hs.application.runningApplications()
    /// apps.forEach(a => console.log(a.title))
    /// ```
    @objc func runningApplications() -> [HSApplication]

    /// Fetch the first running application that matches a name
    /// - Parameter name: The applicaiton name to search for
    /// - Returns: The first matching application, or nil if none matched
    /// - Example:
    /// ```js
    /// const safari = hs.application.matchingName("Safari")
    /// ```
    @objc func matchingName(_ name: String) -> HSApplication?

    /// Fetch the first running application that matches a Bundle ID
    /// - Parameter bundleID: The identifier to search for
    /// - Returns: The first matching application, or nil if none matched
    /// - Example:
    /// ```js
    /// const safari = hs.application.matchingBundleID("com.apple.Safari")
    /// ```
    @objc func matchingBundleID(_ bundleID: String) -> HSApplication?

    /// Fetch the running application that matches a POSIX PID
    /// - Parameter pid: The PID to search for
    /// - Returns: The matching application, or nil if none matched
    /// - Example:
    /// ```js
    /// const app = hs.application.fromPID(1234)
    /// ```
    @objc func fromPID(_ pid: Int) -> HSApplication?

    /// Fetch the currently focused application
    /// - Returns: The matching application, or nil if none matched
    /// - Example:
    /// ```js
    /// const app = hs.application.frontmost()
    /// console.log(app.title)
    /// ```
    @objc func frontmost() -> HSApplication?

    /// Fetch the application which currently owns the menu bar
    /// - Returns: The matching application, or nil if none matched
    /// - Example:
    /// ```js
    /// const owner = hs.application.menuBarOwner()
    /// ```
    @objc func menuBarOwner() -> HSApplication?

    /// Fetch the filesystem path for an application
    /// - Parameter bundleID: The application bundle identifier to search for (e.g. "com.apple.Safari")
    /// - Returns: The application's filesystem path, or nil if it was not found
    /// - Example:
    /// ```js
    /// const path = hs.application.pathForBundleID("com.apple.Safari")
    /// ```
    @objc func pathForBundleID(_ bundleID: String) -> String?

    /// Render the application's icon as a base64-encoded PNG string. Use the
    /// returned string as the body of a `data:image/png;base64,…` URL to render
    /// the icon in HTML/SwiftUI without exposing the underlying .icns path.
    /// Falls back to NSWorkspace's generic icon if no application is found.
    /// - Parameter bundleID: The application bundle identifier (e.g. "com.apple.Safari")
    /// - Returns: The base64-encoded PNG bytes, or null if the bundle could not be located
    /// - Example:
    /// ```js
    /// const b64 = hs.application.iconForBundleID("com.apple.Safari")
    /// element.src = "data:image/png;base64," + b64
    /// ```
    @objc func iconForBundleID(_ bundleID: String) -> String?

    /// Fetch filesystem paths for an application
    /// - Parameter bundleID: The application bundle identifier to search for (e.g. "com.apple.Safari")
    /// - Returns: An array of strings containing any filesystem paths that were found
    /// - Example:
    /// ```js
    /// const paths = hs.application.pathsForBundleID("com.apple.Safari")
    /// ```
    @objc func pathsForBundleID(_ bundleID: String) -> [String]

    /// SKIP_DOCS
    /// Fetch a dictionary of information about an application bundle, given its path
    /// - Parameter bundlePath: The path to a bundle (e.g. "/Applications/Safari.app")
    /// - Returns: A dictionary of information about the bundle
    @objc func infoForBundlePath(_ bundlePath: String) -> [String: Any]?

    /// Fetch filesystem path for an application able to open a given file type
    /// - Parameter fileType: The file type to search for. This can be a UTType identifier, a MIME type, or a filename extension
    /// - Returns: The path to an application for the given filetype, or il if none were found
    /// - Example:
    /// ```js
    /// const path = hs.application.pathForFileType("public.html")
    /// ```
    @objc func pathForFileType(_ fileType: String) -> String?

    /// Fetch filesystem paths for applications able to open a given file type
    /// - Parameter fileType: The file type to search for. This can be a UTType identifier, a MIME type, or a filename extension
    /// - Returns: An array of strings containing the filesystem paths for any applications that were found
    /// - Example:
    /// ```js
    /// const paths = hs.application.pathsForFileType("png")
    /// ```
    @objc func pathsForFileType(_ fileType: String) -> [String]

    /// Launch an application, or give it focus if it's already running
    /// - Parameter bundleID: A bundle identifier for the app to launch/focus (e.g. "com.apple.Safari")
    /// - Returns: {Promise<boolean>} A Promise that resolves to true if successful, false otherwise
    /// - Example:
    /// ```js
    /// hs.application.launchOrFocus("com.apple.Safari").then(ok => console.log(ok))
    /// ```
    @objc func launchOrFocus(_ bundleID: String) -> JSPromise?

    /// Enumerate every `.app` bundle under the standard application roots,
    /// plus any caller-supplied extra roots. Results are cached for 30 seconds
    /// per unique `extraRoots` argument; call `invalidateInstalledAppsCache()`
    /// to force a rescan.
    ///
    /// Roots scanned in order (dedup by bundleID — first wins):
    ///   1. /Applications
    ///   2. ~/Applications
    ///   3. /System/Applications
    ///   4. /System/Applications/Utilities
    ///   5. Any caller-supplied extra roots
    ///
    /// Bundles with `LSBackgroundOnly = true` (true daemons with no UI) are
    /// skipped. Menu-bar-only apps (`LSUIElement = true`, e.g. Hammerspoon 1,
    /// Bartender, ClipMenu) are included because users still launch them.
    /// Icons are extracted on first scan to `~/Library/Caches/Hammerspoon2/app-icons/`.
    ///
    /// - Parameter extraRoots: Optional array of additional directories to scan.
    /// - Returns: Array of `{name, displayName, bundleID, path, iconPath, version}`
    /// - Example:
    /// ```js
    /// const apps = hs.application.installedApps()
    /// console.log(apps[0].displayName, apps[0].bundleID)
    ///
    /// // With extra roots:
    /// const more = hs.application.installedApps(['~/Tools', '~/Dev/Apps'])
    /// ```
    @objc(installedApps:) func installedApps(_ extraRoots: JSValue) -> [[String: Any]]

    /// Force the next call to `installedApps()` to rescan from disk.
    /// - Example:
    /// ```js
    /// hs.application.invalidateInstalledAppsCache()
    /// ```
    @objc func invalidateInstalledAppsCache()

    /// Send SIGTERM (force=false) or SIGKILL (force=true) to an arbitrary PID.
    /// Refuses to signal PID 0, 1, or this process. Returns true if the signal
    /// was delivered, false on error (logged via AKError).
    /// - Parameter pid: Target PID
    /// - Parameter force: When true sends SIGKILL; otherwise SIGTERM.
    /// - Returns: true on success
    /// - Example:
    /// ```js
    /// hs.application.killPid(12345, false)   // graceful
    /// hs.application.killPid(12345, true)    // force
    /// ```
    @objc func killPid(_ pid: Int, _ force: Bool) -> Bool

    /// Create a watcher for application events
    /// - Parameters:
    ///    - listener: A javascript function/lambda to call when any application event is received. The function will be called with two parameters: the name of the event, and the associated HSApplication object
    /// - Example:
    /// ```js
    /// hs.application.addWatcher((event, app) => {
    ///     console.log(event, app && app.title)
    /// })
    /// ```
    @objc func addWatcher(_ listener: JSValue)

    /// Remove a watcher for application events
    /// - Parameters:
    ///   - listener: The javascript function/lambda that was previously being used to handle events
    /// - Example:
    /// ```js
    /// hs.application.removeWatcher(myHandler)
    /// ```
    @objc func removeWatcher(_ listener: JSValue)

    // NOTE: These are not documented because they are private API for our JavaScript code
    /// SKIP_DOCS
    @objc(_addWatcher:) func _addWatcher(callback: JSValue)
    /// SKIP_DOCS
    @objc func _removeWatcher()

    /// Swift-retained storage for the JS ApplicationModuleWatcherEmitter instance
    /// SKIP_DOCS
    @objc var _watcherEmitter: JSValue? { get set }
}

// MARK: - Implementations

class HSApplicationWatcherObject {
    let callback: JSValue

    static let notificationToEventName: [NSNotification.Name: String] = [
        NSWorkspace.willLaunchApplicationNotification: "willLaunch",
        NSWorkspace.didLaunchApplicationNotification: "didLaunch",
        NSWorkspace.didTerminateApplicationNotification: "didTerminate",
        NSWorkspace.didHideApplicationNotification: "didHide",
        NSWorkspace.didUnhideApplicationNotification: "didUnhide",
        NSWorkspace.didActivateApplicationNotification: "didActivate",
        NSWorkspace.didDeactivateApplicationNotification: "didDeactivate",
    ]

    init(callback: JSValue) {
        self.callback = callback
    }

    @objc func handleEvent(notification: NSNotification) {
        guard let eventName = Self.notificationToEventName[notification.name] else {
            AKError("hs.application: received unknown notification: \(notification.name)")
            return
        }
        let eventApp = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.asHSApplication()
        callback.callSafely(withArguments: [eventName, eventApp as Any], context: "hs.application watcher")
    }
}

private struct InstalledAppsCacheEntry {
    let apps: [[String: Any]]
    let timestamp: TimeInterval
}

@_documentation(visibility: private)
@MainActor
@objc class HSApplicationModule: NSObject, HSModuleAPI, HSApplicationModuleAPI {
    var name = "hs.application"
    let engineID: UUID
    private var watcher: HSApplicationWatcherObject? = nil

    // installedApps() cache: keyed by the joined extraRoots string.
    private var installedAppsCache: [String: InstalledAppsCacheEntry] = [:]
    private let installedAppsCacheTTL: TimeInterval = 30

    // Swift-retained storage for the JS-defined ApplicationModuleWatcherEmitter instance
    @objc var _watcherEmitter: JSValue? = nil

    // MARK: - Module lifecycle
    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {
        _removeWatcher()
    }

    isolated deinit {
        AKTrace("Deinit of \(name): \(engineID)")
        shutdown()
    }

    // MARK: - API relating to running applications
    @objc func runningApplications() -> [HSApplication] {
        let apps = NSWorkspace.shared.runningApplications.compactMap { $0.asHSApplication() }
        return apps
    }

    @objc func matchingName(_ name: String) -> HSApplication? {
        return NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name })?.asHSApplication()
    }

    @objc func matchingBundleID(_ bundleID: String) -> HSApplication? {
        return NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID })?.asHSApplication()
    }

    @objc func fromPID(_ pid: Int) -> HSApplication? {
        return NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid })?.asHSApplication()
    }

    @objc func frontmost() -> HSApplication? {
        return NSWorkspace.shared.frontmostApplication?.asHSApplication()
    }

    @objc func menuBarOwner() -> HSApplication? {
        return NSWorkspace.shared.menuBarOwningApplication?.asHSApplication()
    }

    @objc func addWatcher(_ listener: JSValue) {
        _watcherEmitter?.invokeMethod("on", withArguments: [listener])
    }

    @objc func removeWatcher(_ listener: JSValue) {
        _watcherEmitter?.invokeMethod("removeListener", withArguments: [listener])
    }

    @objc(_addWatcher:) func _addWatcher(callback: JSValue) {
        if watcher != nil {
            AKWarning("hs.application._addWatcher(): Already watching. Refusing to create a second.")
            return
        }

        let watcherObject = HSApplicationWatcherObject(callback: callback)
        let selector = #selector(HSApplicationWatcherObject.handleEvent(notification:))

        for notificationName in HSApplicationWatcherObject.notificationToEventName.keys {
            AKTrace("hs.application._addWatcher(): Registering for \(notificationName.rawValue)")
            NSWorkspace.shared.notificationCenter.addObserver(watcherObject,
                                                              selector: selector,
                                                              name: notificationName,
                                                              object: nil)
        }

        watcher = watcherObject
    }

    @objc func _removeWatcher() {
        guard let watcherObject = watcher else { return }

        for notificationName in HSApplicationWatcherObject.notificationToEventName.keys {
            NSWorkspace.shared.notificationCenter.removeObserver(watcherObject as Any,
                                                                 name: notificationName,
                                                                 object: nil)
        }

        watcher = nil
        AKTrace("hs.application._removeWatcher(): Removed all application event watchers")
    }

    // MARK: - API for application information
    @objc func pathForBundleID(_ bundleID: String) -> String? {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path(percentEncoded: false)
    }

    @objc func pathsForBundleID(_ bundleID: String) -> [String] {
        return NSWorkspace.shared.urlsForApplications(withBundleIdentifier: bundleID).compactMap { $0.path(percentEncoded: false) }
    }

    @objc func infoForBundlePath(_ bundlePath: String) -> [String: Any]? {
        guard let app = Bundle(path: bundlePath) else {
            return nil
        }
        return app.infoDictionary
    }

    private func fileTypeToUTType(_ fileType: String) -> UTType? {
        var utType: UTType? = nil

        utType = UTType(fileType)
        if utType == nil {
            utType = UTType(mimeType: fileType)
        }
        if utType == nil {
            utType = UTType(filenameExtension: fileType)
        }

        return utType
    }

    @objc func pathForFileType(_ fileType: String) -> String? {
        guard let utType = fileTypeToUTType(fileType) else {
            AKError("Unable to resolve file type: \(fileType)")
            return nil
        }

        return NSWorkspace.shared.urlForApplication(toOpen: utType)?.path(percentEncoded: false)
    }

    @objc func pathsForFileType(_ fileType: String) -> [String] {
        guard let utType = fileTypeToUTType(fileType) else {
            AKError("Unable to resolve file type: \(fileType)")
            return []
        }

        return NSWorkspace.shared.urlsForApplications(toOpen: utType).compactMap { $0.path(percentEncoded: false) }
    }

    @objc func launchOrFocus(_ bundleID: String) -> JSPromise? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return JSEngine.shared.createResolvedPromise(with: false)
        }

        return JSEngine.shared.createPromise { holder in
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { app, error in
                Task { @MainActor in
                    if let error = error {
                        AKError("hs.application.launchOrFocus: \(error.localizedDescription)")
                        holder.resolveWith(false)
                    } else {
                        holder.resolveWith(app != nil)
                    }
                }
            }
        }
    }

    // MARK: - Installed apps + process signaling

    @objc(installedApps:) func installedApps(_ extraRoots: JSValue) -> [[String: Any]] {
        let extras = extractExtraRoots(extraRoots)
        let cacheKey = extras.joined(separator: "\n")
        let now = Date().timeIntervalSince1970
        if let entry = installedAppsCache[cacheKey],
           now - entry.timestamp < installedAppsCacheTTL {
            return entry.apps
        }

        let standardRoots = [
            "/Applications",
            NSString(string: "~/Applications").expandingTildeInPath,
            "/System/Applications",
            "/System/Applications/Utilities",
        ]
        let allRoots = standardRoots + extras

        var seen = Set<String>()
        var result: [[String: Any]] = []
        for root in allRoots {
            for url in scanForApps(in: root) {
                guard let info = readInfoPlist(at: url),
                      let bundleID = info["CFBundleIdentifier"] as? String else { continue }
                if seen.contains(bundleID) { continue }
                // Exclude only true daemons (`LSBackgroundOnly = true` — no UI
                // at all). LSUIElement / NSUIElement apps like Hammerspoon 1,
                // Bartender, ClipMenu, MonitorControl live in the menu bar
                // without a Dock icon but are very much user-launchable and
                // should appear in the launcher.
                if (info["LSBackgroundOnly"] as? Bool == true) ||
                   (info["NSBGOnly"] as? Bool == true) { continue }
                seen.insert(bundleID)

                let name = info["CFBundleName"] as? String ?? url.deletingPathExtension().lastPathComponent
                let displayName = info["CFBundleDisplayName"] as? String ?? name

                result.append([
                    "name":        name,
                    "displayName": displayName,
                    "bundleID":    bundleID,
                    "path":        url.path,
                    "iconPath":    iconPathFromBundle(info: info, appPath: url.path) as Any,
                    "version":     info["CFBundleShortVersionString"] as? String ?? "",
                ])
            }
        }
        installedAppsCache[cacheKey] = InstalledAppsCacheEntry(apps: result, timestamp: now)
        return result
    }

    @objc func invalidateInstalledAppsCache() {
        installedAppsCache.removeAll()
    }

    @objc func killPid(_ pid: Int, _ force: Bool) -> Bool {
        let myPid = Int(ProcessInfo.processInfo.processIdentifier)
        guard pid > 1, pid != myPid else {
            AKWarning("hs.application.killPid: refused to signal pid \(pid)")
            return false
        }
        let sig: Int32 = force ? SIGKILL : SIGTERM
        let rc = kill(pid_t(pid), sig)
        if rc != 0 {
            let err = errno
            AKError("hs.application.killPid: kill(\(pid), \(sig)) failed: \(String(cString: strerror(err)))")
            return false
        }
        return true
    }

    // MARK: - Private helpers for installedApps

    private func extractExtraRoots(_ value: JSValue) -> [String] {
        guard value.isArray else { return [] }
        let count = Int(value.objectForKeyedSubscript("length")?.toInt32() ?? 0)
        var result: [String] = []
        for i in 0..<count {
            if let s = value.atIndex(i)?.toString(), !s.isEmpty {
                result.append(NSString(string: s).expandingTildeInPath)
            }
        }
        return result
    }

    private func scanForApps(in root: String) -> [URL] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: root) else { return [] }
        let rootURL = URL(fileURLWithPath: root)
        var found: [URL] = []
        if let entries = try? fm.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries {
                if entry.pathExtension == "app" {
                    found.append(entry)
                } else {
                    // Recurse one level for /Applications/Utilities/*.app patterns
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue {
                        if let sub = try? fm.contentsOfDirectory(at: entry, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                            for s in sub where s.pathExtension == "app" {
                                found.append(s)
                            }
                        }
                    }
                }
            }
        }
        return found
    }

    private func readInfoPlist(at appURL: URL) -> [String: Any]? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    @objc func iconForBundleID(_ bundleID: String) -> String? {
        let workspace = NSWorkspace.shared
        // urlForApplication looks up the app by bundle identifier; if the
        // bundleID isn't a known installed app (e.g. a CLI tool or service),
        // fall through to nil — caller will use a fallback letter tile.
        guard let url = workspace.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        // NSWorkspace returns an NSImage that includes multiple representations
        // (multi-size .icns). Pick a 44px target so the rendered PNG is sharp
        // on @2x without being huge.
        let icon = workspace.icon(forFile: url.path)
        let target = NSSize(width: 44, height: 44)
        // Render at @2x for retina sharpness, but keep the *bitmap*'s declared
        // size at the logical 44pt so CSS `width:22px;height:22px` still fits.
        let scale: CGFloat = 2
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(target.width * scale),
            pixelsHigh: Int(target.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32
        ) else { return nil }
        bitmap.size = target
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        icon.draw(in: NSRect(origin: .zero, size: target))
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
        return png.base64EncodedString()
    }

    /// Resolves the path of the bundle's primary icon (.icns) without any image
    /// processing. macOS / SwiftUI both render `.icns` files natively, so callers
    /// can hand this path directly to `hs.image.fromPath()` or pass it through to
    /// SwiftUI without converting. Returns nil if the bundle doesn't declare an
    /// icon or the file doesn't exist on disk.
    private func iconPathFromBundle(info: [String: Any], appPath: String) -> String? {
        var iconName: String?

        // Modern (iOS/macOS): CFBundleIcons → CFBundlePrimaryIcon → CFBundleIconFile / IconFiles
        if let icons = info["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any] {
            iconName = primary["CFBundleIconFile"] as? String
            if iconName == nil, let files = primary["CFBundleIconFiles"] as? [String] {
                iconName = files.last
            }
        }

        // Legacy: top-level CFBundleIconFile
        if iconName == nil {
            iconName = info["CFBundleIconFile"] as? String
        }

        guard var name = iconName else { return nil }
        if (name as NSString).pathExtension.isEmpty {
            name += ".icns"
        }

        let path = (appPath as NSString).appendingPathComponent("Contents/Resources/\(name)")
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }
}

