#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <spawn.h>
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <os/log.h>
#import <errno.h>
#import <notify.h>
#import <string.h>
#import "PXInjectionFilter.h"
#import "PXJailbreakCompat.h"
#import "PXRuntimeSnapshot.h"
#import "PXPaths.h"

// Constants
static const NSTimeInterval kCheckInterval = 0.5; // Cheap staging-change poll; sync itself is change-gated.
static NSString *kGuardianDir = nil; // Will be initialized in init
static NSString *ROOT_PREFIX = nil; // Will be set based on environment
static os_log_t weaponx_log = NULL;
static BOOL debugMode = NO;
static NSString * const kTLinkIOSFilterChangedNotification = @"com.hydra.tlinkios.filterPlistChanged";
static NSString * const kTLinkIOSTweakLoadedNotification = @"com.hydra.tlinkios.tweakLoaded";
static const char *kTLinkIOSTweakLoadedNotifyName = "com.hydra.tlinkios.tweakLoaded";
static NSString * const kTLinkIOSBootstrapDecisionNotification = @"com.hydra.tlinkios.bootstrapDecision";
static const char *kTLinkIOSBootstrapDecisionNotifyName = "com.hydra.tlinkios.bootstrapDecision";
static NSString * const kTLinkIOSHookDiagnosticNotification = @"com.hydra.tlinkios.hookDiagnostic";
static const char *kTLinkIOSHookDiagnosticNotifyName = "com.hydra.tlinkios.hookDiagnostic";

@interface WeaponXDaemon : NSObject
@property (nonatomic, strong) NSTimer *monitorTimer;
@property (nonatomic, strong) NSMutableDictionary *processInfo;
@property (nonatomic, strong) NSMutableArray *protectedProcesses;
@property (nonatomic, copy) NSString *lastStagingFingerprint;
@property (nonatomic, copy) NSString *lastRuntimeFingerprint;
@property (nonatomic, assign) NSUInteger syncSequence;
@property (nonatomic, assign) int tweakLoadNotifyToken;
@property (nonatomic, assign) int bootstrapDecisionNotifyToken;
@property (nonatomic, assign) int hookDiagnosticNotifyToken;
- (void)syncTLinkIOSFilterPlists;
- (void)recordTweakLoadSignal;
- (void)recordBootstrapDecisionSignal;
- (void)recordHookDiagnosticSignal;
- (void)publishRuntimeSnapshotWithReason:(NSString *)reason;
- (NSString *)stagingFingerprint;
- (NSString *)runtimeStateFingerprint;
- (void)writeRuntimeStatus:(NSString *)event;
- (void)runOneShotSelfTest;
@end

static void PXFilterChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)name; (void)object; (void)userInfo;
    WeaponXDaemon *daemon = (__bridge WeaponXDaemon *)observer;
    [daemon syncTLinkIOSFilterPlists];
    [daemon publishRuntimeSnapshotWithReason:@"filter-plist-changed"];
}

static void PXTweakLoadedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)name; (void)object; (void)userInfo;
    WeaponXDaemon *daemon = (__bridge WeaponXDaemon *)observer;
    [daemon recordTweakLoadSignal];
}

static void PXRuntimeStateChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)object; (void)userInfo;
    WeaponXDaemon *daemon = (__bridge WeaponXDaemon *)observer;
    NSString *reason = name ? (__bridge NSString *)name : @"darwin-state-change";
    [daemon publishRuntimeSnapshotWithReason:reason];
}

static void PXBootstrapDecisionCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)name; (void)object; (void)userInfo;
    WeaponXDaemon *daemon = (__bridge WeaponXDaemon *)observer;
    [daemon recordBootstrapDecisionSignal];
}

static void PXHookDiagnosticCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)name; (void)object; (void)userInfo;
    WeaponXDaemon *daemon = (__bridge WeaponXDaemon *)observer;
    [daemon recordHookDiagnosticSignal];
}

@implementation WeaponXDaemon

+ (void)initialize {
    if (self == [WeaponXDaemon class]) {
        // Initialize the os_log handle for system console
        weaponx_log = os_log_create("com.hydra.weaponx.guardian", "daemon");
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        ROOT_PREFIX = PXJailbreakRootPath(@"/");
#else
        ROOT_PREFIX = @"";
#endif
        kGuardianDir = PXJailbreakRootPath(@"/Library/WeaponX/Guardian");
        
        _processInfo = [NSMutableDictionary dictionary];
        // The guardian must never respawn the GUI application. On RootHide this
        // daemon is loaded as root/KeepAlive; launching TLinkIOS headlessly from
        // here can create a crash/restart loop during package installation.
        _protectedProcesses = [NSMutableArray array];
        _tweakLoadNotifyToken = -1;
        _bootstrapDecisionNotifyToken = -1;
        _hookDiagnosticNotifyToken = -1;
        
        NSLog(@"Using Guardian dir: %@", kGuardianDir);
        
        // Create guardian directory if needed
        [self ensureGuardianDirectoryExists];
        
        // Start logging
        [self log:[NSString stringWithFormat:@"WeaponXDaemon initialized (rootless: %@, debug: %@)", 
                   ROOT_PREFIX.length > 0 ? @"YES" : @"NO",
                   debugMode ? @"YES" : @"NO"] 
         withType:OS_LOG_TYPE_INFO];
        
        // Write to stderr directly for visibility
        fprintf(stderr, "WeaponXDaemon initialized with root prefix: %s\n", [ROOT_PREFIX UTF8String]);
    }
    return self;
}

