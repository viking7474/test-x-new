#import "PXRuntimeSourceStore.h"

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString * _Nullable PXRuntimeIdentifierSidecar(NSString *type);
FOUNDATION_EXPORT NSSet<NSString *> *PXRuntimeIdentifierSidecars(void);
/// Preserves historical integerValue/default-zero behavior, rejects signed overflow.
FOUNDATION_EXPORT BOOL PXAdvanceRuntimeIdentifierGeneration(NSMutableDictionary *ids, NSError * _Nullable * _Nullable error);
/// Pure staging with explicit target. The caller prepares values before entering
/// the source gate and performs compatibility-manager side effects after commit.
FOUNDATION_EXPORT BOOL PXStageRuntimeIdentifierState(PXRuntimeSourceTransaction *transaction,
    NSString *identityDirectory, NSDictionary *updates, NSDictionary<NSString *, NSDictionary *> *sidecars,
    BOOL incrementGeneration, NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT BOOL PXStageRuntimeIdentifierValue(PXRuntimeSourceTransaction *transaction,
    NSString *identityDirectory, NSString *type, NSString *value, NSDate *timestamp,
    BOOL incrementGeneration, NSError * _Nullable * _Nullable error);
NS_ASSUME_NONNULL_END
