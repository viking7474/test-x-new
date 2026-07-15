#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const PXBackupDirectoryDiscoveryErrorDomain;
FOUNDATION_EXPORT NSString * const PXBackupDirectoryDiscoveryErrorFieldPathKey;

typedef NS_ERROR_ENUM(PXBackupDirectoryDiscoveryErrorDomain,
                      PXBackupDirectoryDiscoveryErrorCode) {
    PXBackupDirectoryDiscoveryErrorInvalidInput = 1,
    PXBackupDirectoryDiscoveryErrorLimitExceeded = 2,
    PXBackupDirectoryDiscoveryErrorRootInspectionFailed = 3,
    PXBackupDirectoryDiscoveryErrorBundleDirectoryInvalid = 4,
    PXBackupDirectoryDiscoveryErrorTraversalFailed = 5,
    PXBackupDirectoryDiscoveryErrorEntryChanged = 6,
    PXBackupDirectoryDiscoveryErrorFilesystemChanged = 7,
    PXBackupDirectoryDiscoveryErrorManifestOpenFailed = 8,
    PXBackupDirectoryDiscoveryErrorManifestReadFailed = 9,
    PXBackupDirectoryDiscoveryErrorManifestParseFailed = 10,
    PXBackupDirectoryDiscoveryErrorManifestInvalid = 11,
    PXBackupDirectoryDiscoveryErrorUnsupportedManifestVersion = 12,
    PXBackupDirectoryDiscoveryErrorBundleIdentifierMismatch = 13,
    PXBackupDirectoryDiscoveryErrorPublishedNameMismatch = 14,
    PXBackupDirectoryDiscoveryErrorDuplicateBackup = 15,
    PXBackupDirectoryDiscoveryErrorInternalInvariantFailed = 16,
};

__attribute__((objc_subclassing_restricted))
@interface PXBackupDirectoryDiscovery : NSObject

+ (nullable NSArray<NSString *> *)discoverBackupDirectoriesAtBackupRoots:
    (NSArray<NSString *> *)backupRoots
    bundleIdentifier:(NSString *)bundleIdentifier
    error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
