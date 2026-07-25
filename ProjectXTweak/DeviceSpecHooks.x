#import "ProjectX.h"
#import "DeviceModelManager.h"
#import "IdentifierManager.h"
#import "ProfileManager.h"
#import "ProjectXLogging.h"
#import "HookOwnership.h"
#import "PXNativeHookCoordinator.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Metal/Metal.h>
#import <WebKit/WebKit.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <dlfcn.h>
#import <errno.h>
#import <mach-o/arch.h>
// #import <ellekit/ellekit.h> // Removed for rootful - using Substrate
#import "IOSVersionInfo.h"

#import "PXScope.h"
#import "PXFileDebug.h"

// Define the swap usage structure if it's not available
#ifndef HAVE_XSW_USAGE
struct xsw_usage {
    uint64_t xsu_total;
    uint64_t xsu_avail;
    uint64_t xsu_used;
    uint32_t xsu_pagesize;
    boolean_t xsu_encrypted;
};
typedef struct xsw_usage xsw_usage;
#endif

#ifndef CPU_SUBTYPE_ARM64_V8
#define CPU_SUBTYPE_ARM64_V8 ((cpu_subtype_t)1)
#endif
#ifndef CPU_SUBTYPE_ARM64E
#define CPU_SUBTYPE_ARM64E ((cpu_subtype_t)2)
#endif

// Original function pointers
static kern_return_t (*orig_host_statistics64)(host_t host, host_flavor_t flavor, host_info64_t info, mach_msg_type_number_t *count);
static NXArchInfo* (* orig_nx_get_local_arch_info)();

// Path to scoped apps plist
static NSString *const kScopedAppsPath = @"/var/mobile/Library/Preferences/com.hydra.projectx.global_scope.plist";
static NSString *const kScopedAppsPathAlt1 = @"/private/var/mobile/Library/Preferences/com.hydra.projectx.global_scope.plist";
static NSString *const kScopedAppsPathAlt2 = @"/var/mobile/Library/Preferences/com.hydra.projectx.global_scope.plist";

// Scoped apps cache
static NSMutableDictionary *scopedAppsCache = nil;
static NSDate *scopedAppsCacheTimestamp = nil;
static const NSTimeInterval kScopedAppsCacheValidDuration = 60.0; // 1 minute

// Caches for device specs
static NSMutableDictionary *deviceSpecsCache;
static NSDate *cacheTimestamp;
static NSString *cachedDeviceModel;
static NSMutableDictionary *cachedBundleDecisions;

// Cache to track which memory hooks have been called for logging
static NSMutableSet *hookedMemoryAPIs;

// Cache for bundle decisions
static const NSTimeInterval kCacheValidityDuration = 300.0; // 5 minutes

// Helper for logging memory hook invocations only once
static void logMemoryHook(NSString *apiName);

// Function declarations
static NSString *getCurrentBundleID(void);
static BOOL PXCPUArchitectureHasToken(NSString *architecture, NSString *token);
static NSDictionary *loadScopedApps(void);
static BOOL isInScopedAppsList(void);
static BOOL isSpoofingEnabled(void);
static NSString *getSpoofedDeviceModel(void);
static NSDictionary *getDeviceSpecs(void);
static float getFreeMemoryPercentage(void);
static void getConsistentMemoryStats(unsigned long long totalMemory, 
                                    unsigned long long *freeMemory,
                                    unsigned long long *wiredMemory,
                                    unsigned long long *activeMemory,
                                    unsigned long long *inactiveMemory);
static kern_return_t hook_host_statistics64(host_t host, host_flavor_t flavor, host_info64_t info, mach_msg_type_number_t *count);
static int applyDeviceSpecSysctlBynamePost(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen, int originalResult);
static NXArchInfo* hook_nx_get_local_arch_info();
static void refreshCaches(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
static CGSize parseResolution(NSString *resolutionString);

#pragma mark - Helper Functions

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

// Match a processor token on an alphanumeric boundary so A18 does not match A180
// and M1 does not match M10. A12X/A12Z are explicit members of the A12 family.
static BOOL PXCPUArchitectureHasToken(NSString *architecture, NSString *token) {
    if (!architecture.length || !token.length) return NO;

    NSString *upperArchitecture = [architecture uppercaseString];
    NSString *upperToken = [token uppercaseString];
    NSCharacterSet *alphanumeric = [NSCharacterSet alphanumericCharacterSet];
    NSRange searchRange = NSMakeRange(0, upperArchitecture.length);

    while (searchRange.length > 0) {
        NSRange match = [upperArchitecture rangeOfString:upperToken options:0 range:searchRange];
        if (match.location == NSNotFound) return NO;

        BOOL beforeIsBoundary = (match.location == 0) ||
            ![alphanumeric characterIsMember:[upperArchitecture characterAtIndex:match.location - 1]];
        NSUInteger end = NSMaxRange(match);
        BOOL afterIsBoundary = (end >= upperArchitecture.length) ||
            ![alphanumeric characterIsMember:[upperArchitecture characterAtIndex:end]];

        // A12X and A12Z share the A12 CPU family but must be accepted explicitly.
        if (!afterIsBoundary && [upperToken isEqualToString:@"A12"] && end < upperArchitecture.length) {
            unichar suffix = [upperArchitecture characterAtIndex:end];
            NSUInteger suffixEnd = end + 1;
            BOOL suffixBoundary = (suffixEnd >= upperArchitecture.length) ||
                ![alphanumeric characterIsMember:[upperArchitecture characterAtIndex:suffixEnd]];
            afterIsBoundary = (suffix == 'X' || suffix == 'Z') && suffixBoundary;
        }

        if (beforeIsBoundary && afterIsBoundary) return YES;

        NSUInteger next = match.location + 1;
        if (next >= upperArchitecture.length) return NO;
        searchRange = NSMakeRange(next, upperArchitecture.length - next);
    }

    return NO;
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
                PXLog(@"[DeviceSpec] Could not find scoped apps file");
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

// Check if device model spoofing is enabled for the current app with caching
static BOOL isSpoofingEnabled(void) {
    NSString *currentBundleID = getCurrentBundleID();
    if (!currentBundleID) return NO;
    NSString *proc = [NSProcessInfo processInfo].processName;
    if (!PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack)) return NO;
    
    // Check if the current app is a scoped app AND if device model spoofing is enabled
    BOOL shouldSpoof = NO;
    @try {
        BOOL managerCheckPassed = NO;
        if (NSClassFromString(@"IdentifierManager")) {
            IdentifierManager *manager = [NSClassFromString(@"IdentifierManager") sharedManager];
            if (manager && [manager isIdentifierEnabled:@"DeviceModel"]) {
                shouldSpoof = YES;
                managerCheckPassed = YES;
            }
        }

        if (!managerCheckPassed) {
            NSString *profilesPath = @"/var/mobile/Library/WeaponX/Profiles";
            NSString *centralInfoPath = [profilesPath stringByAppendingPathComponent:@"current_profile_info.plist"];
            NSDictionary *centralInfo = [NSDictionary dictionaryWithContentsOfFile:centralInfoPath];
            NSString *profileId = centralInfo[@"ProfileId"];
            if (profileId) {
                NSString *profileSettingsPath = [profilesPath stringByAppendingPathComponent:[profileId stringByAppendingPathComponent:@"settings.plist"]];
                NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:profileSettingsPath];
                if (settings && settings[@"deviceModelEnabled"]) {
                    shouldSpoof = [settings[@"deviceModelEnabled"] boolValue];
                }
            }
        }
    } @catch (NSException *exception) {
        PXLog(@"[DeviceSpec] Exception checking if device model spoofing is enabled: %@", exception);
        shouldSpoof = NO;
    }
    
    return shouldSpoof;
}

// Get the device model from profile
static NSString *getSpoofedDeviceModel() {
    @try {
        // Try multiple methods to get the model value
        NSString *deviceModel = nil;

        // METHOD 0: Prefer IdentifierManager for consistency with other hooks
        if (NSClassFromString(@"IdentifierManager")) {
            IdentifierManager *manager = [NSClassFromString(@"IdentifierManager") sharedManager];
            if (manager) {
                NSString *m = [manager currentValueForIdentifier:@"DeviceModel"];
                if (m.length > 0) {
                    deviceModel = m;
                }
            }
        }
        
        // METHOD 1: Try direct access from profile plist (device_ids.plist)
        if (!deviceModel.length) {
            NSString *profilesPath = @"/var/mobile/Library/WeaponX/Profiles";
            NSString *centralInfoPath = [profilesPath stringByAppendingPathComponent:@"current_profile_info.plist"];
            NSDictionary *centralInfo = [NSDictionary dictionaryWithContentsOfFile:centralInfoPath];

            NSString *profileId = centralInfo[@"ProfileId"];
            if (profileId) {
                // Build path to identity directory
                NSString *identityDir = [[profilesPath stringByAppendingPathComponent:profileId] stringByAppendingPathComponent:@"identity"];

                NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
                NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
                deviceModel = deviceIds[@"DeviceModel"];
            }
        }
        
        // METHOD 2: Use DeviceModelManager as fallback (do not generate here)
        if (!deviceModel.length && NSClassFromString(@"DeviceModelManager")) {
            DeviceModelManager *deviceManager = [NSClassFromString(@"DeviceModelManager") sharedManager];
            deviceModel = [deviceManager currentDeviceModel];
        }
        
        return deviceModel;
    } @catch (NSException *exception) {
        PXLog(@"[DeviceSpec] Exception getting spoofed device model: %@", exception);
        return nil;
    }
}

