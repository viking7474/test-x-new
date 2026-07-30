#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Loads iPhone model specifications from the versioned iOS database publication.
@interface IPhoneModelDB : NSObject

+ (instancetype)sharedManager;

- (BOOL)loadIfNeeded:(NSError * _Nullable * _Nullable)error;

/// Version metadata shared with IOSBuildDB.
@property (nonatomic, copy, readonly, nullable) NSString *databaseVersion;
@property (nonatomic, copy, readonly) NSDictionary *databaseMetadata;

/// Reload atomically; the current generation remains usable if validation fails.
- (BOOL)reload:(NSError * _Nullable * _Nullable)error;

/// Drop cached roots so the next query loads one complete database generation.
- (void)invalidate;

/// Returns a random model whose maxIOS >= minIOS (inclusive).
- (NSDictionary * _Nullable)randomModelMinIOS:(NSString *)minIOS error:(NSError * _Nullable * _Nullable)error;

/// Returns the model spec for the exact productType.
- (NSDictionary * _Nullable)specForProductType:(NSString *)productType;

/// Returns YES if a productType exists in the DB.
- (BOOL)containsProductType:(NSString *)productType;

@end

NS_ASSUME_NONNULL_END
