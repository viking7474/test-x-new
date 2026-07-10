#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "ProjectXLogging.h"
#import "HookOwnership.h"
#import "IdentifierManager.h"
#import "SystemUUIDManager.h"
#import "DyldCacheUUIDManager.h"
#import "PXScope.h"
#import "PXNativeHookCoordinator.h"
#import <dlfcn.h>
#import <substrate.h>
#import <mach-o/dyld.h>
#import <mach-o/dyld_images.h>
#import <IOKit/IOKitLib.h>
// #import <ellekit/ellekit.h> // Removed for rootful - using Substrate
#import <sys/sysctl.h>
#import <pthread.h>
#import <string.h>
#import <errno.h>

// Macro for iOS version checking
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

// Global variables to track state
static NSMutableDictionary *cachedBundleDecisions = nil;
static NSTimeInterval kCacheValidityDuration = 600.0; // 10 minutes for better performance
static dispatch_queue_t cacheQueue = nil; // Queue for thread-safe access to cache
static BOOL isInitialized = NO;

static BOOL isSystemBootUUIDEnabled(void);
static BOOL isDyldCacheUUIDEnabled(void);

// Callback function for notifications that clear the cache
static void clearCacheCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    if (!cacheQueue) return;
    // Clear cached decisions using the dispatch queue for thread safety
    dispatch_async(cacheQueue, ^{
        if (cachedBundleDecisions) {
            [cachedBundleDecisions removeAllObjects];
            PXLog(@"[WeaponX] 🧹 Cleared UUID hooks decision cache");
        }
    });
}

// Update the shouldSpoofForBundle function to directly check settings files
static BOOL shouldSpoofForBundle(NSString *bundleID) {
    if (!bundleID) return NO;
    NSString *proc = [NSProcessInfo processInfo].processName;
    if (!PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack)) return NO;
    return isSystemBootUUIDEnabled() || isDyldCacheUUIDEnabled();
}

// Direct check for SystemBootUUID being enabled
static BOOL isSystemBootUUIDEnabled(void) {
    // Check settings file directly
    NSArray *preferencesLocations = @[
        @"/var/mobile/Library/Preferences",
        @"/private/var/mobile/Library/Preferences",
        @"/var/mobile/Library/Preferences"
    ];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    for (NSString *prefsPath in preferencesLocations) {
        NSString *settingsPath = [prefsPath stringByAppendingPathComponent:@"com.hydra.projectx.settings.plist"];
        if ([fileManager fileExistsAtPath:settingsPath]) {
            NSDictionary *settingsDict = [NSDictionary dictionaryWithContentsOfFile:settingsPath];
            NSDictionary *enabledIdentifiers = settingsDict[@"EnabledIdentifiers"];
            
            if (enabledIdentifiers) {
                BOOL isEnabled = [enabledIdentifiers[@"SystemBootUUID"] boolValue];
                PXLog(@"[WeaponX] 🔍 SystemBootUUID enabled status from plist: %@", isEnabled ? @"YES" : @"NO");
                return isEnabled;
            }
        }
    }
    
    PXLog(@"[WeaponX] ⚠️ Could not find settings.plist file, assuming SystemBootUUID is disabled");
    return NO;
}

// Direct check for DyldCacheUUID being enabled
static BOOL isDyldCacheUUIDEnabled(void) {
    // Check settings file directly
    NSArray *preferencesLocations = @[
        @"/var/mobile/Library/Preferences",
        @"/private/var/mobile/Library/Preferences",
        @"/var/mobile/Library/Preferences"
    ];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    for (NSString *prefsPath in preferencesLocations) {
        NSString *settingsPath = [prefsPath stringByAppendingPathComponent:@"com.hydra.projectx.settings.plist"];
        if ([fileManager fileExistsAtPath:settingsPath]) {
            NSDictionary *settingsDict = [NSDictionary dictionaryWithContentsOfFile:settingsPath];
            NSDictionary *enabledIdentifiers = settingsDict[@"EnabledIdentifiers"];
            
            if (enabledIdentifiers) {
                BOOL isEnabled = [enabledIdentifiers[@"DyldCacheUUID"] boolValue];
                PXLog(@"[WeaponX] 🔍 DyldCacheUUID enabled status from plist: %@", isEnabled ? @"YES" : @"NO");
                return isEnabled;
            }
        }
    }
    
    PXLog(@"[WeaponX] ⚠️ Could not find settings.plist file, assuming DyldCacheUUID is disabled");
    return NO;
}

