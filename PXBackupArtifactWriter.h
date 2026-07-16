#import <Foundation/Foundation.h>
#import "PXBackupArtifactPolicy.h"

NS_ASSUME_NONNULL_BEGIN

@class PXBackupPublicationWorkspace;

FOUNDATION_EXPORT NSErrorDomain const PXBackupArtifactWriterErrorDomain;
FOUNDATION_EXPORT NSString * const PXBackupArtifactWriterErrorFieldPathKey;
FOUNDATION_EXPORT NSString * const PXBackupArtifactTemporaryDirectoryPrefix;

typedef NS_ERROR_ENUM(PXBackupArtifactWriterErrorDomain,
                      PXBackupArtifactWriterErrorCode) {
    PXBackupArtifactWriterErrorInvalidInput = 1,
    PXBackupArtifactWriterErrorWorkspaceValidationFailed = 2,
    PXBackupArtifactWriterErrorWorkspaceInspectionFailed = 3,
    PXBackupArtifactWriterErrorParentCreationFailed = 4,
    PXBackupArtifactWriterErrorParentInvalid = 5,
    PXBackupArtifactWriterErrorDuplicateArtifact = 6,
    PXBackupArtifactWriterErrorTemporaryCreationFailed = 7,
    PXBackupArtifactWriterErrorProducerFailed = 8,
    PXBackupArtifactWriterErrorOutputMissing = 9,
    PXBackupArtifactWriterErrorOutputInvalid = 10,
    PXBackupArtifactWriterErrorReadFailed = 11,
    PXBackupArtifactWriterErrorFilesystemChanged = 12,
    PXBackupArtifactWriterErrorLimitExceeded = 13,
    PXBackupArtifactWriterErrorDurabilityFailed = 14,
    PXBackupArtifactWriterErrorFinalizationFailed = 15,
    PXBackupArtifactWriterErrorCleanupFailed = 16,
    PXBackupArtifactWriterErrorPolicyRejected = 17,
    PXBackupArtifactWriterErrorProtectionFailed = 18,
};

typedef BOOL (^PXBackupArtifactProducer)(NSString *temporaryOutputPath);

__attribute__((objc_subclassing_restricted))
@interface PXVerifiedBackupArtifact : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSString *relativePath;
@property (nonatomic, copy, readonly) NSString *filePath;
@property (nonatomic, readonly) unsigned long long size;
@property (nonatomic, copy, readonly) NSString *sha256;
@property (nonatomic, strong, readonly) PXBackupArtifactPolicy *policy;
@property (nonatomic, readonly) BOOL protectionVerified;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *manifestRepresentation;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PXBackupArtifactWriter : NSObject

@property (nonatomic, copy, readonly) NSString *workspacePath;
@property (nonatomic, readonly) NSUInteger artifactCount;

+ (nullable instancetype)writerForWorkspace:(PXBackupPublicationWorkspace *)workspace
                                      error:(NSError **)error;

- (nullable PXVerifiedBackupArtifact *)writeArtifactAtRelativePath:(NSString *)relativePath
                                                            policy:(PXBackupArtifactPolicy *)policy
                                                          producer:(PXBackupArtifactProducer)producer
                                                             error:(NSError **)error;

- (BOOL)validateIdentityWithError:(NSError **)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
