#import "PXRuntimeSourceStore.h"
@class PXProfileLifecycleLease;

NS_ASSUME_NONNULL_BEGIN

/// Synchronous ownership for standalone profile artifact writers. Resolve the
/// target only after acquiring lifecycle ownership, outside the source gate.
/// Callers must not acquire this from a source transaction or another lease.
@interface PXProfileArtifactMutation : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, copy, readonly) NSString *identityDirectory;
@property (nonatomic, copy, readonly) NSString *profileDirectory;
+ (nullable instancetype)acquireWithIdentityResolver:(NSString * _Nullable (^)(void))resolver
    error:(NSError * _Nullable * _Nullable)error NS_RETURNS_RETAINED;
/// Resolver may explicitly compose migration using this held capability.
/// It must not invalidate/retain the capability beyond this synchronous call.
+ (nullable instancetype)acquireWithIdentityResolverUsingLease:(NSString * _Nullable (^)(PXProfileLifecycleLease *lease))resolver
    error:(NSError * _Nullable * _Nullable)error NS_RETURNS_RETAINED;
/// For artifacts directly under a profile (e.g. storage.plist). Pins the profile
/// directory itself; an identity child is neither required nor created.
+ (nullable instancetype)acquireWithProfileIDResolver:(NSString * _Nullable (^)(void))resolver
    error:(NSError * _Nullable * _Nullable)error NS_RETURNS_RETAINED;
/// Optional-target writers may already own lifecycle while resolving whether
/// a profile exists. Borrow that capability; invalidate only closes this scope's
/// directory FD. The caller must retain/hold the lease until this scope ends.
+ (nullable instancetype)borrowWithLifecycleLease:(PXProfileLifecycleLease * _Nullable)lease
    identityResolver:(NSString * _Nullable (^)(void))resolver error:(NSError * _Nullable * _Nullable)error NS_RETURNS_RETAINED;
/// Borrow ownership for files directly under an existing profile, without
/// requiring an identity child or invalidating the caller's lease.
+ (nullable instancetype)borrowWithLifecycleLease:(PXProfileLifecycleLease * _Nullable)lease
    profileID:(NSString *)profileID error:(NSError * _Nullable * _Nullable)error NS_RETURNS_RETAINED;
/// Body stages source data only; no providers, notifications or cache callbacks.
- (BOOL)performSourceWrite:(BOOL (^)(PXRuntimeSourceTransaction *transaction, NSError * _Nullable * _Nullable error))body
    error:(NSError * _Nullable * _Nullable)error;
/// Release before compatibility callbacks or returning to a reentrant caller.
- (void)invalidate;
@end

NS_ASSUME_NONNULL_END
