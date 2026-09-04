#import <Foundation/Foundation.h>
#include <stdio.h>

extern int PXRunPhaseBRegressionGateTests(void);

int main(void) {
    @autoreleasepool {
        int failures = PXRunPhaseBRegressionGateTests();
        if (failures == 0) {
            printf("ALL PHASE-B REGRESSION GATE TESTS PASSED\n");
            return 0;
        }
        fprintf(stderr, "PHASE-B REGRESSION GATE TESTS FAILED: %d\n", failures);
        return 1;
    }
}
