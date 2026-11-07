#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <os/lock.h>
#import <dispatch/dispatch.h>
#include <math.h>
#include <time.h>
#include <stdint.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>

static NSUInteger gChecks, gFailures, gClockCalls, gRandomCalls, gModeReads;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PX_RUNTIME_READ_OPERATION do {} while (0)
static os_unfair_lock gNetworkCacheLock = OS_UNFAIR_LOCK_INIT;
static time_t gSeconds = 1000;
static long gNanoseconds;
static BOOL gClockUnavailable, gUseRealClock;
static int gMode = 1;
static BOOL gAutoWiFi = YES;
static uint32_t gRolls[32], gRollCount, gRollCursor, gDefaultRoll = 99;
static int gRandomAction;
static atomic_bool gPauseRandom;
static dispatch_semaphore_t gEntered, gContinue;
static int gNestedSignal;
static NSString *gNestedRadio;
static void PXFixtureAction(int action);
static int PXFixtureClock(clockid_t clock, struct timespec *ts) {
    gClockCalls++;
    if (gUseRealClock) return clock_gettime(clock, ts);
    if (gClockUnavailable || clock != CLOCK_MONOTONIC) return -1;
    ts->tv_sec = gSeconds; ts->tv_nsec = gNanoseconds;
    return 0;
}
static uint32_t PXFixtureRandom(uint32_t bound) {
    if (atomic_exchange(&gPauseRandom, false)) {
        dispatch_semaphore_signal(gEntered);
        dispatch_semaphore_wait(gContinue, DISPATCH_TIME_FOREVER);
    }
    gRandomCalls++;
    int action = gRandomAction; gRandomAction = 0;
    if (action) PXFixtureAction(action);
    uint32_t value = gRollCursor < gRollCount ? gRolls[gRollCursor++] : gDefaultRoll;
    return bound ? value % bound : 0;
}
#define clock_gettime PXFixtureClock
#include "PXNetworkSignalState.inc"
#undef clock_gettime
static NetworkConnectionType getNetworkConnectionType(void) { gModeReads++; return (NetworkConnectionType)gMode; }
static BOOL shouldUseWiFiForAutoMode(void) { return gAutoWiFi; }
#define arc4random_uniform PXFixtureRandom
#include "PXNetworkSignalWork.inc"
#undef arc4random_uniform

