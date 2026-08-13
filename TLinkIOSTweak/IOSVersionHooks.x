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
#import "PXUserAgentNormalizer.h"
#import "IdentifierManager.h"
#import "PXFileDebug.h"
#import <os/lock.h>

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
static void modifyUserAgentString(NSString **userAgentString, NSString *originalVersion, NSString *spoofedVersion);
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

// Version cache: immutable dictionary and timestamp are one lock-owned unit.
static const NSTimeInterval kIOSVersionCacheValidPeriod = 1800.0; // 30 minutes
static os_unfair_lock gIOSVersionCacheLock = OS_UNFAIR_LOCK_INIT;
static NSDictionary *versionCache = nil;
static NSTimeInterval lastVersionLoad = 0;

static NSDictionary *PXIOSVersionCachedInfo(NSTimeInterval now) {
    os_unfair_lock_lock(&gIOSVersionCacheLock);
    NSDictionary *cached = (versionCache && (now - lastVersionLoad < kIOSVersionCacheValidPeriod))
        ? versionCache
        : nil;
    os_unfair_lock_unlock(&gIOSVersionCacheLock);
    return cached;
}

static NSDictionary *PXIOSVersionPublishInfo(NSDictionary *info, NSTimeInterval loadedAt) {
    NSDictionary *immutableInfo = [info isKindOfClass:[NSDictionary class]] ? [info copy] : nil;
    os_unfair_lock_lock(&gIOSVersionCacheLock);
    versionCache = immutableInfo;
    lastVersionLoad = immutableInfo ? loadedAt : 0;
    NSDictionary *published = versionCache;
    os_unfair_lock_unlock(&gIOSVersionCacheLock);
    return published;
}

static void PXIOSVersionInvalidateCache(void) {
    os_unfair_lock_lock(&gIOSVersionCacheLock);
    versionCache = nil;
    lastVersionLoad = 0;
    os_unfair_lock_unlock(&gIOSVersionCacheLock);
}

// Throttling variables to prevent excessive function calls
static uint64_t lastSystemVersionCallTime = 0;
static NSString *cachedSystemVersionResult = nil;
// Define constants
#define THROTTLE_INTERVAL_NSEC 100000000  // 100ms in nanoseconds

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

// Load scoped apps from the plist file
static NSDictionary *loadScopedApps(void) {
    return PXScopedAppsSnapshot();
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

// Get the current iOS version information from the profile
static NSDictionary *getIOSVersionInfo() {
    static dispatch_once_t sourceLogOnce;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSDictionary *cached = PXIOSVersionCachedInfo(now);
    if (cached) return cached;

    PXIdentitySnapshot *identitySnapshot = PXCurrentIdentitySnapshot();
    NSDictionary *deviceIds = identitySnapshot.valid ? identitySnapshot.deviceIDs : nil;
    NSString *formattedVersion = [deviceIds[@"IOSVersion"] isKindOfClass:[NSString class]]
        ? deviceIds[@"IOSVersion"]
        : nil;

    if (deviceIds.count > 0) {
        NSString *version = nil;
        NSString *build = [deviceIds[@"IOSBuild"] isKindOfClass:[NSString class]] ? deviceIds[@"IOSBuild"] : nil;
        if ([formattedVersion containsString:@"("]) {
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"([0-9.]+)\\s*\\(([^)]+)\\)" options:0 error:nil];
            NSTextCheckingResult *match = [regex firstMatchInString:formattedVersion options:0 range:NSMakeRange(0, formattedVersion.length)];
            if (match && match.numberOfRanges == 3) {
                version = [formattedVersion substringWithRange:[match rangeAtIndex:1]];
                if (!build.length) build = [formattedVersion substringWithRange:[match rangeAtIndex:2]];
            }
        }
        if (!version.length && formattedVersion.length) version = formattedVersion;

        NSString *darwin = [deviceIds[@"Darwin"] isKindOfClass:[NSString class]] ? deviceIds[@"Darwin"] : nil;
        NSString *xnu = [deviceIds[@"XNU"] isKindOfClass:[NSString class]] ? deviceIds[@"XNU"] : nil;
        NSString *kernel = [deviceIds[@"KernelVersion"] isKindOfClass:[NSString class]] ? deviceIds[@"KernelVersion"] : nil;
        if (version.length && build.length && darwin.length && xnu.length && kernel.length) {
            NSDictionary *published = PXIOSVersionPublishInfo(@{
                @"version": version,
                @"build": build,
                @"darwin": darwin,
                @"xnu": xnu,
                @"kernel_version": kernel
            }, now);
            dispatch_once(&sourceLogOnce, ^{
                IOSVERSION_LOG(@"Using iOS version from device_ids: %@ (%@)", version, build);
            });
            return published;
        }
        IOSVERSION_LOG(@"device_ids.plist missing required iOS fields (version/build/darwin/xnu/kernel)");
    }

    NSDictionary *current = [[IOSVersionInfo sharedManager] currentIOSVersionInfo];
    if (current[@"version"] && current[@"build"] && current[@"darwin"] && current[@"xnu"] && current[@"kernel_version"]) {
        return PXIOSVersionPublishInfo(current, now);
    }
    return nil;
}

// Extract just the version number from the full version info
static NSString *getSpoofedSystemVersion() {
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

static PXUADebugSettings gUADebug;
static BOOL gUADebugValid = NO;
static NSTimeInterval gUADebugLastRead = 0;

static void PXUADebugInvalidate(void) {
    gUADebugValid = NO;
}

static NSDictionary *PXReadSecuritySettingsDict(void) {
    NSArray<NSString *> *paths = @[
        @"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist",
        @"/private/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist"
    ];
    for (NSString *p in paths) {
        NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:p];
        if ([d isKindOfClass:[NSDictionary class]]) return d;
    }
    return nil;
}

static id PXSecuritySettingObject(NSString *key) {
    NSDictionary *d = PXReadSecuritySettingsDict();
    if ([d isKindOfClass:[NSDictionary class]] && d[key] != nil) {
        return d[key];
    }
    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
    return [ud objectForKey:key];
}

static BOOL PXSecuritySettingBoolDefault(NSString *key, BOOL def) {
    id v = PXSecuritySettingObject(key);
    return v ? [v boolValue] : def;
}

