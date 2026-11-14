#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dispatch/dispatch.h>
#import "PXUserAgentNormalizer.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static NSUInteger gChecks, gFailures, gCalls[10], gPolicyReads, gScopeReads, gVersionReads, gNormalizes, gHeaderNormalizes, gCaptures, gSyncs, gRegistrations, gUIReads;
static BOOL gAllowed = YES, gSafariPermission, gSafariStack, gFullSpoof, gOriginalThrows, gOriginalNil, gNormalizeThrows, gPolicyThrows, gTraceThrows, gConfigThrows, gURLThrows, gNativeThrows, gFallbackThrows, gSyncThrows;
static NSString *gBundle = @"fixture.app", *gProcess = @"Fixture", *gVersion = @"17.5.1";
static NSString *gNativeUA = @"Mozilla/5.0 (iPhone; CPU iPhone OS 15_8_8 like Mac OS X) AppleWebKit/605.1.15 Version/15.8 Mobile/19H1 Safari/605.1.15";
static NSDictionary *gVersionInfo;
static uint64_t gEpoch = 1, gSyncedEpoch;
static NSString *gSyncedHost, *gSyncedUA;
static void (*gDuringProvider)(void), (*gDuringNativeCustom)(void);
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PX_RUNTIME_READ_OPERATION do { gCaptures++; } while (0)
static void PXFixtureLog(NSString *__unsafe_unretained format, ...) { (void)format; }
#define IOSVERSION_LOG(...) PXFixtureLog(__VA_ARGS__)
#define UIUserInterfaceIdiomPhone 0
#define UIUserInterfaceIdiomPad 1
#define UI_USER_INTERFACE_IDIOM() UIUserInterfaceIdiomPhone
#define PXScopeOptionAllowSafariAuthStack 1
static __thread BOOL gUASyncApplying;
#include "PXUADispatchState.inc"
static PXUAPolicyValues gPolicy;
static void Raise(void) { [NSException raise:@"fixture" format:@"injected fault"]; }
static void ProviderCallback(void) { void (*callback)(void) = gDuringProvider; gDuringProvider = NULL; if (callback) callback(); }
static NSString *PXFixtureBundle(void) { ProviderCallback(); return gBundle; }
static NSString *PXFixtureProcess(void) { return gProcess; }
static NSLocale *PXFixtureLocale(void) { return [NSLocale localeWithLocaleIdentifier:@"en_US"]; }
static PXUAPolicyValues PXUACurrentPolicy(void) { gPolicyReads++; if (gPolicyThrows) Raise(); return gPolicy; }
static BOOL PXUAShouldSpoofMobileBuildToken(void) { return gPolicy.mobileBuild; }
static uint64_t PXUASyncEpoch(void) { return gEpoch; }
static BOOL PXProcessIsAllowedForSpoofing(NSString *__unsafe_unretained bundle, NSString *__unsafe_unretained process, NSUInteger option) {
    (void)bundle; (void)process; (void)option; gScopeReads++; return gSafariPermission;
}
static BOOL PXIsSafariStackProcess(NSString *__unsafe_unretained bundle, NSString *__unsafe_unretained process) { (void)bundle; (void)process; return gSafariStack; }
static BOOL PXIsSafariBrowserBundleIdentifier(NSString *__unsafe_unretained bundle) { return [bundle isEqualToString:@"com.apple.mobilesafari"]; }
static BOOL shouldSpoofForBundle(NSString *__unsafe_unretained bundle) { (void)bundle; gScopeReads++; return gAllowed; }
static BOOL PXFullSpoofTestModeEnabled(void) { return gFullSpoof; }
static BOOL PXUAHostIsSensitive(NSString *__unsafe_unretained host) { return !gFullSpoof && [host hasSuffix:@"google.com"]; }
static NSString *getSpoofedSystemVersion(void) { gVersionReads++; ProviderCallback(); return gVersion; }
static NSDictionary *getIOSVersionInfo(void) { return gVersionInfo; }
static NSString *PXFixtureNormalize(NSString *base, NSString *version, NSString *build, BOOL mobile) {
    NSString *result = nil;
    @try { gNormalizes++; if (gNormalizeThrows) Raise(); result = PXNormalizeUserAgent(base, version, build, mobile); return result; }
    @finally { base = nil; version = nil; build = nil; result = nil; }
}
static NSDictionary *PXFixtureIdentityHeaders(NSDictionary *input, NSString *locale, BOOL mobile) {
    NSDictionary *result = nil;
    @try { gHeaderNormalizes++; if (gNormalizeThrows) Raise(); result = PXCanonicalWebIdentityHeaders(input, locale, mobile); return result; }
    @finally { input = nil; locale = nil; result = nil; }
}
static void PXUADebugTrace(NSString *__unsafe_unretained event, NSString *__unsafe_unretained bundle, NSString *__unsafe_unretained process,
    NSString *__unsafe_unretained host, NSString *__unsafe_unretained decision, NSString *__unsafe_unretained reason,
    NSString *__unsafe_unretained before, NSString *__unsafe_unretained after) {
    (void)event; (void)bundle; (void)process; (void)host; (void)decision; (void)reason; (void)before; (void)after;
    if (gTraceThrows) Raise();
}
@class WKWebView;
static void PXUASyncRegisterWKWebView(WKWebView *__unsafe_unretained view) { (void)view; gRegistrations++; }
static void PXUASyncApplyToWebViewsForHost(NSString *host, NSString *ua, uint64_t epoch) {
    @try { if (gSyncThrows) Raise(); gSyncs++; gSyncedHost = [host copy]; gSyncedUA = [ua copy]; gSyncedEpoch = epoch; }
    @finally { host = nil; ua = nil; }
}
@interface WKNavigation : NSObject @end
@implementation WKNavigation @end
static WKNavigation *gNavigation;
@interface WKWebViewConfiguration : NSObject
@property (nonatomic, copy) NSString *applicationNameForUserAgent;
@end
@implementation WKWebViewConfiguration @end
// All ten exact adapter bodies live on this facade. No WebKit implementation is linked.
@interface WKWebView : NSObject
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, strong) WKWebViewConfiguration *configuration;
@property (nonatomic, copy, readonly) NSString *customUserAgent;
@property (nonatomic, strong) id nativeCustom, nativeAppName, nativeValue, nativeField;
@property (nonatomic, strong) id argument1, argument2, argument3, argument4;
+ (NSString *)_standardUserAgentWithApplicationName:(NSString *)name;
#include "PXUADispatchDeclarations.inc"
@end
@interface SFUserAgentController : NSObject
+ (NSString *)defaultUserAgentString;
@end
@implementation SFUserAgentController
+ (NSString *)defaultUserAgentString { if (gFallbackThrows) Raise(); return gNativeUA; }
@end