// Get all device specifications for the current spoofed model
static NSDictionary *getDeviceSpecs() {
    // Initialize cache if needed
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        deviceSpecsCache = [NSMutableDictionary dictionary];
    });
    
    // Check if specs are already cached
    @synchronized(deviceSpecsCache) {
        NSDictionary *cachedSpecs = deviceSpecsCache[@"specs"];
        if (cachedSpecs && [[NSDate date] timeIntervalSinceDate:cacheTimestamp] < kCacheValidityDuration) {
            return cachedSpecs;
        }
    }
    
    @try {
        // METHOD 1: Try to get specs directly from device_ids.plist
        NSString *profilesPath = @"/var/mobile/Library/WeaponX/Profiles";
        NSString *centralInfoPath = [profilesPath stringByAppendingPathComponent:@"current_profile_info.plist"];
        NSDictionary *centralInfo = [NSDictionary dictionaryWithContentsOfFile:centralInfoPath];
        
        NSString *profileId = centralInfo[@"ProfileId"];
        if (profileId) {
            NSString *identityDir = [[profilesPath stringByAppendingPathComponent:profileId] stringByAppendingPathComponent:@"identity"];
            NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
            NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
            
            if (deviceIds && deviceIds[@"DeviceModel"]) {
                // Reconstruct specs from device_ids.plist
                NSMutableDictionary *specs = [NSMutableDictionary dictionary];
                specs[@"value"] = deviceIds[@"DeviceModel"];
                specs[@"name"] = deviceIds[@"DeviceModelName"] ?: @"Unknown";
                specs[@"screenResolution"] = deviceIds[@"ScreenResolution"] ?: @"Unknown";
                specs[@"viewportResolution"] = deviceIds[@"ViewportResolution"] ?: @"Unknown";
                specs[@"devicePixelRatio"] = deviceIds[@"DevicePixelRatio"] ?: @(0);
                specs[@"screenDensity"] = deviceIds[@"ScreenDensityPPI"] ?: @(0);
                specs[@"cpuArchitecture"] = deviceIds[@"CPUArchitecture"] ?: @"Unknown";
                specs[@"deviceMemory"] = deviceIds[@"DeviceMemory"] ?: @(0);
                specs[@"gpuFamily"] = deviceIds[@"GPUFamily"] ?: @"Unknown";
                specs[@"cpuCoreCount"] = deviceIds[@"CPUCoreCount"] ?: @(0);
                specs[@"metalFeatureSet"] = deviceIds[@"MetalFeatureSet"] ?: @"Unknown";
                
                // Add board/hardware identifiers (used by apps like AIDA)
                if (deviceIds[@"BoardID"]) {
                    specs[@"boardID"] = deviceIds[@"BoardID"];
                }
                if (deviceIds[@"HwModel"]) {
                    specs[@"hwModel"] = deviceIds[@"HwModel"];
                } else if (deviceIds[@"BoardID"]) {
                    specs[@"hwModel"] = deviceIds[@"BoardID"]; // Best-effort fallback
                }

                // Reconstruct webGLInfo
                NSMutableDictionary *webGLInfo = [NSMutableDictionary dictionary];
                webGLInfo[@"webglVendor"] = deviceIds[@"WebGLVendor"] ?: @"Apple";
                webGLInfo[@"webglRenderer"] = deviceIds[@"WebGLRenderer"] ?: @"Apple GPU";
                webGLInfo[@"unmaskedVendor"] = @"Apple Inc.";
                webGLInfo[@"unmaskedRenderer"] = deviceIds[@"GPUFamily"] ?: @"Apple GPU";
                webGLInfo[@"webglVersion"] = @"WebGL 2.0";
                webGLInfo[@"maxTextureSize"] = @(16384);
                webGLInfo[@"maxRenderBufferSize"] = @(16384);
                specs[@"webGLInfo"] = webGLInfo;
                
                PXLog(@"[DeviceSpec] Reconstructed device specs from device_ids.plist");
                
                // Cache the specifications
                @synchronized(deviceSpecsCache) {
                    deviceSpecsCache[@"specs"] = specs;
                    cacheTimestamp = [NSDate date];
                }
                
                return specs;
            }
        }
        
        // METHOD 2: Fallback to DeviceModelManager
        // Get the current spoofed device model
        NSString *deviceModel = getSpoofedDeviceModel();
        if (!deviceModel.length) {
            return nil;
        }
        
        // Get the specifications from DeviceModelManager
        DeviceModelManager *deviceManager = [NSClassFromString(@"DeviceModelManager") sharedManager];
        if (!deviceManager) {
            PXLog(@"[DeviceSpec] WARNING: DeviceModelManager not available");
            return nil;
        }
        
        NSDictionary *specs = [deviceManager deviceSpecificationsForModel:deviceModel];
        if (!specs) {
            PXLog(@"[DeviceSpec] WARNING: No specifications found for device model: %@", deviceModel);
            return nil;
        }
        
        // Cache the specifications
        @synchronized(deviceSpecsCache) {
            deviceSpecsCache[@"specs"] = specs;
            cacheTimestamp = [NSDate date];
        }
        
        return specs;
    } @catch (NSException *exception) {
        PXLog(@"[DeviceSpec] Exception getting device specifications: %@", exception);
        return nil;
    }
}

#pragma mark - Document-Start Web Capability Script

// Central WKWebView ownership lives in CanvasFingerprintHooks.x. This exported helper
// contributes device capability spoofing without installing additional WKWebView hooks.
void PXInstallDeviceSpecUserScripts(WKUserContentController *userContentController) {
    if (!userContentController) return;
    for (WKUserScript *existingScript in userContentController.userScripts) {
        if ([existingScript.source containsString:@"__weaponx_device_capabilities__"]) {
            return;
        }
    }
    if (!isSpoofingEnabled()) return;

    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString *processName = [NSProcessInfo processInfo].processName;
    if (!PXFullSpoofTestModeEnabled() &&
        PXProcessIsAllowedForSpoofing(bundleID, processName, PXScopeOptionAllowSafariAuthStack) &&
        PXIsSafariStackProcess(bundleID, processName)) {
        return;
    }

    NSDictionary *specs = getDeviceSpecs();
    NSInteger deviceMemoryGB = [specs[@"deviceMemory"] integerValue];
    NSInteger cpuCoreCount = [specs[@"cpuCoreCount"] integerValue];
    if (deviceMemoryGB <= 0 && cpuCoreCount <= 0) return;

    NSString *script = [NSString stringWithFormat:
        @"(function(){\n"
         "  'use strict';\n"
         "  try {\n"
         "    if (globalThis.__weaponx_device_capabilities__) return;\n"
         "    Object.defineProperty(globalThis,'__weaponx_device_capabilities__',{value:true,configurable:false,enumerable:false,writable:false});\n"
         "    var nav=globalThis.navigator; if(!nav) return;\n"
         "    var proto=Object.getPrototypeOf(nav)||nav;\n"
         "    function def(name,value){\n"
         "      if(!(value>0)) return;\n"
         "      try{Object.defineProperty(proto,name,{get:function(){return value;},configurable:true,enumerable:true});return;}catch(e){}\n"
         "      try{Object.defineProperty(nav,name,{get:function(){return value;},configurable:true,enumerable:true});}catch(e){}\n"
         "    }\n"
         "    def('deviceMemory',%ld);\n"
         "    def('hardwareConcurrency',%ld);\n"
         "  } catch(e) {}\n"
         "})();",
        (long)deviceMemoryGB,
        (long)cpuCoreCount];

    WKUserScript *userScript = [[WKUserScript alloc] initWithSource:script
                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                   forMainFrameOnly:NO];
    [userContentController addUserScript:userScript];
}

// Parse resolution string (e.g., "2556x1179") into CGSize
static CGSize parseResolution(NSString *resolutionString) {
    if (!resolutionString) return CGSizeZero;
    
    NSArray *components = [resolutionString componentsSeparatedByString:@"x"];
    if (components.count != 2) return CGSizeZero;
    
    CGFloat width = [components[0] floatValue];
    CGFloat height = [components[1] floatValue];
    
    return CGSizeMake(width, height);
}

#pragma mark - UIScreen Hooks

// Check if current process is a WebKit/WebContent process that needs resolution spoofing
static BOOL shouldSpoofResolutionForCurrentProcess() {
    static BOOL cachedDecision = NO;
    static BOOL hasCheckedProcess = NO;
    
    if (hasCheckedProcess) {
        return cachedDecision;
    }
    
    // IMPORTANT:
    // By default, do NOT spoof UIScreen bounds/scale for Safari/Auth stack processes.
    // In SafariViewService/WebKit services, spoofing UIScreen can desync touch hit-testing
    // and break critical flows (e.g. Google login buttons not clickable).
    // In FullSpoof test mode we override this to intentionally stress web flows.
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
    NSString *procName = [[NSProcessInfo processInfo] processName];
    if (PXProcessIsAllowedForSpoofing(bid, procName, PXScopeOptionAllowSafariAuthStack) && PXIsSafariStackProcess(bid, procName) && !PXFullSpoofTestModeEnabled()) {
        hasCheckedProcess = YES;
        cachedDecision = NO;
        return NO;
    }

    // Only spoof resolution for web views, not for native apps
    NSString *processName = procName;
    BOOL isWebProcess = [processName containsString:@"WebKit"] || 
                        [processName containsString:@"WebContent"] ||
                        [processName containsString:@"Safari"];
                         
    // For Safari and web-focused apps, continue spoofing
    NSString *bundleID = bid;
    BOOL isWebApp = [bundleID hasPrefix:@"com.apple.mobilesafari"] ||
                    [bundleID hasPrefix:@"com.google.chrome"] ||
                    [bundleID hasPrefix:@"org.mozilla.ios.Firefox"] ||
                    [bundleID hasPrefix:@"com.brave.ios"] ||
                    [bundleID hasPrefix:@"com.opera"];
    
    // Cache the decision
    hasCheckedProcess = YES;
    cachedDecision = isWebProcess || isWebApp;
    
    PXLog(@"[DeviceSpec] Resolution spoofing for process '%@' (%@): %@", 
          processName, bundleID, cachedDecision ? @"ENABLED" : @"DISABLED");
          
    return cachedDecision;
}

