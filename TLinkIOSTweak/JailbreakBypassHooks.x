// JailbreakBypassHooks.x
// Phase 1: File/URL/InstalledApps/LoopbackPortScan/WriteCheck

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import <CoreFoundation/CoreFoundation.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <errno.h>
#import <fcntl.h>
#import <dirent.h>
#import <stdarg.h>
#import <stdlib.h>
#import <spawn.h>
#import <signal.h>
#import <sys/stat.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <sys/types.h>
#import <sys/mount.h>
#import <sys/statvfs.h>
#import "PXScope.h"
#import "PXFileDebug.h"
#import "PXNativeHookCoordinator.h"
#import "PXP1CFilters.h"
#import <sys/sysctl.h>
#if __has_include(<sys/user.h>)
#import <sys/user.h>
#endif
#import <string.h>
#import <pthread.h>
#import <dispatch/dispatch.h>
#import <mach/mach.h>
#import <stdint.h>
#import <stddef.h>
#import <stdbool.h>
#import <stdatomic.h>
#import <time.h>

// Darwin attrlist is only passed through opaquely by the B-02 wrappers. Keep
// the declaration SDK-compatible instead of depending on optional Theos headers.
struct attrlist;

// XPC types — Theos SDK doesn't ship <xpc/xpc.h>.
// We only need opaque pointers and a few functions.
typedef void *xpc_object_t;
typedef const struct _xpc_type_s *xpc_type_t;
extern const struct _xpc_type_s _xpc_type_dictionary;
#define XPC_TYPE_DICTIONARY ((xpc_type_t)&_xpc_type_dictionary)
extern xpc_type_t xpc_get_type(xpc_object_t object);
extern xpc_object_t xpc_dictionary_create(const char * const *keys, const xpc_object_t *values, size_t count);
extern xpc_object_t xpc_dictionary_create_empty(void);
extern uint64_t xpc_dictionary_get_uint64(xpc_object_t xdict, const char *key);
extern void xpc_dictionary_set_uint64(xpc_object_t xdict, const char *key, uint64_t value);

// bootstrap_look_up from bootstrap.h
extern kern_return_t bootstrap_look_up(mach_port_t bp, const char *service_name, mach_port_t *sp);
#ifndef BOOTSTRAP_UNKNOWN_SERVICE
#define BOOTSTRAP_UNKNOWN_SERVICE 1102
#endif

// XPC private pipe functions (resolved via libxpc at link time)
extern int xpc_pipe_routine(xpc_object_t pipe, xpc_object_t request, xpc_object_t *reply);
extern int xpc_pipe_routine_with_flags(xpc_object_t pipe, xpc_object_t request, xpc_object_t *reply, uint64_t flags);

// Some iOS SDKs used by Theos don't ship <link.h>, but we only need the
// leading fields of dl_phdr_info to access dlpi_name for dl_iterate_phdr.
struct dl_phdr_info {
    uintptr_t dlpi_addr;
    const char *dlpi_name;
    const void *dlpi_phdr;
    unsigned short dlpi_phnum;
};

// Some Theos SDKs for iOS don't ship <sys/ptrace.h>.
// PT_DENY_ATTACH is 31 on Darwin.
#ifndef PT_DENY_ATTACH
#define PT_DENY_ATTACH 31
#endif

// Code signing constants (not always available in Theos SDKs).
#ifndef CS_OPS_STATUS
#define CS_OPS_STATUS       0
#endif
#ifndef CS_PLATFORM_BINARY
#define CS_PLATFORM_BINARY  0x4000000
#endif
int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
#import <unistd.h>
#import <limits.h>

#ifndef AT_FDCWD
#define AT_FDCWD (-2)
#endif

#import <substrate.h>

// Optional logging macro if TLinkIOSLogging is present.
#ifndef PXLog
#define PXLog(...) NSLog(__VA_ARGS__)
#endif

@interface IdentifierManager : NSObject
+ (instancetype)sharedManager;
- (BOOL)isApplicationEnabled:(NSString *)bundleID;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray *)allInstalledApplications;
- (NSArray *)installedApplications;
- (NSArray *)allApplications;
- (NSArray *)installedPlugins;
@end

@interface LSBundleProxy : NSObject
- (NSString *)bundleIdentifier;
@end

@interface LSPlugInKitProxy : LSBundleProxy
- (NSString *)pluginIdentifier;
- (LSBundleProxy *)containingBundle;
@end

static void *FindSymbol(const char *symbol) {
    return symbol ? dlsym(RTLD_DEFAULT, symbol) : NULL;
}

static BOOL PXStrEqNoCase(const char *a, const char *b) {
    if (!a || !b) return NO;
    while (*a && *b) {
        char ca = *a;
        char cb = *b;
        if (ca >= 'A' && ca <= 'Z') ca = (char)(ca - 'A' + 'a');
        if (cb >= 'A' && cb <= 'Z') cb = (char)(cb - 'A' + 'a');
        if (ca != cb) return NO;
        a++; b++;
    }
    return (*a == '\0' && *b == '\0');
}

static BOOL PXHasPrefix(const char *s, const char *prefix) {
    if (!s || !prefix) return NO;
    size_t n = strlen(prefix);
    return strncmp(s, prefix, n) == 0;
}

static BOOL PXHasPrefixNoCase(const char *s, const char *prefix) {
    if (!s || !prefix) return NO;
    while (*prefix) {
        char a = *s;
        char b = *prefix;
        if (!a) return NO;
        if (a >= 'A' && a <= 'Z') a = (char)(a - 'A' + 'a');
        if (b >= 'A' && b <= 'Z') b = (char)(b - 'A' + 'a');
        if (a != b) return NO;
        s++; prefix++;
    }
    return YES;
}

static BOOL PXJBSpanEqualsNoCase(const char *bytes,
                                 size_t length,
                                 const char *expected) {
    if (!bytes || !expected) return NO;
    size_t expectedLength = strlen(expected);
    if (length != expectedLength) return NO;
    for (size_t i = 0; i < length; i++) {
        char a = bytes[i];
        char b = expected[i];
        if (a >= 'A' && a <= 'Z') a = (char)(a - 'A' + 'a');
        if (b >= 'A' && b <= 'Z') b = (char)(b - 'A' + 'a');
        if (a != b) return NO;
    }
    return YES;
}

static BOOL PXJBSpanHasPrefixNoCase(const char *bytes,
                                    size_t length,
                                    const char *prefix) {
    if (!bytes || !prefix) return NO;
    size_t prefixLength = strlen(prefix);
    if (length < prefixLength) return NO;
    for (size_t i = 0; i < prefixLength; i++) {
        char a = bytes[i];
        char b = prefix[i];
        if (a >= 'A' && a <= 'Z') a = (char)(a - 'A' + 'a');
        if (b >= 'A' && b <= 'Z') b = (char)(b - 'A' + 'a');
        if (a != b) return NO;
    }
    return YES;
}

static BOOL PXJBPathBasenameMatchesAnyNoCase(const char *path,
                                              const char *const *exactNames,
                                              const char *const *prefixNames) {
    if (!path || !path[0]) return NO;
    const char *end = path + strlen(path);
    while (end > path && end[-1] == '/') end--;
    if (end == path) return NO;

    const char *start = end;
    while (start > path && start[-1] != '/') start--;
    size_t length = (size_t)(end - start);

    if (exactNames) {
        for (size_t i = 0; exactNames[i]; i++) {
            if (PXJBSpanEqualsNoCase(start, length, exactNames[i])) return YES;
        }
    }
    if (prefixNames) {
        for (size_t i = 0; prefixNames[i]; i++) {
            if (PXJBSpanHasPrefixNoCase(start, length, prefixNames[i])) return YES;
        }
    }
    return NO;
}

static BOOL PXJBPathComponentMatchesAnyNoCase(const char *path,
                                               const char *const *exactComponents,
                                               const char *const *prefixComponents) {
    if (!path || !path[0]) return NO;
    const char *cursor = path;
    while (*cursor) {
        while (*cursor == '/') cursor++;
        if (!*cursor) break;
        const char *start = cursor;
        while (*cursor && *cursor != '/') cursor++;
        size_t length = (size_t)(cursor - start);

        if (exactComponents) {
            for (size_t i = 0; exactComponents[i]; i++) {
                if (PXJBSpanEqualsNoCase(start, length, exactComponents[i])) return YES;
            }
        }
        if (prefixComponents) {
            for (size_t i = 0; prefixComponents[i]; i++) {
                if (PXJBSpanHasPrefixNoCase(start, length, prefixComponents[i])) return YES;
            }
        }
    }
    return NO;
}

static BOOL PXJBPathContainsComponentSequencePrefixNoCase(const char *path,
                                                           const char *sequencePrefix) {
    if (!path || !sequencePrefix || !sequencePrefix[0]) return NO;
    const char *cursor = path;
    while (*cursor) {
        while (*cursor == '/') cursor++;
        if (!*cursor) break;
        if (PXHasPrefixNoCase(cursor, sequencePrefix)) return YES;
        while (*cursor && *cursor != '/') cursor++;
    }
    return NO;
}

static BOOL PXJBPathContainsComponentSequenceNoCase(const char *path,
                                                     const char *sequence) {
    if (!path || !sequence || !sequence[0]) return NO;
    size_t sequenceLength = strlen(sequence);
    const char *cursor = path;
    while (*cursor) {
        while (*cursor == '/') cursor++;
        if (!*cursor) break;
        if (PXHasPrefixNoCase(cursor, sequence) &&
            (cursor[sequenceLength] == '\0' || cursor[sequenceLength] == '/')) {
            return YES;
        }
        while (*cursor && *cursor != '/') cursor++;
    }
    return NO;
}

static const char *const kPXJBArtifactExactBasenames[] = {
    "TLinkIOSTweak.dylib",
    "ProjectXTweak.dylib",
    "MobileSubstrate.dylib",
    "SubstrateLoader.dylib",
    "SubstrateBootstrap.dylib",
    "SubstrateInserter.dylib",
    "libsubstrate.dylib",
    "libellekit.dylib",
    "libinjector.dylib",
    "libhooker.dylib",
    "libsubstitute.dylib",
    "SubstituteLoader.dylib",
    "TweakInject.dylib",
    "RocketBootstrap.dylib",
    "libmryipc.dylib",
    "libblackjack.dylib",
    "AppList.dylib",
    "Cephei.dylib",
    "libcolorpicker.dylib",
    "libFLEX.dylib",
    "libactivator.dylib",
    "FridaGadget.dylib",
    "libFrida.dylib",
    "frida-agent.dylib",
    "libcycript.dylib",
    "Cycript.dylib",
    "SSLKillSwitch2.dylib",
    "Shadow.dylib",
    "Liberty.dylib",
    "vnodebypass.dylib",
    "UnSub.dylib",
    "A-Bypass.dylib",
    "Hestia.dylib",
    "Choicy.dylib",
    "KernBypass.dylib",
    "HideJB.dylib",
    "JailProtect.dylib",
    "DetectorDeter.dylib",
    "libjailbreak.dylib",
    "jailbreakd",
    "frida-server",
    NULL
};

static const char *const kPXJBArtifactBasenamePrefixes[] = {
    "FridaGadget-",
    "frida-agent-",
    NULL
};

static const char *const kPXJBArtifactExactComponents[] = {
    "MobileSubstrate",
    "TweakInject",
    "ellekit",
    "libhooker",
    "CydiaSubstrate.framework",
    "PreferenceLoader",
    "PreferenceBundles",
    NULL
};

static const char *const kPXJBArtifactAbsolutePrefixes[] = {
    "/usr/lib/substrate/",
    "/usr/lib/TweakInject/",
    "/usr/lib/ellekit/",
    "/usr/lib/substitute/",
    "/usr/lib/libhooker/",
    "/usr/lib/frida/",
    "/Library/MobileSubstrate/",
    "/private/var/Library/MobileSubstrate/",
    "/private/var/mobile/Library/MobileSubstrate/",
    "/Library/Frameworks/CydiaSubstrate.framework/",
    "/Library/PreferenceBundles/",
    "/Library/PreferenceLoader/",
    "/Library/Caches/cy-",
    "/private/var/Library/Caches/cy-",
    "/private/var/mobile/Library/Caches/cy-",
    "/var/jb/",
    "/private/var/jb/",
    NULL
};

static const char *const kPXJBArtifactRelativeExactSequences[] = {
    "var/jb",
    "private/var/jb",
    NULL
};

static const char *const kPXJBArtifactRelativeSequencePrefixes[] = {
    "usr/lib/substrate/",
    "usr/lib/TweakInject/",
    "usr/lib/ellekit/",
    "usr/lib/substitute/",
    "usr/lib/libhooker/",
    "usr/lib/frida/",
    "Library/MobileSubstrate/",
    "private/var/Library/MobileSubstrate/",
    "private/var/mobile/Library/MobileSubstrate/",
    "Library/Frameworks/CydiaSubstrate.framework/",
    "Library/PreferenceBundles/",
    "Library/PreferenceLoader/",
    "Library/Caches/cy-",
    "private/var/Library/Caches/cy-",
    "private/var/mobile/Library/Caches/cy-",
    "var/jb/",
    "private/var/jb/",
    NULL
};

static const char *const kPXJBPrivatePrebootExactComponents[] = {
    "jb",
    "procursus",
    "dopamine",
    "palera1n",
    NULL
};

static const char *const kPXJBPrivatePrebootComponentPrefixes[] = {
    "jb-",
    NULL
};

static BOOL PXJBPrivatePrebootPathShouldHide(const char *path) {
    if (!path || !path[0]) return NO;

    const char *descendants = NULL;
    static const char absolutePrefix[] = "/private/preboot";
    if (path[0] == '/') {
        size_t prefixLength = sizeof(absolutePrefix) - 1;
        if (!PXHasPrefixNoCase(path, absolutePrefix)) return NO;
        if (path[prefixLength] != '\0' && path[prefixLength] != '/') return NO;
        descendants = path + prefixLength;
    } else {
        static const char relativePrefix[] = "private/preboot";
        const char *cursor = path;
        while (*cursor) {
            while (*cursor == '/') cursor++;
            if (!*cursor) break;
            if (PXHasPrefixNoCase(cursor, relativePrefix)) {
                size_t prefixLength = sizeof(relativePrefix) - 1;
                if (cursor[prefixLength] == '\0' || cursor[prefixLength] == '/') {
                    descendants = cursor + prefixLength;
                    break;
                }
            }
            while (*cursor && *cursor != '/') cursor++;
        }
    }

    if (!descendants || !descendants[0]) return NO;
    return PXJBPathComponentMatchesAnyNoCase(descendants,
                                              kPXJBPrivatePrebootExactComponents,
                                              kPXJBPrivatePrebootComponentPrefixes);
}

static BOOL PXJBArtifactPathShouldMatch(const char *path) {
    if (!path || !path[0]) return NO;

    if (PXJBPathBasenameMatchesAnyNoCase(path,
                                         kPXJBArtifactExactBasenames,
                                         kPXJBArtifactBasenamePrefixes)) {
        return YES;
    }
    if (PXJBPathComponentMatchesAnyNoCase(path,
                                          kPXJBArtifactExactComponents,
                                          NULL)) {
        return YES;
    }
    if (PXJBPrivatePrebootPathShouldHide(path)) return YES;

    if (path[0] == '/') {
        for (size_t i = 0; kPXJBArtifactAbsolutePrefixes[i]; i++) {
            if (PXHasPrefixNoCase(path, kPXJBArtifactAbsolutePrefixes[i])) return YES;
        }
    } else {
        for (size_t i = 0; kPXJBArtifactRelativeExactSequences[i]; i++) {
            if (PXJBPathContainsComponentSequenceNoCase(
                    path,
                    kPXJBArtifactRelativeExactSequences[i])) {
                return YES;
            }
        }
        for (size_t i = 0; kPXJBArtifactRelativeSequencePrefixes[i]; i++) {
            if (PXJBPathContainsComponentSequencePrefixNoCase(
                    path,
                    kPXJBArtifactRelativeSequencePrefixes[i])) {
                return YES;
            }
        }
    }
    return NO;
}

// P0-C: process eligibility is computed once before hook installation and is
// never re-evaluated from a native hot path.
static _Atomic(bool) gJBProcessEligible = false;

typedef uint64_t PXJBPolicyMask;
enum {
    kPXJBPolicyMaster                     = 1ull << 0,
    kPXJBPolicyStatfs                     = 1ull << 1,
    kPXJBPolicyHideDylibs                 = 1ull << 2,
    kPXJBPolicyBlockDyldAddImageCallbacks = 1ull << 3,
    kPXJBPolicyHideTaskDyldInfo           = 1ull << 4,
    kPXJBPolicyHideDlIteratePhdr          = 1ull << 5,
    kPXJBPolicyBlockDlopenDlsymProbes     = 1ull << 6,
    kPXJBPolicySysctlProcSanitize         = 1ull << 7,
    kPXJBPolicyHideProcMaps               = 1ull << 8,
    kPXJBPolicyHideObjcImages             = 1ull << 9,
    kPXJBPolicyDebugLogging               = 1ull << 10,
    kPXJBPolicySCDebuggerScalar            = 1ull << 11,
};

static _Atomic(PXJBPolicyMask) gJBPolicyMask = 0;
static _Atomic(bool) gJBDyldNameHookReady = false;

// P1-A: requested settings are not capabilities. A policy bit becomes usable
// only after the install audit proves the corresponding hook/provider is ready.
typedef enum {
    kPXJBCapabilityCore = 0,
    kPXJBCapabilityStatfs,
    kPXJBCapabilityDyldIndexed,
    kPXJBCapabilityDyldAddImage,
    kPXJBCapabilityTaskDyldInfo,
    kPXJBCapabilityDlIteratePhdr,
    kPXJBCapabilityDlopenDlsym,
    kPXJBCapabilitySysctlSanitize,
    kPXJBCapabilityProcMaps,
    kPXJBCapabilityObjcImages,
    kPXJBCapabilityDebugLogging,
    kPXJBCapabilitySCDebuggerScalar,
    kPXJBCapabilityCount,
} PXJBCapabilityID;

typedef struct {
    const char *name;
    PXJBPolicyMask policyBit;
    bool requested;
    bool attempted;
    bool ready;
    uint16_t expectedSymbols;
    uint16_t installedSymbols;
    uint16_t requiredSymbols;
    uint16_t missingRequiredSymbols;
    const char *firstMissingRequiredSymbol;
    const char *failureReason;
} PXJBCapabilityRecord;

static PXJBCapabilityRecord gJBCapabilities[kPXJBCapabilityCount] = {
    { .name = "core",            .policyBit = kPXJBPolicyMaster },
    { .name = "statfs",          .policyBit = kPXJBPolicyStatfs },
    { .name = "dyld-indexed",    .policyBit = kPXJBPolicyHideDylibs },
    { .name = "dyld-add-image",  .policyBit = kPXJBPolicyBlockDyldAddImageCallbacks },
    { .name = "task-dyld-info",  .policyBit = kPXJBPolicyHideTaskDyldInfo },
    { .name = "dl-iterate-phdr", .policyBit = kPXJBPolicyHideDlIteratePhdr },
    { .name = "dlopen-dlsym",    .policyBit = kPXJBPolicyBlockDlopenDlsymProbes },
    { .name = "sysctl-sanitize", .policyBit = kPXJBPolicySysctlProcSanitize },
    { .name = "proc-maps",       .policyBit = kPXJBPolicyHideProcMaps },
    { .name = "objc-images",     .policyBit = kPXJBPolicyHideObjcImages },
    { .name = "debug-logging",   .policyBit = kPXJBPolicyDebugLogging },
    { .name = "sc-debugger",     .policyBit = kPXJBPolicySCDebuggerScalar },
};

static _Atomic(PXJBPolicyMask) gJBInstalledCapabilityMask = 0;
static _Atomic(bool) gJBCapabilityRegistryFinalized = false;
static bool gJBStatfsProviderRegistered = false;
static bool gJBMountSnapshotOwnerReady = false;
static bool gJBSysctlProviderRegistered = false;
static bool gJBSysctlBynameProviderRegistered = false;

static void PXJBPrepareCapabilityRegistry(PXJBPolicyMask requestedMask) {
    atomic_store_explicit(&gJBInstalledCapabilityMask, 0, memory_order_release);
    atomic_store_explicit(&gJBCapabilityRegistryFinalized, false, memory_order_release);
    for (uint32_t i = 0; i < kPXJBCapabilityCount; i++) {
        PXJBCapabilityRecord *record = &gJBCapabilities[i];
        record->requested = (requestedMask & record->policyBit) != 0;
        record->attempted = false;
        record->ready = false;
        record->expectedSymbols = 0;
        record->installedSymbols = 0;
        record->requiredSymbols = 0;
        record->missingRequiredSymbols = 0;
        record->firstMissingRequiredSymbol = NULL;
        record->failureReason = NULL;
    }
}

static void PXJBCapabilityAuditSymbol(PXJBCapabilityID capability,
                                      const char *symbol,
                                      bool installed,
                                      bool required) {
    if ((uint32_t)capability >= kPXJBCapabilityCount) return;
    PXJBCapabilityRecord *record = &gJBCapabilities[capability];
    record->attempted = record->attempted || record->requested;
    record->expectedSymbols++;
    if (required) record->requiredSymbols++;
    if (installed) {
        record->installedSymbols++;
        return;
    }
    if (required) {
        record->missingRequiredSymbols++;
        if (!record->firstMissingRequiredSymbol) {
            record->firstMissingRequiredSymbol = symbol;
        }
    }
}

static void PXJBCapabilitySetFailure(PXJBCapabilityID capability,
                                     const char *reason) {
    if ((uint32_t)capability >= kPXJBCapabilityCount) return;
    gJBCapabilities[capability].failureReason = reason;
}

static PXJBPolicyMask PXJBFinalizeCapabilityRegistryAndAudit(void);

static dispatch_queue_t gJBPolicyReloadQueue = NULL;
static dispatch_source_t gJBPolicyReloadTimer = NULL;

// P0-D: re-entry is tracked per domain. A nested filesystem call does not
// globally disable dyld/process filtering, and policy/logging I/O can bypass
// only filesystem interposition while those domains are active.
enum {
    kPXJBReentryFilesystem   = 1u << 0,
    kPXJBReentryDyldNames = 1u << 1,
    kPXJBReentryPolicyReload = 1u << 2,
    kPXJBReentryLogging      = 1u << 3,
    kPXJBReentryExec         = 1u << 4,
    kPXJBReentryHookInstall  = 1u << 5,
};

static __thread uint32_t gJBReentryDomains = 0;

typedef struct {
    uint32_t domain;
    bool entered;
} PXJBReentryScope;

static inline bool PXJBReentryDomainIsActive(uint32_t domains) {
    return (gJBReentryDomains & domains) != 0;
}

static inline uint64_t PXJBMonotonicNanoseconds(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) return 0;
    return ((uint64_t)ts.tv_sec * 1000000000ull) + (uint64_t)ts.tv_nsec;
}

static inline PXJBReentryScope PXJBEnterReentryDomain(uint32_t domain) {
    PXJBReentryScope scope = { domain, false };
    if ((gJBReentryDomains & domain) != 0) return scope;
    gJBReentryDomains |= domain;
    scope.entered = true;
    return scope;
}

static inline void PXJBLeaveReentryDomain(PXJBReentryScope *scope) {
    if (!scope || !scope->entered) return;
    gJBReentryDomains &= ~scope->domain;
    scope->entered = false;
}

#define PXJB_REENTRY_SCOPE(name, domainValue) \
    PXJBReentryScope name __attribute__((cleanup(PXJBLeaveReentryDomain))) = \
        PXJBEnterReentryDomain((domainValue))

static _Atomic(uint64_t) gJBDeferredBlockedEventCount = 0;
static void PXJBFlushDeferredDebugCounters(void);

static BOOL PXJBProcessIsEligibleAtLaunch(NSString *bundleID, NSString *processName) {
    if (![bundleID isKindOfClass:[NSString class]] || bundleID.length == 0) return NO;
    if (![processName isKindOfClass:[NSString class]] || processName.length == 0) return NO;

    if ([processName isEqualToString:@"launchd"] ||
        [processName isEqualToString:@"SpringBoard"] ||
        [processName isEqualToString:@"backboardd"]) {
        return NO;
    }
    if ([bundleID isEqualToString:@"com.hydra.tlinkios"] ||
        [bundleID hasPrefix:@"com.apple."]) {
        return NO;
    }
    return PXProcessIsAllowedForSpoofing(bundleID, processName, PXScopeOptionNone);
}

static NSDictionary *PXJBReadSecuritySettingsSnapshot(void) {
    static NSArray<NSString *> *paths = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        paths = @[
            @"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist",
            @"/private/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist"
        ];
    });

    for (NSString *path in paths) {
        NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:path];
        if ([settings isKindOfClass:[NSDictionary class]]) {
            return settings;
        }
    }

    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
    NSDictionary *fallback = [defaults dictionaryRepresentation];
    return [fallback isKindOfClass:[NSDictionary class]] ? fallback : @{};
}

static BOOL PXJBSettingEnabled(NSDictionary *settings, NSString *key) {
    id value = settings[key];
    return [value respondsToSelector:@selector(boolValue)] && [value boolValue];
}

static PXJBPolicyMask PXJBBuildRequestedPolicyMask(NSDictionary *settings) {
    if (!atomic_load_explicit(&gJBProcessEligible, memory_order_acquire)) return 0;
    if (!PXJBSettingEnabled(settings, @"jailbreakDetectionEnabled")) return 0;

    // C-01 is a framework-level scalar tied to the existing JB master. It is
    // requested automatically but only becomes effective after its own install
    // audit proves the runtime symbol/trampoline is available.
    PXJBPolicyMask mask = kPXJBPolicyMaster | kPXJBPolicySCDebuggerScalar;
    if (PXJBSettingEnabled(settings, @"jbBypassStatfsEnabled")) {
        mask |= kPXJBPolicyStatfs;
    }
    if (PXJBSettingEnabled(settings, @"jbBypassHideDylibsEnabled")) {
        mask |= kPXJBPolicyHideDylibs;
    }
    if (PXJBSettingEnabled(settings, @"jbBypassBlockDyldAddImageCallbacksEnabled")) {
        mask |= kPXJBPolicyBlockDyldAddImageCallbacks;
    }
    if (PXJBSettingEnabled(settings, @"jbBypassHideTaskDyldInfoEnabled")) {
        mask |= kPXJBPolicyHideTaskDyldInfo;
    }
    if (PXJBSettingEnabled(settings, @"jbBypassHideDlIteratePhdrEnabled")) {
        mask |= kPXJBPolicyHideDlIteratePhdr;
    }
    if (PXJBSettingEnabled(settings, @"jbBypassBlockDlopenDlsymProbesEnabled")) {
        mask |= kPXJBPolicyBlockDlopenDlsymProbes;
    }
    if (PXJBSettingEnabled(settings, @"jbBypassSysctlProcSanitizeEnabled")) {
        mask |= kPXJBPolicySysctlProcSanitize;
    }
    if (PXJBSettingEnabled(settings, @"jbBypassHideProcMapsEnabled")) {
        mask |= kPXJBPolicyHideProcMaps;
    }
    if (PXJBSettingEnabled(settings, @"jbBypassHideObjcImagesEnabled")) {
        mask |= kPXJBPolicyHideObjcImages;
    }
    if (PXJBSettingEnabled(settings, @"jbBypassDebugLoggingEnabled")) {
        mask |= kPXJBPolicyDebugLogging;
    }
    return mask;
}

