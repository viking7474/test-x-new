#import "PXIdentityDependencyValidator.h"
#import "PXCellularIdentitySchema.h"
#import <math.h>

@interface PXIdentityDependencyValidationResult ()
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, NSString *> *issues;
@property (nonatomic, readwrite, getter=isValid) BOOL valid;
@end

@implementation PXIdentityDependencyValidationResult
@end

static NSString *PXDependencyString(id value) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length ? trimmed : nil;
}

static BOOL PXDependencyEqualString(id left, id right) {
    NSString *lhs = PXDependencyString(left);
    NSString *rhs = PXDependencyString(right);
    return lhs && rhs && [lhs isEqualToString:rhs];
}

static NSDictionary *PXModelByProductType(NSDictionary *modelRoot) {
    NSArray *models = [modelRoot[@"models"] isKindOfClass:[NSArray class]] ? modelRoot[@"models"] : nil;
    if (!models) return nil;
    NSMutableDictionary *index = [NSMutableDictionary dictionaryWithCapacity:models.count];
    for (id row in models) {
        NSString *productType = [row isKindOfClass:[NSDictionary class]] ? PXDependencyString(row[@"productType"]) : nil;
        if (!productType || index[productType]) return nil;
        index[productType] = row;
    }
    return [index copy];
}

static NSNumber *PXDependencyNumber(id value) {
    if (![value isKindOfClass:[NSNumber class]]) return nil;
    double v = [value doubleValue];
    return isfinite(v) ? value : nil;
}

static BOOL PXDependencyEqualNumber(id left, id right) {
    NSNumber *lhs = PXDependencyNumber(left);
    NSNumber *rhs = PXDependencyNumber(right);
    if (!lhs || !rhs) return NO;
    return fabs(lhs.doubleValue - rhs.doubleValue) < 0.00001;
}

static BOOL PXDependencyEqualNumberArray(id left, id right) {
    if (![left isKindOfClass:[NSArray class]] || ![right isKindOfClass:[NSArray class]]) return NO;
    NSArray *lhs = left;
    NSArray *rhs = right;
    if (lhs.count != rhs.count) return NO;
    for (id value in lhs) {
        if (![value isKindOfClass:[NSNumber class]] || ![rhs containsObject:value]) return NO;
    }
    return YES;
}

static BOOL PXVariantMatches(NSDictionary *model,
                             NSString *boardID,
                             NSString *hwModel,
                             NSString *regulatoryModelNumber) {
    NSArray *variants = [model[@"variants"] isKindOfClass:[NSArray class]] ? model[@"variants"] : nil;
    if (variants.count) {
        for (id row in variants) {
            if (![row isKindOfClass:[NSDictionary class]]) continue;
            BOOL boardMatches = !boardID || PXDependencyEqualString(boardID, row[@"boardID"]);
            BOOL hwMatches = !hwModel || PXDependencyEqualString(hwModel, row[@"hwModel"]);
            if (!boardMatches || !hwMatches) continue;

            NSArray *variantNumbers = [row[@"regulatoryModelNumbers"] isKindOfClass:[NSArray class]]
                ? row[@"regulatoryModelNumbers"] : nil;
            if (regulatoryModelNumber.length && variantNumbers.count &&
                ![variantNumbers containsObject:regulatoryModelNumber]) continue;
            if (regulatoryModelNumber.length && !variantNumbers.count) {
                NSArray *aggregate = [model[@"regulatoryModelNumbers"] isKindOfClass:[NSArray class]]
                    ? model[@"regulatoryModelNumbers"] : nil;
                if (aggregate.count && ![aggregate containsObject:regulatoryModelNumber]) continue;
            }
            return YES;
        }
        return NO;
    }
    BOOL boardMatches = !boardID || PXDependencyEqualString(boardID, model[@"boardID"]);
    BOOL hwMatches = !hwModel || PXDependencyEqualString(hwModel, model[@"hwModel"]);
    NSArray *aggregate = [model[@"regulatoryModelNumbers"] isKindOfClass:[NSArray class]]
        ? model[@"regulatoryModelNumbers"] : nil;
    BOOL numberMatches = !regulatoryModelNumber || !aggregate.count ||
        [aggregate containsObject:regulatoryModelNumber];
    return boardMatches && hwMatches && numberMatches;
}

