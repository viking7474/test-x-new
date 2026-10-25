#import "PXRuntimeSourceStore.h"
NS_ASSUME_NONNULL_BEGIN
/// Stage a canonical/legacy selection pair. No defaults, callbacks or notifications.
FOUNDATION_EXPORT BOOL PXStageRuntimeProfileSelection(PXRuntimeSourceTransaction *transaction,
    NSDictionary *info, NSString *centralPath, NSString *legacyPath, NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT NSDictionary * _Nullable PXReadRuntimeProfileSelection(PXRuntimeSourceTransaction *transaction,
    NSString *centralPath, NSString *legacyPath, NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT BOOL PXRuntimeProfileSelectionMatches(PXRuntimeSourceTransaction *transaction, NSDictionary *expected,
    NSString *centralPath, NSString *legacyPath, NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT BOOL PXStageRuntimeProfileSelectionIfUnchanged(PXRuntimeSourceTransaction *transaction,
    NSDictionary *info, NSDictionary *expected, NSString *centralPath, NSString *legacyPath, NSError * _Nullable * _Nullable error);
NS_ASSUME_NONNULL_END
