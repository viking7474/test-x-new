#import <Foundation/Foundation.h>
#import <os/lock.h>
#include <stdint.h>
#include <math.h>
#include <time.h>
#include <stdio.h>

static NSUInteger gChecks, gFailures, gSerializations, gDeallocations;
static void (^gDuringFreeze)(void);
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)

// Forward the real Foundation codec. The optional callback deterministically
// invalidates during preparation, outside the production cache lock.
@interface PXCacheSerializationFixture : NSObject
+ (NSData *)dataWithPropertyList:(id)value format:(NSPropertyListFormat)format options:(NSUInteger)options error:(NSError **)error;
+ (id)propertyListWithData:(NSData *)data options:(NSUInteger)options format:(NSPropertyListFormat *)format error:(NSError **)error;
@end
@implementation PXCacheSerializationFixture
+ (NSData *)dataWithPropertyList:(id)value format:(NSPropertyListFormat)format options:(NSUInteger)options error:(NSError **)error {
    gSerializations++;
    void (^callback)(void) = gDuringFreeze; gDuringFreeze = nil;
    if (callback) callback();
    return [NSPropertyListSerialization dataWithPropertyList:value format:format options:options error:error];
}
+ (id)propertyListWithData:(NSData *)data options:(NSUInteger)options format:(NSPropertyListFormat *)format error:(NSError **)error {
    return [NSPropertyListSerialization propertyListWithData:data options:options format:format error:error];
}
@end
#define NSPropertyListSerialization PXCacheSerializationFixture
#include "PXStorageObjectCache.inc"
#undef NSPropertyListSerialization

