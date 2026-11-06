#import "BatteryManager.h"
#import "TLinkIOSLogging.h"
#import "PXPaths.h"
#import "PXRuntimeArtifactWriter.h"
#import "PXRuntimeArtifactPreparation.h"
#import "PXProfileArtifactMutation.h"
#import "PXProfileLifecycleLease.h"
#import "PXProfileDeletionJournal.h"
#include <math.h>

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
- (void)applyLoadedBatteryInfo:(NSDictionary *)info profileSpecific:(BOOL)profileSpecific;
- (NSDictionary *)batteryRecordForLevel:(NSString *)level lowPowerMode:(BOOL)enabled;
- (BOOL)persistBatteryRecord:(NSDictionary *)record;
- (BOOL)mirrorBatteryRecord:(NSDictionary *)record error:(NSError **)error;
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
    if (![_currentBatteryLevel isKindOfClass:NSString.class] || _currentBatteryLevel.length == 0) {
        _currentBatteryLevel = [self generateBatteryLevel];
    }
    
    // Compare in float precision so a stored 1% value is not rounded below
    // a double 0.01 threshold and spuriously regenerated.
    float storedLevel = [_currentBatteryLevel isKindOfClass:NSString.class] ? [_currentBatteryLevel floatValue] : NAN;
    if (!isfinite(storedLevel) || storedLevel < 0.01f || storedLevel > 1.0f) {
        // Fix invalid values
        PXLog(@"[WeaponX] ⚠️ Fixing invalid battery level: %@", _currentBatteryLevel);
        _currentBatteryLevel = [self generateBatteryLevel];
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
    NSDictionary *record = [self batteryRecordForLevel:_currentBatteryLevel lowPowerMode:enabled];
    if (![self persistBatteryRecord:record]) return;
    
    PXLog(@"[WeaponX] 🔋 Low Power Mode set to: %@", enabled ? @"YES" : @"NO");
    
    // Notify listeners about the change
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BatteryInfoUpdated"
                                                        object:self
                                                      userInfo:@{
                                                          kBatteryLevelKey: record[kBatteryLevelKey],
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
    NSDictionary *record = [self batteryRecordForLevel:batteryInfo[kBatteryLevelKey] lowPowerMode:[batteryInfo[kLowPowerModeKey] boolValue]];
    if (![self persistBatteryRecord:record]) return batteryInfo;
    
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
    NSError *mirrorError = nil;
    if (![self mirrorBatteryRecord:mirror error:&mirrorError])
        PXLog(@"[BatteryManager] Source committed; legacy battery mirror could not be written: %@", mirrorError);
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
    NSDictionary *selection = nil;
    NSString *identity = nil;
    @try {
        selection = [NSDictionary dictionaryWithContentsOfFile:PXCurrentProfileInfoPath()];
        if (![selection isKindOfClass:NSDictionary.class]) return nil;
        identity = PXProfileIdentityPath(PXValidatedProfileID(selection[@"ProfileId"]));
        // A read must never recreate a retired profile/identity directory.
        return identity.length ? [identity stringByAppendingPathComponent:@"battery_info.plist"] : nil;
    } @finally { identity = nil; selection = nil; }
}

// Load battery values from disk
- (void)applyLoadedBatteryInfo:(NSDictionary *)info profileSpecific:(BOOL)profileSpecific {
    id level = nil, lowPower = nil;
    NSString *normalized = nil;
    @try {
        if (![info isKindOfClass:NSDictionary.class]) return;
        level = info[kBatteryLevelKey]; lowPower = info[kLowPowerModeKey];
        if ([level isKindOfClass:NSString.class]) normalized = [level copy];
        else if ([level isKindOfClass:NSNumber.class]) normalized = [[level stringValue] copy];
        BOOL hasLowPower = [lowPower isKindOfClass:NSString.class] || [lowPower isKindOfClass:NSNumber.class];
        BOOL enabled = hasLowPower ? [lowPower boolValue] : NO;
        // Unsupported fields follow the existing missing-field policy. Preserve
        // raw NSString spelling and accept legacy numeric levels as strings.
        if (normalized) _currentBatteryLevel = normalized;
        if (hasLowPower) {
            _currentLowPowerMode = enabled; _lowPowerModeLoaded = YES;
        } else if (profileSpecific) {
            _currentLowPowerMode = NO; _lowPowerModeLoaded = YES;
        } else if (!_lowPowerModeLoaded) {
            _currentLowPowerMode = NO;
        }
    } @finally { normalized = nil; lowPower = nil; level = nil; info = nil; }
}

- (void)loadBatteryInfoFromDisk {
    NSDictionary *batteryInfo = nil;
    NSString *profileBatteryPath = nil, *identityDir = nil, *profileDir = nil, *legacyPath = nil;
    @try {
        // Preserve canonical identity -> pre-identity profile -> global order.
        profileBatteryPath = [self batteryInfoPathForCurrentProfile];
        if (profileBatteryPath) {
            batteryInfo = [NSDictionary dictionaryWithContentsOfFile:profileBatteryPath];
            if (![batteryInfo isKindOfClass:NSDictionary.class]) {
                identityDir = [profileBatteryPath stringByDeletingLastPathComponent];
                profileDir = [identityDir stringByDeletingLastPathComponent];
                legacyPath = [profileDir stringByAppendingPathComponent:@"battery_info.plist"];
                batteryInfo = [NSDictionary dictionaryWithContentsOfFile:legacyPath];
            }
        }
        if ([batteryInfo isKindOfClass:NSDictionary.class]) {
            [self applyLoadedBatteryInfo:batteryInfo profileSpecific:YES];
            return;
        }
        batteryInfo = [NSDictionary dictionaryWithContentsOfFile:BATTERY_PLIST_PATH];
        if ([batteryInfo isKindOfClass:NSDictionary.class]) {
            [self applyLoadedBatteryInfo:batteryInfo profileSpecific:NO];
        } else if (!_lowPowerModeLoaded) {
            _currentLowPowerMode = NO;
        }
    } @finally {
        legacyPath = nil; profileDir = nil; identityDir = nil;
        profileBatteryPath = nil; batteryInfo = nil;
    }
}

// Save battery values to disk (both global and profile-specific)
- (void)saveBatteryInfoToDisk {
    if (!_currentBatteryLevel) return;
    NSDictionary *record = [self batteryRecordForLevel:_currentBatteryLevel lowPowerMode:_currentLowPowerMode];
    if (![self persistBatteryRecord:record]) PXLog(@"[BatteryManager] Battery persistence failed: %@", self.error);
}

- (NSDictionary *)batteryRecordForLevel:(NSString *)level lowPowerMode:(BOOL)enabled {
    if (!level) return nil;
    return @{ kBatteryLevelKey: [level copy], kLowPowerModeKey: @(enabled), kLastUpdatedKey: NSDate.date };
}

- (BOOL)persistBatteryRecord:(NSDictionary *)record {
    if (!record) {
        self.error = [NSError errorWithDomain:@"com.weaponx.BatteryManager" code:103 userInfo:@{NSLocalizedDescriptionKey: @"Missing battery persistence record"}];
        return NO;
    }
    NSError *failure = nil;
    PXProfileLifecycleLease *lease = nil;
    PXProfileArtifactMutation *mutation = nil;
    BOOL profileCommitted = NO;
    @try {
        lease = [PXProfileLifecycleLease acquireInDirectory:PXProfilesPath() error:&failure];
        if (!lease || ![lease validateForDirectory:PXProfilesPath() error:&failure] || !PXRequireNoPendingProfileDeletion(&failure)) {
            self.error = failure; return NO;
        }
        NSDictionary *selection = [NSDictionary dictionaryWithContentsOfFile:PXCurrentProfileInfoPath()];
        id selected = selection[@"ProfileId"];
        if (selected) {
            NSString *profileID = PXValidatedProfileID(selected);
            if (!profileID) {
                self.error = [NSError errorWithDomain:@"com.weaponx.BatteryManager" code:100 userInfo:@{NSLocalizedDescriptionKey: @"Invalid battery target profile"}]; return NO;
            }
            mutation = [PXProfileArtifactMutation borrowWithLifecycleLease:lease identityResolver:^NSString *{
                return PXProfileIdentityPath(profileID);
            } error:&failure];
            if (!mutation) { self.error = failure; return NO; }
            profileCommitted = [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
                return PXStageRuntimeBattery(tx, mutation.identityDirectory, record, error);
            } error:&failure];
            if (!profileCommitted) { self.error = failure; return NO; }
        }
        // No canonical active ID preserves the legacy global-only branch.
        // A present but invalid/missing target never downgrades to that branch.
    } @catch (NSException *exception) {
        self.error = [NSError errorWithDomain:@"com.weaponx.BatteryManager" code:101 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Battery persistence raised an exception"}];
        return NO;
    } @finally {
        [mutation invalidate];
        [lease invalidate];
    }
    // The mirror is a compatibility output, outside the source transaction.
    // Never update it when an intended profile commit failed.
    BOOL mirrored = [self mirrorBatteryRecord:record error:&failure];
    if (!mirrored && !profileCommitted) { self.error = failure; return NO; }
    self.error = nil;
    if (!mirrored) PXLog(@"[BatteryManager] Source committed; legacy mirror failed: %@", failure);
    return YES;
}

- (BOOL)mirrorBatteryRecord:(NSDictionary *)record error:(NSError **)error {
    if (error) *error = nil;
    @try {
        NSString *directory = [BATTERY_PLIST_PATH stringByDeletingLastPathComponent];
        if (![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:error]) return NO;
        if ([record writeToFile:BATTERY_PLIST_PATH atomically:YES]) return YES;
        if (error) *error = [NSError errorWithDomain:@"com.weaponx.BatteryManager" code:102 userInfo:@{NSLocalizedDescriptionKey: @"Could not write legacy battery mirror"}];
    } @catch (NSException *exception) {
        if (error) *error = [NSError errorWithDomain:@"com.weaponx.BatteryManager" code:102 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Legacy battery mirror raised an exception"}];
    }
    return NO;
}

@end
