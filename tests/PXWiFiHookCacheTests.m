#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <os/lock.h>
#import "PXWiFiHookResolver.h"
#include <stdint.h>
#include <math.h>
#include <time.h>
#include <stdio.h>

static NSUInteger gChecks, gFailures, gSerializations, gDeallocations;
static NSUInteger gReads, gWrites, gFactoryCalls, gClassLookups, gManagerReads, gGenerations, gFileManagers, gSelections, gCaptures;
static void (^gDuringFreeze)(void);
static BOOL gThrowCodec, gThrowDecode, gDecodedFault;
static __weak id gEncodedData, gDecodedRoot;
static NSUInteger gIdentityPaths;
@interface PXWiFiThrowingRecord : NSObject
@end
@implementation PXWiFiThrowingRecord
- (BOOL)isKindOfClass:(Class)type { return type == NSDictionary.class || [super isKindOfClass:type]; }
- (id)objectForKeyedSubscript:(id __unsafe_unretained)key {
    (void)key; [NSException raise:@"fixture.record" format:@"record lookup failed"]; return nil;
}
@end
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PX_RUNTIME_READ_OPERATION do {} while (0)

@interface PXWiFiThrowingProfile : NSObject
@end
@implementation PXWiFiThrowingProfile
- (BOOL)isEqualToString:(NSString * __unsafe_unretained)value {
    (void)value; [NSException raise:@"fixture.profile" format:@"profile comparison failed"]; return NO;
}
@end
@interface PXWiFiCodec : NSObject
+ (NSData *)dataWithPropertyList:(id)value format:(NSPropertyListFormat)format options:(NSUInteger)options error:(NSError **)error;
+ (id)propertyListWithData:(NSData *)data options:(NSUInteger)options format:(NSPropertyListFormat *)format error:(NSError **)error;
@end
@implementation PXWiFiCodec
+ (NSData *)dataWithPropertyList:(id __unsafe_unretained)value format:(NSPropertyListFormat)format options:(NSUInteger)options error:(NSError **)error {
    gSerializations++;
    void (^callback)(void) = gDuringFreeze; gDuringFreeze = nil;
    NSData *data = nil;
    @try {
        if (callback) callback();
        if (gThrowCodec) [NSException raise:@"fixture.codec" format:@"freeze failed"];
        data = [NSPropertyListSerialization dataWithPropertyList:value format:format options:options error:error];
        gEncodedData = data; return data;
    } @finally { data = nil; callback = nil; }
}
+ (id)propertyListWithData:(NSData * __unsafe_unretained)data options:(NSUInteger)options format:(NSPropertyListFormat *)format error:(NSError **)error {
    if (gThrowDecode) [NSException raise:@"fixture.decode" format:@"decode failed"];
    if (gDecodedFault) { id record = [PXWiFiThrowingRecord new]; gDecodedRoot = record; return record; }
    return [NSPropertyListSerialization propertyListWithData:data options:options format:format error:error];
}
@end
#define NSPropertyListSerialization PXWiFiCodec
#include "PXWiFiHookCache.inc"
#undef NSPropertyListSerialization

