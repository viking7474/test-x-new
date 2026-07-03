#import "PXScope.h"
#import <CoreFoundation/CoreFoundation.h>

static __thread BOOL gPXReadingSecuritySettings = NO;

BOOL PXScopeIsReadingSecuritySettings(void) {
    return gPXReadingSecuritySettings;
}

static id PXReadSecuritySettingObject(NSString *key) {
    if (!key.length) return nil;
    gPXReadingSecuritySettings = YES;
    id result = nil;

    CFStringRef cfKey = (__bridge CFStringRef)key;
    CFStringRef appID = CFSTR("com.weaponx.securitySettings");
    CFPropertyListRef pref = CFPreferencesCopyAppValue(cfKey, appID);
    if (pref) {
        result = CFBridgingRelease(pref);
        gPXReadingSecuritySettings = NO;
        return result;
    }

    NSArray<NSString *> *paths = @[
        @"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist",
        @"/private/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist"
    ];
    for (NSString *path in paths) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
        if ([dict isKindOfClass:[NSDictionary class]] && dict[key] != nil) {
            result = dict[key];
            break;
        }
    }
    gPXReadingSecuritySettings = NO;
    return result;
}

static BOOL PXReadSecuritySettingHasKey(NSString *key) {
    if (!key.length) return NO;
    gPXReadingSecuritySettings = YES;

    CFStringRef cfKey = (__bridge CFStringRef)key;
    CFStringRef appID = CFSTR("com.weaponx.securitySettings");
    CFPropertyListRef pref = CFPreferencesCopyAppValue(cfKey, appID);
    if (pref) {
        CFRelease(pref);
        gPXReadingSecuritySettings = NO;
        return YES;
    }

    NSArray<NSString *> *paths = @[
        @"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist",
        @"/private/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist"
    ];
    for (NSString *path in paths) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
        if ([dict isKindOfClass:[NSDictionary class]] && dict[key] != nil) {
            gPXReadingSecuritySettings = NO;
            return YES;
        }
    }
    gPXReadingSecuritySettings = NO;
    return NO;
}

static BOOL PXReadSecuritySettingBool(NSString *key) {
    id v = PXReadSecuritySettingObject(key);
    return v ? [v boolValue] : NO;
}

// Small cache to avoid disk reads on hot paths.
static NSTimeInterval gLastSettingsRead = 0;
static BOOL gCachedDeviceSpoofEnabled = NO;
static BOOL gCachedSafariStackEnabled = NO;
static BOOL gCachedFullSpoofTestModeEnabled = NO;
static BOOL gCachedDisplayUIScaleEnabled = YES;
static BOOL gCachedDisplayPixelMetricsEnabled = YES;
static BOOL gCachedDisplayWebScreenEnabled = YES;
static BOOL gCacheValid = NO;
static NSDictionary *gScopedAppsCache = nil;
static uint64_t gScopeGeneration = 1;
static NSMutableDictionary *gDecisionLogTimes = nil;

void PXInvalidateScopeDecisionCache(void) {
    gCacheValid = NO;
    gScopedAppsCache = nil;
    gScopeGeneration++;
}

uint64_t PXScopeGeneration(void) {
    return gScopeGeneration;
}

static void PXInvalidateScopeCache(void) {
    PXInvalidateScopeDecisionCache();
}

static NSDictionary *PXLoadScopedApps(void) {
    if (gScopedAppsCache) return gScopedAppsCache;
    NSArray<NSString *> *paths = @[
        @"/var/mobile/Library/Preferences/com.hydra.projectx.global_scope.plist",
        @"/private/var/mobile/Library/Preferences/com.hydra.projectx.global_scope.plist"
    ];
    for (NSString *path in paths) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
        NSDictionary *scoped = [dict isKindOfClass:[NSDictionary class]] ? dict[@"ScopedApps"] : nil;
        if ([scoped isKindOfClass:[NSDictionary class]]) {
            gScopedAppsCache = [scoped copy];
            return gScopedAppsCache;
        }
    }
    gScopedAppsCache = @{};
    return gScopedAppsCache;
}

static BOOL PXScopedBundleEnabled(NSString *bundleID) {
    if (![bundleID isKindOfClass:[NSString class]] || !bundleID.length) return NO;
    NSDictionary *scoped = PXLoadScopedApps();
    NSDictionary *entry = [scoped[bundleID] isKindOfClass:[NSDictionary class]] ? scoped[bundleID] : nil;
    return [entry[@"enabled"] boolValue];
}

static void PXScopeNotify(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    PXInvalidateScopeCache();
}

