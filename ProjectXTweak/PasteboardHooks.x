#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "ProjectXLogging.h"
#import "PasteboardUUIDManager.h"
#import "IdentifierManager.h"
// #import <ellekit/ellekit.h> // Removed for rootful - using Substrate

#import "PXScope.h"

// Path to scoped apps plist
static NSString *const kScopedAppsPath = @"/var/mobile/Library/Preferences/com.hydra.projectx.global_scope.plist";
static NSString *const kScopedAppsPathAlt1 = @"/private/var/mobile/Library/Preferences/com.hydra.projectx.global_scope.plist";
static NSString *const kScopedAppsPathAlt2 = @"/var/mobile/Library/Preferences/com.hydra.projectx.global_scope.plist";

// Scoped apps cache
static NSMutableDictionary *scopedAppsCache = nil;
static NSDate *scopedAppsCacheTimestamp = nil;
static const NSTimeInterval kScopedAppsCacheValidDuration = 60.0; // 1 minute

// Global variables to track state
static NSMutableDictionary *cachedBundleDecisions = nil;
static NSTimeInterval kCacheValidityDuration = 300.0; // 5 minutes
static NSMutableDictionary *customChangeCountMap = nil; // Store custom change counts per app
static NSMutableDictionary *lastKnownPasteboardData = nil; // Cache pasteboard content hash

// One-time log set for unsupported optional selectors
static NSMutableSet *loggedUnsupportedSelectors = nil;

// Forward declarations
static NSString *getCurrentBundleID(void);
static NSDictionary *loadScopedApps(void);
static BOOL isInScopedAppsList(void);
static NSString *getSpoofedPasteboardUUID(void);
static BOOL shouldSpoofForBundle(NSString *bundleID);
static NSInteger getCustomChangeCount(NSString *bundleID, NSInteger originalCount);
static void incrementCustomChangeCount(NSString *bundleID);
static BOOL hasPasteboardContentChanged(NSString *bundleID, UIPasteboard *pasteboard);
static NSString *deterministicPasteboardName(NSString *originalName, NSString *uuidString);

// Callback function for notifications that clear the cache
static void clearCacheCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    if (cachedBundleDecisions) {
        [cachedBundleDecisions removeAllObjects];
    }
    if (customChangeCountMap) {
        [customChangeCountMap removeAllObjects];
    }
    if (lastKnownPasteboardData) {
        [lastKnownPasteboardData removeAllObjects];
    }
}

#pragma mark - Scoped Apps Helper Functions

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

static NSDictionary *loadScopedApps(void) {
    @try {
        if (scopedAppsCache && scopedAppsCacheTimestamp &&
            [[NSDate date] timeIntervalSinceDate:scopedAppsCacheTimestamp] < kScopedAppsCacheValidDuration) {
            return scopedAppsCache;
        }
        
        if (!scopedAppsCache) {
            scopedAppsCache = [NSMutableDictionary dictionary];
        } else {
            [scopedAppsCache removeAllObjects];
        }
        
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
            static NSDate *lastErrorLog = nil;
            if (!lastErrorLog || [[NSDate date] timeIntervalSinceDate:lastErrorLog] > 300.0) {
                PXLog(@"[PasteboardHooks] Could not find scoped apps file");
                lastErrorLog = [NSDate date];
            }
            scopedAppsCacheTimestamp = [NSDate date];
            return scopedAppsCache;
        }
        
        NSDictionary *plistDict = [NSDictionary dictionaryWithContentsOfFile:validPath];
        if (!plistDict || ![plistDict isKindOfClass:[NSDictionary class]]) {
            scopedAppsCacheTimestamp = [NSDate date];
            return scopedAppsCache;
        }
        
        NSDictionary *scopedApps = plistDict[@"ScopedApps"];
        if (!scopedApps || ![scopedApps isKindOfClass:[NSDictionary class]]) {
            scopedAppsCacheTimestamp = [NSDate date];
            return scopedAppsCache;
        }
        
        [scopedAppsCache addEntriesFromDictionary:scopedApps];
        scopedAppsCacheTimestamp = [NSDate date];
        
        return scopedAppsCache;
        
    } @catch (NSException *e) {
        scopedAppsCacheTimestamp = [NSDate date];
        return scopedAppsCache ?: [NSMutableDictionary dictionary];
    }
}

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
        
        id appEntry = scopedApps[bundleID];
        if (!appEntry || ![appEntry isKindOfClass:[NSDictionary class]]) {
            return NO;
        }
        
        return [appEntry[@"enabled"] boolValue];
        
    } @catch (NSException *e) {
        return NO;
    }
}

