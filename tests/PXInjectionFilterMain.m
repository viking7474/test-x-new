#import <Foundation/Foundation.h>

// Standalone host runner for the IOS-08 injection-filter tests.
// Build/run instructions: docs/IOS-08-injection-filter.md.

extern int PXRunInjectionFilterTests(void);

int main(int argc, const char *argv[]) {
    (void)argc; (void)argv;
    @autoreleasepool {
        int failures = PXRunInjectionFilterTests();
        if (failures == 0) {
            fprintf(stderr, "ALL INJECTION FILTER TESTS PASSED\n");
        } else {
            fprintf(stderr, "%d INJECTION FILTER TEST(S) FAILED\n", failures);
        }
        return failures == 0 ? 0 : 1;
    }
}
