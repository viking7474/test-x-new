#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#include <sys/mount.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

static NSUInteger gChecks, gFailures;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PX_RUNTIME_READ_OPERATION ((void)0)
#include "PXStorageNativePublish.inc"

// Test-only atomic-load adapters force a completed publication between the two
// value loads. Production copies are extracted byte-for-byte, without callbacks.
static bool gInterleave;
static uint64_t PXLoad64(_Atomic(uint64_t) *value, memory_order order) {
    uint64_t result = atomic_load_explicit(value, order);
    if (value == &gStorageNativeTotalBytes && gInterleave) {
        gInterleave = false;
        CHECK(PXStorageBeginNativeRefresh(), "interleaving publisher owns refresh");
        PXStorageEndNativeRefresh(400, 40, YES);
    }
    return result;
}
static bool PXLoadBool(_Atomic(bool) *value, memory_order order) { return atomic_load_explicit(value, order); }
#pragma push_macro("atomic_load_explicit")
#undef atomic_load_explicit
#define atomic_load_explicit(value, order) _Generic((value), _Atomic(uint64_t) *: PXLoad64, _Atomic(bool) *: PXLoadBool)((value), (order))
#include "PXStorageNativeCopy.inc"
#undef atomic_load_explicit
#pragma pop_macro("atomic_load_explicit")

static NSString *gBundle = @"fixture.app", *gExecutable = @"/Applications/Fixture";
static NSDictionary *gValues;
static BOOL gScopeThrows;
static _Atomic(unsigned int) gComputations;
static void (^gDuringCompute)(void);
@interface PXStorageBundleFixture : NSObject
+ (instancetype)mainBundle;
- (NSString *)bundleIdentifier;
- (NSString *)executablePath;
- (id)objectForInfoDictionaryKey:(NSString *)key;
@end
@implementation PXStorageBundleFixture
+ (instancetype)mainBundle { return [self new]; }
- (NSString *)bundleIdentifier { return gBundle; }
- (NSString *)executablePath { return gExecutable; }
- (id)objectForInfoDictionaryKey:(NSString *)key { (void)key; return @"Fixture"; }
@end
static NSDictionary *getStorageValues(void) {
    atomic_fetch_add_explicit(&gComputations, 1, memory_order_relaxed);
    void (^callback)(void) = gDuringCompute; gDuringCompute = nil;
    if (callback) callback();
    return gValues;
}
enum { PXScopeOptionAllowSafariAuthStack = 1 };
static BOOL PXProcessIsAllowedForSpoofing(NSString *bundle, NSString *process, NSUInteger options) {
    (void)bundle; (void)process; (void)options;
    if (gScopeThrows) [NSException raise:@"fixture.scope" format:@"scope failure"];
    return YES;
}
#define NSBundle PXStorageBundleFixture
#include "PXStorageNativeWork.inc"
#undef NSBundle

