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
import Darwin

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
    /// Encoded icons are cached across configuration reloads. Root changes,
    /// bundle path, metadata or icon-resource changes, and
    /// `invalidateInstalledAppsCache()` invalidate cached icons.
    /// Resource modification times and sizes are checked on cache hits.
    /// Changes cause a new native render; NSWorkspace/Icon Services may still
    /// retain older artwork in their own drawing caches. This API clears only
    /// its encoded PNG cache and preserves the native renderer's output.
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
    /// per unique `extraRoots` argument; the cache is dropped automatically
    /// when the contents of any scanned root change (an app is installed or
    /// deleted), so changes are visible on the next call. Call
    /// `invalidateInstalledAppsCache()` to force a rescan by hand.
    ///
    /// Roots scanned in order (dedup by bundleID — first wins):
    ///   1. /Applications
    ///   2. ~/Applications
    ///   3. /System/Applications
    ///   4. /System/Applications/Utilities
    ///   5. /System/Cryptexes/App/System/Applications (Safari — its
    ///      /Applications symlink is flagged hidden, so it must be scanned
    ///      at its real cryptex location)
    ///   6. /System/Library/CoreServices/Applications (Keychain Access,
    ///      Archive Utility, Directory Utility, …)
    ///   7. /System/Library/CoreServices/Finder.app (Finder)
    ///   8. Any caller-supplied extra roots
    ///
    /// A root may be a single `.app` bundle (like the Finder entry above), in
    /// which case that bundle itself is the result — extra roots may use this
    /// form too.
    ///
    /// Both bundle layouts are understood: regular macOS bundles
    /// (`Contents/Info.plist`) and the wrapper layout the App Store uses for
    /// iPhone/iPad apps on Apple silicon (`Foo.app/Wrapper/<Inner>.app/`).
    /// Wrapper apps report the inner bundle's metadata (that's where the
    /// localized `displayName` lives) with `path` pointing at the outer
    /// `.app` — the thing you launch or reveal in Finder.
    ///
    /// Bundles with `LSBackgroundOnly = true` (true daemons with no UI) are
    /// skipped. Menu-bar-only apps (`LSUIElement = true`, e.g. Hammerspoon 1,
    /// Bartender, ClipMenu) are included because users still launch them.
    /// `iconPath`, when non-null, points at the bundle's primary icon on disk
    /// (`.icns` for macOS bundles, the app-icon `.png` for iOS wrapper apps).
    ///
    /// The native cache survives configuration reloads. Within each JavaScript
    /// context, cache hits return the same frozen array of frozen records.
    /// Use `apps.map(app => ({...app}))` when mutable records are needed, or
    /// `apps.slice()` to sort a copy of the array.
    ///
    /// - Parameter extraRoots?: Optional array of additional directories to scan.
    /// - Returns: {ReadonlyArray<Readonly<Record<string, any>>>} Array of `{name, displayName, bundleID, path, iconPath, version}`
    /// - Example:
    /// ```js
    /// const apps = hs.application.installedApps()
    /// console.log(apps[0].displayName, apps[0].bundleID)
    ///
    /// // With extra roots:
    /// const more = hs.application.installedApps(['~/Tools', '~/Dev/Apps'])
    /// ```
    @objc(installedApps:) func installedApps(_ extraRoots: JSValue) -> JSValue

    /// Force the next call to `installedApps()` to rescan from disk, and clear
    /// cached application icons. Applies to all JavaScript contexts.
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
    ///    - listener: {(event: string, app: HSApplication | null) => void} A javascript function/lambda to call when any application event is received. The function will be called with two parameters: the name of the event, and the associated HSApplication object
    /// - Example:
    /// ```js
    /// hs.application.addWatcher((event, app) => {
    ///     console.log(event + app && app.title)
    /// })
    /// ```
    @objc func addWatcher(_ listener: JSFunction)

    /// Remove a watcher for application events
    /// - Parameters:
    ///   - listener: The javascript function/lambda that was previously being used to handle events
    /// - Example:
    /// ```js
    /// hs.application.removeWatcher(myHandler)
    /// ```
    @objc func removeWatcher(_ listener: JSFunction)

    // NOTE: These are not documented because they are private API for our JavaScript code
    /// SKIP_DOCS
    @objc(_addWatcher:) func _addWatcher(callback: JSFunction)
    /// SKIP_DOCS
    @objc func _removeWatcher()

    /// Swift-retained storage for the JS ApplicationModuleWatcherEmitter instance
    /// SKIP_DOCS
    @objc var _watcherEmitter: JSFunction? { get set }
}