static void PXValidateCanonicalModelHardware(NSDictionary *deviceIDs,
                                             NSDictionary *model,
                                             BOOL requireComplete,
                                             NSMutableDictionary<NSString *, NSString *> *issues) {
    NSDictionary *screen = [model[@"screen"] isKindOfClass:[NSDictionary class]] ? model[@"screen"] : @{};
    NSDictionary<NSString *, id> *stringExpected = @{
        @"DeviceModelName": model[@"name"] ?: [NSNull null],
        @"ScreenResolution": screen[@"resolution"] ?: [NSNull null],
        @"ViewportResolution": screen[@"viewport"] ?: [NSNull null],
        @"CPUArchitecture": model[@"cpuArchitecture"] ?: [NSNull null],
        @"CPUProfileKey": model[@"cpuProfileKey"] ?: [NSNull null]
    };
    [stringExpected enumerateKeysAndObjectsUsingBlock:^(NSString *key, id expected, BOOL *stop) {
        (void)stop;
        NSString *expectedString = PXDependencyString(expected);
        if (!expectedString) return;
        NSString *actual = PXDependencyString(deviceIDs[key]);
        if (!actual) {
            if (requireComplete) issues[key] = @"missing-canonical-model-field";
        } else if (![actual isEqualToString:expectedString]) {
            issues[key] = @"does-not-match-canonical-model";
        }
    }];

    NSDictionary<NSString *, id> *numberExpected = @{
        @"DevicePixelRatio": screen[@"scale"] ?: [NSNull null],
        @"NativeScale": screen[@"nativeScale"] ?: [NSNull null],
        @"ScreenDensityPPI": screen[@"ppi"] ?: [NSNull null],
        @"DeviceMemory": model[@"deviceMemoryGB"] ?: [NSNull null],
        @"CPUCoreCount": model[@"cpuCores"] ?: [NSNull null],
        @"FrontCameraMegapixels": model[@"frontCameraMegapixels"] ?: [NSNull null],
        @"RearCameraMegapixels": model[@"rearCameraMegapixels"] ?: [NSNull null],
        @"RearCameraCount": model[@"rearCameraCount"] ?: [NSNull null]
    };
    [numberExpected enumerateKeysAndObjectsUsingBlock:^(NSString *key, id expected, BOOL *stop) {
        (void)stop;
        NSNumber *expectedNumber = PXDependencyNumber(expected);
        if (!expectedNumber) return;
        NSNumber *actual = PXDependencyNumber(deviceIDs[key]);
        if (!actual) {
            if (requireComplete) issues[key] = @"missing-canonical-model-field";
        } else if (!PXDependencyEqualNumber(actual, expectedNumber)) {
            issues[key] = @"does-not-match-canonical-model";
        }
    }];

    for (NSString *field in @[@"hasFrontCamera", @"hasRearCamera", @"hasPanoramaCamera",
                               @"hasUltraWideCamera", @"hasTelephotoCamera", @"hasLiDARScanner",
                               @"supports4KVideo"]) {
        id expected = model[field];
        if (![expected isKindOfClass:[NSNumber class]]) continue;
        NSString *profileKey = @{
            @"hasFrontCamera": @"HasFrontCamera", @"hasRearCamera": @"HasRearCamera",
            @"hasPanoramaCamera": @"HasPanoramaCamera", @"hasUltraWideCamera": @"HasUltraWideCamera",
            @"hasTelephotoCamera": @"HasTelephotoCamera", @"hasLiDARScanner": @"HasLiDARScanner",
            @"supports4KVideo": @"Supports4KVideo"
        }[field];
        id actual = deviceIDs[profileKey];
        if (![actual isKindOfClass:[NSNumber class]]) {
            if (requireComplete) issues[profileKey] = @"missing-canonical-model-field";
        } else if ([actual boolValue] != [expected boolValue]) {
            issues[profileKey] = @"does-not-match-canonical-model";
        }
    }

    NSArray *expectedCapacities = [model[@"storageCapacitiesGB"] isKindOfClass:[NSArray class]] ? model[@"storageCapacitiesGB"] : nil;
    if (expectedCapacities.count) {
        id actualCapacities = deviceIDs[@"StorageCapacitiesGB"];
        if (!actualCapacities) {
            if (requireComplete) issues[@"StorageCapacitiesGB"] = @"missing-canonical-model-field";
        } else if (!PXDependencyEqualNumberArray(actualCapacities, expectedCapacities)) {
            issues[@"StorageCapacitiesGB"] = @"does-not-match-canonical-model";
        }
    }
}