@interface PXWiFiDeallocSentinel : NSObject
@end
@implementation PXWiFiDeallocSentinel
- (void)dealloc { gDeallocations++; PXWiFiInvalidateCache(); }
@end
static NSDictionary *Packet(NSString *ssid) { return @{ @"ssid": ssid, @"bssid": @"02:11:22:33:44:55", @"networkType": @"Infrastructure" }; }
static uint64_t Miss(NSString *profile, NSTimeInterval now) {
    uint64_t generation = UINT64_MAX;
    CHECK(!PXWiFiCachedInfo(profile, now, &generation), "cache miss captures invalidation token");
    return generation;
}
static void SeedLegacySentinel(void) {
    PXWiFiInvalidateCache();
    @autoreleasepool {
        NSDictionary *packet = [[NSDictionary alloc] initWithObjectsAndKeys:[PXWiFiDeallocSentinel new], @"child", nil];
        os_unfair_lock_lock(&gWiFiCacheLock);
        cachedWifiInfo = packet; cachedProfileId = @"a"; gWiFiCacheLoadedAt = 0;
        os_unfair_lock_unlock(&gWiFiCacheLock);
    }
}
static void TestCache(void) {
    PXWiFiInvalidateCache();
    NSTimeInterval now = PXWiFiCacheTime();
    uint64_t generation = Miss(@"a", now);
    NSMutableString *ssid = [@"original" mutableCopy], *tag = [@"tag" mutableCopy], *profile = [@"a" mutableCopy];
    NSMutableArray *tags = [NSMutableArray arrayWithObject:tag];
    NSMutableDictionary *packet = [Packet(ssid) mutableCopy]; packet[@"tags"] = tags;
    NSUInteger serialized = gSerializations;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    CHECK(now == 0 && generation == 0, "RootHide has no live object-cache clock or token authority");
    CHECK(PXWiFiPublishInfo(packet, profile, NAN, UINT64_MAX) == packet && gSerializations == serialized &&
          !PXWiFiCachedInfo(profile, 0, &generation), "RootHide cache helpers cannot copy or substitute a captured view");
#else
    CHECK(isfinite(now) && now >= 0, "rootful cache clock is monotonic and available");
    now = 1000; // Deterministic boundary arithmetic, independent of host uptime.
    generation = Miss(@"a", now);
    NSDictionary *published = PXWiFiPublishInfo(packet, profile, now, generation);
    CHECK(published != packet && gSerializations == serialized + 1, "rootful cache freezes one complete plist packet");
    [ssid setString:@"changed"]; [tag setString:@"changed"]; [tags addObject:@"new"]; [profile setString:@"b"];
    CHECK([published[@"ssid"] isEqual:@"original"] && [published[@"tags"] count] == 1 && [published[@"tags"][0] isEqual:@"tag"] &&
          PXWiFiCachedInfo(@"a", now, &generation) == published && !PXWiFiCachedInfo(@"b", now, &generation),
          "nested mutable values and profile key cannot mutate the cached packet or its identity");
    CHECK(PXWiFiCachedInfo(@"a", now + 300, &generation) == published && !PXWiFiCachedInfo(@"a", now + 300.001, &generation),
          "existing inclusive 300 second TTL is preserved");
    generation = Miss(@"a", now);
    PXWiFiPublishInfo(published, @"a", now + 10, generation);
    CHECK(!PXWiFiCachedInfo(@"a", now, &generation), "negative cache age is never fresh");
    NSDictionary *oneShot = PXWiFiPublishInfo(published, @"a", NAN, generation);
    CHECK([oneShot isEqual:published] && !PXWiFiCachedInfo(@"a", now, &generation), "clock failure serves detached one shot without cache retention");

    PXWiFiInvalidateCache(); generation = Miss(@"a", PXWiFiCacheTime()); PXWiFiInvalidateCache();
    CHECK(!PXWiFiPublishInfo(published, @"a", PXWiFiCacheTime(), generation) && !cachedWifiInfo,
          "invalidated loader cannot resurrect an old packet");
    uint64_t current = Miss(@"a", PXWiFiCacheTime());
    NSDictionary *winner = PXWiFiPublishInfo(Packet(@"winner"), @"a", PXWiFiCacheTime(), current);
    CHECK(PXWiFiPublishInfo(published, @"a", PXWiFiCacheTime(), generation) == winner,
          "invalidated loader may reuse only a fresh matching-profile winner");
    CHECK(!PXWiFiPublishInfo(published, @"b", PXWiFiCacheTime(), generation) && cachedWifiInfo == winner,
          "stale other-profile loader never returns or overwrites a different-profile winner");
    NSTimeInterval expired = PXWiFiCacheTime() - 301;
    os_unfair_lock_lock(&gWiFiCacheLock); gWiFiCacheLoadedAt = expired; os_unfair_lock_unlock(&gWiFiCacheLock);
    CHECK(!PXWiFiPublishInfo(published, @"a", PXWiFiCacheTime(), generation), "stale publisher cannot reuse an expired winner");
    PXWiFiInvalidateCache(); generation = Miss(@"a", PXWiFiCacheTime());
    gDuringFreeze = ^{ PXWiFiInvalidateCache(); };
    CHECK(!PXWiFiPublishInfo(Packet(@"old"), @"a", PXWiFiCacheTime(), generation) && !cachedWifiInfo,
          "invalidation inside serialization revokes old publication without a recursive lock");
    generation = Miss(@"a", PXWiFiCacheTime());
    winner = PXWiFiPublishInfo(Packet(@"keep"), @"a", PXWiFiCacheTime(), generation);
    gThrowCodec = YES;
    CHECK(!PXWiFiPublishInfo(Packet(@"throws"), @"a", PXWiFiCacheTime(), generation) && cachedWifiInfo == winner,
          "failed freeze never replaces an already valid cache packet");
    gThrowCodec = NO;
    NSMutableDictionary *bad = [Packet(@"bad") mutableCopy]; bad[@"extra"] = [NSObject new];
    CHECK(!PXWiFiPublishInfo(bad, @"a", PXWiFiCacheTime(), generation) && cachedWifiInfo == winner,
          "unsupported non-plist graph is not shallow retained");
#endif
    for (id bad in @[NSNull.null, @[], @{ @"ssid": @1, @"bssid": @"mac" }, @{ @"ssid": @"name", @"bssid": NSNull.null }]) {
        CHECK(!PXWiFiInfoHasIdentity(bad), "WiFi identity requires a dictionary and two string fields");
    }
    NSDictionary *empty = @{ @"ssid": @"", @"bssid": @"" };
    CHECK(PXWiFiInfoHasIdentity(empty), "type guard preserves empty-string policy and does not impose new identity validation");
    NSUInteger released = gDeallocations;
    SeedLegacySentinel(); PXWiFiInvalidateCache();
    CHECK(gDeallocations == released + 1 && !cachedWifiInfo && !cachedProfileId,
          "cache invalidation drops owned graph only after unlock so dealloc can reenter");
#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    SeedLegacySentinel(); released = gDeallocations;
    NSDictionary *replacement = PXWiFiPublishInfo(Packet(@"replace"), @"a", PXWiFiCacheTime(), gWiFiCacheGeneration);
    CHECK(replacement && !cachedWifiInfo && gDeallocations == released + 1,
          "replacement return survives graph deallocation that reenters invalidation outside lock");
    SeedLegacySentinel(); released = gDeallocations;
    CHECK(!PXWiFiCachedInfo(@"a", -1, &generation) && gDeallocations == released + 1,
          "expiration also releases old graph after unlock");
#endif
}

