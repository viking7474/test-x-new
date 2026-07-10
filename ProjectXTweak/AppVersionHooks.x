// AppVersionHooks.x
// App-version spoof helpers + full Info.plist dictionary access paths.

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <substrate.h>
#import <dlfcn.h>
#import <stdatomic.h>

#import "AppVersionHooks.h"
#import "PXScope.h"
#import "PXFileDebug.h"

static NSString *const kSecuritySettingsPlist1 = @"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist";
static NSString *const kSecuritySettingsPlist2 = @"/private/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist";

static NSString *const kVersionSpoofPlist1 = @"/var/mobile/Library/Preferences/com.hydra.projectx.version_spoof.plist";
static NSString *const kVersionSpoofPlist2 = @"/private/var/mobile/Library/Preferences/com.hydra.projectx.version_spoof.plist";

static NSString *const kProfilesBase1 = @"/var/mobile/Library/WeaponX/Profiles";
static NSString *const kProfilesBase2 = @"/private/var/mobile/Library/WeaponX/Profiles";

static NSDictionary *gCachedVersionSpoofPlist = nil;
static NSDate *gCachedVersionSpoofMTime = nil;
static NSString *gCachedVersionSpoofPath = nil;

static NSMutableDictionary<NSString *, NSDictionary *> *gCachedProfileVersionPlists = nil;
static NSMutableDictionary<NSString *, NSDate *> *gCachedProfileVersionMTime = nil;

// Full-dictionary CF cache: stable retained CFDictionary per (bundleID + localized + generation)
static _Atomic int32_t gAppVersionCacheGeneration = 0;

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

static NSDate *PXFileMTime(NSString *path) {
    if (!path.length) return nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    return [attrs isKindOfClass:[NSDictionary class]] ? attrs[NSFileModificationDate] : nil;
}

static NSDictionary *PXReadPlist(NSString *path) {
    if (!path.length) return nil;
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:path];
    return [d isKindOfClass:[NSDictionary class]] ? d : nil;
}

static NSString *PXResolveExistingPath(NSArray<NSString *> *candidates) {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *p in candidates) {
        if (p.length && [fm fileExistsAtPath:p]) {
            return p;
        }
    }
    return candidates.firstObject;
}

BOOL PXAppVersionSpoofMasterEnabled(void) {
    NSDictionary *s = PXReadPlist(PXResolveExistingPath(@[kSecuritySettingsPlist1, kSecuritySettingsPlist2]));
    return [s[@"appVersionSpoofingEnabled"] boolValue];
}

static NSDictionary *PXLoadVersionSpoofPlistCached(void) {
    NSString *path = PXResolveExistingPath(@[kVersionSpoofPlist1, kVersionSpoofPlist2]);
    NSDate *mtime = PXFileMTime(path);

    if (gCachedVersionSpoofPlist && gCachedVersionSpoofMTime && [path isEqualToString:gCachedVersionSpoofPath]) {
        if ((!mtime && !gCachedVersionSpoofMTime) || (mtime && [mtime isEqualToDate:gCachedVersionSpoofMTime])) {
            return gCachedVersionSpoofPlist;
        }
    }

    NSDictionary *d = PXReadPlist(path);
    gCachedVersionSpoofPlist = d;
    gCachedVersionSpoofMTime = mtime;
    gCachedVersionSpoofPath = path;
    return d;
}

static NSString *PXReadActiveProfileId(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *bases = @[kProfilesBase1, kProfilesBase2];
    for (NSString *base in bases) {
        if (![fm fileExistsAtPath:base]) continue;
        NSString *p = [base stringByAppendingPathComponent:@"current_profile_info.plist"];
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:p];
        NSString *pid = [info[@"ProfileId"] isKindOfClass:[NSString class]] ? info[@"ProfileId"] : nil;
        if (pid.length) return pid;
    }

    // Legacy file (outside Profiles directory)
    NSDictionary *legacy1 = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/WeaponX/active_profile_info.plist"];
    NSString *pid2 = [legacy1[@"ProfileId"] isKindOfClass:[NSString class]] ? legacy1[@"ProfileId"] : nil;
    if (pid2.length) return pid2;

    NSDictionary *legacy2 = [NSDictionary dictionaryWithContentsOfFile:@"/private/var/mobile/Library/WeaponX/active_profile_info.plist"];
    NSString *pid3 = [legacy2[@"ProfileId"] isKindOfClass:[NSString class]] ? legacy2[@"ProfileId"] : nil;
    return pid3.length ? pid3 : nil;
}