// Borrowed IMP-like arguments: a fault in the original fixture must not add its own C-parameter retain leak.
static WKWebView *PXOriginalInit(WKWebView *__unsafe_unretained object, CGRect frame, WKWebViewConfiguration *__unsafe_unretained config) {
    (void)frame; gCalls[0]++; if (gOriginalThrows) Raise(); if (gOriginalNil) return nil;
    object.configuration = config; return object;
}
static WKNavigation *PXOriginalRequest(WKWebView *__unsafe_unretained object, NSURLRequest *__unsafe_unretained request) {
    gCalls[1]++; if (gOriginalThrows) Raise(); object.argument1 = request; return gOriginalNil ? nil : gNavigation;
}
static WKNavigation *PXOriginalHTML(WKWebView *__unsafe_unretained object, NSString *__unsafe_unretained string, NSURL *__unsafe_unretained url) {
    gCalls[2]++; if (gOriginalThrows) Raise(); object.argument1 = string; object.argument2 = url; return gOriginalNil ? nil : gNavigation;
}
static WKNavigation *PXOriginalFile(WKWebView *__unsafe_unretained object, NSURL *__unsafe_unretained url, NSURL *__unsafe_unretained read) {
    gCalls[3]++; if (gOriginalThrows) Raise(); object.argument1 = url; object.argument2 = read; return gOriginalNil ? nil : gNavigation;
}
static WKNavigation *PXOriginalData(WKWebView *__unsafe_unretained object, NSData *__unsafe_unretained data, NSString *__unsafe_unretained mime, NSString *__unsafe_unretained encoding, NSURL *__unsafe_unretained url) {
    gCalls[4]++; if (gOriginalThrows) Raise(); object.argument1 = data; object.argument2 = mime; object.argument3 = encoding; object.argument4 = url; return gOriginalNil ? nil : gNavigation;
}
static void PXOriginalCustom(WKWebView *__unsafe_unretained object, NSString *__unsafe_unretained ua) {
    gCalls[5]++; if (gOriginalThrows) Raise(); object.nativeCustom = ua;
    void (*callback)(void) = gDuringNativeCustom; gDuringNativeCustom = NULL; if (callback) callback();
}
static void PXOriginalAppName(WKWebView *__unsafe_unretained object, NSString *__unsafe_unretained name) {
    gCalls[6]++; if (gOriginalThrows) Raise(); object.nativeAppName = name;
}
static void PXOriginalHeader(WKWebView *__unsafe_unretained object, NSString *__unsafe_unretained value, NSString *__unsafe_unretained field) {
    gCalls[7]++; if (gOriginalThrows) Raise(); object.nativeValue = value; object.nativeField = field;
}
static NSString *PXOriginalDomain(NSString *__unsafe_unretained domain) { (void)domain; gCalls[8]++; if (gOriginalThrows) Raise(); return gOriginalNil ? nil : gNativeUA; }
static NSString *PXOriginalDefault(void) { gCalls[9]++; if (gOriginalThrows) Raise(); return gOriginalNil ? nil : gNativeUA; }
#include "PXUADispatchWork.inc"
@implementation WKWebView
@synthesize configuration = _configuration, URL = _URL;
- (NSURL *)URL { gUIReads++; if (gURLThrows) Raise(); return _URL; }
- (WKWebViewConfiguration *)configuration { gUIReads++; if (gConfigThrows) Raise(); return _configuration; }
- (NSString *)customUserAgent { gUIReads++; return self.nativeCustom; }
+ (NSString *)_standardUserAgentWithApplicationName:(NSString *)name { (void)name; if (gNativeThrows) Raise(); return gNativeUA; }
#include "PXUADispatchMethods.inc"
@end

