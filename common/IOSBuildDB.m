#import "IOSBuildDB.h"
#import "PXVersionedIOSDatabase.h"
#import "VersionCompare.h"
#import "DBDebugLogger.h"
#import <Security/Security.h>

static NSString *const kIOSBuildDBErrorDomain = @"com.hydra.tlinkios.ios_build_db";

static NSUInteger PXRandomIndex(NSUInteger upperBoundExclusive) {
    if (upperBoundExclusive == 0) return 0;
    uint32_t r = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(r), (uint8_t *)&r) == errSecSuccess) {
        return (NSUInteger)(r % (uint32_t)upperBoundExclusive);
    }
    return (NSUInteger)arc4random_uniform((uint32_t)upperBoundExclusive);
}

@interface IOSBuildDB ()
@property (nonatomic, strong) NSDictionary *db;
@property (nonatomic, strong) NSDictionary *buildToMeta;
@property (nonatomic, strong) NSDictionary *deviceToBuilds;
@end

@implementation IOSBuildDB

+ (instancetype)sharedManager {
    static IOSBuildDB *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[IOSBuildDB alloc] init];
    });
    return shared;
}

- (BOOL)loadIfNeeded:(NSError **)error {
    PXVersionedIOSDatabase *database = [PXVersionedIOSDatabase sharedDatabase];
    NSDictionary *root = [database rootForKey:@"iosBuildDB" error:error];
    if (!root) return NO;
    if (self.db == root) return YES;

    NSDictionary *btm = [root[@"buildToMeta"] isKindOfClass:[NSDictionary class]] ? root[@"buildToMeta"] : nil;
    NSDictionary *dtb = [root[@"deviceToBuilds"] isKindOfClass:[NSDictionary class]] ? root[@"deviceToBuilds"] : nil;
    if (!btm || !dtb) {
        if (error) *error = [NSError errorWithDomain:kIOSBuildDBErrorDomain code:4 userInfo:@{NSLocalizedDescriptionKey: @"Missing buildToMeta/deviceToBuilds"}];
        PXDBLog(@"IOSBuildDB: rejected version=%@; missing buildToMeta/deviceToBuilds", database.databaseVersion ?: @"unknown");
        return NO;
    }

    // Publish all derived indexes together only after the complete root validates.
    self.buildToMeta = btm;
    self.deviceToBuilds = dtb;
    self.db = root;
    PXDBLog(@"IOSBuildDB: loaded version=%@ builds=%lu devices=%lu legacy=%@",
            database.databaseVersion ?: @"unknown",
            (unsigned long)btm.count,
            (unsigned long)dtb.count,
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
    self.buildToMeta = nil;
    self.deviceToBuilds = nil;
    return [self loadIfNeeded:error];
}

- (void)invalidate {
    self.db = nil;
    self.buildToMeta = nil;
    self.deviceToBuilds = nil;
    [[PXVersionedIOSDatabase sharedDatabase] invalidate];
}

- (NSDictionary *)randomMetaForDevice:(NSString *)productType
                                   min:(NSString *)minVersion
                                   max:(NSString *)maxVersion
                                 error:(NSError **)error {
    if (![self loadIfNeeded:error]) return nil;
    if (productType.length == 0) {
        if (error) *error = [NSError errorWithDomain:kIOSBuildDBErrorDomain code:5 userInfo:@{NSLocalizedDescriptionKey: @"Missing productType"}];
        return nil;
    }

    id buildsObj = self.deviceToBuilds[productType];
    if (![buildsObj isKindOfClass:[NSArray class]]) {
        if (error) *error = [NSError errorWithDomain:kIOSBuildDBErrorDomain code:6 userInfo:@{NSLocalizedDescriptionKey: @"No builds for device"}];
        PXDBLog(@"IOSBuildDB: no deviceToBuilds entry for device=%@", productType);
        return nil;
    }

    NSArray *builds = (NSArray *)buildsObj;
    NSMutableArray<NSDictionary *> *candidates = [NSMutableArray array];
    NSUInteger missingMeta = 0;
    NSUInteger missingFields = 0;
    NSUInteger kernelMismatch = 0;
    NSUInteger outOfRange = 0;

    NSMutableArray<NSString *> *missingMetaExamples = [NSMutableArray array];
    NSMutableArray<NSString *> *missingFieldsExamples = [NSMutableArray array];
    NSMutableArray<NSString *> *kernelMismatchExamples = [NSMutableArray array];

    for (id b in builds) {
        if (![b isKindOfClass:[NSString class]]) continue;
        NSString *build = (NSString *)b;
        NSDictionary *meta = self.buildToMeta[build];
        if (![meta isKindOfClass:[NSDictionary class]]) {
            missingMeta += 1;
            if (missingMetaExamples.count < 2) {
                [missingMetaExamples addObject:build];
            }
            continue;
        }

        NSString *version = meta[@"version"];
        NSString *darwin = meta[@"darwin"];
        NSString *xnu = meta[@"xnu"];
        NSString *kernel = meta[@"kernel_version"];

        if (![version isKindOfClass:[NSString class]] || ![darwin isKindOfClass:[NSString class]] || ![xnu isKindOfClass:[NSString class]] || ![kernel isKindOfClass:[NSString class]]) {
            missingFields += 1;
            if (missingFieldsExamples.count < 2) {
                NSString *vType = NSStringFromClass([version class]) ?: @"nil";
                NSString *dType = NSStringFromClass([darwin class]) ?: @"nil";
                NSString *xType = NSStringFromClass([xnu class]) ?: @"nil";
                NSString *kType = NSStringFromClass([kernel class]) ?: @"nil";
                [missingFieldsExamples addObject:[NSString stringWithFormat:@"%@ (types: version=%@ darwin=%@ xnu=%@ kernel_version=%@)", build, vType, dType, xType, kType]];
            }
            continue;
        }

        if (!PXVersionInRange(version, minVersion, maxVersion)) {
            outOfRange += 1;
            continue;
        }

        // Guardrails: kernel string must match darwin/xnu
        NSString *darwinNeedle = [NSString stringWithFormat:@"Darwin Kernel Version %@", darwin];
        NSString *xnuNeedle = [NSString stringWithFormat:@"xnu-%@", xnu];
        if ([kernel rangeOfString:darwinNeedle].location == NSNotFound || [kernel rangeOfString:xnuNeedle].location == NSNotFound) {
            kernelMismatch += 1;
            if (kernelMismatchExamples.count < 2) {
                NSString *reason = nil;
                if ([kernel rangeOfString:darwinNeedle].location == NSNotFound && [kernel rangeOfString:xnuNeedle].location == NSNotFound) {
                    reason = @"missing darwin and xnu";
                } else if ([kernel rangeOfString:darwinNeedle].location == NSNotFound) {
                    reason = @"missing darwin";
                } else {
                    reason = @"missing xnu";
                }
                [kernelMismatchExamples addObject:[NSString stringWithFormat:@"%@ v=%@ darwin=%@ xnu=%@ (%@)",
                                                 build,
                                                 version,
                                                 darwin,
                                                 xnu,
                                                 reason ?: @"mismatch"]];
            }
            continue;
        }

        NSMutableDictionary *full = [meta mutableCopy];
        full[@"build"] = build;
        [candidates addObject:full];
    }

    if (candidates.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:kIOSBuildDBErrorDomain code:7 userInfo:@{NSLocalizedDescriptionKey: @"No compatible iOS builds in range for this device"}];
        }
        PXDBLog(@"IOSBuildDB: no candidates for device=%@ range=[%@..%@] totalBuilds=%lu missingMeta=%lu missingFields=%lu outOfRange=%lu kernelMismatch=%lu", productType, minVersion, maxVersion, (unsigned long)builds.count, (unsigned long)missingMeta, (unsigned long)missingFields, (unsigned long)outOfRange, (unsigned long)kernelMismatch);

        if (missingMetaExamples.count > 0) {
            PXDBLog(@"IOSBuildDB: missingMeta examples for %@: %@", productType, [missingMetaExamples componentsJoinedByString:@", "]);
        }
        if (missingFieldsExamples.count > 0) {
            PXDBLog(@"IOSBuildDB: missingFields examples for %@: %@", productType, [missingFieldsExamples componentsJoinedByString:@" | "]);
        }
        if (kernelMismatchExamples.count > 0) {
            PXDBLog(@"IOSBuildDB: kernelMismatch examples for %@: %@", productType, [kernelMismatchExamples componentsJoinedByString:@" | "]);
        }
        return nil;
    }

    NSDictionary *pick = candidates[PXRandomIndex(candidates.count)];
    return pick;
}

@end
