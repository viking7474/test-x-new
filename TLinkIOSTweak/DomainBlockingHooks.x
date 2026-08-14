#import "DomainBlockingSettings.h"
#import <Foundation/Foundation.h>
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



// Function pointers for original C functions (DNS level)
static struct hostent* (*original_gethostbyname)(const char *name);
static int (*original_getaddrinfo)(const char *hostname, const char *servname, const struct addrinfo *hints, struct addrinfo **res);
static int (*original_getnameinfo)(const struct sockaddr *sa, socklen_t salen, char *host, size_t hostlen, char *serv, size_t servlen, int flags);

// Forward declarations
static NSString *getCurrentBundleID(void);
static NSDictionary *loadScopedApps(void);
static BOOL isInScopedAppsList(void);
static BOOL shouldBlockDomain(NSString *host);

#pragma mark - Scoped Apps Helper Functions (Unified)

// Get the current bundle ID
static NSString *getCurrentBundleID(void) {
    @try {
        NSBundle *mainBundle = [NSBundle mainBundle];
        if (!mainBundle) {
            return nil;
        }
        return [mainBundle bundleIdentifier];
    } @catch (NSException *e) {
        return nil;
    }
}

// Load scoped apps from the plist file
static NSDictionary *loadScopedApps(void) {
    return PXScopedAppsSnapshot();
}

// Check if the current app is in the scoped apps list
static BOOL isInScopedAppsList(void) {
    @try {
        NSString *bundleID = getCurrentBundleID();
        if (!bundleID || [bundleID length] == 0) {
            return NO;
        }
        
        NSDictionary *scopedApps = loadScopedApps();
        if (!scopedApps || scopedApps.count == 0) {
            return NO;
        }
        
        // Check if this bundle ID is in the scoped apps dictionary
        id appEntry = scopedApps[bundleID];
        if (!appEntry || ![appEntry isKindOfClass:[NSDictionary class]]) {
            return NO;
        }
        
        // Check if the app is enabled - STEALTH: no logging
        BOOL isEnabled = [appEntry[@"enabled"] boolValue];
        return isEnabled;
        
    } @catch (NSException *e) {
        // STEALTH: Silent exception handling
        return NO;
    }
}

#pragma mark - Unified Domain Blocking Logic

// UNIFIED: Helper function to check if domain blocking should occur (works for both DNS and HTTP)
static BOOL shouldBlockDomain(NSString *host) {
    if (!host) {
        return NO;
    }
    
    @autoreleasepool {
        // OPTIMIZATION: Check global enable state first to avoid expensive operations
        DomainBlockingSettings *settings = [DomainBlockingSettings sharedSettings];
        
        // TEMPORARY DEBUG: Log the state
        NSLog(@"[DomainBlocking DEBUG] Checking domain: %@", host);
        NSLog(@"[DomainBlocking DEBUG] Settings enabled: %@", settings.isEnabled ? @"YES" : @"NO");
        NSLog(@"[DomainBlocking DEBUG] Blocked domains: %@", settings.blockedDomains);
        
        if (!settings.isEnabled) {
            // STEALTH: No logging - avoid detection
            return NO; // Early exit if globally disabled
        }
        
        // Get current bundle ID for scoped app check
        NSString *bundleID = getCurrentBundleID();
        NSLog(@"[DomainBlocking DEBUG] Bundle ID: %@", bundleID);
        
        if (!bundleID) {
            // STEALTH: No logging - avoid detection
            return NO;
        }
        
        // Only check scoped apps if globally enabled
        BOOL isScoped = isInScopedAppsList();
        NSLog(@"[DomainBlocking DEBUG] Is scoped app: %@", isScoped ? @"YES" : @"NO");
        
        if (!isScoped) {
            // STEALTH: No logging - avoid detection
            return NO;
        }
        
        // Check if domain is blocked (domain names only, no IP blocking)
        BOOL shouldBlock = [settings isDomainBlocked:host];
        NSLog(@"[DomainBlocking DEBUG] Should block %@: %@", host, shouldBlock ? @"YES" : @"NO");
        
        // STEALTH: No logging - avoid detection
        return shouldBlock;
    }
}

