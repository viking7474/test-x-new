// LocaleTimeZoneHooks.x
// Canonical locale + timezone projection for Target Region / Time Spoof modes.

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <time.h>
#import <stdlib.h>

#import "TLinkIOSLogging.h"
#import "PXScope.h"

static NSString *const kSecuritySettingsPath_LTZ = @"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist";
static char kPXLocaleTimeZoneControllerStateKey;

static BOOL LTZShouldApply(void) {
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    NSString *processName = NSProcessInfo.processInfo.processName;
    BOOL bundleScoped = PXBundleIsEnabledInScope(bundleID);
    PXScopeOptions options = bundleScoped ? PXScopeOptionNone : PXScopeOptionAllowSafariAuthStack;
    return PXProcessIsAllowedForSpoofing(bundleID, processName, options);
}

static NSDictionary *LTZSecuritySettings(void) {
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:kSecuritySettingsPath_LTZ];
    return [settings isKindOfClass:[NSDictionary class]] ? settings : @{};
}

static BOOL LTZTargetRegionEnabled(void) {
    return [LTZSecuritySettings()[@"targetRegionFollowsIPEnabled"] boolValue];
}

static NSInteger LTZTimeSpoofingMode(void) {
    NSInteger mode = [LTZSecuritySettings()[@"timeSpoofingMode"] integerValue];
    return (mode >= 0 && mode <= 2) ? mode : 0;
}

static NSString *LTZPinnedLocaleIdentifier(void) {
    id value = LTZSecuritySettings()[@"targetRegionPinnedLocaleIdentifier"];
    return [value isKindOfClass:[NSString class]] && [value length] ? value : nil;
}

static NSArray<NSString *> *LTZPinnedPreferredLanguages(void) {
    id value = LTZSecuritySettings()[@"targetRegionPinnedPreferredLanguages"];
    return [value isKindOfClass:[NSArray class]] && [value count] ? value : nil;
}

static NSString *LTZEffectiveTimeZoneName(void) {
    NSDictionary *settings = LTZSecuritySettings();
    NSInteger mode = [settings[@"timeSpoofingMode"] integerValue];
    id value = nil;
    if (mode == 1) {
        value = settings[@"timeSpoofIPAddressTimeZoneName"];
        if (![value isKindOfClass:[NSString class]] || ![value length]) {
            value = settings[@"targetRegionPinnedTimeZoneName"];
        }
    } else if (mode == 2) {
        value = settings[@"timeSpoofLocationTimeZoneName"];
    } else {
        return nil;
    }
    if (![value isKindOfClass:[NSString class]] || ![value length]) return nil;
    return [NSTimeZone timeZoneWithName:value] ? value : nil;
}

static NSTimeZone *LTZEffectiveTimeZone(void) {
    NSString *name = LTZEffectiveTimeZoneName();
    return name.length ? [NSTimeZone timeZoneWithName:name] : nil;
}

static void LTZApplyProcessTimeZone(void) {
    static dispatch_once_t onceToken;
    static char *originalTZ = NULL;
    static BOOL hadOriginalTZ = NO;
    dispatch_once(&onceToken, ^{
        const char *current = getenv("TZ");
        if (current) {
            originalTZ = strdup(current);
            hadOriginalTZ = YES;
        }
    });

    NSString *name = LTZShouldApply() ? LTZEffectiveTimeZoneName() : nil;
    if (name.length) {
        setenv("TZ", name.UTF8String, 1);
    } else if (hadOriginalTZ && originalTZ) {
        setenv("TZ", originalTZ, 1);
    } else {
        unsetenv("TZ");
    }
    tzset();
}

%group PXLocaleTimeZoneRuntime

%hook NSLocale
+ (NSLocale *)currentLocale {
    NSLocale *original = %orig;
    if (!LTZShouldApply() || !LTZTargetRegionEnabled()) return original;
    NSString *identifier = LTZPinnedLocaleIdentifier();
    return identifier.length ? [NSLocale localeWithLocaleIdentifier:identifier] : original;
}
+ (NSLocale *)autoupdatingCurrentLocale {
    NSLocale *original = %orig;
    if (!LTZShouldApply() || !LTZTargetRegionEnabled()) return original;
    NSString *identifier = LTZPinnedLocaleIdentifier();
    return identifier.length ? [NSLocale localeWithLocaleIdentifier:identifier] : original;
}
+ (NSArray<NSString *> *)preferredLanguages {
    NSArray *original = %orig;
    if (!LTZShouldApply() || !LTZTargetRegionEnabled()) return original;
    NSArray *languages = LTZPinnedPreferredLanguages();
    return languages.count ? languages : original;
}
%end

%hook NSTimeZone
+ (NSTimeZone *)localTimeZone {
    NSTimeZone *original = %orig;
    if (!LTZShouldApply() || LTZTimeSpoofingMode() == 0) return original;
    return LTZEffectiveTimeZone() ?: original;
}
+ (NSTimeZone *)systemTimeZone {
    NSTimeZone *original = %orig;
    if (!LTZShouldApply() || LTZTimeSpoofingMode() == 0) return original;
    return LTZEffectiveTimeZone() ?: original;
}
+ (NSTimeZone *)defaultTimeZone {
    NSTimeZone *original = %orig;
    if (!LTZShouldApply() || LTZTimeSpoofingMode() == 0) return original;
    return LTZEffectiveTimeZone() ?: original;
}
%end

