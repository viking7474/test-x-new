// JailbreakBypassHooks.x
// Phase 1: File/URL/InstalledApps/LoopbackPortScan/WriteCheck

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

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
#import <sys/sysctl.h>
#if __has_include(<sys/user.h>)
#import <sys/user.h>
#endif
#import <string.h>
#import <pthread.h>
#import <dispatch/dispatch.h>
#import <mach/mach.h>
#import <stdint.h>
#import <stdbool.h>
#import <stdatomic.h>
#import <time.h>

// XPC types — Theos SDK doesn't ship <xpc/xpc.h>.
// We only need opaque pointers and a few functions.
typedef void *xpc_object_t;
typedef const struct _xpc_type_s *xpc_type_t;
extern xpc_type_t _xpc_type_dictionary;
#define XPC_TYPE_DICTIONARY (&_xpc_type_dictionary)
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

// Optional logging macro if ProjectXLogging is present.
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

static void *FindSymbol(const char *image, const char *symbol) {
    if (!symbol) return NULL;
    if (image) {
        void *handle = dlopen(image, RTLD_NOW);
        if (!handle) return dlsym(RTLD_DEFAULT, symbol);
        return dlsym(handle, symbol);
    }
    return dlsym(RTLD_DEFAULT, symbol);
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
};

