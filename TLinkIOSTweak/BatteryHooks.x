#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "BatteryManager.h"
#import "IdentifierManager.h"
#import "PXScope.h"
#import "PXPaths.h"
#import "PXRuntimeSnapshot.h"
#import "PXFileDebug.h"
#import <os/lock.h>
#include <math.h>
#include <stdint.h>
#include <time.h>



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
static uint64_t gBatterySnapshotGeneration = 0;
static const NSTimeInterval kBatterySnapTTL = 2.0;

static NSTimeInterval PXBatterySnapshotTime(void) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    return 0; // Captured reads do not use the live cache clock.
#else
    struct timespec instant = {0};
    if (clock_gettime(CLOCK_MONOTONIC, &instant) != 0) return NAN;
    return (NSTimeInterval)instant.tv_sec + (NSTimeInterval)instant.tv_nsec / 1e9;
#endif
}

static PXBatterySnapshot PXReadBatterySnapshot(uint64_t *generation) {
    os_unfair_lock_lock(&gBatterySnapshotLock);
    if (generation) *generation = gBatterySnapshotGeneration;
    PXBatterySnapshot snapshot = gBatterySnap;
    os_unfair_lock_unlock(&gBatterySnapshotLock);
    return snapshot;
}

static BOOL PXPublishBatterySnapshot(PXBatterySnapshot snapshot, uint64_t generation) {
    os_unfair_lock_lock(&gBatterySnapshotLock);
    BOOL accepted = generation == gBatterySnapshotGeneration;
    // Clock failure may serve a current one-shot read, but cannot retain it.
    if (accepted) {
        if (isfinite(snapshot.loadedAt) && snapshot.loadedAt > 0) gBatterySnap = snapshot;
        else { PXBatterySnapshot empty = {0}; gBatterySnap = empty; }
    }
    os_unfair_lock_unlock(&gBatterySnapshotLock);
    return accepted;
}

// LPM baseline and accepted notification submissions share gBatterySnapshotLock.
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
    PX_RUNTIME_READ_OPERATION;
    return PXScopedAppsSnapshot();
}

// Helper: check if current app is in scoped apps list and enabled
static BOOL isInScopedAppsList(void) {
    PX_RUNTIME_READ_OPERATION;
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
    PX_RUNTIME_READ_OPERATION;
    if (!bundleID) return NO;
    NSString *proc = [NSProcessInfo processInfo].processName;
    return PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionNone);
}

// Helper to check if battery spoofing is enabled for this app/profile
static BOOL isBatterySpoofingEnabled(void) {
    PX_RUNTIME_READ_OPERATION;
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
    NSString *profileID = nil, *identityPath = nil, *canonical = nil, *legacy = nil;
    NSFileManager *manager = nil;
    @try {
        // Resolve selection once; both candidate paths belong to that ID.
        profileID = [PXActiveProfileID() copy];
        if (![profileID isKindOfClass:NSString.class] || !profileID.length) return nil;
        identityPath = PXProfileIdentityPath(profileID);
        if (!identityPath.length) return nil;
        manager = NSFileManager.defaultManager;
        canonical = [identityPath stringByAppendingPathComponent:@"battery_info.plist"];
        if ([manager fileExistsAtPath:canonical]) return canonical;
        legacy = [identityPath.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"battery_info.plist"];
        if ([manager fileExistsAtPath:legacy]) return legacy;
        return canonical;
    } @finally { manager = nil; legacy = nil; canonical = nil; identityPath = nil; profileID = nil; }
}

