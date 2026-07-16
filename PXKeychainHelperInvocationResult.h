#import <Foundation/Foundation.h>

#import "CommandRunner.h"
#import "KeychainHelper/PXKeychainHelperResult.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const PXKeychainHelperInvocationResultErrorDomain;
FOUNDATION_EXPORT NSString * const PXKeychainHelperInvocationResultErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXKeychainHelperInvocationStatus) {
    PXKeychainHelperInvocationStatusCompleted = 0,
    PXKeychainHelperInvocationStatusPartial,
    PXKeychainHelperInvocationStatusHelperFailed,
    PXKeychainHelperInvocationStatusProtocolFailed,
    PXKeychainHelperInvocationStatusWrapperFailed,
    PXKeychainHelperInvocationStatusProcessFailed,
};

typedef NS_ERROR_ENUM(PXKeychainHelperInvocationResultErrorDomain,
                      PXKeychainHelperInvocationResultErrorCode) {
    PXKeychainHelperInvocationResultErrorInvalidInput = 1,
    PXKeychainHelperInvocationResultErrorInvalidExpectedOperation = 2,
    PXKeychainHelperInvocationResultErrorInvalidExpectedAccessGroups = 3,
    PXKeychainHelperInvocationResultErrorInternalInvariantFailed = 4,
};

__attribute__((objc_subclassing_restricted))
@interface PXKeychainHelperInvocationResult : NSObject <NSCopying>

@property (nonatomic, readonly) PXKeychainHelperInvocationStatus status;
@property (nonatomic, readonly) PXKeychainHelperOperation expectedOperation;
@property (nonatomic, readonly) NSInteger exitCode;
@property (nonatomic, copy, nullable, readonly) PXKeychainHelperResult *helperResult;
@property (nonatomic, readonly) NSUInteger additionalEffectiveAccessGroupCount;
@property (nonatomic, readonly) BOOL diagnosticOutputTruncated;

+ (nullable NSArray<NSString *> *)canonicalAccessGroupsFromArray:(NSArray<NSString *> *)accessGroups
                                                           error:(NSError * _Nullable * _Nullable)error;

+ (nullable instancetype)resultWithCommandResult:(CommandResult * _Nullable)commandResult
                               expectedOperation:(PXKeychainHelperOperation)expectedOperation
                  expectedRequestedAccessGroups:(NSArray<NSString *> *)expectedRequestedAccessGroups
                                           error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
