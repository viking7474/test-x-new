#import "BatteryManager.h"
#import "TLinkIOSLogging.h"
#import "PXPaths.h"
#import "PXRuntimeArtifactWriter.h"
#import "PXRuntimeArtifactPreparation.h"
#import "PXProfileArtifactMutation.h"
#import "PXProfileLifecycleLease.h"
#import "PXProfileDeletionJournal.h"
#include <math.h>
#include <stdint.h>

// Define file paths
#define BATTERY_PLIST_PATH @"/var/mobile/Library/Preferences/com.weaponx.battery.plist"
#define kBatteryLevelKey @"BatteryLevel"
#define kLowPowerModeKey @"LowPowerMode"
#define kLastUpdatedKey @"LastUpdated"

typedef NS_OPTIONS(NSUInteger, PXBatteryCacheFields) {
    PXBatteryCacheLevel = 1, PXBatteryCacheLowPower = 2, PXBatteryCacheLoaded = 4,
};

@interface BatteryManager ()
@property (nonatomic, strong) NSString *currentBatteryLevel;
@property (nonatomic, assign) BOOL currentLowPowerMode;
@property (nonatomic, assign) BOOL lowPowerModeLoaded;
@property (atomic, strong) NSError *error;
@property (nonatomic) uint64_t batteryCacheRevision;
@property (nonatomic) uint64_t batteryLoadSequence;
@property (nonatomic) uint64_t batteryMutationSequence;
@property (nonatomic) uint64_t batteryPendingMutation;
- (void)finishBatteryMutation:(uint64_t)mutation;
- (uint64_t)beginBatteryMutation;
- (uint64_t)beginBatteryMutationIfRevision:(uint64_t)revision;
- (BOOL)batteryMutationIsCurrent:(uint64_t)mutation;
- (NSString *)captureBatteryLevel:(BOOL *)enabled loaded:(BOOL *)loaded revision:(uint64_t *)revision mutation:(uint64_t *)mutation;
- (BOOL)publishBatteryLevel:(NSString *)level lowPowerMode:(BOOL)enabled loaded:(BOOL)loaded fields:(PXBatteryCacheFields)fields mutation:(uint64_t)mutation resultLevel:(NSString * __strong *)resultLevel resultLowPowerMode:(BOOL *)resultLowPower;
- (uint64_t)beginBatteryLoad:(uint64_t *)sequence;
- (BOOL)isValidBatteryLevel:(id)level;
- (NSString *)randomizeBatteryLevelAtMutation:(uint64_t)mutation;
- (void)applyLoadedBatteryInfo:(NSDictionary *)info profileSpecific:(BOOL)profileSpecific revision:(uint64_t)revision sequence:(uint64_t)sequence;
- (void)applyLoadedBatteryInfo:(NSDictionary *)info profileSpecific:(BOOL)profileSpecific;
- (NSDictionary *)batteryRecordForLevel:(NSString *)level lowPowerMode:(BOOL)enabled;
- (BOOL)persistBatteryRecord:(NSDictionary *)record;
- (BOOL)persistBatteryRecord:(NSDictionary *)record mutation:(uint64_t)receipt;
- (void)setBatteryError:(NSError *)error mutation:(uint64_t)mutation;
- (BOOL)mirrorBatteryRecord:(NSDictionary *)record error:(NSError **)error;
@end

@implementation BatteryManager

@synthesize error = _error;

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

- (uint64_t)beginBatteryMutation {
    @synchronized (self) {
        if (++_batteryMutationSequence == 0) ++_batteryMutationSequence;
        if (++_batteryCacheRevision == 0) ++_batteryCacheRevision;
        _batteryPendingMutation = _batteryMutationSequence;
        return _batteryMutationSequence;
    }
}

- (uint64_t)beginBatteryMutationIfRevision:(uint64_t)revision {
    @synchronized (self) {
        if (revision != _batteryCacheRevision || _batteryPendingMutation) return 0;
        if (++_batteryMutationSequence == 0) ++_batteryMutationSequence;
        if (++_batteryCacheRevision == 0) ++_batteryCacheRevision;
        _batteryPendingMutation = _batteryMutationSequence;
        return _batteryMutationSequence;
    }
}

- (void)finishBatteryMutation:(uint64_t)mutation {
    @synchronized (self) {
        if (_batteryPendingMutation == mutation) {
            _batteryPendingMutation = 0;
            // Revoke any disk load that started while this candidate was pending.
            if (++_batteryCacheRevision == 0) ++_batteryCacheRevision;
        }
    }
}

