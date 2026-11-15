#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "TLinkIOSLogging.h"
#import <objc/runtime.h>
#import "PXScope.h"
#import "PXRuntimeUtilities.h"
#import "PXPaths.h"
#import "PXRuntimeSnapshot.h"
#import <os/lock.h>
#include <math.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

// Scalar cache state only: no foreign method or object destruction under lock.
typedef NS_ENUM(NSInteger, WeaponXThemeStyle) {
    WeaponXThemeStyleUnspecified, WeaponXThemeStyleLight, WeaponXThemeStyleDark
};
static os_unfair_lock gThemeCacheLock = OS_UNFAIR_LOCK_INIT;
static uint64_t gThemeCacheGeneration;
static BOOL gThemeCacheValid;
static WeaponXThemeStyle gThemeCachedStyle;
static double gThemeLoadedAt;
static const double kCacheValidityDuration = 300.0;
static __thread BOOL gPXThemePreparing;
static __thread BOOL gPXThemeBypass;
static BOOL gPXThemeTraitFactoriesAvailable;

static double PXThemeMonotonicNow(void) {
    struct timespec ts;
    return clock_gettime(CLOCK_MONOTONIC, &ts) == 0 ? (double)ts.tv_sec + (double)ts.tv_nsec / 1000000000.0 : NAN;
}
static BOOL PXThemeCacheBegin(double now, WeaponXThemeStyle *style, uint64_t *ticket) {
    BOOL hit = NO;
    os_unfair_lock_lock(&gThemeCacheLock);
    if (gThemeCacheValid && isfinite(now) && isfinite(gThemeLoadedAt) && now >= gThemeLoadedAt &&
        now - gThemeLoadedAt <= kCacheValidityDuration) {
        *style = gThemeCachedStyle; hit = YES;
    } else {
        *ticket = ++gThemeCacheGeneration;
        gThemeCacheValid = NO;
    }
    os_unfair_lock_unlock(&gThemeCacheLock);
    return hit;
}
static BOOL PXThemeCachePublish(uint64_t ticket, double now, WeaponXThemeStyle style, BOOL enabled) {
    BOOL current = NO;
    os_unfair_lock_lock(&gThemeCacheLock);
    if (ticket == gThemeCacheGeneration) {
        current = YES;
        gThemeCacheValid = isfinite(now) && (!enabled || style == WeaponXThemeStyleLight || style == WeaponXThemeStyleDark);
        gThemeCachedStyle = enabled ? style : WeaponXThemeStyleUnspecified; gThemeLoadedAt = now;
    }
    os_unfair_lock_unlock(&gThemeCacheLock);
    return current;
}
static void PXThemeInvalidateCache(void) {
    os_unfair_lock_lock(&gThemeCacheLock);
    ++gThemeCacheGeneration; gThemeCacheValid = NO;
    gThemeCachedStyle = WeaponXThemeStyleUnspecified; gThemeLoadedAt = 0;
    os_unfair_lock_unlock(&gThemeCacheLock);
}
static NSString *getCurrentBundleID(void) {
    NSBundle *bundle = nil;
    @try { bundle = [NSBundle mainBundle]; return bundle.bundleIdentifier; }
    @catch (__unused NSException *exception) { return nil; }
    @finally { bundle = nil; }
}
static BOOL shouldSpoofForBundle(NSString *bundleID) {
    PX_RUNTIME_READ_OPERATION;
    NSString *process = nil;
    @try {
        if (!bundleID.length) return NO;
        process = [NSProcessInfo processInfo].processName;
        if (PXIsSafariStackProcess(bundleID, process)) return NO;
        return PXProcessIsAllowedForSpoofing(bundleID, process, PXScopeOptionNone);
    } @finally { bundleID = nil; process = nil; }
}
static WeaponXThemeStyle PXThemeDecode(NSString *value) {
    @try {
        if ([value isEqualToString:@"Dark"]) return WeaponXThemeStyleDark;
        if ([value isEqualToString:@"Light"]) return WeaponXThemeStyleLight;
        return WeaponXThemeStyleUnspecified;
    } @finally { value = nil; }
}
// One canonical enablement rule; an invalid present primary never falls back.
typedef NS_ENUM(NSInteger, PXThemeEnablement) { PXThemeEnablementMissing, PXThemeEnablementDisabled, PXThemeEnablementEnabled };
static BOOL PXThemeBool(id value) {
    @try { return ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class]) && [value boolValue]; }
    @finally { value = nil; }
}
static PXThemeEnablement PXThemePrimaryEnablement(NSDictionary *settings) {
    id flags = nil, value = nil;
    @try {
        if (!settings) return PXThemeEnablementMissing;
        if (![settings isKindOfClass:NSDictionary.class]) return PXThemeEnablementDisabled;
        flags = settings[@"EnabledIdentifiers"];
        if (!flags) return PXThemeEnablementMissing;
        if (![flags isKindOfClass:NSDictionary.class]) return PXThemeEnablementDisabled;
        value = flags[@"DeviceTheme"];
        if (!value) return PXThemeEnablementMissing;
        return PXThemeBool(value) ? PXThemeEnablementEnabled : PXThemeEnablementDisabled;
    } @finally { settings = nil; flags = nil; value = nil; }
}
static BOOL PXThemeSecondaryEnablement(NSDictionary *security) {
    id value = nil;
    @try {
        if (![security isKindOfClass:NSDictionary.class]) return NO;
        value = security[@"deviceThemeSpoofEnabled"];
        return PXThemeBool(value);
    } @finally { security = nil; value = nil; }
}
static NSDictionary *PXThemeDictionaryAtPath(NSString *path) {
    NSDictionary *dictionary = nil;
    @try { if (path.length) dictionary = [NSDictionary dictionaryWithContentsOfFile:path]; return dictionary; }
    @finally { path = nil; dictionary = nil; }
}
typedef NS_ENUM(NSInteger, PXThemeFilePresence) { PXThemeFileMissing, PXThemeFilePresent, PXThemeFileUnreadable };
static PXThemeFilePresence PXThemePresenceAtPath(NSFileManager *files, NSString *path) {
    NSDictionary *attributes = nil;
    NSError *__autoreleasing error = nil;
    @try {
        if (!path.length) return PXThemeFileUnreadable;
        attributes = [files attributesOfItemAtPath:path error:&error];
        if (attributes) return PXThemeFilePresent;
        if ([error.domain isEqualToString:NSCocoaErrorDomain] &&
            (error.code == NSFileReadNoSuchFileError || error.code == NSFileNoSuchFileError)) return PXThemeFileMissing;
        return PXThemeFileUnreadable;
    } @finally { files = nil; path = nil; attributes = nil; }
}
// Cold rootful legacy reader only. No source gate/recovery, shared manager reload,
// defaults synchronization or writes occur on a synchronous trait getter.
static BOOL PXThemeRootfulEnabled(void) {
    NSFileManager *files = nil;
    NSString *path = nil, *legacy = nil;
    NSDictionary *settings = nil, *security = nil;
    NSUserDefaults *defaults = nil;
    id value = nil;
    @try {
        files = [NSFileManager defaultManager]; path = PXTLinkIOSSettingsPath();
        PXThemeFilePresence presence = PXThemePresenceAtPath(files, path);
        if (presence == PXThemeFileUnreadable) return NO;
        if (presence == PXThemeFileMissing) {
            legacy = [PXPreferencesPath() stringByAppendingPathComponent:@"com.hydra.tlinkios.plist"];
            presence = PXThemePresenceAtPath(files, legacy);
            if (presence == PXThemeFileUnreadable) return NO;
            if (presence == PXThemeFilePresent) path = legacy;
        }
        if (presence == PXThemeFilePresent) {
            settings = PXThemeDictionaryAtPath(path);
            if (![settings isKindOfClass:NSDictionary.class]) return NO;
        }
        PXThemeEnablement primary = PXThemePrimaryEnablement(settings);
        if (primary != PXThemeEnablementMissing) return primary == PXThemeEnablementEnabled;
        // Match the existing security store's disk-first, defaults-on-missing-key
        // precedence. Corrupt present sources/values disable rather than infer ON.
        path = PXSecuritySettingsPath();
        presence = PXThemePresenceAtPath(files, path);
        if (presence == PXThemeFileUnreadable) return NO;
        if (presence == PXThemeFilePresent) {
            security = PXThemeDictionaryAtPath(path);
            if (![security isKindOfClass:NSDictionary.class]) return NO;
            value = security[@"deviceThemeSpoofEnabled"];
            if (value != nil) return PXThemeBool(value);
        }
        defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
        value = [defaults objectForKey:@"deviceThemeSpoofEnabled"];
        return PXThemeBool(value);
    } @finally {
        files = nil; path = nil; legacy = nil; settings = nil; security = nil; defaults = nil; value = nil;
    }
}
static WeaponXThemeStyle getThemeStyleFromProfile(void) {
    PX_RUNTIME_READ_OPERATION;
    PXRuntimeReadSnapshot *runtimeView = nil;
    NSDictionary *deviceIDs = nil, *themeInfo = nil, *settings = nil, *security = nil;
    NSString *identityPath = nil, *deviceIDsPath = nil, *themeValue = nil;
    id raw = nil;
    @try {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        // One operation view; no TTL, clock, lock or live file fallback here.
        runtimeView = PXCaptureRuntimeSnapshot();
        settings = runtimeView.tlinkSettings;
        PXThemeEnablement primary = PXThemePrimaryEnablement(settings);
        BOOL enabled = primary == PXThemeEnablementEnabled;
        if (primary == PXThemeEnablementMissing) {
            security = runtimeView.securitySettings;
            enabled = PXThemeSecondaryEnablement(security);
        }
        if (!enabled) return WeaponXThemeStyleUnspecified;
        deviceIDs = runtimeView.deviceIDs;
#else
        double now = PXThemeMonotonicNow();
        uint64_t ticket = 0;
        WeaponXThemeStyle cached = WeaponXThemeStyleUnspecified;
        if (PXThemeCacheBegin(now, &cached, &ticket)) return cached;
        BOOL enabled = PXThemeRootfulEnabled();
        if (!enabled) {
            // Unspecified is a cacheable resolved OFF packet, distinct from an
            // enabled but unknown theme (which remains uncached).
            PXThemeCachePublish(ticket, now, WeaponXThemeStyleUnspecified, NO);
            return WeaponXThemeStyleUnspecified;
        }
        // Both artifacts belong to one resolved profile identity directory.
        identityPath = PXActiveProfileIdentityPath();
        deviceIDsPath = identityPath.length ? [identityPath stringByAppendingPathComponent:@"device_ids.plist"] : nil;
        deviceIDs = deviceIDsPath.length ? PXThemeDictionaryAtPath(deviceIDsPath) : nil;
#endif
        if ([deviceIDs isKindOfClass:NSDictionary.class]) raw = deviceIDs[@"DeviceTheme"];
        if ([raw isKindOfClass:NSString.class] && [raw length]) themeValue = raw;
        if (!themeValue) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
            themeInfo = [runtimeView profileArtifact:@"deviceTheme"];
#else
            if (identityPath.length) themeInfo = PXThemeDictionaryAtPath([identityPath stringByAppendingPathComponent:@"device_theme.plist"]);
#endif
            raw = [themeInfo isKindOfClass:NSDictionary.class] ? themeInfo[@"value"] : nil;
            if ([raw isKindOfClass:NSString.class] && [raw length]) themeValue = raw;
        }
        if (!themeValue) themeValue = @"Light"; // Preserve legacy absent-data default.
        WeaponXThemeStyle style = PXThemeDecode(themeValue);
#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        // Invalidation or a newer cold read supersedes this candidate. Do not
        // repopulate/return its old override; this invocation falls back native.
        if (!PXThemeCachePublish(ticket, now, style, YES)) return WeaponXThemeStyleUnspecified;
#endif
        return style;
    } @finally {
        runtimeView = nil; deviceIDs = nil; themeInfo = nil; settings = nil; security = nil; raw = nil;
        identityPath = nil; deviceIDsPath = nil; themeValue = nil;
    }
}
static UIUserInterfaceStyle mapThemeStyleToUIUserInterfaceStyle(WeaponXThemeStyle style) {
    switch (style) {
        case WeaponXThemeStyleDark: return UIUserInterfaceStyleDark;
        case WeaponXThemeStyleLight: return UIUserInterfaceStyleLight;
        default: return UIUserInterfaceStyleUnspecified;
    }
}
// Internal work is entered only with the preparation guard already claimed.
static WeaponXThemeStyle PXThemeReadStyleForOperation(NSString *__strong *bundleOut) {
    NSString *bundle = nil;
    @try {
        bundle = getCurrentBundleID();
        if (!shouldSpoofForBundle(bundle)) return WeaponXThemeStyleUnspecified;
        if (bundleOut) *bundleOut = bundle;
        return getThemeStyleFromProfile();
    } @finally { bundle = nil; }
}
static WeaponXThemeStyle PXThemeResolveOverride(NSString *__strong *bundleOut) {
    BOOL previous = gPXThemePreparing;
    @try {
        if (previous || gPXThemeBypass) return WeaponXThemeStyleUnspecified;
        gPXThemePreparing = YES;
        return PXThemeReadStyleForOperation(bundleOut);
    } @catch (__unused NSException *exception) { return WeaponXThemeStyleUnspecified; }
    @finally { gPXThemePreparing = previous; }
}
static void PXThemeLogOverride(NSString *bundle, UIUserInterfaceStyle style) {
    @try {
        if (PXLogOnceClaim(@"ThemeHooks.bundle", bundle))
            PXLog(@"[WeaponX] Spoofing device theme for %@ to: %@", bundle, style == UIUserInterfaceStyleDark ? @"Dark" : @"Light");
    } @catch (__unused NSException *exception) { }
    @finally { bundle = nil; }
}
static void PXThemeLogInstallation(NSString *format, id detail) {
    @try { PXLog(format, detail); }
    @catch (__unused NSException *exception) { }
    @finally { format = nil; detail = nil; }
}
static UITraitCollection *PXThemeProjectTraits(UITraitCollection *original) {
    UITraitCollection *styleTrait = nil, *merged = nil;
    NSArray *inputs = nil;
    BOOL previous = gPXThemePreparing, bypass = gPXThemeBypass;
    @try {
        if (!original || previous || bypass || !gPXThemeTraitFactoriesAvailable) return original;
        gPXThemePreparing = YES;
        WeaponXThemeStyle theme = PXThemeReadStyleForOperation(NULL);
        if (theme == WeaponXThemeStyleUnspecified) return original;
        UIUserInterfaceStyle style = mapThemeStyleToUIUserInterfaceStyle(theme);
        // Read the native style, not our own scalar getter override. Keep the
        // bypass through factories so their nested trait queries remain native.
        gPXThemeBypass = YES;
        if (original.userInterfaceStyle == style) return original;
        styleTrait = [UITraitCollection traitCollectionWithUserInterfaceStyle:style];
        if (!styleTrait) return original;
        inputs = @[original, styleTrait];
        merged = [UITraitCollection traitCollectionWithTraitsFromCollections:inputs];
        return merged ?: original;
    } @catch (__unused NSException *exception) { return original; }
    @finally {
        gPXThemePreparing = previous; gPXThemeBypass = bypass;
        original = nil; styleTrait = nil; merged = nil; inputs = nil;
    }
}