PXIdentityDependencyValidationResult *PXValidateIdentityDependencies(NSDictionary *deviceIDs,
                                                                     NSDictionary *buildRoot,
                                                                     NSDictionary *modelRoot) {
    NSMutableDictionary<NSString *, NSString *> *issues = [NSMutableDictionary dictionary];
    if (![deviceIDs isKindOfClass:[NSDictionary class]]) {
        issues[@"$"] = @"not-a-dictionary";
    } else {
        NSArray<NSString *> *softwareKeys = @[@"IOSVersion", @"IOSBuild", @"Darwin", @"XNU", @"KernelVersion"];
        NSUInteger softwarePresent = 0;
        for (NSString *key in softwareKeys) if (PXDependencyString(deviceIDs[key])) softwarePresent++;
        NSString *productType = PXDependencyString(deviceIDs[@"DeviceModel"]);
        BOOL requiresDatabase = softwarePresent > 0 || productType.length > 0;

        NSDictionary *buildToMeta = [buildRoot[@"buildToMeta"] isKindOfClass:[NSDictionary class]] ? buildRoot[@"buildToMeta"] : nil;
        NSDictionary *deviceToBuilds = [buildRoot[@"deviceToBuilds"] isKindOfClass:[NSDictionary class]] ? buildRoot[@"deviceToBuilds"] : nil;
        NSDictionary *models = PXModelByProductType(modelRoot);
        if (requiresDatabase && (!buildToMeta || !deviceToBuilds || !models)) {
            issues[@"database"] = @"coherent-ios-database-required";
        }

        if (softwarePresent > 0 && softwarePresent != softwareKeys.count) {
            issues[@"softwareTuple"] = @"incomplete-version-build-kernel-tuple";
        } else if (softwarePresent == softwareKeys.count && buildToMeta) {
            NSString *build = PXDependencyString(deviceIDs[@"IOSBuild"]);
            NSDictionary *meta = [buildToMeta[build] isKindOfClass:[NSDictionary class]] ? buildToMeta[build] : nil;
            if (!meta) {
                issues[@"IOSBuild"] = @"build-not-in-versioned-database";
            } else {
                NSDictionary *mapping = @{
                    @"IOSVersion": @"version",
                    @"Darwin": @"darwin",
                    @"XNU": @"xnu",
                    @"KernelVersion": @"kernel_version"
                };
                [mapping enumerateKeysAndObjectsUsingBlock:^(NSString *profileKey, NSString *metaKey, BOOL *stop) {
                    (void)stop;
                    if (!PXDependencyEqualString(deviceIDs[profileKey], meta[metaKey])) {
                        issues[profileKey] = [NSString stringWithFormat:@"does-not-match-build-%@", metaKey];
                    }
                }];
                NSString *kernel = PXDependencyString(deviceIDs[@"KernelVersion"]);
                NSString *darwinNeedle = [NSString stringWithFormat:@"Darwin Kernel Version %@", PXDependencyString(deviceIDs[@"Darwin"]) ?: @""];
                NSString *xnuNeedle = [NSString stringWithFormat:@"xnu-%@", PXDependencyString(deviceIDs[@"XNU"]) ?: @""];
                if ([kernel rangeOfString:darwinNeedle].location == NSNotFound ||
                    [kernel rangeOfString:xnuNeedle].location == NSNotFound) {
                    issues[@"KernelVersion"] = @"kernel-banner-does-not-contain-darwin-xnu";
                }
            }
        }

        NSDictionary *model = productType.length ? models[productType] : nil;
        if (productType.length && !model) {
            issues[@"DeviceModel"] = @"model-not-in-versioned-database";
        }
        if (productType.length && softwarePresent == softwareKeys.count && deviceToBuilds) {
            NSArray *allowedBuilds = [deviceToBuilds[productType] isKindOfClass:[NSArray class]] ? deviceToBuilds[productType] : nil;
            if (![allowedBuilds containsObject:deviceIDs[@"IOSBuild"]]) {
                issues[@"modelBuild"] = @"build-not-supported-by-model";
            }
        }
        if (model) {
            NSString *boardID = PXDependencyString(deviceIDs[@"BoardID"]);
            NSString *hwModel = PXDependencyString(deviceIDs[@"HwModel"]);
            NSString *regulatoryModelNumber = PXDependencyString(deviceIDs[@"RegulatoryModelNumber"]);
            if ((boardID || hwModel || regulatoryModelNumber) &&
                !PXVariantMatches(model, boardID, hwModel, regulatoryModelNumber)) {
                issues[@"hardwareVariant"] = regulatoryModelNumber.length
                    ? @"board-hwmodel-regulatory-model-variant-mismatch"
                    : @"board-or-hwmodel-does-not-match-product-type";
            }

            BOOL p0Catalog = PXDependencyString(modelRoot[@"hardwareCatalogVersion"]).length > 0;
            PXValidateCanonicalModelHardware(deviceIDs, model, p0Catalog, issues);
        }
        // Preserve stable dependency contract reasons emitted by CELL-01:
        // cellular-identifiers-on-noncellular-model, secondary-imei-requires-primary-imei.
        PXCellularIdentityValidationResult *cellular =
            PXValidateCellularIdentitySchema(deviceIDs, model);
        [cellular.issues enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *detail, BOOL *stop) {
            (void)stop;
            issues[key] = detail;
        }];
    }

    PXIdentityDependencyValidationResult *result = [PXIdentityDependencyValidationResult new];
    result.issues = [issues copy];
    result.valid = issues.count == 0;
    return result;
}
