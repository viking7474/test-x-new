#import "TLinkIOS.h"
#import "UptimeManager.h"
#import "TLinkIOSLogging.h"
#import "PXNativeHookCoordinator.h"
#import <Foundation/Foundation.h>
#import <sys/sysctl.h>
#import <sys/time.h>
#import <mach/mach.h>
#import <mach/mach_time.h>
#import <mach/mach_host.h>
#import <substrate.h>
// #import <ellekit/ellekit.h> // Removed for rootful - using Substrate
#import <dlfcn.h>
#import <objc/runtime.h>

#import "PXScope.h"
#import "PXRuntimeUtilities.h"
#import "PXPaths.h"
#import <os/lock.h>
#import "PXFileDebug.h"

// Define the boot time structure for sysctl calls
struct timeval_boot {
    time_t tv_sec;
    suseconds_t tv_usec;
};

// Original function pointers - ONLY for system calls
static int (*orig_sysctl)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
static int (*orig_sysctlbyname)(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen);

// Cache for spoofed values to improve performance
static os_unfair_lock gBootTimeCacheLock = OS_UNFAIR_LOCK_INIT;
static NSDate *cachedBootTime = nil;
static NSTimeInterval cachedUptime = 0;
static NSString *cachedProfilePath = nil;
static NSDate *cacheTimestamp = nil;
static const NSTimeInterval kCacheValidityDuration = 30.0;

static NSDate *PXCachedBootTimeValue(void) {
    os_unfair_lock_lock(&gBootTimeCacheLock);
    NSDate *value = cachedBootTime;
    os_unfair_lock_unlock(&gBootTimeCacheLock);
    return value;
}

static NSTimeInterval PXCachedUptimeValue(void) {
    os_unfair_lock_lock(&gBootTimeCacheLock);
    NSTimeInterval value = cachedUptime;
    os_unfair_lock_unlock(&gBootTimeCacheLock);
    return value;
}

static void PXInvalidateBootTimeCache(void) {
    os_unfair_lock_lock(&gBootTimeCacheLock);
    cachedBootTime = nil;
    cachedUptime = 0;
    cachedProfilePath = nil;
    cacheTimestamp = nil;
    os_unfair_lock_unlock(&gBootTimeCacheLock);
}

static void PXBootTimeSettingsChanged(CFNotificationCenterRef center,
                                      void *observer,
                                      CFStringRef name,
                                      const void *object,
                                      CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    PXInvalidateBootTimeCache();
    PXInvalidateScopeDecisionCache();
}



// Global flag to track if hooks are installed
static BOOL hooksInstalled = NO;

// Recursion guard to prevent infinite loops when UptimeManager calls sysctl
static __thread BOOL isInsideHook = NO;

// Forward declarations
static BOOL shouldSpoofBootTimeForApp(void);
static NSString *getCurrentProfilePath(void);
static void updateCachedBootTimeValues(void);
static void logBootTimeAccess(const char *method, NSString *bundleID);
static NSString *getCurrentBundleID(void);
static NSDictionary *loadScopedApps(void);
static BOOL isInScopedAppsList(void);
static void installSystemCallHooks(void);
static BOOL isBootTimeOrUptimeEnabled(void);

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

// Check if boot time spoofing should be applied for the current app
static BOOL shouldSpoofBootTimeForApp(void) {
    @try {
        NSString *bundleID = getCurrentBundleID();
        if (!bundleID) return NO;
        NSString *proc = [NSProcessInfo processInfo].processName;
        return PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack);
        
    } @catch (NSException *e) {
        return NO;
    }
}

// Get the current profile path for spoofed values
// NOTE: Boot time / uptime keys live in the profile identity directory
// (identity/device_ids.plist, boot_time.plist, system_uptime.plist) — the same
// location IdentifierManager writes to. Returning the identity path keeps the
// tweak's reads/writes consistent with the app side and stops duplicate plists
// from being created in the profile root directory.
static NSString *getCurrentProfilePath(void) {
    return PXActiveProfileIdentityPath();
}