- (BOOL)batteryMutationIsCurrent:(uint64_t)mutation {
    @synchronized (self) { return mutation == _batteryMutationSequence; }
}

- (NSString *)captureBatteryLevel:(BOOL *)enabled loaded:(BOOL *)loaded revision:(uint64_t *)revision mutation:(uint64_t *)mutation {
    NSString *level = nil;
    @try {
        @synchronized (self) {
            level = _currentBatteryLevel;
            if (enabled) *enabled = _currentLowPowerMode;
            if (loaded) *loaded = _lowPowerModeLoaded;
            if (revision) *revision = _batteryCacheRevision;
            if (mutation) *mutation = _batteryMutationSequence;
        }
        return level;
    } @finally { level = nil; }
}

- (BOOL)publishBatteryLevel:(NSString *)level lowPowerMode:(BOOL)enabled loaded:(BOOL)loaded fields:(PXBatteryCacheFields)fields mutation:(uint64_t)mutation resultLevel:(NSString * __strong *)resultLevel resultLowPowerMode:(BOOL *)resultLowPower {
    __attribute__((objc_precise_lifetime)) NSString *discarded = nil;
    @try {
        @synchronized (self) {
            if (mutation != _batteryMutationSequence) return NO;
            if (fields & PXBatteryCacheLevel) { discarded = _currentBatteryLevel; _currentBatteryLevel = level; }
            if (fields & PXBatteryCacheLowPower) _currentLowPowerMode = enabled;
            if (fields & PXBatteryCacheLoaded) _lowPowerModeLoaded = loaded;
            if (++_batteryCacheRevision == 0) ++_batteryCacheRevision;
            // All internal callers supply initially nil owned output slots.
            if (resultLevel) *resultLevel = _currentBatteryLevel;
            if (resultLowPower) *resultLowPower = _currentLowPowerMode;
        }
        return YES;
    } @finally { discarded = nil; level = nil; }
}

- (NSError *)error {
    NSError *value = nil;
    @try {
        @synchronized (self) { value = _error; }
        return value;
    } @finally { value = nil; }
}

- (void)setError:(NSError *)error {
    uint64_t mutation = 0;
    @try {
        @synchronized (self) { mutation = _batteryMutationSequence; }
        [self setBatteryError:error mutation:mutation];
    } @finally { error = nil; }
}

- (void)setBatteryError:(NSError *)error mutation:(uint64_t)mutation {
    __attribute__((objc_precise_lifetime)) NSError *discarded = nil;
    @try {
        @synchronized (self) {
            if (mutation != _batteryMutationSequence) return;
            // Raw store avoids KVO or overridden property callbacks in the monitor.
            discarded = _error; _error = error;
        }
    } @finally { discarded = nil; error = nil; }
}

- (uint64_t)beginBatteryLoad:(uint64_t *)sequence {
    @synchronized (self) {
        if (_batteryPendingMutation) { *sequence = 0; return _batteryCacheRevision; }
        if (++_batteryLoadSequence == 0) ++_batteryLoadSequence;
        *sequence = _batteryLoadSequence;
        return _batteryCacheRevision;
    }
}

- (BOOL)isValidBatteryLevel:(id)level {
    @try {
        if (![level isKindOfClass:NSString.class] || ![level length]) return NO;
        float value = [level floatValue];
        return isfinite(value) && value >= 0.01f && value <= 1.0f;
    } @finally { level = nil; }
}

#pragma mark - Battery Level

- (NSString *)batteryLevel {
    NSString *level = nil, *generated = nil;
    @try {
        [self loadBatteryInfoFromDisk];
        uint64_t revision = 0;
        level = [self captureBatteryLevel:NULL loaded:NULL revision:&revision mutation:NULL];
        if ([self isValidBatteryLevel:level]) return level;
        if ([level isKindOfClass:NSString.class] && level.length) PXLog(@"[WeaponX] ⚠️ Fixing invalid battery level: %@", level);
        // Only the still-observed invalid cache may initiate a repair.
        uint64_t mutation = [self beginBatteryMutationIfRevision:revision];
        if (mutation) {
            generated = [self randomizeBatteryLevelAtMutation:mutation];
            if ([self batteryMutationIsCurrent:mutation]) return generated;
        }
        // Superseded work never repairs or returns an obsolete candidate.
        level = [self captureBatteryLevel:NULL loaded:NULL revision:NULL mutation:NULL];
        return [self isValidBatteryLevel:level] ? level : nil;
    } @finally { generated = nil; level = nil; }
}

