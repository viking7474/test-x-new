#import "PXRuntimeSnapshot.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "TLinkIOSLogging.h"
#import "IOSVersionInfo.h"
#import <WebKit/WebKit.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <substrate.h>
// #import <ellekit/ellekit.h> // Removed for rootful - using Substrate
#import <mach/mach_time.h>
#import <dispatch/dispatch.h>

#import "PXScope.h"
#import "PXPaths.h"
#import "PXIdentitySnapshot.h"
#import "PXSystemVersionTransformer.h"
#import "PXRuntimeOSCompatibility.h"
#import "PXUserAgentNormalizer.h"
#import "IdentifierManager.h"
#import "PXFileDebug.h"
#import <os/lock.h>
#import <time.h>
#import <math.h>
#import <stdint.h>

#import "AppVersionHooks.h"



// Add a macro for logging with a recognizable prefix
// Set DEBUG_LOG to 0 to reduce logging in production
#define DEBUG_LOG 0

#if DEBUG_LOG
#define IOSVERSION_LOG(fmt, ...) NSLog((@"[iosversion] " fmt), ##__VA_ARGS__)
#else
// Only log important messages when DEBUG_LOG is off
#define IOSVERSION_LOG(fmt, ...) if ([fmt hasPrefix:@"❌"] || [fmt hasPrefix:@"⚠️"]) NSLog((@"[iosversion] " fmt), ##__VA_ARGS__)
#endif

// Forward declarations
static NSString *getCurrentBundleID(void);
static NSDictionary *loadScopedApps(void);
static BOOL isInScopedAppsList(void);
static BOOL isCriticalSystemProcess(NSString *bundleID);
static void modifyUserAgentString(NSString *__strong *userAgentString, NSString *originalVersion, NSString *spoofedVersion);
static BOOL isSystemVersionFile(NSString *path);
static NSDictionary *spoofSystemVersionPlist(NSDictionary *originalPlist);

// Function declarations for file access hooks
NSData* replaced_NSData_dataWithContentsOfFile(Class self, SEL _cmd, NSString *path);
NSDictionary* replaced_NSDictionary_dictionaryWithContentsOfFile(Class self, SEL _cmd, NSString *path);
id replaced_NSString_stringWithContentsOfFile(Class self, SEL _cmd, NSString *path, NSStringEncoding enc, NSError **error);

// Original sysctlbyname function pointer for hooking
static int (*original_sysctlbyname)(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen);

// Original function pointers for direct file access hooks
static NSData* (*original_NSData_dataWithContentsOfFile)(Class self, SEL _cmd, NSString *path);
static NSDictionary* (*original_NSDictionary_dictionaryWithContentsOfFile)(Class self, SEL _cmd, NSString *path);
static id (*original_NSString_stringWithContentsOfFile)(Class self, SEL _cmd, NSString *path, NSStringEncoding enc, NSError **error);

#pragma mark - Reporting cache state

static const NSTimeInterval kIOSVersionCacheValidPeriod = 1800.0;
static const NSTimeInterval kIOSSystemVersionCacheValidPeriod = 0.1;
static os_unfair_lock gIOSVersionCacheLock = OS_UNFAIR_LOCK_INIT;
static NSDictionary *versionCache;
static PXIdentitySnapshot *gIOSVersionIdentity;
static NSString *gIOSSystemResult, *gIOSSystemBundle;
static NSDictionary *gIOSSystemInfo;
static double lastVersionLoad, gIOSSystemLoadedAt;
static BOOL gIOSInfoHasTime, gIOSSystemHasTime;
static uint64_t gIOSInfoRevision, gIOSSystemRevision;
static char kPXRuntimeIOSInfo;
static __thread BOOL gPXInsideIOSReportingHook;
static __thread BOOL gPXInsideIOSVersionInfo;

static double PXIOSVersionCacheTime(void) {
    struct timespec instant;
    if (clock_gettime(CLOCK_MONOTONIC, &instant) != 0) return NAN;
    return (double)instant.tv_sec + (double)instant.tv_nsec / 1000000000.0;
}

static BOOL PXIOSVersionTimeIsFresh(double now, double loadedAt, BOOL valid, double ttl) {
    return valid && isfinite(now) && isfinite(loadedAt) && now >= loadedAt && now - loadedAt < ttl;
}

static uint64_t PXIOSVersionInfoEpoch(void) {
    os_unfair_lock_lock(&gIOSVersionCacheLock);
    uint64_t revision = gIOSInfoRevision;
    os_unfair_lock_unlock(&gIOSVersionCacheLock);
    return revision;
}

static uint64_t PXIOSVersionSystemEpoch(void) {
    os_unfair_lock_lock(&gIOSVersionCacheLock);
    uint64_t revision = gIOSSystemRevision;
    os_unfair_lock_unlock(&gIOSVersionCacheLock);
    return revision;
}

static NSDictionary *PXIOSVersionCachedInfo(PXIdentitySnapshot *identity, double now, uint64_t *revision) {
    NSDictionary *result = nil;
    os_unfair_lock_lock(&gIOSVersionCacheLock);
    if (revision) *revision = gIOSInfoRevision;
    if (identity && gIOSVersionIdentity == identity &&
        PXIOSVersionTimeIsFresh(now, lastVersionLoad, gIOSInfoHasTime, kIOSVersionCacheValidPeriod)) result = versionCache;
    os_unfair_lock_unlock(&gIOSVersionCacheLock);
    return result;
}

static BOOL PXIOSVersionPublishInfo(NSDictionary *info, PXIdentitySnapshot *identity, double now, uint64_t revision) {
    __attribute__((objc_precise_lifetime)) NSDictionary *oldInfo = nil;
    __attribute__((objc_precise_lifetime)) PXIdentitySnapshot *oldIdentity = nil;
    BOOL published = NO;
    @try {
        os_unfair_lock_lock(&gIOSVersionCacheLock);
        if (identity && gIOSInfoRevision == revision) {
            oldInfo = versionCache; oldIdentity = gIOSVersionIdentity;
            versionCache = info; gIOSVersionIdentity = identity;
            lastVersionLoad = now; gIOSInfoHasTime = isfinite(now);
            gIOSInfoRevision++; published = YES;
        }
        os_unfair_lock_unlock(&gIOSVersionCacheLock);
        return published;
    } @finally { oldInfo = nil; oldIdentity = nil; info = nil; identity = nil; }
}

static NSString *PXIOSSystemCachedResult(NSDictionary *info, NSString *bundle, double now, uint64_t revision) {
    NSString *result = nil, *storedBundle = nil;
    NSDictionary *storedInfo = nil;
    BOOL fresh = NO;
    @try {
        os_unfair_lock_lock(&gIOSVersionCacheLock);
        result = gIOSSystemResult; storedBundle = gIOSSystemBundle; storedInfo = gIOSSystemInfo;
        fresh = gIOSSystemRevision == revision &&
            PXIOSVersionTimeIsFresh(now, gIOSSystemLoadedAt, gIOSSystemHasTime, kIOSSystemVersionCacheValidPeriod);
        os_unfair_lock_unlock(&gIOSVersionCacheLock);
        // String equality can execute foreign code; evaluate it after unlock.
        return fresh && info && storedInfo == info && [storedBundle isEqualToString:bundle] ? result : nil;
    } @finally { result = nil; storedBundle = nil; storedInfo = nil; info = nil; bundle = nil; }
}

static BOOL PXIOSSystemPublishResult(NSString *value, NSDictionary *info, NSString *bundle, double now, uint64_t revision) {
    NSString *frozenValue = nil, *frozenBundle = nil;
    __attribute__((objc_precise_lifetime)) NSString *oldValue = nil;
    __attribute__((objc_precise_lifetime)) NSString *oldBundle = nil;
    __attribute__((objc_precise_lifetime)) NSDictionary *oldInfo = nil;
    BOOL published = NO;
    @try {
        frozenValue = [value copy]; frozenBundle = [bundle copy];
        if (!frozenValue.length || !info || !frozenBundle.length) return NO;
        os_unfair_lock_lock(&gIOSVersionCacheLock);
        if (gIOSSystemRevision == revision) {
            oldValue = gIOSSystemResult; oldInfo = gIOSSystemInfo; oldBundle = gIOSSystemBundle;
            gIOSSystemResult = frozenValue; gIOSSystemInfo = info; gIOSSystemBundle = frozenBundle;
            gIOSSystemLoadedAt = now; gIOSSystemHasTime = isfinite(now);
            gIOSSystemRevision++; published = YES;
        }
        os_unfair_lock_unlock(&gIOSVersionCacheLock);
        return published;
    } @finally {
        frozenValue = nil; frozenBundle = nil; oldValue = nil; oldBundle = nil; oldInfo = nil;
        value = nil; info = nil; bundle = nil;
    }
}

static void PXIOSVersionInvalidateCache(void) {
    __attribute__((objc_precise_lifetime)) NSDictionary *oldInfo = nil;
    __attribute__((objc_precise_lifetime)) PXIdentitySnapshot *oldIdentity = nil;
    __attribute__((objc_precise_lifetime)) NSString *oldResult = nil;
    __attribute__((objc_precise_lifetime)) NSString *oldBundle = nil;
    __attribute__((objc_precise_lifetime)) NSDictionary *oldSystemInfo = nil;
    @try {
        os_unfair_lock_lock(&gIOSVersionCacheLock);
        oldInfo = versionCache; oldIdentity = gIOSVersionIdentity;
        oldResult = gIOSSystemResult; oldBundle = gIOSSystemBundle; oldSystemInfo = gIOSSystemInfo;
        versionCache = nil; gIOSVersionIdentity = nil;
        gIOSSystemResult = nil; gIOSSystemBundle = nil; gIOSSystemInfo = nil;
        gIOSInfoHasTime = NO; gIOSSystemHasTime = NO;
        gIOSInfoRevision++; gIOSSystemRevision++;
        os_unfair_lock_unlock(&gIOSVersionCacheLock);
    } @finally {
        oldInfo = nil; oldIdentity = nil; oldResult = nil; oldBundle = nil; oldSystemInfo = nil;
    }
}

#pragma mark - End reporting cache state

// NSBundle identity used by Info.plist hooks. Capture this before %init so hook
// bodies never need to call -bundleIdentifier and re-enter -infoDictionary.
static NSString *gPXIOSVersionMainBundleID = nil;
static __thread BOOL gPXInsideIOSVersionBundleInfoHook = NO;
static __thread BOOL gPXInsideIOSVersionCFBundleInfoHook = NO;

// Define constants
#define THROTTLE_INTERVAL_NSEC 100000000  // 100ms in nanoseconds

#pragma mark - Helper Functions

// Get the current bundle ID. Once the constructor captures the main identity,
// always use that immutable value so Info.plist hooks cannot recurse through
// -[NSBundle bundleIdentifier] -> -[NSBundle infoDictionary].
static NSString *getCurrentBundleID(void) {
    if (gPXIOSVersionMainBundleID.length) return gPXIOSVersionMainBundleID;
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

// Load scoped apps from the plist file
static NSDictionary *loadScopedApps(void) {
    PX_RUNTIME_READ_OPERATION;
    return PXScopedAppsSnapshot();
}

// Check if the current app is in the scoped apps list
static BOOL isInScopedAppsList(void) {
    PX_RUNTIME_READ_OPERATION;
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

// Critical system processes to exclude from spoofing
static NSSet *criticalSystemBundleIDs() {
    static NSSet *criticalBundleIDs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        criticalBundleIDs = [NSSet setWithArray:@[
            @"com.apple.springboard",
            @"com.apple.backboardd",
            @"com.apple.Preferences",
            @"com.apple.UIKit",
            @"com.apple.iokit",
            @"com.apple.mediaserverd",
            @"com.apple.dock",
            @"com.apple.security",
            @"com.apple.powerd",
            @"com.apple.tccd",
            @"com.apple.launchd",
            @"com.apple.trustd",
            @"com.apple.CoreTelephony"
        ]];
    });
    return criticalBundleIDs;
}

// Helper function to check if we should spoof for this bundle ID (with caching)
static BOOL shouldSpoofForBundle(NSString *bundleID) {
    PX_RUNTIME_READ_OPERATION;
    @try {
        // Basic validation
        if (!bundleID) {
            NSLog(@"[iosversion] Skipping iOS version spoofing for nil bundleID");
            return NO;
        }

        NSString *proc = [NSProcessInfo processInfo].processName;
        BOOL isScoped = PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack);
        
        if (isScoped) {
            NSLog(@"[iosversion] iOS Version spoofing enabled for %@", bundleID);
        }
        
        return isScoped;
    } @catch (NSException *e) {
        NSLog(@"[iosversion] Error in shouldSpoofForBundle: %@", e);
        return NO; // Default to NO for safety
    }
}

// Typed, immutable fields retain the original five-field completeness contract.
// Preserve optional fallback metadata while isolating mutable required strings.
static NSDictionary *PXIOSVersionFreezeInfo(id raw) {
    NSMutableDictionary *packet = nil;
    NSString *field = nil, *frozen = nil;
    @try {
        if (![raw isKindOfClass:NSDictionary.class]) return nil;
        packet = [raw mutableCopy];
        for (NSString *key in @[@"version", @"build", @"darwin", @"xnu", @"kernel_version"]) {
            field = packet[key];
            if (![field isKindOfClass:NSString.class] || !field.length) return nil;
            frozen = [field copy]; packet[key] = frozen;
        }
        return [packet copy];
    } @finally { packet = nil; field = nil; frozen = nil; raw = nil; }
}

