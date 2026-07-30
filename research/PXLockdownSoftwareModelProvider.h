#import <Foundation/Foundation.h>
#import "PXLockdownResearchSafety.h"

NS_ASSUME_NONNULL_BEGIN

// Phase 5 — Lockdown software/model providers (LOCK-03/LOCK-05).
// Software version, build version, product type and device name only.
// Device identity, SoC and cellular keys are intentionally out of scope here.
typedef NS_ENUM(NSUInteger, PXLockdownSoftwareOptionGroup) {
    PXLockdownSoftwareOptionGroupSoftwareVersion = 0, // ProductVersion + BuildVersion (atomic)
    PXLockdownSoftwareOptionGroupProductModel,        // ProductType
    PXLockdownSoftwareOptionGroupDeviceName,          // DeviceName
};

@interface PXLockdownSoftwareModelEntry : NSObject
/// Lockdown key the app looks up, e.g. kLockdownBuildVersionKey.
@property (nonatomic, copy, readonly) NSString *lockdownKey;
/// Canonical profile field in the immutable snapshot, e.g. IOSBuild.
@property (nonatomic, copy, readonly) NSString *deviceIDKey;
/// PXConsistencyMatrix group used for the cross-surface check.
@property (nonatomic, copy, readonly) NSString *consistencyGroup;
/// Owning identifier toggle, e.g. IOSVersion / DeviceModel / DeviceName.
@property (nonatomic, copy, readonly) NSString *toggle;
/// Grouped option that must be ON for the key to be replaced.
@property (nonatomic, readonly) PXLockdownSoftwareOptionGroup optionGroup;
@end

FOUNDATION_EXPORT NSArray<PXLockdownSoftwareModelEntry *> *PXLockdownSoftwareModelEntries(void);
FOUNDATION_EXPORT PXLockdownSoftwareModelEntry * _Nullable
PXLockdownSoftwareModelEntryForKey(NSString *lockdownKey);

/// Grouped enable flags. Individual software keys never toggle independently;
/// ProductVersion and BuildVersion share one atomic "software version" group.
typedef struct {
    BOOL softwareVersion;
    BOOL productModel;
    BOOL deviceName;
} PXLockdownSoftwareModelOptions;

FOUNDATION_EXPORT PXLockdownSoftwareModelOptions
PXLockdownSoftwareModelOptionsFromSettings(NSDictionary *settings);

/// Structural self-check independent of any profile: every entry maps to a real
/// consistency group and expects a String projection.
FOUNDATION_EXPORT BOOL
PXLockdownSoftwareModelRegistryIsWellFormed(NSArray<NSString *> * _Nullable * _Nullable outFailures);

/// Resolve what a Lockdown software/model lookup should return.
///
/// Returns `original` unless ALL hold: the key is in-scope, its option group is
/// ON, the safety decision allows a profile-backed replacement, the snapshot has
/// a non-empty String value, and the value survives a cross-surface consistency
/// check against SystemVersion / MobileGestalt / IORegistry for its group.
/// String type is always preserved; any failure returns the original value.
FOUNDATION_EXPORT id _Nullable
PXLockdownSoftwareModelResolve(NSString *lockdownKey,
                               id _Nullable original,
                               NSDictionary *deviceIDs,
                               PXLockdownSoftwareModelOptions options,
                               PXLockdownSafetyDecision *decision,
                               NSArray<NSString *> * _Nullable * _Nullable outFailures);

NS_ASSUME_NONNULL_END