// Add functions to get spoofed UUIDs from managers
static NSString *getSpoofedSystemBootUUID() {
    @try {
        // Use the SystemUUIDManager for consistent values across the app and hooks
        SystemUUIDManager *manager = [SystemUUIDManager sharedManager];
        if (!manager) {
            // Generate a safer fallback if manager is unavailable
            return [[NSUUID UUID] UUIDString];
        }
        
        NSString *uuid = [manager currentBootUUID];
        
        // Validate UUID format
        if (uuid && uuid.length > 0 && ![uuid isEqualToString:@"(null)"]) {
            // Check if it's a valid UUID format (basic validation)
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$" 
                                                                                    options:NSRegularExpressionCaseInsensitive 
                                                                                      error:nil];
            if ([regex numberOfMatchesInString:uuid 
                                       options:0 
                                         range:NSMakeRange(0, uuid.length)] > 0) {
                return uuid;
            }
        }
        
        // Try to read directly from plist files
        IdentifierManager *idManager = [NSClassFromString(@"IdentifierManager") sharedManager];
        if (!idManager) {
            return [[NSUUID UUID] UUIDString];
        }
        
        NSString *identityDir = [idManager valueForKey:@"profileIdentityPath"];
        
        if (identityDir) {
            // First try the combined device_ids.plist
            NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
            NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
            NSString *value = deviceIds[@"SystemBootUUID"];
            
            if (value && value.length > 0 && ![value isEqualToString:@"(null)"]) {
                // Basic validation for UUID format
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$" 
                                                                                        options:NSRegularExpressionCaseInsensitive 
                                                                                          error:nil];
                if ([regex numberOfMatchesInString:value 
                                           options:0 
                                             range:NSMakeRange(0, value.length)] > 0) {
                    PXLog(@"[WeaponX] 🔄 Got SystemBootUUID from device_ids.plist: %@", value);
                    // Update the manager for future consistency
                    if ([manager respondsToSelector:@selector(setCurrentBootUUID:)]) {
                        [manager setCurrentBootUUID:value];
                    }
                    return value;
                }
            }
            
            // Try the specific uuid file
            NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"system_boot_uuid.plist"];
            NSDictionary *uuidDict = [NSDictionary dictionaryWithContentsOfFile:uuidPath];
            if (uuidDict && uuidDict[@"value"] && [uuidDict[@"value"] length] > 0 && ![uuidDict[@"value"] isEqualToString:@"(null)"]) {
                // Validate UUID format
                NSString *uuidValue = uuidDict[@"value"];
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$" 
                                                                                        options:NSRegularExpressionCaseInsensitive 
                                                                                          error:nil];
                if ([regex numberOfMatchesInString:uuidValue 
                                           options:0 
                                             range:NSMakeRange(0, uuidValue.length)] > 0) {
                    PXLog(@"[WeaponX] 🔄 Got SystemBootUUID from system_boot_uuid.plist: %@", uuidValue);
                    // Update the manager for future consistency
                    if ([manager respondsToSelector:@selector(setCurrentBootUUID:)]) {
                        [manager setCurrentBootUUID:uuidValue];
                    }
                    return uuidValue;
                }
            }
        }
        
        // If we still don't have a UUID, generate a new one rather than using zeros
        uuid = [[NSUUID UUID] UUIDString];
        PXLog(@"[WeaponX] 🔄 Generated fallback UUID: %@", uuid);
        
        // Store this for future consistency
        if ([manager respondsToSelector:@selector(setCurrentBootUUID:)]) {
            [manager setCurrentBootUUID:uuid];
        }
        
        return uuid;
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ❌ Exception in getSpoofedSystemBootUUID: %@", exception);
        return [[NSUUID UUID] UUIDString];
    }
}

