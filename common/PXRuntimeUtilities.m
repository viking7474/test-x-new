#import "PXRuntimeUtilities.h"
#import <os/lock.h>

// Immutable namespace -> immutable key set. Capture/publish owned roots only;
// validation, hashing, copying and retired-object destruction run outside lock.
static os_unfair_lock gPXLogOnceLock = OS_UNFAIR_LOCK_INIT;
static NSDictionary<NSString *, NSSet<NSString *> *> *gPXLogOnceClaims;
static __thread BOOL gPXLogOncePreparing;
static NSDictionary *PXLogOnceSnapshot(void) {
    NSDictionary *snapshot = nil;
    os_unfair_lock_lock(&gPXLogOnceLock);
    @try { snapshot = gPXLogOnceClaims; }
    @finally { os_unfair_lock_unlock(&gPXLogOnceLock); }
    return snapshot;
}
static BOOL PXLogOncePublish(NSDictionary *basis, NSDictionary *candidate) {
    __attribute__((objc_precise_lifetime)) NSDictionary *retired = nil;
    BOOL published = NO;
    @try {
        os_unfair_lock_lock(&gPXLogOnceLock);
        @try {
            if (gPXLogOnceClaims == basis) {
                retired = gPXLogOnceClaims; gPXLogOnceClaims = candidate; published = YES;
            }
        } @finally { os_unfair_lock_unlock(&gPXLogOnceLock); }
        return published;
    } @finally { basis = nil; candidate = nil; retired = nil; }
}
BOOL PXLogOnceClaim(NSString *namespaceName, NSString *key) {
    NSString *space = nil, *frozenKey = nil;
    NSDictionary *basis = nil, *candidate = nil;
    NSMutableDictionary *namespaces = nil;
    NSMutableSet *keys = nil;
    BOOL previous = gPXLogOncePreparing;
    @try {
        if (previous) return NO;
        gPXLogOncePreparing = YES;
        if (![namespaceName isKindOfClass:NSString.class] || ![key isKindOfClass:NSString.class] ||
            !namespaceName.length || !key.length) return NO;
        space = [[NSString alloc] initWithString:namespaceName];
        frozenKey = [[NSString alloc] initWithString:key];
        if (!space.length || !frozenKey.length) return NO;
        for (;;) {
            basis = PXLogOnceSnapshot();
            if ([basis[space] containsObject:frozenKey]) return NO;
            namespaces = basis ? [basis mutableCopy] : [NSMutableDictionary dictionary];
            keys = [basis[space] mutableCopy] ?: [NSMutableSet set];
            [keys addObject:frozenKey]; namespaces[space] = [keys copy];
            candidate = [namespaces copy];
            if (PXLogOncePublish(basis, candidate)) return YES;
            basis = nil; candidate = nil; namespaces = nil; keys = nil;
        }
    } @finally {
        gPXLogOncePreparing = previous;
        namespaceName = nil; key = nil; space = nil; frozenKey = nil;
        basis = nil; candidate = nil; namespaces = nil; keys = nil;
    }
}
void PXLogOnceResetNamespace(NSString *namespaceName) {
    NSString *space = nil;
    NSDictionary *basis = nil, *candidate = nil;
    NSMutableDictionary *namespaces = nil;
    BOOL previous = gPXLogOncePreparing;
    @try {
        if (previous) return;
        gPXLogOncePreparing = YES;
        if (![namespaceName isKindOfClass:NSString.class] || !namespaceName.length) return;
        space = [[NSString alloc] initWithString:namespaceName];
        if (!space.length) return;
        for (;;) {
            basis = PXLogOnceSnapshot();
            if (!basis[space]) return;
            namespaces = [basis mutableCopy]; [namespaces removeObjectForKey:space];
            candidate = [namespaces copy];
            if (PXLogOncePublish(basis, candidate)) return;
            basis = nil; candidate = nil; namespaces = nil;
        }
    } @finally {
        gPXLogOncePreparing = previous;
        namespaceName = nil; space = nil; basis = nil; candidate = nil; namespaces = nil;
    }
}
