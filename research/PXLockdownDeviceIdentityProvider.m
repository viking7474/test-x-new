#ifndef INTERNAL_SECURITY_RESEARCH
#define INTERNAL_SECURITY_RESEARCH 0
#endif
#if !INTERNAL_SECURITY_RESEARCH
#error "PXLockdownDeviceIdentityProvider must never be compiled outside an Internal Research build"
#endif

#import "PXLockdownDeviceIdentityProvider.h"
#import "PXIdentitySurfaceRegistry.h"

// Firmware constant names are documented for provenance but never mutated here.
static NSString *const kPXLockdownUniqueDeviceIDKey = @"kLockdownUniqueDeviceIDKey";
static NSString *const kPXLockdownSerialNumberKey = @"kLockdownSerialNumberKey";
static NSString *const kPXLockdownMLBSerialNumberKey = @"kLockdownMLBSerialNumberKey";

@interface PXLockdownDeviceIdentityEntry ()
@property (nonatomic, copy, readwrite) NSString *lockdownKey;
@property (nonatomic, copy, readwrite) NSString *deviceIDKey;
@property (nonatomic, readwrite) PXLockdownDeviceIdentityKind kind;
@end

@implementation PXLockdownDeviceIdentityEntry
@end

static PXLockdownDeviceIdentityEntry *PXEntry(NSString *lockdownKey, NSString *deviceIDKey,
                                              PXLockdownDeviceIdentityKind kind) {
    PXLockdownDeviceIdentityEntry *entry = [[PXLockdownDeviceIdentityEntry alloc] init];
    entry.lockdownKey = lockdownKey;
    entry.deviceIDKey = deviceIDKey;
    entry.kind = kind;
    return entry;
}

NSArray<PXLockdownDeviceIdentityEntry *> *PXLockdownDeviceIdentityEntries(void) {
    static NSArray<PXLockdownDeviceIdentityEntry *> *entries = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        entries = @[
            PXEntry(kPXLockdownUniqueDeviceIDKey, @"UDID", PXLockdownDeviceIdentityKindUDID),
            PXEntry(kPXLockdownSerialNumberKey, @"SerialNumber", PXLockdownDeviceIdentityKindSerialNumber),
            PXEntry(kPXLockdownMLBSerialNumberKey, @"MLBSerialNumber", PXLockdownDeviceIdentityKindMLBSerialNumber),
        ];
    });
    return entries;
}

PXLockdownDeviceIdentityEntry *PXLockdownDeviceIdentityEntryForKey(NSString *lockdownKey) {
    if (![lockdownKey isKindOfClass:[NSString class]] || !lockdownKey.length) return nil;
    for (PXLockdownDeviceIdentityEntry *entry in PXLockdownDeviceIdentityEntries()) {
        if ([entry.lockdownKey isEqualToString:lockdownKey]) return entry;
    }
    return nil;
}

static BOOL PXStrictBool(id value) {
    return [value isKindOfClass:[NSNumber class]] && [value doubleValue] == 1.0;
}

PXLockdownDeviceIdentityOptions PXLockdownDeviceIdentityOptionsFromSettings(NSDictionary *settings) {
    NSDictionary *safe = [settings isKindOfClass:[NSDictionary class]] ? settings : @{};
    PXLockdownDeviceIdentityOptions options;
    // Single atomic switch: UDID / serial / MLB never toggle independently.
    options.deviceIdentifiers = PXStrictBool(safe[@"lockdownDeviceIdentifiersEnabled"]);
    return options;
}

BOOL PXLockdownDeviceIdentityRegistryIsWellFormed(NSArray<NSString *> **outFailures) {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    NSMutableSet<NSString *> *seenKeys = [NSMutableSet set];
    NSMutableSet<NSString *> *seenFields = [NSMutableSet set];
    for (PXLockdownDeviceIdentityEntry *entry in PXLockdownDeviceIdentityEntries()) {
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
        if (entry.kind > PXLockdownDeviceIdentityKindMLBSerialNumber) {
            [failures addObject:[NSString stringWithFormat:@"entry %@ has unknown identity kind", entry.lockdownKey]];
        }
    }
    if (outFailures) *outFailures = failures;
    return failures.count == 0;
}

static BOOL PXAllCharactersInSet(NSString *value, NSCharacterSet *allowed) {
    NSRange invalid = [value rangeOfCharacterFromSet:[allowed invertedSet]];
    return invalid.location == NSNotFound;
}

static BOOL PXIsUUIDString(NSString *value) {
    // Canonical 8-4-4-4-12 hex form used by modern UniqueDeviceID values.
    if (value.length != 36) return NO;
    return [[NSUUID alloc] initWithUUIDString:value] != nil;
}

