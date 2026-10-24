#import "PXDomainTaskBlocker.h"
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#import <string.h>

static char kPXDomainSessionPredicate;
static char kPXDomainTaskPolicy;
static __thread void *gPXDomainResumingTask;

@interface PXDomainTaskPolicy : NSObject
@property (nonatomic, copy) PXDomainTaskBlockPredicate predicate;
@property (nonatomic, copy) NSString *initialHost;
@end
@implementation PXDomainTaskPolicy
@end

// The original IMP is seeded before publication and updated atomically with the
// IMP returned by the runtime. A racing message always has a callable fallback.
@interface PXDomainMethodHook : NSObject
@property (atomic, assign) IMP original;
@end
@implementation PXDomainMethodHook
@end

typedef NS_ENUM(NSUInteger, PXDomainFactoryKind) {
    PXDomainFactoryObject,
    PXDomainFactoryObjectBlock,
    PXDomainFactoryTwoObjects,
    PXDomainFactoryTwoObjectsBlock,
    PXDomainFactoryHostPort,
};

static NSRecursiveLock *PXDomainInstallationLock(void) {
    static NSRecursiveLock *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [[NSRecursiveLock alloc] init]; });
    return lock;
}

static NSMapTable *PXDomainInstalledMethods(void) {
    static NSMapTable *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality
                                     valueOptions:NSPointerFunctionsStrongMemory];
    });
    return table;
}

static BOOL PXDomainTypeMatches(const char *actual, const char *expected) {
    // Named object encodings (e.g. @"NSURLRequest") still have object ABI;
    // a block (@?) must remain distinct from an ordinary object argument.
    if (strcmp(expected, @encode(id)) == 0) {
        return actual[0] == '@' && (actual[1] == '\0' || actual[1] == '"');
    }
    return strcmp(actual, expected) == 0;
}

static BOOL PXDomainArgumentMatches(Method method, unsigned int index, const char *expected) {
    char actual[64] = {0};
    method_getArgumentType(method, index, actual, sizeof(actual));
    return PXDomainTypeMatches(actual, expected);
}

static BOOL PXDomainMethodMatches(Method method, BOOL resume, PXDomainFactoryKind kind) {
    if (!method) return NO;
    unsigned int count = resume ? 2 :
        (kind == PXDomainFactoryObject ? 3 : (kind == PXDomainFactoryTwoObjectsBlock ? 5 : 4));
    if (method_getNumberOfArguments(method) != count) return NO;
    char result[64] = {0};
    method_getReturnType(method, result, sizeof(result));
    if (!PXDomainTypeMatches(result, resume ? @encode(void) : @encode(id))) return NO;
    if (!PXDomainArgumentMatches(method, 0, @encode(id)) ||
        !PXDomainArgumentMatches(method, 1, @encode(SEL))) return NO;
    if (resume) return YES;
    if (!PXDomainArgumentMatches(method, 2, @encode(id))) return NO;
    if (kind == PXDomainFactoryObject) return YES;
    if (!PXDomainArgumentMatches(method, 3,
            kind == PXDomainFactoryHostPort ? @encode(NSInteger) :
            (kind == PXDomainFactoryObjectBlock ? "@?" : @encode(id)))) return NO;
    return kind != PXDomainFactoryTwoObjectsBlock || PXDomainArgumentMatches(method, 4, "@?");
}

static void PXDomainResumeTask(NSURLSessionTask *task, IMP original, SEL selector) {
    PXDomainTaskPolicy *policy = objc_getAssociatedObject(task, &kPXDomainTaskPolicy);
    if (!policy) {
        ((void (*)(id, SEL))original)(task, selector);
        return;
    }
    void *identity = (__bridge void *)task;
    void *previous = gPXDomainResumingTask;
    if (previous == identity) {
        ((void (*)(id, SEL))original)(task, selector);
        return;
    }
    gPXDomainResumingTask = identity;
    @try {
        NSURLSessionTaskState state = task.state;
        if (state != NSURLSessionTaskStateCompleted && state != NSURLSessionTaskStateCanceling) {
            NSString *host = task.currentRequest.URL.host ?: task.originalRequest.URL.host ?: policy.initialHost;
            if (host.length && policy.predicate(host)) {
                // Foundation owns cancellation, state/KVO, delegate queue and the
                // single terminal callback. Never invoke a user block ourselves.
                [task cancel];
            }
        }
        ((void (*)(id, SEL))original)(task, selector);
    } @finally {
        gPXDomainResumingTask = previous;
    }
}

