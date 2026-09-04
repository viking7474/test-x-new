#import <Foundation/Foundation.h>
#import "PXP1CFilters.h"
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <sys/mount.h>

int PXRunP1CFiltersTests(void);

static int gPXT_Failures = 0;

#define PXT_ASSERT(cond, desc) do { \
    if (!(cond)) { \
        gPXT_Failures++; \
        fprintf(stderr, "  FAIL: %s\n", (desc)); \
    } \
} while (0)

// Local mirrors of the JB policy bits. Values must match the kPXJBPolicy*
// enum in JailbreakBypassHooks.x (Master = 1<<0, feature bits above it).
enum {
    kBitMaster = 1ull << 0,
    kBitStatfs = 1ull << 1,
    kBitDyld   = 1ull << 2,
};

static void testScopeBundleEnabled(void) {
    NSDictionary *scoped = @{
        @"com.foo.app": @{ @"enabled": @YES },
        @"com.bar.app": @{ @"enabled": @NO },
        @"com.baz.app": @{ @"other": @1 },
        @"com.bad.app": @"notADict",
    };
    PXT_ASSERT(PXP1CScopeBundleEnabled(scoped, @"com.foo.app"), "enabled bundle scoped");
    PXT_ASSERT(!PXP1CScopeBundleEnabled(scoped, @"com.bar.app"), "disabled bundle not scoped");
    PXT_ASSERT(!PXP1CScopeBundleEnabled(scoped, @"com.baz.app"), "missing enabled key not scoped");
    PXT_ASSERT(!PXP1CScopeBundleEnabled(scoped, @"com.bad.app"), "non-dict entry not scoped");
    PXT_ASSERT(!PXP1CScopeBundleEnabled(scoped, @"com.absent.app"), "absent bundle not scoped");
    PXT_ASSERT(!PXP1CScopeBundleEnabled(scoped, @""), "empty bundle id not scoped");
    PXT_ASSERT(!PXP1CScopeBundleEnabled(scoped, nil), "nil bundle id not scoped");
    PXT_ASSERT(!PXP1CScopeBundleEnabled(nil, @"com.foo.app"), "nil dict not scoped");
}

static void testWebKitHostScoped(void) {
    PXT_ASSERT(PXP1CWebKitHostScoped(YES, @"com.foo.app", NO, YES), "resolved+enabled host scoped");
    PXT_ASSERT(!PXP1CWebKitHostScoped(NO, @"com.foo.app", NO, YES), "device spoof off => not scoped");
    PXT_ASSERT(!PXP1CWebKitHostScoped(YES, nil, NO, YES), "nil host fails closed");
    PXT_ASSERT(!PXP1CWebKitHostScoped(YES, @"", NO, YES), "empty host fails closed");
    PXT_ASSERT(!PXP1CWebKitHostScoped(YES, @"com.foo.app", YES, YES), "critical host not scoped");
    PXT_ASSERT(!PXP1CWebKitHostScoped(YES, @"com.foo.app", NO, NO), "host disabled in scope not scoped");
}

static void testSnapshotRefresh(void) {
    PXT_ASSERT(PXP1CSnapshotNeedsRefresh(NO, 100.0, 200.0), "no snapshot => refresh");
    PXT_ASSERT(PXP1CSnapshotNeedsRefresh(YES, 200.0, 200.0), "at expiration => refresh");
    PXT_ASSERT(PXP1CSnapshotNeedsRefresh(YES, 250.0, 200.0), "past expiration => refresh");
    PXT_ASSERT(!PXP1CSnapshotNeedsRefresh(YES, 150.0, 200.0), "before expiration => valid");
}