static void TestCacheExceptionalLifetime(void) {
    __weak id weakRecord = nil; BOOL threw = NO;
    @autoreleasepool {
        id record = [PXWiFiThrowingRecord new]; weakRecord = record;
        @try { (void)PXWiFiInfoHasIdentity(record); }
        @catch (NSException *exception) { threw = [exception.name isEqual:@"fixture.record"]; }
        record = nil;
    }
    CHECK(threw && !weakRecord, "WiFi identity predicate propagates accessor exceptions without retaining its input");
#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    PXWiFiInvalidateCache(); __weak id weakProfile = nil, weakSnapshot = nil;
    @autoreleasepool {
        id profile = [PXWiFiThrowingProfile new], snapshot = [Packet(@"comparison") mutableCopy];
        weakProfile = profile; weakSnapshot = snapshot;
        NSTimeInterval now = PXWiFiCacheTime();
        os_unfair_lock_lock(&gWiFiCacheLock);
        cachedWifiInfo = snapshot; cachedProfileId = profile; gWiFiCacheLoadedAt = now;
        os_unfair_lock_unlock(&gWiFiCacheLock);
        uint64_t generation = 0; threw = NO;
        @try { (void)PXWiFiCachedInfo(@"a", now, &generation); }
        @catch (NSException *exception) { threw = [exception.name isEqual:@"fixture.profile"]; }
        CHECK(threw, "WiFi cache comparison exceptions propagate after unlocking");
        PXWiFiInvalidateCache(); profile = nil; snapshot = nil;
    }
    CHECK(!weakProfile && !weakSnapshot, "WiFi cache comparison unwinding releases its retained ID and snapshot");
    for (NSUInteger fault = 0; fault < 2; fault++) {
        PXWiFiInvalidateCache(); gEncodedData = nil; gDecodedRoot = nil;
        @autoreleasepool {
            gThrowDecode = fault == 0; gDecodedFault = fault == 1;
            uint64_t generation = Miss(@"a", PXWiFiCacheTime());
            CHECK(!PXWiFiPublishInfo(Packet(@"failed freeze"), @"a", PXWiFiCacheTime(), generation) && !cachedWifiInfo,
                  "WiFi decode or decoded-predicate failure never publishes a partial packet");
            gThrowDecode = gDecodedFault = NO;
        }
        CHECK(!gEncodedData && !gDecodedRoot,
              "WiFi failed freeze releases encoded data and decoded graph after pool drain");
    }
#endif
}

