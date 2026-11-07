#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <os/lock.h>
#import <dispatch/dispatch.h>
#include <stdint.h>
#include <stdbool.h>
#include <math.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>

static NSUInteger gChecks, gFailures, gClockCalls, gSettingsReads, gIdentityReads, gLookupCalls, gDeallocations;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PX_RUNTIME_READ_OPERATION do {} while (0)
static os_unfair_lock gNetworkCacheLock = OS_UNFAIR_LOCK_INIT;
static time_t gSeconds = 1000;
static long gNanoseconds;
static BOOL gClockUnavailable;
static int PXFixtureClock(clockid_t clock, struct timespec *instant) {
    gClockCalls++;
    if (gClockUnavailable || clock != CLOCK_MONOTONIC) return -1;
    instant->tv_sec = gSeconds; instant->tv_nsec = gNanoseconds;
    return 0;
}
#define clock_gettime PXFixtureClock
#include "PXNetworkSignalState.inc"
#undef clock_gettime

@interface PXRuntimeReadSnapshot : NSObject
@property (nonatomic, copy) NSDictionary *securitySettings;
@property (nonatomic, copy) NSDictionary *deviceIDs;
@property (nonatomic, copy) NSDictionary *artifacts;
- (NSDictionary *)profileArtifact:(NSString *)key;
@end
@implementation PXRuntimeReadSnapshot
- (NSDictionary *)profileArtifact:(NSString *)key { return self.artifacts[key]; }
@end
static PXRuntimeReadSnapshot *gView;
static NSDictionary *gSettings;
static NSString *gIdentity;
static void (*gDuringSettings)(void), (*gDuringLookup)(void), (*gDuringIdentity)(void);
static PXRuntimeReadSnapshot *PXCaptureRuntimeSnapshot(void) { return gView; }
static NSString *getProfileIdentityPath(void) {
    gIdentityReads++;
    void (*callback)(void) = gDuringIdentity; gDuringIdentity = NULL;
    if (callback) callback();
    return gIdentity;
}
#include "PXNetworkReadBool.inc"
#include "PXNetworkReadCacheState.inc"
#include "PXNetworkTypedReads.inc"
static NSDictionary *getTargetRegionPinnedOverrides(void);
static NSDictionary *PXNetworkSecuritySettings(void) {
    NSDictionary *result = nil;
    @try {
        gSettingsReads++;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        result = gView.securitySettings;
#else
        result = gSettings;
#endif
        void (*callback)(void) = gDuringSettings; gDuringSettings = NULL;
        if (callback) callback();
        return PXNetworkDictionary(result) ?: @{};
    } @finally { result = nil; }
}
static NSString *PXCarrierNameForMCCMNC(NSString *mcc, NSString *mnc) {
    (void)mcc; (void)mnc; gLookupCalls++;
    void (*callback)(void) = gDuringLookup; gDuringLookup = NULL;
    if (callback) callback();
    return @"Fixture DB Carrier";
}
#include "PXNetworkCarrierRead.inc"
#include "PXNetworkConsumerReads.inc"