// Validate actual runtime capabilities; an OS version alone does not prove a
// private selector exists or carries the ABI used by a replacement.
static const char *PXThemeSkipQualifiers(const char *type) {
    while (type && *type && strchr("rnNoORV", *type)) type++;
    return type;
}
static BOOL PXThemeTypeMatches(const char *actual, const char *expected) {
    actual = PXThemeSkipQualifiers(actual); expected = PXThemeSkipQualifiers(expected);
    if (!actual || !expected) return NO;
    if (!strcmp(expected, @encode(id))) return *actual == '@' && actual[1] != '?';
    return !strcmp(actual, expected);
}
static BOOL PXThemeMethodSupported(Class cls, SEL selector, const char *result, const char *argument) {
    NSMethodSignature *signature = nil;
    @try {
        Method method = cls && selector ? class_getInstanceMethod(cls, selector) : NULL;
        const char *types = method ? method_getTypeEncoding(method) : NULL;
        if (!types) return NO;
        signature = [NSMethodSignature signatureWithObjCTypes:types];
        if (signature.numberOfArguments < 2) return NO;
        const char *receiver = PXThemeSkipQualifiers([signature getArgumentTypeAtIndex:0]);
        BOOL receiverOK = receiver && ((*receiver == '@' && receiver[1] != '?') || !strcmp(receiver, @encode(Class)));
        return signature.numberOfArguments == (argument ? 3u : 2u) &&
            PXThemeTypeMatches(signature.methodReturnType, result) &&
            receiverOK &&
            PXThemeTypeMatches([signature getArgumentTypeAtIndex:1], @encode(SEL)) &&
            (!argument || PXThemeTypeMatches([signature getArgumentTypeAtIndex:2], argument));
    } @catch (__unused NSException *exception) { return NO; }
    @finally { signature = nil; }
}

