#import <Foundation/Foundation.h>
#import "PXP1CFilters.h"
#import "PXInjectionFilter.h"
#import "PXLocaleRuntimeProjection.h"
#include <stdio.h>

static int gPXPhaseBFailures = 0;

#define PX_B_ASSERT(condition, message) do { \
    if (!(condition)) { \
        gPXPhaseBFailures++; \
        fprintf(stderr, "  FAIL: %s\n", (message)); \
    } \
} while (0)

enum {
    kPXBMaster = 1ull << 0,
    kPXBStatfs = 1ull << 1,
    kPXBDyld = 1ull << 2,
};

static void PXPhaseBCaseSpoofDisabled(void) {
    NSDictionary *scope = @{@"com.fixture.app": @{ @"enabled": @NO }};
    PX_B_ASSERT(!PXP1CScopeBundleEnabled(scope, @"com.fixture.app"),
                "B-06 spoof-disabled scope must be false");

    NSArray *arguments = @[@"/Applications/Fixture.app/Fixture", @"--jailbreak-probe"];
    PX_B_ASSERT(PXP1CJBFilterProcessArguments(arguments, NO) == arguments,
                "B-06 spoof-disabled argv projection must return exact original");

    NSArray<NSString *> *localizations = @[@"en", @"Base"];
    PX_B_ASSERT(PXPreferredLocalizationsProjection(localizations, @[@"vi-VN"], @"vi-VN", NO) == localizations,
                "B-06 spoof-disabled locale projection must return exact original");
}

static void PXPhaseBCaseSpoofEnabledFullProfile(void) {
    NSDictionary *scope = @{@"com.fixture.app": @{ @"enabled": @YES }};
    PX_B_ASSERT(PXP1CScopeBundleEnabled(scope, @"com.fixture.app"),
                "B-06 full-profile scoped app must be enabled");

    NSArray<NSString *> *projected = PXPreferredLocalizationsProjection(@[@"en"],
                                                                         @[@"vi-VN", @"en-US"],
                                                                         @"vi-VN",
                                                                         YES);
    PX_B_ASSERT(projected.count == 1 && [projected.firstObject isEqualToString:@"vi-VN"],
                "B-06 full-profile locale projection must use canonical preferred language");

    PXJBFilesystemDisposition normal =
        PXP1CJBResolvedPathDisposition(kPXJBFilesystemOperationRead, NO, NO);
    PX_B_ASSERT(normal == kPXJBFilesystemAllow,
                "B-06 full-profile normal filesystem query must remain pass-through");
}

static void PXPhaseBCaseJailbreakBypassDisabled(void) {
    uint64_t requested = PXP1CJBRequestedMask(NO, kPXBMaster, kPXBStatfs | kPXBDyld);
    uint64_t effective = PXP1CJBEffectivePolicyMask(requested, UINT64_MAX);
    PX_B_ASSERT(requested == 0 && effective == 0,
                "B-06 JB-disabled requested/effective mask must be zero");
    PX_B_ASSERT(!PXP1CJBFeatureActive(effective, kPXBMaster, kPXBStatfs),
                "B-06 JB-disabled feature must remain inactive");
}

static void PXPhaseBCaseJailbreakBypassEnabled(void) {
    uint64_t requested = PXP1CJBRequestedMask(YES, kPXBMaster, kPXBStatfs | kPXBDyld);
    uint64_t installed = kPXBMaster | kPXBStatfs;
    uint64_t effective = PXP1CJBEffectivePolicyMask(requested, installed);
    PX_B_ASSERT((requested & (kPXBMaster | kPXBStatfs | kPXBDyld)) ==
                    (kPXBMaster | kPXBStatfs | kPXBDyld),
                "B-06 JB-enabled requested mask lost a requested capability");
    PX_B_ASSERT(PXP1CJBFeatureActive(effective, kPXBMaster, kPXBStatfs),
                "B-06 installed JB feature must activate with master");
    PX_B_ASSERT(!PXP1CJBFeatureActive(effective, kPXBMaster, kPXBDyld),
                "B-06 uninstalled JB feature must not activate at runtime");
}

