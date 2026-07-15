#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class PXBackupManifestV4;
@class PXBackupPublicationWorkspace;

FOUNDATION_EXPORT NSErrorDomain const PXBackupManifestWriterErrorDomain;
FOUNDATION_EXPORT NSString * const PXBackupManifestWriterErrorFieldPathKey;
FOUNDATION_EXPORT NSString * const PXBackupManifestFinalFileName;
FOUNDATION_EXPORT NSString * const PXBackupManifestTemporaryFilePrefix;

typedef NS_ERROR_ENUM(PXBackupManifestWriterErrorDomain,
                      PXBackupManifestWriterErrorCode) {
    PXBackupManifestWriterErrorInvalidInput = 1,
    PXBackupManifestWriterErrorWorkspaceValidationFailed = 2,
    PXBackupManifestWriterErrorWorkspaceInspectionFailed = 3,
    PXBackupManifestWriterErrorManifestAlreadyWritten = 4,
    PXBackupManifestWriterErrorFinalManifestAlreadyExists = 5,
    PXBackupManifestWriterErrorSerializationFailed = 6,
    PXBackupManifestWriterErrorLimitExceeded = 7,
    PXBackupManifestWriterErrorTemporaryCreationFailed = 8,
    PXBackupManifestWriterErrorWriteFailed = 9,
    PXBackupManifestWriterErrorDurabilityFailed = 10,
    PXBackupManifestWriterErrorReadBackFailed = 11,
    PXBackupManifestWriterErrorValidationFailed = 12,
    PXBackupManifestWriterErrorSnapshotMismatch = 13,
    PXBackupManifestWriterErrorFilesystemChanged = 14,
    PXBackupManifestWriterErrorFinalizationFailed = 15,
    PXBackupManifestWriterErrorCleanupFailed = 16,
};

__attribute__((objc_subclassing_restricted))
@interface PXBackupManifestWriter : NSObject

@property (nonatomic, copy, readonly) NSString *workspacePath;
@property (nonatomic, copy, readonly) NSString *manifestPath;
@property (nonatomic, readonly, getter=isManifestWritten) BOOL manifestWritten;
@property (nonatomic, readonly) unsigned long long manifestSize;
@property (nonatomic, copy, readonly, nullable) NSString *manifestSHA256;
@property (nonatomic, copy, readonly, nullable)
    NSDictionary<NSString *, id> *manifestRepresentation;

+ (nullable instancetype)
    writerForWorkspace:(PXBackupPublicationWorkspace *)workspace
                  error:(NSError * _Nullable * _Nullable)error;

- (BOOL)writeManifestSnapshot:(PXBackupManifestV4 *)manifestSnapshot
                        error:(NSError * _Nullable * _Nullable)error;

- (BOOL)validateIdentityWithError:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
