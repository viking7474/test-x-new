#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <NetworkExtension/NetworkExtension.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "TLinkIOSLogging.h"
#import "WiFiManager.h"
#import <substrate.h>
// #import <ellekit/ellekit.h> // Removed for rootful - using Substrate
#import <Network/Network.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <ifaddrs.h>
#import <net/if.h>
#import "MethodSwizzler.h"

#import "PXScope.h"
#import "PXPaths.h"
#import "PXNativeHookCoordinator.h"
#import <os/lock.h>



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

// Immutable WiFi info/profile/timestamp cache protected as one unit.
static os_unfair_lock gWiFiCacheLock = OS_UNFAIR_LOCK_INIT;
static NSDictionary *cachedWifiInfo = nil;
static NSString *cachedProfileId = nil;
static NSDate *cacheTimestamp = nil;
static NSTimeInterval kCacheValidityDuration = 300.0;

static NSDictionary *PXWiFiCachedInfo(NSString *profileId, NSDate *now) {
    os_unfair_lock_lock(&gWiFiCacheLock);
    BOOL valid = cachedWifiInfo && cachedProfileId && cacheTimestamp &&
        [cachedProfileId isEqualToString:profileId] &&
        [now timeIntervalSinceDate:cacheTimestamp] <= kCacheValidityDuration;
    NSDictionary *snapshot = valid ? cachedWifiInfo : nil;
    os_unfair_lock_unlock(&gWiFiCacheLock);
    return snapshot;
}

static NSDictionary *PXWiFiPublishInfo(NSDictionary *info, NSString *profileId, NSDate *now) {
    NSDictionary *immutable = [info isKindOfClass:[NSDictionary class]] ? [info copy] : nil;
    os_unfair_lock_lock(&gWiFiCacheLock);
    cachedWifiInfo = immutable;
    cachedProfileId = [profileId copy];
    cacheTimestamp = immutable ? now : nil;
    NSDictionary *published = cachedWifiInfo;
    os_unfair_lock_unlock(&gWiFiCacheLock);
    return published;
}

static void PXWiFiInvalidateCache(void) {
    os_unfair_lock_lock(&gWiFiCacheLock);
    cachedWifiInfo = nil;
    cachedProfileId = nil;
    cacheTimestamp = nil;
    os_unfair_lock_unlock(&gWiFiCacheLock);
}

// Forward declarations
static NSString *getCurrentBundleID(void);
static NSDictionary *loadScopedApps(void);
static BOOL isInScopedAppsList(void);

#pragma mark - Profile Detection Helpers

// Helper function to check if we should spoof for this bundle ID (with caching)
static BOOL shouldSpoofForBundle(NSString *bundleID) {
    if (!bundleID) return NO;
    NSString *proc = [NSProcessInfo processInfo].processName;
    return PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack);
}

// Helper function to directly get current profile ID from plist
static NSString *getCurrentProfileID(void) {
    return PXActiveProfileID();
}

