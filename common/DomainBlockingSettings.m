#import "DomainBlockingSettings.h"

// Multiple possible paths for rootless jailbreak compatibility
static NSString *const kDomainBlockingSettingsFile = @"/var/mobile/Library/Preferences/com.hydra.tlinkios.domainblocking.plist";
static NSString *const kDomainBlockingSettingsFileAlt1 = @"/private/var/mobile/Library/Preferences/com.hydra.tlinkios.domainblocking.plist";
static NSString *const kDomainBlockingSettingsFileAlt2 = @"/var/mobile/Library/Preferences/com.hydra.tlinkios.domainblocking.plist";
static NSString *const kIsEnabledKey = @"isEnabled";
static NSString *const kBlockedDomainsKey = @"blockedDomains";
static NSString *const kCustomDomainsKey = @"customDomains";

@interface DomainBlockingSettings ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *customDomainsStatus;
@end

// Helper function to find the correct settings file path
static NSString *getSettingsFilePath(void) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Try each possible path in order of preference
    NSArray *possiblePaths = @[
        kDomainBlockingSettingsFile,        // Primary rootless path
        kDomainBlockingSettingsFileAlt1,    // Alternative rootless path  
        kDomainBlockingSettingsFileAlt2     // Legacy non-rootless path
    ];
    
    for (NSString *path in possiblePaths) {
        if ([fileManager fileExistsAtPath:path]) {
            return path;
        }
    }
    
    // If no file exists, return the primary path for creating new file
    return kDomainBlockingSettingsFile;
}

// Helper function to ensure directory exists before saving
static void ensureDirectoryExists(NSString *filePath) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *directory = [filePath stringByDeletingLastPathComponent];
    
    if (![fileManager fileExistsAtPath:directory]) {
        NSError *error = nil;
        [fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            // STEALTH: No logging - avoid detection
        }
    }
}

@implementation DomainBlockingSettings

+ (instancetype)sharedSettings {
    static DomainBlockingSettings *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"[DomainBlockingSettings] Creating shared instance");
        sharedInstance = [[self alloc] init];
        NSLog(@"[DomainBlockingSettings] Before loadSettings - domains: %@", sharedInstance.blockedDomains);
        [sharedInstance loadSettings];
        NSLog(@"[DomainBlockingSettings] After loadSettings - domains: %@", sharedInstance.blockedDomains);
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initialize empty blocked domains list (built from custom domains only)
        _blockedDomains = [NSMutableArray array];
        
        // Initialize custom domains status (this is where all domains go)
        _customDomainsStatus = [NSMutableDictionary dictionary];
        
        // Add critical Apple domains by default for essential protection
        _customDomainsStatus[@"devicecheck.apple.com"] = @YES;
        _customDomainsStatus[@"appattest.apple.com"] = @YES;
        
        // Build the initial blocked domains list
        [self rebuildBlockedDomainsList];
        
        _isEnabled = YES;
        
        // TEMPORARY DEBUG
        NSLog(@"[DomainBlockingSettings] Initialized with domains: %@", _blockedDomains);
    }
    return self;
}

- (BOOL)saveSettings {
    @synchronized (self) {
        @try {
            NSString *settingsPath = getSettingsFilePath();
            ensureDirectoryExists(settingsPath);

            NSDictionary *settings = @{
                kIsEnabledKey: @(self.isEnabled),
                kBlockedDomainsKey: [self.blockedDomains copy],
                kCustomDomainsKey: [self.customDomainsStatus copy]
            };

            BOOL success = [settings writeToFile:settingsPath atomically:YES];
            if (!success) {
                NSLog(@"[DomainBlockingSettings] ERROR: Failed to save settings to %@", settingsPath);
            }
            return success;
        } @catch (NSException *exception) {
            NSLog(@"[DomainBlockingSettings] Exception saving: %@", exception);
            return NO;
        }
    }
}

- (BOOL)loadSettings {
    @synchronized (self) {
        @try {
            NSString *settingsPath = getSettingsFilePath();
            NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:settingsPath];

            if (settings) {
                self.isEnabled = settings[kIsEnabledKey] != nil ? [settings[kIsEnabledKey] boolValue] : YES;

                NSDictionary *savedCustomStatus = settings[kCustomDomainsKey];
                if ([savedCustomStatus isKindOfClass:[NSDictionary class]]) {
                    [self.customDomainsStatus removeAllObjects];
                    [self.customDomainsStatus addEntriesFromDictionary:savedCustomStatus];
                }

                NSArray *savedDomains = settings[kBlockedDomainsKey];
                if ([savedDomains isKindOfClass:[NSArray class]] && !savedCustomStatus) {
                    for (NSString *domain in savedDomains) {
                        if ([domain isKindOfClass:[NSString class]] && domain.length > 0) {
                            self.customDomainsStatus[domain] = @YES;
                        }
                    }
                    [self rebuildBlockedDomainsList];
                    return [self saveSettings];
                }

                [self rebuildBlockedDomainsList];
                return YES;
            }

            // First run: keep the in-memory defaults and create the file.
            return [self saveSettings];
        } @catch (NSException *exception) {
            NSLog(@"[DomainBlockingSettings] Exception loading: %@", exception);
            [self rebuildBlockedDomainsList];
            return NO;
        }
    }
}

- (void)rebuildBlockedDomainsList {
    [self.blockedDomains removeAllObjects];
    
    NSLog(@"[DomainBlockingSettings] Rebuilding list from customDomainsStatus: %@", self.customDomainsStatus);
    
    // Add all enabled custom domains (this is now the only source)
    NSMutableArray *enabledDomains = [NSMutableArray array];
    for (NSString *domain in self.customDomainsStatus.allKeys) {
        BOOL isEnabled = [self.customDomainsStatus[domain] boolValue];
        if (isEnabled) {
            [self.blockedDomains addObject:domain];
            [enabledDomains addObject:domain];
        }
    }
    
    NSLog(@"[DomainBlockingSettings] Final blocked domains: %@", self.blockedDomains);
}

