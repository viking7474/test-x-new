#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#import <os/lock.h>
#include <math.h>
#include <stdint.h>
#include <stdatomic.h>
#include <stdio.h>

static NSUInteger gChecks, gFailures;
static atomic_uint gFileReads, gSuites, gDefaultReads, gClockReads;
static double gTime = 1000;
static NSDictionary *gFirst, *gSecond, *gDefaults;
static void (*gReadAction)(void);
static os_unfair_lock gFixtureReadLock = OS_UNFAIR_LOCK_INIT;
static BOOL gReadThrows, gViewThrows, gDefaultsThrow;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PX_RUNTIME_READ_OPERATION ((void)0)

@interface PXFixtureDefaults : NSObject
- (instancetype)initWithSuiteName:(NSString *)name;
- (id)objectForKey:(NSString *)key;
@end
@implementation PXFixtureDefaults
- (instancetype)initWithSuiteName:(NSString *)name {
    (void)name; atomic_fetch_add(&gSuites, 1); return [super init];
}
- (id)objectForKey:(NSString *)key {
    atomic_fetch_add(&gDefaultReads, 1);
    if (gDefaultsThrow) [NSException raise:@"fixture" format:@"defaults read"];
    return gDefaults[key];
}
@end

@interface PXRuntimeReadSnapshot : NSObject
@property (nonatomic) BOOL valid;
@property (nonatomic, copy) NSDictionary *securitySettings;
@end
@implementation PXRuntimeReadSnapshot
@synthesize securitySettings = _securitySettings;
- (NSDictionary *)securitySettings {
    if (gViewThrows) [NSException raise:@"fixture" format:@"view read"];
    return _securitySettings;
}
@end
static PXRuntimeReadSnapshot *gView;
static PXRuntimeReadSnapshot *PXCaptureRuntimeSnapshot(void) { return gView; }
static double PXIOSVersionCacheTime(void) { atomic_fetch_add(&gClockReads, 1); return gTime; }
static NSDictionary *PXFixtureRead(NSString *path) {
    NSDictionary *result = nil;
    @try {
        atomic_fetch_add(&gFileReads, 1);
        result = [path hasPrefix:@"/private/"] ? gSecond : gFirst;
        os_unfair_lock_lock(&gFixtureReadLock);
        void (*action)(void) = gReadAction; gReadAction = NULL;
        os_unfair_lock_unlock(&gFixtureReadLock);
        if (action) action();
        if (gReadThrows) [NSException raise:@"fixture" format:@"file read"];
        return result;
    } @finally { path = nil; result = nil; }
}
#include "PXUAPolicy.inc"

// A Foundation facade, not a WebKit replacement/runtime acceptance test.
@interface WKWebView : NSObject
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, copy) NSString *customUserAgent;
@property (nonatomic, copy) NSString *lastScript;
@property (nonatomic, strong) NSURL *navigateDuringSetter;
@property (nonatomic) BOOL invalidateDuringSetter, throwSetter, throwScript;
@property (nonatomic) NSUInteger setters, scripts, offMain;
- (void)evaluateJavaScript:(NSString *)script completionHandler:(void (^)(id, NSError *))completion;
@end
@implementation WKWebView
@synthesize URL = _URL, customUserAgent = _customUserAgent;
- (NSURL *)URL { if (![NSThread isMainThread]) _offMain++; return _URL; }
- (void)setCustomUserAgent:(NSString *)ua {
    if (![NSThread isMainThread]) _offMain++;
    _setters++; _customUserAgent = [ua copy];
    if (_navigateDuringSetter) _URL = _navigateDuringSetter;
    if (_invalidateDuringSetter) PXUAPolicyInvalidate();
    if (_throwSetter) [NSException raise:@"fixture" format:@"setter"];
}
- (void)evaluateJavaScript:(NSString *)script completionHandler:(void (^)(id, NSError *))completion {
    (void)completion;
    if (![NSThread isMainThread]) _offMain++;
    _scripts++; _lastScript = [script copy];
    if (_throwScript) [NSException raise:@"fixture" format:@"script"];
}
@end
#include "PXUASync.inc"

