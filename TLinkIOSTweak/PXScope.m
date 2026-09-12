#import "PXScope.h"
#import "PXPaths.h"
#import <CoreFoundation/CoreFoundation.h>
#import <fcntl.h>
#import <os/lock.h>
#import <stdarg.h>
#import <stdio.h>
#import <sys/stat.h>
#import <sys/time.h>
#import <time.h>
#import <unistd.h>
#import <stdlib.h>

static __thread BOOL gPXReadingSecuritySettings = NO;
// Scope decisions are called from hook predicates. Nested evaluation must fail
// closed instead of re-entering Foundation/other hooks recursively.
static __thread unsigned int gPXScopeDecisionDepth = 0;

// Captured once, before any TLinkIOS hook is installed. Do not classify a process
// from subsequently projected NSBundle/NSProcessInfo values or substring matches.
static NSString *gPXProcessBundleID;
static NSString *gPXProcessName;
static NSString *gPXExtensionOwner;
static NSArray<NSString *> *gPXHostHomes;
static PXProcessRole gPXProcessRole = PXProcessUnknown;
static void PXScopeStartObserving(void);

static void PXCaptureProcessIdentity(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *bundle = NSBundle.mainBundle;
        gPXProcessBundleID = [bundle.bundleIdentifier copy] ?: @"";
        gPXProcessName = [NSProcessInfo.processInfo.processName copy] ?: @"";
        NSString *path = bundle.bundlePath.stringByStandardizingPath;
        NSString *executable = bundle.executablePath;
        if ([gPXProcessBundleID isEqualToString:@"com.apple.springboard"] &&
            [gPXProcessName isEqualToString:@"SpringBoard"]) {
            gPXProcessRole = PXProcessSpringBoard;
        } else if (PXIsCriticalSystemProcess(gPXProcessBundleID, gPXProcessName) ||
                   [gPXProcessBundleID isEqualToString:@"com.hydra.tlinkios"] ||
                   [gPXProcessBundleID isEqualToString:@"com.hydra.projectx"] ||
                   [gPXProcessBundleID isEqualToString:@"com.hydra.weaponx"]) {
            gPXProcessRole = PXProcessSystemDaemon;
        } else if ([gPXProcessBundleID isEqualToString:@"com.apple.WebKit.WebContent"]) {
            gPXProcessRole = PXProcessWebContent;
        } else if ([gPXProcessBundleID isEqualToString:@"com.apple.WebKit.Networking"]) {
            gPXProcessRole = PXProcessWebNetworking;
        } else if ([gPXProcessBundleID isEqualToString:@"com.apple.WebKit.GPU"]) {
            gPXProcessRole = PXProcessWebGPU;
        } else if ([gPXProcessBundleID isEqualToString:@"com.apple.SafariViewService"]) {
            gPXProcessRole = PXProcessSafariViewService;
        } else if (PXIsWebKitHelperProcess(gPXProcessBundleID, gPXProcessName)) {
            // A new/private helper variant needs an explicit policy first.
            gPXProcessRole = PXProcessUnknown;
        } else if ([executable hasPrefix:@"/usr/"] || [executable hasPrefix:@"/bin/"] ||
                   [executable hasPrefix:@"/sbin/"] || [executable hasPrefix:@"/var/jb/usr/"]) {
            gPXProcessRole = PXProcessSystemDaemon;
        } else if ([path.pathExtension.lowercaseString isEqualToString:@"appex"]) {
            gPXProcessRole = PXProcessExtension;
            // Inherit only from an actual enclosing .app/PlugIns/*.appex bundle.
            // A disabled explicit extension entry always overrides inheritance.
            NSString *plugins = path.stringByDeletingLastPathComponent;
            NSString *ownerPath = plugins.stringByDeletingLastPathComponent;
            if ([plugins.lastPathComponent.lowercaseString isEqualToString:@"plugins"] &&
                [ownerPath.pathExtension.lowercaseString isEqualToString:@"app"]) {
                NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:
                    [ownerPath stringByAppendingPathComponent:@"Info.plist"]];
                id owner = info[@"CFBundleIdentifier"];
                if ([owner isKindOfClass:NSString.class]) gPXExtensionOwner = [owner copy];
            }
        } else if ([path.pathExtension.lowercaseString isEqualToString:@"app"] &&
                   gPXProcessBundleID.length) {
            gPXProcessRole = PXProcessMainApp;
        }
        if (gPXProcessRole >= PXProcessWebContent && gPXProcessRole <= PXProcessSafariViewService) {
            NSMutableOrderedSet *homes = [NSMutableOrderedSet orderedSet];
            NSString *home = NSHomeDirectory();
            if (home.length) [homes addObject:home.stringByStandardizingPath];
            for (NSString *key in @[@"HOME", @"CFFIXED_USER_HOME"]) {
                const char *raw = getenv(key.UTF8String);
                NSString *candidate = raw ? [NSString stringWithUTF8String:raw] : nil;
                if (candidate.length) [homes addObject:candidate.stringByStandardizingPath];
            }
            gPXHostHomes = [homes.array copy];
        }
    });
}