%hook UIScreen

// Hook for bounds (controls size of the screen in points)
- (CGRect)bounds {
    CGRect originalBounds = %orig;
    
    if (!isSpoofingEnabled() || !PXDisplayUIScaleSpoofEnabled() || !shouldSpoofResolutionForCurrentProcess()) {
        return originalBounds;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalBounds;
    }
    
    // Get the viewport resolution and device pixel ratio from specs
    NSString *viewportResString = specs[@"viewportResolution"];
    NSString *screenResString = specs[@"screenResolution"];
    CGFloat pixelRatio = [specs[@"devicePixelRatio"] floatValue];
    
    if (!viewportResString || pixelRatio <= 0) {
        return originalBounds;
    }
    
    // Parse the viewport resolution
    CGSize viewportSize = parseResolution(viewportResString);
    if (CGSizeEqualToSize(viewportSize, CGSizeZero)) {
        return originalBounds;
    }

    // Some profiles store viewportResolution in points/CSS pixels already.
    // If we divide by DPR again, bounds become unrealistically small.
    BOOL viewportIsPoints = NO;
    CGSize screenSize = parseResolution(screenResString);
    if (!CGSizeEqualToSize(screenSize, CGSizeZero)) {
        CGFloat screenMax = MAX(screenSize.width, screenSize.height);
        CGFloat viewportMax = MAX(viewportSize.width, viewportSize.height);
        if (screenMax > 1500.0 && viewportMax > 0.0 && viewportMax < 1500.0) {
            viewportIsPoints = YES;
        }
    }
    
    // Calculate bounds in points (logical pixels)
    CGFloat width = viewportIsPoints ? viewportSize.width : (viewportSize.width / pixelRatio);
    CGFloat height = viewportIsPoints ? viewportSize.height : (viewportSize.height / pixelRatio);

    // Normalize to portrait-style bounds (UIScreen reports portrait coordinate space).
    CGFloat normW = MIN(width, height);
    CGFloat normH = MAX(width, height);
    
    // Log the change the first time
    static BOOL loggedScreenBounds = NO;
    if (!loggedScreenBounds) {
        PXLog(@"[DeviceSpec] Spoofing UIScreen bounds from %@ to %@",
             NSStringFromCGRect(originalBounds),
             NSStringFromCGRect(CGRectMake(0, 0, normW, normH)));
        loggedScreenBounds = YES;
    }
    
    return CGRectMake(0, 0, normW, normH);
}

// Hook for nativeBounds (actual pixels)
- (CGRect)nativeBounds {
    CGRect originalNativeBounds = %orig;
    
    if (!isSpoofingEnabled() || !PXDisplayPixelMetricsSpoofEnabled() || !shouldSpoofResolutionForCurrentProcess()) {
        return originalNativeBounds;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalNativeBounds;
    }
    
    // Get the screen resolution from specs
    NSString *screenResString = specs[@"screenResolution"];
    if (!screenResString) {
        return originalNativeBounds;
    }
    
    // Parse the screen resolution
    CGSize screenSize = parseResolution(screenResString);
    if (CGSizeEqualToSize(screenSize, CGSizeZero)) {
        return originalNativeBounds;
    }

    // Normalize to portrait-style native bounds.
    CGFloat normW = MIN(screenSize.width, screenSize.height);
    CGFloat normH = MAX(screenSize.width, screenSize.height);
    
    // Log the change the first time
    static BOOL loggedNativeBounds = NO;
    if (!loggedNativeBounds) {
        PXLog(@"[DeviceSpec] Spoofing UIScreen nativeBounds from %@ to %@",
             NSStringFromCGRect(originalNativeBounds),
             NSStringFromCGRect(CGRectMake(0, 0, normW, normH)));
        loggedNativeBounds = YES;
    }
    
    return CGRectMake(0, 0, normW, normH);
}

// Hook for scale (affects UI element sizes)
- (CGFloat)scale {
    CGFloat originalScale = %orig;
    
    if (!isSpoofingEnabled() || !shouldSpoofResolutionForCurrentProcess()) {
        return originalScale;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalScale;
    }
    
    // Get the device pixel ratio from specs
    CGFloat pixelRatio = [specs[@"devicePixelRatio"] floatValue];
    if (pixelRatio <= 0) {
        return originalScale;
    }
    
    // Log the change the first time
    static BOOL loggedScale = NO;
    if (!loggedScale) {
        PXLog(@"[DeviceSpec] Spoofing UIScreen scale from %.2f to %.2f", originalScale, pixelRatio);
        loggedScale = YES;
    }
    
    return pixelRatio;
}

// Hook for current mode (affects refresh rate)
- (UIScreenMode *)currentMode {
    UIScreenMode *originalMode = %orig;
    
    if (!isSpoofingEnabled()) {
        return originalMode;
    }
    
    // We can't create a new UIScreenMode, but we can modify its properties
    // through associated objects if needed in the future
    
    return originalMode;
}

%end

#pragma mark - NSProcessInfo Hooks

%hook NSProcessInfo

// Hook for physical memory (RAM)
- (unsigned long long)physicalMemory {
    unsigned long long originalMemory = %orig;
    
    if (!isSpoofingEnabled()) {
        return originalMemory;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalMemory;
    }
    
    // Get the device memory from specs (in GB)
    NSInteger deviceMemoryGB = [specs[@"deviceMemory"] integerValue];
    if (deviceMemoryGB <= 0) {
        return originalMemory;
    }
    
    // Convert GB to bytes
    unsigned long long spoofedMemory = ((unsigned long long)deviceMemoryGB) * 1024ULL * 1024ULL * 1024ULL;
    
    // Log the change the first time
    static BOOL loggedMemory = NO;
    if (!loggedMemory) {
        PXLog(@"[DeviceSpec] Spoofing device memory from %llu bytes to %llu bytes (%ld GB)",
             originalMemory, spoofedMemory, (long)deviceMemoryGB);
        loggedMemory = YES;
    }
    
    return spoofedMemory;
}

// Add hook for macOS compatibility - similar to iOS physicalMemory
- (unsigned long long)physicalMemorySize {
    logMemoryHook(@"physicalMemorySize");
    return [self physicalMemory]; // Reuse the physicalMemory hook
}

// Add hook for total memory (used on some iOS versions)
- (unsigned long long)totalPhysicalMemory {
    logMemoryHook(@"totalPhysicalMemory");
    return [self physicalMemory]; // Reuse the physicalMemory hook
}

// Hook for available memory
- (unsigned long long)availableMemory {
    unsigned long long originalAvailableMemory = %orig;
    
    if (!isSpoofingEnabled()) {
        return originalAvailableMemory;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalAvailableMemory;
    }
    
    // Get the device memory from specs (in GB)
    NSInteger deviceMemoryGB = [specs[@"deviceMemory"] integerValue];
    if (deviceMemoryGB <= 0) {
        return originalAvailableMemory;
    }
    
    // Calculate total memory
    unsigned long long totalMemory = ((unsigned long long)deviceMemoryGB) * 1024ULL * 1024ULL * 1024ULL;
    
    // Calculate free memory based on typical iOS behavior
    float freePercentage = getFreeMemoryPercentage();
    unsigned long long spoofedAvailableMemory = (unsigned long long)(totalMemory * freePercentage);
    
    // Log the change the first time
    static BOOL loggedAvailableMemory = NO;
    if (!loggedAvailableMemory) {
        PXLog(@"[DeviceSpec] Spoofing available memory from %llu bytes to %llu bytes (%.1f%% of %ld GB)",
             originalAvailableMemory, spoofedAvailableMemory, freePercentage * 100, (long)deviceMemoryGB);
        loggedAvailableMemory = YES;
    }
    
    return spoofedAvailableMemory;
}

// Hook for processor count
- (NSUInteger)processorCount {
    NSUInteger originalCount = %orig;
    
    if (!isSpoofingEnabled()) {
        return originalCount;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalCount;
    }
    
    // Get CPU core count from specs
    NSInteger cpuCoreCount = [specs[@"cpuCoreCount"] integerValue];
    if (cpuCoreCount <= 0) {
        return originalCount;
    }
    
    // Log the change the first time
    static BOOL loggedProcessorCount = NO;
    if (!loggedProcessorCount) {
        PXLog(@"[DeviceSpec] Spoofing processor count from %lu to %ld",
             (unsigned long)originalCount, (long)cpuCoreCount);
        loggedProcessorCount = YES;
    }
    
    return cpuCoreCount;
}

// Add hook for CPU architecture information
- (NSString *)machineHardwareName {
    NSString *originalName = %orig;
    
    if (!isSpoofingEnabled()) {
        return originalName;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalName;
    }
    
    // Get CPU architecture from specs
    NSString *cpuArchitecture = specs[@"cpuArchitecture"];
    if (!cpuArchitecture || cpuArchitecture.length == 0) {
        return originalName;
    }
    
    // Log the change the first time
    static BOOL loggedMachineHardwareName = NO;
    if (!loggedMachineHardwareName) {
        PXLog(@"[DeviceSpec] Spoofing machine hardware name from '%@' to '%@'",
             originalName, cpuArchitecture);
        loggedMachineHardwareName = YES;
    }
    
    return cpuArchitecture;
}

