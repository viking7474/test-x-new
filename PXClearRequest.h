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

/// Optional destructive policies are deliberately separate from the core scope
/// contract. They are snapshotted when the request is created so a setting
/// change cannot alter an in-flight Clear operation.
typedef NS_OPTIONS(NSUInteger, PXClearOptions) {
    PXClearOptionNone                = 0,
    PXClearOptionICloudData          = 1UL << 0,
    PXClearOptionSafariSharedWebData = 1UL << 1,
};

FOUNDATION_EXPORT const PXClearOptions PXClearOptionsKnownMask;

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
    PXClearOptions _options;
}

@property (nonatomic, copy, readonly) NSString *bundleIdentifier;
@property (nonatomic, assign, readonly) PXClearScope scopes;
@property (nonatomic, assign, readonly) PXClearMode mode;
@property (nonatomic, assign, readonly) PXClearOptions options;
/// Compatibility view for pre-Phase-8 callers. YES only for PXClearModeDeep.
@property (nonatomic, assign, readonly, getter=isDeepClean) BOOL deepClean;

- (nullable instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                                            scopes:(PXClearScope)scopes
                                              mode:(PXClearMode)mode
                                           options:(PXClearOptions)options
    NS_DESIGNATED_INITIALIZER;

/// Compatibility initializer. Optional destructive policies default to OFF.
- (nullable instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                                            scopes:(PXClearScope)scopes
                                              mode:(PXClearMode)mode;

/// Compatibility initializer: deepClean=NO maps to Full; YES maps to Deep.
/// Optional destructive policies default to OFF.
- (nullable instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                                            scopes:(PXClearScope)scopes
                                         deepClean:(BOOL)deepClean;

+ (nullable instancetype)defaultRequestForBundleIdentifier:(NSString *)bundleIdentifier;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
