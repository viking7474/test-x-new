#import <Foundation/Foundation.h>
#include <sys/types.h>
#include <sys/stat.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSDictionary * _Nullable (^PXRuntimePublicationLoader)(NSError * _Nullable * _Nullable error);
typedef BOOL (^PXRuntimePublicationWriter)(NSDictionary *snapshot, NSError * _Nullable * _Nullable error);
/// Must return `complete` and diagnostics. Retries receive the same snapshot.
typedef NSDictionary * (^PXRuntimePublicationDistributor)(NSDictionary *snapshot);
typedef BOOL (^PXRuntimePublicationNotifier)(NSError * _Nullable * _Nullable error);

/// Privileged publisher only. Every stage and callback runs on its serial queue.
/// The stable flock inode is never unlinked; ownership lasts until deallocation.
@interface PXRuntimePublisher : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (nullable instancetype)initWithDirectory:(NSString *)directory
                                   loader:(PXRuntimePublicationLoader)loader
                                   writer:(PXRuntimePublicationWriter)writer
                              distributor:(PXRuntimePublicationDistributor)distributor
                                 notifier:(PXRuntimePublicationNotifier)notifier
                               completion:(void (^ _Nullable)(NSDictionary *result))completion
                                    error:(NSError * _Nullable * _Nullable)error;
- (BOOL)tryAcquireOwnership:(NSError * _Nullable * _Nullable)error;
/// Coalesces bursts; only the lease owner can publish.
- (void)requestPublication;
/// Existing daemon fallback timer calls this; no additional polling timer.
- (void)serviceRequestsAndRetry;
/// Explicit owner operation. Reentrant calls fail instead of deadlocking.
- (NSDictionary *)publishNow;
/// Owner publishes directly; contender submits a UUID request and awaits its ack.
/// Timeout/partial distribution/notify failure are returned with success=NO.
- (NSDictionary *)syncOnceWithTimeout:(NSTimeInterval)timeout;
@end

/// Unique exclusive temp file, full write, permissions before atomic rename.
FOUNDATION_EXPORT BOOL PXRuntimeWritePropertyList(NSDictionary *value, NSString *path,
                                                uid_t owner, gid_t group, mode_t mode,
                                                NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT NSString * const PXRuntimeSyncRequestedNotification;

NS_ASSUME_NONNULL_END
