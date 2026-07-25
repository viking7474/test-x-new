#import "ProjectX.h"
#import "DeviceModelManager.h"
#import "IdentifierManager.h"
#import "ProfileManager.h"
#import "ProjectXLogging.h"
#import "HookOwnership.h"
#import "PXNativeHookCoordinator.h"
#import <Foundation/Foundation.h>
#import <sys/sysctl.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Metal/Metal.h>
#import <WebKit/WebKit.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <dlfcn.h>
#import <errno.h>
#import <limits.h>
#import <mach-o/arch.h>
// #import <ellekit/ellekit.h> // Removed for rootful - using Substrate
#import "IOSVersionInfo.h"

#import "PXScope.h"
#import "PXFileDebug.h"

#ifndef CPU_SUBTYPE_ARM64_V8
#define CPU_SUBTYPE_ARM64_V8 ((cpu_subtype_t)1)
#endif
#ifndef CPU_SUBTYPE_ARM64E
#define CPU_SUBTYPE_ARM64E ((cpu_subtype_t)2)
#endif

typedef NS_OPTIONS(uint32_t, PXDeviceCPUFeatureFlags) {
    PXDeviceCPUFeatureARM64       = 1u << 0,
    PXDeviceCPUFeatureARM64E      = 1u << 1,
    PXDeviceCPUFeatureAtomics     = 1u << 2,
    PXDeviceCPUFeatureFCMA        = 1u << 3,
    PXDeviceCPUFeatureCRC32       = 1u << 4,
    PXDeviceCPUFeatureNEON        = 1u << 5,
    PXDeviceCPUFeatureAES         = 1u << 6,
    PXDeviceCPUFeatureFP16        = 1u << 7,
    PXDeviceCPUFeatureJSCVT       = 1u << 8,
    PXDeviceCPUFeatureLRCPC       = 1u << 9,
};

typedef struct {
    const char *token;
    const char *qualifier;
    const char *brand;
    const char *archDescription;
    cpu_subtype_t cpuSubtype;
    uint32_t cpuFamily;
    uint32_t defaultCoreCount;
    uint64_t minFrequencyHz;
    uint64_t maxFrequencyHz;
    uint64_t l1iCacheBytes;
    uint64_t l1dCacheBytes;
    uint64_t l2CacheBytes;
    uint64_t cacheLineBytes;
    PXDeviceCPUFeatureFlags featureFlags;
    const char *featureString;
} PXDeviceCPUProfile;

#define PX_CPU_BASE_FLAGS ((PXDeviceCPUFeatureFlags)(PXDeviceCPUFeatureARM64 | PXDeviceCPUFeatureCRC32 | PXDeviceCPUFeatureNEON | PXDeviceCPUFeatureAES))
#define PX_CPU_ATOMICS_FLAGS ((PXDeviceCPUFeatureFlags)(PX_CPU_BASE_FLAGS | PXDeviceCPUFeatureAtomics))
#define PX_CPU_ARM64E_FLAGS ((PXDeviceCPUFeatureFlags)(PX_CPU_ATOMICS_FLAGS | PXDeviceCPUFeatureARM64E | PXDeviceCPUFeatureFCMA))
#define PX_CPU_ARM64E_FP16_FLAGS ((PXDeviceCPUFeatureFlags)(PX_CPU_ARM64E_FLAGS | PXDeviceCPUFeatureFP16 | PXDeviceCPUFeatureJSCVT))
#define PX_CPU_ARM64E_LRCPC_FLAGS ((PXDeviceCPUFeatureFlags)(PX_CPU_ARM64E_FP16_FLAGS | PXDeviceCPUFeatureLRCPC))

// P1.1 canonical CPU source. All native CPU surfaces resolve through this table.
static const PXDeviceCPUProfile kPXDeviceCPUProfiles[] = {
    { "A18", "PRO", "Apple A18 Pro", "ARM64E", CPU_SUBTYPE_ARM64E, 0x75D4ACB9u, 6u, 1620000000ULL, 4050000000ULL, 131072ULL, 131072ULL, 20971520ULL, 64u, PX_CPU_ARM64E_LRCPC_FLAGS, "NEON AES SHA1 SHA2 CRC32 ATOMICS FCMA FP16 JSCVT LRCPC" },
    { "A18", NULL, "Apple A18", "ARM64E", CPU_SUBTYPE_ARM64E, 0x204526D0u, 6u, 1620000000ULL, 4050000000ULL, 131072ULL, 131072ULL, 20971520ULL, 64u, PX_CPU_ARM64E_LRCPC_FLAGS, "NEON AES SHA1 SHA2 CRC32 ATOMICS FCMA FP16 JSCVT LRCPC" },
    { "A17", NULL, "Apple A17 Pro", "ARM64E", CPU_SUBTYPE_ARM64E, 0x2876F5B5u, 6u, 1512000000ULL, 3780000000ULL, 65536ULL, 65536ULL, 16777216ULL, 64u, PX_CPU_ARM64E_LRCPC_FLAGS, "NEON AES SHA1 SHA2 CRC32 ATOMICS FCMA FP16 JSCVT LRCPC" },
    { "A16", NULL, "Apple A16 Bionic", "ARM64E", CPU_SUBTYPE_ARM64E, 0x8765EDEAu, 6u, 1384000000ULL, 3460000000ULL, 65536ULL, 65536ULL, 16777216ULL, 64u, PX_CPU_ARM64E_FP16_FLAGS, "NEON AES SHA1 SHA2 CRC32 ATOMICS FCMA FP16 JSCVT" },
    { "A15", NULL, "Apple A15 Bionic", "ARM64E", CPU_SUBTYPE_ARM64E, 0xDA33D83Du, 6u, 1292000000ULL, 3230000000ULL, 65536ULL, 65536ULL, 12582912ULL, 64u, PX_CPU_ARM64E_FP16_FLAGS, "NEON AES SHA1 SHA2 CRC32 ATOMICS FCMA FP16 JSCVT" },
    { "A14", NULL, "Apple A14 Bionic", "ARM64E", CPU_SUBTYPE_ARM64E, 0x1B588BB3u, 6u, 1196000000ULL, 2990000000ULL, 65536ULL, 65536ULL, 12582912ULL, 64u, PX_CPU_ARM64E_FLAGS, "NEON AES SHA1 SHA2 CRC32 ATOMICS FCMA" },
    { "A13", NULL, "Apple A13 Bionic", "ARM64E", CPU_SUBTYPE_ARM64E, 0x462504D2u, 6u, 1060000000ULL, 2650000000ULL, 65536ULL, 65536ULL, 8388608ULL, 64u, PX_CPU_ARM64E_FLAGS, "NEON AES SHA1 SHA2 CRC32 ATOMICS FCMA" },
    { "A12X", NULL, "Apple A12X Bionic", "ARM64E", CPU_SUBTYPE_ARM64E, 0x07D34B9Fu, 8u, 996000000ULL, 2490000000ULL, 32768ULL, 32768ULL, 8388608ULL, 64u, PX_CPU_ARM64E_FLAGS, "NEON AES SHA1 SHA2 CRC32 ATOMICS FCMA" },
    { "A12Z", NULL, "Apple A12Z Bionic", "ARM64E", CPU_SUBTYPE_ARM64E, 0x07D34B9Fu, 8u, 996000000ULL, 2490000000ULL, 32768ULL, 32768ULL, 8388608ULL, 64u, PX_CPU_ARM64E_FLAGS, "NEON AES SHA1 SHA2 CRC32 ATOMICS FCMA" },
    { "A12", NULL, "Apple A12 Bionic", "ARM64E", CPU_SUBTYPE_ARM64E, 0x07D34B9Fu, 6u, 996000000ULL, 2490000000ULL, 32768ULL, 32768ULL, 8388608ULL, 64u, PX_CPU_ARM64E_FLAGS, "NEON AES SHA1 SHA2 CRC32 ATOMICS FCMA" },
    { "A11", NULL, "Apple A11 Bionic", "ARM64", CPU_SUBTYPE_ARM64_V8, 0xE81E7EF6u, 6u, 956000000ULL, 2390000000ULL, 32768ULL, 32768ULL, 8388608ULL, 64u, PX_CPU_ATOMICS_FLAGS, "NEON AES SHA1 SHA2 CRC32 ATOMICS" },
    { "A10", NULL, "Apple A10 Fusion", "ARM64", CPU_SUBTYPE_ARM64_V8, 0x67CEEE93u, 4u, 936000000ULL, 2340000000ULL, 32768ULL, 32768ULL, 3145728ULL, 64u, PX_CPU_BASE_FLAGS, "NEON AES SHA1 SHA2 CRC32" },
    { "A9", NULL, "Apple A9", "ARM64", CPU_SUBTYPE_ARM64_V8, 0x92FB37C8u, 2u, 720000000ULL, 1800000000ULL, 32768ULL, 32768ULL, 3145728ULL, 64u, PX_CPU_BASE_FLAGS, "NEON AES SHA1 SHA2 CRC32" },
    { "M2", NULL, "Apple M2", "ARM64E", CPU_SUBTYPE_ARM64E, 0xDA33D83Du, 8u, 1396000000ULL, 3490000000ULL, 131072ULL, 131072ULL, 16777216ULL, 64u, PX_CPU_ARM64E_LRCPC_FLAGS, "NEON AES SHA1 SHA2 CRC32 ATOMICS FCMA FP16 JSCVT LRCPC" },
    { "M1", NULL, "Apple M1", "ARM64E", CPU_SUBTYPE_ARM64E, 0x1B588BB3u, 8u, 1280000000ULL, 3200000000ULL, 131072ULL, 131072ULL, 12582912ULL, 64u, PX_CPU_ARM64E_LRCPC_FLAGS, "NEON AES SHA1 SHA2 CRC32 ATOMICS FCMA FP16 JSCVT LRCPC" },
};

