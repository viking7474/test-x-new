#import <Foundation/Foundation.h>
#include <stdint.h>
#import "PXLockdownResearchSafety.h"

NS_ASSUME_NONNULL_BEGIN

// Phase 6 — Lockdown device identity providers (LOCK-04).
// UniqueDeviceID (UDID), SerialNumber and MLBSerialNumber only.
// Software/model keys are handled by Phase 5; SoC and cellular keys stay out of
// scope here (Phase 7). Per the plan, UDID / serial / MLB are NOT individually
// switchable: they form one atomic identity group so a profile can never leak a
// mismatched trio.
typedef NS_ENUM(NSUInteger, PXLockdownDeviceIdentityKind) {
    PXLockdownDeviceIdentityKindUDID = 0,
    PXLockdownDeviceIdentityKindSerialNumber,
    PXLockdownDeviceIdentityKindMLBSerialNumber,
};

@interface PXLockdownDeviceIdentityEntry : NSObject
/// Lockdown key the app looks up, e.g. kLockdownUniqueDeviceIDKey.
@property (nonatomic, copy, readonly) NSString *lockdownKey;
/// Canonical profile field in the immutable snapshot, e.g. SerialNumber.
@property (nonatomic, copy, readonly) NSString *deviceIDKey;
/// Which identity this entry projects, used for form validation.
@property (nonatomic, readonly) PXLockdownDeviceIdentityKind kind;
@end

FOUNDATION_EXPORT NSArray<PXLockdownDeviceIdentityEntry *> *PXLockdownDeviceIdentityEntries(void);
FOUNDATION_EXPORT PXLockdownDeviceIdentityEntry * _Nullable
PXLockdownDeviceIdentityEntryForKey(NSString *lockdownKey);

/// One atomic switch for the whole identity trio. Individual keys never toggle
/// on their own, so UDID / serial / MLB are always replaced together or not at all.
typedef struct {
    BOOL deviceIdentifiers;
} PXLockdownDeviceIdentityOptions;

FOUNDATION_EXPORT PXLockdownDeviceIdentityOptions
PXLockdownDeviceIdentityOptionsFromSettings(NSDictionary *settings);

/// Structural self-check independent of any profile: every entry has a distinct
/// lockdown key, a snapshot field, and a known identity kind.
FOUNDATION_EXPORT BOOL
PXLockdownDeviceIdentityRegistryIsWellFormed(NSArray<NSString *> * _Nullable * _Nullable outFailures);

/// Whether a candidate value is a well-formed instance of the given identity.
/// Rejects empty/whitespace and obviously malformed values before any spoof.
FOUNDATION_EXPORT BOOL
PXLockdownDeviceIdentityValueIsWellFormed(PXLockdownDeviceIdentityKind kind, NSString * _Nullable value);

/// Resolve what a Lockdown device-identity lookup should return.
///
/// Returns `original` unless ALL hold: the key is in-scope, the atomic
/// device-identifiers group is ON, the safety decision allows a profile-backed
/// replacement, the snapshot has a non-empty well-formed String value, and the
/// value matches every MobileGestalt / IORegistry surface registered for that
/// identity (no partial projection). String type is always preserved; any
/// failure returns the original value.
FOUNDATION_EXPORT id _Nullable
PXLockdownDeviceIdentityResolve(NSString *lockdownKey,
                                id _Nullable original,
                                NSDictionary *deviceIDs,
                                PXLockdownDeviceIdentityOptions options,
                                PXLockdownSafetyDecision *decision,
                                NSArray<NSString *> * _Nullable * _Nullable outFailures);

/// Generation-stability contract for the identity trio. Within one generation
/// (same generation counter) every in-scope identity value MUST be identical
/// between two snapshots, so a value can never change mid-session. Across
/// different generations the values are allowed to differ (a profile switch).
FOUNDATION_EXPORT BOOL
PXLockdownDeviceIdentityStableAcrossGeneration(NSDictionary *previousDeviceIDs,
                                               uint64_t previousGeneration,
                                               NSDictionary *currentDeviceIDs,
                                               uint64_t currentGeneration,
                                               NSArray<NSString *> * _Nullable * _Nullable outFailures);

NS_ASSUME_NONNULL_END
