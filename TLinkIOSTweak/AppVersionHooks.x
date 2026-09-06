// AppVersionHooks.x
// App-version spoof helpers + full Info.plist dictionary access paths.

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <substrate.h>
#import <dlfcn.h>
#import <stdatomic.h>

#import "AppVersionHooks.h"
#import "PXScope.h"
#import "PXPaths.h"
#import "PXNativeFilesystemReentry.h"
#import "PXFileDebug.h"
#import "PXP1BFilters.h"
#import <os/lock.h>

static NSDictionary *gCachedVersionSpoofPlist = nil;
static NSDate *gCachedVersionSpoofMTime = nil;
static NSString *gCachedVersionSpoofPath = nil;

static os_unfair_lock gAppVersionCacheLock = OS_UNFAIR_LOCK_INIT;
static NSMutableDictionary<NSString *, NSDictionary *> *gCachedProfileVersionPlists = nil;
static NSMutableDictionary<NSString *, NSDate *> *gCachedProfileVersionMTime = nil;

static void PXEnsureAppVersionProfileCaches(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gCachedProfileVersionPlists = [NSMutableDictionary dictionary];
        gCachedProfileVersionMTime = [NSMutableDictionary dictionary];
    });
}

static NSString *PXVersionSpoofPlistPath(void) {
    return [PXPreferencesPath() stringByAppendingPathComponent:@"com.hydra.tlinkios.version_spoof.plist"];
}

// Full-dictionary CF cache: stable retained CFDictionary per (bundleID + localized + generation)
static _Atomic int32_t gAppVersionCacheGeneration = 0;

// Prevent infinite recursion:
// -[NSBundle infoDictionary] <-> -[NSBundle bundleIdentifier] <-> CFBundleGetInfoDictionary
static __thread int gPXAppVersionInfoRecursion = 0;

// Captured BEFORE hooks install — never call -[NSBundle bundleIdentifier] from hook bodies.
static NSString *gMainBundleIDCached = nil;

typedef struct {
    CFDictionaryRef dict;
    CFStringRef bundleID;
    int32_t generation;
    BOOL localized;
    BOOL valid;
} PXCFInfoDictCacheEntry;

static PXCFInfoDictCacheEntry gCFInfoDictCache = {0};
static PXCFInfoDictCacheEntry gCFLocalInfoDictCache = {0};
static NSDictionary *gNSInfoDictCache = nil;
static NSDictionary *gNSLocalizedInfoDictCache = nil;
static NSString *gNSInfoDictBundleID = nil;
static int32_t gNSInfoDictGeneration = -1;
static NSString *gNSLocalizedInfoDictBundleID = nil;
static int32_t gNSLocalizedInfoDictGeneration = -1;

// Forward decls for original CF pointers (used by safe helpers).
static CFDictionaryRef (*original_CFBundleGetInfoDictionary)(CFBundleRef bundle) = NULL;
static CFDictionaryRef (*original_CFBundleGetLocalInfoDictionary)(CFBundleRef bundle) = NULL;

/// Main bundle ID without re-entering infoDictionary hooks.
static NSString *PXMainBundleIDCached(void) {
    if (gMainBundleIDCached.length) return gMainBundleIDCached;

    // Best effort while already inside a hook: read via ORIGINAL CF API only.
    if (original_CFBundleGetInfoDictionary) {
        CFBundleRef mainCF = CFBundleGetMainBundle();
        if (mainCF) {
            CFDictionaryRef info = original_CFBundleGetInfoDictionary(mainCF);
            if (info) {
                CFStringRef bid = CFDictionaryGetValue(info, kCFBundleIdentifierKey);
                if (bid && CFGetTypeID(bid) == CFStringGetTypeID()) {
                    gMainBundleIDCached = CFBridgingRelease(CFStringCreateCopy(kCFAllocatorDefault, bid));
                    return gMainBundleIDCached;
                }
            }
        }
    }
    return nil;
}

