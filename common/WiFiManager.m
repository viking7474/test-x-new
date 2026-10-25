#import "WiFiManager.h"
#import "ProfileManager.h"
#import "TLinkIOSLogging.h"
#import "PXPaths.h"
#import "PXRuntimeArtifactWriter.h"
#import "PXRuntimeArtifactPreparation.h"
#import "PXIdentityValidator.h"
#import <Security/Security.h>

@interface WiFiManager ()
@property (nonatomic, strong) NSString *currentIdentifier;
@property (nonatomic, strong) NSMutableDictionary *wifiInfo;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSString *currentProfileId;
@property (nonatomic, weak) id profileChangeObserver;
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
    // Register for profile change notifications
    self.profileChangeObserver = [[NSNotificationCenter defaultCenter] 
        addObserverForName:@"WeaponXProfileChanged"
        object:nil 
        queue:[NSOperationQueue mainQueue] 
        usingBlock:^(NSNotification *note) {
            // Reload WiFi info when profile changes
            NSString *newProfileId = note.userInfo[@"ProfileId"];
            if (newProfileId && ![newProfileId isEqualToString:self.currentProfileId]) {
                self.currentProfileId = newProfileId;
                [self loadWiFiInfoFromCurrentProfile];
                PXLog(@"[WiFiManager] Loaded WiFi info for new profile: %@", newProfileId);
            }
    }];
}

- (NSString *)getCurrentProfileID {
    // First try via ProfileManager
    id profileManager = NSClassFromString(@"ProfileManager");
    if (profileManager) {
        id sharedManager = [profileManager sharedManager];
        if ([sharedManager respondsToSelector:@selector(currentProfile)]) {
            id currentProfile = [sharedManager currentProfile];
            if (currentProfile && [currentProfile respondsToSelector:@selector(profileId)]) {
                NSString *profileId = [currentProfile profileId];
                if (profileId) {
                    return profileId;
                }
            }
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
    NSString *profileId = [self getCurrentProfileID];
    if (!profileId) {
        PXLog(@"[WiFiManager] No active profile, cannot load WiFi info");
        return;
    }
    
    self.currentProfileId = profileId;
    
    // Build path to WiFi info file in profile directory
    NSString *profileDir = [PXProfilesPath() stringByAppendingPathComponent:profileId];
    NSString *identityDir = [profileDir stringByAppendingPathComponent:@"identity"];
    NSString *wifiInfoPath = [identityDir stringByAppendingPathComponent:@"wifi_info.plist"];
    
    // Check if file exists
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:wifiInfoPath]) {
        PXLog(@"[WiFiManager] No saved WiFi info found for profile %@", profileId);
        return;
    }
    
    // Load the saved info
    NSMutableDictionary *savedInfo = [NSMutableDictionary dictionaryWithContentsOfFile:wifiInfoPath];
    if (savedInfo) {
        self.wifiInfo = savedInfo;
        PXLog(@"[WiFiManager] Loaded WiFi info from profile %@: SSID=%@, BSSID=%@", 
              profileId, savedInfo[@"ssid"], savedInfo[@"bssid"]);
    }
}

- (void)saveWiFiInfoToCurrentProfile {
    NSString *profileId = [self getCurrentProfileID];
    if (!profileId) {
        PXLog(@"[WiFiManager] No active profile, cannot save WiFi info");
        return;
    }
    
    self.currentProfileId = profileId;
    
    // Build canonical identity/device paths through PXPaths.
    NSString *identityDir = PXProfileIdentityPath(profileId);
    if (!identityDir.length) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:3002
            userInfo:@{NSLocalizedDescriptionKey: @"Invalid WiFi target profile"}];
        return;
    }
    NSString *wifiInfoPath = [identityDir stringByAppendingPathComponent:@"wifi_info.plist"];
    
    // Ensure directory exists
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:identityDir]) {
        [fileManager createDirectoryAtPath:identityDir 
              withIntermediateDirectories:YES 
                               attributes:nil 
                                    error:nil];
    }
    
    NSDictionary *preparedWiFi = [self.wifiInfo copy];
    NSError *error = nil;
    if (!PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return PXStageRuntimeWiFi(tx, identityDir, preparedWiFi, writeError);
    }, &error)) {
        self.error = error;
        PXLog(@"[WiFiManager] Failed to commit WiFi info at %@: %@", wifiInfoPath, error);
        return;
    }
    self.error = nil;
    
    PXLog(@"[WiFiManager] Saved WiFi info to profile %@: SSID=%@, BSSID=%@", 
          profileId, self.wifiInfo[@"ssid"], self.wifiInfo[@"bssid"]);
}

#pragma mark - Core Methods

- (NSDictionary *)generateWiFiInfo {
    self.error = nil;
    NSDictionary *prepared = PXPrepareRuntimeWiFiInfo();
    self.wifiInfo = [prepared mutableCopy];
    [self saveWiFiInfoToCurrentProfile];
    return prepared;
}

- (NSDictionary *)currentWiFiInfo {
    // Always check the current profile ID first
    NSString *currentId = [self getCurrentProfileID];
    if (currentId && (self.currentProfileId == nil || ![self.currentProfileId isEqualToString:currentId])) {
        PXLog(@"[WiFiManager] Profile change detected (%@ → %@), reloading WiFi info", 
              self.currentProfileId ?: @"nil", currentId);
        self.currentProfileId = currentId;
        [self loadWiFiInfoFromCurrentProfile];
    }
    
    // If we don't have info, load from profile
    if (self.wifiInfo.count == 0) {
        [self loadWiFiInfoFromCurrentProfile];
    }
    
    // If still no info, generate new
    if (self.wifiInfo.count == 0) {
        return [self generateWiFiInfo];
    }
    
    PXLog(@"[WiFiManager] Returning WiFi info: SSID=%@, BSSID=%@", 
          self.wifiInfo[@"ssid"], self.wifiInfo[@"bssid"]);
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