// Helper for C string domain checking (DNS level)
static BOOL shouldBlockHostname(const char *hostname) {
    if (!hostname) return NO;
    
    @autoreleasepool {
        NSString *host = [NSString stringWithUTF8String:hostname];
        return shouldBlockDomain(host);
    }
}

#pragma mark - DNS Level Blocking (C Functions)

// Enhanced gethostbyname hook
static struct hostent* hooked_gethostbyname(const char *name) {
    if (shouldBlockHostname(name)) {
        // STEALTH: No logging - apps can detect NSLog
        // Set h_errno to indicate host not found
        h_errno = HOST_NOT_FOUND;
        return NULL;
    }
    
    return original_gethostbyname(name);
}

// Enhanced getaddrinfo hook
static int hooked_getaddrinfo(const char *hostname, const char *servname, const struct addrinfo *hints, struct addrinfo **res) {
    if (shouldBlockHostname(hostname)) {
        // STEALTH: No logging - silent blocking
        // Return EAI_NONAME to indicate name resolution failure
        return EAI_NONAME;
    }
    
    return original_getaddrinfo(hostname, servname, hints, res);
}

// Enhanced getnameinfo hook (reverse DNS)
static int hooked_getnameinfo(const struct sockaddr *sa, socklen_t salen, char *host, size_t hostlen, char *serv, size_t servlen, int flags) {
    // Call original first to get the hostname
    int result = original_getnameinfo(sa, salen, host, hostlen, serv, servlen, flags);
    
    // If successful and we got a hostname, check if we should block it
    if (result == 0 && host && hostlen > 0) {
        if (shouldBlockHostname(host)) {
            // STEALTH: No logging - silent reverse DNS blocking
            // Clear the hostname to indicate no result
            if (hostlen > 0) {
                host[0] = '\0';
            }
            return EAI_NONAME;
        }
    }
    
    return result;
}

#pragma mark - Foundation Level DNS Blocking

// Hook CFHost for higher-level DNS resolution
%hook CFHost

+ (CFHostRef)createWithName:(CFStringRef)hostname {
    if (hostname) {
        @autoreleasepool {
            NSString *hostStr = (__bridge NSString *)hostname;
            if (shouldBlockDomain(hostStr)) {
                // STEALTH: No logging - silent CFHost blocking
                return NULL;
            }
        }
    }
    return %orig;
}

%end

// Hook NSHost for Objective-C level DNS resolution
%hook NSHost

+ (NSHost *)hostWithName:(NSString *)name {
    if (shouldBlockDomain(name)) {
        // STEALTH: No logging - silent NSHost blocking
        return nil;
    }
    return %orig;
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
    if (shouldBlockDomain(hostname)) {
        // STEALTH: No logging - silent Network.framework blocking
        return nil;
    }
    return %orig;
}

%end

%end

#pragma mark - HTTP Request Level Blocking

%hook NSURLRequest

