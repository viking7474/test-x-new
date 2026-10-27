#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <Security/Security.h>
#import "PXRuntimeIdentifierWriter.h"
#import "PXRuntimeGeneration.h"
#import "PXRuntimeProfileSelection.h"
#import "PXRuntimeArtifactPreparation.h"
#import "PXRuntimeScalarPreparation.h"
#import "PXProfileLifecycleLease.h"
#import "PXProfileArtifactMutation.h"
#import "PXProfileDeletionJournal.h"
#include <sys/sysctl.h>
#import "PXDeviceProfileSchema.h"
#import "PXIdentityValidator.h"
#import "VersionCompare.h"
#import "TLinkIOSLogging.h"
#import "DBDebugLogger.h"
#include <sys/stat.h>
#include <unistd.h>

static NSUInteger gChecks, gFailures, gSelections, gCacheChanges;
static PXRuntimeSourceStore *gStore;
static NSString *gRoot, *gSelected, *gExpectedIdentity, *gBuild = @"B1";
static BOOL gFailDB, gNoHardware, gNoFirmware, gUnknownCellular, gDisabledCellular, gWebCompat;
static BOOL gNoCDMA, gNoTACs, gNoMEIDPrefixes;
static NSUInteger gTelephonyLookups, gPreparations, gMigrations;
static NSUInteger gBatchNotifications, gArtifactAdoptions, gBatteryNotifications;
static BOOL gFailSerial, gThrowBatteryPublication;
static void (^gDuringPrepare)(void);
static void (^gDuringPublication)(void);
static void (^gDuringResolve)(void);
static void CheckLeaseFree(void);
#define CHECK(value, message) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", message); } } while (0)
static NSString *Path(NSString *root, NSString *name) { return [root stringByAppendingPathComponent:name]; }
static NSString *Identity(NSString *profile) { return Path(Path(gRoot, profile), @"identity"); }
static NSDictionary *IDs(NSString *identity) { return [NSDictionary dictionaryWithContentsOfFile:Path(identity, @"device_ids.plist")] ?: @{}; }
BOOL PXPerformRuntimeSourceWrite(BOOL (^body)(PXRuntimeSourceTransaction *, NSError **), NSError **error) { return [gStore performWrite:body error:error]; }
NSString *PXActiveProfileID(void) { return gSelected; }
NSString *PXValidatedProfileID(id value) { return [value isKindOfClass:NSString.class] && [@[@"a", @"b"] containsObject:value] ? [value copy] : nil; }
NSString *PXProfileIdentityPath(NSString *profile) { return PXValidatedProfileID(profile) ? Identity(profile) : nil; }
NSString *PXProfileRootPath(NSString *profile) { return PXValidatedProfileID(profile) ? Path(gRoot, profile) : nil; }
NSString *PXProfilesPath(void) { return gRoot; }
NSString *PXProfileDeletionJournalPath(void) { return Path(gRoot, @".profile-delete-journal.plist"); }
NSString *PXTLinkIOSSettingsPath(void) { return Path(gRoot, @"settings.plist"); }
NSString *PXGlobalScopePath(void) { return Path(gRoot, @"scope.plist"); }
NSString *PXCurrentProfileInfoPath(void) { return Path(gRoot, @"selection.plist"); }
NSString *PXLegacyActiveProfileInfoPath(void) { return Path(gRoot, @"legacy-selection.plist"); }
NSString *PXSecuritySettingsPath(void) { return Path(gRoot, @"security.plist"); }
void PXPostSettingsChangedNotification(void) {
    gBatchNotifications++;
    CHECK([gStore capture:^NSDictionary *(NSError **error) { (void)error; return @{}; } error:NULL] != nil,
          "batch notification runs outside source gate after commit");
}
void PXLog(NSString *format, ...) { (void)format; }
void PXDBLog(NSString *format, ...) { (void)format; }
static BOOL PXWebCompatIOSRangeEnabled(void) { return gWebCompat; }
static NSDictionary *Snapshot(NSString *identity) {
    return [gStore capture:^NSDictionary *(NSError **error) {
        (void)error;
        NSMutableDictionary *files = [NSMutableDictionary dictionary];
        for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:identity error:nil]) {
            if ([name hasSuffix:@".plist"]) files[name] = [NSData dataWithContentsOfFile:Path(identity, name)];
        }
        return @{ @"files": files };
    } error:NULL];
}
static BOOL Seed(NSString *identity, NSDictionary *ids, BOOL legacy) {
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        if (![tx setDictionary:ids atPath:Path(identity, @"device_ids.plist") error:error]) return NO;
        for (NSString *file in @[@"imei.plist", @"meid.plist"])
            if (legacy && ![tx setDictionary:@{ @"value": @"legacy" } atPath:Path(identity, file) error:error]) return NO;
        return YES;
    } error:NULL];
}
static void Preparation(void) {
    gPreparations++;
    CHECK(Snapshot(gExpectedIdentity) != nil, "DB and generation run outside source gate");
    void (^callback)(void) = gDuringPrepare;
    gDuringPrepare = nil;
    if (callback) callback();
}
static BOOL HasLegacy(NSString *identity) {
    return [NSFileManager.defaultManager fileExistsAtPath:Path(identity, @"imei.plist")] ||
           [NSFileManager.defaultManager fileExistsAtPath:Path(identity, @"meid.plist")];
}
static NSDictionary *Hardware(void) {
    return @{ @"name": @"Fixture phone", @"screenResolution": @"1170x2532", @"viewportResolution": @"390x844",
        @"devicePixelRatio": @3, @"nativeScale": @3, @"screenDensity": @460, @"cpuArchitecture": @"arm64",
        @"cpuProfileKey": @"fixture-cpu", @"deviceMemory": @6, @"cpuCoreCount": @6,
        @"hasFrontCamera": @YES, @"hasRearCamera": @YES, @"storageCapacitiesGB": @[@128, @256] };
}
static NSDictionary *Model(NSString *product) {
    return @{ @"productType": product, @"name": @"Fixture phone", @"minIOS": @"13.0", @"maxIOS": @"17.0",
        @"variants": @[@{ @"boardID": @"D37AP", @"hwModel": @"D37AP", @"regulatoryModelNumbers": @[@"A2846"] }] };
}
@interface IPhoneModelDB : NSObject
+ (instancetype)sharedManager;
- (BOOL)loadIfNeeded:(NSError **)error;
- (NSDictionary *)randomModelMinIOS:(NSString *)min error:(NSError **)error;
- (BOOL)containsProductType:(NSString *)product;
- (NSDictionary *)specForProductType:(NSString *)product;
- (NSDictionary *)canonicalHardwareSpecForProductType:(NSString *)product;
- (NSDictionary *)cellularSpecForProductType:(NSString *)product regulatoryModelNumber:(NSString *)regulatory;
- (NSDictionary *)basebandMetaForProductType:(NSString *)product regulatoryModelNumber:(NSString *)regulatory iosBuild:(NSString *)build;
@end
@implementation IPhoneModelDB
+ (instancetype)sharedManager { static id instance; static dispatch_once_t once; dispatch_once(&once, ^{ instance = [self new]; }); return instance; }
- (BOOL)loadIfNeeded:(NSError **)error {
    Preparation(); if (gFailDB && error) *error = [NSError errorWithDomain:@"fixture" code:1 userInfo:nil]; return !gFailDB;
}
- (NSDictionary *)randomModelMinIOS:(NSString *)min error:(NSError **)error { (void)min; (void)error; return Model(@"iPhone15,4"); }
- (BOOL)containsProductType:(NSString *)product { return [product hasPrefix:@"iPhone"]; }
- (NSDictionary *)specForProductType:(NSString *)product { Preparation(); return [product hasPrefix:@"iPhone"] ? Model(product) : nil; }
- (NSDictionary *)canonicalHardwareSpecForProductType:(NSString *)product { (void)product; Preparation(); return gNoHardware ? nil : Hardware(); }
- (NSDictionary *)cellularSpecForProductType:(NSString *)product regulatoryModelNumber:(NSString *)regulatory {
    (void)product; (void)regulatory; gTelephonyLookups++; Preparation();
    return @{ @"known": @(!gUnknownCellular), @"enabled": @(!gDisabledCellular), @"dualSIM": @YES,
        @"cdma": @(!gNoCDMA), @"imeiTACs": gNoTACs ? @[] : @[@"12345678"],
        @"meidPrefixes": gNoMEIDPrefixes ? @[] : @[@"A00000"] };
}
- (NSDictionary *)basebandMetaForProductType:(NSString *)product regulatoryModelNumber:(NSString *)regulatory iosBuild:(NSString *)build {
    (void)product; (void)regulatory; Preparation();
    return gNoFirmware ? nil : @{ @"basebandFamily": @"fixture-modem", @"basebandVersion": [@"firmware-" stringByAppendingString:build] };
}
@end
@interface IOSBuildDB : NSObject
+ (instancetype)sharedManager;
- (BOOL)loadIfNeeded:(NSError **)error;
- (NSDictionary *)randomMetaForDevice:(NSString *)product min:(NSString *)min max:(NSString *)max error:(NSError **)error;
@end
@implementation IOSBuildDB
+ (instancetype)sharedManager { static id instance; static dispatch_once_t once; dispatch_once(&once, ^{ instance = [self new]; }); return instance; }
- (BOOL)loadIfNeeded:(NSError **)error { (void)error; Preparation(); return YES; }
- (NSDictionary *)randomMetaForDevice:(NSString *)product min:(NSString *)min max:(NSString *)max error:(NSError **)error {
    (void)product; (void)min; (void)max; (void)error; Preparation();
    return @{ @"version": @"17.0", @"build": gBuild, @"darwin": @"23.0", @"xnu": @"fixture-xnu", @"kernel_version": @"fixture-kernel" };
}
@end
@interface DeviceModelManager : NSObject
+ (instancetype)sharedManager;
- (BOOL)isValidDeviceModel:(NSString *)value;
- (NSDictionary *)deviceSpecificationsForModel:(NSString *)product;
- (NSString *)deviceModelNameForString:(NSString *)product;
- (NSDictionary *)webGLInfoForModel:(NSString *)product;
- (void)setCurrentDeviceModel:(NSString *)product;
@end
@implementation DeviceModelManager
+ (instancetype)sharedManager { static id instance; static dispatch_once_t once; dispatch_once(&once, ^{ instance = [self new]; }); return instance; }
- (BOOL)isValidDeviceModel:(NSString *)value { return [value isEqual:@"iPad1,1"]; }
- (NSDictionary *)deviceSpecificationsForModel:(NSString *)product { (void)product; Preparation(); return Hardware(); }
- (NSString *)deviceModelNameForString:(NSString *)product { (void)product; return @"Fixture phone"; }
- (NSDictionary *)webGLInfoForModel:(NSString *)product { (void)product; return @{}; }
- (void)setCurrentDeviceModel:(NSString *)product {
    gCacheChanges++;
    CHECK(Snapshot(gExpectedIdentity) != nil && [IDs(gExpectedIdentity)[@"DeviceModel"] isEqual:product] && !HasLegacy(gExpectedIdentity),
          "model compatibility callback runs after complete commit outside gate");
}
@end
@interface IOSVersionInfo : NSObject
+ (instancetype)sharedManager;
- (void)setCurrentIOSVersionInfo:(NSDictionary *)value;
@end
@implementation IOSVersionInfo
+ (instancetype)sharedManager { static id instance; static dispatch_once_t once; dispatch_once(&once, ^{ instance = [self new]; }); return instance; }
- (void)setCurrentIOSVersionInfo:(NSDictionary *)value {
    gCacheChanges++;
    CHECK(Snapshot(gExpectedIdentity) != nil && [IDs(gExpectedIdentity)[@"IOSBuild"] isEqual:value[@"build"]] && !HasLegacy(gExpectedIdentity),
          "software compatibility callback runs after complete commit outside gate");
}
@end
#define ARTIFACT_SINGLETON + (instancetype)sharedManager { static id instance; static dispatch_once_t once; dispatch_once(&once, ^{ instance = [self new]; }); return instance; }
static void Adopt(void) {
    void (^callback)(void) = gDuringPublication; gDuringPublication = nil; if (callback) callback();
    gArtifactAdoptions++;
    CHECK(Snapshot(gExpectedIdentity) != nil && IDs(gExpectedIdentity)[@"SSID"] != nil,
          "batch compatibility adoption follows source commit outside gate");
}
@interface SerialNumberManager : NSObject
+ (instancetype)sharedManager;
- (NSString *)prepareSerialNumber;
- (NSError *)lastError;
@end
@implementation SerialNumberManager
ARTIFACT_SINGLETON
- (NSString *)prepareSerialNumber { Preparation(); return gFailSerial ? nil : PXPrepareRuntimeSerial(@"FVF", NULL); }
- (NSError *)lastError { return [NSError errorWithDomain:@"fixture.serial" code:1 userInfo:nil]; }
@end
@interface WiFiManager : NSObject
+ (instancetype)sharedManager;
- (void)adoptCommittedWiFiInfo:(NSDictionary *)info profileID:(NSString *)profile;
@end
@implementation WiFiManager
ARTIFACT_SINGLETON
- (void)adoptCommittedWiFiInfo:(NSDictionary *)info profileID:(NSString *)profile { (void)info; (void)profile; Adopt(); }
@end
@interface StorageManager : NSObject
+ (instancetype)sharedManager;
- (void)adoptCommittedStorageInfo:(NSDictionary *)info;
@end
@implementation StorageManager
ARTIFACT_SINGLETON
- (void)adoptCommittedStorageInfo:(NSDictionary *)info { (void)info; Adopt(); }
@end
@interface UptimeManager : NSObject
+ (instancetype)sharedManager;
- (void)adoptCommittedUptimeInfo:(NSDictionary *)info timestamp:(NSDate *)timestamp;
@end
@implementation UptimeManager
ARTIFACT_SINGLETON
- (void)adoptCommittedUptimeInfo:(NSDictionary *)info timestamp:(NSDate *)timestamp { (void)info; (void)timestamp; Adopt(); }
@end
@interface BatteryManager : NSObject
+ (instancetype)sharedManager;
- (void)adoptCommittedBatteryInfo:(NSDictionary *)info;
- (void)publishCommittedBatteryInfo:(NSDictionary *)info timestamp:(NSDate *)timestamp;
@end
@implementation BatteryManager
ARTIFACT_SINGLETON
- (void)adoptCommittedBatteryInfo:(NSDictionary *)info { (void)info; Adopt(); }
- (void)publishCommittedBatteryInfo:(NSDictionary *)info timestamp:(NSDate *)timestamp {
    (void)timestamp; gBatteryNotifications++;
    CHECK([info[@"LowPowerMode"] boolValue] && [IDs(gExpectedIdentity)[@"LowPowerMode"] boolValue], "batch battery preserves captured target LPM");
    if (gThrowBatteryPublication) [NSException raise:@"fixture" format:@"post commit observer failure"];
}
@end
#include "PXDeviceGroupStatics.inc"
@interface PXDeviceGroupFixture : NSObject {
    NSMutableDictionary *_appEnabledCache;
}
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSMutableDictionary *settings;
@property (nonatomic, strong) NSMutableDictionary *scopedApps;
@property (nonatomic, strong) NSMutableDictionary *spoofCache;
- (NSString *)profileIdentityPath;
- (BOOL)isIdentifierEnabled:(NSString *)type;
- (BOOL)migrateProfileSchemaAtIdentityDirectory:(NSString *)identity;
- (void)publishPreparedIdentifier:(NSString *)value type:(NSString *)type includeNameAndSerial:(BOOL)includeNameAndSerial;
#include "PXDeviceGroupDeclarations.inc"
@end
@implementation PXDeviceGroupFixture
- (instancetype)init {
    if ((self = [super init])) {
        _settings = [@{ @"IMEI": @YES, @"MEID": @YES } mutableCopy];
        _scopedApps = [NSMutableDictionary dictionary]; _spoofCache = [NSMutableDictionary dictionary];
        _appEnabledCache = [NSMutableDictionary dictionary];
    }
    return self;
}
- (NSString *)profileIdentityPath {
    gSelections++;
    void (^callback)(void) = gDuringResolve; gDuringResolve = nil;
    if (callback) callback();
    return gSelected ? Identity(gSelected) : nil;
}
- (BOOL)isIdentifierEnabled:(NSString *)type { return [self.settings[type] boolValue]; }
- (BOOL)migrateProfileSchemaAtIdentityDirectory:(NSString *)identity { gMigrations++; CHECK([identity isEqual:Identity(@"a")] || [identity isEqual:Identity(@"b")], "explicit wrapper migrates only supplied target"); return YES; }
- (void)publishPreparedIdentifier:(NSString *)value type:(NSString *)type includeNameAndSerial:(BOOL)includeNameAndSerial {
    (void)includeNameAndSerial; gCacheChanges++;
    CHECK([IDs(gExpectedIdentity)[type] isEqual:value] && Snapshot(gExpectedIdentity) != nil,
          "batch scalar publisher sees committed value outside gate");
}
#include "PXDeviceGroupMethods.inc"
@end

