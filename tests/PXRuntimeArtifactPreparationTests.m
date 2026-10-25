#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import "PXRuntimeArtifactPreparation.h"
#import "PXRuntimeArtifactWriter.h"
#import "PXIdentityValidator.h"
#import "PXPaths.h"
#import "TLinkIOSLogging.h"
#include <sys/sysctl.h>
#include <sys/time.h>
#include <stdlib.h>
#include <math.h>
#include <unistd.h>

static NSUInteger gChecks, gFailures, gWrites, gBatterySaves, gDarwin, gLocal, gWiFiSaves;
static NSString *gRoot;
static PXRuntimeSourceStore *gStore;
static NSArray<NSNumber *> *gTape;
static NSUInteger gTapeIndex;
static BOOL gHigh;
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
NSString *PXProfileIdentityPath(NSString *profile) {
    return [@[@"a", @"b"] containsObject:profile] ? Path(Path(gRoot, profile), @"identity") : nil;
}
BOOL PXPerformRuntimeSourceWrite(BOOL (^body)(PXRuntimeSourceTransaction *, NSError **), NSError **error) {
    gWrites++; return [gStore performWrite:body error:error];
}
void PXLog(NSString *format, ...) { (void)format; }
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
@property (nonatomic, strong) NSError *error;
- (NSDictionary *)generateWiFiInfo;
- (void)saveWiFiInfoToCurrentProfile;
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
}
- (NSDictionary *)generateBatteryInfo;
- (NSString *)randomizeBatteryLevel;
- (void)saveBatteryInfoToDisk;
- (void)setFixtureLowPowerMode:(BOOL)value;
- (NSString *)fixtureLevel;
@end
@implementation PXPreparedBatteryFixture
- (void)saveBatteryInfoToDisk { gBatterySaves++; CHECK(_currentBatteryLevel.length > 0, "battery cache ready before legacy save"); }
- (void)setFixtureLowPowerMode:(BOOL)value { _currentLowPowerMode = value; }
- (NSString *)fixtureLevel { return _currentBatteryLevel; }
// Notification delivery is a fixture backend; do not broadcast production IPC.
#define CFNotificationCenterPostNotification PXFixtureDarwin
#define CFNotificationCenterGetDarwinNotifyCenter() NULL
#define kBatteryLevelKey @"BatteryLevel"
#include "PXPreparedBatteryMethods.inc"
#undef kBatteryLevelKey
#undef CFNotificationCenterGetDarwinNotifyCenter
#undef CFNotificationCenterPostNotification
@end

@interface PXPreparedStorageFixture : NSObject
- (NSDictionary *)generateStorageForCapacity:(NSString *)capacity;
@end
@implementation PXPreparedStorageFixture
#include "PXPreparedStorageMethod.inc"
@end

@interface PXPreparedUptimeFixture : NSObject
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSDate *bootTimeValue;
@property (nonatomic) NSTimeInterval uptimeValue;
@property (nonatomic, strong) NSDate *cacheTime;
- (void)generateConsistentUptimeAndBootTimeForProfile:(NSString *)path;
@end
@implementation PXPreparedUptimeFixture
#include "PXPreparedUptimeMethod.inc"
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
        TestPurePreparation(); TestManagerWrappers(); TestCompositionAndUptime();
        gStore = nil; [NSFileManager.defaultManager removeItemAtPath:gRoot error:nil];
        printf("Runtime artifact preparation: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
