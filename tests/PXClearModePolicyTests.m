#import <Foundation/Foundation.h>
#import "../PXClearRequest.h"

static void PXRequire(BOOL condition, NSString *message) {
    if (!condition) @throw [NSException exceptionWithName:@"PXClearModePolicyTestFailure"
                                                    reason:message userInfo:nil];
}

void PXRunClearModePolicyTests(void) {
    NSString *bundleID = @"com.example.phase8";
    PXClearRequest *quick = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                                                      scopes:PXClearScopeDefaultMask
                                                                        mode:PXClearModeQuick];
    PXClearRequest *full = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                                                     scopes:PXClearScopeDefaultMask
                                                                       mode:PXClearModeFull];
    PXClearRequest *deep = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                                                     scopes:PXClearScopeDefaultMask
                                                                       mode:PXClearModeDeep];
    PXRequire(quick && full && deep, @"valid modes must construct requests");
    PXRequire(!quick.deepClean && !full.deepClean && deep.deepClean,
              @"only Deep may expose deepClean=YES");
    PXRequire(!PXClearModeIncludesExtendedContainers(PXClearModeQuick),
              @"Quick must exclude extended containers");
    PXRequire(PXClearModeIncludesExtendedContainers(PXClearModeFull) &&
              PXClearModeIncludesExtendedContainers(PXClearModeDeep),
              @"Full/Deep must include exact extended containers");
    PXRequire(PXClearModeIncludesDeepDiagnostics(PXClearModeDeep),
              @"Deep diagnostics policy missing");

    PXClearRequest *compatFull = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                                                           scopes:PXClearScopeDefaultMask
                                                                        deepClean:NO];
    PXClearRequest *compatDeep = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                                                           scopes:PXClearScopeDefaultMask
                                                                        deepClean:YES];
    PXRequire(compatFull.mode == PXClearModeFull && compatDeep.mode == PXClearModeDeep,
              @"legacy initializer mapping changed");
    PXClearRequest *invalid = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                                                         scopes:PXClearScopeDefaultMask
                                                                           mode:(PXClearMode)99];
    PXRequire(invalid == nil, @"invalid mode must fail closed");
}
