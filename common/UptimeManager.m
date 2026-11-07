#import "UptimeManager.h"
#import <sys/sysctl.h>
#include <math.h>
#import "TLinkIOSLogging.h"
#import "PXPaths.h"
#import "PXRuntimeArtifactWriter.h"
#import "PXRuntimeArtifactPreparation.h"
#import "PXProfileArtifactMutation.h"

#ifndef kUptimeVersionKey
#define kUptimeVersionKey @"version"
#endif

// Keep legacy numeric-prefix parsing; reject unsupported roots and non-finite output.
static BOOL PXUptimeNumber(id value, NSTimeInterval *result) {
    @try {
        if (![value isKindOfClass:NSString.class] && ![value isKindOfClass:NSNumber.class]) return NO;
        NSTimeInterval seconds = [value doubleValue];
        if (!isfinite(seconds)) return NO;
        if (result) *result = seconds;
        return YES;
    } @finally { value = nil; }
}
static NSDate *PXUptimeDate(id value) {
    @try { return [value isKindOfClass:NSDate.class] && isfinite([value timeIntervalSince1970]) ? value : nil; }
    @finally { value = nil; }
}
static NSString *PXUptimePath(id value) {
    @try { return [value isKindOfClass:NSString.class] && [value length] ? [value copy] : nil; }
    @finally { value = nil; }
}
static NSDictionary *PXUptimePreparedPacket(id raw) {
    NSDictionary *boot = nil, *elapsed = nil;
    NSMutableDictionary *packet = nil, *bootCopy = nil, *elapsedCopy = nil;
    NSDate *date = nil, *updated = nil, *elapsedUpdated = nil;
    id seconds = nil, value = nil;
    NSTimeInterval parsed = 0;
    @try {
        if (![raw isKindOfClass:NSDictionary.class]) return nil;
        raw = [raw copy]; boot = raw[@"boot"]; elapsed = raw[@"uptime"];
        if (![boot isKindOfClass:NSDictionary.class] || ![elapsed isKindOfClass:NSDictionary.class]) return nil;
        date = [PXUptimeDate(boot[@"value"]) copy]; updated = [PXUptimeDate(boot[@"lastUpdated"]) copy];
        elapsedUpdated = [PXUptimeDate(elapsed[@"lastUpdated"]) copy];
        seconds = raw[@"seconds"]; value = elapsed[@"value"];
        if (!date || !updated || !elapsedUpdated || !PXUptimeNumber(seconds, &parsed) || !PXUptimeNumber(value, &parsed)) return nil;
        bootCopy = [boot mutableCopy]; bootCopy[@"value"] = date; bootCopy[@"lastUpdated"] = updated;
        elapsedCopy = [elapsed mutableCopy]; elapsedCopy[@"value"] = [value copy]; elapsedCopy[@"lastUpdated"] = elapsedUpdated;
        packet = [raw mutableCopy]; packet[@"boot"] = [bootCopy copy]; packet[@"uptime"] = [elapsedCopy copy]; packet[@"seconds"] = [seconds copy];
        return [packet copy];
    } @finally { value = nil; seconds = nil; elapsedUpdated = nil; updated = nil; date = nil; elapsedCopy = nil; bootCopy = nil; packet = nil; elapsed = nil; boot = nil; raw = nil; }
}

@interface UptimeManager ()
@property (nonatomic, readonly, strong) NSDate *bootTimeValue;
@property (nonatomic, readonly) NSTimeInterval uptimeValue;
@property (nonatomic, readonly, strong) NSDate *cacheTime;
@property (nonatomic, readonly, strong) NSError *error;
@property (nonatomic, readonly) uint64_t uptimeEpoch;
- (uint64_t)captureUptimeEpoch;
- (uint64_t)claimUptimeEpoch:(uint64_t)observed;
- (BOOL)uptimeEpochIsCurrent:(uint64_t)epoch;
- (NSDate *)captureUptimeSeconds:(NSTimeInterval *)seconds cacheTime:(NSDate * __strong *)clock error:(NSError * __strong *)error;
- (BOOL)publishUptimeBoot:(NSDate *)boot seconds:(NSTimeInterval)seconds clock:(NSDate *)clock clearError:(BOOL)clearError epoch:(uint64_t)epoch;
- (void)setUptimeError:(NSError *)error epoch:(uint64_t)epoch;
- (NSDate *)bootTimeValue;
- (NSTimeInterval)uptimeValue;
- (NSDate *)cacheTime;
- (NSError *)error;
@end

