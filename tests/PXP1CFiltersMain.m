#import <Foundation/Foundation.h>
#include <stdio.h>

extern int PXRunP1CFiltersTests(void);

int main(void) {
    @autoreleasepool {
        int failures = PXRunP1CFiltersTests();
        if (failures == 0) {
            printf("ALL P1-C HELPER TESTS PASSED\n");
            return 0;
        }
        fprintf(stderr, "P1-C HELPER TESTS FAILED: %d\n", failures);
        return 1;
    }
}
