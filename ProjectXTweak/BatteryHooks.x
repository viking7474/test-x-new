#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "BatteryManager.h"
#import "IdentifierManager.h"
#import "PXScope.h"
#import "PXFileDebug.h"

// Path to scoped apps plist
static NSString *const kScopedAppsPath = @"/var/mobile/Library/Preferences/com.hydra.projectx.global_scope.plist";
static NSString *const kScopedAppsPathAlt1 = @"/private/var/mobile/Library/Preferences/com.hydra.projectx.global_scope.plist";

// Scoped apps cache
static NSMutableDictionary *scopedAppsCache = nil;
static NSDate *scopedAppsCacheTimestamp = nil;
static const NSTimeInterval kScopedAppsCacheValidDuration = 60.0; // 1 minute

// Bundle decision cache
static NSMutableDictionary *cachedBundleDecisions = nil;
static NSTimeInterval kCacheValidityDuration = 300.0; // 5 minutes

// Shared profile battery snapshot (level + LPM) — short TTL, one file read
typedef struct {
    float level;
    BOOL hasLevel;
    BOOL lowPowerMode;
    BOOL hasLPM;
    NSTimeInterval loadedAt;
} PXBatterySnapshot;

static PXBatterySnapshot gBatterySnap = {0};
static const NSTimeInterval kBatterySnapTTL = 2.0;

static BOOL gHavePostedLPM = NO;
static BOOL gLastPostedLPM = NO;

// Helper: get current bundle ID
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

// Helper: load scoped apps from plist (with cache)
static NSDictionary *loadScopedApps(void) {
    @try {
        if (scopedAppsCache && scopedAppsCacheTimestamp &&
            [[NSDate date] timeIntervalSinceDate:scopedAppsCacheTimestamp] < kScopedAppsCacheValidDuration) {
            return scopedAppsCache;
        }
        if (!scopedAppsCache) {
            scopedAppsCache = [NSMutableDictionary dictionary];
        } else {
            [scopedAppsCache removeAllObjects];
        }
        NSArray *possiblePaths = @[kScopedAppsPath, kScopedAppsPathAlt1];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *validPath = nil;
        for (NSString *path in possiblePaths) {
            if ([fileManager fileExistsAtPath:path]) {
                validPath = path;
                break;
            }
        }
        if (!validPath) {
            scopedAppsCacheTimestamp = [NSDate date];
            return scopedAppsCache;
        }
        NSDictionary *plistDict = [NSDictionary dictionaryWithContentsOfFile:validPath];
        if (!plistDict || ![plistDict isKindOfClass:[NSDictionary class]]) {
            scopedAppsCacheTimestamp = [NSDate date];
            return scopedAppsCache;
        }
        NSDictionary *scopedApps = plistDict[@"ScopedApps"];
        if (!scopedApps || ![scopedApps isKindOfClass:[NSDictionary class]]) {
            scopedAppsCacheTimestamp = [NSDate date];
            return scopedAppsCache;
        }
        [scopedAppsCache addEntriesFromDictionary:scopedApps];
        scopedAppsCacheTimestamp = [NSDate date];
        return scopedAppsCache;
    } @catch (NSException *e) {
        scopedAppsCacheTimestamp = [NSDate date];
        return scopedAppsCache ?: [NSMutableDictionary dictionary];
    }
}

// Helper: check if current app is in scoped apps list and enabled
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
        id appEntry = scopedApps[bundleID];
        if (!appEntry || ![appEntry isKindOfClass:[NSDictionary class]]) {
            return NO;
        }
        BOOL isEnabled = [appEntry[@"enabled"] boolValue];
        return isEnabled;
    } @catch (NSException *e) {
        return NO;
    }
}

// Helper: should spoof battery for this bundle (with cache)
static BOOL shouldSpoofBatteryForBundle(NSString *bundleID) {
    if (!bundleID) return NO;
    NSString *proc = [NSProcessInfo processInfo].processName;
    return PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionNone);
}

// Helper to check if battery spoofing is enabled for this app/profile
static BOOL isBatterySpoofingEnabled(void) {
    @try {
        NSString *bundleID = getCurrentBundleID();
        if (!bundleID) {
            return NO;
        }
        if (!shouldSpoofBatteryForBundle(bundleID)) {
            return NO;
        }
        Class managerClass = NSClassFromString(@"IdentifierManager");
        if (!managerClass) {
            return NO;
        }
        id manager = [managerClass respondsToSelector:@selector(sharedManager)] ? [managerClass sharedManager] : nil;
        if (!manager) {
            return NO;
        }
        SEL isEnabledSel = NSSelectorFromString(@"isIdentifierEnabled:");
        if (![manager respondsToSelector:isEnabledSel]) {
            return NO;
        }
        NSString *batteryStr = @"Battery";
        BOOL enabled = NO;
        NSMethodSignature *sig = [manager methodSignatureForSelector:isEnabledSel];
        if (sig) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
            [invocation setSelector:isEnabledSel];
            [invocation setTarget:manager];
            [invocation setArgument:&batteryStr atIndex:2];
            [invocation invoke];
            [invocation getReturnValue:&enabled];
        }
        return enabled;
    } @catch (...) {
        return NO;
    }
}