static NSString *getSpoofedDyldCacheUUID() {
    @try {
        // Use the DyldCacheUUIDManager for consistent values across the app and hooks
        DyldCacheUUIDManager *manager = [DyldCacheUUIDManager sharedManager];
        if (!manager) {
            // Generate a safer fallback if manager is unavailable
            return [[NSUUID UUID] UUIDString];
        }
        
        NSString *uuid = [manager currentDyldCacheUUID];
        
        // Validate UUID format
        if (uuid && uuid.length > 0 && ![uuid isEqualToString:@"(null)"]) {
            // Check if it's a valid UUID format (basic validation)
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$" 
                                                                                    options:NSRegularExpressionCaseInsensitive 
                                                                                      error:nil];
            if ([regex numberOfMatchesInString:uuid 
                                       options:0 
                                         range:NSMakeRange(0, uuid.length)] > 0) {
                return uuid;
            }
        }
        
        // Try to read directly from plist files
        IdentifierManager *idManager = [NSClassFromString(@"IdentifierManager") sharedManager];
        if (!idManager) {
            return [[NSUUID UUID] UUIDString];
        }
        
        NSString *identityDir = [idManager valueForKey:@"profileIdentityPath"];
        
        if (identityDir) {
            // First try the combined device_ids.plist
            NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
            NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
            NSString *value = deviceIds[@"DyldCacheUUID"];
            
            if (value && value.length > 0 && ![value isEqualToString:@"(null)"]) {
                // Basic validation for UUID format
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$" 
                                                                                        options:NSRegularExpressionCaseInsensitive 
                                                                                          error:nil];
                if ([regex numberOfMatchesInString:value 
                                           options:0 
                                             range:NSMakeRange(0, value.length)] > 0) {
                    PXLog(@"[WeaponX] 🔄 Got DyldCacheUUID from device_ids.plist: %@", value);
                    // Update the manager for future consistency
                    if ([manager respondsToSelector:@selector(setCurrentDyldCacheUUID:)]) {
                        [manager setCurrentDyldCacheUUID:value];
                    }
                    return value;
                }
            }
            
            // Try the specific uuid file
            NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"dyld_cache_uuid.plist"];
            NSDictionary *uuidDict = [NSDictionary dictionaryWithContentsOfFile:uuidPath];
            if (uuidDict && uuidDict[@"value"] && [uuidDict[@"value"] length] > 0 && ![uuidDict[@"value"] isEqualToString:@"(null)"]) {
                // Validate UUID format
                NSString *uuidValue = uuidDict[@"value"];
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$" 
                                                                                        options:NSRegularExpressionCaseInsensitive 
                                                                                          error:nil];
                if ([regex numberOfMatchesInString:uuidValue 
                                           options:0 
                                             range:NSMakeRange(0, uuidValue.length)] > 0) {
                    PXLog(@"[WeaponX] 🔄 Got DyldCacheUUID from dyld_cache_uuid.plist: %@", uuidValue);
                    // Update the manager for future consistency
                    if ([manager respondsToSelector:@selector(setCurrentDyldCacheUUID:)]) {
                        [manager setCurrentDyldCacheUUID:uuidValue];
                    }
                    return uuidValue;
                }
            }
        }
        
        // If we still don't have a UUID, generate a new one rather than using zeros
        uuid = [[NSUUID UUID] UUIDString];
        PXLog(@"[WeaponX] 🔄 Generated fallback UUID: %@", uuid);
        
        // Store this for future consistency
        if ([manager respondsToSelector:@selector(setCurrentDyldCacheUUID:)]) {
            [manager setCurrentDyldCacheUUID:uuid];
        }
        
        return uuid;
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ❌ Exception in getSpoofedDyldCacheUUID: %@", exception);
        return [[NSUUID UUID] UUIDString];
    }
}

#pragma mark - Blanket UUID generation intentionally NOT hooked
// Per Newplan: do not hook CFUUIDCreate / +[NSUUID UUID] / UUIDString / description /
// initWithUUIDBytes. Generic UUID generation must remain unique. Keep only
// gethostuuid, kern.uuid, IOKit platform UUID and dyld cache UUID (via coordinator).

#pragma mark - IOKit Platform UUID (registered with PXNativeHookCoordinator)
// Legacy %hookf removed — identity IOKit transforms register via coordinator.

static BOOL PXUUID_IOKitHandled = NO;
static void PXUUIDRegisterIOKitProviders(void) {
    // Providers registered from ctor; actual install is coordinator-owned.
    (void)PXUUID_IOKitHandled;
}