typedef struct {
    const char *name;
    PXDeviceCPUFeatureFlags feature;
} PXDeviceCPUOptionalKey;

// Exact whitelist only. Unknown hw.optional.* keys fall through to the real kernel.
static const PXDeviceCPUOptionalKey kPXDeviceCPUOptionalKeys[] = {
    { "hw.optional.arm64", PXDeviceCPUFeatureARM64 },
    { "hw.optional.neon", PXDeviceCPUFeatureNEON },
    { "hw.optional.neon_fp16", PXDeviceCPUFeatureFP16 },
    { "hw.optional.armv8_crc32", PXDeviceCPUFeatureCRC32 },
    { "hw.optional.armv8_1_atomics", PXDeviceCPUFeatureAtomics },
    { "hw.optional.armv8_3_compnum", PXDeviceCPUFeatureFCMA },
    { "hw.optional.arm.AdvSIMD", PXDeviceCPUFeatureNEON },
    { "hw.optional.arm.FEAT_AES", PXDeviceCPUFeatureAES },
    { "hw.optional.arm.FEAT_CRC32", PXDeviceCPUFeatureCRC32 },
    { "hw.optional.arm.FEAT_LSE", PXDeviceCPUFeatureAtomics },
    { "hw.optional.arm.FEAT_FCMA", PXDeviceCPUFeatureFCMA },
    { "hw.optional.arm.FEAT_FP16", PXDeviceCPUFeatureFP16 },
    { "hw.optional.arm.FEAT_JSCVT", PXDeviceCPUFeatureJSCVT },
    { "hw.optional.arm.FEAT_LRCPC", PXDeviceCPUFeatureLRCPC },
};

#undef PX_CPU_BASE_FLAGS
#undef PX_CPU_ATOMICS_FLAGS
#undef PX_CPU_ARM64E_FLAGS
#undef PX_CPU_ARM64E_FP16_FLAGS
#undef PX_CPU_ARM64E_LRCPC_FLAGS

