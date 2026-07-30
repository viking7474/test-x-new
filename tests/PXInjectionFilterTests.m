#import <Foundation/Foundation.h>
#import "PXInjectionFilter.h"

// IOS-08 — Injection filter tests.
//
// Exercises the canonical filter algorithm shared by the app-side writer
// (PXWriteSubstrateFilterPlists) and the mount daemon (filterPlistIsValid).
// Pure Foundation, host-runnable. Returns the number of failed checks.

static int gPass = 0;
static int gFail = 0;

#define PXT_ASSERT(cond, desc) do { \
    if (cond) { gPass++; } \
    else { gFail++; fprintf(stderr, "  FAIL: %s\n", desc); } \
} while (0)

static BOOL PXTArrayEquals(NSArray *a, NSArray *b) {
    return (a == b) || [a isEqualToArray:b];
}

static void PXTTestNormalize(void) {
    NSArray *input = @[@"b.app", @"a.app", @"b.app", @"", @42, @"a.app", @"c.app"];
    NSArray *out = PXInjectionNormalizeBundleList(input);
    PXT_ASSERT(PXTArrayEquals(out, (@[@"a.app", @"b.app", @"c.app"])),
               "normalize dedups, drops empty/non-string, sorts ascending");
    PXT_ASSERT(PXInjectionNormalizeBundleList(nil).count == 0, "normalize nil -> empty");
}

static void PXTTestClassifiers(void) {
    PXT_ASSERT(PXInjectionBundleIsProjectXApp(@"com.hydra.projectx"), "projectx app detected");
    PXT_ASSERT(PXInjectionBundleIsProjectXApp(@"com.hydra.weaponx"), "weaponx app detected");
    PXT_ASSERT(!PXInjectionBundleIsProjectXApp(@"com.acme.app"), "third-party not projectx app");

    PXT_ASSERT(PXInjectionBundleIsAppleOrWebKit(@"com.apple.springboard"), "com.apple.* is apple");
    PXT_ASSERT(PXInjectionBundleIsAppleOrWebKit(@"com.apple.WebKit.GPU"), "webkit helper is apple");
    PXT_ASSERT(PXInjectionBundleIsAppleOrWebKit(@"org.example.WebKitShim"), "WebKit-named non-apple treated as apple/webkit");
    PXT_ASSERT(PXInjectionBundleIsAppleOrWebKit(nil), "nil treated as apple/webkit (defensive)");
    PXT_ASSERT(!PXInjectionBundleIsAppleOrWebKit(@"com.acme.app"), "third-party is not apple/webkit");
}

static void PXTTestEnabledScope(void) {
    NSDictionary *scope = @{
        @"ScopedApps": @{
            @"com.acme.app":        @{ @"enabled": @YES },
            @"com.beta.app":        @{ @"enabled": @NO },   // disabled -> excluded
            @"com.gamma.app":       @{},                     // no flag -> excluded (enabled must be YES)
            @"com.hydra.projectx":  @{ @"enabled": @YES },   // self -> excluded
            @"com.apple.WebKit.GPU":@{ @"enabled": @YES },   // webkit -> excluded
            @"com.apple.SafariViewService": @{ @"enabled": @YES }, // safari helper -> excluded
            @"com.delta.app":       @{ @"enabled": @YES }
        }
    };
    NSArray *out = PXInjectionEnabledMainBundlesFromScopePlist(scope);
    PXT_ASSERT(PXTArrayEquals(out, (@[@"com.acme.app", @"com.delta.app"])),
               "enabled scope keeps only enabled third-party mains, sorted");
    PXT_ASSERT(PXInjectionEnabledMainBundlesFromScopePlist(nil).count == 0, "nil scope -> empty");
    PXT_ASSERT(PXInjectionEnabledMainBundlesFromScopePlist(@{}).count == 0, "missing ScopedApps -> empty");
}