static void Invalidate(void) {
    os_unfair_lock_lock(&gNetworkCacheLock);
    PXNetworkInvalidateSignalCachesLocked();
    os_unfair_lock_unlock(&gNetworkCacheLock);
}
static void PXFixtureAction(int action) {
    if (action == 1) Invalidate();
    else if (action == 2) gNestedSignal = getWiFiSignalStrength();
    else if (action == 3) gNestedSignal = getCellularSignalBars();
    else if (action == 4) gNestedRadio = getCurrentCellularNetworkType();
    else if (action == 5) @throw [NSException exceptionWithName:@"FixtureRandom" reason:@"policy provider failed" userInfo:nil];
}
static void Reset(void) {
    Invalidate();
    gWiFiSignal.value = -65; gCellularSignal.value = 4;
    gSeconds = 1000; gNanoseconds = 0; gClockUnavailable = NO; gUseRealClock = NO;
    gRandomCalls = 0; gModeReads = 0; gRandomAction = 0;
    gRollCount = 0; gRollCursor = 0; gDefaultRoll = 99;
    gMode = 1; gAutoWiFi = YES;
    gNestedSignal = 0; gNestedRadio = nil;
}
static void Roll3(uint32_t a, uint32_t b, uint32_t c) {
    gRollCursor = 0; gRollCount = 3;
    gRolls[0] = a; gRolls[1] = b; gRolls[2] = c;
}
static BOOL IsLTE(NSString *value) { return [value isEqualToString:@"CTRadioAccessTechnologyLTE"]; }
static void TestClockAndIntervals(void) {
    Reset(); gUseRealClock = YES;
    CHECK(isfinite(PXNetworkSignalNow()), "adapter forwards real monotonic clock");
    gUseRealClock = NO; gNanoseconds = 250000000;
    CHECK(PXNetworkSignalNow() == 1000.25, "nanoseconds convert to seconds");
    gClockUnavailable = YES;
    CHECK(isnan(PXNetworkSignalNow()), "clock failure never creates a fresh timestamp");
    CHECK(PXNetworkSignalFresh(0, 0, YES, 30), "monotonic zero is a valid instant");
    CHECK(PXNetworkSignalFresh(1029.999, 1000, YES, 30), "signal interval includes just before 30 seconds");
    CHECK(!PXNetworkSignalFresh(1030, 1000, YES, 30), "signal interval excludes exactly 30 seconds");
    CHECK(!PXNetworkSignalFresh(999, 1000, YES, 30), "clock rollback cannot extend a cache interval");
    CHECK(!PXNetworkSignalFresh(NAN, 1000, YES, 30) && !PXNetworkSignalFresh(1000, INFINITY, YES, 30), "nonfinite timestamps miss");
    CHECK(!PXNetworkSignalFresh(1000, 1000, NO, 30), "absence of a timestamp always misses");
}
static void TestIndependentSignals(void) {
    Reset(); int wifi = getWiFiSignalStrength();
    CHECK(gRandomCalls == 2 && gWiFiSignal.hasTime && !gCellularSignal.hasTime, "WiFi updates only its own interval");
    int bars = getCellularSignalBars();
    CHECK(gRandomCalls == 3 && gCellularSignal.hasTime, "cellular still computes after a WiFi read");
    NSUInteger reads = gModeReads;
    CHECK(getWiFiSignalStrength() == wifi && getCellularSignalBars() == bars && gRandomCalls == 3 && gModeReads == reads, "warm signals skip policy and RNG");
    gSeconds = 1029; gNanoseconds = 999000000;
    CHECK(getWiFiSignalStrength() == wifi && getCellularSignalBars() == bars && gRandomCalls == 3, "both independent TTLs retain the exclusive boundary");
    gSeconds = 1030; gNanoseconds = 0;
    (void)getWiFiSignalStrength(); (void)getCellularSignalBars();
    CHECK(gRandomCalls == 6, "both signals refresh at exactly 30 seconds");
    Reset(); (void)getCellularSignalBars();
    CHECK(!gWiFiSignal.hasTime && gCellularSignal.hasTime, "reverse read order leaves WiFi interval empty");
    (void)getWiFiSignalStrength();
    CHECK(gRandomCalls == 3, "reverse read order still computes each signal once");
    int oldWiFi = gWiFiSignal.value, oldBars = gCellularSignal.value;
    uint64_t wifiRevision = gWiFiSignal.revision, barsRevision = gCellularSignal.revision;
    Invalidate();
    CHECK(gWiFiSignal.value == oldWiFi && gCellularSignal.value == oldBars && !gWiFiSignal.hasTime && !gCellularSignal.hasTime, "invalidation preserves gradual numeric values and clears both intervals");
    CHECK(gWiFiSignal.revision == wifiRevision + 1 && gCellularSignal.revision == barsRevision + 1, "invalidation revokes each signal candidate");
    for (int mode = -1; mode <= 3; mode++) {
        for (int autoWiFi = 0; autoWiFi < 2; autoWiFi++) {
            Reset(); gMode = mode; gAutoWiFi = autoWiFi;
            for (int step = 0; step < 100; step++) {
                gSeconds += 30; gDefaultRoll = (uint32_t)(step * 17);
                int previous = gWiFiSignal.value, previousBars = gCellularSignal.value;
                int next = getWiFiSignalStrength(), nextBars = getCellularSignalBars();
                CHECK(next >= -90 && next <= -40 && abs(next - previous) <= 4, "all modes preserve WiFi bounds and three-step plus jitter policy");
                CHECK(nextBars >= 1 && nextBars <= 5 && abs(nextBars - previousBars) <= 1, "all modes preserve cellular bounds and one-step policy");
            }
        }
    }
}
static void TestSignalSupersessionAndFaults(void) {
    for (int which = 0; which < 2; which++) {
        Reset(); int before = which ? gCellularSignal.value : gWiFiSignal.value;
        gRandomAction = 1;
        int value = which ? getCellularSignalBars() : getWiFiSignalStrength();
        CHECK(value == before && !(which ? gCellularSignal.hasTime : gWiFiSignal.hasTime), "invalidation during RNG prevents stale signal publication");
        gRandomAction = which ? 3 : 2;
        value = which ? getCellularSignalBars() : getWiFiSignalStrength();
        CHECK(value == gNestedSignal && (which ? gCellularSignal.hasTime : gWiFiSignal.hasTime), "newer reentrant signal candidate wins and is returned");
        Invalidate(); uint64_t revision = which ? gCellularSignal.revision : gWiFiSignal.revision;
        gRandomAction = 5; BOOL caught = NO;
        @try { if (which) (void)getCellularSignalBars(); else (void)getWiFiSignalStrength(); }
        @catch (NSException *exception) { caught = [exception.name isEqualToString:@"FixtureRandom"]; }
        CHECK(caught && (which ? gCellularSignal.revision : gWiFiSignal.revision) == revision, "throwing provider neither claims nor poisons signal publication");
        (void)(which ? getCellularSignalBars() : getWiFiSignalStrength());
        CHECK((which ? gCellularSignal.hasTime : gWiFiSignal.hasTime), "signal remains usable after provider exception");
        gClockUnavailable = YES; NSUInteger calls = gRandomCalls;
        (void)(which ? getCellularSignalBars() : getWiFiSignalStrength());
        CHECK(gRandomCalls > calls && !(which ? gCellularSignal.hasTime : gWiFiSignal.hasTime), "clock failure recomputes but never stores a fresh signal interval");
        gClockUnavailable = NO; gSeconds = 900;
        (void)(which ? getCellularSignalBars() : getWiFiSignalStrength());
        CHECK((which ? gCellularSignal.updatedAt : gWiFiSignal.updatedAt) == 900, "signal recovers onto a new monotonic baseline");
    }
}
static void TestRadio(void) {
    Reset();
    CHECK(IsLTE(getCurrentCellularNetworkType()) && gRandomCalls == 1, "initial failed radio roll retains LTE and starts interval");
    gSeconds = 1119; gNanoseconds = 999000000;
    CHECK(IsLTE(getCurrentCellularNetworkType()) && gRandomCalls == 1, "warm radio skips all RNG before 120 seconds");
    gSeconds = 1120; gNanoseconds = 0;
    CHECK(IsLTE(getCurrentCellularNetworkType()) && gRandomCalls == 2 && gNetworkRadio.changedAt == 1000, "failed 120-second roll keeps its previous timestamp");
    (void)getCurrentCellularNetworkType();
    CHECK(gRandomCalls == 3, "expired radio retries next call without another 120-second delay");
    Roll3(0, 0, 0);
    CHECK([getCurrentCellularNetworkType() isEqualToString:@"CTRadioAccessTechnologyNRNSA"] && gNetworkRadio.changedAt == 1120, "matching probability and 70 percent branch selects NRNSA");
    Invalidate(); CHECK(IsLTE(getCurrentCellularNetworkType()), "invalidation restores legacy LTE baseline");
    Reset(); Roll3(0, 0, 99);
    CHECK([getCurrentCellularNetworkType() isEqualToString:@"CTRadioAccessTechnologyNR"], "remaining successful technology branch selects NR");
    for (int bars = 1; bars <= 5; bars++) {
        int threshold[] = {0, 5, 15, 40, 65, 85};
        Reset(); gCellularSignal.value = bars; Roll3(0, (uint32_t)threshold[bars] - 1, 0);
        CHECK(!IsLTE(getCurrentCellularNetworkType()), "radio keeps existing per-bar probability just below threshold");
        Reset(); gCellularSignal.value = bars; Roll3(0, (uint32_t)threshold[bars], 0);
        CHECK(IsLTE(getCurrentCellularNetworkType()), "radio probability threshold remains exclusive");
    }
    Reset(); gRandomAction = 1; Roll3(0, 0, 0);
    CHECK(IsLTE(getCurrentCellularNetworkType()) && !gNetworkRadio.hasTime, "invalidation rejects an in-flight radio candidate");
    Reset(); gRandomAction = 4;
    NSString *value = getCurrentCellularNetworkType();
    CHECK([value isEqual:gNestedRadio] && gNetworkRadio.revision > 0, "newer reentrant radio candidate wins");
    Reset(); gRandomAction = 5; BOOL caught = NO;
    @try { (void)getCurrentCellularNetworkType(); } @catch (NSException *exception) { caught = YES; (void)exception; }
    CHECK(caught && !gNetworkRadio.hasTime && IsLTE(getCurrentCellularNetworkType()), "radio exception leaves lock and cache reusable");
    gSeconds = 900; (void)getCurrentCellularNetworkType();
    CHECK(gNetworkRadio.changedAt == 900 && gNetworkRadio.hasTime, "radio clock rollback starts a valid new baseline");
    gClockUnavailable = YES; (void)getCurrentCellularNetworkType();
    CHECK(!gNetworkRadio.hasTime, "radio clock failure does not retain a fresh interval");
}
static void TestRealThreadInterleaving(void) {
    // The first background RNG waits outside the production lock. Main publishes
    // a newer result, then the older reader must return that result unchanged.
    for (int which = 0; which < 3; which++) {
        Reset();
        gEntered = dispatch_semaphore_create(0); gContinue = dispatch_semaphore_create(0);
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        atomic_store(&gPauseRandom, true);
        __block int observed = 0; __block NSString *observedRadio;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            @autoreleasepool {
                if (which == 0) observed = getWiFiSignalStrength();
                else if (which == 1) observed = getCellularSignalBars();
                else observedRadio = getCurrentCellularNetworkType();
            }
            dispatch_semaphore_signal(done);
        });
        long wait = dispatch_semaphore_wait(gEntered, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
        CHECK(wait == 0, "background reader reached policy work outside lock");
        if (wait != 0) { dispatch_semaphore_signal(gContinue); exit(1); }
        int expected = 0; NSString *expectedRadio = nil;
        if (which == 0) expected = getWiFiSignalStrength();
        else if (which == 1) expected = getCellularSignalBars();
        else expectedRadio = getCurrentCellularNetworkType();
        uint64_t revision = which == 0 ? gWiFiSignal.revision : which == 1 ? gCellularSignal.revision : gNetworkRadio.revision;
        dispatch_semaphore_signal(gContinue);
        wait = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
        CHECK(wait == 0, "background reader completed without lock contention deadlock");
        if (wait != 0) exit(1);
        CHECK(which == 2 ? [observedRadio isEqual:expectedRadio] : observed == expected, "older thread returns the winning cache value");
        CHECK(revision == (which == 0 ? gWiFiSignal.revision : which == 1 ? gCellularSignal.revision : gNetworkRadio.revision), "older thread cannot republish over the newer revision");
    }
}

