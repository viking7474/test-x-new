#import "PXRuntimeSnapshotReader.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct PXRuntimeReadScope {
    void * _Nullable retainedView;
    struct PXRuntimeReadScope * _Nullable previous;
    BOOL active;
    BOOL ownsView;
} PXRuntimeReadScope;

// Stack-only lexical context. Inherit even a nil (pending) outer capture;
// nested helpers must never resurrect a different generation within an operation.
FOUNDATION_EXPORT void PXRuntimeReadScopeBegin(PXRuntimeReadScope *scope, PXRuntimeSnapshotReader *reader);
FOUNDATION_EXPORT void PXRuntimeReadScopeEnd(PXRuntimeReadScope *scope);
FOUNDATION_EXPORT PXRuntimeReadSnapshot * _Nullable PXRuntimeReadScopeCurrent(BOOL * _Nullable hasScope);

// Compare with the newest owned script in this content controller, not a
// process-global counter. Unchanged fallback views add no redundant scripts.
FOUNDATION_EXPORT BOOL PXRuntimeShouldStageWebCapabilities(uint64_t incoming, NSInteger memoryGB, NSUInteger cores,
                                                          uint64_t previous, NSInteger previousMemoryGB, NSUInteger previousCores);

NS_ASSUME_NONNULL_END

