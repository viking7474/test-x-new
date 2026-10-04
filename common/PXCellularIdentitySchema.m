#import "PXCellularIdentitySchema.h"
#import "PXIdentityValidator.h"

@interface PXCellularIdentityValidationResult ()
@property (nonatomic, readwrite, getter=isValid) BOOL valid;
@property (nonatomic, readwrite) PXCellularCapability capabilities;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, NSString *> *issues;
@property (nonatomic, copy, readwrite) NSDictionary *canonicalDeviceIDs;
@end
@implementation PXCellularIdentityValidationResult
@end

static NSString *PXCellString(id value) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *result = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return result.length ? result : nil;
}

static BOOL PXCellBoolean(id value, BOOL *present) {
    if (present) *present = [value isKindOfClass:[NSNumber class]];
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : NO;
}

static BOOL PXCellMatches(NSString *value, NSString *pattern) {
    return value && [value rangeOfString:[NSString stringWithFormat:@"^(?:%@)$", pattern] options:NSRegularExpressionSearch].length == value.length;
}

static BOOL PXCellHasAllowedPrefix(NSString *value, NSArray *prefixes) {
    if (!value.length || ![prefixes isKindOfClass:[NSArray class]] || !prefixes.count) return NO;
    NSString *upper = [value uppercaseString];
    for (id item in prefixes) {
        if (![item isKindOfClass:[NSString class]]) continue;
        NSString *prefix = [(NSString *)item uppercaseString];
        if (prefix.length && [upper hasPrefix:prefix]) return YES;
    }
    return NO;
}

static NSDictionary *PXResolvedCellularSpec(NSDictionary *model, NSDictionary *deviceIDs) {
    id regionalValue = model[@"cellularByRegulatoryModelNumber"];
    NSDictionary *regional = [regionalValue isKindOfClass:[NSDictionary class]]
        ? regionalValue : nil;
    NSString *regulatoryModelNumber = PXCellString(deviceIDs[@"RegulatoryModelNumber"]);
    // Once a model publishes a regional map, an exact A-number match is
    // mandatory. Falling back to a generic record here could leak another
    // region's SIM/eSIM capabilities into an unknown regulatory variant.
    if (regionalValue) {
        return regulatoryModelNumber.length &&
            [regional[regulatoryModelNumber] isKindOfClass:[NSDictionary class]]
            ? regional[regulatoryModelNumber] : nil;
    }
    return [model[@"cellular"] isKindOfClass:[NSDictionary class]] ? model[@"cellular"] : nil;
}

static NSDictionary *PXResolvedBasebandSpec(NSDictionary *model, NSDictionary *deviceIDs) {
    NSDictionary *regional = [model[@"basebandByRegulatoryModelNumber"] isKindOfClass:[NSDictionary class]]
        ? model[@"basebandByRegulatoryModelNumber"] : nil;
    NSString *regulatoryModelNumber = PXCellString(deviceIDs[@"RegulatoryModelNumber"]);
    return regulatoryModelNumber.length && [regional[regulatoryModelNumber] isKindOfClass:[NSDictionary class]]
        ? regional[regulatoryModelNumber] : nil;
}

