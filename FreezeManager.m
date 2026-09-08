#import "FreezeManager.h"
#import "IdentifierManager.h"
#import "common/PXProcessKiller.h"
#import <string.h>
#import <sys/stat.h>

@interface FreezeManager ()
@property (nonatomic, strong) BottomButtons *bottomButtons;
@property (nonatomic, strong) IdentifierManager *identifierManager;
@property (nonatomic, strong) NSMutableDictionary *frozenApps;
@end

@implementation FreezeManager

+ (instancetype)sharedManager {
    static FreezeManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    if (self = [super init]) {
        _bottomButtons = [BottomButtons sharedInstance];
        _identifierManager = [IdentifierManager sharedManager];
        _frozenApps = [NSMutableDictionary dictionary];
        
        // Load frozen state from UserDefaults - Use suite name to avoid conflicts
        NSUserDefaults *freezeDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.hydra.tlinkios.freezer"];
        NSDictionary *savedState = [freezeDefaults dictionaryForKey:@"FrozenApps"];
        if (savedState) {
            [_frozenApps setDictionary:savedState];
            NSLog(@"[FreezeManager] Loaded frozen app state: %@", savedState);
        } else {
            // Try to load from standard UserDefaults as fallback for backward compatibility
            NSDictionary *oldSavedState = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"FrozenApps"];
            if (oldSavedState) {
                [_frozenApps setDictionary:oldSavedState];
                NSLog(@"[FreezeManager] Loaded frozen app state from standard defaults (legacy): %@", oldSavedState);
                
                // Migrate the data to the new location
                [self saveFrozenState];
                
                // Clear the data from the old location
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"FrozenApps"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        }
    }
    return self;
}

#pragma mark - App Freezing Management

- (void)freezeApplication:(NSString *)bundleID {
    if (!bundleID) {
        NSLog(@"[FreezeManager] Error: Invalid bundle ID");
        return;
    }
    
    // Skip if the bundleID matches our own tweak's bundle ID
    if ([bundleID isEqualToString:@"com.hydra.tlinkios"]) {
        NSLog(@"[FreezeManager] Skipping termination of our own tweak");
        return;
    }
    
    // Verify app is installed and enabled
    NSDictionary *appInfo = [self.identifierManager getApplicationInfo:bundleID];
    if (!appInfo || ![appInfo[@"installed"] boolValue]) {
        NSLog(@"[FreezeManager] App is not installed: %@", bundleID);
        return;
    }
    
    if (![self.identifierManager isApplicationEnabled:bundleID]) {
        NSLog(@"[FreezeManager] Skipping freeze for disabled app: %@", bundleID);
        return;
    }
    
    // Kill the application
    [self killApplication:bundleID];
    
    // Update frozen state
    self.frozenApps[bundleID] = @YES;
    [self saveFrozenState];
    
    // Post notification for UI update
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AppFrozenStateChanged"
                                                    object:self
                                                  userInfo:@{@"bundleID": bundleID}];
}

- (void)unfreezeApplication:(NSString *)bundleID {
    if (!bundleID) {
        NSLog(@"[FreezeManager] Error: Invalid bundle ID for unfreeze");
        return;
    }
    
    // Skip if the bundleID matches our own tweak's bundle ID
    if ([bundleID isEqualToString:@"com.hydra.tlinkios"]) {
        NSLog(@"[FreezeManager] Skipping unfreeze of our own tweak");
        return;
    }
    
    // Verify app is installed and enabled
    NSDictionary *appInfo = [self.identifierManager getApplicationInfo:bundleID];
    if (!appInfo || ![appInfo[@"installed"] boolValue]) {
        NSLog(@"[FreezeManager] App is not installed: %@", bundleID);
        return;
    }
    
    if (![self.identifierManager isApplicationEnabled:bundleID]) {
        NSLog(@"[FreezeManager] App is not enabled: %@", bundleID);
        return;
    }
    
    // Remove from frozen state
    [self.frozenApps removeObjectForKey:bundleID];
    [self saveFrozenState];
    
    // Post notification for UI update
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AppFrozenStateChanged"
                                                    object:self
                                                  userInfo:@{@"bundleID": bundleID}];
}

- (BOOL)isApplicationFrozen:(NSString *)bundleID {
    return [self.frozenApps[bundleID] boolValue];
}

#pragma mark - Helper Methods

- (void)saveFrozenState {
    // Use suite name to avoid conflicts with other settings
    NSUserDefaults *freezeDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.hydra.tlinkios.freezer"];
    [freezeDefaults setObject:self.frozenApps forKey:@"FrozenApps"];
    [freezeDefaults synchronize];
    
    NSLog(@"[FreezeManager] Saved frozen app state: %@", self.frozenApps);
}

