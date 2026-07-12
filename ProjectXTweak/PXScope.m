#import "PXScope.h"
#import <CoreFoundation/CoreFoundation.h>
#import <fcntl.h>
#import <os/lock.h>
#import <stdarg.h>
#import <stdio.h>
#import <sys/stat.h>
#import <sys/time.h>
#import <time.h>
#import <unistd.h>

static __thread BOOL gPXReadingSecuritySettings = NO;

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

static BOOL PXReadSecuritySettingHasKey(NSString *key) {
    if (!key.length) return NO;
    gPXReadingSecuritySettings = YES;

    CFStringRef cfKey = (__bridge CFStringRef)key;
    CFStringRef appID = CFSTR("com.weaponx.securitySettings");
    CFPropertyListRef pref = CFPreferencesCopyAppValue(cfKey, appID);
    if (pref) {
        CFRelease(pref);
        gPXReadingSecuritySettings = NO;
        return YES;
    }

    NSArray<NSString *> *paths = @[
        @"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist",
        @"/private/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist"
    ];
    for (NSString *path in paths) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
        if ([dict isKindOfClass:[NSDictionary class]] && dict[key] != nil) {
            gPXReadingSecuritySettings = NO;
            return YES;
        }
    }
    gPXReadingSecuritySettings = NO;
    return NO;
}

static BOOL PXReadSecuritySettingBool(NSString *key) {
    id v = PXReadSecuritySettingObject(key);
    return v ? [v boolValue] : NO;
}

// Immutable snapshot for hot-path scope decisions.
@interface PXScopeSnapshot : NSObject
@property (nonatomic, assign) BOOL deviceSpoofEnabled;
@property (nonatomic, assign) BOOL safariStackEnabled;
@property (nonatomic, assign) BOOL fullSpoofTestModeEnabled;
@property (nonatomic, assign) BOOL displayUIScaleEnabled;
@property (nonatomic, assign) BOOL displayPixelMetricsEnabled;
@property (nonatomic, assign) BOOL displayWebScreenEnabled;
@property (nonatomic, copy) NSDictionary *scopedApps; // immutable copy
@property (nonatomic, assign) uint64_t generation;
@property (nonatomic, assign) NSTimeInterval expirationTime;
@end

@implementation PXScopeSnapshot
@end

static os_unfair_lock gSnapshotLock = OS_UNFAIR_LOCK_INIT;
static os_unfair_lock gRefreshLock = OS_UNFAIR_LOCK_INIT;
static os_unfair_lock gDecisionLogLock = OS_UNFAIR_LOCK_INIT;
static PXScopeSnapshot *gSnapshot = nil; // immutable once published
static uint64_t gScopeGeneration = 1;
static NSMutableDictionary *gDecisionLogTimes = nil; // protected by gDecisionLogLock
static NSString *gWebKitHostBundle = nil; // process-lifetime immutable after first resolve

static BOOL PXScopeFileDebugEnabled(void) {
    return access("/tmp/px_debug_scope", F_OK) == 0 || access("/tmp/px_debug_all", F_OK) == 0;
}

static BOOL PXScopeFileDebugVerboseEnabled(void) {
    return access("/tmp/px_debug_scope_verbose", F_OK) == 0;
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

    mkdir("/var/mobile/Library/ProjectX", 0755);
    int fd = open("/var/mobile/Library/ProjectX/scope_decision.log", O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) fd = open("/tmp/scope_decision.log", O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) return;
    write(fd, data.bytes, data.length);
    close(fd);
}

static NSDictionary *PXLoadScopedAppsFromDisk(void) {
    NSArray<NSString *> *paths = @[
        @"/var/mobile/Library/Preferences/com.hydra.projectx.global_scope.plist",
        @"/private/var/mobile/Library/Preferences/com.hydra.projectx.global_scope.plist"
    ];
    for (NSString *path in paths) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
        NSDictionary *scoped = [dict isKindOfClass:[NSDictionary class]] ? dict[@"ScopedApps"] : nil;
        if ([scoped isKindOfClass:[NSDictionary class]]) {
            return [scoped copy];
        }
    }
    return @{};
}

