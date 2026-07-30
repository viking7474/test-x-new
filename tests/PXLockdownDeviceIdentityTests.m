#import <Foundation/Foundation.h>
#import "PXLockdownResearchSafety.h"
#import "PXLockdownDeviceIdentityProvider.h"
#import "PXIdentitySurfaceRegistry.h"

static PXLockdownSafetyDecision *PXAllowedDecision(PXLockdownResearchMode mode) {
    NSDictionary *settings = @{
        @"lockdownResearchEnabled": @YES,
        @"lockdownResearchMode": mode == PXLockdownResearchModeProfileBacked ? @"profile-backed" : @"observe-only",
        @"lockdownResearchBundleAllowlist": @[@"com.example.fixture"],
    };
    PXLockdownResearchPolicy *policy = [PXLockdownResearchPolicy policyFromSettings:settings];
    PXLockdownResearchRuntime *runtime = [[PXLockdownResearchRuntime alloc] initWithPolicy:policy];
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:1000];
    NSCAssert([runtime activateAt:now], @"fixture session did not arm");
    return [runtime decisionForBundleID:@"com.example.fixture" processName:@"Fixture" now:now];
}

void PXRunLockdownDeviceIdentityTests(void) {
    NSArray<NSString *> *structural = nil;
    NSCAssert(PXLockdownDeviceIdentityRegistryIsWellFormed(&structural),
              @"registry malformed: %@", structural);

    // A coherent device-identity trio.
    NSString *udid = @"a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0"; // 40-hex UDID
    NSString *serial = @"F2LLD9ABCD12";
    NSString *mlb = @"C02XY1234567890AB";
    NSDictionary *goodIDs = @{
        @"UDID": udid,
        @"SerialNumber": serial,
        @"MLBSerialNumber": mlb,
    };
    PXLockdownDeviceIdentityOptions on = PXLockdownDeviceIdentityOptionsFromSettings(@{
        @"lockdownDeviceIdentifiersEnabled": @YES,
    });
    PXLockdownSafetyDecision *allowed = PXAllowedDecision(PXLockdownResearchModeProfileBacked);
    NSArray<NSString *> *failures = nil;

    id resolvedUDID = PXLockdownDeviceIdentityResolve(@"kLockdownUniqueDeviceIDKey", @"orig", goodIDs, on, allowed, &failures);
    NSCAssert([resolvedUDID isEqual:udid], @"UDID not projected");
    NSCAssert([resolvedUDID isKindOfClass:[NSString class]], @"UDID must stay String");

    id resolvedSerial = PXLockdownDeviceIdentityResolve(@"kLockdownSerialNumberKey", @"orig", goodIDs, on, allowed, &failures);
    NSCAssert([resolvedSerial isEqual:serial], @"SerialNumber not projected");
    NSCAssert([resolvedSerial isKindOfClass:[NSString class]], @"SerialNumber must stay String");

    id resolvedMLB = PXLockdownDeviceIdentityResolve(@"kLockdownMLBSerialNumberKey", @"orig", goodIDs, on, allowed, &failures);
    NSCAssert([resolvedMLB isEqual:mlb], @"MLBSerialNumber not projected");

    // Positive cross-surface check: the projected serial equals every IORegistry
    // serial surface the shared registry resolves from the same snapshot.
    PXIdentitySurfaceEntry *ioSerial = PXIdentitySurfaceEntryForKey(@"IOPlatformSerialNumber", PXIdentitySurfaceIORegistry);
    PXIdentitySurfaceEntry *ioSerialAlias = PXIdentitySurfaceEntryForKey(@"serial-number", PXIdentitySurfaceIORegistry);
    NSCAssert(ioSerial && ioSerialAlias, @"serial surfaces missing from registry");
    NSCAssert([PXIdentitySurfaceResolveValue(ioSerial, goodIDs) isEqual:resolvedSerial],
              @"projected serial diverges from IOPlatformSerialNumber");
    NSCAssert([PXIdentitySurfaceResolveValue(ioSerialAlias, goodIDs) isEqual:resolvedSerial],
              @"projected serial diverges from serial-number");
    PXIdentitySurfaceEntry *ioMLB = PXIdentitySurfaceEntryForKey(@"mlb-serial-number", PXIdentitySurfaceIORegistry);
    NSCAssert(ioMLB && [PXIdentitySurfaceResolveValue(ioMLB, goodIDs) isEqual:resolvedMLB],
              @"projected MLB diverges from mlb-serial-number");

    // Out-of-scope keys (software/model, SoC/cellular) pass through untouched.
    id product = PXLockdownDeviceIdentityResolve(@"kLockdownProductTypeKey", @"orig-model", goodIDs, on, allowed, &failures);
    NSCAssert([product isEqual:@"orig-model"], @"out-of-scope key must return original");

    // Atomic group OFF: the whole trio returns original (no per-key switching).
    PXLockdownDeviceIdentityOptions off = PXLockdownDeviceIdentityOptionsFromSettings(@{});
    NSCAssert([PXLockdownDeviceIdentityResolve(@"kLockdownUniqueDeviceIDKey", @"orig", goodIDs, off, allowed, &failures) isEqual:@"orig"],
              @"identity group off must return original");
    NSCAssert([PXLockdownDeviceIdentityResolve(@"kLockdownSerialNumberKey", @"orig", goodIDs, off, allowed, &failures) isEqual:@"orig"],
              @"identity group off must return original");
    NSCAssert([PXLockdownDeviceIdentityResolve(@"kLockdownMLBSerialNumberKey", @"orig", goodIDs, off, allowed, &failures) isEqual:@"orig"],
              @"identity group off must return original");

    // Observe-only always returns original even when everything else allows.
    PXLockdownSafetyDecision *observe = PXAllowedDecision(PXLockdownResearchModeObserveOnly);
    id observed = PXLockdownDeviceIdentityResolve(@"kLockdownSerialNumberKey", @"orig", goodIDs, on, observe, &failures);
    NSCAssert([observed isEqual:@"orig"], @"observe-only must return original");

    // Malformed values fail closed: lowercase/short serial, hyphen-free bad UDID.
    NSMutableDictionary *badSerial = [goodIDs mutableCopy];
    badSerial[@"SerialNumber"] = @"bad serial!";
    NSCAssert([PXLockdownDeviceIdentityResolve(@"kLockdownSerialNumberKey", @"orig", badSerial, on, allowed, &failures) isEqual:@"orig"],
              @"malformed serial must return original");
    NSCAssert(!PXLockdownDeviceIdentityValueIsWellFormed(PXLockdownDeviceIdentityKindUDID, @"not-a-udid"),
              @"malformed UDID must be rejected");
    NSCAssert(PXLockdownDeviceIdentityValueIsWellFormed(PXLockdownDeviceIdentityKindUDID,
              @"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"), @"UUID-form UDID must be accepted");

    // Missing snapshot value fails closed.
    NSMutableDictionary *missing = [goodIDs mutableCopy];
    [missing removeObjectForKey:@"UDID"];
    NSCAssert([PXLockdownDeviceIdentityResolve(@"kLockdownUniqueDeviceIDKey", @"orig", missing, on, allowed, &failures) isEqual:@"orig"],
              @"missing snapshot value must return original");

    // Generation-stability contract.
    NSMutableDictionary *rotatedSerial = [goodIDs mutableCopy];
    rotatedSerial[@"SerialNumber"] = @"G7MMD1WXYZ98";
    NSArray<NSString *> *stabilityFailures = nil;
    NSCAssert(PXLockdownDeviceIdentityStableAcrossGeneration(goodIDs, 7, goodIDs, 7, &stabilityFailures),
              @"identical snapshot in one generation must be stable");
    NSCAssert(!PXLockdownDeviceIdentityStableAcrossGeneration(goodIDs, 7, rotatedSerial, 7, &stabilityFailures),
              @"identity changed within a generation must fail stability");
    NSCAssert(PXLockdownDeviceIdentityStableAcrossGeneration(goodIDs, 7, rotatedSerial, 8, &stabilityFailures),
              @"identity change across generations is allowed");

    NSLog(@"[LOCK-04] Lockdown device identity provider PASS");
}
