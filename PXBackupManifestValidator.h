#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const
    PXBackupManifestValidatorErrorDomain;

FOUNDATION_EXPORT NSString * const
    PXBackupManifestValidatorErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXBackupManifestValidatorErrorCode) {
    PXBackupManifestValidatorErrorInvalidRoot = 1,
    PXBackupManifestValidatorErrorMissingRequiredField = 2,
    PXBackupManifestValidatorErrorInvalidFieldType = 3,
    PXBackupManifestValidatorErrorInvalidFieldValue = 4,
    PXBackupManifestValidatorErrorDuplicateEntry = 5,
    PXBackupManifestValidatorErrorInconsistentField = 6,
};

__attribute__((objc_subclassing_restricted))
@interface PXBackupManifestValidator : NSObject

+ (BOOL)validateManifestObject:(nullable id)object
                         error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
