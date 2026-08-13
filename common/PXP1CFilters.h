#import <Foundation/Foundation.h>
#include <stdint.h>

NS_ASSUME_NONNULL_BEGIN

// Pure, host-testable mirrors of the TLinkIOS Newplan §5 decision logic
// (PXScope immutable snapshot + Jailbreak hook groups / master toggle).
//
// These helpers hold no global state, no locks, and perform no disk or
// Objective-C runtime side effects, so they run in a plain Foundation host
// test while staying byte-for-byte faithful to the live logic in PXScope.m
// and JailbreakBypassHooks.x. The live modules already implement §5; these
// helpers exist to lock the decision math under host-runnable regression
// tests (no drift), not to replace the on-device code paths.

#pragma mark - Scope snapshot decision (§5 PXScope immutable snapshot)

/// Mirrors PXScopedBundleEnabledInSnapshot: a bundle is in scope only when it
/// maps to a dictionary entry whose `enabled` value is YES. A nil/empty bundle
/// id, a missing entry, or a non-dictionary entry all resolve to NO.
BOOL PXP1CScopeBundleEnabled(NSDictionary *_Nullable scopedApps,
                            NSString *_Nullable bundleID);

/// Mirrors PXWebKitHostIsScopedForSpoofing fail-closed rule: a WebKit helper
/// process is only scoped when device spoofing is enabled, a host bundle id
/// actually resolved (non-empty), the host is not a critical system process,
/// and the host bundle is enabled in scope. Any missing host id fails closed.
BOOL PXP1CWebKitHostScoped(BOOL deviceSpoofEnabled,
                          NSString *_Nullable hostBundleID,
                          BOOL hostIsCriticalProcess,
                          BOOL hostEnabledInScope);

/// Mirrors PXCurrentSnapshot's refresh test: reload is required when no
/// snapshot has been published yet, or when `now` has reached the published
/// snapshot's expiration time.
BOOL PXP1CSnapshotNeedsRefresh(BOOL hasSnapshot,
                              double now,
                              double expirationTime);

#pragma mark - Jailbreak policy mask (§5 master toggle / launch-only install)

/// Mirrors PXJBBuildRequestedPolicyMask: returns 0 when the master toggle is
/// off (so a runtime "master off" produces a fully pass-through mask),
/// otherwise the master bit OR'd with the requested feature bits.
uint64_t PXP1CJBRequestedMask(BOOL masterEnabled,
                             uint64_t masterBit,
                             uint64_t featureBits);

/// Mirrors PXJBPublishPolicySnapshot: the effective mask is the intersection of
/// what was requested and what actually passed the launch install audit.
/// Capabilities not installed at launch can never activate at runtime.
uint64_t PXP1CJBEffectivePolicyMask(uint64_t requestedMask,
                                   uint64_t installedMask);

/// Mirrors PXJBPolicyFeatureEnabled: a feature is active only when BOTH the
/// master bit and the feature bit are present in the effective mask.
BOOL PXP1CJBFeatureActive(uint64_t effectiveMask,
                         uint64_t masterBit,
                         uint64_t featureBit);

#pragma mark - Jailbreak statfs sanitize (§5 statfs coordinator provider)

/// Mirrors PXJBIsSensitiveMountPath: only the canonical root/volume paths that
/// detectors probe ("/", "/var", "/private", "/private/var") are sensitive.
BOOL PXP1CJBIsSensitiveMountPath(const char *_Nullable path);

/// Mirrors PXJBNormalizeStatfs: force the read-only mount flag so rootfs looks
/// like a stock, non-jailbroken device while preserving all other flag bits.
uint32_t PXP1CJBNormalizeStatfsFlags(uint32_t flags);

NS_ASSUME_NONNULL_END