// Scope/toggle must be checked BEFORE any systemVersion throttle hit. This is the
// same admission policy as shouldSpoofForBundle, without per-query success logs.
static BOOL PXIOSVersionReportingAllowedForBundle(NSString *bundleID) {
    IdentifierManager *manager = nil;
    NSString *process = nil;
    @try {
        if (!bundleID.length) return NO;
        process = [NSProcessInfo processInfo].processName;
        if (!PXProcessIsAllowedForSpoofing(bundleID, process, PXScopeOptionAllowSafariAuthStack)) return NO;
        manager = [IdentifierManager sharedManager];
        return manager && [manager isIdentifierEnabled:@"IOSVersion"];
    } @finally { manager = nil; process = nil; bundleID = nil; }
}

// RootHide memoizes only on its captured view. Rootful ties its 30-minute cache
// to the retained identity object and revokes in-flight writes on notification.
static NSDictionary *getIOSVersionInfo() {
    PX_RUNTIME_READ_OPERATION;
    if (gPXInsideIOSVersionInfo) return nil;
    gPXInsideIOSVersionInfo = YES;
    PXIdentitySnapshot *identity = nil, *currentIdentity = nil;
    NSDictionary *deviceIds = nil, *raw = nil, *result = nil;
    NSString *formatted = nil, *version = nil, *build = nil, *darwin = nil, *xnu = nil, *kernel = nil;
    NSTextCheckingResult *match = nil;
    NSRegularExpression *regex = nil;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    PXRuntimeReadSnapshot *view = PXCaptureRuntimeSnapshot();
#else
    double now = PXIOSVersionCacheTime();
    uint64_t revision = PXIOSVersionInfoEpoch();
#endif
    @try {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        result = objc_getAssociatedObject(view, &kPXRuntimeIOSInfo);
        if (result) return result;
#endif
        identity = PXCurrentIdentitySnapshot();
#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        result = PXIOSVersionCachedInfo(identity, now, NULL);
        if (result) return result;
#endif
        deviceIds = identity.valid ? identity.deviceIDs : nil;
        formatted = [deviceIds[@"IOSVersion"] isKindOfClass:NSString.class] ? deviceIds[@"IOSVersion"] : nil;
        build = [deviceIds[@"IOSBuild"] isKindOfClass:NSString.class] ? deviceIds[@"IOSBuild"] : nil;
        if ([formatted containsString:@"("]) {
            regex = [NSRegularExpression regularExpressionWithPattern:@"([0-9.]+)\\s*\\(([^)]+)\\)" options:0 error:nil];
            match = [regex firstMatchInString:formatted options:0 range:NSMakeRange(0, formatted.length)];
            if (match.numberOfRanges == 3) {
                version = [formatted substringWithRange:[match rangeAtIndex:1]];
                if (!build.length) build = [formatted substringWithRange:[match rangeAtIndex:2]];
            }
        }
        if (!version.length && formatted.length) version = formatted;
        darwin = [deviceIds[@"Darwin"] isKindOfClass:NSString.class] ? deviceIds[@"Darwin"] : nil;
        xnu = [deviceIds[@"XNU"] isKindOfClass:NSString.class] ? deviceIds[@"XNU"] : nil;
        kernel = [deviceIds[@"KernelVersion"] isKindOfClass:NSString.class] ? deviceIds[@"KernelVersion"] : nil;
        if (version.length && build.length && darwin.length && xnu.length && kernel.length) {
            raw = @{ @"version": version, @"build": build, @"darwin": darwin, @"xnu": xnu, @"kernel_version": kernel };
        }
#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        if (!raw) raw = [[IOSVersionInfo sharedManager] currentIOSVersionInfo];
#endif
        result = PXIOSVersionFreezeInfo(raw);
        if (!result) return nil;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        if (view) objc_setAssociatedObject(view, &kPXRuntimeIOSInfo, result, OBJC_ASSOCIATION_RETAIN);
#else
        currentIdentity = PXCurrentIdentitySnapshot();
        if (currentIdentity == identity) PXIOSVersionPublishInfo(result, identity, now, revision);
#endif
        return result;
    } @finally {
        identity = nil; currentIdentity = nil; deviceIds = nil; raw = nil; result = nil;
        formatted = nil; version = nil; build = nil; darwin = nil; xnu = nil; kernel = nil; match = nil; regex = nil;
        gPXInsideIOSVersionInfo = NO;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        view = nil;
#endif
    }
}

// Extract just the version number from the full version info
static NSString *getSpoofedSystemVersion() {
    PX_RUNTIME_READ_OPERATION;
    NSDictionary *versionInfo = getIOSVersionInfo();
    return versionInfo ? versionInfo[@"version"] : nil;
}

// Convert version string to NSOperatingSystemVersion struct
static NSOperatingSystemVersion getOperatingSystemVersion(NSString *versionString) {
    NSArray *components = [versionString componentsSeparatedByString:@"."];
    
    NSInteger majorVersion = components.count > 0 ? [components[0] integerValue] : 0;
    NSInteger minorVersion = components.count > 1 ? [components[1] integerValue] : 0;
    NSInteger patchVersion = components.count > 2 ? [components[2] integerValue] : 0;
    
    return (NSOperatingSystemVersion){majorVersion, minorVersion, patchVersion};
}

static BOOL PXHostMatchesSuffix(NSString *host, NSString *suffix) {
    if (![host isKindOfClass:[NSString class]] || !host.length) return NO;
    if (![suffix isKindOfClass:[NSString class]] || !suffix.length) return NO;
    NSString *h = [host lowercaseString];
    NSString *s = [suffix lowercaseString];
    if ([h isEqualToString:s]) return YES;
    return [h hasSuffix:[@"." stringByAppendingString:s]];
}

static BOOL PXIsSensitiveAuthHost(NSString *host) {
    // Allow login flows to work even when Safari/Auth stack spoof is enabled.
    // These domains are particularly sensitive to UA tampering.
    if (!host.length) return NO;
    return PXHostMatchesSuffix(host, @"google.com") ||
           PXHostMatchesSuffix(host, @"accounts.google.com") ||
           PXHostMatchesSuffix(host, @"gstatic.com") ||
           PXHostMatchesSuffix(host, @"googleusercontent.com") ||
           PXHostMatchesSuffix(host, @"recaptcha.net");
}

// ---- UA Debug Toggles (runtime, plist-driven) ----
// Stored in com.weaponx.securitySettings.plist (same file as other settings)

typedef struct {
    BOOL masterEnabled;
    BOOL traceEnabled;

    BOOL scopeSafari;
    BOOL scopeSafariViewService;
    BOOL scopeWebKit;

    BOOL hook_init;
    BOOL hook_setCustomUserAgent;
    BOOL hook_appNameUA;
    BOOL hook_requestHeaderUA;
    BOOL hook_sfUserAgentWithDomain;
    BOOL hook_sfDefaultUA;

    BOOL sensitiveHostExemptionsEnabled;
} PXUADebugSettings;

// One scalar packet: no Objective-C providers or releases while holding the lock.
#pragma mark - UA policy packet

typedef struct {
    PXUADebugSettings debug;
    BOOL mobileBuild, syncEnabled, fileLog, applyAll, injectJS;
} PXUAPolicyValues;

static os_unfair_lock gUAPolicyLock = OS_UNFAIR_LOCK_INIT;
static PXUAPolicyValues gUAPolicy;
static double gUAPolicyLoadedAt;
static BOOL gUAPolicyValid;
static uint64_t gUAPolicyEpoch, gUAPolicyRevision;
static __thread BOOL gUALoadingPolicy;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
static char kPXRuntimeUAPolicy;
#endif

static PXUAPolicyValues PXUADefaultPolicy(void) {
    PXUAPolicyValues values = {0};
    values.debug.scopeSafari = values.debug.scopeSafariViewService = values.debug.scopeWebKit = YES;
    values.debug.hook_init = values.debug.hook_setCustomUserAgent = values.debug.hook_appNameUA = YES;
    values.debug.hook_requestHeaderUA = values.debug.hook_sfUserAgentWithDomain = values.debug.hook_sfDefaultUA = YES;
    values.debug.sensitiveHostExemptionsEnabled = YES;
    values.fileLog = values.applyAll = values.injectJS = YES;
    return values;
}

static uint64_t PXUASyncEpoch(void) {
    os_unfair_lock_lock(&gUAPolicyLock);
    uint64_t epoch = gUAPolicyEpoch;
    os_unfair_lock_unlock(&gUAPolicyLock);
    return epoch;
}

static void PXUAPolicyInvalidate(void) {
    os_unfair_lock_lock(&gUAPolicyLock);
    gUAPolicyEpoch++; gUAPolicyRevision++; gUAPolicyValid = NO;
    os_unfair_lock_unlock(&gUAPolicyLock);
}

static BOOL PXUAPolicyBool(NSDictionary *settings, NSUserDefaults *defaults, NSString *key, BOOL fallback) {
    id value = nil;
    @try {
        value = settings[key];
        if (!value) value = [defaults objectForKey:key];
        // A present malformed value uses the established default, not another authority.
        return ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class]) ? [value boolValue] : fallback;
    } @finally { value = nil; settings = nil; defaults = nil; key = nil; }
}

static PXUAPolicyValues PXUABuildPolicy(NSDictionary *settings, NSUserDefaults *defaults) {
    PXUAPolicyValues values = PXUADefaultPolicy();
    @try {
        values.debug.masterEnabled = PXUAPolicyBool(settings, defaults, @"debugSafariUAMasterEnabled", NO);
        values.debug.traceEnabled = PXUAPolicyBool(settings, defaults, @"debugSafariUATraceEnabled", NO);
        values.debug.scopeSafari = PXUAPolicyBool(settings, defaults, @"debugSafariUAScope_applySafari", YES);
        values.debug.scopeSafariViewService = PXUAPolicyBool(settings, defaults, @"debugSafariUAScope_applySafariViewService", YES);
        values.debug.scopeWebKit = PXUAPolicyBool(settings, defaults, @"debugSafariUAScope_applyWebKit", YES);
        values.debug.hook_init = PXUAPolicyBool(settings, defaults, @"debugSafariUA_WKWebView_init", YES);
        values.debug.hook_setCustomUserAgent = PXUAPolicyBool(settings, defaults, @"debugSafariUA_WKWebView_setCustomUserAgent", YES);
        values.debug.hook_appNameUA = PXUAPolicyBool(settings, defaults, @"debugSafariUA_WKWebViewConfiguration_appNameUA", YES);
        values.debug.hook_requestHeaderUA = PXUAPolicyBool(settings, defaults, @"debugSafariUA_NSURLRequest_setHeaderUA", YES);
        values.debug.hook_sfUserAgentWithDomain = PXUAPolicyBool(settings, defaults, @"debugSafariUA_SFUserAgentController_userAgentWithDomain", YES);
        values.debug.hook_sfDefaultUA = PXUAPolicyBool(settings, defaults, @"debugSafariUA_SFUserAgentController_defaultUA", YES);
        values.debug.sensitiveHostExemptionsEnabled = PXUAPolicyBool(settings, defaults, @"debugSafariUA_SensitiveHostExemptionsEnabled", YES);
        values.mobileBuild = PXUAPolicyBool(settings, defaults, @"uaSpoofMobileBuildEnabled", NO);
        BOOL syncBoth = PXUAPolicyBool(settings, defaults, @"uaSyncHeaderAndJS", NO);
        BOOL syncJSOnly = PXUAPolicyBool(settings, defaults, @"uaSyncJSOnlyFromRequests", NO);
        values.syncEnabled = syncBoth || syncJSOnly;
        values.fileLog = PXUAPolicyBool(settings, defaults, @"debugSafariUA_LogFileEnabled", YES);
        values.applyAll = PXUAPolicyBool(settings, defaults, @"uaSyncApplyAllWebViews", YES);
        values.injectJS = PXUAPolicyBool(settings, defaults, @"uaSyncInjectJS", YES);
        return values;
    } @finally { settings = nil; defaults = nil; }
}

#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
static NSDictionary *PXReadSecuritySettingsDict(void) {
    NSDictionary *settings = nil;
    @try {
        settings = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist"];
        if ([settings isKindOfClass:NSDictionary.class]) return settings;
        settings = [NSDictionary dictionaryWithContentsOfFile:@"/private/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist"];
        return [settings isKindOfClass:NSDictionary.class] ? settings : nil;
    } @finally { settings = nil; }
}
#endif

static PXUAPolicyValues PXUACurrentPolicy(void) {
    PXUAPolicyValues values = PXUADefaultPolicy();
    if (gUALoadingPolicy) return values;
    gUALoadingPolicy = YES;
    NSDictionary *settings = nil;
    NSUserDefaults *defaults = nil;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    PXRuntimeReadSnapshot *view = nil;
    NSValue *boxed = nil;
#endif
    @try {
        PX_RUNTIME_READ_OPERATION;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        view = PXCaptureRuntimeSnapshot();
        boxed = objc_getAssociatedObject(view, &kPXRuntimeUAPolicy);
        if (boxed) { [boxed getValue:&values size:sizeof(values)]; return values; }
        settings = view.valid ? view.securitySettings : nil;
        values = PXUABuildPolicy(settings, nil);
        if (view) {
            boxed = [NSValue valueWithBytes:&values objCType:@encode(PXUAPolicyValues)];
            objc_setAssociatedObject(view, &kPXRuntimeUAPolicy, boxed, OBJC_ASSOCIATION_RETAIN);
        }
#else
        double now = PXIOSVersionCacheTime();
        os_unfair_lock_lock(&gUAPolicyLock);
        uint64_t epoch = gUAPolicyEpoch, revision = gUAPolicyRevision;
        BOOL hit = PXIOSVersionTimeIsFresh(now, gUAPolicyLoadedAt, gUAPolicyValid, 1.0);
        if (hit) values = gUAPolicy;
        os_unfair_lock_unlock(&gUAPolicyLock);
        if (hit) return values;
        settings = PXReadSecuritySettingsDict();
        defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
        values = PXUABuildPolicy(settings, defaults);
        os_unfair_lock_lock(&gUAPolicyLock);
        if (epoch != gUAPolicyEpoch) {
            values = PXUADefaultPolicy();
        } else if (revision == gUAPolicyRevision) {
            gUAPolicy = values; gUAPolicyLoadedAt = now;
            gUAPolicyValid = isfinite(now); gUAPolicyRevision++;
        } else {
            values = gUAPolicy;
        }
        os_unfair_lock_unlock(&gUAPolicyLock);
#endif
        return values;
    } @finally {
        settings = nil; defaults = nil;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        view = nil; boxed = nil;
#endif
        gUALoadingPolicy = NO;
    }
}

