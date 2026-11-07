#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdint.h>
#include <stdio.h>

static NSUInteger gChecks, gFailures, gOriginalCalls, gScopeCalls, gWiFiReads, gOperations;
static NSUInteger gBridgeCalls, gSourceReleases, gCopies, gDeaths;
static BOOL gAllowed, gThrowScope, gThrowWiFi, gFailBridge, gThrowBridge, gThrowCopy, gThrowOriginal, gThrowRelease;
static int gOriginalKind, gArrayKind, gStatus;
static id gWiFi, gScanOriginal;
static CFTypeRef gLastOriginal;
static CFDictionaryRef *gWatchedOutput, *gSeenOutput;
static CFDictionaryRef gSeenInitial;
static NSUInteger gScanCopyMode, gScanWrites, gScanWriteFailure, gScanCopyDeaths, gScanStandardDeaths;
static __weak id gScanWorkingCopy, gBridgeInput;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PX_RUNTIME_READ_OPERATION do { gOperations++; } while (0)
static BOOL shouldSpoofForBundle(NSString *bundle) {
    (void)bundle; gScopeCalls++;
    if (gThrowScope) [NSException raise:@"fixture.scope" format:@"scope failed"];
    return gAllowed;
}
static NSDictionary *PXResolvedWiFiInfo(void) {
    gWiFiReads++;
    if (gThrowWiFi) [NSException raise:@"fixture.wifi" format:@"WiFi failed"];
    return gWiFi;
}
@interface PXWiFiEncodingFailure : NSObject
@end
@implementation PXWiFiEncodingFailure
- (BOOL)isKindOfClass:(Class)type { return type == NSString.class || [super isKindOfClass:type]; }
- (NSUInteger)length { return 5; }
- (NSData *)dataUsingEncoding:(NSStringEncoding)encoding {
    (void)encoding; [NSException raise:@"fixture.encoding" format:@"encoding failed"]; return nil;
}
@end
@interface PXWiFiCFProbe : NSObject
@end
@implementation PXWiFiCFProbe
- (void)dealloc { gDeaths++; }
@end
static CFTypeRef OwnedOriginal(id value) CF_RETURNS_RETAINED;
static CFTypeRef OwnedOriginal(id value) { gLastOriginal = CFRetain((__bridge CFTypeRef)value); return gLastOriginal; }
static CFDictionaryRef OriginalDictionary(void) {
    @autoreleasepool {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:@{ @"SSID": @"real", @"BSSID": @"real-mac", @"RSSI": @-50 }];
        dict[@"probe"] = [PXWiFiCFProbe new];
        return (CFDictionaryRef)OwnedOriginal(dict);
    }
}
static CFDictionaryRef OriginalNetwork(CFStringRef interface) {
    (void)interface; gOriginalCalls++;
    if (gThrowOriginal) [NSException raise:@"fixture.original" format:@"original failed"];
    return gOriginalKind ? OriginalDictionary() : NULL;
}
static CFArrayRef OriginalInterfaces(void) {
    gOriginalCalls++;
    if (gThrowOriginal) [NSException raise:@"fixture.original" format:@"original failed"];
    @autoreleasepool {
        if (!gArrayKind) return NULL;
        if (gArrayKind == 3) return (CFArrayRef)OwnedOriginal(@"unexpected-type");
        NSMutableArray *array = [[NSMutableArray alloc] init];
        if (gArrayKind == 2) [array addObjectsFromArray:@[@"en1", @"en0"]];
        return (CFArrayRef)OwnedOriginal(array);
    }
}
static int OriginalApple(void *handle, CFDictionaryRef *info) {
    (void)handle; gOriginalCalls++; gSeenOutput = info; gSeenInitial = info ? *info : NULL;
    if (info && gOriginalKind == 1) *info = OriginalDictionary();
    if (info && gOriginalKind == 2) *info = (CFDictionaryRef)OwnedOriginal(@"unexpected-type");
    if (gThrowOriginal) [NSException raise:@"fixture.original" format:@"original failed after output"];
    return gStatus;
}
static id OriginalScan(id __unsafe_unretained self, SEL command, id __unsafe_unretained input) {
    (void)self; (void)command; (void)input; gOriginalCalls++;
    if (gThrowOriginal) [NSException raise:@"fixture.original" format:@"original failed"];
    return gScanOriginal;
}
// Borrowed C input matches the bridge operation. An ARC-strong id parameter
// can itself retain the copied dictionary at -O0 and leak that reference when
// the injected exception unwinds without -fobjc-arc-exceptions. The caller's
// explicit cleanup cannot release a callee-owned parameter reference.
static CFTypeRef PXFixtureBridge(CFTypeRef value) CF_RETURNS_RETAINED;
static CFTypeRef PXFixtureBridge(CFTypeRef value) {
    gBridgeCalls++; gBridgeInput = (__bridge id)value;
    if (gThrowBridge) [NSException raise:@"fixture.bridge" format:@"retain failed"];
    return gFailBridge ? NULL : CFRetain(value);
}
static void PXFixtureRelease(CFTypeRef value) {
    gSourceReleases++;
    if (value == gLastOriginal && gWatchedOutput) {
        CHECK(*gWatchedOutput && (CFTypeRef)*gWatchedOutput != value && CFGetTypeID(*gWatchedOutput) == CFDictionaryGetTypeID(),
              "Apple output is published before original release can observe or reenter it");
        gWatchedOutput = NULL;
    }
    CFRelease(value);
    if (gThrowRelease) { gThrowRelease = NO; [NSException raise:@"fixture.release" format:@"release callback failed"]; }
}
// These stand-ins expose only the scan preparation selectors. Throwing
// collaborators borrow parameters so they do not invent a callee-owned ARC leak.
@interface PXWiFiScanCopy : NSObject
@property (nonatomic, strong) NSMutableDictionary *record;
@end
@implementation PXWiFiScanCopy
- (BOOL)isKindOfClass:(Class)type {
    return type == NSMutableDictionary.class || type == NSDictionary.class || [super isKindOfClass:type];
}
- (void)setObject:(id __unsafe_unretained)value forKeyedSubscript:(id __unsafe_unretained)key {
    self.record[key] = value;
    if (++gScanWrites == gScanWriteFailure) [NSException raise:@"fixture.scan-write" format:@"scan mutation failed"];
}
- (void)dealloc { gScanCopyDeaths++; }
@end
@interface PXWiFiScanStandard : NSObject
@end
@implementation PXWiFiScanStandard
- (BOOL)isKindOfClass:(Class)type { return type == NSString.class || [super isKindOfClass:type]; }
- (BOOL)containsString:(NSString * __unsafe_unretained)value {
    (void)value; [NSException raise:@"fixture.scan-standard" format:@"standard classification failed"]; return NO;
}
- (void)dealloc { gScanStandardDeaths++; }
@end
@interface NSObject (PXWiFiCFCopyFixture)
- (id)px_cfMutableCopy NS_RETURNS_RETAINED;
@end
@implementation NSObject (PXWiFiCFCopyFixture)
- (id)px_cfMutableCopy {
    gCopies++;
    if (gThrowCopy) [NSException raise:@"fixture.copy" format:@"copy failed"];
    if (gScanCopyMode == 1) {
        PXWiFiScanCopy *copy = [PXWiFiScanCopy new]; copy.record = [self mutableCopy];
        gScanWorkingCopy = copy; return copy;
    }
    if (gScanCopyMode == 2) return @[];
    if (gScanCopyMode == 3) return nil;
    return [self mutableCopy];
}
@end
// The seven bodies and five original-pointer declarations are exact source.
// Only external CF retain/release and mutable-copy collaborators are controlled.
#undef CFBridgingRetain
#define CFBridgingRetain(value) PXFixtureBridge((__bridge CFTypeRef)(value))
#define CFRelease PXFixtureRelease
#define mutableCopy px_cfMutableCopy
#include "PXWiFiCFHooks.inc"
#undef mutableCopy
#undef CFRelease
#undef CFBridgingRetain

