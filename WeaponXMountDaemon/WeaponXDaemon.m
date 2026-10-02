#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
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

// Constants
static const int kCheckInterval = 5; // Check every 5 seconds
static NSString *kGuardianDir = nil; // Will be initialized in init
static NSString *ROOT_PREFIX = nil; // Will be set based on environment
static os_log_t weaponx_log = NULL;
static BOOL debugMode = NO;
static NSString * const kTLinkIOSFilterChangedNotification = @"com.hydra.tlinkios.filterPlistChanged";

@interface WeaponXDaemon : NSObject
@property (nonatomic, strong) NSTimer *monitorTimer;
@property (nonatomic, strong) NSMutableDictionary *processInfo;
@property (nonatomic, strong) NSMutableArray *protectedProcesses;
- (void)syncTLinkIOSFilterPlists;
- (void)writeRuntimeStatus:(NSString *)event;
- (void)runOneShotSelfTest;
@end

static void PXFilterChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)name; (void)object; (void)userInfo;
    WeaponXDaemon *daemon = (__bridge WeaponXDaemon *)observer;
    [daemon syncTLinkIOSFilterPlists];
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

- (void)startDaemon {
    [self log:@"WeaponXDaemon starting..." withType:OS_LOG_TYPE_INFO];
    [self writeRuntimeStatus:@"start"];

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    (__bridge const void *)(self),
                                    PXFilterChangedCallback,
                                    (__bridge CFStringRef)kTLinkIOSFilterChangedNotification,
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

- (void)checkProcesses {
    // Historical versions also scanned processes and relaunched TLinkIOS when the
    // GUI was not running. A root KeepAlive daemon must not own GUI lifecycle.
    // Its only periodic responsibility is privileged filter synchronization.
    [self log:@"Synchronizing tweak filters..." withType:OS_LOG_TYPE_DEBUG];
    [self syncTLinkIOSFilterPlists];
    [self updateStateFile];
}

- (void)syncTLinkIOSFilterPlists {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *stagingDir = @"/var/mobile/Library/TLinkIOS/filter_plists";
    NSString *targetDir = [self substrateDynamicLibrariesDir];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:stagingDir isDirectory:&isDir] || !isDir) return;
    if (![fm fileExistsAtPath:targetDir isDirectory:&isDir] || !isDir) {
        NSError *mkErr = nil;
        [fm createDirectoryAtPath:targetDir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0755} error:&mkErr];
        if (mkErr) {
            [self log:[NSString stringWithFormat:@"Filter sync failed to create target dir: %@", mkErr.localizedDescription] withType:OS_LOG_TYPE_ERROR];
            return;
        }
    }

    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
    result[@"targetDir"] = targetDir ?: @"";
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
            [self log:[NSString stringWithFormat:@"Filter sync failed for %@: %@", name, syncResult[@"status"] ?: @"unknown"] withType:OS_LOG_TYPE_ERROR];
        }
    }
    NSString *debugPath = @"/var/mobile/Library/TLinkIOS/filter_daemon_debug.plist";
    [result writeToFile:debugPath atomically:YES];
    chmod([debugPath fileSystemRepresentation], 0644);
    chown([debugPath fileSystemRepresentation], 501, 501);
}

- (NSString *)substrateDynamicLibrariesDir {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    // RootHide's jbroot() is the source of truth for jailbreak-owned files.
    // Never prefer a fixed /var/jb path left by another jailbreak/layout.
    return PXJailbreakRootPath(@"/Library/MobileSubstrate/DynamicLibraries");
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
        @"targetDir": [self substrateDynamicLibrariesDir] ?: @""
    };
    [status writeToFile:path atomically:YES];
    chmod([path fileSystemRepresentation], 0644);
    chown([path fileSystemRepresentation], 501, 501);
}

- (void)runOneShotSelfTest {
    [self log:@"WeaponXDaemon one-shot self-test" withType:OS_LOG_TYPE_INFO];
    [self writeRuntimeStatus:@"self-test"];
    [self syncTLinkIOSFilterPlists];
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
