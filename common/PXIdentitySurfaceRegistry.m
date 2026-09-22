#import "PXIdentitySurfaceRegistry.h"
#import "PXRuntimeOSCompatibility.h"
#include <math.h>

@interface PXIdentitySurfaceEntry ()
@property (nonatomic, copy, readwrite) NSString *canonicalKey;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *aliases;
@property (nonatomic, copy, readwrite) NSString *toggle;
@property (nonatomic, copy, readwrite, nullable) NSString *deviceIDKey;
@property (nonatomic, copy, readwrite, nullable) NSString *constantValue;
@property (nonatomic, readwrite) PXIdentitySurfaceMask surfaces;
@property (nonatomic, readwrite) PXIdentityExpectedType expectedType;
@property (nonatomic, readwrite) PXIdentityProjectionKind projectionKind;
@end
@implementation PXIdentitySurfaceEntry
@end

static PXIdentitySurfaceEntry *PXEntryWithProjection(NSString *canonicalKey,
                                                     NSArray<NSString *> *aliases,
                                                     NSString *toggle,
                                                     NSString *deviceIDKey,
                                                     NSString *constantValue,
                                                     PXIdentitySurfaceMask surfaces,
                                                     PXIdentityExpectedType expectedType,
                                                     PXIdentityProjectionKind projectionKind);

static PXIdentitySurfaceEntry *PXEntry(NSString *canonicalKey,
                                       NSArray<NSString *> *aliases,
                                       NSString *toggle,
                                       NSString *deviceIDKey,
                                       NSString *constantValue,
                                       PXIdentitySurfaceMask surfaces,
                                       PXIdentityExpectedType expectedType) {
    return PXEntryWithProjection(canonicalKey, aliases, toggle, deviceIDKey,
                                 constantValue, surfaces, expectedType,
                                 PXIdentityProjectionDirect);
}

