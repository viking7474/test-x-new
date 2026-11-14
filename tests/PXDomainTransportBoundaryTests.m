#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CFNetwork/CFNetwork.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#import <netdb.h>
#import <errno.h>
#import <string.h>
#import "PXDomainTaskBlocker.h"
#include <stdio.h>
#include <stdlib.h>
static NSUInteger checks, failures, bundleReads, scopeReads, settingsReads, reloads, nativeCalls[14], dnsCalls[3], observed;
static BOOL policyThrows, bundleThrows, scopeThrows, reloadThrows, originalThrows, observeThrows, afterThrows, failURL, messageThrows, streamThrows;
static BOOL blockEnabled = YES, blockLoopback;
static id scopePacket;
static id nativeResult, lastA, lastB, lastC;
static NSURLRequest *lastCFRequest;
static NSString *lastCFMethod, *lastCFVersion;
static NSUInteger messageCalls, streamCalls;
static dispatch_block_t delayedJob;
static double delaySeconds;
static PXDomainTaskBlockPredicate observedPredicate;
static void (*policyAction)(void);
#define CHECK(value, label) do { checks++; if (!(value)) { failures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
static void Raise(void) { [NSException raise:@"fixture" format:@"fault"]; }
@interface DomainBlockingSettings : NSObject
+ (instancetype)sharedSettings;
- (BOOL)isDomainBlocked:(NSString *)host;
- (BOOL)loadSettings;
@end
@implementation DomainBlockingSettings
+ (instancetype)sharedSettings { static DomainBlockingSettings *settings; if (!settings) settings = [DomainBlockingSettings new]; return settings; }
- (BOOL)isDomainBlocked:(NSString *)host {
    settingsReads++; errno = EACCES; h_errno = NO_RECOVERY;
    void (*callback)(void) = policyAction; policyAction = NULL; if (callback) callback();
    if (policyThrows) Raise();
    return blockEnabled && ([host isEqualToString:@"blocked.example"] || (blockLoopback && [host isEqualToString:@"127.0.0.1"]));
}
- (BOOL)loadSettings { reloads++; if (reloadThrows) Raise(); return YES; }
@end
@interface PXBundleShim : NSObject
- (NSString *)bundleIdentifier;
@end
@implementation PXBundleShim
- (NSString *)bundleIdentifier { bundleReads++; if (bundleThrows) Raise(); return @"fixture.app"; }
@end
static NSBundle *PXFixtureMainBundle(void) { static PXBundleShim *bundle; if (!bundle) bundle = [PXBundleShim new]; return (id)bundle; }
static NSDictionary *PXScopedAppsSnapshot(void) { scopeReads++; errno = EPERM; h_errno = NO_RECOVERY; if (scopeThrows) Raise(); return scopePacket; }
#include "PXDomainPolicyState.inc"
#include "PXDomainPolicyWork.inc"

static NSUInteger validationReads;
@interface PXReenteringDomain : NSObject @end
@implementation PXReenteringDomain
- (BOOL)isKindOfClass:(Class)type {
    (void)type; validationReads++;
    (void)shouldBlockDomain((id)self);
    return NO;
}
@end