static PXScopeSnapshot *PXBuildSnapshot(uint64_t generation) {
    // Disk/settings reads happen WITHOUT holding gSnapshotLock.
    BOOL deviceEnabled = PXReadSecuritySettingBool(@"deviceSpoofingEnabled");
    BOOL fullTest = PXReadSecuritySettingBool(@"fullSpoofTestModeEnabled");

    BOOL safariEnabled = deviceEnabled;
    if (PXReadSecuritySettingHasKey(@"safariStackSpoofEnabled")) {
        safariEnabled = deviceEnabled && PXReadSecuritySettingBool(@"safariStackSpoofEnabled");
    }
    if (deviceEnabled && fullTest) {
        safariEnabled = YES;
    }

    BOOL uiScaleEnabled = deviceEnabled;
    if (PXReadSecuritySettingHasKey(@"displayUIScaleSpoofEnabled")) {
        uiScaleEnabled = deviceEnabled && PXReadSecuritySettingBool(@"displayUIScaleSpoofEnabled");
    }

    BOOL pixelMetricsEnabled = deviceEnabled;
    if (PXReadSecuritySettingHasKey(@"displayPixelMetricsSpoofEnabled")) {
        pixelMetricsEnabled = deviceEnabled && PXReadSecuritySettingBool(@"displayPixelMetricsSpoofEnabled");
    }

    BOOL webScreenEnabled = deviceEnabled;
    if (PXReadSecuritySettingHasKey(@"displayWebScreenSpoofEnabled")) {
        webScreenEnabled = deviceEnabled && PXReadSecuritySettingBool(@"displayWebScreenSpoofEnabled");
    }

    NSDictionary *scoped = PXLoadScopedAppsFromDisk();

    PXScopeSnapshot *snap = [[PXScopeSnapshot alloc] init];
    snap.deviceSpoofEnabled = deviceEnabled;
    snap.fullSpoofTestModeEnabled = (deviceEnabled && fullTest);
    snap.safariStackEnabled = safariEnabled;
    snap.displayUIScaleEnabled = uiScaleEnabled;
    snap.displayPixelMetricsEnabled = pixelMetricsEnabled;
    snap.displayWebScreenEnabled = webScreenEnabled;
    snap.scopedApps = scoped ?: @{};
    snap.generation = generation;
    snap.expirationTime = [NSDate timeIntervalSinceReferenceDate] + 1.0;
    return snap;
}

