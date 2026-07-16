#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class PXBackupPublicationWorkspace;
@class PXBackupBundleLock;
@class PXBackupArtifactWriter;
@class PXBackupManifestWriter;

FOUNDATION_EXPORT NSErrorDomain const PXBackupDirectoryPublisherErrorDomain;
FOUNDATION_EXPORT NSString * const PXBackupDirectoryPublisherErrorFieldPathKey;

typedef NS_ERROR_ENUM(PXBackupDirectoryPublisherErrorDomain,
                      PXBackupDirectoryPublisherErrorCode) {
    PXBackupDirectoryPublisherErrorInvalidInput = 1,
    PXBackupDirectoryPublisherErrorLockValidationFailed = 2,
    PXBackupDirectoryPublisherErrorWorkspaceValidationFailed = 3,
    PXBackupDirectoryPublisherErrorParentInspectionFailed = 4,
    PXBackupDirectoryPublisherErrorWorkspaceInspectionFailed = 5,
    PXBackupDirectoryPublisherErrorInvalidFinalName = 6,
    PXBackupDirectoryPublisherErrorFinalDirectoryAlreadyExists = 7,
    PXBackupDirectoryPublisherErrorArtifactWriterValidationFailed = 8,
    PXBackupDirectoryPublisherErrorManifestWriterValidationFailed = 9,
    PXBackupDirectoryPublisherErrorManifestNotReady = 10,
    PXBackupDirectoryPublisherErrorFilesystemChanged = 11,
    PXBackupDirectoryPublisherErrorDurabilityFailed = 12,
    PXBackupDirectoryPublisherErrorPublicationFailed = 13,
    PXBackupDirectoryPublisherErrorFinalDirectoryInspectionFailed = 14,
    PXBackupDirectoryPublisherErrorManifestReadBackFailed = 15,
    PXBackupDirectoryPublisherErrorManifestValidationFailed = 16,
    PXBackupDirectoryPublisherErrorSnapshotMismatch = 17,
    PXBackupDirectoryPublisherErrorRollbackFailed = 18,
    PXBackupDirectoryPublisherErrorProtectedArtifactInvalid = 19,
};

__attribute__((objc_subclassing_restricted))
@interface PXBackupDirectoryPublisher : NSObject

@property (nonatomic, copy, readonly) NSString *workspacePath;
@property (nonatomic, copy, readonly) NSString *publishedDirectoryPath;
@property (nonatomic, copy, readonly) NSString *publishedDirectoryName;
@property (nonatomic, copy, readonly) NSString *publishedManifestPath;
@property (nonatomic, copy, readonly) NSString *backupIdentifier;
@property (nonatomic, copy, readonly) NSString *timestamp;
@property (nonatomic, readonly, getter=isPublished) BOOL published;

+ (nullable instancetype)
    publisherForWorkspace:(PXBackupPublicationWorkspace *)workspace
               bundleLock:(PXBackupBundleLock *)bundleLock
         backupIdentifier:(NSString *)backupIdentifier
                timestamp:(NSString *)timestamp
                    error:(NSError * _Nullable * _Nullable)error;

- (BOOL)publishWithArtifactWriter:(PXBackupArtifactWriter *)artifactWriter
                   manifestWriter:(PXBackupManifestWriter *)manifestWriter
                            error:(NSError * _Nullable * _Nullable)error;

- (BOOL)validateIdentityWithError:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
