#import "PXLocationDelegateHooks.h"
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#import <string.h>

@protocol PXLocationCallbackManager <NSObject>
- (id)delegate;
@end

typedef NS_ENUM(NSUInteger, PXLocationCallbackKind) {
    PXLocationCallbackBatch,
    PXLocationCallbackLegacy,
    PXLocationCallbackHeading,
    PXLocationCallbackRegion,
};

@interface PXLocationDelegateHook : NSObject
@property (atomic, assign) IMP original;
@property (nonatomic, assign) Class owner;
@property (nonatomic, assign) PXLocationCallbackKind kind;
@property (nonatomic, assign) PXLocationDelegateSnapshotProvider provider;
@property (nonatomic, assign) PXLocationDelegateSnapshotAttacher attacher;
@end
@implementation PXLocationDelegateHook
@end

typedef struct PXLocationCallbackFrame {
    __unsafe_unretained id receiver;
    __unsafe_unretained id manager;
    SEL selector;
    __unsafe_unretained Class owner;
    struct PXLocationCallbackFrame *previous;
} PXLocationCallbackFrame;
static __thread PXLocationCallbackFrame *gPXLocationCallbackFrame;

static NSRecursiveLock *PXLocationDelegateInstallationLock(void) {
    static NSRecursiveLock *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [NSRecursiveLock new]; });
    return lock;
}

// Only class objects and hook records live in this registry. There is no
// associated manager/delegate state, observer or cleanup callback to outlive it.
static NSMapTable *PXLocationDelegateRegistry(void) {
    static NSMapTable *registry;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        registry = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality
                                        valueOptions:NSPointerFunctionsStrongMemory];
    });
    return registry;
}

static BOOL PXLocationObjectType(const char *type) {
    return type[0] == '@' && (type[1] == '\0' || type[1] == '"');
}

static BOOL PXLocationDelegateMethodMatches(Method method, BOOL legacy) {
    if (!method || method_getNumberOfArguments(method) != (legacy ? 5u : 4u)) return NO;
    char type[64] = {0};
    method_getReturnType(method, type, sizeof(type));
    if (strcmp(type, @encode(void)) != 0) return NO;
    for (unsigned int index = 0; index < (legacy ? 5u : 4u); index++) {
        method_getArgumentType(method, index, type, sizeof(type));
        if (index == 1 ? strcmp(type, @encode(SEL)) != 0 : !PXLocationObjectType(type)) return NO;
    }
    return YES;
}

static BOOL PXLocationIsSuperCallback(id receiver, id manager, SEL selector, Class owner) {
    for (PXLocationCallbackFrame *frame = gPXLocationCallbackFrame; frame; frame = frame->previous) {
        if (frame->receiver != receiver || frame->manager != manager || frame->selector != selector) continue;
        for (Class ancestor = class_getSuperclass(frame->owner); ancestor; ancestor = class_getSuperclass(ancestor)) {
            if (ancestor == owner) return YES;
        }
    }
    return NO;
}

static void PXLocationProjectCallback(PXLocationDelegateHook *hook, id receiver, id manager, id first, id second) {
    // Cached/queued callbacks to a previous delegate still forward, but must not
    // advance projection after replacement or setDelegate:nil. No weak registry
    // or extra owner of either instance is needed: use the native relationship.
    if (!manager || ![manager respondsToSelector:@selector(delegate)] ||
        [(id<PXLocationCallbackManager>)manager delegate] != receiver) return;
    if (hook.kind == PXLocationCallbackBatch) {
        NSArray *locations = first;
        if (!locations.count) return;
        id snapshot = hook.provider(YES);
        if (snapshot) {
            for (id location in locations) hook.attacher(location, snapshot);
        }
    } else if (hook.kind == PXLocationCallbackLegacy) {
        if (!first && !second) return;
        id snapshot = hook.provider(YES);
        if (snapshot) {
            hook.attacher(first, snapshot);
            hook.attacher(second, snapshot);
        }
    } else {
        id snapshot = hook.provider(NO);
        if (snapshot && hook.kind == PXLocationCallbackHeading) hook.attacher(first, snapshot);
    }
}