/// Identifier for an arbitrary CFBundle without going through hooked NSBundle paths.
static NSString *PXCFBundleIDSafe(CFBundleRef bundle) {
    if (!bundle) return nil;
    // Prefer CFBundleGetIdentifier only when NOT inside our info-dict hooks — it can
    // refresh via CFBundleGetInfoDictionary. When recursing, read from original dict.
    if (gPXAppVersionInfoRecursion == 0) {
        CFStringRef cfID = CFBundleGetIdentifier(bundle);
        if (cfID) return (__bridge NSString *)cfID;
    }
    if (original_CFBundleGetInfoDictionary) {
        CFDictionaryRef info = original_CFBundleGetInfoDictionary(bundle);
        if (info) {
            CFStringRef bid = CFDictionaryGetValue(info, kCFBundleIdentifierKey);
            if (bid && CFGetTypeID(bid) == CFStringGetTypeID()) {
                return (__bridge NSString *)bid;
            }
        }
    }
    return nil;
}

static NSDate *PXFileMTime(NSString *path) {
    if (PXNativeFilesystemCriticalIsActive() || !path.length) return nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    return [attrs isKindOfClass:[NSDictionary class]] ? attrs[NSFileModificationDate] : nil;
}

static NSDictionary *PXReadPlist(NSString *path) {
    if (PXNativeFilesystemCriticalIsActive() || !path.length) return nil;
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:path];
    return [d isKindOfClass:[NSDictionary class]] ? d : nil;
}

static NSString *PXResolveExistingPath(NSArray<NSString *> *candidates) {
    if (PXNativeFilesystemCriticalIsActive()) return nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *p in candidates) {
        if (p.length && [fm fileExistsAtPath:p]) {
            return p;
        }
    }
    return [candidates firstObject];
}

BOOL PXAppVersionSpoofMasterEnabled(void) {
    if (PXNativeFilesystemCriticalIsActive()) return NO;
    NSDictionary *settings = PXReadPlist(PXSecuritySettingsPath());
    return [settings[@"appVersionSpoofingEnabled"] boolValue];
}

static NSDictionary *PXLoadVersionSpoofPlistCached(void) {
    NSString *path = PXVersionSpoofPlistPath();
    NSDate *mtime = PXFileMTime(path);

    os_unfair_lock_lock(&gAppVersionCacheLock);
    BOOL valid = gCachedVersionSpoofPlist && [path isEqualToString:gCachedVersionSpoofPath] &&
        ((!mtime && !gCachedVersionSpoofMTime) ||
         (mtime && gCachedVersionSpoofMTime && [mtime isEqualToDate:gCachedVersionSpoofMTime]));
    NSDictionary *cached = valid ? gCachedVersionSpoofPlist : nil;
    os_unfair_lock_unlock(&gAppVersionCacheLock);
    if (cached) return cached;

    NSDictionary *loaded = PXReadPlist(path);
    os_unfair_lock_lock(&gAppVersionCacheLock);
    gCachedVersionSpoofPlist = [loaded copy];
    gCachedVersionSpoofMTime = [mtime copy];
    gCachedVersionSpoofPath = [path copy];
    NSDictionary *published = gCachedVersionSpoofPlist;
    os_unfair_lock_unlock(&gAppVersionCacheLock);
    return published;
}

static NSString *PXReadActiveProfileId(void) {
    return PXActiveProfileID();
}

static NSString *PXSafeBundleFilename(NSString *bundleID) {
    // Delegate to the shared, host-testable helper (P1-B, no drift with tests).
    return PXAppVersionSafeBundleFilename(bundleID);
}

