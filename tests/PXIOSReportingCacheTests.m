#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <os/lock.h>
#import <dispatch/dispatch.h>
#include <time.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static NSUInteger gChecks, gFailures, gClockCalls, gIdentityReads, gFallbackReads;
static NSUInteger gDeviceOriginalCalls, gStructOriginalCalls, gStringOriginalCalls, gAdmissionCalls;
static BOOL gScoped = YES, gEnabled = YES, gManagerPresent = YES, gOriginalThrows, gClockUnavailable;
static time_t gSeconds = 1000;
static long gNanoseconds;
static NSString *gBundle = @"fixture.app";
static void (*gDuringIdentity)(void), (*gDuringFallback)(void), (*gDuringGate)(void);
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PX_RUNTIME_READ_OPERATION do {} while (0)
#define IOSVERSION_LOG(...) do {} while (0)
// Preserve the production log call in the exact method without fixture noise.
#define NSLog(...) do {} while (0)

@interface PXIdentitySnapshot : NSObject
@property (nonatomic) BOOL valid;
@property (nonatomic, copy) NSDictionary *deviceIDs;
@end
@implementation PXIdentitySnapshot
@end
@interface PXRuntimeReadSnapshot : NSObject
@property (nonatomic, strong) PXIdentitySnapshot *identity;
@end
@implementation PXRuntimeReadSnapshot
@end
static PXIdentitySnapshot *gIdentity;
static PXRuntimeReadSnapshot *gView;
static id gFallback;
static PXRuntimeReadSnapshot *PXCaptureRuntimeSnapshot(void) { return gView; }
static PXIdentitySnapshot *PXCurrentIdentitySnapshot(void) {
    PXIdentitySnapshot *result = nil;
    @try {
        gIdentityReads++;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        result = gView.identity;
#else
        result = gIdentity;
#endif
        void (*callback)(void) = gDuringIdentity; gDuringIdentity = NULL;
        if (callback) callback();
        return result;
    } @finally { result = nil; }
}
static int PXFixtureClock(clockid_t clock, struct timespec *instant) {
    gClockCalls++;
    if (gClockUnavailable || clock != CLOCK_MONOTONIC) return -1;
    instant->tv_sec = gSeconds; instant->tv_nsec = gNanoseconds; return 0;
}
#define clock_gettime PXFixtureClock
#include "PXIOSReportingState.inc"
#undef clock_gettime

@interface IdentifierManager : NSObject
+ (instancetype)sharedManager;
- (BOOL)isIdentifierEnabled:(NSString *)name;
@end
@implementation IdentifierManager
+ (instancetype)sharedManager {
    static IdentifierManager *manager; static dispatch_once_t once;
    dispatch_once(&once, ^{ manager = [IdentifierManager new]; });
    return gManagerPresent ? manager : nil;
}
- (BOOL)isIdentifierEnabled:(NSString *)name {
    (void)name;
    void (*callback)(void) = gDuringGate; gDuringGate = NULL;
    if (callback) callback();
    return gEnabled;
}
@end
@interface IOSVersionInfo : NSObject
+ (instancetype)sharedManager;
- (NSDictionary *)currentIOSVersionInfo;
@end
@implementation IOSVersionInfo
+ (instancetype)sharedManager {
    static IOSVersionInfo *manager; static dispatch_once_t once;
    dispatch_once(&once, ^{ manager = [IOSVersionInfo new]; }); return manager;
}
- (NSDictionary *)currentIOSVersionInfo {
    id result = nil;
    @try {
        gFallbackReads++; result = gFallback;
        void (*callback)(void) = gDuringFallback; gDuringFallback = NULL;
        if (callback) callback();
        return result;
    } @finally { result = nil; }
}
@end
static const NSUInteger PXScopeOptionAllowSafariAuthStack = 1;
static BOOL PXProcessIsAllowedForSpoofing(NSString *bundle, NSString *process, NSUInteger options) {
    (void)bundle; (void)process; (void)options; gAdmissionCalls++; return gScoped;
}
static NSString *getCurrentBundleID(void) { return gBundle; }
#include "PXIOSReportingPolicy.inc"
#include "PXIOSReportingWork.inc"

