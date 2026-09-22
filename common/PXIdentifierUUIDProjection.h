#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Returns a validated profile UUID while preserving the original object's
/// runtime shape. Invalid/missing values fail open to the original.
FOUNDATION_EXPORT NSUUID * _Nullable PXProjectIdentityUUID(NSUUID * _Nullable original,
                                                            id _Nullable profileValue);

/// Canonical IDFA projection shared by AdSupport and LaunchServices. The
/// profile ATT status controls zero-IDFA behavior; an authorized profile uses
/// deviceIDs["IDFA"], with invalid/missing IDFA failing open to the original.
FOUNDATION_EXPORT NSUUID * _Nullable PXProjectAdvertisingIdentityUUID(NSUUID * _Nullable original,
                                                                       NSDictionary *deviceIDs);

/// Reads a validated ATT status (0...3) from the same immutable identity
/// snapshot used by the identifier projection. Missing/invalid status is 0.
FOUNDATION_EXPORT NSInteger PXIdentitySnapshotATTAuthorizationStatus(NSDictionary *deviceIDs);

NS_ASSUME_NONNULL_END