// Update cached boot time values from profile data
static void updateCachedBootTimeValues(void) {
    @try {
        NSString *profilePath = getCurrentProfilePath();
        if (!profilePath.length) {
            if (PXLogOnceClaim(@"BootTimeHooks.missingProfile", @"active-profile")) {
                PXLog(@"[BootTimeHooks] No active profile path available");
            }
            return;
        }

        NSDate *now = [NSDate date];
        os_unfair_lock_lock(&gBootTimeCacheLock);
        BOOL valid = cachedBootTime && cacheTimestamp &&
            [cachedProfilePath isEqualToString:profilePath] &&
            [now timeIntervalSinceDate:cacheTimestamp] < kCacheValidityDuration;
        os_unfair_lock_unlock(&gBootTimeCacheLock);
        if (valid) return;

        UptimeManager *uptimeManager = [UptimeManager sharedManager];
        if (!uptimeManager) return;
        NSDate *bootTime = [uptimeManager currentBootTimeForProfile:profilePath];
        NSTimeInterval uptime = [uptimeManager currentUptimeForProfile:profilePath];
        if (!bootTime || uptime <= 0) {
            [uptimeManager generateConsistentUptimeAndBootTimeForProfile:profilePath];
            bootTime = [uptimeManager currentBootTimeForProfile:profilePath];
            uptime = [uptimeManager currentUptimeForProfile:profilePath];
        }
        if (bootTime && uptime > 0) {
            os_unfair_lock_lock(&gBootTimeCacheLock);
            cachedBootTime = [bootTime copy];
            cachedUptime = uptime;
            cachedProfilePath = [profilePath copy];
            cacheTimestamp = now;
            os_unfair_lock_unlock(&gBootTimeCacheLock);
        }
    } @catch (__unused NSException *e) {
    }
}

// Log boot time access attempts for debugging
static void logBootTimeAccess(const char *method, NSString *bundleID) {
    @try {
        if (!method || !bundleID.length) return;
        NSString *methodStr = [NSString stringWithUTF8String:method];
        if (!methodStr.length) return;
        NSString *methodKey = [NSString stringWithFormat:@"%@:%@", methodStr, bundleID];
        if (PXLogOnceClaim(@"BootTimeHooks.access", methodKey)) {
            PXLog(@"[BootTimeHooks] App %@ accessed boot time via %@", bundleID, methodStr);
        }
    } @catch (__unused NSException *e) {
    }
}

// Helper to check if a spoof identifier is enabled for the current profile
static BOOL isBootTimeOrUptimeEnabled(void) {
    @try {
        // Dynamically get IdentifierManager class and sharedManager
        Class managerClass = NSClassFromString(@"IdentifierManager");
        if (!managerClass) return NO;
        id manager = [managerClass respondsToSelector:@selector(sharedManager)] ? [managerClass sharedManager] : nil;
        if (!manager) return NO;
        
        SEL isEnabledSel = NSSelectorFromString(@"isIdentifierEnabled:");
        if (![manager respondsToSelector:isEnabledSel]) return NO;
        
        BOOL bootTimeEnabled = NO;
        BOOL uptimeEnabled = NO;
        NSString *bootTimeStr = @"BootTime";
        NSString *uptimeStr = @"SystemUptime";
        NSMethodSignature *sig = [manager methodSignatureForSelector:isEnabledSel];
        if (sig) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
            [invocation setSelector:isEnabledSel];
            [invocation setTarget:manager];
            // BootTime
            [invocation setArgument:&bootTimeStr atIndex:2];
            [invocation invoke];
            [invocation getReturnValue:&bootTimeEnabled];
            // SystemUptime
            [invocation setArgument:&uptimeStr atIndex:2];
            [invocation invoke];
            [invocation getReturnValue:&uptimeEnabled];
        }
        return bootTimeEnabled || uptimeEnabled;
    } @catch (NSException *e) {
        return NO;
    }
}

#pragma mark - System Call Hooks

