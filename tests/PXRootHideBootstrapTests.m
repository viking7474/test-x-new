// macOS cold-constructor integration: real process reader wrappers, PXScope,
// lexical scopes and runtime reader. Storage and identity projection are fixtures;
// this does not emulate ElleKit injection or iOS sandbox permissions.
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#import "PXRuntimeSnapshot.h"
#include <errno.h>
#include <stdio.h>

static NSDictionary *gPayload;
static NSRecursiveLock *gInitializationLock;
static NSThread *gLoaderThread;
static NSUInteger gLoads, gPrepared, gChecks, gFailures;
static char kProjection;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)

#include "PXRuntimeBootstrap.inc"
#import "../TLinkIOSTweak/PXScope.m"

static NSDictionary *PXRuntimeCapturedSource(void) {
    gLoads++;
    gLoaderThread = NSThread.currentThread;
    // Model a lock held by an initializer: another thread cannot load while
    // this constructor waits. Same-thread recursive entry remains legal.
    if (![gInitializationLock tryLock]) return nil;
    NSDictionary *value = gPayload;
    [gInitializationLock unlock];
    return value;
}

// Exercise the real registration/publication path without linking iOS databases.
void PXIdentitySnapshotStartObserving(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        PXRuntimeSnapshotRegisterPreparation(^(PXRuntimeReadSnapshot *view) {
            gPrepared++;
            objc_setAssociatedObject(view, &kProjection, @YES, OBJC_ASSOCIATION_RETAIN);
        });
        (void)PXPrepareRuntimeSnapshotReader();
    });
}

static NSDictionary *PXPayload(BOOL scoped, BOOL master) {
    return @{ @"schemaVersion": @2, @"publisherEpoch": @"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        @"revision": @1, @"profileID": @"fixture-profile",
        @"globalScope": @{ @"ScopedApps": @{ @"fixture.aida64": @{ @"enabled": @(scoped) } } },
        @"securitySettings": @{ @"deviceSpoofingEnabled": @(master) } };
}

__attribute__((constructor)) static void PXRunColdBootstrapFixture(void) {
    @autoreleasepool {
        gInitializationLock = [NSRecursiveLock new];
        [gInitializationLock lock];
        gPayload = PXPayload(YES, YES);
        PXCaptureProcessIdentity();
        // Only process classification is supplied by the fixture. Actual role
        // discovery in a sandboxed iOS App Store app still requires device QA.
        gPXProcessRole = PXProcessMainApp;
        gPXProcessBundleID = @"fixture.aida64";
        gPXProcessName = @"AIDA64";
        PXBootstrapDecision first = PXBootstrapDecisionForCurrentProcess();
        CHECK(PXBootstrapDecisionAllows(first, PXHookCapabilityNative), "cold constructor permits scoped app before returning");
        CHECK(gLoaderThread == NSThread.currentThread && gLoads == 2 && gPrepared == 1,
              "cold load and identity preparation never wait for initializer worker");
        PXRuntimeReadSnapshot *view = PXCaptureRuntimeSnapshot();
        CHECK(view.valid && [objc_getAssociatedObject(view, &kProjection) boolValue],
              "identity projection is ready after bootstrap returns");
        for (NSUInteger i = 0; i < 40; i++)
            CHECK(PXBootstrapAllows(PXHookCapabilityNative), "later constructors retain native permission");
        CHECK(gLoads == 2 && gPrepared == 1, "ctor gates reuse the immutable prepared view");
        [gInitializationLock unlock];

        // Revocation remains fail closed; the patch must not broaden scope.
        gPayload = PXPayload(NO, YES);
        PXInvalidateRuntimeSnapshotReader();
        CHECK([PXProcessRuntimeReader() waitForPendingRefresh:3], "scope revocation refresh completes");
        CHECK(!PXBootstrapAllows(PXHookCapabilityNative), "disabled target remains denied");
        gPayload = PXPayload(YES, NO);
        PXInvalidateRuntimeSnapshotReader();
        CHECK([PXProcessRuntimeReader() waitForPendingRefresh:3], "master revocation refresh completes");
        CHECK(PXBootstrapDecisionForCurrentProcess().reason == PXBootstrapDeniedMaster, "disabled master remains denied");
        gPayload = @{};
        PXInvalidateRuntimeSnapshotReader();
        CHECK([PXProcessRuntimeReader() waitForPendingRefresh:3], "invalid source refresh completes");
        CHECK(!PXPrimeRuntimeSnapshotReader() && !PXBootstrapAllows(PXHookCapabilityNative),
              "invalid snapshot cannot be mistaken for a successful prime");
    }
}

int main(void) {
    fprintf(stderr, "RootHide cold bootstrap: %lu/%lu checks passed\n",
        (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
    return gFailures ? 1 : 0;
}