// The exact reader runs against controlled file/provider/snapshot collaborators.
// No filesystem, jailbreak framework or real singleton is used by this fixture.
static NSMutableDictionary *gFiles;
static void (^gDuringRead)(void);
static NSString *gActiveID;
static id gManagerInfo, gGenerated;
static NSString *gManagerID;
static NSUInteger gResolverCalls;
static BOOL gResolverFails, gThrowManagerRead;
static __weak id gLastManager;
static Class gProviderClass;
@interface WiFiManager : NSObject
+ (instancetype)sharedManager;
- (NSDictionary *)currentWiFiInfo;
- (NSDictionary *)generateWiFiInfo;
- (NSDictionary *)cachedWiFiInfoForProfileID:(NSString *)profileID;
@end
@implementation WiFiManager
+ (instancetype)sharedManager { gFactoryCalls++; id manager = [self new]; gLastManager = manager; return manager; }
- (NSDictionary *)currentWiFiInfo { gManagerReads++; return gManagerInfo; }
- (NSDictionary *)generateWiFiInfo { gGenerations++; return gGenerated; }
- (NSDictionary *)cachedWiFiInfoForProfileID:(NSString * __unsafe_unretained)profileID {
    gManagerReads++;
    if (gThrowManagerRead) [NSException raise:@"fixture.manager" format:@"manager read failed"];
    return [gManagerID isEqual:profileID] ? gManagerInfo : nil;
}
@end
@interface PXLegacyWiFiProvider : NSObject
+ (instancetype)sharedManager;
@end
@implementation PXLegacyWiFiProvider
+ (instancetype)sharedManager { gFactoryCalls++; return [self new]; }
@end
// Reader wiring collaborator only. Real lifecycle/source behavior is exercised
// by the artifact-preparation binary linked with PXWiFiHookResolver.m.
NSDictionary *PXResolveHookWiFiInfo(NSString * __unsafe_unretained profileID, PXWiFiHookCacheReader __unsafe_unretained reader, NSError **error) {
    gResolverCalls++;
    if (gResolverFails || ![profileID isEqual:gActiveID]) return nil;
    NSError *failure = nil;
    id cached = nil;
    @try {
        cached = reader ? reader(profileID, &failure) : nil;
        if (failure) { if (error) *error = failure; return nil; }
        return PXWiFiInfoHasIdentity(cached) ? cached : gGenerated;
    } @catch (__unused NSException *exception) { return nil; }
      @finally { cached = nil; failure = nil; }
}
@interface PXWiFiFileManager : NSObject
- (BOOL)fileExistsAtPath:(NSString *)path;
- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)create attributes:(NSDictionary *)attributes error:(NSError **)error;
@end
@implementation PXWiFiFileManager
- (BOOL)fileExistsAtPath:(NSString *)path { (void)path; return YES; }
- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)create attributes:(NSDictionary *)attributes error:(NSError **)error {
    (void)path; (void)create; (void)attributes; (void)error; return YES;
}
@end
@interface NSFileManager (PXWiFiFixture)
+ (id)PXWiFiFixtureDefaultManager;
@end
@implementation NSFileManager (PXWiFiFixture)
+ (id)PXWiFiFixtureDefaultManager { gFileManagers++; return [PXWiFiFileManager new]; }
@end
@interface NSDictionary (PXWiFiFixture)
+ (instancetype)PXWiFiFixtureDictionaryWithContentsOfFile:(NSString *)path;
- (BOOL)PXWiFiFixtureWriteToFile:(NSString *)path atomically:(BOOL)atomic;
@end
@implementation NSDictionary (PXWiFiFixture)
+ (instancetype)PXWiFiFixtureDictionaryWithContentsOfFile:(NSString * __unsafe_unretained)path {
    gReads++; id value = gFiles[path];
    void (^callback)(void) = gDuringRead; gDuringRead = nil;
    @try {
        if (callback) callback();
        return [self isSubclassOfClass:NSMutableDictionary.class] ? [value mutableCopy] : value;
    } @finally { callback = nil; value = nil; }
}
- (BOOL)PXWiFiFixtureWriteToFile:(NSString *)path atomically:(BOOL)atomic { (void)atomic; gWrites++; gFiles[path] = [self copy]; return YES; }
@end
@interface PXRuntimeReadSnapshot : NSObject
@property (nonatomic, strong) NSDictionary *deviceIDs;
@property (nonatomic, strong) NSDictionary *artifacts;
- (NSDictionary *)profileArtifact:(NSString *)key;
@end
@implementation PXRuntimeReadSnapshot
- (NSDictionary *)profileArtifact:(NSString *)key { return self.artifacts[key]; }
@end
static PXRuntimeReadSnapshot *gView;
static PXRuntimeReadSnapshot *PXCaptureRuntimeSnapshot(void) { gCaptures++; return gView; }
static NSString *PXActiveProfileID(void) { gSelections++; return gActiveID; }
static NSString *PXProfileIdentityPath(NSString *profile) { gIdentityPaths++; return profile.length ? [@"/fixture/" stringByAppendingPathComponent:[profile stringByAppendingPathComponent:@"identity"]] : nil; }
static Class PXWiFiFixtureClassFromString(NSString *name) { (void)name; gClassLookups++; return gProviderClass; }
#define NSClassFromString PXWiFiFixtureClassFromString
#define dictionaryWithContentsOfFile PXWiFiFixtureDictionaryWithContentsOfFile
#define writeToFile PXWiFiFixtureWriteToFile
#define defaultManager PXWiFiFixtureDefaultManager
#include "PXWiFiHookReader.inc"
#undef defaultManager
#undef writeToFile
#undef dictionaryWithContentsOfFile
#undef NSClassFromString

