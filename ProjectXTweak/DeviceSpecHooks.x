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
#import "PXPaths.h"
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

// P1.2 immutable profile snapshot. Every DeviceSpec surface reads one published
// generation instead of independently re-reading profile files on hot paths.
@interface PXDeviceSpecSnapshot : NSObject {
@private
    BOOL _enabled;
    uint64_t _generation;
    NSString *_profileID;
    NSString *_deviceModel;
    NSDictionary *_specs;
    NSString *_source;
}
@property (nonatomic, readonly, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly) uint64_t generation;
@property (nonatomic, copy, readonly) NSString *profileID;
@property (nonatomic, copy, readonly) NSString *deviceModel;
@property (nonatomic, copy, readonly) NSDictionary *specs;
@property (nonatomic, copy, readonly) NSString *source;
- (instancetype)initWithGeneration:(uint64_t)generation
                           enabled:(BOOL)enabled
                         profileID:(NSString *)profileID
                       deviceModel:(NSString *)deviceModel
                             specs:(NSDictionary *)specs
                            source:(NSString *)source;
@end

@implementation PXDeviceSpecSnapshot
@synthesize enabled = _enabled;
@synthesize generation = _generation;
@synthesize profileID = _profileID;
@synthesize deviceModel = _deviceModel;
@synthesize specs = _specs;
@synthesize source = _source;

- (instancetype)initWithGeneration:(uint64_t)generation
                           enabled:(BOOL)enabled
                         profileID:(NSString *)profileID
                       deviceModel:(NSString *)deviceModel
                             specs:(NSDictionary *)specs
                            source:(NSString *)source {
    self = [super init];
    if (self) {
        _generation = generation;
        _enabled = enabled;
        _profileID = [profileID copy];
        _deviceModel = [deviceModel copy];
        _specs = [specs copy];
        _source = [source copy];
    }
    return self;
}
@end

static NSObject *gDeviceSpecSnapshotLock;
static PXDeviceSpecSnapshot *gDeviceSpecSnapshot;
static uint64_t gDeviceSpecSnapshotGeneration;
static __thread BOOL gDeviceSpecSnapshotBuildInProgress;