static void SetSettings(NSDictionary *settings) {
    gFirst = settings; gSecond = nil; gDefaults = nil;
    gView = [PXRuntimeReadSnapshot new]; gView.valid = YES; gView.securitySettings = settings;
    PXUAPolicyInvalidate();
}
static void PumpMain(void) {
    __block BOOL done = NO;
    dispatch_async(dispatch_get_main_queue(), ^{ done = YES; });
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent() + 5;
    while (!done && CFAbsoluteTimeGetCurrent() < end) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, true);
    CHECK(done, "main queue drains within bound");
}
static void SetSync(BOOL all, BOOL js) {
    SetSettings(@{@"uaSyncHeaderAndJS": @YES, @"uaSyncApplyAllWebViews": @(all), @"uaSyncInjectJS": @(js)});
}
static WKWebView *View(NSString *host) {
    WKWebView *view = [WKWebView new];
    view.URL = [NSURL URLWithString:[@"https://" stringByAppendingString:host]];
    PXUASyncRegisterWKWebView(view); return view;
}
static void Apply(NSString *host, NSString *ua) { PXUASyncApplyToWebViewsForHost(host, ua, PXUASyncEpoch()); }
static void InvalidateInRead(void) { PXUAPolicyInvalidate(); }
static void ReenterInRead(void) {
    PXUAPolicyValues nested = PXUACurrentPolicy();
    CHECK(!nested.syncEnabled && nested.applyAll && !nested.debug.masterEnabled, "recursive policy provider receives pure defaults");
}