static void testJBPolicyMask(void) {
    // Master off (launch or runtime) => requested 0 => full pass-through.
    PXT_ASSERT(PXP1CJBRequestedMask(NO, kBitMaster, kBitStatfs | kBitDyld) == 0,
               "master off => requested mask 0");
    uint64_t requested = PXP1CJBRequestedMask(YES, kBitMaster, kBitStatfs);
    PXT_ASSERT(requested == (kBitMaster | kBitStatfs), "master on => master|features");

    // Installed at launch excludes dyld; requested wants statfs + dyld.
    uint64_t installed = kBitMaster | kBitStatfs;
    uint64_t requestedBoth = kBitMaster | kBitStatfs | kBitDyld;
    uint64_t effective = PXP1CJBEffectivePolicyMask(requestedBoth, installed);
    PXT_ASSERT(effective == (kBitMaster | kBitStatfs), "effective = requested & installed");

    PXT_ASSERT(PXP1CJBFeatureActive(effective, kBitMaster, kBitStatfs), "statfs active");
    PXT_ASSERT(!PXP1CJBFeatureActive(effective, kBitMaster, kBitDyld),
               "dyld not active (not installed at launch => needs relaunch)");

    // Runtime master off => effective 0 => nothing active (pass-through).
    uint64_t offEffective = PXP1CJBEffectivePolicyMask(
        PXP1CJBRequestedMask(NO, kBitMaster, kBitStatfs), installed);
    PXT_ASSERT(offEffective == 0, "runtime master off => effective 0");
    PXT_ASSERT(!PXP1CJBFeatureActive(offEffective, kBitMaster, kBitStatfs),
               "master off => statfs pass-through");

    // A feature bit without the master bit is never active.
    PXT_ASSERT(!PXP1CJBFeatureActive(kBitStatfs, kBitMaster, kBitStatfs),
               "feature without master not active");
}

static void testJBStatfs(void) {
    PXT_ASSERT(PXP1CJBIsSensitiveMountPath("/"), "root sensitive");
    PXT_ASSERT(PXP1CJBIsSensitiveMountPath("/var"), "/var sensitive");
    PXT_ASSERT(PXP1CJBIsSensitiveMountPath("/private"), "/private sensitive");
    PXT_ASSERT(PXP1CJBIsSensitiveMountPath("/private/var"), "/private/var sensitive");
    PXT_ASSERT(!PXP1CJBIsSensitiveMountPath("/Applications"), "/Applications not sensitive");
    PXT_ASSERT(!PXP1CJBIsSensitiveMountPath(NULL), "NULL not sensitive");

    uint32_t out = PXP1CJBNormalizeStatfsFlags(0);
    PXT_ASSERT((out & (uint32_t)MNT_RDONLY) != 0, "normalize sets MNT_RDONLY");
    uint32_t keep = PXP1CJBNormalizeStatfsFlags(0x40u);
    PXT_ASSERT((keep & 0x40u) != 0 && (keep & (uint32_t)MNT_RDONLY) != 0,
               "normalize preserves other flags");
}

static void testB01DirectoryAndStat64Contracts(void) {
    char path[PATH_MAX];

    PXT_ASSERT(PXP1CJBNormalizeAbsolutePath("/var/mobile/Containers/Data/Application/ABC/Documents",
                                            path,
                                            sizeof(path)),
               "B-01 normal file provenance normalizes");
    PXT_ASSERT(strcmp(path, "/var/mobile/Containers/Data/Application/ABC/Documents") == 0,
               "B-01 normal file path changed");

    PXT_ASSERT(PXP1CJBJoinAbsoluteBaseAndNormalize("/private/var/jb",
                                                   "Applications/Cydia.app",
                                                   path,
                                                   sizeof(path)),
               "B-01 relative dirfd path joins safely");
    PXT_ASSERT(strcmp(path, "/private/var/jb/Applications/Cydia.app") == 0,
               "B-01 relative dirfd/rootless normalization drifted");

    PXJBFilesystemDisposition hidden =
        PXP1CJBResolvedPathDisposition(kPXJBFilesystemOperationRead, YES, NO);
    PXT_ASSERT(hidden == kPXJBFilesystemHide,
               "B-01 hidden path must classify HIDE");
    PXT_ASSERT(PXP1CJBErrnoForDisposition(hidden) == ENOENT,
               "B-01 path-based hidden query must use ENOENT contract");

    PXT_ASSERT(!PXP1CJBJoinAbsoluteBaseAndNormalize(NULL,
                                                    "Applications/Cydia.app",
                                                    path,
                                                    sizeof(path)),
               "B-01 invalid/missing fd provenance must stay unresolved");
    PXT_ASSERT(PXP1CJBErrnoForDisposition(kPXJBFilesystemUnresolved) == 0,
               "B-01 unresolved fd must fail open without synthetic errno");

    PXJBFilesystemDisposition normal =
        PXP1CJBResolvedPathDisposition(kPXJBFilesystemOperationRead, NO, NO);
    PXT_ASSERT(normal == kPXJBFilesystemAllow,
               "B-01 normal query must remain ALLOW/original");
}