static int inputErrno, inputHostError, nativeEAI;
static const char *lastHostname, *lastService;
static const struct addrinfo *lastHints;
static struct addrinfo addressResult;
static struct hostent hostResult;
static BOOL unterminatedHost;
static struct hostent *NativeHost(const char *name) {
    dnsCalls[0]++; lastHostname = name; inputErrno = errno; inputHostError = h_errno;
    if (originalThrows) Raise(); errno = EINTR; h_errno = TRY_AGAIN; return &hostResult;
}
static int NativeAddress(const char *host, const char *service, const struct addrinfo *hints, struct addrinfo **result) {
    dnsCalls[1]++; lastHostname = host; lastService = service; lastHints = hints; inputErrno = errno; inputHostError = h_errno;
    if (originalThrows) Raise(); if (!nativeEAI && result) *result = &addressResult;
    errno = EINTR; h_errno = TRY_AGAIN; return nativeEAI;
}
static int NativeName(const struct sockaddr *sa, socklen_t length, char *host, socklen_t hostLength, char *service, socklen_t serviceLength, int flags) {
    (void)sa; (void)length; (void)flags; dnsCalls[2]++;
    if (originalThrows) Raise();
    if (!nativeEAI) {
        if (host && hostLength) { if (unterminatedHost) memset(host, 'x', hostLength); else snprintf(host, hostLength, "%s", "blocked.example"); }
        if (service && serviceLength) snprintf(service, serviceLength, "%s", "443");
    }
    errno = EINTR; h_errno = TRY_AGAIN; return nativeEAI;
}
BOOL PXDomainObserveURLSession(NSURLSession *session, PXDomainTaskBlockPredicate predicate) {
    @try { observed++; if (observeThrows) Raise(); observedPredicate = [predicate copy]; return session != nil; }
    @finally { session = nil; predicate = nil; }
}
static void PXFixtureAfter(double seconds, dispatch_block_t block) {
    @try { if (afterThrows) Raise(); delaySeconds = seconds; delayedJob = [block copy]; }
    @finally { block = nil; }
}
#include "PXDomainTransportHelpers.inc"
static id PXOrig(NSUInteger kind, id __unsafe_unretained a, id __unsafe_unretained b, id __unsafe_unretained c) {
    nativeCalls[kind]++; if (originalThrows) Raise(); lastA = a; lastB = b; lastC = c; return nativeResult;
}
static id PXOrigInit(id __unsafe_unretained object, NSURLRequest *__unsafe_unretained request, id __unsafe_unretained delegate) { (void)PXOrig(9, request, delegate, nil); return object; }
static NSData *PXOrigSync(NSURLRequest *__unsafe_unretained request, NSURLResponse **response, NSError **error) {
    (void)response; (void)error; return PXOrig(7, request, nil, nil);
}
static void PXOrigAsync(NSURLRequest *__unsafe_unretained request, NSOperationQueue *__unsafe_unretained queue, void (^ __unsafe_unretained handler)(NSURLResponse *, NSData *, NSError *)) { (void)PXOrig(8, request, queue, handler); }
static CFHostRef PXOrigCFHost(CFStringRef name) { nativeCalls[0]++; if (originalThrows) Raise(); return name ? CFHostCreateWithName(NULL, name) : NULL; }
@interface WKNavigation : NSObject @end
@implementation WKNavigation @end
@interface PXDomainFixture : NSObject
#include "PXDomainTransportDeclarations.inc"
@end
@implementation PXDomainFixture
#include "PXDomainTransportMethods.inc"
@end
static CFURLRef PXFixtureBlockURL(CFAllocatorRef alloc, CFStringRef text, CFURLRef base) { return failURL ? NULL : CFURLCreateWithString(alloc, text, base); }
static CFHTTPMessageRef PXOrigMessage(CFAllocatorRef alloc, CFStringRef method, CFURLRef url, CFStringRef version) {
    messageCalls++; if (originalThrows || messageThrows) Raise();
    lastCFRequest = url ? [NSURLRequest requestWithURL:(__bridge NSURL *)url] : nil;
    lastCFMethod = (__bridge NSString *)method; lastCFVersion = (__bridge NSString *)version;
    return (url && method && version) ? CFHTTPMessageCreateRequest(alloc, method, url, version) : NULL;
}
static CFReadStreamRef PXOrigStream(CFAllocatorRef alloc, CFHTTPMessageRef request) {
    (void)alloc; streamCalls++; if (originalThrows || streamThrows) Raise();
    CFURLRef url = request ? CFHTTPMessageCopyRequestURL(request) : NULL;
    lastCFRequest = url ? [NSURLRequest requestWithURL:(__bridge NSURL *)url] : nil;
    if (url) CFRelease(url);
    return CFReadStreamCreateWithBytesNoCopy(NULL, (const UInt8 *)"ok", 2, kCFAllocatorNull);
}
#include "PXDomainCFMethods.inc"
@interface PXManualQueue : NSOperationQueue
@property (nonatomic, copy) dispatch_block_t pending;
@property (nonatomic) BOOL rejectEnqueue;
- (void)fire;
@end
@implementation PXManualQueue
- (void)addOperationWithBlock:(void (^)(void))block {
    @try { if (self.rejectEnqueue) Raise(); self.pending = block; }
    @finally { block = nil; }
}
- (void)fire {
    dispatch_block_t block = nil;
    @try { block = self.pending; self.pending = nil; if (block) block(); }
    @finally { block = nil; }
}
@end
static void FireDelay(void) {
    dispatch_block_t job = nil;
    @try { job = delayedJob; delayedJob = nil; if (job) job(); }
    @finally { job = nil; }
}
static void Reset(void) {
    policyThrows = bundleThrows = scopeThrows = reloadThrows = originalThrows = observeThrows = afterThrows = failURL = messageThrows = streamThrows = NO;
    blockEnabled = YES; blockLoopback = NO; policyAction = NULL; nativeEAI = 0; unterminatedHost = NO;
    gPXDomainEvaluating = gPXDomainRedirecting = NO;
    scopePacket = @{@"fixture.app": @{@"enabled": @YES}};
    bundleReads = scopeReads = settingsReads = observed = reloads = 0;
    memset(nativeCalls, 0, sizeof(nativeCalls)); memset(dnsCalls, 0, sizeof(dnsCalls));
    nativeResult = [NSObject new]; lastA = lastB = lastC = nil;
    lastCFRequest = nil; lastCFMethod = lastCFVersion = nil; delayedJob = nil; observedPredicate = nil;
    original_gethostbyname = NativeHost; original_getaddrinfo = NativeAddress; original_getnameinfo = NativeName;
}
static NSURLRequest *Request(BOOL blocked) { return [NSURLRequest requestWithURL:[NSURL URLWithString:blocked ? @"https://blocked.example/path" : @"https://allowed.example/path"]]; }
static void ReenterDNS(void) { struct addrinfo *out = NULL; (void)hooked_getaddrinfo("blocked.example", "443", NULL, &out); }
static void DNSTests(void) {
    Reset(); struct addrinfo *out = (void *)0x1234;
    errno = E2BIG; h_errno = HOST_NOT_FOUND;
    CHECK(hooked_getaddrinfo("blocked.example", "443", NULL, &out) == EAI_NONAME && !out && dnsCalls[1] == 0, "blocked getaddrinfo clears only valid output slot and avoids native resolution");
    CHECK(errno == E2BIG && h_errno == HOST_NOT_FOUND && bundleReads == 1 && scopeReads == 1 && settingsReads == 1, "blocking policy preserves ambient errors and reads identity/scope once");
    CHECK(hooked_getaddrinfo("blocked.example", NULL, NULL, NULL) == EAI_NONAME, "blocked getaddrinfo tolerates absent output slot");
    blockEnabled = NO; errno = E2BIG; h_errno = HOST_NOT_FOUND;
    CHECK(hooked_getaddrinfo("allowed.example", "80", &addressResult, &out) == 0 && out == &addressResult, "allowed resolver preserves native result pointer");
    CHECK(inputErrno == E2BIG && inputHostError == HOST_NOT_FOUND && errno == EINTR && h_errno == TRY_AGAIN && lastHints == &addressResult && strcmp(lastService,"80") == 0, "allowed resolver preserves arguments input and output error state");
    nativeEAI = EAI_AGAIN; out = (void *)0x1234;
    CHECK(hooked_getaddrinfo(NULL, "80", NULL, &out) == EAI_AGAIN && out == (void *)0x1234 && lastHostname == NULL, "native error and nil hostname preserve original output behavior");
    nativeEAI = 0; const char bad[] = {(char)0xff, 0}; NSUInteger before = scopeReads;
    (void)hooked_getaddrinfo(bad, "80", NULL, &out);
    CHECK(lastHostname == bad && scopeReads == before, "invalid UTF8 goes native without policy providers");
    blockEnabled = YES; errno = E2BIG;
    CHECK(!hooked_gethostbyname("blocked.example") && h_errno == HOST_NOT_FOUND && errno == E2BIG, "legacy blocked host preserves errno and sets HOST_NOT_FOUND");
    policyThrows = YES; CHECK(hooked_gethostbyname("blocked.example") == &hostResult && !gPXDomainEvaluating, "policy exception falls through to native legacy resolver and restores guard");
    policyThrows = NO; policyAction = ReenterDNS; before = settingsReads;
    (void)hooked_getaddrinfo("blocked.example", "443", NULL, &out);
    CHECK(settingsReads == before + 1 && dnsCalls[1] > 0 && !gPXDomainEvaluating, "policy callback reentry uses native without recursive settings lookup");
    char host[64] = {0}, service[16] = {0}; errno = 0;
    CHECK(hooked_getnameinfo(NULL, 0, host, sizeof(host), service, sizeof(service), 0) == EAI_NONAME && !host[0] && strcmp(service,"443") == 0, "reverse denial clears hostname only after native success");
    CHECK(errno == EINTR && h_errno == TRY_AGAIN, "reverse policy does not clobber native error state");
    char bounded[20]; memset(bounded,'z',sizeof(bounded)); bounded[19] = 0; unterminatedHost = YES; before = scopeReads;
    CHECK(hooked_getnameinfo(NULL,0,bounded,12,NULL,0,0) == 0 && bounded[12] == 'z' && scopeReads == before, "unterminated reverse result is not scanned past hostlen");
    unterminatedHost = NO; nativeEAI = EAI_AGAIN; before = scopeReads;
    CHECK(hooked_getnameinfo(NULL,0,host,sizeof(host),NULL,0,0) == EAI_AGAIN && scopeReads == before, "failed reverse resolution never enters policy");
    original_getaddrinfo = NULL; original_getnameinfo = NULL; original_gethostbyname = NULL; blockEnabled = NO;
    CHECK(hooked_getaddrinfo("allowed.example",NULL,NULL,&out) == EAI_SYSTEM && errno == ENOSYS && !out, "missing getaddrinfo original reports ENOSYS safely");
    CHECK(hooked_getnameinfo(NULL,0,host,sizeof(host),NULL,0,0) == EAI_SYSTEM && errno == ENOSYS, "missing reverse original reports ENOSYS");
    CHECK(!hooked_gethostbyname("allowed.example") && errno == ENOSYS && h_errno == NO_RECOVERY, "missing legacy original reports NO_RECOVERY");
    Reset(); originalThrows = YES; BOOL caught = NO;
    @try { (void)hooked_getaddrinfo("allowed.example",NULL,NULL,&out); } @catch (__unused NSException *e) { caught = YES; }
    CHECK(caught && dnsCalls[1] == 1, "native resolver exception is not swallowed or replayed");
}
static void PolicyTests(void) {
    Reset(); CHECK(!shouldBlockDomain(nil) && !shouldBlockDomain((id)@[]) && !shouldBlockDomain(@"") && !scopeReads, "empty/malformed domain skips all scope/settings work");
    validationReads = 0;
    CHECK(!shouldBlockDomain((id)[PXReenteringDomain new]) && validationReads == 1 && !gPXDomainEvaluating && !scopeReads, "policy guard covers foreign host validation before provider work");
    NSArray *bad = @[@[], @{}, @{@"fixture.app": @[]}, @{@"fixture.app": @{@"enabled": @[]}}, @{@"fixture.app": @{@"enabled": @NO}}];
    for (id packet in bad) { scopePacket = packet; CHECK(!shouldBlockDomain(@"blocked.example") && !settingsReads, "missing/malformed/disabled scope never instantiates settings decision"); }
    Reset(); scopeThrows = YES; CHECK(!shouldBlockDomain(@"blocked.example") && !gPXDomainEvaluating, "scope fault is fail-open with TLS restored");
    Reset(); bundleThrows = YES; CHECK(!shouldBlockDomain(@"blocked.example") && !scopeReads, "identity fault avoids scope and matcher");
    Reset(); reloadThrows = YES; domainBlockingSettingsChanged(NULL,NULL,NULL,NULL,NULL);
    CHECK(reloads == 1, "notification reload exception is contained");
    reloadThrows = NO; domainBlockingSettingsChanged(NULL,NULL,NULL,NULL,NULL); CHECK(reloads == 2, "reload remains usable after exception");
}
static void FactoryTests(void) {
    Reset(); CFHostRef host = [PXDomainFixture createWithName:CFSTR("blocked.example")];
    CHECK(!host && !nativeCalls[0], "CFHost denial preserves null without native factory");
    host = [PXDomainFixture createWithName:CFSTR("allowed.example")]; CHECK(host && nativeCalls[0] == 1, "CFHost allowance returns native owned result"); if (host) CFRelease(host);
    CHECK(![PXDomainFixture hostWithName:@"blocked.example"] && [PXDomainFixture hostWithAddress:@"127.0.0.1"] == nativeResult, "NSHost name policy and address passthrough stay distinct");
    CHECK(![PXDomainFixture endpointWithHost:@"blocked.example" port:@"443"] && [PXDomainFixture endpointWithHost:@"allowed.example" port:@"443"] == nativeResult, "endpoint host/port policy preserves native allowance");
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration]; NSOperationQueue *queue = [NSOperationQueue new]; NSObject *delegate = [NSObject new];
    CHECK([PXDomainFixture sharedSession] == nativeResult && [PXDomainFixture sessionWithConfiguration:config] == nativeResult &&
        [PXDomainFixture sessionWithConfiguration:config delegate:(id)delegate delegateQueue:queue] == nativeResult && observed == 3, "three session constructors preserve native objects and observe once");
    CHECK(lastA == config && lastB == delegate && lastC == queue, "session constructor arguments remain unchanged");
    CHECK(observedPredicate(@"blocked.example"), "session predicate uses current policy"); blockEnabled = NO;
    CHECK(!observedPredicate(@"blocked.example"), "stored session predicate honors later disable");
    observeThrows = YES; CHECK([PXDomainFixture sharedSession] == nativeResult, "observer failure cannot negate native constructor success");
    originalThrows = YES; NSUInteger before = nativeCalls[4]; BOOL caught = NO;
    @try { (void)[PXDomainFixture sharedSession]; } @catch (__unused NSException *e) { caught = YES; }
    CHECK(caught && nativeCalls[4] == before + 1, "native session constructor exception propagates once");
}
static void WebLegacyTests(void) {
    Reset(); NSURLRequest *blocked = Request(YES), *allowed = Request(NO);
    NSError *error = nil; NSURLResponse *response = (id)nativeResult;
    CHECK(![PXDomainFixture sendSynchronousRequest:blocked returningResponse:&response error:&error] && !response && error.code == NSURLErrorCannotFindHost && !nativeCalls[7], "blocked synchronous legacy request preserves error tuple");
    CHECK([PXDomainFixture sendSynchronousRequest:allowed returningResponse:NULL error:NULL] == nativeResult && lastA == allowed, "allowed synchronous request preserves original argument/result");
    PXDomainFixture *connection = [[PXDomainFixture alloc] initWithRequest:blocked delegate:nativeResult];
    CHECK(connection && [((NSURLRequest *)lastA).URL.absoluteString isEqual:@"https://127.0.0.1:1"] && [blocked.URL.host isEqual:@"blocked.example"], "legacy init redirects a copy without mutating caller request");
    PXDomainFixture *view = [PXDomainFixture new];
    CHECK([view loadRequest:blocked] == nativeResult && [((NSURLRequest *)lastA).URL.absoluteString isEqual:@"about:blank"], "WebKit request block keeps blank-page behavior");
    NSURL *base = blocked.URL;
    CHECK([view loadHTMLString:@"html" baseURL:base] == nativeResult && [lastA isEqual:@"html"] && [((NSURL *)lastB).absoluteString isEqual:@"https://127.0.0.1:1"], "HTML block preserves content and loopback base");
    NSUInteger fileBefore = nativeCalls[12], requestBefore = nativeCalls[10];
    CHECK([view loadFileURL:base allowingReadAccessToURL:allowed.URL] == nativeResult && nativeCalls[12] == fileBefore && nativeCalls[10] == requestBefore + 1, "blocked file load still delegates to blank loadRequest");
    nativeResult = blocked; CHECK([[view request].URL.absoluteString isEqual:@"https://127.0.0.1:1"], "navigation action keeps loopback request projection");
    nativeResult = [WKNavigation new]; policyThrows = YES;
    CHECK([view loadRequest:blocked] == nativeResult && lastA == blocked, "policy failure preserves raw WebKit request");
    policyThrows = NO; originalThrows = YES; BOOL caught = NO; requestBefore = nativeCalls[10];
    @try { (void)[view loadRequest:allowed]; } @catch (__unused NSException *e) { caught = YES; }
    CHECK(caught && nativeCalls[10] == requestBefore + 1, "WebKit native exception does not retry a load");
    connection = nil; view = nil;
}
static void AsyncTests(void) {
    Reset(); PXManualQueue *queue = [PXManualQueue new]; __block NSUInteger calls = 0;
    [PXDomainFixture sendAsynchronousRequest:Request(YES) queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        calls++; CHECK(!response && !data && error.code == NSURLErrorDNSLookupFailed, "blocked callback tuple preserved");
    }];
    CHECK(delayedJob && delaySeconds == 0.2 && !calls && !nativeCalls[8], "blocked async keeps delay and avoids native submission");
    FireDelay(); CHECK(queue.pending && !calls, "delayed job enqueues on caller queue without invoking client inline"); [queue fire];
    CHECK(calls == 1 && !queue.pending && !delayedJob, "caller-queue delivery occurs once");
    NSOperationQueue *real = [NSOperationQueue new]; dispatch_semaphore_t finished = dispatch_semaphore_create(0); __block BOOL correct = NO;
    [PXDomainFixture sendAsynchronousRequest:Request(YES) queue:real completionHandler:^(NSURLResponse *r, NSData *d, NSError *e) {
        (void)r; (void)d; (void)e; correct = [NSOperationQueue currentQueue] == real; dispatch_semaphore_signal(finished);
    }];
    FireDelay(); CHECK(dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0 && correct, "real caller operation queue receives completion"); [real waitUntilAllOperationsAreFinished];
    [PXDomainFixture sendAsynchronousRequest:Request(YES) queue:queue completionHandler:nil]; CHECK(!delayedJob, "nil blocked completion schedules nothing");
    __weak NSObject *weakToken;
    @autoreleasepool {
        NSObject *token = [NSObject new]; weakToken = token;
        void (^client)(NSURLResponse *, NSData *, NSError *) = nil;
        { NSObject *captured = token; client = ^(NSURLResponse *r, NSData *d, NSError *e) { (void)r; (void)d; (void)e; (void)[captured class]; }; }
        [PXDomainFixture sendAsynchronousRequest:Request(YES) queue:queue completionHandler:client]; client = nil; token = nil;
    }
    CHECK(weakToken != nil, "scheduled blocked callback retains client capture until caller queue delivery");
    @autoreleasepool { FireDelay(); [queue fire]; }
    CHECK(!weakToken, "blocked callback releases capture after both scheduling stages and pool drain");
    @autoreleasepool {
        NSObject *token = [NSObject new]; weakToken = token;
        void (^client)(NSURLResponse *, NSData *, NSError *) = nil;
        { NSObject *captured = token; client = ^(NSURLResponse *r, NSData *d, NSError *e) { (void)r; (void)d; (void)e; (void)[captured class]; }; }
        afterThrows = YES; BOOL caught = NO;
        @try { [PXDomainFixture sendAsynchronousRequest:Request(YES) queue:queue completionHandler:client]; }
        @catch (__unused NSException *e) { caught = YES; }
        @finally { client = nil; token = nil; }
        CHECK(caught && !delayedJob && !nativeCalls[8], "scheduling exception propagates without native retry");
    }
    CHECK(!weakToken, "plain ARC scheduling failure releases both block capture layers");
    afterThrows = NO;
    NSURLRequest *allowedRequest = Request(NO);
    void (^allowedClient)(NSURLResponse *, NSData *, NSError *) = [^(NSURLResponse *r, NSData *d, NSError *e) { (void)r; (void)d; (void)e; calls++; } copy];
    [PXDomainFixture sendAsynchronousRequest:allowedRequest queue:queue completionHandler:allowedClient];
    CHECK(nativeCalls[8] == 1 && lastA == allowedRequest && lastB == queue && lastC == allowedClient && !delayedJob, "allowed async preserves original request queue and completion without synthetic scheduling");
    lastA = lastB = lastC = nil; allowedClient = nil; allowedRequest = nil;
    // Remaining cases continue to assert zero native submissions for blocked work.
    nativeCalls[8] = 0;
    @autoreleasepool {
        NSObject *token = [NSObject new]; weakToken = token;
        void (^client)(NSURLResponse *, NSData *, NSError *) = nil;
        { NSObject *captured = token; client = ^(NSURLResponse *r, NSData *d, NSError *e) { (void)r; (void)d; (void)e; (void)[captured class]; }; }
        [PXDomainFixture sendAsynchronousRequest:Request(YES) queue:queue completionHandler:client]; client = nil; token = nil;
        queue.rejectEnqueue = YES; BOOL enqueueCaught = NO;
        @try { FireDelay(); } @catch (__unused NSException *e) { enqueueCaught = YES; }
        queue.rejectEnqueue = NO;
        CHECK(enqueueCaught && !delayedJob && !queue.pending && !nativeCalls[8], "caller queue exception is propagated without callback/native retry");
    }
    CHECK(!weakToken, "queue enqueue failure releases delayed and delivery captures after pool drain");
    [PXDomainFixture sendAsynchronousRequest:Request(YES) queue:queue completionHandler:^(NSURLResponse *r, NSData *d, NSError *e) { (void)r; (void)d; (void)e; calls++; Raise(); }];
    FireDelay(); BOOL caught = NO; @try { [queue fire]; } @catch (__unused NSException *e) { caught = YES; }
    CHECK(caught && calls == 2 && !queue.pending && !nativeCalls[8], "client exception is not swallowed retried or sent through native");
}
static const void *ContextRetain(const void *info) { return (__bridge_retained const void *)(__bridge id)info; }
static void ContextRelease(const void *info) { id object = CFBridgingRelease(info); object = nil; }
static void *ContextAllocate(CFIndex size, CFOptionFlags hints, void *info) { (void)hints; (void)info; return malloc((size_t)size); }
static void *ContextReallocate(void *memory, CFIndex size, CFOptionFlags hints, void *info) { (void)hints; (void)info; return realloc(memory,(size_t)size); }
static void ContextDeallocate(void *memory, void *info) { (void)info; free(memory); }
static CFIndex ContextSize(CFIndex size, CFOptionFlags hints, void *info) { (void)hints; (void)info; return size; }
static void CFTests(void) {
    Reset(); NSURL *url = [NSURL URLWithString:@"https://blocked.example/path"];
    CFHTTPMessageRef input = CFHTTPMessageCreateRequest(NULL, CFSTR("POST"), (__bridge CFURLRef)url, kCFHTTPVersion1_1);
    blockLoopback = YES;
    CFReadStreamRef stream = PXFixtureStream(NULL, input);
    CHECK(stream && streamCalls == 1 && messageCalls == 1 && settingsReads == 1 && !gPXDomainRedirecting, "stream block creates one internal message without repeated loopback policy");
    CHECK([lastCFRequest.URL.absoluteString isEqual:@"https://127.0.0.1:1"] && [url.host isEqual:@"blocked.example"], "CF stream redirect leaves original URL unchanged"); if (stream) CFRelease(stream);
    CFHTTPMessageRef message = PXFixtureMessage(NULL, CFSTR("POST"), (__bridge CFURLRef)url, kCFHTTPVersion1_1);
    CHECK(message && [lastCFMethod isEqual:@"POST"] && [lastCFVersion isEqual:(__bridge NSString *)kCFHTTPVersion1_1] && [lastCFRequest.URL.host isEqual:@"127.0.0.1"], "CF message keeps method/version and changes only target URL"); if (message) CFRelease(message);
    gPXDomainRedirecting = YES; NSUInteger checkedBefore = settingsReads;
    message = PXFixtureMessage(NULL, CFSTR("GET"), (__bridge CFURLRef)url, kCFHTTPVersion1_1);
    CHECK(message && settingsReads == checkedBefore + 1 && [lastCFRequest.URL.host isEqual:@"127.0.0.1"] && gPXDomainRedirecting, "redirect nesting does not bypass policy for a different original target");
    if (message) CFRelease(message); gPXDomainRedirecting = NO;
    failURL = YES; NSUInteger before = streamCalls;
    CHECK(!PXFixtureStream(NULL,input) && streamCalls == before && !gPXDomainRedirecting, "known-blocked stream with no redirect URL returns null without native submission");
    before = messageCalls;
    CHECK(!PXFixtureMessage(NULL,CFSTR("GET"),(__bridge CFURLRef)url,kCFHTTPVersion1_1) && messageCalls == before, "known-blocked message with no redirect URL never releases null or submits real target");
    failURL = NO; policyThrows = YES; stream = PXFixtureStream(NULL,input);
    CHECK(stream && [lastCFRequest.URL.host isEqual:@"blocked.example"], "CF policy failure preserves native original request"); if (stream) CFRelease(stream);
    policyThrows = NO; originalThrows = YES; BOOL caught = NO; before = streamCalls;
    @try { (void)PXFixtureStream(NULL,input); } @catch (__unused NSException *e) { caught = YES; }
    // An internal message constructor can fail before the stream original; blocked prep fails closed.
    CHECK(!caught && streamCalls == before && !gPXDomainRedirecting, "internal CF construction exception is contained after block decision");
    blockEnabled = NO; caught = NO;
    @try { (void)PXFixtureStream(NULL,input); } @catch (__unused NSException *e) { caught = YES; }
    CHECK(caught && streamCalls == before + 1 && !gPXDomainRedirecting, "native CF stream exception propagates once after preparation");
    originalThrows = NO;
    for (int fault = 0; fault < 3; fault++) {
        __weak NSObject *weakContext;
        @autoreleasepool {
            NSObject *token = [NSObject new]; weakContext = token;
            CFAllocatorContext context = {0, (__bridge void *)token, ContextRetain, ContextRelease, NULL, ContextAllocate, ContextReallocate, ContextDeallocate, ContextSize};
            CFAllocatorRef allocator = CFAllocatorCreate(NULL, &context); token = nil;
            CHECK(allocator && weakContext, "custom allocator owns a live context for the cleanup oracle");
            lastCFRequest = nil; lastCFMethod = lastCFVersion = nil;
            blockEnabled = YES; messageThrows = fault != 1; streamThrows = fault == 1;
            BOOL nativeCaught = NO;
            @try {
                if (fault == 2) (void)PXFixtureMessage(allocator, CFSTR("POST"), (__bridge CFURLRef)url, kCFHTTPVersion1_1);
                else (void)PXFixtureStream(allocator, input);
            } @catch (__unused NSException *e) { nativeCaught = YES; }
            CHECK(nativeCaught == (fault != 0) && !gPXDomainRedirecting, "CF preparation/native faults have distinct propagation and restore redirect TLS");
            lastCFRequest = nil; lastCFMethod = lastCFVersion = nil;
            if (allocator) CFRelease(allocator);
        }
        CHECK(!weakContext, "CF allocator context releases after all owned temporaries input pins and native faults");
    }
    messageThrows = streamThrows = NO;
    if (input) CFRelease(input);
}
int main(void) {
    @autoreleasepool { DNSTests(); PolicyTests(); }
    @autoreleasepool { FactoryTests(); WebLegacyTests(); }
    @autoreleasepool { AsyncTests(); }
    @autoreleasepool { CFTests(); }
    nativeResult = nil; lastA = lastB = lastC = nil; scopePacket = nil; lastCFRequest = nil; lastCFMethod = lastCFVersion = nil; delayedJob = nil; observedPredicate = nil;
    fprintf(stdout,"Domain transport boundaries: %lu/%lu checks passed\n",(unsigned long)(checks-failures),(unsigned long)checks);
    return failures ? 1 : 0;
}
