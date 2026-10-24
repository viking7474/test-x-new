#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#include <stdatomic.h>
#import "PXDomainTaskBlocker.h"

static NSUInteger gChecks, gFailures;
static atomic_uint gTransportStarts;
static atomic_bool gEnabled;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)

// No socket, DNS or remote server is used by these Foundation fixtures.
@interface PXDomainFixtureTransport : NSURLProtocol
@end
@implementation PXDomainFixtureTransport
+ (BOOL)canInitWithRequest:(NSURLRequest *)request { return [request.URL.host hasSuffix:@".example.test"]; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    atomic_fetch_add(&gTransportStarts, 1);
    NSData *data = [@"fixture" dataUsingEncoding:NSUTF8StringEncoding];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
        statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Length": @"7"}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end

@interface PXDomainCompletion : NSObject <NSURLSessionTaskDelegate>
@property (nonatomic, strong) NSOperationQueue *expectedQueue;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, assign) NSUInteger count;
@property (nonatomic, assign) BOOL correctQueue;
@property (nonatomic, strong) dispatch_semaphore_t signal;
- (void)record:(NSError *)error;
- (BOOL)wait:(NSTimeInterval)seconds;
@end
@implementation PXDomainCompletion
- (instancetype)init {
    if ((self = [super init])) _signal = dispatch_semaphore_create(0);
    return self;
}
- (void)record:(NSError *)error {
    @synchronized(self) {
        self.count++;
        self.error = error;
        self.correctQueue = NSOperationQueue.currentQueue == self.expectedQueue;
    }
    dispatch_semaphore_signal(self.signal);
}
- (BOOL)wait:(NSTimeInterval)seconds {
    return dispatch_semaphore_wait(self.signal, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC))) == 0;
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    (void)session; (void)task;
    [self record:error];
}
@end

static BOOL PXFixtureBlocked(NSString *host) {
    return atomic_load(&gEnabled) && [host isEqualToString:@"blocked.example.test"];
}

static NSURLSession *PXFixtureSession(PXDomainCompletion *completion, BOOL ephemeral, BOOL observe) {
    NSURLSessionConfiguration *config = ephemeral ? NSURLSessionConfiguration.ephemeralSessionConfiguration
                                                : NSURLSessionConfiguration.defaultSessionConfiguration;
    config.protocolClasses = @[PXDomainFixtureTransport.class];
    NSOperationQueue *queue = [NSOperationQueue new];
    queue.maxConcurrentOperationCount = 1;
    queue.name = @"fixture.custom-delegate-queue";
    completion.expectedQueue = queue;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:completion delegateQueue:queue];
    if (observe) {
        CHECK(PXDomainObserveURLSession(session, ^BOOL(NSString *host) { return PXFixtureBlocked(host); }), "observe concrete session");
        CHECK(PXDomainObserveURLSession(session, ^BOOL(NSString *host) { return PXFixtureBlocked(host); }), "observe is idempotent");
    }
    return session;
}

static NSMutableURLRequest *PXFixtureRequest(void) {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://blocked.example.test/resource"]];
    [request setValue:@"unchanged" forHTTPHeaderField:@"X-Fixture"];
    return request;
}

typedef NSURLSessionTask *(^PXFixtureFactory)(NSURLSession *, NSMutableURLRequest *, PXDomainCompletion *);