- (void)dealloc {
    if (_tweakLoadNotifyToken >= 0) notify_cancel(_tweakLoadNotifyToken);
    if (_bootstrapDecisionNotifyToken >= 0) notify_cancel(_bootstrapDecisionNotifyToken);
    if (_hookDiagnosticNotifyToken >= 0) notify_cancel(_hookDiagnosticNotifyToken);
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                            (__bridge const void *)(self));
}

- (void)startDaemon {
    [self log:@"WeaponXDaemon starting..." withType:OS_LOG_TYPE_INFO];
    [self writeRuntimeStatus:@"start"];
    [self publishRuntimeSnapshotWithReason:@"daemon-start"];

    CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(darwinCenter,
                                    (__bridge const void *)(self),
                                    PXFilterChangedCallback,
                                    (__bridge CFStringRef)kTLinkIOSFilterChangedNotification,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    for (NSString *notificationName in @[@"com.hydra.tlinkios.settings.changed",
                                         @"com.hydra.tlinkios.profileChanged",
                                         @"com.hydra.tlinkios.scopedAppsChanged"]) {
        CFNotificationCenterAddObserver(darwinCenter,
                                        (__bridge const void *)(self),
                                        PXRuntimeStateChangedCallback,
                                        (__bridge CFStringRef)notificationName,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
    }

    uint32_t notifyStatus = notify_register_check(kTLinkIOSTweakLoadedNotifyName, &_tweakLoadNotifyToken);
    if (notifyStatus != NOTIFY_STATUS_OK) {
        _tweakLoadNotifyToken = -1;
        [self log:[NSString stringWithFormat:@"Tweak-load probe notify_register_check failed: %u", notifyStatus]
             withType:OS_LOG_TYPE_ERROR];
    } else {
        // Clear any persisted notify state from a previous daemon instance so an
        // unresolved sender can never be mistaken for an old PID.
        notify_set_state(_tweakLoadNotifyToken, 0);
    }
    CFNotificationCenterAddObserver(darwinCenter,
                                    (__bridge const void *)(self),
                                    PXTweakLoadedCallback,
                                    (__bridge CFStringRef)kTLinkIOSTweakLoadedNotification,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);

    uint32_t decisionNotifyStatus = notify_register_check(kTLinkIOSBootstrapDecisionNotifyName, &_bootstrapDecisionNotifyToken);
    if (decisionNotifyStatus != NOTIFY_STATUS_OK) {
        _bootstrapDecisionNotifyToken = -1;
        [self log:[NSString stringWithFormat:@"Bootstrap probe notify_register_check failed: %u", decisionNotifyStatus]
             withType:OS_LOG_TYPE_ERROR];
    } else {
        notify_set_state(_bootstrapDecisionNotifyToken, 0);
    }
    CFNotificationCenterAddObserver(darwinCenter,
                                    (__bridge const void *)(self),
                                    PXBootstrapDecisionCallback,
                                    (__bridge CFStringRef)kTLinkIOSBootstrapDecisionNotification,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);

    uint32_t hookDiagnosticStatus = notify_register_check(kTLinkIOSHookDiagnosticNotifyName, &_hookDiagnosticNotifyToken);
    if (hookDiagnosticStatus != NOTIFY_STATUS_OK) {
        _hookDiagnosticNotifyToken = -1;
        [self log:[NSString stringWithFormat:@"Hook diagnostic notify_register_check failed: %u", hookDiagnosticStatus]
             withType:OS_LOG_TYPE_ERROR];
    } else {
        notify_set_state(_hookDiagnosticNotifyToken, 0);
    }
    CFNotificationCenterAddObserver(darwinCenter,
                                    (__bridge const void *)(self),
                                    PXHookDiagnosticCallback,
                                    (__bridge CFStringRef)kTLinkIOSHookDiagnosticNotification,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    
    // Schedule monitoring timer
    self.monitorTimer = [NSTimer scheduledTimerWithTimeInterval:kCheckInterval
                                                       target:self
                                                     selector:@selector(checkProcesses)
                                                     userInfo:nil
                                                      repeats:YES];
    
    // Add to runloop
    [[NSRunLoop currentRunLoop] addTimer:self.monitorTimer forMode:NSRunLoopCommonModes];
    
    // Check immediately
    [self checkProcesses];
    
    // Keep runloop running
    [[NSRunLoop currentRunLoop] run];
}

- (void)publishRuntimeSnapshotWithReason:(NSString *)reason {
    NSError *publishError = nil;
    BOOL success = PXPublishRuntimeSnapshot(&publishError);
    NSDictionary *snapshot = success ? PXLoadRuntimeSnapshot() : @{};
    NSDictionary *scope = [snapshot[@"globalScope"] isKindOfClass:NSDictionary.class] ? snapshot[@"globalScope"] : @{};
    NSDictionary *scopedApps = [scope[@"ScopedApps"] isKindOfClass:NSDictionary.class] ? scope[@"ScopedApps"] : @{};
    NSDictionary *deviceIDs = [snapshot[@"deviceIDs"] isKindOfClass:NSDictionary.class] ? snapshot[@"deviceIDs"] : @{};
    NSString *profileID = [snapshot[@"profileID"] isKindOfClass:NSString.class] ? snapshot[@"profileID"] : @"";

    NSString *debugDir = @"/var/mobile/Library/TLinkIOS";
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:debugDir
  withIntermediateDirectories:YES
                   attributes:@{NSFilePosixPermissions: @0755}
                        error:nil];
    NSString *debugPath = [debugDir stringByAppendingPathComponent:@"runtime_snapshot_debug.plist"];
    NSDictionary *publishStats = PXRuntimeSnapshotLastPublishStats();
    NSDictionary *debug = @{
        @"timestamp": @([[NSDate date] timeIntervalSince1970]),
        @"success": @(success),
        @"reason": reason ?: @"unknown",
        @"snapshotPath": PXRuntimeSnapshotPath() ?: @"",
        @"profileID": profileID ?: @"",
        @"scopedAppCount": @(scopedApps.count),
        @"deviceIDCount": @(deviceIDs.count),
        @"publishStats": publishStats ?: @{},
        @"runtimeFingerprint": [self runtimeStateFingerprint] ?: @"",
        @"error": publishError.localizedDescription ?: @""
    };
    [debug writeToFile:debugPath atomically:YES];
    chmod(debugPath.fileSystemRepresentation, 0644);
    chown(debugPath.fileSystemRepresentation, 501, 501);

    if (success) {
        [self log:[NSString stringWithFormat:@"Published RootHide runtime snapshot reason=%@ profile=%@ scope=%lu deviceIDs=%lu",
                   reason ?: @"unknown", profileID ?: @"",
                   (unsigned long)scopedApps.count, (unsigned long)deviceIDs.count]
             withType:OS_LOG_TYPE_INFO];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFSTR("com.hydra.tlinkios.runtimeSnapshotChanged"),
                                             NULL, NULL, true);
    } else {
        [self log:[NSString stringWithFormat:@"Runtime snapshot publish failed reason=%@ error=%@",
                   reason ?: @"unknown", publishError.localizedDescription ?: @"unknown"]
             withType:OS_LOG_TYPE_ERROR];
    }
}

- (void)recordBootstrapDecisionSignal {
    uint64_t state = 0;
    uint32_t stateStatus = (uint32_t)-1;
    if (self.bootstrapDecisionNotifyToken >= 0) {
        stateStatus = notify_get_state(self.bootstrapDecisionNotifyToken, &state);
        if (stateStatus == NOTIFY_STATUS_OK) notify_set_state(self.bootstrapDecisionNotifyToken, 0);
    }

    uint32_t pid = (uint32_t)(state & 0xFFFFFFFFu);
    uint32_t role = (uint32_t)((state >> 32) & 0xFFu);
    uint32_t reason = (uint32_t)((state >> 40) & 0xFFu);
    uint32_t capabilities = (uint32_t)((state >> 48) & 0xFFFFu);
    NSArray<NSString *> *roleNames = @[@"unknown", @"main-app", @"extension", @"web-content",
                                       @"web-networking", @"web-gpu", @"safari-view-service",
                                       @"springboard", @"system-daemon"];
    NSArray<NSString *> *reasonNames = @[@"denied-unknown", @"denied-system", @"denied-scope",
                                         @"denied-master", @"denied-web-stack", @"allowed"];
    NSString *roleName = role < roleNames.count ? roleNames[role] : @"invalid-role";
    NSString *reasonName = reason < reasonNames.count ? reasonNames[reason] : @"invalid-reason";
    NSString *processPath = @"";
    NSString *processName = @"";
    NSString *bundleID = @"";
    if (pid > 0) {
        typedef int (*PXProcPidPathFn)(int, void *, uint32_t);
        PXProcPidPathFn procPidPath = (PXProcPidPathFn)dlsym(RTLD_DEFAULT, "proc_pidpath");
        void *libprocHandle = NULL;
        if (!procPidPath) {
            libprocHandle = dlopen("/usr/lib/libproc.dylib", RTLD_LAZY | RTLD_LOCAL);
            if (libprocHandle) procPidPath = (PXProcPidPathFn)dlsym(libprocHandle, "proc_pidpath");
        }
        if (procPidPath) {
            char pathBuffer[4096] = {0};
            if (procPidPath((int)pid, pathBuffer, (uint32_t)sizeof(pathBuffer)) > 0) {
                processPath = [NSString stringWithUTF8String:pathBuffer] ?: @"";
                processName = processPath.lastPathComponent ?: @"";
                NSRange appMarker = [processPath rangeOfString:@".app/" options:NSBackwardsSearch];
                if (appMarker.location != NSNotFound) {
                    NSUInteger appEnd = appMarker.location + @".app".length;
                    NSString *bundlePath = [processPath substringToIndex:MIN(appEnd, processPath.length)];
                    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:
                        [bundlePath stringByAppendingPathComponent:@"Info.plist"]];
                    id identifier = [info isKindOfClass:NSDictionary.class] ? info[@"CFBundleIdentifier"] : nil;
                    if ([identifier isKindOfClass:NSString.class]) bundleID = identifier;
                }
            }
        }
        if (libprocHandle) dlclose(libprocHandle);
    }

    NSString *dir = @"/var/mobile/Library/TLinkIOS";
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0755} error:nil];
    NSString *path = [dir stringByAppendingPathComponent:@"tweak_bootstrap_probe.plist"];
    NSMutableArray *events = [[NSArray arrayWithContentsOfFile:path] mutableCopy];
    if (![events isKindOfClass:NSMutableArray.class]) events = [NSMutableArray array];
    NSDictionary *record = @{
        @"timestamp": @([[NSDate date] timeIntervalSince1970]),
        @"pid": @(pid),
        @"role": @(role),
        @"roleName": roleName,
        @"reason": @(reason),
        @"reasonName": reasonName,
        @"capabilities": @(capabilities),
        @"bundleID": bundleID ?: @"",
        @"processName": processName ?: @"",
        @"processPath": processPath ?: @"",
        @"notifyStateStatus": @(stateStatus)
    };
    [events addObject:record];
    if (events.count > 64) [events removeObjectsInRange:NSMakeRange(0, events.count - 64)];
    [events writeToFile:path atomically:YES];
    chmod(path.fileSystemRepresentation, 0644);
    chown(path.fileSystemRepresentation, 501, 501);
}