static void PXJBPublishPolicySnapshot(NSDictionary *settings) {
    PXJBPolicyMask requested = PXJBBuildRequestedPolicyMask(settings ?: @{});
    PXJBPolicyMask installed = atomic_load_explicit(&gJBInstalledCapabilityMask,
                                                    memory_order_acquire);
    PXJBPolicyMask effective = requested & installed;
    atomic_store_explicit(&gJBPolicyMask, effective, memory_order_release);
}

static void PXJBReloadPolicySnapshot(void) {
    PXJB_REENTRY_SCOPE(policyScope, kPXJBReentryPolicyReload);
    if (!policyScope.entered) return;

    @autoreleasepool {
        PXJBPublishPolicySnapshot(PXJBReadSecuritySettingsSnapshot());
    }
}

static void PXJBStartPolicyReloadTimer(void) {
    if (gJBPolicyReloadTimer ||
        !atomic_load_explicit(&gJBProcessEligible, memory_order_acquire)) {
        return;
    }

    gJBPolicyReloadQueue = dispatch_queue_create("com.hydra.tlinkios.jb-policy", DISPATCH_QUEUE_SERIAL);
    gJBPolicyReloadTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, gJBPolicyReloadQueue);
    if (!gJBPolicyReloadTimer) return;

    dispatch_source_set_timer(gJBPolicyReloadTimer,
                              dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),
                              NSEC_PER_SEC,
                              100ull * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(gJBPolicyReloadTimer, ^{
        PXJBReloadPolicySnapshot();
        PXJBFlushDeferredDebugCounters();
    });
    dispatch_resume(gJBPolicyReloadTimer);
}

static inline PXJBPolicyMask PXJBPolicyLoad(void) {
    return atomic_load_explicit(&gJBPolicyMask, memory_order_acquire);
}

// Kept under the existing name to avoid touching every call site. It is now a
// constant-time atomic read and performs no Foundation, filesystem or scope work.
static BOOL PXJBShouldBypassCached(void) {
    if (!atomic_load_explicit(&gJBProcessEligible, memory_order_acquire)) return NO;
    return (PXJBPolicyLoad() & kPXJBPolicyMaster) != 0;
}

static inline BOOL PXJBFilesystemFilteringAllowed(void) {
    const uint32_t suppressDomains = kPXJBReentryFilesystem |
                                     kPXJBReentryDyldNames |
                                     kPXJBReentryPolicyReload |
                                     kPXJBReentryLogging |
                                     kPXJBReentryExec |
                                     kPXJBReentryHookInstall;
    return PXJBShouldBypassCached() && !PXJBReentryDomainIsActive(suppressDomains);
}

static inline BOOL PXJBExecFilteringAllowed(void) {
    const uint32_t suppressDomains = kPXJBReentryExec |
                                     kPXJBReentryPolicyReload |
                                     kPXJBReentryLogging |
                                     kPXJBReentryHookInstall;
    return PXJBShouldBypassCached() && !PXJBReentryDomainIsActive(suppressDomains);
}

#define PXJB_FILESYSTEM_HOOK_SCOPE() \
    BOOL pxjbFilterFilesystem = PXJBFilesystemFilteringAllowed(); \
    PXJB_REENTRY_SCOPE(pxjbFilesystemScope, kPXJBReentryFilesystem); \
    if (!pxjbFilesystemScope.entered) pxjbFilterFilesystem = NO

#define PXJB_EXEC_HOOK_SCOPE() \
    BOOL pxjbFilterExec = PXJBExecFilteringAllowed(); \
    PXJB_REENTRY_SCOPE(pxjbExecScope, kPXJBReentryExec); \
    if (!pxjbExecScope.entered) pxjbFilterExec = NO

static BOOL PXJBPolicyFeatureEnabled(PXJBPolicyMask feature) {
    if (!atomic_load_explicit(&gJBProcessEligible, memory_order_acquire)) return NO;
    PXJBPolicyMask mask = PXJBPolicyLoad();
    return (mask & (kPXJBPolicyMaster | feature)) == (kPXJBPolicyMaster | feature);
}

static BOOL PXJBStatfsBypassEnabled(void) {
    return PXJBPolicyFeatureEnabled(kPXJBPolicyStatfs);
}

static BOOL PXJBHideDylibsEnabled(void) {
    return PXJBPolicyFeatureEnabled(kPXJBPolicyHideDylibs) &&
           atomic_load_explicit(&gJBDyldNameHookReady, memory_order_acquire);
}

// Forward declaration (defined later in dyld section).
static BOOL PXStrContainsNoCase(const char *haystack, const char *needle);

static BOOL PXJBBlockDyldAddImageCallbacksEnabled(void) {
    return PXJBPolicyFeatureEnabled(kPXJBPolicyBlockDyldAddImageCallbacks);
}

static BOOL PXJBHideTaskDyldInfoEnabled(void) {
    return PXJBPolicyFeatureEnabled(kPXJBPolicyHideTaskDyldInfo);
}

static BOOL PXJBHideDlIteratePhdrEnabled(void) {
    return PXJBPolicyFeatureEnabled(kPXJBPolicyHideDlIteratePhdr);
}

static BOOL PXJBBlockDlopenDlsymProbesEnabled(void) {
    return PXJBPolicyFeatureEnabled(kPXJBPolicyBlockDlopenDlsymProbes);
}

static BOOL PXJBSysctlProcSanitizeEnabled(void) {
    return PXJBPolicyFeatureEnabled(kPXJBPolicySysctlProcSanitize);
}

static BOOL PXJBHideProcMapsEnabled(void) {
    return PXJBPolicyFeatureEnabled(kPXJBPolicyHideProcMaps);
}

static BOOL PXJBHideObjcImagesEnabled(void) {
    return PXJBPolicyFeatureEnabled(kPXJBPolicyHideObjcImages);
}

static BOOL PXJBDebugLoggingEnabled(void) {
    return PXJBPolicyFeatureEnabled(kPXJBPolicyDebugLogging);
}

static BOOL PXJBSCDebuggerScalarEnabled(void) {
    return PXJBPolicyFeatureEnabled(kPXJBPolicySCDebuggerScalar);
}

// Native hooks only record a counter. Formatting and Foundation logging are
// deferred to the policy queue so C hot paths perform no I/O or ObjC work.
static inline void PXJBRecordBlockedEvent(const char *what, const char *detail) {
    (void)what;
    (void)detail;
    if (!PXJBDebugLoggingEnabled()) return;
    atomic_fetch_add_explicit(&gJBDeferredBlockedEventCount, 1, memory_order_relaxed);
}

static void PXJBFlushDeferredDebugCounters(void) {
    PXJB_REENTRY_SCOPE(loggingScope, kPXJBReentryLogging);
    if (!loggingScope.entered) return;

    uint64_t count = atomic_exchange_explicit(&gJBDeferredBlockedEventCount,
                                              0,
                                              memory_order_acq_rel);
    if (!PXJBDebugLoggingEnabled() || count == 0) return;
    PXLog(@"[JailbreakBypass][debug] deferred blocked events=%llu",
          (unsigned long long)count);
}

// P2: immutable path matcher. Exact and prefix rules are inserted into one
// byte trie once, so the hot path performs O(path length) traversal instead of
// scanning every rule. Allocation failure preserves behavior through a cached-
// length linear fallback.
typedef struct {
    const char *bytes;
    uint16_t length;
} PXJBStaticPathRule;

#define PXJB_PATH_RULE(literal) { (literal), (uint16_t)(sizeof(literal) - 1) }

static const PXJBStaticPathRule kPXJBHiddenExactRules[] = {
    PXJB_PATH_RULE("/Applications/Cydia.app"),
    PXJB_PATH_RULE("/Applications/Sileo.app"),
    PXJB_PATH_RULE("/Applications/Zebra.app"),
    PXJB_PATH_RULE("/Applications/Filza.app"),
    PXJB_PATH_RULE("/Applications/Installer.app"),
    PXJB_PATH_RULE("/Applications/RockApp.app"),
    PXJB_PATH_RULE("/Applications/Icy.app"),
    PXJB_PATH_RULE("/Applications/WinterBoard.app"),
    PXJB_PATH_RULE("/Applications/SBSettings.app"),
    PXJB_PATH_RULE("/Applications/MxTube.app"),
    PXJB_PATH_RULE("/Applications/IntelliScreen.app"),
    PXJB_PATH_RULE("/Applications/FakeCarrier.app"),
    PXJB_PATH_RULE("/Applications/blackra1n.app"),
    PXJB_PATH_RULE("/Applications/Dopamine.app"),
    PXJB_PATH_RULE("/Applications/Th0r.app"),
    PXJB_PATH_RULE("/Applications/iFile.app"),
    PXJB_PATH_RULE("/Applications/Terminal.app"),
    PXJB_PATH_RULE("/Applications/NewTerm.app"),
    PXJB_PATH_RULE("/Library/MobileSubstrate/DynamicLibraries/0Cr4shed.dylib"),
    PXJB_PATH_RULE("/Library/MobileSubstrate/DynamicLibraries/libappstoreplus.dylib"),
    PXJB_PATH_RULE("/Library/MobileSubstrate/DynamicLibraries/ Crane.dylib"),
    PXJB_PATH_RULE("/Library/MobileSubstrate/DynamicLibraries/TLinkIOSTweak.dylib"),
    PXJB_PATH_RULE("/Library/MobileSubstrate/DynamicLibraries/ProjectXTweak.dylib"),
    PXJB_PATH_RULE("/Library/MobileSubstrate/DynamicLibraries/FilzaHack.dylib"),
    PXJB_PATH_RULE("/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist"),
    PXJB_PATH_RULE("/Library/MobileSubstrate/DynamicLibraries/Veency.plist"),
    PXJB_PATH_RULE("/Library/MobileSubstrate/MobileSubstrate.dylib"),
    PXJB_PATH_RULE("/Library/MobileSubstrate/DynamicLibraries"),
    PXJB_PATH_RULE("/Library/dpkg/info/mobilesubstrate.md5sums"),
    PXJB_PATH_RULE("/Library/dpkg/status"),
    PXJB_PATH_RULE("/private/var/binpack/Applications/loader.app"),
    PXJB_PATH_RULE("/usr/lib/substrate/SubstrateBootstrap.dylib"),
    PXJB_PATH_RULE("/usr/lib/substrate/SubstrateLoader.dylib"),
    PXJB_PATH_RULE("/usr/lib/substrate/SubstrateInserter.dylib"),
    PXJB_PATH_RULE("/usr/lib/libsubstrate.dylib"),
    PXJB_PATH_RULE("/usr/lib/libmryipc.dylib"),
    PXJB_PATH_RULE("/usr/lib/libFrida.dylib"),
    PXJB_PATH_RULE("/usr/lib/libcycript.dylib"),
    PXJB_PATH_RULE("/usr/lib/libjailbreak.dylib"),
    PXJB_PATH_RULE("/usr/lib/libhooker.dylib"),
    PXJB_PATH_RULE("/usr/lib/libsubstitute.dylib"),
    PXJB_PATH_RULE("/usr/lib/TweakInject.dylib"),
    PXJB_PATH_RULE("/usr/lib/ellekit/libinjector.dylib"),
    PXJB_PATH_RULE("/usr/lib/libellekit.dylib"),
    PXJB_PATH_RULE("/Library/Frameworks/CydiaSubstrate.framework"),
    PXJB_PATH_RULE("/Library/PreferenceBundles"),
    PXJB_PATH_RULE("/Library/PreferenceLoader"),
    PXJB_PATH_RULE("/usr/bin/ssh"),
    PXJB_PATH_RULE("/usr/bin/scp"),
    PXJB_PATH_RULE("/usr/bin/sftp"),
    PXJB_PATH_RULE("/usr/sbin/sshd"),
    PXJB_PATH_RULE("/bin/bash"),
    PXJB_PATH_RULE("/bin/sh"),
    PXJB_PATH_RULE("/bin/zsh"),
    PXJB_PATH_RULE("/usr/bin/cycript"),
    PXJB_PATH_RULE("/usr/bin/dpkg"),
    PXJB_PATH_RULE("/usr/bin/apt"),
    PXJB_PATH_RULE("/usr/bin/apt-get"),
    PXJB_PATH_RULE("/usr/libexec/cydia"),
    PXJB_PATH_RULE("/usr/libexec/sftp-server"),
    PXJB_PATH_RULE("/usr/libexec/ssh-keysign"),
    PXJB_PATH_RULE("/etc/apt"),
    PXJB_PATH_RULE("/private/etc/apt"),
    PXJB_PATH_RULE("/etc/ssh"),
    PXJB_PATH_RULE("/private/etc/ssh"),
    PXJB_PATH_RULE("/var/lib/apt"),
    PXJB_PATH_RULE("/var/lib/cydia"),
    PXJB_PATH_RULE("/var/cache/apt"),
    PXJB_PATH_RULE("/var/log/syslog"),
    PXJB_PATH_RULE("/var/tmp/cydia.log"),
    PXJB_PATH_RULE("/Library/dpkg"),
    PXJB_PATH_RULE("/private/var/binpack"),
    PXJB_PATH_RULE("/var/checkra1n.dmg"),
    PXJB_PATH_RULE("/var/binpack"),
    PXJB_PATH_RULE("/.bootstrapped_electra"),
    PXJB_PATH_RULE("/.cydia_no_stash"),
    PXJB_PATH_RULE("/.installed_unc0ver"),
    PXJB_PATH_RULE("/.installed_taurine"),
    PXJB_PATH_RULE("/.installed_odyssey"),
    PXJB_PATH_RULE("/.installed_chimera"),
    PXJB_PATH_RULE("/.installed_dopamine"),
    PXJB_PATH_RULE("/.installed_palera1n"),
    PXJB_PATH_RULE("/private/var/stash"),
    PXJB_PATH_RULE("/usr/sbin/frida-server"),
    PXJB_PATH_RULE("/usr/lib/frida/frida-agent.dylib"),
    PXJB_PATH_RULE("/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist"),
    PXJB_PATH_RULE("/System/Library/LaunchDaemons/com.ikey.bbot.plist"),
    PXJB_PATH_RULE("/private/jailbreak_test"),
    PXJB_PATH_RULE("/private/var/jailbreak_test"),
    PXJB_PATH_RULE("/var/jb"),
    PXJB_PATH_RULE("/var/jb/Applications"),
    PXJB_PATH_RULE("/var/jb/usr"),
    PXJB_PATH_RULE("/var/jb/Library"),
};
static const PXJBStaticPathRule kPXJBHiddenPrefixRules[] = {
    PXJB_PATH_RULE("/usr/lib/substrate/"),
    PXJB_PATH_RULE("/usr/lib/TweakInject/"),
    PXJB_PATH_RULE("/usr/lib/ellekit/"),
    PXJB_PATH_RULE("/usr/lib/substitute/"),
    PXJB_PATH_RULE("/usr/lib/libhooker/"),
    PXJB_PATH_RULE("/Library/MobileSubstrate/"),
    PXJB_PATH_RULE("/private/var/Library/MobileSubstrate/"),
    PXJB_PATH_RULE("/private/var/mobile/Library/MobileSubstrate/"),
    PXJB_PATH_RULE("/Library/Caches/cy-"),
    PXJB_PATH_RULE("/private/var/Library/Caches/cy-"),
    PXJB_PATH_RULE("/private/var/mobile/Library/Caches/cy-"),
    PXJB_PATH_RULE("/Library/Frameworks/CydiaSubstrate.framework/"),
    PXJB_PATH_RULE("/Library/PreferenceBundles/"),
    PXJB_PATH_RULE("/Library/PreferenceLoader/"),
    PXJB_PATH_RULE("/Library/dpkg/info/"),
    PXJB_PATH_RULE("/Library/Themes/"),
    PXJB_PATH_RULE("/Library/Ringtones/"),
    PXJB_PATH_RULE("/Library/Wallpaper/"),
    PXJB_PATH_RULE("/var/jb/"),
    PXJB_PATH_RULE("/private/var/jb/"),
    PXJB_PATH_RULE("/var/jb/Applications/"),
    PXJB_PATH_RULE("/var/jb/usr/"),
    PXJB_PATH_RULE("/var/jb/Library/"),
    PXJB_PATH_RULE("/var/jb/bin/"),
    PXJB_PATH_RULE("/var/jb/sbin/"),
    PXJB_PATH_RULE("/var/jb/etc/"),
    PXJB_PATH_RULE("/var/lib/apt/"),
    PXJB_PATH_RULE("/private/var/lib/apt/"),
    PXJB_PATH_RULE("/var/cache/apt/"),
    PXJB_PATH_RULE("/private/var/cache/apt/"),
    PXJB_PATH_RULE("/var/lib/dpkg/"),
    PXJB_PATH_RULE("/private/var/lib/dpkg/"),
    PXJB_PATH_RULE("/var/tmp/cydia"),
    PXJB_PATH_RULE("/private/var/tmp/cydia"),
    PXJB_PATH_RULE("/private/var/stash/"),
    PXJB_PATH_RULE("/var/stash/"),
    PXJB_PATH_RULE("/usr/lib/frida/"),
    PXJB_PATH_RULE("/var/jb/procursus/"),
    PXJB_PATH_RULE("/var/jb/usr/lib/ellekit/"),
    PXJB_PATH_RULE("/etc/apt/"),
    PXJB_PATH_RULE("/private/etc/apt/"),
    PXJB_PATH_RULE("/etc/ssh/"),
    PXJB_PATH_RULE("/private/etc/ssh/"),
    PXJB_PATH_RULE("/Library/dpkg/"),
    PXJB_PATH_RULE("/private/var/binpack/"),
    PXJB_PATH_RULE("/usr/libexec/cydia/"),
};
typedef enum {
    kPXJBPathTrieTerminalExact  = 1u << 0,
    kPXJBPathTrieTerminalPrefix = 1u << 1,
} PXJBPathTrieFlags;

typedef struct {
    uint32_t firstChild;
    uint32_t nextSibling;
    uint8_t byte;
    uint8_t flags;
} PXJBPathTrieNode;

#define PXJB_TRIE_NONE UINT32_MAX
#define PXJB_ARRAY_COUNT(array) (sizeof(array) / sizeof((array)[0]))

static pthread_once_t gJBPathMatcherOnce = PTHREAD_ONCE_INIT;
static PXJBPathTrieNode *gJBPathTrieNodes = NULL;
static uint32_t gJBPathTrieNodeCount = 0;
static uint32_t gJBPathTrieNodeCapacity = 0;
static _Atomic(bool) gJBPathMatcherReady = false;

static uint32_t PXJBPathTrieFindChild(uint32_t parent,
                                      uint8_t byte,
                                      BOOL create) {
    if (!gJBPathTrieNodes || parent >= gJBPathTrieNodeCount) return PXJB_TRIE_NONE;
    uint32_t child = gJBPathTrieNodes[parent].firstChild;
    while (child != PXJB_TRIE_NONE) {
        if (gJBPathTrieNodes[child].byte == byte) return child;
        child = gJBPathTrieNodes[child].nextSibling;
    }
    if (!create || gJBPathTrieNodeCount >= gJBPathTrieNodeCapacity) {
        return PXJB_TRIE_NONE;
    }

    uint32_t index = gJBPathTrieNodeCount++;
    PXJBPathTrieNode *node = &gJBPathTrieNodes[index];
    node->firstChild = PXJB_TRIE_NONE;
    node->nextSibling = gJBPathTrieNodes[parent].firstChild;
    node->byte = byte;
    node->flags = 0;
    gJBPathTrieNodes[parent].firstChild = index;
    return index;
}

static BOOL PXJBPathTrieInsertRule(const PXJBStaticPathRule *rule,
                                   uint8_t terminalFlag) {
    if (!rule || !rule->bytes || rule->length == 0) return NO;
    uint32_t node = 0;
    for (uint16_t i = 0; i < rule->length; i++) {
        node = PXJBPathTrieFindChild(node, (uint8_t)rule->bytes[i], YES);
        if (node == PXJB_TRIE_NONE) return NO;
    }
    gJBPathTrieNodes[node].flags |= terminalFlag;
    return YES;
}

static void PXJBInitializePathMatcher(void) {
    size_t capacity = 1;
    for (size_t i = 0; i < PXJB_ARRAY_COUNT(kPXJBHiddenExactRules); i++) {
        capacity += kPXJBHiddenExactRules[i].length;
    }
    for (size_t i = 0; i < PXJB_ARRAY_COUNT(kPXJBHiddenPrefixRules); i++) {
        capacity += kPXJBHiddenPrefixRules[i].length;
    }
    if (capacity > UINT32_MAX || capacity > SIZE_MAX / sizeof(PXJBPathTrieNode)) return;

    gJBPathTrieNodes = (PXJBPathTrieNode *)calloc(capacity,
                                                   sizeof(PXJBPathTrieNode));
    if (!gJBPathTrieNodes) return;
    gJBPathTrieNodeCapacity = (uint32_t)capacity;
    gJBPathTrieNodeCount = 1;
    gJBPathTrieNodes[0].firstChild = PXJB_TRIE_NONE;
    gJBPathTrieNodes[0].nextSibling = PXJB_TRIE_NONE;

    for (size_t i = 0; i < PXJB_ARRAY_COUNT(kPXJBHiddenExactRules); i++) {
        if (!PXJBPathTrieInsertRule(&kPXJBHiddenExactRules[i],
                                    kPXJBPathTrieTerminalExact)) {
            free(gJBPathTrieNodes);
            gJBPathTrieNodes = NULL;
            gJBPathTrieNodeCount = 0;
            gJBPathTrieNodeCapacity = 0;
            return;
        }
    }
    for (size_t i = 0; i < PXJB_ARRAY_COUNT(kPXJBHiddenPrefixRules); i++) {
        if (!PXJBPathTrieInsertRule(&kPXJBHiddenPrefixRules[i],
                                    kPXJBPathTrieTerminalPrefix)) {
            free(gJBPathTrieNodes);
            gJBPathTrieNodes = NULL;
            gJBPathTrieNodeCount = 0;
            gJBPathTrieNodeCapacity = 0;
            return;
        }
    }
    atomic_store_explicit(&gJBPathMatcherReady, true, memory_order_release);
}

static BOOL PXJBPathMatchesHiddenRulesLinear(const char *path) {
    size_t pathLength = strlen(path);
    for (size_t i = 0; i < PXJB_ARRAY_COUNT(kPXJBHiddenExactRules); i++) {
        const PXJBStaticPathRule *rule = &kPXJBHiddenExactRules[i];
        if (pathLength == rule->length &&
            memcmp(path, rule->bytes, rule->length) == 0) {
            return YES;
        }
    }
    for (size_t i = 0; i < PXJB_ARRAY_COUNT(kPXJBHiddenPrefixRules); i++) {
        const PXJBStaticPathRule *rule = &kPXJBHiddenPrefixRules[i];
        if (pathLength >= rule->length &&
            memcmp(path, rule->bytes, rule->length) == 0) {
            return YES;
        }
    }
    return NO;
}

static BOOL PXJBPathMatchesHiddenRulesTrie(const char *path) {
    uint32_t node = 0;
    for (const uint8_t *cursor = (const uint8_t *)path; *cursor; cursor++) {
        node = PXJBPathTrieFindChild(node, *cursor, NO);
        if (node == PXJB_TRIE_NONE) return NO;
        if ((gJBPathTrieNodes[node].flags & kPXJBPathTrieTerminalPrefix) != 0) {
            return YES;
        }
    }
    return (gJBPathTrieNodes[node].flags &
            (kPXJBPathTrieTerminalExact | kPXJBPathTrieTerminalPrefix)) != 0;
}

static BOOL PXJBPathMatcherIsReady(void) {
    pthread_once(&gJBPathMatcherOnce, PXJBInitializePathMatcher);
    return atomic_load_explicit(&gJBPathMatcherReady, memory_order_acquire);
}

static BOOL PXJBPathMatchesHiddenRules(const char *path) {
    if (!path || path[0] != '/') return NO;

    BOOL matched = PXJBPathMatcherIsReady()
        ? PXJBPathMatchesHiddenRulesTrie(path)
        : PXJBPathMatchesHiddenRulesLinear(path);
    if (matched) return YES;

    // /private/preboot is a normal iOS volume. Only hide descendants whose
    // component boundaries identify a jailbreak bootstrap/rootless subtree.
    return PXJBPrivatePrebootPathShouldHide(path);
}

#undef PXJB_PATH_RULE

static BOOL PXJBIsWriteAttempt(int flags) {
    if (flags & O_CREAT) return YES;
    if (flags & O_TRUNC) return YES;
    if ((flags & O_ACCMODE) == O_WRONLY) return YES;
    if ((flags & O_ACCMODE) == O_RDWR) return YES;
    return NO;
}

static BOOL PXJBIsSandboxAllowedWritePath(const char *path) {
    if (!path) return NO;
    // Allow normal sandbox container paths.
    if (PXHasPrefix(path, "/var/mobile/Containers/")) return YES;
    if (PXHasPrefix(path, "/private/var/mobile/Containers/")) return YES;
    if (PXHasPrefix(path, "/containers/Data/")) return YES;
    if (PXHasPrefix(path, "/private/var/containers/")) return YES;
    return NO;
}

static BOOL PXJBPathMatchesDenyWriteRules(const char *path, int flags) {
    if (!path) return NO;
    if (!PXJBIsWriteAttempt(flags)) return NO;
    // Only block classic jailbreak write-probe targets and obvious restricted prefixes.
    if (PXJBIsSandboxAllowedWritePath(path)) return NO;
    if (PXHasPrefix(path, "/private/jailbreak_test")) return YES;
    if (PXHasPrefix(path, "/private/var/jailbreak_test")) return YES;
    if (PXHasPrefix(path, "/var/tmp/cydia")) return YES;
    if (PXHasPrefix(path, "/private/var/tmp/cydia")) return YES;
    return NO;
}

// P1-B/B-00: one classifier owns path resolution and the hidden-path corpus;
// shared disposition/operation semantics live in PXP1CFilters.
static PXJBFilesystemDisposition PXJBClassifyFilesystemPathAt(int dirfd,
                                                               const char *path,
                                                               PXJBFilesystemOperation operation,
                                                               int flags,
                                                               char *resolvedPath,
                                                               size_t resolvedCapacity);
static int PXJBOriginalFcntlGetPath(int fd,
                                      char *path,
                                      size_t pathCapacity);
static PXJBFilesystemDisposition PXJBClassifyFileDescriptorPath(int fd);

static inline BOOL PXJBFilesystemDispositionIsHidden(PXJBFilesystemDisposition disposition) {
    return PXP1CJBDispositionIsHidden(disposition);
}

static inline BOOL PXJBFilesystemDispositionBlocksWrite(PXJBFilesystemDisposition disposition) {
    return PXP1CJBDispositionBlocksWrite(disposition);
}

static inline int PXJBFilesystemErrno(PXJBFilesystemDisposition disposition) {
    return PXP1CJBErrnoForDisposition(disposition);
}

// Compatibility helpers keep ObjC hook call sites on the classifier while the
// native hooks below consume the full four-state result directly.
static BOOL PXJBPathShouldHide(const char *path) {
    return PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                        path,
                                        kPXJBFilesystemOperationRead,
                                        O_RDONLY,
                                        NULL,
                                        0) == kPXJBFilesystemHide;
}