static NSDictionary *PXLoadProfileAppVersionPlist(NSString *bundleID) {
    if (!bundleID.length) return nil;
    PXEnsureAppVersionProfileCaches();

    NSString *profileId = PXReadActiveProfileId();
    NSString *profileRoot = PXProfileRootPath(profileId);
    NSString *fileName = PXSafeBundleFilename(bundleID);
    if (!profileRoot.length || !fileName.length) return nil;

    NSString *path = [[profileRoot stringByAppendingPathComponent:@"app_versions"]
        stringByAppendingPathComponent:fileName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return nil;
    NSDate *mtime = PXFileMTime(path);

    os_unfair_lock_lock(&gAppVersionCacheLock);
    NSDictionary *cached = gCachedProfileVersionPlists[path];
    NSDate *cachedMTime = gCachedProfileVersionMTime[path];
    BOOL valid = cached && ((!mtime && !cachedMTime) ||
        (mtime && cachedMTime && [mtime isEqualToDate:cachedMTime]));
    os_unfair_lock_unlock(&gAppVersionCacheLock);
    if (valid) return cached;

    NSDictionary *loaded = PXReadPlist(path);
    if (!loaded) return nil;
    os_unfair_lock_lock(&gAppVersionCacheLock);
    gCachedProfileVersionPlists[path] = [loaded copy];
    if (mtime) gCachedProfileVersionMTime[path] = [mtime copy];
    else [gCachedProfileVersionMTime removeObjectForKey:path];
    NSDictionary *published = gCachedProfileVersionPlists[path];
    os_unfair_lock_unlock(&gAppVersionCacheLock);
    return published;
}

BOOL PXGetSpoofedAppVersionForBundle(NSString *bundleID, NSString **outVersion, NSString **outBuild) {
    if (outVersion) *outVersion = nil;
    if (outBuild) *outBuild = nil;
    if (PXNativeFilesystemCriticalIsActive() || !bundleID.length) return NO;

    if (!PXAppVersionSpoofMasterEnabled()) {
        return NO;
    }

    NSDictionary *global = PXLoadVersionSpoofPlistCached();
    NSDictionary *spoofedVersions = [global[@"SpoofedVersions"] isKindOfClass:[NSDictionary class]] ? global[@"SpoofedVersions"] : nil;
    NSDictionary *entry = [spoofedVersions[bundleID] isKindOfClass:[NSDictionary class]] ? spoofedVersions[bundleID] : nil;
    BOOL enabled = entry ? [entry[@"spoofingEnabled"] boolValue] : NO;

    NSString *ver = [entry[@"spoofedVersion"] isKindOfClass:[NSString class]] ? entry[@"spoofedVersion"] : nil;
    NSString *bld = [entry[@"spoofedBuild"] isKindOfClass:[NSString class]] ? entry[@"spoofedBuild"] : nil;

    if (enabled && (!ver.length || !bld.length)) {
        NSDictionary *profilePlist = PXLoadProfileAppVersionPlist(bundleID);
        if (profilePlist) {
            if (!ver.length) {
                ver = [profilePlist[@"spoofedVersion"] isKindOfClass:[NSString class]] ? profilePlist[@"spoofedVersion"] : ver;
            }
            if (!bld.length) {
                bld = [profilePlist[@"spoofedBuild"] isKindOfClass:[NSString class]] ? profilePlist[@"spoofedBuild"] : bld;
            }
        }
    }

    if (!enabled) return NO;
    if (!ver.length && !bld.length) return NO;

    if (outVersion && ver.length) *outVersion = ver;
    if (outBuild && bld.length) *outBuild = bld;
    return YES;
}

static void PXReleaseCFInfoDictCacheEntry(PXCFInfoDictCacheEntry *entry) {
    if (!entry) return;
    if (entry->dict) {
        CFRelease(entry->dict);
        entry->dict = NULL;
    }
    if (entry->bundleID) {
        CFRelease(entry->bundleID);
        entry->bundleID = NULL;
    }
    entry->generation = 0;
    entry->localized = NO;
    entry->valid = NO;
}

void PXAppVersionHooksInvalidateCache(void) {
    PXEnsureAppVersionProfileCaches();
    atomic_fetch_add(&gAppVersionCacheGeneration, 1);

    os_unfair_lock_lock(&gAppVersionCacheLock);
    gCachedVersionSpoofPlist = nil;
    gCachedVersionSpoofMTime = nil;
    gCachedVersionSpoofPath = nil;
    [gCachedProfileVersionPlists removeAllObjects];
    [gCachedProfileVersionMTime removeAllObjects];
    PXReleaseCFInfoDictCacheEntry(&gCFInfoDictCache);
    PXReleaseCFInfoDictCacheEntry(&gCFLocalInfoDictCache);
    gNSInfoDictCache = nil;
    gNSInfoDictBundleID = nil;
    gNSInfoDictGeneration = -1;
    gNSLocalizedInfoDictCache = nil;
    gNSLocalizedInfoDictBundleID = nil;
    gNSLocalizedInfoDictGeneration = -1;
    os_unfair_lock_unlock(&gAppVersionCacheLock);
    PXInvalidateScopeDecisionCache();
}

#pragma mark - Full dictionary helpers

static BOOL PXAppVersionScopeAllows(void) {
    // A native mount/stat callback may run while CoreServices holds MountInfo's
    // non-recursive lock. Never resolve scope through bundle/profile metadata there.
    if (PXNativeFilesystemCriticalIsActive()) return NO;
    // NEVER call -[NSBundle bundleIdentifier] here — it re-enters infoDictionary.
    NSString *bundleID = PXMainBundleIDCached();
    if (!bundleID.length) return NO;
    NSString *proc = [NSProcessInfo processInfo].processName;
    return PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionNone);
}

