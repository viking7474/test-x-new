#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import "PXSecuritySettingsStore.h"
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
static NSUInteger gToggleSecurityWrites, gToggleSecondaryNotices, gToggleSecurityFailures, gToggleGenerations;
static NSString *gToggleMissingValue;
static void (^gDuringToggleGeneration)(void);
static void (^gAfterFailedStandaloneWrite)(void);
static NSUInteger gStandaloneSourceAttempts;
static void (^gDuringToggleSecurityWrite)(void);
static void (^gDuringToggleSecurityPublication)(void);
static NSUInteger gToggleSecurityPublications;
static void (^gDuringToggleSecondaryNotification)(void);
static BOOL gFailSerial, gThrowBatteryPublication;
static void (^gDuringPrepare)(void);
static void (^gDuringPublication)(void);
static void (^gDuringResolve)(void);
static void CheckLeaseFree(void);
static void ProbeDependencyPublication(void);
static BOOL gCheckDependencyPublication, gThrowDependencyPublication;
static BOOL gCheckDashboardPublication, gBadDashboardStorage, gFailDashboardTuple, gIncompleteDashboardTuple;
static NSDictionary *gDashboardStorage;
static NSString *gDashboardStorageModel;
static NSUInteger gDashboardStorageSelections;
static void ProbeDashboardStorage(NSDictionary *info);
static void (^gDuringDependencyPublication)(void);
static void (^gDuringScalarPublication)(void);
static void (^gDuringBatteryAdoption)(void);
static void (^gDuringRequiredNotification)(void);
#define CHECK(value, message) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", message); } } while (0)
static NSString *Path(NSString *root, NSString *name) { return [root stringByAppendingPathComponent:name]; }
static NSString *Identity(NSString *profile) { return Path(Path(gRoot, profile), @"identity"); }
static NSDictionary *IDs(NSString *identity) { return [NSDictionary dictionaryWithContentsOfFile:Path(identity, @"device_ids.plist")] ?: @{}; }
BOOL PXPerformRuntimeSourceWrite(BOOL (^body)(PXRuntimeSourceTransaction *, NSError **), NSError **error) { return [gStore performWrite:body error:error]; }
BOOL PXPerformStandaloneRuntimeSourceWrite(BOOL (^body)(PXRuntimeSourceTransaction *, NSError **), NSError **error) {
    gStandaloneSourceAttempts++;
    BOOL success = [gStore performStandaloneWrite:body error:error];
    // Model a competing owner scheduled after the source gate has been released.
    if (!success) {
        void (^callback)(void) = gAfterFailedStandaloneWrite; gAfterFailedStandaloneWrite = nil;
        if (callback) callback();
    }
    return success;
}
NSString *PXActiveProfileID(void) { return gSelected; }
NSString *PXValidatedProfileID(id value) { return [value isKindOfClass:NSString.class] && [@[@"a", @"b"] containsObject:value] ? [value copy] : nil; }
NSString *PXProfileIdentityPath(NSString *profile) { return PXValidatedProfileID(profile) ? Identity(profile) : nil; }
NSString *PXProfileRootPath(NSString *profile) { return PXValidatedProfileID(profile) ? Path(gRoot, profile) : nil; }
NSString *PXProfilesPath(void) { return gRoot; }
NSString *PXPreferencesPath(void) { return gRoot; }
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
    void (^callback)(void) = gDuringRequiredNotification; gDuringRequiredNotification = nil;
    if (callback) callback();
}
// Controlled security collaborator: real source commit, no defaults daemon or
// Darwin delivery in this host fixture. Faults can leave an already matching value.
id PXReadSecuritySetting(NSString *key) {
    return [NSDictionary dictionaryWithContentsOfFile:PXSecuritySettingsPath()][key];
}
BOOL PXWriteSecurityBool(NSString *key, BOOL value, NSError **error) {
    gToggleSecurityWrites++;
    if (gToggleSecurityFailures) {
        gToggleSecurityFailures--;
        if (error) *error = [NSError errorWithDomain:@"fixture.toggle.security" code:71 userInfo:nil];
        void (^callback)(void) = gDuringToggleSecurityWrite; gDuringToggleSecurityWrite = nil;
        if (callback) callback();
        return NO;
    }
    BOOL success = [gStore performStandaloneWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **failure) {
        NSDictionary *current = [tx dictionaryAtPath:PXSecuritySettingsPath() error:failure];
        if (!current) return NO;
        NSMutableDictionary *updated = [current mutableCopy]; updated[key] = @(value);
        return [tx setDictionary:updated atPath:PXSecuritySettingsPath() error:failure];
    } error:error];
    void (^callback)(void) = gDuringToggleSecurityWrite; gDuringToggleSecurityWrite = nil;
    if (callback) callback();
    return success;
}
BOOL PXWriteSecurityBoolWithRollbackAuthority(NSString *key, BOOL value, NSString *expectedIdentifier, NSString **rollbackIdentifier, NSError **error) {
    if (rollbackIdentifier) *rollbackIdentifier = nil;
    __block NSString *candidate = nil;
    gToggleSecurityWrites++;
    if (gToggleSecurityFailures) {
        gToggleSecurityFailures--;
        if (error) *error = [NSError errorWithDomain:@"fixture.toggle.security" code:71 userInfo:nil];
        void (^callback)(void) = gDuringToggleSecurityWrite; gDuringToggleSecurityWrite = nil;
        if (callback) callback();
        return NO;
    }
    BOOL success = [gStore performStandaloneWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **failure) {
        NSString *base = [tx baseCommitIdentifierWithError:failure];
        if (!base) return NO;
        BOOL ownsChain = [base isEqual:expectedIdentifier];
        NSDictionary *current = [tx dictionaryAtPath:PXSecuritySettingsPath() error:failure];
        if (!current) return NO;
        NSMutableDictionary *updated = [current mutableCopy]; updated[key] = @(value);
        if (![tx setDictionary:updated atPath:PXSecuritySettingsPath() error:failure]) return NO;
        candidate = ownsChain ? [tx prospectiveCommitIdentifierWithError:failure] : nil;
        return !ownsChain || candidate != nil;
    } error:error];
    if (success && rollbackIdentifier) *rollbackIdentifier = candidate;
    void (^callback)(void) = gDuringToggleSecurityWrite; gDuringToggleSecurityWrite = nil;
    if (callback) callback();
    return success;
}
BOOL PXPublishSecurityBoolForSourceCommit(NSString *key, BOOL value, NSString *identifier) {
    BOOL (^current)(PXRuntimeSourceTransaction *, NSError **) = ^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx requireBaseCommitIdentifier:identifier error:error];
    };
    if (![gStore performStandaloneWrite:current error:NULL]) return NO;
    gToggleSecurityPublications++;
    CHECK([PXReadSecuritySetting(key) boolValue] == value, "conditional rollback mirror sees atomically restored security state");
    void (^callback)(void) = gDuringToggleSecurityPublication; gDuringToggleSecurityPublication = nil;
    if (callback) callback();
    return [gStore performStandaloneWrite:current error:NULL];
}
static void PXToggleFixtureNotification(CFNotificationCenterRef center, CFStringRef name,
                                       const void *object, CFDictionaryRef info, Boolean immediately) {
    (void)center; (void)object; (void)info; (void)immediately;
    gToggleSecondaryNotices++;
    NSString *topic = (__bridge NSString *)name;
    CHECK(([@[@"com.hydra.tlinkios.toggleWifiSpoof", @"com.hydra.tlinkios.toggleBatterySpoof",
             @"com.hydra.tlinkios.toggleDeviceThemeSpoof"] containsObject:topic] &&
          [gStore capture:^NSDictionary *(NSError **error) { (void)error; return @{}; } error:NULL] != nil),
          "toggle secondary notification follows committed security write outside source gate");
    void (^callback)(void) = gDuringToggleSecondaryNotification; gDuringToggleSecondaryNotification = nil;
    if (callback) callback();
}
// Only provider signatures are needed for unexercised legacy branches. Existing
// values skip them; the IDFA provider below exercises the missing-value path.
@interface NSObject (PXLegacyToggleProviderDeclarations)
- (NSString *)currentValueForIdentifier:(NSString *)type;
- (NSString *)generateIDFA;
- (NSString *)generateIDFV;
- (NSString *)generateDeviceName;
- (NSString *)generateSerialNumber;
- (NSString *)generateUDID;
- (NSString *)generateSystemBootUUID;
- (NSString *)generateDyldCacheUUID;
- (NSString *)generatePasteboardUUID;
- (NSString *)generateKeychainUUID;
- (NSString *)generateUserDefaultsUUID;
- (NSString *)generateAppGroupUUID;
- (NSString *)generateCoreDataUUID;
- (NSString *)generateAppInstallUUID;
- (NSString *)generateAppContainerUUID;
- (NSString *)generateDeviceTheme;
- (void)generateUptimeForProfile:(NSString *)path;
- (void)generateBootTimeForProfile:(NSString *)path;
- (void)generateWiFiInfo;
- (NSDictionary *)generateBatteryInfo;
- (NSString *)randomizeStorageCapacity;
- (void)setTotalStorageCapacity:(id)value;
- (void)setFreeStorageSpace:(id)value;
- (void)setFilesystemType:(id)value;
@end
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
    if (gFailDashboardTuple) { if (error) *error = [NSError errorWithDomain:@"fixture.tuple" code:1 userInfo:nil]; return nil; }
    if (gIncompleteDashboardTuple) return @{ @"version": @"17.0", @"build": gBuild };
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
    ProbeDependencyPublication();
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
    ProbeDependencyPublication();
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
- (NSDictionary *)currentStorageInfo;
- (NSString *)randomizeStorageCapacityForDeviceModel:(NSString *)model;
- (NSDictionary *)generateStorageForCapacity:(NSString *)capacity;
@end
@implementation StorageManager
ARTIFACT_SINGLETON
- (NSDictionary *)currentStorageInfo { return gDashboardStorage ?: @{}; }
- (NSString *)randomizeStorageCapacityForDeviceModel:(NSString *)model {
    gDashboardStorageModel = [model copy]; gDashboardStorageSelections++; Preparation(); return @"128";
}
- (NSDictionary *)generateStorageForCapacity:(NSString *)capacity { Preparation(); return gBadDashboardStorage ? @{} : PXPrepareRuntimeStorage(capacity); }
- (void)adoptCommittedStorageInfo:(NSDictionary *)info { gDashboardStorage = [info copy]; Adopt(); ProbeDashboardStorage(info); }
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
- (void)adoptCommittedBatteryInfo:(NSDictionary *)info {
    (void)info; Adopt();
    void (^callback)(void) = gDuringBatteryAdoption; gDuringBatteryAdoption = nil;
    if (callback) callback();
}
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
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *identifierToggleOperations;
@property (nonatomic, strong) NSMutableDictionary *scopedApps;
@property (nonatomic, strong) NSMutableDictionary *spoofCache;
- (NSString *)profileIdentityPath;
- (NSString *)profileIdentityPathWithLifecycleLease:(PXProfileLifecycleLease *)lease;
- (BOOL)isIdentifierEnabled:(NSString *)type;
- (BOOL)migrateProfileSchemaAtIdentityDirectory:(NSString *)identity;
- (BOOL)migrateProfileSchemaAtIdentityDirectory:(NSString *)identity lifecycleLease:(PXProfileLifecycleLease *)lease;
- (void)publishPreparedIdentifier:(NSString *)value type:(NSString *)type includeNameAndSerial:(BOOL)includeNameAndSerial;
- (void)seedPersistenceCaches;
- (NSDictionary *)persistenceCaches;
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
- (NSString *)profileIdentityPathWithLifecycleLease:(PXProfileLifecycleLease *)lease {
    CHECK([lease validateForDirectory:gRoot error:NULL], "group target resolver receives held lifecycle capability");
    return [self profileIdentityPath];
}
- (BOOL)migrateProfileSchemaAtIdentityDirectory:(NSString *)identity lifecycleLease:(PXProfileLifecycleLease *)lease {
    CHECK([lease validateForDirectory:gRoot error:NULL], "group migration composes existing lifecycle capability");
    return [self migrateProfileSchemaAtIdentityDirectory:identity];
}
- (BOOL)isIdentifierEnabled:(NSString *)type { return [self.settings[type] boolValue]; }
- (void)seedPersistenceCaches { self.spoofCache[@"keep"] = @YES; _appEnabledCache[@"keep"] = @YES; }
- (NSDictionary *)persistenceCaches { return @{ @"spoof": [self.spoofCache copy], @"enabled": [_appEnabledCache copy] }; }
- (BOOL)migrateProfileSchemaAtIdentityDirectory:(NSString *)identity { gMigrations++; CHECK([identity isEqual:Identity(@"a")] || [identity isEqual:Identity(@"b")], "explicit wrapper migrates only supplied target"); return YES; }
- (void)publishPreparedIdentifier:(NSString *)value type:(NSString *)type includeNameAndSerial:(BOOL)includeNameAndSerial {
    (void)includeNameAndSerial; gCacheChanges++;
    CHECK([IDs(gExpectedIdentity)[type] isEqual:value] && Snapshot(gExpectedIdentity) != nil,
          "batch scalar publisher sees committed value outside gate");
    void (^callback)(void) = gDuringScalarPublication; gDuringScalarPublication = nil;
    if (callback) callback();
}
- (NSString *)currentValueForIdentifier:(NSString *)type { return [type isEqual:gToggleMissingValue] ? nil : @"existing"; }
- (NSString *)generateIDFA {
    gToggleGenerations++; gToggleMissingValue = nil;
    void (^callback)(void) = gDuringToggleGeneration; gDuringToggleGeneration = nil;
    if (callback) callback();
    return @"generated-idfa";
}
#define CFNotificationCenterPostNotification PXToggleFixtureNotification
#include "PXDeviceGroupMethods.inc"
#undef CFNotificationCenterPostNotification
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
    NSString *sidecarPath = Path(a, @"imei.plist");
    NSData *savedSidecar = [NSData dataWithContentsOfFile:sidecarPath];
    NSDictionary *clean = Snapshot(a);
    CHECK(savedSidecar != nil, "telephony malformed fixture captures original sidecar bytes");
    NSData *badBytes = [@"malformed sidecar" dataUsingEncoding:NSUTF8StringEncoding];
    @try {
        CHECK([badBytes writeToFile:sidecarPath atomically:YES], "malformed telephony sidecar prepared");
        before = Snapshot(a);
        CHECK(![manager setCustomIMEI:imei] && [before isEqual:Snapshot(a)], "malformed telephony sidecar is never silently replaced");
    } @finally {
        // Only fixture teardown restores the injected corruption. A source
        // writer must keep rejecting this malformed before-image; Seed cannot
        // overwrite it for the next suite sharing the same store.
        CHECK([savedSidecar writeToFile:sidecarPath atomically:YES], "telephony malformed fixture restores original sidecar bytes");
    }
    CHECK([clean isEqual:Snapshot(a)], "telephony corruption teardown restores files and global commit identity before later suites");
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
static void ProbeDependencyPublication(void) {
    if (!gCheckDependencyPublication) return;
    CheckLeaseFree();
    void (^callback)(void) = gDuringDependencyPublication; gDuringDependencyPublication = nil;
    if (callback) callback();
    if (gThrowDependencyPublication) [NSException raise:@"fixture" format:@"dependency publication exception"];
}
static BOOL InvokeDependency(PXDeviceGroupFixture *manager, NSUInteger mode) {
    if (mode == 0) return [manager regenerateDeviceProfileGroup] != nil;
    if (mode == 1) return [manager setCustomDeviceModel:@"iPhone16,1"];
    if (mode == 2 || mode == 4) return [manager generateIOSVersion] != nil;
    return [manager refreshCanonicalCellularIdentityForCurrentProfile];
}
static void CheckDependencyLeaseHeld(void) {
    NSError *error = nil;
    PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:gRoot error:&error];
    CHECK(!lease && error.code == 12, "model software cellular hold lifecycle across target and preparation");
    [lease invalidate];
    CHECK(Snapshot(gExpectedIdentity) != nil, "dependency providers run outside source gate");
}
static void TestDependencyLifecycle(PXDeviceGroupFixture *manager, NSString *a, NSString *b) {
    gSelected = @"a"; gExpectedIdentity = a; gBuild = @"B1";
    manager.settings = [@{ @"IMEI": @YES, @"MEID": @YES } mutableCopy];
    NSString *imei = PXGenerateIMEIFromAuthoritativeTACs(@[@"12345678"]);
    NSString *meid = PXGenerateMEIDFromAuthoritativePrefixes(@[@"A00000"]);
    NSDictionary *full = @{ @"DeviceModel": @"iPhone15,4", @"RegulatoryModelNumber": @"A2846", @"IOSBuild": @"B1",
        @"GenerationCounter": @12, @"IMEI": imei, @"MEID": meid, @"SSID": @"before" };
    NSDictionary *empty = @{ @"GenerationCounter": @12, @"SSID": @"fallback" };
    for (NSUInteger mode = 0; mode < 8; mode++) {
        NSMutableDictionary *baseline = [(mode == 4 || mode == 5 ? empty : full) mutableCopy];
        if (mode == 6) [baseline removeObjectForKey:@"RegulatoryModelNumber"];
        if (mode == 7) [baseline removeObjectForKey:@"IOSBuild"];
        gSelected = @"a";
        CHECK(Seed(a, baseline, YES), "dependency lifecycle baseline seeded");
        PXProfileLifecycleLease *owner = [PXProfileLifecycleLease acquireInDirectory:gRoot error:NULL];
        CHECK(owner != nil, "dependency competing owner acquired");
        NSUInteger selections = gSelections, preparations = gPreparations, caches = gCacheChanges;
        NSDictionary *before = BatchSnapshot();
        CHECK(!InvokeDependency(manager, mode) && manager.error.code == 12 && selections == gSelections && preparations == gPreparations &&
              caches == gCacheChanges && [before isEqual:BatchSnapshot()], "dependency APIs including fallbacks fail busy before target preparation and publication");
        CHECK([owner validateForDirectory:gRoot error:NULL], "busy dependency writer preserves competing capability");
        [owner invalidate]; CheckLeaseFree();
        CHECK(SetSource(PXProfileDeletionJournalPath(), @"state", @"pending"), "dependency pending deletion seeded");
        before = BatchSnapshot();
        CHECK(!InvokeDependency(manager, mode) && manager.error.code == 27 && selections == gSelections && preparations == gPreparations &&
              caches == gCacheChanges && [before isEqual:BatchSnapshot()], "dependency APIs including fallbacks stop at pending deletion");
        CHECK(ClearDeletionIntent(), "dependency pending deletion cleared"); CheckLeaseFree();
        gDuringResolve = ^{ CheckDependencyLeaseHeld(); };
        gDuringPrepare = ^{
            CheckDependencyLeaseHeld();
            CHECK(![manager refreshCanonicalCellularIdentityForCurrentProfile] && manager.error.code == 12,
                  "dependency preparation reentry fails busy instead of acquiring recursively");
        };
        gCheckDependencyPublication = YES;
        CHECK(InvokeDependency(manager, mode) && !manager.error && [IDs(a)[@"GenerationCounter"] isEqual:((mode == 1 || mode == 2) ? @12 : @13)],
              "dependency success and missing tuple fallbacks share scope without changing counter policy");
        gCheckDependencyPublication = NO; CheckLeaseFree();
        CHECK(Seed(a, baseline, YES), "dependency exception baseline seeded"); before = BatchSnapshot(); caches = gCacheChanges;
        gDuringPrepare = ^{ CheckDependencyLeaseHeld(); [NSException raise:@"fixture" format:@"dependency provider exception"]; };
        BOOL threw = NO;
        @try { (void)InvokeDependency(manager, mode); } @catch (NSException *exception) { (void)exception; threw = YES; }
        CHECK(threw && caches == gCacheChanges && [before isEqual:BatchSnapshot()], "dependency preparation exception preserves sources caches and releases ownership"); CheckLeaseFree();
        __block NSDictionary *competitor = nil;
        gDuringPrepare = ^{
            CHECK(SetSource(PXProfileDeletionJournalPath(), @"state", @"late"), "dependency late journal committed by bypass writer");
            competitor = BatchSnapshot();
        };
        CHECK(!InvokeDependency(manager, mode) && manager.error.code == 27 && caches == gCacheChanges && [competitor isEqual:BatchSnapshot()],
              "dependency late deletion prevents tuple sidecar removal and publication");
        CHECK(ClearDeletionIntent(), "dependency late journal cleared"); CheckLeaseFree();
        for (NSUInteger kind = 0; kind < 3; kind++) {
            NSString *old = Path(a.stringByDeletingLastPathComponent, @"owned-old-dependency");
            __block BOOL moved = NO; competitor = nil;
            gDuringPrepare = ^{
                moved = [NSFileManager.defaultManager moveItemAtPath:a toPath:old error:NULL];
                if (kind == 1) moved = moved && [NSFileManager.defaultManager createDirectoryAtPath:a withIntermediateDirectories:NO attributes:nil error:NULL];
                if (kind == 2) moved = moved && [NSFileManager.defaultManager createSymbolicLinkAtPath:a withDestinationPath:b error:NULL];
                competitor = BatchSnapshot();
            };
            CHECK(!InvokeDependency(manager, mode) && manager.error && moved && caches == gCacheChanges && [competitor isEqual:BatchSnapshot()],
                  "dependency namespace replacement never stages or removes competitor files");
            if (kind != 0) CHECK([NSFileManager.defaultManager removeItemAtPath:a error:NULL], "dependency replacement fixture removed");
            CHECK([NSFileManager.defaultManager moveItemAtPath:old toPath:a error:NULL], "dependency identity restored"); CheckLeaseFree();
        }
        before = BatchSnapshot();
        __block BOOL interrupted = NO;
        gStore.testCheckpoint = ^(NSString *stage) {
            if (!interrupted && [stage isEqual:@"source-written"]) { interrupted = YES; [NSException raise:@"fixture" format:@"owned dependency commit fault"]; }
        };
        CHECK(!InvokeDependency(manager, mode) && manager.error && interrupted && caches == gCacheChanges && [before isEqual:BatchSnapshot()],
              "owned dependency commit fault restores complete tuple sidecars counter and token");
        gStore.testCheckpoint = nil; CheckLeaseFree();
    }
    CHECK(Seed(a, full, YES), "dependency callback baseline seeded");
    gCheckDependencyPublication = YES;
    __block BOOL reentered = NO;
    gDuringDependencyPublication = ^{
        reentered = [manager refreshCanonicalCellularIdentityForCurrentProfile];
        CHECK(reentered, "dependency compatibility callback can acquire fresh scope after release");
    };
    CHECK([manager regenerateDeviceProfileGroup] && reentered, "dependency callback reentry completes without recursive ownership");
    gThrowDependencyPublication = YES; gBuild = @"B2";
    BOOL threw = NO;
    @try { [manager generateIOSVersion]; } @catch (NSException *exception) { (void)exception; threw = YES; }
    CHECK(threw && [IDs(a)[@"IOSBuild"] isEqual:@"B2"], "throwing software publication preserves already committed source");
    gThrowDependencyPublication = NO; gCheckDependencyPublication = NO; CheckLeaseFree();
    CHECK(Seed(a, full, YES), "mutable custom model baseline seeded");
    NSMutableString *input = [@"iPhone16,1" mutableCopy];
    gDuringPrepare = ^{ [input setString:@"iPhone-mutated"]; };
    CHECK([manager setCustomDeviceModel:input] && [IDs(a)[@"DeviceModel"] isEqual:@"iPhone16,1"],
          "custom model detaches mutable caller before DB callbacks and publication"); CheckLeaseFree();
    CHECK([manager setCustomDeviceModel:@"iPad1,1"] && [IDs(a)[@"GenerationCounter"] isEqual:@12] && !IDs(a)[@"IOSBuild"],
          "owned custom model preserves non iPhone validation fallback and counter"); CheckLeaseFree();
    NSUInteger selections = gSelections;
    CHECK(![manager setCustomDeviceModel:@"invalid-model"] && manager.error.code == 2003 && selections == gSelections,
          "invalid custom model keeps validation before target ownership");
    gSelected = nil;
    NSUInteger preparations = gPreparations; NSDictionary *before = BatchSnapshot();
    for (NSUInteger mode = 0; mode < 4; mode++) {
        CHECK(!InvokeDependency(manager, mode) && manager.error && preparations == gPreparations && [before isEqual:BatchSnapshot()],
              "missing dependency selection rejects before provider work"); CheckLeaseFree();
    }
    gSelected = @"a";
}
static void ProbeDashboardStorage(NSDictionary *info) {
    if (!gCheckDashboardPublication) return;
    CheckLeaseFree();
    NSDictionary *persisted = [NSDictionary dictionaryWithContentsOfFile:Path(gExpectedIdentity.stringByDeletingLastPathComponent, @"storage.plist")];
    CHECK([persisted isEqual:info], "dashboard storage cache sees complete committed record after ownership release");
}
static BOOL SeedDashboard(NSString *identity, NSInteger generation) {
    gDashboardStorageModel = nil;
    gDashboardStorage = @{ @"TotalStorage": @"64", @"FreeStorage": @"32", @"FilesystemType": @"old", @"cacheExtra": @"preserved" };
    NSDictionary *ids = @{ @"DeviceModel": @"iPhone15,4", @"RegulatoryModelNumber": @"A2846", @"IOSBuild": @"B1",
        @"GenerationCounter": @(generation), @"keep": @YES, @"SSID": @"dashboard-before" };
    if (!Seed(identity, ids, YES)) return NO;
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx setDictionary:@{ @"value": @"old-name" } atPath:Path(identity, @"device_name.plist") error:error] &&
            [tx setDictionary:@{ @"value": @"old-serial" } atPath:Path(identity, @"serial_number.plist") error:error] &&
            [tx setDictionary:@{ @"diskExtra": @"old-source" } atPath:Path(identity.stringByDeletingLastPathComponent, @"storage.plist") error:error];
    } error:NULL];
}
static NSDictionary *DashboardPreview(void) {
    return @{ @"DeviceModel": @"iPhone15,4", @"DeviceModelName": @"Preview name", @"DeviceName": @"Preview device",
        @"SerialNumber": @"FVF12345678", @"IOSProductType": @"iPhone15,4", @"IOSVersion": @"17.0", @"IOSBuild": @"B1",
        @"Darwin": @"23.0", @"XNU": @"preview-xnu", @"KernelVersion": @"preview-kernel", @"MACAddress": @"02:11:22:33:44:55",
        @"CountryCode": @"us", @"CarrierName": @"Preview carrier" };
}
static void TestDashboardPreview(PXDeviceGroupFixture *manager, NSString *a, NSString *b) {
    gSelected = @"a"; gExpectedIdentity = a; gBuild = @"B1";
    manager.settings = [@{ @"StorageSystem": @YES } mutableCopy];
    NSError *error = nil;
    CHECK(SeedDashboard(a, 7), "dashboard baseline seeded");
    NSDictionary *before = BatchSnapshot(); NSUInteger caches = gCacheChanges, adoptions = gArtifactAdoptions;
    PXPreparedDeviceProfileGroup *custom = [manager prepareCustomDeviceModel:@"iPhone15,4" error:&error];
    CHECK(custom && !error && custom.versionInfo.count == 0 && [before isEqual:BatchSnapshot()] && caches == gCacheChanges && adoptions == gArtifactAdoptions,
          "custom model builder prepares detached replacement without source or cache effects");
    PXProfileLifecycleLease *owner = [PXProfileLifecycleLease acquireInDirectory:gRoot error:NULL];
    NSUInteger selections = gSelections, preparations = gPreparations, notices = gBatchNotifications;
    CHECK(owner && ![manager applyDashboardPreview:DashboardPreview() error:&error] && error.code == 12 && selections == gSelections && preparations == gPreparations &&
          [before isEqual:BatchSnapshot()], "busy dashboard stops before target providers and all candidate writes");
    [owner invalidate]; CheckLeaseFree();
    CHECK(SetSource(PXProfileDeletionJournalPath(), @"state", @"pending"), "dashboard pending intent seeded"); before = BatchSnapshot();
    CHECK(![manager applyDashboardPreview:DashboardPreview() error:&error] && error.code == 27 && selections == gSelections && preparations == gPreparations &&
          [before isEqual:BatchSnapshot()], "pending deletion blocks dashboard without partial setters");
    CHECK(ClearDeletionIntent(), "dashboard pending intent cleared");
    gCheckDashboardPublication = YES; gCheckDependencyPublication = YES;
    __block NSUInteger commits = 0, writes = 0;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"commit-written"]) commits++; if ([phase isEqual:@"source-written"]) writes++; };
    CHECK([manager applyDashboardPreview:DashboardPreview() error:&error] && !error && commits == 1 && [IDs(a)[@"GenerationCounter"] isEqual:@10] &&
          [IDs(a)[@"DeviceModelName"] isEqual:@"Preview name"] && [IDs(a)[@"DeviceName"] isEqual:@"Preview device"] &&
          [IDs(a)[@"IOSBuild"] isEqual:@"B1"] && [IDs(a)[@"WiFiAddress"] isEqual:@"02:11:22:33:44:55"] && !IDs(a)[@"IOSProductType"] && !HasLegacy(a) &&
          caches + 1 == gCacheChanges && adoptions + 1 == gArtifactAdoptions && notices == gBatchNotifications,
          "dashboard model sidecars tuple storage and legacy counter policy commit together once before caches");
    gStore.testCheckpoint = nil;
    NSDictionary *storage = [NSDictionary dictionaryWithContentsOfFile:Path(a.stringByDeletingLastPathComponent, @"storage.plist")];
    CHECK([storage[@"TotalStorage"] isEqual:@"128"] && [storage[@"cacheExtra"] isEqual:@"preserved"] && !storage[@"diskExtra"] &&
          [storage isEqual:gDashboardStorage] && [gDashboardStorageModel isEqual:@"iPhone15,4"], "dashboard storage keeps legacy cache authority and unrelated cached fields");
    NSUInteger totalWrites = writes; CHECK(totalWrites >= 6, "dashboard complete transaction includes all sidecar and storage changes");
    gCheckDashboardPublication = NO; gCheckDependencyPublication = NO;
    for (NSUInteger fault = 1; fault <= totalWrites; fault++) {
        CHECK(SeedDashboard(a, 7), "dashboard rollback baseline seeded"); before = BatchSnapshot(); caches = gCacheChanges; adoptions = gArtifactAdoptions;
        __block NSUInteger step = 0;
        gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"] && ++step == fault) [NSException raise:@"fixture" format:@"dashboard source fault"]; };
        CHECK(![manager applyDashboardPreview:DashboardPreview() error:&error] && error && step == fault && [before isEqual:BatchSnapshot()] &&
              caches == gCacheChanges && adoptions == gArtifactAdoptions && notices == gBatchNotifications,
              "dashboard fault at each written source restores hardware tuple sidecars storage counter and token");
        gStore.testCheckpoint = nil; CheckLeaseFree();
    }
    CHECK(SeedDashboard(a, 7), "dashboard preparation failure baseline seeded"); before = BatchSnapshot(); caches = gCacheChanges; adoptions = gArtifactAdoptions;
    gBadDashboardStorage = YES;
    CHECK(![manager applyDashboardPreview:DashboardPreview() error:&error] && error && [before isEqual:BatchSnapshot()], "dashboard storage preparation failure writes no source");
    gBadDashboardStorage = NO; gNoHardware = YES;
    CHECK(![manager applyDashboardPreview:DashboardPreview() error:&error] && error && [before isEqual:BatchSnapshot()] && caches == gCacheChanges && adoptions == gArtifactAdoptions,
          "dashboard model preparation failure has no partial model name serial or storage write");
    gNoHardware = NO;
    NSDictionary *partial = @{ @"IOSVersion": @"17.0", @"DeviceModel": @"iPhone15,4" };
    gFailDashboardTuple = YES;
    CHECK(![manager applyDashboardPreview:partial error:&error] && error && [before isEqual:BatchSnapshot()], "dashboard unavailable tuple resolution preserves every source");
    gFailDashboardTuple = NO; gIncompleteDashboardTuple = YES;
    CHECK(![manager applyDashboardPreview:partial error:&error] && error && [before isEqual:BatchSnapshot()], "dashboard malformed DB tuple never publishes a partial software identity");
    gIncompleteDashboardTuple = NO;
    CHECK([manager applyDashboardPreview:partial error:&error] && !error && [IDs(a)[@"IOSBuild"] isEqual:@"B1"] && [IDs(a)[@"KernelVersion"] isEqual:@"fixture-kernel"],
          "dashboard resolves complete tuple for requested model and version");
    CHECK(SeedDashboard(a, 7), "dashboard immutable intent baseline seeded");
    NSMutableString *name = [@"Frozen name" mutableCopy]; NSMutableDictionary *preview = [DashboardPreview() mutableCopy]; preview[@"DeviceName"] = name;
    NSDictionary *otherBefore = Snapshot(b)[@"files"]; gSelections = 0;
    gDuringPrepare = ^{
        CheckDependencyLeaseHeld(); [name setString:@"changed"]; preview[@"SerialNumber"] = @"changed"; gSelected = @"b";
        CHECK(SetSource(Path(a, @"device_ids.plist"), @"SSID", @"disjoint-winner"), "dashboard bypass disjoint update committed");
        NSError *busy = nil;
        CHECK(![manager applyDashboardPreview:DashboardPreview() error:&busy] && busy.code == 12, "dashboard provider reentry fails busy without recursive setters");
    };
    CHECK([manager applyDashboardPreview:preview error:&error] && !error && gSelections == 1 && [IDs(a)[@"DeviceName"] isEqual:@"Frozen name"] &&
          [IDs(a)[@"SerialNumber"] isEqual:@"FVF12345678"] && [IDs(a)[@"SSID"] isEqual:@"disjoint-winner"] && [otherBefore isEqual:Snapshot(b)[@"files"]],
          "dashboard freezes mutable intent merges unrelated updates and keeps one captured target");
    gSelected = @"a";
    CHECK(SeedDashboard(a, 7), "dashboard provider exception baseline seeded"); before = BatchSnapshot(); caches = gCacheChanges; adoptions = gArtifactAdoptions;
    gDuringPrepare = ^{ CheckDependencyLeaseHeld(); [NSException raise:@"fixture" format:@"dashboard provider exception"]; };
    BOOL threw = NO;
    @try { [manager applyDashboardPreview:DashboardPreview() error:&error]; } @catch (NSException *exception) { (void)exception; threw = YES; }
    CHECK(threw && [before isEqual:BatchSnapshot()] && caches == gCacheChanges && adoptions == gArtifactAdoptions, "dashboard provider exception releases ownership without mutation"); CheckLeaseFree();
    __block NSDictionary *competitor = nil;
    gDuringPrepare = ^{ CHECK(SetSource(PXProfileDeletionJournalPath(), @"state", @"late"), "dashboard late deletion intent seeded"); competitor = BatchSnapshot(); };
    CHECK(![manager applyDashboardPreview:DashboardPreview() error:&error] && error.code == 27 && [competitor isEqual:BatchSnapshot()], "late deletion rejects entire dashboard candidate before staging");
    CHECK(ClearDeletionIntent(), "dashboard late intent cleared"); CheckLeaseFree();
    for (NSUInteger kind = 0; kind < 3; kind++) {
        NSString *old = Path(a.stringByDeletingLastPathComponent, @"old-dashboard-identity"); __block BOOL moved = NO;
        gDuringPrepare = ^{
            moved = [NSFileManager.defaultManager moveItemAtPath:a toPath:old error:NULL];
            if (kind == 1) moved = moved && [NSFileManager.defaultManager createDirectoryAtPath:a withIntermediateDirectories:NO attributes:nil error:NULL];
            if (kind == 2) moved = moved && [NSFileManager.defaultManager createSymbolicLinkAtPath:a withDestinationPath:b error:NULL];
            competitor = BatchSnapshot();
        };
        CHECK(![manager applyDashboardPreview:DashboardPreview() error:&error] && error && moved && [competitor isEqual:BatchSnapshot()] && caches == gCacheChanges && adoptions == gArtifactAdoptions,
              "dashboard rejects missing replaced or symlink identity without source or cache publication");
        if (kind != 0) CHECK([NSFileManager.defaultManager removeItemAtPath:a error:NULL], "dashboard replacement fixture removed");
        CHECK([NSFileManager.defaultManager moveItemAtPath:old toPath:a error:NULL], "dashboard identity restored"); CheckLeaseFree();
    }
    NSDictionary *softwareOnly = @{ @"IOSVersion": @"17.0" };
    gDuringPrepare = ^{ CHECK(SetSource(Path(a, @"device_ids.plist"), @"DeviceModel", @"iPhone16,1"), "dashboard model dependency drift seeded"); competitor = BatchSnapshot(); };
    CHECK(![manager applyDashboardPreview:softwareOnly error:&error] && error && [competitor isEqual:BatchSnapshot()], "dashboard software resolution rejects captured model drift without overwriting competitor");
    CHECK(SeedDashboard(a, NSIntegerMax - 2), "dashboard exhausted counter seeded"); before = BatchSnapshot();
    CHECK(![manager applyDashboardPreview:DashboardPreview() error:&error] && error && [before isEqual:BatchSnapshot()], "dashboard counter exhaustion rolls back all intermediate increments");
    CHECK(SeedDashboard(a, 7), "dashboard invalid input baseline seeded"); before = BatchSnapshot();
    NSDictionary *shortSerial = @{ @"DeviceName": @"valid-name", @"SerialNumber": @"short" };
    CHECK(![manager applyDashboardPreview:shortSerial error:&error] && error.code == 7003 && [before isEqual:BatchSnapshot()], "dashboard rejects short serial rather than writing unpaired invalid scalar");
    selections = gSelections;
    CHECK(![manager applyDashboardPreview:(id)@[] error:&error] && error && ![manager applyDashboardPreview:@{} error:&error] && error && selections == gSelections,
          "dashboard empty or non dictionary input fails before ownership and lookup");
    NSArray *scalarCases = @[
        @{ @"preview": @{ @"DeviceName": @"only-name" }, @"increment": @2 },
        @{ @"preview": @{ @"SerialNumber": @"FVF12345678" }, @"increment": @2 },
        @{ @"preview": @{ @"DeviceName": @"both", @"SerialNumber": @"FVF12345678" }, @"increment": @3 },
        @{ @"preview": @{ @"CountryCode": @"vn" }, @"increment": @1 },
        @{ @"preview": @{ @"MACAddress": @42 }, @"increment": @1 }
    ];
    for (NSDictionary *row in scalarCases) {
        CHECK(SeedDashboard(a, 7), "dashboard scalar-only case seeded");
        NSData *storageBefore = [NSData dataWithContentsOfFile:Path(a.stringByDeletingLastPathComponent, @"storage.plist")];
        adoptions = gArtifactAdoptions;
        NSUInteger storageSelections = gDashboardStorageSelections;
        NSInteger expectedGeneration = 7 + [row[@"increment"] integerValue];
        CHECK([manager applyDashboardPreview:row[@"preview"] error:&error] && !error && [IDs(a)[@"GenerationCounter"] integerValue] == expectedGeneration &&
              adoptions == gArtifactAdoptions && storageSelections == gDashboardStorageSelections && [storageBefore isEqual:[NSData dataWithContentsOfFile:Path(a.stringByDeletingLastPathComponent, @"storage.plist")]],
              "dashboard scalar-only and metadata cases preserve counters without preparing or saving storage");
    }
    CHECK(SeedDashboard(a, 7), "dashboard changed model storage case seeded");
    NSMutableDictionary *changedModel = [DashboardPreview() mutableCopy];
    changedModel[@"DeviceModel"] = @"iPhone16,1"; changedModel[@"IOSProductType"] = @"iPhone16,1";
    NSUInteger storageSelections = gDashboardStorageSelections;
    CHECK([manager applyDashboardPreview:changedModel error:&error] && !error && [IDs(a)[@"DeviceModel"] isEqual:@"iPhone16,1"] &&
          [gDashboardStorageModel isEqual:@"iPhone16,1"] && storageSelections + 1 == gDashboardStorageSelections &&
          [[NSDictionary dictionaryWithContentsOfFile:Path(a.stringByDeletingLastPathComponent, @"storage.plist")] isEqual:gDashboardStorage],
          "dashboard storage selection uses final preview model instead of previous persisted model");
    CHECK(SeedDashboard(a, 7), "dashboard software-only marker seeded");
    NSDictionary *softwareMarker = @{ @"IOSVersion": @"17.0", @"IOSBuild": @"B1", @"Darwin": @"23.0", @"XNU": @"xnu", @"KernelVersion": @"kernel", @"IOSProductType": @"iPhone16,1" };
    storageSelections = gDashboardStorageSelections;
    CHECK([manager applyDashboardPreview:softwareMarker error:&error] && !error && [IDs(a)[@"DeviceModel"] isEqual:@"iPhone16,1"] && !IDs(a)[@"IOSProductType"] &&
          [gDashboardStorageModel isEqual:@"iPhone16,1"] && storageSelections + 1 == gDashboardStorageSelections,
          "dashboard software-only marker restores prepared model instead of transient generated model");
    CHECK(SeedDashboard(a, 7), "dashboard disabled storage case seeded");
    manager.settings[@"StorageSystem"] = @NO;
    NSData *unchangedStorage = [NSData dataWithContentsOfFile:Path(a.stringByDeletingLastPathComponent, @"storage.plist")]; adoptions = gArtifactAdoptions;
    storageSelections = gDashboardStorageSelections;
    CHECK([manager applyDashboardPreview:DashboardPreview() error:&error] && !error && adoptions == gArtifactAdoptions && storageSelections == gDashboardStorageSelections &&
          [unchangedStorage isEqual:[NSData dataWithContentsOfFile:Path(a.stringByDeletingLastPathComponent, @"storage.plist")]], "dashboard honors disabled storage while applying model tuple");
    manager.settings[@"StorageSystem"] = @YES;
    CHECK(SeedDashboard(a, 7), "dashboard callback exception baseline seeded");
    gCheckDependencyPublication = YES; gThrowDependencyPublication = YES; gCheckDashboardPublication = YES;
    CHECK([manager applyDashboardPreview:DashboardPreview() error:&error] && !error && [IDs(a)[@"GenerationCounter"] isEqual:@10],
          "dashboard committed source remains success after compatibility callback exception");
    gCheckDependencyPublication = NO; gThrowDependencyPublication = NO; gCheckDashboardPublication = NO; CheckLeaseFree();
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

