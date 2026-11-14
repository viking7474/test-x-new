#import "DomainBlockingSettings.h"
#import <Foundation/Foundation.h>
#import <CFNetwork/CFNetwork.h>
#import <errno.h>
#import <string.h>
#import <sys/socket.h>
#import <netdb.h>
#import <arpa/inet.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <substrate.h>
// #import <ellekit/ellekit.h> // Removed for rootful - using Substrate
#import <WebKit/WebKit.h>
#import <SafariServices/SafariServices.h>
#import "TLinkIOSLogging.h"
#import "PXScope.h"
#import "PXDomainTaskBlocker.h"



// Use the active SDK's resolver types, including Darwin socklen_t buffer lengths.
static __typeof__(&gethostbyname) original_gethostbyname;
static __typeof__(&getaddrinfo) original_getaddrinfo;
static __typeof__(&getnameinfo) original_getnameinfo;
static __thread BOOL gPXDomainEvaluating;
static __thread BOOL gPXDomainRedirecting;

static NSString *getCurrentBundleID(void);
static BOOL shouldBlockDomain(NSString *host);

static void domainBlockingSettingsChanged(CFNotificationCenterRef center,
                                          void *observer,
                                          CFStringRef name,
                                          const void *object,
                                          CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    @autoreleasepool {
        DomainBlockingSettings *settings = nil;
        @try { settings = [DomainBlockingSettings sharedSettings]; [settings loadSettings]; }
        @catch (__unused NSException *exception) { }
        @finally { settings = nil; }
    }
}

#pragma mark - Scoped Apps Helper Functions (Unified)

// Capture identity/scope once per decision. Keep the existing entry.enabled policy.
static NSString *getCurrentBundleID(void) {
    NSBundle *bundle = nil;
    @try { bundle = [NSBundle mainBundle]; return bundle.bundleIdentifier; }
    @catch (__unused NSException *exception) { return nil; }
    @finally { bundle = nil; }
}

static BOOL shouldBlockDomain(NSString *host) {
    NSString *bundleID = nil;
    NSDictionary *scope = nil, *entry = nil;
    id flag = nil;
    DomainBlockingSettings *settings = nil;
    BOOL previous = gPXDomainEvaluating;
    @autoreleasepool {
        @try {
            if (previous) return NO;
            gPXDomainEvaluating = YES;
            if (![host isKindOfClass:NSString.class] || !host.length) return NO;
            bundleID = getCurrentBundleID();
            if (!bundleID.length) return NO;
            scope = PXScopedAppsSnapshot();
            if (![scope isKindOfClass:NSDictionary.class]) return NO;
            entry = scope[bundleID];
            if (![entry isKindOfClass:NSDictionary.class]) return NO;
            flag = entry[@"enabled"];
            if (!([flag isKindOfClass:NSNumber.class] || [flag isKindOfClass:NSString.class]) || ![flag boolValue]) return NO;
            settings = [DomainBlockingSettings sharedSettings];
            return [settings isDomainBlocked:host];
        } @catch (__unused NSException *exception) { return NO; }
        @finally {
            gPXDomainEvaluating = previous;
            host = nil; bundleID = nil; scope = nil; entry = nil; flag = nil; settings = nil;
        }
    }
}

static BOOL shouldBlockHostname(const char *hostname) {
    @autoreleasepool {
        NSString *host = nil;
        @try {
            if (!hostname) return NO;
            host = [NSString stringWithUTF8String:hostname];
            return shouldBlockDomain(host);
        } @catch (__unused NSException *exception) { return NO; }
        @finally { host = nil; }
    }
}

// Reverse lookup output has an explicit bound; do not scan beyond it on a bad native result.
static BOOL PXDomainBlockResolvedHost(const char *hostname, socklen_t length) {
    @autoreleasepool {
        NSString *host = nil;
        @try {
            if (!hostname || !length) return NO;
            const char *end = memchr(hostname, 0, (size_t)length);
            if (!end) return NO;
            host = [[NSString alloc] initWithBytes:hostname length:(NSUInteger)(end - hostname) encoding:NSUTF8StringEncoding];
            return shouldBlockDomain(host);
        } @catch (__unused NSException *exception) { return NO; }
        @finally { host = nil; }
    }
}