@implementation UptimeManager
@synthesize bootTimeValue = _bootTimeValue, uptimeValue = _uptimeValue, cacheTime = _cacheTime, error = _error, uptimeEpoch = _uptimeEpoch;


#pragma mark - Initialization

+ (instancetype)sharedManager {
    static UptimeManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initialize with default values
        _bootTimeValue = nil;
        _uptimeValue = 0;
        _cacheTime = nil;
        
        // Load saved values if they exist

    }
    return self;
}

- (uint64_t)uptimeEpoch { return [self captureUptimeEpoch]; }

- (uint64_t)captureUptimeEpoch {
    @synchronized (self) { return _uptimeEpoch; }
}

// Compare after foreign preparation so a reentrant update cannot be reclaimed.
- (uint64_t)claimUptimeEpoch:(uint64_t)observed {
    @synchronized (self) {
        if (observed != _uptimeEpoch) return 0;
        if (++_uptimeEpoch == 0) ++_uptimeEpoch;
        return _uptimeEpoch;
    }
}

- (BOOL)uptimeEpochIsCurrent:(uint64_t)epoch {
    @synchronized (self) { return epoch == _uptimeEpoch; }
}

- (NSDate *)captureUptimeSeconds:(NSTimeInterval *)seconds cacheTime:(NSDate * __strong *)clock error:(NSError * __strong *)error {
    NSDate *boot = nil, *time = nil;
    NSError *failure = nil; NSTimeInterval value = 0;
    @try {
        @synchronized (self) { boot = _bootTimeValue; value = _uptimeValue; time = _cacheTime; failure = _error; }
        if (seconds) *seconds = value;
        if (clock) *clock = time;
        if (error) *error = failure;
        return boot;
    } @finally { failure = nil; time = nil; boot = nil; }
}

- (BOOL)publishUptimeBoot:(NSDate *)boot seconds:(NSTimeInterval)seconds clock:(NSDate *)clock clearError:(BOOL)clearError epoch:(uint64_t)epoch {
    // Retain displaced roots through unlock: their dealloc may call foreign code.
    __attribute__((objc_precise_lifetime)) NSDate *oldBoot = nil, *oldClock = nil;
    __attribute__((objc_precise_lifetime)) NSError *oldError = nil;
    @try {
        @synchronized (self) {
            if (epoch != _uptimeEpoch) return NO;
            oldBoot = _bootTimeValue; oldClock = _cacheTime;
            _bootTimeValue = boot; _uptimeValue = seconds; _cacheTime = clock;
            if (clearError) { oldError = _error; _error = nil; }
        }
        return YES;
    } @finally { oldError = nil; oldClock = nil; oldBoot = nil; clock = nil; boot = nil; }
}

- (void)setUptimeError:(NSError *)error epoch:(uint64_t)epoch {
    __attribute__((objc_precise_lifetime)) NSError *old = nil;
    @try {
        @synchronized (self) { if (epoch == _uptimeEpoch) { old = _error; _error = error; } }
    } @finally { old = nil; error = nil; }
}

- (NSDate *)bootTimeValue {
    return [self captureUptimeSeconds:NULL cacheTime:NULL error:NULL];
}

- (NSTimeInterval)uptimeValue {
    NSTimeInterval seconds = 0;
    [self captureUptimeSeconds:&seconds cacheTime:NULL error:NULL]; return seconds;
}

- (NSDate *)cacheTime {
    NSDate *clock = nil;
    @try { [self captureUptimeSeconds:NULL cacheTime:&clock error:NULL]; return clock; }
    @finally { clock = nil; }
}

- (NSError *)error {
    NSError *error = nil;
    @try { [self captureUptimeSeconds:NULL cacheTime:NULL error:&error]; return error; }
    @finally { error = nil; }
}

