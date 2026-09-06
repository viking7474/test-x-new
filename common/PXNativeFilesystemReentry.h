#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Marks native filesystem/mount callbacks where re-entering Foundation file or
// bundle metadata APIs can recursively acquire CoreServices' MountInfo lock.
// This API is deliberately Foundation-free and thread-local.
void PXNativeFilesystemCriticalEnter(void);
void PXNativeFilesystemCriticalLeave(void);
bool PXNativeFilesystemCriticalIsActive(void);
uint32_t PXNativeFilesystemCriticalDepth(void);

typedef struct {
    bool entered;
} PXNativeFilesystemCriticalScope;

static inline PXNativeFilesystemCriticalScope PXNativeFilesystemCriticalScopeBegin(void) {
    PXNativeFilesystemCriticalEnter();
    PXNativeFilesystemCriticalScope scope = { true };
    return scope;
}

static inline void PXNativeFilesystemCriticalScopeEnd(PXNativeFilesystemCriticalScope *scope) {
    if (scope && scope->entered) {
        scope->entered = false;
        PXNativeFilesystemCriticalLeave();
    }
}

#define PX_NATIVE_FILESYSTEM_CRITICAL_SCOPE(name) \
    PXNativeFilesystemCriticalScope name __attribute__((cleanup(PXNativeFilesystemCriticalScopeEnd))) = \
        PXNativeFilesystemCriticalScopeBegin()

#ifdef __cplusplus
}
#endif
