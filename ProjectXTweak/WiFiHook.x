#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <NetworkExtension/NetworkExtension.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "ProjectXLogging.h"
#import "WiFiManager.h"
#import <substrate.h>
// #import <ellekit/ellekit.h> // Removed for rootful - using Substrate
#import <Network/Network.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <ifaddrs.h>
#import <net/if.h>
#import "MethodSwizzler.h"
#import "PXConfigProviderC.h"

#import "PXScope.h"


// Forward declarations for private API methods
@interface NWPath (WeaponXPrivate)
- (NSString *)_getSSID;
- (id)_getBSSID;
- (NSInteger)quality;
- (double)latency;
- (id)gatherDiagnostics;
- (BOOL)isExpensive;
- (BOOL)isConstrained;
@end

@interface URLSessionTaskTransactionMetrics : NSObject
@property (nonatomic, readonly) NSURLRequest *request;
@property (nonatomic, readonly) NSURLResponse *response;
@property (nonatomic, readonly) NSDate *fetchStartDate;
@property (nonatomic, readonly) NSDate *domainLookupStartDate;
@property (nonatomic, readonly) NSDate *domainLookupEndDate;
@property (nonatomic, readonly) NSDate *connectStartDate;
@property (nonatomic, readonly) NSDate *connectEndDate;
@property (nonatomic, readonly) NSDate *secureConnectionStartDate;
@property (nonatomic, readonly) NSDate *secureConnectionEndDate;
@property (nonatomic, readonly) NSDate *requestStartDate;
@property (nonatomic, readonly) NSDate *requestEndDate;
@property (nonatomic, readonly) NSDate *responseStartDate;
@property (nonatomic, readonly) NSDate *responseEndDate;
@end

@interface URLSessionTaskMetrics : NSObject
@property (nonatomic, readonly) NSArray<URLSessionTaskTransactionMetrics *> *transactionMetrics;
@property (nonatomic, readonly) NSDate *taskInterval;
@property (nonatomic, readonly) int64_t countOfBytesReceived;
@property (nonatomic, readonly) int64_t countOfBytesSent;
@end

// MobileWiFi framework typedefs and functions (private API)
typedef struct __WiFiDeviceClient *WiFiDeviceClientRef;
typedef struct __WiFiNetwork *WiFiNetworkRef;
typedef struct __WiFiManager *WiFiManagerRef;

// Function pointers for the original functions we'll hook
static CFDictionaryRef (*orig_CNCopyCurrentNetworkInfo)(CFStringRef interfaceName);
static id (*orig_dictionaryWithScanResult)(id self, SEL _cmd, id arg1);

// MobileWiFi.framework function pointers
static WiFiManagerRef (*orig_WiFiManagerClientCreate)(CFAllocatorRef allocator, int flags);
static WiFiNetworkRef (*orig_WiFiDeviceClientCopyCurrentNetwork)(WiFiDeviceClientRef client);
static CFStringRef (*orig_WiFiNetworkGetSSID)(WiFiNetworkRef network);
static CFStringRef (*orig_WiFiNetworkGetBSSID)(WiFiNetworkRef network);


// Forward declarations
static NSString *getCurrentBundleID(void);
static NSDictionary *loadScopedApps(void);
static BOOL isInScopedAppsList(void);

#pragma mark - Profile Detection Helpers

static BOOL shouldSpoofForBundle(NSString *bundleID) {
    if (!bundleID) return NO;
    NSString *proc = [NSProcessInfo processInfo].processName;
    if (PXAllowUnscopedSafariStack() || (PXSafariStackSpoofEnabled() && PXIsSafariStackProcess(bundleID, proc))) {
        return YES;
    }
    return PXIsWiFiSpoofingEnabled();
}

