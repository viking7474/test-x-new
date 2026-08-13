#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "BatteryManager.h"
#import "IdentifierManager.h"
#import "PXScope.h"
#import "PXPaths.h"
#import "PXFileDebug.h"
#import <os/lock.h>



// Shared profile battery snapshot (level + LPM) — short TTL, one file read
typedef struct {
    float level;
    BOOL hasLevel;
    BOOL lowPowerMode;
    BOOL hasLPM;
    NSTimeInterval loadedAt;
} PXBatterySnapshot;

static os_unfair_lock gBatterySnapshotLock = OS_UNFAIR_LOCK_INIT;
static PXBatterySnapshot gBatterySnap = {0};
static const NSTimeInterval kBatterySnapTTL = 2.0;

static PXBatterySnapshot PXReadBatterySnapshot(void) {
    os_unfair_lock_lock(&gBatterySnapshotLock);
    PXBatterySnapshot snapshot = gBatterySnap;
    os_unfair_lock_unlock(&gBatterySnapshotLock);
    return snapshot;
}

static void PXPublishBatterySnapshot(PXBatterySnapshot snapshot) {
    os_unfair_lock_lock(&gBatterySnapshotLock);
    gBatterySnap = snapshot;
    os_unfair_lock_unlock(&gBatterySnapshotLock);
}

static BOOL gHavePostedLPM = NO;
static BOOL gLastPostedLPM = NO;

// Prevent: hook_batteryLevel → sharedManager → init → UIDevice.batteryLevel → hook again
// (dispatch_once reentrancy → SIGTRAP).
static __thread int gPXBatterySnapshotDepth = 0;

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
    return PXScopedAppsSnapshot();
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
    NSString *identityPath = PXActiveProfileIdentityPath();
    NSString *profileRoot = PXActiveProfileRootPath();
    if (!identityPath.length || !profileRoot.length) return nil;

    NSString *canonical = [identityPath stringByAppendingPathComponent:@"battery_info.plist"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:canonical]) return canonical;
    NSString *legacy = [profileRoot stringByAppendingPathComponent:@"battery_info.plist"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:legacy]) return legacy;
    return canonical;
}

// Load level + LPM from the same profile snapshot (TTL cache).
// Prefer disk first so we never need BatteryManager while UIDevice hooks are active
// and the singleton is still initializing.
static PXBatterySnapshot PXGetBatterySnapshot(void) {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    PXBatterySnapshot current = PXReadBatterySnapshot();
    if (current.loadedAt > 0 && (now - current.loadedAt) < kBatterySnapTTL) {
        return current;
    }

    // Re-entrant call (e.g. UIDevice.batteryLevel during BatteryManager init): 
    // return last snapshot or empty — never touch sharedManager again.
    if (gPXBatterySnapshotDepth > 0) {
        return current;
    }

    gPXBatterySnapshotDepth++;

    PXBatterySnapshot snap = {0};
    snap.loadedAt = now;

    @try {
        // 1) Profile battery_info.plist (no ObjC singleton / no UIDevice)
        NSString *path = PXProfileBatteryInfoPath();
        NSDictionary *batteryInfo = path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
        if ([batteryInfo isKindOfClass:[NSDictionary class]]) {
            id levelObj = batteryInfo[@"BatteryLevel"];
            if ([levelObj isKindOfClass:[NSString class]] || [levelObj isKindOfClass:[NSNumber class]]) {
                float v = [levelObj floatValue];
                if (v >= 0.01f && v <= 1.0f) {
                    snap.level = v;
                    snap.hasLevel = YES;
                }
            }
            if (batteryInfo[@"LowPowerMode"] != nil) {
                snap.lowPowerMode = [batteryInfo[@"LowPowerMode"] boolValue];
                snap.hasLPM = YES;
            }
        }

        // 2) Optional BatteryManager fill — only if not already complete.
        // Skip if sharedManager is mid-init (dispatch_once not finished).
        if (!snap.hasLevel || !snap.hasLPM) {
            BatteryManager *shared = [BatteryManager sharedManager];
            if (shared) {
                if (!snap.hasLevel) {
                    NSString *level = [shared batteryLevel];
                    if ([level isKindOfClass:[NSString class]]) {
                        float v = [level floatValue];
                        if (v >= 0.01f && v <= 1.0f) {
                            snap.level = v;
                            snap.hasLevel = YES;
                        }
                    }
                }
                if (!snap.hasLPM) {
                    snap.lowPowerMode = [shared lowPowerModeEnabled] ? YES : NO;
                    snap.hasLPM = YES;
                }
            }
        }

        if (!snap.hasLPM) {
            snap.lowPowerMode = NO;
            snap.hasLPM = YES;
        }
    } @catch (__unused NSException *e) {
    }

    PXPublishBatterySnapshot(snap);
    gPXBatterySnapshotDepth--;
    return snap;
}

static void PXInvalidateBatterySnapshot(void) {
    PXBatterySnapshot empty = {0};
    PXPublishBatterySnapshot(empty);
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
    PXInvalidateScopeDecisionCache();
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
    // If snapshot load re-enters (BatteryManager init), always pass through original.
    if (gPXBatterySnapshotDepth > 0) {
        return orig_batteryLevel ? orig_batteryLevel(self, _cmd) : -1.0f;
    }
    if (isBatterySpoofingEnabled()) {
        PXBatterySnapshot snap = PXGetBatterySnapshot();
        if (snap.hasLevel) {
            return snap.level;
        }
    }
    float realValue = orig_batteryLevel ? orig_batteryLevel(self, _cmd) : -1.0f;
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
    if (gPXBatterySnapshotDepth > 0) {
        return orig_isLowPowerModeEnabled ? orig_isLowPowerModeEnabled(self, _cmd) : NO;
    }
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
                                        CFSTR("com.hydra.tlinkios.settings.changed"), NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwin, NULL, batterySettingsChanged,
                                        CFSTR("com.hydra.tlinkios.profileChanged"), NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwin, NULL, batterySettingsChanged,
                                        CFSTR("com.hydra.tlinkios.battery.updated"), NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        // Seed LPM observation baseline without posting on first load.
        // Prefer plist-only path (PXGetBatterySnapshot) — safe under installed UIDevice hooks.
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