// Original function pointers. sysctlbyname remains coordinator-owned; DeviceSpec
// only borrows the coordinator's original pointer for existence-gated keys.
static int (*orig_sysctlbyname_device_spec)(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
static kern_return_t (*orig_host_statistics64)(host_t host, host_flavor_t flavor, host_info64_t info, mach_msg_type_number_t *count);
static const NXArchInfo *(*orig_nx_get_local_arch_info)(void);
static __thread NXArchInfo g_deviceSpecThreadArchInfo;

// Path to scoped apps plist
static NSString *const kScopedAppsPath = @"/var/mobile/Library/Preferences/com.hydra.projectx.global_scope.plist";
static NSString *const kScopedAppsPathAlt1 = @"/private/var/mobile/Library/Preferences/com.hydra.projectx.global_scope.plist";
static NSString *const kScopedAppsPathAlt2 = @"/var/mobile/Library/Preferences/com.hydra.projectx.global_scope.plist";

// Scoped apps cache
static NSMutableDictionary *scopedAppsCache = nil;
static NSDate *scopedAppsCacheTimestamp = nil;
static const NSTimeInterval kScopedAppsCacheValidDuration = 60.0; // 1 minute

// Caches for device specs
static NSMutableDictionary *deviceSpecsCache;
static NSDate *cacheTimestamp;
static NSString *cachedDeviceModel;
static NSMutableDictionary *cachedBundleDecisions;

// Cache to track which memory hooks have been called for logging
static NSMutableSet *hookedMemoryAPIs;

// Cache for bundle decisions
static const NSTimeInterval kCacheValidityDuration = 300.0; // 5 minutes

// Helper for logging memory hook invocations only once
static void logMemoryHook(NSString *apiName);

// Function declarations
static NSString *getCurrentBundleID(void);
static BOOL PXCPUArchitectureHasToken(NSString *architecture, NSString *token);
static const PXDeviceCPUProfile *PXCPUProfileForArchitecture(NSString *architecture);
static const PXDeviceCPUProfile *PXCPUProfileFromSpecs(NSDictionary *specs);
static NSUInteger PXCPUCoreCountFromSpecs(NSDictionary *specs);
static NSInteger PXDeviceMemoryGBFromSpecs(NSDictionary *specs);
static BOOL PXDeviceMemoryBytesFromSpecs(NSDictionary *specs, uint64_t *outBytes);
static BOOL PXWriteSysctlBytes(const void *value, size_t valueSize, void *oldp, size_t *oldlenp, int *outResult);
static BOOL PXWriteExistingSysctlBytes(const char *name, const void *value, size_t valueSize, void *oldp, size_t *oldlenp, int *outResult);
static BOOL PXWriteExistingSysctlCString(const char *name, const char *value, void *oldp, size_t *oldlenp, int *outResult);
static BOOL PXCompleteDeviceSpecSysctlResult(const char *name, const PXDeviceCPUProfile *profile, BOOL handled, size_t *oldlenp, int *outResult);
static BOOL PXOptionalFeatureValue(const char *name, const PXDeviceCPUProfile *profile, uint32_t *outValue);
static NSDictionary *loadScopedApps(void);
static BOOL isInScopedAppsList(void);
static BOOL isSpoofingEnabled(void);
static NSString *getSpoofedDeviceModel(void);
static NSDictionary *getDeviceSpecs(void);
static float getFreeMemoryPercentage(void);
static void getConsistentMemoryStats(unsigned long long totalMemory, 
                                    unsigned long long *freeMemory,
                                    unsigned long long *wiredMemory,
                                    unsigned long long *activeMemory,
                                    unsigned long long *inactiveMemory);
static kern_return_t hook_host_statistics64(host_t host, host_flavor_t flavor, host_info64_t info, mach_msg_type_number_t *count);
static BOOL handleDeviceSpecSysctlByname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen, int *outResult);
static const NXArchInfo *hook_nx_get_local_arch_info(void);
static void refreshCaches(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
static CGSize parseResolution(NSString *resolutionString);

#pragma mark - Helper Functions

// Get the current bundle ID
static NSString *getCurrentBundleID(void) {
    @try {
        NSBundle *mainBundle = [NSBundle mainBundle];
        if (!mainBundle) {
            return nil;
        }
        return [mainBundle bundleIdentifier];
    } @catch (NSException *e) {
        return nil;
    }
}

// Match a processor token on an alphanumeric boundary so A18 does not match A180
// and M1 does not match M10. A12X/A12Z are explicit members of the A12 family.
static BOOL PXCPUArchitectureHasToken(NSString *architecture, NSString *token) {
    if (!architecture.length || !token.length) return NO;

    NSString *upperArchitecture = [architecture uppercaseString];
    NSString *upperToken = [token uppercaseString];
    NSCharacterSet *alphanumeric = [NSCharacterSet alphanumericCharacterSet];
    NSRange searchRange = NSMakeRange(0, upperArchitecture.length);

    while (searchRange.length > 0) {
        NSRange match = [upperArchitecture rangeOfString:upperToken options:0 range:searchRange];
        if (match.location == NSNotFound) return NO;

        BOOL beforeIsBoundary = (match.location == 0) ||
            ![alphanumeric characterIsMember:[upperArchitecture characterAtIndex:match.location - 1]];
        NSUInteger end = NSMaxRange(match);
        BOOL afterIsBoundary = (end >= upperArchitecture.length) ||
            ![alphanumeric characterIsMember:[upperArchitecture characterAtIndex:end]];

        // A12X and A12Z share the A12 CPU family but must be accepted explicitly.
        if (!afterIsBoundary && [upperToken isEqualToString:@"A12"] && end < upperArchitecture.length) {
            unichar suffix = [upperArchitecture characterAtIndex:end];
            NSUInteger suffixEnd = end + 1;
            BOOL suffixBoundary = (suffixEnd >= upperArchitecture.length) ||
                ![alphanumeric characterIsMember:[upperArchitecture characterAtIndex:suffixEnd]];
            afterIsBoundary = (suffix == 'X' || suffix == 'Z') && suffixBoundary;
        }

        if (beforeIsBoundary && afterIsBoundary) return YES;

        NSUInteger next = match.location + 1;
        if (next >= upperArchitecture.length) return NO;
        searchRange = NSMakeRange(next, upperArchitecture.length - next);
    }

    return NO;
}

static const PXDeviceCPUProfile *PXCPUProfileForArchitecture(NSString *architecture) {
    if (!architecture.length) return NULL;

    for (NSUInteger i = 0; i < sizeof(kPXDeviceCPUProfiles) / sizeof(kPXDeviceCPUProfiles[0]); i++) {
        const PXDeviceCPUProfile *profile = &kPXDeviceCPUProfiles[i];
        NSString *token = [NSString stringWithUTF8String:profile->token];
        if (!PXCPUArchitectureHasToken(architecture, token)) continue;

        if (profile->qualifier) {
            NSString *qualifier = [NSString stringWithUTF8String:profile->qualifier];
            if (!PXCPUArchitectureHasToken(architecture, qualifier)) {
                continue;
            }
        }
        return profile;
    }
    return NULL;
}

static const PXDeviceCPUProfile *PXCPUProfileFromSpecs(NSDictionary *specs) {
    NSString *architecture = [specs[@"cpuArchitecture"] isKindOfClass:[NSString class]] ? specs[@"cpuArchitecture"] : nil;
    return PXCPUProfileForArchitecture(architecture);
}

static NSUInteger PXCPUCoreCountFromSpecs(NSDictionary *specs) {
    // Fail open as one unit. An unknown architecture must not spoof only the core
    // count while family/subtype/cache/features continue exposing the real device.
    const PXDeviceCPUProfile *profile = PXCPUProfileFromSpecs(specs);
    return profile ? profile->defaultCoreCount : 0;
}

static NSInteger PXDeviceMemoryGBFromSpecs(NSDictionary *specs) {
    NSInteger memoryGB = [specs[@"deviceMemory"] integerValue];
    return (memoryGB > 0 && memoryGB <= 64) ? memoryGB : 0;
}

static BOOL PXDeviceMemoryBytesFromSpecs(NSDictionary *specs, uint64_t *outBytes) {
    if (!outBytes) return NO;
    NSInteger memoryGB = PXDeviceMemoryGBFromSpecs(specs);
    if (memoryGB <= 0) return NO;
    *outBytes = ((uint64_t)memoryGB) * 1024ULL * 1024ULL * 1024ULL;
    return YES;
}

static BOOL PXWriteSysctlBytes(const void *value,
                               size_t valueSize,
                               void *oldp,
                               size_t *oldlenp,
                               int *outResult) {
    if (!value || valueSize == 0 || !oldlenp || !outResult) return NO;

    if (!oldp) {
        *oldlenp = valueSize;
        *outResult = 0;
        return YES;
    }

    size_t capacity = *oldlenp;
    *oldlenp = valueSize;
    if (capacity < valueSize) {
        errno = ENOMEM;
        *outResult = -1;
        return YES;
    }

    memcpy(oldp, value, valueSize);
    *outResult = 0;
    return YES;
}

// Preserve the real kernel's key-existence contract while retaining the caller's
// original buffer capacity. The coordinator skips its own original call when this
// helper returns YES, so the real sysctlbyname is still executed at most once.
static BOOL PXWriteExistingSysctlBytes(const char *name,
                                       const void *value,
                                       size_t valueSize,
                                       void *oldp,
                                       size_t *oldlenp,
                                       int *outResult) {
    if (!name || !value || valueSize == 0 || !oldlenp || !outResult ||
        !orig_sysctlbyname_device_spec) {
        return NO;
    }

    size_t callerCapacity = oldp ? *oldlenp : 0;
    int incomingErrno = errno;
    int originalResult = orig_sysctlbyname_device_spec(name, oldp, oldlenp, NULL, 0);
    int originalErrno = errno;

    // ENOMEM proves the key exists but the caller's buffer was too small.
    // Other failures (for example ENOENT on release kernels) are preserved exactly.
    if (originalResult != 0 && originalErrno != ENOMEM) {
        *outResult = originalResult;
        errno = originalErrno;
        return YES;
    }

    if (oldp) {
        *oldlenp = callerCapacity;
    }

    BOOL handled = PXWriteSysctlBytes(value, valueSize, oldp, oldlenp, outResult);
    if (handled && *outResult == 0) {
        errno = incomingErrno;
    }
    return handled;
}

static BOOL PXWriteExistingSysctlCString(const char *name,
                                         const char *value,
                                         void *oldp,
                                         size_t *oldlenp,
                                         int *outResult) {
    if (!value) return NO;
    return PXWriteExistingSysctlBytes(name,
                                      value,
                                      strlen(value) + 1,
                                      oldp,
                                      oldlenp,
                                      outResult);
}

// Emit bounded runtime evidence only after DeviceSpec has terminally handled a
// request. Preserve errno because opt-in file logging performs its own syscalls.
static BOOL PXCompleteDeviceSpecSysctlResult(const char *name,
                                             const PXDeviceCPUProfile *profile,
                                             BOOL handled,
                                             size_t *oldlenp,
                                             int *outResult) {
    if (!handled) return NO;

    int resultErrno = errno;
    static volatile uint32_t resultLogCount = 0;
    uint32_t logIndex = __sync_fetch_and_add(&resultLogCount, 1u);
    if (logIndex < 80u) {
        PXFileDebugAIDA64Log("[DeviceSpec.sysctlbyname.result] key=%s profile=%s result=%d size=%llu errno=%d",
                             name ?: "<nil>",
                             profile ? profile->token : "<none>",
                             outResult ? *outResult : 0,
                             (unsigned long long)(oldlenp ? *oldlenp : 0),
                             resultErrno);
    }
    errno = resultErrno;
    return YES;
}

static BOOL PXOptionalFeatureValue(const char *name,
                                   const PXDeviceCPUProfile *profile,
                                   uint32_t *outValue) {
    if (!name || !profile || !outValue) return NO;

    for (NSUInteger i = 0; i < sizeof(kPXDeviceCPUOptionalKeys) / sizeof(kPXDeviceCPUOptionalKeys[0]); i++) {
        const PXDeviceCPUOptionalKey *optionalKey = &kPXDeviceCPUOptionalKeys[i];
        if (strcmp(name, optionalKey->name) == 0) {
            *outValue = (profile->featureFlags & optionalKey->feature) ? 1u : 0u;
            return YES;
        }
    }
    return NO;
}

// Load scoped apps from the plist file
static NSDictionary *loadScopedApps(void) {
    @try {
        // Check if cache is valid
        if (scopedAppsCache && scopedAppsCacheTimestamp && 
            [[NSDate date] timeIntervalSinceDate:scopedAppsCacheTimestamp] < kScopedAppsCacheValidDuration) {
            return scopedAppsCache;
        }
        
        // Initialize cache if needed
        if (!scopedAppsCache) {
            scopedAppsCache = [NSMutableDictionary dictionary];
        } else {
            [scopedAppsCache removeAllObjects];
        }
        
        // Try each possible path for the scoped apps file
        NSArray *possiblePaths = @[kScopedAppsPath, kScopedAppsPathAlt1, kScopedAppsPathAlt2];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *validPath = nil;
        
        for (NSString *path in possiblePaths) {
            if ([fileManager fileExistsAtPath:path]) {
                validPath = path;
                break;
            }
        }
        
        if (!validPath) {
            // Don't log this error too frequently to avoid spam
            static NSDate *lastErrorLog = nil;
            if (!lastErrorLog || [[NSDate date] timeIntervalSinceDate:lastErrorLog] > 300.0) { // 5 minutes
                PXLog(@"[DeviceSpec] Could not find scoped apps file");
                lastErrorLog = [NSDate date];
            }
            scopedAppsCacheTimestamp = [NSDate date];
            return scopedAppsCache;
        }
        
        // Load the plist file safely
        NSDictionary *plistDict = [NSDictionary dictionaryWithContentsOfFile:validPath];
        if (!plistDict || ![plistDict isKindOfClass:[NSDictionary class]]) {
            scopedAppsCacheTimestamp = [NSDate date];
            return scopedAppsCache;
        }
        
        // Get the scoped apps dictionary
        NSDictionary *scopedApps = plistDict[@"ScopedApps"];
        if (!scopedApps || ![scopedApps isKindOfClass:[NSDictionary class]]) {
            scopedAppsCacheTimestamp = [NSDate date];
            return scopedAppsCache;
        }
        
        // Copy the scoped apps to our cache
        [scopedAppsCache addEntriesFromDictionary:scopedApps];
        scopedAppsCacheTimestamp = [NSDate date];
        
        return scopedAppsCache;
        
    } @catch (NSException *e) {
        scopedAppsCacheTimestamp = [NSDate date];
        return scopedAppsCache ?: [NSMutableDictionary dictionary];
    }
}

// Check if the current app is in the scoped apps list
static BOOL isInScopedAppsList(void) {
    @try {
        NSString *bundleID = getCurrentBundleID();
        if (!bundleID || [bundleID length] == 0) {
            return NO;
        }
        
        NSDictionary *scopedApps = loadScopedApps();
        if (!scopedApps || scopedApps.count == 0) {
            return NO;
        }
        
        // Check if this bundle ID is in the scoped apps dictionary
        id appEntry = scopedApps[bundleID];
        if (!appEntry || ![appEntry isKindOfClass:[NSDictionary class]]) {
            return NO;
        }
        
        // Check if the app is enabled
        BOOL isEnabled = [appEntry[@"enabled"] boolValue];
        return isEnabled;
        
    } @catch (NSException *e) {
        return NO;
    }
}

// Check if device model spoofing is enabled for the current app with caching
static BOOL isSpoofingEnabled(void) {
    NSString *currentBundleID = getCurrentBundleID();
    if (!currentBundleID) return NO;
    NSString *proc = [NSProcessInfo processInfo].processName;
    if (!PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack)) return NO;
    
    // Check if the current app is a scoped app AND if device model spoofing is enabled
    BOOL shouldSpoof = NO;
    @try {
        BOOL managerCheckPassed = NO;
        if (NSClassFromString(@"IdentifierManager")) {
            IdentifierManager *manager = [NSClassFromString(@"IdentifierManager") sharedManager];
            if (manager && [manager isIdentifierEnabled:@"DeviceModel"]) {
                shouldSpoof = YES;
                managerCheckPassed = YES;
            }
        }

        if (!managerCheckPassed) {
            NSString *profilesPath = @"/var/mobile/Library/WeaponX/Profiles";
            NSString *centralInfoPath = [profilesPath stringByAppendingPathComponent:@"current_profile_info.plist"];
            NSDictionary *centralInfo = [NSDictionary dictionaryWithContentsOfFile:centralInfoPath];
            NSString *profileId = centralInfo[@"ProfileId"];
            if (profileId) {
                NSString *profileSettingsPath = [profilesPath stringByAppendingPathComponent:[profileId stringByAppendingPathComponent:@"settings.plist"]];
                NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:profileSettingsPath];
                if (settings && settings[@"deviceModelEnabled"]) {
                    shouldSpoof = [settings[@"deviceModelEnabled"] boolValue];
                }
            }
        }
    } @catch (NSException *exception) {
        PXLog(@"[DeviceSpec] Exception checking if device model spoofing is enabled: %@", exception);
        shouldSpoof = NO;
    }
    
    return shouldSpoof;
}