static void Publish(uint64_t total, uint64_t free, BOOL allowed) {
    CHECK(PXStorageBeginNativeRefresh(), "publisher claims idle refresh");
    PXStorageEndNativeRefresh(total, free, allowed);
}
static void TestNativeCopy(void) {
    uint64_t total = 7, free = 9;
    Publish(200, 20, YES);
    gInterleave = true;
    CHECK(!PXStorageCopyNativeSnapshot(&total, &free) && total == 7 && free == 9, "completed publication between scalar loads is rejected without partial output");
    CHECK(PXStorageCopyNativeSnapshot(&total, &free) && total == 400 && free == 40, "stable complete publication is copied");
    CHECK(PXStorageBeginNativeRefresh() && !PXStorageBeginNativeRefresh(), "overlapping publisher cannot enter or clear another refresh");
    total = 7; free = 9;
    CHECK(!PXStorageCopyNativeSnapshot(&total, &free) && total == 7 && free == 9, "reader never waits or writes outputs while publisher is active");
    PXStorageEndNativeRefresh(100, 0, YES);
    CHECK(PXStorageCopyNativeSnapshot(&total, &free) && total == 100 && free == 0, "zero free-space is a valid complete snapshot");
    Publish(100, 101, YES);
    CHECK(!PXStorageCopyNativeSnapshot(&total, &free), "invalid free larger than total disables publication");
    Publish(100, 20, NO);
    CHECK(!PXStorageCopyNativeSnapshot(&total, &free) && !PXStorageCopyNativeSnapshot(NULL, &free), "denied process and invalid output pointers fail closed");
    atomic_store_explicit(&gStorageNativeRevision, UINT64_MAX - 1, memory_order_seq_cst);
    Publish(100, 10, YES);
    CHECK(PXStorageCopyNativeSnapshot(&total, &free) && total == 100 && free == 10, "version wrap retains stable odd-even publication state");

    dispatch_group_t writers = dispatch_group_create();
    dispatch_group_async(writers, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        for (uint64_t i = 1; i <= 100000; i++) {
            if (PXStorageBeginNativeRefresh()) PXStorageEndNativeRefresh(i * 10, i, YES);
        }
    });
    NSUInteger torn = 0;
    for (NSUInteger i = 0; i < 100000; i++) {
        if (PXStorageCopyNativeSnapshot(&total, &free) && total != free * 10) torn++;
    }
    CHECK(dispatch_group_wait(writers, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0, "concurrent publisher completes within fixture deadline");
    CHECK(!torn && PXStorageCopyNativeSnapshot(&total, &free) && total == free * 10, "concurrent accepted reads always contain one coherent tuple");
}
static void TestNumericAndBuffers(void) {
    uint64_t total = 0, free = 0;
    gValues = @{ @"TotalStorage": @64, @"FreeStorage": @16 };
    getStorageValuesForApp(&total, &free);
    CHECK(total == 64000000000ULL && free == 16000000000ULL, "numeric storage scalars keep marketing units instead of entering exception defaults");
    gValues = @{ @"TotalStorage": @"128", @"FreeStorage": @"32" };
    gExecutable = @"/Applications/DiskUsage";
    getStorageValuesForApp(&total, &free);
    CHECK(total == 128ULL * 1024 * 1024 * 1024 && free == total / 4, "technical app special capacities keep binary compensation");
    gExecutable = @"/Applications/Settings";
    getStorageValuesForApp(&total, &free);
    CHECK(total == 119000000000ULL && free == total / 4, "Settings special capacity and free ratio are unchanged");
    gExecutable = @"/Applications/Fixture";
    NSArray *invalid = @[@[], NSNull.null, @(NAN), @(INFINITY), @(1e100)];
    for (id value in invalid) {
        gValues = @{ @"TotalStorage": value, @"FreeStorage": @1 };
        getStorageValuesForApp(&total, &free);
        CHECK(total == 128000000000ULL && free == 38000000000ULL, "invalid enabled total uses safe spoof defaults without unsafe cast or physical-capacity fallback");
    }
    gValues = @{ @"TotalStorage": @256, @"FreeStorage": @(NAN) };
    getStorageValuesForApp(&total, &free);
    CHECK(total == 256000000000ULL && free == 0, "invalid free field preserves valid total and existing zero-free fallback");
    struct statfs buffer = {0}; buffer.f_bsize = 4096; buffer.f_bfree = 12345; buffer.f_bavail = 6789;
    PXStorageModifyStatfsWithValues(&buffer, 4096 * 100, 0);
    CHECK(buffer.f_blocks == 100 && buffer.f_bfree == 0 && buffer.f_bavail == 0, "zero fake free blocks replace physical free and available values");
    struct statfs before = buffer;
    PXStorageModifyStatfsWithValues(&buffer, 0, 0);
    CHECK(before.f_bsize == buffer.f_bsize && before.f_blocks == buffer.f_blocks &&
          before.f_bfree == buffer.f_bfree && before.f_bavail == buffer.f_bavail,
          "unavailable tuple does not modify physical statfs fields");
    CHECK(PXStorageBoundedMountCount(10, (int)sizeof(buffer), sizeof(buffer)) == 1 &&
          PXStorageBoundedMountCount(2, (int)(sizeof(buffer) - 1), sizeof(buffer)) == 0 &&
          PXStorageBoundedMountCount(INT_MAX, INT_MAX, sizeof(buffer)) <= INT_MAX / (int)sizeof(buffer),
          "mount provider iteration is bounded by complete addressable records");
    CHECK(!PXStorageBoundedMountCount(-1, INT_MAX, sizeof(buffer)) && !PXStorageBoundedMountCount(3, -1, sizeof(buffer)) &&
          !PXStorageBoundedMountCount(3, 100, 0), "invalid mount counts sizes and entry widths cannot iterate");
}
static void TestRefreshQueue(void) {
    gValues = @{ @"TotalStorage": @128, @"FreeStorage": @32 };
    gScopeThrows = YES;
    PXStorageRefreshNativeSnapshot(); gScopeThrows = NO;
    uint64_t total = 0, free = 0;
    CHECK(!atomic_load_explicit(&gStorageNativeRefreshInProgress, memory_order_seq_cst) &&
          !PXStorageCopyNativeSnapshot(&total, &free), "refresh exception releases ownership and publishes disabled state");
    dispatch_queue_t queue = dispatch_queue_create("fixture.storage-refresh", DISPATCH_QUEUE_SERIAL);
    dispatch_semaphore_t entered = dispatch_semaphore_create(0), gate = dispatch_semaphore_create(0);
    dispatch_async(queue, ^{
        dispatch_semaphore_signal(entered);
        dispatch_semaphore_wait(gate, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    });
    CHECK(dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0, "fixture blocks refresh queue before storm");
    unsigned int before = atomic_load_explicit(&gComputations, memory_order_relaxed);
    for (NSUInteger i = 0; i < 1000; i++) PXStorageScheduleNativeRefresh(queue);
    CHECK(atomic_load_explicit(&gStorageRefreshScheduled, memory_order_acquire), "notification storm owns one pending refresh slot");
    dispatch_semaphore_signal(gate); dispatch_sync(queue, ^{});
    CHECK(atomic_load_explicit(&gComputations, memory_order_relaxed) == before + 1, "queued notification storm performs one refresh");
    before = atomic_load_explicit(&gComputations, memory_order_relaxed);
    gDuringCompute = ^{ for (NSUInteger i = 0; i < 1000; i++) PXStorageScheduleNativeRefresh(queue); };
    PXStorageScheduleNativeRefresh(queue); dispatch_sync(queue, ^{}); dispatch_sync(queue, ^{});
    CHECK(atomic_load_explicit(&gComputations, memory_order_relaxed) == before + 2 &&
          !atomic_load_explicit(&gStorageRefreshScheduled, memory_order_acquire), "events during refresh schedule exactly one follow-up without losing the wakeup");
    PXStorageScheduleNativeRefresh(queue); dispatch_sync(queue, ^{});
    CHECK(atomic_load_explicit(&gComputations, memory_order_relaxed) == before + 3, "a later notification can schedule after coalesced work drains");
}
int main(void) {
    @autoreleasepool {
        @try { TestNativeCopy(); TestNumericAndBuffers(); TestRefreshQueue(); }
        @catch (NSException *exception) { gFailures++; fprintf(stderr, "FAIL: unexpected storage-native exception: %s\n", exception.description.UTF8String); }
        printf("Storage native snapshot: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
