// PXP1BFiltersTests.m
// Host-runnable unit tests for the pure P1-B helpers.

#import <Foundation/Foundation.h>
#import "PXP1BFilters.h"

static int gPass = 0;
static int gFail = 0;

#define PXT_ASSERT(cond, desc) do { \
    if (cond) { gPass++; } \
    else { gFail++; fprintf(stderr, "FAIL: %s (line %d)\n", desc, __LINE__); } \
} while (0)

static void testAppVersionApply(void) {
    NSDictionary *base = @{ @"CFBundleShortVersionString": @"1.0",
                            @"CFBundleVersion": @"100",
                            @"CFBundleName": @"Demo" };

    // Both overrides applied; other keys preserved; result immutable copy.
    NSDictionary *both = PXAppVersionApplyToInfoDictionary(base, @"9.9", @"999");
    PXT_ASSERT([both[@"CFBundleShortVersionString"] isEqualToString:@"9.9"], "apply short version");
    PXT_ASSERT([both[@"CFBundleVersion"] isEqualToString:@"999"], "apply build version");
    PXT_ASSERT([both[@"CFBundleName"] isEqualToString:@"Demo"], "preserve other keys");
    PXT_ASSERT(![both isKindOfClass:[NSMutableDictionary class]], "result is immutable copy");

    // Original never mutated.
    PXT_ASSERT([base[@"CFBundleShortVersionString"] isEqualToString:@"1.0"], "original untouched short");
    PXT_ASSERT([base[@"CFBundleVersion"] isEqualToString:@"100"], "original untouched build");

    // Empty / nil arguments leave the corresponding key unchanged.
    NSDictionary *verOnly = PXAppVersionApplyToInfoDictionary(base, @"2.0", @"");
    PXT_ASSERT([verOnly[@"CFBundleShortVersionString"] isEqualToString:@"2.0"], "version only sets short");
    PXT_ASSERT([verOnly[@"CFBundleVersion"] isEqualToString:@"100"], "version only keeps build");

    NSDictionary *buildOnly = PXAppVersionApplyToInfoDictionary(base, nil, @"222");
    PXT_ASSERT([buildOnly[@"CFBundleShortVersionString"] isEqualToString:@"1.0"], "build only keeps short");
    PXT_ASSERT([buildOnly[@"CFBundleVersion"] isEqualToString:@"222"], "build only sets build");

    // Non-dictionary input returned unchanged.
    id notDict = (id)@"not a dict";
    PXT_ASSERT(PXAppVersionApplyToInfoDictionary(notDict, @"1", @"2") == notDict, "non-dict passthrough");
}

static void testSafeBundleFilename(void) {
    PXT_ASSERT([PXAppVersionSafeBundleFilename(@"com.foo.bar") isEqualToString:@"com_foo_bar_version.plist"], "dotted bundle id");
    PXT_ASSERT([PXAppVersionSafeBundleFilename(@"single") isEqualToString:@"single_version.plist"], "no dots");
    PXT_ASSERT(PXAppVersionSafeBundleFilename(@"") == nil, "empty is nil");
    PXT_ASSERT(PXAppVersionSafeBundleFilename(nil) == nil, "nil is nil");
}

static void testGethostnameWrite(void) {
    char buf[32];

    // Normal copy fits: exact string + NUL.
    memset(buf, 'X', sizeof(buf));
    PXT_ASSERT(PXGethostnameWriteValue(buf, sizeof(buf), "iPhone") == YES, "write returns YES");
    PXT_ASSERT(strcmp(buf, "iPhone") == 0, "write copies value");

    // Truncation: buffer smaller than value, always NUL-terminated.
    char small[4];
    memset(small, 'X', sizeof(small));
    PXT_ASSERT(PXGethostnameWriteValue(small, sizeof(small), "abcdefgh") == YES, "truncated write YES");
    PXT_ASSERT(strcmp(small, "abc") == 0, "truncated to namelen-1 + NUL");
    PXT_ASSERT(small[3] == '\0', "trailing NUL present");

    // Guards: NULL buffer, zero length, NULL/empty value -> NO, buffer untouched.
    PXT_ASSERT(PXGethostnameWriteValue(NULL, 8, "x") == NO, "null buffer NO");
    PXT_ASSERT(PXGethostnameWriteValue(buf, 0, "x") == NO, "zero length NO");
    PXT_ASSERT(PXGethostnameWriteValue(buf, sizeof(buf), NULL) == NO, "null value NO");
    PXT_ASSERT(PXGethostnameWriteValue(buf, sizeof(buf), "") == NO, "empty value NO");

    // namelen == 1 leaves room only for NUL -> copies 0 chars.
    char one[1];
    one[0] = 'X';
    PXT_ASSERT(PXGethostnameWriteValue(one, 1, "abc") == YES, "namelen 1 YES");
    PXT_ASSERT(one[0] == '\0', "namelen 1 only NUL");
}

static void testATT(void) {
    PXT_ASSERT(PXATTClampStatus(-5) == 0, "clamp negative to 0");
    PXT_ASSERT(PXATTClampStatus(0) == 0, "clamp 0");
    PXT_ASSERT(PXATTClampStatus(3) == 3, "clamp 3");
    PXT_ASSERT(PXATTClampStatus(99) == 3, "clamp above to 3");

    PXT_ASSERT(PXATTStatusIsAuthorized(3) == YES, "3 authorized");
    PXT_ASSERT(PXATTStatusIsAuthorized(0) == NO, "0 not authorized");
    PXT_ASSERT(PXATTStatusIsAuthorized(2) == NO, "2 not authorized");
    PXT_ASSERT(PXATTStatusIsAuthorized(99) == NO, "clamped 99->3 authorized") ; // 99 clamps to 3 -> authorized
    PXT_ASSERT([PXATTZeroIDFAUUIDString isEqualToString:@"00000000-0000-0000-0000-000000000000"], "zero idfa constant");
}

int PXRunP1BFiltersTests(void) {
    @autoreleasepool {
        gPass = 0;
        gFail = 0;
        testAppVersionApply();
        testSafeBundleFilename();
        testGethostnameWrite();
        testATT();
        fprintf(stderr, "P1-B helper tests: %d passed, %d failed\n", gPass, gFail);
    }
    return gFail == 0 ? 0 : 1;
}
