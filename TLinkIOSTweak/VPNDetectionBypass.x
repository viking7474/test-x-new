#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <Network/Network.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <string.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <substrate.h>

#import "TLinkIOSLogging.h"
#import "PXScope.h"
#import "PXNativeHookCoordinator.h"
#import "PXPACProxySanitizer.h"

static NSString *const kPXVPNSecuritySettingsPath = @"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist";

static BOOL PXVPNBypassActive(void) {
    @try {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        NSString *processName = NSProcessInfo.processInfo.processName;
        if (!PXProcessIsAllowedForSpoofing(bundleID, processName, PXScopeOptionAllowSafariAuthStack)) return NO;
        NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:kPXVPNSecuritySettingsPath];
        return [settings[@"vpnDetectionBypassEnabled"] boolValue];
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static BOOL PXVPNInterfaceNameIsSensitive(const char *name) {
    if (!name || !name[0]) return NO;
    static const char *prefixes[] = { "utun", "ipsec", "ppp", "tun", "tap", NULL };
    for (NSUInteger i = 0; prefixes[i]; i++) {
        size_t length = strlen(prefixes[i]);
        if (strncmp(name, prefixes[i], length) == 0) return YES;
    }
    return NO;
}

static void PXVPNPostGetifaddrs(struct ifaddrs **ifap, int *inoutResult) {
    if (!PXVPNBypassActive() || !inoutResult || *inoutResult != 0 || !ifap || !*ifap) return;
    for (struct ifaddrs *entry = *ifap; entry; entry = entry->ifa_next) {
        if (!PXVPNInterfaceNameIsSensitive(entry->ifa_name)) continue;
        // Preserve the allocation graph expected by freeifaddrs. Every sensitive
        // prefix above is at least as long as "en0", so this bounded replacement
        // cannot overrun the existing name storage.
        memcpy(entry->ifa_name, "en0", 4);
        entry->ifa_flags &= ~IFF_POINTOPOINT;
    }
}

static CFMutableDictionaryRef PXVPNCreateSanitizedProxyDictionary(CFDictionaryRef original) {
    if (!original || CFGetTypeID(original) != CFDictionaryGetTypeID()) return NULL;
    CFMutableDictionaryRef result = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, original);
    if (!result) return NULL;
    static const CFStringRef keys[] = {
        CFSTR("HTTPEnable"), CFSTR("HTTPProxy"), CFSTR("HTTPPort"),
        CFSTR("HTTPSEnable"), CFSTR("HTTPSProxy"), CFSTR("HTTPSPort"),
        CFSTR("SOCKSEnable"), CFSTR("SOCKSProxy"), CFSTR("SOCKSPort"),
        CFSTR("ProxyAutoConfigEnable"), CFSTR("ProxyAutoConfigURLString"),
        CFSTR("ProxyAutoDiscoveryEnable"), CFSTR("__SCOPED__"),
        CFSTR("__PROXY_SCOPE__"), NULL
    };
    for (NSUInteger i = 0; keys[i]; i++) CFDictionaryRemoveValue(result, keys[i]);
    return result;
}

static CFDictionaryRef (*PXOrigCFNetworkCopySystemProxySettings)(void) = NULL;
static CFDictionaryRef PXHookCFNetworkCopySystemProxySettings(void) {
    CFDictionaryRef original = PXOrigCFNetworkCopySystemProxySettings ? PXOrigCFNetworkCopySystemProxySettings() : NULL;
    if (!PXVPNBypassActive() || !original) return original;
    CFMutableDictionaryRef sanitized = PXVPNCreateSanitizedProxyDictionary(original);
    if (!sanitized) return original;
    CFRelease(original);
    return sanitized;
}

static CFDictionaryRef (*PXOrigSCDynamicStoreCopyProxies)(SCDynamicStoreRef) = NULL;
static CFDictionaryRef PXHookSCDynamicStoreCopyProxies(SCDynamicStoreRef store) {
    CFDictionaryRef original = PXOrigSCDynamicStoreCopyProxies ? PXOrigSCDynamicStoreCopyProxies(store) : NULL;
    if (!PXVPNBypassActive() || !original) return original;
    CFMutableDictionaryRef sanitized = PXVPNCreateSanitizedProxyDictionary(original);
    if (!sanitized) return original;
    CFRelease(original);
    return sanitized;
}

typedef CFArrayRef (*PXCFNetworkCopyPACProxiesFunction)(CFStringRef, CFURLRef, CFErrorRef *);
static PXCFNetworkCopyPACProxiesFunction PXOrigCFNetworkCopyProxiesForAutoConfigurationScript = NULL;
static __thread BOOL gPXInsidePACProxyHook = NO;

