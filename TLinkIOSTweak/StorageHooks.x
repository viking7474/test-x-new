#import "TLinkIOS.h"
#import "IdentifierManager.h"
#import "StorageManager.h"
#import "TLinkIOSLogging.h"
#import "PXNativeHookCoordinator.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <string.h>
#import <dispatch/dispatch.h>
#import <sys/mount.h>
#import <dlfcn.h>
#import <substrate.h>
// #import <ellekit/ellekit.h> // Removed for rootful - using Substrate
#import <IOKit/IOKitLib.h>
#import <execinfo.h>
#import <mach-o/dyld.h>

#import "PXScope.h"
#import "PXPaths.h"
#import "PXRuntimeSnapshot.h"
#import "PXFileDebug.h"
#import <os/lock.h>
#import <stdatomic.h>
#import <stdbool.h>
#include <math.h>
#include <time.h>

// Constants for proper size calculations - use only marketing units (1000-based)
#define BYTES_PER_KB (1000ULL)
#define BYTES_PER_MB (1000ULL * 1000ULL)
#define BYTES_PER_GB (1000ULL * 1000ULL * 1000ULL)
#define BYTES_PER_TB (1000ULL * 1000ULL * 1000ULL * 1000ULL)

// Binary units for compensation calculations
#define BYTES_PER_KB_BINARY (1024ULL)
#define BYTES_PER_MB_BINARY (1024ULL * 1024ULL)
#define BYTES_PER_GB_BINARY (1024ULL * 1024ULL * 1024ULL)
#define BYTES_PER_TB_BINARY (1024ULL * 1024ULL * 1024ULL * 1024ULL)

// Compensation factor for technical apps (binary/marketing ratio)
#define BINARY_COMPENSATION_FACTOR (BYTES_PER_GB_BINARY / (double)BYTES_PER_GB)

// Define standard capacities in GB that we want to display correctly
#define CAPACITY_64GB  32
#define CAPACITY_128GB 128

// Standard APFS block size
#define DEFAULT_BLOCK_SIZE (4096ULL)



// IOKit function pointer
static CFTypeRef (*orig_IORegistryEntryCreateCFProperty)(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options);

// Forward declarations
static NSString *getCurrentBundleID(void);
static void PXStorageRefreshNativeSnapshot(void);
static void PXStorageScheduleNativeRefresh(dispatch_queue_t queue);

// Native statfs/getfsstat providers run while CoreServices may hold its
// non-recursive MountInfo lock. Their call path must remain Foundation-free.
static _Atomic(bool) gStorageProcessAllowed = false;
static _Atomic(bool) gStorageNativeRefreshInProgress = false;
static _Atomic(uint64_t) gStorageNativeTotalBytes = 0;
static _Atomic(uint64_t) gStorageNativeFreeBytes = 0;
// SC versioning makes the separately stored C scalars one observed generation.
// Producers claim refresh ownership; native readers never spin or acquire a lock.
static _Atomic(uint64_t) gStorageNativeRevision = 0;
static _Atomic(bool) gStorageRefreshScheduled = false;

static BOOL PXStorageBeginNativeRefresh(void) {
    bool expected = false;
    if (!atomic_compare_exchange_strong_explicit(&gStorageNativeRefreshInProgress, &expected, true,
                                                 memory_order_seq_cst, memory_order_seq_cst)) return NO;
    atomic_fetch_add_explicit(&gStorageNativeRevision, 1, memory_order_seq_cst);
    return YES;
}

static void PXStorageEndNativeRefresh(uint64_t total, uint64_t free, BOOL allowed) {
    allowed = allowed && total > 0 && free <= total;
    atomic_store_explicit(&gStorageNativeTotalBytes, allowed ? total : 0, memory_order_seq_cst);
    atomic_store_explicit(&gStorageNativeFreeBytes, allowed ? free : 0, memory_order_seq_cst);
    atomic_store_explicit(&gStorageProcessAllowed, allowed, memory_order_seq_cst);
    atomic_fetch_add_explicit(&gStorageNativeRevision, 1, memory_order_seq_cst);
    atomic_store_explicit(&gStorageNativeRefreshInProgress, false, memory_order_seq_cst);
}


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

// Object cache state is lock-owned; its epoch tracks notification invalidation.
static os_unfair_lock gStorageCacheLock = OS_UNFAIR_LOCK_INIT;
static NSDictionary *gCachedStorageValues = nil;
static NSTimeInterval gStorageCacheLoadedAt = 0;
static uint64_t gStorageCacheGeneration = 0;

static NSTimeInterval PXStorageCacheTime(void) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    return 0; // Captured views bypass this object cache and its clock.
#else
    struct timespec instant = {0};
    if (clock_gettime(CLOCK_MONOTONIC, &instant) != 0) return NAN;
    return (NSTimeInterval)instant.tv_sec + (NSTimeInterval)instant.tv_nsec / 1e9;
#endif
}

static NSDictionary *PXStorageCachedValues(NSTimeInterval now, uint64_t *generation) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    (void)now;
    if (generation) *generation = 0;
    return nil;
#else
    __attribute__((objc_precise_lifetime)) NSDictionary *discarded = nil;
    NSDictionary *cached = nil;
    os_unfair_lock_lock(&gStorageCacheLock);
    if (generation) *generation = gStorageCacheGeneration;
    if (gCachedStorageValues && isfinite(now) && now >= gStorageCacheLoadedAt &&
        now - gStorageCacheLoadedAt < 30.0) {
        cached = gCachedStorageValues;
    } else {
        discarded = gCachedStorageValues;
        gCachedStorageValues = nil;
        gStorageCacheLoadedAt = 0;
    }
    os_unfair_lock_unlock(&gStorageCacheLock);
    (void)discarded;
    return cached;
#endif
}

static NSDictionary *PXStoragePublishValues(NSDictionary *values, NSTimeInterval now, uint64_t generation) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    (void)now; (void)generation;
    return values;
