#import <Foundation/Foundation.h>
#import "PXConsistencyMatrix.h"
#import "PXIdentitySurfaceRegistry.h"
#import "PXManagedConfigurationIdentity.h"
#import "PXCoreTelephonyServerIdentity.h"
#import "PXPrivateIdentityWrapperProjection.h"

static NSDictionary *PXPhaseACanonicalDeviceIDs(NSString *generationSuffix) {
    BOOL next = generationSuffix.length > 0;
    return @{
        @"IOSVersion": next ? @"18.0" : @"17.5.1",
        @"IOSBuild": next ? @"22A3354" : @"21F90",
        @"Darwin": next ? @"24.0.0" : @"23.5.0",
        @"KernelVersion": next ? @"Darwin Kernel Version 24.0.0" : @"Darwin Kernel Version 23.5.0",
        @"DeviceModel": next ? @"iPhone16,2" : @"iPhone15,3",
        @"HwModel": next ? @"D84AP" : @"D74AP",
        @"BoardID": next ? @"0x0E" : @"0x2C",
        @"ModelNumber": next ? @"MU456" : @"MU123",
        @"DeviceName": next ? @"Research iPhone G2" : @"Research iPhone",
        @"SerialNumber": next ? @"C39NEW123456" : @"F2LLD9ABCD12",
        @"MLBSerialNumber": next ? @"C39NEW1234567890A" : @"C02XY1234567890AB",
        @"UDID": next ? @"00112233445566778899aabbccddeeff00112233" : @"a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0",
        @"SystemBootUUID": next ? @"87654321-4321-4432-A234-ABCDEF123456" : @"12345678-1234-4234-9234-123456789ABC",
        @"IDFA": next ? @"0F1E2D3C-4B5A-4678-9ABC-DEF012345678" : @"A1B2C3D4-E5F6-4789-ABCD-0123456789EF",
        @"IMEI": next ? @"356938035643809" : @"490154203237518",
        @"IMEI2": next ? @"352099001761481" : @"356938035643809",
        @"MEID": next ? @"A00000C0FFEE12" : @"A00000BEEF1234",
        @"IMSI": next ? @"310260987654321" : @"310260123456789",
    };
}

static NSSet<NSString *> *PXPhaseAAllEnabledToggles(void) {
    NSMutableSet<NSString *> *toggles = [NSMutableSet set];
    for (PXConsistencyMatrixEntry *entry in PXConsistencyMatrixEntries()) {
        if (entry.toggle.length) [toggles addObject:entry.toggle];
    }
    return toggles;
}

static PXConsistencyMatrixEntry *PXPhaseAMatrixEntry(NSString *surface, NSString *key) {
    for (PXConsistencyMatrixEntry *entry in PXConsistencyMatrixEntries()) {
        if ([entry.surface isEqualToString:surface] && [entry.key isEqualToString:key]) return entry;
    }
    return nil;
}

static NSString *PXPhaseAExpected(NSString *surface, NSString *key, NSDictionary *deviceIDs) {
    PXConsistencyMatrixEntry *entry = PXPhaseAMatrixEntry(surface, key);
    NSCAssert(entry != nil, @"A-06 matrix row missing for %@/%@", surface, key);
    return PXConsistencyResolveEntryValue(entry, deviceIDs);
}