static PXIdentitySurfaceEntry *PXEntryWithProjection(NSString *canonicalKey,
                                                     NSArray<NSString *> *aliases,
                                                     NSString *toggle,
                                                     NSString *deviceIDKey,
                                                     NSString *constantValue,
                                                     PXIdentitySurfaceMask surfaces,
                                                     PXIdentityExpectedType expectedType,
                                                     PXIdentityProjectionKind projectionKind) {
    PXIdentitySurfaceEntry *entry = [PXIdentitySurfaceEntry new];
    entry.canonicalKey = canonicalKey;
    entry.aliases = aliases;
    entry.toggle = toggle;
    entry.deviceIDKey = deviceIDKey;
    entry.constantValue = constantValue;
    entry.surfaces = surfaces;
    entry.expectedType = expectedType;
    entry.projectionKind = projectionKind;
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

            // P0-01: typed MobileGestalt parity.  Every entry is backed by an
            // existing canonical profile field and an existing feature toggle.
            // Unknown/missing values fail open in the hook and call the original.
            PXEntry(@"MLBSerialNumber", @[], @"SerialNumber", @"MLBSerialNumber", nil, mg, PXIdentityExpectedTypeString),
            PXEntryWithProjection(@"UniqueChipID", @[@"ChipID"], @"DeviceModel", @"UniqueChipID", nil, mg,
                                  PXIdentityExpectedTypeNumber, PXIdentityProjectionUnsignedInteger),
            PXEntry(@"CPUArchitecture", @[], @"DeviceModel", @"CPUArchitecture", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"HardwarePlatform", @[], @"DeviceModel", @"HwModel", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"UserAssignedDeviceName", @[@"DeviceName", @"ComputerName"], @"DeviceName", @"DeviceName", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"marketing-name", @[@"MarketingName"], @"DeviceModel", @"DeviceModelName", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"InternationalMobileEquipmentIdentity2", @[@"IMEI2"], @"IMEI", @"IMEI2", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"InternationalMobileSubscriberIdentity", @[@"IMSI"], @"IMEI", @"IMSI", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"IntegratedCircuitCardIdentifier", @[@"ICCID"], @"IMEI", @"ICCID", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"BasebandFirmwareVersion", @[@"BasebandVersion"], @"IMEI", @"BasebandVersion", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"WifiAddress", @[@"WiFiAddress"], @"WiFi", @"WiFiAddress", nil, mg, PXIdentityExpectedTypeString),
            PXEntryWithProjection(@"WifiAddressData", @[@"WiFiAddressData"], @"WiFi", @"WiFiAddress", nil, mg,
                                  PXIdentityExpectedTypeData, PXIdentityProjectionMACAddressData),
            PXEntry(@"BluetoothAddress", @[], @"WiFi", @"BluetoothAddress", nil, mg, PXIdentityExpectedTypeString),
            PXEntryWithProjection(@"main-screen-width", @[], @"DeviceModel", @"ScreenResolution", nil, mg,
                                  PXIdentityExpectedTypeNumber, PXIdentityProjectionResolutionWidth),
            PXEntryWithProjection(@"main-screen-height", @[], @"DeviceModel", @"ScreenResolution", nil, mg,
                                  PXIdentityExpectedTypeNumber, PXIdentityProjectionResolutionHeight),
            PXEntryWithProjection(@"main-screen-scale", @[], @"DeviceModel", @"DevicePixelRatio", nil, mg,
                                  PXIdentityExpectedTypeNumber, PXIdentityProjectionPositiveNumber),
            PXEntryWithProjection(@"main-screen-pitch", @[], @"DeviceModel", @"ScreenDensityPPI", nil, mg,
                                  PXIdentityExpectedTypeNumber, PXIdentityProjectionPositiveNumber),
            PXEntryWithProjection(@"BatteryCurrentCapacity", @[], @"Battery", @"BatteryLevel", nil, mg,
                                  PXIdentityExpectedTypeNumber, PXIdentityProjectionFractionToPercent),

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
            PXEntry(@"deviceIdentifierForAdvertising", @[], @"IDFA", @"IDFA", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"deviceIdentifierForVendor", @[], @"IDFV", @"IDFV", nil, wrapper, PXIdentityExpectedTypeString),
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
            PXEntry(@"uniqueDeviceId", @[], @"UDID", @"UDID", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"hardwarePlatform", @[], @"DeviceModel", @"HwModel", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"marketingName", @[], @"DeviceModel", @"DeviceModelName", nil, wrapper, PXIdentityExpectedTypeString),
            PXEntry(@"_iOSComponentHardwarePlatform", @[], @"DeviceModel", @"HwModel", nil, wrapper, PXIdentityExpectedTypeString),
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
    if (![deviceIDs isKindOfClass:[NSDictionary class]]) return nil;

    // ProductVersion/ProductBuildVersion are reporting identity surfaces and always
    // preserve the configured profile, including upward spoofing. Legacy Fix Version
    // is intentionally limited to kern.osproductversion in Tweak.x, so MG/MC/private
    // wrappers remain fake and cannot drift from the selected profile.
    if ([entry.toggle isEqualToString:@"IOSVersion"] &&
        ([entry.deviceIDKey isEqualToString:@"IOSVersion"] || [entry.deviceIDKey isEqualToString:@"IOSBuild"])) {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        return PXReportingIOSValueForDeviceIDKey(entry.deviceIDKey, deviceIDs, bundleID);
    }

    id raw = deviceIDs[entry.deviceIDKey];
    if (![raw isKindOfClass:[NSString class]]) return nil;
    NSString *value = (NSString *)raw;
    return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length ? value : nil;
}