// Helper function to directly get current profile ID from plist
static NSString *getCurrentProfileID(void) {
    // Direct access to the current profile info plist
    NSString *centralInfoPath = @"/var/mobile/Library/WeaponX/Profiles/current_profile_info.plist";
    NSDictionary *centralInfo = [NSDictionary dictionaryWithContentsOfFile:centralInfoPath];
    
    NSString *profileId = centralInfo[@"ProfileId"];
    if (profileId) {
        return profileId;
    }
    
    // Fallback to legacy location if needed
    NSString *legacyInfoPath = @"/var/mobile/Library/WeaponX/active_profile_info.plist";
    NSDictionary *legacyInfo = [NSDictionary dictionaryWithContentsOfFile:legacyInfoPath];
    profileId = legacyInfo[@"ProfileId"];
    
    if (profileId) {
        return profileId;
    }
    
    // Last resort - scan for profiles
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *profilesDir = @"/var/mobile/Library/WeaponX/Profiles";
    NSError *error = nil;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:profilesDir error:&error];
    
    if (!error && contents.count > 0) {
        // Find the first numeric directory
        for (NSString *item in contents) {
            if ([item isEqualToString:@"profiles.plist"] || 
                [item isEqualToString:@"current_profile_info.plist"]) {
                continue;
            }
            
            BOOL isDir = NO;
            NSString *fullPath = [profilesDir stringByAppendingPathComponent:item];
            [fileManager fileExistsAtPath:fullPath isDirectory:&isDir];
            
            if (isDir) {
                profileId = item;
                break;
            }
        }
    }
    
    return profileId ?: @"default";
}

// Get current WiFi info from appropriate profile
static NSDictionary *getProfileWiFiInfo(void) {
    // Skip cache if it's more than 5 minutes old
    BOOL shouldRefresh = NO;
    if (!cacheTimestamp || [[NSDate date] timeIntervalSinceDate:cacheTimestamp] > kCacheValidityDuration) {
        shouldRefresh = YES;
    }
    
    // Get current profile ID (use cache if available)
    NSString *profileId = cachedProfileId;
    if (!profileId || shouldRefresh) {
        profileId = getCurrentProfileID();
        cachedProfileId = profileId;
        cacheTimestamp = [NSDate date];
    }
    
    if (!profileId) {
        return nil;
    }
    
    // If cache is valid and we have WiFi info, return it
    if (!shouldRefresh && cachedWifiInfo && cachedWifiInfo[@"ssid"] && cachedWifiInfo[@"bssid"]) {
        return cachedWifiInfo;
    }
    
    // Build path to WiFi info file in profile directory
    NSString *profileDir = [NSString stringWithFormat:@"/var/mobile/Library/WeaponX/Profiles/%@", profileId];
    NSString *identityDir = [profileDir stringByAppendingPathComponent:@"identity"];
    NSString *wifiInfoPath = [identityDir stringByAppendingPathComponent:@"wifi_info.plist"];
    NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
    
    // First try wifi_info.plist
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:wifiInfoPath]) {
        NSDictionary *wifiInfo = [NSDictionary dictionaryWithContentsOfFile:wifiInfoPath];
        if (wifiInfo && wifiInfo[@"ssid"] && wifiInfo[@"bssid"]) {
            return wifiInfo;
        }
    }
    
    // Then try device_ids.plist
    if ([fileManager fileExistsAtPath:deviceIdsPath]) {
        NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
        if (deviceIds[@"SSID"] && deviceIds[@"BSSID"]) {
            NSMutableDictionary *wifiInfo = [NSMutableDictionary dictionary];
            wifiInfo[@"ssid"] = deviceIds[@"SSID"];
            wifiInfo[@"bssid"] = deviceIds[@"BSSID"];
            wifiInfo[@"networkType"] = @"Infrastructure";
            
            return wifiInfo;
        }
        
        // If WiFi value is stored as a formatted string
        NSString *wifiValue = deviceIds[@"WiFi"];
        if (wifiValue && [wifiValue containsString:@"("]) {
            NSRange openParenRange = [wifiValue rangeOfString:@"("];
            NSRange closeParenRange = [wifiValue rangeOfString:@")"];
            
            if (openParenRange.location != NSNotFound && closeParenRange.location != NSNotFound) {
                NSString *ssid = [wifiValue substringToIndex:openParenRange.location - 1];
                NSString *bssid = [wifiValue substringWithRange:NSMakeRange(openParenRange.location + 1, 
                                                                closeParenRange.location - openParenRange.location - 1)];
                
                NSMutableDictionary *wifiInfo = [NSMutableDictionary dictionary];
                wifiInfo[@"ssid"] = ssid;
                wifiInfo[@"bssid"] = bssid;
                wifiInfo[@"networkType"] = @"Infrastructure";
                
                return wifiInfo;
            }
        }
    }
    
    // Fallback - try to get from WiFiManager if available
    if (NSClassFromString(@"WiFiManager")) {
        id wifiManager = [NSClassFromString(@"WiFiManager") sharedManager];
        if ([wifiManager respondsToSelector:@selector(currentWiFiInfo)]) {
            NSDictionary *wifiInfo = [wifiManager currentWiFiInfo];
            if (wifiInfo && wifiInfo[@"ssid"] && wifiInfo[@"bssid"]) {
                return wifiInfo;
            }
        }
        
        // Generate new info if needed
        if ([wifiManager respondsToSelector:@selector(generateWiFiInfo)]) {
            NSDictionary *wifiInfo = [wifiManager generateWiFiInfo];
            if (wifiInfo && wifiInfo[@"ssid"] && wifiInfo[@"bssid"]) {
                // Save it to the profile for future use
                if ([fileManager fileExistsAtPath:identityDir] || 
                    [fileManager createDirectoryAtPath:identityDir withIntermediateDirectories:YES attributes:nil error:nil]) {
                    [wifiInfo writeToFile:wifiInfoPath atomically:YES];
                    
                    // Also update device_ids.plist
                    NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath];
                    if (!deviceIds) deviceIds = [NSMutableDictionary dictionary];
                    deviceIds[@"SSID"] = wifiInfo[@"ssid"];
                    deviceIds[@"BSSID"] = wifiInfo[@"bssid"];
                    deviceIds[@"WiFi"] = [NSString stringWithFormat:@"%@ (%@)", wifiInfo[@"ssid"], wifiInfo[@"bssid"]];
                    [deviceIds writeToFile:deviceIdsPath atomically:YES];
                }
                
                return wifiInfo;
            }
        }
    }
    
    // Return nil if all methods failed
    return nil;
}