// Both helper and adapter callers own named roots across policy failures.
static BOOL PXDomainBlocksRequest(NSURLRequest *request) {
    @autoreleasepool {
        NSURL *url = nil;
        NSString *host = nil;
        @try { url = request.URL; host = url.host; return shouldBlockDomain(host); }
        @catch (__unused NSException *exception) { return NO; }
        @finally { request = nil; url = nil; host = nil; }
    }
}
static BOOL PXDomainBlocksURL(NSURL *url) {
    @autoreleasepool {
        NSString *host = nil;
        @try { host = url.host; return shouldBlockDomain(host); }
        @catch (__unused NSException *exception) { return NO; }
        @finally { url = nil; host = nil; }
    }
}

// Only the adapter's exact internal target bypasses its nested message check.
// Other requests made by a callback still receive normal domain policy.
static BOOL PXDomainIsInternalRedirect(NSURL *url) {
    NSString *text = nil;
    @try {
        if (!gPXDomainRedirecting) return NO;
        text = url.absoluteString;
        return [text isEqualToString:@"https://127.0.0.1:1"];
    } @catch (__unused NSException *exception) { return NO; }
    @finally { url = nil; text = nil; }
}

#pragma mark - DNS Level Blocking (C Functions)

// Enhanced gethostbyname hook
static struct hostent* hooked_gethostbyname(const char *name) {
    int savedErrno = errno, savedHostError = h_errno;
    BOOL blocked = shouldBlockHostname(name);
    errno = savedErrno; h_errno = savedHostError;
    if (blocked) { h_errno = HOST_NOT_FOUND; return NULL; }
    if (!original_gethostbyname) { errno = ENOSYS; h_errno = NO_RECOVERY; return NULL; }
    return original_gethostbyname(name);
}

// Enhanced getaddrinfo hook
static int hooked_getaddrinfo(const char *hostname, const char *servname, const struct addrinfo *hints, struct addrinfo **res) {
    int savedErrno = errno, savedHostError = h_errno;
    BOOL blocked = shouldBlockHostname(hostname);
    errno = savedErrno; h_errno = savedHostError;
    if (blocked) { if (res) *res = NULL; return EAI_NONAME; }
    if (!original_getaddrinfo) { if (res) *res = NULL; errno = ENOSYS; return EAI_SYSTEM; }
    return original_getaddrinfo(hostname, servname, hints, res);
}

// Enhanced getnameinfo hook (reverse DNS)
static int hooked_getnameinfo(const struct sockaddr *sa, socklen_t salen, char *host, socklen_t hostlen, char *serv, socklen_t servlen, int flags) {
    if (!original_getnameinfo) { errno = ENOSYS; return EAI_SYSTEM; }
    int result = original_getnameinfo(sa, salen, host, hostlen, serv, servlen, flags);
    if (result != 0 || !host || !hostlen) return result;
    int savedErrno = errno, savedHostError = h_errno;
    BOOL blocked = PXDomainBlockResolvedHost(host, hostlen);
    errno = savedErrno; h_errno = savedHostError;
    if (blocked) { host[0] = 0; return EAI_NONAME; }
    return result;
}

// Catch prototype drift in the real SDK at build time, not after injection.
_Static_assert(__builtin_types_compatible_p(__typeof__(&hooked_getnameinfo), __typeof__(&getnameinfo)), "getnameinfo ABI mismatch");

#pragma mark - Foundation Level DNS Blocking

// Hook CFHost for higher-level DNS resolution
%hook CFHost

+ (CFHostRef)createWithName:(CFStringRef)hostname {
    NSString *host = nil;
    @try {
        @try { host = (__bridge NSString *)hostname; if (shouldBlockDomain(host)) return NULL; }
        @catch (__unused NSException *exception) { }
        return %orig;
    } @finally { host = nil; }
}

%end

// Hook NSHost for Objective-C level DNS resolution
%hook NSHost

+ (NSHost *)hostWithName:(NSString *)name {
    @try { if (shouldBlockDomain(name)) return nil; return %orig; }
    @finally { name = nil; }
}

+ (NSHost *)hostWithAddress:(NSString *)address {
    // Allow IP addresses through - we only block domain names
    return %orig;
}

%end

// Hook Network.framework (iOS 12+) for modern networking
%group NetworkFrameworkHooks

%hook NWEndpoint

