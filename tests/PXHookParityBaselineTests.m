#import <Foundation/Foundation.h>
#import "PXIdentitySurfaceRegistry.h"
#import "PXConsistencyMatrix.h"

static NSDictionary *PXLoadParityFixture(void) {
    NSString *source = [NSString stringWithUTF8String:__FILE__];
    NSString *testsDir = [source stringByDeletingLastPathComponent];
    NSString *path = [testsDir stringByAppendingPathComponent:@"fixtures/ifake_parity_profile.json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSCAssert(data.length > 0, @"missing parity fixture at %@", path);
    NSError *error = nil;
    id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    NSCAssert(error == nil && [root isKindOfClass:[NSDictionary class]],
              @"invalid parity fixture: %@", error);
    return root;
}

static void PXAssertString(NSDictionary *dictionary, NSString *key) {
    id value = dictionary[key];
    NSCAssert([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0,
              @"fixture key %@ must be a nonempty string", key);
}

void PXRunHookParityBaselineTests(void) {
    NSDictionary *fixture = PXLoadParityFixture();
    NSDictionary *deviceIDs = fixture[@"deviceIDs"];
    NSCAssert([fixture[@"profileID"] isEqual:@"ifake-parity-fixture"], @"fixture profile id drifted");
    NSCAssert([fixture[@"generation"] respondsToSelector:@selector(unsignedLongLongValue)] &&
              [fixture[@"generation"] unsignedLongLongValue] > 0,
              @"fixture generation invalid");
    NSCAssert([deviceIDs isKindOfClass:[NSDictionary class]], @"fixture deviceIDs missing");

    for (NSString *key in @[
        @"IOSVersion", @"IOSBuild", @"Darwin", @"KernelVersion",
        @"DeviceModel", @"DeviceModelName", @"HwModel", @"BoardID", @"ModelNumber", @"DeviceName",
        @"SerialNumber", @"MLBSerialNumber", @"UDID", @"SystemBootUUID", @"IDFA",
        @"IMEI", @"IMEI2", @"MEID", @"IMSI", @"ICCID", @"BasebandVersion",
        @"LocaleIdentifier", @"Language", @"TimeZone"
    ]) {
        PXAssertString(deviceIDs, key);
    }

    NSArray<NSString *> *registryFailures = nil;
    NSCAssert(PXIdentitySurfaceRegistryIsWellFormed(&registryFailures),
              @"identity surface registry malformed before parity work: %@", registryFailures);

    NSArray<NSString *> *matrixFailures = nil;
    NSCAssert(PXConsistencyMatrixIsWellFormed(&matrixFailures),
              @"consistency matrix malformed before parity work: %@", matrixFailures);

    NSArray<NSString *> *valueFailures = nil;
    NSCAssert(PXValidateConsistencyMatrix(deviceIDs, &valueFailures),
              @"parity fixture must satisfy current consistency matrix: %@", valueFailures);

    PXIdentitySurfaceEntry *mgProduct =
        PXIdentitySurfaceEntryForKey(@"ProductVersion", PXIdentitySurfaceMobileGestalt);
    NSCAssert(mgProduct &&
              [[PXIdentitySurfaceResolveValue(mgProduct, deviceIDs) description]
               isEqualToString:deviceIDs[@"IOSVersion"]],
              @"MG ProductVersion baseline diverged");

    PXIdentitySurfaceEntry *mgBuild =
        PXIdentitySurfaceEntryForKey(@"BuildVersion", PXIdentitySurfaceMobileGestalt);
    NSCAssert(mgBuild &&
              [[PXIdentitySurfaceResolveValue(mgBuild, deviceIDs) description]
               isEqualToString:deviceIDs[@"IOSBuild"]],
              @"MG BuildVersion baseline diverged");

    PXIdentitySurfaceEntry *ioSerial =
        PXIdentitySurfaceEntryForKey(@"IOPlatformSerialNumber", PXIdentitySurfaceIORegistry);
    NSCAssert(ioSerial &&
              [[PXIdentitySurfaceResolveValue(ioSerial, deviceIDs) description]
               isEqualToString:deviceIDs[@"SerialNumber"]],
              @"IOPlatformSerialNumber baseline diverged");

    PXIdentitySurfaceEntry *ioMLB =
        PXIdentitySurfaceEntryForKey(@"mlb-serial-number", PXIdentitySurfaceIORegistry);
    NSCAssert(ioMLB &&
              [[PXIdentitySurfaceResolveValue(ioMLB, deviceIDs) description]
               isEqualToString:deviceIDs[@"MLBSerialNumber"]],
              @"MLB serial baseline diverged");

    PXIdentitySurfaceEntry *ioIMEI =
        PXIdentitySurfaceEntryForKey(@"InternationalMobileEquipmentIdentity", PXIdentitySurfaceIORegistry);
    NSCAssert(ioIMEI &&
              [[PXIdentitySurfaceResolveValue(ioIMEI, deviceIDs) description]
               isEqualToString:deviceIDs[@"IMEI"]],
              @"IMEI baseline diverged");

    PXIdentitySurfaceEntry *ioMEID =
        PXIdentitySurfaceEntryForKey(@"MEID", PXIdentitySurfaceIORegistry);
    NSCAssert(ioMEID &&
              [[PXIdentitySurfaceResolveValue(ioMEID, deviceIDs) description]
               isEqualToString:deviceIDs[@"MEID"]],
              @"MEID baseline diverged");

    NSLog(@"[P0-00] iFake parity baseline fixture + current registry/matrix PASS");
}
