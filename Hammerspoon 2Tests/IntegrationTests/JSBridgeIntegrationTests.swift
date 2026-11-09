//
//  JSBridgeIntegrationTests.swift
//  Hammerspoon 2Tests
//

import Testing
import JavaScriptCore
@testable import Hammerspoon_2

@objc private protocol JSBridgeProbeAPI: JSExport {
    @objc func stringArray(_ value: JSValue) -> [String]?
    @objc func optionalStringArray(_ value: JSValue?) -> [String]?
    @objc func stringDictionary(_ value: JSValue) -> [String: String]?
    @objc func optionalStringDictionary(_ value: JSValue?) -> [String: String]?
    @objc func doubleDictionary(_ value: JSValue) -> [String: Double]?
    @objc func objectDictionary(_ value: JSValue) -> [String: Any]?
    @objc func optionalObjectDictionary(_ value: JSValue?) -> [String: Any]?
    @objc func objectDictionaryArray(_ value: JSValue) -> [[String: Any]]?
}

@objc private final class JSBridgeProbe: NSObject, JSBridgeProbeAPI {
    @objc func stringArray(_ value: JSValue) -> [String]? {
        value.toStringArray(method: "probe.stringArray", parameter: "items")
    }

    @objc func optionalStringArray(_ value: JSValue?) -> [String]? {
        guard let items = value.toOptionalStringArray(method: "probe.optionalStringArray", parameter: "items") else {
            return nil
        }
        return items ?? []
    }

    @objc func stringDictionary(_ value: JSValue) -> [String: String]? {
        value.toStringDictionary(method: "probe.stringDictionary", parameter: "env")
    }

    @objc func optionalStringDictionary(_ value: JSValue?) -> [String: String]? {
        guard let dict = value.toOptionalStringDictionary(method: "probe.optionalStringDictionary", parameter: "env") else {
            return nil
        }
        return dict ?? [:]
    }

    @objc func doubleDictionary(_ value: JSValue) -> [String: Double]? {
        value.toDoubleDictionary(method: "probe.doubleDictionary", parameter: "point")
    }

    @objc func objectDictionary(_ value: JSValue) -> [String: Any]? {
        value.toObjectDictionary(method: "probe.objectDictionary", parameter: "options")
    }

    @objc func optionalObjectDictionary(_ value: JSValue?) -> [String: Any]? {
        guard let dict = value.toOptionalObjectDictionary(method: "probe.optionalObjectDictionary", parameter: "options") else {
            return nil
        }
        return dict ?? [:]
    }

    @objc func objectDictionaryArray(_ value: JSValue) -> [[String: Any]]? {
        value.toObjectDictionaryArray(method: "probe.objectDictionaryArray", parameter: "descriptors")
    }
}

@Suite("JSBridge boundary conversion tests")
struct JSBridgeIntegrationTests {
    private func makeHarness() -> JSTestHarness {
        let harness = JSTestHarness()
        harness.context.setObject(JSBridgeProbe(), forKeyedSubscript: "probe" as NSString)
        return harness
    }

    @Test("toStringArray converts valid string arrays and rejects non-arrays or non-string elements")
    func testToStringArray() {
        let harness = makeHarness()

        harness.expectEqual("probe.stringArray(['a', 'b', '']).join(',')", "a,b,")
        harness.expectEqual("probe.stringArray([]).length", 0)
        #expect(!harness.hasException)

        harness.eval("""
        var bad = [null, undefined, 42, 'str', true, {}, function() {}, ['a', 1], ['a', null], ['a', undefined], ['a', {}]];
        var allTypeErrors = bad.every(function(v) {
            try {
                probe.stringArray(v);
                return false;
            } catch (e) {
                return (e instanceof TypeError) &&
                       e.message.includes('probe.stringArray') &&
                       e.message.includes('items');
            }
        });
        """)
        #expect(!harness.hasException)
        harness.expectTrue("allTypeErrors === true")
    }