static NSDictionary *PXApplyAppVersionToInfoDictionary(NSDictionary *original, NSString *ver, NSString *build) {
    // Delegate to the shared, host-testable helper (P1-B, no drift with tests).
    return PXAppVersionApplyToInfoDictionary(original, ver, build);
}

static BOOL PXShouldSpoofMainBundleInfo(NSBundle *bundle, NSString **outMainBundleID, NSString **outVer, NSString **outBuild) {
    if (!bundle) return NO;
    if (!PXAppVersionScopeAllows()) return NO;

    NSString *mainBundleID = PXMainBundleIDCached();
    if (!mainBundleID.length) return NO;

    // Only spoof the main bundle. Compare object identity first to avoid
    // calling -[NSBundle bundleIdentifier] (re-enters infoDictionary).
    if (bundle != [NSBundle mainBundle]) {
        // Non-main: try CF path via executable URL / already-known identity only.
        // Reading [bundle bundleIdentifier] is unsafe under our hooks.
        return NO;
    }

    NSString *ver = nil;
    NSString *build = nil;
    if (!PXGetSpoofedAppVersionForBundle(mainBundleID, &ver, &build)) return NO;
    if (!ver.length && !build.length) return NO;

    if (outMainBundleID) *outMainBundleID = mainBundleID;
    if (outVer) *outVer = ver;
    if (outBuild) *outBuild = build;
    return YES;
}

#pragma mark - NSBundle full dictionary hooks

%group AppVersionFullDictionary

%hook NSBundle

- (NSDictionary *)infoDictionary {
    // CoreServices mount/property resolution can call bundle APIs while holding
    // MountInfo's non-recursive lock. In that context only the original bundle
    // dictionary is safe; AppVersion profile I/O must not run.
    if (PXNativeFilesystemCriticalIsActive()) return %orig;
    // Recursion: bundleIdentifier / CFBundleGetInfoDictionary re-enter here.
    if (gPXAppVersionInfoRecursion > 0) {
        return %orig;
    }
    gPXAppVersionInfoRecursion++;
    NSDictionary *original = %orig;
    NSDictionary *result = original;
    @try {
        NSString *mainBundleID = nil;
        NSString *ver = nil;
        NSString *build = nil;
        if (!PXShouldSpoofMainBundleInfo(self, &mainBundleID, &ver, &build)) {
            result = original;
        } else {
            int32_t gen = atomic_load(&gAppVersionCacheGeneration);
            os_unfair_lock_lock(&gAppVersionCacheLock);
            BOOL valid = gNSInfoDictCache && gNSInfoDictGeneration == gen &&
                [gNSInfoDictBundleID isEqualToString:mainBundleID];
            NSDictionary *cached = valid ? gNSInfoDictCache : nil;
            os_unfair_lock_unlock(&gAppVersionCacheLock);
            if (cached) {
                result = cached;
            } else {
                NSDictionary *spoofed = PXApplyAppVersionToInfoDictionary(original, ver, build);
                if (spoofed) {
                    os_unfair_lock_lock(&gAppVersionCacheLock);
                    gNSInfoDictCache = [spoofed copy];
                    gNSInfoDictBundleID = [mainBundleID copy];
                    gNSInfoDictGeneration = gen;
                    result = gNSInfoDictCache;
                    os_unfair_lock_unlock(&gAppVersionCacheLock);
                }
            }
        }
    } @catch (__unused NSException *e) {
        result = original;
    }
    gPXAppVersionInfoRecursion--;
    return result;
}

