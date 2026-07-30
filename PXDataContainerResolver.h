#import <Foundation/Foundation.h>

#import "PXResolvedContainer.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PXDataContainerResolverErrorDomain;

typedef NS_ENUM(NSInteger, PXDataContainerResolverErrorCode) {
    PXDataContainerResolverErrorInvalidInput = 1,
    PXDataContainerResolverErrorEnumerationFailed = 2,
    PXDataContainerResolverErrorAmbiguousMatch = 3,
    PXDataContainerResolverErrorInvalidCandidate = 4,
};

__attribute__((objc_subclassing_restricted))
@interface PXDataContainerResolver : NSObject

/// Process-local validated cache. Every hit is revalidated against the directory,
/// metadata file and exact MCM identifier before it can be returned.
+ (void)invalidateCachedContainerForIdentifier:(NSString *)identifier;
+ (void)invalidateAllCachedContainers;

- (nullable PXResolvedContainer *)resolveDataContainerForIdentifier:(NSString *)identifier
                                                               kind:(PXResolvedContainerKind)kind
                                                               root:(PXResolvedContainerRoot)root
                                                              error:(NSError * _Nullable * _Nullable)error;

- (nullable PXResolvedContainer *)resolveApplicationDataContainerForIdentifier:(NSString *)identifier
                                                                          root:(PXResolvedContainerRoot)root
                                                                         error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