static void Reset(void) {
    gAllowed = YES; gSafariPermission = gSafariStack = gFullSpoof = NO;
    gOriginalThrows = gOriginalNil = gNormalizeThrows = gPolicyThrows = gTraceThrows = gConfigThrows = gURLThrows = gNativeThrows = gFallbackThrows = gSyncThrows = NO;
    gPXPreparingUA = gUASyncApplying = gUACanonicalApplying = NO;
    gBundle = @"fixture.app"; gProcess = @"Fixture"; gVersion = @"17.5.1";
    gVersionInfo = @{@"version": @"17.5.1", @"build": @"21F90"};
    gPolicy = (PXUAPolicyValues){0};
    gPolicy.debug.scopeSafari = gPolicy.debug.scopeSafariViewService = gPolicy.debug.scopeWebKit = YES;
    gPolicy.debug.hook_init = gPolicy.debug.hook_setCustomUserAgent = gPolicy.debug.hook_appNameUA = YES;
    gPolicy.debug.hook_requestHeaderUA = gPolicy.debug.hook_sfUserAgentWithDomain = gPolicy.debug.hook_sfDefaultUA = YES;
    gEpoch++; gSyncedHost = nil; gSyncedUA = nil; gDuringProvider = NULL; gDuringNativeCustom = NULL;
    memset(gCalls, 0, sizeof(gCalls));
    gPolicyReads = gScopeReads = gVersionReads = gNormalizes = gHeaderNormalizes = gCaptures = gSyncs = gRegistrations = gUIReads = 0;
}
static WKWebView *View(void) {
    WKWebView *view = [WKWebView new];
    view.URL = [NSURL URLWithString:@"https://example.com/"];
    view.configuration = [WKWebViewConfiguration new]; return view;
}
static NSString *Expected(NSString *source) { return PXNormalizeUserAgent(source, gVersion, gVersionInfo[@"build"], gPolicy.mobileBuild); }
static void ClearRecords(WKWebView *view) {
    view.nativeValue = nil; view.nativeField = nil; view.nativeAppName = nil;
    view.argument1 = nil; view.argument2 = nil; view.argument3 = nil; view.argument4 = nil;
}

static void AdvanceEpochProvider(void) { gEpoch++; }