// Get the device model from profile
static NSString *getSpoofedDeviceModel() {
    @try {
        // Try multiple methods to get the model value
        NSString *deviceModel = nil;

        // METHOD 0: Prefer IdentifierManager for consistency with other hooks
        if (NSClassFromString(@"IdentifierManager")) {
            IdentifierManager *manager = [NSClassFromString(@"IdentifierManager") sharedManager];
            if (manager) {
                NSString *m = [manager currentValueForIdentifier:@"DeviceModel"];
                if (m.length > 0) {
                    deviceModel = m;
                }
            }
        }
        
        // METHOD 1: Try direct access from profile plist (device_ids.plist)
        if (!deviceModel.length) {
            NSString *profilesPath = @"/var/mobile/Library/WeaponX/Profiles";
            NSString *centralInfoPath = [profilesPath stringByAppendingPathComponent:@"current_profile_info.plist"];
            NSDictionary *centralInfo = [NSDictionary dictionaryWithContentsOfFile:centralInfoPath];

            NSString *profileId = centralInfo[@"ProfileId"];
            if (profileId) {
                // Build path to identity directory
                NSString *identityDir = [[profilesPath stringByAppendingPathComponent:profileId] stringByAppendingPathComponent:@"identity"];

                NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
                NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
                deviceModel = deviceIds[@"DeviceModel"];
            }
        }
        
        // METHOD 2: Use DeviceModelManager as fallback (do not generate here)
        if (!deviceModel.length && NSClassFromString(@"DeviceModelManager")) {
            DeviceModelManager *deviceManager = [NSClassFromString(@"DeviceModelManager") sharedManager];
            deviceModel = [deviceManager currentDeviceModel];
        }
        
        return deviceModel;
    } @catch (NSException *exception) {
        PXLog(@"[DeviceSpec] Exception getting spoofed device model: %@", exception);
        return nil;
    }
}

// Get all device specifications for the current spoofed model
static NSDictionary *getDeviceSpecs() {
    // Initialize cache if needed
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        deviceSpecsCache = [NSMutableDictionary dictionary];
    });
    
    // Check if specs are already cached
    @synchronized(deviceSpecsCache) {
        NSDictionary *cachedSpecs = deviceSpecsCache[@"specs"];
        if (cachedSpecs && [[NSDate date] timeIntervalSinceDate:cacheTimestamp] < kCacheValidityDuration) {
            return cachedSpecs;
        }
    }
    
    @try {
        // METHOD 1: Try to get specs directly from device_ids.plist
        NSString *profilesPath = @"/var/mobile/Library/WeaponX/Profiles";
        NSString *centralInfoPath = [profilesPath stringByAppendingPathComponent:@"current_profile_info.plist"];
        NSDictionary *centralInfo = [NSDictionary dictionaryWithContentsOfFile:centralInfoPath];
        
        NSString *profileId = centralInfo[@"ProfileId"];
        if (profileId) {
            NSString *identityDir = [[profilesPath stringByAppendingPathComponent:profileId] stringByAppendingPathComponent:@"identity"];
            NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
            NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
            
            if (deviceIds && deviceIds[@"DeviceModel"]) {
                // Reconstruct specs from device_ids.plist
                NSMutableDictionary *specs = [NSMutableDictionary dictionary];
                specs[@"value"] = deviceIds[@"DeviceModel"];
                specs[@"name"] = deviceIds[@"DeviceModelName"] ?: @"Unknown";
                specs[@"screenResolution"] = deviceIds[@"ScreenResolution"] ?: @"Unknown";
                specs[@"viewportResolution"] = deviceIds[@"ViewportResolution"] ?: @"Unknown";
                specs[@"devicePixelRatio"] = deviceIds[@"DevicePixelRatio"] ?: @(0);
                specs[@"screenDensity"] = deviceIds[@"ScreenDensityPPI"] ?: @(0);
                specs[@"cpuArchitecture"] = deviceIds[@"CPUArchitecture"] ?: @"Unknown";
                specs[@"deviceMemory"] = deviceIds[@"DeviceMemory"] ?: @(0);
                specs[@"gpuFamily"] = deviceIds[@"GPUFamily"] ?: @"Unknown";
                specs[@"cpuCoreCount"] = deviceIds[@"CPUCoreCount"] ?: @(0);
                specs[@"metalFeatureSet"] = deviceIds[@"MetalFeatureSet"] ?: @"Unknown";
                
                // Add board/hardware identifiers (used by apps like AIDA)
                if (deviceIds[@"BoardID"]) {
                    specs[@"boardID"] = deviceIds[@"BoardID"];
                }
                if (deviceIds[@"HwModel"]) {
                    specs[@"hwModel"] = deviceIds[@"HwModel"];
                } else if (deviceIds[@"BoardID"]) {
                    specs[@"hwModel"] = deviceIds[@"BoardID"]; // Best-effort fallback
                }

                // Reconstruct webGLInfo
                NSMutableDictionary *webGLInfo = [NSMutableDictionary dictionary];
                webGLInfo[@"webglVendor"] = deviceIds[@"WebGLVendor"] ?: @"Apple";
                webGLInfo[@"webglRenderer"] = deviceIds[@"WebGLRenderer"] ?: @"Apple GPU";
                webGLInfo[@"unmaskedVendor"] = @"Apple Inc.";
                webGLInfo[@"unmaskedRenderer"] = deviceIds[@"GPUFamily"] ?: @"Apple GPU";
                webGLInfo[@"webglVersion"] = @"WebGL 2.0";
                webGLInfo[@"maxTextureSize"] = @(16384);
                webGLInfo[@"maxRenderBufferSize"] = @(16384);
                specs[@"webGLInfo"] = webGLInfo;
                
                PXLog(@"[DeviceSpec] Reconstructed device specs from device_ids.plist");
                
                // Cache the specifications
                @synchronized(deviceSpecsCache) {
                    deviceSpecsCache[@"specs"] = specs;
                    cacheTimestamp = [NSDate date];
                }
                
                return specs;
            }
        }
        
        // METHOD 2: Fallback to DeviceModelManager
        // Get the current spoofed device model
        NSString *deviceModel = getSpoofedDeviceModel();
        if (!deviceModel.length) {
            return nil;
        }
        
        // Get the specifications from DeviceModelManager
        DeviceModelManager *deviceManager = [NSClassFromString(@"DeviceModelManager") sharedManager];
        if (!deviceManager) {
            PXLog(@"[DeviceSpec] WARNING: DeviceModelManager not available");
            return nil;
        }
        
        NSDictionary *specs = [deviceManager deviceSpecificationsForModel:deviceModel];
        if (!specs) {
            PXLog(@"[DeviceSpec] WARNING: No specifications found for device model: %@", deviceModel);
            return nil;
        }
        
        // Cache the specifications
        @synchronized(deviceSpecsCache) {
            deviceSpecsCache[@"specs"] = specs;
            cacheTimestamp = [NSDate date];
        }
        
        return specs;
    } @catch (NSException *exception) {
        PXLog(@"[DeviceSpec] Exception getting device specifications: %@", exception);
        return nil;
    }
}

#pragma mark - Document-Start Web Capability Script

// Central WKWebView ownership lives in CanvasFingerprintHooks.x. This exported helper
// contributes device capability spoofing without installing additional WKWebView hooks.
void PXInstallDeviceSpecUserScripts(WKUserContentController *userContentController) {
    if (!userContentController) return;
    for (WKUserScript *existingScript in userContentController.userScripts) {
        if ([existingScript.source containsString:@"__weaponx_device_capabilities__"]) {
            return;
        }
    }
    if (!isSpoofingEnabled()) return;

    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString *processName = [NSProcessInfo processInfo].processName;
    if (!PXFullSpoofTestModeEnabled() &&
        PXProcessIsAllowedForSpoofing(bundleID, processName, PXScopeOptionAllowSafariAuthStack) &&
        PXIsSafariStackProcess(bundleID, processName)) {
        return;
    }

    NSDictionary *specs = getDeviceSpecs();
    NSInteger deviceMemoryGB = PXDeviceMemoryGBFromSpecs(specs);
    NSUInteger cpuCoreCount = PXCPUCoreCountFromSpecs(specs);
    if (deviceMemoryGB <= 0 && cpuCoreCount == 0) return;

    NSString *script = [NSString stringWithFormat:
        @"(function(){\n"
         "  'use strict';\n"
         "  try {\n"
         "    if (globalThis.__weaponx_device_capabilities__) return;\n"
         "    Object.defineProperty(globalThis,'__weaponx_device_capabilities__',{value:true,configurable:false,enumerable:false,writable:false});\n"
         "    var nav=globalThis.navigator; if(!nav) return;\n"
         "    var proto=Object.getPrototypeOf(nav)||nav;\n"
         "    function def(name,value){\n"
         "      if(!(value>0)) return;\n"
         "      try{Object.defineProperty(proto,name,{get:function(){return value;},configurable:true,enumerable:true});return;}catch(e){}\n"
         "      try{Object.defineProperty(nav,name,{get:function(){return value;},configurable:true,enumerable:true});}catch(e){}\n"
         "    }\n"
         "    def('deviceMemory',%ld);\n"
         "    def('hardwareConcurrency',%ld);\n"
         "  } catch(e) {}\n"
         "})();",
        (long)deviceMemoryGB,
        (long)cpuCoreCount];

    WKUserScript *userScript = [[WKUserScript alloc] initWithSource:script
                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                   forMainFrameOnly:NO];
    [userContentController addUserScript:userScript];
}

// Parse resolution string (e.g., "2556x1179") into CGSize
static CGSize parseResolution(NSString *resolutionString) {
    if (!resolutionString) return CGSizeZero;
    
    NSArray *components = [resolutionString componentsSeparatedByString:@"x"];
    if (components.count != 2) return CGSizeZero;
    
    CGFloat width = [components[0] floatValue];
    CGFloat height = [components[1] floatValue];
    
    return CGSizeMake(width, height);
}