%end

#pragma mark - WebGL Info Hooks

%hook WebGLRenderingContext

// WebKit returns `id` (string/number/array/etc). Returning the wrong type can break JS.
- (id)getParameter:(unsigned)pname {
    id original = %orig;
    
    if (!isSpoofingEnabled()) {
        return original;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return original;
    }
    
    NSDictionary *webGLInfo = specs[@"webGLInfo"];
    if (!webGLInfo) {
        return original;
    }
    
    // Map WebGL parameter constants to our stored values
    // VENDOR = 0x1F00, RENDERER = 0x1F01, VERSION = 0x1F02
    id spoofedValue = nil;
    
    if (pname == 0x1F00) { // VENDOR
        spoofedValue = webGLInfo[@"webglVendor"];
    } else if (pname == 0x1F01) { // RENDERER
        spoofedValue = webGLInfo[@"webglRenderer"];
    } else if (pname == 0x1F02) { // VERSION
        spoofedValue = webGLInfo[@"webglVersion"];
    } else if (pname == 0x8B4F || pname == 0x8B4E) { // UNMASKED_VENDOR_WEBGL or UNMASKED_RENDERER_WEBGL
        spoofedValue = (pname == 0x8B4F) ? webGLInfo[@"unmaskedVendor"] : webGLInfo[@"unmaskedRenderer"];
    } else if (pname == 0x0D33) { // MAX_TEXTURE_SIZE
        id v = webGLInfo[@"maxTextureSize"];
        if ([v isKindOfClass:[NSNumber class]]) return v;
        if ([v respondsToSelector:@selector(integerValue)]) return @([v integerValue]);
        return original;
    } else if (pname == 0x8D57) { // MAX_RENDERBUFFER_SIZE
        id v = webGLInfo[@"maxRenderBufferSize"];
        if ([v isKindOfClass:[NSNumber class]]) return v;
        if ([v respondsToSelector:@selector(integerValue)]) return @([v integerValue]);
        return original;
    }
    
    if (spoofedValue) {
        static NSMutableSet *loggedParameters = nil;
        if (!loggedParameters) {
            loggedParameters = [NSMutableSet set];
        }
        
        NSString *paramKey = [NSString stringWithFormat:@"%u", pname];
        if (![loggedParameters containsObject:paramKey]) {
            [loggedParameters addObject:paramKey];
            PXLog(@"[DeviceSpec] Spoofing WebGL parameter 0x%X from '%@' to '%@'", pname, original, spoofedValue);
        }
        
        return spoofedValue;
    }
    
    return original;
}

%end

#pragma mark - Metal API Hooks

%hook MTLDevice

// Hook for name property
- (NSString *)name {
    NSString *originalName = %orig;
    
    if (!isSpoofingEnabled()) {
        return originalName;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalName;
    }
    
    NSString *gpuFamily = specs[@"gpuFamily"];
    if (!gpuFamily) {
        return originalName;
    }
    
    // Log the change the first time
    static BOOL loggedGPUName = NO;
    if (!loggedGPUName) {
        PXLog(@"[DeviceSpec] Spoofing GPU name from '%@' to '%@'", originalName, gpuFamily);
        loggedGPUName = YES;
    }
    
    return gpuFamily;
}

// Also hook the family name property
- (NSString *)familyName {
    NSString *originalFamilyName = %orig;
    
    if (!isSpoofingEnabled()) {
        return originalFamilyName;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalFamilyName;
    }
    
    NSString *gpuFamily = specs[@"gpuFamily"];
    if (!gpuFamily) {
        return originalFamilyName;
    }
    
    // Log the change the first time
    static BOOL loggedGPUFamilyName = NO;
    if (!loggedGPUFamilyName) {
        PXLog(@"[DeviceSpec] Spoofing GPU family name from '%@' to '%@'", originalFamilyName, gpuFamily);
        loggedGPUFamilyName = YES;
    }
    
    return gpuFamily;
}

%end

#pragma mark - Screen Density (DPI) Hooks

%hook UIScreen

// Keep nativeScale aligned with scale when UI scale spoofing is enabled.
- (CGFloat)nativeScale {
    CGFloat original = %orig;

    if (!isSpoofingEnabled() || !PXDisplayUIScaleSpoofEnabled() || !shouldSpoofResolutionForCurrentProcess()) {
        return original;
    }

    NSDictionary *specs = getDeviceSpecs();
    if (!specs) return original;

    CGFloat pixelRatio = [specs[@"devicePixelRatio"] floatValue];
    if (pixelRatio <= 0) return original;

    return pixelRatio;
}

// For screen density
- (CGFloat)native_scale {
    CGFloat originalScale = %orig;
    
    // Avoid spoofing screen density in Safari/Auth stack; it can desync page layout/touch logic.
    if (!isSpoofingEnabled() || !PXDisplayUIScaleSpoofEnabled() || !shouldSpoofResolutionForCurrentProcess()) {
        return originalScale;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return originalScale;
    }
    
    // Calculate from screen density (PPI)
    NSInteger screenDensity = [specs[@"screenDensity"] integerValue];
    if (screenDensity <= 0) {
        return originalScale;
    }
    
    // iPhone reference point is 163 PPI for scale 1.0
    CGFloat spoofedScale = screenDensity / 163.0;
    
    // Log the change the first time
    static BOOL loggedNativeScale = NO;
    if (!loggedNativeScale) {
        PXLog(@"[DeviceSpec] Spoofing native scale from %.2f to %.2f (density: %ld PPI)",
             originalScale, spoofedScale, (long)screenDensity);
        loggedNativeScale = YES;
    }
    
    return spoofedScale;
}

%end

#pragma mark - Notification Handlers

// Handler for notification to refresh caches
static void refreshCaches(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSString *notificationName = (__bridge NSString *)name;
    PXLog(@"[DeviceSpec] Received notification: %@, refreshing caches", notificationName);
    
    @synchronized(deviceSpecsCache) {
        [deviceSpecsCache removeAllObjects];
        cachedDeviceModel = nil;
        cacheTimestamp = nil;
    }
    
    @synchronized(cachedBundleDecisions) {
        [cachedBundleDecisions removeAllObjects];
    }
}

#pragma mark - CPU Core Spoofing Enhancements

// JavaScript hardwareConcurrency is installed through the shared document-start
// WKUserScript path. Keep only lower-level native CPU detection hooks here.

// Hook lower-level CPU detection APIs for native apps
%hook host_basic_info

- (unsigned int)max_cpus {
    unsigned int original = %orig;
    
    if (!isSpoofingEnabled()) {
        return original;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return original;
    }
    
    NSInteger cpuCoreCount = [specs[@"cpuCoreCount"] integerValue];
    if (cpuCoreCount <= 0) {
        return original;
    }
    
    static BOOL loggedCoreAPI = NO;
    if (!loggedCoreAPI) {
        PXLog(@"[DeviceSpec] Spoofing low-level CPU API from %u to %ld", original, (long)cpuCoreCount);
        loggedCoreAPI = YES;
    }
    
    return (unsigned int)cpuCoreCount;
}

%end

#pragma mark - Constructor