static void PXPhaseAAssertMatrixScenario(NSDictionary *deviceIDs,
                                         NSSet<NSString *> *enabledToggles,
                                         BOOL scopeAllowed,
                                         NSString *scenario) {
    NSMutableDictionary<NSString *, NSMutableArray<PXConsistencyMatrixEntry *> *> *groups = [NSMutableDictionary dictionary];
    for (PXConsistencyMatrixEntry *entry in PXConsistencyMatrixEntries()) {
        NSMutableArray *bucket = groups[entry.group];
        if (!bucket) {
            bucket = [NSMutableArray array];
            groups[entry.group] = bucket;
        }
        [bucket addObject:entry];
    }

    for (NSString *group in groups) {
        NSArray<PXConsistencyMatrixEntry *> *entries = groups[group];
        NSUInteger enabledCount = 0;
        NSUInteger resolvedCount = 0;
        NSString *expected = nil;
        for (PXConsistencyMatrixEntry *entry in entries) {
            if (!scopeAllowed || ![enabledToggles containsObject:entry.toggle]) continue;
            enabledCount += 1;
            NSString *value = PXConsistencyResolveEntryValue(entry, deviceIDs);
            if (!value) continue;
            resolvedCount += 1;
            if (!expected) expected = value;
            NSCAssert([value isEqualToString:expected],
                      @"A-06 %@ group %@ diverged at %@/%@: %@ vs %@",
                      scenario, group, entry.surface, entry.key, value, expected);
        }
        NSCAssert(resolvedCount == 0 || resolvedCount == enabledCount,
                  @"A-06 %@ group %@ partially projected (%lu/%lu enabled surfaces)",
                  scenario, group, (unsigned long)resolvedCount, (unsigned long)enabledCount);
    }
}

static NSDictionary<NSString *, id> *PXPhaseACTRuntimeKeys(void) {
    NSMutableDictionary<NSString *, id> *keys = [NSMutableDictionary dictionary];
    for (NSString *surfaceKey in PXCoreTelephonyServerSurfaceKeys()) {
        keys[surfaceKey] = surfaceKey;
    }
    return keys;
}

static NSMutableDictionary *PXPhaseACTOriginal(void) {
    NSMutableDictionary *information = [NSMutableDictionary dictionary];
    for (NSString *surfaceKey in PXCoreTelephonyServerSurfaceKeys()) {
        information[surfaceKey] = [@"original:" stringByAppendingString:surfaceKey];
    }
    information[@"unknown"] = @"preserve";
    return information;
}

static void PXPhaseAAssertManagedConfiguration(NSDictionary *deviceIDs) {
    NSArray<NSString *> *symbols = @[
        @"MCCTIMEI",
        @"MCIOSerialString",
        @"MCProductVersion",
        @"MCProductBuildVersion",
        @"MCGestaltGetProductName",
        @"MCGestaltGetDeviceUUID",
    ];
    for (NSString *symbol in symbols) {
        NSString *expected = PXPhaseAExpected(@"ManagedConfiguration", symbol, deviceIDs);
        id actual = PXManagedConfigurationResolveValue(symbol, @"original", deviceIDs, YES, YES);
        NSCAssert([actual isEqual:expected], @"A-06 ManagedConfiguration %@ diverged: %@ != %@", symbol, actual, expected);
    }
}

static void PXPhaseAAssertPrivateWrappers(NSDictionary *deviceIDs) {
    for (NSDictionary<NSString *, id> *rule in PXPrivateIdentityWrapperRuleDescriptors()) {
        if ([rule[@"keyedGetter"] boolValue]) continue;
        NSString *selector = rule[@"selector"];
        NSString *expected = PXPhaseAExpected(@"PrivateWrapper", selector, deviceIDs);
        id actual = PXPrivateIdentityWrapperProjectObject(@"original", selector, deviceIDs);
        NSCAssert([actual isEqual:expected], @"A-06 private wrapper %@ diverged: %@ != %@", selector, actual, expected);
    }

    NSDictionary<NSString *, NSString *> *keyedExpectations = @{
        @"ProductType": deviceIDs[@"DeviceModel"],
        @"ProductBuildVersion": deviceIDs[@"IOSBuild"],
        @"IOPlatformSerialNumber": deviceIDs[@"SerialNumber"],
        @"InternationalMobileEquipmentIdentity": deviceIDs[@"IMEI"],
    };
    for (NSString *key in keyedExpectations) {
        PXIdentitySurfaceEntry *entry = nil;
        id actual = PXPrivateIdentityWrapperProjectKeyedObject(@"original", key, deviceIDs, &entry);
        NSCAssert(entry != nil, @"A-06 keyed private wrapper %@ lost registry ownership", key);
        NSCAssert([actual isEqual:keyedExpectations[key]], @"A-06 keyed private wrapper %@ diverged", key);
    }
}