+ (instancetype)endpointWithHost:(NSString *)hostname port:(NSString *)port {
    @try { if (shouldBlockDomain(hostname)) return nil; return %orig; }
    @finally { hostname = nil; port = nil; }
}

%end

%end

#pragma mark - NSURLSession Lifecycle Blocking

// Keep request construction pure: rewriting NSURLRequest/NSMutableURLRequest to
// localhost hid the real host before session policy could inspect it. Legacy
// NSURLConnection/CFNetwork/WebKit entry points retain their existing adapters.
static NSURLSession *PXDomainObservedSession(NSURLSession *session) {
    @try {
        @try {
            PXDomainObserveURLSession(session, ^BOOL(NSString *host) { return shouldBlockDomain(host); });
        } @catch (__unused NSException *exception) { }
        return session;
    } @finally { session = nil; }
}

%hook NSURLSession

+ (NSURLSession *)sharedSession {
    NSURLSession *session = nil;
    @try { session = %orig; return PXDomainObservedSession(session); }
    @finally { session = nil;  }
}

+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration {
    NSURLSession *session = nil;
    @try { session = %orig; return PXDomainObservedSession(session); }
    @finally { session = nil; configuration = nil; }
}

+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration
                                delegate:(id<NSURLSessionDelegate>)delegate
                           delegateQueue:(NSOperationQueue *)queue {
    NSURLSession *session = nil;
    @try { session = %orig; return PXDomainObservedSession(session); }
    @finally { session = nil; configuration = nil; delegate = nil; queue = nil; }
}

%end

#pragma mark - NSURLConnection Legacy Support

static void PXDomainDeliverBlockedAsync(NSOperationQueue *queue, void (^handler)(NSURLResponse *, NSData *, NSError *)) {
    NSOperationQueue *targetQueue = nil;
    void (^client)(NSURLResponse *, NSData *, NSError *) = nil;
    NSError *error = nil;
    dispatch_block_t delivery = nil, delayed = nil;
    @try {
        if (!handler) return;
        targetQueue = queue ?: [NSOperationQueue mainQueue]; client = [handler copy];
        error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorDNSLookupFailed
            userInfo:@{NSLocalizedDescriptionKey: @"The host name could not be resolved."}];
        {
            delivery = ^{
                void (^completion)(NSURLResponse *, NSData *, NSError *) = nil;
                NSError *failure = nil;
                @try { completion = client; failure = error; completion(nil, nil, failure); }
                @finally { completion = nil; failure = nil; }
            };
        }
        {
            delayed = ^{
                NSOperationQueue *target = nil;
                dispatch_block_t callback = nil;
                @try { target = targetQueue; callback = delivery; [target addOperationWithBlock:callback]; }
                @finally { target = nil; callback = nil; }
            };
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), delayed);
    } @finally { queue = nil; handler = nil; targetQueue = nil; client = nil; error = nil; delivery = nil; delayed = nil; }
}

%hook NSURLConnection

+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error {
    @try {
        if (PXDomainBlocksRequest(request)) {
            if (error) *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotFindHost
                userInfo:@{NSLocalizedDescriptionKey: @"A server with the specified hostname could not be found."}];
            if (response) *response = nil;
            return nil;
        }
        return %orig;
    } @finally { request = nil; }
}

+ (void)sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void (^)(NSURLResponse *, NSData *, NSError *))handler {
    @try {
        if (PXDomainBlocksRequest(request)) { PXDomainDeliverBlockedAsync(queue, handler); return; }
        %orig;
    } @finally { request = nil; queue = nil; handler = nil; }
}

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    NSMutableURLRequest *blockRequest = nil;
    NSURL *blockURL = nil;
    BOOL blocked = NO;
    @try {
        blocked = PXDomainBlocksRequest(request);
        if (blocked) {
            @try {
                blockRequest = [request mutableCopy]; blockURL = [NSURL URLWithString:@"https://127.0.0.1:1"];
                if (!blockRequest || !blockURL) return nil;
                [blockRequest setURL:blockURL];
            } @catch (__unused NSException *exception) { return nil; }
        }
        return %orig(blocked ? blockRequest : request, delegate);
    } @finally { request = nil; delegate = nil; blockRequest = nil; blockURL = nil; }
}

%end

#pragma mark - CFNetwork Level Blocking

%group ScopedApps