static void PXTTestTweakBundles(void) {
    // Non-empty scope: tweak = expanded + SpringBoard, normalized, never the placeholder.
    NSArray *expanded = @[@"com.acme.app", @"com.acme.app.ext", @"com.apple.WebKit.GPU"];
    NSArray *tweak = PXInjectionComputeTweakBundles(expanded);
    PXT_ASSERT([tweak containsObject:PXInjectionSpringBoardBundleID], "tweak always contains SpringBoard");
    PXT_ASSERT([tweak containsObject:@"com.acme.app"], "tweak keeps main bundle");
    PXT_ASSERT([tweak containsObject:@"com.acme.app.ext"], "tweak keeps extension bundle");
    PXT_ASSERT(![tweak containsObject:PXInjectionPlaceholderBundleID], "tweak never contains placeholder");
    PXT_ASSERT(PXTArrayEquals(tweak, PXInjectionNormalizeBundleList(tweak)), "tweak output is normalized");

    // Empty scope: tweak collapses to placeholder-only (matches plan + keychain bridge; never Bundles=[]).
    NSArray *emptyTweak = PXInjectionComputeTweakBundles(@[]);
    PXT_ASSERT(PXTArrayEquals(emptyTweak, (@[PXInjectionPlaceholderBundleID])),
               "empty scope -> placeholder-only tweak filter");
    PXT_ASSERT(![emptyTweak containsObject:PXInjectionSpringBoardBundleID],
               "empty tweak drops SpringBoard when no apps are scoped");
}

static void PXTTestBridgeBundles(void) {
    NSArray *tweak = @[@"com.acme.app", @"com.acme.app.ext", @"com.apple.springboard", @"com.apple.WebKit.GPU"];
    NSArray *bridge = PXInjectionComputeBridgeBundles(tweak);
    PXT_ASSERT(PXTArrayEquals(bridge, (@[@"com.acme.app", @"com.acme.app.ext"])),
               "bridge keeps only third-party app/extensions, sorted");
    PXT_ASSERT(![bridge containsObject:PXInjectionSpringBoardBundleID], "bridge drops SpringBoard");
    PXT_ASSERT(![bridge containsObject:@"com.apple.WebKit.GPU"], "bridge drops WebKit helpers");

    // No third-party apps: bridge collapses to placeholder-only.
    NSArray *emptyBridge = PXInjectionComputeBridgeBundles(@[PXInjectionSpringBoardBundleID]);
    PXT_ASSERT(PXTArrayEquals(emptyBridge, (@[PXInjectionPlaceholderBundleID])),
               "empty bridge -> placeholder-only");
}

static void PXTTestValidator(void) {
    NSArray *bundles = nil;
    NSString *reason = nil;

    PXT_ASSERT(!PXInjectionFilterPlistIsValid((id)@"nope", &bundles, &reason) &&
               [reason isEqualToString:@"plist-not-dictionary"], "validator: not-dictionary");
    PXT_ASSERT(!PXInjectionFilterPlistIsValid(@{}, &bundles, &reason) &&
               [reason isEqualToString:@"missing-Filter"], "validator: missing-Filter");
    PXT_ASSERT(!PXInjectionFilterPlistIsValid(@{ @"Filter": @{ @"Bundles": @[@"a"], @"Mode": @"All" } }, &bundles, &reason) &&
               [reason isEqualToString:@"invalid-Mode"], "validator: invalid-Mode");
    PXT_ASSERT(!PXInjectionFilterPlistIsValid(@{ @"Filter": @{ @"Bundles": @[] } }, &bundles, &reason) &&
               [reason isEqualToString:@"empty-Bundles"], "validator: empty-Bundles");
    PXT_ASSERT(!PXInjectionFilterPlistIsValid(@{ @"Filter": @{ @"Bundles": @[@""] } }, &bundles, &reason) &&
               [reason isEqualToString:@"invalid-bundle-item"], "validator: invalid-bundle-item");
    PXT_ASSERT(!PXInjectionFilterPlistIsValid(@{ @"Filter": @{ @"Bundles": @[@"com.apple.UIKit"] } }, &bundles, &reason) &&
               [reason isEqualToString:@"blocked-com.apple.UIKit"], "validator: blocked UIKit");
    PXT_ASSERT(!PXInjectionFilterPlistIsValid(@{ @"Filter": @{ @"Bundles": @[@"com.acme.*"] } }, &bundles, &reason) &&
               [reason isEqualToString:@"wildcard-not-allowed"], "validator: wildcard");
    PXT_ASSERT(!PXInjectionFilterPlistIsValid(@{ @"Filter": @{ @"Bundles": @[PXInjectionPlaceholderBundleID, @"com.acme.app"] } }, &bundles, &reason) &&
               [reason isEqualToString:@"placeholder-with-real-bundles"], "validator: placeholder mixed with real");

    bundles = nil; reason = nil;
    PXT_ASSERT(PXInjectionFilterPlistIsValid(@{ @"Filter": @{ @"Bundles": @[@"com.acme.app"], @"Mode": @"Any" } }, &bundles, &reason) &&
               bundles.count == 1, "validator: accepts a normal filter");
    PXT_ASSERT(PXInjectionFilterPlistIsValid(@{ @"Filter": @{ @"Bundles": @[PXInjectionPlaceholderBundleID] } }, &bundles, &reason),
               "validator: accepts placeholder-only filter");
}

