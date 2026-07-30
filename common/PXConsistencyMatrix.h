#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// IOS-07 / CONS-01
// Authoritative consistency matrix for every user-visible identity surface.
//
// Every spoofed surface (uname, sysctl, sysctlbyname, MobileGestalt, IOKit,
// CoreFoundation system version, SystemVersion.plist) must project the SAME
// canonical value whenever those surfaces describe the SAME logical fact.
// This module is the single source of truth for those groupings so a test can
// prove the hooks never diverge and reviewers can extend the matrix safely.

/// How a surface derives its projected value.
typedef NS_ENUM(NSInteger, PXConsistencySourceKind) {
    /// Value is read from deviceIDs[deviceIDKey] (a canonical profile field).
    PXConsistencySourceDeviceIDKey = 0,
    /// Value is a fixed literal, independent of the profile (e.g. "Darwin").
    PXConsistencySourceConstant,
};

/// One spoofed surface entry.
@interface PXConsistencyMatrixEntry : NSObject
/// Hook family, e.g. "uname", "sysctlbyname", "MG", "IOKit", "CFSystem", "SystemVersion.plist".
@property (nonatomic, copy, readonly) NSString *surface;
/// Concrete key/selector the app reads, e.g. "kern.osproductversion", "ProductType".
@property (nonatomic, copy, readonly) NSString *key;
/// Consistency group id. All entries in a group MUST resolve to one value.
@property (nonatomic, copy, readonly) NSString *group;
/// Identifier toggle that gates this surface, e.g. "IOSVersion", "DeviceModel", "DeviceName".
@property (nonatomic, copy, readonly) NSString *toggle;
@property (nonatomic, readonly) PXConsistencySourceKind sourceKind;
/// Set when sourceKind == PXConsistencySourceDeviceIDKey.
@property (nonatomic, copy, readonly, nullable) NSString *deviceIDKey;
/// Set when sourceKind == PXConsistencySourceConstant.
@property (nonatomic, copy, readonly, nullable) NSString *constantValue;
@end

/// The full, ordered matrix of surfaces the project keeps consistent.
FOUNDATION_EXPORT NSArray<PXConsistencyMatrixEntry *> *PXConsistencyMatrixEntries(void);

/// Resolve the projected value an entry should return for a given profile.
/// Returns nil when a required deviceIDs key is missing or blank.
FOUNDATION_EXPORT NSString * _Nullable
PXConsistencyResolveEntryValue(PXConsistencyMatrixEntry *entry, NSDictionary *deviceIDs);

/// Structural check: every group is internally coherent (all entries in a group
/// share one source spec — same deviceIDKey, or same constant, never mixed).
/// Independent of any profile. Returns YES when well-formed.
FOUNDATION_EXPORT BOOL
PXConsistencyMatrixIsWellFormed(NSArray<NSString *> * _Nullable * _Nullable outFailures);

/// Value check: for a concrete profile, every surface in a group resolves to the
/// same value, and no group that has any resolvable surface is left partial.
/// Returns YES when consistent; otherwise populates outFailures.
FOUNDATION_EXPORT BOOL
PXValidateConsistencyMatrix(NSDictionary *deviceIDs,
                            NSArray<NSString *> * _Nullable * _Nullable outFailures);

NS_ASSUME_NONNULL_END
