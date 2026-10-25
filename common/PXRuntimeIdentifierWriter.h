#import "PXRuntimeSourceStore.h"

NS_ASSUME_NONNULL_BEGIN
/// Detached immutable model/cellular preparation. Contains no transaction,
/// provider instance, callback or active-profile selection.
@interface PXPreparedDeviceProfileGroup : NSObject
@property (nonatomic, copy, readonly) NSDictionary *updates;
@property (nonatomic, copy, readonly) NSArray<NSString *> *replacedKeys;
@property (nonatomic, copy, readonly) NSDictionary *versionInfo;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (nullable instancetype)initWithUpdates:(NSDictionary *)updates replacedKeys:(NSArray<NSString *> *)keys
                            versionInfo:(NSDictionary *)versionInfo error:(NSError * _Nullable * _Nullable)error;
@end

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
/// Capture only fields a prepared update depends on. NSNull represents absence
/// in memory, never in a persisted plist. Conflict fails without partial writes.
FOUNDATION_EXPORT NSDictionary *PXRuntimeIdentifierDependencies(NSDictionary *ids, NSArray<NSString *> *keys);
FOUNDATION_EXPORT BOOL PXStageRuntimeIdentifierReplacement(PXRuntimeSourceTransaction *transaction,
    NSString *identityDirectory, NSDictionary *updates, NSArray<NSString *> *replacedKeys,
    NSDictionary * _Nullable expectedDependencies, BOOL incrementGeneration, BOOL removeLegacyCellular,
    NSError * _Nullable * _Nullable error);
/// Pair a prepared value and sidecar only if validation's captured basis is
/// still current. Does not perform generation, DB lookup or callbacks.
FOUNDATION_EXPORT BOOL PXStageRuntimeIdentifierValueWithDependencies(PXRuntimeSourceTransaction *transaction,
    NSString *identityDirectory, NSString *type, NSString *value, NSDate *timestamp,
    NSDictionary *expectedDependencies, NSError * _Nullable * _Nullable error);
NS_ASSUME_NONNULL_END