static BOOL shouldSpoofForBundle(NSString *bundleID) {
    if (!bundleID) return NO;
    if (!PXProcessIsAllowedForSpoofing(bundleID, [NSProcessInfo processInfo].processName, PXScopeOptionAllowSafariAuthStack)) {
        return NO;
    }
    // Prefer IdentifierManager when available; fall back to scope-only if class missing
    Class imClass = NSClassFromString(@"IdentifierManager");
    if (imClass) {
        IdentifierManager *manager = [imClass sharedManager];
        if (manager && ![manager isIdentifierEnabled:@"PasteboardUUID"]) {
            return NO;
        }
    }
    return YES;
}

static NSString *getSpoofedPasteboardUUID(void) {
    PasteboardUUIDManager *manager = [PasteboardUUIDManager sharedManager];
    NSString *uuid = [manager currentPasteboardUUID];
    
    if (uuid && uuid.length > 0) {
        return uuid;
    }
    
    uuid = [manager generatePasteboardUUID];
    if (uuid && uuid.length > 0) {
        return uuid;
    }
    
    NSString *identityDir = nil;
    NSArray *possibleProfilePaths = @[
        @"/var/mobile/Library/WeaponX/Profiles",
        @"/private/var/mobile/Library/WeaponX/Profiles"
    ];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *profileBasePath in possibleProfilePaths) {
        if ([fileManager fileExistsAtPath:profileBasePath]) {
            NSString *currentProfileInfoPath = [profileBasePath stringByAppendingPathComponent:@"current_profile_info.plist"];
            NSDictionary *currentProfileInfo = [NSDictionary dictionaryWithContentsOfFile:currentProfileInfoPath];
            NSString *profileId = currentProfileInfo[@"ProfileId"];
            
            if (profileId) {
                identityDir = [[profileBasePath stringByAppendingPathComponent:profileId] stringByAppendingPathComponent:@"identity"];
                break;
            }
        }
    }
    
    if (identityDir) {
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
        NSString *value = deviceIds[@"PasteboardUUID"];
        
        if (value) {
            PXLog(@"[WeaponX] 🔄 Got PasteboardUUID from device_ids.plist: %@", value);
            return value;
        }
        
        NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"pasteboard_uuid.plist"];
        NSDictionary *uuidDict = [NSDictionary dictionaryWithContentsOfFile:uuidPath];
        if (uuidDict && uuidDict[@"value"]) {
            PXLog(@"[WeaponX] 🔄 Got PasteboardUUID from pasteboard_uuid.plist: %@", uuidDict[@"value"]);
            return uuidDict[@"value"];
        }
    }
    
    uuid = [[NSUUID UUID] UUIDString];
    PXLog(@"[WeaponX] 🔄 Generated fallback PasteboardUUID: %@", uuid);
    return uuid;
}

static NSInteger getCustomChangeCount(NSString *bundleID, NSInteger originalCount) {
    if (!customChangeCountMap) {
        customChangeCountMap = [NSMutableDictionary dictionary];
    }
    
    NSNumber *currentValue = customChangeCountMap[bundleID];
    if (!currentValue) {
        customChangeCountMap[bundleID] = @(originalCount);
        return originalCount;
    }
    
    return [currentValue integerValue];
}

static void incrementCustomChangeCount(NSString *bundleID) {
    if (!customChangeCountMap) {
        customChangeCountMap = [NSMutableDictionary dictionary];
    }
    
    NSNumber *currentValue = customChangeCountMap[bundleID];
    NSInteger newValue = currentValue ? [currentValue integerValue] + 1 : 1;
    customChangeCountMap[bundleID] = @(newValue);
}

