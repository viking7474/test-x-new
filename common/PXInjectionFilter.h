#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// IOS-08 — Injection filter.
//
// Single source of truth for how TLinkIOS turns the global scope selection into
// the MobileSubstrate filter plists (TLinkIOSTweak.plist + WeaponXKeychainBridge.plist)
// and how the mount daemon validates them before installing. Both the app writer
// and the daemon delegate to these pure, dependency-free functions so their rules
// can never drift and can be exercised by a host-runnable test.

/// Bundle ID written when a filter would otherwise be empty (Substrate rejects Bundles=[]).
extern NSString * const PXInjectionPlaceholderBundleID;
/// SpringBoard target added while scope is non-empty for Freeze/Profile Indicator.
extern NSString * const PXInjectionSpringBoardBundleID;

/// Sorted, de-duplicated, non-empty string bundle IDs (stable output for compare + writing).
NSArray<NSString *> *PXInjectionNormalizeBundleList(NSArray * _Nullable bundles);

/// The TLinkIOS app / companion bundles that must never be injected or scoped.
BOOL PXInjectionBundleIsTLinkIOSApp(NSString * _Nullable bundleID);

/// Apple- or WebKit-family bundles (excluded from the keychain bridge filter).
BOOL PXInjectionBundleIsAppleOrWebKit(NSString * _Nullable bundleID);

/// Safari/WebKit helper coverage targets; runtime bootstrap requires a scoped host.
BOOL PXInjectionBundleIsSharedWebKitHelper(NSString * _Nullable bundleID);
NSArray<NSString *> *PXInjectionDefaultWebKitHelperBundleIDs(void);

/// Enabled third-party main bundles from a loaded global_scope plist dictionary.
/// Only ScopedApps entries with enabled == YES; TLinkIOS and WebKit/SafariViewService removed.
NSArray<NSString *> *PXInjectionEnabledMainBundlesFromScopePlist(NSDictionary * _Nullable scopePlist);

/// Final tweak filter: app/extensions + SpringBoard + UIKit + explicit WebKit cluster.
/// Coverage targets alone never count as scope anchors. Empty -> placeholder-only.
/// Idempotent: safe to canonicalize an already generated staging filter.
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
