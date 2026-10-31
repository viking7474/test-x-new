#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#import "PXRuntimeArtifactPreparation.h"
#import "PXRuntimeArtifactWriter.h"
#import "PXRuntimeSourceStore.h"
#import "PXProfileArtifactMutation.h"
#import "PXProfileLifecycleLease.h"
#import "PXProfileDeletionJournal.h"
#import "PXIdentityValidator.h"
#import "PXPaths.h"
#import "TLinkIOSLogging.h"
#include <sys/sysctl.h>
#include <sys/time.h>
#include <stdlib.h>
#include <math.h>
#include <unistd.h>
#include <fcntl.h>

static NSUInteger gChecks, gFailures, gWrites, gBatterySaves, gDarwin, gLocal, gWiFiSaves;
static NSString *gRoot, *gOwnedBatteryMirrorPath;
static NSUInteger gOwnedBatteryLocal, gOwnedBatteryDarwin, gOwnedBatteryMirrors;
static void (^gDuringBatteryMirror)(NSDictionary *), (^gDuringBatteryNotice)(NSDictionary *);
static PXRuntimeSourceStore *gStore;
static NSArray<NSNumber *> *gTape;
static NSUInteger gTapeIndex;
static BOOL gHigh;
static NSUInteger gUptimeProviders, gStorageCopies, gWiFiSelections, gWiFiCopies, gWiFiReloads;
static NSUInteger gStorageModelCalls, gStorageActiveReads;
static NSDictionary *gStorageModelRows, *gStorageModelSpecs;
static id gStorageFallbackSpecs;
static NSString *gLastStorageModel;
static BOOL gWiFiManagerAvailable = YES;
static NSString *gWiFiMemoryID;
static void (^gDuringWiFiCopy)(void), (^gDuringWiFiWarmup)(void);
static void (^gDuringUptime)(void), (^gDuringStorageCopy)(void), (^gDuringLog)(void);
#define CHECK(value, message) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", message); } } while (0)
uint32_t PXPreparationFixtureRandom(uint32_t bound) {
    CHECK(bound > 0, "random preparation has bounded nonzero input");
    if (!bound) return 0;
    if (gTapeIndex < gTape.count) {
        uint32_t value = gTape[gTapeIndex++].unsignedIntValue;
        CHECK(value < bound, "fixture random tape matches production bound");
        return value % bound;
    }
    return gHigh ? bound - 1 : 0;
}
static void Tape(NSArray<NSNumber *> *values) { gTape = values; gTapeIndex = 0; gHigh = NO; }
static NSString *Path(NSString *root, NSString *name) { return [root stringByAppendingPathComponent:name]; }
NSString *PXProfilesPath(void) { return gRoot; }
NSString *PXCurrentProfileInfoPath(void) { return Path(gRoot, @"current_profile_info.plist"); }
NSString *PXTLinkIOSSettingsPath(void) { return Path(gRoot, @"tlink_settings.plist"); }
NSString *PXLegacyActiveProfileInfoPath(void) { return Path(gRoot, @"legacy_selection.plist"); }
NSString *PXActiveProfileID(void) {
    gStorageActiveReads++;
    NSDictionary *selection = [NSDictionary dictionaryWithContentsOfFile:PXCurrentProfileInfoPath()];
    NSString *profile = PXValidatedProfileID(selection[@"ProfileId"]);
    if (profile) return profile;
    selection = [NSDictionary dictionaryWithContentsOfFile:PXLegacyActiveProfileInfoPath()];
    return PXValidatedProfileID(selection[@"ProfileId"]) ?: PXValidatedProfileID(selection[@"currentProfileId"]);
}
NSString *PXProfileDeletionJournalPath(void) { return Path(gRoot, @".profile-delete-journal.plist"); }
NSString *PXValidatedProfileID(id value) {
    return [value isKindOfClass:NSString.class] && [@[@"a", @"b", @"c"] containsObject:value] ? [value copy] : nil;
}
NSString *PXProfileRootPath(NSString *profile) { return PXValidatedProfileID(profile) ? Path(gRoot, profile) : nil; }
NSString *PXProfileIdentityPath(NSString *profile) {
    NSString *root = PXProfileRootPath(profile);
    return root ? Path(root, @"identity") : nil;
}
BOOL PXPerformRuntimeSourceWrite(BOOL (^body)(PXRuntimeSourceTransaction *, NSError **), NSError **error) {
    gWrites++; return [gStore performWrite:body error:error];
}
BOOL PXPerformStandaloneRuntimeSourceWrite(BOOL (^body)(PXRuntimeSourceTransaction *, NSError **), NSError **error) {
    gWrites++; return [gStore performStandaloneWrite:body error:error];
}
void PXLog(NSString *format, ...) { (void)format; if (gDuringLog) gDuringLog(); }
static NSDictionary *IDs(void) { return [NSDictionary dictionaryWithContentsOfFile:Path(PXProfileIdentityPath(@"a"), @"device_ids.plist")] ?: @{}; }
static NSDictionary *Capture(void) {
    return [gStore capture:^NSDictionary *(NSError **error) {
        (void)error;
        NSMutableDictionary *files = [NSMutableDictionary dictionary];
        NSString *profile = Path(gRoot, @"a");
        for (NSString *relative in [NSFileManager.defaultManager subpathsAtPath:profile])
            if ([relative hasSuffix:@".plist"]) files[relative] = [NSData dataWithContentsOfFile:Path(profile, relative)];
        return @{ @"files": files };
    } error:NULL];
}

@interface PXPreparedWiFiFixture : NSObject
@property (nonatomic, strong) NSMutableDictionary *wifiInfo;
@property (nonatomic, strong) NSString *currentProfileId;
@property (nonatomic, strong) NSError *error;
- (NSDictionary *)generateWiFiInfo;
- (void)saveWiFiInfoToCurrentProfile;
- (void)adoptCommittedWiFiInfo:(NSDictionary *)wifiInfo profileID:(NSString *)profileID;
@end
@implementation PXPreparedWiFiFixture
- (void)saveWiFiInfoToCurrentProfile { gWiFiSaves++; CHECK(self.wifiInfo.count == 6, "WiFi cache ready before legacy save"); }
#include "PXPreparedWiFiMethod.inc"
@end

static void PXFixtureDarwin(CFNotificationCenterRef center, CFStringRef name, const void *object, CFDictionaryRef info, Boolean immediate) {
    (void)center; (void)name; (void)object; (void)info; (void)immediate;
    gDarwin++; CHECK(gBatterySaves == 1, "Darwin notification follows single batch save");
}
@interface PXPreparedBatteryFixture : NSObject {
    NSString *_currentBatteryLevel;
    BOOL _currentLowPowerMode;
    BOOL _lowPowerModeLoaded;
}
@property (nonatomic, strong) NSError *error;
- (NSDictionary *)generateBatteryInfo;
- (NSString *)randomizeBatteryLevel;
- (void)saveBatteryInfoToDisk;
- (void)setFixtureLowPowerMode:(BOOL)value;
- (NSString *)fixtureLevel;
- (BOOL)persistBatteryRecord:(NSDictionary *)record;
- (NSDictionary *)batteryRecordForLevel:(NSString *)level lowPowerMode:(BOOL)enabled;
- (BOOL)mirrorBatteryRecord:(NSDictionary *)record error:(NSError **)error;
- (void)adoptCommittedBatteryInfo:(NSDictionary *)batteryInfo;
- (void)publishCommittedBatteryInfo:(NSDictionary *)batteryInfo timestamp:(NSDate *)timestamp;
@end
@implementation PXPreparedBatteryFixture
- (void)saveBatteryInfoToDisk { gBatterySaves++; CHECK(_currentBatteryLevel.length > 0, "battery cache ready before legacy save"); }
- (void)setFixtureLowPowerMode:(BOOL)value { _currentLowPowerMode = value; }
- (NSString *)fixtureLevel { return _currentBatteryLevel; }
- (BOOL)persistBatteryRecord:(NSDictionary *)record {
    gBatterySaves++;
    CHECK([record[@"BatteryLevel"] isEqual:_currentBatteryLevel] && [record[@"LastUpdated"] isKindOfClass:NSDate.class], "battery wrapper persists captured record once");
    return YES;
}
// Notification delivery is a fixture backend; do not broadcast production IPC.
#define CFNotificationCenterPostNotification PXFixtureDarwin
#define CFNotificationCenterGetDarwinNotifyCenter() NULL
#define kBatteryLevelKey @"BatteryLevel"
#define kLowPowerModeKey @"LowPowerMode"
#define kLastUpdatedKey @"LastUpdated"
#define BATTERY_PLIST_PATH Path(gRoot, @"legacy-battery.plist")
#include "PXPreparedBatteryMethods.inc"
#undef BATTERY_PLIST_PATH
#undef kLastUpdatedKey
#undef kLowPowerModeKey
#undef kBatteryLevelKey
#undef CFNotificationCenterGetDarwinNotifyCenter
#undef CFNotificationCenterPostNotification
@end

@interface PXStorageSnapshotFixture : NSObject <NSCopying>
@property (nonatomic, copy) NSDictionary *record;
@end
@implementation PXStorageSnapshotFixture
- (id)copyWithZone:(NSZone *)zone {
    (void)zone; gStorageCopies++;
    NSDictionary *snapshot = [self.record copy];
    void (^callback)(void) = gDuringStorageCopy; gDuringStorageCopy = nil; if (callback) callback();
    return snapshot;
}
@end

// Storage flag mirrors never reach the host user's preferences service.
static NSUInteger gStoragePreferenceMirrors, gStoragePreferenceFlushes;
static BOOL gStoragePreferenceMirrorThrows;
static NSString *gStoragePreferenceMirrorSuite, *gStoragePreferenceMirrorKey;
static NSNumber *gStoragePreferenceMirrorValue;
static void (^gDuringStoragePreferenceMirror)(void);
@interface PXStoragePreferenceDefaultsFixture : NSObject
- (instancetype)initWithSuiteName:(NSString *)suite;
- (void)setBool:(BOOL)value forKey:(NSString *)key;
- (BOOL)synchronize;
@end
@implementation PXStoragePreferenceDefaultsFixture
- (instancetype)initWithSuiteName:(NSString *)suite {
    if ((self = [super init])) gStoragePreferenceMirrorSuite = [suite copy]; return self;
}
- (void)setBool:(BOOL)value forKey:(NSString *)key {
    gStoragePreferenceMirrors++; gStoragePreferenceMirrorKey = [key copy]; gStoragePreferenceMirrorValue = @(value);
    void (^callback)(void) = gDuringStoragePreferenceMirror; gDuringStoragePreferenceMirror = nil;
    if (callback) callback();
    if (gStoragePreferenceMirrorThrows) [NSException raise:@"fixture.storage-mirror" format:@"mirror failure"];
}
- (BOOL)synchronize { gStoragePreferenceFlushes++; return YES; }
@end

@interface IPhoneModelDB : NSObject
+ (instancetype)sharedManager;
- (NSDictionary *)specForProductType:(NSString *)product;
- (NSDictionary *)canonicalHardwareSpecForProductType:(NSString *)product;
@end
@implementation IPhoneModelDB
+ (instancetype)sharedManager { gStorageModelCalls++; return [self new]; }
- (NSDictionary *)specForProductType:(NSString *)product { gLastStorageModel = [product copy]; return product ? gStorageModelRows[product] : nil; }
- (NSDictionary *)canonicalHardwareSpecForProductType:(NSString *)product { return product ? gStorageModelSpecs[product] : nil; }
@end
@interface DeviceModelManager : NSObject
+ (instancetype)sharedManager;
- (NSDictionary *)deviceSpecificationsForModel:(NSString *)product;
@end
@implementation DeviceModelManager
+ (instancetype)sharedManager { return [self new]; }
- (NSDictionary *)deviceSpecificationsForModel:(NSString *)product { (void)product; return gStorageFallbackSpecs; }
@end
#include "PXStorageReadHelpers.inc"
@interface PXPreparedStorageFixture : NSObject {
    NSMutableDictionary *_storageSettings;
    BOOL _isEnabled;
    BOOL _storagePreferenceWriteInFlight;
}
- (NSDictionary *)generateStorageForCapacity:(NSString *)capacity;
- (void)adoptCommittedStorageInfo:(NSDictionary *)storageInfo;
- (NSDictionary *)fixtureStorage;
- (NSDictionary *)currentStorageInfo;
- (BOOL)commitDisplayStorageInfo:(NSDictionary *)values updateFilesystem:(BOOL)updateFilesystem error:(NSError **)error;
- (void)setFixtureSnapshot:(NSDictionary *)record;
- (void)saveToCurrentProfile;
- (void)saveToProfile:(NSString *)profileId;
- (BOOL)persistStorageToProfile:(NSString *)profileID current:(BOOL)current error:(NSError **)error;
- (void)setTotalStorageCapacity:(NSString *)capacity;
- (void)setFreeStorageSpace:(NSString *)freeSpace;
- (void)setFilesystemType:(NSString *)fsType;
- (BOOL)isStorageSpoofingEnabled;
- (void)setStorageSpoofingEnabled:(BOOL)enabled;
- (BOOL)setStorageSpoofingEnabled:(BOOL)enabled error:(NSError **)error;
#include "PXStorageReadDeclarations.inc"
@end
#define NSUserDefaults PXStoragePreferenceDefaultsFixture
@implementation PXPreparedStorageFixture
- (NSDictionary *)fixtureStorage { return _storageSettings; }
- (void)setFixtureSnapshot:(NSDictionary *)record {
    PXStorageSnapshotFixture *spy = [PXStorageSnapshotFixture new]; spy.record = record; _storageSettings = (id)spy;
}
#include "PXPreparedStorageMethod.inc"
@end
#undef NSUserDefaults

@interface PXPreparedUptimeFixture : NSObject
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSDate *bootTimeValue;
@property (nonatomic) NSTimeInterval uptimeValue;
@property (nonatomic, strong) NSDate *cacheTime;
- (void)generateConsistentUptimeAndBootTimeForProfile:(NSString *)path;
- (NSDictionary *)prepareConsistentUptimeInfo;
- (NSTimeInterval)currentUptimeForProfile:(NSString *)path;
- (NSDate *)currentBootTimeForProfile:(NSString *)path;
- (NSTimeInterval)currentUptimeForProfile:(NSString *)path generateIfMissing:(BOOL)generateIfMissing;
- (NSDate *)currentBootTimeForProfile:(NSString *)path generateIfMissing:(BOOL)generateIfMissing;
- (void)adoptCommittedUptimeInfo:(NSDictionary *)uptimeInfo timestamp:(NSDate *)timestamp;
@end
static int PXPreparationFixtureSysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    gUptimeProviders++;
    void (^callback)(void) = gDuringUptime; gDuringUptime = nil; if (callback) callback();
    return sysctl(name, namelen, oldp, oldlenp, newp, newlen);
}
@implementation PXPreparedUptimeFixture
#define sysctl PXPreparationFixtureSysctl
#include "PXPreparedUptimeMethod.inc"
#undef sysctl
@end