static void PXEnsureScopeCache(void) {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (gCacheValid && (now - gLastSettingsRead) < 1.0) {
        return;
    }
    gLastSettingsRead = now;

    BOOL deviceEnabled = PXReadSecuritySettingBool(@"deviceSpoofingEnabled");

    // Full spoof test mode: force Safari/Auth stack spoofing ON (for failure testing).
    BOOL fullTest = PXReadSecuritySettingBool(@"fullSpoofTestModeEnabled");

    // Default behavior: if safariStackSpoofEnabled is absent, follow deviceSpoofingEnabled.
    BOOL safariEnabled = deviceEnabled;
    if (PXReadSecuritySettingHasKey(@"safariStackSpoofEnabled")) {
        safariEnabled = deviceEnabled && PXReadSecuritySettingBool(@"safariStackSpoofEnabled");
    }
    // In test mode, always allow Safari/Auth stack spoofing when global spoofing is enabled.
    if (deviceEnabled && fullTest) {
        safariEnabled = YES;
    }

    // Display spoof controls. Defaults are ON when keys are absent.
    BOOL uiScaleEnabled = deviceEnabled;
    if (PXReadSecuritySettingHasKey(@"displayUIScaleSpoofEnabled")) {
        uiScaleEnabled = deviceEnabled && PXReadSecuritySettingBool(@"displayUIScaleSpoofEnabled");
    }

    BOOL pixelMetricsEnabled = deviceEnabled;
    if (PXReadSecuritySettingHasKey(@"displayPixelMetricsSpoofEnabled")) {
        pixelMetricsEnabled = deviceEnabled && PXReadSecuritySettingBool(@"displayPixelMetricsSpoofEnabled");
    }

    BOOL webScreenEnabled = deviceEnabled;
    if (PXReadSecuritySettingHasKey(@"displayWebScreenSpoofEnabled")) {
        webScreenEnabled = deviceEnabled && PXReadSecuritySettingBool(@"displayWebScreenSpoofEnabled");
    }

    gCachedDeviceSpoofEnabled = deviceEnabled;
    gCachedFullSpoofTestModeEnabled = (deviceEnabled && fullTest);
    gCachedSafariStackEnabled = safariEnabled;
    gCachedDisplayUIScaleEnabled = uiScaleEnabled;
    gCachedDisplayPixelMetricsEnabled = pixelMetricsEnabled;
    gCachedDisplayWebScreenEnabled = webScreenEnabled;
    gCacheValid = YES;
}

