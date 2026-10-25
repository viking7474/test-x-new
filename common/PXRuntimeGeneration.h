#import "PXRuntimeIdentifierWriter.h"

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSArray<NSString *> *PXRuntimeGenerationScalarTypes(void);
/// Deep-detach a prepared property-list payload. Conditions remain separate:
/// their NSNull absence sentinels are ephemeral and must never be persisted.
FOUNDATION_EXPORT NSDictionary * _Nullable PXDetachRuntimeGeneration(NSDictionary *payload, NSError * _Nullable * _Nullable error);
/// A detached receipt of committed artifacts; does not itself activate/publish.
@interface PXCommittedRuntimeGeneration : NSObject
@property (nonatomic, copy, readonly) NSString *identityDirectory;
@property (nonatomic, copy, readonly) NSDictionary *payload;
@property (nonatomic, copy, readonly) NSDictionary *proof;
@property (nonatomic, strong, readonly, nullable) PXPreparedDeviceProfileGroup *model;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (nullable instancetype)initWithIdentityDirectory:(NSString *)identity payload:(NSDictionary *)payload
    proof:(NSDictionary *)proof model:(nullable PXPreparedDeviceProfileGroup *)model error:(NSError * _Nullable * _Nullable)error;
@end
FOUNDATION_EXPORT BOOL PXStageRuntimeGenerationSettings(PXRuntimeSourceTransaction *transaction, NSDictionary *payload, NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT NSDictionary * _Nullable PXReadRuntimeGenerationProof(PXRuntimeSourceTransaction *transaction,
    NSString *identityDirectory, NSDictionary *payload, NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT BOOL PXRuntimeGenerationMatchesProof(PXRuntimeSourceTransaction *transaction,
    NSDictionary *proof, NSError * _Nullable * _Nullable error);
/// Stage only. No provider, active selection lookup, callback or notification.
/// Each condition is {values: {field: value-or-NSNull}, exists: optional Boolean}.
FOUNDATION_EXPORT BOOL PXStageRuntimeGeneration(PXRuntimeSourceTransaction *transaction, NSString *identityDirectory,
    NSDictionary *payload, NSDictionary<NSString *, NSDictionary *> *conditions,
    NSError * _Nullable * _Nullable error);
NS_ASSUME_NONNULL_END