// The real optional ProfileManager is not linked into this Foundation fixture.
// Observe the singleton/current-profile seam without copying its lifecycle code.
@interface PXWiFiProfileFixture : NSObject
@property (nonatomic, copy) NSString *profileId;
@end
@implementation PXWiFiProfileFixture
@end
@interface ProfileManager : NSObject
+ (instancetype)sharedManager;
- (id)currentProfile;
@end
@implementation ProfileManager
+ (instancetype)sharedManager {
    if (gDuringWiFiWarmup) gDuringWiFiWarmup();
    if (!gWiFiManagerAvailable) return nil;
    static ProfileManager *manager; static dispatch_once_t once;
    dispatch_once(&once, ^{ manager = [self new]; }); return manager;
}
- (id)currentProfile {
    gWiFiSelections++;
    id selected = gWiFiMemoryID ?: [NSDictionary dictionaryWithContentsOfFile:PXCurrentProfileInfoPath()][@"ProfileId"];
    if (![selected isKindOfClass:NSString.class]) return nil;
    PXWiFiProfileFixture *profile = [PXWiFiProfileFixture new]; profile.profileId = selected; return profile;
}
@end
@interface PXWiFiSnapshotFixture : NSObject <NSCopying>
@property (nonatomic, copy) NSDictionary *record;
@end
@implementation PXWiFiSnapshotFixture
- (id)copyWithZone:(NSZone *)zone {
    (void)zone; gWiFiCopies++;
    NSDictionary *snapshot = [self.record copy];
    void (^callback)(void) = gDuringWiFiCopy; gDuringWiFiCopy = nil; if (callback) callback();
    return snapshot;
}
@end
@interface PXOwnedWiFiFixture : NSObject
@property (nonatomic, strong) NSMutableDictionary *wifiInfo;
@property (nonatomic, strong) NSString *currentProfileId;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) id profileChangeObserver;
- (void)registerForProfileNotifications;
- (id)profileManagerForWiFi;
- (NSString *)getCurrentProfileID;
- (NSString *)profileIDFromManager:(id)manager;
- (void)loadWiFiInfoFromCurrentProfile;
- (void)loadWiFiInfoForProfileID:(NSString *)profileID;
- (void)saveWiFiInfoToCurrentProfile;
- (NSDictionary *)generateWiFiInfo;
- (void)adoptCommittedWiFiInfo:(NSDictionary *)wifiInfo profileID:(NSString *)profileID;
- (NSDictionary *)currentWiFiInfo;
- (void)setCurrentWiFiInfo:(NSDictionary *)wifiInfo;
- (BOOL)isValidSSID:(NSString *)ssid;
- (BOOL)isValidBSSID:(NSString *)bssid;
@end
@implementation PXOwnedWiFiFixture
#include "PXOwnedWiFiMethods.inc"
@end
@interface PXObservedWiFiFixture : PXOwnedWiFiFixture
@end
@implementation PXObservedWiFiFixture
- (void)loadWiFiInfoForProfileID:(NSString *)profileID {
    gWiFiReloads++; [super loadWiFiInfoForProfileID:profileID];
}
@end

static void CheckArtifactLeaseFree(void);
static void PXOwnedBatteryDarwin(CFNotificationCenterRef center, CFStringRef name, const void *object, CFDictionaryRef info, Boolean immediate) {
    (void)center; (void)name; (void)object; (void)info; (void)immediate; gOwnedBatteryDarwin++; CheckArtifactLeaseFree();
}
@interface PXOwnedBatteryFixture : NSObject {
    NSString *_currentBatteryLevel;
    BOOL _currentLowPowerMode, _lowPowerModeLoaded;
}
@property (nonatomic, strong) NSError *error;
- (NSString *)batteryLevel;
- (void)setBatteryLevel:(NSString *)level;
- (NSString *)generateBatteryLevel;
- (NSString *)randomizeBatteryLevel;
- (BOOL)lowPowerModeEnabled;
- (void)setLowPowerModeEnabled:(BOOL)enabled;
- (NSDictionary *)generateBatteryInfo;
- (void)adoptCommittedBatteryInfo:(NSDictionary *)batteryInfo;
- (void)publishCommittedBatteryInfo:(NSDictionary *)batteryInfo timestamp:(NSDate *)timestamp;
- (NSError *)lastError;
- (NSString *)batteryInfoPathForCurrentProfile;
- (void)loadBatteryInfoFromDisk;
- (void)saveBatteryInfoToDisk;
- (NSDictionary *)batteryRecordForLevel:(NSString *)level lowPowerMode:(BOOL)enabled;
- (BOOL)persistBatteryRecord:(NSDictionary *)record;
- (BOOL)mirrorBatteryRecord:(NSDictionary *)record error:(NSError **)error;
@end
@implementation PXOwnedBatteryFixture
- (instancetype)init { if ((self = [super init])) _currentBatteryLevel = @"0.75"; return self; }
#define CFNotificationCenterPostNotification PXOwnedBatteryDarwin
#define CFNotificationCenterGetDarwinNotifyCenter() NULL
#define kBatteryLevelKey @"BatteryLevel"
#define kLowPowerModeKey @"LowPowerMode"
#define kLastUpdatedKey @"LastUpdated"
#define BATTERY_PLIST_PATH gOwnedBatteryMirrorPath
#include "PXOwnedBatteryMethods.inc"
#undef BATTERY_PLIST_PATH
#undef kLastUpdatedKey
#undef kLowPowerModeKey
#undef kBatteryLevelKey
#undef CFNotificationCenterGetDarwinNotifyCenter
#undef CFNotificationCenterPostNotification
@end
@interface PXObservedBatteryFixture : PXOwnedBatteryFixture
@end
@implementation PXObservedBatteryFixture
- (BOOL)mirrorBatteryRecord:(NSDictionary *)record error:(NSError **)error {
    gOwnedBatteryMirrors++;
    if (gDuringBatteryMirror) gDuringBatteryMirror(record);
    return [super mirrorBatteryRecord:record error:error];
}
@end

static void TestPurePreparation(void) {
    NSDictionary *before = Capture(); NSUInteger writes = gWrites;
    for (NSUInteger mode = 0; mode < 2; mode++) {
        Tape(@[]); gHigh = mode == 1;
        NSDate *start = NSDate.date;
        NSDictionary *wifi = PXPrepareRuntimeWiFiInfo();
        NSDate *finish = NSDate.date, *connection = wifi[@"lastConnectionTime"];
        CHECK(wifi.count == 6 && [wifi[@"ssid"] length] > 0 && PXValidateIdentityValue(wifi[@"bssid"], PXIdentityValueKindMACAddress, NO), "prepared WiFi retains schema and valid MAC");
        CHECK(connection.timeIntervalSince1970 >= start.timeIntervalSince1970 - 86401 && connection.timeIntervalSince1970 <= finish.timeIntervalSince1970 + 1,
              "WiFi past connection time cannot unsigned wrap");
        CHECK(![wifi isKindOfClass:NSMutableDictionary.class], "prepared WiFi dictionary is immutable");
    }
    NSArray *tapes = @[@[@0, @0], @[@59, @50], @[@60, @0], @[@79, @20], @[@80, @0], @[@94, @15], @[@95, @0], @[@99, @10]];
    NSArray *levels = @[@"0.30", @"0.80", @"0.80", @"1.00", @"0.15", @"0.30", @"0.05", @"0.15"];
    for (NSUInteger i = 0; i < tapes.count; i++) { Tape(tapes[i]); CHECK([PXPrepareRuntimeBatteryLevel() isEqual:levels[i]], "battery weighted buckets retain endpoint policy"); }
    Tape(@[@0, @0]); NSDictionary *battery = PXPrepareRuntimeBatteryInfo(YES);
    CHECK([battery[@"BatteryLevel"] isEqual:@"0.30"] && [battery[@"BatteryPercentage"] isEqual:@30] && [battery[@"LowPowerMode"] boolValue], "battery record retains preserved LPM and percentage schema");
    Tape(@[@0, @0]); NSDictionary *storage = PXPrepareRuntimeStorage(@"64");
    CHECK([storage[@"TotalStorage"] isEqual:@"64"] && [storage[@"FreeStorage"] isEqual:@"9.6"] && [storage[@"FilesystemType"] isEqual:@"0x1A"], "storage preparation preserves low capacity distribution and units");
    Tape(@[@14, @9]); storage = PXPrepareRuntimeStorage(@"128");
    CHECK([storage[@"FreeStorage"] isEqual:@"50.8"], "storage preparation preserves high capacity rounding");
    for (id capacity in @[NSNull.null, @"", @"bad", @"0", @"-64", @"nan", @"inf", @"1e308"])
        CHECK(PXPrepareRuntimeStorage(capacity == NSNull.null ? nil : capacity) == nil, "storage rejects unsafe capacity before staging");
    Tape(@[@14, @9]); CHECK(PXPrepareRuntimeStorage(@"0.1") == nil, "unphysical free space is rejected instead of persisted");
    NSMutableString *capacity = [@"64" mutableCopy]; Tape(@[@0, @0]); storage = PXPrepareRuntimeStorage(capacity); [capacity setString:@"changed"];
    CHECK([storage[@"TotalStorage"] isEqual:@"64"] && ![storage isKindOfClass:NSMutableDictionary.class], "prepared storage detaches mutable caller input");
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:500000];
    Tape(@[]); gHigh = YES;
    NSDictionary *uptime = PXPrepareRuntimeUptime(now, 18 * 3600, YES);
    CHECK([uptime[@"seconds"] doubleValue] == 18 * 3600 - 60 &&
          [[uptime[@"boot"] objectForKey:@"lastUpdated"] isEqual:now] && [[uptime[@"uptime"] objectForKey:@"lastUpdated"] isEqual:now] &&
          fabs([now timeIntervalSinceDate:uptime[@"boot"][@"value"]] - [uptime[@"seconds"] doubleValue]) < 0.001, "uptime uses one clock sample and real uptime cap");
    uptime = PXPrepareRuntimeUptime(now, 6 * 3600, YES);
    CHECK([uptime[@"seconds"] doubleValue] == 12 * 3600, "uptime preserves legacy minimum over real uptime");
    uptime = PXPrepareRuntimeUptime(now, 0, NO);
    CHECK([uptime[@"seconds"] doubleValue] >= 12 * 3600 && [uptime[@"seconds"] doubleValue] < 48 * 3600 + 45 * 60 &&
          [uptime[@"boot"][@"version"] isEqual:@1] && [uptime[@"uptime"][@"value"] isKindOfClass:NSString.class], "uptime extra random interval and persisted types retained");
    CHECK(gWrites == writes && gBatterySaves == 0 && gWiFiSaves == 0 && gDarwin == 0 && [before isEqual:Capture()], "preparation never writes sources initializes managers or sends notifications");
    Tape(@[]);
}
static void TestManagerWrappers(void) {
    Tape(@[]); PXPreparedWiFiFixture *wifi = [PXPreparedWiFiFixture new];
    NSDictionary *returned = [wifi generateWiFiInfo];
    NSString *ssid = returned[@"ssid"]; wifi.wifiInfo[@"ssid"] = @"edited";
    CHECK(gWiFiSaves == 1 && [returned[@"ssid"] isEqual:ssid] && [wifi.wifiInfo isKindOfClass:NSMutableDictionary.class], "WiFi wrapper keeps detached result and mutable cache");
    PXPreparedBatteryFixture *battery = [PXPreparedBatteryFixture new];
    [battery setFixtureLowPowerMode:YES];
    id observer = [NSNotificationCenter.defaultCenter addObserverForName:@"BatteryInfoUpdated" object:battery queue:nil usingBlock:^(NSNotification *note) {
        gLocal++; CHECK(gBatterySaves == 1 && [note.userInfo[@"LowPowerMode"] boolValue], "local notification follows one save and keeps LPM");
    }];
    NSDictionary *info = [battery generateBatteryInfo];
    CHECK(gBatterySaves == 1 && gLocal == 1 && gDarwin == 1 && [[battery fixtureLevel] isEqual:info[@"BatteryLevel"]], "battery batch saves once before notifications");
    [NSNotificationCenter.defaultCenter removeObserver:observer];
    gBatterySaves = 0; gDarwin = 0;
    CHECK([battery randomizeBatteryLevel] != nil && gBatterySaves == 1 && gDarwin == 0, "standalone battery level still saves once without batch notification");
    PXPreparedStorageFixture *storage = [PXPreparedStorageFixture new];
    CHECK([storage generateStorageForCapacity:@"64"] != nil && [storage generateStorageForCapacity:nil] == nil, "storage manager delegates preparation and rejects nil safely");
    NSUInteger writes = gWrites, saves = gBatterySaves, wifiSaves = gWiFiSaves, darwin = gDarwin;
    NSDictionary *before = Capture(); NSDate *now = [NSDate dateWithTimeIntervalSince1970:1700000000];
    [wifi adoptCommittedWiFiInfo:returned profileID:@"a"];
    [battery adoptCommittedBatteryInfo:info];
    NSDictionary *storageInfo = PXPrepareRuntimeStorage(@"128");
    [storage adoptCommittedStorageInfo:storageInfo];
    PXPreparedUptimeFixture *uptime = [PXPreparedUptimeFixture new];
    NSDictionary *uptimeInfo = PXPrepareRuntimeUptime(now, 0, NO);
    [uptime adoptCommittedUptimeInfo:uptimeInfo timestamp:now];
    CHECK(gWrites == writes && gBatterySaves == saves && gWiFiSaves == wifiSaves && darwin == gDarwin && [before isEqual:Capture()] &&
          [wifi.currentProfileId isEqual:@"a"] && [[battery fixtureLevel] isEqual:info[@"BatteryLevel"]] &&
          [[storage fixtureStorage] isEqual:storageInfo] && [[storage currentStorageInfo] isEqual:storageInfo] && [uptime.cacheTime isEqual:now] &&
          [uptime.bootTimeValue isEqual:uptimeInfo[@"boot"][@"value"]], "committed artifact adoption updates caches without autosave or notifications");
    [battery publishCommittedBatteryInfo:info timestamp:now];
    NSDictionary *mirror = [NSDictionary dictionaryWithContentsOfFile:Path(gRoot, @"legacy-battery.plist")];
    CHECK(gDarwin == darwin + 1 && gWrites == writes && [before isEqual:Capture()] && [mirror[@"LastUpdated"] isEqual:now] &&
          [mirror[@"BatteryLevel"] isEqual:info[@"BatteryLevel"]], "committed battery publisher mirrors and notifies without selecting or saving a profile");
    Tape(@[]);
    CHECK([PXChooseRuntimeStorageCapacity(@[@128, @256], @"128") isEqual:@"256"] &&
          [PXChooseRuntimeStorageCapacity(@[@128], @"128") isEqual:@"128"] &&
          [PXChooseRuntimeStorageCapacity(@[@0, @"bad"], nil) isEqual:@"64"], "storage capacity selector retains tiers previous avoidance and fallback policy");
}
static void TestCompositionAndUptime(void) {
    Tape(@[]);
    NSString *identity = PXProfileIdentityPath(@"a"); NSDate *now = NSDate.date;
    NSDictionary *wifi = PXPrepareRuntimeWiFiInfo(), *batteryUI = PXPrepareRuntimeBatteryInfo(YES);
    NSDictionary *battery = @{ @"BatteryLevel": batteryUI[@"BatteryLevel"], @"LowPowerMode": batteryUI[@"LowPowerMode"], @"LastUpdated": now };
    NSDictionary *uptime = PXPrepareRuntimeUptime(now, 0, NO), *storage = PXPrepareRuntimeStorage(@"128");
    BOOL (^stages)(PXRuntimeSourceTransaction *, NSError **) = ^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return PXStageRuntimeWiFi(tx, identity, wifi, error) && PXStageRuntimeBattery(tx, identity, battery, error) &&
            PXStageRuntimeUptime(tx, identity, uptime[@"boot"], uptime[@"uptime"], now, error) &&
            [tx setDictionary:storage atPath:Path(Path(gRoot, @"a"), @"storage.plist") error:error];
    };
    NSUInteger writes = gWrites;
    CHECK(PXPerformRuntimeSourceWrite(stages, NULL) && gWrites == writes + 1 && [IDs()[@"SSID"] isEqual:wifi[@"ssid"]] &&
          [IDs()[@"LowPowerMode"] boolValue] && [IDs()[@"SystemUptime"] isEqual:uptime[@"uptime"][@"value"]] && [IDs()[@"keep"] boolValue], "all prepared artifacts commit together and preserve unrelated fields");
    NSDictionary *before = Capture();
    Tape(@[]); gHigh = YES;
    NSDictionary *nextWiFi = PXPrepareRuntimeWiFiInfo(), *nextUI = PXPrepareRuntimeBatteryInfo(NO);
    NSDate *nextClock = [now dateByAddingTimeInterval:600];
    NSDictionary *nextBattery = @{ @"BatteryLevel": nextUI[@"BatteryLevel"], @"LowPowerMode": nextUI[@"LowPowerMode"], @"LastUpdated": nextClock };
    NSDictionary *nextUptime = PXPrepareRuntimeUptime(nextClock, 0, NO), *nextStorage = PXPrepareRuntimeStorage(@"256");
    BOOL (^differentStages)(PXRuntimeSourceTransaction *, NSError **) = ^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return PXStageRuntimeWiFi(tx, identity, nextWiFi, error) && PXStageRuntimeBattery(tx, identity, nextBattery, error) &&
            PXStageRuntimeUptime(tx, identity, nextUptime[@"boot"], nextUptime[@"uptime"], nextClock, error) &&
            [tx setDictionary:nextStorage atPath:Path(Path(gRoot, @"a"), @"storage.plist") error:error];
    };
    __block NSUInteger changed = 0;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"] && ++changed == 2) [NSException raise:@"fixture" format:@"prepared group failure"]; };
    CHECK(!PXPerformRuntimeSourceWrite(differentStages, NULL), "prepared artifact commit failure propagated");
    gStore.testCheckpoint = nil;
    CHECK([before isEqual:Capture()], "prepared artifact failure rolls back entire tuple and commit identity");
    PXPreparedUptimeFixture *manager = [PXPreparedUptimeFixture new];
    [manager generateConsistentUptimeAndBootTimeForProfile:identity];
    CHECK(manager.error == nil && manager.bootTimeValue != nil && manager.uptimeValue > 0, "uptime production wrapper commits then fills cache");
    NSDate *previous = manager.bootTimeValue, *previousClock = manager.cacheTime; before = Capture(); changed = 0;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"] && ++changed == 1) [NSException raise:@"fixture" format:@"uptime failure"]; };
    [manager generateConsistentUptimeAndBootTimeForProfile:identity]; gStore.testCheckpoint = nil;
    CHECK(manager.error != nil && manager.bootTimeValue == previous && manager.cacheTime == previousClock && [before isEqual:Capture()], "uptime cache changes only after commit");
}

