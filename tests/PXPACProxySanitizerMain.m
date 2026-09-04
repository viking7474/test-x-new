#import <Foundation/Foundation.h>
#include <stdio.h>

extern int PXRunPACProxySanitizerTests(void);

int main(void) {
    @autoreleasepool {
        int failures = PXRunPACProxySanitizerTests();
        if (failures == 0) {
            printf("ALL PAC PROXY SANITIZER TESTS PASSED\n");
            return 0;
        }
        fprintf(stderr, "PAC PROXY SANITIZER TESTS FAILED: %d\n", failures);
        return 1;
    }
}
