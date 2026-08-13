#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <UIKit/UIKit.h>
#import "TLinkIOSLogging.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#import <substrate.h>
// #import <ellekit/ellekit.h> // Removed for rootful - using Substrate
#import <netinet/in.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import "NetworkManager.h"
#import "CarrierDB.h"

#import "PXScope.h"
#import "PXPaths.h"
#import <os/lock.h>

// Constants for connection types
typedef NS_ENUM(NSInteger, NetworkConnectionType) {
    NetworkConnectionTypeAuto = 0,
    NetworkConnectionTypeWiFi = 1,
    NetworkConnectionTypeCellular = 2,
    NetworkConnectionTypeNone = 3
};

// Path to security settings plist
static NSString *const kSecuritySettingsPath = @"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist";

// All network cache values/timestamps are protected by one process-local lock.
static os_unfair_lock gNetworkCacheLock = OS_UNFAIR_LOCK_INIT;

// Cache for quick lookup
static NSInteger cachedConnectionType = -1;
static BOOL cachedNetworkDataSpoofEnabled = NO;
static NSDate *cacheTimestamp = nil;
static const NSTimeInterval kCacheValidDuration = 5.0; // 5 seconds


// Default cellular identity (US T-Mobile) — never use product name "TLinkIOS" as carrier.
// Profile/target-region values override these when present.
static NSString *const kFakeCarrierName = @"T-Mobile";
static NSString *const kFakeMobileCountryCode = @"310";
static NSString *const kFakeMobileNetworkCode = @"260";

// Cache for ISO country code
static NSString *cachedISOCountryCode = nil;
static NSDate *isoCountryCodeCacheTimestamp = nil;
static const NSTimeInterval kISOCountryCodeCacheValidDuration = 60.0; // 60 seconds

// Fallback WiFi identity (realistic-looking; profile WiFi info should override when set)
static NSString *const kFakeWiFiSSID = @"HomeWiFi";
static NSString *const kFakeBSSID = @"00:11:22:33:44:55";

// Carrier name from CarrierDB (JSON) when available; never product branding.
static NSString *PXCarrierNameForMCCMNC(NSString *mcc, NSString *mnc) {
    if (!mcc.length || !mnc.length) return kFakeCarrierName;
    NSString *name = [[CarrierDB sharedManager] carrierNameForMCC:mcc mnc:mnc];
    if ([name isKindOfClass:[NSString class]] && name.length &&
        ![name isEqualToString:@"TLinkIOS"] && ![name hasPrefix:@"TLinkIOS"]) {
        return name;
    }
    return kFakeCarrierName;
}

// Cache for carrier details
static NSString *cachedCarrierName = nil;
static NSString *cachedMobileCountryCode = nil;
static NSString *cachedMobileNetworkCode = nil;
static NSDate *carrierDetailsCacheTimestamp = nil;
static const NSTimeInterval kCarrierDetailsCacheValidDuration = 60.0; // 60 seconds

// Cache for TargetRegion pinned overrides
static NSDate *targetRegionCacheTimestamp = nil;
static NSDictionary *cachedTargetRegion = nil;
static const NSTimeInterval kTargetRegionCacheValidDuration = 5.0;

// Constants for signal strength
static const int kWiFiSignalStrengthExcellent = -45;  // -45 dBm (Excellent)
static const int kWiFiSignalStrengthGood = -60;       // -60 dBm (Good)
static const int kWiFiSignalStrengthFair = -70;       // -70 dBm (Fair)
static const int kWiFiSignalStrengthPoor = -80;       // -80 dBm (Poor)

// Keep track of current signal values for realistic gradual changes
static int currentWiFiSignalStrength = -65;  // Start with a reasonable default
static int currentCellularSignalBars = 4;    // Start with good signal
static NSDate *lastSignalUpdateTime = nil;

// Cellular network type constants (4G/5G)
static NSString *const kCellularNetworkType4G = @"CTRadioAccessTechnologyLTE";
static NSString *const kCellularNetworkType5G = @"CTRadioAccessTechnologyNR";  // iOS 15+ 5G
static NSString *const kCellularNetworkType5GNSA = @"CTRadioAccessTechnologyNRNSA"; // 5G Non-Standalone

// Current cellular network type (changes over time)
static NSString *currentCellularNetworkType = nil;
static NSDate *lastNetworkTypeChangeTime = nil;
static const NSTimeInterval kMinNetworkTypeChangeDuration = 120.0; // Minimum 2 minutes between technology changes

static BOOL PXNetworkDataSpoofEnabledCached(void) {
    os_unfair_lock_lock(&gNetworkCacheLock);
    BOOL enabled = cachedNetworkDataSpoofEnabled;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    return enabled;
}

static void PXNetworkInvalidateCaches(void) {
    os_unfair_lock_lock(&gNetworkCacheLock);
    cachedConnectionType = -1;
    cachedNetworkDataSpoofEnabled = NO;
    cacheTimestamp = nil;
    cachedISOCountryCode = nil;
    isoCountryCodeCacheTimestamp = nil;
    cachedCarrierName = nil;
    cachedMobileCountryCode = nil;
    cachedMobileNetworkCode = nil;
    carrierDetailsCacheTimestamp = nil;
    cachedTargetRegion = nil;
    targetRegionCacheTimestamp = nil;
    lastSignalUpdateTime = nil;
    lastNetworkTypeChangeTime = nil;
    currentCellularNetworkType = nil;
    os_unfair_lock_unlock(&gNetworkCacheLock);
}