// Get current WiFi info from appropriate profile
static NSDictionary *getProfileWiFiInfo(void) {
    NSString *profileId = getCurrentProfileID();
    NSString *identityDir = PXProfileIdentityPath(profileId);
    NSString *deviceIdsPath = PXProfileDeviceIDsPath(profileId);
    if (!profileId.length || !identityDir.length || !deviceIdsPath.length) return nil;

    NSDate *now = [NSDate date];
    NSDictionary *cached = PXWiFiCachedInfo(profileId, now);
    if (cached) return cached;

    NSString *wifiInfoPath = [identityDir stringByAppendingPathComponent:@"wifi_info.plist"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *resolved = nil;

    NSDictionary *wifiInfo = [NSDictionary dictionaryWithContentsOfFile:wifiInfoPath];
    if (wifiInfo[@"ssid"] && wifiInfo[@"bssid"]) {
        resolved = wifiInfo;
    }

    NSDictionary *deviceIds = nil;
    if (!resolved) {
        deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
        if (deviceIds[@"SSID"] && deviceIds[@"BSSID"]) {
            resolved = @{
                @"ssid": deviceIds[@"SSID"],
                @"bssid": deviceIds[@"BSSID"],
                @"networkType": @"Infrastructure"
            };
        } else {
            NSString *wifiValue = [deviceIds[@"WiFi"] isKindOfClass:[NSString class]] ? deviceIds[@"WiFi"] : nil;
            NSRange openParen = [wifiValue rangeOfString:@"("];
            NSRange closeParen = [wifiValue rangeOfString:@")" options:NSBackwardsSearch];
            if (wifiValue.length && openParen.location != NSNotFound && closeParen.location != NSNotFound &&
                closeParen.location > openParen.location + 1) {
                NSString *ssid = [[wifiValue substringToIndex:openParen.location]
                    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                NSString *bssid = [wifiValue substringWithRange:NSMakeRange(
                    openParen.location + 1,
                    closeParen.location - openParen.location - 1)];
                if (ssid.length && bssid.length) {
                    resolved = @{
                        @"ssid": ssid,
                        @"bssid": bssid,
                        @"networkType": @"Infrastructure"
                    };
                }
            }
        }
    }

    id wifiManager = NSClassFromString(@"WiFiManager")
        ? [NSClassFromString(@"WiFiManager") sharedManager]
        : nil;
    if (!resolved && [wifiManager respondsToSelector:@selector(currentWiFiInfo)]) {
        NSDictionary *managerInfo = [wifiManager currentWiFiInfo];
        if (managerInfo[@"ssid"] && managerInfo[@"bssid"]) resolved = managerInfo;
    }
    if (!resolved && [wifiManager respondsToSelector:@selector(generateWiFiInfo)]) {
        NSDictionary *generated = [wifiManager generateWiFiInfo];
        if (generated[@"ssid"] && generated[@"bssid"]) {
            resolved = generated;
            if ([fileManager fileExistsAtPath:identityDir] ||
                [fileManager createDirectoryAtPath:identityDir withIntermediateDirectories:YES attributes:nil error:nil]) {
                [generated writeToFile:wifiInfoPath atomically:YES];
                NSMutableDictionary *mutableIDs = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath];
                if (!mutableIDs) mutableIDs = [NSMutableDictionary dictionary];
                mutableIDs[@"SSID"] = generated[@"ssid"];
                mutableIDs[@"BSSID"] = generated[@"bssid"];
                mutableIDs[@"WiFi"] = [NSString stringWithFormat:@"%@ (%@)", generated[@"ssid"], generated[@"bssid"]];
                [mutableIDs writeToFile:deviceIdsPath atomically:YES];
            }
        }
    }

    return resolved ? PXWiFiPublishInfo(resolved, profileId, now) : nil;
}

#pragma mark - Core Hook Functions

// Build a CNCopy-compatible network info dictionary (public + private key variants).
// Always returns a new retained CFDictionary when ssid/bssid are non-empty.
static CFDictionaryRef PXCreateSpoofedNetworkInfoDict(NSString *ssid, NSString *bssid) {
    if (!ssid.length || !bssid.length) return NULL;
    NSMutableDictionary *spoofedInfo = [NSMutableDictionary dictionary];
    // Canonical CaptiveNetwork keys
    spoofedInfo[@"SSID"] = ssid;
    spoofedInfo[@"BSSID"] = bssid;
    // Some apps read lowercase / alternate keys
    spoofedInfo[@"ssid"] = ssid;
    spoofedInfo[@"bssid"] = bssid;
    spoofedInfo[@"NetworkType"] = @"Infrastructure";
    spoofedInfo[@"networkType"] = @"Infrastructure";
    // SSIDDATA (NSData) used by older / private readers
    NSData *ssidData = [ssid dataUsingEncoding:NSUTF8StringEncoding];
    if (ssidData) {
        spoofedInfo[@"SSIDDATA"] = ssidData;
        spoofedInfo[@"ssidData"] = ssidData;
    }
    return CFBridgingRetain(spoofedInfo);
}

static NSDictionary *PXResolvedWiFiInfo(void) {
    return getProfileWiFiInfo();
}

// Implementation of CNCopyCurrentNetworkInfo hook
// On iOS 13+ original often returns NULL without location entitlement — still spoof when scoped.
static CFDictionaryRef replaced_CNCopyCurrentNetworkInfo(CFStringRef interfaceName) {
    CFDictionaryRef originalDict = orig_CNCopyCurrentNetworkInfo ? orig_CNCopyCurrentNetworkInfo(interfaceName) : NULL;

    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (!shouldSpoofForBundle(bundleID)) {
            return originalDict;
        }

        NSDictionary *wifiInfo = PXResolvedWiFiInfo();
        if (wifiInfo) {
            CFDictionaryRef spoofed = PXCreateSpoofedNetworkInfoDict(wifiInfo[@"ssid"], wifiInfo[@"bssid"]);
            if (spoofed) {
                if (originalDict) CFRelease(originalDict);
                return spoofed;
            }
        }
    } @catch (__unused NSException *exception) {
    }

    return originalDict;
}

