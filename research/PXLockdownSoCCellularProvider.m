#ifndef INTERNAL_SECURITY_RESEARCH
#define INTERNAL_SECURITY_RESEARCH 0
#endif
#if !INTERNAL_SECURITY_RESEARCH
#error "PXLockdownSoCCellularProvider must never be compiled outside an Internal Research build"
#endif

#import "PXLockdownSoCCellularProvider.h"
#import "PXIdentitySurfaceRegistry.h"

// Firmware constant names are documented for provenance but never mutated here.
static NSString *const kPXLockdownUniqueChipIDKey = @"kLockdownUniqueChipIDKey";
static NSString *const kPXLockdownIMEIKey = @"kLockdownIMEIKey";
static NSString *const kPXLockdownSecondaryIMEIKey = @"kLockdownSecondaryIMEIKey";
static NSString *const kPXLockdownMobileEquipmentIdentifierKey = @"kLockdownMobileEquipmentIdentifierKey";
static NSString *const kPXLockdownBasebandVersionKey = @"kLockdownBasebandVersionKey";

@interface PXLockdownSoCCellularEntry ()
@property (nonatomic, copy, readwrite) NSString *lockdownKey;
@property (nonatomic, copy, readwrite) NSString *deviceIDKey;
@property (nonatomic, readwrite) PXLockdownSoCCellularKind kind;
@property (nonatomic, readwrite) PXLockdownSoCCellularGroup group;
@property (nonatomic, readwrite) BOOL requiresCellular;
@end

@implementation PXLockdownSoCCellularEntry
@end

static PXLockdownSoCCellularEntry *PXEntry(NSString *lockdownKey, NSString *deviceIDKey,
                                           PXLockdownSoCCellularKind kind,
                                           PXLockdownSoCCellularGroup group,
                                           BOOL requiresCellular) {
    PXLockdownSoCCellularEntry *entry = [[PXLockdownSoCCellularEntry alloc] init];
    entry.lockdownKey = lockdownKey;
    entry.deviceIDKey = deviceIDKey;
    entry.kind = kind;
    entry.group = group;
    entry.requiresCellular = requiresCellular;
    return entry;
}

NSArray<PXLockdownSoCCellularEntry *> *PXLockdownSoCCellularEntries(void) {
    static NSArray<PXLockdownSoCCellularEntry *> *entries = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        entries = @[
            PXEntry(kPXLockdownUniqueChipIDKey, @"UniqueChipID",
                    PXLockdownSoCCellularKindUniqueChipID, PXLockdownSoCCellularGroupSoCIdentity, NO),
            PXEntry(kPXLockdownIMEIKey, @"IMEI",
                    PXLockdownSoCCellularKindIMEI, PXLockdownSoCCellularGroupCellularBaseband, YES),
            PXEntry(kPXLockdownSecondaryIMEIKey, @"IMEI2",
                    PXLockdownSoCCellularKindSecondaryIMEI, PXLockdownSoCCellularGroupCellularBaseband, YES),
            PXEntry(kPXLockdownMobileEquipmentIdentifierKey, @"MEID",
                    PXLockdownSoCCellularKindMEID, PXLockdownSoCCellularGroupCellularBaseband, YES),
            PXEntry(kPXLockdownBasebandVersionKey, @"BasebandVersion",
                    PXLockdownSoCCellularKindBasebandVersion, PXLockdownSoCCellularGroupCellularBaseband, YES),
        ];
    });
    return entries;
}

PXLockdownSoCCellularEntry *PXLockdownSoCCellularEntryForKey(NSString *lockdownKey) {
    if (![lockdownKey isKindOfClass:[NSString class]] || !lockdownKey.length) return nil;
    for (PXLockdownSoCCellularEntry *entry in PXLockdownSoCCellularEntries()) {
        if ([entry.lockdownKey isEqualToString:lockdownKey]) return entry;
    }
    return nil;
}

static BOOL PXStrictBool(id value) {
    return [value isKindOfClass:[NSNumber class]] && [value doubleValue] == 1.0;
}

PXLockdownSoCCellularOptions PXLockdownSoCCellularOptionsFromSettings(NSDictionary *settings) {
    NSDictionary *safe = [settings isKindOfClass:[NSDictionary class]] ? settings : @{};
    PXLockdownSoCCellularOptions options;
    // Two atomic groups: chip identity and cellular/baseband never split per key.
    options.socIdentity = PXStrictBool(safe[@"lockdownSoCIdentityEnabled"]);
    options.cellularBaseband = PXStrictBool(safe[@"lockdownCellularBasebandEnabled"]);
    return options;
}