static BOOL SelectExpectedSource(NSString *profileID, NSString *revision) {
    return PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        NSDictionary *info = @{ @"ProfileId": profileID, @"SelectionRevision": revision };
        return PXStageRuntimeProfileSelection(tx, info, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), error);
    }, NULL);
}
static BOOL ApplyExpectedOwner(PXDeviceGroupFixture *manager, BOOL preview, NSString *profileID, NSError **error) {
    return preview ? [manager applyDashboardPreview:DashboardPreview() expectedActiveProfileID:profileID error:error] :
        [manager regenerateAllEnabledIdentifiersForExpectedActiveProfileID:profileID error:error];
}
static void TestExpectedActiveOwners(PXDeviceGroupFixture *manager, NSString *a, NSString *b) {
    gSelected = @"a"; gExpectedIdentity = a; gBuild = @"B1"; gFailDB = gNoHardware = gNoFirmware = NO;
    gUnknownCellular = gDisabledCellular = gNoCDMA = gNoTACs = gNoMEIDPrefixes = NO;
    gFailSerial = gBadDashboardStorage = gFailDashboardTuple = gIncompleteDashboardTuple = NO;
    gCheckDashboardPublication = gCheckDependencyPublication = gThrowDependencyPublication = NO;
    gDuringPublication = gDuringDependencyPublication = nil; gThrowBatteryPublication = NO;
    manager.settings = [@{ @"DeviceModel": @YES, @"StorageSystem": @YES } mutableCopy]; manager.scopedApps = [NSMutableDictionary dictionary];
    CHECK(SeedDashboard(a, 3) && SeedDashboard(b, 8) && SelectExpectedSource(@"b", @"admission-newer"), "expected owners seed independent targets and newer selection");
    for (NSUInteger preview = 0; preview < 2; preview++) {
        NSDictionary *before = BatchSnapshot(); NSUInteger resolve = gSelections, prepare = gPreparations, migrate = gMigrations;
        NSUInteger caches = gCacheChanges, notices = gBatchNotifications, adoptions = gArtifactAdoptions; NSError *error = nil;
        CHECK(!ApplyExpectedOwner(manager, preview, @"a", &error) && error.code == 20 && resolve == gSelections && prepare == gPreparations && migrate == gMigrations &&
            caches == gCacheChanges && notices == gBatchNotifications && adoptions == gArtifactAdoptions && [before isEqual:BatchSnapshot()],
            "expected active mismatch rejects before target lookup migration providers writes or caches");
        CheckLeaseFree();
        PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:gRoot error:NULL];
        CHECK(lease && !ApplyExpectedOwner(manager, preview, @"a", &error) && error.code == 12 && [before isEqual:BatchSnapshot()], "expected owners reject busy lifecycle before resolving target"); [lease invalidate];
        CHECK(!ApplyExpectedOwner(manager, preview, @"../a", &error) && error.code == 10 && [before isEqual:BatchSnapshot()], "expected owners reject invalid IDs without selection repair");
        CHECK(!ApplyExpectedOwner(manager, preview, @"../a", NULL), "expected owners support null error output on failure");
    }
    for (NSUInteger missing = 0; missing < 2; missing++) {
        CHECK(PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
            if (missing) return [tx removeDictionaryAtPath:PXCurrentProfileInfoPath() error:error] && [tx removeDictionaryAtPath:PXLegacyActiveProfileInfoPath() error:error];
            return [tx setDictionary:@{ @"ProfileId": @7 } atPath:PXCurrentProfileInfoPath() error:error];
        }, NULL), "expected owner fixture seeds invalid or absent selection");
        NSDictionary *before = BatchSnapshot(); NSUInteger migrations = gMigrations, resolves = gSelections;
        for (NSUInteger preview = 0; preview < 2; preview++) {
            NSError *error = nil;
            CHECK(!ApplyExpectedOwner(manager, preview, @"a", &error) && error.code == 20 && migrations == gMigrations && resolves == gSelections && [before isEqual:BatchSnapshot()],
                "expected owners preserve invalid or absent selection instead of defaulting to another profile");
        }
    }
    for (NSUInteger preview = 0; preview < 2; preview++) {
        CHECK(SelectExpectedSource(@"a", @"matching"), "expected target selected independently of stale resolver cache");
        gSelected = @"b"; NSDictionary *other = Snapshot(b); NSUInteger resolve = gSelections; NSError *error = nil;
        NSMutableString *expectedID = [@"a" mutableCopy];
        gDuringPrepare = ^{ [expectedID setString:@"b"]; };
        BOOL committed = ApplyExpectedOwner(manager, preview, expectedID, &error);
        NSDictionary *after = Snapshot(b);
        // A committed A operation advances the store-wide marker returned by
        // capture. Only B's file bytes are expected to remain unchanged.
        CHECK(committed && !error && resolve == gSelections && [other[@"files"] isEqual:after[@"files"]] && [expectedID isEqual:@"b"],
            "expected owners freeze caller ID and never resolve the stale current profile");
        CHECK(committed && [other[@"sourceCommitID"] length] && [after[@"sourceCommitID"] length] && ![other[@"sourceCommitID"] isEqual:after[@"sourceCommitID"]],
            "expected owner A commit advances the global marker while preserving inactive B file bytes");
        CheckLeaseFree();
    }
    gSelected = @"a";
    for (NSUInteger preview = 0; preview < 2; preview++) {
        CHECK(SelectExpectedSource(@"a", @"fault-rollback"), "expected selection before fault fixture");
        NSDictionary *before = BatchSnapshot(); NSUInteger caches = gCacheChanges, notices = gBatchNotifications, adoptions = gArtifactAdoptions;
        __block NSUInteger writes = 0;
        gStore.testCheckpoint = ^(NSString *stage) { if ([stage isEqual:@"source-written"] && ++writes == 2) [NSException raise:@"fixture.expected" format:@"expected target commit fault"]; };
        NSError *failure = nil; BOOL committed = ApplyExpectedOwner(manager, preview, @"a", &failure); gStore.testCheckpoint = nil;
        CHECK(!committed && failure && writes == 2 && [before isEqual:BatchSnapshot()] && caches == gCacheChanges && notices == gBatchNotifications && adoptions == gArtifactAdoptions,
            "expected owner source fault rolls back artifacts without cache or notification effects"); CheckLeaseFree();
    }
    gSelected = @"a";
    for (NSUInteger preview = 0; preview < 2; preview++) for (NSUInteger drift = 0; drift < 4; drift++) {
        CHECK(SelectExpectedSource(@"a", @"before-preparation"), "expected selection receipt seeded");
        NSUInteger caches = gCacheChanges, notices = gBatchNotifications, adoptions = gArtifactAdoptions;
        __block NSDictionary *competitor = nil;
        gDuringPrepare = ^{
            NSError *busy = nil; PXProfileLifecycleLease *probe = [PXProfileLifecycleLease acquireInDirectory:gRoot error:&busy];
            CHECK(!probe && busy.code == 12, "expected owner retains lifecycle through provider preparation"); [probe invalidate];
            if (drift == 0) CHECK(SelectExpectedSource(@"b", @"changed-target"), "raw target change seeded under source gate");
            else if (drift == 1) CHECK(SelectExpectedSource(@"a", @"changed-same-id"), "same ID new selection revision seeded");
            else if (drift == 2) { CHECK(SelectExpectedSource(@"b", @"away") && SelectExpectedSource(@"a", @"back-with-new-revision"), "selection ABA with new revision seeded"); }
            else CHECK(SetSource(PXLegacyActiveProfileInfoPath(), @"SelectionRevision", @"legacy-only-change"), "legacy-only selection drift seeded");
            competitor = BatchSnapshot();
        };
        NSError *error = nil;
        CHECK(!ApplyExpectedOwner(manager, preview, @"a", &error) && error.code == 20 && competitor && [competitor isEqual:BatchSnapshot()] && caches == gCacheChanges && notices == gBatchNotifications && adoptions == gArtifactAdoptions,
            "expected selection receipt drift aborts complete generation or preview before source commit and publication");
        CheckLeaseFree();
    }
    CHECK(SelectExpectedSource(@"a", @"legacy-fallback") && PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx removeDictionaryAtPath:PXCurrentProfileInfoPath() error:error];
    }, NULL), "expected owner fixture removes canonical selection for legacy fallback");
    NSError *error = nil;
    CHECK([manager applyDashboardPreview:DashboardPreview() expectedActiveProfileID:@"a" error:&error] && !error && ![NSFileManager.defaultManager fileExistsAtPath:PXCurrentProfileInfoPath()],
        "expected owners preserve legacy fallback without creating or repairing canonical selection");
    CHECK(SelectExpectedSource(@"a", @"restored"), "expected owner fixture restores selection");
}

