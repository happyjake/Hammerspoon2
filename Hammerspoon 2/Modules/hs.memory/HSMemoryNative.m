#import "HSMemoryNative.h"
#import "../../Bridging-Header.h"
#import <dlfcn.h>
#import <mach/mach.h>
#import <malloc/malloc.h>
#import <time.h>

// Derive function pointer types from the declarations, including the existing GC
// declaration. Neither private function is directly referenced by this module.
static __typeof__(&JSGetMemoryUsageStatistics) memoryStatistics;
static __typeof__(&JSSynchronousGarbageCollectForDebugging) synchronousGC;

static void resolveJavaScriptSymbols(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        memoryStatistics = (__typeof__(memoryStatistics))dlsym(RTLD_DEFAULT, "JSGetMemoryUsageStatistics");
        synchronousGC = (__typeof__(synchronousGC))dlsym(RTLD_DEFAULT, "JSSynchronousGarbageCollectForDebugging");
    });
}

static BOOL readFootprint(JSContext *context, uint64_t *footprint, NSNumber **peak) {
    task_vm_info_data_t info = {0};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t status = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count);
    if (status != KERN_SUCCESS || count < TASK_VM_INFO_REV1_COUNT) {
        context.exception = [JSValue valueWithNewErrorFromMessage:@"Unable to read task memory footprint" inContext:context];
        return NO;
    }
    *footprint = info.phys_footprint;
    if (peak) {
        *peak = count >= TASK_VM_INFO_REV3_COUNT ? @(info.ledger_phys_footprint_peak) : nil;
    }
    return YES;
}

static NSDictionary *mallocSnapshot(JSContext *context) {
    vm_address_t *addresses = NULL;
    unsigned count = 0;
    if (malloc_get_all_zones(mach_task_self(), NULL, &addresses, &count) != KERN_SUCCESS) {
        context.exception = [JSValue valueWithNewErrorFromMessage:@"Unable to enumerate malloc zones" inContext:context];
        return nil;
    }
    // With the default in-process reader, addresses is borrowed malloc storage.
    // Keep an array so duplicate zone names do not overwrite one another.
    NSMutableArray *zones = [NSMutableArray arrayWithCapacity:count];
    uint64_t sizeInUse = 0, sizeAllocated = 0, blocksInUse = 0;
    for (unsigned i = 0; i < count; i++) {
        malloc_zone_t *zone = (malloc_zone_t *)addresses[i];
        malloc_statistics_t statistics = {0};
        malloc_zone_statistics(zone, &statistics);
        const char *zoneName = malloc_get_zone_name(zone);
        NSString *name = zoneName ? [NSString stringWithUTF8String:zoneName] : nil;
        [zones addObject:@{
            @"name": name ?: @"unnamed",
            @"sizeInUse": @(statistics.size_in_use),
            @"sizeAllocated": @(statistics.size_allocated),
            @"blocksInUse": @(statistics.blocks_in_use)
        }];
        sizeInUse += statistics.size_in_use;
        sizeAllocated += statistics.size_allocated;
        blocksInUse += statistics.blocks_in_use;
    }
    return @{@"sizeInUse": @(sizeInUse), @"sizeAllocated": @(sizeAllocated),
             @"blocksInUse": @(blocksInUse), @"zones": zones};
}

NSDictionary<NSString *, id> *HSMemorySnapshot(JSContext *context) {
    uint64_t footprint;
    NSNumber *peak = nil;
    if (!readFootprint(context, &footprint, &peak)) return nil;
    NSDictionary *mallocStats = mallocSnapshot(context);
    if (!mallocStats) return nil;

    resolveJavaScriptSymbols();
    NSMutableDictionary *jsStats = nil;
    if (memoryStatistics) {
        JSObjectRef object = memoryStatistics(context.JSGlobalContextRef);
        if (object) {
            // JSValue protects the result while converting it to Foundation values.
            JSValue *value = [JSValue valueWithJSValueRef:object inContext:context];
            jsStats = [[value toDictionary] mutableCopy];
            // Some JSC versions expose only the all-object type counts.
            if (!jsStats[@"protectedObjectTypeCounts"]) jsStats[@"protectedObjectTypeCounts"] = @{};
        }
    }
    NSMutableDictionary *result = [@{@"footprint": @(footprint), @"malloc": mallocStats,
                                     @"js": jsStats ?: (id)NSNull.null} mutableCopy];
    if (peak) result[@"footprintPeak"] = peak;
    return result;
}

NSDictionary<NSString *, id> *HSMemoryRelieve(JSContext *context, BOOL gc, BOOL mallocRelief) {
    resolveJavaScriptSymbols();
    uint64_t before, afterGC, after;
    if (!readFootprint(context, &before, NULL)) return nil;
    double gcMs = 0, reliefMs = 0;
    size_t released = 0;
    if (gc && synchronousGC) {
        uint64_t start = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        synchronousGC(context.JSGlobalContextRef);
        gcMs = (clock_gettime_nsec_np(CLOCK_UPTIME_RAW) - start) / 1e6;
    }
    if (!readFootprint(context, &afterGC, NULL)) return nil;
    if (mallocRelief) {
        uint64_t start = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
        released = malloc_zone_pressure_relief(NULL, 0);
        reliefMs = (clock_gettime_nsec_np(CLOCK_UPTIME_RAW) - start) / 1e6;
    }
    // JSC returns allocator pages asynchronously. Do not wait or infer a decrease.
    if (!readFootprint(context, &after, NULL)) return nil;
    return @{@"footprintBefore": @(before), @"footprintAfterGC": @(afterGC),
             @"footprintAfter": @(after), @"mallocReleased": @(released),
             @"gcMs": @(gcMs), @"reliefMs": @(reliefMs)};
}