%ctor {
    @autoreleasepool {
        @try {
            PXFileDebugAIDA64Log("[DeviceSpec.ctor] enter");
            PXLog(@"[DeviceSpec] Initializing device specifications spoofing hooks");
            
            NSString *currentBundleID = getCurrentBundleID();
            
            // Skip if we can't get bundle ID
            if (!currentBundleID || [currentBundleID length] == 0) {
                return;
            }
            
            // Don't hook our own apps
            if ([currentBundleID isEqualToString:@"com.hydra.projectx"] ||
                [currentBundleID isEqualToString:@"com.hydra.weaponx"]) {
                return;
            }

            NSString *proc = [NSProcessInfo processInfo].processName;
            if (PXIsWebKitHelperProcess(currentBundleID, proc)) {
                PXFileDebugAIDA64Log("[DeviceSpec.ctor] skip WebKit helper bundle=%s", currentBundleID.UTF8String ?: "<nil>");
                return;
            }
            BOOL allowed = PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack);
            PXFileDebugAIDA64Log("[DeviceSpec.ctor] scope allowed=%d bundle=%s", allowed, currentBundleID.UTF8String ?: "<nil>");
            if (!allowed) {
                PXLog(@"[DeviceSpec] App %@ is not scoped, skipping hook installation", currentBundleID);
                return;
            }
            
            // Always initialize caches
            deviceSpecsCache = [NSMutableDictionary dictionary];
            cachedBundleDecisions = [NSMutableDictionary dictionary];
            
            // Register for notifications to refresh caches
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                refreshCaches,
                CFSTR("com.hydra.projectx.profileChanged"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
            
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                refreshCaches,
                CFSTR("com.hydra.projectx.settings.changed"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
            
            PXLog(@"[DeviceSpec] App %@ is scoped, installing device specification hooks", currentBundleID);

            // sysctlbyname is owned by PXNativeHookCoordinator. DeviceSpec participates as a
            // post-provider so the original syscall is executed exactly once and identity
            // pre-providers (Tweak/BootTime/UUID) retain first right of refusal.
            PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
            [coord installOwnedSymbolsIfNeeded];
            static dispatch_once_t deviceSpecSysctlProviderOnce;
            dispatch_once(&deviceSpecSysctlProviderOnce, ^{
                BOOL registered = [coord registerSysctlBynameProvider:@"devicespec.sysctlbyname"
                                                              priority:PXNativeHookPriorityIdentity
                                                                   pre:nil
                                                                  post:^(const char *name,
                                                                         void *oldp,
                                                                         size_t *oldlenp,
                                                                         void *newp,
                                                                         size_t newlen,
                                                                         int *inoutResult) {
                    if (!inoutResult) return;
                    *inoutResult = applyDeviceSpecSysctlBynamePost(name,
                                                                  oldp,
                                                                  oldlenp,
                                                                  newp,
                                                                  newlen,
                                                                  *inoutResult);
                }];
                PXLog(@"[DeviceSpec] sysctlbyname coordinator post-provider %@",
                      registered ? @"registered" : @"registration failed");
            });
            
            // Initialize memory hook function pointers for scoped apps only
            PXFileDebugAIDA64Log("[DeviceSpec.ctor] before dlopen libSystem");
            void *libSystem = dlopen("/usr/lib/libSystem.dylib", RTLD_NOW);
            PXFileDebugAIDA64Log("[DeviceSpec.ctor] after dlopen libSystem handle=%d", libSystem ? 1 : 0);
            if (libSystem) {
                // Hook host_statistics64 for VM stats spoofing
                orig_host_statistics64 = dlsym(libSystem, "host_statistics64");
                if (orig_host_statistics64) {
                    PXFileDebugAIDA64Log("[DeviceSpec.ctor] before hook host_statistics64");
                    MSHookFunction(orig_host_statistics64, (void *)hook_host_statistics64, (void **)&orig_host_statistics64);
                    PXFileDebugAIDA64Log("[DeviceSpec.ctor] after hook host_statistics64");
                    PXLog(@"[DeviceSpec] Successfully hooked host_statistics64 for memory stats spoofing");
                }
                
                // Hook NXGetLocalArchInfo for CPU architecture spoofing
                orig_nx_get_local_arch_info = dlsym(libSystem, "NXGetLocalArchInfo");
                if (orig_nx_get_local_arch_info) {
                    PXFileDebugAIDA64Log("[DeviceSpec.ctor] before hook NXGetLocalArchInfo");
                    MSHookFunction(orig_nx_get_local_arch_info, (void *)hook_nx_get_local_arch_info, (void **)&orig_nx_get_local_arch_info);
                    PXFileDebugAIDA64Log("[DeviceSpec.ctor] after hook NXGetLocalArchInfo");
                    PXLog(@"[DeviceSpec] Successfully hooked NXGetLocalArchInfo for CPU architecture spoofing");
                }
                
                dlclose(libSystem);
                PXFileDebugAIDA64Log("[DeviceSpec.ctor] after dlclose libSystem");
            }
            
            // Initialize Objective-C hooks for scoped apps only
            PXFileDebugAIDA64Log("[DeviceSpec.ctor] before %%init");
            %init();
            PXFileDebugAIDA64Log("[DeviceSpec.ctor] after %%init");
            
            PXLog(@"[DeviceSpec] Device specification hooks successfully initialized for scoped app: %@", currentBundleID);
            PXFileDebugAIDA64Log("[DeviceSpec.ctor] exit");
            
        } @catch (NSException *e) {
            PXFileDebugAIDA64Log("[DeviceSpec.ctor] exception=%s", e.description.UTF8String ?: "<nil>");
            PXLog(@"[DeviceSpec] ❌ Exception in constructor: %@", e);
        }
    }
}

// Helper for logging memory hook invocations only once
static void logMemoryHook(NSString *apiName) {
    if (!hookedMemoryAPIs) {
        hookedMemoryAPIs = [NSMutableSet set];
    }
    
    if (![hookedMemoryAPIs containsObject:apiName]) {
        [hookedMemoryAPIs addObject:apiName];
        PXLog(@"[DeviceSpec] Memory spoofing API '%@' was accessed", apiName);
    }
}

// Function to calculate free memory percentage based on device specs
static float getFreeMemoryPercentage(void) {
    // Default free memory percentage (typical for iOS devices under normal usage)
    float defaultFreePercentage = 0.35; // 35% free
    
    // Check if spoofing is enabled
    if (!isSpoofingEnabled()) {
        return defaultFreePercentage;
    }
    
    // Get device specs
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return defaultFreePercentage;
    }
    
    // If we have a specific free memory percentage in specs, use it
    NSNumber *freeMemoryPercent = specs[@"freeMemoryPercentage"];
    if (freeMemoryPercent) {
        float percentage = [freeMemoryPercent floatValue];
        // Validate the percentage is reasonable
        if (percentage > 0.1 && percentage < 0.7) {
            return percentage;
        }
    }
    
    // Otherwise use a realistic value based on device memory
    NSInteger deviceMemoryGB = [specs[@"deviceMemory"] integerValue];
    if (deviceMemoryGB <= 0) {
        return defaultFreePercentage;
    }
    
    // Larger memory devices typically have higher free percentage
    if (deviceMemoryGB >= 6) {
        return 0.45; // 45% free for 6GB+ devices
    } else if (deviceMemoryGB >= 4) {
        return 0.40; // 40% free for 4GB devices
    } else if (deviceMemoryGB >= 3) {
        return 0.35; // 35% free for 3GB devices
    } else {
        return 0.30; // 30% free for smaller memory devices
    }
}

// Function to get consistent free/wired/active memory values based on total memory
static void getConsistentMemoryStats(unsigned long long totalMemory, 
                                    unsigned long long *freeMemory,
                                    unsigned long long *wiredMemory,
                                    unsigned long long *activeMemory,
                                    unsigned long long *inactiveMemory) {
    
    float freePercentage = getFreeMemoryPercentage();
    freePercentage = MAX(0.0f, MIN(1.0f, freePercentage));

    float wiredPercentage = 0.20f; // 20% wired (kernel, system)
    float activePercentage = 0.30f; // 30% active (running apps)
    float remainingPercentage = MAX(0.0f, 1.0f - freePercentage);
    float committedPercentage = wiredPercentage + activePercentage;

    // Keep all buckets non-negative and ensure their total never exceeds RAM.
    if (committedPercentage > remainingPercentage && committedPercentage > 0.0f) {
        float scale = remainingPercentage / committedPercentage;
        wiredPercentage *= scale;
        activePercentage *= scale;
    }

    float inactivePercentage = MAX(0.0f,
        1.0f - freePercentage - wiredPercentage - activePercentage);
    
    if (freeMemory) {
        *freeMemory = (unsigned long long)(totalMemory * freePercentage);
    }
    
    if (wiredMemory) {
        *wiredMemory = (unsigned long long)(totalMemory * wiredPercentage);
    }
    
    if (activeMemory) {
        *activeMemory = (unsigned long long)(totalMemory * activePercentage);
    }
    
    if (inactiveMemory) {
        *inactiveMemory = (unsigned long long)(totalMemory * inactivePercentage);
    }
}

// NXGetLocalArchInfo hook for CPU architecture spoofing
static NXArchInfo* hook_nx_get_local_arch_info() {
    if (!orig_nx_get_local_arch_info) {
        return NULL;
    }
    
    NXArchInfo* original = orig_nx_get_local_arch_info();
    if (!original) {
        return NULL;
    }
    
    if (!isSpoofingEnabled()) {
        return original;
    }
    
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return original;
    }
    
    NSString *cpuArchitecture = specs[@"cpuArchitecture"];
    if (!cpuArchitecture || cpuArchitecture.length == 0) {
        return original;
    }
    
    // Create new struct to check, don't modify original
    static NXArchInfo customArchInfo;
    customArchInfo = *original; // Copy original values
    
    // NXArchInfo reports ARM ABI subtype, not a synthetic per-chip sequence.
    BOOL isLegacyARM64 = PXCPUArchitectureHasToken(cpuArchitecture, @"A9") ||
                        PXCPUArchitectureHasToken(cpuArchitecture, @"A10") ||
                        PXCPUArchitectureHasToken(cpuArchitecture, @"A11");
    BOOL isARM64E = PXCPUArchitectureHasToken(cpuArchitecture, @"A12") ||
                    PXCPUArchitectureHasToken(cpuArchitecture, @"A13") ||
                    PXCPUArchitectureHasToken(cpuArchitecture, @"A14") ||
                    PXCPUArchitectureHasToken(cpuArchitecture, @"A15") ||
                    PXCPUArchitectureHasToken(cpuArchitecture, @"A16") ||
                    PXCPUArchitectureHasToken(cpuArchitecture, @"A17") ||
                    PXCPUArchitectureHasToken(cpuArchitecture, @"A18") ||
                    PXCPUArchitectureHasToken(cpuArchitecture, @"M1") ||
                    PXCPUArchitectureHasToken(cpuArchitecture, @"M2");

    cpu_subtype_t cpuSubtype = original->cpusubtype;
    const char *customDescription = original->description;
    if (isARM64E) {
        cpuSubtype = CPU_SUBTYPE_ARM64E;
        customDescription = "ARM64E";
    } else if (isLegacyARM64) {
        cpuSubtype = CPU_SUBTYPE_ARM64_V8;
        customDescription = "ARM64";
    }
    
    customArchInfo.cpusubtype = cpuSubtype;
    customArchInfo.description = customDescription;
    
    static BOOL loggedArchInfo = NO;
    if (!loggedArchInfo) {
        PXLog(@"[DeviceSpec] Spoofing NXArchInfo: cpusubtype %d->%d, description %s->%s", 
              original->cpusubtype, cpuSubtype, original->description, customDescription);
        loggedArchInfo = YES;
    }
    
    return &customArchInfo;
}

