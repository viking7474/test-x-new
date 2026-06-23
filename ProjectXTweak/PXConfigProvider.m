// PXConfigProvider.m

#import "PXConfigProvider.h"
#import "PXScope.h"
#import <objc/message.h>
#import "ProjectXLogging.h"

// Immutable Snapshot Model
@interface PXConfigSnapshot : NSObject
@property (nonatomic, strong, readonly) NSDictionary *deviceIdsCache;
@property (nonatomic, strong, readonly) NSDictionary *wifiInfoCache;
@property (nonatomic, assign, readonly) BOOL isDeviceModelSpoofingEnabled;
@property (nonatomic, assign, readonly) BOOL isSystemBootUUIDSpoofingEnabled;
@property (nonatomic, assign, readonly) BOOL isDyldCacheUUIDSpoofingEnabled;
@property (nonatomic, assign, readonly) BOOL isWiFiSpoofingEnabled;
@property (nonatomic, assign, readonly) BOOL valid;
@property (nonatomic, strong, readonly) NSDictionary *currentProfileInfo;

- (instancetype)initWithDeviceIds:(NSDictionary *)deviceIds
                         wifiInfo:(NSDictionary *)wifiInfo
               currentProfileInfo:(NSDictionary *)currentProfileInfo
                            valid:(BOOL)valid
                 deviceModelEnabled:(BOOL)deviceModelEnabled
            systemBootUUIDEnabled:(BOOL)systemBootUUIDEnabled
             dyldCacheUUIDEnabled:(BOOL)dyldCacheUUIDEnabled
                      wifiEnabled:(BOOL)wifiEnabled;
@end

@implementation PXConfigSnapshot
- (instancetype)initWithDeviceIds:(NSDictionary *)deviceIds
                         wifiInfo:(NSDictionary *)wifiInfo
               currentProfileInfo:(NSDictionary *)currentProfileInfo
                            valid:(BOOL)valid
                 deviceModelEnabled:(BOOL)deviceModelEnabled
            systemBootUUIDEnabled:(BOOL)systemBootUUIDEnabled
             dyldCacheUUIDEnabled:(BOOL)dyldCacheUUIDEnabled
                      wifiEnabled:(BOOL)wifiEnabled {
    if (self = [super init]) {
        _deviceIdsCache = [deviceIds copy] ?: @{};
        _wifiInfoCache = [wifiInfo copy] ?: @{};
        _currentProfileInfo = [currentProfileInfo copy] ?: @{};
        _valid = valid;
        _isDeviceModelSpoofingEnabled = deviceModelEnabled;
        _isSystemBootUUIDSpoofingEnabled = systemBootUUIDEnabled;
        _isDyldCacheUUIDSpoofingEnabled = dyldCacheUUIDEnabled;
        _isWiFiSpoofingEnabled = wifiEnabled;
    }
    return self;
}
@end

@interface PXConfigProvider ()
@property (atomic, strong) PXConfigSnapshot *currentSnapshot;
@end

@implementation PXConfigProvider

