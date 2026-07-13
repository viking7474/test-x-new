#import <Foundation/Foundation.h>
#import "PXClearRequest.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, PXClearComponentStatus) {
    PXClearComponentStatusSucceeded = 1,
    PXClearComponentStatusSkipped = 2,
    PXClearComponentStatusFailed = 3,
};

__attribute__((objc_subclassing_restricted))
@interface PXClearFailure : NSObject <NSCopying> {
@private
    NSString *_domain;
    NSInteger _code;
    NSString *_message;
}

@property (nonatomic, copy, readonly) NSString *domain;
@property (nonatomic, assign, readonly) NSInteger code;
@property (nonatomic, copy, readonly) NSString *message;

- (nullable instancetype)initWithDomain:(NSString *)domain
                                   code:(NSInteger)code
                                message:(NSString *)message
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PXClearComponentResult : NSObject <NSCopying> {
@private
    PXClearScope _scope;
    PXClearComponentStatus _status;
    NSUInteger _attemptedUnitCount;
    NSUInteger _succeededUnitCount;
    NSUInteger _failedUnitCount;
    NSString *_detail;
    PXClearFailure *_failure;
}

@property (nonatomic, assign, readonly) PXClearScope scope;
@property (nonatomic, assign, readonly) PXClearComponentStatus status;
@property (nonatomic, assign, readonly) NSUInteger attemptedUnitCount;
@property (nonatomic, assign, readonly) NSUInteger succeededUnitCount;
@property (nonatomic, assign, readonly) NSUInteger failedUnitCount;
@property (nonatomic, copy, readonly, nullable) NSString *detail;
@property (nonatomic, copy, readonly, nullable) PXClearFailure *failure;

- (nullable instancetype)initWithScope:(PXClearScope)scope
                                status:(PXClearComponentStatus)status
                    attemptedUnitCount:(NSUInteger)attemptedUnitCount
                    succeededUnitCount:(NSUInteger)succeededUnitCount
                       failedUnitCount:(NSUInteger)failedUnitCount
                                detail:(nullable NSString *)detail
                               failure:(nullable PXClearFailure *)failure
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PXClearResult : NSObject <NSCopying> {
@private
    PXClearRequest *_request;
    NSArray<PXClearComponentResult *> *_componentResults;
    PXClearScope _succeededScopes;
    PXClearScope _skippedScopes;
    PXClearScope _failedScopes;
}

@property (nonatomic, copy, readonly) PXClearRequest *request;
@property (nonatomic, copy, readonly) NSArray<PXClearComponentResult *> *componentResults;
@property (nonatomic, assign, readonly) PXClearScope succeededScopes;
@property (nonatomic, assign, readonly) PXClearScope skippedScopes;
@property (nonatomic, assign, readonly) PXClearScope failedScopes;
@property (nonatomic, assign, readonly) BOOL hasFailures;
@property (nonatomic, assign, readonly) BOOL allRequestedScopesSucceeded;

- (nullable instancetype)initWithRequest:(PXClearRequest *)request
                        componentResults:(NSArray<PXClearComponentResult *> *)componentResults
    NS_DESIGNATED_INITIALIZER;

- (nullable PXClearComponentResult *)componentResultForScope:(PXClearScope)scope;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
