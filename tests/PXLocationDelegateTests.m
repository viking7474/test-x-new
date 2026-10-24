#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#include <stdatomic.h>
#import "PXLocationDelegateHooks.h"

static NSUInteger gChecks, gFailures;
static atomic_uint gGeneration, gProviderCalls;
static atomic_bool gEnabled, gThrowProjection;
static char kSnapshot;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)

static id PXFixtureSnapshot(BOOL advance) {
    atomic_fetch_add(&gProviderCalls, 1);
    if (atomic_load(&gThrowProjection)) @throw [NSException exceptionWithName:@"ProjectionFixture" reason:nil userInfo:nil];
    if (!atomic_load(&gEnabled)) return nil;
    unsigned int generation = advance ? atomic_fetch_add(&gGeneration, 1) + 1 : atomic_load(&gGeneration);
    return @{ @"generation": @(generation) };
}
static void PXFixtureAttach(id object, id snapshot) {
    if (object && snapshot) objc_setAssociatedObject(object, &kSnapshot, snapshot, OBJC_ASSOCIATION_RETAIN);
}
static id PXAttached(id object) { return objc_getAssociatedObject(object, &kSnapshot); }
static NSUInteger PXObserve(id delegate) {
    return PXInstallLocationDelegateHooks(delegate, PXFixtureSnapshot, PXFixtureAttach);
}

@protocol PXFixtureLocationCallbacks <NSObject>
@optional
- (void)locationManager:(id)manager didUpdateLocations:(NSArray *)locations;
- (void)locationManager:(id)manager didUpdateToLocation:(id)location fromLocation:(id)oldLocation;
- (void)locationManager:(id)manager didUpdateHeading:(id)heading;
- (void)locationManager:(id)manager didEnterRegion:(id)region;
- (void)locationManager:(id)manager didExitRegion:(id)region;
@end

@interface PXFixtureLocationManager : NSObject
@property (nonatomic, weak) id<PXFixtureLocationCallbacks> delegate;
@property (nonatomic, strong) NSArray *synchronousBatch;
@end
@implementation PXFixtureLocationManager
- (void)setDelegate:(id<PXFixtureLocationCallbacks>)delegate {
    // Same ordering as the production setter: observe, native assignment, then
    // optional synchronous callback. This double cannot prove iOS setter ABI.
    PXObserve(delegate);
    _delegate = delegate;
    if (self.synchronousBatch) [delegate locationManager:self didUpdateLocations:self.synchronousBatch];
}
@end