    @Test("toOptionalStringArray accepts null and undefined and rejects invalid values")
    func testToOptionalStringArray() {
        let harness = makeHarness()

        harness.expectEqual("probe.optionalStringArray(null).length", 0)
        harness.expectEqual("probe.optionalStringArray(undefined).length", 0)
        harness.expectEqual("probe.optionalStringArray().length", 0)
        harness.expectEqual("probe.optionalStringArray(['x']).join(',')", "x")
        #expect(!harness.hasException)

        harness.eval("""
        var threw = false;
        try {
            probe.optionalStringArray([123]);
        } catch (e) {
            threw = (e instanceof TypeError) &&
                    e.message.includes('probe.optionalStringArray') &&
                    e.message.includes('items');
        }
        """)
        #expect(!harness.hasException)
        harness.expectTrue("threw === true")
    }

    @Test("toStringDictionary and toOptionalStringDictionary validate plain objects with string values")
    func testToStringDictionary() {
        let harness = makeHarness()

        harness.expectEqual("probe.stringDictionary({ A: '1', B: 'two' }).B", "two")
        harness.expectEqual("Object.keys(probe.optionalStringDictionary(null)).length", 0)
        harness.expectEqual("Object.keys(probe.optionalStringDictionary(undefined)).length", 0)
        #expect(!harness.hasException)

        harness.eval("""
        var bad = [
            null,
            undefined,
            ['a'],
            function() {},
            new Date(),
            /regex/,
            new Map(),
            new Set(),
            probe,
            'str',
            123,
            false,
            { A: 1 },
            { A: null },
            { A: undefined },
            { A: true },
            { A: [] },
            { A: {} },
            { A: function() {} }
        ];
        var allTypeErrors = bad.every(function(v) {
            try {
                probe.stringDictionary(v);
                return false;
            } catch (e) {
                return (e instanceof TypeError) &&
                       e.message.includes('probe.stringDictionary') &&
                       e.message.includes('env');
            }
        });
        """)
        #expect(!harness.hasException)
        harness.expectTrue("allTypeErrors === true")
    }

    @Test("toDoubleDictionary validates plain objects with numeric values, omits undefined values, and normalizes booleans")
    func testToDoubleDictionary() {
        let harness = makeHarness()

        harness.eval("""
        var valid = probe.doubleDictionary({
            x: 10.5,
            y: -2,
            altitude: undefined,
            flagTrue: true,
            flagFalse: false
        });
        """)
        #expect(!harness.hasException)
        harness.expectEqual("valid.x", 10.5)
        harness.expectEqual("valid.y", -2)
        harness.expectTrue("!('altitude' in valid)")
        harness.expectEqual("valid.flagTrue", 1)
        harness.expectEqual("valid.flagFalse", 0)

        harness.eval("""
        var bad = [
            null,
            undefined,
            [1, 2],
            function() {},
            '10',
            10,
            { x: '10', y: 20 },
            { x: null, y: 20 },
            { x: {}, y: 20 },
            { x: [], y: 20 },
            { x: function() {}, y: 20 }
        ];
        var allTypeErrors = bad.every(function(v) {
            try {
                probe.doubleDictionary(v);
                return false;
            } catch (e) {
                return (e instanceof TypeError) &&
                       e.message.includes('probe.doubleDictionary') &&
                       e.message.includes('point');
            }
        });
        """)
        #expect(!harness.hasException)
        harness.expectTrue("allTypeErrors === true")
    }

    @Test("toObjectDictionary and toOptionalObjectDictionary validate plain objects")
    func testToObjectDictionary() {
        let harness = makeHarness()

        harness.expectEqual("probe.objectDictionary({ title: 'hi', count: 3 }).title", "hi")
        harness.expectEqual("Object.keys(probe.optionalObjectDictionary(null)).length", 0)
        harness.expectEqual("Object.keys(probe.optionalObjectDictionary(undefined)).length", 0)
        #expect(!harness.hasException)

        harness.eval("""
        var bad = [null, undefined, [], ['a'], function() {}, new Date(), /re/, 'str', 42, true];
        var allTypeErrors = bad.every(function(v) {
            try {
                probe.objectDictionary(v);
                return false;
            } catch (e) {
                return (e instanceof TypeError) &&
                       e.message.includes('probe.objectDictionary') &&
                       e.message.includes('options');
            }
        });
        """)
        #expect(!harness.hasException)
        harness.expectTrue("allTypeErrors === true")
    }