static NSDictionary *AllArtifactFiles(void) {
    return [gStore capture:^NSDictionary *(NSError **error) {
        (void)error; NSMutableDictionary *files = [NSMutableDictionary dictionary];
        for (NSString *relative in [NSFileManager.defaultManager subpathsAtPath:gRoot])
            if (![relative hasPrefix:@"control/"] && [relative hasSuffix:@".plist"])
                files[relative] = [NSData dataWithContentsOfFile:Path(gRoot, relative)];
        return @{ @"files": files };
    } error:NULL];
}
static BOOL PXSeedStoragePreferences(NSDictionary *settings) {
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx setDictionary:settings atPath:PXTLinkIOSSettingsPath() error:error];
    } error:NULL];
}
static NSDictionary *PXStoragePreferences(void) { return [NSDictionary dictionaryWithContentsOfFile:PXTLinkIOSSettingsPath()]; }

static void TestStoragePreferenceWriters(void) {
    PXPreparedStorageFixture *manager = [PXPreparedStorageFixture new]; NSError *error = nil;
    NSDictionary *baseline = @{ @"keep": @YES, @"EnabledIdentifiers": @{ @"StorageSystem": @NO } };
    CHECK(PXSeedStoragePreferences(baseline) && ![manager isStorageSpoofingEnabled], "storage preference baseline and cache seeded");
    __block NSUInteger commits = 0;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"commit-written"]) commits++; };
    gDuringStoragePreferenceMirror = ^{
        CHECK(AllArtifactFiles() && [manager isStorageSpoofingEnabled] && [PXStoragePreferences()[@"StorageSystemEnabled"] boolValue],
            "storage flag mirror observes committed source and cache after source unlock");
        NSError *busy = nil; NSUInteger writes = gWrites;
        CHECK(![manager setStorageSpoofingEnabled:NO error:&busy] && busy.code == 1 && writes == gWrites,
            "storage mirror reentry fails busy before source entry without deadlock");
    };
    NSUInteger notices = gDarwin + gLocal, mirrors = gStoragePreferenceMirrors, flushes = gStoragePreferenceFlushes;
    CHECK([manager setStorageSpoofingEnabled:YES error:&error] && !error && commits == 1 && gStoragePreferenceMirrors == mirrors + 1 &&
        gStoragePreferenceFlushes == flushes + 1 && [gStoragePreferenceMirrorSuite isEqual:@"com.hydra.tlinkios.settings"] &&
        [gStoragePreferenceMirrorKey isEqual:@"StorageSystemEnabled"] && gStoragePreferenceMirrorValue.boolValue &&
        [PXStoragePreferences()[@"keep"] boolValue] && ![PXStoragePreferences()[@"EnabledIdentifiers"][@"StorageSystem"] boolValue] &&
        notices == gDarwin + gLocal, "storage flag commit preserves unrelated primary toggle and legacy mirror scope without notifications");
    gStore.testCheckpoint = nil;

    NSDictionary *before = AllArtifactFiles(); mirrors = gStoragePreferenceMirrors;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"]) [NSException raise:@"fixture" format:@"storage preference fault"]; };
    CHECK(![manager setStorageSpoofingEnabled:NO error:&error] && error && [manager isStorageSpoofingEnabled] &&
        mirrors == gStoragePreferenceMirrors && [before isEqual:AllArtifactFiles()], "failed storage flag commit preserves source cache and mirrors");
    gStore.testCheckpoint = nil;
    CHECK([manager setStorageSpoofingEnabled:NO error:&error] && !error && ![manager isStorageSpoofingEnabled],
        "storage writer admission is released after source failure");
    [manager setStorageSpoofingEnabled:YES];
    CHECK([manager isStorageSpoofingEnabled] && [PXStoragePreferences()[@"StorageSystemEnabled"] boolValue], "legacy void storage setter uses verified commit");

    gStoragePreferenceMirrorThrows = YES;
    CHECK([manager setStorageSpoofingEnabled:NO error:&error] && !error && ![manager isStorageSpoofingEnabled] &&
        ![PXStoragePreferences()[@"StorageSystemEnabled"] boolValue], "storage mirror exception does not negate primary commit or cache adoption");
    gStoragePreferenceMirrorThrows = NO;
    CHECK([manager setStorageSpoofingEnabled:YES error:&error], "storage admission is released after mirror exception");

    before = AllArtifactFiles(); mirrors = gStoragePreferenceMirrors;
    CHECK(![gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        (void)tx; return [manager setStorageSpoofingEnabled:NO error:writeError];
    } error:&error] && error && mirrors == gStoragePreferenceMirrors && [manager isStorageSpoofingEnabled] &&
        [before isEqual:AllArtifactFiles()], "nested storage high-level writer rejects before cache and mirror effects");

    CHECK([NSFileManager.defaultManager removeItemAtPath:PXTLinkIOSSettingsPath() error:NULL], "missing storage preference source prepared");
    before = AllArtifactFiles(); mirrors = gStoragePreferenceMirrors;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"]) [NSException raise:@"fixture" format:@"storage preference absence"]; };
    CHECK(![manager setStorageSpoofingEnabled:NO error:&error] && error && [before isEqual:AllArtifactFiles()] &&
        [manager isStorageSpoofingEnabled] && mirrors == gStoragePreferenceMirrors, "storage flag rollback preserves original source absence");
    gStore.testCheckpoint = nil;
    CHECK([manager setStorageSpoofingEnabled:NO error:&error] && !error && PXStoragePreferences().count == 1 && ![manager isStorageSpoofingEnabled],
        "missing storage preference source commits only the legacy key");
    NSData *corrupt = [@"not a plist" dataUsingEncoding:NSUTF8StringEncoding];
    CHECK([corrupt writeToFile:PXTLinkIOSSettingsPath() atomically:YES], "corrupt storage preference source installed");
    mirrors = gStoragePreferenceMirrors; before = AllArtifactFiles();
    [manager setStorageSpoofingEnabled:YES];
    CHECK(![manager isStorageSpoofingEnabled] && mirrors == gStoragePreferenceMirrors && [before isEqual:AllArtifactFiles()],
        "void storage setter preserves corrupt source and prior cache on failure");
    CHECK([NSFileManager.defaultManager removeItemAtPath:PXTLinkIOSSettingsPath() error:NULL] && PXSeedStoragePreferences(baseline), "storage preference source restored");

    // Block the first call after commit without holding the object's monitor.
    // Main can read the cache and reject a competing call while this mirror waits.
    dispatch_semaphore_t enteredMirror = dispatch_semaphore_create(0), releaseMirror = dispatch_semaphore_create(0);
    dispatch_group_t group = dispatch_group_create(); __block BOOL firstResult = NO;
    gDuringStoragePreferenceMirror = ^{
        dispatch_semaphore_signal(enteredMirror);
        dispatch_semaphore_wait(releaseMirror, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    };
    dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ firstResult = [manager setStorageSpoofingEnabled:YES error:NULL]; });
    CHECK(dispatch_semaphore_wait(enteredMirror, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) == 0, "storage concurrent fixture reaches mirror");
    NSUInteger writes = gWrites;
    CHECK([manager isStorageSpoofingEnabled] && ![manager setStorageSpoofingEnabled:NO error:&error] && error.code == 1 && writes == gWrites,
        "concurrent storage flag writer fails busy while getter remains available");
    dispatch_semaphore_signal(releaseMirror);
    CHECK(dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0 && firstResult,
        "admitted storage flag writer completes after competing caller rejection");
    CHECK([manager setStorageSpoofingEnabled:NO error:&error] && !error && ![manager isStorageSpoofingEnabled],
        "storage flag writer accepts a later request after completion");
}

static BOOL SetArtifactSelection(id profileID) {
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        NSDictionary *selection = profileID ? @{ @"ProfileId": profileID } : @{};
        return [tx setDictionary:selection atPath:PXCurrentProfileInfoPath() error:error];
    } error:NULL];
}
static BOOL SetArtifactIntent(BOOL present) {
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return present ? [tx setDictionary:@{ @"fixture": @YES } atPath:PXProfileDeletionJournalPath() error:error] :
            [tx removeDictionaryAtPath:PXProfileDeletionJournalPath() error:error];
    } error:NULL];
}
static void CheckArtifactLeaseFree(void) {
    NSError *error = nil;
    PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:gRoot error:&error];
    CHECK(lease && !error, "standalone artifact releases lifecycle before cache callbacks logging and return");
    [lease invalidate];
}
static void CheckArtifactLeaseHeld(void) {
    NSError *error = nil;
    PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:gRoot error:&error];
    CHECK(!lease && error.code == 12, "standalone artifact owns lifecycle during preparation outside source gate");
    [lease invalidate];
    CHECK(AllArtifactFiles() != nil, "standalone artifact preparation executes outside source gate");
}
static NSUInteger ArtifactDescriptorCount(void) {
    NSUInteger count = 0;
    for (int fd = 0; fd < 1024; fd++) if (fcntl(fd, F_GETFD) != -1) count++;
    return count;
}
@interface PXObservedUptimeFixture : PXPreparedUptimeFixture
@end
@implementation PXObservedUptimeFixture
- (void)setBootTimeValue:(NSDate *)value {
    CheckArtifactLeaseFree();
    NSString *persisted = IDs()[@"BootTime"];
    CHECK(([persisted isEqual:[NSString stringWithFormat:@"%.0f", value.timeIntervalSince1970]]),
          "uptime cache setter sees committed tuple after ownership release");
    [super setBootTimeValue:value];
}
@end