@interface PXLocationBatchDelegate : NSObject <PXFixtureLocationCallbacks>
@property (nonatomic) NSUInteger calls;
@property (nonatomic, weak) id lastManager;
@property (nonatomic, strong) id first, second, snapshotAtEntry;
@property (nonatomic, strong) NSThread *threadAtEntry;
- (void)recordManager:(id)manager first:(id)first second:(id)second;
@end
@implementation PXLocationBatchDelegate
- (void)recordManager:(id)manager first:(id)first second:(id)second {
    self.calls++;
    self.lastManager = manager;
    self.first = first;
    self.second = second;
    self.threadAtEntry = NSThread.currentThread;
    self.snapshotAtEntry = [first isKindOfClass:NSArray.class] ? PXAttached([first firstObject]) : PXAttached(first);
}
- (void)locationManager:(id)manager didUpdateLocations:(NSArray *)locations {
    [self recordManager:manager first:locations second:nil];
}
@end
@interface PXLocationAllDelegate : PXLocationBatchDelegate
@end
@implementation PXLocationAllDelegate
- (void)locationManager:(id)m didUpdateToLocation:(id)n fromLocation:(id)o { [self recordManager:m first:n second:o]; }
- (void)locationManager:(id)m didUpdateHeading:(id)h { [self recordManager:m first:h second:nil]; }
- (void)locationManager:(id)m didEnterRegion:(id)r { [self recordManager:m first:r second:nil]; }
- (void)locationManager:(id)m didExitRegion:(id)r { [self recordManager:m first:r second:nil]; }
@end
@interface PXLocationInheritedDelegate : PXLocationAllDelegate @end
@implementation PXLocationInheritedDelegate @end
@interface PXLocationLateInheritedDelegate : PXLocationAllDelegate @end
@implementation PXLocationLateInheritedDelegate @end
@interface PXLocationConcurrentDelegate : PXLocationBatchDelegate @end
@implementation PXLocationConcurrentDelegate @end
@interface PXLocationOverrideDelegate : PXLocationAllDelegate
@property (nonatomic) NSUInteger overrideCalls;
@end
@implementation PXLocationOverrideDelegate
- (void)locationManager:(id)m didUpdateLocations:(NSArray *)a {
    self.overrideCalls++; [super locationManager:m didUpdateLocations:a];
}
- (void)locationManager:(id)m didUpdateToLocation:(id)n fromLocation:(id)o {
    self.overrideCalls++; [super locationManager:m didUpdateToLocation:n fromLocation:o];
}
@end
@interface PXLocationReentrantDelegate : PXLocationAllDelegate
@property (nonatomic) BOOL entered;
@property (nonatomic, strong) NSArray *nestedBatch;
@end
@implementation PXLocationReentrantDelegate
- (void)locationManager:(id)m didUpdateLocations:(NSArray *)a {
    if (!self.entered) {
        self.entered = YES;
        [self locationManager:m didUpdateLocations:self.nestedBatch];
    }
    [super locationManager:m didUpdateLocations:a];
}
@end
@interface PXLocationThrowingDelegate : PXLocationAllDelegate
@property (nonatomic, strong) NSException *exception;
@end
@implementation PXLocationThrowingDelegate
- (void)locationManager:(id)m didUpdateLocations:(NSArray *)a {
    if (self.exception) @throw self.exception;
    [super locationManager:m didUpdateLocations:a];
}
@end
@interface PXLocationBlockingDelegate : PXLocationAllDelegate
@property (nonatomic, strong) dispatch_semaphore_t entered, proceed;
@end
@implementation PXLocationBlockingDelegate
- (void)locationManager:(id)m didUpdateLocations:(NSArray *)a {
    dispatch_semaphore_signal(self.entered);
    dispatch_semaphore_wait(self.proceed, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
    [super locationManager:m didUpdateLocations:a];
}
@end

@interface PXLocationWrongReturn : NSObject
- (double)locationManager:(id)m didUpdateLocations:(id)a;
@end
@implementation PXLocationWrongReturn
- (double)locationManager:(id)m didUpdateLocations:(id)a { (void)m; (void)a; return 1.25; }
@end
@interface PXLocationWrongArgument : NSObject
- (void)locationManager:(id)m didUpdateLocations:(double)a;
@property (nonatomic) double value;
@end
@implementation PXLocationWrongArgument
- (void)locationManager:(id)m didUpdateLocations:(double)a { (void)m; self.value = a; }
@end
@interface PXLocationWrongBlock : NSObject
- (void)locationManager:(id)m didUpdateLocations:(void (^)(void))block;
@end
@implementation PXLocationWrongBlock
- (void)locationManager:(id)m didUpdateLocations:(void (^)(void))block { (void)m; if (block) block(); }
@end
@interface PXLocationForwardingDelegate : NSObject
@property (nonatomic, strong) id target;
@end
@implementation PXLocationForwardingDelegate
- (BOOL)respondsToSelector:(SEL)sel { return [super respondsToSelector:sel] || [self.target respondsToSelector:sel]; }
- (id)forwardingTargetForSelector:(SEL)sel { return [self.target respondsToSelector:sel] ? self.target : [super forwardingTargetForSelector:sel]; }
@end

static void PXCheckCapabilitiesAndABI(void) {
    PXLocationBatchDelegate *batch = [PXLocationBatchDelegate new];
    CHECK(PXObserve(nil) == 0 && PXObserve([NSObject new]) == 0, "nil and root delegate are not hooked");
    CHECK(PXObserve(batch) == 1 && PXObserve(batch) == 1, "only implemented batch selector is installed once");
    CHECK(![batch respondsToSelector:@selector(locationManager:didUpdateHeading:)] &&
          ![batch respondsToSelector:@selector(locationManager:didEnterRegion:)] &&
          ![batch respondsToSelector:@selector(locationManager:didExitRegion:)] &&
          ![batch respondsToSelector:@selector(locationManager:didUpdateToLocation:fromLocation:)], "optional selector absence preserved");
    PXLocationWrongReturn *wrong = [PXLocationWrongReturn new];
    IMP original = class_getMethodImplementation(wrong.class, @selector(locationManager:didUpdateLocations:));
    CHECK(PXObserve(wrong) == 0 && [wrong locationManager:nil didUpdateLocations:nil] == 1.25 &&
          class_getMethodImplementation(wrong.class, @selector(locationManager:didUpdateLocations:)) == original, "reject return ABI without mutation");
    PXLocationWrongArgument *scalar = [PXLocationWrongArgument new];
    CHECK(PXObserve(scalar) == 0, "reject scalar callback argument ABI");
    [scalar locationManager:nil didUpdateLocations:2.5];
    CHECK(scalar.value == 2.5, "rejected scalar implementation still forwards normally");
    PXLocationWrongBlock *block = [PXLocationWrongBlock new];
    __block BOOL invoked = NO;
    CHECK(PXObserve(block) == 0, "reject block ABI where ordinary object is required");
    [block locationManager:nil didUpdateLocations:^{ invoked = YES; }];
    CHECK(invoked, "rejected block method unchanged");
    PXLocationForwardingDelegate *forward = [PXLocationForwardingDelegate new];
    forward.target = [PXLocationBatchDelegate new];
    CHECK([forward respondsToSelector:@selector(locationManager:didUpdateLocations:)] && PXObserve(forward) == 0,
          "forwarding-only capability does not fabricate implementation");
    NSArray *array = @[[NSObject new]];
    [(id<PXFixtureLocationCallbacks>)forward locationManager:nil didUpdateLocations:array];
    CHECK([(PXLocationBatchDelegate *)forward.target calls] == 1, "forwarding-only delegate retains native routing");
}

static void PXCheckBatchesAndLivePolicy(void) {
    PXFixtureLocationManager *m = [PXFixtureLocationManager new];
    PXLocationBatchDelegate *d = [PXLocationBatchDelegate new];
    NSObject *first = [NSObject new], *second = [NSObject new];
    NSArray *batch = @[first, second];
    m.synchronousBatch = batch;
    unsigned int before = atomic_load(&gGeneration);
    m.delegate = d;
    CHECK(m.delegate == d && d.calls == 1, "identity preserved and synchronous setter callback intercepted");
    CHECK(d.first == batch && d.lastManager == m && d.threadAtEntry == NSThread.currentThread, "batch arguments/thread preserved");
    CHECK(PXAttached(first) == PXAttached(second) && d.snapshotAtEntry == PXAttached(first), "all original objects share one snapshot before delegate entry");
    CHECK(atomic_load(&gGeneration) == before + 1, "one generation for complete batch");
    m.synchronousBatch = nil;
    [d locationManager:m didUpdateLocations:@[]];
    [d locationManager:m didUpdateLocations:nil];
    CHECK(d.calls == 3 && atomic_load(&gGeneration) == before + 1, "empty/nil batches forward without generation advance");
    atomic_store(&gEnabled, NO);
    NSObject *off = [NSObject new];
    [d locationManager:m didUpdateLocations:@[off]];
    CHECK(!PXAttached(off) && d.calls == 4 && atomic_load(&gGeneration) == before + 1, "disabled policy forwards unchanged");
    atomic_store(&gEnabled, YES);
    [d locationManager:m didUpdateLocations:@[off]];
    CHECK(PXAttached(off) != nil && atomic_load(&gGeneration) == before + 2, "live re-enable without reinstall");
    m.delegate = nil;
    unsigned int calls = atomic_load(&gProviderCalls);
    [d locationManager:m didUpdateLocations:@[[NSObject new]]];
    CHECK(d.calls == 6 && atomic_load(&gProviderCalls) == calls, "old callback after nil delegate forwards without projection");
    [d locationManager:nil didUpdateLocations:@[[NSObject new]]];
    CHECK(d.calls == 7 && d.lastManager == nil && atomic_load(&gProviderCalls) == calls,
          "nil manager argument forwards unchanged without projection");
}

static void PXCheckInheritanceAndSurfaces(void) {
    SEL modern = @selector(locationManager:didUpdateLocations:);
    IMP baseBefore = class_getMethodImplementation(PXLocationAllDelegate.class, modern);
    PXLocationInheritedDelegate *inherited = [PXLocationInheritedDelegate new];
    CHECK(PXObserve(inherited) == 5, "all inherited real callbacks observed");
    CHECK(class_getMethodImplementation(PXLocationAllDelegate.class, modern) == baseBefore,
          "class-local inherited installation leaves ancestor IMP untouched");
    PXLocationAllDelegate *base = [PXLocationAllDelegate new];
    CHECK(PXObserve(base) == 5, "base installed after inherited delegate");
    NSArray *delegates = @[inherited, [PXLocationLateInheritedDelegate new], [PXLocationOverrideDelegate new]];
    for (PXLocationAllDelegate *d in delegates) {
        PXFixtureLocationManager *m = [PXFixtureLocationManager new];
        m.delegate = d;
        unsigned int generation = atomic_load(&gGeneration);
        NSObject *n = [NSObject new], *o = [NSObject new], *heading = [NSObject new], *region = [NSObject new];
        NSArray *batch = @[n, o];
        [d locationManager:m didUpdateLocations:batch];
        CHECK(d.calls == 1 && atomic_load(&gGeneration) == generation + 1 && d.first == batch, "inherited/override-super batch forwards once and advances once");
        [d locationManager:m didUpdateToLocation:n fromLocation:o];
        CHECK(d.calls == 2 && d.first == n && d.second == o && PXAttached(n) == PXAttached(o) &&
              atomic_load(&gGeneration) == generation + 2, "legacy pair identity and one shared generation");
        [d locationManager:m didUpdateHeading:heading];
        CHECK(d.calls == 3 && d.first == heading && PXAttached(heading) == d.snapshotAtEntry &&
              atomic_load(&gGeneration) == generation + 2, "heading uses current generation and same object");
        [d locationManager:m didEnterRegion:region];
        [d locationManager:m didExitRegion:region];
        CHECK(d.calls == 5 && d.first == region && !PXAttached(region) && atomic_load(&gGeneration) == generation + 2,
              "region callbacks remain unsuppressed without generation advance");
        [d locationManager:m didUpdateToLocation:nil fromLocation:nil];
        CHECK(d.calls == 6 && atomic_load(&gGeneration) == generation + 2, "nil legacy locations still forward");
    }
    PXFixtureLocationManager *a = [PXFixtureLocationManager new], *b = [PXFixtureLocationManager new];
    a.delegate = base; b.delegate = base;
    unsigned int generation = atomic_load(&gGeneration);
    [base locationManager:a didUpdateLocations:@[[NSObject new]]];
    [base locationManager:b didUpdateLocations:@[[NSObject new]]];
    CHECK(base.calls == 2 && atomic_load(&gGeneration) == generation + 2, "one delegate can serve multiple managers");
    a.delegate = inherited;
    unsigned int calls = atomic_load(&gProviderCalls);
    [base locationManager:a didUpdateLocations:@[[NSObject new]]];
    CHECK(base.calls == 3 && atomic_load(&gProviderCalls) == calls, "replaced delegate's queued callback forwards without advancing");
}

static void PXCheckCoreLocationValueObjects(void) {
    // Real CoreLocation values without starting services, authorization or GPS.
    // The native manager setter/real delivery remain device integration gates.
    NSDate *timestamp = [NSDate dateWithTimeIntervalSince1970:1234];
    CLLocation *location = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(51.5, -0.12)
        altitude:12 horizontalAccuracy:3 verticalAccuracy:4 timestamp:timestamp];
    CLLocation *old = [[CLLocation alloc] initWithLatitude:51.4 longitude:-0.13];
    NSArray *batch = @[location, old];
    PXFixtureLocationManager *m = [PXFixtureLocationManager new];
    PXLocationAllDelegate *d = [PXLocationAllDelegate new];
    m.delegate = d;
    [d locationManager:m didUpdateLocations:batch];
    CHECK(d.first == batch && batch[0] == location && batch[1] == old && PXAttached(location) == PXAttached(old),
          "real CLLocation values retain batch/order/identity and shared attached snapshot");
    CHECK(location.altitude == 12 && location.horizontalAccuracy == 3 && location.verticalAccuracy == 4 &&
          [location.timestamp isEqual:timestamp], "snapshot attachment preserves real location metadata");
    [d locationManager:m didUpdateToLocation:location fromLocation:old];
    CHECK(d.first == location && d.second == old && PXAttached(location) == PXAttached(old),
          "real legacy CLLocation pair forwarded unchanged");
}

