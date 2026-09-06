#include "PXNativeFilesystemReentry.h"

#include <limits.h>

static __thread uint32_t gPXNativeFilesystemCriticalDepth = 0;

void PXNativeFilesystemCriticalEnter(void) {
    if (gPXNativeFilesystemCriticalDepth != UINT32_MAX) {
        gPXNativeFilesystemCriticalDepth++;
    }
}

void PXNativeFilesystemCriticalLeave(void) {
    if (gPXNativeFilesystemCriticalDepth > 0) {
        gPXNativeFilesystemCriticalDepth--;
    }
}

bool PXNativeFilesystemCriticalIsActive(void) {
    return gPXNativeFilesystemCriticalDepth != 0;
}

uint32_t PXNativeFilesystemCriticalDepth(void) {
    return gPXNativeFilesystemCriticalDepth;
}