#pragma mark - Helper Functions

// Get the current bundle ID
static NSString *getCurrentBundleID() {
    NSBundle *mainBundle = [NSBundle mainBundle];
    if (!mainBundle) {
        return nil;
    }
    
    NSString *bundleID = [mainBundle bundleIdentifier];
    return bundleID;
}

// Get the current ISO country code from security settings
static NSString *getCurrentISOCountryCode() {
    NSDate *now = [NSDate date];
    os_unfair_lock_lock(&gNetworkCacheLock);
    BOOL valid = cachedISOCountryCode && isoCountryCodeCacheTimestamp &&
        [now timeIntervalSinceDate:isoCountryCodeCacheTimestamp] < kISOCountryCodeCacheValidDuration;
    NSString *cached = valid ? cachedISOCountryCode : nil;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    if (cached) return cached;

    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:kSecuritySettingsPath];
    NSString *isoCode = nil;
    if ([settings[@"targetRegionFollowsIPEnabled"] boolValue]) {
        NSString *pinnedISO = [settings[@"targetRegionPinnedCarrierISO"] isKindOfClass:[NSString class]]
            ? settings[@"targetRegionPinnedCarrierISO"]
            : nil;
        if (pinnedISO.length) isoCode = [pinnedISO lowercaseString];
    }
    if (!isoCode.length) {
        NSString *configured = [settings[@"networkISOCountryCode"] isKindOfClass:[NSString class]]
            ? settings[@"networkISOCountryCode"]
            : nil;
        isoCode = configured.length ? [configured lowercaseString] : @"us";
    }

    os_unfair_lock_lock(&gNetworkCacheLock);
    cachedISOCountryCode = [isoCode copy];
    isoCountryCodeCacheTimestamp = now;
    NSString *published = cachedISOCountryCode;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    return published;
}

static NSDictionary *getTargetRegionPinnedOverrides(void) {
    NSDate *now = [NSDate date];
    os_unfair_lock_lock(&gNetworkCacheLock);
    BOOL valid = targetRegionCacheTimestamp &&
        [now timeIntervalSinceDate:targetRegionCacheTimestamp] < kTargetRegionCacheValidDuration;
    NSDictionary *cached = valid ? cachedTargetRegion : nil;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    if (valid) return cached;

    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:kSecuritySettingsPath];
    NSDictionary *resolved = nil;
    if ([settings isKindOfClass:[NSDictionary class]] && [settings[@"targetRegionFollowsIPEnabled"] boolValue]) {
        NSString *mcc = [settings[@"targetRegionPinnedCarrierMCC"] isKindOfClass:[NSString class]] ? settings[@"targetRegionPinnedCarrierMCC"] : nil;
        NSString *mnc = [settings[@"targetRegionPinnedCarrierMNC"] isKindOfClass:[NSString class]] ? settings[@"targetRegionPinnedCarrierMNC"] : nil;
        NSString *iso = [settings[@"targetRegionPinnedCarrierISO"] isKindOfClass:[NSString class]] ? settings[@"targetRegionPinnedCarrierISO"] : nil;
        NSString *name = [settings[@"targetRegionPinnedCarrierName"] isKindOfClass:[NSString class]] ? settings[@"targetRegionPinnedCarrierName"] : nil;
        if (mcc.length && mnc.length) {
            NSString *resolvedName = name.length ? name : PXCarrierNameForMCCMNC(mcc, mnc);
            if ([resolvedName isEqualToString:@"TLinkIOS"] || [resolvedName hasPrefix:@"TLinkIOS"]) {
                resolvedName = PXCarrierNameForMCCMNC(mcc, mnc);
            }
            resolved = @{
                @"carrierName": resolvedName ?: kFakeCarrierName,
                @"mobileCountryCode": mcc,
                @"mobileNetworkCode": mnc,
                @"carrierISO": iso ?: @""
            };
        }
    }

    os_unfair_lock_lock(&gNetworkCacheLock);
    cachedTargetRegion = [resolved copy];
    targetRegionCacheTimestamp = now;
    NSDictionary *published = cachedTargetRegion;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    return published;
}

static BOOL shouldForceCarrierSpoof(void) {
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:kSecuritySettingsPath];
    if (![settings isKindOfClass:[NSDictionary class]]) return NO;
    if ([settings[@"targetRegionFollowsIPEnabled"] boolValue]) return YES;
    if ([settings[@"fullSpoofTestModeEnabled"] boolValue]) return YES;
    return NO;
}

// Get the path to the current profile's identity directory
static NSString *getProfileIdentityPath() {
    return PXActiveProfileIdentityPath();
}

// Get the local IP address from the current profile
static NSString *getProfileLocalIPAddress() {
    NSString *identityDir = getProfileIdentityPath();
    if (!identityDir) {
        return @"192.168.1.1"; // Default fallback
    }
    
    // Try to read from network_settings.plist
    NSString *networkPath = [identityDir stringByAppendingPathComponent:@"network_settings.plist"];
    NSDictionary *networkDict = [NSDictionary dictionaryWithContentsOfFile:networkPath];
    
    NSString *localIP = networkDict[@"localIPAddress"];
    
    // If not found in dedicated file, try the combined device_ids.plist
    if (!localIP) {
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
        localIP = deviceIds[@"LocalIPAddress"];
    }
    
    // If still not found, return default IP
    if (!localIP) {
        localIP = @"192.168.1.1";
    }
    
    return localIP;
}