static void TestStorageLifecycle(void) {
    PXPreparedStorageFixture *manager = [PXPreparedStorageFixture new];
    NSDictionary *record = @{ @"TotalStorage": @"256", @"FreeStorage": @"99.5", @"FilesystemType": @"0x1A" };
    [manager setFixtureSnapshot:record];
    CHECK(SetArtifactSelection(@"b"), "storage inactive-target fixture selected B");
    NSError *error = nil;
    __block NSUInteger commits = 0;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"commit-written"]) commits++; };
    CHECK([manager persistStorageToProfile:@"a" current:NO error:&error] && !error && commits == 1 &&
          [[NSDictionary dictionaryWithContentsOfFile:Path(PXProfileRootPath(@"a"), @"storage.plist")] isEqual:record],
          "storage explicit inactive target persists once without selecting active profile");
    gStore.testCheckpoint = nil;
    PXProfileLifecycleLease *owner = [PXProfileLifecycleLease acquireInDirectory:gRoot error:NULL];
    CHECK(owner != nil, "external artifact lifecycle owner acquired");
    NSUInteger copies = gStorageCopies, providers = gUptimeProviders;
    NSDictionary *before = AllArtifactFiles();
    CHECK(![manager persistStorageToProfile:@"a" current:NO error:&error] && error.code == 12 &&
          ![manager persistStorageToProfile:nil current:YES error:&error] && error.code == 12 &&
          copies == gStorageCopies && [before isEqual:AllArtifactFiles()], "busy storage blocks current and explicit persistence before copying cache");
    [owner invalidate];
    CHECK(SetArtifactIntent(YES), "storage pending intent seeded"); before = AllArtifactFiles();
    CHECK(![manager persistStorageToProfile:@"a" current:NO error:&error] && error.code == 27 &&
          ![manager persistStorageToProfile:nil current:YES error:&error] && error.code == 27 &&
          copies == gStorageCopies && [before isEqual:AllArtifactFiles()], "pending delete blocks storage before target cache capture");
    CHECK(SetArtifactIntent(NO), "storage pending intent cleared"); CheckArtifactLeaseFree();
    CHECK([NSFileManager.defaultManager createDirectoryAtPath:PXProfileRootPath(@"c") withIntermediateDirectories:NO attributes:nil error:NULL], "legacy storage-only profile directory created");
    CHECK([manager persistStorageToProfile:@"c" current:NO error:&error] && !error &&
          ![NSFileManager.defaultManager fileExistsAtPath:PXProfileIdentityPath(@"c")],
          "storage supports existing profile without requiring or creating identity child");
    // Keep the old canonical-file authority even if a legacy selection exists.
    CHECK(SetArtifactSelection(nil), "storage missing canonical selection seeded");
    CHECK([gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return [tx setDictionary:@{ @"ProfileId": @"a" } atPath:PXLegacyActiveProfileInfoPath() error:writeError];
    } error:NULL], "legacy selection present beside empty canonical selection");
    before = AllArtifactFiles(); copies = gStorageCopies;
    CHECK(![manager persistStorageToProfile:nil current:YES error:&error] && error && copies == gStorageCopies &&
          [before isEqual:AllArtifactFiles()], "current storage does not substitute legacy selection when canonical ID is absent");
    CHECK(SetArtifactSelection(@7), "invalid canonical profile ID seeded"); before = AllArtifactFiles();
    CHECK(![manager persistStorageToProfile:nil current:YES error:&error] && copies == gStorageCopies &&
          [before isEqual:AllArtifactFiles()], "invalid storage selection fails before copying cache or writing source");
    CHECK(SetArtifactSelection(@"a"), "storage canonical selection restored");
    NSDictionary *bStorage = [NSDictionary dictionaryWithContentsOfFile:Path(PXProfileRootPath(@"b"), @"storage.plist")];
    gDuringStorageCopy = ^{
        CheckArtifactLeaseHeld();
        NSError *busy = nil;
        CHECK(![manager persistStorageToProfile:@"b" current:NO error:&busy] && busy.code == 12, "storage copy reentry rejects busy without deadlock");
        CHECK(SetArtifactSelection(@"b"), "bypass selection changes during storage preparation");
    };
    CHECK([manager persistStorageToProfile:nil current:YES error:&error] && !error &&
          [[NSDictionary dictionaryWithContentsOfFile:Path(PXProfileRootPath(@"a"), @"storage.plist")] isEqual:record] &&
          ((!bStorage && ![NSFileManager.defaultManager fileExistsAtPath:Path(PXProfileRootPath(@"b"), @"storage.plist")]) ||
            [bStorage isEqual:[NSDictionary dictionaryWithContentsOfFile:Path(PXProfileRootPath(@"b"), @"storage.plist")]]),
          "current storage captures target once and cannot redirect after preparation");
    CHECK(SetArtifactSelection(@"a"), "storage current target restored");
    [manager setFixtureSnapshot:@{ @"TotalStorage": @"512", @"FreeStorage": @"123.4", @"FilesystemType": @"0x1A" }];
    before = AllArtifactFiles(); __block BOOL interrupted = NO;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"] && !interrupted) { interrupted = YES; [NSException raise:@"fixture" format:@"storage failure"]; } };
    CHECK(![manager persistStorageToProfile:@"a" current:NO error:&error] && error && interrupted, "storage commit fault is reported");
    gStore.testCheckpoint = nil;
    CHECK([before isEqual:AllArtifactFiles()], "storage commit failure preserves previous file and source token"); CheckArtifactLeaseFree();
    gDuringStorageCopy = ^{ [NSException raise:@"fixture" format:@"cache copy exception"]; };
    BOOL threw = NO;
    @try { [manager saveToProfile:@"a"]; } @catch (NSException *exception) { (void)exception; threw = YES; }
    CHECK(threw && [before isEqual:AllArtifactFiles()], "storage cache-copy exception preserves source and releases scope"); CheckArtifactLeaseFree();
    __block NSDictionary *competitor = nil;
    gDuringStorageCopy = ^{ CHECK(SetArtifactIntent(YES), "bypass storage deletion intent committed"); competitor = AllArtifactFiles(); };
    CHECK(![manager persistStorageToProfile:@"a" current:NO error:&error] && error.code == 27 && [competitor isEqual:AllArtifactFiles()],
          "late deletion journal rejects storage before staging");
    CHECK(SetArtifactIntent(NO), "storage late intent cleared"); CheckArtifactLeaseFree();
    for (NSUInteger kind = 0; kind < 3; kind++) {
        NSString *root = PXProfileRootPath(@"a"), *old = Path(gRoot, @"displaced-storage-a");
        __block BOOL moved = NO; competitor = nil;
        gDuringStorageCopy = ^{
            moved = [NSFileManager.defaultManager moveItemAtPath:root toPath:old error:NULL];
            if (kind == 1) moved = moved && [NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:NO attributes:nil error:NULL];
            if (kind == 2) moved = moved && [NSFileManager.defaultManager createSymbolicLinkAtPath:root withDestinationPath:PXProfileRootPath(@"b") error:NULL];
            competitor = AllArtifactFiles();
        };
        CHECK(![manager persistStorageToProfile:@"a" current:NO error:&error] && error && moved && [competitor isEqual:AllArtifactFiles()],
              "storage rejects removed replaced and symlink profile roots without recreating target");
        if (kind != 0) CHECK([NSFileManager.defaultManager removeItemAtPath:root error:NULL], "storage replacement fixture removed");
        CHECK([NSFileManager.defaultManager moveItemAtPath:old toPath:root error:NULL], "storage profile root restored"); CheckArtifactLeaseFree();
    }
    // Public setters still update their cache before attempting their legacy
    // autosave; ownership does not make three separate setters one transaction.
    [manager adoptCommittedStorageInfo:record];
    gDuringLog = ^{ CheckArtifactLeaseFree(); };
    [manager setTotalStorageCapacity:@"128"]; [manager setFreeStorageSpace:@"42.0"]; [manager setFilesystemType:@"0x1A"];
    gDuringLog = nil;
    NSDictionary *stored = [NSDictionary dictionaryWithContentsOfFile:Path(PXProfileRootPath(@"a"), @"storage.plist")];
    CHECK([stored isEqual:[manager fixtureStorage]] && [stored[@"TotalStorage"] isEqual:@"128"] &&
          [stored[@"FreeStorage"] isEqual:@"42.0"] && gUptimeProviders == providers, "storage setter autosaves use owned current-target persistence without altering units");
    NSUInteger descriptors = ArtifactDescriptorCount();
    for (NSUInteger i = 0; i < 12; i++) {
        @autoreleasepool {
            PXProfileArtifactMutation *scope = [PXProfileArtifactMutation acquireWithProfileIDResolver:^NSString *{ return @"c"; } error:&error];
            CHECK(scope && !error && [scope.profileDirectory isEqual:PXProfileRootPath(@"c")], "profile-root capability captures existing legacy directory");
            if (i % 2) [scope invalidate];
            scope = nil;
            scope = [PXProfileArtifactMutation acquireWithProfileIDResolver:^NSString *{ return @"../a"; } error:&error];
            CHECK(!scope && error, "profile-root capability rejects invalid resolver ID");
        }
    }
    CHECK(descriptors == ArtifactDescriptorCount(), "profile-root capability closes descriptors on explicit release dealloc and failed acquire");
    CheckArtifactLeaseFree();
}

