#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "PXRuntimeSnapshotReader.h"
#import "PXIdentitySnapshot.h"
#include <stdio.h>

// Exact production reader bodies; providers, role, path and captures are controlled
// collaborators. This is not an injection, lexical-scope or device runtime test.
static NSUInteger gChecks, gFailures, gPaths, gCaptures, gOperations, gFallbacks, gSaves;
static BOOL gManager = YES;
static NSString *gDirectory;
static PXRuntimeReadSnapshot *gView;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
static NSString *File(NSString *name) { return [gDirectory stringByAppendingPathComponent:name]; }
static void Put(NSString *name, NSDictionary *record) {
    CHECK([record writeToFile:File(name) atomically:YES], "reader fixture plist written");
}
static NSString *PXSecuritySettingsPath(void) { return File(@"security.plist"); }
static void PXLog(NSString *format, ...) { (void)format; }
static BOOL PXIdentifierManagerIsManagerProcess(void) { return gManager; }
static PXRuntimeReadSnapshot *PXCaptureRuntimeSnapshot(void) { gCaptures++; return gView; }
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
#define PX_IDENTIFIER_RUNTIME_READ_OPERATION do { if (!gManager) gOperations++; } while (0)
#else
#define PX_IDENTIFIER_RUNTIME_READ_OPERATION ((void)0)
#endif

@interface PXReaderIdentity : NSObject
@property (nonatomic, getter=isValid) BOOL valid;
@property (nonatomic, copy) NSDictionary *deviceIDs;
@end
@implementation PXReaderIdentity
@end
static PXReaderIdentity *gIdentity;
static PXIdentitySnapshot *PXFixtureCurrentIdentitySnapshot(void) { gCaptures++; return (id)gIdentity; }
#define PXCurrentIdentitySnapshot PXFixtureCurrentIdentitySnapshot
#include "PXReaderStatics.inc"

@interface PXReaderProvider : NSObject
+ (instancetype)sharedManager;
@end
@implementation PXReaderProvider
+ (instancetype)sharedManager { return [self new]; }
@end
#include "PXReaderProviders.inc"

// Declare every selector used by the extracted body, including its unchanged
// legacy fallback branches. Controlled optional providers return no candidate.
@interface IOSVersionInfo : PXReaderProvider
- (NSDictionary *)currentIOSVersionInfo;
@end
@implementation IOSVersionInfo
- (NSDictionary *)currentIOSVersionInfo { gFallbacks++; return nil; }
@end
@interface PXReaderProvider (OptionalSelectors)
- (void)loadBatteryInfoFromDisk;
- (NSString *)currentSSID;
- (NSString *)currentBSSID;
- (NSString *)totalStorageCapacity;
- (NSString *)freeStorageSpace;
- (NSString *)randomizeStorageCapacity;
- (NSDictionary *)generateStorageForCapacity:(NSString *)capacity;
- (void)setTotalStorageCapacity:(NSString *)value;
- (void)setFreeStorageSpace:(NSString *)value;
- (void)setFilesystemType:(NSString *)value;
@end
@interface BatteryManager : PXReaderProvider
- (NSString *)batteryLevel;
- (BOOL)lowPowerModeEnabled;
- (NSDictionary *)generateBatteryInfo;
@end
@implementation BatteryManager
- (NSString *)batteryLevel { gFallbacks++; return nil; }
- (BOOL)lowPowerModeEnabled { return NO; }
- (NSDictionary *)generateBatteryInfo { return nil; }
@end
@interface UptimeManager : PXReaderProvider
- (NSTimeInterval)currentUptimeForProfile:(NSString *)path;
- (NSDate *)currentBootTimeForProfile:(NSString *)path;
@end
@implementation UptimeManager
- (NSTimeInterval)currentUptimeForProfile:(NSString *)path { (void)path; gFallbacks++; return 0; }
- (NSDate *)currentBootTimeForProfile:(NSString *)path { (void)path; gFallbacks++; return nil; }
@end

@interface PXReaderFixture : NSObject
@property (nonatomic, strong) id settings;
- (NSString *)profileIdentityPath;
- (BOOL)saveCustomValue:(NSString *)value forType:(NSString *)type;
#include "PXReaderDeclarations.inc"
@end
@implementation PXReaderFixture
- (NSString *)profileIdentityPath { gPaths++; return gDirectory; }
- (BOOL)saveCustomValue:(NSString *)value forType:(NSString *)type {
    (void)type;
    if (![value isKindOfClass:NSString.class]) return NO;
    gSaves++; return YES;
}
#include "PXReaderMethods.inc"
@end

@interface PXReaderBoolConverter : NSObject
- (BOOL)boolValue;
@end
@implementation PXReaderBoolConverter
- (BOOL)boolValue { return YES; }
@end

