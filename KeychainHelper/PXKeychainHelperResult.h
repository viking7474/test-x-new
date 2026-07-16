#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSInteger const PXKeychainHelperResultSchemaVersion;
FOUNDATION_EXPORT NSString * const PXKeychainHelperResultOutputPrefix;
FOUNDATION_EXPORT NSErrorDomain const PXKeychainHelperResultErrorDomain;
FOUNDATION_EXPORT NSString * const PXKeychainHelperResultErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXKeychainHelperOperation) {
    PXKeychainHelperOperationUnknown = 0,
    PXKeychainHelperOperationBackup = 1,
    PXKeychainHelperOperationRestore = 2,
    PXKeychainHelperOperationWipe = 3,
    PXKeychainHelperOperationList = 4,
};

typedef NS_ENUM(NSInteger, PXKeychainHelperCompletion) {
    PXKeychainHelperCompletionFailed = 1,
    PXKeychainHelperCompletionCompleted = 2,
    PXKeychainHelperCompletionPartial = 3,
};

typedef NS_ERROR_ENUM(PXKeychainHelperResultErrorDomain,
                      PXKeychainHelperResultErrorCode) {
    PXKeychainHelperResultErrorInvalidInput = 1,
    PXKeychainHelperResultErrorInvalidOperation = 2,
    PXKeychainHelperResultErrorInvalidCompletion = 3,
    PXKeychainHelperResultErrorInvalidCounts = 4,
    PXKeychainHelperResultErrorInvalidFatalError = 5,
    PXKeychainHelperResultErrorLimitExceeded = 6,
    PXKeychainHelperResultErrorSerializationFailed = 7,
    PXKeychainHelperResultErrorInternalInvariantFailed = 8,
};

__attribute__((objc_subclassing_restricted))
@interface PXKeychainHelperResult : NSObject <NSCopying>

@property (nonatomic, readonly) NSInteger schemaVersion;
@property (nonatomic, readonly) PXKeychainHelperOperation operation;
@property (nonatomic, readonly) PXKeychainHelperCompletion completion;
@property (nonatomic, readonly) NSUInteger attemptedCount;
@property (nonatomic, readonly) NSUInteger succeededCount;
@property (nonatomic, readonly) NSUInteger failedCount;
@property (nonatomic, readonly) NSUInteger skippedCount;
@property (nonatomic, readonly) NSUInteger warningCount;
@property (nonatomic, readonly) NSUInteger errorCount;
@property (nonatomic, readonly) BOOL fatalErrorPresent;
@property (nonatomic, copy, readonly) NSString *fatalErrorDomain;
@property (nonatomic, readonly) NSInteger fatalErrorCode;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *propertyListRepresentation;
@property (nonatomic, copy, readonly) NSString *machineReadableLine;

+ (nullable instancetype)resultWithOperation:(PXKeychainHelperOperation)operation
                                  completion:(PXKeychainHelperCompletion)completion
                              attemptedCount:(NSUInteger)attemptedCount
                              succeededCount:(NSUInteger)succeededCount
                                 failedCount:(NSUInteger)failedCount
                                skippedCount:(NSUInteger)skippedCount
                                warningCount:(NSUInteger)warningCount
                                  errorCount:(NSUInteger)errorCount
                                  fatalError:(NSError * _Nullable)fatalError
                                       error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