+ (instancetype)sharedProvider {
    static PXConfigProvider *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initial load
        [self reloadConfig];

        // Listen to potential Darwin notifications to reload
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        (__bridge const void *)(self),
                                        reloadConfigCallback,
                                        PX_NOTIFICATION_CONFIG_CHANGED,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        (__bridge const void *)(self),
                                        reloadConfigCallback,
                                        PX_NOTIFICATION_SCOPE_CHANGED,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        (__bridge const void *)(self),
                                        reloadConfigCallback,
                                        CFSTR("com.hydra.projectx.config_changed"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        // Backward compatibility until Phase 4 is complete
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        (__bridge const void *)(self),
                                        reloadConfigCallback,
                                        CFSTR("com.hydra.projectx.settings_changed"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        (__bridge const void *)(self),
                                        reloadConfigCallback,
                                        CFSTR("com.hydra.projectx.toggleWifiSpoof"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    return self;
}

static void reloadConfigCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    PXConfigProvider *provider = (__bridge PXConfigProvider *)observer;
    [provider reloadConfig];
}

- (PXConfigSnapshot *)buildSnapshotFromDisk {
    NSString *profilesPath = @"/var/mobile/Library/WeaponX/Profiles";
    NSString *centralInfoPath = [profilesPath stringByAppendingPathComponent:@"current_profile_info.plist"];
    NSDictionary *centralInfo = [NSDictionary dictionaryWithContentsOfFile:centralInfoPath];
    NSString *profileId = centralInfo[@"ProfileId"];

    BOOL valid = YES;
    if (!profileId || profileId.length == 0) {
        valid = NO;
    }

    NSDictionary *deviceIds = @{};
    NSDictionary *wifiInfo = @{};
    if (profileId.length > 0) {
        NSString *identityDir = [[profilesPath stringByAppendingPathComponent:profileId] stringByAppendingPathComponent:@"identity"];

        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
        if (!deviceIds) {
            deviceIds = @{};
            // If we can't read device_ids.plist but we have a profile, the snapshot might be invalid or partially written.
            valid = NO;
        }

        NSString *wifiPath = [identityDir stringByAppendingPathComponent:@"wifi_info.plist"];
        wifiInfo = [NSDictionary dictionaryWithContentsOfFile:wifiPath] ?: @{};
    }

    BOOL shouldSpoofModel = NO;
    BOOL shouldSpoofBootUUID = NO;
    BOOL shouldSpoofDyldUUID = NO;
    BOOL shouldSpoofWiFi = NO;

    NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (currentBundleID && NSClassFromString(@"IdentifierManager")) {
        id manager = [NSClassFromString(@"IdentifierManager") performSelector:@selector(sharedManager)];
        if (manager) {
            BOOL isAppEnabled = ((BOOL(*)(id, SEL, id))objc_msgSend)(manager, @selector(isApplicationEnabled:), currentBundleID);
            if (isAppEnabled) {
                shouldSpoofModel = ((BOOL(*)(id, SEL, id))objc_msgSend)(manager, @selector(isIdentifierEnabled:), @"DeviceModel");
                shouldSpoofBootUUID = ((BOOL(*)(id, SEL, id))objc_msgSend)(manager, @selector(isIdentifierEnabled:), @"SystemBootUUID");
                shouldSpoofDyldUUID = ((BOOL(*)(id, SEL, id))objc_msgSend)(manager, @selector(isIdentifierEnabled:), @"DyldCacheUUID");
                shouldSpoofWiFi = ((BOOL(*)(id, SEL, id))objc_msgSend)(manager, @selector(isIdentifierEnabled:), @"WiFi");
            }
        }
    }

    return [[PXConfigSnapshot alloc] initWithDeviceIds:deviceIds
                                              wifiInfo:wifiInfo
                                    currentProfileInfo:centralInfo
                                                 valid:valid
                                    deviceModelEnabled:shouldSpoofModel
                                 systemBootUUIDEnabled:shouldSpoofBootUUID
                                  dyldCacheUUIDEnabled:shouldSpoofDyldUUID
                                           wifiEnabled:shouldSpoofWiFi];
}

- (void)reloadConfig {
    @try {
        PXConfigSnapshot *next = [self buildSnapshotFromDisk];

        if (!next || !next.valid) {
            // Keep the old snapshot to prevent leaking original values
            PXLog(@"[PXConfigProvider] Invalid reload, keeping old snapshot");
            return;
        }

        // Atomic swap
        self.currentSnapshot = next;



    } @catch (NSException *e) {
        PXLog(@"[PXConfigProvider] Error reloading config: %@", e);
    }
}

- (NSString *)spoofedDeviceModel {
    PXConfigSnapshot *snap = self.currentSnapshot;
    NSString *model = snap.deviceIdsCache[@"DeviceModel"];
    // Fail-Closed Fallback
    return [model isKindOfClass:[NSString class]] && model.length > 0 ? model : @"iPhone14,5"; // Default safe fallback
}

- (NSString *)spoofedGPUFamily {
    PXConfigSnapshot *snap = self.currentSnapshot;
    NSString *gpu = snap.deviceIdsCache[@"GPUFamily"];
    if (![gpu isKindOfClass:[NSString class]] || gpu.length == 0) {
        gpu = snap.deviceIdsCache[@"WebGLRenderer"];
    }
    // Fail-Closed Fallback
    return [gpu isKindOfClass:[NSString class]] && gpu.length > 0 ? gpu : @"Apple A15 GPU";
}

- (NSString *)spoofedIDFA {
    // Implement fail-closed behavior when properly integrated
    return @"00000000-0000-0000-0000-000000000000";
}

- (NSString *)spoofedIDFV {
    return @"00000000-0000-0000-0000-000000000000";
}

- (NSString *)spoofedBoardID {
    PXConfigSnapshot *snap = self.currentSnapshot;
    NSString *boardID = snap.deviceIdsCache[@"BoardID"];
    return [boardID isKindOfClass:[NSString class]] && boardID.length > 0 ? boardID : @"D63AP";
}

- (NSString *)spoofedHwModel {
    PXConfigSnapshot *snap = self.currentSnapshot;
    NSString *hwModel = snap.deviceIdsCache[@"HwModel"];
    return [hwModel isKindOfClass:[NSString class]] && hwModel.length > 0 ? hwModel : @"D63AP";
}

- (NSString *)spoofedDeviceName {
    PXConfigSnapshot *snap = self.currentSnapshot;
    NSString *deviceName = snap.deviceIdsCache[@"DeviceName"];
    return [deviceName isKindOfClass:[NSString class]] && deviceName.length > 0 ? deviceName : @"iPhone";
}

- (NSString *)spoofedIOSBuild {
    PXConfigSnapshot *snap = self.currentSnapshot;
    NSString *iosBuild = snap.deviceIdsCache[@"IOSBuild"];
    if (![iosBuild isKindOfClass:[NSString class]] || iosBuild.length == 0) {
        id versionClass = NSClassFromString(@"IOSVersionInfo");
        id versionMgr = versionClass ? [versionClass performSelector:@selector(sharedManager)] : nil;
        if (versionMgr && [versionMgr respondsToSelector:@selector(currentIOSVersionInfo)]) {
            NSDictionary *current = [versionMgr performSelector:@selector(currentIOSVersionInfo)];
            iosBuild = current[@"build"];
        }
    }
    return [iosBuild isKindOfClass:[NSString class]] && iosBuild.length > 0 ? iosBuild : @"19H12";
}

- (NSString *)spoofedDarwin {
    PXConfigSnapshot *snap = self.currentSnapshot;
    NSString *darwin = snap.deviceIdsCache[@"Darwin"];
    if (![darwin isKindOfClass:[NSString class]] || darwin.length == 0) {
        id versionClass = NSClassFromString(@"IOSVersionInfo");
        id versionMgr = versionClass ? [versionClass performSelector:@selector(sharedManager)] : nil;
        if (versionMgr && [versionMgr respondsToSelector:@selector(currentIOSVersionInfo)]) {
            NSDictionary *current = [versionMgr performSelector:@selector(currentIOSVersionInfo)];
            darwin = current[@"darwin"];
        }
    }
    return [darwin isKindOfClass:[NSString class]] && darwin.length > 0 ? darwin : @"Darwin Kernel Version 21.6.0: Wed Aug 10 14:28:23 PDT 2022; root:xnu-8020.141.5~2/RELEASE_ARM64_T8101";
}

- (NSString *)spoofedKernelVersion {
    PXConfigSnapshot *snap = self.currentSnapshot;
    NSString *kernelVersion = snap.deviceIdsCache[@"KernelVersion"];
    if (![kernelVersion isKindOfClass:[NSString class]] || kernelVersion.length == 0) {
        id versionClass = NSClassFromString(@"IOSVersionInfo");
        id versionMgr = versionClass ? [versionClass performSelector:@selector(sharedManager)] : nil;
        if (versionMgr && [versionMgr respondsToSelector:@selector(currentIOSVersionInfo)]) {
            NSDictionary *current = [versionMgr performSelector:@selector(currentIOSVersionInfo)];
            kernelVersion = current[@"kernel_version"];
        }
    }
    return [kernelVersion isKindOfClass:[NSString class]] && kernelVersion.length > 0 ? kernelVersion : @"Darwin Kernel Version 21.6.0";
}

- (NSDictionary *)spoofedSpecs {
    PXConfigSnapshot *snap = self.currentSnapshot;
    NSDictionary *deviceIds = snap.deviceIdsCache;
    NSMutableDictionary *specs = [NSMutableDictionary dictionary];
    if (deviceIds && deviceIds[@"DeviceModel"]) {
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
    }
    return specs;
}

- (NSString *)spoofedBootTime {
    return nil;
}

- (BOOL)isDeviceModelSpoofingEnabledForCurrentProcess {
    return self.currentSnapshot.isDeviceModelSpoofingEnabled;
}


- (NSString *)spoofedSystemBootUUID {
    PXConfigSnapshot *snap = self.currentSnapshot;
    NSString *uuid = snap.deviceIdsCache[@"SystemBootUUID"];
    return [uuid isKindOfClass:[NSString class]] && uuid.length > 0 ? uuid : @"00000000-0000-0000-0000-000000000000";
}

- (NSString *)spoofedDyldCacheUUID {
    PXConfigSnapshot *snap = self.currentSnapshot;
    NSString *uuid = snap.deviceIdsCache[@"DyldCacheUUID"];
    return [uuid isKindOfClass:[NSString class]] && uuid.length > 0 ? uuid : @"00000000-0000-0000-0000-000000000000";
}

- (BOOL)isSystemBootUUIDSpoofingEnabledForCurrentProcess {
    return self.currentSnapshot.isSystemBootUUIDSpoofingEnabled;
}

- (BOOL)isDyldCacheUUIDSpoofingEnabledForCurrentProcess {
    return self.currentSnapshot.isDyldCacheUUIDSpoofingEnabled;
}

- (NSString *)spoofedWiFiBSSID {
    PXConfigSnapshot *snap = self.currentSnapshot;
    NSString *bssid = snap.wifiInfoCache[@"BSSID"];
    return [bssid isKindOfClass:[NSString class]] && bssid.length > 0 ? bssid : @"00:00:00:00:00:00";
}

- (NSString *)spoofedWiFiSSID {
    PXConfigSnapshot *snap = self.currentSnapshot;
    NSString *ssid = snap.wifiInfoCache[@"SSID"];
    return [ssid isKindOfClass:[NSString class]] && ssid.length > 0 ? ssid : @"Apple Network";
}

- (BOOL)isWiFiSpoofingEnabledForCurrentProcess {
    return self.currentSnapshot.isWiFiSpoofingEnabled;
}

- (void)dealloc {
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), PX_NOTIFICATION_CONFIG_CHANGED, NULL);
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), PX_NOTIFICATION_SCOPE_CHANGED, NULL);
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), CFSTR("com.hydra.projectx.config_changed"), NULL);
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), CFSTR("com.hydra.projectx.settings_changed"), NULL);
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), CFSTR("com.hydra.projectx.toggleWifiSpoof"), NULL);
}