#pragma mark - End UA policy packet

static BOOL PXUADebugTraceEnabled(void) { return PXUACurrentPolicy().debug.traceEnabled; }
// Default OFF: older WebKit builds can reject impossible Mobile/<build> tokens.
static BOOL PXUAShouldSpoofMobileBuildToken(void) { return PXUACurrentPolicy().mobileBuild; }

static BOOL PXUADebugScopeAllowsWithSettings(NSString *bundleID, NSString *processName, PXUADebugSettings debug) {
    @try {
        if (!debug.masterEnabled) return YES;

        BOOL isSafari = PXIsSafariBrowserBundleIdentifier(bundleID);
        BOOL isSafariViewService = [bundleID isEqualToString:@"com.apple.SafariViewService"] ||
                                   ([processName isKindOfClass:[NSString class]] && [processName containsString:@"SafariViewService"]);
        BOOL isWebKit = ([bundleID hasPrefix:@"com.apple.WebKit"] ||
                         ([processName isKindOfClass:[NSString class]] && [processName containsString:@"WebKit"]));

        if (isSafari) return debug.scopeSafari;
        if (isSafariViewService) return debug.scopeSafariViewService;
        if (isWebKit) return debug.scopeWebKit;
        return YES;
    } @finally { bundleID = nil; processName = nil; }
}

static BOOL PXUAHostIsSensitive(NSString *hostOrDomain) {
    PX_RUNTIME_READ_OPERATION;
    if (!hostOrDomain.length) return NO;

    // In Full Spoof Test Mode we intentionally do NOT exempt sensitive hosts.
    // This is used to reproduce failure cases (e.g. Google login breakages) reliably.
    if (PXFullSpoofTestModeEnabled()) {
        return NO;
    }

    PXUADebugSettings debug = PXUACurrentPolicy().debug;
    if (debug.masterEnabled && !debug.sensitiveHostExemptionsEnabled) {
        return NO;
    }
    return PXIsSensitiveAuthHost(hostOrDomain);
}

static void PXUADebugTrace(NSString *hookName,
                           NSString *bundleID,
                           NSString *processName,
                           NSString *host,
                           NSString *decision,
                           NSString *reason,
                           NSString *uaBefore,
                           NSString *uaAfter) {
    if (!PXUADebugTraceEnabled()) return;

    // Optional file logging to avoid relying on syslog.
    // Enabled by default when trace is enabled; can be disabled via plist key.
    static dispatch_queue_t logQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logQueue = dispatch_queue_create("com.hydra.tlinkios.uadebuglog", DISPATCH_QUEUE_SERIAL);
    });

    BOOL fileLogEnabled = PXUACurrentPolicy().fileLog;
    NSString *logPath = @"/var/mobile/Documents/WeaponX_UADebug.log";
    NSString *h = host.length ? host : @"(nil)";
    NSString *b = bundleID.length ? bundleID : @"(nil)";
    NSString *p = processName.length ? processName : @"(nil)";
    NSString *r = reason.length ? reason : @"";
    NSMutableString *line = [NSMutableString string];
    NSTimeInterval ts = [[NSDate date] timeIntervalSince1970];
    if (uaBefore.length || uaAfter.length) {
        [line appendFormat:@"[%.0f] [UADebug] hook=%@ bid=%@ proc=%@ host=%@ decision=%@ %@ ua='%@' -> '%@'",
         ts, hookName, b, p, h, decision, r, uaBefore ?: @"", uaAfter ?: @""];
    } else {
        [line appendFormat:@"[%.0f] [UADebug] hook=%@ bid=%@ proc=%@ host=%@ decision=%@ %@",
         ts, hookName, b, p, h, decision, r];
    }

    IOSVERSION_LOG(@"%@", line);

    if (fileLogEnabled) {
        dispatch_async(logQueue, ^{
            @autoreleasepool {
                NSFileManager *fm = [NSFileManager defaultManager];
                // Rotate if too large (2MB)
                NSDictionary *attrs = [fm attributesOfItemAtPath:logPath error:nil];
                unsigned long long size = [attrs[NSFileSize] respondsToSelector:@selector(unsignedLongLongValue)] ? [attrs[NSFileSize] unsignedLongLongValue] : 0;
                if (size > (2ULL * 1024ULL * 1024ULL)) {
                    NSString *rotated = [logPath stringByAppendingString:@".1"];
                    [fm removeItemAtPath:rotated error:nil];
                    [fm moveItemAtPath:logPath toPath:rotated error:nil];
                }

                if (![fm fileExistsAtPath:logPath]) {
                    [fm createFileAtPath:logPath contents:nil attributes:@{NSFilePosixPermissions: @(0644)}];
                }

                NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:logPath];
                if (!fh) return;
                @try {
                    [fh seekToEndOfFile];
                    NSData *d = [[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
                    if (d) {
                        [fh writeData:d];
                    }
                } @catch (__unused NSException *e) {
                }
                @try {
                    [fh closeFile];
                } @catch (__unused NSException *e) {
                }
            }
        });
    }
}

// ---- UA Sync: weak registry and all WebKit access are main-thread owned ----
#pragma mark - UA sync pipeline

static NSHashTable<WKWebView *> *gWKWebViews;
static __thread BOOL gUASyncApplying;

static void PXUASyncRegisterWKWebView(WKWebView *webView) {
    __weak WKWebView *weakView = webView;
    dispatch_block_t operation = nil;
    @try {
        if (!webView) return;
        {
            operation = ^{
                WKWebView *owner = nil;
                @try {
                    owner = weakView;
                    if (!owner) return;
                    if (!gWKWebViews) gWKWebViews = [[NSHashTable alloc]
                        initWithOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality capacity:0];
                    [gWKWebViews addObject:owner];
                } @catch (__unused NSException *exception) {
                } @finally { owner = nil; }
            };
        }
        if ([NSThread isMainThread]) operation();
        else dispatch_async(dispatch_get_main_queue(), operation);
    } @finally { webView = nil; operation = nil; }
}

static NSString *PXUASyncScript(NSString *ua) {
    NSArray *packet = nil;
    NSData *data = nil;
    NSString *arrayJSON = nil, *literal = nil, *script = nil;
    @try {
        packet = @[ua];
        data = [NSJSONSerialization dataWithJSONObject:packet options:0 error:nil];
        if (!data) return nil;
        arrayJSON = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (arrayJSON.length < 2) return nil;
        literal = [arrayJSON substringWithRange:NSMakeRange(1, arrayJSON.length - 2)];
        literal = [literal stringByReplacingOccurrencesOfString:@"\u2028" withString:@"\\u2028"];
        literal = [literal stringByReplacingOccurrencesOfString:@"\u2029" withString:@"\\u2029"];
        script = [NSString stringWithFormat:
            @"(function(){try{var value=%@;Object.defineProperty(navigator,'userAgent',{get:function(){return value;},configurable:true});}catch(e){}})();", literal];
        return script;
    } @finally { ua = nil; packet = nil; data = nil; arrayJSON = nil; literal = nil; script = nil; }
}

static BOOL PXUASyncViewMatches(WKWebView *view, NSString *host, BOOL applyAll) {
    NSURL *url = nil;
    NSString *viewHost = nil, *canonicalHost = nil;
    @try {
        if (applyAll) return YES;
        url = view.URL; viewHost = url.host; canonicalHost = viewHost.lowercaseString;
        return canonicalHost.length && [canonicalHost isEqualToString:host];
    } @finally { view = nil; host = nil; url = nil; viewHost = nil; canonicalHost = nil; }
}

static void PXUASyncApplyToView(WKWebView *view, NSString *host, NSString *ua, PXUAPolicyValues policy, uint64_t epoch) {
    NSString *script = nil;
    BOOL previous = gUASyncApplying;
    @try {
        if (![NSThread isMainThread] || epoch != PXUASyncEpoch()) return;
        if (!PXUASyncViewMatches(view, host, policy.applyAll)) return;
        gUASyncApplying = YES;
        if ([view respondsToSelector:@selector(setCustomUserAgent:)]) [view setCustomUserAgent:ua];
        // A setter may synchronously navigate or deliver a settings notification.
        if (epoch != PXUASyncEpoch() || !PXUASyncViewMatches(view, host, policy.applyAll)) return;
        if (policy.injectJS && [view respondsToSelector:@selector(evaluateJavaScript:completionHandler:)]) {
            script = PXUASyncScript(ua);
            if (script && epoch == PXUASyncEpoch()) [view evaluateJavaScript:script completionHandler:nil];
        }
    } @finally { gUASyncApplying = previous; view = nil; host = nil; ua = nil; script = nil; }
}

static void PXUASyncApplyToWebViewsForHost(NSString *host, NSString *ua, uint64_t epoch) {
    NSString *lowerHost = nil, *frozenHost = nil, *frozenUA = nil;
    dispatch_block_t operation = nil;
    @try {
        if (!host.length || !ua.length) return;
        lowerHost = host.lowercaseString; frozenHost = [lowerHost copy]; frozenUA = [ua copy];
        {
            operation = ^{
                NSArray<WKWebView *> *targets = nil;
                @try {
                    PX_RUNTIME_READ_OPERATION;
                    if (epoch != PXUASyncEpoch()) return;
                    PXUAPolicyValues policy = PXUACurrentPolicy();
                    if (!policy.syncEnabled || epoch != PXUASyncEpoch()) return;
                    targets = gWKWebViews.allObjects;
                    for (WKWebView *view in targets) {
                        if (epoch != PXUASyncEpoch()) break;
                        @try { PXUASyncApplyToView(view, frozenHost, frozenUA, policy, epoch); }
                        @catch (__unused NSException *exception) { }
                    }
                } @catch (__unused NSException *exception) {
                    // Optional sync must not turn a policy/provider failure into a main-queue crash.
                } @finally { targets = nil; }
            };
        }
        // Preserve asynchronous application even for a request made on main.
        dispatch_async(dispatch_get_main_queue(), operation);
    } @finally { host = nil; ua = nil; lowerHost = nil; frozenHost = nil; frozenUA = nil; operation = nil; }
}

#pragma mark - End UA sync pipeline

// Compatibility wrapper: every UA surface delegates to the central normalizer.
static void modifyUserAgentString(NSString *__strong *userAgentString, NSString *originalVersion, NSString *spoofedVersion) {
    PX_RUNTIME_READ_OPERATION;
    NSDictionary *versionInfo = nil;
    NSString *build = nil, *normalized = nil;
    @try {
        (void)originalVersion;
        if (!userAgentString || !*userAgentString || !spoofedVersion.length) return;
        versionInfo = getIOSVersionInfo(); build = versionInfo[@"build"];
        normalized = PXNormalizeUserAgent(*userAgentString, spoofedVersion, build, PXUAShouldSpoofMobileBuildToken());
        if (normalized.length) *userAgentString = normalized;
    } @finally { originalVersion = nil; spoofedVersion = nil; versionInfo = nil; build = nil; normalized = nil; }
}

#pragma mark - Canonical WKWebView User Agent

static const void *kPXUABaseUserAgentKey = &kPXUABaseUserAgentKey;
static const void *kPXUAOwnsCustomUserAgentKey = &kPXUAOwnsCustomUserAgentKey;
static const void *kPXUASetterIntentKey = &kPXUASetterIntentKey;
static __thread BOOL gUACanonicalApplying = NO;
static __thread BOOL gPXPreparingUA;

static NSString *PXUANativeBaseUserAgent(WKWebViewConfiguration *configuration) {
    NSString *applicationName = nil, *userAgent = nil;
    @try {
        @try {
            if ([configuration respondsToSelector:@selector(applicationNameForUserAgent)]) {
                applicationName = configuration.applicationNameForUserAgent;
            }
        } @catch (__unused NSException *exception) {
        }

        @try {
            Class webViewClass = NSClassFromString(@"WKWebView");
            SEL selector = NSSelectorFromString(@"_standardUserAgentWithApplicationName:");
            if (webViewClass && [webViewClass respondsToSelector:selector]) {
                NSString *(*sendMessage)(id, SEL, id) =
                    (NSString *(*)(id, SEL, id))objc_msgSend;
                userAgent = sendMessage(webViewClass, selector, applicationName);
                if ([userAgent isKindOfClass:[NSString class]] && userAgent.length) {
                    return userAgent;
                }
            }
        } @catch (__unused NSException *exception) {
        }

        @try {
            Class controllerClass = NSClassFromString(@"SFUserAgentController");
            SEL selector = NSSelectorFromString(@"defaultUserAgentString");
            if (controllerClass && [controllerClass respondsToSelector:selector]) {
                NSString *(*sendMessage)(id, SEL) = (NSString *(*)(id, SEL))objc_msgSend;
                userAgent = sendMessage(controllerClass, selector);
                if ([userAgent isKindOfClass:[NSString class]] && userAgent.length) {
                    return userAgent;
                }
            }
        } @catch (__unused NSException *exception) {
        }

        return nil;
    } @finally { configuration = nil; applicationName = nil; userAgent = nil; }
}