%group ThemeStyleGetter
%hook UITraitCollection
- (UIUserInterfaceStyle)userInterfaceStyle {
    PX_RUNTIME_READ_OPERATION;
    __attribute__((objc_precise_lifetime)) id receiver = self;
    NSString *bundle = nil;
    @try {
        WeaponXThemeStyle theme = PXThemeResolveOverride(&bundle);
        if (theme != WeaponXThemeStyleUnspecified) {
            UIUserInterfaceStyle style = mapThemeStyleToUIUserInterfaceStyle(theme);
            PXThemeLogOverride(bundle, style); return style;
        }
        return %orig;
    } @finally { bundle = nil; receiver = nil; }
}
%end
%end
%group ThemeEffectiveGetter
%hook UITraitCollection
- (UIUserInterfaceStyle)effectiveUserInterfaceStyle {
    PX_RUNTIME_READ_OPERATION;
    __attribute__((objc_precise_lifetime)) id receiver = self;
    @try {
        if (@available(iOS 17.0, *)) {
            WeaponXThemeStyle theme = PXThemeResolveOverride(NULL);
            if (theme != WeaponXThemeStyleUnspecified) return mapThemeStyleToUIUserInterfaceStyle(theme);
        }
        return %orig;
    } @finally { receiver = nil; }
}
%end
%end
%group ThemeScreenTraits
%hook UIScreen
- (UITraitCollection *)traitCollection {
    PX_RUNTIME_READ_OPERATION;
    __attribute__((objc_precise_lifetime)) id receiver = self;
    UITraitCollection *original = nil;
    @try { original = %orig; return PXThemeProjectTraits(original); }
    @finally { original = nil; receiver = nil; }
}
%end
%end
%group ThemeViewTraits
%hook UIView
- (UITraitCollection *)traitCollection {
    PX_RUNTIME_READ_OPERATION;
    __attribute__((objc_precise_lifetime)) id receiver = self;
    UITraitCollection *original = nil;
    @try { original = %orig; return PXThemeProjectTraits(original); }
    @finally { original = nil; receiver = nil; }
}
%end
%end
%group ThemeControllerTraits
%hook UIViewController
- (UITraitCollection *)traitCollection {
    PX_RUNTIME_READ_OPERATION;
    __attribute__((objc_precise_lifetime)) id receiver = self;
    UITraitCollection *original = nil;
    @try { original = %orig; return PXThemeProjectTraits(original); }
    @finally { original = nil; receiver = nil; }
}
%end
%end
%group ThemeWebKitScheme
%hook WKWebView
- (void)_setPreferredColorScheme:(NSInteger)colorScheme {
    PX_RUNTIME_READ_OPERATION;
    __attribute__((objc_precise_lifetime)) id receiver = self;
    @try {
        WeaponXThemeStyle theme = PXThemeResolveOverride(NULL);
        NSInteger resolved = theme == WeaponXThemeStyleUnspecified ? colorScheme : (theme == WeaponXThemeStyleDark ? 1 : 0);
        %orig(resolved);
    } @finally { receiver = nil; }
}
%end
%end

