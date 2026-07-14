#import <Foundation/Foundation.h>

@class PXValidatedMainDataStage;
@class PXValidatedOptionalFileStage;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PXOptionalRestoreTransactionErrorDomain;
FOUNDATION_EXPORT NSString * const PXOptionalRestoreTransactionErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXOptionalRestoreTransactionItemKind) {
    PXOptionalRestoreTransactionItemKindDirectoryContents = 1,
    PXOptionalRestoreTransactionItemKindDirectoryObject = 2,
    PXOptionalRestoreTransactionItemKindFileObject = 3,
};

typedef NS_ENUM(NSInteger, PXOptionalRestoreTransactionErrorCode) {
    PXOptionalRestoreTransactionErrorInvalidInput = 1,
    PXOptionalRestoreTransactionErrorDestinationValidationFailed = 2,
    PXOptionalRestoreTransactionErrorFilesystemInspectionFailed = 3,
    PXOptionalRestoreTransactionErrorLockFailed = 4,
    PXOptionalRestoreTransactionErrorCrossDeviceBoundary = 5,
    PXOptionalRestoreTransactionErrorEntryLimitExceeded = 6,
    PXOptionalRestoreTransactionErrorWorkspaceCreationFailed = 7,
    PXOptionalRestoreTransactionErrorReplacementPreparationFailed = 8,
    PXOptionalRestoreTransactionErrorReplacementMismatch = 9,
    PXOptionalRestoreTransactionErrorJournalCreationFailed = 10,
    PXOptionalRestoreTransactionErrorJournalInvalid = 11,
    PXOptionalRestoreTransactionErrorQuarantineFailed = 12,
    PXOptionalRestoreTransactionErrorCommitFailed = 13,
    PXOptionalRestoreTransactionErrorRollbackFailed = 14,
    PXOptionalRestoreTransactionErrorCleanupFailed = 15,
    PXOptionalRestoreTransactionErrorFilesystemChanged = 16,
    PXOptionalRestoreTransactionErrorInconsistentBatch = 17,
    PXOptionalRestoreTransactionErrorRecoveryFailed = 18,
};

__attribute__((objc_subclassing_restricted))
@interface PXOptionalRestoreTransactionItem : NSObject <NSCopying>
@property (nonatomic, assign, readonly) PXOptionalRestoreTransactionItemKind kind;
@property (nonatomic, copy, readonly) NSString *destinationPath;
@property (nonatomic, strong, nullable, readonly) PXValidatedMainDataStage *validatedDirectoryStage;
@property (nonatomic, strong, nullable, readonly) PXValidatedOptionalFileStage *validatedFileStage;

+ (nullable instancetype)directoryContentsItemWithDestinationPath:(NSString *)destinationPath
                                                   validatedStage:(PXValidatedMainDataStage *)validatedStage
                                                            error:(NSError * _Nullable * _Nullable)error;

+ (nullable instancetype)directoryObjectItemWithDestinationPath:(NSString *)destinationPath
                                                 validatedStage:(PXValidatedMainDataStage *)validatedStage
                                                          error:(NSError * _Nullable * _Nullable)error;

+ (nullable instancetype)fileObjectItemWithDestinationPath:(NSString *)destinationPath
                                            validatedStage:(PXValidatedOptionalFileStage *)validatedStage
                                                     error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

__attribute__((objc_subclassing_restricted))
@interface PXOptionalRestoreTransaction : NSObject
@property (nonatomic, assign, readonly, getter=isCommitted) BOOL committed;
@property (nonatomic, assign, readonly) BOOL rollbackPerformed;
@property (nonatomic, assign, readonly) BOOL rollbackComplete;
@property (nonatomic, assign, readonly) NSUInteger recoveredStaleTransactionCount;
@property (nonatomic, assign, readonly) NSUInteger itemCount;

+ (nullable instancetype)transactionForItems:(NSArray<PXOptionalRestoreTransactionItem *> *)items
                                        error:(NSError * _Nullable * _Nullable)error;

- (BOOL)commitWithCleanupWarning:(NSError * _Nullable * _Nullable)cleanupWarning
                           error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
