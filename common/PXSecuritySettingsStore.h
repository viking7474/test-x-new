#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT id _Nullable PXReadSecuritySetting(NSString *key);
FOUNDATION_EXPORT BOOL PXReadSecurityBool(NSString *key, BOOL defaultValue);
FOUNDATION_EXPORT NSInteger PXReadSecurityInteger(NSString *key, NSInteger defaultValue);
FOUNDATION_EXPORT BOOL PXWriteSecuritySetting(NSString *key, id value, NSError **error);
FOUNDATION_EXPORT BOOL PXWriteSecurityBool(NSString *key, BOOL value, NSError **error);
FOUNDATION_EXPORT BOOL PXWriteSecurityInteger(NSString *key, NSInteger value, NSError **error);

NS_ASSUME_NONNULL_END
