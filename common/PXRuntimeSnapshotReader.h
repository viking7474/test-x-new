#import <Foundation/Foundation.h>
#include <stdint.h>

NS_ASSUME_NONNULL_BEGIN

/// Existing numeric/string boolean conventions, fail closed for malformed types.
FOUNDATION_EXPORT BOOL PXRuntimeReadBool(id _Nullable value);

/// Detached, deeply immutable view. Legacy schema 1 has no publication identity;
/// readerGeneration is process-local and must never masquerade as publisher revision.
@interface PXRuntimeReadSnapshot : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, readonly, getter=isValid) BOOL valid;
@property (nonatomic, readonly) NSUInteger schemaVersion;
@property (nonatomic, readonly) uint64_t readerGeneration;
@property (nonatomic, readonly) BOOL hasPublicationIdentity;
@property (nonatomic, copy, readonly, nullable) NSString *publisherEpoch;
@property (nonatomic, readonly) uint64_t revision;
@property (nonatomic, copy, readonly) NSDictionary *propertyList;
@property (nonatomic, copy, readonly, nullable) NSString *profileID;
@property (nonatomic, copy, readonly) NSDictionary *globalScope;
@property (nonatomic, copy, readonly) NSDictionary *securitySettings;
@property (nonatomic, copy, readonly) NSDictionary *tlinkSettings;
@property (nonatomic, copy, readonly) NSDictionary *profileSettings;
@property (nonatomic, copy, readonly) NSDictionary *deviceIDs;
- (instancetype)initWithPropertyList:(nullable NSDictionary *)propertyList
                   readerGeneration:(uint64_t)readerGeneration NS_DESIGNATED_INITIALIZER;
- (NSDictionary *)profileArtifact:(NSString *)key;
@end

typedef NSDictionary * _Nullable (^ _Nonnull PXRuntimeSnapshotLoader)(void);

/// Refreshes run on the reader's serial queue, except explicit bootstrap priming.
/// Captures never wait for I/O.
/// Callers keep one strong view and pass it to related field readers/helpers.
/// A loader that needs the reader must capture it weakly to avoid a cycle.
@interface PXRuntimeSnapshotReader : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)initWithLoader:(PXRuntimeSnapshotLoader)loader
              refreshInterval:(NSTimeInterval)refreshInterval NS_DESIGNATED_INITIALIZER;
- (nullable PXRuntimeReadSnapshot *)capture;
/// Constructor/bootstrap only: load inline if no view or worker exists. Never
/// wait for another thread (which may need a dyld/ObjC initialization lock held
/// by the caller). Returns NO for pending/invalid data; does not bypass validation.
- (BOOL)primeSynchronouslyIfIdle;
/// Clear the current publication immediately before asynchronous reload.
- (void)invalidateAndRefresh;
/// Slow fallback refresh retains the current view only while loading; failure
/// publishes an invalid/empty view rather than preserving enablement indefinitely.
- (void)requestRefresh;
/// Runs before publication on the loader queue (or the explicit bootstrap
/// caller); changing it invalidates current views. Handler must not mutate or
/// re-publish a view after this callback returns.
- (void)setPreparationHandler:(void (^ _Nullable)(PXRuntimeReadSnapshot *view))handler;
/// Bootstrap variant: reprepare inline if idle; an existing worker owns reload
/// otherwise. Must not be called by a hot getter or by a preparation callback.
- (void)setBootstrapPreparationHandler:(void (^ _Nullable)(PXRuntimeReadSnapshot *view))handler;
/// Bootstrap/tests only. Never use this on a hot hook or from the loader queue.
- (BOOL)waitForPendingRefresh:(NSTimeInterval)timeout;
@end

NS_ASSUME_NONNULL_END