// Ensure apps that iterate interfaces still see a Wi-Fi interface (en0).
static CFArrayRef (*orig_CNCopySupportedInterfaces)(void) = NULL;
static CFArrayRef replaced_CNCopySupportedInterfaces(void) {
    CFArrayRef original = orig_CNCopySupportedInterfaces ? orig_CNCopySupportedInterfaces() : NULL;
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (!shouldSpoofForBundle(bundleID)) {
            return original;
        }
        // If system already reports interfaces, keep them (order preserved).
        if (original && CFArrayGetCount(original) > 0) {
            return original;
        }
        // Fabricate en0 so CNCopyCurrentNetworkInfo(en0) is queried.
        NSArray *ifaces = @[ @"en0" ];
        if (original) CFRelease(original);
        return CFBridgingRetain(ifaces);
    } @catch (__unused NSException *e) {
        return original;
    }
}

// Try to build a synthetic NEHotspotNetwork when public API returns nil
// (no location permission / not associated) so property swizzles still apply.
static id PXCreateSpoofedNEHotspotNetwork(NSString *ssid, NSString *bssid) {
    Class cls = NSClassFromString(@"NEHotspotNetwork");
    if (!cls || !ssid.length || !bssid.length) return nil;

    id net = nil;
    @try {
        net = [cls alloc];
        if ([net respondsToSelector:@selector(init)]) {
            net = [net init];
        }
    } @catch (__unused NSException *e) {
        net = nil;
    }
    if (!net) {
        @try { net = [[cls alloc] init]; } @catch (__unused NSException *e) { net = nil; }
    }
    if (!net) return nil;

    // Private ivar / property names vary by iOS version — try all common ones.
    NSArray<NSString *> *ssidKeys = @[ @"SSID", @"_SSID", @"ssid", @"_ssid" ];
    NSArray<NSString *> *bssidKeys = @[ @"BSSID", @"_BSSID", @"bssid", @"_bssid" ];
    for (NSString *k in ssidKeys) {
        @try { [net setValue:ssid forKey:k]; } @catch (__unused NSException *e) {}
    }
    for (NSString *k in bssidKeys) {
        @try { [net setValue:bssid forKey:k]; } @catch (__unused NSException *e) {}
    }
    return net;
}

