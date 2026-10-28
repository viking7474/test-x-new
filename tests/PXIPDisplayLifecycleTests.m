#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#include <stdio.h>

static NSUInteger gChecks, gFailures, gReplies, gFences;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
typedef void (^PXDTransport)(NSData *, NSURLResponse *, NSError *);
@interface PXDTask : NSObject
@property (nonatomic, copy) PXDTransport completion;
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic) NSUInteger resumes;
- (void)resume;
@end
@implementation PXDTask
- (void)resume { self.resumes++; }
@end
@interface PXDSession : NSObject
@property (nonatomic, strong) NSURLSessionConfiguration *config;
@property (nonatomic, strong) PXDTask *task;
@property (nonatomic) NSUInteger finishes, cancellations;
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)config;
- (PXDTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(PXDTransport)completion;
- (void)finishTasksAndInvalidate;
- (void)invalidateAndCancel;
@end
static NSMutableArray<PXDSession *> *gSessions;
@implementation PXDSession
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)config {
    PXDSession *session = [self new]; session.config = config; [gSessions addObject:session]; return session;
}
- (PXDTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(PXDTransport)completion {
    PXDTask *task = [PXDTask new]; task.request = request; task.completion = completion; self.task = task; return task;
}
- (void)finishTasksAndInvalidate { self.finishes++; }
- (void)invalidateAndCancel { self.cancellations++; }
@end

// SDK headers above remain real. Only transport is replaced; production parser,
// locking, serial preparation, main delivery and ARC lifetime run unchanged.
#define NSURLSession PXDSession
#include "../common/PXIPDisplayLookup.m"
#undef NSURLSession

@interface PXDSettings : NSObject
@property (nonatomic, copy) NSString *zone;
- (NSString *)stringForKey:(NSString *)key;
@end
@implementation PXDSettings
- (NSString *)stringForKey:(NSString *)key { (void)key; return self.zone; }
@end
@interface PXDController : NSObject
@property (nonatomic, strong) PXIPDisplayLookup *ipDisplayLookup;
@property (nonatomic, strong) PXDSettings *securitySettings;
@property (nonatomic, copy) NSDictionary *display;
@property (nonatomic) NSUInteger writes, updates;
- (void)fetchCurrentIP;
- (void)fetchSimpleIP;
- (void)fetchIPDisplayUsingFallback:(BOOL)fallback;
- (BOOL)persistTimeZoneName:(NSString *)name forKey:(NSString *)key;
- (void)updateIPLabelWithIP:(NSString *)ip countryCode:(NSString *)country currentTime:(NSString *)time;
@end
@implementation PXDController
- (instancetype)init { if ((self = [super init])) _securitySettings = [PXDSettings new]; return self; }
- (BOOL)persistTimeZoneName:(NSString *)name forKey:(NSString *)key {
    (void)key; if (NSThread.isMainThread) __atomic_fetch_add(&gFailures, 1, __ATOMIC_RELAXED);
    self.writes++; self.securitySettings.zone = name; return YES;
}
- (void)updateIPLabelWithIP:(NSString *)ip countryCode:(NSString *)country currentTime:(NSString *)time {
    CHECK(NSThread.isMainThread, "controller display effects run on main"); self.updates++;
    self.display = @{ @"ip": ip ?: @"", @"country": country ?: @"", @"time": time ?: @"" };
}
#include "PXIPDisplayAdapters.inc"
@end

static BOOL PXDWait(BOOL (^condition)(void)) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3];
    while (deadline.timeIntervalSinceNow > 0) {
        if (condition()) return YES;
        @autoreleasepool { CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.005, YES); }
    }
    return condition();
}
static NSData *PXDJSON(id value) { return [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingFragmentsAllowed error:NULL]; }
static NSDictionary *PXDPayload(NSString *ip) { return @{ @"ip": ip, @"country_code": @"VN", @"timezone": @{ @"id": @"Asia/Ho_Chi_Minh" } }; }
static void PXDReply(PXDSession *session, NSData *data, NSError *error) {
    NSUInteger before = gReplies;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        session.task.completion(data, nil, error);
        dispatch_async(dispatch_get_main_queue(), ^{ gReplies++; });
    });
    CHECK(PXDWait(^BOOL { return gReplies == before + 1; }), "transport and main callback drain");
}
static void PXDFlush(PXIPDisplayLookup *lookup) {
    NSUInteger before = gFences;
    dispatch_async(lookup.preparationQueue, ^{ dispatch_async(dispatch_get_main_queue(), ^{ gFences++; }); });
    CHECK(PXDWait(^BOOL { return gFences == before + 1; }), "ordered worker and UI handoff drain");
}

