#import "WiFiManager.h"
#import "ProfileManager.h"
#import "TLinkIOSLogging.h"
#import "PXPaths.h"
#import "PXRuntimeArtifactWriter.h"
#import "PXProfileArtifactMutation.h"
#import "PXRuntimeArtifactPreparation.h"
#import "PXIdentityValidator.h"
#import <Security/Security.h>

@interface WiFiManager ()
@property (nonatomic, strong) NSString *currentIdentifier;
@property (atomic, strong) NSMutableDictionary *wifiInfo;
@property (atomic, strong) NSError *error;
@property (atomic, strong) NSString *currentProfileId;
@property (nonatomic, strong) id profileChangeObserver;
- (id)profileManagerForWiFi;
- (NSString *)profileIDFromManager:(id)manager;
- (void)loadWiFiInfoForProfileID:(NSString *)profileID;
@property (nonatomic) uint64_t wifiCacheRevision; // Only under the cache monitor.
@property (nonatomic) BOOL wifiCacheReadable;
- (uint64_t)beginWiFiCacheUpdate;
- (uint64_t)beginWiFiCacheUpdateIfRevision:(uint64_t)revision;
- (uint64_t)loadWiFiInfoForProfileID:(NSString *)profileID revision:(uint64_t)revision;
- (NSDictionary *)generateWiFiInfoAtRevision:(uint64_t)revision;
- (BOOL)wiFiCacheRevisionIsCurrent:(uint64_t)revision;
- (uint64_t)publishWiFiCache:(NSMutableDictionary *)info profileID:(NSString *)profileID revision:(uint64_t)revision readable:(BOOL)readable;
- (NSDictionary *)wiFiCacheSnapshotForProfileID:(NSString *)profileID requireReadable:(BOOL)readable;
- (void)setWiFiCacheError:(NSError *)error revision:(uint64_t)revision;
- (void)saveWiFiInfoToCurrentProfileAtRevision:(uint64_t)revision;
@end

@implementation WiFiManager

+ (instancetype)sharedManager {
    static WiFiManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _wifiInfo = [NSMutableDictionary dictionary];
        _error = nil;

        // Load WiFi info for current profile
        [self loadWiFiInfoFromCurrentProfile];

        // Register for profile changes
        [self registerForProfileNotifications];
    }
    return self;
}

#pragma mark - Profile Integration

- (void)registerForProfileNotifications {
    @synchronized (self) {
        if (self.profileChangeObserver) return;
        __weak typeof(self) weakSelf = self;
        self.profileChangeObserver = [NSNotificationCenter.defaultCenter addObserverForName:@"WeaponXProfileChanged"
            object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
                __strong typeof(weakSelf) owner = weakSelf;
                if (!owner) return;
                NSString *eventID = PXValidatedProfileID(note.userInfo[@"ProfileId"]);
                if (eventID && ![eventID isEqualToString:owner.currentProfileId]) {
                    // Queued notifications can be stale. Resolve current state
                    // rather than adopting the event's profile ID as authority.
                    [owner loadWiFiInfoFromCurrentProfile];
                }
            }];
    }
}

- (id)profileManagerForWiFi {
    Class managerClass = NSClassFromString(@"ProfileManager");
    return [managerClass respondsToSelector:@selector(sharedManager)] ? [managerClass sharedManager] : nil;
}

- (NSString *)getCurrentProfileID {
    return [self profileIDFromManager:[self profileManagerForWiFi]];
}

- (NSString *)profileIDFromManager:(id)manager {
    if ([manager respondsToSelector:@selector(currentProfile)]) {
        id profile = [manager currentProfile];
        if ([profile respondsToSelector:@selector(profileId)]) {
            NSString *profileID = [profile profileId];
            if (profileID) return profileID;
        }
    }
    // Fallback to direct file read if ProfileManager isn't available
    NSString *currentProfileInfoPath = PXCurrentProfileInfoPath();
    NSDictionary *profileInfo = [NSDictionary dictionaryWithContentsOfFile:currentProfileInfoPath];

    if (profileInfo && profileInfo[@"ProfileId"]) {
        id profileIdValue = profileInfo[@"ProfileId"];
        NSString *profileId = nil;

        // Handle both NSNumber and NSString types properly
        if ([profileIdValue isKindOfClass:[NSNumber class]]) {
            profileId = [profileIdValue stringValue];
        } else if ([profileIdValue isKindOfClass:[NSString class]]) {
            profileId = profileIdValue;
        } else {
            profileId = [profileIdValue description];
        }

        PXLog(@"[WiFiManager] Got current profile ID from plist: %@", profileId);
        return profileId;
    }

    // If all else fails, use default
    return @"default";
}