// Typed readers are exact extractions. Their external identity/snapshot providers
// are controlled here; scope admission/bootstrap and Darwin transport are not.
@interface PXRuntimeReadSnapshot : NSObject
@property (nonatomic, copy) NSDictionary *deviceIDs;
@property (nonatomic, copy) NSDictionary *artifacts;
- (NSDictionary *)profileArtifact:(NSString *)key;
@end
@implementation PXRuntimeReadSnapshot
- (NSDictionary *)profileArtifact:(NSString *)key { return self.artifacts[key]; }
@end
static PXRuntimeReadSnapshot *gView;
static NSString *gIdentity;
static NSUInteger gIdentityReads;
static PXRuntimeReadSnapshot * __attribute__((unused)) PXCaptureRuntimeSnapshot(void) { return gView; }
static NSString *getProfileIdentityPath(void) { gIdentityReads++; return gIdentity; }
#include "PXNetworkTypedReads.inc"
#include "PXNetworkReadBool.inc"
static NSDictionary *gPinned, *gSettings;
static NSDictionary *PXNetworkSecuritySettings(void) { return gSettings; }
static NSDictionary *getTargetRegionPinnedOverrides(void) { return gPinned; }
static NSString *PXCarrierNameForMCCMNC(NSString *mcc, NSString *mnc) { (void)mcc; (void)mnc; return @"Fixture DB Carrier"; }
#include "PXNetworkCarrierRead.inc"
static void ClearCarrier(void) {
    cachedCarrierName = nil; cachedMobileCountryCode = nil; cachedMobileNetworkCode = nil;
    carrierDetailsCacheTimestamp = nil; gPinned = nil;
    gView = [PXRuntimeReadSnapshot new];
}
static void WritePlist(id value, NSString *file) {
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:value format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    CHECK(data != nil && [data writeToFile:[gIdentity stringByAppendingPathComponent:file] atomically:YES], "typed-reader fixture plist stored");
}
#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
@interface PXThrowingIdentity : NSObject
@property (nonatomic, copy) NSString *directory;
@property (nonatomic) NSUInteger failAt, calls;
- (NSUInteger)length;
- (NSString *)stringByAppendingPathComponent:(NSString *)component;
@end
@implementation PXThrowingIdentity
- (NSUInteger)length { return self.directory.length; }
- (NSString *)stringByAppendingPathComponent:(NSString *)component {
    self.calls++;
    if (self.calls == self.failAt) @throw [NSException exceptionWithName:@"FixturePath" reason:@"path boundary failed" userInfo:nil];
    return [self.directory stringByAppendingPathComponent:component];
}
@end
static void TestIdentityExceptionCleanup(void) {
    NSString *directory = gIdentity;
    for (NSUInteger fault = 1; fault <= 3; fault++) {
        __weak PXThrowingIdentity *weakOwner;
        BOOL caught = NO;
        NSUInteger calls = 0;
        @autoreleasepool {
            PXThrowingIdentity *owner = [PXThrowingIdentity new];
            owner.directory = directory; owner.failAt = fault;
            weakOwner = owner; gIdentity = (id)owner; owner = nil;
            ClearCarrier();
            @try { (void)getCarrierDetailsFromProfile(); }
            @catch (NSException *exception) { caught = [exception.name isEqual:@"FixturePath"]; }
            @finally { calls = [(PXThrowingIdentity *)(id)gIdentity calls]; gIdentity = directory; }
        }
        CHECK(caught && calls == fault && weakOwner == nil, "fixed-identity helper and caller release path owner on each exceptional read boundary");
    }
}
#endif

