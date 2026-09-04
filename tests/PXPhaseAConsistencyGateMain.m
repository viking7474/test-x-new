#import <Foundation/Foundation.h>

void PXRunPhaseAConsistencyGateTests(void);

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        (void)argc;
        (void)argv;
        PXRunPhaseAConsistencyGateTests();
    }
    return 0;
}
