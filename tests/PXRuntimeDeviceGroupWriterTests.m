#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <Security/Security.h>
#import "PXRuntimeIdentifierWriter.h"
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
static void (^gDuringPrepare)(void);
#define CHECK(value, message) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", message); } } while (0)
static NSString *Path(NSString *root, NSString *name) { return [root stringByAppendingPathComponent:name]; }
static NSString *Identity(NSString *profile) { return Path(Path(gRoot, profile), @"identity"); }
static NSDictionary *IDs(NSString *identity) { return [NSDictionary dictionaryWithContentsOfFile:Path(identity, @"device_ids.plist")] ?: @{}; }
BOOL PXPerformRuntimeSourceWrite(BOOL (^body)(PXRuntimeSourceTransaction *, NSError **), NSError **error) { return [gStore performWrite:body error:error]; }
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
    (void)product; (void)regulatory; Preparation();
    return @{ @"known": @(!gUnknownCellular), @"enabled": @(!gDisabledCellular), @"dualSIM": @YES,
        @"cdma": @YES, @"imeiTACs": @[@"12345678"], @"meidPrefixes": @[@"A00000"] };
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
#include "PXDeviceGroupStatics.inc"
@interface PXDeviceGroupFixture : NSObject
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSMutableDictionary *settings;
- (NSString *)profileIdentityPath;
- (BOOL)isIdentifierEnabled:(NSString *)type;
#include "PXDeviceGroupDeclarations.inc"
@end
@implementation PXDeviceGroupFixture
- (instancetype)init { if ((self = [super init])) _settings = [@{ @"IMEI": @YES, @"MEID": @YES } mutableCopy]; return self; }
- (NSString *)profileIdentityPath { gSelections++; return gSelected ? Identity(gSelected) : nil; }
- (BOOL)isIdentifierEnabled:(NSString *)type { return [self.settings[type] boolValue]; }
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
int main(void) {
    @autoreleasepool {
        gRoot = Path(NSTemporaryDirectory(), NSUUID.UUID.UUIDString);
        for (NSString *profile in @[@"a", @"b"])
            [NSFileManager.defaultManager createDirectoryAtPath:Identity(profile) withIntermediateDirectories:YES attributes:nil error:nil];
        gStore = [[PXRuntimeSourceStore alloc] initWithDirectory:Path(gRoot, @"control") owner:geteuid() group:getegid()
            allowsPath:^BOOL(NSString *path) { return [path hasPrefix:[gRoot stringByAppendingString:@"/"]] && [path hasSuffix:@".plist"] && ![path hasPrefix:Path(gRoot, @"control/")]; } error:NULL];
        CHECK(gStore != nil, "device group source backend initialized");
        PXDeviceGroupFixture *manager = [PXDeviceGroupFixture new];
        TestGroups(manager, Identity(@"a"), Identity(@"b"));
        TestDependentRefresh(manager, Identity(@"a"), Identity(@"b"));
        gStore = nil;
        [NSFileManager.defaultManager removeItemAtPath:gRoot error:nil];
        printf("Runtime device group writers: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
