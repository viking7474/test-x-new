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

/// Returns a random build meta for the given device model, constrained by version range.
/// The returned dictionary includes the selected build under key "build".
- (NSDictionary * _Nullable)randomMetaForDevice:(NSString *)productType
                                            min:(NSString *)minVersion
                                            max:(NSString *)maxVersion
                                          error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
