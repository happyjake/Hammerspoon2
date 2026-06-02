//
//  ModuleRoot.swift
//  Hammerspoon 2
//
//  Created by Chris Jones on 27/09/2025.
//

import Foundation
import JavaScriptCore
import JavaScriptCoreExtras

@_documentation(visibility: private)
@objc protocol ModuleRootAPI: JSExport {
    // Core
    @objc func reload()

    // Modules
    @objc var appinfo: HSAppInfoModule { get }
    @objc var application: HSApplicationModule { get }
    @objc var audiodevice: HSAudioDeviceModule { get }
    @objc var ax: HSAXModule { get }
    @objc var ble: HSBLEModule { get }
    @objc var bonjour: HSBonjourModule { get }
    @objc var camera: HSCameraModule { get }
    @objc var console: HSConsoleModule { get }
    @objc var crypto: HSCryptoModule { get }
    @objc var eventtap: HSEventTapModule { get }
    @objc var fs: HSFSModule { get }
    @objc var hashing: HSHashModule { get }
    @objc var hotkey: HSHotkeyModule { get }
    @objc var httpserver: HSHttpServerModule { get }
    @objc var keychain: HSKeychainModule { get }
    @objc var location: HSLocationModule { get }
    @objc var menubar: HSMenubarModule { get }
    @objc var mouse: HSMouseModule { get }
    @objc var multipeer: HSMultipeerModule { get }
    @objc var permissions: HSPermissionsModule { get }
    @objc var notify: HSNotifyModule { get }
    @objc var osascript: HSOSAScriptModule { get }
    @objc var pasteboard: HSPasteboardModule { get }
    @objc var screen: HSScreenModule { get }
    @objc var serial: HSSerialModule { get }
    @objc var sqlite: HSSqliteModule { get }
    @objc var switcher: HSSwitcherModule { get }
    @objc var task: HSTaskModule { get }
    @objc var power: HSPowerModule { get }
    @objc var text: HSTextModule { get }
    @objc var timer: HSTimerModule { get }
    @objc var ui: HSUIModule { get }
    @objc var webview: HSWebviewModule { get }
    @objc var window: HSWindowModule { get }
}

@_documentation(visibility: private)
@objc class ModuleRoot: NSObject, ModuleRootAPI {
    let engineID: UUID
    @objc var modules: [String: HSModuleAPI] = [:]

    init(engineID: UUID) {
        self.engineID = engineID
        super.init()
    }

    private func getOrCreate<T>(name: String, type: T.Type) -> T where T:HSModuleAPI {
        if let result = modules[name] as? T {
            return result
        } else {
            AKTrace("Loading module: \(name)")
            let module = type.init(engineID: engineID)
            modules[name] = module

            if let moduleJS = Bundle.main.url(forResource: "hs.\(name)", withExtension: "js") {
                try? _ = JSEngine.shared.evalFromURL(moduleJS)
            }

            return module
        }
    }

    func shutdown() {
        for moduleName in modules.keys {
            AKTrace("Destroying module \(moduleName)")
            let module = modules[moduleName]
            module?.shutdown()
            modules.removeValue(forKey: moduleName)
        }
    }

    // MARK: - ModuleRootAPI conformance

    // Core
    @objc func reload() {
        do {
            try ManagerManager.shared.boot()
        } catch {
            AKError("Unable to reload config: \(error.localizedDescription)")
        }
    }

