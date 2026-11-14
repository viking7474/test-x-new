#import "PXSystemVersionTransformer.h"
#import "PXIdentitySnapshot.h"
#import "PXDeviceProfileSchema.h"
#import "PXRuntimeOSCompatibility.h"

static __thread BOOL gPXSystemVersionProjectionActive;
BOOL PXSystemVersionProjectionActive(void) { return gPXSystemVersionProjectionActive; }
BOOL PXSystemVersionProjectionEnter(void) {
    BOOL previous = gPXSystemVersionProjectionActive; gPXSystemVersionProjectionActive = YES; return previous;
}
void PXSystemVersionProjectionLeave(BOOL previous) { gPXSystemVersionProjectionActive = previous; }

@interface PXSystemVersionProjection ()
@property (nonatomic, copy, readwrite) NSString *productVersion;
@property (nonatomic, copy, readwrite) NSString *productBuildVersion;
@property (nonatomic, copy, readwrite) NSString *releaseType;
@property (nonatomic, copy, readwrite, nullable) NSString *profileID;
@property (nonatomic, strong, readwrite) NSNumber *generation;
@end

@implementation PXSystemVersionProjection
@end

PXSystemVersionProjection *PXSystemVersionProjectionFromSnapshot(PXIdentitySnapshot *snapshot) {
    NSDictionary *ids = nil;
    NSString *version = nil, *build = nil;
    PXSystemVersionProjection *projection = nil;
    @try {
        if (![snapshot isKindOfClass:[PXIdentitySnapshot class]] || !snapshot.valid) return nil;
        ids = snapshot.deviceIDs; version = PXProfileString(ids[@"IOSVersion"]); build = PXProfileString(ids[@"IOSBuild"]);
        if (!version || !build) return nil;
        projection = [[PXSystemVersionProjection alloc] init];
        projection.productVersion = version; projection.productBuildVersion = build; projection.releaseType = @"User";
        projection.profileID = snapshot.profileID; projection.generation = snapshot.generationNumber ?: @(snapshot.generation);
        return projection;
    } @catch (__unused NSException *exception) { return nil; }
    @finally { snapshot = nil; ids = nil; version = nil; build = nil; projection = nil; }
}

PXSystemVersionProjection *PXCurrentSystemVersionProjection(void) {
    PXIdentitySnapshot *snapshot = nil;
    @try { snapshot = PXCurrentIdentitySnapshot(); return PXSystemVersionProjectionFromSnapshot(snapshot); }
    @finally { snapshot = nil; }
}

PXSystemVersionProjection *PXCurrentReportingSystemVersionProjectionForBundle(NSString *bundleID) {
    PXSystemVersionProjection *configured = nil, *projection = nil;
    NSString *__autoreleasing reportedVersion = nil;
    NSString *__autoreleasing reportedBuild = nil;
    @try {
        configured = PXCurrentSystemVersionProjection();
        if (!configured) return nil;

        if (!PXReportingIOSVersionBuildForBundle(configured.productVersion,
                                                  configured.productBuildVersion,
                                                  bundleID,
                                                  &reportedVersion,
                                                  &reportedBuild)) {
            return nil;
        }
        if ([reportedVersion isEqualToString:configured.productVersion] &&
            [reportedBuild isEqualToString:configured.productBuildVersion]) {
            return configured;
        }

        projection = [[PXSystemVersionProjection alloc] init];
        projection.productVersion = reportedVersion;
        projection.productBuildVersion = reportedBuild;
        projection.releaseType = configured.releaseType;
        projection.profileID = configured.profileID;
        projection.generation = configured.generation;
        return projection;
    } @finally { configured = nil; projection = nil; reportedVersion = nil; reportedBuild = nil; bundleID = nil; }
}

PXSystemVersionProjection *PXCurrentNativeSafeSystemVersionProjection(void) {
    PXSystemVersionProjection *configured = nil, *projection = nil;
    NSString *__autoreleasing safeVersion = nil;
    NSString *__autoreleasing safeBuild = nil;
    @try {
        configured = PXCurrentSystemVersionProjection();
        if (!configured) return nil;

        if (!PXNativeSafeIOSVersionBuild(configured.productVersion,
                                         configured.productBuildVersion,
                                         &safeVersion,
                                         &safeBuild)) {
            return nil;
        }
        if ([safeVersion isEqualToString:configured.productVersion] &&
            [safeBuild isEqualToString:configured.productBuildVersion]) {
            return configured;
        }

        projection = [[PXSystemVersionProjection alloc] init];
        projection.productVersion = safeVersion;
        projection.productBuildVersion = safeBuild;
        projection.releaseType = configured.releaseType;
        projection.profileID = configured.profileID;
        projection.generation = configured.generation;
        return projection;
    } @finally { configured = nil; projection = nil; safeVersion = nil; safeBuild = nil;  }
}

