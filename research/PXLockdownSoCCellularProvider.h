#import <Foundation/Foundation.h>
#import "PXLockdownResearchSafety.h"

NS_ASSUME_NONNULL_BEGIN

// Phase 7 — Lockdown SoC/cellular providers (LOCK-05 SoC + LOCK-06 cellular).
// Scope: UniqueChipID plus the telephony identifiers (IMEI1/IMEI2, MEID) and the
// baseband version. Device identity (UDID/serial/MLB) is Phase 6; software and
// model keys are Phase 5 and stay out of scope here.
//
// Per the plan (§4.5) there are two atomic option groups, never per-key toggles:
//   * SoC identity          -> UniqueChipID
//   * Cellular and baseband  -> IMEI1 / IMEI2 / MEID / BasebandVersion
// UniqueChipID keeps its original CFType (an ECID number); every telephony key is
// a String.
typedef NS_ENUM(NSUInteger, PXLockdownSoCCellularKind) {
    PXLockdownSoCCellularKindUniqueChipID = 0,
    PXLockdownSoCCellularKindIMEI,
    PXLockdownSoCCellularKindSecondaryIMEI,
    PXLockdownSoCCellularKindMEID,
    PXLockdownSoCCellularKindBasebandVersion,
};

typedef NS_ENUM(NSUInteger, PXLockdownSoCCellularGroup) {
    PXLockdownSoCCellularGroupSoCIdentity = 0,
    PXLockdownSoCCellularGroupCellularBaseband,
};

@interface PXLockdownSoCCellularEntry : NSObject
/// Lockdown key the app looks up, e.g. kLockdownUniqueChipIDKey.
@property (nonatomic, copy, readonly) NSString *lockdownKey;
/// Canonical profile field in the immutable snapshot, e.g. UniqueChipID.
@property (nonatomic, copy, readonly) NSString *deviceIDKey;
@property (nonatomic, readonly) PXLockdownSoCCellularKind kind;
@property (nonatomic, readonly) PXLockdownSoCCellularGroup group;
/// YES for keys that only exist on cellular-capable hardware.
@property (nonatomic, readonly) BOOL requiresCellular;
@end

FOUNDATION_EXPORT NSArray<PXLockdownSoCCellularEntry *> *PXLockdownSoCCellularEntries(void);
FOUNDATION_EXPORT PXLockdownSoCCellularEntry * _Nullable
PXLockdownSoCCellularEntryForKey(NSString *lockdownKey);

/// Two atomic switches. Individual keys never toggle on their own.
typedef struct {
    BOOL socIdentity;       // lockdownSoCIdentityEnabled
    BOOL cellularBaseband;  // lockdownCellularBasebandEnabled
} PXLockdownSoCCellularOptions;

FOUNDATION_EXPORT PXLockdownSoCCellularOptions
PXLockdownSoCCellularOptionsFromSettings(NSDictionary *settings);

/// Cellular capability derived from the profile specs. Wi-Fi-only models report
/// cellularCapable == NO and must never surface telephony identifiers.
typedef struct {
    BOOL cellularCapable;
    NSUInteger advertisedSIMCount;
} PXLockdownCellularCapability;

FOUNDATION_EXPORT PXLockdownCellularCapability
PXLockdownCellularCapabilityFromSpecs(NSDictionary *specs);

/// SoC must correspond to the ProductType, and the baseband family must match the
/// model. Unknown ProductTypes fail closed.
FOUNDATION_EXPORT BOOL PXLockdownSoCMatchesProductType(NSString *productType, NSString *soc);
FOUNDATION_EXPORT BOOL PXLockdownBasebandFamilyMatchesProductType(NSString *productType, NSString *family);

FOUNDATION_EXPORT BOOL
PXLockdownSoCCellularRegistryIsWellFormed(NSArray<NSString *> * _Nullable * _Nullable outFailures);

/// Whole-schema validator (Phase-7 exit criteria): rejects every invalid
/// model/SoC/cellular combination — Wi-Fi-only models exposing telephony
/// identifiers, dual-SIM schemas missing IMEI2, single-SIM schemas that leak a
/// second IMEI, ChipID that does not correspond to the SoC/ProductType, malformed
/// IMEI/MEID, and baseband families that do not match the model.
FOUNDATION_EXPORT BOOL
PXLockdownSoCCellularSchemaValidate(NSDictionary *deviceIDs,
                                    NSDictionary *specs,
                                    NSArray<NSString *> * _Nullable * _Nullable outFailures);

/// Resolve what a Lockdown SoC/cellular lookup should return.
///
/// Returns `original` unless ALL hold: the key is in-scope, its atomic option
/// group is ON, the safety decision allows a profile-backed replacement, the
/// hardware is cellular-capable for telephony keys, the snapshot value is
/// well-formed and capability-consistent, and (for IMEI/MEID) it matches every
/// telephony surface registered in the shared registry. UniqueChipID preserves
/// the original CFType; telephony keys stay String. Any failure returns original.
FOUNDATION_EXPORT id _Nullable
PXLockdownSoCCellularResolve(NSString *lockdownKey,
                             id _Nullable original,
                             NSDictionary *deviceIDs,
                             NSDictionary *specs,
                             PXLockdownSoCCellularOptions options,
                             PXLockdownSafetyDecision *decision,
                             NSArray<NSString *> * _Nullable * _Nullable outFailures);

NS_ASSUME_NONNULL_END