#pragma mark - UIScreen Hooks

// Check if current process is a WebKit/WebContent process that needs resolution spoofing
static BOOL shouldSpoofResolutionForCurrentProcess() {
    static BOOL cachedDecision = NO;
    static BOOL hasCheckedProcess = NO;
    
    if (hasCheckedProcess) {
        return cachedDecision;
    }
    
    // IMPORTANT:
    // By default, do NOT spoof UIScreen bounds/scale for Safari/Auth stack processes.
    // In SafariViewService/WebKit services, spoofing UIScreen can desync touch hit-testing
    // and break critical flows (e.g. Google login buttons not clickable).
    // In FullSpoof test mode we override this to intentionally stress web flows.
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
    NSString *procName = [[NSProcessInfo processInfo] processName];
    if (PXProcessIsAllowedForSpoofing(bid, procName, PXScopeOptionAllowSafariAuthStack) && PXIsSafariStackProcess(bid, procName) && !PXFullSpoofTestModeEnabled()) {
        hasCheckedProcess = YES;
        cachedDecision = NO;
        return NO;
    }

    // Only spoof resolution for web views, not for native apps
    NSString *processName = procName;
    BOOL isWebProcess = [processName containsString:@"WebKit"] || 
                        [processName containsString:@"WebContent"] ||
                        [processName containsString:@"Safari"];
                         
    // For Safari and web-focused apps, continue spoofing
    NSString *bundleID = bid;
    BOOL isWebApp = [bundleID hasPrefix:@"com.apple.mobilesafari"] ||
                    [bundleID hasPrefix:@"com.google.chrome"] ||
                    [bundleID hasPrefix:@"org.mozilla.ios.Firefox"] ||
                    [bundleID hasPrefix:@"com.brave.ios"] ||
                    [bundleID hasPrefix:@"com.opera"];
    
    // Cache the decision
    hasCheckedProcess = YES;
    cachedDecision = isWebProcess || isWebApp;
    
    PXLog(@"[DeviceSpec] Resolution spoofing for process '%@' (%@): %@", 
          processName, bundleID, cachedDecision ? @"ENABLED" : @"DISABLED");
          
    return cachedDecision;
}

%hook UIScreen

// Hook for bounds (controls size of the screen in points)
- (CGRect)bounds {
    CGRect originalBounds = %orig;
    
    if (!isSpoofingEnabled() || !PXDisplayUIScaleSpoofEnabled() || !shouldSpoofResolutionForCurrentProcess()) {
        return originalBounds;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalBounds;
    }
    
    // Get the viewport resolution and device pixel ratio from specs
    NSString *viewportResString = specs[@"viewportResolution"];
    NSString *screenResString = specs[@"screenResolution"];
    CGFloat pixelRatio = [specs[@"devicePixelRatio"] floatValue];
    
    if (!viewportResString || pixelRatio <= 0) {
        return originalBounds;
    }
    
    // Parse the viewport resolution
    CGSize viewportSize = parseResolution(viewportResString);
    if (CGSizeEqualToSize(viewportSize, CGSizeZero)) {
        return originalBounds;
    }

    // Some profiles store viewportResolution in points/CSS pixels already.
    // If we divide by DPR again, bounds become unrealistically small.
    BOOL viewportIsPoints = NO;
    CGSize screenSize = parseResolution(screenResString);
    if (!CGSizeEqualToSize(screenSize, CGSizeZero)) {
        CGFloat screenMax = MAX(screenSize.width, screenSize.height);
        CGFloat viewportMax = MAX(viewportSize.width, viewportSize.height);
        if (screenMax > 1500.0 && viewportMax > 0.0 && viewportMax < 1500.0) {
            viewportIsPoints = YES;
        }
    }
    
    // Calculate bounds in points (logical pixels)
    CGFloat width = viewportIsPoints ? viewportSize.width : (viewportSize.width / pixelRatio);
    CGFloat height = viewportIsPoints ? viewportSize.height : (viewportSize.height / pixelRatio);

    // Normalize to portrait-style bounds (UIScreen reports portrait coordinate space).
    CGFloat normW = MIN(width, height);
    CGFloat normH = MAX(width, height);
    
    // Log the change the first time
    static BOOL loggedScreenBounds = NO;
    if (!loggedScreenBounds) {
        PXLog(@"[DeviceSpec] Spoofing UIScreen bounds from %@ to %@",
             NSStringFromCGRect(originalBounds),
             NSStringFromCGRect(CGRectMake(0, 0, normW, normH)));
        loggedScreenBounds = YES;
    }
    
    return CGRectMake(0, 0, normW, normH);
}

// Hook for nativeBounds (actual pixels)
- (CGRect)nativeBounds {
    CGRect originalNativeBounds = %orig;
    
    if (!isSpoofingEnabled() || !PXDisplayPixelMetricsSpoofEnabled() || !shouldSpoofResolutionForCurrentProcess()) {
        return originalNativeBounds;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalNativeBounds;
    }
    
    // Get the screen resolution from specs
    NSString *screenResString = specs[@"screenResolution"];
    if (!screenResString) {
        return originalNativeBounds;
    }
    
    // Parse the screen resolution
    CGSize screenSize = parseResolution(screenResString);
    if (CGSizeEqualToSize(screenSize, CGSizeZero)) {
        return originalNativeBounds;
    }

    // Normalize to portrait-style native bounds.
    CGFloat normW = MIN(screenSize.width, screenSize.height);
    CGFloat normH = MAX(screenSize.width, screenSize.height);
    
    // Log the change the first time
    static BOOL loggedNativeBounds = NO;
    if (!loggedNativeBounds) {
        PXLog(@"[DeviceSpec] Spoofing UIScreen nativeBounds from %@ to %@",
             NSStringFromCGRect(originalNativeBounds),
             NSStringFromCGRect(CGRectMake(0, 0, normW, normH)));
        loggedNativeBounds = YES;
    }
    
    return CGRectMake(0, 0, normW, normH);
}

// Hook for scale (affects UI element sizes)
- (CGFloat)scale {
    CGFloat originalScale = %orig;
    
    if (!isSpoofingEnabled() || !shouldSpoofResolutionForCurrentProcess()) {
        return originalScale;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalScale;
    }
    
    // Get the device pixel ratio from specs
    CGFloat pixelRatio = [specs[@"devicePixelRatio"] floatValue];
    if (pixelRatio <= 0) {
        return originalScale;
    }
    
    // Log the change the first time
    static BOOL loggedScale = NO;
    if (!loggedScale) {
        PXLog(@"[DeviceSpec] Spoofing UIScreen scale from %.2f to %.2f", originalScale, pixelRatio);
        loggedScale = YES;
    }
    
    return pixelRatio;
}

// Hook for current mode (affects refresh rate)
- (UIScreenMode *)currentMode {
    UIScreenMode *originalMode = %orig;
    
    if (!isSpoofingEnabled()) {
        return originalMode;
    }
    
    // We can't create a new UIScreenMode, but we can modify its properties
    // through associated objects if needed in the future
    
    return originalMode;
}

%end

#pragma mark - NSProcessInfo Hooks

%hook NSProcessInfo

// Hook for physical memory (RAM)
- (unsigned long long)physicalMemory {
    unsigned long long originalMemory = %orig;
    
    if (!isSpoofingEnabled()) {
        return originalMemory;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalMemory;
    }
    
    uint64_t spoofedMemory = 0;
    if (!PXDeviceMemoryBytesFromSpecs(specs, &spoofedMemory)) {
        return originalMemory;
    }
    NSInteger deviceMemoryGB = PXDeviceMemoryGBFromSpecs(specs);
    
    // Log the change the first time
    static BOOL loggedMemory = NO;
    if (!loggedMemory) {
        PXLog(@"[DeviceSpec] Spoofing device memory from %llu bytes to %llu bytes (%ld GB)",
             originalMemory, spoofedMemory, (long)deviceMemoryGB);
        loggedMemory = YES;
    }
    
    return spoofedMemory;
}

// Add hook for macOS compatibility - similar to iOS physicalMemory
- (unsigned long long)physicalMemorySize {
    logMemoryHook(@"physicalMemorySize");
    return [self physicalMemory]; // Reuse the physicalMemory hook
}

// Add hook for total memory (used on some iOS versions)
- (unsigned long long)totalPhysicalMemory {
    logMemoryHook(@"totalPhysicalMemory");
    return [self physicalMemory]; // Reuse the physicalMemory hook
}

// Hook for available memory
- (unsigned long long)availableMemory {
    unsigned long long originalAvailableMemory = %orig;
    
    if (!isSpoofingEnabled()) {
        return originalAvailableMemory;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalAvailableMemory;
    }
    
    uint64_t totalMemory = 0;
    if (!PXDeviceMemoryBytesFromSpecs(specs, &totalMemory)) {
        return originalAvailableMemory;
    }

    unsigned long long spoofedAvailableMemory = 0;
    getConsistentMemoryStats(totalMemory, &spoofedAvailableMemory, NULL, NULL, NULL);
    float freePercentage = totalMemory > 0 ? (float)((double)spoofedAvailableMemory / (double)totalMemory) : 0.0f;
    NSInteger deviceMemoryGB = PXDeviceMemoryGBFromSpecs(specs);
    
    // Log the change the first time
    static BOOL loggedAvailableMemory = NO;
    if (!loggedAvailableMemory) {
        PXLog(@"[DeviceSpec] Spoofing available memory from %llu bytes to %llu bytes (%.1f%% of %ld GB)",
             originalAvailableMemory, spoofedAvailableMemory, freePercentage * 100, (long)deviceMemoryGB);
        loggedAvailableMemory = YES;
    }
    
    return spoofedAvailableMemory;
}

