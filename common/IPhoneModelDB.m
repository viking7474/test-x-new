#import "IPhoneModelDB.h"
#import "PXVersionedIOSDatabase.h"
#import "VersionCompare.h"
#import "DBDebugLogger.h"
#import "PXDeviceProfileSchema.h"
#import <Security/Security.h>

static NSString *const kIPhoneModelDBErrorDomain = @"com.hydra.tlinkios.iphone_model_db";

static NSUInteger PXRandomIndex2(NSUInteger upperBoundExclusive) {
    if (upperBoundExclusive == 0) return 0;
    uint32_t r = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(r), (uint8_t *)&r) == errSecSuccess) {
        return (NSUInteger)(r % (uint32_t)upperBoundExclusive);
    }
    return (NSUInteger)arc4random_uniform((uint32_t)upperBoundExclusive);
}

@interface IPhoneModelDB ()
@property (nonatomic, strong) NSDictionary *db;
@property (nonatomic, strong) NSArray<NSDictionary *> *models;
@property (nonatomic, strong) NSDictionary<NSString *, NSDictionary *> *byProductType;
@end

@implementation IPhoneModelDB

+ (instancetype)sharedManager {
    static IPhoneModelDB *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[IPhoneModelDB alloc] init];
    });
    return shared;
}

- (BOOL)loadIfNeeded:(NSError **)error {
    PXVersionedIOSDatabase *database = [PXVersionedIOSDatabase sharedDatabase];
    NSDictionary *root = [database rootForKey:@"iphoneModelDB" error:error];
    if (!root) return NO;
    if (self.db == root) return YES;

    NSArray *modelsObject = [root[@"models"] isKindOfClass:[NSArray class]] ? root[@"models"] : nil;
    if (!modelsObject) {
        if (error) *error = [NSError errorWithDomain:kIPhoneModelDBErrorDomain code:4 userInfo:@{NSLocalizedDescriptionKey: @"Missing models array"}];
        PXDBLog(@"IPhoneModelDB: rejected version=%@; missing models array", database.databaseVersion ?: @"unknown");
        return NO;
    }

    NSMutableArray<NSDictionary *> *models = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSDictionary *> *byType = [NSMutableDictionary dictionary];
    NSUInteger invalid = 0;
    for (id item in modelsObject) {
        if (![item isKindOfClass:[NSDictionary class]]) { invalid += 1; continue; }
        NSDictionary *model = item;
        NSString *productType = model[@"productType"];
        NSString *minIOS = [model[@"minIOS"] isKindOfClass:[NSString class]] ? model[@"minIOS"] : nil;
        NSString *maxIOS = model[@"maxIOS"];
        if (![productType isKindOfClass:[NSString class]] || ![productType hasPrefix:@"iPhone"] ||
            ![maxIOS isKindOfClass:[NSString class]] || maxIOS.length == 0 ||
            (model[@"minIOS"] && !minIOS.length) ||
            (minIOS.length && PXCompareVersions(minIOS, maxIOS) == NSOrderedDescending) ||
            byType[productType]) {
            invalid += 1;
            continue;
        }
        [models addObject:model];
        byType[productType] = model;
    }
    if (models.count == 0) {
        if (error) *error = [NSError errorWithDomain:kIPhoneModelDBErrorDomain code:5 userInfo:@{NSLocalizedDescriptionKey: @"No valid iPhone models in DB"}];
        PXDBLog(@"IPhoneModelDB: rejected version=%@; no valid models", database.databaseVersion ?: @"unknown");
        return NO;
    }

    // Publish root and derived indexes only after validation is complete.
    self.models = [models copy];
    self.byProductType = [byType copy];
    self.db = root;
    PXDBLog(@"IPhoneModelDB: loaded version=%@ models=%lu skipped=%lu legacy=%@",
            database.databaseVersion ?: @"unknown",
            (unsigned long)models.count,
            (unsigned long)invalid,
            database.isLegacy ? @"YES" : @"NO");
    return YES;
}

- (NSString *)databaseVersion {
    return [PXVersionedIOSDatabase sharedDatabase].databaseVersion;
}

- (NSDictionary *)databaseMetadata {
    return [PXVersionedIOSDatabase sharedDatabase].metadata;
}

- (BOOL)reload:(NSError **)error {
    if (![[PXVersionedIOSDatabase sharedDatabase] reload:error]) return NO;
    self.db = nil;
    self.models = nil;
    self.byProductType = nil;
    return [self loadIfNeeded:error];
}

