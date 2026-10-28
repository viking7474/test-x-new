#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <dispatch/dispatch.h>
#include <stdio.h>

static NSUInteger gChecks, gFailures, gReplies, gFences, gNotices;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PXLog(...) do {} while (0)
typedef void (^PXRTransport)(NSData *, NSURLResponse *, NSError *);
@interface PXRTask : NSObject
@property (nonatomic, copy) PXRTransport completion;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic) NSUInteger resumes;
- (void)resume;
@end
@implementation PXRTask
- (void)resume { self.resumes++; }
@end
@interface PXRSession : NSObject
@property (nonatomic, strong) NSURLSessionConfiguration *config;
@property (nonatomic, strong) PXRTask *task;
@property (nonatomic) NSUInteger finishes, cancellations;
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)config;
- (PXRTask *)dataTaskWithURL:(NSURL *)url completionHandler:(PXRTransport)completion;
- (void)finishTasksAndInvalidate;
- (void)invalidateAndCancel;
@end
static NSMutableArray<PXRSession *> *gSessions;
@implementation PXRSession
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)config {
    PXRSession *session = [self new]; session.config = config; [gSessions addObject:session]; return session;
}
- (PXRTask *)dataTaskWithURL:(NSURL *)url completionHandler:(PXRTransport)completion {
    PXRTask *task = [PXRTask new]; task.url = url; task.completion = completion; self.task = task; return task;
}
- (void)finishTasksAndInvalidate { self.finishes++; }
- (void)invalidateAndCancel { self.cancellations++; }
@end
#define NSURLSession PXRSession
#include "../common/PXTargetRegionSync.m"
#undef NSURLSession

static NSObject *gGuard;
static BOOL gEnabled, gFailToggle, gFailSync, gBlockSync;
static NSMutableArray *gEffects;
static NSUInteger gCacheWrites;
static NSString *gGPSPath;
static dispatch_semaphore_t gEntered, gProceed;
static BOOL PXReadSecurityBool(NSString *key, BOOL fallback) {
    (void)key; (void)fallback; @synchronized(gGuard) { return gEnabled; }
}
static BOOL PXWriteSecurityBool(NSString *key, BOOL enabled, NSError **error) {
    (void)key;
    @synchronized(gGuard) {
        if (gFailToggle) { if (error) *error = [NSError errorWithDomain:@"fixture" code:1 userInfo:nil]; return NO; }
        gEnabled = enabled; [gEffects addObject:enabled ? @"toggle-on" : @"toggle-off"]; return YES;
    }
}
static NSString *PXTargetRegionGPSPath(void) { return gGPSPath; }
static void PXRPost(CFNotificationCenterRef center, CFStringRef name, const void *object, CFDictionaryRef info, Boolean immediately) {
    (void)center; (void)name; (void)object; (void)info; (void)immediately;
    __atomic_fetch_add(&gNotices, 1, __ATOMIC_RELAXED);
}
#define CFNotificationCenterGetDarwinNotifyCenter() ((CFNotificationCenterRef)(uintptr_t)1)
#define CFNotificationCenterPostNotification PXRPost
#include "PXRegionLifecycleHelpers.inc"
#undef CFNotificationCenterPostNotification
#undef CFNotificationCenterGetDarwinNotifyCenter

