#import <Foundation/Foundation.h>
#import "PXLockdownResearchSafety.h"
#import "PXLockdownSoCCellularProvider.h"
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

void PXRunLockdownSoCCellularTests(void) {
    NSArray<NSString *> *structural = nil;
    NSCAssert(PXLockdownSoCCellularRegistryIsWellFormed(&structural),
              @"registry malformed: %@", structural);

    // Coherent dual-SIM cellular fixture. Both IMEIs satisfy Luhn.
    NSNumber *chipID = @123456789012345;
    NSDictionary *goodIDs = @{
        @"UniqueChipID": chipID,
        @"IMEI": @"490154203237518",
        @"IMEI2": @"356938035643809",
        @"MEID": @"A00000BEEF1234",
        @"BasebandVersion": @"2.10.04",
    };
    NSDictionary *cellularSpecs = @{
        @"ProductType": @"iPhone13,2",
        @"SoC": @"T8101",
        @"CellularCapable": @YES,
        @"AdvertisedSIMCount": @2,
        @"BasebandFamily": @"Qualcomm-SDX55",
    };
    PXLockdownSoCCellularOptions on = PXLockdownSoCCellularOptionsFromSettings(@{
        @"lockdownSoCIdentityEnabled": @YES,
        @"lockdownCellularBasebandEnabled": @YES,
    });
    PXLockdownSafetyDecision *allowed = PXAllowedDecision(PXLockdownResearchModeProfileBacked);
    NSArray<NSString *> *failures = nil;

    NSCAssert(PXLockdownSoCCellularSchemaValidate(goodIDs, cellularSpecs, &failures),
              @"valid cellular schema rejected: %@", failures);

    id resolvedChip = PXLockdownSoCCellularResolve(@"kLockdownUniqueChipIDKey", @1,
                                                    goodIDs, cellularSpecs, on, allowed, &failures);
    NSCAssert([resolvedChip isEqual:chipID], @"UniqueChipID not projected");
    NSCAssert([resolvedChip isKindOfClass:[NSNumber class]], @"UniqueChipID must preserve original CFType");

    id resolvedIMEI = PXLockdownSoCCellularResolve(@"kLockdownIMEIKey", @"orig",
                                                    goodIDs, cellularSpecs, on, allowed, &failures);
    NSCAssert([resolvedIMEI isEqual:@"490154203237518"], @"IMEI1 not projected");
    NSCAssert([resolvedIMEI isKindOfClass:[NSString class]], @"IMEI must stay String");

    id resolvedIMEI2 = PXLockdownSoCCellularResolve(@"kLockdownSecondaryIMEIKey", @"orig",
                                                     goodIDs, cellularSpecs, on, allowed, &failures);
    NSCAssert([resolvedIMEI2 isEqual:@"356938035643809"], @"IMEI2 not projected");

    id resolvedMEID = PXLockdownSoCCellularResolve(@"kLockdownMobileEquipmentIdentifierKey", @"orig",
                                                    goodIDs, cellularSpecs, on, allowed, &failures);
    NSCAssert([resolvedMEID isEqual:@"A00000BEEF1234"], @"MEID not projected");

    id resolvedBaseband = PXLockdownSoCCellularResolve(@"kLockdownBasebandVersionKey", @"orig",
                                                        goodIDs, cellularSpecs, on, allowed, &failures);
    NSCAssert([resolvedBaseband isEqual:@"2.10.04"], @"BasebandVersion not projected");

    // Positive cross-surface agreement for IMEI/MEID.
    PXIdentitySurfaceEntry *imeiSurface = PXIdentitySurfaceEntryForKey(@"kIMEIKey", PXIdentitySurfaceIORegistry);
    NSCAssert(imeiSurface && [PXIdentitySurfaceResolveValue(imeiSurface, goodIDs) isEqual:resolvedIMEI],
              @"projected IMEI diverges from telephony surface");
    PXIdentitySurfaceEntry *meidSurface = PXIdentitySurfaceEntryForKey(@"MEID", PXIdentitySurfaceIORegistry);
    NSCAssert(meidSurface && [PXIdentitySurfaceResolveValue(meidSurface, goodIDs) isEqual:resolvedMEID],
              @"projected MEID diverges from telephony surface");

    // Out-of-scope Phase-5/6 keys must pass through untouched.
    id serial = PXLockdownSoCCellularResolve(@"kLockdownSerialNumberKey", @"orig-serial",
                                             goodIDs, cellularSpecs, on, allowed, &failures);
    NSCAssert([serial isEqual:@"orig-serial"], @"out-of-scope key must return original");

    // Each option controls its whole group. Per-key switches do not exist.
    PXLockdownSoCCellularOptions groupsOff = PXLockdownSoCCellularOptionsFromSettings(@{});
    NSCAssert([PXLockdownSoCCellularResolve(@"kLockdownUniqueChipIDKey", @1, goodIDs, cellularSpecs,
                                            groupsOff, allowed, &failures) isEqual:@1],
              @"SoC group off must return original");
    NSCAssert([PXLockdownSoCCellularResolve(@"kLockdownIMEIKey", @"orig", goodIDs, cellularSpecs,
                                            groupsOff, allowed, &failures) isEqual:@"orig"],
              @"cellular group off must return original");

    // Observe-only always returns original.
    PXLockdownSafetyDecision *observe = PXAllowedDecision(PXLockdownResearchModeObserveOnly);
    NSCAssert([PXLockdownSoCCellularResolve(@"kLockdownIMEIKey", @"orig", goodIDs, cellularSpecs,
                                            on, observe, &failures) isEqual:@"orig"],
              @"observe-only must return original");

    // Type mismatch must fail closed for UniqueChipID.
    NSCAssert([PXLockdownSoCCellularResolve(@"kLockdownUniqueChipIDKey", @"original-string", goodIDs,
                                            cellularSpecs, on, allowed, &failures) isEqual:@"original-string"],
              @"UniqueChipID type mismatch must return original");

    // Malformed IMEI and baseband fail both resolve and whole-schema validation.
    NSMutableDictionary *badIMEI = [goodIDs mutableCopy];
    badIMEI[@"IMEI"] = @"123456789012345";
    NSCAssert(!PXLockdownSoCCellularSchemaValidate(badIMEI, cellularSpecs, &failures),
              @"malformed IMEI must fail schema validation");
    NSCAssert([PXLockdownSoCCellularResolve(@"kLockdownIMEIKey", @"orig", badIMEI, cellularSpecs,
                                            on, allowed, &failures) isEqual:@"orig"],
              @"malformed IMEI must return original");
    NSMutableDictionary *badBaseband = [goodIDs mutableCopy];
    badBaseband[@"BasebandVersion"] = @"unknown modem";
    NSCAssert(!PXLockdownSoCCellularSchemaValidate(badBaseband, cellularSpecs, &failures),
              @"malformed baseband must fail schema validation");

    // Dual-SIM fixture must provide IMEI2; single-SIM must not leak one.
    NSMutableDictionary *missingIMEI2 = [goodIDs mutableCopy];
    [missingIMEI2 removeObjectForKey:@"IMEI2"];
    NSCAssert(!PXLockdownSoCCellularSchemaValidate(missingIMEI2, cellularSpecs, &failures),
              @"dual-SIM schema missing IMEI2 must fail");
    NSMutableDictionary *singleSIMSpecs = [cellularSpecs mutableCopy];
    singleSIMSpecs[@"AdvertisedSIMCount"] = @1;
    NSCAssert(!PXLockdownSoCCellularSchemaValidate(goodIDs, singleSIMSpecs, &failures),
              @"single-SIM schema exposing IMEI2 must fail");

    // Wi-Fi-only negative tests: a valid iPad SoC/ChipID is accepted only when no
    // cellular identity is present. Any IMEI/baseband exposure is rejected and the
    // cellular provider returns original.
    NSDictionary *wifiSpecs = @{
        @"ProductType": @"iPad13,1",
        @"SoC": @"T8103",
        @"CellularCapable": @NO,
        @"AdvertisedSIMCount": @0,
    };
    NSDictionary *wifiIDs = @{ @"UniqueChipID": @99887766554433 };
    NSCAssert(PXLockdownSoCCellularSchemaValidate(wifiIDs, wifiSpecs, &failures),
              @"valid Wi-Fi-only schema rejected: %@", failures);
    NSCAssert([PXLockdownSoCCellularResolve(@"kLockdownIMEIKey", @"orig", goodIDs, wifiSpecs,
                                            on, allowed, &failures) isEqual:@"orig"],
              @"Wi-Fi-only model must return original for IMEI");
    NSCAssert(!PXLockdownSoCCellularSchemaValidate(goodIDs, wifiSpecs, &failures),
              @"Wi-Fi-only schema exposing cellular data must fail");

    // Model/SoC and baseband-family divergence fail closed.
    NSMutableDictionary *wrongSoC = [cellularSpecs mutableCopy];
    wrongSoC[@"SoC"] = @"T8030";
    NSCAssert(!PXLockdownSoCCellularSchemaValidate(goodIDs, wrongSoC, &failures),
              @"ChipID/SoC mismatch must fail schema validation");
    NSMutableDictionary *wrongFamily = [cellularSpecs mutableCopy];
    wrongFamily[@"BasebandFamily"] = @"Intel-XMM7660";
    NSCAssert(!PXLockdownSoCCellularSchemaValidate(goodIDs, wrongFamily, &failures),
              @"baseband family mismatch must fail schema validation");

    NSLog(@"[LOCK-05/06] Lockdown SoC/cellular provider PASS");
}