static void PXUADebugEnsure(void) {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (gUADebugValid && (now - gUADebugLastRead) < 1.0) {
        return;
    }
    gUADebugLastRead = now;

    // Default: master OFF (no behavior change)
    BOOL master = PXSecuritySettingBoolDefault(@"debugSafariUAMasterEnabled", NO);
    gUADebug.masterEnabled = master;
    gUADebug.traceEnabled = PXSecuritySettingBoolDefault(@"debugSafariUATraceEnabled", NO);

    // Defaults when master ON: everything enabled
    gUADebug.scopeSafari = PXSecuritySettingBoolDefault(@"debugSafariUAScope_applySafari", YES);
    gUADebug.scopeSafariViewService = PXSecuritySettingBoolDefault(@"debugSafariUAScope_applySafariViewService", YES);
    gUADebug.scopeWebKit = PXSecuritySettingBoolDefault(@"debugSafariUAScope_applyWebKit", YES);

    gUADebug.hook_init = PXSecuritySettingBoolDefault(@"debugSafariUA_WKWebView_init", YES);
    gUADebug.hook_setCustomUserAgent = PXSecuritySettingBoolDefault(@"debugSafariUA_WKWebView_setCustomUserAgent", YES);
    gUADebug.hook_appNameUA = PXSecuritySettingBoolDefault(@"debugSafariUA_WKWebViewConfiguration_appNameUA", YES);
    gUADebug.hook_requestHeaderUA = PXSecuritySettingBoolDefault(@"debugSafariUA_NSURLRequest_setHeaderUA", YES);
    gUADebug.hook_sfUserAgentWithDomain = PXSecuritySettingBoolDefault(@"debugSafariUA_SFUserAgentController_userAgentWithDomain", YES);
    gUADebug.hook_sfDefaultUA = PXSecuritySettingBoolDefault(@"debugSafariUA_SFUserAgentController_defaultUA", YES);

    // Defaults: exemptions ON
    gUADebug.sensitiveHostExemptionsEnabled = PXSecuritySettingBoolDefault(@"debugSafariUA_SensitiveHostExemptionsEnabled", YES);

    gUADebugValid = YES;
}

static BOOL PXUADebugMasterEnabled(void) {
    PXUADebugEnsure();
    return gUADebug.masterEnabled;
}

static BOOL PXUADebugTraceEnabled(void) {
    PXUADebugEnsure();
    return gUADebug.traceEnabled;
}

// Whether to spoof the UA Mobile/<build> token. Default OFF.
// On older iOS/WebKit builds, changing the Mobile build token can create an impossible UA
// and break sensitive sites (e.g. Google login flows).
static BOOL gUAMobileBuildCached = NO;
static BOOL gUAMobileBuildValid = NO;
static NSTimeInterval gUAMobileBuildLastRead = 0;

static BOOL PXUAShouldSpoofMobileBuildToken(void) {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (gUAMobileBuildValid && (now - gUAMobileBuildLastRead) < 1.0) {
        return gUAMobileBuildCached;
    }
    gUAMobileBuildLastRead = now;
    gUAMobileBuildCached = PXSecuritySettingBoolDefault(@"uaSpoofMobileBuildEnabled", NO);
    gUAMobileBuildValid = YES;
    return gUAMobileBuildCached;
}

static void PXUAMobileBuildTokenInvalidate(void) {
    gUAMobileBuildValid = NO;
}

static BOOL PXUADebugScopeAllows(NSString *bundleID, NSString *processName) {
    PXUADebugEnsure();
    if (!gUADebug.masterEnabled) return YES;

    BOOL isSafari = PXIsSafariBrowserBundleIdentifier(bundleID);
    BOOL isSafariViewService = [bundleID isEqualToString:@"com.apple.SafariViewService"] ||
                               ([processName isKindOfClass:[NSString class]] && [processName containsString:@"SafariViewService"]);
    BOOL isWebKit = ([bundleID hasPrefix:@"com.apple.WebKit"] ||
                     ([processName isKindOfClass:[NSString class]] && [processName containsString:@"WebKit"]));

    if (isSafari) return gUADebug.scopeSafari;
    if (isSafariViewService) return gUADebug.scopeSafariViewService;
    if (isWebKit) return gUADebug.scopeWebKit;
    return YES;
}

static BOOL PXUAHostIsSensitive(NSString *hostOrDomain) {
    if (!hostOrDomain.length) return NO;

    // In Full Spoof Test Mode we intentionally do NOT exempt sensitive hosts.
    // This is used to reproduce failure cases (e.g. Google login breakages) reliably.
    if (PXFullSpoofTestModeEnabled()) {
        return NO;
    }

    PXUADebugEnsure();
    if (gUADebug.masterEnabled && !gUADebug.sensitiveHostExemptionsEnabled) {
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

    BOOL fileLogEnabled = PXSecuritySettingBoolDefault(@"debugSafariUA_LogFileEnabled", YES);
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

// ---- UA Sync Test: keep HTTP header UA and JS UA aligned ----
// Enable via com.weaponx.securitySettings.plist key: uaSyncHeaderAndJS (default NO)
static BOOL gUASyncEnabledCached = NO;
static BOOL gUASyncEnabledValid = NO;
static NSTimeInterval gUASyncEnabledLastRead = 0;

static BOOL PXUASyncHeaderAndJSEnabled(void) {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (gUASyncEnabledValid && (now - gUASyncEnabledLastRead) < 1.0) {
        return gUASyncEnabledCached;
    }
    gUASyncEnabledLastRead = now;
    // uaSyncHeaderAndJS: sync both layers when UA is modified
    // uaSyncJSOnlyFromRequests: allow syncing JS UA even if header UA modification is disabled via debug toggle
    BOOL syncBoth = PXSecuritySettingBoolDefault(@"uaSyncHeaderAndJS", NO);
    BOOL syncJSOnly = PXSecuritySettingBoolDefault(@"uaSyncJSOnlyFromRequests", NO);
    gUASyncEnabledCached = (syncBoth || syncJSOnly);
    gUASyncEnabledValid = YES;
    return gUASyncEnabledCached;
}

static void PXUASyncInvalidate(void) {
    gUASyncEnabledValid = NO;
}

static dispatch_queue_t gWKWebViewsQueue;
static NSPointerArray *gWKWebViews; // weak
static NSMutableDictionary<NSString *, NSString *> *gUAByHost;
static NSString *gUASyncLastUA;
static __thread BOOL gUASyncApplying = NO;

static void PXUASyncInitIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gWKWebViewsQueue = dispatch_queue_create("com.hydra.tlinkios.wkwebviews", DISPATCH_QUEUE_SERIAL);
        gWKWebViews = [NSPointerArray weakObjectsPointerArray];
        gUAByHost = [NSMutableDictionary dictionary];
    });
}

static void PXUASyncRegisterWKWebView(WKWebView *webView) {
    if (!webView) return;
    PXUASyncInitIfNeeded();
    dispatch_async(gWKWebViewsQueue, ^{
        [gWKWebViews addPointer:(__bridge void *)webView];
        [gWKWebViews compact];
    });
}