    // Modules
    @objc var appinfo: HSAppInfoModule { get { getOrCreate(name: "appinfo", type: HSAppInfoModule.self)}}
    @objc var application: HSApplicationModule { get { getOrCreate(name: "application", type: HSApplicationModule.self)}}
    @objc var audiodevice: HSAudioDeviceModule { get { getOrCreate(name: "audiodevice", type: HSAudioDeviceModule.self)}}
    @objc var ax: HSAXModule { get { getOrCreate(name: "ax", type: HSAXModule.self)}}
    @objc var ble: HSBLEModule { get { getOrCreate(name: "ble", type: HSBLEModule.self)}}
    @objc var bonjour: HSBonjourModule { get { getOrCreate(name: "bonjour", type: HSBonjourModule.self)}}
    @objc var camera: HSCameraModule { get { getOrCreate(name: "camera", type: HSCameraModule.self)}}
    @objc var console: HSConsoleModule { get { getOrCreate(name: "console", type: HSConsoleModule.self)}}
    @objc var crypto: HSCryptoModule { get { getOrCreate(name: "crypto", type: HSCryptoModule.self)}}
    @objc var eventtap: HSEventTapModule { get { getOrCreate(name: "eventtap", type: HSEventTapModule.self)}}
    @objc var fs: HSFSModule { get { getOrCreate(name: "fs", type: HSFSModule.self)}}
    @objc var hashing: HSHashModule { get { getOrCreate(name: "hashing", type: HSHashModule.self)}}
    @objc var hotkey: HSHotkeyModule { get { getOrCreate(name: "hotkey", type: HSHotkeyModule.self)}}
    @objc var httpserver: HSHttpServerModule { get { getOrCreate(name: "httpserver", type: HSHttpServerModule.self)}}
    @objc var keychain: HSKeychainModule { get { getOrCreate(name: "keychain", type: HSKeychainModule.self)}}
    @objc var location: HSLocationModule { get { getOrCreate(name: "location", type: HSLocationModule.self)}}
    @objc var menubar: HSMenubarModule { get { getOrCreate(name: "menubar", type: HSMenubarModule.self)}}
    @objc var mouse: HSMouseModule { get { getOrCreate(name: "mouse", type: HSMouseModule.self)}}
    @objc var multipeer: HSMultipeerModule { get { getOrCreate(name: "multipeer", type: HSMultipeerModule.self)}}
    @objc var notify: HSNotifyModule { get { getOrCreate(name: "notify", type: HSNotifyModule.self)}}
    @objc var permissions: HSPermissionsModule { get { getOrCreate(name: "permissions", type: HSPermissionsModule.self)}}
    @objc var osascript: HSOSAScriptModule { get { getOrCreate(name: "osascript", type: HSOSAScriptModule.self)}}
    @objc var pasteboard: HSPasteboardModule { get { getOrCreate(name: "pasteboard", type: HSPasteboardModule.self)}}
    @objc var screen: HSScreenModule { get { getOrCreate(name: "screen", type: HSScreenModule.self)}}
    @objc var serial: HSSerialModule { get { getOrCreate(name: "serial", type: HSSerialModule.self)}}
    @objc var sqlite: HSSqliteModule { get { getOrCreate(name: "sqlite", type: HSSqliteModule.self)}}
    @objc var switcher: HSSwitcherModule { get { getOrCreate(name: "switcher", type: HSSwitcherModule.self)}}
    @objc var task: HSTaskModule { get { getOrCreate(name: "task", type: HSTaskModule.self)}}
    @objc var power: HSPowerModule { get { getOrCreate(name: "power", type: HSPowerModule.self)}}
    @objc var text: HSTextModule { get { getOrCreate(name: "text", type: HSTextModule.self)}}
    @objc var timer: HSTimerModule { get { getOrCreate(name: "timer", type: HSTimerModule.self)}}
    @objc var ui: HSUIModule { get { getOrCreate(name: "ui", type: HSUIModule.self)}}
    @objc var webview: HSWebviewModule { get { getOrCreate(name: "webview", type: HSWebviewModule.self)}}
    @objc var window: HSWindowModule { get { getOrCreate(name: "window", type: HSWindowModule.self)}}
}

// MARK: - JSContextInstallable

struct ModuleRootInstaller: JSContextInstallable {
    let engineID: UUID

    func install(in context: JSContext) throws {
        context.setObject(ModuleRoot(engineID: engineID), forKeyedSubscript: "hs" as NSString)
    }
}
