//
//  JSBridge.swift
//  Hammerspoon 2
//

import Foundation
import JavaScriptCore
import JavaScriptCoreExtras

/// Shared JavaScript→Swift boundary conversion helpers for module APIs.
///
/// `@objc` methods exported via `JSExport` that declare typed Swift collections
/// (`[String]`, `[String: String]`, `[String: Double]`, `[String: Any]`,
/// `[[String: Any]]`) receive an unconditional Objective-C bridge thunk from
/// the Swift compiler (`Array._unconditionallyBridgeFromObjectiveC` /
/// `Dictionary._unconditionallyBridgeFromObjectiveC`). If JavaScript passes a
/// value of the wrong type (e.g. a callback function where an argument array is
/// expected, or a non-string inside `[String]`), the runtime traps with
/// `swift_dynamicCastFailure` (SIGABRT) and takes down the entire application.
///
/// Module methods that accept collections from JavaScript should instead declare
/// those parameters as `JSValue` (or `JSValue?` for optional parameters) in their
/// `@objc protocol ... : JSExport` interface and convert them at the start of the
/// method using these helpers:
///
/// ```swift
/// guard let args = arguments.toStringArray(method: "hs.task.create", parameter: "arguments"),
///       let env = environment.toOptionalStringDictionary(method: "hs.task.create", parameter: "environment")
/// else {
///     return nil
/// }
/// ```
///
/// On any type mismatch, the helper sets a JavaScript `TypeError` on the active
/// `JSContext` naming both `method` and `parameter`, then returns `nil` so the
/// caller can bail out cleanly without side effects.
///
/// For optional collection parameters (`toOptional*`), JavaScript `null` and
/// `undefined` (or a `nil` `JSValue?`) are treated as an absent value and return
/// `.some(nil)` without setting an exception, whereas a present value of the
/// wrong type sets a `TypeError` and returns `.none` (`nil`).
extension JSContext {
    /// Sets a JavaScript `TypeError` with `message` as the pending exception on this context.
    nonisolated func throwTypeError(_ message: String) {
        if let existing = self.exception, !existing.isUndefined, !existing.isNull {
            return
        }
        if let ctor = self.objectForKeyedSubscript("TypeError"),
           !ctor.isUndefined,
           let err = ctor.construct(withArguments: [message]),
           !err.isUndefined {
            self.exception = err
        } else {
            self.exception = JSValue(newErrorFromMessage: "TypeError: \(message)", in: self)
        }
    }
}

extension JSValue {
    /// Maximum number of elements a bridged JavaScript array may contain.
    /// Prevents oversized or sparse arrays (e.g. `a.length = 2**31`) from wrapping
    /// `Int32` or stalling the main thread during element validation.
    nonisolated private static let maxBridgeArrayLength = 100_000

    /// Returns true if this value is a plain JavaScript object suitable for bridging
    /// to a Swift dictionary, without eagerly converting its properties or invoking
    /// property getters. Rejects primitives, null, undefined, arrays, functions,
    /// dates, boxed primitives, built-in non-plain objects (RegExp, Map, Set,
    /// Promise, Error, TypedArrays), and exported native Objective-C objects.
    nonisolated var isPlainJSObject: Bool {
        guard isObject,
              !isNull,
              !isUndefined,
              !isArray,
              !isFunction,
              !isDate,
              !isString,
              !isNumber,
              !isBoolean
        else {
            return false
        }
        guard let context,
              let tag = context.objectForKeyedSubscript("Object")?
                  .forProperty("prototype")?
                  .forProperty("toString")?
                  .invokeMethod("call", withArguments: [self])?
                  .toString()
        else {
            return false
        }
        if let exc = context.exception, !exc.isUndefined, !exc.isNull {
            return false
        }
        return tag == "[object Object]"
    }

