#import <Foundation/Foundation.h>

@interface WiFiManager : NSObject

// Singleton access
+ (instancetype)sharedManager;

// Core functionality
// Standalone persistence owns an existing identity directory through paired
// commit. These legacy APIs remain cache-first: a candidate/error is not a
// persistence acknowledgement. Reloads clear values from a previous profile
// when the selected profile has no readable WiFi record.
// Supersession before preparation may return nil; a returned candidate is not ACK.
- (NSDictionary *)generateWiFiInfo;
// Superseded concurrent work may return nil rather than restart an old target.
- (NSDictionary *)currentWiFiInfo;
// Read-only compatibility fallback for a fixed target. Never reloads, generates,
// persists or resolves the active profile. The ID/data pair is revision-checked;
// nil also means superseded or an unacknowledged standalone candidate.
// Only load, committed adoption and successful save expose a readable entry.
- (NSDictionary *)cachedWiFiInfoForProfileID:(NSString *)profileID;
// Snapshot the root and copy required strings before validation/publication.
// Invalid input leaves cache eligibility intact; superseded preparation is dropped.
// Other metadata retains the legacy shallow-copy policy.
- (void)setCurrentWiFiInfo:(NSDictionary *)wifiInfo;
// Cache adoption after an explicit-target source commit; never saves.
- (void)adoptCommittedWiFiInfo:(NSDictionary *)wifiInfo profileID:(NSString *)profileID;

// Cache-only display snapshot from one revision, including legacy candidates.
// Never resolves selection, reloads, generates, persists or clears lastError.
// Nil means unavailable, malformed or superseded; the returned copy is shallow.
- (NSDictionary *)cachedWiFiDisplayInfo;

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
