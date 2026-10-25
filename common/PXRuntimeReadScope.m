#import "PXRuntimeReadScope.h"
#import <CoreFoundation/CoreFoundation.h>
#include <errno.h>

static __thread PXRuntimeReadScope *gPXRuntimeReadScope;

void PXRuntimeReadScopeBegin(PXRuntimeReadScope *scope, PXRuntimeSnapshotReader *reader) {
    int savedErrno = errno;
    scope->previous = gPXRuntimeReadScope;
    if (gPXRuntimeReadScope) {
        // A synchronous child cannot outlive its lexical parent. Borrow its
        // owned view instead of retaining it again for every recursive helper.
        scope->retainedView = gPXRuntimeReadScope->retainedView;
        scope->ownsView = NO;
    } else {
        PXRuntimeReadSnapshot *view = [reader capture];
        scope->retainedView = (__bridge_retained void *)view;
        scope->ownsView = YES;
    }
    scope->active = YES;
    gPXRuntimeReadScope = scope;
    errno = savedErrno;
}

void PXRuntimeReadScopeEnd(PXRuntimeReadScope *scope) {
    if (!scope->active) return;
    int savedErrno = errno;
    if (gPXRuntimeReadScope == scope) gPXRuntimeReadScope = scope->previous;
    void *view = scope->retainedView;
    scope->retainedView = NULL;
    scope->active = NO;
    if (scope->ownsView && view) CFRelease((CFTypeRef)view);
    errno = savedErrno;
}

PXRuntimeReadSnapshot *PXRuntimeReadScopeCurrent(BOOL *hasScope) {
    if (hasScope) *hasScope = gPXRuntimeReadScope != NULL;
    return gPXRuntimeReadScope ? (__bridge PXRuntimeReadSnapshot *)gPXRuntimeReadScope->retainedView : nil;
}

BOOL PXRuntimeShouldStageWebCapabilities(uint64_t incoming, NSInteger memoryGB, NSUInteger cores,
                                        uint64_t previous, NSInteger previousMemoryGB, NSUInteger previousCores) {
    if (!incoming || incoming <= previous) return NO;
    return !previous || memoryGB != previousMemoryGB || cores != previousCores;
}
