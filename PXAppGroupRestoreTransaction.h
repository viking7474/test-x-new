#import <Foundation/Foundation.h>

@class PXAppGroupRestoreTarget;
@class PXValidatedMainDataStage;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PXAppGroupRestoreTransactionErrorDomain;
FOUNDATION_EXPORT NSString * const PXAppGroupRestoreTransactionErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXAppGroupRestoreTransactionErrorCode) {
    PXAppGroupRestoreTransactionErrorInvalidInput = 1,
    PXAppGroupRestoreTransactionErrorTargetValidationFailed = 2,
    PXAppGroupRestoreTransactionErrorFilesystemInspectionFailed = 3,
    PXAppGroupRestoreTransactionErrorLockFailed = 4,
    PXAppGroupRestoreTransactionErrorCrossDeviceBoundary = 5,
    PXAppGroupRestoreTransactionErrorEntryLimitExceeded = 6,
    PXAppGroupRestoreTransactionErrorJournalCreationFailed = 7,
    PXAppGroupRestoreTransactionErrorJournalInvalid = 8,
    PXAppGroupRestoreTransactionErrorQuarantineFailed = 9,
    PXAppGroupRestoreTransactionErrorCommitFailed = 10,
    PXAppGroupRestoreTransactionErrorRollbackFailed = 11,
    PXAppGroupRestoreTransactionErrorCleanupFailed = 12,
    PXAppGroupRestoreTransactionErrorFilesystemChanged = 13,
    PXAppGroupRestoreTransactionErrorInconsistentBatch = 14,
    PXAppGroupRestoreTransactionErrorRecoveryFailed = 15,
};

__attribute__((objc_subclassing_restricted))
@interface PXAppGroupRestoreTransaction : NSObject

@property (nonatomic, assign, readonly, getter=isCommitted) BOOL committed;
@property (nonatomic, assign, readonly) BOOL rollbackPerformed;
@property (nonatomic, assign, readonly) BOOL rollbackComplete;
@property (nonatomic, assign, readonly) NSUInteger recoveredStaleBatchCount;
@property (nonatomic, assign, readonly) NSUInteger targetCount;

+ (nullable instancetype)transactionForTargets:(NSArray<PXAppGroupRestoreTarget *> *)targets
                               validatedStages:(NSArray<PXValidatedMainDataStage *> *)validatedStages
                                         error:(NSError * _Nullable * _Nullable)error;

- (BOOL)commitWithCleanupWarning:(NSError * _Nullable * _Nullable)cleanupWarning
                           error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