// Hook sysctl() for KERN_BOOTTIME queries - ONLY method that App Store apps commonly use
int hook_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    static BOOL logged = NO;
    if (!logged) {
        logged = YES;
        PXFileDebugAIDA64Log("[BootTime.sysctl] first namelen=%u key0=%d key1=%d", namelen, name ? name[0] : -1, (name && namelen > 1) ? name[1] : -1);
    }
    // CRITICAL: Recursion guard - if we're already inside hook, pass through to original
    if (isInsideHook) {
        if (orig_sysctl) {
            return orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
        }
        return -1;
    }
    
    @try {
        // Also handle kernel build/version queries here to avoid leaks when multiple sysctl hooks exist.
        if (namelen >= 2 && name && name[0] == CTL_KERN && oldlenp) {
            BOOL isOSVersion = (name[1] == KERN_OSVERSION);
            BOOL isOSRelease = (name[1] == KERN_OSRELEASE);
            BOOL isKernelVer = (name[1] == KERN_VERSION);
            if (isOSVersion || isOSRelease || isKernelVer) {
                @try {
                    id mgrClass = NSClassFromString(@"IdentifierManager");
                    id mgr = mgrClass ? [mgrClass performSelector:@selector(sharedManager)] : nil;
                    NSString *bundleID = getCurrentBundleID();

                    SEL selIsIdEnabled = @selector(isIdentifierEnabled:);
                    SEL selProfilePath = @selector(profileIdentityPath);

                    NSString *proc = [NSProcessInfo processInfo].processName;
                    BOOL appEnabled = PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack);
                    BOOL iosEnabled = NO;
                    NSString *identityDir = nil;

                    if (mgr && [mgr respondsToSelector:selIsIdEnabled]) {
                        NSMethodSignature *sig = [mgr methodSignatureForSelector:selIsIdEnabled];
                        if (sig) {
                            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                            [inv setTarget:mgr];
                            [inv setSelector:selIsIdEnabled];
                            NSString *arg = @"IOSVersion";
                            [inv setArgument:&arg atIndex:2];
                            [inv invoke];
                            [inv getReturnValue:&iosEnabled];
                        }
                    }

                    if (mgr && [mgr respondsToSelector:selProfilePath]) {
                        identityDir = [mgr performSelector:selProfilePath];
                    }

                    if (mgr && bundleID && appEnabled && iosEnabled) {
                        NSDictionary *deviceIds = identityDir.length > 0 ? [NSDictionary dictionaryWithContentsOfFile:[identityDir stringByAppendingPathComponent:@"device_ids.plist"]] : nil;
                        NSDictionary *current = nil;
                        id versionClass = NSClassFromString(@"IOSVersionInfo");
                        id versionMgr = versionClass ? [versionClass performSelector:@selector(sharedManager)] : nil;
                        if (versionMgr && [versionMgr respondsToSelector:@selector(currentIOSVersionInfo)]) {
                            current = [versionMgr performSelector:@selector(currentIOSVersionInfo)];
                        }
                        NSString *val = nil;
                        if (isOSVersion) val = deviceIds[@"IOSBuild"] ?: current[@"build"];
                        else if (isOSRelease) val = deviceIds[@"Darwin"] ?: current[@"darwin"];
                        else val = deviceIds[@"KernelVersion"] ?: current[@"kernel_version"];

                        if (val.length > 0) {
                            const char *s = [val UTF8String];
                            if (s) {
                                size_t required = strlen(s) + 1;
                                if (!oldp) {
                                    *oldlenp = required;
                                    return 0;
                                }
                                if (*oldlenp < required) {
                                    *oldlenp = required;
                                    errno = ENOMEM;
                                    return -1;
                                }
                                memset(oldp, 0, *oldlenp);
                                memcpy(oldp, s, required);
                                *oldlenp = required;
                                return 0;
                            }
                        }
                    }
                } @catch (__unused NSException *e) {
                }
            }
        }

        // Check if this is a KERN_BOOTTIME query
        if (namelen >= 2 && name && name[0] == CTL_KERN && name[1] == KERN_BOOTTIME) {
            if (shouldSpoofBootTimeForApp() && isBootTimeOrUptimeEnabled()) {
                NSString *bundleID = getCurrentBundleID();
                if (bundleID) {
                    logBootTimeAccess("sysctl(KERN_BOOTTIME)", bundleID);
                }
                
                // Set recursion guard before calling UptimeManager
                isInsideHook = YES;
                updateCachedBootTimeValues();
                isInsideHook = NO;
                
                NSDate *bootTime = PXCachedBootTimeValue();
                if (bootTime && oldp && oldlenp && *oldlenp >= sizeof(struct timeval)) {
                    struct timeval boottime;
                    boottime.tv_sec = (time_t)[bootTime timeIntervalSince1970];
                    boottime.tv_usec = 0;
                    memcpy(oldp, &boottime, sizeof(boottime));
                    *oldlenp = sizeof(boottime);
                    return 0; // Success
                }
            }
        }
    } @catch (NSException *e) {
        isInsideHook = NO; // Reset guard on exception
        // Silent failure, pass through to original
    }
    // Call original function for all other cases
    if (orig_sysctl) {
        return orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    }
    return -1;
}

