#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Semantic CoreTelephony server keys modeled from the six fields iFake rewrites.
FOUNDATION_EXPORT NSArray<NSString *> *PXCoreTelephonyServerSurfaceKeys(void);

/// Apply an identity overlay to an existing mutable MobileEquipmentInfo dictionary.
///
/// `runtimeKeysBySurfaceKey` maps semantic registry keys such as
/// `kCTMobileEquipmentInfoIMEI` to the actual key object used by the runtime
/// dictionary. Only keys already present in `information` are changed.
///
/// Returns YES when at least one existing field was replaced.
FOUNDATION_EXPORT BOOL PXCoreTelephonyServerApplyIdentityOverlay(
    NSMutableDictionary *information,
    NSDictionary<NSString *, id> *runtimeKeysBySurfaceKey,
    NSDictionary *deviceIDs,
    NSSet<NSString *> *enabledToggles);

NS_ASSUME_NONNULL_END