// Cache to track which memory hooks have been called for logging.
static NSMutableSet *hookedMemoryAPIs;

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
static BOOL PXCompleteDeviceSpecSysctlResult(const char *name, const PXDeviceCPUProfile *profile, uint64_t generation, BOOL handled, size_t *oldlenp, int *outResult);
static BOOL PXOptionalFeatureValue(const char *name, const PXDeviceCPUProfile *profile, uint32_t *outValue);
static id PXDeviceSpecDeepImmutableCopy(id object);
static NSString *PXDeviceSpecValidatedProfileID(id value);
static NSDictionary *PXDeviceSpecReconstructSpecs(NSDictionary *deviceIDs);
static PXDeviceSpecSnapshot *PXBuildDeviceSpecSnapshot(uint64_t generation);
static PXDeviceSpecSnapshot *PXReloadDeviceSpecSnapshot(NSString *reason);
static PXDeviceSpecSnapshot *PXCurrentDeviceSpecSnapshot(void);
static PXDeviceSpecSnapshot *PXActiveDeviceSpecSnapshot(void);
static float getFreeMemoryPercentage(NSDictionary *specs);
static void getConsistentMemoryStats(NSDictionary *specs,
                                     unsigned long long totalMemory,
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
                                             uint64_t generation,
                                             BOOL handled,
                                             size_t *oldlenp,
                                             int *outResult) {
    if (!handled) return NO;

    int resultErrno = errno;
    static volatile uint32_t resultLogCount = 0;
    uint32_t logIndex = __sync_fetch_and_add(&resultLogCount, 1u);
    if (logIndex < 80u) {
        PXFileDebugAIDA64Log("[DeviceSpec.sysctlbyname.result] key=%s profile=%s generation=%llu result=%d size=%llu errno=%d",
                             name ?: "<nil>",
                             profile ? profile->token : "<none>",
                             (unsigned long long)generation,
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

// Recursively detach mutable profile containers before publishing a snapshot.
static id PXDeviceSpecDeepImmutableCopy(id object) {
    if (!object || object == [NSNull null]) return object;

    if ([object isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *copy = [NSMutableDictionary dictionaryWithCapacity:[(NSDictionary *)object count]];
        [(NSDictionary *)object enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            (void)stop;
            id immutableKey = [key conformsToProtocol:@protocol(NSCopying)] ? [key copy] : key;
            id immutableValue = PXDeviceSpecDeepImmutableCopy(value);
            if (immutableKey && immutableValue) copy[immutableKey] = immutableValue;
        }];
        return [copy copy];
    }

    if ([object isKindOfClass:[NSArray class]]) {
        NSMutableArray *copy = [NSMutableArray arrayWithCapacity:[(NSArray *)object count]];
        for (id value in (NSArray *)object) {
            id immutableValue = PXDeviceSpecDeepImmutableCopy(value);
            if (immutableValue) [copy addObject:immutableValue];
        }
        return [copy copy];
    }

    if ([object isKindOfClass:[NSSet class]]) {
        NSMutableSet *copy = [NSMutableSet setWithCapacity:[(NSSet *)object count]];
        for (id value in (NSSet *)object) {
            id immutableValue = PXDeviceSpecDeepImmutableCopy(value);
            if (immutableValue) [copy addObject:immutableValue];
        }
        return [copy copy];
    }

    return [object conformsToProtocol:@protocol(NSCopying)] ? [object copy] : object;
}

static NSString *PXDeviceSpecValidatedProfileID(id value) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *profileID = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!profileID.length || profileID.length > 128) return nil;
    if ([profileID isEqualToString:@"."] || [profileID isEqualToString:@".."]) return nil;
    if ([profileID rangeOfString:@"/"].location != NSNotFound ||
        [profileID rangeOfString:@"\\"].location != NSNotFound ||
        ![[profileID lastPathComponent] isEqualToString:profileID]) {
        return nil;
    }
    return profileID;
}

static NSDictionary *PXDeviceSpecReconstructSpecs(NSDictionary *deviceIDs) {
    if (![deviceIDs isKindOfClass:[NSDictionary class]]) return nil;
    NSString *deviceModel = [deviceIDs[@"DeviceModel"] isKindOfClass:[NSString class]] ? deviceIDs[@"DeviceModel"] : nil;
    if (!deviceModel.length) return nil;

    NSMutableDictionary *specs = [NSMutableDictionary dictionary];
    specs[@"value"] = deviceModel;
    specs[@"name"] = deviceIDs[@"DeviceModelName"] ?: @"Unknown";
    specs[@"screenResolution"] = deviceIDs[@"ScreenResolution"] ?: @"Unknown";
    specs[@"viewportResolution"] = deviceIDs[@"ViewportResolution"] ?: @"Unknown";
    specs[@"devicePixelRatio"] = deviceIDs[@"DevicePixelRatio"] ?: @(0);
    specs[@"screenDensity"] = deviceIDs[@"ScreenDensityPPI"] ?: @(0);
    specs[@"cpuArchitecture"] = deviceIDs[@"CPUArchitecture"] ?: @"Unknown";
    specs[@"deviceMemory"] = deviceIDs[@"DeviceMemory"] ?: @(0);
    specs[@"gpuFamily"] = deviceIDs[@"GPUFamily"] ?: @"Unknown";
    specs[@"cpuCoreCount"] = deviceIDs[@"CPUCoreCount"] ?: @(0);
    specs[@"metalFeatureSet"] = deviceIDs[@"MetalFeatureSet"] ?: @"Unknown";

    if (deviceIDs[@"FreeMemoryPercentage"]) {
        specs[@"freeMemoryPercentage"] = deviceIDs[@"FreeMemoryPercentage"];
    }
    if (deviceIDs[@"BoardID"]) specs[@"boardID"] = deviceIDs[@"BoardID"];
    if (deviceIDs[@"HwModel"]) {
        specs[@"hwModel"] = deviceIDs[@"HwModel"];
    } else if (deviceIDs[@"BoardID"]) {
        specs[@"hwModel"] = deviceIDs[@"BoardID"];
    }

    NSMutableDictionary *webGLInfo = [NSMutableDictionary dictionary];
    webGLInfo[@"webglVendor"] = deviceIDs[@"WebGLVendor"] ?: @"Apple";
    webGLInfo[@"webglRenderer"] = deviceIDs[@"WebGLRenderer"] ?: @"Apple GPU";
    webGLInfo[@"unmaskedVendor"] = deviceIDs[@"WebGLUnmaskedVendor"] ?: @"Apple Inc.";
    webGLInfo[@"unmaskedRenderer"] = deviceIDs[@"WebGLUnmaskedRenderer"] ?: (deviceIDs[@"GPUFamily"] ?: @"Apple GPU");
    webGLInfo[@"webglVersion"] = deviceIDs[@"WebGLVersion"] ?: @"WebGL 2.0";
    webGLInfo[@"maxTextureSize"] = deviceIDs[@"WebGLMaxTextureSize"] ?: @(16384);
    webGLInfo[@"maxRenderBufferSize"] = deviceIDs[@"WebGLMaxRenderBufferSize"] ?: @(16384);
    specs[@"webGLInfo"] = webGLInfo;

    return PXDeviceSpecDeepImmutableCopy(specs);
}

static NSObject *PXDeviceSpecSnapshotLockObject(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gDeviceSpecSnapshotLock = [NSObject new];
    });
    return gDeviceSpecSnapshotLock;
}