static void Configure(NSDictionary *settings) {
    gSettings = settings;
    gView = [PXRuntimeReadSnapshot new];
    gView.securitySettings = settings;
}
static void Reset(void) {
    PXNetworkInvalidateCaches(); Configure(@{});
    gDuringSettings = NULL; gDuringLookup = NULL; gDuringIdentity = NULL;
    gSeconds = 1000; gNanoseconds = 0; gClockUnavailable = NO;
    gSettingsReads = 0; gClockCalls = 0; gIdentityReads = 0; gLookupCalls = 0;
}
static NSDictionary *Settings(NSString *name, NSString *iso, NSInteger mode) {
    return @{ @"targetRegionFollowsIPEnabled": @YES,
              @"targetRegionPinnedCarrierName": name, @"targetRegionPinnedCarrierMCC": @"001",
              @"targetRegionPinnedCarrierMNC": @"02", @"targetRegionPinnedCarrierISO": iso,
              @"networkDataSpoofEnabled": @YES, @"networkConnectionType": @(mode) };
}
static double TTL(PXNetworkReadCacheKind kind) { return kind == PXNetworkReadMode || kind == PXNetworkReadPinned ? 5 : 60; }
static uint64_t Revision(PXNetworkReadCacheKind kind) {
    os_unfair_lock_lock(&gNetworkCacheLock);
    uint64_t revision = gNetworkReadStamps[kind].revision;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    return revision;
}
static id Cached(PXNetworkReadCacheKind kind, BOOL *hit) {
    uint64_t revision;
    return PXNetworkReadCached(kind, PXNetworkSignalNow(), TTL(kind), &revision, hit);
}
static id ReadConsumer(PXNetworkReadCacheKind kind) {
    switch (kind) {
        case PXNetworkReadMode: return @(getNetworkConnectionType());
        case PXNetworkReadISO: return getCurrentISOCountryCode();
        case PXNetworkReadPinned: return getTargetRegionPinnedOverrides();
        case PXNetworkReadCarrier: return getCarrierDetailsFromProfile();
        default: return nil;
    }
}
static void TestPublicationUnits(void) {
    for (PXNetworkReadCacheKind kind = 0; kind < PXNetworkReadCacheCount; kind++) {
        Reset(); BOOL hit = YES; uint64_t revision = Revision(kind);
        CHECK(Cached(kind, &hit) == nil && !hit, "cold read captures a miss");
        CHECK(PXNetworkPublishReadCache(kind, @"old", 1000, revision), "matching revision publishes");
        CHECK([Cached(kind, &hit) isEqual:@"old"] && hit, "published object is ready with its timestamp");
        gSeconds = 1000 + (time_t)TTL(kind) - 1; gNanoseconds = 999000000;
        CHECK([Cached(kind, &hit) isEqual:@"old"] && hit, "TTL includes just before the deadline");
        gSeconds++; gNanoseconds = 0;
        CHECK(Cached(kind, &hit) == nil && !hit, "TTL excludes the exact deadline");
        revision = Revision(kind);
        PXNetworkInvalidateCaches();
        CHECK(!PXNetworkPublishReadCache(kind, @"revoked", 1000, revision), "notification revokes an in-flight candidate");
        uint64_t newer = Revision(kind);
        CHECK(PXNetworkPublishReadCache(kind, @"new", (double)gSeconds, newer), "newer candidate publishes after invalidation");
        CHECK(!PXNetworkPublishReadCache(kind, @"old", (double)gSeconds, revision), "older candidate cannot overwrite a newer root");
        CHECK([Cached(kind, &hit) isEqual:@"new"] && hit, "newer publication remains authoritative");
        revision = Revision(kind); gClockUnavailable = YES;
        CHECK(PXNetworkPublishReadCache(kind, @"clockless", NAN, revision), "source result can finish without a usable clock");
        CHECK(Cached(kind, &hit) == nil && !hit, "clock failure never makes an immortal cached result");
        gClockUnavailable = NO; gSeconds = 900; revision = Revision(kind);
        CHECK(PXNetworkPublishReadCache(kind, @"recovered", 900, revision), "clock recovery accepts a new baseline");
        gSeconds = 899;
        CHECK(Cached(kind, &hit) == nil && !hit, "negative monotonic age never counts as a hit");
    }
    Reset(); uint64_t revision = Revision(PXNetworkReadPinned); BOOL hit = NO;
    CHECK(PXNetworkPublishReadCache(PXNetworkReadPinned, nil, 1000, revision), "nil pinned result is publishable");
    CHECK(Cached(PXNetworkReadPinned, &hit) == nil && hit, "negative pinned cache is distinct from a miss");
}
@interface PXReentrantCacheRoot : NSObject
@end
@implementation PXReentrantCacheRoot
- (void)dealloc {
    gDeallocations++;
    BOOL hit; uint64_t revision;
    (void)PXNetworkReadCached(PXNetworkReadISO, 1000, 60, &revision, &hit);
}
@end
static void SeedRoot(PXNetworkReadCacheKind kind) {
    @autoreleasepool {
        PXReentrantCacheRoot *root = [PXReentrantCacheRoot new];
        CHECK(PXNetworkPublishReadCache(kind, root, 1000, Revision(kind)), "sentinel root seeded");
        root = nil;
    }
}
static void TestRetiredRoots(void) {
    Reset(); NSUInteger count = gDeallocations;
    for (PXNetworkReadCacheKind kind = 0; kind < PXNetworkReadCacheCount; kind++) SeedRoot(kind);
    CHECK(gDeallocations == count, "cache owns all four sentinel roots");
    PXNetworkInvalidateCaches();
    CHECK(gDeallocations == count + 4, "all retired roots dealloc after invalidation unlock and may reenter");
    count = gDeallocations; SeedRoot(PXNetworkReadISO);
    CHECK(PXNetworkPublishReadCache(PXNetworkReadISO, @"replacement", 1000, Revision(PXNetworkReadISO)), "replacement publishes before old destructor");
    CHECK(gDeallocations == count + 1, "replacement releases prior object outside the lock");
    SeedRoot(PXNetworkReadISO); count = gDeallocations;
    @autoreleasepool {
        BOOL hit; id held = Cached(PXNetworkReadISO, &hit);
        PXNetworkInvalidateCaches();
        CHECK(hit && held != nil && gDeallocations == count, "reader retains a retired root through invalidation");
        held = nil;
    }
    CHECK(gDeallocations == count + 1, "retired root releases when its last reader finishes");
}
static void TestRealPublicationInterleaving(void) {
    for (PXNetworkReadCacheKind kind = 0; kind < PXNetworkReadCacheCount; kind++) {
        Reset();
        dispatch_semaphore_t entered = dispatch_semaphore_create(0), finish = dispatch_semaphore_create(0), done = dispatch_semaphore_create(0);
        uint64_t oldRevision = Revision(kind);
        __block BOOL oldPublished = YES;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            @autoreleasepool {
                dispatch_semaphore_signal(entered);
                dispatch_semaphore_wait(finish, DISPATCH_TIME_FOREVER);
                oldPublished = PXNetworkPublishReadCache(kind, @"old", 1000, oldRevision);
            }
            dispatch_semaphore_signal(done);
        });
        long waited = dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
        CHECK(waited == 0, "old cache builder paused before publication");
        if (waited) { dispatch_semaphore_signal(finish); exit(1); }
        PXNetworkInvalidateCaches();
        CHECK(PXNetworkPublishReadCache(kind, @"new", 1000, Revision(kind)), "main thread publishes newer cache entry");
        dispatch_semaphore_signal(finish);
        waited = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
        CHECK(waited == 0, "old builder completed without deadlock"); if (waited) exit(1);
        BOOL hit;
        CHECK(!oldPublished && [Cached(kind, &hit) isEqual:@"new"] && hit, "older thread cannot revive data after invalidation");
    }
}
static void TestConsumerPolicies(void) {
    Reset(); Configure(Settings(@"Pinned", @"GB", NetworkConnectionTypeCellular));
    CHECK(getNetworkConnectionType() == NetworkConnectionTypeCellular && PXNetworkDataSpoofEnabledCached(), "mode and enabled are one packet");
    CHECK([getCurrentISOCountryCode() isEqual:@"gb"], "ISO keeps pinned lowercase policy");
    NSDictionary *pinned = getTargetRegionPinnedOverrides();
    CHECK([pinned[@"carrierName"] isEqual:@"Pinned"] && [pinned[@"carrierISO"] isEqual:@"GB"], "pinned packet preserves original field spelling");
    NSDictionary *carrier = getCarrierDetailsFromProfile();
    CHECK([carrier[@"carrierName"] isEqual:@"Pinned"] && [carrier[@"mobileCountryCode"] isEqual:@"001"] && [carrier[@"mobileNetworkCode"] isEqual:@"02"], "pinned carrier keeps precedence and exact code strings");
    Reset(); Configure(@{});
    CHECK(getNetworkConnectionType() == (NetworkConnectionType)-1 && !PXNetworkDataSpoofEnabledCached(), "missing enablement remains disabled");
    CHECK([getCurrentISOCountryCode() isEqual:@"us"] && getTargetRegionPinnedOverrides() == nil, "missing values retain US and no-pin defaults");
    Reset(); Configure(@{ @"networkDataSpoofEnabled": @"YES", @"networkConnectionType": @"99", @"networkISOCountryCode": @"DE" });
    CHECK(getNetworkConnectionType() == NetworkConnectionTypeAuto && [getCurrentISOCountryCode() isEqual:@"de"], "legacy scalar strings and out-of-range Auto fallback remain");
    Reset(); Configure(@{ @"networkDataSpoofEnabled": @YES, @"networkConnectionType": @[], @"targetRegionFollowsIPEnabled": @[], @"networkISOCountryCode": @19 });
    CHECK(getNetworkConnectionType() == NetworkConnectionTypeAuto && [getCurrentISOCountryCode() isEqual:@"us"] && getTargetRegionPinnedOverrides() == nil, "malformed scalar containers preserve safe defaults");
    Reset(); Configure(Settings(@"TLinkIOS branded", @"US", NetworkConnectionTypeWiFi));
    CHECK([getCarrierDetailsFromProfile()[@"carrierName"] isEqual:@"Fixture DB Carrier"] && gLookupCalls == 1, "branding fallback still uses the catalog");
    NSMutableString *name = [NSMutableString stringWithString:@"mutable"], *mcc = [NSMutableString stringWithString:@"001"], *mnc = [NSMutableString stringWithString:@"02"];
    NSDictionary *packet = PXNetworkCarrierPacket(name, mcc, mnc);
    [name appendString:@"-changed"]; [mcc appendString:@"0"]; [mnc appendString:@"0"];
    CHECK([packet[@"carrierName"] isEqual:@"mutable"] && [packet[@"mobileCountryCode"] isEqual:@"001"] && [packet[@"mobileNetworkCode"] isEqual:@"02"], "whole carrier packet freezes all three legacy copied fields");
}
static PXNetworkReadCacheKind gReadKind;
static BOOL gBuildNewer;
static id gNewerResult;
static void DuringOldProvider(void) {
    PXNetworkInvalidateCaches();
    Configure(Settings(@"New", @"CA", NetworkConnectionTypeNone));
    if (gBuildNewer) gNewerResult = ReadConsumer(gReadKind);
}
static void ThrowProvider(void) { @throw [NSException exceptionWithName:@"FixtureProvider" reason:@"provider failed" userInfo:nil]; }
static void TestExceptions(void) {
    for (PXNetworkReadCacheKind kind = 0; kind < PXNetworkReadCacheCount; kind++) {
        Reset();
        __weak NSDictionary *weakSettings;
        BOOL caught = NO; uint64_t revision = Revision(kind);
        @autoreleasepool {
            Configure(Settings(@"", @"GB", NetworkConnectionTypeCellular));
            weakSettings = gSettings; gDuringSettings = ThrowProvider;
            @try { (void)ReadConsumer(kind); }
            @catch (NSException *exception) { caught = [exception.name isEqual:@"FixtureProvider"]; }
            @finally { Configure(@{}); }
        }
        CHECK(caught && weakSettings == nil && Revision(kind) == revision, "provider exception releases retained settings and leaves revision unclaimed");
        CHECK(ReadConsumer(kind) != nil || kind == PXNetworkReadPinned, "reader remains usable after provider exception");
        if (kind == PXNetworkReadPinned || kind == PXNetworkReadCarrier) {
            Reset(); caught = NO;
            @autoreleasepool {
                Configure(Settings(@"", @"GB", NetworkConnectionTypeCellular));
                weakSettings = gSettings; gDuringLookup = ThrowProvider;
                @try { (void)ReadConsumer(kind); }
                @catch (NSException *exception) { caught = YES; (void)exception; }
                @finally { Configure(@{}); }
            }
            CHECK(caught && weakSettings == nil, "nested catalog exception clears pinned carrier and captured-view roots");
        }
    }
}
#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
static void WriteCarrier(NSString *name) {
    NSDictionary *record = @{ @"carrierName": name, @"mcc": @"001", @"mnc": @"02" };
    CHECK([record writeToFile:[gIdentity stringByAppendingPathComponent:@"carrier_details.plist"] atomically:YES], "carrier TTL fixture stored");
}
static void SameModeProvider(void) { gNewerResult = @(getNetworkConnectionType()); }
static void TestRootfulConsumers(void) {
    Reset(); Configure(Settings(@"Same", @"GB", NetworkConnectionTypeCellular));
    gDuringSettings = SameModeProvider;
    CHECK(getNetworkConnectionType() == NetworkConnectionTypeCellular && [gNewerResult integerValue] == NetworkConnectionTypeCellular && PXNetworkDataSpoofEnabledCached(), "overlapping cold mode readers adopt their matching winner without real-value passthrough");
    Reset(); Configure(@{});
    CHECK(getTargetRegionPinnedOverrides() == nil && gSettingsReads == 1, "negative pin lookup records one provider read");
    Configure(Settings(@"New pin", @"CA", NetworkConnectionTypeWiFi));
    gSeconds = 1004; gNanoseconds = 999000000;
    CHECK(getTargetRegionPinnedOverrides() == nil && gSettingsReads == 1, "negative pin cache survives until just before five seconds");
    gSeconds = 1005; gNanoseconds = 0;
    CHECK([getTargetRegionPinnedOverrides()[@"carrierName"] isEqual:@"New pin"] && gSettingsReads == 2, "negative pin cache expires at exactly five seconds");
    for (PXNetworkReadCacheKind kind = 0; kind < PXNetworkReadCacheCount; kind++) {
        Reset();
        if (kind == PXNetworkReadCarrier) { Configure(@{}); WriteCarrier(@"Old"); }
        else Configure(Settings(@"Old", @"GB", NetworkConnectionTypeCellular));
        id first = ReadConsumer(kind); NSUInteger reads = gSettingsReads;
        if (kind == PXNetworkReadCarrier) WriteCarrier(@"New");
        else Configure(Settings(@"New", @"CA", NetworkConnectionTypeNone));
        gSeconds = 1000 + (time_t)TTL(kind) - 1; gNanoseconds = 999000000;
        id before = ReadConsumer(kind);
        CHECK([before isEqual:first], "rootful derived reader retains its configured interval");
        if (kind != PXNetworkReadCarrier) CHECK(gSettingsReads == reads, "warm independent reader avoids settings I/O");
        gSeconds++; gNanoseconds = 0;
        id after = ReadConsumer(kind);
        CHECK(![after isEqual:first], "rootful derived reader refreshes at exact TTL");
    }
    for (PXNetworkReadCacheKind kind = 0; kind < PXNetworkReadCacheCount; kind++) {
        for (int build = 0; build < 2; build++) {
            Reset(); Configure(Settings(@"Old", @"GB", NetworkConnectionTypeCellular));
            gReadKind = kind; gBuildNewer = build; gNewerResult = nil;
            gDuringSettings = DuringOldProvider;
            id oldResult = ReadConsumer(kind); BOOL hit = YES;
            id actual = Cached(kind, &hit);
            CHECK(build ? hit && [actual isEqual:gNewerResult] : !hit && actual == nil, "old source lookup cannot revive any cache after provider invalidation or a newer publication");
            CHECK(kind != PXNetworkReadMode || [oldResult integerValue] == (build ? NetworkConnectionTypeNone : -1), "revoked mode candidate adopts a current winner or discards old enablement");
            if (!build) CHECK(!PXNetworkDataSpoofEnabledCached(), "invalidation cannot leave a detached enablement bit behind");
        }
    }
}
#else
static void TestRootHideConsumers(void) {
    Reset(); Configure(Settings(@"Captured", @"GB", NetworkConnectionTypeCellular));
    NSNumber *poison = @(-1);
    gNetworkModeValue = poison; gNetworkISOValue = @"poison";
    gNetworkPinnedValue = @{ @"carrierName": @"poison" }; gNetworkCarrierValue = @{ @"carrierName": @"poison" };
    NSUInteger clocks = gClockCalls;
    for (PXNetworkReadCacheKind kind = 0; kind < PXNetworkReadCacheCount; kind++) {
        uint64_t revision = gNetworkReadStamps[kind].revision;
        id first = ReadConsumer(kind); NSUInteger reads = gSettingsReads;
        id second = ReadConsumer(kind);
        CHECK([first isEqual:second] && gSettingsReads == reads, "captured view memo skips repeat derivation");
        CHECK(gNetworkReadStamps[kind].revision == revision, "captured reader never publishes into a cross-view cache");
    }
    CHECK(gClockCalls == clocks && gIdentityReads == 0, "captured readers do not touch clock or identity filesystem providers");
    CHECK(gNetworkModeValue == poison && [gNetworkISOValue isEqual:@"poison"] && [gNetworkCarrierValue[@"carrierName"] isEqual:@"poison"], "global poison roots are ignored and left untouched");
    CHECK(getNetworkConnectionType() == NetworkConnectionTypeCellular && [getCurrentISOCountryCode() isEqual:@"gb"], "captured values win over global poison");
    PXRuntimeReadSnapshot *oldView = gView;
    Configure(Settings(@"New view", @"CA", NetworkConnectionTypeNone));
    CHECK(getNetworkConnectionType() == NetworkConnectionTypeNone && [getCurrentISOCountryCode() isEqual:@"ca"] && [getCarrierDetailsFromProfile()[@"carrierName"] isEqual:@"New view"], "new view never reuses the prior view memo");
    gView = oldView;
    CHECK(getNetworkConnectionType() == NetworkConnectionTypeCellular && [getCarrierDetailsFromProfile()[@"carrierName"] isEqual:@"Captured"], "old captured view retains its own derived values");
    Reset(); Configure(@{}); clocks = gClockCalls;
    CHECK(getTargetRegionPinnedOverrides() == nil, "captured negative pin memo starts nil");
    NSUInteger reads = gSettingsReads;
    CHECK(getTargetRegionPinnedOverrides() == nil && gSettingsReads == reads && gClockCalls == clocks, "captured negative memo skips clock and provider");
}
#endif
int main(void) {
    @autoreleasepool {
        gIdentity = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        CHECK([[NSFileManager defaultManager] createDirectoryAtPath:gIdentity withIntermediateDirectories:YES attributes:nil error:nil], "fixture identity directory created");
        @try {
            TestPublicationUnits(); TestRetiredRoots(); TestRealPublicationInterleaving();
            TestConsumerPolicies(); TestExceptions();
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
            TestRootHideConsumers();
#else
            TestRootfulConsumers();
#endif
        } @finally {
            PXNetworkInvalidateCaches();
            [[NSFileManager defaultManager] removeItemAtPath:gIdentity error:nil];
            gIdentity = nil; gView = nil; gSettings = nil; gNewerResult = nil;
        }
        printf("Network read-cache: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
    }
    return gFailures ? 1 : 0;
}