BOOL PXIsSystemVersionPlistPath(NSString *path) {
    NSString *normalized = nil;
    @try {
        if (![path isKindOfClass:[NSString class]] || path.length == 0) return NO;
        normalized = [path stringByStandardizingPath];
        static NSString *const canonical = @"/System/Library/CoreServices/SystemVersion.plist";
        return [normalized isEqualToString:canonical] || [normalized hasSuffix:canonical];
    } @catch (__unused NSException *exception) { return NO; }
    @finally { path = nil; normalized = nil; }
}

NSDictionary *PXTransformSystemVersionDictionary(NSDictionary *original,
                                                  PXSystemVersionProjection *projection) {
    NSString *version = nil, *build = nil, *release = nil;
    NSMutableDictionary *candidate = nil;
    @try {
        if (![original isKindOfClass:[NSDictionary class]] || !projection) return original;
        version = projection.productVersion; build = projection.productBuildVersion; release = projection.releaseType;
        if (!PXProfileString(version) || !PXProfileString(build) || !PXProfileString(release)) return original;
        BOOL unchanged = [original[@"ProductVersion"] isEqual:version] &&
            [original[@"ProductBuildVersion"] isEqual:build] && [original[@"ReleaseType"] isEqual:release];
        if (unchanged) return original;
        candidate = [original mutableCopy];
        if (!candidate) return original;
        candidate[@"ProductVersion"] = version; candidate[@"ProductBuildVersion"] = build; candidate[@"ReleaseType"] = release;
        return [candidate copy];
    } @catch (__unused NSException *exception) { return original; }
    @finally { original = nil; projection = nil; version = nil; build = nil; release = nil; candidate = nil; }
}

NSData *PXTransformSystemVersionData(NSData *original,
                                     PXSystemVersionProjection *projection) {
    id root = nil;
    NSDictionary *transformed = nil;
    NSData *candidate = nil;
    NSError *__autoreleasing parseError = nil;
    NSError *__autoreleasing serializeError = nil;
    @try {
        if (![original isKindOfClass:[NSData class]] || original.length == 0 || !projection) return original;
        NSPropertyListFormat sourceFormat = NSPropertyListXMLFormat_v1_0;
        root = [NSPropertyListSerialization propertyListWithData:original options:NSPropertyListImmutable format:&sourceFormat error:&parseError];
        if (parseError || ![root isKindOfClass:[NSDictionary class]]) return original;
        transformed = PXTransformSystemVersionDictionary(root, projection);
        if (transformed == root) return original;
        candidate = [NSPropertyListSerialization dataWithPropertyList:transformed format:sourceFormat options:0 error:&serializeError];
        return (!serializeError && candidate.length > 0) ? candidate : original;
    } @catch (__unused NSException *exception) { return original; }
    @finally { original = nil; projection = nil; root = nil; transformed = nil; candidate = nil; parseError = nil; serializeError = nil; }
}

NSString *PXTransformSystemVersionString(NSString *original,
                                         NSStringEncoding sourceEncoding,
                                         PXSystemVersionProjection *projection) {
    NSData *sourceData = nil, *transformedData = nil;
    NSString *candidate = nil;
    @try {
        if (![original isKindOfClass:[NSString class]] || original.length == 0 || !projection) return original;
        sourceData = [original dataUsingEncoding:sourceEncoding allowLossyConversion:NO];
        if (!sourceData) return original;
        transformedData = PXTransformSystemVersionData(sourceData, projection);
        if (transformedData == sourceData) return original;
        candidate = [[NSString alloc] initWithData:transformedData encoding:NSUTF8StringEncoding];
        return candidate ?: original;
    } @catch (__unused NSException *exception) { return original; }
    @finally { original = nil; projection = nil; sourceData = nil; transformedData = nil; candidate = nil; }
}
