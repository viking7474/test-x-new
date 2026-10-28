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
FOUNDATION_EXPORT BOOL PXWriteSecuritySetting(NSString *key, id value, NSError **error);
FOUNDATION_EXPORT BOOL PXWriteSecurityBool(NSString *key, BOOL value, NSError **error);
FOUNDATION_EXPORT BOOL PXWriteSecurityInteger(NSString *key, NSInteger value, NSError **error);

NS_ASSUME_NONNULL_END