BOOL PXScopeIsReadingSecuritySettings(void) {
    return gPXReadingSecuritySettings;
}

static id PXReadSecuritySettingObject(NSString *key) {
    if (!key.length) return nil;
    gPXReadingSecuritySettings = YES;
    id result = nil;

    CFStringRef cfKey = (__bridge CFStringRef)key;
    CFStringRef appID = CFSTR("com.weaponx.securitySettings");
    CFPropertyListRef pref = CFPreferencesCopyAppValue(cfKey, appID);
    if (pref) {
        result = CFBridgingRelease(pref);
        gPXReadingSecuritySettings = NO;
        return result;
    }

    NSArray<NSString *> *paths = @[
        @"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist",
        @"/private/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist"
    ];
    for (NSString *path in paths) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
        if ([dict isKindOfClass:[NSDictionary class]] && dict[key] != nil) {
            result = dict[key];
            break;
        }
    }
    gPXReadingSecuritySettings = NO;
    return result;
}

static BOOL PXReadSecuritySettingBool(NSString *key) {
    id v = PXReadSecuritySettingObject(key);
    return v ? [v boolValue] : NO;
}

static void PXSynchronizeSecuritySettings(void) {
    gPXReadingSecuritySettings = YES;
    CFPreferencesAppSynchronize(CFSTR("com.weaponx.securitySettings"));
    gPXReadingSecuritySettings = NO;
}

static NSTimeInterval PXMonotonicNow(void) {
    // Scope decisions sit underneath many spoof hooks, including our own
    // -[NSProcessInfo systemUptime] hook. Never use an Objective-C/Foundation
    // clock here: doing so can re-enter PXProcessIsAllowedForSpoofing while a
    // scope decision is already in progress and recurse until the stack dies.
    struct timespec ts = {0};
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
        return 0;
    }
    return (NSTimeInterval)ts.tv_sec + ((NSTimeInterval)ts.tv_nsec / 1000000000.0);
}

// Immutable snapshot for hot-path scope decisions.
@interface PXScopeSnapshot : NSObject
@property (nonatomic, assign, readonly) BOOL deviceSpoofEnabled;
@property (nonatomic, assign, readonly) BOOL safariStackEnabled;
@property (nonatomic, assign, readonly) BOOL fullSpoofTestModeEnabled;
@property (nonatomic, assign, readonly) BOOL displayUIScaleEnabled;
@property (nonatomic, assign, readonly) BOOL displayPixelMetricsEnabled;
@property (nonatomic, assign, readonly) BOOL displayWebScreenEnabled;
@property (nonatomic, copy, readonly) NSDictionary *scopedApps;
@property (nonatomic, assign, readonly) uint64_t generation;
@property (nonatomic, assign, readonly) NSTimeInterval expirationTime;
- (instancetype)initWithDeviceSpoofEnabled:(BOOL)deviceSpoofEnabled
                        safariStackEnabled:(BOOL)safariStackEnabled
                  fullSpoofTestModeEnabled:(BOOL)fullSpoofTestModeEnabled
                     displayUIScaleEnabled:(BOOL)displayUIScaleEnabled
                displayPixelMetricsEnabled:(BOOL)displayPixelMetricsEnabled
                    displayWebScreenEnabled:(BOOL)displayWebScreenEnabled
                                scopedApps:(NSDictionary *)scopedApps
                                generation:(uint64_t)generation
                            expirationTime:(NSTimeInterval)expirationTime;
@end

@implementation PXScopeSnapshot

- (instancetype)initWithDeviceSpoofEnabled:(BOOL)deviceSpoofEnabled
                        safariStackEnabled:(BOOL)safariStackEnabled
                  fullSpoofTestModeEnabled:(BOOL)fullSpoofTestModeEnabled
                     displayUIScaleEnabled:(BOOL)displayUIScaleEnabled
                displayPixelMetricsEnabled:(BOOL)displayPixelMetricsEnabled
                    displayWebScreenEnabled:(BOOL)displayWebScreenEnabled
                                scopedApps:(NSDictionary *)scopedApps
                                generation:(uint64_t)generation
                            expirationTime:(NSTimeInterval)expirationTime {
    self = [super init];
    if (self) {
        _deviceSpoofEnabled = deviceSpoofEnabled;
        _safariStackEnabled = safariStackEnabled;
        _fullSpoofTestModeEnabled = fullSpoofTestModeEnabled;
        _displayUIScaleEnabled = displayUIScaleEnabled;
        _displayPixelMetricsEnabled = displayPixelMetricsEnabled;
        _displayWebScreenEnabled = displayWebScreenEnabled;
        _scopedApps = [scopedApps copy] ?: @{};
        _generation = generation;
        _expirationTime = expirationTime;
    }
    return self;
}