@interface IPStatusCacheManager : NSObject
+ (void)savePinnedLocation:(CLLocationCoordinate2D)coordinate countryCode:(NSString *)country flagEmoji:(NSString *)flag timestamp:(NSDate *)date;
@end
@implementation IPStatusCacheManager
+ (void)savePinnedLocation:(CLLocationCoordinate2D)coordinate countryCode:(NSString *)country flagEmoji:(NSString *)flag timestamp:(NSDate *)date {
    (void)coordinate; (void)country; (void)flag; (void)date;
    @synchronized(gGuard) { gCacheWrites++; }
}
@end
@interface PXRControl : NSObject
@property (nonatomic, getter=isOn) BOOL on;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end
@implementation PXRControl
- (void)setOn:(BOOL)on animated:(BOOL)animated { (void)animated; CHECK(NSThread.isMainThread, "toggle acknowledgement uses main"); self.on = on; }
@end
@interface PXRController : NSObject
@property (nonatomic, strong) PXTargetRegionSync *targetRegionSync;
@property (nonatomic, strong) PXRControl *targetRegionFollowsIPToggleSwitch;
@property (nonatomic, copy) NSString *toast;
- (void)syncTargetRegionFromIPTapped:(id)sender;
- (void)targetRegionFollowsIPToggleChanged:(PXRControl *)sender;
- (NSDictionary *)applyTargetRegionResponse:(NSDictionary *)json;
- (BOOL)persistPinnedTargetRegionFromResponse:(NSDictionary *)json error:(NSError **)error;
- (void)publishTargetRegionChanged;
- (void)showToastWithMessage:(NSString *)message;
@end
@implementation PXRController
- (instancetype)init { if ((self = [super init])) _targetRegionFollowsIPToggleSwitch = [PXRControl new]; return self; }
- (void)showToastWithMessage:(NSString *)message { CHECK(NSThread.isMainThread, "toast feedback uses main"); self.toast = message; }
- (BOOL)persistPinnedTargetRegionFromResponse:(NSDictionary *)json error:(NSError **)error {
    (void)json;
    if (NSThread.isMainThread) __atomic_fetch_add(&gFailures, 1, __ATOMIC_RELAXED);
    if (gBlockSync) { dispatch_semaphore_signal(gEntered); dispatch_semaphore_wait(gProceed, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)); }
    @synchronized(gGuard) {
        if (gFailSync) { if (error) *error = [NSError errorWithDomain:@"fixture" code:2 userInfo:nil]; return NO; }
        gEnabled = YES; [gEffects addObject:@"sync"]; return YES;
    }
}
#define UISwitch PXRControl
#include "PXRegionLifecycleAdapters.inc"
#undef UISwitch
@end

static BOOL PXRWait(BOOL (^condition)(void)) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3];
    while (deadline.timeIntervalSinceNow > 0) {
        if (condition()) return YES;
        @autoreleasepool { CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.005, YES); }
    }
    return condition();
}
static void PXRFlush(PXTargetRegionSync *sync) {
    NSUInteger before = gFences;
    dispatch_async(sync.workQueue, ^{ dispatch_async(dispatch_get_main_queue(), ^{ gFences++; }); });
    CHECK(PXRWait(^BOOL { return gFences == before + 1; }), "ordered region worker and main feedback drain");
}
static NSDictionary *PXRResponse(void) {
    return @{ @"status": @"success", @"countryCode": @"VN", @"lat": @10.75, @"lon": @106.5, @"timezone": @"Asia/Ho_Chi_Minh", @"query": @"203.0.113.1" };
}
static void PXRReply(PXRSession *session, id json, NSError *error) {
    NSData *data = json ? [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingFragmentsAllowed error:NULL] : nil;
    NSUInteger before = gReplies;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        session.task.completion(data, nil, error);
        dispatch_async(dispatch_get_main_queue(), ^{ gReplies++; });
    });
    CHECK(PXRWait(^BOOL { return gReplies == before + 1; }), "transport response and main admission drain");
}
static void PXRReset(void) {
    @synchronized(gGuard) { gEnabled = NO; gFailSync = NO; gFailToggle = NO; gBlockSync = NO; gCacheWrites = 0; [gEffects removeAllObjects]; }
    gNotices = 0; [NSFileManager.defaultManager removeItemAtPath:gGPSPath error:NULL];
}