static void OriginalFault(void) {
    if (gOriginalThrows) @throw [NSException exceptionWithName:@"FixtureOriginal" reason:@"original failed" userInfo:nil];
}
static NSString *PXFixtureOriginalVersion(void) { gDeviceOriginalCalls++; OriginalFault(); return @"15.8.8"; }
static NSOperatingSystemVersion PXFixtureOriginalStruct(void) { gStructOriginalCalls++; OriginalFault(); return (NSOperatingSystemVersion){15, 8, 8}; }
static NSString *PXFixtureOriginalVersionString(void) { gStringOriginalCalls++; OriginalFault(); return @"Version 15.8.8 (Build REAL)"; }
@interface PXIOSReportingFixture : NSObject
#include "PXIOSReportingDeclarations.inc"
@end
@implementation PXIOSReportingFixture
#include "PXIOSReportingMethods.inc"
@end
static PXIOSReportingFixture *gFixture;
static NSDictionary *IDs(NSString *version, NSString *build) {
    return @{ @"IOSVersion": version, @"IOSBuild": build, @"Darwin": @"22.0.0", @"XNU": @"xnu-profile", @"KernelVersion": @"Darwin Kernel Version profile" };
}
static void Configure(NSDictionary *ids) {
    gIdentity = [PXIdentitySnapshot new]; gIdentity.valid = YES; gIdentity.deviceIDs = ids;
    gView = [PXRuntimeReadSnapshot new]; gView.identity = gIdentity;
}
static void Reset(void) {
    PXIOSVersionInvalidateCache();
    Configure(IDs(@"17.2.1", @"21C"));
    gScoped = YES; gEnabled = YES; gManagerPresent = YES; gOriginalThrows = NO; gClockUnavailable = NO;
    gDuringIdentity = NULL; gDuringFallback = NULL; gDuringGate = NULL;
    gFallback = nil; gBundle = @"fixture.app"; gSeconds = 1000; gNanoseconds = 0;
    gDeviceOriginalCalls = 0; gStructOriginalCalls = 0; gStringOriginalCalls = 0;
    gIdentityReads = 0; gFallbackReads = 0; gClockCalls = 0; gAdmissionCalls = 0;
    CHECK(!gPXInsideIOSReportingHook && !gPXInsideIOSVersionInfo, "previous invocation restored reporting and info recursion state");
}
static NSString *ReadSurface(NSUInteger kind) {
    if (kind == 0) return [gFixture systemVersion];
    if (kind == 1) {
        NSOperatingSystemVersion v = [gFixture operatingSystemVersion];
        return [NSString stringWithFormat:@"%ld.%ld.%ld", (long)v.majorVersion, (long)v.minorVersion, (long)v.patchVersion];
    }
    return [gFixture operatingSystemVersionString];
}
static NSUInteger OriginalCount(NSUInteger kind) { return kind == 0 ? gDeviceOriginalCalls : kind == 1 ? gStructOriginalCalls : gStringOriginalCalls; }
static void TestReportingPolicies(void) {
    for (NSUInteger kind = 0; kind < 3; kind++) {
        Reset(); NSString *result = ReadSurface(kind);
        CHECK([result containsString:@"17.2.1"] && OriginalCount(kind) == 1, "active reporting keeps configured upward version and calls original once on first read");
        gEnabled = NO;
        CHECK([ReadSurface(kind) containsString:@"15.8.8"] && OriginalCount(kind) == 2, "toggle off bypasses any warm throttle");
        gEnabled = YES;
        CHECK([ReadSurface(kind) containsString:@"17.2.1"], "toggle reenable can report the configured profile");
        gScoped = NO;
        CHECK([ReadSurface(kind) containsString:@"15.8.8"], "scope disable bypasses a warm reporting result");
        gScoped = YES; gManagerPresent = NO;
        CHECK([ReadSurface(kind) containsString:@"15.8.8"], "missing toggle manager preserves original");
        gManagerPresent = YES;
        Configure(IDs(@"18.1", @"22B"));
        CHECK([ReadSurface(kind) containsString:@"18.1"], "new identity/view cannot hit the prior profile inside 100 milliseconds");
        Configure(IDs(@"not-a-version", @"22B"));
        CHECK([ReadSurface(kind) containsString:@"15.8.8"], "invalid configured version follows the unchanged reporting policy rejection");
        CHECK(!gPXInsideIOSReportingHook, "reporting state restores after each policy outcome");
    }
}
static void TestTimeAndKeys(void) {
    Reset();
    CHECK(PXIOSVersionCacheTime() == 1000, "clock uses seconds rather than Mach ticks");
    gNanoseconds = 250000000;
    CHECK(PXIOSVersionCacheTime() == 1000.25, "clock converts nanoseconds correctly");
    CHECK(PXIOSVersionTimeIsFresh(0, 0, YES, 0.1), "zero monotonic time is valid");
    CHECK(PXIOSVersionTimeIsFresh(1000.099, 1000, YES, 0.1), "100ms interval includes just before boundary");
    // Use an exactly representable origin for the exact 0.1 boundary; adding
    // a fractional deadline to a large origin can round the subtraction down.
    CHECK(!PXIOSVersionTimeIsFresh(0.1, 0, YES, 0.1), "100ms exact boundary is exclusive");
    CHECK(!PXIOSVersionTimeIsFresh(1800, 0, YES, 1800), "30-minute exact boundary is exclusive");
    CHECK(!PXIOSVersionTimeIsFresh(999, 1000, YES, 0.1) && !PXIOSVersionTimeIsFresh(NAN, 0, YES, 0.1), "clock rollback and nonfinite samples never hit");
    NSDictionary *info = PXIOSVersionFreezeInfo(@{ @"version": @"17.2.1", @"build": @"21C", @"darwin": @"22", @"xnu": @"x", @"kernel_version": @"kernel" });
    uint64_t epoch = PXIOSVersionSystemEpoch();
    CHECK(PXIOSSystemPublishResult(@"17.2.1", info, @"fixture.app", 0, epoch), "complete system packet publishes");
    epoch = PXIOSVersionSystemEpoch();
    CHECK([PXIOSSystemCachedResult(info, @"fixture.app", 0.099, epoch) isEqual:@"17.2.1"], "system cache owns value info bundle and timestamp together");
    CHECK(PXIOSSystemCachedResult(info, @"another.app", 0.05, epoch) == nil, "bundle identity is part of system result key");
    // A mutable copy must have separate identity from the frozen input. Avoid
    // assuming that copying an immutable Foundation class cluster allocates.
    NSDictionary *otherInfo = [info mutableCopy];
    CHECK(PXIOSSystemCachedResult(otherInfo, @"fixture.app", 0.05, epoch) == nil, "same contents under another info publication cannot hit");
    CHECK(PXIOSSystemCachedResult(info, @"fixture.app", 0.1, epoch) == nil, "system helper enforces exact 100ms boundary");
    PXIOSVersionInvalidateCache();
    CHECK(!PXIOSSystemPublishResult(@"old", info, @"fixture.app", 0, epoch), "notification rejects a revoked system result");
    uint64_t infoEpoch = 0;
    (void)PXIOSVersionCachedInfo(gIdentity, 0, &infoEpoch);
    CHECK(PXIOSVersionPublishInfo(info, gIdentity, 0, infoEpoch), "profile-info packet publishes for its retained identity");
    CHECK(PXIOSVersionCachedInfo(gIdentity, 1799.999, &infoEpoch) == info, "info cache retains 30-minute interval");
    CHECK(PXIOSVersionCachedInfo(gIdentity, 1800, &infoEpoch) == nil, "info helper enforces exclusive 30-minute boundary");
    Configure(IDs(@"18.1", @"22B"));
    CHECK(PXIOSVersionCachedInfo(gIdentity, 1, &infoEpoch) == nil, "identity object key prevents cross-profile info cache hit");
}
static void TestParsingAndFallback(void) {
    Reset(); Configure(IDs(@"17.2.1 (21C99)", @""));
    NSDictionary *info = getIOSVersionInfo();
    CHECK([info[@"version"] isEqual:@"17.2.1"] && [info[@"build"] isEqual:@"21C99"], "formatted version retains parenthesized-build fallback");
    Reset(); Configure(IDs(@"17.2.1 (21C99)", @"EXPLICIT"));
    CHECK([getIOSVersionInfo()[@"build"] isEqual:@"EXPLICIT"], "explicit build keeps precedence over parsed build");
    Reset(); Configure(@{});
    gFallback = @{ @"version": @"18.1", @"build": @"22B", @"darwin": @"24", @"xnu": @"x", @"kernel_version": @"kernel", @"extra": @"preserved" };
    info = getIOSVersionInfo();
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    CHECK(info == nil && gFallbackReads == 0, "captured missing fields never consult live fallback manager");
#else
    CHECK([info[@"version"] isEqual:@"18.1"] && [info[@"extra"] isEqual:@"preserved"] && gFallbackReads == 1, "rootful fallback preserves optional metadata");
#endif
    NSArray *bad = @[@[], NSNull.null, @{ @"version": @17 }, @{ @"version": @"18", @"build": @"", @"darwin": @"24", @"xnu": @"x", @"kernel_version": @"k" }];
    for (id value in bad) CHECK(PXIOSVersionFreezeInfo(value) == nil, "malformed or incomplete fallback packet is rejected");
    NSMutableString *mutable = [NSMutableString stringWithString:@"18.1"];
    info = PXIOSVersionFreezeInfo(@{ @"version": mutable, @"build": @"22B", @"darwin": @"24", @"xnu": @"x", @"kernel_version": @"kernel" });
    [mutable appendString:@"-changed"];
    CHECK([info[@"version"] isEqual:@"18.1"], "prepared version fields are isolated from mutable fallback strings");
}
static void ThrowProvider(void) { @throw [NSException exceptionWithName:@"FixtureProvider" reason:@"provider failed" userInfo:nil]; }
static void TestExceptions(void) {
    for (NSUInteger kind = 0; kind < 3; kind++) {
        Reset(); gOriginalThrows = YES; BOOL caught = NO;
        @try { (void)ReadSurface(kind); }
        @catch (NSException *exception) { caught = [exception.name isEqual:@"FixtureOriginal"]; }
        CHECK(caught && OriginalCount(kind) == 1 && !gPXInsideIOSReportingHook, "original exception propagates once and restores recursion state");
        gOriginalThrows = NO;
        CHECK([ReadSurface(kind) containsString:@"17.2.1"], "getter remains usable after original exception");
        Reset(); __weak PXIdentitySnapshot *weakIdentity;
        @autoreleasepool {
            Configure(IDs(@"17.2.1", @"21C")); weakIdentity = gIdentity;
            gDuringIdentity = ThrowProvider;
            CHECK([ReadSurface(kind) containsString:@"15.8.8"] && OriginalCount(kind) == 1, "projection provider failure preserves original without a second call");
            gIdentity = nil; gView = nil;
        }
        CHECK(weakIdentity == nil && !gPXInsideIOSReportingHook, "exceptional provider path releases captured identity and view roots after pool drain");
        Reset(); gDuringGate = ThrowProvider;
        CHECK([ReadSurface(kind) containsString:@"15.8.8"] && OriginalCount(kind) == 1, "admission exception preserves original");
    }
}
static NSDictionary *gReentrantInfo;
static void ReenterInfo(void) { gReentrantInfo = getIOSVersionInfo(); }
static NSString *gReentrantVersion;
static NSOperatingSystemVersion gReentrantStruct;
static void ReenterGetters(void) {
    gReentrantVersion = [gFixture systemVersion];
    gReentrantStruct = [gFixture operatingSystemVersion];
}
static void TestReentry(void) {
    Reset(); gDuringIdentity = ReenterInfo;
    NSDictionary *outer = getIOSVersionInfo();
    CHECK(gReentrantInfo == nil && [outer[@"version"] isEqual:@"17.2.1"] && !gPXInsideIOSVersionInfo, "recursive info provider gets unavailable without blocking or poisoning its outer reader");
    Reset(); gDuringGate = ReenterGetters;
    CHECK([[gFixture systemVersion] isEqual:@"17.2.1"], "outer reporting survives a reentrant policy provider");
    CHECK([gReentrantVersion isEqual:@"15.8.8"] && gReentrantStruct.majorVersion == 15, "reentrant reporting getters stay on their original paths");
    CHECK(gAdmissionCalls == 1 && gDeviceOriginalCalls == 2 && gStructOriginalCalls == 1 && !gPXInsideIOSReportingHook, "cross-surface recursion never reenters policy or leaves thread flag set");
}
@interface PXIOSRetiredRoot : NSObject
@end
@implementation PXIOSRetiredRoot
- (void)dealloc { gDeallocations++; (void)PXIOSVersionSystemEpoch(); }
@end
static void TestRetiredRoots(void) {
    Reset(); NSUInteger count = gDeallocations;
    @autoreleasepool {
        versionCache = (id)[PXIOSRetiredRoot new]; gIOSVersionIdentity = (id)[PXIOSRetiredRoot new];
        gIOSSystemResult = (id)[PXIOSRetiredRoot new]; gIOSSystemBundle = (id)[PXIOSRetiredRoot new]; gIOSSystemInfo = (id)[PXIOSRetiredRoot new];
    }
    PXIOSVersionInvalidateCache();
    CHECK(gDeallocations == count + 5, "joint invalidation releases all five retired roots after unlock and permits destructor reentry");
    @autoreleasepool { gIOSSystemResult = (id)[PXIOSRetiredRoot new]; }
    count = gDeallocations;
    NSDictionary *info = PXIOSVersionFreezeInfo(@{ @"version": @"17", @"build": @"21", @"darwin": @"22", @"xnu": @"x", @"kernel_version": @"kernel" });
    CHECK(PXIOSSystemPublishResult(@"17", info, @"fixture.app", 1000, PXIOSVersionSystemEpoch()), "system replacement accepts a complete candidate");
    CHECK(gDeallocations == count + 1, "system replacement defers old result destruction until after unlock");
    @autoreleasepool {
        versionCache = (id)[PXIOSRetiredRoot new]; gIOSVersionIdentity = (id)[PXIOSRetiredRoot new];
    }
    count = gDeallocations;
    CHECK(PXIOSVersionPublishInfo(info, gIdentity, 1000, PXIOSVersionInfoEpoch()), "info replacement accepts a matching epoch");
    CHECK(gDeallocations == count + 2, "info replacement defers both old packet and identity destruction until after unlock");
    @autoreleasepool {
        NSDictionary *held = PXIOSVersionCachedInfo(gIdentity, 1000, NULL);
        PXIOSVersionInvalidateCache();
        CHECK([held[@"version"] isEqual:@"17"], "retained info reader survives global invalidation");
    }
}
static void TestThreadPublication(void) {
    for (NSUInteger kind = 0; kind < 2; kind++) {
        Reset(); NSDictionary *older = PXIOSVersionFreezeInfo(@{ @"version": @"17", @"build": @"21", @"darwin": @"22", @"xnu": @"x", @"kernel_version": @"kernel" });
        NSDictionary *newer = PXIOSVersionFreezeInfo(@{ @"version": @"18", @"build": @"22", @"darwin": @"24", @"xnu": @"x", @"kernel_version": @"kernel" });
        uint64_t oldEpoch = kind ? PXIOSVersionSystemEpoch() : 0;
        if (!kind) (void)PXIOSVersionCachedInfo(gIdentity, 1000, &oldEpoch);
        dispatch_semaphore_t entered = dispatch_semaphore_create(0), finish = dispatch_semaphore_create(0), done = dispatch_semaphore_create(0);
        __block BOOL oldPublished = YES;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            @autoreleasepool {
                dispatch_semaphore_signal(entered); dispatch_semaphore_wait(finish, DISPATCH_TIME_FOREVER);
                oldPublished = kind ? PXIOSSystemPublishResult(@"17", older, @"fixture.app", 1000, oldEpoch) : PXIOSVersionPublishInfo(older, gIdentity, 1000, oldEpoch);
            }
            dispatch_semaphore_signal(done);
        });
        long waited = dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
        CHECK(waited == 0, "older reporting builder paused before publication"); if (waited) { dispatch_semaphore_signal(finish); exit(1); }
        PXIOSVersionInvalidateCache(); uint64_t epoch = kind ? PXIOSVersionSystemEpoch() : 0;
        if (!kind) (void)PXIOSVersionCachedInfo(gIdentity, 1000, &epoch);
        CHECK(kind ? PXIOSSystemPublishResult(@"18", newer, @"fixture.app", 1000, epoch) : PXIOSVersionPublishInfo(newer, gIdentity, 1000, epoch), "newer reporting builder publishes first");
        dispatch_semaphore_signal(finish); waited = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
        CHECK(waited == 0 && !oldPublished, "older thread cannot overwrite invalidation or a newer reporting publication"); if (waited) exit(1);
    }
}
static void InvalidateDuringRead(void) { PXIOSVersionInvalidateCache(); }
#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
static NSDictionary *gNewInfo;
static void SwitchIdentityDuringRead(void) { Configure(IDs(@"18.1", @"22B")); }
static void TestRootfulCacheFlow(void) {
    Reset(); gSeconds = 0;
    CHECK([[gFixture systemVersion] isEqual:@"17.2.1"] && gDeviceOriginalCalls == 1, "system hook accepts monotonic zero at first publication");
    gNanoseconds = 99000000;
    CHECK([[gFixture systemVersion] isEqual:@"17.2.1"] && gDeviceOriginalCalls == 1, "actual system hook hits before 100 milliseconds");
    gNanoseconds = 100000000;
    CHECK([[gFixture systemVersion] isEqual:@"17.2.1"] && gDeviceOriginalCalls == 2, "actual system hook misses at exactly 100 milliseconds");
    Reset(); CHECK([[gFixture systemVersion] isEqual:@"17.2.1"], "first active system getter reports profile");
    NSUInteger originals = gDeviceOriginalCalls;
    CHECK([[gFixture systemVersion] isEqual:@"17.2.1"] && gDeviceOriginalCalls == originals, "warm system getter avoids the original call");
    gSeconds = 1001;
    CHECK([[gFixture systemVersion] isEqual:@"17.2.1"] && gDeviceOriginalCalls == originals + 1, "expired throttle calls original once");
    Reset(); gDuringIdentity = InvalidateDuringRead;
    CHECK([[gFixture systemVersion] isEqual:@"17.2.1"] && gIOSSystemResult == nil && versionCache == nil, "notification during identity lookup cannot revive either cache from the older operation");
    Reset(); gDuringIdentity = SwitchIdentityDuringRead;
    NSDictionary *old = getIOSVersionInfo(); uint64_t revision;
    CHECK([old[@"version"] isEqual:@"17.2.1"] && versionCache == nil, "older identity lookup cannot publish after an unnotified profile switch");
    gNewInfo = getIOSVersionInfo();
    CHECK([gNewInfo[@"version"] isEqual:@"18.1"] && PXIOSVersionCachedInfo(gIdentity, 1000, &revision) == gNewInfo, "new identity reader publishes its own source packet");
    Reset(); gClockUnavailable = YES;
    (void)[gFixture systemVersion]; (void)[gFixture systemVersion];
    CHECK(gDeviceOriginalCalls == 2 && !gIOSInfoHasTime && !gIOSSystemHasTime, "failed clock never causes indefinite info or system throttle hits");
}
#else
static void TestRootHideCacheFlow(void) {
    Reset(); NSUInteger clocks = gClockCalls;
    NSDictionary *first = getIOSVersionInfo();
    CHECK(getIOSVersionInfo() == first && gIdentityReads == 1, "captured view memo skips repeated identity preparation");
    (void)[gFixture systemVersion]; (void)[gFixture systemVersion];
    CHECK(gClockCalls == clocks && gDeviceOriginalCalls == 2 && gIOSSystemResult == nil, "RootHide keeps original-call policy and never uses shared throttle or clock");
    PXRuntimeReadSnapshot *old = gView;
    Configure(IDs(@"18.1", @"22B"));
    CHECK([getIOSVersionInfo()[@"version"] isEqual:@"18.1"], "new captured view has an independent version memo");
    gView = old;
    CHECK(getIOSVersionInfo() == first, "earlier captured view retains its own immutable derived packet");
}
#endif
int main(void) {
    @autoreleasepool {
        gFixture = [PXIOSReportingFixture new];
        TestReportingPolicies(); TestTimeAndKeys(); TestParsingAndFallback(); TestExceptions(); TestReentry(); TestRetiredRoots(); TestThreadPublication();
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        TestRootHideCacheFlow();
#else
        TestRootfulCacheFlow();
#endif
        PXIOSVersionInvalidateCache(); gFixture = nil; gIdentity = nil; gView = nil; gFallback = nil;
        printf("iOS reporting cache: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
    }
    return gFailures ? 1 : 0;
}