- (void)invalidate {
    self.db = nil;
    self.models = nil;
    self.byProductType = nil;
    [[PXVersionedIOSDatabase sharedDatabase] invalidate];
}

- (NSDictionary *)randomModelMinIOS:(NSString *)minIOS error:(NSError **)error {
    if (![self loadIfNeeded:error]) return nil;
    if (minIOS.length == 0) minIOS = @"0.0";

    NSMutableArray<NSDictionary *> *candidates = [NSMutableArray array];
    for (NSDictionary *m in self.models) {
        NSString *maxIOS = m[@"maxIOS"];
        if (![maxIOS isKindOfClass:[NSString class]]) continue;
        if (PXCompareVersions(maxIOS, minIOS) == NSOrderedAscending) continue;
        [candidates addObject:m];
    }

    if (candidates.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:kIPhoneModelDBErrorDomain code:6 userInfo:@{NSLocalizedDescriptionKey: @"No models satisfy minIOS constraint"}];
        }
        PXDBLog(@"IPhoneModelDB: no candidates for minIOS=%@ (models=%lu)", minIOS, (unsigned long)self.models.count);
        return nil;
    }

    return candidates[PXRandomIndex2(candidates.count)];
}

- (NSDictionary *)specForProductType:(NSString *)productType {
    if (!productType.length) return nil;
    // Best-effort load.
    [self loadIfNeeded:nil];
    return self.byProductType[productType];
}

- (NSDictionary *)canonicalHardwareSpecForProductType:(NSString *)productType {
    NSDictionary *model = [self specForProductType:productType];
    if (!model) return nil;

    // A model row from an older DB generation is not a P0 hardware record just
    // because ProductType/name exist. Require the complete model-level contract
    // before exposing it to runtime hooks/generators.
    NSDictionary *screenRecord = [model[@"screen"] isKindOfClass:[NSDictionary class]] ? model[@"screen"] : nil;
    NSArray *storageTiers = [model[@"storageCapacitiesGB"] isKindOfClass:[NSArray class]] ? model[@"storageCapacitiesGB"] : nil;
    NSArray<NSString *> *requiredNumeric = @[@"deviceMemoryGB", @"cpuCores",
                                              @"frontCameraMegapixels", @"rearCameraMegapixels", @"rearCameraCount"];
    NSArray<NSString *> *requiredBoolean = @[@"hasFrontCamera", @"hasRearCamera", @"hasPanoramaCamera",
                                              @"hasUltraWideCamera", @"hasTelephotoCamera", @"hasLiDARScanner", @"supports4KVideo"];
    BOOL complete = screenRecord != nil &&
        PXProfileString(screenRecord[@"resolution"]).length > 0 &&
        PXProfileString(screenRecord[@"viewport"]).length > 0 &&
        PXProfilePositiveNumber(screenRecord[@"scale"]) != nil &&
        PXProfilePositiveNumber(screenRecord[@"nativeScale"]) != nil &&
        PXProfilePositiveNumber(screenRecord[@"ppi"]) != nil &&
        PXProfileString(model[@"cpuArchitecture"]).length > 0 &&
        PXProfileString(model[@"cpuProfileKey"]).length > 0 &&
        storageTiers.count > 0;
    for (NSString *key in requiredNumeric) {
        if (!PXProfilePositiveNumber(model[key])) { complete = NO; break; }
    }
    if (complete) {
        for (NSString *key in requiredBoolean) {
            if (![model[key] isKindOfClass:[NSNumber class]]) { complete = NO; break; }
        }
    }
    if (!complete) return nil;

    NSMutableDictionary *source = [NSMutableDictionary dictionary];
    source[@"value"] = productType;
    NSString *name = PXProfileString(model[@"name"]);
    if (name) source[@"name"] = name;

    NSDictionary *screen = [model[@"screen"] isKindOfClass:[NSDictionary class]] ? model[@"screen"] : nil;
    NSString *resolution = PXProfileString(screen[@"resolution"]);
    NSString *viewport = PXProfileString(screen[@"viewport"]);
    NSNumber *scale = PXProfilePositiveNumber(screen[@"scale"]);
    NSNumber *nativeScale = PXProfilePositiveNumber(screen[@"nativeScale"]);
    NSNumber *ppi = PXProfilePositiveNumber(screen[@"ppi"]);
    if (resolution) source[@"screenResolution"] = resolution;
    if (viewport) source[@"viewportResolution"] = viewport;
    if (scale) source[@"devicePixelRatio"] = scale;
    if (nativeScale) source[@"nativeScale"] = nativeScale;
    if (ppi) source[@"screenDensity"] = ppi;

    NSString *cpuArchitecture = PXProfileString(model[@"cpuArchitecture"]);
    NSString *cpuProfileKey = PXProfileString(model[@"cpuProfileKey"]);
    NSNumber *deviceMemoryGB = PXProfilePositiveNumber(model[@"deviceMemoryGB"]);
    NSNumber *cpuCores = PXProfilePositiveNumber(model[@"cpuCores"]);
    if (cpuArchitecture) source[@"cpuArchitecture"] = cpuArchitecture;
    if (cpuProfileKey) source[@"cpuProfileKey"] = cpuProfileKey;
    if (deviceMemoryGB) source[@"deviceMemory"] = deviceMemoryGB;
    if (cpuCores) source[@"cpuCoreCount"] = cpuCores;

    for (NSString *key in @[@"frontCameraMegapixels", @"rearCameraMegapixels", @"rearCameraCount",
                             @"hasFrontCamera", @"hasRearCamera", @"hasPanoramaCamera",
                             @"hasUltraWideCamera", @"hasTelephotoCamera", @"hasLiDARScanner",
                             @"supports4KVideo", @"storageCapacitiesGB"]) {
        id value = model[key];
        if (value) source[key] = value;
    }

    return PXCanonicalDeviceSpecifications(source, productType);
}

