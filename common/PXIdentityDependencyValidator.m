#import "PXIdentityDependencyValidator.h"

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

static NSNumber *PXExplicitCellularCapability(NSDictionary *model) {
    id value = model[@"hasCellular"] ?: model[@"cellular"];
    NSDictionary *capabilities = [model[@"capabilities"] isKindOfClass:[NSDictionary class]] ? model[@"capabilities"] : nil;
    if (!value) value = capabilities[@"cellular"] ?: capabilities[@"telephony"];
    return [value isKindOfClass:[NSNumber class]] ? value : nil;
}

static BOOL PXVariantMatches(NSDictionary *model, NSString *boardID, NSString *hwModel) {
    NSArray *variants = [model[@"variants"] isKindOfClass:[NSArray class]] ? model[@"variants"] : nil;
    if (variants.count) {
        for (id row in variants) {
            if (![row isKindOfClass:[NSDictionary class]]) continue;
            BOOL boardMatches = !boardID || PXDependencyEqualString(boardID, row[@"boardID"]);
            BOOL hwMatches = !hwModel || PXDependencyEqualString(hwModel, row[@"hwModel"]);
            if (boardMatches && hwMatches) return YES;
        }
        return NO;
    }
    BOOL boardMatches = !boardID || PXDependencyEqualString(boardID, model[@"boardID"]);
    BOOL hwMatches = !hwModel || PXDependencyEqualString(hwModel, model[@"hwModel"]);
    return boardMatches && hwMatches;
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
            if ((boardID || hwModel) && !PXVariantMatches(model, boardID, hwModel)) {
                issues[@"hardwareVariant"] = @"board-or-hwmodel-does-not-match-product-type";
            }
            NSNumber *hasCellular = PXExplicitCellularCapability(model);
            NSArray *cellularKeys = @[@"IMEI", @"IMEI2", @"MEID", @"ICCID", @"IMSI", @"BasebandVersion"];
            BOOL hasCellularValue = NO;
            for (NSString *key in cellularKeys) if (PXDependencyString(deviceIDs[key])) { hasCellularValue = YES; break; }
            if (hasCellular && !hasCellular.boolValue && hasCellularValue) {
                issues[@"cellular"] = @"cellular-identifiers-on-noncellular-model";
            }
            if (PXDependencyString(deviceIDs[@"IMEI2"]) && !PXDependencyString(deviceIDs[@"IMEI"])) {
                issues[@"IMEI2"] = @"secondary-imei-requires-primary-imei";
            }
        }
    }

    PXIdentityDependencyValidationResult *result = [PXIdentityDependencyValidationResult new];
    result.issues = [issues copy];
    result.valid = issues.count == 0;
    return result;
}
