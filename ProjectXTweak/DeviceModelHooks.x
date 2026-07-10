#import "ProjectX.h"
#import "DeviceModelManager.h"
#import "IdentifierManager.h"
#import "ProjectXLogging.h"
#import "PXScope.h"
#import "PXFileDebug.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
// #import <ellekit/ellekit.h> // Removed for rootful - using Substrate

// Cache for device model values
static NSMutableDictionary *modelCache = nil;
static NSDate *cacheTimestamp = nil;

#pragma mark - Helper Functions

// Check if device model spoofing is enabled for the current app
static BOOL isDeviceModelSpoofingEnabled(void) {
    NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!currentBundleID) return NO;
    
    // Single source of truth: IdentifierManager settings + scope.
    BOOL shouldSpoof = NO;
    @try {
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (!PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack)) return NO;
        if (NSClassFromString(@"IdentifierManager")) {
            IdentifierManager *manager = [NSClassFromString(@"IdentifierManager") sharedManager];
            if (manager && [manager isIdentifierEnabled:@"DeviceModel"]) {
                shouldSpoof = YES;
            }
        }
    } @catch (__unused NSException *exception) {
        shouldSpoof = NO;
    }
    
    return shouldSpoof;
}

// Get the spoofed device model (machine id like iPhone15,3) from profile.
// Used only to derive the Apple product family for UIDevice.model / localizedModel.
static NSString* getSpoofedDeviceModel(void) {
    // Initialize cache if needed
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        modelCache = [NSMutableDictionary dictionary];
        cacheTimestamp = [NSDate date];
    });
    
    NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!currentBundleID) return nil;
    
    // Check cache first for consistency (per bundle ID)
    @synchronized(modelCache) {
        NSString *cachedModel = modelCache[currentBundleID];
        if (cachedModel && [[NSDate date] timeIntervalSinceDate:cacheTimestamp] < 300.0) {
            return cachedModel;
        }
    }
    
    NSString *deviceModel = nil;
    @try {
        // METHOD 0: Use IdentifierManager as the single source of truth
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
                NSString *identityDir = [[profilesPath stringByAppendingPathComponent:profileId] stringByAppendingPathComponent:@"identity"];
                NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:[identityDir stringByAppendingPathComponent:@"device_ids.plist"]];
                deviceModel = deviceIds[@"DeviceModel"];
            }
        }
        
        // METHOD 2: DeviceModelManager as last resort (do not generate here)
        if (!deviceModel.length && NSClassFromString(@"DeviceModelManager")) {
            DeviceModelManager *deviceManager = [NSClassFromString(@"DeviceModelManager") sharedManager];
            deviceModel = [deviceManager currentDeviceModel];
        }
        
        // If we got a model, cache it for this bundle ID
        if (deviceModel.length > 0) {
            @synchronized(modelCache) {
                modelCache[currentBundleID] = deviceModel;
                cacheTimestamp = [NSDate date];
            }
        }
        
        return deviceModel;
    } @catch (NSException *exception) {
        PXLog(@"[model] Exception getting spoofed device model: %@", exception);
        return nil;
    }
}

// Map machine id / model string to Apple UIDevice.model family name.
// UIDevice.model must NOT return machine identifiers like "iPhone15,3".
static NSString* mapDeviceModelToUIDeviceFamily(NSString *spoofedModel, NSString *original) {
    if (!spoofedModel.length) {
        return original;
    }
    
    if ([spoofedModel hasPrefix:@"iPhone"]) {
        return @"iPhone";
    }
    if ([spoofedModel hasPrefix:@"iPad"]) {
        return @"iPad";
    }
    if ([spoofedModel hasPrefix:@"iPod"]) {
        return @"iPod touch";
    }
    
    // Unknown prefix → keep original UIDevice value
    return original;
}

#pragma mark - Foundation UIDevice Hooks Only
// name / systemName / MGCopyAnswer / uname / sysctl / IOKit are owned by Tweak.x / other modules.
// NSDictionary dictionaryWithContentsOfURL was removed (not a device-model query surface).

%group DeviceModelFoundation

%hook UIDevice

- (NSString *)model {
    NSString *originalModel = %orig;
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    if (!bundleID) {
        return originalModel;
    }
    
    if (isDeviceModelSpoofingEnabled()) {
        NSString *spoofedModel = getSpoofedDeviceModel();
        NSString *family = mapDeviceModelToUIDeviceFamily(spoofedModel, originalModel);
        if (family && ![family isEqualToString:originalModel]) {
            PXLog(@"[model] Spoofing UIDevice model from %@ to %@ (machine=%@) for app: %@",
                  originalModel, family, spoofedModel ?: @"nil", bundleID);
            return family;
        }
    }
    
    return originalModel;
}

- (NSString *)localizedModel {
    NSString *originalModel = %orig;
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    if (!bundleID) {
        return originalModel;
    }
    
    // Same generic Apple product family as model; do not invent detailed localized names.
    if (isDeviceModelSpoofingEnabled()) {
        NSString *spoofedModel = getSpoofedDeviceModel();
        NSString *family = mapDeviceModelToUIDeviceFamily(spoofedModel, originalModel);
        if (family && ![family isEqualToString:originalModel]) {
            PXLog(@"[model] Spoofing UIDevice localizedModel from %@ to %@ (machine=%@) for app: %@",
                  originalModel, family, spoofedModel ?: @"nil", bundleID);
            return family;
        }
    }
    
    return originalModel;
}

%end

%end // %group DeviceModelFoundation

%ctor {
    @autoreleasepool {
        PXFileDebugAIDA64Log("[DeviceModel.ctor] enter");
        PXLog(@"[model] Initializing device model foundation hooks");
        
        // CRITICAL SAFETY CHECK: Only initialize hooks if we can get a valid bundle ID
        NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (!currentBundleID) {
            PXLog(@"[model] No bundle ID available, not initializing device model hooks");
            return;
        }
        
        IdentifierManager *manager = [%c(IdentifierManager) sharedManager];
        NSString *proc = [NSProcessInfo processInfo].processName;
        BOOL allowed = PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack);
        PXFileDebugAIDA64Log("[DeviceModel.ctor] scope allowed=%d bundle=%s", allowed, currentBundleID.UTF8String ?: "<nil>");
        if (!manager || !allowed) {
            PXLog(@"[model] App %@ is not enabled for spoofing, not initializing hooks", currentBundleID);
            return;
        }
        
        // Toggle: DeviceModel identifier must be enabled
        if (!isDeviceModelSpoofingEnabled()) {
            PXLog(@"[model] Device model spoofing not enabled for app %@, not initializing hooks", currentBundleID);
            return;
        }
        
        // Profile value must be available before installing hooks
        NSString *testModel = getSpoofedDeviceModel();
        if (!testModel.length) {
            PXLog(@"[model] WARNING: Could not retrieve spoofed model, not initializing hooks");
            return;
        }
        
        PXLog(@"[model] Successfully retrieved spoofed model: %@ — installing DeviceModelFoundation (UIDevice.model/localizedModel only)", testModel);
        PXFileDebugAIDA64Log("[DeviceModel.ctor] before %%init DeviceModelFoundation");
        %init(DeviceModelFoundation);
        PXFileDebugAIDA64Log("[DeviceModel.ctor] after %%init DeviceModelFoundation exit");
    }
}
