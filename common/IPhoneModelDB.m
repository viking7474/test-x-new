#import "IPhoneModelDB.h"
#import "PXVersionedIOSDatabase.h"
#import "VersionCompare.h"
#import "DBDebugLogger.h"
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
        NSString *maxIOS = model[@"maxIOS"];
        if (![productType isKindOfClass:[NSString class]] || ![productType hasPrefix:@"iPhone"] ||
            ![maxIOS isKindOfClass:[NSString class]] || maxIOS.length == 0 || byType[productType]) {
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

- (BOOL)containsProductType:(NSString *)productType {
    return [self specForProductType:productType] != nil;
}

@end
