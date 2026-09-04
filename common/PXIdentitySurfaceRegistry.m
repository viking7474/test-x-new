#import "PXIdentitySurfaceRegistry.h"

@interface PXIdentitySurfaceEntry ()
@property (nonatomic, copy, readwrite) NSString *canonicalKey;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *aliases;
@property (nonatomic, copy, readwrite) NSString *toggle;
@property (nonatomic, copy, readwrite, nullable) NSString *deviceIDKey;
@property (nonatomic, copy, readwrite, nullable) NSString *constantValue;
@property (nonatomic, readwrite) PXIdentitySurfaceMask surfaces;
@property (nonatomic, readwrite) PXIdentityExpectedType expectedType;
@end
@implementation PXIdentitySurfaceEntry
@end

static PXIdentitySurfaceEntry *PXEntry(NSString *canonicalKey,
                                       NSArray<NSString *> *aliases,
                                       NSString *toggle,
                                       NSString *deviceIDKey,
                                       NSString *constantValue,
                                       PXIdentitySurfaceMask surfaces,
                                       PXIdentityExpectedType expectedType) {
    PXIdentitySurfaceEntry *entry = [PXIdentitySurfaceEntry new];
    entry.canonicalKey = canonicalKey;
    entry.aliases = aliases;
    entry.toggle = toggle;
    entry.deviceIDKey = deviceIDKey;
    entry.constantValue = constantValue;
    entry.surfaces = surfaces;
    entry.expectedType = expectedType;
    return entry;
}

