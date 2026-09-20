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
        @"CPUArchitecture": @"arm64e",
        @"ScreenResolution": @"1290x2796",
        @"DevicePixelRatio": @3,
        @"ScreenDensityPPI": @460,
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
        @"IMSI": @"310260123456789",
        @"ICCID": @"8901260123456789012",
        @"BasebandVersion": @"2.10.04",
        @"UniqueChipID": @81234567890123ULL,
        @"WiFiAddress": @"02:11:22:33:44:55",
        @"BluetoothAddress": @"02:AA:BB:CC:DD:EE",
        @"BatteryLevel": @"0.73"
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

    PXIdentitySurfaceEntry *mgMLB = PXIdentitySurfaceEntryForKey(@"MLBSerialNumber", PXIdentitySurfaceMobileGestalt);
    PXIdentitySurfaceEntry *mgChip = PXIdentitySurfaceEntryForKey(@"ChipID", PXIdentitySurfaceMobileGestalt);
    PXIdentitySurfaceEntry *mgIMEI2 = PXIdentitySurfaceEntryForKey(@"IMEI2", PXIdentitySurfaceMobileGestalt);
    PXIdentitySurfaceEntry *mgIMSI = PXIdentitySurfaceEntryForKey(@"IMSI", PXIdentitySurfaceMobileGestalt);
    PXIdentitySurfaceEntry *mgICCID = PXIdentitySurfaceEntryForKey(@"ICCID", PXIdentitySurfaceMobileGestalt);
    PXIdentitySurfaceEntry *mgBaseband = PXIdentitySurfaceEntryForKey(@"BasebandVersion", PXIdentitySurfaceMobileGestalt);
    PXIdentitySurfaceEntry *mgWiFiData = PXIdentitySurfaceEntryForKey(@"WiFiAddressData", PXIdentitySurfaceMobileGestalt);
    PXIdentitySurfaceEntry *mgWidth = PXIdentitySurfaceEntryForKey(@"main-screen-width", PXIdentitySurfaceMobileGestalt);
    PXIdentitySurfaceEntry *mgHeight = PXIdentitySurfaceEntryForKey(@"main-screen-height", PXIdentitySurfaceMobileGestalt);
    PXIdentitySurfaceEntry *mgScale = PXIdentitySurfaceEntryForKey(@"main-screen-scale", PXIdentitySurfaceMobileGestalt);
    PXIdentitySurfaceEntry *mgPitch = PXIdentitySurfaceEntryForKey(@"main-screen-pitch", PXIdentitySurfaceMobileGestalt);
    PXIdentitySurfaceEntry *mgBattery = PXIdentitySurfaceEntryForKey(@"BatteryCurrentCapacity", PXIdentitySurfaceMobileGestalt);

    NSCAssert([[PXIdentitySurfaceResolveObject(mgMLB, ids) description] isEqualToString:ids[@"MLBSerialNumber"]],
              @"MG MLB serial source drifted");
    id chip = PXIdentitySurfaceResolveObject(mgChip, ids);
    NSCAssert(mgChip.expectedType == PXIdentityExpectedTypeNumber && [chip isKindOfClass:[NSNumber class]] && [chip isEqual:ids[@"UniqueChipID"]],
              @"MG UniqueChipID must be a CFNumber-compatible NSNumber");
    NSMutableDictionary *stringChipIDs = [ids mutableCopy];
    stringChipIDs[@"UniqueChipID"] = @"18446744073709551614";
    NSNumber *stringChip = PXIdentitySurfaceResolveObject(mgChip, stringChipIDs);
    NSCAssert(stringChip.unsignedLongLongValue == 18446744073709551614ULL,
              @"MG decimal UniqueChipID must preserve unsigned integer precision");
    NSCAssert([[PXIdentitySurfaceResolveObject(mgIMEI2, ids) description] isEqualToString:ids[@"IMEI2"]], @"MG IMEI2 drifted");
    NSCAssert([[PXIdentitySurfaceResolveObject(mgIMSI, ids) description] isEqualToString:ids[@"IMSI"]], @"MG IMSI drifted");
    NSCAssert([[PXIdentitySurfaceResolveObject(mgICCID, ids) description] isEqualToString:ids[@"ICCID"]], @"MG ICCID drifted");
    NSCAssert([[PXIdentitySurfaceResolveObject(mgBaseband, ids) description] isEqualToString:ids[@"BasebandVersion"]], @"MG baseband drifted");

    NSDictionary<NSString *, NSString *> *directStringSources = @{
        @"CPUArchitecture": @"CPUArchitecture",
        @"HardwarePlatform": @"HwModel",
        @"UserAssignedDeviceName": @"DeviceName",
        @"marketing-name": @"DeviceModelName",
        @"WifiAddress": @"WiFiAddress",
        @"BluetoothAddress": @"BluetoothAddress",
    };
    for (NSString *gestaltKey in directStringSources) {
        PXIdentitySurfaceEntry *entry = PXIdentitySurfaceEntryForKey(gestaltKey, PXIdentitySurfaceMobileGestalt);
        NSString *sourceKey = directStringSources[gestaltKey];
        NSCAssert(entry.expectedType == PXIdentityExpectedTypeString &&
                  [[PXIdentitySurfaceResolveObject(entry, ids) description] isEqualToString:ids[sourceKey]],
                  @"MG direct string projection drifted for %@", gestaltKey);
    }

    const uint8_t expectedMAC[] = { 0x02, 0x11, 0x22, 0x33, 0x44, 0x55 };
    NSData *wifiData = PXIdentitySurfaceResolveObject(mgWiFiData, ids);
    NSCAssert(mgWiFiData.expectedType == PXIdentityExpectedTypeData &&
              [wifiData isEqualToData:[NSData dataWithBytes:expectedMAC length:sizeof(expectedMAC)]],
              @"MG WifiAddressData must contain six binary MAC bytes");
    NSCAssert([PXIdentitySurfaceResolveObject(mgWidth, ids) isEqual:@1290], @"MG screen width projection drifted");
    NSCAssert([PXIdentitySurfaceResolveObject(mgHeight, ids) isEqual:@2796], @"MG screen height projection drifted");
    NSCAssert([PXIdentitySurfaceResolveObject(mgScale, ids) isEqual:@3], @"MG screen scale projection drifted");
    NSCAssert([PXIdentitySurfaceResolveObject(mgPitch, ids) isEqual:@460], @"MG screen pitch projection drifted");
    NSCAssert([PXIdentitySurfaceResolveObject(mgBattery, ids) isEqual:@73], @"MG battery capacity must be percent CFNumber");

    NSMutableDictionary *badIDs = [ids mutableCopy];
    badIDs[@"WiFiAddress"] = @"not-a-mac";
    badIDs[@"BatteryLevel"] = @"1.5";
    badIDs[@"UniqueChipID"] = @"0";
    badIDs[@"DevicePixelRatio"] = @-1;
    NSCAssert(PXIdentitySurfaceResolveObject(mgWiFiData, badIDs) == nil, @"malformed MAC data must fail open");
    NSCAssert(PXIdentitySurfaceResolveObject(mgBattery, badIDs) == nil, @"out-of-range battery must fail open");
    NSCAssert(PXIdentitySurfaceResolveObject(mgChip, badIDs) == nil, @"invalid chip ID must fail open");
    NSCAssert(PXIdentitySurfaceResolveObject(mgScale, badIDs) == nil, @"non-positive screen scale must fail open");
    badIDs[@"UniqueChipID"] = @"18446744073709551616";
    NSCAssert(PXIdentitySurfaceResolveObject(mgChip, badIDs) == nil, @"overflowing chip ID must fail open");
    NSLog(@"[HOOK-02/03] identity surface registry PASS");
}