// Hook sysctlbyname() for "kern.boottime" queries - ONLY method that App Store apps commonly use
int hook_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    static int loggedCount = 0;
    if (name && loggedCount < 20) {
        loggedCount++;
        PXFileDebugAIDA64Log("[BootTime.sysctlbyname] key=%s", name);
    }
    // CRITICAL: Recursion guard - if we're already inside hook, pass through to original
    if (isInsideHook) {
        if (orig_sysctlbyname) {
            return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
        }
        return -1;
    }
    
    @try {
        if (name && strcmp(name, "kern.boottime") == 0) {
            if (shouldSpoofBootTimeForApp() && isBootTimeOrUptimeEnabled()) {
                NSString *bundleID = getCurrentBundleID();
                if (bundleID) {
                    logBootTimeAccess("sysctlbyname(kern.boottime)", bundleID);
                }
                
                // Set recursion guard before calling UptimeManager
                isInsideHook = YES;
                updateCachedBootTimeValues();
                isInsideHook = NO;
                
                NSDate *bootTime = PXCachedBootTimeValue();
                if (bootTime && oldp && oldlenp && *oldlenp >= sizeof(struct timeval)) {
                    struct timeval boottime;
                    boottime.tv_sec = (time_t)[bootTime timeIntervalSince1970];
                    boottime.tv_usec = 0;
                    memcpy(oldp, &boottime, sizeof(boottime));
                    *oldlenp = sizeof(boottime);
                    return 0; // Success
                }
            }
        }
    } @catch (NSException *e) {
        isInsideHook = NO; // Reset guard on exception
        // Silent failure, pass through to original
    }
    // Call original function for all other cases
    if (orig_sysctlbyname) {
        return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
    }
    return -1;
}

// Hook for -[NSProcessInfo systemUptime]
static NSTimeInterval (*orig_systemUptime)(NSProcessInfo *, SEL);
static NSTimeInterval hook_systemUptime(NSProcessInfo *self, SEL _cmd) {
    // Recursion guard
    if (isInsideHook) {
        return orig_systemUptime(self, _cmd);
    }
    
    if (shouldSpoofBootTimeForApp() && isBootTimeOrUptimeEnabled()) {
        isInsideHook = YES;
        updateCachedBootTimeValues();
        isInsideHook = NO;
        
        NSTimeInterval uptime = PXCachedUptimeValue();
        if (uptime > 0) return uptime;
    }
    return orig_systemUptime(self, _cmd);
}