static void PXRTestRequestsAndEffects(void) {
    PXRReset(); PXRController *controller = [PXRController new];
    [controller syncTargetRegionFromIPTapped:nil]; PXRSession *old = gSessions.lastObject;
    [controller syncTargetRegionFromIPTapped:nil]; PXRSession *current = gSessions.lastObject;
    CHECK(old.cancellations == 1 && current.task.resumes == 1 && current.config.timeoutIntervalForRequest == 10 &&
        current.config.timeoutIntervalForResource == 15 && [current.task.url.host isEqual:@"ip-api.com"], "sync policy preserved and older request cancelled");
    PXRReply(old, PXRResponse(), nil); PXRFlush(controller.targetRegionSync);
    CHECK(gEffects.count == 0 && gCacheWrites == 0 && gNotices == 0, "stale sync response cannot write source GPS cache or notifications");
    PXRReply(current, PXRResponse(), nil); PXRFlush(controller.targetRegionSync);
    NSDictionary *gps = [NSDictionary dictionaryWithContentsOfFile:gGPSPath];
    CHECK(gEnabled && controller.targetRegionFollowsIPToggleSwitch.isOn && gEffects.count == 1 && gCacheWrites == 1 && gNotices == 3 &&
        [gps[@"GPSSpoofingToggleEnabled"] boolValue] && [controller.toast hasPrefix:@"Pinned VN"], "exact sync adapter commits before compatibility effects and main feedback");
    PXRReply(current, PXRResponse(), nil); PXRFlush(controller.targetRegionSync);
    CHECK(current.finishes == 1 && gEffects.count == 1 && gCacheWrites == 1, "duplicate sync completion has no repeated effects");
    PXRReset(); [controller syncTargetRegionFromIPTapped:nil]; old = gSessions.lastObject;
    controller.targetRegionFollowsIPToggleSwitch.on = NO;
    [controller targetRegionFollowsIPToggleChanged:controller.targetRegionFollowsIPToggleSwitch];
    PXRReply(old, PXRResponse(), nil); PXRFlush(controller.targetRegionSync);
    CHECK(!gEnabled && !controller.targetRegionFollowsIPToggleSwitch.isOn && gCacheWrites == 0 &&
        [gEffects isEqual:@[@"toggle-off"]], "toggle invalidates pending sync before any apply effects");
}

static void PXRTestInFlightAndFailure(void) {
    PXRReset(); PXRController *controller = [PXRController new];
    gBlockSync = YES; gEntered = dispatch_semaphore_create(0); gProceed = dispatch_semaphore_create(0);
    [controller syncTargetRegionFromIPTapped:nil];
    PXRReply(gSessions.lastObject, PXRResponse(), nil);
    CHECK(PXRWait(^BOOL { return dispatch_semaphore_wait(gEntered, DISPATCH_TIME_NOW) == 0; }), "sync apply admitted on worker without blocking main");
    controller.targetRegionFollowsIPToggleSwitch.on = NO;
    [controller targetRegionFollowsIPToggleChanged:controller.targetRegionFollowsIPToggleSwitch];
    dispatch_semaphore_signal(gProceed); PXRFlush(controller.targetRegionSync); gBlockSync = NO;
    CHECK((!gEnabled && !controller.targetRegionFollowsIPToggleSwitch.isOn && [gEffects isEqual:@[@"sync", @"toggle-off"]] &&
        ![controller.toast hasPrefix:@"Pinned"]), "in-flight sync finishes before newer disable and cannot resurrect UI");
    PXRReset(); gFailSync = YES;
    [controller syncTargetRegionFromIPTapped:nil]; PXRReply(gSessions.lastObject, PXRResponse(), nil); PXRFlush(controller.targetRegionSync);
    CHECK(!gEnabled && gCacheWrites == 0 && gNotices == 0 && ![NSFileManager.defaultManager fileExistsAtPath:gGPSPath] &&
        [controller.toast hasPrefix:@"Could not"], "failed primary commit suppresses GPS cache notifications and success feedback");
    gFailSync = NO; gEnabled = YES; gFailToggle = YES; controller.targetRegionFollowsIPToggleSwitch.on = NO;
    [controller targetRegionFollowsIPToggleChanged:controller.targetRegionFollowsIPToggleSwitch]; PXRFlush(controller.targetRegionSync);
    CHECK(controller.targetRegionFollowsIPToggleSwitch.isOn && gEnabled && gNotices == 0, "failed toggle restores worker-read previous state on main"); gFailToggle = NO;
}

