#import <Foundation/Foundation.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

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

#pragma mark - Central native filesystem query contract (B-00)

typedef enum {
    kPXJBFilesystemAllow = 0,
    kPXJBFilesystemHide,
    kPXJBFilesystemDenyWrite,
    kPXJBFilesystemUnresolved,
} PXJBFilesystemDisposition;

typedef enum {
    kPXJBFilesystemOperationRead = 0,
    kPXJBFilesystemOperationWrite,
} PXJBFilesystemOperation;

typedef enum {
    kPXJBHiddenReadErrnoPathNotFound = 0,
    kPXJBHiddenReadErrnoBadFileDescriptor,
    kPXJBHiddenReadErrnoPermissionDenied,
} PXJBHiddenReadErrnoPolicy;

BOOL PXP1CJBNormalizeAbsolutePath(const char *_Nullable inPath,
                                  char *_Nullable out,
                                  size_t outCapacity);
BOOL PXP1CJBJoinAbsoluteBaseAndNormalize(const char *_Nullable basePath,
                                         const char *_Nullable relativePath,
                                         char *_Nullable out,
                                         size_t outCapacity);
PXJBFilesystemDisposition PXP1CJBResolvedPathDisposition(PXJBFilesystemOperation operation,
                                                         BOOL hiddenArtifact,
                                                         BOOL deniedWriteProbe);
BOOL PXP1CJBDispositionIsHidden(PXJBFilesystemDisposition disposition);
BOOL PXP1CJBDispositionBlocksWrite(PXJBFilesystemDisposition disposition);
int PXP1CJBErrnoForDisposition(PXJBFilesystemDisposition disposition);
int PXP1CJBErrnoForHiddenRead(PXJBHiddenReadErrnoPolicy policy);

#pragma mark - Safe process/socket query parity (B-03)

int PXP1CJBCompactNonRootGroups(gid_t *_Nullable groups, int count);
BOOL PXP1CJBEndpointPortShouldHide(uint16_t hostOrderPort);

#pragma mark - Secondary Objective-C parity (B-05)

/// Exact, dedicated iFake argument markers recovered from sub_E60D4. This is
/// intentionally separate from the filesystem/image path corpus because argv
/// uses substring semantics rather than path classification.
BOOL PXP1CJBArgumentContainsInstrumentationMarker(NSString *_Nullable argument);
NSArray * _Nullable PXP1CJBFilterProcessArguments(NSArray *_Nullable originalArguments,
                                                   BOOL filteringEnabled);

/// Shared URL/app-availability corpus recovered from iFake's 18-entry
/// off_5E4498 table. Input is normalized to lowercase before substring checks.
BOOL PXP1CJBURLSchemeShouldHide(NSString *_Nullable scheme);

/// Preserve array count and element class by replacing only entries proven by
/// the caller-owned predicate. If disabled, malformed, or no entry matches,
/// return the exact original object.
NSArray * _Nullable PXP1CJBArrayByReplacingMatchingObjects(NSArray *_Nullable originalArray,
                                                            BOOL filteringEnabled,
                                                            BOOL (^_Nullable shouldReplace)(id object),
                                                            id _Nullable replacementObject);

#pragma mark - Framework debugger scalar parity (C-01)

/// Pure projection contract for SCIsRunningWithDebugger: preserve the original
/// framework result whenever the scoped JB capability is inactive; otherwise
/// project the debugger state to false. The live hook remains runtime-optional.
BOOL PXP1CJBProjectedDebuggerState(BOOL originalValue, BOOL bypassEnabled);

NS_ASSUME_NONNULL_END