// Get the current local IP address from the system
static NSString * __attribute__((unused)) getCurrentLocalIPAddress() {
    NSString *address = @"192.168.1.1"; // Default fallback
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    
    // Retrieve the current interfaces - returns 0 on success
    if (getifaddrs(&interfaces) == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if (temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on iOS
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                    break;
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    // Free memory
    freeifaddrs(interfaces);
    
    return address;
}

// Load scoped apps from the plist file
static NSDictionary *loadScopedApps(void) {
    return PXScopedAppsSnapshot();
}

// Check if the current app is in the scoped apps list
static BOOL isInScopedAppsList() {
    NSString *bundleID = getCurrentBundleID();
    if (!bundleID) {
        return NO;
    }
    
    NSDictionary *scopedApps = loadScopedApps();
    if (!scopedApps || scopedApps.count == 0) {
        return NO;
    }
    
    // Check if this bundle ID is in the scoped apps dictionary
    NSDictionary *appEntry = scopedApps[bundleID];
    if (!appEntry) {
        // Also try case-insensitive match
        NSString *lowercaseBundleID = [bundleID lowercaseString];
        for (NSString *key in scopedApps) {
            if ([[key lowercaseString] isEqualToString:lowercaseBundleID]) {
                appEntry = scopedApps[key];
                break;
            }
        }
        
        if (!appEntry) {
            return NO;
        }
    }
    
    // Check if the app is enabled
    BOOL isEnabled = [appEntry[@"enabled"] boolValue];
    return isEnabled;
}

// Get the current connection type setting from the plist
static NetworkConnectionType getNetworkConnectionType() {
    NSDate *now = [NSDate date];
    os_unfair_lock_lock(&gNetworkCacheLock);
    BOOL valid = cacheTimestamp && [now timeIntervalSinceDate:cacheTimestamp] < kCacheValidDuration;
    NetworkConnectionType cachedType = (NetworkConnectionType)cachedConnectionType;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    if (valid) return cachedType;

    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:kSecuritySettingsPath];
    BOOL enabled = [settings[@"networkDataSpoofEnabled"] boolValue];
    NetworkConnectionType type = enabled
        ? (NetworkConnectionType)([settings[@"networkConnectionType"] respondsToSelector:@selector(integerValue)]
            ? [settings[@"networkConnectionType"] integerValue]
            : NetworkConnectionTypeAuto)
        : (NetworkConnectionType)-1;

    os_unfair_lock_lock(&gNetworkCacheLock);
    cachedConnectionType = type;
    cachedNetworkDataSpoofEnabled = enabled;
    cacheTimestamp = now;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    return type;
}

// For Auto mode, decide randomly between WiFi and Cellular
static BOOL shouldUseWiFiForAutoMode() {
    // Use a persistent seed for the current process to ensure consistent behavior
    static BOOL isWiFi = NO;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        isWiFi = arc4random_uniform(2) == 0; // 50% chance
        PXLog(@"[NetworkHook] Auto mode initialized as: %@", isWiFi ? @"WiFi" : @"Cellular");
    });
    
    return isWiFi;
}

// Helper to check if we should spoof connection type for the current app
static BOOL shouldSpoofConnectionType() {
    NetworkConnectionType type = getNetworkConnectionType();
    
    // If spoofing is disabled or set to "None", don't spoof
    if (type == -1 || !PXNetworkDataSpoofEnabledCached() || type == NetworkConnectionTypeNone) {
        return NO;
    }
    
    // Check if the current app is a scoped app
    BOOL isScoped = isInScopedAppsList();
    
    // If it's a scoped app, we should apply the network spoofing
    if (isScoped) {
        NSString *bundleID = getCurrentBundleID();
        PXLog(@"[NetworkHook] App %@ is a scoped app, applying network spoofing", bundleID);
        return YES;
    }
    
    return NO;
}

// Helper to check if we should show as WiFi
static BOOL shouldShowAsWiFi() {
    NetworkConnectionType type = getNetworkConnectionType();
    
    if (type == NetworkConnectionTypeWiFi) {
        return YES;
    } else if (type == NetworkConnectionTypeAuto && shouldUseWiFiForAutoMode()) {
        return YES;
    }
    
    return NO;
}

// Helper to check if we should show as Cellular
static BOOL shouldShowAsCellular() {
    NetworkConnectionType type = getNetworkConnectionType();
    if (type == NetworkConnectionTypeCellular) {
        return YES;
    } else if (type == NetworkConnectionTypeAuto && !shouldUseWiFiForAutoMode()) {
        return YES;
    }
    return NO;
}