static void testB02ReadQueryErrnoContracts(void) {
    PXT_ASSERT(PXP1CJBErrnoForHiddenRead(kPXJBHiddenReadErrnoPathNotFound) == ENOENT,
               "B-02 hidden path read must use ENOENT");
    PXT_ASSERT(PXP1CJBErrnoForHiddenRead(kPXJBHiddenReadErrnoBadFileDescriptor) == EBADF,
               "B-02 hidden fd read must use EBADF");
    PXT_ASSERT(PXP1CJBErrnoForHiddenRead(kPXJBHiddenReadErrnoPermissionDenied) == EPERM,
               "B-02 hidden listxattr must preserve EPERM parity");

    PXJBFilesystemDisposition normal =
        PXP1CJBResolvedPathDisposition(kPXJBFilesystemOperationRead, NO, NO);
    PXJBFilesystemDisposition hidden =
        PXP1CJBResolvedPathDisposition(kPXJBFilesystemOperationRead, YES, NO);
    PXT_ASSERT(normal == kPXJBFilesystemAllow,
               "B-02 normal read query must stay pass-through");
    PXT_ASSERT(hidden == kPXJBFilesystemHide,
               "B-02 hidden read query must be blockable");
    PXT_ASSERT(PXP1CJBErrnoForDisposition(kPXJBFilesystemUnresolved) == 0,
               "B-02 unresolved provenance must not synthesize errno");
}

static void testB03ProcessSocketContracts(void) {
    gid_t groups[] = {501, 0, 20, 0, 12};
    int visible = PXP1CJBCompactNonRootGroups(groups, 5);
    PXT_ASSERT(visible == 3, "B-03 getgroups compact count drifted");
    PXT_ASSERT(groups[0] == 501 && groups[1] == 20 && groups[2] == 12,
               "B-03 getgroups visible order changed");
    PXT_ASSERT(PXP1CJBCompactNonRootGroups(NULL, 0) == 0,
               "B-03 getgroups sizing/null contract drifted");
    PXT_ASSERT(PXP1CJBCompactNonRootGroups(NULL, -1) == -1,
               "B-03 getgroups original error must pass through");

    PXT_ASSERT(PXP1CJBEndpointPortShouldHide(27042),
               "B-03 peer port 27042 must hide");
    PXT_ASSERT(PXP1CJBEndpointPortShouldHide(27043),
               "B-03 peer port 27043 must hide");
    PXT_ASSERT(!PXP1CJBEndpointPortShouldHide(22),
               "B-03 peer filter must stay narrower than connect policy");
    PXT_ASSERT(!PXP1CJBEndpointPortShouldHide(443),
               "B-03 ordinary peer port must stay visible");
}

