// PrivateIdentityWrapperHooks.x
// A-05: capability-gated Apple/private identity wrapper parity.
//
// This module intentionally does NOT reproduce iFake's vendor anti-fraud lattice.
// It only hooks explicit Apple/system wrapper classes whose selector maps to the
// canonical PXIdentitySurfacePrivateWrapper registry. Secure Element / PassKit
// evidence classes are excluded by construction.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <os/lock.h>
#import <string.h>
#import <substrate.h>

#import "IdentifierManager.h"
#import "PXIdentitySnapshot.h"
#import "PXIdentitySurfaceRegistry.h"
#import "PXPrivateIdentityWrapperProjection.h"
#import "PXRuntimeUtilities.h"
#import "PXScope.h"
#import "TLinkIOSLogging.h"

@interface PXPrivateIdentityInstalledHook : NSObject
@property (nonatomic, assign) Class targetClass;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, assign) IMP original;
@property (nonatomic, assign) BOOL classMethod;
@property (nonatomic, assign) BOOL keyedGetter;
@end
@implementation PXPrivateIdentityInstalledHook
@end

static os_unfair_lock gPXPrivateWrapperLock = OS_UNFAIR_LOCK_INIT;
static NSMutableArray<PXPrivateIdentityInstalledHook *> *gPXPrivateWrapperInstalled = nil;
static dispatch_queue_t gPXPrivateWrapperInstallQueue = nil;
static __thread BOOL gPXInsidePrivateIdentityWrapper = NO;

static BOOL PXPrivateIdentityProcessAllowed(void) {
    if (PXIsSpringBoardProcess()) return NO;
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    NSString *processName = NSProcessInfo.processInfo.processName;
    if (!bundleID.length) return NO;
    return PXProcessIsAllowedForSpoofing(bundleID,
                                         processName,
                                         PXScopeOptionAllowSafariAuthStack);
}

static BOOL PXPrivateIdentityClassIsSystemOwned(Class cls) {
    if (!cls) return NO;
    const char *image = class_getImageName(cls);
    if (!image || !image[0]) return NO;
    return strncmp(image, "/System/Library/", strlen("/System/Library/")) == 0 ||
           strncmp(image, "/usr/lib/", strlen("/usr/lib/")) == 0;
}

static PXPrivateIdentityInstalledHook *PXPrivateIdentityFindInstalled(id receiver, SEL selector) {
    if (!receiver || !selector) return nil;
    Class runtimeClass = object_getClass(receiver);
    if (!runtimeClass) return nil;
    BOOL classMethod = class_isMetaClass(runtimeClass);

    os_unfair_lock_lock(&gPXPrivateWrapperLock);
    NSArray<PXPrivateIdentityInstalledHook *> *snapshot = [gPXPrivateWrapperInstalled copy] ?: @[];
    os_unfair_lock_unlock(&gPXPrivateWrapperLock);

    for (PXPrivateIdentityInstalledHook *record in snapshot) {
        if (record.classMethod != classMethod || record.selector != selector) continue;
        for (Class cursor = runtimeClass; cursor != Nil; cursor = class_getSuperclass(cursor)) {
            if (cursor == record.targetClass) return record;
        }
    }
    return nil;
}

static id PXPrivateIdentityCallOriginal0(PXPrivateIdentityInstalledHook *record,
                                         id receiver,
                                         SEL selector) {
    if (!record.original) return nil;
    return ((id (*)(id, SEL))record.original)(receiver, selector);
}

static id PXPrivateIdentityCallOriginal1(PXPrivateIdentityInstalledHook *record,
                                         id receiver,
                                         SEL selector,
                                         id argument) {
    if (!record.original) return nil;
    return ((id (*)(id, SEL, id))record.original)(receiver, selector, argument);
}