@end

static os_unfair_lock gSnapshotLock = OS_UNFAIR_LOCK_INIT;
static os_unfair_lock gRefreshLock = OS_UNFAIR_LOCK_INIT;
static os_unfair_lock gDecisionLogLock = OS_UNFAIR_LOCK_INIT;
static PXScopeSnapshot *gSnapshot = nil; // immutable once published
static uint64_t gScopeGeneration = 1;
static NSMutableDictionary *gDecisionLogTimes = nil; // protected by gDecisionLogLock

static os_unfair_lock gDebugFlagLock = OS_UNFAIR_LOCK_INIT;
static NSTimeInterval gDebugFlagCheckTime = 0;
static BOOL gDebugFlagsInitialized = NO;
static BOOL gDebugFlagEnabled = NO;
static BOOL gDebugFlagVerbose = NO;

static BOOL PXScopeDebugFlagState(BOOL verbose) {
    NSTimeInterval now = PXMonotonicNow();
    os_unfair_lock_lock(&gDebugFlagLock);
    if (!gDebugFlagsInitialized || now - gDebugFlagCheckTime >= 1.0) {
        gDebugFlagEnabled = access("/tmp/px_debug_scope", F_OK) == 0 ||
                            access("/tmp/px_debug_all", F_OK) == 0;
        gDebugFlagVerbose = access("/tmp/px_debug_scope_verbose", F_OK) == 0;
        gDebugFlagCheckTime = now;
        gDebugFlagsInitialized = YES;
    }
    BOOL result = verbose ? gDebugFlagVerbose : gDebugFlagEnabled;
    os_unfair_lock_unlock(&gDebugFlagLock);
    return result;
}

static BOOL PXScopeFileDebugEnabled(void) {
    return PXScopeDebugFlagState(NO);
}

static BOOL PXScopeFileDebugVerboseEnabled(void) {
    return PXScopeDebugFlagState(YES);
}

static void PXScopeFileLog(NSString *format, ...) {
    if (!PXScopeFileDebugEnabled() || !format.length) return;

    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    if (!message.length) return;

    struct timeval tv;
    gettimeofday(&tv, NULL);
    struct tm tmv;
    localtime_r(&tv.tv_sec, &tmv);

    NSString *line = [NSString stringWithFormat:@"%02d:%02d:%02d.%03d pid=%d %@\n",
                      tmv.tm_hour, tmv.tm_min, tmv.tm_sec, (int)(tv.tv_usec / 1000), getpid(), message];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    if (!data.length) return;

    mkdir("/var/mobile/Library/TLinkIOS", 0755);
    int fd = open("/var/mobile/Library/TLinkIOS/scope_decision.log", O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) fd = open("/tmp/scope_decision.log", O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) return;
    write(fd, data.bytes, data.length);
    close(fd);
}

static NSDictionary *PXLoadScopedAppsFromDisk(void) {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PXGlobalScopePath()];
    NSDictionary *scoped = [dict isKindOfClass:[NSDictionary class]] ? dict[@"ScopedApps"] : nil;
    return [scoped isKindOfClass:[NSDictionary class]] ? [scoped copy] : @{};
}

