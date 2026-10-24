#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "PXRuntimeSnapshotReader.h"
#include <errno.h>
#include <stdatomic.h>
#include <stdlib.h>

static NSUInteger gChecks, gFailures;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)

static NSDictionary *PXFixturePayload(NSUInteger tag) {
    return @{
        @"schemaVersion": @1, @"profileID": [NSString stringWithFormat:@"profile-%lu", (unsigned long)tag],
        @"globalScope": @{ @"ScopedApps": @{ @"fixture.app": @{ @"enabled": @YES } } },
        @"securitySettings": @{ @"deviceSpoofingEnabled": @YES },
        @"tlinkSettings": @{ @"EnabledIdentifiers": @{ @"BootTime": @YES } },
        @"profileSettings": @{ @"marker": @(tag) }, @"deviceIDs": @{ @"marker": @(tag) },
        @"profileArtifacts": @{
            @"bootTime": @{ @"value": [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)tag] },
            @"systemUptime": @{ @"value": @(tag) }
        }
    };
}
static BOOL PXConsistent(PXRuntimeReadSnapshot *view) {
    if (!view.valid) return NO;
    NSUInteger tag = [view.deviceIDs[@"marker"] unsignedIntegerValue];
    NSDate *boot = [view profileArtifact:@"bootTime"][@"value"];
    return [view.profileID isEqualToString:[NSString stringWithFormat:@"profile-%lu", (unsigned long)tag]] &&
        [view.profileSettings[@"marker"] unsignedIntegerValue] == tag &&
        [boot timeIntervalSince1970] == (NSTimeInterval)tag &&
        [[view profileArtifact:@"systemUptime"][@"value"] unsignedIntegerValue] == tag;
}

