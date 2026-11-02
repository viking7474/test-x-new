#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import "MethodSwizzler.h"
#include <stdint.h>
#include <stdio.h>
#include <math.h>

typedef struct __WiFiNetwork *WiFiNetworkRef;
static NSUInteger gChecks, gFailures, gOperations, gScopes, gReads, gCopies, gRandomCalls;
static NSUInteger gOriginals[8];
static BOOL gAllowed, gThrowScope, gThrowRead, gThrowOriginal, gRetireInfo, gFailCopy, gThrowCopy, gNested;
static uint32_t gRandomValue, gLastUpper;
static id gInfo;
static WiFiNetworkRef gSeenNetwork;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PX_RUNTIME_READ_OPERATION do { gOperations++; } while (0)
static BOOL shouldSpoofForBundle(NSString * __unsafe_unretained bundle) {
    (void)bundle; gScopes++;
    if (gThrowScope) [NSException raise:@"fixture.scope" format:@"scope failed"];
    return gAllowed;
}
static NSDictionary *PXResolvedWiFiInfo(void) {
    gReads++;
    if (gThrowRead) [NSException raise:@"fixture.read" format:@"read failed"];
    id result = gInfo;
    if (gRetireInfo) gInfo = nil;
    return result;
}
#include "PXWiFiGetterHelpers.inc"