static NSString *PXUASyntheticSpoofedUserAgent(WKWebViewConfiguration *configuration) {
    PX_RUNTIME_READ_OPERATION;
    NSDictionary *versionInfo = nil;
    NSString *version = nil, *build = nil, *underscoredVersion = nil, *deviceToken = nil, *applicationName = nil;
    NSMutableString *userAgent = nil;
    @try {
        versionInfo = getIOSVersionInfo();
        version = [versionInfo[@"version"] isKindOfClass:[NSString class]] ? versionInfo[@"version"] : nil;
        build = [versionInfo[@"build"] isKindOfClass:[NSString class]] ? versionInfo[@"build"] : nil;
        if (!version.length) return nil;
        if (!build.length) build = @"15E148";

        underscoredVersion = [version stringByReplacingOccurrencesOfString:@"." withString:@"_"];
        deviceToken = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"iPad; CPU OS" : @"iPhone; CPU iPhone OS";
        userAgent = [NSMutableString stringWithFormat:
            @"Mozilla/5.0 (%@ %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/%@",
            deviceToken,
            underscoredVersion,
            build];

        @try {
            applicationName = configuration.applicationNameForUserAgent;
            if (applicationName.length) [userAgent appendFormat:@" %@", applicationName];
        } @catch (__unused NSException *exception) {
        }
        return userAgent;
    } @finally {
        configuration = nil; versionInfo = nil; version = nil; build = nil; underscoredVersion = nil;
        deviceToken = nil; applicationName = nil; userAgent = nil;
    }
}

static BOOL PXUAShouldApplyForHost(NSString *bundleID, NSString *processName, NSString *host) {
    PX_RUNTIME_READ_OPERATION;
    @try {
        BOOL safariPermission = PXProcessIsAllowedForSpoofing(bundleID, processName, PXScopeOptionAllowSafariAuthStack);
        BOOL safariStack = safariPermission && PXIsSafariStackProcess(bundleID, processName);
        if (!PXWebKitHelperProcessIsInScope(bundleID, processName, safariPermission)) return NO;
        if (!safariStack && !shouldSpoofForBundle(bundleID)) return NO;

        if (!PXFullSpoofTestModeEnabled()) {
            if (PXUAHostIsSensitive(host)) return NO;
            // Safari/Auth helpers must wait until the destination host is known.
            if (safariStack && !host.length) return NO;
        }
        return YES;
    } @finally { bundleID = nil; processName = nil; host = nil; }
}

static NSString *PXUAModifiedUserAgent(NSString *baseUserAgent, WKWebViewConfiguration *configuration) {
    PX_RUNTIME_READ_OPERATION;
    NSString *spoofedVersion = nil, *candidate = nil, *modified = nil;
    @try {
        spoofedVersion = getSpoofedSystemVersion();
        if (!spoofedVersion.length) return nil;
        candidate = baseUserAgent.length ? baseUserAgent : PXUASyntheticSpoofedUserAgent(configuration);
        if (!candidate.length) return nil;
        modified = [candidate mutableCopy];
        modifyUserAgentString(&modified, @"native", spoofedVersion);
        return modified;
    } @finally { baseUserAgent = nil; configuration = nil; spoofedVersion = nil; candidate = nil; modified = nil; }
}

