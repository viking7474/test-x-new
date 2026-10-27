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
@property (nonatomic, strong) NSMutableDictionary *wifiInfo;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSString *currentProfileId;
@property (nonatomic, strong) id profileChangeObserver;
- (id)profileManagerForWiFi;
- (NSString *)profileIDFromManager:(id)manager;
- (void)loadWiFiInfoForProfileID:(NSString *)profileID;
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

- (void)loadWiFiInfoFromCurrentProfile {
    [self loadWiFiInfoForProfileID:[self getCurrentProfileID]];
}

- (void)loadWiFiInfoForProfileID:(NSString *)profileID {
    NSString *target = PXValidatedProfileID(profileID);
    // Never carry the previous profile's values through a missing/corrupt file.
    // Keep the legacy cache key (including the non-persistable "default"
    // fallback), but only a validated ID may resolve a filesystem path.
    self.currentProfileId = [profileID isKindOfClass:NSString.class] ? [profileID copy] : nil;
    self.wifiInfo = [NSMutableDictionary dictionary];
    NSString *identity = PXProfileIdentityPath(target);
    if (!identity.length) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:3002
            userInfo:@{NSLocalizedDescriptionKey: @"Invalid WiFi target profile"}];
        return;
    }
    NSDictionary *saved = [NSDictionary dictionaryWithContentsOfFile:[identity stringByAppendingPathComponent:@"wifi_info.plist"]];
    if (saved) self.wifiInfo = [saved mutableCopy];
}

- (void)saveWiFiInfoToCurrentProfile {
    // Warm the optional manager outside ownership. Its cold initializer can
    // acquire lifecycle ownership while bootstrapping/loading profiles.
    id manager = [self profileManagerForWiFi];
    NSError *error = nil;
    __block NSString *profileID = nil;
    PXProfileArtifactMutation *mutation = [PXProfileArtifactMutation acquireWithIdentityResolver:^NSString *{
        profileID = PXValidatedProfileID([self profileIDFromManager:manager]);
        return PXProfileIdentityPath(profileID);
    } error:&error];
    @try {
        if (!mutation) { self.error = error; return; }
        NSDictionary *prepared = [self.wifiInfo copy];
        BOOL committed = [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
            return PXStageRuntimeWiFi(tx, mutation.identityDirectory, prepared, writeError);
        } error:&error];
        [mutation invalidate];
        self.error = committed ? nil : error;
        if (committed) self.currentProfileId = profileID;
        else PXLog(@"[WiFiManager] Failed to commit WiFi info: %@", error);
    } @finally { [mutation invalidate]; }
}

#pragma mark - Core Methods

- (NSDictionary *)generateWiFiInfo {
    self.error = nil;
    NSDictionary *prepared = PXPrepareRuntimeWiFiInfo();
    self.wifiInfo = [prepared mutableCopy];
    [self saveWiFiInfoToCurrentProfile];
    return prepared;
}

- (void)adoptCommittedWiFiInfo:(NSDictionary *)wifiInfo profileID:(NSString *)profileID {
    self.wifiInfo = [wifiInfo mutableCopy];
    self.currentProfileId = [profileID copy];
    self.error = nil;
}

- (NSDictionary *)currentWiFiInfo {
    NSString *currentID = [self getCurrentProfileID];
    if (![self.currentProfileId isEqualToString:currentID] || self.wifiInfo.count == 0)
        [self loadWiFiInfoForProfileID:currentID];
    if (self.wifiInfo.count == 0) return [self generateWiFiInfo];
    return [self.wifiInfo copy];
}

- (void)setCurrentWiFiInfo:(NSDictionary *)wifiInfo {
    if (!wifiInfo) return;
    
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
    
    // Copy values
    self.wifiInfo = [NSMutableDictionary dictionaryWithDictionary:wifiInfo];
    
    // Save to profile
    [self saveWiFiInfoToCurrentProfile];
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