@interface PXPreviewPublicationFixture : PXDeviceGroupFixture
@property (nonatomic, copy) dispatch_block_t beforePublicationCheck;
@property (nonatomic) NSUInteger publicationChecks;
@end
@implementation PXPreviewPublicationFixture
- (BOOL)dashboardPreviewPublicationIsCurrentAtIdentity:(NSString *)identity model:(NSString *)model storage:(NSDictionary *)storage {
    self.publicationChecks++;
    dispatch_block_t callback = self.beforePublicationCheck; self.beforePublicationCheck = nil;
    if (callback) callback();
    return [super dashboardPreviewPublicationIsCurrentAtIdentity:identity model:model storage:storage];
}
@end
static void TestExpectedPreviewPublication(NSString *a, NSString *b) {
    gExpectedIdentity = a; gSelected = @"a"; gBuild = @"B1";
    gFailDB = gNoHardware = gNoFirmware = NO; gDuringPrepare = gDuringResolve = nil;
    gBadDashboardStorage = gFailDashboardTuple = gIncompleteDashboardTuple = NO;
    gCheckDashboardPublication = gCheckDependencyPublication = gThrowDependencyPublication = NO;
    gDuringPublication = gDuringDependencyPublication = nil;
    for (NSUInteger drift = 0; drift < 5; drift++) {
        CHECK(SeedDashboard(a, 7) && SeedDashboard(b, 8) && SelectExpectedSource(@"a", @"publication-before"), "expected preview publication baseline seeded");
        PXPreviewPublicationFixture *manager = [PXPreviewPublicationFixture new]; manager.settings = [@{ @"StorageSystem": @YES } mutableCopy];
        NSUInteger caches = gCacheChanges, adoptions = gArtifactAdoptions;
        __block NSDictionary *afterCommit = nil;
        manager.beforePublicationCheck = ^{
            CheckLeaseFree();
            if (drift == 0) CHECK(SelectExpectedSource(@"b", @"after-commit"), "publication observes newer active profile");
            else if (drift == 1) CHECK(SelectExpectedSource(@"a", @"newer-same-id"), "publication observes newer selection revision");
            else if (drift == 2) CHECK(SetSource(Path(a, @"device_ids.plist"), @"DeviceModel", @"iPhone16,1"), "publication observes newer model field");
            else if (drift == 3) CHECK(SetSource(Path(a.stringByDeletingLastPathComponent, @"storage.plist"), @"TotalStorage", @"512"), "publication observes newer storage source");
            else CHECK(PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
                return [tx removeDictionaryAtPath:PXCurrentProfileInfoPath() error:error] && [tx removeDictionaryAtPath:PXLegacyActiveProfileInfoPath() error:error];
            }, NULL), "publication observes missing selection");
            afterCommit = BatchSnapshot();
        };
        NSError *error = nil; BOOL applied = [manager applyDashboardPreview:DashboardPreview() expectedActiveProfileID:@"a" error:&error];
        CHECK(applied && !error && !manager.error && manager.publicationChecks == 2 && [afterCommit isEqual:BatchSnapshot()] && gArtifactAdoptions == adoptions + (drift == 1 ? 1 : 0) && gCacheChanges == caches + (drift == 1 || drift == 3 ? 1 : 0),
            "expected preview publication suppression preserves source success and released ownership");
        if (drift == 3) CHECK(gCacheChanges == caches + 1 && adoptions == gArtifactAdoptions, "expected preview publishes matching model but skips newer storage values");
        else if (drift == 1) CHECK(gCacheChanges == caches + 1 && gArtifactAdoptions == adoptions + 1, "same-profile metadata changes preserve matching preview cache adoption");
        else CHECK(caches == gCacheChanges && adoptions == gArtifactAdoptions, "expected preview skips stale publication after post-commit selection or model changes");
        CheckLeaseFree();
    }
    for (NSUInteger mode = 0; mode < 3; mode++) {
        CHECK(SeedDashboard(a, 7) && SeedDashboard(b, 8) && SelectExpectedSource(@"a", @"callback-before"), "model callback publication baseline seeded");
        PXPreviewPublicationFixture *manager = [PXPreviewPublicationFixture new]; manager.settings = [@{ @"StorageSystem": @YES } mutableCopy];
        NSDictionary *newerStorage = @{ @"TotalStorage": @"512", @"FreeStorage": @"300", @"FilesystemType": @"newer" };
        NSUInteger adoptions = gArtifactAdoptions;
        gCheckDependencyPublication = YES; gThrowDependencyPublication = mode == 2;
        gDuringDependencyPublication = ^{
            CheckLeaseFree();
            NSString *target = mode == 1 ? a : b;
            if (mode != 1) CHECK(SelectExpectedSource(@"b", @"model-callback"), "model callback changes active target");
            else CHECK(SetSource(Path(a, @"device_ids.plist"), @"DeviceModel", @"iPhone16,1"), "model callback commits a newer same-profile model");
            CHECK(PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
                return [tx setDictionary:newerStorage atPath:Path(target.stringByDeletingLastPathComponent, @"storage.plist") error:error];
            }, NULL), "model callback commits newer storage source");
            [[StorageManager sharedManager] adoptCommittedStorageInfo:newerStorage];
        };
        NSError *error = nil;
        CHECK([manager applyDashboardPreview:DashboardPreview() expectedActiveProfileID:@"a" error:&error] && !error && adoptions + 1 == gArtifactAdoptions && [gDashboardStorage isEqual:newerStorage] && manager.publicationChecks == 2,
            "preview model callback may publish newer target without stale storage overwrite");
        gCheckDependencyPublication = gThrowDependencyPublication = NO; gDuringDependencyPublication = nil; CheckLeaseFree();
    }
    CHECK(SeedDashboard(a, 7) && SelectExpectedSource(@"a", @"publication-matching"), "matching preview publication baseline seeded");
    PXPreviewPublicationFixture *manager = [PXPreviewPublicationFixture new]; manager.settings = [@{ @"StorageSystem": @YES } mutableCopy];
    NSUInteger caches = gCacheChanges, adoptions = gArtifactAdoptions; NSError *error = nil;
    CHECK([manager applyDashboardPreview:DashboardPreview() expectedActiveProfileID:@"a" error:&error] && !error && manager.publicationChecks == 2 && caches + 1 == gCacheChanges && adoptions + 1 == gArtifactAdoptions,
        "matching expected preview still adopts model and storage once");
    manager.beforePublicationCheck = ^{ CHECK(NO, "generic preview must not read targeted publication checkpoints"); };
    NSUInteger checks = manager.publicationChecks;
    CHECK([manager applyDashboardPreview:DashboardPreview() error:&error] && !error && manager.publicationChecks == checks && manager.beforePublicationCheck,
        "generic preview preserves legacy cache publication without checkpoint reads");
    manager.beforePublicationCheck = nil; CheckLeaseFree();
}

