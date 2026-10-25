#import "BatteryManager.h"
#import "TLinkIOSLogging.h"
#import "PXPaths.h"
#import "PXRuntimeArtifactWriter.h"
#import "PXRuntimeArtifactPreparation.h"

// Define file paths
#define BATTERY_PLIST_PATH @"/var/mobile/Library/Preferences/com.weaponx.battery.plist"
#define kBatteryLevelKey @"BatteryLevel"
#define kLowPowerModeKey @"LowPowerMode"
#define kLastUpdatedKey @"LastUpdated"

@interface BatteryManager ()
@property (nonatomic, strong) NSString *currentBatteryLevel;
@property (nonatomic, assign) BOOL currentLowPowerMode;
@property (nonatomic, assign) BOOL lowPowerModeLoaded;
@property (nonatomic, strong) NSError *error;
@end

@implementation BatteryManager

// Singleton pattern
static BatteryManager *sharedManager = nil;

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[BatteryManager alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Do NOT call -[UIDevice batteryLevel] here.
        // TLinkIOSTweak hooks UIDevice.batteryLevel → BatteryManager.sharedManager →
        // re-enters this init under dispatch_once and SIGTRAPs (once deadlock).
        _currentBatteryLevel = @"0.75";
        _currentLowPowerMode = NO; // Profile default
        _lowPowerModeLoaded = NO;

        // Load saved profile/global battery info first (no UIDevice dependency).
        [self loadBatteryInfoFromDisk];

        // Enable monitoring after load; any later real-device reads go through hooks safely
        // only once the singleton is fully published.
        @try {
            [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
        } @catch (__unused NSException *e) {
        }
    }
    return self;
}

#pragma mark - Battery Level

- (NSString *)batteryLevel {
    // First try to load from disk in case another process updated it
    [self loadBatteryInfoFromDisk];
    
    // If we don't have a value yet, generate one
    if (!_currentBatteryLevel || _currentBatteryLevel.length == 0) {
        _currentBatteryLevel = [self generateBatteryLevel];
        
        // Save the generated value
        [self saveBatteryInfoToDisk];
    }
    
    // Validate the value is within range
    float storedLevel = [_currentBatteryLevel floatValue];
    if (storedLevel < 0.01 || storedLevel > 1.0) {
        // Fix invalid values
        PXLog(@"[WeaponX] ⚠️ Fixing invalid battery level: %@", _currentBatteryLevel);
        _currentBatteryLevel = [self generateBatteryLevel];
        [self saveBatteryInfoToDisk];
    }
    
    return _currentBatteryLevel;
}

- (void)setBatteryLevel:(NSString *)level {
    _currentBatteryLevel = level;
    
    // Persist changes to disk
    [self saveBatteryInfoToDisk];
}

- (NSString *)generateBatteryLevel {
    // Generate a random battery level between 0.05 (5%) and 1.0 (100%)
    return [self randomizeBatteryLevel];
}

- (NSString *)randomizeBatteryLevel {
    NSString *levelStr = PXPrepareRuntimeBatteryLevel();
    _currentBatteryLevel = levelStr;
    [self saveBatteryInfoToDisk];
    return levelStr;
}

#pragma mark - Low Power Mode

- (BOOL)lowPowerModeEnabled {
    [self loadBatteryInfoFromDisk];
    return _currentLowPowerMode;
}

- (void)setLowPowerModeEnabled:(BOOL)enabled {
    _currentLowPowerMode = enabled;
    _lowPowerModeLoaded = YES;
    [self saveBatteryInfoToDisk];
    
    PXLog(@"[WeaponX] 🔋 Low Power Mode set to: %@", enabled ? @"YES" : @"NO");
    
    // Notify listeners about the change
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BatteryInfoUpdated"
                                                        object:self
                                                      userInfo:@{
                                                          kBatteryLevelKey: _currentBatteryLevel ?: @"0.75",
                                                          kLowPowerModeKey: @(enabled)
                                                      }];
    
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.hydra.tlinkios.battery.updated"),
        NULL,
        NULL,
        YES
    );
}