static void TestStorageReadBoundaries(void) {
    PXPreparedStorageFixture *manager = [PXPreparedStorageFixture new];
    [manager adoptCommittedStorageInfo:@{ @"TotalStorage": @128, @"FreeStorage": @19.8, @"FilesystemType": @26 }];
    CHECK([[manager totalStorageCapacity] isEqual:@"128"] && [[manager freeStorageSpace] isEqual:@"19.8"] && [[manager filesystemType] isEqual:@"26"],
          "storage scalar getters stringify legacy numeric values without changing the cache");
    CHECK([[manager currentStorageInfo][@"TotalStorage"] isKindOfClass:NSNumber.class], "storage getters never rewrite source or cached scalar types");
    NSArray *invalid = @[@[], @{}, NSNull.null, NSDate.date];
    for (id value in invalid) {
        [manager adoptCommittedStorageInfo:@{ @"TotalStorage": value, @"FreeStorage": value, @"FilesystemType": value }];
        CHECK(![manager totalStorageCapacity] && ![manager freeStorageSpace] && ![manager filesystemType] &&
              [manager totalStorageCapacityInMarketingBytes] == 0 && [manager freeStorageSpaceInMarketingBytes] == 0,
              "malformed storage fields cannot escape string APIs or reach numeric selectors");
        CHECK([manager convertGBStringToBytes:value] == 0, "storage numeric helper rejects unsupported scalar types");
    }
    NSArray *badNumbers = @[@(-1), @0, @(NAN), @(INFINITY), @(-INFINITY), @(1e100), @(0x1p64 / 1e9)];
    for (id value in badNumbers) CHECK([manager convertGBStringToBytes:value] == 0, "storage numeric conversion rejects nonpositive nonfinite and uint64 overflow values");
    CHECK([manager convertGBStringToBytes:@"64"] == 64000000000ULL && [manager convertGBStringToBytes:@0.1] == 100000000ULL &&
          [manager convertGBStringToBytes:@"64GB"] == 64000000000ULL && [manager convertGBStringToBytes:@"bad"] == 0,
          "storage conversions preserve marketing units fractions and legacy prefix parsing");
    CHECK([manager convertGBStringToBytes:@"64" useBinaryUnits:YES] == 64000000000ULL &&
          [manager normalizeStorageBytes:64000000000ULL useMarketingUnits:NO] == 64000000000ULL,
          "storage compatibility unit switches keep their existing marketing-only behavior");
    for (NSNumber *capacity in @[@64, @128, @256, @512, @1024]) {
        uint64_t bytes = capacity.unsignedLongLongValue * 1000000000ULL;
        CHECK([manager normalizeStorageBytes:bytes] == bytes, "normal storage tiers retain legacy normalization");
    }
    CHECK([manager normalizeStorageBytes:UINT64_MAX] == UINT64_MAX && [manager normalizeStorageBytes:UINT64_MAX - 1] == UINT64_MAX - 1,
          "normalization preserves original byte count if rounding cannot fit uint64");
    for (NSNumber *bytes in @[@0, @1, @4095, @4096, @4097, @(UINT64_MAX - 1), @(UINT64_MAX)]) {
        for (NSNumber *block in @[@0, @1, @4096, @(UINT32_MAX)]) {
            uint64_t size = bytes.unsignedLongLongValue;
            uint32_t divisor = block.unsignedIntValue ?: 4096;
            uint64_t count = calculateBlockCount(size, block.unsignedIntValue);
            __uint128_t covered = (__uint128_t)count * divisor;
            CHECK(covered >= size && (!count || covered - divisor < size), "block count is the minimal covering count without overflowing at uint64 boundaries");
        }
    }

    // Restore exact bytes/absence after the read/default matrix; the fixture
    // never publishes these temporary model/selection records through SourceStore.
    NSArray *paths = @[PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(),
        Path(PXProfileRootPath(@"a"), @"storage.plist"), Path(PXProfileIdentityPath(@"a"), @"device_ids.plist"),
        Path(PXProfileIdentityPath(@"b"), @"device_ids.plist")];
    NSMutableDictionary *original = [NSMutableDictionary dictionary];
    for (NSString *path in paths) original[path] = [NSData dataWithContentsOfFile:path] ?: (id)NSNull.null;
    NSDictionary *allBefore = AllArtifactFiles();
    NSUInteger writes = gWrites, local = gLocal, darwin = gDarwin;
    NSArray *savedTape = gTape; NSUInteger savedTapeIndex = gTapeIndex; BOOL savedHigh = gHigh;
    @try {
        gStorageModelRows = @{ @"iPhoneFixtureA": @{ @"known": @YES }, @"iPhoneFixtureB": @{ @"known": @YES } };
        gStorageModelSpecs = @{ @"iPhoneFixtureA": @{ @"storageCapacitiesGB": @[@64] }, @"iPhoneFixtureB": @{ @"storageCapacitiesGB": @[@1024] } };
        CHECK(([@{ @"ProfileId": @"b" } writeToFile:PXCurrentProfileInfoPath() atomically:YES]), "storage read fixture selects active B");
        CHECK(([@{ @"DeviceModel": @"iPhoneFixtureA" } writeToFile:paths[3] atomically:YES] &&
               [@{ @"DeviceModel": @"iPhoneFixtureB" } writeToFile:paths[4] atomically:YES]), "storage read fixture model packets seeded");
        [NSFileManager.defaultManager removeItemAtPath:paths[2] error:NULL];
        [manager adoptCommittedStorageInfo:@{ @"keep": @"metadata" }]; Tape(@[]);
        NSUInteger active = gStorageActiveReads;
        CHECK(![manager loadFromProfile:@"a"] && [[manager totalStorageCapacity] isEqual:@"64"] &&
              [gLastStorageModel isEqual:@"iPhoneFixtureA"] && active == gStorageActiveReads && [[manager currentStorageInfo][@"keep"] isEqual:@"metadata"],
              "missing inactive storage uses its own target model rather than active profile hardware");
        CHECK(![NSFileManager.defaultManager fileExistsAtPath:paths[2]], "default storage stays ephemeral and never creates a source file");
        NSDictionary *snapshot = [manager currentStorageInfo];
        NSUInteger calls = gStorageModelCalls;
        NSArray *badIDs = @[@[], @1, NSNull.null, @"../a", @"Unknown", @""];
        for (id value in badIDs) CHECK(![manager loadFromProfile:value] && [snapshot isEqual:[manager currentStorageInfo]] && calls == gStorageModelCalls,
                                      "invalid storage profile ID rejects before defaults model lookup or cache mutation");
        for (id value in invalid) CHECK(![manager randomizeStorageCapacityForDeviceModel:value] && calls == gStorageModelCalls,
                                      "invalid model type rejects before database factory lookup");
        CHECK(([@{ @"TotalStorage": @128, @"FreeStorage": @20, @"FilesystemType": @"apfs" } writeToFile:paths[2] atomically:YES]), "storage read numeric record seeded");
        CHECK([manager loadFromProfile:@"a"] && [[manager totalStorageCapacity] isEqual:@"128"] && ![manager currentStorageInfo][@"keep"],
              "existing storage load replaces cache and preserves legacy numeric getter compatibility");
        gStorageModelSpecs = @{ @"iPhoneFixtureA": @{ @"storageCapacitiesGB": @[@128, @256] } };
        CHECK([[manager randomizeStorageCapacityForDeviceModel:@"iPhoneFixtureA"] isEqual:@"256"], "numeric previous capacity avoids immediate repeat");
        gStorageModelSpecs = @{ @"iPhoneFixtureA": @{ @"storageCapacitiesGB": @[@128, @128] } };
        CHECK([[manager randomizeStorageCapacityForDeviceModel:@"iPhoneFixtureA"] isEqual:@"128"], "duplicate-only tiers retain restoration fallback after filtering");
        gStorageModelSpecs = @{ @"iPhoneFixtureA": @{ @"storageCapacitiesGB": @[@128] } };
        CHECK([[manager randomizeStorageCapacityForDeviceModel:@"iPhoneFixtureA"] isEqual:@"128"], "single storage tier is not filtered out");
        gStorageModelSpecs = @{ @"iPhoneFixtureA": @[] }; gStorageFallbackSpecs = @{ @"storageCapacitiesGB": @[@32] };
        CHECK(![manager randomizeStorageCapacityForDeviceModel:@"iPhoneFixtureA"] && ![manager randomizeStorageCapacityForDeviceModel:@"iPhoneUnknown"],
              "iPhone hardware remains fail closed when canonical rows are missing or malformed");
        gStorageFallbackSpecs = @[];
        CHECK([manager randomizeStorageCapacityForDeviceModel:nil] != nil, "nil model keeps generic tiers even with malformed optional fallback specs");
        CHECK(([@{ @"DeviceModel": @"iPhoneUnknown" } writeToFile:paths[3] atomically:YES]), "unknown target model seeded");
        [NSFileManager.defaultManager removeItemAtPath:paths[2] error:NULL];
        [manager adoptCommittedStorageInfo:@{ @"TotalStorage": @"256", @"FreeStorage": @"40", @"FilesystemType": @"old", @"keep": @YES }];
        CHECK(![manager loadFromProfile:@"a"] && ![manager totalStorageCapacity] && ![manager freeStorageSpace] &&
              ![manager filesystemType] && [[manager currentStorageInfo][@"keep"] boolValue], "failed target defaults clear owned storage fields without leaking previous profile values");
        gStorageModelSpecs = @{ @"iPhoneFixtureB": @{ @"storageCapacitiesGB": @[@1024] } };
        CHECK(([@{ @"ProfileId": @[] } writeToFile:PXCurrentProfileInfoPath() atomically:YES] &&
               [@{ @"ProfileId": @"b" } writeToFile:PXLegacyActiveProfileInfoPath() atomically:YES]), "storage current-load malformed canonical selection fixture seeded");
        [manager loadFromCurrentProfile];
        CHECK([[manager totalStorageCapacity] isEqual:@"1024"] && [gLastStorageModel isEqual:@"iPhoneFixtureB"],
              "current storage malformed canonical ID uses legacy active hardware for ephemeral defaults without loading another profile record");
    } @finally {
        for (NSString *path in paths) {
            id bytes = original[path];
            if (bytes == NSNull.null) [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
            else CHECK([bytes writeToFile:path atomically:YES], "storage read fixture restores exact original bytes");
        }
        gStorageModelRows = nil; gStorageModelSpecs = nil; gStorageFallbackSpecs = nil; gLastStorageModel = nil;
        gTape = savedTape; gTapeIndex = savedTapeIndex; gHigh = savedHigh;
    }
    CHECK([allBefore isEqual:AllArtifactFiles()] && writes == gWrites && local == gLocal && darwin == gDarwin,
          "storage read and default matrix leaves source marker files and notification counters unchanged after teardown");
}

static void TestStorageDisplayCommit(void) {
    PXPreparedStorageFixture *manager = [PXPreparedStorageFixture new];
    NSDictionary *base = @{ @"TotalStorage": @"64", @"FreeStorage": @"18", @"FilesystemType": @"old", @"keep": @[@"metadata"] };
    NSDictionary *values = @{ @"TotalStorage": @"128", @"FreeStorage": @"32", @"FilesystemType": @"0x1A" };
    [manager adoptCommittedStorageInfo:base];
    CHECK(SetArtifactSelection(@"a"), "display storage canonical target seeded");
    NSString *path = Path(PXProfileRootPath(@"a"), @"storage.plist");
    NSString *identityPath = Path(PXProfileIdentityPath(@"a"), @"storage.plist");
    NSData *identityBefore = [NSData dataWithContentsOfFile:identityPath];
    NSData *otherBefore = [NSData dataWithContentsOfFile:Path(PXProfileRootPath(@"b"), @"storage.plist")];
    NSError *error = [NSError errorWithDomain:@"stale" code:99 userInfo:nil];
    NSUInteger writes = gWrites, local = gLocal, darwin = gDarwin;
    __block NSUInteger commits = 0;
    gStore.testCheckpoint = ^(NSString *phase) {
        if ([phase isEqual:@"commit-written"]) {
            commits++;
            CHECK([[manager fixtureStorage] isEqual:base], "display storage cache remains old until source commit returns");
        }
    };
    CHECK([manager commitDisplayStorageInfo:values updateFilesystem:YES error:&error] && !error && gWrites == writes + 3 && commits == 1,
          "display storage commits one complete packet instead of three setter writes");
    gStore.testCheckpoint = nil;
    NSDictionary *stored = [NSDictionary dictionaryWithContentsOfFile:path];
    CHECK([stored isEqual:[manager currentStorageInfo]] && [stored[@"TotalStorage"] isEqual:@"128"] &&
          [stored[@"FreeStorage"] isEqual:@"32"] && [stored[@"FilesystemType"] isEqual:@"0x1A"] && [stored[@"keep"] isEqual:base[@"keep"]],
          "display storage adopts the detached committed packet and preserves unrelated cache fields");
    NSData *identityAfter = [NSData dataWithContentsOfFile:identityPath];
    NSData *otherAfter = [NSData dataWithContentsOfFile:Path(PXProfileRootPath(@"b"), @"storage.plist")];
    CHECK((identityBefore == identityAfter || [identityBefore isEqual:identityAfter]) &&
          (otherBefore == otherAfter || [otherBefore isEqual:otherAfter]) && local == gLocal && darwin == gDarwin,
          "display storage preserves root artifact location inactive target and notification policy");
    CheckArtifactLeaseFree();

    NSDictionary *withoutFilesystem = @{ @"TotalStorage": @"256", @"FreeStorage": @"80" };
    CHECK([manager commitDisplayStorageInfo:withoutFilesystem updateFilesystem:NO error:&error] &&
          [[manager currentStorageInfo][@"FilesystemType"] isEqual:@"0x1A"], "display storage can preserve unowned filesystem metadata");
    CHECK([manager commitDisplayStorageInfo:withoutFilesystem updateFilesystem:YES error:&error] &&
          ![manager currentStorageInfo][@"FilesystemType"] && ![NSDictionary dictionaryWithContentsOfFile:path][@"FilesystemType"],
          "display storage absent owned filesystem retains removal semantics");

    NSDictionary *before = AllArtifactFiles(), *cache = [manager currentStorageInfo];
    NSData *marker = [NSData dataWithContentsOfFile:Path(Path(gRoot, @"control"), @"commit.plist")];
    __block BOOL interrupted = NO;
    gStore.testCheckpoint = ^(NSString *phase) {
        if ([phase isEqual:@"source-written"] && !interrupted) { interrupted = YES; [NSException raise:@"fixture" format:@"display storage fault"]; }
    };
    CHECK(![manager commitDisplayStorageInfo:values updateFilesystem:YES error:&error] && error && interrupted,
          "display storage reports a pre-marker source fault");
    gStore.testCheckpoint = nil;
    CHECK([before isEqual:AllArtifactFiles()] && [cache isEqual:[manager currentStorageInfo]] &&
          [marker isEqual:[NSData dataWithContentsOfFile:Path(Path(gRoot, @"control"), @"commit.plist")]],
          "display storage failure restores source bytes and marker without adopting cache");
    CheckArtifactLeaseFree();
    gStore.testCheckpoint = ^(NSString *phase) {
        if ([phase isEqual:@"commit-written"]) [NSException raise:@"fixture" format:@"display post-marker housekeeping fault"];
    };
    CHECK([manager commitDisplayStorageInfo:values updateFilesystem:YES error:&error] && !error &&
          [[manager currentStorageInfo] isEqual:[NSDictionary dictionaryWithContentsOfFile:path]],
          "display storage acknowledged commit still adopts cache after post-marker housekeeping exception");
    gStore.testCheckpoint = nil;
    CheckArtifactLeaseFree();
    before = AllArtifactFiles(); cache = [manager currentStorageInfo];

    writes = gWrites;
    NSArray *bad = @[@[], NSNull.null, @1, @{}, @{ @"TotalStorage": @[], @"FreeStorage": @"1" },
        @{ @"TotalStorage": @"1", @"FreeStorage": @"1", @"FilesystemType": @[] }];
    for (id invalid in bad) {
        CHECK(![manager commitDisplayStorageInfo:invalid updateFilesystem:YES error:&error] && error.code == 1,
              "display storage rejects malformed input before ownership and source writes");
    }
    CHECK(writes == gWrites && [cache isEqual:[manager currentStorageInfo]] && [before isEqual:AllArtifactFiles()],
          "invalid display storage leaves cache and source untouched");
    BOOL outer = [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        (void)tx; (void)writeError;
        NSError *nested = nil;
        CHECK(![manager commitDisplayStorageInfo:values updateFilesystem:YES error:&nested] && nested,
              "nested display storage rejects staged success before lifecycle target and cache work");
        return YES; // Ignoring the inner NO must not allow the outer commit.
    } error:&error];
    CHECK(!outer && error && [before isEqual:AllArtifactFiles()] && [cache isEqual:[manager currentStorageInfo]],
          "nested display storage poisons outer transaction without source or cache publication");
    writes = gWrites;
    [manager setFixtureSnapshot:cache];
    NSUInteger copies = gStorageCopies;
    PXProfileLifecycleLease *owner = [PXProfileLifecycleLease acquireInDirectory:gRoot error:NULL];
    CHECK(owner && ![manager commitDisplayStorageInfo:values updateFilesystem:YES error:&error] && error.code == 12 && copies == gStorageCopies && gWrites == writes + 1,
          "busy display storage performs only standalone admission before rejecting ownership");
    [owner invalidate];
    CHECK(SetArtifactIntent(YES), "display storage pending deletion seeded");
    CHECK(![manager commitDisplayStorageInfo:values updateFilesystem:YES error:&error] && error.code == 27 && copies == gStorageCopies,
          "pending deletion blocks display storage before cache preparation");
    CHECK(SetArtifactIntent(NO), "display storage pending deletion cleared");
    gDuringStorageCopy = ^{
        CheckArtifactLeaseHeld();
        NSError *nested = nil;
        CHECK(![manager commitDisplayStorageInfo:values updateFilesystem:YES error:&nested] && nested.code == 12,
              "display storage preparation rejects reentry without deadlock");
    };
    CHECK([manager commitDisplayStorageInfo:values updateFilesystem:YES error:&error] && !error, "display storage outer owner survives rejected reentry");
    CheckArtifactLeaseFree();

    NSMutableString *total = [@"512" mutableCopy], *free = [@"123" mutableCopy];
    NSMutableDictionary *mutableValues = [@{ @"TotalStorage": total, @"FreeStorage": free } mutableCopy];
    [manager setFixtureSnapshot:[manager currentStorageInfo]];
    gDuringStorageCopy = ^{
        [total setString:@"changed"]; [free setString:@"changed"]; [mutableValues removeAllObjects];
        CHECK(SetArtifactSelection(@"b"), "display storage external selection drift seeded");
    };
    otherBefore = [NSData dataWithContentsOfFile:Path(PXProfileRootPath(@"b"), @"storage.plist")];
    CHECK([manager commitDisplayStorageInfo:mutableValues updateFilesystem:NO error:&error] &&
          [[NSDictionary dictionaryWithContentsOfFile:path][@"TotalStorage"] isEqual:@"512"] &&
          [[NSDictionary dictionaryWithContentsOfFile:path][@"FreeStorage"] isEqual:@"123"] &&
          [otherBefore isEqual:[NSData dataWithContentsOfFile:Path(PXProfileRootPath(@"b"), @"storage.plist")]],
          "display storage freezes caller values and keeps one canonical target through selection drift");
    CHECK(SetArtifactSelection(@"a"), "display storage canonical target restored");
    CheckArtifactLeaseFree();
    before = AllArtifactFiles();
    [manager setFixtureSnapshot:[manager currentStorageInfo]];
    gDuringStorageCopy = ^{ [NSException raise:@"fixture" format:@"display cache copy failure"]; };
    BOOL threw = NO;
    @try { [manager commitDisplayStorageInfo:values updateFilesystem:YES error:&error]; }
    @catch (NSException *exception) { (void)exception; threw = YES; }
    CHECK(threw && [before isEqual:AllArtifactFiles()], "display storage cache-copy exception releases ownership before propagating");
    CheckArtifactLeaseFree();
    CHECK(SetArtifactSelection(@"c"), "display storage legacy root-only target selected");
    CHECK([manager commitDisplayStorageInfo:values updateFilesystem:YES error:&error] &&
          ![NSFileManager.defaultManager fileExistsAtPath:PXProfileIdentityPath(@"c")], "display storage root-only profile requires no identity directory");
    NSString *legacyRoot = PXProfileRootPath(@"c"), *displaced = Path(gRoot, @"display-displaced-c");
    CHECK([NSFileManager.defaultManager moveItemAtPath:legacyRoot toPath:displaced error:NULL], "display storage missing-root fixture moved");
    @try {
        [manager setFixtureSnapshot:[manager currentStorageInfo]]; copies = gStorageCopies; before = AllArtifactFiles();
        CHECK(![manager commitDisplayStorageInfo:values updateFilesystem:YES error:&error] && error && copies == gStorageCopies &&
              ![NSFileManager.defaultManager fileExistsAtPath:legacyRoot] && [before isEqual:AllArtifactFiles()],
              "display storage cannot recreate a removed profile or copy cache for it");
    } @finally {
        CHECK([NSFileManager.defaultManager moveItemAtPath:displaced toPath:legacyRoot error:NULL], "display storage missing-root fixture restored");
    }
    CHECK(SetArtifactSelection(nil), "display storage missing selection seeded");
    writes = gWrites;
    CHECK(![manager commitDisplayStorageInfo:values updateFilesystem:YES error:&error] && error && gWrites == writes + 2,
          "display storage never invents a target for missing canonical selection");
    CHECK(SetArtifactSelection(@"a"), "display storage fixture restores selection for following suites");
    gDuringStorageCopy = nil; CheckArtifactLeaseFree();
}

