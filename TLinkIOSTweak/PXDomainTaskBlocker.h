#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef BOOL (^PXDomainTaskBlockPredicate)(NSString *host);

/// Observe the concrete session's supported public task factories. The session,
/// requests, tasks, configuration, delegates and completion blocks are preserved.
/// Policy is evaluated at resume, not when the factory returns a suspended task.
FOUNDATION_EXPORT BOOL PXDomainObserveURLSession(NSURLSession * _Nullable session,
                                               PXDomainTaskBlockPredicate predicate);

NS_ASSUME_NONNULL_END
