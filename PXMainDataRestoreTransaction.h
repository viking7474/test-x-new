#import <Foundation/Foundation.h>

@class PXResolvedContainer;
@class PXValidatedMainDataStage;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PXMainDataRestoreTransactionErrorDomain;
FOUNDATION_EXPORT NSString * const PXMainDataRestoreTransactionErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXMainDataRestoreTransactionErrorCode) {
    PXMainDataRestoreTransactionErrorInvalidInput = 1,
    PXMainDataRestoreTransactionErrorDestinationValidationFailed = 2,
    PXMainDataRestoreTransactionErrorFilesystemInspectionFailed = 3,
    PXMainDataRestoreTransactionErrorCrossDeviceBoundary = 4,
    PXMainDataRestoreTransactionErrorEntryLimitExceeded = 5,
    PXMainDataRestoreTransactionErrorJournalCreationFailed = 6,
    PXMainDataRestoreTransactionErrorJournalInvalid = 7,
    PXMainDataRestoreTransactionErrorQuarantineFailed = 8,
    PXMainDataRestoreTransactionErrorCommitFailed = 9,
    PXMainDataRestoreTransactionErrorRollbackFailed = 10,
    PXMainDataRestoreTransactionErrorCleanupFailed = 11,
    PXMainDataRestoreTransactionErrorFilesystemChanged = 12,
};

__attribute__((objc_subclassing_restricted))
@interface PXMainDataRestoreTransaction : NSObject

@property (nonatomic, assign, readonly, getter=isCommitted) BOOL committed;
@property (nonatomic, assign, readonly) BOOL rollbackPerformed;
@property (nonatomic, assign, readonly) BOOL rollbackComplete;
@property (nonatomic, assign, readonly) NSUInteger recoveredStaleTransactionCount;

+ (nullable instancetype)transactionForContainer:(PXResolvedContainer *)container
                                   canonicalPath:(NSString *)canonicalPath
                                  validatedStage:(PXValidatedMainDataStage *)validatedStage
                                           error:(NSError * _Nullable * _Nullable)error;

- (BOOL)commitWithCleanupWarning:(NSError * _Nullable * _Nullable)cleanupWarning
                           error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
