#ifndef PX_BOOTSTRAP_POLICY_H
#define PX_BOOTSTRAP_POLICY_H

#include <stdbool.h>
#include <stdint.h>

// Pure policy: no Foundation, I/O, hook installation or process-name heuristics.
typedef enum {
    PXProcessUnknown = 0,
    PXProcessMainApp,
    PXProcessExtension,
    PXProcessWebContent,
    PXProcessWebNetworking,
    PXProcessWebGPU,
    PXProcessSafariViewService,
    PXProcessSpringBoard,
    PXProcessSystemDaemon
} PXProcessRole;

typedef enum {
    PXHookCapabilityNone = 0,
    PXHookCapabilityNative = 1u << 0,
    PXHookCapabilityWebContent = 1u << 1,
    PXHookCapabilityWebNetworking = 1u << 2,
    PXHookCapabilityWebGraphics = 1u << 3,
    PXHookCapabilityTelephony = 1u << 4,
    PXHookCapabilitySpringBoard = 1u << 5
} PXHookCapability;

typedef enum {
    PXBootstrapDeniedUnknown = 0,
    PXBootstrapDeniedSystem,
    PXBootstrapDeniedScope,
    PXBootstrapDeniedMaster,
    PXBootstrapDeniedWebStack,
    PXBootstrapAllowed
} PXBootstrapReason;

typedef struct {
    PXProcessRole role;
    uint32_t capabilities;
    PXBootstrapReason reason;
    uint64_t scopeGeneration;
} PXBootstrapDecision;

static inline PXBootstrapDecision PXBootstrapEvaluate(PXProcessRole role,
                                                       bool ownerScoped,
                                                       bool deviceEnabled,
                                                       bool webStackEnabled,
                                                       uint64_t generation) {
    PXBootstrapDecision result = {role, 0, PXBootstrapDeniedUnknown, generation};
    if (role == PXProcessSpringBoard) {
        result.capabilities = PXHookCapabilitySpringBoard;
        result.reason = PXBootstrapAllowed;
        return result;
    }
    if (role == PXProcessSystemDaemon) {
        result.reason = PXBootstrapDeniedSystem;
        return result;
    }
    if (role < PXProcessMainApp || role > PXProcessSafariViewService) return result;
    if (!ownerScoped) {
        result.reason = PXBootstrapDeniedScope;
        return result;
    }
    if (!deviceEnabled) {
        result.reason = PXBootstrapDeniedMaster;
        return result;
    }
    if (role >= PXProcessWebContent && !webStackEnabled) {
        result.reason = PXBootstrapDeniedWebStack;
        return result;
    }
    switch (role) {
        case PXProcessMainApp:
        case PXProcessExtension:
            // WKWebView construction and document-start scripts live in the app.
            result.capabilities = PXHookCapabilityNative | PXHookCapabilityWebContent |
                PXHookCapabilityWebNetworking | PXHookCapabilityWebGraphics;
            if (role == PXProcessMainApp) result.capabilities |= PXHookCapabilityTelephony;
            break;
        case PXProcessWebContent:
            result.capabilities = PXHookCapabilityWebContent | PXHookCapabilityWebGraphics;
            break;
        case PXProcessWebNetworking:
            result.capabilities = PXHookCapabilityWebNetworking;
            break;
        case PXProcessWebGPU:
            result.capabilities = PXHookCapabilityWebGraphics;
            break;
        case PXProcessSafariViewService:
            result.capabilities = PXHookCapabilityWebContent | PXHookCapabilityWebNetworking;
            break;
        default: return result;
    }
    result.reason = PXBootstrapAllowed;
    return result;
}

static inline bool PXBootstrapDecisionAllows(PXBootstrapDecision decision, uint32_t anyCapability) {
    return (decision.capabilities & anyCapability) != 0;
}

#endif
