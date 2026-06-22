// PXConfigProvider.m

#import "PXConfigProvider.h"
#import "PXScope.h"
#import <objc/message.h>
#import "ProjectXLogging.h"

static NSString * const kPXConfigCacheValidityTimestampKey = @"PXConfigCacheValidityTimestamp";
static const NSTimeInterval kPXConfigCacheDuration = 300.0; // 5 minutes cache

@interface PXConfigProvider ()

@property (nonatomic, strong) NSDictionary *deviceIdsCache;
@property (nonatomic, strong) NSDictionary *globalScopeCache;
@property (nonatomic, strong) NSDate *lastCacheTime;
@property (nonatomic, strong) NSLock *cacheLock;
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
        _cacheLock = [[NSLock alloc] init];
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
    [self.cacheLock lock];
    @try {
        NSString *profilesPath = @"/var/mobile/Library/WeaponX/Profiles";
        NSString *centralInfoPath = [profilesPath stringByAppendingPathComponent:@"current_profile_info.plist"];
        NSDictionary *centralInfo = [NSDictionary dictionaryWithContentsOfFile:centralInfoPath];
        NSString *profileId = centralInfo[@"ProfileId"];

        if (profileId.length > 0) {
            NSString *identityDir = [[profilesPath stringByAppendingPathComponent:profileId] stringByAppendingPathComponent:@"identity"];
            NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
            self.deviceIdsCache = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: @{};
        } else {
            self.deviceIdsCache = @{};
        }

        // Global scope
        NSArray *paths = @[@"/var/mobile/Library/Preferences/com.hydra.projectx.global_scope.plist",
                           @"/private/var/mobile/Library/Preferences/com.hydra.projectx.global_scope.plist"];
        for (NSString *p in paths) {
            NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:p];
            if (plist) {
                self.globalScopeCache = plist;
                break;
            }
        }

        self.lastCacheTime = [NSDate date];
    } @catch (NSException *e) {
        PXLog(@"[PXConfigProvider] Error reloading config: %@", e);
    } @finally {
        [self.cacheLock unlock];
    }
}

- (void)checkAndRefreshCacheIfNeeded {
    [self.cacheLock lock];
    NSDate *lastTime = self.lastCacheTime;
    [self.cacheLock unlock];

    if (!lastTime || [[NSDate date] timeIntervalSinceDate:lastTime] > kPXConfigCacheDuration) {
        [self reloadConfig];
    }
}

- (NSString *)spoofedDeviceModel {
    [self checkAndRefreshCacheIfNeeded];
    [self.cacheLock lock];
    NSString *model = [self.deviceIdsCache[@"DeviceModel"] isKindOfClass:[NSString class]] ? self.deviceIdsCache[@"DeviceModel"] : nil;
    [self.cacheLock unlock];
    return model;
}

- (NSString *)spoofedGPUFamily {
    [self checkAndRefreshCacheIfNeeded];
    [self.cacheLock lock];
    NSString *gpu = [self.deviceIdsCache[@"GPUFamily"] isKindOfClass:[NSString class]] ? self.deviceIdsCache[@"GPUFamily"] : nil;
    if (!gpu) {
        gpu = [self.deviceIdsCache[@"WebGLRenderer"] isKindOfClass:[NSString class]] ? self.deviceIdsCache[@"WebGLRenderer"] : nil;
    }
    [self.cacheLock unlock];
    return gpu;
}

- (NSString *)spoofedIDFA {
    // IDFA might be in a separate file depending on your app's architecture,
    // but if it's centralized or easily read from the profile path, do it here.
    return nil; // Implement if necessary based on your current setup.
}

- (NSString *)spoofedIDFV {
    return nil; // Implement if necessary based on your current setup.
}

- (NSString *)spoofedBootTime {
    return nil; // Implement if necessary based on your current setup.
}

- (BOOL)isDeviceModelSpoofingEnabledForCurrentProcess {
    NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!currentBundleID) return NO;

    // Add cache to avoid perf regression on sysctl
    static NSMutableDictionary *cachedBundleDecisions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cachedBundleDecisions = [NSMutableDictionary dictionary];
    });

    [self.cacheLock lock];
    NSNumber *cachedDecision = cachedBundleDecisions[currentBundleID];
    NSDate *decisionTimestamp = cachedBundleDecisions[[currentBundleID stringByAppendingString:@"_timestamp"]];
    if (cachedDecision && decisionTimestamp &&
        [[NSDate date] timeIntervalSinceDate:decisionTimestamp] < kPXConfigCacheDuration) {
        [self.cacheLock unlock];
        return [cachedDecision boolValue];
    }
    [self.cacheLock unlock];

    BOOL shouldSpoof = NO;
    @try {
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
    } @catch (__unused NSException *exception) {
        shouldSpoof = NO;
    }

    [self.cacheLock lock];
    cachedBundleDecisions[currentBundleID] = @(shouldSpoof);
    cachedBundleDecisions[[currentBundleID stringByAppendingString:@"_timestamp"]] = [NSDate date];
    [self.cacheLock unlock];

    return shouldSpoof;
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