static void PXDTestLatestFallback(void) {
    PXIPDisplayLookup *lookup = [PXIPDisplayLookup new];
    __block NSUInteger replies = 0; __block NSDictionary *value;
    PXIPDisplayCompletion completion = ^(NSDictionary *payload) { CHECK(NSThread.isMainThread, "lookup completion runs on main"); replies++; value = payload; };
    [lookup resolveUsingFallback:NO prepare:nil completion:completion]; PXDSession *old = gSessions.lastObject;
    [lookup resolveUsingFallback:NO prepare:nil completion:completion]; PXDSession *current = gSessions.lastObject;
    CHECK(old.cancellations == 1 && current.task.resumes == 1 && current.config.timeoutIntervalForRequest == 8 &&
        current.config.timeoutIntervalForResource == 15, "primary policy and cancellation preserved");
    CHECK([current.task.request.URL.absoluteString isEqual:@"https://ipwhois.app/json/"] &&
        [[current.task.request valueForHTTPHeaderField:@"User-Agent"] isEqual:@"WeaponX iOS App"], "primary endpoint and header preserved");
    NSUInteger sessions = gSessions.count;
    PXDReply(old, nil, [NSError errorWithDomain:NSURLErrorDomain code:-1 userInfo:nil]);
    CHECK(gSessions.count == sessions && replies == 0, "stale primary error cannot launch fallback");
    PXDReply(current, PXDJSON(@[]), nil); PXDSession *fallback = gSessions.lastObject;
    CHECK(current.finishes == 1 && fallback != current && fallback.config.timeoutIntervalForRequest == 5 &&
        [fallback.task.request.URL.absoluteString isEqual:@"https://api.ipify.org"], "primary finishes before one fallback starts");
    sessions = gSessions.count; PXDReply(current, nil, nil);
    CHECK(gSessions.count == sessions && current.finishes == 1, "duplicate primary cannot create another fallback");
    PXDReply(fallback, [@" 203.0.113.2\n" dataUsingEncoding:NSUTF8StringEncoding], nil); PXDFlush(lookup);
    CHECK(replies == 1 && [value[@"ip"] isEqual:@"203.0.113.2"] && fallback.finishes == 1,
        "fallback trims body and delivers once");
    PXDReply(fallback, nil, nil); PXDFlush(lookup);
    CHECK(replies == 1 && fallback.finishes == 1, "duplicate fallback is ignored");
    [lookup resolveUsingFallback:NO prepare:nil completion:completion]; old = gSessions.lastObject;
    PXDReply(old, nil, nil); fallback = gSessions.lastObject;
    [lookup resolveUsingFallback:NO prepare:nil completion:completion]; current = gSessions.lastObject;
    PXDReply(fallback, [@"old" dataUsingEncoding:NSUTF8StringEncoding], nil);
    PXDReply(current, PXDJSON(PXDPayload(@"new")), nil); PXDFlush(lookup);
    CHECK(replies == 2 && [value[@"ip"] isEqual:@"new"] && fallback.cancellations == 1, "old fallback cannot overwrite newer generation");
}

