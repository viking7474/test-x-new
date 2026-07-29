#import <Foundation/Foundation.h>
#include <stdint.h>

NS_ASSUME_NONNULL_BEGIN

/// Immutable, process-local view of the active profile. All identity providers
/// should read one published object instead of independently re-reading plists.
@interface PXIdentitySnapshot : NSObject

@property (nonatomic, copy, readonly, nullable) NSString *profileID;
@property (nonatomic, readonly) uint64_t generation;
@property (nonatomic, strong, readonly) NSNumber *generationNumber;
@property (nonatomic, copy, readonly) NSDictionary *deviceIDs;
@property (nonatomic, copy, readonly) NSDictionary *settings;
@property (nonatomic, copy, readonly) NSDictionary *specs;
@property (nonatomic, copy, readonly, nullable) NSString *deviceModel;
@property (nonatomic, copy, readonly) NSString *source;
@property (nonatomic, readonly, getter=isValid) BOOL valid;

@end

/// Return the last complete publication, lazily loading the active profile once.
FOUNDATION_EXPORT PXIdentitySnapshot *PXCurrentIdentitySnapshot(void);

/// Re-read the active profile and atomically publish the newest completed request.
/// Out-of-order reloads cannot overwrite a newer publication.
FOUNDATION_EXPORT PXIdentitySnapshot *PXReloadIdentitySnapshot(NSString * _Nullable reason);

/// Drop the process-local publication. The next read performs a lazy reload.
FOUNDATION_EXPORT void PXInvalidateIdentitySnapshot(void);

/// Register the canonical Darwin notification observers once per process.
FOUNDATION_EXPORT void PXIdentitySnapshotStartObserving(void);

/// Compatibility accessor for existing hook call sites.
FOUNDATION_EXPORT NSDictionary * _Nullable PXDeviceIDsSnapshot(NSString * _Nullable * _Nullable outProfileID,
                                                               NSNumber * _Nullable * _Nullable outGeneration);

NS_ASSUME_NONNULL_END