static PXScopeSnapshot *PXBuildSnapshot(uint64_t generation) {
    // Sync once per snapshot rebuild. Individual reads below no longer force cfprefsd
    // synchronization, avoiding repeated IPC/I/O on this otherwise hot cache-miss path.
    PXSynchronizeSecuritySettings();

    // Disk/settings reads happen WITHOUT holding gSnapshotLock.
    BOOL deviceEnabled = PXReadSecuritySettingBool(@"deviceSpoofingEnabled");
    BOOL fullTest = PXReadSecuritySettingBool(@"fullSpoofTestModeEnabled");

    BOOL safariEnabled = deviceEnabled;
    id safariSetting = PXReadSecuritySettingObject(@"safariStackSpoofEnabled");
    if (safariSetting != nil) {
        safariEnabled = deviceEnabled && [safariSetting boolValue];
    }
    if (deviceEnabled && fullTest) {
        safariEnabled = YES;
    }

    BOOL uiScaleEnabled = deviceEnabled;
    id uiScaleSetting = PXReadSecuritySettingObject(@"displayUIScaleSpoofEnabled");
    if (uiScaleSetting != nil) {
        uiScaleEnabled = deviceEnabled && [uiScaleSetting boolValue];
    }

    BOOL pixelMetricsEnabled = deviceEnabled;
    id pixelMetricsSetting = PXReadSecuritySettingObject(@"displayPixelMetricsSpoofEnabled");
    if (pixelMetricsSetting != nil) {
        pixelMetricsEnabled = deviceEnabled && [pixelMetricsSetting boolValue];
    }

    BOOL webScreenEnabled = deviceEnabled;
    id webScreenSetting = PXReadSecuritySettingObject(@"displayWebScreenSpoofEnabled");
    if (webScreenSetting != nil) {
        webScreenEnabled = deviceEnabled && [webScreenSetting boolValue];
    }

    NSDictionary *scoped = PXLoadScopedAppsFromDisk();

    return [[PXScopeSnapshot alloc]
        initWithDeviceSpoofEnabled:deviceEnabled
        safariStackEnabled:safariEnabled
        fullSpoofTestModeEnabled:(deviceEnabled && fullTest)
        displayUIScaleEnabled:uiScaleEnabled
        displayPixelMetricsEnabled:pixelMetricsEnabled
        displayWebScreenEnabled:webScreenEnabled
        scopedApps:scoped ?: @{}
        generation:generation
        expirationTime:PXMonotonicNow() + 1.0];
}

static PXScopeSnapshot *PXCurrentSnapshot(void) {
    PXScopeSnapshot *local = nil;
    NSTimeInterval now = PXMonotonicNow();

    os_unfair_lock_lock(&gSnapshotLock);
    local = gSnapshot;
    BOOL needsRefresh = (!local || now >= local.expirationTime);
    os_unfair_lock_unlock(&gSnapshotLock);
    if (!needsRefresh) return local;

    // Only one thread reloads disk; other threads may use the last valid snapshot.
    if (!os_unfair_lock_trylock(&gRefreshLock)) {
        os_unfair_lock_lock(&gSnapshotLock);
        local = gSnapshot;
        os_unfair_lock_unlock(&gSnapshotLock);
        if (local) return local;
        os_unfair_lock_lock(&gRefreshLock);
    }

    for (;;) {
        os_unfair_lock_lock(&gSnapshotLock);
        local = gSnapshot;
        now = PXMonotonicNow();
        needsRefresh = (!local || now >= local.expirationTime);
        uint64_t generation = gScopeGeneration;
        os_unfair_lock_unlock(&gSnapshotLock);
        if (!needsRefresh) break;

        PXScopeSnapshot *built = PXBuildSnapshot(generation);
        os_unfair_lock_lock(&gSnapshotLock);
        if (gScopeGeneration == generation) {
            gSnapshot = built;
            local = built;
            os_unfair_lock_unlock(&gSnapshotLock);
            break;
        }
        // A notification invalidated the cache while disk I/O was in flight.
        // Never publish the stale build; retry using the new generation.
        local = gSnapshot;
        os_unfair_lock_unlock(&gSnapshotLock);
        if (local) break;
    }

    os_unfair_lock_unlock(&gRefreshLock);
    return local;
}

void PXInvalidateScopeDecisionCache(void) {
    // Atomically invalidate snapshot + bump generation. Do not mutate published snapshot objects.
    os_unfair_lock_lock(&gSnapshotLock);
    gSnapshot = nil;
    gScopeGeneration++;
    os_unfair_lock_unlock(&gSnapshotLock);
}

uint64_t PXScopeGeneration(void) {
    os_unfair_lock_lock(&gSnapshotLock);
    uint64_t gen = gScopeGeneration;
    os_unfair_lock_unlock(&gSnapshotLock);
    return gen;
}

static void PXScopeNotify(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    PXInvalidateScopeDecisionCache();
}

static BOOL PXScopedBundleEnabledInSnapshot(PXScopeSnapshot *snap, NSString *bundleID) {
    if (![bundleID isKindOfClass:[NSString class]] || !bundleID.length || !snap) return NO;
    NSDictionary *entry = [snap.scopedApps[bundleID] isKindOfClass:[NSDictionary class]] ? snap.scopedApps[bundleID] : nil;
    return [entry[@"enabled"] boolValue];
}

