#import <Foundation/Foundation.h>

@class PXIdentitySnapshot;

NS_ASSUME_NONNULL_BEGIN

/// Immutable version/build projection captured from one identity snapshot generation.
@interface PXSystemVersionProjection : NSObject
@property (nonatomic, copy, readonly) NSString *productVersion;
@property (nonatomic, copy, readonly) NSString *productBuildVersion;
@property (nonatomic, copy, readonly) NSString *releaseType;
@property (nonatomic, copy, readonly, nullable) NSString *profileID;
@property (nonatomic, strong, readonly) NSNumber *generation;
@end

/// Returns nil unless IOSVersion and IOSBuild are both valid in the same snapshot.
FOUNDATION_EXPORT PXSystemVersionProjection * _Nullable
PXSystemVersionProjectionFromSnapshot(PXIdentitySnapshot * _Nullable snapshot);

/// Captures the current immutable snapshot exactly once.
FOUNDATION_EXPORT PXSystemVersionProjection * _Nullable
PXCurrentSystemVersionProjection(void);

/// Per-app reporting projection. Normal apps receive the configured profile
/// version/build even for upward spoofing. Apps selected by Fix Version receive
/// the physical runtime version/build while the rest of their profile stays active.
FOUNDATION_EXPORT PXSystemVersionProjection * _Nullable
PXCurrentReportingSystemVersionProjectionForBundle(NSString * _Nullable bundleID);

/// Physical/native compatibility projection retained for kernel/runtime safety.
/// Upward profiles are clamped to the real runtime pair.
FOUNDATION_EXPORT PXSystemVersionProjection * _Nullable
PXCurrentNativeSafeSystemVersionProjection(void);

/// Matches canonical and rootless/preboot SystemVersion.plist paths by components.
FOUNDATION_EXPORT BOOL PXIsSystemVersionPlistPath(NSString * _Nullable path);

/// Preserve every unknown key and atomically replace ProductVersion,
/// ProductBuildVersion and ReleaseType. Returns the original object on failure/no-op.
FOUNDATION_EXPORT NSDictionary *PXTransformSystemVersionDictionary(
    NSDictionary *original,
    PXSystemVersionProjection * _Nullable projection);

/// Parse, transform and serialize using the source plist format (XML/binary/OpenStep).
/// Returns the original data on any parse, validation or serialization failure.
FOUNDATION_EXPORT NSData *PXTransformSystemVersionData(
    NSData *original,
    PXSystemVersionProjection * _Nullable projection);

/// Structurally transform a plist string; no regex/text substitution is used.
/// Returns the original string on any failure.
FOUNDATION_EXPORT NSString *PXTransformSystemVersionString(
    NSString *original,
    NSStringEncoding sourceEncoding,
    PXSystemVersionProjection * _Nullable projection);

NS_ASSUME_NONNULL_END
