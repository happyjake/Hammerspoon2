//
//  HammerCore.swift
//  Hammerspoon 2 Demo
//
//  Created by Chris Jones on 23/09/2025.
//

import Foundation
import JavaScriptCore
import JavaScriptCoreExtras

// MARK: - JSContext lifetime diagnostics

private var contextTrackerKey: UInt8 = 0

private final class ContextLifetimeTracker {
    let id: UUID
    init(id: UUID) { self.id = id }
    isolated deinit { AKDebug("JSContext freed: \(id)") }
}

// MARK: -

@_documentation(visibility: private)
class JSEngine {
    static let shared = JSEngine()

    private(set) var id = UUID()
    private var vm: JSVirtualMachine?
    private var context: JSContext?

    // MARK: - JSContext Managing
    private func createContext() throws(HammerspoonError) {
        id = UUID()
        AKTrace("Creating JavaScript context: \(id)")
        vm = JSVirtualMachine()
        guard vm != nil else {
            throw HammerspoonError(.vmCreation, msg: "Unknown error (vm)")
        }

        context = JSContext(virtualMachine: vm)
        guard let context else {
            throw HammerspoonError(.vmCreation, msg: "Unknown error (context)")
        }

        context.name = "Hammerspoon \(id)"

        // Attach a sentinel so we can observe exactly when this JSContext's ARC drops to 0.
        unsafe objc_setAssociatedObject(context, &contextTrackerKey, ContextLifetimeTracker(id: id), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // Format any uncaught JS exception with name/message/sourceURL:line:col
        // + full JS stack; clear it so the engine state stays clean for the
        // next call. callSafely covers the common Swift→JS paths with their
        // caller-site tag; this handler is the catch-all for re-entrant or
        // pure-JS throws that don't pass through a callSafely site. JSC fires
        // the handler on the JSContext's owning thread (main in HS2), so the
        // MainActor.assumeIsolated assertion is honest.
        context.exceptionHandler = { ctx, exception in
            guard let exception else { return }
            let message = "JSException: " + formatJSException(exception)
            ctx?.exception = nil
            MainActor.assumeIsolated { AKError(message) }
        }

        // This is our startup sequence - install all components in order
        do {
            try context.install([
                ConsoleModuleInstaller(),      // console namespace
                RequireInstaller(),            // require() function
                TypeBridgesInstaller(),        // HSPoint, HSSize, HSRect, HSFont, HSAlert
                .bundled(path: "engine.js", in: .main),  // EventEmitter class
                ModuleRootInstaller(engineID: id),  // hs namespace
            ])
        } catch {
            throw HammerspoonError(.vmCreation, msg: "Failed to install context components: \(error.localizedDescription)")
        }
    }

    private func deleteContext() {
        AKTrace("Destroying JavaScript context: \(id)")

        SettingsManager.shared.removeAllDelegates()

        if let hs = self["hs"] as? JSValue, let moduleRoot = hs.toObjectOf(ModuleRoot.self) as? ModuleRoot {
            moduleRoot.shutdown()
            self["hs"] = nil
        }

        // ConsoleModule has no shutdown() so we can just nil it out
        self["console"] = nil

        // require() isn't even an object, so we can just nil it out
        self["require"] = nil

        if let context = context {
            // Remove global properties from the lexical environment.
            context.globalObject.deleteProperty("hs")
            context.globalObject.deleteProperty("console")
            context.globalObject.deleteProperty("require")
            context.globalObject.deleteProperty(CommonJSLoader.cacheGlobalName)

            // Force a synchronous full GC cycle (mark → sweep → finalize) before
            // tearing down the VM. JSC's concurrent GC defers ObjC bridge finalizers
            // (CFRelease) to a background sweep thread; if VM teardown races with that
            // thread, the finalizer never runs and Swift objects leak permanently.
            // After shutdown() above, all managed references are removed and all JS
            // variables referencing module proxies are cleared, so every proxy is
            // now GC-unreachable. The synchronous GC collects them and calls each
            // proxy's destructor (CFRelease) before this line returns.
            // Do NOT use JSGarbageCollect here — it schedules an asynchronous
            // collection and returns immediately, re-introducing the same race.
            unsafe JSSynchronousGarbageCollectForDebugging(context.jsGlobalContextRef)
        }

        context = nil
        vm = nil
    }
}

// MARK: - JSEngineProtocol Conformance
extension JSEngine: JSEngineProtocol {
    subscript(key: String) -> Any? {
        get {
            AKDebug("JSEngine subscript get for: \(key)")
            return context?.objectForKeyedSubscript(key as (NSCopying & NSObjectProtocol))
        }
        set {
            AKDebug("JSEngine subscript set for: \(key)")
            context?.setObject(newValue, forKeyedSubscript: key as (NSCopying & NSObjectProtocol))
        }
    }

