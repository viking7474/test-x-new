#import <Foundation/Foundation.h>
#include <math.h>
#include <stdio.h>
static NSUInteger gChecks, gFailures, gReads, gRepairs, gLogs;
static NSMutableDictionary *gFiles;
static NSMutableArray *gReadPaths;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PXLog(...) do { gLogs++; } while (0)
#define BATTERY_PLIST_PATH @"/fixture/global.plist"
#define kBatteryLevelKey @"BatteryLevel"
#define kLowPowerModeKey @"LowPowerMode"
#define kLastUpdatedKey @"LastUpdated"
static NSString *PXCurrentProfileInfoPath(void) { return @"/fixture/selection.plist"; }
static NSString *PXValidatedProfileID(id value) { return [value isKindOfClass:NSString.class] && [value isEqual:@"a"] ? value : nil; }
static NSString *PXProfileIdentityPath(NSString *profile) { return profile ? @"/fixture/a/identity" : nil; }
@interface NSDictionary (BatteryReaderFixture)
+ (instancetype)px_batteryRead:(NSString *)path;
@end
@implementation NSDictionary (BatteryReaderFixture)
+ (instancetype)px_batteryRead:(NSString *)path { gReads++; [gReadPaths addObject:path]; return gFiles[path]; }
@end
@interface PXNonfiniteBatteryValue : NSObject <NSCopying>
@end
@implementation PXNonfiniteBatteryValue
- (BOOL)isKindOfClass:(Class)type { return type == NSString.class || [super isKindOfClass:type]; }
- (id)copyWithZone:(NSZone *)zone { (void)zone; return self; }
- (NSUInteger)length { return 3; }
- (float)floatValue { return NAN; }
@end
#include "PXBatteryCacheFields.inc"
@interface PXBatteryReader : NSObject {
    NSString *_currentBatteryLevel;
    BOOL _currentLowPowerMode, _lowPowerModeLoaded;
}
@property (atomic, strong) NSError *error;
#include "PXBatteryCacheDeclarations.inc"
#include "PXBatteryReaderDeclarations.inc"
- (NSString *)randomizeBatteryLevelAtMutation:(uint64_t)mutation;
- (NSString *)generateBatteryLevel;
- (void)seedLevel:(id)level lowPower:(BOOL)enabled loaded:(BOOL)loaded;
- (id)cachedLevel;
- (BOOL)cachedLowPower;
- (BOOL)lowPowerLoaded;
@end
@implementation PXBatteryReader
@synthesize error = _error;
- (void)seedLevel:(id)level lowPower:(BOOL)enabled loaded:(BOOL)loaded {
    _currentBatteryLevel = level; _currentLowPowerMode = enabled; _lowPowerModeLoaded = loaded;
}
- (id)cachedLevel { return _currentBatteryLevel; }
- (BOOL)cachedLowPower { return _currentLowPowerMode; }
- (BOOL)lowPowerLoaded { return _lowPowerModeLoaded; }
- (NSString *)generateBatteryLevel { return [self randomizeBatteryLevelAtMutation:[self beginBatteryMutation]]; }
- (NSString *)randomizeBatteryLevelAtMutation:(uint64_t)mutation {
    gRepairs++;
    [self publishBatteryLevel:@"0.42" lowPowerMode:NO loaded:NO fields:PXBatteryCacheLevel mutation:mutation resultLevel:NULL resultLowPowerMode:NULL];
    [self finishBatteryMutation:mutation];
    return @"0.42";
}
#include "PXBatteryCacheMethods.inc"
#define dictionaryWithContentsOfFile px_batteryRead
#include "PXBatteryReaderMethods.inc"
#undef dictionaryWithContentsOfFile
@end
static NSString *Canonical(void) { return @"/fixture/a/identity/battery_info.plist"; }
static NSString *Legacy(void) { return @"/fixture/a/battery_info.plist"; }
static PXBatteryReader *Reset(void) {
    gFiles = [NSMutableDictionary new]; gReadPaths = [NSMutableArray new]; gReads = gRepairs = gLogs = 0;
    gFiles[PXCurrentProfileInfoPath()] = @{ @"ProfileId": @"a" };
    PXBatteryReader *reader = [PXBatteryReader new]; [reader seedLevel:@"0.60" lowPower:YES loaded:YES]; return reader;
}
static void TestPrecedence(void) {
    PXBatteryReader *reader = Reset();
    gFiles[Canonical()] = @{ @"BatteryLevel": @" 0.61 ", @"LowPowerMode": @NO };
    gFiles[Legacy()] = @{ @"BatteryLevel": @"0.73", @"LowPowerMode": @YES };
    gFiles[BATTERY_PLIST_PATH] = @{ @"BatteryLevel": @"0.90", @"LowPowerMode": @YES };
    [reader loadBatteryInfoFromDisk];
    CHECK([[reader cachedLevel] isEqual:@" 0.61 "] && ![reader cachedLowPower] && [reader lowPowerLoaded] && gReads == 2 && !gRepairs,
          "battery canonical record preserves spelling and explicit false without lower-priority reads");
    [gFiles removeObjectForKey:Canonical()]; [reader loadBatteryInfoFromDisk];
    CHECK([[reader cachedLevel] isEqual:@"0.73"] && [reader cachedLowPower] && gReads == 5, "battery missing canonical retains legacy fallback order");
    [gFiles removeObjectForKey:Legacy()]; [reader loadBatteryInfoFromDisk];
    CHECK([[reader cachedLevel] isEqual:@"0.90"] && gReads == 9, "battery missing profile records retains global fallback order");
    gFiles[Canonical()] = @{}; [reader loadBatteryInfoFromDisk];
    CHECK([[reader cachedLevel] isEqual:@"0.90"] && ![reader cachedLowPower] && [reader lowPowerLoaded] && gReads == 11,
          "battery empty profile record retains cached level and resets LPM without global field merge");
    for (id selection in @[@{}, @{ @"ProfileId": @7 }, @[], NSNull.null]) {
        gFiles[PXCurrentProfileInfoPath()] = selection; [gReadPaths removeAllObjects];
        [reader loadBatteryInfoFromDisk];
        CHECK(gReadPaths.count == 2 && [gReadPaths.lastObject isEqual:BATTERY_PLIST_PATH] && [[reader cachedLevel] isEqual:@"0.90"],
              "battery absent invalid or numeric selection retains global read fallback without selecting another profile");
    }
}
static void TestScalarFields(void) {
    for (id invalid in @[@[], @{}, NSDate.date, [NSData data], NSNull.null]) {
        PXBatteryReader *reader = Reset(); gFiles[Canonical()] = @{ @"BatteryLevel": invalid, @"LowPowerMode": invalid };
        [reader loadBatteryInfoFromDisk];
        CHECK([[reader cachedLevel] isEqual:@"0.60"] && ![reader cachedLowPower] && [reader lowPowerLoaded] && !gRepairs,
              "battery unsupported profile fields follow missing-field policy without unsafe selectors or generation");
        [gFiles removeObjectForKey:Canonical()]; gFiles[BATTERY_PLIST_PATH] = @{ @"BatteryLevel": invalid, @"LowPowerMode": invalid };
        [reader seedLevel:@"0.60" lowPower:YES loaded:YES]; [reader loadBatteryInfoFromDisk];
        CHECK([[reader cachedLevel] isEqual:@"0.60"] && [reader cachedLowPower] && [reader lowPowerLoaded],
              "battery unsupported global fields preserve an already loaded LPM");
        [reader seedLevel:@"0.60" lowPower:YES loaded:NO]; [reader loadBatteryInfoFromDisk];
        CHECK(![reader cachedLowPower] && ![reader lowPowerLoaded], "battery global missing LPM retains the not-loaded default policy");
    }
    for (id scalar in @[@0.625, @YES, @"0.625", @" 0.625 "]) {
        PXBatteryReader *reader = Reset(); gFiles[Canonical()] = @{ @"BatteryLevel": scalar, @"LowPowerMode": @"YES" };
        NSString *expected = [scalar isKindOfClass:NSString.class] ? scalar : [scalar stringValue];
        CHECK([[reader batteryLevel] isEqual:expected] && [reader cachedLowPower] && !gRepairs,
              "battery strings keep spelling numeric levels become strings and string bool conversion remains compatible");
    }
    PXBatteryReader *reader = Reset(); NSMutableString *mutable = [@"0.62" mutableCopy];
    gFiles[Canonical()] = @{ @"BatteryLevel": mutable };
    [reader loadBatteryInfoFromDisk]; [mutable setString:@"0.20"];
    CHECK([[reader cachedLevel] isEqual:@"0.62"], "battery loaded level is detached from a mutable input string");
}
static void TestRepair(void) {
    for (NSString *valid in @[@"0.01", @"1.0", @"0.5"]) {
        PXBatteryReader *reader = Reset(); gFiles[Canonical()] = @{ @"BatteryLevel": valid };
        CHECK([[reader batteryLevel] isEqual:valid] && !gRepairs, "battery float endpoints include exact one-percent without regeneration");
    }
    for (id invalid in @[@"", @"0", @"1.01", @"-0.3", @"garbage", @"nan", @"inf", [PXNonfiniteBatteryValue new]]) {
        PXBatteryReader *reader = Reset(); gFiles[Canonical()] = @{ @"BatteryLevel": invalid };
        CHECK([[reader batteryLevel] isEqual:@"0.42"] && gRepairs == 1,
              "battery invalid or nonfinite level takes one existing generation path");
    }
    PXBatteryReader *reader = Reset(); [reader seedLevel:NSNull.null lowPower:NO loaded:NO]; gFiles[Canonical()] = @{};
    CHECK([[reader batteryLevel] isEqual:@"0.42"] && gRepairs == 1, "battery poisoned cache is repaired before string selectors");
}
int main(void) {
    @autoreleasepool {
        @try { TestPrecedence(); TestScalarFields(); TestRepair(); }
        @catch (NSException *exception) { gFailures++; fprintf(stderr, "FAIL: unexpected battery reader exception: %s\n", exception.description.UTF8String); }
        printf("Battery reader: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
