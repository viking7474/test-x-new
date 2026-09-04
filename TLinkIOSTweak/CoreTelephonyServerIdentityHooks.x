#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <substrate.h>
#import <dlfcn.h>

#import "IdentifierManager.h"
#import "PXScope.h"
#import "PXIdentitySnapshot.h"
#import "PXIdentitySurfaceRegistry.h"
#import "PXCoreTelephonyServerIdentity.h"
#import "TLinkIOSLogging.h"

// iFake's B7948/B8094 replacements take X0/X1 plus an out-dictionary pointer
// in X2 and return the original status in X0. Keep the first two arguments
// opaque because their private CoreTelephony types are not needed by the overlay.
typedef int64_t (*PXCTServerCopyInfoFunction)(void *arg1,
                                               void *arg2,
                                               CFMutableDictionaryRef *outInformation);

static PXCTServerCopyInfoFunction gOrigCTServerCopyInfo = NULL;
static PXCTServerCopyInfoFunction gOrigCTServerCopyInfoV2 = NULL;
static NSDictionary<NSString *, id> *gCTServerResolvedRuntimeKeys = nil;
static __thread BOOL gInsideCTServerIdentityHook = NO;

static BOOL PXCTServerProcessScopeAllowsProjection(void) {
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    if (![bundleID isKindOfClass:[NSString class]] || bundleID.length == 0) return NO;
    NSString *processName = NSProcessInfo.processInfo.processName;
    return PXProcessIsAllowedForSpoofing(bundleID,
                                         processName,
                                         PXScopeOptionAllowSafariAuthStack);
}

static id PXCTServerResolveExportedStringConstant(void *handle, NSString *symbolName) {
    if (![symbolName isKindOfClass:[NSString class]] || symbolName.length == 0) return nil;
    const char *name = symbolName.UTF8String;
    if (!name) return nil;

    void *address = handle ? dlsym(handle, name) : NULL;
    if (!address) address = dlsym(RTLD_DEFAULT, name);
    if (!address) return nil;

    // dlsym() returns the address of exported data symbols. CoreTelephony's
    // dictionary-key constants are CFStringRef globals, so one dereference yields
    // the key object. If an OS does not export the constant, we simply skip it.
    CFTypeRef value = *(CFTypeRef *)address;
    if (!value || CFGetTypeID(value) != CFStringGetTypeID()) return nil;
    return (__bridge id)value;
}

static NSDictionary<NSString *, id> *PXCTServerRuntimeKeysForInformation(NSDictionary *information) {
    NSMutableDictionary<NSString *, id> *keys =
        [gCTServerResolvedRuntimeKeys mutableCopy] ?: [NSMutableDictionary dictionary];

    // Some builds may not export the key globals even though the dictionary uses
    // their literal names. Only accept that exact literal when it is already a key
    // in the original dictionary; never guess IMEI/IMSI/MEID aliases.
    for (NSString *surfaceKey in PXCoreTelephonyServerSurfaceKeys()) {
        if (keys[surfaceKey]) continue;
        if ([information objectForKey:surfaceKey] != nil) keys[surfaceKey] = surfaceKey;
    }
    return keys;
}

static NSSet<NSString *> *PXCTServerEnabledToggles(IdentifierManager *manager) {
    if (!manager) return [NSSet set];
    NSMutableSet<NSString *> *enabled = [NSMutableSet set];
    for (NSString *surfaceKey in PXCoreTelephonyServerSurfaceKeys()) {
        PXIdentitySurfaceEntry *entry =
            PXIdentitySurfaceEntryForKey(surfaceKey,
                                         PXIdentitySurfaceCoreTelephonyServer);
        if (entry.toggle.length && [manager isIdentifierEnabled:entry.toggle]) {
            [enabled addObject:entry.toggle];
        }
    }
    return enabled;
}

