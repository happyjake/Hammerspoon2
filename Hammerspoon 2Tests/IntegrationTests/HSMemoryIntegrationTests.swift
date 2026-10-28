import XCTest
import JavaScriptCore
import Darwin
@testable import Hammerspoon_2

private nonisolated final class HSMemoryUnavailableShrinkVM: JSVirtualMachine {
    override func responds(to selector: Selector!) -> Bool {
        if selector == NSSelectorFromString("shrinkFootprintWhenIdle") { return false }
        return super.responds(to: selector)
    }

    @objc func shrinkFootprintWhenIdle() {
        XCTFail("An unavailable shrink selector must not be called")
    }
}

nonisolated final class HSMemoryIntegrationTests: XCTestCase {
    @MainActor
    private func makeHarness(vm: JSVirtualMachine = JSVirtualMachine()) -> JSTestHarness {
        let harness = JSTestHarness(vm: vm)
        harness.loadModule(HSMemoryModule.self, as: "memory")
        return harness
    }

    private func hasSymbol(_ name: String) -> Bool {
        guard let handle = unsafe dlopen(nil, RTLD_LAZY) else { return false }
        defer { _ = unsafe dlclose(handle) }
        return unsafe dlsym(handle, name) != nil
    }

    @MainActor
    private func check(_ harness: JSTestHarness, _ script: String,
                       file: StaticString = #filePath, line: UInt = #line) {
        let result = harness.evalValue(script)
        XCTAssertFalse(harness.hasException, harness.exceptionMessage ?? "", file: file, line: line)
        XCTAssertEqual(result?.toBool(), true, file: file, line: line)
    }

    @MainActor
    func testRegistrationAndSnapshot() {
        let harness = JSTestHarness()
        harness.loadModuleRoot()
        check(harness, """
            (() => {
                const s = hs.memory.stats();
                const counters = ['sizeInUse', 'sizeAllocated', 'blocksInUse'];
                const sane = n => Number.isFinite(n) && n >= 0;
                return Object.getPrototypeOf(s) === Object.prototype &&
                    s.footprint > 0 &&
                    (s.footprintPeak === undefined || s.footprintPeak >= s.footprint) &&
                    s.malloc.zones.length > 0 &&
                    s.malloc.zones.every(z => typeof z.name === 'string' && z.name.length > 0 &&
                        counters.every(k => sane(z[k]))) &&
                    counters.every(k => sane(s.malloc[k]) &&
                        s.malloc[k] === s.malloc.zones.reduce((total, z) => total + z[k], 0)) &&
                    JSON.parse(JSON.stringify(s)).footprint === s.footprint;
            })()
            """)
    }

    @MainActor
    func testJavaScriptHeapFields() throws {
        let harness = makeHarness()
        let available = hasSymbol("JSGetMemoryUsageStatistics")
        XCTAssertEqual(harness.evalValue("hs.memory.stats().js !== null")?.toBool(), available)
        XCTAssertFalse(harness.hasException)
        try XCTSkipUnless(available, "Private JSC statistics are unavailable")
        check(harness, """
            (() => {
                hs.memory.relieve({malloc: false});
                const s = hs.memory.stats().js;
                const counters = ['heapSize', 'heapCapacity', 'extraMemorySize', 'objectCount',
                    'protectedObjectCount', 'globalObjectCount', 'protectedGlobalObjectCount'];
                return counters.every(k => Number.isFinite(s[k]) && s[k] >= 0) &&
                    s.objectCount > 0 && s.globalObjectCount > 0 &&
                    ['objectTypeCounts', 'protectedObjectTypeCounts'].every(k =>
                        s[k] !== null && typeof s[k] === 'object' && !Array.isArray(s[k]) &&
                        Object.values(s[k]).every(n => Number.isInteger(n) && n >= 0));
            })()
            """)
    }

    @MainActor
    func testIncludesRegisteredMallocZone() throws {
        let zone = try XCTUnwrap(unsafe malloc_create_zone(0, 0))
        defer { unsafe malloc_destroy_zone(zone) }
        unsafe malloc_set_zone_name(zone, "MemoryStatisticsTestZone")
        let allocation = try XCTUnwrap(unsafe malloc_zone_malloc(zone, 4096))
        defer { unsafe malloc_zone_free(zone, allocation) }
        check(makeHarness(), """
            hs.memory.stats().malloc.zones.some(z =>
                z.name === 'MemoryStatisticsTestZone' && z.blocksInUse >= 1 && z.sizeInUse >= 4096)
            """)
    }

    @MainActor
    func testTreatmentOptionsAndRepeatedCalls() {
        let harness = makeHarness()
        harness.eval("var gcAvailable = \(hasSymbol("JSSynchronousGarbageCollectForDebugging"));")
        XCTAssertFalse(harness.hasException)
        check(harness, """
            (() => {
                const options = [undefined, null, {}, {gc: false}, {malloc: false},
                    {gc: false, malloc: false}, {gc: true, malloc: true}, {shrink: false}];
                const keys = ['footprintBefore', 'footprintAfterGC', 'footprintAfter',
                    'mallocReleased', 'gcMs', 'reliefMs'].sort().join(',');
                for (let repeat = 0; repeat < 3; repeat++) {
                    for (const opts of options) {
                        const r = hs.memory.relieve(opts);
                        if (Object.keys(r).sort().join(',') !== keys) return false;
                        if (!['footprintBefore', 'footprintAfterGC', 'footprintAfter'].every(k =>
                            Number.isFinite(r[k]) && r[k] > 0)) return false;
                        if (!['mallocReleased', 'gcMs', 'reliefMs'].every(k =>
                            Number.isFinite(r[k]) && r[k] >= 0)) return false;
                        if (opts?.gc === false && r.gcMs !== 0) return false;
                        if (opts?.gc !== false && gcAvailable && r.gcMs <= 0) return false;
                        if (!gcAvailable && r.gcMs !== 0) return false;
                        if (opts?.malloc === false && (r.mallocReleased !== 0 || r.reliefMs !== 0)) return false;
                        if (opts?.malloc !== false && r.reliefMs <= 0) return false;
                    }
                }
                const r = hs.memory.relieve();
                return r.footprintAfter > 0 && Object.keys(r).sort().join(',') === keys;
            })()
            """)
    }

    @MainActor
    func testShrinkReportsAvailabilityAndPreservesJavaScript() {
        let harness = makeHarness()
        let available = harness.vm.responds(to: NSSelectorFromString("shrinkFootprintWhenIdle"))
        harness.eval("var shrinkReport = hs.memory.relieve({shrink: true});")
        XCTAssertFalse(harness.hasException, harness.exceptionMessage ?? "")
        XCTAssertEqual(harness.evalValue("shrinkReport.shrinkAvailable")?.toBool(), available)
        check(harness, """
            Number.isFinite(shrinkReport.shrinkMs) && shrinkReport.shrinkMs >= 0 &&
                (shrinkReport.shrinkAvailable || shrinkReport.shrinkMs === 0) &&
                shrinkReport.mallocReleased >= 0 && shrinkReport.reliefMs > 0 &&
                shrinkReport.footprintBefore > 0 && shrinkReport.footprintAfterGC > 0 &&
                shrinkReport.footprintAfter > 0
            """)
        // A separate evaluation runs after the shrink request's JS stack unwinds.
        check(harness, """
            (() => {
                let sum = 0;
                for (let i = 0; i < 100000; i++) sum += i;
                return sum === 4999950000;
            })()
            """)
    }

    @MainActor
    func testShrinkWithoutSeparateGCOrMallocRelief() {
        check(makeHarness(), """
            (() => {
                const r = hs.memory.relieve({gc: false, malloc: false, shrink: true});
                return typeof r.shrinkAvailable === 'boolean' &&
                    Number.isFinite(r.shrinkMs) && r.shrinkMs >= 0 &&
                    r.gcMs === 0 && r.reliefMs === 0 && r.mallocReleased === 0;
            })()
            """)
    }

    @MainActor
    func testUnavailableShrinkIsANoOp() {
        let harness = makeHarness(vm: HSMemoryUnavailableShrinkVM())
        check(harness, """
            (() => {
                const r = hs.memory.relieve({gc: false, malloc: false, shrink: true});
                return r.shrinkAvailable === false && r.shrinkMs === 0 &&
                    r.gcMs === 0 && r.reliefMs === 0 && r.mallocReleased === 0 &&
                    r.footprintBefore > 0 && r.footprintAfterGC > 0 && r.footprintAfter > 0;
            })()
            """)
        check(harness, "[1, 2, 3].map(n => n * n).join(',') === '1,4,9'")
    }

    @MainActor
    func testAllocationAndSynchronousCollection() throws {
        let harness = makeHarness()
        try XCTSkipUnless(hasSymbol("JSGetMemoryUsageStatistics"), "Private JSC statistics are unavailable")
        try XCTSkipUnless(hasSymbol("JSSynchronousGarbageCollectForDebugging"), "Private synchronous JSC collection is unavailable")

        // Separate evaluations let allocation frames unwind before full GC.
        harness.eval("hs.memory.relieve(); var baseline = hs.memory.stats().js.objectCount;")
        XCTAssertFalse(harness.hasException)
        harness.eval("""
            var retained = Array.from({length: 20000}, (_, i) => ({index: i}));
            // JSC counts marked cells; collect while the objects remain rooted.
            hs.memory.relieve({malloc: false});
            var allocated = hs.memory.stats().js.objectCount;
            """)
        XCTAssertFalse(harness.hasException)
        check(harness, "allocated >= baseline + 19000")
        harness.eval("retained = null;")
        XCTAssertFalse(harness.hasException)
        harness.eval("var report = hs.memory.relieve({malloc: false});")
        XCTAssertFalse(harness.hasException)
        check(harness, "report.gcMs > 0")
        check(harness, "hs.memory.stats().js.objectCount < allocated - 10000")
        check(harness, "report.mallocReleased === 0 && report.reliefMs === 0")
    }
}