- (void)setBatteryLevel:(NSString *)level {
    uint64_t mutation = [self beginBatteryMutation];
    NSString *candidate = nil;
    NSDictionary *record = nil;
    @try {
        if (level && ![level isKindOfClass:NSString.class]) return;
        candidate = [level copy];
        if (candidate && ![candidate isKindOfClass:NSString.class]) return;
        BOOL enabled = NO;
        if (![self publishBatteryLevel:candidate lowPowerMode:NO loaded:NO fields:PXBatteryCacheLevel mutation:mutation resultLevel:NULL resultLowPowerMode:&enabled]) return;
        if (!candidate) return; // Preserve nil-clear without a save.
        record = [self batteryRecordForLevel:candidate lowPowerMode:enabled];
        if ([self batteryMutationIsCurrent:mutation] && ![self persistBatteryRecord:record mutation:mutation])
            PXLog(@"[BatteryManager] Battery persistence failed: %@", self.error);
    } @finally { [self finishBatteryMutation:mutation]; record = nil; candidate = nil; level = nil; }
}

- (NSString *)generateBatteryLevel {
    // Generate a random battery level between 0.05 (5%) and 1.0 (100%)
    return [self randomizeBatteryLevel];
}

- (NSString *)randomizeBatteryLevel {
    return [self randomizeBatteryLevelAtMutation:[self beginBatteryMutation]];
}

- (NSString *)randomizeBatteryLevelAtMutation:(uint64_t)mutation {
    NSString *level = nil;
    NSDictionary *record = nil;
    @try {
        level = [PXPrepareRuntimeBatteryLevel() copy];
        BOOL enabled = NO;
        if (![self publishBatteryLevel:level lowPowerMode:NO loaded:NO fields:PXBatteryCacheLevel mutation:mutation resultLevel:NULL resultLowPowerMode:&enabled]) return level;
        record = [self batteryRecordForLevel:level lowPowerMode:enabled];
        if ([self batteryMutationIsCurrent:mutation] && ![self persistBatteryRecord:record mutation:mutation])
            PXLog(@"[BatteryManager] Battery persistence failed: %@", self.error);
        return level;
    } @finally { [self finishBatteryMutation:mutation]; record = nil; level = nil; }
}

#pragma mark - Low Power Mode

- (BOOL)lowPowerModeEnabled {
    [self loadBatteryInfoFromDisk];
    BOOL enabled = NO;
    (void)[self captureBatteryLevel:&enabled loaded:NULL revision:NULL mutation:NULL];
    return enabled;
}

- (void)setLowPowerModeEnabled:(BOOL)enabled {
    uint64_t mutation = [self beginBatteryMutation];
    NSString *level = nil;
    NSDictionary *record = nil;
    @try {
        if (![self publishBatteryLevel:nil lowPowerMode:enabled loaded:YES fields:(PXBatteryCacheLowPower | PXBatteryCacheLoaded) mutation:mutation resultLevel:&level resultLowPowerMode:NULL]) return;
        record = [self batteryRecordForLevel:level lowPowerMode:enabled];
        if (![self batteryMutationIsCurrent:mutation] || ![self persistBatteryRecord:record mutation:mutation]) return;
        PXLog(@"[WeaponX] 🔋 Low Power Mode set to: %@", enabled ? @"YES" : @"NO");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"BatteryInfoUpdated" object:self
            userInfo:@{ kBatteryLevelKey: record[kBatteryLevelKey], kLowPowerModeKey: @(enabled) }];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
            CFSTR("com.hydra.tlinkios.battery.updated"), NULL, NULL, YES);
    } @finally { [self finishBatteryMutation:mutation]; record = nil; level = nil; }
}

// Generate comprehensive battery info for UI display.
// Keeps the current Low Power Mode value; does NOT randomize it.
- (NSDictionary *)generateBatteryInfo {
    uint64_t mutation = [self beginBatteryMutation];
    NSString *level = nil;
    NSDictionary *batteryInfo = nil, *record = nil;
    @try {
        BOOL enabled = NO;
        (void)[self captureBatteryLevel:&enabled loaded:NULL revision:NULL mutation:NULL];
        batteryInfo = PXPrepareRuntimeBatteryInfo(enabled);
        level = [batteryInfo[kBatteryLevelKey] copy];
        if (![self publishBatteryLevel:level lowPowerMode:enabled loaded:NO fields:(PXBatteryCacheLevel | PXBatteryCacheLowPower) mutation:mutation resultLevel:NULL resultLowPowerMode:NULL]) return batteryInfo;
        record = [self batteryRecordForLevel:level lowPowerMode:enabled];
        if (![self batteryMutationIsCurrent:mutation] || ![self persistBatteryRecord:record mutation:mutation]) return batteryInfo;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"BatteryInfoUpdated" object:self userInfo:batteryInfo];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
            CFSTR("com.hydra.tlinkios.battery.updated"), NULL, (__bridge CFDictionaryRef)batteryInfo, YES);
        return batteryInfo;
    } @finally { [self finishBatteryMutation:mutation]; record = nil; batteryInfo = nil; level = nil; }
}

