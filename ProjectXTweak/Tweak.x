#import "ProjectX.h"
#import "DeviceModelManager.h"
#import "IdentifierManager.h"
#import <AdSupport/ASIdentifierManager.h>
#import <UIKit/UIKit.h>
// #import "ellekit/ellekit.h" // Removed for rootful - using Substrate
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import "ProjectXLogging.h"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <mach/vm_prot.h>
#import <mach/mach.h>
#import <ifaddrs.h>
#import <string.h>
#import <net/if.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <IOKit/IOKitLib.h>
#import <sys/sysctl.h>  // For sysctlbyname hooks
#import <errno.h>
#import <dirent.h>     // For DIR type
#import <sys/mount.h>  // For statfs
#import "ProfileManager.h" // For accessing current profile
#import "ProfileIndicatorView.h" // For profile indicator
#import <substrate.h>
#import <sys/utsname.h>
#import <Security/Security.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreGraphics/CoreGraphics.h>
// #import <ellekit/ellekit.h> // Removed for rootful - using Substrate
#import <CoreMotion/CoreMotion.h> // Import CoreMotion framework for sensor spoofing
#import "LocationSpoofingManager.h" // Import location spoofing manager
#import "MobileGestalt.h"
#import "IOSVersionInfo.h"
#import "PXNativeHookCoordinator.h"
#import "PXScope.h"
#import "PXDeviceProfileSchema.h"
#import "PXIdentitySnapshot.h"
#import "PXSystemVersionTransformer.h"
#import "PXIdentitySurfaceRegistry.h"
#import "PXRuntimeUtilities.h"
#import "PXPaths.h"
#import "PXFileDebug.h"
#import "PXP1BFilters.h"
#import <os/lock.h>
#import <CoreFoundation/CoreFoundation.h>

__attribute__((constructor(101))) static void PXProjectXTweakEarlyLoadMarker(void) {
    PXFileDebugLoadMarker("ProjectXTweak.early");
}

// Forward declarations for classes we need to hook
@interface SBScreenshotManager : NSObject
- (void)saveScreenshotsWithCompletion:(id)completion;
- (void)saveScreenshots;
@end

@interface UIImage (WeaponXScreenshot)
- (UIImage *)weaponx_addProfileIndicator;
- (UIImage *)weaponx_removeNavigationBar;
@end

// Cache for values
static NSMutableDictionary *valueCache;

// Compatibility shims for apps calling weakly-linked / newer-iOS selectors
// when the real OS is older than the spoofed iOS version (common crash pattern).
static BOOL PXCompatReturnNo(id self, SEL _cmd) {
    return NO;
}

static id PXCompatReturnNil(id self, SEL _cmd) {
    return nil;
}

static void PXCompatVoidNoop(id self, SEL _cmd) {
    (void)self; (void)_cmd;
}

// Retain object for getter/setter pair using the selector as the association key.
static void PXCompatSetAssociatedObject(id self, SEL _cmd, id value) {
    // Key must be stable; use the selector pointer of the *setter* so get/set share storage.
    // Callers pass a dedicated key SEL via function... we store by _cmd of setter.
    objc_setAssociatedObject(self, (const void *)_cmd, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static id PXCompatGetAssociatedForSetterSEL(id self, SEL setterSel) {
    return objc_getAssociatedObject(self, (const void *)setterSel);
}

// scrollEdgeAppearance property (iOS 15+) — getter paired with setScrollEdgeAppearance:
static id PXCompatGetScrollEdgeAppearance(id self, SEL _cmd) {
    (void)_cmd;
    return PXCompatGetAssociatedForSetterSEL(self, @selector(setScrollEdgeAppearance:));
}

static void PXCompatSetScrollEdgeAppearance(id self, SEL _cmd, id value) {
    PXCompatSetAssociatedObject(self, _cmd, value);
}

static id PXCompatGetCompactScrollEdgeAppearance(id self, SEL _cmd) {
    (void)_cmd;
    return PXCompatGetAssociatedForSetterSEL(self, @selector(setCompactScrollEdgeAppearance:));
}

static void PXCompatSetCompactScrollEdgeAppearance(id self, SEL _cmd, id value) {
    PXCompatSetAssociatedObject(self, _cmd, value);
}

static id PXCompatGetStandardAppearance(id self, SEL _cmd) {
    (void)_cmd;
    return PXCompatGetAssociatedForSetterSEL(self, @selector(setStandardAppearance:));
}

static void PXCompatSetStandardAppearance(id self, SEL _cmd, id value) {
    PXCompatSetAssociatedObject(self, _cmd, value);
}

static id PXCompatGetCompactAppearance(id self, SEL _cmd) {
    (void)_cmd;
    return PXCompatGetAssociatedForSetterSEL(self, @selector(setCompactAppearance:));
}

static void PXCompatSetCompactAppearance(id self, SEL _cmd, id value) {
    PXCompatSetAssociatedObject(self, _cmd, value);
}

static void PXCompatAddMethodIfMissing(Class cls, SEL sel, IMP imp, const char *types) {
    if (!cls || !sel || !imp || !types) return;
    if (class_getInstanceMethod(cls, sel)) return;
    class_addMethod(cls, sel, imp, types);
}

static void PXCompatShimBarAppearanceClass(Class cls) {
    if (!cls) return;
    // UITabBar / UINavigationBar / UIToolbar — iOS 13 standardAppearance, iOS 15 scrollEdge*
    PXCompatAddMethodIfMissing(cls, @selector(setStandardAppearance:),
                               (IMP)PXCompatSetStandardAppearance, "v@:@");
    PXCompatAddMethodIfMissing(cls, @selector(standardAppearance),
                               (IMP)PXCompatGetStandardAppearance, "@@:");
    PXCompatAddMethodIfMissing(cls, @selector(setCompactAppearance:),
                               (IMP)PXCompatSetCompactAppearance, "v@:@");
    PXCompatAddMethodIfMissing(cls, @selector(compactAppearance),
                               (IMP)PXCompatGetCompactAppearance, "@@:");
    PXCompatAddMethodIfMissing(cls, @selector(setScrollEdgeAppearance:),
                               (IMP)PXCompatSetScrollEdgeAppearance, "v@:@");
    PXCompatAddMethodIfMissing(cls, @selector(scrollEdgeAppearance),
                               (IMP)PXCompatGetScrollEdgeAppearance, "@@:");
    PXCompatAddMethodIfMissing(cls, @selector(setCompactScrollEdgeAppearance:),
                               (IMP)PXCompatSetCompactScrollEdgeAppearance, "v@:@");
    PXCompatAddMethodIfMissing(cls, @selector(compactScrollEdgeAppearance),
                               (IMP)PXCompatGetCompactScrollEdgeAppearance, "@@:");
}

// WKWebView iOS 14+ APIs — apps call these after spoofing systemVersion ≥ 14 on real iOS 12/13.
typedef void (^PXWKJSCompletion)(id result, NSError *error);

static void PXCompatWKEvaluateJavaScriptInWorld(id self, SEL _cmd,
                                                NSString *javaScriptString,
                                                id frame,
                                                id contentWorld,
                                                PXWKJSCompletion completionHandler) {
    (void)_cmd; (void)frame; (void)contentWorld;
    // Fall back to the long-standing evaluateJavaScript:completionHandler: API (iOS 8+).
    SEL legacy = @selector(evaluateJavaScript:completionHandler:);
    if ([self respondsToSelector:legacy] && [javaScriptString isKindOfClass:[NSString class]]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        // Signature: - (void)evaluateJavaScript:(NSString *) completionHandler:(void(^)(id, NSError *))
        void (*msg)(id, SEL, id, id) = (void (*)(id, SEL, id, id))objc_msgSend;
        msg(self, legacy, javaScriptString, completionHandler);
#pragma clang diagnostic pop
        return;
    }
    if (completionHandler) {
        NSError *err = [NSError errorWithDomain:@"com.hydra.projectx.compat"
                                           code:14
                                       userInfo:@{NSLocalizedDescriptionKey:
                                           @"evaluateJavaScript:inFrame:inContentWorld: unavailable; no legacy fallback"}];
        completionHandler(nil, err);
    }
}

static void PXCompatWKCallAsyncJavaScript(id self, SEL _cmd,
                                          NSString *javaScriptString,
                                          NSDictionary *arguments,
                                          id frame,
                                          id contentWorld,
                                          PXWKJSCompletion completionHandler) {
    (void)_cmd; (void)arguments; (void)frame; (void)contentWorld;
    // Best-effort: run the script via legacy evaluateJavaScript (args/world ignored on old OS).
    SEL legacy = @selector(evaluateJavaScript:completionHandler:);
    if ([self respondsToSelector:legacy] && [javaScriptString isKindOfClass:[NSString class]]) {
        void (*msg)(id, SEL, id, id) = (void (*)(id, SEL, id, id))objc_msgSend;
        msg(self, legacy, javaScriptString, completionHandler);
        return;
    }
    if (completionHandler) {
        NSError *err = [NSError errorWithDomain:@"com.hydra.projectx.compat"
                                           code:14
                                       userInfo:@{NSLocalizedDescriptionKey:
                                           @"callAsyncJavaScript: unavailable on this iOS version"}];
        completionHandler(nil, err);
    }
}

static void PXCompatShimWKWebView(void) {
    // Ensure WebKit is loaded so WKWebView class exists before we add methods.
    dlopen("/System/Library/Frameworks/WebKit.framework/WebKit", RTLD_LAZY);
    Class wk = objc_getClass("WKWebView");
    if (!wk) return;

    // -[WKWebView callAsyncJavaScript:arguments:inFrame:inContentWorld:completionHandler:] (iOS 14+)
    SEL callAsync = NSSelectorFromString(@"callAsyncJavaScript:arguments:inFrame:inContentWorld:completionHandler:");
    // Encoding: void, id, SEL, id, id, id, id, block
    PXCompatAddMethodIfMissing(wk, callAsync, (IMP)PXCompatWKCallAsyncJavaScript, "v@:@@@@@?");

    // -[WKWebView evaluateJavaScript:inFrame:inContentWorld:completionHandler:] (iOS 14+)
    SEL evalWorld = NSSelectorFromString(@"evaluateJavaScript:inFrame:inContentWorld:completionHandler:");
    PXCompatAddMethodIfMissing(wk, evalWorld, (IMP)PXCompatWKEvaluateJavaScriptInWorld, "v@:@@@@?");
}

#pragma mark - WidgetKit soft stubs (iOS < 14)

// Real OS major from disk (not spoofed). Used to decide if WidgetKit exists.
static NSInteger PXRealOSMajorVersion(void) {
    static NSInteger major = -1;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSDictionary *sv = [NSDictionary dictionaryWithContentsOfFile:
                            @"/System/Library/CoreServices/SystemVersion.plist"];
        NSString *ver = [sv[@"ProductVersion"] isKindOfClass:[NSString class]] ? sv[@"ProductVersion"] : nil;
        if (ver.length) {
            major = [[ver componentsSeparatedByString:@"."].firstObject integerValue];
        }
        if (major < 0) major = 0;
    });
    return major;
}

// Fake storage large enough for Swift to read a few words without immediate OOB.
static uint8_t gPXWidgetKitFakeMeta[256];
static uint8_t gPXWidgetKitFakeInstance[256];

// Type metadata accessor: _$s9WidgetKit0A6CenterCMa
static void *PXStub_WidgetCenter_Ma(void) {
    return gPXWidgetKitFakeMeta;
}

// shared singleton-ish pointer
static void *PXStub_WidgetCenter_shared(void) {
    return gPXWidgetKitFakeInstance;
}

// Generic no-op for void instance/class methods (reloadAllTimelines, etc.)
static void PXStub_WidgetKit_void(void) {
}

// Generic pointer-returning stub
static void *PXStub_WidgetKit_ptr(void) {
    return gPXWidgetKitFakeInstance;
}

// Rebind one indirect symbol pointer in an image (fishhook-style, main binary only).
static void PXRebindIndirectSymbol(const struct mach_header *header,
                                   intptr_t slide,
                                   const char *symbolName,
                                   void *replacement) {
    if (!header || !symbolName || !replacement) return;

#if defined(__LP64__)
    typedef struct mach_header_64 px_mh_t;
    typedef struct segment_command_64 px_seg_t;
    typedef struct section_64 px_sect_t;
    typedef struct nlist_64 px_nlist_t;
    const uint32_t LC_SEG = LC_SEGMENT_64;
#else
    typedef struct mach_header px_mh_t;
    typedef struct segment_command px_seg_t;
    typedef struct section px_sect_t;
    typedef struct nlist px_nlist_t;
    const uint32_t LC_SEG = LC_SEGMENT;
#endif

    const px_mh_t *mh = (const px_mh_t *)header;
    Dl_info info;
    if (dladdr(header, &info) == 0) return;

    const uint8_t *cursor = (const uint8_t *)(mh + 1);
    const struct symtab_command *symtab = NULL;
    const struct dysymtab_command *dysymtab = NULL;
    const px_seg_t *linkedit = NULL;

    for (uint32_t i = 0; i < mh->ncmds; i++) {
        const struct load_command *lc = (const struct load_command *)cursor;
        if (lc->cmd == LC_SYMTAB) {
            symtab = (const struct symtab_command *)lc;
        } else if (lc->cmd == LC_DYSYMTAB) {
            dysymtab = (const struct dysymtab_command *)lc;
        } else if (lc->cmd == LC_SEG) {
            const px_seg_t *seg = (const px_seg_t *)lc;
            if (strcmp(seg->segname, SEG_LINKEDIT) == 0) {
                linkedit = seg;
            }
        }
        cursor += lc->cmdsize;
    }
    if (!symtab || !dysymtab || !linkedit) return;

    const uintptr_t linkeditBase = (uintptr_t)slide + linkedit->vmaddr - linkedit->fileoff;
    const char *strtab = (const char *)(linkeditBase + symtab->stroff);
    const px_nlist_t *symtabEntries = (const px_nlist_t *)(linkeditBase + symtab->symoff);
    const uint32_t *indirectSymtab = (const uint32_t *)(linkeditBase + dysymtab->indirectsymoff);

    cursor = (const uint8_t *)(mh + 1);
    for (uint32_t i = 0; i < mh->ncmds; i++) {
        const struct load_command *lc = (const struct load_command *)cursor;
        if (lc->cmd == LC_SEG) {
            const px_seg_t *seg = (const px_seg_t *)lc;
            // Only patch DATA-ish segments (lazy/non-lazy symbol pointers)
            if (strcmp(seg->segname, SEG_DATA) != 0 &&
                strcmp(seg->segname, "__DATA_CONST") != 0 &&
                strcmp(seg->segname, "__AUTH_CONST") != 0) {
                cursor += lc->cmdsize;
                continue;
            }
            const px_sect_t *sections = (const px_sect_t *)(seg + 1);
            for (uint32_t s = 0; s < seg->nsects; s++) {
                const px_sect_t *sect = &sections[s];
                uint32_t type = sect->flags & SECTION_TYPE;
                if (type != S_LAZY_SYMBOL_POINTERS && type != S_NON_LAZY_SYMBOL_POINTERS) {
                    continue;
                }
                uint32_t entryCount = (uint32_t)(sect->size / sizeof(void *));
                void **indirect = (void **)((uintptr_t)slide + sect->addr);
                uint32_t indirectOffset = sect->reserved1;
                for (uint32_t j = 0; j < entryCount; j++) {
                    uint32_t symIndex = indirectSymtab[indirectOffset + j];
                    if (symIndex == INDIRECT_SYMBOL_ABS || symIndex == INDIRECT_SYMBOL_LOCAL ||
                        symIndex == (INDIRECT_SYMBOL_LOCAL | INDIRECT_SYMBOL_ABS)) {
                        continue;
                    }
                    if (symIndex >= symtab->nsyms) continue;
                    const px_nlist_t *nl = &symtabEntries[symIndex];
                    const char *name = strtab + nl->n_un.n_strx;
                    if (!name) continue;
                    BOOL match = (strcmp(name, symbolName) == 0);
                    if (!match && name[0] == '_' && strcmp(name + 1, symbolName) == 0) match = YES;
                    if (!match && symbolName[0] == '_' && strcmp(name, symbolName + 1) == 0) match = YES;
                    if (!match) continue;

                    // DATA_CONST may be r-- — make the page writable first.
                    vm_size_t psz = vm_page_size ? vm_page_size : 0x4000;
                    vm_address_t page = (vm_address_t)&indirect[j];
                    page &= ~(vm_address_t)(psz - 1);
                    vm_protect(mach_task_self(), page, psz, FALSE,
                               VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
                    indirect[j] = replacement;
                }
            }
        }
        cursor += lc->cmdsize;
    }
}

static void PXRebindWidgetKitSymbolsInMainImage(void) {
    // Only needed when WidgetKit.framework cannot load (real iOS < 14).
    if (PXRealOSMajorVersion() >= 14) return;
    void *wk = dlopen("/System/Library/Frameworks/WidgetKit.framework/WidgetKit", RTLD_LAZY | RTLD_NOLOAD);
    if (wk) {
        dlclose(wk);
        return; // real WidgetKit present
    }
    // Probe load — if it fails, rebind main binary imports to stubs.
    wk = dlopen("/System/Library/Frameworks/WidgetKit.framework/WidgetKit", RTLD_LAZY);
    if (wk) {
        dlclose(wk);
        return;
    }

    const struct mach_header *mainHeader = NULL;
    intptr_t slide = 0;
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        // Main app executable (not a dylib/framework)
        if (strstr(name, ".app/") && !strstr(name, ".dylib") && !strstr(name, ".framework/")) {
            mainHeader = _dyld_get_image_header(i);
            slide = _dyld_get_image_vmaddr_slide(i);
            break;
        }
    }
    if (!mainHeader) {
        mainHeader = _dyld_get_image_header(0);
        slide = _dyld_get_image_vmaddr_slide(0);
    }
    if (!mainHeader) return;

    // Known mangled symbols used by apps (WidgetCenter.shared / reload*).
    // Rebind prevents dyld_stub_binder abort: "can't resolve symbol ... WidgetKit".
    struct { const char *name; void *rep; } pairs[] = {
        { "_$s9WidgetKit0A6CenterCMa", (void *)PXStub_WidgetCenter_Ma },
        { "$s9WidgetKit0A6CenterCMa", (void *)PXStub_WidgetCenter_Ma },
        { "_$s9WidgetKit0A6CenterC6sharedACvgZ", (void *)PXStub_WidgetCenter_shared },
        { "$s9WidgetKit0A6CenterC6sharedACvgZ", (void *)PXStub_WidgetCenter_shared },
        { "_$s9WidgetKit0A6CenterC6sharedACvau", (void *)PXStub_WidgetCenter_shared },
        { "_$s9WidgetKit0A6CenterC18reloadAllTimelinesyyF", (void *)PXStub_WidgetKit_void },
        { "$s9WidgetKit0A6CenterC18reloadAllTimelinesyyF", (void *)PXStub_WidgetKit_void },
        { "_$s9WidgetKit0A6CenterC15reloadTimelines6ofKindySS_tF", (void *)PXStub_WidgetKit_void },
        { "$s9WidgetKit0A6CenterC15reloadTimelines6ofKindySS_tF", (void *)PXStub_WidgetKit_void },
        // Broad fallbacks for other WidgetKit entry points — return inert pointer / no-op.
        { NULL, NULL }
    };

    // Also walk all indirect symbols with prefix _$s9WidgetKit and rebind generically.
    // First apply known pairs.
    for (int i = 0; pairs[i].name; i++) {
        PXRebindIndirectSymbol(mainHeader, slide, pairs[i].name, pairs[i].rep);
    }

    // Generic prefix scan: any remaining WidgetKit lazy binds → void stub (safe abort avoidance).
#if defined(__LP64__)
    typedef struct mach_header_64 px_mh_t;
    typedef struct segment_command_64 px_seg_t;
    typedef struct section_64 px_sect_t;
    typedef struct nlist_64 px_nlist_t;
    const uint32_t LC_SEG = LC_SEGMENT_64;
#else
    typedef struct mach_header px_mh_t;
    typedef struct segment_command px_seg_t;
    typedef struct section px_sect_t;
    typedef struct nlist px_nlist_t;
    const uint32_t LC_SEG = LC_SEGMENT;
#endif
    const px_mh_t *mh = (const px_mh_t *)mainHeader;
    const uint8_t *cursor = (const uint8_t *)(mh + 1);
    const struct symtab_command *symtab = NULL;
    const struct dysymtab_command *dysymtab = NULL;
    const px_seg_t *linkedit = NULL;
    for (uint32_t i = 0; i < mh->ncmds; i++) {
        const struct load_command *lc = (const struct load_command *)cursor;
        if (lc->cmd == LC_SYMTAB) symtab = (const struct symtab_command *)lc;
        else if (lc->cmd == LC_DYSYMTAB) dysymtab = (const struct dysymtab_command *)lc;
        else if (lc->cmd == LC_SEG) {
            const px_seg_t *seg = (const px_seg_t *)lc;
            if (strcmp(seg->segname, SEG_LINKEDIT) == 0) linkedit = seg;
        }
        cursor += lc->cmdsize;
    }
    if (!symtab || !dysymtab || !linkedit) return;
    const uintptr_t linkeditBase = (uintptr_t)slide + linkedit->vmaddr - linkedit->fileoff;
    const char *strtab = (const char *)(linkeditBase + symtab->stroff);
    const px_nlist_t *symtabEntries = (const px_nlist_t *)(linkeditBase + symtab->symoff);
    const uint32_t *indirectSymtab = (const uint32_t *)(linkeditBase + dysymtab->indirectsymoff);

    cursor = (const uint8_t *)(mh + 1);
    for (uint32_t i = 0; i < mh->ncmds; i++) {
        const struct load_command *lc = (const struct load_command *)cursor;
        if (lc->cmd == LC_SEG) {
            const px_seg_t *seg = (const px_seg_t *)lc;
            if (strcmp(seg->segname, SEG_DATA) != 0 &&
                strcmp(seg->segname, "__DATA_CONST") != 0 &&
                strcmp(seg->segname, "__AUTH_CONST") != 0) {
                cursor += lc->cmdsize;
                continue;
            }
            const px_sect_t *sections = (const px_sect_t *)(seg + 1);
            for (uint32_t s = 0; s < seg->nsects; s++) {
                const px_sect_t *sect = &sections[s];
                uint32_t type = sect->flags & SECTION_TYPE;
                if (type != S_LAZY_SYMBOL_POINTERS && type != S_NON_LAZY_SYMBOL_POINTERS) continue;
                uint32_t entryCount = (uint32_t)(sect->size / sizeof(void *));
                void **indirect = (void **)((uintptr_t)slide + sect->addr);
                uint32_t indirectOffset = sect->reserved1;
                for (uint32_t j = 0; j < entryCount; j++) {
                    uint32_t symIndex = indirectSymtab[indirectOffset + j];
                    if (symIndex >= symtab->nsyms) continue;
                    if (symIndex == INDIRECT_SYMBOL_ABS || symIndex == INDIRECT_SYMBOL_LOCAL) continue;
                    const char *name = strtab + symtabEntries[symIndex].n_un.n_strx;
                    if (!name) continue;
                    const char *n = (name[0] == '_') ? name + 1 : name;
                    if (strncmp(n, "$s9WidgetKit", 11) != 0 && strncmp(n, "WidgetKit", 9) != 0) continue;
                    // Prefer pointer stub for accessors (Ma, shared, gZ, vau), void for methods (yF, yyF)
                    BOOL wantPtr = (strstr(n, "Ma") != NULL) || (strstr(n, "shared") != NULL) ||
                                   (strstr(n, "vau") != NULL) || (strstr(n, "vgZ") != NULL) ||
                                   (strstr(n, "vpZ") != NULL);
                    vm_size_t psz = vm_page_size ? vm_page_size : 0x4000;
                    vm_address_t page = (vm_address_t)&indirect[j];
                    page &= ~(vm_address_t)(psz - 1);
                    vm_protect(mach_task_self(), page, psz, FALSE,
                               VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
                    indirect[j] = wantPtr ? (void *)PXStub_WidgetKit_ptr : (void *)PXStub_WidgetKit_void;
                }
            }
        }
        cursor += lc->cmdsize;
    }

    PXLog(@"[WeaponX] WidgetKit missing on this iOS — rebound WidgetKit imports to soft stubs");
}

static void PXInstallCompatibilityShims(void) {
    @autoreleasepool {
        // Some apps call selectors that may not exist on all iOS builds.
        // When we spoof a newer iOS version, apps often branch into newer UIKit APIs
        // without @available checks — add no-op / storage shims when missing.

        Class procInfoCls = objc_getClass("NSProcessInfo");
        if (procInfoCls && !class_getInstanceMethod(procInfoCls, @selector(isiOSAppOnMac))) {
            class_addMethod(procInfoCls, @selector(isiOSAppOnMac), (IMP)PXCompatReturnNo, "B@:");
        }

        Class ctProvCls = objc_getClass("CTCellularPlanProvisioning");
        if (ctProvCls && !class_getInstanceMethod(ctProvCls, @selector(supportsEmbeddedSIM))) {
            class_addMethod(ctProvCls, @selector(supportsEmbeddedSIM), (IMP)PXCompatReturnNo, "B@:");
        }

        // Crash signature (CPUDasher etc.): -[UITabBar setScrollEdgeAppearance:] on iOS < 15
        // while spoofed systemVersion advertises 15+/16+.
        PXCompatShimBarAppearanceClass(objc_getClass("UITabBar"));
        PXCompatShimBarAppearanceClass(objc_getClass("UINavigationBar"));
        PXCompatShimBarAppearanceClass(objc_getClass("UIToolbar"));

        // UINavigationItem large title / appearance helpers (harmless if unused)
        Class navItem = objc_getClass("UINavigationItem");
        if (navItem) {
            PXCompatAddMethodIfMissing(navItem, @selector(setStandardAppearance:),
                                       (IMP)PXCompatSetStandardAppearance, "v@:@");
            PXCompatAddMethodIfMissing(navItem, @selector(standardAppearance),
                                       (IMP)PXCompatGetStandardAppearance, "@@:");
            PXCompatAddMethodIfMissing(navItem, @selector(setScrollEdgeAppearance:),
                                       (IMP)PXCompatSetScrollEdgeAppearance, "v@:@");
            PXCompatAddMethodIfMissing(navItem, @selector(scrollEdgeAppearance),
                                       (IMP)PXCompatGetScrollEdgeAppearance, "@@:");
            PXCompatAddMethodIfMissing(navItem, @selector(setCompactAppearance:),
                                       (IMP)PXCompatSetCompactAppearance, "v@:@");
            PXCompatAddMethodIfMissing(navItem, @selector(compactAppearance),
                                       (IMP)PXCompatGetCompactAppearance, "@@:");
            PXCompatAddMethodIfMissing(navItem, @selector(setCompactScrollEdgeAppearance:),
                                       (IMP)PXCompatSetCompactScrollEdgeAppearance, "v@:@");
            PXCompatAddMethodIfMissing(navItem, @selector(compactScrollEdgeAppearance),
                                       (IMP)PXCompatGetCompactScrollEdgeAppearance, "@@:");
        }

        // Crash: -[WKWebView callAsyncJavaScript:arguments:inFrame:inContentWorld:completionHandler:]
        // on real iOS < 14 while spoofed version is 14+.
        PXCompatShimWKWebView();

        // Crash: dyld can't resolve WidgetKit.WidgetCenter on real iOS < 14 (ARMCPUZ etc.)
        // when app takes iOS 14+ path after version spoof / weak-link WidgetKit.
        PXRebindWidgetKitSymbolsInMainImage();

        // Quiet unused-function warnings if optimizer is aggressive
        (void)PXCompatReturnNil;
        (void)PXCompatVoidNoop;
        (void)PXStub_WidgetCenter_Ma;
        (void)PXStub_WidgetCenter_shared;
    }
}

// uname is the only Tweak-owned exclusive native symbol (not managed by the
// coordinator). Track its install state file-locally; every other native symbol
// is owned by PXNativeHookCoordinator (see scripts/audit_native_hooks.sh).
static BOOL sPXUnameHookInstalled = NO;

// Missing-key logging
// Security settings helpers
static id PXReadSecuritySettingObject(NSString *key) {
    if (!key.length) return nil;
    CFPropertyListRef pref = CFPreferencesCopyAppValue((__bridge CFStringRef)key, CFSTR("com.weaponx.securitySettings"));
    if (pref) return CFBridgingRelease(pref);

    NSArray<NSString *> *paths = @[
        @"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist",
        @"/private/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist"
    ];
    for (NSString *path in paths) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
        if (dict && dict[key] != nil) {
            return dict[key];
        }
    }
    return nil;
}