static void TestManagerReaders(PXReaderFixture *reader) {
    NSArray *invalid = @[[NSNull null], @1, @[], @{}, [NSDate date]];
    for (id value in invalid) {
        NSUInteger paths = gPaths, captures = gCaptures, operations = gOperations;
        CHECK(![reader isIdentifierEnabled:value] && ![reader currentValueForIdentifier:value] &&
              paths == gPaths && captures == gCaptures && operations == gOperations,
              "invalid identifier rejected before capture operation or path resolution");
    }
    CHECK(![reader isIdentifierEnabled:nil] && ![reader currentValueForIdentifier:nil] &&
          ![reader isIdentifierEnabled:@""] && ![reader currentValueForIdentifier:@""], "nil and empty identifier rejected");
    for (id root in invalid) {
        reader.settings = root;
        // NSNumber is an invalid root even though it has boolValue.
        CHECK(![reader isIdentifierEnabled:@"IDFA"], "malformed live settings root fails closed");
    }
    reader.settings = nil;
    CHECK(![reader isIdentifierEnabled:@"IDFA"], "absent live settings root remains disabled");
    NSArray *badFlags = @[[NSNull null], @[], @{}, [NSDate date]];
    for (id value in badFlags) {
        reader.settings = @{ @"IDFA": value };
        CHECK(![reader isIdentifierEnabled:@"IDFA"], "container and date toggle values fail closed");
    }
    reader.settings = @{ @"IDFA": @"YES", @"IDFV": @0, @"WiFi": @1 };
    CHECK([reader isIdentifierEnabled:@"IDFA"] && ![reader isIdentifierEnabled:@"IDFV"] &&
          [reader isIdentifierEnabled:@"WiFiAddress"] && ![reader isIdentifierEnabled:@"unknown"],
          "live scalar conventions WiFi alias and missing toggle preserved");
    reader.settings = @{ @"IDFA": [PXReaderBoolConverter new] };
    CHECK([reader isIdentifierEnabled:@"IDFA"], "legacy live-memory bool converter accepted by the sanitizer remains readable");

    for (NSArray *row in PXReaderSidecarCases()) {
        NSString *key = row[0], *file = row[1];
        Put(@"device_ids.plist", @{ key: @"canonical" }); Put(file, @{ @"value": @"sidecar" });
        CHECK([[reader currentValueForIdentifier:key] isEqual:@"canonical"], "canonical scalar precedes sidecar");
        Put(@"device_ids.plist", @{});
        CHECK([[reader currentValueForIdentifier:key] isEqual:@"sidecar"], "each existing filename reads its sidecar");
        Put(file, @{ @"value": @42 });
        CHECK([[reader currentValueForIdentifier:key] isEqual:@"42"], "numeric sidecars obey NSString return contract");
        Put(file, @{ @"value": @"" });
        CHECK([[reader currentValueForIdentifier:key] isEqual:@""], "manager empty sidecar string remains authoritative");
        Put(file, @{ @"value": @[] });
        id result = [reader currentValueForIdentifier:key];
        CHECK(!result || [result isKindOfClass:NSString.class], "malformed sidecar never escapes as a container");
    }
    Put(@"device_ids.plist", @{ @"HardwareUUID": @"legacy" });
    CHECK([[reader currentValueForIdentifier:@"SystemBootUUID"] isEqual:@"legacy"], "legacy boot alias still precedes sidecar");
    Put(@"device_ids.plist", @{ @"SystemBootUUID": @"", @"HardwareUUID": @"legacy" });
    CHECK([[reader currentValueForIdentifier:@"SystemBootUUID"] isEqual:@""], "empty canonical manager value still precedes legacy");

    NSArray *badNumbers = @[@[], @{}, [NSDate date]]; // actual plist encodable malformed values
    for (id value in badNumbers) {
        Put(@"device_ids.plist", @{ @"ATTAuthorizationStatus": value });
        Put(@"tracking_info.plist", @{ @"ATTAuthorizationStatus": @2 });
        CHECK([reader attAuthorizationStatus] == 2, "malformed canonical ATT falls through to valid tracking status");
        Put(@"tracking_info.plist", @{ @"ATTAuthorizationStatus": value });
        CHECK([reader attAuthorizationStatus] == 0 && ![reader currentValueForIdentifier:@"ATTAuthorizationStatus"],
              "malformed ATT containers neither crash nor display their descriptions");
        Put(@"system_uptime.plist", @{ @"value": value });
        CHECK([[reader currentValueForIdentifier:@"SystemUptime"] isEqual:@"Not Set"], "malformed uptime returns legacy missing label");
    }
    Put(@"device_ids.plist", @{});
    Put(@"system_uptime.plist", @{ @"value": @7200 });
    CHECK([[reader currentValueForIdentifier:@"SystemUptime"] isEqual:@"2.00 hours"], "uptime display units preserved");
    Put(@"battery_info.plist", @{ @"BatteryLevel": @0.5, @"LowPowerMode": @1 });
    CHECK([[reader currentValueForIdentifier:@"BatteryLevel"] isEqual:@"0.5"] &&
          [[reader currentValueForIdentifier:@"LowPowerMode"] isEqual:@"1"], "numeric battery sidecar values become strings");
    for (NSInteger status = 0; status < 4; status++) {
        Put(@"device_ids.plist", @{ @"ATTAuthorizationStatus": @(status) });
        CHECK([reader attAuthorizationStatus] == status, "all four canonical ATT statuses accepted");
    }
    Put(@"device_ids.plist", @{ @"ATTAuthorizationStatus": @99 });
    Put(@"tracking_info.plist", @{ @"ATTAuthorizationStatus": @"3" });
    CHECK([reader attAuthorizationStatus] == 3, "out of range canonical ATT still falls through to string tracking value");
    Put(@"device_ids.plist", @{ @"ATTAuthorizationStatus": @"legacy-text" });
    CHECK([reader attAuthorizationStatus] == 0, "legacy nonnumeric string integerValue behavior preserved");

    for (id value in badNumbers) {
        Put(@"security.plist", @{ @"canvasFingerprintingEnabled": value, @"CanvasFingerprint": @YES });
        CHECK(![reader isCanvasFingerprintProtectionEnabled], "invalid present primary Canvas flag fails closed without reviving alias");
    }
    Put(@"security.plist", @{ @"CanvasFingerprint": @"YES" });
    CHECK([reader isCanvasFingerprintProtectionEnabled], "absent Canvas primary keeps legacy alias fallback");
    Put(@"security.plist", @{ @"canvasFingerprintingEnabled": @NO, @"CanvasFingerprint": @YES });
    CHECK(![reader isCanvasFingerprintProtectionEnabled], "explicit Canvas false remains authoritative");
    NSUInteger saves = gSaves;
    CHECK(![reader setCustomSerialNumber:(id)@12345678] && ![reader setCustomSerialNumber:@"short"] && saves == gSaves,
          "invalid serial rejected before invoking custom persistence");
    CHECK([reader setCustomSerialNumber:@"12345678"] && [reader setCustomDeviceName:@""], "serial minimum and device name empty-input delegation preserved");
}