static _Atomic(PXJBPolicyMask) gJBPolicyMask = 0;
static _Atomic(bool) gJBDyldIndexedHooksReady = false;

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
    kPXJBReentryDyldSnapshot = 1u << 1,
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
    if ([bundleID isEqualToString:@"com.hydra.projectx"] ||
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

    PXJBPolicyMask mask = kPXJBPolicyMaster;
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

    gJBPolicyReloadQueue = dispatch_queue_create("com.hydra.projectx.jb-policy", DISPATCH_QUEUE_SERIAL);
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
                                     kPXJBReentryDyldSnapshot |
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
           atomic_load_explicit(&gJBDyldIndexedHooksReady, memory_order_acquire);
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

// Path matching
static BOOL PXJBIsHiddenExactPath(const char *path) {
    if (!path) return NO;
    static const char *kExact[] = {
        // Jailbreak package managers / apps
        "/Applications/Cydia.app",
        "/Applications/Sileo.app",
        "/Applications/Zebra.app",
        "/Applications/Filza.app",
        "/Applications/Installer.app",
        "/Applications/RockApp.app",
        "/Applications/Icy.app",
        "/Applications/WinterBoard.app",
        "/Applications/SBSettings.app",
        "/Applications/MxTube.app",
        "/Applications/IntelliScreen.app",
        "/Applications/FakeCarrier.app",
        "/Applications/blackra1n.app",
        "/Applications/Dopamine.app",
        "/Applications/Th0r.app",
        "/Applications/iFile.app",
        "/Applications/Terminal.app",
        "/Applications/NewTerm.app",
        
        // MobileSubstrate files
        "/Library/MobileSubstrate/DynamicLibraries/0Cr4shed.dylib",
        "/Library/MobileSubstrate/DynamicLibraries/libappstoreplus.dylib",
        "/Library/MobileSubstrate/DynamicLibraries/ Crane.dylib",
        "/Library/MobileSubstrate/DynamicLibraries/ProjectXTweak.dylib",
        "/Library/MobileSubstrate/DynamicLibraries/FilzaHack.dylib",
        "/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
        "/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/Library/MobileSubstrate/DynamicLibraries",
        "/Library/dpkg/info/mobilesubstrate.md5sums",
        "/Library/dpkg/status", 
        "/private/var/binpack/Applications/loader.app",      

        // Substrate/hooking libs
        "/usr/lib/substrate/SubstrateBootstrap.dylib",
        "/usr/lib/substrate/SubstrateLoader.dylib",
        "/usr/lib/substrate/SubstrateInserter.dylib",

        "/usr/lib/libsubstrate.dylib",
        "/usr/lib/libmryipc.dylib",
        "/usr/lib/libFrida.dylib",
        "/usr/lib/libcycript.dylib",
        "/usr/lib/libjailbreak.dylib",
        "/usr/lib/libhooker.dylib",
        "/usr/lib/libsubstitute.dylib",
        "/usr/lib/TweakInject.dylib",
        "/usr/lib/ellekit/libinjector.dylib",
        "/usr/lib/libellekit.dylib",
        
        // Frameworks
        "/Library/Frameworks/CydiaSubstrate.framework",
        "/Library/PreferenceBundles",
        "/Library/PreferenceLoader",
        
        // SSH / shell tools
        "/usr/bin/ssh",
        "/usr/bin/scp",
        "/usr/bin/sftp",
        "/usr/sbin/sshd",
        "/bin/bash",
        "/bin/sh",
        "/bin/zsh",
        "/usr/bin/cycript",
        "/usr/bin/dpkg",
        "/usr/bin/apt",
        "/usr/bin/apt-get",
        
        // SSH support files
        "/usr/libexec/cydia",
        "/usr/libexec/sftp-server",
        "/usr/libexec/ssh-keysign",
        
        // Common directories
        "/etc/apt",
        "/private/etc/apt",
        "/etc/ssh",
        "/private/etc/ssh",
        "/var/lib/apt",
        "/var/lib/cydia",
        "/var/cache/apt",
        "/var/log/syslog",
        "/var/tmp/cydia.log",
        "/Library/dpkg",
        "/private/var/binpack",
        
        // Jailbreak markers / files
        "/var/checkra1n.dmg",
        "/var/binpack",
        "/.bootstrapped_electra",
        "/.cydia_no_stash",
        "/.installed_unc0ver",
        "/.installed_taurine",
        "/.installed_odyssey",
        "/.installed_chimera",
        "/.installed_dopamine",
        "/.installed_palera1n",
        "/private/var/stash",
        
        // Frida detection paths
        "/usr/sbin/frida-server",
        "/usr/lib/frida/frida-agent.dylib",
        
        // LaunchDaemons used for detection
        "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
        "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
        
        // Write test paths
        "/private/jailbreak_test",
        "/private/var/jailbreak_test",
        
        // Rootless jailbreak specific
        "/var/jb",
        "/var/jb/Applications",
        "/var/jb/usr",
        "/var/jb/Library",
        "/private/preboot",
        
        NULL
    };
    for (int i = 0; kExact[i]; i++) {
        if (strcmp(path, kExact[i]) == 0) return YES;
    }
    return NO;
}

static BOOL PXJBIsHiddenPrefixPath(const char *path) {
    if (!path) return NO;
    static const char *kPrefixes[] = {
        // Substrate/hooking framework paths
        "/usr/lib/substrate/",
        "/usr/lib/TweakInject/",
        "/usr/lib/ellekit/",
        "/usr/lib/substitute/",
        "/usr/lib/libhooker/",
        
        // MobileSubstrate paths
        "/Library/MobileSubstrate/",
        "/private/var/Library/MobileSubstrate/",
        "/private/var/mobile/Library/MobileSubstrate/",
        
        // Cydia cache injection paths
        "/Library/Caches/cy-",
        "/private/var/Library/Caches/cy-",
        "/private/var/mobile/Library/Caches/cy-",
        
        // Library paths
        "/Library/Frameworks/CydiaSubstrate.framework/",
        "/Library/PreferenceBundles/",
        "/Library/PreferenceLoader/",
        "/Library/dpkg/info/",
        "/Library/Themes/",
        "/Library/Ringtones/",
        "/Library/Wallpaper/",
        
        // Rootless jailbreak paths (Dopamine, palera1n, etc.)
        "/var/jb/",
        "/private/var/jb/",
        "/var/jb/Applications/",
        "/var/jb/usr/",
        "/var/jb/Library/",
        "/var/jb/bin/",
        "/var/jb/sbin/",
        "/var/jb/etc/",
        
        // Preboot jailbreak paths
        "/private/preboot/jb/",
        "/private/preboot/",
        
        // Package manager paths
        "/var/lib/apt/",
        "/private/var/lib/apt/",
        "/var/cache/apt/",
        "/private/var/cache/apt/",
        "/var/lib/dpkg/",
        "/private/var/lib/dpkg/",
        
        // Cydia temp/log paths
        "/var/tmp/cydia",
        "/private/var/tmp/cydia",
        
        // Stash paths (older jailbreaks)
        "/private/var/stash/",
        "/var/stash/",
        
        // Frida paths
        "/usr/lib/frida/",
        
        // procursus (modern package set)
        "/var/jb/procursus/",
        
        // ElleKit injection
        "/var/jb/usr/lib/ellekit/",

        // Additional prefixes found from sandbox logs (MB Bank / VNID)
        "/etc/apt/",
        "/private/etc/apt/",
        "/etc/ssh/",
        "/private/etc/ssh/",
        "/Library/dpkg/",
        "/private/var/binpack/",
        "/usr/libexec/cydia/",
        
        NULL
    };
    for (int i = 0; kPrefixes[i]; i++) {
        if (PXHasPrefix(path, kPrefixes[i])) return YES;
    }
    return NO;
}

static BOOL PXJBPathMatchesHiddenRules(const char *path) {
    if (!path) return NO;
    if (path[0] != '/') return NO;
    // Quick exact/prefix checks.
    if (PXJBIsHiddenExactPath(path)) return YES;
    if (PXJBIsHiddenPrefixPath(path)) return YES;
    return NO;
}

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

// P1-B: one classifier owns path resolution and filesystem policy decisions.
typedef enum {
    kPXJBFilesystemAllow = 0,
    kPXJBFilesystemHide,
    kPXJBFilesystemDenyWrite,
    kPXJBFilesystemUnresolved,
} PXJBFilesystemDisposition;

typedef enum {
    kPXJBFilesystemOperationRead = 0,
    kPXJBFilesystemOperationWrite,
} PXJBFilesystemOperation;

static PXJBFilesystemDisposition PXJBClassifyFilesystemPathAt(int dirfd,
                                                               const char *path,
                                                               PXJBFilesystemOperation operation,
                                                               int flags,
                                                               char *resolvedPath,
                                                               size_t resolvedCapacity);

static inline BOOL PXJBFilesystemDispositionIsHidden(PXJBFilesystemDisposition disposition) {
    return disposition == kPXJBFilesystemHide;
}

static inline BOOL PXJBFilesystemDispositionBlocksWrite(PXJBFilesystemDisposition disposition) {
    return disposition == kPXJBFilesystemHide ||
           disposition == kPXJBFilesystemDenyWrite;
}

static inline int PXJBFilesystemErrno(PXJBFilesystemDisposition disposition) {
    return disposition == kPXJBFilesystemDenyWrite ? EACCES : ENOENT;
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
    if (!path) return NO;
    // Keep this list tight to avoid false positives.
    static const char *needles[] = {
        "mobilesubstrate",
        "cydia.app",
        "sileo.app",
        "zebra.app",
        "filza.app",
        "preferenceloader",
        "preferencebundles",
        "var/jb",
        "library/caches/cy-",
        "substrate",
        "ellekit",
        "libhooker",
        "frida",
        NULL
    };
    for (int i = 0; needles[i]; i++) {
        if (PXStrContainsNoCase(path, needles[i])) return YES;
    }
    return NO;
}

static BOOL PXJBNormalizeAbsolutePath(const char *inPath, char *out, size_t outsz) {
    if (!inPath || !out || outsz < 2) return NO;
    if (inPath[0] != '/') return NO;

    size_t w = 0;
    out[w++] = '/';

    const char *p = inPath;
    while (*p) {
        while (*p == '/') p++;
        if (!*p) break;
        const char *seg = p;
        while (*p && *p != '/') p++;
        size_t segLen = (size_t)(p - seg);
        if (segLen == 1 && seg[0] == '.') {
            continue;
        }
        if (segLen == 2 && seg[0] == '.' && seg[1] == '.') {
            // pop last segment
            if (w > 1) {
                // remove trailing slash if any
                if (out[w - 1] == '/' && w > 1) w--;
                while (w > 1 && out[w - 1] != '/') w--;
            }
            continue;
        }
        // append segment
        if (w > 1 && out[w - 1] != '/') {
            if (w + 1 >= outsz) return NO;
            out[w++] = '/';
        }
        if (w + segLen + 1 >= outsz) return NO;
        memcpy(out + w, seg, segLen);
        w += segLen;
        out[w] = '\0';
    }

    if (w == 0) {
        out[0] = '/';
        out[1] = '\0';
    } else {
        out[w] = '\0';
    }
    return YES;
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

static DIR *(*orig_opendir)(const char *);
static DIR *hook_opendir(const char *path) {
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
    return orig_opendir ? orig_opendir(path) : NULL;
}

static struct dirent *(*orig_readdir)(DIR *);
static struct dirent *hook_readdir(DIR *dirp) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (!orig_readdir) return NULL;
    struct dirent *ent = orig_readdir(dirp);
    if (!pxjbFilterFilesystem) return ent;

    // Hide common jailbreak app names if a directory listing is used.
    while (ent) {
        const char *n = ent->d_name;
        if (n) {
            if (PXStrEqNoCase(n, "Cydia.app") || PXStrEqNoCase(n, "Sileo.app") || PXStrEqNoCase(n, "Zebra.app") || PXStrEqNoCase(n, "Filza.app")) {
                ent = orig_readdir(dirp);
                continue;
            }
        }
        break;
    }
    return ent;
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

static int (*orig_connect)(int, const struct sockaddr *, socklen_t);
static int hook_connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
    if (PXJBShouldBypassCached() && addr) {
        if (addr->sa_family == AF_INET && addrlen >= sizeof(struct sockaddr_in)) {
            const struct sockaddr_in *a = (const struct sockaddr_in *)addr;
            uint32_t ip = ntohl(a->sin_addr.s_addr);
            uint16_t port = ntohs(a->sin_port);
            if (ip == INADDR_LOOPBACK && PXJBIsDeniedLoopbackPort(port)) {
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
static char *hook_getenv(const char *name) {
    if (PXJBShouldBypassCached() && name) {
        if (strcmp(name, "DYLD_INSERT_LIBRARIES") == 0 ||
            strcmp(name, "DYLD_LIBRARY_PATH") == 0 ||
            strcmp(name, "DYLD_FRAMEWORK_PATH") == 0 ||
            strcmp(name, "DYLD_FALLBACK_LIBRARY_PATH") == 0 ||
            strcmp(name, "DYLD_FALLBACK_FRAMEWORK_PATH") == 0 ||
            strcmp(name, "DYLD_ROOT_PATH") == 0 ||
            strcmp(name, "DYLD_SHARED_CACHE_DIR") == 0 ||
            strcmp(name, "DYLD_PRINT_TO_FILE") == 0 ||
            strcmp(name, "DYLD_PRINT_LIBRARIES") == 0 ||
            strcmp(name, "DYLD_PRINT_APIS") == 0 ||
            strcmp(name, "DYLD_PRINT_OPTS") == 0 ||
            strcmp(name, "DYLD_PRINT_ENV") == 0 ||
            strcmp(name, "LD_PRELOAD") == 0 ||
            strcmp(name, "_MSSafeMode") == 0 ||
            strcmp(name, "JB_SANDBOX_EXTENSIONS") == 0 ||
            strcmp(name, "SHELL") == 0) {
            return NULL;
        }
    }
    return orig_getenv ? orig_getenv(name) : NULL;
}

static void PXJBUnsetSuspiciousEnvIfNeeded(void) {
    if (!PXJBShouldBypassCached()) return;
    // Proactive cleanup so detectors reading env via non-getenv paths see a clean environment.
    // Low risk: only affects this process.
    const char *keys[] = {
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
    for (int i = 0; keys[i]; i++) {
        unsetenv(keys[i]);
    }
}

// Phase 2: anti-debug / anti-exec probes
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

// Phase 3: dylib hiding (dyld enumeration + dladdr)
static pthread_mutex_t gDyldLock = PTHREAD_MUTEX_INITIALIZER;
static uint32_t *gVisibleToReal = NULL;
static uint32_t gVisibleCount = 0;
static uint32_t gRealCount = 0;
static uint64_t gDyldLastBuildNs = 0;

// P0-E: the only callable originals are trampolines returned by MSHookFunction.
// Entry pointers are retained solely for integrity comparison and are never invoked.
typedef uint32_t (*PXDyldImageCountFn)(void);
typedef const char *(*PXDyldImageNameFn)(uint32_t image_index);
typedef const struct mach_header *(*PXDyldImageHeaderFn)(uint32_t image_index);
typedef intptr_t (*PXDyldImageSlideFn)(uint32_t image_index);

static PXDyldImageCountFn orig__dyld_image_count = NULL;
static PXDyldImageNameFn orig__dyld_get_image_name = NULL;
static PXDyldImageHeaderFn orig__dyld_get_image_header = NULL;
static PXDyldImageSlideFn orig__dyld_get_image_vmaddr_slide = NULL;

static PXDyldImageCountFn gDyldImageCountEntry = NULL;
static PXDyldImageNameFn gDyldImageNameEntry = NULL;
static PXDyldImageHeaderFn gDyldImageHeaderEntry = NULL;
static PXDyldImageSlideFn gDyldImageSlideEntry = NULL;

static BOOL PXDyldIndexedTrampolinesAreReady(void) {
    return orig__dyld_image_count != NULL &&
           orig__dyld_image_count != gDyldImageCountEntry &&
           orig__dyld_get_image_name != NULL &&
           orig__dyld_get_image_name != gDyldImageNameEntry &&
           orig__dyld_get_image_header != NULL &&
           orig__dyld_get_image_header != gDyldImageHeaderEntry &&
           orig__dyld_get_image_vmaddr_slide != NULL &&
           orig__dyld_get_image_vmaddr_slide != gDyldImageSlideEntry;
}

static uint32_t PXDyldOriginalImageCount(void) {
    if (!orig__dyld_image_count || orig__dyld_image_count == gDyldImageCountEntry) return 0;
    return orig__dyld_image_count();
}

static const char *PXDyldOriginalImageName(uint32_t idx) {
    if (!orig__dyld_get_image_name || orig__dyld_get_image_name == gDyldImageNameEntry) return NULL;
    return orig__dyld_get_image_name(idx);
}

static const struct mach_header *PXDyldOriginalImageHeader(uint32_t idx) {
    if (!orig__dyld_get_image_header || orig__dyld_get_image_header == gDyldImageHeaderEntry) return NULL;
    return orig__dyld_get_image_header(idx);
}

static intptr_t PXDyldOriginalImageSlide(uint32_t idx) {
    if (!orig__dyld_get_image_vmaddr_slide ||
        orig__dyld_get_image_vmaddr_slide == gDyldImageSlideEntry) return 0;
    return orig__dyld_get_image_vmaddr_slide(idx);
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
    if (!name) return NO;
    // Substrings frequently used by jailbreak tooling / injection.
    static const char *deny[] = {
        // Substrate family
        "mobilesubstrate",
        "substrateloader",
        "substratebootstrap",
        "libsubstrate",
        "substrate",
        
        // ElleKit (modern jailbreaks)
        "ellekit",
        "libellekit",
        
        // libhooker
        "libhooker",
        
        // Substitute
        "substitute",
        
        // TweakInject
        "tweakinject",
        
        // Common ecosystem libs
        "rocketbootstrap",
        "libmryipc",
        "libblackjack",
        "applist",
        "cephei",
        "libcolorpicker",
        "libflex",
        "libactivator",
        "preferenceloader",
        "preferencebundles",
        
        // Security tools
        "frida",
        "fridagadget",
        "cycript",
        "ssl_logger",
        "objection",
        
        // Common tweak names
        "shadow",
        "liberty",
        "vnodebypass",
        "unsub",
        "a-bypass",
        "hestia",
        "choicy",
        "kernbypass",
        "hidejb",
        "jailprotect",
        "detectordeter",
        
        // Jailbreak specific
        "libjailbreak",
        "jailbreakd",
        "cy-",
        "dopamine",
        "palera1n",
        "procursus",
        "checkra1n",
        "unc0ver",
        "taurine",
        "odyssey",
        "chimera",
        "electra",
        
        NULL
    };
    for (int i = 0; deny[i]; i++) {
        if (PXStrContainsNoCase(name, deny[i])) return YES;
    }
    // Common rootless prefixes.
    if (PXStrContainsNoCase(name, "/var/jb")) return YES;
    if (PXStrContainsNoCase(name, "/private/preboot/jb")) return YES;
    if (PXStrContainsNoCase(name, "/private/preboot/")) return YES;
    // Common jailbreak cache-injected dylib pattern.
    if (PXStrContainsNoCase(name, "/library/caches/cy-")) return YES;
    // MobileSubstrate injection path.
    if (PXStrContainsNoCase(name, "/library/mobilesubstrate/")) return YES;
    return NO;
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

// Phase 3 strong option: hide ObjC runtime image list
static const char **(*orig_objc_copyImageNames)(unsigned int *outCount);
static const char **hook_objc_copyImageNames(unsigned int *outCount) {
    const char **list = orig_objc_copyImageNames ? orig_objc_copyImageNames(outCount) : NULL;
    if (!PXJBHideObjcImagesEnabled()) {
        return list;
    }
    if (!list || !outCount || *outCount == 0) {
        return list;
    }

    unsigned int inCount = *outCount;
    // Allocate a new list and free the original (caller will free what we return).
    const char **out = (const char **)calloc(inCount + 1, sizeof(char *));
    if (!out) {
        return list;
    }

    unsigned int j = 0;
    for (unsigned int i = 0; i < inCount; i++) {
        const char *nm = list[i];
        if (PXJBShouldHideImageName(nm)) continue;
        out[j++] = nm;
    }
    out[j] = NULL;
    *outCount = j;
    free((void *)list);
    return out;
}

static const char *(*orig_class_getImageName)(Class cls);
static const char *hook_class_getImageName(Class cls) {
    const char *nm = orig_class_getImageName ? orig_class_getImageName(cls) : NULL;
    if (!PXJBHideObjcImagesEnabled()) return nm;
    if (PXJBShouldHideImageName(nm)) return NULL;
    return nm;
}

static BOOL PXJBShouldBlockDlopenPath(const char *path) {
    if (!path || !path[0]) return NO;
    // Block direct probes for common injection/jailbreak libraries.
    static const char *deny[] = {
        "/usr/lib/substrate/",
        "substratebootstrap",
        "mobilesubstrate",
        "substrate",
        "ellekit",
        "libhooker",
        "rocketbootstrap",
        "substitute",
        "frida",
        "/library/caches/cy-",
        NULL
    };
    for (int i = 0; deny[i]; i++) {
        if (PXStrContainsNoCase(path, deny[i])) return YES;
    }
    return NO;
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

    if (PXJBHideDlIteratePhdrEnabled() && info) {
        const char *nm = info->dlpi_name;
        if (PXJBShouldHideImageName(nm)) {
            return 0; // skip
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

static void PXDyldRebuildVisibleMapLocked(void) {
    uint32_t count = PXDyldOriginalImageCount();
    if (count == 0) {
        free(gVisibleToReal);
        gVisibleToReal = NULL;
        gRealCount = 0;
        gVisibleCount = 0;
        gDyldLastBuildNs = PXJBMonotonicNanoseconds();
        return;
    }

    uint32_t *replacement = (uint32_t *)calloc(count, sizeof(uint32_t));
    if (!replacement) {
        // Fail open rather than expose a stale index map from another dyld
        // generation. The indexed wrappers call the original trampoline when
        // no visible map is available.
        free(gVisibleToReal);
        gVisibleToReal = NULL;
        gRealCount = count;
        gVisibleCount = 0;
        gDyldLastBuildNs = PXJBMonotonicNanoseconds();
        return;
    }

    uint32_t visible = 0;
    for (uint32_t i = 0; i < count; i++) {
        const char *name = PXDyldOriginalImageName(i);
        if (PXJBShouldHideImageName(name)) continue;
        replacement[visible++] = i;
    }

    uint32_t *oldMap = gVisibleToReal;
    gVisibleToReal = replacement;
    gRealCount = count;
    gVisibleCount = visible;
    gDyldLastBuildNs = PXJBMonotonicNanoseconds();
    free(oldMap);
}

static void PXDyldEnsureVisibleMap(void) {
    if (!PXJBHideDylibsEnabled()) return;

    uint64_t nowNs = PXJBMonotonicNanoseconds();
    uint32_t countNow = PXDyldOriginalImageCount();

    pthread_mutex_lock(&gDyldLock);
    BOOL expired = (nowNs == 0 || gDyldLastBuildNs == 0 ||
                    nowNs - gDyldLastBuildNs > 1000000000ull);
    BOOL needsRebuild = (gVisibleToReal == NULL) ||
                        (gRealCount != countNow) ||
                        expired;
    if (needsRebuild) PXDyldRebuildVisibleMapLocked();
    pthread_mutex_unlock(&gDyldLock);
}

static uint32_t hook__dyld_image_count(void) {
    PXJB_REENTRY_SCOPE(dyldScope, kPXJBReentryDyldSnapshot);
    uint32_t originalCount = PXDyldOriginalImageCount();
    if (!dyldScope.entered || !PXJBHideDylibsEnabled()) return originalCount;

    PXDyldEnsureVisibleMap();
    pthread_mutex_lock(&gDyldLock);
    uint32_t result = gVisibleToReal ? gVisibleCount : originalCount;
    pthread_mutex_unlock(&gDyldLock);
    return result;
}

static const char *hook__dyld_get_image_name(uint32_t image_index) {
    PXJB_REENTRY_SCOPE(dyldScope, kPXJBReentryDyldSnapshot);
    if (!dyldScope.entered || !PXJBHideDylibsEnabled()) {
        return PXDyldOriginalImageName(image_index);
    }

    PXDyldEnsureVisibleMap();
    pthread_mutex_lock(&gDyldLock);
    if (!gVisibleToReal) {
        pthread_mutex_unlock(&gDyldLock);
        return PXDyldOriginalImageName(image_index);
    }
    if (image_index >= gVisibleCount) {
        pthread_mutex_unlock(&gDyldLock);
        return NULL;
    }
    uint32_t realIndex = gVisibleToReal[image_index];
    pthread_mutex_unlock(&gDyldLock);
    return PXDyldOriginalImageName(realIndex);
}

static const struct mach_header *hook__dyld_get_image_header(uint32_t image_index) {
    PXJB_REENTRY_SCOPE(dyldScope, kPXJBReentryDyldSnapshot);
    if (!dyldScope.entered || !PXJBHideDylibsEnabled()) {
        return PXDyldOriginalImageHeader(image_index);
    }

    PXDyldEnsureVisibleMap();
    pthread_mutex_lock(&gDyldLock);
    if (!gVisibleToReal) {
        pthread_mutex_unlock(&gDyldLock);
        return PXDyldOriginalImageHeader(image_index);
    }
    if (image_index >= gVisibleCount) {
        pthread_mutex_unlock(&gDyldLock);
        return NULL;
    }
    uint32_t realIndex = gVisibleToReal[image_index];
    pthread_mutex_unlock(&gDyldLock);
    return PXDyldOriginalImageHeader(realIndex);
}

static intptr_t hook__dyld_get_image_vmaddr_slide(uint32_t image_index) {
    PXJB_REENTRY_SCOPE(dyldScope, kPXJBReentryDyldSnapshot);
    if (!dyldScope.entered || !PXJBHideDylibsEnabled()) {
        return PXDyldOriginalImageSlide(image_index);
    }

    PXDyldEnsureVisibleMap();
    pthread_mutex_lock(&gDyldLock);
    if (!gVisibleToReal) {
        pthread_mutex_unlock(&gDyldLock);
        return PXDyldOriginalImageSlide(image_index);
    }
    if (image_index >= gVisibleCount) {
        pthread_mutex_unlock(&gDyldLock);
        return 0;
    }
    uint32_t realIndex = gVisibleToReal[image_index];
    pthread_mutex_unlock(&gDyldLock);
    return PXDyldOriginalImageSlide(realIndex);
}

static int (*orig_dladdr)(const void *addr, Dl_info *info);
static int hook_dladdr(const void *addr, Dl_info *info) {
    PXJB_REENTRY_SCOPE(dyldScope, kPXJBReentryDyldSnapshot);
    int result = orig_dladdr ? orig_dladdr(addr, info) : 0;
    if (!dyldScope.entered || result == 0 || !info || !PXJBHideDylibsEnabled()) {
        return result;
    }
    if (info->dli_fname && PXJBShouldHideImageName(info->dli_fname)) {
        memset(info, 0, sizeof(*info));
        return 0;
    }
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
    if (r == 0 && (pxjbFilterFilesystem && PXJBStatfsBypassEnabled())) {
        // We can't reliably map fd->path cheaply; normalize anyway (best-effort).
        PXJBNormalizeStatfs(buf);
    }
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
    if (r == 0 && (pxjbFilterFilesystem && PXJBStatfsBypassEnabled())) {
        PXJBNormalizeStatvfs(buf);
    }
    return r;
}

// --- Priority 1: UID/GID spoofing ---
// Many apps check getuid()==0 to detect root access on jailbroken devices.
// Return 501 (mobile user) to appear non-jailbroken.

static uid_t (*orig_getuid)(void);
static uid_t hook_getuid(void) {
    if (PXJBShouldBypassCached()) return 501;
    return orig_getuid ? orig_getuid() : 501;
}

static uid_t (*orig_geteuid)(void);
static uid_t hook_geteuid(void) {
    if (PXJBShouldBypassCached()) return 501;
    return orig_geteuid ? orig_geteuid() : 501;
}

static gid_t (*orig_getgid)(void);
static gid_t hook_getgid(void) {
    if (PXJBShouldBypassCached()) return 501;
    return orig_getgid ? orig_getgid() : 501;
}

static gid_t (*orig_getegid)(void);
static gid_t hook_getegid(void) {
    if (PXJBShouldBypassCached()) return 501;
    return orig_getegid ? orig_getegid() : 501;
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
    if (!basePath || basePath[0] != '/' || !relativePath || !out || outCapacity < 2) {
        return NO;
    }

    size_t baseLength = strlen(basePath);
    size_t relativeLength = strlen(relativePath);
    BOOL needsSlash = (baseLength > 0 && basePath[baseLength - 1] != '/');
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
    return PXJBNormalizeAbsolutePath(joined, out, outCapacity);
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
    // filesystem artifacts. They return EACCES/DENY_WRITE even when a broader
    // hidden-path table also contains the same lexical path.
    if (operation == kPXJBFilesystemOperationWrite &&
        PXJBPathMatchesDenyWriteRules(target, flags)) {
        return kPXJBFilesystemDenyWrite;
    }
    if (PXJBPathMatchesHiddenRules(target)) {
        return kPXJBFilesystemHide;
    }
    return kPXJBFilesystemAllow;
}


// --- Priority 3: fstat (fd-based, resolve via original fcntl F_GETPATH) ---
static int (*orig_fstat)(int, struct stat *);
static int hook_fstat(int fd, struct stat *buf) {
    PXJB_FILESYSTEM_HOOK_SCOPE();
    if (pxjbFilterFilesystem && fd >= 0) {
        char fdPath[PATH_MAX];
        if (PXJBOriginalFcntlGetPath(fd, fdPath, sizeof(fdPath)) != -1) {
            PXJBFilesystemDisposition disposition =
                PXJBClassifyFilesystemPathAt(AT_FDCWD,
                                             fdPath,
                                             kPXJBFilesystemOperationRead,
                                             O_RDONLY,
                                             NULL,
                                             0);
            if (PXJBFilesystemDispositionIsHidden(disposition)) {
                errno = EBADF;
                return -1;
            }
        }
    }
    return orig_fstat ? orig_fstat(fd, buf) : -1;
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

static BOOL PXJBMountEntryShouldHide(const struct statfs *entry) {
    if (!entry) return NO;
    if (strcmp(entry->f_fstypename, "bindfs") == 0) {
        static const char *knownBinds[] = {
            "/usr/standalone/firmware",
            "/System/Library/Pearl/ReferenceFrames",
            "/System/Library/Caches/com.apple.factorydata",
            NULL
        };
        BOOL known = NO;
        for (int i = 0; knownBinds[i]; i++) {
            if (strcmp(entry->f_mntonname, knownBinds[i]) == 0) {
                known = YES;
                break;
            }
        }
        if (!known) return YES;
    }

    if (strcmp(entry->f_mntonname, "/") != 0 &&
        strcmp(entry->f_fstypename, "apfs") == 0 &&
        strstr(entry->f_mntfromname, "@") != NULL &&
        PXJBPathShouldHide(entry->f_mntonname)) {
        return YES;
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
    NSArray<NSString *> *orig = %orig;
    if (!PXJBShouldBypassCached()) return orig;
    if (![orig isKindOfClass:[NSArray class]] || orig.count == 0) return orig;

    NSMutableArray<NSString *> *out = [NSMutableArray arrayWithCapacity:orig.count];
    for (NSString *item in orig) {
        if (![item isKindOfClass:[NSString class]]) continue;
        if ([item caseInsensitiveCompare:@"Cydia.app"] == NSOrderedSame) continue;
        if ([item caseInsensitiveCompare:@"Sileo.app"] == NSOrderedSame) continue;
        if ([item caseInsensitiveCompare:@"Zebra.app"] == NSOrderedSame) continue;
        if ([item caseInsensitiveCompare:@"Filza.app"] == NSOrderedSame) continue;
        [out addObject:item];
    }
    return out;
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
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return %orig(@"/.file");
    }
    return %orig;
}

- (NSArray<NSString *> *)subpathsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil];
            return nil;
        }
    }
    NSArray *ret = %orig;
    if (!PXJBShouldBypassCached()) return ret;
    if (![ret isKindOfClass:[NSArray class]] || ret.count == 0) return ret;
    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:ret.count];
    for (NSString *sub in ret) {
        if ([sub isKindOfClass:[NSString class]]) {
            NSString *full = [path stringByAppendingPathComponent:sub];
            const char *fp = [full fileSystemRepresentation];
            if (PXJBPathShouldHide(fp)) continue;
        }
        [filtered addObject:sub];
    }
    return [filtered copy];
}

- (NSArray<NSString *> *)subpathsAtPath:(NSString *)path {
    if (PXJBShouldBypassCached() && [path isKindOfClass:[NSString class]]) {
        const char *p = [path fileSystemRepresentation];
        if (PXJBPathShouldHide(p)) return nil;
    }
    return %orig;
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

%hook NSProcessInfo

- (NSDictionary<NSString *, NSString *> *)environment {
    NSDictionary *env = %orig;
    if (!PXJBShouldBypassCached()) return env;
    if (![env isKindOfClass:[NSDictionary class]] || env.count == 0) return env;

    NSMutableDictionary *out = [env mutableCopy];
    NSArray<NSString *> *deny = @[
        @"DYLD_INSERT_LIBRARIES",
        @"DYLD_LIBRARY_PATH",
        @"DYLD_FRAMEWORK_PATH",
        @"DYLD_FALLBACK_LIBRARY_PATH",
        @"DYLD_FALLBACK_FRAMEWORK_PATH",
        @"DYLD_ROOT_PATH",
        @"DYLD_SHARED_CACHE_DIR",
        @"DYLD_PRINT_TO_FILE",
        @"DYLD_PRINT_LIBRARIES",
        @"DYLD_PRINT_APIS",
        @"DYLD_PRINT_OPTS",
        @"DYLD_PRINT_ENV",
        @"LD_PRELOAD",
        @"_MSSafeMode",
        @"MSDebug",
        @"JB_SANDBOX_EXTENSIONS",
        @"SHELL"
    ];
    [out removeObjectsForKeys:deny];
    return [out copy];
}

%end

%hook UIApplication

- (BOOL)canOpenURL:(NSURL *)url {
    if (PXJBShouldBypassCached() && [url isKindOfClass:[NSURL class]]) {
        NSString *scheme = [[url scheme] lowercaseString];
        if (scheme.length) {
            if ([scheme isEqualToString:@"cydia"] ||
                [scheme isEqualToString:@"sileo"] ||
                [scheme isEqualToString:@"zbra"] ||
                [scheme isEqualToString:@"filza"] ||
                [scheme isEqualToString:@"undecimus"] ||
                [scheme isEqualToString:@"checkra1n"] ||
                [scheme isEqualToString:@"odyssey"] ||
                [scheme isEqualToString:@"taurine"] ||
                [scheme isEqualToString:@"electra"]) {
                return NO;
            }
        }
    }
    return %orig;
}

%end

%hook LSApplicationWorkspace

- (NSArray *)allInstalledApplications {
    NSArray *apps = %orig;
    if (!PXJBShouldBypassCached()) return apps;
    if (![apps isKindOfClass:[NSArray class]] || apps.count == 0) return apps;

    static NSSet<NSString *> *deny = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        deny = [NSSet setWithArray:@[
            @"com.saurik.Cydia",
            @"org.coolstar.SileoStore",
            @"com.opa334.Sileo",
            @"xyz.willy.Zebra",
            @"com.tigisoftware.Filza",
        ]];
    });

    NSMutableArray *out = [NSMutableArray arrayWithCapacity:apps.count];
    for (id proxy in apps) {
        NSString *bid = nil;
        if ([proxy respondsToSelector:@selector(bundleIdentifier)]) {
            bid = [proxy performSelector:@selector(bundleIdentifier)];
        }
        if ([bid isKindOfClass:[NSString class]] && [deny containsObject:bid]) {
            continue;
        }
        [out addObject:proxy];
    }
    return out;
}

- (NSArray *)installedApplications {
    return [self allInstalledApplications];
}

- (NSArray *)allApplications {
    return [self allInstalledApplications];
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
// These classes are from popular SDKs that apps embed for jailbreak detection.

%hook UIDevice
+ (BOOL)isJailbroken { return NO; }
- (BOOL)isJailBreak { return NO; }
- (BOOL)isJailBroken { return NO; }
%end

%hook JailbreakDetectionVC
- (BOOL)isJailbroken { return NO; }
%end

%hook DTTJailbreakDetection
+ (BOOL)isJailbroken { return NO; }
%end

%hook ANSMetadata
- (BOOL)computeIsJailbroken { return NO; }
- (BOOL)isJailbroken { return NO; }
%end

%hook AppsFlyerUtils
+ (BOOL)isJailBreakon { return NO; }
%end

%hook GBDeviceInfo
- (BOOL)isJailbroken { return NO; }
%end

%hook CMARAppRestrictionsDelegate
- (bool)isDeviceNonCompliant { return false; }
%end

%hook ADYSecurityChecks
+ (bool)isDeviceJailbroken { return false; }
%end

%hook UBReportMetadataDevice
- (void *)is_rooted { return NULL; }
%end

%hook UtilitySystem
+ (bool)isJailbreak { return false; }
%end

%hook GemaltoConfiguration
+ (bool)isJailbreak { return false; }
%end

%hook CPWRDeviceInfo
- (bool)isJailbroken { return false; }
%end

%hook CPWRSessionInfo
- (bool)isJailbroken { return false; }
%end

%hook KSSystemInfo
+ (bool)isJailbroken { return false; }
%end

%hook EMDSKPPConfiguration
- (bool)jailBroken { return false; }
%end

%hook EnrollParameters
- (void *)jailbroken { return NULL; }
%end

%hook EMDskppConfigurationBuilder
- (bool)jailbreakStatus { return false; }
%end

%hook FCRSystemMetadata
- (bool)isJailbroken { return false; }
%end

%hook v_VDMap
- (bool)isJailBrokenDetectedByVOS { return false; }
- (bool)isDFPHookedDetecedByVOS { return false; }
- (bool)isCodeInjectionDetectedByVOS { return false; }
- (bool)isDebuggerCheckDetectedByVOS { return false; }
- (bool)isAppSignerCheckDetectedByVOS { return false; }
- (bool)v_checkAModified { return false; }
%end

%hook SDMUtils
- (BOOL)isJailBroken { return NO; }
%end

%hook OneSignalJailbreakDetection
+ (BOOL)isJailbroken { return NO; }
%end

%hook DigiPassHandler
- (BOOL)rootedDeviceTestResult { return NO; }
%end

%hook AWMyDeviceGeneralInfo
- (bool)isCompliant { return true; }
%end

// --- Priority 3: NSDirectoryEnumerator filtering ---
%hook NSDirectoryEnumerator

- (id)nextObject {
    if (!PXJBShouldBypassCached()) return %orig;

    id obj = %orig;
    while (obj != nil) {
        NSString *path = nil;
        if ([obj isKindOfClass:[NSURL class]]) {
            NSURL *url = (NSURL *)obj;
            if ([url isFileURL]) path = [url path];
        } else if ([obj isKindOfClass:[NSString class]]) {
            path = (NSString *)obj;
        }
        if (path) {
            const char *p = [path fileSystemRepresentation];
            if (PXJBPathShouldHide(p)) {
                obj = %orig;
                continue;
            }
        }
        break;
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

// --- JailbreakDetector bypass: LSApplicationWorkspace installedPlugins ---
// Filter plugins belonging to known JB apps from the enumeration.
%hook LSApplicationWorkspace

- (NSArray *)installedPlugins {
    NSArray *plugins = %orig;
    if (!PXJBShouldBypassCached() || !plugins) return plugins;

    static NSSet *jbAppIDs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        jbAppIDs = [NSSet setWithArray:@[
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

    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:plugins.count];
    for (id plugin in plugins) {
        if ([plugin respondsToSelector:@selector(containingBundle)]) {
            id appBundle = [plugin performSelector:@selector(containingBundle)];
            if (appBundle && [appBundle respondsToSelector:@selector(bundleIdentifier)]) {
                NSString *appID = [appBundle performSelector:@selector(bundleIdentifier)];
                if (appID && [jbAppIDs containsObject:appID]) continue; // skip JB plugin
            }
        }
        // Also check plugin identifier hash for obfuscated detection
        if ([plugin respondsToSelector:@selector(pluginIdentifier)]) {
            NSString *pluginID = [plugin performSelector:@selector(pluginIdentifier)];
            if (pluginID && [jbAppIDs containsObject:pluginID]) continue;
        }
        [filtered addObject:plugin];
    }
    return [filtered copy];
}

%end

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
        // JBAppSpecific: Logos %init ObjC detectors
        // JBAggressiveRuntime: dyld/dlsym/task_info (experimental toggles only)
        // P0-B: syscall and sandbox_check are intentionally not production capabilities.
        void *libSystem = dlopen("/usr/lib/libSystem.B.dylib", RTLD_NOW);
        if (libSystem) {
            void *sym = NULL;

            sym = FindSymbol(NULL, "stat");
            if (sym) MSHookFunction(sym, (void *)hook_stat, (void **)&orig_stat);

            sym = FindSymbol(NULL, "stat64");
            if (sym) MSHookFunction(sym, (void *)hook_stat64, (void **)&orig_stat64);

            sym = FindSymbol(NULL, "lstat");
            if (sym) MSHookFunction(sym, (void *)hook_lstat, (void **)&orig_lstat);

            sym = FindSymbol(NULL, "lstat64");
            if (sym) MSHookFunction(sym, (void *)hook_lstat64, (void **)&orig_lstat64);

            sym = FindSymbol(NULL, "access");
            if (sym) MSHookFunction(sym, (void *)hook_access, (void **)&orig_access);

            sym = FindSymbol(NULL, "open");
            if (sym) MSHookFunction(sym, (void *)hook_open, (void **)&orig_open);

            sym = FindSymbol(NULL, "openat");
            if (sym) MSHookFunction(sym, (void *)hook_openat, (void **)&orig_openat);

            sym = FindSymbol(NULL, "fopen");
            if (sym) MSHookFunction(sym, (void *)hook_fopen, (void **)&orig_fopen);

            sym = FindSymbol(NULL, "opendir");
            if (sym) MSHookFunction(sym, (void *)hook_opendir, (void **)&orig_opendir);

            sym = FindSymbol(NULL, "readdir");
            if (sym) MSHookFunction(sym, (void *)hook_readdir, (void **)&orig_readdir);

            sym = FindSymbol(NULL, "readlink");
            if (sym) MSHookFunction(sym, (void *)hook_readlink, (void **)&orig_readlink);

            sym = FindSymbol(NULL, "realpath");
            if (sym) MSHookFunction(sym, (void *)hook_realpath, (void **)&orig_realpath);

            sym = FindSymbol(NULL, "connect");
            if (sym) MSHookFunction(sym, (void *)hook_connect, (void **)&orig_connect);

            sym = FindSymbol(NULL, "getenv");
            if (sym) MSHookFunction(sym, (void *)hook_getenv, (void **)&orig_getenv);

            // Phase 2
            sym = FindSymbol(NULL, "ptrace");
            if (sym) MSHookFunction(sym, (void *)hook_ptrace, (void **)&orig_ptrace);

            sym = FindSymbol(NULL, "fork");
            if (sym) MSHookFunction(sym, (void *)hook_fork, (void **)&orig_fork);

            sym = FindSymbol(NULL, "vfork");
            if (sym) MSHookFunction(sym, (void *)hook_vfork, (void **)&orig_vfork);

            // Priority 1: UID/GID spoofing - hide root access.
            sym = FindSymbol(NULL, "getuid");
            if (sym) MSHookFunction(sym, (void *)hook_getuid, (void **)&orig_getuid);

            sym = FindSymbol(NULL, "geteuid");
            if (sym) MSHookFunction(sym, (void *)hook_geteuid, (void **)&orig_geteuid);

            sym = FindSymbol(NULL, "getgid");
            if (sym) MSHookFunction(sym, (void *)hook_getgid, (void **)&orig_getgid);

            sym = FindSymbol(NULL, "getegid");
            if (sym) MSHookFunction(sym, (void *)hook_getegid, (void **)&orig_getegid);

            sym = FindSymbol(NULL, "setuid");
            if (sym) MSHookFunction(sym, (void *)hook_setuid, (void **)&orig_setuid);

            sym = FindSymbol(NULL, "seteuid");
            if (sym) MSHookFunction(sym, (void *)hook_seteuid, (void **)&orig_seteuid);

            sym = FindSymbol(NULL, "setgid");
            if (sym) MSHookFunction(sym, (void *)hook_setgid, (void **)&orig_setgid);

            sym = FindSymbol(NULL, "setegid");
            if (sym) MSHookFunction(sym, (void *)hook_setegid, (void **)&orig_setegid);

            sym = FindSymbol(NULL, "setreuid");
            if (sym) MSHookFunction(sym, (void *)hook_setreuid, (void **)&orig_setreuid);

            sym = FindSymbol(NULL, "setregid");
            if (sym) MSHookFunction(sym, (void *)hook_setregid, (void **)&orig_setregid);

            // Priority 1: getppid spoofing.
            sym = FindSymbol(NULL, "getppid");
            if (sym) MSHookFunction(sym, (void *)hook_getppid, (void **)&orig_getppid);

            // Priority 1: csops — clear CS_PLATFORM_BINARY.
            sym = FindSymbol(NULL, "csops");
            if (sym) MSHookFunction(sym, (void *)hook_csops, (void **)&orig_csops);

            // P0-B: syscall is intentionally not resolved or hooked.

            sym = FindSymbol(NULL, "system");
            if (sym) MSHookFunction(sym, (void *)hook_system, (void **)&orig_system);

            sym = FindSymbol(NULL, "popen");
            if (sym) MSHookFunction(sym, (void *)hook_popen, (void **)&orig_popen);

            // Block probe spawns (safe default; gate inside hook).
            sym = FindSymbol(NULL, "posix_spawn");
            if (sym) MSHookFunction(sym, (void *)hook_posix_spawn, (void **)&orig_posix_spawn);

            sym = FindSymbol(NULL, "posix_spawnp");
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

            sym = FindSymbol(NULL, "fstatfs");
            if (sym) MSHookFunction(sym, (void *)hook_fstatfs, (void **)&orig_fstatfs);

            sym = FindSymbol(NULL, "statvfs");
            if (sym) MSHookFunction(sym, (void *)hook_statvfs, (void **)&orig_statvfs);

            sym = FindSymbol(NULL, "fstatvfs");
            if (sym) MSHookFunction(sym, (void *)hook_fstatvfs, (void **)&orig_fstatvfs);

            // Priority 3: dlopen_preflight, creat, fstat variants, fs mutation hooks.
            sym = FindSymbol(NULL, "dlopen_preflight");
            if (sym) MSHookFunction(sym, (void *)hook_dlopen_preflight, (void **)&orig_dlopen_preflight);

            sym = FindSymbol(NULL, "creat");
            if (sym) MSHookFunction(sym, (void *)hook_creat, (void **)&orig_creat);

            sym = FindSymbol(NULL, "fstat");
            if (sym) MSHookFunction(sym, (void *)hook_fstat, (void **)&orig_fstat);

            sym = FindSymbol(NULL, "fstatat");
            if (sym) MSHookFunction(sym, (void *)hook_fstatat, (void **)&orig_fstatat);

            sym = FindSymbol(NULL, "faccessat");
            if (sym) MSHookFunction(sym, (void *)hook_faccessat, (void **)&orig_faccessat);

            sym = FindSymbol(NULL, "readlinkat");
            if (sym) MSHookFunction(sym, (void *)hook_readlinkat, (void **)&orig_readlinkat);

            sym = FindSymbol(NULL, "symlink");
            if (sym) MSHookFunction(sym, (void *)hook_symlink, (void **)&orig_symlink);

            sym = FindSymbol(NULL, "rename");
            if (sym) MSHookFunction(sym, (void *)hook_rename, (void **)&orig_rename);

            sym = FindSymbol(NULL, "link");
            if (sym) MSHookFunction(sym, (void *)hook_link, (void **)&orig_link);

            sym = FindSymbol(NULL, "unlink");
            if (sym) MSHookFunction(sym, (void *)hook_unlink, (void **)&orig_unlink);

            sym = FindSymbol(NULL, "remove");
            if (sym) MSHookFunction(sym, (void *)hook_remove_func, (void **)&orig_remove_func);

            sym = FindSymbol(NULL, "rmdir");
            if (sym) MSHookFunction(sym, (void *)hook_rmdir, (void **)&orig_rmdir);

            // Priority 3: objc_copyClassNamesForImage, NSVersionOf*.
            sym = FindSymbol(NULL, "objc_copyClassNamesForImage");
            if (sym) MSHookFunction(sym, (void *)hook_objc_copyClassNamesForImage, (void **)&orig_objc_copyClassNamesForImage);

            sym = FindSymbol(NULL, "NSVersionOfRunTimeLibrary");
            if (sym) MSHookFunction(sym, (void *)hook_NSVersionOfRunTimeLibrary, (void **)&orig_NSVersionOfRunTimeLibrary);

            sym = FindSymbol(NULL, "NSVersionOfLinkTimeLibrary");
            if (sym) MSHookFunction(sym, (void *)hook_NSVersionOfLinkTimeLibrary, (void **)&orig_NSVersionOfLinkTimeLibrary);

            // JailbreakDetector bypass hooks.
            sym = FindSymbol(NULL, "getmntinfo");
            if (sym) {
                gJBGetmntinfoEntry = (PXJBGetmntinfoFunction)sym;
                MSHookFunction(sym, (void *)hook_getmntinfo, (void **)&orig_getmntinfo);
                gJBMountSnapshotOwnerReady = orig_getmntinfo != NULL &&
                                             orig_getmntinfo != gJBGetmntinfoEntry &&
                                             PXJBPrepareMountSnapshotOwner();
            }

            sym = FindSymbol(NULL, "bootstrap_look_up");
            if (sym) MSHookFunction(sym, (void *)hook_bootstrap_look_up, (void **)&orig_bootstrap_look_up);

            // P1-E: vm_region_64 and task_get_exception_ports are high-risk,
            // process-wide introspection hooks and are absent from the default
            // module. A future implementation requires an explicit capability.

            // P0-A: capture fcntl only for verified internal calls. Do not hook the
            // variadic entry point until a command-complete ABI dispatcher exists.
            sym = FindSymbol(NULL, "fcntl");
            if (sym) {
                orig_fcntl = (PXJBFcntlFunction)sym;
            } else {
                PXLog(@"[JailbreakBypass] fcntl symbol unavailable; F_GETPATH helpers will use libc fallback");
            }

            sym = FindSymbol(NULL, "xpc_pipe_routine");
            if (sym) MSHookFunction(sym, (void *)hook_xpc_pipe_routine, (void **)&orig_xpc_pipe_routine);

            sym = FindSymbol(NULL, "xpc_pipe_routine_with_flags");
            if (sym) MSHookFunction(sym, (void *)hook_xpc_pipe_routine_with_flags, (void **)&orig_xpc_pipe_routine_with_flags);

            // P0-E: install the four indexed dyld APIs as one consistency group.
            // The patched entries are never called as originals; only the
            // trampolines returned by MSHookFunction are callable.
            if (wantDyldHide) {
                void *countEntry = FindSymbol(NULL, "_dyld_image_count");
                void *nameEntry = FindSymbol(NULL, "_dyld_get_image_name");
                void *headerEntry = FindSymbol(NULL, "_dyld_get_image_header");
                void *slideEntry = FindSymbol(NULL, "_dyld_get_image_vmaddr_slide");

                if (countEntry && nameEntry && headerEntry && slideEntry) {
                    gDyldImageCountEntry = (PXDyldImageCountFn)countEntry;
                    gDyldImageNameEntry = (PXDyldImageNameFn)nameEntry;
                    gDyldImageHeaderEntry = (PXDyldImageHeaderFn)headerEntry;
                    gDyldImageSlideEntry = (PXDyldImageSlideFn)slideEntry;

                    MSHookFunction(countEntry,
                                   (void *)hook__dyld_image_count,
                                   (void **)&orig__dyld_image_count);
                    MSHookFunction(nameEntry,
                                   (void *)hook__dyld_get_image_name,
                                   (void **)&orig__dyld_get_image_name);
                    MSHookFunction(headerEntry,
                                   (void *)hook__dyld_get_image_header,
                                   (void **)&orig__dyld_get_image_header);
                    MSHookFunction(slideEntry,
                                   (void *)hook__dyld_get_image_vmaddr_slide,
                                   (void **)&orig__dyld_get_image_vmaddr_slide);

                    BOOL dyldReady = PXDyldIndexedTrampolinesAreReady();
                    atomic_store_explicit(&gJBDyldIndexedHooksReady,
                                          dyldReady,
                                          memory_order_release);
                    if (dyldReady) {
                        sym = FindSymbol(NULL, "dladdr");
                        if (sym) MSHookFunction(sym, (void *)hook_dladdr, (void **)&orig_dladdr);
                    } else {
                        PXLog(@"[JailbreakBypass] dyld indexed group disabled: invalid trampoline");
                    }
                } else {
                    atomic_store_explicit(&gJBDyldIndexedHooksReady, false, memory_order_release);
                    PXLog(@"[JailbreakBypass] dyld indexed group disabled: missing symbol");
                }
            }

            // Phase 3 extension: block suspicious add_image callback registrations.
            if (wantBlockAddImage) {
                // _dyld_register_func_for_add_image is in libdyld/dyld; dlsym RTLD_DEFAULT works.
                sym = FindSymbol(NULL, "_dyld_register_func_for_add_image");
                if (sym) {
                    // See hook implementation below (near dyld helpers).
                    extern void PXJBInstallDyldAddImageBlocker(void *sym);
                    PXJBInstallDyldAddImageBlocker(sym);
                }
            }

            // Phase 3 extension: hide TASK_DYLD_INFO via task_info.
            if (wantHideTaskDyldInfo) {
                sym = FindSymbol(NULL, "task_info");
                if (sym) {
                    extern void PXJBInstallTaskInfoHook(void *sym);
                    PXJBInstallTaskInfoHook(sym);
                }
            }

            // Phase 3 extension: hide dl_iterate_phdr enumeration.
            if (wantHideDlIteratePhdr) {
                sym = FindSymbol(NULL, "dl_iterate_phdr");
                if (sym) {
                    MSHookFunction(sym, (void *)hook_dl_iterate_phdr, (void **)&orig_dl_iterate_phdr);
                }
            }

            // Phase 4: block dlopen/dlsym probes.
            if (wantBlockDlopenDlsym) {
                sym = FindSymbol(NULL, "dlopen");
                if (sym) MSHookFunction(sym, (void *)hook_dlopen, (void **)&orig_dlopen);
                sym = FindSymbol(NULL, "dlsym");
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
                sym = FindSymbol(NULL, "proc_regionfilename");
                if (sym) {
                    MSHookFunction(sym, (void *)hook_proc_regionfilename, (void **)&orig_proc_regionfilename);
                }
            }

            // Phase 7: hide ObjC runtime image list.
            if (wantHideObjcImages) {
                sym = FindSymbol(NULL, "objc_copyImageNames");
                if (sym) {
                    MSHookFunction(sym, (void *)hook_objc_copyImageNames, (void **)&orig_objc_copyImageNames);
                }
                sym = FindSymbol(NULL, "class_getImageName");
                if (sym) {
                    MSHookFunction(sym, (void *)hook_class_getImageName, (void **)&orig_class_getImageName);
                }
            }

            dlclose(libSystem);
        }

        %init;

        // Finalize install evidence, publish the immutable installed mask, then
        // activate the requested subset with one atomic policy publication.
        PXJBFinalizeCapabilityRegistryAndAudit();
        PXJBPublishPolicySnapshot(launchSettings);

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
    PXJB_AUDIT(kPXJBCapabilityCore, "readdir", orig_readdir, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "readlink", orig_readlink, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "realpath", orig_realpath, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "connect", orig_connect, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "getenv", orig_getenv, true);
    PXJB_AUDIT(kPXJBCapabilityCore, "ptrace", orig_ptrace, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "fork", orig_fork, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "vfork", orig_vfork, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "getuid", orig_getuid, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "geteuid", orig_geteuid, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "getgid", orig_getgid, false);
    PXJB_AUDIT(kPXJBCapabilityCore, "getegid", orig_getegid, false);
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
    PXJB_AUDIT(kPXJBCapabilityCore, "fstatat", orig_fstatat, true);
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
    PXJB_AUDIT(kPXJBCapabilityStatfs, "statvfs", orig_statvfs, false);
    PXJB_AUDIT(kPXJBCapabilityStatfs, "fstatvfs", orig_fstatvfs, false);

    PXJB_AUDIT(kPXJBCapabilityDyldIndexed, "_dyld_image_count", orig__dyld_image_count, true);
    PXJB_AUDIT(kPXJBCapabilityDyldIndexed, "_dyld_get_image_name", orig__dyld_get_image_name, true);
    PXJB_AUDIT(kPXJBCapabilityDyldIndexed, "_dyld_get_image_header", orig__dyld_get_image_header, true);
    PXJB_AUDIT(kPXJBCapabilityDyldIndexed, "_dyld_get_image_vmaddr_slide", orig__dyld_get_image_vmaddr_slide, true);
    PXJB_AUDIT(kPXJBCapabilityDyldIndexed, "dladdr", orig_dladdr, false);
    if (gJBCapabilities[kPXJBCapabilityDyldIndexed].requested &&
        !atomic_load_explicit(&gJBDyldIndexedHooksReady, memory_order_acquire)) {
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
