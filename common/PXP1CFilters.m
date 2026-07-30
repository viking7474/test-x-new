#import "PXP1CFilters.h"
#include <string.h>
#include <sys/mount.h>

BOOL PXP1CScopeBundleEnabled(NSDictionary *scopedApps, NSString *bundleID) {
    if (![bundleID isKindOfClass:[NSString class]] || bundleID.length == 0) return NO;
    if (![scopedApps isKindOfClass:[NSDictionary class]]) return NO;
    id entry = scopedApps[bundleID];
    if (![entry isKindOfClass:[NSDictionary class]]) return NO;
    return [((NSDictionary *)entry)[@"enabled"] boolValue];
}

BOOL PXP1CWebKitHostScoped(BOOL deviceSpoofEnabled,
                          NSString *hostBundleID,
                          BOOL hostIsCriticalProcess,
                          BOOL hostEnabledInScope) {
    if (!deviceSpoofEnabled) return NO;
    // Fail closed: an unresolved WebKit host bundle must never be treated as scoped.
    if (![hostBundleID isKindOfClass:[NSString class]] || hostBundleID.length == 0) return NO;
    if (hostIsCriticalProcess) return NO;
    return hostEnabledInScope;
}

BOOL PXP1CSnapshotNeedsRefresh(BOOL hasSnapshot, double now, double expirationTime) {
    if (!hasSnapshot) return YES;
    return now >= expirationTime;
}

uint64_t PXP1CJBRequestedMask(BOOL masterEnabled, uint64_t masterBit, uint64_t featureBits) {
    if (!masterEnabled) return 0;
    return masterBit | featureBits;
}

uint64_t PXP1CJBEffectivePolicyMask(uint64_t requestedMask, uint64_t installedMask) {
    return requestedMask & installedMask;
}

BOOL PXP1CJBFeatureActive(uint64_t effectiveMask, uint64_t masterBit, uint64_t featureBit) {
    uint64_t required = masterBit | featureBit;
    return (effectiveMask & required) == required;
}

BOOL PXP1CJBIsSensitiveMountPath(const char *path) {
    if (!path) return NO;
    if (strcmp(path, "/") == 0) return YES;
    if (strcmp(path, "/var") == 0) return YES;
    if (strcmp(path, "/private") == 0) return YES;
    if (strcmp(path, "/private/var") == 0) return YES;
    return NO;
}

uint32_t PXP1CJBNormalizeStatfsFlags(uint32_t flags) {
#ifdef MNT_RDONLY
    return flags | (uint32_t)MNT_RDONLY;
#else
    return flags | 0x1u;
#endif
}