// Placeholder kept for structure; real registration is below near setupAdditionalSystemUUIDHooks.
#if 0
%hookf(CFTypeRef, IORegistryEntryCreateCFProperty, io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options) {
    if (gOwnerIOKitInstalled) {
        return %orig;
    }
    @try {
        // Check if we're looking for the platform UUID
        if (key && [(__bridge NSString *)key isEqualToString:@"IOPlatformUUID"]) {
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            
            if (shouldSpoofForBundle(bundleID)) {
                // Use direct check instead of manager
                if (isSystemBootUUIDEnabled()) {
                    NSString *bootUUID = getSpoofedSystemBootUUID();
                    if (bootUUID && bootUUID.length > 0) {
                        PXLog(@"[WeaponX] 🔄 Spoofing IOPlatformUUID with: %@", bootUUID);
                        return (__bridge_retained CFStringRef)bootUUID;
                    }
                }
            }
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ❌ Exception in IORegistryEntryCreateCFProperty: %@", exception);
    }
    
    return %orig;
}

// Hook IORegistryEntryCreateCFProperties to intercept multiple properties at once
%hookf(IOReturn, IORegistryEntryCreateCFProperties, io_registry_entry_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, IOOptionBits options) {
    IOReturn result = %orig;
    
    @try {
        // If successful and we get properties back
        if (result == kIOReturnSuccess && properties && *properties) {
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            
            if (shouldSpoofForBundle(bundleID)) {
                // Use direct check instead of manager
                if (isSystemBootUUIDEnabled()) {
                    NSMutableDictionary *props = (__bridge NSMutableDictionary *)*properties;
                    
                    // Check if the dictionary has IOPlatformUUID
                    if (props[@"IOPlatformUUID"]) {
                        NSString *bootUUID = getSpoofedSystemBootUUID();
                        if (bootUUID && bootUUID.length > 0) {
                            PXLog(@"[WeaponX] 🔄 Spoofing IOPlatformUUID in properties with: %@", bootUUID);
                            props[@"IOPlatformUUID"] = bootUUID;
                        }
                    }
                }
            }
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ❌ Exception in IORegistryEntryCreateCFProperties: %@", exception);
    }
    
    return result;
}
#endif // 0 — legacy IOKit %hookf removed (coordinator-owned)

#pragma mark - Dyld Cache UUID Hooks

// Function pointer for _dyld_get_shared_cache_uuid
static bool (*orig_dyld_get_shared_cache_uuid)(uuid_t uuid_out) = NULL;

// Replacement function for _dyld_get_shared_cache_uuid
static bool replaced_dyld_get_shared_cache_uuid(uuid_t uuid_out) {
    @try {
        // First check if we need to spoof at all
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (!shouldSpoofForBundle(bundleID) || !isDyldCacheUUIDEnabled() || !uuid_out) {
            // Call original if we're not spoofing
            if (orig_dyld_get_shared_cache_uuid) {
                return orig_dyld_get_shared_cache_uuid(uuid_out);
            }
            return false;
        }
        
        // Get the UUID from the manager to ensure we're consistent with other hooks
        DyldCacheUUIDManager *manager = [DyldCacheUUIDManager sharedManager];
        NSString *dyldUUID = [manager currentDyldCacheUUID];
        
        // If we got a valid UUID, use it
        if (dyldUUID && dyldUUID.length > 0) {
            // Parse UUID string
            NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:dyldUUID];
            if (uuid) {
                [uuid getUUIDBytes:uuid_out];
                
                // Only log occasionally to reduce spam
                static NSTimeInterval lastLogTime = 0;
                NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
                if (now - lastLogTime > 5.0) { // Log at most every 5 seconds
                    PXLog(@"[WeaponX] 🔄 Spoofing Dyld Cache UUID with: %@", dyldUUID);
                    lastLogTime = now;
                }
                
                return true;
            }
        }
        
        // Fallback: try to get a new UUID if the manager didn't have one
        dyldUUID = getSpoofedDyldCacheUUID();
        if (dyldUUID && dyldUUID.length > 0) {
            NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:dyldUUID];
            if (uuid) {
                [uuid getUUIDBytes:uuid_out];
                
                // Update the manager with this UUID for future consistency
                [manager setCurrentDyldCacheUUID:dyldUUID];
                
                PXLog(@"[WeaponX] 🔄 Spoofing Dyld Cache UUID (fallback) with: %@", dyldUUID);
                return true;
            }
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ❌ Exception in replaced_dyld_get_shared_cache_uuid: %@", exception);
    }
    
    // Call original if spoofing failed
    if (orig_dyld_get_shared_cache_uuid) {
        return orig_dyld_get_shared_cache_uuid(uuid_out);
    }
    
    return false;
}

// Additional hook for dyld_get_all_image_infos which can be used to get dyld cache info
static const struct dyld_all_image_infos* (*orig_dyld_get_all_image_infos)(void) = NULL;

// Version of the struct with only the fields we need to copy
typedef struct {
    uint32_t version;
    uint32_t infoArrayCount;
    const void* infoArray;
    const void* notification;
    bool processDetachedFromSharedRegion;
    bool libSystemInitialized;
    const void* dyldImageLoadAddress;
    void* jitInfo;
    const void* dyldVersion;
    const void* errorMessage;
    uintptr_t terminationFlags;
    void* coreSymbolicationShmPage;
    uintptr_t systemOrderFlag;
    uintptr_t uuidArrayCount;
    const void* uuidArray;
    const void* dyldAllImageInfosAddress;
    uintptr_t initialImageCount;
    uintptr_t errorKind;
    const void* errorClientOfDylibPath;
    const void* errorTargetDylibPath;
    const void* errorSymbol;
    const uuid_t* sharedCacheUUID;
    // Remaining fields are not needed for our spoofing
} simplified_dyld_all_image_infos;

// Create a thread-local storage for per-thread cache to avoid "1 image on all image" problem
static NSMutableDictionary *threadLocalCaches() {
    static NSMutableDictionary *allCaches = nil;
    static dispatch_once_t onceToken;
    static NSLock *cachesLock = nil;
    
    dispatch_once(&onceToken, ^{
        allCaches = [NSMutableDictionary dictionary];
        cachesLock = [[NSLock alloc] init];
    });
    
    [cachesLock lock];
    
    // Get current thread ID
    NSString *threadKey = [NSString stringWithFormat:@"%p", (void *)pthread_self()];
    NSMutableDictionary *threadCache = allCaches[threadKey];
    
    if (!threadCache) {
        threadCache = [NSMutableDictionary dictionary];
        allCaches[threadKey] = threadCache;
    }
    
    [cachesLock unlock];
    return threadCache;
}

// Create a copy of the image infos structure with spoofed UUID
static const struct dyld_all_image_infos* replaced_dyld_get_all_image_infos(void) {
    @try {
        const struct dyld_all_image_infos *original = orig_dyld_get_all_image_infos();
        if (!original) return NULL;
        
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (shouldSpoofForBundle(bundleID)) {
            // Use direct check instead of manager
            // The compiler warns about comparing sharedCacheUUID with NULL because it's an array pointer
            // Instead, we'll check if the version is high enough to safely access this field
            if (isDyldCacheUUIDEnabled() && original->version >= 15) {
                // Using per-bundle caching to ensure consistent but unique UUIDs across apps
                DyldCacheUUIDManager *manager = [DyldCacheUUIDManager sharedManager];
                NSString *dyldUUID = [manager currentDyldCacheUUID];
                
                if (!dyldUUID || dyldUUID.length == 0) {
                    // If no UUID is available, try to get one from the manager
                    dyldUUID = getSpoofedDyldCacheUUID();
                    if (!dyldUUID || dyldUUID.length == 0) {
                        // Fall back to original if we can't get a valid UUID
                        return original;
                    }
                }
                
                // Get thread-local storage for this image info
                NSMutableDictionary *threadCache = threadLocalCaches();
                NSString *cacheKey = [NSString stringWithFormat:@"image_info_%@", bundleID];
                
                // Check if we already have a cached struct for this thread + bundle
                NSDictionary *cachedInfo = threadCache[cacheKey];
                id cachedUUIDObj = threadCache[[NSString stringWithFormat:@"uuid_%@", bundleID]];
                uuid_t *cachedUUIDPtr = NULL;
                if (cachedUUIDObj) {
                    cachedUUIDPtr = (uuid_t *)[cachedUUIDObj pointerValue];
                }
                
                // Only create a new struct if needed
                if (cachedInfo && cachedUUIDPtr) {
                    // Update last access time
                    NSMutableDictionary *updatedCache = [cachedInfo mutableCopy];
                    [updatedCache setObject:[NSDate date] forKey:@"lastAccess"];
                    threadCache[cacheKey] = updatedCache;
                    
                    struct dyld_all_image_infos* spoofedInfos = (struct dyld_all_image_infos*)[cachedInfo[@"pointer"] pointerValue];
                    
                    // Replace the UUID in the original struct before returning
                    if (spoofedInfos && spoofedInfos->uuidArray) {
                        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"15.0")) {
                            // Use proper struct access for dyld_uuid_info
                            struct dyld_uuid_info *uuidInfo = (struct dyld_uuid_info *)spoofedInfos->uuidArray;
                            for (int i = 0; i < original->uuidArrayCount; i++) {
                                // Use direct access to uuid field in dyld_uuid_info struct
                                if (cachedUUIDPtr) {
                                    memcpy((void*)uuidInfo[i].imageUUID, cachedUUIDPtr, sizeof(uuid_t));
                                }
                            }
                        } else {
                            // For older iOS versions
                            struct dyld_uuid_info *uuidInfo = (struct dyld_uuid_info *)spoofedInfos->uuidArray;
                            if (cachedUUIDPtr) {
                                memcpy((void*)uuidInfo[0].imageUUID, cachedUUIDPtr, sizeof(uuid_t));
                            }
                        }
                    }
                    
                    return (const struct dyld_all_image_infos*)spoofedInfos;
                }
            }
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ❌ Exception in replaced_dyld_get_all_image_infos: %@", exception);
    }
    
    return orig_dyld_get_all_image_infos();
}

