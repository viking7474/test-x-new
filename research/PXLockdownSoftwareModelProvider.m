#ifndef INTERNAL_SECURITY_RESEARCH
#define INTERNAL_SECURITY_RESEARCH 0
#endif
#if !INTERNAL_SECURITY_RESEARCH
#error "PXLockdownSoftwareModelProvider must never be compiled outside an Internal Research build"
#endif

#import "PXLockdownSoftwareModelProvider.h"
#import "PXConsistencyMatrix.h"

// Firmware constant names are documented for provenance but never mutated here.
static NSString *const kPXLockdownProductVersionKey = @"kLockdownProductVersionKey";
static NSString *const kPXLockdownBuildVersionKey = @"kLockdownBuildVersionKey";
static NSString *const kPXLockdownProductTypeKey = @"kLockdownProductTypeKey";
static NSString *const kPXLockdownDeviceNameKey = @"kLockdownDeviceNameKey";

@interface PXLockdownSoftwareModelEntry ()
@property (nonatomic, copy, readwrite) NSString *lockdownKey;
@property (nonatomic, copy, readwrite) NSString *deviceIDKey;
@property (nonatomic, copy, readwrite) NSString *consistencyGroup;
@property (nonatomic, copy, readwrite) NSString *toggle;
@property (nonatomic, readwrite) PXLockdownSoftwareOptionGroup optionGroup;
@end

@implementation PXLockdownSoftwareModelEntry
@end

static PXLockdownSoftwareModelEntry *PXEntry(NSString *lockdownKey, NSString *deviceIDKey,
                                             NSString *consistencyGroup, NSString *toggle,
                                             PXLockdownSoftwareOptionGroup optionGroup) {
    PXLockdownSoftwareModelEntry *entry = [[PXLockdownSoftwareModelEntry alloc] init];
    entry.lockdownKey = lockdownKey;
    entry.deviceIDKey = deviceIDKey;
    entry.consistencyGroup = consistencyGroup;
    entry.toggle = toggle;
    entry.optionGroup = optionGroup;
    return entry;
}

NSArray<PXLockdownSoftwareModelEntry *> *PXLockdownSoftwareModelEntries(void) {
    static NSArray<PXLockdownSoftwareModelEntry *> *entries = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        entries = @[
            PXEntry(kPXLockdownProductVersionKey, @"IOSVersion", @"ProductVersion", @"IOSVersion",
                    PXLockdownSoftwareOptionGroupSoftwareVersion),
            PXEntry(kPXLockdownBuildVersionKey, @"IOSBuild", @"ProductBuildVersion", @"IOSVersion",
                    PXLockdownSoftwareOptionGroupSoftwareVersion),
            PXEntry(kPXLockdownProductTypeKey, @"DeviceModel", @"DeviceModel", @"DeviceModel",
                    PXLockdownSoftwareOptionGroupProductModel),
            PXEntry(kPXLockdownDeviceNameKey, @"DeviceName", @"DeviceName", @"DeviceName",
                    PXLockdownSoftwareOptionGroupDeviceName),
        ];
    });
    return entries;
}

PXLockdownSoftwareModelEntry *PXLockdownSoftwareModelEntryForKey(NSString *lockdownKey) {
    if (![lockdownKey isKindOfClass:[NSString class]] || !lockdownKey.length) return nil;
    for (PXLockdownSoftwareModelEntry *entry in PXLockdownSoftwareModelEntries()) {
        if ([entry.lockdownKey isEqualToString:lockdownKey]) return entry;
    }
    return nil;
}

static BOOL PXStrictBool(id value) {
    return [value isKindOfClass:[NSNumber class]] && [value doubleValue] == 1.0;
}

PXLockdownSoftwareModelOptions PXLockdownSoftwareModelOptionsFromSettings(NSDictionary *settings) {
    NSDictionary *safe = [settings isKindOfClass:[NSDictionary class]] ? settings : @{};
    PXLockdownSoftwareModelOptions options;
    options.softwareVersion = PXStrictBool(safe[@"lockdownSoftwareVersionEnabled"]);
    options.productModel = PXStrictBool(safe[@"lockdownProductModelEnabled"]);
    options.deviceName = PXStrictBool(safe[@"lockdownDeviceNameEnabled"]);
    return options;
}

