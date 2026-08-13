// LocaleTimeZoneHooks.x
// Runtime TargetRegion overrides (pinned from IP)

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

#import "TLinkIOSLogging.h"
#import "PXScope.h"

static NSString *const kSecuritySettingsPath_LTZ = @"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist";

static BOOL LTZIsInScopedAppsList(void) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return PXBundleIsEnabledInScope(bundleID);
}

static BOOL LTZShouldApply(void) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString *proc = [NSProcessInfo processInfo].processName;
    return PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack);
}

static NSDictionary *LTZSecuritySettings(void) {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:kSecuritySettingsPath_LTZ];
    return [d isKindOfClass:[NSDictionary class]] ? d : nil;
}

static BOOL LTZTargetRegionFollowsIPEnabled(void) {
    NSDictionary *s = LTZSecuritySettings();
    return [s[@"targetRegionFollowsIPEnabled"] boolValue];
}

static NSString *LTZPinnedLocaleIdentifier(void) {
    NSDictionary *s = LTZSecuritySettings();
    NSString *v = [s[@"targetRegionPinnedLocaleIdentifier"] isKindOfClass:[NSString class]] ? s[@"targetRegionPinnedLocaleIdentifier"] : nil;
    return v.length ? v : nil;
}

static NSArray *LTZPinnedPreferredLanguages(void) {
    NSDictionary *s = LTZSecuritySettings();
    NSArray *a = [s[@"targetRegionPinnedPreferredLanguages"] isKindOfClass:[NSArray class]] ? s[@"targetRegionPinnedPreferredLanguages"] : nil;
    return a.count ? a : nil;
}

static NSString *LTZPinnedTimeZoneName(void) {
    NSDictionary *s = LTZSecuritySettings();
    NSString *v = [s[@"targetRegionPinnedTimeZoneName"] isKindOfClass:[NSString class]] ? s[@"targetRegionPinnedTimeZoneName"] : nil;
    return v.length ? v : nil;
}

%hook NSLocale

+ (NSLocale *)currentLocale {
    NSLocale *orig = %orig;
    if (!LTZShouldApply() || !LTZTargetRegionFollowsIPEnabled()) return orig;
    NSString *localeId = LTZPinnedLocaleIdentifier();
    if (!localeId.length) return orig;
    return [NSLocale localeWithLocaleIdentifier:localeId];
}

+ (NSLocale *)autoupdatingCurrentLocale {
    NSLocale *orig = %orig;
    if (!LTZShouldApply() || !LTZTargetRegionFollowsIPEnabled()) return orig;
    NSString *localeId = LTZPinnedLocaleIdentifier();
    if (!localeId.length) return orig;
    return [NSLocale localeWithLocaleIdentifier:localeId];
}

+ (NSArray<NSString *> *)preferredLanguages {
    NSArray *orig = %orig;
    if (!LTZShouldApply() || !LTZTargetRegionFollowsIPEnabled()) return orig;
    NSArray *langs = LTZPinnedPreferredLanguages();
    if (!langs.count) return orig;
    return langs;
}

%end

%hook NSTimeZone

+ (NSTimeZone *)localTimeZone {
    NSTimeZone *orig = %orig;
    if (!LTZShouldApply() || !LTZTargetRegionFollowsIPEnabled()) return orig;
    NSString *tzName = LTZPinnedTimeZoneName();
    if (!tzName.length) return orig;
    NSTimeZone *tz = [NSTimeZone timeZoneWithName:tzName];
    return tz ?: orig;
}

+ (NSTimeZone *)systemTimeZone {
    NSTimeZone *orig = %orig;
    if (!LTZShouldApply() || !LTZTargetRegionFollowsIPEnabled()) return orig;
    NSString *tzName = LTZPinnedTimeZoneName();
    if (!tzName.length) return orig;
    NSTimeZone *tz = [NSTimeZone timeZoneWithName:tzName];
    return tz ?: orig;
}

+ (NSTimeZone *)defaultTimeZone {
    NSTimeZone *orig = %orig;
    if (!LTZShouldApply() || !LTZTargetRegionFollowsIPEnabled()) return orig;
    NSString *tzName = LTZPinnedTimeZoneName();
    if (!tzName.length) return orig;
    NSTimeZone *tz = [NSTimeZone timeZoneWithName:tzName];
    return tz ?: orig;
}

%end

%ctor {
    @autoreleasepool {
        // Install only for scoped apps or Safari stack.
        if (!LTZShouldApply()) return;
        %init;
        PXLog(@"[LocaleTimeZone] Hooks initialized");
    }
}
