#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NSDictionary * _Nullable (^PXIPDisplayPreparation)(NSDictionary *payload);
typedef void (^PXIPDisplayCompletion)(NSDictionary * _Nullable payload);

/// One latest primary/fallback chain per owner. Controls and final delivery use
/// main; optional preparation runs on an ordered worker. Consumers weak-capture
/// owners. Cancel drops queued work/UI results; already admitted preparation can
/// finish its side effects and is not rolled back by cancellation.
@interface PXIPDisplayLookup : NSObject
- (void)resolveUsingFallback:(BOOL)fallbackOnly
                    prepare:(nullable PXIPDisplayPreparation)prepare
                 completion:(nullable PXIPDisplayCompletion)completion;
- (void)cancel;
@end
NS_ASSUME_NONNULL_END