static NSString *getPasteboardContentHash(UIPasteboard *pasteboard) {
    @try {
        NSMutableString *hashInput = [NSMutableString string];
        
        NSArray *types = @[@"public.text", @"public.plain-text", @"public.utf8-plain-text"];
        for (NSString *type in types) {
            if ([pasteboard containsPasteboardTypes:@[type]]) {
                id value = [pasteboard valueForPasteboardType:type];
                if ([value isKindOfClass:[NSString class]]) {
                    [hashInput appendString:(NSString *)value];
                }
            }
        }
        
        if (pasteboard.image) {
            NSData *imageData = UIImagePNGRepresentation(pasteboard.image);
            if (imageData) {
                [hashInput appendFormat:@"IMG:%lu", (unsigned long)imageData.hash];
            }
        }
        
        if (pasteboard.URL) {
            [hashInput appendString:[pasteboard.URL absoluteString]];
        }
        
        return [NSString stringWithFormat:@"%lu", (unsigned long)[hashInput hash]];
        
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ⚠️ Exception computing pasteboard hash: %@", exception);
        return @"ERROR";
    }
}

static BOOL hasPasteboardContentChanged(NSString *bundleID, UIPasteboard *pasteboard) {
    @try {
        if (!lastKnownPasteboardData) {
            lastKnownPasteboardData = [NSMutableDictionary dictionary];
        }
        
        NSString *newHash = getPasteboardContentHash(pasteboard);
        NSString *oldHash = lastKnownPasteboardData[bundleID];
        
        lastKnownPasteboardData[bundleID] = newHash;
        
        return !oldHash || ![oldHash isEqualToString:newHash];
        
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ⚠️ Exception checking pasteboard changes: %@", exception);
        return NO;
    }
}

// Build deterministic custom pasteboard name from PasteboardUUID.
// General pasteboard name must never be rewritten by callers.
static NSString *deterministicPasteboardName(NSString *originalName, NSString *uuidString) {
    if (!originalName.length || !uuidString.length) {
        return originalName;
    }
    
    NSString *shortUUID = [uuidString componentsSeparatedByString:@"-"].firstObject;
    if (!shortUUID.length) {
        return originalName;
    }
    
    NSArray *components = [originalName componentsSeparatedByString:@"."];
    if (components.count > 0) {
        NSMutableArray *newComponents = [NSMutableArray arrayWithArray:components];
        newComponents[newComponents.count - 1] = shortUUID;
        return [newComponents componentsJoinedByString:@"."];
    }
    
    return [NSString stringWithFormat:@"%@.%@", originalName, shortUUID];
}

#pragma mark - Per-selector original IMPs

// Instance methods
static NSUUID *(*orig_uniquePasteboardUUID)(id, SEL) = NULL;
static NSString *(*orig_name)(id, SEL) = NULL;
static NSInteger (*orig_changeCount)(id, SEL) = NULL;
static void (*orig_setPersistent)(id, SEL, BOOL) = NULL;
static BOOL (*orig_isPersistent)(id, SEL) = NULL;
static NSArray *(*orig_itemProviders)(id, SEL) = NULL;
static NSArray *(*orig_itemSetWithPreferredPasteboardTypes)(id, SEL, NSArray *) = NULL;
static BOOL (*orig_containsPasteboardTypes)(id, SEL, NSArray *) = NULL;
static id (*orig_valueForPasteboardType)(id, SEL, NSString *) = NULL;
static void (*orig_setDataForPasteboardType)(id, SEL, NSData *, NSString *) = NULL;
static void (*orig_setItems)(id, SEL, NSArray *) = NULL;

// Class methods
static UIPasteboard *(*orig_generalPasteboard)(id, SEL) = NULL;
static UIPasteboard *(*orig_pasteboardWithNameCreate)(id, SEL, NSString *, BOOL) = NULL;
static UIPasteboard *(*orig_pasteboardWithUniqueName)(id, SEL) = NULL;
static UIPasteboard *(*orig_pasteboardWithURLCreate)(id, SEL, NSURL *, BOOL) = NULL;

