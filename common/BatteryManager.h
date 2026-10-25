#import "UIKit/UIKit.h"

@interface BatteryManager : NSObject

+ (instancetype)sharedManager;

// Battery level (0.0-1.0 range)
- (NSString *)batteryLevel;
- (void)setBatteryLevel:(NSString *)level;
- (NSString *)generateBatteryLevel;
- (NSString *)randomizeBatteryLevel;

// Low Power Mode (profile-scoped Boolean; default NO)
- (BOOL)lowPowerModeEnabled;
- (void)setLowPowerModeEnabled:(BOOL)enabled;

// Generate battery info for UI display (keeps current LPM; does not randomize it)
- (NSDictionary *)generateBatteryInfo;
// Cache only; caller publishes compatibility effects after the source commit.
- (void)adoptCommittedBatteryInfo:(NSDictionary *)batteryInfo;
- (void)publishCommittedBatteryInfo:(NSDictionary *)batteryInfo timestamp:(NSDate *)timestamp;

// File operations
- (void)saveBatteryInfoToDisk;
- (void)loadBatteryInfoFromDisk;

// Error handling
- (NSError *)lastError;

@end