// +[NEHotspotNetwork fetchCurrentWithCompletionHandler:] (iOS 14+) — primary path for many info apps.
static void (*orig_NEHotspotNetwork_fetchCurrent)(id, SEL, void (^)(id)) = NULL;
static void replaced_NEHotspotNetwork_fetchCurrent(id self, SEL _cmd, void (^completion)(id network)) {
    void (^deliver)(id) = ^(id network) {
        @try {
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            if (shouldSpoofForBundle(bundleID)) {
                // If system gave us a network object, SSID/BSSID swizzles cover property reads.
                // If nil (common without CoreLocation auth), synthesize one from profile.
                if (!network) {
                    NSDictionary *info = PXResolvedWiFiInfo();
                    if (info) {
                        network = PXCreateSpoofedNEHotspotNetwork(info[@"ssid"], info[@"bssid"]);
                    }
                }
            }
        } @catch (__unused NSException *e) {}
        if (completion) completion(network);
    };

    if (orig_NEHotspotNetwork_fetchCurrent) {
        orig_NEHotspotNetwork_fetchCurrent(self, _cmd, deliver);
    } else if (completion) {
        deliver(nil);
    }
}

// Implementation of NEHotspotHelper dictionaryWithScanResult: hook
static id replaced_dictionaryWithScanResult(id self, SEL _cmd, id arg1) {
    // Call original first
    id originalResult = nil;
    if (orig_dictionaryWithScanResult) {
        originalResult = orig_dictionaryWithScanResult(self, _cmd, arg1);
    }
    
    @try {
        // Get bundle ID for scope checking
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        // Check if we should spoof
        if (!shouldSpoofForBundle(bundleID)) {
            return originalResult;
        }
        
        // Ensure we have a valid dictionary to work with
        if (!originalResult || ![originalResult isKindOfClass:[NSDictionary class]]) {
            return originalResult;
        }
        
        // Create mutable copy for modification
        NSMutableDictionary *modifiedResult = [NSMutableDictionary dictionaryWithDictionary:originalResult];
        
        NSDictionary *wifiInfo = PXResolvedWiFiInfo();
        if (wifiInfo[@"ssid"] && wifiInfo[@"bssid"]) {
            modifiedResult[@"SSID"] = wifiInfo[@"ssid"];
            modifiedResult[@"BSSID"] = wifiInfo[@"bssid"];
            NSString *standard = [wifiInfo[@"wifiStandard"] isKindOfClass:[NSString class]]
                ? wifiInfo[@"wifiStandard"]
                : nil;
            if ([standard containsString:@"ax"]) {
                modifiedResult[@"WifiStandard"] = @6;
            } else if ([standard containsString:@"ac"]) {
                modifiedResult[@"WifiStandard"] = @5;
            } else if ([standard containsString:@"n"]) {
                modifiedResult[@"WifiStandard"] = @4;
            }
            return modifiedResult;
        }
    } @catch (NSException *exception) {
        // Silent exception handling
    }
    
    // Return original if spoofing failed
    return originalResult;
}

#pragma mark - Swizzle Implementations for NEHotspotNetwork

// Swizzle replacements for NEHotspotNetwork
@implementation NEHotspotNetwork (WeaponXHooks)

- (NSString *)weaponx_SSID {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return [self weaponx_SSID]; // original after exchange
    }
    NSDictionary *wifiInfo = PXResolvedWiFiInfo();
    if (wifiInfo[@"ssid"]) return wifiInfo[@"ssid"];
    return [self weaponx_SSID];
}

- (NSString *)weaponx_BSSID {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return [self weaponx_BSSID];
    }
    NSDictionary *wifiInfo = PXResolvedWiFiInfo();
    if (wifiInfo[@"bssid"]) return wifiInfo[@"bssid"];
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
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return orig_WiFiNetworkGetSSID ? orig_WiFiNetworkGetSSID(network) : NULL;
    }
    NSDictionary *wifiInfo = PXResolvedWiFiInfo();
    if (wifiInfo[@"ssid"]) {
        // Caller owns returned CFString (Create rule of MobileWiFi GetSSID varies;
        // CFStringCreateCopy is safe for both Get and Copy conventions when we spoof).
        return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)wifiInfo[@"ssid"]);
    }
    return orig_WiFiNetworkGetSSID ? orig_WiFiNetworkGetSSID(network) : NULL;
}

