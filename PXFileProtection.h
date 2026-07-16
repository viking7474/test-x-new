#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const PXFileProtectionErrorDomain;
FOUNDATION_EXPORT NSString * const PXFileProtectionErrorFieldPathKey;

typedef NS_ERROR_ENUM(PXFileProtectionErrorDomain, PXFileProtectionErrorCode) {
    PXFileProtectionErrorInvalidDescriptor = 1,
    PXFileProtectionErrorInspectionFailed = 2,
    PXFileProtectionErrorInvalidFileType = 3,
    PXFileProtectionErrorInvalidLinkCount = 4,
    PXFileProtectionErrorOwnershipMismatch = 5,
    PXFileProtectionErrorPermissionUpdateFailed = 6,
    PXFileProtectionErrorClassUpdateFailed = 7,
    PXFileProtectionErrorClassInspectionFailed = 8,
    PXFileProtectionErrorClassMismatch = 9,
    PXFileProtectionErrorDurabilityFailed = 10,
    PXFileProtectionErrorIdentityChanged = 11,
};

FOUNDATION_EXPORT BOOL
PXApplyCompleteFileProtectionToDescriptor(
    int descriptor,
    NSError * _Nullable * _Nullable error);

FOUNDATION_EXPORT BOOL
PXVerifyCompleteFileProtectionOnDescriptor(
    int descriptor,
    NSError * _Nullable * _Nullable error);

NS_ASSUME_NONNULL_END
