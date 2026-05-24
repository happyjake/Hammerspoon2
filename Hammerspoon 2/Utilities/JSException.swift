//
//  JSException.swift
//  Hammerspoon 2
//
//  Framework-level JS exception capture:
//   - `formatJSException` renders a JSValue exception (name + message +
//     sourceURL:line:column + indented JS stack frames) into a single
//     human-readable string.
//   - `JSValue.callSafely(_:context:)` wraps every Swift→JS callback
//     invocation, traps any thrown JS exception, formats it tagged with the
//     Swift caller site (eventtap keyDown / hotkey / timer / ui onKey …),
//     and clears the engine exception slot so subsequent calls run clean.
//
//  Threading note: JSC is thread-affine — JS callbacks always fire on the
//  JSContext's owning thread (main in HS2). Both helpers are `nonisolated`
//  because:
//    1. The underlying `JSValue.call(withArguments:)` we wrap is *itself*
//       nonisolated (Apple ships it as an Obj-C method without isolation),
//       so callSafely just preserves that existing contract — it isn't
//       downgrading callers.
//    2. Several real call sites (NSEvent local monitor, NotificationCenter
//       observer, InteractiveModifiable click/hover callbacks, the JSC
//       exceptionHandler closure itself) are nonisolated closure types,
//       and non-Sendable `JSValue` cannot be carried across into a
//       `@MainActor` boundary from those without lying with
//       `@unchecked Sendable` boxes — we avoid that.
//    3. The only piece that genuinely needs MainActor isolation is the
//       AKError UI-log dispatch, and we hop into it via
//       `MainActor.assumeIsolated { AKError(message) }` while passing only
//       a Sendable `String` — no JSValue crosses any boundary.
//  At @MainActor callsites (HSEventTap.handle, HSHotkey.handle, HSTimer.fire,
//  …) calling a nonisolated method is a no-op semantically — the caller's
//  own isolation is unchanged.
//

import Foundation
import JavaScriptCore

/// Format a JS exception JSValue as a multi-line, human-readable string.
/// `context` is an optional Swift-side caller tag prepended in brackets.
@_documentation(visibility: private)
nonisolated func formatJSException(_ exc: JSValue, context: String? = nil) -> String {
    let name = (exc.objectForKeyedSubscript("name")?.toString())
        .flatMap { $0.isEmpty ? nil : $0 } ?? "Error"
    let message = (exc.objectForKeyedSubscript("message")?.toString())
        .flatMap { $0.isEmpty ? nil : $0 }
        ?? exc.toString()
        ?? "(no message)"

    var head = context.map { "[\($0)] " } ?? ""
    head += "\(name): \(message)"

    if let src = exc.objectForKeyedSubscript("sourceURL")?.toString(), !src.isEmpty {
        head += "\n    at \(src)"
        if let line = exc.objectForKeyedSubscript("line"), !line.isUndefined, !line.isNull {
            head += ":\(line.toInt32())"
            if let col = exc.objectForKeyedSubscript("column"), !col.isUndefined, !col.isNull {
                head += ":\(col.toInt32())"
            }
        }
    }

    if let stack = exc.objectForKeyedSubscript("stack")?.toString(), !stack.isEmpty {
        let frames = stack
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { "    \($0)" }
            .joined(separator: "\n")
        head += "\n\(frames)"
    }
    return head
}

extension JSValue {
    /// Invoke a JS function and trap any exception it raises.
    ///
    /// On throw: format the exception (incl. stack) tagged with `callerContext`,
    /// log via `AKError`, and clear `self.context.exception`. Returns the JS
    /// result on success, nil on throw.
    ///
    /// `nonisolated` matches the underlying `JSValue.call(withArguments:)`
    /// (an unisolated Obj-C method); see the file header for the rationale.
    /// The single MainActor hop is for the AKError UI-log path, which only
    /// captures a Sendable `String`.
    @discardableResult
    nonisolated func callSafely(withArguments args: [Any], context callerContext: String) -> JSValue? {
        let result = self.call(withArguments: args)
        if let ctx = self.context, let exc = ctx.exception, !exc.isUndefined {
            let message = "JSException: " + formatJSException(exc, context: callerContext)
            ctx.exception = nil
            MainActor.assumeIsolated { AKError(message) }
            return nil
        }
        return result
    }
}