// Hook for processor count
- (NSUInteger)processorCount {
    NSUInteger originalCount = %orig;
    
    if (!isSpoofingEnabled()) {
        return originalCount;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalCount;
    }
    
    NSUInteger cpuCoreCount = PXCPUCoreCountFromSpecs(specs);
    if (cpuCoreCount == 0) {
        return originalCount;
    }
    
    // Log the change the first time
    static BOOL loggedProcessorCount = NO;
    if (!loggedProcessorCount) {
        PXLog(@"[DeviceSpec] Spoofing processor count from %lu to %lu",
             (unsigned long)originalCount, (unsigned long)cpuCoreCount);
        loggedProcessorCount = YES;
    }
    
    return cpuCoreCount;
}

// Add hook for CPU architecture information
- (NSString *)machineHardwareName {
    NSString *originalName = %orig;
    
    if (!isSpoofingEnabled()) {
        return originalName;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalName;
    }
    
    const PXDeviceCPUProfile *profile = PXCPUProfileFromSpecs(specs);
    if (!profile || !profile->brand) {
        return originalName;
    }
    NSString *cpuArchitecture = [NSString stringWithUTF8String:profile->brand];
    
    // Log the change the first time
    static BOOL loggedMachineHardwareName = NO;
    if (!loggedMachineHardwareName) {
        PXLog(@"[DeviceSpec] Spoofing machine hardware name from '%@' to '%@'",
             originalName, cpuArchitecture);
        loggedMachineHardwareName = YES;
    }
    
    return cpuArchitecture;
}

%end

#pragma mark - WebGL Info Hooks

%hook WebGLRenderingContext

// WebKit returns `id` (string/number/array/etc). Returning the wrong type can break JS.
- (id)getParameter:(unsigned)pname {
    id original = %orig;
    
    if (!isSpoofingEnabled()) {
        return original;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return original;
    }
    
    NSDictionary *webGLInfo = specs[@"webGLInfo"];
    if (!webGLInfo) {
        return original;
    }
    
    // Map WebGL parameter constants to our stored values
    // VENDOR = 0x1F00, RENDERER = 0x1F01, VERSION = 0x1F02
    id spoofedValue = nil;
    
    if (pname == 0x1F00) { // VENDOR
        spoofedValue = webGLInfo[@"webglVendor"];
    } else if (pname == 0x1F01) { // RENDERER
        spoofedValue = webGLInfo[@"webglRenderer"];
    } else if (pname == 0x1F02) { // VERSION
        spoofedValue = webGLInfo[@"webglVersion"];
    } else if (pname == 0x8B4F || pname == 0x8B4E) { // UNMASKED_VENDOR_WEBGL or UNMASKED_RENDERER_WEBGL
        spoofedValue = (pname == 0x8B4F) ? webGLInfo[@"unmaskedVendor"] : webGLInfo[@"unmaskedRenderer"];
    } else if (pname == 0x0D33) { // MAX_TEXTURE_SIZE
        id v = webGLInfo[@"maxTextureSize"];
        if ([v isKindOfClass:[NSNumber class]]) return v;
        if ([v respondsToSelector:@selector(integerValue)]) return @([v integerValue]);
        return original;
    } else if (pname == 0x8D57) { // MAX_RENDERBUFFER_SIZE
        id v = webGLInfo[@"maxRenderBufferSize"];
        if ([v isKindOfClass:[NSNumber class]]) return v;
        if ([v respondsToSelector:@selector(integerValue)]) return @([v integerValue]);
        return original;
    }
    
    if (spoofedValue) {
        static NSMutableSet *loggedParameters = nil;
        if (!loggedParameters) {
            loggedParameters = [NSMutableSet set];
        }
        
        NSString *paramKey = [NSString stringWithFormat:@"%u", pname];
        if (![loggedParameters containsObject:paramKey]) {
            [loggedParameters addObject:paramKey];
            PXLog(@"[DeviceSpec] Spoofing WebGL parameter 0x%X from '%@' to '%@'", pname, original, spoofedValue);
        }
        
        return spoofedValue;
    }
    
    return original;
}

%end

#pragma mark - Metal API Hooks

%hook MTLDevice

// Hook for name property
- (NSString *)name {
    NSString *originalName = %orig;
    
    if (!isSpoofingEnabled()) {
        return originalName;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalName;
    }
    
    NSString *gpuFamily = specs[@"gpuFamily"];
    if (!gpuFamily) {
        return originalName;
    }
    
    // Log the change the first time
    static BOOL loggedGPUName = NO;
    if (!loggedGPUName) {
        PXLog(@"[DeviceSpec] Spoofing GPU name from '%@' to '%@'", originalName, gpuFamily);
        loggedGPUName = YES;
    }
    
    return gpuFamily;
}

// Also hook the family name property
- (NSString *)familyName {
    NSString *originalFamilyName = %orig;
    
    if (!isSpoofingEnabled()) {
        return originalFamilyName;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalFamilyName;
    }
    
    NSString *gpuFamily = specs[@"gpuFamily"];
    if (!gpuFamily) {
        return originalFamilyName;
    }
    
    // Log the change the first time
    static BOOL loggedGPUFamilyName = NO;
    if (!loggedGPUFamilyName) {
        PXLog(@"[DeviceSpec] Spoofing GPU family name from '%@' to '%@'", originalFamilyName, gpuFamily);
        loggedGPUFamilyName = YES;
    }
    
    return gpuFamily;
}

%end

#pragma mark - Screen Density (DPI) Hooks

%hook UIScreen

// Keep nativeScale aligned with scale when UI scale spoofing is enabled.
- (CGFloat)nativeScale {
    CGFloat original = %orig;

    if (!isSpoofingEnabled() || !PXDisplayUIScaleSpoofEnabled() || !shouldSpoofResolutionForCurrentProcess()) {
        return original;
    }

    NSDictionary *specs = getDeviceSpecs();
    if (!specs) return original;

    CGFloat pixelRatio = [specs[@"devicePixelRatio"] floatValue];
    if (pixelRatio <= 0) return original;

    return pixelRatio;
}

// For screen density
- (CGFloat)native_scale {
    CGFloat originalScale = %orig;
    
    // Avoid spoofing screen density in Safari/Auth stack; it can desync page layout/touch logic.
    if (!isSpoofingEnabled() || !PXDisplayUIScaleSpoofEnabled() || !shouldSpoofResolutionForCurrentProcess()) {
        return originalScale;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalScale;
    }
    
    // Calculate from screen density (PPI)
    NSInteger screenDensity = [specs[@"screenDensity"] integerValue];
    if (screenDensity <= 0) {
        return originalScale;
    }
    
    // iPhone reference point is 163 PPI for scale 1.0
    CGFloat spoofedScale = screenDensity / 163.0;
    
    // Log the change the first time
    static BOOL loggedNativeScale = NO;
    if (!loggedNativeScale) {
        PXLog(@"[DeviceSpec] Spoofing native scale from %.2f to %.2f (density: %ld PPI)",
             originalScale, spoofedScale, (long)screenDensity);
        loggedNativeScale = YES;
    }
    
    return spoofedScale;
}

%end

#pragma mark - Notification Handlers

// Handler for notification to refresh caches
static void refreshCaches(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSString *notificationName = (__bridge NSString *)name;
    PXLog(@"[DeviceSpec] Received notification: %@, refreshing caches", notificationName);
    
    @synchronized(deviceSpecsCache) {
        [deviceSpecsCache removeAllObjects];
        cachedDeviceModel = nil;
        cacheTimestamp = nil;
    }
    
    @synchronized(cachedBundleDecisions) {
        [cachedBundleDecisions removeAllObjects];
    }
}

#pragma mark - CPU Core Spoofing Enhancements

// JavaScript hardwareConcurrency is installed through the shared document-start
// WKUserScript path. Keep only lower-level native CPU detection hooks here.

// Hook lower-level CPU detection APIs for native apps
%hook host_basic_info

- (unsigned int)max_cpus {
    unsigned int original = %orig;
    
    if (!isSpoofingEnabled()) {
        return original;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return original;
    }
    
    NSUInteger cpuCoreCount = PXCPUCoreCountFromSpecs(specs);
    if (cpuCoreCount == 0 || cpuCoreCount > UINT_MAX) {
        return original;
    }
    
    static BOOL loggedCoreAPI = NO;
    if (!loggedCoreAPI) {
        PXLog(@"[DeviceSpec] Spoofing low-level CPU API from %u to %lu", original, (unsigned long)cpuCoreCount);
        loggedCoreAPI = YES;
    }
    
    return (unsigned int)cpuCoreCount;
}

%end

#pragma mark - Constructor

