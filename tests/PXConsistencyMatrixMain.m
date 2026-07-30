#import <Foundation/Foundation.h>

// Entry point for the standalone CONS-01 harness.
// See docs/IOS-07-consistency-matrix.md for build + run instructions.

extern void PXRunConsistencyMatrixTests(void);
extern void PXRunSystemVersionTransformerTests(void);

int main(int argc, const char *argv[]) {
    (void)argc; (void)argv;
    @autoreleasepool {
        PXRunSystemVersionTransformerTests();
        PXRunConsistencyMatrixTests();
        NSLog(@"[CONS-01] all consistency tests passed");
    }
    return 0;
}
