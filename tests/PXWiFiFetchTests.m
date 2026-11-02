#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#include <stdio.h>
#include <stdlib.h>

static NSUInteger gChecks, gFailures, gOperations, gOriginalCalls, gScopeCalls, gReads;
static NSUInteger gLookups, gAllocations, gInitializations, gDeaths, gKVC, gPreInitProbes;
static BOOL gAllowed, gThrowScope, gThrowRead, gThrowLookup, gThrowAlloc, gNilAlloc, gNilInit, gWrongInit, gThrowKVC, gThrowOriginal;
static id gInfo, gOriginalNetwork, gSeenSelf;
static SEL gSeenSelector;
static Class gNetworkClass;
static NSMutableArray *gKeys;
static void (^gPending)(id);
static BOOL gDeferred, gSawNilHandler;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PX_RUNTIME_READ_OPERATION do { gOperations++; } while (0)
static BOOL shouldSpoofForBundle(NSString * __unsafe_unretained bundle) {
    (void)bundle; gScopeCalls++;
    if (gThrowScope) [NSException raise:@"fixture.scope" format:@"scope failed"];
    return gAllowed;
}
static NSDictionary *PXResolvedWiFiInfo(void) {
    gReads++;
    if (gThrowRead) [NSException raise:@"fixture.read" format:@"read failed"];
    return gInfo;
}
static BOOL PXWiFiInfoHasIdentity(id info) {
    return [info isKindOfClass:NSDictionary.class] &&
        [info[@"ssid"] isKindOfClass:NSString.class] && [info[@"bssid"] isKindOfClass:NSString.class];
}
@interface PXFetchNetwork : NSObject {
    BOOL _initialized;
}
@property (nonatomic, strong) NSMutableDictionary *values;
@end
@implementation PXFetchNetwork
+ (instancetype)alloc {
    gAllocations++;
    if (gThrowAlloc) [NSException raise:@"fixture.alloc" format:@"allocation failed"];
    if (gNilAlloc) return nil;
    return [super alloc];
}
- (instancetype)init {
    gInitializations++;
    self = [super init];
    if (!self || gNilInit) return nil;
    if (gWrongInit) return (id)[NSObject new];
    _initialized = YES;
    _values = [NSMutableDictionary new];
    return self;
}
- (BOOL)respondsToSelector:(SEL)selector {
    if (!_initialized) gPreInitProbes++;
    return [super respondsToSelector:selector];
}
// Borrowed parameters keep injected throws from adding mock-owned ARC references.
- (void)setValue:(id __unsafe_unretained)value forKey:(NSString * __unsafe_unretained)key {
    gKVC++; [gKeys addObject:key];
    if (gThrowKVC) [NSException raise:@"fixture.kvc" format:@"unsupported key"];
    self.values[key] = value;
}
- (void)dealloc { gDeaths++; }
@end
static Class PXFixtureNetworkClass(NSString * __unsafe_unretained name) {
    CHECK([name isEqual:@"NEHotspotNetwork"], "factory looks up only the expected class");
    gLookups++;
    if (gThrowLookup) [NSException raise:@"fixture.lookup" format:@"lookup failed"];
    return gNetworkClass;
}
static void OriginalFetch(id self, SEL command, void (^ __unsafe_unretained completion)(id)) {
    gOriginalCalls++; gSeenSelf = self; gSeenSelector = command; gSawNilHandler = completion == nil;
    if (gThrowOriginal) [NSException raise:@"fixture.original" format:@"original failed"];
    if (gDeferred) gPending = completion;
    else if (completion) completion(gOriginalNetwork);
}
#define NSClassFromString PXFixtureNetworkClass
#include "PXWiFiFetchHooks.inc"
#undef NSClassFromString