static BOOL PXPrivateIdentityProjectionContext(PXIdentitySnapshot **outSnapshot,
                                               IdentifierManager **outManager) {
    if (!PXPrivateIdentityProcessAllowed()) return NO;
    PXIdentitySnapshot *snapshot = PXCurrentIdentitySnapshot();
    if (!snapshot.valid || ![snapshot.deviceIDs isKindOfClass:[NSDictionary class]]) return NO;
    IdentifierManager *manager = [IdentifierManager sharedManager];
    if (!manager) return NO;
    if (outSnapshot) *outSnapshot = snapshot;
    if (outManager) *outManager = manager;
    return YES;
}

static id PXPrivateIdentityGetter(id receiver, SEL selector) {
    PXPrivateIdentityInstalledHook *record = PXPrivateIdentityFindInstalled(receiver, selector);
    if (!record) return nil;
    if (gPXInsidePrivateIdentityWrapper) {
        return PXPrivateIdentityCallOriginal0(record, receiver, selector);
    }

    gPXInsidePrivateIdentityWrapper = YES;
    id original = nil;
    @try {
        original = PXPrivateIdentityCallOriginal0(record, receiver, selector);
        PXIdentitySnapshot *snapshot = nil;
        IdentifierManager *manager = nil;
        if (!PXPrivateIdentityProjectionContext(&snapshot, &manager)) return original;

        NSString *surfaceKey = NSStringFromSelector(selector);
        PXIdentitySurfaceEntry *entry =
            PXIdentitySurfaceEntryForKey(surfaceKey, PXIdentitySurfacePrivateWrapper);
        if (!entry || ![manager isIdentifierEnabled:entry.toggle]) return original;
        return PXPrivateIdentityWrapperProjectObject(original, surfaceKey, snapshot.deviceIDs);
    } @catch (__unused NSException *exception) {
        return original;
    } @finally {
        gPXInsidePrivateIdentityWrapper = NO;
    }
}

static PXIdentitySurfaceEntry *PXPrivateIdentityEntryForQueriedKey(NSString *key) {
    PXIdentitySurfaceEntry *entry =
        PXIdentitySurfaceEntryForKey(key, PXIdentitySurfaceMobileGestalt);
    if (!entry) entry = PXIdentitySurfaceEntryForKey(key, PXIdentitySurfaceIORegistry);
    if (!entry) entry = PXIdentitySurfaceEntryForKey(key, PXIdentitySurfacePrivateWrapper);
    return entry;
}

static id PXPrivateIdentityKeyedGetter(id receiver, SEL selector, id key) {
    PXPrivateIdentityInstalledHook *record = PXPrivateIdentityFindInstalled(receiver, selector);
    if (!record) return nil;
    if (gPXInsidePrivateIdentityWrapper) {
        return PXPrivateIdentityCallOriginal1(record, receiver, selector, key);
    }

    gPXInsidePrivateIdentityWrapper = YES;
    id original = nil;
    @try {
        original = PXPrivateIdentityCallOriginal1(record, receiver, selector, key);
        if (![key isKindOfClass:[NSString class]]) return original;

        PXIdentitySnapshot *snapshot = nil;
        IdentifierManager *manager = nil;
        if (!PXPrivateIdentityProjectionContext(&snapshot, &manager)) return original;

        PXIdentitySurfaceEntry *entry = PXPrivateIdentityEntryForQueriedKey((NSString *)key);
        if (!entry || ![manager isIdentifierEnabled:entry.toggle]) return original;
        return PXPrivateIdentityWrapperProjectKeyedObject(original,
                                                          (NSString *)key,
                                                          snapshot.deviceIDs,
                                                          NULL);
    } @catch (__unused NSException *exception) {
        return original;
    } @finally {
        gPXInsidePrivateIdentityWrapper = NO;
    }
}

static BOOL PXPrivateIdentityAlreadyInstalled(Class targetClass, SEL selector, BOOL classMethod) {
    os_unfair_lock_lock(&gPXPrivateWrapperLock);
    for (PXPrivateIdentityInstalledHook *record in gPXPrivateWrapperInstalled) {
        if (record.targetClass == targetClass &&
            record.selector == selector &&
            record.classMethod == classMethod) {
            os_unfair_lock_unlock(&gPXPrivateWrapperLock);
            return YES;
        }
    }
    os_unfair_lock_unlock(&gPXPrivateWrapperLock);
    return NO;
}