static void PXPhaseAAssertCTServer(NSDictionary *deviceIDs, NSSet<NSString *> *enabledToggles) {
    NSDictionary<NSString *, id> *keys = PXPhaseACTRuntimeKeys();
    NSMutableDictionary *information = PXPhaseACTOriginal();
    PXCoreTelephonyServerApplyIdentityOverlay(information, keys, deviceIDs, enabledToggles);
    for (NSString *surfaceKey in PXCoreTelephonyServerSurfaceKeys()) {
        PXConsistencyMatrixEntry *entry = PXPhaseAMatrixEntry(@"CoreTelephonyServer", surfaceKey);
        NSCAssert(entry != nil, @"A-06 CTServer matrix row missing for %@", surfaceKey);
        NSString *original = [@"original:" stringByAppendingString:surfaceKey];
        NSString *expected = [enabledToggles containsObject:entry.toggle]
            ? PXConsistencyResolveEntryValue(entry, deviceIDs)
            : original;
        if (!expected) expected = original;
        NSCAssert([information[surfaceKey] isEqual:expected],
                  @"A-06 CTServer %@ diverged: %@ != %@", surfaceKey, information[surfaceKey], expected);
    }
    NSCAssert([information[@"unknown"] isEqual:@"preserve"], @"A-06 CTServer changed unknown field");
}

static void PXPhaseAAssertIndirectSysctlRows(NSDictionary *deviceIDs) {
    NSDictionary<NSString *, NSString *> *peers = @{
        @"kern.osversion": @"sysctlbyname",
        @"kern.osrelease": @"sysctlbyname",
        @"hw.machine": @"sysctlbyname",
        @"hw.model": @"sysctlbyname",
    };
    for (NSString *key in peers) {
        NSString *direct = PXPhaseAExpected(peers[key], key, deviceIDs);
        NSString *indirect = PXPhaseAExpected(@"sysctlnametomib+sysctl", key, deviceIDs);
        NSCAssert([direct isEqualToString:indirect], @"A-06 indirect sysctl route diverged for %@", key);
    }
}