#pragma mark - Uptime Generation

- (void)adoptCommittedUptimeInfo:(NSDictionary *)uptimeInfo timestamp:(NSDate *)timestamp {
    uint64_t observed = [self captureUptimeEpoch];
    NSDictionary *bootRecord = nil;
    id rawDate = nil, rawSeconds = nil;
    NSDate *boot = nil, *clock = nil;
    NSTimeInterval seconds = 0;
    @try {
        if (uptimeInfo && ![uptimeInfo isKindOfClass:NSDictionary.class]) return;
        bootRecord = uptimeInfo[@"boot"];
        if (bootRecord && ![bootRecord isKindOfClass:NSDictionary.class]) return;
        rawDate = bootRecord[@"value"]; rawSeconds = uptimeInfo[@"seconds"];
        boot = [PXUptimeDate(rawDate) copy]; clock = [PXUptimeDate(timestamp) copy];
        if ((rawDate && !boot) || (timestamp && !clock) || (rawSeconds && !PXUptimeNumber(rawSeconds, &seconds))) return;
        uint64_t epoch = [self claimUptimeEpoch:observed];
        if (epoch) [self publishUptimeBoot:boot seconds:seconds clock:clock clearError:YES epoch:epoch];
    } @finally { clock = nil; boot = nil; rawSeconds = nil; rawDate = nil; bootRecord = nil; timestamp = nil; uptimeInfo = nil; }
}

- (NSDictionary *)prepareConsistentUptimeInfo {
    NSDate *now = nil;
    @try {
        struct timeval boottv = {0}; size_t sz = sizeof(boottv);
        int mib[2] = {CTL_KERN, KERN_BOOTTIME};
        int sysctlResult = sysctl(mib, 2, &boottv, &sz, NULL, 0);
        now = [NSDate date]; if (!PXUptimeDate(now)) return nil;
        NSTimeInterval realUptime = sysctlResult == 0 ? now.timeIntervalSince1970 - boottv.tv_sec : 0;
        BOOL hasRealUptime = sysctlResult == 0 && sz >= sizeof(boottv) && boottv.tv_sec > 0 && isfinite(realUptime) && realUptime >= 0;
        return PXPrepareRuntimeUptime(now, realUptime, hasRealUptime);
    } @finally { now = nil; }
}

