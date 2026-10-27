#import <Foundation/Foundation.h>

@interface WiFiManager : NSObject

// Singleton access
+ (instancetype)sharedManager;

// Core functionality
// Standalone persistence owns an existing identity directory through paired
// commit. These legacy APIs remain cache-first: a candidate/error is not a
// persistence acknowledgement. Reloads clear values from a previous profile
// when the selected profile has no readable WiFi record.
- (NSDictionary *)generateWiFiInfo;
- (NSDictionary *)currentWiFiInfo;
- (void)setCurrentWiFiInfo:(NSDictionary *)wifiInfo;
// Cache adoption after an explicit-target source commit; never saves.
- (void)adoptCommittedWiFiInfo:(NSDictionary *)wifiInfo profileID:(NSString *)profileID;

// Individual property getters/setters
- (NSString *)currentSSID;
- (NSString *)currentBSSID;
- (NSString *)currentNetworkType;
- (NSString *)currentWiFiStandard;
- (BOOL)currentAutoJoinStatus;
- (NSDate *)lastConnectionTime;

// Validation
- (BOOL)isValidSSID:(NSString *)ssid;
- (BOOL)isValidBSSID:(NSString *)bssid;

// Error Handling
- (NSError *)lastError;

@end