#pragma mark - Core Hook Functions

// Implementation of CNCopyCurrentNetworkInfo hook
static CFDictionaryRef replaced_CNCopyCurrentNetworkInfo(CFStringRef interfaceName) {
    // Get the original result first
    CFDictionaryRef originalDict = orig_CNCopyCurrentNetworkInfo ? orig_CNCopyCurrentNetworkInfo(interfaceName) : NULL;
    
    @try {
        // Get the bundle ID for scope checking
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        // Check if we should spoof for this bundle
        if (!shouldSpoofForBundle(bundleID)) {
            return originalDict;
        }
        
        // Use PXConfigProvider
        NSMutableDictionary *spoofedInfo = [NSMutableDictionary dictionary];
        spoofedInfo[@"SSID"] = PXGetSpoofedWiFiSSID();
        spoofedInfo[@"BSSID"] = PXGetSpoofedWiFiBSSID();
        spoofedInfo[@"NetworkType"] = @"Infrastructure";
        
        return CFBridgingRetain(spoofedInfo);
    } @catch (NSException *exception) {
        // Silent exception handling
    }
    
    // Return original if spoofing failed
    return originalDict;
}

// Implementation of NEHotspotHelper dictionaryWithScanResult: hook
static id replaced_dictionaryWithScanResult(id self, SEL _cmd, id arg1) {
    id originalResult = nil;
    if (orig_dictionaryWithScanResult) {
        originalResult = orig_dictionaryWithScanResult(self, _cmd, arg1);
    }
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return originalResult;
    }
    
    if (!originalResult || ![originalResult isKindOfClass:[NSDictionary class]]) {
        return originalResult;
    }

    NSMutableDictionary *modifiedResult = [NSMutableDictionary dictionaryWithDictionary:originalResult];
    modifiedResult[@"SSID"] = PXGetSpoofedWiFiSSID();
    modifiedResult[@"BSSID"] = PXGetSpoofedWiFiBSSID();

    return modifiedResult;
}

#pragma mark - Swizzle Implementations for NEHotspotNetwork