@end

NSString *PXGetSpoofedDeviceModel(void) {
    return [[PXConfigProvider sharedProvider] spoofedDeviceModel];
}

NSString *PXGetSpoofedGPUFamily(void) {
    return [[PXConfigProvider sharedProvider] spoofedGPUFamily];
}

BOOL PXIsDeviceModelSpoofingEnabled(void) {
    return [[PXConfigProvider sharedProvider] isDeviceModelSpoofingEnabledForCurrentProcess];
}

NSString *PXGetSpoofedSystemBootUUID(void) { return [[PXConfigProvider sharedProvider] spoofedSystemBootUUID]; }
NSString *PXGetSpoofedDyldCacheUUID(void) { return [[PXConfigProvider sharedProvider] spoofedDyldCacheUUID]; }
BOOL PXIsSystemBootUUIDSpoofingEnabled(void) { return [[PXConfigProvider sharedProvider] isSystemBootUUIDSpoofingEnabledForCurrentProcess]; }
BOOL PXIsDyldCacheUUIDSpoofingEnabled(void) { return [[PXConfigProvider sharedProvider] isDyldCacheUUIDSpoofingEnabledForCurrentProcess]; }

NSString *PXGetSpoofedWiFiBSSID(void) { return [[PXConfigProvider sharedProvider] spoofedWiFiBSSID]; }
NSString *PXGetSpoofedWiFiSSID(void) { return [[PXConfigProvider sharedProvider] spoofedWiFiSSID]; }
BOOL PXIsWiFiSpoofingEnabled(void) { return [[PXConfigProvider sharedProvider] isWiFiSpoofingEnabledForCurrentProcess]; }

NSString *PXGetSpoofedBoardID(void) { return [[PXConfigProvider sharedProvider] spoofedBoardID]; }
NSString *PXGetSpoofedHwModel(void) { return [[PXConfigProvider sharedProvider] spoofedHwModel]; }
NSString *PXGetSpoofedDeviceName(void) { return [[PXConfigProvider sharedProvider] spoofedDeviceName]; }
NSString *PXGetSpoofedIOSBuild(void) { return [[PXConfigProvider sharedProvider] spoofedIOSBuild]; }
NSString *PXGetSpoofedDarwin(void) { return [[PXConfigProvider sharedProvider] spoofedDarwin]; }
NSString *PXGetSpoofedKernelVersion(void) { return [[PXConfigProvider sharedProvider] spoofedKernelVersion]; }

NSDictionary *PXGetSpoofedSpecs(void) { return [[PXConfigProvider sharedProvider] spoofedSpecs]; }