static PXDeviceSpecSnapshot *PXBuildDeviceSpecSnapshot(uint64_t generation) {
    NSString *bundleID = getCurrentBundleID();
    NSString *processName = [NSProcessInfo processInfo].processName;
    BOOL allowed = bundleID.length && PXProcessIsAllowedForSpoofing(bundleID,
                                                                     processName,
                                                                     PXScopeOptionAllowSafariAuthStack);
    if (!allowed) {
        return [[PXDeviceSpecSnapshot alloc] initWithGeneration:generation
                                                       enabled:NO
                                                     profileID:nil
                                                   deviceModel:nil
                                                         specs:nil
                                                        source:@"scope-denied"];
    }

    NSString *profilesPath = PXProfilesPath();
    NSDictionary *centralInfo = [NSDictionary dictionaryWithContentsOfFile:PXCurrentProfileInfoPath()];
    NSString *profileID = PXDeviceSpecValidatedProfileID(centralInfo[@"ProfileId"]);
    if (!profileID.length) {
        NSDictionary *legacyInfo = [NSDictionary dictionaryWithContentsOfFile:PXLegacyActiveProfileInfoPath()];
        id legacyID = legacyInfo[@"ProfileId"] ?: legacyInfo[@"currentProfileId"];
        profileID = PXDeviceSpecValidatedProfileID(legacyID);
    }

    NSDictionary *settings = nil;
    NSDictionary *deviceIDs = nil;
    if (profileID.length && profilesPath.length) {
        NSString *profileRoot = [profilesPath stringByAppendingPathComponent:profileID];
        settings = [NSDictionary dictionaryWithContentsOfFile:[profileRoot stringByAppendingPathComponent:@"settings.plist"]];
        deviceIDs = [NSDictionary dictionaryWithContentsOfFile:[[profileRoot stringByAppendingPathComponent:@"identity"]
                                                                  stringByAppendingPathComponent:@"device_ids.plist"]];
    }

    IdentifierManager *identifierManager = nil;
    Class identifierManagerClass = NSClassFromString(@"IdentifierManager");
    if (identifierManagerClass && [identifierManagerClass respondsToSelector:@selector(sharedManager)]) {
        identifierManager = [identifierManagerClass sharedManager];
    }

    BOOL managerAvailable = identifierManager != nil;
    BOOL managerEnabled = managerAvailable && [identifierManager isIdentifierEnabled:@"DeviceModel"];
    id profileEnabledValue = settings[@"deviceModelEnabled"];
    BOOL hasProfileEnableValue = [profileEnabledValue respondsToSelector:@selector(boolValue)];
    BOOL profileFallbackEnabled = hasProfileEnableValue && [profileEnabledValue boolValue];
    BOOL requestedEnabled = managerAvailable ? managerEnabled : profileFallbackEnabled;

    // The selected profile is the only identity source for this generation.
    // IdentifierManager remains the canonical enable gate shared with the UI and
    // Tweak; the profile flag is used only when that manager is unavailable.
    NSString *deviceModel = [deviceIDs[@"DeviceModel"] isKindOfClass:[NSString class]]
        ? deviceIDs[@"DeviceModel"]
        : nil;
    NSDictionary *specs = nil;
    NSString *source = @"disabled";

    if (requestedEnabled && deviceModel.length) {
        specs = PXDeviceSpecReconstructSpecs(deviceIDs);
        source = @"device_ids";
    }

    if (requestedEnabled && !specs.count && deviceModel.length) {
        Class deviceManagerClass = NSClassFromString(@"DeviceModelManager");
        DeviceModelManager *deviceManager = nil;
        if (deviceManagerClass && [deviceManagerClass respondsToSelector:@selector(sharedManager)]) {
            deviceManager = [deviceManagerClass sharedManager];
        }
        NSDictionary *managerSpecs = [deviceManager deviceSpecificationsForModel:deviceModel];
        if ([managerSpecs isKindOfClass:[NSDictionary class]] && managerSpecs.count) {
            specs = PXDeviceSpecDeepImmutableCopy(managerSpecs);
            source = @"device_model_manager";
        }
    }

    BOOL effectiveEnabled = requestedEnabled && profileID.length && deviceModel.length && specs.count > 0;
    if (requestedEnabled && !effectiveEnabled) {
        source = deviceModel.length ? @"missing-specs" : @"missing-model";
        PXLog(@"[DeviceSpec.snapshot] requested profile failed closed model=%@ profile=%@ source=%@",
              deviceModel ?: @"<nil>",
              profileID ?: @"<nil>",
              source);
    }

    return [[PXDeviceSpecSnapshot alloc] initWithGeneration:generation
                                                   enabled:effectiveEnabled
                                                 profileID:profileID
                                               deviceModel:deviceModel
                                                     specs:effectiveEnabled ? specs : nil
                                                    source:source];
}

