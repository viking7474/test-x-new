#import <Foundation/Foundation.h>
#import "PXRuntimeSnapshotReader.h"
#import "PXRuntimeReadScope.h"
#import "PXRuntimePublisher.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *PXRuntimeSnapshotPath(void);
FOUNDATION_EXPORT NSString * _Nullable PXRuntimeSnapshotLocalContainerPath(void);
FOUNDATION_EXPORT NSDictionary *PXLoadRuntimeSnapshot(void);

/// Captured reader rollout. Nil means initial load/invalidation is pending;
/// a non-nil invalid view means the last read failed validation or was absent.
/// RootHide consumers use a lexical operation so policy and data share this view.
FOUNDATION_EXPORT PXRuntimeReadSnapshot * _Nullable PXCaptureRuntimeSnapshot(void);
/// Scoped bootstrap only: register lazy observers, request the first load and
/// wait at most one second. Hot hooks must only capture, never call this function.
FOUNDATION_EXPORT BOOL PXPrepareRuntimeSnapshotReader(void);
/// Cold process classification only; no observers are installed for denied roles.
FOUNDATION_EXPORT BOOL PXPrimeRuntimeSnapshotReader(void);
FOUNDATION_EXPORT void PXRuntimeSnapshotRegisterPreparation(void (^handler)(PXRuntimeReadSnapshot *view));
FOUNDATION_EXPORT void PXInvalidateRuntimeSnapshotReader(void);
FOUNDATION_EXPORT void PXBeginRuntimeSnapshotOperation(PXRuntimeReadScope *scope);

// Clang cleanup runs for lexical returns and Objective-C exception unwinding.
// Each synchronous hook/helper owns its stack frame; async callbacks start a new
// operation. Rootful readers retain their existing live-file behavior in 4A.
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
#define PX_RUNTIME_READ_OPERATION \
    PXRuntimeReadScope pxRuntimeOperationScope __attribute__((cleanup(PXRuntimeReadScopeEnd))) = {0}; \
    PXBeginRuntimeSnapshotOperation(&pxRuntimeOperationScope)
#else
#define PX_RUNTIME_READ_OPERATION ((void)0)
#endif

/// Compatibility field getters. RootHide uses the captured view; rootful keeps
/// the historical live-file path. New grouped operations must capture once.
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
FOUNDATION_EXPORT PXRuntimePublisher * _Nullable PXCreateRuntimeSnapshotPublisher(
    void (^ _Nullable completion)(NSDictionary *result), NSError * _Nullable * _Nullable error);

NS_ASSUME_NONNULL_END