static NSString *PXSafeBundleFilename(NSString *bundleID) {
    if (!bundleID.length) return nil;
    NSString *safe = [bundleID stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    return [safe stringByAppendingString:@"_version.plist"];
}

static NSDictionary *PXLoadProfileAppVersionPlist(NSString *bundleID) {
    if (!bundleID.length) return nil;

    if (!gCachedProfileVersionPlists) {
        gCachedProfileVersionPlists = [NSMutableDictionary dictionary];
        gCachedProfileVersionMTime = [NSMutableDictionary dictionary];
    }

    NSString *profileId = PXReadActiveProfileId();
    if (!profileId.length) return nil;

    NSString *fileName = PXSafeBundleFilename(bundleID);
    if (!fileName.length) return nil;

    NSArray *bases = @[kProfilesBase1, kProfilesBase2];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *foundPath = nil;
    for (NSString *base in bases) {
        if (![fm fileExistsAtPath:base]) continue;
        NSString *p = [[base stringByAppendingPathComponent:profileId] stringByAppendingPathComponent:@"app_versions"];
        p = [p stringByAppendingPathComponent:fileName];
        if ([fm fileExistsAtPath:p]) {
            foundPath = p;
            break;
        }
    }
    if (!foundPath.length) return nil;

    NSDate *mtime = PXFileMTime(foundPath);
    NSDictionary *cached = gCachedProfileVersionPlists[foundPath];
    NSDate *cachedMTime = gCachedProfileVersionMTime[foundPath];
    if (cached && cachedMTime && mtime && [cachedMTime isEqualToDate:mtime]) {
        return cached;
    }

    NSDictionary *d = PXReadPlist(foundPath);
    if (d) {
        gCachedProfileVersionPlists[foundPath] = d;
        if (mtime) gCachedProfileVersionMTime[foundPath] = mtime;
    }
    return d;
}

BOOL PXGetSpoofedAppVersionForBundle(NSString *bundleID, NSString **outVersion, NSString **outBuild) {
    if (outVersion) *outVersion = nil;
    if (outBuild) *outBuild = nil;
    if (!bundleID.length) return NO;

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
    gCachedVersionSpoofPlist = nil;
    gCachedVersionSpoofMTime = nil;
    gCachedVersionSpoofPath = nil;
    [gCachedProfileVersionPlists removeAllObjects];
    [gCachedProfileVersionMTime removeAllObjects];

    // Bump generation so any live full-dict cache is considered stale.
    atomic_fetch_add(&gAppVersionCacheGeneration, 1);

    PXReleaseCFInfoDictCacheEntry(&gCFInfoDictCache);
    PXReleaseCFInfoDictCacheEntry(&gCFLocalInfoDictCache);
    gNSInfoDictCache = nil;
    gNSInfoDictBundleID = nil;
    gNSInfoDictGeneration = -1;
    gNSLocalizedInfoDictCache = nil;
    gNSLocalizedInfoDictBundleID = nil;
    gNSLocalizedInfoDictGeneration = -1;
}

#pragma mark - Full dictionary helpers

static BOOL PXAppVersionScopeAllows(void) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString *proc = [NSProcessInfo processInfo].processName;
    return PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionNone);
}

static NSDictionary *PXApplyAppVersionToInfoDictionary(NSDictionary *original, NSString *ver, NSString *build) {
    if (![original isKindOfClass:[NSDictionary class]]) return original;
    NSMutableDictionary *mutable = [original mutableCopy];
    if (!mutable) return original;
    if (ver.length) {
        mutable[@"CFBundleShortVersionString"] = ver;
    }
    if (build.length) {
        mutable[@"CFBundleVersion"] = build;
    }
    // Immutable copy — never mutate the system dictionary in place.
    return [mutable copy];
}

static BOOL PXShouldSpoofMainBundleInfo(NSBundle *bundle, NSString **outMainBundleID, NSString **outVer, NSString **outBuild) {
    if (!bundle) return NO;
    if (!PXAppVersionScopeAllows()) return NO;

    NSString *mainBundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!mainBundleID.length) return NO;

    NSString *bundleID = [bundle bundleIdentifier];
    if (!bundleID.length || ![bundleID isEqualToString:mainBundleID]) return NO;

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
    NSDictionary *original = %orig;
    @try {
        NSString *mainBundleID = nil;
        NSString *ver = nil;
        NSString *build = nil;
        if (!PXShouldSpoofMainBundleInfo(self, &mainBundleID, &ver, &build)) {
            return original;
        }

        int32_t gen = atomic_load(&gAppVersionCacheGeneration);
        if (gNSInfoDictCache &&
            gNSInfoDictGeneration == gen &&
            gNSInfoDictBundleID &&
            [gNSInfoDictBundleID isEqualToString:mainBundleID]) {
            return gNSInfoDictCache;
        }

        NSDictionary *spoofed = PXApplyAppVersionToInfoDictionary(original, ver, build);
        if (spoofed) {
            gNSInfoDictCache = spoofed;
            gNSInfoDictBundleID = [mainBundleID copy];
            gNSInfoDictGeneration = gen;
            return spoofed;
        }
    } @catch (__unused NSException *e) {
    }
    return original;
}

