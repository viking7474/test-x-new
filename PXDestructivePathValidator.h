#import <Foundation/Foundation.h>

#import "PXResolvedContainer.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PXDestructivePathValidatorErrorDomain;

typedef NS_ENUM(NSInteger, PXDestructivePathValidatorErrorCode) {
    PXDestructivePathValidatorErrorInvalidInput = 1,
    PXDestructivePathValidatorErrorCandidatePathMismatch = 2,
    PXDestructivePathValidatorErrorFilesystemInspectionFailed = 3,
    PXDestructivePathValidatorErrorSymlinkRejected = 4,
    PXDestructivePathValidatorErrorCanonicalizationFailed = 5,
    PXDestructivePathValidatorErrorCanonicalBaseViolation = 6,
    PXDestructivePathValidatorErrorCrossDeviceBoundary = 7,
    PXDestructivePathValidatorErrorOwnershipOrModeViolation = 8,
    PXDestructivePathValidatorErrorMetadataInvalid = 9,
    PXDestructivePathValidatorErrorIdentityMismatch = 10,
    PXDestructivePathValidatorErrorFilesystemChanged = 11,
};

__attribute__((objc_subclassing_restricted))
@interface PXDestructivePathValidator : NSObject

- (nullable NSString *)validatedCanonicalPathForContainer:(PXResolvedContainer *)container
                                                    error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