static void PXUASyncUnregisterWKWebView(WKWebView *webView) {
    if (!webView) return;
    PXUASyncInitIfNeeded();
    dispatch_async(gWKWebViewsQueue, ^{
        for (NSUInteger i = 0; i < gWKWebViews.count; i++) {
            id obj = [gWKWebViews pointerAtIndex:i] ? (__bridge id)[gWKWebViews pointerAtIndex:i] : nil;
            if (obj == webView) {
                [gWKWebViews removePointerAtIndex:i];
                break;
            }
        }
        [gWKWebViews compact];
    });
}

static void PXUASyncRememberHostUA(NSString *host, NSString *ua) {
    if (!host.length || !ua.length) return;
    PXUASyncInitIfNeeded();
    dispatch_async(gWKWebViewsQueue, ^{
        gUAByHost[host.lowercaseString] = ua;
        gUASyncLastUA = ua;
    });
}

static NSString *PXUASyncLookupHostUA(NSString *host) {
    if (!host.length) return nil;
    PXUASyncInitIfNeeded();
    __block NSString *ua = nil;
    dispatch_sync(gWKWebViewsQueue, ^{
        ua = gUAByHost[host.lowercaseString];
    });
    return ua;
}

static void PXUASyncApplyToWebViewsForHost(NSString *host, NSString *ua) {
    if (!host.length || !ua.length) return;
    PXUASyncInitIfNeeded();
    dispatch_async(gWKWebViewsQueue, ^{
        [gWKWebViews compact];

        BOOL applyAll = PXSecuritySettingBoolDefault(@"uaSyncApplyAllWebViews", YES);
        BOOL injectJS = PXSecuritySettingBoolDefault(@"uaSyncInjectJS", YES);

        for (NSUInteger i = 0; i < gWKWebViews.count; i++) {
            WKWebView *wv = [gWKWebViews pointerAtIndex:i] ? (__bridge WKWebView *)[gWKWebViews pointerAtIndex:i] : nil;
            if (!wv) continue;
            NSString *h = wv.URL.host;

            if (!applyAll) {
                if (!h.length) continue;
                if (![h.lowercaseString isEqualToString:host.lowercaseString]) continue;
            }

            // WKWebView APIs must be called on main thread.
            dispatch_async(dispatch_get_main_queue(), ^{
                gUASyncApplying = YES;
                @try {
                    if ([wv respondsToSelector:@selector(setCustomUserAgent:)]) {
                        [wv setCustomUserAgent:ua];
                    }

                    if (injectJS && [wv respondsToSelector:@selector(evaluateJavaScript:completionHandler:)]) {
                        NSString *escaped = [[ua stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
                                             stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
                        NSString *js = [NSString stringWithFormat:
                                        @"(function(){try{Object.defineProperty(navigator,'userAgent',{get:function(){return '%@';},configurable:true});}catch(e){}})();",
                                        escaped];
                        [wv evaluateJavaScript:js completionHandler:nil];
                    }
                } @catch (__unused NSException *e) {
                }
                gUASyncApplying = NO;
            });
        }
    });
}

// Compatibility wrapper: every UA surface delegates to the central normalizer.
static void modifyUserAgentString(NSString **userAgentString, NSString *originalVersion, NSString *spoofedVersion) {
    (void)originalVersion;
    if (!userAgentString || !*userAgentString || !spoofedVersion.length) return;
    NSDictionary *versionInfo = getIOSVersionInfo();
    NSString *normalized = PXNormalizeUserAgent(*userAgentString,
                                                 spoofedVersion,
                                                 versionInfo[@"build"],
                                                 PXUAShouldSpoofMobileBuildToken());
    if (normalized.length) *userAgentString = normalized;
}

#pragma mark - Canonical WKWebView User Agent

static const void *kPXUABaseUserAgentKey = &kPXUABaseUserAgentKey;
static const void *kPXUAOwnsCustomUserAgentKey = &kPXUAOwnsCustomUserAgentKey;
static __thread BOOL gUACanonicalApplying = NO;

static NSString *PXUANativeBaseUserAgent(WKWebViewConfiguration *configuration) {
    NSString *applicationName = nil;
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
            NSString *userAgent = sendMessage(webViewClass, selector, applicationName);
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
            NSString *userAgent = sendMessage(controllerClass, selector);
            if ([userAgent isKindOfClass:[NSString class]] && userAgent.length) {
                return userAgent;
            }
        }
    } @catch (__unused NSException *exception) {
    }

    return nil;
}

