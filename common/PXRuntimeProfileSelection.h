#import "PXRuntimeSourceStore.h"
NS_ASSUME_NONNULL_BEGIN
/// Stage a canonical/legacy selection pair. No defaults, callbacks or notifications.
FOUNDATION_EXPORT BOOL PXStageRuntimeProfileSelection(PXRuntimeSourceTransaction *transaction,
    NSDictionary *info, NSString *centralPath, NSString *legacyPath, NSError * _Nullable * _Nullable error);
NS_ASSUME_NONNULL_END