static BOOL PXJBPathShouldBlockWrite(const char *path) {
    PXJBFilesystemDisposition disposition =
        PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                     path,
                                     kPXJBFilesystemOperationWrite,
                                     O_WRONLY | O_CREAT,
                                     NULL,
                                     0);
    return PXJBFilesystemDispositionBlocksWrite(disposition);
}

// Loopback port scan blocking
static BOOL PXJBIsDeniedLoopbackPort(uint16_t port) {
    switch (port) {
        case 22:      // ssh
        case 44:      // historically used by some detectors
        case 27042:   // frida
        case 4444:
        case 5555:
            return YES;
        default:
            return NO;
    }
}

// --- C hooks ---
static int (*orig_stat)(const char *, struct stat *);
static int hook_stat(const char *path, struct stat *st) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemDisposition disposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         path,
                                         kPXJBFilesystemOperationRead,
                                         O_RDONLY,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionIsHidden(disposition)) {
            errno = ENOENT;
            return -1;
        }
    }
    return orig_stat ? orig_stat(path, st) : -1;
}

static int (*orig_stat64)(const char *, struct stat *);
static int hook_stat64(const char *path, struct stat *st) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemDisposition disposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         path,
                                         kPXJBFilesystemOperationRead,
                                         O_RDONLY,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionIsHidden(disposition)) {
            errno = ENOENT;
            return -1;
        }
    }
    return orig_stat64 ? orig_stat64(path, st) : -1;
}

static int (*orig_lstat)(const char *, struct stat *);
static int hook_lstat(const char *path, struct stat *st) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemDisposition disposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         path,
                                         kPXJBFilesystemOperationRead,
                                         O_RDONLY,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionIsHidden(disposition)) {
            errno = ENOENT;
            return -1;
        }
    }
    return orig_lstat ? orig_lstat(path, st) : -1;
}

static int (*orig_lstat64)(const char *, struct stat *);
static int hook_lstat64(const char *path, struct stat *st) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemDisposition disposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         path,
                                         kPXJBFilesystemOperationRead,
                                         O_RDONLY,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionIsHidden(disposition)) {
            errno = ENOENT;
            return -1;
        }
    }
    return orig_lstat64 ? orig_lstat64(path, st) : -1;
}

static int (*orig_access)(const char *, int);
static int hook_access(const char *path, int amode) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemDisposition disposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         path,
                                         kPXJBFilesystemOperationRead,
                                         O_RDONLY,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionIsHidden(disposition)) {
            errno = ENOENT;
            return -1;
        }
    }
    return orig_access ? orig_access(path, amode) : -1;
}

static int (*orig_open)(const char *, int, ...);
static int hook_open(const char *path, int oflag, ...) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemOperation operation = PXJBIsWriteAttempt(oflag)
            ? kPXJBFilesystemOperationWrite
            : kPXJBFilesystemOperationRead;
        PXJBFilesystemDisposition disposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         path,
                                         operation,
                                         oflag,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionIsHidden(disposition) ||
            disposition == kPXJBFilesystemDenyWrite) {
            errno = PXJBFilesystemErrno(disposition);
            return -1;
        }
    }

    int mode = 0;
    if (oflag & O_CREAT) {
        va_list ap;
        va_start(ap, oflag);
        mode = va_arg(ap, int);
        va_end(ap);
    }
    return orig_open ? orig_open(path, oflag, mode) : -1;
}

static int (*orig_openat)(int, const char *, int, ...);

static BOOL PXJBRelativePathLooksLikeProbe(const char *path) {
    if (!path || !path[0] || path[0] == '/') return NO;
    // Resolution failure is uncertain. Only retain high-confidence matches
    // with basename/component/prefix boundaries; otherwise fail open.
    return PXJBArtifactPathShouldMatch(path);
}

static BOOL PXJBNormalizeAbsolutePath(const char *inPath, char *out, size_t outsz) {
    return PXP1CJBNormalizeAbsolutePath(inPath, out, outsz);
}

static BOOL PXJBJoinCwdAndNormalize(const char *relPath, char *out, size_t outsz) {
    if (!relPath || !out || outsz < 2) return NO;
    char cwd[PATH_MAX];
    if (!getcwd(cwd, sizeof(cwd))) return NO;
    size_t cwdLen = strlen(cwd);
    size_t relLen = strlen(relPath);
    if (cwdLen == 0 || cwd[0] != '/') return NO;

    char tmp[PATH_MAX];
    size_t need = cwdLen + 1 + relLen + 1;
    if (need >= sizeof(tmp)) return NO;
    memcpy(tmp, cwd, cwdLen);
    tmp[cwdLen] = '/';
    memcpy(tmp + cwdLen + 1, relPath, relLen);
    tmp[cwdLen + 1 + relLen] = '\0';
    return PXJBNormalizeAbsolutePath(tmp, out, outsz);
}

static int hook_openat(int fd, const char *path, int oflag, ...) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        char resolvedPath[PATH_MAX];
        PXJBFilesystemOperation operation = PXJBIsWriteAttempt(oflag)
            ? kPXJBFilesystemOperationWrite
            : kPXJBFilesystemOperationRead;
        PXJBFilesystemDisposition disposition =
            PXJBClassifyFilesystemPathAt(fd,
                                         path,
                                         operation,
                                         oflag,
                                         resolvedPath,
                                         sizeof(resolvedPath));
        if (PXJBFilesystemDispositionIsHidden(disposition) ||
            disposition == kPXJBFilesystemDenyWrite) {
            PXJBRecordBlockedEvent(disposition == kPXJBFilesystemDenyWrite
                                       ? "openat(write)"
                                       : "openat",
                                   resolvedPath[0] ? resolvedPath : path);
            errno = PXJBFilesystemErrno(disposition);
            return -1;
        }
        // UNRESOLVED deliberately fails open unless the lexical relative path
        // was strong enough for the classifier to return HIDE/DENY_WRITE.
    }

    int mode = 0;
    if (oflag & O_CREAT) {
        va_list ap;
        va_start(ap, oflag);
        mode = va_arg(ap, int);
        va_end(ap);
    }
    return orig_openat ? orig_openat(fd, path, oflag, mode) : -1;
}

static FILE *(*orig_fopen)(const char *, const char *);
static FILE *hook_fopen(const char *path, const char *mode) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        BOOL writeIntent = mode &&
                           (strchr(mode, 'w') || strchr(mode, 'a') || strchr(mode, '+'));
        int flags = writeIntent ? (O_WRONLY | O_CREAT) : O_RDONLY;
        PXJBFilesystemDisposition disposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         path,
                                         writeIntent
                                             ? kPXJBFilesystemOperationWrite
                                             : kPXJBFilesystemOperationRead,
                                         flags,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionIsHidden(disposition) ||
            disposition == kPXJBFilesystemDenyWrite) {
            errno = PXJBFilesystemErrno(disposition);
            return NULL;
        }
    }
    return orig_fopen ? orig_fopen(path, mode) : NULL;
}

// P2: directory stream lifecycle. A DIR* is associated with the normalized
// parent path from opendir/fdopendir until closedir. readdir can therefore
// classify the full child path instead of applying basename rules globally.
typedef DIR *(*PXJBOpendirFunction)(const char *);
typedef DIR *(*PXJBOpenDir2Function)(const char *, int);
typedef DIR *(*PXJBFdopendirFunction)(int);
typedef struct dirent *(*PXJBReaddirFunction)(DIR *);
typedef int (*PXJBReaddirRFunction)(DIR *, struct dirent *, struct dirent **);
typedef int (*PXJBClosedirFunction)(DIR *);

typedef struct PXJBDirectoryStreamRecord {
    DIR *stream;
    uint64_t generation;
    char parentPath[PATH_MAX];
    struct PXJBDirectoryStreamRecord *next;
} PXJBDirectoryStreamRecord;

#define PXJB_DIRECTORY_BUCKET_COUNT 64u
_Static_assert((PXJB_DIRECTORY_BUCKET_COUNT & (PXJB_DIRECTORY_BUCKET_COUNT - 1u)) == 0,
               "directory bucket count must be a power of two");

static PXJBOpendirFunction orig_opendir = NULL;
static PXJBOpendirFunction gJBOpendirEntry = NULL;
static PXJBOpenDir2Function orig___opendir2 = NULL;
static PXJBOpenDir2Function gJBOpenDir2Entry = NULL;
static PXJBFdopendirFunction orig_fdopendir = NULL;
static PXJBFdopendirFunction gJBFdopendirEntry = NULL;
static PXJBReaddirFunction orig_readdir = NULL;
static PXJBReaddirFunction gJBReaddirEntry = NULL;
static PXJBReaddirRFunction orig_readdir_r = NULL;
static PXJBReaddirRFunction gJBReaddirREntry = NULL;
static PXJBClosedirFunction orig_closedir = NULL;
static PXJBClosedirFunction gJBClosedirEntry = NULL;
static _Atomic(bool) gJBDirectoryLifecycleReady = false;
static _Atomic(uint64_t) gJBDirectoryGeneration = 1;
static pthread_mutex_t gJBDirectoryRegistryLock = PTHREAD_MUTEX_INITIALIZER;
static PXJBDirectoryStreamRecord *gJBDirectoryBuckets[PXJB_DIRECTORY_BUCKET_COUNT];

static size_t PXJBDirectoryBucketIndex(DIR *stream) {
    uintptr_t value = (uintptr_t)stream;
    value ^= value >> 17;
    value ^= value >> 9;
    return (size_t)(value & (PXJB_DIRECTORY_BUCKET_COUNT - 1u));
}

static void PXJBFreeDirectoryStreamRecord(PXJBDirectoryStreamRecord *record) {
    if (!record) return;
    memset(record, 0, sizeof(*record));
    free(record);
}

static PXJBDirectoryStreamRecord *PXJBDetachDirectoryStream(DIR *stream) {
    if (!stream) return NULL;
    size_t bucket = PXJBDirectoryBucketIndex(stream);
    pthread_mutex_lock(&gJBDirectoryRegistryLock);
    PXJBDirectoryStreamRecord **cursor = &gJBDirectoryBuckets[bucket];
    while (*cursor && (*cursor)->stream != stream) cursor = &(*cursor)->next;
    PXJBDirectoryStreamRecord *record = *cursor;
    if (record) {
        *cursor = record->next;
        record->next = NULL;
    }
    pthread_mutex_unlock(&gJBDirectoryRegistryLock);
    return record;
}

static BOOL PXJBRestoreDirectoryStream(PXJBDirectoryStreamRecord *record) {
    if (!record || !record->stream) return NO;
    size_t bucket = PXJBDirectoryBucketIndex(record->stream);
    BOOL restored = NO;
    pthread_mutex_lock(&gJBDirectoryRegistryLock);
    PXJBDirectoryStreamRecord *cursor = gJBDirectoryBuckets[bucket];
    while (cursor && cursor->stream != record->stream) cursor = cursor->next;
    if (!cursor) {
        record->next = gJBDirectoryBuckets[bucket];
        gJBDirectoryBuckets[bucket] = record;
        restored = YES;
    }
    pthread_mutex_unlock(&gJBDirectoryRegistryLock);
    return restored;
}

static BOOL PXJBRegisterDirectoryStream(DIR *stream, const char *parentPath) {
    if (!stream || !parentPath || parentPath[0] != '/') return NO;
    size_t pathLength = strlen(parentPath);
    if (pathLength == 0 || pathLength >= PATH_MAX) return NO;

    PXJBDirectoryStreamRecord *record =
        (PXJBDirectoryStreamRecord *)calloc(1, sizeof(*record));
    if (!record) return NO;
    record->stream = stream;
    record->generation = atomic_fetch_add_explicit(&gJBDirectoryGeneration,
                                                    1,
                                                    memory_order_relaxed);
    memcpy(record->parentPath, parentPath, pathLength + 1);

    size_t bucket = PXJBDirectoryBucketIndex(stream);
    PXJBDirectoryStreamRecord *replaced = NULL;
    pthread_mutex_lock(&gJBDirectoryRegistryLock);
    PXJBDirectoryStreamRecord **cursor = &gJBDirectoryBuckets[bucket];
    while (*cursor && (*cursor)->stream != stream) cursor = &(*cursor)->next;
    if (*cursor) {
        replaced = *cursor;
        *cursor = replaced->next;
        replaced->next = NULL;
    }
    record->next = gJBDirectoryBuckets[bucket];
    gJBDirectoryBuckets[bucket] = record;
    pthread_mutex_unlock(&gJBDirectoryRegistryLock);
    PXJBFreeDirectoryStreamRecord(replaced);
    return YES;
}

static BOOL PXJBCopyDirectoryStreamPath(DIR *stream,
                                        char *outPath,
                                        size_t outCapacity,
                                        uint64_t *outGeneration) {
    if (!stream || !outPath || outCapacity < 2) return NO;
    BOOL found = NO;
    size_t bucket = PXJBDirectoryBucketIndex(stream);
    pthread_mutex_lock(&gJBDirectoryRegistryLock);
    PXJBDirectoryStreamRecord *record = gJBDirectoryBuckets[bucket];
    while (record && record->stream != stream) record = record->next;
    if (record) {
        size_t length = strlen(record->parentPath);
        if (length + 1 <= outCapacity) {
            memcpy(outPath, record->parentPath, length + 1);
            if (outGeneration) *outGeneration = record->generation;
            found = YES;
        }
    }
    pthread_mutex_unlock(&gJBDirectoryRegistryLock);
    return found;
}

static DIR *PXJBOriginalOpendir(const char *path) {
    PXJBOpendirFunction function = orig_opendir;
    if (!function || function == gJBOpendirEntry) {
        errno = ENOSYS;
        return NULL;
    }
    return function(path);
}

static DIR *PXJBOriginalOpenDir2(const char *path, int flags) {
    PXJBOpenDir2Function function = orig___opendir2;
    if (!function || function == gJBOpenDir2Entry) {
        errno = ENOSYS;
        return NULL;
    }
    return function(path, flags);
}

static DIR *PXJBOriginalFdopendir(int fd) {
    PXJBFdopendirFunction function = orig_fdopendir;
    if (!function || function == gJBFdopendirEntry) {
        errno = ENOSYS;
        return NULL;
    }
    return function(fd);
}

static struct dirent *PXJBOriginalReaddir(DIR *stream) {
    PXJBReaddirFunction function = orig_readdir;
    if (!function || function == gJBReaddirEntry) {
        errno = ENOSYS;
        return NULL;
    }
    return function(stream);
}

static int PXJBOriginalReaddirR(DIR *stream,
                                struct dirent *entry,
                                struct dirent **result) {
    PXJBReaddirRFunction function = orig_readdir_r;
    if (!function || function == gJBReaddirREntry) return ENOSYS;
    return function(stream, entry, result);
}

static int PXJBOriginalClosedir(DIR *stream) {
    PXJBClosedirFunction function = orig_closedir;
    if (!function || function == gJBClosedirEntry) {
        errno = ENOSYS;
        return -1;
    }
    return function(stream);
}

static BOOL PXJBJoinDirectoryEntryPath(const char *parentPath,
                                       const char *entryName,
                                       char *outPath,
                                       size_t outCapacity) {
    if (!parentPath || parentPath[0] != '/' ||
        !entryName || !entryName[0] || strchr(entryName, '/') != NULL ||
        !outPath || outCapacity < 2) {
        return NO;
    }
    size_t parentLength = strlen(parentPath);
    size_t entryLength = strlen(entryName);
    BOOL parentIsRoot = parentLength == 1 && parentPath[0] == '/';
    size_t required = parentLength + (parentIsRoot ? 0 : 1) + entryLength + 1;
    if (required > outCapacity) return NO;

    memcpy(outPath, parentPath, parentLength);
    size_t cursor = parentLength;
    if (!parentIsRoot) outPath[cursor++] = '/';
    memcpy(outPath + cursor, entryName, entryLength + 1);
    return YES;
}

static BOOL PXJBUntrackedDirectoryEntryShouldHide(const char *entryName) {
    if (!entryName) return NO;
    static const char *const highConfidenceNames[] = {
        "Cydia.app",
        "Sileo.app",
        "Zebra.app",
        "Filza.app",
        NULL
    };
    for (size_t i = 0; highConfidenceNames[i]; i++) {
        if (PXStrEqNoCase(entryName, highConfidenceNames[i])) return YES;
    }
    return NO;
}

static BOOL PXJBDirectoryParentUsesAppNameRules(const char *parentPath) {
    if (!parentPath) return NO;
    return strcmp(parentPath, "/Applications") == 0 ||
           strcmp(parentPath, "/var/jb/Applications") == 0;
}

static BOOL PXJBDirectoryEntryShouldHide(const char *parentPath,
                                         const char *entryName) {
    if (!entryName || !entryName[0] ||
        strcmp(entryName, ".") == 0 || strcmp(entryName, "..") == 0) {
        return NO;
    }
    if (!parentPath || parentPath[0] != '/') {
        return PXJBUntrackedDirectoryEntryShouldHide(entryName);
    }

    char childPath[PATH_MAX];
    if (!PXJBJoinDirectoryEntryPath(parentPath,
                                    entryName,
                                    childPath,
                                    sizeof(childPath))) {
        return NO;
    }
    if (PXJBPathMatchesHiddenRules(childPath)) return YES;
    return PXJBDirectoryParentUsesAppNameRules(parentPath) &&
           PXJBUntrackedDirectoryEntryShouldHide(entryName);
}

static DIR *hook_opendir(const char *path) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    BOOL lifecycleReady = atomic_load_explicit(&gJBDirectoryLifecycleReady,
                                                memory_order_acquire);
    BOOL collectContext = lifecycleReady && pxjbFilesystemScope.entered;
    char resolvedPath[PATH_MAX];
    resolvedPath[0] = '\0';
    PXJBFilesystemDisposition disposition = kPXJBFilesystemUnresolved;
    if (pxjbFilterFilesystem || collectContext) {
        disposition = PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                                    path,
                                                    kPXJBFilesystemOperationRead,
                                                    O_RDONLY,
                                                    resolvedPath,
                                                    sizeof(resolvedPath));
    }
    if (pxjbFilterFilesystem && PXJBFilesystemDispositionIsHidden(disposition)) {
        errno = ENOENT;
        return NULL;
    }

    DIR *stream = PXJBOriginalOpendir(path);
    if (stream && collectContext && resolvedPath[0] == '/') {
        int savedErrno = errno;
        (void)PXJBRegisterDirectoryStream(stream, resolvedPath);
        errno = savedErrno;
    }
    return stream;
}

static DIR *hook___opendir2(const char *path, int flags) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    BOOL lifecycleReady = atomic_load_explicit(&gJBDirectoryLifecycleReady,
                                                memory_order_acquire);
    BOOL collectContext = lifecycleReady && pxjbFilesystemScope.entered;
    char resolvedPath[PATH_MAX];
    resolvedPath[0] = '\0';
    PXJBFilesystemDisposition disposition = kPXJBFilesystemUnresolved;
    if (pxjbFilterFilesystem || collectContext) {
        disposition = PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                                    path,
                                                    kPXJBFilesystemOperationRead,
                                                    O_RDONLY,
                                                    resolvedPath,
                                                    sizeof(resolvedPath));
    }
    if (pxjbFilterFilesystem && PXJBFilesystemDispositionIsHidden(disposition)) {
        errno = ENOENT;
        return NULL;
    }

    DIR *stream = PXJBOriginalOpenDir2(path, flags);
    if (stream && collectContext && resolvedPath[0] == '/') {
        int savedErrno = errno;
        (void)PXJBRegisterDirectoryStream(stream, resolvedPath);
        errno = savedErrno;
    }
    return stream;
}

static DIR *hook_fdopendir(int fd) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    BOOL lifecycleReady = atomic_load_explicit(&gJBDirectoryLifecycleReady,
                                                memory_order_acquire);
    BOOL collectContext = lifecycleReady && pxjbFilesystemScope.entered;
    char resolvedPath[PATH_MAX];
    resolvedPath[0] = '\0';
    if ((pxjbFilterFilesystem || collectContext) && fd >= 0) {
        char fdPath[PATH_MAX];
        if (PXJBOriginalFcntlGetPath(fd, fdPath, sizeof(fdPath)) != -1) {
            (void)PXJBNormalizeAbsolutePath(fdPath,
                                            resolvedPath,
                                            sizeof(resolvedPath));
        }
    }
    if (pxjbFilterFilesystem && resolvedPath[0] == '/' &&
        PXJBPathMatchesHiddenRules(resolvedPath)) {
        errno = ENOENT;
        return NULL;
    }

    DIR *stream = PXJBOriginalFdopendir(fd);
    if (stream && collectContext && resolvedPath[0] == '/') {
        int savedErrno = errno;
        (void)PXJBRegisterDirectoryStream(stream, resolvedPath);
        errno = savedErrno;
    }
    return stream;
}

static struct dirent *hook_readdir(DIR *dirp) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    BOOL lifecycleReady = atomic_load_explicit(&gJBDirectoryLifecycleReady,
                                                memory_order_acquire);
    if (!pxjbFilterFilesystem || !lifecycleReady) {
        return PXJBOriginalReaddir(dirp);
    }

    char parentPath[PATH_MAX];
    BOOL tracked = PXJBCopyDirectoryStreamPath(dirp,
                                               parentPath,
                                               sizeof(parentPath),
                                               NULL);
    for (;;) {
        struct dirent *entry = PXJBOriginalReaddir(dirp);
        if (!entry) return NULL;
        if (!PXJBDirectoryEntryShouldHide(tracked ? parentPath : NULL,
                                          entry->d_name)) {
            return entry;
        }
        PXJBRecordBlockedEvent("readdir", entry->d_name);
    }
}

static int hook_readdir_r(DIR *dirp,
                          struct dirent *entry,
                          struct dirent **result) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    BOOL lifecycleReady = atomic_load_explicit(&gJBDirectoryLifecycleReady,
                                                memory_order_acquire);
    if (!entry || !result || !pxjbFilterFilesystem || !lifecycleReady) {
        return PXJBOriginalReaddirR(dirp, entry, result);
    }

    char parentPath[PATH_MAX];
    BOOL tracked = PXJBCopyDirectoryStreamPath(dirp,
                                               parentPath,
                                               sizeof(parentPath),
                                               NULL);
    for (;;) {
        struct dirent *candidate = NULL;
        int status = PXJBOriginalReaddirR(dirp, entry, &candidate);
        int savedErrno = errno;
        if (status != 0 || !candidate) {
            *result = candidate;
            errno = savedErrno;
            return status;
        }
        if (!PXJBDirectoryEntryShouldHide(tracked ? parentPath : NULL,
                                          candidate->d_name)) {
            *result = candidate;
            errno = savedErrno;
            return 0;
        }
        PXJBRecordBlockedEvent("readdir_r", candidate->d_name);
        errno = savedErrno;
    }
}

static int hook_closedir(DIR *dirp) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    PXJBDirectoryStreamRecord *detached = PXJBDetachDirectoryStream(dirp);
    int result = PXJBOriginalClosedir(dirp);
    int savedErrno = errno;
    if (result == 0) {
        PXJBFreeDirectoryStreamRecord(detached);
    } else if (detached && !PXJBRestoreDirectoryStream(detached)) {
        PXJBFreeDirectoryStreamRecord(detached);
    }
    errno = savedErrno;
    return result;
}

static ssize_t (*orig_readlink)(const char *, char *, size_t);
static ssize_t hook_readlink(const char *path, char *buf, size_t bufsiz) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemDisposition disposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         path,
                                         kPXJBFilesystemOperationRead,
                                         O_RDONLY,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionIsHidden(disposition)) {
            errno = ENOENT;
            return -1;
        }
    }
    return orig_readlink ? orig_readlink(path, buf, bufsiz) : -1;
}

static char *(*orig_realpath)(const char *, char *);
static char *hook_realpath(const char *path, char *resolved) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemDisposition disposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         path,
                                         kPXJBFilesystemOperationRead,
                                         O_RDONLY,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionIsHidden(disposition)) {
            errno = ENOENT;
            return NULL;
        }
    }
    return orig_realpath ? orig_realpath(path, resolved) : NULL;
}

// B-02: read-only native metadata/query parity. These wrappers never rewrite
// caller buffers or lengths; allowed/unresolved requests are forwarded exactly,
// preserving libc's sizing probes, option handling and errno behavior.
static BOOL PXJBRejectHiddenPathReadQuery(const char *path,
                                          PXJBHiddenReadErrnoPolicy errnoPolicy) {
    int incomingErrno = errno;
    PXJBFilesystemDisposition disposition =
        PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                     path,
                                     kPXJBFilesystemOperationRead,
                                     O_RDONLY,
                                     NULL,
                                     0);
    if (!PXJBFilesystemDispositionIsHidden(disposition)) {
        errno = incomingErrno;
        return NO;
    }
    errno = PXP1CJBErrnoForHiddenRead(errnoPolicy);
    return YES;
}

static BOOL PXJBRejectHiddenFDReadQuery(int fd,
                                        PXJBHiddenReadErrnoPolicy errnoPolicy) {
    int incomingErrno = errno;
    PXJBFilesystemDisposition disposition = PXJBClassifyFileDescriptorPath(fd);
    if (!PXJBFilesystemDispositionIsHidden(disposition)) {
        errno = incomingErrno;
        return NO;
    }
    errno = PXP1CJBErrnoForHiddenRead(errnoPolicy);
    return YES;
}

static long (*orig_pathconf)(const char *, int);
static long hook_pathconf(const char *path, int name) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem &&
        PXJBRejectHiddenPathReadQuery(path, kPXJBHiddenReadErrnoPathNotFound)) {
        return -1L;
    }
    return orig_pathconf ? orig_pathconf(path, name) : -1L;
}

static long (*orig_fpathconf)(int, int);
static long hook_fpathconf(int fd, int name) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem &&
        PXJBRejectHiddenFDReadQuery(fd, kPXJBHiddenReadErrnoBadFileDescriptor)) {
        return -1L;
    }
    return orig_fpathconf ? orig_fpathconf(fd, name) : -1L;
}

static int (*orig_getattrlist)(const char *, struct attrlist *, void *, size_t, unsigned long);
static int hook_getattrlist(const char *path,
                            struct attrlist *attrList,
                            void *attrBuf,
                            size_t attrBufSize,
                            unsigned long options) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem &&
        PXJBRejectHiddenPathReadQuery(path, kPXJBHiddenReadErrnoPathNotFound)) {
        return -1;
    }
    return orig_getattrlist
        ? orig_getattrlist(path, attrList, attrBuf, attrBufSize, options)
        : -1;
}

static int (*orig_fgetattrlist)(int, struct attrlist *, void *, size_t, unsigned long);
static int hook_fgetattrlist(int fd,
                             struct attrlist *attrList,
                             void *attrBuf,
                             size_t attrBufSize,
                             unsigned long options) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem &&
        PXJBRejectHiddenFDReadQuery(fd, kPXJBHiddenReadErrnoBadFileDescriptor)) {
        return -1;
    }
    return orig_fgetattrlist
        ? orig_fgetattrlist(fd, attrList, attrBuf, attrBufSize, options)
        : -1;
}

static ssize_t (*orig_getxattr)(const char *, const char *, void *, size_t, uint32_t, int);
static ssize_t hook_getxattr(const char *path,
                             const char *name,
                             void *value,
                             size_t size,
                             uint32_t position,
                             int options) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem &&
        PXJBRejectHiddenPathReadQuery(path, kPXJBHiddenReadErrnoPathNotFound)) {
        return -1;
    }
    return orig_getxattr
        ? orig_getxattr(path, name, value, size, position, options)
        : -1;
}