- (NSDictionary *)localizedInfoDictionary {
    if (PXNativeFilesystemCriticalIsActive()) return %orig;
    if (gPXAppVersionInfoRecursion > 0) {
        return %orig;
    }
    gPXAppVersionInfoRecursion++;
    NSDictionary *original = %orig;
    NSDictionary *result = original;
    @try {
        NSString *mainBundleID = nil;
        NSString *ver = nil;
        NSString *build = nil;
        if (!PXShouldSpoofMainBundleInfo(self, &mainBundleID, &ver, &build)) {
            result = original;
        } else if (!original) {
            result = original; // may legitimately be nil
        } else {
            int32_t gen = atomic_load(&gAppVersionCacheGeneration);
            os_unfair_lock_lock(&gAppVersionCacheLock);
            BOOL valid = gNSLocalizedInfoDictCache && gNSLocalizedInfoDictGeneration == gen &&
                [gNSLocalizedInfoDictBundleID isEqualToString:mainBundleID];
            NSDictionary *cached = valid ? gNSLocalizedInfoDictCache : nil;
            os_unfair_lock_unlock(&gAppVersionCacheLock);
            if (cached) {
                result = cached;
            } else {
                NSDictionary *spoofed = PXApplyAppVersionToInfoDictionary(original, ver, build);
                if (spoofed) {
                    os_unfair_lock_lock(&gAppVersionCacheLock);
                    gNSLocalizedInfoDictCache = [spoofed copy];
                    gNSLocalizedInfoDictBundleID = [mainBundleID copy];
                    gNSLocalizedInfoDictGeneration = gen;
                    result = gNSLocalizedInfoDictCache;
                    os_unfair_lock_unlock(&gAppVersionCacheLock);
                }
            }
        }
    } @catch (__unused NSException *e) {
        result = original;
    }
    gPXAppVersionInfoRecursion--;
    return result;
}

%end

%end // AppVersionFullDictionary

#pragma mark - CFBundle full dictionary hooks

static BOOL PXShouldSpoofCFBundleInfo(CFBundleRef bundle, NSString **outMainBundleID, NSString **outVer, NSString **outBuild) {
    if (!bundle) return NO;
    if (!PXAppVersionScopeAllows()) return NO;

    NSString *mainBundleID = PXMainBundleIDCached();
    if (!mainBundleID.length) return NO;

    // Only main CFBundle. Compare with CFBundleGetMainBundle to avoid CFBundleGetIdentifier
    // (which can refresh info dictionary and re-enter our hook).
    if (bundle != CFBundleGetMainBundle()) {
        NSString *nsBundleID = PXCFBundleIDSafe(bundle);
        if (!nsBundleID.length || ![nsBundleID isEqualToString:mainBundleID]) return NO;
    }

    NSString *ver = nil;
    NSString *build = nil;
    if (!PXGetSpoofedAppVersionForBundle(mainBundleID, &ver, &build)) return NO;
    if (!ver.length && !build.length) return NO;

    if (outMainBundleID) *outMainBundleID = mainBundleID;
    if (outVer) *outVer = ver;
    if (outBuild) *outBuild = build;
    return YES;
}