    @Test("toObjectDictionaryArray validates arrays of plain objects")
    func testToObjectDictionaryArray() {
        let harness = makeHarness()

        harness.expectEqual("probe.objectDictionaryArray([{ key: 'k', ascending: true }]).length", 1)
        harness.expectEqual("probe.objectDictionaryArray([]).length", 0)
        #expect(!harness.hasException)

        harness.eval("""
        var bad = [
            null,
            undefined,
            {},
            function() {},
            'str',
            [null],
            [undefined],
            ['str'],
            [123],
            [[]],
            [function() {}],
            [{ ok: 1 }, 'not-an-object']
        ];
        var allTypeErrors = bad.every(function(v) {
            try {
                probe.objectDictionaryArray(v);
                return false;
            } catch (e) {
                return (e instanceof TypeError) &&
                       e.message.includes('probe.objectDictionaryArray') &&
                       e.message.includes('descriptors');
            }
        });
        """)
        #expect(!harness.hasException)
        harness.expectTrue("allTypeErrors === true")
    }

    @Test("dictionary helpers evaluate getters once and reject cyclic invalid objects without eager conversion")
    func testDictionarySingleGetterEvalAndCyclicRejection() {
        let harness = makeHarness()

        harness.eval("""
        let strCalls = 0;
        let numCalls = 0;
        let objCalls = 0;
        const strRes = probe.stringDictionary({ get FOO() { return String(++strCalls); } });
        const numRes = probe.doubleDictionary({ get x() { return ++numCalls; } });
        const objRes = probe.objectDictionary({ get k() { return ++objCalls; } });

        const cycStr = {};
        cycStr.SELF = cycStr;
        const cycNum = {};
        cycNum.SELF = cycNum;

        let strCycThrew = false;
        let numCycThrew = false;
        try {
            probe.stringDictionary(cycStr);
        } catch (e) {
            strCycThrew = (e instanceof TypeError) && e.message.includes('probe.stringDictionary');
        }
        try {
            probe.doubleDictionary(cycNum);
        } catch (e) {
            numCycThrew = (e instanceof TypeError) && e.message.includes('probe.doubleDictionary');
        }
        """)

        #expect(!harness.hasException)
        harness.expectEqual("strRes.FOO", "1")
        harness.expectEqual("strCalls", 1)
        harness.expectEqual("numRes.x", 1)
        harness.expectEqual("numCalls", 1)
        harness.expectEqual("objRes.k", 1)
        harness.expectEqual("objCalls", 1)
        harness.expectTrue("strCycThrew === true && numCycThrew === true")
    }

    @Test("dictionary helpers include inherited enumerable keys and reject invalid inherited values")
    func testDictionaryInheritedEnumerableProperties() {
        let harness = makeHarness()

        harness.eval("""
        const strInherited = Object.create({ FOO: 'bar' });
        strInherited.OWN = 'ok';
        const numInherited = Object.create({ x: 2.5 });
        numInherited.y = 4.0;
        const objInherited = Object.create({ inherited: 'yes' });
        objInherited.own = 42;

        const strOut = probe.stringDictionary(strInherited);
        const numOut = probe.doubleDictionary(numInherited);
        const objOut = probe.objectDictionary(objInherited);

        let strBadInherited = false;
        let numBadInherited = false;
        try {
            probe.stringDictionary(Object.create({ FOO: 99 }));
        } catch (e) {
            strBadInherited = (e instanceof TypeError) && e.message.includes('probe.stringDictionary');
        }
        try {
            probe.doubleDictionary(Object.create({ x: 'not-a-number' }));
        } catch (e) {
            numBadInherited = (e instanceof TypeError) && e.message.includes('probe.doubleDictionary');
        }
        """)

        #expect(!harness.hasException)
        harness.expectEqual("strOut.FOO", "bar")
        harness.expectEqual("strOut.OWN", "ok")
        harness.expectEqual("numOut.x", 2.5)
        harness.expectEqual("numOut.y", 4.0)
        harness.expectEqual("objOut.inherited", "yes")
        harness.expectEqual("objOut.own", 42)
        harness.expectTrue("strBadInherited === true && numBadInherited === true")
    }