PXLockdownCellularCapability PXLockdownCellularCapabilityFromSpecs(NSDictionary *specs) {
    NSDictionary *safe = [specs isKindOfClass:[NSDictionary class]] ? specs : @{};
    PXLockdownCellularCapability cap;
    cap.cellularCapable = PXStrictBool(safe[@"CellularCapable"]);
    id count = safe[@"AdvertisedSIMCount"];
    cap.advertisedSIMCount = [count isKindOfClass:[NSNumber class]] ? [count unsignedIntegerValue] : 0;
    return cap;
}

// Fixture-level model tables. Correctness of the map is not safety critical: the
// validator fails closed for any ProductType it does not recognise.
static NSDictionary<NSString *, NSString *> *PXProductTypeSoCMap(void) {
    static NSDictionary *map = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        map = @{ @"iPhone12,1": @"T8030", @"iPhone13,2": @"T8101", @"iPad13,1": @"T8103" };
    });
    return map;
}

static NSDictionary<NSString *, NSString *> *PXProductTypeBasebandFamilyMap(void) {
    static NSDictionary *map = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Wi-Fi-only models are intentionally absent (no baseband family).
        map = @{ @"iPhone12,1": @"Intel-XMM7660", @"iPhone13,2": @"Qualcomm-SDX55" };
    });
    return map;
}

static BOOL PXProductTypeIsCellularCapable(NSString *productType) {
    return [productType isKindOfClass:[NSString class]] && PXProductTypeBasebandFamilyMap()[productType] != nil;
}

BOOL PXLockdownSoCMatchesProductType(NSString *productType, NSString *soc) {
    if (![productType isKindOfClass:[NSString class]] || ![soc isKindOfClass:[NSString class]]) return NO;
    NSString *expected = PXProductTypeSoCMap()[productType];
    return expected != nil && [expected isEqualToString:soc];
}

BOOL PXLockdownBasebandFamilyMatchesProductType(NSString *productType, NSString *family) {
    if (![productType isKindOfClass:[NSString class]] || ![family isKindOfClass:[NSString class]]) return NO;
    NSString *expected = PXProductTypeBasebandFamilyMap()[productType];
    return expected != nil && [expected isEqualToString:family];
}

static BOOL PXIsAllDigits(NSString *value) {
    if (![value isKindOfClass:[NSString class]] || value.length == 0) return NO;
    NSCharacterSet *digits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    return [value rangeOfCharacterFromSet:[digits invertedSet]].location == NSNotFound;
}

static BOOL PXLuhnValid(NSString *value) {
    NSUInteger sum = 0;
    BOOL doubleDigit = NO;
    for (NSInteger i = (NSInteger)value.length - 1; i >= 0; i--) {
        int digit = [value characterAtIndex:i] - '0';
        if (doubleDigit) { digit *= 2; if (digit > 9) digit -= 9; }
        sum += (NSUInteger)digit;
        doubleDigit = !doubleDigit;
    }
    return (sum % 10) == 0;
}

static BOOL PXIsValidIMEI(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return NO;
    if (value.length != 15 || !PXIsAllDigits(value)) return NO;
    return PXLuhnValid(value);
}

static BOOL PXIsValidMEID(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return NO;
    NSCharacterSet *hexUpper = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"];
    if (value.length == 14 && [value rangeOfCharacterFromSet:[hexUpper invertedSet]].location == NSNotFound) return YES;
    if (value.length == 18 && PXIsAllDigits(value)) return YES;
    return NO;
}

static BOOL PXIsValidBaseband(NSString *value) {
    if (![value isKindOfClass:[NSString class]] || value.length == 0) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"0123456789."];
    if ([value rangeOfCharacterFromSet:[allowed invertedSet]].location != NSNotFound) return NO;
    if ([value hasPrefix:@"."] || [value hasSuffix:@"."]) return NO;
    if ([value rangeOfString:@"."].location == NSNotFound) return NO;   // require at least one dotted component
    if ([value rangeOfString:@".."].location != NSNotFound) return NO;  // reject empty components
    return YES;
}

static BOOL PXChipIDIsWellFormed(id value) {
    if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value unsignedLongLongValue] != 0ULL;
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *string = (NSString *)value;
        NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length == 0 || ![trimmed isEqualToString:string]) return NO;
        NSString *body = ([string hasPrefix:@"0x"] || [string hasPrefix:@"0X"]) ? [string substringFromIndex:2] : string;
        if (body.length == 0) return NO;
        NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
        if ([body rangeOfCharacterFromSet:[hex invertedSet]].location != NSNotFound) return NO;
        NSCharacterSet *nonzero = [NSCharacterSet characterSetWithCharactersInString:@"123456789abcdefABCDEF"];
        return [body rangeOfCharacterFromSet:nonzero].location != NSNotFound;
    }
    return NO;
}