static CFDictionaryRef PXCachedOrBuildCFInfoDict(CFBundleRef bundle,
                                                 CFDictionaryRef original,
                                                 BOOL localized,
                                                 PXCFInfoDictCacheEntry *cache) {
    if (!original || !cache) return original;

    NSString *mainBundleID = nil;
    NSString *ver = nil;
    NSString *build = nil;
    if (!PXShouldSpoofCFBundleInfo(bundle, &mainBundleID, &ver, &build)) {
        return original;
    }

    int32_t gen = atomic_load(&gAppVersionCacheGeneration);
    os_unfair_lock_lock(&gAppVersionCacheLock);
    BOOL valid = cache->valid && cache->dict && cache->generation == gen &&
        cache->localized == localized && cache->bundleID &&
        CFEqual(cache->bundleID, (__bridge CFStringRef)mainBundleID);
    CFDictionaryRef cached = valid ? cache->dict : NULL;
    os_unfair_lock_unlock(&gAppVersionCacheLock);
    if (cached) return cached;

    NSDictionary *nsOrig = (__bridge NSDictionary *)original;
    NSDictionary *spoofed = PXApplyAppVersionToInfoDictionary(nsOrig, ver, build);
    if (!spoofed) return original;
    CFDictionaryRef retained = CFBridgingRetain(spoofed);
    if (!retained) return original;

    os_unfair_lock_lock(&gAppVersionCacheLock);
    BOOL anotherValid = cache->valid && cache->dict && cache->generation == gen &&
        cache->localized == localized && cache->bundleID &&
        CFEqual(cache->bundleID, (__bridge CFStringRef)mainBundleID);
    if (anotherValid) {
        CFRelease(retained);
    } else {
        PXReleaseCFInfoDictCacheEntry(cache);
        cache->dict = retained;
        cache->bundleID = CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)mainBundleID);
        cache->generation = gen;
        cache->localized = localized;
        cache->valid = YES;
    }
    CFDictionaryRef published = cache->dict;
    os_unfair_lock_unlock(&gAppVersionCacheLock);
    return published;

}

static CFDictionaryRef replaced_CFBundleGetInfoDictionary(CFBundleRef bundle) {
    if (PXNativeFilesystemCriticalIsActive()) {
        return original_CFBundleGetInfoDictionary ? original_CFBundleGetInfoDictionary(bundle) : NULL;
    }
    if (gPXAppVersionInfoRecursion > 0) {
        return original_CFBundleGetInfoDictionary ? original_CFBundleGetInfoDictionary(bundle) : NULL;
    }
    gPXAppVersionInfoRecursion++;
    CFDictionaryRef original = NULL;
    if (original_CFBundleGetInfoDictionary) {
        original = original_CFBundleGetInfoDictionary(bundle);
    }
    CFDictionaryRef result = original;
    @try {
        result = PXCachedOrBuildCFInfoDict(bundle, original, NO, &gCFInfoDictCache);
    } @catch (__unused NSException *e) {
        result = original;
    }
    gPXAppVersionInfoRecursion--;
    return result;
}

static CFDictionaryRef replaced_CFBundleGetLocalInfoDictionary(CFBundleRef bundle) {
    if (PXNativeFilesystemCriticalIsActive()) {
        return original_CFBundleGetLocalInfoDictionary ? original_CFBundleGetLocalInfoDictionary(bundle) : NULL;
    }
    if (gPXAppVersionInfoRecursion > 0) {
        return original_CFBundleGetLocalInfoDictionary ? original_CFBundleGetLocalInfoDictionary(bundle) : NULL;
    }
    gPXAppVersionInfoRecursion++;
    CFDictionaryRef original = NULL;
    if (original_CFBundleGetLocalInfoDictionary) {
        original = original_CFBundleGetLocalInfoDictionary(bundle);
    }
    CFDictionaryRef result = original;
    @try {
        // Local info dict may be NULL — pass through.
        if (original) {
            result = PXCachedOrBuildCFInfoDict(bundle, original, YES, &gCFLocalInfoDictCache);
        }
    } @catch (__unused NSException *e) {
        result = original;
    }
    gPXAppVersionInfoRecursion--;
    return result;
}

