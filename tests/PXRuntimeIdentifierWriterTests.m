#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <Security/Security.h>
#import "PXRuntimeScalarPreparation.h"
#import "PXRuntimeIdentifierWriter.h"
#import "PXRuntimeArtifactWriter.h"
#import "PXRuntimeArtifactPreparation.h"
#import "PXRuntimePublisher.h"
#import "PXProfileArtifactMutation.h"
#import "PXProfileLifecycleLease.h"
#import "PXProfileDeletionJournal.h"
#import "PXPaths.h"
#import "TLinkIOSLogging.h"
#include <stdatomic.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>

static NSUInteger gChecks, gFailures, gSelections, gCacheSets;
static _Atomic NSUInteger gProviderCalls;
static void CheckIdentifierLeaseFree(void);
static void (^gDuringLog)(void);
static _Atomic NSUInteger gWrites;
static NSString *gRoot, *gSelected, *gExpectedIdentity, *gExpectedKey;
static PXRuntimeSourceStore *gStore;
static BOOL gFailGeneration, gCheckCacheCommit;
static void (^gDuringGeneration)(void);
static void PXFixturePreparationCallback(void) {
    gProviderCalls++;
    void (^callback)(void) = gDuringGeneration; gDuringGeneration = nil;
    if (callback) callback();
}
uint32_t PXIdentifierFixtureRandom(void) { PXFixturePreparationCallback(); return 5; }
uint32_t PXIdentifierFixtureUniform(uint32_t bound) { PXFixturePreparationCallback(); return bound ? 5 % bound : 0; }
OSStatus PXIdentifierFixtureSecure(SecRandomRef random, size_t count, void *bytes) {
    (void)random; PXFixturePreparationCallback();
    if (gFailGeneration) return errSecNotAvailable;
    memset(bytes, 5, count); return errSecSuccess;
}
#define CHECK(value, message) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", message); } } while (0)
static NSString *Path(NSString *root, NSString *name) { return [root stringByAppendingPathComponent:name]; }
NSString *PXProfilesPath(void) { return gRoot; }
NSString *PXValidatedProfileID(id value) {
    return [value isKindOfClass:NSString.class] && [value length] && ![value containsString:@"/"] &&
        ![value containsString:@"\\"] && ![value isEqual:@"."] && ![value isEqual:@".."] ? [value copy] : nil;
}
NSString *PXProfileRootPath(NSString *profile) { return PXValidatedProfileID(profile) ? Path(gRoot, profile) : nil; }
NSString *PXProfileIdentityPath(NSString *profile) { return PXValidatedProfileID(profile) ? Path(PXProfileRootPath(profile), @"identity") : nil; }
NSString *PXCurrentProfileInfoPath(void) { return Path(gRoot, @"current_profile_info.plist"); }
NSString *PXLegacyActiveProfileInfoPath(void) { return Path(gRoot, @"legacy_active_profile.plist"); }
NSString *PXProfileDeletionJournalPath(void) { return Path(gRoot, @".profile-delete-journal.plist"); }
BOOL PXPerformRuntimeSourceWrite(BOOL (^body)(PXRuntimeSourceTransaction *, NSError **), NSError **error) {
    atomic_fetch_add(&gWrites, 1);
    return [gStore performWrite:body error:error];
}
void PXLog(NSString *format, ...) { (void)format; if (gDuringLog) gDuringLog(); }
static NSDictionary *Load(NSString *path) { return [NSDictionary dictionaryWithContentsOfFile:path] ?: @{}; }
static NSDictionary *Snapshot(NSString *identity) {
    return [gStore capture:^NSDictionary *(NSError **error) {
        (void)error;
        NSMutableDictionary *files = [NSMutableDictionary dictionary];
        for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:identity error:nil]) {
            if ([name hasSuffix:@".plist"]) files[name] = Load(Path(identity, name));
        }
        return @{ @"files": files, @"legacyBattery": Load(Path(identity.stringByDeletingLastPathComponent, @"battery_info.plist")) };
    } error:NULL];
}
static NSDictionary *IDs(NSString *identity) { return Load(Path(identity, @"device_ids.plist")); }
static BOOL Seed(NSString *identity, NSDictionary *ids) {
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx setDictionary:ids atPath:Path(identity, @"device_ids.plist") error:error];
    } error:NULL];
}

