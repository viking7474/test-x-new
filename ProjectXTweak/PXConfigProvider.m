// PXConfigProvider.m

#import "PXConfigProvider.h"
#import "PXScope.h"
#import <objc/message.h>
#import "ProjectXLogging.h"

// Immutable Snapshot Model
@interface PXConfigSnapshot : NSObject
@property (nonatomic, strong, readonly) NSDictionary *deviceIdsCache;
@property (nonatomic, assign, readonly) BOOL isDeviceModelSpoofingEnabled;

- (instancetype)initWithDeviceIds:(NSDictionary *)deviceIds
                       appEnabled:(BOOL)appEnabled;
@end

@implementation PXConfigSnapshot
- (instancetype)initWithDeviceIds:(NSDictionary *)deviceIds
                       appEnabled:(BOOL)appEnabled {
    if (self = [super init]) {
        _deviceIdsCache = [deviceIds copy] ?: @{};
        _isDeviceModelSpoofingEnabled = appEnabled;
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
                                        CFSTR("com.hydra.projectx.config_changed"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    return self;
}

static void reloadConfigCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    PXConfigProvider *provider = (__bridge PXConfigProvider *)observer;
    [provider reloadConfig];
}

- (void)reloadConfig {
    @try {
        NSString *profilesPath = @"/var/mobile/Library/WeaponX/Profiles";
        NSString *centralInfoPath = [profilesPath stringByAppendingPathComponent:@"current_profile_info.plist"];
        NSDictionary *centralInfo = [NSDictionary dictionaryWithContentsOfFile:centralInfoPath];
        NSString *profileId = centralInfo[@"ProfileId"];

        NSDictionary *deviceIds = @{};
        if (profileId.length > 0) {
            NSString *identityDir = [[profilesPath stringByAppendingPathComponent:profileId] stringByAppendingPathComponent:@"identity"];
            NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
            deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: @{};
        }

        // Calculate app enablement at reload time
        BOOL shouldSpoof = NO;
        NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (currentBundleID) {
            if (NSClassFromString(@"IdentifierManager")) {
                id manager = [NSClassFromString(@"IdentifierManager") performSelector:@selector(sharedManager)];
                if (manager) {
                    BOOL isAppEnabled = ((BOOL(*)(id, SEL, id))objc_msgSend)(manager, @selector(isApplicationEnabled:), currentBundleID);
                    BOOL isIdEnabled = ((BOOL(*)(id, SEL, id))objc_msgSend)(manager, @selector(isIdentifierEnabled:), @"DeviceModel");
                    if (isAppEnabled && isIdEnabled) {
                        shouldSpoof = YES;
                    }
                }
            }
        }

        // Atomic swap
        self.currentSnapshot = [[PXConfigSnapshot alloc] initWithDeviceIds:deviceIds appEnabled:shouldSpoof];
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

- (NSString *)spoofedBootTime {
    return nil;
}

- (BOOL)isDeviceModelSpoofingEnabledForCurrentProcess {
    return self.currentSnapshot.isDeviceModelSpoofingEnabled;
}

- (void)dealloc {
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), CFSTR("com.hydra.projectx.config_changed"), NULL);
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