static void PolicyTests(void) {
    SetSettings(@{});
    PXUAPolicyValues p = PXUACurrentPolicy();
    CHECK(!p.debug.masterEnabled && !p.debug.traceEnabled && !p.mobileBuild && !p.syncEnabled, "disabled defaults preserved");
    CHECK(p.debug.scopeSafari && p.debug.scopeSafariViewService && p.debug.scopeWebKit, "scope defaults preserved");
    CHECK(p.debug.hook_init && p.debug.hook_setCustomUserAgent && p.debug.hook_appNameUA && p.debug.hook_requestHeaderUA && p.debug.hook_sfUserAgentWithDomain && p.debug.hook_sfDefaultUA, "hook defaults preserved");
    CHECK(p.debug.sensitiveHostExemptionsEnabled && p.fileLog && p.applyAll && p.injectJS, "sensitive host and sync defaults preserved");
    SetSettings(@{@"debugSafariUAMasterEnabled": @YES, @"debugSafariUATraceEnabled": @YES,
        @"debugSafariUAScope_applySafari": @NO, @"debugSafariUAScope_applySafariViewService": @NO, @"debugSafariUAScope_applyWebKit": @NO,
        @"debugSafariUA_WKWebView_init": @NO, @"debugSafariUA_WKWebView_setCustomUserAgent": @NO,
        @"debugSafariUA_WKWebViewConfiguration_appNameUA": @NO, @"debugSafariUA_NSURLRequest_setHeaderUA": @NO,
        @"debugSafariUA_SFUserAgentController_userAgentWithDomain": @NO, @"debugSafariUA_SFUserAgentController_defaultUA": @NO,
        @"debugSafariUA_SensitiveHostExemptionsEnabled": @NO, @"uaSpoofMobileBuildEnabled": @YES,
        @"uaSyncJSOnlyFromRequests": @YES, @"debugSafariUA_LogFileEnabled": @NO, @"uaSyncApplyAllWebViews": @NO, @"uaSyncInjectJS": @NO});
    p = PXUACurrentPolicy();
    CHECK(p.debug.masterEnabled && p.debug.traceEnabled && p.mobileBuild && p.syncEnabled, "explicit enables and JS-only OR preserved");
    CHECK(!p.debug.scopeSafari && !p.debug.scopeSafariViewService && !p.debug.scopeWebKit, "explicit scope disables preserved");
    CHECK(!p.debug.hook_init && !p.debug.hook_setCustomUserAgent && !p.debug.hook_appNameUA && !p.debug.hook_requestHeaderUA && !p.debug.hook_sfUserAgentWithDomain && !p.debug.hook_sfDefaultUA, "explicit hook disables preserved");
    CHECK(!p.debug.sensitiveHostExemptionsEnabled && !p.fileLog && !p.applyAll && !p.injectJS, "explicit secondary disables preserved");
    SetSettings(@{@"uaSyncHeaderAndJS": @"YES", @"uaSpoofMobileBuildEnabled": @"1", @"uaSyncInjectJS": @"0"});
    p = PXUACurrentPolicy();
    CHECK(p.syncEnabled && p.mobileBuild && !p.injectJS, "legacy string booleans accepted");
    SetSettings(@{@"uaSyncHeaderAndJS": @[], @"debugSafariUAMasterEnabled": @{}, @"uaSyncInjectJS": NSNull.null});
    gDefaults = @{@"debugSafariUAMasterEnabled": @YES, @"uaSyncHeaderAndJS": @YES};
    p = PXUACurrentPolicy();
    CHECK(!p.syncEnabled && !p.debug.masterEnabled && p.injectJS, "malformed present values use defaults without fallback or selector crash");
    // Unrelated direct helpers must also release provider inputs under plain ARC exceptions.
    CHECK(PXIOSVersionTimeIsFresh(0, 0, YES, 1), "zero timestamp valid");
    CHECK(!PXIOSVersionTimeIsFresh(0, 1, YES, 1) && !PXIOSVersionTimeIsFresh(NAN, 0, YES, 1), "rollback and unavailable clock rejected");
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    unsigned files = atomic_load(&gFileReads), suites = atomic_load(&gSuites), clocks = atomic_load(&gClockReads);
    SetSettings(@{@"uaSyncHeaderAndJS": @YES});
    p = PXUACurrentPolicy();
    gView.securitySettings = @{}; // Same-view association stays immutable.
    CHECK(PXUACurrentPolicy().syncEnabled, "RootHide packet memo belongs to captured view");
    SetSettings(@{});
    CHECK(!PXUACurrentPolicy().syncEnabled, "RootHide new view cannot reuse old policy");
    gView = nil; gDefaults = @{@"uaSyncHeaderAndJS": @YES};
    CHECK(!PXUACurrentPolicy().syncEnabled, "RootHide pending view has no live defaults fallback");
    SetSettings(@{}); gView.valid = NO;
    CHECK(!PXUACurrentPolicy().syncEnabled, "RootHide invalid view has pure defaults");
    SetSettings(@{}); gViewThrows = YES;
    BOOL caught = NO;
    @try { (void)PXUACurrentPolicy(); } @catch (__unused NSException *e) { caught = YES; }
    gViewThrows = NO;
    CHECK(caught && !gUALoadingPolicy && !PXUACurrentPolicy().syncEnabled, "RootHide provider exception restores reentry guard");
    CHECK(files == atomic_load(&gFileReads) && suites == atomic_load(&gSuites) && clocks == atomic_load(&gClockReads), "RootHide never probes files defaults suites or clock");
#else
    SetSettings(@{}); gSecond = @{@"uaSyncHeaderAndJS": @YES}; gDefaults = @{@"uaSyncInjectJS": @NO};
    unsigned files = atomic_load(&gFileReads), suites = atomic_load(&gSuites);
    p = PXUACurrentPolicy();
    CHECK(!p.syncEnabled && !p.injectJS, "first empty dictionary wins; missing key falls back per defaults");
    CHECK(atomic_load(&gFileReads) == files + 1 && atomic_load(&gSuites) == suites + 1, "one file probe and one suite on cold packet");
    files = atomic_load(&gFileReads); suites = atomic_load(&gSuites);
    for (int i = 0; i < 100; i++) (void)PXUACurrentPolicy();
    CHECK(files == atomic_load(&gFileReads) && suites == atomic_load(&gSuites), "warm packet has zero file or suite work");
    gTime = 1000.5; (void)PXUACurrentPolicy();
    CHECK(files == atomic_load(&gFileReads), "one-second cache remains fresh inside TTL");
    gTime = 1001; (void)PXUACurrentPolicy();
    CHECK(files + 1 == atomic_load(&gFileReads), "TTL boundary is exclusive");
    SetSettings(nil); gSecond = @{@"uaSyncHeaderAndJS": @YES};
    files = atomic_load(&gFileReads); CHECK(PXUACurrentPolicy().syncEnabled, "second file used only when first absent");
    CHECK(files + 2 == atomic_load(&gFileReads), "cold miss probes at most two paths");
    SetSettings(@{@"uaSyncHeaderAndJS": @YES}); gReadAction = InvalidateInRead;
    CHECK(!PXUACurrentPolicy().syncEnabled && !gUAPolicyValid, "invalidated loader cannot publish or return stale policy");
    CHECK(PXUACurrentPolicy().syncEnabled, "next load recovers after canceled publication");
    SetSettings(@{}); gReadAction = ReenterInRead; (void)PXUACurrentPolicy();
    SetSettings(@{}); gReadThrows = YES; BOOL caught = NO;
    @try { (void)PXUACurrentPolicy(); } @catch (__unused NSException *e) { caught = YES; }
    gReadThrows = NO;
    CHECK(caught && !gUALoadingPolicy && !PXUACurrentPolicy().syncEnabled, "rootful provider exception restores reentry guard");
    SetSettings(@{}); gTime = NAN; (void)PXUACurrentPolicy();
    CHECK(!gUAPolicyValid, "failed monotonic clock never leaves immortal cache");
    gTime = 2000;
#endif
    SetSettings(@{@"debugSafariUAMasterEnabled": @YES, @"debugSafariUATraceEnabled": @YES, @"uaSyncHeaderAndJS": @YES});
    dispatch_group_t group = dispatch_group_create();
    atomic_uint torn = 0;
    // Stable immutable provider roots; only packet publication/invalidation is concurrent.
    atomic_uint *tornPointer = &torn;
    for (int i = 0; i < 64; i++) dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        @autoreleasepool {
            PXUAPolicyValues sample = PXUACurrentPolicy();
            if (!(sample.debug.masterEnabled == sample.debug.traceEnabled && sample.debug.traceEnabled == sample.syncEnabled)) atomic_fetch_add(tornPointer, 1);
        }
    });
    CHECK(dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0, "concurrent policy loads complete");
    CHECK(atomic_load(&torn) == 0, "concurrent readers see whole policy packets");
}