static ssize_t (*orig_fgetxattr)(int, const char *, void *, size_t, uint32_t, int);
static ssize_t hook_fgetxattr(int fd,
                              const char *name,
                              void *value,
                              size_t size,
                              uint32_t position,
                              int options) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem &&
        PXJBRejectHiddenFDReadQuery(fd, kPXJBHiddenReadErrnoBadFileDescriptor)) {
        return -1;
    }
    return orig_fgetxattr
        ? orig_fgetxattr(fd, name, value, size, position, options)
        : -1;
}

static ssize_t (*orig_listxattr)(const char *, char *, size_t, int);
static ssize_t hook_listxattr(const char *path,
                              char *nameBuffer,
                              size_t size,
                              int options) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem &&
        PXJBRejectHiddenPathReadQuery(path, kPXJBHiddenReadErrnoPermissionDenied)) {
        return -1;
    }
    return orig_listxattr ? orig_listxattr(path, nameBuffer, size, options) : -1;
}

static ssize_t (*orig_flistxattr)(int, char *, size_t, int);
static ssize_t hook_flistxattr(int fd,
                               char *nameBuffer,
                               size_t size,
                               int options) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem &&
        PXJBRejectHiddenFDReadQuery(fd, kPXJBHiddenReadErrnoBadFileDescriptor)) {
        return -1;
    }
    return orig_flistxattr ? orig_flistxattr(fd, nameBuffer, size, options) : -1;
}

static BOOL PXJBSocketEndpointShouldHide(const struct sockaddr *address,
                                         socklen_t addressLength) {
    if (!address || addressLength < sizeof(struct sockaddr_in) ||
        address->sa_family != AF_INET) {
        return NO;
    }
    const struct sockaddr_in *ipv4 = (const struct sockaddr_in *)address;
    return PXP1CJBEndpointPortShouldHide(ntohs(ipv4->sin_port));
}

static int (*orig_getpeername)(int, struct sockaddr *, socklen_t *);
static int hook_getpeername(int socketFD,
                            struct sockaddr *address,
                            socklen_t *addressLength) {
    int status = orig_getpeername
        ? orig_getpeername(socketFD, address, addressLength)
        : -1;
    if (status == 0 && PXJBShouldBypassCached() && address && addressLength &&
        PXJBSocketEndpointShouldHide(address, *addressLength)) {
        errno = ENOTCONN;
        return -1;
    }
    return status;
}

static int (*orig_getsockname)(int, struct sockaddr *, socklen_t *);
static int hook_getsockname(int socketFD,
                            struct sockaddr *address,
                            socklen_t *addressLength) {
    int status = orig_getsockname
        ? orig_getsockname(socketFD, address, addressLength)
        : -1;
    if (status == 0 && PXJBShouldBypassCached() && address && addressLength &&
        PXJBSocketEndpointShouldHide(address, *addressLength)) {
        errno = ENOTCONN;
        return -1;
    }
    return status;
}

static int (*orig_connect)(int, const struct sockaddr *, socklen_t);
static int hook_connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
    if (PXJBShouldBypassCached() && addr) {
        if (addr->sa_family == AF_INET && addrlen >= sizeof(struct sockaddr_in)) {
            const struct sockaddr_in *a = (const struct sockaddr_in *)addr;
            uint32_t ip = ntohl(a->sin_addr.s_addr);
            uint16_t port = ntohs(a->sin_port);
            if ((ip & 0xFF000000U) == 0x7F000000U &&
                PXJBIsDeniedLoopbackPort(port)) {
                errno = ECONNREFUSED;
                return -1;
            }
        } else if (addr->sa_family == AF_INET6 && addrlen >= sizeof(struct sockaddr_in6)) {
            const struct sockaddr_in6 *a6 = (const struct sockaddr_in6 *)addr;
            uint16_t port = ntohs(a6->sin6_port);
            static const struct in6_addr loop = IN6ADDR_LOOPBACK_INIT;
            if (memcmp(&a6->sin6_addr, &loop, sizeof(loop)) == 0 && PXJBIsDeniedLoopbackPort(port)) {
                errno = ECONNREFUSED;
                return -1;
            }
        }
    }
    return orig_connect ? orig_connect(sockfd, addr, addrlen) : -1;
}

static char *(*orig_getenv)(const char *);

static BOOL PXJBShellEnvironmentValueShouldHide(const char *value) {
    if (!value || !value[0]) return NO;
    if (PXStrEqNoCase(value, "/bin/bash") ||
        PXStrEqNoCase(value, "/bin/zsh") ||
        PXStrEqNoCase(value, "/usr/bin/bash") ||
        PXStrEqNoCase(value, "/usr/bin/zsh")) {
        return YES;
    }
    if (PXHasPrefixNoCase(value, "/var/jb/") ||
        PXHasPrefixNoCase(value, "/private/var/jb/")) {
        return YES;
    }
    return PXJBPrivatePrebootPathShouldHide(value);
}

static const char *const kPXJBAlwaysHiddenEnvironmentKeys[] = {
    "DYLD_INSERT_LIBRARIES",
    "DYLD_LIBRARY_PATH",
    "DYLD_FRAMEWORK_PATH",
    "DYLD_FALLBACK_LIBRARY_PATH",
    "DYLD_FALLBACK_FRAMEWORK_PATH",
    "DYLD_ROOT_PATH",
    "DYLD_SHARED_CACHE_DIR",
    "DYLD_PRINT_TO_FILE",
    "DYLD_PRINT_LIBRARIES",
    "DYLD_PRINT_APIS",
    "DYLD_PRINT_OPTS",
    "DYLD_PRINT_ENV",
    "LD_PRELOAD",
    "_MSSafeMode",
    "MSDebug",
    "JB_SANDBOX_EXTENSIONS",
    NULL
};

static BOOL PXJBEnvironmentKeyAlwaysHidden(const char *name) {
    if (!name) return NO;
    for (size_t i = 0; kPXJBAlwaysHiddenEnvironmentKeys[i]; i++) {
        if (strcmp(name, kPXJBAlwaysHiddenEnvironmentKeys[i]) == 0) return YES;
    }
    return NO;
}

static char *hook_getenv(const char *name) {
    char *value = orig_getenv ? orig_getenv(name) : NULL;
    if (!PXJBShouldBypassCached() || !name) return value;
    if (PXJBEnvironmentKeyAlwaysHidden(name)) return NULL;
    if (strcmp(name, "SHELL") == 0 &&
        PXJBShellEnvironmentValueShouldHide(value)) {
        return NULL;
    }
    return value;
}

static void PXJBUnsetSuspiciousEnvIfNeeded(void) {
    if (!PXJBShouldBypassCached()) return;
    // Keep raw environ consistent with getenv/NSProcessInfo. SHELL is removed
    // only when its value identifies a jailbreak/rootless shell.
    for (size_t i = 0; kPXJBAlwaysHiddenEnvironmentKeys[i]; i++) {
        unsetenv(kPXJBAlwaysHiddenEnvironmentKeys[i]);
    }

    const char *shell = orig_getenv ? orig_getenv("SHELL") : getenv("SHELL");
    if (PXJBShellEnvironmentValueShouldHide(shell)) {
        unsetenv("SHELL");
    }
}

// Phase 2: anti-debug / anti-exec probes
// C-01: optional SystemConfiguration scalar. iFake resolves the zero-argument
// symbol at runtime and projects it to false. Keep x-new fail-open when the
// scoped JB master capability is inactive; symbol absence means no install.
typedef Boolean (*PXJBSCIsRunningWithDebuggerFunction)(void);
static PXJBSCIsRunningWithDebuggerFunction orig_SCIsRunningWithDebugger = NULL;

static Boolean hook_SCIsRunningWithDebugger(void) {
    if (PXJBSCDebuggerScalarEnabled()) return (Boolean)0;
    PXJBSCIsRunningWithDebuggerFunction original = orig_SCIsRunningWithDebugger;
    return original ? original() : (Boolean)0;
}

static int (*orig_ptrace)(int request, pid_t pid, void *addr, int data);
static int hook_ptrace(int request, pid_t pid, void *addr, int data) {
    if (PXJBShouldBypassCached()) {
        // PT_DENY_ATTACH == 31 on Darwin.
        if (request == PT_DENY_ATTACH || request == 31) {
            return 0;
        }
    }
    return orig_ptrace ? orig_ptrace(request, pid, addr, data) : -1;
}

static pid_t (*orig_fork)(void);
static pid_t hook_fork(void) {
    if (PXJBShouldBypassCached()) {
        errno = EPERM;
        return (pid_t)-1;
    }
    return orig_fork ? orig_fork() : (pid_t)-1;
}

static pid_t (*orig_vfork)(void);
static pid_t hook_vfork(void) {
    if (PXJBShouldBypassCached()) {
        errno = EPERM;
        return (pid_t)-1;
    }
    return orig_vfork ? orig_vfork() : (pid_t)-1;
}

// P0-B: generic syscall interception is not a production capability.
// A portable C variadic wrapper cannot preserve unknown syscall arguments.

// Block common jailbreak probe commands executed via system()/popen().
// This matcher is intentionally C-only because both callers are native hooks.
static inline BOOL PXJBCommandSeparator(unsigned char c) {
    switch (c) {
        case ' ': case '\t': case '\r': case '\n':
        case ';': case '|': case '&': case '(': case ')':
        case '<': case '>': case '"': case '\'': case '\\':
            return YES;
        default:
            return NO;
    }
}

static BOOL PXJBTokenEqualsNoCase(const char *token, size_t tokenLength, const char *expected) {
    if (!token || !expected) return NO;
    size_t expectedLength = strlen(expected);
    if (tokenLength != expectedLength) return NO;
    for (size_t i = 0; i < tokenLength; i++) {
        char a = token[i];
        char b = expected[i];
        if (a >= 'A' && a <= 'Z') a = (char)(a - 'A' + 'a');
        if (b >= 'A' && b <= 'Z') b = (char)(b - 'A' + 'a');
        if (a != b) return NO;
    }
    return YES;
}

static BOOL PXJBCommandLooksLikeProbe(const char *command) {
    if (!command || !command[0]) return NO;

    static const char *pathNeedles[] = {
        "/applications/cydia.app",
        "/applications/sileo.app",
        "/applications/zebra.app",
        "/applications/filza.app",
        "/library/mobilesubstrate",
        "/usr/sbin/sshd",
        "/etc/apt",
        "/var/lib/apt",
        "/var/lib/cydia",
        "/var/jb",
        "/private/preboot/jb",
        "frida-server",
        "fridagadget",
        "cycript",
        "uicache",
        "ldrestart",
        NULL
    };
    for (size_t i = 0; pathNeedles[i]; i++) {
        if (PXStrContainsNoCase(command, pathNeedles[i])) return YES;
    }

    const char *cursor = command;
    while (*cursor) {
        while (*cursor && PXJBCommandSeparator((unsigned char)*cursor)) cursor++;
        const char *token = cursor;
        while (*cursor && !PXJBCommandSeparator((unsigned char)*cursor)) cursor++;
        size_t tokenLength = (size_t)(cursor - token);
        if (tokenLength == 0) continue;
        if (PXJBTokenEqualsNoCase(token, tokenLength, "apt") ||
            PXJBTokenEqualsNoCase(token, tokenLength, "apt-get") ||
            PXJBTokenEqualsNoCase(token, tokenLength, "dpkg")) {
            return YES;
        }
    }
    return NO;
}

static int (*orig_system)(const char *);
static int hook_system(const char *command) {
    PXJB_EXEC_HOOK_SCOPE();
    if (pxjbFilterExec && command && PXJBCommandLooksLikeProbe(command)) {
        PXJBRecordBlockedEvent("system", command);
        errno = EPERM;
        return -1;
    }
    return orig_system ? orig_system(command) : -1;
}

static FILE *(*orig_popen)(const char *, const char *);
static FILE *hook_popen(const char *command, const char *type) {
    PXJB_EXEC_HOOK_SCOPE();
    if (pxjbFilterExec && command && PXJBCommandLooksLikeProbe(command)) {
        PXJBRecordBlockedEvent("popen", command);
        errno = EPERM;
        return NULL;
    }
    return orig_popen ? orig_popen(command, type) : NULL;
}

static BOOL PXJBSpawnPathLooksLikeProbe(const char *path) {
    if (!path || !path[0]) return NO;
    if (path[0] == '/' && PXJBPathShouldHide(path)) return YES;
    // Also block common tool names when posix_spawnp is used.
    static const char *denyTokens[] = {
        "ssh",
        "scp",
        "sshd",
        "bash",
        "zsh",
        "sh",
        "uicache",
        "ldrestart",
        "frida-server",
        "cycript",
        "dpkg",
        "apt",
        "apt-get",
        NULL
    };
    const char *base = strrchr(path, '/');
    base = base ? (base + 1) : path;
    for (int i = 0; denyTokens[i]; i++) {
        if (PXStrEqNoCase(base, denyTokens[i])) return YES;
    }
    return NO;
}

static int (*orig_posix_spawn)(pid_t *restrict, const char *restrict, const posix_spawn_file_actions_t *restrict, const posix_spawnattr_t *restrict, char *const argv[restrict], char *const envp[restrict]);
static int hook_posix_spawn(pid_t *restrict pid, const char *restrict path, const posix_spawn_file_actions_t *restrict file_actions, const posix_spawnattr_t *restrict attrp, char *const argv[restrict], char *const envp[restrict]) {
    PXJB_EXEC_HOOK_SCOPE();
    if (pxjbFilterExec && path && PXJBSpawnPathLooksLikeProbe(path)) {
        PXJBRecordBlockedEvent("posix_spawn", path);
        errno = ENOENT;
        return -1;
    }
    return orig_posix_spawn ? orig_posix_spawn(pid, path, file_actions, attrp, argv, envp) : -1;
}

static int (*orig_posix_spawnp)(pid_t *restrict, const char *restrict, const posix_spawn_file_actions_t *restrict, const posix_spawnattr_t *restrict, char *const argv[restrict], char *const envp[restrict]);
static int hook_posix_spawnp(pid_t *restrict pid, const char *restrict file, const posix_spawn_file_actions_t *restrict file_actions, const posix_spawnattr_t *restrict attrp, char *const argv[restrict], char *const envp[restrict]) {
    PXJB_EXEC_HOOK_SCOPE();
    if (pxjbFilterExec && file && PXJBSpawnPathLooksLikeProbe(file)) {
        PXJBRecordBlockedEvent("posix_spawnp", file);
        errno = ENOENT;
        return -1;
    }
    return orig_posix_spawnp ? orig_posix_spawnp(pid, file, file_actions, attrp, argv, envp) : -1;
}

// P0-B: sandbox_check interception is not a production capability.
// Its operation-specific variadic ABI is intentionally left unhooked.

// Phase 3: compatibility-first dylib hiding.
// Preserve dyld cardinality and index identity. Only image-name surfaces are
// sanitized; count/header/slide remain owned by dyld and are never hooked.
typedef const char *(*PXDyldImageNameFn)(uint32_t image_index);

static PXDyldImageNameFn orig__dyld_get_image_name = NULL;
static PXDyldImageNameFn gDyldImageNameEntry = NULL;

static BOOL PXDyldNameTrampolineIsReady(void) {
    return orig__dyld_get_image_name != NULL &&
           orig__dyld_get_image_name != gDyldImageNameEntry;
}

static const char *PXDyldOriginalImageName(uint32_t idx) {
    if (!orig__dyld_get_image_name ||
        orig__dyld_get_image_name == gDyldImageNameEntry) return NULL;
    return orig__dyld_get_image_name(idx);
}

static BOOL PXStrContainsNoCase(const char *haystack, const char *needle) {
    if (!haystack || !needle) return NO;
    size_t nlen = strlen(needle);
    if (nlen == 0) return YES;

    for (const char *h = haystack; *h; h++) {
        const char *p = h;
        size_t i = 0;
        while (p[i] && i < nlen) {
            char a = p[i];
            char b = needle[i];
            if (a >= 'A' && a <= 'Z') a = (char)(a - 'A' + 'a');
            if (b >= 'A' && b <= 'Z') b = (char)(b - 'A' + 'a');
            if (a != b) break;
            i++;
        }
        if (i == nlen) return YES;
    }
    return NO;
}

static BOOL PXJBShouldHideImageName(const char *name) {
    // Image enumeration is compatibility-sensitive: never match arbitrary
    // substrings such as "shadow", "liberty", "substrate" or "frida".
    return PXJBArtifactPathShouldMatch(name);
}

static uint32_t PXJBStableImageAliasHash(const char *name) {
    uint32_t hash = 2166136261u;
    if (!name) return hash;
    for (const unsigned char *cursor = (const unsigned char *)name; *cursor; cursor++) {
        unsigned char value = *cursor;
        if (value >= 'A' && value <= 'Z') value = (unsigned char)(value - 'A' + 'a');
        hash ^= value;
        hash *= 16777619u;
    }
    return hash;
}

static const char *PXJBSanitizedImageName(const char *name) {
    if (!name || !PXJBShouldHideImageName(name)) return name;

    // Immutable process-lifetime aliases: no allocation, lock, TLS or index map.
    // A stable hash spreads hidden images across believable system paths while
    // preserving the same alias for the same original path on every call.
    static const char *const aliases[] = {
        "/System/Library/Frameworks/Accelerate.framework/Accelerate",
        "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation",
        "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
        "/System/Library/Frameworks/CoreServices.framework/CoreServices",
        "/System/Library/Frameworks/Foundation.framework/Foundation",
        "/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit",
        "/System/Library/Frameworks/Security.framework/Security",
        "/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration",
        "/System/Library/PrivateFrameworks/CoreAnalytics.framework/CoreAnalytics",
        "/System/Library/PrivateFrameworks/CoreUtils.framework/CoreUtils",
        "/System/Library/PrivateFrameworks/LoggingSupport.framework/LoggingSupport",
        "/System/Library/PrivateFrameworks/MobileCoreServices.framework/MobileCoreServices",
        "/usr/lib/libSystem.B.dylib",
        "/usr/lib/libc++.1.dylib",
        "/usr/lib/libobjc.A.dylib",
        "/usr/lib/system/libsystem_trace.dylib",
    };
    return aliases[PXJBStableImageAliasHash(name) % PXJB_ARRAY_COUNT(aliases)];
}

// Phase 3 strong option: hide libproc-based region filename queries
static int (*orig_proc_regionfilename)(int pid, uint64_t address, void *buffer, uint32_t buffersize);
static int hook_proc_regionfilename(int pid, uint64_t address, void *buffer, uint32_t buffersize) {
    if (!orig_proc_regionfilename) return 0;
    int r = orig_proc_regionfilename(pid, address, buffer, buffersize);
    if (r <= 0) return r;
    if (!PXJBHideProcMapsEnabled()) return r;
    if (pid != getpid()) return r;
    if (!buffer || buffersize == 0) return r;

    // Ensure NUL-termination for scanning.
    char *cbuf = (char *)buffer;
    cbuf[buffersize - 1] = '\0';
    if (PXJBShouldHideImageName(cbuf) || PXJBPathShouldHide(cbuf)) {
        cbuf[0] = '\0';
        return 0;
    }
    return r;
}

// Phase 3 compatibility option: preserve ObjC image-list cardinality and
// sanitize only the path strings exposed to callers.
static const char **(*orig_objc_copyImageNames)(unsigned int *outCount);
static const char **hook_objc_copyImageNames(unsigned int *outCount) {
    const char **list = orig_objc_copyImageNames ? orig_objc_copyImageNames(outCount) : NULL;
    if (!PXJBHideObjcImagesEnabled() || !list || !outCount || *outCount == 0) {
        return list;
    }

    unsigned int count = *outCount;
    BOOL changed = NO;
    for (unsigned int i = 0; i < count; i++) {
        if (PXJBSanitizedImageName(list[i]) != list[i]) {
            changed = YES;
            break;
        }
    }
    if (!changed) return list;

    // objc_copyImageNames returns a caller-owned pointer array. Replace only
    // that array; original and alias strings both have process lifetime.
    const char **out = (const char **)calloc(count + 1, sizeof(char *));
    if (!out) return list; // fail open without corrupting ownership

    for (unsigned int i = 0; i < count; i++) {
        out[i] = PXJBSanitizedImageName(list[i]);
    }
    out[count] = NULL;
    free((void *)list);
    return out;
}

static const char *(*orig_class_getImageName)(Class cls);
static const char *hook_class_getImageName(Class cls) {
    const char *name = orig_class_getImageName ? orig_class_getImageName(cls) : NULL;
    if (!PXJBHideObjcImagesEnabled()) return name;
    return PXJBSanitizedImageName(name);
}

static BOOL PXJBShouldBlockDlopenPath(const char *path) {
    // Direct dlopen probes share the same boundary-aware artifact policy as
    // dyld/ObjC image enumeration so the two surfaces cannot drift.
    return PXJBArtifactPathShouldMatch(path);
}

static BOOL PXJBShouldBlockDlsymName(const char *sym) {
    if (!sym || !sym[0]) return NO;
    // Only block extremely fingerprintable hooking symbols.
    static const char *deny[] = {
        "MSHookFunction",
        "MSHookMessageEx",
        "MSGetImageByName",
        "MSFindSymbol",
        "EKHook",
        "EKHookFunction",
        "LHHookFunction",
        "SubHookFunction",
        "fishhook_rebind_symbols",
        NULL
    };
    for (int i = 0; deny[i]; i++) {
        if (strcmp(sym, deny[i]) == 0) return YES;
    }
    return NO;
}

// Phase 3 strong option: hide dl_iterate_phdr enumeration
static int (*orig_dl_iterate_phdr)(int (*callback)(struct dl_phdr_info *info, size_t size, void *data), void *data);

typedef struct {
    int (*cb)(struct dl_phdr_info *info, size_t size, void *data);
    void *data;
} PXJBPhdrIterCtx;

static int px_dl_iterate_phdr_cb(struct dl_phdr_info *info, size_t size, void *data) {
    PXJBPhdrIterCtx *ctx = (PXJBPhdrIterCtx *)data;
    if (!ctx || !ctx->cb) return 0;

    const size_t nameFieldEnd =
        offsetof(struct dl_phdr_info, dlpi_name) + sizeof(info->dlpi_name);
    if (PXJBHideDlIteratePhdrEnabled() &&
        info &&
        size >= nameFieldEnd) {
        const char *sanitized = PXJBSanitizedImageName(info->dlpi_name);
        if (sanitized != info->dlpi_name) {
            // Preserve every ABI field and the callback cardinality. The SDK
            // declaration may expose only leading fields, so copy exactly the
            // runtime-provided size before replacing dlpi_name.
            void *copy = malloc(size);
            if (copy) {
                memcpy(copy, info, size);
                ((struct dl_phdr_info *)copy)->dlpi_name = sanitized;
                int result = ctx->cb((struct dl_phdr_info *)copy, size, ctx->data);
                free(copy);
                return result;
            }
        }
    }
    return ctx->cb(info, size, ctx->data);
}

static int hook_dl_iterate_phdr(int (*callback)(struct dl_phdr_info *info, size_t size, void *data), void *data) {
    if (!orig_dl_iterate_phdr) return 0;
    if (!PXJBHideDlIteratePhdrEnabled() || !callback) {
        return orig_dl_iterate_phdr(callback, data);
    }

    PXJBPhdrIterCtx ctx;
    ctx.cb = callback;
    ctx.data = data;
    return orig_dl_iterate_phdr(px_dl_iterate_phdr_cb, &ctx);
}

// Phase 3 strong option: block dlopen/dlsym probes
static void *(*orig_dlopen)(const char *path, int mode);
static void *hook_dlopen(const char *path, int mode) {
    if (PXJBBlockDlopenDlsymProbesEnabled() && path) {
        if (PXJBShouldBlockDlopenPath(path)) {
            errno = ENOENT;
            return NULL;
        }
    }
    return orig_dlopen ? orig_dlopen(path, mode) : NULL;
}

static void *(*orig_dlsym)(void *handle, const char *symbol);
static void *hook_dlsym(void *handle, const char *symbol) {
    if (PXJBBlockDlopenDlsymProbesEnabled() && symbol) {
        if (PXJBShouldBlockDlsymName(symbol)) {
            return NULL;
        }
    }
    return orig_dlsym ? orig_dlsym(handle, symbol) : NULL;
}

// P1-D: sysctl/sysctlbyname sanitization is coordinator-owned. These
// handlers are narrow terminal pre-providers because the existing identity
// provider calls the original internally and returns YES, which intentionally
// skips later post providers. Only jailbreak-specific keys are claimed here.
static int (*orig_sysctl_jb)(int *name,
                             u_int namelen,
                             void *oldp,
                             size_t *oldlenp,
                             void *newp,
                             size_t newlen) = NULL;
static int (*orig_sysctlbyname_jb)(const char *name,
                                   void *oldp,
                                   size_t *oldlenp,
                                   void *newp,
                                   size_t newlen) = NULL;

static void PXJBSanitizeBootArgs(void *oldp, size_t *oldlenp) {
    if (!oldp || !oldlenp || *oldlenp == 0) return;
    char *buf = (char *)oldp;
    size_t n = *oldlenp;
    buf[n - 1] = '\0';
    if (strstr(buf, "checkra1n") ||
        strstr(buf, "cs_enforcement_disable") ||
        strstr(buf, "amfid") ||
        strstr(buf, "jailbreak")) {
        memset(buf, 0, n);
        const char *clean = "root_device=md0";
        strncpy(buf, clean, n - 1);
    }
}

static void PXJBSanitizeKinfoProc(void *oldp, size_t *oldlenp) {
    if (!oldp || !oldlenp || *oldlenp == 0) return;
#if __has_include(<sys/user.h>)
#ifndef P_TRACED
#define P_TRACED 0x00000800
#endif
    size_t len = *oldlenp;
    if (len < sizeof(struct kinfo_proc)) return;
    size_t count = len / sizeof(struct kinfo_proc);
    struct kinfo_proc *procs = (struct kinfo_proc *)oldp;
    for (size_t i = 0; i < count; i++) {
        procs[i].kp_proc.p_flag &= ~P_TRACED;
    }
#else
    (void)oldp;
    (void)oldlenp;
#endif
}

static BOOL PXJBIsRawSysctlSanitizeTarget(const int *name, u_int namelen) {
    if (!name || namelen < 2 || name[0] != CTL_KERN) return NO;
#ifdef KERN_BOOTARGS
    if (name[1] == KERN_BOOTARGS) return YES;
#endif
    return name[1] == KERN_PROC;
}

static BOOL PXJBHandleSysctlSanitizeRequest(int *name,
                                            u_int namelen,
                                            void *oldp,
                                            size_t *oldlenp,
                                            void *newp,
                                            size_t newlen,
                                            int *outResult) {
    if (!PXJBSysctlProcSanitizeEnabled() ||
        !orig_sysctl_jb ||
        !PXJBIsRawSysctlSanitizeTarget(name, namelen) ||
        newp != NULL ||
        newlen != 0) {
        return NO;
    }

    int result = orig_sysctl_jb(name, namelen, oldp, oldlenp, NULL, 0);
    if (result == 0) {
#ifdef KERN_BOOTARGS
        if (name[1] == KERN_BOOTARGS) {
            PXJBSanitizeBootArgs(oldp, oldlenp);
        } else
#endif
        if (name[1] == KERN_PROC) {
            PXJBSanitizeKinfoProc(oldp, oldlenp);
        }
    }
    if (outResult) *outResult = result;
    return YES;
}

