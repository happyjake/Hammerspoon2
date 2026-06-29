//
//  Hammerspoon_2App.swift
//  Hammerspoon 2
//
//  Created by Chris Jones on 23/09/2025.
//

import SwiftUI
import Sparkle
import Darwin

@_documentation(visibility: private)
class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var instance: AppDelegate! = nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        AKTrace("applicationDidFinishLaunching: Creating/booting shared manager")

        // Raise the open-file-descriptor limit before any subsystem starts
        // opening sockets, webviews, SQLite handles or image destinations.
        AppDelegate.raiseOpenFileLimit()

        AppDelegate.instance = self
        ConsoleCompletionEngine.shared.prewarm()
        let managerManager = ManagerManager.shared
        do {
            try managerManager.boot()
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    /// macOS launches GUI apps with launchd's default soft `RLIMIT_NOFILE` of
    /// just **256** open file descriptors. That is far too low for a long-running
    /// automation host: webviews, HTTP connections, SQLite WAL handles, timers,
    /// event taps and peer sockets accumulate descriptors over hours of uptime.
    /// Once the process reaches 256, **every** subsequent `open()` fails with
    /// EMFILE — new sockets, file reads, and notably ImageIO's
    /// `CGImageDestinationCreateWithURL` (clipboard image capture started failing
    /// with "could not create destination"). Raise the soft limit toward the
    /// kernel's per-process ceiling so normal operation never hits the wall.
    static func raiseOpenFileLimit() {
        var lim = rlimit()
        guard unsafe getrlimit(RLIMIT_NOFILE, &lim) == 0 else {
            AKWarning("raiseOpenFileLimit: getrlimit failed")
            return
        }

        // The kernel rejects a soft limit above kern.maxfilesperproc, so clamp to
        // it (≈92k on modern Macs, but smaller on some configs).
        var perProc: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let sysctlRC = unsafe sysctlbyname("kern.maxfilesperproc", &perProc, &size, nil, 0)
        let kernelCap: rlim_t = (sysctlRC == 0 && perProc > 0) ? rlim_t(perProc) : 10240

        // Clamp under both the kernel per-process cap and our own hard limit.
        // rlim_max is either a real ceiling or the huge RLIM_INFINITY sentinel —
        // min() handles both, since our 64k target is tiny next to the sentinel.
        let desired = min(min(rlim_t(65536), kernelCap), lim.rlim_max)

        guard desired > lim.rlim_cur else {
            AKTrace("raiseOpenFileLimit: soft limit already \(lim.rlim_cur) (cap \(kernelCap)); leaving as-is")
            return
        }

        let previous = lim.rlim_cur
        lim.rlim_cur = desired
        if unsafe setrlimit(RLIMIT_NOFILE, &lim) == 0 {
            AKTrace("raiseOpenFileLimit: raised RLIMIT_NOFILE soft limit \(previous) → \(desired)")
        } else {
            AKWarning("raiseOpenFileLimit: setrlimit(\(desired)) failed")
        }
    }
}

@_documentation(visibility: private)
@main
struct Hammerspoon_2App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    var body: some Scene {
        MenuBarExtra("Hammerspoon 2", systemImage: "hammer") { // FIXME: Use the real logo here
            let managerManager = ManagerManager.shared

            Button("Reload Config") {
                try? managerManager.boot()
            }

            Divider()

            Button("Settings") {
                openSettings()
            }

            Button("Open Console") {
                if let url = URL(string:"hammerspoon2://openConsole") {
                    NSWorkspace.shared.open(url)
                }
            }

            Divider()

            CheckForUpdatesView(updater: updaterController.updater)

            Divider()

            Button("Quit") {
                managerManager.shutdown()
            }
        }
        Window("Content", id: "content") {
            ContentView()
        }

        Window("Console", id: "console") {
            ConsoleView()
        }
        .restorationBehavior(.disabled)
        .handlesExternalEvents(matching: ["openConsole", "closeConsole"])
        .commands {
            // About
            CommandGroup(replacing: CommandGroupPlacement.appInfo) {
                Button("About Hammerspoon 2") {
                    openWindow(id: "about")
                }
            }
        }

        Window("About Hammerspoon 2", id: "about") {
            AboutView()
                .containerBackground(.thickMaterial, for: .window)
                .windowResizeBehavior(.disabled)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .windowBackgroundDragBehavior(.enabled)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Settings() {
            SettingsView()
        }
    }
}