static void PolicyLifetimeTests(void) {
    __weak NSDictionary *weakSettings;
    __weak PXFixtureDefaults *weakDefaults;
    __weak NSObject *weakToken;
    BOOL caught = NO;
    @autoreleasepool {
        NSDictionary *settings = nil;
        PXFixtureDefaults *defaults = nil;
        NSObject *token = nil;
        @try {
            token = [NSObject new]; settings = @{@"held-token": token}; defaults = [PXFixtureDefaults new];
            weakSettings = settings; weakDefaults = defaults; weakToken = token;
            gDefaultsThrow = YES;
            (void)PXUABuildPolicy(settings, defaults);
        } @catch (__unused NSException *e) { caught = YES; }
        @finally { settings = nil; defaults = nil; token = nil; gDefaultsThrow = NO; }
    }
    CHECK(caught && !weakSettings && !weakDefaults && !weakToken, "policy builder and typed helper release provider inputs after exception and pool drain");
}

static void SyncTests(void) {
    gWKWebViews = nil; SetSettings(@{});
    WKWebView *one = View(@"example.com"); PXUASyncRegisterWKWebView(one);
    WKWebView *two = View(@"other.com");
    CHECK(gWKWebViews.count == 2, "weak pointer-identity registry deduplicates views");
    Apply(@"example.com", @"disabled"); PumpMain();
    CHECK(one.setters == 0 && two.setters == 0, "disabled sync tracks without applying");
    SetSync(NO, YES); Apply(@"EXAMPLE.COM", @"first"); PumpMain();
    CHECK(one.setters == 1 && one.scripts == 1 && two.setters == 0, "later enable reaches existing matching view only");
    CHECK([one.customUserAgent isEqualToString:@"first"], "sync passes exact frozen UA to setter");
    SetSync(YES, NO); Apply(@"example.com", @"all"); PumpMain();
    CHECK(one.setters == 2 && two.setters == 1 && one.scripts == 1 && two.scripts == 0, "apply-all and JS-off policies preserved");
    SetSync(NO, YES);
    NSUInteger before = one.setters;
    Apply(@"example.com", @"canceled"); PXUAPolicyInvalidate(); PumpMain();
    CHECK(one.setters == before, "invalidation revokes queued job even when sync remains enabled");
    Apply(@"example.com", @"navigation"); one.URL = [NSURL URLWithString:@"https://new.example/"]; PumpMain();
    CHECK(one.setters == before, "host checked on main after navigation before job");
    one.URL = [NSURL URLWithString:@"https://example.com/"];
    one.navigateDuringSetter = [NSURL URLWithString:@"https://new.example/"];
    NSUInteger scripts = one.scripts;
    Apply(@"example.com", @"nav-in-setter"); PumpMain();
    CHECK(one.setters == before + 1 && one.scripts == scripts, "host rechecked after setter navigation before JS");
    one.navigateDuringSetter = nil; one.URL = [NSURL URLWithString:@"https://example.com/"];
    one.invalidateDuringSetter = YES;
    Apply(@"example.com", @"invalidate-in-setter"); PumpMain();
    CHECK(one.scripts == scripts && !gUASyncApplying, "setter invalidation suppresses JS and restores TLS");
    one.invalidateDuringSetter = NO;
    one.throwSetter = YES;
    Apply(@"example.com", @"throw"); PumpMain();
    CHECK(!gUASyncApplying && one.scripts == scripts, "setter exception restores TLS without JS");
    // Per-view failure cannot stop the remaining registry entries (unordered table).
    SetSync(YES, NO);
    NSUInteger otherBefore = two.setters;
    Apply(@"example.com", @"continue-after-throw"); PumpMain();
    CHECK(two.setters == otherBefore + 1, "one throwing view does not suppress other views");
    SetSync(NO, YES);
    one.throwSetter = NO; one.throwScript = YES;
    Apply(@"example.com", @"throw-js"); PumpMain();
    CHECK(!gUASyncApplying && one.scripts == scripts + 1, "JS exception restores TLS");
    one.throwScript = NO;
    gUASyncApplying = YES;
    PXUASyncApplyToView(one, @"example.com", @"nested", PXUACurrentPolicy(), PXUASyncEpoch());
    CHECK(gUASyncApplying, "nested sync restores previous true guard"); gUASyncApplying = NO;
    one.throwSetter = YES; gUASyncApplying = YES;
    @try { PXUASyncApplyToView(one, @"example.com", @"nested-throw", PXUACurrentPolicy(), PXUASyncEpoch()); }
    @catch (__unused NSException *e) { }
    CHECK(gUASyncApplying, "nested throwing sync restores previous true guard");
    gUASyncApplying = NO; one.throwSetter = NO;
    NSMutableString *host = [@"example.com" mutableCopy], *ua = [@"immutable-job" mutableCopy];
    Apply(host, ua); [host setString:@"other.com"]; [ua setString:@"mutated"]; PumpMain();
    CHECK([one.customUserAgent isEqualToString:@"immutable-job"], "queued job copies mutable host and UA inputs");
    NSString *special = @"quote'\"\\\n\r\t\u2028\u2029";
    NSString *script = PXUASyncScript(special);
    NSString *prefix = @"(function(){try{var value=";
    NSRange tail = [script rangeOfString:@";Object.defineProperty"];
    NSString *literal = [script substringWithRange:NSMakeRange(prefix.length, tail.location - prefix.length)];
    NSString *array = [NSString stringWithFormat:@"[%@]", literal];
    NSArray *decoded = [NSJSONSerialization JSONObjectWithData:[array dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    CHECK([decoded.firstObject isEqualToString:special], "JS literal roundtrips quotes slash newlines and Unicode separators");
    CHECK([script rangeOfString:@"\u2028"].location == NSNotFound && [script rangeOfString:@"\u2029"].location == NSNotFound, "legacy JS source has no raw separator characters");
    SetSync(NO, YES);
    before = one.setters;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    gViewThrows = YES;
#else
    gReadThrows = YES;
#endif
    Apply(@"example.com", @"policy-exception"); PumpMain();
    gViewThrows = NO; gReadThrows = NO;
    CHECK(one.setters == before && !gUALoadingPolicy && !gUASyncApplying, "queued policy exception is contained without poisoning guards");
    __weak WKWebView *weakView;
    @autoreleasepool {
        WKWebView *temporary = View(@"example.com"); weakView = temporary;
        Apply(@"example.com", @"pending"); temporary = nil;
    }
    CHECK(!weakView, "pending job does not retain registered view before main execution"); PumpMain();
    CHECK(gWKWebViews.count == 2, "weak registry drops deallocated views");
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        @autoreleasepool {
            WKWebView *temporary = [WKWebView new];
            PXUASyncRegisterWKWebView(temporary); temporary = nil;
            PXUASyncApplyToWebViewsForHost(@"example.com", @"background", PXUASyncEpoch());
        }
        dispatch_semaphore_signal(finished);
    });
    CHECK(dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0, "background caller returns without waiting for main");
    PumpMain();
    CHECK([one.customUserAgent isEqualToString:@"background"] && one.offMain == 0 && two.offMain == 0, "background apply touches all UI only on main");
    CHECK(gWKWebViews.count == 2, "background weak registration does not resurrect expired view");
    // Direct helper also rejects a background caller without touching the facade.
    before = one.setters;
    __weak WKWebView *weakOne = one;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        WKWebView *owner = nil;
        @try { owner = weakOne; PXUASyncApplyToView(owner, @"example.com", @"wrong-thread", PXUADefaultPolicy(), PXUASyncEpoch()); }
        @finally { owner = nil; }
        dispatch_semaphore_signal(finished);
    });
    CHECK(dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0 && one.setters == before, "direct helper rejects background UI access");
    __weak WKWebView *weakOneEnd = one; __weak WKWebView *weakTwoEnd = two;
    one = nil; two = nil; script = nil; decoded = nil; literal = nil; array = nil; special = nil; host = nil; ua = nil;
    // An autoreleasepool around SyncTests in main drains temporary allObjects snapshots.
    (void)weakOneEnd; (void)weakTwoEnd;
}

int main(void) {
    @autoreleasepool { PolicyTests(); }
    @autoreleasepool { PolicyLifetimeTests(); }
    @autoreleasepool { SyncTests(); }
    CHECK(gWKWebViews.count == 0, "registry owns no views after caller and pool release");
    gWKWebViews = nil; gView = nil; gFirst = nil; gSecond = nil; gDefaults = nil;
    fprintf(stdout, "UA policy/sync: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
    return gFailures ? 1 : 0;
}