- (void)generateConsistentUptimeAndBootTimeForProfile:(NSString *)profilePath {
    uint64_t epoch = [self captureUptimeEpoch], observed = epoch;
    PXProfileArtifactMutation *mutation = nil;
    NSString *profileID = nil, *expectedIdentity = nil, *message = nil;
    NSError *writeError = nil;
    id raw = nil;
    NSDictionary *prepared = nil, *bootTimeDict = nil, *uptimeDict = nil;
    NSDate *now = nil, *bootTime = nil;
    NSString *(^resolver)(void) = nil;
    BOOL (^sourceWrite)(PXRuntimeSourceTransaction *, NSError **) = nil;
    @try {
        profilePath = PXUptimePath(profilePath);
        profileID = profilePath.stringByDeletingLastPathComponent.lastPathComponent;
        expectedIdentity = PXProfileIdentityPath(profileID);
        if (!expectedIdentity.length || ![profilePath isEqualToString:expectedIdentity]) {
            message = @"Invalid profile path provided";
            [self setUptimeError:[NSError errorWithDomain:@"com.weaponx.UptimeManager" code:1003 userInfo:@{NSLocalizedDescriptionKey: message}] epoch:epoch];
            PXLog(@"[WeaponX] ❌ %@", message); return;
        }
        {
            resolver = ^NSString *{ return profilePath; };
        }
        mutation = [PXProfileArtifactMutation acquireWithIdentityResolver:resolver error:&writeError];
        resolver = nil;
        if (!mutation) { [self setUptimeError:writeError epoch:epoch]; return; }
        // Failed/busy admission must not revoke the operation holding the lease.
        epoch = [self claimUptimeEpoch:observed]; if (!epoch) return;
        raw = [self prepareConsistentUptimeInfo];
        if (![self uptimeEpochIsCurrent:epoch]) return;
        prepared = PXUptimePreparedPacket(raw); raw = nil;
        if (!prepared) {
            writeError = [NSError errorWithDomain:@"com.weaponx.UptimeManager" code:1002 userInfo:@{NSLocalizedDescriptionKey: @"Invalid prepared uptime information"}];
            [mutation invalidate]; [self setUptimeError:writeError epoch:epoch]; return;
        }
        now = prepared[@"boot"][@"lastUpdated"]; bootTimeDict = prepared[@"boot"]; uptimeDict = prepared[@"uptime"];
        bootTime = bootTimeDict[@"value"]; NSTimeInterval uptime = [prepared[@"seconds"] doubleValue];
        {
            sourceWrite = ^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
                NSString *identity = nil;
                @try {
                    if (![self uptimeEpochIsCurrent:epoch]) {
                        if (error) *error = [NSError errorWithDomain:@"com.weaponx.UptimeManager" code:1004 userInfo:@{NSLocalizedDescriptionKey: @"Uptime operation was superseded"}];
                        return NO;
                    }
                    identity = mutation.identityDirectory;
                    return PXStageRuntimeUptime(tx, identity, bootTimeDict, uptimeDict, now, error);
                } @finally { identity = nil; tx = nil; }
            };
        }
        BOOL committed = [mutation performSourceWrite:sourceWrite error:&writeError];
        [mutation invalidate];
        if (!committed) {
            [self setUptimeError:writeError epoch:epoch];
            PXLog(@"[UptimeManager] Failed to commit boot/uptime group at %@: %@", profilePath, writeError); return;
        }
        // Source success survives a newer local adoption; only cache publication is skipped.
        [self publishUptimeBoot:bootTime seconds:uptime clock:now clearError:YES epoch:epoch];
        PXLog(@"[WeaponX] ✅ Generated consistent uptime (%.2f hours) and boot time (%@) for profile path: %@", uptime/3600.0, bootTime, profilePath);
    } @catch (NSException *exception) {
        [mutation invalidate];
        message = [NSString stringWithFormat:@"Error generating consistent uptime: %@", exception];
        [self setUptimeError:[NSError errorWithDomain:@"com.weaponx.UptimeManager" code:1002 userInfo:@{NSLocalizedDescriptionKey: message}] epoch:epoch];
        PXLog(@"[WeaponX] ❌ %@", message);
    } @finally {
        [mutation invalidate];
        sourceWrite = nil; resolver = nil; bootTime = nil; now = nil; uptimeDict = nil; bootTimeDict = nil;
        prepared = nil; raw = nil; writeError = nil; message = nil; expectedIdentity = nil; profileID = nil; mutation = nil; profilePath = nil;
    }
}

- (NSString *)generateUptimeForProfile:(NSString *)profilePath {
    @try {
        profilePath = PXUptimePath(profilePath);
        [self generateConsistentUptimeAndBootTimeForProfile:profilePath];
        NSTimeInterval uptime = [self currentUptimeForProfile:profilePath];
        return [NSString stringWithFormat:@"%.0f", uptime];
    } @finally { profilePath = nil; }
}

- (NSTimeInterval)currentUptimeForProfile:(NSString *)profilePath {
    @try { return [self currentUptimeForProfile:profilePath generateIfMissing:YES]; }
    @finally { profilePath = nil; }
}

