#import "PXManagedConfigurationIdentity.h"
#import "PXIdentitySurfaceRegistry.h"

id PXManagedConfigurationResolveValue(NSString *symbolName,
                                      id originalValue,
                                      NSDictionary *deviceIDs,
                                      BOOL scopeAllowed,
                                      BOOL toggleEnabled) {
    if (!scopeAllowed || !toggleEnabled ||
        ![symbolName isKindOfClass:[NSString class]] || symbolName.length == 0 ||
        ![deviceIDs isKindOfClass:[NSDictionary class]]) {
        return originalValue;
    }

    PXIdentitySurfaceEntry *entry =
        PXIdentitySurfaceEntryForKey(symbolName, PXIdentitySurfaceManagedConfiguration);
    if (!entry || entry.expectedType != PXIdentityExpectedTypeString) {
        return originalValue;
    }

    NSString *projected = PXIdentitySurfaceResolveValue(entry, deviceIDs);
    if (![projected isKindOfClass:[NSString class]] || projected.length == 0) {
        return originalValue;
    }
    return projected;
}