@interface PXGenerator : NSObject
@property (nonatomic, copy) NSString *value;
@property (nonatomic, strong) NSError *error;
+ (instancetype)sharedManager;
- (NSError *)lastError;
@end
@implementation PXGenerator
+ (instancetype)sharedManager {
    static NSMutableDictionary *instances;
    static dispatch_once_t once; dispatch_once(&once, ^{ instances = [NSMutableDictionary dictionary]; });
    @synchronized (instances) {
        NSString *name = NSStringFromClass(self);
        if (!instances[name]) instances[name] = [self new];
        return instances[name];
    }
}
- (NSError *)lastError { return self.error; }
@end
static NSString *PXFixtureGenerate(PXGenerator *manager, NSString *key) {
    PXFixturePreparationCallback();
    if (gFailGeneration) {
        manager.error = [NSError errorWithDomain:@"fixture" code:1 userInfo:nil]; return nil;
    }
    manager.error = nil;
    return [@"prepared-" stringByAppendingString:key];
}
static void PXFixtureSet(PXGenerator *manager, NSString *key, NSString *value) {
    gCacheSets++;
    if (gCheckCacheCommit) {
        CheckIdentifierLeaseFree();
        CHECK(Snapshot(gExpectedIdentity) != nil && [IDs(gExpectedIdentity)[gExpectedKey] isEqual:value] && [key isEqual:gExpectedKey],
              "compatibility setter runs after complete commit outside source gate");
    }
    manager.value = value;
}
// Generated fixture provider adapters; production IdentifierManager method bodies follow.
#include "PXIdentifierFixtureProviders.inc"
static BOOL gMissingUptime;
static NSUInteger gUptimeReads, gUptimePreparations, gUptimeAdoptions;
static void (^gDuringUptimeRead)(void), (^gDuringUptimePrepare)(void);
@interface UptimeManager : PXGenerator
- (NSTimeInterval)currentUptimeForProfile:(NSString *)path generateIfMissing:(BOOL)generate;
- (NSDate *)currentBootTimeForProfile:(NSString *)path generateIfMissing:(BOOL)generate;
- (NSDictionary *)prepareConsistentUptimeInfo;
- (void)adoptCommittedUptimeInfo:(NSDictionary *)info timestamp:(NSDate *)timestamp;
@end
@implementation UptimeManager
- (void)checkRead:(BOOL)generate {
    CHECK(!generate, "identifier compatibility reads never recursively auto generate");
    gUptimeReads++;
    void (^callback)(void) = gDuringUptimeRead; gDuringUptimeRead = nil; if (callback) callback();
}
- (NSTimeInterval)currentUptimeForProfile:(NSString *)path generateIfMissing:(BOOL)generate {
    (void)path; [self checkRead:generate]; return gMissingUptime ? 0 : 7200;
}
- (NSDate *)currentBootTimeForProfile:(NSString *)path generateIfMissing:(BOOL)generate {
    (void)path; [self checkRead:generate]; return gMissingUptime ? nil : [NSDate dateWithTimeIntervalSince1970:123456];
}
- (NSDictionary *)prepareConsistentUptimeInfo {
    gUptimePreparations++;
    void (^callback)(void) = gDuringUptimePrepare; gDuringUptimePrepare = nil; if (callback) callback();
    return PXPrepareRuntimeUptime([NSDate dateWithTimeIntervalSince1970:1700000000], 0, NO);
}
- (void)adoptCommittedUptimeInfo:(NSDictionary *)info timestamp:(NSDate *)timestamp {
    (void)timestamp; gUptimeAdoptions++; CheckIdentifierLeaseFree();
    NSString *bootScalar = [NSString stringWithFormat:@"%.0f", [info[@"boot"][@"value"] timeIntervalSince1970]];
    CHECK([IDs(gExpectedIdentity)[@"BootTime"] isEqual:bootScalar] &&
          [Load(Path(gExpectedIdentity, @"boot_time.plist"))[@"value"] isEqual:info[@"boot"][@"value"]], "compatibility uptime adoption sees committed pair after release");
}
@end
#include "PXIdentifierFixtureStatics.inc"
@interface PXIdentifierFixture : NSObject
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSMutableDictionary *settings;
- (NSString *)getActiveProfileId;
#include "PXIdentifierProductionDeclarations.inc"
@end
@implementation PXIdentifierFixture
- (instancetype)init { if ((self = [super init])) _settings = [NSMutableDictionary dictionary]; return self; }
- (NSString *)getActiveProfileId { gSelections++; return gSelected; }
#include "PXIdentifierProductionMethods.inc"
@end
@interface PXThrowOnceIdentifier : PXIdentifierFixture
@property (nonatomic) NSUInteger calls;
@end
@implementation PXThrowOnceIdentifier
- (BOOL)migrateProfileSchemaAtIdentityDirectory:(NSString *)identity {
    if (++self.calls == 1) [NSException raise:@"fixture" format:@"migration exception"];
    return [super migrateProfileSchemaAtIdentityDirectory:identity];
}
@end