// Get carrier details from the current profile
static NSDictionary *getCarrierDetailsFromProfile() {
    NSDictionary *pinned = getTargetRegionPinnedOverrides();
    NSDate *now = [NSDate date];
    if (pinned) {
        NSDictionary *result = @{
            @"carrierName": pinned[@"carrierName"] ?: kFakeCarrierName,
            @"mobileCountryCode": pinned[@"mobileCountryCode"] ?: kFakeMobileCountryCode,
            @"mobileNetworkCode": pinned[@"mobileNetworkCode"] ?: kFakeMobileNetworkCode
        };
        os_unfair_lock_lock(&gNetworkCacheLock);
        cachedCarrierName = [result[@"carrierName"] copy];
        cachedMobileCountryCode = [result[@"mobileCountryCode"] copy];
        cachedMobileNetworkCode = [result[@"mobileNetworkCode"] copy];
        carrierDetailsCacheTimestamp = now;
        os_unfair_lock_unlock(&gNetworkCacheLock);
        return result;
    }

    os_unfair_lock_lock(&gNetworkCacheLock);
    BOOL valid = cachedCarrierName && cachedMobileCountryCode && cachedMobileNetworkCode &&
        carrierDetailsCacheTimestamp &&
        [now timeIntervalSinceDate:carrierDetailsCacheTimestamp] < kCarrierDetailsCacheValidDuration;
    NSDictionary *cached = valid ? @{
        @"carrierName": cachedCarrierName,
        @"mobileCountryCode": cachedMobileCountryCode,
        @"mobileNetworkCode": cachedMobileNetworkCode
    } : nil;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    if (cached) return cached;

    NSString *carrierName = kFakeCarrierName;
    NSString *mcc = kFakeMobileCountryCode;
    NSString *mnc = kFakeMobileNetworkCode;
    NSString *identityDir = getProfileIdentityPath();
    if (identityDir.length) {
        NSDictionary *carrier = [NSDictionary dictionaryWithContentsOfFile:
            [identityDir stringByAppendingPathComponent:@"carrier_details.plist"]];
        NSDictionary *network = [NSDictionary dictionaryWithContentsOfFile:
            [identityDir stringByAppendingPathComponent:@"network_settings.plist"]];
        NSDictionary *deviceIDs = [NSDictionary dictionaryWithContentsOfFile:PXActiveProfileDeviceIDsPath()];
        NSDictionary *source = carrier.count ? carrier : (network.count ? network : deviceIDs);
        NSString *sourceName = [source[@"carrierName"] isKindOfClass:[NSString class]] ? source[@"carrierName"] : source[@"CarrierName"];
        NSString *sourceMCC = [source[@"mcc"] isKindOfClass:[NSString class]] ? source[@"mcc"] : source[@"CarrierMCC"];
        NSString *sourceMNC = [source[@"mnc"] isKindOfClass:[NSString class]] ? source[@"mnc"] : source[@"CarrierMNC"];
        if (sourceName.length) carrierName = sourceName;
        if (sourceMCC.length) mcc = sourceMCC;
        if (sourceMNC.length) mnc = sourceMNC;
    }
    if (!carrierName.length || [carrierName isEqualToString:@"TLinkIOS"] || [carrierName hasPrefix:@"TLinkIOS"]) {
        carrierName = PXCarrierNameForMCCMNC(mcc, mnc);
    }
    NSDictionary *result = @{
        @"carrierName": carrierName ?: kFakeCarrierName,
        @"mobileCountryCode": mcc ?: kFakeMobileCountryCode,
        @"mobileNetworkCode": mnc ?: kFakeMobileNetworkCode
    };
    os_unfair_lock_lock(&gNetworkCacheLock);
    cachedCarrierName = [result[@"carrierName"] copy];
    cachedMobileCountryCode = [result[@"mobileCountryCode"] copy];
    cachedMobileNetworkCode = [result[@"mobileNetworkCode"] copy];
    carrierDetailsCacheTimestamp = now;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    return result;
}

// Get a realistic WiFi signal strength in dBm that changes gradually over time
static int getWiFiSignalStrength() {
    NSDate *now = [NSDate date];
    os_unfair_lock_lock(&gNetworkCacheLock);
    int current = currentWiFiSignalStrength;
    NSDate *last = lastSignalUpdateTime;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    if (last && [now timeIntervalSinceDate:last] < 30.0) return current;

    NetworkConnectionType type = getNetworkConnectionType();
    int target = -65;
    if (type == NetworkConnectionTypeWiFi || (type == NetworkConnectionTypeAuto && shouldUseWiFiForAutoMode())) {
        target = -45 - (int)arc4random_uniform(20);
    } else if (type == NetworkConnectionTypeCellular || (type == NetworkConnectionTypeAuto && !shouldUseWiFiForAutoMode())) {
        target = -60 - (int)arc4random_uniform(25);
    } else {
        target = -45 - (int)arc4random_uniform(45);
    }
    int diff = target - current;
    if (diff > 3) current += 3;
    else if (diff < -3) current -= 3;
    else current = target;
    current += (int)arc4random_uniform(3) - 1;
    current = MAX(-90, MIN(-40, current));

    os_unfair_lock_lock(&gNetworkCacheLock);
    currentWiFiSignalStrength = current;
    lastSignalUpdateTime = now;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    return current;
}

