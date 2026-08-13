// LockdownIdentityHooks.x
// Runtime wiring for the Lockdown identity research providers (plan §4, Phases 5/6/7).
//
// This is the missing hook that routes real liblockdown value lookups through the
// safety-gated resolvers under research/. Until now PXLockdown*Resolve existed and
// was unit-tested, but nothing intercepted a live Lockdown lookup to call it.
//
// Safety model (plan §4.2 / §4.6):
//   * The ENTIRE body is gated behind INTERNAL_SECURITY_RESEARCH. The Makefile forces
//     that macro to 0 for FINALPACKAGE / release packages, so this file compiles to a
//     no-op object in every shipping build and links no research symbols.
//   * The interception is only armed for a process the research policy allowlists.
//   * Every path fails closed to the original Lockdown value; the resolvers + safety
//     runtime decide observe-only vs. profile-backed and never leak a mismatched value.

#ifndef INTERNAL_SECURITY_RESEARCH
#define INTERNAL_SECURITY_RESEARCH 0
#endif

#if INTERNAL_SECURITY_RESEARCH

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <substrate.h>
#import <dlfcn.h>
#import <os/lock.h>

#import "PXIdentitySnapshot.h"
#import "PXScope.h"
#import "TLinkIOSLogging.h"

#import "PXLockdownResearchSafety.h"
#import "PXLockdownSoftwareModelProvider.h"
#import "PXLockdownDeviceIdentityProvider.h"
#import "PXLockdownSoCCellularProvider.h"
#import "PXLockdownObservability.h"

#pragma mark - Process-local state

static os_unfair_lock gLockdownRuntimeLock = OS_UNFAIR_LOCK_INIT;
static PXLockdownResearchRuntime *gLockdownRuntime = nil;
static PXLockdownAccessMetrics *gLockdownMetrics = nil;
static __thread BOOL gInsideLockdownHook = NO;

// liblockdown device-side value lookup. Signature is resolved dynamically; if the
// symbol is unavailable the wiring stays a no-op and the original value is used.
static CFTypeRef (*orig_lockdown_copy_value)(void *client, CFStringRef domain, CFStringRef key);

#pragma mark - Runtime key -> provider constant-name mapping

// The resolvers identify keys by their documented firmware constant NAME
// (e.g. "kLockdownUniqueDeviceIDKey", plan §4.3), while liblockdown is queried with
// the bare runtime key (e.g. "UniqueDeviceID"). This table is the single translation
// point between the two namespaces.
static NSString *PXLockdownConstNameForRuntimeKey(NSString *runtimeKey) {
    if (![runtimeKey isKindOfClass:[NSString class]] || runtimeKey.length == 0) return nil;
    static NSDictionary<NSString *, NSString *> *map = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        map = @{
            // Device identity (Phase 6)
            @"UniqueDeviceID": @"kLockdownUniqueDeviceIDKey",
            @"SerialNumber": @"kLockdownSerialNumberKey",
            @"MLBSerialNumber": @"kLockdownMLBSerialNumberKey",
            // Software / model (Phase 5)
            @"ProductVersion": @"kLockdownProductVersionKey",
            @"BuildVersion": @"kLockdownBuildVersionKey",
            @"ProductType": @"kLockdownProductTypeKey",
            @"DeviceName": @"kLockdownDeviceNameKey",
            // SoC / cellular (Phase 7)
            @"UniqueChipID": @"kLockdownUniqueChipIDKey",
            @"InternationalMobileEquipmentIdentity": @"kLockdownIMEIKey",
            @"InternationalMobileEquipmentIdentity2": @"kLockdownSecondaryIMEIKey",
            @"SecondaryInternationalMobileEquipmentIdentity": @"kLockdownSecondaryIMEIKey",
            @"MobileEquipmentIdentifier": @"kLockdownMobileEquipmentIdentifierKey",
            @"BasebandVersion": @"kLockdownBasebandVersionKey",
            // Common aliases some callers use for the same underlying value.
            @"IMEI": @"kLockdownIMEIKey",
            @"IMEI2": @"kLockdownSecondaryIMEIKey",
            @"MEID": @"kLockdownMobileEquipmentIdentifierKey",
        };
    });
    NSString *mapped = map[runtimeKey];
    if (mapped) return mapped;
    // Callers that already use the firmware constant name pass straight through.
    if ([runtimeKey hasPrefix:@"kLockdown"]) return runtimeKey;
    return nil;
}

