#import "PXSystemVersionTransformer.h"
#import "PXIdentitySnapshot.h"
#import "PXDeviceProfileSchema.h"
#import "PXRuntimeOSCompatibility.h"

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
    @try {
        if (![snapshot isKindOfClass:[PXIdentitySnapshot class]] || !snapshot.valid) return nil;

        // The validator has already canonicalized the snapshot. Re-check runtime types here
        // so no malformed publication can create a partial SystemVersion projection.
        NSString *version = PXProfileString(snapshot.deviceIDs[@"IOSVersion"]);
        NSString *build = PXProfileString(snapshot.deviceIDs[@"IOSBuild"]);
        if (!version || !build) return nil;

        PXSystemVersionProjection *projection = [[PXSystemVersionProjection alloc] init];
        projection.productVersion = version;
        projection.productBuildVersion = build;
        projection.releaseType = @"User";
        projection.profileID = snapshot.profileID;
        projection.generation = snapshot.generationNumber ?: @(snapshot.generation);
        return projection;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

PXSystemVersionProjection *PXCurrentSystemVersionProjection(void) {
    PXIdentitySnapshot *snapshot = PXCurrentIdentitySnapshot();
    return PXSystemVersionProjectionFromSnapshot(snapshot);
}

PXSystemVersionProjection *PXCurrentReportingSystemVersionProjectionForBundle(NSString *bundleID) {
    PXSystemVersionProjection *configured = PXCurrentSystemVersionProjection();
    if (!configured) return nil;

    NSString *reportedVersion = nil;
    NSString *reportedBuild = nil;
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

    PXSystemVersionProjection *projection = [[PXSystemVersionProjection alloc] init];
    projection.productVersion = reportedVersion;
    projection.productBuildVersion = reportedBuild;
    projection.releaseType = configured.releaseType;
    projection.profileID = configured.profileID;
    projection.generation = configured.generation;
    return projection;
}

PXSystemVersionProjection *PXCurrentNativeSafeSystemVersionProjection(void) {
    PXSystemVersionProjection *configured = PXCurrentSystemVersionProjection();
    if (!configured) return nil;

    NSString *safeVersion = nil;
    NSString *safeBuild = nil;
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

    PXSystemVersionProjection *projection = [[PXSystemVersionProjection alloc] init];
    projection.productVersion = safeVersion;
    projection.productBuildVersion = safeBuild;
    projection.releaseType = configured.releaseType;
    projection.profileID = configured.profileID;
    projection.generation = configured.generation;
    return projection;
}

BOOL PXIsSystemVersionPlistPath(NSString *path) {
    @try {
        if (![path isKindOfClass:[NSString class]] || path.length == 0) return NO;
        NSString *normalized = [path stringByStandardizingPath];
        static NSString *const canonical = @"/System/Library/CoreServices/SystemVersion.plist";
        return [normalized isEqualToString:canonical] || [normalized hasSuffix:canonical];
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

NSDictionary *PXTransformSystemVersionDictionary(NSDictionary *original,
                                                  PXSystemVersionProjection *projection) {
    @try {
        if (![original isKindOfClass:[NSDictionary class]] || !projection) return original;
        if (!PXProfileString(projection.productVersion) ||
            !PXProfileString(projection.productBuildVersion) ||
            !PXProfileString(projection.releaseType)) {
            return original;
        }

        BOOL unchanged = [original[@"ProductVersion"] isEqual:projection.productVersion] &&
                         [original[@"ProductBuildVersion"] isEqual:projection.productBuildVersion] &&
                         [original[@"ReleaseType"] isEqual:projection.releaseType];
        if (unchanged) return original;

        NSMutableDictionary *candidate = [original mutableCopy];
        if (!candidate) return original;
        candidate[@"ProductVersion"] = projection.productVersion;
        candidate[@"ProductBuildVersion"] = projection.productBuildVersion;
        candidate[@"ReleaseType"] = projection.releaseType;
        return [candidate copy];
    } @catch (__unused NSException *exception) {
        return original;
    }
}

NSData *PXTransformSystemVersionData(NSData *original,
                                     PXSystemVersionProjection *projection) {
    @try {
        if (![original isKindOfClass:[NSData class]] || original.length == 0 || !projection) return original;

        NSPropertyListFormat sourceFormat = NSPropertyListXMLFormat_v1_0;
        NSError *parseError = nil;
        id root = [NSPropertyListSerialization propertyListWithData:original
                                                            options:NSPropertyListImmutable
                                                             format:&sourceFormat
                                                              error:&parseError];
        if (parseError || ![root isKindOfClass:[NSDictionary class]]) return original;

        NSDictionary *transformed = PXTransformSystemVersionDictionary(root, projection);
        if (transformed == root) return original;

        NSError *serializeError = nil;
        NSData *candidate = [NSPropertyListSerialization dataWithPropertyList:transformed
                                                                        format:sourceFormat
                                                                       options:0
                                                                         error:&serializeError];
        return (!serializeError && candidate.length > 0) ? candidate : original;
    } @catch (__unused NSException *exception) {
        return original;
    }
}

NSString *PXTransformSystemVersionString(NSString *original,
                                         NSStringEncoding sourceEncoding,
                                         PXSystemVersionProjection *projection) {
    @try {
        if (![original isKindOfClass:[NSString class]] || original.length == 0 || !projection) return original;

        NSData *sourceData = [original dataUsingEncoding:sourceEncoding allowLossyConversion:NO];
        if (!sourceData) return original;
        NSData *transformedData = PXTransformSystemVersionData(sourceData, projection);
        if (transformedData == sourceData) return original;

        // NSPropertyListSerialization emits XML and OpenStep strings as UTF-8. A binary
        // plist cannot originate from NSString's text initializer.
        NSString *candidate = [[NSString alloc] initWithData:transformedData encoding:NSUTF8StringEncoding];
        return candidate ?: original;
    } @catch (__unused NSException *exception) {
        return original;
    }
}