static BOOL PXJBIsSysctlBynameSanitizeTarget(const char *name) {
    if (!name) return NO;
    return strcmp(name, "kern.bootargs") == 0 ||
           strcmp(name, "kern.proc.pid") == 0 ||
           strcmp(name, "kern.proc") == 0;
}

static BOOL PXJBHandleSysctlBynameSanitizeRequest(const char *name,
                                                  void *oldp,
                                                  size_t *oldlenp,
                                                  void *newp,
                                                  size_t newlen,
                                                  int *outResult) {
    if (!PXJBSysctlProcSanitizeEnabled() ||
        !orig_sysctlbyname_jb ||
        !PXJBIsSysctlBynameSanitizeTarget(name) ||
        newp != NULL ||
        newlen != 0) {
        return NO;
    }

    int result = orig_sysctlbyname_jb(name, oldp, oldlenp, NULL, 0);
    if (result == 0) {
        if (strcmp(name, "kern.bootargs") == 0) {
            PXJBSanitizeBootArgs(oldp, oldlenp);
        } else {
            PXJBSanitizeKinfoProc(oldp, oldlenp);
        }
    }
    if (outResult) *outResult = result;
    return YES;
}

static const char *hook__dyld_get_image_name(uint32_t image_index) {
    PXJB_REENTRY_SCOPE(dyldScope, kPXJBReentryDyldNames);
    const char *name = PXDyldOriginalImageName(image_index);
    if (!dyldScope.entered || !PXJBHideDylibsEnabled()) return name;
    return PXJBSanitizedImageName(name);
}

static int (*orig_dladdr)(const void *addr, Dl_info *info);
static int hook_dladdr(const void *addr, Dl_info *info) {
    PXJB_REENTRY_SCOPE(dyldScope, kPXJBReentryDyldNames);
    int result = orig_dladdr ? orig_dladdr(addr, info) : 0;
    if (!dyldScope.entered || result == 0 || !info || !PXJBHideDylibsEnabled()) {
        return result;
    }
    info->dli_fname = PXJBSanitizedImageName(info->dli_fname);
    return result;
}

// Phase 2 extension: mount/volume checks (statfs/statvfs)
static BOOL PXJBIsSensitiveMountPath(const char *path) {
    if (!path) return NO;
    // Most detectors check "/" and sometimes "/private" or "/var".
    if (strcmp(path, "/") == 0) return YES;
    if (strcmp(path, "/var") == 0) return YES;
    if (strcmp(path, "/private") == 0) return YES;
    if (strcmp(path, "/private/var") == 0) return YES;
    return NO;
}

static BOOL PXJBFileDescriptorNeedsReadonlyFilesystemSpoof(int fd) {
    if (fd < 0) return NO;

    char fdPath[PATH_MAX];
    if (PXJBOriginalFcntlGetPath(fd, fdPath, sizeof(fdPath)) == -1) {
        return NO;
    }

    char normalizedPath[PATH_MAX];
    if (!PXJBNormalizeAbsolutePath(fdPath,
                                   normalizedPath,
                                   sizeof(normalizedPath))) {
        return NO;
    }
    return PXJBIsSensitiveMountPath(normalizedPath);
}

static void PXJBNormalizeStatfs(struct statfs *buf) {
    if (!buf) return;
    // Ensure rootfs looks read-only (common non-JB expectation).
#ifdef MNT_RDONLY
    buf->f_flags |= MNT_RDONLY;
#endif
}

static void PXJBNormalizeStatvfs(struct statvfs *buf) {
    if (!buf) return;
#ifdef ST_RDONLY
    buf->f_flag |= ST_RDONLY;
#endif
}

static int (*orig_statfs)(const char *, struct statfs *);
static int hook_statfs(const char *path, struct statfs *buf) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    int r = orig_statfs ? orig_statfs(path, buf) : -1;
    if (r == 0 && (pxjbFilterFilesystem && PXJBStatfsBypassEnabled()) && PXJBIsSensitiveMountPath(path)) {
        PXJBNormalizeStatfs(buf);
    }
    return r;
}

static int (*orig_fstatfs)(int, struct statfs *);
static int hook_fstatfs(int fd, struct statfs *buf) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    int r = orig_fstatfs ? orig_fstatfs(fd, buf) : -1;
    int savedErrno = errno;
    if (r == 0 && pxjbFilterFilesystem && PXJBStatfsBypassEnabled() &&
        PXJBFileDescriptorNeedsReadonlyFilesystemSpoof(fd)) {
        PXJBNormalizeStatfs(buf);
    }
    errno = savedErrno;
    return r;
}

static int (*orig_fstatfs64)(int, PXStatfs64Buf *);
static int hook_fstatfs64(int fd, PXStatfs64Buf *buf) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem &&
        PXJBFilesystemDispositionIsHidden(PXJBClassifyFileDescriptorPath(fd))) {
        errno = EBADF;
        return -1;
    }

    int r = orig_fstatfs64 ? orig_fstatfs64(fd, buf) : -1;
    int savedErrno = errno;
    if (r == 0 && pxjbFilterFilesystem && PXJBStatfsBypassEnabled() &&
        PXJBFileDescriptorNeedsReadonlyFilesystemSpoof(fd)) {
        PXJBNormalizeStatfs((struct statfs *)buf);
    }
    errno = savedErrno;
    return r;
}

static int (*orig_statvfs)(const char *, struct statvfs *);
static int hook_statvfs(const char *path, struct statvfs *buf) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    int r = orig_statvfs ? orig_statvfs(path, buf) : -1;
    if (r == 0 && (pxjbFilterFilesystem && PXJBStatfsBypassEnabled()) && PXJBIsSensitiveMountPath(path)) {
        PXJBNormalizeStatvfs(buf);
    }
    return r;
}

static int (*orig_fstatvfs)(int, struct statvfs *);
static int hook_fstatvfs(int fd, struct statvfs *buf) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    int r = orig_fstatvfs ? orig_fstatvfs(fd, buf) : -1;
    int savedErrno = errno;
    if (r == 0 && pxjbFilterFilesystem && PXJBStatfsBypassEnabled() &&
        PXJBFileDescriptorNeedsReadonlyFilesystemSpoof(fd)) {
        PXJBNormalizeStatvfs(buf);
    }
    errno = savedErrno;
    return r;
}

// --- Priority 1: UID/GID spoofing ---
// Preserve legitimate process identity and only hide an actual root identity.
// The fallback remains 501 when a trampoline is unavailable.

static int (*orig_issetugid)(void);
static int hook_issetugid(void) {
    int original = orig_issetugid ? orig_issetugid() : 0;
    if (PXJBShouldBypassCached() && original != 0) return 0;
    return original;
}

static uid_t (*orig_getuid)(void);
static uid_t hook_getuid(void) {
    uid_t original = orig_getuid ? orig_getuid() : 501;
    if (PXJBShouldBypassCached() && original == 0) return 501;
    return original;
}

static uid_t (*orig_geteuid)(void);
static uid_t hook_geteuid(void) {
    uid_t original = orig_geteuid ? orig_geteuid() : 501;
    if (PXJBShouldBypassCached() && original == 0) return 501;
    return original;
}

static gid_t (*orig_getgid)(void);
static gid_t hook_getgid(void) {
    gid_t original = orig_getgid ? orig_getgid() : 501;
    if (PXJBShouldBypassCached() && original == 0) return 501;
    return original;
}

static gid_t (*orig_getegid)(void);
static gid_t hook_getegid(void) {
    gid_t original = orig_getegid ? orig_getegid() : 501;
    if (PXJBShouldBypassCached() && original == 0) return 501;
    return original;
}

static int (*orig_getgroups)(int, gid_t *);
static int hook_getgroups(int gidsetsize, gid_t *grouplist) {
    int count = orig_getgroups ? orig_getgroups(gidsetsize, grouplist) : -1;
    if (count <= 0 || !PXJBShouldBypassCached() || !grouplist || gidsetsize <= 0 ||
        count > gidsetsize) {
        return count;
    }
    return PXP1CJBCompactNonRootGroups(grouplist, count);
}

static int (*orig_setuid)(uid_t);
static int hook_setuid(uid_t uid) {
    if (PXJBShouldBypassCached() && uid == 0) {
        errno = EPERM;
        return -1;
    }
    return orig_setuid ? orig_setuid(uid) : -1;
}

static int (*orig_seteuid)(uid_t);
static int hook_seteuid(uid_t uid) {
    if (PXJBShouldBypassCached() && uid == 0) {
        errno = EPERM;
        return -1;
    }
    return orig_seteuid ? orig_seteuid(uid) : -1;
}

static int (*orig_setgid)(gid_t);
static int hook_setgid(gid_t gid) {
    if (PXJBShouldBypassCached() && gid == 0) {
        errno = EPERM;
        return -1;
    }
    return orig_setgid ? orig_setgid(gid) : -1;
}

static int (*orig_setegid)(gid_t);
static int hook_setegid(gid_t gid) {
    if (PXJBShouldBypassCached() && gid == 0) {
        errno = EPERM;
        return -1;
    }
    return orig_setegid ? orig_setegid(gid) : -1;
}

static int (*orig_setreuid)(uid_t, uid_t);
static int hook_setreuid(uid_t ruid, uid_t euid) {
    if (PXJBShouldBypassCached() && (ruid == 0 || euid == 0)) {
        errno = EPERM;
        return -1;
    }
    return orig_setreuid ? orig_setreuid(ruid, euid) : -1;
}

static int (*orig_setregid)(gid_t, gid_t);
static int hook_setregid(gid_t rgid, gid_t egid) {
    if (PXJBShouldBypassCached() && (rgid == 0 || egid == 0)) {
        errno = EPERM;
        return -1;
    }
    return orig_setregid ? orig_setregid(rgid, egid) : -1;
}

// --- Priority 1: getppid spoofing ---
// On non-jailbroken devices, parent PID is always 1 (launchd).
static pid_t (*orig_getppid)(void);
static pid_t hook_getppid(void) {
    if (PXJBShouldBypassCached()) return 1;
    return orig_getppid ? orig_getppid() : 1;
}

// --- Priority 1: csops — hide CS_PLATFORM_BINARY ---
// Some detectors check if the process has the platform binary flag set,
// which can happen on jailbroken devices.
static int (*orig_csops)(pid_t, unsigned int, void *, size_t);
static int hook_csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize) {
    int ret = orig_csops ? orig_csops(pid, ops, useraddr, usersize) : -1;
    if (ret == 0 && PXJBShouldBypassCached() && ops == CS_OPS_STATUS && pid == getpid()) {
        // Clear CS_PLATFORM_BINARY flag from the returned status.
        if (useraddr && usersize >= sizeof(uint32_t)) {
            uint32_t *flags = (uint32_t *)useraddr;
            *flags &= ~CS_PLATFORM_BINARY;
        }
    }
    return ret;
}

// --- Priority 3: dlopen_preflight ---
static bool (*orig_dlopen_preflight)(const char *);
static bool hook_dlopen_preflight(const char *path) {
    if (PXJBShouldBypassCached() && path) {
        if (PXJBShouldBlockDlopenPath(path)) return false;
    }
    return orig_dlopen_preflight ? orig_dlopen_preflight(path) : false;
}

// --- Priority 3: objc_copyClassNamesForImage ---
static const char **(*orig_objc_copyClassNamesForImage)(const char *, unsigned int *);
static const char **hook_objc_copyClassNamesForImage(const char *image, unsigned int *outCount) {
    if (PXJBShouldBypassCached() && image) {
        if (PXJBShouldHideImageName(image)) {
            if (outCount) *outCount = 0;
            return NULL;
        }
    }
    return orig_objc_copyClassNamesForImage ? orig_objc_copyClassNamesForImage(image, outCount) : NULL;
}

// --- Priority 3: NSVersionOfRunTimeLibrary / NSVersionOfLinkTimeLibrary ---
static int32_t (*orig_NSVersionOfRunTimeLibrary)(const char *);
static int32_t hook_NSVersionOfRunTimeLibrary(const char *libraryName) {
    if (PXJBShouldBypassCached() && libraryName) {
        if (PXJBShouldHideImageName(libraryName)) return -1;
    }
    return orig_NSVersionOfRunTimeLibrary ? orig_NSVersionOfRunTimeLibrary(libraryName) : -1;
}

static int32_t (*orig_NSVersionOfLinkTimeLibrary)(const char *);
static int32_t hook_NSVersionOfLinkTimeLibrary(const char *libraryName) {
    if (PXJBShouldBypassCached() && libraryName) {
        if (PXJBShouldHideImageName(libraryName)) return -1;
    }
    return orig_NSVersionOfLinkTimeLibrary ? orig_NSVersionOfLinkTimeLibrary(libraryName) : -1;
}

// --- Priority 3: creat ---
static int (*orig_creat)(const char *, mode_t);
static int hook_creat(const char *path, mode_t mode) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemDisposition disposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         path,
                                         kPXJBFilesystemOperationWrite,
                                         O_WRONLY | O_CREAT | O_TRUNC,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionBlocksWrite(disposition)) {
            errno = PXJBFilesystemErrno(disposition);
            return -1;
        }
    }
    return orig_creat ? orig_creat(path, mode) : -1;
}

// P0-A: fcntl is variadic and cannot be forwarded generically in portable C.
// Keep a direct function pointer only for internal commands with a verified ABI.
typedef int (*PXJBFcntlFunction)(int, int, ...);
static PXJBFcntlFunction orig_fcntl = NULL;

static int PXJBOriginalFcntlGetPath(int fd, char *path, size_t pathCapacity) {
    if (fd < 0 || !path) {
        errno = EINVAL;
        return -1;
    }
    if (pathCapacity < PATH_MAX) {
        path[0] = '\0';
        errno = ERANGE;
        return -1;
    }

    path[0] = '\0';
    PXJBFcntlFunction fn = orig_fcntl;
    int result = fn ? fn(fd, F_GETPATH, path) : fcntl(fd, F_GETPATH, path);
    if (result == -1) {
        path[0] = '\0';
        return -1;
    }

    path[pathCapacity - 1] = '\0';
    return result;
}

static BOOL PXJBJoinAbsoluteBaseAndNormalize(const char *basePath,
                                             const char *relativePath,
                                             char *out,
                                             size_t outCapacity) {
    return PXP1CJBJoinAbsoluteBaseAndNormalize(basePath,
                                               relativePath,
                                               out,
                                               outCapacity);
}

static BOOL PXJBResolveAtPathForFiltering(int dirfd,
                                          const char *path,
                                          char *out,
                                          size_t outCapacity) {
    if (!path || !out || outCapacity < 2) return NO;
    out[0] = '\0';

    if (path[0] == '/') {
        return PXJBNormalizeAbsolutePath(path, out, outCapacity);
    }
    if (dirfd == AT_FDCWD) {
        return PXJBJoinCwdAndNormalize(path, out, outCapacity);
    }

    char directoryPath[PATH_MAX];
    if (PXJBOriginalFcntlGetPath(dirfd, directoryPath, sizeof(directoryPath)) == -1) {
        return NO;
    }
    return PXJBJoinAbsoluteBaseAndNormalize(directoryPath, path, out, outCapacity);
}

static PXJBFilesystemDisposition PXJBClassifyFilesystemPathAt(int dirfd,
                                                               const char *path,
                                                               PXJBFilesystemOperation operation,
                                                               int flags,
                                                               char *resolvedPath,
                                                               size_t resolvedCapacity) {
    if (resolvedPath && resolvedCapacity > 0) resolvedPath[0] = '\0';
    if (!path || !path[0]) return kPXJBFilesystemUnresolved;

    char localResolved[PATH_MAX];
    char *target = resolvedPath;
    size_t targetCapacity = resolvedCapacity;
    if (!target || targetCapacity < 2) {
        target = localResolved;
        targetCapacity = sizeof(localResolved);
    }

    BOOL resolved = PXJBResolveAtPathForFiltering(dirfd,
                                                  path,
                                                  target,
                                                  targetCapacity);
    if (!resolved) {
        // A relative probe can still be classified from its own lexical form.
        // Otherwise preserve uncertainty and let callers fail open.
        if (path[0] != '/' && PXJBRelativePathLooksLikeProbe(path)) {
            return operation == kPXJBFilesystemOperationWrite
                ? kPXJBFilesystemDenyWrite
                : kPXJBFilesystemHide;
        }
        return kPXJBFilesystemUnresolved;
    }

    // Dedicated write-probe targets must remain distinguishable from hidden
    // filesystem artifacts. The shared B-00 contract gives denied writes
    // priority so EACCES never collapses into ENOENT.
    BOOL deniedWriteProbe = operation == kPXJBFilesystemOperationWrite &&
                            PXJBPathMatchesDenyWriteRules(target, flags);
    BOOL hiddenArtifact = PXJBPathMatchesHiddenRules(target);
    return PXP1CJBResolvedPathDisposition(operation,
                                          hiddenArtifact,
                                          deniedWriteProbe);
}

static PXJBFilesystemDisposition PXJBClassifyFileDescriptorPath(int fd) {
    if (fd < 0) return kPXJBFilesystemUnresolved;

    char fdPath[PATH_MAX];
    if (PXJBOriginalFcntlGetPath(fd, fdPath, sizeof(fdPath)) == -1) {
        return kPXJBFilesystemUnresolved;
    }
    return PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                        fdPath,
                                        kPXJBFilesystemOperationRead,
                                        O_RDONLY,
                                        NULL,
                                        0);
}

// --- Priority 3: fstat (fd-based, resolve via original fcntl F_GETPATH) ---
static int (*orig_fstat)(int, struct stat *);
static int hook_fstat(int fd, struct stat *buf) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem &&
        PXJBFilesystemDispositionIsHidden(PXJBClassifyFileDescriptorPath(fd))) {
        errno = EBADF;
        return -1;
    }
    return orig_fstat ? orig_fstat(fd, buf) : -1;
}

static int (*orig_fstat64)(int, struct stat *);
static int hook_fstat64(int fd, struct stat *buf) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem &&
        PXJBFilesystemDispositionIsHidden(PXJBClassifyFileDescriptorPath(fd))) {
        errno = EBADF;
        return -1;
    }
    return orig_fstat64 ? orig_fstat64(fd, buf) : -1;
}

// --- Priority 3: fstatat ---
static int (*orig_fstatat)(int, const char *, struct stat *, int);
static int hook_fstatat(int dirfd, const char *pathname, struct stat *buf, int flags) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemDisposition disposition =
            PXJBClassifyFilesystemPathAt(dirfd,
                                         pathname,
                                         kPXJBFilesystemOperationRead,
                                         O_RDONLY,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionIsHidden(disposition)) {
            errno = ENOENT;
            return -1;
        }
    }
    return orig_fstatat ? orig_fstatat(dirfd, pathname, buf, flags) : -1;
}

static int (*orig_fstatat64)(int, const char *, struct stat *, int);
static int hook_fstatat64(int dirfd, const char *pathname, struct stat *buf, int flags) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemDisposition disposition =
            PXJBClassifyFilesystemPathAt(dirfd,
                                         pathname,
                                         kPXJBFilesystemOperationRead,
                                         O_RDONLY,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionIsHidden(disposition)) {
            errno = ENOENT;
            return -1;
        }
    }
    return orig_fstatat64 ? orig_fstatat64(dirfd, pathname, buf, flags) : -1;
}

// --- Priority 3: faccessat ---
static int (*orig_faccessat)(int, const char *, int, int);
static int hook_faccessat(int dirfd, const char *pathname, int mode, int flags) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemDisposition disposition =
            PXJBClassifyFilesystemPathAt(dirfd,
                                         pathname,
                                         kPXJBFilesystemOperationRead,
                                         O_RDONLY,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionIsHidden(disposition)) {
            errno = ENOENT;
            return -1;
        }
    }
    return orig_faccessat ? orig_faccessat(dirfd, pathname, mode, flags) : -1;
}

// --- Priority 3: readlinkat ---
static ssize_t (*orig_readlinkat)(int, const char *, char *, size_t);
static ssize_t hook_readlinkat(int dirfd, const char *pathname, char *buf, size_t bufsiz) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemDisposition disposition =
            PXJBClassifyFilesystemPathAt(dirfd,
                                         pathname,
                                         kPXJBFilesystemOperationRead,
                                         O_RDONLY,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionIsHidden(disposition)) {
            errno = ENOENT;
            return -1;
        }
    }
    return orig_readlinkat ? orig_readlinkat(dirfd, pathname, buf, bufsiz) : -1;
}

// --- Priority 3: Filesystem mutation hooks ---
static int (*orig_symlink)(const char *, const char *);
static int hook_symlink(const char *path1, const char *path2) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemDisposition sourceDisposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         path1,
                                         kPXJBFilesystemOperationRead,
                                         O_RDONLY,
                                         NULL,
                                         0);
        PXJBFilesystemDisposition destinationDisposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         path2,
                                         kPXJBFilesystemOperationWrite,
                                         O_WRONLY | O_CREAT,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionIsHidden(sourceDisposition)) {
            errno = ENOENT;
            return -1;
        }
        if (PXJBFilesystemDispositionBlocksWrite(destinationDisposition)) {
            errno = PXJBFilesystemErrno(destinationDisposition);
            return -1;
        }
    }
    return orig_symlink ? orig_symlink(path1, path2) : -1;
}

static int (*orig_rename)(const char *, const char *);
static int hook_rename(const char *old, const char *new_path) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemDisposition sourceDisposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         old,
                                         kPXJBFilesystemOperationRead,
                                         O_RDONLY,
                                         NULL,
                                         0);
        PXJBFilesystemDisposition destinationDisposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         new_path,
                                         kPXJBFilesystemOperationWrite,
                                         O_WRONLY | O_CREAT,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionIsHidden(sourceDisposition)) {
            errno = ENOENT;
            return -1;
        }
        if (PXJBFilesystemDispositionBlocksWrite(destinationDisposition)) {
            errno = PXJBFilesystemErrno(destinationDisposition);
            return -1;
        }
    }
    return orig_rename ? orig_rename(old, new_path) : -1;
}

static int (*orig_link)(const char *, const char *);
static int hook_link(const char *path1, const char *path2) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemDisposition sourceDisposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         path1,
                                         kPXJBFilesystemOperationRead,
                                         O_RDONLY,
                                         NULL,
                                         0);
        PXJBFilesystemDisposition destinationDisposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         path2,
                                         kPXJBFilesystemOperationWrite,
                                         O_WRONLY | O_CREAT,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionIsHidden(sourceDisposition)) {
            errno = ENOENT;
            return -1;
        }
        if (PXJBFilesystemDispositionBlocksWrite(destinationDisposition)) {
            errno = PXJBFilesystemErrno(destinationDisposition);
            return -1;
        }
    }
    return orig_link ? orig_link(path1, path2) : -1;
}

static int (*orig_unlink)(const char *);
static int hook_unlink(const char *path) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemDisposition disposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         path,
                                         kPXJBFilesystemOperationWrite,
                                         O_WRONLY,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionBlocksWrite(disposition)) {
            errno = PXJBFilesystemErrno(disposition);
            return -1;
        }
    }
    return orig_unlink ? orig_unlink(path) : -1;
}

static int (*orig_remove_func)(const char *);
static int hook_remove_func(const char *path) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemDisposition disposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         path,
                                         kPXJBFilesystemOperationWrite,
                                         O_WRONLY,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionBlocksWrite(disposition)) {
            errno = PXJBFilesystemErrno(disposition);
            return -1;
        }
    }
    return orig_remove_func ? orig_remove_func(path) : -1;
}

static int (*orig_rmdir)(const char *);
static int hook_rmdir(const char *path) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem) {
        PXJBFilesystemDisposition disposition =
            PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                         path,
                                         kPXJBFilesystemOperationWrite,
                                         O_WRONLY,
                                         NULL,
                                         0);
        if (PXJBFilesystemDispositionBlocksWrite(disposition)) {
            errno = PXJBFilesystemErrno(disposition);
            return -1;
        }
    }
    return orig_rmdir ? orig_rmdir(path) : -1;
}

// --- JailbreakDetector bypass: getmntinfo ---
// P1-C: libc owns the original mount array. Never compact or mutate it in place.
// Each calling thread receives a filtered snapshot owned by this hook until that
// thread's next getmntinfo call or thread teardown.
typedef int (*PXJBGetmntinfoFunction)(struct statfs **, int);
typedef struct {
    struct statfs *entries;
    size_t capacity;
} PXJBMountSnapshotStorage;

static PXJBGetmntinfoFunction orig_getmntinfo = NULL;
static PXJBGetmntinfoFunction gJBGetmntinfoEntry = NULL;
static pthread_key_t gJBMountSnapshotKey;
static pthread_once_t gJBMountSnapshotKeyOnce = PTHREAD_ONCE_INIT;
static int gJBMountSnapshotKeyStatus = EAGAIN;

static void PXJBDestroyMountSnapshotStorage(void *context) {
    PXJBMountSnapshotStorage *storage = (PXJBMountSnapshotStorage *)context;
    if (!storage) return;
    free(storage->entries);
    storage->entries = NULL;
    storage->capacity = 0;
    free(storage);
}

static void PXJBCreateMountSnapshotKey(void) {
    gJBMountSnapshotKeyStatus = pthread_key_create(&gJBMountSnapshotKey,
                                                    PXJBDestroyMountSnapshotStorage);
}

static BOOL PXJBPrepareMountSnapshotOwner(void) {
    pthread_once(&gJBMountSnapshotKeyOnce, PXJBCreateMountSnapshotKey);
    return gJBMountSnapshotKeyStatus == 0;
}

static PXJBMountSnapshotStorage *PXJBGetMountSnapshotStorage(void) {
    if (!PXJBPrepareMountSnapshotOwner()) return NULL;
    PXJBMountSnapshotStorage *storage =
        (PXJBMountSnapshotStorage *)pthread_getspecific(gJBMountSnapshotKey);
    if (storage) return storage;

    storage = (PXJBMountSnapshotStorage *)calloc(1, sizeof(*storage));
    if (!storage) return NULL;
    if (pthread_setspecific(gJBMountSnapshotKey, storage) != 0) {
        free(storage);
        return NULL;
    }
    return storage;
}

static BOOL PXJBEnsureMountSnapshotCapacity(PXJBMountSnapshotStorage *storage,
                                            size_t count) {
    if (!storage) return NO;
    if (count <= storage->capacity) return YES;
    if (count > SIZE_MAX / sizeof(struct statfs)) return NO;

    struct statfs *replacement =
        (struct statfs *)realloc(storage->entries, count * sizeof(struct statfs));
    if (!replacement) return NO;
    storage->entries = replacement;
    storage->capacity = count;
    return YES;
}

static int PXJBOriginalGetmntinfo(struct statfs **mntbufp, int flags) {
    PXJBGetmntinfoFunction function = orig_getmntinfo;
    if (!function || function == gJBGetmntinfoEntry) {
        errno = ENOSYS;
        return 0;
    }
    return function(mntbufp, flags);
}

static BOOL PXJBMountPathShouldHide(const char *path) {
    if (!path || !path[0]) return NO;
    if (strcmp(path, "/var/jb") == 0 || PXHasPrefix(path, "/var/jb/")) return YES;
    if (strcmp(path, "/private/var/jb") == 0 ||
        PXHasPrefix(path, "/private/var/jb/")) {
        return YES;
    }
    return PXJBPrivatePrebootPathShouldHide(path);
}