// Load level + LPM from the same profile snapshot (TTL cache).
// Prefer disk first so we never need BatteryManager while UIDevice hooks are active
// and the singleton is still initializing.
static PXBatterySnapshot PXGetBatterySnapshot(void) {
    PX_RUNTIME_READ_OPERATION;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    PXBatterySnapshot snap = {0};
    snap.loadedAt = [NSDate timeIntervalSinceReferenceDate];
    PXRuntimeReadSnapshot *runtimeView = PXCaptureRuntimeSnapshot();
    NSDictionary *runtimeBattery = [runtimeView profileArtifact:@"batteryInfo"];
    NSDictionary *runtimeIDs = runtimeView.deviceIDs;
    id runtimeLevel = runtimeBattery[@"BatteryLevel"] ?: runtimeIDs[@"BatteryLevel"];
    id runtimeLPM = runtimeBattery[@"LowPowerMode"] ?: runtimeIDs[@"LowPowerMode"];
    if ([runtimeLevel isKindOfClass:NSString.class] || [runtimeLevel isKindOfClass:NSNumber.class]) {
        float v = [runtimeLevel floatValue];
        if (v >= 0.01f && v <= 1.0f) { snap.level = v; snap.hasLevel = YES; }
    }
    if (runtimeLPM != nil) { snap.lowPowerMode = PXRuntimeReadBool(runtimeLPM); snap.hasLPM = YES; }
    return snap;
#else
    NSTimeInterval now = PXBatterySnapshotTime();
    uint64_t generation = 0;
    PXBatterySnapshot current = PXReadBatterySnapshot(&generation);
    if (isfinite(now) && isfinite(current.loadedAt) && current.loadedAt > 0 && now >= current.loadedAt &&
        (now - current.loadedAt) < kBatterySnapTTL) {
        return current;
    }
    // Reentry must never touch the singleton again; hook-level guards still
    // forward to originals while this thread prepares a snapshot.
    if (gPXBatterySnapshotDepth > 0) return current;
    gPXBatterySnapshotDepth++;
    PXBatterySnapshot snap = {0};
    snap.loadedAt = isfinite(now) && now > 0 ? now : 0;
    NSString *path = nil, *level = nil;
    NSDictionary *batteryInfo = nil;
    id levelObj = nil, lowPowerObj = nil;
    BatteryManager *shared = nil;
    @try {
        @try {
            // Disk first, retaining the existing optional-manager fallback.
            path = PXProfileBatteryInfoPath();
            batteryInfo = path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
            if ([batteryInfo isKindOfClass:NSDictionary.class]) {
                levelObj = batteryInfo[@"BatteryLevel"];
                if ([levelObj isKindOfClass:NSString.class] || [levelObj isKindOfClass:NSNumber.class]) {
                    float v = [levelObj floatValue];
                    if (v >= 0.01f && v <= 1.0f) { snap.level = v; snap.hasLevel = YES; }
                }
                lowPowerObj = batteryInfo[@"LowPowerMode"];
                if ([lowPowerObj isKindOfClass:NSString.class] || [lowPowerObj isKindOfClass:NSNumber.class]) {
                    snap.lowPowerMode = [lowPowerObj boolValue]; snap.hasLPM = YES;
                }
            }
            if (!snap.hasLevel || !snap.hasLPM) {
                shared = [BatteryManager sharedManager];
                if (shared) {
                    if (!snap.hasLevel) {
                        level = [shared batteryLevel];
                        if ([level isKindOfClass:NSString.class]) {
                            float v = [level floatValue];
                            if (v >= 0.01f && v <= 1.0f) { snap.level = v; snap.hasLevel = YES; }
                        }
                    }
                    if (!snap.hasLPM) {
                        snap.lowPowerMode = [shared lowPowerModeEnabled] ? YES : NO; snap.hasLPM = YES;
                    }
                }
            }
            if (!snap.hasLPM) { snap.lowPowerMode = NO; snap.hasLPM = YES; }
        } @catch (__unused NSException *exception) {
        }
        if (!PXPublishBatterySnapshot(snap, generation)) {
            // A notification revoked this read. Do not repopulate or return it,
            // and do not substitute a winner that may belong to another profile.
            PXBatterySnapshot unavailable = {0}; return unavailable;
        }
        return snap;
    } @finally {
        @try {
            shared = nil; lowPowerObj = nil; levelObj = nil;
            batteryInfo = nil; level = nil; path = nil;
        } @finally { gPXBatterySnapshotDepth--; }
    }
#endif
}

static uint64_t PXInvalidateBatterySnapshot(void) {
    os_unfair_lock_lock(&gBatterySnapshotLock);
    uint64_t generation = ++gBatterySnapshotGeneration;
    PXBatterySnapshot empty = {0}; gBatterySnap = empty;
    os_unfair_lock_unlock(&gBatterySnapshotLock);
    return generation;
}

static void PXObserveBatteryLowPowerMode(BOOL enabled, uint64_t generation, BOOL seedOnly) {
    os_unfair_lock_lock(&gBatterySnapshotLock);
    if (generation == gBatterySnapshotGeneration && (!seedOnly || !gHavePostedLPM)) {
        BOOL changed = !gHavePostedLPM || gLastPostedLPM != enabled;
        gHavePostedLPM = YES;
        gLastPostedLPM = enabled;
        if (!seedOnly && changed) {
            // This capture-free async submission stays in the decision lock to
            // preserve accepted transition order. Observer execution is outside
            // the lock on the main queue; never synchronously wait here.
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:NSProcessInfoPowerStateDidChangeNotification
                                  object:[NSProcessInfo processInfo]];
            });
        }
    }
    os_unfair_lock_unlock(&gBatterySnapshotLock);
}

static void PXSeedBatteryLPMBaseline(void) {
    uint64_t generation = 0;
    (void)PXReadBatterySnapshot(&generation);
    if (!isBatterySpoofingEnabled()) return;
    PXBatterySnapshot snap = PXGetBatterySnapshot();
    if (snap.hasLPM) PXObserveBatteryLowPowerMode(snap.lowPowerMode, generation, YES);
}

static void batterySettingsChanged(CFNotificationCenterRef center,
                                   void *observer,
                                   CFStringRef name,
                                   const void *object,
                                   CFDictionaryRef userInfo) {
    // Claim before capture/scope/provider work can reenter or yield to another
    // settings callback. The receipt also revokes in-flight live cache loads.
    uint64_t generation = PXInvalidateBatterySnapshot();
    PX_RUNTIME_READ_OPERATION;
    PXInvalidateScopeDecisionCache();
    if (!isBatterySpoofingEnabled()) return;
    PXBatterySnapshot snap = PXGetBatterySnapshot();
    if (snap.hasLPM) PXObserveBatteryLowPowerMode(snap.lowPowerMode, generation, NO);
}

// Hook for -[UIDevice batteryLevel]
static float (*orig_batteryLevel)(UIDevice *, SEL);
static float hook_batteryLevel(UIDevice *self, SEL _cmd) {
    PX_RUNTIME_READ_OPERATION;
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
    PX_RUNTIME_READ_OPERATION;
    if (isBatterySpoofingEnabled()) {
        return 1; // UIDeviceBatteryStateUnplugged
    }
    NSInteger realState = orig_batteryState(self, _cmd);
    return realState;
}

// Hook for -[NSProcessInfo isLowPowerModeEnabled]
static BOOL (*orig_isLowPowerModeEnabled)(NSProcessInfo *, SEL);
static BOOL hook_isLowPowerModeEnabled(NSProcessInfo *self, SEL _cmd) {
    PX_RUNTIME_READ_OPERATION;
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
        if (!PXBootstrapAllows(PXHookCapabilityNative)) return;
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
        PXSeedBatteryLPMBaseline();

        PXFileDebugAIDA64Log("[Battery.ctor] exit");
    }
}