    @discardableResult func eval(_ script: String) -> Any? {
        return context?.evaluateScript(script)?.toObject()
    }

    @discardableResult func evalFromURL(_ url: URL, wrapInIIFE: Bool = false) throws -> Any? {
        guard url.isFileURL else {
            throw HammerspoonError(.jsEvalURLKind, msg: "Refusing to eval remote URL")
        }

        // Resolve symlinks so __dirname points at the real file's dir, not the
        // symlink location. This matters for ~/.config/Hammerspoon2/init.js when
        // it's a symlink into a user's separate source repo.
        let canonical = url.resolvingSymlinksInPath()
        let canonicalPath = canonical.path
        let escapedPath = canonicalPath
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")

        // Verify the canonical file actually exists (resolvingSymlinksInPath can
        // produce paths that don't, e.g. if the symlink is dangling).
        guard FileManager.default.fileExists(atPath: canonicalPath) else {
            throw HammerspoonError(.jsEvalURLKind, msg: "User script not found at \(canonicalPath)")
        }

        // Load via the CommonJS shim so init.js gets __dirname/__filename and can
        // require sibling files relatively (e.g. require('./lib/log')).
        // The CJS wrapper already function-scopes top-level `const`/`let`
        // bindings, which is the guarantee callers request via `wrapInIIFE`
        // (keeps hs.* proxies collectable instead of pinned as global GC
        // roots), so no additional IIFE wrapping is needed on this path.
        // Flush any cached entry first so a reload re-evaluates the file.
        _ = context?.evaluateScript("delete require.cache['\(escapedPath)']")
        let result = context?.evaluateScript("require('\(escapedPath)')")
        return result?.toObject()
    }

    func resetContext() throws {
        if hasContext() {
            AKDebug("resetContext()")
            deleteContext()
        }
        try createContext()
    }

    func hasContext() -> Bool {
        return vm != nil || context != nil
    }

    func shutdown() {
        deleteContext()
    }

    /// Creates a Promise that wraps an async operation
    /// - Parameter body: A closure that receives a JSPromiseHolder to resolve/reject the promise
    /// - Returns: A JSPromise representing the Promise, or nil if context is unavailable
    @MainActor
    func createPromise(body: @escaping @MainActor (JSPromiseHolder) -> Void) -> JSPromise? {
        guard let context = context else {
            AKError("JSEngine.createPromise: No context available")
            return nil
        }
        return wrapAsyncInJSPromise(in: context, body: body)
    }

    /// Creates a Promise that resolves immediately with the given value
    /// - Parameter value: The value to resolve with
    /// - Returns: A JSPromise representing the resolved Promise
    func createResolvedPromise(with value: Any?) -> JSPromise? {
        return context?.createResolvedPromise(with: value)
    }