@interface PXGenerationPublicationFixture : PXDeviceGroupFixture
@property (nonatomic, copy) void (^beforePublicationCheck)(PXCommittedRuntimeGeneration *, NSArray *, NSArray *);
@property (nonatomic) NSUInteger publicationChecks;
@end
@implementation PXGenerationPublicationFixture
- (BOOL)runtimeGenerationPublicationIsCurrent:(PXCommittedRuntimeGeneration *)generation identifierKeys:(NSArray *)keys artifactPaths:(NSArray *)paths {
    self.publicationChecks++;
    void (^callback)(PXCommittedRuntimeGeneration *, NSArray *, NSArray *) = self.beforePublicationCheck;
    self.beforePublicationCheck = nil;
    if (callback) callback(generation, keys, paths);
    return [super runtimeGenerationPublicationIsCurrent:generation identifierKeys:keys artifactPaths:paths];
}
@end
static PXGenerationPublicationFixture *GenerationPublicationFixture(NSString *a, NSString *b) {
    gExpectedIdentity = a; gSelected = @"a"; gBuild = @"B1";
    gFailDB = gNoHardware = gNoFirmware = gUnknownCellular = gDisabledCellular = NO;
    gFailSerial = gThrowBatteryPublication = NO;
    gCheckDependencyPublication = gThrowDependencyPublication = gCheckDashboardPublication = NO;
    gDuringPrepare = gDuringResolve = gDuringPublication = gDuringDependencyPublication = nil;
    gDuringScalarPublication = gDuringBatteryAdoption = nil;
    CHECK(SeedDashboard(a, 7) && SeedDashboard(b, 8) && SelectExpectedSource(@"a", @"generation-before") &&
          SetSource(Path(a, @"battery_info.plist"), @"LowPowerMode", @YES), "expected generation publication bases seeded");
    PXGenerationPublicationFixture *manager = [PXGenerationPublicationFixture new];
    manager.settings = [@{ @"DeviceModel": @YES, @"IDFA": @YES, @"IDFV": @YES, @"StorageSystem": @YES,
        @"BootTime": @YES, @"Battery": @YES } mutableCopy];
    return manager;
}
static void TestExpectedGenerationPublication(NSString *a, NSString *b) {
    for (NSUInteger drift = 0; drift < 4; drift++) {
        PXGenerationPublicationFixture *manager = GenerationPublicationFixture(a, b);
        NSUInteger caches = gCacheChanges, adoptions = gArtifactAdoptions, battery = gBatteryNotifications, notices = gBatchNotifications;
        __block NSDictionary *afterCommit = nil;
        manager.beforePublicationCheck = ^(PXCommittedRuntimeGeneration *generation, NSArray *keys, NSArray *paths) {
            (void)generation; (void)keys; (void)paths; CheckLeaseFree();
            if (drift == 0) CHECK(SelectExpectedSource(@"b", @"generation-after"), "generation publication observes post-commit handoff");
            else if (drift == 1) CHECK(PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
                return [tx removeDictionaryAtPath:PXCurrentProfileInfoPath() error:error] && [tx removeDictionaryAtPath:PXLegacyActiveProfileInfoPath() error:error];
            }, NULL), "generation publication observes missing authoritative selection");
            else if (drift == 2) CHECK(SelectExpectedSource(@"a", @"metadata-only"), "generation publication observes same-ID metadata change");
            else CHECK(SetSource(Path(a, @"device_ids.plist"), @"Unrelated", @"newer"), "generation publication observes unrelated ID merge");
            afterCommit = BatchSnapshot();
        };
        NSError *error = nil;
        CHECK([manager regenerateAllEnabledIdentifiersForExpectedActiveProfileID:@"a" error:&error] && !error && !manager.error &&
              [afterCommit isEqual:BatchSnapshot()] && gBatchNotifications == notices + 1 &&
              gCacheChanges == caches + (drift < 2 ? 0 : 4) && gArtifactAdoptions == adoptions + (drift < 2 ? 0 : 4) &&
              gBatteryNotifications == battery + (drift < 2 ? 0 : 1),
              "expected generation checks authoritative post-commit selection without negating source success or matching metadata merges");
        CheckLeaseFree();
    }
    // Field and sidecar drift are independent: do not reject unaffected groups
    // merely because device_ids carries some other writer's newer fields.
    NSArray *cases = @[
        @[@"device_ids.plist", @"IDFA", @"newer-scalar", @3, @4, @1],
        @[PXRuntimeIdentifierSidecar(@"IDFA"), @"value", @"newer-sidecar", @3, @4, @1],
        @[PXRuntimeIdentifierSidecar(@"IDFV"), NSNull.null, NSNull.null, @3, @4, @1],
        @[@"device_ids.plist", @"SSID", @"newer-wifi", @4, @3, @1],
        @[@"wifi_info.plist", @"ssid", @"newer-wifi", @4, @3, @1],
        @[@"storage.plist", @"TotalStorage", @"512", @4, @3, @1],
        @[@"device_ids.plist", @"SystemUptime", @"newer-uptime", @4, @3, @1],
        @[@"boot_time.plist", @"value", @"newer-boot", @4, @3, @1],
        @[@"device_ids.plist", @"BatteryLevel", @0.11, @4, @3, @0],
        @[@"battery_info.plist", @"BatteryLevel", @0.11, @4, @3, @0],
        @[@"device_ids.plist", @"IOSBuild", @"B2", @3, @4, @1],
        @[@"device_ids.plist", @"DeviceModel", @"iPhone16,1", @2, @3, @1]
    ];
    for (NSArray *entry in cases) {
        PXGenerationPublicationFixture *manager = GenerationPublicationFixture(a, b);
        NSUInteger caches = gCacheChanges, adoptions = gArtifactAdoptions, battery = gBatteryNotifications;
        __block NSDictionary *newer = nil;
        manager.beforePublicationCheck = ^(PXCommittedRuntimeGeneration *generation, NSArray *keys, NSArray *paths) {
            (void)generation; (void)keys; (void)paths; CheckLeaseFree();
            NSString *root = [entry[0] isEqual:@"storage.plist"] ? a.stringByDeletingLastPathComponent : a;
            if (entry[1] == NSNull.null) CHECK(PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
                return [tx removeDictionaryAtPath:Path(root, entry[0]) error:error];
            }, NULL), "generation callback sidecar removed after commit");
            else CHECK(SetSource(Path(root, entry[0]), entry[1], entry[2]), "newer generation callback input committed");
            newer = BatchSnapshot();
        };
        NSError *error = nil;
        CHECK([manager regenerateAllEnabledIdentifiersForExpectedActiveProfileID:@"a" error:&error] && !error &&
              [newer isEqual:BatchSnapshot()] && gCacheChanges == caches + [entry[3] unsignedIntegerValue] &&
              gArtifactAdoptions == adoptions + [entry[4] unsignedIntegerValue] && gBatteryNotifications == battery + [entry[5] unsignedIntegerValue],
              "generation field and sidecar checkpoints skip only stale callback inputs");
    }
    for (NSUInteger mode = 0; mode < 3; mode++) {
        PXGenerationPublicationFixture *manager = GenerationPublicationFixture(a, b);
        NSUInteger caches = gCacheChanges, adoptions = gArtifactAdoptions, battery = gBatteryNotifications;
        gCheckDependencyPublication = YES; gThrowDependencyPublication = mode == 2;
        gDuringDependencyPublication = ^{
            CheckLeaseFree();
            if (mode == 1) CHECK(SetSource(Path(a, @"device_ids.plist"), @"DeviceModel", @"iPhone16,1"), "software callback commits newer same-profile hardware");
            else CHECK(SelectExpectedSource(@"b", @"software-callback"), "software callback selects newer target");
        };
        NSError *error = nil;
        CHECK([manager regenerateAllEnabledIdentifiersForExpectedActiveProfileID:@"a" error:&error] && !error &&
              gCacheChanges == caches + (mode == 1 ? 3 : 1) && gArtifactAdoptions == adoptions + (mode == 1 ? 3 : 0) &&
              gBatteryNotifications == battery + (mode == 1 ? 1 : 0),
              "generation rechecks between software and model callbacks including throwing reentry");
        gCheckDependencyPublication = gThrowDependencyPublication = NO;
    }
    for (NSUInteger mode = 0; mode < 3; mode++) {
        PXGenerationPublicationFixture *manager = GenerationPublicationFixture(a, b);
        NSUInteger caches = gCacheChanges, adoptions = gArtifactAdoptions, battery = gBatteryNotifications;
        if (mode == 0) gDuringScalarPublication = ^{
            CheckLeaseFree();
            CHECK(SetSource(Path(a, @"device_ids.plist"), @"IDFA", @"newer-idfa") && SetSource(Path(a, @"device_ids.plist"), @"IDFV", @"newer-idfv"), "scalar callback changes remaining scalar inputs");
        };
        else gDuringBatteryAdoption = ^{
            CheckLeaseFree();
            if (mode == 1) CHECK(SelectExpectedSource(@"b", @"battery-callback"), "battery adoption changes authoritative target");
            else CHECK(SetSource(Path(a, @"battery_info.plist"), @"BatteryLevel", @0.11), "battery adoption changes its source packet");
        };
        NSError *error = nil;
        CHECK([manager regenerateAllEnabledIdentifiersForExpectedActiveProfileID:@"a" error:&error] && !error &&
              gCacheChanges == caches + (mode == 0 ? 3 : 4) && gArtifactAdoptions == adoptions + 4 &&
              gBatteryNotifications == battery + (mode == 0 ? 1 : 0),
              "generation rechecks each scalar and battery publication after reentrant adoption");
        CheckLeaseFree();
    }
    PXGenerationPublicationFixture *manager = GenerationPublicationFixture(a, b);
    gSelected = @"b"; // Stale resolver cache must not defeat authoritative A.
    NSUInteger caches = gCacheChanges, adoptions = gArtifactAdoptions;
    __block NSUInteger commits = 0;
    gStore.testCheckpoint = ^(NSString *stage) { if ([stage isEqual:@"commit-written"]) commits++; };
    NSError *error = nil;
    CHECK([manager regenerateAllEnabledIdentifiersForExpectedActiveProfileID:@"a" error:&error] && !error && commits == 1 && gCacheChanges == caches + 4 && gArtifactAdoptions == adoptions + 4,
          "expected generation publication uses source selection even when resolver cache is stale");
    gStore.testCheckpoint = nil;
    manager = GenerationPublicationFixture(a, b);
    manager.beforePublicationCheck = ^(PXCommittedRuntimeGeneration *generation, NSArray *keys, NSArray *paths) {
        (void)generation; (void)keys; (void)paths; CHECK(NO, "generic generation must not read expected publication checkpoints");
    };
    CHECK([manager regenerateAllEnabledIdentifiersWithError:&error] && !error && manager.publicationChecks == 0 && manager.beforePublicationCheck,
          "generic generation retains legacy publication without targeted checkpoint reads");
    manager.beforePublicationCheck = nil; gSelected = @"a"; CheckLeaseFree();
}

