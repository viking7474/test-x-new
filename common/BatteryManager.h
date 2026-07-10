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

// File operations
- (void)saveBatteryInfoToDisk;
- (void)loadBatteryInfoFromDisk;

// Error handling
- (NSError *)lastError;

@end 