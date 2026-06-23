#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <NetworkExtension/NetworkExtension.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "ProjectXLogging.h"
#import "WiFiManager.h"
#import <substrate.h>
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
@end

@interface NEHotspotNetwork (WeaponXPrivate)
- (NSString *)SSID;
- (NSString *)BSSID;
- (double)signalStrength;
- (BOOL)secure;
@end

// MobileWiFi.framework function pointers
typedef struct __WiFiDeviceClient *WiFiDeviceClientRef;
typedef struct __WiFiNetwork *WiFiNetworkRef;
typedef struct __WiFiManager *WiFiManagerRef;

static CFDictionaryRef (*orig_CNCopyCurrentNetworkInfo)(CFStringRef interfaceName);
static id (*orig_dictionaryWithScanResult)(id self, SEL _cmd, id arg1);
static WiFiManagerRef (*orig_WiFiManagerClientCreate)(CFAllocatorRef allocator, int flags);
static WiFiNetworkRef (*orig_WiFiDeviceClientCopyCurrentNetwork)(WiFiDeviceClientRef client);
static CFStringRef (*orig_WiFiNetworkGetSSID)(WiFiNetworkRef network);
static CFStringRef (*orig_WiFiNetworkGetBSSID)(WiFiNetworkRef network);

#pragma mark - Profile Detection Helpers

static BOOL shouldSpoofForBundle(NSString *bundleID) {
    if (!bundleID) return NO;
    NSString *proc = [NSProcessInfo processInfo].processName;
    if (PXAllowUnscopedSafariStack() || (PXSafariStackSpoofEnabled() && PXIsSafariStackProcess(bundleID, proc))) {
        return YES;
    }
    return PXIsWiFiSpoofingEnabled();
}

#pragma mark - Core Hook Functions

static CFDictionaryRef replaced_CNCopyCurrentNetworkInfo(CFStringRef interfaceName) {
    id originalResult = nil;
    if (orig_CNCopyCurrentNetworkInfo) {
        originalResult = (__bridge id)orig_CNCopyCurrentNetworkInfo(interfaceName);
    }
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return (__bridge_retained CFDictionaryRef)originalResult;
    }
    
    NSMutableDictionary *spoofedInfo = [NSMutableDictionary dictionary];
    if (originalResult && [originalResult isKindOfClass:[NSDictionary class]]) {
        [spoofedInfo addEntriesFromDictionary:originalResult];
    }
    
    spoofedInfo[@"SSID"] = PXGetSpoofedWiFiSSID();
    spoofedInfo[@"BSSID"] = PXGetSpoofedWiFiBSSID();
    spoofedInfo[@"SSIDDATA"] = [spoofedInfo[@"SSID"] dataUsingEncoding:NSUTF8StringEncoding];
    
    return (__bridge_retained CFDictionaryRef)spoofedInfo;
}

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

%hook NEHotspotNetwork

- (NSString *)SSID {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return %orig;
    }
    return PXGetSpoofedWiFiSSID();
}

- (NSString *)BSSID {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return %orig;
    }
    return PXGetSpoofedWiFiBSSID();
}

- (double)signalStrength {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return %orig;
    }
    return 0.7 + ((double)arc4random_uniform(20) / 100.0);
}

- (BOOL)secure {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return %orig;
    }
    return YES;
}

%end

#pragma mark - MobileWiFi Framework Hooks

static WiFiManagerRef replaced_WiFiManagerClientCreate(CFAllocatorRef allocator, int flags) {
    return orig_WiFiManagerClientCreate(allocator, flags);
}

static WiFiNetworkRef replaced_WiFiDeviceClientCopyCurrentNetwork(WiFiDeviceClientRef client) {
    return orig_WiFiDeviceClientCopyCurrentNetwork(client);
}

static CFStringRef replaced_WiFiNetworkGetSSID(WiFiNetworkRef network) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return orig_WiFiNetworkGetSSID(network);
    }
    return (__bridge CFStringRef)PXGetSpoofedWiFiSSID();
}