static NSMutableDictionary *PXDomainMethodsForClass(Class cls) {
    NSMapTable *table = PXDomainInstalledMethods();
    NSMutableDictionary *methods = [table objectForKey:cls];
    if (!methods) {
        methods = [NSMutableDictionary dictionary];
        [table setObject:methods forKey:cls];
    }
    return methods;
}

static void PXDomainPublishMethod(Class cls, SEL selector, Method method,
                                  PXDomainMethodHook *hook, IMP replacement) {
    // class_addMethod isolates inherited implementations to this concrete class;
    // method_setImplementation is used only when the class already owns it.
    if (!class_addMethod(cls, selector, replacement, method_getTypeEncoding(method))) {
        IMP previous = method_setImplementation(class_getInstanceMethod(cls, selector), replacement);
        if (previous && previous != replacement) hook.original = previous;
    }
}

static BOOL PXDomainTrackTask(NSURLSessionTask *task, NSURLSession *session, NSString *initialHost) {
    PXDomainTaskBlockPredicate predicate = objc_getAssociatedObject(session, &kPXDomainSessionPredicate);
    if (!task || !predicate) return NO;
    NSRecursiveLock *lock = PXDomainInstallationLock();
    [lock lock];
    @try {
        PXDomainTaskPolicy *existing = objc_getAssociatedObject(task, &kPXDomainTaskPolicy);
        if (existing) {
            // A public factory can delegate to another hooked factory. Complete
            // a stream host hint by publishing a new policy, never mutating one
            // that a racing resume may already have retained.
            if (initialHost.length && !existing.initialHost.length) {
                PXDomainTaskPolicy *completed = [PXDomainTaskPolicy new];
                completed.predicate = existing.predicate;
                completed.initialHost = initialHost;
                objc_setAssociatedObject(task, &kPXDomainTaskPolicy, completed, OBJC_ASSOCIATION_RETAIN);
            }
            return YES;
        }
        Class cls = object_getClass(task);
        SEL selector = @selector(resume);
        NSMutableDictionary *methods = PXDomainMethodsForClass(cls);
        if (!methods[@"resume"]) {
            Method method = class_getInstanceMethod(cls, selector);
            if (!PXDomainMethodMatches(method, YES, PXDomainFactoryObject)) return NO;
            PXDomainMethodHook *hook = [PXDomainMethodHook new];
            hook.original = method_getImplementation(method);
            if (!hook.original) return NO;
            IMP replacement = imp_implementationWithBlock(^(NSURLSessionTask *receiver) {
                PXDomainResumeTask(receiver, hook.original, selector);
            });
            if (!replacement) return NO;
            methods[@"resume"] = hook;
            PXDomainPublishMethod(cls, selector, method, hook, replacement);
        }
        PXDomainTaskPolicy *policy = [PXDomainTaskPolicy new];
        policy.predicate = predicate;
        policy.initialHost = initialHost;
        objc_setAssociatedObject(task, &kPXDomainTaskPolicy, policy, OBJC_ASSOCIATION_RETAIN);
        return YES;
    } @finally {
        [lock unlock];
    }
}

static id PXDomainDidCreateTask(id task, id session, id argument, BOOL hostArgument) {
    // No task is resumed, cancelled or otherwise modified in a factory wrapper.
    PXDomainTrackTask(task, session, hostArgument ? argument : nil);
    return task;
}

