#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Main-thread, process-local Reset admission. The owner is weak; the token has
/// no owner back-reference. No service/lifecycle/source lock is held by this API.
FOUNDATION_EXPORT NSObject * _Nullable PXBeginDashboardResetAdmission(id _Nullable owner);
FOUNDATION_EXPORT BOOL PXDashboardResetAdmissionMatches(id _Nullable owner, NSObject * _Nullable token);
FOUNDATION_EXPORT BOOL PXFinishDashboardResetAdmission(id _Nullable owner, NSObject * _Nullable token);
NS_ASSUME_NONNULL_END
