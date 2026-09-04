#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Pure projection helper shared by the live ManagedConfiguration hook and host tests.
/// Returns `originalValue` unless every gate is satisfied and the registry provides
/// a valid String projection for the requested ManagedConfiguration symbol.
FOUNDATION_EXPORT id _Nullable PXManagedConfigurationResolveValue(NSString *symbolName,
                                                                    id _Nullable originalValue,
                                                                    NSDictionary * _Nullable deviceIDs,
                                                                    BOOL scopeAllowed,
                                                                    BOOL toggleEnabled);

NS_ASSUME_NONNULL_END
