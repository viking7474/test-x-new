#import <Foundation/Foundation.h>
#import "PXLocaleRuntimeProjection.h"

#include <locale.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static void PXTestCanonicalLocaleNames(void) {
    NSCAssert([PXCanonicalCLocaleName(@"en-US") isEqualToString:@"en_US.UTF-8"],
              @"BCP-47 locale did not normalize for libc");
    NSCAssert([PXCanonicalCLocaleName(@"vi_VN") isEqualToString:@"vi_VN.UTF-8"],
              @"underscore locale did not gain UTF-8 suffix");
    NSCAssert([PXCanonicalCLocaleName(@"de_DE.UTF-8") isEqualToString:@"de_DE.UTF-8"],
              @"explicit codeset should be preserved");
    NSCAssert(PXCanonicalCLocaleName(@"   ") == nil,
              @"blank locale should fail open");
}

static void PXTestSetlocaleDecision(void) {
    NSCAssert(PXSetlocaleCategorySupportsProjection(LC_ALL), @"LC_ALL should be supported");
    NSCAssert(PXSetlocaleCategorySupportsProjection(LC_TIME), @"LC_TIME should be supported");
    NSCAssert(PXSetlocaleCategorySupportsProjection(LC_CTYPE), @"LC_CTYPE should be supported");
    NSCAssert(!PXSetlocaleCategorySupportsProjection(0x7fffffff),
              @"unknown locale category should fail open");

    NSCAssert(PXSetlocaleShouldUseCanonicalInput(LC_ALL, ""),
              @"environment-derived setlocale should be projectable");
    NSCAssert(!PXSetlocaleShouldUseCanonicalInput(LC_ALL, NULL),
              @"setlocale query semantics must not be rewritten");
    NSCAssert(!PXSetlocaleShouldUseCanonicalInput(LC_ALL, "C"),
              @"explicit locale request must stay caller-owned");
}

static void PXTestPreferredLocalizationsProjection(void) {
    NSArray<NSString *> *original = @[@"en", @"Base"];

    NSArray<NSString *> *disabled = PXPreferredLocalizationsProjection(original,
                                                                        @[@"vi-VN"],
                                                                        @"vi-VN",
                                                                        NO);
    NSCAssert(disabled == original,
              @"B-05 disabled preferredLocalizations must preserve exact original array");

    NSArray<NSString *> *fromLanguages = PXPreferredLocalizationsProjection(original,
                                                                            @[@"vi-VN", @"en-US"],
                                                                            @"fr-FR",
                                                                            YES);
    NSCAssert(fromLanguages.count == 1 && [fromLanguages.firstObject isEqualToString:@"vi-VN"],
              @"B-05 preferredLocalizations must prefer canonical preferredLanguages source");

    NSArray<NSString *> *fromHyphenLocale = PXPreferredLocalizationsProjection(original,
                                                                               @[],
                                                                               @"fr-FR",
                                                                               YES);
    NSCAssert(fromHyphenLocale.count == 1 && [fromHyphenLocale.firstObject isEqualToString:@"fr"],
              @"B-05 locale fallback must project first hyphen component");

    NSArray *invalidPreferredLanguages = @[@"", @42];
    NSArray<NSString *> *fromUnderscoreLocale = PXPreferredLocalizationsProjection(original,
                                                                                   invalidPreferredLanguages,
                                                                                   @"de_DE",
                                                                                   YES);
    NSCAssert(fromUnderscoreLocale.count == 1 && [fromUnderscoreLocale.firstObject isEqualToString:@"de"],
              @"B-05 locale fallback must accept underscore locale identifiers");

    NSArray<NSString *> *partial = PXPreferredLocalizationsProjection(original,
                                                                       @[@"", @"  "],
                                                                       @"   ",
                                                                       YES);
    NSCAssert(partial == original,
              @"B-05 partial/invalid locale profile must fail open to exact original array");
}

static void PXTestLibcTimeZoneContract(void) {
    const char *existingTZ = getenv("TZ");
    char *savedTZ = existingTZ ? strdup(existingTZ) : NULL;

    setenv("TZ", "UTC", 1);
    tzset();

    time_t fixture = (time_t)1704067200; // 2024-01-01T00:00:00Z
    struct tm reentrant = {0};
    struct tm *r = localtime_r(&fixture, &reentrant);
    NSCAssert(r == &reentrant, @"localtime_r must return the caller buffer");
    NSCAssert(reentrant.tm_year == 124 && reentrant.tm_mon == 0 &&
              reentrant.tm_mday == 1 && reentrant.tm_hour == 0,
              @"UTC localtime_r fixture is incorrect");

    struct tm *shared = localtime(&fixture);
    NSCAssert(shared != NULL, @"localtime returned nil for valid fixture");
    NSCAssert(shared->tm_year == reentrant.tm_year &&
              shared->tm_mon == reentrant.tm_mon &&
              shared->tm_mday == reentrant.tm_mday &&
              shared->tm_hour == reentrant.tm_hour &&
              shared->tm_min == reentrant.tm_min &&
              shared->tm_sec == reentrant.tm_sec,
              @"localtime and localtime_r diverged for the same process TZ");

#if defined(__APPLE__)
    setenv("TZ", "Asia/Ho_Chi_Minh", 1);
    tzset();
    memset(&reentrant, 0, sizeof(reentrant));
    NSCAssert(localtime_r(&fixture, &reentrant) == &reentrant,
              @"Asia/Ho_Chi_Minh localtime_r failed");
    NSTimeZone *zone = [NSTimeZone timeZoneWithName:@"Asia/Ho_Chi_Minh"];
    NSInteger expectedOffset = [zone secondsFromGMTForDate:[NSDate dateWithTimeIntervalSince1970:fixture]];
    NSCAssert(reentrant.tm_gmtoff == expectedOffset,
              @"libc timezone offset diverged from NSTimeZone (%ld vs %ld)",
              (long)reentrant.tm_gmtoff, (long)expectedOffset);
#endif

    // Querying setlocale must not change locale state.
    char *beforeQuery = setlocale(LC_ALL, NULL);
    NSString *before = beforeQuery ? [NSString stringWithUTF8String:beforeQuery] : nil;
    char *afterQuery = setlocale(LC_ALL, NULL);
    NSString *after = afterQuery ? [NSString stringWithUTF8String:afterQuery] : nil;
    NSCAssert((before == nil && after == nil) || [before isEqualToString:after],
              @"setlocale(LC_ALL,NULL) query changed locale state");

    if (savedTZ) {
        setenv("TZ", savedTZ, 1);
        free(savedTZ);
    } else {
        unsetenv("TZ");
    }
    tzset();
}

void PXRunLocaleRuntimeProjectionTests(void) {
    PXTestCanonicalLocaleNames();
    PXTestSetlocaleDecision();
    PXTestPreferredLocalizationsProjection();
    PXTestLibcTimeZoneContract();
    NSLog(@"[A-04] libc locale/time projection PASS");
}
