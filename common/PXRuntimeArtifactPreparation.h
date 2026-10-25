#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Cold preparation only: no profile lookup, persistence, manager initialization,
/// cache mutation or notification. Returned records are detached/immutable.
FOUNDATION_EXPORT NSDictionary *PXPrepareRuntimeWiFiInfo(void);
FOUNDATION_EXPORT NSString *PXPrepareRuntimeBatteryLevel(void);
FOUNDATION_EXPORT NSDictionary *PXPrepareRuntimeBatteryInfo(BOOL lowPowerMode);
/// Positive finite GB capacity representable in marketing bytes is required;
/// rejects unphysical computed free space and preserves accepted spelling.
FOUNDATION_EXPORT NSDictionary * _Nullable PXPrepareRuntimeStorage(NSString * _Nullable capacity);
FOUNDATION_EXPORT NSString *PXChooseRuntimeStorageCapacity(NSArray * _Nullable rawCapacities, NSString * _Nullable previous);
/// Caller supplies one clock sample and optional real-uptime probe result.
/// Keeps the legacy minimum clamp even when real uptime is below 12 hours.
FOUNDATION_EXPORT NSDictionary *PXPrepareRuntimeUptime(NSDate *now, NSTimeInterval realUptime, BOOL hasRealUptime);
NS_ASSUME_NONNULL_END
