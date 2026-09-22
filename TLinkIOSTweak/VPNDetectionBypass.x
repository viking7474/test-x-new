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
#import "PXRuntimeUtilities.h"

static NSString *const kPXVPNSecuritySettingsPath = @"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist";
static NSString *const kPXVPNBypassSettingKey = @"vpnDetectionBypassEnabled";
static NSString *const kPXDiscoverySuppressionSettingKey = @"discoverySuppressionEnabled";

static BOOL PXNetworkPrivacySettingActive(NSString *key) {
    @try {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        NSString *processName = NSProcessInfo.processInfo.processName;
        if (!PXProcessIsAllowedForSpoofing(bundleID, processName, PXScopeOptionAllowSafariAuthStack)) return NO;
        NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:kPXVPNSecuritySettingsPath];
        return [settings[key] boolValue];
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static BOOL PXVPNBypassActive(void) {
    return PXNetworkPrivacySettingActive(kPXVPNBypassSettingKey);
}

static BOOL PXDiscoverySuppressionActive(void) {
    // This capability is deliberately independent and defaults to disabled
    // because a missing preference value evaluates to false.
    return PXNetworkPrivacySettingActive(kPXDiscoverySuppressionSettingKey);
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

typedef NS_ENUM(NSUInteger, PXVPNRuntimeHookKind) {
    PXVPNRuntimeHookObject,
    PXVPNRuntimeHookBool,
    PXVPNRuntimeHookStatus,
    PXVPNRuntimeHookLoadManagers,
};

typedef struct {
    const char *className;
    const char *selectorName;
    const char *imageFragment;
    BOOL classMethod;
    PXVPNRuntimeHookKind kind;
    IMP original;
} PXVPNRuntimeRule;

static PXVPNRuntimeRule gPXVPNRuntimeRules[] = {
    { "NEVPNManager", "+sharedManager", "/NetworkExtension.framework/", YES, PXVPNRuntimeHookObject, NULL },
    { "NEVPNManager", "+loadedManagers", "/NetworkExtension.framework/", YES, PXVPNRuntimeHookObject, NULL },
    { "NEVPNManager", "connection", "/NetworkExtension.framework/", NO, PXVPNRuntimeHookObject, NULL },
    { "NEVPNManager", "isEnabled", "/NetworkExtension.framework/", NO, PXVPNRuntimeHookBool, NULL },
    { "NETunnelProviderManager", "+loadAllFromPreferencesWithCompletionHandler:", "/NetworkExtension.framework/", YES, PXVPNRuntimeHookLoadManagers, NULL },
    { "NEVPNConnection", "status", "/NetworkExtension.framework/", NO, PXVPNRuntimeHookStatus, NULL },
};

typedef NS_ENUM(NSUInteger, PXDiscoveryRuntimeHookKind) {
    PXDiscoveryRuntimeHookVoid0,
    PXDiscoveryRuntimeHookVoid2,
};

typedef struct {
    const char *className;
    const char *selectorName;
    const char *imageFragment;
    PXDiscoveryRuntimeHookKind kind;
    IMP original;
} PXDiscoveryRuntimeRule;

static PXDiscoveryRuntimeRule gPXDiscoveryRuntimeRules[] = {
    { "MCNearbyServiceBrowser", "startBrowsingForPeers", "/MultipeerConnectivity.framework/", PXDiscoveryRuntimeHookVoid0, NULL },
    { "MCNearbyServiceBrowser", "syncStartBrowsingForPeers", "/MultipeerConnectivity.framework/", PXDiscoveryRuntimeHookVoid0, NULL },
    { "MCNearbyServiceBrowser", "syncStopBrowsingForPeers", "/MultipeerConnectivity.framework/", PXDiscoveryRuntimeHookVoid0, NULL },
    { "CBCentralManager", "scanForPeripheralsWithServices:options:", "/CoreBluetooth.framework/", PXDiscoveryRuntimeHookVoid2, NULL },
    { "NSNetServiceBrowser", "searchForBrowsableDomains", "/Foundation.framework/", PXDiscoveryRuntimeHookVoid0, NULL },
    { "NSNetServiceBrowser", "searchForRegistrationDomains", "/Foundation.framework/", PXDiscoveryRuntimeHookVoid0, NULL },
    { "NSNetServiceBrowser", "searchForServicesOfType:inDomain:", "/Foundation.framework/", PXDiscoveryRuntimeHookVoid2, NULL },
    { "NSNetServiceBrowser", "searchForAllDomains", "/Foundation.framework/", PXDiscoveryRuntimeHookVoid0, NULL },
};

static const char *PXRuntimeSelectorName(const char *selectorName) {
    return selectorName && selectorName[0] == '+' ? selectorName + 1 : selectorName;
}

static BOOL PXRuntimeMethodOwnedByImage(Class cls, const char *imageFragment) {
    const char *imageName = cls ? class_getImageName(cls) : NULL;
    return imageName && imageFragment && strstr(imageName, imageFragment) != NULL;
}

static BOOL PXRuntimeMethodHasShape(Method method, NSUInteger argumentCount, char returnType, BOOL objectArguments) {
    if (!method || method_getNumberOfArguments(method) != argumentCount) return NO;
    char result[8] = {0};
    method_getReturnType(method, result, sizeof(result));
    if (result[0] != returnType) return NO;
    if (!objectArguments) return YES;
    for (NSUInteger index = 2; index < argumentCount; index++) {
        char argument[8] = {0};
        method_getArgumentType(method, index, argument, sizeof(argument));
        if (argument[0] != '@') return NO;
    }
    return YES;
}

static BOOL PXVPNRuleEncodingIsValid(PXVPNRuntimeRule *rule, Method method) {
    if (!rule || !method) return NO;
    if (rule->kind == PXVPNRuntimeHookObject) return PXRuntimeMethodHasShape(method, 2, '@', NO);
    if (rule->kind == PXVPNRuntimeHookLoadManagers) return PXRuntimeMethodHasShape(method, 3, 'v', YES);
    if (method_getNumberOfArguments(method) != 2) return NO;
    char result[8] = {0};
    method_getReturnType(method, result, sizeof(result));
    if (rule->kind == PXVPNRuntimeHookBool) return result[0] == 'B' || result[0] == 'c';
    return result[0] == 'q' || result[0] == 'i' || result[0] == 'l';
}

static PXVPNRuntimeRule *PXVPNRuleForSelector(SEL selector, PXVPNRuntimeHookKind kind) {
    for (NSUInteger index = 0; index < sizeof(gPXVPNRuntimeRules) / sizeof(gPXVPNRuntimeRules[0]); index++) {
        PXVPNRuntimeRule *rule = &gPXVPNRuntimeRules[index];
        if (rule->kind == kind && sel_isEqual(selector, sel_registerName(PXRuntimeSelectorName(rule->selectorName)))) return rule;
    }
    return NULL;
}

static id PXHookVPNObjectGetter(id self, SEL _cmd) {
    PXVPNRuntimeRule *rule = PXVPNRuleForSelector(_cmd, PXVPNRuntimeHookObject);
    id original = rule && rule->original ? ((id (*)(id, SEL))rule->original)(self, _cmd) : nil;
    if (!PXVPNBypassActive()) return original;
    if (sel_isEqual(_cmd, sel_registerName("loadedManagers"))) return @[];
    // Preserve the framework-owned singleton/connection identities. Their
    // observable state is projected by -isEnabled and -status below.
    return original;
}

static BOOL PXHookVPNBoolGetter(id self, SEL _cmd) {
    PXVPNRuntimeRule *rule = PXVPNRuleForSelector(_cmd, PXVPNRuntimeHookBool);
    BOOL original = rule && rule->original ? ((BOOL (*)(id, SEL))rule->original)(self, _cmd) : NO;
    return PXVPNBypassActive() ? NO : original;
}

static NSInteger PXHookVPNStatusGetter(id self, SEL _cmd) {
    PXVPNRuntimeRule *rule = PXVPNRuleForSelector(_cmd, PXVPNRuntimeHookStatus);
    NSInteger original = rule && rule->original ? ((NSInteger (*)(id, SEL))rule->original)(self, _cmd) : 0;
    return PXVPNBypassActive() ? 1 : original; // NEVPNStatusDisconnected
}

typedef void (^PXVPNManagersCompletion)(NSArray *managers, NSError *error);
static void PXHookVPNLoadManagers(id self, SEL _cmd, PXVPNManagersCompletion completion) {
    PXVPNRuntimeRule *rule = PXVPNRuleForSelector(_cmd, PXVPNRuntimeHookLoadManagers);
    void (*original)(id, SEL, PXVPNManagersCompletion) = rule && rule->original
        ? (void (*)(id, SEL, PXVPNManagersCompletion))rule->original : NULL;
    if (!original) return;
    if (!PXVPNBypassActive() || !completion) {
        original(self, _cmd, completion);
        return;
    }

    // Let NetworkExtension own dispatch queue and callback cardinality. Only
    // project the manager list, and preserve any framework error unchanged.
    PXVPNManagersCompletion projected = ^(NSArray *managers, NSError *error) {
        (void)managers;
        completion(@[], error);
    };
    original(self, _cmd, projected);
}

static PXDiscoveryRuntimeRule *PXDiscoveryRuleForSelector(SEL selector, PXDiscoveryRuntimeHookKind kind) {
    for (NSUInteger index = 0; index < sizeof(gPXDiscoveryRuntimeRules) / sizeof(gPXDiscoveryRuntimeRules[0]); index++) {
        PXDiscoveryRuntimeRule *rule = &gPXDiscoveryRuntimeRules[index];
        if (rule->kind == kind && sel_isEqual(selector, sel_registerName(rule->selectorName))) return rule;
    }
    return NULL;
}

static void PXHookDiscoveryVoid0(id self, SEL _cmd) {
    PXDiscoveryRuntimeRule *rule = PXDiscoveryRuleForSelector(_cmd, PXDiscoveryRuntimeHookVoid0);
    if (!PXDiscoverySuppressionActive()) {
        if (rule && rule->original) ((void (*)(id, SEL))rule->original)(self, _cmd);
        return;
    }
    if (PXLogOnceClaim(@"VPNDiscovery.suppressed", NSStringFromSelector(_cmd))) {
        PXLog(@"[VPNBypass] Suppressed discovery selector %@", NSStringFromSelector(_cmd));
    }
}

static void PXHookDiscoveryVoid2(id self, SEL _cmd, id first, id second) {
    PXDiscoveryRuntimeRule *rule = PXDiscoveryRuleForSelector(_cmd, PXDiscoveryRuntimeHookVoid2);
    if (!PXDiscoverySuppressionActive()) {
        if (rule && rule->original) ((void (*)(id, SEL, id, id))rule->original)(self, _cmd, first, second);
        return;
    }
    if (PXLogOnceClaim(@"VPNDiscovery.suppressed", NSStringFromSelector(_cmd))) {
        PXLog(@"[VPNBypass] Suppressed discovery selector %@", NSStringFromSelector(_cmd));
    }
}

static NSUInteger PXInstallVPNManagerRuntimeHooks(void) {
    NSUInteger installed = 0;
    for (NSUInteger index = 0; index < sizeof(gPXVPNRuntimeRules) / sizeof(gPXVPNRuntimeRules[0]); index++) {
        PXVPNRuntimeRule *rule = &gPXVPNRuntimeRules[index];
        Class cls = objc_getClass(rule->className);
        if (!cls || !PXRuntimeMethodOwnedByImage(cls, rule->imageFragment)) continue;
        Class target = rule->classMethod ? object_getClass((id)cls) : cls;
        SEL selector = sel_registerName(PXRuntimeSelectorName(rule->selectorName));
        Method method = target ? class_getInstanceMethod(target, selector) : NULL;
        if (!PXVPNRuleEncodingIsValid(rule, method)) continue;

        IMP replacement = NULL;
        if (rule->kind == PXVPNRuntimeHookObject) replacement = (IMP)PXHookVPNObjectGetter;
        else if (rule->kind == PXVPNRuntimeHookBool) replacement = (IMP)PXHookVPNBoolGetter;
        else if (rule->kind == PXVPNRuntimeHookStatus) replacement = (IMP)PXHookVPNStatusGetter;
        else if (rule->kind == PXVPNRuntimeHookLoadManagers) replacement = (IMP)PXHookVPNLoadManagers;
        if (!replacement) continue;
        MSHookMessageEx(target, selector, replacement, &rule->original);
        installed++;
    }
    return installed;
}

static NSUInteger PXInstallDiscoveryRuntimeHooks(void) {
    NSUInteger installed = 0;
    for (NSUInteger index = 0; index < sizeof(gPXDiscoveryRuntimeRules) / sizeof(gPXDiscoveryRuntimeRules[0]); index++) {
        PXDiscoveryRuntimeRule *rule = &gPXDiscoveryRuntimeRules[index];
        Class cls = objc_getClass(rule->className);
        if (!cls || !PXRuntimeMethodOwnedByImage(cls, rule->imageFragment)) continue;
        SEL selector = sel_registerName(rule->selectorName);
        Method method = class_getInstanceMethod(cls, selector);
        NSUInteger argumentCount = rule->kind == PXDiscoveryRuntimeHookVoid0 ? 2 : 4;
        if (!PXRuntimeMethodHasShape(method, argumentCount, 'v', rule->kind == PXDiscoveryRuntimeHookVoid2)) continue;
        IMP replacement = rule->kind == PXDiscoveryRuntimeHookVoid0 ? (IMP)PXHookDiscoveryVoid0 : (IMP)PXHookDiscoveryVoid2;
        MSHookMessageEx(cls, selector, replacement, &rule->original);
        installed++;
    }
    return installed;
}

static void PXVPNInstallFunctionHook(void *handle, const char *symbol, void *replacement, void **original) {
    if (!handle || !symbol || !replacement || !original) return;
    void *target = dlsym(handle, symbol);
    if (target) MSHookFunction(target, replacement, original);
}

%ctor {
    @autoreleasepool {
        if (!PXBootstrapAllows(PXHookCapabilityNative)) return;
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

        (void)dlopen("/System/Library/Frameworks/NetworkExtension.framework/NetworkExtension", RTLD_LAZY);
        (void)dlopen("/System/Library/Frameworks/MultipeerConnectivity.framework/MultipeerConnectivity", RTLD_LAZY);
        (void)dlopen("/System/Library/Frameworks/CoreBluetooth.framework/CoreBluetooth", RTLD_LAZY);

        NSUInteger vpnManagerHooks = PXInstallVPNManagerRuntimeHooks();
        NSUInteger discoveryHooks = PXInstallDiscoveryRuntimeHooks();

        %init(PXVPNObjectiveCHooks);
        PXLog(@"[VPNBypass] Runtime surfaces installed for %@; capability audit vpn-manager=%lu/6 discovery=%lu/8 discovery-active=%@",
              bundleID, (unsigned long)vpnManagerHooks, (unsigned long)discoveryHooks,
              PXDiscoverySuppressionActive() ? @"YES" : @"NO");
    }
}