static void TestTypedReads(void) {
    CHECK(PXNetworkDictionary(@[]) == nil && PXNetworkDictionary(NSNull.null) == nil && PXNetworkString(@17) == nil, "malformed dictionary and string fields fail closed");
    CHECK(PXRuntimeReadBool(@YES) && PXRuntimeReadBool(@"YES") && !PXRuntimeReadBool(NSNull.null) && !PXRuntimeReadBool(@[]) && !PXRuntimeReadBool(@{}), "typed bool retains NSNumber and NSString compatibility");
    gSettings = @{ @"targetRegionFollowsIPEnabled": NSNull.null, @"fullSpoofTestModeEnabled": @[] };
    CHECK(!shouldForceCarrierSpoof(), "actual force-carrier reader rejects malformed toggle containers");
    gSettings = @{ @"targetRegionFollowsIPEnabled": @"YES" };
    CHECK(shouldForceCarrierSpoof(), "actual force-carrier reader retains string enablement");
    gSettings = @{ @"fullSpoofTestModeEnabled": @YES };
    CHECK(shouldForceCarrierSpoof(), "actual force-carrier reader retains full-test numeric enablement");
    gSettings = (id)@[];
    CHECK(!shouldForceCarrierSpoof(), "actual force-carrier reader rejects malformed settings root");
    gSettings = nil;
    NSDictionary *carrier = @{ @"CarrierName": @"Legacy", @"CarrierMCC": @"001", @"CarrierMNC": @"02" };
    NSDictionary *network = @{ @"carrierName": @"Network", @"mcc": @"310", @"mnc": @"260" };
    CHECK(PXNetworkCarrierSource(carrier, network, @{}) == carrier, "nonempty carrier record wins as a whole");
    CHECK(PXNetworkCarrierSource(@{}, network, carrier) == network, "network record is the second whole-record source");
    CHECK(PXNetworkCarrierSource(@[], NSNull.null, carrier) == carrier, "malformed sources fall through to device IDs");
    CHECK([PXNetworkCarrierField(carrier, @"carrierName", @"CarrierName") isEqual:@"Legacy"], "legacy uppercase carrier keys remain supported");
    NSDictionary *malformed = @{ @"carrierName": @[], @"CarrierName": @"Legacy", @"mcc": NSNull.null, @"CarrierMCC": @19 };
    CHECK([PXNetworkCarrierField(malformed, @"carrierName", @"CarrierName") isEqual:@"Legacy"] && PXNetworkCarrierField(malformed, @"mcc", @"CarrierMCC") == nil, "only valid legacy strings may replace invalid primary fields");
    CHECK([PXNetworkCarrierField(@{ @"carrierName": @"", @"CarrierName": @"Legacy" }, @"carrierName", @"CarrierName") isEqual:@""], "empty primary string preserves existing fallback policy");
    gIdentity = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    CHECK([[NSFileManager defaultManager] createDirectoryAtPath:gIdentity withIntermediateDirectories:YES attributes:nil error:nil], "identity fixture directory created");
    @try {
        WritePlist(carrier, @"device_ids.plist");
        WritePlist(@[], @"carrier_details.plist");
        WritePlist(@[], @"network_settings.plist");
        ClearCarrier(); gView.artifacts = @{ @"carrierDetails": @[], @"networkSettings": @[] }; gView.deviceIDs = carrier;
        NSDictionary *details = getCarrierDetailsFromProfile();
        CHECK([details[@"carrierName"] isEqual:@"Legacy"] && [details[@"mobileCountryCode"] isEqual:@"001"] && [details[@"mobileNetworkCode"] isEqual:@"02"], "actual carrier reader accepts valid device fallback after malformed earlier records");
        WritePlist(@{ @"CarrierName": @19, @"CarrierMCC": @[], @"CarrierMNC": @NO }, @"carrier_details.plist");
        ClearCarrier(); gView.artifacts = @{ @"carrierDetails": @{ @"CarrierName": @19, @"CarrierMCC": @[], @"CarrierMNC": @NO } }; gView.deviceIDs = carrier;
        details = getCarrierDetailsFromProfile();
        CHECK([details[@"carrierName"] isEqual:@"T-Mobile"] && [details[@"mobileCountryCode"] isEqual:@"310"] && [details[@"mobileNetworkCode"] isEqual:@"260"], "actual carrier reader preserves whole-record defaults for malformed uppercase fields");
        WritePlist(network, @"network_settings.plist"); WritePlist(@{}, @"carrier_details.plist");
        ClearCarrier(); gView.artifacts = @{ @"networkSettings": network }; gView.deviceIDs = carrier;
        details = getCarrierDetailsFromProfile();
        CHECK([details[@"carrierName"] isEqual:@"Network"], "actual carrier reader retains network precedence");
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        NSUInteger identityReads = gIdentityReads;
        gView.artifacts = @{ @"networkSettings": carrier };
        CHECK(getCarrierDetailsFromProfile() == details && gIdentityReads == identityReads, "captured view memo stays authoritative without file path lookup");
        ClearCarrier(); gView.artifacts = @{ @"networkSettings": carrier };
        CHECK([getCarrierDetailsFromProfile()[@"carrierName"] isEqual:@"Legacy"], "new captured view never adopts the prior global carrier cache");
#else
        CHECK([PXNetworkCarrierSourceAtIdentity(gIdentity) isEqual:network], "all carrier fallbacks use one explicit identity directory");
        CHECK(PXNetworkCarrierSourceAtIdentity(nil) == nil, "missing identity never resolves another active profile");
        TestIdentityExceptionCleanup();
#endif
        WritePlist(@[], @"network_settings.plist");
        WritePlist(@{ @"LocalIPAddress": @"192.0.2.8" }, @"device_ids.plist");
        gView.artifacts = @{ @"networkSettings": @[] }; gView.deviceIDs = @{ @"LocalIPAddress": @"192.0.2.8" };
        CHECK([getProfileStoredIPAddress(@"localIPAddress", @"LocalIPAddress") isEqual:@"192.0.2.8"], "actual IP reader handles malformed network root and typed device fallback");
        WritePlist(@{ @"localIPAddress": @"192.0.2.9" }, @"network_settings.plist");
        gView.artifacts = @{ @"networkSettings": @{ @"localIPAddress": @"192.0.2.9" } };
        CHECK([getProfileStoredIPAddress(@"localIPAddress", @"LocalIPAddress") isEqual:@"192.0.2.9"], "actual IP reader preserves primary nonempty string precedence");
        WritePlist(@{ @"localIPAddress": @19 }, @"network_settings.plist"); WritePlist(@[], @"device_ids.plist");
        gView.artifacts = @{ @"networkSettings": @{ @"localIPAddress": @19 } }; gView.deviceIDs = (id)@[];
        CHECK(getProfileStoredIPAddress(@"localIPAddress", @"LocalIPAddress") == nil, "actual IP reader rejects both malformed roots and scalar values");
    } @finally {
        [[NSFileManager defaultManager] removeItemAtPath:gIdentity error:nil];
        gIdentity = nil; gView = nil;
    }
}
int main(void) {
    @autoreleasepool {
        TestClockAndIntervals(); TestIndependentSignals(); TestSignalSupersessionAndFaults();
        TestRadio(); TestRealThreadInterleaving(); TestTypedReads();
        printf("Network hook state: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
    }
    return gFailures ? 1 : 0;
}