#pragma mark - Error Handling

- (void)adoptCommittedBatteryInfo:(NSDictionary *)batteryInfo {
    uint64_t mutation = [self beginBatteryMutation];
    id rawLevel = nil, rawLowPower = nil;
    NSString *level = nil;
    @try {
        if (![batteryInfo isKindOfClass:NSDictionary.class]) return;
        rawLevel = batteryInfo[kBatteryLevelKey]; rawLowPower = batteryInfo[kLowPowerModeKey];
        if ([rawLevel isKindOfClass:NSString.class]) level = [rawLevel copy];
        else if ([rawLevel isKindOfClass:NSNumber.class]) level = [[rawLevel stringValue] copy];
        if (!level || !([rawLowPower isKindOfClass:NSString.class] || [rawLowPower isKindOfClass:NSNumber.class])) return;
        BOOL enabled = [rawLowPower boolValue];
        if ([self publishBatteryLevel:level lowPowerMode:enabled loaded:YES fields:(PXBatteryCacheLevel | PXBatteryCacheLowPower | PXBatteryCacheLoaded) mutation:mutation resultLevel:NULL resultLowPowerMode:NULL]) [self setBatteryError:nil mutation:mutation];
    } @finally { [self finishBatteryMutation:mutation]; level = nil; rawLowPower = nil; rawLevel = nil; batteryInfo = nil; }
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
    return self.error;
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
    uint64_t sequence = 0;
    uint64_t revision = [self beginBatteryLoad:&sequence];
    if (!sequence) return;
    [self applyLoadedBatteryInfo:info profileSpecific:profileSpecific revision:revision sequence:sequence];
}

- (void)applyLoadedBatteryInfo:(NSDictionary *)info profileSpecific:(BOOL)profileSpecific revision:(uint64_t)revision sequence:(uint64_t)sequence {
    id level = nil, lowPower = nil;
    NSString *normalized = nil;
    __attribute__((objc_precise_lifetime)) NSString *discarded = nil;
    @try {
        if (info && ![info isKindOfClass:NSDictionary.class]) return;
        level = info[kBatteryLevelKey]; lowPower = info[kLowPowerModeKey];
        if ([level isKindOfClass:NSString.class]) normalized = [level copy];
        else if ([level isKindOfClass:NSNumber.class]) normalized = [[level stringValue] copy];
        BOOL hasLowPower = [lowPower isKindOfClass:NSString.class] || [lowPower isKindOfClass:NSNumber.class];
        BOOL enabled = hasLowPower ? [lowPower boolValue] : NO;
        @synchronized (self) {
            if (revision != _batteryCacheRevision || sequence != _batteryLoadSequence || _batteryPendingMutation) return;
            if (normalized) { discarded = _currentBatteryLevel; _currentBatteryLevel = normalized; }
            if (hasLowPower) { _currentLowPowerMode = enabled; _lowPowerModeLoaded = YES; }
            else if (profileSpecific) { _currentLowPowerMode = NO; _lowPowerModeLoaded = YES; }
            else if (!_lowPowerModeLoaded) _currentLowPowerMode = NO;
            if (++_batteryCacheRevision == 0) ++_batteryCacheRevision;
        }
    } @finally { discarded = nil; normalized = nil; lowPower = nil; level = nil; info = nil; }
}

- (void)loadBatteryInfoFromDisk {
    uint64_t sequence = 0;
    uint64_t revision = [self beginBatteryLoad:&sequence];
    if (!sequence) return;
    NSDictionary *batteryInfo = nil;
    NSString *profileBatteryPath = nil, *identityDir = nil, *profileDir = nil, *legacyPath = nil;
    @try {
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
            [self applyLoadedBatteryInfo:batteryInfo profileSpecific:YES revision:revision sequence:sequence];
            return;
        }
        batteryInfo = [NSDictionary dictionaryWithContentsOfFile:BATTERY_PLIST_PATH];
        [self applyLoadedBatteryInfo:([batteryInfo isKindOfClass:NSDictionary.class] ? batteryInfo : nil) profileSpecific:NO revision:revision sequence:sequence];
    } @finally {
        legacyPath = nil; profileDir = nil; identityDir = nil;
        profileBatteryPath = nil; batteryInfo = nil;
    }
}