- (void)recordHookDiagnosticSignal {
    uint64_t state = 0;
    uint32_t stateStatus = (uint32_t)-1;
    if (self.hookDiagnosticNotifyToken >= 0) {
        // Do not clear this state. Tweak translation units merge their reached
        // masks through the shared notify state so coalesced notifications still
        // leave one useful, cumulative diagnostic record.
        stateStatus = notify_get_state(self.hookDiagnosticNotifyToken, &state);
    }

    uint32_t pid = (uint32_t)(state & 0xFFFFFFFFu);
    uint16_t reachedMask = (uint16_t)((state >> 32) & 0xFFFFu);
    uint8_t stage = (uint8_t)((state >> 48) & 0xFFu);
    uint8_t result = (uint8_t)((state >> 56) & 0xFFu);
    NSArray<NSString *> *stageNames = @[
        @"invalid",
        @"native-ctor-allowed",
        @"identity-snapshot",
        @"native-coordinator",
        @"identifiers-group",
        @"device-model-profile",
        @"device-model-hooks",
        @"ios-version-profile",
        @"ios-version-hooks",
        @"sysctl-observed",
        @"sysctlbyname-observed",
        @"mobilegestalt-observed",
        @"iokit-observed",
        @"uname-observed",
        @"system-version-observed",
        @"ios-version-cfbundle-hook",
        @"native-ctor-completed"
    ];
    NSArray<NSString *> *resultNames = @[
        @"checkpoint", @"success", @"skipped", @"disabled",
        @"missing-data", @"scope-denied", @"symbol-missing", @"failed"
    ];
    NSString *stageName = stage < stageNames.count ? stageNames[stage] : @"invalid-stage";
    NSString *resultName = result < resultNames.count ? resultNames[result] : @"invalid-result";
    NSMutableArray<NSString *> *reachedStages = [NSMutableArray array];
    for (NSUInteger index = 1; index < stageNames.count; index++) {
        if ((reachedMask & (1u << (index - 1u))) != 0) [reachedStages addObject:stageNames[index]];
    }

    NSString *processPath = @"";
    NSString *processName = @"";
    NSString *bundleID = @"";
    if (pid > 0) {
        typedef int (*PXProcPidPathFn)(int, void *, uint32_t);
        PXProcPidPathFn procPidPath = (PXProcPidPathFn)dlsym(RTLD_DEFAULT, "proc_pidpath");
        void *libprocHandle = NULL;
        if (!procPidPath) {
            libprocHandle = dlopen("/usr/lib/libproc.dylib", RTLD_LAZY | RTLD_LOCAL);
            if (libprocHandle) procPidPath = (PXProcPidPathFn)dlsym(libprocHandle, "proc_pidpath");
        }
        if (procPidPath) {
            char pathBuffer[4096] = {0};
            if (procPidPath((int)pid, pathBuffer, (uint32_t)sizeof(pathBuffer)) > 0) {
                processPath = [NSString stringWithUTF8String:pathBuffer] ?: @"";
                processName = processPath.lastPathComponent ?: @"";
                NSRange appMarker = [processPath rangeOfString:@".app/" options:NSBackwardsSearch];
                if (appMarker.location != NSNotFound) {
                    NSUInteger appEnd = appMarker.location + @".app".length;
                    NSString *bundlePath = [processPath substringToIndex:MIN(appEnd, processPath.length)];
                    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:
                        [bundlePath stringByAppendingPathComponent:@"Info.plist"]];
                    id identifier = [info isKindOfClass:NSDictionary.class] ? info[@"CFBundleIdentifier"] : nil;
                    if ([identifier isKindOfClass:NSString.class]) bundleID = identifier;
                }
            }
        }
        if (libprocHandle) dlclose(libprocHandle);
    }

    NSString *dir = @"/var/mobile/Library/TLinkIOS";
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0755} error:nil];
    NSString *path = [dir stringByAppendingPathComponent:@"hook_install_probe.plist"];
    NSMutableArray *events = [[NSArray arrayWithContentsOfFile:path] mutableCopy];
    if (![events isKindOfClass:NSMutableArray.class]) events = [NSMutableArray array];
    NSDictionary *record = @{
        @"timestamp": @([[NSDate date] timeIntervalSince1970]),
        @"pid": @(pid),
        @"bundleID": bundleID ?: @"",
        @"processName": processName ?: @"",
        @"processPath": processPath ?: @"",
        @"stage": @(stage),
        @"stageName": stageName,
        @"result": @(result),
        @"resultName": resultName,
        @"reachedMask": @(reachedMask),
        @"reachedMaskHex": [NSString stringWithFormat:@"0x%04x", reachedMask],
        @"reachedStages": reachedStages,
        @"notifyStateStatus": @(stateStatus)
    };
    [events addObject:record];
    if (events.count > 128) [events removeObjectsInRange:NSMakeRange(0, events.count - 128)];
    [events writeToFile:path atomically:YES];
    chmod(path.fileSystemRepresentation, 0644);
    chown(path.fileSystemRepresentation, 501, 501);
}