// Register as coordinator providers — do NOT call MSHookFunction for sysctl/sysctlbyname.
static void installSystemCallHooks(void) {
    @try {
        PXFileDebugAIDA64Log("[BootTime.installSystemCallHooks] enter");
        if (hooksInstalled) {
            PXFileDebugAIDA64Log("[BootTime.installSystemCallHooks] already installed");
            return;
        }

        PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
        [coord installOwnedSymbolsIfNeeded];
        orig_sysctl = [coord originalForSymbol:kPXNativeSymbolSysctl];
        orig_sysctlbyname = [coord originalForSymbol:kPXNativeSymbolSysctlByname];

        // Priority Identity, provider ID sorts before "tweak.*" so boot-time keys win when handled.
        // CRITICAL: UptimeManager.generate* calls sysctl(KERN_BOOTTIME) to sample the real
        // boot time. Providers MUST return NO while isInsideHook so the coordinator runs the
        // original and we never recurse: provider → UptimeManager → sysctl → provider...
        [coord registerSysctlProvider:@"boottime.sysctl" priority:PXNativeHookPriorityIdentity pre:^BOOL(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen, int *outResult) {
            (void)newp; (void)newlen;
            if (isInsideHook) return NO; // pass through to original (and later providers)
            if (!(namelen >= 2 && name && name[0] == CTL_KERN && name[1] == KERN_BOOTTIME)) return NO;
            if (!shouldSpoofBootTimeForApp() || !isBootTimeOrUptimeEnabled()) return NO;

            isInsideHook = YES;
            @try {
                updateCachedBootTimeValues();
            } @finally {
                isInsideHook = NO;
            }

            NSDate *bootTime = PXCachedBootTimeValue();
            if (bootTime && oldp && oldlenp && *oldlenp >= sizeof(struct timeval)) {
                struct timeval boottime;
                boottime.tv_sec = (time_t)[bootTime timeIntervalSince1970];
                boottime.tv_usec = 0;
                memcpy(oldp, &boottime, sizeof(boottime));
                *oldlenp = sizeof(boottime);
                if (outResult) *outResult = 0;
                return YES;
            }
            // Two-call sizing
            if (!oldp && oldlenp && bootTime) {
                *oldlenp = sizeof(struct timeval);
                if (outResult) *outResult = 0;
                return YES;
            }
            return NO;
        } post:nil];

        [coord registerSysctlBynameProvider:@"boottime.sysctlbyname" priority:PXNativeHookPriorityIdentity pre:^BOOL(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen, int *outResult) {
            (void)newp; (void)newlen;
            if (isInsideHook) return NO;
            if (!name || strcmp(name, "kern.boottime") != 0) return NO;
            if (!shouldSpoofBootTimeForApp() || !isBootTimeOrUptimeEnabled()) return NO;

            isInsideHook = YES;
            @try {
                updateCachedBootTimeValues();
            } @finally {
                isInsideHook = NO;
            }

            NSDate *bootTime = PXCachedBootTimeValue();
            if (bootTime && oldp && oldlenp && *oldlenp >= sizeof(struct timeval)) {
                struct timeval boottime;
                boottime.tv_sec = (time_t)[bootTime timeIntervalSince1970];
                boottime.tv_usec = 0;
                memcpy(oldp, &boottime, sizeof(boottime));
                *oldlenp = sizeof(boottime);
                if (outResult) *outResult = 0;
                return YES;
            }
            // Two-call sizing: oldp NULL
            if (!oldp && oldlenp) {
                *oldlenp = sizeof(struct timeval);
                if (outResult) *outResult = 0;
                return YES;
            }
            return NO;
        } post:nil];

        Class procInfoClass = objc_getClass("NSProcessInfo");
        if (procInfoClass) {
            MSHookMessageEx(procInfoClass, @selector(systemUptime), (IMP)hook_systemUptime, (IMP *)&orig_systemUptime);
        }

        hooksInstalled = YES;
        PXLog(@"[BootTimeHooks] ✅ Boot-time providers registered (no direct MSHookFunction)");
        PXFileDebugAIDA64Log("[BootTime.installSystemCallHooks] success");
    } @catch (NSException *e) {
        PXLog(@"[BootTimeHooks] ❌ Exception installing hooks: %@", e);
    }
}

#pragma mark - Initialization

// COMPLETELY REMOVED ALL %hook DIRECTIVES - NO MORE OBJECTIVE-C METHOD HOOKS
// This eliminates crashes in non-scoped apps

%ctor {
    @autoreleasepool {
        @try {
            PXFileDebugAIDA64Log("[BootTime.ctor] enter");
            NSString *bundleID = getCurrentBundleID();
            
            // Skip if we can't get bundle ID
            if (!bundleID || [bundleID length] == 0) {
                return;
            }
            
            NSString *proc = [NSProcessInfo processInfo].processName;
            if (PXIsWebKitHelperProcess(bundleID, proc)) {
                PXFileDebugAIDA64Log("[BootTime.ctor] skip WebKit helper bundle=%s", bundleID.UTF8String ?: "<nil>");
                return;
            }
            BOOL allowed = PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack);
            PXFileDebugAIDA64Log("[BootTime.ctor] scope allowed=%d bundle=%s", allowed, bundleID.UTF8String ?: "<nil>");
            if (!allowed) {
                return;
            }
            
            PXLog(@"[BootTimeHooks] 🎯 Installing minimal system call hooks for scoped app: %@", bundleID);
            
            CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
            for (NSString *notificationName in @[
                @"com.hydra.tlinkios.settings.changed",
                @"com.hydra.tlinkios.profileChanged",
                @"com.hydra.tlinkios.scopedAppsChanged"
            ]) {
                CFNotificationCenterAddObserver(center, NULL, PXBootTimeSettingsChanged,
                    (__bridge CFStringRef)notificationName, NULL,
                    CFNotificationSuspensionBehaviorDeliverImmediately);
            }

            // Install the minimal system call hooks that App Store apps actually use immediately
            installSystemCallHooks();
            PXFileDebugAIDA64Log("[BootTime.ctor] exit");
            
        } @catch (NSException *e) {
            PXFileDebugAIDA64Log("[BootTime.ctor] exception=%s", e.description.UTF8String ?: "<nil>");
            // Silent failure to prevent crashes
        }
    }
} 
