#import <Foundation/Foundation.h>
#import <substrate.h>
#import <dlfcn.h>

#import "IdentifierManager.h"
#import "PXScope.h"
#import "PXIdentitySnapshot.h"
#import "PXIdentitySurfaceRegistry.h"
#import "PXManagedConfigurationIdentity.h"
#import "TLinkIOSLogging.h"

// iFake's six replacements and saved originals are all no-argument pointer-return
// functions.  Use `id` to preserve the Objective-C object calling convention
// without claiming a stronger NSString/CF ownership contract than the binary proves.
typedef id (*PXMCObjectGetter)(void);

static PXMCObjectGetter gOrigMCCTIMEI = NULL;
static PXMCObjectGetter gOrigMCIOSerialString = NULL;
static PXMCObjectGetter gOrigMCProductVersion = NULL;
static PXMCObjectGetter gOrigMCProductBuildVersion = NULL;
static PXMCObjectGetter gOrigMCGestaltGetProductName = NULL;
static PXMCObjectGetter gOrigMCGestaltGetDeviceUUID = NULL;

static __thread BOOL gInsideManagedConfigurationIdentityHook = NO;

static BOOL PXMCProcessScopeAllowsProjection(void) {
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    if (![bundleID isKindOfClass:[NSString class]] || bundleID.length == 0) return NO;
    NSString *processName = NSProcessInfo.processInfo.processName;
    return PXProcessIsAllowedForSpoofing(bundleID,
                                         processName,
                                         PXScopeOptionAllowSafariAuthStack);
}

static id PXMCOriginalValue(PXMCObjectGetter original) {
    return original ? original() : nil;
}

static id PXMCProjectedValue(NSString *symbolName, PXMCObjectGetter original) {
    if (gInsideManagedConfigurationIdentityHook) {
        return PXMCOriginalValue(original);
    }

    gInsideManagedConfigurationIdentityHook = YES;
    id result = nil;
    @try {
        if (!PXMCProcessScopeAllowsProjection()) {
            result = PXMCOriginalValue(original);
        } else {
            PXIdentitySnapshot *snapshot = PXCurrentIdentitySnapshot();
            if (!snapshot.valid) {
                result = PXMCOriginalValue(original);
            } else {
                PXIdentitySurfaceEntry *entry =
                    PXIdentitySurfaceEntryForKey(symbolName,
                                                 PXIdentitySurfaceManagedConfiguration);
                IdentifierManager *manager = [IdentifierManager sharedManager];
                BOOL enabled = entry && manager && [manager isIdentifierEnabled:entry.toggle];
                if (!enabled) {
                    result = PXMCOriginalValue(original);
                } else {
                    // Obtain original lazily only for fallback.  This matches iFake's
                    // observable contract: a valid profile replacement does not need
                    // the private getter to execute first.
                    id projected = PXManagedConfigurationResolveValue(symbolName,
                                                                      nil,
                                                                      snapshot.deviceIDs,
                                                                      YES,
                                                                      YES);
                    result = projected ?: PXMCOriginalValue(original);
                }
            }
        }
    } @catch (__unused NSException *exception) {
        result = PXMCOriginalValue(original);
    } @finally {
        gInsideManagedConfigurationIdentityHook = NO;
    }
    return result;
}

static id PXHookMCCTIMEI(void) {
    return PXMCProjectedValue(@"MCCTIMEI", gOrigMCCTIMEI);
}

static id PXHookMCIOSerialString(void) {
    return PXMCProjectedValue(@"MCIOSerialString", gOrigMCIOSerialString);
}

static id PXHookMCProductVersion(void) {
    return PXMCProjectedValue(@"MCProductVersion", gOrigMCProductVersion);
}

static id PXHookMCProductBuildVersion(void) {
    return PXMCProjectedValue(@"MCProductBuildVersion", gOrigMCProductBuildVersion);
}

static id PXHookMCGestaltGetProductName(void) {
    return PXMCProjectedValue(@"MCGestaltGetProductName", gOrigMCGestaltGetProductName);
}

static id PXHookMCGestaltGetDeviceUUID(void) {
    return PXMCProjectedValue(@"MCGestaltGetDeviceUUID", gOrigMCGestaltGetDeviceUUID);
}

typedef struct {
    const char *name;
    void *replacement;
    PXMCObjectGetter *original;
} PXMCHookSpec;

static void PXInstallManagedConfigurationIdentityHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        const char *frameworkPath =
            "/System/Library/PrivateFrameworks/ManagedConfiguration.framework/ManagedConfiguration";
        void *handle = dlopen(frameworkPath, RTLD_LAZY | RTLD_LOCAL);
        if (!handle) {
            // Some OS builds publish selected MC symbols globally.  Missing symbols
            // remain a safe no-op; never expand injection scope to chase them.
            handle = RTLD_DEFAULT;
        }

        PXMCHookSpec specs[] = {
            { "MCCTIMEI", (void *)PXHookMCCTIMEI, &gOrigMCCTIMEI },
            { "MCIOSerialString", (void *)PXHookMCIOSerialString, &gOrigMCIOSerialString },
            { "MCProductVersion", (void *)PXHookMCProductVersion, &gOrigMCProductVersion },
            { "MCProductBuildVersion", (void *)PXHookMCProductBuildVersion, &gOrigMCProductBuildVersion },
            { "MCGestaltGetProductName", (void *)PXHookMCGestaltGetProductName, &gOrigMCGestaltGetProductName },
            { "MCGestaltGetDeviceUUID", (void *)PXHookMCGestaltGetDeviceUUID, &gOrigMCGestaltGetDeviceUUID },
        };

        for (NSUInteger index = 0; index < sizeof(specs) / sizeof(specs[0]); index++) {
            void *symbol = dlsym(handle, specs[index].name);
            if (!symbol && handle != RTLD_DEFAULT) symbol = dlsym(RTLD_DEFAULT, specs[index].name);
            if (!symbol) {
                PXLog(@"[ManagedConfigurationIdentity] capability absent: %s", specs[index].name);
                continue;
            }
            MSHookFunction(symbol, specs[index].replacement, (void **)specs[index].original);
            PXLog(@"[ManagedConfigurationIdentity] installed %s", specs[index].name);
        }

        // Keep the image resident for the lifetime of the installed trampolines.
        // Dropping the only dlopen reference here can unload ManagedConfiguration
        // on processes that did not already link it, invalidating both the patched
        // entry point and the saved original function pointer.
    });
}

%ctor {
    @autoreleasepool {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        NSString *processName = NSProcessInfo.processInfo.processName;
        if (!bundleID.length ||
            !PXProcessIsAllowedForSpoofing(bundleID,
                                           processName,
                                           PXScopeOptionAllowSafariAuthStack)) {
            return;
        }
        PXIdentitySnapshotStartObserving();
        PXInstallManagedConfigurationIdentityHooks();
    }
}