%ctor {
    @autoreleasepool {
        @try {
            PXFileDebugAIDA64Log("[DeviceSpec.ctor] enter");
            PXLog(@"[DeviceSpec] Initializing device specifications spoofing hooks");
            
            NSString *currentBundleID = getCurrentBundleID();
            
            // Skip if we can't get bundle ID
            if (!currentBundleID || [currentBundleID length] == 0) {
                return;
            }
            
            // Don't hook our own apps
            if ([currentBundleID isEqualToString:@"com.hydra.projectx"] ||
                [currentBundleID isEqualToString:@"com.hydra.weaponx"]) {
                return;
            }

            NSString *proc = [NSProcessInfo processInfo].processName;
            if (PXIsWebKitHelperProcess(currentBundleID, proc)) {
                PXFileDebugAIDA64Log("[DeviceSpec.ctor] skip WebKit helper bundle=%s", currentBundleID.UTF8String ?: "<nil>");
                return;
            }
            BOOL allowed = PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack);
            PXFileDebugAIDA64Log("[DeviceSpec.ctor] scope allowed=%d bundle=%s", allowed, currentBundleID.UTF8String ?: "<nil>");
            if (!allowed) {
                PXLog(@"[DeviceSpec] App %@ is not scoped, skipping hook installation", currentBundleID);
                return;
            }
            
            // Always initialize caches
            deviceSpecsCache = [NSMutableDictionary dictionary];
            cachedBundleDecisions = [NSMutableDictionary dictionary];
            
            // Register for notifications to refresh caches
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                refreshCaches,
                CFSTR("com.hydra.projectx.profileChanged"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
            
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                refreshCaches,
                CFSTR("com.hydra.projectx.settings.changed"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
            
            PXLog(@"[DeviceSpec] App %@ is scoped, installing device specification hooks", currentBundleID);

            // DeviceSpec is a selective coordinator pre-provider. It claims only CPU,
            // cache, feature and memory keys; identity and OS keys remain owned by Tweak.
            PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
            [coord installOwnedSymbolsIfNeeded];
            orig_sysctlbyname_device_spec = [coord originalForSymbol:kPXNativeSymbolSysctlByname];
            static dispatch_once_t deviceSpecSysctlProviderOnce;
            dispatch_once(&deviceSpecSysctlProviderOnce, ^{
                BOOL registered = NO;
                if (orig_sysctlbyname_device_spec) {
                    registered = [coord registerSysctlBynameProvider:@"devicespec.sysctlbyname"
                                                              priority:PXNativeHookPriorityIdentity
                                                                   pre:^BOOL(const char *name,
                                                                              void *oldp,
                                                                              size_t *oldlenp,
                                                                              void *newp,
                                                                              size_t newlen,
                                                                              int *outResult) {
                    return handleDeviceSpecSysctlByname(name, oldp, oldlenp, newp, newlen, outResult);
                }
                                                                  post:nil];
                }
                PXLog(@"[DeviceSpec] sysctlbyname coordinator selective provider %@",
                      registered ? @"registered" : @"registration failed");
                PXFileDebugAIDA64Log("[DeviceSpec.provider] registered=%d original=%d",
                                     registered ? 1 : 0,
                                     orig_sysctlbyname_device_spec ? 1 : 0);
            });
            
            // Initialize memory hook function pointers for scoped apps only
            PXFileDebugAIDA64Log("[DeviceSpec.ctor] before dlopen libSystem");
            void *libSystem = dlopen("/usr/lib/libSystem.dylib", RTLD_NOW);
            PXFileDebugAIDA64Log("[DeviceSpec.ctor] after dlopen libSystem handle=%d", libSystem ? 1 : 0);
            if (libSystem) {
                // Hook host_statistics64 for VM stats spoofing
                orig_host_statistics64 = dlsym(libSystem, "host_statistics64");
                if (orig_host_statistics64) {
                    PXFileDebugAIDA64Log("[DeviceSpec.ctor] before hook host_statistics64");
                    MSHookFunction(orig_host_statistics64, (void *)hook_host_statistics64, (void **)&orig_host_statistics64);
                    PXFileDebugAIDA64Log("[DeviceSpec.ctor] after hook host_statistics64");
                    PXLog(@"[DeviceSpec] Successfully hooked host_statistics64 for memory stats spoofing");
                }
                
                // Hook NXGetLocalArchInfo for CPU architecture spoofing
                orig_nx_get_local_arch_info = dlsym(libSystem, "NXGetLocalArchInfo");
                if (orig_nx_get_local_arch_info) {
                    PXFileDebugAIDA64Log("[DeviceSpec.ctor] before hook NXGetLocalArchInfo");
                    MSHookFunction((void *)orig_nx_get_local_arch_info,
                                   (void *)hook_nx_get_local_arch_info,
                                   (void **)&orig_nx_get_local_arch_info);
                    PXFileDebugAIDA64Log("[DeviceSpec.ctor] after hook NXGetLocalArchInfo");
                    PXLog(@"[DeviceSpec] Successfully hooked NXGetLocalArchInfo for CPU architecture spoofing");
                }
                
                dlclose(libSystem);
                PXFileDebugAIDA64Log("[DeviceSpec.ctor] after dlclose libSystem");
            }
            
            // Initialize Objective-C hooks for scoped apps only
            PXFileDebugAIDA64Log("[DeviceSpec.ctor] before %%init");
            %init();
            PXFileDebugAIDA64Log("[DeviceSpec.ctor] after %%init");
            
            PXLog(@"[DeviceSpec] Device specification hooks successfully initialized for scoped app: %@", currentBundleID);
            PXFileDebugAIDA64Log("[DeviceSpec.ctor] exit");
            
        } @catch (NSException *e) {
            PXFileDebugAIDA64Log("[DeviceSpec.ctor] exception=%s", e.description.UTF8String ?: "<nil>");
            PXLog(@"[DeviceSpec] ❌ Exception in constructor: %@", e);
        }
    }
}

// Helper for logging memory hook invocations only once
static void logMemoryHook(NSString *apiName) {
    if (!apiName.length) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        hookedMemoryAPIs = [NSMutableSet set];
    });

    BOOL shouldLog = NO;
    @synchronized(hookedMemoryAPIs) {
        if (![hookedMemoryAPIs containsObject:apiName]) {
            [hookedMemoryAPIs addObject:apiName];
            shouldLog = YES;
        }
    }

    if (shouldLog) {
        PXLog(@"[DeviceSpec] Memory spoofing API '%@' was accessed", apiName);
    }
}

// Normalize free-memory configuration to a bounded fraction.
static float getFreeMemoryPercentage(void) {
    const float defaultFreePercentage = 0.35f;
    if (!isSpoofingEnabled()) return defaultFreePercentage;

    NSDictionary *specs = getDeviceSpecs();
    if (!specs) return defaultFreePercentage;

    id configuredValue = specs[@"freeMemoryPercentage"];
    if ([configuredValue respondsToSelector:@selector(doubleValue)]) {
        double configured = [configuredValue doubleValue];
        if (configured > 1.0 && configured <= 100.0) configured /= 100.0;
        if (configured >= 0.10 && configured <= 0.70) return (float)configured;
    }

    NSInteger memoryGB = PXDeviceMemoryGBFromSpecs(specs);
    if (memoryGB >= 6) return 0.45f;
    if (memoryGB >= 4) return 0.40f;
    if (memoryGB >= 3) return 0.35f;
    if (memoryGB > 0) return 0.30f;
    return defaultFreePercentage;
}

// Produce deterministic buckets whose byte sum is exactly totalMemory.
static void getConsistentMemoryStats(unsigned long long totalMemory,
                                     unsigned long long *freeMemory,
                                     unsigned long long *wiredMemory,
                                     unsigned long long *activeMemory,
                                     unsigned long long *inactiveMemory) {
    double freeFraction = MAX(0.10, MIN(0.70, (double)getFreeMemoryPercentage()));
    uint64_t freeBytes = (uint64_t)((double)totalMemory * freeFraction);
    uint64_t remaining = totalMemory >= freeBytes ? totalMemory - freeBytes : 0;

    // Preserve the original 20:30:15 wired/active/inactive relationship.
    // 4:6:3 distributes the remaining bytes while leaving a real inactive bucket.
    uint64_t wiredBytes = (remaining * 4ULL) / 13ULL;
    uint64_t activeBytes = (remaining * 6ULL) / 13ULL;
    uint64_t inactiveBytes = remaining - wiredBytes - activeBytes;

    if (freeMemory) *freeMemory = freeBytes;
    if (wiredMemory) *wiredMemory = wiredBytes;
    if (activeMemory) *activeMemory = activeBytes;
    if (inactiveMemory) *inactiveMemory = inactiveBytes;
}

// NXGetLocalArchInfo reports ABI subtype, sourced from the canonical CPU profile.
static const NXArchInfo *hook_nx_get_local_arch_info(void) {
    if (!orig_nx_get_local_arch_info) return NULL;

    const NXArchInfo *original = orig_nx_get_local_arch_info();
    if (!original || !isSpoofingEnabled()) return original;

    NSDictionary *specs = getDeviceSpecs();
    const PXDeviceCPUProfile *profile = PXCPUProfileFromSpecs(specs);
    if (!profile) return original;

    g_deviceSpecThreadArchInfo = *original;
    g_deviceSpecThreadArchInfo.name = profile->cpuSubtype == CPU_SUBTYPE_ARM64E ? "arm64e" : "arm64";
    g_deviceSpecThreadArchInfo.cputype = CPU_TYPE_ARM64;
    g_deviceSpecThreadArchInfo.cpusubtype = profile->cpuSubtype;
    g_deviceSpecThreadArchInfo.description = profile->archDescription;

    static dispatch_once_t logOnce;
    dispatch_once(&logOnce, ^{
        PXLog(@"[DeviceSpec] Spoofing NXArchInfo: cpusubtype %d->%d, description %s->%s",
              original->cpusubtype,
              profile->cpuSubtype,
              original->description ? original->description : "<nil>",
              profile->archDescription ? profile->archDescription : "<nil>");
    });
    return &g_deviceSpecThreadArchInfo;
}

