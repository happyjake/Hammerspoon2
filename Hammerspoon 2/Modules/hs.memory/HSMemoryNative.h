#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

NS_ASSUME_NONNULL_BEGIN

// Private JavaScriptCore API; resolve dynamically rather than linking to it.
JS_EXPORT JSObjectRef JSGetMemoryUsageStatistics(JSContextRef ctx);

NSDictionary<NSString *, id> * _Nullable HSMemorySnapshot(JSContext *context);
NSDictionary<NSString *, id> * _Nullable HSMemoryRelieve(JSContext *context, BOOL gc, BOOL mallocRelief);

NS_ASSUME_NONNULL_END