static void Reset(void) {
    gOriginalCalls = gScopeCalls = gWiFiReads = gOperations = gBridgeCalls = gSourceReleases = gCopies = gDeaths = 0;
    gAllowed = YES; gThrowScope = gThrowWiFi = gFailBridge = gThrowBridge = gThrowCopy = gThrowOriginal = gThrowRelease = NO;
    gOriginalKind = 1; gArrayKind = 1; gStatus = 17; gLastOriginal = NULL; gWatchedOutput = NULL; gSeenOutput = NULL; gSeenInitial = NULL;
    gWiFi = @{ @"ssid": @"Fake WiFi", @"bssid": @"02:11:22:33:44:55", @"wifiStandard": @"802.11ax" };
    gScanOriginal = @{ @"SSID": @"real", @"BSSID": @"real-mac", @"keep": @YES, @"WifiStandard": @99 };
    orig_CNCopyCurrentNetworkInfo = OriginalNetwork;
    orig_CNCopySupportedInterfaces = OriginalInterfaces;
    orig_Apple80211GetInfoCopy = OriginalApple;
    orig_dictionaryWithScanResult = OriginalScan;
    gScanCopyMode = gScanWrites = gScanWriteFailure = gScanCopyDeaths = gScanStandardDeaths = 0;
    gScanWorkingCopy = nil; gBridgeInput = nil;
}
static void TestLifetimeOracle(void) {
    Reset();
    @autoreleasepool {
        CFDictionaryRef original = OriginalDictionary();
        CFTypeRef extraOwner = CFRetain(original);
        CFRelease(original);
        CHECK(gDeaths == 0, "lifetime oracle detects a deliberately surviving CF owner");
        CFRelease(extraOwner);
    }
    CHECK(gDeaths == 1, "lifetime oracle requires destruction after the final real CF owner releases");
}
static void TestNetworkCopy(void) {
    Reset();
    @autoreleasepool {
        CFDictionaryRef result = replaced_CNCopyCurrentNetworkInfo(CFSTR("en0"));
        NSDictionary *dict = (__bridge NSDictionary *)result;
        CHECK([dict[@"SSID"] isEqual:@"Fake WiFi"] && [dict[@"ssid"] isEqual:dict[@"SSID"]] &&
              [dict[@"BSSID"] isEqual:dict[@"bssid"]] && [dict[@"SSIDDATA"] isEqual:[@"Fake WiFi" dataUsingEncoding:NSUTF8StringEncoding]] &&
              gOriginalCalls == 1 && gBridgeCalls == 1 && gSourceReleases == 1, "network Copy preserves key aliases UTF8 data and one original replacement ownership");
        CFRelease(result);
    }
    CHECK(gDeaths == 1, "replaced original network graph is released without a retained result leak");
    for (NSUInteger fault = 0; fault < 5; fault++) {
        Reset(); gAllowed = fault != 0; gThrowWiFi = fault == 1; gFailBridge = fault == 2; gThrowBridge = fault == 3; gThrowScope = fault == 4;
        @autoreleasepool {
            CFDictionaryRef result = replaced_CNCopyCurrentNetworkInfo(CFSTR("en0"));
            CHECK(result == gLastOriginal && gOriginalCalls == 1 && !gSourceReleases, "denied or failed replacement keeps original owned network result alive");
            CFRelease(result);
        }
        CHECK(gDeaths == 1, "caller releases exactly the surviving original network result");
    }
    Reset(); gThrowRelease = YES; BOOL threw = NO;
    @autoreleasepool {
        @try { (void)replaced_CNCopyCurrentNetworkInfo(CFSTR("en0")); }
        @catch (NSException *exception) { (void)exception; threw = YES; }
    }
    CHECK(threw && gSourceReleases == 2 && gDeaths == 1, "release exception propagates and cleans unreturned replacement instead of returning freed original");
    Reset(); gThrowOriginal = YES; threw = NO;
    @try { (void)replaced_CNCopyCurrentNetworkInfo(CFSTR("en0")); }
    @catch (NSException *exception) { (void)exception; threw = YES; }
    CHECK(threw && gOriginalCalls == 1 && !gWiFiReads, "original network exception stays outside replacement catch");
    Reset(); orig_CNCopyCurrentNetworkInfo = NULL;
    CFDictionaryRef synthesized = replaced_CNCopyCurrentNetworkInfo(CFSTR("en0"));
    CHECK(synthesized && !gOriginalCalls && !gSourceReleases && gBridgeCalls == 1, "missing original network function can still return a retained scoped result");
    CFRelease(synthesized);
    Reset(); gWiFi = NSNull.null;
    CFDictionaryRef preserved = replaced_CNCopyCurrentNetworkInfo(CFSTR("en0"));
    CHECK((CFTypeRef)preserved == gLastOriginal && !gBridgeCalls && !gSourceReleases, "malformed network record never enters the CF builder");
    CFRelease(preserved);
    Reset();
    CHECK(!PXCreateSpoofedNetworkInfoDict((id)@7, @"mac") && !PXCreateSpoofedNetworkInfoDict(@"", @"mac") && !gBridgeCalls,
          "network dictionary builder rejects malformed or empty strings before allocation and encoding");
}
static void TestPreparationLifetime(void) {
    for (NSUInteger fault = 0; fault < 2; fault++) {
        Reset(); gFailBridge = fault == 0; gThrowBridge = fault == 1;
        __weak id weakInfo = nil, weakSSID = nil, weakBSSID = nil;
        @autoreleasepool {
            gWiFi = [@{ @"ssid": [@"owned WiFi" mutableCopy], @"bssid": [@"02:11:22:33:44:55" mutableCopy] } mutableCopy];
            weakInfo = gWiFi; weakSSID = gWiFi[@"ssid"]; weakBSSID = gWiFi[@"bssid"];
            CFDictionaryRef result = replaced_CNCopyCurrentNetworkInfo(CFSTR("en0"));
            CHECK((CFTypeRef)result == gLastOriginal && gOriginalCalls == 1 && gBridgeCalls == 1 && !gSourceReleases,
                  "network failed retain keeps the caller-owned original and never retries");
            if (result) CFRelease(result); gWiFi = nil;
        }
        if (weakInfo || weakSSID || weakBSSID || gBridgeInput)
            fprintf(stderr, "DETAIL: network preparation fault=%s info=%d ssid=%d bssid=%d builder=%d\n",
                    fault == 0 ? "bridge-null" : "bridge-throw", weakInfo != nil, weakSSID != nil, weakBSSID != nil, gBridgeInput != nil);
        CHECK(!weakInfo && !weakSSID && !weakBSSID && !gBridgeInput,
              "network preparation failure releases provider root builder dictionary and mutable fields after pool drain");
    }
    Reset(); __weak id weakSSID = nil, weakBSSID = nil; BOOL threw = NO;
    @autoreleasepool {
        id ssid = [PXWiFiEncodingFailure new]; NSString *bssid = [@"02:11:22:33:44:55" mutableCopy];
        weakSSID = ssid; weakBSSID = bssid;
        @try { CFDictionaryRef value = PXCreateSpoofedNetworkInfoDict(ssid, bssid); if (value) CFRelease(value); }
        @catch (NSException *exception) { threw = [exception.name isEqual:@"fixture.encoding"]; }
        CHECK(threw && !gBridgeCalls && !gOriginalCalls, "network builder encoding exception propagates before ownership transfer");
        ssid = nil; bssid = nil;
    }
    CHECK(!weakSSID && !weakBSSID, "network builder encoding unwind releases its dictionary and both input parameters");
    Reset();
    @autoreleasepool {
        NSString *ssid = [@"retained output" mutableCopy], *bssid = [@"02:11:22:33:44:55" mutableCopy];
        weakSSID = ssid; weakBSSID = bssid;
        CFDictionaryRef value = PXCreateSpoofedNetworkInfoDict(ssid, bssid);
        ssid = nil; bssid = nil;
        CHECK(value && gBridgeInput == (__bridge id)value && weakSSID && weakBSSID && gBridgeCalls == 1,
              "network builder result keeps its independent CF owner after local cleanup");
        if (value) CFRelease(value);
    }
    CHECK(!weakSSID && !weakBSSID && !gBridgeInput,
          "network builder output and descendants die after caller release and pool drain");
    for (NSUInteger fault = 0; fault < 2; fault++) {
        Reset(); gFailBridge = fault == 0; gThrowBridge = fault == 1;
        CFArrayRef value = replaced_CNCopySupportedInterfaces();
        CHECK(value && (CFTypeRef)value == gLastOriginal && CFArrayGetCount(value) == 0 && gOriginalCalls == 1 &&
              gBridgeCalls == 1 && gScopeCalls == 1 && !gSourceReleases,
              "interface failed retain preserves the original owned empty array without retry");
        if (value) CFRelease(value);
    }
    Reset(); gThrowOriginal = YES; threw = NO;
    @try { (void)replaced_CNCopySupportedInterfaces(); }
    @catch (NSException *exception) { threw = [exception.name isEqual:@"fixture.original"]; }
    CHECK(threw && gOriginalCalls == 1 && !gScopeCalls && !gBridgeCalls,
          "interface original exception propagates before scope or preparation");
    for (NSUInteger fault = 0; fault < 2; fault++) {
        Reset(); gAllowed = fault != 0; gThrowScope = fault == 1;
        CFArrayRef value = replaced_CNCopySupportedInterfaces();
        CHECK(value && (CFTypeRef)value == gLastOriginal && CFArrayGetCount(value) == 0 && gOriginalCalls == 1 && !gBridgeCalls && !gSourceReleases,
              "interface denied or throwing scope preserves its original without synthesis");
        if (value) CFRelease(value);
    }
}
static void TestNetworkAdapterFieldOwnership(void) {
    Reset(); __weak id weakInfo = nil, weakSSID = nil, weakBSSID = nil;
    @autoreleasepool {
        id ssid = [PXWiFiEncodingFailure new]; NSString *bssid = [@"02:11:22:33:44:55" mutableCopy];
        gWiFi = [@{ @"ssid": ssid, @"bssid": bssid } mutableCopy];
        weakInfo = gWiFi; weakSSID = ssid; weakBSSID = bssid;
        CFDictionaryRef result = replaced_CNCopyCurrentNetworkInfo(CFSTR("en0"));
        CHECK(result && (CFTypeRef)result == gLastOriginal && gOriginalCalls == 1 && gWiFiReads == 1 && !gBridgeCalls && !gSourceReleases,
              "network adapter encoding failure preserves original ownership without retry or a replacement retain");
        if (result) CFRelease(result); gWiFi = nil; ssid = nil; bssid = nil;
    }
    CHECK(!weakInfo && !weakSSID && !weakBSSID && !gBridgeInput,
          "network adapter releases named accessor results after builder encoding unwind and pool drain");
    Reset(); CFDictionaryRef result = NULL;
    @autoreleasepool {
        gWiFi = [@{ @"ssid": [@"caller-owned result" mutableCopy], @"bssid": [@"02:11:22:33:44:55" mutableCopy] } mutableCopy];
        weakInfo = gWiFi; weakSSID = gWiFi[@"ssid"]; weakBSSID = gWiFi[@"bssid"];
        result = replaced_CNCopyCurrentNetworkInfo(CFSTR("en0")); gWiFi = nil;
    }
    @autoreleasepool {
        CHECK(result && !weakInfo && weakSSID && weakBSSID && gBridgeInput == (__bridge id)result &&
              gOriginalCalls == 1 && gWiFiReads == 1 && gBridgeCalls == 1 && gSourceReleases == 1,
              "network adapter result keeps mutable fields alive independently after provider and named caller cleanup");
    } // Drain weak-load observations before dropping the caller's final CF owner.
    if (result) CFRelease(result); result = NULL;
    CHECK(!weakSSID && !weakBSSID && !gBridgeInput,
          "network adapter mutable fields release after caller CF release with no stranded accessor temporary");
}
static void TestInterfaces(void) {
    for (int kind = 0; kind < 4; kind++) {
        Reset(); gArrayKind = kind;
        CFArrayRef result = replaced_CNCopySupportedInterfaces();
        if (kind <= 1) CHECK(CFArrayGetCount(result) == 1 && CFEqual(CFArrayGetValueAtIndex(result, 0), CFSTR("en0")) &&
            gBridgeCalls == 1 && gSourceReleases == (kind == 1), "missing or empty interfaces synthesize retained en0 after preparation");
        else CHECK(result == gLastOriginal && gOperations == 1 && !gScopeCalls && !gBridgeCalls && !gSourceReleases,
            "nonempty or unexpected valid CF interface result preserves operation while bypassing scope and replacement work");
        if (kind == 2) CHECK(CFEqual(CFArrayGetValueAtIndex(result, 0), CFSTR("en1")), "original interface order is preserved");
        CFRelease(result);
    }
    Reset(); orig_CNCopySupportedInterfaces = NULL;
    CFArrayRef synthesized = replaced_CNCopySupportedInterfaces();
    CHECK(synthesized && !gOriginalCalls && !gSourceReleases && CFArrayGetCount(synthesized) == 1,
          "missing original interface function keeps scoped synthesis without a null call"); CFRelease(synthesized);
    Reset(); gFailBridge = YES;
    CFArrayRef result = replaced_CNCopySupportedInterfaces();
    CHECK(result == gLastOriginal && CFArrayGetCount(result) == 0 && !gSourceReleases, "failed interface retain cannot discard original empty array");
    CFRelease(result);
}
static void TestAppleOutput(void) {
    Reset(); CFDictionaryRef output = (CFDictionaryRef)(uintptr_t)1; gOriginalKind = 0;
    CHECK(replaced_Apple80211GetInfoCopy(NULL, &output) == 0 && output && gSeenInitial == NULL && gSeenOutput == &output &&
          gOriginalCalls == 1 && !gSourceReleases, "scoped failure with untouched output never reads caller poison and still synthesizes WiFi");
    CFRelease(output);
    Reset(); orig_Apple80211GetInfoCopy = NULL; output = (CFDictionaryRef)(uintptr_t)1;
    CHECK(replaced_Apple80211GetInfoCopy(NULL, &output) == 0 && output && !gOriginalCalls && !gSourceReleases,
          "missing original Apple function never reads caller poison before scoped synthesis"); CFRelease(output);
    Reset(); orig_Apple80211GetInfoCopy = NULL;
    CHECK(replaced_Apple80211GetInfoCopy(NULL, NULL) == -1 && !gOriginalCalls && !gOperations,
          "missing original and null output return native unavailable status without work");
    Reset();
    CHECK(replaced_Apple80211GetInfoCopy(NULL, NULL) == 17 && gOriginalCalls == 1 && !gOperations && !gScopeCalls && !gWiFiReads,
          "null Apple output forwards once without runtime scope or provider work");
    for (NSUInteger fault = 0; fault < 2; fault++) {
        Reset(); gOriginalKind = 0; gAllowed = fault != 0; gThrowScope = fault == 1;
        CFDictionaryRef caller = (CFDictionaryRef)CFRetain(CFSTR("caller-value")); output = caller;
        CHECK(replaced_Apple80211GetInfoCopy(NULL, &output) == 17 && output == caller && gSeenInitial == caller && !gWiFiReads && !gSourceReleases,
              "denied or failed admission leaves original output pointer and untouched-on-error behavior unchanged");
        CFRelease(caller);
    }
    for (NSUInteger fault = 0; fault < 4; fault++) {
        Reset(); gThrowWiFi = fault == 0; gFailBridge = fault == 1; gThrowBridge = fault == 2; gThrowCopy = fault == 3;
        @autoreleasepool {
            output = NULL;
            CHECK(replaced_Apple80211GetInfoCopy(NULL, &output) == 17 && (CFTypeRef)output == gLastOriginal && !gSourceReleases &&
                  [((__bridge NSDictionary *)output)[@"SSID"] isEqual:@"real"], "Apple preparation failures preserve original owned output and original status");
            CFRelease(output);
        }
        if (gDeaths != 1) {
            const char *faultNames[] = {"provider throw", "bridge NULL", "bridge throw", "mutableCopy throw"};
            fprintf(stderr, "DETAIL: Apple fault=%lu (%s), deaths=%lu expected=1, bridge=%lu copies=%lu source-releases=%lu\n",
                (unsigned long)fault, faultNames[fault], (unsigned long)gDeaths, (unsigned long)gBridgeCalls,
                (unsigned long)gCopies, (unsigned long)gSourceReleases);
        }
        CHECK(gDeaths == 1, "preserved Apple output has no ownership leak after caller release");
    }
    Reset();
    @autoreleasepool {
        output = NULL; gWatchedOutput = &output;
        CHECK(replaced_Apple80211GetInfoCopy(NULL, &output) == 0 && gOriginalCalls == 1 && gCopies == 1 && gSourceReleases == 1 && !gWatchedOutput &&
              [((__bridge NSDictionary *)output)[@"SSID_STR"] isEqual:@"Fake WiFi"] && [((__bridge NSDictionary *)output)[@"RSSI"] isEqual:@-50],
              "Apple synthesis preserves partial original extras publishes first and releases only its old owned output");
        CFRelease(output);
    }
    CHECK(gDeaths == 1, "merged original descendants live until replacement output is released");
    Reset(); gOriginalKind = 2; output = NULL;
    CHECK(replaced_Apple80211GetInfoCopy(NULL, &output) == 17 && CFGetTypeID(output) == CFStringGetTypeID() && !gWiFiReads && !gCopies,
          "unexpected valid CF output type passes through without dictionary assumptions"); CFRelease(output);
    Reset(); gThrowOriginal = YES; output = NULL; BOOL threw = NO;
    @autoreleasepool {
        @try { (void)replaced_Apple80211GetInfoCopy(NULL, &output); }
        @catch (NSException *exception) { (void)exception; threw = YES; }
        CHECK(threw && output && !gWiFiReads && !gSourceReleases, "original Apple exception keeps its directly written owned output visible to caller");
        CFRelease(output);
    }
    CHECK(gDeaths == 1, "exceptional original Apple output remains caller releasable");
    Reset(); gThrowRelease = YES; output = NULL; gWatchedOutput = &output; threw = NO;
    @autoreleasepool {
        @try { (void)replaced_Apple80211GetInfoCopy(NULL, &output); }
        @catch (NSException *exception) { (void)exception; threw = YES; }
        CHECK(threw && output && (CFTypeRef)output != gLastOriginal && gSourceReleases == 1 && !gWatchedOutput,
              "Apple release exception cannot restore or return a dangling original output"); CFRelease(output);
    }
    CHECK(gDeaths == 1, "published Apple replacement ownership survives release exception");
}
static void TestScanLifetime(void) {
    for (NSUInteger fault = 1; fault <= 3; fault++) {
        Reset(); gScanCopyMode = 1; gScanWriteFailure = fault;
        __weak id weakOriginal = nil, weakWiFi = nil;
        @autoreleasepool {
            gScanOriginal = [@{ @"SSID": @"real", @"BSSID": @"real-mac", @"WifiStandard": @99 } mutableCopy];
            gWiFi = [@{ @"ssid": @"Fake WiFi", @"bssid": @"02:11:22:33:44:55", @"wifiStandard": @"802.11ax" } mutableCopy];
            weakOriginal = gScanOriginal; weakWiFi = gWiFi;
            id result = replaced_dictionaryWithScanResult(nil, NULL, nil);
            CHECK(result == gScanOriginal && [result[@"SSID"] isEqual:@"real"] && [result[@"WifiStandard"] isEqual:@99] &&
                  gOriginalCalls == 1 && gScopeCalls == 1 && gWiFiReads == 1 && gCopies == 1 && gScanWrites == fault,
                  "scan failure after each mutation returns untouched original without retry or partial output");
            result = nil; gScanOriginal = nil; gWiFi = nil;
        }
        CHECK(!gScanWorkingCopy && !weakOriginal && !weakWiFi && gScanCopyDeaths == 1,
              "scan exceptional preparation releases its partial copy and retained roots after pool drain");
    }
    Reset(); __weak id weakStandard = nil, weakWiFi = nil, weakOriginal = nil;
    @autoreleasepool {
        id standard = [PXWiFiScanStandard new]; weakStandard = standard;
        gWiFi = @{ @"ssid": @"fake", @"bssid": @"mac", @"wifiStandard": standard };
        gScanOriginal = [@{ @"SSID": @"real" } mutableCopy]; weakWiFi = gWiFi; weakOriginal = gScanOriginal;
        id result = replaced_dictionaryWithScanResult(nil, NULL, nil);
        CHECK(result == gScanOriginal && gOriginalCalls == 1 && !gCopies,
              "scan standard accessor failure preserves original before any copy");
        result = nil; standard = nil; gWiFi = nil; gScanOriginal = nil;
    }
    CHECK(!weakStandard && !weakWiFi && !weakOriginal && gScanStandardDeaths == 1,
          "scan classification exception releases retained standard and WiFi graph");
    Reset(); gThrowOriginal = YES; __weak id weakReceiver = nil, weakInput = nil; BOOL threw = NO;
    @autoreleasepool {
        id receiver = [PXWiFiCFProbe new], input = [PXWiFiCFProbe new]; weakReceiver = receiver; weakInput = input;
        @try { (void)replaced_dictionaryWithScanResult(receiver, NULL, input); }
        @catch (NSException *exception) { threw = [exception.name isEqual:@"fixture.original"]; }
        receiver = nil; input = nil;
    }
    CHECK(threw && !weakReceiver && !weakInput && gDeaths == 2 && gOriginalCalls == 1 && !gScopeCalls && !gWiFiReads && !gCopies,
          "scan original exception propagates once and releases adapter-owned receiver and argument");
}
static void TestScan(void) {
    Reset(); id result = replaced_dictionaryWithScanResult(nil, NULL, nil);
    CHECK([result[@"SSID"] isEqual:@"Fake WiFi"] && [result[@"WifiStandard"] isEqual:@6] && [result[@"keep"] boolValue] &&
          [gScanOriginal[@"SSID"] isEqual:@"real"] && gCopies == 1 && gOriginalCalls == 1,
          "scan replacement preserves original extras and immutability with one lazy copy");
    Reset(); gScanOriginal = @{ @"SSID": @"Fake WiFi", @"BSSID": @"02:11:22:33:44:55", @"WifiStandard": @6 };
    CHECK(replaced_dictionaryWithScanResult(nil, NULL, nil) == gScanOriginal && !gCopies, "already matching scan values retain original identity without copying");
    for (NSUInteger fault = 0; fault < 4; fault++) {
        Reset(); gAllowed = fault != 0; gWiFi = fault == 1 ? nil : (fault == 2 ? (id)NSNull.null : gWiFi); gThrowWiFi = fault == 3;
        CHECK(replaced_dictionaryWithScanResult(nil, NULL, nil) == gScanOriginal && !gCopies && gOriginalCalls == 1,
              "denied missing malformed or throwing scan data avoids allocation and preserves original");
    }
    for (NSArray *row in @[@[@"802.11ac", @5], @[@"802.11n", @4], @[@"802.11ax/ac", @6], @[NSNull.null, @99]]) {
        Reset(); gWiFi = @{ @"ssid": @"Fake WiFi", @"bssid": @"02:11:22:33:44:55", @"wifiStandard": row[0] };
        CHECK([replaced_dictionaryWithScanResult(nil, NULL, nil)[@"WifiStandard"] isEqual:row[1]],
              "scan standard retains ax before ac before n precedence and malformed-field preservation");
    }
    Reset(); gThrowCopy = YES;
    CHECK(replaced_dictionaryWithScanResult(nil, NULL, nil) == gScanOriginal && gCopies == 1, "scan copy failure preserves untouched original");
    for (NSUInteger mode = 2; mode <= 3; mode++) {
        Reset(); gScanCopyMode = mode;
        CHECK(replaced_dictionaryWithScanResult(nil, NULL, nil) == gScanOriginal && gCopies == 1 && gOriginalCalls == 1,
              "scan unusable mutable-copy result preserves original instead of returning nil or mutating another type");
    }
    for (id original in @[@42, NSNull.null]) {
        Reset(); gScanOriginal = original;
        CHECK(replaced_dictionaryWithScanResult(nil, NULL, nil) == original && !gWiFiReads && !gCopies && gOriginalCalls == 1,
              "scan non-dictionary original bypasses WiFi preparation and copying");
    }
    Reset(); orig_dictionaryWithScanResult = NULL;
    CHECK(!replaced_dictionaryWithScanResult(nil, NULL, nil) && !gOriginalCalls && !gWiFiReads && !gCopies,
          "scan missing original preserves nil without a null call or synthesis");
    Reset(); gWiFi = @{ @"ssid": @"Fake WiFi", @"bssid": @"02:11:22:33:44:55", @"wifiStandard": @"unknown" };
    CHECK([replaced_dictionaryWithScanResult(nil, NULL, nil)[@"WifiStandard"] isEqual:@99], "unknown scan standard preserves the original standard field");
}
int main(void) {
    @autoreleasepool {
        @try { TestLifetimeOracle(); TestNetworkCopy(); TestPreparationLifetime(); TestNetworkAdapterFieldOwnership(); TestInterfaces(); TestAppleOutput(); TestScan(); TestScanLifetime(); }
        @catch (NSException *exception) { gFailures++; fprintf(stderr, "FAIL: unexpected WiFi CF exception: %s\n", exception.description.UTF8String); }
        printf("WiFi CF boundaries: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
