// App-version source/projection caches and borrowed CF result ownership.
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <substrate.h>
#import <dlfcn.h>
#import "AppVersionHooks.h"
#import "PXScope.h"
#import "PXPaths.h"
#import "PXFileDebug.h"
#import "PXP1BFilters.h"
#import <os/lock.h>

static os_unfair_lock gAppVersionCacheLock = OS_UNFAIR_LOCK_INIT;
// Immutable packet: unique epoch, path -> plist/mtime, localized -> projection.
static NSDictionary *gAppVersionState;
// Get results have no release/eviction signal. Keep every distinct returned value
// process-owned across invalidation; never borrow from a reclaimable cache slot.
static NSArray<NSDictionary *> *gAppVersionBorrowedDictionaries;
static __thread int gPXAppVersionInfoRecursion;
static __thread BOOL gPXAppVersionReading, gPXAppVersionMasterReading, gPXAppVersionInterning;
static NSString *gMainBundleIDCached;
static CFDictionaryRef (*original_CFBundleGetInfoDictionary)(CFBundleRef bundle) = NULL;
static CFDictionaryRef (*original_CFBundleGetLocalInfoDictionary)(CFBundleRef bundle) = NULL;

static BOOL PXAppVersionPublish(NSDictionary *basis, NSDictionary *candidate) {
    __attribute__((objc_precise_lifetime)) NSDictionary *retired = nil;
    BOOL published = NO;
    @try {
        os_unfair_lock_lock(&gAppVersionCacheLock);
        @try { if (gAppVersionState == basis) { retired = gAppVersionState;gAppVersionState = candidate;published = YES; } }
        @finally { os_unfair_lock_unlock(&gAppVersionCacheLock); }
        return published;
    } @finally { basis = nil;candidate = nil;retired = nil; }
}
static NSDictionary *PXAppVersionCapture(void) {
    NSDictionary *state = nil, *initial = nil;
    @try {
        for (;;) {
            os_unfair_lock_lock(&gAppVersionCacheLock);
            @try { state = gAppVersionState; } @finally { os_unfair_lock_unlock(&gAppVersionCacheLock); }
            if (state) return state;
            initial = @{@"epoch":[NSObject new],@"files":@{},@"projections":@{}};
            if (PXAppVersionPublish(nil,initial)) return initial;
            initial = nil;
        }
    } @finally { state = nil;initial = nil; }
}
static BOOL PXAppVersionEpochCurrent(id epoch) {
    NSDictionary *state = nil;@try { state = PXAppVersionCapture();return state[@"epoch"] == epoch; } @finally { state = nil;epoch = nil; }
}
static BOOL PXAppVersionStore(id epoch, NSString *section, id key, NSDictionary *entry) {
    NSDictionary *basis = nil, *candidate = nil;
    NSMutableDictionary *items = nil, *working = nil;
    @try {
        for (;;) {
            basis = PXAppVersionCapture();if (basis[@"epoch"] != epoch) return NO;
            items = [basis[section] mutableCopy];items[key] = entry;working = [basis mutableCopy];working[section] = [items copy];candidate = [working copy];
            if (PXAppVersionPublish(basis,candidate)) return YES;
            basis = nil;candidate = nil;items = nil;working = nil;
        }
    } @finally { epoch = nil;section = nil;key = nil;entry = nil;basis = nil;candidate = nil;items = nil;working = nil; }
}
static NSString *PXVersionSpoofPlistPath(void) { NSString *root = nil;@try { root = PXPreferencesPath();return [root stringByAppendingPathComponent:@"com.hydra.tlinkios.version_spoof.plist"]; } @finally { root = nil; } }
static NSDate *PXFileMTime(NSString *path) {
    NSFileManager *files = nil;NSDictionary *attributes = nil;id date = nil;
    @try { if (!path.length) return nil;files = [NSFileManager defaultManager];attributes = [files attributesOfItemAtPath:path error:NULL];date = attributes[NSFileModificationDate];return [date isKindOfClass:NSDate.class] ? date : nil; }
    @finally { path = nil;files = nil;attributes = nil;date = nil; }
}
static NSDictionary *PXReadPlist(NSString *path) {
    NSDictionary *plist = nil;@try { if (!path.length) return nil;plist = [NSDictionary dictionaryWithContentsOfFile:path];return [plist isKindOfClass:NSDictionary.class] ? plist : nil; }
    @finally { path = nil;plist = nil; }
}
static BOOL PXAppVersionScalar(id value) { @try { return [value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class]; } @finally { value = nil; } }
BOOL PXAppVersionSpoofMasterEnabled(void) {
    NSDictionary *settings = nil;id flag = nil;BOOL previous = gPXAppVersionMasterReading;
    @try { if (previous) return NO;gPXAppVersionMasterReading = YES;settings = PXReadPlist(PXSecuritySettingsPath());flag = settings[@"appVersionSpoofingEnabled"];return PXAppVersionScalar(flag) && [flag boolValue]; }
    @catch (__unused NSException *exception) { return NO; }
    @finally { settings = nil;flag = nil;gPXAppVersionMasterReading = previous; }
}
static NSDictionary *PXAppVersionLoadPath(NSString *path, id epoch) {
    NSDictionary *state = nil, *entry = nil, *loaded = nil, *candidate = nil;
    NSDate *before = nil, *after = nil, *saved = nil;
    @try {
        if (!path.length) return nil;before = PXFileMTime(path);state = PXAppVersionCapture();if (state[@"epoch"] != epoch) return nil;
        entry = state[@"files"][path];saved = entry[@"mtime"];
        if (before && saved && [before isEqualToDate:saved]) return entry[@"plist"];
        loaded = PXReadPlist(path);if (!loaded) return nil;after = PXFileMTime(path);
        if (!PXAppVersionEpochCurrent(epoch)) return nil;
        if (before && after && [before isEqualToDate:after]) {
            candidate = @{@"mtime":after,@"plist":[loaded copy]};
            if (!PXAppVersionStore(epoch,@"files",path,candidate)) return nil;
        }
        // No reliable metadata: use this read only, never memoize a nil timestamp.
        return loaded;
    } @finally { path = nil;epoch = nil;state = nil;entry = nil;loaded = nil;candidate = nil;before = nil;after = nil;saved = nil; }
}
static NSDictionary *PXLoadVersionSpoofPlistCached(id epoch) {
    NSString *path = nil;@try { path = PXVersionSpoofPlistPath();return PXAppVersionLoadPath(path,epoch); } @finally { path = nil;epoch = nil; }
}
static NSDictionary *PXLoadProfileAppVersionPlist(NSString *bundleID, id epoch) {
    NSString *profile = nil, *root = nil, *name = nil, *directory = nil, *path = nil;
    @try {
        if (!bundleID.length) return nil;profile = PXActiveProfileID();root = PXProfileRootPath(profile);name = PXAppVersionSafeBundleFilename(bundleID);
        if (!root.length || !name.length) return nil;directory = [root stringByAppendingPathComponent:@"app_versions"];path = [directory stringByAppendingPathComponent:name];
        return PXAppVersionLoadPath(path,epoch);
    } @finally { bundleID = nil;epoch = nil;profile = nil;root = nil;name = nil;directory = nil;path = nil; }
}
BOOL PXGetSpoofedAppVersionForBundle(NSString *bundleID, NSString **outVersion, NSString **outBuild) {
    NSDictionary *state = nil, *global = nil, *versions = nil, *entry = nil, *profile = nil;
    NSString *identity = nil, *version = nil, *build = nil;id flag = nil, field = nil, epoch = nil;
    BOOL previous = gPXAppVersionReading;
    if (outVersion) *outVersion = nil;if (outBuild) *outBuild = nil;
    @try {
        if (previous) return NO;gPXAppVersionReading = YES;
        if (![bundleID isKindOfClass:NSString.class] || !bundleID.length) return NO;
        identity = [[NSString alloc] initWithString:bundleID];state = PXAppVersionCapture();epoch = state[@"epoch"];
        if (!PXAppVersionSpoofMasterEnabled()) return NO;
        global = PXLoadVersionSpoofPlistCached(epoch);versions = global[@"SpoofedVersions"];
        if (![versions isKindOfClass:NSDictionary.class]) return NO;entry = versions[identity];if (![entry isKindOfClass:NSDictionary.class]) return NO;
        flag = entry[@"spoofingEnabled"];if (!PXAppVersionScalar(flag) || ![flag boolValue]) return NO;
        version = entry[@"spoofedVersion"];build = entry[@"spoofedBuild"];
        if (![version isKindOfClass:NSString.class]) version = nil;if (![build isKindOfClass:NSString.class]) build = nil;
        if (!version.length || !build.length) {
            profile = PXLoadProfileAppVersionPlist(identity,epoch);
            if (!version.length) { field = profile[@"spoofedVersion"];if ([field isKindOfClass:NSString.class]) version = field; }
            if (!build.length) { field = profile[@"spoofedBuild"];if ([field isKindOfClass:NSString.class]) build = field; }
        }
        if (!version.length && !build.length) return NO;
        version = version.length ? [[NSString alloc] initWithString:version] : nil;build = build.length ? [[NSString alloc] initWithString:build] : nil;
        if (!PXAppVersionEpochCurrent(epoch)) return NO;
        if (outVersion) *outVersion = version;if (outBuild) *outBuild = build;return YES;
    } @catch (__unused NSException *exception) { return NO; }
    @finally { bundleID = nil;state = nil;global = nil;versions = nil;entry = nil;profile = nil;identity = nil;version = nil;build = nil;flag = nil;field = nil;epoch = nil;gPXAppVersionReading = previous; }
}
void PXAppVersionHooksInvalidateCache(void) {
    NSDictionary *basis = nil, *candidate = nil;
    @try {
        candidate = @{@"epoch":[NSObject new],@"files":@{},@"projections":@{}};
        do { basis = PXAppVersionCapture(); } while (!PXAppVersionPublish(basis,candidate));
    } @finally { basis = nil;candidate = nil; }
    PXInvalidateScopeDecisionCache();
}
static NSString *PXMainBundleIDCached(void) {
    NSString *identity = nil, *candidate = nil;id value = nil;CFDictionaryRef info = NULL;
    @try {
        os_unfair_lock_lock(&gAppVersionCacheLock);
        @try { identity = gMainBundleIDCached; } @finally { os_unfair_lock_unlock(&gAppVersionCacheLock); }
        if (identity.length) return identity;
        if (original_CFBundleGetInfoDictionary) {
            CFBundleRef main = CFBundleGetMainBundle();if (main) info = original_CFBundleGetInfoDictionary(main);if (info) CFRetain(info);
            value = info ? (__bridge id)CFDictionaryGetValue(info,kCFBundleIdentifierKey) : nil;
            if ([value isKindOfClass:NSString.class]) candidate = [[NSString alloc] initWithString:value];
        }
        if (!candidate.length) return nil;
        os_unfair_lock_lock(&gAppVersionCacheLock);
        @try { if (!gMainBundleIDCached) gMainBundleIDCached = candidate;identity = gMainBundleIDCached; }
        @finally { os_unfair_lock_unlock(&gAppVersionCacheLock); }
        return identity;
    } @finally { if (info) CFRelease(info);identity = nil;candidate = nil;value = nil; }
}
static NSString *PXCFBundleIDSafe(CFBundleRef bundle) {
    CFDictionaryRef info = NULL;NSString *identity = nil;id value = nil;
    @try {
        if (!bundle) return nil;
        if (gPXAppVersionInfoRecursion == 0) { CFStringRef value = CFBundleGetIdentifier(bundle);if (value) return [[NSString alloc] initWithString:(__bridge NSString *)value]; }
        if (original_CFBundleGetInfoDictionary) info = original_CFBundleGetInfoDictionary(bundle);if (info) CFRetain(info);
        value = info ? (__bridge id)CFDictionaryGetValue(info,kCFBundleIdentifierKey) : nil;
        if ([value isKindOfClass:NSString.class]) identity = [[NSString alloc] initWithString:value];return identity;
    } @finally { if (info) CFRelease(info);identity = nil;value = nil; }
}
static BOOL PXAppVersionScopeAllows(void) {
    NSString *bundleID = nil, *process = nil;NSProcessInfo *info = nil;
    @try { bundleID = PXMainBundleIDCached();if (!bundleID.length) return NO;info = [NSProcessInfo processInfo];process = info.processName;return PXProcessIsAllowedForSpoofing(bundleID,process,PXScopeOptionNone); }
    @finally { bundleID = nil;process = nil;info = nil; }
}
static BOOL PXShouldSpoofMainBundleInfo(NSBundle *bundle, NSString **outMainBundleID, NSString **outVer, NSString **outBuild) {
    NSString *identity = nil;NSString *__autoreleasing version = nil, *build = nil;
    @try {
        if (!bundle || bundle != [NSBundle mainBundle] || !PXAppVersionScopeAllows()) return NO;
        identity = PXMainBundleIDCached();if (!identity.length || !PXGetSpoofedAppVersionForBundle(identity,&version,&build)) return NO;
        if (outMainBundleID) *outMainBundleID = identity;if (outVer) *outVer = version;if (outBuild) *outBuild = build;return YES;
    } @finally { bundle = nil;identity = nil; }
}
static BOOL PXShouldSpoofCFBundleInfo(CFBundleRef bundle, NSString **outMainBundleID, NSString **outVer, NSString **outBuild) {
    NSString *identity = nil, *bundleID = nil;NSString *__autoreleasing version = nil, *build = nil;
    @try {
        if (!bundle || !PXAppVersionScopeAllows()) return NO;identity = PXMainBundleIDCached();if (!identity.length) return NO;
        if (bundle != CFBundleGetMainBundle()) { bundleID = PXCFBundleIDSafe(bundle);if (!bundleID.length || ![bundleID isEqualToString:identity]) return NO; }
        if (!PXGetSpoofedAppVersionForBundle(identity,&version,&build)) return NO;
        if (outMainBundleID) *outMainBundleID = identity;if (outVer) *outVer = version;if (outBuild) *outBuild = build;return YES;
    } @finally { identity = nil;bundleID = nil; }
}
static NSDictionary *PXInternAppVersionDictionary(NSDictionary *value) {
    NSArray *basis = nil, *candidate = nil;NSMutableArray *working = nil;NSDictionary *frozen = nil, *stored = nil;
    __attribute__((objc_precise_lifetime)) NSArray *retired = nil;
    BOOL previous = gPXAppVersionInterning;
    @try {
        if (previous) return nil;gPXAppVersionInterning = YES;frozen = [value copy];if (!frozen) return nil;
        for (;;) {
            os_unfair_lock_lock(&gAppVersionCacheLock);
            @try { basis = gAppVersionBorrowedDictionaries; } @finally { os_unfair_lock_unlock(&gAppVersionCacheLock); }
            for (NSUInteger i = 0; i < basis.count; i++) { stored = basis[i];if (stored == frozen || [stored isEqualToDictionary:frozen]) return stored; }
            working = basis ? [basis mutableCopy] : [NSMutableArray array];[working addObject:frozen];candidate = [working copy];
            BOOL published = NO;
            os_unfair_lock_lock(&gAppVersionCacheLock);
            @try { if (gAppVersionBorrowedDictionaries == basis) { retired = gAppVersionBorrowedDictionaries;gAppVersionBorrowedDictionaries = candidate;published = YES; } }
            @finally { os_unfair_lock_unlock(&gAppVersionCacheLock); }
            retired = nil;if (published) return frozen;basis = nil;candidate = nil;working = nil;stored = nil;
        }
    } @finally { value = nil;basis = nil;candidate = nil;working = nil;frozen = nil;stored = nil;retired = nil;gPXAppVersionInterning = previous; }
}
static NSDictionary *PXAppVersionProjectInfo(NSBundle *bundle, CFBundleRef cfBundle, NSDictionary *original, BOOL localized, BOOL cf) {
    NSDictionary *state = nil, *cached = nil, *candidate = nil, *result = nil;id epoch = nil;
    NSString *__autoreleasing identity = nil, *version = nil, *build = nil;
    @try {
        if (![original isKindOfClass:NSDictionary.class]) return original;state = PXAppVersionCapture();epoch = state[@"epoch"];
        BOOL allowed = cf ? PXShouldSpoofCFBundleInfo(cfBundle,&identity,&version,&build) : PXShouldSpoofMainBundleInfo(bundle,&identity,&version,&build);
        if (!allowed || !PXAppVersionEpochCurrent(epoch)) return original;
        cached = state[@"projections"][@(localized)];
        if ([cached[@"bundle"] isEqualToString:identity] && [cached[@"version"] isEqualToString:version ?: @""] && [cached[@"build"] isEqualToString:build ?: @""] && [cached[@"base"] isEqualToDictionary:original]) result = cached[@"result"];
        else {
            result = PXAppVersionApplyToInfoDictionary(original,version,build);if (![result isKindOfClass:NSDictionary.class]) return original;
            candidate = @{@"bundle":identity,@"version":version ?: @"",@"build":build ?: @"",@"base":[original copy],@"result":result};
            if (!PXAppVersionStore(epoch,@"projections",@(localized),candidate)) return original;
        }
        if (cf) { result = PXInternAppVersionDictionary(result);if (!result) return original; }
        return PXAppVersionEpochCurrent(epoch) ? result : original;
    } @finally { bundle = nil;original = nil;state = nil;cached = nil;candidate = nil;result = nil;epoch = nil; }
}

