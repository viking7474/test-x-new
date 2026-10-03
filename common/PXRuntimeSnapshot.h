#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *PXRuntimeSnapshotPath(void);
FOUNDATION_EXPORT NSString * _Nullable PXRuntimeSnapshotLocalContainerPath(void);
FOUNDATION_EXPORT NSDictionary *PXLoadRuntimeSnapshot(void);
FOUNDATION_EXPORT NSDictionary *PXRuntimeSnapshotLastPublishStats(void);

FOUNDATION_EXPORT NSDictionary *PXRuntimeSnapshotGlobalScope(void);
FOUNDATION_EXPORT NSDictionary *PXRuntimeSnapshotSecuritySettings(void);
FOUNDATION_EXPORT NSDictionary *PXRuntimeSnapshotTLinkSettings(void);
FOUNDATION_EXPORT NSString * _Nullable PXRuntimeSnapshotProfileID(void);
FOUNDATION_EXPORT NSDictionary *PXRuntimeSnapshotProfileSettings(void);
FOUNDATION_EXPORT NSDictionary *PXRuntimeSnapshotDeviceIDs(void);
FOUNDATION_EXPORT NSDictionary *PXRuntimeSnapshotProfileArtifact(NSString *key);

/// Publish a read-only runtime snapshot into jailbreak-owned storage. This is
/// intended for privileged manager/daemon processes; injected sandboxed apps
/// should only call the read accessors above.
FOUNDATION_EXPORT BOOL PXPublishRuntimeSnapshot(NSError * _Nullable * _Nullable error);

NS_ASSUME_NONNULL_END