static PXDeviceSpecSnapshot *PXReloadDeviceSpecSnapshot(NSString *reason) {
    int incomingErrno = errno;
    NSObject *lock = PXDeviceSpecSnapshotLockObject();

    // Recursive hook activity during a build must see the last complete snapshot
    // (or fail open during the very first build), never start a nested file read.
    if (gDeviceSpecSnapshotBuildInProgress) {
        PXDeviceSpecSnapshot *existing = nil;
        @synchronized(lock) {
            existing = gDeviceSpecSnapshot;
        }
        errno = incomingErrno;
        return existing;
    }

    uint64_t generation = 0;
    @synchronized(lock) {
        generation = ++gDeviceSpecSnapshotGeneration;
    }

    gDeviceSpecSnapshotBuildInProgress = YES;
    PXDeviceSpecSnapshot *candidate = nil;
    @try {
        // Build outside the publication lock. Readers continue using the previous
        // immutable generation while profile I/O and manager lookups complete.
        @autoreleasepool {
            candidate = PXBuildDeviceSpecSnapshot(generation);
        }
    } @catch (NSException *exception) {
        PXLog(@"[DeviceSpec.snapshot] build exception: %@", exception);
        candidate = [[PXDeviceSpecSnapshot alloc] initWithGeneration:generation
                                                             enabled:NO
                                                           profileID:nil
                                                         deviceModel:nil
                                                               specs:nil
                                                              source:@"exception"];
    } @finally {
        gDeviceSpecSnapshotBuildInProgress = NO;
    }

    PXDeviceSpecSnapshot *published = nil;
    BOOL didPublish = NO;
    BOOL rejectedTransientFailure = NO;
    @synchronized(lock) {
        // Concurrent reloads may finish out of order. A lower generation is stale
        // and must never overwrite a newer complete publication.
        BOOL transientFailure = [candidate.source isEqualToString:@"exception"] ||
                                [candidate.source isEqualToString:@"missing-model"] ||
                                [candidate.source isEqualToString:@"missing-specs"];
        if (transientFailure && gDeviceSpecSnapshot) {
            // Keep the last complete/intentional generation while profile files are
            // between atomic writes. This avoids a temporary real-device leak.
            rejectedTransientFailure = YES;
        } else if (candidate && (!gDeviceSpecSnapshot || candidate.generation > gDeviceSpecSnapshot.generation)) {
            gDeviceSpecSnapshot = candidate;
            didPublish = YES;
        }
        published = gDeviceSpecSnapshot;
    }

    if (rejectedTransientFailure) {
        PXFileDebugAIDA64Log("[DeviceSpec.snapshot.reject] generation=%llu source=%s retained=%llu reason=%s",
                             (unsigned long long)candidate.generation,
                             candidate.source.UTF8String ?: "<none>",
                             (unsigned long long)published.generation,
                             reason.UTF8String ?: "<none>");
    }

    if (didPublish) {
        PXFileDebugAIDA64Log("[DeviceSpec.snapshot] generation=%llu enabled=%d profile=%s model=%s source=%s specs=%llu reason=%s",
                             (unsigned long long)published.generation,
                             published.enabled ? 1 : 0,
                             published.profileID.UTF8String ?: "<none>",
                             published.deviceModel.UTF8String ?: "<none>",
                             published.source.UTF8String ?: "<none>",
                             (unsigned long long)published.specs.count,
                             reason.UTF8String ?: "<none>");
    }
    errno = incomingErrno;
    return published;
}