static void TestUptimeLifecycle(void) {
    Tape(@[]);
    PXObservedUptimeFixture *manager = [PXObservedUptimeFixture new];
    PXPreparedStorageFixture *storage = [PXPreparedStorageFixture new];
    [storage adoptCommittedStorageInfo:PXPrepareRuntimeStorage(@"128")];
    NSString *identity = PXProfileIdentityPath(@"a");
    CHECK(SetArtifactSelection(@"b"), "uptime explicit inactive target selected");
    [manager generateConsistentUptimeAndBootTimeForProfile:identity];
    CHECK(!manager.error && manager.bootTimeValue && manager.uptimeValue > 0, "uptime commits explicit inactive target under lifecycle ownership");
    NSDate *previous = manager.bootTimeValue, *clock = manager.cacheTime;
    NSTimeInterval seconds = manager.uptimeValue;
    PXProfileLifecycleLease *owner = [PXProfileLifecycleLease acquireInDirectory:gRoot error:NULL];
    CHECK(owner != nil, "uptime competing lifecycle owner acquired");
    NSUInteger providers = gUptimeProviders; NSDictionary *before = AllArtifactFiles();
    [manager generateConsistentUptimeAndBootTimeForProfile:identity];
    CHECK(manager.error.code == 12 && providers == gUptimeProviders && previous == manager.bootTimeValue && clock == manager.cacheTime &&
          seconds == manager.uptimeValue && [before isEqual:AllArtifactFiles()], "busy uptime avoids sysctl preparation cache changes and source writes");
    [owner invalidate];
    CHECK(SetArtifactIntent(YES), "uptime pending intent seeded"); before = AllArtifactFiles();
    [manager generateConsistentUptimeAndBootTimeForProfile:identity];
    CHECK(manager.error.code == 27 && providers == gUptimeProviders && previous == manager.bootTimeValue &&
          [before isEqual:AllArtifactFiles()], "pending delete stops uptime before sysctl and preserves cache");
    CHECK(SetArtifactIntent(NO), "uptime pending intent cleared");
    [manager generateConsistentUptimeAndBootTimeForProfile:PXProfileIdentityPath(@"c")];
    CHECK(manager.error && providers == gUptimeProviders && ![NSFileManager.defaultManager fileExistsAtPath:PXProfileIdentityPath(@"c")] &&
          previous == manager.bootTimeValue, "uptime refuses absent identity instead of recreating legacy directory");
    before = AllArtifactFiles();
    gDuringUptime = ^{ CheckArtifactLeaseHeld(); [NSException raise:@"fixture" format:@"sysctl adapter exception"]; };
    gDuringLog = ^{ CheckArtifactLeaseFree(); };
    [manager generateConsistentUptimeAndBootTimeForProfile:identity];
    gDuringLog = nil;
    CHECK(manager.error.code == 1002 && previous == manager.bootTimeValue && clock == manager.cacheTime && [before isEqual:AllArtifactFiles()],
          "uptime provider exception releases lease before error logging and leaves cache unchanged"); CheckArtifactLeaseFree();
    NSMutableString *callerPath = [identity mutableCopy];
    gDuringUptime = ^{
        CheckArtifactLeaseHeld();
        NSError *busy = nil;
        CHECK(![storage persistStorageToProfile:@"b" current:NO error:&busy] && busy.code == 12, "uptime preparation excludes reentrant storage writer");
        [callerPath setString:PXProfileIdentityPath(@"b")];
    };
    NSDictionary *other = [NSDictionary dictionaryWithContentsOfFile:Path(PXProfileIdentityPath(@"b"), @"device_ids.plist")];
    [manager generateConsistentUptimeAndBootTimeForProfile:callerPath];
    CHECK(!manager.error && ((!other && ![NSFileManager.defaultManager fileExistsAtPath:Path(PXProfileIdentityPath(@"b"), @"device_ids.plist")]) ||
          [other isEqual:[NSDictionary dictionaryWithContentsOfFile:Path(PXProfileIdentityPath(@"b"), @"device_ids.plist")]]),
          "uptime detaches mutable caller path and cannot redirect during preparation");
    previous = manager.bootTimeValue; clock = manager.cacheTime;
    __block NSDictionary *competitor = nil;
    gDuringUptime = ^{ CHECK(SetArtifactIntent(YES), "bypass uptime deletion intent committed"); competitor = AllArtifactFiles(); };
    [manager generateConsistentUptimeAndBootTimeForProfile:identity];
    CHECK(manager.error.code == 27 && previous == manager.bootTimeValue && clock == manager.cacheTime && [competitor isEqual:AllArtifactFiles()],
          "late deletion journal rejects entire uptime tuple without adopting cache");
    CHECK(SetArtifactIntent(NO), "uptime late intent cleared");
    for (NSUInteger kind = 0; kind < 3; kind++) {
        NSString *old = Path(PXProfileRootPath(@"a"), @"old-uptime-identity");
        __block BOOL moved = NO; competitor = nil;
        gDuringUptime = ^{
            moved = [NSFileManager.defaultManager moveItemAtPath:identity toPath:old error:NULL];
            if (kind == 1) moved = moved && [NSFileManager.defaultManager createDirectoryAtPath:identity withIntermediateDirectories:NO attributes:nil error:NULL];
            if (kind == 2) moved = moved && [NSFileManager.defaultManager createSymbolicLinkAtPath:identity withDestinationPath:PXProfileIdentityPath(@"b") error:NULL];
            competitor = AllArtifactFiles();
        };
        [manager generateConsistentUptimeAndBootTimeForProfile:identity];
        CHECK(manager.error && moved && previous == manager.bootTimeValue && clock == manager.cacheTime && [competitor isEqual:AllArtifactFiles()],
              "uptime rejects removed replaced and symlink identity without source or cache adoption");
        if (kind != 0) CHECK([NSFileManager.defaultManager removeItemAtPath:identity error:NULL], "uptime identity replacement fixture removed");
        CHECK([NSFileManager.defaultManager moveItemAtPath:old toPath:identity error:NULL], "uptime original identity restored"); CheckArtifactLeaseFree();
    }
    CHECK(SetArtifactSelection(@"a"), "artifact lifecycle selection restored");
}