- (BOOL)addDomain:(NSString *)domain {
    if (![domain isKindOfClass:[NSString class]] || domain.length == 0) return NO;
    @synchronized (self) {
        NSNumber *oldValue = self.customDomainsStatus[domain];
        if (oldValue && [oldValue boolValue]) return YES;

        self.customDomainsStatus[domain] = @YES;
        [self rebuildBlockedDomainsList];
        if ([self saveSettings]) return YES;

        if (oldValue) self.customDomainsStatus[domain] = oldValue;
        else [self.customDomainsStatus removeObjectForKey:domain];
        [self rebuildBlockedDomainsList];
        return NO;
    }
}

- (BOOL)removeDomain:(NSString *)domain {
    if (![domain isKindOfClass:[NSString class]] || domain.length == 0) return NO;
    @synchronized (self) {
        NSNumber *oldValue = self.customDomainsStatus[domain];
        if (!oldValue || ![oldValue boolValue]) return YES;

        self.customDomainsStatus[domain] = @NO;
        [self rebuildBlockedDomainsList];
        if ([self saveSettings]) return YES;

        self.customDomainsStatus[domain] = oldValue;
        [self rebuildBlockedDomainsList];
        return NO;
    }
}

// Removed optional domain methods - everything is now custom domains

- (BOOL)isDomainBlocked:(NSString *)domain {
    if (!domain || domain.length == 0) return NO;

    @synchronized (self) {
        if (!self.isEnabled) return NO;

        NSString *lowerDomain = [domain lowercaseString];
        if ([lowerDomain hasSuffix:@"."]) {
            lowerDomain = [lowerDomain substringToIndex:lowerDomain.length - 1];
        }

        for (NSString *blockedDomain in self.blockedDomains) {
            NSString *lowerBlocked = [blockedDomain lowercaseString];
            if ([lowerBlocked hasSuffix:@"."]) {
                lowerBlocked = [lowerBlocked substringToIndex:lowerBlocked.length - 1];
            }

            if ([lowerDomain isEqualToString:lowerBlocked]) return YES;
            if ([lowerDomain hasSuffix:[@"." stringByAppendingString:lowerBlocked]]) return YES;
        }
        return NO;
    }
}

// Removed getEnabledByDefaultDomains - no longer needed

#pragma mark - Custom Domain Management

- (BOOL)setCustomDomainEnabled:(NSString *)domain enabled:(BOOL)enabled {
    if (![domain isKindOfClass:[NSString class]] || domain.length == 0) return NO;
    @synchronized (self) {
        NSNumber *oldValue = self.customDomainsStatus[domain];
        if (!oldValue) return NO;
        if ([oldValue boolValue] == enabled) return YES;

        self.customDomainsStatus[domain] = @(enabled);
        [self rebuildBlockedDomainsList];
        if ([self saveSettings]) return YES;

        self.customDomainsStatus[domain] = oldValue;
        [self rebuildBlockedDomainsList];
        return NO;
    }
}

- (BOOL)isCustomDomainEnabled:(NSString *)domain {
    @synchronized (self) {
        return [self.customDomainsStatus[domain] boolValue];
    }
}

- (BOOL)removeCustomDomain:(NSString *)domain {
    if (![domain isKindOfClass:[NSString class]] || domain.length == 0) return NO;
    @synchronized (self) {
        NSNumber *oldValue = self.customDomainsStatus[domain];
        if (!oldValue) return YES;

        [self.customDomainsStatus removeObjectForKey:domain];
        [self rebuildBlockedDomainsList];
        if ([self saveSettings]) return YES;

        self.customDomainsStatus[domain] = oldValue;
        [self rebuildBlockedDomainsList];
        return NO;
    }
}

- (BOOL)replaceCustomDomain:(NSString *)oldDomain withDomain:(NSString *)newDomain {
    if (oldDomain.length == 0 || newDomain.length == 0) return NO;
    @synchronized (self) {
        NSNumber *oldEnabled = self.customDomainsStatus[oldDomain];
        if (!oldEnabled || self.customDomainsStatus[newDomain] != nil) return NO;

        NSDictionary *snapshot = [self.customDomainsStatus copy];
        [self.customDomainsStatus removeObjectForKey:oldDomain];
        self.customDomainsStatus[newDomain] = oldEnabled;
        [self rebuildBlockedDomainsList];
        if ([self saveSettings]) return YES;

        [self.customDomainsStatus removeAllObjects];
        [self.customDomainsStatus addEntriesFromDictionary:snapshot];
        [self rebuildBlockedDomainsList];
        return NO;
    }
}

- (NSArray<NSDictionary *> *)getCustomDomains {
    @synchronized (self) {
        NSMutableArray *customDomains = [NSMutableArray array];
        for (NSString *domain in self.customDomainsStatus.allKeys) {
            BOOL enabled = [self.customDomainsStatus[domain] boolValue];
            [customDomains addObject:@{
                @"domain": domain,
                @"enabled": @(enabled),
                @"category": @"Custom",
                @"description": @"User added domain"
            }];
        }
        return [customDomains sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
            return [obj1[@"domain"] localizedCaseInsensitiveCompare:obj2[@"domain"]];
        }];
    }
}

- (BOOL)isCustomDomain:(NSString *)domain {
    @synchronized (self) {
        return self.customDomainsStatus[domain] != nil;
    }
}

- (NSArray<NSDictionary *> *)getAllDomains {
    // Only custom domains now - just return the custom domains list
    return [self getCustomDomains];
}

@end