static void ResetReader(void) {
    PXWiFiInvalidateCache(); gFiles = [NSMutableDictionary dictionary]; gActiveID = @"a";
    gManagerInfo = nil; gGenerated = nil; gProviderClass = WiFiManager.class;
    gManagerID = @"a"; gResolverCalls = 0; gResolverFails = gThrowManagerRead = NO; gLastManager = nil; gIdentityPaths = 0;
    gDuringRead = nil;
    gView = [PXRuntimeReadSnapshot new]; gView.deviceIDs = @{}; gView.artifacts = @{};
    gReads = gWrites = gFactoryCalls = gClassLookups = gManagerReads = gGenerations = gFileManagers = gSelections = gCaptures = 0;
}
static void TestReader(void) {
    ResetReader();
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    NSDictionary *artifact = Packet(@"captured"); gView.artifacts = @{ @"wifiInfo": artifact };
    CHECK(getProfileWiFiInfo() == artifact && getProfileWiFiInfo() == artifact && !gReads && !gSelections && !gFactoryCalls && !gSerializations,
          "RootHide reads and memoizes captured artifact without live files singleton or object cache codec");
    ResetReader(); gView.deviceIDs = @{ @"SSID": @"captured-ids", @"BSSID": @"mac" };
    CHECK([getProfileWiFiInfo()[@"ssid"] isEqual:@"captured-ids"] && !gReads && !gWrites && !gClassLookups,
          "RootHide keeps captured device-ID fallback authority");
    ResetReader();
    CHECK(!getProfileWiFiInfo() && !getProfileWiFiInfo() && !gReads && !gWrites && !gFactoryCalls,
          "missing captured WiFi stays missing without live repair or generation");
#else
    NSString *wifiPath = @"/fixture/a/identity/wifi_info.plist", *idsPath = @"/fixture/a/identity/device_ids.plist";
    gFiles[wifiPath] = Packet(@"file");
    NSDictionary *result = getProfileWiFiInfo(); NSUInteger reads = gReads;
    CHECK([result[@"ssid"] isEqual:@"file"] && getProfileWiFiInfo() == result && gReads == reads && !gFactoryCalls && !gClassLookups && !gFileManagers && !gWrites && gIdentityPaths == 1 && gSelections == 2,
          "valid file and warm cache avoid singleton class lookup file-manager setup and repeat artifact reads");
    NSUInteger paths = gIdentityPaths;
    for (NSUInteger iteration = 0; iteration < 100; iteration++) (void)getProfileWiFiInfo();
    CHECK(gIdentityPaths == paths && gReads == reads && gSelections == 102,
          "warm WiFi reader keeps active-selection checks but constructs no artifact identity paths");
    ResetReader(); gFiles[wifiPath] = Packet(@"old-read");
    gDuringRead = ^{ PXWiFiInvalidateCache(); };
    CHECK(!getProfileWiFiInfo() && !cachedWifiInfo && !gFactoryCalls && !gWrites,
          "reader forwards captured epoch so notification during file read revokes its old publication");
    CHECK([getProfileWiFiInfo()[@"ssid"] isEqual:@"old-read"], "subsequent stable reader can refill after invalidation");
    ResetReader(); gFiles[wifiPath] = Packet(@"a-old"); gFiles[@"/fixture/b/identity/wifi_info.plist"] = Packet(@"b-new");
    gDuringRead = ^{ PXWiFiInvalidateCache(); gActiveID = @"b"; (void)getProfileWiFiInfo(); };
    CHECK(!getProfileWiFiInfo() && [cachedProfileId isEqual:@"b"] && [cachedWifiInfo[@"ssid"] isEqual:@"b-new"],
          "profile change and nested newer publication cannot leak B cache into the in-flight A reader");
    ResetReader(); gFiles[wifiPath] = @{ @"ssid": @7, @"bssid": @"invalid" }; gFiles[idsPath] = @{ @"SSID": @"ids", @"BSSID": @"mac" };
    CHECK([getProfileWiFiInfo()[@"ssid"] isEqual:@"ids"] && !gFactoryCalls && !gWrites && gIdentityPaths == 1,
          "malformed artifact identity falls through to typed canonical device IDs");
    ResetReader(); gFiles[idsPath] = @{ @"SSID": @[], @"BSSID": @"bad", @"WiFi": @"  Parsed Name  (02:AA:BB:CC:DD:EE)" };
    result = getProfileWiFiInfo();
    CHECK([result[@"ssid"] isEqual:@"Parsed Name"] && [result[@"bssid"] isEqual:@"02:AA:BB:CC:DD:EE"] && !gFactoryCalls,
          "typed pair fallback preserves legacy display parser whitespace and case policy");
    ResetReader(); gManagerInfo = Packet(@"manager");
    CHECK([getProfileWiFiInfo()[@"ssid"] isEqual:@"manager"] && gFactoryCalls == 1 && gClassLookups == 1 && gManagerReads == 1 && !gGenerations && !gWrites,
          "manager fallback is resolved once only when profile artifacts are missing");
    ResetReader(); gProviderClass = NSObject.class;
    CHECK(!getProfileWiFiInfo() && gClassLookups == 1 && !gFactoryCalls && !gWrites,
          "optional class without sharedManager is never sent an unsupported selector");
    ResetReader(); gProviderClass = PXLegacyWiFiProvider.class; gGenerated = Packet(@"must-not-generate");
    CHECK(!getProfileWiFiInfo() && gResolverCalls == 1 && gFactoryCalls == 1 && !gGenerations && !gWrites,
          "older optional provider without read-only selector fails closed without legacy generation");
    ResetReader(); gResolverFails = YES;
    CHECK(!getProfileWiFiInfo() && gResolverCalls == 1 && !gFactoryCalls && !gGenerations && !gWrites && !cachedWifiInfo,
          "owned resolver failure never falls back to legacy generation or raw writes or cache adoption");
    ResetReader(); gGenerated = Packet(@"generated");
    CHECK([getProfileWiFiInfo()[@"ssid"] isEqual:@"generated"] && gResolverCalls == 1 && !gGenerations && !gFileManagers && !gWrites,
          "hook accepts owned resolver result without repeating generation or raw file writes");
    ResetReader(); gManagerID = @"b"; gManagerInfo = Packet(@"wrong-b"); gGenerated = Packet(@"fixed-a");
    CHECK([getProfileWiFiInfo()[@"ssid"] isEqual:@"fixed-a"] && gResolverCalls == 1 && !gGenerations && !gWrites,
          "hook asks for fixed-profile read-only cache instead of a live current-profile getter");
    ResetReader(); __weak id weakRecord = nil;
    @autoreleasepool {
        id record = [PXWiFiThrowingRecord new]; weakRecord = record; gFiles[wifiPath] = record;
        BOOL threw = NO;
        @try { (void)getProfileWiFiInfo(); }
        @catch (NSException *exception) { threw = [exception.name isEqual:@"fixture.record"]; }
        CHECK(threw && !gResolverCalls && !gFactoryCalls, "WiFi artifact accessor exception retains propagation without provider retry");
        [gFiles removeObjectForKey:wifiPath]; record = nil;
    }
    CHECK(!weakRecord, "WiFi reader unwinding releases its retained artifact root after pool drain");
    ResetReader(); gThrowManagerRead = YES;
    @autoreleasepool {
        CHECK(!getProfileWiFiInfo() && gResolverCalls == 1 && gFactoryCalls == 1 && gManagerReads == 1,
              "WiFi provider failure returns unavailable without repeating lookup or generation");
    }
    CHECK(!gLastManager, "WiFi cache-reader callback releases its manager on exceptional exit");
    ResetReader(); gActiveID = nil;
    CHECK(!getProfileWiFiInfo() && !gReads && !gFactoryCalls && !gWrites, "missing profile exits before artifacts or optional providers");
#endif
}
int main(void) {
    @autoreleasepool {
        @try { TestCache(); TestCacheExceptionalLifetime(); TestReader(); }
        @catch (NSException *exception) { gFailures++; fprintf(stderr, "FAIL: unexpected WiFi hook fixture exception: %s\n", exception.description.UTF8String); }
        PXWiFiInvalidateCache();
        printf("WiFi hook cache/reader: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