#pragma mark - Hook implementations

static NSUUID *hook_uniquePasteboardUUID(id self, SEL _cmd) {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (shouldSpoofForBundle(bundleID)) {
            NSString *uuidString = getSpoofedPasteboardUUID();
            NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
            if (uuid) {
                PXLog(@"[WeaponX] 🔄 Spoofing Pasteboard UUID with: %@", uuidString);
                return uuid;
            }
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ⚠️ Exception in uniquePasteboardUUID hook: %@", exception);
    }
    
    if (orig_uniquePasteboardUUID) {
        return orig_uniquePasteboardUUID(self, _cmd);
    }
    return nil;
}

static NSString *hook_name(id self, SEL _cmd) {
    NSString *originalName = orig_name ? orig_name(self, _cmd) : nil;
    
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        // General pasteboard name must NOT change; only custom/unique pasteboards
        if (shouldSpoofForBundle(bundleID) && originalName &&
            ![originalName isEqualToString:@"com.apple.UIKit.pboard.general"]) {
            NSString *uuidString = getSpoofedPasteboardUUID();
            NSString *spoofedName = deterministicPasteboardName(originalName, uuidString);
            if (spoofedName && ![spoofedName isEqualToString:originalName]) {
                PXLog(@"[WeaponX] 🔄 Spoofing Pasteboard name from '%@' to '%@'", originalName, spoofedName);
                return spoofedName;
            }
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ⚠️ Exception in name hook: %@", exception);
    }
    
    return originalName;
}

static UIPasteboard *hook_generalPasteboard(id self, SEL _cmd) {
    UIPasteboard *original = orig_generalPasteboard ? orig_generalPasteboard(self, _cmd) : nil;
    
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (shouldSpoofForBundle(bundleID)) {
            PXLog(@"[WeaponX] 📋 Accessed general pasteboard from %@", bundleID);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ⚠️ Exception in generalPasteboard hook: %@", exception);
    }
    
    return original;
}

static UIPasteboard *hook_pasteboardWithNameCreate(id self, SEL _cmd, NSString *pasteboardName, BOOL create) {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (shouldSpoofForBundle(bundleID) && pasteboardName.length > 0 &&
            ![pasteboardName isEqualToString:@"com.apple.UIKit.pboard.general"]) {
            NSString *uuidString = getSpoofedPasteboardUUID();
            NSString *spoofedName = deterministicPasteboardName(pasteboardName, uuidString);
            if (spoofedName.length > 0) {
                PXLog(@"[WeaponX] 🔄 Creating pasteboard with spoofed name: %@ (original: %@)", spoofedName, pasteboardName);
                if (orig_pasteboardWithNameCreate) {
                    return orig_pasteboardWithNameCreate(self, _cmd, spoofedName, create);
                }
            }
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ⚠️ Exception in pasteboardWithName:create: hook: %@", exception);
    }
    
    if (orig_pasteboardWithNameCreate) {
        return orig_pasteboardWithNameCreate(self, _cmd, pasteboardName, create);
    }
    return nil;
}

static UIPasteboard *hook_pasteboardWithUniqueName(id self, SEL _cmd) {
    UIPasteboard *original = orig_pasteboardWithUniqueName ? orig_pasteboardWithUniqueName(self, _cmd) : nil;
    
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (shouldSpoofForBundle(bundleID) && original) {
            PXLog(@"[WeaponX] 📋 Created pasteboard with unique name from %@", bundleID);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ⚠️ Exception in pasteboardWithUniqueName hook: %@", exception);
    }
    
    return original;
}