static BOOL PXJBMountSourceShouldHide(const char *source) {
    if (!source || !source[0]) return NO;
    if (PXJBMountPathShouldHide(source)) return YES;

    // APFS snapshot sources can encode a mounted path after '@'. Only inspect
    // path-valued suffixes; ordinary Apple snapshot names remain visible.
    const char *cursor = source;
    while ((cursor = strchr(cursor, '@')) != NULL) {
        cursor++;
        if (*cursor == '/' && PXJBMountPathShouldHide(cursor)) return YES;
    }
    return NO;
}

static BOOL PXJBKnownSystemBindMountPath(const char *path) {
    if (!path) return NO;
    static const char *const knownBinds[] = {
        "/usr/standalone/firmware",
        "/System/Library/Pearl/ReferenceFrames",
        "/System/Library/Caches/com.apple.factorydata",
        NULL
    };
    for (size_t i = 0; knownBinds[i]; i++) {
        if (strcmp(path, knownBinds[i]) == 0) return YES;
    }
    return NO;
}

static BOOL PXJBMountEntryShouldHide(const struct statfs *entry) {
    if (!entry) return NO;

    BOOL jailbreakMount = PXJBMountPathShouldHide(entry->f_mntonname) ||
                          PXJBMountSourceShouldHide(entry->f_mntfromname);

    if (strcmp(entry->f_fstypename, "bindfs") == 0) {
        if (PXJBKnownSystemBindMountPath(entry->f_mntonname)) return NO;
        // Unknown bindfs mounts are not jailbreak evidence by themselves.
        return jailbreakMount;
    }

    if (strcmp(entry->f_mntonname, "/") != 0 &&
        strcmp(entry->f_fstypename, "apfs") == 0 &&
        strchr(entry->f_mntfromname, '@') != NULL) {
        return jailbreakMount;
    }
    return NO;
}

static int hook_getmntinfo(struct statfs **mntbufp, int flags) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    int count = PXJBOriginalGetmntinfo(mntbufp, flags);
    if (!pxjbFilterFilesystem || count <= 0 || !mntbufp || !*mntbufp) return count;

    PXJBMountSnapshotStorage *storage = PXJBGetMountSnapshotStorage();
    if (!storage || !PXJBEnsureMountSnapshotCapacity(storage, (size_t)count)) {
        // Allocation/key failure must not corrupt or replace libc's snapshot.
        return count;
    }

    const struct statfs *source = *mntbufp;
    int visibleCount = 0;
    for (int i = 0; i < count; i++) {
        if (PXJBMountEntryShouldHide(&source[i])) continue;
        storage->entries[visibleCount++] = source[i];
    }

    *mntbufp = storage->entries;
    return visibleCount;
}

// --- JailbreakDetector bypass: bootstrap_look_up ---
// Blocks Mach service lookups for known JB daemons.
static kern_return_t (*orig_bootstrap_look_up)(mach_port_t, const char *, mach_port_t *);
static kern_return_t hook_bootstrap_look_up(mach_port_t bp, const char *service_name, mach_port_t *sp) {
    if (PXJBShouldBypassCached() && service_name) {
        static const char *deny[] = {
            "cy:com.saurik.substrated",
            "org.coolstar.jailbreakd",
            "jailbreakd",
            "cy:com.opa334.jailbreakd",
            "lh:com.opa334.jailbreakd",
            "com.opa334.jailbreakd",
            NULL
        };
        for (int i = 0; deny[i]; i++) {
            if (strcmp(service_name, deny[i]) == 0) {
                if (sp) *sp = MACH_PORT_NULL;
                return BOOTSTRAP_UNKNOWN_SERVICE;
            }
        }
        // Also block cy: and lh: prefixed probes generically
        if (strncmp(service_name, "cy:", 3) == 0 || strncmp(service_name, "lh:", 3) == 0) {
            if (sp) *sp = MACH_PORT_NULL;
            return BOOTSTRAP_UNKNOWN_SERVICE;
        }
    }
    return orig_bootstrap_look_up ? orig_bootstrap_look_up(bp, service_name, sp) : BOOTSTRAP_UNKNOWN_SERVICE;
}

// P1-E: vm_region_64 and task_get_exception_ports are intentionally absent
// from the default module. Reintroducing either requires a separate explicit
// capability, dedicated install audit and per-target compatibility evidence.

// P0-A: no generic fcntl hook is installed. A C variadic wrapper cannot safely
// preserve unknown command argument types, so production code only issues the
// verified F_GETPATH call through PXJBOriginalFcntlGetPath().

// --- JailbreakDetector bypass: xpc_pipe_routine ---
// Block JB-server XPC queries (Dopamine jb-domain, launchd deplatformization probes).
static int (*orig_xpc_pipe_routine)(xpc_object_t, xpc_object_t, xpc_object_t *);
static int hook_xpc_pipe_routine(xpc_object_t pipe, xpc_object_t request, xpc_object_t *reply) {
    if (PXJBShouldBypassCached() && request) {
        // Block launchd deplatformization probe (subsystem=3, routine=815)
        if (xpc_get_type(request) == XPC_TYPE_DICTIONARY) {
            uint64_t subsystem = xpc_dictionary_get_uint64(request, "subsystem");
            uint64_t routine = xpc_dictionary_get_uint64(request, "routine");
            if (subsystem == 3 && routine == 815) {
                if (reply) *reply = NULL;
                return 154; // Expected error code for non-jailbroken device
            }
        }
    }
    return orig_xpc_pipe_routine ? orig_xpc_pipe_routine(pipe, request, reply) : -1;
}

static int (*orig_xpc_pipe_routine_with_flags)(xpc_object_t, xpc_object_t, xpc_object_t *, uint64_t);
static int hook_xpc_pipe_routine_with_flags(xpc_object_t pipe, xpc_object_t request, xpc_object_t *reply, uint64_t flags) {
    if (PXJBShouldBypassCached() && request) {
        // Block jb-domain XPC queries (Dopamine jb server)
        if (xpc_get_type(request) == XPC_TYPE_DICTIONARY) {
            uint64_t jb_domain = xpc_dictionary_get_uint64(request, "jb-domain");
            if (jb_domain != 0) {
                if (reply) *reply = NULL;
                return -1; // Simulate no JB server
            }
        }
    }
    return orig_xpc_pipe_routine_with_flags ? orig_xpc_pipe_routine_with_flags(pipe, request, reply, flags) : -1;
}

// Foundation directory enumeration must classify child entries against the
// directory root captured when enumeration begins. Relative children are never
// resolved against a later process CWD; unresolved roots fail open.
static char kPXJBDirectoryEnumeratorBasePathKey;

static void PXJBSetNoSuchDirectoryError(NSError **error) {
    if (!error) return;
    *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                 code:NSFileNoSuchFileError
                             userInfo:nil];
}

static NSString *PXJBResolvedDirectoryBasePath(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || path.length == 0) return nil;

    const char *fileSystemPath = [path fileSystemRepresentation];
    if (!fileSystemPath || !fileSystemPath[0]) return nil;

    char resolvedPath[PATH_MAX];
    if (!PXJBResolveAtPathForFiltering(AT_FDCWD,
                                       fileSystemPath,
                                       resolvedPath,
                                       sizeof(resolvedPath))) {
        return nil;
    }

    return [[NSString alloc] initWithBytes:resolvedPath
                                    length:strlen(resolvedPath)
                                  encoding:NSUTF8StringEncoding];
}

static BOOL PXJBRelativeDirectoryChildShouldHide(NSString *basePath,
                                                  NSString *childPath) {
    if (![childPath isKindOfClass:[NSString class]] || childPath.length == 0) {
        return NO;
    }

    NSString *fullPath = nil;
    if ([childPath isAbsolutePath]) {
        fullPath = childPath;
    } else if ([basePath isKindOfClass:[NSString class]] && basePath.length > 0) {
        fullPath = [basePath stringByAppendingPathComponent:childPath];
    } else {
        return NO;
    }

    const char *fileSystemPath = [fullPath fileSystemRepresentation];
    return fileSystemPath && PXJBPathShouldHide(fileSystemPath);
}

static NSArray *PXJBFilterRelativeDirectoryChildren(NSArray *children,
                                                      NSString *basePath) {
    if (![children isKindOfClass:[NSArray class]] || children.count == 0 ||
        ![basePath isKindOfClass:[NSString class]] || basePath.length == 0) {
        return children;
    }

    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:children.count];
    BOOL changed = NO;
    for (id child in children) {
        if ([child isKindOfClass:[NSString class]] &&
            PXJBRelativeDirectoryChildShouldHide(basePath, (NSString *)child)) {
            changed = YES;
            continue;
        }
        [filtered addObject:child];
    }
    return changed ? [filtered copy] : children;
}

// --- ObjC hooks ---
%hook NSFileManager

- (BOOL)fileExistsAtPath:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return NO;
    }
    return %orig;
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) {
            if (isDirectory) *isDirectory = NO;
            return NO;
        }
    }
    return %orig;
}

- (BOOL)isReadableFileAtPath:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return NO;
    }
    return %orig;
}

- (BOOL)isWritableFileAtPath:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) return NO;
    }
    return %orig;
}

- (BOOL)isExecutableFileAtPath:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return NO;
    }
    return %orig;
}

- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) {
            if (error) {
                *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            }
            return nil;
        }
    }
    return %orig;
}

- (NSArray<NSString *> *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    NSString *basePath = nil;
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) {
            PXJBSetNoSuchDirectoryError(error);
            return nil;
        }
        basePath = PXJBResolvedDirectoryBasePath(path);
    }

    NSArray<NSString *> *orig = %orig;
    if (!PXJBShouldBypassCached()) return orig;
    return (NSArray<NSString *> *)PXJBFilterRelativeDirectoryChildren(orig, basePath);
}

- (NSString *)destinationOfSymbolicLinkAtPath:(NSString *)path error:(NSError **)error {
    NSString *dest = %orig;
    if (!PXJBShouldBypassCached()) return dest;
    if (![dest isKindOfClass:[NSString class]] || dest.length == 0) return dest;
    const char *p = [dest fileSystemRepresentation];
    if (PXJBPathShouldHide(p)) {
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
        }
        return nil;
    }
    return dest;
}

// --- Priority 2: Extended NSFileManager methods ---

- (NSDictionary *)attributesOfFileSystemForPath:(NSString *)path error:(NSError **)error {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return nil;
        }
    }
    return %orig;
}

- (NSArray<NSURL *> *)contentsOfDirectoryAtURL:(NSURL *)url includingPropertiesForKeys:(NSArray<NSURLResourceKey> *)keys options:(NSDirectoryEnumerationOptions)mask error:(NSError **)error {
    NSArray *ret = %orig;
    if (!PXJBShouldBypassCached()) return ret;
    if (![ret isKindOfClass:[NSArray class]] || ret.count == 0) return ret;

    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:ret.count];
    for (NSURL *retURL in ret) {
        if ([retURL isKindOfClass:[NSURL class]] && [retURL isFileURL]) {
            const char *p = [[retURL path] fileSystemRepresentation];
            if (PXJBPathShouldHide(p)) continue;
        }
        [filtered addObject:retURL];
    }
    return [filtered copy];
}

- (NSArray<NSURL *> *)URLsForDirectory:(NSSearchPathDirectory)directory inDomains:(NSSearchPathDomainMask)domainMask {
    NSArray *ret = %orig;
    if (!PXJBShouldBypassCached()) return ret;
    if (![ret isKindOfClass:[NSArray class]] || ret.count == 0) return ret;

    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:ret.count];
    for (NSURL *u in ret) {
        if ([u isKindOfClass:[NSURL class]] && [u isFileURL]) {
            const char *p = [[u path] fileSystemRepresentation];
            if (PXJBPathShouldHide(p)) continue;
        }
        [filtered addObject:u];
    }
    return [filtered copy];
}

- (NSDirectoryEnumerator<NSString *> *)enumeratorAtPath:(NSString *)path {
    NSString *basePath = nil;
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
        basePath = PXJBResolvedDirectoryBasePath(path);
    }

    NSDirectoryEnumerator<NSString *> *enumerator = %orig;
    if (enumerator && basePath) {
        objc_setAssociatedObject(enumerator,
                                 &kPXJBDirectoryEnumeratorBasePathKey,
                                 basePath,
                                 OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    return enumerator;
}

- (NSArray<NSString *> *)subpathsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    NSString *basePath = nil;
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) {
            PXJBSetNoSuchDirectoryError(error);
            return nil;
        }
        basePath = PXJBResolvedDirectoryBasePath(path);
    }

    NSArray<NSString *> *ret = %orig;
    if (!PXJBShouldBypassCached()) return ret;
    return (NSArray<NSString *> *)PXJBFilterRelativeDirectoryChildren(ret, basePath);
}

- (NSArray<NSString *> *)subpathsAtPath:(NSString *)path {
    NSString *basePath = nil;
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
        basePath = PXJBResolvedDirectoryBasePath(path);
    }

    NSArray<NSString *> *ret = %orig;
    if (!PXJBShouldBypassCached()) return ret;
    return (NSArray<NSString *> *)PXJBFilterRelativeDirectoryChildren(ret, basePath);
}

- (BOOL)copyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error {
    if (PXJBShouldBypassCached()) {
        BOOL srcHide = [srcPath isKindOfClass:[NSString class]] && PXJBPathShouldHide([srcPath fileSystemRepresentation]);
        BOOL dstBlock = [dstPath isKindOfClass:[NSString class]] && PXJBPathShouldBlockWrite([dstPath fileSystemRepresentation]);
        if (srcHide || dstBlock) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return NO;
        }
    }
    return %orig;
}

- (BOOL)copyItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL error:(NSError **)error {
    if (PXJBShouldBypassCached()) {
        BOOL srcHide = [srcURL isKindOfClass:[NSURL class]] && [srcURL isFileURL] && PXJBPathShouldHide([[srcURL path] fileSystemRepresentation]);
        BOOL dstBlock = [dstURL isKindOfClass:[NSURL class]] && [dstURL isFileURL] && PXJBPathShouldBlockWrite([[dstURL path] fileSystemRepresentation]);
        if (srcHide || dstBlock) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return NO;
        }
    }
    return %orig;
}

- (BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error {
    if (PXJBShouldBypassCached()) {
        BOOL srcHide = [srcPath isKindOfClass:[NSString class]] && PXJBPathShouldHide([srcPath fileSystemRepresentation]);
        BOOL dstBlock = [dstPath isKindOfClass:[NSString class]] && PXJBPathShouldBlockWrite([dstPath fileSystemRepresentation]);
        if (srcHide || dstBlock) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return NO;
        }
    }
    return %orig;
}

- (BOOL)moveItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL error:(NSError **)error {
    if (PXJBShouldBypassCached()) {
        BOOL srcHide = [srcURL isKindOfClass:[NSURL class]] && [srcURL isFileURL] && PXJBPathShouldHide([[srcURL path] fileSystemRepresentation]);
        BOOL dstBlock = [dstURL isKindOfClass:[NSURL class]] && [dstURL isFileURL] && PXJBPathShouldBlockWrite([[dstURL path] fileSystemRepresentation]);
        if (srcHide || dstBlock) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return NO;
        }
    }
    return %orig;
}

- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return NO;
        }
    }
    return %orig;
}

- (BOOL)createDirectoryAtURL:(NSURL *)url withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return NO;
        }
    }
    return %orig;
}

- (BOOL)createFileAtPath:(NSString *)path contents:(NSData *)data attributes:(NSDictionary *)attr {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) return NO;
    }
    return %orig;
}

- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return NO;
        }
    }
    return %orig;
}

- (BOOL)removeItemAtURL:(NSURL *)URL error:(NSError **)error {
    if (PXJBShouldBypassCached() && [URL isKindOfClass:[NSURL class]] && [URL isFileURL]) {
        const char *p = [[URL path] fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return NO;
        }
    }
    return %orig;
}

- (BOOL)linkItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error {
    if (PXJBShouldBypassCached()) {
        BOOL srcHide = [srcPath isKindOfClass:[NSString class]] && PXJBPathShouldHide([srcPath fileSystemRepresentation]);
        BOOL dstBlock = [dstPath isKindOfClass:[NSString class]] && PXJBPathShouldBlockWrite([dstPath fileSystemRepresentation]);
        if (srcHide || dstBlock) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return NO;
        }
    }
    return %orig;
}

- (BOOL)createSymbolicLinkAtPath:(NSString *)path withDestinationPath:(NSString *)destPath error:(NSError **)error {
    if (PXJBShouldBypassCached()) {
        BOOL linkBlock = [path isKindOfClass:[NSString class]] && PXJBPathShouldBlockWrite([path fileSystemRepresentation]);
        BOOL targetHide = [destPath isKindOfClass:[NSString class]] && PXJBPathShouldHide([destPath fileSystemRepresentation]);
        if (linkBlock || targetHide) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return NO;
        }
    }
    return %orig;
}

%end

static BOOL PXJBCallStackAddressBelongsToHiddenImage(uintptr_t address) {
    if (address == 0) return NO;
    Dl_info info = {0};
    if (!dladdr((const void *)address, &info) || !info.dli_fname) return NO;
    return PXJBShouldHideImageName(info.dli_fname);
}

static BOOL PXJBCopyAddressFromCallStackSymbol(NSString *symbol, uintptr_t *outAddress) {
    if (![symbol isKindOfClass:[NSString class]] || !outAddress) return NO;
    NSRange prefix = [symbol rangeOfString:@"0x"];
    if (prefix.location == NSNotFound || NSMaxRange(prefix) >= symbol.length) return NO;
    NSString *hex = [symbol substringFromIndex:NSMaxRange(prefix)];
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    unsigned long long parsed = 0;
    if (![scanner scanHexLongLong:&parsed] || parsed == 0) return NO;
    *outAddress = (uintptr_t)parsed;
    return YES;
}

%hook NSThread

+ (NSArray<NSNumber *> *)callStackReturnAddresses {
    NSArray<NSNumber *> *original = %orig;
    if (!PXJBShouldBypassCached()) return original;
    return (NSArray<NSNumber *> *)PXP1CJBArrayByReplacingMatchingObjects(
        original,
        YES,
        ^BOOL(id object) {
            if (![object isKindOfClass:[NSNumber class]]) return NO;
            uintptr_t address = (uintptr_t)[(NSNumber *)object unsignedLongLongValue];
            return PXJBCallStackAddressBelongsToHiddenImage(address);
        },
        @0);
}

+ (NSArray<NSString *> *)callStackSymbols {
    NSArray<NSString *> *original = %orig;
    if (!PXJBShouldBypassCached()) return original;
    return (NSArray<NSString *> *)PXP1CJBArrayByReplacingMatchingObjects(
        original,
        YES,
        ^BOOL(id object) {
            if (![object isKindOfClass:[NSString class]]) return NO;
            uintptr_t address = 0;
            return PXJBCopyAddressFromCallStackSymbol((NSString *)object, &address) &&
                   PXJBCallStackAddressBelongsToHiddenImage(address);
        },
        @"<redacted frame>");
}

%end

%hook NSProcessInfo

- (NSArray<NSString *> *)arguments {
    NSArray<NSString *> *original = %orig;
    return (NSArray<NSString *> *)PXP1CJBFilterProcessArguments(original,
                                                                 PXJBShouldBypassCached());
}

- (NSDictionary<NSString *, NSString *> *)environment {
    NSDictionary *env = %orig;
    if (!PXJBShouldBypassCached()) return env;
    if (![env isKindOfClass:[NSDictionary class]] || env.count == 0) return env;

    NSMutableDictionary *out = [env mutableCopy];
    for (size_t i = 0; kPXJBAlwaysHiddenEnvironmentKeys[i]; i++) {
        NSString *key = [NSString stringWithUTF8String:kPXJBAlwaysHiddenEnvironmentKeys[i]];
        if (key) [out removeObjectForKey:key];
    }

    NSString *shell = out[@"SHELL"];
    if ([shell isKindOfClass:[NSString class]] &&
        PXJBShellEnvironmentValueShouldHide([shell UTF8String])) {
        [out removeObjectForKey:@"SHELL"];
    }
    return [out copy];
}

%end

%hook UIApplication

- (BOOL)canOpenURL:(NSURL *)url {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] &&
        PXP1CJBURLSchemeShouldHide(url.scheme)) {
        return NO;
    }
    return %orig;
}

%end

static NSSet<NSString *> *PXJBWorkspaceHiddenApplicationIdentifiers(void) {
    static NSSet<NSString *> *identifiers = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        identifiers = [NSSet setWithArray:@[
            @"com.saurik.Cydia",
            @"org.coolstar.SileoStore",
            @"com.opa334.Sileo",
            @"xyz.willy.Zebra",
            @"com.tigisoftware.Filza",
        ]];
    });
    return identifiers;
}

static NSSet<NSString *> *PXJBWorkspaceHiddenPluginOwnerIdentifiers(void) {
    static NSSet<NSString *> *identifiers = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        identifiers = [NSSet setWithArray:@[
            @"com.xina.jailbreak",
            @"com.opa334.Dopamine",
            @"com.tigisoftware.Filza",
            @"org.coolstar.SileoStore",
            @"org.coolstar.Sileo",
            @"ws.hbang.Terminal",
            @"xyz.willy.Zebra",
            @"shshd",
            @"com.saurik.Cydia",
        ]];
    });
    return identifiers;
}

static NSArray *PXJBFilterWorkspaceApplications(NSArray *applications) {
    if (![applications isKindOfClass:[NSArray class]] || applications.count == 0) {
        return applications;
    }

    NSSet<NSString *> *deny = PXJBWorkspaceHiddenApplicationIdentifiers();
    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:applications.count];
    BOOL changed = NO;
    for (id proxy in applications) {
        NSString *bundleIdentifier = nil;
        if ([proxy respondsToSelector:@selector(bundleIdentifier)]) {
            bundleIdentifier = [(LSBundleProxy *)proxy bundleIdentifier];
        }
        if ([bundleIdentifier isKindOfClass:[NSString class]] &&
            [deny containsObject:bundleIdentifier]) {
            changed = YES;
            continue;
        }
        [filtered addObject:proxy];
    }
    return changed ? [filtered copy] : applications;
}

static NSArray *PXJBFilterWorkspacePlugins(NSArray *plugins) {
    if (![plugins isKindOfClass:[NSArray class]] || plugins.count == 0) {
        return plugins;
    }

    NSSet<NSString *> *deny = PXJBWorkspaceHiddenPluginOwnerIdentifiers();
    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:plugins.count];
    BOOL changed = NO;
    for (id plugin in plugins) {
        NSString *ownerIdentifier = nil;
        if ([plugin respondsToSelector:@selector(containingBundle)]) {
            LSBundleProxy *owner = [(LSPlugInKitProxy *)plugin containingBundle];
            if ([owner respondsToSelector:@selector(bundleIdentifier)]) {
                ownerIdentifier = [owner bundleIdentifier];
            }
        }
        if ([ownerIdentifier isKindOfClass:[NSString class]] &&
            [deny containsObject:ownerIdentifier]) {
            changed = YES;
            continue;
        }

        NSString *pluginIdentifier = nil;
        if ([plugin respondsToSelector:@selector(pluginIdentifier)]) {
            pluginIdentifier = [(LSPlugInKitProxy *)plugin pluginIdentifier];
        }
        if ([pluginIdentifier isKindOfClass:[NSString class]] &&
            [deny containsObject:pluginIdentifier]) {
            changed = YES;
            continue;
        }
        [filtered addObject:plugin];
    }
    return changed ? [filtered copy] : plugins;
}

%hook LSApplicationWorkspace

- (NSArray *)allInstalledApplications {
    NSArray *applications = %orig;
    if (!PXJBShouldBypassCached()) return applications;
    return PXJBFilterWorkspaceApplications(applications);
}

- (NSArray *)installedApplications {
    NSArray *applications = %orig;
    if (!PXJBShouldBypassCached()) return applications;
    return PXJBFilterWorkspaceApplications(applications);
}

- (NSArray *)allApplications {
    NSArray *applications = %orig;
    if (!PXJBShouldBypassCached()) return applications;
    return PXJBFilterWorkspaceApplications(applications);
}

- (NSArray *)installedPlugins {
    NSArray *plugins = %orig;
    if (!PXJBShouldBypassCached()) return plugins;
    return PXJBFilterWorkspacePlugins(plugins);
}

%end

// --- Priority 1: NSBundle SignerIdentity ---
%hook NSBundle

- (id)objectForInfoDictionaryKey:(NSString *)key {
    if (PXJBShouldBypassCached() && [key isKindOfClass:[NSString class]]) {
        if ([key isEqualToString:@"SignerIdentity"]) {
            return nil;
        }
    }
    return %orig;
}

+ (instancetype)bundleWithPath:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

- (instancetype)initWithPath:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

%end

// --- Priority 2: NSFileHandle hooks ---
%hook NSFileHandle

+ (instancetype)fileHandleForReadingAtPath:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

+ (instancetype)fileHandleForReadingFromURL:(NSURL *)url error:(NSError **)error {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return nil;
        }
    }
    return %orig;
}

+ (instancetype)fileHandleForWritingAtPath:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) return nil;
    }
    return %orig;
}

+ (instancetype)fileHandleForWritingToURL:(NSURL *)url error:(NSError **)error {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return nil;
        }
    }
    return %orig;
}

+ (instancetype)fileHandleForUpdatingAtPath:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) return nil;
    }
    return %orig;
}

%end

// --- Priority 2: UIImage hooks ---
%hook UIImage

- (instancetype)initWithContentsOfFile:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

+ (UIImage *)imageWithContentsOfFile:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

%end

// --- Priority 2: NSString file read/write hooks ---
%hook NSString

- (instancetype)initWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)enc error:(NSError **)error {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return nil;
        }
    }
    return %orig;
}

- (instancetype)initWithContentsOfFile:(NSString *)path usedEncoding:(NSStringEncoding *)enc error:(NSError **)error {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return nil;
        }
    }
    return %orig;
}

+ (instancetype)stringWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)enc error:(NSError **)error {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return nil;
        }
    }
    return %orig;
}

+ (instancetype)stringWithContentsOfFile:(NSString *)path usedEncoding:(NSStringEncoding *)enc error:(NSError **)error {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return nil;
        }
    }
    return %orig;
}

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile encoding:(NSStringEncoding)enc error:(NSError **)error {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return NO;
        }
    }
    return %orig;
}

- (BOOL)writeToURL:(NSURL *)url atomically:(BOOL)useAuxiliaryFile encoding:(NSStringEncoding)enc error:(NSError **)error {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return NO;
        }
    }
    return %orig;
}

%end

// --- Priority 2: NSArray file read/write hooks ---
%hook NSArray

- (id)initWithContentsOfFile:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

+ (id)arrayWithContentsOfFile:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

+ (id)arrayWithContentsOfURL:(NSURL *)url {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) return NO;
    }
    return %orig;
}

- (BOOL)writeToURL:(NSURL *)url atomically:(BOOL)atomically {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) return NO;
    }
    return %orig;
}

%end

%hook NSMutableArray

- (id)initWithContentsOfFile:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

- (id)initWithContentsOfURL:(NSURL *)url {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

%end

// --- Priority 2: NSDictionary file read/write hooks ---
%hook NSDictionary

- (id)initWithContentsOfFile:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

- (id)initWithContentsOfURL:(NSURL *)url {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

+ (id)dictionaryWithContentsOfFile:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

+ (id)dictionaryWithContentsOfURL:(NSURL *)url {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) return NO;
    }
    return %orig;
}

- (BOOL)writeToURL:(NSURL *)url atomically:(BOOL)atomically {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) return NO;
    }
    return %orig;
}