// Hook implementation for WiFiNetworkGetBSSID
static CFStringRef replaced_WiFiNetworkGetBSSID(WiFiNetworkRef network) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return orig_WiFiNetworkGetBSSID ? orig_WiFiNetworkGetBSSID(network) : NULL;
    }
    NSDictionary *wifiInfo = PXResolvedWiFiInfo();
    if (wifiInfo[@"bssid"]) {
        return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)wifiInfo[@"bssid"]);
    }
    return orig_WiFiNetworkGetBSSID ? orig_WiFiNetworkGetBSSID(network) : NULL;
}

#pragma mark - Hook Installation

// Apple80211GetInfoCopy — used by many device-info apps (AIDA-style private path).
typedef int (*Apple80211Open_t)(void **handle);
typedef int (*Apple80211Bind_t)(void *handle, const char *ifname);
typedef int (*Apple80211GetInfoCopy_t)(void *handle, CFDictionaryRef *info);
static Apple80211GetInfoCopy_t orig_Apple80211GetInfoCopy = NULL;

static int replaced_Apple80211GetInfoCopy(void *handle, CFDictionaryRef *info) {
    int r = orig_Apple80211GetInfoCopy ? orig_Apple80211GetInfoCopy(handle, info) : -1;
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (!shouldSpoofForBundle(bundleID)) return r;

        NSDictionary *wifiInfo = PXResolvedWiFiInfo();
        if (!wifiInfo) return r;

        NSString *ssid = wifiInfo[@"ssid"];
        NSString *bssid = wifiInfo[@"bssid"];
        if (!ssid.length || !bssid.length) return r;

        NSMutableDictionary *dict = nil;
        if (info && *info) {
            dict = [NSMutableDictionary dictionaryWithDictionary:(__bridge NSDictionary *)(*info)];
        } else {
            dict = [NSMutableDictionary dictionary];
        }
        // Common Apple80211 keys
        dict[@"SSID_STR"] = ssid;
        dict[@"SSID"] = ssid;
        dict[@"BSSID"] = bssid;
        NSData *ssidData = [ssid dataUsingEncoding:NSUTF8StringEncoding];
        if (ssidData) dict[@"SSID_DATA"] = ssidData;

        if (info) {
            if (*info) CFRelease(*info);
            *info = CFBridgingRetain(dict);
            return 0; // success even if original failed
        }
    } @catch (__unused NSException *e) {}
    return r;
}

