#import <Foundation/Foundation.h>
#import "PXIdentitySurfaceRegistry.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSArray<NSDictionary<NSString *, id> *> *PXPrivateIdentityWrapperRuleDescriptors(void);
FOUNDATION_EXPORT BOOL PXPrivateIdentityWrapperMethodEncodingIsSupported(const char * _Nullable types,
                                                                          BOOL keyedGetter);
FOUNDATION_EXPORT id _Nullable PXPrivateIdentityWrapperProjectObject(id _Nullable original,
                                                                      NSString *surfaceKey,
                                                                      NSDictionary *deviceIDs);
/// LaunchServices identity accessors are object-typed at the ABI level but are
/// expected to return NSUUID. Preserve the original unless both its runtime
/// shape and the canonical profile UUID are valid.
FOUNDATION_EXPORT id _Nullable PXPrivateIdentityWrapperProjectUUID(id _Nullable original,
                                                                    NSString *surfaceKey,
                                                                    NSDictionary *deviceIDs);
FOUNDATION_EXPORT id _Nullable PXPrivateIdentityWrapperProjectKeyedObject(id _Nullable original,
                                                                           NSString *queriedKey,
                                                                           NSDictionary *deviceIDs,
                                                                           PXIdentitySurfaceEntry * _Nullable * _Nullable outEntry);

NS_ASSUME_NONNULL_END
