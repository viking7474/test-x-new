#import <Foundation/Foundation.h>

@class PXRestorePlan;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PXOptionalRestoreStagingErrorDomain;
FOUNDATION_EXPORT NSString * const PXOptionalRestoreStagingErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXOptionalRestoreStagingErrorCode) {
    PXOptionalRestoreStagingErrorInvalidInput = 1,
    PXOptionalRestoreStagingErrorInvalidDestinationIdentity = 2,
    PXOptionalRestoreStagingErrorMissingDestination = 3,
    PXOptionalRestoreStagingErrorAmbiguousDestination = 4,
    PXOptionalRestoreStagingErrorUnsafeDestination = 5,
    PXOptionalRestoreStagingErrorWorkspaceCreationFailed = 6,
    PXOptionalRestoreStagingErrorSourceOpenFailed = 7,
    PXOptionalRestoreStagingErrorSourceChanged = 8,
    PXOptionalRestoreStagingErrorSourceUnsupported = 9,
    PXOptionalRestoreStagingErrorCopyFailed = 10,
    PXOptionalRestoreStagingErrorStagedFileInvalid = 11,
    PXOptionalRestoreStagingErrorSizeMismatch = 12,
    PXOptionalRestoreStagingErrorDigestMismatch = 13,
    PXOptionalRestoreStagingErrorLimitExceeded = 14,
    PXOptionalRestoreStagingErrorCleanupFailed = 15,
    PXOptionalRestoreStagingErrorInconsistentPlan = 16,
    PXOptionalRestoreStagingErrorProtectionFailed = 17,
};

__attribute__((objc_subclassing_restricted))
@interface PXValidatedOptionalFileStage : NSObject <NSCopying>
@property (nonatomic, copy, readonly) NSString *workspaceRootPath;
@property (nonatomic, copy, readonly) NSString *filePath;
@property (nonatomic, assign, readonly) unsigned long long byteCount;
@property (nonatomic, copy, readonly) NSString *sha256;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

__attribute__((objc_subclassing_restricted))
@interface PXOptionalFileStagingWorkspace : NSObject
@property (nonatomic, copy, readonly) NSString *rootPath;
@property (nonatomic, copy, readonly) NSString *filePath;
@property (nonatomic, strong, readonly) PXValidatedOptionalFileStage *validatedStage;
+ (nullable instancetype)workspaceByStagingSourceFileAtPath:(NSString *)sourcePath
                                                     error:(NSError * _Nullable * _Nullable)error;
- (BOOL)applyCompleteFileProtectionWithError:
    (NSError * _Nullable * _Nullable)error;
- (BOOL)cleanupWithError:(NSError * _Nullable * _Nullable)error;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

__attribute__((objc_subclassing_restricted))
@interface PXOptionalRestoreDestinationPlan : NSObject <NSCopying>
@property (nonatomic, copy, readonly) NSString *mobileLibraryPath;
@property (nonatomic, copy, nullable, readonly) NSString *profileAppDataPath;
@property (nonatomic, copy, nullable, readonly) NSString *globalSafariPath;
@property (nonatomic, copy, nullable, readonly) NSString *preferencesPath;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *systemGlobalPathsBySubdirectory;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *sharedDatabasePathsByRelativePath;

+ (nullable instancetype)destinationPlanForRestorePlan:(PXRestorePlan *)restorePlan
                                      bundleIdentifier:(NSString *)bundleIdentifier
                               activeProfileIdentifier:(nullable NSString *)profileIdentifier
                                                 error:(NSError * _Nullable * _Nullable)error;

- (nullable NSString *)systemGlobalPathForSubdirectory:(NSString *)subdirectory;
- (nullable NSString *)sharedDatabasePathForRelativePath:(NSString *)relativePath;

- (nullable NSString *)revalidatedProfileAppDataPathWithError:(NSError * _Nullable * _Nullable)error;
- (nullable NSString *)revalidatedGlobalSafariPathWithError:(NSError * _Nullable * _Nullable)error;
- (nullable NSString *)revalidatedPreferencesPathWithError:(NSError * _Nullable * _Nullable)error;
- (nullable NSString *)revalidatedSystemGlobalPathForSubdirectory:(NSString *)subdirectory
                                                             error:(NSError * _Nullable * _Nullable)error;
- (nullable NSString *)revalidatedSharedDatabasePathForRelativePath:(NSString *)relativePath
                                                               error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