@interface PXRequiredIdentifiersFixture : PXDeviceGroupFixture
@property (nonatomic, copy) dispatch_block_t afterSelection;
@property (nonatomic) NSUInteger selectionCaptures;
@end
@implementation PXRequiredIdentifiersFixture
- (NSDictionary *)captureExpectedActiveSelection:(NSString *)profileID lifecycleLease:(PXProfileLifecycleLease *)lease error:(NSError **)error {
    self.selectionCaptures++;
    NSDictionary *selection = [super captureExpectedActiveSelection:profileID lifecycleLease:lease error:error];
    dispatch_block_t callback = self.afterSelection; self.afterSelection = nil;
    if (callback) callback();
    return selection;
}
@end
static NSDictionary *RequiredArtifactSnapshot(NSString *a, NSString *b) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSDictionary *all = BatchSnapshot()[@"files"];
    NSString *aRoot = [a.stringByDeletingLastPathComponent.lastPathComponent stringByAppendingString:@"/"], *bRoot = [b.stringByDeletingLastPathComponent.lastPathComponent stringByAppendingString:@"/"];
    for (NSString *path in all) if ([path hasPrefix:aRoot] || [path hasPrefix:bRoot]) result[path] = all[path];
    return result;
}
static PXRequiredIdentifiersFixture *RequiredIdentifiersFixture(void) {
    CHECK(SelectExpectedSource(@"a", @"required-before"), "required flag active selection seeded");
    PXRequiredIdentifiersFixture *manager = [PXRequiredIdentifiersFixture new];
    manager.settings = [@{ @"IDFA": @YES, @"Battery": @NO, @"StorageSystem": @NO } mutableCopy];
    manager.scopedApps = [@{ @"fixture.required": @YES } mutableCopy];
    return manager;
}
static void TestRequiredIdentifiers(NSString *a, NSString *b) {
    NSArray *types = @[@"IOSVersion", @"DeviceModel", @"StorageSystem", @"DeviceName"];
    PXRequiredIdentifiersFixture *manager = RequiredIdentifiersFixture();
    CHECK(SetSource(PXTLinkIOSSettingsPath(), @"KeepTopLevel", @YES), "required settings merge basis seeded");
    NSDictionary *artifacts = RequiredArtifactSnapshot(a, b);
    CHECK(artifacts.count > 0, "required artifact oracle includes real profile file bytes");
    NSUInteger preparations = gPreparations, migrations = gMigrations, selections = gSelections;
    NSUInteger caches = gCacheChanges, adoptions = gArtifactAdoptions, notices = gBatchNotifications;
    __block NSUInteger commits = 0;
    gStore.testCheckpoint = ^(NSString *stage) { if ([stage isEqual:@"commit-written"]) commits++; };
    gSelected = @"b"; NSError *error = nil;
    gDuringRequiredNotification = ^{ CheckLeaseFree(); };
    CHECK([manager enableRequiredIdentifiers:types forExpectedActiveProfileID:@"a" error:&error] && !error && !manager.error && commits == 1 &&
          gBatchNotifications == notices + 1 && gPreparations == preparations && gMigrations == migrations && gSelections == selections &&
          gCacheChanges == caches && gArtifactAdoptions == adoptions && [artifacts isEqual:RequiredArtifactSnapshot(a, b)],
          "required flags commit once without target resolution providers migration or profile artifact writes");
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:PXTLinkIOSSettingsPath()];
    BOOL allEnabled = YES;
    for (NSString *type in types) if (![settings[@"EnabledIdentifiers"][type] boolValue] || ![manager.settings[type] boolValue]) allEnabled = NO;
    CHECK(allEnabled && [settings[@"StorageSystemEnabled"] boolValue] && [settings[@"KeepTopLevel"] boolValue] &&
          [settings[@"EnabledIdentifiers"][@"IDFA"] boolValue] && ![settings[@"EnabledIdentifiers"][@"Battery"] boolValue] &&
          [[[NSDictionary dictionaryWithContentsOfFile:PXGlobalScopePath()] objectForKey:@"ScopedApps"] isEqual:manager.scopedApps],
          "required packet keeps enable-only policy unrelated flags top-level keys scope and storage alias");
    NSDictionary *before = BatchSnapshot(); notices = gBatchNotifications;
    CHECK([manager enableRequiredIdentifiers:types forExpectedActiveProfileID:@"a" error:NULL] && commits == 1 && notices == gBatchNotifications && [before isEqual:BatchSnapshot()],
          "already enabled required packet validates selection without writes or notification");
    gStore.testCheckpoint = nil;
    CHECK(SelectExpectedSource(@"b", @"required-mismatch"), "required mismatch source installed"); before = BatchSnapshot();
    CHECK(![manager enableRequiredIdentifiers:types forExpectedActiveProfileID:@"a" error:&error] && error && [before isEqual:BatchSnapshot()] && notices == gBatchNotifications,
          "required packet rejects authoritative mismatch even when all flags are already enabled");
    for (id invalid in @[@[@"Battery"], @[@"WiFi"], @[@1], @"IOSVersion", NSNull.null]) {
        before = BatchSnapshot();
        CHECK(![manager enableRequiredIdentifiers:invalid forExpectedActiveProfileID:@"a" error:&error] && error && [before isEqual:BatchSnapshot()],
              "required packet rejects unsupported secondary toggles and malformed requests");
    }
    for (NSUInteger cut = 1; cut <= 2; cut++) {
        manager = RequiredIdentifiersFixture();
        if (cut == 2) CHECK(PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
            return [tx removeDictionaryAtPath:PXGlobalScopePath() error:writeError];
        }, NULL), "required rollback fixture has absent scope source");
        before = BatchSnapshot(); NSDictionary *memory = [manager.settings copy]; notices = gBatchNotifications;
        __block NSUInteger writes = 0;
        gStore.testCheckpoint = ^(NSString *stage) { if ([stage isEqual:@"source-written"] && ++writes == cut) [NSException raise:@"fixture.required" format:@"flag packet fault"]; };
        CHECK(![manager enableRequiredIdentifiers:types forExpectedActiveProfileID:@"a" error:&error] && error && [before isEqual:BatchSnapshot()] &&
              [memory isEqual:manager.settings] && notices == gBatchNotifications, "required flag fault rolls back settings scope and memory without publication");
        gStore.testCheckpoint = nil; CheckLeaseFree();
    }
    for (NSUInteger drift = 0; drift < 4; drift++) {
        manager = RequiredIdentifiersFixture(); __block NSDictionary *competitor = nil;
        NSDictionary *memory = [manager.settings copy]; notices = gBatchNotifications;
        manager.afterSelection = ^{
            if (drift == 0) CHECK(SelectExpectedSource(@"b", @"required-new-target"), "required competitor selects B");
            else if (drift == 1) CHECK(SelectExpectedSource(@"a", @"required-new-revision"), "required competitor replaces same-ID selection receipt");
            else if (drift == 2) CHECK(SetSource(PXLegacyActiveProfileInfoPath(), @"SelectionRevision", @"legacy-drift"), "required legacy selection drifts");
            else CHECK(SetSource(PXProfileDeletionJournalPath(), @"state", @"pending"), "required late deletion intent installed");
            competitor = BatchSnapshot();
        };
        CHECK(![manager enableRequiredIdentifiers:types forExpectedActiveProfileID:@"a" error:&error] && error && [competitor isEqual:BatchSnapshot()] &&
              [memory isEqual:manager.settings] && notices == gBatchNotifications, "required packet revalidates selection receipt and deletion before staging any flag");
        if (drift == 3) CHECK(PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
            return [tx removeDictionaryAtPath:PXProfileDeletionJournalPath() error:writeError];
        }, NULL), "required deletion fixture removed");
        CheckLeaseFree();
    }
    manager = RequiredIdentifiersFixture(); before = BatchSnapshot();
    PXProfileLifecycleLease *held = [PXProfileLifecycleLease acquireInDirectory:gRoot error:NULL];
    CHECK(held && ![manager enableRequiredIdentifiers:types forExpectedActiveProfileID:@"a" error:&error] && error.code == 12 && !manager.selectionCaptures && [before isEqual:BatchSnapshot()],
          "busy required packet rejects before selection capture and settings mutation");
    [held invalidate];
    CHECK(SetSource(PXProfileDeletionJournalPath(), @"state", @"pending"), "required early deletion intent installed"); before = BatchSnapshot();
    CHECK(![manager enableRequiredIdentifiers:types forExpectedActiveProfileID:@"a" error:&error] && error && !manager.selectionCaptures && [before isEqual:BatchSnapshot()],
          "pending deletion blocks required flags before selection capture or writes");
    CHECK(PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return [tx removeDictionaryAtPath:PXProfileDeletionJournalPath() error:writeError];
    }, NULL), "required early deletion fixture removed");
    NSMutableString *mutableID = [@"a" mutableCopy], *mutableType = [@"DeviceName" mutableCopy];
    NSMutableArray *mutableTypes = [NSMutableArray arrayWithObject:mutableType];
    manager.afterSelection = ^{ [mutableID setString:@"b"]; [mutableType setString:@"Battery"]; [mutableTypes removeAllObjects]; };
    CHECK([manager enableRequiredIdentifiers:mutableTypes forExpectedActiveProfileID:mutableID error:&error] && !error && [manager.settings[@"DeviceName"] boolValue] && ![manager.settings[@"Battery"] boolValue],
          "required packet freezes caller ID container and strings before source callbacks");
    manager = RequiredIdentifiersFixture(); notices = gBatchNotifications;
    gDuringRequiredNotification = ^{ CheckLeaseFree(); [NSException raise:@"fixture.required" format:@"notification observer exception"]; };
    CHECK([manager enableRequiredIdentifiers:types forExpectedActiveProfileID:@"a" error:&error] && !error && !manager.error && notices + 1 == gBatchNotifications,
          "required flag notification exception after ownership release preserves committed success");
    for (NSUInteger noOp = 0; noOp < 2; noOp++) {
        manager = RequiredIdentifiersFixture();
        if (noOp) for (NSString *type in types) manager.settings[type] = @YES;
        before = BatchSnapshot(); NSDictionary *memory = [manager.settings copy]; notices = gBatchNotifications;
        __block BOOL accepted = YES;
        BOOL outer = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
            if (![tx setDictionary:@{ @"uncommitted": @YES } atPath:PXTLinkIOSSettingsPath() error:writeError]) return NO;
            accepted = [manager enableRequiredIdentifiers:types forExpectedActiveProfileID:@"a" error:NULL];
            return YES; // Swallowing the failure must still poison outer staging.
        }, &error);
        CHECK(!outer && error && !accepted && [before isEqual:BatchSnapshot()] && [memory isEqual:manager.settings] && notices == gBatchNotifications,
              "required packet including no-op rejects nested source acknowledgement before publication");
        CheckLeaseFree();
    }
    gSelected = @"a"; CheckLeaseFree();
}

