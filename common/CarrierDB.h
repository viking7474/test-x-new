#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Data-driven MCC/MNC + carrier names by ISO country.
/// Loads `/var/mobile/Library/WeaponX/Data/carrier_db.json` (schemaVersion 1).
/// Falls back to a small built-in set when the JSON is missing.
@interface CarrierDB : NSObject

+ (instancetype)sharedManager;

/// Ensure JSON is loaded. Returns YES if data is available (file or fallback).
- (BOOL)loadIfNeeded:(NSError * _Nullable * _Nullable)error;

/// ISO-3166 alpha-2 (e.g. @"US", @"VN"). Case-insensitive.
- (NSArray<NSDictionary *> *)carriersForCountry:(NSString *)countryCode;

/// Random entry from carriersForCountry:; never nil.
- (NSDictionary *)randomCarrierForCountry:(NSString *)countryCode;

/// Lookup by MCC+MNC (e.g. @"310", @"260") → @{name, mcc, mnc, country?} or nil.
- (NSDictionary * _Nullable)carrierForMCC:(NSString *)mcc mnc:(NSString *)mnc;

/// Display name for MCC/MNC; falls back to a sane default (never product branding).
- (NSString *)carrierNameForMCC:(NSString *)mcc mnc:(NSString *)mnc;

/// Region metadata for TargetRegion UI / pinning:
/// @{ carrierISO, mcc, mnc, carrierName, localeIdentifier, preferredLanguages }
- (NSDictionary *)regionDefaultsForCountryCode:(NSString *)countryCode;

/// All ISO country codes present in the DB (uppercase).
- (NSArray<NSString *> *)availableCountryCodes;

@end

NS_ASSUME_NONNULL_END