static void TestGroups(PXDeviceGroupFixture *manager, NSString *a, NSString *b) {
    gSelected = @"a"; gExpectedIdentity = a; gSelections = 0;
    CHECK(Seed(a, @{ @"GenerationCounter": @7, @"SSID": @"old", @"ModelNumber": @"stale", @"WebGLMaxRenderBufferSize": @99 }, YES) &&
          Seed(b, @{ @"keep": @YES }, NO), "group fixtures seeded");
    gDuringPrepare = ^{
        NSMutableDictionary *latest = [IDs(a) mutableCopy]; latest[@"SSID"] = @"concurrent";
        CHECK(Seed(a, latest, NO), "competing unrelated source write committed"); gSelected = @"b";
    };
    CHECK([[manager regenerateDeviceProfileGroup] isEqual:@"iPhone15,4"] && gSelections == 1 && !IDs(b)[@"DeviceModel"], "fixed target survives profile switch");
    NSDictionary *ids = IDs(a);
    CHECK([ids[@"SSID"] isEqual:@"concurrent"] && [ids[@"GenerationCounter"] isEqual:@8], "unrelated update survives preparation and counter increments once");
    CHECK([ids[@"IOSBuild"] isEqual:@"B1"] && [ids[@"BasebandVersion"] isEqual:@"firmware-B1"] &&
          PXValidateIdentityValue(ids[@"IMEI"], PXIdentityValueKindIMEI, NO) &&
          PXValidateIdentityValue(ids[@"MEID"], PXIdentityValueKindMEID, NO) && ![ids[@"IMEI"] isEqual:ids[@"IMEI2"]], "production regional generation creates distinct validated identities with matching build");
    CHECK(!ids[@"ModelNumber"] && !ids[@"WebGLMaxRenderBufferSize"] && !HasLegacy(a), "replacement removes stale fields and legacy sidecars");
    gSelected = @"a";
    CHECK(Seed(a, ids, YES), "rollback legacy files seeded");
    chmod(Path(a, @"imei.plist").fileSystemRepresentation, 0600);
    NSDictionary *before = Snapshot(a); NSUInteger caches = gCacheChanges;
    __block NSUInteger writes = 0;
    gStore.testCheckpoint = ^(NSString *stage) { if ([stage isEqual:@"source-written"] && ++writes == 2) [NSException raise:@"fixture" format:@"after deletion"]; };
    CHECK([manager regenerateDeviceProfileGroup] == nil && manager.error != nil, "group commit failure reported");
    gStore.testCheckpoint = nil;
    struct stat st = {0}; stat(Path(a, @"imei.plist").fileSystemRepresentation, &st);
    CHECK([before isEqual:Snapshot(a)] && (st.st_mode & 0777) == 0600 && caches == gCacheChanges, "model rollback restores removed sidecars bytes modes counter and cache");
    CHECK([manager setCustomDeviceModel:@"iPhone16,1"], "custom model commits");
    ids = IDs(a);
    CHECK([ids[@"GenerationCounter"] isEqual:@8] && [ids[@"DeviceModel"] isEqual:@"iPhone16,1"] &&
          !ids[@"IOSBuild"] && !ids[@"BasebandVersion"] && !ids[@"IMEI"] && !HasLegacy(a), "custom model preserves counter and invalidates old dependent tuple");
    CHECK([manager regenerateDeviceProfileGroup] != nil, "coherent baseline restored");
    gNoHardware = YES; before = Snapshot(a); caches = gCacheChanges;
    CHECK([manager regenerateDeviceProfileGroup] == nil && [before isEqual:Snapshot(a)] && caches == gCacheChanges, "missing authoritative hardware cannot mutate group");
    gNoHardware = NO; gNoFirmware = YES;
    CHECK([manager regenerateDeviceProfileGroup] == nil && [before isEqual:Snapshot(a)], "known cellular without firmware fails closed");
    gNoFirmware = NO; gUnknownCellular = YES;
    CHECK([manager regenerateDeviceProfileGroup] != nil && !IDs(a)[@"CellularCapable"] && !IDs(a)[@"IMEI"], "unknown cellular stays absent");
    gUnknownCellular = NO;
    gFailDB = YES; before = Snapshot(a);
    CHECK([manager regenerateDeviceProfileGroup] == nil && [before isEqual:Snapshot(a)], "database load failure leaves persisted sources intact");
    gFailDB = NO;
    CHECK(Seed(a, @{ @"GenerationCounter": @(NSIntegerMax) }, YES), "counter exhaustion fixture seeded");
    before = Snapshot(a); caches = gCacheChanges;
    CHECK([manager regenerateDeviceProfileGroup] == nil && [before isEqual:Snapshot(a)] && caches == gCacheChanges, "counter exhaustion leaves entire group intact");
}
static void TestDependentRefresh(PXDeviceGroupFixture *manager, NSString *a, NSString *b) {
    gSelected = @"a"; gExpectedIdentity = a; gBuild = @"B1";
    CHECK(Seed(a, @{ @"GenerationCounter": @10 }, YES) && [manager regenerateDeviceProfileGroup] != nil, "software baseline seeded");
    NSString *imei = IDs(a)[@"IMEI"];
    gBuild = @"B2"; gSelections = 0;
    gDuringPrepare = ^{ gSelected = @"b"; NSMutableDictionary *latest = [IDs(a) mutableCopy]; latest[@"SSID"] = @"new"; CHECK(Seed(a, latest, NO), "unrelated software preparation write committed"); };
    CHECK([manager generateIOSVersion] != nil && gSelections == 1 && !IDs(b)[@"IOSBuild"] &&
          [IDs(a)[@"IOSBuild"] isEqual:@"B2"] && [IDs(a)[@"BasebandVersion"] isEqual:@"firmware-B2"] &&
          [IDs(a)[@"GenerationCounter"] isEqual:@11] && [IDs(a)[@"SSID"] isEqual:@"new"], "software refresh includes matching baseband preserves counter and captured target");
    CHECK([IDs(a)[@"IMEI"] isEqual:imei], "software refresh keeps valid regional identity");
    gSelected = @"a"; gBuild = @"B3";
    __block NSDictionary *competitor;
    NSUInteger caches = gCacheChanges;
    gDuringPrepare = ^{ NSMutableDictionary *latest = [IDs(a) mutableCopy]; latest[@"RegulatoryModelNumber"] = @"changed"; CHECK(Seed(a, latest, NO), "competing dependency update seeded"); competitor = Snapshot(a); };
    CHECK([manager generateIOSVersion] == nil && manager.error != nil && [competitor isEqual:Snapshot(a)] && caches == gCacheChanges,
          "dependency drift rejects prepared software without overwriting competitor");
    CHECK([manager regenerateDeviceProfileGroup] != nil, "cellular refresh baseline restored");
    imei = IDs(a)[@"IMEI"]; NSNumber *counter = IDs(a)[@"GenerationCounter"];
    CHECK([manager refreshCanonicalCellularIdentityForCurrentProfile] && [IDs(a)[@"IMEI"] isEqual:imei] &&
          [IDs(a)[@"GenerationCounter"] integerValue] == counter.integerValue + 1, "cellular refresh preserves valid IMEI and increments once");
    gDuringPrepare = ^{ NSMutableDictionary *latest = [IDs(a) mutableCopy]; latest[@"IOSBuild"] = @"competing-build"; CHECK(Seed(a, latest, NO), "competing cellular tuple seeded"); competitor = Snapshot(a); };
    CHECK(![manager refreshCanonicalCellularIdentityForCurrentProfile] && [competitor isEqual:Snapshot(a)], "cellular dependency drift cannot overwrite competing build");
    CHECK([manager regenerateDeviceProfileGroup] != nil, "coherent tuple restored after conflict");
    gNoFirmware = YES;
    NSDictionary *before = Snapshot(a);
    CHECK([manager generateIOSVersion] == nil && [before isEqual:Snapshot(a)], "software refresh with missing firmware cannot commit mixed tuple");
    gNoFirmware = NO;
    CHECK(Seed(a, @{ @"GenerationCounter": @0 }, YES), "fallback fixture seeded");
    gSelections = 0; gDuringPrepare = ^{ gSelected = @"b"; };
    CHECK([manager generateIOSVersion] != nil && gSelections == 1 && [IDs(a)[@"IOSBuild"] isEqual:gBuild] && !IDs(b)[@"DeviceModel"], "missing model fallback keeps captured target");
}
static NSString *InvokeTelephony(PXDeviceGroupFixture *manager, BOOL imei, BOOL generate, NSString *value) {
    if (generate) return imei ? [manager generateIMEI] : [manager generateMEID];
    BOOL saved = imei ? [manager setCustomIMEI:value] : [manager setCustomMEID:value];
    return saved ? value : nil;
}
static void TestTelephony(PXDeviceGroupFixture *manager, NSString *a, NSString *b) {
    gSelected = @"a"; gExpectedIdentity = a;
    NSString *imei = PXGenerateIMEIFromAuthoritativeTACs(@[@"12345678"]);
    NSString *meid = [PXGenerateMEIDFromAuthoritativePrefixes(@[@"A00000"]) lowercaseString];
    NSDictionary *baseline = @{ @"DeviceModel": @"iPhone15,4", @"RegulatoryModelNumber": @"A2846", @"IOSBuild": @"B1",
        @"IMEI": imei, @"MEID": meid, @"GenerationCounter": @12, @"SSID": @"before" };
    for (NSUInteger mode = 0; mode < 4; mode++) {
        BOOL isIMEI = mode < 2, generate = (mode % 2) == 1;
        NSString *key = isIMEI ? @"IMEI" : @"MEID";
        NSString *file = isIMEI ? @"imei.plist" : @"meid.plist";
        NSString *otherKey = isIMEI ? @"MEID" : @"IMEI";
        NSString *otherFile = isIMEI ? @"meid.plist" : @"imei.plist";
        NSString *input = isIMEI ? imei : meid;
        CHECK(Seed(a, baseline, YES), "standalone telephony fixture seeded");
        NSData *otherSidecar = [NSData dataWithContentsOfFile:Path(a, otherFile)];
        NSDictionary *otherIDs = IDs(b);
        gSelected = @"a"; gSelections = 0; gTelephonyLookups = 0;
        gDuringPrepare = ^{
            NSMutableDictionary *latest = [IDs(a) mutableCopy]; latest[@"SSID"] = @"concurrent";
            CHECK(Seed(a, latest, NO), "telephony unrelated update committed"); gSelected = @"b";
        };
        NSString *result = InvokeTelephony(manager, isIMEI, generate, input);
        CHECK(result != nil && gSelections == 1 && gTelephonyLookups == 1 && [otherIDs isEqual:IDs(b)],
              "four telephony APIs keep one target and one regional lookup");
        NSDictionary *sidecar = [NSDictionary dictionaryWithContentsOfFile:Path(a, file)];
        CHECK([IDs(a)[key] isEqual:result] && [sidecar[@"value"] isEqual:result] &&
              [sidecar[@"lastUpdated"] isKindOfClass:NSDate.class] && [IDs(a)[@"GenerationCounter"] isEqual:@13] &&
              [IDs(a)[@"SSID"] isEqual:@"concurrent"], "telephony pair merges unrelated fields and increments once");
        CHECK([IDs(a)[otherKey] isEqual:baseline[otherKey]] && [otherSidecar isEqual:[NSData dataWithContentsOfFile:Path(a, otherFile)]],
              "standalone IMEI and MEID keep independent fields and sidecars");
        if (!isIMEI && !generate) CHECK([IDs(a)[key] isEqual:meid], "manual lowercase MEID spelling preserved");
        gSelected = @"a";
        CHECK(Seed(a, baseline, YES), "telephony drift fixture seeded");
        __block NSDictionary *competitor;
        gDuringPrepare = ^{
            NSMutableDictionary *latest = [IDs(a) mutableCopy]; latest[@"RegulatoryModelNumber"] = @"changed";
            CHECK(Seed(a, latest, NO), "competing telephony region committed"); competitor = Snapshot(a);
        };
        CHECK(InvokeTelephony(manager, isIMEI, generate, input) == nil && manager.error != nil && [competitor isEqual:Snapshot(a)],
              "four telephony APIs reject dependency drift without sidecar writes");
        CHECK(Seed(a, baseline, YES), "telephony rollback fixture seeded");
        NSDictionary *before = Snapshot(a);
        __block BOOL interrupted = NO;
        gStore.testCheckpoint = ^(NSString *stage) { if (!interrupted && [stage isEqual:@"source-written"]) {
            interrupted = YES; [NSException raise:@"fixture" format:@"telephony pair failure"];
        } };
        CHECK(InvokeTelephony(manager, isIMEI, generate, input) == nil && manager.error != nil, "telephony persistence error returned");
        gStore.testCheckpoint = nil;
        CHECK([before isEqual:Snapshot(a)], "telephony pair failure restores bytes counter and commit identity");
    }
    CHECK(Seed(a, baseline, YES), "telephony policy baseline seeded");
    gSelections = 0; NSDictionary *before = Snapshot(a);
    CHECK(![manager setCustomIMEI:nil] && ![manager setCustomMEID:@"invalid"] && gSelections == 0 && [before isEqual:Snapshot(a)],
          "invalid manual formats reject before target lookup");
    gUnknownCellular = YES;
    CHECK(![manager setCustomIMEI:imei] && ![manager setCustomMEID:meid] && [manager generateIMEI] == nil &&
          [manager generateMEID] == nil && [before isEqual:Snapshot(a)], "unknown cellular rejects all standalone APIs");
    gUnknownCellular = NO; gDisabledCellular = YES;
    CHECK(![manager setCustomIMEI:imei] && ![manager setCustomMEID:meid] && [manager generateIMEI] == nil &&
          [manager generateMEID] == nil && [before isEqual:Snapshot(a)], "disabled cellular rejects all standalone APIs");
    gDisabledCellular = NO; gNoCDMA = YES;
    CHECK(![manager setCustomMEID:meid] && [manager generateMEID] == nil && [before isEqual:Snapshot(a)], "non CDMA rejects standalone MEID");
    CHECK([manager setCustomIMEI:imei], "non CDMA still permits valid IMEI");
    gNoCDMA = NO;
    before = Snapshot(a);
    CHECK(![manager setCustomIMEI:PXGenerateIMEIFromAuthoritativeTACs(@[@"87654321"])] &&
          ![manager setCustomMEID:PXGenerateMEIDFromAuthoritativePrefixes(@[@"B00000"])] && [before isEqual:Snapshot(a)],
          "valid checksums cannot bypass regional prefix policy");
    gNoTACs = YES; gNoMEIDPrefixes = YES;
    CHECK([manager generateIMEI] == nil && [manager generateMEID] == nil && [before isEqual:Snapshot(a)],
          "missing authoritative prefixes never use generic generation");
    gNoTACs = NO; gNoMEIDPrefixes = NO;
    CHECK(Seed(a, baseline, YES), "manual input lifetime fixture seeded");
    NSMutableString *mutableInput = [imei mutableCopy];
    gDuringPrepare = ^{ [mutableInput setString:@"changed-after-validation"]; };
    CHECK([manager setCustomIMEI:mutableInput] && [IDs(a)[@"IMEI"] isEqual:imei], "manual input copy survives provider callbacks");
    for (NSString *key in @[@"DeviceModel", @"IOSBuild", @"IMEI", @"IMEI2"]) {
        CHECK(Seed(a, baseline, YES), "telephony dependency field fixture seeded");
        __block NSDictionary *changed;
        gDuringPrepare = ^{
            NSMutableDictionary *latest = [IDs(a) mutableCopy]; latest[key] = @"changed-dependency";
            CHECK(Seed(a, latest, NO), "telephony dependency field changed"); changed = Snapshot(a);
        };
        CHECK(![manager setCustomIMEI:imei] && [changed isEqual:Snapshot(a)], "captured model build and existing identities reject drift including absence");
    }
    CHECK(Seed(a, @{ @"DeviceModel": @"iPhone15,4", @"GenerationCounter": @0 }, YES), "missing regulatory fixture seeded");
    before = Snapshot(a);
    CHECK(![manager setCustomIMEI:imei] && ![manager setCustomMEID:meid] && [manager generateIMEI] == nil &&
          [manager generateMEID] == nil && [before isEqual:Snapshot(a)], "iPhone writes reject missing regulatory slot");
    CHECK(Seed(a, @{ @"DeviceModel": @"iPad1,1", @"GenerationCounter": @0 }, YES), "legacy non iPhone fixture seeded");
    CHECK([manager setCustomIMEI:imei] && [manager setCustomMEID:meid] && [IDs(a)[@"GenerationCounter"] isEqual:@2],
          "manual non iPhone compatibility policy preserved");
    before = Snapshot(a);
    CHECK([manager generateIMEI] == nil && [manager generateMEID] == nil && [before isEqual:Snapshot(a)],
          "generation requires canonical slot even for legacy model");
    NSMutableDictionary *exhausted = [baseline mutableCopy]; exhausted[@"GenerationCounter"] = @(NSIntegerMax);
    CHECK(Seed(a, exhausted, YES), "telephony exhausted counter fixture seeded"); before = Snapshot(a);
    CHECK(![manager setCustomIMEI:imei] && [manager generateMEID] == nil && [before isEqual:Snapshot(a)],
          "telephony counter exhaustion preserves complete pair");
    CHECK(Seed(a, baseline, YES), "telephony malformed sidecar fixture seeded");
    NSData *badBytes = [@"malformed sidecar" dataUsingEncoding:NSUTF8StringEncoding];
    CHECK([badBytes writeToFile:Path(a, @"imei.plist") atomically:YES], "malformed telephony sidecar prepared");
    before = Snapshot(a);
    CHECK(![manager setCustomIMEI:imei] && [before isEqual:Snapshot(a)], "malformed telephony sidecar is never silently replaced");
    CheckLeaseFree();
}
static void TestModelPreparation(PXDeviceGroupFixture *manager, NSString *identity) {
    gExpectedIdentity = identity; gSelected = @"a";
    CHECK(Seed(identity, @{ @"GenerationCounter": @0, @"keep": @YES }, YES), "model preparation fixture seeded");
    NSDictionary *before = Snapshot(identity); NSUInteger caches = gCacheChanges;
    NSMutableDictionary *options = [@{ @"webCompat": @NO, @"wantsIMEI": @YES, @"wantsMEID": @YES } mutableCopy];
    gSelections = 0;
    gDuringPrepare = ^{ options[@"wantsIMEI"] = @NO; gSelected = @"b"; };
    NSError *error = nil;
    PXPreparedDeviceProfileGroup *prepared = [manager prepareDeviceProfileGroupWithOptions:options error:&error];
    CHECK(prepared != nil && error == nil && prepared.updates[@"IMEI"] != nil && gSelections == 0 &&
          gCacheChanges == caches && [before isEqual:Snapshot(identity)], "model prepare captures options without source writes selection or cache publication");
    CHECK([gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return PXStageRuntimeIdentifierReplacement(tx, identity, prepared.updates, prepared.replacedKeys, nil, YES, YES, writeError);
    } error:NULL] && gCacheChanges == caches, "prepared model stages independently without publishing callbacks");
    [manager publishPreparedDeviceProfileGroup:prepared];
    CHECK(gCacheChanges == caches + 2 && [IDs(identity)[@"GenerationCounter"] isEqual:@1], "prepared model publishes caches only after explicit commit");
    NSMutableString *model = [@"iPhone15,4" mutableCopy];
    NSMutableArray *capacities = [@[@128] mutableCopy], *keys = [@[@"DeviceModel"] mutableCopy];
    NSMutableDictionary *updates = [@{ @"DeviceModel": model, @"StorageCapacitiesGB": capacities } mutableCopy];
    NSMutableDictionary *version = [@{ @"version": @"17.0" } mutableCopy];
    PXPreparedDeviceProfileGroup *detached = [[PXPreparedDeviceProfileGroup alloc] initWithUpdates:updates replacedKeys:keys versionInfo:version error:&error];
    [model setString:@"changed"]; [capacities addObject:@256]; [keys addObject:@"IMEI"]; version[@"version"] = @"changed";
    CHECK([detached.updates[@"DeviceModel"] isEqual:@"iPhone15,4"] && [detached.updates[@"StorageCapacitiesGB"] count] == 1 &&
          detached.replacedKeys.count == 1 && [detached.versionInfo[@"version"] isEqual:@"17.0"], "prepared model deep detaches mutable provider graphs");
    CHECK([[PXPreparedDeviceProfileGroup alloc] initWithUpdates:@{} replacedKeys:(id)@[@1] versionInfo:@{} error:&error] == nil && error != nil,
          "prepared model rejects malformed ownership keys");
    CHECK([manager prepareDeviceProfileGroupWithOptions:@{ @"wantsIMEI": NSNull.null } error:&error] == nil && error != nil,
          "model preparation rejects malformed flags before DB work");
    gSelected = @"a";
}
static NSDictionary *BatchSnapshot(void) {
    return [gStore capture:^NSDictionary *(NSError **error) {
        (void)error; NSMutableDictionary *files = [NSMutableDictionary dictionary];
        for (NSString *relative in [NSFileManager.defaultManager subpathsAtPath:gRoot])
            if (![relative hasPrefix:@"control/"] && [relative hasSuffix:@".plist"])
                files[relative] = [NSData dataWithContentsOfFile:Path(gRoot, relative)];
        return @{ @"files": files };
    } error:NULL];
}
static BOOL SetSource(NSString *path, NSString *key, id value) {
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        NSMutableDictionary *record = [[tx dictionaryAtPath:path error:error] mutableCopy];
        if (!record) return NO;
        record[key] = value;
        return [tx setDictionary:record atPath:path error:error];
    } error:NULL];
}
static void TestBatchGeneration(PXDeviceGroupFixture *manager, NSString *a, NSString *b) {
    gSelected = @"a"; gExpectedIdentity = a; gFailDB = NO; gBuild = @"B1";
    NSMutableDictionary *flags = [NSMutableDictionary dictionary];
    for (NSString *key in PXCanonicalIdentifierToggleKeys()) flags[key] = @YES;
    manager.settings = [flags mutableCopy];
    manager.scopedApps = [@{ @"fixture.app": [@{ @"enabled": @YES } mutableCopy] } mutableCopy];
    CHECK(Seed(a, @{ @"GenerationCounter": @20, @"DeviceTheme": @"Light" }, YES), "batch IDs seeded");
    NSString *batteryPath = Path(a, @"battery_info.plist");
    NSString *storagePath = Path(a.stringByDeletingLastPathComponent, @"storage.plist");
    CHECK(SetSource(batteryPath, @"LowPowerMode", @YES) && SetSource(storagePath, @"TotalStorage", @"128") &&
          SetSource(PXTLinkIOSSettingsPath(), @"UnrelatedFeature", @YES), "batch artifact and settings bases seeded");
    __block NSUInteger commits = 0;
    gStore.testCheckpoint = ^(NSString *stage) { if ([stage isEqual:@"commit-written"]) commits++; };
    NSUInteger notices = gBatchNotifications, batteryNotices = gBatteryNotifications;
    gSelections = 0; NSError *error = nil;
    CHECK([manager regenerateAllEnabledIdentifiersWithError:&error] && error == nil && commits == 1 && gSelections == 1,
          "whole regenerate commits once at one captured target");
    gStore.testCheckpoint = nil;
    NSDictionary *ids = IDs(a);
    for (NSString *type in PXRuntimeGenerationScalarTypes()) {
        NSDictionary *sidecar = [NSDictionary dictionaryWithContentsOfFile:Path(a, PXRuntimeIdentifierSidecar(type))];
        CHECK([ids[type] isEqual:sidecar[@"value"]], "batch scalar and sidecar agree");
    }
    NSDictionary *wifi = [NSDictionary dictionaryWithContentsOfFile:Path(a, @"wifi_info.plist")];
    NSDictionary *battery = [NSDictionary dictionaryWithContentsOfFile:batteryPath];
    NSDictionary *storage = [NSDictionary dictionaryWithContentsOfFile:storagePath];
    NSDictionary *uptime = [NSDictionary dictionaryWithContentsOfFile:Path(a, @"system_uptime.plist")];
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:PXTLinkIOSSettingsPath()];
    CHECK([ids[@"GenerationCounter"] isEqual:@21] && [ids[@"SSID"] isEqual:wifi[@"ssid"]] &&
          [ids[@"BatteryLevel"] isEqual:battery[@"BatteryLevel"]] && [ids[@"SystemUptime"] isEqual:uptime[@"value"]] &&
          [storage[@"TotalStorage"] isEqual:@"256"] && [settings[@"EnabledIdentifiers"] isEqual:flags] &&
          [settings[@"UnrelatedFeature"] boolValue] && gBatchNotifications == notices + 1 && gBatteryNotifications == batteryNotices + 1,
          "whole batch joins artifacts settings scope and counter before publication");
    NSDictionary *before = BatchSnapshot(); NSUInteger caches = gCacheChanges, adoptions = gArtifactAdoptions;
    notices = gBatchNotifications; batteryNotices = gBatteryNotifications;
    for (NSNumber *cut in @[@1, @3, @10]) {
        __block NSUInteger writes = 0;
        gStore.testCheckpoint = ^(NSString *stage) {
            if ([stage isEqual:@"source-written"] && ++writes == cut.unsignedIntegerValue) [NSException raise:@"fixture" format:@"batch write failure"];
        };
        CHECK(![manager regenerateAllEnabledIdentifiersWithError:&error] && error != nil, "batch source failure reported");
        gStore.testCheckpoint = nil;
        CHECK([before isEqual:BatchSnapshot()] && caches == gCacheChanges && adoptions == gArtifactAdoptions &&
              notices == gBatchNotifications && batteryNotices == gBatteryNotifications,
              "whole batch rollback restores artifacts settings scope without cache or notification");
    }
    gFailDB = YES;
    CHECK(![manager regenerateAllEnabledIdentifiersWithError:&error] && [before isEqual:BatchSnapshot()], "batch DB preparation failure writes nothing");
    gFailDB = NO; gFailSerial = YES;
    CHECK(![manager regenerateAllEnabledIdentifiersWithError:&error] && [before isEqual:BatchSnapshot()] && caches == gCacheChanges,
          "batch scalar preparation failure leaves all source and caches intact");
    gFailSerial = NO;
    NSArray *changes = @[
        @[Path(a, @"device_ids.plist"), @"DeviceModel", @"changed-model"],
        @[Path(a, @"device_ids.plist"), @"IMEI", @"changed-imei"],
        @[Path(a, @"device_ids.plist"), @"SSID", @"changed-ssid"],
        @[Path(a, @"device_ids.plist"), @"IDFA", @"changed-idfa"],
        @[PXTLinkIOSSettingsPath(), @"EnabledIdentifiers", @{}],
        @[PXGlobalScopePath(), @"ScopedApps", @{}],
        @[PXSecuritySettingsPath(), @"webCompatIOSRangeEnabled", @YES],
        @[storagePath, @"TotalStorage", @"64"], @[batteryPath, @"LowPowerMode", @NO]
    ];
    for (NSArray *change in changes) {
        __block NSDictionary *competitor = nil;
        gDuringPrepare = ^{ CHECK(SetSource(change[0], change[1], change[2]), "batch competing dependency write commits"); competitor = BatchSnapshot(); };
        CHECK(![manager regenerateAllEnabledIdentifiersWithError:&error] && error != nil && competitor &&
              [competitor isEqual:BatchSnapshot()] && caches == gCacheChanges && notices == gBatchNotifications,
              "batch dependency drift rejects entire candidate including absence");
    }
    __block NSDictionary *presenceCompetitor = nil;
    gDuringPrepare = ^{
        CHECK([gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
            return [tx setDictionary:@{} atPath:Path(a.stringByDeletingLastPathComponent, @"battery_info.plist") error:writeError];
        } error:NULL], "empty legacy battery source appears during preparation");
        presenceCompetitor = BatchSnapshot();
    };
    CHECK(![manager regenerateAllEnabledIdentifiersWithError:&error] && [presenceCompetitor isEqual:BatchSnapshot()],
          "batch source presence drift rejects even without field differences");
    CHECK(SetSource(batteryPath, @"LowPowerMode", @YES), "batch target LPM restored");
    NSInteger expectedCounter = [IDs(a)[@"GenerationCounter"] integerValue] + 6;
    gDuringPrepare = ^{
        manager.settings[@"IDFA"] = @NO;
        manager.scopedApps[@"fixture.app"][@"enabled"] = @NO;
        CHECK(SetSource(Path(a, @"device_ids.plist"), @"CarrierName", @"concurrent-carrier"), "batch disjoint writer commits");
        CHECK(SetSource(Path(a, @"device_ids.plist"), @"GenerationCounter", @(expectedCounter - 1)), "batch competing counter advances");
    };
    CHECK([manager regenerateAllEnabledIdentifiersWithError:&error] && [IDs(a)[@"CarrierName"] isEqual:@"concurrent-carrier"] &&
          [IDs(a)[@"GenerationCounter"] integerValue] == expectedCounter &&
          [[[NSDictionary dictionaryWithContentsOfFile:PXTLinkIOSSettingsPath()] objectForKey:@"EnabledIdentifiers"][@"IDFA"] boolValue] &&
          [[[NSDictionary dictionaryWithContentsOfFile:PXGlobalScopePath()] objectForKey:@"ScopedApps"][@"fixture.app"][@"enabled"] boolValue],
          "batch freezes nested caller intent and merges unrelated updates");
    manager.settings = [flags mutableCopy]; manager.scopedApps[@"fixture.app"][@"enabled"] = @YES;
    NSDictionary *other = Snapshot(b); caches = gCacheChanges; adoptions = gArtifactAdoptions; notices = gBatchNotifications;
    gSelections = 0; gDuringPrepare = ^{ gSelected = @"b"; };
    CHECK([manager regenerateAllEnabledIdentifiersWithError:&error] && gSelections == 1 && [other[@"files"] isEqual:Snapshot(b)[@"files"]] &&
          caches == gCacheChanges && adoptions == gArtifactAdoptions && gBatchNotifications == notices + 1,
          "batch target switch commits A and skips inactive compatibility caches");
    // Snapshot carries the global source token, which legitimately advances for A.
    gSelected = @"a";
    gThrowBatteryPublication = YES; notices = gBatchNotifications;
    CHECK([manager regenerateAllEnabledIdentifiersWithError:&error] && error == nil && gBatchNotifications == notices + 1,
          "post commit callback exception cannot report a false rollback");
    gThrowBatteryPublication = NO;
    NSMutableDictionary *exhausted = [IDs(a) mutableCopy]; exhausted[@"GenerationCounter"] = @(NSIntegerMax);
    CHECK(Seed(a, exhausted, YES), "batch counter exhaustion seeded"); before = BatchSnapshot(); notices = gBatchNotifications;
    CHECK(![manager regenerateAllEnabledIdentifiersWithError:&error] && [before isEqual:BatchSnapshot()] && notices == gBatchNotifications,
          "batch counter exhaustion prevents every artifact and notification");
    exhausted[@"GenerationCounter"] = @0; CHECK(Seed(a, exhausted, YES), "batch counter restored");
    NSString *sidecarPath = Path(a, @"advertising_id.plist"); NSData *saved = [NSData dataWithContentsOfFile:sidecarPath];
    CHECK([[@"malformed" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:sidecarPath atomically:YES], "batch malformed sidecar injected");
    before = BatchSnapshot();
    CHECK(![manager regenerateAllEnabledIdentifiersWithError:&error] && [before isEqual:BatchSnapshot()], "batch malformed beforeimage fails without replacing any source");
    CHECK([saved writeToFile:sidecarPath atomically:YES], "batch scalar sidecar restored");
    [manager.settings removeAllObjects];
    NSNumber *counter = IDs(a)[@"GenerationCounter"]; NSString *build = IDs(a)[@"IOSBuild"];
    CHECK([manager regenerateAllEnabledIdentifiersWithError:&error] && [IDs(a)[@"GenerationCounter"] isEqual:counter] &&
          [IDs(a)[@"IOSBuild"] isEqual:build] && IDs(a)[@"SSID"] != nil, "batch disabled options preserve tuple and unconditional WiFi policy");
    manager.settings[@"IMEI"] = @YES;
    CHECK([manager regenerateAllEnabledIdentifiersWithError:&error] && [IDs(a)[@"IOSBuild"] isEqual:build] &&
          [IDs(a)[@"GenerationCounter"] integerValue] == counter.integerValue + 1, "batch cellular only refresh preserves model and build");
    [manager.settings removeAllObjects]; CHECK(Seed(a, @{}, YES), "batch missing baseline seeded");
    CHECK([manager regenerateAllEnabledIdentifiersWithError:&error] && [IDs(a)[@"GenerationCounter"] isEqual:@1] &&
          IDs(a)[@"DeviceModel"] && !IDs(a)[@"IMEI"] && IDs(a)[@"DeviceTheme"], "batch missing baseline seeds canonical group with frozen cellular policy");
    gSelected = nil; before = BatchSnapshot(); notices = gBatchNotifications;
    CHECK(![manager regenerateAllEnabledIdentifiersWithError:&error] && error != nil &&
          [before isEqual:BatchSnapshot()] && notices == gBatchNotifications, "batch missing target fails before any source write");
    gSelected = @"a";
    NSMutableDictionary *savedScope = manager.scopedApps;
    manager.scopedApps = nil; before = BatchSnapshot();
    CHECK(![manager regenerateAllEnabledIdentifiersWithError:&error] && error != nil && [before isEqual:BatchSnapshot()],
          "batch missing scope intent fails instead of revoking existing scope");
    manager.scopedApps = savedScope;
    manager.settings = [@{ @"IMEI": @YES, @"MEID": @YES } mutableCopy];
}


