#import "MethodSwizzler.h"
#include <string.h>
#include <stdlib.h>

static const char *PXSwizzleSkipQualifiers(const char *type) {
    while (type && *type && strchr("rnNoORV", *type)) type++;
    return type;
}
static BOOL PXSwizzleTypeEqual(const char *left, const char *right) {
    left = PXSwizzleSkipQualifiers(left); right = PXSwizzleSkipQualifiers(right);
    if (!left || !right || !*left || !*right) return NO;
    if (strcmp(left, right) == 0) return YES;
    // Class annotations do not change object calling convention. A block (@?)
    // is deliberately distinct from an ordinary object; other shapes stay exact.
    return left[0] == '@' && right[0] == '@' &&
        (left[1] == 0 || left[1] == '"') && (right[1] == 0 || right[1] == '"');
}
BOOL PXMethodHasCompatibleTypeEncoding(Method method, const char *encoding) {
    const char *original = method ? method_getTypeEncoding(method) : NULL;
    if (!original || !encoding || !*original || !*encoding) return NO;
    @try {
        NSMethodSignature *from = [NSMethodSignature signatureWithObjCTypes:original];
        NSMethodSignature *to = [NSMethodSignature signatureWithObjCTypes:encoding];
        if (!from || !to || from.numberOfArguments < 2 || from.numberOfArguments != to.numberOfArguments ||
            !PXSwizzleTypeEqual(from.methodReturnType, to.methodReturnType)) return NO;
        for (NSUInteger index = 0; index < from.numberOfArguments; index++) {
            if (!PXSwizzleTypeEqual([from getArgumentTypeAtIndex:index], [to getArgumentTypeAtIndex:index])) return NO;
        }
        return YES;
    } @catch (NSException *exception) { (void)exception; return NO; }
}

// Installation records intentionally live for the process, as do the registered
// application/framework classes used here. Access only under the shared monitor.
typedef struct PXSwizzleInstallation {
    __unsafe_unretained Class target;
    SEL original, alias;
    struct PXSwizzleInstallation *next;
} PXSwizzleInstallation;
static PXSwizzleInstallation *gPXSwizzleInstallations = NULL;

static BOOL PXSwizzleClassesRelated(Class left, Class right) {
    if (class_isMetaClass(left) != class_isMetaClass(right)) return NO;
    for (Class cls = left; cls; cls = class_getSuperclass(cls)) if (cls == right) return YES;
    for (Class cls = right; cls; cls = class_getSuperclass(cls)) if (cls == left) return YES;
    return NO;
}
static BOOL PXSwizzlePairInstalled(Class target, SEL original, SEL alias) {
    for (PXSwizzleInstallation *entry = gPXSwizzleInstallations; entry; entry = entry->next) {
        BOOL samePair = (entry->original == original && entry->alias == alias) ||
                        (entry->original == alias && entry->alias == original);
        // Reusing one alias at multiple hierarchy levels can recurse when a
        // child's original calls super. One owner per pair/hierarchy is admitted.
        if (samePair && PXSwizzleClassesRelated(target, entry->target)) return YES;
    }
    return NO;
}
static BOOL PXSwizzleHasOwnSelector(Class target, SEL selector) {
    unsigned count = 0;
    Method *methods = class_copyMethodList(target, &count);
    if (!methods) return NO;
    BOOL found = NO;
    for (unsigned index = 0; index < count; index++) {
        if (method_getName(methods[index]) == selector) { found = YES; break; }
    }
    free(methods);
    return found;
}
static void PXInstallLocalSwizzle(Class target, SEL original, SEL alias) {
    if (!target || !original || !alias || original == alias) return;
    @synchronized (MethodSwizzler.class) {
        if (PXSwizzlePairInstalled(target, original, alias)) return;
        Method from = class_getInstanceMethod(target, original);
        Method to = class_getInstanceMethod(target, alias);
        if (!from || !to || !PXMethodHasCompatibleTypeEncoding(from, method_getTypeEncoding(to))) {
            NSLog(@"[WeaponX] MethodSwizzler: missing/incompatible methods on %s (%s -> %s), skipping",
                class_getName(target), sel_getName(original), sel_getName(alias));
            return;
        }
        PXSwizzleInstallation *entry = calloc(1, sizeof(*entry));
        if (!entry) return;
        // Localize BOTH methods before exchange; never mutate an inherited
        // alias's Method in its superclass, even if the original is local.
        if ((!PXSwizzleHasOwnSelector(target, original) &&
             !class_addMethod(target, original, method_getImplementation(from), method_getTypeEncoding(from))) ||
            (!PXSwizzleHasOwnSelector(target, alias) &&
             !class_addMethod(target, alias, method_getImplementation(to), method_getTypeEncoding(to)))) {
            free(entry); return;
        }
        Method localOriginal = class_getInstanceMethod(target, original);
        Method localAlias = class_getInstanceMethod(target, alias);
        method_exchangeImplementations(localOriginal, localAlias);
        entry->target = target; entry->original = original; entry->alias = alias;
        entry->next = gPXSwizzleInstallations; gPXSwizzleInstallations = entry;
    }
}

@implementation MethodSwizzler
+ (void)swizzleClass:(Class)cls originalSelector:(SEL)originalSelector swizzledSelector:(SEL)swizzledSelector {
    PXInstallLocalSwizzle(cls, originalSelector, swizzledSelector);
}
+ (void)swizzleClassMethod:(Class)cls originalSelector:(SEL)originalSelector swizzledSelector:(SEL)swizzledSelector {
    PXInstallLocalSwizzle(cls ? object_getClass((id)cls) : Nil, originalSelector, swizzledSelector);
}
@end