static void PXCheckReentrancyAndExceptions(void) {
    PXFixtureLocationManager *m = [PXFixtureLocationManager new];
    PXLocationReentrantDelegate *d = [PXLocationReentrantDelegate new];
    d.nestedBatch = @[[NSObject new]];
    m.delegate = d;
    unsigned int before = atomic_load(&gGeneration);
    NSArray *outer = @[[NSObject new]];
    [d locationManager:m didUpdateLocations:outer];
    CHECK(d.calls == 2 && atomic_load(&gGeneration) == before + 2, "new nested self callback projects; only super chain is deduplicated");
    CHECK([PXAttached(outer.firstObject)[@"generation"] unsignedIntValue] == before + 1 &&
          [PXAttached(d.nestedBatch.firstObject)[@"generation"] unsignedIntValue] == before + 2, "nested batches keep distinct immutable snapshots");
    atomic_store(&gThrowProjection, YES);
    [d locationManager:m didUpdateLocations:outer];
    atomic_store(&gThrowProjection, NO);
    CHECK(d.calls == 3, "projection exception does not suppress original callback");
    PXLocationThrowingDelegate *throwing = [PXLocationThrowingDelegate new];
    m.delegate = throwing;
    NSException *expected = [NSException exceptionWithName:@"DelegateFixture" reason:nil userInfo:nil];
    throwing.exception = expected;
    BOOL propagated = NO;
    @try { [throwing locationManager:m didUpdateLocations:outer]; }
    @catch (NSException *exception) { propagated = exception == expected; }
    CHECK(propagated, "delegate exception propagates unchanged");
    throwing.exception = nil;
    before = atomic_load(&gGeneration);
    [throwing locationManager:m didUpdateLocations:outer];
    CHECK(throwing.calls == 1 && atomic_load(&gGeneration) == before + 1, "exception unwind restores callback frame");
}