static void *PXFindCFSymbol(void *handle, const char *names[], int count) {
    if (!handle) return NULL;
    for (int i = 0; i < count; i++) {
        void *sym = dlsym(handle, names[i]);
        if (sym) return sym;
    }
    return NULL;
}

static void PXAppVersionCacheInvalidateNotification(CFNotificationCenterRef center,
                                                    void *observer,
                                                    CFStringRef name,
                                                    const void *object,
                                                    CFDictionaryRef userInfo) {
    PXAppVersionHooksInvalidateCache();
}

%dtor {
    PXAppVersionHooksInvalidateCache();
}

%ctor {
    @autoreleasepool {
        PXFileDebugAIDA64Log("[AppVersion.ctor] enter");
        // Capture main bundle ID BEFORE installing hooks — prevents
        // infoDictionary ↔ bundleIdentifier recursion under spoof paths.
        gMainBundleIDCached = [[[NSBundle mainBundle] bundleIdentifier] copy];
        NSString *bundleID = gMainBundleIDCached;
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (!PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionNone)) {
            PXFileDebugAIDA64Log("[AppVersion.ctor] skip scope bundle=%s proc=%s",
                                 bundleID.UTF8String ?: "<nil>",
                                 proc.UTF8String ?: "<nil>");
            return;
        }

        %init(AppVersionFullDictionary);

        // Invalidate on settings / profile / mapping changes
        CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
        CFNotificationCenterAddObserver(darwin, NULL, PXAppVersionCacheInvalidateNotification,
                                        CFSTR("com.hydra.tlinkios.settings.changed"), NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwin, NULL, PXAppVersionCacheInvalidateNotification,
                                        CFSTR("com.hydra.tlinkios.profileChanged"), NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwin, NULL, PXAppVersionCacheInvalidateNotification,
                                        CFSTR("com.hydra.tlinkios.scopedAppsChanged"), NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwin, NULL, PXAppVersionCacheInvalidateNotification,
                                        CFSTR("com.hydra.tlinkios.appVersionSpoofChanged"), NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        void *cf = dlopen("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", RTLD_NOW);
        if (cf) {
            const char *infoNames[] = {
                "CFBundleGetInfoDictionary",
                "_CFBundleGetInfoDictionary",
                "__CFBundleGetInfoDictionary"
            };
            const char *localNames[] = {
                "CFBundleGetLocalInfoDictionary",
                "_CFBundleGetLocalInfoDictionary",
                "__CFBundleGetLocalInfoDictionary"
            };

            void *infoPtr = PXFindCFSymbol(cf, infoNames, 3);
            if (infoPtr) {
                PXFileDebugAIDA64Log("[AppVersion.ctor] before hook CFBundleGetInfoDictionary");
                MSHookFunction(infoPtr, (void *)replaced_CFBundleGetInfoDictionary,
                               (void **)&original_CFBundleGetInfoDictionary);
                PXFileDebugAIDA64Log("[AppVersion.ctor] after hook CFBundleGetInfoDictionary");
            }

            void *localPtr = PXFindCFSymbol(cf, localNames, 3);
            if (localPtr) {
                PXFileDebugAIDA64Log("[AppVersion.ctor] before hook CFBundleGetLocalInfoDictionary");
                MSHookFunction(localPtr, (void *)replaced_CFBundleGetLocalInfoDictionary,
                               (void **)&original_CFBundleGetLocalInfoDictionary);
                PXFileDebugAIDA64Log("[AppVersion.ctor] after hook CFBundleGetLocalInfoDictionary");
            }
        }

        PXFileDebugAIDA64Log("[AppVersion.ctor] exit");
    }
}
