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

// Resolves the currently registered exact physical App Group container when MobileContainerManager is
// available. If that authority is unavailable, falls back to exact metadata scanning. A missing root or
// no exact match returns an empty array; resolver faults return nil plus error. Callers must still validate
// every returned model before mutation.
- (nullable NSArray<PXResolvedContainer *> *)resolveAllAppGroupContainersForGroupIdentifier:(NSString *)groupIdentifier
                                                                                       root:(PXResolvedContainerRoot)root
                                                                                      error:(NSError * _Nullable * _Nullable)error;

// Single-target resolver used by Restore and operations that require an unambiguous destination.
- (nullable PXResolvedContainer *)resolveAppGroupContainerForGroupIdentifier:(NSString *)groupIdentifier
                                                                        root:(PXResolvedContainerRoot)root
                                                                       error:(NSError * _Nullable * _Nullable)error;

// Maps each application-group identifier to at most one authoritative UUID/path. Ambiguous fallback
// filesystem matches are omitted rather than guessed.
- (NSArray<AppGroupContainerInfo *> *)resolveGroupContainersForGroupIDs:(NSArray<NSString *> *)groupIDs;

@end

NS_ASSUME_NONNULL_END