static void PXRTestQueuedSupersession(void) {
    PXRReset(); PXRController *controller = [PXRController new]; controller.targetRegionSync = [PXTargetRegionSync new];
    dispatch_semaphore_t entered = dispatch_semaphore_create(0), proceed = dispatch_semaphore_create(0);
    dispatch_async(controller.targetRegionSync.workQueue, ^{
        dispatch_semaphore_signal(entered);
        dispatch_semaphore_wait(proceed, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
    });
    CHECK(PXRWait(^BOOL { return dispatch_semaphore_wait(entered, DISPATCH_TIME_NOW) == 0; }), "queued apply barrier entered");
    [controller syncTargetRegionFromIPTapped:nil]; PXRReply(gSessions.lastObject, PXRResponse(), nil);
    controller.targetRegionFollowsIPToggleSwitch.on = NO;
    [controller targetRegionFollowsIPToggleChanged:controller.targetRegionFollowsIPToggleSwitch];
    controller.targetRegionFollowsIPToggleSwitch.on = YES;
    [controller targetRegionFollowsIPToggleChanged:controller.targetRegionFollowsIPToggleSwitch];
    dispatch_semaphore_signal(proceed); PXRFlush(controller.targetRegionSync);
    CHECK((gEnabled && controller.targetRegionFollowsIPToggleSwitch.isOn && gCacheWrites == 0 && gNotices == 3 &&
        [gEffects isEqual:@[@"toggle-on"]]), "queued sync and older toggle are discarded before effects for latest intent");
}

static void PXRTestParsingLifetimeAndDurability(void) {
    PXRReset(); PXRController *controller = [PXRController new];
    for (id bad in @[@[], NSNull.null, @{}, @{ @"status": @"success", @"countryCode": @3 }]) {
        [controller syncTargetRegionFromIPTapped:nil]; PXRReply(gSessions.lastObject, bad, nil); PXRFlush(controller.targetRegionSync);
        CHECK(gEffects.count == 0 && [controller.toast hasPrefix:@"IP geo"], "malformed service response produces no source effects");
    }
    [controller syncTargetRegionFromIPTapped:nil]; PXRReply(gSessions.lastObject, nil, [NSError errorWithDomain:NSURLErrorDomain code:-1 userInfo:nil]);
    CHECK([controller.toast isEqual:@"IP geo fetch failed"], "fetch failure feedback preserved");
    __weak PXRController *weakOwner; PXRSession *pending;
    @autoreleasepool { PXRController *owner = [PXRController new]; weakOwner = owner; [owner syncTargetRegionFromIPTapped:nil]; pending = gSessions.lastObject; }
    CHECK(!weakOwner && pending.cancellations == 1, "pending network does not retain controller and dealloc cancels session");
    PXRReply(pending, PXRResponse(), nil); CHECK(gEffects.count == 0, "deallocated owner drops late sync result");
    dispatch_semaphore_t entered = dispatch_semaphore_create(0), proceed = dispatch_semaphore_create(0);
    @autoreleasepool {
        PXRController *owner = [PXRController new]; weakOwner = owner; owner.targetRegionSync = [PXTargetRegionSync new];
        dispatch_async(owner.targetRegionSync.workQueue, ^{ dispatch_semaphore_signal(entered); dispatch_semaphore_wait(proceed, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)); });
        CHECK(PXRWait(^BOOL { return dispatch_semaphore_wait(entered, DISPATCH_TIME_NOW) == 0; }), "durable setting worker barrier entered");
        owner.targetRegionFollowsIPToggleSwitch.on = YES;
        [owner targetRegionFollowsIPToggleChanged:owner.targetRegionFollowsIPToggleSwitch];
    }
    CHECK(!weakOwner, "queued explicit toggle does not retain controller"); dispatch_semaphore_signal(proceed);
    CHECK(PXRWait(^BOOL { @synchronized(gGuard) { return gEnabled; } }), "detached explicit toggle persists after UI owner release");
    // Drain its publication before resetting shared test counters.
    CHECK(PXRWait(^BOOL { return __atomic_load_n(&gNotices, __ATOMIC_RELAXED) == 3; }), "durable toggle publishes its committed setting");
    NSUInteger before = gSessions.count;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ [controller syncTargetRegionFromIPTapped:nil]; });
    CHECK(PXRWait(^BOOL { return gSessions.count > before; }), "background sync entry reaches main asynchronously");
}

int main(void) {
    @autoreleasepool {
        gGuard = [NSObject new]; gEffects = [NSMutableArray new]; gSessions = [NSMutableArray new];
        NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
        gGPSPath = [directory stringByAppendingPathComponent:@"gps.plist"];
        PXRTestRequestsAndEffects(); PXRTestInFlightAndFailure(); PXRTestQueuedSupersession(); PXRTestParsingLifetimeAndDurability();
        [NSFileManager.defaultManager removeItemAtPath:directory error:NULL];
        fprintf(stderr, "TargetRegion lifecycle: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
