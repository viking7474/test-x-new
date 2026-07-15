#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const PXBackupPublicationWorkspaceErrorDomain;
FOUNDATION_EXPORT NSString * const PXBackupPublicationWorkspaceErrorFieldPathKey;
FOUNDATION_EXPORT NSString * const PXBackupPublicationPartialDirectoryPrefix;

typedef NS_ERROR_ENUM(PXBackupPublicationWorkspaceErrorDomain,
                      PXBackupPublicationWorkspaceErrorCode) {
    PXBackupPublicationWorkspaceErrorInvalidInput = 1,
    PXBackupPublicationWorkspaceErrorRootCreationFailed = 2,
    PXBackupPublicationWorkspaceErrorRootInspectionFailed = 3,
    PXBackupPublicationWorkspaceErrorUnsafeRoot = 4,
    PXBackupPublicationWorkspaceErrorBundleDirectoryCreationFailed = 5,
    PXBackupPublicationWorkspaceErrorBundleDirectoryInvalid = 6,
    PXBackupPublicationWorkspaceErrorWorkspaceCreationFailed = 7,
    PXBackupPublicationWorkspaceErrorWorkspaceInvalid = 8,
    PXBackupPublicationWorkspaceErrorFilesystemChanged = 9,
    PXBackupPublicationWorkspaceErrorLimitExceeded = 10,
};

__attribute__((objc_subclassing_restricted))
@interface PXBackupPublicationWorkspace : NSObject

@property (nonatomic, copy, readonly) NSString *canonicalBackupRootPath;
@property (nonatomic, copy, readonly) NSString *canonicalBundleDirectoryPath;
@property (nonatomic, copy, readonly) NSString *workspacePath;
@property (nonatomic, copy, readonly) NSString *workspaceName;
@property (nonatomic, copy, readonly) NSString *bundleIdentifier;

+ (nullable instancetype)createWorkspaceAtBackupRoot:(NSString *)backupRoot
                                    bundleIdentifier:(NSString *)bundleIdentifier
                                               error:(NSError **)error;

- (BOOL)validateIdentityWithError:(NSError **)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