// Host statistics hook for memory stats
static kern_return_t hook_host_statistics64(host_t host, host_flavor_t flavor, host_info64_t info, mach_msg_type_number_t *count) {
    if (!orig_host_statistics64) return KERN_FAILURE;
    kern_return_t result = orig_host_statistics64(host, flavor, info, count);

    if (result != KERN_SUCCESS || !info || !count || !isSpoofingEnabled()) {
        return result;
    }
    
    // Get device specs
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return result;
    }
    
    uint64_t totalMemory = 0;
    if (!PXDeviceMemoryBytesFromSpecs(specs, &totalMemory)) {
        return result;
    }
    NSInteger deviceMemoryGB = PXDeviceMemoryGBFromSpecs(specs);
    
    // Handle specific host info types
    if (flavor == HOST_VM_INFO64 || flavor == HOST_VM_INFO) {
        // VM statistics (free memory, etc.)
        if (flavor == HOST_VM_INFO64 && *count >= HOST_VM_INFO64_COUNT) {
            vm_statistics64_data_t *vmStats = (vm_statistics64_data_t *)info;
            
            // Calculate consistent memory values
            unsigned long long freeMemory, wiredMemory, activeMemory, inactiveMemory;
            getConsistentMemoryStats(totalMemory, &freeMemory, &wiredMemory, &activeMemory, &inactiveMemory);
            
            // page size is typically 4096 or 16384 depending on device
            vm_size_t pageSize = 4096;
            if (host_page_size(host, &pageSize) != KERN_SUCCESS || pageSize == 0) pageSize = 4096;
            
            // Convert bytes to pages
            uint64_t freePages = freeMemory / pageSize;
            uint64_t wiredPages = wiredMemory / pageSize;
            uint64_t activePages = activeMemory / pageSize;
            uint64_t inactivePages = inactiveMemory / pageSize;
            
            // Update stats consistently
            vmStats->free_count = freePages;
            vmStats->wire_count = wiredPages;
            vmStats->active_count = activePages;
            vmStats->inactive_count = inactivePages;
            
            // Log the change the first time
            static BOOL loggedVMStats = NO;
            if (!loggedVMStats) {
                PXLog(@"[DeviceSpec] Spoofed vm_statistics64 with %llu free pages (%.1f%% of total memory)",
                    freePages, (float)freeMemory * 100.0 / totalMemory);
                loggedVMStats = YES;
            }
        } else if (flavor == HOST_VM_INFO && *count >= HOST_VM_INFO_COUNT) {
            vm_statistics_data_t *vmStats = (vm_statistics_data_t *)info;
            
            // Calculate consistent memory values
            unsigned long long freeMemory, wiredMemory, activeMemory, inactiveMemory;
            getConsistentMemoryStats(totalMemory, &freeMemory, &wiredMemory, &activeMemory, &inactiveMemory);
            
            // page size is typically 4096 or 16384 depending on device
            vm_size_t pageSize = 4096;
            if (host_page_size(host, &pageSize) != KERN_SUCCESS || pageSize == 0) pageSize = 4096;
            
            // Convert bytes to pages
            unsigned int freePages = (unsigned int)(freeMemory / pageSize);
            unsigned int wiredPages = (unsigned int)(wiredMemory / pageSize);
            unsigned int activePages = (unsigned int)(activeMemory / pageSize);
            unsigned int inactivePages = (unsigned int)(inactiveMemory / pageSize);
            
            // Update stats consistently
            vmStats->free_count = freePages;
            vmStats->wire_count = wiredPages;
            vmStats->active_count = activePages;
            vmStats->inactive_count = inactivePages;
            
            // Log the change the first time
            static BOOL loggedVMStats32 = NO;
            if (!loggedVMStats32) {
                PXLog(@"[DeviceSpec] Spoofed vm_statistics with %u free pages (%.1f%% of total memory)",
                    freePages, (float)freeMemory * 100.0 / totalMemory);
                loggedVMStats32 = YES;
            }
        }
    } else if (flavor == HOST_BASIC_INFO) {
        // Basic host info including memory size
        if (*count >= HOST_BASIC_INFO_COUNT) {
            host_basic_info_t basicInfo = (host_basic_info_t)info;
            
            // Spoof max memory to match our deviceMemory value
            basicInfo->max_mem = totalMemory;
            
            // Log the change the first time
            static BOOL loggedBasicInfo = NO;
            if (!loggedBasicInfo) {
                PXLog(@"[DeviceSpec] Spoofed host_basic_info max_mem to %llu bytes (%ld GB)",
                    totalMemory, (long)deviceMemoryGB);
                loggedBasicInfo = YES;
            }
        }
    }
    
    return result;
}

// Selective coordinator pre-provider for CPU and memory sysctl keys.
static BOOL handleDeviceSpecSysctlByname(const char *name,
                                         void *oldp,
                                         size_t *oldlenp,
                                         void *newp,
                                         size_t newlen,
                                         int *outResult) {
    if (!name || !outResult || !oldlenp || newp != NULL || newlen != 0 || !isSpoofingEnabled()) {
        return NO;
    }

    NSDictionary *specs = getDeviceSpecs();
    if (!specs) return NO;

    const PXDeviceCPUProfile *profile = PXCPUProfileFromSpecs(specs);
    NSUInteger coreCount = PXCPUCoreCountFromSpecs(specs);

    if (strcmp(name, "hw.physicalcpu") == 0 ||
        strcmp(name, "hw.physicalcpu_max") == 0 ||
        strcmp(name, "hw.logicalcpu") == 0 ||
        strcmp(name, "hw.logicalcpu_max") == 0 ||
        strcmp(name, "hw.ncpu") == 0 ||
        strcmp(name, "hw.activecpu") == 0) {
        if (coreCount == 0 || coreCount > UINT32_MAX) return NO;
        uint32_t value = (uint32_t)coreCount;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  PXWriteSysctlBytes(&value, sizeof(value), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (profile && strcmp(name, "hw.cputype") == 0) {
        uint32_t value = (uint32_t)CPU_TYPE_ARM64;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  PXWriteSysctlBytes(&value, sizeof(value), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (profile && strcmp(name, "hw.cpusubtype") == 0) {
        uint32_t value = (uint32_t)profile->cpuSubtype;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  PXWriteSysctlBytes(&value, sizeof(value), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (profile && strcmp(name, "hw.cpufamily") == 0) {
        uint32_t value = profile->cpuFamily;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  PXWriteSysctlBytes(&value, sizeof(value), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (profile && strcmp(name, "hw.cachelinesize") == 0) {
        uint64_t value = profile->cacheLineBytes;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  PXWriteSysctlBytes(&value, sizeof(value), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (profile && strcmp(name, "hw.l1icachesize") == 0) {
        uint64_t value = profile->l1iCacheBytes;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  PXWriteSysctlBytes(&value, sizeof(value), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (profile && strcmp(name, "hw.l1dcachesize") == 0) {
        uint64_t value = profile->l1dCacheBytes;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  PXWriteSysctlBytes(&value, sizeof(value), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (profile && strcmp(name, "hw.l2cachesize") == 0) {
        uint64_t value = profile->l2CacheBytes;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  PXWriteSysctlBytes(&value, sizeof(value), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    uint64_t totalMemory = 0;
    BOOL hasMemory = PXDeviceMemoryBytesFromSpecs(specs, &totalMemory);

    if (hasMemory && strcmp(name, "hw.memsize") == 0) {
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  PXWriteSysctlBytes(&totalMemory, sizeof(totalMemory), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (hasMemory && strcmp(name, "hw.physmem") == 0) {
        // XNU exposes hw.physmem as a legacy compatibility unsigned int.
        uint32_t legacyBytes = totalMemory > UINT32_MAX ? UINT32_MAX : (uint32_t)totalMemory;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  PXWriteSysctlBytes(&legacyBytes, sizeof(legacyBytes), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    // The following keys are release/build dependent. Ask the coordinator-owned
    // original exactly once to preserve ENOENT/EPERM, then serialize from the
    // canonical profile using the caller's original buffer capacity.
    if (profile && strncmp(name, "hw.optional.", 12) == 0) {
        uint32_t value = 0;
        if (!PXOptionalFeatureValue(name, profile, &value)) return NO;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  PXWriteExistingSysctlBytes(name,
                                          &value,
                                          sizeof(value),
                                          oldp,
                                          oldlenp,
                                          outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (profile && (strcmp(name, "hw.cpufrequency") == 0 ||
                    strcmp(name, "hw.cpufrequency_max") == 0 ||
                    strcmp(name, "hw.cpufrequency_min") == 0)) {
        uint64_t value = strcmp(name, "hw.cpufrequency_min") == 0
            ? profile->minFrequencyHz
            : profile->maxFrequencyHz;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  PXWriteExistingSysctlBytes(name,
                                          &value,
                                          sizeof(value),
                                          oldp,
                                          oldlenp,
                                          outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (profile && (strcmp(name, "hw.cpu.brand_string") == 0 ||
                    strcmp(name, "machdep.cpu.brand_string") == 0 ||
                    strcmp(name, "hw.cpubrand") == 0)) {
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  PXWriteExistingSysctlCString(name,
                                            profile->brand,
                                            oldp,
                                            oldlenp,
                                            outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (profile && strcmp(name, "hw.cpu.features") == 0) {
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  PXWriteExistingSysctlCString(name,
                                            profile->featureString,
                                            oldp,
                                            oldlenp,
                                            outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (strcmp(name, "vm.swapusage") == 0) {
        if (!hasMemory) return NO;

        struct xsw_usage usage;
        memset(&usage, 0, sizeof(usage));
        usage.xsu_total = PXDeviceMemoryGBFromSpecs(specs) >= 4 ? totalMemory / 2ULL : totalMemory;
        usage.xsu_used = (usage.xsu_total * 3ULL) / 10ULL;
        usage.xsu_avail = usage.xsu_total - usage.xsu_used;

        vm_size_t pageSize = 4096;
        if (host_page_size(mach_host_self(), &pageSize) != KERN_SUCCESS || pageSize == 0) {
            pageSize = 4096;
        }
        usage.xsu_pagesize = (uint32_t)pageSize;
        usage.xsu_encrypted = TRUE;

        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  PXWriteExistingSysctlBytes(name,
                                          &usage,
                                          sizeof(usage),
                                          oldp,
                                          oldlenp,
                                          outResult),
                                                  oldlenp,
                                                  outResult);
    }

    return NO;
}