static void testB05SecondaryObjCContracts(void) {
    NSArray *cleanArguments = @[@"/Applications/Demo.app/Demo", @"--safe-mode"];
    PXT_ASSERT(PXP1CJBFilterProcessArguments(cleanArguments, YES) == cleanArguments,
               "B-05 clean argv must preserve exact original array");
    PXT_ASSERT(PXP1CJBFilterProcessArguments(cleanArguments, NO) == cleanArguments,
               "B-05 scope/policy off argv must preserve exact original array");

    NSArray *mixedArguments = @[
        @"/Applications/Demo.app/Demo",
        @"--jailbreak-probe",
        @"dyld_insert_libraries=/tmp/inject.dylib",
        @"--safe-mode",
        @"/var/jb/roothide/config",
        @"theos-build",
        @"substrate-loader",
    ];
    NSArray *filteredArguments = PXP1CJBFilterProcessArguments(mixedArguments, YES);
    PXT_ASSERT(filteredArguments.count == 2,
               "B-05 argv must remove only the five recovered marker families");
    PXT_ASSERT([filteredArguments[0] isEqual:@"/Applications/Demo.app/Demo"] &&
               [filteredArguments[1] isEqual:@"--safe-mode"],
               "B-05 argv visible order changed");
    PXT_ASSERT(PXP1CJBArgumentContainsInstrumentationMarker(@"prefix-dyld-suffix"),
               "B-05 argv exact lowercase marker must match");
    PXT_ASSERT(!PXP1CJBArgumentContainsInstrumentationMarker(@"prefix-DYLD-suffix"),
               "B-05 argv marker semantics must remain iFake case-sensitive");
    PXT_ASSERT(!PXP1CJBArgumentContainsInstrumentationMarker(@"--ordinary-option"),
               "B-05 ordinary argv marker false-positive");

    PXT_ASSERT(PXP1CJBURLSchemeShouldHide(@"cydia"),
               "B-05 cydia URL scheme must hide");
    PXT_ASSERT(PXP1CJBURLSchemeShouldHide(@"my-trollstore-helper"),
               "B-05 18-fragment URL corpus substring semantics drifted");
    PXT_ASSERT(PXP1CJBURLSchemeShouldHide(@"SileoSDK"),
               "B-05 URL scheme normalization must be lowercase-insensitive");
    PXT_ASSERT(!PXP1CJBURLSchemeShouldHide(@"https"),
               "B-05 ordinary URL scheme must stay visible");

    NSArray *frames = @[@1, @2, @3];
    NSArray *redacted = PXP1CJBArrayByReplacingMatchingObjects(
        frames,
        YES,
        ^BOOL(id object) { return [object isEqual:@2]; },
        @0);
    PXT_ASSERT(redacted.count == frames.count,
               "B-05 callstack redaction must preserve cardinality");
    PXT_ASSERT([redacted[0] isEqual:@1] && [redacted[1] isEqual:@0] && [redacted[2] isEqual:@3],
               "B-05 callstack redaction must preserve visible frame order/shape");
    PXT_ASSERT([frames[1] isEqual:@2],
               "B-05 callstack redaction must not mutate original array");
    NSArray *unchanged = PXP1CJBArrayByReplacingMatchingObjects(
        frames,
        YES,
        ^BOOL(__unused id object) { return NO; },
        @0);
    PXT_ASSERT(unchanged == frames,
               "B-05 no matching callstack frame must return exact original array");
}

static void testC01DebuggerScalarProjection(void) {
    const uint64_t masterBit = 1ull << 0;
    const uint64_t scDebuggerBit = 1ull << 11;

    uint64_t scopeOffRequested = PXP1CJBRequestedMask(NO, masterBit, scDebuggerBit);
    PXT_ASSERT(scopeOffRequested == 0,
               "C-01 scope/master off must request no debugger capability");

    uint64_t requested = PXP1CJBRequestedMask(YES, masterBit, scDebuggerBit);
    uint64_t symbolAbsentEffective = PXP1CJBEffectivePolicyMask(requested, masterBit);
    PXT_ASSERT(!PXP1CJBFeatureActive(symbolAbsentEffective, masterBit, scDebuggerBit),
               "C-01 symbol-absent capability must remain inactive");

    uint64_t symbolReadyEffective = PXP1CJBEffectivePolicyMask(requested,
                                                               masterBit | scDebuggerBit);
    PXT_ASSERT(PXP1CJBFeatureActive(symbolReadyEffective, masterBit, scDebuggerBit),
               "C-01 audited debugger capability must become active");

    PXT_ASSERT(PXP1CJBProjectedDebuggerState(YES, NO) == YES,
               "C-01 capability/scope off must preserve original true debugger state");
    PXT_ASSERT(PXP1CJBProjectedDebuggerState(NO, NO) == NO,
               "C-01 capability/scope off must preserve original false debugger state");
    PXT_ASSERT(PXP1CJBProjectedDebuggerState(YES, YES) == NO,
               "C-01 active capability must project original true to false");
    PXT_ASSERT(PXP1CJBProjectedDebuggerState(NO, YES) == NO,
               "C-01 active capability must keep original false false");
}