+ (id)requestWithURL:(NSURL *)url {
    if (shouldBlockDomain(url.host) && url && url.host) {
        // STEALTH: No logging - apps can detect NSLog
        // Return valid request with localhost to avoid nil detection
        return [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://127.0.0.1:1"]];
    }
    return %orig;
}

- (id)initWithURL:(NSURL *)url {
    if (shouldBlockDomain(url.host) && url && url.host) {
        // STEALTH: No logging - initialize with localhost instead of nil
        return %orig([NSURL URLWithString:@"https://127.0.0.1:1"]);
    }
    return %orig;
}

%end

%hook NSMutableURLRequest

- (void)setURL:(NSURL *)url {
    if (shouldBlockDomain(url.host) && url && url.host) {
        // STEALTH: No logging - silent URL blocking
        // Set to localhost instead of not setting
        %orig([NSURL URLWithString:@"https://127.0.0.1:1"]);
        return;
    }
    %orig;
}

%end

#pragma mark - NSURLSession Comprehensive Blocking

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    if (shouldBlockDomain(request.URL.host) && request.URL && request.URL.host) {
        // STEALTH: No logging, create task with localhost that will fail naturally
        NSMutableURLRequest *blockRequest = [request mutableCopy];
        [blockRequest setURL:[NSURL URLWithString:@"https://127.0.0.1:1"]];
        return %orig(blockRequest);
    }
    return %orig;
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if (shouldBlockDomain(request.URL.host) && request.URL && request.URL.host) {
        // STEALTH: Create realistic delayed network failure
        if (completionHandler) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain 
                                                     code:NSURLErrorCannotFindHost 
                                                 userInfo:@{NSLocalizedDescriptionKey: @"A server with the specified hostname could not be found."}];
                completionHandler(nil, nil, error);
            });
        }
        // Return cancelled task to simulate network failure
        NSMutableURLRequest *blockRequest = [request mutableCopy];
        [blockRequest setURL:[NSURL URLWithString:@"https://127.0.0.1:1"]];
        NSURLSessionDataTask *task = %orig(blockRequest, nil);
        [task cancel];
        return task;
    }
    return %orig;
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url {
    if (shouldBlockDomain(url.host) && url && url.host) {
        // STEALTH: No logging, redirect to localhost
        return %orig([NSURL URLWithString:@"https://127.0.0.1:1"]);
    }
    return %orig;
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if (shouldBlockDomain(url.host) && url && url.host) {
        // STEALTH: Realistic delayed failure
        if (completionHandler) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain 
                                                     code:NSURLErrorTimedOut 
                                                 userInfo:@{NSLocalizedDescriptionKey: @"The request timed out."}];
                completionHandler(nil, nil, error);
            });
        }
        NSURLSessionDataTask *task = %orig([NSURL URLWithString:@"https://127.0.0.1:1"], nil);
        [task cancel];
        return task;
    }
    return %orig;
}

// Upload tasks
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData {
    if (shouldBlockDomain(request.URL.host) && request.URL && request.URL.host) {
        // STEALTH: No logging
        NSMutableURLRequest *blockRequest = [request mutableCopy];
        [blockRequest setURL:[NSURL URLWithString:@"https://127.0.0.1:1"]];
        return %orig(blockRequest, bodyData);
    }
    return %orig;
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if (shouldBlockDomain(request.URL.host) && request.URL && request.URL.host) {
        // STEALTH: Realistic upload failure
        if (completionHandler) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain 
                                                     code:NSURLErrorNetworkConnectionLost 
                                                 userInfo:@{NSLocalizedDescriptionKey: @"The network connection was lost."}];
                completionHandler(nil, nil, error);
            });
        }
        NSMutableURLRequest *blockRequest = [request mutableCopy];
        [blockRequest setURL:[NSURL URLWithString:@"https://127.0.0.1:1"]];
        NSURLSessionUploadTask *task = %orig(blockRequest, bodyData, nil);
        [task cancel];
        return task;
    }
    return %orig;
}

// Download tasks
- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request {
    if (shouldBlockDomain(request.URL.host) && request.URL && request.URL.host) {
        // STEALTH: No logging, redirect to localhost that will fail
        NSMutableURLRequest *blockRequest = [request mutableCopy];
        [blockRequest setURL:[NSURL URLWithString:@"https://127.0.0.1:1"]];
        return %orig(blockRequest);
    }
    return %orig;
}

- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURL *, NSURLResponse *, NSError *))completionHandler {
    if (shouldBlockDomain(request.URL.host) && request.URL && request.URL.host) {
        // STEALTH: Realistic download failure
        if (completionHandler) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain 
                                                     code:NSURLErrorCannotConnectToHost 
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Could not connect to the server."}];
                completionHandler(nil, nil, error);
            });
        }
        NSMutableURLRequest *blockRequest = [request mutableCopy];
        [blockRequest setURL:[NSURL URLWithString:@"https://127.0.0.1:1"]];
        NSURLSessionDownloadTask *task = %orig(blockRequest, nil);
        [task cancel];
        return task;
    }
    return %orig;
}

- (NSURLSessionDownloadTask *)downloadTaskWithURL:(NSURL *)url {
    if (shouldBlockDomain(url.host) && url && url.host) {
        // STEALTH: No logging, redirect to localhost
        return %orig([NSURL URLWithString:@"https://127.0.0.1:1"]);
    }
    return %orig;
}

