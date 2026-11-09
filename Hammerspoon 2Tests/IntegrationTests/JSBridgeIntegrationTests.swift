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

    @Test("toDoubleDictionary validates plain objects with numeric values and rejects booleans")
    func testToDoubleDictionary() {
        let harness = makeHarness()

        harness.expectEqual("probe.doubleDictionary({ x: 10.5, y: -2 }).x", 10.5)
        #expect(!harness.hasException)

        harness.eval("""
        var bad = [
            null,
            undefined,
            [1, 2],
            function() {},
            '10',
            10,
            { x: '10', y: 20 },
            { x: true, y: 20 },
            { x: null, y: 20 },
            { x: undefined, y: 20 }
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
}