static void TestDashboardHardwareCapture(PXDeviceGroupFixture *manager, NSString *a, NSString *b) {
    NSDictionary *aHardware = @{ @"DeviceModel": @"iPhone15,4", @"DeviceModelName": @"A name", @"RegulatoryModelNumber": @"A2846", @"BoardID": @"A-board", @"HwModel": @"A-hw" };
    NSDictionary *bHardware = @{ @"DeviceModel": @"iPhone16,1", @"DeviceModelName": @"B name", @"RegulatoryModelNumber": @"B-number", @"BoardID": @"B-board", @"HwModel": @"B-hw" };
    CHECK(Seed(a, aHardware, NO) && Seed(b, bHardware, NO) && SelectExpectedSource(@"a", @"hardware-capture"), "dashboard hardware capture independent sources seeded");
    gSelected = @"b";
    NSDictionary *before = BatchSnapshot();
    NSUInteger resolves = gSelections, migrations = gMigrations, preparations = gPreparations, caches = gCacheChanges, adoptions = gArtifactAdoptions, notices = gBatchNotifications;
    NSError *error = [NSError errorWithDomain:@"old" code:9 userInfo:nil];
    NSDictionary *captured = [manager captureCurrentDashboardHardwareWithError:&error];
    CHECK([captured isEqual:aHardware] && !error && [before isEqual:BatchSnapshot()] && resolves == gSelections && migrations == gMigrations && preparations == gPreparations && caches == gCacheChanges && adoptions == gArtifactAdoptions && notices == gBatchNotifications,
          "hardware capture reads authoritative selection and one source without cache resolver migration provider or commit effects");
    CHECK(SelectExpectedSource(@"b", @"hardware-after") && SetSource(Path(a, @"device_ids.plist"), @"BoardID", @"newer-board"), "hardware source changes after capture");
    CHECK([captured isEqual:aHardware] && [[manager captureCurrentDashboardHardwareWithError:NULL] isEqual:bHardware],
          "hardware packet remains detached when selection or captured source changes later");
    CHECK(PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return [tx removeDictionaryAtPath:PXCurrentProfileInfoPath() error:writeError];
    }, NULL), "hardware legacy fallback fixture seeded");
    before = BatchSnapshot();
    CHECK([[manager captureCurrentDashboardHardwareWithError:&error] isEqual:bHardware] && !error && [before isEqual:BatchSnapshot()], "hardware capture preserves legacy fallback without selection repair");
    CHECK(SetSource(PXCurrentProfileInfoPath(), @"ProfileId", @7), "hardware invalid canonical selection seeded"); before = BatchSnapshot();
    CHECK(![manager captureCurrentDashboardHardwareWithError:&error] && error.code == 20 && [before isEqual:BatchSnapshot()], "hardware capture does not fall back past invalid canonical selection");
    CHECK(PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return [tx removeDictionaryAtPath:PXCurrentProfileInfoPath() error:writeError] && [tx removeDictionaryAtPath:PXLegacyActiveProfileInfoPath() error:writeError];
    }, NULL), "hardware missing selection fixture seeded"); before = BatchSnapshot();
    CHECK(![manager captureCurrentDashboardHardwareWithError:NULL] && [before isEqual:BatchSnapshot()], "hardware capture rejects missing selection without creating a profile");
    CHECK(SelectExpectedSource(@"a", @"hardware-model-validation"), "hardware model validation target seeded");
    for (id model in @[@7, @"", NSNull.null]) {
        CHECK(PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
            return model == NSNull.null ? [tx removeDictionaryAtPath:Path(a, @"device_ids.plist") error:writeError] : [tx setDictionary:@{ @"DeviceModel": model } atPath:Path(a, @"device_ids.plist") error:writeError];
        }, NULL), "hardware invalid or missing identity source seeded"); before = BatchSnapshot();
        CHECK(![manager captureCurrentDashboardHardwareWithError:&error] && error.code == 6032 && [before isEqual:BatchSnapshot()], "hardware capture rejects missing empty or malformed model before preview work");
    }
    CHECK(Seed(a, aHardware, NO), "hardware malformed plist baseline restored");
    NSString *path = Path(a, @"device_ids.plist"); NSData *saved = [NSData dataWithContentsOfFile:path]; NSDictionary *clean = BatchSnapshot();
    @try {
        CHECK([[@"invalid hardware plist" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:YES], "hardware malformed plist injected");
        before = BatchSnapshot();
        CHECK(![manager captureCurrentDashboardHardwareWithError:&error] && error && [before isEqual:BatchSnapshot()], "hardware capture preserves corrupt source bytes on failure");
    } @finally { CHECK([saved writeToFile:path atomically:YES], "hardware malformed fixture restores original bytes"); }
    CHECK([clean isEqual:BatchSnapshot()], "hardware malformed teardown restores shared files and commit identity");
    CHECK(SetSource(path, @"DeviceModelName", @7) && SetSource(path, @"BoardID", @[]) && SetSource(path, @"HwModel", @""), "hardware optional field type fixture seeded");
    captured = [manager captureCurrentDashboardHardwareWithError:&error];
    CHECK(captured && !error && [captured[@"DeviceModel"] isEqual:aHardware[@"DeviceModel"]] && !captured[@"DeviceModelName"] && !captured[@"BoardID"] && !captured[@"HwModel"], "hardware capture keeps legacy optional string omission policy");
    before = BatchSnapshot(); __block NSDictionary *uncommitted = nil;
    BOOL outer = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        if (![tx setDictionary:bHardware atPath:path error:writeError]) return NO;
        uncommitted = [manager captureCurrentDashboardHardwareWithError:NULL];
        return YES;
    }, &error);
    CHECK(!outer && error && !uncommitted && [before isEqual:BatchSnapshot()], "hardware capture rejects nested uncommitted source views and poisons outer staging");
    gSelected = @"a";
}

static void InvokeSettingsSave(PXDeviceGroupFixture *manager, BOOL scopeOnly) {
    if (scopeOnly) [manager saveScopedApps]; else [manager saveSettings];
}
static void TestStandaloneSettingsSaves(PXDeviceGroupFixture *manager, NSString *a) {
    for (NSUInteger mode = 0; mode < 2; mode++) {
        BOOL scopeOnly = mode == 1;
        manager.settings = [@{ @"IDFA": @YES, @"StorageSystem": @YES, @"NotAnIdentifier": @YES } mutableCopy];
        manager.scopedApps = [@{ @"settings.fixture": @{ @"enabled": @YES, @"name": @"fixture" } } mutableCopy];
        CHECK(SetSource(PXTLinkIOSSettingsPath(), @"UnrelatedFeature", @YES), "settings save top-level merge fixture seeded");
        [manager seedPersistenceCaches]; manager.error = nil;
        NSData *settingsBefore = [NSData dataWithContentsOfFile:PXTLinkIOSSettingsPath()];
        NSUInteger notices = gBatchNotifications; __block NSUInteger commits = 0, delivered = 0;
        gStore.testCheckpoint = ^(NSString *stage) { if ([stage isEqual:@"commit-written"]) commits++; };
        gDuringRequiredNotification = ^{
            NSDictionary *scope = [NSDictionary dictionaryWithContentsOfFile:PXGlobalScopePath()];
            NSDictionary *caches = [manager persistenceCaches];
            CHECK([scope[@"ScopedApps"] isEqual:manager.scopedApps] && ![caches[@"spoof"] count] && ![caches[@"enabled"] count], "settings notification sees committed scope and invalidated caches outside source gate");
            delivered++;
        };
        InvokeSettingsSave(manager, scopeOnly); gStore.testCheckpoint = nil;
        NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:PXTLinkIOSSettingsPath()];
        CHECK(!manager.error && commits == 1 && delivered == 1 && notices + 1 == gBatchNotifications,
              "standalone settings and scope saves commit once before one compatibility notification");
        if (scopeOnly) CHECK([settingsBefore isEqual:[NSData dataWithContentsOfFile:PXTLinkIOSSettingsPath()]], "scope-only save preserves settings source bytes");
        else CHECK([settings[@"EnabledIdentifiers"][@"IDFA"] boolValue] && [settings[@"EnabledIdentifiers"][@"StorageSystem"] boolValue] && !settings[@"EnabledIdentifiers"][@"NotAnIdentifier"] && [settings[@"StorageSystemEnabled"] boolValue] && [settings[@"SettingsInitialized"] boolValue] && [settings[@"UnrelatedFeature"] boolValue], "standalone settings save preserves canonical map storage alias and unrelated top-level policy");
        for (NSUInteger finish = 0; finish < 3; finish++) {
            CHECK(chmod(PXGlobalScopePath().fileSystemRepresentation, 0600) == 0, "nested settings scope permission fixture seeded");
            [manager seedPersistenceCaches]; manager.error = nil;
            NSDictionary *before = BatchSnapshot(), *cacheBefore = [manager persistenceCaches];
            notices = gBatchNotifications; NSError *error = nil; __block BOOL attempted = NO;
            BOOL outer = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
                if (![tx setDictionary:@{ @"uncommitted": @YES } atPath:Path(a, @"device_ids.plist") error:writeError]) return NO;
                attempted = YES; InvokeSettingsSave(manager, scopeOnly);
                if (finish == 2) [NSException raise:@"fixture.settings" format:@"outer source exception after save"];
                return finish == 1; // An ignored nested failure must poison outer staging.
            }, &error);
            struct stat st = {0}; BOOL hasMode = stat(PXGlobalScopePath().fileSystemRepresentation, &st) == 0;
            CHECK(attempted && !outer && error && manager.error.code == 4006 && [before isEqual:BatchSnapshot()] && [cacheBefore isEqual:[manager persistenceCaches]] && notices == gBatchNotifications && hasMode && (st.st_mode & 0777) == 0600,
                  "nested settings helpers reject before permissions caches or notification and poison ignored outer staging");
        }
        for (NSUInteger cut = 1; cut <= (scopeOnly ? 1 : 2); cut++) {
            if (!scopeOnly && cut == 2) CHECK(PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
                return [tx removeDictionaryAtPath:PXGlobalScopePath() error:writeError];
            }, NULL), "settings fault fixture includes absent scope source");
            [manager seedPersistenceCaches]; manager.error = nil;
            NSDictionary *before = BatchSnapshot(), *cacheBefore = [manager persistenceCaches]; notices = gBatchNotifications;
            __block NSUInteger writes = 0;
            gStore.testCheckpoint = ^(NSString *stage) { if ([stage isEqual:@"source-written"] && ++writes == cut) [NSException raise:@"fixture.settings" format:@"settings physical source fault"]; };
            InvokeSettingsSave(manager, scopeOnly); gStore.testCheckpoint = nil;
            CHECK(manager.error.code == 4006 && writes == cut && [before isEqual:BatchSnapshot()] && [cacheBefore isEqual:[manager persistenceCaches]] && notices == gBatchNotifications,
                  "standalone settings source faults preserve bytes commit identity caches and notification count");
        }
        NSString *path = scopeOnly ? PXGlobalScopePath() : PXTLinkIOSSettingsPath();
        NSData *saved = [NSData dataWithContentsOfFile:path]; NSDictionary *clean = BatchSnapshot();
        @try {
            CHECK([[@"malformed settings source" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:YES], "settings malformed source fixture injected");
            [manager seedPersistenceCaches]; manager.error = nil;
            NSDictionary *before = BatchSnapshot(), *cacheBefore = [manager persistenceCaches]; notices = gBatchNotifications;
            InvokeSettingsSave(manager, scopeOnly);
            CHECK(manager.error.code == 4006 && [before isEqual:BatchSnapshot()] && [cacheBefore isEqual:[manager persistenceCaches]] && notices == gBatchNotifications,
                  "settings helpers preserve corrupt source without cache or notification effects");
        } @finally { CHECK([saved writeToFile:path atomically:YES], "settings malformed fixture restores original bytes"); }
        CHECK([clean isEqual:BatchSnapshot()], "settings corruption teardown restores shared files and commit identity");
    }
}