static BOOL PXScopedOwnerEnabledInSnapshot(PXScopeSnapshot *snap, NSString *bundleID) {
    if (!bundleID.length) return NO;
    if (gPXProcessRole == PXProcessExtension && [bundleID isEqualToString:gPXProcessBundleID] &&
        snap.scopedApps[bundleID] == nil && gPXExtensionOwner.length) {
        return PXScopedBundleEnabledInSnapshot(snap, gPXExtensionOwner);
    }
    return PXScopedBundleEnabledInSnapshot(snap, bundleID);
}

static BOOL PXBundleIsStrictlyScopedInSnapshot(PXScopeSnapshot *snap, NSString *bundleID, NSString *processName) {
    if (!snap.deviceSpoofEnabled) return NO;
    if (![bundleID isKindOfClass:[NSString class]] || !bundleID.length) return NO;
    if ([bundleID isEqualToString:@"com.hydra.tlinkios"] || [bundleID isEqualToString:@"com.hydra.weaponx"]) return NO;
    if (PXIsCriticalSystemProcess(bundleID, processName)) return NO;
    if (PXIsWebKitHelperProcess(bundleID, processName)) return NO;
    return PXScopedOwnerEnabledInSnapshot(snap, bundleID);
}

NSDictionary<NSString *, NSDictionary *> *PXScopedAppsSnapshot(void) {
    if (gPXScopeDecisionDepth != 0 || gPXReadingSecuritySettings) return @{};
    PXScopeSnapshot *snap = PXCurrentSnapshot();
    return [snap.scopedApps isKindOfClass:[NSDictionary class]] ? snap.scopedApps : @{};
}

BOOL PXBundleIsEnabledInScope(NSString *bundleID) {
    if (gPXScopeDecisionDepth != 0 || gPXReadingSecuritySettings) return NO;
    return PXScopedOwnerEnabledInSnapshot(PXCurrentSnapshot(), bundleID);
}

NSArray<NSString *> *PXBrowserBundleIdentifierPrefixes(void) {
    static NSArray<NSString *> *prefixes = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        prefixes = @[
            @"com.apple.mobilesafari",
            @"com.google.chrome",
            @"org.mozilla.ios.Firefox",
            @"com.brave.ios",
            @"com.microsoft.msedge",
            @"com.opera"
        ];
    });
    return prefixes;
}

BOOL PXIsBrowserBundleIdentifier(NSString *bundleID) {
    if (![bundleID isKindOfClass:[NSString class]] || !bundleID.length) return NO;
    for (NSString *prefix in PXBrowserBundleIdentifierPrefixes()) {
        if ([bundleID isEqualToString:prefix] || [bundleID hasPrefix:prefix]) return YES;
    }
    return NO;
}

BOOL PXIsSafariBrowserBundleIdentifier(NSString *bundleID) {
    NSString *safariPrefix = [PXBrowserBundleIdentifierPrefixes() firstObject];
    return safariPrefix.length &&
        ([bundleID isEqualToString:safariPrefix] || [bundleID hasPrefix:safariPrefix]);
}

