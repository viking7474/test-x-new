#import "PXRuntimeUtilities.h"
#import <os/lock.h>

static os_unfair_lock gPXLogOnceLock = OS_UNFAIR_LOCK_INIT;
static NSMutableSet<NSString *> *gPXLogOnceClaims = nil;

static NSMutableSet<NSString *> *PXLogOnceClaims(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gPXLogOnceClaims = [NSMutableSet set];
    });
    return gPXLogOnceClaims;
}

static NSString *PXLogOnceCompositeKey(NSString *namespaceName, NSString *key) {
    if (![namespaceName isKindOfClass:[NSString class]] || !namespaceName.length ||
        ![key isKindOfClass:[NSString class]] || !key.length) {
        return nil;
    }
    return [NSString stringWithFormat:@"%@\x1f%@", namespaceName, key];
}

BOOL PXLogOnceClaim(NSString *namespaceName, NSString *key) {
    NSString *composite = PXLogOnceCompositeKey(namespaceName, key);
    if (!composite.length) return NO;

    NSMutableSet<NSString *> *claims = PXLogOnceClaims();
    os_unfair_lock_lock(&gPXLogOnceLock);
    BOOL firstClaim = ![claims containsObject:composite];
    if (firstClaim) [claims addObject:composite];
    os_unfair_lock_unlock(&gPXLogOnceLock);
    return firstClaim;
}

void PXLogOnceResetNamespace(NSString *namespaceName) {
    if (![namespaceName isKindOfClass:[NSString class]] || !namespaceName.length) return;
    NSString *prefix = [namespaceName stringByAppendingString:@"\x1f"];
    NSMutableSet<NSString *> *claims = PXLogOnceClaims();

    os_unfair_lock_lock(&gPXLogOnceLock);
    NSSet<NSString *> *snapshot = [claims copy];
    for (NSString *claim in snapshot) {
        if ([claim hasPrefix:prefix]) [claims removeObject:claim];
    }
    os_unfair_lock_unlock(&gPXLogOnceLock);
}
