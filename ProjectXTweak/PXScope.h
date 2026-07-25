#import <Foundation/Foundation.h>
#include <stdint.h>

typedef NS_OPTIONS(NSUInteger, PXScopeOptions) {
    PXScopeOptionNone = 0,
    PXScopeOptionAllowSafariAuthStack = 1 << 0,
};

// Centralized scope helpers for ProjectXTweak.
// Goal: keep spoofing decisions consistent across modules, especially for Safari/Auth stack.

BOOL PXDeviceSpoofingEnabled(void);
BOOL PXSafariStackSpoofEnabled(void);

// Test mode: forces spoofing in Safari/Auth stack for failure testing.
BOOL PXFullSpoofTestModeEnabled(void);

// Display spoof controls (native + web). These are intended for test builds.
// - UIScale affects UI sizing/zoom (bounds/scale/nativeScale).
// - PixelMetrics affects fingerprint-visible pixel size (nativeBounds, etc.).
// - WebScreen affects JS-visible metrics (screen.width, devicePixelRatio, etc.).
BOOL PXDisplayUIScaleSpoofEnabled(void);
BOOL PXDisplayPixelMetricsSpoofEnabled(void);
BOOL PXDisplayWebScreenSpoofEnabled(void);

BOOL PXIsCriticalSystemProcess(NSString *bundleID, NSString *processName);
/// Cached process-name check (SpringBoard). Prefer this at %ctor top to skip work fast.
BOOL PXIsSpringBoardProcess(void);
BOOL PXIsWebKitHelperProcess(NSString *bundleID, NSString *processName);
NSString *PXWebKitHostBundleIdentifier(void);
BOOL PXWebKitHostIsScopedForSpoofing(void);
BOOL PXIsSafariStackProcess(NSString *bundleID, NSString *processName);
BOOL PXAllowUnscopedSafariStack(void);

/// Immutable scoped-app dictionary owned by PXScope's snapshot.
NSDictionary<NSString *, NSDictionary *> *PXScopedAppsSnapshot(void);
BOOL PXBundleIsEnabledInScope(NSString *bundleID);

/// Canonical browser bundle identifier prefixes used by all tweak modules.
NSArray<NSString *> *PXBrowserBundleIdentifierPrefixes(void);
BOOL PXIsBrowserBundleIdentifier(NSString *bundleID);
BOOL PXIsSafariBrowserBundleIdentifier(NSString *bundleID);

BOOL PXScopeIsReadingSecuritySettings(void);
BOOL PXBundleIsStrictlyScopedForSpoofing(NSString *bundleID);
BOOL PXProcessIsAllowedForSpoofing(NSString *bundleID, NSString *processName, PXScopeOptions options);
void PXInvalidateScopeDecisionCache(void);
uint64_t PXScopeGeneration(void);