static NSString *PXUASyntheticSpoofedUserAgent(WKWebViewConfiguration *configuration) {
    NSDictionary *versionInfo = getIOSVersionInfo();
    NSString *version = [versionInfo[@"version"] isKindOfClass:[NSString class]] ? versionInfo[@"version"] : nil;
    NSString *build = [versionInfo[@"build"] isKindOfClass:[NSString class]] ? versionInfo[@"build"] : nil;
    if (!version.length) return nil;
    if (!build.length) build = @"15E148";

    NSString *underscoredVersion = [version stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    NSString *deviceToken = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"iPad; CPU OS" : @"iPhone; CPU iPhone OS";
    NSMutableString *userAgent = [NSMutableString stringWithFormat:
        @"Mozilla/5.0 (%@ %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/%@",
        deviceToken,
        underscoredVersion,
        build];

    @try {
        NSString *applicationName = configuration.applicationNameForUserAgent;
        if (applicationName.length) [userAgent appendFormat:@" %@", applicationName];
    } @catch (__unused NSException *exception) {
    }
    return userAgent;
}

static BOOL PXUAShouldApplyForHost(NSString *bundleID, NSString *processName, NSString *host) {
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
}

static NSString *PXUAModifiedUserAgent(NSString *baseUserAgent, WKWebViewConfiguration *configuration) {
    NSString *spoofedVersion = getSpoofedSystemVersion();
    if (!spoofedVersion.length) return nil;

    NSString *candidate = baseUserAgent.length ? baseUserAgent : PXUASyntheticSpoofedUserAgent(configuration);
    if (!candidate.length) return nil;

    NSMutableString *modified = [candidate mutableCopy];
    // The replacement patterns are version-agnostic; the non-empty placeholder keeps
    // the legacy helper contract without consulting asynchronously spoofed UIDevice state.
    modifyUserAgentString(&modified, @"native", spoofedVersion);
    return modified;
}

static void PXUASetExactCustomUserAgent(WKWebView *webView, NSString *userAgent, BOOL owned) {
    if (!webView) return;
    gUACanonicalApplying = YES;
    @try {
        [webView setCustomUserAgent:userAgent];
        objc_setAssociatedObject(webView,
                                 kPXUAOwnsCustomUserAgentKey,
                                 @(owned),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @finally {
        gUACanonicalApplying = NO;
    }
}

static void PXUAEnsureCanonicalUserAgent(WKWebView *webView,
                                         WKWebViewConfiguration *configuration,
                                         NSString *host,
                                         NSString *hookName) {
    if (!webView) return;

    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString *processName = [NSProcessInfo processInfo].processName;
    if (PXUADebugMasterEnabled() && !PXUADebugScopeAllows(bundleID, processName)) {
        PXUADebugTrace(hookName, bundleID, processName, host, @"skip", @"reason=scope", nil, nil);
        return;
    }
    if (PXUADebugMasterEnabled() && !gUADebug.hook_init) {
        PXUADebugTrace(hookName, bundleID, processName, host, @"skip", @"reason=toggle", nil, nil);
        return;
    }

    id storedBase = objc_getAssociatedObject(webView, kPXUABaseUserAgentKey);
    if (!storedBase) {
        NSString *resolvedBase = PXUANativeBaseUserAgent(configuration ?: webView.configuration);
        storedBase = resolvedBase ?: (id)[NSNull null];
        objc_setAssociatedObject(webView,
                                 kPXUABaseUserAgentKey,
                                 storedBase,
                                 OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    NSString *baseUserAgent = [storedBase isKindOfClass:[NSString class]] ? storedBase : nil;
    BOOL currentlyOwned = [objc_getAssociatedObject(webView, kPXUAOwnsCustomUserAgentKey) boolValue];
    BOOL shouldApply = PXUAShouldApplyForHost(bundleID, processName, host);

    if (!shouldApply) {
        if (currentlyOwned) {
            NSString *before = webView.customUserAgent;
            PXUASetExactCustomUserAgent(webView, baseUserAgent, NO);
            PXUADebugTrace(hookName, bundleID, processName, host, @"restore", @"reason=host", before, baseUserAgent);
        }
        return;
    }

    NSString *desiredUserAgent = PXUAModifiedUserAgent(baseUserAgent, configuration ?: webView.configuration);
    if (!desiredUserAgent.length) return;

    NSString *currentUserAgent = webView.customUserAgent;
    if (![currentUserAgent isEqualToString:desiredUserAgent]) {
        PXUASetExactCustomUserAgent(webView, desiredUserAgent, YES);
        PXUADebugTrace(hookName, bundleID, processName, host, @"modify", @"canonical-before-load", currentUserAgent, desiredUserAgent);
    } else if (!currentlyOwned) {
        objc_setAssociatedObject(webView,
                                 kPXUAOwnsCustomUserAgentKey,
                                 @YES,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

#pragma mark - UIDevice Hooks

%hook UIDevice

// Hook the systemVersion method to return our spoofed version
- (NSString *)systemVersion {
    @try {
        // Rate limiting - don't call this function too frequently
        uint64_t currentTime = mach_absolute_time();
        if (cachedSystemVersionResult != nil && 
            (currentTime - lastSystemVersionCallTime) < THROTTLE_INTERVAL_NSEC) {
            return cachedSystemVersionResult;
        }
        
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (shouldSpoofForBundle(bundleID)) {
            NSString *spoofedVersion = getSpoofedSystemVersion();
            if (spoofedVersion) {
                NSString *originalVersion = %orig;
                
                // Only log occasionally to reduce overhead
                if (lastSystemVersionCallTime == 0 || (currentTime - lastSystemVersionCallTime) > THROTTLE_INTERVAL_NSEC * 10) {
                    IOSVERSION_LOG(@"UIDevice.systemVersion: %@ → %@", originalVersion, spoofedVersion);
                }
                
                // Update cache and timestamp
                lastSystemVersionCallTime = currentTime;
                cachedSystemVersionResult = spoofedVersion;
                
                return spoofedVersion;
            }
        }
        
        // Cache the original result too
        NSString *originalResult = %orig;
        lastSystemVersionCallTime = currentTime;
        cachedSystemVersionResult = originalResult;
        return originalResult;
    } @catch (NSException *e) {
        IOSVERSION_LOG(@"❌ Error in systemVersion hook: %@", e);
    }
    
    return %orig;
}

%end

#pragma mark - NSProcessInfo Hooks

%hook NSProcessInfo

// Hook operatingSystemVersion to return our spoofed version
- (NSOperatingSystemVersion)operatingSystemVersion {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (shouldSpoofForBundle(bundleID)) {
            NSString *spoofedVersion = getSpoofedSystemVersion();
            if (spoofedVersion) {
                NSOperatingSystemVersion originalVersion = %orig;
                NSOperatingSystemVersion spoofedStructVersion = getOperatingSystemVersion(spoofedVersion);
                
                NSLog(@"[iosversion] NSProcessInfo.operatingSystemVersion: %ld.%ld.%ld → %ld.%ld.%ld", 
                      (long)originalVersion.majorVersion, 
                      (long)originalVersion.minorVersion, 
                      (long)originalVersion.patchVersion,
                      (long)spoofedStructVersion.majorVersion, 
                      (long)spoofedStructVersion.minorVersion, 
                      (long)spoofedStructVersion.patchVersion);
                
                return spoofedStructVersion;
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[iosversion] Error in operatingSystemVersion hook: %@", e);
    }
    return %orig;
}

// Hook isOperatingSystemAtLeastVersion to handle our spoofed version
- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (shouldSpoofForBundle(bundleID)) {
            NSString *spoofedVersion = getSpoofedSystemVersion();
            if (spoofedVersion) {
                NSOperatingSystemVersion spoofedStructVersion = getOperatingSystemVersion(spoofedVersion);

                // Feature gate: never claim OS capabilities above the *real* device OS.
                // systemVersion / operatingSystemVersion still return the full spoof for
                // fingerprint display; this only blocks code paths that would load
                // unavailable frameworks (e.g. WidgetKit on iOS 13 after spoofing 14+).
                static NSOperatingSystemVersion realOS = {0, 0, 0};
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    NSDictionary *sv = [NSDictionary dictionaryWithContentsOfFile:
                                        @"/System/Library/CoreServices/SystemVersion.plist"];
                    NSString *ver = [sv[@"ProductVersion"] isKindOfClass:[NSString class]] ? sv[@"ProductVersion"] : nil;
                    if (ver.length) {
                        NSArray *parts = [ver componentsSeparatedByString:@"."];
                        if (parts.count > 0) realOS.majorVersion = [parts[0] integerValue];
                        if (parts.count > 1) realOS.minorVersion = [parts[1] integerValue];
                        if (parts.count > 2) realOS.patchVersion = [parts[2] integerValue];
                    }
                });

                NSOperatingSystemVersion effective = spoofedStructVersion;
                BOOL spoofAboveReal =
                    (effective.majorVersion > realOS.majorVersion) ||
                    (effective.majorVersion == realOS.majorVersion && effective.minorVersion > realOS.minorVersion) ||
                    (effective.majorVersion == realOS.majorVersion && effective.minorVersion == realOS.minorVersion &&
                     effective.patchVersion > realOS.patchVersion);
                if (spoofAboveReal && realOS.majorVersion > 0) {
                    effective = realOS;
                }

                BOOL result = (effective.majorVersion > version.majorVersion) ||
                             ((effective.majorVersion == version.majorVersion) &&
                              (effective.minorVersion > version.minorVersion)) ||
                             ((effective.majorVersion == version.majorVersion) &&
                              (effective.minorVersion == version.minorVersion) &&
                              (effective.patchVersion >= version.patchVersion));
                return result;
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[iosversion] Error in isOperatingSystemAtLeastVersion hook: %@", e);
    }
    return %orig;
}

// Additional method to hook for getting raw operating system version string
- (NSString *)operatingSystemVersionString {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (shouldSpoofForBundle(bundleID)) {
            NSDictionary *versionInfo = getIOSVersionInfo();
            if (versionInfo && versionInfo[@"version"]) {
                NSString *originalVersion = %orig;
                NSString *spoofedVersion = [NSString stringWithFormat:@"Version %@ (Build %@)", 
                                           versionInfo[@"version"], 
                                           versionInfo[@"build"]];
                
                IOSVERSION_LOG(@"NSProcessInfo.operatingSystemVersionString: %@ → %@", 
                      originalVersion, spoofedVersion);
                      
                return spoofedVersion;
            }
        }
    } @catch (NSException *e) {
        IOSVERSION_LOG(@"❌ Error in operatingSystemVersionString hook: %@", e);
    }
    
    return %orig;
}

%end

#pragma mark - WKWebView User Agent Hooks

%hook WKWebView

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    // Resolve the native base synchronously before construction. No JavaScript round-trip
    // is allowed here because callers may issue loadRequest: immediately after init returns.
    NSString *nativeBaseUserAgent = PXUANativeBaseUserAgent(configuration);
    WKWebView *webView = %orig(frame, configuration);
    if (!webView) return webView;

    objc_setAssociatedObject(webView,
                             kPXUABaseUserAgentKey,
                             nativeBaseUserAgent ?: (id)[NSNull null],
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(webView,
                             kPXUAOwnsCustomUserAgentKey,
                             @NO,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (PXUASyncHeaderAndJSEnabled()) {
        PXUASyncRegisterWKWebView(webView);
    }

    PXUAEnsureCanonicalUserAgent(webView, configuration, nil, @"WKWebView.init");
    return webView;
}

- (WKNavigation *)loadRequest:(NSURLRequest *)request {
    PXUAEnsureCanonicalUserAgent(self, self.configuration, request.URL.host, @"WKWebView.loadRequest");
    return %orig(request);
}

- (WKNavigation *)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL {
    PXUAEnsureCanonicalUserAgent(self, self.configuration, baseURL.host, @"WKWebView.loadHTMLString");
    return %orig(string, baseURL);
}

- (WKNavigation *)loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL {
    PXUAEnsureCanonicalUserAgent(self, self.configuration, URL.host, @"WKWebView.loadFileURL");
    return %orig(URL, readAccessURL);
}

- (WKNavigation *)loadData:(NSData *)data
                  MIMEType:(NSString *)MIMEType
     characterEncodingName:(NSString *)characterEncodingName
                   baseURL:(NSURL *)baseURL {
    PXUAEnsureCanonicalUserAgent(self, self.configuration, baseURL.host, @"WKWebView.loadData");
    return %orig(data, MIMEType, characterEncodingName, baseURL);
}

- (void)setCustomUserAgent:(NSString *)customUserAgent {
    if (gUASyncApplying || gUACanonicalApplying) {
        %orig(customUserAgent);
        return;
    }

    objc_setAssociatedObject(self,
                             kPXUABaseUserAgentKey,
                             customUserAgent ?: (id)[NSNull null],
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self,
                             kPXUAOwnsCustomUserAgentKey,
                             @NO,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSString *processName = [NSProcessInfo processInfo].processName;
        NSString *host = self.URL.host;
        if (PXUADebugMasterEnabled() && !PXUADebugScopeAllows(bundleID, processName)) {
            PXUADebugTrace(@"WKWebView.setCustomUserAgent", bundleID, processName, host, @"skip", @"reason=scope", customUserAgent, nil);
            %orig(customUserAgent);
            return;
        }
        if (PXUADebugMasterEnabled() && !gUADebug.hook_setCustomUserAgent) {
            PXUADebugTrace(@"WKWebView.setCustomUserAgent", bundleID, processName, host, @"skip", @"reason=toggle", customUserAgent, nil);
            %orig(customUserAgent);
            return;
        }

        if (customUserAgent.length && PXUAShouldApplyForHost(bundleID, processName, host)) {
            NSString *modifiedUserAgent = PXUAModifiedUserAgent(customUserAgent, self.configuration);
            if (modifiedUserAgent.length && ![modifiedUserAgent isEqualToString:customUserAgent]) {
                objc_setAssociatedObject(self,
                                         kPXUAOwnsCustomUserAgentKey,
                                         @YES,
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                PXUADebugTrace(@"WKWebView.setCustomUserAgent", bundleID, processName, host, @"modify", @"", customUserAgent, modifiedUserAgent);
                %orig(modifiedUserAgent);
                return;
            }
        }
    } @catch (NSException *exception) {
        IOSVERSION_LOG(@"Error in setCustomUserAgent: %@", exception);
    }

    %orig(customUserAgent);
}


%end

#pragma mark - WKWebViewConfiguration Hooks

%hook WKWebViewConfiguration

- (void)setApplicationNameForUserAgent:(NSString *)applicationNameForUserAgent {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (PXUADebugMasterEnabled() && !PXUADebugScopeAllows(bundleID, proc)) {
            PXUADebugTrace(@"WKWebViewConfiguration.setApplicationNameForUserAgent", bundleID, proc, nil, @"skip", @"reason=scope", applicationNameForUserAgent, nil);
            %orig;
            return;
        }
        if (PXUADebugMasterEnabled() && !gUADebug.hook_appNameUA) {
            PXUADebugTrace(@"WKWebViewConfiguration.setApplicationNameForUserAgent", bundleID, proc, nil, @"skip", @"reason=toggle", applicationNameForUserAgent, nil);
            %orig;
            return;
        }
        // Don't mutate UA at configuration time for Safari/Auth stack; host is unknown here.
        // In FullSpoof test mode we allow this to force UA spoofing.
        BOOL forceSpoofForWebKit = PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack) &&
                                  PXIsSafariStackProcess(bundleID, proc);
        if (forceSpoofForWebKit && !PXFullSpoofTestModeEnabled()) {
            PXUADebugTrace(@"WKWebViewConfiguration.setApplicationNameForUserAgent", bundleID, proc, nil, @"skip", @"reason=safaristack", applicationNameForUserAgent, nil);
            %orig;
            return;
        }

        if (shouldSpoofForBundle(bundleID) && applicationNameForUserAgent) {
            NSString *spoofedVersion = getSpoofedSystemVersion();
            NSString *originalVersion = [[UIDevice currentDevice] systemVersion];
            
            if (spoofedVersion) {
                NSMutableString *modifiedName = [applicationNameForUserAgent mutableCopy];
                modifyUserAgentString(&modifiedName, originalVersion, spoofedVersion);
                
                if (![modifiedName isEqualToString:applicationNameForUserAgent]) {
                    PXUADebugTrace(@"WKWebViewConfiguration.setApplicationNameForUserAgent", bundleID, proc, nil, @"modify", @"", applicationNameForUserAgent, modifiedName);
                    %orig(modifiedName);
                    return;
                }
            }
        }
    } @catch (NSException *e) {
        // Error handling
    }
    
    %orig;
}

%end

#pragma mark - NSURLRequest User-Agent Hooks

%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    @try {
        NSSet *managedIdentityHeaders = [NSSet setWithArray:@[@"accept-language", @"sec-ch-ua-platform", @"sec-ch-ua-mobile"]];
        NSString *canonicalField = [field lowercaseString];
        if (value && [managedIdentityHeaders containsObject:canonicalField]) {
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            NSString *proc = [NSProcessInfo processInfo].processName;
            if (PXUAShouldApplyForHost(bundleID, proc, self.URL.host)) {
                NSDictionary *canonical = PXCanonicalWebIdentityHeaders(@{field: value},
                    [NSLocale currentLocale].localeIdentifier, UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone);
                for (NSString *name in canonical) {
                    if ([name caseInsensitiveCompare:field] == NSOrderedSame) {
                        %orig(canonical[name], field);
                        return;
                    }
                }
            }
        }
        if ([field isEqualToString:@"User-Agent"] && value) {
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            NSString *proc = [NSProcessInfo processInfo].processName;
            if (PXUADebugMasterEnabled() && !PXUADebugScopeAllows(bundleID, proc)) {
                PXUADebugTrace(@"NSMutableURLRequest.setValue(User-Agent)", bundleID, proc, self.URL.host, @"skip", @"reason=scope", value, nil);
                %orig;
                return;
            }
            BOOL headerModifyEnabled = !(PXUADebugMasterEnabled() && !gUADebug.hook_requestHeaderUA);
            BOOL syncEnabled = PXUASyncHeaderAndJSEnabled();
            if (!headerModifyEnabled && !syncEnabled) {
                PXUADebugTrace(@"NSMutableURLRequest.setValue(User-Agent)", bundleID, proc, self.URL.host, @"skip", @"reason=toggle", value, nil);
                %orig;
                return;
            }
            if (shouldSpoofForBundle(bundleID)) {
                NSString *host = self.URL.host;
                if (PXUAHostIsSensitive(host)) {
                    PXUADebugTrace(@"NSMutableURLRequest.setValue(User-Agent)", bundleID, proc, host, @"skip", @"reason=sensitive", value, nil);
                    %orig;
                    return;
                }
                NSString *spoofedVersion = getSpoofedSystemVersion();
                NSString *originalVersion = [[UIDevice currentDevice] systemVersion];
                
                if (spoofedVersion) {
                    NSMutableString *modifiedValue = [value mutableCopy];
                    modifyUserAgentString(&modifiedValue, originalVersion, spoofedVersion);
                    
                    if (![modifiedValue isEqualToString:value]) {
                        // If syncing is enabled, always push the UA into JS layer (customUserAgent + optional JS patch)
                        // even when header UA modification is disabled (for mismatch testing).
                        if (syncEnabled && host.length) {
                            PXUASyncRememberHostUA(host, modifiedValue);
                            PXUASyncApplyToWebViewsForHost(host, modifiedValue);
                            PXUADebugTrace(@"UASync.remember", bundleID, proc, host, @"modify", headerModifyEnabled ? @"" : @"reason=jsOnly", value, modifiedValue);
                        }

                        if (headerModifyEnabled) {
                            PXUADebugTrace(@"NSMutableURLRequest.setValue(User-Agent)", bundleID, proc, host, @"modify", @"", value, modifiedValue);
                            %orig(modifiedValue, field);
                            return;
                        }

                        // Header disabled: keep original header, only sync JS.
                        PXUADebugTrace(@"NSMutableURLRequest.setValue(User-Agent)", bundleID, proc, host, @"skip", @"reason=jsOnly", value, modifiedValue);
                        %orig;
                        return;
                    }
                }
            }
        }
    } @catch (NSException *e) {
        // Error handling
    }
    
    %orig;
}

%end

#pragma mark - Safari Specific Hooks

// Hook Safari's SFUserAgentController to modify the user agent string
%hook SFUserAgentController

+ (NSString *)userAgentWithDomain:(NSString *)domain {
    NSString *originalUA = %orig;
    
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (PXUADebugMasterEnabled() && !PXUADebugScopeAllows(bundleID, proc)) {
            PXUADebugTrace(@"SFUserAgentController.userAgentWithDomain", bundleID, proc, domain, @"skip", @"reason=scope", originalUA, nil);
            return originalUA;
        }
        if (PXUADebugMasterEnabled() && !gUADebug.hook_sfUserAgentWithDomain) {
            PXUADebugTrace(@"SFUserAgentController.userAgentWithDomain", bundleID, proc, domain, @"skip", @"reason=toggle", originalUA, nil);
            return originalUA;
        }
        if (PXIsSafariBrowserBundleIdentifier(bundleID)) {
            if (PXUAHostIsSensitive(domain)) {
                PXUADebugTrace(@"SFUserAgentController.userAgentWithDomain", bundleID, proc, domain, @"skip", @"reason=sensitive", originalUA, nil);
                return originalUA;
            }
            NSString *spoofedVersion = getSpoofedSystemVersion();
            NSString *originalVersion = [[UIDevice currentDevice] systemVersion];
            
            if (spoofedVersion && originalUA) {
                NSMutableString *modifiedUA = [originalUA mutableCopy];
                modifyUserAgentString(&modifiedUA, originalVersion, spoofedVersion);
                
                if (![modifiedUA isEqualToString:originalUA]) {
                    PXUADebugTrace(@"SFUserAgentController.userAgentWithDomain", bundleID, proc, domain, @"modify", @"", originalUA, modifiedUA);
                    IOSVERSION_LOG(@"Safari: Modified user agent for domain %@", domain);
                    return modifiedUA;
                }
            }
        }
    } @catch (NSException *e) {
        IOSVERSION_LOG(@"Error modifying Safari user agent: %@", e);
    }
    
    return originalUA;
}

+ (NSString *)defaultUserAgentString {
    NSString *originalUA = %orig;
    
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (PXUADebugMasterEnabled() && !PXUADebugScopeAllows(bundleID, proc)) {
            PXUADebugTrace(@"SFUserAgentController.defaultUserAgentString", bundleID, proc, nil, @"skip", @"reason=scope", originalUA, nil);
            return originalUA;
        }
        if (PXUADebugMasterEnabled() && !gUADebug.hook_sfDefaultUA) {
            PXUADebugTrace(@"SFUserAgentController.defaultUserAgentString", bundleID, proc, nil, @"skip", @"reason=toggle", originalUA, nil);
            return originalUA;
        }
        if (PXIsSafariBrowserBundleIdentifier(bundleID)) {
            // Avoid global UA changes for Safari; per-request/domain hooks handle spoofing.
            // In FullSpoof test mode, allow default UA mutation to force failures.
            if (PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack) && !PXFullSpoofTestModeEnabled()) {
                PXUADebugTrace(@"SFUserAgentController.defaultUserAgentString", bundleID, proc, nil, @"skip", @"reason=safaristack", originalUA, nil);
                return originalUA;
            }
            NSString *spoofedVersion = getSpoofedSystemVersion();
            NSString *originalVersion = [[UIDevice currentDevice] systemVersion];
            
            if (spoofedVersion && originalUA) {
                NSMutableString *modifiedUA = [originalUA mutableCopy];
                modifyUserAgentString(&modifiedUA, originalVersion, spoofedVersion);
                
                if (![modifiedUA isEqualToString:originalUA]) {
                    PXUADebugTrace(@"SFUserAgentController.defaultUserAgentString", bundleID, proc, nil, @"modify", @"", originalUA, modifiedUA);
                    IOSVERSION_LOG(@"Safari: Modified default user agent");
                    return modifiedUA;
                }
            }
        }
    } @catch (NSException *e) {
        IOSVERSION_LOG(@"Error modifying Safari default user agent: %@", e);
    }
    
    return originalUA;
}

%end

#pragma mark - CoreFoundation Version Dictionary Hook

// Hook CFCopySystemVersionDictionary through the IOS-06 unified transformer.
static CFDictionaryRef (*original_CFCopySystemVersionDictionary)(void);
CFDictionaryRef replaced_CFCopySystemVersionDictionary(void) {
    CFDictionaryRef original = original_CFCopySystemVersionDictionary ? original_CFCopySystemVersionDictionary() : NULL;
    @autoreleasepool {
        @try {
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            IdentifierManager *manager = [IdentifierManager sharedManager];
            if (!shouldSpoofForBundle(bundleID) || ![manager isIdentifierEnabled:@"IOSVersion"]) return original;

            PXSystemVersionProjection *projection = PXCurrentSystemVersionProjection();
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
    @try {
        NSString *bundleID = [self bundleIdentifier];
        if (shouldSpoofForBundle(bundleID)) {
            // App-specific version/build spoofing (only for main bundle)
            if ([key isEqualToString:@"CFBundleShortVersionString"] || [key isEqualToString:@"CFBundleVersion"]) {
                NSString *mainBundleID = getCurrentBundleID();
                if (mainBundleID.length && [bundleID isEqualToString:mainBundleID]) {
                    NSString *spoofVer = nil;
                    NSString *spoofBuild = nil;
                    if (PXGetSpoofedAppVersionForBundle(mainBundleID, &spoofVer, &spoofBuild)) {
                        if ([key isEqualToString:@"CFBundleShortVersionString"] && spoofVer.length) {
                            return spoofVer;
                        }
                        if ([key isEqualToString:@"CFBundleVersion"] && spoofBuild.length) {
                            return spoofBuild;
                        }
                    }
                }
            }

            // Handle system version info in Info.plist queries
            if ([key isEqualToString:@"MinimumOSVersion"] || 
                [key isEqualToString:@"DTPlatformVersion"] ||
                [key isEqualToString:@"DTSDKName"]) {
                
                NSString *spoofedVersion = getSpoofedSystemVersion();
                if (spoofedVersion) {
                    // For SDK and platform keys, add iOS prefix if needed
                    if ([key isEqualToString:@"DTPlatformVersion"] || 
                        [key isEqualToString:@"DTSDKName"]) {
                        if (![spoofedVersion hasPrefix:@"iOS"]) {
                            return [NSString stringWithFormat:@"iOS%@", spoofedVersion];
                        }
                        return spoofedVersion;
                    }
                    return spoofedVersion;
                }
            }
        }
    } @catch (NSException *e) {
        // Error handling
    }
    
    return %orig;
}

%end

// Original function pointer for CFBundleGetValueForInfoDictionaryKey
static CFTypeRef (*original_CFBundleGetValueForInfoDictionaryKey)(CFBundleRef bundle, CFStringRef key);

// Replacement function for CFBundleGetValueForInfoDictionaryKey
CFTypeRef replaced_CFBundleGetValueForInfoDictionaryKey(CFBundleRef bundle, CFStringRef key) {
    @try {
        if (!bundle || !key) return NULL;
        
        // Get the bundle ID for CFBundle
        CFStringRef bundleID = CFBundleGetIdentifier(bundle);
        NSString *nsBundleID = bundleID ? (__bridge NSString*)bundleID : nil;
        
        if (shouldSpoofForBundle(nsBundleID)) {
            // App-specific version/build spoofing (only for main bundle)
            if (CFEqual(key, CFSTR("CFBundleShortVersionString")) || CFEqual(key, CFSTR("CFBundleVersion"))) {
                NSString *mainBundleID = getCurrentBundleID();
                if (mainBundleID.length && [nsBundleID isEqualToString:mainBundleID]) {
                    NSString *spoofVer = nil;
                    NSString *spoofBuild = nil;
                    if (PXGetSpoofedAppVersionForBundle(mainBundleID, &spoofVer, &spoofBuild)) {
                        if (CFEqual(key, CFSTR("CFBundleShortVersionString")) && spoofVer.length) {
                            return CFStringCreateWithCString(NULL, [spoofVer UTF8String], kCFStringEncodingUTF8);
                        }
                        if (CFEqual(key, CFSTR("CFBundleVersion")) && spoofBuild.length) {
                            return CFStringCreateWithCString(NULL, [spoofBuild UTF8String], kCFStringEncodingUTF8);
                        }
                    }
                }
            }

            // Check for system version keys
            if (CFEqual(key, CFSTR("MinimumOSVersion")) || 
                CFEqual(key, CFSTR("DTPlatformVersion")) ||
                CFEqual(key, CFSTR("DTSDKName"))) {
                
                NSString *spoofedVersion = getSpoofedSystemVersion();
                if (spoofedVersion) {
                    // Log what we're spoofing
                    NSLog(@"[iosversion] 💉 Spoofing %@ for bundle %@ to %@", 
                          (__bridge NSString*)key, nsBundleID, spoofedVersion);
                    
                    // Create a CFString from our spoofed version
                    if (CFEqual(key, CFSTR("DTPlatformVersion")) || 
                        CFEqual(key, CFSTR("DTSDKName"))) {
                        
                        if (![spoofedVersion hasPrefix:@"iOS"]) {
                            NSString *prefixedVersion = [NSString stringWithFormat:@"iOS%@", spoofedVersion];
                            return CFStringCreateWithCString(NULL, [prefixedVersion UTF8String], kCFStringEncodingUTF8);
                        }
                    }
                    
                    return CFStringCreateWithCString(NULL, [spoofedVersion UTF8String], kCFStringEncodingUTF8);
                }
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[iosversion] ❌ Error in CFBundleGetValueForInfoDictionaryKey hook: %@", e);
    }
    
    // Call original function if available, otherwise return NULL
    if (original_CFBundleGetValueForInfoDictionaryKey) {
        return original_CFBundleGetValueForInfoDictionaryKey(bundle, key);
    } else {
        // For some keys, provide default values
        if (key && (CFEqual(key, CFSTR("MinimumOSVersion")))) {
            // Return the current device's actual iOS version for MinimumOSVersion
            NSString *actualVersion = [[UIDevice currentDevice] systemVersion];
            return CFStringCreateWithCString(NULL, [actualVersion UTF8String], kCFStringEncodingUTF8);
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

    // Clear UA debug cache (runtime toggles)
    PXUADebugInvalidate();

    // Clear UA Mobile/<build> toggle cache
    PXUAMobileBuildTokenInvalidate();

    // Clear UA sync toggle cache
    PXUASyncInvalidate();

    // Clear app version spoof cache
    PXAppVersionHooksInvalidateCache();

    // Clear sync mapping (avoid stale UA across tests)
    PXUASyncInitIfNeeded();
    dispatch_async(gWKWebViewsQueue, ^{
        [gUAByHost removeAllObjects];
        gUASyncLastUA = nil;
        [gWKWebViews compact];
    });
}

// Safe check if a bundle ID is a critical system process
static BOOL isCriticalSystemProcess(NSString *bundleID) {
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
    cachedSystemVersionResult = nil;
    PXIOSVersionInvalidateCache();
}

%ctor {
    @autoreleasepool {
        PXFileDebugAIDA64Log("[IOSVersion.ctor] enter");
        // Get the bundle ID for scope checking
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        // Skip for system processes to avoid potential issues
        if (isCriticalSystemProcess(bundleID)) {
            return;
        }
        
        IOSVERSION_LOG(@"Initializing iOS Version Hooks for %@...", bundleID);
        
        NSString *proc = [NSProcessInfo processInfo].processName;
        BOOL allowed = PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack);
        PXFileDebugAIDA64Log("[IOSVersion.ctor] scope allowed=%d bundle=%s", allowed, bundleID.UTF8String ?: "<nil>");
        if (!allowed) {
            // App is NOT scoped - no hooks, no interference, no crashes
            IOSVERSION_LOG(@"App %@ is not scoped, skipping iOS version hook installation", bundleID);
            return;
        }
        
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
                PXFileDebugAIDA64Log("[IOSVersion.ctor] after hook CFBundleGetValueForInfoDictionaryKey");
                IOSVERSION_LOG(@"Successfully hooked CFBundleGetValueForInfoDictionaryKey");
            } else {
                // If we can't find the symbol, create a stub implementation
                IOSVERSION_LOG(@"⚠️ Failed to find CFBundleGetValueForInfoDictionaryKey symbols, using fallback");
                
                // Set original function to NULL and handle it in the replacement function
                original_CFBundleGetValueForInfoDictionaryKey = NULL;
                IOSVERSION_LOG(@"Set original_CFBundleGetValueForInfoDictionaryKey to NULL, will use fallback in replacement function");
            }
        } else {
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
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    IdentifierManager *manager = [IdentifierManager sharedManager];
    if (!shouldSpoofForBundle(bundleID) || ![manager isIdentifierEnabled:@"IOSVersion"]) return nil;
    return PXCurrentSystemVersionProjection();
}

static NSDictionary *spoofSystemVersionPlist(NSDictionary *originalPlist) {
    if (!originalPlist) return nil;
    PXSystemVersionProjection *projection = PXScopedSystemVersionProjection();
    return projection ? PXTransformSystemVersionDictionary(originalPlist, projection) : originalPlist;
}

NSData *replaced_NSData_dataWithContentsOfFile(Class self, SEL _cmd, NSString *path) {
    NSData *originalData = original_NSData_dataWithContentsOfFile
        ? original_NSData_dataWithContentsOfFile(self, _cmd, path)
        : nil;
    if (!originalData || !isSystemVersionFile(path)) return originalData;
    PXSystemVersionProjection *projection = PXScopedSystemVersionProjection();
    return projection ? PXTransformSystemVersionData(originalData, projection) : originalData;
}

NSDictionary *replaced_NSDictionary_dictionaryWithContentsOfFile(Class self, SEL _cmd, NSString *path) {
    NSDictionary *originalDictionary = original_NSDictionary_dictionaryWithContentsOfFile
        ? original_NSDictionary_dictionaryWithContentsOfFile(self, _cmd, path)
        : nil;
    if (!originalDictionary || !isSystemVersionFile(path)) return originalDictionary;
    return spoofSystemVersionPlist(originalDictionary);
}

id replaced_NSString_stringWithContentsOfFile(Class self, SEL _cmd, NSString *path,
                                               NSStringEncoding encoding, NSError **error) {
    NSString *originalString = original_NSString_stringWithContentsOfFile
        ? original_NSString_stringWithContentsOfFile(self, _cmd, path, encoding, error)
        : nil;
    if (!originalString || !isSystemVersionFile(path)) return originalString;
    PXSystemVersionProjection *projection = PXScopedSystemVersionProjection();
    return projection ? PXTransformSystemVersionString(originalString, encoding, projection) : originalString;
}