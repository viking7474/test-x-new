#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, PXResolvedContainerKind) {
    PXResolvedContainerKindApplicationData = 1,
    PXResolvedContainerKindAppGroup = 2,
    PXResolvedContainerKindExtensionData = 3,
    PXResolvedContainerKindPluginKitData = 4,
};

typedef NS_ENUM(NSUInteger, PXResolvedContainerRoot) {
    PXResolvedContainerRootRootful = 1,
    PXResolvedContainerRootRootless = 2,
};

__attribute__((objc_subclassing_restricted))
@interface PXResolvedContainer : NSObject <NSCopying> {
@private
    PXResolvedContainerKind _kind;
    PXResolvedContainerRoot _root;
    NSString *_requestedIdentifier;
    NSString *_metadataIdentifier;
    NSString *_containerUUID;
    NSString *_containerPath;
}

@property (nonatomic, assign, readonly) PXResolvedContainerKind kind;
@property (nonatomic, assign, readonly) PXResolvedContainerRoot root;
@property (nonatomic, copy, readonly) NSString *requestedIdentifier;
@property (nonatomic, copy, readonly) NSString *metadataIdentifier;
@property (nonatomic, copy, readonly) NSString *containerUUID;
@property (nonatomic, copy, readonly) NSString *containerPath;

- (nullable instancetype)initWithKind:(PXResolvedContainerKind)kind
                                 root:(PXResolvedContainerRoot)root
                  requestedIdentifier:(NSString *)requestedIdentifier
                   metadataIdentifier:(NSString *)metadataIdentifier
                        containerUUID:(NSString *)containerUUID
                        containerPath:(NSString *)containerPath NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