static BOOL SeedReadOnlyUptime(NSDictionary *boot, NSDictionary *uptime, NSDictionary *ids) {
    NSString *identity = PXProfileIdentityPath(@"b");
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx setDictionary:boot atPath:Path(identity, @"boot_time.plist") error:error] &&
            [tx setDictionary:uptime atPath:Path(identity, @"system_uptime.plist") error:error] &&
            [tx setDictionary:ids atPath:Path(identity, @"device_ids.plist") error:error];
    } error:NULL];
}
static void TestUptimeReadOnly(void) {
    PXPreparedUptimeFixture *manager = [PXPreparedUptimeFixture new];
    NSString *identity = PXProfileIdentityPath(@"b");
    NSDate *bootDate = [NSDate dateWithTimeIntervalSinceNow:-7200];
    NSDictionary *boot = @{ @"value": bootDate };
    NSDictionary *elapsed = @{ @"value": @"300", @"lastUpdated": [NSDate date] };
    NSDictionary *ids = @{ @"SystemUptime": @"600", @"BootTime": @"123456" };
    CHECK(SeedReadOnlyUptime(boot, elapsed, ids), "read only uptime precedence fixture seeded");
    PXProfileLifecycleLease *owner = [PXProfileLifecycleLease acquireInDirectory:gRoot error:NULL];
    CHECK(owner != nil, "read only uptime competing owner acquired");
    NSUInteger providers = gUptimeProviders, writes = gWrites;
    NSDictionary *before = AllArtifactFiles();
    NSDate *beforeRead = [NSDate date];
    NSTimeInterval value = [manager currentUptimeForProfile:identity generateIfMissing:NO];
    NSDate *afterRead = [NSDate date];
    CHECK(value >= [beforeRead timeIntervalSinceDate:bootDate] && value <= [afterRead timeIntervalSinceDate:bootDate] && [[manager currentBootTimeForProfile:identity generateIfMissing:NO] isEqual:bootDate] &&
          providers == gUptimeProviders && writes == gWrites && !manager.cacheTime && [before isEqual:AllArtifactFiles()],
          "read only uptime preserves boot precedence and avoids lock generation persistence and cache adoption");
    CHECK(SeedReadOnlyUptime(@{}, elapsed, ids), "read only uptime secondary precedence seeded");
    beforeRead = [NSDate date];
    value = [manager currentUptimeForProfile:identity generateIfMissing:NO];
    afterRead = [NSDate date];
    CHECK(value >= 300 + [beforeRead timeIntervalSinceDate:elapsed[@"lastUpdated"]] && value <= 300 + [afterRead timeIntervalSinceDate:elapsed[@"lastUpdated"]] && [[manager currentBootTimeForProfile:identity generateIfMissing:NO] timeIntervalSince1970] == 123456,
          "read only uptime preserves elapsed sidecar and boot scalar fallbacks");
    NSDictionary *malformed = @{ @"value": @[], @"lastUpdated": @[] };
    CHECK(SeedReadOnlyUptime(malformed, malformed, ids), "read only uptime malformed fallback seeded");
    CHECK([manager currentUptimeForProfile:identity generateIfMissing:NO] == 600 &&
          [[manager currentBootTimeForProfile:identity generateIfMissing:NO] timeIntervalSince1970] == 123456,
          "malformed uptime sidecar fields fall through instead of sending unsafe selectors");
    NSDictionary *badIDs = @{ @"SystemUptime": @[], @"BootTime": @{} };
    CHECK(SeedReadOnlyUptime(malformed, malformed, badIDs), "read only uptime fully malformed fixture seeded");
    before = AllArtifactFiles();
    CHECK([manager currentUptimeForProfile:identity generateIfMissing:NO] == 0 && ![manager currentBootTimeForProfile:identity generateIfMissing:NO] &&
          [manager currentUptimeForProfile:PXProfileIdentityPath(@"c") generateIfMissing:NO] == 0 &&
          ![manager currentBootTimeForProfile:PXProfileIdentityPath(@"c") generateIfMissing:NO] && providers == gUptimeProviders && writes == gWrites &&
          [before isEqual:AllArtifactFiles()], "read only missing or malformed uptime returns sentinel without creating profile or source");
    CHECK([manager currentUptimeForProfile:PXProfileIdentityPath(@"c")] == 12 * 3600 &&
          [manager currentBootTimeForProfile:PXProfileIdentityPath(@"c")] != nil && providers == gUptimeProviders && [before isEqual:AllArtifactFiles()],
          "legacy uptime getters retain safe default policy when generation is busy");
    [owner invalidate]; CheckArtifactLeaseFree();
}
static BOOL SetWiFiFixture(NSString *profileID, NSDictionary *record) {
    NSString *path = Path(PXProfileIdentityPath(profileID), @"wifi_info.plist");
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return record ? PXStageRuntimeWiFi(tx, PXProfileIdentityPath(profileID), record, error) : [tx removeDictionaryAtPath:path error:error];
    } error:NULL];
}
static void WiFiSpy(PXOwnedWiFiFixture *manager, NSDictionary *record) {
    PXWiFiSnapshotFixture *spy = [PXWiFiSnapshotFixture new]; spy.record = record; manager.wifiInfo = (id)spy;
}
static BOOL PumpWiFiReload(NSUInteger count) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3];
    while (gWiFiReloads < count && deadline.timeIntervalSinceNow > 0)
        [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    return gWiFiReloads == count;
}
static void TestWiFiLifecycle(void) {
    Tape(@[]);
    NSDictionary *a = @{ @"ssid": @"Saved A", @"bssid": @"02:11:22:33:44:55" };
    NSDictionary *next = @{ @"ssid": @"Next A", @"bssid": @"02:11:22:33:44:66" };
    CHECK(SetArtifactSelection(@"a") && SetWiFiFixture(@"a", a) && SetWiFiFixture(@"b", nil), "WiFi profiles seeded with saved A and missing B");
    __attribute__((objc_precise_lifetime)) PXObservedWiFiFixture *wifi = [PXObservedWiFiFixture new];
    CHECK([wifi.wifiInfo isEqual:a] && [wifi.currentProfileId isEqual:@"a"], "WiFi constructor loads only selected profile cache");
    id token = wifi.profileChangeObserver;
    [wifi registerForProfileNotifications]; [wifi registerForProfileNotifications];
    CHECK(token && token == wifi.profileChangeObserver, "WiFi observer registration is idempotent and retains one token");
    CHECK(SetArtifactSelection(@"b"), "WiFi current selection changed to missing B");
    NSUInteger reloads = gWiFiReloads, writes = gWrites;
    [NSNotificationCenter.defaultCenter postNotificationName:@"WeaponXProfileChanged" object:nil userInfo:@{ @"ProfileId": @"b" }];
    CHECK(PumpWiFiReload(reloads + 1) && [wifi.currentProfileId isEqual:@"b"] && wifi.wifiInfo.count == 0 && gWrites == writes,
          "WiFi profile notification clears old cache on missing target without writing source");
    NSDictionary *generated = [wifi currentWiFiInfo];
    CHECK(generated.count == 6 && [wifi.currentProfileId isEqual:@"b"] &&
          [[NSDictionary dictionaryWithContentsOfFile:Path(PXProfileIdentityPath(@"b"), @"wifi_info.plist")] isEqual:generated] &&
          [[NSDictionary dictionaryWithContentsOfFile:Path(PXProfileIdentityPath(@"a"), @"wifi_info.plist")] isEqual:a],
          "WiFi missing-profile getter generates B instead of returning or overwriting A");
    writes = gWrites;
    CHECK([[wifi currentWiFiInfo] isEqual:generated] && gWrites == writes, "WiFi cached read hit adds no lifecycle or source transaction");
    NSString *bPath = Path(PXProfileIdentityPath(@"b"), @"wifi_info.plist"); NSData *saved = [NSData dataWithContentsOfFile:bPath];
    CHECK([[@"broken" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:bPath atomically:YES], "WiFi malformed file injected");
    [wifi loadWiFiInfoFromCurrentProfile];
    CHECK(wifi.wifiInfo.count == 0 && [wifi.currentProfileId isEqual:@"b"], "WiFi malformed reload clears cache instead of retaining previous data");
    CHECK([saved writeToFile:bPath atomically:YES], "WiFi malformed fixture restored");
    WiFiSpy(wifi, next);
    PXProfileLifecycleLease *owner = [PXProfileLifecycleLease acquireInDirectory:gRoot error:NULL]; CHECK(owner != nil, "WiFi competing lifecycle owner acquired");
    NSUInteger copies = gWiFiCopies, selections = gWiFiSelections; NSDictionary *before = AllArtifactFiles();
    [wifi saveWiFiInfoToCurrentProfile];
    CHECK(wifi.error.code == 12 && copies == gWiFiCopies && selections == gWiFiSelections && [before isEqual:AllArtifactFiles()],
          "busy WiFi persistence stops before target resolution snapshot and source writes");
    [owner invalidate];
    CHECK(SetArtifactIntent(YES), "WiFi pending intent seeded"); before = AllArtifactFiles();
    [wifi saveWiFiInfoToCurrentProfile];
    CHECK(wifi.error.code == 27 && copies == gWiFiCopies && selections == gWiFiSelections && [before isEqual:AllArtifactFiles()],
          "pending deletion stops WiFi persistence before cache snapshot");
    CHECK(SetArtifactIntent(NO) && SetArtifactSelection(@"c"), "WiFi pending intent cleared and legacy target selected");
    [wifi saveWiFiInfoToCurrentProfile];
    CHECK(wifi.error && copies == gWiFiCopies && ![NSFileManager.defaultManager fileExistsAtPath:PXProfileIdentityPath(@"c")],
          "WiFi persistence never recreates missing identity directory"); CheckArtifactLeaseFree();
    CHECK(SetArtifactSelection(@"a"), "WiFi selected A for captured-target test");
    gDuringWiFiWarmup = ^{ CheckArtifactLeaseFree(); };
    gDuringWiFiCopy = ^{
        CheckArtifactLeaseHeld();
        PXPreparedStorageFixture *other = [PXPreparedStorageFixture new]; NSError *busy = nil;
        CHECK(![other persistStorageToProfile:@"b" current:NO error:&busy] && busy.code == 12, "WiFi snapshot excludes reentrant storage persistence");
        CHECK(SetArtifactSelection(@"b"), "bypass writer changes active selection during WiFi copy");
    };
    [wifi saveWiFiInfoToCurrentProfile]; gDuringWiFiWarmup = nil;
    CHECK(!wifi.error && [wifi.currentProfileId isEqual:@"a"] &&
          [[NSDictionary dictionaryWithContentsOfFile:Path(PXProfileIdentityPath(@"a"), @"wifi_info.plist")] isEqual:next] &&
          [[NSDictionary dictionaryWithContentsOfFile:bPath] isEqual:generated], "WiFi persistence captures one target and never redirects during snapshot");
    CHECK([[wifi currentWiFiInfo] isEqual:generated] && [wifi.currentProfileId isEqual:@"b"], "WiFi read after source-target switch reloads actual active profile");
    CHECK(SetArtifactSelection(@"a"), "WiFi source-fault target restored"); WiFiSpy(wifi, a); before = AllArtifactFiles();
    __block BOOL interrupted = NO;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"] && !interrupted) { interrupted = YES; [NSException raise:@"fixture" format:@"WiFi fault"]; } };
    gDuringLog = ^{ CheckArtifactLeaseFree(); };
    [wifi saveWiFiInfoToCurrentProfile]; gDuringLog = nil; gStore.testCheckpoint = nil;
    CHECK(wifi.error && interrupted && [before isEqual:AllArtifactFiles()], "WiFi source failure rolls back wifi and IDs before error logging"); CheckArtifactLeaseFree();
    gDuringWiFiCopy = ^{ [NSException raise:@"fixture" format:@"WiFi copy exception"]; };
    BOOL threw = NO; @try { [wifi saveWiFiInfoToCurrentProfile]; } @catch (NSException *exception) { (void)exception; threw = YES; }
    CHECK(threw && [before isEqual:AllArtifactFiles()], "WiFi snapshot exception releases scope and preserves source"); CheckArtifactLeaseFree();
    __block NSDictionary *competitor = nil;
    gDuringWiFiCopy = ^{ CHECK(SetArtifactIntent(YES), "bypass WiFi deletion intent committed"); competitor = AllArtifactFiles(); };
    [wifi saveWiFiInfoToCurrentProfile];
    CHECK(wifi.error.code == 27 && [competitor isEqual:AllArtifactFiles()], "late journal rejects WiFi candidate before paired staging");
    CHECK(SetArtifactIntent(NO), "WiFi late intent cleared");
    for (NSUInteger kind = 0; kind < 3; kind++) {
        NSString *identity = PXProfileIdentityPath(@"a"), *old = Path(PXProfileRootPath(@"a"), @"old-wifi-identity");
        __block BOOL moved = NO; competitor = nil;
        gDuringWiFiCopy = ^{
            moved = [NSFileManager.defaultManager moveItemAtPath:identity toPath:old error:NULL];
            if (kind == 1) moved = moved && [NSFileManager.defaultManager createDirectoryAtPath:identity withIntermediateDirectories:NO attributes:nil error:NULL];
            if (kind == 2) moved = moved && [NSFileManager.defaultManager createSymbolicLinkAtPath:identity withDestinationPath:PXProfileIdentityPath(@"b") error:NULL];
            competitor = AllArtifactFiles();
        };
        [wifi saveWiFiInfoToCurrentProfile];
        CHECK(wifi.error && moved && [competitor isEqual:AllArtifactFiles()], "WiFi persistence rejects missing replaced and symlink identity without recreating it");
        if (kind != 0) CHECK([NSFileManager.defaultManager removeItemAtPath:identity error:NULL], "WiFi identity replacement fixture removed");
        CHECK([NSFileManager.defaultManager moveItemAtPath:old toPath:identity error:NULL], "WiFi original identity restored"); CheckArtifactLeaseFree();
    }
    [wifi loadWiFiInfoFromCurrentProfile]; NSDictionary *cache = [wifi.wifiInfo copy]; before = AllArtifactFiles();
    [wifi setCurrentWiFiInfo:@{ @"ssid": @"missing BSSID" }];
    CHECK(wifi.error.code == 3001 && [cache isEqual:wifi.wifiInfo] && [before isEqual:AllArtifactFiles()], "WiFi custom setter preserves required-field validation before persistence");
    [wifi setCurrentWiFiInfo:@{ @"ssid": @"Invalid MAC", @"bssid": @"00:00:00:00:00:00" }];
    CHECK(wifi.error.code == 3005 && [cache isEqual:wifi.wifiInfo] && [before isEqual:AllArtifactFiles()], "WiFi custom setter retains MAC validation and rejects all-zero address");
    [wifi setCurrentWiFiInfo:next];
    CHECK(!wifi.error && [wifi.wifiInfo isEqual:next] && [[NSDictionary dictionaryWithContentsOfFile:Path(PXProfileIdentityPath(@"a"), @"wifi_info.plist")] isEqual:next],
          "WiFi custom setter persists candidate through owned paired commit");
    // Preserve the existing optional-manager authority and file-only fallback.
    CHECK(SetArtifactSelection(@"b"), "WiFi file authority B selected"); gWiFiMemoryID = @"a";
    [wifi setCurrentWiFiInfo:a];
    CHECK(!wifi.error && [wifi.currentProfileId isEqual:@"a"] && [[NSDictionary dictionaryWithContentsOfFile:Path(PXProfileIdentityPath(@"a"), @"wifi_info.plist")] isEqual:a],
          "WiFi persistence preserves optional manager-first profile authority");
    gWiFiMemoryID = nil; gWiFiManagerAvailable = NO;
    CHECK(SetArtifactSelection(@7) && [[wifi getCurrentProfileID] isEqual:@"7"], "WiFi fallback retains numeric profile ID normalization");
    CHECK(SetArtifactSelection(nil), "WiFi no-active fallback seeded"); before = AllArtifactFiles();
    [wifi loadWiFiInfoFromCurrentProfile]; NSDictionary *ephemeral = [wifi currentWiFiInfo]; id cached = wifi.wifiInfo;
    CHECK(ephemeral.count == 6 && wifi.error && [[wifi currentWiFiInfo] isEqual:ephemeral] && wifi.wifiInfo == cached &&
          [wifi.currentProfileId isEqual:@"default"] && [before isEqual:AllArtifactFiles()], "WiFi default fallback keeps ephemeral cache without repeated generation or directory writes");
    gWiFiManagerAvailable = YES; CHECK(SetArtifactSelection(@"a"), "WiFi selected A after fallback tests");
    [wifi loadWiFiInfoFromCurrentProfile];
    __weak PXOwnedWiFiFixture *weakOwner = nil;
    @autoreleasepool {
        PXOwnedWiFiFixture *temporary = [PXOwnedWiFiFixture new]; weakOwner = temporary;
        [temporary registerForProfileNotifications];
    }
    CHECK(weakOwner == nil, "WiFi observer does not retain manager and dealloc removes its token");
    reloads = gWiFiReloads; writes = gWrites;
    [NSNotificationCenter.defaultCenter postNotificationName:@"WeaponXProfileChanged" object:nil userInfo:@{ @"ProfileId": @"c" }];
    CHECK(PumpWiFiReload(reloads + 1) && [wifi.currentProfileId isEqual:@"a"] && [wifi.wifiInfo isEqual:a] && gWrites == writes && weakOwner == nil,
          "queued WiFi notification reloads current authority and safely ignores deallocated observer owner");
}


static BOOL SeedBatteryRecord(NSString *profileID, NSString *level) {
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return PXStageRuntimeBattery(tx, PXProfileIdentityPath(profileID),
            @{ @"BatteryLevel": level, @"LowPowerMode": @YES, @"LastUpdated": NSDate.date }, error);
    } error:NULL];
}
static BOOL BatteryLegacyMirrorMatchesSource(NSDictionary *source, NSDictionary *mirror) {
    if (![source isKindOfClass:NSDictionary.class] || ![mirror isKindOfClass:NSDictionary.class]) return NO;
    // The source store writes binary plists. The legacy NSDictionary writer
    // uses XML, whose NSDate precision can differ. Compare every key/value
    // against that format's round-trip, rather than ignoring the timestamp.
    NSData *xml = [NSPropertyListSerialization dataWithPropertyList:source format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
    NSDictionary *expected = xml ? [NSPropertyListSerialization propertyListWithData:xml options:NSPropertyListImmutable format:NULL error:NULL] : nil;
    return expected != nil && [expected isEqual:mirror];
}
static void TestBatteryLegacyMirrorPrecision(void) {
    NSString *normalPath = gOwnedBatteryMirrorPath;
    gOwnedBatteryMirrorPath = Path(gRoot, @"fractional-battery-mirror.plist");
    @try {
        PXOwnedBatteryFixture *writer = [PXOwnedBatteryFixture new];
        NSDictionary *record = @{ @"BatteryLevel": @"0.62", @"LowPowerMode": @YES,
            @"LastUpdated": [NSDate dateWithTimeIntervalSince1970:1700000000.875] };
        NSError *error = nil;
        BOOL wrote = [writer mirrorBatteryRecord:record error:&error];
        NSData *data = [NSData dataWithContentsOfFile:gOwnedBatteryMirrorPath];
        NSPropertyListFormat format = 0;
        NSDictionary *mirror = data ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:&format error:&error] : nil;
        CHECK(wrote && !error && format == NSPropertyListXMLFormat_v1_0 && BatteryLegacyMirrorMatchesSource(record, mirror),
              "fractional battery timestamp matches real legacy XML round trip");
        NSMutableDictionary *changed = [mirror mutableCopy];
        changed[@"BatteryLevel"] = @"0.99";
        CHECK(!BatteryLegacyMirrorMatchesSource(record, changed), "legacy mirror oracle rejects changed battery level");
        changed = [mirror mutableCopy]; changed[@"LowPowerMode"] = @NO;
        CHECK(!BatteryLegacyMirrorMatchesSource(record, changed), "legacy mirror oracle rejects changed low power mode");
        changed = [mirror mutableCopy]; changed[@"LastUpdated"] = [record[@"LastUpdated"] dateByAddingTimeInterval:1];
        CHECK(!BatteryLegacyMirrorMatchesSource(record, changed), "legacy mirror oracle rejects different timestamp beyond XML precision");
        changed = [mirror mutableCopy]; [changed removeObjectForKey:@"LastUpdated"];
        CHECK(!BatteryLegacyMirrorMatchesSource(record, changed), "legacy mirror oracle rejects omitted timestamp");
        changed = [mirror mutableCopy]; changed[@"unexpected"] = @YES;
        CHECK(!BatteryLegacyMirrorMatchesSource(record, changed), "legacy mirror oracle rejects extra fields");
    } @finally { gOwnedBatteryMirrorPath = normalPath; }
}
static void TestBatteryLifecycle(void) {
    Tape(@[]);
    gOwnedBatteryMirrorPath = Path(gRoot, @"owned-battery-global.plist");
    PXObservedBatteryFixture *battery = [PXObservedBatteryFixture new];
    CHECK(SetArtifactSelection(@"a"), "battery active target selected");
    gDuringBatteryMirror = ^(NSDictionary *record) {
        CheckArtifactLeaseFree(); CHECK(AllArtifactFiles() != nil, "battery mirror runs outside source gate");
        NSDictionary *selection = [NSDictionary dictionaryWithContentsOfFile:PXCurrentProfileInfoPath()];
        NSString *profileID = PXValidatedProfileID(selection[@"ProfileId"]);
        if (profileID) {
            NSDictionary *source = [NSDictionary dictionaryWithContentsOfFile:Path(PXProfileIdentityPath(profileID), @"battery_info.plist")];
            CHECK([source isEqual:record], "battery profile commit precedes global mirror with the same captured record");
        }
    };
    id observer = [NSNotificationCenter.defaultCenter addObserverForName:@"BatteryInfoUpdated" object:battery queue:nil usingBlock:^(NSNotification *note) {
        gOwnedBatteryLocal++; CheckArtifactLeaseFree();
        if (gDuringBatteryNotice) gDuringBatteryNotice(note.userInfo);
    }];
    gDuringBatteryNotice = ^(NSDictionary *info) {
        NSDictionary *source = [NSDictionary dictionaryWithContentsOfFile:Path(PXProfileIdentityPath(@"a"), @"battery_info.plist")];
        CHECK([source[@"BatteryLevel"] isEqual:info[@"BatteryLevel"]] &&
              [source[@"LowPowerMode"] isEqual:info[@"LowPowerMode"]], "battery notifications follow committed profile values");
    };
    __block NSUInteger commits = 0;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"commit-written"]) commits++; };
    NSDictionary *generated = [battery generateBatteryInfo];
    gStore.testCheckpoint = nil;
    NSDictionary *source = [NSDictionary dictionaryWithContentsOfFile:Path(PXProfileIdentityPath(@"a"), @"battery_info.plist")];
    NSDictionary *mirror = [NSDictionary dictionaryWithContentsOfFile:gOwnedBatteryMirrorPath];
    BOOL generationOK = commits == 1 && !battery.error && generated[@"BatteryPercentage"] &&
        gOwnedBatteryLocal == 1 && gOwnedBatteryDarwin == 1;
    BOOL mirrorOK = BatteryLegacyMirrorMatchesSource(source, mirror);
    CHECK(generationOK, "battery generation commits once before mirror and both notifications");
    CHECK(mirrorOK, "battery legacy mirror preserves complete source record at XML precision");
    if (!generationOK || !mirrorOK) {
        id sourceDate = source[@"LastUpdated"], mirrorDate = mirror[@"LastUpdated"];
        fprintf(stderr, "Battery generation diagnostic: commits=%lu local=%lu darwin=%lu error=%s percentage=%s sourceTime=%.9f mirrorTime=%.9f mirrorMatch=%d\n",
            (unsigned long)commits, (unsigned long)gOwnedBatteryLocal, (unsigned long)gOwnedBatteryDarwin,
            battery.error.description.UTF8String ?: "none", [generated[@"BatteryPercentage"] description].UTF8String ?: "missing",
            [sourceDate isKindOfClass:NSDate.class] ? [sourceDate timeIntervalSince1970] : NAN,
            [mirrorDate isKindOfClass:NSDate.class] ? [mirrorDate timeIntervalSince1970] : NAN, (int)mirrorOK);
    }
    TestBatteryLegacyMirrorPrecision();
    NSUInteger local = gOwnedBatteryLocal, darwin = gOwnedBatteryDarwin, mirrors = gOwnedBatteryMirrors;
    NSDictionary *before = AllArtifactFiles();
    PXProfileLifecycleLease *owner = [PXProfileLifecycleLease acquireInDirectory:gRoot error:NULL];
    CHECK(owner != nil, "battery competing lifecycle owner acquired");
    NSDictionary *candidate = [battery generateBatteryInfo]; [battery setLowPowerModeEnabled:YES];
    CHECK(candidate[@"BatteryPercentage"] && battery.error.code == 12 && mirrors == gOwnedBatteryMirrors &&
          local == gOwnedBatteryLocal && darwin == gOwnedBatteryDarwin && [before isEqual:AllArtifactFiles()],
          "busy battery leaves profile mirror and notifications untouched while returning legacy candidate");
    [owner invalidate];
    CHECK(SetArtifactIntent(YES), "battery pending deletion intent seeded"); before = AllArtifactFiles();
    [battery generateBatteryInfo]; [battery setLowPowerModeEnabled:NO];
    CHECK(battery.error.code == 27 && mirrors == gOwnedBatteryMirrors && local == gOwnedBatteryLocal &&
          darwin == gOwnedBatteryDarwin && [before isEqual:AllArtifactFiles()], "pending delete blocks battery source mirror and notifications");
    CHECK(SetArtifactIntent(NO) && SetArtifactSelection(@7), "battery invalid canonical ID selected"); before = AllArtifactFiles();
    [battery generateBatteryInfo];
    CHECK(battery.error.code == 100 && mirrors == gOwnedBatteryMirrors && local == gOwnedBatteryLocal &&
          [before isEqual:AllArtifactFiles()], "invalid active battery ID never downgrades into global-only success");
    CHECK(SetArtifactSelection(@"c"), "battery legacy identity-missing target selected"); before = AllArtifactFiles();
    [battery generateBatteryInfo];
    CHECK(battery.error && mirrors == gOwnedBatteryMirrors && local == gOwnedBatteryLocal && [before isEqual:AllArtifactFiles()] &&
          ![NSFileManager.defaultManager fileExistsAtPath:PXProfileIdentityPath(@"c")], "missing battery identity cannot create directory or update global mirror");
    CHECK(SetArtifactSelection(@"a"), "battery source-fault target restored"); before = AllArtifactFiles();
    __block BOOL interrupted = NO;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"] && !interrupted) { interrupted = YES; [NSException raise:@"fixture" format:@"battery write failure"]; } };
    [battery generateBatteryInfo]; gStore.testCheckpoint = nil;
    CHECK(interrupted && battery.error && [before isEqual:AllArtifactFiles()] && mirrors == gOwnedBatteryMirrors &&
          local == gOwnedBatteryLocal && darwin == gOwnedBatteryDarwin, "battery source rollback preserves old mirror and suppresses success notifications"); CheckArtifactLeaseFree();
    // A legacy mirror error cannot turn an already committed source into a
    // reported rollback. Exercise the real filesystem failure, not a fake save.
    NSString *normalMirror = gOwnedBatteryMirrorPath, *blocker = Path(gRoot, @"battery-mirror-blocker");
    CHECK([[@"file" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:blocker atomically:YES], "battery mirror blocking file created");
    NSData *oldMirror = [NSData dataWithContentsOfFile:normalMirror];
    gOwnedBatteryMirrorPath = Path(blocker, @"mirror.plist");
    [battery generateBatteryInfo];
    CHECK(!battery.error && gOwnedBatteryLocal == local + 1 && gOwnedBatteryDarwin == darwin + 1 &&
          [[NSData dataWithContentsOfFile:normalMirror] isEqual:oldMirror], "profile battery success survives failed legacy mirror without false rollback");
    local = gOwnedBatteryLocal; darwin = gOwnedBatteryDarwin;
    gDuringBatteryNotice = nil;
    CHECK(SetArtifactSelection(nil), "battery no-active global-only branch selected");
    before = AllArtifactFiles();
    [battery generateBatteryInfo];
    CHECK(battery.error && local == gOwnedBatteryLocal && darwin == gOwnedBatteryDarwin && [before isEqual:AllArtifactFiles()],
          "global-only battery mirror failure is not announced as persisted success");
    gOwnedBatteryMirrorPath = normalMirror;
    commits = 0;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"commit-written"]) commits++; };
    [battery setLowPowerModeEnabled:YES]; gStore.testCheckpoint = nil;
    mirror = [NSDictionary dictionaryWithContentsOfFile:normalMirror];
    CHECK(!battery.error && commits == 0 && [mirror[@"LowPowerMode"] boolValue] &&
          gOwnedBatteryLocal == local + 1 && gOwnedBatteryDarwin == darwin + 1,
          "no-active battery preserves coordinated global-only save without profile source commit");
    local = gOwnedBatteryLocal; darwin = gOwnedBatteryDarwin;
    // Read helper is pure: preserve pre-identity and global fallback, including
    // the legacy missing-LPM default, without recreating a directory on read.
    CHECK(SetArtifactSelection(@"c"), "battery legacy profile selected for read");
    CHECK([gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx setDictionary:@{ @"BatteryLevel": @"0.61" } atPath:Path(PXProfileRootPath(@"c"), @"battery_info.plist") error:error];
    } error:NULL], "legacy pre-identity battery record seeded");
    NSUInteger writes = gWrites;
    CHECK([[battery batteryLevel] isEqual:@"0.61"] && ![battery lowPowerModeEnabled] && gWrites == writes &&
          ![NSFileManager.defaultManager fileExistsAtPath:PXProfileIdentityPath(@"c")], "battery read preserves legacy fallback and missing LPM default without directory writes or lease");
    CHECK(SetArtifactSelection(@"a"), "battery captured record target restored");
    NSMutableString *mutableLevel = [@"0.62" mutableCopy];
    NSDictionary *record = [battery batteryRecordForLevel:mutableLevel lowPowerMode:YES]; [mutableLevel setString:@"0.10"];
    CHECK([battery persistBatteryRecord:record] && !battery.error &&
          [[NSDictionary dictionaryWithContentsOfFile:normalMirror][@"BatteryLevel"] isEqual:@"0.62"], "battery captures immutable level once for profile and mirror");
    CHECK(local == gOwnedBatteryLocal && darwin == gOwnedBatteryDarwin, "plain battery persistence does not add batch notifications");
    for (NSString *invalid in @[@"", @"2.0"]) {
        CHECK(SeedBatteryRecord(@"a", invalid), "invalid legacy battery level seeded for repair");
        commits = 0; mirrors = gOwnedBatteryMirrors;
        gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"commit-written"]) commits++; };
        NSString *repaired = [battery batteryLevel]; gStore.testCheckpoint = nil;
        CHECK(repaired.floatValue >= 0.05 && repaired.floatValue <= 1 && commits == 1 && gOwnedBatteryMirrors == mirrors + 1 &&
              local == gOwnedBatteryLocal && darwin == gOwnedBatteryDarwin, "battery getter repair performs one save instead of duplicate persistence");
    }
    CHECK(SetArtifactSelection(@"b"), "battery IDs-absence policy target selected");
    CHECK([gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx removeDictionaryAtPath:Path(PXProfileIdentityPath(@"b"), @"device_ids.plist") error:error];
    } error:NULL], "battery target device IDs removed by fixture");
    CHECK([battery persistBatteryRecord:record] && ![NSFileManager.defaultManager fileExistsAtPath:Path(PXProfileIdentityPath(@"b"), @"device_ids.plist")],
          "owned battery persistence retains no-new-device-IDs policy");
    before = AllArtifactFiles(); mirrors = gOwnedBatteryMirrors;
    [battery setBatteryLevel:nil]; [battery setLowPowerModeEnabled:YES];
    CHECK(battery.error.code == 103 && mirrors == gOwnedBatteryMirrors && local == gOwnedBatteryLocal && darwin == gOwnedBatteryDarwin &&
          [before isEqual:AllArtifactFiles()], "missing battery record reports failure without mirror or success notification");
    [battery adoptCommittedBatteryInfo:record];
    NSString *availableRoot = gRoot; oldMirror = [NSData dataWithContentsOfFile:normalMirror];
    gRoot = Path(availableRoot, @"unavailable-profiles-root");
    @try {
        writes = gWrites;
        CHECK([[battery batteryLevel] isEqual:@"0.62"] && gWrites == writes, "battery global read fallback works when profiles root is unavailable");
        mirrors = gOwnedBatteryMirrors;
        [battery generateBatteryInfo];
        CHECK(battery.error && mirrors == gOwnedBatteryMirrors && local == gOwnedBatteryLocal && darwin == gOwnedBatteryDarwin &&
              [[NSData dataWithContentsOfFile:normalMirror] isEqual:oldMirror] && ![NSFileManager.defaultManager fileExistsAtPath:gRoot],
              "battery mutation refuses unavailable lifecycle namespace without creating root or changing mirror");
    } @finally { gRoot = availableRoot; }
    CHECK(SetArtifactSelection(@"a"), "battery selection restored after unavailable namespace test");
    gDuringBatteryMirror = nil; gDuringBatteryNotice = nil;
    [NSNotificationCenter.defaultCenter removeObserver:observer];
    CheckArtifactLeaseFree();
}