static void PXCheckBlockedFactories(void) {
    NSData *body = [@"payload" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *file = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".upload"]];
    CHECK([body writeToFile:file atomically:YES], "create upload fixture");
    NSURL *fileURL = [NSURL fileURLWithPath:file];
    NSArray *factories = @[
        ^NSURLSessionTask *(NSURLSession *s, NSMutableURLRequest *r, PXDomainCompletion *c) {
            return [s dataTaskWithRequest:r completionHandler:^(NSData *d, NSURLResponse *response, NSError *error) {
                (void)d; (void)response; [c record:error];
            }];
        },
        ^NSURLSessionTask *(NSURLSession *s, NSMutableURLRequest *r, PXDomainCompletion *c) {
            return [s dataTaskWithURL:r.URL completionHandler:^(NSData *d, NSURLResponse *response, NSError *error) {
                (void)d; (void)response; [c record:error];
            }];
        },
        ^NSURLSessionTask *(NSURLSession *s, NSMutableURLRequest *r, PXDomainCompletion *c) {
            r.HTTPMethod = @"POST";
            return [s uploadTaskWithRequest:r fromData:body completionHandler:^(NSData *d, NSURLResponse *response, NSError *error) {
                (void)d; (void)response; [c record:error];
            }];
        },
        ^NSURLSessionTask *(NSURLSession *s, NSMutableURLRequest *r, PXDomainCompletion *c) {
            r.HTTPMethod = @"POST";
            return [s uploadTaskWithRequest:r fromFile:fileURL completionHandler:^(NSData *d, NSURLResponse *response, NSError *error) {
                (void)d; (void)response; [c record:error];
            }];
        },
        ^NSURLSessionTask *(NSURLSession *s, NSMutableURLRequest *r, PXDomainCompletion *c) {
            return [s downloadTaskWithRequest:r completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
                (void)location; (void)response; [c record:error];
            }];
        },
        ^NSURLSessionTask *(NSURLSession *s, NSMutableURLRequest *r, PXDomainCompletion *c) {
            return [s downloadTaskWithURL:r.URL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
                (void)location; (void)response; [c record:error];
            }];
        },
    ];
    for (NSUInteger i = 0; i < factories.count; i++) {
        @autoreleasepool {
            fprintf(stderr, "Factory fixture %lu (default/ephemeral)\n", (unsigned long)i);
            atomic_store(&gTransportStarts, 0);
            PXDomainCompletion *c = [PXDomainCompletion new];
            NSURLSession *session = PXFixtureSession(c, i % 2, YES);
            NSMutableURLRequest *request = PXFixtureRequest();
            PXFixtureFactory factory = factories[i];
            NSURLSessionTask *task = factory(session, request, c);
            CHECK(task.state == NSURLSessionTaskStateSuspended, "factory returns real suspended task");
            CHECK([task.originalRequest.URL isEqual:request.URL], "task original URL preserved");
            CHECK([request.URL.host isEqualToString:@"blocked.example.test"], "caller request URL preserved");
            CHECK(![c wait:0.12], "no completion without resume");
            CHECK(atomic_load(&gTransportStarts) == 0, "no transport before resume");
            [task resume];
            CHECK([c wait:3], "Foundation completes blocked task");
            CHECK(c.correctQueue, "completion uses session delegate queue");
            CHECK([c.error.domain isEqualToString:NSURLErrorDomain] && c.error.code == NSURLErrorCancelled,
                  "blocked error is genuine cancellation");
            CHECK(task.error.code == c.error.code, "callback error agrees with task.error");
            CHECK(task.state == NSURLSessionTaskStateCompleted, "terminal task state belongs to Foundation");
            CHECK(atomic_load(&gTransportStarts) == 0, "blocked task never starts transport");
            [task resume]; [task cancel];
            CHECK(![c wait:0.08] && c.count == 1, "repeated resume/cancel does not duplicate completion");
            [session invalidateAndCancel];
        }
    }
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
}

static void PXCheckLivePolicyAndUnobservedSessions(void) {
    for (NSUInteger scenario = 0; scenario < 4; scenario++) {
        atomic_store(&gTransportStarts, 0);
        atomic_store(&gEnabled, scenario != 1);
        PXDomainCompletion *c = [PXDomainCompletion new];
        NSURLSession *session = PXFixtureSession(c, YES, scenario != 3);
        NSURLSessionDataTask *task = [session dataTaskWithRequest:PXFixtureRequest()
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                (void)data; (void)response; [c record:error];
            }];
        if (scenario == 0) atomic_store(&gEnabled, NO); // disable after creation
        if (scenario == 1) atomic_store(&gEnabled, YES); // enable after creation
        if (scenario == 2) [task cancel]; // user's cancel, not our factory
        [task resume];
        CHECK([c wait:3], "live policy/cancel completion");
        BOOL cancelled = scenario == 1 || scenario == 2;
        CHECK(cancelled ? c.error.code == NSURLErrorCancelled : c.error == nil,
              "policy evaluated at resume; unobserved sessions pass through");
        CHECK(atomic_load(&gTransportStarts) == (cancelled ? 0 : 1), "live policy transport count");
        CHECK(c.correctQueue && c.count == 1, "live policy preserves queue and callback count");
        [session invalidateAndCancel];
    }
    atomic_store(&gEnabled, YES);
}

static void PXCheckUnblockedSuspendResumeParity(void) {
    atomic_store(&gEnabled, NO);
    for (NSUInteger observed = 0; observed < 2; observed++) {
        PXDomainCompletion *c = [PXDomainCompletion new];
        NSURLSession *session = PXFixtureSession(c, YES, observed != 0);
        NSURLSessionTask *task = [session dataTaskWithURL:PXFixtureRequest().URL
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                (void)data; (void)response; [c record:error];
            }];
        [task suspend];
        CHECK(task.state == NSURLSessionTaskStateSuspended, "unblocked task remains suspended before resume");
        [task resume];
        [task resume];
        CHECK([c wait:3], "unblocked task completes after balanced resume");
        CHECK(c.error == nil && c.correctQueue && c.count == 1, "unblocked suspension preserves callback contract");
        [session invalidateAndCancel];
    }
    atomic_store(&gEnabled, YES);
}

