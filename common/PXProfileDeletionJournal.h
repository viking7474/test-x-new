#import "PXProfileLifecycleLease.h"
#import "PXRuntimeProfileSelection.h"

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, PXProfileDeletionResolution) {
    PXProfileDeletionNoPendingIntent,
    PXProfileDeletionAbortedPreparation,
    PXProfileDeletionCompleted,
    PXProfileDeletionCancelledForSelectionDrift
};
/// Validates secure archive semantics outside the source transaction. The
/// manager verifies that After removes exactly Target and preserves all others.
typedef BOOL (^PXProfileDeletionArchiveValidator)(NSDictionary *intent, NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT BOOL PXRequireNoPendingProfileDeletion(NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT BOOL PXPrepareProfileDeletion(PXProfileLifecycleLease *lease, NSDictionary *intent,
    PXProfileDeletionArchiveValidator validator, NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT BOOL PXCommitProfileDeletion(PXProfileLifecycleLease *lease, NSDictionary *prepared,
    NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT BOOL PXMarkProfileDeletionArchiveWritten(PXProfileLifecycleLease *lease, NSDictionary *prepared,
    NSError * _Nullable * _Nullable error);
/// Reconciles only known Before/After registry bytes. Never removes a directory
/// or changes selection, even when a committed deletion is replayed after exit.
FOUNDATION_EXPORT BOOL PXRecoverProfileDeletion(PXProfileLifecycleLease *lease,
    PXProfileDeletionArchiveValidator validator, PXProfileDeletionResolution *resolution,
    NSError * _Nullable * _Nullable error);

#if defined(PX_SOURCE_TRANSACTION_TESTING)
FOUNDATION_EXPORT void (^ _Nullable PXProfileDeletionTestCheckpoint)(NSString *stage);
#define PXProfileDeletionCheckpoint(stage) do { if (PXProfileDeletionTestCheckpoint) PXProfileDeletionTestCheckpoint(stage); } while (0)
#else
#define PXProfileDeletionCheckpoint(stage) do { } while (0)
#endif
NS_ASSUME_NONNULL_END
