#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Loads iOS build metadata from the versioned iOS database publication.
@interface IOSBuildDB : NSObject

+ (instancetype)sharedManager;

- (BOOL)loadIfNeeded:(NSError * _Nullable * _Nullable)error;

/// Version metadata shared with IPhoneModelDB.
@property (nonatomic, copy, readonly, nullable) NSString *databaseVersion;
@property (nonatomic, copy, readonly) NSDictionary *databaseMetadata;

/// Reload atomically; the current generation remains usable if validation fails.
- (BOOL)reload:(NSError * _Nullable * _Nullable)error;

/// Drop cached roots so the next query loads one complete database generation.
- (void)invalidate;

/// All distinct iOS versions present in the currently published build database,
/// sorted as semantic versions. UI range pickers should use this instead of
/// maintaining a separate hard-coded version list.
- (NSArray<NSString *> *)availableVersions;

/// Returns YES only when the exact build is listed for the exact ProductType in
/// the currently published coherent DB generation.
- (BOOL)productType:(NSString *)productType supportsBuild:(NSString *)build;

/// Returns metadata for an exact build, or nil when it is unknown/malformed.
- (NSDictionary * _Nullable)metaForBuild:(NSString *)build;

/// Returns a random build meta for the given device model, constrained by version range.
/// The returned dictionary includes the selected build under key "build".
- (NSDictionary * _Nullable)randomMetaForDevice:(NSString *)productType
                                            min:(NSString *)minVersion
                                            max:(NSString *)maxVersion
                                          error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