// Own cache writers replace whole roots. Copy/validation/I/O and callbacks
// stay outside this monitor; old objects cannot deallocate during a pair swap.
- (uint64_t)beginWiFiCacheUpdate {
    @synchronized (self) {
        if (++_wifiCacheRevision == 0) ++_wifiCacheRevision;
        _wifiCacheReadable = NO;
        return _wifiCacheRevision;
    }
}

- (uint64_t)beginWiFiCacheUpdateIfRevision:(uint64_t)revision {
    @synchronized (self) {
        if (revision != _wifiCacheRevision) return 0;
        if (++_wifiCacheRevision == 0) ++_wifiCacheRevision;
        _wifiCacheReadable = NO;
        return _wifiCacheRevision;
    }
}

- (BOOL)wiFiCacheRevisionIsCurrent:(uint64_t)revision {
    @synchronized (self) { return revision == _wifiCacheRevision; }
}

- (uint64_t)publishWiFiCache:(NSMutableDictionary *)info profileID:(NSString *)profileID revision:(uint64_t)revision readable:(BOOL)readable {
    __attribute__((objc_precise_lifetime)) NSDictionary *discardedInfo = nil;
    __attribute__((objc_precise_lifetime)) NSString *discardedID = nil;
    uint64_t published = 0;
    @synchronized (self) {
        if (revision == _wifiCacheRevision) {
            discardedInfo = self.wifiInfo; discardedID = self.currentProfileId;
            self.wifiInfo = info; self.currentProfileId = profileID;
            _wifiCacheReadable = readable;
            if (++_wifiCacheRevision == 0) ++_wifiCacheRevision;
            published = _wifiCacheRevision;
        }
    }
    (void)discardedInfo; (void)discardedID;
    return published;
}

- (void)setWiFiCacheError:(NSError *)error revision:(uint64_t)revision {
    __attribute__((objc_precise_lifetime)) NSError *discardedError = nil;
    @synchronized (self) {
        if (revision == _wifiCacheRevision) {
            discardedError = self.error;
            self.error = error;
        }
    }
    (void)discardedError;
}

- (NSDictionary *)wiFiCacheSnapshotForProfileID:(NSString *)profileID requireReadable:(BOOL)readable {
    NSDictionary *info = nil, *result = nil;
    NSString *owner = nil;
    uint64_t revision = 0;
    BOOL eligible = NO;
    @try {
        @synchronized (self) {
            info = self.wifiInfo; owner = self.currentProfileId;
            revision = _wifiCacheRevision;
            eligible = !readable || _wifiCacheReadable;
        }
        if (!eligible || ![profileID isKindOfClass:NSString.class] || ![owner isEqualToString:profileID]) return nil;
        result = [info copy]; // May reenter: never copy under the monitor.
        if (![self wiFiCacheRevisionIsCurrent:revision]) return nil;
        return result;
    } @finally { result = nil; owner = nil; info = nil; profileID = nil; }
}

- (void)loadWiFiInfoFromCurrentProfile {
    [self loadWiFiInfoForProfileID:[self getCurrentProfileID]];
}

- (void)loadWiFiInfoForProfileID:(NSString *)profileID {
    [self loadWiFiInfoForProfileID:profileID revision:[self beginWiFiCacheUpdate]];
}

- (uint64_t)loadWiFiInfoForProfileID:(NSString *)profileID revision:(uint64_t)revision {
    if (![self wiFiCacheRevisionIsCurrent:revision]) return 0;
    NSString *key = nil;
    NSString *target = nil;
    NSMutableDictionary *empty = nil;
    NSString *identity = nil;
    NSDictionary *saved = nil;
    NSMutableDictionary *loaded = nil;
    @try {
        key = [profileID isKindOfClass:NSString.class] ? [profileID copy] : nil;
        target = PXValidatedProfileID(key);
        empty = [NSMutableDictionary dictionary];
        revision = [self publishWiFiCache:empty profileID:key revision:revision readable:NO];
        if (!revision) return 0;
        identity = PXProfileIdentityPath(target);
        if (!identity.length) {
            [self setWiFiCacheError:[NSError errorWithDomain:@"com.hydra.tlinkios" code:3002
                userInfo:@{NSLocalizedDescriptionKey: @"Invalid WiFi target profile"}] revision:revision];
            return revision;
        }
        saved = [NSDictionary dictionaryWithContentsOfFile:[identity stringByAppendingPathComponent:@"wifi_info.plist"]];
        loaded = [saved isKindOfClass:NSDictionary.class] ? [saved mutableCopy] : empty;
        // An older file read must not overwrite a later load/adoption/candidate.
        return [self publishWiFiCache:loaded profileID:key revision:revision readable:YES];
    } @finally { loaded = nil; saved = nil; identity = nil; empty = nil; target = nil; key = nil; profileID = nil; }
}