- (NSTimeInterval)currentUptimeForProfile:(NSString *)profilePath generateIfMissing:(BOOL)generateIfMissing {
    uint64_t epoch = [self captureUptimeEpoch];
    NSString *bootTimePath = nil, *path = nil;
    NSDictionary *record = nil;
    NSDate *boot = nil, *updated = nil, *now = nil;
    NSTimeInterval seconds = 0, elapsed = 0;
    @try {
        profilePath = PXUptimePath(profilePath);
        if (!profilePath) {
            [self setUptimeError:[NSError errorWithDomain:@"com.weaponx.UptimeManager" code:1003 userInfo:@{NSLocalizedDescriptionKey: @"Invalid profile path"}] epoch:epoch]; return 0;
        }
        bootTimePath = [profilePath stringByAppendingPathComponent:@"boot_time.plist"];
        record = [NSDictionary dictionaryWithContentsOfFile:bootTimePath];
        boot = [record isKindOfClass:NSDictionary.class] ? PXUptimeDate(record[@"value"]) : nil;
        if (boot) {
            now = [NSDate date]; seconds = [now timeIntervalSinceDate:boot];
            if (isfinite(seconds) && seconds > 0) return seconds;
        }
        path = [profilePath stringByAppendingPathComponent:@"system_uptime.plist"];
        record = [NSDictionary dictionaryWithContentsOfFile:path];
        updated = [record isKindOfClass:NSDictionary.class] ? PXUptimeDate(record[@"lastUpdated"]) : nil;
        if (updated && PXUptimeNumber(record[@"value"], &seconds)) {
            now = [NSDate date]; elapsed = [now timeIntervalSinceDate:updated]; seconds += elapsed;
            if (isfinite(elapsed) && isfinite(seconds) && seconds > 0) return seconds;
        }
        path = [profilePath stringByAppendingPathComponent:@"device_ids.plist"];
        record = [NSDictionary dictionaryWithContentsOfFile:path];
        if ([record isKindOfClass:NSDictionary.class] && PXUptimeNumber(record[@"SystemUptime"], &seconds) && seconds > 0) return seconds;
        if (!generateIfMissing) return 0;
        PXLog(@"[WeaponX] ⚠️ No valid uptime found for profile %@, generating new values", profilePath);
        [self generateConsistentUptimeAndBootTimeForProfile:profilePath];
        record = [NSDictionary dictionaryWithContentsOfFile:bootTimePath];
        boot = [record isKindOfClass:NSDictionary.class] ? PXUptimeDate(record[@"value"]) : nil;
        if (boot) { now = [NSDate date]; seconds = [now timeIntervalSinceDate:boot]; return isfinite(seconds) && seconds > 0 ? seconds : 0; }
        return 12 * 3600;
    } @finally { now = nil; updated = nil; boot = nil; record = nil; path = nil; bootTimePath = nil; profilePath = nil; }
}

- (void)setCurrentUptime:(NSTimeInterval)uptime {
    uint64_t observed = [self captureUptimeEpoch];
    NSDate *now = nil, *boot = nil;
    @try {
        if (!isfinite(uptime) || uptime <= 0) {
            uint64_t epoch = [self claimUptimeEpoch:observed];
            if (epoch) [self setUptimeError:[NSError errorWithDomain:@"com.weaponx.UptimeManager" code:1001 userInfo:@{NSLocalizedDescriptionKey: @"Uptime must be greater than 0"}] epoch:epoch]; return;
        }
        now = [NSDate date]; boot = [now dateByAddingTimeInterval:-uptime];
        if (!PXUptimeDate(now) || !PXUptimeDate(boot) || !isfinite(uptime)) {
            uint64_t failed = [self claimUptimeEpoch:observed];
            if (failed) [self setUptimeError:[NSError errorWithDomain:@"com.weaponx.UptimeManager" code:1002 userInfo:@{NSLocalizedDescriptionKey: @"Invalid uptime clock"}] epoch:failed]; return;
        }
        uint64_t epoch = [self claimUptimeEpoch:observed];
        if (epoch) [self publishUptimeBoot:boot seconds:uptime clock:now clearError:NO epoch:epoch];
        PXLog(@"[WeaponX] 🕒 Set system uptime: %.2f hours", uptime / 3600.0);
    } @finally { boot = nil; now = nil; }
}

#pragma mark - Boot Time Generation

- (NSString *)generateBootTimeForProfile:(NSString *)profilePath {
    NSString *path = nil;
    NSDictionary *record = nil;
    NSDate *boot = nil;
    @try {
        profilePath = PXUptimePath(profilePath);
        [self generateConsistentUptimeAndBootTimeForProfile:profilePath];
        path = [profilePath stringByAppendingPathComponent:@"boot_time.plist"];
        record = path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
        boot = [record isKindOfClass:NSDictionary.class] ? PXUptimeDate(record[@"value"]) : nil;
        return boot ? [NSString stringWithFormat:@"%.0f", boot.timeIntervalSince1970] : @"0";
    } @finally { boot = nil; record = nil; path = nil; profilePath = nil; }
}