- (void)recordTweakLoadSignal {
    uint64_t state = 0;
    uint32_t stateStatus = (uint32_t)-1;
    if (self.tweakLoadNotifyToken >= 0) {
        stateStatus = notify_get_state(self.tweakLoadNotifyToken, &state);
        if (stateStatus == NOTIFY_STATUS_OK) {
            notify_set_state(self.tweakLoadNotifyToken, 0);
        }
    }

    pid_t pid = (stateStatus == NOTIFY_STATUS_OK && state > 0) ? (pid_t)(uint32_t)state : 0;
    NSString *processPath = @"";
    NSString *processName = @"";
    NSString *bundleID = @"";
    NSString *bundlePath = @"";

    if (pid > 0) {
        typedef int (*PXProcPidPathFn)(int, void *, uint32_t);
        PXProcPidPathFn procPidPath = (PXProcPidPathFn)dlsym(RTLD_DEFAULT, "proc_pidpath");
        void *libprocHandle = NULL;
        if (!procPidPath) {
            libprocHandle = dlopen("/usr/lib/libproc.dylib", RTLD_LAZY | RTLD_LOCAL);
            if (libprocHandle) procPidPath = (PXProcPidPathFn)dlsym(libprocHandle, "proc_pidpath");
        }

        if (procPidPath) {
            char pathBuffer[4096] = {0};
            int length = procPidPath(pid, pathBuffer, (uint32_t)sizeof(pathBuffer));
            if (length > 0) {
                processPath = [NSString stringWithUTF8String:pathBuffer] ?: @"";
                processName = processPath.lastPathComponent ?: @"";
                NSRange appMarker = [processPath rangeOfString:@".app/" options:NSBackwardsSearch];
                if (appMarker.location != NSNotFound) {
                    NSUInteger appEnd = appMarker.location + @".app".length;
                    if (appEnd <= processPath.length) {
                        bundlePath = [processPath substringToIndex:appEnd];
                        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:
                            [bundlePath stringByAppendingPathComponent:@"Info.plist"]];
                        id identifier = [info isKindOfClass:NSDictionary.class] ? info[@"CFBundleIdentifier"] : nil;
                        if ([identifier isKindOfClass:NSString.class]) bundleID = identifier;
                    }
                }
            }
        }
        if (libprocHandle) dlclose(libprocHandle);
    }

    NSString *dir = @"/var/mobile/Library/TLinkIOS";
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:dir
  withIntermediateDirectories:YES
                   attributes:@{NSFilePosixPermissions: @0755}
                        error:nil];
    NSString *path = [dir stringByAppendingPathComponent:@"tweak_load_probe.plist"];
    NSMutableArray *events = [[NSArray arrayWithContentsOfFile:path] mutableCopy];
    if (![events isKindOfClass:NSMutableArray.class]) events = [NSMutableArray array];
    NSDictionary *record = @{
        @"timestamp": @([[NSDate date] timeIntervalSince1970]),
        @"pid": @(pid),
        @"notifyStateStatus": @(stateStatus),
        @"processPath": processPath ?: @"",
        @"processName": processName ?: @"",
        @"bundlePath": bundlePath ?: @"",
        @"bundleID": bundleID ?: @""
    };
    [events addObject:record];
    if (events.count > 64) {
        [events removeObjectsInRange:NSMakeRange(0, events.count - 64)];
    }
    [events writeToFile:path atomically:YES];
    chmod(path.fileSystemRepresentation, 0644);
    chown(path.fileSystemRepresentation, 501, 501);

    [self log:[NSString stringWithFormat:@"Tweak-load probe pid=%d bundle=%@ process=%@ path=%@",
               pid, bundleID.length ? bundleID : @"<unknown>",
               processName.length ? processName : @"<unknown>",
               processPath.length ? processPath : @"<unknown>"]
         withType:OS_LOG_TYPE_INFO];
}