static void PXDTestParsingAndQueuedCancellation(void) {
    NSArray *invalid = @[@[], NSNull.null, @{}, @{ @"ip": NSNull.null }, @{ @"ip": @3 }, @{ @"ip": @"" }];
    for (id root in invalid) CHECK(PXIPDisplayPayload(PXDJSON(root), NO) == nil, "wrong JSON roots and IP types reject safely");
    NSDictionary *optional = PXIPDisplayPayload(PXDJSON(@{ @"ip": @"valid", @"country_code": @[], @"timezone": NSNull.null, @"timezone_gmt": @3 }), NO);
    CHECK(optional.count == 1 && [optional[@"ip"] isEqual:@"valid"], "invalid optional fields cannot escape to UIKit or timezone selectors");
    CHECK(PXIPDisplayPayload([@"bad JSON" dataUsingEncoding:NSUTF8StringEncoding], NO) == nil &&
        PXIPDisplayPayload([@" \n" dataUsingEncoding:NSUTF8StringEncoding], YES) == nil, "malformed JSON and empty fallback reject safely");
    PXIPDisplayLookup *lookup = [PXIPDisplayLookup new];
    dispatch_semaphore_t entered = dispatch_semaphore_create(0), proceed = dispatch_semaphore_create(0);
    dispatch_async(lookup.preparationQueue, ^{
        dispatch_semaphore_signal(entered);
        dispatch_semaphore_wait(proceed, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
    });
    CHECK(PXDWait(^BOOL { return dispatch_semaphore_wait(entered, DISPATCH_TIME_NOW) == 0; }), "worker barrier entered");
    __block NSUInteger prepares = 0, replies = 0;
    [lookup resolveUsingFallback:NO prepare:^NSDictionary *(NSDictionary *payload) { prepares++; return payload; }
        completion:^(NSDictionary *payload) { (void)payload; replies++; }];
    PXDReply(gSessions.lastObject, PXDJSON(PXDPayload(@"stale")), nil);
    [lookup cancel]; dispatch_semaphore_signal(proceed); PXDFlush(lookup);
    CHECK(prepares == 0 && replies == 0, "cancel drops queued preparation before source effects");
    NSUInteger sessions = gSessions.count;
    [lookup resolveUsingFallback:NO prepare:nil completion:nil];
    CHECK(gSessions.count == sessions, "nil completion starts no session");
}

static void PXDTestAdapterLifetimeAndReentry(void) {
    PXDController *controller = [PXDController new];
    [controller fetchCurrentIP]; PXDSession *session = gSessions.lastObject;
    PXDReply(session, PXDJSON(PXDPayload(@"203.0.113.5")), nil); PXDFlush(controller.ipDisplayLookup);
    CHECK(controller.writes == 1 && controller.updates == 1 && [controller.securitySettings.zone isEqual:@"Asia/Ho_Chi_Minh"] &&
        [controller.display[@"time"] length] > 0, "exact adapter persists timezone off main and delivers formatted display");
    [controller fetchCurrentIP]; PXDReply(gSessions.lastObject, PXDJSON(PXDPayload(@"203.0.113.6")), nil); PXDFlush(controller.ipDisplayLookup);
    CHECK(controller.writes == 1 && controller.updates == 2, "unchanged timezone skips another source write");
    [controller fetchSimpleIP]; PXDReply(gSessions.lastObject, [@"203.0.113.7" dataUsingEncoding:NSUTF8StringEncoding], nil); PXDFlush(controller.ipDisplayLookup);
    CHECK(controller.writes == 1 && controller.updates == 3 && [controller.display[@"country"] isEqual:@""], "direct fallback preserves no-country no-timezone behavior");
    __weak PXDController *weakController;
    @autoreleasepool { PXDController *owner = [PXDController new]; weakController = owner; [owner fetchCurrentIP]; session = gSessions.lastObject; }
    CHECK(!weakController && session.cancellations == 1, "pending transport does not retain controller and dealloc cancels session");
    PXIPDisplayLookup *lookup = [PXIPDisplayLookup new]; __weak PXIPDisplayLookup *weakLookup = lookup;
    __block NSUInteger completions = 0;
    [lookup resolveUsingFallback:NO prepare:nil completion:^(NSDictionary *payload) {
        (void)payload; completions++; [weakLookup resolveUsingFallback:YES prepare:nil completion:^(NSDictionary *next) { (void)next; completions++; }];
    }];
    PXDReply(gSessions.lastObject, PXDJSON(PXDPayload(@"first")), nil); PXDFlush(lookup);
    session = gSessions.lastObject; PXDReply(session, [@"second" dataUsingEncoding:NSUTF8StringEncoding], nil); PXDFlush(lookup);
    CHECK(completions == 2 && session.cancellations == 0, "consumer reentry retains its new lookup");
    NSUInteger before = gSessions.count;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ [controller fetchCurrentIP]; });
    CHECK(PXDWait(^BOOL { return gSessions.count > before; }), "background adapter entry routes main without dispatch sync");
    session = gSessions.lastObject;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ [controller.ipDisplayLookup cancel]; });
    CHECK(PXDWait(^BOOL { return session.cancellations == 1; }), "background cancellation reaches main");
}

static void PXDTestInFlightOrdering(void) {
    PXIPDisplayLookup *lookup = [PXIPDisplayLookup new];
    dispatch_semaphore_t entered = dispatch_semaphore_create(0), proceed = dispatch_semaphore_create(0);
    NSMutableArray *effects = [NSMutableArray new]; __block NSUInteger replies = 0;
    PXIPDisplayCompletion completion = ^(NSDictionary *payload) {
        CHECK([payload[@"ip"] isEqual:@"new"], "in-flight old preparation cannot deliver stale UI"); replies++;
    };
    [lookup resolveUsingFallback:NO prepare:^NSDictionary *(NSDictionary *payload) {
        dispatch_semaphore_signal(entered);
        dispatch_semaphore_wait(proceed, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
        [effects addObject:payload[@"ip"]]; return payload;
    } completion:completion];
    PXDReply(gSessions.lastObject, PXDJSON(PXDPayload(@"old")), nil);
    CHECK(PXDWait(^BOOL { return dispatch_semaphore_wait(entered, DISPATCH_TIME_NOW) == 0; }), "old preparation admitted without blocking main");
    [lookup resolveUsingFallback:NO prepare:^NSDictionary *(NSDictionary *payload) {
        [effects addObject:payload[@"ip"]]; return payload;
    } completion:completion];
    PXDReply(gSessions.lastObject, PXDJSON(PXDPayload(@"new")), nil);
    dispatch_semaphore_signal(proceed); PXDFlush(lookup);
    CHECK((replies == 1 && [effects isEqual:@[@"old", @"new"]]),
        "admitted preparation finishes before newer effects and stale UI is suppressed");
}

int main(void) {
    @autoreleasepool {
        gSessions = [NSMutableArray new]; PXDTestLatestFallback(); PXDTestParsingAndQueuedCancellation(); PXDTestAdapterLifetimeAndReentry(); PXDTestInFlightOrdering();
        fprintf(stderr, "IP display lifecycle: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
