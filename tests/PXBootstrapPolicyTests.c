#include "PXBootstrapPolicy.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    const uint32_t web = PXHookCapabilityWebContent | PXHookCapabilityWebNetworking |
        PXHookCapabilityWebGraphics;
    const uint32_t expected[] = {
        0, PXHookCapabilityNative | PXHookCapabilityTelephony | web,
        PXHookCapabilityNative | web,
        PXHookCapabilityWebContent | PXHookCapabilityWebGraphics,
        PXHookCapabilityWebNetworking, PXHookCapabilityWebGraphics,
        PXHookCapabilityWebContent | PXHookCapabilityWebNetworking,
        PXHookCapabilitySpringBoard, 0
    };
    unsigned cases = 0;
    for (int role = PXProcessUnknown; role <= PXProcessSystemDaemon; ++role) {
        for (int scope = 0; scope < 2; ++scope) {
            for (int master = 0; master < 2; ++master) {
                for (int safari = 0; safari < 2; ++safari) {
                    PXBootstrapDecision d = PXBootstrapEvaluate((PXProcessRole)role,
                        scope != 0, master != 0, safari != 0, 42);
                    assert(d.role == (PXProcessRole)role && d.scopeGeneration == 42);
                    uint32_t wanted = expected[role];
                    if (role != PXProcessSpringBoard && (!scope || !master)) wanted = 0;
                    if (role >= PXProcessWebContent && role <= PXProcessSafariViewService && !safari) wanted = 0;
                    assert(d.capabilities == wanted);
                    assert(PXBootstrapDecisionAllows(d, PXHookCapabilityNative) ==
                        (wanted != 0 && (role == PXProcessMainApp || role == PXProcessExtension)));
                    assert(!PXBootstrapDecisionAllows(d, 0));
                    if (role >= PXProcessWebContent && role <= PXProcessSafariViewService) {
                        assert(!PXBootstrapDecisionAllows(d, PXHookCapabilityNative |
                            PXHookCapabilityTelephony | PXHookCapabilitySpringBoard));
                    }
                    ++cases;
                }
            }
        }
    }
    // Unresolved/unscoped hosts and unscoped Safari cannot become allowed just
    // because the global Safari stack/master switch is enabled.
    assert(PXBootstrapEvaluate(PXProcessWebContent, false, true, true, 1).capabilities == 0);
    assert(PXBootstrapEvaluate(PXProcessMainApp, false, true, true, 1).capabilities == 0);
    // Re-evaluation after revocation removes every spoof capability. SpringBoard
    // keeps only its independent Freeze/Indicator capability with master OFF.
    assert(PXBootstrapEvaluate(PXProcessMainApp, true, true, true, 1).capabilities != 0);
    assert(PXBootstrapEvaluate(PXProcessMainApp, false, true, true, 2).capabilities == 0);
    assert(PXBootstrapEvaluate(PXProcessMainApp, true, false, true, 3).capabilities == 0);
    assert(PXBootstrapEvaluate((PXProcessRole)99, true, true, true, 4).capabilities == 0);
    assert(PXBootstrapEvaluate(PXProcessUnknown, true, true, true, 4).reason == PXBootstrapDeniedUnknown);
    assert(PXBootstrapEvaluate(PXProcessSystemDaemon, true, true, true, 4).reason == PXBootstrapDeniedSystem);
    assert(PXBootstrapEvaluate(PXProcessWebGPU, true, true, false, 4).reason == PXBootstrapDeniedWebStack);
    printf("PASS: bootstrap capability matrix (%u combinations), revocation and unknown roles\n", cases);
    return 0;
}