static PXScopeSnapshot *PXCurrentSnapshot(void) {
    PXScopeSnapshot *local = nil;
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];

    os_unfair_lock_lock(&gSnapshotLock);
    local = gSnapshot;
    BOOL needsRefresh = (!local || now >= local.expirationTime);
    uint64_t gen = gScopeGeneration;
    os_unfair_lock_unlock(&gSnapshotLock);

    if (!needsRefresh) {
        return local;
    }

    // Only one thread reloads disk; others keep using the last valid snapshot.
    if (!os_unfair_lock_trylock(&gRefreshLock)) {
        // Another thread is refreshing; return best available snapshot.
        os_unfair_lock_lock(&gSnapshotLock);
        local = gSnapshot;
        os_unfair_lock_unlock(&gSnapshotLock);
        if (local) return local;
        // No snapshot yet — fall through and wait for refresh lock.
        os_unfair_lock_lock(&gRefreshLock);
    }

    // Re-check after acquiring refresh lock.
    os_unfair_lock_lock(&gSnapshotLock);
    local = gSnapshot;
    now = [NSDate timeIntervalSinceReferenceDate];
    needsRefresh = (!local || now >= local.expirationTime);
    gen = gScopeGeneration;
    os_unfair_lock_unlock(&gSnapshotLock);

    if (needsRefresh) {
        PXScopeSnapshot *built = PXBuildSnapshot(gen);
        os_unfair_lock_lock(&gSnapshotLock);
        // Only publish if generation still matches (no invalidate during build).
        if (gScopeGeneration == gen) {
            gSnapshot = built;
            local = built;
        } else {
            // Stale build; keep existing if any, else use built as best-effort.
            if (!gSnapshot) gSnapshot = built;
            local = gSnapshot;
        }
        os_unfair_lock_unlock(&gSnapshotLock);
    } else {
        os_unfair_lock_lock(&gSnapshotLock);
        local = gSnapshot;
        os_unfair_lock_unlock(&gSnapshotLock);
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

__attribute__((constructor))
static void PXScopeInit(void) {
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    if (!center) return;
    CFNotificationCenterAddObserver(center, NULL, PXScopeNotify, CFSTR("com.hydra.projectx.settings.changed"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(center, NULL, PXScopeNotify, CFSTR("com.hydra.projectx.profileChanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(center, NULL, PXScopeNotify, CFSTR("com.hydra.projectx.safariStackSpoofToggleChanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}

BOOL PXDeviceSpoofingEnabled(void) {
    PXScopeSnapshot *snap = PXCurrentSnapshot();
    return snap.deviceSpoofEnabled;
}

BOOL PXSafariStackSpoofEnabled(void) {
    PXScopeSnapshot *snap = PXCurrentSnapshot();
    return snap.safariStackEnabled;
}

BOOL PXFullSpoofTestModeEnabled(void) {
    PXScopeSnapshot *snap = PXCurrentSnapshot();
    return snap.fullSpoofTestModeEnabled;
}

BOOL PXDisplayUIScaleSpoofEnabled(void) {
    PXScopeSnapshot *snap = PXCurrentSnapshot();
    return snap.displayUIScaleEnabled;
}

BOOL PXDisplayPixelMetricsSpoofEnabled(void) {
    PXScopeSnapshot *snap = PXCurrentSnapshot();
    return snap.displayPixelMetricsEnabled;
}

BOOL PXDisplayWebScreenSpoofEnabled(void) {
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
    static int cached = -1;
    if (cached != -1) return cached == 1;
    NSString *proc = [NSProcessInfo processInfo].processName;
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
    cached = ([proc isEqualToString:@"SpringBoard"] || [bid isEqualToString:@"com.apple.springboard"]) ? 1 : 0;
    return cached == 1;
}

BOOL PXIsWebKitHelperProcess(NSString *bundleID, NSString *processName) {
    if ([bundleID isEqualToString:@"com.apple.SafariViewService"]) return YES;
    if ([bundleID hasPrefix:@"com.apple.WebKit"]) return YES;
    if ([processName isKindOfClass:[NSString class]]) {
        if ([processName containsString:@"SafariViewService"] ||
            [processName containsString:@"WebContent"] ||
            [processName containsString:@"Networking"] ||
            [processName containsString:@"GPU"] ||
            [processName containsString:@"WebKit"]) {
            return YES;
        }
    }
    return NO;
}

NSString *PXWebKitHostBundleIdentifier(void) {
    // Process-lifetime immutable cache; fail closed if not found.
    if (gWebKitHostBundle) {
        return gWebKitHostBundle.length ? gWebKitHostBundle : nil;
    }

    NSString *resolved = nil;
    NSArray<NSString *> *homeCandidates = @[
        NSHomeDirectory() ?: @"",
        [[[NSProcessInfo processInfo] environment][@"HOME"] isKindOfClass:[NSString class]] ? [[NSProcessInfo processInfo] environment][@"HOME"] : @"",
        [[[NSProcessInfo processInfo] environment][@"CFFIXED_USER_HOME"] isKindOfClass:[NSString class]] ? [[NSProcessInfo processInfo] environment][@"CFFIXED_USER_HOME"] : @""
    ];
    for (NSString *home in homeCandidates) {
        if (![home isKindOfClass:[NSString class]] || !home.length) continue;
        NSString *metadataPath = [home stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        NSString *identifier = [metadata[@"MCMMetadataIdentifier"] isKindOfClass:[NSString class]] ? metadata[@"MCMMetadataIdentifier"] : nil;
        if (identifier.length) {
            resolved = [identifier copy];
            break;
        }
    }
    // Sentinel empty string means "looked up, not found" (fail closed).
    gWebKitHostBundle = resolved ?: @"";
    return resolved;
}

BOOL PXWebKitHostIsScopedForSpoofing(void) {
    if (!PXDeviceSpoofingEnabled()) return NO;
    NSString *host = PXWebKitHostBundleIdentifier();
    if (!host.length) return NO; // fail closed
    NSString *proc = [NSProcessInfo processInfo].processName;
    if (PXIsCriticalSystemProcess(host, proc)) return NO;
    PXScopeSnapshot *snap = PXCurrentSnapshot();
    return PXScopedBundleEnabledInSnapshot(snap, host);
}

BOOL PXIsSafariStackProcess(NSString *bundleID, NSString *processName) {
    if (![bundleID isKindOfClass:[NSString class]] || !bundleID.length) return NO;
    if ([bundleID isEqualToString:@"com.apple.mobilesafari"]) return YES;
    if ([bundleID isEqualToString:@"com.apple.webapp"]) return YES;
    if ([bundleID isEqualToString:@"com.apple.SafariViewService"]) return YES;
    if ([bundleID hasPrefix:@"com.apple.WebKit"]) return YES;

    BOOL appleWebKitBundle = [bundleID hasPrefix:@"com.apple.WebKit"] ||
        [bundleID hasPrefix:@"com.apple.Safari"] ||
        [bundleID isEqualToString:@"com.apple.mobilesafari"] ||
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
    if (!PXDeviceSpoofingEnabled()) return NO;
    if (![bundleID isKindOfClass:[NSString class]] || !bundleID.length) return NO;
    if ([bundleID isEqualToString:@"com.hydra.projectx"] || [bundleID isEqualToString:@"com.hydra.weaponx"]) return NO;
    NSString *proc = [NSProcessInfo processInfo].processName;
    if (PXIsCriticalSystemProcess(bundleID, proc)) return NO;
    if (PXIsWebKitHelperProcess(bundleID, proc)) return NO;
    PXScopeSnapshot *snap = PXCurrentSnapshot();
    return PXScopedBundleEnabledInSnapshot(snap, bundleID);
}

BOOL PXProcessIsAllowedForSpoofing(NSString *bundleID, NSString *processName, PXScopeOptions options) {
    if (PXIsCriticalSystemProcess(bundleID, processName)) return NO;
    BOOL webKitHelper = PXIsWebKitHelperProcess(bundleID, processName);
    NSString *webKitHost = webKitHelper ? PXWebKitHostBundleIdentifier() : nil;
    BOOL webKitHostScoped = webKitHelper && ((options & PXScopeOptionAllowSafariAuthStack) != 0) && PXSafariStackSpoofEnabled() && PXWebKitHostIsScopedForSpoofing();
    BOOL strict = PXBundleIsStrictlyScopedForSpoofing(bundleID);
    BOOL safari = !webKitHelper && ((options & PXScopeOptionAllowSafariAuthStack) && PXSafariStackSpoofEnabled() && PXIsSafariStackProcess(bundleID, processName));
    BOOL allowed = strict || safari || webKitHostScoped;

    // Decision log only when debug flags enabled — no hot-path file/NSLog otherwise.
    BOOL verboseFile = PXScopeFileDebugVerboseEnabled();
    BOOL debugOn = PXScopeFileDebugEnabled() || verboseFile;
    if (debugOn) {
        NSString *key = [NSString stringWithFormat:@"%@|%@|%@|%lu|%d", bundleID ?: @"", processName ?: @"", webKitHost ?: @"", (unsigned long)options, allowed];
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
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

    return allowed;
}

BOOL PXAllowUnscopedSafariStack(void) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString *processName = [NSProcessInfo processInfo].processName;
    return PXProcessIsAllowedForSpoofing(bundleID, processName, PXScopeOptionAllowSafariAuthStack) && !PXBundleIsStrictlyScopedForSpoofing(bundleID);
}