- (void)saveWiFiInfoToCurrentProfile {
    [self saveWiFiInfoToCurrentProfileAtRevision:[self beginWiFiCacheUpdate]];
}


- (void)saveWiFiInfoToCurrentProfileAtRevision:(uint64_t)revision {
    if (![self wiFiCacheRevisionIsCurrent:revision]) return;
    id manager = nil;
    NSError *error = nil;
    __block NSString *profileID = nil;
    PXProfileArtifactMutation *mutation = nil;
    NSDictionary *candidate = nil, *prepared = nil;
    NSMutableDictionary *cache = nil;
    @try {
        // Optional manager callbacks and lifecycle ownership stay outside the monitor.
        manager = [self profileManagerForWiFi];
        if (![self wiFiCacheRevisionIsCurrent:revision]) return;
        mutation = [PXProfileArtifactMutation acquireWithIdentityResolver:^NSString *{
            profileID = PXValidatedProfileID([self profileIDFromManager:manager]);
            return PXProfileIdentityPath(profileID);
        } error:&error];
        if (!mutation) { [self setWiFiCacheError:error revision:revision]; return; }
        @synchronized (self) {
            if (revision == _wifiCacheRevision) candidate = self.wifiInfo;
        }
        if (![self wiFiCacheRevisionIsCurrent:revision]) return;
        prepared = [candidate copy];
        if (![self wiFiCacheRevisionIsCurrent:revision]) return;
        BOOL committed = [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
            return PXStageRuntimeWiFi(tx, mutation.identityDirectory, prepared, writeError);
        } error:&error];
        [mutation invalidate];
        if (committed) {
            cache = [prepared mutableCopy];
            revision = [self publishWiFiCache:cache profileID:profileID revision:revision readable:YES];
            if (revision) [self setWiFiCacheError:nil revision:revision];
        } else {
            [self setWiFiCacheError:error revision:revision];
            PXLog(@"[WiFiManager] Failed to commit WiFi info: %@", error);
        }
    } @finally {
        [mutation invalidate];
        cache = nil; prepared = nil; candidate = nil; mutation = nil;
        profileID = nil; manager = nil; error = nil;
    }
}

#pragma mark - Core Methods

- (NSDictionary *)generateWiFiInfo {
    return [self generateWiFiInfoAtRevision:[self beginWiFiCacheUpdate]];
}

- (NSDictionary *)generateWiFiInfoAtRevision:(uint64_t)revision {
    if (![self wiFiCacheRevisionIsCurrent:revision]) return nil;
    NSString *profileID = nil;
    NSDictionary *prepared = nil;
    NSMutableDictionary *candidate = nil;
    @try {
        [self setWiFiCacheError:nil revision:revision];
        profileID = [self.currentProfileId copy];
        prepared = PXPrepareRuntimeWiFiInfo();
        candidate = [prepared mutableCopy];
        revision = [self publishWiFiCache:candidate profileID:profileID revision:revision readable:NO];
        if (revision) [self saveWiFiInfoToCurrentProfileAtRevision:revision];
        return prepared; // A candidate remains distinct from persistence ACK.
    } @finally { candidate = nil; prepared = nil; profileID = nil; }
}

- (void)adoptCommittedWiFiInfo:(NSDictionary *)wifiInfo profileID:(NSString *)profileID {
    uint64_t revision = [self beginWiFiCacheUpdate];
    NSString *key = nil;
    NSMutableDictionary *prepared = nil;
    @try {
        key = [profileID isKindOfClass:NSString.class] ? [profileID copy] : nil;
        prepared = [wifiInfo isKindOfClass:NSDictionary.class] ? [wifiInfo mutableCopy] : nil;
        revision = [self publishWiFiCache:prepared profileID:key revision:revision readable:YES];
        if (revision) [self setWiFiCacheError:nil revision:revision];
    } @finally { prepared = nil; key = nil; wifiInfo = nil; profileID = nil; }
}

