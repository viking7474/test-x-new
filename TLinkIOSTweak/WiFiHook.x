#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <NetworkExtension/NetworkExtension.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "TLinkIOSLogging.h"
#import "WiFiManager.h"
#import "PXWiFiHookResolver.h"
#import <substrate.h>
// #import <ellekit/ellekit.h> // Removed for rootful - using Substrate
#import <Network/Network.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <ifaddrs.h>
#import <net/if.h>
#import "MethodSwizzler.h"

#import "PXScope.h"
#import "PXRuntimeSnapshot.h"
#import "PXPaths.h"
#import "PXNativeHookCoordinator.h"
#import <os/lock.h>
#include <math.h>
#include <time.h>



// Forward declarations for private API methods
@interface NWPath (WeaponXPrivate)
- (NSString *)_getSSID;
- (id)_getBSSID;
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
typedef struct __WiFiNetwork *WiFiNetworkRef;

// Function pointers for the original functions we'll hook
static CFDictionaryRef (*orig_CNCopyCurrentNetworkInfo)(CFStringRef interfaceName);
static id (*orig_dictionaryWithScanResult)(id self, SEL _cmd, id arg1);

// MobileWiFi.framework function pointers
static CFStringRef (*orig_WiFiNetworkGetSSID)(WiFiNetworkRef network);
static CFStringRef (*orig_WiFiNetworkGetBSSID)(WiFiNetworkRef network);

// Cache ownership and invalidation epoch are protected as one unit.
static os_unfair_lock gWiFiCacheLock = OS_UNFAIR_LOCK_INIT;
static NSDictionary *cachedWifiInfo = nil;
static NSString *cachedProfileId = nil;
static NSTimeInterval gWiFiCacheLoadedAt = 0;
static uint64_t gWiFiCacheGeneration = 0;
static const NSTimeInterval kCacheValidityDuration = 300.0;

static BOOL PXWiFiInfoHasIdentity(id info) {
    return [info isKindOfClass:NSDictionary.class] &&
        [info[@"ssid"] isKindOfClass:NSString.class] && [info[@"bssid"] isKindOfClass:NSString.class];
}

static NSTimeInterval PXWiFiCacheTime(void) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    return 0; // Captured views do not consult the live profile cache.
#else
    struct timespec instant = {0};
    if (clock_gettime(CLOCK_MONOTONIC, &instant) != 0) return NAN;
    return (NSTimeInterval)instant.tv_sec + (NSTimeInterval)instant.tv_nsec / 1e9;
#endif
}

static NSDictionary *PXWiFiCachedInfo(NSString *profileId, NSTimeInterval now, uint64_t *generation) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    (void)profileId; (void)now;
    if (generation) *generation = 0;
    return nil;
#else
    __attribute__((objc_precise_lifetime)) NSDictionary *discardedInfo = nil;
    __attribute__((objc_precise_lifetime)) NSString *discardedProfile = nil;
    NSDictionary *snapshot = nil;
    NSString *snapshotProfile = nil;
    os_unfair_lock_lock(&gWiFiCacheLock);
    if (generation) *generation = gWiFiCacheGeneration;
    if (cachedWifiInfo && cachedProfileId && isfinite(now) && now >= gWiFiCacheLoadedAt &&
        now - gWiFiCacheLoadedAt <= kCacheValidityDuration) {
        snapshot = cachedWifiInfo;
        snapshotProfile = cachedProfileId;
    } else {
        discardedInfo = cachedWifiInfo; discardedProfile = cachedProfileId;
        cachedWifiInfo = nil; cachedProfileId = nil; gWiFiCacheLoadedAt = 0;
    }
    os_unfair_lock_unlock(&gWiFiCacheLock);
    (void)discardedInfo; (void)discardedProfile;
    return [profileId isKindOfClass:NSString.class] && [snapshotProfile isEqualToString:profileId] ? snapshot : nil;
#endif
}

static NSDictionary *PXWiFiPublishInfo(NSDictionary *info, NSString *profileId, NSTimeInterval now, uint64_t generation) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    (void)profileId; (void)now; (void)generation;
    return info;