static void TestBorrowedArtifactScope(void) {
    NSError *error = nil;
    PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:gRoot error:&error];
    CHECK(lease && !error, "borrowed artifact parent lease acquired");
    PXProfileArtifactMutation *scope = [PXProfileArtifactMutation borrowWithLifecycleLease:lease identityResolver:^NSString *{ return PXProfileIdentityPath(@"a"); } error:&error];
    CHECK(scope && !error, "borrowed artifact scope does not recursively acquire lifecycle");
    CHECK([scope performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return PXStageRuntimeBattery(tx, scope.identityDirectory, @{ @"BatteryLevel": @"0.42", @"LowPowerMode": @NO, @"LastUpdated": NSDate.date }, writeError);
    } error:&error], "borrowed artifact scope uses real staging and source commit");
    [scope invalidate];
    CHECK([lease validateForDirectory:gRoot error:&error], "borrowed artifact invalidation preserves caller lifecycle ownership");
    __block BOOL entered = NO;
    CHECK(![scope performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        (void)tx; (void)writeError; entered = YES; return YES;
    } error:&error] && !entered && [lease validateWithError:NULL], "invalidated borrowed scope rejects work without ending caller lease");
    scope = [PXProfileArtifactMutation borrowWithLifecycleLease:lease identityResolver:^NSString *{ return nil; } error:&error];
    CHECK(!scope && error && [lease validateWithError:NULL], "failed borrowed artifact resolution leaves caller ownership intact");
    BOOL threw = NO;
    @try { scope = [PXProfileArtifactMutation borrowWithLifecycleLease:lease identityResolver:^NSString *{ [NSException raise:@"fixture" format:@"borrowed resolver exception"]; return nil; } error:&error]; }
    @catch (NSException *exception) { (void)exception; threw = YES; }
    CHECK(threw && [lease validateWithError:NULL], "throwing borrowed artifact resolver cannot release caller lease");
    scope = [PXProfileArtifactMutation borrowWithLifecycleLease:nil identityResolver:^NSString *{ return PXProfileIdentityPath(@"a"); } error:&error];
    CHECK(!scope && error.code == 25 && [lease validateWithError:NULL], "nil borrowed capability never silently acquires an owned lease");
    scope = [PXProfileArtifactMutation borrowWithLifecycleLease:lease identityResolver:^NSString *{ return PXProfileIdentityPath(@"a"); } error:&error];
    CHECK(scope != nil, "borrowed scope reacquired for namespace guard");
    NSString *identity = PXProfileIdentityPath(@"a"), *old = Path(PXProfileRootPath(@"a"), @"old-borrowed-identity");
    CHECK([NSFileManager.defaultManager moveItemAtPath:identity toPath:old error:NULL] &&
          [NSFileManager.defaultManager createDirectoryAtPath:identity withIntermediateDirectories:NO attributes:nil error:NULL], "borrowed namespace replacement fixture prepared");
    NSDictionary *before = AllArtifactFiles(); entered = NO;
    CHECK(![scope performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        (void)tx; (void)writeError; entered = YES; return YES;
    } error:&error] && !entered && [before isEqual:AllArtifactFiles()] && [lease validateWithError:NULL],
          "borrowed artifact scope rejects replaced identity while keeping caller lease");
    [scope invalidate];
    CHECK([NSFileManager.defaultManager removeItemAtPath:identity error:NULL] &&
          [NSFileManager.defaultManager moveItemAtPath:old toPath:identity error:NULL], "borrowed identity fixture restored");
    scope = [PXProfileArtifactMutation borrowWithLifecycleLease:lease identityResolver:^NSString *{ return PXProfileIdentityPath(@"a"); } error:&error];
    CHECK(scope && SetArtifactIntent(YES), "borrowed late journal fixture seeded"); entered = NO; before = AllArtifactFiles();
    CHECK(![scope performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        (void)tx; (void)writeError; entered = YES; return YES;
    } error:&error] && error.code == 27 && !entered && [before isEqual:AllArtifactFiles()], "borrowed artifact scope rejects late deletion before staging");
    [scope invalidate]; CHECK(SetArtifactIntent(NO), "borrowed pending journal cleared");
    PXProfileLifecycleLease *wrong = [PXProfileLifecycleLease acquireInDirectory:PXProfileRootPath(@"c") error:NULL];
    scope = [PXProfileArtifactMutation borrowWithLifecycleLease:wrong identityResolver:^NSString *{ return PXProfileIdentityPath(@"a"); } error:&error];
    CHECK(wrong && !scope && error && [wrong validateWithError:NULL], "wrong-root borrowed artifact capability is rejected without invalidating it");
    [wrong invalidate]; [lease invalidate];
    scope = [PXProfileArtifactMutation borrowWithLifecycleLease:lease identityResolver:^NSString *{ return PXProfileIdentityPath(@"a"); } error:&error];
    CHECK(!scope && error, "released borrowed artifact capability is rejected"); CheckArtifactLeaseFree();
}

int main(void) {
    @autoreleasepool {
        gRoot = Path(NSTemporaryDirectory(), NSUUID.UUID.UUIDString);
        for (NSString *profile in @[@"a", @"b"])
            [NSFileManager.defaultManager createDirectoryAtPath:PXProfileIdentityPath(profile) withIntermediateDirectories:YES attributes:nil error:nil];
        gStore = [[PXRuntimeSourceStore alloc] initWithDirectory:Path(gRoot, @"control") owner:geteuid() group:getegid()
            allowsPath:^BOOL(NSString *path) { return [path hasPrefix:[gRoot stringByAppendingString:@"/"]] && [path hasSuffix:@".plist"] && ![path hasPrefix:Path(gRoot, @"control/")]; } error:NULL];
        CHECK(gStore != nil && [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
            return [tx setDictionary:@{ @"keep": @YES } atPath:Path(PXProfileIdentityPath(@"a"), @"device_ids.plist") error:error];
        } error:NULL], "preparation source backend seeded");
        TestPurePreparation(); TestManagerWrappers(); TestCompositionAndUptime(); TestStorageLifecycle(); TestStorageDisplayCommit(); TestStorageReadBoundaries(); TestStoragePreferenceWriters(); TestUptimeLifecycle(); TestWiFiLifecycle(); TestBatteryLifecycle(); TestBorrowedArtifactScope(); TestUptimeReadOnly();
        gStore = nil; [NSFileManager.defaultManager removeItemAtPath:gRoot error:nil];
        printf("Runtime artifact preparation: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
