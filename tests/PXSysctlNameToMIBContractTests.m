#import <Foundation/Foundation.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>

static void PXAssertDirectAndIndirectSysctlAgree(const char *key) {
    int mib[CTL_MAXNAME] = {0};
    size_t mibCount = CTL_MAXNAME;
    errno = 0;
    NSCAssert(sysctlnametomib(key, mib, &mibCount) == 0,
              @"sysctlnametomib failed for %s errno=%d", key, errno);
    NSCAssert(mibCount >= 2 && mibCount <= CTL_MAXNAME,
              @"invalid MIB component count for %s: %zu", key, mibCount);

    size_t directLength = 0;
    size_t indirectLength = 0;
    NSCAssert(sysctlbyname(key, NULL, &directLength, NULL, 0) == 0,
              @"direct size query failed for %s", key);
    NSCAssert(sysctl(mib, (u_int)mibCount, NULL, &indirectLength, NULL, 0) == 0,
              @"indirect size query failed for %s", key);
    NSCAssert(directLength == indirectLength,
              @"direct/indirect size diverged for %s (%zu vs %zu)",
              key, directLength, indirectLength);

    if (directLength == 0) return;
    void *direct = calloc(1, directLength);
    void *indirect = calloc(1, indirectLength);
    NSCAssert(direct && indirect, @"allocation failed for %s", key);
    size_t directCapacity = directLength;
    size_t indirectCapacity = indirectLength;
    int directResult = sysctlbyname(key, direct, &directCapacity, NULL, 0);
    int indirectResult = sysctl(mib, (u_int)mibCount, indirect, &indirectCapacity, NULL, 0);
    NSCAssert(directResult == 0 && indirectResult == 0,
              @"direct/indirect value query failed for %s", key);
    NSCAssert(directCapacity == indirectCapacity,
              @"direct/indirect returned length diverged for %s", key);
    NSCAssert(memcmp(direct, indirect, directCapacity) == 0,
              @"direct/indirect bytes diverged for %s", key);
    free(direct);
    free(indirect);
}

void PXRunSysctlNameToMIBContractTests(void) {
    PXAssertDirectAndIndirectSysctlAgree("kern.osrelease");
    PXAssertDirectAndIndirectSysctlAgree("hw.machine");

    // A one-int buffer cannot hold the normal two-component kern.osrelease MIB.
    // Darwin reports ENOMEM rather than fabricating/truncating the numeric name.
    int tiny[1] = {0};
    size_t tinyCount = 1;
    errno = 0;
    int tinyResult = sysctlnametomib("kern.osrelease", tiny, &tinyCount);
    NSCAssert(tinyResult == -1 && errno == ENOMEM,
              @"short MIB buffer did not preserve ENOMEM contract: result=%d errno=%d",
              tinyResult, errno);

    int unknown[CTL_MAXNAME] = {0};
    size_t unknownCount = CTL_MAXNAME;
    errno = 0;
    int unknownResult = sysctlnametomib("weaponx.parity.this.key.must.not.exist",
                                        unknown,
                                        &unknownCount);
    NSCAssert(unknownResult == -1 && errno != 0,
              @"unknown sysctl name unexpectedly resolved");

    NSLog(@"[A-03] sysctlnametomib contract PASS");
}