    /// Converts this `JSValue` to `[String]`, or sets a JS `TypeError` and returns `nil`.
    nonisolated func toStringArray(method: String, parameter: String) -> [String]? {
        let ctx = self.context ?? JSContext.current()
        guard !isUndefined, !isNull, isArray else {
            ctx?.throwTypeError("\(method): parameter '\(parameter)' must be an array of strings")
            return nil
        }

        guard let length = validatedArrayLength(
            method: method,
            parameter: parameter,
            expectedDescription: "array of strings",
            in: ctx
        ) else {
            return nil
        }

        var result: [String] = []
        result.reserveCapacity(length)

        for index in 0..<length {
            let element = atIndex(index)
            if let exc = ctx?.exception, !exc.isUndefined, !exc.isNull {
                return nil
            }
            guard let element,
                  !element.isUndefined,
                  !element.isNull,
                  element.isString,
                  let str = element.toString()
            else {
                ctx?.throwTypeError(
                    "\(method): parameter '\(parameter)' must be an array of strings (element at index \(index) is not a string)"
                )
                return nil
            }
            result.append(str)
        }

        return result
    }

    /// Converts an optional `JSValue` to `[String]?`.
    /// Returns `.some(nil)` when `null` or `undefined`, `.some(array)` when valid,
    /// or `.none` after setting a JS `TypeError` when invalid.
    nonisolated func toOptionalStringArray(method: String, parameter: String) -> [String]?? {
        if isUndefined || isNull {
            return .some(nil)
        }
        guard let array = toStringArray(method: method, parameter: parameter) else {
            return .none
        }
        return .some(array)
    }

    /// Converts this `JSValue` to `[String: String]`, or sets a JS `TypeError` and returns `nil`.
    nonisolated func toStringDictionary(method: String, parameter: String) -> [String: String]? {
        let ctx = self.context ?? JSContext.current()
        guard isPlainJSObject,
              let keys = enumerableKeys()
        else {
            ctx?.throwTypeError("\(method): parameter '\(parameter)' must be an object mapping strings to strings")
            return nil
        }

        var result: [String: String] = [:]
        result.reserveCapacity(keys.count)

        for key in keys {
            let propValue = objectForKeyedSubscript(key)
            if let exc = ctx?.exception, !exc.isUndefined, !exc.isNull {
                return nil
            }
            guard let propValue,
                  !propValue.isUndefined,
                  !propValue.isNull,
                  propValue.isString,
                  let str = propValue.toString()
            else {
                ctx?.throwTypeError(
                    "\(method): parameter '\(parameter)' must have string values (key '\(key)' is not a string)"
                )
                return nil
            }
            result[key] = str
        }

        return result
    }

    /// Converts an optional `JSValue` to `[String: String]?`.
    /// Returns `.some(nil)` when `null` or `undefined`, `.some(dict)` when valid,
    /// or `.none` after setting a JS `TypeError` when invalid.
    nonisolated func toOptionalStringDictionary(method: String, parameter: String) -> [String: String]?? {
        if isUndefined || isNull {
            return .some(nil)
        }
        guard let dict = toStringDictionary(method: method, parameter: parameter) else {
            return .none
        }
        return .some(dict)
    }

    /// Converts this `JSValue` to `[String: Double]`, or sets a JS `TypeError` and returns `nil`.
    nonisolated func toDoubleDictionary(method: String, parameter: String) -> [String: Double]? {
        let ctx = self.context ?? JSContext.current()
        guard isPlainJSObject,
              let keys = enumerableKeys()
        else {
            ctx?.throwTypeError("\(method): parameter '\(parameter)' must be an object mapping strings to numbers")
            return nil
        }

        var result: [String: Double] = [:]
        result.reserveCapacity(keys.count)

        for key in keys {
            let propValue = objectForKeyedSubscript(key)
            if let exc = ctx?.exception, !exc.isUndefined, !exc.isNull {
                return nil
            }
            guard let propValue,
                  !propValue.isUndefined,
                  !propValue.isNull,
                  propValue.isNumber,
                  !propValue.isBoolean
            else {
                ctx?.throwTypeError(
                    "\(method): parameter '\(parameter)' must have numeric values (key '\(key)' is not a number)"
                )
                return nil
            }
            result[key] = propValue.toDouble()
        }

        return result
    }

