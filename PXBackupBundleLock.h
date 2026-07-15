#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const PXBackupBundleLockErrorDomain;
FOUNDATION_EXPORT NSString * const PXBackupBundleLockErrorFieldPathKey;
FOUNDATION_EXPORT NSString * const PXBackupBundleLockFileName;

typedef NS_ERROR_ENUM(PXBackupBundleLockErrorDomain,
                      PXBackupBundleLockErrorCode) {
    PXBackupBundleLockErrorInvalidInput = 1,
    PXBackupBundleLockErrorRootCreationFailed = 2,
    PXBackupBundleLockErrorRootInspectionFailed = 3,
    PXBackupBundleLockErrorUnsafeRoot = 4,
    PXBackupBundleLockErrorBundleDirectoryCreationFailed = 5,
    PXBackupBundleLockErrorBundleDirectoryInvalid = 6,
    PXBackupBundleLockErrorLockFileOpenFailed = 7,
    PXBackupBundleLockErrorLockFileInvalid = 8,
    PXBackupBundleLockErrorLockUnavailable = 9,
    PXBackupBundleLockErrorFilesystemChanged = 10,
    PXBackupBundleLockErrorLimitExceeded = 11,
};

__attribute__((objc_subclassing_restricted))
@interface PXBackupBundleLock : NSObject

@property (nonatomic, copy, readonly) NSString *canonicalBackupRootPath;
@property (nonatomic, copy, readonly) NSString *canonicalBundleDirectoryPath;
@property (nonatomic, copy, readonly) NSString *bundleIdentifier;
@property (nonatomic, copy, readonly) NSString *lockFileName;

+ (nullable instancetype)acquireLockAtBackupRoot:(NSString *)backupRoot
                                bundleIdentifier:(NSString *)bundleIdentifier
                                           error:(NSError * _Nullable * _Nullable)error;

- (BOOL)validateOwnershipWithError:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