static void TestGeneratedValues(PXIdentifierFixture *manager, NSString *a, NSString *b) {
    NSArray<NSArray<NSString *> *> *cases = PXFixtureGeneratorCases();
    gSelected = @"a";
    CHECK(Seed(a, @{ @"ProfileSchemaVersion": @2, @"GenerationCounter": @7, @"keep": @YES }) &&
          Seed(b, @{ @"ProfileSchemaVersion": @2, @"untouched": @YES }), "generator fixtures seeded");
    NSUInteger writes = atomic_load(&gWrites);
    CHECK([[manager profileIdentityPath] isEqual:a] && atomic_load(&gWrites) == writes,
          "already-current live path never enters writer gate");
    gSelected = nil;
    NSDictionary *absentTargetBefore = Snapshot(a); NSUInteger providersBefore = gProviderCalls;
    CHECK([manager generateIDFA] == nil && manager.error != nil && providersBefore == gProviderCalls && [absentTargetBefore isEqual:Snapshot(a)],
          "missing active target rejects before generation and persistence");
    for (NSArray<NSString *> *row in cases) {
        NSString *selectorName = row[0], *key = row[1], *file = row[2];
        gSelected = @"a"; gSelections = 0;
        gExpectedIdentity = a; gExpectedKey = key; gCheckCacheCommit = YES;
        gDuringGeneration = ^{ CHECK(Snapshot(a) != nil, "generation is outside source gate"); gSelected = @"b"; };
        SEL selector = NSSelectorFromString(selectorName);
        NSString *(*invoke)(id, SEL) = (NSString *(*)(id, SEL))[manager methodForSelector:selector];
        NSString *value = invoke(manager, selector);
        gDuringGeneration = nil;
        gCheckCacheCommit = NO;
        CHECK(value != nil && gSelections == 1, "generator captures target once before preparing value");
        CHECK([Load(Path(a, file))[@"value"] isEqual:value] && [IDs(a)[key] isEqual:value], "generator writes exact sidecar and canonical ID key");
        CHECK([IDs(a)[@"GenerationCounter"] isEqual:@7] && [IDs(a)[@"keep"] boolValue] && !IDs(b)[key],
              "generated scalar preserves counter unrelated keys and other profile");
    }
    gSelected = @"a"; gFailGeneration = YES;
    NSDictionary *before = Snapshot(a);
    CHECK([manager generateIDFA] == nil && manager.error != nil && [before isEqual:Snapshot(a)], "generation failure does not mutate persisted sources");
    gFailGeneration = NO;
    __block BOOL interrupted = NO;
    NSUInteger cacheSetsBefore = gCacheSets;
    gStore.testCheckpoint = ^(NSString *stage) { if (!interrupted && [stage isEqual:@"source-written"]) { interrupted = YES; [NSException raise:@"fixture" format:@"fail scalar commit"]; } };
    CHECK([manager generateSystemBootUUID] == nil && manager.error != nil, "generator reports persist failure");
    gStore.testCheckpoint = nil;
    CHECK([before isEqual:Snapshot(a)] && gCacheSets == cacheSetsBefore, "failed generated pair rolls back bytes and source identity without publishing cache");
    CHECK(PXRuntimeIdentifierSidecar(@"HardwareUUID") == nil && PXRuntimeIdentifierSidecar(@"DeviceTheme") == nil,
          "custom API does not introduce legacy aliases or extra types");
}
static void TestCustomAndMetadata(PXIdentifierFixture *manager, NSString *identity) {
    gSelected = @"custom";
    CHECK(Seed(identity, @{ @"ProfileSchemaVersion": @2, @"GenerationCounter": @0, @"keep": @YES }), "custom fixture seeded");
    NSArray *rows = PXFixtureCustomCases();
    NSUInteger count = 0;
    gExpectedIdentity = identity; gCheckCacheCommit = YES;
    for (NSArray<NSString *> *row in rows) {
        NSString *key = row[0], *file = row[1]; gExpectedKey = key;
        NSString *value = [@"custom-" stringByAppendingString:key];
        CHECK([manager saveCustomValue:value forType:key], "custom value committed");
        CHECK([IDs(identity)[key] isEqual:value] && [Load(Path(identity, file))[@"value"] isEqual:value] &&
              [IDs(identity)[@"GenerationCounter"] unsignedIntegerValue] == ++count, "custom counter increments exactly once with paired value");
    }
    gCheckCacheCommit = NO;
    NSUInteger setsBefore = gCacheSets;
    NSDictionary *before = Snapshot(identity);
    __block BOOL interrupted = NO;
    gStore.testCheckpoint = ^(NSString *stage) { if (!interrupted && [stage isEqual:@"source-written"]) { interrupted = YES; [NSException raise:@"fixture" format:@"fail custom commit"]; } };
    CHECK(![manager saveCustomValue:@"rejected" forType:@"IDFA"], "custom failure returned to caller");
    gStore.testCheckpoint = nil;
    CHECK(gCacheSets == setsBefore && [before isEqual:Snapshot(identity)], "failed custom commit cannot publish compatibility cache or counter");
    CHECK(![manager saveCustomValue:@"x" forType:@"Unknown"] && ![manager saveCustomValue:nil forType:@"IDFA"], "unsupported or nil custom payload rejected");
    [manager setATTAuthorizationStatus:99];
    CHECK([IDs(identity)[@"ATTAuthorizationStatus"] isEqual:@3] && [Load(Path(identity, @"tracking_info.plist"))[@"ATTAuthorizationStatus"] isEqual:@3], "ATT clamping and sidecar schema preserved");
    [manager setATTAuthorizationStatus:-1];
    CHECK([IDs(identity)[@"ATTAuthorizationStatus"] isEqual:@0], "negative ATT clamps to not determined");
    CHECK([manager setCustomDeviceTheme:@"Dark"] && [IDs(identity)[@"DeviceTheme"] isEqual:@"Dark"] &&
          [Load(Path(identity, @"device_theme.plist"))[@"value"] isEqual:@"Dark"], "theme sidecar and ID committed together");
    CHECK(![manager setCustomDeviceTheme:@"Invalid"] && [IDs(identity)[@"GenerationCounter"] unsignedIntegerValue] == count, "metadata updates preserve generation policy");
    CHECK([[manager generateSystemUptime] isEqual:@"2.00 hours"] && [IDs(identity)[@"SystemUptime"] isEqual:@"7200"], "uptime keeps display units and persisted seconds string");
    CHECK([manager generateBootTime] != nil && [Load(Path(identity, @"boot_time.plist"))[@"value"] isKindOfClass:NSDate.class] &&
          [IDs(identity)[@"BootTime"] isEqual:@"123456"], "boot keeps date sidecar and string ID timestamp");
    CHECK(Seed(identity, @{ @"ProfileSchemaVersion": @2, @"GenerationCounter": @(NSIntegerMax) }), "exhausted counter fixture seeded");
    before = Snapshot(identity);
    CHECK(![manager saveCustomValue:@"overflow" forType:@"IDFA"] && [before isEqual:Snapshot(identity)], "counter exhaustion rejects without signed overflow or partial data");
}
static void TestMigration(PXIdentifierFixture *manager, NSString *identity, NSString *failIdentity, NSString *raceIdentity, NSString *throwIdentity) {
    manager.settings = [@{ @"UDID": @YES, @"IDFA": @YES } mutableCopy];
    CHECK(Seed(identity, @{ @"HardwareUUID": @"legacy-boot", @"IDFA": @"nonzero", @"GenerationCounter": @4, @"keep": @YES }), "legacy fixture seeded");
    CHECK([gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx setDictionary:@{ @"BatteryLevel": @"0.4" } atPath:Path(identity, @"battery_info.plist") error:error];
    } error:NULL], "legacy battery fixture seeded");
    CHECK([manager migrateProfileSchemaAtIdentityDirectory:identity], "schema migration commits whole group");
    NSDictionary *ids = IDs(identity);
    CHECK([ids[@"SystemBootUUID"] isEqual:@"legacy-boot"] && [Load(Path(identity, @"system_boot_uuid.plist"))[@"value"] isEqual:@"legacy-boot"], "legacy hardware UUID migration preserved");
    CHECK([ids[@"UDID"] length] == 40 && [ids[@"ATTAuthorizationStatus"] isEqual:@3] && [ids[@"LowPowerMode"] isEqual:@NO] &&
          [ids[@"ProfileSchemaVersion"] isEqual:@2] && [ids[@"GenerationCounter"] isEqual:@5], "migration defaults schema and single counter bump preserved");
    CHECK([Load(Path(identity.stringByDeletingLastPathComponent, @"battery_info.plist"))[@"BatteryLevel"] isEqual:@"0.4"], "legacy profile-root battery compatibility preserved");
    NSDictionary *before = Snapshot(identity);
    CHECK([manager migrateProfileSchemaAtIdentityDirectory:identity] && [before isEqual:Snapshot(identity)], "already migrated schema is no-op without new source commit");

    CHECK(Seed(failIdentity, @{ @"HardwareUUID": @"old", @"GenerationCounter": @2 }), "failed migration fixture seeded");
    before = Snapshot(failIdentity);
    __block BOOL interrupted = NO;
    gStore.testCheckpoint = ^(NSString *stage) { if (!interrupted && [stage isEqual:@"source-written"]) { interrupted = YES; [NSException raise:@"fixture" format:@"interrupt migration"]; } };
    CHECK(![manager migrateProfileSchemaAtIdentityDirectory:failIdentity], "migration failure propagated");
    gStore.testCheckpoint = nil;
    CHECK([before isEqual:Snapshot(failIdentity)], "migration rollback restores all sidecars schema and generation");
    CHECK([manager migrateProfileSchemaAtIdentityDirectory:failIdentity], "migration retry succeeds after rollback");
    NSString *corruptIdentity = PXProfileIdentityPath(@"corrupt");
    CHECK(Seed(corruptIdentity, @{}), "corrupt migration fixture seeded");
    NSString *corruptPath = Path(corruptIdentity, @"udid.plist");
    NSData *badBytes = [@"not a property list" dataUsingEncoding:NSUTF8StringEncoding];
    CHECK([badBytes writeToFile:corruptPath atomically:YES], "corrupt legacy input prepared");
    before = Snapshot(corruptIdentity);
    CHECK(![manager migrateProfileSchemaAtIdentityDirectory:corruptIdentity] && manager.error != nil &&
          [badBytes isEqual:[NSData dataWithContentsOfFile:corruptPath]] && [before isEqual:Snapshot(corruptIdentity)],
          "malformed migration input preserves bytes schema and commit identity");
    CHECK(Seed(raceIdentity, @{ @"GenerationCounter": @8 }), "concurrent migration fixture seeded");
    dispatch_group_t group = dispatch_group_create();
    static _Atomic NSUInteger failures; atomic_store(&failures, 0);
    for (NSUInteger i = 0; i < 8; ++i) dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        PXIdentifierFixture *instance = [PXIdentifierFixture new]; instance.settings = [manager.settings mutableCopy];
        BOOL migrated = NO;
        for (NSUInteger attempt = 0; attempt < 3 && !migrated; ++attempt) {
            migrated = [instance migrateProfileSchemaAtIdentityDirectory:raceIdentity];
            // Only a documented contention deadline is retryable under CI load.
            if (!migrated && ![instance.error.localizedDescription hasPrefix:@"Timed out waiting for source "]) break;
        }
        if (!migrated) atomic_fetch_add(&failures, 1);
    });
    CHECK(dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0 && atomic_load(&failures) == 0 &&
          [IDs(raceIdentity)[@"GenerationCounter"] isEqual:@9], "concurrent migrations bump once after serialized schema recheck");
    gSelected = @"throw";
    CHECK(Seed(throwIdentity, @{}), "exception migration fixture seeded");
    PXThrowOnceIdentifier *thrower = [PXThrowOnceIdentifier new];
    @try { [thrower profileIdentityPath]; } @catch (__unused NSException *exception) {}
    CHECK([thrower profileIdentityPath] != nil && thrower.calls == 2 && [IDs(throwIdentity)[@"ProfileSchemaVersion"] isEqual:@2], "thread-local migration guard resets during exception unwinding");
}