static NSString *PXProfileBatteryInfoPath(void) {
    NSArray *candidates = @[
        @"/var/mobile/Library/WeaponX/Profiles/current_profile_info.plist",
        @"/private/var/mobile/Library/WeaponX/Profiles/current_profile_info.plist"
    ];
    NSDictionary *currentProfileInfo = nil;
    for (NSString *p in candidates) {
        currentProfileInfo = [NSDictionary dictionaryWithContentsOfFile:p];
        if (currentProfileInfo[@"ProfileId"]) break;
    }
    NSString *profileId = currentProfileInfo[@"ProfileId"];
    if (![profileId isKindOfClass:[NSString class]] || !profileId.length) return nil;

    // Prefer identity/battery_info.plist (canonical); fall back to profile-root legacy.
    NSArray *bases = @[
        [NSString stringWithFormat:@"/var/mobile/Library/WeaponX/Profiles/%@", profileId],
        [NSString stringWithFormat:@"/private/var/mobile/Library/WeaponX/Profiles/%@", profileId]
    ];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *base in bases) {
        NSString *identityPath = [[base stringByAppendingPathComponent:@"identity"]
                                  stringByAppendingPathComponent:@"battery_info.plist"];
        if ([fm fileExistsAtPath:identityPath]) {
            return identityPath;
        }
    }
    for (NSString *base in bases) {
        NSString *legacyPath = [base stringByAppendingPathComponent:@"battery_info.plist"];
        if ([fm fileExistsAtPath:legacyPath]) {
            return legacyPath;
        }
    }
    // Prefer canonical identity path even if missing (callers handle nil dict)
    return [[bases.firstObject stringByAppendingPathComponent:@"identity"]
            stringByAppendingPathComponent:@"battery_info.plist"];
}

// Load level + LPM from the same profile snapshot (TTL cache).
static PXBatterySnapshot PXGetBatterySnapshot(void) {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (gBatterySnap.loadedAt > 0 && (now - gBatterySnap.loadedAt) < kBatterySnapTTL) {
        return gBatterySnap;
    }

    PXBatterySnapshot snap = {0};
    snap.loadedAt = now;

    @try {
        // Prefer BatteryManager when available (same profile source).
        // Cast to BatteryManager* so the compiler does not confuse -[BatteryManager batteryLevel]
        // (NSString *) with -[UIDevice batteryLevel] (float).
        BatteryManager *shared = [BatteryManager sharedManager];
        if (shared) {
            NSString *level = [shared batteryLevel];
            if ([level isKindOfClass:[NSString class]]) {
                float v = [level floatValue];
                if (v >= 0.01f && v <= 1.0f) {
                    snap.level = v;
                    snap.hasLevel = YES;
                }
            }
            snap.lowPowerMode = [shared lowPowerModeEnabled] ? YES : NO;
            snap.hasLPM = YES;
        }

        // Fallback / fill gaps from battery_info.plist (single read)
        if (!snap.hasLevel || !snap.hasLPM) {
            NSString *path = PXProfileBatteryInfoPath();
            NSDictionary *batteryInfo = path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
            if ([batteryInfo isKindOfClass:[NSDictionary class]]) {
                if (!snap.hasLevel) {
                    NSString *level = batteryInfo[@"BatteryLevel"];
                    if ([level isKindOfClass:[NSString class]] || [level isKindOfClass:[NSNumber class]]) {
                        float v = [level floatValue];
                        if (v >= 0.01f && v <= 1.0f) {
                            snap.level = v;
                            snap.hasLevel = YES;
                        }
                    }
                }
                if (!snap.hasLPM && batteryInfo[@"LowPowerMode"] != nil) {
                    snap.lowPowerMode = [batteryInfo[@"LowPowerMode"] boolValue];
                    snap.hasLPM = YES;
                }
            }
        }

        // Default LPM when Battery is enabled but key missing
        if (!snap.hasLPM) {
            snap.lowPowerMode = NO;
            snap.hasLPM = YES;
        }
    } @catch (__unused NSException *e) {
    }

    gBatterySnap = snap;
    return snap;
}

static void PXInvalidateBatterySnapshot(void) {
    gBatterySnap.loadedAt = 0;
}

static void PXMaybePostLPMChangeNotification(void) {
    if (!isBatterySpoofingEnabled()) return;

    PXBatterySnapshot snap = PXGetBatterySnapshot();
    if (!snap.hasLPM) return;

    if (!gHavePostedLPM || gLastPostedLPM != snap.lowPowerMode) {
        gHavePostedLPM = YES;
        gLastPostedLPM = snap.lowPowerMode;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:NSProcessInfoPowerStateDidChangeNotification
                              object:[NSProcessInfo processInfo]];
        });
    }
}