__attribute__((constructor))
static void PXScopeInit(void) {
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    if (!center) return;
    CFNotificationCenterAddObserver(center, NULL, PXScopeNotify, CFSTR("com.hydra.projectx.settings.changed"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(center, NULL, PXScopeNotify, CFSTR("com.hydra.projectx.profileChanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(center, NULL, PXScopeNotify, CFSTR("com.hydra.projectx.safariStackSpoofToggleChanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}

BOOL PXDeviceSpoofingEnabled(void) {
    PXEnsureScopeCache();
    return gCachedDeviceSpoofEnabled;
}

BOOL PXSafariStackSpoofEnabled(void) {
    PXEnsureScopeCache();
    return gCachedSafariStackEnabled;
}

BOOL PXFullSpoofTestModeEnabled(void) {
    PXEnsureScopeCache();
    return gCachedFullSpoofTestModeEnabled;
}

BOOL PXDisplayUIScaleSpoofEnabled(void) {
    PXEnsureScopeCache();
    return gCachedDisplayUIScaleEnabled;
}

BOOL PXDisplayPixelMetricsSpoofEnabled(void) {
    PXEnsureScopeCache();
    return gCachedDisplayPixelMetricsEnabled;
}

BOOL PXDisplayWebScreenSpoofEnabled(void) {
    PXEnsureScopeCache();
    return gCachedDisplayWebScreenEnabled;
}

BOOL PXIsCriticalSystemProcess(NSString *bundleID, NSString *processName) {
    static NSSet<NSString *> *criticalNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        criticalNames = [NSSet setWithArray:@[
            @"SpringBoard",
            @"backboardd",
            @"runningboardd",
            @"assertiond",
            @"launchd",
            @"installd",
            @"mobile_installation_proxy",
            @"securityd",
            @"mediaserverd",
            @"commcenter",
            @"aggregated"
        ]];
    });
    if ([processName isKindOfClass:[NSString class]] && [criticalNames containsObject:processName]) return YES;
    if ([bundleID isEqualToString:@"com.apple.springboard"]) return YES;
    return NO;
}

BOOL PXIsWebKitHelperProcess(NSString *bundleID, NSString *processName) {
    if ([bundleID isEqualToString:@"com.apple.SafariViewService"]) return YES;
    if ([bundleID hasPrefix:@"com.apple.WebKit"]) return YES;
    if ([processName isKindOfClass:[NSString class]]) {
        if ([processName containsString:@"SafariViewService"] ||
            [processName containsString:@"WebContent"] ||
            [processName containsString:@"Networking"] ||
            [processName containsString:@"GPU"] ||
            [processName containsString:@"WebKit"]) {
            return YES;
        }
    }
    return NO;
}

NSString *PXWebKitHostBundleIdentifier(void) {
    static NSString *cachedHost = nil;
    if (cachedHost.length) return cachedHost;

    NSArray<NSString *> *homeCandidates = @[
        NSHomeDirectory() ?: @"",
        [[[NSProcessInfo processInfo] environment][@"HOME"] isKindOfClass:[NSString class]] ? [[NSProcessInfo processInfo] environment][@"HOME"] : @"",
        [[[NSProcessInfo processInfo] environment][@"CFFIXED_USER_HOME"] isKindOfClass:[NSString class]] ? [[NSProcessInfo processInfo] environment][@"CFFIXED_USER_HOME"] : @""
    ];
    for (NSString *home in homeCandidates) {
        if (![home isKindOfClass:[NSString class]] || !home.length) continue;
        NSString *metadataPath = [home stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        NSString *identifier = [metadata[@"MCMMetadataIdentifier"] isKindOfClass:[NSString class]] ? metadata[@"MCMMetadataIdentifier"] : nil;
        if (identifier.length) {
            cachedHost = [identifier copy];
            return cachedHost;
        }
    }
    return nil;
}

BOOL PXWebKitHostIsScopedForSpoofing(void) {
    if (!PXDeviceSpoofingEnabled()) return NO;
    NSString *host = PXWebKitHostBundleIdentifier();
    if (!host.length) return NO;
    NSString *proc = [NSProcessInfo processInfo].processName;
    if (PXIsCriticalSystemProcess(host, proc)) return NO;
    return PXScopedBundleEnabled(host);
}

BOOL PXIsSafariStackProcess(NSString *bundleID, NSString *processName) {
    if (![bundleID isKindOfClass:[NSString class]] || !bundleID.length) return NO;
    if ([bundleID isEqualToString:@"com.apple.mobilesafari"]) return YES;
    if ([bundleID isEqualToString:@"com.apple.webapp"]) return YES;
    if ([bundleID isEqualToString:@"com.apple.SafariViewService"]) return YES;
    if ([bundleID hasPrefix:@"com.apple.WebKit"]) return YES;

    BOOL appleWebKitBundle = [bundleID hasPrefix:@"com.apple.WebKit"] ||
        [bundleID hasPrefix:@"com.apple.Safari"] ||
        [bundleID isEqualToString:@"com.apple.mobilesafari"] ||
        [bundleID isEqualToString:@"com.apple.SafariViewService"];
    if ([processName isKindOfClass:[NSString class]] && processName.length) {
        if (appleWebKitBundle &&
            ([processName containsString:@"SafariViewService"] ||
             [processName containsString:@"WebKit"] ||
             [processName containsString:@"WebContent"] ||
             [processName containsString:@"Networking"] ||
             [processName containsString:@"GPU"] ||
             [processName containsString:@"Safari"])) {
            return YES;
        }
    }
    return NO;
}

BOOL PXBundleIsStrictlyScopedForSpoofing(NSString *bundleID) {
    if (!PXDeviceSpoofingEnabled()) return NO;
    if (![bundleID isKindOfClass:[NSString class]] || !bundleID.length) return NO;
    if ([bundleID isEqualToString:@"com.hydra.projectx"] || [bundleID isEqualToString:@"com.hydra.weaponx"]) return NO;
    NSString *proc = [NSProcessInfo processInfo].processName;
    if (PXIsCriticalSystemProcess(bundleID, proc)) return NO;
    if (PXIsWebKitHelperProcess(bundleID, proc)) return NO;
    return PXScopedBundleEnabled(bundleID);
}

BOOL PXProcessIsAllowedForSpoofing(NSString *bundleID, NSString *processName, PXScopeOptions options) {
    if (PXIsCriticalSystemProcess(bundleID, processName)) return NO;
    BOOL webKitHelper = PXIsWebKitHelperProcess(bundleID, processName);
    NSString *webKitHost = webKitHelper ? PXWebKitHostBundleIdentifier() : nil;
    BOOL webKitHostScoped = webKitHelper && ((options & PXScopeOptionAllowSafariAuthStack) != 0) && PXSafariStackSpoofEnabled() && PXWebKitHostIsScopedForSpoofing();
    BOOL strict = PXBundleIsStrictlyScopedForSpoofing(bundleID);
    BOOL safari = !webKitHelper && ((options & PXScopeOptionAllowSafariAuthStack) && PXSafariStackSpoofEnabled() && PXIsSafariStackProcess(bundleID, processName));
    BOOL allowed = strict || safari || webKitHostScoped;

    if (!gDecisionLogTimes) gDecisionLogTimes = [NSMutableDictionary dictionary];
    NSString *key = [NSString stringWithFormat:@"%@|%@|%@|%lu|%d", bundleID ?: @"", processName ?: @"", webKitHost ?: @"", (unsigned long)options, allowed];
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSNumber *last = gDecisionLogTimes[key];
    if (!last || now - [last doubleValue] > 5.0) {
        gDecisionLogTimes[key] = @(now);
        NSLog(@"[PXScopeDecision] bundle=%@ proc=%@ host=%@ strict=%d safari=%d webkitHost=%d options=%lu allowed=%d gen=%llu",
              bundleID, processName, webKitHost, strict, safari, webKitHostScoped, (unsigned long)options, allowed, (unsigned long long)PXScopeGeneration());
    }

    return allowed;
}

BOOL PXAllowUnscopedSafariStack(void) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString *processName = [NSProcessInfo processInfo].processName;
    return PXProcessIsAllowedForSpoofing(bundleID, processName, PXScopeOptionAllowSafariAuthStack) && !PXBundleIsStrictlyScopedForSpoofing(bundleID);
}
