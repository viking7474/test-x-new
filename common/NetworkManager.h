#import <Foundation/Foundation.h>

@interface NetworkManager : NSObject

// Shared instance
+ (instancetype)sharedManager;

// Carrier information methods
+ (NSArray *)getCarriersForCountry:(NSString *)countryCode;
+ (NSDictionary *)getRandomCarrierForCountry:(NSString *)countryCode;
+ (BOOL)saveCarrierDetails:(NSString *)carrierName mcc:(NSString *)mcc mnc:(NSString *)mnc;
+ (NSDictionary *)getSavedCarrierDetails;
+ (NSDictionary *)getSavedCarrierDetailsWithForcedRefresh:(BOOL)forceRefresh;

// US Carriers
+ (NSArray *)getUSCarriers;
// India Carriers
+ (NSArray *)getIndiaCarriers;
// Canada Carriers
+ (NSArray *)getCanadaCarriers;

// Local IP address methods
// Mutating saves/refreshes use nonblocking profile lifecycle ownership. Saves
// return NO and generating getters return nil if ownership is unavailable or
// deletion recovery is already pending before generation starts.
// Inputs are frozen before target/provider callbacks. Explicit saves accept only
// NSString/nil, preserving raw spelling and nil-pair semantics. Saved readers
// reject malformed fields and keep dedicated-file/IDs fallback; empty IP strings
// remain read hits. Carrier numeric MCC/MNC values become strings at read boundary.
// Empty/non-string identity values are rejected before file access.
// Existing saved-value reads keep their ordinary read path. Once generation
// starts, a getter's candidate is not proof that its disk commit succeeded.
// en0 detection uses caller-owned conversion buffers and always frees ifaddrs.
// No IPv4 address is invented when detection/conversion fails.
+ (NSString *)getCurrentLocalIPAddress;
+ (BOOL)saveLocalIPAddress:(NSString *)ipAddress;
+ (BOOL)saveLocalIPAddress:(NSString *)ipAddress
             ipv6Address:(NSString *)ipv6Address;
+ (NSString *)getSavedLocalIPAddress;
+ (NSString *)getSavedLocalIPAddressWithForcedRefresh:(BOOL)forceRefresh;

+ (NSString *)generateSpoofedLocalIPAddressFromCurrent;
+ (NSString *)generateSpoofedLocalIPv6AddressFromCurrent;
+ (NSString *)getSavedLocalIPv6Address;

@end
