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

/// Resolves model-level P0 hardware metadata into the canonical DeviceSpec schema.
/// Variant-specific BoardID/HwModel/RegulatoryModelNumber is intentionally not selected here.
- (NSDictionary * _Nullable)canonicalHardwareSpecForProductType:(NSString *)productType;

/// Exact regional cellular capability for one regulatory A-number. Returns nil
/// when the model/A-number relation is unknown or the row is malformed.
- (NSDictionary * _Nullable)cellularSpecForProductType:(NSString *)productType
                                 regulatoryModelNumber:(NSString *)regulatoryModelNumber;

/// Exact build-specific baseband metadata for one ProductType/A-number/build tuple.
/// A known=false row or a build without authoritative firmware returns nil.
- (NSDictionary * _Nullable)basebandMetaForProductType:(NSString *)productType
                                  regulatoryModelNumber:(NSString *)regulatoryModelNumber
                                              iosBuild:(NSString *)iosBuild;

/// Returns YES if a productType exists in the DB.
- (BOOL)containsProductType:(NSString *)productType;

@end

NS_ASSUME_NONNULL_END