    @Test("array helpers reject oversized sparse array lengths without wrapping Int32")
    func testOversizedSparseArrayLengthsRejected() {
        let harness = makeHarness()

        harness.eval("""
        const sparseStrings = [123];
        sparseStrings.length = Math.pow(2, 31);
        const sparseObjects = [123];
        sparseObjects.length = Math.pow(2, 31);

        let strThrew = false;
        let objArrThrew = false;
        try {
            probe.stringArray(sparseStrings);
        } catch (e) {
            strThrew = (e instanceof TypeError) &&
                       e.message.includes('probe.stringArray') &&
                       e.message.includes('items');
        }
        try {
            probe.objectDictionaryArray(sparseObjects);
        } catch (e) {
            objArrThrew = (e instanceof TypeError) &&
                          e.message.includes('probe.objectDictionaryArray') &&
                          e.message.includes('descriptors');
        }
        """)

        #expect(!harness.hasException)
        harness.expectTrue("strThrew === true && objArrThrew === true")
    }

    @Test("toObjectDictionary and toObjectDictionaryArray convert shared nested objects once across the object graph")
    func testSharedNestedObjectConvertedOnce() {
        let harness = makeHarness()

        harness.eval("""
        let n = 0;
        const shared = { get x() { return ++n; } };
        const r = probe.objectDictionary({ a: shared, b: shared, c: shared });
        const dictSnap = [r.a.x, r.b.x, r.c.x, n];

        let m = 0;
        const sharedInArray = { get x() { return ++m; } };
        const arr = probe.objectDictionaryArray([
            { a: sharedInArray, b: sharedInArray },
            { c: sharedInArray }
        ]);
        const arrSnap = [arr[0].a.x, arr[0].b.x, arr[1].c.x, m];
        """)

        #expect(!harness.hasException)
        harness.expectEqual("dictSnap.join(',')", "1,1,1,1")
        harness.expectEqual("arrSnap.join(',')", "1,1,1,1")
    }

    @Test("toObjectDictionaryArray reads array index getters once and preserves the validated element snapshot")
    func testToObjectDictionaryArrayReadsIndexGettersOnce() {
        let harness = makeHarness()

        _ = harness.evalValue("""
        let reads = 0;
        const a = [];
        Object.defineProperty(a, 0, {
            get() {
                return { attribute: ++reads === 1 ? 'kMDItemFSName' : 'kMDItemFSSize' };
            }
        });
        const out = probe.objectDictionaryArray(a);
        """)

        #expect(!harness.hasException)
        harness.expectEqual("reads", 1)
        harness.expectEqual("out.length", 1)
        harness.expectEqual("out[0].attribute", "kMDItemFSName")
    }

    @Test("dictionary helpers accept plain objects with custom Symbol.toStringTag without invoking tag getters")
    func testDictionaryHelpersAcceptCustomToStringTag() {
        let harness = makeHarness()

        harness.eval("""
        let tagReads = 0;
        function withThrowingTag(obj) {
            Object.defineProperty(obj, Symbol.toStringTag, {
                get() {
                    tagReads++;
                    return 'CustomTag';
                }
            });
            return obj;
        }

        const strTagged = probe.stringDictionary({
            FOO: 'bar',
            [Symbol.toStringTag]: 'Env'
        });
        const strGetterTagged = probe.stringDictionary(withThrowingTag({ FOO: 'baz' }));

        const numTagged = probe.doubleDictionary({
            x: 1,
            y: 2,
            [Symbol.toStringTag]: 'Point'
        });
        const numGetterTagged = probe.doubleDictionary(withThrowingTag({ x: 3, y: 4 }));

        const objTagged = probe.objectDictionary({
            title: 'ok',
            [Symbol.toStringTag]: 'Options'
        });
        const objGetterTagged = probe.objectDictionary(withThrowingTag({ title: 'ok2' }));

        const arrTagged = probe.objectDictionaryArray([
            { attribute: 'kMDItemFSName', [Symbol.toStringTag]: 'Sort' },
            withThrowingTag({ attribute: 'kMDItemFSSize' })
        ]);
        """)

        #expect(!harness.hasException)
        harness.expectEqual("strTagged.FOO", "bar")
        harness.expectEqual("strGetterTagged.FOO", "baz")
        harness.expectEqual("numTagged.x", 1)
        harness.expectEqual("numGetterTagged.y", 4)
        harness.expectEqual("objTagged.title", "ok")
        harness.expectEqual("objGetterTagged.title", "ok2")
        harness.expectEqual("arrTagged[0].attribute", "kMDItemFSName")
        harness.expectEqual("arrTagged[1].attribute", "kMDItemFSSize")
        harness.expectEqual("tagReads", 0)
    }