- (NSDictionary *)localizedInfoDictionary {
    NSDictionary *original = %orig;
    @try {
        NSString *mainBundleID = nil;
        NSString *ver = nil;
        NSString *build = nil;
        if (!PXShouldSpoofMainBundleInfo(self, &mainBundleID, &ver, &build)) {
            return original;
        }
        // localizedInfoDictionary may legitimately be nil — leave it alone.
        if (!original) return original;

        int32_t gen = atomic_load(&gAppVersionCacheGeneration);
        if (gNSLocalizedInfoDictCache &&
            gNSLocalizedInfoDictGeneration == gen &&
            gNSLocalizedInfoDictBundleID &&
            [gNSLocalizedInfoDictBundleID isEqualToString:mainBundleID]) {
            return gNSLocalizedInfoDictCache;
        }

        NSDictionary *spoofed = PXApplyAppVersionToInfoDictionary(original, ver, build);
        if (spoofed) {
            gNSLocalizedInfoDictCache = spoofed;
            gNSLocalizedInfoDictBundleID = [mainBundleID copy];
            gNSLocalizedInfoDictGeneration = gen;
            return spoofed;
        }
    } @catch (__unused NSException *e) {
    }
    return original;
}

%end

%end // AppVersionFullDictionary

#pragma mark - CFBundle full dictionary hooks

static CFDictionaryRef (*original_CFBundleGetInfoDictionary)(CFBundleRef bundle) = NULL;
static CFDictionaryRef (*original_CFBundleGetLocalInfoDictionary)(CFBundleRef bundle) = NULL;

static BOOL PXShouldSpoofCFBundleInfo(CFBundleRef bundle, NSString **outMainBundleID, NSString **outVer, NSString **outBuild) {
    if (!bundle) return NO;
    if (!PXAppVersionScopeAllows()) return NO;

    CFStringRef cfID = CFBundleGetIdentifier(bundle);
    if (!cfID) return NO;
    NSString *nsBundleID = (__bridge NSString *)cfID;

    NSString *mainBundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!mainBundleID.length || ![nsBundleID isEqualToString:mainBundleID]) return NO;

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
    if (cache->valid &&
        cache->dict &&
        cache->generation == gen &&
        cache->localized == localized &&
        cache->bundleID &&
        CFEqual(cache->bundleID, (__bridge CFStringRef)mainBundleID)) {
        return cache->dict;
    }

    NSDictionary *nsOrig = (__bridge NSDictionary *)original;
    NSDictionary *spoofed = PXApplyAppVersionToInfoDictionary(nsOrig, ver, build);
    if (!spoofed) return original;

    // Retained cache — CF Get APIs do not transfer ownership to the caller.
    CFDictionaryRef retained = CFBridgingRetain(spoofed);
    if (!retained) return original;

    PXReleaseCFInfoDictCacheEntry(cache);
    cache->dict = retained;
    cache->bundleID = CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)mainBundleID);
    cache->generation = gen;
    cache->localized = localized;
    cache->valid = YES;
    return cache->dict;
}

static CFDictionaryRef replaced_CFBundleGetInfoDictionary(CFBundleRef bundle) {
    CFDictionaryRef original = NULL;
    if (original_CFBundleGetInfoDictionary) {
        original = original_CFBundleGetInfoDictionary(bundle);
    }
    @try {
        return PXCachedOrBuildCFInfoDict(bundle, original, NO, &gCFInfoDictCache);
    } @catch (__unused NSException *e) {
        return original;
    }
}

static CFDictionaryRef replaced_CFBundleGetLocalInfoDictionary(CFBundleRef bundle) {
    CFDictionaryRef original = NULL;
    if (original_CFBundleGetLocalInfoDictionary) {
        original = original_CFBundleGetLocalInfoDictionary(bundle);
    }
    @try {
        // Local info dict may be NULL — pass through.
        if (!original) return original;
        return PXCachedOrBuildCFInfoDict(bundle, original, YES, &gCFLocalInfoDictCache);
    } @catch (__unused NSException *e) {
        return original;
    }
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
    PXReleaseCFInfoDictCacheEntry(&gCFInfoDictCache);
    PXReleaseCFInfoDictCacheEntry(&gCFLocalInfoDictCache);
}

%ctor {
    @autoreleasepool {
        PXFileDebugAIDA64Log("[AppVersion.ctor] enter");
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
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
                                        CFSTR("com.hydra.projectx.settings.changed"), NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwin, NULL, PXAppVersionCacheInvalidateNotification,
                                        CFSTR("com.hydra.projectx.profileChanged"), NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwin, NULL, PXAppVersionCacheInvalidateNotification,
                                        CFSTR("com.hydra.projectx.appVersionSpoofChanged"), NULL,
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
