#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Prepare IDFA/IDFV, DeviceName, nine lowercase v4 UUIDs, or UDID without
/// initializing providers, publishing caches or writing sources/preferences.
/// Preserves provider generation formats and failure codes. Serial uses its
/// separate policy adapter and explicit-prefix factory below.
FOUNDATION_EXPORT NSString * _Nullable PXPrepareRuntimeScalar(NSString * _Nullable type, NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT NSString * _Nullable PXPrepareRuntimeSerial(NSString * _Nullable prefix, NSError * _Nullable * _Nullable error);
NS_ASSUME_NONNULL_END
