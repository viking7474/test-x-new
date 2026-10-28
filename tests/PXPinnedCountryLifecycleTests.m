#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <dispatch/dispatch.h>
#include <math.h>
#include <stdio.h>

static NSUInteger gChecks, gFailures, gDeliveries;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
typedef void (^PXCountryTransportCompletion)(NSData *, NSURLResponse *, NSError *);
@interface PXCountryTask : NSObject
@property (nonatomic, copy) PXCountryTransportCompletion completion;
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic) NSUInteger resumes, cancellations;
- (void)resume;
- (void)cancel;
@end
@implementation PXCountryTask
- (void)resume { self.resumes++; }
- (void)cancel { self.cancellations++; }
@end
static NSMutableArray<PXCountryTask *> *gTasks;
@interface PXCountrySession : NSObject
+ (instancetype)sharedSession;
- (PXCountryTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(PXCountryTransportCompletion)completion;
@end
@implementation PXCountrySession
+ (instancetype)sharedSession { static PXCountrySession *session; static dispatch_once_t once; dispatch_once(&once, ^{ session = [self new]; }); return session; }
- (PXCountryTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(PXCountryTransportCompletion)completion {
    PXCountryTask *task = [PXCountryTask new]; task.request = request; task.completion = completion;
    [gTasks addObject:task]; return task;
}
@end

// Replace only transport, after importing platform headers. Parsing, URL requests,
// coordinates, GCD, weak ownership and the lookup implementation remain real.
#define NSURLSession PXCountrySession
#define NSURLSessionDataTask PXCountryTask
#include "../common/PXPinnedCountryLookup.m"
#undef NSURLSessionDataTask
#undef NSURLSession

@interface PXCountryController : NSObject
@property (nonatomic, strong) NSCache *countryCache;
@property (nonatomic, strong) PXPinnedCountryLookup *pinnedCountryLookup;
- (void)fetchCountryForCoordinates:(double)lat longitude:(double)lon completion:(void (^)(NSString *countryCode, NSString *flag))completion;
- (NSString *)flagEmojiForCountryCode:(NSString *)code;
@end
@implementation PXCountryController
- (instancetype)init { if ((self = [super init])) { _countryCache = [NSCache new]; _countryCache.countLimit = 50; } return self; }
- (NSString *)flagEmojiForCountryCode:(NSString *)code { return code.length == 2 ? @"fixture-flag" : nil; }
#include "PXSecurityCountryAdapter.inc"
@end

static BOOL Wait(BOOL (^condition)(void)) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3];
    while (!condition() && deadline.timeIntervalSinceNow > 0)
        @autoreleasepool { CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.005, YES); }
    return condition();
}
// MacTypes.h declares Point; fixture helpers must not reuse SDK type names.
static CLLocationCoordinate2D PXCountryFixtureCoordinate(void) { return CLLocationCoordinate2DMake(10.75, 106.5); }
static NSData *JSON(id value) { return [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingFragmentsAllowed error:NULL]; }
static void ReplyData(PXCountryTask *task, NSData *data, NSError *error) {
    NSUInteger before = gDeliveries;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        // Deliberately permit late and duplicate completion after cancellation.
        task.completion(data, nil, error);
        dispatch_async(dispatch_get_main_queue(), ^{ gDeliveries++; });
    });
    CHECK(Wait(^BOOL { return gDeliveries == before + 1; }), "transport callback and main delivery drain");
}
static void Reply(PXCountryTask *task, id value) { ReplyData(task, JSON(value), nil); }

static void TestLatestAndReentry(void) {
    PXPinnedCountryLookup *lookup = [PXPinnedCountryLookup new];
    __block NSUInteger replies = 0; __block NSString *result;
    PXPinnedCountryCompletion completion = ^(NSString *code) {
        CHECK(NSThread.isMainThread, "current result arrives on main"); replies++; result = code;
    };
    [lookup resolveCoordinate:PXCountryFixtureCoordinate() completion:completion]; PXCountryTask *old = gTasks.lastObject;
    [lookup resolveCoordinate:PXCountryFixtureCoordinate() completion:completion]; PXCountryTask *current = gTasks.lastObject;
    CHECK(old.cancellations == 1 && old.resumes == 1 && current.resumes == 1, "supersession cancels only old task");
    CHECK([current.request.URL.host isEqual:@"nominatim.openstreetmap.org"] && current.request.timeoutInterval == 10 &&
        [[current.request valueForHTTPHeaderField:@"User-Agent"] isEqual:@"WeaponX iOS App"], "endpoint timeout and user agent preserved");
    CHECK([current.request.URL.query containsString:@"lat=10.750000&lon=106.500000&zoom=18&addressdetails=1"], "coordinate formatting and request fields preserved");
    Reply(old, @{ @"address": @{ @"country_code": @"us" } });
    CHECK(replies == 0, "late superseded result has no consumer effects");
    Reply(current, @{ @"address": @{ @"country_code": @"vn" } });
    Reply(current, @{ @"address": @{ @"country_code": @"us" } });
    CHECK(replies == 1 && [result isEqual:@"VN"], "current country delivered once and normalized");
    [lookup cancel]; CHECK(current.cancellations == 0, "completed task released before cancellation");
    [lookup resolveCoordinate:PXCountryFixtureCoordinate() completion:completion]; current = gTasks.lastObject; [lookup cancel];
    ReplyData(current, nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]);
    CHECK(replies == 1 && current.cancellations == 1, "cancelled late error is suppressed");
    __weak PXPinnedCountryLookup *weakLookup = lookup;
    [lookup resolveCoordinate:PXCountryFixtureCoordinate() completion:^(NSString *code) {
        (void)code; [weakLookup resolveCoordinate:PXCountryFixtureCoordinate() completion:completion];
    }];
    current = gTasks.lastObject; Reply(current, @{ @"address": @{ @"country_code": @"vn" } });
    PXCountryTask *reentrant = gTasks.lastObject;
    Reply(reentrant, @{ @"address": @{ @"country_code": @"jp" } });
    CHECK(replies == 2 && [result isEqual:@"JP"] && reentrant != current && reentrant.cancellations == 0,
        "consumer reentry keeps newly started request");
}