#else
    __attribute__((objc_precise_lifetime)) NSDictionary *immutable = nil;
    __attribute__((objc_precise_lifetime)) NSString *frozenProfile = nil;
    @try {
        if (!PXWiFiInfoHasIdentity(info) || ![profileId isKindOfClass:NSString.class] || !profileId.length) return nil;
        frozenProfile = [profileId copy];
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:info format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
        id detached = data ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL] : nil;
        if (PXWiFiInfoHasIdentity(detached)) immutable = detached;
    } @catch (NSException *exception) { (void)exception; }
    if (!immutable || !frozenProfile.length) return nil;
    NSTimeInterval observedNow = PXWiFiCacheTime();
    __attribute__((objc_precise_lifetime)) NSDictionary *discardedInfo = nil;
    __attribute__((objc_precise_lifetime)) NSString *discardedProfile = nil;
    NSDictionary *published = nil;
    NSString *publishedProfile = nil;
    os_unfair_lock_lock(&gWiFiCacheLock);
    if (generation == gWiFiCacheGeneration) {
        discardedInfo = cachedWifiInfo; discardedProfile = cachedProfileId;
        BOOL cacheable = isfinite(now) && now >= 0;
        cachedWifiInfo = cacheable ? immutable : nil;
        cachedProfileId = cacheable ? frozenProfile : nil;
        gWiFiCacheLoadedAt = cacheable ? now : 0;
        published = immutable;
        publishedProfile = frozenProfile;
    } else if (cachedWifiInfo && cachedProfileId && isfinite(observedNow) && observedNow >= gWiFiCacheLoadedAt &&
               observedNow - gWiFiCacheLoadedAt <= kCacheValidityDuration) {
        // An invalidated loader may reuse only a fresh winner for its own ID.
        published = cachedWifiInfo;
        publishedProfile = cachedProfileId;
    }
    os_unfair_lock_unlock(&gWiFiCacheLock);
    (void)discardedInfo; (void)discardedProfile; (void)immutable; (void)frozenProfile;
    return [publishedProfile isEqualToString:frozenProfile] ? published : nil;
#endif
}

static void PXWiFiInvalidateCache(void) {
    __attribute__((objc_precise_lifetime)) NSDictionary *discardedInfo = nil;
    __attribute__((objc_precise_lifetime)) NSString *discardedProfile = nil;
    os_unfair_lock_lock(&gWiFiCacheLock);
    discardedInfo = cachedWifiInfo; discardedProfile = cachedProfileId;
    cachedWifiInfo = nil; cachedProfileId = nil; gWiFiCacheLoadedAt = 0;
    gWiFiCacheGeneration++;
    os_unfair_lock_unlock(&gWiFiCacheLock);
    (void)discardedInfo; (void)discardedProfile;
}

// Forward declarations
static NSString *getCurrentBundleID(void);
static NSDictionary *loadScopedApps(void);
static BOOL isInScopedAppsList(void);

#pragma mark - Profile Detection Helpers

