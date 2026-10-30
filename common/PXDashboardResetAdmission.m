#import "PXDashboardResetAdmission.h"

static __weak id PXResetAdmissionOwner;
static NSObject *PXResetAdmissionToken;

NSObject *PXBeginDashboardResetAdmission(id owner) {
    if (!NSThread.isMainThread || !owner || PXResetAdmissionOwner) return nil;
    // A deallocated owner revokes its admission. Reclaim its small stale token
    // lazily; already submitted services may still finish without that UI owner.
    NSObject *token = [NSObject new];
    PXResetAdmissionOwner = owner;
    PXResetAdmissionToken = token;
    return token;
}

BOOL PXDashboardResetAdmissionMatches(id owner, NSObject *token) {
    return NSThread.isMainThread && owner && token && PXResetAdmissionOwner == owner && PXResetAdmissionToken == token;
}

BOOL PXFinishDashboardResetAdmission(id owner, NSObject *token) {
    if (!PXDashboardResetAdmissionMatches(owner, token)) return NO;
    PXResetAdmissionOwner = nil;
    PXResetAdmissionToken = nil;
    return YES;
}
