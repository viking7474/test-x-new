#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#import "PXRuntimeArtifactPreparation.h"
#import "PXRuntimeArtifactWriter.h"
#import "PXProfileArtifactMutation.h"
#import "PXProfileLifecycleLease.h"
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
static NSString *gRoot;
static PXRuntimeSourceStore *gStore;
static NSArray<NSNumber *> *gTape;
static NSUInteger gTapeIndex;
static BOOL gHigh;
static NSUInteger gUptimeProviders, gStorageCopies, gWiFiSelections, gWiFiCopies, gWiFiReloads;
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
NSString *PXLegacyActiveProfileInfoPath(void) { return Path(gRoot, @"legacy_selection.plist"); }
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
- (void)adoptCommittedBatteryInfo:(NSDictionary *)batteryInfo;
- (void)publishCommittedBatteryInfo:(NSDictionary *)batteryInfo timestamp:(NSDate *)timestamp;
@end
@implementation PXPreparedBatteryFixture
- (void)saveBatteryInfoToDisk { gBatterySaves++; CHECK(_currentBatteryLevel.length > 0, "battery cache ready before legacy save"); }
- (void)setFixtureLowPowerMode:(BOOL)value { _currentLowPowerMode = value; }
- (NSString *)fixtureLevel { return _currentBatteryLevel; }
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

@interface PXPreparedStorageFixture : NSObject {
    NSMutableDictionary *_storageSettings;
}
- (NSDictionary *)generateStorageForCapacity:(NSString *)capacity;
- (void)adoptCommittedStorageInfo:(NSDictionary *)storageInfo;
- (NSDictionary *)fixtureStorage;
- (void)setFixtureSnapshot:(NSDictionary *)record;
- (void)saveToCurrentProfile;
- (void)saveToProfile:(NSString *)profileId;
- (BOOL)persistStorageToProfile:(NSString *)profileID current:(BOOL)current error:(NSError **)error;
- (void)setTotalStorageCapacity:(NSString *)capacity;
- (void)setFreeStorageSpace:(NSString *)freeSpace;
- (void)setFilesystemType:(NSString *)fsType;
@end
@implementation PXPreparedStorageFixture
- (NSDictionary *)fixtureStorage { return _storageSettings; }
- (void)setFixtureSnapshot:(NSDictionary *)record {
    PXStorageSnapshotFixture *spy = [PXStorageSnapshotFixture new]; spy.record = record; _storageSettings = (id)spy;
}
#include "PXPreparedStorageMethod.inc"
@end

@interface PXPreparedUptimeFixture : NSObject
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSDate *bootTimeValue;
@property (nonatomic) NSTimeInterval uptimeValue;
@property (nonatomic, strong) NSDate *cacheTime;
- (void)generateConsistentUptimeAndBootTimeForProfile:(NSString *)path;
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
          [[storage fixtureStorage] isEqual:storageInfo] && [uptime.cacheTime isEqual:now] &&
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
        TestPurePreparation(); TestManagerWrappers(); TestCompositionAndUptime(); TestStorageLifecycle(); TestUptimeLifecycle(); TestWiFiLifecycle();
        gStore = nil; [NSFileManager.defaultManager removeItemAtPath:gRoot error:nil];
        printf("Runtime artifact preparation: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