// Cross-surface agreement using the shared MobileGestalt/IORegistry registry.
// Every registered surface for the field must resolve to the same value as the
// candidate. A partial projection fails closed. When no surface is registered
// (e.g. IMEI2, baseband) there is nothing to diverge from, so form + capability
// gate the value instead.
static BOOL PXSurfacesAgree(NSString *deviceIDKey, NSDictionary *deviceIDs, NSString *candidate) {
    NSUInteger total = 0;
    NSUInteger resolved = 0;
    NSString *expected = nil;
    for (PXIdentitySurfaceEntry *entry in PXIdentitySurfaceRegistryEntries()) {
        if (![entry.deviceIDKey isEqualToString:deviceIDKey]) continue;
        total += 1;
        NSString *value = PXIdentitySurfaceResolveValue(entry, deviceIDs);
        if (!value) continue;
        resolved += 1;
        if (!expected) expected = value;
        else if (![expected isEqualToString:value]) return NO;
    }
    if (total == 0) return YES;
    if (resolved != total) return NO;
    return expected && [expected isEqualToString:candidate];
}

BOOL PXLockdownSoCCellularRegistryIsWellFormed(NSArray<NSString *> **outFailures) {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    NSMutableSet<NSString *> *seenKeys = [NSMutableSet set];
    NSMutableSet<NSString *> *seenFields = [NSMutableSet set];
    for (PXLockdownSoCCellularEntry *entry in PXLockdownSoCCellularEntries()) {
        if (!entry.lockdownKey.length || !entry.deviceIDKey.length) {
            [failures addObject:[NSString stringWithFormat:@"entry %@ has an empty field", entry.lockdownKey]];
        }
        if ([seenKeys containsObject:entry.lockdownKey]) {
            [failures addObject:[NSString stringWithFormat:@"duplicate lockdown key %@", entry.lockdownKey]];
        }
        [seenKeys addObject:entry.lockdownKey];
        if ([seenFields containsObject:entry.deviceIDKey]) {
            [failures addObject:[NSString stringWithFormat:@"duplicate snapshot field %@", entry.deviceIDKey]];
        }
        [seenFields addObject:entry.deviceIDKey];
        if (entry.kind > PXLockdownSoCCellularKindBasebandVersion) {
            [failures addObject:[NSString stringWithFormat:@"entry %@ has unknown kind", entry.lockdownKey]];
        }
        BOOL chip = entry.kind == PXLockdownSoCCellularKindUniqueChipID;
        BOOL socGroup = entry.group == PXLockdownSoCCellularGroupSoCIdentity;
        if (chip != socGroup) {
            [failures addObject:[NSString stringWithFormat:@"entry %@ has an inconsistent option group", entry.lockdownKey]];
        }
        if (chip == entry.requiresCellular) {
            [failures addObject:[NSString stringWithFormat:@"entry %@ has an inconsistent cellular requirement", entry.lockdownKey]];
        }
    }
    if (outFailures) *outFailures = failures;
    return failures.count == 0;
}

BOOL PXLockdownSoCCellularSchemaValidate(NSDictionary *deviceIDs,
                                         NSDictionary *specs,
                                         NSArray<NSString *> **outFailures) {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    NSDictionary *ids = [deviceIDs isKindOfClass:[NSDictionary class]] ? deviceIDs : @{};
    NSDictionary *sp = [specs isKindOfClass:[NSDictionary class]] ? specs : @{};
    NSString *productType = [sp[@"ProductType"] isKindOfClass:[NSString class]] ? sp[@"ProductType"] : nil;
    NSString *soc = [sp[@"SoC"] isKindOfClass:[NSString class]] ? sp[@"SoC"] : nil;
    NSString *family = [sp[@"BasebandFamily"] isKindOfClass:[NSString class]] ? sp[@"BasebandFamily"] : nil;
    PXLockdownCellularCapability cap = PXLockdownCellularCapabilityFromSpecs(sp);

    NSString *imei = [ids[@"IMEI"] isKindOfClass:[NSString class]] ? ids[@"IMEI"] : nil;
    NSString *imei2 = [ids[@"IMEI2"] isKindOfClass:[NSString class]] ? ids[@"IMEI2"] : nil;
    NSString *meid = [ids[@"MEID"] isKindOfClass:[NSString class]] ? ids[@"MEID"] : nil;
    NSString *baseband = [ids[@"BasebandVersion"] isKindOfClass:[NSString class]] ? ids[@"BasebandVersion"] : nil;
    id chipID = ids[@"UniqueChipID"];

    if (productType && PXProductTypeIsCellularCapable(productType) != cap.cellularCapable) {
        [failures addObject:@"CellularCapable disagrees with the model capability table"];
    }

    if (!cap.cellularCapable) {
        if (imei || imei2 || meid || baseband) {
            [failures addObject:@"Wi-Fi-only model must not expose cellular identifiers"];
        }
    } else {
        if (!PXIsValidIMEI(imei)) [failures addObject:@"cellular model is missing a valid IMEI"];
        if (!PXIsValidBaseband(baseband)) [failures addObject:@"cellular model is missing a valid baseband version"];
        if (!(productType && PXLockdownBasebandFamilyMatchesProductType(productType, family))) {
            [failures addObject:@"baseband family does not match the model"];
        }
        if (cap.advertisedSIMCount >= 2) {
            if (!PXIsValidIMEI(imei2)) [failures addObject:@"dual-SIM model is missing a valid second IMEI"];
        } else if (imei2) {
            [failures addObject:@"single-SIM model must not expose a second IMEI"];
        }
        if (meid && !PXIsValidMEID(meid)) [failures addObject:@"MEID is malformed"];
    }

    if (!(productType && PXLockdownSoCMatchesProductType(productType, soc))) {
        [failures addObject:@"SoC does not correspond to the ProductType"];
    }
    if (!PXChipIDIsWellFormed(chipID)) {
        [failures addObject:@"UniqueChipID is missing or malformed"];
    }

    if (outFailures) *outFailures = failures;
    return failures.count == 0;
}

