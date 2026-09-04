#import "PXCoreTelephonyServerIdentity.h"
#import "PXIdentitySurfaceRegistry.h"

NSArray<NSString *> *PXCoreTelephonyServerSurfaceKeys(void) {
    static NSArray<NSString *> *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @[
            @"kCTMobileEquipmentInfoCurrentMobileId",
            @"kCTMobileEquipmentInfoIMEI",
            @"kCTMobileEquipmentInfoIMSI",
            @"kCTMobileEquipmentInfoMEID",
            @"kCTPostponementInfoIMEI",
            @"kCTPostponementInfoMEID",
        ];
    });
    return keys;
}

BOOL PXCoreTelephonyServerApplyIdentityOverlay(
    NSMutableDictionary *information,
    NSDictionary<NSString *, id> *runtimeKeysBySurfaceKey,
    NSDictionary *deviceIDs,
    NSSet<NSString *> *enabledToggles) {
    if (![information isKindOfClass:[NSMutableDictionary class]] ||
        ![runtimeKeysBySurfaceKey isKindOfClass:[NSDictionary class]] ||
        ![deviceIDs isKindOfClass:[NSDictionary class]] ||
        ![enabledToggles isKindOfClass:[NSSet class]]) {
        return NO;
    }

    BOOL changed = NO;
    for (NSString *surfaceKey in PXCoreTelephonyServerSurfaceKeys()) {
        id runtimeKey = runtimeKeysBySurfaceKey[surfaceKey];
        if (!runtimeKey) continue;

        // iFake only rewrites a field when it already exists in the original
        // dictionary. Preserve that shape contract exactly.
        if ([information objectForKey:runtimeKey] == nil) continue;

        PXIdentitySurfaceEntry *entry =
            PXIdentitySurfaceEntryForKey(surfaceKey,
                                         PXIdentitySurfaceCoreTelephonyServer);
        if (!entry || ![enabledToggles containsObject:entry.toggle]) continue;

        NSString *replacement = PXIdentitySurfaceResolveValue(entry, deviceIDs);
        if (![replacement isKindOfClass:[NSString class]] || replacement.length == 0) continue;

        [information setObject:replacement forKey:runtimeKey];
        changed = YES;
    }
    return changed;
}