- (void)checkProcesses {
    // Darwin notifications are the fast path. This timer is a RootHide-safe
    // fallback in case a notification is delayed/lost across bootstrap
    // boundaries. Fingerprinting keeps the 0.5s poll effectively read-only.
    NSString *fingerprint = [self stagingFingerprint];
    if (!self.lastStagingFingerprint || ![fingerprint isEqualToString:self.lastStagingFingerprint]) {
        [self log:[NSString stringWithFormat:@"Staging changed; synchronizing filters (%@)", fingerprint]
             withType:OS_LOG_TYPE_DEBUG];
        [self syncTLinkIOSFilterPlists];
        [self updateStateFile];
    }

    NSString *runtimeFingerprint = [self runtimeStateFingerprint];
    if (!self.lastRuntimeFingerprint || ![runtimeFingerprint isEqualToString:self.lastRuntimeFingerprint]) {
        self.lastRuntimeFingerprint = runtimeFingerprint;
        [self log:[NSString stringWithFormat:@"Runtime state changed; republishing snapshot (%@)", runtimeFingerprint]
             withType:OS_LOG_TYPE_DEBUG];
        [self publishRuntimeSnapshotWithReason:@"runtime-fingerprint-changed"];
    }
}

- (NSString *)runtimeStateFingerprint {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *profileID = PXActiveProfileID();
    NSString *profileRoot = PXProfileRootPath(profileID);
    NSString *identityRoot = PXProfileIdentityPath(profileID);
    NSMutableArray<NSString *> *paths = [NSMutableArray arrayWithObjects:
        PXTLinkIOSSettingsPath(), PXGlobalScopePath(), PXSecuritySettingsPath(),
        PXCurrentProfileInfoPath(), nil];
    if (profileRoot.length) [paths addObject:[profileRoot stringByAppendingPathComponent:@"storage.plist"]];
    if (identityRoot.length) {
        for (NSString *name in @[@"device_ids.plist", @"battery_info.plist", @"network_settings.plist",
                                 @"wifi_info.plist", @"carrier_details.plist", @"device_theme.plist",
                                 @"boot_time.plist", @"system_uptime.plist", @"system_boot_uuid.plist",
                                 @"dyld_cache_uuid.plist", @"pasteboard_uuid.plist", @"userdefaults_uuid.plist"]) {
            [paths addObject:[identityRoot stringByAppendingPathComponent:name]];
        }
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithCapacity:paths.count + 1];
    [parts addObject:[NSString stringWithFormat:@"profile=%@", profileID ?: @""]];
    for (NSString *path in paths) {
        NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
        if (!attrs) {
            [parts addObject:[NSString stringWithFormat:@"%@=missing", path.lastPathComponent ?: path]];
            continue;
        }
        NSNumber *size = attrs[NSFileSize];
        NSDate *mtime = attrs[NSFileModificationDate];
        [parts addObject:[NSString stringWithFormat:@"%@=%llu:%.6f",
                          path.lastPathComponent ?: path,
                          size.unsignedLongLongValue,
                          mtime.timeIntervalSince1970]];
    }
    return [parts componentsJoinedByString:@"|"];
}

