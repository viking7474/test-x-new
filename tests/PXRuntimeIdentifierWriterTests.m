#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <Security/Security.h>
#import "PXRuntimeScalarPreparation.h"
#import "PXRuntimeIdentifierWriter.h"
#import "PXRuntimePublisher.h"
#import "PXPaths.h"
#import "TLinkIOSLogging.h"
#include <stdatomic.h>
#include <unistd.h>
#include <string.h>

static NSUInteger gChecks, gFailures, gSelections, gCacheSets;
static _Atomic NSUInteger gWrites;
static NSString *gRoot, *gSelected, *gExpectedIdentity, *gExpectedKey;
static PXRuntimeSourceStore *gStore;
static BOOL gFailGeneration, gCheckCacheCommit;
static void (^gDuringGeneration)(void);
static void PXFixturePreparationCallback(void) {
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
NSString *PXProfileRootPath(NSString *profile) { return profile ? Path(gRoot, profile) : nil; }
NSString *PXProfileIdentityPath(NSString *profile) { return profile ? Path(PXProfileRootPath(profile), @"identity") : nil; }
BOOL PXPerformRuntimeSourceWrite(BOOL (^body)(PXRuntimeSourceTransaction *, NSError **), NSError **error) {
    atomic_fetch_add(&gWrites, 1);
    return [gStore performWrite:body error:error];
}
void PXLog(NSString *format, ...) { (void)format; }
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
        CHECK(Snapshot(gExpectedIdentity) != nil && [IDs(gExpectedIdentity)[gExpectedKey] isEqual:value] && [key isEqual:gExpectedKey],
              "compatibility setter runs after complete commit outside source gate");
    }
    manager.value = value;
}
// Generated fixture provider adapters; production IdentifierManager method bodies follow.
#include "PXIdentifierFixtureProviders.inc"
@interface UptimeManager : PXGenerator
- (NSTimeInterval)currentUptimeForProfile:(NSString *)path;
- (NSDate *)currentBootTimeForProfile:(NSString *)path;
@end
@implementation UptimeManager
- (NSTimeInterval)currentUptimeForProfile:(NSString *)path { (void)path; if (gDuringGeneration) gDuringGeneration(); return 7200; }
- (NSDate *)currentBootTimeForProfile:(NSString *)path { (void)path; if (gDuringGeneration) gDuringGeneration(); return [NSDate dateWithTimeIntervalSince1970:123456]; }
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
    CHECK([manager generateIDFA] == nil && manager.error != nil && atomic_load(&gWrites) == writes,
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
int main(void) {
    @autoreleasepool {
        gRoot = Path(NSTemporaryDirectory(), NSUUID.UUID.UUIDString);
        for (NSString *profile in @[@"a", @"b", @"custom", @"migration", @"failure", @"corrupt", @"race", @"throw"]) {
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
        gStore = nil;
        [NSFileManager.defaultManager removeItemAtPath:gRoot error:nil];
        printf("Runtime identifier writers: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
