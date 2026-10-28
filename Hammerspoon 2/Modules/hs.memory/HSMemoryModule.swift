import Foundation
import JavaScriptCore

/// Inspect the current process's memory and explicitly request garbage collection
/// and allocator relief. Loading this module does not collect or release memory.
@objc protocol HSMemoryModuleAPI: JSExport {
    /// Returns a snapshot of process, malloc, and JavaScript heap memory.
    ///
    /// All sizes are bytes. `footprint` is task_vm_info's phys_footprint;
    /// `footprintPeak` is included when the kernel supplies its peak ledger.
    /// `malloc` contains `sizeInUse`, `sizeAllocated`, `blocksInUse`, and `zones`.
    /// The zones array has objects with `name` and those same three counters. Totals sum
    /// every registered malloc zone, including zones with duplicate names.
    /// `js` contains `heapSize`, `heapCapacity`, `extraMemorySize`, `objectCount`,
    /// `protectedObjectCount`, `globalObjectCount`, `protectedGlobalObjectCount`,
    /// and the name-to-count maps `objectTypeCounts` and `protectedObjectTypeCounts`.
    /// The protected type map is empty when JSC does not provide it. `js` is null
    /// if its private statistics symbol is unavailable. JSC figures cover the
    /// calling context's VM; process and malloc figures cover the entire process.
    /// Sampling itself allocates memory; the counters are not an atomic snapshot.
    /// - Returns: A plain object containing `footprint`, optional `footprintPeak`, `malloc`, and `js`. Throws if task or malloc statistics cannot be read.
    /// - Example:
    /// ```js
    /// console.log(JSON.stringify(hs.memory.stats()))
    /// ```
    @objc func stats() -> [String: Any]

    /// Runs synchronous full JavaScript GC, then requests maximal malloc relief.
    ///
    /// GC and malloc relief default to true. GC runs on the calling JS thread. If its
    /// private symbol is unavailable, GC is skipped and `gcMs` is zero. Skipping
    /// malloc relief leaves `mallocReleased` and `reliefMs` zero. Timings are in
    /// milliseconds; footprints and released memory are bytes. Footprints are
    /// measured immediately before, after GC, and after all requests, even when
    /// a treatment is skipped. JSC releases pages asynchronously, so footprints
    /// need not decrease. This call does not wait for those pages to be returned.
    ///
    /// Set `shrink: true` to also request JavaScriptCore's private
    /// `shrinkFootprintWhenIdle` SPI on the calling context's VM and JS thread.
    /// Shrink defaults to false. Only request it at idle: it drops cached JIT code
    /// and bytecode, performs a full GC, and asks the WebKit allocator to release
    /// free pages. The next hot path must re-tier its JIT code. Shrink performs its
    /// own GC even when `gc: false`; that flag controls only the separate initial GC.
    /// JSC defers shrinking until the current JS stack unwinds, so `shrinkMs`
    /// measures only the request call, not deferred work. Sample `stats()` later
    /// to observe reclamation. If the SPI is missing, shrink is a no-op with
    /// `shrinkAvailable: false` and `shrinkMs: 0`.
    /// - Parameter opts?: {{gc?: boolean, malloc?: boolean, shrink?: boolean} | null} Optional treatment flags; omitted, undefined, or null uses GC and malloc relief, without shrinking.
    /// - Returns: A plain object with `footprintBefore`, `footprintAfterGC`, `footprintAfter`, `mallocReleased`, `gcMs`, and `reliefMs`. Only `shrink: true` adds `shrinkAvailable` (whether the VM supports the SPI) and `shrinkMs`. Throws if a footprint cannot be read.
    /// - Example:
    /// ```js
    /// console.log(JSON.stringify(hs.memory.relieve({gc: false})))
    /// // During an idle period; inspect stats again after this JS stack returns.
    /// console.log(JSON.stringify(hs.memory.relieve({gc: true, malloc: false, shrink: true})))
    /// ```
    @objc func relieve(_ opts: [String: Any]?) -> [String: Any]
}

@_documentation(visibility: private)
@MainActor
@objc class HSMemoryModule: NSObject, HSModuleAPI, HSMemoryModuleAPI {
    var name = "hs.memory"
    let engineID: UUID

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKDebug("Init of \(name): \(engineID)")
    }

    func shutdown() {}

    isolated deinit {
        AKDebug("Deinit of \(name): \(engineID)")
    }

    func stats() -> [String: Any] {
        guard let context = JSContext.current() else { return [:] }
        return HSMemorySnapshot(context) ?? [:]
    }

    func relieve(_ opts: [String: Any]?) -> [String: Any] {
        guard let context = JSContext.current() else { return [:] }
        return HSMemoryRelieve(context, opts?["gc"] as? Bool ?? true,
                               opts?["malloc"] as? Bool ?? true,
                               opts?["shrink"] as? Bool ?? false) ?? [:]
    }
}