#else
    __attribute__((objc_precise_lifetime)) NSDictionary *immutable = nil;
    if ([values isKindOfClass:NSDictionary.class]) {
        @try {
            NSData *data = [NSPropertyListSerialization dataWithPropertyList:values format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
            id detached = data ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL] : nil;
            if ([detached isKindOfClass:NSDictionary.class]) immutable = detached;
        } @catch (NSException *exception) { (void)exception; }
        // Match enabled invalid-data byte defaults, not physical capacity.
        if (!immutable) immutable = @{ @"TotalStorage": @"128", @"FreeStorage": @"38" };
    }
    NSTimeInterval observedNow = PXStorageCacheTime();
    __attribute__((objc_precise_lifetime)) NSDictionary *discarded = nil;
    NSDictionary *published = nil;
    os_unfair_lock_lock(&gStorageCacheLock);
    if (generation == gStorageCacheGeneration) {
        discarded = gCachedStorageValues;
        BOOL cacheable = immutable && isfinite(now) && now >= 0;
        gCachedStorageValues = cacheable ? immutable : nil;
        gStorageCacheLoadedAt = cacheable ? now : 0;
        published = immutable; // A clock failure may still serve this detached read once.
    } else {
        // A notification invalidated this loader. Do not resurrect its packet;
        // a newer publication, if present, is already the authoritative cache.
        if (gCachedStorageValues && isfinite(observedNow) && observedNow >= gStorageCacheLoadedAt &&
            observedNow - gStorageCacheLoadedAt < 30.0) published = gCachedStorageValues;
    }
    os_unfair_lock_unlock(&gStorageCacheLock);
    (void)discarded; (void)immutable;
    return published;
#endif
}

static void PXStorageInvalidateCache(void) {
    __attribute__((objc_precise_lifetime)) NSDictionary *discarded = nil;
    os_unfair_lock_lock(&gStorageCacheLock);
    discarded = gCachedStorageValues;
    gCachedStorageValues = nil;
    gStorageCacheLoadedAt = 0;
    gStorageCacheGeneration++;
    os_unfair_lock_unlock(&gStorageCacheLock);
    (void)discarded;
}

static void PXStorageSettingsChanged(CFNotificationCenterRef center,
                                     void *observer,
                                     CFStringRef name,
                                     const void *object,
                                     CFDictionaryRef userInfo) {
    PX_RUNTIME_READ_OPERATION;
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    PXStorageInvalidateCache();
    PXInvalidateScopeDecisionCache();

    static dispatch_queue_t refreshQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        refreshQueue = dispatch_queue_create("com.hydra.tlinkios.storage-native-refresh",
                                             DISPATCH_QUEUE_SERIAL);
    });
    PXStorageScheduleNativeRefresh(refreshQueue);
}

// Helper function to get consistent storage values directly from storage.plist.
static NSDictionary *getStorageValues() {
    PX_RUNTIME_READ_OPERATION;
    uint64_t generation = 0;
    NSTimeInterval now = PXStorageCacheTime();
    NSDictionary *cached = PXStorageCachedValues(now, &generation);
    if (cached) return cached;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    PXRuntimeReadSnapshot *runtimeView = PXCaptureRuntimeSnapshot();
    NSDictionary *runtimeSettings = runtimeView.tlinkSettings;
    NSDictionary *runtimeEnabled = [runtimeSettings[@"EnabledIdentifiers"] isKindOfClass:NSDictionary.class] ? runtimeSettings[@"EnabledIdentifiers"] : @{};
    NSDictionary *runtimeStorage = [runtimeView profileArtifact:@"storage"];
    id primaryStorageEnabled = runtimeEnabled[@"StorageSystem"];
    BOOL runtimeStorageEnabled = NO;
    if (primaryStorageEnabled != nil) {
        runtimeStorageEnabled = PXRuntimeReadBool(primaryStorageEnabled);
    } else {
        id secondaryStorageEnabled = runtimeSettings[@"StorageSystemEnabled"];
        if (secondaryStorageEnabled != nil) {
            runtimeStorageEnabled = PXRuntimeReadBool(secondaryStorageEnabled);
        } else {
            // Compatibility with older sparse settings: storage.plist is only
            // generated for an enabled StorageSystem, so a complete artifact is
            // sufficient evidence when the primary toggle key was lost.
            runtimeStorageEnabled = runtimeStorage[@"TotalStorage"] != nil && runtimeStorage[@"FreeStorage"] != nil;
        }
    }
    if (!runtimeStorageEnabled) return nil;
    if (runtimeStorage[@"TotalStorage"] && runtimeStorage[@"FreeStorage"]) {
        return PXStoragePublishValues(runtimeStorage, now, generation);
    }
    // Match the rootful behavior: once StorageSystem is explicitly/effectively
    // enabled, an unavailable profile artifact must not leak the physical disk.
    return PXStoragePublishValues(@{
        @"TotalStorage": @"128",
        @"FreeStorage": @"38.4"
    }, now, generation);
#endif
    
    // First check if the feature is globally enabled
    BOOL storageSystemEnabled = NO;
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.hydra.tlinkios.settings"];
    if (defaults) {
        storageSystemEnabled = [defaults boolForKey:@"StorageSystemEnabled"];
    }
    
    if (!storageSystemEnabled && NSClassFromString(@"IdentifierManager")) {
        id manager = [NSClassFromString(@"IdentifierManager") sharedManager];
        if (manager && [manager respondsToSelector:@selector(isIdentifierEnabled:)]) {
            storageSystemEnabled = [manager isIdentifierEnabled:@"StorageSystem"];
        }
    }
    
    // If feature is disabled globally, return nil to abort spoofing
    if (!storageSystemEnabled) {
        return nil;
    }
    
    @try {
        NSString *profileRoot = PXActiveProfileRootPath();
        if (profileRoot.length) {
            NSDictionary *storageDict = [NSDictionary dictionaryWithContentsOfFile:
                [profileRoot stringByAppendingPathComponent:@"storage.plist"]];
            if (storageDict[@"TotalStorage"] && storageDict[@"FreeStorage"]) {
                return PXStoragePublishValues(storageDict, now, generation);
            }
        }
        
        // Fallback to StorageManager if plist not found
        StorageManager *storageManager = [%c(StorageManager) sharedManager];
        if (storageManager) {
            NSString *totalStorage = [storageManager totalStorageCapacity];
            NSString *freeStorage = [storageManager freeStorageSpace];
            
            if (totalStorage && freeStorage) {
                return PXStoragePublishValues(@{
                    @"TotalStorage": totalStorage,
                    @"FreeStorage": freeStorage
                }, now, generation);
            }
        }
    } @catch (NSException *exception) {
        // If any error occurs, use default values
    }
    
    // Final fallback
    return PXStoragePublishValues(@{
        @"TotalStorage": @"128",
        @"FreeStorage": @"38.4"
    }, now, generation);
}