static void initializeHooks(void) {
    // CNCopyCurrentNetworkInfo: register as sole dictionary builder on coordinator.
    PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
    [coord installOwnedSymbolsIfNeeded];
    orig_CNCopyCurrentNetworkInfo = [coord originalForSymbol:kPXNativeSymbolCNCopyCurrentNetworkInfo];
    static dispatch_once_t wifiCNOnce;
    dispatch_once(&wifiCNOnce, ^{
        [coord registerCNCopyCurrentNetworkInfoProvider:@"wifi.CNCopyCurrentNetworkInfo"
                                              priority:PXNativeHookPriorityNetworkStorage
                                                   pre:^BOOL(CFStringRef interfaceName, CFDictionaryRef *outResult) {
            // Always fully handle: replaced_* already falls through to original when not spoofing.
            CFDictionaryRef r = replaced_CNCopyCurrentNetworkInfo(interfaceName);
            if (outResult) *outResult = r;
            return YES;
        } post:nil];
    });

    // CNCopySupportedInterfaces — not coordinator-owned; install directly.
    void *cnSym = dlsym(RTLD_DEFAULT, "CNCopySupportedInterfaces");
    if (!cnSym) {
        void *sc = dlopen("/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration", RTLD_NOW);
        if (sc) cnSym = dlsym(sc, "CNCopySupportedInterfaces");
    }
    if (cnSym && dlsym(RTLD_DEFAULT, "MSHookFunction")) {
        MSHookFunction(cnSym, (void *)replaced_CNCopySupportedInterfaces, (void **)&orig_CNCopySupportedInterfaces);
        PXLog(@"[WiFiHook] Hooked CNCopySupportedInterfaces");
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
    
    // Install NEHotspotNetwork instance property swizzles + class fetchCurrent
    Class neHotspotNetworkClass = NSClassFromString(@"NEHotspotNetwork");
    if (neHotspotNetworkClass) {
        [MethodSwizzler swizzleClass:neHotspotNetworkClass 
                   originalSelector:@selector(SSID) 
                   swizzledSelector:@selector(weaponx_SSID)];
        
        [MethodSwizzler swizzleClass:neHotspotNetworkClass 
                   originalSelector:@selector(BSSID) 
                   swizzledSelector:@selector(weaponx_BSSID)];
        
        [MethodSwizzler swizzleClass:neHotspotNetworkClass 
                   originalSelector:@selector(signalStrength) 
                   swizzledSelector:@selector(weaponx_signalStrength)];
                   
        [MethodSwizzler swizzleClass:neHotspotNetworkClass 
                   originalSelector:@selector(secure) 
                   swizzledSelector:@selector(weaponx_secure)];

        // +fetchCurrentWithCompletionHandler: (iOS 14+) — CPUDasher / modern readers
        SEL fetchSel = NSSelectorFromString(@"fetchCurrentWithCompletionHandler:");
        Method fetchMethod = class_getClassMethod(neHotspotNetworkClass, fetchSel);
        if (fetchMethod && dlsym(RTLD_DEFAULT, "MSHookMessageEx")) {
            MSHookMessageEx(object_getClass((id)neHotspotNetworkClass),
                            fetchSel,
                            (IMP)replaced_NEHotspotNetwork_fetchCurrent,
                            (IMP *)&orig_NEHotspotNetwork_fetchCurrent);
            PXLog(@"[WiFiHook] Hooked +[NEHotspotNetwork fetchCurrentWithCompletionHandler:]");
        }
    }
    
    // Install MobileWiFi framework hooks
    void *mobileWiFiLib = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi", RTLD_NOW);
    if (mobileWiFiLib) {
        void *symbol = NULL;

        symbol = dlsym(mobileWiFiLib, "WiFiManagerClientCreate");
        if (symbol) {
            MSHookFunction(symbol,
                  (void *)replaced_WiFiManagerClientCreate,
                  (void **)&orig_WiFiManagerClientCreate);
        }

        symbol = dlsym(mobileWiFiLib, "WiFiDeviceClientCopyCurrentNetwork");
        if (symbol) {
            MSHookFunction(symbol,
                  (void *)replaced_WiFiDeviceClientCopyCurrentNetwork,
                  (void **)&orig_WiFiDeviceClientCopyCurrentNetwork);
        }

        symbol = dlsym(mobileWiFiLib, "WiFiNetworkGetSSID");
        if (symbol) {
            MSHookFunction(symbol,
                  (void *)replaced_WiFiNetworkGetSSID,
                  (void **)&orig_WiFiNetworkGetSSID);
        }

        symbol = dlsym(mobileWiFiLib, "WiFiNetworkGetBSSID");
        if (symbol) {
            MSHookFunction(symbol,
                  (void *)replaced_WiFiNetworkGetBSSID,
                  (void **)&orig_WiFiNetworkGetBSSID);
        }
        // Keep library open so symbols stay valid for the process lifetime.
    }

    // Apple80211GetInfoCopy — optional private path used by some device-info tools
    void *getInfo = dlsym(RTLD_DEFAULT, "Apple80211GetInfoCopy");
    if (!getInfo) {
        const char *candidates[] = {
            "/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi",
            "/System/Library/SystemConfiguration/IPConfiguration.bundle/IPConfiguration",
            "/usr/lib/libMobileGestalt.dylib",
            NULL
        };
        for (int i = 0; candidates[i]; i++) {
            void *h = dlopen(candidates[i], RTLD_NOW);
            if (!h) continue;
            getInfo = dlsym(h, "Apple80211GetInfoCopy");
            if (getInfo) break;
        }
        if (!getInfo) getInfo = dlsym(RTLD_DEFAULT, "Apple80211GetInfoCopy");
    }
    if (getInfo && dlsym(RTLD_DEFAULT, "MSHookFunction")) {
        MSHookFunction(getInfo, (void *)replaced_Apple80211GetInfoCopy, (void **)&orig_Apple80211GetInfoCopy);
        PXLog(@"[WiFiHook] Hooked Apple80211GetInfoCopy");
    } else {
        PXLog(@"[WiFiHook] Apple80211GetInfoCopy not found (optional)");
    }
}

#pragma mark - Notification Handlers

static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSString *notificationName = (__bridge NSString *)name;
    PXLog(@"[WeaponX] Received settings notification: %@", notificationName);
    
    PXWiFiInvalidateCache();
    PXInvalidateScopeDecisionCache();
}