- (NSDictionary *)currentWiFiInfo {
    NSString *currentID = nil;
    NSDictionary *info = nil;
    uint64_t revision = 0;
    @try {
        @synchronized (self) { revision = _wifiCacheRevision; }
        currentID = [self getCurrentProfileID];
        if (![self wiFiCacheRevisionIsCurrent:revision]) return nil;
        info = [self wiFiCacheSnapshotForProfileID:currentID requireReadable:NO];
        if (info.count) return info;
        revision = [self beginWiFiCacheUpdateIfRevision:revision];
        if (!revision) return nil;
        revision = [self loadWiFiInfoForProfileID:currentID revision:revision];
        if (!revision) return nil;
        info = [self wiFiCacheSnapshotForProfileID:currentID requireReadable:NO];
        if (info.count) return info;
        if (!info) return nil;
        revision = [self beginWiFiCacheUpdateIfRevision:revision];
        return revision ? [self generateWiFiInfoAtRevision:revision] : nil;
    } @finally { info = nil; currentID = nil; }
}

- (NSDictionary *)cachedWiFiInfoForProfileID:(NSString *)profileID {
    NSString *target = nil;
    @try {
        target = [PXValidatedProfileID(profileID) copy];
        return target ? [self wiFiCacheSnapshotForProfileID:target requireReadable:YES] : nil;
    } @finally { target = nil; profileID = nil; }
}

- (void)setCurrentWiFiInfo:(NSDictionary *)wifiInfo {
    NSString *profileID = nil;
    NSMutableDictionary *candidate = nil;
    @try {
        if (!wifiInfo) return;
        if (![wifiInfo isKindOfClass:NSDictionary.class]) {
            self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:3001
                userInfo:@{NSLocalizedDescriptionKey: @"WiFi info must be a dictionary"}];
            return;
        }

        // Validate required fields
        if (!wifiInfo[@"ssid"] || !wifiInfo[@"bssid"]) {
            self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                             code:3001
                                         userInfo:@{NSLocalizedDescriptionKey: @"WiFi info must contain SSID and BSSID"}];
            return;
        }

        // Validate SSID and BSSID
        if (![self isValidSSID:wifiInfo[@"ssid"]] || ![self isValidBSSID:wifiInfo[@"bssid"]]) {
            return; // Error will be set by validation methods
        }

        uint64_t revision = [self beginWiFiCacheUpdate];
        profileID = [self.currentProfileId copy];
        candidate = [wifiInfo mutableCopy];
        revision = [self publishWiFiCache:candidate profileID:profileID revision:revision readable:NO];
        if (revision) [self saveWiFiInfoToCurrentProfileAtRevision:revision];
    } @finally { candidate = nil; profileID = nil; wifiInfo = nil; }
}

#pragma mark - Accessors

- (NSString *)currentSSID {
    return self.wifiInfo[@"ssid"];
}

- (NSString *)currentBSSID {
    return self.wifiInfo[@"bssid"];
}

- (NSString *)currentNetworkType {
    return self.wifiInfo[@"networkType"] ?: @"Infrastructure";
}

- (NSString *)currentWiFiStandard {
    return self.wifiInfo[@"wifiStandard"] ?: @"802.11ac";
}

- (BOOL)currentAutoJoinStatus {
    return [self.wifiInfo[@"autoJoin"] boolValue];
}

- (NSDate *)lastConnectionTime {
    return self.wifiInfo[@"lastConnectionTime"] ?: [NSDate date];
}

#pragma mark - Validation

- (BOOL)isValidSSID:(NSString *)ssid {
    BOOL valid = PXValidateIdentityValue(ssid, PXIdentityValueKindSSID, NO);
    if (!valid) self.error = [NSError errorWithDomain:PXIdentityValidationErrorDomain
                                                 code:3003
                                             userInfo:@{NSLocalizedDescriptionKey: @"SSID must be valid UTF-8 and 1-32 bytes"}];
    return valid;
}

- (BOOL)isValidBSSID:(NSString *)bssid {
    BOOL valid = PXValidateIdentityValue(bssid, PXIdentityValueKindMACAddress, NO);
    if (!valid) self.error = [NSError errorWithDomain:PXIdentityValidationErrorDomain
                                                 code:3005
                                             userInfo:@{NSLocalizedDescriptionKey: @"BSSID must be a nonzero MAC address"}];
    return valid;
}

#pragma mark - Error Handling

- (NSError *)lastError {
    return self.error;
}

#pragma mark - Cleanup

- (void)dealloc {
    if (self.profileChangeObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.profileChangeObserver];
    }
}

@end
