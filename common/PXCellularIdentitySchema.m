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

PXCellularIdentityValidationResult *PXValidateCellularIdentitySchema(NSDictionary *deviceIDs,
                                                                     NSDictionary *modelRecord) {
    NSMutableDictionary *canonical = [deviceIDs isKindOfClass:[NSDictionary class]] ? [deviceIDs mutableCopy] : [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSString *> *issues = [NSMutableDictionary dictionary];
    NSDictionary *model = [modelRecord isKindOfClass:[NSDictionary class]] ? modelRecord : @{};
    NSDictionary *caps = [model[@"capabilities"] isKindOfClass:[NSDictionary class]] ? model[@"capabilities"] : @{};
    BOOL cellularPresent = NO;
    BOOL hasCellular = PXCellBoolean(model[@"hasCellular"] ?: model[@"cellular"] ?: caps[@"cellular"], &cellularPresent);
    BOOL physical = PXCellBoolean(caps[@"physicalSIM"], NULL);
    BOOL esim = PXCellBoolean(caps[@"eSIM"], NULL);
    BOOL dual = PXCellBoolean(caps[@"dualSIM"], NULL);
    BOOL cdma = PXCellBoolean(caps[@"cdma"], NULL);
    if (hasCellular && !physical && !esim) physical = YES;
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

    for (NSString *key in @[@"IMEI", @"IMEI2"]) {
        NSString *value = PXCellString(canonical[key]);
        if (value) {
            NSString *normalized = PXCanonicalIdentityValue(value, PXIdentityValueKindIMEI, NO);
            if (normalized) canonical[key] = normalized; else issues[key] = @"invalid-imei";
        }
    }
    NSString *meid = PXCellString(canonical[@"MEID"]);
    if (meid) {
        NSString *normalized = PXCanonicalIdentityValue(meid, PXIdentityValueKindMEID, NO);
        if (!cdma) issues[@"MEID"] = @"meid-requires-cdma-capability";
        else if (normalized) canonical[@"MEID"] = normalized;
        else issues[@"MEID"] = @"invalid-meid";
    }
    NSString *iccid = PXCellString(canonical[@"ICCID"]);
    if (iccid && !PXCellMatches(iccid, @"[0-9]{18,22}")) issues[@"ICCID"] = @"invalid-iccid";
    NSString *imsi = PXCellString(canonical[@"IMSI"]);
    if (imsi && !PXCellMatches(imsi, @"[0-9]{14,16}")) issues[@"IMSI"] = @"invalid-imsi";
    NSString *baseband = PXCellString(canonical[@"BasebandVersion"]);
    if (hasCellular && !baseband) issues[@"BasebandVersion"] = @"cellular-model-requires-baseband-version";
    if (baseband && !PXCellMatches(baseband, @"[0-9A-Za-z][0-9A-Za-z._-]{0,63}")) issues[@"BasebandVersion"] = @"invalid-baseband-version";
    if (PXCellString(canonical[@"IMEI2"]) && !PXCellString(canonical[@"IMEI"])) issues[@"IMEI2"] = @"secondary-imei-requires-primary-imei";
    if (PXCellString(canonical[@"IMEI2"]) && !dual) issues[@"IMEI2"] = @"secondary-imei-requires-dual-sim-capability";

    PXCellularIdentityValidationResult *result = [PXCellularIdentityValidationResult new];
    result.capabilities = capability;
    result.issues = [issues copy];
    result.canonicalDeviceIDs = [canonical copy];
    result.valid = issues.count == 0;
    return result;
}
