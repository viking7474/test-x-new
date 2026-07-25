#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ProjectXLogging.h"
#import <objc/runtime.h>
// #import <ellekit/ellekit.h> // Removed for rootful - using Substrate

#import "PXScope.h"
#import "PXRuntimeUtilities.h"
#import "PXPaths.h"
#import <os/lock.h>



// Theme value and timestamp are published as one lock-owned cache unit.
static os_unfair_lock gThemeCacheLock = OS_UNFAIR_LOCK_INIT;
static NSString *cachedThemeValue = nil;
static NSDate *cacheTimestamp = nil;
static NSTimeInterval kCacheValidityDuration = 300.0; // 5 minutes in seconds

// Forward declarations
static NSString *getCurrentBundleID(void);
static NSDictionary *loadScopedApps(void);
static BOOL isInScopedAppsList(void);

// Define the possible theme values
typedef NS_ENUM(NSInteger, WeaponXThemeStyle) {
    WeaponXThemeStyleUnspecified,
    WeaponXThemeStyleLight,
    WeaponXThemeStyleDark
};

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

// Helper function to check if we should spoof theme for this bundle ID (with caching)
static BOOL shouldSpoofForBundle(NSString *bundleID) {
    if (!bundleID) return NO;

    // SKIP theme spoofing for Safari/Auth stack to avoid text color conflicts
    // Safari WebKit has its own color management that conflicts with UIKit theme changes
    NSString *proc = [NSProcessInfo processInfo].processName;
    if (PXIsSafariStackProcess(bundleID, proc)) {
        return NO;  // Don't spoof theme for Safari - causes invisible text
    }
    return PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionNone);
}

// Helper function to get theme value from profile
static WeaponXThemeStyle getThemeStyleFromProfile(void) {
    NSDate *now = [NSDate date];
    os_unfair_lock_lock(&gThemeCacheLock);
    NSString *cachedValue = cachedThemeValue;
    NSDate *loadedAt = cacheTimestamp;
    os_unfair_lock_unlock(&gThemeCacheLock);

    if (cachedValue.length && loadedAt && [now timeIntervalSinceDate:loadedAt] <= kCacheValidityDuration) {
        if ([cachedValue isEqualToString:@"Dark"]) return WeaponXThemeStyleDark;
        if ([cachedValue isEqualToString:@"Light"]) return WeaponXThemeStyleLight;
    }

    NSString *identityPath = PXActiveProfileIdentityPath();
    NSString *deviceIDsPath = PXActiveProfileDeviceIDsPath();
    NSDictionary *deviceIDs = deviceIDsPath.length
        ? [NSDictionary dictionaryWithContentsOfFile:deviceIDsPath]
        : nil;
    NSString *themeValue = [deviceIDs[@"DeviceTheme"] isKindOfClass:[NSString class]]
        ? deviceIDs[@"DeviceTheme"]
        : nil;
    if (!themeValue.length && identityPath.length) {
        NSDictionary *themeInfo = [NSDictionary dictionaryWithContentsOfFile:
            [identityPath stringByAppendingPathComponent:@"device_theme.plist"]];
        themeValue = [themeInfo[@"value"] isKindOfClass:[NSString class]] ? themeInfo[@"value"] : nil;
    }
    if (!themeValue.length) themeValue = @"Light";

    os_unfair_lock_lock(&gThemeCacheLock);
    cachedThemeValue = [themeValue copy];
    cacheTimestamp = now;
    os_unfair_lock_unlock(&gThemeCacheLock);

    if ([themeValue isEqualToString:@"Dark"]) return WeaponXThemeStyleDark;
    if ([themeValue isEqualToString:@"Light"]) return WeaponXThemeStyleLight;
    return WeaponXThemeStyleUnspecified;
}

// UIUserInterfaceStyle mapping function
static UIUserInterfaceStyle mapThemeStyleToUIUserInterfaceStyle(WeaponXThemeStyle themeStyle) {
    switch (themeStyle) {
        case WeaponXThemeStyleDark:
            return UIUserInterfaceStyleDark;
        case WeaponXThemeStyleLight:
            return UIUserInterfaceStyleLight;
        case WeaponXThemeStyleUnspecified:
        default:
            return UIUserInterfaceStyleUnspecified;
    }
}