@interface PXCacheDeallocSentinel : NSObject
@end
@implementation PXCacheDeallocSentinel
- (void)dealloc { gDeallocations++; PXStorageInvalidateCache(); }
@end
static void SeedLegacySentinel(void) {
    PXStorageInvalidateCache();
    @autoreleasepool {
        PXCacheDeallocSentinel *sentinel = [PXCacheDeallocSentinel new];
        NSDictionary *packet = [[NSDictionary alloc] initWithObjectsAndKeys:sentinel, @"sentinel", nil];
        os_unfair_lock_lock(&gStorageCacheLock);
        gCachedStorageValues = packet; gStorageCacheLoadedAt = 0;
        os_unfair_lock_unlock(&gStorageCacheLock);
    } // Only the cache now owns the sentinel's dictionary.
}
static uint64_t MissAt(NSTimeInterval now) {
    uint64_t generation = UINT64_MAX;
    CHECK(PXStorageCachedValues(now, &generation) == nil, "cache miss captures an invalidation generation");
    return generation;
}
static void TestLifetime(void) {
    NSUInteger released = gDeallocations;
    SeedLegacySentinel(); PXStorageInvalidateCache();
    CHECK(gDeallocations == released + 1 && !gCachedStorageValues, "invalidate releases old cache after unlock so dealloc may reenter invalidation");
#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    SeedLegacySentinel(); released = gDeallocations;
    uint64_t generation = gStorageCacheGeneration;
    NSDictionary *packet = @{ @"TotalStorage": @"64", @"FreeStorage": @"16" };
    NSDictionary *published = PXStoragePublishValues(packet, PXStorageCacheTime(), generation);
    CHECK(gDeallocations == released + 1 && [published isEqual:packet] && !gCachedStorageValues,
          "replacement releases after unlock and returned packet survives dealloc-triggered invalidation");
    SeedLegacySentinel(); released = gDeallocations;
    CHECK(!PXStorageCachedValues(100, &generation) && gDeallocations == released + 1,
          "expiration releases old cache outside lock even when its dealloc reenters");
#endif
}
static void TestObjectCache(void) {
    PXStorageInvalidateCache();
    NSMutableString *total = [@"64" mutableCopy], *tag = [@"tag" mutableCopy];
    NSMutableArray *tags = [NSMutableArray arrayWithObject:tag];
    NSMutableDictionary *packet = [@{ @"TotalStorage": total, @"FreeStorage": @16, @"tags": tags } mutableCopy];
    NSTimeInterval now = PXStorageCacheTime();
    uint64_t generation = MissAt(now);
    NSUInteger serialized = gSerializations;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    CHECK(now == 0 && generation == 0, "RootHide bypass needs no object-cache clock or epoch");
    NSDictionary *published = PXStoragePublishValues(packet, NAN, UINT64_MAX);
    CHECK(published == packet && !PXStorageCachedValues(0, &generation) && serialized == gSerializations,
          "RootHide returns its captured view unchanged without codec or cross-view object reuse");
    PXStorageInvalidateCache();
    CHECK(PXStoragePublishValues(packet, 123, 999) == packet, "RootHide invalidation never substitutes the object-cache authority");
#else
    CHECK(isfinite(now) && now >= 0, "rootful object cache uses an available monotonic timestamp");
    NSDictionary *published = PXStoragePublishValues(packet, now, generation);
    CHECK(published != packet && serialized + 1 == gSerializations, "rootful cache detaches a plist packet once outside the lock");
    [total setString:@"999"]; [tag setString:@"changed"]; [tags addObject:@"new"]; packet[@"extra"] = @YES;
    CHECK([published[@"TotalStorage"] isEqual:@"64"] && [published[@"tags"] count] == 1 &&
          [published[@"tags"][0] isEqual:@"tag"] && !published[@"extra"], "cached descendants cannot change through caller-owned mutable strings arrays or dictionary");
    CHECK(PXStorageCachedValues(now + 29.999, &generation) == published &&
          !PXStorageCachedValues(now + 30, &generation), "cache retains its 30-second exclusive TTL boundary");
    generation = MissAt(now);
    PXStoragePublishValues(published, now + 10, generation);
    CHECK(!PXStorageCachedValues(now, &generation), "negative elapsed time is never accepted as fresh");
    NSDictionary *oneShot = PXStoragePublishValues(published, NAN, generation);
    CHECK([oneShot isEqual:published] && !PXStorageCachedValues(now, &generation), "unavailable clock can serve a detached one-shot value without caching it");

    PXStorageInvalidateCache(); generation = MissAt(PXStorageCacheTime());
    PXStorageInvalidateCache();
    CHECK(!PXStoragePublishValues(published, PXStorageCacheTime(), generation) && !gCachedStorageValues,
          "a loader invalidated during I O cannot resurrect its old cache packet");
    uint64_t current = MissAt(PXStorageCacheTime());
    NSDictionary *newValues = @{ @"TotalStorage": @"128", @"FreeStorage": @"32" };
    NSDictionary *winner = PXStoragePublishValues(newValues, PXStorageCacheTime(), current);
    CHECK(PXStoragePublishValues(published, PXStorageCacheTime(), generation) == winner &&
          [gCachedStorageValues isEqual:newValues], "stale publisher may use a fresh winner but never overwrite newer invalidation state");
    NSTimeInterval expiredAt = PXStorageCacheTime() - 31;
    os_unfair_lock_lock(&gStorageCacheLock); gStorageCacheLoadedAt = expiredAt; os_unfair_lock_unlock(&gStorageCacheLock);
    CHECK(!PXStoragePublishValues(published, PXStorageCacheTime(), generation), "stale publisher cannot bypass TTL using an expired winner");

    PXStorageInvalidateCache(); generation = MissAt(PXStorageCacheTime());
    gDuringFreeze = ^{ PXStorageInvalidateCache(); };
    CHECK(!PXStoragePublishValues(newValues, PXStorageCacheTime(), generation) && !gCachedStorageValues,
          "invalidation during plist preparation rejects publication after freeze without a recursive lock");
    generation = MissAt(PXStorageCacheTime());
    NSDictionary *bad = @{ @"TotalStorage": [NSObject new], @"FreeStorage": @1 };
    NSDictionary *safe = PXStoragePublishValues(bad, PXStorageCacheTime(), generation);
    CHECK([safe[@"TotalStorage"] isEqual:@"128"] && [safe[@"FreeStorage"] isEqual:@"38"],
          "non plist input gets enabled safe-byte defaults instead of a mutable or physical-capacity fallback");
    PXStorageInvalidateCache(); generation = MissAt(PXStorageCacheTime());
    CHECK(!PXStoragePublishValues(nil, PXStorageCacheTime(), generation), "nil publication remains unavailable");
#endif
}
int main(void) {
    @autoreleasepool {
        @try { TestLifetime(); TestObjectCache(); }
        @catch (NSException *exception) { gFailures++; fprintf(stderr, "FAIL: unexpected storage-cache exception: %s\n", exception.description.UTF8String); }
        PXStorageInvalidateCache();
        printf("Storage object cache: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