static void HeaderTests(void) {
    Reset(); WKWebView *view = View();
    for (int i = 0; i < 100; i++) [view setValue:@"value" forHTTPHeaderField:@"X-Fixture"];
    CHECK(gCalls[7] == 100 && gPolicyReads == 0 && gScopeReads == 0 && gVersionReads == 0 && gCaptures == 0 && gUIReads == 0 && gNormalizes == 0 && gHeaderNormalizes == 0, "unrelated headers bypass all projection providers snapshot capture URL and collection building");
    CHECK(PXUAClassifyHeader(nil) == PXUAHeaderOther && PXUAClassifyHeader(@[]) == PXUAHeaderOther, "nil and malformed header names remain native");
    NSArray *names = @[@"User-Agent", @"user-agent", @"uSeR-aGeNt", @"USER-AGENT"];
    for (NSString *name in names) {
        NSUInteger before = gCalls[7]; [view setValue:gNativeUA forHTTPHeaderField:name];
        CHECK(gCalls[7] == before + 1 && [view.nativeValue isEqual:Expected(gNativeUA)] && view.nativeField == name, "all User-Agent casing uses one native invocation and preserves original field argument");
    }
    [view setValue:nil forHTTPHeaderField:@"user-agent"];
    CHECK(!view.nativeValue && gSyncs == 0, "nil removes a header without projection or sync");
    id malformed = @[@"wrong-value"];
    [view setValue:malformed forHTTPHeaderField:@"User-Agent"];
    CHECK(view.nativeValue == malformed, "malformed value passes to original untouched");
    [view setValue:@"x" forHTTPHeaderField:(id)NSNull.null];
    CHECK(view.nativeField == NSNull.null, "invalid field stays original responsibility");
    NSArray *managed = @[@"aCcEpT-LaNgUaGe", @"SEC-CH-UA-PLATFORM", @"sec-ch-ua-mobile"];
    NSArray *expected = @[@"en-us", @"\"iOS\"", @"?1"];
    for (NSUInteger i = 0; i < managed.count; i++) {
        NSUInteger before = gCalls[7]; [view setValue:@"old" forHTTPHeaderField:managed[i]];
        CHECK(gCalls[7] == before + 1 && [view.nativeValue isEqual:expected[i]], "managed headers retain canonical locale platform and mobile policy");
    }
    gAllowed = NO; [view setValue:gNativeUA forHTTPHeaderField:@"user-agent"];
    CHECK([view.nativeValue isEqual:gNativeUA], "unscoped UA remains native");
    gAllowed = YES; view.URL = [NSURL URLWithString:@"https://accounts.google.com/"];
    [view setValue:gNativeUA forHTTPHeaderField:@"user-agent"];
    CHECK([view.nativeValue isEqual:gNativeUA], "sensitive host UA remains native");
    view.URL = [NSURL URLWithString:@"https://example.com/"];
    gPolicy.debug.masterEnabled = YES; gPolicy.debug.hook_requestHeaderUA = NO;
    gPolicy.syncEnabled = YES;
    [view setValue:gNativeUA forHTTPHeaderField:@"user-agent"];
    CHECK([view.nativeValue isEqual:gNativeUA] && gSyncs == 1 && [gSyncedUA isEqual:Expected(gNativeUA)] && [gSyncedHost isEqual:@"example.com"] && gSyncedEpoch == gEpoch, "JS-only preserves native header and frozen sync intent after acknowledgment");
    NSUInteger syncs = gSyncs; gOriginalThrows = YES; NSUInteger before = gCalls[7]; BOOL caught = NO;
    @try { [view setValue:gNativeUA forHTTPHeaderField:@"User-Agent"]; } @catch (__unused NSException *e) { caught = YES; }
    CHECK(caught && gCalls[7] == before + 1 && gSyncs == syncs && !gPXPreparingUA, "native header exception propagates once with no JS submission");
    gOriginalThrows = NO; gSyncThrows = YES;
    [view setValue:gNativeUA forHTTPHeaderField:@"User-Agent"];
    CHECK([view.nativeValue isEqual:gNativeUA] && !gPXPreparingUA, "post-ack sync failure does not replay or negate header success");
    gSyncThrows = NO; gPolicy.debug.hook_requestHeaderUA = YES;
    gNormalizeThrows = YES; syncs = gSyncs; before = gCalls[7];
    [view setValue:gNativeUA forHTTPHeaderField:@"User-Agent"];
    CHECK(gCalls[7] == before + 1 && [view.nativeValue isEqual:gNativeUA] && gSyncs == syncs && !gPXPreparingUA, "normalizer exception falls back once and discards sync outputs");
    gNormalizeThrows = NO; gTraceThrows = YES;
    [view setValue:gNativeUA forHTTPHeaderField:@"User-Agent"];
    CHECK([view.nativeValue isEqual:gNativeUA] && gSyncs == syncs && !gPXPreparingUA, "trace exception after sync preparation cannot publish a partial intent");
    gTraceThrows = NO;
    uint64_t admittedEpoch = gEpoch; gDuringProvider = AdvanceEpochProvider;
    [view setValue:gNativeUA forHTTPHeaderField:@"User-Agent"];
    CHECK(gEpoch != admittedEpoch && gSyncedEpoch == admittedEpoch, "provider invalidation cannot be hidden by recapturing a newer sync epoch");
    gURLThrows = YES;
    [view setValue:gNativeUA forHTTPHeaderField:@"User-Agent"];
    CHECK([view.nativeValue isEqual:gNativeUA] && !gPXPreparingUA, "request URL failure preserves original header path");
    gURLThrows = NO;
    view = nil;
}