- (NSURLSessionDownloadTask *)downloadTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSURL *, NSURLResponse *, NSError *))completionHandler {
    if (shouldBlockDomain(url.host) && url && url.host) {
        // STEALTH: Realistic delayed failure
        if (completionHandler) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain 
                                                     code:NSURLErrorTimedOut 
                                                 userInfo:@{NSLocalizedDescriptionKey: @"The request timed out."}];
                completionHandler(nil, nil, error);
            });
        }
        NSURLSessionDownloadTask *task = %orig([NSURL URLWithString:@"https://127.0.0.1:1"], nil);
        [task cancel];
        return task;
    }
    return %orig;
}

// WebSocket tasks (iOS 13+)
- (NSURLSessionWebSocketTask *)webSocketTaskWithRequest:(NSURLRequest *)request {
    if (shouldBlockDomain(request.URL.host) && request.URL && request.URL.host) {
        // STEALTH: No logging, create task with localhost that will fail
        NSMutableURLRequest *blockRequest = [request mutableCopy];
        [blockRequest setURL:[NSURL URLWithString:@"wss://127.0.0.1:1"]];
        return %orig(blockRequest);
    }
    return %orig;
}

- (NSURLSessionWebSocketTask *)webSocketTaskWithURL:(NSURL *)url {
    if (shouldBlockDomain(url.host) && url && url.host) {
        // STEALTH: No logging, redirect to localhost
        return %orig([NSURL URLWithString:@"wss://127.0.0.1:1"]);
    }
    return %orig;
}

// Stream tasks
- (NSURLSessionStreamTask *)streamTaskWithHostName:(NSString *)hostname port:(NSInteger)port {
    if (shouldBlockDomain(hostname)) {
        // STEALTH: No logging, redirect to localhost
        return %orig(@"127.0.0.1", 1);
    }
    return %orig;
}

%end

#pragma mark - NSURLConnection Legacy Support

%hook NSURLConnection

+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error {
    if (shouldBlockDomain(request.URL.host) && request.URL && request.URL.host) {
        // STEALTH: Simulate realistic DNS failure
        if (error) {
            *error = [NSError errorWithDomain:NSURLErrorDomain 
                                         code:NSURLErrorCannotFindHost 
                                     userInfo:@{NSLocalizedDescriptionKey: @"A server with the specified hostname could not be found."}];
        }
        if (response) *response = nil;
        return nil;
    }
    return %orig;
}

+ (void)sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void (^)(NSURLResponse *, NSData *, NSError *))handler {
    if (shouldBlockDomain(request.URL.host) && request.URL && request.URL.host) {
        // STEALTH: Realistic async failure with delay
        if (handler) {
            // P1 FIX (callback sai queue): +sendAsynchronousRequest:queue:completionHandler: must
            // deliver its completion handler on the caller-provided NSOperationQueue (Apple's
            // contract), not on a global GCD queue. Wrong-queue delivery breaks callers that
            // expect the handler on their own queue (e.g. main-thread UI updates).
            NSOperationQueue *targetQueue = queue ?: [NSOperationQueue mainQueue];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain 
                                                     code:NSURLErrorDNSLookupFailed 
                                                 userInfo:@{NSLocalizedDescriptionKey: @"The host name could not be resolved."}];
                [targetQueue addOperationWithBlock:^{
                    handler(nil, nil, error);
                }];
            });
        }
        return;
    }
    %orig;
}

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    if (shouldBlockDomain(request.URL.host) && request.URL && request.URL.host) {
        // STEALTH: Initialize with localhost that will fail
        NSMutableURLRequest *blockRequest = [request mutableCopy];
        [blockRequest setURL:[NSURL URLWithString:@"https://127.0.0.1:1"]];
        return %orig(blockRequest, delegate);
    }
    return %orig;
}

%end

#pragma mark - CFNetwork Level Blocking

%group ScopedApps