static CFArrayRef PXHookCFNetworkCopyProxiesForAutoConfigurationScript(CFStringRef script,
                                                                       CFURLRef targetURL,
                                                                       CFErrorRef *error) {
    PXCFNetworkCopyPACProxiesFunction originalFunction = PXOrigCFNetworkCopyProxiesForAutoConfigurationScript;
    if (!originalFunction) return NULL;
    if (gPXInsidePACProxyHook) return originalFunction(script, targetURL, error);

    gPXInsidePACProxyHook = YES;
    CFArrayRef original = originalFunction(script, targetURL, error);
    gPXInsidePACProxyHook = NO;

    if (!PXVPNBypassActive() || !original) return original;
    if (error && *error) return original;
    if (CFGetTypeID(original) != CFArrayGetTypeID()) return original;

    id originalObject = (__bridge id)original;
    id projected = nil;
    @try {
        projected = PXPACProjectedProxyValue(originalObject, YES);
    } @catch (__unused NSException *exception) {
        return original;
    }
    if (projected == originalObject || ![projected isKindOfClass:[NSArray class]]) return original;

    CFArrayRef replacement = (CFArrayRef)CFBridgingRetain(projected);
    if (!replacement) return original;
    CFRelease(original);
    return replacement;
}

%group PXVPNObjectiveCHooks

%hook NSURLSessionConfiguration
- (NSDictionary *)connectionProxyDictionary {
    if (PXVPNBypassActive()) return @{};
    return %orig;
}
%end

%hook NWPath
- (BOOL)usesInterfaceType:(NSInteger)type {
    // NWInterfaceTypeOther is the public bucket normally used by tunnels.
    if (PXVPNBypassActive() && type == 0) return NO;
    return %orig;
}
%end

%hook NWInterface
- (NSString *)name {
    NSString *original = %orig;
    if (PXVPNBypassActive() && PXVPNInterfaceNameIsSensitive(original.UTF8String)) return @"en0";
    return original;
}
- (NSInteger)type {
    NSInteger original = %orig;
    // Network.framework classifies tunnel interfaces as "other" (0).
    // Report Wi-Fi (1) while the bypass is active so availableInterfaces and
    // direct interface inspection agree with -usesInterfaceType: above.
    return (PXVPNBypassActive() && original == 0) ? 1 : original;
}
%end

%end

static NSInteger (*PXOrigNEVPNConnectionStatus)(id, SEL) = NULL;
static NSInteger PXHookNEVPNConnectionStatus(id self, SEL _cmd) {
    if (PXVPNBypassActive()) return 1; // NEVPNStatusDisconnected
    return PXOrigNEVPNConnectionStatus ? PXOrigNEVPNConnectionStatus(self, _cmd) : 0;
}

static void PXVPNInstallFunctionHook(void *handle, const char *symbol, void *replacement, void **original) {
    if (!handle || !symbol || !replacement || !original) return;
    void *target = dlsym(handle, symbol);
    if (target) MSHookFunction(target, replacement, original);
}

%ctor {
    @autoreleasepool {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        NSString *processName = NSProcessInfo.processInfo.processName;
        if (!PXProcessIsAllowedForSpoofing(bundleID, processName, PXScopeOptionAllowSafariAuthStack)) return;

        PXNativeHookCoordinator *coordinator = [PXNativeHookCoordinator sharedCoordinator];
        [coordinator registerGetifaddrsProvider:@"vpn.interface-sanitize"
                                      priority:PXNativeHookPriorityNetworkStorage + 50
                                           pre:nil
                                          post:^(struct ifaddrs **ifap, int *result) {
            PXVPNPostGetifaddrs(ifap, result);
        }];
        [coordinator installOwnedSymbolsIfNeeded];

        void *cfNetwork = dlopen("/System/Library/Frameworks/CFNetwork.framework/CFNetwork", RTLD_LAZY);
        PXVPNInstallFunctionHook(cfNetwork, "CFNetworkCopySystemProxySettings",
                                 (void *)PXHookCFNetworkCopySystemProxySettings,
                                 (void **)&PXOrigCFNetworkCopySystemProxySettings);
        PXVPNInstallFunctionHook(cfNetwork, "CFNetworkCopyProxiesForAutoConfigurationScript",
                                 (void *)PXHookCFNetworkCopyProxiesForAutoConfigurationScript,
                                 (void **)&PXOrigCFNetworkCopyProxiesForAutoConfigurationScript);

        void *systemConfiguration = dlopen("/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration", RTLD_LAZY);
        PXVPNInstallFunctionHook(systemConfiguration, "SCDynamicStoreCopyProxies",
                                 (void *)PXHookSCDynamicStoreCopyProxies,
                                 (void **)&PXOrigSCDynamicStoreCopyProxies);

        void *networkExtension = dlopen("/System/Library/Frameworks/NetworkExtension.framework/NetworkExtension", RTLD_LAZY);
        (void)networkExtension;
        Class connectionClass = NSClassFromString(@"NEVPNConnection");
        Method statusMethod = connectionClass ? class_getInstanceMethod(connectionClass, NSSelectorFromString(@"status")) : NULL;
        if (statusMethod) {
            MSHookMessageEx(connectionClass, NSSelectorFromString(@"status"),
                            (IMP)PXHookNEVPNConnectionStatus,
                            (IMP *)&PXOrigNEVPNConnectionStatus);
        }

        %init(PXVPNObjectiveCHooks);
        PXLog(@"[VPNBypass] Runtime surfaces installed for %@", bundleID);
    }
}