static void CheckIdentifierLeaseFree(void) {
    NSError *error = nil;
    PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:gRoot error:&error];
    CHECK(lease && !error, "identifier writer releases lifecycle before compatibility publication logging and return");
    [lease invalidate];
}
static void CheckIdentifierLeaseHeld(void) {
    NSError *error = nil;
    PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:gRoot error:&error];
    CHECK(!lease && error.code == 12, "identifier preparation runs with lifecycle ownership");
    [lease invalidate];
    CHECK(Snapshot(gExpectedIdentity) != nil, "identifier preparation never runs under source gate");
}
static BOOL IdentifierDeleteIntent(BOOL present) {
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return present ? [tx setDictionary:@{ @"fixture": @YES } atPath:PXProfileDeletionJournalPath() error:error] :
            [tx removeDictionaryAtPath:PXProfileDeletionJournalPath() error:error];
    } error:NULL];
}
static NSDictionary *IdentifierAllFiles(void) {
    return [gStore capture:^NSDictionary *(NSError **error) {
        (void)error; NSMutableDictionary *files = [NSMutableDictionary dictionary];
        for (NSString *relative in [NSFileManager.defaultManager subpathsAtPath:gRoot])
            if (![relative hasPrefix:@"control/"] && [relative hasSuffix:@".plist"])
                files[relative] = [NSData dataWithContentsOfFile:Path(gRoot, relative)];
        return @{ @"files": files };
    } error:NULL];
}
static void TestScalarLifecycle(PXIdentifierFixture *manager, NSString *a, NSString *b) {
    gSelected = @"a"; gExpectedIdentity = a;
    CHECK(Seed(a, @{ @"ProfileSchemaVersion": @2, @"GenerationCounter": @8, @"keep": @YES }), "owned scalar target seeded");
    PXProfileLifecycleLease *owner = [PXProfileLifecycleLease acquireInDirectory:gRoot error:NULL];
    CHECK(owner != nil, "competing scalar lifecycle owner acquired");
    NSUInteger selections = gSelections, providers = gProviderCalls, caches = gCacheSets;
    NSDictionary *before = IdentifierAllFiles();
    for (NSArray *row in PXFixtureGeneratorCases()) {
        SEL selector = NSSelectorFromString(row[0]);
        NSString *(*invoke)(id, SEL) = (NSString *(*)(id, SEL))[manager methodForSelector:selector];
        CHECK(!invoke(manager, selector) && manager.error.code == 12, "busy scalar generator rejects before preparation");
    }
    CHECK(![manager saveCustomValue:@"busy" forType:@"IDFA"] && manager.error.code == 12, "busy custom scalar rejects source mutation");
    [manager setATTAuthorizationStatus:3]; CHECK(manager.error.code == 12, "busy ATT rejects source mutation");
    CHECK(![manager setCustomDeviceTheme:@"Dark"] && manager.error.code == 12, "busy theme rejects source mutation");
    CHECK(selections == gSelections && providers == gProviderCalls && caches == gCacheSets && [before isEqual:IdentifierAllFiles()],
          "busy scalar metadata writers never resolve migrate prepare write or publish");
    [owner invalidate]; CheckIdentifierLeaseFree();
    CHECK(IdentifierDeleteIntent(YES), "scalar pending delete seeded"); before = IdentifierAllFiles();
    CHECK(![manager generateSerialNumber] && manager.error.code == 27 &&
          ![manager saveCustomValue:@"pending" forType:@"IDFA"] && manager.error.code == 27, "pending deletion blocks generated and custom scalars");
    [manager setATTAuthorizationStatus:0]; CHECK(manager.error.code == 27, "pending deletion blocks ATT state");
    CHECK(![manager setCustomDeviceTheme:@"Light"] && manager.error.code == 27 && selections == gSelections && providers == gProviderCalls &&
          caches == gCacheSets && [before isEqual:IdentifierAllFiles()], "pending deletion blocks scalar metadata before target and preparation");
    CHECK(IdentifierDeleteIntent(NO), "scalar pending delete cleared");
    gDuringGeneration = ^{ CheckIdentifierLeaseHeld(); CHECK(![manager saveCustomValue:@"reentry" forType:@"IDFV"] && manager.error.code == 12, "scalar preparation reentry fails busy without deadlock"); };
    gExpectedKey = @"IDFA"; gCheckCacheCommit = YES;
    CHECK([manager generateIDFA] != nil && manager.error == nil, "scalar generation owns target across provider and source commit");
    gCheckCacheCommit = NO; CheckIdentifierLeaseFree();
    before = IdentifierAllFiles(); caches = gCacheSets;
    gDuringGeneration = ^{ CheckIdentifierLeaseHeld(); [NSException raise:@"fixture" format:@"scalar provider exception"]; };
    BOOL threw = NO;
    @try { [manager generateSerialNumber]; } @catch (NSException *exception) { (void)exception; threw = YES; }
    CHECK(threw && caches == gCacheSets && [before isEqual:IdentifierAllFiles()], "throwing scalar provider preserves files and releases lifecycle ownership"); CheckIdentifierLeaseFree();
    __block NSDictionary *competitor = nil;
    gDuringGeneration = ^{ CHECK(IdentifierDeleteIntent(YES), "bypass scalar deletion intent committed"); competitor = IdentifierAllFiles(); };
    CHECK(![manager generateIDFV] && manager.error.code == 27 && caches == gCacheSets && [competitor isEqual:IdentifierAllFiles()],
          "late deletion intent rejects scalar sidecar IDs and cache publication");
    CHECK(IdentifierDeleteIntent(NO), "late scalar intent cleared");
    for (NSUInteger kind = 0; kind < 3; kind++) {
        NSString *old = Path(a.stringByDeletingLastPathComponent, @"old-scalar-identity"); __block BOOL moved = NO;
        competitor = nil;
        gDuringGeneration = ^{
            moved = [NSFileManager.defaultManager moveItemAtPath:a toPath:old error:NULL];
            if (kind == 1) moved = moved && [NSFileManager.defaultManager createDirectoryAtPath:a withIntermediateDirectories:NO attributes:nil error:NULL];
            if (kind == 2) moved = moved && [NSFileManager.defaultManager createSymbolicLinkAtPath:a withDestinationPath:b error:NULL];
            competitor = IdentifierAllFiles();
        };
        CHECK(![manager generateIDFA] && manager.error && moved && caches == gCacheSets && [competitor isEqual:IdentifierAllFiles()],
              "scalar commit rejects missing replaced and symlink identity after preparation");
        if (kind != 0) CHECK([NSFileManager.defaultManager removeItemAtPath:a error:NULL], "scalar namespace replacement fixture removed");
        CHECK([NSFileManager.defaultManager moveItemAtPath:old toPath:a error:NULL], "scalar original identity restored"); CheckIdentifierLeaseFree();
    }
    // Source commit callbacks can outlive a mutable caller argument. The value
    // passed to both persistence and compatibility publication must be detached.
    NSMutableString *input = [@"copied-custom-value" mutableCopy], *type = [@"IDFA" mutableCopy];
    __block BOOL changed = NO;
    gStore.testCheckpoint = ^(NSString *phase) {
        if ([phase isEqual:@"commit-written"]) { [input setString:@"changed-value"]; [type setString:@"IDFV"]; changed = YES; }
    };
    gExpectedKey = @"IDFA"; gCheckCacheCommit = YES;
    CHECK([manager saveCustomValue:input forType:type] && changed && [IDs(a)[@"IDFA"] isEqual:@"copied-custom-value"],
          "custom scalar freezes caller value and type before commit and publication");
    gStore.testCheckpoint = nil; gCheckCacheCommit = NO;
    gDuringLog = ^{ CheckIdentifierLeaseFree(); };
    [manager setATTAuthorizationStatus:99];
    CHECK(!manager.error && [IDs(a)[@"ATTAuthorizationStatus"] isEqual:@3], "owned ATT preserves clamp policy and releases before logging");
    CHECK([manager setCustomDeviceTheme:@"Light"] && !manager.error && [IDs(a)[@"DeviceTheme"] isEqual:@"Light"], "owned theme retains paired state without changing generation policy");
    gDuringLog = nil;
    // A writer's resolver keeps the legacy schema preflight, but failure later
    // in scalar preparation must not masquerade as rolling that migration back.
    NSString *legacy = PXProfileIdentityPath(@"owned-legacy");
    CHECK(Seed(legacy, @{ @"GenerationCounter": @2 }), "owned legacy migration fixture seeded");
    gSelected = @"owned-legacy"; gFailGeneration = YES;
    CHECK(![manager generateIDFA] && manager.error && [IDs(legacy)[@"ProfileSchemaVersion"] isEqual:@2] &&
          [IDs(legacy)[@"GenerationCounter"] isEqual:@3], "scalar failure preserves completed schema preflight without claiming whole-operation rollback");
    gFailGeneration = NO; CheckIdentifierLeaseFree();
    NSString *throwIdentity = PXProfileIdentityPath(@"owned-throw");
    CHECK(Seed(throwIdentity, @{}), "owned throwing migration fixture seeded"); gSelected = @"owned-throw";
    PXThrowOnceIdentifier *thrower = [PXThrowOnceIdentifier new]; threw = NO;
    @try { [thrower generateIDFA]; } @catch (NSException *exception) { (void)exception; threw = YES; }
    CHECK(threw, "writer schema exception propagates through resolver"); CheckIdentifierLeaseFree();
    CHECK([thrower generateIDFA] && !thrower.error && thrower.calls == 2 && [IDs(throwIdentity)[@"ProfileSchemaVersion"] isEqual:@2],
          "writer resolver exception releases lifecycle and resets schema reentry guard");
    gSelected = @"a";
}