// Swizzle replacements for NEHotspotNetwork
@implementation NEHotspotNetwork (WeaponXHooks)

- (NSString *)weaponx_SSID {
    // Check if we should spoof
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return [self weaponx_SSID]; // Call original
    }
    
    return PXGetSpoofedWiFiSSID();
    
    // Call original as fallback
    return [self weaponx_SSID];
}

- (NSString *)weaponx_BSSID {
    // Check if we should spoof
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return [self weaponx_BSSID]; // Call original
    }
    
    return PXGetSpoofedWiFiBSSID();
    
    // Call original as fallback
    return [self weaponx_BSSID];
}

// Additional NEHotspotNetwork property hook for signal strength
- (NSNumber *)weaponx_signalStrength {
    // Check if we should spoof
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return [self weaponx_signalStrength]; // Call original
    }
    
    // Return a realistic signal strength (0.7-0.9 range for good strength)
    double strength = 0.7 + ((double)arc4random_uniform(20) / 100.0);
    return @(strength);
}

// Additional NEHotspotNetwork property hook for secure flag
- (BOOL)weaponx_secure {
    // Check if we should spoof
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return [self weaponx_secure]; // Call original
    }
    
    // Most networks are secure, so default to YES (true)
    return YES;
}

@end

#pragma mark - MobileWiFi Framework Hooks

// Hook implementation for WiFiManagerClientCreate
static WiFiManagerRef replaced_WiFiManagerClientCreate(CFAllocatorRef allocator, int flags) {
    // Call original implementation
    WiFiManagerRef result = orig_WiFiManagerClientCreate(allocator, flags);
    return result;
}

// Hook implementation for WiFiDeviceClientCopyCurrentNetwork
static WiFiNetworkRef replaced_WiFiDeviceClientCopyCurrentNetwork(WiFiDeviceClientRef client) {
    // Call original implementation
    WiFiNetworkRef result = orig_WiFiDeviceClientCopyCurrentNetwork(client);
    return result;
}

// Hook implementation for WiFiNetworkGetSSID
static CFStringRef replaced_WiFiNetworkGetSSID(WiFiNetworkRef network) {
    // Check if we should spoof
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return orig_WiFiNetworkGetSSID(network);
    }
    
    return (__bridge CFStringRef)PXGetSpoofedWiFiSSID();
    
    // Call original as fallback
    return orig_WiFiNetworkGetSSID(network);
}

// Hook implementation for WiFiNetworkGetBSSID
static CFStringRef replaced_WiFiNetworkGetBSSID(WiFiNetworkRef network) {
    // Check if we should spoof
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return orig_WiFiNetworkGetBSSID(network);
    }
    
    return (__bridge CFStringRef)PXGetSpoofedWiFiBSSID();
    
    // Call original as fallback
    return orig_WiFiNetworkGetBSSID(network);
}

#pragma mark - Hook Installation