// Generate comprehensive battery info for UI display.
// Keeps the current Low Power Mode value; does NOT randomize it.
- (NSDictionary *)generateBatteryInfo {
    NSDictionary *batteryInfo = PXPrepareRuntimeBatteryInfo(_currentLowPowerMode);
    _currentBatteryLevel = batteryInfo[kBatteryLevelKey];

    // Save to disk (includes LPM)
    [self saveBatteryInfoToDisk];
    
    // Notify listeners about the change
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BatteryInfoUpdated"
                                                      object:self
                                                    userInfo:batteryInfo];
    
    // Also post CF notification for tweak hooks
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.hydra.tlinkios.battery.updated"),
        NULL,
        (__bridge CFDictionaryRef)batteryInfo,
        YES
    );
    
    return batteryInfo;
}

#pragma mark - Error Handling

- (void)adoptCommittedBatteryInfo:(NSDictionary *)batteryInfo {
    _currentBatteryLevel = [batteryInfo[kBatteryLevelKey] copy];
    _currentLowPowerMode = [batteryInfo[kLowPowerModeKey] boolValue];
    _lowPowerModeLoaded = YES;
    self.error = nil;
}

- (void)publishCommittedBatteryInfo:(NSDictionary *)batteryInfo timestamp:(NSDate *)timestamp {
    // Legacy mirror is not a runtime snapshot source. Never call the saving
    // setter here: it would select a profile again and start another commit.
    NSDictionary *mirror = @{ kBatteryLevelKey: batteryInfo[kBatteryLevelKey],
        kLowPowerModeKey: batteryInfo[kLowPowerModeKey], kLastUpdatedKey: timestamp };
    NSString *directory = [BATTERY_PLIST_PATH stringByDeletingLastPathComponent];
    if (![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL] ||
        ![mirror writeToFile:BATTERY_PLIST_PATH atomically:YES])
        PXLog(@"[BatteryManager] Source committed; legacy battery mirror could not be written");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BatteryInfoUpdated" object:self userInfo:batteryInfo];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.hydra.tlinkios.battery.updated"), NULL, (__bridge CFDictionaryRef)batteryInfo, YES);
}

// Return the last error that occurred
- (NSError *)lastError {
    return _error;
}

#pragma mark - File Operations

// Private helper to get the path to profile-specific battery_info.plist
- (NSString *)batteryInfoPathForCurrentProfile {
    // First try to get active profile ID
    NSString *profilesPath = PXCurrentProfileInfoPath();
    NSDictionary *currentProfileInfo = [NSDictionary dictionaryWithContentsOfFile:profilesPath];
    NSString *profileId = currentProfileInfo[@"ProfileId"];
    
    if (!profileId) {
        _error = [NSError errorWithDomain:@"com.weaponx.BatteryManager"
                                     code:100
                                 userInfo:@{NSLocalizedDescriptionKey: @"No active profile found"}];
        PXLog(@"[WeaponX] ⚠️ Error: No active profile when getting identity path in BatteryManager");
        return nil;
    }
    
    // Align with IdentifierManager: <profiles>/<id>/identity/battery_info.plist
    NSString *identityDir = PXProfileIdentityPath(profileId);
    if (!identityDir.length) {
        self.error = [NSError errorWithDomain:@"com.weaponx.BatteryManager" code:100
            userInfo:@{NSLocalizedDescriptionKey: @"Invalid battery target profile"}];
        return nil;
    }
    
    // Ensure identity directory exists
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:identityDir]) {
        [fm createDirectoryAtPath:identityDir
      withIntermediateDirectories:YES
                       attributes:nil
                            error:nil];
    }
    
    // Return the path to the battery_info.plist in this profile's identity dir
    return [identityDir stringByAppendingPathComponent:@"battery_info.plist"];
}