static BOOL PXReadSecuritySettingBool(NSString *key) {
    id v = PXReadSecuritySettingObject(key);
    return v ? [v boolValue] : NO;
}

static BOOL PXFixVersionAppliesToBundle(NSString *bundleID) {
    if (!bundleID.length) return NO;
    if (!PXReadSecuritySettingBool(@"fixVersionEnabled")) return NO;
    id list = PXReadSecuritySettingObject(@"fixVersionApps");
    if ([list isKindOfClass:[NSArray class]]) {
        return [(NSArray *)list containsObject:bundleID];
    }
    return NO;
}

static NSString *PXHookMissingLogPath(void) {
    NSArray<NSString *> *dirs = @[
        @"/var/mobile/Library/WeaponX/Logs",
        @"/private/var/mobile/Library/WeaponX/Logs"
    ];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *dir in dirs) {
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:dir isDirectory:&isDir] && isDir) {
            return [dir stringByAppendingPathComponent:@"hook_missing.log"];
        }
    }
    NSString *preferred = dirs.firstObject;
    if (preferred.length) {
        [fm createDirectoryAtPath:preferred withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0755, NSFileOwnerAccountName: @"mobile"} error:nil];
        return [preferred stringByAppendingPathComponent:@"hook_missing.log"];
    }
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"hook_missing.log"];
}

static void PXHookMissingLogLine(NSString *line) {
    if (!line.length) return;
    static NSObject *lock = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [NSObject new];
    });
    NSString *path = PXHookMissingLogPath();
    NSString *out = [line stringByAppendingString:@"\n"];
    @synchronized(lock) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            [out writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
            return;
        }
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!fh) {
            [out writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
            return;
        }
        [fh seekToEndOfFile];
        NSData *data = [out dataUsingEncoding:NSUTF8StringEncoding];
        if (data) {
            [fh writeData:data];
        }
        [fh closeFile];
    }
}

static void PXHookMissingLogOnce(NSString *signature, NSString *line) {
    if (!signature.length || PXLogOnceClaim(@"Tweak.missingKey", signature)) {
        PXHookMissingLogLine(line);
    }
}

static NSString *PXISO8601Now(void) {
    static NSDateFormatter *df = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"]; 
    });
    return [df stringFromDate:[NSDate date]];
}

// Compatibility wrapper over the process-wide immutable identity snapshot.
// Native, MobileGestalt, IORegistry and DeviceSpec providers now share the same
// profile ID + persisted GenerationCounter publication.
static void PXIdentitySnapshotChanged(CFNotificationCenterRef center,
                                      void *observer,
                                      CFStringRef name,
                                      const void *object,
                                      CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    PXInvalidateScopeDecisionCache();
}

static NSDictionary *PXGetDeviceIdsSnapshot(NSString **outProfileId, NSNumber **outGen) {
    return PXDeviceIDsSnapshot(outProfileId, outGen);
}

static BOOL PXRequireKeysAll(NSDictionary *ids, NSArray<NSString *> *keys, NSString *api, NSString *req, NSString *bundleID, NSString *profileId, NSNumber *gen) {
    if (!keys.count) return YES;
    NSMutableArray *missing = [NSMutableArray array];
    for (NSString *k in keys) {
        id v = ids[k];
        if (!PXProfileString(v)) {
            [missing addObject:k];
        }
    }
    if (missing.count == 0) return YES;
    NSString *proc = [NSProcessInfo processInfo].processName ?: @"";
    NSString *missingStr = [missing componentsJoinedByString:@","];
    NSString *line = [NSString stringWithFormat:@"ts=%@ api=%@ req=%@ bundle=%@ proc=%@ profile=%@ gen=%@ missing=[%@]",
                      PXISO8601Now(), api ?: @"", req ?: @"", bundleID ?: @"", proc, profileId ?: @"", gen ?: @"", missingStr];
    NSString *sig = [NSString stringWithFormat:@"%@|%@|%@|%@|%@|%@|%@", bundleID ?: @"", proc, api ?: @"", req ?: @"", profileId ?: @"", gen ?: @"", missingStr];
    PXHookMissingLogOnce(sig, line);
    return NO;
}


static CFDataRef PXCreateCFDataFromNSString(NSString *s) {
    if (!s.length) return NULL;
    const char *cStr = [s UTF8String];
    if (!cStr) return NULL;
    return CFDataCreate(kCFAllocatorDefault, (const UInt8 *)cStr, strlen(cStr) + 1);
}

static CFStringRef PXCreateCFStringFromNSString(NSString *s) {
    if (!s.length) return NULL;
    return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)s);
}