    /// Creates a Promise that rejects immediately with the given error
    /// - Parameter error: The error message
    /// - Returns: A JSPromise representing the rejected Promise
    func createRejectedPromise(with error: String) -> JSPromise? {
        return context?.createRejectedPromise(with: error)
    }
}

// MARK: - JSContextInstallable Implementations

struct RequireInstaller: JSContextInstallable {
    func install(in context: JSContext) throws {
        // Use a class to hold shared mutable state and enable recursive calls
        // without the Swift recursive-closure-capture limitation.
        //
        // Lifetime: the require function's block captures the loader STRONGLY,
        // so the loader lives exactly as long as the require function — a JS-
        // heap object that dies with the context. Do NOT anchor the loader to
        // the context with objc_setAssociatedObject: combined with the loader's
        // (former) strong context/cache ivars that made an ObjC retain cycle
        // (context → loader → context) which leaked every JSContext across
        // reloads — see testContextDeallocatesAfterRelease.
        let loader = CommonJSLoader(context: context)
        guard let requireFn = loader.makeRequire(parentDirname: nil) else {
            throw HammerspoonError(.vmCreation, msg: "RequireInstaller: failed to create require()")
        }
        context.setObject(requireFn, forKeyedSubscript: "require" as NSString)
    }
}

/// Implements Node-style CommonJS module loading for a single JSContext.
///
/// Each module is wrapped in a function that receives `exports`, `module`,
/// `require`, `__filename`, and `__dirname` as arguments, mirroring Node.js.
/// Modules are cached by absolute path; the cache is JS-accessible via
/// `require.cache`. Files that never assign `module.exports` return the
/// initial empty `{}` object.
private final class CommonJSLoader {
    // Weak: the loader is owned (via the require function's block capture) by
    // the context's own JS heap. A strong ref here — or a stored JSValue,
    // which retains its context internally — would cycle the context back to
    // itself and leak it on every reload.
    private weak var context: JSContext?

    /// Hidden global that roots the module cache ({ [absPath]: moduleObject })
    /// in the JS heap, so Swift never holds it strongly. Non-enumerable to keep
    /// globalThis tidy; configurable so deleteContext() can remove it. The same
    /// object is exposed to users as `require.cache`.
    static let cacheGlobalName = "__hsRequireCache__"

    init(context: JSContext) {
        self.context = context
        context.evaluateScript(
            "Object.defineProperty(globalThis, '\(Self.cacheGlobalName)', { value: {}, enumerable: false, writable: false, configurable: true })"
        )
    }

    /// The module cache, fetched from its JS-heap root. Nil once the context
    /// is torn down (or after deleteContext removed the global).
    private var cache: JSValue? {
        guard let cache = context?.globalObject.objectForKeyedSubscript(Self.cacheGlobalName),
              !cache.isUndefined, !cache.isNull else { return nil }
        return cache
    }

    // MARK: - Path resolution

    /// Resolves a raw require() argument to a candidate absolute path.
    /// Returns nil and logs if the path cannot be resolved.
    func resolvePath(_ raw: String, parentDirname: String?) -> String? {
        if raw.hasPrefix("/") {
            return raw
        }
        if raw.hasPrefix("~") {
            return NSString(string: raw).expandingTildeInPath as String
        }
        if raw.hasPrefix("./") || raw.hasPrefix("../") {
            guard let parent = parentDirname else {
                AKError("require(): relative path '\(raw)' used with no parent __dirname")
                return nil
            }
            let joined = (parent as NSString).appendingPathComponent(raw)
            return (joined as NSString).standardizingPath as String
        }
        AKError("require(): bare name '\(raw)' is not supported; use ./, ../, ~, or an absolute path")
        return nil
    }

    /// Applies extension probing: tries the path as-is, then appends .js, .json,
    /// and /index.js in order.
    func resolveWithExtensions(_ candidate: String) -> String? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        // Accept the bare path only if it's a regular file. Directories must
        // resolve via the /index.js extension probe; otherwise we'd return a
        // directory path that the loader can't read.
        if fm.fileExists(atPath: candidate, isDirectory: &isDir) && !isDir.boolValue {
            return candidate
        }
        for ext in [".js", ".json", "/index.js"] {
            let probe = candidate + ext
            var probeIsDir: ObjCBool = false
            if fm.fileExists(atPath: probe, isDirectory: &probeIsDir) && !probeIsDir.boolValue {
                return probe
            }
        }
        return nil
    }

    // MARK: - Require factory

