#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class PXBackupBundleLock;

FOUNDATION_EXPORT NSErrorDomain const PXBackupStaleWorkspaceCleanupErrorDomain;
FOUNDATION_EXPORT NSString * const PXBackupStaleWorkspaceCleanupErrorFieldPathKey;

typedef NS_ERROR_ENUM(PXBackupStaleWorkspaceCleanupErrorDomain,
                      PXBackupStaleWorkspaceCleanupErrorCode) {
    PXBackupStaleWorkspaceCleanupErrorInvalidInput = 1,
    PXBackupStaleWorkspaceCleanupErrorLockValidationFailed = 2,
    PXBackupStaleWorkspaceCleanupErrorParentInspectionFailed = 3,
    PXBackupStaleWorkspaceCleanupErrorTraversalFailed = 4,
    PXBackupStaleWorkspaceCleanupErrorReservedNameInvalid = 5,
    PXBackupStaleWorkspaceCleanupErrorUnsafeReservedEntry = 6,
    PXBackupStaleWorkspaceCleanupErrorEntryChanged = 7,
    PXBackupStaleWorkspaceCleanupErrorLimitExceeded = 8,
    PXBackupStaleWorkspaceCleanupErrorQuarantineFailed = 9,
    PXBackupStaleWorkspaceCleanupErrorRollbackFailed = 10,
    PXBackupStaleWorkspaceCleanupErrorRemovalFailed = 11,
    PXBackupStaleWorkspaceCleanupErrorDurabilityFailed = 12,
    PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete = 13,
    PXBackupStaleWorkspaceCleanupErrorFilesystemChanged = 14,
    PXBackupStaleWorkspaceCleanupErrorAlreadyPerformed = 15,
    PXBackupStaleWorkspaceCleanupErrorPublishedEntryDetected = 16,
    PXBackupStaleWorkspaceCleanupErrorInternalInvariantFailed = 17,
    PXBackupStaleWorkspaceCleanupErrorMissingError = 18,
};

__attribute__((objc_subclassing_restricted))
@interface PXBackupStaleWorkspaceCleanup : NSObject

@property (nonatomic, copy, readonly) NSString *canonicalBundleDirectoryPath;
@property (nonatomic, readonly) BOOL cleanupAttempted;
@property (nonatomic, readonly) NSUInteger cleanedWorkspaceCount;
@property (nonatomic, readonly) NSUInteger removedEntryCount;

+ (nullable instancetype)cleanupForBundleLock:(PXBackupBundleLock *)bundleLock
                                        error:(NSError * _Nullable * _Nullable)error;

- (BOOL)removeStaleWorkspacesWithError:(NSError * _Nullable * _Nullable)error;
- (BOOL)validateIdentityWithError:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