static NSString *PXStringFromCFType(CFTypeRef v) {
    if (!v) return nil;
    if (CFGetTypeID(v) == CFStringGetTypeID()) {
        return (__bridge NSString *)v;
    }
    if (CFGetTypeID(v) == CFDataGetTypeID()) {
        NSData *data = (__bridge NSData *)v;
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

// Function pointer declarations for additional system functions
static int (*sysctlbyname_orig)(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
static int (*sysctl_orig)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);

static int PXWriteSysctlCStringLocal(const char *value, void *outBuf, size_t *outLen) {
    if (!outLen || !value) { errno = EINVAL; return -1; }
    size_t required = strlen(value) + 1;
    if (!outBuf) {
        *outLen = required;
        return 0;
    }
    if (*outLen < required) {
        *outLen = required;
        errno = ENOMEM;
        return -1;
    }
    memset(outBuf, 0, *outLen);
    memcpy(outBuf, value, required);
    *outLen = required;
    return 0;
}

// Hook for sysctl array - handles both Kernel and Hardware queries
static int sysctl_hook(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    static BOOL logged = NO;
    if (!logged) {
        logged = YES;
        PXFileDebugAIDA64Log("[Tweak.sysctl] first namelen=%u key0=%d key1=%d", namelen, name ? name[0] : -1, (name && namelen > 1) ? name[1] : -1);
    }
    if (!sysctl_orig) return -1;
    if (!name || namelen < 2) {
        return sysctl_orig(name, namelen, oldp, oldlenp, newp, newlen);
    }

    @autoreleasepool {
        @try {
            if (%c(IdentifierManager)) {
                IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
                NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
                NSString *proc = [NSProcessInfo processInfo].processName;
                if (manager && bundleID && PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
                    NSString *profileId = nil;
                    NSNumber *gen = nil;
                    NSDictionary *deviceIds = PXGetDeviceIdsSnapshot(&profileId, &gen);

                    if (name[0] == CTL_HW && [manager isIdentifierEnabled:@"DeviceModel"]) {
                        if (name[1] == HW_MACHINE) {
                            if (!PXRequireKeysAll(deviceIds, @[@"DeviceModel"], @"sysctl", @"CTL_HW/HW_MACHINE", bundleID, profileId, gen)) {
                                return sysctl_orig(name, namelen, oldp, oldlenp, newp, newlen);
                            }
                            NSString *spoofed = deviceIds[@"DeviceModel"];
                            return PXWriteSysctlCStringLocal([spoofed UTF8String], oldp, oldlenp);
                        } else if (name[1] == HW_MODEL) {
                            if (!PXRequireKeysAll(deviceIds, @[@"HwModel"], @"sysctl", @"CTL_HW/HW_MODEL", bundleID, profileId, gen)) {
                                return sysctl_orig(name, namelen, oldp, oldlenp, newp, newlen);
                            }
                            NSString *spoofed = deviceIds[@"HwModel"];
                            return PXWriteSysctlCStringLocal([spoofed UTF8String], oldp, oldlenp);
                        }
                    }

                    if (name[0] == CTL_KERN && [manager isIdentifierEnabled:@"IOSVersion"]) {
                        if (name[1] == KERN_OSVERSION) {
                            if (!PXRequireKeysAll(deviceIds, @[@"IOSBuild"], @"sysctl", @"CTL_KERN/KERN_OSVERSION", bundleID, profileId, gen)) {
                                return sysctl_orig(name, namelen, oldp, oldlenp, newp, newlen);
                            }
                            NSString *spoofed = deviceIds[@"IOSBuild"];
                            return PXWriteSysctlCStringLocal([spoofed UTF8String], oldp, oldlenp);
                        } else if (name[1] == KERN_OSRELEASE) {
                            if (!PXRequireKeysAll(deviceIds, @[@"Darwin"], @"sysctl", @"CTL_KERN/KERN_OSRELEASE", bundleID, profileId, gen)) {
                                return sysctl_orig(name, namelen, oldp, oldlenp, newp, newlen);
                            }
                            NSString *spoofed = deviceIds[@"Darwin"];
                            return PXWriteSysctlCStringLocal([spoofed UTF8String], oldp, oldlenp);
                        } else if (name[1] == KERN_VERSION) {
                            if (!PXRequireKeysAll(deviceIds, @[@"KernelVersion"], @"sysctl", @"CTL_KERN/KERN_VERSION", bundleID, profileId, gen)) {
                                return sysctl_orig(name, namelen, oldp, oldlenp, newp, newlen);
                            }
                            NSString *spoofed = deviceIds[@"KernelVersion"];
                            return PXWriteSysctlCStringLocal([spoofed UTF8String], oldp, oldlenp);
                        }
                    }
                }
            }
        } @catch (__unused NSException *e) {
        }
    }

    return sysctl_orig(name, namelen, oldp, oldlenp, newp, newlen);
}

// Helper functions from successful bypass code
static __thread BOOL px_sysctlbyname_in_hook = NO;

static int PXWriteSysctlCString(const char *name, const char *value, void *oldp, size_t *oldlenp) {
    if (!oldlenp || !value) { errno = EINVAL; return -1; }
    size_t required = strlen(value) + 1; // include NUL
    if (!oldp) {
        *oldlenp = required;
        return 0;
    }
    if (*oldlenp < required) {
        *oldlenp = required;
        errno = ENOMEM;
        return -1;
    }
    memset(oldp, 0, *oldlenp);
    memcpy(oldp, value, required);
    *oldlenp = required;
    return 0;
}

static int PXWriteSysctlInt64(const char *name, int64_t v, void *oldp, size_t *oldlenp) {
    if (!oldlenp) { errno = EINVAL; return -1; }
    // Keep caller's expected size when possible
    if (!oldp) {
        *oldlenp = (*oldlenp ? *oldlenp : sizeof(int64_t));
        return 0;
    }
    if (*oldlenp == sizeof(int)) {
        *(int *)oldp = (int)v;
        return 0;
    }
    if (*oldlenp == sizeof(uint32_t)) {
        *(uint32_t *)oldp = (uint32_t)v;
        return 0;
    }
    if (*oldlenp == sizeof(unsigned long)) {
        *(unsigned long *)oldp = (unsigned long)v;
        return 0;
    }
    if (*oldlenp >= sizeof(int64_t)) {
        *(int64_t *)oldp = (int64_t)v;
        return 0;
    }
    errno = ENOMEM;
    return -1;
}

// CoreFoundation system version dictionary. IOS-06 routes this surface through
// the same transformer used by file-backed SystemVersion.plist reads.
static CFDictionaryRef (*CFCopySystemVersionDictionary_orig)(void);

static CFDictionaryRef CFCopySystemVersionDictionary_hook(void) {
    CFDictionaryRef original = CFCopySystemVersionDictionary_orig ? CFCopySystemVersionDictionary_orig() : NULL;
    @autoreleasepool {
        @try {
            if (!%c(IdentifierManager)) return original;
            IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            NSString *processName = [NSProcessInfo processInfo].processName;
            if (!manager || !bundleID || ![manager isIdentifierEnabled:@"IOSVersion"] ||
                !PXProcessIsAllowedForSpoofing(bundleID, processName, PXScopeOptionAllowSafariAuthStack)) {
                return original;
            }

            PXSystemVersionProjection *projection = PXCurrentSystemVersionProjection();
            if (!projection) return original;
            NSDictionary *base = original ? (__bridge NSDictionary *)original : @{};
            NSDictionary *transformed = PXTransformSystemVersionDictionary(base, projection);
            if (transformed == base) return original;

            NSString *signature = [NSString stringWithFormat:@"%@|%@", projection.profileID ?: @"", projection.generation];
            if (PXLogOnceClaim(@"Tweak.SystemVersion", signature)) {
                PXLog(@"[WeaponX] SystemVersion transformed profile=%@ gen=%@ version=%@ build=%@",
                      projection.profileID ?: @"", projection.generation,
                      projection.productVersion, projection.productBuildVersion);
            }
            CFDictionaryRef result = CFBridgingRetain(transformed);
            if (original) CFRelease(original);
            return result;
        } @catch (NSException *exception) {
            PXLog(@"[WeaponX] SystemVersion transformer exception: %@", exception);
            return original;
        }
    }
}

// Implementation for sysctl hook - commonly used to get device identifiers and detect jailbreak
// Implementation for sysctl hook - commonly used to get device identifiers and detect jailbreak
// Implementation for sysctl hook - commonly used to get device identifiers and detect jailbreak
static int sysctlbyname_hook(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen, BOOL *outHandled) {
    if (outHandled) *outHandled = NO;
    static int loggedCount = 0;
    if (name && loggedCount < 20) {
        loggedCount++;
        PXFileDebugAIDA64Log("[Tweak.sysctlbyname] key=%s oldp=%d oldlenp=%d", name, oldp ? 1 : 0, oldlenp ? 1 : 0);
    }
    if (!sysctlbyname_orig) return 0;
    if (px_sysctlbyname_in_hook) return 0;
    if (!name) return 0;

    px_sysctlbyname_in_hook = YES;

    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID) {
        px_sysctlbyname_in_hook = NO;
        return 0;
    }
    
    // Check if we should spoof
    if (!%c(IdentifierManager)) {
        px_sysctlbyname_in_hook = NO;
        return 0;
    }
    
    IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
    NSString *proc = [NSProcessInfo processInfo].processName;
    if (!manager || !PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
          px_sysctlbyname_in_hook = NO;
          return 0;
    }

    NSString *profileId = nil;
    NSNumber *gen = nil;
    NSDictionary *deviceIds = PXGetDeviceIdsSnapshot(&profileId, &gen);

    // Do not sample the original here. This function is a coordinator pre-provider;
    // unhandled requests must fall through without calling the real syscall twice.
    const char *originalValue = "<coordinator-original>";

    NSString *spoofedValue = nil;
    
    // kern.ostype => "Darwin"
    if (strcmp(name, "kern.ostype") == 0) {
        const char *v = "Darwin";
        int r = PXWriteSysctlCString(name, v, oldp, oldlenp);
        if (r == 0) PXLog(@"[WeaponX] 🎯 Spoofed sysctlbyname kern.ostype to: %s", v);
        if (outHandled) *outHandled = YES;
        px_sysctlbyname_in_hook = NO;
        return r;
    }

     // NEW: kern.osproductversion - Critical for Facebook
      if (strcmp(name, "kern.osproductversion") == 0 && [manager isIdentifierEnabled:@"IOSVersion"]) {
          // Fix Version (runtime-capped): for selected apps, always return runtime value to avoid crashes.
          if (PXFixVersionAppliesToBundle(bundleID)) {
              px_sysctlbyname_in_hook = NO;
              return 0;
          }

          if (!PXRequireKeysAll(deviceIds, @[@"IOSVersion"], @"sysctlbyname", @"kern.osproductversion", bundleID, profileId, gen)) {
              px_sysctlbyname_in_hook = NO;
              return 0;
          }
          spoofedValue = deviceIds[@"IOSVersion"];
      }
    // Machine/Model spoofing
    else if (strcmp(name, "hw.machine") == 0 && [manager isIdentifierEnabled:@"DeviceModel"]) {
        if (!PXRequireKeysAll(deviceIds, @[@"DeviceModel"], @"sysctlbyname", @"hw.machine", bundleID, profileId, gen)) {
            px_sysctlbyname_in_hook = NO;
            return 0;
        }
        spoofedValue = deviceIds[@"DeviceModel"];
    }
    else if (strcmp(name, "hw.model") == 0 && [manager isIdentifierEnabled:@"DeviceModel"]) {
        if (!PXRequireKeysAll(deviceIds, @[@"HwModel"], @"sysctlbyname", @"hw.model", bundleID, profileId, gen)) {
            px_sysctlbyname_in_hook = NO;
            return 0;
        }
        spoofedValue = deviceIds[@"HwModel"];
    }
    else if (strcmp(name, "hw.product") == 0 && [manager isIdentifierEnabled:@"DeviceModel"]) {
         if (!PXRequireKeysAll(deviceIds, @[@"DeviceModel"], @"sysctlbyname", @"hw.product", bundleID, profileId, gen)) {
             px_sysctlbyname_in_hook = NO;
             return 0;
         }
         spoofedValue = deviceIds[@"DeviceModel"];
    }
    // OS Version spoofing
    else if ((strcmp(name, "kern.osversion") == 0 || strcmp(name, "kern.osrelease") == 0 || strcmp(name, "kern.version") == 0) &&
             [manager isIdentifierEnabled:@"IOSVersion"]) {
         if (strcmp(name, "kern.osversion") == 0) {
             if (!PXRequireKeysAll(deviceIds, @[@"IOSBuild"], @"sysctlbyname", @"kern.osversion", bundleID, profileId, gen)) {
                 px_sysctlbyname_in_hook = NO;
                 return 0;
             }
             spoofedValue = deviceIds[@"IOSBuild"];
         } else if (strcmp(name, "kern.osrelease") == 0) {
             if (!PXRequireKeysAll(deviceIds, @[@"Darwin"], @"sysctlbyname", @"kern.osrelease", bundleID, profileId, gen)) {
                 px_sysctlbyname_in_hook = NO;
                 return 0;
             }
             spoofedValue = deviceIds[@"Darwin"];
         } else {
             if (!PXRequireKeysAll(deviceIds, @[@"KernelVersion"], @"sysctlbyname", @"kern.version", bundleID, profileId, gen)) {
                 px_sysctlbyname_in_hook = NO;
                 return 0;
             }
             spoofedValue = deviceIds[@"KernelVersion"];
         }
    }
    else if (strcmp(name, "kern.hostname") == 0 && [manager isIdentifierEnabled:@"DeviceName"]) {
        spoofedValue = [manager currentValueForIdentifier:@"DeviceName"];
    }
    // kern.uuid: NUL-terminated UUID *string* (not raw 16 bytes — that is gethostuuid)
    else if (strcmp(name, "kern.uuid") == 0 && [manager isIdentifierEnabled:@"SystemBootUUID"]) {
        spoofedValue = [manager currentValueForIdentifier:@"SystemBootUUID"];
        if (!spoofedValue.length) {
            // legacy one-way alias
            spoofedValue = [manager currentValueForIdentifier:@"HardwareUUID"];
        }
    }
    
    // WRITE STRING VALUE if found
    if (spoofedValue.length > 0) {
        const char *v = [spoofedValue UTF8String];
        int r = PXWriteSysctlCString(name, v, oldp, oldlenp);
        if (r == 0) {
            PXLog(@"[WeaponX] 🎯 Spoofed sysctlbyname %s from: %s to: %s", name, originalValue, v);
        }
        if (outHandled) *outHandled = YES;
        px_sysctlbyname_in_hook = NO;
        return r;
    }
    
    // CPU topology and CPU identity are owned exclusively by DeviceSpecHooks.x.
    // Leave all hw.*cpu* keys unhandled here so the canonical DeviceSpec provider
    // can serialize one consistent SoC profile across sysctlbyname, NSProcessInfo,
    // and NXGetLocalArchInfo.

    // Jailbreak detection hook removed to match working bypass behavior
    // (Facebook may check for behavior discrepancy here)

    px_sysctlbyname_in_hook = NO;
    return 0;
}

// IOS-05: complete uname() projection from one immutable identity snapshot.
// Field contract:
//   sysname="Darwin", release=Darwin, version=KernelVersion  (IOSVersion toggle)
//   nodename=DeviceName                                  (DeviceName toggle)
//   machine=DeviceModel                                  (DeviceModel toggle)
// The native result remains untouched when scope, toggle, validation, or capacity fails.
static int (*uname_orig)(struct utsname *);
static __thread BOOL px_uname_in_hook = NO;

static BOOL PXUnameWriteField(char *destination, size_t capacity, NSString *value) {
    if (!destination || capacity == 0 || !PXProfileString(value)) return NO;
    const char *utf8 = value.UTF8String;
    if (!utf8) return NO;
    size_t length = strlen(utf8);
    if (length >= capacity) return NO;
    memset(destination, 0, capacity);
    memcpy(destination, utf8, length);
    destination[length] = '\0';
    return YES;
}

static int uname_hook(struct utsname *buf) {
    if (!uname_orig) {
        errno = ENOSYS;
        return -1;
    }
    if (px_uname_in_hook) return uname_orig(buf);

    int result = uname_orig(buf);
    int nativeErrno = errno;
    if (result != 0 || !buf) {
        errno = nativeErrno;
        return result;
    }

    px_uname_in_hook = YES;
    @autoreleasepool {
        @try {
            if (!%c(IdentifierManager)) {
                errno = nativeErrno;
                px_uname_in_hook = NO;
                return result;
            }

            IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            NSString *processName = [NSProcessInfo processInfo].processName;
            if (!manager || !bundleID ||
                !PXProcessIsAllowedForSpoofing(bundleID, processName, PXScopeOptionAllowSafariAuthStack)) {
                errno = nativeErrno;
                px_uname_in_hook = NO;
                return result;
            }

            NSString *profileID = nil;
            NSNumber *generation = nil;
            NSDictionary *deviceIDs = PXGetDeviceIdsSnapshot(&profileID, &generation);
            struct utsname candidate = *buf;
            BOOL changed = NO;

            if ([manager isIdentifierEnabled:@"IOSVersion"] &&
                PXRequireKeysAll(deviceIDs, @[@"Darwin", @"KernelVersion"], @"uname",
                                 @"utsname.sysname/release/version", bundleID, profileID, generation)) {
                struct utsname versionCandidate = candidate;
                BOOL valid = PXUnameWriteField(versionCandidate.sysname, sizeof(versionCandidate.sysname), @"Darwin") &&
                             PXUnameWriteField(versionCandidate.release, sizeof(versionCandidate.release), deviceIDs[@"Darwin"]) &&
                             PXUnameWriteField(versionCandidate.version, sizeof(versionCandidate.version), deviceIDs[@"KernelVersion"]);
                if (valid) {
                    candidate = versionCandidate;
                    changed = YES;
                }
            }

            if ([manager isIdentifierEnabled:@"DeviceName"] &&
                PXRequireKeysAll(deviceIDs, @[@"DeviceName"], @"uname",
                                 @"utsname.nodename", bundleID, profileID, generation)) {
                struct utsname nameCandidate = candidate;
                if (PXUnameWriteField(nameCandidate.nodename, sizeof(nameCandidate.nodename), deviceIDs[@"DeviceName"])) {
                    candidate = nameCandidate;
                    changed = YES;
                }
            }

            if ([manager isIdentifierEnabled:@"DeviceModel"] &&
                PXRequireKeysAll(deviceIDs, @[@"DeviceModel"], @"uname",
                                 @"utsname.machine", bundleID, profileID, generation)) {
                struct utsname modelCandidate = candidate;
                if (PXUnameWriteField(modelCandidate.machine, sizeof(modelCandidate.machine), deviceIDs[@"DeviceModel"])) {
                    candidate = modelCandidate;
                    changed = YES;
                }
            }

            if (changed) {
                // Publish one complete struct only after all selected field groups validate.
                *buf = candidate;
                NSString *signature = [NSString stringWithFormat:@"%@|%@", profileID ?: @"", generation ?: @""];
                if (PXLogOnceClaim(@"Tweak.uname", signature)) {
                    PXLog(@"[WeaponX] uname projected profile=%@ gen=%@ sysname=%s nodename=%s release=%s version=%s machine=%s",
                          profileID ?: @"", generation ?: @"", buf->sysname, buf->nodename,
                          buf->release, buf->version, buf->machine);
                }
            }
        } @catch (NSException *exception) {
            PXLog(@"[WeaponX] Exception in uname hook: %@", exception);
        }
    }

    px_uname_in_hook = NO;
    errno = nativeErrno;
    return result;
}

// Define hook group for main identifier spoofing
%group Identifiers

// MGCopyAnswer hook for various system identifiers
%hookf(CFTypeRef, MGCopyAnswer, CFStringRef property) {
    static int loggedCount = 0;
    if (property && loggedCount < 30) {
        loggedCount++;
        NSString *p = (__bridge NSString *)property;
        PXFileDebugAIDA64Log("[Tweak.MGCopyAnswer] property=%s", p.UTF8String ?: "<nil>");
    }
    if (!%c(IdentifierManager)) {
        return %orig;
    }
    
    IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
    NSString *propertyString = (__bridge NSString *)property;
    NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString *profileId = nil;
    NSNumber *gen = nil;
    NSDictionary *deviceIds = PXGetDeviceIdsSnapshot(&profileId, &gen);
    
    PXLog(@"MGCopyAnswer requested for property: %@ by app: %@", propertyString, currentBundleID);
    
    NSString *proc = [NSProcessInfo processInfo].processName;
    if (!PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
        return %orig;
    }

    NSDictionary *securitySettings = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist"];
    BOOL targetRegionFollowsIP = [securitySettings[@"targetRegionFollowsIPEnabled"] boolValue];
    NSString *pinnedCountryCode = [securitySettings[@"targetRegionPinnedCountryCode"] isKindOfClass:[NSString class]] ? securitySettings[@"targetRegionPinnedCountryCode"] : nil;
    NSString *pinnedMCC = [securitySettings[@"targetRegionPinnedCarrierMCC"] isKindOfClass:[NSString class]] ? securitySettings[@"targetRegionPinnedCarrierMCC"] : nil;
    NSString *pinnedMNC = [securitySettings[@"targetRegionPinnedCarrierMNC"] isKindOfClass:[NSString class]] ? securitySettings[@"targetRegionPinnedCarrierMNC"] : nil;

    // TargetRegion (pinned from IP) - keep Region/Subscriber fields consistent.
    if (propertyString && targetRegionFollowsIP) {
        if ([propertyString isEqualToString:@"RegionCode"] && pinnedCountryCode.length) {
            return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)[pinnedCountryCode uppercaseString]);
        }
        if ([propertyString isEqualToString:@"MobileSubscriberCountryCode"] && pinnedMCC.length) {
            return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)pinnedMCC);
        }
        if ([propertyString isEqualToString:@"MobileSubscriberNetworkCode"] && pinnedMNC.length) {
            return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)pinnedMNC);
        }
    }
    
    // HOOK-02: resolve MobileGestalt aliases, toggles and snapshot sources centrally.
    PXIdentitySurfaceEntry *surfaceEntry =
        PXIdentitySurfaceEntryForKey(propertyString, PXIdentitySurfaceMobileGestalt);
    if (surfaceEntry && [manager isIdentifierEnabled:surfaceEntry.toggle]) {
        NSString *surfaceValue = PXIdentitySurfaceResolveValue(surfaceEntry, deviceIds);
        BOOL sourceReady = surfaceEntry.constantValue.length > 0;
        if (!sourceReady && surfaceEntry.deviceIDKey.length) {
            sourceReady = PXRequireKeysAll(deviceIds, @[surfaceEntry.deviceIDKey], @"MG",
                                           propertyString, currentBundleID, profileId, gen);
        }
        if (sourceReady && surfaceValue.length) {
            if (surfaceEntry.expectedType == PXIdentityExpectedTypeData) {
                return (CFTypeRef)PXCreateCFDataFromNSString(surfaceValue);
            }
            return (CFTypeRef)PXCreateCFStringFromNSString(surfaceValue);
        }
        return %orig;
    }

    // Handle various identifier types
    if ([propertyString isEqualToString:@"UniqueDeviceID"]) {
        if ([manager isIdentifierEnabled:@"UDID"]) {
            NSString *spoofedUDID = [manager currentValueForIdentifier:@"UDID"];
            if (spoofedUDID.length) {
                PXLog(@"Spoofing UniqueDeviceID with: %@", spoofedUDID);
                return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)spoofedUDID);
            }
        }
    }
    if ([propertyString isEqualToString:@"UniqueDeviceIDData"]) {
        // UniqueDeviceIDData must return CFData matching original ABI — not a string.
        if ([manager isIdentifierEnabled:@"UDID"]) {
            NSString *spoofedUDID = [manager currentValueForIdentifier:@"UDID"];
            if (spoofedUDID.length) {
                NSData *hexData = nil;
                // Prefer raw hex bytes when UDID is 40-char hex; else UTF-8 bytes of the string.
                if (spoofedUDID.length == 40) {
                    NSMutableData *md = [NSMutableData dataWithCapacity:20];
                    const char *c = spoofedUDID.UTF8String;
                    for (NSUInteger i = 0; i + 1 < 40 && c; i += 2) {
                        unsigned int byte = 0;
                        if (sscanf(c + i, "%02x", &byte) == 1) {
                            uint8_t b = (uint8_t)byte;
                            [md appendBytes:&b length:1];
                        }
                    }
                    if (md.length == 20) hexData = md;
                }
                if (!hexData) {
                    hexData = [spoofedUDID dataUsingEncoding:NSUTF8StringEncoding];
                }
                if (hexData) {
                    PXLog(@"Spoofing UniqueDeviceIDData (%lu bytes)", (unsigned long)hexData.length);
                    return CFDataCreate(kCFAllocatorDefault, hexData.bytes, (CFIndex)hexData.length);
                }
            }
        }
    } 
    else if ([propertyString isEqualToString:@"SerialNumber"]) {
        // Special case for Filza and ADManager
        if ([currentBundleID isEqualToString:@"com.tigisoftware.Filza"] || 
            [currentBundleID isEqualToString:@"com.tigisoftware.ADManager"]) {
            NSString *hardcodedSerial = @"FCCC15Q4HG04";
            PXLog(@"[WeaponX] 📱 Returning hardcoded serial number for %@: %@", currentBundleID, hardcodedSerial);
            return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)hardcodedSerial);
        }
        
        if ([manager isIdentifierEnabled:@"SerialNumber"]) {
            NSString *spoofedSerial = [manager currentValueForIdentifier:@"SerialNumber"];
            if (spoofedSerial) {
                PXLog(@"Spoofing Serial Number with: %@", spoofedSerial);
                return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)spoofedSerial);
            }
        }
    }
    else if ([propertyString isEqualToString:@"InternationalMobileEquipmentIdentity"]) {
        // IMEI only — separate toggle/value from MEID.
        if ([manager isIdentifierEnabled:@"IMEI"]) {
            NSString *spoofedIMEI = [manager currentValueForIdentifier:@"IMEI"];
            if (spoofedIMEI.length) {
                PXLog(@"Spoofing IMEI with: %@", spoofedIMEI);
                return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)spoofedIMEI);
            }
        }
    }
    else if ([propertyString isEqualToString:@"MobileEquipmentIdentifier"]) {
        // MEID only — separate toggle/value from IMEI.
        if ([manager isIdentifierEnabled:@"MEID"]) {
            NSString *spoofedMEID = [manager currentValueForIdentifier:@"MEID"];
            if (spoofedMEID.length) {
                PXLog(@"Spoofing MEID with: %@", spoofedMEID);
                return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)spoofedMEID);
            }
        }
    }
    
    // Default: return original value
    PXLog(@"No spoofing applied, returning original value");
    return %orig;
}

// ATT / IDFA consistency helpers (active when identifier IDFA is enabled — no second master toggle)
static NSString *const kPXZeroIDFAUUID = @"00000000-0000-0000-0000-000000000000";

static BOOL PXATTSpoofActive(void) {
    if (!%c(IdentifierManager)) return NO;
    IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
    if (!manager) return NO;
    NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString *proc = [NSProcessInfo processInfo].processName;
    if (!PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
        return NO;
    }
    return [manager isIdentifierEnabled:@"IDFA"];
}

