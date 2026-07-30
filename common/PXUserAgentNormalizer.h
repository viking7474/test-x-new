#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * _Nullable PXNormalizeUserAgent(NSString * _Nullable baseUserAgent,
                                                             NSString * _Nullable productVersion,
                                                             NSString * _Nullable productBuild,
                                                             BOOL replaceMobileBuild);
FOUNDATION_EXPORT NSDictionary<NSString *, NSString *> *PXCanonicalWebIdentityHeaders(NSDictionary * _Nullable headers,
                                                                                       NSString * _Nullable localeIdentifier,
                                                                                       BOOL mobilePlatform);
FOUNDATION_EXPORT BOOL PXWebKitHelperProcessIsInScope(NSString * _Nullable bundleIdentifier,
                                                       NSString * _Nullable processName,
                                                       BOOL explicitSafariStackPermission);

NS_ASSUME_NONNULL_END
