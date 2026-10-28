#import <Foundation/Foundation.h>
@class PXProfileLifecycleLease;

NS_ASSUME_NONNULL_BEGIN
/// Commit the four legacy display plists of an existing profile together.
/// Fields: Name/Description strings, CreatedAt/LastUsed dates. The caller owns
/// lifecycle through return. Missing appdata creation precedes byte rollback;
/// registry archive persistence is a separate subsequent phase.
FOUNDATION_EXPORT BOOL PXWriteProfileDisplayMetadata(PXProfileLifecycleLease *lease, NSString *profileID,
    NSDictionary *fields, NSError * _Nullable * _Nullable error);
NS_ASSUME_NONNULL_END
