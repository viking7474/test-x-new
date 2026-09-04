#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Pure PAC-result projection used by VPNDetectionBypass.x and host tests.
///
/// When `bypassEnabled` is NO, or when `originalValue` is not a well-formed
/// array of proxy dictionaries with string `kCFProxyTypeKey` values, the exact
/// original object is returned (fail-open).  A valid enabled result preserves
/// array cardinality, dictionary shape and unknown keys while converting each
/// proxy entry to DIRECT and removing known endpoint/configuration fields.
FOUNDATION_EXPORT id _Nullable PXPACProjectedProxyValue(id _Nullable originalValue,
                                                        BOOL bypassEnabled);

NS_ASSUME_NONNULL_END
