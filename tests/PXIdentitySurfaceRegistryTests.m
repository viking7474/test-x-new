#import <Foundation/Foundation.h>
#import "PXIdentitySurfaceRegistry.h"

void PXRunIdentitySurfaceRegistryTests(void) {
    NSArray<NSString *> *failures = nil;
    NSCAssert(PXIdentitySurfaceRegistryIsWellFormed(&failures), @"registry malformed: %@", failures);

    NSDictionary *ids = @{
        @"DeviceModel": @"iPhone15,3",
        @"DeviceModelName": @"iPhone 14 Pro Max",
        @"HwModel": @"D74AP",
        @"BoardID": @"0x2C",
        @"ModelNumber": @"A2894",
        @"IOSVersion": @"17.5.1",
        @"IOSBuild": @"21F90",
        @"SerialNumber": @"DEVICE-SERIAL",
        @"MLBSerialNumber": @"MLB-SERIAL",
        @"UDID": @"a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0",
        @"SystemBootUUID": @"12345678-1234-4234-9234-123456789abc",
        @"IDFA": @"A1B2C3D4-E5F6-4789-ABCD-0123456789EF",
        @"IMEI": @"490154203237518",
        @"IMEI2": @"356938035643809",
        @"MEID": @"A00000BEEF1234",
        @"IMSI": @"310260123456789"
    };
    PXIdentitySurfaceEntry *mgAlias = PXIdentitySurfaceEntryForKey(@"HardwareModel", PXIdentitySurfaceMobileGestalt);
    NSCAssert([mgAlias.canonicalKey isEqualToString:@"HWModelStr"], @"MG alias did not canonicalize");
    NSCAssert([[PXIdentitySurfaceResolveValue(mgAlias, ids) description] isEqualToString:@"D74AP"], @"MG alias resolved wrong source");

    PXIdentitySurfaceEntry *ioData = PXIdentitySurfaceEntryForKey(@"device-model", PXIdentitySurfaceIORegistry);
    NSCAssert(ioData.expectedType == PXIdentityExpectedTypeData, @"device-tree ABI type must be CFData");
    NSCAssert([ioData.toggle isEqualToString:@"DeviceModel"], @"IORegistry alias has wrong toggle");

    PXIdentitySurfaceEntry *buildAlias = PXIdentitySurfaceEntryForKey(@"BuildVersion", PXIdentitySurfaceMobileGestalt);
    NSCAssert([[PXIdentitySurfaceResolveValue(buildAlias, ids) description] isEqualToString:@"21F90"], @"build alias drifted");
    NSCAssert(PXIdentitySurfaceEntryForKey(@"BuildVersion", PXIdentitySurfaceIORegistry) == nil, @"surface isolation failed");

    PXIdentitySurfaceEntry *deviceSerial = PXIdentitySurfaceEntryForKey(@"serial-number", PXIdentitySurfaceIORegistry);
    PXIdentitySurfaceEntry *mlbSerial = PXIdentitySurfaceEntryForKey(@"mlb-serial-number", PXIdentitySurfaceIORegistry);
    NSCAssert([deviceSerial.deviceIDKey isEqualToString:@"SerialNumber"], @"device serial source drifted");
    NSCAssert([mlbSerial.deviceIDKey isEqualToString:@"MLBSerialNumber"], @"MLB must not alias device serial");
    NSCAssert(![PXIdentitySurfaceResolveValue(deviceSerial, ids) isEqual:PXIdentitySurfaceResolveValue(mlbSerial, ids)],
              @"device and MLB serials collapsed to one identity");

    PXIdentitySurfaceEntry *mcSerial = PXIdentitySurfaceEntryForKey(@"MCIOSerialString", PXIdentitySurfaceManagedConfiguration);
    PXIdentitySurfaceEntry *mcProduct = PXIdentitySurfaceEntryForKey(@"MCProductVersion", PXIdentitySurfaceManagedConfiguration);
    PXIdentitySurfaceEntry *mcName = PXIdentitySurfaceEntryForKey(@"MCGestaltGetProductName", PXIdentitySurfaceManagedConfiguration);
    PXIdentitySurfaceEntry *mcUUID = PXIdentitySurfaceEntryForKey(@"MCGestaltGetDeviceUUID", PXIdentitySurfaceManagedConfiguration);
    NSCAssert([[PXIdentitySurfaceResolveValue(mcSerial, ids) description] isEqualToString:ids[@"SerialNumber"]],
              @"ManagedConfiguration serial source drifted");
    NSCAssert([[PXIdentitySurfaceResolveValue(mcProduct, ids) description] isEqualToString:ids[@"IOSVersion"]],
              @"ManagedConfiguration ProductVersion source drifted");
    NSCAssert([[PXIdentitySurfaceResolveValue(mcName, ids) description] isEqualToString:ids[@"DeviceModel"]],
              @"ManagedConfiguration product-name source must match iFake device_product_id/ProductType");
    NSCAssert([[PXIdentitySurfaceResolveValue(mcUUID, ids) description] isEqualToString:ids[@"UDID"]],
              @"ManagedConfiguration device UUID source drifted");

    PXIdentitySurfaceEntry *ctIMEI = PXIdentitySurfaceEntryForKey(@"kCTMobileEquipmentInfoIMEI", PXIdentitySurfaceCoreTelephonyServer);
    PXIdentitySurfaceEntry *ctIMSI = PXIdentitySurfaceEntryForKey(@"kCTMobileEquipmentInfoIMSI", PXIdentitySurfaceCoreTelephonyServer);
    PXIdentitySurfaceEntry *ctMEID = PXIdentitySurfaceEntryForKey(@"kCTMobileEquipmentInfoCurrentMobileId", PXIdentitySurfaceCoreTelephonyServer);
    NSCAssert([[PXIdentitySurfaceResolveValue(ctIMEI, ids) description] isEqualToString:ids[@"IMEI"]], @"CTServer IMEI drifted");
    NSCAssert([[PXIdentitySurfaceResolveValue(ctIMSI, ids) description] isEqualToString:ids[@"IMSI"]], @"CTServer IMSI drifted");
    NSCAssert([[PXIdentitySurfaceResolveValue(ctMEID, ids) description] isEqualToString:ids[@"MEID"]], @"CTServer MEID drifted");

    PXIdentitySurfaceEntry *wrapperIMEI2 = PXIdentitySurfaceEntryForKey(@"internationalMobileEquipmentIdentity2", PXIdentitySurfacePrivateWrapper);
    PXIdentitySurfaceEntry *wrapperIDFA = PXIdentitySurfaceEntryForKey(@"sf_uuidString", PXIdentitySurfacePrivateWrapper);
    PXIdentitySurfaceEntry *wrapperDSID = PXIdentitySurfaceEntryForKey(@"applicationDSID", PXIdentitySurfacePrivateWrapper);
    NSCAssert([[PXIdentitySurfaceResolveValue(wrapperIMEI2, ids) description] isEqualToString:ids[@"IMEI2"]],
              @"private wrapper IMEI2 source drifted");
    NSCAssert([[PXIdentitySurfaceResolveValue(wrapperIDFA, ids) description] isEqualToString:ids[@"IDFA"]],
              @"private wrapper sf_uuidString must follow advertising identity");
    NSCAssert([[PXIdentitySurfaceResolveValue(wrapperDSID, ids) description] isEqualToString:ids[@"IDFA"]],
              @"private wrapper applicationDSID must follow advertising identity");
    NSCAssert(PXIdentitySurfaceEntryForKey(@"secureElementIdentifier", PXIdentitySurfacePrivateWrapper) == nil,
              @"secure-element evidence must not enter generic private-wrapper parity registry");

    PXIdentitySurfaceEntry *release = PXIdentitySurfaceEntryForKey(@"ReleaseType", PXIdentitySurfaceMobileGestalt);
    NSCAssert([[PXIdentitySurfaceResolveValue(release, @{}) description] isEqualToString:@"User"], @"constant source failed");
    NSLog(@"[HOOK-02/03] identity surface registry PASS");
}
