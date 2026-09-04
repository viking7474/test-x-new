#import <Foundation/Foundation.h>
#import <CFNetwork/CFNetwork.h>
#import "PXPACProxySanitizer.h"
#include <stdio.h>

static NSString *PXTestProxyTypeKey(void) {
    return (__bridge NSString *)kCFProxyTypeKey;
}

static NSString *PXTestProxyTypeNone(void) {
    return (__bridge NSString *)kCFProxyTypeNone;
}

static int gPXPACFailures = 0;

#define PX_PAC_ASSERT(condition, message) do { \
    if (!(condition)) { \
        gPXPACFailures++; \
        fprintf(stderr, "  FAIL: %s\n", (message)); \
    } \
} while (0)

static void testProfileOffAndNilFailOpen(void) {
    NSArray *fixture = @[@{PXTestProxyTypeKey(): @"HTTP", @"marker": @"keep"}];
    id disabled = PXPACProjectedProxyValue(fixture, NO);
    PX_PAC_ASSERT(disabled == fixture, "B-04 profile-off must return exact original object");
    PX_PAC_ASSERT(PXPACProjectedProxyValue(nil, YES) == nil,
                  "B-04 nil original must remain nil");
}

static void testDirectOnlyPreservesShape(void) {
    NSDictionary *entry = @{
        PXTestProxyTypeKey(): PXTestProxyTypeNone(),
        @"marker": @"preserve",
    };
    NSArray *fixture = @[entry];
    id projectedValue = PXPACProjectedProxyValue(fixture, YES);
    PX_PAC_ASSERT(projectedValue != fixture, "B-04 valid PAC array should produce projected copy");
    PX_PAC_ASSERT([projectedValue isKindOfClass:[NSArray class]], "B-04 DIRECT result stays array");
    NSArray *projected = (NSArray *)projectedValue;
    PX_PAC_ASSERT(projected.count == fixture.count, "B-04 DIRECT cardinality preserved");
    NSDictionary *out = projected.firstObject;
    PX_PAC_ASSERT([out[PXTestProxyTypeKey()] isEqual:PXTestProxyTypeNone()],
                  "B-04 DIRECT type preserved");
    PX_PAC_ASSERT([out[@"marker"] isEqual:@"preserve"], "B-04 DIRECT unknown key preserved");
}

static void testHTTPAndSOCKSBecomeDirect(void) {
    NSArray *fixture = @[
        @{
            PXTestProxyTypeKey(): @"HTTP",
            @"kCFProxyHostNameKey": @"127.0.0.1",
            @"kCFProxyPortNumberKey": @8080,
            @"http-marker": @"keep-http",
        },
        @{
            PXTestProxyTypeKey(): @"SOCKS",
            @"kCFProxyHostNameKey": @"10.0.0.1",
            @"kCFProxyPortNumberKey": @1080,
            @"kCFProxyUsernameKey": @"user",
            @"kCFProxyPasswordKey": @"secret",
            @"socks-marker": @"keep-socks",
        },
    ];

    NSArray *projected = PXPACProjectedProxyValue(fixture, YES);
    PX_PAC_ASSERT(projected != fixture, "B-04 HTTP/SOCKS valid result should project");
    PX_PAC_ASSERT(projected.count == 2, "B-04 HTTP/SOCKS cardinality preserved");

    NSDictionary *http = projected[0];
    NSDictionary *socks = projected[1];
    PX_PAC_ASSERT([http[PXTestProxyTypeKey()] isEqual:PXTestProxyTypeNone()],
                  "B-04 HTTP becomes DIRECT");
    PX_PAC_ASSERT([socks[PXTestProxyTypeKey()] isEqual:PXTestProxyTypeNone()],
                  "B-04 SOCKS becomes DIRECT");
    PX_PAC_ASSERT(http[@"kCFProxyHostNameKey"] == nil && http[@"kCFProxyPortNumberKey"] == nil,
                  "B-04 HTTP endpoint fields removed");
    PX_PAC_ASSERT(socks[@"kCFProxyHostNameKey"] == nil && socks[@"kCFProxyPortNumberKey"] == nil,
                  "B-04 SOCKS endpoint fields removed");
    PX_PAC_ASSERT(socks[@"kCFProxyUsernameKey"] == nil && socks[@"kCFProxyPasswordKey"] == nil,
                  "B-04 proxy credential fields removed");
    PX_PAC_ASSERT([http[@"http-marker"] isEqual:@"keep-http"], "B-04 HTTP unknown key preserved");
    PX_PAC_ASSERT([socks[@"socks-marker"] isEqual:@"keep-socks"], "B-04 SOCKS unknown key preserved");
}

static void testPACConfigurationFieldsAreRemoved(void) {
    NSArray *fixture = @[@{
        PXTestProxyTypeKey(): @"AutoConfigurationURL",
        @"kCFProxyAutoConfigurationURLKey": @"http://example.invalid/proxy.pac",
        @"kCFProxyAutoConfigurationJavaScriptKey": @"return 'PROXY 127.0.0.1:8080';",
        @"marker": @42,
    }];
    NSArray *projected = PXPACProjectedProxyValue(fixture, YES);
    NSDictionary *out = projected.firstObject;
    PX_PAC_ASSERT([out[PXTestProxyTypeKey()] isEqual:PXTestProxyTypeNone()],
                  "B-04 PAC entry becomes DIRECT");
    PX_PAC_ASSERT(out[@"kCFProxyAutoConfigurationURLKey"] == nil &&
                  out[@"kCFProxyAutoConfigurationJavaScriptKey"] == nil,
                  "B-04 PAC configuration fields removed");
    PX_PAC_ASSERT([out[@"marker"] isEqual:@42], "B-04 PAC unknown key preserved");
}

static void testMalformedResultFailsOpen(void) {
    NSArray *nonDictionary = @[@"not-a-proxy-dictionary"];
    PX_PAC_ASSERT(PXPACProjectedProxyValue(nonDictionary, YES) == nonDictionary,
                  "B-04 malformed PAC entry must return exact original array");

    NSArray *missingType = @[@{@"marker": @"missing-type"}];
    PX_PAC_ASSERT(PXPACProjectedProxyValue(missingType, YES) == missingType,
                  "B-04 missing proxy type must fail open");

    NSArray *wrongType = @[@{PXTestProxyTypeKey(): @7}];
    PX_PAC_ASSERT(PXPACProjectedProxyValue(wrongType, YES) == wrongType,
                  "B-04 non-string proxy type must fail open");

    NSDictionary *notArray = @{PXTestProxyTypeKey(): @"HTTP"};
    PX_PAC_ASSERT(PXPACProjectedProxyValue(notArray, YES) == notArray,
                  "B-04 non-array original must fail open");
}

int PXRunPACProxySanitizerTests(void) {
    gPXPACFailures = 0;
    testProfileOffAndNilFailOpen();
    testDirectOnlyPreservesShape();
    testHTTPAndSOCKSBecomeDirect();
    testPACConfigurationFieldsAreRemoved();
    testMalformedResultFailsOpen();
    return gPXPACFailures;
}