- (NSDictionary *)cellularSpecForProductType:(NSString *)productType
                       regulatoryModelNumber:(NSString *)regulatoryModelNumber {
    if (!productType.length || !regulatoryModelNumber.length) return nil;
    NSDictionary *model = [self specForProductType:productType];
    if (!model) return nil;

    NSArray *allowed = [model[@"regulatoryModelNumbers"] isKindOfClass:[NSArray class]]
        ? model[@"regulatoryModelNumbers"] : nil;
    if (allowed.count && ![allowed containsObject:regulatoryModelNumber]) return nil;

    NSDictionary *regional = [model[@"cellularByRegulatoryModelNumber"] isKindOfClass:[NSDictionary class]]
        ? model[@"cellularByRegulatoryModelNumber"] : nil;
    NSDictionary *spec = [regional[regulatoryModelNumber] isKindOfClass:[NSDictionary class]]
        ? regional[regulatoryModelNumber] : nil;
    if (![spec[@"known"] isKindOfClass:[NSNumber class]]) return nil;
    return [spec copy];
}

- (NSDictionary *)basebandMetaForProductType:(NSString *)productType
                        regulatoryModelNumber:(NSString *)regulatoryModelNumber
                                    iosBuild:(NSString *)iosBuild {
    if (!productType.length || !regulatoryModelNumber.length || !iosBuild.length) return nil;
    NSDictionary *model = [self specForProductType:productType];
    if (!model) return nil;

    NSArray *allowed = [model[@"regulatoryModelNumbers"] isKindOfClass:[NSArray class]]
        ? model[@"regulatoryModelNumbers"] : nil;
    if (allowed.count && ![allowed containsObject:regulatoryModelNumber]) return nil;

    NSDictionary *regional = [model[@"basebandByRegulatoryModelNumber"] isKindOfClass:[NSDictionary class]]
        ? model[@"basebandByRegulatoryModelNumber"] : nil;
    NSDictionary *spec = [regional[regulatoryModelNumber] isKindOfClass:[NSDictionary class]]
        ? regional[regulatoryModelNumber] : nil;
    if (![spec[@"known"] isKindOfClass:[NSNumber class]] || ![spec[@"known"] boolValue]) return nil;

    NSString *family = PXProfileString(spec[@"basebandFamily"]);
    NSDictionary *builds = [spec[@"builds"] isKindOfClass:[NSDictionary class]] ? spec[@"builds"] : nil;
    NSString *version = PXProfileString(builds[iosBuild]);
    if (!family.length || !version.length) return nil;

    return @{
        @"known": @YES,
        @"productType": productType,
        @"regulatoryModelNumber": regulatoryModelNumber,
        @"iosBuild": iosBuild,
        @"basebandFamily": family,
        @"basebandVersion": version
    };
}

- (BOOL)containsProductType:(NSString *)productType {
    return [self specForProductType:productType] != nil;
}

@end