%hookf(CFReadStreamRef, CFReadStreamCreateForHTTPRequest, CFAllocatorRef alloc, CFHTTPMessageRef request) {
    CFURLRef requestURL = NULL, blockURL = NULL;
    CFStringRef method = NULL, version = NULL;
    CFHTTPMessageRef blockRequest = NULL;
    CFHTTPMessageRef heldRequest = request ? (CFHTTPMessageRef)CFRetain(request) : NULL;
    CFAllocatorRef heldAllocator = alloc ? (CFAllocatorRef)CFRetain(alloc) : NULL;
    NSURL *url = nil;
    BOOL blocked = NO, previous = gPXDomainRedirecting;
    @try {
        @try {
            if (request) {
                requestURL = CFHTTPMessageCopyRequestURL(request); url = (__bridge NSURL *)requestURL;
                blocked = !PXDomainIsInternalRedirect(url) && PXDomainBlocksURL(url);
                if (blocked) {
                    blockURL = CFURLCreateWithString(alloc, CFSTR("https://127.0.0.1:1"), NULL);
                    method = CFHTTPMessageCopyRequestMethod(request); version = CFHTTPMessageCopyVersion(request);
                    if (!blockURL || !method || !version) return NULL;
                    gPXDomainRedirecting = YES;
                    blockRequest = CFHTTPMessageCreateRequest(alloc, method, blockURL, version);
                    if (!blockRequest) return NULL;
                }
            }
        } @catch (__unused NSException *exception) { if (blocked) return NULL; }
        @finally { gPXDomainRedirecting = previous; }
        return %orig(alloc, blocked ? blockRequest : request);
    } @finally {
        gPXDomainRedirecting = previous; url = nil;
        if (requestURL) CFRelease(requestURL); if (blockURL) CFRelease(blockURL);
        if (method) CFRelease(method); if (version) CFRelease(version); if (blockRequest) CFRelease(blockRequest);
        if (heldRequest) CFRelease(heldRequest); if (heldAllocator) CFRelease(heldAllocator);
    }
}

%hookf(CFHTTPMessageRef, CFHTTPMessageCreateRequest, CFAllocatorRef alloc, CFStringRef requestMethod, CFURLRef url, CFStringRef httpVersion) {
    CFURLRef blockURL = NULL, heldURL = url ? (CFURLRef)CFRetain(url) : NULL;
    CFStringRef heldMethod = requestMethod ? (CFStringRef)CFRetain(requestMethod) : NULL;
    CFStringRef heldVersion = httpVersion ? (CFStringRef)CFRetain(httpVersion) : NULL;
    CFAllocatorRef heldAllocator = alloc ? (CFAllocatorRef)CFRetain(alloc) : NULL;
    NSURL *nsURL = nil;
    BOOL blocked = NO;
    @try {
        @try {
            if (url) {
                nsURL = (__bridge NSURL *)url; blocked = !PXDomainIsInternalRedirect(nsURL) && PXDomainBlocksURL(nsURL);
                if (blocked) {
                    blockURL = CFURLCreateWithString(alloc, CFSTR("https://127.0.0.1:1"), NULL);
                    if (!blockURL) return NULL;
                }
            }
        } @catch (__unused NSException *exception) { if (blocked) return NULL; }
        return %orig(alloc, requestMethod, blocked ? blockURL : url, httpVersion);
    } @finally {
        nsURL = nil; if (blockURL) CFRelease(blockURL); if (heldURL) CFRelease(heldURL);
        if (heldMethod) CFRelease(heldMethod); if (heldVersion) CFRelease(heldVersion); if (heldAllocator) CFRelease(heldAllocator);
    }
}

%end

#pragma mark - WebKit Fallback (Only if other hooks fail)

%hook WKWebView

- (WKNavigation *)loadRequest:(NSURLRequest *)request {
    __attribute__((objc_precise_lifetime)) id receiver = self;
    NSURL *blockURL = nil;
    NSURLRequest *blockRequest = nil;
    BOOL blocked = NO;
    @try {
        blocked = PXDomainBlocksRequest(request);
        if (blocked) {
            @try { blockURL = [NSURL URLWithString:@"about:blank"]; if (blockURL) blockRequest = [NSURLRequest requestWithURL:blockURL]; if (!blockRequest) return nil; }
            @catch (__unused NSException *exception) { return nil; }
        }
        return %orig(blocked ? blockRequest : request);
    } @finally { receiver = nil; request = nil; blockURL = nil; blockRequest = nil; }
}

