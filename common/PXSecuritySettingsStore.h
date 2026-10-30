#import <Foundation/Foundation.h>
#include <stdint.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT id _Nullable PXReadSecuritySetting(NSString *key);
/// NSNumber/NSString retain their legacy conversions; missing or malformed
/// scalar types use the caller's default rather than sending unsafe selectors.
FOUNDATION_EXPORT BOOL PXReadSecurityBool(NSString *key, BOOL defaultValue);
FOUNDATION_EXPORT NSInteger PXReadSecurityInteger(NSString *key, NSInteger defaultValue);
/// Merge one detached update packet in the shared source transaction. Empty is a no-op.
/// Compatibility defaults mirrors run after commit; cfprefsd authority is still partial.
FOUNDATION_EXPORT BOOL PXWriteSecuritySettings(NSDictionary<NSString *, id> *values, NSError **error);
/// Advance a uint32 nonce atomically, wrapping UINT32_MAX to 1. Output changes only on success.
FOUNDATION_EXPORT BOOL PXAdvanceSecurityNonce(NSString *key, uint32_t * _Nullable committedValue, NSError **error);
/// Increment the legacy clear counters as one source mutation. Nonnegative
/// integer/string counts must fit NSInteger and successes <= attempts. Outputs
/// change only after commit; telemetry failure must not fail the clear operation.
FOUNDATION_EXPORT BOOL PXRecordClearAttempt(BOOL firstAttemptSuccess,
                                           NSUInteger * _Nullable totalAttempts,
                                           NSUInteger * _Nullable firstAttemptSuccesses,
                                           NSError **error);
/// Commit legacy float preference coordinates and the preferred full-precision
/// position plist together. Parent creation is a preflight outside rollback.
/// Mirroring remains canonical-only after the primary source commit.
FOUNDATION_EXPORT BOOL PXWriteProfileIndicatorPosition(double x, double y, NSError **error);
FOUNDATION_EXPORT BOOL PXWriteSecuritySetting(NSString *key, id value, NSError **error);
FOUNDATION_EXPORT BOOL PXWriteSecurityBool(NSString *key, BOOL value, NSError **error);
/// Preserve the legacy secondary merge. Return rollback authority only if the
/// preceding commit still matches at admission; otherwise success has nil authority.
/// Authority is captured before mirrors; BOOL still acknowledges the source write.
FOUNDATION_EXPORT BOOL PXWriteSecurityBoolWithRollbackAuthority(NSString *key, BOOL value, NSString *expectedIdentifier,
    NSString * _Nullable * _Nullable rollbackIdentifier, NSError **error);
/// Mirror only while the cooperative source marker still matches; recheck after
/// mirrors. No source mutation. Does not make mirrors/notifications atomic.
FOUNDATION_EXPORT BOOL PXPublishSecurityBoolForSourceCommit(NSString *key, BOOL value, NSString *identifier);
FOUNDATION_EXPORT BOOL PXWriteSecurityInteger(NSString *key, NSInteger value, NSError **error);

NS_ASSUME_NONNULL_END
