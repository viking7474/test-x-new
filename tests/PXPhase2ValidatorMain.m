#import <Foundation/Foundation.h>

extern void PXRunPhase2ValidatorTests(void);

int main(int argc, const char *argv[]) {
    (void)argc; (void)argv;
    @autoreleasepool {
        PXRunPhase2ValidatorTests();
        NSLog(@"[PHASE-2] all validator tests passed");
    }
    return 0;
}