static void CheckLeaseFree(void) {
    NSError *error = nil;
    PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:gRoot error:&error];
    CHECK(lease != nil && error == nil, "owned batch releases lifecycle lease before callbacks and failures return");
    [lease invalidate];
}
static BOOL ClearDeletionIntent(void) {
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx removeDictionaryAtPath:PXProfileDeletionJournalPath() error:error];
    } error:NULL];
}
static void CheckTelephonyLeaseHeld(void) {
    NSError *error = nil;
    PXProfileLifecycleLease *other = [PXProfileLifecycleLease acquireInDirectory:gRoot error:&error];
    CHECK(!other && error.code == 12, "telephony owns lifecycle throughout target lookup and provider callbacks");
    [other invalidate];
    CHECK(Snapshot(gExpectedIdentity) != nil, "telephony lifecycle never holds source gate across provider work");
}
static void TestTelephonyLifecycle(PXDeviceGroupFixture *manager, NSString *a, NSString *b) {
    gSelected = @"a"; gExpectedIdentity = a;
    NSString *imei = PXGenerateIMEIFromAuthoritativeTACs(@[@"12345678"]);
    NSString *meid = [PXGenerateMEIDFromAuthoritativePrefixes(@[@"A00000"]) lowercaseString];
    NSDictionary *baseline = @{ @"DeviceModel": @"iPhone15,4", @"RegulatoryModelNumber": @"A2846", @"IOSBuild": @"B1",
        @"IMEI": imei, @"MEID": meid, @"GenerationCounter": @12, @"SSID": @"owned" };
    CHECK(Seed(a, baseline, YES), "owned telephony baseline seeded");
    PXProfileLifecycleLease *owner = [PXProfileLifecycleLease acquireInDirectory:gRoot error:NULL];
    CHECK(owner != nil, "competing telephony lifecycle owner acquired");
    NSUInteger selections = gSelections, preparations = gPreparations, lookups = gTelephonyLookups;
    NSDictionary *before = BatchSnapshot();
    for (NSUInteger mode = 0; mode < 4; mode++)
        CHECK(!InvokeTelephony(manager, mode < 2, mode % 2, mode < 2 ? imei : meid) && manager.error.code == 12,
              "all telephony APIs reject busy lifecycle before target and DB lookup");
    CHECK(selections == gSelections && preparations == gPreparations && lookups == gTelephonyLookups && [before isEqual:BatchSnapshot()],
          "busy telephony preserves every source byte and commit identity");
    [owner invalidate]; CheckLeaseFree();
    CHECK(SetSource(PXProfileDeletionJournalPath(), @"state", @"pending"), "telephony pending delete seeded");
    before = BatchSnapshot();
    for (NSUInteger mode = 0; mode < 4; mode++)
        CHECK(!InvokeTelephony(manager, mode < 2, mode % 2, mode < 2 ? imei : meid) && manager.error.code == 27,
              "all telephony APIs reject pending deletion before target and DB lookup");
    CHECK(selections == gSelections && preparations == gPreparations && lookups == gTelephonyLookups && [before isEqual:BatchSnapshot()],
          "pending telephony preserves source selection and preparation counts");
    CHECK(ClearDeletionIntent(), "telephony pending delete cleared"); CheckLeaseFree();
    for (NSUInteger mode = 0; mode < 4; mode++) {
        CHECK(Seed(a, baseline, YES), "owned telephony mode seeded");
        gDuringResolve = ^{ CheckTelephonyLeaseHeld(); };
        gDuringPrepare = ^{
            CheckTelephonyLeaseHeld();
            CHECK(![manager setCustomIMEI:imei] && manager.error.code == 12, "telephony provider reentry fails busy without deadlock");
        };
        CHECK(InvokeTelephony(manager, mode < 2, mode % 2, mode < 2 ? imei : meid) && !manager.error &&
              [IDs(a)[@"GenerationCounter"] isEqual:@13], "telephony owned success clears reentry error and increments once");
        CheckLeaseFree();
        before = BatchSnapshot();
        gDuringPrepare = ^{ CheckTelephonyLeaseHeld(); [NSException raise:@"fixture" format:@"telephony provider exception"]; };
        BOOL threw = NO;
        @try { (void)InvokeTelephony(manager, mode < 2, mode % 2, mode < 2 ? imei : meid); }
        @catch (NSException *exception) { (void)exception; threw = YES; }
        CHECK(threw && [before isEqual:BatchSnapshot()], "telephony provider exception preserves sources and releases lease"); CheckLeaseFree();
        __block NSDictionary *competitor = nil;
        gDuringPrepare = ^{
            CHECK(SetSource(PXProfileDeletionJournalPath(), @"state", @"late"), "telephony late delete committed by bypass writer");
            competitor = BatchSnapshot();
        };
        CHECK(!InvokeTelephony(manager, mode < 2, mode % 2, mode < 2 ? imei : meid) && manager.error.code == 27 && [competitor isEqual:BatchSnapshot()],
              "late deletion blocks telephony sidecar IDs counter and commit token together");
        CHECK(ClearDeletionIntent(), "telephony late delete cleared"); CheckLeaseFree();
        for (NSUInteger kind = 0; kind < 3; kind++) {
            NSString *old = Path(a.stringByDeletingLastPathComponent, @"owned-old-identity");
            __block BOOL moved = NO; competitor = nil;
            gDuringPrepare = ^{
                moved = [NSFileManager.defaultManager moveItemAtPath:a toPath:old error:NULL];
                if (kind == 1) moved = moved && [NSFileManager.defaultManager createDirectoryAtPath:a withIntermediateDirectories:NO attributes:nil error:NULL];
                if (kind == 2) moved = moved && [NSFileManager.defaultManager createSymbolicLinkAtPath:a withDestinationPath:b error:NULL];
                competitor = BatchSnapshot();
            };
            CHECK(!InvokeTelephony(manager, mode < 2, mode % 2, mode < 2 ? imei : meid) && manager.error && moved && [competitor isEqual:BatchSnapshot()],
                  "telephony rejects missing replaced and symlink identity without touching competitor bytes");
            if (kind != 0) CHECK([NSFileManager.defaultManager removeItemAtPath:a error:NULL], "telephony replacement fixture removed");
            CHECK([NSFileManager.defaultManager moveItemAtPath:old toPath:a error:NULL], "telephony original identity restored"); CheckLeaseFree();
        }
    }
    before = BatchSnapshot();
    gDuringResolve = ^{ CheckTelephonyLeaseHeld(); [NSException raise:@"fixture" format:@"telephony resolver exception"]; };
    BOOL threw = NO;
    @try { [manager generateIMEI]; } @catch (NSException *exception) { (void)exception; threw = YES; }
    CHECK(threw && [before isEqual:BatchSnapshot()], "telephony resolver exception releases acquired ownership"); CheckLeaseFree();
    gSelected = nil; preparations = gPreparations;
    CHECK(![manager generateMEID] && manager.error && preparations == gPreparations && [before isEqual:BatchSnapshot()],
          "telephony missing selection fails before provider and releases lease"); CheckLeaseFree(); gSelected = @"a";
    CHECK(Seed(a, baseline, YES), "telephony mutable type fixture seeded");
    NSMutableString *mutableType = [@"IMEI" mutableCopy];
    gDuringPrepare = ^{ [mutableType setString:@"MEID"]; };
    CHECK([manager prepareAndPersistTelephonyValue:imei type:mutableType generate:NO] && !manager.error &&
          [IDs(a)[@"IMEI"] isEqual:imei] && [IDs(a)[@"MEID"] isEqual:meid], "telephony copies type before provider can mutate caller input");
    CheckLeaseFree();
}
static void TestGenerationLifecycle(PXDeviceGroupFixture *manager, NSString *a) {
    gSelected = @"a"; gExpectedIdentity = a;
    manager.settings = [@{ @"DeviceModel": @YES, @"IMEI": @YES, @"MEID": @YES } mutableCopy];
    NSError *error = nil;
    PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:gRoot error:&error];
    CHECK(lease && !error, "batch contention owner acquired");
    NSString *alias = Path(gRoot, @"profiles-alias");
    CHECK([NSFileManager.defaultManager createSymbolicLinkAtPath:alias withDestinationPath:gRoot error:&error] &&
          [lease validateForDirectory:alias error:&error], "borrowed capability accepts configured root aliases by inode");
    CHECK([NSFileManager.defaultManager removeItemAtPath:alias error:&error], "fixture root alias removed");
    NSUInteger selections = gSelections, preparations = gPreparations, migrations = gMigrations;
    NSUInteger notices = gBatchNotifications, caches = gCacheChanges, adoptions = gArtifactAdoptions;
    NSDictionary *before = BatchSnapshot();
    CHECK(![manager regenerateAllEnabledIdentifiersWithError:&error] && error.code == 12,
          "held lifecycle lease blocks current batch before target lookup");
    CHECK(![manager regenerateAllEnabledIdentifiersForProfileID:@"a" networkArtifacts:nil error:&error] && error.code == 12,
          "held lifecycle lease blocks explicit batch before migration");
    CHECK(![manager commitRuntimeGenerationForProfileID:@"a" networkArtifacts:nil error:&error] && error.code == 12,
          "held lifecycle lease blocks standalone deferred generation");
    CHECK(selections == gSelections && preparations == gPreparations && migrations == gMigrations &&
          notices == gBatchNotifications && caches == gCacheChanges && adoptions == gArtifactAdoptions && [before isEqual:BatchSnapshot()],
          "busy generation leaves source providers target resolution and caches untouched");
    PXCommittedRuntimeGeneration *receipt = [manager commitRuntimeGenerationForProfileID:@"a" networkArtifacts:nil lifecycleLease:lease error:&error];
    CHECK(receipt && !error && [lease validateWithError:NULL] && notices == gBatchNotifications && caches == gCacheChanges,
          "borrowed generation succeeds without recursively acquiring or releasing caller lease");
    PXProfileLifecycleLease *competitor = [PXProfileLifecycleLease acquireInDirectory:gRoot error:&error];
    CHECK(!competitor && error.code == 12, "borrowed generation leaves caller ownership held after success");
    [competitor invalidate];
    before = BatchSnapshot();
    gDuringPrepare = ^{ [NSException raise:@"fixture" format:@"provider preparation exception"]; };
    CHECK(![manager commitRuntimeGenerationForProfileID:@"a" networkArtifacts:nil lifecycleLease:lease error:&error] && error &&
          [lease validateWithError:NULL] && [before isEqual:BatchSnapshot()], "borrowed generation exception preserves source and caller lease");
    [lease invalidate];
    preparations = gPreparations; migrations = gMigrations;
    CHECK(![manager commitRuntimeGenerationForProfileID:@"a" networkArtifacts:nil lifecycleLease:lease error:&error] && error &&
          preparations == gPreparations && migrations == gMigrations, "invalidated capability rejected before migration and providers");
    NSString *otherRoot = Path(gRoot, @"unrelated-root");
    CHECK([NSFileManager.defaultManager createDirectoryAtPath:otherRoot withIntermediateDirectories:NO attributes:nil error:&error], "unrelated lease root created");
    lease = [PXProfileLifecycleLease acquireInDirectory:otherRoot error:&error];
    CHECK(lease && ![manager commitRuntimeGenerationForProfileID:@"a" networkArtifacts:nil lifecycleLease:lease error:&error] && error &&
          preparations == gPreparations && migrations == gMigrations && [lease validateWithError:NULL],
          "wrong root capability rejected while preserving its ownership");
    [lease invalidate];
    CHECK([NSFileManager.defaultManager removeItemAtPath:otherRoot error:&error], "unrelated fixture lease root removed");
    // Presence alone blocks mutation, including unknown/malformed logical intents.
    CHECK(SetSource(PXProfileDeletionJournalPath(), @"state", @"fixture-pending"), "pending deletion intent seeded");
    before = BatchSnapshot(); selections = gSelections;
    CHECK(![manager regenerateAllEnabledIdentifiersWithError:&error] && error.code == 27 &&
          ![manager regenerateAllEnabledIdentifiersForProfileID:@"a" networkArtifacts:nil error:&error] && error.code == 27 &&
          ![manager commitRuntimeGenerationForProfileID:@"a" networkArtifacts:nil error:&error] && error.code == 27 &&
          preparations == gPreparations && migrations == gMigrations && selections == gSelections && [before isEqual:BatchSnapshot()],
          "pending deletion blocks all owned batch APIs before target lookup migration or preparation");
    lease = [PXProfileLifecycleLease acquireInDirectory:gRoot error:&error];
    CHECK(lease && ![manager commitRuntimeGenerationForProfileID:@"a" networkArtifacts:nil lifecycleLease:lease error:&error] && error.code == 27 &&
          [lease validateWithError:NULL], "pending deletion also blocks borrowed batch without releasing caller");
    [lease invalidate]; CHECK(ClearDeletionIntent(), "pending deletion fixture cleared"); CheckLeaseFree();
    before = BatchSnapshot();
    gDuringPrepare = ^{ [NSException raise:@"fixture" format:@"owned provider exception"]; };
    CHECK(![manager regenerateAllEnabledIdentifiersWithError:&error] && error && [before isEqual:BatchSnapshot()] &&
          notices == gBatchNotifications && caches == gCacheChanges, "owned provider exception leaves source and callbacks untouched");
    CheckLeaseFree();
    __block BOOL preparationObserved = NO, publicationObserved = NO;
    gDuringPrepare = ^{
        NSError *busy = nil;
        PXProfileLifecycleLease *other = [PXProfileLifecycleLease acquireInDirectory:gRoot error:&busy];
        preparationObserved = !other && busy.code == 12; [other invalidate];
    };
    gDuringPublication = ^{ CheckLeaseFree(); publicationObserved = YES; };
    CHECK([manager regenerateAllEnabledIdentifiersWithError:&error] && !error && preparationObserved && publicationObserved,
          "batch holds lifecycle during providers and releases before compatibility publication");
    // Simulate a writer that ignores the lifecycle contract during preparation.
    __block NSDictionary *competitorState = nil;
    gDuringPrepare = ^{
        CHECK(SetSource(PXProfileDeletionJournalPath(), @"state", @"late-pending"), "bypass writer installs deletion during preparation");
        competitorState = BatchSnapshot();
    };
    notices = gBatchNotifications; caches = gCacheChanges;
    CHECK(![manager regenerateAllEnabledIdentifiersWithError:&error] && error.code == 27 && competitorState &&
          [competitorState isEqual:BatchSnapshot()] && notices == gBatchNotifications && caches == gCacheChanges,
          "late deletion intent rejects batch before staging any artifact");
    CHECK(ClearDeletionIntent(), "late intent fixture cleared"); CheckLeaseFree();
    NSString *profilePath = a.stringByDeletingLastPathComponent, *displaced = Path(gRoot, @"displaced-a");
    __block BOOL replaced = NO;
    competitorState = nil;
    gDuringPrepare = ^{
        replaced = [NSFileManager.defaultManager moveItemAtPath:profilePath toPath:displaced error:NULL];
        if (replaced) replaced = [NSFileManager.defaultManager createDirectoryAtPath:a withIntermediateDirectories:YES attributes:nil error:NULL];
        competitorState = BatchSnapshot();
    };
    CHECK(![manager regenerateAllEnabledIdentifiersWithError:&error] && error && replaced &&
          [competitorState isEqual:BatchSnapshot()] && notices == gBatchNotifications && caches == gCacheChanges,
          "directory replacement rejects prepared batch without writing replacement or old target");
    CHECK([NSFileManager.defaultManager removeItemAtPath:profilePath error:&error] &&
          [NSFileManager.defaultManager moveItemAtPath:displaced toPath:profilePath error:&error], "original batch directory restored after bypass fixture");
    CheckLeaseFree();
}