%hookf(CFLocaleRef, CFLocaleCopyCurrent) {
    if (LTZShouldApply() && LTZTargetRegionEnabled()) {
        NSString *identifier = LTZPinnedLocaleIdentifier();
        if (identifier.length) return CFLocaleCreate(kCFAllocatorDefault, (__bridge CFStringRef)identifier);
    }
    return %orig;
}

%hookf(CFArrayRef, CFLocaleCopyPreferredLanguages) {
    if (LTZShouldApply() && LTZTargetRegionEnabled()) {
        NSArray *languages = LTZPinnedPreferredLanguages();
        if (languages.count) return (__bridge_retained CFArrayRef)[languages copy];
    }
    return %orig;
}

%hookf(CFTimeZoneRef, CFTimeZoneCopySystem) {
    NSString *name = (LTZShouldApply() && LTZTimeSpoofingMode() != 0) ? LTZEffectiveTimeZoneName() : nil;
    if (name.length) return CFTimeZoneCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)name, true);
    return %orig;
}

%hookf(CFTimeZoneRef, CFTimeZoneCopyDefault) {
    NSString *name = (LTZShouldApply() && LTZTimeSpoofingMode() != 0) ? LTZEffectiveTimeZoneName() : nil;
    if (name.length) return CFTimeZoneCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)name, true);
    return %orig;
}

%end

static NSString *LTZJavaScriptJSONValue(NSString *timeZoneName) {
    id value = timeZoneName.length ? timeZoneName : [NSNull null];
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[value] options:0 error:nil];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"[null]";
}

// Called by the canonical WKUserContentController owner in CanvasFingerprintHooks.x.
void PXInstallLocaleTimeZoneUserScript(WKUserContentController *controller) {
    if (!controller || !LTZShouldApply()) return;
    NSString *timeZoneName = LTZEffectiveTimeZoneName();
    NSString *state = timeZoneName ?: @"<off>";
    NSString *previous = objc_getAssociatedObject(controller, &kPXLocaleTimeZoneControllerStateKey);
    if ([previous isEqualToString:state]) return;

    BOOL hasBase = NO;
    for (WKUserScript *script in controller.userScripts) {
        if ([script.source containsString:@"__weaponx_timezone_spoof__"]) { hasBase = YES; break; }
    }
    if (!hasBase) {
        NSString *base =
        @"// __weaponx_timezone_spoof__\n"
        @"(()=>{const g=globalThis;if(g.__weaponx_timezone_base__)return;"
        @"g.__weaponx_timezone_base__=true;g.__weaponx_timezone_value__=null;"
        @"const ro=Intl.DateTimeFormat.prototype.resolvedOptions;"
        @"Intl.DateTimeFormat.prototype.resolvedOptions=function(){const o=ro.call(this);const z=g.__weaponx_timezone_value__;return z?Object.assign({},o,{timeZone:z}):o;};"
        @"const go=Date.prototype.getTimezoneOffset;"
        @"Date.prototype.getTimezoneOffset=function(){const z=g.__weaponx_timezone_value__;if(!z)return go.call(this);try{"
        @"const p=new Intl.DateTimeFormat('en-US',{timeZone:z,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'}).formatToParts(this);"
        @"const m={};for(const x of p)m[x.type]=x.value;const u=Date.UTC(+m.year,+m.month-1,+m.day,+m.hour,+m.minute,+m.second);return Math.round((this.getTime()-u)/60000);}catch(e){return go.call(this);}};})();";
        WKUserScript *script = [[WKUserScript alloc] initWithSource:base
                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                   forMainFrameOnly:NO];
        [controller addUserScript:script];
    }

    NSString *config = [NSString stringWithFormat:
        @"// __weaponx_timezone_config__\n(()=>{globalThis.__weaponx_timezone_value__=(%@)[0];})();",
        LTZJavaScriptJSONValue(timeZoneName)];
    WKUserScript *configScript = [[WKUserScript alloc] initWithSource:config
                                                        injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                     forMainFrameOnly:NO];
    [controller addUserScript:configScript];
    objc_setAssociatedObject(controller, &kPXLocaleTimeZoneControllerStateKey, state, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

BOOL PXLocaleTimeZoneWebSpoofActive(void) {
    return LTZShouldApply() && LTZEffectiveTimeZoneName().length > 0;
}

static void LTZSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name,
                               const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ LTZApplyProcessTimeZone(); });
}

%ctor {
    @autoreleasepool {
        if (!LTZShouldApply()) return;
        %init(PXLocaleTimeZoneRuntime);
        LTZApplyProcessTimeZone();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                        LTZSettingsChanged,
                                        CFSTR("com.hydra.tlinkios.settings.changed"), NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                        LTZSettingsChanged,
                                        CFSTR("com.hydra.tlinkios.profileChanged"), NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        PXLog(@"[LocaleTimeZone] Locale, timezone, libc and WebKit surfaces initialized");
    }
}
