#import "PXRuntimeSourceStore.h"

NS_ASSUME_NONNULL_BEGIN

/// Staging only. Explicit target path; no active-profile lookup, generation,
/// directory creation, notifications, callbacks or manager-cache mutation.
/// No-op with needsIPv6=YES if no paired value exists; caller prepares outside
/// the gate, then uses PXStageRuntimeAddresses with preserveExistingIPv6=YES.
FOUNDATION_EXPORT BOOL PXStageRuntimeIPv4WithExistingPair(PXRuntimeSourceTransaction *transaction,
    NSString *identityDirectory, NSString *ipv4, NSDate *timestamp, BOOL *needsIPv6,
    NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT BOOL PXStageRuntimeAddresses(PXRuntimeSourceTransaction *transaction,
    NSString *identityDirectory, NSString * _Nullable ipv4, NSString * _Nullable ipv6,
    BOOL preserveExistingIPv6, NSDate *timestamp, NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT BOOL PXStageRuntimeCarrier(PXRuntimeSourceTransaction *transaction,
    NSString *identityDirectory, NSDictionary *carrier, NSDate *networkTimestamp, NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT BOOL PXStageRuntimeWiFi(PXRuntimeSourceTransaction *transaction,
    NSString *identityDirectory, NSDictionary *wifi, NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT BOOL PXStageRuntimeBattery(PXRuntimeSourceTransaction *transaction,
    NSString *identityDirectory, NSDictionary *battery, NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT BOOL PXStageRuntimeUptime(PXRuntimeSourceTransaction *transaction,
    NSString *identityDirectory, NSDictionary *boot, NSDictionary *uptime, NSDate *timestamp,
    NSError * _Nullable * _Nullable error);

NS_ASSUME_NONNULL_END
