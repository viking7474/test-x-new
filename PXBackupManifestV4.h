#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class PXVerifiedBackupArtifact;

FOUNDATION_EXPORT NSInteger const PXBackupManifestV4Version;
FOUNDATION_EXPORT NSString * const PXBackupManifestV4SchemaIdentifier;
FOUNDATION_EXPORT NSInteger const PXBackupManifestV4SchemaRevision;
FOUNDATION_EXPORT NSString * const PXBackupManifestV4DigestAlgorithm;
FOUNDATION_EXPORT NSString * const PXBackupManifestV4PublicationProtocol;
FOUNDATION_EXPORT NSString * const PXBackupManifestV4ContentStateComplete;
FOUNDATION_EXPORT NSErrorDomain const PXBackupManifestV4ErrorDomain;
FOUNDATION_EXPORT NSString * const PXBackupManifestV4ErrorFieldPathKey;

typedef NS_ERROR_ENUM(PXBackupManifestV4ErrorDomain,
                      PXBackupManifestV4ErrorCode) {
    PXBackupManifestV4ErrorInvalidInput = 1,
    PXBackupManifestV4ErrorInvalidBackupIdentifier = 2,
    PXBackupManifestV4ErrorInvalidFieldSet = 3,
    PXBackupManifestV4ErrorInvalidFieldValue = 4,
    PXBackupManifestV4ErrorInvalidArtifact = 5,
    PXBackupManifestV4ErrorInvalidArtifactPolicy = 6,
    PXBackupManifestV4ErrorInvalidArtifactOrder = 7,
    PXBackupManifestV4ErrorDuplicateReference = 8,
    PXBackupManifestV4ErrorMissingReference = 9,
    PXBackupManifestV4ErrorUnreferencedArtifact = 10,
    PXBackupManifestV4ErrorMissingRequiredArtifact = 11,
    PXBackupManifestV4ErrorSizeOverflow = 12,
    PXBackupManifestV4ErrorInconsistentOptions = 13,
    PXBackupManifestV4ErrorSnapshotFailed = 14,
};

__attribute__((objc_subclassing_restricted))
@interface PXBackupManifestV4 : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSString *backupIdentifier;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *manifestRepresentation;
@property (nonatomic, readonly) NSUInteger artifactCount;
@property (nonatomic, readonly) unsigned long long totalSize;
@property (nonatomic, copy, readonly) NSString *applicationDataChecksum;

+ (nullable instancetype)
    manifestWithBackupIdentifier:(NSString *)backupIdentifier
                          fields:(NSDictionary<NSString *, id> *)fields
               verifiedArtifacts:(NSArray<PXVerifiedBackupArtifact *> *)verifiedArtifacts
                           error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