// Get realistic cellular signal bars (1-5) that change gradually over time
static int getCellularSignalBars() {
    NSDate *now = [NSDate date];
    os_unfair_lock_lock(&gNetworkCacheLock);
    int current = currentCellularSignalBars;
    NSDate *last = lastSignalUpdateTime;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    if (last && [now timeIntervalSinceDate:last] < 30.0) return current;

    NetworkConnectionType type = getNetworkConnectionType();
    int target = 3;
    if (type == NetworkConnectionTypeCellular || (type == NetworkConnectionTypeAuto && !shouldUseWiFiForAutoMode())) {
        target = 3 + (int)arc4random_uniform(3);
    } else if (type == NetworkConnectionTypeWiFi || (type == NetworkConnectionTypeAuto && shouldUseWiFiForAutoMode())) {
        target = 1 + (int)arc4random_uniform(4);
    } else {
        target = 1 + (int)arc4random_uniform(5);
    }
    if (target > current) current += 1;
    else if (target < current) current -= 1;
    current = MAX(1, MIN(5, current));

    os_unfair_lock_lock(&gNetworkCacheLock);
    currentCellularSignalBars = current;
    lastSignalUpdateTime = now;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    return current;
}

// Get a realistic cellular network type (4G/5G) that changes based on signal strength
static NSString *getCurrentCellularNetworkType() {
    NSDate *now = [NSDate date];
    os_unfair_lock_lock(&gNetworkCacheLock);
    NSString *currentType = currentCellularNetworkType ?: kCellularNetworkType4G;
    NSDate *lastChange = lastNetworkTypeChangeTime;
    int bars = currentCellularSignalBars;
    os_unfair_lock_unlock(&gNetworkCacheLock);

    if (!lastChange || [now timeIntervalSinceDate:lastChange] >= kMinNetworkTypeChangeDuration) {
        if (arc4random_uniform(100) < 10) {
            CGFloat probability = bars >= 5 ? 0.85 : bars == 4 ? 0.65 : bars == 3 ? 0.40 : bars == 2 ? 0.15 : 0.05;
            CGFloat random = (CGFloat)arc4random_uniform(100) / 100.0;
            currentType = random < probability
                ? (arc4random_uniform(100) < 70 ? kCellularNetworkType5GNSA : kCellularNetworkType5G)
                : kCellularNetworkType4G;
            lastChange = now;
        } else if (!lastChange) {
            lastChange = now;
        }
    }

    os_unfair_lock_lock(&gNetworkCacheLock);
    currentCellularNetworkType = [currentType copy];
    lastNetworkTypeChangeTime = lastChange;
    NSString *published = currentCellularNetworkType;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    return published;
}

#pragma mark - SCNetworkReachability Hooks

// Hook SCNetworkReachabilityGetFlags to modify network type
static Boolean (*original_SCNetworkReachabilityGetFlags)(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags *flags);

Boolean hooked_SCNetworkReachabilityGetFlags(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags *flags) {
    if (shouldShowAsWiFi()) {
        return original_SCNetworkReachabilityGetFlags(target, flags);
    }
    Boolean result = original_SCNetworkReachabilityGetFlags(target, flags);
    if (!result || !flags) {
        return result;
    }
    @try {
        if (!shouldSpoofConnectionType()) {
            return result;
        }
        if (shouldShowAsWiFi()) {
            *flags |= kSCNetworkReachabilityFlagsReachable;
            *flags &= ~kSCNetworkReachabilityFlagsIsWWAN;
        } else if (shouldShowAsCellular()) {
            *flags |= kSCNetworkReachabilityFlagsReachable;
            *flags |= kSCNetworkReachabilityFlagsIsWWAN;
        } else {
            *flags &= ~kSCNetworkReachabilityFlagsReachable;
            *flags &= ~kSCNetworkReachabilityFlagsIsWWAN;
        }
    } @catch (NSException *exception) {}
    return result;
}

#pragma mark - CoreTelephony Hooks

// Hook for CTTelephonyNetworkInfo
%hook CTTelephonyNetworkInfo

- (NSDictionary<NSString *, CTCarrier *> *)serviceSubscriberCellularProviders {
    if (shouldShowAsWiFi()) {
        return %orig;
    }
    
    NSDictionary<NSString *, CTCarrier *> *origDict = %orig;
    return origDict;
}

- (CTCarrier *)subscriberCellularProvider {
    if (shouldShowAsWiFi()) {
        return %orig;
    }
    
    return %orig;
}

- (NSString *)currentRadioAccessTechnology {
    if (shouldShowAsWiFi()) {
        return %orig;
    } else if (shouldShowAsCellular()) {
        return getCurrentCellularNetworkType();
    }
    return %orig;
}

- (NSDictionary<NSString *, NSString *> *)serviceCurrentRadioAccessTechnology {
    if (shouldShowAsWiFi()) {
        return %orig;
    } else if (shouldShowAsCellular()) {
        return @{ @"0": getCurrentCellularNetworkType() };
    }
    return %orig;
}

%end

// Hook for CTCarrier
%hook CTCarrier

- (NSString *)carrierName {
    if (shouldShowAsWiFi() && !shouldForceCarrierSpoof()) {
        return %orig;
    } else if (shouldShowAsCellular()) {
        return getCarrierDetailsFromProfile()[@"carrierName"];
    }
    if (shouldForceCarrierSpoof()) {
        return getCarrierDetailsFromProfile()[@"carrierName"];
    }
    return %orig;
}

