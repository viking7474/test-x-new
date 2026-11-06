#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static NSUInteger gChecks, gFailures, gReads, gPaths, gCopies;
static BOOL gThrowCopy;
static id gResolutionManager;
static BOOL gThrowManager, gThrowProfile, gThrowProfileID;
static void (^gDuringResolve)(void);
static NSUInteger gResolutionCalls;
static NSMutableDictionary *gFiles;
static void (^gDuringRead)(void);
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
static NSString *PXValidatedProfileID(NSString *value) {
    return [value isKindOfClass:NSString.class] && ([value isEqual:@"a"] || [value isEqual:@"b"]) ? value : nil;
}
static NSString *PXProfileIdentityPath(NSString *value) {
    gPaths++; return value ? [@"/fixture/" stringByAppendingString:value] : nil;
}
static NSString *PXCurrentProfileInfoPath(void) { return @"/fixture/selection.plist"; }
@interface NSDictionary (CacheFixture)
+ (instancetype)cacheFixtureRead:(NSString *)path;
@end
@implementation NSDictionary (CacheFixture)
+ (instancetype)cacheFixtureRead:(NSString * __unsafe_unretained)path {
    gReads++; id value = gFiles[path];
    void (^callback)(void) = gDuringRead; gDuringRead = nil;
    @try { if (callback) callback(); return value; }
    @finally { callback = nil; }
}
@end
@interface PXResolutionProfile : NSObject
@property (nonatomic, strong) id profileId;
@end
@interface PXResolutionManager : NSObject
@property (nonatomic, strong) id profile;
- (id)currentProfile;
@end
@interface PXCacheWiFi : NSObject
@property (atomic, strong) NSMutableDictionary *wifiInfo;
@property (atomic, strong) NSString *currentProfileId;
@property (atomic, strong) NSError *error;
@property (nonatomic) uint64_t wifiCacheRevision;
@property (nonatomic) BOOL wifiCacheReadable;
#include "PXWiFiCacheCoreDeclarations.inc"
#include "PXWiFiCacheReaderDeclarations.inc"
#include "PXWiFiResolutionDeclarations.inc"
- (id)profileManagerForWiFi;
- (void)loadWiFiInfoForProfileID:(NSString *)profileID;
- (uint64_t)loadWiFiInfoForProfileID:(NSString *)profileID revision:(uint64_t)revision;
- (void)adoptCommittedWiFiInfo:(NSDictionary *)info profileID:(NSString *)profile;
- (NSDictionary *)cachedWiFiInfoForProfileID:(NSString *)profile;
@end
@implementation PXCacheWiFi
- (id)profileManagerForWiFi {
    if (gThrowManager) [NSException raise:@"fixture.manager" format:@"factory failed"];
    return gResolutionManager;
}
#define dictionaryWithContentsOfFile cacheFixtureRead
#include "PXWiFiManagerCacheMethods.inc"
#undef dictionaryWithContentsOfFile
@end
@interface PXCacheCopySpy : NSObject <NSCopying, NSMutableCopying>
@property (nonatomic, copy) NSDictionary *record;
@property (nonatomic, copy) void (^duringCopy)(void);
@end
@implementation PXCacheCopySpy
- (BOOL)isKindOfClass:(Class)type { return type == NSDictionary.class || [super isKindOfClass:type]; }
- (id)prepareCopy:(BOOL)mutable {
    gCopies++;
    if (gThrowCopy) [NSException raise:@"fixture.copy" format:@"copy failed"];
    id result = mutable ? [self.record mutableCopy] : [self.record copy];
    void (^callback)(void) = self.duringCopy; self.duringCopy = nil;
    @try { if (callback) callback(); return result; }
    @finally { callback = nil; result = nil; }
}
- (id)copyWithZone:(NSZone *)zone { (void)zone; return [self prepareCopy:NO]; }
- (id)mutableCopyWithZone:(NSZone *)zone { (void)zone; return [self prepareCopy:YES]; }
@end
@interface PXCacheDestructor : NSObject
@property (nonatomic, copy) void (^onDeath)(void);
@end
@implementation PXCacheDestructor
- (void)dealloc { if (_onDeath) _onDeath(); }
@end
static NSDictionary *Record(NSString *value) { return @{ @"ssid": value, @"bssid": @"02:11:22:33:44:55" }; }
static uint64_t Publish(PXCacheWiFi *manager, id info, NSString *profile) {
    return [manager publishWiFiCache:info profileID:profile revision:[manager beginWiFiCacheUpdate] readable:YES];
}
static PXCacheCopySpy *Spy(NSDictionary *record) { PXCacheCopySpy *spy = [PXCacheCopySpy new]; spy.record = record; return spy; }
static void Wait(dispatch_semaphore_t done) {
    long result = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    CHECK(result == 0, "cache collaborator may finish work on another thread without a held monitor");
    if (result) exit(1);
}
static void TestSnapshotABA(void) {
    PXCacheWiFi *manager = [PXCacheWiFi new];
    NSDictionary *a = Record(@"old A"), *b = Record(@"B"), *newA = Record(@"new A");
    [manager adoptCommittedWiFiInfo:a profileID:@"a"];
    CHECK([[manager cachedWiFiInfoForProfileID:@"a"] isEqual:a] && ![manager cachedWiFiInfoForProfileID:@"b"], "read-only cache admits only matching owned pair");
    NSUInteger reads = gReads, paths = gPaths;
    PXCacheCopySpy *spy = Spy(a);
    spy.duringCopy = ^{ [manager adoptCommittedWiFiInfo:b profileID:@"b"]; [manager adoptCommittedWiFiInfo:newA profileID:@"a"]; };
    Publish(manager, spy, @"a");
    CHECK(![manager cachedWiFiInfoForProfileID:@"a"] && [[manager cachedWiFiInfoForProfileID:@"a"] isEqual:newA], "A B A during copy rejects stale bytes despite matching final profile ID");
    CHECK(gReads == reads && gPaths == paths, "read-only cache API performs no path or file resolution");
    spy = Spy(a);
    spy.duringCopy = ^{ [manager adoptCommittedWiFiInfo:newA profileID:@"a"]; };
    Publish(manager, spy, @"a");
    CHECK(![manager cachedWiFiInfoForProfileID:@"a"] && [[manager cachedWiFiInfoForProfileID:@"a"] isEqual:newA], "same-profile newer adoption invalidates an older copying reader");
    spy = Spy(a);
    spy.duringCopy = ^{
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        [NSThread detachNewThreadWithBlock:^{ [manager adoptCommittedWiFiInfo:b profileID:@"b"]; dispatch_semaphore_signal(done); }];
        Wait(done);
    };
    Publish(manager, spy, @"a");
    CHECK(![manager cachedWiFiInfoForProfileID:@"a"] && [[manager cachedWiFiInfoForProfileID:@"b"] isEqual:b], "copy callback runs outside monitor and cannot return a displaced pair");
    uint64_t revision = [manager beginWiFiCacheUpdate];
    CHECK(![manager cachedWiFiInfoForProfileID:@"b"], "pending candidate is not exposed as acknowledged read-only cache");
    [manager publishWiFiCache:[a mutableCopy] profileID:@"a" revision:revision readable:NO];
    CHECK(![manager cachedWiFiInfoForProfileID:@"a"] && [[manager wiFiCacheSnapshotForProfileID:@"a" requireReadable:NO] isEqual:a], "legacy candidate stays available while hook fallback excludes unacknowledged data");
    revision = [manager beginWiFiCacheUpdate];
    [manager adoptCommittedWiFiInfo:b profileID:@"b"];
    CHECK(![manager publishWiFiCache:[a mutableCopy] profileID:@"a" revision:revision readable:YES] && [[manager cachedWiFiInfoForProfileID:@"b"] isEqual:b], "superseded publisher cannot relabel a newer cache");
    NSError *newError = [NSError errorWithDomain:@"fixture" code:9 userInfo:nil]; manager.error = newError;
    [manager setWiFiCacheError:nil revision:revision];
    CHECK(manager.error == newError, "superseded error result cannot clear newer diagnostic");
    revision = [manager beginWiFiCacheUpdate];
    uint64_t admitted = [manager beginWiFiCacheUpdateIfRevision:revision];
    CHECK(admitted && [manager wiFiCacheRevisionIsCurrent:admitted] && ![manager beginWiFiCacheUpdateIfRevision:revision], "conditional admission advances a matching receipt and rejects stale reuse");
}
static void TestLoadAndAdoptOrdering(void) {
    PXCacheWiFi *manager = [PXCacheWiFi new];
    NSDictionary *a = Record(@"file A"), *b = Record(@"new B");
    gFiles[@"/fixture/a/wifi_info.plist"] = a;
    gDuringRead = ^{
        CHECK(![manager cachedWiFiInfoForProfileID:@"a"], "load clears read eligibility before file callback");
        [manager adoptCommittedWiFiInfo:b profileID:@"b"];
    };
    [manager loadWiFiInfoForProfileID:@"a"];
    CHECK([[manager cachedWiFiInfoForProfileID:@"b"] isEqual:b] && ![manager cachedWiFiInfoForProfileID:@"a"], "stale loader cannot overwrite later committed adoption");
    gFiles[@"/fixture/b/wifi_info.plist"] = b;
    gDuringRead = ^{ [manager loadWiFiInfoForProfileID:@"b"]; };
    [manager loadWiFiInfoForProfileID:@"a"];
    CHECK([[manager cachedWiFiInfoForProfileID:@"b"] isEqual:b], "newer nested load wins over old file result");
    PXCacheCopySpy *spy = Spy(a);
    spy.duringCopy = ^{ [manager adoptCommittedWiFiInfo:b profileID:@"b"]; };
    [manager adoptCommittedWiFiInfo:(id)spy profileID:@"a"];
    CHECK([[manager cachedWiFiInfoForProfileID:@"b"] isEqual:b], "adoption captures revision before caller-controlled mutable copy");
    [gFiles removeObjectForKey:@"/fixture/a/wifi_info.plist"];
    [manager loadWiFiInfoForProfileID:@"a"];
    NSDictionary *empty = [manager cachedWiFiInfoForProfileID:@"a"];
    CHECK(empty && empty.count == 0 && [manager.currentProfileId isEqual:@"a"] && manager.wifiInfo.count == 0, "missing file clears old profile bytes and preserves empty cache policy");
    gFiles[@"/fixture/a/wifi_info.plist"] = @[@"not dictionary"];
    [manager loadWiFiInfoForProfileID:@"a"];
    CHECK(manager.wifiInfo.count == 0, "malformed root never enters legacy dictionary cache");
}
static void TestLifetime(void) {
    PXCacheWiFi *manager = [PXCacheWiFi new];
    __weak PXCacheCopySpy *weakSpy = nil;
    @autoreleasepool {
        PXCacheCopySpy *spy = Spy(Record(@"A")); weakSpy = spy;
        Publish(manager, spy, @"a"); spy = nil;
        gThrowCopy = YES; BOOL raised = NO;
        @try { (void)[manager cachedWiFiInfoForProfileID:@"a"]; }
        @catch (NSException *e) { raised = [e.name isEqual:@"fixture.copy"]; }
        gThrowCopy = NO;
        CHECK(raised, "snapshot copy exception propagates with normal collaborator semantics");
        [manager adoptCommittedWiFiInfo:Record(@"B") profileID:@"b"];
    }
    CHECK(weakSpy == nil, "snapshot exception releases retained old cache after replacement and pool drain");
    __block NSUInteger destroyed = 0;
    @autoreleasepool {
        PXCacheDestructor *probe = [PXCacheDestructor new];
        probe.onDeath = ^{
            dispatch_semaphore_t done = dispatch_semaphore_create(0);
            __block NSDictionary *observed = nil;
            [NSThread detachNewThreadWithBlock:^{ @autoreleasepool { observed = [manager cachedWiFiInfoForProfileID:@"b"]; } dispatch_semaphore_signal(done); }];
            Wait(done);
            CHECK([observed[@"ssid"] isEqual:@"complete B"], "dealloc reentry observes completed new pair outside monitor"); destroyed++;
        };
        Publish(manager, probe, @"a"); probe = nil;
        [manager adoptCommittedWiFiInfo:Record(@"complete B") profileID:@"b"];
    }
    CHECK(destroyed == 1, "displaced cache destructor runs once after publication");
}
@interface PXCacheBoolConverter : NSObject
@end
@implementation PXCacheBoolConverter
- (BOOL)boolValue { return YES; }
@end
@interface PXCacheThrowingBool : NSObject
@end
@implementation PXCacheThrowingBool
- (BOOL)boolValue { [NSException raise:@"fixture.bool" format:@"converter failed"]; return NO; }
@end
static void TestDisplayAndTypedReaders(void) {
    PXCacheWiFi *manager = [PXCacheWiFi new];
    NSDate *stamp = [NSDate dateWithTimeIntervalSince1970:123456];
    NSDictionary *record = @{ @"ssid": @"", @"bssid": @"aB:11", @"networkType": @"", @"wifiStandard": @"custom", @"autoJoin": @"YES", @"lastConnectionTime": stamp };
    [manager adoptCommittedWiFiInfo:record profileID:@"a"];
    NSError *sentinel = [NSError errorWithDomain:@"fixture" code:7 userInfo:nil]; manager.error = sentinel;
    NSUInteger reads = gReads, paths = gPaths;
    CHECK([[manager currentSSID] isEqual:@""] && [[manager currentBSSID] isEqual:@"aB:11"] && [[manager currentNetworkType] isEqual:@""] && [[manager currentWiFiStandard] isEqual:@"custom"], "typed string accessors preserve empty spelling case and custom standards");
    CHECK([manager currentAutoJoinStatus] && [manager lastConnectionTime] == stamp, "typed metadata preserves string bool conversion and valid date identity");
    CHECK([[manager cachedWiFiDisplayInfo] isEqual:record] && manager.error == sentinel && reads == gReads && paths == gPaths, "combined display and field readers have no selection I/O write or diagnostic effects");
    NSArray *bad = @[NSNull.null, @42, @[], @{}, NSDate.date];
    for (id value in bad) {
        [manager adoptCommittedWiFiInfo:@{ @"ssid": value, @"bssid": value, @"networkType": value, @"wifiStandard": value, @"lastConnectionTime": value } profileID:@"a"];
        CHECK(![manager currentSSID] && ![manager currentBSSID] && [[manager currentNetworkType] isEqual:@"Infrastructure"] && [[manager currentWiFiStandard] isEqual:@"802.11ac"], "malformed string fields use typed sentinels without escaping containers");
        if (![value isKindOfClass:NSDate.class]) {
            NSDate *before = [NSDate date]; id observed = [manager lastConnectionTime]; NSDate *after = [NSDate date];
            CHECK([observed isKindOfClass:NSDate.class] && [observed timeIntervalSinceDate:before] >= 0 && [after timeIntervalSinceDate:observed] >= 0, "malformed date field uses existing current date fallback");
        }
    }
    for (id value in @[NSNull.null, @[], @{}, NSDate.date]) {
        [manager adoptCommittedWiFiInfo:@{ @"autoJoin": value } profileID:@"a"];
        CHECK(![manager currentAutoJoinStatus], "unsupported autoJoin object returns NO without boolValue crash");
    }
    [manager adoptCommittedWiFiInfo:@{ @"autoJoin": [PXCacheBoolConverter new] } profileID:@"a"];
    CHECK([manager currentAutoJoinStatus], "legacy live-memory bool converter remains supported");
    [manager adoptCommittedWiFiInfo:@{ @"autoJoin": [PXCacheThrowingBool new] } profileID:@"a"];
    manager.error = sentinel;
    CHECK(![manager currentAutoJoinStatus] && manager.error == sentinel, "throwing optional converter returns NO without changing lastError");
    Publish(manager, @[@"foreign root"], @"a");
    CHECK(![manager cachedWiFiDisplayInfo] && ![manager currentSSID] && ![manager currentAutoJoinStatus], "foreign cache root is unavailable rather than subscripted");
    NSDictionary *a = Record(@"A"), *b = Record(@"B");
    PXCacheCopySpy *spy = Spy(a);
    spy.duringCopy = ^{ [manager adoptCommittedWiFiInfo:b profileID:@"b"]; [manager adoptCommittedWiFiInfo:a profileID:@"a"]; };
    Publish(manager, spy, @"a");
    CHECK(![manager cachedWiFiDisplayInfo] && [[manager cachedWiFiDisplayInfo] isEqual:a], "display snapshot rejects A B A during copy without retrying");
    spy = Spy(a);
    spy.duringCopy = ^{
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        [NSThread detachNewThreadWithBlock:^{ [manager adoptCommittedWiFiInfo:b profileID:@"b"]; dispatch_semaphore_signal(done); }];
        Wait(done);
    };
    Publish(manager, spy, @"a");
    CHECK(![manager cachedWiFiDisplayInfo] && [[manager cachedWiFiDisplayInfo] isEqual:b], "display copies outside monitor and rejects a concurrent replacement");
    spy = Spy(a); Publish(manager, spy, @"a"); gThrowCopy = YES;
    CHECK(![manager cachedWiFiDisplayInfo], "display copy exception becomes an unavailable snapshot");
    gThrowCopy = NO;
    uint64_t revision = [manager beginWiFiCacheUpdate];
    [manager publishWiFiCache:[a mutableCopy] profileID:@"a" revision:revision readable:NO];
    CHECK([[manager cachedWiFiDisplayInfo] isEqual:a] && ![manager cachedWiFiInfoForProfileID:@"a"], "display keeps legacy candidate visibility while hook cache still requires acknowledgement");
    CHECK(gReads == reads && gPaths == paths, "entire display metadata matrix remains cache-only");
}
@implementation PXResolutionProfile
@synthesize profileId = _profileId;
- (id)profileId {
    if (gThrowProfileID) [NSException raise:@"fixture.id" format:@"ID failed"];
    id value = _profileId;
    void (^callback)(void) = gDuringResolve; gDuringResolve = nil;
    @try { if (callback) callback(); return value; }
    @finally { value = nil; callback = nil; }
}
@end
@implementation PXResolutionManager
- (id)currentProfile {
    gResolutionCalls++;
    if (gThrowProfile) [NSException raise:@"fixture.profile" format:@"profile failed"];
    return self.profile;
}
@end
@interface PXResolutionNote : NSObject
@property (nonatomic, strong) id userInfo;
@end
@implementation PXResolutionNote
@end
static void TestProfileResolutionAndAdmission(void) {
    PXCacheWiFi *cache = [PXCacheWiFi new];
    PXResolutionManager *manager = [PXResolutionManager new];
    PXResolutionProfile *profile = [PXResolutionProfile new]; manager.profile = profile;
    gResolutionManager = manager;
    @try {
        gFiles[PXCurrentProfileInfoPath()] = @{ @"ProfileId": @"b" };
        profile.profileId = @"a"; NSUInteger reads = gReads, resolutions = gResolutionCalls;
        CHECK([[cache getCurrentProfileID] isEqual:@"a"] && reads == gReads && gResolutionCalls == resolutions + 1, "manager authority resolves once without reading a competing file target");
        NSMutableString *mutableID = [@"a" mutableCopy]; profile.profileId = mutableID;
        NSString *frozen = [cache getCurrentProfileID]; [mutableID setString:@"b"];
        CHECK([frozen isEqual:@"a"], "resolved manager ID is detached before caller mutates its string");
        for (id bad in @[NSNull.null, @7, @[], @{}, NSDate.date]) {
            profile.profileId = bad; reads = gReads;
            CHECK(![cache getCurrentProfileID] && reads == gReads, "present malformed manager ID never redirects resolution to file or default");
        }
        profile.profileId = @"../retired";
        CHECK([[cache getCurrentProfileID] isEqual:@"../retired"], "string authority stays raw for existing downstream path validation");
        profile.profileId = @"a"; gThrowProfile = YES; reads = gReads;
        CHECK(![cache getCurrentProfileID] && gReads == reads, "throwing manager getter cannot fall back to another target");
        gThrowProfile = NO; gThrowProfileID = YES;
        CHECK(![cache getCurrentProfileID] && gReads == reads, "throwing ID getter is unresolved without file fallback");
        gThrowProfileID = NO; gThrowManager = YES;
        CHECK(![cache getCurrentProfileID] && gReads == reads, "read factory exception is unresolved without redirecting to disk");
        gThrowManager = NO; profile.profileId = nil;
        CHECK([[cache getCurrentProfileID] isEqual:@"b"], "absent manager ID retains file fallback");
        manager.profile = [NSObject new];
        CHECK([[cache getCurrentProfileID] isEqual:@"b"], "optional missing profile selector retains compatibility fallback");
        gResolutionManager = nil;
        for (id value in @[@"a", @7, @"", @YES]) {
            gFiles[PXCurrentProfileInfoPath()] = @{ @"ProfileId": value };
            NSString *expected = [value isKindOfClass:NSString.class] ? value : [value stringValue];
            CHECK([[cache getCurrentProfileID] isEqual:expected], "file strings and NSNumber normalization preserve existing grammar");
        }
        for (id bad in @[NSNull.null, @[], @{}, NSDate.date, @[@"a"]]) {
            gFiles[PXCurrentProfileInfoPath()] = @{ @"ProfileId": bad };
            CHECK(![cache getCurrentProfileID], "file containers dates and NSNull never become directory names via description");
        }
        gFiles[PXCurrentProfileInfoPath()] = @[@"foreign root"];
        CHECK(![cache getCurrentProfileID], "unexpected selection root is never subscripted");
        [gFiles removeObjectForKey:PXCurrentProfileInfoPath()];
        CHECK([[cache getCurrentProfileID] isEqual:@"default"], "absent selection preserves legacy default label");
        gFiles[PXCurrentProfileInfoPath()] = @{};
        CHECK([[cache getCurrentProfileID] isEqual:@"default"], "missing selection field preserves legacy default label");
        manager.profile = profile; profile.profileId = @"a"; gResolutionManager = manager;
        NSDictionary *a = Record(@"file A"), *b = Record(@"new B");
        gFiles[@"/fixture/a/wifi_info.plist"] = a;
        [cache adoptCommittedWiFiInfo:a profileID:@"a"];
        reads = gReads;
        gDuringResolve = ^{ [cache adoptCommittedWiFiInfo:b profileID:@"b"]; };
        [cache loadWiFiInfoFromCurrentProfile];
        CHECK([[cache cachedWiFiInfoForProfileID:@"b"] isEqual:b] && gReads == reads, "reload claims before lookup so reentrant adoption wins before any old-target file read");
        PXResolutionNote *note = [PXResolutionNote new];
        reads = gReads; uint64_t revision = cache.wifiCacheRevision;
        for (id payload in @[NSNull.null, @[], @42, @"bad", @{}, @{ @"ProfileId": @[] }, @{ @"ProfileId": @7 }]) {
            note.userInfo = payload; [cache handleWiFiProfileNotification:(id)note];
        }
        CHECK(gReads == reads && cache.wifiCacheRevision == revision, "malformed notification payloads do not resolve or invalidate cache");
        profile.profileId = @"b"; gFiles[@"/fixture/b/wifi_info.plist"] = b;
        note.userInfo = @{ @"ProfileId": @"a" };
        [cache handleWiFiProfileNotification:(id)note];
        CHECK([[cache cachedWiFiInfoForProfileID:@"b"] isEqual:b] && [cache.currentProfileId isEqual:@"b"], "stale valid event reloads current authority instead of adopting event target");
    } @finally {
        gResolutionManager = nil; gDuringResolve = nil;
        gThrowProfile = gThrowProfileID = gThrowManager = NO;
        [gFiles removeObjectForKey:PXCurrentProfileInfoPath()];
    }
}
static void TestConcurrentPairs(void) {
    PXCacheWiFi *manager = [PXCacheWiFi new];
    NSDictionary *a = Record(@"A"), *b = Record(@"B");
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [NSThread detachNewThreadWithBlock:^{
        @autoreleasepool {
            for (NSUInteger index = 0; index < 1000; index++) {
                [manager adoptCommittedWiFiInfo:(index % 2 ? a : b) profileID:(index % 2 ? @"a" : @"b")];
            }
        }
        dispatch_semaphore_signal(done);
    }];
    NSUInteger wrong = 0;
    for (NSUInteger index = 0; index < 1000; index++) {
        @autoreleasepool {
            NSDictionary *forA = [manager cachedWiFiInfoForProfileID:@"a"];
            NSDictionary *forB = [manager cachedWiFiInfoForProfileID:@"b"];
            if ((forA && ![forA[@"ssid"] isEqual:@"A"]) || (forB && ![forB[@"ssid"] isEqual:@"B"])) wrong++;
        }
    }
    Wait(done);
    CHECK(wrong == 0, "concurrent publication and reads never associate another profile's bytes");
    CHECK([[manager cachedWiFiInfoForProfileID:@"a"] isEqual:a], "completed concurrent writer leaves final acknowledged pair readable");
}
int main(void) {
    @autoreleasepool {
        gFiles = [NSMutableDictionary new];
        @try { TestSnapshotABA(); TestLoadAndAdoptOrdering(); TestLifetime(); TestDisplayAndTypedReaders(); TestProfileResolutionAndAdmission(); TestConcurrentPairs(); }
        @catch (NSException *e) { gFailures++; fprintf(stderr, "FAIL: unexpected manager cache exception: %s\n", e.description.UTF8String); }
        printf("WiFi manager cache: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
