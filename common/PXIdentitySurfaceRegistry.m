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
        entries = @[
            PXEntry(@"ProductType", @[], @"DeviceModel", @"DeviceModel", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"HWModelStr", @[@"HardwareModel", @"HWModel", @"hw-model"], @"DeviceModel", @"HwModel", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"BoardId", @[@"board-id"], @"DeviceModel", @"BoardID", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"ModelNumber", @[], @"DeviceModel", @"ModelNumber", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"ProductVersion", @[], @"IOSVersion", @"IOSVersion", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"ProductBuildVersion", @[@"BuildVersion"], @"IOSVersion", @"IOSBuild", nil, mg, PXIdentityExpectedTypeString),
            PXEntry(@"ReleaseType", @[], @"IOSVersion", nil, @"User", mg, PXIdentityExpectedTypeString),

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
            for (NSUInteger bit = 1; bit <= PXIdentitySurfaceIORegistry; bit <<= 1) {
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