// MARK: - Implementations

class HSApplicationWatcherObject {
    let callback: JSFunction

    static let notificationToEventName: [NSNotification.Name: String] = [
        NSWorkspace.willLaunchApplicationNotification: "willLaunch",
        NSWorkspace.didLaunchApplicationNotification: "didLaunch",
        NSWorkspace.didTerminateApplicationNotification: "didTerminate",
        NSWorkspace.didHideApplicationNotification: "didHide",
        NSWorkspace.didUnhideApplicationNotification: "didUnhide",
        NSWorkspace.didActivateApplicationNotification: "didActivate",
        NSWorkspace.didDeactivateApplicationNotification: "didDeactivate",
    ]

    init(callback: JSFunction) {
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

private final class InstalledAppsCacheEntry {
    let apps: [[String: Any]]
    let timestamp: TimeInterval

    init(apps: [[String: Any]], timestamp: TimeInterval) {
        self.apps = apps
        self.timestamp = timestamp
    }
}

/// Native data only: retaining a JSValue here would keep an old context alive.
@MainActor
private final class ApplicationInfoCache {
    static let shared = ApplicationInfoCache()
    var apps: [[String]: InstalledAppsCacheEntry] = [:]
    let ttl: TimeInterval = 30
    let rootWatcher = InstalledAppsRootWatcher()
    private(set) var generation: UInt64 = 0

    struct IconKey: Hashable {
        let bundleID: String
        let pixels: Int
    }

    struct IconEntry {
        let path: String
        let files: [IconFile]
        let base64: String
    }

    struct IconFile {
        struct Stamp: Equatable {
            let seconds: Int
            let nanoseconds: Int
            let size: Int64
            let inode: UInt64

            init?(_ path: String) {
                var info = Darwin.stat()
                guard unsafe Darwin.fstatat(AT_FDCWD, path, &info, 0) == 0 else { return nil }
                seconds = info.st_mtimespec.tv_sec
                nanoseconds = info.st_mtimespec.tv_nsec
                size = info.st_size
                inode = info.st_ino
            }
        }

        let path: String
        let stamp: Stamp?

        init(_ path: String) {
            self.path = path
            stamp = Stamp(path)
        }

        var isCurrent: Bool { stamp == Stamp(path) }
    }

    var icons: [IconKey: IconEntry] = [:]
    var iconRenderCount: UInt64 = 0

    func refreshIfNeeded() {
        if rootWatcher.consumeDirty() { invalidate() }
    }

    func invalidate() {
        apps.removeAll()
        icons.removeAll()
        // Reopen watches on the next fill: an updated root may have a new
        // inode, and roots no longer used must not retain descriptors forever.
        rootWatcher.cancelAll()
        generation &+= 1
    }
}

/// Watches application root directories (e.g. /Applications) and flips a
/// thread-safe dirty flag when any of them changes, so `installedApps()` can
/// drop its cache and reflect installs/deletes immediately instead of waiting
/// out the TTL.
///
/// Explicitly `nonisolated`: this project compiles with MainActor as the
/// default isolation, which would otherwise make this class — and the
/// DispatchSource event handler closures formed inside it — @MainActor.
/// Those handlers run on a private background queue, where a @MainActor
/// closure traps (EXC_BREAKPOINT in dispatch_assert_queue). All mutable
/// state is guarded by a lock instead; the MainActor module only calls
/// `watch`/`consumeDirty`/`cancelAll`.
private nonisolated final class InstalledAppsRootWatcher: @unchecked Sendable {
    private let lock = NSLock()
    private var watchedRoots = Set<String>()
    private var sources: [DispatchSourceFileSystemObject] = []
    private var dirty = false
    private var generation: UInt64 = 0
    private let queue = DispatchQueue(label: "hs.application.installedApps.rootwatch")

    /// Start watching a directory if it exists and isn't watched yet.
    /// Missing roots are retried on the next call (they may be created later).
    func watch(_ root: String) {
        lock.lock()
        let alreadyWatched = watchedRoots.contains(root)
        let watchGeneration = generation
        lock.unlock()
        if alreadyWatched { return }

        let fd = open(root, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .link, .rename, .delete],
            queue: queue)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            self.lock.lock()
            if self.generation == watchGeneration { self.dirty = true }
            self.lock.unlock()
        }
        source.setCancelHandler { close(fd) }
        lock.lock()
        watchedRoots.insert(root)
        sources.append(source)
        lock.unlock()
        source.activate()
    }

