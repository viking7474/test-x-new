// HookOwnership.h
// Legacy ownership flags — retained for modules still checking gOwner* during transition.
// New multi-module native hooks must register with PXNativeHookCoordinator and must NOT
// call MSHookFunction for coordinator-owned symbols (see scripts/audit_native_hooks.sh).

#include <objc/objc.h>

extern BOOL gOwnerSysctlInstalled;
extern BOOL gOwnerSysctlBynameInstalled;
extern BOOL gOwnerUnameInstalled;
extern BOOL gOwnerIOKitInstalled;
extern BOOL gOwnerMGInstalled;
extern BOOL gOwnerCFSystemInstalled;