- (BOOL)writeToURL:(NSURL *)url error:(NSError **)error {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return NO;
        }
    }
    return %orig;
}

%end

%hook NSMutableDictionary

- (id)initWithContentsOfFile:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

- (id)initWithContentsOfURL:(NSURL *)url {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

%end

// --- Priority 2: NSData file read/write hooks ---
%hook NSData

- (instancetype)initWithContentsOfFile:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

- (instancetype)initWithContentsOfFile:(NSString *)path options:(NSDataReadingOptions)readOptionsMask error:(NSError **)error {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return nil;
        }
    }
    return %orig;
}

- (instancetype)initWithContentsOfURL:(NSURL *)url {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

- (instancetype)initWithContentsOfURL:(NSURL *)url options:(NSDataReadingOptions)readOptionsMask error:(NSError **)error {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return nil;
        }
    }
    return %orig;
}

+ (instancetype)dataWithContentsOfFile:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

+ (instancetype)dataWithContentsOfFile:(NSString *)path options:(NSDataReadingOptions)readOptionsMask error:(NSError **)error {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return nil;
        }
    }
    return %orig;
}

+ (instancetype)dataWithContentsOfURL:(NSURL *)url {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

+ (instancetype)dataWithContentsOfURL:(NSURL *)url options:(NSDataReadingOptions)readOptionsMask error:(NSError **)error {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return nil;
        }
    }
    return %orig;
}

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) return NO;
    }
    return %orig;
}

- (BOOL)writeToFile:(NSString *)path options:(NSDataWritingOptions)writeOptionsMask error:(NSError **)error {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return NO;
        }
    }
    return %orig;
}

- (BOOL)writeToURL:(NSURL *)url atomically:(BOOL)useAuxiliaryFile {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) return NO;
    }
    return %orig;
}

- (BOOL)writeToURL:(NSURL *)url options:(NSDataWritingOptions)writeOptionsMask error:(NSError **)error {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return NO;
        }
    }
    return %orig;
}

%end

// --- Priority 2: Known JB detection library class hooks ---
// Detector SDK classes can be loaded after Logos initialization. Keep a
// table-driven runtime installer and re-check it after every added image.
typedef enum {
    kPXJBDetectionReturnFalse = 0,
    kPXJBDetectionReturnTrue,
    kPXJBDetectionReturnNull,
} PXJBDetectionReturnPolicy;

typedef struct {
    const char *className;
    const char *selectorName;
    bool classMethod;
    PXJBDetectionReturnPolicy returnPolicy;
    bool installed;
    IMP original;
    IMP replacement;
} PXJBDetectionHookRule;

#define PXJB_DETECTION_RULE(cls, sel, isClass, policy) \
    { (cls), (sel), (isClass), (policy), false, NULL, NULL }