static UIPasteboard *hook_pasteboardWithURLCreate(id self, SEL _cmd, NSURL *url, BOOL create) {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (shouldSpoofForBundle(bundleID) && url) {
            NSString *uuidString = getSpoofedPasteboardUUID();
            NSString *shortUUID = [uuidString componentsSeparatedByString:@"-"].firstObject;
            
            NSURL *spoofedURL = nil;
            NSString *originalURLString = [url absoluteString];
            
            if ([originalURLString containsString:@"?"]) {
                spoofedURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@&uuid=%@", originalURLString, shortUUID]];
            } else {
                spoofedURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?uuid=%@", originalURLString, shortUUID]];
            }
            
            if (!spoofedURL) {
                spoofedURL = url;
            }
            
            PXLog(@"[WeaponX] 🔄 Creating pasteboard with spoofed URL: %@ (original: %@)", spoofedURL, url);
            if (orig_pasteboardWithURLCreate) {
                return orig_pasteboardWithURLCreate(self, _cmd, spoofedURL, create);
            }
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ⚠️ Exception in pasteboardWithURL:create: hook: %@", exception);
    }
    
    if (orig_pasteboardWithURLCreate) {
        return orig_pasteboardWithURLCreate(self, _cmd, url, create);
    }
    return nil;
}

static NSInteger hook_changeCount(id self, SEL _cmd) {
    NSInteger originalCount = orig_changeCount ? orig_changeCount(self, _cmd) : 0;
    
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (shouldSpoofForBundle(bundleID)) {
            NSInteger spoofedCount = getCustomChangeCount(bundleID, originalCount);
            
            if (hasPasteboardContentChanged(bundleID, (UIPasteboard *)self)) {
                incrementCustomChangeCount(bundleID);
                spoofedCount = getCustomChangeCount(bundleID, originalCount);
            }
            
            PXLog(@"[WeaponX] 🔄 Spoofing pasteboard changeCount: %ld (original: %ld)",
                 (long)spoofedCount, (long)originalCount);
            return spoofedCount;
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ⚠️ Exception in changeCount hook: %@", exception);
    }
    
    return originalCount;
}

static void hook_setPersistent(id self, SEL _cmd, BOOL persistent) {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (shouldSpoofForBundle(bundleID)) {
            PXLog(@"[WeaponX] 📋 App %@ trying to set pasteboard persistence: %@",
                 bundleID, persistent ? @"YES" : @"NO");
            if (orig_setPersistent) {
                orig_setPersistent(self, _cmd, YES);
            }
            return;
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ⚠️ Exception in setPersistent: hook: %@", exception);
    }
    
    if (orig_setPersistent) {
        orig_setPersistent(self, _cmd, persistent);
    }
}

static BOOL hook_isPersistent(id self, SEL _cmd) {
    BOOL originalValue = orig_isPersistent ? orig_isPersistent(self, _cmd) : NO;
    
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (shouldSpoofForBundle(bundleID)) {
            PXLog(@"[WeaponX] 📋 App %@ checking pasteboard persistence", bundleID);
            return YES;
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ⚠️ Exception in isPersistent hook: %@", exception);
    }
    
    return originalValue;
}

static NSArray *hook_itemProviders(id self, SEL _cmd) {
    NSArray *originalProviders = orig_itemProviders ? orig_itemProviders(self, _cmd) : nil;
    
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (shouldSpoofForBundle(bundleID) && originalProviders) {
            PXLog(@"[WeaponX] 📋 App %@ accessing pasteboard item providers (%lu items)",
                 bundleID, (unsigned long)originalProviders.count);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ⚠️ Exception in itemProviders hook: %@", exception);
    }
    
    return originalProviders;
}

static NSArray *hook_itemSetWithPreferredPasteboardTypes(id self, SEL _cmd, NSArray *types) {
    NSArray *originalItemSet = orig_itemSetWithPreferredPasteboardTypes
        ? orig_itemSetWithPreferredPasteboardTypes(self, _cmd, types)
        : nil;
    
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (shouldSpoofForBundle(bundleID) && originalItemSet) {
            PXLog(@"[WeaponX] 📋 App %@ accessing pasteboard items with preferred types: %@",
                 bundleID, types);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ⚠️ Exception in itemSetWithPreferredPasteboardTypes: hook: %@", exception);
    }
    
    return originalItemSet;
}