// Host statistics hook for memory stats
static kern_return_t hook_host_statistics64(host_t host, host_flavor_t flavor, host_info64_t info, mach_msg_type_number_t *count) {
    // Call original function first
    kern_return_t result = orig_host_statistics64(host, flavor, info, count);
    
    // Check if we should modify the result
    if (result != KERN_SUCCESS || !info || !isSpoofingEnabled()) {
        return result;
    }
    
    // Get device specs
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return result;
    }
    
    // Get the device memory from specs (in GB)
    NSInteger deviceMemoryGB = [specs[@"deviceMemory"] integerValue];
    if (deviceMemoryGB <= 0) {
        return result;
    }
    
    // Calculate total memory in bytes
    unsigned long long totalMemory = ((unsigned long long)deviceMemoryGB) * 1024ULL * 1024ULL * 1024ULL;
    
    // Handle specific host info types
    if (flavor == HOST_VM_INFO64 || flavor == HOST_VM_INFO) {
        // VM statistics (free memory, etc.)
        if (flavor == HOST_VM_INFO64 && *count >= HOST_VM_INFO64_COUNT) {
            vm_statistics64_data_t *vmStats = (vm_statistics64_data_t *)info;
            
            // Calculate consistent memory values
            unsigned long long freeMemory, wiredMemory, activeMemory, inactiveMemory;
            getConsistentMemoryStats(totalMemory, &freeMemory, &wiredMemory, &activeMemory, &inactiveMemory);
            
            // page size is typically 4096 or 16384 depending on device
            vm_size_t pageSize = 4096;
            host_page_size(host, &pageSize);
            
            // Convert bytes to pages
            uint64_t freePages = freeMemory / pageSize;
            uint64_t wiredPages = wiredMemory / pageSize;
            uint64_t activePages = activeMemory / pageSize;
            uint64_t inactivePages = inactiveMemory / pageSize;
            
            // Update stats consistently
            vmStats->free_count = freePages;
            vmStats->wire_count = wiredPages;
            vmStats->active_count = activePages;
            vmStats->inactive_count = inactivePages;
            
            // Log the change the first time
            static BOOL loggedVMStats = NO;
            if (!loggedVMStats) {
                PXLog(@"[DeviceSpec] Spoofed vm_statistics64 with %llu free pages (%.1f%% of total memory)",
                    freePages, (float)freeMemory * 100.0 / totalMemory);
                loggedVMStats = YES;
            }
        } else if (flavor == HOST_VM_INFO && *count >= HOST_VM_INFO_COUNT) {
            vm_statistics_data_t *vmStats = (vm_statistics_data_t *)info;
            
            // Calculate consistent memory values
            unsigned long long freeMemory, wiredMemory, activeMemory, inactiveMemory;
            getConsistentMemoryStats(totalMemory, &freeMemory, &wiredMemory, &activeMemory, &inactiveMemory);
            
            // page size is typically 4096 or 16384 depending on device
            vm_size_t pageSize = 4096;
            host_page_size(host, &pageSize);
            
            // Convert bytes to pages
            unsigned int freePages = (unsigned int)(freeMemory / pageSize);
            unsigned int wiredPages = (unsigned int)(wiredMemory / pageSize);
            unsigned int activePages = (unsigned int)(activeMemory / pageSize);
            unsigned int inactivePages = (unsigned int)(inactiveMemory / pageSize);
            
            // Update stats consistently
            vmStats->free_count = freePages;
            vmStats->wire_count = wiredPages;
            vmStats->active_count = activePages;
            vmStats->inactive_count = inactivePages;
            
            // Log the change the first time
            static BOOL loggedVMStats32 = NO;
            if (!loggedVMStats32) {
                PXLog(@"[DeviceSpec] Spoofed vm_statistics with %u free pages (%.1f%% of total memory)",
                    freePages, (float)freeMemory * 100.0 / totalMemory);
                loggedVMStats32 = YES;
            }
        }
    } else if (flavor == HOST_BASIC_INFO) {
        // Basic host info including memory size
        if (*count >= HOST_BASIC_INFO_COUNT) {
            host_basic_info_t basicInfo = (host_basic_info_t)info;
            
            // Spoof max memory to match our deviceMemory value
            basicInfo->max_mem = totalMemory;
            
            // Log the change the first time
            static BOOL loggedBasicInfo = NO;
            if (!loggedBasicInfo) {
                PXLog(@"[DeviceSpec] Spoofed host_basic_info max_mem to %llu bytes (%ld GB)",
                    totalMemory, (long)deviceMemoryGB);
                loggedBasicInfo = YES;
            }
        }
    }
    
    return result;
}