// Load battery values from disk
- (void)loadBatteryInfoFromDisk {
    NSDictionary *batteryInfo = nil;
    
    // First try identity/battery_info.plist (canonical)
    NSString *profileBatteryPath = [self batteryInfoPathForCurrentProfile];
    if (profileBatteryPath) {
        batteryInfo = [NSDictionary dictionaryWithContentsOfFile:profileBatteryPath];
        
        // Legacy fallback: <profile>/battery_info.plist (pre-identity path)
        if (!batteryInfo) {
            NSString *identityDir = [profileBatteryPath stringByDeletingLastPathComponent];
            NSString *profileDir = [identityDir stringByDeletingLastPathComponent];
            NSString *legacyPath = [profileDir stringByAppendingPathComponent:@"battery_info.plist"];
            batteryInfo = [NSDictionary dictionaryWithContentsOfFile:legacyPath];
        }
    }
    
    if (batteryInfo) {
        if (batteryInfo[kBatteryLevelKey]) {
            _currentBatteryLevel = batteryInfo[kBatteryLevelKey];
        }
        // LowPowerMode: present key → use it; missing → default NO
        if (batteryInfo[kLowPowerModeKey] != nil) {
            _currentLowPowerMode = [batteryInfo[kLowPowerModeKey] boolValue];
        } else {
            _currentLowPowerMode = NO;
        }
        _lowPowerModeLoaded = YES;
        return;
    }
    
    // If profile-specific load failed, try global plist
    batteryInfo = [NSDictionary dictionaryWithContentsOfFile:BATTERY_PLIST_PATH];
    if (batteryInfo) {
        // Extract the values we need
        _currentBatteryLevel = batteryInfo[kBatteryLevelKey] ?: _currentBatteryLevel;
        if (batteryInfo[kLowPowerModeKey] != nil) {
            _currentLowPowerMode = [batteryInfo[kLowPowerModeKey] boolValue];
            _lowPowerModeLoaded = YES;
        } else if (!_lowPowerModeLoaded) {
            _currentLowPowerMode = NO;
        }
    } else if (!_lowPowerModeLoaded) {
        _currentLowPowerMode = NO;
    }
}

// Save battery values to disk (both global and profile-specific)
- (void)saveBatteryInfoToDisk {
    // Basic validation
    if (!_currentBatteryLevel) {
        return;
    }
    
    @try {
        // First save to the global battery plist
        NSMutableDictionary *batteryInfo = [NSMutableDictionary dictionary];
        batteryInfo[kBatteryLevelKey] = _currentBatteryLevel;
        batteryInfo[kLowPowerModeKey] = @(_currentLowPowerMode);
        batteryInfo[kLastUpdatedKey] = [NSDate date];
        
        // Create the directory if it doesn't exist
        NSString *directory = [BATTERY_PLIST_PATH stringByDeletingLastPathComponent];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        if (![fileManager fileExistsAtPath:directory]) {
            [fileManager createDirectoryAtPath:directory
                  withIntermediateDirectories:YES
                                   attributes:nil
                                        error:nil];
        }
        
        // Write the plist
        [batteryInfo writeToFile:BATTERY_PLIST_PATH atomically:YES];
        
        PXLog(@"[WeaponX] 🔋 Saved battery info to global plist: %@%% LPM=%@",
              @([_currentBatteryLevel floatValue] * 100),
              _currentLowPowerMode ? @"YES" : @"NO");
    }
    @catch (NSException *exception) {
        // Log the error but don't crash
        PXLog(@"[WeaponX] ⚠️ Error saving battery info: %@", exception);
    }
    
    // Now also save to the profile-specific plist
    NSString *batteryInfoPath = [self batteryInfoPathForCurrentProfile];
    if (batteryInfoPath) {
        @try {
            // Create the directory if needed
            NSString *identityDir = [batteryInfoPath stringByDeletingLastPathComponent];
            [[NSFileManager defaultManager] createDirectoryAtPath:identityDir
                                     withIntermediateDirectories:YES
                                                      attributes:nil
                                                           error:nil];
            
            // Prepare the battery info dictionary
            NSMutableDictionary *batteryInfo = [NSMutableDictionary dictionary];
            batteryInfo[kBatteryLevelKey] = _currentBatteryLevel ?: @"0.75";
            batteryInfo[kLowPowerModeKey] = @(_currentLowPowerMode);
            batteryInfo[kLastUpdatedKey] = [NSDate date];
            
            NSError *error = nil;
            if (!PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
                return PXStageRuntimeBattery(tx, identityDir, batteryInfo, writeError);
            }, &error)) {
                self.error = error;
                PXLog(@"[BatteryManager] Failed to commit profile battery info: %@", error);
            } else self.error = nil;
        }
        @catch (NSException *exception) {
            PXLog(@"[WeaponX] ⚠️ Error saving profile battery info: %@", exception);
        }
    }
}

@end
