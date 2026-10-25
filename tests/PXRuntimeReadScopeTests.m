#import "PXRuntimeSnapshot.h"
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#include <stdatomic.h>
#include <stdlib.h>

static NSUInteger gChecks, gFailures;
static PXRuntimeSnapshotReader *gReader;
static char kPrepared;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)

// Test backend for the production lexical macro. No duplicate TLS/cleanup logic:
// these functions only select the fixture reader instead of jailbreak storage.
void PXBeginRuntimeSnapshotOperation(PXRuntimeReadScope *scope) { PXRuntimeReadScopeBegin(scope, gReader); }
PXRuntimeReadSnapshot *PXCaptureRuntimeSnapshot(void) {
    BOOL active = NO;
    PXRuntimeReadSnapshot *view = PXRuntimeReadScopeCurrent(&active);
    return active ? view : [gReader capture];
}

static NSDictionary *PXPayload(NSString *profile, BOOL enabled) {
    return @{ @"schemaVersion": @1, @"profileID": profile,
        @"securitySettings": @{ @"deviceSpoofingEnabled": @(enabled) },
        @"tlinkSettings": @{ @"EnabledIdentifiers": @{ @"IDFA": @(enabled) } },
        @"deviceIDs": @{ @"label": profile },
        @"profileArtifacts": @{ @"fixture": @{ @"value": profile } } };
}
@interface PXScopeSource : NSObject
@property (atomic, strong) NSDictionary *value;
@property (nonatomic) BOOL blockNext;
@property (nonatomic, strong) dispatch_semaphore_t entered, proceed;
- (NSDictionary *)load;
@end
@implementation PXScopeSource
- (instancetype)init {
    if ((self = [super init])) { _entered = dispatch_semaphore_create(0); _proceed = dispatch_semaphore_create(0); }
    return self;
}
- (NSDictionary *)load {
    BOOL block;
    NSDictionary *value;
    @synchronized(self) { value = self.value; block = self.blockNext; self.blockNext = NO; }
    if (block) {
        dispatch_semaphore_signal(self.entered);
        dispatch_semaphore_wait(self.proceed, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
    }
    return value;
}
@end

static BOOL PXNestedRead(NSString *profile, BOOL enabled) {
    PX_RUNTIME_READ_OPERATION;
    PXRuntimeReadSnapshot *view = PXCaptureRuntimeSnapshot();
    return [view.profileID isEqual:profile] &&
        [view.deviceIDs[@"label"] isEqual:profile] &&
        [[view profileArtifact:@"fixture"][@"value"] isEqual:profile] &&
        [view.securitySettings[@"deviceSpoofingEnabled"] boolValue] == enabled &&
        [view.tlinkSettings[@"EnabledIdentifiers"][@"IDFA"] boolValue] == enabled;
}
static void PXThrowingRead(void) {
    PX_RUNTIME_READ_OPERATION;
    @throw [NSException exceptionWithName:@"ScopeFixture" reason:nil userInfo:nil];
}
static NSString *PXReturnFieldAfterReload(PXScopeSource *source) {
    PX_RUNTIME_READ_OPERATION;
    source.value = PXPayload(@"new-profile", YES);
    [gReader invalidateAndRefresh];
    if (![gReader waitForPendingRefresh:3]) exit(EXIT_FAILURE);
    return PXCaptureRuntimeSnapshot().deviceIDs[@"label"];
}

static void PXCheckPinnedOperations(PXScopeSource *source) {
    source.value = PXPayload(@"profile-A", YES);
    [gReader requestRefresh]; CHECK([gReader waitForPendingRefresh:3], "initial runtime view ready");
    {
        PX_RUNTIME_READ_OPERATION;
        CHECK(PXNestedRead(@"profile-A", YES), "policy and data share initial operation view");
        source.value = PXPayload(@"profile-B", NO);
        [gReader invalidateAndRefresh]; CHECK([gReader waitForPendingRefresh:3], "replacement published during operation");
        CHECK(PXNestedRead(@"profile-A", YES), "nested helper never reacquires a newer publication");
        BOOL caught = NO;
        @try { PXThrowingRead(); } @catch (NSException *exception) { caught = [exception.name isEqual:@"ScopeFixture"]; }
        CHECK(caught && PXNestedRead(@"profile-A", YES), "exception restores outer lexical context");
    }
    BOOL active = YES;
    (void)PXRuntimeReadScopeCurrent(&active);
    CHECK(!active && PXNestedRead(@"profile-B", NO), "operation cleanup exposes revocation to next read");
    @try { PXThrowingRead(); } @catch (__unused NSException *exception) {}
    (void)PXRuntimeReadScopeCurrent(&active);
    CHECK(!active, "outer exception unwinds cleanup attribute");

    source.value = PXPayload(@"long-original-profile-name-owned-by-the-old-publication", YES);
    [gReader requestRefresh]; CHECK([gReader waitForPendingRefresh:3], "return-lifetime baseline ready");
    NSString *returned;
    @autoreleasepool { returned = PXReturnFieldAfterReload(source); }
    (void)PXRuntimeReadScopeCurrent(&active);
    CHECK(!active && [returned isEqual:@"long-original-profile-name-owned-by-the-old-publication"],
          "early returned field survives frame cleanup and old-view release");
}

static void PXCheckPendingAndPreparation(PXScopeSource *source) {
    source.blockNext = YES;
    [gReader invalidateAndRefresh];
    CHECK(dispatch_semaphore_wait(source.entered, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) == 0,
          "pending source is controlled before entering operation");
    {
        PX_RUNTIME_READ_OPERATION;
        CHECK(PXCaptureRuntimeSnapshot() == nil, "operation captures pending nil view");
        dispatch_semaphore_signal(source.proceed);
        CHECK([gReader waitForPendingRefresh:3], "new view ready while pending operation remains active");
        { PX_RUNTIME_READ_OPERATION; CHECK(PXCaptureRuntimeSnapshot() == nil, "nested scope cannot resurrect pending enablement"); }
    }
    CHECK(PXCaptureRuntimeSnapshot().valid, "new operation sees available view after pending frame ends");
    NSThread *caller = NSThread.currentThread;
    __block BOOL offThread = NO;
    [gReader setPreparationHandler:^(PXRuntimeReadSnapshot *view) {
        offThread = NSThread.currentThread != caller;
        objc_setAssociatedObject(view, &kPrepared, view.profileID, OBJC_ASSOCIATION_RETAIN);
    }];
    CHECK([gReader waitForPendingRefresh:3], "derived identity preparation finishes");
    PXRuntimeReadSnapshot *view = PXCaptureRuntimeSnapshot();
    CHECK(offThread && [objc_getAssociatedObject(view, &kPrepared) isEqual:view.profileID],
          "derived object is ready before view becomes visible to consumers");
    source.blockNext = YES;
    [gReader requestRefresh];
    CHECK(dispatch_semaphore_wait(source.entered, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) == 0,
          "old preparation load is in flight");
    [gReader setPreparationHandler:^(PXRuntimeReadSnapshot *candidate) {
        objc_setAssociatedObject(candidate, &kPrepared, @"replacement-preparer", OBJC_ASSOCIATION_RETAIN);
    }];
    CHECK(PXCaptureRuntimeSnapshot() == nil, "changing preparer atomically invalidates current publication");
    dispatch_semaphore_signal(source.proceed);
    CHECK([gReader waitForPendingRefresh:3], "replacement preparation drains");
    CHECK([objc_getAssociatedObject(PXCaptureRuntimeSnapshot(), &kPrepared) isEqual:@"replacement-preparer"],
          "old in-flight preparation cannot publish under the new handler");
}

static void PXCheckParallelScopes(PXScopeSource *source) {
    source.value = PXPayload(@"parallel", YES);
    [gReader requestRefresh]; CHECK([gReader waitForPendingRefresh:3], "parallel baseline ready");
    atomic_uint failures; atomic_init(&failures, 0);
    atomic_uint *counter = &failures;
    dispatch_apply(128, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^(size_t index) {
        (void)index;
        @autoreleasepool {
            BOOL active = YES;
            (void)PXRuntimeReadScopeCurrent(&active);
            if (active) atomic_fetch_add(counter, 1);
            {
                PX_RUNTIME_READ_OPERATION;
                if (!PXNestedRead(@"parallel", YES)) atomic_fetch_add(counter, 1);
            }
            (void)PXRuntimeReadScopeCurrent(&active);
            if (active) atomic_fetch_add(counter, 1);
        }
    });
    CHECK(atomic_load(&failures) == 0, "thread-local frames never leak between callbacks or threads");
    dispatch_group_t writer = dispatch_group_create();
    dispatch_group_async(writer, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        for (NSUInteger index = 0; index < 12; index++) {
            @autoreleasepool {
                source.value = PXPayload(index % 2 ? @"concurrent-A" : @"concurrent-B", index % 2 != 0);
                [gReader invalidateAndRefresh];
                if (![gReader waitForPendingRefresh:3]) atomic_fetch_add(counter, 1);
            }
        }
    });
    dispatch_apply(256, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^(size_t index) {
        (void)index;
        @autoreleasepool {
            PX_RUNTIME_READ_OPERATION;
            PXRuntimeReadSnapshot *view = PXCaptureRuntimeSnapshot();
            if (view) {
                NSString *profile = view.profileID;
                BOOL enabled = PXRuntimeReadBool(view.securitySettings[@"deviceSpoofingEnabled"]);
                [NSThread sleepForTimeInterval:0.0001];
                if (!PXNestedRead(profile, enabled)) atomic_fetch_add(counter, 1);
            } else {
                { PX_RUNTIME_READ_OPERATION; if (PXCaptureRuntimeSnapshot()) atomic_fetch_add(counter, 1); }
            }
        }
    });
    BOOL completed = dispatch_group_wait(writer, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0;
    CHECK(completed, "concurrent operation writer finishes");
    if (!completed) exit(EXIT_FAILURE);
    CHECK(atomic_load(&failures) == 0, "concurrent profile/toggle changes cannot mix policy and data within a scope");
}

static void PXCheckWebRevisions(void) {
    CHECK(PXRuntimeReadBool(@YES) && !PXRuntimeReadBool(@NO) && PXRuntimeReadBool(@"YES") &&
          !PXRuntimeReadBool(@[]) && !PXRuntimeReadBool(@{}) && !PXRuntimeReadBool(nil),
          "malformed runtime flags fail closed while numeric/string conventions remain compatible");
    CHECK(PXRuntimeShouldStageWebCapabilities(100, 4, 6, 0, 0, 0) &&
          !PXRuntimeShouldStageWebCapabilities(101, 4, 6, 100, 4, 6) &&
          PXRuntimeShouldStageWebCapabilities(102, 6, 8, 100, 4, 6),
          "unchanged fallback views do not add capability scripts; value changes advance revision");
    CHECK(!PXRuntimeShouldStageWebCapabilities(100, 4, 6, 102, 6, 8) &&
          PXRuntimeShouldStageWebCapabilities(100, 4, 6, 0, 0, 0),
          "older captured capability operation cannot override newer staging");
}

int main(void) {
    @autoreleasepool {
        PXScopeSource *source = [PXScopeSource new];
        gReader = [[PXRuntimeSnapshotReader alloc] initWithLoader:^NSDictionary *{ return [source load]; } refreshInterval:3600];
        PXCheckPinnedOperations(source);
        PXCheckPendingAndPreparation(source);
        PXCheckParallelScopes(source);
        PXCheckWebRevisions();
        fprintf(stderr, "Runtime read operations: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
