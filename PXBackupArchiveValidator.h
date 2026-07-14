#import <Foundation/Foundation.h>

@class PXVerifiedBackupArtifactSet;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const
    PXBackupArchiveValidatorErrorDomain;

FOUNDATION_EXPORT NSString * const
    PXBackupArchiveValidatorErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXBackupArchiveValidatorErrorCode) {
    PXBackupArchiveValidatorErrorInvalidInput = 1,
    PXBackupArchiveValidatorErrorMissingArchive = 2,
    PXBackupArchiveValidatorErrorOpenFailed = 3,
    PXBackupArchiveValidatorErrorReadFailed = 4,
    PXBackupArchiveValidatorErrorUnsupportedCompression = 5,
    PXBackupArchiveValidatorErrorTruncatedArchive = 6,
    PXBackupArchiveValidatorErrorInvalidHeader = 7,
    PXBackupArchiveValidatorErrorUnsafeEntryPath = 8,
    PXBackupArchiveValidatorErrorDuplicateEntry = 9,
    PXBackupArchiveValidatorErrorUnsupportedEntryType = 10,
    PXBackupArchiveValidatorErrorInvalidExtendedHeader = 11,
    PXBackupArchiveValidatorErrorLimitExceeded = 12,
    PXBackupArchiveValidatorErrorSizeMismatch = 13,
    PXBackupArchiveValidatorErrorDigestMismatch = 14,
    PXBackupArchiveValidatorErrorFilesystemChanged = 15,
    PXBackupArchiveValidatorErrorInconsistentManifest = 16,
};

__attribute__((objc_subclassing_restricted))
@interface PXValidatedBackupArchiveSet : NSObject <NSCopying>

@property (nonatomic, copy, readonly)
    NSArray<NSString *> *archiveNames;

@property (nonatomic, copy, readonly)
    NSDictionary<NSString *, NSNumber *> *memberCountsByArchiveName;

@property (nonatomic, copy, readonly)
    NSDictionary<NSString *, NSNumber *> *regularFileBytesByArchiveName;

- (BOOL)containsArchiveName:(NSString *)archiveName;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PXBackupArchiveValidator : NSObject

+ (nullable PXValidatedBackupArchiveSet *)validatedArchivesForManifest:(NSDictionary *)manifest
                                                       backupDirectory:(NSString *)backupDirectory
                                                     verifiedArtifacts:(PXVerifiedBackupArtifactSet *)verifiedArtifacts
                                                                 error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