static BOOL hook_containsPasteboardTypes(id self, SEL _cmd, NSArray *pasteboardTypes) {
    BOOL originalResult = orig_containsPasteboardTypes
        ? orig_containsPasteboardTypes(self, _cmd, pasteboardTypes)
        : NO;
    
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (shouldSpoofForBundle(bundleID) && pasteboardTypes) {
            if ([pasteboardTypes containsObject:@"com.apple.uikit.pboard-uuid"] ||
                [pasteboardTypes containsObject:@"com.apple.uikit.pboard-devices"]) {
                PXLog(@"[WeaponX] ⚠️ Possible fingerprinting: App %@ checking for special types: %@",
                      bundleID, pasteboardTypes);
            }
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ⚠️ Exception in containsPasteboardTypes: hook: %@", exception);
    }
    
    return originalResult;
}

static id hook_valueForPasteboardType(id self, SEL _cmd, NSString *pasteboardType) {
    id originalValue = orig_valueForPasteboardType
        ? orig_valueForPasteboardType(self, _cmd, pasteboardType)
        : nil;
    
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (shouldSpoofForBundle(bundleID) && pasteboardType) {
            if ([pasteboardType isEqualToString:@"com.apple.uikit.pboard-uuid"] ||
                [pasteboardType isEqualToString:@"com.apple.uikit.pboard-devices"] ||
                [pasteboardType containsString:@"uuid"] ||
                [pasteboardType containsString:@"device"]) {
                
                PXLog(@"[WeaponX] ⚠️ App %@ accessing potentially identifying pasteboard type: %@",
                      bundleID, pasteboardType);
                
                if ([pasteboardType isEqualToString:@"com.apple.uikit.pboard-uuid"]) {
                    NSString *spoofedUUID = getSpoofedPasteboardUUID();
                    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:spoofedUUID];
                    
                    NSError *archiveError = nil;
                    NSData *uuidData = nil;
                    
                    if (@available(iOS 12.0, *)) {
                        uuidData = [NSKeyedArchiver archivedDataWithRootObject:uuid requiringSecureCoding:NO error:&archiveError];
                        if (archiveError) {
                            PXLog(@"[WeaponX] ⚠️ Error archiving UUID data: %@", archiveError);
                        }
                    } else {
                        @try {
                            #pragma clang diagnostic push
                            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                            uuidData = [NSKeyedArchiver archivedDataWithRootObject:uuid];
                            #pragma clang diagnostic pop
                        } @catch (NSException *exception) {
                            PXLog(@"[WeaponX] ⚠️ Exception archiving UUID data: %@", exception);
                        }
                    }
                    
                    if (uuidData) {
                        return uuidData;
                    }
                }
            }
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ⚠️ Exception in valueForPasteboardType: hook: %@", exception);
    }
    
    return originalValue;
}

static void hook_setDataForPasteboardType(id self, SEL _cmd, NSData *data, NSString *pasteboardType) {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (shouldSpoofForBundle(bundleID)) {
            incrementCustomChangeCount(bundleID);
            PXLog(@"[WeaponX] 📋 App %@ setting pasteboard data for type: %@", bundleID, pasteboardType);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ⚠️ Exception in setData:forPasteboardType: hook: %@", exception);
    }
    
    if (orig_setDataForPasteboardType) {
        orig_setDataForPasteboardType(self, _cmd, data, pasteboardType);
    }
}

static void hook_setItems(id self, SEL _cmd, NSArray *items) {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (shouldSpoofForBundle(bundleID)) {
            incrementCustomChangeCount(bundleID);
            PXLog(@"[WeaponX] 📋 App %@ setting pasteboard items (%lu items)",
                 bundleID, (unsigned long)items.count);
        }
    } @catch (NSException *exception) {
        PXLog(@"[WeaponX] ⚠️ Exception in setItems: hook: %@", exception);
    }
    
    if (orig_setItems) {
        orig_setItems(self, _cmd, items);
    }
}

#pragma mark - Runtime installer

// Log unsupported-selector once, then continue.
static void logUnsupportedSelectorOnce(NSString *selectorName) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loggedUnsupportedSelectors = [NSMutableSet set];
    });
    
    @synchronized(loggedUnsupportedSelectors) {
        if (![loggedUnsupportedSelectors containsObject:selectorName]) {
            [loggedUnsupportedSelectors addObject:selectorName];
            PXLog(@"[PasteboardHooks] unsupported-selector: %@", selectorName);
        }
    }
}

