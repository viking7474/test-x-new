#import "MethodSwizzler.h"
#import <string.h>

@implementation MethodSwizzler

// Returns YES only when it is ABI-safe to install the swizzle.
// Guards against mismatched Objective-C type encodings, which otherwise
// corrupt registers or crash when the runtime calls through the exchanged
// implementation (e.g. an object-returning IMP installed over a
// double-returning getter such as -[NEHotspotNetwork signalStrength]).
static BOOL PXMethodSwizzleTypesCompatible(Method original, Method swizzled) {
    if (!original || !swizzled) return NO;

    const char *origEnc = method_getTypeEncoding(original);
    const char *swizEnc = method_getTypeEncoding(swizzled);
    if (!origEnc || !swizEnc) return NO;
    if (strcmp(origEnc, swizEnc) == 0) return YES;

    // Full encodings can legitimately differ across SDKs (argument-frame
    // offsets), but the return type and argument count must always match or
    // the calling convention is violated.
    char origRet[64] = {0};
    char swizRet[64] = {0};
    @try {
        method_getReturnType(original, origRet, sizeof(origRet));
        method_getReturnType(swizzled, swizRet, sizeof(swizRet));
    } @catch (__unused NSException *e) {
        return NO;
    }
    if (origRet[0] == '\0' || swizRet[0] == '\0') return NO;
    if (strcmp(origRet, swizRet) != 0) return NO;
    if (method_getNumberOfArguments(original) != method_getNumberOfArguments(swizzled)) return NO;
    return YES;
}

+ (void)swizzleClass:(Class)cls originalSelector:(SEL)originalSelector swizzledSelector:(SEL)swizzledSelector {
    if (!cls || !originalSelector || !swizzledSelector) {
        NSLog(@"[WeaponX] MethodSwizzler: nil class/selector, skipping instance swizzle");
        return;
    }

    Method originalMethod = class_getInstanceMethod(cls, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(cls, swizzledSelector);

    if (!originalMethod || !swizzledMethod) {
        NSLog(@"[WeaponX] MethodSwizzler: method not found on %@ (%s -> %s), skipping",
              NSStringFromClass(cls), sel_getName(originalSelector), sel_getName(swizzledSelector));
        return;
    }

    if (!PXMethodSwizzleTypesCompatible(originalMethod, swizzledMethod)) {
        NSLog(@"[WeaponX] MethodSwizzler: ABI/type-encoding mismatch for -[%@ %s] (orig=%s swiz=%s), refusing to swizzle",
              NSStringFromClass(cls), sel_getName(originalSelector),
              method_getTypeEncoding(originalMethod) ?: "?", method_getTypeEncoding(swizzledMethod) ?: "?");
        return;
    }

    BOOL didAddMethod = class_addMethod(cls,
                                       originalSelector,
                                       method_getImplementation(swizzledMethod),
                                       method_getTypeEncoding(swizzledMethod));

    if (didAddMethod) {
        class_replaceMethod(cls,
                           swizzledSelector,
                           method_getImplementation(originalMethod),
                           method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

+ (void)swizzleClassMethod:(Class)cls originalSelector:(SEL)originalSelector swizzledSelector:(SEL)swizzledSelector {
    if (!cls || !originalSelector || !swizzledSelector) {
        NSLog(@"[WeaponX] MethodSwizzler: nil class/selector, skipping class swizzle");
        return;
    }

    Class metaClass = object_getClass(cls);
    Method originalMethod = class_getClassMethod(cls, originalSelector);
    Method swizzledMethod = class_getClassMethod(cls, swizzledSelector);

    if (!metaClass || !originalMethod || !swizzledMethod) {
        NSLog(@"[WeaponX] MethodSwizzler: class method not found on %@ (%s -> %s), skipping",
              NSStringFromClass(cls), sel_getName(originalSelector), sel_getName(swizzledSelector));
        return;
    }

    if (!PXMethodSwizzleTypesCompatible(originalMethod, swizzledMethod)) {
        NSLog(@"[WeaponX] MethodSwizzler: ABI/type-encoding mismatch for +[%@ %s] (orig=%s swiz=%s), refusing to swizzle",
              NSStringFromClass(cls), sel_getName(originalSelector),
              method_getTypeEncoding(originalMethod) ?: "?", method_getTypeEncoding(swizzledMethod) ?: "?");
        return;
    }

    BOOL didAddMethod = class_addMethod(metaClass,
                                       originalSelector,
                                       method_getImplementation(swizzledMethod),
                                       method_getTypeEncoding(swizzledMethod));

    if (didAddMethod) {
        class_replaceMethod(metaClass,
                           swizzledSelector,
                           method_getImplementation(originalMethod),
                           method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

@end
