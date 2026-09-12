// macOS integration harness: exercise the actual PXScope adapter with immutable
// fixture snapshots. Including the implementation exposes only test-local state;
// no test setter or alternate ownership path is shipped in the tweak.
#import <Foundation/Foundation.h>
#include <assert.h>
#import "../TLinkIOSTweak/PXScope.m"

NSString *PXGlobalScopePath(void) { return @"/dev/null"; }

static void fixture(PXProcessRole role, NSString *bundle, NSString *parent,
                    NSDictionary *apps, BOOL master, BOOL safari) {
    gPXProcessRole = role;
    gPXProcessBundleID = bundle;
    gPXProcessName = @"fixture-process";
    gPXExtensionOwner = parent;
    gPXHostHomes = nil;
    gScopeGeneration++;
    gSnapshot = [[PXScopeSnapshot alloc] initWithDeviceSpoofEnabled:master
        safariStackEnabled:safari fullSpoofTestModeEnabled:NO
        displayUIScaleEnabled:NO displayPixelMetricsEnabled:NO displayWebScreenEnabled:NO
        scopedApps:apps generation:gScopeGeneration expirationTime:PXMonotonicNow() + 60];
}

int main(void) {
    @autoreleasepool {
        PXCaptureProcessIdentity();
        NSDictionary *app = @{@"com.fixture.app": @{@"enabled": @YES}};
        fixture(PXProcessMainApp, @"com.fixture.app", nil, app, YES, YES);
        assert(PXBootstrapAllows(PXHookCapabilityNative));
        assert(PXProcessIsAllowedForSpoofing(@"com.fixture.app", @"fixture-process", PXScopeOptionNone));
        assert(!PXProcessIsAllowedForSpoofing(@"com.other.app", @"fixture-process", PXScopeOptionNone));
        fixture(PXProcessMainApp, @"com.apple.mobilesafari", nil, app, YES, YES);
        assert(!PXProcessIsAllowedForSpoofing(@"com.apple.mobilesafari", @"Safari", PXScopeOptionAllowSafariAuthStack));

        fixture(PXProcessExtension, @"com.fixture.app.share", @"com.fixture.app", app, YES, YES);
        assert(PXBootstrapAllows(PXHookCapabilityNative));
        assert(PXBundleIsEnabledInScope(@"com.fixture.app.share"));
        assert(PXProcessIsAllowedForSpoofing(@"com.fixture.app.share", @"share", PXScopeOptionNone));
        assert(!PXBootstrapAllows(PXHookCapabilityTelephony));
        fixture(PXProcessExtension, @"com.fixture.app.share", nil, app, YES, YES);
        assert(!PXBootstrapAllows(PXHookCapabilityNative)); // prefix alone is no ownership proof
        NSDictionary *disabledExtension = @{@"com.fixture.app": @{@"enabled": @YES},
            @"com.fixture.app.share": @{@"enabled": @NO}};
        fixture(PXProcessExtension, @"com.fixture.app.share", @"com.fixture.app", disabledExtension, YES, YES);
        assert(!PXBootstrapAllows(PXHookCapabilityNative));
        assert(!PXBundleIsEnabledInScope(@"com.fixture.app.share"));

        fixture(PXProcessWebContent, @"com.apple.WebKit.WebContent", nil, app, YES, YES);
        assert(!PXBootstrapAllows(PXHookCapabilityWebContent)); // unresolved host
        assert(!PXIsWebKitHelperProcess(@"com.fixture.GPUViewer", @"GPU Viewer"));
        assert(PXIsWebKitHelperProcess(@"com.apple.WebKit.WebContent", @"WebContent"));
        assert(PXIsWebKitHelperProcess(@"com.apple.WebKit.FutureHelper", nil));

        fixture(PXProcessMainApp, @"com.fixture.app", nil, app, NO, YES);
        assert(PXBootstrapDecisionForCurrentProcess().reason == PXBootstrapDeniedMaster);
        fixture(PXProcessMainApp, @"com.fixture.app", nil, @{}, YES, YES);
        assert(!PXBootstrapAllows(PXHookCapabilityNative));
        fixture(PXProcessSpringBoard, @"com.apple.springboard", nil, @{}, NO, NO);
        assert(PXBootstrapAllows(PXHookCapabilitySpringBoard));
        assert(!PXBootstrapAllows(PXHookCapabilityNative));
        gPXScopeDecisionDepth = 1;
        assert(!PXBootstrapAllows(PXHookCapabilitySpringBoard)); // nested scope is fail-closed
        assert(!PXDeviceSpoofingEnabled());
        assert(!PXBundleIsEnabledInScope(@"com.fixture.app"));
        assert(PXScopedAppsSnapshot().count == 0);
        gPXScopeDecisionDepth = 0;
        puts("PASS: actual PXScope adapter: scope, extension ownership, unresolved hosts, revocation and recursion");
    }
    return 0;
}
