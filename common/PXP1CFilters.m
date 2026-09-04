#import "PXP1CFilters.h"
#import <dispatch/dispatch.h>
#include <errno.h>
#include <limits.h>
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

BOOL PXP1CJBNormalizeAbsolutePath(const char *inPath, char *out, size_t outCapacity) {
    if (!inPath || !out || outCapacity < 2 || inPath[0] != '/') return NO;

    size_t w = 0;
    out[w++] = '/';
    out[w] = '\0';
    const char *p = inPath;
    while (*p) {
        while (*p == '/') p++;
        if (!*p) break;
        const char *seg = p;
        while (*p && *p != '/') p++;
        size_t segLen = (size_t)(p - seg);
        if (segLen == 1 && seg[0] == '.') continue;
        if (segLen == 2 && seg[0] == '.' && seg[1] == '.') {
            if (w > 1) {
                if (out[w - 1] == '/') w--;
                while (w > 1 && out[w - 1] != '/') w--;
            }
            out[w] = '\0';
            continue;
        }
        if (w > 1 && out[w - 1] != '/') {
            if (w + 1 >= outCapacity) return NO;
            out[w++] = '/';
        }
        if (w + segLen + 1 > outCapacity) return NO;
        memcpy(out + w, seg, segLen);
        w += segLen;
        out[w] = '\0';
    }
    return YES;
}

BOOL PXP1CJBJoinAbsoluteBaseAndNormalize(const char *basePath,
                                         const char *relativePath,
                                         char *out,
                                         size_t outCapacity) {
    if (!basePath || basePath[0] != '/' || !relativePath || relativePath[0] == '/' ||
        !out || outCapacity < 2) return NO;
    size_t baseLength = strlen(basePath);
    size_t relativeLength = strlen(relativePath);
    BOOL needsSlash = baseLength > 0 && basePath[baseLength - 1] != '/';
    size_t needed = baseLength + (needsSlash ? 1u : 0u) + relativeLength + 1u;
    if (needed > PATH_MAX || needed > outCapacity) return NO;
    char joined[PATH_MAX];
    size_t offset = 0;
    memcpy(joined + offset, basePath, baseLength);
    offset += baseLength;
    if (needsSlash) joined[offset++] = '/';
    memcpy(joined + offset, relativePath, relativeLength);
    offset += relativeLength;
    joined[offset] = '\0';
    return PXP1CJBNormalizeAbsolutePath(joined, out, outCapacity);
}

PXJBFilesystemDisposition PXP1CJBResolvedPathDisposition(PXJBFilesystemOperation operation,
                                                         BOOL hiddenArtifact,
                                                         BOOL deniedWriteProbe) {
    if (operation == kPXJBFilesystemOperationWrite && deniedWriteProbe) {
        return kPXJBFilesystemDenyWrite;
    }
    if (hiddenArtifact) return kPXJBFilesystemHide;
    return kPXJBFilesystemAllow;
}

BOOL PXP1CJBDispositionIsHidden(PXJBFilesystemDisposition disposition) {
    return disposition == kPXJBFilesystemHide;
}

BOOL PXP1CJBDispositionBlocksWrite(PXJBFilesystemDisposition disposition) {
    return disposition == kPXJBFilesystemHide || disposition == kPXJBFilesystemDenyWrite;
}

int PXP1CJBErrnoForDisposition(PXJBFilesystemDisposition disposition) {
    if (disposition == kPXJBFilesystemHide) return ENOENT;
    if (disposition == kPXJBFilesystemDenyWrite) return EACCES;
    return 0;
}

int PXP1CJBErrnoForHiddenRead(PXJBHiddenReadErrnoPolicy policy) {
    switch (policy) {
        case kPXJBHiddenReadErrnoBadFileDescriptor:
            return EBADF;
        case kPXJBHiddenReadErrnoPermissionDenied:
            return EPERM;
        case kPXJBHiddenReadErrnoPathNotFound:
        default:
            return ENOENT;
    }
}