static NSString *PXTrimmedNonemptyString(id raw) {
    if (![raw isKindOfClass:[NSString class]]) return nil;
    NSString *trimmed = [(NSString *)raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return trimmed.length ? trimmed : nil;
}

static NSNumber *PXStrictNumber(id raw) {
    if ([raw isKindOfClass:[NSNumber class]]) {
        CFTypeRef cf = (__bridge CFTypeRef)raw;
        if (CFGetTypeID(cf) == CFBooleanGetTypeID()) return nil;
        double value = [(NSNumber *)raw doubleValue];
        return isfinite(value) ? raw : nil;
    }
    NSString *text = PXTrimmedNonemptyString(raw);
    if (!text || ![text isEqualToString:raw]) return nil;

    NSScanner *scanner = [NSScanner scannerWithString:text];
    scanner.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    if ([text hasPrefix:@"0x"] || [text hasPrefix:@"0X"]) {
        unsigned long long value = 0;
        scanner.scanLocation = 2;
        if (![scanner scanHexLongLong:&value] || !scanner.isAtEnd) return nil;
        return @(value);
    }
    double value = 0;
    if (![scanner scanDouble:&value] || !scanner.isAtEnd || !isfinite(value)) return nil;
    return @(value);
}

static NSNumber *PXStrictUnsignedInteger(id raw) {
    if ([raw isKindOfClass:[NSNumber class]]) {
        CFTypeRef cf = (__bridge CFTypeRef)raw;
        if (CFGetTypeID(cf) == CFBooleanGetTypeID()) return nil;
        double value = [(NSNumber *)raw doubleValue];
        if (!isfinite(value) || value <= 0.0 || floor(value) != value) return nil;
        return raw;
    }

    NSString *text = PXTrimmedNonemptyString(raw);
    if (!text || ![text isEqualToString:raw]) return nil;

    BOOL hexadecimal = [text hasPrefix:@"0x"] || [text hasPrefix:@"0X"];
    NSString *digits = hexadecimal ? [text substringFromIndex:2] : text;
    NSCharacterSet *allowed = hexadecimal
        ? [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"]
        : [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    if (digits.length == 0 || [digits rangeOfCharacterFromSet:allowed.invertedSet].location != NSNotFound) return nil;

    NSUInteger firstSignificant = 0;
    while (firstSignificant < digits.length && [digits characterAtIndex:firstSignificant] == '0') firstSignificant++;
    if (firstSignificant == digits.length) return nil;
    NSString *significant = [digits substringFromIndex:firstSignificant];
    NSString *maximum = hexadecimal ? @"FFFFFFFFFFFFFFFF" : @"18446744073709551615";
    if (significant.length > maximum.length ||
        (significant.length == maximum.length && [significant caseInsensitiveCompare:maximum] == NSOrderedDescending)) {
        return nil;
    }

    NSScanner *scanner = [NSScanner scannerWithString:digits];
    unsigned long long value = 0;
    BOOL scanned = hexadecimal ? [scanner scanHexLongLong:&value] : [scanner scanUnsignedLongLong:&value];
    if (!scanned || !scanner.isAtEnd || value == 0) return nil;
    return @(value);
}

static NSNumber *PXStrictBoolean(id raw) {
    if ([raw isKindOfClass:[NSNumber class]]) return @([(NSNumber *)raw boolValue]);
    NSString *text = [PXTrimmedNonemptyString(raw) lowercaseString];
    if ([text isEqualToString:@"true"] || [text isEqualToString:@"1"]) return @YES;
    if ([text isEqualToString:@"false"] || [text isEqualToString:@"0"]) return @NO;
    return nil;
}

static NSData *PXMACAddressData(id raw) {
    NSString *text = PXTrimmedNonemptyString(raw);
    if (!text) return nil;
    NSArray<NSString *> *parts = [text componentsSeparatedByString:@":"];
    if (parts.count != 6) return nil;
    uint8_t bytes[6] = {0};
    for (NSUInteger index = 0; index < parts.count; index++) {
        NSString *part = parts[index];
        if (part.length != 2) return nil;
        NSScanner *scanner = [NSScanner scannerWithString:part];
        unsigned int value = 0;
        if (![scanner scanHexInt:&value] || !scanner.isAtEnd || value > 0xFF) return nil;
        bytes[index] = (uint8_t)value;
    }
    return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

static NSNumber *PXResolutionComponent(id raw, BOOL height) {
    NSString *text = PXTrimmedNonemptyString(raw);
    if (!text) return nil;
    NSString *normalized = [[text stringByReplacingOccurrencesOfString:@"×" withString:@"x"]
                            stringByReplacingOccurrencesOfString:@"X" withString:@"x"];
    normalized = [[normalized componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
                  componentsJoinedByString:@""];
    NSArray<NSString *> *parts = [normalized componentsSeparatedByString:@"x"];
    if (parts.count != 2) return nil;
    NSNumber *value = PXStrictNumber(parts[height ? 1 : 0]);
    return value.doubleValue > 0 ? value : nil;
}

id PXIdentitySurfaceResolveObject(PXIdentitySurfaceEntry *entry, NSDictionary *deviceIDs) {
    if (![entry isKindOfClass:[PXIdentitySurfaceEntry class]]) return nil;
    if (![deviceIDs isKindOfClass:[NSDictionary class]] && !entry.constantValue.length) return nil;

    id raw = entry.constantValue;
    if (!raw) {
        if ([entry.toggle isEqualToString:@"IOSVersion"] &&
            ([entry.deviceIDKey isEqualToString:@"IOSVersion"] || [entry.deviceIDKey isEqualToString:@"IOSBuild"])) {
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            raw = PXReportingIOSValueForDeviceIDKey(entry.deviceIDKey, deviceIDs, bundleID);
        } else {
            raw = deviceIDs[entry.deviceIDKey];
        }
    }
    if (!raw || raw == NSNull.null) return nil;

    switch (entry.projectionKind) {
        case PXIdentityProjectionPositiveNumber: {
            NSNumber *number = PXStrictNumber(raw);
            return number.doubleValue > 0.0 ? number : nil;
        }
        case PXIdentityProjectionUnsignedInteger:
            return PXStrictUnsignedInteger(raw);
        case PXIdentityProjectionMACAddressData:
            return PXMACAddressData(raw);
        case PXIdentityProjectionResolutionWidth:
            return PXResolutionComponent(raw, NO);
        case PXIdentityProjectionResolutionHeight:
            return PXResolutionComponent(raw, YES);
        case PXIdentityProjectionFractionToPercent: {
            NSNumber *fraction = PXStrictNumber(raw);
            double value = fraction.doubleValue;
            if (!fraction || value < 0.0 || value > 1.0) return nil;
            return @((NSInteger)llround(value * 100.0));
        }
        case PXIdentityProjectionDirect:
            break;
    }

    switch (entry.expectedType) {
        case PXIdentityExpectedTypeString:
            return PXTrimmedNonemptyString(raw);
        case PXIdentityExpectedTypeData:
            if ([raw isKindOfClass:[NSData class]] && [(NSData *)raw length]) return [raw copy];
            return nil;
        case PXIdentityExpectedTypeNumber:
            return PXStrictNumber(raw);
        case PXIdentityExpectedTypeBoolean:
            return PXStrictBoolean(raw);
        case PXIdentityExpectedTypeStringOrData:
            if ([raw isKindOfClass:[NSData class]] && [(NSData *)raw length]) return [raw copy];
            return PXTrimmedNonemptyString(raw);
        case PXIdentityExpectedTypeStringOrDataArray: {
            if (![raw isKindOfClass:[NSArray class]] || [(NSArray *)raw count] == 0) return nil;
            for (id item in (NSArray *)raw) {
                BOOL validString = PXTrimmedNonemptyString(item) != nil;
                BOOL validData = [item isKindOfClass:[NSData class]] && [(NSData *)item length] > 0;
                if (!validString && !validData) return nil;
            }
            return [raw copy];
        }
    }
    return nil;
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
        if (entry.projectionKind > PXIdentityProjectionFractionToPercent) {
            [failures addObject:[NSString stringWithFormat:@"%@ has invalid projection kind", entry.canonicalKey]];
        }
        BOOL dataProjection = entry.projectionKind == PXIdentityProjectionMACAddressData;
        BOOL numberProjection = entry.projectionKind == PXIdentityProjectionPositiveNumber ||
                                entry.projectionKind == PXIdentityProjectionUnsignedInteger ||
                                entry.projectionKind == PXIdentityProjectionResolutionWidth ||
                                entry.projectionKind == PXIdentityProjectionResolutionHeight ||
                                entry.projectionKind == PXIdentityProjectionFractionToPercent;
        if (dataProjection && entry.expectedType != PXIdentityExpectedTypeData) {
            [failures addObject:[NSString stringWithFormat:@"%@ data projection has non-data ABI", entry.canonicalKey]];
        }
        if (numberProjection && entry.expectedType != PXIdentityExpectedTypeNumber) {
            [failures addObject:[NSString stringWithFormat:@"%@ numeric projection has non-number ABI", entry.canonicalKey]];
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
