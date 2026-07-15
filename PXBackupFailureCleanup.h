#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class PXBackupPublicationWorkspace;
@class PXBackupBundleLock;
@class PXBackupDirectoryPublisher;

FOUNDATION_EXPORT NSErrorDomain const PXBackupFailureCleanupErrorDomain;
FOUNDATION_EXPORT NSString * const PXBackupFailureCleanupErrorFieldPathKey;

typedef NS_ERROR_ENUM(PXBackupFailureCleanupErrorDomain,
                      PXBackupFailureCleanupErrorCode) {
    PXBackupFailureCleanupErrorInvalidInput = 1,
    PXBackupFailureCleanupErrorLockValidationFailed = 2,
    PXBackupFailureCleanupErrorParentInspectionFailed = 3,
    PXBackupFailureCleanupErrorWorkspaceInspectionFailed = 4,
    PXBackupFailureCleanupErrorWorkspaceChanged = 5,
    PXBackupFailureCleanupErrorUnsafeEntry = 6,
    PXBackupFailureCleanupErrorEntryChanged = 7,
    PXBackupFailureCleanupErrorLimitExceeded = 8,
    PXBackupFailureCleanupErrorTraversalFailed = 9,
    PXBackupFailureCleanupErrorRemovalFailed = 10,
    PXBackupFailureCleanupErrorDurabilityFailed = 11,
    PXBackupFailureCleanupErrorCleanupIncomplete = 12,
    PXBackupFailureCleanupErrorPublishedStateDetected = 13,
    PXBackupFailureCleanupErrorAlreadyFinished = 14,
    PXBackupFailureCleanupErrorDisarmValidationFailed = 15,
    PXBackupFailureCleanupErrorFactoryCleanupFailed = 16,
};

__attribute__((objc_subclassing_restricted))
@interface PXBackupFailureCleanup : NSObject

@property (nonatomic, copy, readonly) NSString *workspacePath;
@property (nonatomic, copy, readonly) NSString *workspaceName;
@property (nonatomic, readonly) BOOL cleanupAttempted;
@property (nonatomic, readonly) BOOL cleaned;
@property (nonatomic, readonly) BOOL disarmed;
@property (nonatomic, readonly) NSUInteger removedEntryCount;

+ (nullable instancetype)cleanupForWorkspace:(PXBackupPublicationWorkspace *)workspace
                                  bundleLock:(PXBackupBundleLock *)bundleLock
                                       error:(NSError * _Nullable * _Nullable)error;

- (BOOL)cleanupWithError:(NSError * _Nullable * _Nullable)error;

- (BOOL)disarmAfterPublishedDirectory:(PXBackupDirectoryPublisher *)publisher
                                error:(NSError * _Nullable * _Nullable)error;

- (BOOL)validateIdentityWithError:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