NSArray<PXIdentitySurfaceEntry *> *PXIdentitySurfaceRegistryEntries(void) {
    static NSArray<PXIdentitySurfaceEntry *> *entries;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        PXIdentitySurfaceMask mg = PXIdentitySurfaceMobileGestalt;
        PXIdentitySurfaceMask io = PXIdentitySurfaceIORegistry;
        PXIdentitySurfaceMask mc = PXIdentitySurfaceManagedConfiguration;
        PXIdentitySurfaceMask ct = PXIdentitySurfaceCoreTelephonyServer;
        PXIdentitySurfaceMask wrapper = PXIdentitySurfacePrivateWrapper;
        entries = @[
            PXEntry(@"ProductType", @[], @"DeviceModel", @"DeviceModel", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"HWModelStr", @[@"HardwareModel", @"HWModel", @"hw-model"], @"DeviceModel", @"HwModel", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"BoardId", @[@"board-id"], @"DeviceModel", @"BoardID", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"ModelNumber", @[], @"DeviceModel", @"ModelNumber", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"ProductVersion", @[], @"IOSVersion", @"IOSVersion", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"ProductBuildVersion", @[@"BuildVersion"], @"IOSVersion", @"IOSBuild", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"ReleaseType", @[], @"IOSVersion", nil, @"User", mg, PXIdentityExpectedTypeString),

            // ManagedConfiguration compatibility getters.  Keep API names as
            // surface keys while resolving every value from the canonical profile.
            PXEntry(@"MCCTIMEI", @[], @"IMEI", @"IMEI", nil, mc, PXIdentityExpectedTypeString),
            PXEntry(@"MCIOSerialString", @[], @"SerialNumber", @"SerialNumber", nil, mc, PXIdentityExpectedTypeString),
            PXEntry(@"MCProductVersion", @[], @"IOSVersion", @"IOSVersion", nil, mc, PXIdentityExpectedTypeString),
            PXEntry(@"MCProductBuildVersion", @[], @"IOSVersion", @"IOSBuild", nil, mc, PXIdentityExpectedTypeString),
            PXEntry(@"MCGestaltGetProductName", @[], @"DeviceModel", @"DeviceModel", nil, mc, PXIdentityExpectedTypeString),
            PXEntry(@"MCGestaltGetDeviceUUID", @[], @"UDID", @"UDID", nil, mc, PXIdentityExpectedTypeString),

            PXEntry(@"device-model", @[@"product-name"], @"DeviceModel", @"DeviceModel", nil, io, PXIdentityExpectedTypeData),
            PXEntry(@"hw.machine", @[], @"DeviceModel", @"DeviceModel", nil, io, PXIdentityExpectedTypeString),
            PXEntry(@"model", @[], @"DeviceModel", @"HwModel", nil, io, PXIdentityExpectedTypeData),
            PXEntry(@"hw.model", @[], @"DeviceModel", @"HwModel", nil, io, PXIdentityExpectedTypeString),
            PXEntry(@"platform-name", @[], @"DeviceModel", @"HwModel", nil, io, PXIdentityExpectedTypeData),
            PXEntry(@"board-id", @[], @"DeviceModel", @"BoardID", nil, io, PXIdentityExpectedTypeData),
            PXEntry(@"BoardId", @[], @"DeviceModel", @"BoardID", nil, io, PXIdentityExpectedTypeString),
            PXEntry(@"model-number", @[], @"DeviceModel", @"ModelNumber", nil, io, PXIdentityExpectedTypeData),
            PXEntry(@"compatible", @[], @"DeviceModel", @"DeviceModel", nil, io, PXIdentityExpectedTypeStringOrDataArray),
            PXEntry(@"IOPlatformSerialNumber", @[], @"SerialNumber", @"SerialNumber", nil, io, PXIdentityExpectedTypeString),
            PXEntry(@"serial-number", @[], @"SerialNumber", @"SerialNumber", nil, io, PXIdentityExpectedTypeData),
            // MLB is a separate hardware identity. Never alias it to the device serial.
            PXEntry(@"mlb-serial-number", @[], @"MLBSerialNumber", @"MLBSerialNumber", nil, io, PXIdentityExpectedTypeData),
            PXEntry(@"IOPlatformUUID", @[], @"SystemBootUUID", @"SystemBootUUID", nil, io, PXIdentityExpectedTypeString),
            PXEntry(@"system-id", @[], @"SystemBootUUID", @"SystemBootUUID", nil, io, PXIdentityExpectedTypeData),
            PXEntry(@"kIMEIKey", @[@"InternationalMobileEquipmentIdentity"], @"IMEI", @"IMEI", nil, io, PXIdentityExpectedTypeString),
            PXEntry(@"MobileEquipmentIdentifier", @[@"kMEIDKey", @"MEID"], @"MEID", @"MEID", nil, io, PXIdentityExpectedTypeString),

            // CoreTelephony server dictionary keys observed in iFake's V1/V2
            // wrappers.  These entries model only fields that already exist in
            // the original dictionary; the hook task must not synthesize keys.
            PXEntry(@"kCTMobileEquipmentInfoCurrentMobileId", @[], @"MEID", @"MEID", nil, ct, PXIdentityExpectedTypeString),
            PXEntry(@"kCTMobileEquipmentInfoIMEI", @[], @"IMEI", @"IMEI", nil, ct, PXIdentityExpectedTypeString),
            PXEntry(@"kCTMobileEquipmentInfoIMSI", @[], @"IMSI", @"IMSI", nil, ct, PXIdentityExpectedTypeString),
            PXEntry(@"kCTMobileEquipmentInfoMEID", @[], @"MEID", @"MEID", nil, ct, PXIdentityExpectedTypeString),
            PXEntry(@"kCTPostponementInfoIMEI", @[], @"IMEI", @"IMEI", nil, ct, PXIdentityExpectedTypeString),
            PXEntry(@"kCTPostponementInfoMEID", @[], @"MEID", @"MEID", nil, ct, PXIdentityExpectedTypeString),

            // Generic/private wrapper surface.  Only selectors whose semantics
            // map cleanly to canonical profile identity are modeled here.
            // Vendor anti-fraud classes and secure-element evidence stay out.
            PXEntry(@"sf_productType", @[], @"DeviceModel", @"DeviceModel", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"sf_serialNumber", @[], @"SerialNumber", @"SerialNumber", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"sf_udidString", @[], @"UDID", @"UDID", nil, wrapper, PXIdentityExpectedTypeString),
            // iFake sub_B17D8 byte-replays its config key as exact `ads_tracking`;
            // x-new's canonical equivalent is IDFA, not SystemBootUUID.
            PXEntry(@"sf_uuidString", @[], @"IDFA", @"IDFA", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"applicationDSID", @[], @"IDFA", @"IDFA", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"productType", @[], @"DeviceModel", @"DeviceModel", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"productVersion", @[], @"IOSVersion", @"IOSVersion", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"buildVersion", @[], @"IOSVersion", @"IOSBuild", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"deviceName", @[], @"DeviceName", @"DeviceName", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"deviceModel", @[], @"DeviceModel", @"DeviceModel", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"name", @[], @"DeviceName", @"DeviceName", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"hostName", @[], @"DeviceName", @"DeviceName", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"localHostName", @[], @"DeviceName", @"DeviceName", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"serialNumber", @[], @"SerialNumber", @"SerialNumber", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"udid", @[], @"UDID", @"UDID", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"osVersion", @[], @"IOSVersion", @"IOSVersion", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"IMEI", @[], @"IMEI", @"IMEI", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"MEID", @[], @"MEID", @"MEID", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"ICCID", @[], @"ICCID", @"ICCID", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"IMSI", @[], @"IMSI", @"IMSI", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"MLBSerialNumber", @[], @"MLBSerialNumber", @"MLBSerialNumber", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"internationalMobileEquipmentIdentity", @[], @"IMEI", @"IMEI", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"internationalMobileEquipmentIdentity2", @[], @"IMEI2", @"IMEI2", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"mobileEquipmentIdentifier", @[], @"MEID", @"MEID", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"uniqueDeviceIdentifier", @[], @"UDID", @"UDID", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"deviceUDID", @[], @"UDID", @"UDID", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"deviceSerialNumber", @[], @"SerialNumber", @"SerialNumber", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"_iOSComponentHardwarePlatform", @[], @"HwModel", @"HwModel", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"_iOSComponentBuildVersion", @[], @"IOSVersion", @"IOSBuild", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"_iOSComponentDeviceModel", @[], @"DeviceModel", @"DeviceModel", nil, wrapper, PXIdentityExpectedTypeString),
        ];
    });
    return entries;
}