%hookf(CFReadStreamRef, CFReadStreamCreateForHTTPRequest, CFAllocatorRef alloc, CFHTTPMessageRef request) {
    // P1 FIX (CF lifetime / UAF): CFHTTPMessageCopyRequestURL returns a +1 CF object; own it in
    // one variable and release it exactly once on every path.
    CFURLRef requestURL = CFHTTPMessageCopyRequestURL(request);
    NSURL *url = (__bridge NSURL *)requestURL;
    if (url.host && shouldBlockDomain(url.host)) {
        // STEALTH: No logging, create stream with localhost that will fail naturally.
        if (requestURL) CFRelease(requestURL);
        // CFHTTPMessageCopyRequestMethod / CFHTTPMessageCopyVersion each return a +1 copy; capture
        // them so they are released instead of leaked into CFHTTPMessageCreateRequest, and
        // NULL-guard every created object before use.
        CFURLRef blockURL = CFURLCreateWithString(alloc, CFSTR("https://127.0.0.1:1"), NULL);
        CFStringRef method = CFHTTPMessageCopyRequestMethod(request);
        CFStringRef version = CFHTTPMessageCopyVersion(request);
        CFReadStreamRef stream = NULL;
        if (blockURL) {
            CFHTTPMessageRef blockRequest = CFHTTPMessageCreateRequest(alloc, method, blockURL, version);
            if (blockRequest) {
                stream = %orig(alloc, blockRequest);
                CFRelease(blockRequest);
            }
        }
        if (method) CFRelease(method);
        if (version) CFRelease(version);
        if (blockURL) CFRelease(blockURL);
        return stream;
    }
    if (requestURL) CFRelease(requestURL);
    return %orig;
}

%hookf(CFHTTPMessageRef, CFHTTPMessageCreateRequest, CFAllocatorRef alloc, CFStringRef requestMethod, CFURLRef url, CFStringRef httpVersion) {
    if (url) {
        NSURL *nsURL = (__bridge NSURL *)url;
        if (shouldBlockDomain(nsURL.host)) {
            // STEALTH: No logging, create request with localhost that will fail
            CFURLRef blockURL = CFURLCreateWithString(alloc, CFSTR("https://127.0.0.1:1"), NULL);
            CFHTTPMessageRef result = %orig(alloc, requestMethod, blockURL, httpVersion);
            CFRelease(blockURL);
            return result;
        }
    }
    return %orig;
}

%end

#pragma mark - WebKit Fallback (Only if other hooks fail)

%hook WKWebView

- (WKNavigation *)loadRequest:(NSURLRequest *)request {
    if (shouldBlockDomain(request.URL.host) && request.URL && request.URL.host) {
        // STEALTH: Load blank page instead of showing error
        // Note: This should rarely trigger since NSURLRequest hooks should catch it first
        NSURLRequest *blockRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]];
        return %orig(blockRequest);
    }
    return %orig;
}

- (WKNavigation *)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL {
    if (baseURL && shouldBlockDomain(baseURL.host)) {
        // STEALTH: Load with localhost base URL
        NSURL *blockURL = [NSURL URLWithString:@"https://127.0.0.1:1"];
        return %orig(string, blockURL);
    }
    return %orig;
}

- (WKNavigation *)loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL {
    if (URL && shouldBlockDomain(URL.host)) {
        // STEALTH: Load blank page instead
        NSURLRequest *blockRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]];
        return [self loadRequest:blockRequest];
    }
    return %orig;
}

%end

%hook WKNavigationAction

- (NSURLRequest *)request {
    NSURLRequest *originalRequest = %orig;
    if (originalRequest.URL && shouldBlockDomain(originalRequest.URL.host)) {
        // STEALTH: Return request to localhost
        return [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://127.0.0.1:1"]];
    }
    return originalRequest;
}

%end

#pragma mark - Unified Constructor

%ctor {
    @autoreleasepool {
        // Never run domain blocking work in SpringBoard / critical system processes.
        if (PXIsSpringBoardProcess()) return;
        NSString *bundleID = getCurrentBundleID();
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (PXIsCriticalSystemProcess(bundleID, proc)) return;
        DomainBlockingSettings *settings = [DomainBlockingSettings sharedSettings];
        if (!settings.isEnabled) return;

        BOOL isScoped = bundleID.length && PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack);
        if (!isScoped) return;

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