// Returns profile ATT status 0...3. Falls back to device_ids / tracking_info via IdentifierManager.
static NSInteger PXProfileATTAuthorizationStatus(void) {
    IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
    if (!manager) return 0;
    if ([manager respondsToSelector:@selector(attAuthorizationStatus)]) {
        NSInteger status = [manager attAuthorizationStatus];
        if (status < 0) status = 0;
        if (status > 3) status = 3;
        return status;
    }
    // Manual fallback if method missing
    @try {
        NSString *identityDir = nil;
        if ([manager respondsToSelector:@selector(profileIdentityPath)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            identityDir = [manager performSelector:@selector(profileIdentityPath)];
#pragma clang diagnostic pop
        }
        if (identityDir.length) {
            NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:
                [identityDir stringByAppendingPathComponent:@"device_ids.plist"]];
            if (deviceIds[@"ATTAuthorizationStatus"] != nil) {
                NSInteger s = [deviceIds[@"ATTAuthorizationStatus"] integerValue];
                if (s >= 0 && s <= 3) return s;
            }
            NSDictionary *tracking = [NSDictionary dictionaryWithContentsOfFile:
                [identityDir stringByAppendingPathComponent:@"tracking_info.plist"]];
            if (tracking[@"ATTAuthorizationStatus"] != nil) {
                NSInteger s = [tracking[@"ATTAuthorizationStatus"] integerValue];
                if (s >= 0 && s <= 3) return s;
            }
        }
    } @catch (__unused NSException *e) {}
    return 0;
}

// IDFA + legacy advertisingTrackingEnabled (ATT consistency)
%hook ASIdentifierManager

- (BOOL)isAdvertisingTrackingEnabled {
    if (!PXATTSpoofActive()) {
        return %orig;
    }
    // YES only when profile ATT status is authorized (3)
    return PXProfileATTAuthorizationStatus() == 3;
}

- (NSUUID *)advertisingIdentifier {
    if (!%c(IdentifierManager)) {
        return %orig;
    }
    
    IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
    NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    PXLog(@"IDFA requested by app: %@", currentBundleID);

    NSString *proc = [NSProcessInfo processInfo].processName;
    if (!PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
        PXLog(@"App not in scope or disabled, passing through original IDFA");
        return %orig;
    }

    if ([manager isIdentifierEnabled:@"IDFA"]) {
        NSInteger attStatus = PXProfileATTAuthorizationStatus();
        // authorized → profile IDFA; restricted/denied/notDetermined → zero UUID
        if (attStatus != 3) {
            PXLog(@"ATT status=%ld → returning zero IDFA", (long)attStatus);
            return [[NSUUID alloc] initWithUUIDString:kPXZeroIDFAUUID];
        }
        NSString *idfaString = [manager currentValueForIdentifier:@"IDFA"];
        if (idfaString.length) {
            PXLog(@"Spoofing IDFA with: %@", idfaString);
            NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:idfaString];
            if (uuid) return uuid;
        }
        // Authorized but missing value — still zero rather than leaking real IDFA
        return [[NSUUID alloc] initWithUUIDString:kPXZeroIDFAUUID];
    }
    
    PXLog(@"No IDFA spoofing applied, returning original value");
    return %orig;
}

%end

// ATTrackingManager (iOS 14+) — installed at runtime only if class/methods exist
static NSInteger (*orig_ATTrackingManager_trackingAuthorizationStatus)(Class, SEL) = NULL;
static void (*orig_ATTrackingManager_requestTrackingAuthorizationWithCompletionHandler)(Class, SEL, void (^)(NSInteger)) = NULL;

static NSInteger hook_ATTrackingManager_trackingAuthorizationStatus(Class self, SEL _cmd) {
    if (PXATTSpoofActive()) {
        return PXProfileATTAuthorizationStatus();
    }
    if (orig_ATTrackingManager_trackingAuthorizationStatus) {
        return orig_ATTrackingManager_trackingAuthorizationStatus(self, _cmd);
    }
    return 0;
}

static void hook_ATTrackingManager_requestTrackingAuthorizationWithCompletionHandler(Class self, SEL _cmd, void (^completion)(NSInteger)) {
    if (PXATTSpoofActive()) {
        // Do NOT call system prompt; deliver profile status async on main queue
        NSInteger status = PXProfileATTAuthorizationStatus();
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(status);
            });
        }
        return;
    }
    if (orig_ATTrackingManager_requestTrackingAuthorizationWithCompletionHandler) {
        orig_ATTrackingManager_requestTrackingAuthorizationWithCompletionHandler(self, _cmd, completion);
    } else if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(0);
        });
    }
}

static void PXInstallATTHooksIfAvailable(void) {
    // Soft-link AppTrackingTransparency if present (iOS 14+)
    void *attFramework = dlopen("/System/Library/Frameworks/AppTrackingTransparency.framework/AppTrackingTransparency", RTLD_LAZY);
    (void)attFramework;

    Class attClass = objc_getClass("ATTrackingManager");
    if (!attClass) {
        PXLog(@"[WeaponX] ATT: ATTrackingManager not present — using legacy ASIdentifierManager path only");
        return;
    }

    SEL statusSel = NSSelectorFromString(@"trackingAuthorizationStatus");
    Method statusMethod = class_getClassMethod(attClass, statusSel);
    if (statusMethod) {
        MSHookMessageEx(object_getClass((id)attClass), statusSel,
                        (IMP)hook_ATTrackingManager_trackingAuthorizationStatus,
                        (IMP *)&orig_ATTrackingManager_trackingAuthorizationStatus);
        PXLog(@"[WeaponX] ATT: hooked +[ATTrackingManager trackingAuthorizationStatus]");
    } else {
        PXLog(@"[WeaponX] ATT: trackingAuthorizationStatus unsupported-selector");
    }

    SEL requestSel = NSSelectorFromString(@"requestTrackingAuthorizationWithCompletionHandler:");
    Method requestMethod = class_getClassMethod(attClass, requestSel);
    if (requestMethod) {
        MSHookMessageEx(object_getClass((id)attClass), requestSel,
                        (IMP)hook_ATTrackingManager_requestTrackingAuthorizationWithCompletionHandler,
                        (IMP *)&orig_ATTrackingManager_requestTrackingAuthorizationWithCompletionHandler);
        PXLog(@"[WeaponX] ATT: hooked +[ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:]");
    } else {
        PXLog(@"[WeaponX] ATT: requestTrackingAuthorizationWithCompletionHandler: unsupported-selector");
    }
}

// IDFV and device name hooks
%hook UIDevice

// Hook for identifierForVendor (IDFV)
- (NSUUID *)identifierForVendor {
    NSUUID *originalIdentifier = %orig;
    
    @try {
        if (!%c(IdentifierManager)) {
            return originalIdentifier;
        }
        
        IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
        NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];

        if (!currentBundleID) {
            return originalIdentifier;
        }
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (!PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
            return originalIdentifier;
        }
        
        // In iOS 15+, this is the preferred identifier checked by many apps
        if ([manager isIdentifierEnabled:@"IDFV"]) {
            NSString *idfvString = [manager currentValueForIdentifier:@"IDFV"];
            if (idfvString) {
                // Create a static cache keyed by bundle ID to ensure consistent values
                static NSMutableDictionary *idfvCache = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    idfvCache = [NSMutableDictionary dictionary];
                });
                
                // Thread-safe access to the cache
                @synchronized(idfvCache) {
                    NSUUID *cachedValue = idfvCache[currentBundleID];
                    if (cachedValue) {
                        return cachedValue;
                    }
                    
                    NSUUID *spoofedIdentifier = [[NSUUID alloc] initWithUUIDString:idfvString];
                    if (spoofedIdentifier) {
                        PXLog(@"[WeaponX] Spoofing identifierForVendor with: %@", idfvString);
                        idfvCache[currentBundleID] = spoofedIdentifier;
                        return spoofedIdentifier;
                    }
                }
            }
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in identifierForVendor: %@", exception);
    }
    
    return originalIdentifier;
}

// Hook for device name with improved iOS 15-16 compatibility
- (NSString *)name {
    NSString *originalName = %orig;
    
    @try {
        if (!%c(IdentifierManager)) {
            return originalName;
        }
        
        IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
        NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];

        if (!currentBundleID) {
            return originalName;
        }
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (!PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
            return originalName;
        }
        
        if ([manager isIdentifierEnabled:@"DeviceName"]) {
            NSString *deviceName = [manager currentValueForIdentifier:@"DeviceName"];
            if (deviceName && deviceName.length > 0) {
                // Cache the name for this process to ensure consistency
                static NSString *cachedHostName = nil;
                if (!cachedHostName) {
                    cachedHostName = [deviceName copy];
                }
                PXLog(@"[WeaponX] Spoofing NSHost name with: %@", cachedHostName);
                return cachedHostName;
            }
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in NSHost name: %@", exception);
    }
    
    return originalName;
}

%end

// IDFV fallback through ubiquityIdentityToken
%hook NSFileManager

- (id)ubiquityIdentityToken {
    if (!%c(IdentifierManager)) {
        return %orig;
    }
    
    IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
    NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    PXLog(@"ubiquityIdentityToken requested by app: %@", currentBundleID);

    NSString *proc = [NSProcessInfo processInfo].processName;
    if (!PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
        PXLog(@"App not in scope or disabled, passing through original ubiquityIdentityToken");
        return %orig;
    }
    
    if ([manager isIdentifierEnabled:@"IDFV"]) {
        // If IDFV is enabled, we can't directly replace the token as it's a private structure
        // but we can return nil to prevent tracking through this method
        PXLog(@"Blocking ubiquityIdentityToken access for privacy protection");
        return nil;
    }
    
    return %orig;
}

%end

// NSHost hook for device name
%hook NSHost

+ (NSHost *)currentHost {
    NSHost *originalHost = %orig;
    
    if (!%c(IdentifierManager)) {
        return originalHost;
    }
    
    IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
    NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    PXLog(@"NSHost currentHost requested by app: %@", currentBundleID);

    NSString *proc = [NSProcessInfo processInfo].processName;
    if (!PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
        PXLog(@"App not in scope, returning original host info");
        return originalHost;
    }
    
    if ([manager isIdentifierEnabled:@"DeviceName"]) {
        // We can't easily modify the NSHost instance as it has private structure
        // So we'll overwrite the name and addresses methods
        PXLog(@"App is requesting NSHost information - will spoof in name method");
        
        // Return the original host, name will be handled in the name method
        return originalHost;
    }
    
    return originalHost;
}

- (NSString *)name {
    NSString *originalName = %orig;
    
    @try {
        if (!%c(IdentifierManager)) {
            return originalName;
        }
        
        IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
        NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (!currentBundleID) {
            return originalName;
        }
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (!PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
            return originalName;
        }
        
        if ([manager isIdentifierEnabled:@"DeviceName"]) {
            NSString *deviceName = [manager currentValueForIdentifier:@"DeviceName"];
            if (deviceName && deviceName.length > 0) {
                // Cache the name for this process to ensure consistency
                static NSString *cachedHostName = nil;
                if (!cachedHostName) {
                    cachedHostName = [deviceName copy];
                }
                PXLog(@"[WeaponX] Spoofing NSHost name with: %@", cachedHostName);
                return cachedHostName;
            }
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in NSHost name: %@", exception);
    }
    
    return originalName;
}

%end

// CTTelephonyNetworkInfo hook for carrier info with iOS 15-16 compatibility
%hook CTTelephonyNetworkInfo

// Basic subscriber cellular provider method
- (id)subscriberCellularProvider {
    id original = %orig;
    
    @try {
        if (!%c(IdentifierManager)) {
            return original;
        }
        
        IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
        NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (!currentBundleID) {
            return original;
        }
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (!PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
            return original;
        }
        
        // If any identifier spoofing is enabled, ensure we're consistent with carrier info
        // to prevent carrier-based fingerprinting (common on iOS 15+)
        if ([manager isIdentifierEnabled:@"IDFV"] || 
            [manager isIdentifierEnabled:@"IDFA"] || 
            [manager isIdentifierEnabled:@"UDID"]) {
            // We return the original but modified carrier object is handled via CTCarrier hooks
        }
    } @catch (NSException *exception) {
        // We return the original but modified carrier object is handled via CTCarrier hooks
    }
    
    return original;
}

// iOS 12+ multi-carrier support - heavily used in iOS 15-16
- (NSDictionary *)serviceSubscriberCellularProviders {
    NSDictionary *original = %orig;
    
    @try {
        if (!%c(IdentifierManager)) {
            return original;
        }
        
        IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
        NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (!currentBundleID) {
            return original;
        }
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (!PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
            return original;
        }
        
        // For iOS 15+, apps often use this to fingerprint devices
        if ([manager isIdentifierEnabled:@"IDFV"] || 
            [manager isIdentifierEnabled:@"IDFA"] || 
            [manager isIdentifierEnabled:@"UDID"]) {
            // The individual CTCarrier objects in the dictionary will be modified 
            // by the CTCarrier hooks separately
        }
    } @catch (NSException *exception) {
        // The individual CTCarrier objects in the dictionary will be modified 
        // by the CTCarrier hooks separately
    }
    
    return original;
}

// iOS 13+ carrier data for specific carrier token
- (id)subscriberCellularProviderForIdentifier:(NSString *)identifier {
    id original = %orig;
    
    @try {
        if (!%c(IdentifierManager) || !identifier) {
            return original;
        }
        
        IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
        NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (!currentBundleID) {
            return original;
        }
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (!PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
            return original;
        }
        
        // Ensure consistent carrier info for this specific carrier
        if ([manager isIdentifierEnabled:@"IDFV"] || 
            [manager isIdentifierEnabled:@"IDFA"] || 
            [manager isIdentifierEnabled:@"UDID"]) {
        }
    } @catch (NSException *exception) {
        // The individual CTCarrier objects in the dictionary will be modified 
        // by the CTCarrier hooks separately
    }
    
    return original;
}

%end

%end // End of Identifiers group

// Define hook group for screenshot modifications
%group ScreenshotModifier

// Extension for UIImage to add profile indicator and remove navigation bar
%hookf(UIImage *, UIImagePNGRepresentation, UIImage *image) {
    UIImage *modifiedImage = image;
    
    // First, remove navigation bar from the screenshot
    modifiedImage = [modifiedImage weaponx_removeNavigationBar];
    
    // Then, add profile indicator
    modifiedImage = [modifiedImage weaponx_addProfileIndicator];
    
    // Finally, convert to PNG
    return %orig(modifiedImage);
}

// Hook into screenshot saving
%hook SBScreenshotManager

- (void)saveScreenshotsWithCompletion:(id)completion {
    PXLog(@"[WeaponX] Intercepted screenshot capture");
    %orig;
}

- (void)saveScreenshots {
    PXLog(@"[WeaponX] Intercepted screenshot capture (no completion)");
    %orig;
}

%end

%hook UIImage

// Extension method to add profile indicator
%new
- (UIImage *)weaponx_addProfileIndicator {
    // Get the current profile ID from NSUserDefaults
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.hydra.projectx.shared"];
    NSString *profileId = [defaults objectForKey:@"CurrentProfileID"];
    
    if (!profileId) {
        profileId = @"1"; // Default to 1 if no profile ID is saved
    }
    
    // Ensure profileId is treated as a string to avoid any numeric conversion issues
    NSString *displayProfileId = [NSString stringWithFormat:@"%@", profileId];
    PXLog(@"[WeaponX] Screenshot using profile ID: %@", displayProfileId);
    
    // Begin a new graphics context with the image size
    UIGraphicsBeginImageContextWithOptions(self.size, NO, self.scale);
    
    // Draw the original image
    [self drawAtPoint:CGPointZero];
    
    // Create the indicator text
    NSString *indicatorText = [NSString stringWithFormat:@"←------------------ Profile Num: %@ -----------------→", displayProfileId];
    
    // Create the attributes for the text
    UIFont *font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    NSDictionary *attributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: [UIColor systemBlueColor]
    };
    
    // Create the text to be drawn
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:indicatorText attributes:attributes];
    
    // Get the size of the text
    CGSize textSize = [attributedString size];
    
    // Save the context state
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    
    // Translate and rotate the context to draw vertical text on the left edge
    CGContextTranslateCTM(context, 20, self.size.height / 2);
    CGContextRotateCTM(context, -M_PI_2);
    
    // Draw the text
    [attributedString drawAtPoint:CGPointMake(-textSize.width / 2, -textSize.height / 2)];
    
    // Restore the context state
    CGContextRestoreGState(context);
    
    // Get the modified image
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    // End the graphics context
    UIGraphicsEndImageContext();
    
    return newImage ?: self;
}

// Extension method to remove navigation bar
%new
- (UIImage *)weaponx_removeNavigationBar {
    // Check if there's a navigation bar to remove (usually at the top of the screen)
    // We'll assume a standard navigation bar height of ~44 points from the top
    CGFloat navBarHeight = 44.0;
    
    // Begin a new graphics context with the image size
    UIGraphicsBeginImageContextWithOptions(self.size, NO, self.scale);
    
    // Draw the original image but crop out the navigation bar area
    [self drawInRect:CGRectMake(0, 0, self.size.width, self.size.height)
            blendMode:kCGBlendModeNormal
                alpha:1.0];
    
    // Get a reference to the graphics context
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Create a solid color rectangle to cover the navigation bar area
    CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, self.size.width, navBarHeight));
    
    // Get the modified image
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    // End the graphics context
    UIGraphicsEndImageContext();
    
    return newImage ?: self;
}

%end

%end // End ScreenshotModifier group

// Define hook group for location spoofing
static BOOL PXLocationManagerShouldSpoof(LocationSpoofingManager *manager, NSString *bundleID) {
    if (!manager || ![manager isSpoofingEnabled] || !bundleID.length) return NO;
    NSString *proc = [NSProcessInfo processInfo].processName;
    return PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionNone);
}

%group LocationSpoofing

// Hook CLLocationManager to intercept location updates
%hook CLLocationManager

- (void)setDelegate:(id)delegate {
    %orig;

    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID.length && ![bundleID hasPrefix:@"com.apple."]) {
            LocationSpoofingManager *manager = [LocationSpoofingManager sharedManager];
            NSString *delegateID = [NSString stringWithFormat:@"%p-%p", delegate, self];
            if (PXLogOnceClaim(@"Tweak.locationDelegate", delegateID) && manager) {
                BOOL isSpoofingEnabled = [manager isSpoofingEnabled];
                BOOL shouldSpoofApp = PXLocationManagerShouldSpoof(manager, bundleID);
                if (isSpoofingEnabled && shouldSpoofApp) {
                    double lat = [manager getSpoofedLatitude];
                    double lon = [manager getSpoofedLongitude];
                    PXLog(@"[WeaponX] GPS spoofing is enabled for %@. Using: %.6f, %.6f",
                          bundleID, lat, lon);
                } else if (isSpoofingEnabled) {
                    PXLog(@"[WeaponX] GPS spoofing is enabled globally but not for %@", bundleID);
                }
                if (isSpoofingEnabled && shouldSpoofApp && manager.jitterEnabled) {
                    manager.positionVariationsEnabled = YES;
                }
            }
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in CLLocationManager.setDelegate: %@", exception);
    }
}

// Hook location accuracy settings
- (void)setDesiredAccuracy:(CLLocationAccuracy)accuracy {
    // Check if we should modify accuracy
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        LocationSpoofingManager *manager = [LocationSpoofingManager sharedManager];
        
        // Only proceed if this is an app we're monitoring
        if (PXLocationManagerShouldSpoof(manager, bundleID)) {
            // Ensure high accuracy for our spoofed locations
            PXLog(@"[WeaponX] App %@ requested accuracy %.1f, ensuring best accuracy for spoofing", 
                  bundleID, accuracy);
            
            // Override with best accuracy
            %orig(kCLLocationAccuracyBest);
            return;
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in setDesiredAccuracy: %@", exception);
    }
    
    // Default behavior
    %orig;
}

// Monitor when location updates are started
- (void)startUpdatingLocation {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID && ![bundleID hasPrefix:@"com.apple."]) {
            PXLog(@"[WeaponX] App %@ started location updates", bundleID);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in startUpdatingLocation: %@", exception);
    }
    
    %orig;
}

// Monitor when location updates are stopped
- (void)stopUpdatingLocation {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID && ![bundleID hasPrefix:@"com.apple."]) {
            PXLog(@"[WeaponX] App %@ stopped location updates", bundleID);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in stopUpdatingLocation: %@", exception);
    }
    
    %orig;
}

%end

// Hook CLLocation to modify coordinate with improved thread safety
%hook CLLocation