static int64_t PXCTServerCopyInfoProjected(PXCTServerCopyInfoFunction original,
                                           void *arg1,
                                           void *arg2,
                                           CFMutableDictionaryRef *outInformation) {
    // Original-first is part of the observed iFake contract and preserves both
    // status semantics and the caller-owned out-parameter lifetime.
    int64_t status = original ? original(arg1, arg2, outInformation) : 0;
    if (!original || gInsideCTServerIdentityHook || !outInformation || !*outInformation) {
        return status;
    }

    gInsideCTServerIdentityHook = YES;
    @try {
        if (!PXCTServerProcessScopeAllowsProjection()) return status;

        id information = (__bridge id)*outInformation;
        if (![information isKindOfClass:[NSMutableDictionary class]]) return status;

        PXIdentitySnapshot *snapshot = PXCurrentIdentitySnapshot();
        if (!snapshot.valid) return status;

        IdentifierManager *manager = [IdentifierManager sharedManager];
        NSSet<NSString *> *enabled = PXCTServerEnabledToggles(manager);
        if (enabled.count == 0) return status;

        NSDictionary<NSString *, id> *runtimeKeys =
            PXCTServerRuntimeKeysForInformation((NSDictionary *)information);
        PXCoreTelephonyServerApplyIdentityOverlay((NSMutableDictionary *)information,
                                                  runtimeKeys,
                                                  snapshot.deviceIDs,
                                                  enabled);
    } @catch (__unused NSException *exception) {
        // Fail open. The original status and out dictionary remain authoritative.
    } @finally {
        gInsideCTServerIdentityHook = NO;
    }
    return status;
}

static int64_t PXHookCTServerCopyMobileEquipmentInfo(void *arg1,
                                                      void *arg2,
                                                      CFMutableDictionaryRef *outInformation) {
    return PXCTServerCopyInfoProjected(gOrigCTServerCopyInfo, arg1, arg2, outInformation);
}

static int64_t PXHookCTServerCopyMobileEquipmentInfoV2(void *arg1,
                                                        void *arg2,
                                                        CFMutableDictionaryRef *outInformation) {
    return PXCTServerCopyInfoProjected(gOrigCTServerCopyInfoV2, arg1, arg2, outInformation);
}

typedef struct {
    const char *name;
    void *replacement;
    PXCTServerCopyInfoFunction *original;
} PXCTServerHookSpec;

static void PXInstallCoreTelephonyServerIdentityHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        const char *frameworkPath =
            "/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony";
        void *handle = dlopen(frameworkPath, RTLD_LAZY | RTLD_LOCAL);
        if (!handle) handle = RTLD_DEFAULT;

        NSMutableDictionary<NSString *, id> *resolvedKeys = [NSMutableDictionary dictionary];
        for (NSString *surfaceKey in PXCoreTelephonyServerSurfaceKeys()) {
            id keyObject = PXCTServerResolveExportedStringConstant(handle, surfaceKey);
            if (keyObject) resolvedKeys[surfaceKey] = keyObject;
        }
        gCTServerResolvedRuntimeKeys = [resolvedKeys copy];

        PXCTServerHookSpec specs[] = {
            { "_CTServerConnectionCopyMobileEquipmentInfo",
              (void *)PXHookCTServerCopyMobileEquipmentInfo,
              &gOrigCTServerCopyInfo },
            { "_CTServerConnectionCopyMobileEquipmentInfoV2",
              (void *)PXHookCTServerCopyMobileEquipmentInfoV2,
              &gOrigCTServerCopyInfoV2 },
        };

        for (NSUInteger index = 0; index < sizeof(specs) / sizeof(specs[0]); index++) {
            void *symbol = dlsym(handle, specs[index].name);
            if (!symbol && handle != RTLD_DEFAULT) symbol = dlsym(RTLD_DEFAULT, specs[index].name);
            if (!symbol) {
                PXLog(@"[CoreTelephonyServerIdentity] capability absent: %s", specs[index].name);
                continue;
            }
            MSHookFunction(symbol, specs[index].replacement, (void **)specs[index].original);
            PXLog(@"[CoreTelephonyServerIdentity] installed %s original=%p",
                  specs[index].name,
                  *(void **)specs[index].original);
        }
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
        PXInstallCoreTelephonyServerIdentityHooks();
    }
}