- (void)killApplication:(NSString *)bundleID {
    if (![bundleID isKindOfClass:[NSString class]] || bundleID.length == 0) return;

    LSApplicationProxy *appProxy = [LSApplicationProxy applicationProxyForIdentifier:bundleID];
    if (!appProxy) {
        NSLog(@"[FreezeManager] Could not find application proxy for bundle ID: %@", bundleID);
        return;
    }

    NSArray<NSString *> *protectedProcesses = @[@"SpringBoard", @"backboardd", @"TLinkIOS", @"installd", @"assertiond"];
    NSMutableOrderedSet<NSString *> *executableNames = [NSMutableOrderedSet orderedSet];
    NSString *mainExecutable = appProxy.bundleExecutable;
    if ([mainExecutable isKindOfClass:[NSString class]] && mainExecutable.length > 0 &&
        ![protectedProcesses containsObject:mainExecutable]) {
        [executableNames addObject:mainExecutable];
    }

    // App extensions can keep an App Group live after the host executable exits. Resolve only
    // .appex bundles physically owned by this installed app and kill their exact executables too.
    @try {
        id bundleURLObject = nil;
        @try { bundleURLObject = [appProxy valueForKey:@"bundleURL"]; } @catch (__unused NSException *exception) {}
        NSString *applicationBundlePath = nil;
        if ([bundleURLObject isKindOfClass:[NSURL class]]) {
            applicationBundlePath = [(NSURL *)bundleURLObject path];
        } else if ([bundleURLObject isKindOfClass:[NSString class]]) {
            applicationBundlePath = (NSString *)bundleURLObject;
        }

        struct stat applicationBundleStat;
        memset(&applicationBundleStat, 0, sizeof(applicationBundleStat));
        const char *applicationBundleFS = applicationBundlePath.fileSystemRepresentation;
        if (applicationBundlePath.length > 0 &&
            [[applicationBundlePath pathExtension].lowercaseString isEqualToString:@"app"] &&
            applicationBundleFS &&
            lstat(applicationBundleFS, &applicationBundleStat) == 0 &&
            S_ISDIR(applicationBundleStat.st_mode) &&
            !S_ISLNK(applicationBundleStat.st_mode)) {
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSArray<NSString *> *extensionLocations = @[
                applicationBundlePath,
                [applicationBundlePath stringByAppendingPathComponent:@"PlugIns"],
                [applicationBundlePath stringByAppendingPathComponent:@"Plugins"]
            ];

            for (NSUInteger locationIndex = 0; locationIndex < extensionLocations.count; locationIndex++) {
                NSString *location = extensionLocations[locationIndex];
                struct stat locationStat;
                memset(&locationStat, 0, sizeof(locationStat));
                const char *locationFS = location.fileSystemRepresentation;
                if (!locationFS || lstat(locationFS, &locationStat) != 0 ||
                    !S_ISDIR(locationStat.st_mode) || S_ISLNK(locationStat.st_mode)) {
                    continue;
                }

                NSArray<NSString *> *entries = [fileManager contentsOfDirectoryAtPath:location error:nil];
                for (NSString *entry in entries) {
                    if (![entry isKindOfClass:[NSString class]] ||
                        ![[entry pathExtension].lowercaseString isEqualToString:@"appex"]) {
                        continue;
                    }
                    NSString *extensionPath = [location stringByAppendingPathComponent:entry];
                    struct stat extensionStat;
                    memset(&extensionStat, 0, sizeof(extensionStat));
                    const char *extensionFS = extensionPath.fileSystemRepresentation;
                    if (!extensionFS || lstat(extensionFS, &extensionStat) != 0 ||
                        !S_ISDIR(extensionStat.st_mode) || S_ISLNK(extensionStat.st_mode)) {
                        continue;
                    }

                    NSString *infoPath = [extensionPath stringByAppendingPathComponent:@"Info.plist"];
                    struct stat infoStat;
                    memset(&infoStat, 0, sizeof(infoStat));
                    const char *infoFS = infoPath.fileSystemRepresentation;
                    if (!infoFS || lstat(infoFS, &infoStat) != 0 ||
                        !S_ISREG(infoStat.st_mode) || S_ISLNK(infoStat.st_mode)) {
                        continue;
                    }
                    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
                    NSString *extensionExecutable = [info[@"CFBundleExecutable"] isKindOfClass:[NSString class]]
                        ? info[@"CFBundleExecutable"]
                        : nil;
                    BOOL safeExecutableName = extensionExecutable.length > 0 &&
                        ![extensionExecutable isEqualToString:@"."] &&
                        ![extensionExecutable isEqualToString:@".."] &&
                        [extensionExecutable rangeOfString:@"/"].location == NSNotFound;
                    if (safeExecutableName && ![protectedProcesses containsObject:extensionExecutable]) {
                        [executableNames addObject:extensionExecutable];
                    }
                }
            }
        }
    } @catch (__unused NSException *exception) {
        // Best-effort process quiescence must not make Clear/Restore fail before their strict validators run.
    }

    if (executableNames.count == 0) {
        NSLog(@"[FreezeManager] Could not resolve any killable executable for app: %@", bundleID);
        return;
    }

    for (NSString *executableName in executableNames) {
        BOOL executed = PXKillallByName(executableName, SIGKILL);
        NSLog(@"[FreezeManager] Kill request app=%@ executable=%@ executed=%d",
              bundleID, executableName, executed ? 1 : 0);
    }

    // Give host and extension processes a short window to leave shared-container descriptors.
    usleep(100000);
}

@end