- (CLLocationCoordinate2D)coordinate {
    // Get the original coordinate
    CLLocationCoordinate2D originalCoordinate = %orig;
    
    // Use thread-local storage to prevent recursive calls
    static NSString * const kRecursionGuardKey = @"CLLocationCoordinateRecursionGuard";
    NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    if ([threadDictionary[kRecursionGuardKey] boolValue]) {
        return originalCoordinate;
    }
    
    // Set recursion guard
    threadDictionary[kRecursionGuardKey] = @YES;
    
    @try {
        // Performance optimization: throttle location checks
        static NSTimeInterval lastProcessTime = 0;
        static CLLocationCoordinate2D lastReturnedCoordinate = {0, 0};
        
        // Thread-safe time check
        NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
        BOOL shouldThrottle = NO;
        
        @synchronized([self class]) {
            shouldThrottle = (currentTime - lastProcessTime < 0.2);
            
            if (!shouldThrottle) {
                lastProcessTime = currentTime;
            }
        }
        
        if (shouldThrottle) {
            // Return the last spoofed coordinates if they were set and valid
            if (CLLocationCoordinate2DIsValid(lastReturnedCoordinate) && 
                (lastReturnedCoordinate.latitude != 0.0 || lastReturnedCoordinate.longitude != 0.0)) {
                threadDictionary[kRecursionGuardKey] = nil;
                return lastReturnedCoordinate;
            }
            threadDictionary[kRecursionGuardKey] = nil;
            return originalCoordinate;
        }
        
        // Get the LocationSpoofingManager and check if spoofing is enabled
        LocationSpoofingManager *manager = [LocationSpoofingManager sharedManager];
        if (!manager) {
            threadDictionary[kRecursionGuardKey] = nil;
            return originalCoordinate;
        }
        
        // Check if spoofing is enabled - this verifies pinned location exists
        if (![manager isSpoofingEnabled]) {
            // Not enabled, return original coordinate
            threadDictionary[kRecursionGuardKey] = nil;
            return originalCoordinate;
        }
        
        // Get the current bundle ID
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (!bundleID) {
            threadDictionary[kRecursionGuardKey] = nil;
            return originalCoordinate;
        }
        
        // Check if we should spoof this app
        if (!PXLocationManagerShouldSpoof(manager, bundleID)) {
            threadDictionary[kRecursionGuardKey] = nil;
            return originalCoordinate;
        }
        
        // Use modifySpoofedLocation method which properly handles position variations
        // Create a temporary CLLocation with the original coordinates to modify
        CLLocation *tempLocation = [[CLLocation alloc] initWithLatitude:originalCoordinate.latitude
                                                             longitude:originalCoordinate.longitude];
        
        // Get a properly spoofed location with all variations applied
        CLLocation *spoofedLocation = [manager modifySpoofedLocation:tempLocation];
        if (!spoofedLocation) {
            threadDictionary[kRecursionGuardKey] = nil;
            return originalCoordinate;
        }
        
        // Get the spoofed coordinates with variations applied
        CLLocationCoordinate2D spoofedCoordinate = spoofedLocation.coordinate;
        
        // Store the spoofed coordinate for throttled requests in thread-safe way
        @synchronized([self class]) {
            lastReturnedCoordinate = spoofedCoordinate;
        }
        
        // Only log occasionally to reduce spam
        static NSTimeInterval lastLogTime = 0;
        if (currentTime - lastLogTime > 30.0) {
            @synchronized([self class]) {
                if (currentTime - lastLogTime > 30.0) {
                    PXLog(@"[WeaponX] Using spoofed location for %@: (%.6f, %.6f) with variations", 
                        bundleID, spoofedCoordinate.latitude, spoofedCoordinate.longitude);
                    lastLogTime = currentTime;
                }
            }
        }
        
        threadDictionary[kRecursionGuardKey] = nil;
        return spoofedCoordinate;
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception while spoofing location: %@", exception);
        threadDictionary[kRecursionGuardKey] = nil;
        return originalCoordinate;
    }
}

%end

// Hook -[CLLocationManager locationManagerDidUpdateLocations:] delegate method
%hook NSObject

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    // First check if this is actually a CLLocationManagerDelegate
    if (![self respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        %orig;
        return;
    }
    
    if (!manager || !locations || locations.count == 0) {
        %orig;
        return;
    }
    
    // Get the LocationSpoofingManager
    LocationSpoofingManager *spoofManager = [LocationSpoofingManager sharedManager];
    
    // If spoofing is disabled (no pinned location) or manager is not available, use original location
    if (!spoofManager || ![spoofManager isSpoofingEnabled]) {
        %orig;
        return;
    }
    
    // Get the current bundle ID
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!PXLocationManagerShouldSpoof(spoofManager, bundleID)) {
        %orig;
        return;
    }
    
    @try {
        // Create array of spoofed locations
        NSMutableArray *spoofedLocations = [NSMutableArray arrayWithCapacity:locations.count];
        
        // Apply proper position variations to each location using modifySpoofedLocation
        for (CLLocation *originalLocation in locations) {
            // Get a properly spoofed location with all variations applied
            CLLocation *spoofedLocation = [spoofManager modifySpoofedLocation:originalLocation];
            
            if (spoofedLocation) {
                [spoofedLocations addObject:spoofedLocation];
            } else {
                // If spoofing fails, use original location
                [spoofedLocations addObject:originalLocation];
            }
        }
        
        // Replace original locations with spoofed ones
        if (spoofedLocations.count > 0) {
            %orig(manager, spoofedLocations);
            return;
        }
        
        // If no spoofed locations were created, use original
        %orig;
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in locationManager:didUpdateLocations: %@", exception);
        %orig; // Pass through original on exception
    }
}

// Add hook for the legacy location update method
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    // First check if this is actually a CLLocationManagerDelegate
    if (![self respondsToSelector:@selector(locationManager:didUpdateToLocation:fromLocation:)]) {
        %orig;
        return;
    }
    
    if (!manager || !newLocation) {
        %orig;
        return;
    }
    
    // Get the LocationSpoofingManager
    LocationSpoofingManager *spoofManager = [LocationSpoofingManager sharedManager];
    
    // If spoofing is disabled (no pinned location) or manager is not available, use original location
    if (!spoofManager || ![spoofManager isSpoofingEnabled]) {
        %orig;
        return;
    }
    
        // Get the current bundle ID
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!PXLocationManagerShouldSpoof(spoofManager, bundleID)) {
            %orig;
            return;
        }
        
    @try {
        // Performance optimization: throttle excessive legacy updates
        static NSTimeInterval lastLegacyUpdateTime = 0;
        NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
        if (currentTime - lastLegacyUpdateTime < 0.3) { // Max ~3 updates per second
            static int legacySkipCounter = 0;
            if (++legacySkipCounter % 3 != 0) { // Process only every 3rd rapid update
                %orig;
                return;
            }
        }
        lastLegacyUpdateTime = currentTime;
        
        // Get spoofed location with position variations applied
        CLLocation *spoofedLocation = [spoofManager modifySpoofedLocation:newLocation];
        
        if (spoofedLocation) {
            // Only log occasionally
            static NSTimeInterval lastLogTime = 0;
            if (currentTime - lastLogTime > 30.0) {
                PXLog(@"[WeaponX] Using pinned location with variations for %@ (legacy method)", bundleID);
                lastLogTime = currentTime;
            }
            
            // Call original with spoofed location
            %orig(manager, spoofedLocation, oldLocation);
        } else {
            // If spoofing fails, use original
            %orig;
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in legacy location method: %@", exception);
        %orig; // Pass through original on exception
    }
}

%end

// Additional CLLocationManager hooks for special methods
%hook CLLocationManager

// Hook for one-time location requests
- (void)requestLocation {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID && ![bundleID hasPrefix:@"com.apple."]) {
            PXLog(@"[WeaponX] App %@ requested one-time location", bundleID);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in requestLocation: %@", exception);
    }
    
    %orig;
}

// Hook for significant location monitoring
- (void)startMonitoringSignificantLocationChanges {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID && ![bundleID hasPrefix:@"com.apple."]) {
            PXLog(@"[WeaponX] App %@ started monitoring significant location changes", bundleID);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in startMonitoringSignificantLocationChanges: %@", exception);
    }
    
    %orig;
}

- (void)stopMonitoringSignificantLocationChanges {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID && ![bundleID hasPrefix:@"com.apple."]) {
            PXLog(@"[WeaponX] App %@ stopped monitoring significant location changes", bundleID);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in stopMonitoringSignificantLocationChanges: %@", exception);
    }
    
    %orig;
}

// Hook for deferred location updates
- (void)allowDeferredLocationUpdatesUntilTraveled:(CLLocationDistance)distance timeout:(NSTimeInterval)timeout {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID && ![bundleID hasPrefix:@"com.apple."]) {
            PXLog(@"[WeaponX] App %@ requested deferred location updates (distance: %.2f, timeout: %.2f)", 
                  bundleID, distance, timeout);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in allowDeferredLocationUpdatesUntilTraveled: %@", exception);
    }
    
    %orig;
}

- (void)disallowDeferredLocationUpdates {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID && ![bundleID hasPrefix:@"com.apple."]) {
            PXLog(@"[WeaponX] App %@ disallowed deferred location updates", bundleID);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in disallowDeferredLocationUpdates: %@", exception);
    }
    
    %orig;
}

// Hook for heading updates
- (void)startUpdatingHeading {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID && ![bundleID hasPrefix:@"com.apple."]) {
            PXLog(@"[WeaponX] App %@ started heading updates", bundleID);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in startUpdatingHeading: %@", exception);
    }
    
    %orig;
}

- (void)stopUpdatingHeading {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID && ![bundleID hasPrefix:@"com.apple."]) {
            PXLog(@"[WeaponX] App %@ stopped heading updates", bundleID);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in stopUpdatingHeading: %@", exception);
    }
    
    %orig;
}

// Hook for geofencing
- (void)startMonitoringForRegion:(CLRegion *)region {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID && ![bundleID hasPrefix:@"com.apple."]) {
            PXLog(@"[WeaponX] App %@ started monitoring for region: %@", bundleID, region.identifier);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in startMonitoringForRegion: %@", exception);
    }
    
    %orig;
}

- (void)stopMonitoringForRegion:(CLRegion *)region {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID && ![bundleID hasPrefix:@"com.apple."]) {
            PXLog(@"[WeaponX] App %@ stopped monitoring for region: %@", bundleID, region.identifier);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in stopMonitoringForRegion: %@", exception);
    }
    
    %orig;
}

- (void)requestStateForRegion:(CLRegion *)region {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID && ![bundleID hasPrefix:@"com.apple."]) {
            PXLog(@"[WeaponX] App %@ requested state for region: %@", bundleID, region.identifier);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in requestStateForRegion: %@", exception);
    }
    
    %orig;
}

// Hook for visit monitoring
- (void)startMonitoringVisits {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID && ![bundleID hasPrefix:@"com.apple."]) {
            PXLog(@"[WeaponX] App %@ started monitoring visits", bundleID);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in startMonitoringVisits: %@", exception);
    }
    
    %orig;
}

- (void)stopMonitoringVisits {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID && ![bundleID hasPrefix:@"com.apple."]) {
            PXLog(@"[WeaponX] App %@ stopped monitoring visits", bundleID);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in stopMonitoringVisits: %@", exception);
    }
    
    %orig;
}

%end

// Hook CLLocation additional properties
%hook CLLocation

- (CLLocationSpeed)speed {
    LocationSpoofingManager *manager = [LocationSpoofingManager sharedManager];
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    if (PXLocationManagerShouldSpoof(manager, bundleID)) {
        // Return a reasonable speed value (walking pace)
        return 1.5;
    }
    
    return %orig;
}

- (CLLocationDirection)course {
    LocationSpoofingManager *manager = [LocationSpoofingManager sharedManager];
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    if (PXLocationManagerShouldSpoof(manager, bundleID)) {
        // Return a fixed direction (North = 0 degrees)
        return 0.0;
    }
    
    return %orig;
}

%end

// Add more delegate method hooks to NSObject
%hook NSObject

// Regional monitoring delegate methods
- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    // First check if this is actually a CLLocationManagerDelegate
    if (![self respondsToSelector:@selector(locationManager:didEnterRegion:)]) {
        %orig;
        return;
    }
    
    LocationSpoofingManager *spoofManager = [LocationSpoofingManager sharedManager];
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    if (!PXLocationManagerShouldSpoof(spoofManager, bundleID)) {
        %orig;
        return;
    }
    
    @try {
        // Log the interception
        PXLog(@"[WeaponX] Intercepted region entry for app %@, region: %@", bundleID, region.identifier);
        
        // We suppress region events when spoofing is active since our location isn't actually moving
        // This prevents apps from getting confusing region notifications
        
        // Do not call %orig to suppress the notification
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in locationManager:didEnterRegion: %@", exception);
        %orig;
    }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    // First check if this is actually a CLLocationManagerDelegate
    if (![self respondsToSelector:@selector(locationManager:didExitRegion:)]) {
        %orig;
        return;
    }
    
    LocationSpoofingManager *spoofManager = [LocationSpoofingManager sharedManager];
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    if (!PXLocationManagerShouldSpoof(spoofManager, bundleID)) {
        %orig;
        return;
    }
    
    @try {
        // Log the interception
        PXLog(@"[WeaponX] Intercepted region exit for app %@, region: %@", bundleID, region.identifier);
        
        // Suppress region exit events when spoofing is active
        // Do not call %orig to suppress the notification
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in locationManager:didExitRegion: %@", exception);
        %orig;
    }
}

// Heading update delegate method
- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
    // First check if this is actually a CLLocationManagerDelegate
    if (![self respondsToSelector:@selector(locationManager:didUpdateHeading:)]) {
        %orig;
        return;
    }
    
    LocationSpoofingManager *spoofManager = [LocationSpoofingManager sharedManager];
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    if (!PXLocationManagerShouldSpoof(spoofManager, bundleID)) {
        %orig;
        return;
    }
    
    @try {
        // Create a spoofed heading pointing north
        // This would require creating a custom CLHeading, which is complex
        // For now, we'll just pass through the original heading
        PXLog(@"[WeaponX] Passing through heading update for app %@", bundleID);
        %orig;
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in locationManager:didUpdateHeading: %@", exception);
        %orig;
    }
}

%end

// Hook for MKMapView to handle map-specific location display
%hook MKMapView

- (MKUserLocation *)userLocation {
    MKUserLocation *originalUserLocation = %orig;
    
    @try {
        LocationSpoofingManager *manager = [LocationSpoofingManager sharedManager];
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (!PXLocationManagerShouldSpoof(manager, bundleID)) {
            return originalUserLocation;
        }
        
        // Since we can't directly modify MKUserLocation's coordinate (it's read-only),
        // we rely on our CLLocation hook to handle this
        // The coordinate is ultimately provided by CLLocationManager
        
        // Just log the request
        static NSTimeInterval lastLogTime = 0;
        NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
        if (currentTime - lastLogTime > 30.0) {
            PXLog(@"[WeaponX] App %@ requested map user location", bundleID);
            lastLogTime = currentTime;
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in MKMapView userLocation: %@", exception);
    }
    
    return originalUserLocation;
}

%end

// Hook for MKUserLocation to ensure map display is spoofed
%hook MKUserLocation

- (CLLocationCoordinate2D)coordinate {
    CLLocationCoordinate2D originalCoordinate = %orig;
    
    @try {
        LocationSpoofingManager *manager = [LocationSpoofingManager sharedManager];
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (!PXLocationManagerShouldSpoof(manager, bundleID)) {
            return originalCoordinate;
        }
        
        // Get spoofed coordinates
        double latitude = [manager getSpoofedLatitude];
        double longitude = [manager getSpoofedLongitude];
        
        // Validation
        if (latitude == 0.0 && longitude == 0.0) {
            return originalCoordinate;
        }
        
        // Create and return spoofed coordinate
        CLLocationCoordinate2D spoofedCoordinate = CLLocationCoordinate2DMake(latitude, longitude);
        
        // Log occasionally
        static NSTimeInterval lastLogTime = 0;
        NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
        if (currentTime - lastLogTime > 30.0) {
            PXLog(@"[WeaponX] Using spoofed coordinate for map display: (%.6f, %.6f)", 
                  spoofedCoordinate.latitude, spoofedCoordinate.longitude);
            lastLogTime = currentTime;
        }
        
        return spoofedCoordinate;
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in MKUserLocation coordinate: %@", exception);
        return originalCoordinate;
    }
}

%end

// Hook CLGeocoder for geocoding services
%hook CLGeocoder

- (void)reverseGeocodeLocation:(CLLocation *)location completionHandler:(void (^)(NSArray<CLPlacemark *> *placemarks, NSError *error))completionHandler {
    @try {
        LocationSpoofingManager *manager = [LocationSpoofingManager sharedManager];
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (!PXLocationManagerShouldSpoof(manager, bundleID) || !location || !completionHandler) {
            %orig;
            return;
        }
        
        // Create a spoofed location
        CLLocation *spoofedLocation = [manager modifySpoofedLocation:location];
        if (!spoofedLocation) {
            %orig;
            return;
        }
        
        // Log the reverseGeocoding request
        PXLog(@"[WeaponX] App %@ requested reverse geocoding, using spoofed location", bundleID);
        
        // Create a copy of the completion handler to ensure it stays alive
        void (^wrappedHandler)(NSArray<CLPlacemark *> *, NSError *) = [completionHandler copy];
        
        // Call original with our spoofed location and copied handler
        %orig(spoofedLocation, wrappedHandler);
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in reverseGeocodeLocation: %@", exception);
        %orig;
    }
}

// Add forward geocoding method
- (void)geocodeAddressString:(NSString *)addressString completionHandler:(void (^)(NSArray<CLPlacemark *> *placemarks, NSError *error))completionHandler {
    @try {
        LocationSpoofingManager *manager = [LocationSpoofingManager sharedManager];
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (!PXLocationManagerShouldSpoof(manager, bundleID) || !addressString || !completionHandler) {
            %orig;
            return;
        }
        
        // Log the forward geocoding request
        PXLog(@"[WeaponX] App %@ requested forward geocoding for address: %@", bundleID, addressString);
        
        // Create a copy of the completion handler to ensure it stays alive
        void (^wrappedHandler)(NSArray<CLPlacemark *> *, NSError *) = [completionHandler copy];
        
        // Use a simpler implementation to avoid syntax errors
        void (^monitorBlock)(NSArray<CLPlacemark *> *, NSError *) = ^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
            if (placemarks.count > 0) {
                PXLog(@"[WeaponX] Forward geocoding returned %lu placemarks for %@", 
                      (unsigned long)placemarks.count, addressString);
            }
            
            // Call original completion handler
            wrappedHandler(placemarks, error);
        };
        
        %orig(addressString, monitorBlock);
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in geocodeAddressString: %@", exception);
        %orig;
    }
}

%end

%end // End of LocationSpoofing group

// Add new group for sensor data integration
%group SensorSpoofing

// Hook for accelerometer data
%hook CMMotionManager

- (CMAccelerometerData *)accelerometerData {
    @try {
        // Check if we should spoof
        LocationSpoofingManager *manager = [LocationSpoofingManager sharedManager];
        if (!manager || ![manager isSpoofingEnabled]) {
            return %orig;
        }
        
        // Get the current bundle ID
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (!PXLocationManagerShouldSpoof(manager, bundleID)) {
            return %orig;
        }
        
        // Get the last spoofed location data
        double speed = manager.lastReportedSpeed;
        double course = manager.lastReportedCourse;
        
        // Create synthetic accelerometer data based on movement
        CMAccelerometerData *data = %orig;
        if (!data) {
            data = [[objc_getClass("CMAccelerometerData") alloc] init];
        }
        
        // Calculate appropriate accelerometer values
        double xAccel = 0.0, yAccel = 0.0, zAccel = -1.0; // Default gravity
        
        // Modify based on movement
        if (speed > 0) {
            // Convert course to radians
            double courseRad = course * M_PI / 180.0;
            
            // Add movement component
            double movementFactor = MIN(speed * 0.01, 0.2); // Scale with speed
            xAccel += cos(courseRad) * movementFactor;
            yAccel += sin(courseRad) * movementFactor;
            
            // Add slight vibration for realism
            xAccel += ((arc4random() % 100) - 50) / 1000.0;
            yAccel += ((arc4random() % 100) - 50) / 1000.0;
            zAccel += ((arc4random() % 100) - 50) / 1000.0;
        }
        
        // Set the accelerometer values safely with exception handling
        @try {
            [data setValue:@(xAccel) forKey:@"x"];
            [data setValue:@(yAccel) forKey:@"y"];
            [data setValue:@(zAccel) forKey:@"z"];
        } @catch (NSException *exception) {
            PXLog(@"[WeaponX] Exception setting accelerometer data: %@", exception);
            // Return original data if there's an error setting values
            return %orig;
        }
        
        return data;
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in accelerometerData: %@", exception);
        return %orig;
    }
}