- (WKNavigation *)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL {
    __attribute__((objc_precise_lifetime)) id receiver = self;
    NSURL *blockURL = nil;
    BOOL blocked = NO;
    @try {
        blocked = PXDomainBlocksURL(baseURL);
        if (blocked) {
            @try { blockURL = [NSURL URLWithString:@"https://127.0.0.1:1"]; if (!blockURL) return nil; }
            @catch (__unused NSException *exception) { return nil; }
        }
        return %orig(string, blocked ? blockURL : baseURL);
    } @finally { receiver = nil; string = nil; baseURL = nil; blockURL = nil; }
}

- (WKNavigation *)loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL {
    __attribute__((objc_precise_lifetime)) id receiver = self;
    NSURL *blockURL = nil;
    NSURLRequest *blockRequest = nil;
    BOOL blocked = NO;
    @try {
        blocked = PXDomainBlocksURL(URL);
        if (blocked) {
            @try { blockURL = [NSURL URLWithString:@"about:blank"]; if (blockURL) blockRequest = [NSURLRequest requestWithURL:blockURL]; if (!blockRequest) return nil; }
            @catch (__unused NSException *exception) { return nil; }
        }
        if (blocked) return [self loadRequest:blockRequest];
        return %orig(URL, readAccessURL);
    } @finally { receiver = nil; URL = nil; readAccessURL = nil; blockURL = nil; blockRequest = nil; }
}

%end

%hook WKNavigationAction

- (NSURLRequest *)request {
    __attribute__((objc_precise_lifetime)) id receiver = self;
    NSURLRequest *originalRequest = nil, *blockRequest = nil;
    NSURL *blockURL = nil;
    @try {
        originalRequest = %orig;
        @try {
            if (PXDomainBlocksRequest(originalRequest)) {
                blockURL = [NSURL URLWithString:@"https://127.0.0.1:1"];
                if (blockURL) blockRequest = [NSURLRequest requestWithURL:blockURL];
                return blockRequest;
            }
        } @catch (__unused NSException *exception) { }
        return originalRequest;
    } @finally { receiver = nil; originalRequest = nil; blockRequest = nil; blockURL = nil; }
}

%end

#pragma mark - Unified Constructor

%ctor {
    @autoreleasepool {
        if (!PXBootstrapAllows(PXHookCapabilityWebNetworking)) return;
        // Never run domain blocking work in SpringBoard / critical system processes.
        if (PXIsSpringBoardProcess()) return;
        NSString *bundleID = getCurrentBundleID();
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (PXIsCriticalSystemProcess(bundleID, proc)) return;
        BOOL isScoped = bundleID.length && PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack);
        if (!isScoped) return;

        DomainBlockingSettings *settings = [DomainBlockingSettings sharedSettings];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        (__bridge const void *)(settings),
                                        domainBlockingSettingsChanged,
                                        CFSTR("com.hydra.tlinkios.domainBlockingChanged"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        // Install hooks even when Domain Blocking is currently OFF. shouldBlockDomain()
        // consults the live settings snapshot, so an already-running scoped process can
        // be enabled or disabled without a restart.
        // DNS-level C function hooks
        void *gethostbyname_ptr = dlsym(RTLD_DEFAULT, "gethostbyname");
        if (gethostbyname_ptr) {
            MSHookFunction(gethostbyname_ptr, (void *)hooked_gethostbyname, (void **)&original_gethostbyname);
        }

        void *getaddrinfo_ptr = dlsym(RTLD_DEFAULT, "getaddrinfo");
        if (getaddrinfo_ptr) {
            MSHookFunction(getaddrinfo_ptr, (void *)hooked_getaddrinfo, (void **)&original_getaddrinfo);
        }

        void *getnameinfo_ptr = dlsym(RTLD_DEFAULT, "getnameinfo");
        if (getnameinfo_ptr) {
            MSHookFunction(getnameinfo_ptr, (void *)hooked_getnameinfo, (void **)&original_getnameinfo);
        }

        %init;

        Class NWEndpointClass = NSClassFromString(@"NWEndpoint");
        if (NWEndpointClass) {
            %init(NetworkFrameworkHooks);
        }

        %init(ScopedApps);
    }
}