- (NSString *)stagingFingerprint {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *stagingDir = @"/var/mobile/Library/TLinkIOS/filter_plists";
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *name in @[@"TLinkIOSTweak.plist", @"WeaponXKeychainBridge.plist"]) {
        NSString *path = [stagingDir stringByAppendingPathComponent:name];
        NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
        NSNumber *size = attrs[NSFileSize];
        NSDate *mtime = attrs[NSFileModificationDate];
        if (!attrs) {
            [parts addObject:[NSString stringWithFormat:@"%@=missing", name]];
        } else {
            [parts addObject:[NSString stringWithFormat:@"%@=%llu:%.6f",
                              name,
                              size.unsignedLongLongValue,
                              mtime.timeIntervalSince1970]];
        }
    }
    return [parts componentsJoinedByString:@"|"];
}

- (void)syncTLinkIOSFilterPlists {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *stagingDir = @"/var/mobile/Library/TLinkIOS/filter_plists";
    NSString *targetDir = [self tweakInjectionDir];
    NSString *observedFingerprint = [self stagingFingerprint];
    NSUInteger sequence = ++self.syncSequence;
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:stagingDir isDirectory:&isDir] || !isDir) {
        NSString *debugPath = @"/var/mobile/Library/TLinkIOS/filter_daemon_debug.plist";
        NSDictionary *missing = @{
            @"timestamp": @([[NSDate date] timeIntervalSince1970]),
            @"syncSequence": @(sequence),
            @"status": @"staging-dir-missing",
            @"stagingDir": stagingDir,
            @"stagingFingerprint": observedFingerprint ?: @"",
            @"targetDir": targetDir ?: @""
        };
        [missing writeToFile:debugPath atomically:YES];
        chmod([debugPath fileSystemRepresentation], 0644);
        chown([debugPath fileSystemRepresentation], 501, 501);
        self.lastStagingFingerprint = observedFingerprint;
        return;
    }
    if (![fm fileExistsAtPath:targetDir isDirectory:&isDir] || !isDir) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        // Do not manufacture a dead injector directory on RootHide. ElleKit must
        // provide its canonical /usr/lib/TweakInject inside the active jbroot.
        NSString *debugPath = @"/var/mobile/Library/TLinkIOS/filter_daemon_debug.plist";
        NSDictionary *failed = @{
            @"timestamp": @([[NSDate date] timeIntervalSince1970]),
            @"syncSequence": @(sequence),
            @"status": @"target-dir-missing",
            @"reason": @"ElleKit canonical /usr/lib/TweakInject is missing",
            @"stagingDir": stagingDir,
            @"stagingFingerprint": observedFingerprint ?: @"",
            @"targetDir": targetDir ?: @""
        };
        [failed writeToFile:debugPath atomically:YES];
        chmod([debugPath fileSystemRepresentation], 0644);
        chown([debugPath fileSystemRepresentation], 501, 501);
        self.lastStagingFingerprint = observedFingerprint;
        return;
#else
        NSError *mkErr = nil;
        [fm createDirectoryAtPath:targetDir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0755} error:&mkErr];
        if (mkErr) {
            [self log:[NSString stringWithFormat:@"Filter sync failed to create target dir: %@", mkErr.localizedDescription] withType:OS_LOG_TYPE_ERROR];
            NSString *debugPath = @"/var/mobile/Library/TLinkIOS/filter_daemon_debug.plist";
            NSDictionary *failed = @{
                @"timestamp": @([[NSDate date] timeIntervalSince1970]),
                @"syncSequence": @(sequence),
                @"status": @"target-dir-create-failed",
                @"reason": mkErr.localizedDescription ?: @"unknown",
                @"stagingDir": stagingDir,
                @"stagingFingerprint": observedFingerprint ?: @"",
                @"targetDir": targetDir ?: @""
            };
            [failed writeToFile:debugPath atomically:YES];
            chmod([debugPath fileSystemRepresentation], 0644);
            chown([debugPath fileSystemRepresentation], 501, 501);
            self.lastStagingFingerprint = observedFingerprint;
            return;
        }