#pragma mark - NWPathMonitor Hooks (Network Framework)

// Hook for NWPath methods
%hook NWPath

- (BOOL)usesInterfaceType:(NSInteger)type {
    // We don't modify this as it would break connectivity detection
    return %orig;
}

- (NSString *)_getSSID {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) return %orig;
    NSDictionary *wifiInfo = PXResolvedWiFiInfo();
    if (wifiInfo[@"ssid"]) return wifiInfo[@"ssid"];
    return %orig;
}

- (id)_getBSSID {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) return %orig;
    NSDictionary *wifiInfo = PXResolvedWiFiInfo();
    if (wifiInfo[@"bssid"]) return wifiInfo[@"bssid"];
    return %orig;
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
            PXLog(@"[WiFiHook] Initializing WiFi hooks");
            
            // Get the bundle ID for scope checking
            NSString *bundleID = getCurrentBundleID();
            
            // Skip if we can't get bundle ID
            if (!bundleID || [bundleID length] == 0) {
                return;
            }
            
            // Skip if this is a system process (except Safari/Auth stack when enabled)
            NSString *proc = [NSProcessInfo processInfo].processName;
            if (PXIsWebKitHelperProcess(bundleID, proc)) {
                PXLog(@"[WiFiHook] Not hooking WebKit helper: %@", bundleID);
                return;
            }
            if (!PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
                PXLog(@"[WiFiHook] Not hooking system process: %@", bundleID);
                return;
            }
            
            // Skip our own apps
            if ([bundleID isEqualToString:@"com.hydra.tlinkios"] || 
                [bundleID isEqualToString:@"com.hydra.weaponx"]) {
                PXLog(@"[WiFiHook] Not hooking own app: %@", bundleID);
                return;
            }
            
            PXLog(@"[WiFiHook] App %@ is scoped, setting up WiFi hooks", bundleID);
            
            // Initialize hooks
            initializeHooks();
            
            // Initialize Objective-C hooks for scoped apps only
            %init;
            
            // Register for settings change notifications
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                settingsChanged,
                CFSTR("com.hydra.tlinkios.settings.changed"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
            
            // Also register for WiFi-specific toggle notifications
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                settingsChanged,
                CFSTR("com.hydra.tlinkios.toggleWifiSpoof"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
            
            // Register for profile change notifications
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                settingsChanged,
                CFSTR("com.hydra.tlinkios.profileChanged"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                settingsChanged,
                CFSTR("com.hydra.tlinkios.scopedAppsChanged"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
            
            PXLog(@"[WiFiHook] WiFi hooks successfully initialized for scoped app: %@", bundleID);
            
        } @catch (NSException *e) {
            PXLog(@"[WiFiHook] ❌ Exception in constructor: %@", e);
        }
    }
}

#pragma mark - Scoped Apps Helper Functions

// Get the current bundle ID
static NSString *getCurrentBundleID(void) {
    @try {
        NSBundle *mainBundle = [NSBundle mainBundle];
        if (!mainBundle) {
            return nil;
        }
        return [mainBundle bundleIdentifier];
    } @catch (NSException *e) {
        return nil;
    }
}

// Load scoped apps from the plist file
static NSDictionary *loadScopedApps(void) {
    return PXScopedAppsSnapshot();
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