    /// Returns a JS `require` function whose relative-path resolution is
    /// anchored at `parentDirname`.  Attach `.cache` and `.resolve` to it.
    func makeRequire(parentDirname: String?) -> JSValue? {
        guard let context else { return nil }
        // Capture `self` (the loader) STRONGLY: the block — and through it the
        // loader — is owned by the require function object in the JS heap, so
        // both die with the context. (The loader's back-reference to the
        // context is weak, so this ownership is acyclic.)
        let block: @convention(block) (String) -> JSValue? = { rawPath in
            self.loadModule(rawPath: rawPath, parentDirname: parentDirname)
        }
        let jsRequire = JSValue(object: block, in: context)!

        // Attach `.cache` — same object as what every child require sees.
        jsRequire.setObject(cache, forKeyedSubscript: "cache" as NSString)

        // Attach `.resolve` — returns the resolved absolute path without loading.
        let resolveBlock: @convention(block) (String) -> String? = { rawPath in
            guard let candidate = self.resolvePath(rawPath, parentDirname: parentDirname),
                  let abs = self.resolveWithExtensions(candidate)
            else { return nil }
            return abs
        }
        jsRequire.setObject(resolveBlock, forKeyedSubscript: "resolve" as NSString)

        return jsRequire
    }

    // MARK: - Module loading

    /// Core loading logic; shared by all `require` closures regardless of parent.
    func loadModule(rawPath: String, parentDirname: String?) -> JSValue? {
        // Torn-down context (or deleted cache global): require becomes a no-op.
        guard let context, let cache else { return nil }

        // 1. Resolve path to an absolute filesystem path.
        guard let candidate = resolvePath(rawPath, parentDirname: parentDirname),
              let absPath = resolveWithExtensions(candidate)
        else {
            AKError("require(): cannot resolve '\(rawPath)'")
            return nil
        }

        // 2. Cache hit — return cached exports without re-executing the file.
        let cachedModule = cache.objectForKeyedSubscript(absPath)
        if let cachedModule, !cachedModule.isUndefined, !cachedModule.isNull {
            return cachedModule.objectForKeyedSubscript("exports")
        }

        // 3. Read source.
        guard let source = try? String(contentsOfFile: absPath, encoding: .utf8) else {
            AKError("require(): cannot read '\(absPath)'")
            return nil
        }

        // 4. JSON files: parse and cache directly.
        if absPath.hasSuffix(".json") {
            let parsed = context.evaluateScript("(\(source))")
            let moduleObj = JSValue(newObjectIn: context)!
            moduleObj.setObject(parsed, forKeyedSubscript: "exports" as NSString)
            cache.setObject(moduleObj, forKeyedSubscript: absPath as NSString)
            return parsed
        }

        // 5. Build the CommonJS module object and populate the cache *before*
        //    executing the file, so circular requires don't loop infinitely.
        let dirname = (absPath as NSString).deletingLastPathComponent as String
        let moduleObj = JSValue(newObjectIn: context)!
        let initialExports = JSValue(newObjectIn: context)!
        moduleObj.setObject(initialExports, forKeyedSubscript: "exports" as NSString)
        moduleObj.setObject(absPath, forKeyedSubscript: "filename" as NSString)
        moduleObj.setObject(dirname, forKeyedSubscript: "dirname" as NSString)
        cache.setObject(moduleObj, forKeyedSubscript: absPath as NSString)

        // 6. Build a child require that knows this file's dirname.
        guard let childRequire = makeRequire(parentDirname: dirname) else { return nil }

        // 7. Wrap source in the CJS function and compile it.
        //    We use a JS-level string escape via the URL source map name only;
        //    single-quotes in the path are not safe to embed in JS source.
        //    So we pass __filename and __dirname as arguments, not interpolated strings.
        let fileURL = URL(fileURLWithPath: absPath)
        let wrapper = "(function(exports, module, require, __filename, __dirname) {\n\(source)\n})"
        guard let fn = context.evaluateScript(wrapper, withSourceURL: fileURL),
              !fn.isUndefined, !fn.isNull
        else {
            AKError("require(): failed to compile '\(absPath)'")
            // Remove from cache so a retry can work.
            cache.setObject(JSValue(undefinedIn: context), forKeyedSubscript: absPath as NSString)
            return nil
        }

        // 8. Execute the wrapper with the CommonJS arguments.
        fn.call(withArguments: [
            initialExports,
            moduleObj,
            childRequire,
            absPath,
            dirname,
        ])

        // 9. Read final exports (may have been replaced by `module.exports = ...`).
        //    Files that never assign module.exports get back the initial empty {}.
        //    Files run for side effects (e.g. hs.*.js enhancement files) discard
        //    the return value anyway, so this is safe for all callers.
        return moduleObj.objectForKeyedSubscript("exports")!
    }
}

