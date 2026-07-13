#import <Foundation/Foundation.h>

#import "PXResolvedContainer.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PXAppGroupContainerResolverErrorDomain;

typedef NS_ENUM(NSInteger, PXAppGroupContainerResolverErrorCode) {
    PXAppGroupContainerResolverErrorInvalidInput = 1,
    PXAppGroupContainerResolverErrorEnumerationFailed = 2,
    PXAppGroupContainerResolverErrorAmbiguousMatch = 3,
    PXAppGroupContainerResolverErrorInvalidCandidate = 4,
    PXAppGroupContainerResolverErrorMetadataInvalid = 5,
};

@interface AppGroupContainerInfo : NSObject
@property (nonatomic, copy) NSString *groupID;
@property (nonatomic, copy) NSString *uuid;
@property (nonatomic, copy) NSString *path;
@end

@interface AppGroupContainerResolver : NSObject

- (nullable PXResolvedContainer *)resolveAppGroupContainerForGroupIdentifier:(NSString *)groupIdentifier
                                                                        root:(PXResolvedContainerRoot)root
                                                                       error:(NSError * _Nullable * _Nullable)error;

// Maps application group identifiers to AppGroup container UUID/path using exact metadata matches.
- (NSArray<AppGroupContainerInfo *> *)resolveGroupContainersForGroupIDs:(NSArray<NSString *> *)groupIDs;

@end

NS_ASSUME_NONNULL_END