static void TestIdentifierToggleAcknowledgement(void) {
    PXDeviceGroupFixture *manager = [PXDeviceGroupFixture new];
    manager.settings = [@{ @"IDFA": @NO, @"WiFi": @NO, @"Battery": @NO, @"DeviceTheme": @NO,
                            @"StorageSystem": @NO } mutableCopy];
    [manager saveSettings];
    CHECK(PXWriteSecurityBool(@"wifiSpoofEnabled", NO, NULL) &&
          PXWriteSecurityBool(@"batterySpoofEnabled", NO, NULL) &&
          PXWriteSecurityBool(@"deviceThemeSpoofEnabled", NO, NULL), "toggle already matching baseline seeded");
    // Fault each primary file even though the old value already equals NO.
    // No compensating write is permitted when the primary has not committed.
    for (NSUInteger cut = 1; cut <= 2; cut++) {
        [manager seedPersistenceCaches]; manager.error = nil;
        NSDictionary *before = BatchSnapshot(), *cache = [manager persistenceCaches];
        NSUInteger notices = gBatchNotifications; __block NSUInteger writes = 0;
        gStore.testCheckpoint = ^(NSString *stage) {
            if ([stage isEqual:@"source-written"] && ++writes % cut == 0)
                [NSException raise:@"fixture.toggle" format:@"primary fault"];
        };
        BOOL success = [manager setIdentifierEnabledAndPersist:NO forType:@"IDFA"];
        gStore.testCheckpoint = nil;
        CHECK(!success && manager.error.code == 4006 && [before isEqual:BatchSnapshot()] &&
              [cache isEqual:[manager persistenceCaches]] && notices == gBatchNotifications,
              "matching old primary value never acknowledges a failed forward write");
    }
    NSUInteger restoredNotices = gBatchNotifications; __block BOOL faulted = NO;
    gStore.testCheckpoint = ^(NSString *stage) {
        if (!faulted && [stage isEqual:@"source-written"]) {
            faulted = YES; [NSException raise:@"fixture.toggle" format:@"one shot primary fault"];
        }
    };
    BOOL restoredSuccess = [manager setIdentifierEnabledAndPersist:NO forType:@"IDFA"];
    gStore.testCheckpoint = nil;
    CHECK(faulted && !restoredSuccess && manager.error.code == 4006 && gBatchNotifications == restoredNotices,
          "primary forward failure restores memory without a compensating commit or notification");
    // A failed secondary write also cannot be inferred from its matching old value.
    for (NSString *type in @[@"WiFi", @"Battery", @"DeviceTheme"]) {
        gToggleSecurityFailures = 1;
        NSUInteger writes = gToggleSecurityWrites, topics = gToggleSecondaryNotices, notices = gBatchNotifications;
        CHECK(![manager setIdentifierEnabledAndPersist:NO forType:type] && manager.error.code == 71 &&
              [manager.error.domain isEqual:@"fixture.toggle.security"] &&
              gToggleSecurityWrites == writes + 1 && gToggleSecondaryNotices == topics + 1 &&
              gBatchNotifications == notices + 2,
              "matching old secondary value cannot hide forward failure and rollback retains original error");
        // Stale shared error is intentionally irrelevant to the next local receipt.
        CHECK([manager setIdentifierEnabledAndPersist:NO forType:type], "toggle success uses local receipt despite stale shared manager error");
        CHECK([manager setIdentifierEnabledAndPersist:YES forType:type] && [manager.settings[type] boolValue] &&
              [manager setIdentifierEnabledAndPersist:NO forType:type] && ![manager.settings[type] boolValue],
              "verified secondary toggles retain successful enable and disable behavior");
    }
    NSUInteger writes = gToggleSecurityWrites, topics = gToggleSecondaryNotices, notices = gBatchNotifications;
    NSError *failure = nil; __block NSUInteger physicalWrites = 0;
    gStore.testCheckpoint = ^(NSString *stage) {
        if ([stage isEqual:@"source-written"] && ++physicalWrites == 1)
            [NSException raise:@"fixture.toggle" format:@"skip secondary"];
    };
    BOOL applied = [manager applyIdentifierEnabled:NO forType:@"WiFi" error:&failure];
    gStore.testCheckpoint = nil;
    CHECK(!applied && failure.code == 4006 && writes == gToggleSecurityWrites && topics == gToggleSecondaryNotices && notices == gBatchNotifications,
          "failed primary receipt stops secondary writes even when old enabled flag matches");

    NSDictionary *before = BatchSnapshot(); notices = gBatchNotifications;
    __block BOOL innerSuccess = YES;
    BOOL outer = [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        if (![tx setDictionary:@{ @"uncommitted": @YES } atPath:Path(gRoot, @"toggle-outer.plist") error:error]) return NO;
        innerSuccess = [manager setIdentifierEnabledAndPersist:NO forType:@"IDFA"];
        return YES; // Ignoring the inner failure must not commit staged work.
    } error:&failure];
    CHECK(!outer && !innerSuccess && failure && [before isEqual:BatchSnapshot()] && notices == gBatchNotifications,
          "nested toggle matching old primary rejects acknowledgement and poisons ignored outer staging");

    // Preserve the existing post-notification value guard: a reentrant change
    // must prevent the older secondary write, even after a successful primary commit.
    writes = gToggleSecurityWrites; topics = gToggleSecondaryNotices;
    gDuringRequiredNotification = ^{
        CHECK([gStore performStandaloneWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
            NSMutableDictionary *settings = [[tx dictionaryAtPath:PXTLinkIOSSettingsPath() error:error] mutableCopy];
            NSMutableDictionary *flags = [settings[@"EnabledIdentifiers"] mutableCopy]; flags[@"WiFi"] = @YES;
            settings[@"EnabledIdentifiers"] = flags;
            return [tx setDictionary:settings atPath:PXTLinkIOSSettingsPath() error:error];
        } error:NULL], "toggle notification reentry changes committed primary flag");
    };
    CHECK(![manager applyIdentifierEnabled:NO forType:@"WiFi" error:&failure] && failure.code == 6033 &&
          writes == gToggleSecurityWrites && topics == gToggleSecondaryNotices,
          "toggle receipt retains readback guard before secondary publication after notification reentry");
    [manager saveSettings];

    NSMutableString *type = [@"IDFA" mutableCopy]; gToggleMissingValue = @"IDFA";
    NSUInteger generations = gToggleGenerations;
    gDuringToggleGeneration = ^{ [type setString:@"Battery"]; };
    CHECK([manager setIdentifierEnabledAndPersist:YES forType:type] && gToggleGenerations == generations + 1 &&
          [type isEqual:@"Battery"] && [manager.settings[@"IDFA"] boolValue] && ![manager.settings[@"Battery"] boolValue],
          "toggle freezes mutable caller key before legacy provider callbacks without changing generation policy");
    generations = gToggleGenerations;
    [manager setIdentifierEnabled:YES forType:@"IDFA"];
    CHECK(generations == gToggleGenerations && [manager setIdentifierEnabledAndPersist:YES forType:@"StorageSystem"] &&
          [[NSDictionary dictionaryWithContentsOfFile:PXTLinkIOSSettingsPath()][@"StorageSystemEnabled"] boolValue],
          "legacy void setter skips existing generation and verified storage retains atomic alias");
    before = BatchSnapshot(); notices = gBatchNotifications;
    CHECK(![manager setIdentifierEnabledAndPersist:YES forType:nil] &&
          ![manager setIdentifierEnabledAndPersist:YES forType:(id)@7] &&
          ![manager setIdentifierEnabledAndPersist:YES forType:@""] &&
          [before isEqual:BatchSnapshot()] && notices == gBatchNotifications,
          "invalid toggle keys fail before settings source or notification work");
}

static PXDeviceGroupFixture *ToggleReentryFixture(void) {
    PXDeviceGroupFixture *manager = [PXDeviceGroupFixture new];
    manager.settings = [@{ @"IDFA": @NO, @"WiFi": @NO, @"Battery": @NO, @"DeviceTheme": @NO } mutableCopy];
    [manager saveSettings];
    CHECK(PXWriteSecurityBool(@"wifiSpoofEnabled", NO, NULL) && PXWriteSecurityBool(@"batterySpoofEnabled", NO, NULL),
          "toggle reentry fixture seeds primary and secondary sources");
    return manager;
}
static void TestIdentifierToggleReentry(void) {
    PXDeviceGroupFixture *manager = ToggleReentryFixture();
    __block BOOL inner = NO; __block NSDictionary *latest = nil, *cache = nil;
    NSUInteger notices = gBatchNotifications, writes = gToggleSecurityWrites, topics = gToggleSecondaryNotices;
    gDuringRequiredNotification = ^{
        inner = [manager setIdentifierEnabledAndPersist:YES forType:@"WiFi"];
        manager.error = [NSError errorWithDomain:@"fixture.newer" code:995 userInfo:nil];
        [manager seedPersistenceCaches]; latest = BatchSnapshot(); cache = [manager persistenceCaches];
    };
    BOOL success = [manager setIdentifierEnabledAndPersist:NO forType:@"WiFi"];
    CHECK(!success && inner && [manager.settings[@"WiFi"] boolValue] && [PXReadSecuritySetting(@"wifiSpoofEnabled") boolValue] &&
          [latest isEqual:BatchSnapshot()] && [cache isEqual:[manager persistenceCaches]] && manager.error.code == 995 &&
          notices + 2 == gBatchNotifications && writes + 1 == gToggleSecurityWrites && topics + 1 == gToggleSecondaryNotices &&
          !manager.identifierToggleOperations.count,
          "newer same identifier notification call survives older forward path rollback caches and shared error");

    manager = ToggleReentryFixture(); notices = gBatchNotifications; writes = gToggleSecurityWrites;
    gDuringRequiredNotification = ^{
        CHECK([manager setIdentifierEnabledAndPersist:NO forType:@"WiFi"] &&
              [manager setIdentifierEnabledAndPersist:YES forType:@"WiFi"], "toggle ABA successors both commit");
        latest = BatchSnapshot();
    };
    CHECK(![manager setIdentifierEnabledAndPersist:YES forType:@"WiFi"] && [latest isEqual:BatchSnapshot()] &&
          notices + 3 == gBatchNotifications && writes + 2 == gToggleSecurityWrites && !manager.identifierToggleOperations.count,
          "matching ABA values never restore superseded toggle ownership or permit stale secondary publication");

    manager = ToggleReentryFixture();
    gDuringRequiredNotification = ^{ inner = [manager setIdentifierEnabledAndPersist:YES forType:@"Battery"]; };
    CHECK([manager setIdentifierEnabledAndPersist:YES forType:@"WiFi"] && inner &&
          [manager.settings[@"Battery"] boolValue] && [PXReadSecuritySetting(@"wifiSpoofEnabled") boolValue] &&
          [PXReadSecuritySetting(@"batterySpoofEnabled") boolValue] && !manager.identifierToggleOperations.count,
          "different identifier reentry preserves both successful operations");

    manager = ToggleReentryFixture(); notices = gBatchNotifications;
    gToggleMissingValue = @"IDFA";
    gDuringToggleGeneration = ^{
        inner = [manager setIdentifierEnabledAndPersist:NO forType:@"IDFA"]; latest = BatchSnapshot();
    };
    CHECK(![manager setIdentifierEnabledAndPersist:YES forType:@"IDFA"] && inner &&
          [latest isEqual:BatchSnapshot()] && notices + 1 == gBatchNotifications && ![manager.settings[@"IDFA"] boolValue],
          "provider reentry supersedes older toggle before its settings commit");

    for (NSUInteger boundary = 0; boundary < 2; boundary++) {
        manager = ToggleReentryFixture(); notices = gBatchNotifications; writes = gToggleSecurityWrites; topics = gToggleSecondaryNotices;
        BOOL requested = boundary == 1;
        if (!requested) gToggleSecurityFailures = 1;
        gDuringToggleSecurityWrite = ^{
            inner = [manager setIdentifierEnabledAndPersist:!requested forType:@"WiFi"];
            manager.error = [NSError errorWithDomain:@"fixture.newer" code:995 userInfo:nil]; latest = BatchSnapshot();
        };
        CHECK(![manager setIdentifierEnabledAndPersist:requested forType:@"WiFi"] && inner &&
              [latest isEqual:BatchSnapshot()] && manager.error.code == 995 &&
              [manager.settings[@"WiFi"] boolValue] == !requested &&
              [PXReadSecuritySetting(@"wifiSpoofEnabled") boolValue] == !requested &&
              writes + 2 == gToggleSecurityWrites && topics + 1 == gToggleSecondaryNotices && notices + 2 == gBatchNotifications,
              "secondary return reentry suppresses older failure rollback or obsolete success notification");
    }

    // Arrange the successor after recovery starts, at either primary rollback
    // notification or the secondary rollback writer's post-commit callback.
    for (NSUInteger boundary = 0; boundary < 2; boundary++) {
        manager = ToggleReentryFixture(); writes = gToggleSecurityWrites; topics = gToggleSecondaryNotices;
        gToggleSecurityFailures = 1;
        void (^newer)(void) = ^{
            inner = [manager setIdentifierEnabledAndPersist:YES forType:@"WiFi"];
            manager.error = [NSError errorWithDomain:@"fixture.newer" code:995 userInfo:nil];
            [manager seedPersistenceCaches]; latest = BatchSnapshot(); cache = [manager persistenceCaches];
        };
        gDuringToggleSecurityWrite = ^{
            if (boundary == 0) gDuringRequiredNotification = newer;
            else gDuringToggleSecurityPublication = newer;
        };
        CHECK(![manager setIdentifierEnabledAndPersist:YES forType:@"WiFi"] && inner &&
              [latest isEqual:BatchSnapshot()] && [cache isEqual:[manager persistenceCaches]] && manager.error.code == 995 &&
              [manager.settings[@"WiFi"] boolValue] && [PXReadSecuritySetting(@"wifiSpoofEnabled") boolValue] &&
              writes + 2 == gToggleSecurityWrites && topics + 1 == gToggleSecondaryNotices &&
              !manager.identifierToggleOperations.count,
              "successor during rollback keeps newer sources caches error and skips remaining stale effects");
    }

    manager = ToggleReentryFixture(); writes = gToggleSecurityWrites; topics = gToggleSecondaryNotices;
    gDuringToggleSecondaryNotification = ^{
        inner = [manager setIdentifierEnabledAndPersist:NO forType:@"WiFi"]; latest = BatchSnapshot();
    };
    CHECK(![manager setIdentifierEnabledAndPersist:YES forType:@"WiFi"] && inner && [latest isEqual:BatchSnapshot()] &&
          writes + 2 == gToggleSecurityWrites && topics + 2 == gToggleSecondaryNotices && !manager.identifierToggleOperations.count,
          "secondary notification successor prevents older verification rollback");

    manager = ToggleReentryFixture(); gToggleMissingValue = @"IDFA";
    NSDictionary *before = BatchSnapshot(); BOOL threw = NO;
    gDuringToggleGeneration = ^{ [NSException raise:@"fixture.toggle.reentry" format:@"provider exception"]; };
    @try { [manager setIdentifierEnabledAndPersist:YES forType:@"IDFA"]; }
    @catch (NSException *exception) { (void)exception; threw = YES; }
    CHECK(threw && !manager.identifierToggleOperations.count && [before isEqual:BatchSnapshot()] &&
          [manager setIdentifierEnabledAndPersist:NO forType:@"IDFA"],
          "throwing provider releases toggle token without changing legacy exception policy");

    manager = ToggleReentryFixture(); threw = NO;
    gDuringRequiredNotification = ^{ [NSException raise:@"fixture.toggle.reentry" format:@"observer exception"]; };
    @try { [manager setIdentifierEnabled:YES forType:@"WiFi"]; }
    @catch (NSException *exception) { (void)exception; threw = YES; }
    CHECK(threw && !manager.identifierToggleOperations.count && [manager setIdentifierEnabledAndPersist:NO forType:@"WiFi"],
          "throwing void setter observer releases toggle token and preserves later operations");

    id oldOperation = [manager beginIdentifierToggleForType:@"WiFi"];
    id newOperation = [manager beginIdentifierToggleForType:@"WiFi"];
    [manager finishIdentifierToggle:oldOperation forType:@"WiFi"];
    CHECK([manager validateIdentifierToggle:newOperation forType:@"WiFi" error:NULL] &&
          ![manager validateIdentifierToggle:oldOperation forType:@"WiFi" error:NULL], "stale toggle cleanup cannot revoke newer owner token");
    [manager finishIdentifierToggle:newOperation forType:@"WiFi"];
    CHECK(!manager.identifierToggleOperations.count, "toggle token registry removes completed keys");
    __weak PXDeviceGroupFixture *weakOwner = nil; id retainedToken = nil;
    @autoreleasepool {
        PXDeviceGroupFixture *owner = [PXDeviceGroupFixture new]; weakOwner = owner;
        retainedToken = [owner beginIdentifierToggleForType:@"WiFi"];
    }
    CHECK(!weakOwner && retainedToken, "bare toggle token never retains its manager owner");
}

