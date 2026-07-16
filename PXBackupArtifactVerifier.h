#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const
    PXBackupArtifactVerifierErrorDomain;

FOUNDATION_EXPORT NSString * const
    PXBackupArtifactVerifierErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXBackupArtifactVerifierErrorCode) {
    PXBackupArtifactVerifierErrorInvalidInput = 1,
    PXBackupArtifactVerifierErrorInvalidReference = 2,
    PXBackupArtifactVerifierErrorUnsafeRelativePath = 3,
    PXBackupArtifactVerifierErrorMissingArtifact = 4,
    PXBackupArtifactVerifierErrorFilesystemInspectionFailed = 5,
    PXBackupArtifactVerifierErrorSymlinkRejected = 6,
    PXBackupArtifactVerifierErrorNotRegularFile = 7,
    PXBackupArtifactVerifierErrorSizeMismatch = 8,
    PXBackupArtifactVerifierErrorInvalidDigest = 9,
    PXBackupArtifactVerifierErrorDigestReadFailed = 10,
    PXBackupArtifactVerifierErrorDigestMismatch = 11,
    PXBackupArtifactVerifierErrorFilesystemChanged = 12,
    PXBackupArtifactVerifierErrorInconsistentManifest = 13,
    PXBackupArtifactVerifierErrorProtectionInvalid = 14,
};

__attribute__((objc_subclassing_restricted))
@interface PXVerifiedBackupArtifactSet : NSObject <NSCopying>

@property (nonatomic, copy, readonly)
    NSArray<NSString *> *artifactNames;

@property (nonatomic, copy, readonly)
    NSDictionary<NSString *, NSString *> *canonicalPathsByName;

- (nullable NSString *)pathForArtifactName:(NSString *)artifactName;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PXBackupArtifactVerifier : NSObject

+ (nullable PXVerifiedBackupArtifactSet *)verifiedArtifactsForManifest:(NSDictionary *)manifest
                                                       backupDirectory:(NSString *)backupDirectory
                                                                 error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