// Save battery values to disk (both global and profile-specific)
- (void)saveBatteryInfoToDisk {
    uint64_t mutation = [self beginBatteryMutation];
    NSString *level = nil;
    NSDictionary *record = nil;
    @try {
        BOOL enabled = NO;
        level = [self captureBatteryLevel:&enabled loaded:NULL revision:NULL mutation:NULL];
        if (!level) return;
        record = [self batteryRecordForLevel:level lowPowerMode:enabled];
        if ([self batteryMutationIsCurrent:mutation] && ![self persistBatteryRecord:record mutation:mutation])
            PXLog(@"[BatteryManager] Battery persistence failed: %@", self.error);
    } @finally { [self finishBatteryMutation:mutation]; record = nil; level = nil; }
}

- (NSDictionary *)batteryRecordForLevel:(NSString *)level lowPowerMode:(BOOL)enabled {
    NSString *frozen = nil;
    @try {
        if (![level isKindOfClass:NSString.class]) return nil;
        frozen = [level copy];
        if (![frozen isKindOfClass:NSString.class]) return nil;
        return @{ kBatteryLevelKey: frozen, kLowPowerModeKey: @(enabled), kLastUpdatedKey: NSDate.date };
    } @finally { frozen = nil; level = nil; }
}

- (BOOL)persistBatteryRecord:(NSDictionary *)record {
    uint64_t receipt = 0;
    @synchronized (self) { receipt = _batteryMutationSequence; }
    return [self persistBatteryRecord:record mutation:receipt];
}

- (BOOL)persistBatteryRecord:(NSDictionary *)record mutation:(uint64_t)receipt {
    if (![self batteryMutationIsCurrent:receipt]) return NO;
    if (!record) {
        [self setBatteryError:[NSError errorWithDomain:@"com.weaponx.BatteryManager" code:103 userInfo:@{NSLocalizedDescriptionKey: @"Missing battery persistence record"}] mutation:receipt];
        return NO;
    }
    NSError *failure = nil;
    PXProfileLifecycleLease *lease = nil;
    PXProfileArtifactMutation *mutation = nil;
    BOOL profileCommitted = NO;
    @try {
        lease = [PXProfileLifecycleLease acquireInDirectory:PXProfilesPath() error:&failure];
        if (!lease || ![lease validateForDirectory:PXProfilesPath() error:&failure] || !PXRequireNoPendingProfileDeletion(&failure)) {
            [self setBatteryError:failure mutation:receipt]; return NO;
        }
        if (![self batteryMutationIsCurrent:receipt]) return NO;
        NSDictionary *selection = [NSDictionary dictionaryWithContentsOfFile:PXCurrentProfileInfoPath()];
        id selected = selection[@"ProfileId"];
        if (selected) {
            NSString *profileID = PXValidatedProfileID(selected);
            if (!profileID) {
                [self setBatteryError:[NSError errorWithDomain:@"com.weaponx.BatteryManager" code:100 userInfo:@{NSLocalizedDescriptionKey: @"Invalid battery target profile"}] mutation:receipt]; return NO;
            }
            mutation = [PXProfileArtifactMutation borrowWithLifecycleLease:lease identityResolver:^NSString *{
                return PXProfileIdentityPath(profileID);
            } error:&failure];
            if (!mutation) { [self setBatteryError:failure mutation:receipt]; return NO; }
            profileCommitted = [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
                if (![self batteryMutationIsCurrent:receipt]) return NO;
                return PXStageRuntimeBattery(tx, mutation.identityDirectory, record, error);
            } error:&failure];
            if (!profileCommitted) { [self setBatteryError:failure mutation:receipt]; return NO; }
        }
        // No canonical active ID preserves the legacy global-only branch.
        // A present but invalid/missing target never downgrades to that branch.
    } @catch (NSException *exception) {
        [self setBatteryError:[NSError errorWithDomain:@"com.weaponx.BatteryManager" code:101 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Battery persistence raised an exception"}] mutation:receipt];
        return NO;
    } @finally {
        [mutation invalidate];
        [lease invalidate];
    }
    // The mirror is a compatibility output, outside the source transaction.
    // Never update it when an intended profile commit failed.
    BOOL mirrored = [self mirrorBatteryRecord:record error:&failure];
    if (!mirrored && !profileCommitted) { [self setBatteryError:failure mutation:receipt]; return NO; }
    [self setBatteryError:nil mutation:receipt];
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