int PXP1CJBCompactNonRootGroups(gid_t *groups, int count) {
    if (!groups || count <= 0) return count < 0 ? count : 0;

    int visibleCount = 0;
    for (int index = 0; index < count; index++) {
        gid_t group = groups[index];
        if (group == 0) continue;
        groups[visibleCount++] = group;
    }
    return visibleCount;
}

BOOL PXP1CJBEndpointPortShouldHide(uint16_t hostOrderPort) {
    return hostOrderPort == 27042u || hostOrderPort == 27043u;
}

BOOL PXP1CJBArgumentContainsInstrumentationMarker(NSString *argument) {
    if (![argument isKindOfClass:[NSString class]] || argument.length == 0) return NO;
    static NSArray<NSString *> *markers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // XOR-recovered from iFake sub_E60D4: jailbreak, dyld, roothide,
        // theos, substrate. Keep this dedicated argv corpus intentionally small.
        markers = @[@"jailbreak", @"dyld", @"roothide", @"theos", @"substrate"];
    });
    for (NSString *marker in markers) {
        if ([argument containsString:marker]) return YES;
    }
    return NO;
}

NSArray *PXP1CJBFilterProcessArguments(NSArray *originalArguments, BOOL filteringEnabled) {
    if (!filteringEnabled || ![originalArguments isKindOfClass:[NSArray class]] ||
        originalArguments.count == 0) {
        return originalArguments;
    }

    NSMutableArray *visible = nil;
    for (NSUInteger index = 0; index < originalArguments.count; index++) {
        id argument = originalArguments[index];
        BOOL hide = [argument isKindOfClass:[NSString class]] &&
                    PXP1CJBArgumentContainsInstrumentationMarker(argument);
        if (!hide) {
            if (visible) [visible addObject:argument];
            continue;
        }
        if (!visible) {
            visible = [NSMutableArray arrayWithCapacity:originalArguments.count - 1];
            if (index > 0) {
                [visible addObjectsFromArray:[originalArguments subarrayWithRange:NSMakeRange(0, index)]];
            }
        }
    }
    return visible ? [visible copy] : originalArguments;
}

BOOL PXP1CJBURLSchemeShouldHide(NSString *scheme) {
    if (![scheme isKindOfClass:[NSString class]] || scheme.length == 0) return NO;
    NSString *lower = scheme.lowercaseString;
    static NSArray<NSString *> *fragments;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Exact 18-entry iFake off_5E4498 URL/app-availability corpus.
        fragments = @[
            @"activator", @"aptbackup", @"checkra1n", @"com.example.package",
            @"cydia", @"dopamine", @"filza", @"ifile", @"installer", @"palera1n",
            @"sileo", @"sileosdk", @"trollinstallerx", @"trollstore", @"unc0ver",
            @"undecimus", @"zbra", @"zebra",
        ];
    });
    for (NSString *fragment in fragments) {
        if ([lower containsString:fragment]) return YES;
    }
    return NO;
}

NSArray *PXP1CJBArrayByReplacingMatchingObjects(NSArray *originalArray,
                                                BOOL filteringEnabled,
                                                BOOL (^shouldReplace)(id object),
                                                id replacementObject) {
    if (!filteringEnabled || ![originalArray isKindOfClass:[NSArray class]] ||
        originalArray.count == 0 || !shouldReplace || !replacementObject) {
        return originalArray;
    }

    NSMutableArray *projected = nil;
    for (NSUInteger index = 0; index < originalArray.count; index++) {
        id object = originalArray[index];
        if (!shouldReplace(object)) continue;
        if (!projected) projected = [originalArray mutableCopy];
        projected[index] = replacementObject;
    }
    return projected ? [projected copy] : originalArray;
}

BOOL PXP1CJBProjectedDebuggerState(BOOL originalValue, BOOL bypassEnabled) {
    return bypassEnabled ? NO : originalValue;
}