#pragma mark - Safety runtime

static void PXLockdownRebuildRuntime(void) {
    @try {
        PXIdentitySnapshot *snapshot = PXCurrentIdentitySnapshot();
        NSDictionary *settings = snapshot.settings ?: @{};
        PXLockdownResearchPolicy *policy = [PXLockdownResearchPolicy policyFromSettings:settings];
        PXLockdownResearchRuntime *runtime = [[PXLockdownResearchRuntime alloc] initWithPolicy:policy];
        // activateAt: must run after each process start; a persisted master switch never
        // arms a session on its own, so reboot / relaunch fails closed.
        [runtime activateAt:[NSDate date]];
        os_unfair_lock_lock(&gLockdownRuntimeLock);
        gLockdownRuntime = runtime;
        os_unfair_lock_unlock(&gLockdownRuntimeLock);
    } @catch (__unused NSException *e) {
    }
}

static PXLockdownResearchRuntime *PXLockdownCurrentRuntime(void) {
    os_unfair_lock_lock(&gLockdownRuntimeLock);
    PXLockdownResearchRuntime *runtime = gLockdownRuntime;
    os_unfair_lock_unlock(&gLockdownRuntimeLock);
    return runtime;
}

#pragma mark - Dispatcher

// Route one intercepted Lockdown lookup through the correct resolver. Fails closed to
// `original` on any uncertainty and emits only redacted, value-free audit metadata.
static id PXLockdownResolveInterceptedValue(NSString *runtimeKey, id original, NSString *rawDomain) {
    // Never observe or resolve forbidden pairing / certificate / private-key / escrow domains.
    if (PXLockdownObservationDomainIsForbidden(rawDomain)) return original;

    NSString *constName = PXLockdownConstNameForRuntimeKey(runtimeKey);
    if (!constName) return original; // key is outside the research scope

    PXLockdownResearchRuntime *runtime = PXLockdownCurrentRuntime();
    if (!runtime) return original;

    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
    NSString *processName = [NSProcessInfo processInfo].processName;
    PXLockdownSafetyDecision *decision =
        [runtime decisionForBundleID:bundleID processName:processName now:[NSDate date]];
    if (!decision) return original;

    PXIdentitySnapshot *snapshot = PXCurrentIdentitySnapshot();
    if (!snapshot.valid) return original;
    NSDictionary *settings = snapshot.settings ?: @{};
    NSDictionary *deviceIDs = snapshot.deviceIDs ?: @{};
    NSDictionary *specs = snapshot.specs ?: @{};

    NSArray<NSString *> *failures = nil;
    id resolved = original;
    if (PXLockdownDeviceIdentityEntryForKey(constName)) {
        PXLockdownDeviceIdentityOptions options = PXLockdownDeviceIdentityOptionsFromSettings(settings);
        resolved = PXLockdownDeviceIdentityResolve(constName, original, deviceIDs, options, decision, &failures);
    } else if (PXLockdownSoftwareModelEntryForKey(constName)) {
        PXLockdownSoftwareModelOptions options = PXLockdownSoftwareModelOptionsFromSettings(settings);
        resolved = PXLockdownSoftwareModelResolve(constName, original, deviceIDs, options, decision, &failures);
    } else if (PXLockdownSoCCellularEntryForKey(constName)) {
        PXLockdownSoCCellularOptions options = PXLockdownSoCCellularOptionsFromSettings(settings);
        resolved = PXLockdownSoCCellularResolve(constName, original, deviceIDs, specs, options, decision, &failures);
    } else {
        return original; // known const-name but no active provider owns it
    }

    // Redacted, value-free audit (metadata only, logged once per key).
    @try {
        [gLockdownMetrics recordAccessForKey:constName timedOut:NO cacheHit:NO];
        static NSMutableSet<NSString *> *loggedKeys = nil;
        static dispatch_once_t setOnce;
        dispatch_once(&setOnce, ^{ loggedKeys = [NSMutableSet set]; });
        BOOL shouldLog = NO;
        @synchronized (loggedKeys) {
            if (![loggedKeys containsObject:constName]) {
                [loggedKeys addObject:constName];
                shouldLog = YES;
            }
        }
        if (shouldLog) {
            NSDictionary *audit = PXLockdownRedactedAuditEvent(decision, constName, resolved);
            if (audit) PXLog(@"[LockdownIdentityHooks] audit %@", audit);
        }
    } @catch (__unused NSException *e) {
    }

    return resolved;
}