static NSString *InvokeUptimeCompatibility(PXIdentifierFixture *manager, BOOL boot) {
    return boot ? [manager generateBootTime] : [manager generateSystemUptime];
}
static BOOL SeedCompatibilityUptime(NSString *identity) {
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx setDictionary:@{ @"ProfileSchemaVersion": @2, @"GenerationCounter": @12, @"keep": @YES }
                         atPath:Path(identity, @"device_ids.plist") error:error] &&
            [tx removeDictionaryAtPath:Path(identity, @"boot_time.plist") error:error] &&
            [tx removeDictionaryAtPath:Path(identity, @"system_uptime.plist") error:error];
    } error:NULL];
}
static void TestUptimeCompatibilityLifecycle(PXIdentifierFixture *manager, NSString *identity, NSString *other) {
    gSelected = @"owned-time"; gExpectedIdentity = identity;
    for (NSUInteger mode = 0; mode < 4; mode++) {
        BOOL boot = mode % 2; gMissingUptime = mode >= 2;
        CHECK(SeedCompatibilityUptime(identity), "compatibility uptime baseline seeded");
        PXProfileLifecycleLease *owner = [PXProfileLifecycleLease acquireInDirectory:gRoot error:NULL];
        CHECK(owner != nil, "compatibility uptime competing owner acquired");
        NSUInteger selections = gSelections, reads = gUptimeReads, preparations = gUptimePreparations, adoptions = gUptimeAdoptions;
        NSDictionary *before = IdentifierAllFiles();
        CHECK(!InvokeUptimeCompatibility(manager, boot) && manager.error.code == 12 && selections == gSelections && reads == gUptimeReads &&
              preparations == gUptimePreparations && adoptions == gUptimeAdoptions && [before isEqual:IdentifierAllFiles()],
              "busy uptime compatibility rejects before target read provider and source mutation");
        [owner invalidate]; CheckIdentifierLeaseFree();
        CHECK(IdentifierDeleteIntent(YES), "compatibility uptime pending deletion seeded"); before = IdentifierAllFiles();
        CHECK(!InvokeUptimeCompatibility(manager, boot) && manager.error.code == 27 && selections == gSelections && reads == gUptimeReads &&
              preparations == gUptimePreparations && [before isEqual:IdentifierAllFiles()], "pending deletion blocks both uptime compatibility paths");
        CHECK(IdentifierDeleteIntent(NO), "compatibility uptime pending deletion cleared");
        gDuringUptimeRead = ^{
            CheckIdentifierLeaseHeld();
            CHECK(![manager generateBootTime] && manager.error.code == 12, "uptime compatibility reentry fails busy without getter generation");
        };
        __block NSUInteger commits = 0;
        gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"commit-written"]) commits++; };
        NSString *result = InvokeUptimeCompatibility(manager, boot); gStore.testCheckpoint = nil;
        CHECK(result && !manager.error && commits == 1 && reads + 1 == gUptimeReads &&
              preparations + (gMissingUptime ? 1 : 0) == gUptimePreparations && adoptions + (gMissingUptime ? 1 : 0) == gUptimeAdoptions &&
              [IDs(identity)[@"GenerationCounter"] isEqual:@12] && [IDs(identity)[@"keep"] boolValue],
              "uptime read hit or missing pair commits once and adopts only after success");
        NSString *key = boot ? @"BootTime" : @"SystemUptime", *file = boot ? @"boot_time.plist" : @"system_uptime.plist";
        CHECK([IDs(identity)[key] isKindOfClass:NSString.class] &&
              [Load(Path(identity, file))[@"value"] isKindOfClass:(boot ? NSDate.class : NSString.class)], "uptime compatibility preserves persisted date seconds and display types");
        if (gMissingUptime) {
            CHECK([IDs(identity)[@"SystemUptime"] isKindOfClass:NSString.class] && [IDs(identity)[@"BootTime"] isKindOfClass:NSString.class] &&
                  [Load(Path(identity, @"boot_time.plist"))[@"value"] isKindOfClass:NSDate.class] &&
                  [Load(Path(identity, @"system_uptime.plist"))[@"value"] isKindOfClass:NSString.class], "missing compatibility uptime initializes both source records atomically");
        }
        if (!boot) {
            NSString *display = [NSString stringWithFormat:@"%.2f hours", [IDs(identity)[key] doubleValue] / 3600.0];
            CHECK([result isEqual:display], "uptime compatibility display keeps hours while persistence uses seconds");
        }
        CheckIdentifierLeaseFree();
        CHECK(SeedCompatibilityUptime(identity), "compatibility uptime failure baseline seeded"); before = IdentifierAllFiles(); adoptions = gUptimeAdoptions;
        gDuringUptimeRead = ^{ CheckIdentifierLeaseHeld(); [NSException raise:@"fixture" format:@"uptime read failure"]; };
        BOOL threw = NO;
        @try { (void)InvokeUptimeCompatibility(manager, boot); } @catch (NSException *exception) { (void)exception; threw = YES; }
        CHECK(threw && adoptions == gUptimeAdoptions && [before isEqual:IdentifierAllFiles()], "uptime read exception releases ownership without cache or source effects"); CheckIdentifierLeaseFree();
        if (gMissingUptime) {
            gDuringUptimePrepare = ^{ CheckIdentifierLeaseHeld(); [NSException raise:@"fixture" format:@"uptime prepare failure"]; }; threw = NO;
            @try { (void)InvokeUptimeCompatibility(manager, boot); } @catch (NSException *exception) { (void)exception; threw = YES; }
            CHECK(threw && adoptions == gUptimeAdoptions && [before isEqual:IdentifierAllFiles()], "uptime preparation exception cannot publish or leak lifecycle"); CheckIdentifierLeaseFree();
        }
        __block NSDictionary *competitor = nil;
        gDuringUptimeRead = ^{ CHECK(IdentifierDeleteIntent(YES), "uptime compatibility late delete seeded"); competitor = IdentifierAllFiles(); };
        CHECK(!InvokeUptimeCompatibility(manager, boot) && manager.error.code == 27 && adoptions == gUptimeAdoptions && [competitor isEqual:IdentifierAllFiles()],
              "late delete rejects compatibility pair initialization and scalar together");
        CHECK(IdentifierDeleteIntent(NO), "uptime compatibility late intent cleared"); CheckIdentifierLeaseFree();
        for (NSUInteger kind = 0; kind < 3; kind++) {
            NSString *old = Path(identity.stringByDeletingLastPathComponent, @"old-compatibility-time"); __block BOOL moved = NO;
            gDuringUptimeRead = ^{
                moved = [NSFileManager.defaultManager moveItemAtPath:identity toPath:old error:NULL];
                if (kind == 1) moved = moved && [NSFileManager.defaultManager createDirectoryAtPath:identity withIntermediateDirectories:NO attributes:nil error:NULL];
                if (kind == 2) moved = moved && [NSFileManager.defaultManager createSymbolicLinkAtPath:identity withDestinationPath:other error:NULL];
                competitor = IdentifierAllFiles();
            };
            CHECK(!InvokeUptimeCompatibility(manager, boot) && manager.error && moved && adoptions == gUptimeAdoptions && [competitor isEqual:IdentifierAllFiles()],
                  "uptime compatibility rejects missing replaced and symlink identity without adopting cache");
            if (kind != 0) CHECK([NSFileManager.defaultManager removeItemAtPath:identity error:NULL], "uptime compatibility replacement fixture removed");
            CHECK([NSFileManager.defaultManager moveItemAtPath:old toPath:identity error:NULL], "uptime compatibility original identity restored"); CheckIdentifierLeaseFree();
        }
        before = IdentifierAllFiles(); __block BOOL interrupted = NO;
        gStore.testCheckpoint = ^(NSString *phase) {
            if (!interrupted && [phase isEqual:@"source-written"]) { interrupted = YES; [NSException raise:@"fixture" format:@"uptime compatibility commit failure"]; }
        };
        CHECK(!InvokeUptimeCompatibility(manager, boot) && manager.error && interrupted && adoptions == gUptimeAdoptions && [before isEqual:IdentifierAllFiles()],
              "uptime compatibility transaction failure rolls back pair scalar and commit token");
        gStore.testCheckpoint = nil; CheckIdentifierLeaseFree();
    }
    gMissingUptime = NO; gSelected = @"a";
}
int main(void) {
    @autoreleasepool {
        gRoot = Path(NSTemporaryDirectory(), NSUUID.UUID.UUIDString);
        for (NSString *profile in @[@"a", @"b", @"custom", @"migration", @"failure", @"corrupt", @"race", @"throw", @"owned-legacy", @"owned-throw", @"owned-time"]) {
            [NSFileManager.defaultManager createDirectoryAtPath:PXProfileIdentityPath(profile) withIntermediateDirectories:YES attributes:nil error:nil];
        }
        gStore = [[PXRuntimeSourceStore alloc] initWithDirectory:Path(gRoot, @"control") owner:geteuid() group:getegid()
            allowsPath:^BOOL(NSString *path) {
                return [path hasPrefix:[gRoot stringByAppendingString:@"/"]] && [path hasSuffix:@".plist"] &&
                    [path isEqual:path.stringByStandardizingPath] && ![path hasPrefix:Path(gRoot, @"control/")];
            } error:NULL];
        CHECK(gStore != nil, "identifier backend initialized");
        PXIdentifierFixture *manager = [PXIdentifierFixture new];
        TestGeneratedValues(manager, PXProfileIdentityPath(@"a"), PXProfileIdentityPath(@"b"));
        TestCustomAndMetadata(manager, PXProfileIdentityPath(@"custom"));
        TestMigration(manager, PXProfileIdentityPath(@"migration"), PXProfileIdentityPath(@"failure"), PXProfileIdentityPath(@"race"), PXProfileIdentityPath(@"throw"));
        TestScalarLifecycle(manager, PXProfileIdentityPath(@"a"), PXProfileIdentityPath(@"b"));
        TestUptimeCompatibilityLifecycle(manager, PXProfileIdentityPath(@"owned-time"), PXProfileIdentityPath(@"b"));
        gStore = nil;
        [NSFileManager.defaultManager removeItemAtPath:gRoot error:nil];
        printf("Runtime identifier writers: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
