#import <Foundation/Foundation.h>
#include <sys/types.h>

NS_ASSUME_NONNULL_BEGIN

/// Stage only; no source file changes until the outer block succeeds. Instances
/// must not escape their block or be used from another thread/async callback.
@interface PXRuntimeSourceTransaction : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (nullable NSDictionary *)dictionaryAtPath:(NSString *)path error:(NSError * _Nullable * _Nullable)error;
/// Includes staged presence; absent returns an empty dictionary with exists=NO.
- (nullable NSDictionary *)dictionaryAtPath:(NSString *)path exists:(BOOL * _Nullable)exists
                                      error:(NSError * _Nullable * _Nullable)error;
- (BOOL)setDictionary:(NSDictionary *)value atPath:(NSString *)path error:(NSError * _Nullable * _Nullable)error;
/// Stages absence with the same before-image/rollback contract as a write.
- (BOOL)removeDictionaryAtPath:(NSString *)path error:(NSError * _Nullable * _Nullable)error;
/// Compare the marker captured at write admission, under the source gate.
/// A mismatch poisons staging, even if the caller ignores NO. Legacy marker is @"".
- (BOOL)requireBaseCommitIdentifier:(NSString *)identifier error:(NSError * _Nullable * _Nullable)error;
/// Read-only admission marker; unlike require, comparing it does not poison staging.
- (nullable NSString *)baseCommitIdentifierWithError:(NSError * _Nullable * _Nullable)error;
/// Candidate marker for THIS transaction. Copy inside the block; use as a receipt
/// only after a standalone call returns YES AND this transaction staged a write.
/// A no-op transaction does not publish its candidate marker. No use after escape.
- (nullable NSString *)prospectiveCommitIdentifierWithError:(NSError * _Nullable * _Nullable)error;
@end

@interface PXRuntimeSourceStore : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (nullable instancetype)initWithDirectory:(NSString *)directory owner:(uid_t)owner group:(gid_t)group
                               allowsPath:(BOOL (^ _Nonnull)(NSString * _Nonnull path))allowsPath
                                    error:(NSError * _Nullable * _Nullable)error;
/// Nested writes on this instance share staged data; an inner error aborts the
/// outer operation. The block may only stage/read sources: no notifications,
/// external callbacks, publisher ownership, queue hops or waiting on other work.
/// Only the configured source owner may write/recover (the root daemon reads).
/// An acknowledged commit-marker write remains successful through subsequent
/// housekeeping exceptions; pre-marker failures/recovery still fail closed.
/// Write entry clears the supplied error output; journal cleanup may be deferred.
- (BOOL)performWrite:(BOOL (^ _Nonnull)(PXRuntimeSourceTransaction * _Nonnull transaction, NSError * _Nullable * _Nonnull error))body
               error:(NSError * _Nullable * _Nullable)error;
/// For APIs that publish compatibility effects after return. Reject a nested
/// invocation and poison its outer transaction so success always means committed.
- (BOOL)performStandaloneWrite:(BOOL (^ _Nonnull)(PXRuntimeSourceTransaction * _Nonnull transaction, NSError * _Nullable * _Nonnull error))body
                        error:(NSError * _Nullable * _Nullable)error;
/// Holds the source gate through load AND immutable detach, then releases it
/// before global write/distribution. Uncommitted/corrupt journals reject capture;
/// a validated journal matching the commit marker needs only later cleanup.
- (nullable NSDictionary *)capture:(NSDictionary * _Nullable (^ _Nonnull)(NSError * _Nullable * _Nonnull error))loader
                              error:(NSError * _Nullable * _Nullable)error;
#if defined(PX_SOURCE_TRANSACTION_TESTING)
@property (nonatomic, copy, nullable) void (^testCheckpoint)(NSString *stage);
#endif
@end

/// Production singleton uses mobile-owned state and an exact source allowlist.
/// These functions are cold writer/publisher APIs; never call from hot hooks.
FOUNDATION_EXPORT BOOL PXPerformRuntimeSourceWrite(
    BOOL (^ _Nonnull body)(PXRuntimeSourceTransaction * _Nonnull transaction, NSError * _Nullable * _Nonnull error), NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT BOOL PXPerformStandaloneRuntimeSourceWrite(
    BOOL (^ _Nonnull body)(PXRuntimeSourceTransaction * _Nonnull transaction, NSError * _Nullable * _Nonnull error), NSError * _Nullable * _Nullable error);
/// Bounded, immutable dictionary decoder for capture loaders. No lock/recovery:
/// call only inside a source capture, using configured canonical source paths.
/// Missing file returns an empty dictionary; malformed/nonregular input fails.
FOUNDATION_EXPORT NSDictionary * _Nullable PXReadRuntimeSourceDictionary(NSString *path, NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT NSDictionary * _Nullable PXCaptureRuntimeSources(
    NSDictionary * _Nullable (^ _Nonnull loader)(NSError * _Nullable * _Nonnull error), NSError * _Nullable * _Nullable error);

NS_ASSUME_NONNULL_END