#pragma mark - liblockdown interception

static CFTypeRef px_lockdown_copy_value(void *client, CFStringRef domain, CFStringRef key) {
    CFTypeRef original = orig_lockdown_copy_value ? orig_lockdown_copy_value(client, domain, key) : NULL;

    if (gInsideLockdownHook) return original;
    if (key == NULL || CFGetTypeID(key) != CFStringGetTypeID()) return original;
    // Only the global (NULL / empty) domain carries the identity keys we scope.
    if (domain != NULL && CFGetTypeID(domain) == CFStringGetTypeID() && CFStringGetLength(domain) > 0) {
        return original;
    }

    gInsideLockdownHook = YES;
    CFTypeRef result = original;
    @try {
        @autoreleasepool {
            NSString *runtimeKey = (__bridge NSString *)key;
            id originalObj = original ? (__bridge id)original : nil;
            id resolved = PXLockdownResolveInterceptedValue(runtimeKey, originalObj, nil);
            if (resolved != originalObj) {
                // Replacing: hand the caller its own +1 reference and drop the original's.
                CFTypeRef replacement = resolved ? (CFTypeRef)CFBridgingRetain(resolved) : NULL;
                if (original) CFRelease(original);
                result = replacement;
            }
        }
    } @catch (__unused NSException *e) {
        result = original;
    } @finally {
        gInsideLockdownHook = NO;
    }
    return result;
}

static void PXLockdownInstallInterception(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *handle = dlopen("/usr/lib/liblockdown.dylib", RTLD_NOW);
        if (!handle) handle = RTLD_DEFAULT;
        void *symbol = dlsym(handle, "lockdown_copy_value");
        if (!symbol) {
            PXLog(@"[LockdownIdentityHooks] lockdown_copy_value unavailable; wiring is a no-op here");
            return;
        }
        MSHookFunction(symbol, (void *)px_lockdown_copy_value, (void **)&orig_lockdown_copy_value);
        PXLog(@"[LockdownIdentityHooks] ✅ lockdown_copy_value routed through research resolvers");
    });
}

#pragma mark - Settings observers

static void PXLockdownSettingsChanged(CFNotificationCenterRef center, void *observer,
                                      CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    PXLockdownRebuildRuntime();
}

#pragma mark - Bootstrap

%ctor {
    @autoreleasepool {
        @try {
            NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
            if (bundleID.length == 0) return;
            NSString *processName = [NSProcessInfo processInfo].processName;
            if (PXIsWebKitHelperProcess(bundleID, processName)) return;

            // Build the process-local safety runtime from the active profile.
            gLockdownMetrics = [[PXLockdownAccessMetrics alloc] init];
            PXLockdownRebuildRuntime();

            // Only arm the interception for a process the research policy actually
            // allowlists. Every other process keeps zero Lockdown overhead and no hook.
            PXLockdownResearchRuntime *runtime = PXLockdownCurrentRuntime();
            PXLockdownResearchPolicy *policy = runtime.policy;
            if (!policy.masterEnabled) return;
            if (![policy.bundleAllowlist containsObject:bundleID]) return;

            CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
            for (NSString *notification in @[ @"com.hydra.tlinkios.settings.changed",
                                              @"com.hydra.tlinkios.profileChanged" ]) {
                CFNotificationCenterAddObserver(darwin, NULL, PXLockdownSettingsChanged,
                    (__bridge CFStringRef)notification, NULL,
                    CFNotificationSuspensionBehaviorDeliverImmediately);
            }

            PXLockdownInstallInterception();
        } @catch (__unused NSException *e) {
        }
    }
}

#endif // INTERNAL_SECURITY_RESEARCH