#pragma mark - Additional System UUID Methods (coordinator providers)

// gethostuuid: returns exactly 16 UUID bytes (NOT the same serializer as kern.uuid).
static void PXUUIDRegisterNativeProviders(void) {
    PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];

    [coord registerGethostuuidProvider:@"uuid.gethostuuid" priority:PXNativeHookPriorityIdentity pre:^BOOL(uuid_t _Nonnull uuid, const struct timespec * _Nullable wait, int * _Nonnull outResult) {
        (void)wait;
        @try {
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            if (!shouldSpoofForBundle(bundleID) || !isSystemBootUUIDEnabled()) return NO;
            NSString *bootUUID = getSpoofedSystemBootUUID();
            if (!bootUUID.length) return NO;
            NSUUID *ns = [[NSUUID alloc] initWithUUIDString:bootUUID];
            if (!ns || !uuid) return NO;
            [ns getUUIDBytes:uuid];
            if (outResult) *outResult = 0;
            return YES;
        } @catch (__unused NSException *e) {
            return NO;
        }
    }];

    // kern.uuid: NUL-terminated UUID *string* with correct two-call buffer sizing.
    [coord registerSysctlBynameProvider:@"uuid.kern.uuid" priority:PXNativeHookPriorityIdentity pre:^BOOL(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen, int *outResult) {
        (void)newp; (void)newlen;
        if (!name || strcmp(name, "kern.uuid") != 0) return NO;
        @try {
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            if (!shouldSpoofForBundle(bundleID) || !isSystemBootUUIDEnabled()) return NO;
            NSString *bootUUID = getSpoofedSystemBootUUID();
            if (!bootUUID.length || !oldlenp) return NO;
            const char *cstr = bootUUID.UTF8String;
            if (!cstr) return NO;
            size_t required = strlen(cstr) + 1; // NUL-terminated string
            if (!oldp) {
                *oldlenp = required;
                if (outResult) *outResult = 0;
                return YES;
            }
            if (*oldlenp < required) {
                *oldlenp = required;
                errno = ENOMEM;
                if (outResult) *outResult = -1;
                return YES;
            }
            memset(oldp, 0, *oldlenp);
            memcpy(oldp, cstr, required);
            *oldlenp = required;
            if (outResult) *outResult = 0;
            return YES;
        } @catch (__unused NSException *e) {
            return NO;
        }
    } post:nil];

    // IOKit IOPlatformUUID / system-id via coordinator post (identity).
    [coord registerIORegistryCreateCFPropertyProvider:@"uuid.iokit.create" priority:PXNativeHookPriorityIdentity pre:^BOOL(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options, CFTypeRef *outResult) {
        (void)entry; (void)allocator; (void)options;
        if (!key) return NO;
        NSString *keyStr = (__bridge NSString *)key;
        if (![keyStr isEqualToString:@"IOPlatformUUID"] && ![keyStr isEqualToString:@"system-id"]) return NO;
        @try {
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            if (!shouldSpoofForBundle(bundleID) || !isSystemBootUUIDEnabled()) return NO;
            NSString *bootUUID = getSpoofedSystemBootUUID();
            if (!bootUUID.length || !outResult) return NO;
            *outResult = CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)bootUUID);
            return YES;
        } @catch (__unused NSException *e) {
            return NO;
        }
    } post:nil];

    [coord registerIORegistryCreateCFPropertiesProvider:@"uuid.iokit.properties" priority:PXNativeHookPriorityIdentity pre:nil post:^(io_registry_entry_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, IOOptionBits options, IOReturn *inoutResult) {
        (void)entry; (void)allocator; (void)options;
        if (!inoutResult || *inoutResult != kIOReturnSuccess || !properties || !*properties) return;
        @try {
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            if (!shouldSpoofForBundle(bundleID) || !isSystemBootUUIDEnabled()) return;
            NSString *bootUUID = getSpoofedSystemBootUUID();
            if (!bootUUID.length) return;
            NSMutableDictionary *props = (__bridge NSMutableDictionary *)*properties;
            if (props[@"IOPlatformUUID"]) props[@"IOPlatformUUID"] = bootUUID;
            if (props[@"system-id"]) props[@"system-id"] = bootUUID;
        } @catch (__unused NSException *e) {}
    }];

    [coord registerIORegistrySearchCFPropertyProvider:@"uuid.iokit.search" priority:PXNativeHookPriorityIdentity pre:^BOOL(io_registry_entry_t entry, const io_name_t plane, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options, CFTypeRef *outResult) {
        (void)entry; (void)plane; (void)allocator; (void)options;
        if (!key) return NO;
        NSString *keyStr = (__bridge NSString *)key;
        if (![keyStr isEqualToString:@"IOPlatformUUID"] && ![keyStr isEqualToString:@"system-id"]) return NO;
        @try {
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            if (!shouldSpoofForBundle(bundleID) || !isSystemBootUUIDEnabled()) return NO;
            NSString *bootUUID = getSpoofedSystemBootUUID();
            if (!bootUUID.length || !outResult) return NO;
            *outResult = CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)bootUUID);
            return YES;
        } @catch (__unused NSException *e) {
            return NO;
        }
    } post:nil];

    // Do NOT hook CFUUIDCreate — generic UUID generation must stay unique.
    PXLog(@"[WeaponX] ✅ UUID native providers registered (gethostuuid/kern.uuid/IOKit); CFUUIDCreate NOT hooked");
}