PXCellularIdentityValidationResult *PXValidateCellularIdentitySchema(NSDictionary *deviceIDs,
                                                                     NSDictionary *modelRecord) {
    NSMutableDictionary *canonical = [deviceIDs isKindOfClass:[NSDictionary class]] ? [deviceIDs mutableCopy] : [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSString *> *issues = [NSMutableDictionary dictionary];
    NSDictionary *model = [modelRecord isKindOfClass:[NSDictionary class]] ? modelRecord : @{};
    NSDictionary *caps = [model[@"capabilities"] isKindOfClass:[NSDictionary class]] ? model[@"capabilities"] : @{};
    BOOL requiresRegionalCellular = model[@"cellularByRegulatoryModelNumber"] != nil;
    // Regulatory A-number overrides take precedence because SIM/eSIM behavior can
    // vary by region even when ProductType/board are otherwise identical.
    NSDictionary *cellularSpec = PXResolvedCellularSpec(model, canonical);
    NSDictionary *basebandSpec = PXResolvedBasebandSpec(model, canonical);

    BOOL cellularPresent = NO;
    BOOL hasCellular = NO;
    BOOL physical = NO;
    BOOL esim = NO;
    BOOL dual = NO;
    BOOL cdma = NO;

    BOOL knownPresent = NO;
    BOOL cellularKnown = cellularSpec ? PXCellBoolean(cellularSpec[@"known"], &knownPresent) : NO;
    if (cellularSpec && knownPresent) {
        // P0 canonical schema: known=false is an explicit "do not guess" state.
        // Only known=true records may publish cellular capabilities.
        if (cellularKnown) {
            hasCellular = PXCellBoolean(cellularSpec[@"enabled"], &cellularPresent);
            physical = PXCellBoolean(cellularSpec[@"physicalSIM"], NULL);
            esim = PXCellBoolean(cellularSpec[@"eSIM"], NULL);
            dual = PXCellBoolean(cellularSpec[@"dualSIM"], NULL);
            cdma = PXCellBoolean(cellularSpec[@"cdma"], NULL);
        }
    } else if (!requiresRegionalCellular) {
        // Backward-compatible schema used by older database generations.
        hasCellular = PXCellBoolean(model[@"hasCellular"] ?: model[@"cellular"] ?: caps[@"cellular"], &cellularPresent);
        physical = PXCellBoolean(caps[@"physicalSIM"], NULL);
        esim = PXCellBoolean(caps[@"eSIM"], NULL);
        dual = PXCellBoolean(caps[@"dualSIM"], NULL);
        cdma = PXCellBoolean(caps[@"cdma"], NULL);
        if (hasCellular && !physical && !esim) physical = YES;
    }
    if (requiresRegionalCellular && !cellularSpec) {
        issues[@"cellularCapability"] = @"authoritative-cellular-required-for-regulatory-model";
    }
    if (cellularKnown && hasCellular && !physical && !esim) {
        issues[@"cellularCapability"] = @"authoritative-sim-capability-required";
    }
    PXCellularCapability capability = PXCellularCapabilityNone;
    if (hasCellular && physical) capability |= PXCellularCapabilityPhysicalSIM;
    if (hasCellular && esim) capability |= PXCellularCapabilityESIM;
    if (hasCellular && dual) capability |= PXCellularCapabilityDualSIM;
    if (hasCellular && cdma) capability |= PXCellularCapabilityCDMA;

    NSArray *keys = @[@"IMEI", @"IMEI2", @"MEID", @"ICCID", @"IMSI", @"BasebandVersion"];
    BOOL any = NO;
    for (NSString *key in keys) if (PXCellString(canonical[key])) { any = YES; break; }
    if (any && !cellularPresent) issues[@"cellularCapability"] = @"explicit-cellular-capability-required";
    if (any && !hasCellular) issues[@"cellular"] = @"cellular-identifiers-on-noncellular-model";

    NSArray *imeiTACs = [cellularSpec[@"imeiTACs"] isKindOfClass:[NSArray class]]
        ? cellularSpec[@"imeiTACs"] : nil;
    for (NSString *key in @[@"IMEI", @"IMEI2"]) {
        NSString *value = PXCellString(canonical[key]);
        if (value) {
            NSString *normalized = PXCanonicalIdentityValue(value, PXIdentityValueKindIMEI, NO);
            if (!normalized) {
                issues[key] = @"invalid-imei";
            } else if (cellularKnown && hasCellular &&
                       !PXCellHasAllowedPrefix(normalized, imeiTACs)) {
                issues[key] = @"imei-tac-does-not-match-regulatory-model";
            } else {
                canonical[key] = normalized;
            }
        }
    }
    NSString *meid = PXCellString(canonical[@"MEID"]);
    if (meid) {
        NSString *normalized = PXCanonicalIdentityValue(meid, PXIdentityValueKindMEID, NO);
        NSArray *meidPrefixes = [cellularSpec[@"meidPrefixes"] isKindOfClass:[NSArray class]]
            ? cellularSpec[@"meidPrefixes"] : nil;
        if (!cdma) {
            issues[@"MEID"] = @"meid-requires-cdma-capability";
        } else if (!normalized) {
            issues[@"MEID"] = @"invalid-meid";
        } else if (cellularKnown && !PXCellHasAllowedPrefix(normalized, meidPrefixes)) {
            issues[@"MEID"] = @"meid-prefix-does-not-match-regulatory-model";
        } else {
            canonical[@"MEID"] = normalized;
        }
    }
    NSString *iccid = PXCellString(canonical[@"ICCID"]);
    if (iccid && !PXCellMatches(iccid, @"[0-9]{18,22}")) issues[@"ICCID"] = @"invalid-iccid";
    NSString *imsi = PXCellString(canonical[@"IMSI"]);
    if (imsi && !PXCellMatches(imsi, @"[0-9]{14,16}")) issues[@"IMSI"] = @"invalid-imsi";
    NSString *baseband = PXCellString(canonical[@"BasebandVersion"]);
    NSString *basebandFamily = PXCellString(canonical[@"BasebandFamily"]);
    if (hasCellular && !baseband) issues[@"BasebandVersion"] = @"cellular-model-requires-baseband-version";
    if (baseband && !PXCellMatches(baseband, @"[0-9A-Za-z][0-9A-Za-z._-]{0,63}")) {
        issues[@"BasebandVersion"] = @"invalid-baseband-version";
    }

    NSDictionary *regionalBaseband = [model[@"basebandByRegulatoryModelNumber"] isKindOfClass:[NSDictionary class]]
        ? model[@"basebandByRegulatoryModelNumber"] : nil;
    if (cellularKnown && hasCellular && regionalBaseband.count) {
        BOOL basebandKnownPresent = NO;
        BOOL basebandKnown = basebandSpec ? PXCellBoolean(basebandSpec[@"known"], &basebandKnownPresent) : NO;
        if (!basebandSpec || !basebandKnownPresent || !basebandKnown) {
            issues[@"BasebandVersion"] = @"authoritative-baseband-required-for-regulatory-model";
        } else {
            NSString *expectedFamily = PXCellString(basebandSpec[@"basebandFamily"]);
            NSDictionary *builds = [basebandSpec[@"builds"] isKindOfClass:[NSDictionary class]]
                ? basebandSpec[@"builds"] : nil;
            NSString *iosBuild = PXCellString(canonical[@"IOSBuild"]);
            NSString *expectedVersion = iosBuild.length ? PXCellString(builds[iosBuild]) : nil;
            if (!iosBuild.length || !expectedVersion.length) {
                issues[@"BasebandVersion"] = @"baseband-build-not-authoritative";
            } else {
                if (!baseband || ![baseband isEqualToString:expectedVersion]) {
                    issues[@"BasebandVersion"] = @"does-not-match-canonical-baseband-build";
                }
                if (!expectedFamily.length || !basebandFamily.length ||
                    ![basebandFamily isEqualToString:expectedFamily]) {
                    issues[@"BasebandFamily"] = @"does-not-match-canonical-baseband-family";
                }
            }
        }
    }
    if (PXCellString(canonical[@"IMEI2"]) && !PXCellString(canonical[@"IMEI"])) issues[@"IMEI2"] = @"secondary-imei-requires-primary-imei";
    if (PXCellString(canonical[@"IMEI2"]) && !dual) issues[@"IMEI2"] = @"secondary-imei-requires-dual-sim-capability";

    PXCellularIdentityValidationResult *result = [PXCellularIdentityValidationResult new];
    result.capabilities = capability;
    result.issues = [issues copy];
    result.canonicalDeviceIDs = [canonical copy];
    result.valid = issues.count == 0;
    return result;
}