static void initializeHooks(void) {
    // Install CNCopyCurrentNetworkInfo hook using Substrate
    void *symbol = dlsym(RTLD_DEFAULT, "CNCopyCurrentNetworkInfo");
    if (symbol) {
        MSHookFunction(symbol, 
                       (void *)replaced_CNCopyCurrentNetworkInfo, 
                       (void **)&orig_CNCopyCurrentNetworkInfo);
    } else {
        // Try to find the symbol in the framework
        void *captiveNetworkLib = dlopen("/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration", RTLD_NOW);
        if (captiveNetworkLib) {
            symbol = dlsym(captiveNetworkLib, "CNCopyCurrentNetworkInfo");
            if (symbol) {
                MSHookFunction(symbol, 
                      (void *)replaced_CNCopyCurrentNetworkInfo, 
                      (void **)&orig_CNCopyCurrentNetworkInfo);
            }
            dlclose(captiveNetworkLib);
        }
    }
    
    // Install NEHotspotHelper hook using method swizzling
    Class neHotspotHelperClass = NSClassFromString(@"NEHotspotHelper");
    if (neHotspotHelperClass) {
        Method dictionaryMethod = class_getClassMethod(neHotspotHelperClass, @selector(dictionaryWithScanResult:));
        if (dictionaryMethod) {
            orig_dictionaryWithScanResult = (id (*)(id, SEL, id))method_getImplementation(dictionaryMethod);
            method_setImplementation(dictionaryMethod, (IMP)replaced_dictionaryWithScanResult);
        }
    }
    
    // Install NEHotspotNetwork swizzles
    Class neHotspotNetworkClass = NSClassFromString(@"NEHotspotNetwork");
    if (neHotspotNetworkClass) {
        [MethodSwizzler swizzleClass:neHotspotNetworkClass 
                   originalSelector:@selector(SSID) 
                   swizzledSelector:@selector(weaponx_SSID)];
        
        [MethodSwizzler swizzleClass:neHotspotNetworkClass 
                   originalSelector:@selector(BSSID) 
                   swizzledSelector:@selector(weaponx_BSSID)];
        
        // Add additional property swizzles
        [MethodSwizzler swizzleClass:neHotspotNetworkClass 
                   originalSelector:@selector(signalStrength) 
                   swizzledSelector:@selector(weaponx_signalStrength)];
                   
        [MethodSwizzler swizzleClass:neHotspotNetworkClass 
                   originalSelector:@selector(secure) 
                   swizzledSelector:@selector(weaponx_secure)];
    }
    
    // Install MobileWiFi framework hooks
    void *mobileWiFiLib = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi", RTLD_NOW);
    if (mobileWiFiLib) {
        // Hook WiFiManagerClientCreate
        symbol = dlsym(mobileWiFiLib, "WiFiManagerClientCreate");
        if (symbol) {
            MSHookFunction(symbol, 
                  (void *)replaced_WiFiManagerClientCreate, 
                  (void **)&orig_WiFiManagerClientCreate);
        }
        
        // Hook WiFiDeviceClientCopyCurrentNetwork
        symbol = dlsym(mobileWiFiLib, "WiFiDeviceClientCopyCurrentNetwork");
        if (symbol) {
            MSHookFunction(symbol, 
                  (void *)replaced_WiFiDeviceClientCopyCurrentNetwork, 
                  (void **)&orig_WiFiDeviceClientCopyCurrentNetwork);
        }
        
        // Hook WiFiNetworkGetSSID
        symbol = dlsym(mobileWiFiLib, "WiFiNetworkGetSSID");
        if (symbol) {
            MSHookFunction(symbol, 
                  (void *)replaced_WiFiNetworkGetSSID, 
                  (void **)&orig_WiFiNetworkGetSSID);
        }
        
        // Hook WiFiNetworkGetBSSID
        symbol = dlsym(mobileWiFiLib, "WiFiNetworkGetBSSID");
        if (symbol) {
            MSHookFunction(symbol, 
                  (void *)replaced_WiFiNetworkGetBSSID, 
                  (void **)&orig_WiFiNetworkGetBSSID);
        }
        
        dlclose(mobileWiFiLib);
    }
}

#pragma mark - Notification Handlers

#pragma mark - NWPathMonitor Hooks (Network Framework)

// Hook for NWPath methods
%hook NWPath

- (BOOL)usesInterfaceType:(NSInteger)type {
    // We don't modify this as it would break connectivity detection
    return %orig;
}

- (NSString *)_getSSID {
    // Check if we should spoof
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return %orig;
    }
    
    return PXGetSpoofedWiFiSSID();
    
}

- (id)_getBSSID {
    // Check if we should spoof
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return %orig;
    }
    
    return PXGetSpoofedWiFiBSSID();
    
}

- (NSInteger)quality {
    return %orig;
}

- (double)latency {
    return %orig;
}

- (BOOL)isExpensive {
    return %orig;
}

- (BOOL)isConstrained {
    return %orig;
}

- (id)gatherDiagnostics {
    return %orig;
}

%end

// Hook NWPathMonitor class
%hook NWPathMonitor

- (void)setPathUpdateHandler:(void (^)(id path))handler {
    if (handler) {
        // Create a wrapper that can modify the path if needed
        void (^newHandler)(id path) = ^(id path) {
            // Original handler still needs to be called with the path
            // We're not modifying it here as the path itself is hooked separately
            handler(path);
        };
        %orig(newHandler);
    } else {
        %orig;
    }
}