static BOOL PXDomainInstallFactory(Class cls, NSString *name, PXDomainFactoryKind kind) {
    SEL selector = NSSelectorFromString(name);
    NSMutableDictionary *methods = PXDomainMethodsForClass(cls);
    if (methods[name]) return YES;
    Method method = class_getInstanceMethod(cls, selector);
    if (!PXDomainMethodMatches(method, NO, kind)) return NO;
    PXDomainMethodHook *hook = [PXDomainMethodHook new];
    hook.original = method_getImplementation(method);
    if (!hook.original) return NO;
    IMP replacement = NULL;
    // ARC gives captured block temporaries a lifetime. Keep each branch in its
    // own scope so another case label cannot jump into that lifetime.
    switch (kind) {
        case PXDomainFactoryObject: {
            replacement = imp_implementationWithBlock(^id(id session, id argument) {
                id task = ((id (*)(id, SEL, id))hook.original)(session, selector, argument);
                return PXDomainDidCreateTask(task, session, argument, NO);
            });
            break;
        }
        case PXDomainFactoryObjectBlock:
        case PXDomainFactoryTwoObjects: {
            replacement = imp_implementationWithBlock(^id(id session, id first, id second) {
                id task = ((id (*)(id, SEL, id, id))hook.original)(session, selector, first, second);
                return PXDomainDidCreateTask(task, session, first, NO);
            });
            break;
        }
        case PXDomainFactoryTwoObjectsBlock: {
            replacement = imp_implementationWithBlock(^id(id session, id first, id second, id completion) {
                id task = ((id (*)(id, SEL, id, id, id))hook.original)(session, selector, first, second, completion);
                return PXDomainDidCreateTask(task, session, first, NO);
            });
            break;
        }
        case PXDomainFactoryHostPort: {
            replacement = imp_implementationWithBlock(^id(id session, id host, NSInteger port) {
                id task = ((id (*)(id, SEL, id, NSInteger))hook.original)(session, selector, host, port);
                return PXDomainDidCreateTask(task, session, host, YES);
            });
            break;
        }
    }
    if (!replacement) return NO;
    methods[name] = hook;
    PXDomainPublishMethod(cls, selector, method, hook, replacement);
    return YES;
}

BOOL PXDomainObserveURLSession(NSURLSession *session, PXDomainTaskBlockPredicate predicate) {
    if (!session || !predicate) return NO;
    if (objc_getAssociatedObject(session, &kPXDomainSessionPredicate)) return YES;
    NSRecursiveLock *lock = PXDomainInstallationLock();
    [lock lock];
    @try {
        if (objc_getAssociatedObject(session, &kPXDomainSessionPredicate)) return YES;
        Class cls = object_getClass(session);
        NSUInteger installed = 0;
        for (NSString *name in @[@"dataTaskWithRequest:", @"dataTaskWithURL:",
                                 @"downloadTaskWithRequest:", @"downloadTaskWithURL:",
                                 @"downloadTaskWithResumeData:", @"uploadTaskWithStreamedRequest:",
                                 @"webSocketTaskWithRequest:", @"webSocketTaskWithURL:"]) {
            installed += PXDomainInstallFactory(cls, name, PXDomainFactoryObject);
        }
        for (NSString *name in @[@"dataTaskWithRequest:completionHandler:", @"dataTaskWithURL:completionHandler:",
                                 @"downloadTaskWithRequest:completionHandler:", @"downloadTaskWithURL:completionHandler:",
                                 @"downloadTaskWithResumeData:completionHandler:"]) {
            installed += PXDomainInstallFactory(cls, name, PXDomainFactoryObjectBlock);
        }
        for (NSString *name in @[@"uploadTaskWithRequest:fromData:", @"uploadTaskWithRequest:fromFile:",
                                 @"webSocketTaskWithURL:protocols:"]) {
            installed += PXDomainInstallFactory(cls, name, PXDomainFactoryTwoObjects);
        }
        for (NSString *name in @[@"uploadTaskWithRequest:fromData:completionHandler:",
                                 @"uploadTaskWithRequest:fromFile:completionHandler:"]) {
            installed += PXDomainInstallFactory(cls, name, PXDomainFactoryTwoObjectsBlock);
        }
        installed += PXDomainInstallFactory(cls, @"streamTaskWithHostName:port:", PXDomainFactoryHostPort);
        if (installed) objc_setAssociatedObject(session, &kPXDomainSessionPredicate, predicate, OBJC_ASSOCIATION_COPY);
        return installed != 0;
    } @finally {
        [lock unlock];
    }
}