static void SetterTests(void) {
    Reset(); WKWebView *view = View();
    [view setCustomUserAgent:gNativeUA];
    CHECK(gCalls[5] == 1 && [view.customUserAgent isEqual:Expected(gNativeUA)], "custom UA uses real central normalizer once");
    CHECK([objc_getAssociatedObject(view, kPXUABaseUserAgentKey) isEqual:gNativeUA] && [objc_getAssociatedObject(view, kPXUAOwnsCustomUserAgentKey) boolValue], "raw base and ownership adopted after native acknowledgment");
    id oldBase = objc_getAssociatedObject(view, kPXUABaseUserAgentKey);
    gOriginalThrows = YES; NSUInteger before = gCalls[5]; BOOL caught = NO;
    @try { [view setCustomUserAgent:@"different"]; } @catch (__unused NSException *e) { caught = YES; }
    CHECK(caught && gCalls[5] == before + 1 && objc_getAssociatedObject(view, kPXUABaseUserAgentKey) == oldBase && !gPXPreparingUA, "throwing native setter is never replayed and prior metadata is preserved");
    gOriginalThrows = NO; gNormalizeThrows = YES;
    [view setCustomUserAgent:gNativeUA];
    CHECK([view.customUserAgent isEqual:gNativeUA] && ![objc_getAssociatedObject(view, kPXUAOwnsCustomUserAgentKey) boolValue] && !gPXPreparingUA, "projection exception accepts raw custom UA with no spoof ownership");
    gNormalizeThrows = NO;
    gPolicy.debug.masterEnabled = YES; gPolicy.debug.hook_setCustomUserAgent = NO;
    [view setCustomUserAgent:gNativeUA];
    CHECK([view.customUserAgent isEqual:gNativeUA] && ![objc_getAssociatedObject(view, kPXUAOwnsCustomUserAgentKey) boolValue], "custom UA debug disable keeps native value and unowned base");
    gPolicy.debug.masterEnabled = NO; gPolicy.debug.hook_setCustomUserAgent = YES;
    [view setCustomUserAgent:nil];
    CHECK(!view.customUserAgent && objc_getAssociatedObject(view, kPXUABaseUserAgentKey) == NSNull.null, "explicit nil records the native-default sentinel");
    for (int mode = 0; mode < 3; mode++) {
        gUASyncApplying = mode == 0; gUACanonicalApplying = mode == 1; gPXPreparingUA = mode == 2;
        NSUInteger normalizes = gNormalizes; oldBase = objc_getAssociatedObject(view, kPXUABaseUserAgentKey);
        [view setCustomUserAgent:gNativeUA];
        CHECK(gNormalizes == normalizes && objc_getAssociatedObject(view, kPXUABaseUserAgentKey) == oldBase, "internal and recursive custom setters bypass projection and metadata ownership");
    }
    gUASyncApplying = gUACanonicalApplying = gPXPreparingUA = NO;
    [view setApplicationNameForUserAgent:gNativeUA];
    CHECK([view.nativeAppName isEqual:Expected(gNativeUA)] && gCalls[6] == 1, "application-name setter preserves real UA normalization");
    before = gCalls[6]; caught = NO; gOriginalThrows = YES;
    @try { [view setApplicationNameForUserAgent:gNativeUA]; } @catch (__unused NSException *e) { caught = YES; }
    CHECK(caught && gCalls[6] == before + 1 && !gPXPreparingUA, "application-name native exception propagates once");
    gOriginalThrows = NO; gPolicyThrows = YES;
    [view setApplicationNameForUserAgent:gNativeUA];
    CHECK([view.nativeAppName isEqual:gNativeUA] && !gPXPreparingUA, "application-name policy failure falls back to raw input");
    gPolicyThrows = NO;
    gPolicy.debug.masterEnabled = YES; gPolicy.debug.hook_appNameUA = NO;
    [view setApplicationNameForUserAgent:gNativeUA];
    CHECK([view.nativeAppName isEqual:gNativeUA], "application-name debug toggle bypasses normalization");
    gPolicy.debug.masterEnabled = NO; gPolicy.debug.hook_appNameUA = YES;
    gSafariPermission = gSafariStack = YES;
    [view setApplicationNameForUserAgent:gNativeUA];
    CHECK([view.nativeAppName isEqual:gNativeUA], "Safari stack application-name remains native outside FullSpoof");
    gFullSpoof = YES; [view setApplicationNameForUserAgent:gNativeUA];
    CHECK([view.nativeAppName isEqual:Expected(gNativeUA)], "FullSpoof preserves intentional Safari-stack application-name override");
    view = nil; oldBase = nil;
}