PXIdentitySurfaceEntry *PXIdentitySurfaceEntryForKey(NSString *key, PXIdentitySurfaceMask surface) {
    if (![key isKindOfClass:[NSString class]] || key.length == 0 || surface == 0) return nil;
    for (PXIdentitySurfaceEntry *entry in PXIdentitySurfaceRegistryEntries()) {
        if ((entry.surfaces & surface) == 0) continue;
        if ([entry.canonicalKey isEqualToString:key] || [entry.aliases containsObject:key]) return entry;
    }
    return nil;
}

NSString *PXIdentitySurfaceResolveValue(PXIdentitySurfaceEntry *entry, NSDictionary *deviceIDs) {
    if (![entry isKindOfClass:[PXIdentitySurfaceEntry class]]) return nil;
    if (entry.constantValue.length) return entry.constantValue;
    id raw = [deviceIDs isKindOfClass:[NSDictionary class]] ? deviceIDs[entry.deviceIDKey] : nil;
    if (![raw isKindOfClass:[NSString class]]) return nil;
    NSString *value = (NSString *)raw;
    return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length ? value : nil;
}

BOOL PXIdentitySurfaceRegistryIsWellFormed(NSArray<NSString *> **outFailures) {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (PXIdentitySurfaceEntry *entry in PXIdentitySurfaceRegistryEntries()) {
        if (!entry.canonicalKey.length || !entry.toggle.length || entry.surfaces == 0) {
            [failures addObject:@"entry has empty canonical key, toggle, or surface"];
            continue;
        }
        if ((entry.deviceIDKey.length == 0) == (entry.constantValue.length == 0)) {
            [failures addObject:[NSString stringWithFormat:@"%@ must have exactly one source", entry.canonicalKey]];
        }
        if (entry.expectedType < PXIdentityExpectedTypeString || entry.expectedType > PXIdentityExpectedTypeStringOrDataArray) {
            [failures addObject:[NSString stringWithFormat:@"%@ has invalid expected type", entry.canonicalKey]];
        }
        NSArray<NSString *> *keys = [@[entry.canonicalKey] arrayByAddingObjectsFromArray:entry.aliases ?: @[]];
        for (NSString *key in keys) {
            if (![key isKindOfClass:[NSString class]] || key.length == 0) {
                [failures addObject:[NSString stringWithFormat:@"%@ has empty alias", entry.canonicalKey]];
                continue;
            }
            for (NSUInteger bit = 1; bit <= PXIdentitySurfacePrivateWrapper; bit <<= 1) {
                if ((entry.surfaces & bit) == 0) continue;
                NSString *token = [NSString stringWithFormat:@"%lu:%@", (unsigned long)bit, key];
                if ([seen containsObject:token]) [failures addObject:[NSString stringWithFormat:@"duplicate surface alias %@", token]];
                [seen addObject:token];
            }
        }
    }
    if (outFailures) *outFailures = failures;
    return failures.count == 0;
}