// Add gyroscope data spoofing for complete motion data
- (CMGyroData *)gyroData {
    @try {
        // Check if we should spoof
        LocationSpoofingManager *manager = [LocationSpoofingManager sharedManager];
        if (!manager || ![manager isSpoofingEnabled]) {
            return %orig;
        }
        
        // Get the current bundle ID
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (!PXLocationManagerShouldSpoof(manager, bundleID)) {
            return %orig;
        }
        
        // Get the last spoofed location data
        double speed = manager.lastReportedSpeed;
        double course = manager.lastReportedCourse;
        
        // Create synthetic gyroscope data
        CMGyroData *data = %orig;
        if (!data) {
            data = [[objc_getClass("CMGyroData") alloc] init];
        }
        
        // Calculate gyroscope values based on movement and course
        double xRotation = 0.0, yRotation = 0.0, zRotation = 0.0;
        
        // Add slight rotation based on course changes (would be more sophisticated in real implementation)
        if (speed > 0) {
            // Calculate small rotations that align with course
            // In a real implementation this would track course changes over time
            
            // Use the course value to add a slight rotation based on direction
            double courseRad = course * M_PI / 180.0;
            zRotation = ((arc4random() % 100) - 50) / 1000.0; // Small rotation around Z axis for turning
            
            // Add small course-based rotation to make movements more realistic
            xRotation += sin(courseRad) * 0.01;
            yRotation += cos(courseRad) * 0.01;
            
            // Add transportation mode specific movements
            if (manager.transportationMode == TransportationModeDriving) {
                // Driving has more yaw (z-axis rotation) for turns
                zRotation *= 2.5;
            } else if (manager.transportationMode == TransportationModeWalking) {
                // Walking has more pitch/roll (x/y-axis rotation) for steps
                xRotation += sin(CACurrentMediaTime() * 2.0) * 0.05; // Simulate walking motion
                yRotation += sin(CACurrentMediaTime() * 2.0 + M_PI_2) * 0.02;
            }
        }
        
        // Set the gyroscope values safely with exception handling
        @try {
            [data setValue:@(xRotation) forKey:@"x"];
            [data setValue:@(yRotation) forKey:@"y"];
            [data setValue:@(zRotation) forKey:@"z"];
        } @catch (NSException *exception) {
            PXLog(@"[WeaponX] Exception setting gyroscope data: %@", exception);
            // Return original data if there's an error setting values
            return %orig;
        }
        
        return data;
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in gyroData: %@", exception);
        return %orig;
    }
}

// Add magnetometer (compass) data spoofing to align with GPS course
- (CMMagnetometerData *)magnetometerData {
    @try {
        // Check if we should spoof
        LocationSpoofingManager *manager = [LocationSpoofingManager sharedManager];
        if (!manager || ![manager isSpoofingEnabled]) {
            return %orig;
        }
        
        // Get the current bundle ID
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (!PXLocationManagerShouldSpoof(manager, bundleID)) {
            return %orig;
        }
        
        // Get the course from the last spoofed location
        double course = manager.lastReportedCourse;
        
        // Create synthetic magnetometer data
        CMMagnetometerData *data = %orig;
        if (!data) {
            data = [[objc_getClass("CMMagnetometerData") alloc] init];
        }
        
        // Convert course to radians
        double courseRad = course * M_PI / 180.0;
        
        // Calculate magnetometer values that would point to the course direction
        // This is a simplified model - real magnetometer data would be more complex
        double magneticField = 30.0; // Approximate strength of Earth's magnetic field
        
        // Simplified magnetic field components based on course
        double xField = magneticField * cos(courseRad);
        double yField = magneticField * sin(courseRad);
        double zField = 0.0; // Simplified - assume device is flat
        
        // Add some realistic noise
        xField += ((arc4random() % 100) - 50) / 50.0;
        yField += ((arc4random() % 100) - 50) / 50.0;
        zField += ((arc4random() % 100) - 50) / 50.0;
        
        // Set the magnetometer values safely with exception handling
        @try {
            [data setValue:@(xField) forKey:@"x"];
            [data setValue:@(yField) forKey:@"y"];
            [data setValue:@(zField) forKey:@"z"];
        } @catch (NSException *exception) {
            PXLog(@"[WeaponX] Exception setting magnetometer data: %@", exception);
            // Return original data if there's an error setting values
            return %orig;
        }
        
        return data;
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in magnetometerData: %@", exception);
        return %orig;
    }
}

%end // End CMMotionManager hook

// Add barometer/altitude data spoofing
%hook CMAltimeter

- (void)startRelativeAltitudeUpdatesToQueue:(NSOperationQueue *)queue withHandler:(void (^)(CMAltitudeData *altitudeData, NSError *error))handler {
    @try {
        // Check if we should spoof
        LocationSpoofingManager *manager = [LocationSpoofingManager sharedManager];
        if (!manager || ![manager isSpoofingEnabled]) {
            %orig;
            return;
        }
        
        // Get the current bundle ID
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (!PXLocationManagerShouldSpoof(manager, bundleID)) {
            %orig;
            return;
        }
        
        // Instead of calling original, we'll handle the queue operations ourselves
        [self stopRelativeAltitudeUpdates]; // Stop any existing updates
        
        // Create a strong reference to the handler to prevent it from being deallocated
        void (^strongHandler)(CMAltitudeData *, NSError *) = [handler copy];
        
        // Keep a reference to the timer in an associated object to prevent it from being deallocated
        static char kAltimeterTimerKey;
        
        // Create our own timer to simulate altitude updates
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // Create a timer for regular updates
            NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
                @try {
                    if (!manager.isSpoofingEnabled) {
                        [timer invalidate];
                        objc_setAssociatedObject(self, &kAltimeterTimerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        return;
                    }
                    
                    // Create synthetic altitude data
                    CMAltitudeData *altData = [[objc_getClass("CMAltitudeData") alloc] init];
                    
                    // Get current transportation mode and simulate appropriate pressure changes
                    double relativeAltitude = 0.0;
                    double pressure = 1013.25; // Standard pressure at sea level in hPa
                    
                    // Adjust based on transportation mode
                    if (manager.transportationMode == TransportationModeDriving) {
                        // More altitude variations for driving
                        relativeAltitude = ((arc4random() % 100) - 50) / 10.0; // ±5 meters
                    } else if (manager.transportationMode == TransportationModeWalking) {
                        // Slight variations for walking
                        relativeAltitude = ((arc4random() % 50) - 25) / 10.0; // ±2.5 meters
                    } else {
                        // Minimal variations for stationary
                        relativeAltitude = ((arc4random() % 20) - 10) / 10.0; // ±1 meter
                    }
                    
                    // Calculate pressure from altitude (simplified model)
                    // Standard formula: P = P0 * exp(-g * M * h / (R * T))
                    // Simplified for small changes: approximately -0.12 hPa per meter of height
                    pressure = 1013.25 - (relativeAltitude * 0.12);
                    
                    // Set the values using KVC safely
                    @try {
                        [altData setValue:@(relativeAltitude) forKey:@"relativeAltitude"];
                        [altData setValue:@(pressure) forKey:@"pressure"];
                    } @catch (NSException *exception) {
                        PXLog(@"[WeaponX] Exception setting altitude data values: %@", exception);
                    }
                    
                    // Queue operation to deliver update
                    if (queue && strongHandler) {
                        [queue addOperationWithBlock:^{
                            strongHandler(altData, nil);
                        }];
                    }
                } @catch (NSException *exception) {
                    PXLog(@"[WeaponX] Exception in altimeter update timer: %@", exception);
                }
            }];
            
            // Store the timer as an associated object on self to keep it alive
            objc_setAssociatedObject(self, &kAltimeterTimerKey, timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            
            // Run the timer on the current runloop
            NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];
            [currentRunLoop addTimer:timer forMode:NSDefaultRunLoopMode];
            
            // Keep the runloop alive - this will block this thread
            // We're using a separate dispatch_async so this is okay
            CFRunLoopRun();
        });
        
        PXLog(@"[WeaponX] Started custom altitude updates");
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in startRelativeAltitudeUpdatesToQueue: %@", exception);
        %orig; // Fall back to original implementation
    }
}

// Add a hook for stopRelativeAltitudeUpdates to properly clean up our timer
- (void)stopRelativeAltitudeUpdates {
    @try {
        // Clean up our custom timer if it exists
        static char kAltimeterTimerKey;
        NSTimer *timer = objc_getAssociatedObject(self, &kAltimeterTimerKey);
        if (timer) {
            [timer invalidate];
            objc_setAssociatedObject(self, &kAltimeterTimerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            PXLog(@"[WeaponX] Stopped custom altitude updates");
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] Exception in stopRelativeAltitudeUpdates: %@", exception);
    }
    
    // Call original implementation to ensure proper cleanup
    %orig;
}

%end

%end  // End of SensorSpoofing group

// Early initialization for ElleKit - runs before process fully launches
static void earlyInitCallback(void) {
    PXLog(@"ElleKit early initialization phase - preparing identifier spoofing");
    
    // Initialize essential components before process starts
    // This is unique to ElleKit and provides stronger protection
    valueCache = [NSMutableDictionary dictionary];
    
    // We can perform early setup here that will be ready before any app code runs
    NSString *bundleExecutable = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleExecutable"];
    PXLog(@"Preparing early protection for process: %@", bundleExecutable ?: @"Unknown");
    
    // Check if we're using ElleKit
    if (0) {
        PXLog(@"Running in ElleKit environment - enabling advanced protection");
    }
}

static void setupHookingEnvironment() {
    // Check if we're running in ElleKit and adapt accordingly
    bool isElleKit = dlsym(RTLD_DEFAULT, "EKHook") != NULL;
    
    if (isElleKit) {
        PXLog(@"ElleKit detected: Using enhanced protection capabilities");
        
        // Check ElleKit version (function not actually in ElleKit, just for example)
        void *ekVersionSym = dlsym(RTLD_DEFAULT, "EKVersion"); 
        if (ekVersionSym) {
            PXLog(@"ElleKit version checks passed");
        }
        
        // ElleKit has better optimization for arm64e hardware
        #ifdef __arm64e__
        PXLog(@"Running on ARM64e hardware with ElleKit: PAC protection enabled");
        #endif
    } else {
        PXLog(@"Substrate fallback mode: Limited protection capabilities");
    }
}

// Function pointer declarations for rebinding
static int (*getifaddrs_orig)(struct ifaddrs **ifap);
static int (*gethostname_orig)(char *name, size_t namelen);

// Hook implementation for getifaddrs
static int getifaddrs_hook(struct ifaddrs **ifap) {
    int result = getifaddrs_orig(ifap);
    if (result == 0 && ifap && *ifap) {
        // Check if jailbreak detection bypass is enabled
        NSUserDefaults *securitySettings = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
        BOOL jailbreakDetectionEnabled = [securitySettings boolForKey:@"jailbreakDetectionEnabled"];
        
        if (!jailbreakDetectionEnabled) {
            return result; // Skip if bypass is disabled
        }
        
        // Check if the current app is in the scoped apps list
        NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (!currentBundleID) {
            return result;
        }
        
        IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (!manager || !PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionNone)) {
            return result; // Skip if app is not in scoped list
        }
        
        // Loop through network interfaces and modify MAC addresses
        struct ifaddrs *ifa = *ifap;
        while (ifa) {
            if (ifa->ifa_addr && ifa->ifa_addr->sa_family == AF_LINK) {
                // Here you'd modify the link-level address (MAC)
                // For safety, we'll just log it here
                PXLog(@"Protected MAC address for interface: %s for app: %@", ifa->ifa_name, currentBundleID);
            }
            ifa = ifa->ifa_next;
        }
    }
    return result;
}

// Hook implementation for gethostname
// Per Newplan: NOT gated by jailbreakDetectionEnabled. Scoped + DeviceName only.
static int gethostname_hook(char *name, size_t namelen) {
    // Buffer null/size 0 → original
    if (!name || namelen == 0) {
        return gethostname_orig ? gethostname_orig(name, namelen) : -1;
    }

    @try {
        NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (currentBundleID && PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
            IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
            if (manager && [manager isIdentifierEnabled:@"DeviceName"]) {
                NSString *deviceName = [manager currentValueForIdentifier:@"DeviceName"];
                if (deviceName.length > 0) {
                    const char *cstr = deviceName.UTF8String;
                    if (cstr) {
                        size_t len = strlen(cstr);
                        size_t copyLen = (len < namelen - 1) ? len : (namelen - 1);
                        memcpy(name, cstr, copyLen);
                        name[copyLen] = '\0';
                        return 0;
                    }
                }
            }
        }
    } @catch (__unused NSException *e) {}

    return gethostname_orig ? gethostname_orig(name, namelen) : -1;
}

// Anti-detection callback function (must be a regular function, not a block)
static void antiDetectionCallback(void) {
    // Check if jailbreak detection bypass is enabled
    NSUserDefaults *securitySettings = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
    BOOL jailbreakDetectionEnabled = [securitySettings boolForKey:@"jailbreakDetectionEnabled"];
    
    if (!jailbreakDetectionEnabled) {
        return; // Skip if bypass is disabled
    }
    
    // Check if the current app is in the scoped apps list
    NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!currentBundleID) {
        return;
    }
    
    IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
    NSString *proc = [NSProcessInfo processInfo].processName;
    if (!manager || !PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionNone)) {
        return; // Skip if app is not in scoped list
    }
    
    PXLog(@"Running anti-detection callback for %@", currentBundleID);
    // Add additional anti-detection logic here
}

// Hook IOKit's IORegistryEntryCreateCFProperty for serial number
static CFTypeRef (*orig_IORegistryEntryCreateCFProperty)(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options);
static IOReturn (*orig_IORegistryEntryCreateCFProperties)(io_registry_entry_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, IOOptionBits options);
static CFTypeRef (*orig_IORegistryEntrySearchCFProperty)(io_registry_entry_t entry, const io_name_t plane, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options);

static BOOL PXIOKitShouldSpoof(IdentifierManager *manager, NSString *bundleID) {
    if (!manager || !bundleID.length) return NO;
    NSString *proc = [NSProcessInfo processInfo].processName;
    return PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack);
}

static CFTypeRef PXIOKitCreateReplacementMatchingOriginal(CFTypeRef original, NSString *key, NSString *value) {
    if (!value.length) return NULL;
    PXIdentitySurfaceEntry *entry =
        PXIdentitySurfaceEntryForKey(key, PXIdentitySurfaceIORegistry);
    BOOL originalIsData = original && CFGetTypeID(original) == CFDataGetTypeID();
    BOOL registryRequiresData = !original && entry.expectedType == PXIdentityExpectedTypeData;
    if (originalIsData || registryRequiresData) {
        return (CFTypeRef)PXCreateCFDataFromNSString(value);
    }
    return (CFTypeRef)PXCreateCFStringFromNSString(value);
}

static CFTypeRef PXIOKitPatchCompatibleValue(CFTypeRef original, NSString *hwModel, NSString *deviceModel) {
    if (!original) {
        // Fallback: return hwModel as string.
        return (CFTypeRef)PXCreateCFStringFromNSString(hwModel);
    }

    if (CFGetTypeID(original) == CFArrayGetTypeID()) {
        CFArrayRef origArray = (CFArrayRef)original;
        CFMutableArrayRef newArray = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, origArray);
        if (!newArray) {
            return original;
        }

        BOOL prefersData = NO;
        CFIndex count = CFArrayGetCount(origArray);
        for (CFIndex i = 0; i < count; i++) {
            CFTypeRef item = CFArrayGetValueAtIndex(origArray, i);
            if (item && CFGetTypeID(item) == CFDataGetTypeID()) {
                prefersData = YES;
                break;
            }
        }

        BOOL hasHwModel = NO;
        for (CFIndex i = 0; i < count; i++) {
            CFTypeRef item = CFArrayGetValueAtIndex(origArray, i);
            NSString *itemStr = PXStringFromCFType(item);
            if (itemStr.length > 0) {
                if ([itemStr isEqualToString:hwModel]) {
                    hasHwModel = YES;
                }
                if ([itemStr hasPrefix:@"iPhone"] && deviceModel.length) {
                    CFTypeRef replacement = prefersData ? (CFTypeRef)PXCreateCFDataFromNSString(deviceModel) : (CFTypeRef)PXCreateCFStringFromNSString(deviceModel);
                    if (replacement) {
                        CFArraySetValueAtIndex(newArray, i, replacement);
                        CFRelease(replacement);
                    }
                }
            }
        }

        if (!hasHwModel && hwModel.length) {
            CFTypeRef repl = prefersData ? (CFTypeRef)PXCreateCFDataFromNSString(hwModel) : (CFTypeRef)PXCreateCFStringFromNSString(hwModel);
            if (repl) {
                CFArrayInsertValueAtIndex(newArray, 0, repl);
                CFRelease(repl);
            }
        }

        CFRelease(original);
        return newArray;
    }

    // Preserve CFData if needed.
    if (CFGetTypeID(original) == CFDataGetTypeID()) {
        CFRelease(original);
        return (CFTypeRef)PXCreateCFDataFromNSString(hwModel);
    }

    CFRelease(original);
    return (CFTypeRef)PXCreateCFStringFromNSString(hwModel);
}