static void batterySettingsChanged(CFNotificationCenterRef center,
                                   void *observer,
                                   CFStringRef name,
                                   const void *object,
                                   CFDictionaryRef userInfo) {
    BOOL previousLPM = gHavePostedLPM ? gLastPostedLPM : NO;
    BOOL hadPrevious = gHavePostedLPM;

    PXInvalidateBatterySnapshot();

    if (!isBatterySpoofingEnabled()) {
        return;
    }

    PXBatterySnapshot snap = PXGetBatterySnapshot();
    if (snap.hasLPM && (!hadPrevious || previousLPM != snap.lowPowerMode)) {
        gHavePostedLPM = YES;
        gLastPostedLPM = snap.lowPowerMode;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:NSProcessInfoPowerStateDidChangeNotification
                              object:[NSProcessInfo processInfo]];
        });
    }
}

// Hook for -[UIDevice batteryLevel]
static float (*orig_batteryLevel)(UIDevice *, SEL);
static float hook_batteryLevel(UIDevice *self, SEL _cmd) {
    if (isBatterySpoofingEnabled()) {
        PXBatterySnapshot snap = PXGetBatterySnapshot();
        if (snap.hasLevel) {
            return snap.level;
        }
    }
    float realValue = orig_batteryLevel(self, _cmd);
    return realValue;
}

// Optionally, hook batteryState (returns UIDeviceBatteryState)
static NSInteger (*orig_batteryState)(UIDevice *, SEL);
static NSInteger hook_batteryState(UIDevice *self, SEL _cmd) {
    if (isBatterySpoofingEnabled()) {
        return 1; // UIDeviceBatteryStateUnplugged
    }
    NSInteger realState = orig_batteryState(self, _cmd);
    return realState;
}

// Hook for -[NSProcessInfo isLowPowerModeEnabled]
static BOOL (*orig_isLowPowerModeEnabled)(NSProcessInfo *, SEL);
static BOOL hook_isLowPowerModeEnabled(NSProcessInfo *self, SEL _cmd) {
    if (isBatterySpoofingEnabled()) {
        PXBatterySnapshot snap = PXGetBatterySnapshot();
        if (snap.hasLPM) {
            return snap.lowPowerMode;
        }
    }
    if (orig_isLowPowerModeEnabled) {
        return orig_isLowPowerModeEnabled(self, _cmd);
    }
    return NO;
}

%ctor {
    @autoreleasepool {
        PXFileDebugAIDA64Log("[Battery.ctor] enter");
        NSString *bundleID = getCurrentBundleID();
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (!PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionNone)) {
            PXFileDebugAIDA64Log("[Battery.ctor] skip allowed=0 bundle=%s proc=%s", bundleID.UTF8String ?: "<nil>", proc.UTF8String ?: "<nil>");
            return;
        }

        Class deviceClass = objc_getClass("UIDevice");
        if (deviceClass) {
            PXFileDebugAIDA64Log("[Battery.ctor] before hook batteryLevel");
            MSHookMessageEx(deviceClass, @selector(batteryLevel), (IMP)hook_batteryLevel, (IMP *)&orig_batteryLevel);
            PXFileDebugAIDA64Log("[Battery.ctor] after hook batteryLevel");
            PXFileDebugAIDA64Log("[Battery.ctor] before hook batteryState");
            MSHookMessageEx(deviceClass, @selector(batteryState), (IMP)hook_batteryState, (IMP *)&orig_batteryState);
            PXFileDebugAIDA64Log("[Battery.ctor] after hook batteryState");
        }

        // Low Power Mode — only when selector exists
        Class processInfoClass = objc_getClass("NSProcessInfo");
        SEL lpmSel = @selector(isLowPowerModeEnabled);
        if (processInfoClass && class_getInstanceMethod(processInfoClass, lpmSel)) {
            PXFileDebugAIDA64Log("[Battery.ctor] before hook isLowPowerModeEnabled");
            MSHookMessageEx(processInfoClass, lpmSel, (IMP)hook_isLowPowerModeEnabled, (IMP *)&orig_isLowPowerModeEnabled);
            PXFileDebugAIDA64Log("[Battery.ctor] after hook isLowPowerModeEnabled");
        }

        CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
        CFNotificationCenterAddObserver(darwin, NULL, batterySettingsChanged,
                                        CFSTR("com.hydra.projectx.settings.changed"), NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwin, NULL, batterySettingsChanged,
                                        CFSTR("com.hydra.projectx.profileChanged"), NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwin, NULL, batterySettingsChanged,
                                        CFSTR("com.hydra.projectx.battery.updated"), NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        // Seed LPM observation baseline without posting on first load
        if (isBatterySpoofingEnabled()) {
            PXBatterySnapshot snap = PXGetBatterySnapshot();
            if (snap.hasLPM) {
                gHavePostedLPM = YES;
                gLastPostedLPM = snap.lowPowerMode;
            }
        }

        PXFileDebugAIDA64Log("[Battery.ctor] exit");
    }
}