- (NSDate *)currentBootTimeForProfile:(NSString *)profilePath {
    @try { return [self currentBootTimeForProfile:profilePath generateIfMissing:YES]; }
    @finally { profilePath = nil; }
}

- (NSDate *)currentBootTimeForProfile:(NSString *)profilePath generateIfMissing:(BOOL)generateIfMissing {
    uint64_t epoch = [self captureUptimeEpoch];
    NSString *bootTimePath = nil, *path = nil;
    NSDictionary *record = nil;
    NSDate *boot = nil;
    NSTimeInterval timestamp = 0;
    @try {
        profilePath = PXUptimePath(profilePath);
        if (!profilePath) { [self setUptimeError:[NSError errorWithDomain:@"com.weaponx.UptimeManager" code:1003 userInfo:@{NSLocalizedDescriptionKey: @"Invalid profile path"}] epoch:epoch]; return nil; }
        bootTimePath = [profilePath stringByAppendingPathComponent:@"boot_time.plist"];
        record = [NSDictionary dictionaryWithContentsOfFile:bootTimePath];
        boot = [record isKindOfClass:NSDictionary.class] ? PXUptimeDate(record[@"value"]) : nil;
        if (boot) return boot;
        path = [profilePath stringByAppendingPathComponent:@"device_ids.plist"];
        record = [NSDictionary dictionaryWithContentsOfFile:path];
        if ([record isKindOfClass:NSDictionary.class] && PXUptimeNumber(record[@"BootTime"], &timestamp) && timestamp > 0) return [NSDate dateWithTimeIntervalSince1970:timestamp];
        if (!generateIfMissing) return nil;
        PXLog(@"[WeaponX] ⚠️ No valid boot time found for profile %@, generating new values", profilePath);
        [self generateConsistentUptimeAndBootTimeForProfile:profilePath];
        record = [NSDictionary dictionaryWithContentsOfFile:bootTimePath];
        boot = [record isKindOfClass:NSDictionary.class] ? PXUptimeDate(record[@"value"]) : nil;
        return boot ?: [NSDate dateWithTimeIntervalSinceNow:-(12 * 3600)];
    } @finally { boot = nil; record = nil; path = nil; bootTimePath = nil; profilePath = nil; }
}

- (void)setCurrentBootTime:(NSDate *)bootTime {
    uint64_t observed = [self captureUptimeEpoch];
    NSDate *now = nil, *boot = nil;
    @try {
        boot = [PXUptimeDate(bootTime) copy];
        if (!boot) {
            uint64_t epoch = [self claimUptimeEpoch:observed];
            if (epoch) [self setUptimeError:[NSError errorWithDomain:@"com.weaponx.UptimeManager" code:1002 userInfo:@{NSLocalizedDescriptionKey: bootTime ? @"Invalid boot time" : @"Boot time cannot be nil"}] epoch:epoch]; return;
        }
        now = [NSDate date]; NSTimeInterval uptime = [now timeIntervalSinceDate:boot];
        if (!PXUptimeDate(now) || !PXUptimeDate(boot) || !isfinite(uptime)) {
            uint64_t failed = [self claimUptimeEpoch:observed];
            if (failed) [self setUptimeError:[NSError errorWithDomain:@"com.weaponx.UptimeManager" code:1002 userInfo:@{NSLocalizedDescriptionKey: @"Invalid uptime clock"}] epoch:failed]; return;
        }
        uint64_t epoch = [self claimUptimeEpoch:observed];
        if (epoch) [self publishUptimeBoot:boot seconds:uptime clock:now clearError:NO epoch:epoch];
        PXLog(@"[WeaponX] 🕒 Set boot time: %@", boot);
    } @finally { boot = nil; now = nil; bootTime = nil; }
}

#pragma mark - Consistent Uptime Generation

// Implementation already defined at the top of file

#pragma mark - Error Handling

- (NSError *)lastError {
    return self.error;
}

#pragma mark - Helper Methods