static void TestExplicitCreationGeneration(PXDeviceGroupFixture *manager, NSString *a, NSString *b) {
    gSelected = @"b"; gExpectedIdentity = a; gSelections = 0;
    manager.settings = [@{ @"DeviceModel": @YES, @"IMEI": @YES, @"MEID": @YES } mutableCopy];
    CHECK(Seed(a, @{ @"GenerationCounter": @0 }, NO), "explicit creation target seeded");
    NSDictionary *other = Snapshot(b); NSUInteger caches = gCacheChanges;
    NSDictionary *network = @{ @"carrier": @{ @"carrierName": @"creation-carrier", @"mcc": @"310", @"mnc": @"260" },
        @"ipv4": @"192.168.1.77", @"ipv6": @"fd00::77" };
    NSError *error = nil;
    __block NSUInteger commits = 0;
    gStore.testCheckpoint = ^(NSString *stage) { if ([stage isEqual:@"commit-written"]) commits++; };
    CHECK([manager regenerateAllEnabledIdentifiersForProfileID:@"a" networkArtifacts:network error:&error] && !error &&
          gSelections == 0 && commits == 1 && caches == gCacheChanges && [other[@"files"] isEqual:Snapshot(b)[@"files"]],
          "explicit creation generation never retargets to active profile");
    gStore.testCheckpoint = nil;
    NSDictionary *record = [NSDictionary dictionaryWithContentsOfFile:Path(a, @"network_settings.plist")];
    CHECK([IDs(a)[@"CarrierName"] isEqual:@"creation-carrier"] && [IDs(a)[@"LocalIPAddress"] isEqual:@"192.168.1.77"] &&
          [record[@"localIPv6Address"] isEqual:@"fd00::77"] && [IDs(a)[@"LocalIPv6Address"] isEqual:record[@"localIPv6Address"]],
          "creation network and identifier artifacts share one source commit");
    NSDictionary *before = BatchSnapshot();
    __block NSUInteger writes = 0;
    gStore.testCheckpoint = ^(NSString *stage) { if ([stage isEqual:@"source-written"] && ++writes == 4) [NSException raise:@"fixture" format:@"creation group fault"]; };
    CHECK(![manager regenerateAllEnabledIdentifiersForProfileID:@"a" networkArtifacts:network error:&error], "explicit creation source fault reported");
    gStore.testCheckpoint = nil;
    CHECK([before isEqual:BatchSnapshot()], "creation network rollback restores entire generated tuple");
    CHECK(![manager regenerateAllEnabledIdentifiersForProfileID:@"../b" networkArtifacts:network error:&error] &&
          [before isEqual:BatchSnapshot()], "explicit creation rejects invalid target before migration or staging");
    CHECK(![manager regenerateAllEnabledIdentifiersForProfileID:@"a" networkArtifacts:(id)@[] error:&error] &&
          [before isEqual:BatchSnapshot()], "explicit creation rejects malformed prepared network");
    CHECK(SetSource(Path(a, @"network_settings.plist"), @"localIPv6Address", @"fd00::99"), "existing creation IPv6 seeded");
    CHECK([manager regenerateAllEnabledIdentifiersForProfileID:@"a" networkArtifacts:network error:&error] &&
          [IDs(a)[@"LocalIPv6Address"] isEqual:@"fd00::99"], "creation preserves existing IPv6 pair policy");
    gSelected = @"a";
}