%group AppVersionFullDictionary
%hook NSBundle
- (NSDictionary *)infoDictionary {
    __attribute__((objc_precise_lifetime)) NSBundle *receiver = self;
    NSDictionary *original = nil, *result = nil;BOOL entered = NO;
    @try {
        if (gPXAppVersionInfoRecursion > 0) return %orig;
        gPXAppVersionInfoRecursion++;entered = YES;
        original = %orig;result = original;
        @try { result = PXAppVersionProjectInfo(receiver,NULL,original,NO,NO); }
        @catch (__unused NSException *exception) { result = original; }
        return result;
    } @finally { if (entered) gPXAppVersionInfoRecursion--;receiver = nil;original = nil;result = nil; }
}
- (NSDictionary *)localizedInfoDictionary {
    __attribute__((objc_precise_lifetime)) NSBundle *receiver = self;
    NSDictionary *original = nil, *result = nil;BOOL entered = NO;
    @try {
        if (gPXAppVersionInfoRecursion > 0) return %orig;
        gPXAppVersionInfoRecursion++;entered = YES;
        original = %orig;result = original;
        @try { result = PXAppVersionProjectInfo(receiver,NULL,original,YES,NO); }
        @catch (__unused NSException *exception) { result = original; }
        return result;
    } @finally { if (entered) gPXAppVersionInfoRecursion--;receiver = nil;original = nil;result = nil; }
}
%end
%end
static CFDictionaryRef replaced_CFBundleGetInfoDictionary(CFBundleRef bundle) {
    CFDictionaryRef original = NULL, result = NULL;BOOL entered = NO, retainedBundle = NO, retainedOriginal = NO;
    @try {
        if (gPXAppVersionInfoRecursion > 0) return original_CFBundleGetInfoDictionary ? original_CFBundleGetInfoDictionary(bundle) : NULL;
        gPXAppVersionInfoRecursion++;entered = YES;
        if (bundle) { CFRetain(bundle);retainedBundle = YES; }
        original = original_CFBundleGetInfoDictionary ? original_CFBundleGetInfoDictionary(bundle) : NULL;result = original;
        if (original) { CFRetain(original);retainedOriginal = YES; }
        @try { result = (__bridge CFDictionaryRef)PXAppVersionProjectInfo(nil,bundle,(__bridge NSDictionary *)original,NO,YES); }
        @catch (__unused NSException *exception) { result = original; }
        return result;
    } @finally { if (retainedOriginal) CFRelease(original);if (retainedBundle) CFRelease(bundle);if (entered) gPXAppVersionInfoRecursion--; }
}
static CFDictionaryRef replaced_CFBundleGetLocalInfoDictionary(CFBundleRef bundle) {
    CFDictionaryRef original = NULL, result = NULL;BOOL entered = NO, retainedBundle = NO, retainedOriginal = NO;
    @try {
        if (gPXAppVersionInfoRecursion > 0) return original_CFBundleGetLocalInfoDictionary ? original_CFBundleGetLocalInfoDictionary(bundle) : NULL;
        gPXAppVersionInfoRecursion++;entered = YES;
        if (bundle) { CFRetain(bundle);retainedBundle = YES; }
        original = original_CFBundleGetLocalInfoDictionary ? original_CFBundleGetLocalInfoDictionary(bundle) : NULL;result = original;
        if (original) { CFRetain(original);retainedOriginal = YES; }
        @try { result = (__bridge CFDictionaryRef)PXAppVersionProjectInfo(nil,bundle,(__bridge NSDictionary *)original,YES,YES); }
        @catch (__unused NSException *exception) { result = original; }
        return result;
    } @finally { if (retainedOriginal) CFRelease(original);if (retainedBundle) CFRelease(bundle);if (entered) gPXAppVersionInfoRecursion--; }
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
    @try { PXAppVersionHooksInvalidateCache(); } @catch (__unused NSException *exception) { }
}

%dtor {
    @try { PXAppVersionHooksInvalidateCache(); } @catch (__unused NSException *exception) { }
}

%ctor {
    @autoreleasepool {
        if (!PXBootstrapAllows(PXHookCapabilityNative)) return;
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