    /// Returns true (once) if any watched root changed since the last call.
    func consumeDirty() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let wasDirty = dirty
        dirty = false
        return wasDirty
    }

    func cancelAll() {
        lock.lock()
        let toCancel = sources
        sources = []
        watchedRoots = []
        dirty = false
        generation &+= 1
        lock.unlock()
        toCancel.forEach { $0.cancel() }
    }
}

@_documentation(visibility: private)
@MainActor
@objc class HSApplicationModule: NSObject, HSModuleAPI, HSApplicationModuleAPI {
    var name = "hs.application"
    let engineID: UUID
    private var watcher: HSApplicationWatcherObject? = nil

    // Strong JS references belong to this module's context, never the singleton.
    private var installedAppsValues: [[String]: (entry: InstalledAppsCacheEntry, value: JSValue)] = [:]
    private var installedAppsGeneration: UInt64 = 0

    /// Native diagnostic only; counts actual rasterizations across contexts.
    static var iconRenderCount: UInt64 { ApplicationInfoCache.shared.iconRenderCount }

    // Swift-retained storage for the JS-defined ApplicationModuleWatcherEmitter instance
    @objc var _watcherEmitter: JSFunction? = nil

    // MARK: - Module lifecycle
    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKDebug("Init of \(name): \(engineID)")
    }

    func shutdown() {
        _removeWatcher()
        installedAppsValues.removeAll()
        _watcherEmitter = nil
    }

    isolated deinit {
        AKDebug("Deinit of \(name): \(engineID)")
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

    @objc func addWatcher(_ listener: JSFunction) {
        _watcherEmitter?.invokeMethod("on", withArguments: [listener])
    }

    @objc func removeWatcher(_ listener: JSFunction) {
        _watcherEmitter?.invokeMethod("removeListener", withArguments: [listener])
    }

    @objc(_addWatcher:) func _addWatcher(callback: JSFunction) {
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

    @objc(installedApps:) func installedApps(_ extraRoots: JSValue) -> JSValue {
        let extras = extractExtraRoots(extraRoots)
        let cache = ApplicationInfoCache.shared
        cache.refreshIfNeeded()
        // Bound process-lifetime storage when callers use many distinct roots.
        if cache.apps[extras] == nil, cache.apps.count >= 32 { cache.invalidate() }
        if installedAppsGeneration != cache.generation {
            installedAppsValues.removeAll()
            installedAppsGeneration = cache.generation
        }
        let now = Date().timeIntervalSince1970
        let entry: InstalledAppsCacheEntry
        if let cached = cache.apps[extras], now - cached.timestamp < cache.ttl {
            entry = cached
        } else {
            entry = InstalledAppsCacheEntry(apps: scanInstalledApps(extras), timestamp: now)
            cache.apps[extras] = entry
        }
        if let cached = installedAppsValues[extras], cached.entry === entry,
           cached.value.context === extraRoots.context {
            return cached.value
        }

        let context = extraRoots.context!
        let value = JSValue(object: entry.apps, in: context)!
        // Every field is a scalar. Freezing the records as well as the array
        // prevents one caller from changing a later caller's cached result.
        _ = context.evaluateScript("""
            (function(apps) {
                for (let i = 0; i < apps.length; i++) Object.freeze(apps[i]);
                return Object.freeze(apps);
            })
            """)?.call(withArguments: [value])
        installedAppsValues[extras] = (entry, value)
        return value
    }

    private func scanInstalledApps(_ extras: [String]) -> [[String: Any]] {
        let standardRoots = [
            "/Applications",
            NSString(string: "~/Applications").expandingTildeInPath,
            "/System/Applications",
            "/System/Applications/Utilities",
            // Safari's real bundle since macOS 13 — the /Applications/Safari.app
            // symlink carries UF_HIDDEN, so the skipsHiddenFiles scan above
            // never sees it. Finder merges the cryptex view; we must scan it.
            "/System/Cryptexes/App/System/Applications",
            // Keychain Access, Archive Utility, Directory Utility, … moved
            // here in macOS 13.
            "/System/Library/CoreServices/Applications",
            // A root may be a single .app bundle. Finder has no sibling apps
            // we'd want (Dock, loginwindow, …), so it's listed alone rather
            // than scanning all of CoreServices.
            "/System/Library/CoreServices/Finder.app",
        ]
        let allRoots = standardRoots + extras

        var seen = Set<String>()
        var result: [[String: Any]] = []
        for root in allRoots {
            // Watch before scanning so a change racing the scan still marks
            // the cache dirty for the next call.
            ApplicationInfoCache.shared.rootWatcher.watch(root)
            for url in scanForApps(in: root) {
                guard let (info, innerBundle) = readAppInfo(at: url),
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
                    "iconPath":    iconPathFromBundle(info: info, appPath: url.path, innerBundle: innerBundle) as Any,
                    "version":     info["CFBundleShortVersionString"] as? String ?? "",
                ])
            }
        }
        return result
    }

    @objc func invalidateInstalledAppsCache() {
        ApplicationInfoCache.shared.invalidate()
        installedAppsValues.removeAll()
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
        // A root that is itself a bundle (e.g. Finder.app) is the app.
        if rootURL.pathExtension == "app" {
            return [rootURL]
        }
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

    /// Reads an app's Info.plist, understanding both bundle layouts:
    ///   - macOS:       Foo.app/Contents/Info.plist
    ///   - iOS wrapper: Foo.app/Wrapper/<Inner>.app/Info.plist — the flat iOS
    ///     bundle layout the App Store uses when installing iPhone/iPad apps
    ///     on Apple silicon.
    /// Returns the plist plus the inner bundle URL for wrapper apps (nil for
    /// regular macOS bundles) so icon resolution can look in the right place.
    private func readAppInfo(at appURL: URL) -> (info: [String: Any], innerBundle: URL?)? {
        if let info = plistDictionary(at: appURL.appendingPathComponent("Contents/Info.plist")) {
            return (info, nil)
        }
        if let inner = wrappedBundleURL(at: appURL),
           let info = plistDictionary(at: inner.appendingPathComponent("Info.plist")) {
            return (info, inner)
        }
        return nil
    }

    private func plistDictionary(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    /// Resolves the inner bundle of an iOS wrapper app: prefer the
    /// `WrappedBundle` symlink the App Store creates, fall back to the first
    /// `Wrapper/*.app` entry that carries an Info.plist.
    private func wrappedBundleURL(at appURL: URL) -> URL? {
        let fm = FileManager.default
        let linkPath = appURL.appendingPathComponent("WrappedBundle").path
        if let dest = try? fm.destinationOfSymbolicLink(atPath: linkPath) {
            let resolved = dest.hasPrefix("/")
                ? URL(fileURLWithPath: dest)
                : appURL.appendingPathComponent(dest).standardizedFileURL
            if fm.fileExists(atPath: resolved.appendingPathComponent("Info.plist").path) {
                return resolved
            }
        }
        let wrapper = appURL.appendingPathComponent("Wrapper")
        if let entries = try? fm.contentsOfDirectory(at: wrapper, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries where entry.pathExtension == "app" {
                if fm.fileExists(atPath: entry.appendingPathComponent("Info.plist").path) {
                    return entry
                }
            }
        }
        return nil
    }

    @objc func iconForBundleID(_ bundleID: String) -> String? {
        let cache = ApplicationInfoCache.shared
        cache.refreshIfNeeded()
        let workspace = NSWorkspace.shared
        // urlForApplication looks up the app by bundle identifier; if the
        // bundleID isn't a known installed app (e.g. a CLI tool or service),
        // fall through to nil — caller will use a fallback letter tile.
        guard let url = workspace.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let key = ApplicationInfoCache.IconKey(bundleID: bundleID, pixels: 88)
        if cache.icons[key] == nil, cache.icons.count >= 256 { cache.invalidate() }
        cache.rootWatcher.watch(url.deletingLastPathComponent().path)
        cache.rootWatcher.watch(url.path)
        if let cached = cache.icons[key], cached.path == url.path,
           cached.files.allSatisfy(\.isCurrent) {
            return cached.base64
        }
        // Resolve dependencies only on a miss. Hits stat these paths without
        // re-reading the plist or relying on cached URL resource values.
        let files = iconFiles(at: url)
        // NSWorkspace returns an NSImage that includes multiple representations
        // (multi-size .icns). Pick a 44px target so the rendered PNG is sharp
        // on @2x without being huge.
        cache.iconRenderCount &+= 1
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
        let base64 = png.base64EncodedString()
        if files.first?.stamp != nil {
            cache.icons[key] = ApplicationInfoCache.IconEntry(
                path: url.path, files: files, base64: base64)
        }
        return base64
    }

    private func iconFiles(at appURL: URL) -> [ApplicationInfoCache.IconFile] {
        var paths = [appURL.path, appURL.appendingPathComponent("Contents/Info.plist").path]
        if let (info, innerBundle) = readAppInfo(at: appURL) {
            let resources = innerBundle ?? appURL.appendingPathComponent("Contents/Resources")
            if let innerBundle {
                paths.append(innerBundle.appendingPathComponent("Info.plist").path)
            }
            // Track the resource directory too, including when absent, so a
            // newly supplied icon replaces a previously cached generic icon.
            paths.append(resources.path)
            paths.append(resources.appendingPathComponent("Assets.car").path)
            let primary = (info["CFBundleIcons"] as? [String: Any])?["CFBundlePrimaryIcon"] as? [String: Any]
            for declaration in [info, primary ?? [:]] {
                var names = declaration["CFBundleIconFiles"] as? [String] ?? []
                if let file = declaration["CFBundleIconFile"] as? String { names.append(file) }
                if let name = declaration["CFBundleIconName"] as? String { names.append(name) }
                for name in names {
                    if innerBundle != nil {
                        // Icon Services can choose any representation, not
                        // just the preferred path exposed by installedApps().
                        paths.append(resources.appendingPathComponent(name).path)
                        let base = (name as NSString).deletingPathExtension
                        for suffix in ["@3x.png", "@2x.png", ".png", "@2x~ipad.png", "~ipad.png"] {
                            paths.append(resources.appendingPathComponent(base + suffix).path)
                        }
                    } else {
                        let filename = (name as NSString).pathExtension.isEmpty ? name + ".icns" : name
                        paths.append(resources.appendingPathComponent(filename).path)
                    }
                }
            }
        }
        var seen = Set<String>()
        return paths.filter { seen.insert($0).inserted }.map(ApplicationInfoCache.IconFile.init)
    }

    /// Resolves the path of the bundle's primary icon without any image
    /// processing — `.icns` for macOS bundles, the app-icon PNG for iOS
    /// wrapper bundles. macOS / SwiftUI render both natively, so callers can
    /// hand this path directly to `hs.image.fromPath()` or pass it through to
    /// SwiftUI without converting. Returns nil if the bundle doesn't declare
    /// an icon or the file doesn't exist on disk.
    private func iconPathFromBundle(info: [String: Any], appPath: String, innerBundle: URL? = nil) -> String? {
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

        if let innerBundle {
            // iOS wrapper bundle: icons are PNGs at the inner bundle root,
            // named like AppIcon60x60@2x.png — try the common scale/idiom
            // suffixes in quality order.
            let base = (name as NSString).pathExtension.isEmpty
                ? name
                : (name as NSString).deletingPathExtension
            for suffix in ["@3x.png", "@2x.png", ".png", "@2x~ipad.png", "~ipad.png"] {
                let candidate = innerBundle.appendingPathComponent(base + suffix).path
                if FileManager.default.fileExists(atPath: candidate) { return candidate }
            }
            return nil
        }

        if (name as NSString).pathExtension.isEmpty {
            name += ".icns"
        }

        let path = (appPath as NSString).appendingPathComponent("Contents/Resources/\(name)")
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }
}