    @Test("no JSExport protocol method or writable property declares a Swift collection input")
    func testNoJSExportMethodTakesCollectionParameter() throws {
        // Verify the scanner detects collection parameters, writable collection properties,
        // collection typealiases (including optional aliases, callback signatures, and
        // cross-file aliases), and both single-line and next-line-brace protocol layouts,
        // while allowing collection return types, read-only collection properties, and JSValue.
        let syntheticAliasesSource = """
        typealias CrossFileStrings = [String]
        typealias CrossFileEnv = [String: String]
        """
        let syntheticSource = """
        typealias Names = [String]
        typealias OptPoints = [String: Double]?
        typealias BadCallback = ([String]) -> Void

        @objc protocol SyntheticBadAPI: JSExport {
            @objc func allowed(_ value: JSValue) -> [String]
            @objc var allowedReadOnly: [String] { get }
            @objc var allowedWritableScalar: String? { get set }
            @objc var badWritableProperty: [String: String] { get set }
            @objc var badCrossFileWritableProperty: CrossFileEnv { get set }
            @objc func badArray(_ items: [String])
            @objc func badDict(
                _ name: String,
                _ opts: [String: Any]?
            ) -> Bool
            @objc func badGeneric(_ set: Array<String>)
            @objc func badAlias(_ items: Names)
            @objc func badOptionalAlias(_ items: OptPoints)
            @objc func badOptionalAliasUse(_ items: Names?)
            @objc func badCallbackAlias(_ cb: (Names) -> Void)
            @objc func badCallbackTypealias(_ cb: BadCallback)
            @objc func badCrossFileAlias(_ items: CrossFileStrings)
        }

        @objc protocol NextLineBraceBadAPI: JSExport
        {
            @objc func badNextLine(_ items: [String])
        }

        @objc protocol SingleLineBadAPI: JSExport { @objc func badSingleLine(_ items: [String]) }
        """
        let syntheticResult = Self.scanJSExportProtocolsForCollectionParameters(
            inSources: [
                (fileLabel: "SyntheticAliases.swift", source: syntheticAliasesSource),
                (fileLabel: "Synthetic.swift", source: syntheticSource)
            ]
        )
        #expect(syntheticResult.protocolCount == 3)
        #expect(syntheticResult.violations.count == 13)
        #expect(syntheticResult.violations.contains { $0.contains("badWritableProperty") })
        #expect(syntheticResult.violations.contains { $0.contains("badCrossFileWritableProperty") })
        #expect(syntheticResult.violations.contains { $0.contains("badArray") })
        #expect(syntheticResult.violations.contains { $0.contains("badDict") })
        #expect(syntheticResult.violations.contains { $0.contains("badGeneric") })
        #expect(syntheticResult.violations.contains { $0.contains("badAlias") })
        #expect(syntheticResult.violations.contains { $0.contains("badOptionalAlias") })
        #expect(syntheticResult.violations.contains { $0.contains("badOptionalAliasUse") })
        #expect(syntheticResult.violations.contains { $0.contains("badCallbackAlias") })
        #expect(syntheticResult.violations.contains { $0.contains("badCallbackTypealias") })
        #expect(syntheticResult.violations.contains { $0.contains("badCrossFileAlias") })
        #expect(syntheticResult.violations.contains { $0.contains("badNextLine") })
        #expect(syntheticResult.violations.contains { $0.contains("badSingleLine") })
        #expect(!syntheticResult.violations.contains { $0.contains("allowed") })

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceRoot = repoRoot.appendingPathComponent("Hammerspoon 2")

        let enumerator = try #require(
            FileManager.default.enumerator(
                at: sourceRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        )

        var productionSources: [(fileLabel: String, source: String)] = []

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let relativePath = fileURL.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
            productionSources.append((fileLabel: relativePath, source: source))
        }

        let productionResult = Self.scanJSExportProtocolsForCollectionParameters(
            inSources: productionSources
        )