static void PXPhaseBCaseMissingSnapshot(void) {
    PX_B_ASSERT(PXP1CSnapshotNeedsRefresh(NO, 100.0, 200.0),
                "B-06 missing snapshot must require refresh/fail-open path");
    PX_B_ASSERT(!PXP1CSnapshotNeedsRefresh(YES, 100.0, 200.0),
                "B-06 valid unexpired snapshot must not force refresh");
}

static void PXPhaseBCaseAppExtension(void) {
    NSArray *expanded = @[
        @"com.fixture.app",
        @"com.fixture.app.share-extension",
        @"com.apple.WebKit.WebContent",
    ];
    NSArray *tweak = PXInjectionComputeTweakBundles(expanded);
    PX_B_ASSERT([tweak containsObject:@"com.fixture.app"],
                "B-06 tweak filter dropped scoped main app");
    PX_B_ASSERT([tweak containsObject:@"com.fixture.app.share-extension"],
                "B-06 tweak filter dropped scoped app extension");

    NSArray *bridge = PXInjectionComputeBridgeBundles(tweak);
    PX_B_ASSERT([bridge containsObject:@"com.fixture.app"] &&
                [bridge containsObject:@"com.fixture.app.share-extension"],
                "B-06 bridge must retain third-party app + extension");
    PX_B_ASSERT(![bridge containsObject:@"com.apple.WebKit.WebContent"] &&
                ![bridge containsObject:PXInjectionSpringBoardBundleID],
                "B-06 bridge must not expand into WebKit/SpringBoard");
}

static void PXPhaseBCaseWebKitHelper(void) {
    PX_B_ASSERT(!PXP1CWebKitHostScoped(NO, @"com.fixture.app", NO, YES),
                "B-06 WebKit helper must fail closed when device spoof is disabled");
    PX_B_ASSERT(!PXP1CWebKitHostScoped(YES, nil, NO, YES),
                "B-06 WebKit helper must fail closed when host is unresolved");
    PX_B_ASSERT(!PXP1CWebKitHostScoped(YES, @"com.fixture.app", YES, YES),
                "B-06 WebKit helper must reject critical host process");
    PX_B_ASSERT(!PXP1CWebKitHostScoped(YES, @"com.fixture.app", NO, NO),
                "B-06 WebKit helper must reject unscoped host");
    PX_B_ASSERT(PXP1CWebKitHostScoped(YES, @"com.fixture.app", NO, YES),
                "B-06 supported WebKit helper must follow scoped host");
}

static void PXPhaseBCaseSpringBoardMinimal(void) {
    NSArray *tweak = PXInjectionComputeTweakBundles(@[@"com.fixture.app"]);
    PX_B_ASSERT([tweak containsObject:PXInjectionSpringBoardBundleID],
                "B-06 scoped tweak filter must retain SpringBoard UI host");

    NSArray *bridge = PXInjectionComputeBridgeBundles(tweak);
    PX_B_ASSERT(![bridge containsObject:PXInjectionSpringBoardBundleID],
                "B-06 keychain bridge must never expand into SpringBoard");

    NSArray *emptyTweak = PXInjectionComputeTweakBundles(@[]);
    PX_B_ASSERT([emptyTweak isEqualToArray:@[PXInjectionPlaceholderBundleID]],
                "B-06 empty scope must collapse to placeholder-only injection filter");
}

int PXRunPhaseBRegressionGateTests(void) {
    gPXPhaseBFailures = 0;
    PXPhaseBCaseSpoofDisabled();
    PXPhaseBCaseSpoofEnabledFullProfile();
    PXPhaseBCaseJailbreakBypassDisabled();
    PXPhaseBCaseJailbreakBypassEnabled();
    PXPhaseBCaseMissingSnapshot();
    PXPhaseBCaseAppExtension();
    PXPhaseBCaseWebKitHelper();
    PXPhaseBCaseSpringBoardMinimal();
    return gPXPhaseBFailures;
}