static void PXLocationForwardCallback(PXLocationDelegateHook *hook, id receiver, SEL selector,
                                      id manager, id first, id second) {
    BOOL isSuper = PXLocationIsSuperCallback(receiver, manager, selector, hook.owner);
    PXLocationCallbackFrame frame = {receiver, manager, selector, hook.owner, gPXLocationCallbackFrame};
    gPXLocationCallbackFrame = &frame;
    @try {
        if (!isSuper) {
            @try {
                PXLocationProjectCallback(hook, receiver, manager, first, second);
            } @catch (__unused NSException *exception) {
                // Projection failure must not swallow the application's update.
            }
        }
        IMP original = hook.original;
        if (hook.kind == PXLocationCallbackLegacy) {
            ((void (*)(id, SEL, id, id, id))original)(receiver, selector, manager, first, second);
        } else {
            ((void (*)(id, SEL, id, id))original)(receiver, selector, manager, first);
        }
    } @finally {
        // Exceptions thrown by the delegate itself propagate unchanged.
        gPXLocationCallbackFrame = frame.previous;
    }
}

static BOOL PXLocationInstallSelector(Class cls, NSMutableDictionary *methods, NSString *name,
                                      PXLocationCallbackKind kind,
                                      PXLocationDelegateSnapshotProvider provider,
                                      PXLocationDelegateSnapshotAttacher attacher) {
    if (methods[name]) return YES;
    SEL selector = NSSelectorFromString(name);
    Method method = class_getInstanceMethod(cls, selector);
    if (!PXLocationDelegateMethodMatches(method, kind == PXLocationCallbackLegacy)) return NO;
    PXLocationDelegateHook *hook = [PXLocationDelegateHook new];
    hook.original = method_getImplementation(method);
    if (!hook.original) return NO;
    hook.owner = cls;
    hook.kind = kind;
    hook.provider = provider;
    hook.attacher = attacher;
    IMP replacement;
    if (kind == PXLocationCallbackLegacy) {
        replacement = imp_implementationWithBlock(^(id receiver, id manager, id first, id second) {
            PXLocationForwardCallback(hook, receiver, selector, manager, first, second);
        });
    } else {
        replacement = imp_implementationWithBlock(^(id receiver, id manager, id first) {
            PXLocationForwardCallback(hook, receiver, selector, manager, first, nil);
        });
    }
    if (!replacement) return NO;
    methods[name] = hook;
    // Add on the concrete class for inherited methods; never overwrite the
    // Method returned for an ancestor. The seeded original is callable as soon
    // as a replacement becomes visible to another thread.
    if (!class_addMethod(cls, selector, replacement, method_getTypeEncoding(method))) {
        IMP previous = method_setImplementation(class_getInstanceMethod(cls, selector), replacement);
        if (previous && previous != replacement) hook.original = previous;
    }
    return YES;
}

NSUInteger PXInstallLocationDelegateHooks(id delegate, PXLocationDelegateSnapshotProvider provider,
                                          PXLocationDelegateSnapshotAttacher attacher) {
    if (!delegate || !provider || !attacher) return 0;
    Class cls = object_getClass(delegate);
    // Even an explicitly passed root-class instance cannot broaden NSObject or
    // NSProxy's optional-selector surface for the rest of the process.
    if (!cls || class_isMetaClass(cls) || cls == NSObject.class || cls == NSProxy.class) return 0;
    NSRecursiveLock *lock = PXLocationDelegateInstallationLock();
    [lock lock];
    @try {
        NSMapTable *registry = PXLocationDelegateRegistry();
        NSMutableDictionary *methods = [registry objectForKey:cls];
        if (!methods) {
            methods = [NSMutableDictionary dictionary];
            [registry setObject:methods forKey:cls];
        }
        NSUInteger installed = 0;
        installed += PXLocationInstallSelector(cls, methods, @"locationManager:didUpdateLocations:", PXLocationCallbackBatch, provider, attacher);
        installed += PXLocationInstallSelector(cls, methods, @"locationManager:didUpdateToLocation:fromLocation:", PXLocationCallbackLegacy, provider, attacher);
        installed += PXLocationInstallSelector(cls, methods, @"locationManager:didUpdateHeading:", PXLocationCallbackHeading, provider, attacher);
        installed += PXLocationInstallSelector(cls, methods, @"locationManager:didEnterRegion:", PXLocationCallbackRegion, provider, attacher);
        installed += PXLocationInstallSelector(cls, methods, @"locationManager:didExitRegion:", PXLocationCallbackRegion, provider, attacher);
        return installed;
    } @finally {
        [lock unlock];
    }
}
