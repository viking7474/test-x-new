#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#include <sys/sysctl.h>
#include <sys/time.h>
#include <math.h>
#include <string.h>
#include <stdatomic.h>
#include <stdio.h>

static NSUInteger gChecks, gFailures, gReads, gWrites, gSyscalls, gPreparations, gSets, gFailSetAt;
static _Atomic NSUInteger gCaptures;
static BOOL gHeld, gInsideSource, gHasReal;
static int gSysResult;
static size_t gSysSize;
static time_t gBootSeconds;
static NSString *gFault;
static NSDate *gNow;
static NSMutableDictionary *gFiles;
static id gPacketOverride;
static void (^gDuringClock)(void), (^gDuringRead)(void), (^gDuringTxRead)(void), (^gDuringSysctl)(void), (^gDuringCapture)(void), (^gBeforeSource)(void), (^gAfterCommit)(void), (^gDuringDealloc)(void);
static NSHashTable *gCallbackRoots;
static __weak id gOwnerRoot, gTxRoot, gIdentityRoot;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PXLog(...) do {} while (0)
static void Raise(void) { [NSException raise:@"fixture.uptime" format:@"controlled failure"]; }
static void Run(void (^ __strong *slot)(void)) { void (^body)(void) = *slot; *slot = nil; @try { if (body) body(); } @finally { body = nil; } }
static NSDictionary *Packet(NSTimeInterval seconds, NSDate *clock) {
    return @{ @"seconds": @(seconds), @"boot": @{ @"value": [clock dateByAddingTimeInterval:-seconds], @"lastUpdated": clock, @"version": @1 },
              @"uptime": @{ @"value": [NSString stringWithFormat:@"%.0f", seconds], @"lastUpdated": clock, @"version": @1 } };
}
static NSString *PXProfileIdentityPath(NSString *profile) {
    return [profile isKindOfClass:NSString.class] && ([profile isEqual:@"a"] || [profile isEqual:@"b"]) ?
        [@"/profiles/" stringByAppendingPathComponent:[profile stringByAppendingPathComponent:@"identity"]] : nil;
}
static NSString *Identity(void) { return @"/profiles/a/identity"; }
static NSString *File(NSString *name) { return [Identity() stringByAppendingPathComponent:name]; }
@interface NSDate (UptimeClock)
+ (NSDate *)px_uptimeDate;
+ (NSDate *)px_uptimeRelative:(NSTimeInterval)seconds;
@end
@implementation NSDate (UptimeClock)
+ (NSDate *)px_uptimeDate { if (gDuringClock) Run(&gDuringClock); return gNow; }
+ (NSDate *)px_uptimeRelative:(NSTimeInterval)seconds { return [gNow dateByAddingTimeInterval:seconds]; }
@end
@interface NSDictionary (UptimeFiles)
+ (NSDictionary *)px_uptimeFile:(NSString *)path;
@end
@implementation NSDictionary (UptimeFiles)
+ (NSDictionary *)px_uptimeFile:(NSString * __unsafe_unretained)path {
    NSDictionary *record = gFiles[path]; gReads++;
    @try { if ([gFault isEqual:@"read"]) Raise(); if (gDuringRead) Run(&gDuringRead); return record; }
    @finally { record = nil; }
}
@end
static int Fixture_sysctl(int *name, u_int length, void *result, size_t *size, void *newValue, size_t newSize) {
    (void)name; (void)length; (void)newValue; (void)newSize; gSyscalls++;
    CHECK(!gInsideSource, "uptime sysctl provider runs outside source gate");
    if (gDuringSysctl) Run(&gDuringSysctl);
    if ([gFault isEqual:@"provider"]) Raise();
    struct timeval value = {0}; value.tv_sec = gBootSeconds;
    if (result && *size >= sizeof(value)) memcpy(result, &value, sizeof(value));
    *size = gSysSize; return gSysResult;
}
static NSDictionary *PXPrepareRuntimeUptime(NSDate * __unsafe_unretained now, NSTimeInterval real, BOOL hasReal) {
    (void)real; gPreparations++; gHasReal = hasReal; return gPacketOverride ?: Packet(43200, now);
}
@interface PXRuntimeSourceTransaction : NSObject
@property (nonatomic, strong) NSMutableDictionary *staged;
- (NSDictionary *)dictionaryAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)setDictionary:(NSDictionary *)value atPath:(NSString *)path error:(NSError **)error;
@end
@implementation PXRuntimeSourceTransaction
- (NSDictionary *)dictionaryAtPath:(NSString * __unsafe_unretained)path error:(NSError **)error {
    (void)error; if ([gFault isEqual:@"tx-read"]) Raise(); if (gDuringTxRead) Run(&gDuringTxRead); return self.staged[path] ?: gFiles[path] ?: @{};
}
- (BOOL)setDictionary:(NSDictionary * __unsafe_unretained)value atPath:(NSString * __unsafe_unretained)path error:(NSError **)error {
    (void)error; gSets++;
    if ([gFault isEqual:@"tx-set"] || (gFailSetAt && gSets == gFailSetAt)) Raise();
    if (!value || !path) return NO; if (!self.staged) self.staged = [NSMutableDictionary dictionary];
    self.staged[path] = [value copy]; return YES;
}
@end
@interface PXProfileArtifactMutation : NSObject
@property (nonatomic, copy) NSString *identityDirectory;
@property (nonatomic) BOOL active;
+ (instancetype)acquireWithIdentityResolver:(NSString *(^)(void))resolver error:(NSError **)error NS_RETURNS_RETAINED;
- (BOOL)performSourceWrite:(BOOL (^)(PXRuntimeSourceTransaction *, NSError **))body error:(NSError **)error;
- (void)invalidate;
@end
@implementation PXProfileArtifactMutation
+ (instancetype)acquireWithIdentityResolver:(NSString *(^ __unsafe_unretained)(void))resolver error:(NSError **)error {
    if (gHeld) { if (error) *error = [NSError errorWithDomain:@"fixture.busy" code:12 userInfo:nil]; return nil; }
    PXProfileArtifactMutation *owner = [self new]; gOwnerRoot = owner;
    NSString *identity = nil; NSMutableString *ownedPath = nil; BOOL handedOff = NO; owner.active = YES; gHeld = YES;
    @try {
        [gCallbackRoots addObject:resolver]; if ([gFault isEqual:@"acquire"]) Raise();
        identity = resolver(); if (!identity) return nil;
        ownedPath = [identity mutableCopy]; owner.identityDirectory = ownedPath; gIdentityRoot = owner.identityDirectory;
        handedOff = YES; return owner;
    } @finally { if (!handedOff) [owner invalidate]; ownedPath = nil; identity = nil; owner = nil; }
}
- (BOOL)performSourceWrite:(BOOL (^ __unsafe_unretained)(PXRuntimeSourceTransaction *, NSError **))body error:(NSError **)error {
    PXRuntimeSourceTransaction *tx = [PXRuntimeSourceTransaction new]; gTxRoot = tx;
    @try {
        gInsideSource = YES; [gCallbackRoots addObject:body]; if (gBeforeSource) Run(&gBeforeSource);
        BOOL success = body(tx, error);
        if (success) { [gFiles addEntriesFromDictionary:tx.staged]; gWrites++; if (gAfterCommit) Run(&gAfterCommit); }
        return success;
    } @finally { gInsideSource = NO; tx = nil; }
}
- (void)invalidate { if (self.active) { self.active = NO; gHeld = NO; } }
@end
#include "PXUptimeStage.inc"
#define sysctl Fixture_sysctl
#define date px_uptimeDate
#define dateWithTimeIntervalSinceNow px_uptimeRelative
#define dictionaryWithContentsOfFile px_uptimeFile
#include "PXUptimeHelpers.inc"
@interface PXUptimeFixture : NSObject
@property (nonatomic, strong) NSDate *bootTimeValue;
@property (nonatomic) NSTimeInterval uptimeValue;
@property (nonatomic, strong) NSDate *cacheTime;
@property (nonatomic, strong) NSError *error;
@property (nonatomic) uint64_t uptimeEpoch;
#include "PXUptimeDeclarations.inc"
@end
@implementation PXUptimeFixture
@synthesize bootTimeValue = _bootTimeValue, uptimeValue = _uptimeValue, cacheTime = _cacheTime, error = _error, uptimeEpoch = _uptimeEpoch;
#include "PXPreparedUptimeMethod.inc"
@end
#undef dictionaryWithContentsOfFile
#undef dateWithTimeIntervalSinceNow
#undef date
#undef sysctl
@interface PXObservedUptime : PXUptimeFixture
@end
@implementation PXObservedUptime
- (NSDate *)captureUptimeSeconds:(NSTimeInterval *)seconds cacheTime:(NSDate * __strong *)clock error:(NSError * __strong *)error {
    NSDate *boot = nil;
    @try { atomic_fetch_add(&gCaptures, 1); boot = [super captureUptimeSeconds:seconds cacheTime:clock error:error]; if (gDuringCapture) Run(&gDuringCapture); return boot; }
    @finally { boot = nil; }
}
@end
@interface PXInvalidDate : NSObject
@end
@implementation PXInvalidDate
- (BOOL)isKindOfClass:(Class)type { return type == NSDate.class || [super isKindOfClass:type]; }
- (NSTimeInterval)timeIntervalSince1970 { return INFINITY; }
@end
@interface PXUptimeReleaseProbe : NSObject
@end
@implementation PXUptimeReleaseProbe
- (void)dealloc { if (gDuringDealloc) Run(&gDuringDealloc); }
@end
static void Reset(void) {
    gReads = gWrites = gSyscalls = gPreparations = gSets = gFailSetAt = 0; atomic_store(&gCaptures, 0);
    gSysResult = 0; gSysSize = sizeof(struct timeval); gBootSeconds = 1000000; gNow = [NSDate dateWithTimeIntervalSince1970:2000000];
    gHeld = gInsideSource = gHasReal = NO; gFault = nil; gPacketOverride = nil; gFiles = [NSMutableDictionary dictionary];
    gDuringClock = nil; gDuringRead = nil; gDuringTxRead = nil; gDuringSysctl = nil; gDuringCapture = nil; gBeforeSource = nil; gAfterCommit = nil; gDuringDealloc = nil;
    gCallbackRoots = [NSHashTable weakObjectsHashTable]; gOwnerRoot = nil; gTxRoot = nil; gIdentityRoot = nil;
}
static void TestTypedReaders(void) {
    Reset(); PXUptimeFixture *owner = [PXUptimeFixture new];
    NSDate *boot = [gNow dateByAddingTimeInterval:-1000];
    gFiles[File(@"boot_time.plist")] = @{ @"value": boot };
    gFiles[File(@"system_uptime.plist")] = @{ @"value": @500, @"lastUpdated": gNow };
    CHECK([owner currentUptimeForProfile:Identity() generateIfMissing:NO] == 1000 && gReads == 1, "uptime boot sidecar preserves first-hit precedence and read count");
    gFiles[File(@"boot_time.plist")] = @{ @"value": @[] };
    gFiles[File(@"system_uptime.plist")] = @{ @"value": @"500suffix", @"lastUpdated": [gNow dateByAddingTimeInterval:-20] };
    CHECK([owner currentUptimeForProfile:Identity() generateIfMissing:NO] == 520, "uptime elapsed reader retains numeric string prefix and clock arithmetic");
    gFiles[File(@"system_uptime.plist")] = @{ @"value": @(INFINITY), @"lastUpdated": gNow };
    gFiles[File(@"device_ids.plist")] = @{ @"SystemUptime": @777, @"BootTime": @12345 };
    CHECK([owner currentUptimeForProfile:Identity() generateIfMissing:NO] == 777 && [owner currentBootTimeForProfile:Identity() generateIfMissing:NO].timeIntervalSince1970 == 12345,
          "nonfinite uptime falls through to finite IDs without constructing invalid dates");
    for (id invalid in @[@[], @{}, NSNull.null, @(NAN), @(INFINITY), @(-INFINITY)]) {
        gFiles[File(@"device_ids.plist")] = @{ @"SystemUptime": invalid, @"BootTime": invalid };
        CHECK([owner currentUptimeForProfile:Identity() generateIfMissing:NO] == 0 && ![owner currentBootTimeForProfile:Identity() generateIfMissing:NO], "unsupported or nonfinite time fields produce read-only sentinels");
        CHECK(![owner validateBootTimeConsistencyForProfile:Identity()], "consistency validation rejects malformed scalar without unsafe selector");
    }
    NSUInteger reads = gReads;
    CHECK([owner currentUptimeForProfile:(id)@[] generateIfMissing:NO] == 0 && ![owner currentBootTimeForProfile:(id)NSNull.null generateIfMissing:NO] && owner.error.code == 1003 && gReads == reads,
          "unsupported uptime paths fail before file access");
    CHECK(!gWrites && !gPreparations && !owner.cacheTime, "read-only time misses do not adopt cache generate or write");
    gFiles[File(@"boot_time.plist")] = @{ @"value": boot }; gFiles[File(@"device_ids.plist")] = @{ @"BootTime": @(boot.timeIntervalSince1970 + 1) };
    CHECK([owner validateBootTimeConsistencyForProfile:Identity()], "boot consistency keeps inclusive one-second tolerance");
    Reset(); owner = [PXUptimeFixture new]; gHeld = YES;
    CHECK([owner currentUptimeForProfile:Identity()] == 43200 && fabs([[owner currentBootTimeForProfile:Identity()] timeIntervalSinceDate:gNow] + 43200) < 0.01 && owner.error.code == 12 && !gPreparations,
          "busy legacy readers keep twelve-hour fallback without provider work"); gHeld = NO;
}
static void TestCacheAndOrdering(void) {
    Reset(); PXObservedUptime *owner = [PXObservedUptime new];
    NSDictionary *a = Packet(100, gNow), *b = Packet(200, [gNow dateByAddingTimeInterval:10]);
    [owner adoptCommittedUptimeInfo:a timestamp:gNow];
    gDuringSysctl = ^{ [owner adoptCommittedUptimeInfo:b timestamp:b[@"boot"][@"lastUpdated"]]; };
    [owner generateConsistentUptimeAndBootTimeForProfile:Identity()];
    CHECK(!gWrites && owner.uptimeValue == 200 && !owner.error && !gHeld, "superseded uptime provider cannot stage or overwrite newer adoption");
    [owner adoptCommittedUptimeInfo:a timestamp:gNow];
    gBeforeSource = ^{ [owner adoptCommittedUptimeInfo:b timestamp:b[@"boot"][@"lastUpdated"]]; };
    [owner generateConsistentUptimeAndBootTimeForProfile:Identity()];
    CHECK(!gWrites && owner.uptimeValue == 200 && !owner.error, "uptime stage rechecks receipt without publishing stale failure");
    [owner adoptCommittedUptimeInfo:a timestamp:gNow];
    gAfterCommit = ^{ [owner adoptCommittedUptimeInfo:b timestamp:b[@"boot"][@"lastUpdated"]]; [owner setCurrentUptime:-1]; };
    [owner generateConsistentUptimeAndBootTimeForProfile:Identity()];
    CHECK(gWrites == 1 && owner.uptimeValue == 200 && owner.error.code == 1001 && gFiles[File(@"boot_time.plist")], "acknowledged uptime commit preserves newer tuple and newer error");
    Reset(); owner = [PXObservedUptime new];
    gDuringSysctl = ^{ [owner generateConsistentUptimeAndBootTimeForProfile:PXProfileIdentityPath(@"b")]; };
    [owner generateConsistentUptimeAndBootTimeForProfile:Identity()];
    CHECK(gWrites == 1 && gPreparations == 1 && owner.uptimeValue == 43200 && !owner.error, "busy reentrant uptime generation does not revoke its outer owner");
    [owner adoptCommittedUptimeInfo:a timestamp:a[@"boot"][@"lastUpdated"]];
    gDuringClock = ^{ [owner adoptCommittedUptimeInfo:b timestamp:b[@"boot"][@"lastUpdated"]]; };
    [owner setCurrentUptime:300];
    CHECK(owner.uptimeValue == 200, "setter clock preparation cannot claim over newer reentrant adoption");
    [owner setCurrentUptime:NAN]; CHECK(owner.error.code == 1001 && owner.uptimeValue == 200, "nonfinite uptime setter cannot poison cached tuple");
    [owner setCurrentBootTime:(id)[PXInvalidDate new]]; CHECK(owner.error.code == 1002 && owner.uptimeValue == 200, "nonfinite date-like setter fails before date arithmetic");
    [owner setCurrentUptime:300];
    CHECK(owner.uptimeValue == 300 && owner.bootTimeValue.timeIntervalSince1970 + owner.uptimeValue == owner.cacheTime.timeIntervalSince1970 && owner.error.code == 1002,
          "valid uptime setter uses one clock and preserves legacy prior-error policy");
    [owner adoptCommittedUptimeInfo:a timestamp:gNow];
    NSUInteger captures = atomic_load(&gCaptures);
    gDuringCapture = ^{ [owner adoptCommittedUptimeInfo:b timestamp:b[@"boot"][@"lastUpdated"]]; };
    NSString *debug = [owner debugSpoofedUptimeInfo];
    CHECK([debug containsString:@"100 seconds"] && [debug containsString:@"timestamp: 1999900"] && atomic_load(&gCaptures) == captures + 1,
          "debug formatting consumes exactly one captured tuple outside cache monitor");
}
static void TestPreparedAndStageBoundaries(void) {
    Reset();
    NSDictionary *valid = Packet(43200, gNow);
    NSMutableArray *bad = [NSMutableArray arrayWithObjects:@[], @{ @"boot": @[] }, nil];
    for (NSString *field in @[@"seconds", @"boot", @"uptime"]) {
        NSMutableDictionary *packet = [valid mutableCopy];
        if ([field isEqual:@"seconds"]) packet[field] = @(INFINITY);
        else {
            NSMutableDictionary *child = [packet[field] mutableCopy];
            child[@"value"] = [field isEqual:@"boot"] ? (id)NSNull.null : (id)@(NAN); packet[field] = child;
        }
        [bad addObject:packet];
    }
    for (id raw in bad) {
        PXUptimeFixture *owner = [PXUptimeFixture new];
        [owner adoptCommittedUptimeInfo:valid timestamp:gNow];
        gPacketOverride = raw; NSUInteger writes = gWrites, sets = gSets;
        [owner generateConsistentUptimeAndBootTimeForProfile:Identity()];
        CHECK(owner.error.code == 1002 && owner.uptimeValue == 43200 && gWrites == writes && gSets == sets && !gHeld,
              "malformed uptime provider packets reject before source staging and preserve prior cache");
    }
    Reset(); PXUptimeFixture *owner = [PXUptimeFixture new];
    NSMutableString *elapsed = [@"43200" mutableCopy], *seconds = [@"43200" mutableCopy];
    NSMutableDictionary *boot = [Packet(43200, gNow)[@"boot"] mutableCopy];
    NSMutableDictionary *uptime = [Packet(43200, gNow)[@"uptime"] mutableCopy]; uptime[@"value"] = elapsed;
    NSMutableDictionary *packet = [@{ @"boot": boot, @"uptime": uptime, @"seconds": seconds } mutableCopy];
    gPacketOverride = packet;
    gBeforeSource = ^{ boot[@"value"] = [NSDate dateWithTimeIntervalSince1970:123]; [elapsed setString:@"7"]; [seconds setString:@"8"]; };
    [owner generateConsistentUptimeAndBootTimeForProfile:Identity()];
    CHECK(gWrites == 1 && !owner.error && owner.uptimeValue == 43200 &&
          [gFiles[File(@"device_ids.plist")][@"SystemUptime"] isEqual:@"43200"] &&
          [gFiles[File(@"boot_time.plist")][@"value"] timeIntervalSince1970] == 1956800,
          "uptime preparation freezes required nested fields before source callbacks");
    Reset();
    NSMutableString *identity = [Identity() mutableCopy]; elapsed = [@"123" mutableCopy];
    boot = [Packet(123, gNow)[@"boot"] mutableCopy]; uptime = [Packet(123, gNow)[@"uptime"] mutableCopy]; uptime[@"value"] = elapsed;
    gDuringTxRead = ^{ [identity setString:PXProfileIdentityPath(@"b")]; boot[@"value"] = [NSDate dateWithTimeIntervalSince1970:99]; [elapsed setString:@"666"]; };
    PXRuntimeSourceTransaction *tx = [PXRuntimeSourceTransaction new];
    CHECK(PXStageRuntimeUptime(tx, identity, boot, uptime, gNow, NULL) &&
          [tx.staged[File(@"device_ids.plist")][@"SystemUptime"] isEqual:@"123"] &&
          [tx.staged[File(@"boot_time.plist")][@"value"] timeIntervalSince1970] == 1999877 && tx.staged.count == 3 && !gHeld && !gWrites,
          "direct uptime staging freezes identity and known fields without acquiring ownership");
}
static void TestPreparationAndWeakExit(void) {
    Reset(); PXUptimeFixture *owner = [PXUptimeFixture new];
    [owner prepareConsistentUptimeInfo]; CHECK(gHasReal, "valid sysctl result is passed to unchanged pure preparation");
    gSysSize = 0; [owner prepareConsistentUptimeInfo]; CHECK(!gHasReal, "short sysctl output cannot become real uptime input");
    gSysSize = sizeof(struct timeval); gBootSeconds = 3000000; [owner prepareConsistentUptimeInfo]; CHECK(!gHasReal, "future system boot time uses unavailable-real-time policy");
    for (NSString *fault in @[@"acquire", @"provider", @"tx-read", @"tx-set", @"partial", @"read"]) {
        Reset(); __weak id weakOwner = nil, weakToken = nil, weakInput = nil;
        @autoreleasepool {
            PXUptimeFixture *manager = [PXUptimeFixture new]; weakOwner = manager;
            id token = [NSObject new]; weakToken = token;
            NSMutableDictionary *packet = [Packet(43200, gNow) mutableCopy]; NSMutableDictionary *boot = [packet[@"boot"] mutableCopy]; boot[@"retain"] = token; packet[@"boot"] = boot;
            gPacketOverride = packet;
            NSMutableString *path = [Identity() mutableCopy]; weakInput = path; gFault = fault; if ([fault isEqual:@"partial"]) gFailSetAt = 2;
            if ([fault isEqual:@"read"]) {
                BOOL threw = NO; @try { [manager currentUptimeForProfile:path generateIfMissing:NO]; }
                @catch (NSException *exception) { threw = [exception.name isEqual:@"fixture.uptime"]; }
                CHECK(threw, "uptime read collaborator exception retains propagation policy");
            } else { [manager generateConsistentUptimeAndBootTimeForProfile:path]; CHECK(manager.error.code == 1002 && !gWrites, "uptime generation exceptional path retains error code without source success"); }
            CHECK(!gHeld && !gInsideSource, "uptime exceptional exit releases owned capability");
            gPacketOverride = nil; [gFiles removeAllObjects]; manager = nil; path = nil; packet = nil; boot = nil; token = nil;
        }
        if (weakOwner || weakToken || weakInput || gOwnerRoot || gIdentityRoot || gTxRoot || gCallbackRoots.allObjects.count)
            fprintf(stderr, "DETAIL: uptime fault=%s owner=%d token=%d input=%d capability=%d identity=%d tx=%d blocks=%lu\n", fault.UTF8String, weakOwner != nil, weakToken != nil, weakInput != nil, gOwnerRoot != nil, gIdentityRoot != nil, gTxRoot != nil, (unsigned long)gCallbackRoots.allObjects.count);
        CHECK(!weakOwner && !weakToken && !weakInput && !gOwnerRoot && !gIdentityRoot && !gTxRoot && !gCallbackRoots.allObjects.count, "uptime exceptional exit releases prepared partial records input and block captures after pool drain");
    }
}
static void TestConcurrencyAndDeferredRelease(void) {
    Reset(); PXObservedUptime *owner = [PXObservedUptime new]; NSDictionary *a = Packet(100, gNow), *b = Packet(200, [gNow dateByAddingTimeInterval:10]);
    [owner adoptCommittedUptimeInfo:a timestamp:gNow]; __block _Atomic NSUInteger mixed = 0;
    dispatch_apply(256, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
        @autoreleasepool {
            NSDictionary *packet = index % 2 ? a : b;
            [owner adoptCommittedUptimeInfo:packet timestamp:packet[@"boot"][@"lastUpdated"]];
            NSTimeInterval seconds = 0; NSDate *clock = nil;
            NSDate *boot = [owner captureUptimeSeconds:&seconds cacheTime:&clock error:NULL];
            if (boot.timeIntervalSince1970 + seconds != clock.timeIntervalSince1970 || (seconds != 100 && seconds != 200)) atomic_fetch_add(&mixed, 1);
        }
    });
    CHECK(!atomic_load(&mixed) && !gWrites && !gReads && !gPreparations, "concurrent uptime adoption and capture never expose mixed tuple or perform I/O");
    @autoreleasepool {
        PXUptimeReleaseProbe *probe = [PXUptimeReleaseProbe new];
        NSError *error = [NSError errorWithDomain:@"fixture.release" code:1 userInfo:@{ @"probe": probe }];
        [owner setUptimeError:error epoch:[owner captureUptimeEpoch]]; error = nil; probe = nil;
    }
    dispatch_group_t group = dispatch_group_create(); dispatch_semaphore_t done = dispatch_semaphore_create(0); __block BOOL released = NO;
    gDuringDealloc = ^{
        dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ @autoreleasepool { (void)[owner captureUptimeEpoch]; dispatch_semaphore_signal(done); } });
        released = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0;
    };
    [owner adoptCommittedUptimeInfo:a timestamp:gNow]; dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    CHECK(released, "discarded uptime error metadata deallocates outside cache monitor");
}
int main(void) { @autoreleasepool {
    @try { TestTypedReaders(); TestCacheAndOrdering(); TestPreparedAndStageBoundaries(); TestPreparationAndWeakExit(); TestConcurrencyAndDeferredRelease(); }
    @catch (NSException *exception) { gFailures++; fprintf(stderr, "FAIL: unexpected uptime exception: %s\n", exception.description.UTF8String); }
    printf("Uptime boundaries: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks); return gFailures ? 1 : 0;
} }