static CFStringRef replaced_WiFiNetworkGetBSSID(WiFiNetworkRef network) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return orig_WiFiNetworkGetBSSID(network);
    }
    return (__bridge CFStringRef)PXGetSpoofedWiFiBSSID();
}

#pragma mark - Hook Installation

static void initializeHooks(void) {
    void *symbol = dlsym(RTLD_DEFAULT, "CNCopyCurrentNetworkInfo");
    if (symbol) {
        MSHookFunction(symbol, (void *)replaced_CNCopyCurrentNetworkInfo, (void **)&orig_CNCopyCurrentNetworkInfo);
    } else {
        void *captiveNetworkLib = dlopen("/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration", RTLD_NOW);
        if (captiveNetworkLib) {
            symbol = dlsym(captiveNetworkLib, "CNCopyCurrentNetworkInfo");
            if (symbol) {
                MSHookFunction(symbol, (void *)replaced_CNCopyCurrentNetworkInfo, (void **)&orig_CNCopyCurrentNetworkInfo);
            }
            dlclose(captiveNetworkLib);
        }
    }
    
    Class neHotspotHelperClass = NSClassFromString(@"NEHotspotHelper");
    if (neHotspotHelperClass) {
        Method dictionaryMethod = class_getClassMethod(neHotspotHelperClass, @selector(dictionaryWithScanResult:));
        if (dictionaryMethod) {
            orig_dictionaryWithScanResult = (id (*)(id, SEL, id))method_getImplementation(dictionaryMethod);
            method_setImplementation(dictionaryMethod, (IMP)replaced_dictionaryWithScanResult);
        }
    }
    
    void *mobileWiFiLib = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi", RTLD_NOW);
    if (mobileWiFiLib) {
        symbol = dlsym(mobileWiFiLib, "WiFiManagerClientCreate");
        if (symbol) MSHookFunction(symbol, (void *)replaced_WiFiManagerClientCreate, (void **)&orig_WiFiManagerClientCreate);
        
        symbol = dlsym(mobileWiFiLib, "WiFiDeviceClientCopyCurrentNetwork");
        if (symbol) MSHookFunction(symbol, (void *)replaced_WiFiDeviceClientCopyCurrentNetwork, (void **)&orig_WiFiDeviceClientCopyCurrentNetwork);
        
        symbol = dlsym(mobileWiFiLib, "WiFiNetworkGetSSID");
        if (symbol) MSHookFunction(symbol, (void *)replaced_WiFiNetworkGetSSID, (void **)&orig_WiFiNetworkGetSSID);
        
        symbol = dlsym(mobileWiFiLib, "WiFiNetworkGetBSSID");
        if (symbol) MSHookFunction(symbol, (void *)replaced_WiFiNetworkGetBSSID, (void **)&orig_WiFiNetworkGetBSSID);
        
        dlclose(mobileWiFiLib);
    }
}

#pragma mark - NWPathMonitor Hooks (Network Framework)

%hook NWPath

- (BOOL)usesInterfaceType:(NSInteger)type {
    return %orig;
}

- (NSString *)_getSSID {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return %orig;
    }
    return PXGetSpoofedWiFiSSID();
}

- (id)_getBSSID {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!shouldSpoofForBundle(bundleID)) {
        return %orig;
    }
    return PXGetSpoofedWiFiBSSID();
}

- (NSInteger)quality { return %orig; }
- (double)latency { return %orig; }
- (BOOL)isExpensive { return %orig; }
- (BOOL)isConstrained { return %orig; }
- (id)gatherDiagnostics { return %orig; }

%end

%hook NWPathMonitor
- (void)setPathUpdateHandler:(void (^)(id path))handler {
    if (handler) {
        void (^newHandler)(id path) = ^(id path) {
            handler(path);
        };
        %orig(newHandler);
    } else {
        %orig;
    }
}
- (id)currentPath { return %orig; }
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