// Legacy API: stub implementations to satisfy linker, but not used in profile-specific logic
- (NSString *)generateUptime {
    PXLog(@"[WeaponX] WARNING: Called legacy generateUptime; use generateUptimeForProfile:");
    return @"0";
}
- (NSTimeInterval)currentUptime {
    PXLog(@"[WeaponX] WARNING: Called legacy currentUptime; use currentUptimeForProfile:");
    return 0;
}
- (NSString *)generateBootTime {
    PXLog(@"[WeaponX] WARNING: Called legacy generateBootTime; use generateBootTimeForProfile:");
    return @"0";
}
- (NSDate *)currentBootTime {
    PXLog(@"[WeaponX] WARNING: Called legacy currentBootTime; use currentBootTimeForProfile:");
    return nil;
}

- (NSString *)debugSpoofedUptimeInfo {
    NSDate *boot = nil, *clock = nil, *now = nil, *realBoot = nil;
    NSMutableString *result = nil; NSTimeInterval seconds = 0;
    @try {
        boot = [self captureUptimeSeconds:&seconds cacheTime:&clock error:NULL];
        result = [NSMutableString string];
        [result appendFormat:@"Spoofed Uptime: %.0f seconds (%.2f hours)\n", seconds, seconds/3600.0];
        [result appendFormat:@"Spoofed Boot Time: %@ (timestamp: %.0f)\n", boot, boot.timeIntervalSince1970];
        struct timeval boottv = {0}; size_t sz = sizeof(boottv); int mib[2] = {CTL_KERN, KERN_BOOTTIME};
        int sysctlResult = sysctl(mib, 2, &boottv, &sz, NULL, 0);
        if (sysctlResult == 0 && sz >= sizeof(boottv)) {
            realBoot = [NSDate dateWithTimeIntervalSince1970:boottv.tv_sec]; now = [NSDate date];
            NSTimeInterval realUptime = [now timeIntervalSinceDate:realBoot];
            [result appendFormat:@"Real Uptime: %.0f seconds (%.2f hours)\n", realUptime, realUptime/3600.0];
            [result appendFormat:@"Real Boot Time: %@ (timestamp: %.0f)\n", realBoot, realBoot.timeIntervalSince1970];
        }
        [result appendFormat:@"Cache Time: %@\n", clock]; return result;
    } @finally { result = nil; realBoot = nil; now = nil; clock = nil; boot = nil; }
}

- (BOOL)validateBootTimeConsistencyForProfile:(NSString *)profilePath {
    NSString *bootTimePath = nil, *deviceIdsPath = nil;
    NSDictionary *record = nil;
    NSDate *bootTimeFromPlist = nil;
    NSTimeInterval bootTimeFromDeviceIds = 0;
    @try {
        profilePath = PXUptimePath(profilePath); if (!profilePath) return NO;
        bootTimePath = [profilePath stringByAppendingPathComponent:@"boot_time.plist"];
        record = [NSDictionary dictionaryWithContentsOfFile:bootTimePath];
        bootTimeFromPlist = [record isKindOfClass:NSDictionary.class] ? PXUptimeDate(record[@"value"]) : nil;
        deviceIdsPath = [profilePath stringByAppendingPathComponent:@"device_ids.plist"];
        record = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
        if (![record isKindOfClass:NSDictionary.class] || !PXUptimeNumber(record[@"BootTime"], &bootTimeFromDeviceIds)) return NO;
        if (bootTimeFromPlist && bootTimeFromDeviceIds > 0) {
            NSTimeInterval difference = fabs(bootTimeFromPlist.timeIntervalSince1970 - bootTimeFromDeviceIds);
            BOOL consistent = isfinite(difference) && difference <= 1.0;
            if (!consistent) PXLog(@"[WeaponX] ⚠️ Boot time inconsistency detected in profile %@: plist=%.0f, device_ids=%.0f (diff=%.2f)", profilePath, bootTimeFromPlist.timeIntervalSince1970, bootTimeFromDeviceIds, difference);
            return consistent;
        }
        return NO;
    } @finally { bootTimeFromPlist = nil; record = nil; deviceIdsPath = nil; bootTimePath = nil; profilePath = nil; }
}

@end