static void OriginalCalled(NSUInteger index) {
    gOriginals[index]++;
    if (gThrowOriginal) [NSException raise:@"fixture.original" format:@"original failed"];
}
static uint32_t PXGetterRandom(uint32_t upper) {
    gRandomCalls++; gLastUpper = upper; return gRandomValue % upper;
}
@interface PXGetterNetwork : NSObject
- (NSString *)SSID;
- (NSString *)BSSID;
- (double)signalStrength;
- (BOOL)isSecure;
@end
@implementation PXGetterNetwork
- (NSString *)SSID { OriginalCalled(0); if (gNested) (void)[self BSSID]; return @"real-ssid"; }
- (NSString *)BSSID { OriginalCalled(1); return @"real-bssid"; }
- (double)signalStrength { OriginalCalled(2); return 0.23; }
- (BOOL)isSecure { OriginalCalled(3); return NO; }
@end
@interface PXGetterNetwork (Hooks)
- (NSString *)weaponx_SSID;
- (NSString *)weaponx_BSSID;
- (double)weaponx_signalStrength;
- (BOOL)weaponx_secure;
@end
@implementation PXGetterNetwork (Hooks)
#define arc4random_uniform PXGetterRandom
#include "PXWiFiGetterMethods.inc"
#undef arc4random_uniform
@end
@interface PXGetterPath : NSObject
- (NSString *)_getSSID;
- (id)_getBSSID;
- (NSString *)originalSSID;
- (id)originalBSSID;
@end
@implementation PXGetterPath
- (NSString *)originalSSID { OriginalCalled(4); return @"path-ssid"; }
- (id)originalBSSID { OriginalCalled(5); return NSNull.null; }
// Only %orig is replaced with the typed fixture original expression.
#include "PXWiFiGetterPath.inc"
@end
static CFStringRef OriginalCFSSID(WiFiNetworkRef network) { gSeenNetwork = network; OriginalCalled(6); return CFSTR("cf-ssid"); }
static CFStringRef OriginalCFBSSID(WiFiNetworkRef network) { gSeenNetwork = network; OriginalCalled(7); return CFSTR("cf-bssid"); }
static CFStringRef PXGetterCopy(CFAllocatorRef allocator, CFStringRef value) CF_RETURNS_RETAINED;
static CFStringRef PXGetterCopy(CFAllocatorRef allocator, CFStringRef value) {
    // C borrowed input: a throwing mock must not add an ARC parameter owner.
    gCopies++;
    if (gThrowCopy) [NSException raise:@"fixture.copy" format:@"copy failed"];
    return gFailCopy ? NULL : CFStringCreateCopy(allocator, value);
}
#define CFStringCreateCopy PXGetterCopy
#include "PXWiFiGetterCF.inc"
#undef CFStringCreateCopy
@interface PXGetterThrowingValue : NSObject
@end
@implementation PXGetterThrowingValue
- (BOOL)isKindOfClass:(Class)type { (void)type; [NSException raise:@"fixture.type" format:@"type check failed"]; return NO; }
@end
static PXGetterNetwork *gNetwork;
static PXGetterPath *gPath;
static void Reset(void) {
    gInfo = nil;
    gOperations = gScopes = gReads = gCopies = gRandomCalls = 0;
    for (NSUInteger index = 0; index < 8; index++) gOriginals[index] = 0;
    gAllowed = YES;
    gThrowScope = gThrowRead = gThrowOriginal = gRetireInfo = gFailCopy = gThrowCopy = gNested = NO;
    gRandomValue = gLastUpper = 0; gSeenNetwork = NULL;
    gInfo = @{ @"ssid": @"Fáke WiFi", @"bssid": @"aB:11:22:33:44:55" };
    orig_WiFiNetworkGetSSID = OriginalCFSSID; orig_WiFiNetworkGetBSSID = OriginalCFBSSID;
}
static NSUInteger OriginalCount(void) {
    NSUInteger total = 0; for (NSUInteger index = 0; index < 8; index++) total += gOriginals[index]; return total;
}
static void Install(void) {
    [MethodSwizzler swizzleClass:PXGetterNetwork.class originalSelector:@selector(SSID) swizzledSelector:@selector(weaponx_SSID)];
    [MethodSwizzler swizzleClass:PXGetterNetwork.class originalSelector:@selector(BSSID) swizzledSelector:@selector(weaponx_BSSID)];
    [MethodSwizzler swizzleClass:PXGetterNetwork.class originalSelector:@selector(signalStrength) swizzledSelector:@selector(weaponx_signalStrength)];
    [MethodSwizzler swizzleClass:PXGetterNetwork.class originalSelector:@selector(isSecure) swizzledSelector:@selector(weaponx_secure)];
    gNetwork = [PXGetterNetwork new]; gPath = [PXGetterPath new];
}
static void TestObjectGetters(void) {
    Reset();
    CHECK([[gNetwork SSID] isEqual:@"Fáke WiFi"] && [[gNetwork BSSID] isEqual:@"aB:11:22:33:44:55"], "real runtime swizzles use typed SSID BSSID without format changes");
    CHECK([[gPath _getSSID] isEqual:@"Fáke WiFi"] && [[gPath _getBSSID] isEqual:@"aB:11:22:33:44:55"], "private path getters use the same typed preparation");
    CHECK(!OriginalCount() && gReads == 4 && gScopes == 4 && gOperations == 4, "each object getter performs one preparation and skips original on success");
    Reset(); gAllowed = NO;
    CHECK([[gNetwork SSID] isEqual:@"real-ssid"] && [[gNetwork BSSID] isEqual:@"real-bssid"], "denied swizzles forward original values");
    CHECK([[gPath _getSSID] isEqual:@"path-ssid"] && [gPath _getBSSID] == NSNull.null, "denied path preserves opaque original BSSID value");
    CHECK(OriginalCount() == 4 && !gReads && gScopes == 4, "denied getters call original once each without provider work");
    for (id root in @[NSNull.null, @42, @[], @"wrong root", @{}]) {
        Reset(); gInfo = root;
        CHECK([[gNetwork SSID] isEqual:@"real-ssid"] && [gPath _getBSSID] == NSNull.null, "missing or malformed root falls through without selectors on foreign root");
        CHECK(gOriginals[0] == 1 && gOriginals[5] == 1 && !gCopies, "malformed root forwards each original exactly once");
    }
    for (id field in @[NSNull.null, @42, @[], @{}]) {
        Reset(); gInfo = @{ @"ssid": field, @"bssid": @"ok" };
        CHECK([[gNetwork SSID] isEqual:@"real-ssid"] && [[gNetwork BSSID] isEqual:@"ok"], "each identity field is validated independently without requiring a pair");
        CHECK([gPath _getSSID] && gOriginals[0] == 1 && gOriginals[1] == 0 && gOriginals[4] == 1, "bad SSID forwards original while valid BSSID remains usable");
    }
    Reset();
    @autoreleasepool {
        NSMutableString *text = [NSMutableString stringWithString:@"mutable field identity"];
        gInfo = @{ @"ssid": text };
        CHECK([gNetwork SSID] == text && [gPath _getSSID] == text, "typed object getters preserve field object identity without copying or freezing");
    }
    Reset(); gInfo = @{ @"ssid": @"", @"bssid": @"" };
    CHECK([[gNetwork SSID] isEqual:@""] && [[gPath _getBSSID] isEqual:@""] && !OriginalCount(), "empty strings retain existing getter behavior");
    Reset(); gNested = YES; gAllowed = NO;
    CHECK([[gNetwork SSID] isEqual:@"real-ssid"] && gOriginals[0] == 1 && gOriginals[1] == 1, "original may call another hooked getter without alias recursion");
}
static void TestScalarGetters(void) {
    Reset(); gThrowRead = YES;
    CHECK(fabs([gNetwork signalStrength] - 0.70) < 1e-12 && [gNetwork isSecure], "scoped scalar getters preserve double lower bound and secure YES");
    gRandomValue = 19;
    CHECK(fabs([gNetwork signalStrength] - 0.89) < 1e-12 && gLastUpper == 20 && gRandomCalls == 2, "signal getter preserves old discrete upper bound and one random call per read");
    CHECK(!OriginalCount() && !gReads, "scalar getters never resolve unused WiFi data");
    Reset(); gAllowed = NO;
    CHECK(fabs([gNetwork signalStrength] - 0.23) < 1e-12 && ![gNetwork isSecure], "denied scalar getters preserve original ABI and values");
    CHECK(gOriginals[2] == 1 && gOriginals[3] == 1 && !gRandomCalls && !gReads, "denied scalar getters call original once without random provider work");
    Reset(); gThrowScope = YES;
    CHECK(fabs([gNetwork signalStrength] - 0.23) < 1e-12 && ![gNetwork isSecure], "scope exception safely falls through scalar getters");
}
static void TestCGetters(void) {
    WiFiNetworkRef input = (WiFiNetworkRef)(uintptr_t)0x1234;
    Reset();
    CFStringRef ssid = replaced_WiFiNetworkGetSSID(input), bssid = replaced_WiFiNetworkGetBSSID(input);
    CHECK(ssid && bssid && [(__bridge NSString *)ssid isEqual:@"Fáke WiFi"] && [(__bridge NSString *)bssid isEqual:@"aB:11:22:33:44:55"], "C getters preserve string content and existing retained spoof outputs");
    if (ssid) CFRelease(ssid); if (bssid) CFRelease(bssid);
    CHECK(gCopies == 2 && !OriginalCount(), "valid C spoof makes one Copy per read without original");
    Reset(); gAllowed = NO;
    CHECK(replaced_WiFiNetworkGetSSID(input) == CFSTR("cf-ssid") && replaced_WiFiNetworkGetBSSID(input) == CFSTR("cf-bssid"), "C fallback preserves exact original pointers without retain or release");
    CHECK(gSeenNetwork == input && gOriginals[6] == 1 && gOriginals[7] == 1 && !gCopies && !gReads, "C fallback forwards opaque argument and original once without provider or copy");
    Reset(); gInfo = @{ @"ssid": NSNull.null, @"bssid": @42 };
    CHECK(replaced_WiFiNetworkGetSSID(input) == CFSTR("cf-ssid") && replaced_WiFiNetworkGetBSSID(input) == CFSTR("cf-bssid") && !gCopies, "nonstring C values never reach CFStringCreateCopy");
    Reset(); gAllowed = NO; orig_WiFiNetworkGetSSID = NULL; orig_WiFiNetworkGetBSSID = NULL;
    CHECK(!replaced_WiFiNetworkGetSSID(input) && !replaced_WiFiNetworkGetBSSID(input), "absent C originals return NULL safely");
    Reset(); orig_WiFiNetworkGetSSID = NULL;
    ssid = replaced_WiFiNetworkGetSSID(input);
    CHECK(ssid != NULL && gCopies == 1 && !OriginalCount(), "scoped valid C spoof does not require original pointer");
    if (ssid) CFRelease(ssid);
    Reset(); gFailCopy = YES;
    CHECK(!replaced_WiFiNetworkGetSSID(input) && !replaced_WiFiNetworkGetBSSID(input) && !OriginalCount() && gCopies == 2, "Copy NULL retains previous no-original-retry behavior");
}
static void TestFailureAndLifetime(void) {
    for (NSUInteger fault = 0; fault < 2; fault++) {
        Reset(); gThrowScope = fault == 0; gThrowRead = fault == 1;
        CHECK([[gNetwork SSID] isEqual:@"real-ssid"] && [[gPath _getSSID] isEqual:@"path-ssid"] && replaced_WiFiNetworkGetBSSID(NULL) == CFSTR("cf-bssid"), "scope or provider exception falls through across all string surfaces");
        CHECK(gOriginals[0] == 1 && gOriginals[4] == 1 && gOriginals[7] == 1 && gReads == (fault == 0 ? 0 : 3), "preparation exception does not duplicate original or bypass scope admission");
    }
    for (NSUInteger index = 0; index < 8; index++) {
        Reset(); gAllowed = NO; gThrowOriginal = YES;
        BOOL raised = NO;
        @try {
            switch (index) {
                case 0: (void)[gNetwork SSID]; break;
                case 1: (void)[gNetwork BSSID]; break;
                case 2: (void)[gNetwork signalStrength]; break;
                case 3: (void)[gNetwork isSecure]; break;
                case 4: (void)[gPath _getSSID]; break;
                case 5: (void)[gPath _getBSSID]; break;
                case 6: (void)replaced_WiFiNetworkGetSSID(NULL); break;
                case 7: (void)replaced_WiFiNetworkGetBSSID(NULL); break;
            }
        } @catch (NSException *e) { raised = [e.name isEqual:@"fixture.original"]; }
        if (!raised || gOriginals[index] != 1 || OriginalCount() != 1)
            fprintf(stderr, "DETAIL: original exception getter=%lu raised=%d calls=%lu total=%lu\n", (unsigned long)index, raised, (unsigned long)gOriginals[index], (unsigned long)OriginalCount());
        CHECK(raised && gOriginals[index] == 1 && OriginalCount() == 1, "original exception propagates on every getter without catch or retry");
    }
    for (NSUInteger phase = 0; phase < 2; phase++) {
        Reset(); __weak id weakValue = nil;
        @autoreleasepool {
            id poison = [PXGetterThrowingValue new]; weakValue = poison;
            gInfo = phase == 0 ? poison : @{ @"ssid": poison };
            gRetireInfo = YES;
            CHECK([[gNetwork SSID] isEqual:@"real-ssid"], "root or field type-check exception uses original");
            poison = nil;
        }
        if (weakValue != nil) fprintf(stderr, "DETAIL: type lifetime phase=%lu scopes=%lu reads=%lu\n", (unsigned long)phase, (unsigned long)gScopes, (unsigned long)gReads);
        CHECK(weakValue == nil, "type-check exception releases helper-owned root and field references without ARC unwind cleanup");
    }
    Reset(); __weak NSString *weakText = nil;
    @autoreleasepool {
        NSMutableString *text = [NSMutableString stringWithString:@"long mutable identity for copy exception lifetime probe"];
        weakText = text; gInfo = @{ @"ssid": text }; gRetireInfo = YES; gThrowCopy = YES;
        BOOL raised = NO;
        @try { (void)replaced_WiFiNetworkGetSSID(NULL); }
        @catch (NSException *e) { raised = [e.name isEqual:@"fixture.copy"]; }
        CHECK(raised && gCopies == 1 && !OriginalCount(), "Copy exception propagates without falling back to original");
        text = nil;
    }
    CHECK(weakText == nil, "Copy exception releases the C adapter's own strong string reference");
}
int main(void) {
    @autoreleasepool {
        @try { Install(); TestObjectGetters(); TestScalarGetters(); TestCGetters(); TestFailureAndLifetime(); }
        @catch (NSException *e) { gFailures++; fprintf(stderr, "FAIL: unexpected getter exception: %s\n", e.description.UTF8String); }
        printf("WiFi getter boundaries: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