static void PXCheckConcurrencyAndLifetime(void) {
    unsigned int before = atomic_load(&gGeneration);
    __block atomic_uint failures;
    atomic_init(&failures, 0);
    dispatch_apply(32, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^(size_t index) {
        (void)index;
        @autoreleasepool {
            PXFixtureLocationManager *m = [PXFixtureLocationManager new];
            PXLocationConcurrentDelegate *d = [PXLocationConcurrentDelegate new];
            m.delegate = d;
            NSArray *batch = @[[NSObject new], [NSObject new]];
            [d locationManager:m didUpdateLocations:batch];
            if (d.calls != 1 || d.first != batch || d.threadAtEntry != NSThread.currentThread ||
                PXAttached(batch[0]) != PXAttached(batch[1])) atomic_fetch_add(&failures, 1);
        }
    });
    CHECK(atomic_load(&failures) == 0 && atomic_load(&gGeneration) == before + 32,
          "concurrent first installation/callbacks keep per-thread frames and exact generations");
    __weak id weakDelegate, weakManager;
    @autoreleasepool {
        PXFixtureLocationManager *m = [PXFixtureLocationManager new];
        PXLocationAllDelegate *d = [PXLocationAllDelegate new];
        m.delegate = d;
        weakDelegate = d; weakManager = m;
        [d locationManager:m didUpdateLocations:@[[NSObject new]]];
    }
    CHECK(weakDelegate == nil && weakManager == nil, "registry retains neither delegate nor manager");

    PXFixtureLocationManager *m = [PXFixtureLocationManager new];
    PXLocationBlockingDelegate *d = [PXLocationBlockingDelegate new];
    d.entered = dispatch_semaphore_create(0); d.proceed = dispatch_semaphore_create(0);
    m.delegate = d;
    NSArray *batch = @[[NSObject new]];
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    before = atomic_load(&gGeneration);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [d locationManager:m didUpdateLocations:batch];
        dispatch_semaphore_signal(finished);
    });
    CHECK(dispatch_semaphore_wait(d.entered, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) == 0, "callback enters original before change");
    atomic_store(&gEnabled, NO); m.delegate = nil;
    dispatch_semaphore_signal(d.proceed);
    BOOL completed = dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) == 0;
    CHECK(completed, "in-flight callback completes after delegate/toggle change");
    if (completed) {
        CHECK(d.calls == 1 && d.first == batch && atomic_load(&gGeneration) == before + 1,
              "in-flight callback forwards once without super re-projection");
    }
    atomic_store(&gEnabled, YES);
}