#endif
    }

    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
    result[@"syncSequence"] = @(sequence);
    result[@"stagingDir"] = stagingDir;
    result[@"stagingFingerprint"] = observedFingerprint ?: @"";
    result[@"targetDir"] = targetDir ?: @"";
    errno = 0;
    int targetWriteAccess = access([targetDir fileSystemRepresentation], W_OK);
    int targetAccessErrno = errno;
    result[@"targetWriteAccess"] = @(targetWriteAccess == 0);
    result[@"targetAccessErrno"] = @(targetAccessErrno);
    result[@"targetAccessReason"] = targetWriteAccess == 0 ? @"ok" : ([NSString stringWithUTF8String:strerror(targetAccessErrno)] ?: @"unknown");
    result[@"uid"] = @(getuid());
    result[@"euid"] = @(geteuid());
    BOOL allFiltersInstalled = YES;
    for (NSString *name in @[@"TLinkIOSTweak.plist", @"WeaponXKeychainBridge.plist"]) {
        NSString *src = [stagingDir stringByAppendingPathComponent:name];
        NSString *dst = [targetDir stringByAppendingPathComponent:name];
        NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:src];
        NSString *invalidReason = nil;
        NSArray *bundles = nil;
        if (![self filterPlistIsValid:plist bundles:&bundles reason:&invalidReason]) {
            result[name] = @{
                @"status": @"invalid",
                @"reason": invalidReason ?: @"unknown",
                @"src": src,
                @"dst": dst
            };
            allFiltersInstalled = NO;
            continue;
        }

        // Canonicalize both staged filters. Broad UIKit/WebKit coverage belongs
        // only to TLinkIOSTweak; stale/malformed bridge targets are narrowed here.
        NSArray *sanitizedBundles;
        if ([name isEqualToString:@"TLinkIOSTweak.plist"]) {
            sanitizedBundles = PXInjectionComputeTweakBundles(bundles);
        } else {
            sanitizedBundles = PXInjectionComputeBridgeBundles(bundles);
        }
        if (![sanitizedBundles isEqualToArray:PXInjectionNormalizeBundleList(bundles)]) {
            NSDictionary *sanitizedPlist = PXInjectionFilterPlistDictionary(sanitizedBundles);
            if (![sanitizedPlist writeToFile:src atomically:YES]) {
                result[name] = @{
                    @"status": @"sanitize-staging-failed", @"src": src, @"dst": dst,
                    @"bundles": bundles ?: @[], @"sanitizedBundles": sanitizedBundles ?: @[]
                };
                allFiltersInstalled = NO;
                continue;
            }
            chmod([src fileSystemRepresentation], 0644);
            chown([src fileSystemRepresentation], 501, 501);
            plist = sanitizedPlist;
            bundles = sanitizedBundles;
            [self log:[NSString stringWithFormat:@"Canonicalized injection policy for %@", name]
                 withType:OS_LOG_TYPE_INFO];
        }

        NSDictionary *syncResult = [self atomicInstallPlistFromPath:src toPath:dst bundles:bundles];
        result[name] = syncResult ?: @{@"status": @"unknown"};
        if ([syncResult[@"status"] isEqualToString:@"renamed"]) {
            [self log:[NSString stringWithFormat:@"Synced filter plist %@ (%lu bundles)", name, (unsigned long)bundles.count] withType:OS_LOG_TYPE_INFO];
        } else {
            allFiltersInstalled = NO;
            [self log:[NSString stringWithFormat:@"Filter sync failed for %@: %@", name, syncResult[@"status"] ?: @"unknown"] withType:OS_LOG_TYPE_ERROR];
        }
    }
    result[@"status"] = allFiltersInstalled ? @"in_sync" : @"partial_failure";
    NSString *debugPath = @"/var/mobile/Library/TLinkIOS/filter_daemon_debug.plist";
    result[@"completedTimestamp"] = @([[NSDate date] timeIntervalSince1970]);
    result[@"finalStagingFingerprint"] = [self stagingFingerprint] ?: @"";
    [result writeToFile:debugPath atomically:YES];
    chmod([debugPath fileSystemRepresentation], 0644);
    chown([debugPath fileSystemRepresentation], 501, 501);
    self.lastStagingFingerprint = [self stagingFingerprint];
}

- (NSString *)tweakInjectionDir {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    // ElleKit's canonical injector directory is /usr/lib/TweakInject. Upstream
    // ElleKit may expose /Library/MobileSubstrate/DynamicLibraries as a
    // compatibility symlink, but RootHide devices are not required to expose
    // that alias. Always resolve the canonical directory through jbroot().
    return PXJailbreakRootPath(@"/usr/lib/TweakInject");
#else
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in PXJailbreakPathCandidates(@[@"/Library/MobileSubstrate/DynamicLibraries", @"/var/jb/Library/MobileSubstrate/DynamicLibraries"])) {
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:path isDirectory:&isDir] && isDir) return path;
    }
    return PXJailbreakRootPath(@"/Library/MobileSubstrate/DynamicLibraries");
#endif
}

- (BOOL)filterPlistIsValid:(NSDictionary *)plist bundles:(NSArray **)outBundles reason:(NSString **)reason {
    // Single source of truth: PXInjectionFilter (shared with the app-side writer).
    return PXInjectionFilterPlistIsValid(plist, outBundles, reason);
}

/// Stable checksum of filter bundle list (sorted join). Used in filter_daemon_debug.plist.
static NSString *PXFilterBundlesChecksum(NSArray *bundles) {
    return PXInjectionBundlesChecksum(bundles);
}

- (NSDictionary *)atomicInstallPlistFromPath:(NSString *)src toPath:(NSString *)dst bundles:(NSArray *)bundles {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *tmp = [dst stringByAppendingFormat:@".tmp.%d", getpid()];
    [fm removeItemAtPath:tmp error:nil];
    NSString *checksum = PXFilterBundlesChecksum(bundles);

    NSError *copyErr = nil;
    if (![fm copyItemAtPath:src toPath:tmp error:&copyErr]) {
        return @{
            @"status": @"copy-to-tmp-failed",
            @"reason": copyErr.localizedDescription ?: @"unknown",
            @"src": src ?: @"",
            @"dst": dst ?: @"",
            @"tmp": tmp ?: @"",
            @"bundleCount": @(bundles.count),
            @"bundles": bundles ?: @[],
            @"checksum": checksum ?: @""
        };
    }

    chmod([tmp fileSystemRepresentation], 0644);
    chown([tmp fileSystemRepresentation], 0, 0);

    if (rename([tmp fileSystemRepresentation], [dst fileSystemRepresentation]) != 0) {
        int errNo = errno;
        [fm removeItemAtPath:tmp error:nil];
        return @{
            @"status": @"rename-failed",
            @"errno": @(errNo),
            @"reason": [NSString stringWithUTF8String:strerror(errNo)] ?: @"unknown",
            @"src": src ?: @"",
            @"dst": dst ?: @"",
            @"tmp": tmp ?: @"",
            @"bundleCount": @(bundles.count),
            @"bundles": bundles ?: @[],
            @"checksum": checksum ?: @""
        };
    }

    return @{
        @"status": @"renamed",
        @"src": src ?: @"",
        @"dst": dst ?: @"",
        @"tmp": tmp ?: @"",
        @"bundleCount": @(bundles.count),
        @"bundles": bundles ?: @[],
        @"checksum": checksum ?: @""
    };
}