static void PXPrivateIdentityPublishInstalled(Class targetClass,
                                              SEL selector,
                                              BOOL classMethod,
                                              BOOL keyedGetter,
                                              IMP original) {
    PXPrivateIdentityInstalledHook *record = [PXPrivateIdentityInstalledHook new];
    record.targetClass = targetClass;
    record.selector = selector;
    record.classMethod = classMethod;
    record.keyedGetter = keyedGetter;
    record.original = original;
    os_unfair_lock_lock(&gPXPrivateWrapperLock);
    [gPXPrivateWrapperInstalled addObject:record];
    os_unfair_lock_unlock(&gPXPrivateWrapperLock);
}

static void PXPrivateIdentityInstallAvailableRules(void) {
    if (!PXPrivateIdentityProcessAllowed()) return;

    for (NSDictionary<NSString *, id> *rule in PXPrivateIdentityWrapperRuleDescriptors()) {
        NSString *className = rule[@"class"];
        NSString *selectorName = rule[@"selector"];
        BOOL classMethod = [rule[@"classMethod"] boolValue];
        BOOL keyedGetter = [rule[@"keyedGetter"] boolValue];
        if (!className.length || !selectorName.length) continue;

        Class cls = objc_getClass(className.UTF8String);
        if (!cls || !PXPrivateIdentityClassIsSystemOwned(cls)) continue;
        SEL selector = NSSelectorFromString(selectorName);
        Method method = classMethod ? class_getClassMethod(cls, selector)
                                    : class_getInstanceMethod(cls, selector);
        if (!method) continue;
        const char *types = method_getTypeEncoding(method);
        if (!PXPrivateIdentityWrapperMethodEncodingIsSupported(types, keyedGetter)) {
            if (PXLogOnceClaim(@"PrivateIdentityWrapper.unsupportedEncoding",
                               [NSString stringWithFormat:@"%@|%@|%d", className, selectorName, classMethod])) {
                PXLog(@"[PrivateIdentityWrapper] unsupported encoding class=%@ selector=%@ meta=%d",
                      className, selectorName, classMethod);
            }
            continue;
        }

        Class targetClass = classMethod ? object_getClass((id)cls) : cls;
        if (!targetClass || PXPrivateIdentityAlreadyInstalled(targetClass, selector, classMethod)) continue;

        IMP original = NULL;
        IMP replacement = keyedGetter ? (IMP)PXPrivateIdentityKeyedGetter
                                      : (IMP)PXPrivateIdentityGetter;
        MSHookMessageEx(targetClass, selector, replacement, &original);
        if (!original) continue;
        PXPrivateIdentityPublishInstalled(targetClass,
                                          selector,
                                          classMethod,
                                          keyedGetter,
                                          original);
        PXLog(@"[PrivateIdentityWrapper] installed class=%@ selector=%@ meta=%d keyed=%d",
              className, selectorName, classMethod, keyedGetter);
    }
}

static void PXPrivateIdentityDyldImageAdded(const struct mach_header *header, intptr_t slide) {
    (void)header;
    (void)slide;
    if (!gPXPrivateWrapperInstallQueue) return;
    dispatch_async(gPXPrivateWrapperInstallQueue, ^{
        PXPrivateIdentityInstallAvailableRules();
    });
}

%ctor {
    @autoreleasepool {
        if (!PXPrivateIdentityProcessAllowed()) return;
        gPXPrivateWrapperInstalled = [NSMutableArray array];
        gPXPrivateWrapperInstallQueue =
            dispatch_queue_create("com.hydra.tlinkios.private-identity-wrapper", DISPATCH_QUEUE_SERIAL);
        PXPrivateIdentityInstallAvailableRules();
        _dyld_register_func_for_add_image(PXPrivateIdentityDyldImageAdded);
        PXLog(@"[PrivateIdentityWrapper] capability-gated Apple wrapper monitor initialized");
    }
}