int main(void) {
    @autoreleasepool {
        atomic_store(&gEnabled, YES);
        NSArray *names = @[@"locationManager:didUpdateLocations:", @"locationManager:didUpdateToLocation:fromLocation:",
                           @"locationManager:didUpdateHeading:", @"locationManager:didEnterRegion:", @"locationManager:didExitRegion:"];
        NSMutableArray *before = [NSMutableArray array];
        for (NSString *name in names) {
            [before addObject:[NSValue valueWithPointer:class_getInstanceMethod(NSObject.class, NSSelectorFromString(name))]];
        }
        PXCheckCapabilitiesAndABI();
        PXCheckBatchesAndLivePolicy();
        PXCheckInheritanceAndSurfaces();
        PXCheckCoreLocationValueObjects();
        PXCheckReentrancyAndExceptions();
        PXCheckConcurrencyAndLifetime();
        for (NSUInteger index = 0; index < names.count; index++) {
            SEL selector = NSSelectorFromString(names[index]);
            CHECK(class_getInstanceMethod(NSObject.class, selector) == [before[index] pointerValue], "NSObject selector surface unchanged");
            CHECK(![[NSObject new] respondsToSelector:selector], "unrelated NSObject has no fabricated optional selector");
        }
        fprintf(stderr, "Location delegate runtime: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