static PXJBDetectionHookRule kPXJBDetectionHookRules[] = {
    PXJB_DETECTION_RULE("UIDevice", "isJailbroken", true, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("UIDevice", "isJailBreak", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("UIDevice", "isJailBroken", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("JailbreakDetectionVC", "isJailbroken", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("DTTJailbreakDetection", "isJailbroken", true, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("ANSMetadata", "computeIsJailbroken", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("ANSMetadata", "isJailbroken", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("AppsFlyerUtils", "isJailBreakon", true, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("GBDeviceInfo", "isJailbroken", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("CMARAppRestrictionsDelegate", "isDeviceNonCompliant", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("ADYSecurityChecks", "isDeviceJailbroken", true, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("UBReportMetadataDevice", "is_rooted", false, kPXJBDetectionReturnNull),
    PXJB_DETECTION_RULE("UtilitySystem", "isJailbreak", true, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("GemaltoConfiguration", "isJailbreak", true, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("CPWRDeviceInfo", "isJailbroken", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("CPWRSessionInfo", "isJailbroken", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("KSSystemInfo", "isJailbroken", true, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("EMDSKPPConfiguration", "jailBroken", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("EnrollParameters", "jailbroken", false, kPXJBDetectionReturnNull),
    PXJB_DETECTION_RULE("EMDskppConfigurationBuilder", "jailbreakStatus", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("FCRSystemMetadata", "isJailbroken", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("v_VDMap", "isJailBrokenDetectedByVOS", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("v_VDMap", "isDFPHookedDetecedByVOS", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("v_VDMap", "isCodeInjectionDetectedByVOS", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("v_VDMap", "isDebuggerCheckDetectedByVOS", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("v_VDMap", "isAppSignerCheckDetectedByVOS", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("v_VDMap", "v_checkAModified", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("SDMUtils", "isJailBroken", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("OneSignalJailbreakDetection", "isJailbroken", true, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("DigiPassHandler", "rootedDeviceTestResult", false, kPXJBDetectionReturnFalse),
    PXJB_DETECTION_RULE("AWMyDeviceGeneralInfo", "isCompliant", false, kPXJBDetectionReturnTrue),
};

#undef PXJB_DETECTION_RULE

static dispatch_queue_t gJBLateDetectionHookQueue = NULL;
static _Atomic(bool) gJBLateDetectionMonitorStarted = false;
static _Atomic(bool) gJBLateDetectionInstallPending = false;

static dispatch_queue_t PXJBLateDetectionQueue(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gJBLateDetectionHookQueue = dispatch_queue_create(
            "com.weaponx.jailbreak-bypass.late-detection-hooks",
            DISPATCH_QUEUE_SERIAL);
    });
    return gJBLateDetectionHookQueue;
}

static IMP PXJBCreateDetectionReplacement(PXJBDetectionHookRule *rule,
                                           SEL selector) {
    if (!rule || !selector) return NULL;

    switch (rule->returnPolicy) {
        case kPXJBDetectionReturnTrue:
            return imp_implementationWithBlock(^BOOL(id receiver) {
                if (PXJBShouldBypassCached()) return YES;
                IMP original = rule->original;
                return original && original != rule->replacement
                    ? ((BOOL (*)(id, SEL))original)(receiver, selector)
                    : YES;
            });
        case kPXJBDetectionReturnNull:
            return imp_implementationWithBlock(^void *(id receiver) {
                if (PXJBShouldBypassCached()) return NULL;
                IMP original = rule->original;
                return original && original != rule->replacement
                    ? ((void *(*)(id, SEL))original)(receiver, selector)
                    : NULL;
            });
        case kPXJBDetectionReturnFalse:
        default:
            return imp_implementationWithBlock(^BOOL(id receiver) {
                if (PXJBShouldBypassCached()) return NO;
                IMP original = rule->original;
                return original && original != rule->replacement
                    ? ((BOOL (*)(id, SEL))original)(receiver, selector)
                    : NO;
            });
    }
}

static void PXJBInstallLoadedDetectionClassHooks(void) {
    for (size_t i = 0; i < PXJB_ARRAY_COUNT(kPXJBDetectionHookRules); i++) {
        PXJBDetectionHookRule *rule = &kPXJBDetectionHookRules[i];
        Class cls = objc_getClass(rule->className);
        if (!cls) continue;

        Class targetClass = rule->classMethod ? object_getClass(cls) : cls;
        SEL selector = sel_registerName(rule->selectorName);
        Method method = class_getInstanceMethod(targetClass, selector);
        if (!method) continue;

        if (rule->installed &&
            method_getImplementation(method) == rule->replacement) {
            continue;
        }
        if (!rule->replacement) {
            rule->replacement = PXJBCreateDetectionReplacement(rule, selector);
            if (!rule->replacement) continue;
        }

        // A late category can replace an already-hooked implementation. Re-run
        // MSHookMessageEx when the currently published IMP is no longer ours.
        MSHookMessageEx(targetClass,
                        selector,
                        rule->replacement,
                        &rule->original);
        rule->installed = true;
    }
}

static void PXJBRegisterDyldAddImageCallback(
    void (*callback)(const struct mach_header *, intptr_t));

static void PXJBLateDetectionImageAdded(const struct mach_header *header,
                                        intptr_t slide) {
    (void)header;
    (void)slide;
    if (!atomic_load_explicit(&gJBLateDetectionMonitorStarted,
                              memory_order_acquire)) {
        return;
    }
    if (atomic_exchange_explicit(&gJBLateDetectionInstallPending,
                                 true,
                                 memory_order_acq_rel)) {
        return;
    }

    dispatch_queue_t queue = PXJBLateDetectionQueue();
    dispatch_async(queue, ^{
        PXJBInstallLoadedDetectionClassHooks();
        atomic_store_explicit(&gJBLateDetectionInstallPending,
                              false,
                              memory_order_release);
    });
}

static void PXJBStartLateLoadedDetectionClassMonitoring(void) {
    dispatch_queue_t queue = PXJBLateDetectionQueue();
    if (!queue) return;

    atomic_store_explicit(&gJBLateDetectionMonitorStarted,
                          true,
                          memory_order_release);
    PXJBRegisterDyldAddImageCallback(PXJBLateDetectionImageAdded);
    dispatch_sync(queue, ^{
        PXJBInstallLoadedDetectionClassHooks();
    });
}

// --- Priority 3: NSDirectoryEnumerator filtering ---
%hook NSDirectoryEnumerator

- (id)nextObject {
    if (!PXJBShouldBypassCached()) return %orig;

    NSString *basePath = objc_getAssociatedObject(self,
                                                   &kPXJBDirectoryEnumeratorBasePathKey);
    id obj = %orig;
    while (obj != nil) {
        BOOL shouldHide = NO;
        if ([obj isKindOfClass:[NSURL class]]) {
            NSURL *url = (NSURL *)obj;
            if ([url isFileURL]) {
                shouldHide = PXJBRelativeDirectoryChildShouldHide(nil, [url path]);
            }
        } else if ([obj isKindOfClass:[NSString class]]) {
            shouldHide = PXJBRelativeDirectoryChildShouldHide(basePath,
                                                               (NSString *)obj);
        }

        if (!shouldHide) break;
        [self skipDescendants];
        obj = %orig;
    }
    return obj;
}

%end

// --- Priority 3: NSFileWrapper hooks ---
%hook NSFileWrapper

- (instancetype)initWithURL:(NSURL *)url options:(NSFileWrapperReadingOptions)options error:(NSError **)outError {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) {
            if (outError) *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return nil;
        }
    }
    return %orig;
}

- (instancetype)initWithPath:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

- (BOOL)writeToURL:(NSURL *)url options:(NSFileWrapperWritingOptions)options originalContentsURL:(NSURL *)originalContentsURL error:(NSError **)outError {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldBlockWrite(p)) {
            if (outError) *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return NO;
        }
    }
    return %orig;
}

- (BOOL)readFromURL:(NSURL *)url options:(NSFileWrapperReadingOptions)options error:(NSError **)outError {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) {
            if (outError) *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return NO;
        }
    }
    return %orig;
}

%end

// --- Priority 3: NSFileVersion hooks ---
%hook NSFileVersion

+ (NSFileVersion *)currentVersionOfItemAtURL:(NSURL *)url {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

+ (NSArray<NSFileVersion *> *)otherVersionsOfItemAtURL:(NSURL *)url {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] && [url isFileURL]) {
        const char *p = [[url path] fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
}

%end

// --- JailbreakDetector bypass: NSUserDefaults cfprefsd hook detection ---
// Block attempts to read JB plists via NSUserDefaults initWithSuiteName:.
static BOOL PXJBIsJBPlistSuiteName(NSString *suiteName) {
    if (!suiteName || ![suiteName isKindOfClass:[NSString class]]) return NO;
    static NSArray *jbPlistPrefixes = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        jbPlistPrefixes = @[
            @"/basebin/",
            @"com.opa334.",
            @"com.xina.",
            @"org.coolstar.",
            @"com.tigisoftware.",
            @"ws.hbang.",
            @"xyz.willy.",
            @"ru.domo.cocoatop",
            @"com.spark.snowboard",
            @"us.diatr.shshd",
            @"com.openssh.",
        ];
    });
    for (NSString *prefix in jbPlistPrefixes) {
        if ([suiteName hasPrefix:prefix]) return YES;
    }
    // Also block suite names that look like absolute JB paths
    if ([suiteName hasPrefix:@"/"] && PXJBPathShouldHide([suiteName fileSystemRepresentation])) return YES;
    return NO;
}

%hook NSUserDefaults

- (instancetype)initWithSuiteName:(NSString *)suitename {
    if (PXJBShouldBypassCached() && PXJBIsJBPlistSuiteName(suitename)) {
        // Return a blank defaults that has no stored keys
        return %orig(@"com.apple.does.not.exist.sentinel");
    }
    return %orig;
}

%end

// B-05b: optional private LaunchServices URL-probe surface. Install only when
// the runtime method exists and its ABI matches the observed iFake call shape:
// BOOL (id url, BOOL publicSchemes, BOOL privateSchemes, id connection, id *error).
typedef BOOL (*PXJBLSCanOpenURLFunction)(id, SEL, id, BOOL, BOOL, id, id *);
static PXJBLSCanOpenURLFunction gPXJBOrigLSCanOpenURL = NULL;
static _Atomic(bool) gPXJBLSCanOpenURLInstalled = false;

static const char *PXJBSkipObjCTypeQualifiers(const char *type) {
    if (!type) return NULL;
    while (*type && strchr("rnNoORV", *type)) type++;
    return type;
}

static BOOL PXJBObjCTypeIsObject(const char *type) {
    type = PXJBSkipObjCTypeQualifiers(type);
    return type && type[0] == '@';
}

static BOOL PXJBObjCTypeIsBool(const char *type) {
    type = PXJBSkipObjCTypeQualifiers(type);
    return type && (type[0] == 'B' || type[0] == 'c');
}

static BOOL PXJBObjCTypeIsObjectPointer(const char *type) {
    type = PXJBSkipObjCTypeQualifiers(type);
    return type && type[0] == '^' && PXJBObjCTypeIsObject(type + 1);
}

static BOOL PXJBLSCanOpenURLMethodEncodingMatches(Method method) {
    if (!method || method_getNumberOfArguments(method) != 7) return NO;
    char *returnType = method_copyReturnType(method);
    char *urlType = method_copyArgumentType(method, 2);
    char *publicType = method_copyArgumentType(method, 3);
    char *privateType = method_copyArgumentType(method, 4);
    char *connectionType = method_copyArgumentType(method, 5);
    char *errorType = method_copyArgumentType(method, 6);

    BOOL matches = PXJBObjCTypeIsBool(returnType) &&
                   PXJBObjCTypeIsObject(urlType) &&
                   PXJBObjCTypeIsBool(publicType) &&
                   PXJBObjCTypeIsBool(privateType) &&
                   PXJBObjCTypeIsObject(connectionType) &&
                   PXJBObjCTypeIsObjectPointer(errorType);
    free(returnType);
    free(urlType);
    free(publicType);
    free(privateType);
    free(connectionType);
    free(errorType);
    return matches;
}

static BOOL PXJBHookLSCanOpenURL(id receiver,
                                SEL selector,
                                id url,
                                BOOL publicSchemes,
                                BOOL privateSchemes,
                                id XPCConnection,
                                id *error) {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]] &&
        PXP1CJBURLSchemeShouldHide([(NSURL *)url scheme])) {
        // iFake sub_1EAF6C returns NO without clearing or writing the error out-param.
        return NO;
    }
    PXJBLSCanOpenURLFunction original = gPXJBOrigLSCanOpenURL;
    return original
        ? original(receiver, selector, url, publicSchemes, privateSchemes, XPCConnection, error)
        : NO;
}

static void PXJBInstallLSCanOpenURLManagerHook(void) {
    Class cls = objc_getClass("_LSCanOpenURLManager");
    if (!cls) return;
    SEL selector = sel_registerName("canOpenURL:publicSchemes:privateSchemes:XPCConnection:error:");
    Method method = class_getInstanceMethod(cls, selector);
    if (!PXJBLSCanOpenURLMethodEncodingMatches(method)) return;

    MSHookMessageEx(cls,
                    selector,
                    (IMP)PXJBHookLSCanOpenURL,
                    (IMP *)&gPXJBOrigLSCanOpenURL);
    BOOL installed = gPXJBOrigLSCanOpenURL != NULL &&
                     (IMP)gPXJBOrigLSCanOpenURL != (IMP)PXJBHookLSCanOpenURL;
    atomic_store_explicit(&gPXJBLSCanOpenURLInstalled, installed, memory_order_release);
}

%ctor {
    @autoreleasepool {
        // P0-C: resolve process identity and scope once, before installing hooks.
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSString *proc = [NSProcessInfo processInfo].processName;
        BOOL processEligible = PXJBProcessIsEligibleAtLaunch(bundleID, proc);
        atomic_store_explicit(&gJBProcessEligible, processEligible, memory_order_release);
        if (!processEligible) {
            PXFileDebugAIDA64Log("[JailbreakBypass.ctor] skip eligible=0 bundle=%s proc=%s",
                                bundleID.UTF8String ?: "<nil>",
                                proc.UTF8String ?: "<nil>");
            return;
        }

        NSDictionary *launchSettings = PXJBReadSecuritySettingsSnapshot();
        BOOL masterJB = PXJBSettingEnabled(launchSettings, @"jailbreakDetectionEnabled");
        if (!masterJB) {
            PXLog(@"[JailbreakBypass] master OFF at launch ? not installing JB groups/providers");
            PXFileDebugAIDA64Log("[JailbreakBypass.ctor] skip master=0");
            return;
        }

        // P1-A: capture requested capabilities, but publish an empty effective
        // mask before hook installation. The final mask is activated atomically
        // only after the install audit has verified each capability.
        PXJBPolicyMask launchRequestedMask = PXJBBuildRequestedPolicyMask(launchSettings);
        PXJBPrepareCapabilityRegistry(launchRequestedMask);
        BOOL pathMatcherReady = PXJBPathMatcherIsReady();
        if (!pathMatcherReady) {
            PXLog(@"[JailbreakBypass] optimized path matcher unavailable; using linear fallback");
        }

        BOOL wantDyldHide = (launchRequestedMask & kPXJBPolicyHideDylibs) != 0;
        BOOL wantBlockAddImage = (launchRequestedMask & kPXJBPolicyBlockDyldAddImageCallbacks) != 0;
        BOOL wantHideTaskDyldInfo = (launchRequestedMask & kPXJBPolicyHideTaskDyldInfo) != 0;
        BOOL wantHideDlIteratePhdr = (launchRequestedMask & kPXJBPolicyHideDlIteratePhdr) != 0;
        BOOL wantBlockDlopenDlsym = (launchRequestedMask & kPXJBPolicyBlockDlopenDlsymProbes) != 0;
        BOOL wantSysctlSanitize = (launchRequestedMask & kPXJBPolicySysctlProcSanitize) != 0;
        BOOL wantHideProcMaps = (launchRequestedMask & kPXJBPolicyHideProcMaps) != 0;
        BOOL wantHideObjcImages = (launchRequestedMask & kPXJBPolicyHideObjcImages) != 0;

        // Pre-install publication intentionally resolves to zero because no
        // capability has passed install audit yet.
        PXJBPublishPolicySnapshot(launchSettings);

        // Hook installation may call dlopen, logging, coordinator code and
        // filesystem APIs after the first native entry has already been patched.
        // Suppress only dependent filesystem/exec domains until ctor teardown.
        PXJB_REENTRY_SCOPE(installScope, kPXJBReentryHookInstall);
        if (!installScope.entered) return;

        // Groups conceptually:
        // JBSafeFoundation: file/process query wrappers (stat/access/open/...)
        // JBAppSpecific: Logos Foundation hooks plus runtime detector table
        // JBAggressiveRuntime: dyld/dlsym/task_info (experimental toggles only)
        // P0-B: syscall and sandbox_check are intentionally not production capabilities.
        {
            // libSystem is already loaded; FindSymbol resolves through RTLD_DEFAULT.
            void *sym = NULL;

            sym = FindSymbol("stat");
            if (sym) MSHookFunction(sym, (void *)hook_stat, (void **)&orig_stat);

            sym = FindSymbol("stat64");
            if (sym) MSHookFunction(sym, (void *)hook_stat64, (void **)&orig_stat64);

            sym = FindSymbol("lstat");
            if (sym) MSHookFunction(sym, (void *)hook_lstat, (void **)&orig_lstat);

            sym = FindSymbol("lstat64");
            if (sym) MSHookFunction(sym, (void *)hook_lstat64, (void **)&orig_lstat64);

            sym = FindSymbol("access");
            if (sym) MSHookFunction(sym, (void *)hook_access, (void **)&orig_access);

            sym = FindSymbol("open");
            if (sym) MSHookFunction(sym, (void *)hook_open, (void **)&orig_open);

            sym = FindSymbol("openat");
            if (sym) MSHookFunction(sym, (void *)hook_openat, (void **)&orig_openat);

            sym = FindSymbol("fopen");
            if (sym) MSHookFunction(sym, (void *)hook_fopen, (void **)&orig_fopen);

            // P2/B-01: install opendir/readdir/closedir as one lifecycle group.
            // __opendir2 and fdopendir are optional entry points; both reuse the same
            // classifier/lifecycle state without becoming mandatory capabilities.
            void *opendirEntry = FindSymbol("opendir");
            void *opendir2Entry = FindSymbol("__opendir2");
            void *readdirEntry = FindSymbol("readdir");
            void *readdirREntry = FindSymbol("readdir_r");
            void *closedirEntry = FindSymbol("closedir");
            void *fdopendirEntry = FindSymbol("fdopendir");
            if (opendir2Entry) {
                gJBOpenDir2Entry = (PXJBOpenDir2Function)opendir2Entry;
                MSHookFunction(opendir2Entry,
                               (void *)hook___opendir2,
                               (void **)&orig___opendir2);
            }
            if (readdirREntry) {
                gJBReaddirREntry = (PXJBReaddirRFunction)readdirREntry;
                MSHookFunction(readdirREntry,
                               (void *)hook_readdir_r,
                               (void **)&orig_readdir_r);
            }
            if (opendirEntry && readdirEntry && closedirEntry) {
                gJBOpendirEntry = (PXJBOpendirFunction)opendirEntry;
                gJBReaddirEntry = (PXJBReaddirFunction)readdirEntry;
                gJBClosedirEntry = (PXJBClosedirFunction)closedirEntry;
                gJBFdopendirEntry = (PXJBFdopendirFunction)fdopendirEntry;

                MSHookFunction(opendirEntry,
                               (void *)hook_opendir,
                               (void **)&orig_opendir);
                MSHookFunction(readdirEntry,
                               (void *)hook_readdir,
                               (void **)&orig_readdir);
                MSHookFunction(closedirEntry,
                               (void *)hook_closedir,
                               (void **)&orig_closedir);
                if (fdopendirEntry) {
                    MSHookFunction(fdopendirEntry,
                                   (void *)hook_fdopendir,
                                   (void **)&orig_fdopendir);
                }

                BOOL mandatoryReady = orig_opendir != NULL &&
                                      orig_opendir != gJBOpendirEntry &&
                                      orig_readdir != NULL &&
                                      orig_readdir != gJBReaddirEntry &&
                                      orig_closedir != NULL &&
                                      orig_closedir != gJBClosedirEntry;
                BOOL optionalReady = fdopendirEntry == NULL ||
                                     (orig_fdopendir != NULL &&
                                      orig_fdopendir != gJBFdopendirEntry);
                atomic_store_explicit(&gJBDirectoryLifecycleReady,
                                      mandatoryReady && optionalReady,
                                      memory_order_release);
                if (!mandatoryReady || !optionalReady) {
                    PXLog(@"[JailbreakBypass] directory lifecycle disabled: invalid trampoline");
                }
            } else {
                atomic_store_explicit(&gJBDirectoryLifecycleReady,
                                      false,
                                      memory_order_release);
                PXLog(@"[JailbreakBypass] directory lifecycle disabled: missing mandatory symbol");
            }

            sym = FindSymbol("readlink");
            if (sym) MSHookFunction(sym, (void *)hook_readlink, (void **)&orig_readlink);

            sym = FindSymbol("realpath");
            if (sym) MSHookFunction(sym, (void *)hook_realpath, (void **)&orig_realpath);

            // B-02: safe read-only metadata/query surfaces. Each wrapper is
            // capability-optional and preserves original buffer/size semantics.
            sym = FindSymbol("pathconf");
            if (sym) MSHookFunction(sym, (void *)hook_pathconf, (void **)&orig_pathconf);

            sym = FindSymbol("fpathconf");
            if (sym) MSHookFunction(sym, (void *)hook_fpathconf, (void **)&orig_fpathconf);

            sym = FindSymbol("getattrlist");
            if (sym) MSHookFunction(sym, (void *)hook_getattrlist, (void **)&orig_getattrlist);

            sym = FindSymbol("fgetattrlist");
            if (sym) MSHookFunction(sym, (void *)hook_fgetattrlist, (void **)&orig_fgetattrlist);

            sym = FindSymbol("getxattr");
            if (sym) MSHookFunction(sym, (void *)hook_getxattr, (void **)&orig_getxattr);

            sym = FindSymbol("fgetxattr");
            if (sym) MSHookFunction(sym, (void *)hook_fgetxattr, (void **)&orig_fgetxattr);

            sym = FindSymbol("listxattr");
            if (sym) MSHookFunction(sym, (void *)hook_listxattr, (void **)&orig_listxattr);

            sym = FindSymbol("flistxattr");
            if (sym) MSHookFunction(sym, (void *)hook_flistxattr, (void **)&orig_flistxattr);

            sym = FindSymbol("getpeername");
            if (sym) MSHookFunction(sym, (void *)hook_getpeername, (void **)&orig_getpeername);

            sym = FindSymbol("getsockname");
            if (sym) MSHookFunction(sym, (void *)hook_getsockname, (void **)&orig_getsockname);

            sym = FindSymbol("connect");
            if (sym) MSHookFunction(sym, (void *)hook_connect, (void **)&orig_connect);

            sym = FindSymbol("getenv");
            if (sym) MSHookFunction(sym, (void *)hook_getenv, (void **)&orig_getenv);

            // Phase 2
            // C-01: SystemConfiguration's debugger scalar is runtime-optional.
            // Do not dlopen the framework just to gain this capability; if the
            // symbol is not already available, preserve the process unchanged.
            sym = FindSymbol("SCIsRunningWithDebugger");
            if (sym) {
                MSHookFunction(sym,
                               (void *)hook_SCIsRunningWithDebugger,
                               (void **)&orig_SCIsRunningWithDebugger);
            }

            sym = FindSymbol("ptrace");
            if (sym) MSHookFunction(sym, (void *)hook_ptrace, (void **)&orig_ptrace);

            sym = FindSymbol("fork");
            if (sym) MSHookFunction(sym, (void *)hook_fork, (void **)&orig_fork);

            sym = FindSymbol("vfork");
            if (sym) MSHookFunction(sym, (void *)hook_vfork, (void **)&orig_vfork);

            // Priority 1: UID/GID spoofing - hide root access.
            sym = FindSymbol("issetugid");
            if (sym) MSHookFunction(sym, (void *)hook_issetugid, (void **)&orig_issetugid);

            sym = FindSymbol("getuid");
            if (sym) MSHookFunction(sym, (void *)hook_getuid, (void **)&orig_getuid);

            sym = FindSymbol("geteuid");
            if (sym) MSHookFunction(sym, (void *)hook_geteuid, (void **)&orig_geteuid);

            sym = FindSymbol("getgid");
            if (sym) MSHookFunction(sym, (void *)hook_getgid, (void **)&orig_getgid);

            sym = FindSymbol("getegid");
            if (sym) MSHookFunction(sym, (void *)hook_getegid, (void **)&orig_getegid);

            sym = FindSymbol("getgroups");
            if (sym) MSHookFunction(sym, (void *)hook_getgroups, (void **)&orig_getgroups);

            sym = FindSymbol("setuid");
            if (sym) MSHookFunction(sym, (void *)hook_setuid, (void **)&orig_setuid);

            sym = FindSymbol("seteuid");
            if (sym) MSHookFunction(sym, (void *)hook_seteuid, (void **)&orig_seteuid);

            sym = FindSymbol("setgid");
            if (sym) MSHookFunction(sym, (void *)hook_setgid, (void **)&orig_setgid);

            sym = FindSymbol("setegid");
            if (sym) MSHookFunction(sym, (void *)hook_setegid, (void **)&orig_setegid);

            sym = FindSymbol("setreuid");
            if (sym) MSHookFunction(sym, (void *)hook_setreuid, (void **)&orig_setreuid);

            sym = FindSymbol("setregid");
            if (sym) MSHookFunction(sym, (void *)hook_setregid, (void **)&orig_setregid);

            // Priority 1: getppid spoofing.
            sym = FindSymbol("getppid");
            if (sym) MSHookFunction(sym, (void *)hook_getppid, (void **)&orig_getppid);

            // Priority 1: csops — clear CS_PLATFORM_BINARY.
            sym = FindSymbol("csops");
            if (sym) MSHookFunction(sym, (void *)hook_csops, (void **)&orig_csops);

            // P0-B: syscall is intentionally not resolved or hooked.

            sym = FindSymbol("system");
            if (sym) MSHookFunction(sym, (void *)hook_system, (void **)&orig_system);

            sym = FindSymbol("popen");
            if (sym) MSHookFunction(sym, (void *)hook_popen, (void **)&orig_popen);

            // Block probe spawns (safe default; gate inside hook).
            sym = FindSymbol("posix_spawn");
            if (sym) MSHookFunction(sym, (void *)hook_posix_spawn, (void **)&orig_posix_spawn);

            sym = FindSymbol("posix_spawnp");
            if (sym) MSHookFunction(sym, (void *)hook_posix_spawnp, (void **)&orig_posix_spawnp);

            // P0-B: sandbox_check is intentionally not resolved or hooked.

            // Phase 2 extension (toggle: jbBypassStatfsEnabled)
            // statfs is coordinator-owned — register sanitizer post provider instead of MSHookFunction.
            {
                PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
                [coord installOwnedSymbolsIfNeeded];
                orig_statfs = [coord originalForSymbol:kPXNativeSymbolStatfs];
                static dispatch_once_t jbStatfsOnce;
                dispatch_once(&jbStatfsOnce, ^{
                    [coord registerStatfsProvider:@"jb.statfs.sanitize" priority:PXNativeHookPriorityJailbreakSanitize post:^(const char * _Nullable path, struct statfs * _Nullable buf, int * _Nonnull inoutResult) {
                        BOOL filterFilesystem = PXJBFilesystemFilteringAllowed();
                        PXJB_REENTRY_SCOPE(providerScope, kPXJBReentryFilesystem);
                        if (!providerScope.entered || !filterFilesystem) return;
                        if (*inoutResult != 0 || !buf) return;
                        if (PXJBStatfsBypassEnabled() && PXJBIsSensitiveMountPath(path)) {
                            PXJBNormalizeStatfs(buf);
                        }
                    }];
                    gJBStatfsProviderRegistered = true;
                });
            }

            sym = FindSymbol("fstatfs");
            if (sym) MSHookFunction(sym, (void *)hook_fstatfs, (void **)&orig_fstatfs);

            sym = FindSymbol("fstatfs64");
            if (sym) MSHookFunction(sym, (void *)hook_fstatfs64, (void **)&orig_fstatfs64);

            sym = FindSymbol("statvfs");
            if (sym) MSHookFunction(sym, (void *)hook_statvfs, (void **)&orig_statvfs);

            sym = FindSymbol("fstatvfs");
            if (sym) MSHookFunction(sym, (void *)hook_fstatvfs, (void **)&orig_fstatvfs);

            // Priority 3: dlopen_preflight, creat, fstat variants, fs mutation hooks.
            sym = FindSymbol("dlopen_preflight");
            if (sym) MSHookFunction(sym, (void *)hook_dlopen_preflight, (void **)&orig_dlopen_preflight);

            sym = FindSymbol("creat");
            if (sym) MSHookFunction(sym, (void *)hook_creat, (void **)&orig_creat);

            sym = FindSymbol("fstat");
            if (sym) MSHookFunction(sym, (void *)hook_fstat, (void **)&orig_fstat);

            sym = FindSymbol("fstat64");
            if (sym) MSHookFunction(sym, (void *)hook_fstat64, (void **)&orig_fstat64);

            sym = FindSymbol("fstatat");
            if (sym) MSHookFunction(sym, (void *)hook_fstatat, (void **)&orig_fstatat);

            sym = FindSymbol("fstatat64");
            if (sym) MSHookFunction(sym, (void *)hook_fstatat64, (void **)&orig_fstatat64);

            sym = FindSymbol("faccessat");
            if (sym) MSHookFunction(sym, (void *)hook_faccessat, (void **)&orig_faccessat);

            sym = FindSymbol("readlinkat");
            if (sym) MSHookFunction(sym, (void *)hook_readlinkat, (void **)&orig_readlinkat);

            sym = FindSymbol("symlink");
            if (sym) MSHookFunction(sym, (void *)hook_symlink, (void **)&orig_symlink);

            sym = FindSymbol("rename");
            if (sym) MSHookFunction(sym, (void *)hook_rename, (void **)&orig_rename);

            sym = FindSymbol("link");
            if (sym) MSHookFunction(sym, (void *)hook_link, (void **)&orig_link);

            sym = FindSymbol("unlink");
            if (sym) MSHookFunction(sym, (void *)hook_unlink, (void **)&orig_unlink);

            sym = FindSymbol("remove");
            if (sym) MSHookFunction(sym, (void *)hook_remove_func, (void **)&orig_remove_func);

            sym = FindSymbol("rmdir");
            if (sym) MSHookFunction(sym, (void *)hook_rmdir, (void **)&orig_rmdir);

            // Priority 3: objc_copyClassNamesForImage, NSVersionOf*.
            sym = FindSymbol("objc_copyClassNamesForImage");
            if (sym) MSHookFunction(sym, (void *)hook_objc_copyClassNamesForImage, (void **)&orig_objc_copyClassNamesForImage);

            sym = FindSymbol("NSVersionOfRunTimeLibrary");
            if (sym) MSHookFunction(sym, (void *)hook_NSVersionOfRunTimeLibrary, (void **)&orig_NSVersionOfRunTimeLibrary);

            sym = FindSymbol("NSVersionOfLinkTimeLibrary");
            if (sym) MSHookFunction(sym, (void *)hook_NSVersionOfLinkTimeLibrary, (void **)&orig_NSVersionOfLinkTimeLibrary);

            // JailbreakDetector bypass hooks.
            sym = FindSymbol("getmntinfo");
            if (sym) {
                gJBGetmntinfoEntry = (PXJBGetmntinfoFunction)sym;
                MSHookFunction(sym, (void *)hook_getmntinfo, (void **)&orig_getmntinfo);
                gJBMountSnapshotOwnerReady = orig_getmntinfo != NULL &&
                                             orig_getmntinfo != gJBGetmntinfoEntry &&
                                             PXJBPrepareMountSnapshotOwner();
            }

            sym = FindSymbol("bootstrap_look_up");
            if (sym) MSHookFunction(sym, (void *)hook_bootstrap_look_up, (void **)&orig_bootstrap_look_up);

            // P1-E: vm_region_64 and task_get_exception_ports are high-risk,
            // process-wide introspection hooks and are absent from the default
            // module. A future implementation requires an explicit capability.

            // P0-A: capture fcntl only for verified internal calls. Do not hook the
            // variadic entry point until a command-complete ABI dispatcher exists.
            sym = FindSymbol("fcntl");
            if (sym) {
                orig_fcntl = (PXJBFcntlFunction)sym;
            } else {
                PXLog(@"[JailbreakBypass] fcntl symbol unavailable; F_GETPATH helpers will use libc fallback");
            }

            sym = FindSymbol("xpc_pipe_routine");
            if (sym) MSHookFunction(sym, (void *)hook_xpc_pipe_routine, (void **)&orig_xpc_pipe_routine);

            sym = FindSymbol("xpc_pipe_routine_with_flags");
            if (sym) MSHookFunction(sym, (void *)hook_xpc_pipe_routine_with_flags, (void **)&orig_xpc_pipe_routine_with_flags);

            // Compatibility-first dyld concealment: hook only the name surface.
            // count/header/slide retain their original dyld implementation and
            // therefore preserve cardinality, index identity and valid pointers.
            if (wantDyldHide) {
                void *nameEntry = FindSymbol("_dyld_get_image_name");
                if (nameEntry) {
                    gDyldImageNameEntry = (PXDyldImageNameFn)nameEntry;
                    MSHookFunction(nameEntry,
                                   (void *)hook__dyld_get_image_name,
                                   (void **)&orig__dyld_get_image_name);

                    BOOL dyldReady = PXDyldNameTrampolineIsReady();
                    atomic_store_explicit(&gJBDyldNameHookReady,
                                          dyldReady,
                                          memory_order_release);
                    if (dyldReady) {
                        sym = FindSymbol("dladdr");
                        if (sym) MSHookFunction(sym, (void *)hook_dladdr, (void **)&orig_dladdr);
                    } else {
                        PXLog(@"[JailbreakBypass] dyld name sanitizer disabled: invalid trampoline");
                    }
                } else {
                    atomic_store_explicit(&gJBDyldNameHookReady, false, memory_order_release);
                    PXLog(@"[JailbreakBypass] dyld name sanitizer disabled: missing symbol");
                }
            }

            // Phase 3 extension: block suspicious add_image callback registrations.
            if (wantBlockAddImage) {
                // _dyld_register_func_for_add_image is in libdyld/dyld; dlsym RTLD_DEFAULT works.
                sym = FindSymbol("_dyld_register_func_for_add_image");
                if (sym) {
                    // See hook implementation below (near dyld helpers).
                    extern void PXJBInstallDyldAddImageBlocker(void *sym);
                    PXJBInstallDyldAddImageBlocker(sym);
                }
            }

            // Phase 3 extension: hide TASK_DYLD_INFO via task_info.
            if (wantHideTaskDyldInfo) {
                sym = FindSymbol("task_info");
                if (sym) {
                    extern void PXJBInstallTaskInfoHook(void *sym);
                    PXJBInstallTaskInfoHook(sym);
                }
            }

            // Phase 3 extension: hide dl_iterate_phdr enumeration.
            if (wantHideDlIteratePhdr) {
                sym = FindSymbol("dl_iterate_phdr");
                if (sym) {
                    MSHookFunction(sym, (void *)hook_dl_iterate_phdr, (void **)&orig_dl_iterate_phdr);
                }
            }

            // Phase 4: block dlopen/dlsym probes.
            if (wantBlockDlopenDlsym) {
                sym = FindSymbol("dlopen");
                if (sym) MSHookFunction(sym, (void *)hook_dlopen, (void **)&orig_dlopen);
                sym = FindSymbol("dlsym");
                if (sym) MSHookFunction(sym, (void *)hook_dlsym, (void **)&orig_dlsym);
            }

            // P1-D: register real coordinator providers. Priority 150 runs
            // before the terminal identity pre-provider, but these providers only
            // claim KERN_PROC/kern.bootargs and pass every other key onward.
            if (wantSysctlSanitize) {
                PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
                [coord installOwnedSymbolsIfNeeded];
                orig_sysctl_jb = [coord originalForSymbol:kPXNativeSymbolSysctl];
                orig_sysctlbyname_jb = [coord originalForSymbol:kPXNativeSymbolSysctlByname];

                static dispatch_once_t jbSysctlProviderOnce;
                dispatch_once(&jbSysctlProviderOnce, ^{
                    NSInteger priority = PXNativeHookPriorityScopeABI + 50;
                    gJBSysctlProviderRegistered =
                        [coord registerSysctlProvider:@"jb.sysctl.sanitize"
                                             priority:priority
                                                  pre:^BOOL(int *name,
                                                            u_int namelen,
                                                            void *oldp,
                                                            size_t *oldlenp,
                                                            void *newp,
                                                            size_t newlen,
                                                            int *outResult) {
                            return PXJBHandleSysctlSanitizeRequest(name,
                                                                  namelen,
                                                                  oldp,
                                                                  oldlenp,
                                                                  newp,
                                                                  newlen,
                                                                  outResult);
                        }
                                                 post:nil];
                    gJBSysctlBynameProviderRegistered =
                        [coord registerSysctlBynameProvider:@"jb.sysctlbyname.sanitize"
                                                   priority:priority
                                                        pre:^BOOL(const char *name,
                                                                  void *oldp,
                                                                  size_t *oldlenp,
                                                                  void *newp,
                                                                  size_t newlen,
                                                                  int *outResult) {
                            return PXJBHandleSysctlBynameSanitizeRequest(name,
                                                                        oldp,
                                                                        oldlenp,
                                                                        newp,
                                                                        newlen,
                                                                        outResult);
                        }
                                                       post:nil];
                });
            }

            // Phase 6: hide proc map filenames (libproc).
            if (wantHideProcMaps) {
                sym = FindSymbol("proc_regionfilename");
                if (sym) {
                    MSHookFunction(sym, (void *)hook_proc_regionfilename, (void **)&orig_proc_regionfilename);
                }
            }

            // Phase 7: hide ObjC runtime image list.
            if (wantHideObjcImages) {
                sym = FindSymbol("objc_copyImageNames");
                if (sym) {
                    MSHookFunction(sym, (void *)hook_objc_copyImageNames, (void **)&orig_objc_copyImageNames);
                }
                sym = FindSymbol("class_getImageName");
                if (sym) {
                    MSHookFunction(sym, (void *)hook_class_getImageName, (void **)&orig_class_getImageName);
                }
            }

        }

        %init;
        PXJBInstallLSCanOpenURLManagerHook();

        // Finalize install evidence, publish the immutable installed mask, then
        // activate the requested subset with one atomic policy publication.
        PXJBFinalizeCapabilityRegistryAndAudit();
        PXJBPublishPolicySnapshot(launchSettings);
        PXJBStartLateLoadedDetectionClassMonitoring();

        // Runtime reload happens off the hook path and can only use capabilities
        // that passed the immutable install audit.
        PXJBStartPolicyReloadTimer();

        // Proactive env cleanup (safe) for scoped apps.
        PXJBUnsetSuspiciousEnvIfNeeded();
        dispatch_async(dispatch_get_main_queue(), ^{
            PXJBUnsetSuspiciousEnvIfNeeded();
        });
        PXLog(@"[JailbreakBypass] Phase 1 hooks initialized");
    }
}

// --- Optional strong hooks (installed only when toggle is enabled at launch) ---
static void (*orig__dyld_register_func_for_add_image)(void (*func)(const struct mach_header *, intptr_t));

static void PXJBRegisterDyldAddImageCallback(
    void (*callback)(const struct mach_header *, intptr_t)) {
    if (!callback) return;
    // Register internal lifecycle observers through the original trampoline so
    // the optional public callback blocker cannot suppress our own monitor.
    if (orig__dyld_register_func_for_add_image) {
        orig__dyld_register_func_for_add_image(callback);
    } else {
        _dyld_register_func_for_add_image(callback);
    }
}

static void hook__dyld_register_func_for_add_image(void (*func)(const struct mach_header *, intptr_t)) {
    if (!orig__dyld_register_func_for_add_image) return;
    if (!PXJBBlockDyldAddImageCallbacksEnabled() || !func) {
        orig__dyld_register_func_for_add_image(func);
        return;
    }
    Dl_info info;
    if (dladdr((const void *)func, &info) && info.dli_fname) {
        if (PXJBShouldHideImageName(info.dli_fname)) {
            return;
        }
    }
    orig__dyld_register_func_for_add_image(func);
}

void PXJBInstallDyldAddImageBlocker(void *sym) {
    if (!sym) return;
    MSHookFunction(sym, (void *)hook__dyld_register_func_for_add_image, (void **)&orig__dyld_register_func_for_add_image);
}

static kern_return_t (*orig_task_info)(task_t, task_flavor_t, task_info_t, mach_msg_type_number_t *);
static kern_return_t hook_task_info(task_t target_task, task_flavor_t flavor, task_info_t task_info_out, mach_msg_type_number_t *task_info_outCnt) {
    if (!orig_task_info) return KERN_INVALID_ARGUMENT;
    if (!PXJBHideTaskDyldInfoEnabled()) {
        return orig_task_info(target_task, flavor, task_info_out, task_info_outCnt);
    }
    if (target_task != mach_task_self()) {
        return orig_task_info(target_task, flavor, task_info_out, task_info_outCnt);
    }
#ifdef TASK_DYLD_INFO
    if (flavor == TASK_DYLD_INFO) {
        if (task_info_outCnt) *task_info_outCnt = 0;
        return KERN_INVALID_ARGUMENT;
    }
#endif
    return orig_task_info(target_task, flavor, task_info_out, task_info_outCnt);
}

void PXJBInstallTaskInfoHook(void *sym) {
    if (!sym) return;
    MSHookFunction(sym, (void *)hook_task_info, (void **)&orig_task_info);
}

static PXJBPolicyMask PXJBFinalizeCapabilityRegistryAndAudit(void) {
    bool expected = false;
    if (!atomic_compare_exchange_strong_explicit(&gJBCapabilityRegistryFinalized,
                                                  &expected,
                                                  true,
                                                  memory_order_acq_rel,
                                                  memory_order_acquire)) {
        return atomic_load_explicit(&gJBInstalledCapabilityMask, memory_order_acquire);
    }

#define PXJB_AUDIT(capability, symbolName, pointerValue, requiredValue)     PXJBCapabilityAuditSymbol((capability), (symbolName), (pointerValue) != NULL, (requiredValue))

    // Core baseline: audit every unconditional native hook, while only stable
    // filesystem/process primitives are hard requirements for master activation.
    PXJB_AUDIT(kPXJBCapabilityCore, "stat", orig_stat, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "stat64", orig_stat64, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "lstat", orig_lstat, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "lstat64", orig_lstat64, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "access", orig_access, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "open", orig_open, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "openat", orig_openat, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "fopen", orig_fopen, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "opendir", orig_opendir, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "__opendir2", orig___opendir2, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "readdir", orig_readdir, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "readdir_r", orig_readdir_r, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "closedir", orig_closedir, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "fdopendir", orig_fdopendir, false);
    PXJBCapabilityAuditSymbol(kPXJBCapabilityCore,
                              "directory-stream-lifecycle",
                              atomic_load_explicit(&gJBDirectoryLifecycleReady,
                                                   memory_order_acquire),
                              true);
    PXJBCapabilityAuditSymbol(kPXJBCapabilityCore,
                              "path-matcher-optimized",
                              atomic_load_explicit(&gJBPathMatcherReady,
                                                   memory_order_acquire),
                              false);
    PXJB_AUDIT(kPXJBCapabilityCore, "readlink", orig_readlink, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "realpath", orig_realpath, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "pathconf", orig_pathconf, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "fpathconf", orig_fpathconf, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "getattrlist", orig_getattrlist, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "fgetattrlist", orig_fgetattrlist, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "getxattr", orig_getxattr, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "fgetxattr", orig_fgetxattr, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "listxattr", orig_listxattr, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "flistxattr", orig_flistxattr, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "getpeername", orig_getpeername, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "getsockname", orig_getsockname, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "connect", orig_connect, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "getenv", orig_getenv, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "ptrace", orig_ptrace, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "fork", orig_fork, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "vfork", orig_vfork, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "issetugid", orig_issetugid, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "getuid", orig_getuid, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "geteuid", orig_geteuid, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "getgid", orig_getgid, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "getegid", orig_getegid, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "getgroups", orig_getgroups, false);
    PXJBCapabilityAuditSymbol(
        kPXJBCapabilityCore,
        "_LSCanOpenURLManager.canOpenURL:publicSchemes:privateSchemes:XPCConnection:error:",
        atomic_load_explicit(&gPXJBLSCanOpenURLInstalled, memory_order_acquire),
        false);
    PXJB_AUDIT(kPXJBCapabilityCore, "setuid", orig_setuid, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "seteuid", orig_seteuid, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "setgid", orig_setgid, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "setegid", orig_setegid, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "setreuid", orig_setreuid, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "setregid", orig_setregid, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "getppid", orig_getppid, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "csops", orig_csops, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "system", orig_system, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "popen", orig_popen, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "posix_spawn", orig_posix_spawn, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "posix_spawnp", orig_posix_spawnp, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "dlopen_preflight", orig_dlopen_preflight, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "creat", orig_creat, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "fstat", orig_fstat, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "fstat64", orig_fstat64, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "fstatat", orig_fstatat, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "fstatat64", orig_fstatat64, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "faccessat", orig_faccessat, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "readlinkat", orig_readlinkat, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "symlink", orig_symlink, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "rename", orig_rename, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "link", orig_link, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "unlink", orig_unlink, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "remove", orig_remove_func, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "rmdir", orig_rmdir, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "objc_copyClassNamesForImage", orig_objc_copyClassNamesForImage, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "NSVersionOfRunTimeLibrary", orig_NSVersionOfRunTimeLibrary, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "NSVersionOfLinkTimeLibrary", orig_NSVersionOfLinkTimeLibrary, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "getmntinfo-trampoline", orig_getmntinfo, false);
    PXJBCapabilityAuditSymbol(kPXJBCapabilityCore,
                              "getmntinfo-owned-snapshot",
                              gJBMountSnapshotOwnerReady,
                              false);
    PXJB_AUDIT(kPXJBCapabilityCore, "bootstrap_look_up", orig_bootstrap_look_up, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "xpc_pipe_routine", orig_xpc_pipe_routine, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "xpc_pipe_routine_with_flags", orig_xpc_pipe_routine_with_flags, false);
    PXJBCapabilityAuditSymbol(kPXJBCapabilityCore, "logos-init-invoked", true, true);

    PXJBCapabilityAuditSymbol(kPXJBCapabilityStatfs,
                              "statfs-provider-registration",
                              gJBStatfsProviderRegistered,
                              true);
    PXJB_AUDIT(kPXJBCapabilityStatfs, "statfs-provider-original", orig_statfs, true);
    PXJB_AUDIT(kPXJBCapabilityStatfs, "fstatfs", orig_fstatfs, false);
    PXJB_AUDIT(kPXJBCapabilityStatfs, "fstatfs64", orig_fstatfs64, false);
    PXJB_AUDIT(kPXJBCapabilityStatfs, "statvfs", orig_statvfs, false);
    PXJB_AUDIT(kPXJBCapabilityStatfs, "fstatvfs", orig_fstatvfs, false);

    PXJB_AUDIT(kPXJBCapabilityDyldIndexed, "_dyld_get_image_name", orig__dyld_get_image_name, true);
    PXJB_AUDIT(kPXJBCapabilityDyldIndexed, "dladdr", orig_dladdr, false);
    if (gJBCapabilities[kPXJBCapabilityDyldIndexed].requested &&
        !atomic_load_explicit(&gJBDyldNameHookReady, memory_order_acquire)) {
        PXJBCapabilitySetFailure(kPXJBCapabilityDyldIndexed, "trampoline-integrity-failed");
    }

    PXJB_AUDIT(kPXJBCapabilityDyldAddImage, "_dyld_register_func_for_add_image", orig__dyld_register_func_for_add_image, true);
    PXJB_AUDIT(kPXJBCapabilityTaskDyldInfo, "task_info", orig_task_info, true);
    PXJB_AUDIT(kPXJBCapabilityDlIteratePhdr, "dl_iterate_phdr", orig_dl_iterate_phdr, true);
    PXJB_AUDIT(kPXJBCapabilityDlopenDlsym, "dlopen", orig_dlopen, true);
    PXJB_AUDIT(kPXJBCapabilityDlopenDlsym, "dlsym", orig_dlsym, true);

    PXJB_AUDIT(kPXJBCapabilitySysctlSanitize,
                 "sysctl-coordinator-original",
                 orig_sysctl_jb,
                 true);
    PXJBCapabilityAuditSymbol(kPXJBCapabilitySysctlSanitize,
                              "sysctl-provider-registration",
                              gJBSysctlProviderRegistered,
                              true);
    PXJB_AUDIT(kPXJBCapabilitySysctlSanitize,
                 "sysctlbyname-coordinator-original",
                 orig_sysctlbyname_jb,
                 true);
    PXJBCapabilityAuditSymbol(kPXJBCapabilitySysctlSanitize,
                              "sysctlbyname-provider-registration",
                              gJBSysctlBynameProviderRegistered,
                              true);

    PXJB_AUDIT(kPXJBCapabilityProcMaps, "proc_regionfilename", orig_proc_regionfilename, true);
    PXJB_AUDIT(kPXJBCapabilityObjcImages, "objc_copyImageNames", orig_objc_copyImageNames, true);
    PXJB_AUDIT(kPXJBCapabilityObjcImages, "class_getImageName", orig_class_getImageName, true);
    PXJBCapabilityAuditSymbol(kPXJBCapabilityDebugLogging, "atomic-counter", true, true);
    PXJB_AUDIT(kPXJBCapabilitySCDebuggerScalar,
               "SCIsRunningWithDebugger",
               orig_SCIsRunningWithDebugger,
               true);

#undef PXJB_AUDIT

    PXJBPolicyMask readyMask = 0;
    uint32_t requestedCount = 0;
    uint32_t readyCount = 0;
    uint32_t failedCount = 0;

    for (uint32_t i = 0; i < kPXJBCapabilityCount; i++) {
        PXJBCapabilityRecord *record = &gJBCapabilities[i];
        if (record->requested) {
            requestedCount++;
            if (!record->failureReason && record->missingRequiredSymbols > 0) {
                record->failureReason = "required-symbol-missing";
            }
            record->ready = record->failureReason == NULL &&
                            record->missingRequiredSymbols == 0 &&
                            record->installedSymbols >= record->requiredSymbols;
            if (i != kPXJBCapabilityCore &&
                !gJBCapabilities[kPXJBCapabilityCore].ready) {
                record->ready = false;
                if (!record->failureReason) record->failureReason = "core-not-ready";
            }
            if (record->ready) {
                readyMask |= record->policyBit;
                readyCount++;
            } else {
                failedCount++;
            }
        }

        PXFileDebugAIDA64Log("[JailbreakBypass.capability] name=%s requested=%d attempted=%d ready=%d installed=%u/%u required=%u missing_required=%u first_missing=%s reason=%s",
                            record->name,
                            record->requested ? 1 : 0,
                            record->attempted ? 1 : 0,
                            record->ready ? 1 : 0,
                            (unsigned int)record->installedSymbols,
                            (unsigned int)record->expectedSymbols,
                            (unsigned int)record->requiredSymbols,
                            (unsigned int)record->missingRequiredSymbols,
                            record->firstMissingRequiredSymbol ? record->firstMissingRequiredSymbol : "-",
                            record->failureReason ? record->failureReason : "-");
    }

    atomic_store_explicit(&gJBInstalledCapabilityMask, readyMask, memory_order_release);
    PXLog(@"[JailbreakBypass] capability audit requested=%u ready=%u failed=%u mask=0x%llx",
          requestedCount,
          readyCount,
          failedCount,
          (unsigned long long)readyMask);
    return readyMask;
}