        #expect(productionSources.count > 50, "Expected to scan production Swift sources, found \(productionSources.count)")
        #expect(productionResult.protocolCount > 30, "Expected to scan JSExport protocols, found \(productionResult.protocolCount)")
        #expect(
            productionResult.violations.isEmpty,
            "JSExport methods and writable properties must take JSValue instead of bridged collections. Violations: \(productionResult.violations.joined(separator: "; "))"
        )
    }

    private struct ProtocolScanResult {
        var protocolCount: Int
        var violations: [String]
    }

    private static func scanJSExportProtocolsForCollectionParameters(
        inSources sources: [(fileLabel: String, source: String)]
    ) -> ProtocolScanResult {
        let strippedSources = sources.map { (fileLabel: $0.fileLabel, stripped: stripComments(from: $0.source)) }
        let typealiases = collectTypealiases(from: strippedSources.map(\.stripped))

        var protocolCount = 0
        var violations: [String] = []

        for entry in strippedSources {
            let protocols = extractJSExportProtocols(from: entry.stripped)
            protocolCount += protocols.count

            for proto in protocols {
                let protoViolations = scanProtocolBody(proto.body, typealiases: typealiases)
                for violation in protoViolations {
                    violations.append("\(entry.fileLabel) (\(proto.name)): \(violation)")
                }
            }
        }

        return ProtocolScanResult(protocolCount: protocolCount, violations: violations)
    }

    private static func collectTypealiases(from strippedSources: [String]) -> [String: String] {
        var aliases: [String: String] = [:]
        let pattern = #"\btypealias\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:<[^>]+>)?\s*=\s*([^\n;\}]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return aliases
        }

        for source in strippedSources {
            let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
            for match in regex.matches(in: source, range: nsRange) {
                guard let nameRange = Range(match.range(at: 1), in: source),
                      let targetRange = Range(match.range(at: 2), in: source)
                else {
                    continue
                }
                let name = String(source[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let target = String(source[targetRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty && !target.isEmpty {
                    aliases[name] = target
                }
            }
        }

        return aliases
    }

    private static func expandTypealiases(in text: String, typealiases: [String: String]) -> String {
        guard !typealiases.isEmpty else { return text }
        var current = text
        for _ in 0..<16 {
            var updated = current
            for (alias, target) in typealiases {
                let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: alias) + #"\b"#
                updated = updated.replacingOccurrences(
                    of: pattern,
                    with: "(\(target))",
                    options: .regularExpression
                )
            }
            if updated == current {
                break
            }
            current = updated
        }
        return current
    }

    private struct ExtractedProtocol {
        var name: String
        var body: String
    }

    private static func extractJSExportProtocols(from source: String) -> [ExtractedProtocol] {
        var results: [ExtractedProtocol] = []
        guard let protoRegex = try? NSRegularExpression(pattern: #"\bprotocol\s+([A-Za-z_][A-Za-z0-9_]*)"#) else {
            return results
        }

        var searchStart = source.startIndex
        while searchStart < source.endIndex {
            let nsRange = NSRange(searchStart..<source.endIndex, in: source)
            guard let match = protoRegex.firstMatch(in: source, range: nsRange),
                  let fullRange = Range(match.range, in: source),
                  let nameRange = Range(match.range(at: 1), in: source)
            else {
                break
            }

            let protoName = String(source[nameRange])
            let afterName = fullRange.upperBound

            guard let openBrace = source[afterName...].firstIndex(of: "{") else {
                break
            }

            let headerClause = String(source[afterName..<openBrace])
            guard let closeBrace = findMatchingBrace(in: source, openBrace: openBrace) else {
                break
            }

            if let colonIdx = headerClause.firstIndex(of: ":") {
                let inheritance = headerClause[headerClause.index(after: colonIdx)...]
                if inheritance.contains("JSExport")
                    || inheritance.contains("HSTypeAPI")
                    || inheritance.contains("HSModuleAPI") {
                    let body = String(source[source.index(after: openBrace)..<closeBrace])
                    results.append(ExtractedProtocol(name: protoName, body: body))
                }
            }

            searchStart = source.index(after: closeBrace)
        }

        return results
    }

    private static func findMatchingBrace(in text: String, openBrace: String.Index) -> String.Index? {
        var depth = 0
        for idx in text[openBrace...].indices {
            let ch = text[idx]
            if ch == "{" {
                depth += 1
            } else if ch == "}" {
                depth -= 1
                if depth == 0 {
                    return idx
                }
            }
        }
        return nil
    }

    private static func findMatchingParen(in text: String, openParen: String.Index) -> String.Index? {
        var depth = 0
        for idx in text[openParen...].indices {
            let ch = text[idx]
            if ch == "(" {
                depth += 1
            } else if ch == ")" {
                depth -= 1
                if depth == 0 {
                    return idx
                }
            }
        }
        return nil
    }

    private static func scanProtocolBody(_ body: String, typealiases: [String: String]) -> [String] {
        var violations: [String] = []

        // 1. Scan all func declarations in the protocol body.
        if let funcRegex = try? NSRegularExpression(pattern: #"\bfunc\s+([A-Za-z_][A-Za-z0-9_]*)"#) {
            var searchStart = body.startIndex
            while searchStart < body.endIndex {
                let nsRange = NSRange(searchStart..<body.endIndex, in: body)
                guard let match = funcRegex.firstMatch(in: body, range: nsRange),
                      let fullRange = Range(match.range, in: body)
                else {
                    break
                }

                guard let openParen = body[fullRange.upperBound...].firstIndex(of: "("),
                      let closeParen = findMatchingParen(in: body, openParen: openParen)
                else {
                    searchStart = fullRange.upperBound
                    continue
                }

                let signature = String(body[fullRange.lowerBound...closeParen])
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                let paramsSlice = String(body[body.index(after: openParen)..<closeParen])
                let expandedParams = expandTypealiases(in: paramsSlice, typealiases: typealiases)
                if containsForbiddenCollectionType(expandedParams) {
                    violations.append(signature)
                }

                searchStart = body.index(after: closeParen)
            }
        }

        // 2. Scan all writable var declarations in the protocol body.
        if let varRegex = try? NSRegularExpression(pattern: #"\bvar\s+([A-Za-z_][A-Za-z0-9_]*)\s*:"#) {
            var searchStart = body.startIndex
            while searchStart < body.endIndex {
                let nsRange = NSRange(searchStart..<body.endIndex, in: body)
                guard let match = varRegex.firstMatch(in: body, range: nsRange),
                      let fullRange = Range(match.range, in: body)
                else {
                    break
                }

                guard let openBrace = body[fullRange.upperBound...].firstIndex(of: "{"),
                      let closeBrace = findMatchingBrace(in: body, openBrace: openBrace)
                else {
                    searchStart = fullRange.upperBound
                    continue
                }

                let typeSlice = String(body[fullRange.upperBound..<openBrace])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let accessorsSlice = String(body[body.index(after: openBrace)..<closeBrace])
                let isWritable = accessorsSlice.range(of: #"\bset\b"#, options: .regularExpression) != nil

                if isWritable {
                    let expandedType = expandTypealiases(in: typeSlice, typealiases: typealiases)
                    if containsForbiddenCollectionType(expandedType) {
                        let declaration = String(body[fullRange.lowerBound...closeBrace])
                            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                        violations.append(declaration)
                    }
                }

                searchStart = body.index(after: closeBrace)
            }
        }

        return violations
    }

    private static func containsForbiddenCollectionType(_ typeExpression: String) -> Bool {
        let trimmed = typeExpression.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return false
        }
        let forbiddenPatterns = [
            #"\[[^\]]+\]"#,
            #"\bArray\s*<"#,
            #"\bDictionary\s*<"#,
            #"\bSet\s*<"#
        ]
        for pattern in forbiddenPatterns {
            if trimmed.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    private static func stripComments(from source: String) -> String {
        var result = ""
        result.reserveCapacity(source.count)
        var i = source.startIndex
        var inBlockComment = false
        var inLineComment = false

        while i < source.endIndex {
            let ch = source[i]
            let nextIdx = source.index(after: i)
            let nextCh: Character? = nextIdx < source.endIndex ? source[nextIdx] : nil

            if inLineComment {
                if ch == "\n" {
                    inLineComment = false
                    result.append(ch)
                }
                i = nextIdx
                continue
            }

            if inBlockComment {
                if ch == "*" && nextCh == "/" {
                    inBlockComment = false
                    i = source.index(after: nextIdx)
                } else {
                    if ch == "\n" {
                        result.append("\n")
                    }
                    i = nextIdx
                }
                continue
            }

            if ch == "/" && nextCh == "/" {
                inLineComment = true
                i = source.index(after: nextIdx)
                continue
            }

            if ch == "/" && nextCh == "*" {
                inBlockComment = true
                i = source.index(after: nextIdx)
                continue
            }

            result.append(ch)
            i = nextIdx
        }

        return result
    }
}