// Compare type encodings loosely: accept exact match or same leading return/arg count pattern.
// Does not add selectors that don't exist.
static BOOL typeEncodingCompatible(const char *existing, const char *expected) {
    if (!existing || !expected) return NO;
    if (strcmp(existing, expected) == 0) return YES;
    
    // Allow minor encoding differences (e.g. optional signedness / architecture width)
    // by comparing return type and number of arguments after self/_cmd.
    // Fall back to requiring first character (return type) match.
    return existing[0] == expected[0];
}

// Install instance method hook if method exists and encoding is compatible.
// Stores original IMP in *outOrig. Never class_addMethod for missing selectors.
static BOOL installInstanceHook(Class cls, SEL sel, IMP replacement, IMP *outOrig, const char *expectedEncoding, NSString *label) {
    if (!cls || !sel || !replacement || !outOrig) return NO;
    
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) {
        logUnsupportedSelectorOnce(label ?: NSStringFromSelector(sel));
        return NO;
    }
    
    const char *encoding = method_getTypeEncoding(method);
    if (expectedEncoding && !typeEncodingCompatible(encoding, expectedEncoding)) {
        PXLog(@"[PasteboardHooks] type encoding mismatch for %@ (have=%s expected=%s)",
              label ?: NSStringFromSelector(sel), encoding ? encoding : "(null)", expectedEncoding);
        logUnsupportedSelectorOnce([NSString stringWithFormat:@"%@ (encoding)", label ?: NSStringFromSelector(sel)]);
        return NO;
    }
    
    MSHookMessageEx(cls, sel, replacement, outOrig);
    return (*outOrig != NULL);
}

// Install class method hook if method exists and encoding is compatible.
static BOOL installClassHook(Class cls, SEL sel, IMP replacement, IMP *outOrig, const char *expectedEncoding, NSString *label) {
    if (!cls || !sel || !replacement || !outOrig) return NO;
    
    Method method = class_getClassMethod(cls, sel);
    if (!method) {
        logUnsupportedSelectorOnce(label ?: NSStringFromSelector(sel));
        return NO;
    }
    
    const char *encoding = method_getTypeEncoding(method);
    if (expectedEncoding && !typeEncodingCompatible(encoding, expectedEncoding)) {
        PXLog(@"[PasteboardHooks] type encoding mismatch for +%@ (have=%s expected=%s)",
              label ?: NSStringFromSelector(sel), encoding ? encoding : "(null)", expectedEncoding);
        logUnsupportedSelectorOnce([NSString stringWithFormat:@"+%@ (encoding)", label ?: NSStringFromSelector(sel)]);
        return NO;
    }
    
    // Class methods live on the metaclass
    Class meta = object_getClass(cls);
    if (!meta) {
        logUnsupportedSelectorOnce(label ?: NSStringFromSelector(sel));
        return NO;
    }
    
    MSHookMessageEx(meta, sel, replacement, outOrig);
    return (*outOrig != NULL);
}

