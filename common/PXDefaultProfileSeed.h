#import <Foundation/Foundation.h>
@class PXProfileLifecycleLease;

NS_ASSUME_NONNULL_BEGIN
/// Caller holds lifecycle for PXProfilesPath(). Preflight may create profile 0
/// and identity directories; those effects are outside source byte rollback.
/// Commit legacy display metadata and an empty identity only when it is absent.
/// Existing identity bytes are preserved; no selection/registry/cache effects.
FOUNDATION_EXPORT BOOL PXSeedDefaultProfile(PXProfileLifecycleLease *lease, NSError * _Nullable * _Nullable error);
NS_ASSUME_NONNULL_END
