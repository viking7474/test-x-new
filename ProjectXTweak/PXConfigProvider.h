// PXConfigProvider.h
// Centralized configuration provider for ProjectX hooks
// Replaces scattered direct file reads and duplicates.

#import <Foundation/Foundation.h>

@interface PXConfigProvider : NSObject

+ (instancetype)sharedProvider;

// Reloads the cache from disk.
// Can be called periodically or triggered by Darwin notifications.
- (void)reloadConfig;

// Common device spoofing properties
- (NSString *)spoofedDeviceModel;
- (NSString *)spoofedGPUFamily;
- (NSString *)spoofedIDFA;
- (NSString *)spoofedIDFV;
- (NSString *)spoofedBootTime;

// Convenience boolean checks if you want centralized global toggles
- (BOOL)isDeviceModelSpoofingEnabledForCurrentProcess;

- (NSString *)spoofedSystemBootUUID;
- (NSString *)spoofedDyldCacheUUID;
- (BOOL)isSystemBootUUIDSpoofingEnabledForCurrentProcess;
- (BOOL)isDyldCacheUUIDSpoofingEnabledForCurrentProcess;

// WiFi Spoofing properties
- (NSString *)spoofedWiFiBSSID;
- (NSString *)spoofedWiFiSSID;
- (BOOL)isWiFiSpoofingEnabledForCurrentProcess;


@end