- (void)writeRuntimeStatus:(NSString *)event {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = @"/var/mobile/Library/TLinkIOS";
    [fm createDirectoryAtPath:dir
  withIntermediateDirectories:YES
                   attributes:@{NSFilePosixPermissions: @0755}
                        error:nil];
    NSString *path = [dir stringByAppendingPathComponent:@"daemon_runtime_status.plist"];
    NSDictionary *status = @{
        @"event": event ?: @"unknown",
        @"timestamp": @([[NSDate date] timeIntervalSince1970]),
        @"pid": @(getpid()),
        @"uid": @(getuid()),
        @"euid": @(geteuid()),
        @"jbroot": PXJailbreakRootPath(@"/") ?: @"",
        @"targetDir": [self tweakInjectionDir] ?: @""
    };
    [status writeToFile:path atomically:YES];
    chmod([path fileSystemRepresentation], 0644);
    chown([path fileSystemRepresentation], 501, 501);
}

- (void)runOneShotSelfTest {
    [self log:@"WeaponXDaemon one-shot self-test" withType:OS_LOG_TYPE_INFO];
    [self writeRuntimeStatus:@"self-test"];
    [self syncTLinkIOSFilterPlists];
    [self publishRuntimeSnapshotWithReason:@"self-test"];
}

#pragma mark - Utility Methods

- (void)ensureGuardianDirectoryExists {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:kGuardianDir]) {
        NSError *error = nil;
        BOOL success = [fileManager createDirectoryAtPath:kGuardianDir 
              withIntermediateDirectories:YES 
                               attributes:nil 
                                    error:&error];
        
        if (!success) {
            NSLog(@"Failed to create guardian directory: %@", error);
            // Try with posix methods as fallback
            mkdir([kGuardianDir UTF8String], 0755);
        }
        
        // Set permissions explicitly to ensure we can write
        chmod([kGuardianDir UTF8String], 0755);
        
        // Create empty log files
        NSString *stdoutPath = [kGuardianDir stringByAppendingPathComponent:@"guardian-stdout.log"];
        NSString *stderrPath = [kGuardianDir stringByAppendingPathComponent:@"guardian-stderr.log"];
        NSString *daemonPath = [kGuardianDir stringByAppendingPathComponent:@"daemon.log"];
        
        [@"" writeToFile:stdoutPath atomically:NO encoding:NSUTF8StringEncoding error:nil];
        [@"" writeToFile:stderrPath atomically:NO encoding:NSUTF8StringEncoding error:nil];
        [@"" writeToFile:daemonPath atomically:NO encoding:NSUTF8StringEncoding error:nil];
        
        // Set log file permissions
        chmod([stdoutPath UTF8String], 0664);
        chmod([stderrPath UTF8String], 0664);
        chmod([daemonPath UTF8String], 0664);
        
        NSLog(@"Created Guardian directory and log files");
    }
}

- (void)updateStateFile {
    NSString *statePath = [kGuardianDir stringByAppendingPathComponent:@"daemon-state.plist"];
    NSDictionary *state = @{
        @"active": @YES,
        @"processInfo": self.processInfo,
        @"lastCheck": [NSDate date],
        @"protectedProcesses": self.protectedProcesses
    };
    
    [state writeToFile:statePath atomically:YES];
}

- (void)log:(NSString *)message withType:(os_log_type_t)type {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    NSString *logMessage = [NSString stringWithFormat:@"[WeaponX] [%@] %@", timestamp, message];
    
    // Log to system console
    os_log_with_type(weaponx_log, type, "%{public}@", logMessage);
    
    // Also log to file
    NSString *logPath = [kGuardianDir stringByAppendingPathComponent:@"daemon.log"];
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    
    if (fileHandle) {
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[[logMessage stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    } else {
        // Try to create the file if it doesn't exist
        [@"" writeToFile:logPath atomically:NO encoding:NSUTF8StringEncoding error:nil];
        [logMessage writeToFile:logPath atomically:NO encoding:NSUTF8StringEncoding error:nil];
    }
    
    // Also log to stderr for debug visibility
    if (debugMode || type == OS_LOG_TYPE_ERROR || type == OS_LOG_TYPE_FAULT) {
        fprintf(stderr, "%s\n", [logMessage UTF8String]);
    }
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        BOOL syncOnce = NO;
        // Parse command line arguments
        for (int i = 1; i < argc; i++) {
            NSString *arg = @(argv[i]);
            if ([arg isEqualToString:@"--debug"] || [arg isEqualToString:@"-d"]) {
                debugMode = YES;
            } else if ([arg isEqualToString:@"--sync-once"]) {
                syncOnce = YES;
            }
        }
        
        NSLog(@"WeaponXDaemon starting (debug mode: %@, syncOnce: %@)",
              debugMode ? @"ON" : @"OFF",
              syncOnce ? @"YES" : @"NO");
        fprintf(stderr, "WeaponXDaemon starting (debug mode: %s, syncOnce: %s)\n",
                debugMode ? "ON" : "OFF",
                syncOnce ? "YES" : "NO");
        
        WeaponXDaemon *daemon = [[WeaponXDaemon alloc] init];
        if (syncOnce) {
            [daemon runOneShotSelfTest];
            return 0;
        }
        [daemon startDaemon];
    }
    return 0;
}