static void TestDeferredActivation(PXDeviceGroupFixture *manager, NSString *a) {
    gSelected = @"b"; gExpectedIdentity = a; gSelections = 0;
    manager.settings[@"IDFA"] = @YES;
    CHECK([gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return PXStageRuntimeProfileSelection(tx, @{ @"ProfileId": @"b", @"SelectionRevision": @"initial" }, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), error);
    } error:NULL], "deferred activation initial selection seeded");
    NSData *settings = [NSData dataWithContentsOfFile:PXTLinkIOSSettingsPath()], *scope = [NSData dataWithContentsOfFile:PXGlobalScopePath()];
    NSUInteger caches = gCacheChanges, notices = gBatchNotifications;
    NSError *error = nil;
    PXCommittedRuntimeGeneration *receipt = [manager commitRuntimeGenerationForProfileID:@"a" networkArtifacts:@{} error:&error];
    CHECK(receipt && !error && [receipt.payload[@"deferSettings"] boolValue] && gSelections == 0 &&
          caches == gCacheChanges && notices == gBatchNotifications && [settings isEqual:[NSData dataWithContentsOfFile:PXTLinkIOSSettingsPath()]] &&
          [scope isEqual:[NSData dataWithContentsOfFile:PXGlobalScopePath()]], "inactive generation defers settings scope caches and notification");
    CHECK(SetSource(Path(a, @"device_ids.plist"), @"concurrent", @YES), "committed target changed before activation");
    CHECK(![gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return PXRuntimeGenerationMatchesProof(tx, receipt.proof, writeError) && PXStageRuntimeGenerationSettings(tx, receipt.payload, writeError);
    } error:&error] && [settings isEqual:[NSData dataWithContentsOfFile:PXTLinkIOSSettingsPath()]], "receipt proof rejects artifact drift without global writes");
    receipt = [manager commitRuntimeGenerationForProfileID:@"a" networkArtifacts:@{} error:&error];
    CHECK(receipt && notices == gBatchNotifications, "fresh receipt remains unpublished");
    __block NSDictionary *expected = nil;
    CHECK([gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        expected = PXReadRuntimeProfileSelection(tx, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), writeError);
        return expected != nil;
    } error:NULL], "activation basis captured");
    CHECK([gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return PXRuntimeGenerationMatchesProof(tx, receipt.proof, writeError) &&
            PXStageRuntimeGenerationSettings(tx, receipt.payload, writeError) &&
            PXStageRuntimeProfileSelectionIfUnchanged(tx, @{ @"ProfileId": @"a", @"SelectionRevision": @"activated" }, expected,
                PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), writeError);
    } error:&error] && !error && caches == gCacheChanges && notices == gBatchNotifications,
          "activation commits deferred settings scope selection before publication");
    gSelected = @"a";
    [manager publishCommittedRuntimeGeneration:receipt];
    CHECK(caches < gCacheChanges && notices + 1 == gBatchNotifications &&
          [[[NSDictionary dictionaryWithContentsOfFile:PXTLinkIOSSettingsPath()] objectForKey:@"EnabledIdentifiers"][@"IDFA"] boolValue],
          "committed receipt publishes only after deferred global activation");
    NSMutableDictionary *flags = [@{ @"IDFA": @YES } mutableCopy];
    NSMutableDictionary *info = [@{ @"keep": @YES } mutableCopy];
    PXCommittedRuntimeGeneration *detached = [[PXCommittedRuntimeGeneration alloc] initWithIdentityDirectory:a
        payload:@{ @"flags": flags } proof:@{ Path(a, @"device_ids.plist"): @{ @"exists": @YES, @"info": info } } model:nil error:&error];
    flags[@"IDFA"] = @NO; info[@"keep"] = @NO;
    CHECK([detached.payload[@"flags"][@"IDFA"] boolValue] && [detached.proof[Path(a, @"device_ids.plist")][@"info"][@"keep"] boolValue],
          "committed receipt deep detaches publication and activation proof");
    CHECK([[PXCommittedRuntimeGeneration alloc] initWithIdentityDirectory:a payload:(id)@[] proof:@{} model:nil error:&error] == nil && error,
          "receipt rejects malformed payload without throwing");
}

