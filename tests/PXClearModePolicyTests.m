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
    PXRequire(quick.options == PXClearOptionNone &&
              full.options == PXClearOptionNone &&
              deep.options == PXClearOptionNone,
              @"legacy/default request initializers must keep optional destructive policies OFF");
    PXRequire(!quick.deepClean && !full.deepClean && deep.deepClean,
              @"only Deep may expose deepClean=YES");
    PXRequire(!PXClearModeIncludesExtendedContainers(PXClearModeQuick),
              @"Quick must exclude extended containers");
    PXRequire(PXClearModeIncludesExtendedContainers(PXClearModeFull) &&
              PXClearModeIncludesExtendedContainers(PXClearModeDeep),
              @"Full/Deep must include exact extended containers");
    PXRequire(PXClearModeIncludesDeepDiagnostics(PXClearModeDeep),
              @"Deep diagnostics policy missing");

    PXClearRequest *iCloud = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                                                       scopes:PXClearScopeDefaultMask
                                                                         mode:PXClearModeFull
                                                                      options:PXClearOptionICloudData];
    PXRequire(iCloud != nil && (iCloud.options & PXClearOptionICloudData) != 0,
              @"explicit iCloud policy must be snapshotted in the immutable request");
    PXRequire(![iCloud isEqual:full],
              @"request equality must include optional destructive policy bits");
    PXRequire([iCloud copy] == iCloud,
              @"immutable request copy contract changed");

    PXClearRequest *safariShared = [[PXClearRequest alloc] initWithBundleIdentifier:@"com.apple.mobilesafari"
                                                                            scopes:PXClearScopeDefaultMask
                                                                              mode:PXClearModeDeep
                                                                           options:PXClearOptionSafariSharedWebData];
    PXRequire(safariShared != nil &&
              (safariShared.options & PXClearOptionSafariSharedWebData) != 0 &&
              (safariShared.options & PXClearOptionICloudData) == 0,
              @"explicit Safari shared-web policy must be snapshotted independently");

    PXClearRequest *combinedOptions = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                                                               scopes:PXClearScopeDefaultMask
                                                                                 mode:PXClearModeDeep
                                                                              options:(PXClearOptionICloudData | PXClearOptionSafariSharedWebData)];
    PXRequire(combinedOptions != nil &&
              combinedOptions.options == (PXClearOptionICloudData | PXClearOptionSafariSharedWebData),
              @"known Clear option bits must compose without losing policy state");

    PXClearRequest *compatFull = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                                                           scopes:PXClearScopeDefaultMask
                                                                        deepClean:NO];
    PXClearRequest *compatDeep = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                                                           scopes:PXClearScopeDefaultMask
                                                                        deepClean:YES];
    PXRequire(compatFull.mode == PXClearModeFull && compatDeep.mode == PXClearModeDeep,
              @"legacy initializer mapping changed");
    PXRequire(compatFull.options == PXClearOptionNone && compatDeep.options == PXClearOptionNone,
              @"legacy deepClean initializer must not implicitly arm optional destructive policies");

    PXClearRequest *invalid = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                                                         scopes:PXClearScopeDefaultMask
                                                                           mode:(PXClearMode)99];
    PXRequire(invalid == nil, @"invalid mode must fail closed");
    PXClearRequest *invalidOptions = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                                                                scopes:PXClearScopeDefaultMask
                                                                                  mode:PXClearModeFull
                                                                               options:(PXClearOptions)(1UL << 20)];
    PXRequire(invalidOptions == nil, @"unknown request option bits must fail closed");
}