- (id)currentPath {
    // The path object itself is hooked via the NWPath hook above
    return %orig;
}

%end

#pragma mark - Constructor

%ctor {
    @autoreleasepool {
        @try {
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            if (!bundleID) return;
            
            NSString *proc = [NSProcessInfo processInfo].processName;
            if ([bundleID hasPrefix:@"com.apple."] && !(PXSafariStackSpoofEnabled() && PXIsSafariStackProcess(bundleID, proc))) {
                return;
            }
            
            if (!PXIsWiFiSpoofingEnabled()) {
                return;
            }
            
            initializeHooks();
            %init;
        } @catch (NSException *e) {
            PXLog(@"[WeaponX] ❌ Error in WiFi constructor: %@", e);
        }
    }
}



// Load scoped apps from the plist file
static NSDictionary *loadScopedApps(void) {
    @try {
        // Check if cache is valid
        if (scopedAppsCache && scopedAppsCacheTimestamp && 
            [[NSDate date] timeIntervalSinceDate:scopedAppsCacheTimestamp] < kScopedAppsCacheValidDuration) {
            return scopedAppsCache;
        }
        
        // Initialize cache if needed
        if (!scopedAppsCache) {
            scopedAppsCache = [NSMutableDictionary dictionary];
        } else {
            [scopedAppsCache removeAllObjects];
        }
        
        // Try each possible path for the scoped apps file
        NSArray *possiblePaths = @[kScopedAppsPath, kScopedAppsPathAlt1, kScopedAppsPathAlt2];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *validPath = nil;
        
        for (NSString *path in possiblePaths) {
            if ([fileManager fileExistsAtPath:path]) {
                validPath = path;
                break;
            }
        }
        
        if (!validPath) {
            // Don't log this error too frequently to avoid spam
            static NSDate *lastErrorLog = nil;
            if (!lastErrorLog || [[NSDate date] timeIntervalSinceDate:lastErrorLog] > 300.0) { // 5 minutes
                PXLog(@"[WiFiHook] Could not find scoped apps file");
                lastErrorLog = [NSDate date];
            }
            scopedAppsCacheTimestamp = [NSDate date];
            return scopedAppsCache;
        }
        
        // Load the plist file safely
        NSDictionary *plistDict = [NSDictionary dictionaryWithContentsOfFile:validPath];
        if (!plistDict || ![plistDict isKindOfClass:[NSDictionary class]]) {
            scopedAppsCacheTimestamp = [NSDate date];
            return scopedAppsCache;
        }
        
        // Get the scoped apps dictionary
        NSDictionary *scopedApps = plistDict[@"ScopedApps"];
        if (!scopedApps || ![scopedApps isKindOfClass:[NSDictionary class]]) {
            scopedAppsCacheTimestamp = [NSDate date];
            return scopedAppsCache;
        }
        
        // Copy the scoped apps to our cache
        [scopedAppsCache addEntriesFromDictionary:scopedApps];
        scopedAppsCacheTimestamp = [NSDate date];
        
        return scopedAppsCache;
        
    } @catch (NSException *e) {
        scopedAppsCacheTimestamp = [NSDate date];
        return scopedAppsCache ?: [NSMutableDictionary dictionary];
    }
}

// Check if the current app is in the scoped apps list
static BOOL isInScopedAppsList(void) {
    @try {
        NSString *bundleID = getCurrentBundleID();
        if (!bundleID || [bundleID length] == 0) {
            return NO;
        }
        
        NSDictionary *scopedApps = loadScopedApps();
        if (!scopedApps || scopedApps.count == 0) {
            return NO;
        }
        
        // Check if this bundle ID is in the scoped apps dictionary
        id appEntry = scopedApps[bundleID];
        if (!appEntry || ![appEntry isKindOfClass:[NSDictionary class]]) {
            return NO;
        }
        
        // Check if the app is enabled
        BOOL isEnabled = [appEntry[@"enabled"] boolValue];
        return isEnabled;
        
    } @catch (NSException *e) {
        return NO;
    }
} 