static PXDeviceSpecSnapshot *PXCurrentDeviceSpecSnapshot(void) {
    int incomingErrno = errno;
    NSObject *lock = PXDeviceSpecSnapshotLockObject();
    PXDeviceSpecSnapshot *snapshot = nil;
    @synchronized(lock) {
        snapshot = gDeviceSpecSnapshot;
    }
    if (!snapshot) snapshot = PXReloadDeviceSpecSnapshot(@"lazy");
    errno = incomingErrno;
    return snapshot;
}

static PXDeviceSpecSnapshot *PXActiveDeviceSpecSnapshot(void) {
    PXDeviceSpecSnapshot *snapshot = PXCurrentDeviceSpecSnapshot();
    return snapshot.enabled ? snapshot : nil;
}

#pragma mark - Document-Start Web Capability Script

// Central WKWebView ownership lives in CanvasFingerprintHooks.x. This exported helper
// contributes device capability spoofing without installing additional WKWebView hooks.
void PXInstallDeviceSpecUserScripts(WKUserContentController *userContentController) {
    if (!userContentController) return;

    PXDeviceSpecSnapshot *snapshot = PXActiveDeviceSpecSnapshot();
    if (!snapshot) return;

    NSString *generationMarker = [NSString stringWithFormat:@"__weaponx_device_capabilities_generation__:%llu",
                                  (unsigned long long)snapshot.generation];
    for (WKUserScript *existingScript in userContentController.userScripts) {
        if ([existingScript.source containsString:generationMarker]) {
            return;
        }
    }

    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString *processName = [NSProcessInfo processInfo].processName;
    if (!PXFullSpoofTestModeEnabled() &&
        PXProcessIsAllowedForSpoofing(bundleID, processName, PXScopeOptionAllowSafariAuthStack) &&
        PXIsSafariStackProcess(bundleID, processName)) {
        return;
    }

    NSDictionary *specs = snapshot.specs;
    NSInteger deviceMemoryGB = PXDeviceMemoryGBFromSpecs(specs);
    NSUInteger cpuCoreCount = PXCPUCoreCountFromSpecs(specs);
    if (deviceMemoryGB <= 0 && cpuCoreCount == 0) return;

    // Multiple immutable generations may coexist in a long-lived content
    // controller. Scripts execute in insertion order; the highest generation
    // wins and an older script can never downgrade a newer page state.
    NSString *script = [NSString stringWithFormat:
        @"/*%@*/\n"
         "(function(){\n"
         "  'use strict';\n"
         "  try {\n"
         "    var generation=Number('%llu')||1;\n"
         "    var current=Number(globalThis.__weaponx_device_capabilities_generation__||0);\n"
         "    if(current>=generation)return;\n"
         "    try{try{delete globalThis.__weaponx_device_capabilities_generation__;}catch(_){} Object.defineProperty(globalThis,'__weaponx_device_capabilities_generation__',{value:generation,configurable:true,enumerable:false,writable:true});}\n"
         "    catch(e){try{globalThis.__weaponx_device_capabilities_generation__=generation;}catch(_){} }\n"
         "    try{if(!globalThis.__weaponx_device_capabilities__)Object.defineProperty(globalThis,'__weaponx_device_capabilities__',{value:true,configurable:false,enumerable:false,writable:false});}catch(e){}\n"
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
        generationMarker,
        (unsigned long long)snapshot.generation,
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
    
    PXDeviceSpecSnapshot *snapshot = PXActiveDeviceSpecSnapshot();
    if (!snapshot || !PXDisplayUIScaleSpoofEnabled() || !shouldSpoofResolutionForCurrentProcess()) {
        return originalBounds;
    }
    NSDictionary *specs = snapshot.specs;
    
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
    
    PXDeviceSpecSnapshot *snapshot = PXActiveDeviceSpecSnapshot();
    if (!snapshot || !PXDisplayPixelMetricsSpoofEnabled() || !shouldSpoofResolutionForCurrentProcess()) {
        return originalNativeBounds;
    }
    NSDictionary *specs = snapshot.specs;
    
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
    
    PXDeviceSpecSnapshot *snapshot = PXActiveDeviceSpecSnapshot();
    if (!snapshot || !shouldSpoofResolutionForCurrentProcess()) {
        return originalScale;
    }
    NSDictionary *specs = snapshot.specs;
    
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
    
    if (!PXActiveDeviceSpecSnapshot()) {
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
    
    PXDeviceSpecSnapshot *snapshot = PXActiveDeviceSpecSnapshot();
    if (!snapshot) {
        return originalMemory;
    }
    NSDictionary *specs = snapshot.specs;
    
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
    
    PXDeviceSpecSnapshot *snapshot = PXActiveDeviceSpecSnapshot();
    if (!snapshot) {
        return originalAvailableMemory;
    }
    NSDictionary *specs = snapshot.specs;
    
    uint64_t totalMemory = 0;
    if (!PXDeviceMemoryBytesFromSpecs(specs, &totalMemory)) {
        return originalAvailableMemory;
    }

    unsigned long long spoofedAvailableMemory = 0;
    getConsistentMemoryStats(specs, totalMemory, &spoofedAvailableMemory, NULL, NULL, NULL);
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
    
    PXDeviceSpecSnapshot *snapshot = PXActiveDeviceSpecSnapshot();
    if (!snapshot) {
        return originalCount;
    }
    NSDictionary *specs = snapshot.specs;
    
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
    
    PXDeviceSpecSnapshot *snapshot = PXActiveDeviceSpecSnapshot();
    if (!snapshot) {
        return originalName;
    }
    NSDictionary *specs = snapshot.specs;
    
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
    
    PXDeviceSpecSnapshot *snapshot = PXActiveDeviceSpecSnapshot();
    if (!snapshot) {
        return original;
    }
    NSDictionary *specs = snapshot.specs;
    
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
    
    PXDeviceSpecSnapshot *snapshot = PXActiveDeviceSpecSnapshot();
    if (!snapshot) {
        return originalName;
    }
    NSDictionary *specs = snapshot.specs;
    
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
    
    PXDeviceSpecSnapshot *snapshot = PXActiveDeviceSpecSnapshot();
    if (!snapshot) {
        return originalFamilyName;
    }
    NSDictionary *specs = snapshot.specs;
    
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

    PXDeviceSpecSnapshot *snapshot = PXActiveDeviceSpecSnapshot();
    if (!snapshot || !PXDisplayUIScaleSpoofEnabled() || !shouldSpoofResolutionForCurrentProcess()) {
        return original;
    }
    NSDictionary *specs = snapshot.specs;

    CGFloat pixelRatio = [specs[@"devicePixelRatio"] floatValue];
    if (pixelRatio <= 0) return original;

    return pixelRatio;
}

// For screen density
- (CGFloat)native_scale {
    CGFloat originalScale = %orig;
    
    // Avoid spoofing screen density in Safari/Auth stack; it can desync page layout/touch logic.
    PXDeviceSpecSnapshot *snapshot = PXActiveDeviceSpecSnapshot();
    if (!snapshot || !PXDisplayUIScaleSpoofEnabled() || !shouldSpoofResolutionForCurrentProcess()) {
        return originalScale;
    }
    NSDictionary *specs = snapshot.specs;
    
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

// Rebuild and atomically publish the next immutable generation on profile changes.
static void refreshCaches(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center;
    (void)observer;
    (void)object;
    (void)userInfo;
    @autoreleasepool {
        NSString *notificationName = (__bridge NSString *)name;
        PXLog(@"[DeviceSpec] Received notification: %@, rebuilding immutable snapshot", notificationName);
        PXReloadDeviceSpecSnapshot(notificationName ?: @"notification");
    }
}

#pragma mark - CPU Core Spoofing Enhancements

// JavaScript hardwareConcurrency is installed through the shared document-start
// WKUserScript path. Keep only lower-level native CPU detection hooks here.

// Hook lower-level CPU detection APIs for native apps
%hook host_basic_info

- (unsigned int)max_cpus {
    unsigned int original = %orig;
    
    PXDeviceSpecSnapshot *snapshot = PXActiveDeviceSpecSnapshot();
    if (!snapshot) {
        return original;
    }
    NSDictionary *specs = snapshot.specs;
    
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
            
            // Register for notifications before publishing the first snapshot so
            // no profile-change generation can be missed after hooks become visible.
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
            
            PXDeviceSpecSnapshot *initialSnapshot = PXReloadDeviceSpecSnapshot(@"constructor");
            PXLog(@"[DeviceSpec] App %@ is scoped; snapshot generation=%llu enabled=%d source=%@",
                  currentBundleID,
                  (unsigned long long)initialSnapshot.generation,
                  initialSnapshot.enabled ? 1 : 0,
                  initialSnapshot.source ?: @"<none>");

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

// Normalize free-memory configuration from the same immutable snapshot used
// for total memory so one call cannot mix two profile generations.
static float getFreeMemoryPercentage(NSDictionary *specs) {
    const float defaultFreePercentage = 0.35f;
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
static void getConsistentMemoryStats(NSDictionary *specs,
                                     unsigned long long totalMemory,
                                     unsigned long long *freeMemory,
                                     unsigned long long *wiredMemory,
                                     unsigned long long *activeMemory,
                                     unsigned long long *inactiveMemory) {
    double freeFraction = MAX(0.10, MIN(0.70, (double)getFreeMemoryPercentage(specs)));
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
    if (!original) return original;

    PXDeviceSpecSnapshot *snapshot = PXActiveDeviceSpecSnapshot();
    if (!snapshot) return original;
    NSDictionary *specs = snapshot.specs;
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

    if (result != KERN_SUCCESS || !info || !count) {
        return result;
    }

    PXDeviceSpecSnapshot *snapshot = PXActiveDeviceSpecSnapshot();
    if (!snapshot) return result;
    NSDictionary *specs = snapshot.specs;
    
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
            getConsistentMemoryStats(specs, totalMemory, &freeMemory, &wiredMemory, &activeMemory, &inactiveMemory);
            
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
            getConsistentMemoryStats(specs, totalMemory, &freeMemory, &wiredMemory, &activeMemory, &inactiveMemory);
            
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
    if (!name || !outResult || !oldlenp || newp != NULL || newlen != 0) {
        return NO;
    }

    PXDeviceSpecSnapshot *snapshot = PXActiveDeviceSpecSnapshot();
    if (!snapshot) return NO;
    NSDictionary *specs = snapshot.specs;
    uint64_t generation = snapshot.generation;

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
                                                  generation,
                                                  PXWriteSysctlBytes(&value, sizeof(value), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (profile && strcmp(name, "hw.cputype") == 0) {
        uint32_t value = (uint32_t)CPU_TYPE_ARM64;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  generation,
                                                  PXWriteSysctlBytes(&value, sizeof(value), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (profile && strcmp(name, "hw.cpusubtype") == 0) {
        uint32_t value = (uint32_t)profile->cpuSubtype;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  generation,
                                                  PXWriteSysctlBytes(&value, sizeof(value), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (profile && strcmp(name, "hw.cpufamily") == 0) {
        uint32_t value = profile->cpuFamily;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  generation,
                                                  PXWriteSysctlBytes(&value, sizeof(value), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (profile && strcmp(name, "hw.cachelinesize") == 0) {
        uint64_t value = profile->cacheLineBytes;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  generation,
                                                  PXWriteSysctlBytes(&value, sizeof(value), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (profile && strcmp(name, "hw.l1icachesize") == 0) {
        uint64_t value = profile->l1iCacheBytes;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  generation,
                                                  PXWriteSysctlBytes(&value, sizeof(value), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (profile && strcmp(name, "hw.l1dcachesize") == 0) {
        uint64_t value = profile->l1dCacheBytes;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  generation,
                                                  PXWriteSysctlBytes(&value, sizeof(value), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (profile && strcmp(name, "hw.l2cachesize") == 0) {
        uint64_t value = profile->l2CacheBytes;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  generation,
                                                  PXWriteSysctlBytes(&value, sizeof(value), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    uint64_t totalMemory = 0;
    BOOL hasMemory = PXDeviceMemoryBytesFromSpecs(specs, &totalMemory);

    if (hasMemory && strcmp(name, "hw.memsize") == 0) {
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  generation,
                                                  PXWriteSysctlBytes(&totalMemory, sizeof(totalMemory), oldp, oldlenp, outResult),
                                                  oldlenp,
                                                  outResult);
    }

    if (hasMemory && strcmp(name, "hw.physmem") == 0) {
        // XNU exposes hw.physmem as a legacy compatibility unsigned int.
        uint32_t legacyBytes = totalMemory > UINT32_MAX ? UINT32_MAX : (uint32_t)totalMemory;
        return PXCompleteDeviceSpecSysctlResult(name,
                                                  profile,
                                                  generation,
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
                                                  generation,
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
                                                  generation,
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
                                                  generation,
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
                                                  generation,
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
                                                  generation,
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
