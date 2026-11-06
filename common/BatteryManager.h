#import "UIKit/UIKit.h"

@interface BatteryManager : NSObject

+ (instancetype)sharedManager;

// Battery level string; reads accept 0.01-1.0 in float precision.
- (NSString *)batteryLevel;
- (void)setBatteryLevel:(NSString *)level;
- (NSString *)generateBatteryLevel;
- (NSString *)randomizeBatteryLevel;

// Low Power Mode (profile-scoped Boolean; default NO)
- (BOOL)lowPowerModeEnabled;
- (void)setLowPowerModeEnabled:(BOOL)enabled;

// Generate battery info for UI display (keeps current LPM; does not randomize it)
// Candidate/cache-first return remains compatible. Failed persistence sets
// lastError and suppresses success notifications; it does not undo the cache.
- (NSDictionary *)generateBatteryInfo;
// Cache only; caller publishes compatibility effects after the source commit.
- (void)adoptCommittedBatteryInfo:(NSDictionary *)batteryInfo;
- (void)publishCommittedBatteryInfo:(NSDictionary *)batteryInfo timestamp:(NSDate *)timestamp;

// File operations
// Existing profile: commit source first, then best-effort legacy mirror. With no
// canonical active ID, retain global-only persistence under lifecycle ownership.
// Busy/pending/invalid or unavailable namespace never changes the mirror. Reads
// retain profile/legacy/global fallback and never create profile directories.
// Reads accept string/numeric levels; unsupported fields use missing-field policy.
// Level requests retain existing repair behavior for invalid/non-finite values.
- (void)saveBatteryInfoToDisk;
- (void)loadBatteryInfoFromDisk;

// Error handling
- (NSError *)lastError;

@end