static void TestInjectedReaders(PXReaderFixture *reader) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    gManager = NO;
    NSArray *invalid = @[@[], @{}, NSNull.null, @1, @""];
    NSUInteger captures = gCaptures, operations = gOperations, invalidPaths = gPaths;
    for (id value in invalid) {
        CHECK(![reader isIdentifierEnabled:value] && ![reader currentValueForIdentifier:value] &&
              captures == gCaptures && operations == gOperations && invalidPaths == gPaths,
              "invalid injected input does not begin a snapshot operation or resolve a path");
    }
    gView = [[PXRuntimeReadSnapshot alloc] initWithPropertyList:@{
        @"schemaVersion": @1, @"tlinkSettings": @{ @"EnabledIdentifiers": @{ @"IDFA": @NO, @"WiFi": @YES } },
        @"deviceIDs": @{ @"IDFA": @"evidence", @"IDFV": @"evidence" }
    } readerGeneration:1];
    CHECK(gView.valid, "injected snapshot fixture is valid");
    reader.settings = @{ @"IDFA": @YES, @"WiFi": @NO };
    CHECK(![reader isIdentifierEnabled:@"IDFA"] && [reader isIdentifierEnabled:@"IDFV"] &&
          [reader isIdentifierEnabled:@"WiFiAddress"], "injected explicit false inference and alias retain snapshot authority");
    gView = [[PXRuntimeReadSnapshot alloc] initWithPropertyList:@{
        @"schemaVersion": @1, @"deviceIDs": @{ @"IDFV": @"" }
    } readerGeneration:2];
    CHECK(![reader isIdentifierEnabled:@"IDFV"], "cached constant inference schema never caches a prior profile decision");
    gIdentity = [PXReaderIdentity new]; gIdentity.valid = YES;
    gIdentity.deviceIDs = @{ @"IDFA": @"snapshot", @"IDFV": @7, @"SystemBootUUID": @"", @"HardwareUUID": @"legacy-snapshot" };
    NSUInteger paths = gPaths, fallbacks = gFallbacks;
    CHECK([[reader currentValueForIdentifier:@"IDFA"] isEqual:@"snapshot"] &&
          [[reader currentValueForIdentifier:@"IDFV"] isEqual:@"7"] &&
          [[reader currentValueForIdentifier:@"SystemBootUUID"] isEqual:@"legacy-snapshot"],
          "injected scalar and empty canonical boot alias policy preserved");
    CHECK(![reader currentValueForIdentifier:@"DeviceName"] && paths == gPaths && fallbacks == gFallbacks,
          "injected missing value never opens manager paths or legacy providers");
    gIdentity.valid = NO;
    CHECK(![reader currentValueForIdentifier:@"IDFA"] && paths == gPaths, "invalid injected snapshot cannot fall back to disk");
    gManager = YES;
#else
    (void)reader;
#endif
}

int main(void) {
    @autoreleasepool {
        gDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        CHECK([NSFileManager.defaultManager createDirectoryAtPath:gDirectory withIntermediateDirectories:YES attributes:nil error:NULL], "reader directory created");
        PXReaderFixture *reader = [PXReaderFixture new];
        @try { TestManagerReaders(reader); TestInjectedReaders(reader); }
        @catch (NSException *exception) { gFailures++; fprintf(stderr, "FAIL: unexpected reader exception: %s\n", exception.description.UTF8String); }
        [NSFileManager.defaultManager removeItemAtPath:gDirectory error:NULL];
        fprintf(stdout, "Identifier reader safety: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