static void setupAdditionalSystemUUIDHooks(void) {
    // Register providers only — coordinator installs symbols once.
    PXUUIDRegisterNativeProviders();
    [[PXNativeHookCoordinator sharedCoordinator] installOwnedSymbolsIfNeeded];
}

// Update constructor to initialize the additional hooks
%ctor {
    @autoreleasepool {
        // Delay hook initialization to ensure everything is properly set up
        // This helps avoid early hooking that might cause crashes
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            // Enhanced process filtering - check if this is a process we should hook
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            NSString *executablePath = [[NSBundle mainBundle] executablePath];
            NSString *processName = [executablePath lastPathComponent];
            if (PXIsWebKitHelperProcess(bundleID, processName)) {
                PXLog(@"[WeaponX] 🚫 Skipping UUID hooks for WebKit helper: %@", processName);
                return;
            }
            
            BOOL scopeAllowed = bundleID && PXProcessIsAllowedForSpoofing(bundleID, processName, PXScopeOptionAllowSafariAuthStack);
            if (!bundleID || !scopeAllowed ||
                [processName isEqualToString:@"SpringBoard"] ||
                [processName isEqualToString:@"backboardd"] ||
                [processName isEqualToString:@"assertiond"] ||
                [processName isEqualToString:@"useractivityd"] ||
                [processName isEqualToString:@"apsd"] ||
                [processName containsString:@"daemon"] ||
                [processName containsString:@"assistant"] ||
                [processName containsString:@"locationd"] ||
                [processName containsString:@"powerd"] ||
                [executablePath hasPrefix:@"/usr/libexec/"] ||
                [executablePath hasPrefix:@"/usr/sbin/"] ||
                [executablePath hasPrefix:@"/usr/bin/"] ||
                [executablePath hasPrefix:@"/bin/"] ||
                [executablePath hasPrefix:@"/sbin/"]) {
                PXLog(@"[WeaponX] 🚫 Skipping UUID hooks for system process: %@", processName);
                return;
            }
            
            // Perform a more thorough check for iPad-specific processes that might be causing issues
            UIDevice *device = [UIDevice currentDevice];
            BOOL isIPad = [device userInterfaceIdiom] == UIUserInterfaceIdiomPad;
            
            if (isIPad) {
                // Additional processes to skip on iPad to prevent crashes
                if ([processName isEqualToString:@"sharingd"] ||
                    [processName isEqualToString:@"mediaserverd"] ||
                    [processName isEqualToString:@"searchd"] ||
                    [processName isEqualToString:@"identityservicesd"] ||
                    [processName isEqualToString:@"coreduetd"] ||
                    [processName isEqualToString:@"mobiletimerd"] ||
                    [processName containsString:@"app"] ||
                    [processName containsString:@"ctid"] ||
                    [processName containsString:@"trust"] ||
                    [processName containsString:@"xctest"]) {
                    PXLog(@"[WeaponX] 🚫 Skipping UUID hooks for iPad-specific process: %@", processName);
                    return;
                }
            }
            
            // Check if this app is actually configured for spoofing before initializing hooks
            // This prevents unnecessary hooking in apps not configured in the tweak
            if (!shouldSpoofForBundle(bundleID)) {
                // Most apps will hit this branch and exit immediately
                PXLog(@"[WeaponX] ℹ️ App %@ not configured for UUID spoofing, skipping hooks", bundleID);
                return;
            }
            
            // If we get here, the app is configured for spoofing, so we can initialize the hooks
            
            // Check iOS version to apply different handling for iOS 18+
            NSOperatingSystemVersion ios18 = {18, 0, 0};
            BOOL isIOS18OrNewer = [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:ios18];
            
            if (isIOS18OrNewer) {
                // Adjust cache validity duration for better performance on newer iOS
                kCacheValidityDuration = 300.0; // 5 minutes for iOS 18+
                PXLog(@"[WeaponX] ⚙️ Using adjusted cache settings for iOS 18+");
            }
            
            // Initialize cache queue with better naming for debugging
            cacheQueue = dispatch_queue_create("com.hydra.projectx.uuidcache", DISPATCH_QUEUE_SERIAL);
            
            // Initialize cache dictionary
            cachedBundleDecisions = [NSMutableDictionary dictionary];
            
            PXLog(@"[WeaponX] 🚀 Initializing UUID hooks for app: %@ (%@)", bundleID, processName);
            
            // Create a separate try-catch block for each hook to prevent one failure from affecting others
            @try {
                // Set up hook for _dyld_get_shared_cache_uuid
                void *handle = dlopen(NULL, RTLD_GLOBAL);
                if (handle) {
                    // Wrap each hook installation in its own try-catch for isolation
                    @try {
                        orig_dyld_get_shared_cache_uuid = dlsym(handle, "_dyld_get_shared_cache_uuid");
                        
                        if (orig_dyld_get_shared_cache_uuid) {
                            // Use MSHookFunction for hook installation
                            MSHookFunction(orig_dyld_get_shared_cache_uuid, 
                                        (void *)replaced_dyld_get_shared_cache_uuid, 
                                        (void **)&orig_dyld_get_shared_cache_uuid);
                            PXLog(@"[WeaponX] ✅ Successfully hooked _dyld_get_shared_cache_uuid");
                        } else {
                            PXLog(@"[WeaponX] ⚠️ Could not find _dyld_get_shared_cache_uuid symbol");
                        }
                    } @catch (NSException *exception) {
                        PXLog(@"[WeaponX] ❌ Exception when hooking _dyld_get_shared_cache_uuid: %@", exception);
                    }
                    
                    // Separate try-catch for the second hook
                    @try {
                        // Set up hook for dyld_get_all_image_infos
                        orig_dyld_get_all_image_infos = dlsym(handle, "_dyld_get_all_image_infos");
                        
                        if (orig_dyld_get_all_image_infos) {
                            // Use MSHookFunction for hook installation
                            MSHookFunction(orig_dyld_get_all_image_infos, 
                                        (void *)replaced_dyld_get_all_image_infos, 
                                        (void **)&orig_dyld_get_all_image_infos);
                            PXLog(@"[WeaponX] ✅ Successfully hooked _dyld_get_all_image_infos");
                        } else {
                            PXLog(@"[WeaponX] ⚠️ Could not find _dyld_get_all_image_infos symbol");
                        }
                    } @catch (NSException *exception) {
                        PXLog(@"[WeaponX] ❌ Exception when hooking _dyld_get_all_image_infos: %@", exception);
                    }
                    
                    dlclose(handle);
                } else {
                    PXLog(@"[WeaponX] ⚠️ Failed to open dynamic linker handle");
                }
            } @catch (NSException *exception) {
                PXLog(@"[WeaponX] ❌ Exception in UUID hooks setup: %@", exception);
            }
            
            // Register for settings change notifications
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                clearCacheCallback,
                CFSTR("com.hydra.projectx.settings.changed"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
            
            // Register for profile change notifications
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                clearCacheCallback,
                CFSTR("com.hydra.projectx.profileChanged"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
            
            PXLog(@"[WeaponX] ✅ UUID hooks initialization complete for %@", bundleID);
            
            // Add after initializing hooks for _dyld_get_shared_cache_uuid and _dyld_get_all_image_infos
            @try {
                // If this app is configured for spoofing and UUIDs are enabled, set up additional hooks
                if (shouldSpoofForBundle(bundleID)) {
                    setupAdditionalSystemUUIDHooks();
                }
            } @catch (NSException *exception) {
                PXLog(@"[WeaponX] ❌ Exception in additional hooks setup: %@", exception);
            }
        });
    }
} 