id PXLockdownSoCCellularResolve(NSString *lockdownKey,
                                id original,
                                NSDictionary *deviceIDs,
                                NSDictionary *specs,
                                PXLockdownSoCCellularOptions options,
                                PXLockdownSafetyDecision *decision,
                                NSArray<NSString *> **outFailures) {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    if (outFailures) *outFailures = failures;

    PXLockdownSoCCellularEntry *entry = PXLockdownSoCCellularEntryForKey(lockdownKey);
    if (!entry) return original; // out of Phase-7 scope

    BOOL groupOn = entry.group == PXLockdownSoCCellularGroupSoCIdentity
                       ? options.socIdentity : options.cellularBaseband;
    if (!groupOn) {
        [failures addObject:[NSString stringWithFormat:@"%@: option group disabled", lockdownKey]];
        return original;
    }

    NSDictionary *ids = [deviceIDs isKindOfClass:[NSDictionary class]] ? deviceIDs : @{};
    NSDictionary *sp = [specs isKindOfClass:[NSDictionary class]] ? specs : @{};
    NSString *productType = [sp[@"ProductType"] isKindOfClass:[NSString class]] ? sp[@"ProductType"] : nil;
    PXLockdownCellularCapability cap = PXLockdownCellularCapabilityFromSpecs(sp);

    if (entry.requiresCellular && !cap.cellularCapable) {
        [failures addObject:[NSString stringWithFormat:@"%@: Wi-Fi-only model cannot expose cellular identifiers", lockdownKey]];
        return original; // fail closed
    }

    id rawCandidate = ids[entry.deviceIDKey];
    id candidate = nil;
    BOOL consistent = NO;
    Class expectedClass = [NSString class];

    switch (entry.kind) {
        case PXLockdownSoCCellularKindUniqueChipID: {
            candidate = rawCandidate; // preserve original CFType
            NSString *soc = [sp[@"SoC"] isKindOfClass:[NSString class]] ? sp[@"SoC"] : nil;
            consistent = PXChipIDIsWellFormed(candidate) && PXLockdownSoCMatchesProductType(productType, soc);
            expectedClass = original ? [original class] : (candidate ? [candidate class] : [NSNumber class]);
            break;
        }
        case PXLockdownSoCCellularKindIMEI: {
            candidate = [rawCandidate isKindOfClass:[NSString class]] ? rawCandidate : nil;
            consistent = PXIsValidIMEI(candidate) && PXSurfacesAgree(@"IMEI", ids, candidate);
            break;
        }
        case PXLockdownSoCCellularKindSecondaryIMEI: {
            candidate = [rawCandidate isKindOfClass:[NSString class]] ? rawCandidate : nil;
            consistent = cap.advertisedSIMCount >= 2 && PXIsValidIMEI(candidate);
            break;
        }
        case PXLockdownSoCCellularKindMEID: {
            candidate = [rawCandidate isKindOfClass:[NSString class]] ? rawCandidate : nil;
            consistent = PXIsValidMEID(candidate) && PXSurfacesAgree(@"MEID", ids, candidate);
            break;
        }
        case PXLockdownSoCCellularKindBasebandVersion: {
            candidate = [rawCandidate isKindOfClass:[NSString class]] ? rawCandidate : nil;
            NSString *family = [sp[@"BasebandFamily"] isKindOfClass:[NSString class]] ? sp[@"BasebandFamily"] : nil;
            consistent = PXIsValidBaseband(candidate) && PXLockdownBasebandFamilyMatchesProductType(productType, family);
            break;
        }
    }

    if (!consistent) {
        [failures addObject:[NSString stringWithFormat:@"%@: snapshot value failed SoC/cellular validation", lockdownKey]];
    }

    return PXLockdownOriginalOrReplacement(original, candidate, expectedClass, decision, consistent);
}
