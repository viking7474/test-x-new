#import "PXRuntimeIdentifierWriter.h"

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSArray<NSString *> *PXRuntimeGenerationScalarTypes(void);
/// Deep-detach a prepared property-list payload. Conditions remain separate:
/// their NSNull absence sentinels are ephemeral and must never be persisted.
FOUNDATION_EXPORT NSDictionary * _Nullable PXDetachRuntimeGeneration(NSDictionary *payload, NSError * _Nullable * _Nullable error);
/// Stage only. No provider, active selection lookup, callback or notification.
/// Each condition is {values: {field: value-or-NSNull}, exists: optional Boolean}.
FOUNDATION_EXPORT BOOL PXStageRuntimeGeneration(PXRuntimeSourceTransaction *transaction, NSString *identityDirectory,
    NSDictionary *payload, NSDictionary<NSString *, NSDictionary *> *conditions,
    NSError * _Nullable * _Nullable error);
NS_ASSUME_NONNULL_END