static void PXCheckDelegateAndInvalidation(void) {
    for (NSUInteger invalidate = 0; invalidate < 2; invalidate++) {
        PXDomainCompletion *c = [PXDomainCompletion new];
        NSURLSession *session = PXFixtureSession(c, NO, YES);
        NSURLSessionDataTask *task = [session dataTaskWithURL:PXFixtureRequest().URL];
        if (invalidate) [session invalidateAndCancel];
        else [task resume];
        CHECK([c wait:3], "delegate/invalidation completion");
        CHECK(c.count == 1 && c.correctQueue && c.error.code == NSURLErrorCancelled,
              "delegate-only task uses native cancellation contract");
        [session invalidateAndCancel];
    }
}

static void PXCheckConcurrentTaskCreation(void) {
    PXDomainCompletion *c = [PXDomainCompletion new];
    NSURLSession *session = PXFixtureSession(c, YES, YES);
    atomic_store(&gTransportStarts, 0);
    dispatch_apply(24, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^(size_t index) {
        (void)index;
        @autoreleasepool {
            NSURLSessionTask *task = [session dataTaskWithURL:PXFixtureRequest().URL
                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    (void)data; (void)response; [c record:error];
                }];
            [task resume];
        }
    });
    for (NSUInteger index = 0; index < 24; index++) CHECK([c wait:3], "concurrent task completion");
    CHECK(c.count == 24 && c.correctQueue && c.error.code == NSURLErrorCancelled,
          "concurrent creation preserves Foundation callback count and queue");
    CHECK(atomic_load(&gTransportStarts) == 0, "concurrent blocked tasks never start transport");
    [session invalidateAndCancel];
}

static void PXCheckSuspendedDelegateQueueAndSharedSession(void) {
    PXDomainCompletion *c = [PXDomainCompletion new];
    NSURLSession *session = PXFixtureSession(c, YES, YES);
    c.expectedQueue.suspended = YES;
    NSURLSessionTask *task = [session dataTaskWithURL:PXFixtureRequest().URL
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            (void)data; (void)response; [c record:error];
        }];
    [task resume];
    CHECK(![c wait:0.12], "suspended delegate queue is respected");
    c.expectedQueue.suspended = NO;
    CHECK([c wait:3] && c.correctQueue && c.count == 1, "completion waits for delegate queue to resume");
    [session invalidateAndCancel];

    // Register a test-only catch-all for our reserved fixture host. Production
    // does not register a protocol or replace the Foundation shared singleton.
    [NSURLProtocol registerClass:PXDomainFixtureTransport.class];
    NSURLSession *shared = NSURLSession.sharedSession;
    CHECK(PXDomainObserveURLSession(shared, ^BOOL(NSString *host) { return PXFixtureBlocked(host); }), "observe shared session");
    PXDomainCompletion *sharedCompletion = [PXDomainCompletion new];
    sharedCompletion.expectedQueue = shared.delegateQueue;
    atomic_store(&gTransportStarts, 0);
    NSURLSessionTask *sharedTask = [shared dataTaskWithURL:PXFixtureRequest().URL
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            (void)data; (void)response; [sharedCompletion record:error];
        }];
    CHECK(![sharedCompletion wait:0.12], "shared task has no factory-time callback");
    [sharedTask resume];
    CHECK([sharedCompletion wait:3] && sharedCompletion.error.code == NSURLErrorCancelled,
          "shared task uses Foundation cancellation");
    CHECK(atomic_load(&gTransportStarts) == 0, "shared blocked task never reaches transport");
    [NSURLProtocol unregisterClass:PXDomainFixtureTransport.class];
}