static BOOL PXOptionGroupEnabled(PXLockdownSoftwareOptionGroup group, PXLockdownSoftwareModelOptions options) {
    switch (group) {
        case PXLockdownSoftwareOptionGroupSoftwareVersion: return options.softwareVersion;
        case PXLockdownSoftwareOptionGroupProductModel: return options.productModel;
        case PXLockdownSoftwareOptionGroupDeviceName: return options.deviceName;
    }
    return NO;
}

BOOL PXLockdownSoftwareModelRegistryIsWellFormed(NSArray<NSString *> **outFailures) {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    NSMutableSet<NSString *> *groups = [NSMutableSet set];
    for (PXConsistencyMatrixEntry *entry in PXConsistencyMatrixEntries()) {
        [groups addObject:entry.group];
    }
    NSMutableSet<NSString *> *seenKeys = [NSMutableSet set];
    for (PXLockdownSoftwareModelEntry *entry in PXLockdownSoftwareModelEntries()) {
        if (!entry.lockdownKey.length || !entry.deviceIDKey.length || !entry.toggle.length) {
            [failures addObject:[NSString stringWithFormat:@"entry %@ has an empty field", entry.lockdownKey]];
        }
        if ([seenKeys containsObject:entry.lockdownKey]) {
            [failures addObject:[NSString stringWithFormat:@"duplicate lockdown key %@", entry.lockdownKey]];
        }
        [seenKeys addObject:entry.lockdownKey];
        if (![groups containsObject:entry.consistencyGroup]) {
            [failures addObject:[NSString stringWithFormat:@"entry %@ references unknown consistency group %@",
                                 entry.lockdownKey, entry.consistencyGroup]];
        }
    }
    if (outFailures) *outFailures = failures;
    return failures.count == 0;
}

// Focused, per-group cross-surface check using the public consistency matrix:
// every resolvable surface in the group must agree, the group must not be a
// partial projection, and the candidate must equal that single agreed value.
static BOOL PXGroupProjectsValue(NSString *group, NSDictionary *deviceIDs, NSString *candidate) {
    NSString *expected = nil;
    NSUInteger total = 0;
    NSUInteger resolved = 0;
    for (PXConsistencyMatrixEntry *entry in PXConsistencyMatrixEntries()) {
        if (![entry.group isEqualToString:group]) continue;
        total += 1;
        NSString *value = PXConsistencyResolveEntryValue(entry, deviceIDs);
        if (!value) continue;
        resolved += 1;
        if (!expected) expected = value;
        else if (![expected isEqualToString:value]) return NO;
    }
    if (total == 0 || resolved != total) return NO; // unknown group or partial projection
    return expected && [expected isEqualToString:candidate];
}

id PXLockdownSoftwareModelResolve(NSString *lockdownKey,
                                  id original,
                                  NSDictionary *deviceIDs,
                                  PXLockdownSoftwareModelOptions options,
                                  PXLockdownSafetyDecision *decision,
                                  NSArray<NSString *> **outFailures) {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    if (outFailures) *outFailures = failures;

    PXLockdownSoftwareModelEntry *entry = PXLockdownSoftwareModelEntryForKey(lockdownKey);
    if (!entry) return original; // out of Phase-5 scope
    if (!PXOptionGroupEnabled(entry.optionGroup, options)) {
        [failures addObject:[NSString stringWithFormat:@"%@: option group disabled", lockdownKey]];
        return original;
    }

    id rawCandidate = [deviceIDs isKindOfClass:[NSDictionary class]] ? deviceIDs[entry.deviceIDKey] : nil;
    NSString *candidate = [rawCandidate isKindOfClass:[NSString class]] ? (NSString *)rawCandidate : nil;
    NSString *trimmed = [candidate stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL hasValue = candidate != nil && trimmed.length > 0;
    if (!hasValue) {
        [failures addObject:[NSString stringWithFormat:@"%@: snapshot missing %@", lockdownKey, entry.deviceIDKey]];
    }

    BOOL consistent = hasValue && PXGroupProjectsValue(entry.consistencyGroup, deviceIDs, candidate);
    if (hasValue && !consistent) {
        [failures addObject:[NSString stringWithFormat:@"%@: group %@ failed cross-surface consistency",
                             lockdownKey, entry.consistencyGroup]];
    }

    // String type is preserved; the safety layer enforces observe-only/denied/
    // expired/kill-switch fail-closed behavior and the original fallback.
    return PXLockdownOriginalOrReplacement(original, candidate, [NSString class], decision, consistent);
}