static void themeSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)object; (void)userInfo;
    @autoreleasepool {
        NSString *notification = nil;
        // Cache invalidation must survive an optional scope/logging failure.
        PXThemeInvalidateCache();
        @try { PXInvalidateScopeDecisionCache(); } @catch (__unused NSException *exception) { }
        @try { notification = (__bridge NSString *)name; PXLog(@"[WeaponX] Received settings notification: %@", notification); }
        @catch (__unused NSException *exception) { }
        @finally { notification = nil; }
    }
}

// Constructor to initialize hooks
%ctor {
    @autoreleasepool {
        if (!PXBootstrapAllows(PXHookCapabilityNative)) return;
        NSString *bundleID = nil, *process = nil;
        @try {
            PXThemeLogInstallation(@"[ThemeHooks] Initializing theme hooks", nil);
            
            bundleID = getCurrentBundleID();
            
            // Skip if we can't get bundle ID
            if (!bundleID || [bundleID length] == 0) {
                return;
            }
            
            // Don't hook our own apps
            if ([bundleID isEqualToString:@"com.hydra.tlinkios"] ||
                [bundleID isEqualToString:@"com.hydra.weaponx"]) {
                return;
            }

            // Don't hook system processes - including Safari (theme spoofing causes text issues)
            // Note: We deliberately skip Safari for theme hooks even if Safari Spoofing is enabled, 
            // because theme spoofing causes invisible text in WebKit forms (Dark mode text on Light mode background).
            process = [NSProcessInfo processInfo].processName;
            if (!PXProcessIsAllowedForSpoofing(bundleID, process, PXScopeOptionNone)) {
                PXThemeLogInstallation(@"[ThemeHooks] App %@ is not scoped, skipping hook installation", bundleID);
                return;
            }
            
            PXThemeLogInstallation(@"[ThemeHooks] App %@ is scoped, setting up theme hooks", bundleID);
            
            // Initialize hooks for scoped apps only
            gPXThemeTraitFactoriesAvailable =
                PXThemeMethodSupported(object_getClass(UITraitCollection.class), @selector(traitCollectionWithUserInterfaceStyle:), @encode(id), @encode(NSInteger)) &&
                PXThemeMethodSupported(object_getClass(UITraitCollection.class), @selector(traitCollectionWithTraitsFromCollections:), @encode(id), @encode(id)) &&
                PXThemeMethodSupported(UITraitCollection.class, @selector(userInterfaceStyle), @encode(NSInteger), NULL);
            if (PXThemeMethodSupported(UITraitCollection.class, @selector(userInterfaceStyle), @encode(NSInteger), NULL)) { %init(ThemeStyleGetter); }
            if (@available(iOS 17.0, *)) {
                if (PXThemeMethodSupported(UITraitCollection.class, NSSelectorFromString(@"effectiveUserInterfaceStyle"), @encode(NSInteger), NULL)) { %init(ThemeEffectiveGetter); }
            }
            if (gPXThemeTraitFactoriesAvailable) {
                if (PXThemeMethodSupported(UIScreen.class, @selector(traitCollection), @encode(id), NULL)) { %init(ThemeScreenTraits); }
                if (PXThemeMethodSupported(UIView.class, @selector(traitCollection), @encode(id), NULL)) { %init(ThemeViewTraits); }
                if (PXThemeMethodSupported(UIViewController.class, @selector(traitCollection), @encode(id), NULL)) { %init(ThemeControllerTraits); }
            }
            if (PXThemeMethodSupported(NSClassFromString(@"WKWebView"), NSSelectorFromString(@"_setPreferredColorScheme:"), @encode(void), @encode(NSInteger))) { %init(ThemeWebKitScheme); }
            
            // Register for theme spoofing toggle notification
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                themeSettingsChanged,
                CFSTR("com.hydra.tlinkios.toggleDeviceThemeSpoof"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
            
            // Also register for general settings and profile change notifications
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                themeSettingsChanged,
                CFSTR("com.hydra.tlinkios.settings.changed"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
            
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                themeSettingsChanged,
                CFSTR("com.hydra.tlinkios.profileChanged"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                themeSettingsChanged,
                CFSTR("com.hydra.tlinkios.scopedAppsChanged"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
            
            PXThemeLogInstallation(@"[ThemeHooks] Theme capability setup completed for scoped app: %@", bundleID);
            
        } @catch (NSException *e) {
            PXThemeLogInstallation(@"[ThemeHooks] ❌ Exception in constructor: %@", e);
        } @finally { bundleID = nil; process = nil; }
    }
} 