BOOL PXLockdownDeviceIdentityValueIsWellFormed(PXLockdownDeviceIdentityKind kind, NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return NO;
    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0 || ![trimmed isEqualToString:value]) return NO; // reject padding

    NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    NSCharacterSet *serial = [NSCharacterSet characterSetWithCharactersInString:
                              @"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"]; // uppercase alnum
    switch (kind) {
        case PXLockdownDeviceIdentityKindUDID:
            // Legacy 40-hex UDID or a modern UUID string.
            if (value.length == 40 && PXAllCharactersInSet(value, hex)) return YES;
            return PXIsUUIDString(value);
        case PXLockdownDeviceIdentityKindSerialNumber:
            return value.length >= 8 && value.length <= 14 && PXAllCharactersInSet(value, serial);
        case PXLockdownDeviceIdentityKindMLBSerialNumber:
            return value.length >= 11 && value.length <= 20 && PXAllCharactersInSet(value, serial);
    }
    return NO;
}

// Cross-surface agreement using the shared MobileGestalt/IORegistry registry.
// Every registered surface for the identity's snapshot field must resolve to the
// same value as the candidate. A partial projection (some surfaces resolvable,
// others blank) fails closed. When no MG/IORegistry surface is registered for a
// field (e.g. UDID), there is nothing to diverge from, so form + presence gate it.
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
    if (total == 0) return YES;              // no cross-surface to check (e.g. UDID)
    if (resolved != total) return NO;        // partial projection
    return expected && [expected isEqualToString:candidate];
}

id PXLockdownDeviceIdentityResolve(NSString *lockdownKey,
                                   id original,
                                   NSDictionary *deviceIDs,
                                   PXLockdownDeviceIdentityOptions options,
                                   PXLockdownSafetyDecision *decision,
                                   NSArray<NSString *> **outFailures) {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    if (outFailures) *outFailures = failures;

    PXLockdownDeviceIdentityEntry *entry = PXLockdownDeviceIdentityEntryForKey(lockdownKey);
    if (!entry) return original; // out of Phase-6 scope
    if (!options.deviceIdentifiers) {
        [failures addObject:[NSString stringWithFormat:@"%@: device identity group disabled", lockdownKey]];
        return original;
    }

    id rawCandidate = [deviceIDs isKindOfClass:[NSDictionary class]] ? deviceIDs[entry.deviceIDKey] : nil;
    NSString *candidate = [rawCandidate isKindOfClass:[NSString class]] ? (NSString *)rawCandidate : nil;
    BOOL wellFormed = candidate != nil && PXLockdownDeviceIdentityValueIsWellFormed(entry.kind, candidate);
    if (!wellFormed) {
        [failures addObject:[NSString stringWithFormat:@"%@: snapshot %@ missing or malformed",
                             lockdownKey, entry.deviceIDKey]];
    }

    BOOL consistent = wellFormed && PXSurfacesAgree(entry.deviceIDKey, deviceIDs, candidate);
    if (wellFormed && !consistent) {
        [failures addObject:[NSString stringWithFormat:@"%@: %@ failed MG/IORegistry cross-surface check",
                             lockdownKey, entry.deviceIDKey]];
    }

    // String type is preserved; the safety layer enforces observe-only/denied/
    // expired/kill-switch fail-closed behavior and the original fallback.
    return PXLockdownOriginalOrReplacement(original, candidate, [NSString class], decision, consistent);
}

BOOL PXLockdownDeviceIdentityStableAcrossGeneration(NSDictionary *previousDeviceIDs,
                                                    uint64_t previousGeneration,
                                                    NSDictionary *currentDeviceIDs,
                                                    uint64_t currentGeneration,
                                                    NSArray<NSString *> **outFailures) {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    if (previousGeneration == currentGeneration) {
        for (PXLockdownDeviceIdentityEntry *entry in PXLockdownDeviceIdentityEntries()) {
            id before = [previousDeviceIDs isKindOfClass:[NSDictionary class]] ? previousDeviceIDs[entry.deviceIDKey] : nil;
            id after = [currentDeviceIDs isKindOfClass:[NSDictionary class]] ? currentDeviceIDs[entry.deviceIDKey] : nil;
            BOOL equal = (before == after) || [before isEqual:after];
            if (!equal) {
                [failures addObject:[NSString stringWithFormat:
                    @"%@ changed within generation %llu", entry.deviceIDKey, (unsigned long long)currentGeneration]];
            }
        }
    }
    if (outFailures) *outFailures = failures;
    return failures.count == 0;
}
