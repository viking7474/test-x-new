#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// IOS-08 — Injection filter.
//
// Single source of truth for how ProjectX turns the global scope selection into
// the MobileSubstrate filter plists (ProjectXTweak.plist + WeaponXKeychainBridge.plist)
// and how the mount daemon validates them before installing. Both the app writer
// and the daemon delegate to these pure, dependency-free functions so their rules
// can never drift and can be exercised by a host-runnable test.

/// Bundle ID written when a filter would otherwise be empty (Substrate rejects Bundles=[]).
extern NSString * const PXInjectionPlaceholderBundleID;
/// SpringBoard always injects the tweak so the Profile Indicator UI can load.
extern NSString * const PXInjectionSpringBoardBundleID;

/// Sorted, de-duplicated, non-empty string bundle IDs (stable output for compare + writing).
NSArray<NSString *> *PXInjectionNormalizeBundleList(NSArray * _Nullable bundles);

/// The ProjectX app / companion bundles that must never be injected or scoped.
BOOL PXInjectionBundleIsProjectXApp(NSString * _Nullable bundleID);

/// Apple- or WebKit-family bundles (excluded from the keychain bridge filter).
BOOL PXInjectionBundleIsAppleOrWebKit(NSString * _Nullable bundleID);

/// Default WebKit / Safari helper cluster added whenever at least one app is scoped.
NSArray<NSString *> *PXInjectionDefaultWebKitHelperBundleIDs(void);

/// Enabled third-party main bundles from a loaded global_scope plist dictionary.
/// Only ScopedApps entries with enabled == YES; ProjectX and WebKit/SafariViewService removed.
NSArray<NSString *> *PXInjectionEnabledMainBundlesFromScopePlist(NSDictionary * _Nullable scopePlist);

/// Final ProjectXTweak bundle list: expanded scope + SpringBoard, normalized.
/// SpringBoard is always present, so the result is never empty and never needs the placeholder.
NSArray<NSString *> *PXInjectionComputeTweakBundles(NSArray<NSString *> * _Nullable expandedEnabledBundles);

/// Keychain bridge bundle list: third-party app/extensions only (Apple/WebKit + placeholder dropped).
/// An empty result collapses to the placeholder-only list.
NSArray<NSString *> *PXInjectionComputeBridgeBundles(NSArray<NSString *> * _Nullable tweakBundles);

/// Build the { Filter: { Bundles, Mode: "Any" } } plist dictionary for a bundle list.
NSDictionary *PXInjectionFilterPlistDictionary(NSArray<NSString *> *bundles);

/// Validate a filter plist exactly the way the mount daemon does before installing it.
/// Returns YES and fills outBundles on success; NO and fills outReason otherwise.
BOOL PXInjectionFilterPlistIsValid(NSDictionary * _Nullable plist,
                                   NSArray<NSString *> * _Nullable * _Nullable outBundles,
                                   NSString * _Nullable * _Nullable outReason);

/// Stable "count:comma-joined" checksum of a bundle list (human-readable, comparable).
NSString *PXInjectionBundlesChecksum(NSArray * _Nullable bundles);

NS_ASSUME_NONNULL_END