static void TestToggleFailedPrimaryOwnership(void) {
    for (NSString *type in @[@"IDFA", @"WiFi", @"Battery", @"DeviceTheme"]) {
        for (NSUInteger cut = 1; cut <= 2; cut++) {
            PXDeviceGroupFixture *manager = ToggleReentryFixture();
            [manager seedPersistenceCaches];
            NSDictionary *before = BatchSnapshot(), *cache = [manager persistenceCaches];
            NSUInteger attempts = gStandaloneSourceAttempts, writes = gToggleSecurityWrites;
            NSUInteger notices = gBatchNotifications, topics = gToggleSecondaryNotices;
            __block NSUInteger physicalWrites = 0;
            gStore.testCheckpoint = ^(NSString *stage) {
                if ([stage isEqual:@"source-written"] && ++physicalWrites == cut)
                    [NSException raise:@"fixture.toggle.primary" format:@"one shot primary source fault"];
            };
            BOOL success = [manager setIdentifierEnabledAndPersist:YES forType:type];
            gStore.testCheckpoint = nil;
            CHECK(!success && manager.error.code == 4006 && ![manager.settings[type] boolValue] &&
                  physicalWrites == cut && attempts + 1 == gStandaloneSourceAttempts &&
                  [before isEqual:BatchSnapshot()] && [cache isEqual:[manager persistenceCaches]] &&
                  writes == gToggleSecurityWrites && notices == gBatchNotifications && topics == gToggleSecondaryNotices &&
                  !manager.identifierToggleOperations.count,
                  "failed primary uses one source attempt without compensation security cache or notification effects");
        }
    }
    for (NSUInteger cut = 1; cut <= 2; cut++) {
        PXDeviceGroupFixture *manager = ToggleReentryFixture();
        CHECK([gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
            return [tx removeDictionaryAtPath:PXTLinkIOSSettingsPath() error:error] &&
                   [tx removeDictionaryAtPath:PXGlobalScopePath() error:error];
        } error:NULL], "missing primary settings and scope fixture seeded");
        [manager seedPersistenceCaches];
        NSDictionary *before = BatchSnapshot(), *cache = [manager persistenceCaches];
        NSUInteger attempts = gStandaloneSourceAttempts, writes = gToggleSecurityWrites, notices = gBatchNotifications;
        __block NSUInteger physicalWrites = 0;
        gStore.testCheckpoint = ^(NSString *stage) {
            if ([stage isEqual:@"source-written"] && ++physicalWrites == cut)
                [NSException raise:@"fixture.toggle.primary" format:@"missing source write fault"];
        };
        BOOL success = [manager setIdentifierEnabledAndPersist:YES forType:@"WiFi"];
        gStore.testCheckpoint = nil;
        CHECK(!success && manager.error.code == 4006 && attempts + 1 == gStandaloneSourceAttempts &&
              [before isEqual:BatchSnapshot()] && [cache isEqual:[manager persistenceCaches]] &&
              ![NSFileManager.defaultManager fileExistsAtPath:PXTLinkIOSSettingsPath()] &&
              ![NSFileManager.defaultManager fileExistsAtPath:PXGlobalScopePath()] &&
              writes == gToggleSecurityWrites && notices == gBatchNotifications,
              "failed primary preserves exact missing sources instead of creating rollback settings or scope");
    }
    for (NSUInteger kind = 0; kind < 2; kind++) {
        PXDeviceGroupFixture *manager = ToggleReentryFixture();
        PXDeviceGroupFixture *competitor = [PXDeviceGroupFixture new];
        competitor.settings = [manager.settings mutableCopy];
        competitor.scopedApps = [@{ @"newer.scope": @{ @"enabled": @YES, @"name": @"newer writer" } } mutableCopy];
        [manager seedPersistenceCaches]; NSDictionary *cache = [manager persistenceCaches];
        __block BOOL faulted = NO, competitorSuccess = NO;
        __block NSDictionary *latest = nil;
        __block NSUInteger latestAttempts = 0, latestWrites = 0, latestNotices = 0, latestTopics = 0;
        gStore.testCheckpoint = ^(NSString *stage) {
            if (!faulted && [stage isEqual:@"source-written"]) {
                faulted = YES; [NSException raise:@"fixture.toggle.primary" format:@"primary fault before competing owner"];
            }
        };
        gAfterFailedStandaloneWrite = ^{
            CHECK(BatchSnapshot() != nil, "primary failure scheduling fixture runs after gate release");
            if (kind == 0) competitorSuccess = [competitor setIdentifierEnabledAndPersist:YES forType:@"WiFi"];
            else competitorSuccess = [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
                NSMutableDictionary *settings = [[tx dictionaryAtPath:PXTLinkIOSSettingsPath() error:error] mutableCopy];
                if (!settings) return NO;
                NSMutableDictionary *flags = [settings[@"EnabledIdentifiers"] mutableCopy];
                flags[@"WiFi"] = @YES; flags[@"IDFA"] = @YES; settings[@"EnabledIdentifiers"] = flags;
                NSMutableDictionary *security = [[tx dictionaryAtPath:PXSecuritySettingsPath() error:error] mutableCopy];
                if (!security) return NO;
                security[@"wifiSpoofEnabled"] = @YES;
                return [tx setDictionary:settings atPath:PXTLinkIOSSettingsPath() error:error] &&
                       [tx setDictionary:@{ @"ScopedApps": competitor.scopedApps } atPath:PXGlobalScopePath() error:error] &&
                       [tx setDictionary:security atPath:PXSecuritySettingsPath() error:error];
            } error:NULL];
            latest = BatchSnapshot(); latestAttempts = gStandaloneSourceAttempts; latestWrites = gToggleSecurityWrites;
            latestNotices = gBatchNotifications; latestTopics = gToggleSecondaryNotices;
        };
        BOOL success = [manager setIdentifierEnabledAndPersist:YES forType:@"WiFi"];
        gStore.testCheckpoint = nil;
        CHECK(faulted && competitorSuccess && !success && manager.error.code == 4006 && latest &&
              [latest isEqual:BatchSnapshot()] && [cache isEqual:[manager persistenceCaches]] &&
              latestAttempts == gStandaloneSourceAttempts && latestWrites == gToggleSecurityWrites &&
              latestNotices == gBatchNotifications && latestTopics == gToggleSecondaryNotices &&
              !manager.identifierToggleOperations.count && ![manager.settings[@"WiFi"] boolValue],
              "uncommitted primary failure never overwrites a later manager or direct writer commit");
    }
    // The separate acknowledgement is true even if a later secondary write fails.
    // The verified wrapper must retain its existing compensation policy for that case.
    PXDeviceGroupFixture *manager = ToggleReentryFixture();
    id operation = [manager beginIdentifierToggleForType:@"WiFi"];
    BOOL primaryCommitted = NO; NSError *failure = nil;
    gToggleSecurityFailures = 1;
    BOOL success = [manager applyIdentifierEnabled:YES forType:@"WiFi" operation:operation primaryCommitted:&primaryCommitted sourceCommitIdentifier:NULL error:&failure];
    [manager finishIdentifierToggle:operation forType:@"WiFi"];
    CHECK(!success && primaryCommitted && failure.code == 71 && [manager.settings[@"WiFi"] boolValue],
          "primary acknowledgement survives a later secondary failure independently of whole apply result");
    primaryCommitted = YES; failure = nil; NSDictionary *before = BatchSnapshot();
    CHECK(![manager applyIdentifierEnabled:NO forType:@"WiFi" operation:[NSObject new] primaryCommitted:&primaryCommitted sourceCommitIdentifier:NULL error:&failure] &&
          !primaryCommitted && failure.code == 6035 && [before isEqual:BatchSnapshot()],
          "primary acknowledgement resets before rejected owner admission");
}

static void TestConditionalToggleRollback(void) {
    for (NSUInteger kind = 0; kind < 3; kind++) {
        PXDeviceGroupFixture *manager = ToggleReentryFixture(), *other = [PXDeviceGroupFixture new];
        other.settings = [manager.settings mutableCopy];
        other.scopedApps = [@{ @"newer.scope": @{ @"enabled": @YES } } mutableCopy];
        __block NSDictionary *latest = nil, *cache = nil; __block NSUInteger notices = 0, topics = 0;
        NSUInteger publications = gToggleSecurityPublications;
        gDuringRequiredNotification = ^{
            if (kind == 0) {
                CHECK([other setIdentifierEnabledAndPersist:YES forType:@"WiFi"], "foreign toggle after primary commits");
            } else if (kind == 1) {
                CHECK([other setIdentifierEnabledAndPersist:NO forType:@"WiFi"] &&
                      [other setIdentifierEnabledAndPersist:YES forType:@"WiFi"], "foreign toggle ABA commits");
                gToggleSecurityFailures = 1;
            } else {
                CHECK([gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
                NSMutableDictionary *settings = [[tx dictionaryAtPath:PXTLinkIOSSettingsPath() error:error] mutableCopy];
                NSMutableDictionary *flags = [settings[@"EnabledIdentifiers"] mutableCopy]; flags[@"WiFi"] = @{};
                settings[@"EnabledIdentifiers"] = flags;
                return [tx setDictionary:settings atPath:PXTLinkIOSSettingsPath() error:error];
                } error:NULL], "foreign malformed toggle field committed for defensive readback");
            }
            latest = BatchSnapshot(); [manager seedPersistenceCaches]; cache = [manager persistenceCaches];
            notices = gBatchNotifications; topics = gToggleSecondaryNotices;
        };
        CHECK(![manager setIdentifierEnabledAndPersist:kind != 0 forType:@"WiFi"] && [latest isEqual:BatchSnapshot()] &&
              [cache isEqual:[manager persistenceCaches]] && notices == gBatchNotifications && topics == gToggleSecondaryNotices &&
              publications == gToggleSecurityPublications && !manager.identifierToggleOperations.count,
              "conditional rollback preserves foreign primary ABA and malformed-field successors without stale effects");
        if (kind < 2) CHECK([manager.settings[@"WiFi"] boolValue], "conflicted rollback refreshes requested memory flag from authoritative source");
    }
    PXDeviceGroupFixture *manager = ToggleReentryFixture(), *other = [PXDeviceGroupFixture new];
    other.settings = [manager.settings mutableCopy];
    __block NSDictionary *latest = nil, *cache = nil; __block NSUInteger notices = 0, topics = 0;
    gDuringToggleSecurityWrite = ^{
        CHECK([other setIdentifierEnabledAndPersist:NO forType:@"WiFi"], "foreign successor after secondary commit");
        latest = BatchSnapshot(); [manager seedPersistenceCaches]; cache = [manager persistenceCaches];
        notices = gBatchNotifications; topics = gToggleSecondaryNotices;
    };
    CHECK(![manager setIdentifierEnabledAndPersist:YES forType:@"WiFi"] && [latest isEqual:BatchSnapshot()] &&
          [cache isEqual:[manager persistenceCaches]] && notices == gBatchNotifications && topics + 1 == gToggleSecondaryNotices &&
          ![manager.settings[@"WiFi"] boolValue], "secondary rollback authority preserves foreign successor after legacy forward notification");

    for (NSUInteger cut = 1; cut <= 2; cut++) {
        manager = ToggleReentryFixture(); gToggleSecurityFailures = 1;
        NSUInteger publications = gToggleSecurityPublications; __block NSUInteger writes = 0;
        gDuringToggleSecurityWrite = ^{
            latest = BatchSnapshot(); [manager seedPersistenceCaches]; cache = [manager persistenceCaches];
            notices = gBatchNotifications; topics = gToggleSecondaryNotices;
            gStore.testCheckpoint = ^(NSString *stage) {
                if ([stage isEqual:@"source-written"] && ++writes == cut)
                    [NSException raise:@"fixture.rollback" format:@"atomic compensation fault"];
            };
        };
        BOOL success = [manager setIdentifierEnabledAndPersist:YES forType:@"WiFi"];
        gStore.testCheckpoint = nil;
        CHECK(!success && manager.error.code == 71 && writes == cut && [latest isEqual:BatchSnapshot()] &&
              [cache isEqual:[manager persistenceCaches]] && notices == gBatchNotifications && topics == gToggleSecondaryNotices &&
              publications == gToggleSecurityPublications && [manager.settings[@"WiFi"] boolValue],
              "conditional rollback physical fault restores complete forward tuple marker caches and notifications");
    }
    manager = ToggleReentryFixture(); other = [PXDeviceGroupFixture new]; other.settings = [manager.settings mutableCopy];
    gToggleSecurityFailures = 1; NSUInteger publications = gToggleSecurityPublications;
    gDuringToggleSecurityWrite = ^{
        gDuringRequiredNotification = ^{
            CHECK([other setIdentifierEnabledAndPersist:YES forType:@"WiFi"], "foreign successor during rollback notification commits");
            latest = BatchSnapshot(); notices = gBatchNotifications; topics = gToggleSecondaryNotices;
        };
    };
    CHECK(![manager setIdentifierEnabledAndPersist:YES forType:@"WiFi"] && [latest isEqual:BatchSnapshot()] &&
          notices == gBatchNotifications && topics == gToggleSecondaryNotices && publications == gToggleSecurityPublications,
          "rollback notification successor suppresses obsolete security mirror and topic");

    manager = ToggleReentryFixture(); manager.settings[@"StorageSystem"] = @NO; [manager saveSettings];
    id operation = [manager beginIdentifierToggleForType:@"StorageSystem"];
    NSString *identifier = nil; BOOL committed = NO; NSError *failure = nil;
    CHECK([manager applyIdentifierEnabled:YES forType:@"StorageSystem" operation:operation primaryCommitted:&committed sourceCommitIdentifier:&identifier error:&failure] && committed && identifier,
          "storage conditional rollback owns exact primary receipt");
    NSData *scope = [NSData dataWithContentsOfFile:PXGlobalScopePath()];
    [manager rollbackIdentifier:@"StorageSystem" previous:NO secondaryKey:nil notificationName:NULL operation:operation sourceCommitIdentifier:identifier];
    [manager finishIdentifierToggle:operation forType:@"StorageSystem"];
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:PXTLinkIOSSettingsPath()];
    CHECK(![settings[@"EnabledIdentifiers"][@"StorageSystem"] boolValue] && ![settings[@"StorageSystemEnabled"] boolValue] &&
          [scope isEqual:[NSData dataWithContentsOfFile:PXGlobalScopePath()]], "conditional rollback keeps storage alias atomic and never rewrites scope");
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
        TestDependencyLifecycle(manager, Identity(@"a"), Identity(@"b"));
        TestDashboardPreview(manager, Identity(@"a"), Identity(@"b"));
        TestTelephonyLifecycle(manager, Identity(@"a"), Identity(@"b"));
        TestTelephony(manager, Identity(@"a"), Identity(@"b"));
        TestExpectedActiveOwners(manager, Identity(@"a"), Identity(@"b"));
        TestExpectedPreviewPublication(Identity(@"a"), Identity(@"b"));
        TestExpectedGenerationPublication(Identity(@"a"), Identity(@"b"));
        TestRequiredIdentifiers(Identity(@"a"), Identity(@"b"));
        TestDashboardHardwareCapture(manager, Identity(@"a"), Identity(@"b"));
        TestStandaloneSettingsSaves(manager, Identity(@"a"));
        TestIdentifierToggleAcknowledgement();
        TestIdentifierToggleReentry();
        TestToggleFailedPrimaryOwnership();
        TestConditionalToggleRollback();
        gStore = nil;
        [NSFileManager.defaultManager removeItemAtPath:gRoot error:nil];
        printf("Runtime device group and telephony writers: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