@interface PXFixtureSource : NSObject
@property (atomic, strong) NSDictionary *value;
@property (nonatomic) BOOL blockNext, shouldThrow;
@property (nonatomic) NSUInteger calls;
@property (nonatomic, strong) NSThread *loaderThread;
@property (nonatomic, strong) dispatch_semaphore_t entered, proceed;
- (NSDictionary *)load;
@end
@implementation PXFixtureSource
- (instancetype)init {
    if ((self = [super init])) { _entered = dispatch_semaphore_create(0); _proceed = dispatch_semaphore_create(0); }
    return self;
}
- (NSDictionary *)load {
    BOOL block, shouldThrow;
    NSDictionary *value;
    @synchronized(self) {
        self.calls++;
        value = self.value;
        block = self.blockNext; self.blockNext = NO;
        shouldThrow = self.shouldThrow;
        self.loaderThread = NSThread.currentThread;
    }
    if (block) {
        dispatch_semaphore_signal(self.entered);
        dispatch_semaphore_wait(self.proceed, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
    }
    if (shouldThrow) @throw [NSException exceptionWithName:@"LoaderFixture" reason:nil userInfo:nil];
    return value;
}
@end

static BOOL PXWait(dispatch_semaphore_t signal) {
    return dispatch_semaphore_wait(signal, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) == 0;
}

static void PXCheckValueValidation(void) {
    NSMutableDictionary *ids = [@{ @"marker": @1, @"text": [NSMutableString stringWithString:@"original"] } mutableCopy];
    NSMutableArray *array = [NSMutableArray arrayWithObject:[NSMutableString stringWithString:@"item"]];
    NSMutableData *data = [[@"bytes" dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    ids[@"array"] = array; ids[@"data"] = data;
    NSMutableDictionary *root = [PXFixturePayload(1) mutableCopy]; root[@"deviceIDs"] = ids;
    PXRuntimeReadSnapshot *view = [[PXRuntimeReadSnapshot alloc] initWithPropertyList:root readerGeneration:7];
    CHECK(view.valid && view.schemaVersion == 1 && view.readerGeneration == 7 && !view.hasPublicationIdentity,
          "legacy schema remains readable without fabricated epoch/revision");
    [ids[@"text"] appendString:@" changed"]; [array addObject:@"later"]; [data appendData:[NSData dataWithBytes:"!" length:1]];
    root[@"profileID"] = @"later";
    CHECK([view.profileID isEqualToString:@"profile-1"] && [view.deviceIDs[@"text"] isEqual:@"original"] &&
          [view.deviceIDs[@"array"] count] == 1 && [view.deviceIDs[@"data"] length] == 5, "deep immutable copy detaches every mutable descendant");
    BOOL refused = NO;
    @try { [(NSMutableDictionary *)view.deviceIDs setObject:@2 forKey:@"marker"]; }
    @catch (__unused NSException *exception) { refused = YES; }
    CHECK(refused && [view profileArtifact:@"missing"].count == 0, "read-only descendants and absent artifact behavior");
    NSArray *invalidSchemas = @[@0, @3, @YES, @1.5, @"1"];
    for (id schema in invalidSchemas) {
        NSMutableDictionary *invalid = [PXFixturePayload(1) mutableCopy]; invalid[@"schemaVersion"] = schema;
        PXRuntimeReadSnapshot *bad = [[PXRuntimeReadSnapshot alloc] initWithPropertyList:invalid readerGeneration:8];
        CHECK(!bad.valid && !bad.deviceIDs.count && !bad.securitySettings.count, "bad schema cannot publish enabled fields");
    }
    NSString *epoch = @"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
    NSMutableDictionary *identified = [PXFixturePayload(1) mutableCopy];
    identified[@"schemaVersion"] = @2; identified[@"publisherEpoch"] = epoch; identified[@"revision"] = @42;
    PXRuntimeReadSnapshot *modern = [[PXRuntimeReadSnapshot alloc] initWithPropertyList:identified readerGeneration:9];
    CHECK(modern.valid && modern.hasPublicationIdentity && modern.revision == 42 &&
          [modern.publisherEpoch isEqual:epoch.uppercaseString], "publication UUID normalized and revision separate from reader generation");
    for (id badRevision in @[@(-1), @YES, @1.25, @"42"]) {
        identified[@"revision"] = badRevision;
        PXRuntimeReadSnapshot *bad = [[PXRuntimeReadSnapshot alloc] initWithPropertyList:identified readerGeneration:10];
        CHECK(!bad.valid && !bad.globalScope.count, "malformed publication revision fails closed");
    }
    [identified removeObjectForKey:@"publisherEpoch"];
    [identified removeObjectForKey:@"revision"];
    CHECK(![[[PXRuntimeReadSnapshot alloc] initWithPropertyList:identified readerGeneration:11] isValid], "schema 2 requires publication identity");
}

static void PXCheckCoalescingAndCapture(void) {
    PXFixtureSource *source = [PXFixtureSource new]; source.value = PXFixturePayload(1); source.blockNext = YES;
    __block __weak PXRuntimeSnapshotReader *weakReader;
    __block BOOL recursiveWaitRejected = NO;
    PXRuntimeSnapshotReader *reader = [[PXRuntimeSnapshotReader alloc] initWithLoader:^NSDictionary *{
        (void)[weakReader capture];
        recursiveWaitRejected = ![weakReader waitForPendingRefresh:0];
        return [source load];
    } refreshInterval:3600];
    weakReader = reader;
    errno = EDOM;
    CHECK([reader capture] == nil && errno == EDOM, "cold capture returns immediately without inline I/O and preserves errno");
    CHECK(PXWait(source.entered), "initial loader entered asynchronously");
    CHECK([reader capture] == nil && ![reader waitForPendingRefresh:0], "capture does not wait on blocked loader");
    dispatch_semaphore_signal(source.proceed);
    CHECK([reader waitForPendingRefresh:3], "initial publication completes");
    PXRuntimeReadSnapshot *first = [reader capture];
    CHECK(PXConsistent(first) && source.loaderThread != NSThread.currentThread && recursiveWaitRejected,
          "loader is off caller thread and refuses recursive queue wait");
    NSUInteger calls = source.calls;
    for (NSUInteger index = 0; index < 2000; index++) (void)[reader capture];
    CHECK(source.calls == calls, "hot captures perform no loader calls within fallback interval");

    source.value = PXFixturePayload(2); source.blockNext = YES;
    [reader invalidateAndRefresh];
    CHECK(PXWait(source.entered) && [reader capture] == nil, "invalidation immediately removes enabled current publication");
    source.value = PXFixturePayload(3);
    for (NSUInteger index = 0; index < 100; index++) [reader invalidateAndRefresh];
    dispatch_semaphore_signal(source.proceed);
    CHECK([reader waitForPendingRefresh:3], "notification burst drains");
    PXRuntimeReadSnapshot *last = [reader capture];
    CHECK(PXConsistent(last) && [last.profileID isEqual:@"profile-3"] && source.calls == calls + 2,
          "stale in-flight load rejected; burst coalesced into only latest reload");
    CHECK(PXConsistent(first) && [first.profileID isEqual:@"profile-1"] && first.readerGeneration < last.readerGeneration,
          "captured old view remains internally consistent while a new generation publishes");

    source.value = nil; [reader requestRefresh]; CHECK([reader waitForPendingRefresh:3], "missing-file refresh finishes");
    PXRuntimeReadSnapshot *missing = [reader capture];
    CHECK(missing != nil && !missing.valid && missing.securitySettings.count == 0, "missing source does not retain last-good enablement");
    source.shouldThrow = YES; [reader requestRefresh]; CHECK([reader waitForPendingRefresh:3], "throwing loader completes pending group");
    CHECK(![[reader capture] isValid], "loader exception publishes invalid view");
}

static NSDictionary *PXIdentified(NSUInteger tag, NSString *epoch, uint64_t revision) {
    NSMutableDictionary *root = [PXFixturePayload(tag) mutableCopy];
    root[@"schemaVersion"] = @2; root[@"publisherEpoch"] = epoch; root[@"revision"] = @(revision);
    return root;
}
static void PXCheckIdentityAndFallback(void) {
    PXFixtureSource *source = [PXFixtureSource new];
    NSString *epochA = @"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", *epochB = @"00000000-1111-2222-3333-444444444444";
    source.value = PXIdentified(1, epochA, 8);
    PXRuntimeSnapshotReader *reader = [[PXRuntimeSnapshotReader alloc] initWithLoader:^NSDictionary *{ return [source load]; } refreshInterval:3600];
    [reader requestRefresh]; CHECK([reader waitForPendingRefresh:3], "identified publication loaded");
    CHECK([[reader capture] revision] == 8, "revision captured from publisher metadata");
    source.value = PXIdentified(2, epochA.lowercaseString, 7);
    [reader invalidateAndRefresh]; CHECK([reader waitForPendingRefresh:3], "older same-epoch load finishes");
    CHECK(![[reader capture] isValid], "older revision rejected only within same canonical epoch");
    source.value = PXIdentified(3, epochB, 1);
    [reader invalidateAndRefresh]; CHECK([reader waitForPendingRefresh:3], "new publisher incarnation loaded");
    CHECK([[reader capture] revision] == 1 && [[[reader capture] publisherEpoch] isEqual:epochB],
          "epoch switch accepts lower revision without ordering UUIDs");

    PXRuntimeSnapshotReader *fallback = [[PXRuntimeSnapshotReader alloc] initWithLoader:^NSDictionary *{ return [source load]; } refreshInterval:0.02];
    [fallback requestRefresh]; CHECK([fallback waitForPendingRefresh:3], "fallback baseline loaded");
    source.value = PXIdentified(4, epochB, 2);
    [NSThread sleepForTimeInterval:0.04]; // Test-only lost-notification interval.
    (void)[fallback capture];
    CHECK([fallback waitForPendingRefresh:3], "on-demand fallback reload completes");
    CHECK([[[fallback capture] profileID] isEqual:@"profile-4"], "slow fallback observes change without notification/timer");
}

static void PXCheckConcurrentReaders(void) {
    PXFixtureSource *source = [PXFixtureSource new]; source.value = PXFixturePayload(1);
    PXRuntimeSnapshotReader *reader = [[PXRuntimeSnapshotReader alloc] initWithLoader:^NSDictionary *{ return [source load]; } refreshInterval:3600];
    [reader requestRefresh]; CHECK([reader waitForPendingRefresh:3], "concurrency baseline ready");
    atomic_uint failures; atomic_init(&failures, 0);
    atomic_uint *failureCount = &failures;
    dispatch_group_t writer = dispatch_group_create();
    dispatch_group_async(writer, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        for (NSUInteger tag = 2; tag <= 30; tag++) {
            @autoreleasepool {
                source.value = PXFixturePayload(tag);
                [reader invalidateAndRefresh];
                if (![reader waitForPendingRefresh:3]) atomic_fetch_add(failureCount, 1);
            }
        }
    });
    dispatch_apply(2000, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^(size_t index) {
        (void)index;
        @autoreleasepool {
            PXRuntimeReadSnapshot *view = [reader capture];
            if (view && !PXConsistent(view)) atomic_fetch_add(failureCount, 1);
        }
    });
    BOOL finished = dispatch_group_wait(writer, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0;
    CHECK(finished, "concurrent publisher finished");
    if (!finished) exit(EXIT_FAILURE); // Do not leave a writer using stack atomics.
    CHECK(atomic_load(&failures) == 0 && [[[reader capture] profileID] isEqual:@"profile-30"],
          "concurrent captures never combine profile/artifact/device fields from different views");
}

int main(void) {
    @autoreleasepool {
        PXCheckValueValidation();
        PXCheckCoalescingAndCapture();
        PXCheckIdentityAndFallback();
        PXCheckConcurrentReaders();
        fprintf(stderr, "Runtime snapshot reader: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
