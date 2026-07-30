#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable PXCreateBackupProvenance(
    NSString *bundleIdentifier,
    NSString *profileIdentifier,
    NSNumber *profileGeneration,
    NSString *selectedScope,
    NSString *encryptionAlgorithm,
    NSString *externalKeyIdentifier);

FOUNDATION_EXPORT BOOL PXBackupProvenanceMatchesRestoreContext(
    NSDictionary<NSString *, id> *provenance,
    NSString *bundleIdentifier,
    NSString *profileIdentifier,
    NSNumber *profileGeneration,
    NSString *selectedScope);

FOUNDATION_EXPORT NSData *PXBackupProvenanceAssociatedData(NSDictionary<NSString *, id> *provenance);

NS_ASSUME_NONNULL_END