// Coordinator post-provider for device-spec sysctlbyname values.
// The coordinator has already called the real sysctlbyname exactly once.
static int applyDeviceSpecSysctlBynamePost(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen, int originalResult) {
    static int loggedCount = 0;
    if (name && loggedCount < 40) {
        loggedCount++;
        PXFileDebugAIDA64Log("[DeviceSpec.sysctlbyname] key=%s oldp=%d oldlenp=%d", name, oldp ? 1 : 0, oldlenp ? 1 : 0);
    }
    // The coordinator already called the original function before invoking post-providers.
    int result = originalResult;
    if (!name || newp != NULL || newlen != 0) {
        return result;
    }

    // iOS version/build consistency (AIDA64 build number)
    // Handle these early and preserve sysctl size-query semantics (oldp can be NULL).
    if (name && oldlenp && (strcmp(name, "kern.osversion") == 0 || strcmp(name, "kern.osrelease") == 0 || strcmp(name, "kern.version") == 0)) {
        @try {
            IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            NSString *proc = [NSProcessInfo processInfo].processName;
            if (manager && bundleID && PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack) && [manager isIdentifierEnabled:@"IOSVersion"]) {
                NSString *identityDir = [manager profileIdentityPath];
                NSDictionary *deviceIds = identityDir.length > 0 ? [NSDictionary dictionaryWithContentsOfFile:[identityDir stringByAppendingPathComponent:@"device_ids.plist"]] : nil;
                NSDictionary *current = [[IOSVersionInfo sharedManager] currentIOSVersionInfo];
                NSString *value = nil;

                if (strcmp(name, "kern.osversion") == 0) {
                    value = deviceIds[@"IOSBuild"] ?: current[@"build"];
                } else if (strcmp(name, "kern.osrelease") == 0) {
                    value = deviceIds[@"Darwin"] ?: current[@"darwin"];
                } else if (strcmp(name, "kern.version") == 0) {
                    value = deviceIds[@"KernelVersion"] ?: current[@"kernel_version"];
                }

                if (value.length > 0) {
                    const char *s = [value UTF8String];
                    if (s) {
                        size_t len = strlen(s) + 1;

                        // Size query: oldp can be NULL in normal sysctlbyname usage.
                        if (!oldp && oldlenp) {
                            *oldlenp = len;
                            return 0;
                        }

                        if (oldp && oldlenp) {
                            if (*oldlenp >= len) {
                                *oldlenp = len;
                                memset(oldp, 0, len);
                                strcpy((char *)oldp, s);
                                return 0;
                            }

                            // Buffer too small: report required size and preserve sysctl errno semantics.
                            *oldlenp = len;
                            errno = ENOMEM;
                            return -1;
                        }
                    }
                }
            }
        } @catch (NSException *e) {
            // Fall through to other spoofing logic
        }
    }

    // Return original result if conditions not met for the remaining spec/memory spoofing
    if (result != 0 || !name || !oldlenp || !isSpoofingEnabled() || !oldp || *oldlenp == 0) {
        return result;
    }
    
    // Get device specs
    NSDictionary *specs = getDeviceSpecs();
    if (!specs) {
        return result;
    }
    
    // Get CPU architecture for processor-related sysctls
    NSString *cpuArchitecture = specs[@"cpuArchitecture"];
    NSInteger cpuCoreCount = [specs[@"cpuCoreCount"] integerValue];
    
    // Handle CPU-related sysctls
    if (strcmp(name, "hw.ncpu") == 0 || strcmp(name, "hw.activecpu") == 0) {
        // Number of CPUs / Active CPUs
        if (cpuCoreCount > 0) {
            if (*oldlenp == sizeof(uint32_t)) {
                *(uint32_t *)oldp = (uint32_t)cpuCoreCount;
            } else if (*oldlenp == sizeof(int)) {
                *(int *)oldp = (int)cpuCoreCount;
            } else if (*oldlenp == sizeof(unsigned long)) {
                *(unsigned long *)oldp = (unsigned long)cpuCoreCount;
            }
            
            static BOOL loggedCPUCount = NO;
            if (!loggedCPUCount) {
                PXLog(@"[DeviceSpec] Spoofed %s to %ld cores", name, (long)cpuCoreCount);
                loggedCPUCount = YES;
            }
        }
    }
    else if (strcmp(name, "hw.cpu.brand_string") == 0 || strcmp(name, "machdep.cpu.brand_string") == 0 || strcmp(name, "hw.cpubrand") == 0) {
        // CPU Brand/Model Name - return the processor name like "Apple A11 Bionic"
        if (cpuArchitecture && cpuArchitecture.length > 0) {
            const char *cpuBrand = [cpuArchitecture UTF8String];
            if (cpuBrand && *oldlenp > 0) {
                size_t brandLen = strlen(cpuBrand);
                if (brandLen < *oldlenp) {
                    *oldlenp = brandLen + 1;
                    memset(oldp, 0, *oldlenp);
                    strcpy(oldp, cpuBrand);
                    
                    static BOOL loggedCPUBrand = NO;
                    if (!loggedCPUBrand) {
                        PXLog(@"[DeviceSpec] Spoofed %s to '%s'", name, cpuBrand);
                        loggedCPUBrand = YES;
                    }
                } else {
                    PXLog(@"[DeviceSpec] WARNING: CPU brand string too long for buffer");
                }
            }
        }
    }
    else if (strcmp(name, "hw.model") == 0) {
        // Hardware model / board-id style string (e.g. N71AP / D431AP)
        NSString *hwModel = specs[@"hwModel"];
        if (!hwModel.length) {
            hwModel = specs[@"boardID"];
        }

        if (hwModel.length > 0) {
            const char *hwModelStr = [hwModel UTF8String];
            if (hwModelStr && *oldlenp > 0) {
                size_t hwModelLen = strlen(hwModelStr);
                if (hwModelLen < *oldlenp) {
                    *oldlenp = hwModelLen + 1;
                    memset(oldp, 0, *oldlenp);
                    strcpy((char *)oldp, hwModelStr);

                    static BOOL loggedHWModel = NO;
                    if (!loggedHWModel) {
                        PXLog(@"[DeviceSpec] Spoofed hw.model to '%s'", hwModelStr);
                        loggedHWModel = YES;
                    }
                } else {
                    PXLog(@"[DeviceSpec] WARNING: hw.model string too long for buffer");
                }
            }
        }
    }
    else if (strcmp(name, "hw.cputype") == 0) {
        // CPU Type - ARM64 is already defined as CPU_TYPE_ARM64 in system headers
        if (*oldlenp >= sizeof(uint32_t)) {
            *(uint32_t *)oldp = CPU_TYPE_ARM64;
            
            static BOOL loggedCPUType = NO;
            if (!loggedCPUType) {
                PXLog(@"[DeviceSpec] Spoofed hw.cputype to ARM64 (0x%X)", (uint32_t)CPU_TYPE_ARM64);
                loggedCPUType = YES;
            }
        }
    }
    else if (strcmp(name, "hw.cpusubtype") == 0) {
        // ARM64 sysctl exposes ABI subtypes, not one synthetic value per SoC.
        BOOL isLegacyARM64 = PXCPUArchitectureHasToken(cpuArchitecture, @"A9") ||
                            PXCPUArchitectureHasToken(cpuArchitecture, @"A10") ||
                            PXCPUArchitectureHasToken(cpuArchitecture, @"A11");
        BOOL isARM64E = PXCPUArchitectureHasToken(cpuArchitecture, @"A12") ||
                        PXCPUArchitectureHasToken(cpuArchitecture, @"A13") ||
                        PXCPUArchitectureHasToken(cpuArchitecture, @"A14") ||
                        PXCPUArchitectureHasToken(cpuArchitecture, @"A15") ||
                        PXCPUArchitectureHasToken(cpuArchitecture, @"A16") ||
                        PXCPUArchitectureHasToken(cpuArchitecture, @"A17") ||
                        PXCPUArchitectureHasToken(cpuArchitecture, @"A18") ||
                        PXCPUArchitectureHasToken(cpuArchitecture, @"M1") ||
                        PXCPUArchitectureHasToken(cpuArchitecture, @"M2");

        uint32_t cpuSubtype = isARM64E ? (uint32_t)CPU_SUBTYPE_ARM64E :
                              (isLegacyARM64 ? (uint32_t)CPU_SUBTYPE_ARM64_V8 : 0);
        if (cpuSubtype != 0 && *oldlenp >= sizeof(uint32_t)) {
            *(uint32_t *)oldp = cpuSubtype;

            static BOOL loggedCPUSubtype = NO;
            if (!loggedCPUSubtype) {
                PXLog(@"[DeviceSpec] Spoofed hw.cpusubtype to %u for %@", cpuSubtype, cpuArchitecture);
                loggedCPUSubtype = YES;
            }
        }
    }
    else if (strcmp(name, "hw.cpufamily") == 0) {
        // CPU family identifies the Apple core microarchitecture; related SoCs may share it.
        uint32_t cpuFamily = 0;

        if (PXCPUArchitectureHasToken(cpuArchitecture, @"A9")) {
            cpuFamily = 0x92FB37C8; // Twister
        } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A10")) {
            cpuFamily = 0x67CEEE93; // Hurricane
        } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A11")) {
            cpuFamily = 0xE81E7EF6; // Monsoon / Mistral
        } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A12")) {
            cpuFamily = 0x07D34B9F; // Vortex / Tempest (A12/A12X/A12Z)
        } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A13")) {
            cpuFamily = 0x462504D2; // Lightning / Thunder
        } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A14") ||
                   PXCPUArchitectureHasToken(cpuArchitecture, @"M1")) {
            cpuFamily = 0x1B588BB3; // Firestorm / Icestorm
        } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A15") ||
                   PXCPUArchitectureHasToken(cpuArchitecture, @"M2")) {
            cpuFamily = 0xDA33D83D; // Avalanche / Blizzard
        } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A16")) {
            cpuFamily = 0x8765EDEA; // Everest / Sawtooth
        } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A17")) {
            cpuFamily = 0x2876F5B5; // Coll
        } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A18")) {
            BOOL isPro = [cpuArchitecture rangeOfString:@"PRO" options:NSCaseInsensitiveSearch].location != NSNotFound;
            cpuFamily = isPro ? 0x75D4ACB9 : 0x204526D0; // Tahiti / Tupai
        }
        
        if (cpuFamily != 0 && *oldlenp >= sizeof(uint32_t)) {
            *(uint32_t *)oldp = cpuFamily;
            
            static BOOL loggedCPUFamily = NO;
            if (!loggedCPUFamily) {
                PXLog(@"[DeviceSpec] Spoofed hw.cpufamily to 0x%X for %@", cpuFamily, cpuArchitecture);
                loggedCPUFamily = YES;
            }
        }
    }
    else if (strcmp(name, "hw.cpufrequency") == 0 || strcmp(name, "hw.cpufrequency_max") == 0 || strcmp(name, "hw.cpufrequency_min") == 0) {
        // CPU Frequency - approximate values based on processor
        uint64_t cpuFrequency = 0;
        
        if (cpuArchitecture) {
            if (PXCPUArchitectureHasToken(cpuArchitecture, @"A9")) {
                cpuFrequency = 1800000000; // 1.8 GHz
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A10")) {
                cpuFrequency = 2340000000; // 2.34 GHz
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A11")) {
                cpuFrequency = 2390000000; // 2.39 GHz
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A12")) {
                cpuFrequency = 2490000000; // 2.49 GHz
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A13")) {
                cpuFrequency = 2650000000; // 2.65 GHz
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A14")) {
                cpuFrequency = 2990000000; // 2.99 GHz
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A15")) {
                cpuFrequency = 3230000000; // 3.23 GHz
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A16")) {
                cpuFrequency = 3460000000; // 3.46 GHz
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A17")) {
                cpuFrequency = 3780000000; // 3.78 GHz
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A18")) {
                cpuFrequency = 4050000000; // 4.05 GHz
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"M1")) {
                cpuFrequency = 3200000000; // 3.2 GHz
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"M2")) {
                cpuFrequency = 3490000000; // 3.49 GHz
            } else {
                cpuFrequency = 2000000000; // Default 2.0 GHz
            }
            
            // Adjust for min/max variants
            if (strcmp(name, "hw.cpufrequency_min") == 0) {
                cpuFrequency = cpuFrequency * 0.4; // Min is typically 40% of max
            }
        }
        
        if (*oldlenp >= sizeof(uint64_t)) {
            *(uint64_t *)oldp = cpuFrequency;
        } else if (*oldlenp >= sizeof(uint32_t)) {
            *(uint32_t *)oldp = (uint32_t)cpuFrequency;
        }
        
        static BOOL loggedCPUFreq = NO;
        if (!loggedCPUFreq) {
            PXLog(@"[DeviceSpec] Spoofed %s to %.2f GHz for %@", name, cpuFrequency / 1000000000.0, cpuArchitecture);
            loggedCPUFreq = YES;
        }
    }
    else if (strcmp(name, "hw.cachelinesize") == 0) {
        // Cache line size - typically 64 bytes for ARM64
        uint32_t cacheLineSize = 64;
        
        if (*oldlenp >= sizeof(uint32_t)) {
            *(uint32_t *)oldp = cacheLineSize;
            
            static BOOL loggedCacheLineSize = NO;
            if (!loggedCacheLineSize) {
                PXLog(@"[DeviceSpec] Spoofed hw.cachelinesize to %u bytes", cacheLineSize);
                loggedCacheLineSize = YES;
            }
        }
    }
    else if (strcmp(name, "hw.l1icachesize") == 0 || strcmp(name, "hw.l1dcachesize") == 0 || 
             strcmp(name, "hw.l2cachesize") == 0) {
        // Cache sizes vary by processor
        uint32_t cacheSize = 0;
        
        if (cpuArchitecture) {
            BOOL isL1 = (strcmp(name, "hw.l1icachesize") == 0 || strcmp(name, "hw.l1dcachesize") == 0);
            BOOL isL2 = (strcmp(name, "hw.l2cachesize") == 0);
            
            if (PXCPUArchitectureHasToken(cpuArchitecture, @"A9")) {
                cacheSize = isL1 ? 32768 : (isL2 ? 3145728 : 0); // 32KB L1, 3MB L2
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A10")) {
                cacheSize = isL1 ? 32768 : (isL2 ? 3145728 : 0); // 32KB L1, 3MB L2  
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A11")) {
                cacheSize = isL1 ? 32768 : (isL2 ? 8388608 : 0); // 32KB L1, 8MB L2
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A12")) {
                cacheSize = isL1 ? 32768 : (isL2 ? 8388608 : 0); // 32KB L1, 8MB L2
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A13")) {
                cacheSize = isL1 ? 65536 : (isL2 ? 8388608 : 0); // 64KB L1, 8MB L2
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A14") || PXCPUArchitectureHasToken(cpuArchitecture, @"A15")) {
                cacheSize = isL1 ? 65536 : (isL2 ? 12582912 : 0); // 64KB L1, 12MB L2
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A16") || PXCPUArchitectureHasToken(cpuArchitecture, @"A17")) {
                cacheSize = isL1 ? 65536 : (isL2 ? 16777216 : 0); // 64KB L1, 16MB L2
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A18")) {
                cacheSize = isL1 ? 131072 : (isL2 ? 20971520 : 0); // 128KB L1, 20MB L2
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"M1")) {
                cacheSize = isL1 ? 131072 : (isL2 ? 12582912 : 0); // 128KB L1, 12MB L2
            } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"M2")) {
                cacheSize = isL1 ? 131072 : (isL2 ? 16777216 : 0); // 128KB L1, 16MB L2
            } else {
                cacheSize = isL1 ? 32768 : (isL2 ? 3145728 : 0); // Default
            }
        }
        
        if (*oldlenp >= sizeof(uint32_t) && cacheSize > 0) {
            *(uint32_t *)oldp = cacheSize;
            
            static NSMutableSet *loggedCacheSizes = nil;
            if (!loggedCacheSizes) {
                loggedCacheSizes = [NSMutableSet set];
            }
            
            if (![loggedCacheSizes containsObject:@(name)]) {
                [loggedCacheSizes addObject:@(name)];
                PXLog(@"[DeviceSpec] Spoofed %s to %u bytes for %@", name, cacheSize, cpuArchitecture);
            }
        }
    }
    // Handle memory-related sysctls
    else if (strcmp(name, "hw.memsize") == 0 || strcmp(name, "hw.physmem") == 0) {
        // Get the device memory from specs (in GB)
        NSInteger deviceMemoryGB = [specs[@"deviceMemory"] integerValue];
        if (deviceMemoryGB <= 0) {
            return result;
        }
        
        // Calculate total memory in bytes
        unsigned long long totalMemory = ((unsigned long long)deviceMemoryGB) * 1024ULL * 1024ULL * 1024ULL;
        
        // Different sysctls might return different size types
        if (*oldlenp == sizeof(uint64_t)) {
            *(uint64_t *)oldp = totalMemory;
        } else if (*oldlenp == sizeof(uint32_t)) {
            *(uint32_t *)oldp = (uint32_t)totalMemory;
        } else if (*oldlenp == sizeof(unsigned long)) {
            *(unsigned long *)oldp = (unsigned long)totalMemory;
        }
        
        // Log the change the first time
        static BOOL loggedMemSize = NO;
        if (!loggedMemSize) {
            PXLog(@"[DeviceSpec] Spoofed sysctlbyname %s to %llu bytes (%ld GB)",
                name, totalMemory, (long)deviceMemoryGB);
            loggedMemSize = YES;
        }
    } else if (strcmp(name, "vm.swapusage") == 0 && *oldlenp >= sizeof(xsw_usage)) {
        // Swap usage information
        xsw_usage *swap = (xsw_usage *)oldp;
        
        // Get the device memory from specs (in GB)
        NSInteger deviceMemoryGB = [specs[@"deviceMemory"] integerValue];
        if (deviceMemoryGB <= 0) {
            return result;
        }
        
        // Calculate realistic swap values based on device memory
        // iOS typically uses swap space proportional to RAM
        uint64_t totalMemory = ((unsigned long long)deviceMemoryGB) * 1024ULL * 1024ULL * 1024ULL;
        
        // Typical iOS swap is ~50-100% of RAM depending on device
        float swapRatio = (deviceMemoryGB >= 4) ? 0.5 : 1.0;  // Less swap on high-RAM devices
        
        swap->xsu_total = totalMemory * swapRatio;
        swap->xsu_avail = totalMemory * swapRatio * 0.7;  // 70% available
        swap->xsu_used = totalMemory * swapRatio * 0.3;   // 30% used
        
        // Log the change the first time
        static BOOL loggedSwap = NO;
        if (!loggedSwap) {
            PXLog(@"[DeviceSpec] Spoofed vm.swapusage to %llu total, %llu used, %llu available",
                swap->xsu_total, swap->xsu_used, swap->xsu_avail);
            loggedSwap = YES;
        }
    }
    // Add additional CPU feature and identification sysctls
    else if (strncmp(name, "hw.optional.", 12) == 0) {
        // Only override capabilities that are explicitly tied to the selected ABI.
        // Unknown optional keys retain the original result instead of defaulting to YES.
        BOOL isARM64EChip = PXCPUArchitectureHasToken(cpuArchitecture, @"A12") ||
                            PXCPUArchitectureHasToken(cpuArchitecture, @"A13") ||
                            PXCPUArchitectureHasToken(cpuArchitecture, @"A14") ||
                            PXCPUArchitectureHasToken(cpuArchitecture, @"A15") ||
                            PXCPUArchitectureHasToken(cpuArchitecture, @"A16") ||
                            PXCPUArchitectureHasToken(cpuArchitecture, @"A17") ||
                            PXCPUArchitectureHasToken(cpuArchitecture, @"A18") ||
                            PXCPUArchitectureHasToken(cpuArchitecture, @"M1") ||
                            PXCPUArchitectureHasToken(cpuArchitecture, @"M2");
        BOOL shouldOverride = strstr(name, "arm64e") != NULL || strstr(name, "armv8_3") != NULL;
        BOOL featureSupported = isARM64EChip;

        if (shouldOverride && *oldlenp >= sizeof(uint32_t)) {
            *(uint32_t *)oldp = featureSupported ? 1 : 0;

            static NSMutableSet *loggedOptionalFeatures = nil;
            static dispatch_once_t optionalFeatureLogOnce;
            dispatch_once(&optionalFeatureLogOnce, ^{
                loggedOptionalFeatures = [NSMutableSet set];
            });

            NSString *featureName = [NSString stringWithUTF8String:name];
            @synchronized(loggedOptionalFeatures) {
                if (![loggedOptionalFeatures containsObject:featureName]) {
                    [loggedOptionalFeatures addObject:featureName];
                    PXLog(@"[DeviceSpec] Spoofed %s to %d for %@", name, featureSupported ? 1 : 0, cpuArchitecture);
                }
            }
        }
    }
    else if (strcmp(name, "hw.machine") == 0) {
        // Machine name - should return the device model like "iPhone10,1"
        NSString *deviceModel = getSpoofedDeviceModel();
        if (deviceModel && deviceModel.length > 0) {
            const char *machineStr = [deviceModel UTF8String];
            if (machineStr && *oldlenp > 0) {
                size_t machineLen = strlen(machineStr);
                if (machineLen < *oldlenp) {
                    *oldlenp = machineLen + 1;
                    memset(oldp, 0, *oldlenp);
                    strcpy(oldp, machineStr);
                    
                    static BOOL loggedMachine = NO;
                    if (!loggedMachine) {
                        PXLog(@"[DeviceSpec] Spoofed hw.machine to '%s'", machineStr);
                        loggedMachine = YES;
                    }
                } else {
                    PXLog(@"[DeviceSpec] WARNING: Machine string too long for buffer");
                }
            }
        }
    }
    else if (strcmp(name, "hw.cpu.features") == 0) {
        // Never fall back to an x86 SSE/AVX feature string on ARM.
        NSString *cpuFeatures = nil;
        if (PXCPUArchitectureHasToken(cpuArchitecture, @"A17") ||
            PXCPUArchitectureHasToken(cpuArchitecture, @"A18") ||
            PXCPUArchitectureHasToken(cpuArchitecture, @"M1") ||
            PXCPUArchitectureHasToken(cpuArchitecture, @"M2")) {
            cpuFeatures = @"NEON AES SHA1 SHA2 CRC32 ATOMICS FP16 JSCVT FCMA LRCPC";
        } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A15") ||
                   PXCPUArchitectureHasToken(cpuArchitecture, @"A16")) {
            cpuFeatures = @"NEON AES SHA1 SHA2 CRC32 ATOMICS FP16 JSCVT";
        } else if (PXCPUArchitectureHasToken(cpuArchitecture, @"A9") ||
                   PXCPUArchitectureHasToken(cpuArchitecture, @"A10") ||
                   PXCPUArchitectureHasToken(cpuArchitecture, @"A11") ||
                   PXCPUArchitectureHasToken(cpuArchitecture, @"A12") ||
                   PXCPUArchitectureHasToken(cpuArchitecture, @"A13") ||
                   PXCPUArchitectureHasToken(cpuArchitecture, @"A14")) {
            cpuFeatures = @"NEON AES SHA1 SHA2 CRC32 ATOMICS";
        }
        
        const char *featuresStr = [cpuFeatures UTF8String];
        if (featuresStr && *oldlenp > 0) {
            size_t featuresLen = strlen(featuresStr);
            if (featuresLen < *oldlenp) {
                *oldlenp = featuresLen + 1;
                memset(oldp, 0, *oldlenp);
                strcpy(oldp, featuresStr);
                
                static BOOL loggedFeatures = NO;
                if (!loggedFeatures) {
                    PXLog(@"[DeviceSpec] Spoofed hw.cpu.features to '%s'", featuresStr);
                    loggedFeatures = YES;
                }
            }
        }
    }
    
    // Log any unhandled successful sysctl queries for debugging
    if (result == 0 && isSpoofingEnabled()) {
        static NSMutableSet *loggedIgnoredKeys = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            loggedIgnoredKeys = [NSMutableSet set];
        });
        
        @synchronized(loggedIgnoredKeys) {
            NSString *keyStr = [NSString stringWithUTF8String:name];
            if (![loggedIgnoredKeys containsObject:keyStr]) {
                [loggedIgnoredKeys addObject:keyStr];
                PXLog(@"[DeviceSpec DEBUG] Unhandled sysctl query: %s", name);
            }
        }
    }

    return result;
} 