- (NSString *)mobileCountryCode {
    if (shouldShowAsWiFi() && !shouldForceCarrierSpoof()) {
        return %orig;
    } else if (shouldShowAsCellular()) {
        return getCarrierDetailsFromProfile()[@"mobileCountryCode"];
    }
    if (shouldForceCarrierSpoof()) {
        return getCarrierDetailsFromProfile()[@"mobileCountryCode"];
    }
    return %orig;
}

- (NSString *)mobileNetworkCode {
    if (shouldShowAsWiFi() && !shouldForceCarrierSpoof()) {
        return %orig;
    } else if (shouldShowAsCellular()) {
        return getCarrierDetailsFromProfile()[@"mobileNetworkCode"];
    }
    if (shouldForceCarrierSpoof()) {
        return getCarrierDetailsFromProfile()[@"mobileNetworkCode"];
    }
    return %orig;
}

- (NSString *)isoCountryCode {
    if (shouldShowAsWiFi() && !shouldForceCarrierSpoof()) {
        return %orig;
    } else if (shouldShowAsCellular()) {
        return getCurrentISOCountryCode();
    }
    if (shouldForceCarrierSpoof()) {
        return getCurrentISOCountryCode();
    }
    return %orig;
}

- (BOOL)allowsVOIP {
    if (shouldShowAsWiFi()) {
        return %orig;
    }
    
    // Allow VOIP in all network modes
    return YES;
}

%end

#pragma mark - NSURLSession and CFNetwork Hooks

// Hook for cellular detection in NSURLSession
%hook NSURLSessionConfiguration

- (BOOL)allowsCellularAccess {
    if (shouldShowAsWiFi()) {
        return %orig;
    }
    
    return %orig;
}

- (BOOL)isDiscretionary {
    if (shouldShowAsWiFi()) {
        return %orig;
    }
    
    // Discretionary transfers are typically used for background transfers 
    // that prefer WiFi. Return NO to indicate high priority connection.
    return NO;
}

%end

#pragma mark - getifaddrs Hook for Local IP Address

// Enable getifaddrs hook for local IP spoofing
static int (*original_getifaddrs)(struct ifaddrs **);
static int hooked_getifaddrs(struct ifaddrs **ifap) {
    int result = original_getifaddrs(ifap);
    if (result != 0 || !ifap || !*ifap) {
        return result;
    }
    
    // Get spoofed IP values from profile
    NSString *spoofedIPv4 = getProfileLocalIPAddress();
    NSString *spoofedIPv6 = [NetworkManager getSavedLocalIPv6Address];
    
    // Check if we have any custom IP to spoof (not default values)
    BOOL hasSpoofedIPv4 = spoofedIPv4 && ![spoofedIPv4 isEqualToString:@"192.168.1.1"];
    BOOL hasSpoofedIPv6 = spoofedIPv6 && spoofedIPv6.length > 0;
    
    // If no custom IPs are set, don't modify anything
    if (!hasSpoofedIPv4 && !hasSpoofedIPv6) {
        return result;
    }
    
    PXLog(@"[NetworkHook] Spoofing local IPs - IPv4: %@, IPv6: %@", 
          spoofedIPv4 ?: @"(none)", spoofedIPv6 ?: @"(none)");
    
    struct ifaddrs *ifa = *ifap;
    
    // Determine interface to modify based on connection type setting
    NetworkConnectionType type = getNetworkConnectionType();
    BOOL useWiFiInterface = YES; // Default to en0 (WiFi)
    
    if (shouldSpoofConnectionType()) {
        // If connection type spoofing is enabled, respect the setting
        if (type == NetworkConnectionTypeCellular || 
            (type == NetworkConnectionTypeAuto && !shouldUseWiFiForAutoMode())) {
            useWiFiInterface = NO; // Use pdp_ip0 (cellular)
        }
    }
    
    // Interface names
    const char *targetInterface = useWiFiInterface ? "en0" : "pdp_ip0";
    const char *clearInterface = useWiFiInterface ? "pdp_ip0" : "en0";
    
    while (ifa) {
        if (ifa->ifa_addr) {
            // Handle IPv4
            if (ifa->ifa_addr->sa_family == AF_INET) {
                if (strcmp(ifa->ifa_name, targetInterface) == 0 && hasSpoofedIPv4) {
                    struct sockaddr_in *sin = (struct sockaddr_in *)ifa->ifa_addr;
                    sin->sin_addr.s_addr = inet_addr([spoofedIPv4 UTF8String]);
                    PXLog(@"[NetworkHook] Spoofed %s IPv4 to %@", targetInterface, spoofedIPv4);
                }
                // Clear the other interface if connection type spoofing is active
                if (shouldSpoofConnectionType() && strcmp(ifa->ifa_name, clearInterface) == 0) {
                    struct sockaddr_in *sin = (struct sockaddr_in *)ifa->ifa_addr;
                    sin->sin_addr.s_addr = 0;
                }
            }
            // Handle IPv6
            else if (ifa->ifa_addr->sa_family == AF_INET6) {
                if (strcmp(ifa->ifa_name, targetInterface) == 0 && hasSpoofedIPv6) {
                    struct sockaddr_in6 *sin6 = (struct sockaddr_in6 *)ifa->ifa_addr;
                    inet_pton(AF_INET6, [spoofedIPv6 UTF8String], &sin6->sin6_addr);
                    PXLog(@"[NetworkHook] Spoofed %s IPv6 to %@", targetInterface, spoofedIPv6);
                }
                // Clear the other interface if connection type spoofing is active
                if (shouldSpoofConnectionType() && strcmp(ifa->ifa_name, clearInterface) == 0) {
                    struct sockaddr_in6 *sin6 = (struct sockaddr_in6 *)ifa->ifa_addr;
                    memset(&sin6->sin6_addr, 0, sizeof(sin6->sin6_addr));
                }
            }
        }
        ifa = ifa->ifa_next;
    }
    
    return result;
}