    /// Converts an optional `JSValue` to `[String: Double]?`.
    /// Returns `.some(nil)` when `null` or `undefined`, `.some(dict)` when valid,
    /// or `.none` after setting a JS `TypeError` when invalid.
    nonisolated func toOptionalDoubleDictionary(method: String, parameter: String) -> [String: Double]?? {
        if isUndefined || isNull {
            return .some(nil)
        }
        guard let dict = toDoubleDictionary(method: method, parameter: parameter) else {
            return .none
        }
        return .some(dict)
    }

    /// Converts this `JSValue` to `[String: Any]`, or sets a JS `TypeError` and returns `nil`.
    nonisolated func toObjectDictionary(method: String, parameter: String) -> [String: Any]? {
        let ctx = self.context ?? JSContext.current()
        guard isPlainJSObject,
              let keys = enumerableKeys()
        else {
            ctx?.throwTypeError("\(method): parameter '\(parameter)' must be a plain object")
            return nil
        }

        var result: [String: Any] = [:]
        result.reserveCapacity(keys.count)

        for key in keys {
            let propValue = objectForKeyedSubscript(key)
            if let exc = ctx?.exception, !exc.isUndefined, !exc.isNull {
                return nil
            }
            guard let propValue, !propValue.isUndefined else {
                continue
            }
            if propValue.isNull {
                result[key] = NSNull()
            } else if let converted = propValue.toObject() {
                result[key] = converted
            }
        }

        return result
    }

    /// Converts an optional `JSValue` to `[String: Any]?`.
    /// Returns `.some(nil)` when `null` or `undefined`, `.some(dict)` when valid,
    /// or `.none` after setting a JS `TypeError` when invalid.
    nonisolated func toOptionalObjectDictionary(method: String, parameter: String) -> [String: Any]?? {
        if isUndefined || isNull {
            return .some(nil)
        }
        guard let dict = toObjectDictionary(method: method, parameter: parameter) else {
            return .none
        }
        return .some(dict)
    }

    /// Converts this `JSValue` to `[[String: Any]]`, or sets a JS `TypeError` and returns `nil`.
    nonisolated func toObjectDictionaryArray(method: String, parameter: String) -> [[String: Any]]? {
        let ctx = self.context ?? JSContext.current()
        guard !isUndefined, !isNull, isArray else {
            ctx?.throwTypeError("\(method): parameter '\(parameter)' must be an array of plain objects")
            return nil
        }

        guard let length = validatedArrayLength(
            method: method,
            parameter: parameter,
            expectedDescription: "array of plain objects",
            in: ctx
        ) else {
            return nil
        }

        var result: [[String: Any]] = []
        result.reserveCapacity(length)

        for index in 0..<length {
            let element = atIndex(index)
            if let exc = ctx?.exception, !exc.isUndefined, !exc.isNull {
                return nil
            }
            guard let element,
                  let dict = element.toObjectDictionary(
                      method: method,
                      parameter: "\(parameter)[\(index)]"
                  )
            else {
                return nil
            }
            result.append(dict)
        }

        return result
    }

    /// Converts an optional `JSValue` to `[[String: Any]]?`.
    /// Returns `.some(nil)` when `null` or `undefined`, `.some(array)` when valid,
    /// or `.none` after setting a JS `TypeError` when invalid.
    nonisolated func toOptionalObjectDictionaryArray(method: String, parameter: String) -> [[String: Any]]?? {
        if isUndefined || isNull {
            return .some(nil)
        }
        guard let array = toObjectDictionaryArray(method: method, parameter: parameter) else {
            return .none
        }
        return .some(array)
    }

    // MARK: - Private