static void PXUASetExactCustomUserAgent(WKWebView *webView, NSString *userAgent, BOOL owned) {
    if (!webView) return;
    BOOL previous = gUACanonicalApplying;
    gUACanonicalApplying = YES;
    @try {
        [webView setCustomUserAgent:userAgent];
        objc_setAssociatedObject(webView,
                                 kPXUAOwnsCustomUserAgentKey,
                                 @(owned),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @finally {
        gUACanonicalApplying = previous; webView = nil; userAgent = nil;
    }
}

static void PXUAEnsureCanonicalUserAgent(WKWebView *webView,
                                         WKWebViewConfiguration *configuration,
                                         NSString *host,
                                         NSString *hookName) {
    PX_RUNTIME_READ_OPERATION;
    NSString *bundleID = nil, *processName = nil, *resolvedBase = nil, *baseUserAgent = nil;
    NSString *before = nil, *desiredUserAgent = nil, *currentUserAgent = nil;
    id storedBase = nil;
    BOOL previous = gPXPreparingUA;
    @try {
        if (!webView || ![NSThread isMainThread] || previous) return;
        gPXPreparingUA = YES;
        bundleID = [[NSBundle mainBundle] bundleIdentifier];
        processName = [NSProcessInfo processInfo].processName;
        PXUADebugSettings debug = PXUACurrentPolicy().debug;
        if (debug.masterEnabled && !PXUADebugScopeAllowsWithSettings(bundleID, processName, debug)) {
            PXUADebugTrace(hookName, bundleID, processName, host, @"skip", @"reason=scope", nil, nil);
            return;
        }
        if (debug.masterEnabled && !debug.hook_init) {
            PXUADebugTrace(hookName, bundleID, processName, host, @"skip", @"reason=toggle", nil, nil);
            return;
        }

        storedBase = objc_getAssociatedObject(webView, kPXUABaseUserAgentKey);
        if (!storedBase) {
            resolvedBase = PXUANativeBaseUserAgent(configuration ?: webView.configuration);
            storedBase = resolvedBase ?: (id)[NSNull null];
            objc_setAssociatedObject(webView,
                                     kPXUABaseUserAgentKey,
                                     storedBase,
                                     OBJC_ASSOCIATION_COPY_NONATOMIC);
        }
        baseUserAgent = [storedBase isKindOfClass:[NSString class]] ? storedBase : nil;
        BOOL currentlyOwned = [objc_getAssociatedObject(webView, kPXUAOwnsCustomUserAgentKey) boolValue];
        BOOL shouldApply = PXUAShouldApplyForHost(bundleID, processName, host);

        if (!shouldApply) {
            if (currentlyOwned) {
                before = webView.customUserAgent;
                PXUASetExactCustomUserAgent(webView, baseUserAgent, NO);
                PXUADebugTrace(hookName, bundleID, processName, host, @"restore", @"reason=host", before, baseUserAgent);
            }
            return;
        }

        desiredUserAgent = PXUAModifiedUserAgent(baseUserAgent, configuration ?: webView.configuration);
        if (!desiredUserAgent.length) return;

        currentUserAgent = webView.customUserAgent;
        if (![currentUserAgent isEqualToString:desiredUserAgent]) {
            PXUASetExactCustomUserAgent(webView, desiredUserAgent, YES);
            PXUADebugTrace(hookName, bundleID, processName, host, @"modify", @"canonical-before-load", currentUserAgent, desiredUserAgent);
        } else if (!currentlyOwned) {
            objc_setAssociatedObject(webView,
                                     kPXUAOwnsCustomUserAgentKey,
                                     @YES,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } @finally {
        gPXPreparingUA = previous;
        webView = nil; configuration = nil; host = nil; hookName = nil;
        bundleID = nil; processName = nil; storedBase = nil; resolvedBase = nil; baseUserAgent = nil;
        before = nil; desiredUserAgent = nil; currentUserAgent = nil;
    }
}

#pragma mark - UA request preparation

typedef NS_ENUM(NSUInteger, PXUAHeaderKind) {
    PXUAHeaderOther, PXUAHeaderUserAgent, PXUAHeaderLanguage, PXUAHeaderPlatform, PXUAHeaderMobile
};

static PXUAHeaderKind PXUAClassifyHeader(id field) {
    @try {
        if (![field isKindOfClass:NSString.class]) return PXUAHeaderOther;
        if ([field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) return PXUAHeaderUserAgent;
        if ([field caseInsensitiveCompare:@"Accept-Language"] == NSOrderedSame) return PXUAHeaderLanguage;
        if ([field caseInsensitiveCompare:@"Sec-CH-UA-Platform"] == NSOrderedSame) return PXUAHeaderPlatform;
        if ([field caseInsensitiveCompare:@"Sec-CH-UA-Mobile"] == NSOrderedSame) return PXUAHeaderMobile;
        return PXUAHeaderOther;
    } @finally { field = nil; }
}

// Strong output slots avoid ARC autoreleasing writeback temporaries on exceptional exits.
static NSString *PXUAPrepareRequestHeader(NSMutableURLRequest *request, NSString *value, NSString *field,
                                        PXUAHeaderKind kind, NSString *__strong *syncHost,
                                        NSString *__strong *syncUA, uint64_t *epoch) {
    NSString *bundleID = nil, *processName = nil, *host = nil, *version = nil, *result = nil, *localeID = nil;
    NSURL *url = nil;
    NSLocale *locale = nil;
    NSDictionary *inputHeaders = nil, *canonical = nil;
    NSString *modifiedValue = nil;
    BOOL previous = gPXPreparingUA;
    @try {
        if (previous) return nil;
        gPXPreparingUA = YES;
        // Freeze invalidation authority before any policy/scope/version provider.
        uint64_t syncEpoch = kind == PXUAHeaderUserAgent ? PXUASyncEpoch() : 0;
        bundleID = [[NSBundle mainBundle] bundleIdentifier];
        processName = [NSProcessInfo processInfo].processName;
        url = request.URL; host = url.host;
        if (kind != PXUAHeaderUserAgent) {
            if (!PXUAShouldApplyForHost(bundleID, processName, host)) return nil;
            inputHeaders = @{field: value}; locale = [NSLocale currentLocale]; localeID = locale.localeIdentifier;
            canonical = PXCanonicalWebIdentityHeaders(inputHeaders, localeID, UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone);
            NSString *name = kind == PXUAHeaderLanguage ? @"Accept-Language" :
                (kind == PXUAHeaderPlatform ? @"Sec-CH-UA-Platform" : @"Sec-CH-UA-Mobile");
            result = canonical[name];
            return [result isKindOfClass:NSString.class] ? result : nil;
        }
        PXUAPolicyValues policy = PXUACurrentPolicy();
        PXUADebugSettings debug = policy.debug;
        if (debug.masterEnabled && !PXUADebugScopeAllowsWithSettings(bundleID, processName, debug)) {
            PXUADebugTrace(@"NSMutableURLRequest.setValue(User-Agent)", bundleID, processName, host, @"skip", @"reason=scope", value, nil);
            return nil;
        }
        BOOL headerModifyEnabled = !(debug.masterEnabled && !debug.hook_requestHeaderUA);
        BOOL syncEnabled = policy.syncEnabled;
        if (!headerModifyEnabled && !syncEnabled) {
            PXUADebugTrace(@"NSMutableURLRequest.setValue(User-Agent)", bundleID, processName, host, @"skip", @"reason=toggle", value, nil);
            return nil;
        }
        if (!shouldSpoofForBundle(bundleID)) return nil;
        if (PXUAHostIsSensitive(host)) {
            PXUADebugTrace(@"NSMutableURLRequest.setValue(User-Agent)", bundleID, processName, host, @"skip", @"reason=sensitive", value, nil);
            return nil;
        }
        version = getSpoofedSystemVersion();
        if (!version) return nil;
        modifiedValue = [value mutableCopy];
        modifyUserAgentString(&modifiedValue, @"native", version);
        if ([modifiedValue isEqualToString:value]) return nil;
        if (syncEnabled && host.length) {
            *syncHost = [host copy]; *syncUA = [modifiedValue copy]; *epoch = syncEpoch;
            PXUADebugTrace(@"UASync.remember", bundleID, processName, host, @"modify", headerModifyEnabled ? @"" : @"reason=jsOnly", value, modifiedValue);
        }
        PXUADebugTrace(@"NSMutableURLRequest.setValue(User-Agent)", bundleID, processName, host,
                      headerModifyEnabled ? @"modify" : @"skip", headerModifyEnabled ? @"" : @"reason=jsOnly", value, modifiedValue);
        return headerModifyEnabled ? modifiedValue : nil;
    } @finally {
        gPXPreparingUA = previous;
        request = nil; value = nil; field = nil; bundleID = nil; processName = nil; host = nil; version = nil;
        result = nil; localeID = nil; url = nil; locale = nil; inputHeaders = nil; canonical = nil; modifiedValue = nil;
    }
}

#pragma mark - End UA request preparation

#pragma mark - UIDevice Hooks

%hook UIDevice

// Hook the systemVersion method to return our spoofed version
- (NSString *)systemVersion {
    PX_RUNTIME_READ_OPERATION;
    if (gPXInsideIOSReportingHook) return %orig;
    gPXInsideIOSReportingHook = YES;
    NSString *bundleID = nil, *reportedVersion = nil, *originalVersion = nil;
    NSDictionary *versionInfo = nil;
#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    double now = PXIOSVersionCacheTime();
    uint64_t revision = PXIOSVersionSystemEpoch();
#endif
    @try {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        originalVersion = %orig;
#endif
        @try {
            bundleID = getCurrentBundleID();
            if (PXIOSVersionReportingAllowedForBundle(bundleID)) {
                versionInfo = getIOSVersionInfo();
#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
                reportedVersion = PXIOSSystemCachedResult(versionInfo, bundleID, now, revision);
                if (reportedVersion) return reportedVersion;
#endif
                if (!PXReportingIOSVersionBuildForBundle(versionInfo[@"version"], versionInfo[@"build"], bundleID, &reportedVersion, NULL)) reportedVersion = nil;
            }
        } @catch (NSException *exception) {
            reportedVersion = nil;
            IOSVERSION_LOG(@"❌ Error in systemVersion projection: %@", exception);
        }
#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        // Outside projection catch: an original exception must not call it twice.
        originalVersion = %orig;
        @try {
            if (reportedVersion.length) PXIOSSystemPublishResult(reportedVersion, versionInfo, bundleID, now, revision);
        } @catch (__unused NSException *exception) { reportedVersion = nil; }
#endif
        if (reportedVersion.length) return reportedVersion;
        return originalVersion;
    } @finally {
        bundleID = nil; reportedVersion = nil; originalVersion = nil; versionInfo = nil;
        gPXInsideIOSReportingHook = NO;
    }
}

%end

#pragma mark - NSProcessInfo Hooks

%hook NSProcessInfo

// Hook operatingSystemVersion to return our spoofed version
- (NSOperatingSystemVersion)operatingSystemVersion {
    PX_RUNTIME_READ_OPERATION;
    if (gPXInsideIOSReportingHook) return %orig;
    gPXInsideIOSReportingHook = YES;
    NSString *bundleID = nil, *reportedVersion = nil, *reportedBuild = nil;
    NSDictionary *versionInfo = nil;
    @try {
        NSOperatingSystemVersion originalVersion = %orig;
        @try {
            bundleID = getCurrentBundleID();
            if (PXIOSVersionReportingAllowedForBundle(bundleID)) {
                versionInfo = getIOSVersionInfo();
                if (PXReportingIOSVersionBuildForBundle(versionInfo[@"version"], versionInfo[@"build"], bundleID, &reportedVersion, &reportedBuild)) {
                    NSOperatingSystemVersion reportedStructVersion = getOperatingSystemVersion(reportedVersion);
                    NSLog(@"[iosversion] NSProcessInfo.operatingSystemVersion: %ld.%ld.%ld → %ld.%ld.%ld (configured=%@)",
                          (long)originalVersion.majorVersion, (long)originalVersion.minorVersion, (long)originalVersion.patchVersion,
                          (long)reportedStructVersion.majorVersion, (long)reportedStructVersion.minorVersion, (long)reportedStructVersion.patchVersion,
                          versionInfo[@"version"]);
                    return reportedStructVersion;
                }
            }
        } @catch (NSException *exception) { IOSVERSION_LOG(@"❌ Error in operatingSystemVersion projection: %@", exception); }
        return originalVersion;
    } @finally {
        bundleID = nil; reportedVersion = nil; reportedBuild = nil; versionInfo = nil;
        gPXInsideIOSReportingHook = NO;
    }
}

// Availability/capability checks are intentionally not hooked. Reporting getters
// may expose an upward profile, but UIKit/dyld/compiler availability must continue
// to reflect the physical runtime.

// Additional method to hook for getting raw operating system version string
- (NSString *)operatingSystemVersionString {
    PX_RUNTIME_READ_OPERATION;
    if (gPXInsideIOSReportingHook) return %orig;
    gPXInsideIOSReportingHook = YES;
    NSString *bundleID = nil, *reportedVersion = nil, *reportedBuild = nil, *originalVersion = nil;
    NSDictionary *versionInfo = nil;
    @try {
        originalVersion = %orig;
        @try {
            bundleID = getCurrentBundleID();
            if (PXIOSVersionReportingAllowedForBundle(bundleID)) {
                versionInfo = getIOSVersionInfo();
                if (PXReportingIOSVersionBuildForBundle(versionInfo[@"version"], versionInfo[@"build"], bundleID, &reportedVersion, &reportedBuild)) {
                    return [NSString stringWithFormat:@"Version %@ (Build %@)", reportedVersion, reportedBuild];
                }
            }
        } @catch (NSException *exception) { IOSVERSION_LOG(@"❌ Error in operatingSystemVersionString projection: %@", exception); }
        return originalVersion;
    } @finally {
        bundleID = nil; reportedVersion = nil; reportedBuild = nil; originalVersion = nil; versionInfo = nil;
        gPXInsideIOSReportingHook = NO;
    }
}

%end

#pragma mark - WKWebView User Agent Hooks

%hook WKWebView

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    PX_RUNTIME_READ_OPERATION;
    NSString *nativeBaseUserAgent = nil;
    WKWebView *webView = nil;
    BOOL previous = gPXPreparingUA;
    @try {
        @try {
            if ([NSThread isMainThread] && !previous) {
                gPXPreparingUA = YES;
                nativeBaseUserAgent = PXUANativeBaseUserAgent(configuration);
            }
        } @catch (__unused NSException *exception) {
        } @finally { gPXPreparingUA = previous; }
        // The constructor is never inside a projection catch or retried.
        webView = %orig(frame, configuration);
        if (!webView) return nil;
        @try {
            // The registry handles weak background registration without touching view properties.
            PXUASyncRegisterWKWebView(webView);
            if ([NSThread isMainThread] && !previous) {
                objc_setAssociatedObject(webView, kPXUABaseUserAgentKey,
                    nativeBaseUserAgent ?: (id)[NSNull null], OBJC_ASSOCIATION_COPY_NONATOMIC);
                objc_setAssociatedObject(webView, kPXUAOwnsCustomUserAgentKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                PXUAEnsureCanonicalUserAgent(webView, configuration, nil, @"WKWebView.init");
            }
        } @catch (__unused NSException *exception) { }
        return webView;
    } @finally { gPXPreparingUA = previous; nativeBaseUserAgent = nil; webView = nil; configuration = nil; }
}

- (WKNavigation *)loadRequest:(NSURLRequest *)request {
    __attribute__((objc_precise_lifetime)) id receiver = self;
    PX_RUNTIME_READ_OPERATION;
    WKWebViewConfiguration *configuration = nil;
    NSURL *destination = nil;
    NSString *host = nil;
    @try {
        @try {
            if ([NSThread isMainThread] && !gPXPreparingUA) {
                configuration = self.configuration;
                destination = request.URL; host = destination.host;
                PXUAEnsureCanonicalUserAgent(self, configuration, host, @"WKWebView.loadRequest");
            }
        } @catch (__unused NSException *exception) { }
        return %orig(request);
    } @finally { receiver = nil; configuration = nil; destination = nil; host = nil; request = nil; }
}

- (WKNavigation *)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL {
    __attribute__((objc_precise_lifetime)) id receiver = self;
    PX_RUNTIME_READ_OPERATION;
    WKWebViewConfiguration *configuration = nil;
    NSURL *destination = nil;
    NSString *host = nil;
    @try {
        @try {
            if ([NSThread isMainThread] && !gPXPreparingUA) {
                configuration = self.configuration;
                destination = baseURL; host = destination.host;
                PXUAEnsureCanonicalUserAgent(self, configuration, host, @"WKWebView.loadHTMLString");
            }
        } @catch (__unused NSException *exception) { }
        return %orig(string, baseURL);
    } @finally { receiver = nil; configuration = nil; destination = nil; host = nil; string = nil; baseURL = nil; }
}

- (WKNavigation *)loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL {
    __attribute__((objc_precise_lifetime)) id receiver = self;
    PX_RUNTIME_READ_OPERATION;
    WKWebViewConfiguration *configuration = nil;
    NSURL *destination = nil;
    NSString *host = nil;
    @try {
        @try {
            if ([NSThread isMainThread] && !gPXPreparingUA) {
                configuration = self.configuration;
                destination = URL; host = destination.host;
                PXUAEnsureCanonicalUserAgent(self, configuration, host, @"WKWebView.loadFileURL");
            }
        } @catch (__unused NSException *exception) { }
        return %orig(URL, readAccessURL);
    } @finally { receiver = nil; configuration = nil; destination = nil; host = nil; URL = nil; readAccessURL = nil; }
}

- (WKNavigation *)loadData:(NSData *)data
                  MIMEType:(NSString *)MIMEType
     characterEncodingName:(NSString *)characterEncodingName
                   baseURL:(NSURL *)baseURL {
    __attribute__((objc_precise_lifetime)) id receiver = self;
    PX_RUNTIME_READ_OPERATION;
    WKWebViewConfiguration *configuration = nil;
    NSURL *destination = nil;
    NSString *host = nil;
    @try {
        @try {
            if ([NSThread isMainThread] && !gPXPreparingUA) {
                configuration = self.configuration;
                destination = baseURL; host = destination.host;
                PXUAEnsureCanonicalUserAgent(self, configuration, host, @"WKWebView.loadData");
            }
        } @catch (__unused NSException *exception) { }
        return %orig(data, MIMEType, characterEncodingName, baseURL);
    } @finally { receiver = nil; configuration = nil; destination = nil; host = nil; data = nil; MIMEType = nil; characterEncodingName = nil; baseURL = nil; }
}

- (void)setCustomUserAgent:(NSString *)customUserAgent {
    __attribute__((objc_precise_lifetime)) id receiver = self;
    PX_RUNTIME_READ_OPERATION;
    NSString *bundleID = nil, *processName = nil, *host = nil, *candidate = nil, *requestedBase = nil;
    NSURL *url = nil;
    WKWebViewConfiguration *configuration = nil;
    NSObject *intent = nil;
    id currentIntent = nil;
    BOOL previous = gPXPreparingUA, recordBase = NO;
    @try {
        @try {
            if ([NSThread isMainThread] && !previous && !gUASyncApplying && !gUACanonicalApplying &&
                (!customUserAgent || [customUserAgent isKindOfClass:NSString.class])) {
                gPXPreparingUA = YES;
                requestedBase = [customUserAgent copy];
                intent = [NSObject new];
                objc_setAssociatedObject(self, kPXUASetterIntentKey, intent, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                recordBase = YES;
                bundleID = [[NSBundle mainBundle] bundleIdentifier]; processName = [NSProcessInfo processInfo].processName;
                url = self.URL; host = url.host;
                PXUADebugSettings debug = PXUACurrentPolicy().debug;
                if (debug.masterEnabled && !PXUADebugScopeAllowsWithSettings(bundleID, processName, debug)) {
                    PXUADebugTrace(@"WKWebView.setCustomUserAgent", bundleID, processName, host, @"skip", @"reason=scope", customUserAgent, nil);
                } else if (debug.masterEnabled && !debug.hook_setCustomUserAgent) {
                    PXUADebugTrace(@"WKWebView.setCustomUserAgent", bundleID, processName, host, @"skip", @"reason=toggle", customUserAgent, nil);
                } else if (customUserAgent.length && PXUAShouldApplyForHost(bundleID, processName, host)) {
                    configuration = self.configuration;
                    candidate = PXUAModifiedUserAgent(customUserAgent, configuration);
                    if (!candidate.length || [candidate isEqualToString:customUserAgent]) candidate = nil;
                    if (candidate) PXUADebugTrace(@"WKWebView.setCustomUserAgent", bundleID, processName, host, @"modify", @"", customUserAgent, candidate);
                }
            }
        } @catch (__unused NSException *exception) { candidate = nil; }
        @finally { gPXPreparingUA = previous; }
        %orig(candidate ?: customUserAgent);
        // Record ownership only after the native setter acknowledges success.
        @try {
            if (recordBase) currentIntent = objc_getAssociatedObject(self, kPXUASetterIntentKey);
            if (recordBase && currentIntent == intent) {
                // A reentrant native setter may already have accepted a newer caller intent.
                objc_setAssociatedObject(self, kPXUABaseUserAgentKey, requestedBase ?: (id)[NSNull null], OBJC_ASSOCIATION_COPY_NONATOMIC);
                objc_setAssociatedObject(self, kPXUAOwnsCustomUserAgentKey, @(candidate != nil), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        } @catch (__unused NSException *exception) { }
    } @finally { receiver = nil;
        gPXPreparingUA = previous; customUserAgent = nil; bundleID = nil; processName = nil; host = nil;
        candidate = nil; requestedBase = nil; url = nil; configuration = nil; intent = nil; currentIntent = nil;
    }
}


%end

#pragma mark - WKWebViewConfiguration Hooks

%hook WKWebViewConfiguration

- (void)setApplicationNameForUserAgent:(NSString *)applicationNameForUserAgent {
    __attribute__((objc_precise_lifetime)) id receiver = self;
    PX_RUNTIME_READ_OPERATION;
    NSString *bundleID = nil, *processName = nil, *version = nil;
    NSString *candidate = nil;
    BOOL previous = gPXPreparingUA;
    @try {
        @try {
            if (!previous && [applicationNameForUserAgent isKindOfClass:NSString.class]) {
                gPXPreparingUA = YES;
                bundleID = [[NSBundle mainBundle] bundleIdentifier]; processName = [NSProcessInfo processInfo].processName;
                PXUADebugSettings debug = PXUACurrentPolicy().debug;
                if (debug.masterEnabled && !PXUADebugScopeAllowsWithSettings(bundleID, processName, debug)) {
                    PXUADebugTrace(@"WKWebViewConfiguration.setApplicationNameForUserAgent", bundleID, processName, nil, @"skip", @"reason=scope", applicationNameForUserAgent, nil);
                } else if (debug.masterEnabled && !debug.hook_appNameUA) {
                    PXUADebugTrace(@"WKWebViewConfiguration.setApplicationNameForUserAgent", bundleID, processName, nil, @"skip", @"reason=toggle", applicationNameForUserAgent, nil);
                } else {
                    BOOL safariStack = PXProcessIsAllowedForSpoofing(bundleID, processName, PXScopeOptionAllowSafariAuthStack) && PXIsSafariStackProcess(bundleID, processName);
                    if (safariStack && !PXFullSpoofTestModeEnabled()) {
                        PXUADebugTrace(@"WKWebViewConfiguration.setApplicationNameForUserAgent", bundleID, processName, nil, @"skip", @"reason=safaristack", applicationNameForUserAgent, nil);
                    } else if (shouldSpoofForBundle(bundleID)) {
                        version = getSpoofedSystemVersion();
                        if (version) {
                            candidate = [applicationNameForUserAgent mutableCopy]; modifyUserAgentString(&candidate, @"native", version);
                            if ([candidate isEqualToString:applicationNameForUserAgent]) candidate = nil;
                            if (candidate) PXUADebugTrace(@"WKWebViewConfiguration.setApplicationNameForUserAgent", bundleID, processName, nil, @"modify", @"", applicationNameForUserAgent, candidate);
                        }
                    }
                }
            }
        } @catch (__unused NSException *exception) { candidate = nil; }
        @finally { gPXPreparingUA = previous; }
        %orig(candidate ?: applicationNameForUserAgent);
    } @finally { receiver = nil; gPXPreparingUA = previous; applicationNameForUserAgent = nil; bundleID = nil; processName = nil; version = nil; candidate = nil; }
}

%end

#pragma mark - NSURLRequest User-Agent Hooks

%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    __attribute__((objc_precise_lifetime)) id receiver = self;
    NSString *candidate = nil, *host = nil, *modifiedValue = nil;
    uint64_t syncEpoch = 0;
    @try {
        PXUAHeaderKind kind = PXUAHeaderOther;
        @try { if (!gPXPreparingUA && [value isKindOfClass:NSString.class]) kind = PXUAClassifyHeader(field); }
        @catch (__unused NSException *exception) { }
        if (kind == PXUAHeaderOther) { %orig(value, field); return; }
        PX_RUNTIME_READ_OPERATION;
        @try { candidate = PXUAPrepareRequestHeader(self, value, field, kind, &host, &modifiedValue, &syncEpoch); }
        @catch (__unused NSException *exception) { candidate = nil; host = nil; modifiedValue = nil; }
        // Original exceptions propagate; no retry and no JS side effect for a rejected header.
        %orig(candidate ?: value, field);
        @try {
            if (host && modifiedValue) PXUASyncApplyToWebViewsForHost(host, modifiedValue, syncEpoch);
        } @catch (__unused NSException *exception) { }
    } @finally { receiver = nil; value = nil; field = nil; candidate = nil; host = nil; modifiedValue = nil; }
}

%end

#pragma mark - Safari Specific Hooks

// Hook Safari's SFUserAgentController to modify the user agent string
%hook SFUserAgentController

+ (NSString *)userAgentWithDomain:(NSString *)domain {
    PX_RUNTIME_READ_OPERATION;
    NSString *originalUA = nil, *bundleID = nil, *processName = nil, *version = nil;
    NSString *candidate = nil;
    BOOL previous = gPXPreparingUA;
    @try {
        originalUA = %orig(domain);
        if (previous) return originalUA;
        @try {
            gPXPreparingUA = YES;
            bundleID = [[NSBundle mainBundle] bundleIdentifier]; processName = [NSProcessInfo processInfo].processName;
            PXUADebugSettings debug = PXUACurrentPolicy().debug;
            if (debug.masterEnabled && !PXUADebugScopeAllowsWithSettings(bundleID, processName, debug)) {
                PXUADebugTrace(@"SFUserAgentController.userAgentWithDomain", bundleID, processName, domain, @"skip", @"reason=scope", originalUA, nil); return originalUA;
            }
            if (debug.masterEnabled && !debug.hook_sfUserAgentWithDomain) {
                PXUADebugTrace(@"SFUserAgentController.userAgentWithDomain", bundleID, processName, domain, @"skip", @"reason=toggle", originalUA, nil); return originalUA;
            }
            if (PXIsSafariBrowserBundleIdentifier(bundleID)) {
                if (PXUAHostIsSensitive(domain)) {
                    PXUADebugTrace(@"SFUserAgentController.userAgentWithDomain", bundleID, processName, domain, @"skip", @"reason=sensitive", originalUA, nil); return originalUA;
                }
                version = getSpoofedSystemVersion();
                if (version && [originalUA isKindOfClass:NSString.class]) {
                    candidate = [originalUA mutableCopy]; modifyUserAgentString(&candidate, @"native", version);
                    if (![candidate isEqualToString:originalUA]) {
                        PXUADebugTrace(@"SFUserAgentController.userAgentWithDomain", bundleID, processName, domain, @"modify", @"", originalUA, candidate);
                        IOSVERSION_LOG(@"Safari: Modified user agent for domain %@", domain);
                        return candidate;
                    }
                }
            }
        } @catch (__unused NSException *exception) { }
        return originalUA;
    } @finally { gPXPreparingUA = previous; originalUA = nil; bundleID = nil; processName = nil; version = nil; candidate = nil; domain = nil; }
}

+ (NSString *)defaultUserAgentString {
    PX_RUNTIME_READ_OPERATION;
    NSString *originalUA = nil, *bundleID = nil, *processName = nil, *version = nil;
    NSString *candidate = nil;
    BOOL previous = gPXPreparingUA;
    @try {
        originalUA = %orig;
        if (previous) return originalUA;
        @try {
            gPXPreparingUA = YES;
            bundleID = [[NSBundle mainBundle] bundleIdentifier]; processName = [NSProcessInfo processInfo].processName;
            PXUADebugSettings debug = PXUACurrentPolicy().debug;
            if (debug.masterEnabled && !PXUADebugScopeAllowsWithSettings(bundleID, processName, debug)) {
                PXUADebugTrace(@"SFUserAgentController.defaultUserAgentString", bundleID, processName, nil, @"skip", @"reason=scope", originalUA, nil); return originalUA;
            }
            if (debug.masterEnabled && !debug.hook_sfDefaultUA) {
                PXUADebugTrace(@"SFUserAgentController.defaultUserAgentString", bundleID, processName, nil, @"skip", @"reason=toggle", originalUA, nil); return originalUA;
            }
            if (PXIsSafariBrowserBundleIdentifier(bundleID)) {
                if (PXProcessIsAllowedForSpoofing(bundleID, processName, PXScopeOptionAllowSafariAuthStack) && !PXFullSpoofTestModeEnabled()) {
                    PXUADebugTrace(@"SFUserAgentController.defaultUserAgentString", bundleID, processName, nil, @"skip", @"reason=safaristack", originalUA, nil); return originalUA;
                }
                version = getSpoofedSystemVersion();
                if (version && [originalUA isKindOfClass:NSString.class]) {
                    candidate = [originalUA mutableCopy]; modifyUserAgentString(&candidate, @"native", version);
                    if (![candidate isEqualToString:originalUA]) {
                        PXUADebugTrace(@"SFUserAgentController.defaultUserAgentString", bundleID, processName, nil, @"modify", @"", originalUA, candidate);
                        IOSVERSION_LOG(@"Safari: Modified default user agent");
                        return candidate;
                    }
                }
            }
        } @catch (__unused NSException *exception) { }
        return originalUA;
    } @finally { gPXPreparingUA = previous; originalUA = nil; bundleID = nil; processName = nil; version = nil; candidate = nil;  }
}

%end

#pragma mark - CoreFoundation Version Dictionary Hook

// Hook CFCopySystemVersionDictionary through the IOS-06 unified transformer.
static CFDictionaryRef (*original_CFCopySystemVersionDictionary)(void);
CFDictionaryRef replaced_CFCopySystemVersionDictionary(void) {
    PX_RUNTIME_READ_OPERATION;
    CFDictionaryRef original = original_CFCopySystemVersionDictionary ? original_CFCopySystemVersionDictionary() : NULL;
    @autoreleasepool {
        @try {
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            IdentifierManager *manager = [IdentifierManager sharedManager];
            if (!shouldSpoofForBundle(bundleID) || ![manager isIdentifierEnabled:@"IOSVersion"]) return original;

            PXSystemVersionProjection *projection = PXCurrentReportingSystemVersionProjectionForBundle(bundleID);
            if (!projection) return original;
            NSDictionary *base = original ? (__bridge NSDictionary *)original : @{};
            NSDictionary *transformed = PXTransformSystemVersionDictionary(base, projection);
            if (transformed == base) return original;

            CFDictionaryRef result = CFBridgingRetain(transformed);
            if (original) CFRelease(original);
            return result;
        } @catch (NSException *exception) {
            IOSVERSION_LOG(@"Error in unified SystemVersion transformer: %@", exception);
            return original;
        }
    }
}

#pragma mark - sysctlbyname Hook

// Hook sysctlbyname to spoof iOS kernel version information
int hooked_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    PX_RUNTIME_READ_OPERATION;
    static int loggedCount = 0;
    if (name && loggedCount < 30) {
        loggedCount++;
        PXFileDebugAIDA64Log("[IOSVersion.sysctlbyname] key=%s oldp=%d oldlenp=%d", name, oldp ? 1 : 0, oldlenp ? 1 : 0);
    }
    // Store last call time and cached result for the common kernel version calls
    static uint64_t lastOsVersionCallTime = 0;
    static char cachedBuildStr[32] = {0}; // Cache the build string
    static size_t cachedBuildStrLen = 0;
    
    // For kern.version - full Darwin kernel version string
    static uint64_t lastKernVersionCallTime = 0;
    static char cachedKernelVersionStr[256] = {0}; // Cache the kernel version string
    static size_t cachedKernelVersionStrLen = 0;
    
    @try {
        // Pre-cache version info only once
        static NSDictionary *cachedVersionInfo = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
    PX_RUNTIME_READ_OPERATION;
            cachedVersionInfo = getIOSVersionInfo();
            if (cachedVersionInfo) {
                // Extract build number and cache it
                NSString *buildNumber = cachedVersionInfo[@"build"];
                if (buildNumber) {
                    strlcpy(cachedBuildStr, [buildNumber UTF8String], sizeof(cachedBuildStr));
                    cachedBuildStrLen = strlen(cachedBuildStr) + 1; // +1 for null terminator
                }
                
                // Extract kernel version string and cache it
                NSString *kernelVersion = cachedVersionInfo[@"kernel_version"];
                if (kernelVersion) {
                    strlcpy(cachedKernelVersionStr, [kernelVersion UTF8String], sizeof(cachedKernelVersionStr));
                    cachedKernelVersionStrLen = strlen(cachedKernelVersionStr) + 1; // +1 for null terminator
                }
                
                IOSVERSION_LOG(@"🔄 Pre-cached version info: %@ (%@), kernel: %@", 
                      cachedVersionInfo[@"version"], 
                      cachedVersionInfo[@"build"],
                      cachedVersionInfo[@"kernel_version"]);
            } else {
                IOSVERSION_LOG(@"⚠️ Failed to pre-cache version info");
            }
        });

        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (shouldSpoofForBundle(bundleID)) {
            // Check if this is a request for full kernel version string
            if (name && strcmp(name, "kern.version") == 0) {
                uint64_t currentTime = mach_absolute_time();
                
                // Ensure we have a valid cached kernel version string
                if (cachedKernelVersionStrLen == 0 && cachedVersionInfo && cachedVersionInfo[@"kernel_version"]) {
                    NSString *kernelVersion = cachedVersionInfo[@"kernel_version"];
                    strlcpy(cachedKernelVersionStr, [kernelVersion UTF8String], sizeof(cachedKernelVersionStr));
                    cachedKernelVersionStrLen = strlen(cachedKernelVersionStr) + 1;
                }
                
                // If we have a valid cached kernel version string
                if (cachedKernelVersionStrLen > 0) {
                    // Check if this is just a length query (oldp is NULL but oldlenp is not)
                    if (!oldp && oldlenp) {
                        *oldlenp = cachedKernelVersionStrLen;
                        
                        // Only log occasionally
                        if (lastKernVersionCallTime == 0 || (currentTime - lastKernVersionCallTime) > THROTTLE_INTERVAL_NSEC * 10) {
                            IOSVERSION_LOG(@"ℹ️ Returning required buffer size for kern.version: %zu", cachedKernelVersionStrLen);
                        }
                        
                        lastKernVersionCallTime = currentTime;
                        return 0;
                    }
                    
                    // Make sure we have enough space in the buffer and that both oldp and oldlenp are valid
                    if (oldp && oldlenp && *oldlenp >= cachedKernelVersionStrLen) {
                        memcpy(oldp, cachedKernelVersionStr, cachedKernelVersionStrLen);
                        *oldlenp = cachedKernelVersionStrLen;
                        
                        // Only log occasionally
                        if (lastKernVersionCallTime == 0 || (currentTime - lastKernVersionCallTime) > THROTTLE_INTERVAL_NSEC * 10) {
                            IOSVERSION_LOG(@"✅ Successfully spoofed kern.version to %s", cachedKernelVersionStr);
                        }
                        
                        lastKernVersionCallTime = currentTime;
                        return 0; // Success
                    } else if (oldlenp) {
                        // Not enough space, just set the required length
                        *oldlenp = cachedKernelVersionStrLen;
                        
                        // Only log occasionally
                        if (lastKernVersionCallTime == 0 || (currentTime - lastKernVersionCallTime) > THROTTLE_INTERVAL_NSEC * 10) {
                            IOSVERSION_LOG(@"⚠️ Buffer too small for kern.version (%zu < %zu)", *oldlenp, cachedKernelVersionStrLen);
                        }
                        
                        lastKernVersionCallTime = currentTime;
                        return 0; // Success (caller will need to provide a bigger buffer)
                    }
                } else {
                    IOSVERSION_LOG(@"❌ Missing cached kernel version string");
                }
            }
            // Check if this is a request for Darwin version number (kern.osrelease)
            else if (name && strcmp(name, "kern.osrelease") == 0 && cachedVersionInfo && cachedVersionInfo[@"darwin"]) {
                uint64_t currentTime = mach_absolute_time();
                
                // Get Darwin version (format: "21.6.0")
                NSString *darwinVersion = cachedVersionInfo[@"darwin"];
                if (darwinVersion) {
                    const char *darwinVersionStr = [darwinVersion UTF8String];
                    size_t darwinVersionLen = strlen(darwinVersionStr) + 1; // +1 for null terminator
                    
                    // Check if this is just a length query
                    if (!oldp && oldlenp) {
                        *oldlenp = darwinVersionLen;
                        return 0;
                    }
                    
                    // Copy the version if buffer is big enough
                    if (oldp && oldlenp && *oldlenp >= darwinVersionLen) {
                        memcpy(oldp, darwinVersionStr, darwinVersionLen);
                        *oldlenp = darwinVersionLen;
                        
                        // Only log occasionally
                        if (lastOsVersionCallTime == 0 || (currentTime - lastOsVersionCallTime) > THROTTLE_INTERVAL_NSEC * 10) {
                            IOSVERSION_LOG(@"✅ Successfully spoofed kern.osrelease to %s", darwinVersionStr);
                        }
                        
                        lastOsVersionCallTime = currentTime;
                        return 0; // Success
                    } else if (oldlenp) {
                        // Not enough space, just set the required length
                        *oldlenp = darwinVersionLen;
                        return 0;
                    }
                }
            }
            // Check if this is a request for iOS version information
            else if (name && (strcmp(name, "kern.osversion") == 0)) {
                // Rate limiting - don't process too many calls
                uint64_t currentTime = mach_absolute_time();
                
                // Ensure we have a valid cached build string
                if (cachedBuildStrLen == 0 && cachedVersionInfo && cachedVersionInfo[@"build"]) {
                    NSString *buildNumber = cachedVersionInfo[@"build"];
                    strlcpy(cachedBuildStr, [buildNumber UTF8String], sizeof(cachedBuildStr));
                    cachedBuildStrLen = strlen(cachedBuildStr) + 1;
                }
                
                // Skip processing if we have a valid cached build and not enough time has passed
                if (cachedBuildStrLen > 0) {
                    // Check if this is just a length query (oldp is NULL but oldlenp is not)
                    if (!oldp && oldlenp) {
                        *oldlenp = cachedBuildStrLen;
                        
                        // Only log occasionally
                        if (lastOsVersionCallTime == 0 || (currentTime - lastOsVersionCallTime) > THROTTLE_INTERVAL_NSEC * 10) {
                            IOSVERSION_LOG(@"ℹ️ Returning required buffer size: %zu", cachedBuildStrLen);
                        }
                        
                        lastOsVersionCallTime = currentTime;
                        return 0;
                    }
                    
                    // Make sure we have enough space in the buffer and that both oldp and oldlenp are valid
                    if (oldp && oldlenp && *oldlenp >= cachedBuildStrLen) {
                        memcpy(oldp, cachedBuildStr, cachedBuildStrLen);
                        *oldlenp = cachedBuildStrLen;
                        
                        // Only log occasionally
                        if (lastOsVersionCallTime == 0 || (currentTime - lastOsVersionCallTime) > THROTTLE_INTERVAL_NSEC * 10) {
                            IOSVERSION_LOG(@"✅ Successfully spoofed sysctlbyname to %s", cachedBuildStr);
                        }
                        
                        lastOsVersionCallTime = currentTime;
                        return 0; // Success
                    } else if (oldlenp) {
                        // Not enough space, just set the required length
                        *oldlenp = cachedBuildStrLen;
                        
                        // Only log occasionally
                        if (lastOsVersionCallTime == 0 || (currentTime - lastOsVersionCallTime) > THROTTLE_INTERVAL_NSEC * 10) {
                            IOSVERSION_LOG(@"⚠️ Buffer too small for sysctlbyname (%zu < %zu)", *oldlenp, cachedBuildStrLen);
                        }
                        
                        lastOsVersionCallTime = currentTime;
                        return 0; // Success (caller will need to provide a bigger buffer)
                    }
                } else {
                    IOSVERSION_LOG(@"❌ Missing cached build number");
                }
            }
        }
    } @catch (NSException *e) {
        IOSVERSION_LOG(@"❌ Error in sysctlbyname hook: %@", e);
    }
    
    // Call the original function for all other cases
    return original_sysctlbyname(name, oldp, oldlenp, newp, newlen);
}

#pragma mark - Bundle Version Hooks

%hook NSBundle

- (id)objectForInfoDictionaryKey:(NSString *)key {
    PX_RUNTIME_READ_OPERATION;
    // Never resolve bundleIdentifier from an Info.plist hook: Foundation may implement
    // bundleIdentifier through infoDictionary/objectForInfoDictionaryKey and recurse.
    if (gPXInsideIOSVersionBundleInfoHook || self != [NSBundle mainBundle]) {
        return %orig;
    }

    gPXInsideIOSVersionBundleInfoHook = YES;
    id projectedValue = nil;
    BOOL hasProjectedValue = NO;
    @try {
        NSString *mainBundleID = gPXIOSVersionMainBundleID;
        if (mainBundleID.length && shouldSpoofForBundle(mainBundleID)) {
            // App-specific version/build spoofing is only valid for the main bundle.
            if ([key isEqualToString:@"CFBundleShortVersionString"] || [key isEqualToString:@"CFBundleVersion"]) {
                NSString *spoofVer = nil;
                NSString *spoofBuild = nil;
                if (PXGetSpoofedAppVersionForBundle(mainBundleID, &spoofVer, &spoofBuild)) {
                    if ([key isEqualToString:@"CFBundleShortVersionString"] && spoofVer.length) {
                        projectedValue = spoofVer;
                        hasProjectedValue = YES;
                    } else if ([key isEqualToString:@"CFBundleVersion"] && spoofBuild.length) {
                        projectedValue = spoofBuild;
                        hasProjectedValue = YES;
                    }
                }
            }
            // MinimumOSVersion / DTPlatformVersion / DTSDKName intentionally fall
            // through to %orig; they describe the app binary rather than runtime identity.
        }
    } @catch (__unused NSException *e) {
        hasProjectedValue = NO;
        projectedValue = nil;
    } @finally {
        gPXInsideIOSVersionBundleInfoHook = NO;
    }

    if (hasProjectedValue) return projectedValue;
    return %orig;
}

%end

// Original function pointer for CFBundleGetValueForInfoDictionaryKey
static CFTypeRef (*original_CFBundleGetValueForInfoDictionaryKey)(CFBundleRef bundle, CFStringRef key);

// CFBundleGetValueForInfoDictionaryKey is a "Get" API: the caller does NOT own
// the returned reference and must not CFRelease it. Returning a freshly
// CFStringCreate...'d object here leaked on every call (P1 CF lifetime). Vend
// process-lifetime CFStrings from a retained cache instead, so the borrowed
// pointer stays valid for the life of the process with no per-call allocation.
static CFStringRef PXIOSVersionBorrowedInfoString(NSString *value) {
    if (![value isKindOfClass:[NSString class]] || value.length == 0) return NULL;
    static NSMutableDictionary<NSString *, NSString *> *cache = nil;
    static os_unfair_lock cacheLock = OS_UNFAIR_LOCK_INIT;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMutableDictionary dictionary];
    });
    os_unfair_lock_lock(&cacheLock);
    NSString *stored = cache[value];
    if (!stored) {
        stored = [value copy];
        cache[value] = stored;
    }
    os_unfair_lock_unlock(&cacheLock);
    return (__bridge CFStringRef)stored;
}

// Replacement function for CFBundleGetValueForInfoDictionaryKey
CFTypeRef replaced_CFBundleGetValueForInfoDictionaryKey(CFBundleRef bundle, CFStringRef key) {
    PX_RUNTIME_READ_OPERATION;
    if (!bundle || !key) return NULL;
    if (gPXInsideIOSVersionCFBundleInfoHook) {
        return original_CFBundleGetValueForInfoDictionaryKey
            ? original_CFBundleGetValueForInfoDictionaryKey(bundle, key)
            : NULL;
    }

    gPXInsideIOSVersionCFBundleInfoHook = YES;
    @try {
        // App-version projection is only defined for the process main bundle.
        // Never call CFBundleGetIdentifier here: it may refresh through infoDictionary.
        if (bundle != CFBundleGetMainBundle()) {
            gPXInsideIOSVersionCFBundleInfoHook = NO;
            return original_CFBundleGetValueForInfoDictionaryKey
                ? original_CFBundleGetValueForInfoDictionaryKey(bundle, key)
                : NULL;
        }
        NSString *nsBundleID = gPXIOSVersionMainBundleID;
        
        if (shouldSpoofForBundle(nsBundleID)) {
            // App-specific version/build spoofing (only for main bundle)
            if (CFEqual(key, CFSTR("CFBundleShortVersionString")) || CFEqual(key, CFSTR("CFBundleVersion"))) {
                NSString *mainBundleID = getCurrentBundleID();
                if (mainBundleID.length && [nsBundleID isEqualToString:mainBundleID]) {
                    NSString *spoofVer = nil;
                    NSString *spoofBuild = nil;
                    if (PXGetSpoofedAppVersionForBundle(mainBundleID, &spoofVer, &spoofBuild)) {
                        if (CFEqual(key, CFSTR("CFBundleShortVersionString")) && spoofVer.length) {
                            CFTypeRef value = PXIOSVersionBorrowedInfoString(spoofVer);
                            gPXInsideIOSVersionCFBundleInfoHook = NO;
                            return value;
                        }
                        if (CFEqual(key, CFSTR("CFBundleVersion")) && spoofBuild.length) {
                            CFTypeRef value = PXIOSVersionBorrowedInfoString(spoofBuild);
                            gPXInsideIOSVersionCFBundleInfoHook = NO;
                            return value;
                        }
                    }
                }
            }

            // App build metadata is not a device identity surface. Preserve the
            // binary's real deployment/SDK contract so legacy runtimes do not enter
            // newer-framework paths based on spoofed profile data.
            if (CFEqual(key, CFSTR("MinimumOSVersion")) ||
                CFEqual(key, CFSTR("DTPlatformVersion")) ||
                CFEqual(key, CFSTR("DTSDKName"))) {
                gPXInsideIOSVersionCFBundleInfoHook = NO;
                return original_CFBundleGetValueForInfoDictionaryKey
                    ? original_CFBundleGetValueForInfoDictionaryKey(bundle, key)
                    : NULL;
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[iosversion] ❌ Error in CFBundleGetValueForInfoDictionaryKey hook: %@", e);
    }

    gPXInsideIOSVersionCFBundleInfoHook = NO;

    // Call original function if available, otherwise return NULL
    if (original_CFBundleGetValueForInfoDictionaryKey) {
        return original_CFBundleGetValueForInfoDictionaryKey(bundle, key);
    } else {
        // For some keys, provide default values
        if (key && (CFEqual(key, CFSTR("MinimumOSVersion")))) {
            // Fallback only when the original symbol is unavailable. Use the
            // low-level physical runtime reader, never the hooked UIDevice surface.
            NSString *actualVersion = PXRealRuntimeIOSVersion();
            return actualVersion.length ? PXIOSVersionBorrowedInfoString(actualVersion) : NULL;
        }
        
        NSLog(@"[iosversion] ℹ️ No original function for CFBundleGetValueForInfoDictionaryKey, returning NULL");
        return NULL;
    }
}

#pragma mark - Notification Handling

// Settings changed notification handler
static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    PXInvalidateScopeDecisionCache();
    PXIOSVersionInvalidateCache();

    // Revoke queued UA jobs as well as scalar policy cache publication.
    PXUAPolicyInvalidate();
    PXAppVersionHooksInvalidateCache();
}

// Safe check if a bundle ID is a critical system process
static BOOL isCriticalSystemProcess(NSString *bundleID) {
    PX_RUNTIME_READ_OPERATION;
    if (!bundleID) return YES; // Treat nil as critical for safety

    NSString *proc = [NSProcessInfo processInfo].processName;
    if (PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
        return NO;
    }
    
    // Check against our critical system bundle IDs list
    if ([criticalSystemBundleIDs() containsObject:bundleID]) {
        // Allow spoofing for Safari and WebKit processes, even though they're in the critical list
        // This is necessary to spoof browser user agents
        if (PXIsSafariStackProcess(bundleID, proc)) {
            return NO;
        }
        return YES;
    }
    
    // Check for system app prefixes
    if ([bundleID hasPrefix:@"com.apple."]) {
        // Allow spoofing for Safari and WebKit processes
        if (PXIsSafariStackProcess(bundleID, proc)) {
            return NO;
        }
        return YES;
    }
    
    // Check for other known system bundle ID patterns
    if ([bundleID hasPrefix:@"com.hydra.tlinkios"] ||
        [bundleID isEqualToString:@"com.saurik.Cydia"] ||
        [bundleID isEqualToString:@"org.coolstar.SileoStore"] ||
        [bundleID isEqualToString:@"xyz.willy.Zebra"]) {
        return YES;
    }
    
    return NO;
}

#pragma mark - Constructor

// Cleanup function to be called on process termination.
%dtor {
    PXIOSVersionInvalidateCache();
}

%ctor {
    @autoreleasepool {
        if (!PXBootstrapAllows(PXHookCapabilityWebContent | PXHookCapabilityWebNetworking)) return;
        PXFileDebugSignalHookDiagnostic(PXHookDiagnosticStageIOSVersionProfile,
                                        PXHookDiagnosticResultCheckpoint);
        PXFileDebugAIDA64Log("[IOSVersion.ctor] enter");
        // Capture the main bundle identity before this file installs any NSBundle hooks.
        // Hook bodies below must use this immutable value rather than re-entering
        // -bundleIdentifier through Foundation's Info.plist accessors.
        gPXIOSVersionMainBundleID = [[[NSBundle mainBundle] bundleIdentifier] copy];
        NSString *bundleID = gPXIOSVersionMainBundleID;
        
        // Skip for system processes to avoid potential issues
        if (isCriticalSystemProcess(bundleID)) {
            PXFileDebugSignalHookDiagnostic(PXHookDiagnosticStageIOSVersionProfile,
                                            PXHookDiagnosticResultSkipped);
            return;
        }
        
        IOSVERSION_LOG(@"Initializing iOS Version Hooks for %@...", bundleID);
        
        NSString *proc = [NSProcessInfo processInfo].processName;
        BOOL allowed = PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack);
        PXFileDebugAIDA64Log("[IOSVersion.ctor] scope allowed=%d bundle=%s", allowed, bundleID.UTF8String ?: "<nil>");
        if (!allowed) {
            PXFileDebugSignalHookDiagnostic(PXHookDiagnosticStageIOSVersionProfile,
                                            PXHookDiagnosticResultScopeDenied);
            // App is NOT scoped - no hooks, no interference, no crashes
            IOSVERSION_LOG(@"App %@ is not scoped, skipping iOS version hook installation", bundleID);
            return;
        }

        IdentifierManager *diagnosticManager = [IdentifierManager sharedManager];
        BOOL diagnosticEnabled = [diagnosticManager isIdentifierEnabled:@"IOSVersion"];
        NSDictionary *diagnosticVersionInfo = diagnosticEnabled ? getIOSVersionInfo() : nil;
        PXFileDebugSignalHookDiagnostic(PXHookDiagnosticStageIOSVersionProfile,
            !diagnosticEnabled ? PXHookDiagnosticResultDisabled :
            ([diagnosticVersionInfo[@"version"] isKindOfClass:NSString.class] &&
             [diagnosticVersionInfo[@"version"] length] ? PXHookDiagnosticResultSuccess :
             PXHookDiagnosticResultMissingData));
        
        IOSVERSION_LOG(@"App %@ is scoped, installing iOS version hooks", bundleID);
        
        PXIOSVersionInvalidateCache();
        
        // Register for settings change notifications
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            settingsChanged,
            CFSTR("com.hydra.tlinkios.settings.changed"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
        
        // Register for iOS version-specific toggle notifications
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            settingsChanged,
            CFSTR("com.hydra.tlinkios.toggleIOSVersionSpoof"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
        
        // Register for profile and scoped-app changes.
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            settingsChanged,
            CFSTR("com.hydra.tlinkios.profileChanged"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            settingsChanged,
            CFSTR("com.hydra.tlinkios.scopedAppsChanged"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
        
        // Force ElleKit hooks to be applied regardless of environment detection
        // This is needed for rootless jailbreaks where 0 might fail
        IOSVERSION_LOG(@"Setting up ElleKit hooks for build number spoofing");
        
        // Hook CoreFoundation version dictionary function
        PXFileDebugAIDA64Log("[IOSVersion.ctor] before dlopen CoreFoundation");
        void *cfFramework = dlopen("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", RTLD_NOW);
        PXFileDebugAIDA64Log("[IOSVersion.ctor] after dlopen CoreFoundation handle=%d", cfFramework ? 1 : 0);
        if (cfFramework) {
            // Try several possible symbol names for CFCopySystemVersionDictionary
            const char *symbolNames[] = {
                "CFCopySystemVersionDictionary",
                "_CFCopySystemVersionDictionary",
                "__CFCopySystemVersionDictionary"
            };
            
            void *cfCopySystemVersionDictionaryPtr = NULL;
            for (int i = 0; i < 3; i++) {
                cfCopySystemVersionDictionaryPtr = dlsym(cfFramework, symbolNames[i]);
                if (cfCopySystemVersionDictionaryPtr) {
                    IOSVERSION_LOG(@"Found CoreFoundation symbol: %s", symbolNames[i]);
                    break;
                }
            }
            
            if (cfCopySystemVersionDictionaryPtr) {
                // Owned by PXNativeHookCoordinator — skip direct MSHookFunction.
                PXFileDebugAIDA64Log("[IOSVersion.ctor] skip CFCopySystemVersionDictionary (coordinator-owned)");
                IOSVERSION_LOG(@"Skipping CFCopySystemVersionDictionary (coordinator owns symbol)");
            } else {
                // If we can't find the symbol, create a stub implementation
                IOSVERSION_LOG(@"⚠️ Failed to find CFCopySystemVersionDictionary symbols, using fallback");
                
                // Set original function to NULL and handle it in the replacement function
                original_CFCopySystemVersionDictionary = NULL;
                IOSVERSION_LOG(@"Set original_CFCopySystemVersionDictionary to NULL, will use fallback in replacement function");
            }
            
            // Hook CFBundle info dictionary key function - try different symbol names
            const char *bundleSymbolNames[] = {
                "CFBundleGetValueForInfoDictionaryKey",
                "_CFBundleGetValueForInfoDictionaryKey",
                "__CFBundleGetValueForInfoDictionaryKey"
            };
            
            void *cfBundleGetValueForInfoDictionaryKeyPtr = NULL;
            for (int i = 0; i < 3; i++) {
                cfBundleGetValueForInfoDictionaryKeyPtr = dlsym(cfFramework, bundleSymbolNames[i]);
                if (cfBundleGetValueForInfoDictionaryKeyPtr) {
                    IOSVERSION_LOG(@"Found CFBundle symbol: %s", bundleSymbolNames[i]);
                    break;
                }
            }
            
            if (cfBundleGetValueForInfoDictionaryKeyPtr) {
                PXFileDebugAIDA64Log("[IOSVersion.ctor] before hook CFBundleGetValueForInfoDictionaryKey");
                MSHookFunction(cfBundleGetValueForInfoDictionaryKeyPtr, (void *)replaced_CFBundleGetValueForInfoDictionaryKey, (void **)&original_CFBundleGetValueForInfoDictionaryKey);
                PXFileDebugSignalHookDiagnostic(PXHookDiagnosticStageIOSVersionCFBundleHook,
                    original_CFBundleGetValueForInfoDictionaryKey ? PXHookDiagnosticResultSuccess :
                    PXHookDiagnosticResultFailed);
                PXFileDebugAIDA64Log("[IOSVersion.ctor] after hook CFBundleGetValueForInfoDictionaryKey");
                IOSVERSION_LOG(@"Successfully hooked CFBundleGetValueForInfoDictionaryKey");
            } else {
                PXFileDebugSignalHookDiagnostic(PXHookDiagnosticStageIOSVersionCFBundleHook,
                                                PXHookDiagnosticResultSymbolMissing);
                // If we can't find the symbol, create a stub implementation
                IOSVERSION_LOG(@"⚠️ Failed to find CFBundleGetValueForInfoDictionaryKey symbols, using fallback");
                
                // Set original function to NULL and handle it in the replacement function
                original_CFBundleGetValueForInfoDictionaryKey = NULL;
                IOSVERSION_LOG(@"Set original_CFBundleGetValueForInfoDictionaryKey to NULL, will use fallback in replacement function");
            }
        } else {
            PXFileDebugSignalHookDiagnostic(PXHookDiagnosticStageIOSVersionCFBundleHook,
                                            PXHookDiagnosticResultSymbolMissing);
            IOSVERSION_LOG(@"⚠️ Failed to open CoreFoundation framework");
        }
        
        // sysctlbyname is owned by PXNativeHookCoordinator/Tweak identity provider.
        IOSVERSION_LOG(@"Skipping sysctlbyname hook (coordinator/owner handles)");

        // Set up hooks for direct file access methods to catch SystemVersion.plist reads
        IOSVERSION_LOG(@"Setting up hooks for direct file access methods");
        
        // Hook NSData dataWithContentsOfFile:
        Class NSDataClass = objc_getClass("NSData");
        SEL dataWithContentsOfFileSelector = @selector(dataWithContentsOfFile:);
        Method dataWithContentsOfFileMethod = class_getClassMethod(NSDataClass, dataWithContentsOfFileSelector);
        if (dataWithContentsOfFileMethod) {
            original_NSData_dataWithContentsOfFile = (NSData* (*)(Class, SEL, NSString *))method_getImplementation(dataWithContentsOfFileMethod);
            method_setImplementation(dataWithContentsOfFileMethod, (IMP)replaced_NSData_dataWithContentsOfFile);
            IOSVERSION_LOG(@"Hooked NSData dataWithContentsOfFile:");
        } else {
            IOSVERSION_LOG(@"⚠️ Failed to hook NSData dataWithContentsOfFile:");
        }
        
        // Hook NSDictionary dictionaryWithContentsOfFile:
        Class NSDictionaryClass = objc_getClass("NSDictionary");
        SEL dictWithContentsOfFileSelector = @selector(dictionaryWithContentsOfFile:);
        Method dictWithContentsOfFileMethod = class_getClassMethod(NSDictionaryClass, dictWithContentsOfFileSelector);
        if (dictWithContentsOfFileMethod) {
            original_NSDictionary_dictionaryWithContentsOfFile = (NSDictionary* (*)(Class, SEL, NSString *))method_getImplementation(dictWithContentsOfFileMethod);
            method_setImplementation(dictWithContentsOfFileMethod, (IMP)replaced_NSDictionary_dictionaryWithContentsOfFile);
            IOSVERSION_LOG(@"Hooked NSDictionary dictionaryWithContentsOfFile:");
        } else {
            IOSVERSION_LOG(@"⚠️ Failed to hook NSDictionary dictionaryWithContentsOfFile:");
        }
        
        // Hook NSString stringWithContentsOfFile:encoding:error:
        Class NSStringClass = objc_getClass("NSString");
        SEL stringWithContentsOfFileSelector = @selector(stringWithContentsOfFile:encoding:error:);
        Method stringWithContentsOfFileMethod = class_getClassMethod(NSStringClass, stringWithContentsOfFileSelector);
        if (stringWithContentsOfFileMethod) {
            original_NSString_stringWithContentsOfFile = (id (*)(Class, SEL, NSString *, NSStringEncoding, NSError **))method_getImplementation(stringWithContentsOfFileMethod);
            method_setImplementation(stringWithContentsOfFileMethod, (IMP)replaced_NSString_stringWithContentsOfFile);
            IOSVERSION_LOG(@"Hooked NSString stringWithContentsOfFile:encoding:error:");
        } else {
            IOSVERSION_LOG(@"⚠️ Failed to hook NSString stringWithContentsOfFile:encoding:error:");
        }
        
        // Initialize Objective-C hooks for scoped apps only
        PXFileDebugAIDA64Log("[IOSVersion.ctor] before %%init");
        %init;
        PXFileDebugSignalHookDiagnostic(PXHookDiagnosticStageIOSVersionHooks,
                                        PXHookDiagnosticResultSuccess);
        PXFileDebugAIDA64Log("[IOSVersion.ctor] after %%init");
        
        IOSVERSION_LOG(@"iOS Version Hooks successfully initialized for scoped app: %@", bundleID);
        PXFileDebugAIDA64Log("[IOSVersion.ctor] exit");
    }
}

#pragma mark - File Access Hooks for SystemVersion.plist

static BOOL isSystemVersionFile(NSString *path) {
    return PXIsSystemVersionPlistPath(path);
}

static PXSystemVersionProjection *PXScopedSystemVersionProjection(void) {
    PX_RUNTIME_READ_OPERATION;
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    IdentifierManager *manager = [IdentifierManager sharedManager];
    if (!shouldSpoofForBundle(bundleID) || ![manager isIdentifierEnabled:@"IOSVersion"]) return nil;
    return PXCurrentReportingSystemVersionProjectionForBundle(bundleID);
}

static NSDictionary *spoofSystemVersionPlist(NSDictionary *originalPlist) {
    PX_RUNTIME_READ_OPERATION;
    if (!originalPlist) return nil;
    PXSystemVersionProjection *projection = PXScopedSystemVersionProjection();
    return projection ? PXTransformSystemVersionDictionary(originalPlist, projection) : originalPlist;
}

NSData *replaced_NSData_dataWithContentsOfFile(Class self, SEL _cmd, NSString *path) {
    PX_RUNTIME_READ_OPERATION;
    NSData *originalData = original_NSData_dataWithContentsOfFile
        ? original_NSData_dataWithContentsOfFile(self, _cmd, path)
        : nil;
    if (!originalData || !isSystemVersionFile(path)) return originalData;
    PXSystemVersionProjection *projection = PXScopedSystemVersionProjection();
    return projection ? PXTransformSystemVersionData(originalData, projection) : originalData;
}

NSDictionary *replaced_NSDictionary_dictionaryWithContentsOfFile(Class self, SEL _cmd, NSString *path) {
    PX_RUNTIME_READ_OPERATION;
    NSDictionary *originalDictionary = original_NSDictionary_dictionaryWithContentsOfFile
        ? original_NSDictionary_dictionaryWithContentsOfFile(self, _cmd, path)
        : nil;
    if (!originalDictionary || !isSystemVersionFile(path)) return originalDictionary;
    return spoofSystemVersionPlist(originalDictionary);
}

id replaced_NSString_stringWithContentsOfFile(Class self, SEL _cmd, NSString *path,
                                               NSStringEncoding encoding, NSError **error) {
    PX_RUNTIME_READ_OPERATION;
    NSString *originalString = original_NSString_stringWithContentsOfFile
        ? original_NSString_stringWithContentsOfFile(self, _cmd, path, encoding, error)
        : nil;
    if (!originalString || !isSystemVersionFile(path)) return originalString;
    PXSystemVersionProjection *projection = PXScopedSystemVersionProjection();
    return projection ? PXTransformSystemVersionString(originalString, encoding, projection) : originalString;
}
