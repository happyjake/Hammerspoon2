//
//  RequireInstallerTests.swift
//  Hammerspoon 2Tests
//

import Testing
import JavaScriptCore
import JavaScriptCoreExtras
@testable import Hammerspoon_2

/// Integration tests for the CommonJS require() shim installed by RequireInstaller.
///
/// Each test creates its own JSContext via JSTestHarness and installs
/// RequireInstaller directly. Temp files are written to unique directories so
/// tests can run concurrently without interference.
@Suite(.serialized)
struct RequireInstallerTests {

    // MARK: - Helpers

    /// Write a JS file into a unique temp directory and return its absolute path.
    private func tmpJs(_ name: String, _ content: String) -> String {
        let dir = NSTemporaryDirectory() + "hs2-require-tests-\(UUID().uuidString)/"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let path = dir + name
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    /// Build a fresh JSContext with RequireInstaller applied.
    ///
    /// Returns a `(context, eval)` pair where `eval` evaluates JS and returns the
    /// result as an `Any?` (same semantics as `JSTestHarness.eval`).
    private func makeContext() -> (JSContext, (String) -> Any?) {
        let vm = JSVirtualMachine()!
        let ctx = JSContext(virtualMachine: vm)!
        ctx.exceptionHandler = { _, ex in
            print("❌ JS Exception: \(ex?.toString() ?? "unknown")")
        }
        // Install the require shim (throws iff something is structurally wrong).
        try? RequireInstaller().install(in: ctx)
        let eval: (String) -> Any? = { script in
            ctx.evaluateScript(script)?.toObject()
        }
        return (ctx, eval)
    }

    // MARK: - Tests

    @Test("module.exports = object works")
    func testModuleExportsObject() {
        let (_, eval) = makeContext()
        let path = tmpJs("a.js", "module.exports = { x: 42, double: (n) => n * 2 }")
        #expect(eval("require('\(path)').x") as? Int == 42)
        #expect(eval("require('\(path)').double(21)") as? Int == 42)
    }

    @Test("require caches by absolute path")
    func testRequireCaches() {
        let (_, eval) = makeContext()
        let path = tmpJs("counter.js", """
            const state = { count: 0 }
            state.count++
            module.exports = state
        """)
        #expect(eval("require('\(path)').count") as? Int == 1)
        #expect(eval("require('\(path)').count") as? Int == 1)  // cache hit; not re-executed
    }

    @Test("delete require.cache[path] reloads")
    func testCacheDeleteReloads() {
        let (_, eval) = makeContext()
        let path = tmpJs("counter2.js", """
            const state = { count: 0 }
            state.count++
            module.exports = state
        """)
        #expect(eval("require('\(path)').count") as? Int == 1)
        _ = eval("delete require.cache['\(path)']")
        #expect(eval("require('\(path)').count") as? Int == 1)  // fresh re-eval → 1 again
    }

    @Test("__dirname and __filename are injected")
    func testDirnameFilename() {
        let (_, eval) = makeContext()
        let path = tmpJs("dirinfo.js", "module.exports = { dir: __dirname, file: __filename }")
        let expectedDir = (path as NSString).deletingLastPathComponent as String
        #expect(eval("require('\(path)').file") as? String == path)
        #expect(eval("require('\(path)').dir") as? String == expectedDir)
    }

    @Test("relative require resolves against parent __dirname")
    func testRelativeRequire() {
        let dir = NSTemporaryDirectory() + "hs2-require-rel-\(UUID().uuidString)/"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? "module.exports = 'I am b'".write(toFile: dir + "b.js", atomically: true, encoding: .utf8)
        try? "module.exports = require('./b')".write(toFile: dir + "a.js", atomically: true, encoding: .utf8)
        let (_, eval) = makeContext()
        #expect(eval("require('\(dir + "a.js")')") as? String == "I am b")
    }

    @Test("require.resolve returns absolute path without loading")
    func testResolve() {
        let (_, eval) = makeContext()
        let path = tmpJs("resolve.js", "module.exports = 'ok'")
        #expect(eval("require.resolve('\(path)')") as? String == path)
    }

    @Test("file without module.exports returns last expression (legacy mode)")
    func testLegacyReturn() {
        let (_, eval) = makeContext()
        let path = tmpJs("legacy.js", "42")
        let result = eval("require('\(path)')")
        #expect(result as? Int == 42)
    }
}
