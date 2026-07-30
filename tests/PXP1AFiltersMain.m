#import <Foundation/Foundation.h>

// Standalone host runner for the P1-A pure-helper tests.
// Build/run instructions: docs/P1-A-userdefaults-devicemodel-pasteboard.md.

extern int PXRunP1AFiltersTests(void);

int main(int argc, const char *argv[]) {
    (void)argc; (void)argv;
    @autoreleasepool {
        int failures = PXRunP1AFiltersTests();
        if (failures == 0) {
            fprintf(stderr, "ALL P1-A HELPER TESTS PASSED\n");
        } else {
            fprintf(stderr, "%d P1-A HELPER TEST(S) FAILED\n", failures);
        }
        return failures == 0 ? 0 : 1;
    }
}