// Helper to calculate block count from bytes and block size
static uint64_t calculateBlockCount(uint64_t bytes, uint32_t blockSize) {
    if (blockSize == 0) {
        // Default to 4K blocks if block size is zero (shouldn't happen, but safety first)
        blockSize = DEFAULT_BLOCK_SIZE;
    }
    
    // Calculate block count, rounding up for partial blocks
    return bytes / blockSize + (bytes % blockSize != 0);
}

// Helper function to check if storage spoofing should be applied
// This centralizes the bundleID checks to avoid repeating them in every hook
static BOOL shouldApplyStorageSpoofing() {
    return atomic_load_explicit(&gStorageProcessAllowed, memory_order_acquire);
}

static BOOL PXStorageBundleIsProblematic(NSString *bundleID) {
    static NSSet<NSString *> *problematicApps = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        problematicApps = [NSSet setWithArray:@[
        @"com.toyopagroup.picaboo",    // Snapchat 
        @"com.atebits.Tweetie2",       // Twitter/X
        @"com.zhiliaoapp.musically",   // TikTok
        @"net.whatsapp.WhatsApp",      // WhatsApp
        @"ph.telegra.Telegraph",       // Telegram 
        @"ph.telegra.Telegraph.NotificationService", 
        @"ph.telegra.Telegraph.NotificationContent",
        @"com.skype.skype",
        @"com.hammerandchisel.discord",
        @"com.burbn.instagram",        // Instagram
        @"com.facebook.Facebook"       // Facebook
        ]];
    });
    return bundleID.length && [problematicApps containsObject:bundleID];
}

static void PXStorageSetSafeByteDefaults(uint64_t *totalBytes, uint64_t *freeBytes) {
    *totalBytes = 128ULL * BYTES_PER_GB;
    *freeBytes = 38ULL * BYTES_PER_GB;
}

