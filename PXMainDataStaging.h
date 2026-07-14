#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PXMainDataStagingErrorDomain;
FOUNDATION_EXPORT NSString * const PXMainDataStagingErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXMainDataStagingErrorCode) {
    PXMainDataStagingErrorInvalidInput = 1,
    PXMainDataStagingErrorWorkspaceCreationFailed = 2,
    PXMainDataStagingErrorWorkspaceIdentityChanged = 3,
    PXMainDataStagingErrorWorkspaceNotEmpty = 4,
    PXMainDataStagingErrorEnumerationFailed = 5,
    PXMainDataStagingErrorUnsafeEntryPath = 6,
    PXMainDataStagingErrorUnsupportedEntryType = 7,
    PXMainDataStagingErrorHardLinkRejected = 8,
    PXMainDataStagingErrorForbiddenContainerMetadata = 9,
    PXMainDataStagingErrorLimitExceeded = 10,
    PXMainDataStagingErrorReadFailed = 11,
    PXMainDataStagingErrorFilesystemChanged = 12,
    PXMainDataStagingErrorSizeMismatch = 13,
    PXMainDataStagingErrorCleanupFailed = 14,
};

__attribute__((objc_subclassing_restricted))
@interface PXValidatedMainDataStage : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSString *workspaceRootPath;
@property (nonatomic, copy, readonly) NSString *dataPath;
@property (nonatomic, assign, readonly) NSUInteger entryCount;
@property (nonatomic, assign, readonly) NSUInteger regularFileCount;
@property (nonatomic, assign, readonly) NSUInteger directoryCount;
@property (nonatomic, assign, readonly) unsigned long long regularFileBytes;
@property (nonatomic, copy, readonly) NSString *treeSHA256;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PXMainDataStagingWorkspace : NSObject

@property (nonatomic, copy, readonly) NSString *rootPath;
@property (nonatomic, copy, readonly) NSString *dataPath;

+ (nullable instancetype)createWorkspaceWithError:(NSError * _Nullable * _Nullable)error;

- (BOOL)validateEmptyDataDirectoryWithError:(NSError * _Nullable * _Nullable)error;

- (nullable PXValidatedMainDataStage *)validatedStageWithExpectedLogicalMemberCount:(NSUInteger)logicalMemberCount
                                                           expectedRegularFileBytes:(unsigned long long)regularFileBytes
                                                                               error:(NSError * _Nullable * _Nullable)error;

- (BOOL)cleanupWithError:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