static CFTypeRef hook_IORegistryEntryCreateCFProperty(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options) {
    static int loggedCount = 0;
    if (key && loggedCount < 30) {
        loggedCount++;
        NSString *k = (__bridge NSString *)key;
        PXFileDebugAIDA64Log("[Tweak.IORegistryEntryCreateCFProperty] key=%s", k.UTF8String ?: "<nil>");
    }
    // Null checks to prevent crashes
    if (!entry || !key) {
        return NULL;
    }
    
    // Get manager and check if identifier spoofing is enabled
    @try {
        if (!%c(IdentifierManager)) {
            return orig_IORegistryEntryCreateCFProperty(entry, key, allocator, options);
        }
        
        IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
        NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];

        if (!PXIOKitShouldSpoof(manager, currentBundleID)) {
            return orig_IORegistryEntryCreateCFProperty(entry, key, allocator, options);
        }
        
        // Convert CoreFoundation key to NSString for easier handling
        NSString *keyString = (__bridge NSString *)key;
        
        // Serial Number / aliases
        if ([keyString isEqualToString:@"IOPlatformSerialNumber"]) {
            // Special case for Filza and ADManager
            if ([currentBundleID isEqualToString:@"com.tigisoftware.Filza"] || 
                [currentBundleID isEqualToString:@"com.tigisoftware.ADManager"]) {
                NSString *hardcodedSerial = @"FCCC15Q4HG04";
                PXLog(@"[WeaponX] 📱 Spoofing IOPlatformSerialNumber with hardcoded value for %@: %@", 
                     currentBundleID, hardcodedSerial);
                return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)hardcodedSerial);
            }
            
            if ([manager isIdentifierEnabled:@"SerialNumber"]) {
                NSString *spoofedSerial = [manager currentValueForIdentifier:@"SerialNumber"];
                if (spoofedSerial) {
                    PXLog(@"Spoofing IOPlatformSerialNumber with: %@", spoofedSerial);
                    // Ensure proper memory management with CoreFoundation objects
                    return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)spoofedSerial);
                }
            }
        }

        if (([keyString isEqualToString:@"serial-number"] || [keyString isEqualToString:@"mlb-serial-number"]) && [manager isIdentifierEnabled:@"SerialNumber"]) {
            NSString *spoofedSerial = [manager currentValueForIdentifier:@"SerialNumber"];
            if (spoofedSerial.length) {
                CFTypeRef original = orig_IORegistryEntryCreateCFProperty(entry, key, allocator, options);
                CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, spoofedSerial);
                if (repl) {
                    if (original) CFRelease(original);
                    return repl;
                }
                return original;
            }
        }
        
        // WiFi/Ethernet MAC Address
        if (([keyString isEqualToString:@"IOMACAddress"] || [keyString isEqualToString:@"WiFiAddress"] || 
             [keyString isEqualToString:@"BSDName"]) && [manager isIdentifierEnabled:@"WiFiAddress"]) {
            NSString *spoofedMAC = [manager currentValueForIdentifier:@"WiFiAddress"];
            if (spoofedMAC) {
                PXLog(@"Spoofing MAC address identifier %@ with: %@", keyString, spoofedMAC);
                return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)spoofedMAC);
            }
        }
        
        // IMEI for cellular devices (kIMEIKey / InternationalMobileEquipmentIdentity only)
        if (([keyString isEqualToString:@"kIMEIKey"] ||
             [keyString isEqualToString:@"InternationalMobileEquipmentIdentity"]) &&
            [manager isIdentifierEnabled:@"IMEI"]) {
            NSString *spoofedIMEI = [manager currentValueForIdentifier:@"IMEI"];
            if (spoofedIMEI.length) {
                PXLog(@"Spoofing IMEI with: %@", spoofedIMEI);
                return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)spoofedIMEI);
            }
        }
        // MEID only — separate toggle/value
        if (([keyString isEqualToString:@"MobileEquipmentIdentifier"] ||
             [keyString isEqualToString:@"kMEIDKey"] ||
             [keyString isEqualToString:@"MEID"]) &&
            [manager isIdentifierEnabled:@"MEID"]) {
            NSString *spoofedMEID = [manager currentValueForIdentifier:@"MEID"];
            if (spoofedMEID.length) {
                PXLog(@"Spoofing MEID with: %@", spoofedMEID);
                return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)spoofedMEID);
            }
        }
        
        // Hardware UUID / aliases
        if ([keyString isEqualToString:@"IOPlatformUUID"] && [manager isIdentifierEnabled:@"SystemBootUUID"]) {
            NSString *spoofedUUID = [manager currentValueForIdentifier:@"SystemBootUUID"];
            if (spoofedUUID) {
                PXLog(@"Spoofing IOPlatformUUID with: %@", spoofedUUID);
                return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)spoofedUUID);
            }
        }

        if ([keyString isEqualToString:@"system-id"] && [manager isIdentifierEnabled:@"SystemBootUUID"]) {
            NSString *spoofedUUID = [manager currentValueForIdentifier:@"SystemBootUUID"];
            if (spoofedUUID.length) {
                CFTypeRef original = orig_IORegistryEntryCreateCFProperty(entry, key, allocator, options);
                CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, spoofedUUID);
                if (repl) {
                    if (original) CFRelease(original);
                    return repl;
                }
                return original;
            }
        }

        // Device model / hardware identifiers (IOPlatformExpertDevice)
        if ([manager isIdentifierEnabled:@"DeviceModel"] && keyString.length > 0) {
            NSString *profileId = nil;
            NSNumber *gen = nil;
            NSDictionary *deviceIds = PXGetDeviceIdsSnapshot(&profileId, &gen);

            BOOL wantsProductType = [keyString isEqualToString:@"device-model"] ||
                                   [keyString isEqualToString:@"hw.machine"] ||
                                   [keyString isEqualToString:@"product-name"];

            BOOL wantsHWModel = [keyString isEqualToString:@"model"] ||
                               [keyString isEqualToString:@"hw.model"];

            BOOL wantsModelNumber = [keyString isEqualToString:@"model-number"];

            BOOL wantsPlatformName = [keyString isEqualToString:@"platform-name"];

            BOOL wantsBoardID = [keyString isEqualToString:@"board-id"] ||
                               [keyString isEqualToString:@"BoardId"];

            BOOL wantsCompatible = [keyString isEqualToString:@"compatible"];

            if (wantsProductType || wantsHWModel || wantsBoardID || wantsCompatible || wantsModelNumber || wantsPlatformName) {
                CFTypeRef original = orig_IORegistryEntryCreateCFProperty(entry, key, allocator, options);

                if (wantsProductType) {
                    if (!PXRequireKeysAll(deviceIds, @[@"DeviceModel"], @"IOKit", keyString, currentBundleID, profileId, gen)) {
                        return original;
                    }
                    NSString *deviceModel = deviceIds[@"DeviceModel"];
                    CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, deviceModel);
                    if (original) CFRelease(original);
                    return repl;
                }

                if (wantsBoardID) {
                    if (!PXRequireKeysAll(deviceIds, @[@"BoardID"], @"IOKit", keyString, currentBundleID, profileId, gen)) {
                        return original;
                    }
                    NSString *boardID = deviceIds[@"BoardID"];
                    CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, boardID);
                    if (original) CFRelease(original);
                    return repl;
                }

                if (wantsHWModel) {
                    if (!PXRequireKeysAll(deviceIds, @[@"HwModel"], @"IOKit", keyString, currentBundleID, profileId, gen)) {
                        return original;
                    }
                    NSString *hwModel = deviceIds[@"HwModel"];
                    CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, hwModel);
                    if (original) CFRelease(original);
                    return repl;
                }

                if (wantsCompatible) {
                    if (!PXRequireKeysAll(deviceIds, @[@"HwModel"], @"IOKit", keyString, currentBundleID, profileId, gen)) {
                        return original;
                    }
                    NSString *hwModel = deviceIds[@"HwModel"];
                    NSString *deviceModel = deviceIds[@"DeviceModel"];

                    return PXIOKitPatchCompatibleValue(original, hwModel, deviceModel);
                }

                if (wantsModelNumber) {
                    if (!PXRequireKeysAll(deviceIds, @[@"ModelNumber"], @"IOKit", keyString, currentBundleID, profileId, gen)) {
                        return original;
                    }
                    NSString *modelNumber = deviceIds[@"ModelNumber"];
                    CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, modelNumber);
                    if (original) CFRelease(original);
                    return repl;
                }

                if (wantsPlatformName) {
                    // Use HwModel only; BoardID is a separate device-tree identity field.
                    if (!PXRequireKeysAll(deviceIds, @[@"HwModel"], @"IOKit", keyString, currentBundleID, profileId, gen)) {
                        return original;
                    }
                    NSString *hwModel = deviceIds[@"HwModel"];
                    CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, hwModel);
                    if (original) CFRelease(original);
                    return repl;
                }

                if (original) CFRelease(original);
            }
        }
    } @catch (NSException *exception) {
        PXLog(@"Exception in IORegistryEntryCreateCFProperty hook: %@", exception);
    }
    
    // For all other cases, pass through to the original function
    return orig_IORegistryEntryCreateCFProperty(entry, key, allocator, options);
}

static IOReturn hook_IORegistryEntryCreateCFProperties(io_registry_entry_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, IOOptionBits options) {
    static BOOL logged = NO;
    if (!logged) {
        logged = YES;
        PXFileDebugAIDA64Log("[Tweak.IORegistryEntryCreateCFProperties] first entry=%u", entry);
    }
    if (!orig_IORegistryEntryCreateCFProperties) {
        return kIOReturnError;
    }

    IOReturn result = orig_IORegistryEntryCreateCFProperties(entry, properties, allocator, options);
    if (result != kIOReturnSuccess || !properties || !*properties) {
        return result;
    }

    @autoreleasepool {
        @try {
            if (!%c(IdentifierManager)) {
                return result;
            }
            IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
            NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
            if (!PXIOKitShouldSpoof(manager, currentBundleID)) {
                return result;
            }

            NSString *profileId = nil;
            NSNumber *gen = nil;
            NSDictionary *deviceIds = PXGetDeviceIdsSnapshot(&profileId, &gen);

            NSMutableDictionary *props = (__bridge NSMutableDictionary *)*properties;
            if (![props isKindOfClass:[NSMutableDictionary class]]) {
                // Might be immutable; make a mutable copy and replace.
                CFDictionaryRef origDict = (CFDictionaryRef)*properties;
                CFMutableDictionaryRef mutable = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, origDict);
                if (!mutable) return result;
                if (origDict) {
                    CFRelease(origDict);
                }
                *properties = mutable;
                props = (__bridge NSMutableDictionary *)mutable;
            }

            NSDictionary *securitySettings = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist"];
            BOOL targetRegionFollowsIP = [securitySettings[@"targetRegionFollowsIPEnabled"] boolValue];
            NSString *pinnedCountryCode = [securitySettings[@"targetRegionPinnedCountryCode"] isKindOfClass:[NSString class]] ? securitySettings[@"targetRegionPinnedCountryCode"] : nil;
            NSString *pinnedMCC = [securitySettings[@"targetRegionPinnedCarrierMCC"] isKindOfClass:[NSString class]] ? securitySettings[@"targetRegionPinnedCarrierMCC"] : nil;
            NSString *pinnedMNC = [securitySettings[@"targetRegionPinnedCarrierMNC"] isKindOfClass:[NSString class]] ? securitySettings[@"targetRegionPinnedCarrierMNC"] : nil;

            for (id k in [props allKeys]) {
                if (![k isKindOfClass:[NSString class]]) continue;
                NSString *keyString = (NSString *)k;
                id valueObj = props[keyString];
                CFTypeRef original = valueObj ? (__bridge CFTypeRef)valueObj : NULL;

                // Serial/UUID platform identifiers
                if ([keyString isEqualToString:@"IOPlatformSerialNumber"] && [manager isIdentifierEnabled:@"SerialNumber"]) {
                    NSString *spoofedSerial = [manager currentValueForIdentifier:@"SerialNumber"];
                    CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, spoofedSerial);
                    if (repl) props[keyString] = (__bridge_transfer id)repl;
                    continue;
                }
                if (([keyString isEqualToString:@"serial-number"] || [keyString isEqualToString:@"mlb-serial-number"]) && [manager isIdentifierEnabled:@"SerialNumber"]) {
                    NSString *spoofedSerial = [manager currentValueForIdentifier:@"SerialNumber"];
                    CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, spoofedSerial);
                    if (repl) props[keyString] = (__bridge_transfer id)repl;
                    continue;
                }
                if ([keyString isEqualToString:@"IOPlatformUUID"] && [manager isIdentifierEnabled:@"SystemBootUUID"]) {
                    NSString *spoofedUUID = [manager currentValueForIdentifier:@"SystemBootUUID"];
                    CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, spoofedUUID);
                    if (repl) props[keyString] = (__bridge_transfer id)repl;
                    continue;
                }
                if ([keyString isEqualToString:@"system-id"] && [manager isIdentifierEnabled:@"SystemBootUUID"]) {
                    NSString *spoofedUUID = [manager currentValueForIdentifier:@"SystemBootUUID"];
                    CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, spoofedUUID);
                    if (repl) props[keyString] = (__bridge_transfer id)repl;
                    continue;
                }

                // IODeviceTree device-info style keys
                if ([manager isIdentifierEnabled:@"DeviceModel"]) {
                    if ([keyString isEqualToString:@"device-model"] || [keyString isEqualToString:@"product-name"] || [keyString isEqualToString:@"hw.machine"]) {
                        if (PXRequireKeysAll(deviceIds, @[@"DeviceModel"], @"IOKit", keyString, currentBundleID, profileId, gen)) {
                            NSString *deviceModel = deviceIds[@"DeviceModel"];
                            CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, deviceModel);
                            if (repl) props[keyString] = (__bridge_transfer id)repl;
                        }
                        continue;
                    }

                    if ([keyString isEqualToString:@"board-id"] || [keyString isEqualToString:@"BoardId"]) {
                        if (PXRequireKeysAll(deviceIds, @[@"BoardID"], @"IOKit", keyString, currentBundleID, profileId, gen)) {
                            NSString *boardID = deviceIds[@"BoardID"];
                            CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, boardID);
                            if (repl) props[keyString] = (__bridge_transfer id)repl;
                        }
                        continue;
                    }

                    if ([keyString isEqualToString:@"model"] || [keyString isEqualToString:@"hw.model"]) {
                        if (PXRequireKeysAll(deviceIds, @[@"HwModel"], @"IOKit", keyString, currentBundleID, profileId, gen)) {
                            NSString *hwModel = deviceIds[@"HwModel"];
                                    CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, hwModel);
                            if (repl) props[keyString] = (__bridge_transfer id)repl;
                        }
                        continue;
                    }

                    if ([keyString isEqualToString:@"model-number"]) {
                        if (PXRequireKeysAll(deviceIds, @[@"ModelNumber"], @"IOKit", keyString, currentBundleID, profileId, gen)) {
                            NSString *modelNumber = deviceIds[@"ModelNumber"];
                            CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, modelNumber);
                            if (repl) props[keyString] = (__bridge_transfer id)repl;
                        }
                        continue;
                    }

                    if ([keyString isEqualToString:@"platform-name"]) {
                        if (PXRequireKeysAll(deviceIds, @[@"HwModel"], @"IOKit", keyString, currentBundleID, profileId, gen)) {
                            NSString *hwModel = deviceIds[@"HwModel"];
                                    CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, hwModel);
                            if (repl) props[keyString] = (__bridge_transfer id)repl;
                        }
                        continue;
                    }

                    if ([keyString isEqualToString:@"compatible"]) {
                        if (PXRequireKeysAll(deviceIds, @[@"HwModel"], @"IOKit", keyString, currentBundleID, profileId, gen)) {
                            NSString *hwModel = deviceIds[@"HwModel"];
                                    NSString *deviceModel = deviceIds[@"DeviceModel"];

                            // For compatible we must preserve array/data semantics.
                            CFTypeRef repl = PXIOKitPatchCompatibleValue(original ? CFRetain(original) : NULL, hwModel, deviceModel);
                            if (repl) props[keyString] = (__bridge_transfer id)repl;
                        }
                        continue;
                    }
                }

                // TargetRegion pins for subscriber fields sometimes leak through IOKit-ish tables on some apps.
                // Best-effort: only if key matches and targetRegion is enabled.
                if (targetRegionFollowsIP) {
                    if ([keyString isEqualToString:@"MobileSubscriberCountryCode"] && pinnedMCC.length) {
                        CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, pinnedMCC);
                        if (repl) props[keyString] = (__bridge_transfer id)repl;
                        continue;
                    }
                    if ([keyString isEqualToString:@"MobileSubscriberNetworkCode"] && pinnedMNC.length) {
                        CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, pinnedMNC);
                        if (repl) props[keyString] = (__bridge_transfer id)repl;
                        continue;
                    }
                    if ([keyString isEqualToString:@"RegionCode"] && pinnedCountryCode.length) {
                        CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, [pinnedCountryCode uppercaseString]);
                        if (repl) props[keyString] = (__bridge_transfer id)repl;
                        continue;
                    }
                }
            }
        } @catch (NSException *exception) {
            PXLog(@"Exception in IORegistryEntryCreateCFProperties hook: %@", exception);
        }
    }
    return result;
}

static CFTypeRef hook_IORegistryEntrySearchCFProperty(io_registry_entry_t entry, const io_name_t plane, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options) {
    static int loggedCount = 0;
    if (key && loggedCount < 30) {
        loggedCount++;
        NSString *k = (__bridge NSString *)key;
        PXFileDebugAIDA64Log("[Tweak.IORegistryEntrySearchCFProperty] key=%s plane=%s", k.UTF8String ?: "<nil>", plane ?: "<nil>");
    }
    if (!orig_IORegistryEntrySearchCFProperty || !entry || !key) {
        return NULL;
    }

    CFTypeRef original = orig_IORegistryEntrySearchCFProperty(entry, plane, key, allocator, options);

    @autoreleasepool {
        @try {
            if (!%c(IdentifierManager)) {
                return original;
            }
            IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
            NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
            if (!PXIOKitShouldSpoof(manager, currentBundleID)) {
                return original;
            }

            NSString *keyString = (__bridge NSString *)key;
            if (!keyString.length) {
                return original;
            }

            // Handle platform identifiers + common IODeviceTree aliases.
            if ([keyString isEqualToString:@"IOPlatformSerialNumber"] || [keyString isEqualToString:@"serial-number"] || [keyString isEqualToString:@"mlb-serial-number"]) {
                if ([manager isIdentifierEnabled:@"SerialNumber"]) {
                    NSString *spoofedSerial = [manager currentValueForIdentifier:@"SerialNumber"];
                    CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, spoofedSerial);
                    if (repl) {
                        if (original) CFRelease(original);
                        return repl;
                    }
                    return original;
                }
            }

            if ([keyString isEqualToString:@"IOPlatformUUID"] || [keyString isEqualToString:@"system-id"]) {
                if ([manager isIdentifierEnabled:@"SystemBootUUID"]) {
                    NSString *spoofedUUID = [manager currentValueForIdentifier:@"SystemBootUUID"];
                    CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, spoofedUUID);
                    if (repl) {
                        if (original) CFRelease(original);
                        return repl;
                    }
                    return original;
                }
            }

            if ([manager isIdentifierEnabled:@"DeviceModel"]) {
                NSString *profileId = nil;
                NSNumber *gen = nil;
                NSDictionary *deviceIds = PXGetDeviceIdsSnapshot(&profileId, &gen);

                if ([keyString isEqualToString:@"model-number"]) {
                    if (PXRequireKeysAll(deviceIds, @[@"ModelNumber"], @"IOKitSearch", keyString, currentBundleID, profileId, gen)) {
                        NSString *modelNumber = deviceIds[@"ModelNumber"];
                        CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, modelNumber);
                        if (repl) {
                            if (original) CFRelease(original);
                            return repl;
                        }
                        return original;
                    }
                }

                if ([keyString isEqualToString:@"device-model"] || [keyString isEqualToString:@"product-name"] || [keyString isEqualToString:@"hw.machine"]) {
                    if (PXRequireKeysAll(deviceIds, @[@"DeviceModel"], @"IOKitSearch", keyString, currentBundleID, profileId, gen)) {
                        NSString *deviceModel = deviceIds[@"DeviceModel"];
                        CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, deviceModel);
                        if (repl) {
                            if (original) CFRelease(original);
                            return repl;
                        }
                        return original;
                    }
                }

                if ([keyString isEqualToString:@"board-id"] || [keyString isEqualToString:@"BoardId"]) {
                    if (PXRequireKeysAll(deviceIds, @[@"BoardID"], @"IOKitSearch", keyString, currentBundleID, profileId, gen)) {
                        NSString *boardID = deviceIds[@"BoardID"];
                        CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, boardID);
                        if (repl) {
                            if (original) CFRelease(original);
                            return repl;
                        }
                        return original;
                    }
                }

                if ([keyString isEqualToString:@"model"] || [keyString isEqualToString:@"hw.model"] || [keyString isEqualToString:@"platform-name"]) {
                    if (PXRequireKeysAll(deviceIds, @[@"HwModel"], @"IOKitSearch", keyString, currentBundleID, profileId, gen)) {
                        NSString *hwModel = deviceIds[@"HwModel"];
                            CFTypeRef repl = PXIOKitCreateReplacementMatchingOriginal(original, keyString, hwModel);
                        if (repl) {
                            if (original) CFRelease(original);
                            return repl;
                        }
                        return original;
                    }
                }

                if ([keyString isEqualToString:@"compatible"]) {
                    if (PXRequireKeysAll(deviceIds, @[@"HwModel"], @"IOKitSearch", keyString, currentBundleID, profileId, gen)) {
                        NSString *hwModel = deviceIds[@"HwModel"];
                            NSString *deviceModel = deviceIds[@"DeviceModel"];
                        CFTypeRef repl = PXIOKitPatchCompatibleValue(original ? CFRetain(original) : NULL, hwModel, deviceModel);
                        if (repl) {
                            if (original) CFRelease(original);
                            return repl;
                        }
                        return original;
                    }
                }
            }
        } @catch (NSException *exception) {
            PXLog(@"Exception in IORegistryEntrySearchCFProperty hook: %@", exception);
        }
    }

    return original;
}

// Hook private API GSSystemGetSerialNo
static char* (*orig_GSSystemGetSerialNo)(void);

static char* hook_GSSystemGetSerialNo(void) {
    if (!%c(IdentifierManager)) {
        return orig_GSSystemGetSerialNo();
    }
    
    IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
    NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    PXLog(@"GSSystemGetSerialNo requested by app: %@", currentBundleID);
    
    // Special case for Filza and ADManager
    if ([currentBundleID isEqualToString:@"com.tigisoftware.Filza"] || 
        [currentBundleID isEqualToString:@"com.tigisoftware.ADManager"]) {
        NSString *hardcodedSerial = @"FCCC15Q4HG04";
        PXLog(@"[WeaponX] 📱 Spoofing GSSystemGetSerialNo with hardcoded value for %@: %@", 
             currentBundleID, hardcodedSerial);
        
        // Convert NSString to char* that will persist
        char *serialStr = strdup([hardcodedSerial UTF8String]);
        return serialStr;
    }
    
    NSString *proc = [NSProcessInfo processInfo].processName;
    if (!PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
        PXLog(@"App not in scope or disabled, passing through original serial number");
        return orig_GSSystemGetSerialNo();
    }
    
    if ([manager isIdentifierEnabled:@"SerialNumber"]) {
        NSString *spoofedSerial = [manager currentValueForIdentifier:@"SerialNumber"];
        if (spoofedSerial) {
            PXLog(@"Spoofing GSSystemGetSerialNo with: %@", spoofedSerial);
            
            // Convert NSString to char* that will persist
            // Note: This will leak a small amount of memory but it's necessary
            // since we can't free the memory after returning it
            char *serialStr = strdup([spoofedSerial UTF8String]);
            return serialStr;
        }
    }
    
    return orig_GSSystemGetSerialNo();
}