    nonisolated private func validatedArrayLength(
        method: String,
        parameter: String,
        expectedDescription: String,
        in ctx: JSContext?
    ) -> Int? {
        guard let lengthValue = forProperty("length"),
              lengthValue.isNumber,
              !lengthValue.isBoolean
        else {
            ctx?.throwTypeError("\(method): parameter '\(parameter)' must be an \(expectedDescription)")
            return nil
        }
        let rawLength = lengthValue.toDouble()
        guard rawLength.isFinite,
              rawLength >= 0,
              rawLength.rounded(.towardZero) == rawLength,
              rawLength <= Double(Self.maxBridgeArrayLength)
        else {
            ctx?.throwTypeError(
                "\(method): parameter '\(parameter)' must be an \(expectedDescription) (array length exceeds maximum supported limit of \(Self.maxBridgeArrayLength))"
            )
            return nil
        }
        return Int(rawLength)
    }

    /// Returns all own and inherited enumerable string property keys (`for...in`
    /// semantics, matching JavaScriptCore's native dictionary bridging) without
    /// invoking property getters.
    nonisolated private func enumerableKeys() -> [String]? {
        guard let context,
              let enumFn = context.evaluateScript(
                  "(function(obj) { var keys = []; for (var k in obj) { keys.push(k); } return keys; })"
              ),
              let keysVal = enumFn.call(withArguments: [self]),
              keysVal.isArray,
              let keys = keysVal.toArray() as? [String]
        else {
            return nil
        }
        if let exc = context.exception, !exc.isUndefined, !exc.isNull {
            return nil
        }
        return keys
    }
}

extension Optional where Wrapped == JSValue {
    nonisolated func toStringArray(method: String, parameter: String) -> [String]? {
        guard let value = self else {
            JSContext.current()?.throwTypeError("\(method): parameter '\(parameter)' must be an array of strings")
            return nil
        }
        return value.toStringArray(method: method, parameter: parameter)
    }

    nonisolated func toOptionalStringArray(method: String, parameter: String) -> [String]?? {
        guard let value = self else {
            return .some(nil)
        }
        return value.toOptionalStringArray(method: method, parameter: parameter)
    }

    nonisolated func toStringDictionary(method: String, parameter: String) -> [String: String]? {
        guard let value = self else {
            JSContext.current()?.throwTypeError("\(method): parameter '\(parameter)' must be an object mapping strings to strings")
            return nil
        }
        return value.toStringDictionary(method: method, parameter: parameter)
    }

    nonisolated func toOptionalStringDictionary(method: String, parameter: String) -> [String: String]?? {
        guard let value = self else {
            return .some(nil)
        }
        return value.toOptionalStringDictionary(method: method, parameter: parameter)
    }

    nonisolated func toDoubleDictionary(method: String, parameter: String) -> [String: Double]? {
        guard let value = self else {
            JSContext.current()?.throwTypeError("\(method): parameter '\(parameter)' must be an object mapping strings to numbers")
            return nil
        }
        return value.toDoubleDictionary(method: method, parameter: parameter)
    }

    nonisolated func toOptionalDoubleDictionary(method: String, parameter: String) -> [String: Double]?? {
        guard let value = self else {
            return .some(nil)
        }
        return value.toOptionalDoubleDictionary(method: method, parameter: parameter)
    }

    nonisolated func toObjectDictionary(method: String, parameter: String) -> [String: Any]? {
        guard let value = self else {
            JSContext.current()?.throwTypeError("\(method): parameter '\(parameter)' must be a plain object")
            return nil
        }
        return value.toObjectDictionary(method: method, parameter: parameter)
    }

    nonisolated func toOptionalObjectDictionary(method: String, parameter: String) -> [String: Any]?? {
        guard let value = self else {
            return .some(nil)
        }
        return value.toOptionalObjectDictionary(method: method, parameter: parameter)
    }

    nonisolated func toObjectDictionaryArray(method: String, parameter: String) -> [[String: Any]]? {
        guard let value = self else {
            JSContext.current()?.throwTypeError("\(method): parameter '\(parameter)' must be an array of plain objects")
            return nil
        }
        return value.toObjectDictionaryArray(method: method, parameter: parameter)
    }

    nonisolated func toOptionalObjectDictionaryArray(method: String, parameter: String) -> [[String: Any]]?? {
        guard let value = self else {
            return .some(nil)
        }
        return value.toOptionalObjectDictionaryArray(method: method, parameter: parameter)
    }
}