#pragma mark - Network.framework Hooks (iOS 12+)

// Attempt to hook NWPathMonitor for newer iOS versions
%group NetworkFrameworkHooks

%hook NWPath

- (BOOL)isExpensive {
    if (shouldShowAsWiFi()) {
        return %orig;
    }
    
    // WiFi is not expensive, cellular is
    return shouldShowAsCellular();
}

- (BOOL)usesInterfaceType:(NSInteger)type {
    if (shouldShowAsWiFi()) {
        // Interface type 1 is typically WiFi
        if (type == 1) {
            return YES;
        }
        // Interface type 2 is typically cellular
        else if (type == 2) {
            return NO;
        }
    }
    // For cellular mode
    else {
        // Interface type 1 is typically WiFi
        if (type == 1) {
            return NO;
        }
        // Interface type 2 is typically cellular
        else if (type == 2) {
            return YES;
        }
    }
    
    return %orig;
}

%end

%end

// Notification callback for settings changes
static void networkSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    PXNetworkInvalidateCaches();
}

// Notification callback for ISO country code changes
static void isoCountryCodeChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    PXNetworkInvalidateCaches();
}

// Notification callback for scoped apps changes
static void scopedAppsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    PXNetworkInvalidateCaches();
    PXInvalidateScopeDecisionCache();
}

// Notification callback for carrier details changes
static void carrierDetailsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    PXNetworkInvalidateCaches();
}

// Notification callback for signal strength settings changes
static void signalStrengthSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    PXNetworkInvalidateCaches();
}

// Hook for WiFi signal strength (CNCopyCurrentNetworkInfo)
static CFDictionaryRef (*original_CNCopyCurrentNetworkInfo)(CFStringRef interfaceName);

static CFDictionaryRef hooked_CNCopyCurrentNetworkInfo(CFStringRef interfaceName) {
    if (shouldShowAsWiFi()) {
        return original_CNCopyCurrentNetworkInfo(interfaceName);
    }
    // Always call the original so WiFiHook.x can spoof as needed
    CFDictionaryRef originalDict = original_CNCopyCurrentNetworkInfo(interfaceName);
    if (!originalDict) return originalDict;
    // Existing WiFi signal strength spoofing logic
    CFMutableDictionaryRef newDict = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, originalDict);
    int signalStrength = getWiFiSignalStrength();
    CFNumberRef rssiNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &signalStrength);
    CFDictionarySetValue(newDict, CFSTR("RSSI"), rssiNumber);
    CFRelease(originalDict);
    CFRelease(rssiNumber);
    return newDict;
}

// Add hooks for CoreTelephony signal strength
%hook CTServiceDescriptor

- (NSString *)signalStrengthBars {
    if (shouldShowAsWiFi()) {
        return %orig;
    }
    
    // Return spoofed signal bars
    int bars = getCellularSignalBars();
    NSString *barsString = [NSString stringWithFormat:@"%d", bars];
    
    PXLog(@"[NetworkHook] Spoofed cellular signal bars to %@", barsString);
    
    return barsString;
}

%end

%hook UIStatusBarSignalStrengthItemView

- (void)setCellularSignalStrengthBars:(int)bars {
    if (shouldShowAsWiFi()) {
        %orig;
        return;
    }
    
    // Get spoofed signal bars
    int spoofedBars = getCellularSignalBars();
    
    PXLog(@"[NetworkHook] Spoofed UI cellular signal bars from %d to %d", bars, spoofedBars);
    
    %orig(spoofedBars);
}

%end

#pragma mark - Initialization