static void PXScopeStartObserving(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
        if (!center) return;
        CFNotificationCenterAddObserver(center, NULL, PXScopeNotify, CFSTR("com.hydra.tlinkios.settings.changed"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(center, NULL, PXScopeNotify, CFSTR("com.hydra.tlinkios.profileChanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(center, NULL, PXScopeNotify, CFSTR("com.hydra.tlinkios.scopedAppsChanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(center, NULL, PXScopeNotify, CFSTR("com.hydra.tlinkios.safariStackSpoofToggleChanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    });
}

BOOL PXDeviceSpoofingEnabled(void) {
    if (gPXScopeDecisionDepth != 0 || gPXReadingSecuritySettings) return NO;
    PXScopeSnapshot *snap = PXCurrentSnapshot();
    return snap.deviceSpoofEnabled;
}

BOOL PXSafariStackSpoofEnabled(void) {
    if (gPXScopeDecisionDepth != 0 || gPXReadingSecuritySettings) return NO;
    PXScopeSnapshot *snap = PXCurrentSnapshot();
    return snap.safariStackEnabled;
}

BOOL PXFullSpoofTestModeEnabled(void) {
    if (gPXScopeDecisionDepth != 0 || gPXReadingSecuritySettings) return NO;
    PXScopeSnapshot *snap = PXCurrentSnapshot();
    return snap.fullSpoofTestModeEnabled;
}

BOOL PXDisplayUIScaleSpoofEnabled(void) {
    if (gPXScopeDecisionDepth != 0 || gPXReadingSecuritySettings) return NO;
    PXScopeSnapshot *snap = PXCurrentSnapshot();
    return snap.displayUIScaleEnabled;
}

BOOL PXDisplayPixelMetricsSpoofEnabled(void) {
    if (gPXScopeDecisionDepth != 0 || gPXReadingSecuritySettings) return NO;
    PXScopeSnapshot *snap = PXCurrentSnapshot();
    return snap.displayPixelMetricsEnabled;
}

BOOL PXDisplayWebScreenSpoofEnabled(void) {
    if (gPXScopeDecisionDepth != 0 || gPXReadingSecuritySettings) return NO;
    PXScopeSnapshot *snap = PXCurrentSnapshot();
    return snap.displayWebScreenEnabled;
}

BOOL PXIsCriticalSystemProcess(NSString *bundleID, NSString *processName) {
    static NSSet<NSString *> *criticalNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        criticalNames = [NSSet setWithArray:@[
            @"SpringBoard",
            @"backboardd",
            @"runningboardd",
            @"assertiond",
            @"launchd",
            @"installd",
            @"mobile_installation_proxy",
            @"securityd",
            @"mediaserverd",
            @"commcenter",
            @"aggregated"
        ]];
    });
    if ([processName isKindOfClass:[NSString class]] && [criticalNames containsObject:processName]) return YES;
    if ([bundleID isEqualToString:@"com.apple.springboard"]) return YES;
    return NO;
}

BOOL PXIsSpringBoardProcess(void) {
    return PXBootstrapAllows(PXHookCapabilitySpringBoard);
}

BOOL PXIsWebKitHelperProcess(NSString *bundleID, NSString *processName) {
    if ([bundleID isEqualToString:@"com.apple.SafariViewService"] ||
        [bundleID hasPrefix:@"com.apple.WebKit."]) return YES;
    // Exact fallback identifies helpers with no bundle; bootstrap still denies
    // unknown bundle identity. Never classify an app called "GPU Viewer" as WebKit.
    if (!bundleID.length) {
        return [processName isEqualToString:@"SafariViewService"] ||
            [processName isEqualToString:@"com.apple.WebKit.WebContent"] ||
            [processName isEqualToString:@"com.apple.WebKit.Networking"] ||
            [processName isEqualToString:@"com.apple.WebKit.GPU"];
    }
    return NO;
}

NSString *PXWebKitHostBundleIdentifier(void) {
    // Called by bootstrap after canonical identity capture. No dispatch_once
    // negative sentinel: sandbox/container metadata can become readable later.
    if (!gPXHostHomes.count) return nil;
    static os_unfair_lock hostLock = OS_UNFAIR_LOCK_INIT;
    static NSString *cachedHost;
    static uint64_t cachedGeneration;
    static NSTimeInterval expires;
    NSTimeInterval now = PXMonotonicNow();
    uint64_t generation = PXScopeGeneration();
    if (!os_unfair_lock_trylock(&hostLock)) return nil; // no loader-thread wait
    if (generation == cachedGeneration && now < expires) {
        NSString *host = cachedHost;
        os_unfair_lock_unlock(&hostLock);
        return host;
    }
    // Only container metadata from application data directories is admissible.
    // Conflicting readable identifiers are ambiguous and must fail closed.
    NSString *resolved = nil;
    @try {
        for (NSString *home in gPXHostHomes) {
            NSString *canonical = home.stringByResolvingSymlinksInPath;
            if (![canonical hasPrefix:@"/private/var/mobile/Containers/Data/Application/"] &&
                ![canonical hasPrefix:@"/var/mobile/Containers/Data/Application/"]) continue;
            NSString *metadataPath = [canonical stringByAppendingPathComponent:
                @".com.apple.mobile_container_manager.metadata.plist"];
            NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
            id identifier = [metadata isKindOfClass:NSDictionary.class] ? metadata[@"MCMMetadataIdentifier"] : nil;
            if (![identifier isKindOfClass:NSString.class] || ![identifier length]) continue;
            if (resolved && ![resolved isEqualToString:identifier]) {
                resolved = nil;
                break;
            }
            resolved = identifier;
        }
        cachedHost = [resolved copy];
        cachedGeneration = generation;
        expires = now + 1.0;
    } @finally {
        os_unfair_lock_unlock(&hostLock);
    }
    return resolved;
}

BOOL PXWebKitHostIsScopedForSpoofing(void) {
    PXBootstrapDecision decision = PXBootstrapDecisionForCurrentProcess();
    if (decision.role < PXProcessWebContent || decision.role > PXProcessSafariViewService ||
        !decision.capabilities) return NO;
    PXScopeSnapshot *snap = PXCurrentSnapshot();
    if (!snap.deviceSpoofEnabled) return NO;
    NSString *host = PXWebKitHostBundleIdentifier();
    if (!host.length) return NO; // fail closed
    NSString *proc = [NSProcessInfo processInfo].processName;
    if (PXIsCriticalSystemProcess(host, proc)) return NO;
    return PXScopedBundleEnabledInSnapshot(snap, host);
}

BOOL PXIsSafariStackProcess(NSString *bundleID, NSString *processName) {
    if (![bundleID isKindOfClass:[NSString class]] || !bundleID.length) return NO;
    if (PXIsSafariBrowserBundleIdentifier(bundleID)) return YES;
    if ([bundleID isEqualToString:@"com.apple.webapp"]) return YES;
    if ([bundleID isEqualToString:@"com.apple.SafariViewService"]) return YES;
    if ([bundleID hasPrefix:@"com.apple.WebKit"]) return YES;

    BOOL appleWebKitBundle = [bundleID hasPrefix:@"com.apple.WebKit"] ||
        [bundleID hasPrefix:@"com.apple.Safari"] ||
        PXIsSafariBrowserBundleIdentifier(bundleID) ||
        [bundleID isEqualToString:@"com.apple.SafariViewService"];
    if ([processName isKindOfClass:[NSString class]] && processName.length) {
        if (appleWebKitBundle &&
            ([processName containsString:@"SafariViewService"] ||
             [processName containsString:@"WebKit"] ||
             [processName containsString:@"WebContent"] ||
             [processName containsString:@"Networking"] ||
             [processName containsString:@"GPU"] ||
             [processName containsString:@"Safari"])) {
            return YES;
        }
    }
    return NO;
}

BOOL PXBundleIsStrictlyScopedForSpoofing(NSString *bundleID) {
    if (gPXScopeDecisionDepth != 0 || gPXReadingSecuritySettings) return NO;
    PXScopeSnapshot *snap = PXCurrentSnapshot();
    NSString *proc = [NSProcessInfo processInfo].processName;
    return PXBundleIsStrictlyScopedInSnapshot(snap, bundleID, proc);
}

PXBootstrapDecision PXBootstrapDecisionForCurrentProcess(void) {
    PXBootstrapDecision denied = {PXProcessUnknown, 0, PXBootstrapDeniedUnknown, 0};
    if (gPXScopeDecisionDepth != 0) return denied;
    gPXScopeDecisionDepth++;
    PXBootstrapDecision result = denied;
    @try {
        @autoreleasepool {
            PXCaptureProcessIdentity();
            if (gPXProcessRole == PXProcessSpringBoard ||
                gPXProcessRole == PXProcessSystemDaemon || gPXProcessRole == PXProcessUnknown) {
                result = PXBootstrapEvaluate(gPXProcessRole, false, false, false, 0);
            } else {
                PXScopeSnapshot *snap = PXCurrentSnapshot();
                BOOL ownerScoped = NO;
                if (gPXProcessRole == PXProcessMainApp || gPXProcessRole == PXProcessExtension) {
                    ownerScoped = PXScopedOwnerEnabledInSnapshot(snap, gPXProcessBundleID);
                } else if (snap.deviceSpoofEnabled && snap.safariStackEnabled) {
                    NSString *host = PXWebKitHostBundleIdentifier();
                    ownerScoped = host.length && !PXIsWebKitHelperProcess(host, nil) &&
                        !PXIsCriticalSystemProcess(host, nil) &&
                        ![host isEqualToString:@"com.hydra.tlinkios"] &&
                        ![host isEqualToString:@"com.hydra.weaponx"] &&
                        ![host isEqualToString:@"com.hydra.projectx"] &&
                        PXScopedBundleEnabledInSnapshot(snap, host);
                }
                result = PXBootstrapEvaluate(gPXProcessRole, ownerScoped,
                    snap.deviceSpoofEnabled, snap.safariStackEnabled, snap.generation);
                if (result.capabilities) PXScopeStartObserving();
            }
            if (PXScopeFileDebugEnabled()) {
                static os_unfair_lock traceLock = OS_UNFAIR_LOCK_INIT;
                static PXBootstrapDecision last;
                static BOOL hasLast = NO;
                os_unfair_lock_lock(&traceLock);
                BOOL changed = !hasLast || last.role != result.role ||
                    last.capabilities != result.capabilities || last.reason != result.reason ||
                    last.scopeGeneration != result.scopeGeneration;
                last = result;
                hasLast = YES;
                os_unfair_lock_unlock(&traceLock);
                if (changed) {
                    PXScopeFileLog(@"[PXBootstrap] bundle=%@ proc=%@ role=%u capabilities=0x%x reason=%u gen=%llu",
                        gPXProcessBundleID, gPXProcessName, (unsigned)result.role,
                        (unsigned)result.capabilities, (unsigned)result.reason,
                        (unsigned long long)result.scopeGeneration);
                }
            }
        }
    } @catch (__unused NSException *exception) {
        result = denied;
    } @finally {
        gPXScopeDecisionDepth--;
    }
    return result;
}

BOOL PXBootstrapAllows(uint32_t anyCapability) {
    return PXBootstrapDecisionAllows(PXBootstrapDecisionForCurrentProcess(), anyCapability);
}

BOOL PXProcessIsAllowedForSpoofing(NSString *bundleID, NSString *processName, PXScopeOptions options) {
    PXBootstrapDecision decision = PXBootstrapDecisionForCurrentProcess();
    uint32_t requested = PXHookCapabilityNative;
    if (options & PXScopeOptionAllowSafariAuthStack) {
        requested |= PXHookCapabilityWebContent | PXHookCapabilityWebNetworking | PXHookCapabilityWebGraphics;
    }
    if (!PXBootstrapDecisionAllows(decision, requested)) return NO;
    if (![bundleID isEqualToString:gPXProcessBundleID]) return NO;
    if (PXIsCriticalSystemProcess(bundleID, processName)) return NO;
    if (gPXScopeDecisionDepth != 0) return NO;

    gPXScopeDecisionDepth++;
    BOOL allowed = NO;
    @try {
    // Resolve one immutable snapshot for the complete decision. This avoids repeated
    // lock/snapshot lookups through PXDeviceSpoofingEnabled/PXSafariStackSpoofEnabled/etc.
    PXScopeSnapshot *snap = PXCurrentSnapshot();
    BOOL webKitHelper = PXIsWebKitHelperProcess(bundleID, processName);
    NSString *webKitHost = webKitHelper ? PXWebKitHostBundleIdentifier() : nil;
    BOOL safariStackEnabled = snap.safariStackEnabled;
    BOOL webKitHostScoped = webKitHelper &&
                            ((options & PXScopeOptionAllowSafariAuthStack) != 0) &&
                            safariStackEnabled &&
                            webKitHost.length &&
                            !PXIsCriticalSystemProcess(webKitHost, processName) &&
                            PXScopedBundleEnabledInSnapshot(snap, webKitHost);
    BOOL strict = PXBundleIsStrictlyScopedInSnapshot(snap, bundleID, processName);
    BOOL safari = NO; // UIKit injection never implicitly grants unscoped Safari access.
    allowed = strict || safari || webKitHostScoped;

    // Decision log only when debug flags enabled — no hot-path file/NSLog otherwise.
    BOOL verboseFile = PXScopeFileDebugVerboseEnabled();
    BOOL debugOn = PXScopeFileDebugEnabled() || verboseFile;
    if (debugOn) {
        NSString *key = [NSString stringWithFormat:@"%@|%@|%@|%lu|%d", bundleID ?: @"", processName ?: @"", webKitHost ?: @"", (unsigned long)options, allowed];
        NSTimeInterval now = PXMonotonicNow();
        BOOL shouldLog = NO;
        os_unfair_lock_lock(&gDecisionLogLock);
        if (!gDecisionLogTimes) gDecisionLogTimes = [NSMutableDictionary dictionary];
        NSNumber *last = gDecisionLogTimes[key];
        if (!last || now - [last doubleValue] > 5.0 || verboseFile) {
            gDecisionLogTimes[key] = @(now);
            shouldLog = YES;
        }
        os_unfair_lock_unlock(&gDecisionLogLock);

        if (shouldLog) {
            if (!verboseFile || !last || now - [last doubleValue] > 5.0) {
                NSLog(@"[PXScopeDecision] bundle=%@ proc=%@ host=%@ strict=%d safari=%d webkitHost=%d options=%lu allowed=%d gen=%llu",
                      bundleID, processName, webKitHost, strict, safari, webKitHostScoped, (unsigned long)options, allowed, (unsigned long long)PXScopeGeneration());
            }
            PXScopeFileLog(@"[PXScopeDecision] bundle=%@ proc=%@ host=%@ strict=%d safari=%d webkitHost=%d options=%lu allowed=%d gen=%llu",
                           bundleID, processName, webKitHost, strict, safari, webKitHostScoped, (unsigned long)options, allowed, (unsigned long long)PXScopeGeneration());
        }
    }
    } @finally {
        gPXScopeDecisionDepth--;
    }

    return allowed;
}

BOOL PXAllowUnscopedSafariStack(void) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString *processName = [NSProcessInfo processInfo].processName;
    return PXProcessIsAllowedForSpoofing(bundleID, processName, PXScopeOptionAllowSafariAuthStack) && !PXBundleIsStrictlyScopedForSpoofing(bundleID);
}
