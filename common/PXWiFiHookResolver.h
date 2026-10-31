#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Cold fallback only. The cache reader must never generate or persist. Nil is
/// a cache miss; an error means the optional provider is unavailable. It runs
/// after standalone admission and before lifecycle acquisition (singleton init
/// may itself resolve profiles). Returned cache candidates are not commit ACKs.
typedef NSDictionary * _Nullable (^PXWiFiHookCacheReader)(NSString *profileID, NSError * _Nullable * _Nullable error);
/// Fixes the requested active ID, pins an existing identity directory and
/// rechecks sources. New data is returned only after an acknowledged paired
/// commit. Never creates directories, adopts manager cache or sends notifications.
FOUNDATION_EXPORT NSDictionary * _Nullable PXResolveHookWiFiInfo(NSString *profileID,
    PXWiFiHookCacheReader _Nullable cacheReader, NSError * _Nullable * _Nullable error);
NS_ASSUME_NONNULL_END
