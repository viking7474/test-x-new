#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, PXClearScope) {
    PXClearScopeApplicationData = 1UL << 0,
    PXClearScopeExtensionData   = 1UL << 1,
    PXClearScopeAppGroups       = 1UL << 2,
    PXClearScopePluginKitData   = 1UL << 3,
    PXClearScopeKeychain        = 1UL << 4,
};

FOUNDATION_EXPORT const PXClearScope PXClearScopeKnownMask;
FOUNDATION_EXPORT const PXClearScope PXClearScopeDefaultMask;

__attribute__((objc_subclassing_restricted))
@interface PXClearRequest : NSObject <NSCopying> {
@private
    NSString *_bundleIdentifier;
    PXClearScope _scopes;
    BOOL _deepClean;
}

@property (nonatomic, copy, readonly) NSString *bundleIdentifier;
@property (nonatomic, assign, readonly) PXClearScope scopes;
@property (nonatomic, assign, readonly, getter=isDeepClean) BOOL deepClean;

- (nullable instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                                            scopes:(PXClearScope)scopes
                                         deepClean:(BOOL)deepClean
    NS_DESIGNATED_INITIALIZER;

+ (nullable instancetype)defaultRequestForBundleIdentifier:(NSString *)bundleIdentifier;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