// Function to get storage values with universal compatibility
static void getStorageValuesForApp(uint64_t *totalBytes, uint64_t *freeBytes) {
    PX_RUNTIME_READ_OPERATION;
    if (!totalBytes || !freeBytes) return;
    
    // Initialize with zeros
    *totalBytes = 0;
    *freeBytes = 0;
    
    @try {
        // Get storage values from plist
        NSDictionary *storageInfo = getStorageValues();
        if (!storageInfo) return;
        
        // Get total storage value as string
        id totalSpaceStr = storageInfo[@"TotalStorage"];
        if (!totalSpaceStr) return;
        if (![totalSpaceStr isKindOfClass:NSString.class] && ![totalSpaceStr isKindOfClass:NSNumber.class]) {
            PXStorageSetSafeByteDefaults(totalBytes, freeBytes); return;
        }
        if ([totalSpaceStr isKindOfClass:NSString.class] && ![totalSpaceStr length]) return;
        
        // Convert to numeric value
        double totalStorageGB = [totalSpaceStr doubleValue];
        if (!isfinite(totalStorageGB)) { PXStorageSetSafeByteDefaults(totalBytes, freeBytes); return; }
        if (totalStorageGB <= 0) return;
        
        // Get app info for detection
        NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSString *executablePath = [[NSBundle mainBundle] executablePath] ?: @"";
        NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: 
                           [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"] ?: @"";
        
        // Special app handling flags
        BOOL isSettingsApp = NO;
        BOOL isTechnicalApp = NO;
        
        // Check for Settings app or any settings-related UI
        if ([currentBundleID isEqualToString:@"com.apple.Preferences"] ||
            [executablePath containsString:@"Settings"] ||
            [executablePath containsString:@"Preferences"] ||
            [appName containsString:@"Settings"]) {
            isSettingsApp = YES;
        }
        
        // Check for technical apps that need binary values
        if ([executablePath containsString:@"DiskUsage"] || 
            [executablePath containsString:@"Storage"] || 
            [executablePath containsString:@"FileManager"] ||
            [executablePath containsString:@"SystemInfo"] ||
            [currentBundleID containsString:@"disk"] ||
            [currentBundleID containsString:@"storage"] ||
            [currentBundleID containsString:@"system.info"] ||
            [appName containsString:@"Storage"] ||
            [appName containsString:@"Disk"]) {
            isTechnicalApp = YES;
        }
        
        // Standard capacity values
        uint64_t size64GB_Marketing = 64ULL * BYTES_PER_GB;       // 64,000,000,000 bytes
        uint64_t size64GB_Binary = 64ULL * BYTES_PER_GB_BINARY;   // 68,719,476,736 bytes
        uint64_t size64GB_Settings = 59ULL * BYTES_PER_GB;        // ~59 GB (what Settings shows)
        uint64_t size128GB_Marketing = 128ULL * BYTES_PER_GB;     // 128,000,000,000 bytes 
        uint64_t size128GB_Binary = 128ULL * BYTES_PER_GB_BINARY; // 137,438,953,472 bytes
        uint64_t size128GB_Settings = 119ULL * BYTES_PER_GB;      // ~119 GB (what Settings shows)
        // Determine storage capacity based on device model and app type
        uint64_t storageCapacity = 0;
        if (fabs(totalStorageGB - 64) < 1.0) {
            // 64GB device
            if (isTechnicalApp) {
                storageCapacity = size64GB_Binary;
            } else if (isSettingsApp) {
                storageCapacity = size64GB_Settings;
            } else {
                storageCapacity = size64GB_Marketing;
            }
        } else if (fabs(totalStorageGB - 128) < 1.0) {
            // 128GB device
            if (isTechnicalApp) {
                storageCapacity = size128GB_Binary;
            } else if (isSettingsApp) {
                storageCapacity = size128GB_Settings;
            } else {
                storageCapacity = size128GB_Marketing;
            }
        } else {
            // Custom size
            double scaled = isTechnicalApp ? totalStorageGB * BYTES_PER_GB_BINARY :
                (isSettingsApp ? totalStorageGB * BYTES_PER_GB * 0.93 : totalStorageGB * BYTES_PER_GB);
            if (!isfinite(scaled) || scaled >= 0x1p64) { PXStorageSetSafeByteDefaults(totalBytes, freeBytes); return; }
            storageCapacity = (uint64_t)scaled;
        }
        
        // Set total bytes
        *totalBytes = storageCapacity;
        
        // Calculate free space based on percentage
        id freeSpaceStr = storageInfo[@"FreeStorage"];
        if (freeSpaceStr && ![freeSpaceStr isKindOfClass:NSString.class] && ![freeSpaceStr isKindOfClass:NSNumber.class]) {
            PXStorageSetSafeByteDefaults(totalBytes, freeBytes); return;
        }
        if ([freeSpaceStr isKindOfClass:NSNumber.class] ||
            ([freeSpaceStr isKindOfClass:NSString.class] && [freeSpaceStr length] > 0)) {
            double freeGbValue = [freeSpaceStr doubleValue];
            if (isfinite(freeGbValue) && freeGbValue >= 0 && freeGbValue <= totalStorageGB) {
                // Apply the free space as a percentage of total
                double freePercent = freeGbValue / totalStorageGB;
                double scaledFree = *totalBytes * freePercent;
                if (isfinite(scaledFree) && scaledFree >= 0 && scaledFree < 0x1p64)
                    *freeBytes = (uint64_t)scaledFree;
            }
        }
    } @catch (NSException *exception) {
        // Keep enabled-feature fallback rather than exposing physical capacity.
        PXStorageSetSafeByteDefaults(totalBytes, freeBytes);
    }
}

static void PXStorageRefreshNativeSnapshot(void) {
    PX_RUNTIME_READ_OPERATION;
    if (!PXStorageBeginNativeRefresh()) return;
    uint64_t totalBytes = 0, freeBytes = 0;
    BOOL allowed = NO;
    @try {
        NSString *bundleID = getCurrentBundleID();
        NSString *processName = [NSProcessInfo processInfo].processName;
        allowed = bundleID.length && !PXStorageBundleIsProblematic(bundleID) &&
            PXProcessIsAllowedForSpoofing(bundleID, processName, PXScopeOptionAllowSafariAuthStack);
        if (allowed) {
            getStorageValuesForApp(&totalBytes, &freeBytes);
            allowed = totalBytes > 0;
        }
    } @catch (NSException *exception) {
        (void)exception;
        allowed = NO;
    } @finally {
        PXStorageEndNativeRefresh(totalBytes, freeBytes, allowed);
    }
}

static void PXStorageScheduleNativeRefresh(dispatch_queue_t queue) {
    bool expected = false;
    if (!atomic_compare_exchange_strong_explicit(&gStorageRefreshScheduled, &expected, true,
                                                 memory_order_acq_rel, memory_order_acquire)) return;
    dispatch_async(queue, ^{
        // Clear before capture/compute: an event during refresh gets one follow-up.
        atomic_store_explicit(&gStorageRefreshScheduled, false, memory_order_release);
        @autoreleasepool {
            PX_RUNTIME_READ_OPERATION;
            PXStorageRefreshNativeSnapshot();
        }
    });
}

static BOOL PXStorageCopyNativeSnapshot(uint64_t *totalBytes, uint64_t *freeBytes) {
    if (!totalBytes || !freeBytes ||
        atomic_load_explicit(&gStorageNativeRefreshInProgress, memory_order_seq_cst)) return NO;
    uint64_t revision = atomic_load_explicit(&gStorageNativeRevision, memory_order_seq_cst);
    if (revision & 1) return NO;
    BOOL allowed = atomic_load_explicit(&gStorageProcessAllowed, memory_order_seq_cst);
    uint64_t total = atomic_load_explicit(&gStorageNativeTotalBytes, memory_order_seq_cst);
    uint64_t free = atomic_load_explicit(&gStorageNativeFreeBytes, memory_order_seq_cst);
    if (!allowed || total == 0 || free > total ||
        revision != atomic_load_explicit(&gStorageNativeRevision, memory_order_seq_cst) ||
        atomic_load_explicit(&gStorageNativeRefreshInProgress, memory_order_seq_cst)) return NO;
    *totalBytes = total; *freeBytes = free;
    return YES;
}

// Clamp provider iteration to entries actually addressable in the caller buffer.
static int PXStorageBoundedMountCount(int result, int bufsize, size_t entrySize) {
    if (result <= 0 || bufsize <= 0 || entrySize == 0) return 0;
    size_t capacity = (size_t)bufsize / entrySize;
    return capacity < (size_t)result ? (int)capacity : result;
}

// Define NSFileSystem constants as strings since they're just string constants
#define NSFileSystemSize @"NSFileSystemSize"
#define NSFileSystemFreeSize @"NSFileSystemFreeSize"
#define NSFileSystemFreeNodes @"NSFileSystemFreeNodes"
#define NSFileSystemFreeOperationCount @"NSFileSystemFreeOperationCount"

// Classify only supported capacity keys before touching runtime/profile state.
static NSUInteger PXStorageCapacityKeyKind(id key) {
    if (![key isKindOfClass:NSString.class]) return 0;
    if ([key isEqualToString:NSURLVolumeTotalCapacityKey]) return 1;
    if ([key isEqualToString:NSURLVolumeAvailableCapacityKey] ||
        [key isEqualToString:@"NSURLVolumeAvailableCapacityForImportantUsageKey"]) return 2;
    if ([key isEqualToString:@"NSURLVolumeAvailableCapacityForOpportunisticUsageKey"]) return 3;
    return 0;
}

static BOOL PXStorageKeysContainCapacity(id keys) {
    if (![keys isKindOfClass:NSArray.class]) return NO;
    for (id key in keys) if (PXStorageCapacityKeyKind(key)) return YES;
    return NO;
}

static BOOL PXStorageAttributesHaveCapacity(id values) {
    return [values isKindOfClass:NSDictionary.class] &&
        ([values[NSFileSystemSize] isKindOfClass:NSNumber.class] || [values[NSFileSystemFreeSize] isKindOfClass:NSNumber.class]);
}

static BOOL PXStorageResourceValuesHaveCapacity(id values, id keys) {
    if (![values isKindOfClass:NSDictionary.class] || ![keys isKindOfClass:NSArray.class]) return NO;
    for (id key in keys) if (PXStorageCapacityKeyKind(key) && [values[key] isKindOfClass:NSNumber.class]) return YES;
    return NO;
}

static NSNumber *PXStorageCapacityValue(NSUInteger kind, uint64_t total, uint64_t free) {
    if (!total || free > total) return nil;
    if (kind == 1) return @(total);
    if (kind == 2) return @(free); // Zero is a valid full-disk result.
    if (kind == 3) return @((uint64_t)((double)free * 0.9));
    return nil;
}

static NSDictionary *PXStorageAttributesWithCapacity(NSDictionary *original, uint64_t total, uint64_t free) {
    if (!PXStorageAttributesHaveCapacity(original) || !total || free > total) return original;
    NSMutableDictionary *modified = nil;
    id existing = original[NSFileSystemSize];
    NSNumber *value = [existing isKindOfClass:NSNumber.class] ? @(total) : nil;
    if (value && ![existing isEqualToNumber:value]) { modified = [original mutableCopy]; modified[NSFileSystemSize] = value; }
    existing = original[NSFileSystemFreeSize];
    value = [existing isKindOfClass:NSNumber.class] ? @(free) : nil;
    if (value && ![existing isEqualToNumber:value]) {
        if (!modified) modified = [original mutableCopy];
        modified[NSFileSystemFreeSize] = value;
    }
    return modified ?: original;
}

static NSDictionary *PXStorageResourceValuesWithCapacity(NSDictionary *original, NSArray *keys, uint64_t total, uint64_t free) {
    if (!PXStorageResourceValuesHaveCapacity(original, keys) || !total || free > total) return original;
    NSMutableDictionary *modified = nil;
    for (id key in keys) {
        NSUInteger kind = PXStorageCapacityKeyKind(key);
        if (!kind) continue;
        id existing = (modified ?: original)[key];
        if (![existing isKindOfClass:NSNumber.class]) continue;
        NSNumber *value = PXStorageCapacityValue(kind, total, free);
        if (value && ![existing isEqualToNumber:value]) {
            if (!modified) modified = [original mutableCopy];
            modified[key] = value;
        }
    }
    return modified ?: original;
}

static const char *PXStorageSkipTypeQualifiers(const char *type) {
    while (type && *type && strchr("rnNoORV", *type)) type++;
    return type;
}

static BOOL PXStorageObjectEncoding(const char *type) {
    type = PXStorageSkipTypeQualifiers(type);
    return type && type[0] == '@' && (type[1] == 0 || type[1] == '"');
}

// Optional compatibility selectors have no stable SDK contract. Admit only
// the original uint64/object/NSError** ABI; never install a null-%orig method.
static BOOL PXStorageCapacityCompatibilityMatches(Class cls, SEL selector) {
    Method entry = cls && selector ? class_getInstanceMethod(cls, selector) : NULL;
    if (!entry || method_getNumberOfArguments(entry) != 4) return NO;
    char result[128] = {0}, url[128] = {0}, error[128] = {0};
    method_getReturnType(entry, result, sizeof(result)); result[sizeof(result) - 1] = 0;
    method_getArgumentType(entry, 2, url, sizeof(url)); url[sizeof(url) - 1] = 0;
    method_getArgumentType(entry, 3, error, sizeof(error)); error[sizeof(error) - 1] = 0;
    const char *returnType = PXStorageSkipTypeQualifiers(result);
    const char *errorType = PXStorageSkipTypeQualifiers(error);
    return returnType[0] == 'Q' && returnType[1] == 0 && PXStorageObjectEncoding(url) &&
        errorType[0] == '^' && PXStorageObjectEncoding(errorType + 1);
}

// Function pointer for statfs
static int (*orig_statfs)(const char *path, struct statfs *buf);

// Function pointer for statfs64 (Darwin: same layout as struct statfs — use shared PXStatfs64Buf)
static int (*orig_statfs64)(const char *path, PXStatfs64Buf *buf);

// Function pointer for getfsstat
static int (*orig_getfsstat)(struct statfs *buf, int bufsize, int flags);

// Function pointer for getfsstat64
static int (*orig_getfsstat64)(PXStatfs64Buf *buf, int bufsize, int flags);

// Helper to modify statfs struct with spoofed values
static void PXStorageModifyStatfsWithValues(struct statfs *buf,
                                            uint64_t totalBytes,
                                            uint64_t freeBytes) {
    if (!buf || totalBytes == 0 || freeBytes > totalBytes) return;
    
    // Ensure block size is valid
    if (buf->f_bsize == 0) {
        buf->f_bsize = DEFAULT_BLOCK_SIZE; // Standard block size for APFS
    }
    
    buf->f_blocks = calculateBlockCount(totalBytes, buf->f_bsize);
    // Zero is valid; never retain physical free-space values for a full fake disk.
    buf->f_bfree = calculateBlockCount(freeBytes, buf->f_bsize);
    buf->f_bavail = buf->f_bfree; // Available blocks = free blocks for non-root
}

static void modifyStatfsWithSpoofedValues(struct statfs *buf) {
    PX_RUNTIME_READ_OPERATION;
    uint64_t totalBytes = 0;
    uint64_t freeBytes = 0;
    getStorageValuesForApp(&totalBytes, &freeBytes);
    PXStorageModifyStatfsWithValues(buf, totalBytes, freeBytes);
}

// Helper to modify statfs64 buffer (alias of struct statfs on Darwin)
static void modifyStatfs64WithSpoofedValues(PXStatfs64Buf *buf) {
    PX_RUNTIME_READ_OPERATION;
    // Same layout as struct statfs on Apple — reuse the primary helper.
    modifyStatfsWithSpoofedValues((struct statfs *)buf);
}

// Replacement for statfs to spoof filesystem info
static int replaced_statfs(const char *path, struct statfs *buf) {
    PX_RUNTIME_READ_OPERATION;
    // Check for null pointers
    if (!path || !buf) {
        return -1; // EINVAL
    }
    
    // Call original function
    int ret = orig_statfs(path, buf);
    
    if (ret == 0 && buf != NULL && shouldApplyStorageSpoofing()) {
        @try {
            // Only apply spoofing for the main file system paths
            if (path && (
                strcmp(path, "/") == 0 || 
                strcmp(path, "/var") == 0 || 
                strcmp(path, "/private/var") == 0 ||
                strncmp(path, "/var/mobile", 11) == 0 ||
                strncmp(path, "/private/var/mobile", 19) == 0)
            ) {
                modifyStatfsWithSpoofedValues(buf);
            }
        } @catch (NSException *exception) {
            // Ignore exceptions during modification
        }
    }
    
    return ret;
}

// Replacement for statfs64 (64-bit variant)
static int replaced_statfs64(const char *path, PXStatfs64Buf *buf) {
    PX_RUNTIME_READ_OPERATION;
    // Check for null pointers
    if (!path || !buf) {
        return -1; // EINVAL
    }
    
    // Call original function
    int ret = orig_statfs64 ? orig_statfs64(path, buf) : -1;
    
    if (ret == 0 && buf != NULL && shouldApplyStorageSpoofing()) {
        @try {
            // Only apply spoofing for the main file system paths
            if (path && (
                strcmp(path, "/") == 0 || 
                strcmp(path, "/var") == 0 || 
                strcmp(path, "/private/var") == 0 ||
                strncmp(path, "/var/mobile", 11) == 0 ||
                strncmp(path, "/private/var/mobile", 19) == 0)
            ) {
                modifyStatfs64WithSpoofedValues(buf);
            }
        } @catch (NSException *exception) {
            // Ignore exceptions during modification
        }
    }
    
    return ret;
}

// Replacement for getfsstat
static int replaced_getfsstat(struct statfs *buf, int bufsize, int flags) {
    PX_RUNTIME_READ_OPERATION;
    // Check for null pointer or invalid size
    if (!buf || bufsize <= 0) {
        return -1; // EINVAL
    }
    
    // Call original function
    int ret = orig_getfsstat(buf, bufsize, flags);
    
    if (ret > 0 && buf != NULL && shouldApplyStorageSpoofing()) {
        @try {
            // Loop through all filesystems returned
            for (int i = 0, count = PXStorageBoundedMountCount(ret, bufsize, sizeof(*buf)); i < count; i++) {
                // Safely check mount points - first ensure the string is valid
                const char *mountPoint = buf[i].f_mntonname;
                if (mountPoint && mountPoint[0] != '\0') {
                    // Only modify the root filesystem (/) and related mount points
                    if (strcmp(mountPoint, "/") == 0 || 
                        strcmp(mountPoint, "/var") == 0 || 
                        strcmp(mountPoint, "/private/var") == 0) {
                        
                        modifyStatfsWithSpoofedValues(&buf[i]);
                    }
                }
            }
        } @catch (NSException *exception) {
            // Ignore exceptions during modification
        }
    }
    
    return ret;
}

// Replacement for getfsstat64
static int replaced_getfsstat64(PXStatfs64Buf *buf, int bufsize, int flags) {
    PX_RUNTIME_READ_OPERATION;
    // Check for null pointer or invalid size
    if (!buf || bufsize <= 0) {
        return -1; // EINVAL
    }
    
    // Call original function
    int ret = orig_getfsstat64 ? orig_getfsstat64(buf, bufsize, flags) : -1;
    
    if (ret > 0 && buf != NULL && shouldApplyStorageSpoofing()) {
        @try {
            // Loop through all filesystems returned
            for (int i = 0, count = PXStorageBoundedMountCount(ret, bufsize, sizeof(*buf)); i < count; i++) {
                // Safely check mount points - first ensure the string is valid
                const char *mountPoint = buf[i].f_mntonname;
                if (mountPoint && mountPoint[0] != '\0') {
                    // Only modify the root filesystem (/) and related mount points
                    if (strcmp(mountPoint, "/") == 0 || 
                        strcmp(mountPoint, "/var") == 0 || 
                        strcmp(mountPoint, "/private/var") == 0) {
                        
                        modifyStatfs64WithSpoofedValues(&buf[i]);
                    }
                }
            }
        } @catch (NSException *exception) {
            // Ignore exceptions during modification
        }
    }
    
    return ret;
}

// Replacement for IORegistryEntryCreateCFProperty - used for IOKit property lookups
static CFTypeRef replaced_IORegistryEntryCreateCFProperty(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options) {
    PX_RUNTIME_READ_OPERATION;
    // Call original first
    CFTypeRef result = orig_IORegistryEntryCreateCFProperty(entry, key, allocator, options);

    if ([[PXNativeHookCoordinator sharedCoordinator] isSymbolInstalled:kPXNativeSymbolIORegistryEntryCreateCFProperty]) {
        // IOKit identity is owned by the native coordinator; storage never re-spoofs it here.
        return result;
    }
    
    if (!result || !key || !shouldApplyStorageSpoofing()) {
        return result;
    }
    
    @try {
        if (CFGetTypeID(key) == CFStringGetTypeID()) {
            // Check if this is a disk size query
            if (CFStringCompare(key, CFSTR("Size"), 0) == kCFCompareEqualTo) {
                // Get the IOObjectClass
                io_name_t className = {0};  // Initialize to zero
                kern_return_t kr = IOObjectGetClass(entry, className);
                
                // Safely check class name
                if (kr == KERN_SUCCESS && className[0] != '\0') {
                    BOOL isStorageClass = (strcmp(className, "IOMedia") == 0 || 
                                          strcmp(className, "IOApplePartitionScheme") == 0 ||
                                          strcmp(className, "IOBlockStorageDevice") == 0);
                    
                    if (isStorageClass && CFGetTypeID(result) == CFNumberGetTypeID()) {
                        // Get correct storage values for this app
                        uint64_t totalBytes, freeBytes;
                        getStorageValuesForApp(&totalBytes, &freeBytes);
                        
                        if (totalBytes > 0) {
                            // Release the original result
                            CFRelease(result);
                            
                            // Create a new number with our value
                            return CFNumberCreate(allocator, kCFNumberLongLongType, &totalBytes);
                        }
                    }
                }
            }
            // Handle block size queries as well
            else if (CFStringCompare(key, CFSTR("Preferred Block Size"), 0) == kCFCompareEqualTo) {
                // We should preserve the original block size in most cases
                // but ensure it's a reasonable value (4096 bytes is standard for APFS)
                if (CFGetTypeID(result) == CFNumberGetTypeID()) {
                    uint32_t blockSize = 0;
                    if (CFNumberGetValue((CFNumberRef)result, kCFNumberSInt32Type, &blockSize)) {
                        if (blockSize == 0 || blockSize > 65536) {
                            // If the value seems unreasonable, use a standard block size
                            CFRelease(result);
                            uint32_t standardSize = DEFAULT_BLOCK_SIZE;
                            return CFNumberCreate(allocator, kCFNumberSInt32Type, &standardSize);
                        }
                    }
                }
            }
        }
    } @catch (NSException *exception) {
        // If any exception occurs, return the original result
    }
    
    return result;
}

%hook NSFileManager

- (NSDictionary *)attributesOfFileSystemForPath:(NSString *)path error:(NSError **)error {
    PX_RUNTIME_READ_OPERATION;
    NSDictionary *originalAttributes = %orig;
    if (!PXStorageAttributesHaveCapacity(originalAttributes) || !shouldApplyStorageSpoofing()) return originalAttributes;
    @try {
        uint64_t totalBytes = 0, freeBytes = 0;
        getStorageValuesForApp(&totalBytes, &freeBytes);
        return PXStorageAttributesWithCapacity(originalAttributes, totalBytes, freeBytes);
    } @catch (NSException *exception) { return originalAttributes; }
}

%end

%group PXStorageImportantCapacity
%hook NSFileManager

// Optional compatibility selector; initialization validates its runtime ABI.
- (unsigned long long)volumeAvailableCapacityForImportantUsageForURL:(NSURL *)url error:(NSError **)error {
    PX_RUNTIME_READ_OPERATION;
    unsigned long long originalCapacity = %orig;
    
    if (!shouldApplyStorageSpoofing()) {
        return originalCapacity;
    }
    
    @try {
        // Get storage values with appropriate units for this app
        uint64_t totalBytes, freeBytes;
        getStorageValuesForApp(&totalBytes, &freeBytes);
        
        if (totalBytes > 0 && freeBytes <= totalBytes) {
            return freeBytes;
        }
    } @catch (NSException *exception) {
        // If an error occurs, return original value
    }
    
    return originalCapacity;
}

%end
%end

%group PXStorageTotalCapacity
%hook NSFileManager

// Optional compatibility selector.
- (unsigned long long)volumeTotalCapacityForURL:(NSURL *)url error:(NSError **)error {
    PX_RUNTIME_READ_OPERATION;
    unsigned long long originalCapacity = %orig;
    
    if (!shouldApplyStorageSpoofing()) {
        return originalCapacity;
    }
    
    @try {
        // Get storage values with appropriate units for this app
        uint64_t totalBytes, freeBytes;
        getStorageValuesForApp(&totalBytes, &freeBytes);
        
        if (totalBytes > 0) {
            return totalBytes;
        }
    } @catch (NSException *exception) {
        // If an error occurs, return original value
    }
    
    return originalCapacity;
}

%end
%end

%group PXStorageOpportunisticCapacity
%hook NSFileManager

// Optional compatibility selector.
- (unsigned long long)volumeAvailableCapacityForOpportunisticUsageForURL:(NSURL *)url error:(NSError **)error {
    PX_RUNTIME_READ_OPERATION;
    unsigned long long originalCapacity = %orig;
    
    if (!shouldApplyStorageSpoofing()) {
        return originalCapacity;
    }
    
    @try {
        // Get storage values with appropriate units for this app
        uint64_t totalBytes, freeBytes;
        getStorageValuesForApp(&totalBytes, &freeBytes);
        
        if (totalBytes > 0 && freeBytes <= totalBytes) {
            // Calculate 90% of free space with high precision
            return (uint64_t)((double)freeBytes * 0.9);
        }
    } @catch (NSException *exception) {
        // If an error occurs, return original value
    }
    
    return originalCapacity;
}

%end
%end

%hook NSURL

// Hook NSURL's getResourceValue:forKey:error: method for iOS 15+ compatibility
- (BOOL)getResourceValue:(id *)value forKey:(NSURLResourceKey)key error:(NSError **)error {
    NSUInteger kind = PXStorageCapacityKeyKind(key);
    if (!kind) return %orig;
    PX_RUNTIME_READ_OPERATION;
    BOOL result = %orig;
    if (!result || !value || ![*value isKindOfClass:NSNumber.class] || !shouldApplyStorageSpoofing()) return result;
    @try {
        uint64_t totalBytes = 0, freeBytes = 0;
        getStorageValuesForApp(&totalBytes, &freeBytes);
        NSNumber *replacement = PXStorageCapacityValue(kind, totalBytes, freeBytes);
        if (replacement && ![*value isEqualToNumber:replacement]) *value = replacement;
    } @catch (NSException *exception) { }
    return result;
}

// Hook NSURL's resourceValuesForKeys:error: method for iOS 15+ compatibility
- (NSDictionary<NSURLResourceKey, id> *)resourceValuesForKeys:(NSArray<NSURLResourceKey> *)keys error:(NSError **)error {
    if (!PXStorageKeysContainCapacity(keys)) return %orig;
    PX_RUNTIME_READ_OPERATION;
    NSDictionary *originalValues = %orig;
    if (!PXStorageResourceValuesHaveCapacity(originalValues, keys) || !shouldApplyStorageSpoofing()) return originalValues;
    @try {
        uint64_t totalBytes = 0, freeBytes = 0;
        getStorageValuesForApp(&totalBytes, &freeBytes);
        return PXStorageResourceValuesWithCapacity(originalValues, keys, totalBytes, freeBytes);
    } @catch (NSException *exception) { return originalValues; }
}

%end

// Setup hooks - Use %ctor for constructor, runs when module loads
%ctor {
    @autoreleasepool {
        if (!PXBootstrapAllows(PXHookCapabilityNative)) return;
        @try {
            PXFileDebugAIDA64Log("[Storage.ctor] enter");
            PXLog(@"[StorageHooks] Initializing storage hooks");
            
            NSString *currentBundleID = getCurrentBundleID();
            
            // Skip if we can't get bundle ID
            if (!currentBundleID || [currentBundleID length] == 0) {
                return;
            }
            
            // Don't hook our own apps
            if ([currentBundleID isEqualToString:@"com.hydra.tlinkios"] ||
                [currentBundleID isEqualToString:@"com.hydra.weaponx"]) {
                return;
            }

            NSString *proc = [NSProcessInfo processInfo].processName;
            if (PXIsWebKitHelperProcess(currentBundleID, proc)) {
                PXFileDebugAIDA64Log("[Storage.ctor] skip WebKit helper bundle=%s", currentBundleID.UTF8String ?: "<nil>");
                return;
            }
            BOOL allowed = PXProcessIsAllowedForSpoofing(currentBundleID, proc, PXScopeOptionAllowSafariAuthStack);
            PXFileDebugAIDA64Log("[Storage.ctor] scope allowed=%d bundle=%s", allowed, currentBundleID.UTF8String ?: "<nil>");
            if (!allowed) {
                PXLog(@"[StorageHooks] App %@ is not scoped, skipping hook installation", currentBundleID);
                return;
            }

            // Resolve every Foundation-backed decision before native mount hooks.
            PXStorageRefreshNativeSnapshot();
            if (!shouldApplyStorageSpoofing()) {
                PXLog(@"[StorageHooks] Storage spoofing disabled for %@", currentBundleID);
                return;
            }
            
            PXLog(@"[StorageHooks] App %@ is scoped, setting up storage hooks", currentBundleID);

            CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
            for (NSString *notificationName in @[
                @"com.hydra.tlinkios.settings.changed",
                @"com.hydra.tlinkios.profileChanged",
                @"com.hydra.tlinkios.scopedAppsChanged"
            ]) {
                CFNotificationCenterAddObserver(center, NULL, PXStorageSettingsChanged,
                    (__bridge CFStringRef)notificationName, NULL,
                    CFNotificationSuspensionBehaviorDeliverImmediately);
            }
            
            // statfs family: post-processors on coordinator (no MSHookFunction).
            // IOKit identity remains Tweak-owned; storage may still register IOKit post if needed later.
            PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
            [coord installOwnedSymbolsIfNeeded];
            orig_statfs = [coord originalForSymbol:kPXNativeSymbolStatfs];
            orig_statfs64 = [coord originalForSymbol:kPXNativeSymbolStatfs64];
            orig_getfsstat = [coord originalForSymbol:kPXNativeSymbolGetfsstat];
            orig_getfsstat64 = [coord originalForSymbol:kPXNativeSymbolGetfsstat64];
            orig_IORegistryEntryCreateCFProperty = [coord originalForSymbol:kPXNativeSymbolIORegistryEntryCreateCFProperty];

            static dispatch_once_t storageProvOnce;
            dispatch_once(&storageProvOnce, ^{
                // Use shared PXStatfs64Buf (struct statfs on Darwin) — never invent a local struct statfs64.
                [coord registerStatfsProvider:@"storage.statfs" priority:PXNativeHookPriorityNetworkStorage post:^(const char * _Nullable path, struct statfs * _Nullable buf, int * _Nonnull inoutResult) {
                    uint64_t totalBytes = 0, freeBytes = 0;
                    if (*inoutResult != 0 || !buf ||
                        !PXStorageCopyNativeSnapshot(&totalBytes, &freeBytes)) return;
                    if (path && (strcmp(path, "/") == 0 || strcmp(path, "/var") == 0 || strcmp(path, "/private/var") == 0 ||
                                 strncmp(path, "/var/mobile", 11) == 0 || strncmp(path, "/private/var/mobile", 19) == 0)) {
                        PXStorageModifyStatfsWithValues(buf, totalBytes, freeBytes);
                    }
                }];
                [coord registerStatfs64Provider:@"storage.statfs64" priority:PXNativeHookPriorityNetworkStorage post:^(const char * _Nullable path, PXStatfs64Buf * _Nullable buf, int * _Nonnull inoutResult) {
                    uint64_t totalBytes = 0, freeBytes = 0;
                    if (*inoutResult != 0 || !buf ||
                        !PXStorageCopyNativeSnapshot(&totalBytes, &freeBytes)) return;
                    if (path && (strcmp(path, "/") == 0 || strcmp(path, "/var") == 0 || strcmp(path, "/private/var") == 0 ||
                                 strncmp(path, "/var/mobile", 11) == 0 || strncmp(path, "/private/var/mobile", 19) == 0)) {
                        PXStorageModifyStatfsWithValues((struct statfs *)buf, totalBytes, freeBytes);
                    }
                }];
                [coord registerGetfsstatProvider:@"storage.getfsstat" priority:PXNativeHookPriorityNetworkStorage post:^(struct statfs * _Nullable buf, int bufsize, int flags, int * _Nonnull inoutResult) {
                    (void)flags;
                    uint64_t totalBytes = 0, freeBytes = 0;
                    if (*inoutResult <= 0 || !buf ||
                        !PXStorageCopyNativeSnapshot(&totalBytes, &freeBytes)) return;
                    for (int i = 0, count = PXStorageBoundedMountCount(*inoutResult, bufsize, sizeof(*buf)); i < count; i++) {
                        const char *mountPoint = buf[i].f_mntonname;
                        if (mountPoint && mountPoint[0] &&
                            (strcmp(mountPoint, "/") == 0 || strcmp(mountPoint, "/var") == 0 || strcmp(mountPoint, "/private/var") == 0)) {
                            PXStorageModifyStatfsWithValues(&buf[i], totalBytes, freeBytes);
                        }
                    }
                }];
                [coord registerGetfsstat64Provider:@"storage.getfsstat64" priority:PXNativeHookPriorityNetworkStorage post:^(PXStatfs64Buf * _Nullable buf, int bufsize, int flags, int * _Nonnull inoutResult) {
                    (void)flags;
                    uint64_t totalBytes = 0, freeBytes = 0;
                    if (*inoutResult <= 0 || !buf ||
                        !PXStorageCopyNativeSnapshot(&totalBytes, &freeBytes)) return;
                    for (int i = 0, count = PXStorageBoundedMountCount(*inoutResult, bufsize, sizeof(*buf)); i < count; i++) {
                        const char *mountPoint = buf[i].f_mntonname;
                        if (mountPoint && mountPoint[0] &&
                            (strcmp(mountPoint, "/") == 0 || strcmp(mountPoint, "/var") == 0 || strcmp(mountPoint, "/private/var") == 0)) {
                            PXStorageModifyStatfsWithValues((struct statfs *)&buf[i], totalBytes, freeBytes);
                        }
                    }
                }];
            });
            PXLog(@"[StorageHooks] Registered statfs family providers on coordinator");
            
            // Initialize Objective-C hooks for scoped apps only
            PXFileDebugAIDA64Log("[Storage.ctor] before %%init");
            %init;
            Class fileManagerClass = objc_getClass("NSFileManager");
            if (PXStorageCapacityCompatibilityMatches(fileManagerClass, @selector(volumeAvailableCapacityForImportantUsageForURL:error:))) {
                %init(PXStorageImportantCapacity);
            }
            if (PXStorageCapacityCompatibilityMatches(fileManagerClass, @selector(volumeTotalCapacityForURL:error:))) {
                %init(PXStorageTotalCapacity);
            }
            if (PXStorageCapacityCompatibilityMatches(fileManagerClass, @selector(volumeAvailableCapacityForOpportunisticUsageForURL:error:))) {
                %init(PXStorageOpportunisticCapacity);
            }
            PXFileDebugAIDA64Log("[Storage.ctor] after %%init");
            
            PXLog(@"[StorageHooks] Storage hooks successfully initialized for scoped app: %@", currentBundleID);
            PXFileDebugAIDA64Log("[Storage.ctor] exit");
            
        } @catch (NSException *e) {
            PXFileDebugAIDA64Log("[Storage.ctor] exception=%s", e.description.UTF8String ?: "<nil>");
            PXLog(@"[StorageHooks] ❌ Exception in constructor: %@", e);
        }
    }
} 