static void installPasteboardHooks(void) {
    Class pasteboardClass = objc_getClass("UIPasteboard");
    if (!pasteboardClass) {
        PXLog(@"[PasteboardHooks] unsupported-selector: UIPasteboard class missing");
        return;
    }
    
    // Public / commonly available paths
    installClassHook(pasteboardClass,
                     @selector(generalPasteboard),
                     (IMP)hook_generalPasteboard,
                     (IMP *)&orig_generalPasteboard,
                     NULL,
                     @"+generalPasteboard");
    
    installClassHook(pasteboardClass,
                     @selector(pasteboardWithName:create:),
                     (IMP)hook_pasteboardWithNameCreate,
                     (IMP *)&orig_pasteboardWithNameCreate,
                     NULL,
                     @"+pasteboardWithName:create:");
    
    installClassHook(pasteboardClass,
                     @selector(pasteboardWithUniqueName),
                     (IMP)hook_pasteboardWithUniqueName,
                     (IMP *)&orig_pasteboardWithUniqueName,
                     NULL,
                     @"+pasteboardWithUniqueName");
    
    installInstanceHook(pasteboardClass,
                        @selector(name),
                        (IMP)hook_name,
                        (IMP *)&orig_name,
                        NULL,
                        @"-name");
    
    installInstanceHook(pasteboardClass,
                        @selector(changeCount),
                        (IMP)hook_changeCount,
                        (IMP *)&orig_changeCount,
                        NULL,
                        @"-changeCount");
    
    installInstanceHook(pasteboardClass,
                        @selector(containsPasteboardTypes:),
                        (IMP)hook_containsPasteboardTypes,
                        (IMP *)&orig_containsPasteboardTypes,
                        NULL,
                        @"-containsPasteboardTypes:");
    
    installInstanceHook(pasteboardClass,
                        @selector(valueForPasteboardType:),
                        (IMP)hook_valueForPasteboardType,
                        (IMP *)&orig_valueForPasteboardType,
                        NULL,
                        @"-valueForPasteboardType:");
    
    installInstanceHook(pasteboardClass,
                        @selector(setData:forPasteboardType:),
                        (IMP)hook_setDataForPasteboardType,
                        (IMP *)&orig_setDataForPasteboardType,
                        NULL,
                        @"-setData:forPasteboardType:");
    
    installInstanceHook(pasteboardClass,
                        @selector(setItems:),
                        (IMP)hook_setItems,
                        (IMP *)&orig_setItems,
                        NULL,
                        @"-setItems:");
    
    // Optional / private / version-dependent selectors — install only if present
    // uniquePasteboardUUID is not guaranteed on all runtimes
    installInstanceHook(pasteboardClass,
                        @selector(uniquePasteboardUUID),
                        (IMP)hook_uniquePasteboardUUID,
                        (IMP *)&orig_uniquePasteboardUUID,
                        NULL,
                        @"-uniquePasteboardUUID");
    
    // pasteboardWithURL:create: is not available on all iOS versions
    SEL urlSel = NSSelectorFromString(@"pasteboardWithURL:create:");
    installClassHook(pasteboardClass,
                     urlSel,
                     (IMP)hook_pasteboardWithURLCreate,
                     (IMP *)&orig_pasteboardWithURLCreate,
                     NULL,
                     @"+pasteboardWithURL:create:");
    
    installInstanceHook(pasteboardClass,
                        @selector(setPersistent:),
                        (IMP)hook_setPersistent,
                        (IMP *)&orig_setPersistent,
                        NULL,
                        @"-setPersistent:");
    
    installInstanceHook(pasteboardClass,
                        @selector(isPersistent),
                        (IMP)hook_isPersistent,
                        (IMP *)&orig_isPersistent,
                        NULL,
                        @"-isPersistent");
    
    installInstanceHook(pasteboardClass,
                        @selector(itemProviders),
                        (IMP)hook_itemProviders,
                        (IMP *)&orig_itemProviders,
                        NULL,
                        @"-itemProviders");
    
    SEL itemSetSel = NSSelectorFromString(@"itemSetWithPreferredPasteboardTypes:");
    installInstanceHook(pasteboardClass,
                        itemSetSel,
                        (IMP)hook_itemSetWithPreferredPasteboardTypes,
                        (IMP *)&orig_itemSetWithPreferredPasteboardTypes,
                        NULL,
                        @"-itemSetWithPreferredPasteboardTypes:");
    
    PXLog(@"[PasteboardHooks] Runtime installer finished");
}

#pragma mark - Constructor

%ctor {
    @autoreleasepool {
        // Skip for system processes
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (PXIsWebKitHelperProcess(bundleID, proc)) {
            return;
        }
        if (!bundleID || !PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
            return;
        }
        
        // Initialize caches
        cachedBundleDecisions = [NSMutableDictionary dictionary];
        customChangeCountMap = [NSMutableDictionary dictionary];
        lastKnownPasteboardData = [NSMutableDictionary dictionary];
        
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
        
        // Install only selectors that exist; never blind %init of optional private APIs
        installPasteboardHooks();
        
        PXLog(@"[WeaponX] 📋 Initialized PasteboardHooks for %@", bundleID);
    }
}