// Hook definitions
%group ThemeHooks

// Hook UITraitCollection to intercept userInterfaceStyle
%hook UITraitCollection

// Method for getting userInterfaceStyle property
- (UIUserInterfaceStyle)userInterfaceStyle {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    // Check if spoofing is needed for this app
    if (bundleID && shouldSpoofForBundle(bundleID)) {
        WeaponXThemeStyle themeStyle = getThemeStyleFromProfile();
        
        if (themeStyle != WeaponXThemeStyleUnspecified) {
            UIUserInterfaceStyle spoofedStyle = mapThemeStyleToUIUserInterfaceStyle(themeStyle);
            
            // Log the first time we spoof for an app (to reduce spam).
            if (PXLogOnceClaim(@"ThemeHooks.bundle", bundleID)) {
                PXLog(@"[WeaponX] Spoofing device theme for %@ to: %@",
                      bundleID,
                      (spoofedStyle == UIUserInterfaceStyleDark) ? @"Dark" : @"Light");
            }
            
            return spoofedStyle;
        }
    }
    
    // Return original value if not spoofing
    return %orig;
}

// For iOS 17, there's a new named retrieval method
- (UIUserInterfaceStyle)effectiveUserInterfaceStyle {
    if (@available(iOS 17.0, *)) {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        // Check if spoofing is needed for this app
        if (bundleID && shouldSpoofForBundle(bundleID)) {
            WeaponXThemeStyle themeStyle = getThemeStyleFromProfile();
            
            if (themeStyle != WeaponXThemeStyleUnspecified) {
                return mapThemeStyleToUIUserInterfaceStyle(themeStyle);
            }
        }
    }
    
    // Return original value if not spoofing
    return %orig;
}

%end

// Hook UIScreen to intercept system-wide theme setting
%hook UIScreen

- (UITraitCollection *)traitCollection {
    UITraitCollection *originalTraitCollection = %orig;
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    // Check if we need to spoof
    if (bundleID && shouldSpoofForBundle(bundleID)) {
        WeaponXThemeStyle themeStyle = getThemeStyleFromProfile();
        
        if (themeStyle != WeaponXThemeStyleUnspecified) {
            // Create a trait collection with our spoofed interface style
            UIUserInterfaceStyle spoofedStyle = mapThemeStyleToUIUserInterfaceStyle(themeStyle);
            
            UITraitCollection *interfaceStyleTrait = [UITraitCollection traitCollectionWithUserInterfaceStyle:spoofedStyle];
            
            // Merge with original trait collection to preserve other traits
            return [UITraitCollection traitCollectionWithTraitsFromCollections:@[originalTraitCollection, interfaceStyleTrait]];
        }
    }
    
    return originalTraitCollection;
}

%end

// Hook UIView for apps that check theme at the view level
%hook UIView

- (UITraitCollection *)traitCollection {
    UITraitCollection *originalTraitCollection = %orig;
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    // Check if we need to spoof
    if (bundleID && shouldSpoofForBundle(bundleID)) {
        WeaponXThemeStyle themeStyle = getThemeStyleFromProfile();
        
        if (themeStyle != WeaponXThemeStyleUnspecified) {
            // Create a trait collection with our spoofed interface style
            UIUserInterfaceStyle spoofedStyle = mapThemeStyleToUIUserInterfaceStyle(themeStyle);
            
            UITraitCollection *interfaceStyleTrait = [UITraitCollection traitCollectionWithUserInterfaceStyle:spoofedStyle];
            
            // Merge with original trait collection to preserve other traits
            return [UITraitCollection traitCollectionWithTraitsFromCollections:@[originalTraitCollection, interfaceStyleTrait]];
        }
    }
    
    return originalTraitCollection;
}

%end

// Hook UIViewController for apps that check theme at the controller level
%hook UIViewController

