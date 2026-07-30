#import <Foundation/Foundation.h>
#import "PXP1CFilters.h"
#include <stdio.h>
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

int PXRunP1CFiltersTests(void) {
    gPXT_Failures = 0;
    testScopeBundleEnabled();
    testWebKitHostScoped();
    testSnapshotRefresh();
    testJBPolicyMask();
    testJBStatfs();
    return gPXT_Failures;
}
