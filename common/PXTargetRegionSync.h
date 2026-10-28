#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NSDictionary * _Nullable (^PXTargetRegionWork)(void);
typedef NSDictionary * _Nullable (^PXTargetRegionApply)(NSDictionary *response);
typedef void (^PXTargetRegionCompletion)(NSDictionary *result);

/// Per-owner ordering for explicit region sync and toggle changes. Controls/UI
/// use main; work runs serially, outside the short token lock. Admitted work may
/// finish after supersession; newer work runs after it. No cross-process CAS.
@interface PXTargetRegionSync : NSObject
- (void)syncWithApply:(PXTargetRegionApply)apply completion:(PXTargetRegionCompletion)completion;
/// Explicit setting writes survive UI owner release. Work must capture only
/// detached inputs/services, never UI/controller owners; completion uses weak UI.
- (void)performChange:(PXTargetRegionWork)work completion:(PXTargetRegionCompletion)completion;
@end
NS_ASSUME_NONNULL_END