static void LoadTests(void) {
    Reset(); WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    WKWebView *view = [[WKWebView alloc] initWithFrame:(CGRect){0} configuration:config];
    CHECK(view && gCalls[0] == 1 && gRegistrations == 1, "constructor returns native result and registers once");
    CHECK([view.customUserAgent isEqual:Expected(gNativeUA)], "canonical UA installed synchronously before first load");
    NSURL *url = [NSURL URLWithString:@"https://example.com/"], *read = [NSURL URLWithString:@"https://example.com/read/"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSData *data = [@"body" dataUsingEncoding:NSUTF8StringEncoding];
    CHECK([view loadRequest:request] == gNavigation && view.argument1 == request, "loadRequest returns native navigation and identical request");
    CHECK([view loadHTMLString:@"html" baseURL:url] == gNavigation && [view.argument1 isEqual:@"html"] && view.argument2 == url, "HTML load preserves payload base URL and native return");
    CHECK([view loadFileURL:url allowingReadAccessToURL:read] == gNavigation && view.argument1 == url && view.argument2 == read, "file load preserves both URL arguments");
    CHECK([view loadData:data MIMEType:@"text/html" characterEncodingName:@"utf-8" baseURL:url] == gNavigation && view.argument1 == data && [view.argument2 isEqual:@"text/html"] && [view.argument3 isEqual:@"utf-8"] && view.argument4 == url, "data load preserves all arguments and native return");
    gConfigThrows = YES;
    for (NSUInteger i = 1; i <= 4; i++) {
        NSUInteger before = gCalls[i]; WKNavigation *result = nil;
        if (i == 1) result = [view loadRequest:request];
        if (i == 2) result = [view loadHTMLString:@"html" baseURL:url];
        if (i == 3) result = [view loadFileURL:url allowingReadAccessToURL:read];
        if (i == 4) result = [view loadData:data MIMEType:@"text/html" characterEncodingName:@"utf-8" baseURL:url];
        CHECK(result == gNavigation && gCalls[i] == before + 1 && !gPXPreparingUA, "each load survives preparation failure and delegates once");
    }
    gConfigThrows = NO; gOriginalThrows = YES;
    for (NSUInteger i = 1; i <= 4; i++) {
        NSUInteger before = gCalls[i]; BOOL caught = NO;
        @try {
            if (i == 1) (void)[view loadRequest:request];
            if (i == 2) (void)[view loadHTMLString:@"html" baseURL:url];
            if (i == 3) (void)[view loadFileURL:url allowingReadAccessToURL:read];
            if (i == 4) (void)[view loadData:data MIMEType:@"text/html" characterEncodingName:@"utf-8" baseURL:url];
        } @catch (__unused NSException *e) { caught = YES; }
        CHECK(caught && gCalls[i] == before + 1 && !gPXPreparingUA, "each load original exception propagates without replay or poisoned guard");
    }
    gOriginalThrows = NO; gAllowed = NO;
    (void)[view loadRequest:request];
    CHECK([view.customUserAgent isEqual:gNativeUA] && ![objc_getAssociatedObject(view, kPXUAOwnsCustomUserAgentKey) boolValue], "canonical load restores raw base when spoofing no longer applies");
    gAllowed = YES; gNativeThrows = gFallbackThrows = YES; gPolicyThrows = YES;
    WKWebView *other = [[WKWebView alloc] initWithFrame:(CGRect){0} configuration:config];
    CHECK(other && gCalls[0] == 2 && !gPXPreparingUA, "native base and canonical policy failures cannot block successful constructor");
    gPolicyThrows = gNativeThrows = gFallbackThrows = NO; gOriginalNil = YES;
    other = [[WKWebView alloc] initWithFrame:(CGRect){0} configuration:config];
    CHECK(!other && gCalls[0] == 3, "nil constructor remains nil without registration retry");
    gOriginalNil = NO; gOriginalThrows = YES;
    NSUInteger ctorBefore = gCalls[0]; BOOL ctorCaught = NO;
    @try { other = [[WKWebView alloc] initWithFrame:(CGRect){0} configuration:config]; }
    @catch (__unused NSException *e) { ctorCaught = YES; }
    CHECK(ctorCaught && gCalls[0] == ctorBefore + 1 && !gPXPreparingUA, "constructor original exception propagates once without retry");
    gOriginalThrows = NO;
    ClearRecords(view); view = nil; other = nil; config = nil; request = nil; data = nil; url = nil; read = nil;
}

static void SafariTests(void) {
    Reset(); gBundle = @"com.apple.mobilesafari"; gProcess = @"MobileSafari";
    NSString *ua = [WKWebView userAgentWithDomain:@"example.com"];
    CHECK([ua isEqual:Expected(gNativeUA)] && gCalls[8] == 1, "Safari domain getter projects once with configured version");
    ua = [WKWebView userAgentWithDomain:@"accounts.google.com"];
    CHECK([ua isEqual:gNativeUA], "Safari sensitive domain retains native UA");
    gSafariPermission = YES;
    ua = [WKWebView defaultUserAgentString];
    CHECK([ua isEqual:gNativeUA] && gCalls[9] == 1, "Safari default stays native outside FullSpoof");
    gFullSpoof = YES; ua = [WKWebView defaultUserAgentString];
    CHECK([ua isEqual:Expected(gNativeUA)], "Safari FullSpoof default remains projectable");
    gNormalizeThrows = YES; ua = [WKWebView userAgentWithDomain:@"example.com"];
    CHECK([ua isEqual:gNativeUA] && !gPXPreparingUA, "Safari projection exception returns original result and releases guard");
    gNormalizeThrows = NO;
    for (int mode = 0; mode < 2; mode++) {
        NSUInteger before = gCalls[mode ? 9 : 8]; BOOL caught = NO; gOriginalThrows = YES;
        @try { if (mode) (void)[WKWebView defaultUserAgentString]; else (void)[WKWebView userAgentWithDomain:@"example.com"]; }
        @catch (__unused NSException *e) { caught = YES; }
        CHECK(caught && gCalls[mode ? 9 : 8] == before + 1 && !gPXPreparingUA, "Safari original exception is not swallowed or replayed");
    }
    gOriginalThrows = NO;
    gPolicy.debug.masterEnabled = YES; gPolicy.debug.scopeSafari = NO;
    CHECK([[WKWebView userAgentWithDomain:@"example.com"] isEqual:gNativeUA] && [[WKWebView defaultUserAgentString] isEqual:gNativeUA], "Safari debug scope packet disables both projections");
    gPolicy.debug.scopeSafari = YES; gPolicy.debug.hook_sfUserAgentWithDomain = gPolicy.debug.hook_sfDefaultUA = NO;
    CHECK([[WKWebView userAgentWithDomain:@"example.com"] isEqual:gNativeUA] && [[WKWebView defaultUserAgentString] isEqual:gNativeUA], "Safari per-method toggles preserve original getter values");
    gPolicy.debug.masterEnabled = NO; gOriginalNil = YES;
    CHECK(![WKWebView userAgentWithDomain:@"example.com"] && ![WKWebView defaultUserAgentString], "nil Safari originals are preserved");
    gOriginalNil = NO; gPXPreparingUA = YES;
    ua = [WKWebView userAgentWithDomain:@"example.com"];
    CHECK([ua isEqual:gNativeUA] && gPXPreparingUA, "Safari nested preparation bypass preserves previous true guard");
    gPXPreparingUA = NO; ua = nil;
}

static WKWebView *gReentryView;
static __weak WKWebView *gDroppedProbe;
static BOOL gAliveAfterDrop;
static void ReenterProvider(void) { [gReentryView setValue:@"nested-raw" forHTTPHeaderField:@"User-Agent"]; }
static void ReenterNativeSetter(void) { [gReentryView setCustomUserAgent:@"nested-native-user-agent"]; }
static void DropReceiver(void) {
    gReentryView = nil;
    WKWebView *probe = gDroppedProbe;
    gAliveAfterDrop = probe != nil;
    probe = nil;
}
static void ReentryAndLifetimeTests(void) {
    Reset(); WKWebView *view = View(); gReentryView = view; gDuringProvider = ReenterProvider;
    [view setValue:gNativeUA forHTTPHeaderField:@"User-Agent"];
    CHECK(gCalls[7] == 2 && gNormalizes == 1 && [view.nativeValue isEqual:Expected(gNativeUA)] && !gPXPreparingUA, "provider reentry calls each native setter once without recursive projection");
    gDuringNativeCustom = ReenterNativeSetter;
    [view setCustomUserAgent:gNativeUA];
    CHECK([view.customUserAgent isEqual:@"nested-native-user-agent"] &&
        [objc_getAssociatedObject(view, kPXUABaseUserAgentKey) isEqual:@"nested-native-user-agent"] &&
        ![objc_getAssociatedObject(view, kPXUAOwnsCustomUserAgentKey) boolValue], "outer native setter cannot overwrite metadata accepted by a newer reentrant setter");
    gReentryView = nil;
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    __weak WKWebView *weakView = view;
    NSUInteger reads = gUIReads;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        WKWebView *owner = nil;
        @try { owner = weakView; [owner setCustomUserAgent:gNativeUA]; (void)[owner loadHTMLString:@"background" baseURL:nil]; }
        @finally { owner = nil; }
        dispatch_semaphore_signal(finished);
    });
    CHECK(dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0, "background adapter passthrough completes");
    CHECK(gUIReads == reads && [view.nativeCustom isEqual:gNativeUA] && [view.argument1 isEqual:@"background"], "invalid UI-thread callers acquire no extra WebView properties and retain native invocation");
    ClearRecords(view); view = nil;
    for (int fault = 0; fault < 3; fault++) {
        __weak WKWebView *weakOwner;
        __weak NSString *weakInput;
        @autoreleasepool {
            WKWebView *owner = nil;
            NSString *input = nil;
            @try {
                Reset(); owner = View(); weakOwner = owner;
                input = [gNativeUA mutableCopy]; weakInput = input;
                if (fault == 0) { gNormalizeThrows = YES; [owner setValue:input forHTTPHeaderField:@"User-Agent"]; }
                if (fault == 1) { gOriginalThrows = YES; [owner setCustomUserAgent:input]; }
                if (fault == 2) { gOriginalThrows = YES; PXUASetExactCustomUserAgent(owner, input, YES); }
            } @catch (__unused NSException *e) { }
            @finally { ClearRecords(owner); owner = nil; input = nil; }
        }
        CHECK(!weakOwner && !weakInput, "adapter and exact setter release inputs and owner after exceptional exit and pool drain");
    }
    Reset();
    for (int boundary = 0; boundary < 2; boundary++) {
        __weak WKWebView *weakDropped;
        @autoreleasepool {
            // Direct +1 construction avoids depending on autoreleased factory lifetime.
            gReentryView = [WKWebView new];
            gReentryView.configuration = [WKWebViewConfiguration new];
            gReentryView.URL = [NSURL URLWithString:@"https://example.com/"];
            weakDropped = gReentryView; gDroppedProbe = gReentryView; gAliveAfterDrop = NO;
            __unsafe_unretained WKWebView *borrowed = gReentryView;
            if (boundary == 0) { gDuringNativeCustom = DropReceiver; [borrowed setCustomUserAgent:gNativeUA]; }
            else { gDuringProvider = DropReceiver; [borrowed setValue:gNativeUA forHTTPHeaderField:@"User-Agent"]; }
            borrowed = nil;
            CHECK(gAliveAfterDrop, "receiver remains alive inside the provider/native callback that drops its external owner");
        }
        gDroppedProbe = nil;
        CHECK(!weakDropped && !gReentryView, "precise receiver lifetime spans provider/native owner removal without retaining the view afterward");
    }
    Reset();
}

int main(void) {
    gNavigation = [WKNavigation new];
    @autoreleasepool { HeaderTests(); }
    @autoreleasepool { SetterTests(); }
    @autoreleasepool { LoadTests(); }
    @autoreleasepool { SafariTests(); }
    @autoreleasepool { ReentryAndLifetimeTests(); }
    gNavigation = nil; gVersionInfo = nil; gSyncedUA = nil; gSyncedHost = nil;
    fprintf(stdout, "UA hook dispatch: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
    return gFailures ? 1 : 0;
}