static void Reset(void) {
    gPending = nil; gOriginalNetwork = nil; gSeenSelf = nil;
    gOperations = gOriginalCalls = gScopeCalls = gReads = gLookups = 0;
    gAllocations = gInitializations = gDeaths = gKVC = gPreInitProbes = 0;
    gAllowed = YES;
    gThrowScope = gThrowRead = gThrowLookup = gThrowAlloc = gNilAlloc = gNilInit = gWrongInit = gThrowKVC = gThrowOriginal = NO;
    gDeferred = gSawNilHandler = NO;
    gInfo = @{ @"ssid": @"Fake", @"bssid": @"02:11:22:33:44:55" };
    gNetworkClass = PXFetchNetwork.class; gKeys = [NSMutableArray new];
    orig_NEHotspotNetwork_fetchCurrent = OriginalFetch;
}
static void Emit(id network) {
    void (^callback)(id) = gPending; gPending = nil;
    @try { if (callback) callback(network); }
    @finally { callback = nil; }
}
static void Fetch(void (^ __unsafe_unretained completion)(id)) {
    replaced_NEHotspotNetwork_fetchCurrent(PXFetchNetwork.class, @selector(fetchCurrentWithCompletionHandler:), completion);
}
static void TestFactory(void) {
    Reset();
    @autoreleasepool {
        PXFetchNetwork *network = PXCreateSpoofedNEHotspotNetwork(@"Fake", @"02:11");
        CHECK([network isKindOfClass:PXFetchNetwork.class], "factory returns initialized network instance");
        CHECK(gAllocations == 1 && gInitializations == 1 && gPreInitProbes == 0, "factory allocates initializes once and never probes uninitialized instance");
        CHECK(gKVC == 8 && [gKeys isEqual:(@[@"SSID", @"_SSID", @"ssid", @"_ssid", @"BSSID", @"_BSSID", @"bssid", @"_bssid"])], "factory preserves all eight aliases in their existing order");
        CHECK([network.values[@"_ssid"] isEqual:@"Fake"] && [network.values[@"_bssid"] isEqual:@"02:11"], "factory retains SSID BSSID values without changing case or format");
    }
    CHECK(gDeaths == 1, "synthetic network releases after consumer scope");
    for (id bad in @[[NSNull null], @42, @[], @{}]) {
        Reset();
        CHECK(!PXCreateSpoofedNEHotspotNetwork(bad, @"b") && !PXCreateSpoofedNEHotspotNetwork(@"s", bad), "factory rejects nonstring identity without selectors or allocation");
        CHECK(gLookups == 0 && gAllocations == 0, "invalid types reject before class lookup");
    }
    Reset();
    CHECK(!PXCreateSpoofedNEHotspotNetwork(nil, @"b") && !PXCreateSpoofedNEHotspotNetwork(@"", @"b") && !PXCreateSpoofedNEHotspotNetwork(@"s", @""), "factory preserves empty identity rejection");
    CHECK(gLookups == 0, "empty identity rejects before lookup");
    Reset(); gNetworkClass = Nil;
    CHECK(!PXCreateSpoofedNEHotspotNetwork(@"s", @"b") && !gAllocations, "missing optional class returns nil");
    Reset(); gNilAlloc = YES;
    CHECK(!PXCreateSpoofedNEHotspotNetwork(@"s", @"b") && gAllocations == 1 && !gInitializations && !gKVC, "nil allocation returns nil without initialization or KVC");
    Reset(); gNilInit = YES;
    CHECK(!PXCreateSpoofedNEHotspotNetwork(@"s", @"b") && gAllocations == 1 && gInitializations == 1 && !gKVC, "nil initializer never retries or runs KVC");
    CHECK(gDeaths == 1, "nil initializer releases allocated instance");
    Reset(); gWrongInit = YES;
    CHECK(!PXCreateSpoofedNEHotspotNetwork(@"s", @"b") && gInitializations == 1 && !gKVC, "unexpected initializer result is never returned as a network");
    Reset(); gThrowLookup = YES;
    CHECK(!PXCreateSpoofedNEHotspotNetwork(@"s", @"b") && !gAllocations, "class lookup exception returns nil before allocation");
    Reset(); gThrowAlloc = YES;
    CHECK(!PXCreateSpoofedNEHotspotNetwork(@"s", @"b") && gAllocations == 1 && !gInitializations, "allocation exception returns nil without retry");
    Reset(); gThrowKVC = YES;
    @autoreleasepool {
        CHECK([PXCreateSpoofedNEHotspotNetwork(@"s", @"b") isKindOfClass:PXFetchNetwork.class] && gKVC == 8, "unsupported KVC aliases remain best effort and do not abort later attempts");
    }
    CHECK(gDeaths == 1, "KVC exceptions do not retain the synthetic instance");
}
static void TestForwarding(void) {
    Reset(); Fetch(nil);
    CHECK(gOriginalCalls == 1 && gSawNilHandler && !gOperations && !gScopeCalls && !gReads, "nil handler forwards nil once without capture scope or provider work");
    Reset(); orig_NEHotspotNetwork_fetchCurrent = NULL; Fetch(nil);
    CHECK(!gOriginalCalls && !gOperations && !gLookups, "missing original plus nil handler does no work");
    Reset(); gOriginalNetwork = [NSObject new]; gThrowScope = YES;
    __block NSUInteger calls = 0;
    Fetch(^(id network) { calls++; CHECK(network == gOriginalNetwork, "real system network preserves object identity"); });
    CHECK(calls == 1 && gOriginalCalls == 1 && !gScopeCalls && !gReads && !gLookups, "real network skips scope provider and construction");
    CHECK(gSeenSelf == PXFetchNetwork.class && gSeenSelector == @selector(fetchCurrentWithCompletionHandler:), "original receives unchanged receiver and selector");
    CHECK(gOperations == 2, "factory and callback retain independent lexical operation boundaries");
    Reset(); gAllowed = NO; calls = 0;
    Fetch(^(id network) { calls++; CHECK(network == nil, "denied nil result passes through"); });
    CHECK(calls == 1 && gScopeCalls == 1 && !gReads && !gLookups, "denied callback avoids provider and allocation");
    Reset(); calls = 0;
    @autoreleasepool {
        Fetch(^(id network) { calls++; CHECK([network isKindOfClass:PXFetchNetwork.class], "scoped nil system result produces synthetic network"); });
    }
    CHECK(calls == 1 && gOriginalCalls == 1 && gReads == 1 && gAllocations == 1 && gDeaths == 1, "successful callback delivers once and retains no synthetic network");
    Reset(); orig_NEHotspotNetwork_fetchCurrent = NULL; calls = 0;
    Fetch(^(id network) { calls++; CHECK(network != nil, "missing original retains synchronous synthetic fallback"); });
    CHECK(calls == 1 && !gOriginalCalls, "missing original fallback does not add another callback");
    for (NSUInteger fault = 0; fault < 5; fault++) {
        Reset(); calls = 0;
        if (fault == 0) gThrowScope = YES;
        if (fault == 1) gThrowRead = YES;
        if (fault == 2) gThrowLookup = YES;
        if (fault == 3) gThrowAlloc = YES;
        if (fault == 4) gNilInit = YES;
        Fetch(^(id network) { calls++; CHECK(network == nil, "preparation failure preserves nil callback value"); });
        CHECK(calls == 1 && gOriginalCalls == 1, "preparation failure does not swallow or duplicate delivery");
    }
    for (id info in @[[NSNull null], @[], @{}, @{ @"ssid": @42, @"bssid": @"b" }, @{ @"ssid": @"s", @"bssid": @[] }]) {
        Reset(); calls = 0; gInfo = info;
        Fetch(^(id network) { calls++; CHECK(network == nil, "malformed provider result fails to nil without callback loss"); });
        CHECK(calls == 1 && !gLookups && !gAllocations, "malformed provider rejects before optional class work");
    }
    Reset(); gThrowOriginal = YES;
    BOOL raised = NO;
    @try { Fetch(^(id network) { (void)network; }); } @catch (NSException *e) { raised = [e.name isEqual:@"fixture.original"]; }
    CHECK(raised && gOriginalCalls == 1 && !gScopeCalls, "original exception propagates without fabricated completion");
    Reset(); calls = 0; raised = NO;
    @autoreleasepool {
        @try { Fetch(^(id __unsafe_unretained network) { (void)network; calls++; [NSException raise:@"fixture.client" format:@"client failed"]; }); }
        @catch (NSException *e) { raised = [e.name isEqual:@"fixture.client"]; }
    }
    CHECK(raised && calls == 1, "client exception propagates outside preparation catch without retry");
    CHECK(gDeaths == 1, "explicit callback cleanup releases synthetic instance on client exception");
}
static void TestExceptionalClosureLifetime(void) {
    for (NSUInteger fault = 0; fault < 2; fault++) {
        Reset(); gThrowOriginal = fault == 0;
        __weak NSObject *weakConsumer = nil;
        __block NSUInteger calls = 0;
        BOOL raised = NO;
        @autoreleasepool {
            NSObject *consumer = [NSObject new]; weakConsumer = consumer;
            void (^handler)(id) = ^(id __unsafe_unretained network) {
                (void)network; (void)consumer.description; calls++;
                [NSException raise:@"fixture.client" format:@"client failed"];
            };
            @try { Fetch(handler); }
            @catch (NSException *e) { raised = [e.name isEqual:(fault == 0 ? @"fixture.original" : @"fixture.client")]; }
            @finally { handler = nil; consumer = nil; }
        }
        CHECK(raised && calls == (fault == 0 ? 0 : 1), "exceptional original or client preserves exception and callback count");
        CHECK(weakConsumer == nil, "exceptional original or client does not strand wrapper captured consumer");
    }
}
static void TestDeferred(void) {
    Reset(); gDeferred = YES;
    __block NSUInteger calls = 0;
    Fetch(^(id network) { calls++; CHECK(network == nil, "deferred callback observes current scope revocation"); });
    CHECK(gOriginalCalls == 1 && calls == 0 && gPending && !gScopeCalls && !gReads, "deferred original retains callback without early provider work");
    gAllowed = NO; Emit(nil);
    CHECK(calls == 1 && gScopeCalls == 1 && !gReads && !gPending, "deferred callback uses delivery time policy and completes once");
    Reset(); gDeferred = YES; calls = 0;
    Fetch(^(id network) { calls++; CHECK(network != nil && !NSThread.isMainThread, "wrapper forwards on original callback thread without dispatch"); });
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [NSThread detachNewThreadWithBlock:^{ @autoreleasepool { Emit(nil); } dispatch_semaphore_signal(done); }];
    long waitResult = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    CHECK(waitResult == 0, "background original callback finishes within fixture deadline");
    if (waitResult) exit(1); // Stop before reading/resetting counters while the worker may still run.
    CHECK(calls == 1 && !gPending, "background forwarding delivers exactly once");
    Reset(); gDeferred = YES;
    __weak NSObject *weakConsumer = nil;
    @autoreleasepool {
        NSObject *consumer = [NSObject new]; weakConsumer = consumer;
        Fetch(^(id network) { (void)network; (void)consumer.description; });
    }
    @autoreleasepool {
        CHECK(weakConsumer != nil && gPending != nil, "wrapper retains consumer only while original holds callback");
    } // Drain any temporary strong reference from the weak load before Emit.
    @autoreleasepool { Emit(nil); }
    CHECK(weakConsumer == nil && !gPending, "consumer is released after original releases delivered callback");
}
int main(void) {
    @autoreleasepool {
        @try { TestFactory(); TestForwarding(); TestExceptionalClosureLifetime(); TestDeferred(); }
        @catch (NSException *e) { gFailures++; fprintf(stderr, "FAIL: unexpected fetch exception: %s\n", e.description.UTF8String); }
        printf("WiFi fetch lifecycle: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