- (UITraitCollection *)traitCollection {
    UITraitCollection *originalTraitCollection = %orig;
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    // Check if we need to spoof
    if (bundleID && shouldSpoofForBundle(bundleID)) {
        WeaponXThemeStyle themeStyle = getThemeStyleFromProfile();
        
        if (themeStyle != WeaponXThemeStyleUnspecified) {
            // Create a trait collection with our spoofed interface style
            UIUserInterfaceStyle spoofedStyle = mapThemeStyleToUIUserInterfaceStyle(themeStyle);
            
            UITraitCollection *interfaceStyleTrait = [UITraitCollection traitCollectionWithUserInterfaceStyle:spoofedStyle];
            
            // Merge with original trait collection to preserve other traits
            return [UITraitCollection traitCollectionWithTraitsFromCollections:@[originalTraitCollection, interfaceStyleTrait]];
        }
    }
    
    return originalTraitCollection;
}

%end

// Hook any WebKit bridges for web detection of dark mode
%hook WKWebView

// Hook preferredColorScheme for WebKit
- (void)_setPreferredColorScheme:(NSInteger)colorScheme {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    // Check if we need to spoof
    if (bundleID && shouldSpoofForBundle(bundleID)) {
        WeaponXThemeStyle themeStyle = getThemeStyleFromProfile();
        
        if (themeStyle != WeaponXThemeStyleUnspecified) {
            // Map our theme style to WebKit's color scheme values (0 = light, 1 = dark)
            NSInteger spoofedColorScheme = (themeStyle == WeaponXThemeStyleDark) ? 1 : 0;
            %orig(spoofedColorScheme);
            return;
        }
    }
    
    %orig;
}

%end

%end // End of ThemeHooks group

// Notification handler to refresh theme settings when toggled
static void themeSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    PXInvalidateScopeDecisionCache();
    NSString *notificationName = (__bridge NSString *)name;
    PXLog(@"[WeaponX] Received settings notification: %@", notificationName);
    
    os_unfair_lock_lock(&gThemeCacheLock);
    cachedThemeValue = nil;
    cacheTimestamp = nil;
    os_unfair_lock_unlock(&gThemeCacheLock);
}

// Constructor to initialize hooks
%ctor {
    @autoreleasepool {
        @try {
            PXLog(@"[ThemeHooks] Initializing theme hooks");
            
            NSString *bundleID = getCurrentBundleID();
            
            // Skip if we can't get bundle ID
            if (!bundleID || [bundleID length] == 0) {
                return;
            }
            
            // Don't hook our own apps
            if ([bundleID isEqualToString:@"com.hydra.projectx"] ||
                [bundleID isEqualToString:@"com.hydra.weaponx"]) {
                return;
            }

            // Don't hook system processes - including Safari (theme spoofing causes text issues)
            // Note: We deliberately skip Safari for theme hooks even if Safari Spoofing is enabled, 
            // because theme spoofing causes invisible text in WebKit forms (Dark mode text on Light mode background).
            if (!PXProcessIsAllowedForSpoofing(bundleID, [NSProcessInfo processInfo].processName, PXScopeOptionNone)) {
                PXLog(@"[ThemeHooks] App %@ is not scoped, skipping hook installation", bundleID);
                return;
            }
            
            PXLog(@"[ThemeHooks] App %@ is scoped, setting up theme hooks", bundleID);
            
            // Initialize hooks for scoped apps only
            %init(ThemeHooks);
            
            // Register for theme spoofing toggle notification
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                themeSettingsChanged,
                CFSTR("com.hydra.projectx.toggleDeviceThemeSpoof"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
            
            // Also register for general settings and profile change notifications
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                themeSettingsChanged,
                CFSTR("com.hydra.projectx.settings.changed"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
            
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                themeSettingsChanged,
                CFSTR("com.hydra.projectx.profileChanged"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                themeSettingsChanged,
                CFSTR("com.hydra.projectx.scopedAppsChanged"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
            
            PXLog(@"[ThemeHooks] Theme hooks successfully initialized for scoped app: %@", bundleID);
            
        } @catch (NSException *e) {
            PXLog(@"[ThemeHooks] ❌ Exception in constructor: %@", e);
        }
    }
} 