%ctor {
    @autoreleasepool {
        if (PXIsSpringBoardProcess()) return;

        NSString *bundleID = getCurrentBundleID();
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (PXIsCriticalSystemProcess(bundleID, proc)) return;
        if (PXIsWebKitHelperProcess(bundleID, proc)) return;

        BOOL isScoped = PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack);
        if (!isScoped) return;
        PXLog(@"[NetworkHook] Installing network hooks for %@", bundleID ?: @"(unknown)");

        {
            // Initialize CoreTelephony hooks
            %init;
            
            // Initialize Network.framework hooks if available
            Class NWPathClass = NSClassFromString(@"NWPath");
            if (NWPathClass) {
                %init(NetworkFrameworkHooks);
                PXLog(@"[NetworkHook] Successfully initialized Network.framework hooks");
            }
            
            // Setup the SCNetworkReachabilityGetFlags hook
            void *SCNetworkReachabilityGetFlagsPtr = dlsym(RTLD_DEFAULT, "SCNetworkReachabilityGetFlags");
            if (SCNetworkReachabilityGetFlagsPtr) {
                // Use ElleKit for hooking (preferred for iOS 15+)
                MSHookFunction(SCNetworkReachabilityGetFlagsPtr, 
                       (void *)hooked_SCNetworkReachabilityGetFlags, 
                       (void **)&original_SCNetworkReachabilityGetFlags);
                PXLog(@"[NetworkHook] Successfully hooked SCNetworkReachabilityGetFlags");
            } else {
                PXLog(@"[NetworkHook] ERROR: Could not find SCNetworkReachabilityGetFlags function!");
            }
            
            // getifaddrs is coordinator-owned — skip direct MSHookFunction (Tweak/network providers).
            PXLog(@"[NetworkHook] Skipping direct getifaddrs hook (PXNativeHookCoordinator owns symbol)");
            
            // Note: We don't hook CNCopySupportedInterfaces or CNCopyCurrentNetworkInfo
            // as they are already handled by WiFiHook.x for SSID/BSSID spoofing
            
            // Register for notification when settings change
            CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
            CFNotificationCenterAddObserver(darwinCenter, NULL, networkSettingsChanged,
                                           CFSTR("com.hydra.tlinkios.settings.changed"), NULL,
                                           CFNotificationSuspensionBehaviorDeliverImmediately);
            CFNotificationCenterAddObserver(darwinCenter, NULL, networkSettingsChanged,
                                           CFSTR("com.hydra.tlinkios.profileChanged"), NULL,
                                           CFNotificationSuspensionBehaviorDeliverImmediately);
            CFNotificationCenterAddObserver(darwinCenter,
                                           NULL,
                                           networkSettingsChanged,
                                           CFSTR("com.hydra.tlinkios.networkConnectionTypeChanged"),
                                           NULL,
                                           CFNotificationSuspensionBehaviorDeliverImmediately);
            
            // Register for notification when ISO country code changes
            CFNotificationCenterAddObserver(darwinCenter,
                                           NULL,
                                           isoCountryCodeChanged,
                                           CFSTR("com.hydra.tlinkios.networkISOCountryCodeChanged"),
                                           NULL,
                                           CFNotificationSuspensionBehaviorDeliverImmediately);
            
            // Register for notification when scoped apps change
            CFNotificationCenterAddObserver(darwinCenter,
                                           NULL,
                                           scopedAppsChanged,
                                           CFSTR("com.hydra.tlinkios.scopedAppsChanged"),
                                           NULL,
                                           CFNotificationSuspensionBehaviorDeliverImmediately);
            
            // Register for notification when carrier details change
            CFNotificationCenterAddObserver(darwinCenter,
                                           NULL,
                                           carrierDetailsChanged,
                                           CFSTR("com.hydra.tlinkios.carrierDetailsChanged"),
                                           NULL,
                                           CFNotificationSuspensionBehaviorDeliverImmediately);
            
            // Register for notification when signal strength settings change
            CFNotificationCenterAddObserver(darwinCenter,
                                           NULL,
                                           signalStrengthSettingsChanged,
                                           CFSTR("com.hydra.tlinkios.signalStrengthSettingsChanged"),
                                           NULL,
                                           CFNotificationSuspensionBehaviorDeliverImmediately);
            
            // Log initial state
            NetworkConnectionType initialType = getNetworkConnectionType();
            if (initialType != -1) {
                NSString *connectionName;
                switch (initialType) {
                    case NetworkConnectionTypeNone:
                        connectionName = @"None";
                        break;
                    case NetworkConnectionTypeWiFi:
                        connectionName = @"WiFi";
                        break;
                    case NetworkConnectionTypeCellular:
                        connectionName = @"Cellular";
                        break;
                    case NetworkConnectionTypeAuto:
                        connectionName = @"Auto";
                        break;
                    default:
                        connectionName = @"Unknown";
                        break;
                }
                
                if (initialType == NetworkConnectionTypeWiFi || 
                    (initialType == NetworkConnectionTypeAuto && shouldUseWiFiForAutoMode())) {
                    NSString *localIP = getProfileLocalIPAddress();
                    PXLog(@"[NetworkHook] Network connection type spoofing enabled with type: %@ (Local IP: %@) for scoped app: %@", 
                          connectionName, localIP, bundleID);
                } else if (initialType == NetworkConnectionTypeCellular ||
                          (initialType == NetworkConnectionTypeAuto && !shouldUseWiFiForAutoMode())) {
                    NSString *isoCode = getCurrentISOCountryCode();
                    PXLog(@"[NetworkHook] Network connection type spoofing enabled with type: %@ (ISO: %@) for scoped app: %@", 
                          connectionName, isoCode, bundleID);
                } else {
                    PXLog(@"[NetworkHook] Network connection type spoofing enabled with type: %@ for scoped app: %@", 
                          connectionName, bundleID);
                }
            } else {
                PXLog(@"[NetworkHook] Network connection type spoofing disabled");
            }
            
            // CNCopyCurrentNetworkInfo: WiFi module builds final dictionary; network provides policy only.
            // Do not install a second MSHookFunction — coordinator owns the symbol.
            PXLog(@"[NetworkHook] Skipping direct CNCopyCurrentNetworkInfo hook (coordinator/WiFi owns; policy-only)");
        }
    }
} 