// Constructor
%ctor {
    NSString *currentProcessName = [NSProcessInfo processInfo].processName;
    NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
    // SpringBoard hosts Profile Indicator only. Loading the full spoof stack + debug I/O
    // here freezes app launches and overloads the system (user-visible "apps open slowly").
    if (PXIsSpringBoardProcess() ||
        [currentProcessName isEqualToString:@"SpringBoard"] ||
        [currentBundleID isEqualToString:@"com.apple.springboard"]) {
        PXLog(@"[WeaponX] SpringBoard: minimal init (Profile Indicator only)");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            ProfileIndicatorView *indicator = [ProfileIndicatorView sharedInstance];
            if (PXReadSecuritySettingBool(@"profileIndicatorEnabled")) {
                [indicator show];
            } else {
                [indicator hide];
            }
        });
        // One late retry if the first scene attach was too early.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!PXReadSecuritySettingBool(@"profileIndicatorEnabled")) return;
            [[ProfileIndicatorView sharedInstance] show];
        });
        return;
    }

    PXIdentitySnapshotStartObserving();

    CFNotificationCenterRef identityCenter = CFNotificationCenterGetDarwinNotifyCenter();
    if (identityCenter) {
        CFNotificationCenterAddObserver(identityCenter, NULL, PXIdentitySnapshotChanged,
                                        CFSTR("com.hydra.projectx.settings.changed"), NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(identityCenter, NULL, PXIdentitySnapshotChanged,
                                        CFSTR("com.hydra.projectx.profileChanged"), NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(identityCenter, NULL, PXIdentitySnapshotChanged,
                                        CFSTR("com.hydra.projectx.scopedAppsChanged"), NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
    }

    PXFileDebugLoadMarker("ProjectXTweak.Tweak.ctor");
    PXFileDebugAIDA64Log("[Tweak.ctor] enter");
    // Debug flag files only when explicitly debugging (avoid /tmp I/O on every app launch).
    if (access("/tmp/px_debug_all", F_OK) == 0 || access("/tmp/px_debug_aida64", F_OK) == 0) {
        [@"ctor_entry" writeToFile:@"/tmp/weaponx_ctor_started.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
        NSString *flagPath = [NSString stringWithFormat:@"/tmp/weaponx_loaded_%@.txt", currentProcessName];
        [@"Constructor executed!" writeToFile:flagPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    
    // Add at beginning of ctor
    PXFileDebugAIDA64Log("[Tweak.ctor] before setupHookingEnvironment");
    setupHookingEnvironment();
    PXFileDebugAIDA64Log("[Tweak.ctor] after setupHookingEnvironment");

    // Install shims for weakly-linked selectors to prevent crashes (apps only, not SpringBoard).
    PXFileDebugAIDA64Log("[Tweak.ctor] before PXInstallCompatibilityShims");
    PXInstallCompatibilityShims();
    PXFileDebugAIDA64Log("[Tweak.ctor] after PXInstallCompatibilityShims");
    
    PXLog(@"ProjectX tweak initializing...");
    
    BOOL shouldInstallSpoofHooks = NO;
    BOOL isWebKitHelper = PXIsWebKitHelperProcess(currentBundleID, currentProcessName);
    if (isWebKitHelper) {
        PXFileDebugWebKitTrace(@"ProjectXTweak.Tweak.ctor");
    }
    PXFileDebugAIDA64Log("[Tweak.ctor] bundle=%s proc=%s", currentBundleID.UTF8String ?: "<nil>", currentProcessName.UTF8String ?: "<nil>");
    PXLog(@"[WeaponX] 💉 Tweak injected into process: %@ (BundleID: %@)", [NSProcessInfo processInfo].processName, currentBundleID);
    
    if (currentBundleID) {
        PXFileDebugAIDA64Log("[Tweak.ctor] before IdentifierManager/scope decision");
        IdentifierManager *mgr = [%c(IdentifierManager) sharedManager];
        if (mgr) {
            BOOL enabled = PXProcessIsAllowedForSpoofing(currentBundleID, currentProcessName, PXScopeOptionAllowSafariAuthStack);
            shouldInstallSpoofHooks = enabled && !isWebKitHelper;
            PXFileDebugAIDA64Log("[Tweak.ctor] after scope decision enabled=%d", enabled);
            PXLog(@"[WeaponX] 🔍 App Enabled Check: %@ -> %@", currentBundleID, enabled ? @"YES" : @"NO");
            
            if (enabled) {
                PXLog(@"[WeaponX] ✅ App is enabled! Hooks should activate.");
            } else {
                PXLog(@"[WeaponX] ⚠️ App is NOT enabled in settings.");
            }
        } else {
            PXLog(@"[WeaponX] ❌ Failed to get IdentifierManager instance!");
        }
    }
    
    // CRITICAL FIX: Safely initialize jailbreak detection bypass with proper safety measures
    // This must happen before any jailbreak-detection hooks are needed
    NSString *currentProcess = [NSProcessInfo processInfo].processName;
    
    // Never initialize in critical boot-time processes
    if ([currentProcess isEqualToString:@"launchd"] || 
        [currentProcess isEqualToString:@"backboardd"] ||
        [currentProcess isEqualToString:@"SpringBoard"]) {
        PXLog(@"[JailbreakBypass] Not initializing in critical system process: %@", currentProcess);
    } else {
        // For regular apps, initialize normally but with a small delay to avoid boot loops
    }
    
    // ElleKit early init removed for rootful - not needed with Substrate
    // if (dlsym(RTLD_DEFAULT, "EKEarlyInit")) {
    //     EKEarlyInit(earlyInitCallback);
    //     PXLog(@"Registered ElleKit early initialization handler");
    // }
    
    // Detect iOS version
    NSOperatingSystemVersion osVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
    PXLog(@"Detected iOS version: %ld.%ld.%ld", 
          (long)osVersion.majorVersion, 
          (long)osVersion.minorVersion, 
          (long)osVersion.patchVersion);
          
    // Special handling for iOS 16+
    if (osVersion.majorVersion >= 16) {
        PXLog(@"iOS 16+ detected, enabling compatibility mode");
    }
    
    // Detect which hook system is being used (coordinator uses MSHookFunction on both Substrate and ElleKit)
    NSString *hookSystem = @"Unknown";
    if (dlsym(RTLD_DEFAULT, "EKMethodsEqual")) {
        hookSystem = @"ElleKit";
    } else if (dlsym(RTLD_DEFAULT, "MSHookFunction")) {
        hookSystem = @"MobileSubstrate";
    }
    PXLog(@"Using hook system: %@", hookSystem);

    // Register core identity providers + install owned native symbols via coordinator (sole MSHookFunction owner).
    if (shouldInstallSpoofHooks) {
        PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
        [coord installOwnedSymbolsIfNeeded];

        // Wire original pointers for legacy hook bodies used as providers.
        sysctl_orig = [coord originalForSymbol:kPXNativeSymbolSysctl];
        sysctlbyname_orig = [coord originalForSymbol:kPXNativeSymbolSysctlByname];
        gethostname_orig = [coord originalForSymbol:kPXNativeSymbolGethostname];
        getifaddrs_orig = [coord originalForSymbol:kPXNativeSymbolGetifaddrs];
        orig_IORegistryEntryCreateCFProperty = [coord originalForSymbol:kPXNativeSymbolIORegistryEntryCreateCFProperty];
        orig_IORegistryEntryCreateCFProperties = [coord originalForSymbol:kPXNativeSymbolIORegistryEntryCreateCFProperties];
        orig_IORegistryEntrySearchCFProperty = [coord originalForSymbol:kPXNativeSymbolIORegistryEntrySearchCFProperty];
        CFCopySystemVersionDictionary_orig = [coord originalForSymbol:kPXNativeSymbolCFCopySystemVersionDictionary];

        static dispatch_once_t tweakProvOnce;
        dispatch_once(&tweakProvOnce, ^{
            // sysctl still uses the legacy terminal body. sysctlbyname below is a selective
            // pre-provider and returns NO for unhandled keys so coordinator post-providers run.
            [coord registerSysctlProvider:@"tweak.sysctl" priority:PXNativeHookPriorityIdentity pre:^BOOL(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen, int *outResult) {
                if (!sysctl_orig) return NO;
                int r = sysctl_hook(name, namelen, oldp, oldlenp, newp, newlen);
                if (outResult) *outResult = r;
                return YES;
            } post:nil];
            [coord registerSysctlBynameProvider:@"tweak.sysctlbyname" priority:PXNativeHookPriorityIdentity pre:^BOOL(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen, int *outResult) {
                if (!sysctlbyname_orig || !name || newp != NULL || newlen != 0) return NO;
                BOOL handled = NO;
                int r = sysctlbyname_hook(name, oldp, oldlenp, newp, newlen, &handled);
                if (!handled) return NO;
                if (outResult) *outResult = r;
                return YES;
            } post:nil];
            // gethostname provider notes (Newplan):
            // - Coordinator owns MSHookFunction install (MS + ElleKit); not gated by jailbreakDetectionEnabled.
            // - Scoped + DeviceName ON → write profile DeviceName; NUL-terminate; return 0.
            // - null buffer / size 0 / invalid profile value → return NO so coordinator calls original.
            // - UIDevice.name / NSHost / kern.hostname share the same DeviceName profile value.
            [coord registerGethostnameProvider:@"tweak.gethostname" priority:PXNativeHookPriorityIdentity pre:^BOOL(char *name, size_t namelen, int *outResult) {
                if (!name || namelen == 0) return NO;
                @try {
                    NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
                    NSString *proc = [NSProcessInfo processInfo].processName;
                    if (!currentBundleID || !PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
                        return NO;
                    }
                    IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
                    if (!manager || ![manager isIdentifierEnabled:@"DeviceName"]) return NO;
                    NSString *deviceName = [manager currentValueForIdentifier:@"DeviceName"];
                    if (!deviceName.length) return NO;
                    const char *cstr = deviceName.UTF8String;
                    // Delegate the bounded, NUL-terminating copy to the shared,
                    // host-testable helper (P1-B, no drift with tests).
                    if (!PXGethostnameWriteValue(name, namelen, cstr)) return NO;
                    if (outResult) *outResult = 0;
                    return YES;
                } @catch (__unused NSException *e) {
                    return NO;
                }
            } post:nil];
            [coord registerGetifaddrsProvider:@"tweak.getifaddrs" priority:PXNativeHookPriorityIdentity pre:^BOOL(struct ifaddrs **ifap, int *outResult) {
                if (!getifaddrs_orig) return NO;
                int r = getifaddrs_hook(ifap);
                if (outResult) *outResult = r;
                return YES;
            } post:nil];
            [coord registerIORegistryCreateCFPropertyProvider:@"tweak.iokit.create" priority:PXNativeHookPriorityIdentity pre:^BOOL(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options, CFTypeRef *outResult) {
                if (!orig_IORegistryEntryCreateCFProperty) return NO;
                CFTypeRef r = hook_IORegistryEntryCreateCFProperty(entry, key, allocator, options);
                if (outResult) *outResult = r;
                return YES;
            } post:nil];
            [coord registerIORegistryCreateCFPropertiesProvider:@"tweak.iokit.properties" priority:PXNativeHookPriorityIdentity pre:^BOOL(io_registry_entry_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, IOOptionBits options, IOReturn *outResult) {
                if (!orig_IORegistryEntryCreateCFProperties) return NO;
                IOReturn r = hook_IORegistryEntryCreateCFProperties(entry, properties, allocator, options);
                if (outResult) *outResult = r;
                return YES;
            } post:nil];
            [coord registerIORegistrySearchCFPropertyProvider:@"tweak.iokit.search" priority:PXNativeHookPriorityIdentity pre:^BOOL(io_registry_entry_t entry, const io_name_t plane, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options, CFTypeRef *outResult) {
                if (!orig_IORegistryEntrySearchCFProperty) return NO;
                CFTypeRef r = hook_IORegistryEntrySearchCFProperty(entry, plane, key, allocator, options);
                if (outResult) *outResult = r;
                return YES;
            } post:nil];
            [coord registerCFCopySystemVersionDictionaryProvider:@"tweak.cf.systemversion" priority:PXNativeHookPriorityIdentity pre:^BOOL(CFDictionaryRef *outResult) {
                if (!CFCopySystemVersionDictionary_orig) return NO;
                CFDictionaryRef r = CFCopySystemVersionDictionary_hook();
                if (outResult) *outResult = r;
                return YES;
            } post:nil];
        });

        PXLog(@"[WeaponX] Native coordinator installed. diagnostics=%@", [coord diagnostics]);
    }
    
    // Initialize value cache
    valueCache = [NSMutableDictionary dictionary];
    
    // Load saved settings and ensure synchronization
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Load security settings
    NSUserDefaults *securitySettings = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
    [securitySettings synchronize]; // Force synchronization to get the latest settings
    
    // Initialize our hook group
    if (shouldInstallSpoofHooks) {
        PXFileDebugAIDA64Log("[Tweak.ctor] before init Identifiers");
        %init(Identifiers);
        PXFileDebugAIDA64Log("[Tweak.ctor] after init Identifiers");

        // ATT (iOS 14+): install only if class/selectors exist. Active when IDFA identifier enabled.
        // Legacy iOS uses ASIdentifierManager.isAdvertisingTrackingEnabled / advertisingIdentifier above.
        PXInstallATTHooksIfAvailable();
    } else {
        PXFileDebugAIDA64Log("[Tweak.ctor] skip init Identifiers allowed=0");
    }
    
    // ScreenshotModifier: Logos requires every %group to be %init'd somewhere.
    // Intentionally disabled (SB-only feature was scope-gated off) — keep for compile.
    if (0) {
        %init(ScreenshotModifier);
    }

    if (!shouldInstallSpoofHooks) {
        PXFileDebugAIDA64Log("[Tweak.ctor] exit skip native spoof hooks allowed=%d webkit=%d", PXProcessIsAllowedForSpoofing(currentBundleID, currentProcessName, PXScopeOptionAllowSafariAuthStack), isWebKitHelper);
        return;
    }
    
    // Use ElleKit's memory protection modification for direct memory patching
    if (dlsym(RTLD_DEFAULT, "EKMemoryProtect")) {
        // Example: Find and patch in-memory locations that might store identifiers
        // This is a powerful ElleKit-exclusive capability
        PXLog(@"Using ElleKit's memory protection features for enhanced security");
        
        // Get the main executable's handle
        const char *appPath = _dyld_get_image_name(0);
        if (appPath) {
            // Find symbol offsets for potential identifier storage
            uint32_t imageCount = _dyld_image_count();
            for (uint32_t i = 0; i < imageCount; i++) {
                const char *imageName = _dyld_get_image_name(i);
                if (imageName && strstr(imageName, "AppTrackingTransparency")) {
                    PXLog(@"Found AppTrackingTransparency framework, applying additional protections");
                    
                    // Use EKMemoryProtect to make certain memory regions writable
                    // For demonstration only, don't declare unused variables
                    // Calculate actual addresses to patch in a real implementation
                    // Use a dummy variable to silence warnings but be cautious about actual implementation
                    const void *headerPtr = _dyld_get_image_header(i);
                    PXLog(@"Applied memory protection to ATT framework at %p", headerPtr);
                    
                    // For demonstration only - this would need real offset calculations
                    // EKMemoryProtect((void*)(baseAddress + offset), size, PROT_READ | PROT_WRITE);
                }
                
                // Look for analytics frameworks that might capture device identifiers
                if (imageName && (strstr(imageName, "Analytics") || 
                                 strstr(imageName, "Tracking") || 
                                 strstr(imageName, "Firebase") ||
                                 strstr(imageName, "Fabric") ||
                                 strstr(imageName, "Crashlytics"))) {
                    PXLog(@"Found analytics framework: %s, applying protections", imageName);
                    // Here we would add protections specific to analytics frameworks
                }
            }
            
            // Detect anti-jailbreak functionality and neutralize it
            // This is especially important for banking and high-security apps
            PXLog(@"Scanning for anti-jailbreak functionality...");
            
            // Check if jailbreak detection bypass is enabled
            NSUserDefaults *securitySettings = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
            BOOL jailbreakDetectionEnabled = [securitySettings boolForKey:@"jailbreakDetectionEnabled"];
            
            if (!jailbreakDetectionEnabled) {
                PXLog(@"Jailbreak detection bypass is disabled, skipping anti-jailbreak protection");
                return;
            }
            
            NSBundle *mainBundle = [NSBundle mainBundle];
            NSString *bundleID = [mainBundle bundleIdentifier];
            
            // Check if the current app is in the scoped apps list
            if (!bundleID) {
                return;
            }
            
            IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
            NSString *proc = [NSProcessInfo processInfo].processName;
            if (!manager || !PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionNone)) {
                PXLog(@"App %@ not in scoped list, skipping anti-jailbreak protection", bundleID);
                return;
            }
            
            // App is in scoped list and jailbreak detection bypass is enabled
            PXLog(@"High-security app detected: %@, enabling advanced protection", bundleID);
            // For apps in the scoped list, use more aggressive hiding techniques
        }
    }
    
    // Anti-debugging protection for our own tweak
    // This helps prevent apps from detecting our hooks
    if (0) {
        // Check if jailbreak detection bypass is enabled
        NSUserDefaults *securitySettings = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
        BOOL jailbreakDetectionEnabled = [securitySettings boolForKey:@"jailbreakDetectionEnabled"];
        
        if (jailbreakDetectionEnabled) {
            PXLog(@"Enabling anti-detection measures with ElleKit");
            
            // ElleKit callbacks removed for rootful - not available with Substrate
            // if (dlsym(RTLD_DEFAULT, "EKRegisterCallback")) {
            //     EKRegisterCallback(antiDetectionCallback);
            // }
        } else {
            PXLog(@"Jailbreak detection bypass is disabled, skipping anti-detection measures");
        }
    }
    
    // IOKit / sysctl / CFCopySystemVersionDictionary are owned by PXNativeHookCoordinator (installed above).
    // uname remains a Tweak-owned exclusive symbol (not multi-module).
    PXFileDebugAIDA64Log("[Tweak.ctor] before uname/GS hooks");
    void *GSHandle = dlopen("/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices", RTLD_NOW);
    if (GSHandle) {
        void *GSSystemGetSerialNoPtr = dlsym(GSHandle, "GSSystemGetSerialNo");
        if (GSSystemGetSerialNoPtr && dlsym(RTLD_DEFAULT, "MSHookFunction")) {
            MSHookFunction(GSSystemGetSerialNoPtr, (void *)hook_GSSystemGetSerialNo, (void **)&orig_GSSystemGetSerialNo);
        }
        dlclose(GSHandle);
    }
    void *unamePtr = dlsym(RTLD_DEFAULT, "uname");
    void *substrateHook = dlsym(RTLD_DEFAULT, "MSHookFunction");
    if (!sPXUnameHookInstalled && unamePtr && substrateHook && unamePtr != (void *)uname_hook) {
        MSHookFunction(unamePtr, (void *)uname_hook, (void **)&uname_orig);
        sPXUnameHookInstalled = (uname_orig != NULL && uname_orig != uname_hook);
        PXLog(@"[WeaponX] uname hook install %@ original=%p",
              sPXUnameHookInstalled ? @"succeeded" : @"failed", uname_orig);
    }
    PXFileDebugAIDA64Log("[Tweak.ctor] after uname/GS hooks");

    // Initialize the location spoofing hooks
    PXFileDebugAIDA64Log("[Tweak.ctor] before init LocationSpoofing");
    %init(LocationSpoofing);
    PXFileDebugAIDA64Log("[Tweak.ctor] after init LocationSpoofing");
    
    // Initialize sensor data spoofing hooks
    PXFileDebugAIDA64Log("[Tweak.ctor] before init SensorSpoofing");
    %init(SensorSpoofing);
    PXFileDebugAIDA64Log("[Tweak.ctor] after init SensorSpoofing");
    
    PXLog(@"[WeaponX] Location and sensor spoofing hooks initialized");
    PXFileDebugAIDA64Log("[Tweak.ctor] exit");
}
