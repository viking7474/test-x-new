#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#include <math.h>
#include <stdint.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
static NSUInteger gChecks, gFailures, gReads, gAttempts, gLocal, gDarwin, gPreparations;
static BOOL gSucceed;
static NSMutableDictionary *gFiles;
static NSMutableArray *gRecords;
static NSString *gReadTarget;
static void (^gDuringRead)(void), (^gDuringPrepare)(void), (^gDuringRecord)(void), (^gDuringDealloc)(void), (^gDuringErrorAccess)(void);
static void (^gDuringPersist)(NSDictionary *, uint64_t);
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PXLog(...) do {} while (0)
#define BATTERY_PLIST_PATH @"/fixture/global.plist"
#define kBatteryLevelKey @"BatteryLevel"
#define kLowPowerModeKey @"LowPowerMode"
#define kLastUpdatedKey @"LastUpdated"
static NSString *PXCurrentProfileInfoPath(void) { return @"/fixture/selection.plist"; }
static NSString *PXValidatedProfileID(id value) { return [value isKindOfClass:NSString.class] && ([value isEqual:@"a"] || [value isEqual:@"b"]) ? value : nil; }
static NSString *PXProfileIdentityPath(NSString *profile) { return profile ? [@"/fixture" stringByAppendingPathComponent:[profile stringByAppendingPathComponent:@"identity"]] : nil; }
@interface NSDictionary (BatteryCacheFixture)
+ (instancetype)px_cacheRead:(NSString *)path;
@end
@implementation NSDictionary (BatteryCacheFixture)
+ (instancetype)px_cacheRead:(NSString * __unsafe_unretained)path {
    gReads++; id value = gFiles[path];
    void (^callback)(void) = [path isEqual:gReadTarget] ? gDuringRead : nil;
    if (callback) gDuringRead = nil;
    @try { if (callback) callback(); return value; }
    @finally { callback = nil; value = nil; }
}
@end
static NSString *PXPrepareRuntimeBatteryLevel(void) {
    gPreparations++; void (^callback)(void) = gDuringPrepare; gDuringPrepare = nil;
    @try { if (callback) callback(); return @"0.41"; }
    @finally { callback = nil; }
}
static NSDictionary *PXPrepareRuntimeBatteryInfo(BOOL enabled) {
    return @{ @"BatteryLevel": PXPrepareRuntimeBatteryLevel(), @"LowPowerMode": @(enabled), @"BatteryPercentage": @41 };
}
static void PXCacheDarwin(CFNotificationCenterRef center, CFStringRef name, const void *object, CFDictionaryRef info, Boolean immediate) {
    (void)center; (void)name; (void)object; (void)info; (void)immediate; gDarwin++;
}
#include "PXBatteryCacheFields.inc"
@interface PXBatteryCacheFixture : NSObject {
    NSString *_currentBatteryLevel;
    BOOL _currentLowPowerMode, _lowPowerModeLoaded;
}
@property (atomic, strong) NSError *error;
#include "PXBatteryCacheDeclarations.inc"
#include "PXBatteryCacheFlowDeclarations.inc"
- (BOOL)persistBatteryRecord:(NSDictionary *)record;
- (BOOL)persistBatteryRecord:(NSDictionary *)record mutation:(uint64_t)receipt;
- (BOOL)mirrorBatteryRecord:(NSDictionary *)record error:(NSError **)error;
@end
@implementation PXBatteryCacheFixture
@synthesize error = _error;
- (instancetype)init { if ((self = [super init])) _currentBatteryLevel = @"0.75"; return self; }
- (BOOL)persistBatteryRecord:(NSDictionary *)record { uint64_t receipt = 0; (void)[self captureBatteryLevel:NULL loaded:NULL revision:NULL mutation:&receipt]; return [self persistBatteryRecord:record mutation:receipt]; }
- (BOOL)persistBatteryRecord:(NSDictionary *)record mutation:(uint64_t)receipt {
    if (![self batteryMutationIsCurrent:receipt]) return NO;
    gAttempts++; BOOL success = record && gSucceed;
    void (^callback)(NSDictionary *, uint64_t) = gDuringPersist; gDuringPersist = nil;
    @try {
        if (callback) callback(record, receipt);
        if (success) [gRecords addObject:record];
        [self setBatteryError:(success ? nil : [NSError errorWithDomain:@"fixture" code:(record ? 104 : 103) userInfo:nil]) mutation:receipt];
        return success;
    } @finally { callback = nil; record = nil; }
}
- (BOOL)mirrorBatteryRecord:(NSDictionary *)record error:(NSError **)error { (void)record; if (error) *error = nil; return YES; }
#define dictionaryWithContentsOfFile px_cacheRead
#define CFNotificationCenterPostNotification PXCacheDarwin
#define CFNotificationCenterGetDarwinNotifyCenter() NULL
#include "PXBatteryCacheMethods.inc"
#include "PXBatteryCacheFlowMethods.inc"
#undef CFNotificationCenterGetDarwinNotifyCenter
#undef CFNotificationCenterPostNotification
#undef dictionaryWithContentsOfFile
@end
@interface PXObservedCacheFixture : PXBatteryCacheFixture @end
@implementation PXObservedCacheFixture
- (NSError *)error {
    void (^callback)(void) = gDuringErrorAccess; gDuringErrorAccess = nil;
    @try { if (callback) callback(); return [super error]; }
    @finally { callback = nil; }
}
- (NSDictionary *)batteryRecordForLevel:(NSString *)level lowPowerMode:(BOOL)enabled {
    NSDictionary *record = nil;
    void (^callback)(void) = gDuringRecord; gDuringRecord = nil;
    @try { record = [super batteryRecordForLevel:level lowPowerMode:enabled]; if (callback) callback(); return record; }
    @finally { callback = nil; record = nil; level = nil; }
}
@end
@interface PXCacheCopyProbe : NSObject <NSCopying> @end
@implementation PXCacheCopyProbe
- (BOOL)isKindOfClass:(Class)type { return type == NSString.class || [super isKindOfClass:type]; }
- (id)copyWithZone:(NSZone *)zone {
    (void)zone; void (^callback)(void) = gDuringRecord; gDuringRecord = nil;
    @try { if (callback) callback(); return @"0.22"; }
    @finally { callback = nil; }
}
@end
@interface PXCacheValidationProbe : NSObject <NSCopying> @end
@implementation PXCacheValidationProbe
- (BOOL)isKindOfClass:(Class)type { return type == NSString.class || [super isKindOfClass:type]; }
- (NSUInteger)length { return 1; }
- (id)copyWithZone:(NSZone *)zone { (void)zone; return self; }
- (float)floatValue {
    void (^callback)(void) = gDuringRecord; gDuringRecord = nil;
    @try { if (callback) callback(); return 0; }
    @finally { callback = nil; }
}
@end
@interface PXCacheReleaseProbe : NSObject @end
@implementation PXCacheReleaseProbe
- (void)dealloc { void (^callback)(void) = gDuringDealloc; gDuringDealloc = nil; if (callback) callback(); }
@end
static NSString *Canonical(void) { return @"/fixture/a/identity/battery_info.plist"; }
static NSDictionary *Pair(NSString *level, BOOL enabled) { return @{ @"BatteryLevel": level, @"LowPowerMode": @(enabled) }; }
static void RunWorker(dispatch_block_t work) {
    dispatch_semaphore_t done = dispatch_semaphore_create(0); __block BOOL raised = NO;
    [NSThread detachNewThreadWithBlock:^{ @autoreleasepool {
        @try { work(); } @catch (__unused NSException *exception) { raised = YES; }
        @finally { dispatch_semaphore_signal(done); }
    } }];
    long timeout = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    CHECK(!timeout && !raised, "battery collaborators and discarded roots execute outside the cache monitor");
    if (timeout) exit(1);
}
static PXObservedCacheFixture *Reset(void) {
    gFiles = [NSMutableDictionary new]; gRecords = [NSMutableArray new];
    gFiles[PXCurrentProfileInfoPath()] = @{ @"ProfileId": @"a" };
    gReads = gAttempts = gLocal = gDarwin = gPreparations = 0; gSucceed = YES;
    gDuringRead = gDuringPrepare = gDuringRecord = gDuringDealloc = gDuringErrorAccess = nil; gDuringPersist = nil; gReadTarget = Canonical();
    return [PXObservedCacheFixture new];
}
static void TestStaleLoad(void) {
    PXObservedCacheFixture *owner = Reset(); gFiles[Canonical()] = Pair(@"0.2", NO);
    gDuringRead = ^{ RunWorker(^{ [owner adoptCommittedBatteryInfo:Pair(@"0.8", YES)]; }); };
    [owner loadBatteryInfoFromDisk]; BOOL enabled = NO;
    NSString *level = [owner captureBatteryLevel:&enabled loaded:NULL revision:NULL mutation:NULL];
    CHECK([level isEqual:@"0.8"] && enabled && !gAttempts, "old battery load cannot overwrite a newer committed cache pair");
    owner = Reset(); gFiles[Canonical()] = Pair(@"0.2", NO);
    gDuringRead = ^{ RunWorker(^{ gFiles[Canonical()] = Pair(@"0.7", YES); [owner loadBatteryInfoFromDisk]; }); };
    [owner loadBatteryInfoFromDisk]; level = [owner captureBatteryLevel:&enabled loaded:NULL revision:NULL mutation:NULL];
    CHECK([level isEqual:@"0.7"] && enabled && !gAttempts, "newer battery load sequence wins when an older disk read completes last");
    owner = Reset(); gFiles[Canonical()] = Pair(@"0.2", NO);
    gDuringRead = ^{ RunWorker(^{ [owner setBatteryLevel:@"0.9"]; }); };
    [owner loadBatteryInfoFromDisk];
    CHECK([[owner captureBatteryLevel:NULL loaded:NULL revision:NULL mutation:NULL] isEqual:@"0.9"] && gAttempts == 1,
          "old battery load cannot overwrite a new setter candidate or trigger a second save");
}
static void TestWriters(void) {
    PXObservedCacheFixture *owner = Reset(); NSMutableString *input = [@" 0.62 " mutableCopy];
    [owner setBatteryLevel:input]; [input setString:@"0.1"];
    CHECK([[owner captureBatteryLevel:NULL loaded:NULL revision:NULL mutation:NULL] isEqual:@" 0.62 "] && [gRecords.lastObject[@"BatteryLevel"] isEqual:@" 0.62 "] && gAttempts == 1,
          "battery setter freezes caller string once for cache and captured persistence record");
    owner = Reset(); gDuringRecord = ^{ RunWorker(^{ [owner setBatteryLevel:@"0.8"]; }); };
    [owner setBatteryLevel:@"0.2"];
    CHECK(gAttempts == 1 && [gRecords.lastObject[@"BatteryLevel"] isEqual:@"0.8"] && [[owner captureBatteryLevel:NULL loaded:NULL revision:NULL mutation:NULL] isEqual:@"0.8"],
          "superseded battery record creation never persists or relabels a newer cache value");
    owner = Reset(); gDuringRecord = ^{ [owner setBatteryLevel:@"0.9"]; };
    [owner setBatteryLevel:(id)[PXCacheCopyProbe new]];
    CHECK(gAttempts == 1 && [gRecords.lastObject[@"BatteryLevel"] isEqual:@"0.9"], "older battery input copy cannot supersede a reentrant setter");
    owner = Reset(); gDuringPrepare = ^{ [owner setBatteryLevel:@"0.8"]; };
    NSString *candidate = [owner randomizeBatteryLevel];
    CHECK([candidate isEqual:@"0.41"] && gAttempts == 1 && [gRecords.lastObject[@"BatteryLevel"] isEqual:@"0.8"],
          "superseded public battery generation preserves candidate return without obsolete persistence");
    owner = Reset(); gSucceed = NO; NSDictionary *info = [owner generateBatteryInfo];
    CHECK([info[@"BatteryLevel"] isEqual:@"0.41"] && [[owner captureBatteryLevel:NULL loaded:NULL revision:NULL mutation:NULL] isEqual:@"0.41"] && gAttempts == 1 && owner.lastError,
          "battery failed persistence keeps cache-first candidate and reports failure");
    owner = Reset(); [owner setBatteryLevel:nil]; CHECK(gAttempts == 0, "battery nil setter preserves clear without save");
    [owner setLowPowerModeEnabled:YES]; CHECK(gAttempts == 1 && owner.lastError.code == 103, "battery LPM with missing level reports missing record without success effects");
    owner = Reset(); [owner setBatteryLevel:(id)@[]]; [owner adoptCommittedBatteryInfo:(id)@[]];
    CHECK(gAttempts == 0 && [[owner captureBatteryLevel:NULL loaded:NULL revision:NULL mutation:NULL] isEqual:@"0.75"], "unsupported battery writer inputs never poison cache or initiate persistence");
}
static void TestPendingReads(void) {
    PXObservedCacheFixture *owner = Reset(); gFiles[Canonical()] = Pair(@"0.2", NO);
    __block BOOL preserved = NO;
    gDuringPersist = ^(NSDictionary *record, uint64_t receipt) {
        (void)record; (void)receipt; NSUInteger reads = gReads;
        RunWorker(^{ [owner loadBatteryInfoFromDisk]; });
        preserved = gReads == reads && [[owner captureBatteryLevel:NULL loaded:NULL revision:NULL mutation:NULL] isEqual:@"0.8"];
    };
    [owner setBatteryLevel:@"0.8"];
    CHECK(preserved && gAttempts == 1, "pending battery mutation serves its candidate without obsolete disk reads or adoption");
    [owner loadBatteryInfoFromDisk];
    CHECK(gReads == 2 && [[owner captureBatteryLevel:NULL loaded:NULL revision:NULL mutation:NULL] isEqual:@"0.2"],
          "battery completion releases pending ownership and subsequent explicit reads keep disk-first policy");
    owner = Reset(); uint64_t receipt = [owner beginBatteryMutation];
    [owner publishBatteryLevel:@"0.9" lowPowerMode:NO loaded:NO fields:PXBatteryCacheLevel mutation:receipt resultLevel:NULL resultLowPowerMode:NULL];
    uint64_t sequence = 0, revision = [owner beginBatteryLoad:&sequence];
    [owner finishBatteryMutation:receipt];
    [owner applyLoadedBatteryInfo:Pair(@"0.2", NO) profileSpecific:YES revision:revision sequence:sequence];
    CHECK(!sequence && [[owner captureBatteryLevel:NULL loaded:NULL revision:NULL mutation:NULL] isEqual:@"0.9"],
          "finishing battery mutation revokes even an old pending-load receipt");
    owner = Reset(); gSucceed = NO; [owner setBatteryLevel:@"0.8"];
    gFiles[Canonical()] = Pair(@"0.3", YES); [owner loadBatteryInfoFromDisk];
    CHECK([[owner captureBatteryLevel:NULL loaded:NULL revision:NULL mutation:NULL] isEqual:@"0.3"],
          "battery failed persistence also releases pending ownership without blocking future reads");
}
static void TestRepairAndErrors(void) {
    PXObservedCacheFixture *owner = Reset(); uint64_t current = 0;
    (void)[owner captureBatteryLevel:NULL loaded:NULL revision:NULL mutation:&current];
    __block BOOL callbackRan = NO;
    gDuringErrorAccess = ^{ RunWorker(^{ (void)[owner captureBatteryLevel:NULL loaded:NULL revision:NULL mutation:NULL]; }); callbackRan = YES; };
    [owner setBatteryError:[NSError errorWithDomain:@"fixture" code:505 userInfo:nil] mutation:current];
    CHECK(!callbackRan, "battery logical error publication never invokes property callbacks inside its monitor");
    NSError *capturedError = owner.lastError;
    CHECK(callbackRan && capturedError.code == 505, "battery public error read permits property reentry outside the cache monitor");
    owner = Reset();
    gFiles[Canonical()] = Pair((id)[PXCacheValidationProbe new], NO);
    gDuringRecord = ^{ [owner adoptCommittedBatteryInfo:Pair(@"0.8", YES)]; };
    CHECK([[owner batteryLevel] isEqual:@"0.8"] && !gPreparations && !gAttempts,
          "superseded invalid battery observation never initiates generation");
    owner = Reset(); gDuringPrepare = ^{ [NSException raise:@"fixture.prepare" format:@"provider failed"]; };
    BOOL raised = NO;
    @try { [owner randomizeBatteryLevel]; } @catch (__unused NSException *exception) { raised = YES; }
    gFiles[Canonical()] = Pair(@"0.3", YES); [owner loadBatteryInfoFromDisk];
    CHECK(raised && !gAttempts && gReads == 2 && [[owner captureBatteryLevel:NULL loaded:NULL revision:NULL mutation:NULL] isEqual:@"0.3"],
          "battery provider exception releases pending ownership before later reads");
    owner = Reset(); gFiles[Canonical()] = Pair(@"0", NO);
    gDuringPrepare = ^{ [owner adoptCommittedBatteryInfo:Pair(@"0.8", YES)]; };
    CHECK([[owner batteryLevel] isEqual:@"0.8"] && gPreparations == 1 && !gAttempts,
          "superseded battery getter repair returns latest valid cache without saving its candidate");
    owner = Reset(); gFiles[Canonical()] = Pair(@"0", NO);
    CHECK([[owner batteryLevel] isEqual:@"0.41"] && gAttempts == 1 && gPreparations == 1,
          "battery invalid getter makes one captured repair and one persistence attempt");
    owner = Reset(); gSucceed = NO;
    gDuringPersist = ^(NSDictionary *record, uint64_t receipt) { (void)record; (void)receipt; [owner adoptCommittedBatteryInfo:Pair(@"0.8", YES)]; };
    [owner setBatteryLevel:@"0.2"];
    CHECK(!owner.lastError && [[owner captureBatteryLevel:NULL loaded:NULL revision:NULL mutation:NULL] isEqual:@"0.8"],
          "late battery persistence error cannot overwrite a newer committed adoption result");
    owner = Reset();
    gDuringPersist = ^(NSDictionary *record, uint64_t receipt) {
        (void)record; (void)receipt; [owner adoptCommittedBatteryInfo:Pair(@"0.8", YES)];
        uint64_t newer = 0; (void)[owner captureBatteryLevel:NULL loaded:NULL revision:NULL mutation:&newer];
        [owner setBatteryError:[NSError errorWithDomain:@"fixture" code:909 userInfo:nil] mutation:newer];
    };
    [owner setBatteryLevel:@"0.2"];
    CHECK(owner.lastError.code == 909 && [gRecords.lastObject[@"BatteryLevel"] isEqual:@"0.2"],
          "accepted battery source success retains captured record without clearing a newer mutation error");
}
static void TestNotificationsAndPairs(void) {
    PXObservedCacheFixture *owner = Reset();
    id observer = [NSNotificationCenter.defaultCenter addObserverForName:@"BatteryInfoUpdated" object:owner queue:nil usingBlock:^(NSNotification *note) {
        gLocal++; CHECK(gAttempts > 0 && [note.userInfo[@"BatteryLevel"] isEqual:gRecords.lastObject[@"BatteryLevel"]], "battery notification follows captured successful persistence record");
        RunWorker(^{ BOOL enabled = NO; (void)[owner captureBatteryLevel:&enabled loaded:NULL revision:NULL mutation:NULL]; });
    }];
    @try {
        [owner setLowPowerModeEnabled:YES]; [owner generateBatteryInfo];
        CHECK(gAttempts == 2 && gLocal == 2 && gDarwin == 2, "battery mutations save once before both notifications outside cache monitor");
        gSucceed = NO; [owner setLowPowerModeEnabled:NO]; [owner generateBatteryInfo];
        CHECK(gAttempts == 4 && gLocal == 2 && gDarwin == 2, "failed battery mutations suppress both success notifications");
    } @finally { [NSNotificationCenter.defaultCenter removeObserver:observer]; }
    owner = Reset(); [owner adoptCommittedBatteryInfo:Pair(@"0.2", NO)];
    __block _Atomic NSUInteger mixed = 0;
    dispatch_apply(256, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^(size_t index) { @autoreleasepool {
        BOOL enabled = (index % 2) != 0; uint64_t receipt = [owner beginBatteryMutation];
        [owner publishBatteryLevel:(enabled ? @"0.8" : @"0.2") lowPowerMode:enabled loaded:YES fields:(PXBatteryCacheLevel | PXBatteryCacheLowPower | PXBatteryCacheLoaded) mutation:receipt resultLevel:NULL resultLowPowerMode:NULL];
        [owner finishBatteryMutation:receipt];
        BOOL captured = NO; NSString *level = [owner captureBatteryLevel:&captured loaded:NULL revision:NULL mutation:NULL];
        if (![level isEqual:(captured ? @"0.8" : @"0.2")]) atomic_fetch_add(&mixed, 1);
    } });
    CHECK(atomic_load(&mixed) == 0 && !gAttempts, "concurrent battery pair publication and capture never observe mixed fields");
    owner = Reset();
    @autoreleasepool {
        id probe = [PXCacheReleaseProbe new]; uint64_t receipt = [owner beginBatteryMutation];
        [owner publishBatteryLevel:probe lowPowerMode:NO loaded:NO fields:PXBatteryCacheLevel mutation:receipt resultLevel:NULL resultLowPowerMode:NULL];
    }
    __block BOOL released = NO;
    gDuringDealloc = ^{ RunWorker(^{ (void)[owner captureBatteryLevel:NULL loaded:NULL revision:NULL mutation:NULL]; }); released = YES; };
    [owner adoptCommittedBatteryInfo:Pair(@"0.8", YES)];
    CHECK(released, "discarded battery cache root deallocates after monitor release");
}
int main(void) { @autoreleasepool {
    @try { TestStaleLoad(); TestWriters(); TestPendingReads(); TestRepairAndErrors(); TestNotificationsAndPairs(); }
    @catch (NSException *exception) { gFailures++; fprintf(stderr, "FAIL: unexpected battery cache exception: %s\n", exception.description.UTF8String); }
    printf("Battery cache flow: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
    return gFailures ? 1 : 0;
} }