// Test class-local installation, inherited resume/super calls and ABI rejection
// without pretending these doubles can prove Foundation callback semantics.
@interface PXDomainFakeTask : NSObject
@property (nonatomic) NSURLSessionTaskState state;
@property (nonatomic, strong) NSURLRequest *originalRequest;
@property (nonatomic, strong) NSURLRequest *currentRequest;
@property (nonatomic) NSUInteger resumeCount, cancelCount;
- (void)resume;
- (void)cancel;
@end
@implementation PXDomainFakeTask
- (void)resume { self.resumeCount++; }
- (void)cancel { self.cancelCount++; self.state = NSURLSessionTaskStateCanceling; }
@end
@interface PXDomainChildTask : PXDomainFakeTask
@end
@implementation PXDomainChildTask
- (void)resume { [super resume]; }
@end
@interface PXDomainFakeSession : NSObject
@property (nonatomic, strong) PXDomainFakeTask *nextTask;
- (id)dataTaskWithURL:(id)url;
- (id)streamTaskWithHostName:(id)host port:(NSInteger)port;
@end
@implementation PXDomainFakeSession
- (id)dataTaskWithURL:(id)url { (void)url; return self.nextTask; }
- (id)streamTaskWithHostName:(id)host port:(NSInteger)port { (void)host; (void)port; return self.nextTask; }
@end
@interface PXDomainInheritedSession : PXDomainFakeSession
@end
@implementation PXDomainInheritedSession
@end
@interface PXDomainWrongABISession : NSObject
- (double)dataTaskWithURL:(id)url;
@end
@implementation PXDomainWrongABISession
- (double)dataTaskWithURL:(id)url { (void)url; return 1.25; }
@end
@interface PXDomainWrongArgumentSession : NSObject
- (id)dataTaskWithURL:(double)value;
@end
@implementation PXDomainWrongArgumentSession
- (id)dataTaskWithURL:(double)value { return @(value); }
@end

static void PXCheckRuntimeInstallation(void) {
    __block NSUInteger policyCalls = 0;
    PXDomainTaskBlockPredicate predicate = ^BOOL(NSString *host) { policyCalls++; return [host isEqualToString:@"blocked.example.test"]; };
    PXDomainFakeSession *base = [PXDomainFakeSession new];
    base.nextTask = [PXDomainFakeTask new];
    CHECK(PXDomainObserveURLSession((id)base, predicate), "install base fixture");
    PXDomainFakeTask *first = [base streamTaskWithHostName:@"blocked.example.test" port:443];
    CHECK(first == base.nextTask && first.cancelCount == 0, "factory preserves task identity and state");
    [first resume];
    CHECK(first.cancelCount == 1 && first.resumeCount == 1 && policyCalls == 1, "stream hostname policy and original resume exactly once");
    IMP baseFactory = class_getMethodImplementation(base.class, @selector(dataTaskWithURL:));
    PXDomainInheritedSession *child = [PXDomainInheritedSession new];
    child.nextTask = [PXDomainChildTask new];
    child.nextTask.originalRequest = PXFixtureRequest();
    CHECK(PXDomainObserveURLSession((id)child, predicate), "install inherited fixture");
    CHECK(class_getMethodImplementation(base.class, @selector(dataTaskWithURL:)) == baseFactory,
          "inherited factory installation does not overwrite superclass");
    [child dataTaskWithURL:PXFixtureRequest().URL];
    policyCalls = 0;
    [child.nextTask resume];
    CHECK(child.nextTask.cancelCount == 1 && child.nextTask.resumeCount == 1 && policyCalls == 1,
          "override calling super does not re-evaluate policy or cancel twice");
    PXDomainWrongABISession *wrong = [PXDomainWrongABISession new];
    IMP original = class_getMethodImplementation(wrong.class, @selector(dataTaskWithURL:));
    CHECK(!PXDomainObserveURLSession((id)wrong, predicate), "reject mismatched return ABI");
    CHECK(class_getMethodImplementation(wrong.class, @selector(dataTaskWithURL:)) == original &&
          [wrong dataTaskWithURL:nil] == 1.25, "ABI rejection preserves original method");
    PXDomainWrongArgumentSession *wrongArgument = [PXDomainWrongArgumentSession new];
    CHECK(!PXDomainObserveURLSession((id)wrongArgument, predicate) &&
          [[wrongArgument dataTaskWithURL:2.5] isEqual:@2.5], "reject scalar argument in object factory");

    __weak id releasedTask, releasedSession;
    @autoreleasepool {
        PXDomainFakeSession *temporary = [PXDomainFakeSession new];
        temporary.nextTask = [PXDomainFakeTask new];
        PXDomainObserveURLSession((id)temporary, ^BOOL(NSString *host) { (void)host; return NO; });
        [temporary dataTaskWithURL:nil];
        releasedTask = temporary.nextTask;
        releasedSession = temporary;
        temporary.nextTask = nil;
    }
    CHECK(releasedTask == nil && releasedSession == nil, "hook registry does not retain task/session instances");
}

int main(void) {
    @autoreleasepool {
        atomic_store(&gEnabled, YES);
        PXCheckRuntimeInstallation();
        PXCheckBlockedFactories();
        PXCheckLivePolicyAndUnobservedSessions();
        PXCheckUnblockedSuspendResumeParity();
        PXCheckDelegateAndInvalidation();
        PXCheckConcurrentTaskCreation();
        PXCheckSuspendedDelegateQueueAndSharedSession();
        fprintf(stderr, "Domain task lifecycle: %lu/%lu checks passed\n",
                (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