// Helper function to check if we should spoof for this bundle ID (with caching)
static BOOL shouldSpoofForBundle(NSString *bundleID) {
    PX_RUNTIME_READ_OPERATION;
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
    PX_RUNTIME_READ_OPERATION;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    static char wifiKey;
    PXRuntimeReadSnapshot *view = PXCaptureRuntimeSnapshot();
    id cachedView = objc_getAssociatedObject(view, &wifiKey);
    if (cachedView) return cachedView == NSNull.null ? nil : cachedView;
    NSDictionary *artifact = [view profileArtifact:@"wifiInfo"];
    NSDictionary *ids = view.deviceIDs;
    NSDictionary *resolved = nil;
    if ([artifact[@"ssid"] isKindOfClass:NSString.class] && [artifact[@"bssid"] isKindOfClass:NSString.class]) {
        resolved = artifact;
    } else if ([ids[@"SSID"] isKindOfClass:NSString.class] && [ids[@"BSSID"] isKindOfClass:NSString.class]) {
        resolved = @{ @"ssid": ids[@"SSID"], @"bssid": ids[@"BSSID"], @"networkType": @"Infrastructure" };
    } else {
        NSString *value = [ids[@"WiFi"] isKindOfClass:NSString.class] ? ids[@"WiFi"] : nil;
        NSRange open = value.length ? [value rangeOfString:@"("] : NSMakeRange(NSNotFound, 0);
        NSRange close = value.length ? [value rangeOfString:@")" options:NSBackwardsSearch] : NSMakeRange(NSNotFound, 0);
        if (value.length && open.location != NSNotFound && close.location != NSNotFound && close.location > open.location + 1) {
            NSString *ssid = [[value substringToIndex:open.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            NSString *bssid = [value substringWithRange:NSMakeRange(open.location + 1, close.location - open.location - 1)];
            if (ssid.length && bssid.length) resolved = @{ @"ssid": ssid, @"bssid": bssid, @"networkType": @"Infrastructure" };
        }
    }
    if (view) objc_setAssociatedObject(view, &wifiKey, resolved ?: NSNull.null, OBJC_ASSOCIATION_RETAIN);
    return resolved;
#else
    NSString *profileId = getCurrentProfileID();
    NSString *identityDir = PXProfileIdentityPath(profileId);
    NSString *deviceIdsPath = PXProfileDeviceIDsPath(profileId);
    if (!profileId.length || !identityDir.length || !deviceIdsPath.length) return nil;

    uint64_t generation = 0;
    NSTimeInterval now = PXWiFiCacheTime();
    NSDictionary *cached = PXWiFiCachedInfo(profileId, now, &generation);
    if (cached) return cached;

    NSString *wifiInfoPath = [identityDir stringByAppendingPathComponent:@"wifi_info.plist"];
    NSDictionary *resolved = nil;

    NSDictionary *wifiInfo = [NSDictionary dictionaryWithContentsOfFile:wifiInfoPath];
    if (PXWiFiInfoHasIdentity(wifiInfo)) {
        resolved = wifiInfo;
    }

    NSDictionary *deviceIds = nil;
    if (!resolved) {
        deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
        if ([deviceIds[@"SSID"] isKindOfClass:NSString.class] && [deviceIds[@"BSSID"] isKindOfClass:NSString.class]) {
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

    Class managerClass = resolved ? Nil : NSClassFromString(@"WiFiManager");
    if (!resolved && [managerClass respondsToSelector:@selector(sharedManager)]) {
        resolved = PXResolveHookWiFiInfo(profileId, ^NSDictionary *(NSString *target, NSError **failure) {
            id manager = [managerClass sharedManager];
            if (![manager respondsToSelector:@selector(cachedWiFiInfoForProfileID:)]) {
                if (failure) *failure = [NSError errorWithDomain:@"com.hydra.tlinkios.wifi-hook" code:3024
                    userInfo:@{NSLocalizedDescriptionKey: @"WiFi cache provider is unavailable"}];
                return nil;
            }
            return [manager cachedWiFiInfoForProfileID:target];
        }, NULL);
    }

    return resolved ? PXWiFiPublishInfo(resolved, profileId, now, generation) : nil;
#endif
}

#pragma mark - Core Hook Functions

// Build a CNCopy-compatible network info dictionary (public + private key variants).
// Always returns a new retained CFDictionary when ssid/bssid are non-empty.
static CFDictionaryRef PXCreateSpoofedNetworkInfoDict(NSString *ssid, NSString *bssid) {
    if (![ssid isKindOfClass:NSString.class] || ![bssid isKindOfClass:NSString.class] || !ssid.length || !bssid.length) return NULL;
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

// Both inputs follow Copy ownership. Preparation has finished before this
// point, so a release exception must never fall back to an already released
// original. The unreturned replacement is still ours on that exceptional exit.
static CFTypeRef PXWiFiReplaceOwnedCopy(CFTypeRef original, CFTypeRef replacement) {
    if (!replacement) return original;
    @try { if (original) CFRelease(original); }
    @catch (NSException *exception) { (void)exception; CFRelease(replacement); @throw; }
    return replacement;
}

static NSDictionary *PXResolvedWiFiInfo(void) {
    PX_RUNTIME_READ_OPERATION;
    return getProfileWiFiInfo();
}

// Implementation of CNCopyCurrentNetworkInfo hook
// On iOS 13+ original often returns NULL without location entitlement — still spoof when scoped.
static CFDictionaryRef replaced_CNCopyCurrentNetworkInfo(CFStringRef interfaceName) {
    PX_RUNTIME_READ_OPERATION;
    CFDictionaryRef original = orig_CNCopyCurrentNetworkInfo ? orig_CNCopyCurrentNetworkInfo(interfaceName) : NULL;
    CFDictionaryRef replacement = NULL;
    @try {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        if (!shouldSpoofForBundle(bundleID)) return original;
        NSDictionary *wifiInfo = PXResolvedWiFiInfo();
        if (PXWiFiInfoHasIdentity(wifiInfo))
            replacement = PXCreateSpoofedNetworkInfoDict(wifiInfo[@"ssid"], wifiInfo[@"bssid"]);
    } @catch (NSException *exception) { (void)exception; return original; }
    return (CFDictionaryRef)PXWiFiReplaceOwnedCopy(original, replacement);
}

// Ensure apps that iterate interfaces still see a Wi-Fi interface (en0).
static CFArrayRef (*orig_CNCopySupportedInterfaces)(void) = NULL;
static CFArrayRef replaced_CNCopySupportedInterfaces(void) {
    PX_RUNTIME_READ_OPERATION;
    CFArrayRef original = orig_CNCopySupportedInterfaces ? orig_CNCopySupportedInterfaces() : NULL;
    // Keep the lexical view around the original and any nested hooks. Nonempty
    // results need no extra bundle/scope checks; unexpected CF types pass through.
    @try {
        if (original && (CFGetTypeID(original) != CFArrayGetTypeID() || CFArrayGetCount(original) > 0)) return original;
    } @catch (NSException *exception) { (void)exception; return original; }
    CFArrayRef replacement = NULL;
    @try {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        if (!shouldSpoofForBundle(bundleID)) return original;
        replacement = (CFArrayRef)CFBridgingRetain(@[@"en0"]);
    } @catch (NSException *exception) { (void)exception; return original; }
    return (CFArrayRef)PXWiFiReplaceOwnedCopy(original, replacement);
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
    PX_RUNTIME_READ_OPERATION;
    void (^deliver)(id) = ^(id network) {
    PX_RUNTIME_READ_OPERATION;
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
    PX_RUNTIME_READ_OPERATION;
    id original = orig_dictionaryWithScanResult ? orig_dictionaryWithScanResult(self, _cmd, arg1) : nil;
    @try {
        if (!shouldSpoofForBundle(NSBundle.mainBundle.bundleIdentifier) || ![original isKindOfClass:NSDictionary.class]) return original;
        NSDictionary *wifi = PXResolvedWiFiInfo();
        if (!PXWiFiInfoHasIdentity(wifi)) return original;
        NSString *standard = [wifi[@"wifiStandard"] isKindOfClass:NSString.class] ? wifi[@"wifiStandard"] : nil;
        NSNumber *kind = [standard containsString:@"ax"] ? @6 : ([standard containsString:@"ac"] ? @5 : ([standard containsString:@"n"] ? @4 : nil));
        if ([original[@"SSID"] isEqual:wifi[@"ssid"]] && [original[@"BSSID"] isEqual:wifi[@"bssid"]] &&
            (!kind || [original[@"WifiStandard"] isEqual:kind])) return original;
        NSMutableDictionary *modified = [original mutableCopy];
        modified[@"SSID"] = wifi[@"ssid"]; modified[@"BSSID"] = wifi[@"bssid"];
        if (kind) modified[@"WifiStandard"] = kind;
        return modified;
    } @catch (NSException *exception) { (void)exception; return original; }
}

#pragma mark - Swizzle Implementations for NEHotspotNetwork

// Swizzle replacements for NEHotspotNetwork
@implementation NEHotspotNetwork (WeaponXHooks)

- (NSString *)weaponx_SSID {
    PX_RUNTIME_READ_OPERATION;
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return [self weaponx_SSID]; // original after exchange
    }
    NSDictionary *wifiInfo = PXResolvedWiFiInfo();
    if (wifiInfo[@"ssid"]) return wifiInfo[@"ssid"];
    return [self weaponx_SSID];
}

- (NSString *)weaponx_BSSID {
    PX_RUNTIME_READ_OPERATION;
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return [self weaponx_BSSID];
    }
    NSDictionary *wifiInfo = PXResolvedWiFiInfo();
    if (wifiInfo[@"bssid"]) return wifiInfo[@"bssid"];
    return [self weaponx_BSSID];
}

// Additional NEHotspotNetwork property hook for signal strength
- (double)weaponx_signalStrength {
    PX_RUNTIME_READ_OPERATION;
    // Check if we should spoof
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return [self weaponx_signalStrength]; // Call original
    }
    
    // Return a realistic signal strength (0.7-0.9 range for good strength)
    // NEHotspotNetwork.signalStrength is a double in [0.0, 1.0]; return the
    // raw double to match the real ABI (never a boxed NSNumber).
    double strength = 0.7 + ((double)arc4random_uniform(20) / 100.0);
    return strength;
}

// Additional NEHotspotNetwork property hook for secure flag
- (BOOL)weaponx_secure {
    PX_RUNTIME_READ_OPERATION;
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



// Hook implementation for WiFiNetworkGetSSID
static CFStringRef replaced_WiFiNetworkGetSSID(WiFiNetworkRef network) {
    PX_RUNTIME_READ_OPERATION;
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return orig_WiFiNetworkGetSSID ? orig_WiFiNetworkGetSSID(network) : NULL;
    }
    NSDictionary *wifiInfo = PXResolvedWiFiInfo();
    if (wifiInfo[@"ssid"]) {
        // Preserve this tweak's retained-spoof convention pending private API
        // ownership/lifetime verification. A +1 copy does not satisfy both Get
        // and Copy contracts; do not infer caller ownership from this code.
        return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)wifiInfo[@"ssid"]);
    }
    return orig_WiFiNetworkGetSSID ? orig_WiFiNetworkGetSSID(network) : NULL;
}

// Hook implementation for WiFiNetworkGetBSSID
static CFStringRef replaced_WiFiNetworkGetBSSID(WiFiNetworkRef network) {
    PX_RUNTIME_READ_OPERATION;
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
typedef int (*Apple80211GetInfoCopy_t)(void *handle, CFDictionaryRef *info);
static Apple80211GetInfoCopy_t orig_Apple80211GetInfoCopy = NULL;

static int replaced_Apple80211GetInfoCopy(void *handle, CFDictionaryRef *info) {
    if (!info) return orig_Apple80211GetInfoCopy ? orig_Apple80211GetInfoCopy(handle, info) : -1;
    PX_RUNTIME_READ_OPERATION;
    BOOL admitted = NO;
    @try { admitted = shouldSpoofForBundle(NSBundle.mainBundle.bundleIdentifier); }
    @catch (NSException *exception) { (void)exception; }
    // Denied calls keep the original pointer, status and untouched-on-error
    // behavior. The scoped adapter treats this Copy API's slot as output-only.
    if (!admitted) return orig_Apple80211GetInfoCopy ? orig_Apple80211GetInfoCopy(handle, info) : -1;
    *info = NULL;
    int result = orig_Apple80211GetInfoCopy ? orig_Apple80211GetInfoCopy(handle, info) : -1;
    CFDictionaryRef original = *info;
    CFDictionaryRef replacement = NULL;
    @try {
        if (original && CFGetTypeID(original) != CFDictionaryGetTypeID()) return result;
        NSDictionary *wifiInfo = PXResolvedWiFiInfo();
        if (!PXWiFiInfoHasIdentity(wifiInfo)) return result;
        NSString *ssid = wifiInfo[@"ssid"], *bssid = wifiInfo[@"bssid"];
        if (!ssid.length || !bssid.length) return result;
        NSMutableDictionary *dict = original ? [(__bridge NSDictionary *)original mutableCopy] : [NSMutableDictionary dictionary];
        dict[@"SSID_STR"] = ssid; dict[@"SSID"] = ssid; dict[@"BSSID"] = bssid;
        NSData *ssidData = [ssid dataUsingEncoding:NSUTF8StringEncoding];
        if (ssidData) dict[@"SSID_DATA"] = ssidData;
        replacement = (CFDictionaryRef)CFBridgingRetain(dict);
    } @catch (NSException *exception) { (void)exception; return result; }
    if (!replacement) return result;
    // Publish before releasing: a destructor/reentrant observer must see the
    // new owned output, never the old pointer while it is being destroyed.
    *info = replacement;
    if (original) CFRelease(original);
    return 0; // Preserve scoped synthesis even when the original returned failure.
}

static void initializeHooks(void) {
    PX_RUNTIME_READ_OPERATION;
    // CNCopyCurrentNetworkInfo: register as sole dictionary builder on coordinator.
    PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
    [coord installOwnedSymbolsIfNeeded];
    orig_CNCopyCurrentNetworkInfo = [coord originalForSymbol:kPXNativeSymbolCNCopyCurrentNetworkInfo];
    static dispatch_once_t wifiCNOnce;
    dispatch_once(&wifiCNOnce, ^{
    PX_RUNTIME_READ_OPERATION;
        [coord registerCNCopyCurrentNetworkInfoProvider:@"wifi.CNCopyCurrentNetworkInfo"
                                              priority:PXNativeHookPriorityNetworkStorage
                                                   pre:^BOOL(CFStringRef interfaceName, CFDictionaryRef *outResult) {
    PX_RUNTIME_READ_OPERATION;
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
        if (PXMethodHasCompatibleTypeEncoding(dictionaryMethod, "@@:@") && dlsym(RTLD_DEFAULT, "MSHookMessageEx")) {
            MSHookMessageEx(object_getClass((id)neHotspotHelperClass), @selector(dictionaryWithScanResult:),
                (IMP)replaced_dictionaryWithScanResult, (IMP *)&orig_dictionaryWithScanResult);
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
                   originalSelector:@selector(isSecure) 
                   swizzledSelector:@selector(weaponx_secure)];

        // +fetchCurrentWithCompletionHandler: (iOS 14+) — CPUDasher / modern readers
        SEL fetchSel = NSSelectorFromString(@"fetchCurrentWithCompletionHandler:");
        Method fetchMethod = class_getClassMethod(neHotspotNetworkClass, fetchSel);
        if (PXMethodHasCompatibleTypeEncoding(fetchMethod, "v@:@?") && dlsym(RTLD_DEFAULT, "MSHookMessageEx")) {
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

// Optional private getters: only install when the runtime object ABI matches.
%group PXWiFiNWPathSSID
%hook NWPath
- (NSString *)_getSSID {
    PX_RUNTIME_READ_OPERATION;
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) return %orig;
    NSDictionary *wifiInfo = PXResolvedWiFiInfo();
    if (wifiInfo[@"ssid"]) return wifiInfo[@"ssid"];
    return %orig;
}
%end
%end

%group PXWiFiNWPathBSSID
%hook NWPath
- (id)_getBSSID {
    PX_RUNTIME_READ_OPERATION;
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) return %orig;
    NSDictionary *wifiInfo = PXResolvedWiFiInfo();
    if (wifiInfo[@"bssid"]) return wifiInfo[@"bssid"];
    return %orig;
}
%end
%end

#pragma mark - Constructor

%ctor {
    @autoreleasepool {
        if (!PXBootstrapAllows(PXHookCapabilityNative)) return;
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
            
            // Admit the private getters independently; absent/incompatible
            // selectors must never acquire a null or ABI-mismatched %orig.
            Class pathClass = NSClassFromString(@"NWPath");
            if (pathClass && PXMethodHasCompatibleTypeEncoding(class_getInstanceMethod(pathClass, @selector(_getSSID)), "@@:")) {
                %init(PXWiFiNWPathSSID);
            }
            if (pathClass && PXMethodHasCompatibleTypeEncoding(class_getInstanceMethod(pathClass, @selector(_getBSSID)), "@@:")) {
                %init(PXWiFiNWPathBSSID);
            }
            
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
    PX_RUNTIME_READ_OPERATION;
    return PXScopedAppsSnapshot();
}

// Check if the current app is in the scoped apps list
static BOOL isInScopedAppsList(void) {
    PX_RUNTIME_READ_OPERATION;
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