static void TestInvalidAndLifetime(void) {
    PXPinnedCountryLookup *lookup = [PXPinnedCountryLookup new];
    __block NSUInteger replies = 0;
    PXPinnedCountryCompletion completion = ^(NSString *code) { CHECK(!code && NSThread.isMainThread, "malformed result fails safely on main"); replies++; };
    NSArray *bad = @[@[], NSNull.null, @{ @"address": @[] }, @{ @"address": NSNull.null },
        @{ @"address": @{ @"country_code": @1 } }, @{ @"address": @{ @"country_code": NSNull.null } },
        @{ @"address": @{ @"country_code": @"" } }, @{ @"address": @{ @"country_code": @"123" } },
        @{ @"address": @{ @"country_code": @"1!" } }];
    for (id value in bad) { [lookup resolveCoordinate:PXCountryFixtureCoordinate() completion:completion]; Reply(gTasks.lastObject, value); }
    [lookup resolveCoordinate:PXCountryFixtureCoordinate() completion:completion]; ReplyData(gTasks.lastObject, [@"invalid JSON" dataUsingEncoding:NSUTF8StringEncoding], nil);
    [lookup resolveCoordinate:PXCountryFixtureCoordinate() completion:completion]; ReplyData(gTasks.lastObject, nil, [NSError errorWithDomain:NSURLErrorDomain code:-1 userInfo:nil]);
    CHECK(replies == bad.count + 2, "wrong JSON shapes missing fields and transport errors return nil once");
    NSUInteger tasks = gTasks.count;
    [lookup resolveCoordinate:CLLocationCoordinate2DMake(NAN, 2) completion:completion];
    [lookup resolveCoordinate:CLLocationCoordinate2DMake(91, 2) completion:completion];
    [lookup resolveCoordinate:PXCountryFixtureCoordinate() completion:nil];
    CHECK(gTasks.count == tasks && replies == bad.count + 4, "invalid coordinates and nil completion launch no transport");
    __weak PXPinnedCountryLookup *weak;
    PXCountryTask *pending;
    @autoreleasepool {
        PXPinnedCountryLookup *owner = [PXPinnedCountryLookup new]; weak = owner;
        [owner resolveCoordinate:PXCountryFixtureCoordinate() completion:^(NSString *code) { (void)code; replies++; }]; pending = gTasks.lastObject;
    }
    CHECK(!weak && pending.cancellations == 1, "pending transport does not retain lookup and dealloc cancels task");
    NSUInteger before = replies; Reply(pending, @{ @"address": @{ @"country_code": @"vn" } });
    CHECK(replies == before, "deallocated lookup ignores late result");
}

static void TestAdapterAndBackground(void) {
    PXCountryController *controller = [PXCountryController new];
    __block NSUInteger replies = 0;
    void (^completion)(NSString *, NSString *) = ^(NSString *code, NSString *flag) {
        CHECK(NSThread.isMainThread && [code isEqual:@"VN"] && flag.length, "adapter delivers country and flag on main"); replies++;
    };
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [controller fetchCountryForCoordinates:10.75 longitude:106.5 completion:completion];
    });
    NSUInteger before = gTasks.count;
    CHECK(Wait(^BOOL { return gTasks.count > before; }), "background adapter enters main without synchronous dispatch");
    Reply(gTasks.lastObject, @{ @"address": @{ @"country_code": @"vn" } });
    CHECK(replies == 1, "network adapter success completes once");
    [controller fetchCountryForCoordinates:11 longitude:107 completion:completion]; PXCountryTask *stale = gTasks.lastObject;
    before = gTasks.count;
    [controller fetchCountryForCoordinates:10.750001 longitude:106.500001 completion:completion];
    CHECK(gTasks.count == before && replies == 2 && stale.cancellations == 1, "rounded cache hit cancels previous request without new transport");
    Reply(stale, @{ @"address": @{ @"country_code": @"us" } });
    CHECK(replies == 2 && ![controller.countryCache objectForKey:@"11.0000,107.0000"], "stale adapter cannot populate owner cache");
    __weak PXCountryController *weak;
    @autoreleasepool {
        PXCountryController *owner = [PXCountryController new]; weak = owner;
        [owner fetchCountryForCoordinates:10 longitude:100 completion:completion];
    }
    CHECK(!weak && gTasks.lastObject.cancellations == 1, "network adapter does not retain controller");
    [controller fetchCountryForCoordinates:12 longitude:108 completion:completion]; stale = gTasks.lastObject;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ [controller.pinnedCountryLookup cancel]; });
    CHECK(Wait(^BOOL { return stale.cancellations == 1; }), "background cancellation reaches main");
}

int main(void) {
    @autoreleasepool {
        gTasks = [NSMutableArray new];
        TestLatestAndReentry(); TestInvalidAndLifetime(); TestAdapterAndBackground();
        fprintf(stderr, "Pinned country lifecycle: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
