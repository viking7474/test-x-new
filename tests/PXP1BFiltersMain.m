// PXP1BFiltersMain.m
// Standalone entry point for the P1-B helper tests.
// Build (host macOS/Linux with Foundation):
//   clang -fobjc-arc -framework Foundation -Icommon \
//     common/PXP1BFilters.m tests/PXP1BFiltersTests.m tests/PXP1BFiltersMain.m \
//     -o /tmp/px_p1b_tests && /tmp/px_p1b_tests

#import <Foundation/Foundation.h>

extern int PXRunP1BFiltersTests(void);

int main(void) {
    @autoreleasepool {
        int rc = PXRunP1BFiltersTests();
        if (rc == 0) {
            fprintf(stderr, "ALL P1-B HELPER TESTS PASSED\n");
        }
        return rc;
    }
}