static void testJBNativeQuerySanitizerContract(void) {
    char path[PATH_MAX];
    PXT_ASSERT(PXP1CJBNormalizeAbsolutePath("/private//var/jb/./usr/../Library", path, sizeof(path)),
               "rootless path normalizes");
    PXT_ASSERT(strcmp(path, "/private/var/jb/Library") == 0,
               "rootless lexical normalization preserves components");
    PXT_ASSERT(PXP1CJBNormalizeAbsolutePath("/Applications/../var/./mobile//Containers", path, sizeof(path)),
               "normal app path normalizes");
    PXT_ASSERT(strcmp(path, "/var/mobile/Containers") == 0,
               "normal path normalization correct");
    PXT_ASSERT(PXP1CJBNormalizeAbsolutePath("/link/../private/preboot/normal-volume", path, sizeof(path)),
               "symlink-ish lexical path accepted without dereference");
    PXT_ASSERT(strcmp(path, "/private/preboot/normal-volume") == 0,
               "symlink-ish lexical result correct");
    PXT_ASSERT(!PXP1CJBNormalizeAbsolutePath(NULL, path, sizeof(path)), "NULL path rejected");
    PXT_ASSERT(!PXP1CJBNormalizeAbsolutePath("var/jb", path, sizeof(path)), "relative path rejected");
    PXT_ASSERT(!PXP1CJBNormalizeAbsolutePath("/var/jb", path, 1), "undersized output rejected");
    char exactFit[sizeof("/var/jb")];
    PXT_ASSERT(PXP1CJBNormalizeAbsolutePath("/var/jb", exactFit, sizeof(exactFit)),
               "exact output length plus NUL must fit");
    PXT_ASSERT(strcmp(exactFit, "/var/jb") == 0, "exact-fit content changed");

    PXT_ASSERT(PXP1CJBJoinAbsoluteBaseAndNormalize("/var/mobile/Containers/Data/Application/ABC",
                                                   "Documents/../Library/file.plist",
                                                   path,
                                                   sizeof(path)),
               "relative path joins against absolute provenance");
    PXT_ASSERT(strcmp(path, "/var/mobile/Containers/Data/Application/ABC/Library/file.plist") == 0,
               "relative join result correct");
    PXT_ASSERT(!PXP1CJBJoinAbsoluteBaseAndNormalize("relative/base", "var/jb", path, sizeof(path)),
               "relative base rejected");
    PXT_ASSERT(!PXP1CJBJoinAbsoluteBaseAndNormalize(NULL, "var/jb", path, sizeof(path)),
               "missing dirfd provenance rejected");
    PXT_ASSERT(!PXP1CJBJoinAbsoluteBaseAndNormalize("/var/mobile", "/absolute/not-relative", path, sizeof(path)),
               "absolute child rejected by relative join helper");

    PXJBFilesystemDisposition hidden = PXP1CJBResolvedPathDisposition(kPXJBFilesystemOperationRead, YES, NO);
    PXT_ASSERT(hidden == kPXJBFilesystemHide, "hidden read => HIDE");
    PXT_ASSERT(PXP1CJBErrnoForDisposition(hidden) == ENOENT, "HIDE => ENOENT");
    PXJBFilesystemDisposition denied = PXP1CJBResolvedPathDisposition(kPXJBFilesystemOperationWrite, YES, YES);
    PXT_ASSERT(denied == kPXJBFilesystemDenyWrite, "write probe denial wins over hidden path");
    PXT_ASSERT(PXP1CJBErrnoForDisposition(denied) == EACCES, "DENY_WRITE => EACCES");
    PXT_ASSERT(PXP1CJBDispositionBlocksWrite(denied), "DENY_WRITE blocks mutation");
    PXT_ASSERT(PXP1CJBResolvedPathDisposition(kPXJBFilesystemOperationRead, NO, YES) == kPXJBFilesystemAllow,
               "write-probe marker alone does not block read");
    PXT_ASSERT(PXP1CJBErrnoForDisposition(kPXJBFilesystemUnresolved) == 0,
               "UNRESOLVED has no synthetic errno");
    PXT_ASSERT(!PXP1CJBDispositionBlocksWrite(kPXJBFilesystemUnresolved),
               "UNRESOLVED fails open");
}

int PXRunP1CFiltersTests(void) {
    gPXT_Failures = 0;
    testScopeBundleEnabled();
    testWebKitHostScoped();
    testSnapshotRefresh();
    testJBPolicyMask();
    testJBStatfs();
    testB01DirectoryAndStat64Contracts();
    testB02ReadQueryErrnoContracts();
    testB03ProcessSocketContracts();
    testB05SecondaryObjCContracts();
    testC01DebuggerScalarProjection();
    testJBNativeQuerySanitizerContract();
    return gPXT_Failures;
}
