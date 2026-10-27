#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <dispatch/dispatch.h>
#import "TLinkIOSLogging.h"

static NSUInteger gChecks, gFailures, gSettlements, gWrites;
#define CHECK(value, message) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", message); } } while (0)
void PXLog(NSString *format, ...) { (void)format; }
void PXLogError(NSError *error, NSString *context) { (void)error; (void)context; }
BOOL PXWriteSecurityBool(NSString *key, BOOL value, NSError **error) { (void)key; (void)value; if (error) *error = nil; gWrites++; return YES; }

// Controlled NSURLSession boundary: completion may arrive even after cancel.
// Actual production parsing/aggregation, GCD queues and Foundation timers run.
@interface PXMonitorTask : NSObject
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, copy) void (^completion)(NSData *, NSURLResponse *, NSError *);
@property (nonatomic, assign) BOOL resumed;
- (void)resume;
- (void)reply:(NSData *)data error:(NSError *)error;
@end
@implementation PXMonitorTask
- (void)resume { self.resumed = YES; }
- (void)reply:(NSData *)data error:(NSError *)error {
    void (^completion)(NSData *, NSURLResponse *, NSError *) = nil;
    @synchronized (self) { completion = self.completion; self.completion = nil; }
    if (completion) completion(data, nil, error);
}
@end
@interface PXMonitorSession : NSObject
@property (nonatomic, strong) NSMutableArray<PXMonitorTask *> *tasks;
@property (nonatomic, strong) NSURLSessionConfiguration *configuration;
@property (nonatomic, assign) NSUInteger finishes;
@property (nonatomic, assign) NSUInteger cancellations;
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration;
- (PXMonitorTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completion;
- (void)finishTasksAndInvalidate;
- (void)invalidateAndCancel;
@end
static NSMutableArray<PXMonitorSession *> *gSessions;
@implementation PXMonitorSession
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration {
    CHECK(NSThread.isMainThread, "monitor creates transport on main thread");
    PXMonitorSession *session = [self new]; session.tasks = [NSMutableArray array]; session.configuration = [configuration copy];
    [gSessions addObject:session]; return session;
}
- (PXMonitorTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completion {
    PXMonitorTask *task = [PXMonitorTask new]; task.URL = url; task.completion = completion; [self.tasks addObject:task]; return task;
}
- (void)finishTasksAndInvalidate { self.finishes++; }
- (void)invalidateAndCancel { self.cancellations++; }
@end

// Observe terminal main-queue work without replacing dispatch-group ordering.
static void PXObserveGroupNotify(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block) {
    dispatch_group_notify(group, queue, ^{ block(); gSettlements++; });
}
#define NSURLSession PXMonitorSession
#define NSURLSessionDataTask PXMonitorTask
#define dispatch_group_notify PXObserveGroupNotify
@class PXMonitorFixture;
#define IPMonitorService PXMonitorFixture
#include "PXIPMonitorReachabilityOwner.inc"
#undef IPMonitorService
@interface PXMonitorFixture : NSObject
@property (nonatomic, assign) BOOL isMonitoring;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) NSTimer *monitoringTimer;
@property (nonatomic, strong) NSObject *monitoringToken;
@property (nonatomic, strong) NSMutableSet<NSURLSession *> *monitoringSessions;
@property (nonatomic, copy) NSString *lastKnownIP;
@property (nonatomic, copy) NSString *lastCheckedIP;
@property (nonatomic, assign) SCNetworkReachabilityRef reachability;
@property (nonatomic, assign) NSTimeInterval adaptiveInterval;
@property (nonatomic, assign) NSTimeInterval lastCheckTime;
@property (nonatomic, assign) NSInteger checkCount;
@property (nonatomic, assign) NSInteger consensusCount;
@property (nonatomic, assign) NSUInteger saves;
@property (nonatomic, assign) NSUInteger alerts;
@property (nonatomic, assign) NSUInteger reachabilityEvents;
@property (nonatomic, copy) dispatch_block_t duringSave;
- (void)handleReachabilityChange:(SCNetworkReachabilityFlags)flags;
- (BOOL)isIPMonitoringEnabled;
- (void)saveLastKnownIP:(NSString *)ip;
- (void)showIPChangeAlertWithOldIP:(NSString *)oldIP newIP:(NSString *)newIP;
#include "PXIPMonitorLifecycleDeclarations.inc"
@end
@implementation PXMonitorFixture
@synthesize isMonitoring = _isMonitoring;
- (instancetype)init {
    if ((self = [super init])) { _enabled = YES; _adaptiveInterval = 60; _monitoringSessions = [NSMutableSet set]; }
    return self;
}
- (BOOL)isIPMonitoringEnabled { return self.enabled; }
- (void)handleReachabilityChange:(SCNetworkReachabilityFlags)flags { (void)flags; self.reachabilityEvents++; }
- (void)saveLastKnownIP:(NSString *)ip {
    (void)ip; CHECK(NSThread.isMainThread, "IP save executes on main thread"); self.saves++;
    dispatch_block_t callback = self.duringSave; self.duringSave = nil; if (callback) callback();
}
- (void)showIPChangeAlertWithOldIP:(NSString *)oldIP newIP:(NSString *)newIP { (void)oldIP; (void)newIP; CHECK(NSThread.isMainThread, "IP alert executes on main thread"); self.alerts++; }
#include "PXIPMonitorLifecycleMethods.inc"
@end
#undef dispatch_group_notify
#undef NSURLSessionDataTask
#undef NSURLSession
#define IPMonitorService PXMonitorFixture
#include "PXIPMonitorReachabilityCallback.inc"
#undef IPMonitorService

static BOOL Wait(BOOL (^condition)(void)) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3];
    while (!condition() && deadline.timeIntervalSinceNow > 0) {
        @autoreleasepool { CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.005, YES); }
    }
    return condition();
}
static void ReplyAll(PXMonitorSession *session, NSString *ip) {
    NSUInteger settlements = gSettlements;
    CHECK(session.tasks.count == 3, "consensus keeps three existing endpoints");
    for (PXMonitorTask *task in session.tasks) {
        CHECK(task.resumed, "production resumes each transport task");
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            NSString *body = [task.URL.host isEqual:@"api.myip.com"] ? [NSString stringWithFormat:@"{\"ip\":\"%@\"}", ip] : ip;
            [task reply:[body dataUsingEncoding:NSUTF8StringEncoding] error:nil];
        });
    }
    CHECK(Wait(^BOOL { return gSettlements == settlements + 1; }), "consensus terminal main callback drains with deadline");
}
static void TestStoppedAndRestarted(void) {
    PXMonitorFixture *monitor = [PXMonitorFixture new];
    [monitor startMonitoring]; PXMonitorSession *initial = gSessions.lastObject; NSTimer *oldTimer = monitor.monitoringTimer;
    CHECK(initial.configuration.timeoutIntervalForRequest == 8 && initial.configuration.timeoutIntervalForResource == 20 &&
          initial.configuration.HTTPMaximumConnectionsPerHost == 3, "transport timeout and connection policy preserved");
    [monitor startMonitoring]; CHECK(monitor.monitoringSessions.count == 1, "duplicate start does not create another transport batch");
    [monitor stopMonitoring];
    ReplyAll(initial, @"203.0.113.1");
    CHECK(monitor.saves == 0 && monitor.alerts == 0 && !monitor.monitoringTimer && !oldTimer.valid && initial.cancellations == 1 && initial.finishes == 0,
          "stopped initial callbacks cannot save IP or resurrect timer");

    monitor.lastKnownIP = @"baseline"; monitor.lastCheckedIP = @"previous";
    [monitor startMonitoring]; PXMonitorSession *oldInitial = gSessions.lastObject;
    monitor.lastCheckTime = 0; [monitor.monitoringTimer fire]; PXMonitorSession *oldAdaptive = gSessions.lastObject;
    monitor.lastCheckTime = 0; [monitor checkForIPChange]; PXMonitorSession *oldManual = gSessions.lastObject;
    [monitor stopMonitoring]; [monitor startMonitoring]; PXMonitorSession *current = gSessions.lastObject; NSTimer *currentTimer = monitor.monitoringTimer;
    ReplyAll(oldInitial, @"203.0.113.2"); ReplyAll(oldAdaptive, @"203.0.113.3"); ReplyAll(oldManual, @"203.0.113.4");
    CHECK(monitor.saves == 0 && monitor.alerts == 0 && monitor.adaptiveInterval == 60 && [monitor.lastKnownIP isEqual:@"baseline"] &&
          [monitor.lastCheckedIP isEqual:@"previous"] && monitor.monitoringTimer == currentTimer && monitor.monitoringSessions.count == 1 &&
          oldInitial.cancellations == 1 && oldAdaptive.cancellations == 1 && oldManual.cancellations == 1,
          "stale adaptive and manual callbacks cannot mutate restarted monitoring");
    ReplyAll(current, @"203.0.113.5");
    CHECK(monitor.saves == 1 && monitor.consensusCount == 1 && [monitor.lastKnownIP isEqual:@"203.0.113.5"] && current.finishes == 1 &&
          current.cancellations == 0 && monitor.monitoringSessions.count == 0, "normal consensus finishes session and delivers on main thread");
    monitor.lastCheckTime = 0; [monitor.monitoringTimer fire]; ReplyAll(gSessions.lastObject, @"203.0.113.6");
    CHECK(monitor.adaptiveInterval == 30 && monitor.alerts == 1 && monitor.saves == 2, "changed adaptive IP preserves interval reduction and save policy");
    monitor.lastCheckTime = 0; [monitor.monitoringTimer fire]; ReplyAll(gSessions.lastObject, @"203.0.113.6");
    CHECK(monitor.adaptiveInterval == 45 && monitor.alerts == 1 && monitor.saves == 2, "unchanged adaptive IP preserves interval increase policy");
    NSUInteger sessions = gSessions.count; monitor.lastCheckTime = 0; [monitor adaptiveCheckForIPChange:oldTimer];
    [monitor stopMonitoring]; monitor.enabled = NO; [monitor startMonitoring]; [monitor checkForIPChange]; [monitor startAdaptivePolling];
    CHECK(sessions == gSessions.count && !monitor.monitoringTimer && !monitor.monitoringToken, "old timer and disabled controls launch no transport");
}
static void TestDisabledAndReleased(void) {
    PXMonitorFixture *monitor = [PXMonitorFixture new]; [monitor startMonitoring]; PXMonitorSession *session = gSessions.lastObject;
    monitor.enabled = NO; ReplyAll(session, @"203.0.113.7");
    CHECK(session.finishes == 1 && session.cancellations == 0 && monitor.saves == 0 && monitor.monitoringSessions.count == 0,
          "disabled preference drops result and still finishes session");
    [monitor stopMonitoring];
    __weak PXMonitorFixture *released;
    NSTimer *timer = nil;
    @autoreleasepool {
        PXMonitorFixture *temporary = [PXMonitorFixture new]; [temporary startMonitoring];
        released = temporary; timer = temporary.monitoringTimer; session = gSessions.lastObject;
    }
    CHECK(!released && !timer.valid && session.cancellations == 1, "pending transport and timer do not retain monitor owner");
    ReplyAll(session, @"203.0.113.8");

    __block BOOL completed = NO, result = YES; __block NSError *error = nil;
    NSUInteger writes = gWrites, sessions = gSessions.count;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        result = [monitor setMonitoringEnabledAndPersist:YES error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{ completed = YES; });
    });
    CHECK(Wait(^BOOL { return completed; }) && !result && error && writes == gWrites && sessions == gSessions.count,
          "off-main toggle fails before persistence or service mutation");
    monitor.enabled = YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ [monitor startMonitoring]; });
    CHECK(Wait(^BOOL { return monitor.isMonitoring; }), "background void start routes to main without synchronous wait"); session = gSessions.lastObject;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ [monitor stopMonitoring]; });
    CHECK(Wait(^BOOL { return !monitor.monitoringTimer && !monitor.monitoringToken; }), "background void stop routes to main and cancels transport");
    ReplyAll(session, @"203.0.113.9");
}
static void TestParsing(void) {
    PXMonitorFixture *monitor = [PXMonitorFixture new];
    NSArray<NSString *> *payloads = @[@"[]", @"{\"ip\":null}", @"{\"ip\":7}", @"{\"ip\":{}}", @"not-json"];
    for (NSString *payload in payloads) {
        PXMonitorSession *session = [PXMonitorSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
        __block NSString *value = nil; __block NSError *failure = nil;
        [monitor fetchIPFromService:@"https://api.myip.com" isJSON:YES key:@"ip" withSession:(id)session completion:^(NSString *ip, NSError *error) { value = ip; failure = error; }];
        [session.tasks.firstObject reply:[payload dataUsingEncoding:NSUTF8StringEncoding] error:nil];
        CHECK(!value && failure, "invalid JSON shapes never escape as IP values"); [session finishTasksAndInvalidate];
    }
    PXMonitorSession *session = [PXMonitorSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
    __block BOOL failed = NO;
    [monitor fetchIPFromService:@"https://api.myip.com" isJSON:YES key:@"ip" withSession:(id)session completion:^(NSString *ip, NSError *error) { failed = !ip && error != nil; }];
    [session.tasks.firstObject reply:nil error:nil]; CHECK(failed, "missing JSON data reports error without exception"); [session finishTasksAndInvalidate];
}
static void TestFailureAndFallback(void) {
    for (NSUInteger successes = 0; successes <= 1; successes++) {
        PXMonitorFixture *monitor = [PXMonitorFixture new]; [monitor startMonitoring];
        PXMonitorSession *session = gSessions.lastObject; NSUInteger settlements = gSettlements;
        for (NSUInteger index = 0; index < session.tasks.count; index++) {
            PXMonitorTask *task = session.tasks[index];
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
                NSData *data = successes && index == 0 ? [@"203.0.113.10" dataUsingEncoding:NSUTF8StringEncoding] : nil;
                NSError *error = data ? nil : [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
                [task reply:data error:error];
            });
        }
        CHECK(Wait(^BOOL { return gSettlements == settlements + 1; }) && session.finishes == 1 && monitor.monitoringSessions.count == 0 &&
              monitor.saves == successes && monitor.consensusCount == 0, "all-failure and single-result fallback finish sessions with existing save policy");
        [monitor stopMonitoring];
    }
}
static void TestReachabilityOwner(void) {
    PXIPMonitorReachabilityOwner *owner = [PXIPMonitorReachabilityOwner new];
    __weak PXIPMonitorReachabilityOwner *weakOwner = owner;
    SCNetworkReachabilityContext context = {0, (__bridge void *)owner, CFRetain, CFRelease, NULL};
    context.info = (void *)context.retain(context.info); owner = nil;
    CHECK(weakOwner != nil, "reachability context retains proxy independently of local scope");
    __weak PXMonitorFixture *released;
    @autoreleasepool {
        PXMonitorFixture *monitor = [PXMonitorFixture new];
        ((__bridge PXIPMonitorReachabilityOwner *)context.info).service = monitor;
        ReachabilityCallback(NULL, 0, context.info);
        CHECK(monitor.reachabilityEvents == 1, "reachability proxy forwards to live owner");
        released = monitor;
    }
    CHECK(!released && !((__bridge PXIPMonitorReachabilityOwner *)context.info).service, "retained reachability context does not retain service owner");
    ReachabilityCallback(NULL, 0, context.info);
    context.release(context.info);
    CHECK(!weakOwner, "reachability context balances retained proxy release after owner deallocation");
}
static void TestInstanceAndReentry(void) {
    PXMonitorFixture *a = [PXMonitorFixture new], *b = [PXMonitorFixture new];
    [a startMonitoring]; PXMonitorSession *first = gSessions.lastObject;
    [b startMonitoring]; PXMonitorSession *second = gSessions.lastObject;
    ReplyAll(first, @"203.0.113.11"); ReplyAll(second, @"203.0.113.12");
    a.lastCheckTime = 0; [a.monitoringTimer fire]; ReplyAll(gSessions.lastObject, @"203.0.113.13");
    b.lastCheckTime = 0; [b.monitoringTimer fire]; ReplyAll(gSessions.lastObject, @"203.0.113.14");
    CHECK([a.lastCheckedIP isEqual:@"203.0.113.13"] && [b.lastCheckedIP isEqual:@"203.0.113.14"] && !a.alerts && !b.alerts,
          "independent instances do not share adaptive baseline");
    __weak PXMonitorFixture *weakA = a; __block NSTimer *restartedTimer = nil;
    a.duringSave = ^{ [weakA stopMonitoring]; [weakA startMonitoring]; restartedTimer = weakA.monitoringTimer; };
    a.lastCheckTime = 0; [a.monitoringTimer fire]; PXMonitorSession *reentrant = gSessions.lastObject;
    ReplyAll(reentrant, @"203.0.113.15"); PXMonitorSession *restarted = gSessions.lastObject;
    CHECK(restarted != reentrant && a.monitoringTimer == restartedTimer && [a.lastCheckedIP isEqual:@"203.0.113.13"] && a.monitoringSessions.count == 1,
          "cache callback reentry cannot reschedule old adaptive work into new generation");
    [a stopMonitoring]; [b stopMonitoring]; ReplyAll(restarted, @"203.0.113.16");
}
int main(void) {
    @autoreleasepool {
        gSessions = [NSMutableArray array];
        TestStoppedAndRestarted(); TestDisabledAndReleased(); TestParsing(); TestFailureAndFallback(); TestReachabilityOwner(); TestInstanceAndReentry();
        for (PXMonitorSession *session in gSessions)
            CHECK(session.finishes + session.cancellations == 1, "each controlled session closes exactly once");
        printf("IP Monitor lifecycle: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
