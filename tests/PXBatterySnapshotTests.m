#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <os/lock.h>
#include <math.h>
#include <stdint.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
static NSUInteger gChecks, gFailures, gReads, gSelections, gExists, gFactories, gLevelReads, gLPMReads, gClockCalls, gCaptures;
static BOOL gClockFails, gThrowRead, gManagerLPM;
static NSTimeInterval gNow;
static NSString *gActive, *gManagerLevel;
static NSMutableDictionary *gFiles;
static void (^gDuringSelection)(void), (^gDuringRead)(void), (^gDuringFactory)(void);
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PX_RUNTIME_READ_OPERATION do {} while (0)
static NSString *PXActiveProfileID(void) {
    gSelections++; NSString *value = gActive;
    void (^callback)(void) = gDuringSelection; gDuringSelection = nil;
    @try { if (callback) callback(); return value; }
    @finally { callback = nil; value = nil; }
}
static NSString *PXProfileIdentityPath(NSString *profile) {
    return [profile isKindOfClass:NSString.class] && profile.length ?
        [[@"/fixture" stringByAppendingPathComponent:profile] stringByAppendingPathComponent:@"identity"] : nil;
}
@interface PXSnapshotFileManager : NSObject
+ (instancetype)defaultManager;
- (BOOL)fileExistsAtPath:(NSString *)path;
@end
@implementation PXSnapshotFileManager
+ (instancetype)defaultManager { return [self new]; }
- (BOOL)fileExistsAtPath:(NSString *)path { gExists++; return gFiles[path] != nil; }
@end
@interface NSDictionary (SnapshotFixture)
+ (instancetype)px_snapshotRead:(NSString *)path;
@end
@implementation NSDictionary (SnapshotFixture)
+ (instancetype)px_snapshotRead:(NSString * __unsafe_unretained)path {
    gReads++; id value = gFiles[path];
    void (^callback)(void) = gDuringRead; gDuringRead = nil;
    @try {
        if (callback) callback();
        if (gThrowRead) [NSException raise:@"fixture.read" format:@"read failed"];
        return value;
    } @finally { value = nil; callback = nil; }
}
@end
@interface BatteryManager : NSObject
+ (instancetype)sharedManager;
- (NSString *)batteryLevel;
- (BOOL)lowPowerModeEnabled;
@end
@implementation BatteryManager
+ (instancetype)sharedManager {
    gFactories++; void (^callback)(void) = gDuringFactory; gDuringFactory = nil;
    @try { if (callback) callback(); return [self new]; }
    @finally { callback = nil; }
}
- (NSString *)batteryLevel { gLevelReads++; return gManagerLevel; }
- (BOOL)lowPowerModeEnabled { gLPMReads++; return gManagerLPM; }
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
static BOOL PXRuntimeReadBool(id value) {
    return ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class]) && [value boolValue];
}
static int PXFixtureBatteryClock(clockid_t clock, struct timespec *instant) {
    (void)clock; gClockCalls++;
    if (gClockFails) return -1;
    instant->tv_sec = (time_t)gNow; instant->tv_nsec = (long)((gNow - floor(gNow)) * 1e9); return 0;
}
#define clock_gettime PXFixtureBatteryClock
#define NSFileManager PXSnapshotFileManager
#define dictionaryWithContentsOfFile px_snapshotRead
#include "PXBatterySnapshot.inc"
#undef dictionaryWithContentsOfFile
#undef NSFileManager
#undef clock_gettime
static NSString *Canonical(void) { return @"/fixture/a/identity/battery_info.plist"; }
static NSDictionary *Record(NSString *level, id lpm) { return @{ @"BatteryLevel": level, @"LowPowerMode": lpm }; }
static void Reset(void) {
    PXInvalidateBatterySnapshot();
    gReads = gSelections = gExists = gFactories = gLevelReads = gLPMReads = gClockCalls = gCaptures = 0;
    gNow = 100; gClockFails = gThrowRead = NO; gActive = @"a";
    gFiles = [NSMutableDictionary new]; gManagerLevel = @"0.55"; gManagerLPM = NO;
    gDuringSelection = gDuringRead = gDuringFactory = nil;
    gView = [PXRuntimeReadSnapshot new]; gView.deviceIDs = @{}; gView.artifacts = @{};
}
static void TestPath(void) {
    Reset(); gFiles[@"/fixture/a/battery_info.plist"] = Record(@"0.3", @NO);
    gFiles[@"/fixture/b/battery_info.plist"] = Record(@"0.9", @YES);
    gDuringSelection = ^{ gActive = @"b"; };
    CHECK([PXProfileBatteryInfoPath() isEqual:@"/fixture/a/battery_info.plist"] && gSelections == 1,
          "battery canonical and legacy paths share one captured selection despite lookup reentry");
    Reset(); gFiles[Canonical()] = Record(@"0.6", @YES);
    CHECK([PXProfileBatteryInfoPath() isEqual:Canonical()] && gSelections == 1 && gExists == 1,
          "battery canonical path avoids duplicate selection and legacy existence work");
}
static void TestSnapshot(void) {
    Reset();
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    gView.artifacts = @{ @"batteryInfo": Record(@"0.61", @NO) };
    gView.deviceIDs = Record(@"0.9", @YES);
    PXBatterySnapshot value = PXGetBatterySnapshot();
    CHECK(value.hasLevel && fabsf(value.level - 0.61f) < 0.0001f && value.hasLPM && !value.lowPowerMode &&
          gCaptures == 1 && !gReads && !gFactories && !gSelections && !gClockCalls,
          "RootHide battery keeps captured artifact precedence without live cache clock files or manager");
    Reset(); gView.deviceIDs = Record(@"0.01", @YES); value = PXGetBatterySnapshot();
    CHECK(value.hasLevel && value.level == 0.01f && value.hasLPM && value.lowPowerMode && !gReads && !gFactories,
          "RootHide battery retains typed device-ID fallback and one-percent boundary");
#else
    gFiles[Canonical()] = Record(@"0.6", @YES);
    PXBatterySnapshot value = PXGetBatterySnapshot();
    CHECK(value.hasLevel && value.hasLPM && value.lowPowerMode && gReads == 1 && gSelections == 1 && !gFactories,
          "complete battery snapshot uses one selected file without manager fallback");
    gNow = 101; value = PXGetBatterySnapshot();
    CHECK(gReads == 1 && gSelections == 1 && value.loadedAt == 100, "warm battery snapshot avoids all profile IO until TTL expiry");
    gNow = 102; value = PXGetBatterySnapshot();
    CHECK(gReads == 2 && value.loadedAt == 102, "battery TTL retains exclusive two-second boundary");
    gNow = 101; value = PXGetBatterySnapshot();
    CHECK(gReads == 3 && value.loadedAt == 101, "negative battery cache age is never fresh");
    gClockFails = YES; gFiles[Canonical()] = Record(@"0.4", @NO); value = PXGetBatterySnapshot();
    PXBatterySnapshot cached = PXReadBatterySnapshot(NULL);
    CHECK(value.hasLevel && value.level == 0.4f && value.loadedAt == 0 && !cached.hasLevel && cached.loadedAt == 0,
          "battery clock failure serves one shot and clears old cache without retaining the result");
    NSUInteger reads = gReads; (void)PXGetBatterySnapshot();
    CHECK(gReads == reads + 1, "battery invalid clock never makes a warm cache hit");
    Reset(); gFiles[Canonical()] = Record(@"0.6", @[]); gManagerLPM = YES;
    value = PXGetBatterySnapshot();
    CHECK(value.hasLevel && value.hasLPM && value.lowPowerMode && gFactories == 1 && !gLevelReads && gLPMReads == 1,
          "unsupported battery LPM follows optional-manager fallback without unsafe boolValue");
    Reset(); __block BOOL reentrySafe = NO;
    gDuringFactory = ^{ PXBatterySnapshot nested = PXGetBatterySnapshot(); reentrySafe = gPXBatterySnapshotDepth == 1 && !nested.hasLevel && gFactories == 1; };
    value = PXGetBatterySnapshot();
    CHECK(reentrySafe && value.hasLevel && value.hasLPM && !gPXBatterySnapshotDepth,
          "battery singleton reentry never starts a second provider and restores depth");
    Reset(); gThrowRead = YES; gFiles[Canonical()] = Record(@"0.6", @NO); value = PXGetBatterySnapshot();
    CHECK(!value.hasLevel && !gPXBatterySnapshotDepth, "battery read exception preserves partial failure policy and releases depth");
#endif
}
static void TestInvalidation(void) {
#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    Reset(); gFiles[Canonical()] = Record(@"0.3", @NO);
    gDuringRead = ^{ PXInvalidateBatterySnapshot(); };
    PXBatterySnapshot revoked = PXGetBatterySnapshot(), empty = PXReadBatterySnapshot(NULL);
    CHECK(!revoked.hasLevel && !revoked.hasLPM && !empty.hasLevel && !empty.hasLPM && !gPXBatterySnapshotDepth,
          "battery invalidation without a replacement leaves both result and cache unavailable");
    gFiles[Canonical()] = Record(@"0.7", @YES); revoked = PXGetBatterySnapshot();
    CHECK(revoked.hasLevel && revoked.level == 0.7f && gReads == 2,
          "next battery request can refill a revoked cache without a retry loop");
    Reset(); gFiles[Canonical()] = Record(@"0.3", @NO);
    __block PXBatterySnapshot newer = {0};
    gDuringRead = ^{
        gFiles[Canonical()] = Record(@"0.8", @YES); PXInvalidateBatterySnapshot();
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        [NSThread detachNewThreadWithBlock:^{ @autoreleasepool { newer = PXGetBatterySnapshot(); } dispatch_semaphore_signal(done); }];
        long timedOut = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
        CHECK(!timedOut, "battery refresh collaborator runs outside cache lock");
        if (timedOut) exit(1);
    };
    PXBatterySnapshot old = PXGetBatterySnapshot(), cached = PXReadBatterySnapshot(NULL);
    CHECK(newer.hasLevel && newer.level == 0.8f && cached.hasLevel && cached.level == 0.8f &&
          !old.hasLevel && !old.hasLPM && !gPXBatterySnapshotDepth && gReads == 2,
          "invalidated battery loader cannot return or overwrite a newer snapshot from another thread");
#endif
}
int main(void) {
    @autoreleasepool {
        @try { TestPath(); TestSnapshot(); TestInvalidation(); }
        @catch (NSException *exception) { gFailures++; fprintf(stderr, "FAIL: unexpected battery snapshot exception: %s\n", exception.description.UTF8String); }
        printf("Battery snapshot: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