void PXRunPhaseAConsistencyGateTests(void) {
    NSDictionary *ids = PXPhaseACanonicalDeviceIDs(@"");
    NSSet<NSString *> *allOn = PXPhaseAAllEnabledToggles();

    NSArray<NSString *> *failures = nil;
    NSCAssert(PXConsistencyMatrixIsWellFormed(&failures), @"A-06 matrix malformed: %@", failures);
    NSCAssert(PXValidateConsistencyMatrix(ids, &failures), @"A-06 canonical matrix inconsistent: %@", failures);
    PXPhaseAAssertMatrixScenario(ids, allOn, YES, @"canonical");
    PXPhaseAAssertManagedConfiguration(ids);
    PXPhaseAAssertPrivateWrappers(ids);
    PXPhaseAAssertCTServer(ids, [NSSet setWithArray:@[@"IMEI", @"IMSI", @"MEID"]]);
    PXPhaseAAssertIndirectSysctlRows(ids);

    // Whole-group blank: every SerialNumber surface must fail open together.
    NSMutableDictionary *blank = [ids mutableCopy];
    blank[@"SerialNumber"] = @"   ";
    PXPhaseAAssertMatrixScenario(blank, allOn, YES, @"whole-group blank");
    NSCAssert(PXValidateConsistencyMatrix(blank, &failures), @"A-06 blank-group matrix became partial: %@", failures);
    NSCAssert([PXManagedConfigurationResolveValue(@"MCIOSerialString", @"original", blank, YES, YES) isEqual:@"original"],
              @"A-06 blank SerialNumber did not fail open in ManagedConfiguration");
    NSCAssert([PXPrivateIdentityWrapperProjectObject(@"original", @"serialNumber", blank) isEqual:@"original"],
              @"A-06 blank SerialNumber did not fail open in private wrapper");

    // Missing field: all UDID surfaces fail open together.
    NSMutableDictionary *missing = [ids mutableCopy];
    [missing removeObjectForKey:@"UDID"];
    PXPhaseAAssertMatrixScenario(missing, allOn, YES, @"missing UDID");
    NSCAssert(PXValidateConsistencyMatrix(missing, &failures), @"A-06 missing-field matrix became partial: %@", failures);
    NSCAssert([PXManagedConfigurationResolveValue(@"MCGestaltGetDeviceUUID", @"original", missing, YES, YES) isEqual:@"original"],
              @"A-06 missing UDID did not fail open in ManagedConfiguration");
    NSCAssert([PXPrivateIdentityWrapperProjectObject(@"original", @"sf_udidString", missing) isEqual:@"original"],
              @"A-06 missing UDID did not fail open in private wrapper");

    // Malformed field: all IMEI surfaces fail open rather than partially projecting.
    NSMutableDictionary *malformed = [ids mutableCopy];
    malformed[@"IMEI"] = @42;
    PXPhaseAAssertMatrixScenario(malformed, allOn, YES, @"malformed IMEI");
    NSCAssert(PXValidateConsistencyMatrix(malformed, &failures), @"A-06 malformed-field matrix became partial: %@", failures);
    NSCAssert([PXManagedConfigurationResolveValue(@"MCCTIMEI", @"original", malformed, YES, YES) isEqual:@"original"],
              @"A-06 malformed IMEI did not fail open in ManagedConfiguration");
    NSCAssert([PXPrivateIdentityWrapperProjectObject(@"original", @"internationalMobileEquipmentIdentity", malformed) isEqual:@"original"],
              @"A-06 malformed IMEI did not fail open in private wrapper");
    PXPhaseAAssertCTServer(malformed, [NSSet setWithArray:@[@"IMEI", @"IMSI", @"MEID"]]);

    // Toggle-off: every DeviceModel-gated matrix row becomes non-projecting, and
    // ManagedConfiguration preserves original when its canonical toggle is off.
    NSMutableSet<NSString *> *deviceModelOff = [allOn mutableCopy];
    [deviceModelOff removeObject:@"DeviceModel"];
    PXPhaseAAssertMatrixScenario(ids, deviceModelOff, YES, @"DeviceModel toggle off");
    NSCAssert([PXManagedConfigurationResolveValue(@"MCGestaltGetProductName", @"original", ids, YES, NO) isEqual:@"original"],
              @"A-06 ManagedConfiguration ignored toggle-off gate");

    // Scope-off: the integration projection view contains zero enabled surfaces.
    PXPhaseAAssertMatrixScenario(ids, allOn, NO, @"scope off");
    NSCAssert([PXManagedConfigurationResolveValue(@"MCIOSerialString", @"original", ids, NO, YES) isEqual:@"original"],
              @"A-06 ManagedConfiguration ignored scope-off gate");

    // Generation swap: no A-01/A-02/A-05 pure resolver may retain stale values.
    NSDictionary *next = PXPhaseACanonicalDeviceIDs(@"-G2");
    PXPhaseAAssertMatrixScenario(next, allOn, YES, @"generation swap");
    PXPhaseAAssertManagedConfiguration(next);
    PXPhaseAAssertPrivateWrappers(next);
    PXPhaseAAssertCTServer(next, [NSSet setWithArray:@[@"IMEI", @"IMSI", @"MEID"]]);
    NSCAssert(![PXPhaseAExpected(@"ManagedConfiguration", @"MCIOSerialString", ids)
                  isEqualToString:PXPhaseAExpected(@"ManagedConfiguration", @"MCIOSerialString", next)],
              @"A-06 generation fixture did not actually change SerialNumber");
    NSCAssert(![PXPhaseAExpected(@"PrivateWrapper", @"sf_uuidString", ids)
                  isEqualToString:PXPhaseAExpected(@"PrivateWrapper", @"sf_uuidString", next)],
              @"A-06 generation fixture did not actually change IDFA");

    NSLog(@"[A-06] Phase-A consistency gate PASS");
}