int main(void) {
    @autoreleasepool {
        gRoot = Path(NSTemporaryDirectory(), NSUUID.UUID.UUIDString);
        for (NSString *profile in @[@"a", @"b"])
            [NSFileManager.defaultManager createDirectoryAtPath:Identity(profile) withIntermediateDirectories:YES attributes:nil error:nil];
        gStore = [[PXRuntimeSourceStore alloc] initWithDirectory:Path(gRoot, @"control") owner:geteuid() group:getegid()
            allowsPath:^BOOL(NSString *path) { return [path hasPrefix:[gRoot stringByAppendingString:@"/"]] && [path hasSuffix:@".plist"] && ![path hasPrefix:Path(gRoot, @"control/")]; } error:NULL];
        CHECK(gStore != nil, "device group source backend initialized");
        PXDeviceGroupFixture *manager = [PXDeviceGroupFixture new];
        TestModelPreparation(manager, Identity(@"a"));
        TestGroups(manager, Identity(@"a"), Identity(@"b"));
        TestDependentRefresh(manager, Identity(@"a"), Identity(@"b"));
        TestBatchGeneration(manager, Identity(@"a"), Identity(@"b"));
        TestGenerationLifecycle(manager, Identity(@"a"));
        TestExplicitCreationGeneration(manager, Identity(@"a"), Identity(@"b"));
        TestDeferredActivation(manager, Identity(@"a"));
        TestTelephonyLifecycle(manager, Identity(@"a"), Identity(@"b"));
        TestTelephony(manager, Identity(@"a"), Identity(@"b"));
        gStore = nil;
        [NSFileManager.defaultManager removeItemAtPath:gRoot error:nil];
        printf("Runtime device group and telephony writers: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