static void PXTTestConsistencyRoundTrip(void) {
    // Full pipeline: enabled scope -> tweak -> bridge -> plist dicts must both pass
    // the daemon validator (guards against writer/daemon drift, IOS-08 core goal).
    NSDictionary *scope = @{
        @"ScopedApps": @{
            @"com.acme.app":  @{ @"enabled": @YES },
            @"com.beta.app":  @{ @"enabled": @NO }
        }
    };
    NSArray *enabled = PXInjectionEnabledMainBundlesFromScopePlist(scope);
    // Simulate expansion by appending an extension + WebKit cluster to the enabled mains.
    NSMutableArray *expanded = [enabled mutableCopy];
    [expanded addObject:@"com.acme.app.ext"];
    [expanded addObjectsFromArray:PXInjectionDefaultWebKitHelperBundleIDs()];

    NSArray *tweak = PXInjectionComputeTweakBundles(expanded);
    NSArray *bridge = PXInjectionComputeBridgeBundles(tweak);
    NSDictionary *tweakPlist = PXInjectionFilterPlistDictionary(tweak);
    NSDictionary *bridgePlist = PXInjectionFilterPlistDictionary(bridge);

    NSString *reason = nil;
    PXT_ASSERT(PXInjectionFilterPlistIsValid(tweakPlist, NULL, &reason), "round-trip: tweak plist valid");
    PXT_ASSERT(PXInjectionFilterPlistIsValid(bridgePlist, NULL, &reason), "round-trip: bridge plist valid");

    // Empty scope pipeline must also produce daemon-valid plists.
    NSArray *emptyTweak = PXInjectionComputeTweakBundles(@[]);
    NSArray *emptyBridge = PXInjectionComputeBridgeBundles(emptyTweak);
    PXT_ASSERT(PXInjectionFilterPlistIsValid(PXInjectionFilterPlistDictionary(emptyTweak), NULL, &reason),
               "round-trip: empty-scope tweak plist valid (placeholder-only)");
    PXT_ASSERT(PXInjectionFilterPlistIsValid(PXInjectionFilterPlistDictionary(emptyBridge), NULL, &reason),
               "round-trip: empty-scope bridge plist valid (placeholder-only)");
}

static void PXTTestChecksum(void) {
    NSString *a = PXInjectionBundlesChecksum(@[@"b", @"a", @"c"]);
    NSString *b = PXInjectionBundlesChecksum(@[@"c", @"b", @"a"]);
    PXT_ASSERT([a isEqualToString:b], "checksum is order-independent");
    PXT_ASSERT([a isEqualToString:@"3:a,b,c"], "checksum format count:comma-joined");
}

int PXRunInjectionFilterTests(void) {
    gPass = 0;
    gFail = 0;
    fprintf(stderr, "[IOS-08] PXInjectionFilter tests\n");
    PXTTestNormalize();
    PXTTestClassifiers();
    PXTTestEnabledScope();
    PXTTestTweakBundles();
    PXTTestBridgeBundles();
    PXTTestValidator();
    PXTTestConsistencyRoundTrip();
    PXTTestChecksum();
    fprintf(stderr, "[IOS-08] PXInjectionFilter: %d passed, %d failed\n", gPass, gFail);
    return gFail;
}
