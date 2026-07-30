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

/// Phase-8 execution policy. Quick is intentionally application-scoped; Full
/// includes exact extension/App Group/PluginKit targets; Deep adds bounded
/// residual/system cleanup and the broad diagnostic verification pass.
typedef NS_ENUM(NSUInteger, PXClearMode) {
    PXClearModeQuick = 0,
    PXClearModeFull,
    PXClearModeDeep,
};

FOUNDATION_EXPORT BOOL PXClearModeIsValid(PXClearMode mode);
FOUNDATION_EXPORT NSString *PXClearModeName(PXClearMode mode);
FOUNDATION_EXPORT BOOL PXClearModeIncludesExtendedContainers(PXClearMode mode);
FOUNDATION_EXPORT BOOL PXClearModeIncludesDeepDiagnostics(PXClearMode mode);

__attribute__((objc_subclassing_restricted))
@interface PXClearRequest : NSObject <NSCopying> {
@private
    NSString *_bundleIdentifier;
    PXClearScope _scopes;
    PXClearMode _mode;
}

@property (nonatomic, copy, readonly) NSString *bundleIdentifier;
@property (nonatomic, assign, readonly) PXClearScope scopes;
@property (nonatomic, assign, readonly) PXClearMode mode;
/// Compatibility view for pre-Phase-8 callers. YES only for PXClearModeDeep.
@property (nonatomic, assign, readonly, getter=isDeepClean) BOOL deepClean;

- (nullable instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                                            scopes:(PXClearScope)scopes
                                              mode:(PXClearMode)mode
    NS_DESIGNATED_INITIALIZER;

/// Compatibility initializer: deepClean=NO maps to Full; YES maps to Deep.
- (nullable instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                                            scopes:(PXClearScope)scopes
                                         deepClean:(BOOL)deepClean;

+ (nullable instancetype)defaultRequestForBundleIdentifier:(NSString *)bundleIdentifier;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
