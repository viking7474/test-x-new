#import "IPMonitorService.h"
#import "IPStatusViewController.h"
#import "TLinkIOSLogging.h"
#import "PXUIKitCompat.h"
#import "PXSecuritySettingsStore.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>
#import <UIKit/UIKit.h>

@interface PXIPMonitorReachabilityOwner : NSObject
@property (nonatomic, weak) IPMonitorService *service;
@end
@implementation PXIPMonitorReachabilityOwner
@end

@interface IPMonitorService ()

@property (nonatomic, assign) BOOL isMonitoring;
@property (nonatomic, strong) NSTimer *monitoringTimer;
@property (nonatomic, strong) NSString *lastKnownIP;
@property (nonatomic, strong) NSUserDefaults *securitySettings;
@property (nonatomic, assign) SCNetworkReachabilityRef reachability;
@property (nonatomic, assign) NSTimeInterval lastCheckTime;
@property (nonatomic, assign) NSTimeInterval adaptiveInterval;
@property (nonatomic, assign) NSInteger checkCount;
@property (nonatomic, assign) NSInteger toggleCount;
@property (nonatomic, assign) NSInteger consensusCount;
@property (nonatomic, strong) NSObject *monitoringToken;
@property (nonatomic, strong) NSMutableSet<NSURLSession *> *monitoringSessions;
@property (nonatomic, copy) NSString *lastCheckedIP;

@end

@implementation IPMonitorService

static IPMonitorService *sharedInstance = nil;

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[IPMonitorService alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        PXLog(@"[IPMonitor] Initializing IP Monitor Service");
        self.securitySettings = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
        self.isMonitoring = NO;
        self.monitoringTimer = nil;
        self.lastKnownIP = [self loadLastKnownIP];
        self.reachability = NULL;
        self.lastCheckTime = 0;
        self.adaptiveInterval = 60.0; // Start with 60 seconds
        self.checkCount = 0;
        self.toggleCount = 0;
        self.consensusCount = 0;
        self.monitoringSessions = [NSMutableSet set];
        
        // Load cached IP if available
        NSString *cachedIP = [self loadCachedIP];
        NSDate *cacheTime = [self loadCacheTime];
        
        // If cache is less than 5 minutes old, use it
        if (cachedIP && cacheTime && [[NSDate date] timeIntervalSinceDate:cacheTime] < 300) {
            self.lastKnownIP = cachedIP;
            PXLog(@"[IPMonitor] Using cached IP: %@", cachedIP);
        }
        
        __weak typeof(self) weakSelf = self;
        void (^begin)(void) = ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self setupNetworkMonitoring];
            if ([self isIPMonitoringEnabled]) [self startMonitoring];
        };
        if (NSThread.isMainThread) begin();
        else dispatch_async(dispatch_get_main_queue(), begin);
    }
    return self;
}

- (void)dealloc {
    PXLog(@"[IPMonitor] Deallocating IP Monitor Service");
    [_monitoringTimer invalidate];
    for (NSURLSession *session in _monitoringSessions) [session invalidateAndCancel];
    if (self.reachability) {
        SCNetworkReachabilitySetCallback(self.reachability, NULL, NULL);
        SCNetworkReachabilityUnscheduleFromRunLoop(self.reachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
        CFRelease(self.reachability);
        self.reachability = NULL;
    }
}

- (BOOL)isIPMonitoringEnabled {
    self.toggleCount++;
    BOOL enabled = [self.securitySettings boolForKey:@"ipMonitorEnabled"];
    if (self.toggleCount % 10 == 0) {
        PXLog(@"[IPMonitor] Monitoring enabled status checked %ld times, current: %@", (long)self.toggleCount, enabled ? @"YES" : @"NO");
    }
    return enabled;
}

- (NSString *)loadLastKnownIP {
    NSString *ip = [self.securitySettings stringForKey:@"lastKnownIP"];
    PXLog(@"[IPMonitor] Loading last known IP: %@", ip ?: @"None");
    return ip;
}

- (void)saveLastKnownIP:(NSString *)ip {
    if (ip) {
        PXLog(@"[IPMonitor] Saving last known IP: %@", ip);
        // Keep the observed IP and its cache timestamp in one source commit.
        NSError *error = nil;
        if (!PXWriteSecuritySettings(@{ @"lastKnownIP": ip, @"CachedIP": ip, @"IPCacheTime": [NSDate date] }, &error)) {
            PXLog(@"[IPMonitor] Failed to persist observed IP: %@", error);
        }
    }
}



- (void)saveIPToCache:(NSString *)ip {
    if (!ip) return;
    NSError *error = nil;
    if (!PXWriteSecuritySettings(@{ @"CachedIP": ip, @"IPCacheTime": [NSDate date] }, &error)) {
        PXLog(@"[IPMonitor] Failed to persist IP cache: %@", error);
    }
}

- (BOOL)setMonitoringEnabledAndPersist:(BOOL)enabled error:(NSError **)error {
    if (!NSThread.isMainThread) {
        if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios.ip-monitor" code:1
            userInfo:@{NSLocalizedDescriptionKey: @"IP monitoring toggle requires the main thread"}];
        return NO;
    }
    if (!PXWriteSecurityBool(@"ipMonitorEnabled", enabled, error)) return NO;
    if (enabled) [self startMonitoring];
    else [self stopMonitoring];
    return YES;
}

- (NSString *)loadCachedIP {
    return [self.securitySettings stringForKey:@"CachedIP"];
}

- (NSDate *)loadCacheTime {
    return [self.securitySettings objectForKey:@"IPCacheTime"];
}

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    (void)target;
    IPMonitorService *service = ((__bridge PXIPMonitorReachabilityOwner *)info).service;
    [service handleReachabilityChange:flags];
}

- (void)setupNetworkMonitoring {
    // Create a zero address to monitor all network interfaces
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    // Create reachability reference
    self.reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&zeroAddress);
    
    if (self.reachability) {
        // Set callback
        PXIPMonitorReachabilityOwner *owner = [PXIPMonitorReachabilityOwner new];
        owner.service = self;
        SCNetworkReachabilityContext context = {0, (__bridge void *)owner, CFRetain, CFRelease, NULL};
        if (SCNetworkReachabilitySetCallback(self.reachability, ReachabilityCallback, &context)) {
            // Schedule on main run loop
            SCNetworkReachabilityScheduleWithRunLoop(self.reachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
        }
    }
}

- (void)handleReachabilityChange:(SCNetworkReachabilityFlags)flags {
    BOOL isReachable = (flags & kSCNetworkReachabilityFlagsReachable) != 0;
    BOOL isWWAN = (flags & kSCNetworkReachabilityFlagsIsWWAN) != 0;
    
    PXLog(@"[IPMonitor] Network reachability changed - Reachable: %@, WWAN: %@, Monitoring: %@", 
          isReachable ? @"YES" : @"NO",
          isWWAN ? @"YES" : @"NO",
          self.isMonitoring ? @"YES" : @"NO");
    
    if (isReachable && self.isMonitoring) {
        // Only check IP when network becomes reachable and monitoring is active
        PXLog(@"[IPMonitor] Network became reachable, checking for IP change");
        [self checkForIPChange];
    }
}

- (void)startMonitoring {
    if (!NSThread.isMainThread) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf startMonitoring]; });
        return;
    }
    if (![self isIPMonitoringEnabled]) return;
    if (self.isMonitoring) {
        PXLog(@"[IPMonitor] Start monitoring called but already monitoring");
        return;
    }
    
    PXLog(@"[IPMonitor] Starting IP monitoring");
    self.isMonitoring = YES;
    self.monitoringToken = [NSObject new];
    
    // Get initial IP
    __weak typeof(self) weakSelf = self;
    [self fetchCurrentIPWithConsensus:^(NSString *ip, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (ip) {
            PXLog(@"[IPMonitor] Initial IP fetch successful: %@", ip);
            self.lastKnownIP = ip;
            [self saveLastKnownIP:ip];
        } else if (error) {
            PXLogError(error, @"IPMonitor initial IP fetch");
        }
    }];
    
    // Start adaptive polling
    [self startAdaptivePolling];
}

- (void)stopMonitoring {
    if (!NSThread.isMainThread) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf stopMonitoring]; });
        return;
    }
    // The effective getter becomes NO as soon as the stored toggle is disabled.
    // Cleanup must inspect the running state/resources independently of that toggle.
    if (!_isMonitoring && !self.monitoringTimer && !self.monitoringSessions.count && !self.monitoringToken) {
        PXLog(@"[IPMonitor] Stop monitoring called but not currently monitoring");
        return;
    }
    
    PXLog(@"[IPMonitor] Stopping IP monitoring");
    self.isMonitoring = NO;
    self.monitoringToken = nil; // Revoke before cancellation callbacks can run.
    NSSet<NSURLSession *> *sessions = [self.monitoringSessions copy];
    [self.monitoringSessions removeAllObjects];
    for (NSURLSession *session in sessions) [session invalidateAndCancel];
    
    // Invalidate timer
    if (self.monitoringTimer) {
        [self.monitoringTimer invalidate];
        self.monitoringTimer = nil;
        PXLog(@"[IPMonitor] Monitoring timer invalidated");
    }
}

- (BOOL)isMonitoring {
    if (!NSThread.isMainThread) return NO;
    BOOL active = _isMonitoring;
    BOOL enabled = [self isIPMonitoringEnabled];
    return active && enabled;
}

- (void)startAdaptivePolling {
    if (!NSThread.isMainThread || !self.isMonitoring || !self.monitoringToken) return;
    // Cancel existing timer if any
    if (self.monitoringTimer) {
        [self.monitoringTimer invalidate];
        self.monitoringTimer = nil;
    }
    
    PXLog(@"[IPMonitor] Starting adaptive polling with interval: %.1f seconds", self.adaptiveInterval);
    
    // Create a new timer with the current adaptive interval
    __weak typeof(self) weakSelf = self;
    self.monitoringTimer = [NSTimer timerWithTimeInterval:self.adaptiveInterval repeats:YES block:^(NSTimer *timer) {
        [weakSelf adaptiveCheckForIPChange:timer];
    }];
    
    // Add to common run loop modes to ensure it runs even during scrolling
    [[NSRunLoop mainRunLoop] addTimer:self.monitoringTimer forMode:NSRunLoopCommonModes];
    PXLog(@"[IPMonitor] Timer added to main run loop with common modes");
}

- (void)adaptiveCheckForIPChange:(NSTimer *)timer {
    if (!NSThread.isMainThread || !self.isMonitoring || timer != self.monitoringTimer) return;
    
    // Implement time-based throttling to prevent excessive checks
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - self.lastCheckTime < 5.0) { // Minimum 5 seconds between checks
        return;
    }
    
    self.lastCheckTime = now;
    self.checkCount++;
    
    if (self.checkCount % 5 == 0) {
        PXLog(@"[IPMonitor] Adaptive check #%ld for IP change, current interval: %.1f seconds", 
              (long)self.checkCount, self.adaptiveInterval);
    }
    
    NSObject *token = self.monitoringToken;
    __weak typeof(self) weakSelf = self;
    [self fetchCurrentIPWithConsensus:^(NSString *ip, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (ip) {
            if (self.lastCheckedIP && ![self.lastCheckedIP isEqualToString:ip]) {
                // IP changed, decrease interval (but not below 30 seconds)
                self.adaptiveInterval = MAX(30.0, self.adaptiveInterval * 0.5);
                
                PXLog(@"[IPMonitor] IP CHANGED from %@ to %@, decreasing check interval to %.1f seconds", 
                      self.lastCheckedIP, ip, self.adaptiveInterval);
                
                // Show alert for IP change
                [self showIPChangeAlertWithOldIP:self.lastCheckedIP newIP:ip];
                
                // Save the new IP
                self.lastKnownIP = ip;
                [self saveLastKnownIP:ip];
            } else if (self.lastCheckedIP && [self.lastCheckedIP isEqualToString:ip]) {
                // IP unchanged, increase interval (but not above 300 seconds)
                self.adaptiveInterval = MIN(300.0, self.adaptiveInterval * 1.5);
                
                if (self.checkCount % 5 == 0) {
                    PXLog(@"[IPMonitor] IP unchanged (%@), increasing check interval to %.1f seconds", 
                          ip, self.adaptiveInterval);
                }
            }
            
            if (token != self.monitoringToken || !self.isMonitoring) return;
            // Update timer interval
            [self startAdaptivePolling];
            
            // Store the current IP for next comparison
            self.lastCheckedIP = ip;
        }
    }];
}

- (void)checkForIPChange {
    if (!NSThread.isMainThread || !self.isMonitoring || !self.monitoringToken) return;
    // Implement time-based throttling to prevent excessive checks
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - self.lastCheckTime < 5.0) { // Minimum 5 seconds between checks
        return;
    }
    
    self.lastCheckTime = now;
    self.checkCount++;
    
    PXLog(@"[IPMonitor] Manual check for IP change triggered by network change");
    
    __weak typeof(self) weakSelf = self;
    [self fetchCurrentIPWithConsensus:^(NSString *ip, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (ip) {
            PXLog(@"[IPMonitor] IP fetch result: %@, previous IP: %@", ip, self.lastKnownIP);
            if (self.lastKnownIP && ![self.lastKnownIP isEqualToString:ip]) {
                PXLog(@"[IPMonitor] IP change detected during manual check: %@ -> %@", self.lastKnownIP, ip);
                [self showIPChangeAlertWithOldIP:self.lastKnownIP newIP:ip];
                self.lastKnownIP = ip;
                [self saveLastKnownIP:ip];
            }
        } else if (error) {
            PXLogError(error, @"IPMonitor manual IP check");
        }
    }];
}

- (void)fetchCurrentIPWithConsensus:(void (^)(NSString *ip, NSError *error))completion {
    if (!NSThread.isMainThread || !self.isMonitoring || !self.monitoringToken) return;
    NSObject *token = self.monitoringToken;
    PXLog(@"[IPMonitor] Starting IP fetch with consensus from multiple services");
    
    // Define the services to check - prioritize the fastest ones
    NSArray *services = @[
        @{@"url": @"https://ifconfig.me/ip", @"isJSON": @NO},
        @{@"url": @"https://api.myip.com", @"isJSON": @YES, @"key": @"ip"},
        @{@"url": @"https://api.ipify.org", @"isJSON": @NO}
    ];
    
    // Create a dictionary to count occurrences of each IP
    NSMutableDictionary *ipCounts = [NSMutableDictionary dictionary];
    NSMutableArray *errors = [NSMutableArray array];
    
    PXLog(@"[IPMonitor] Querying %lu IP services", (unsigned long)services.count);
    
    // Create a dispatch group to track all requests
    dispatch_group_t group = dispatch_group_create();
    
    // Create a serial queue for thread safety
    dispatch_queue_t queue = dispatch_queue_create("com.yourapp.ipconsensus", DISPATCH_QUEUE_SERIAL);
    
    // Use a shared session configuration with optimized settings
    static NSURLSessionConfiguration *sharedConfig = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        sharedConfig.timeoutIntervalForRequest = 8.0;  // 8 seconds timeout
        sharedConfig.timeoutIntervalForResource = 20.0; // 20 seconds resource timeout
        sharedConfig.HTTPMaximumConnectionsPerHost = 3; // Limit concurrent connections
    });
    
    // Create a shared session
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sharedConfig];
    [self.monitoringSessions addObject:session];
    
    // Check each service
    for (NSDictionary *service in services) {
        dispatch_group_enter(group);
        
        [self fetchIPFromService:service[@"url"] 
                         isJSON:[service[@"isJSON"] boolValue] 
                           key:service[@"key"]
                     withSession:session
                     completion:^(NSString *ip, NSError *error) {
            dispatch_async(queue, ^{
                if (ip) {
                    // Increment count for this IP
                    NSNumber *count = ipCounts[ip];
                    if (count) {
                        ipCounts[ip] = @([count integerValue] + 1);
                    } else {
                        ipCounts[ip] = @1;
                    }
                } else if (error) {
                    [errors addObject:error];
                }
                
                dispatch_group_leave(group);
            });
        }];
    }
    
    // When all requests complete, find the most common IP
    __weak typeof(self) weakSelf = self;
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if ([self.monitoringSessions containsObject:session]) {
            [self.monitoringSessions removeObject:session];
            [session finishTasksAndInvalidate];
        }
        if (!self || token != self.monitoringToken || !self.isMonitoring) return;
        // Find the IP with the highest count
        NSString *mostCommonIP = nil;
        NSInteger highestCount = 0;
        
        PXLog(@"[IPMonitor] All IP services responded, analyzing results");
        
        for (NSString *ip in ipCounts) {
            NSInteger count = [ipCounts[ip] integerValue];
            if (count > highestCount) {
                highestCount = count;
                mostCommonIP = ip;
            }
        }
        
        // If we have a consensus (at least 2 services returned the same IP)
        if (highestCount >= 2) {
            self.consensusCount++;
            PXLog(@"[IPMonitor] IP consensus reached (%ld services agree): %@", (long)highestCount, mostCommonIP);
            completion(mostCommonIP, nil);
        } else {
            // No consensus, use the first successful result if available
            if (mostCommonIP) {
                PXLog(@"[IPMonitor] No consensus reached, using first result: %@", mostCommonIP);
                completion(mostCommonIP, nil);
            } else {
                // All services failed
                PXLog(@"[IPMonitor] ERROR: All IP services failed, %lu errors", (unsigned long)errors.count);
                NSError *consensusError = [NSError errorWithDomain:@"com.yourapp.ipconsensus" 
                                                             code:1001 
                                                         userInfo:@{NSLocalizedDescriptionKey: @"All IP services failed", 
                                                                    @"underlyingErrors": errors}];
                completion(nil, consensusError);
            }
        }
    });
}

- (void)fetchIPFromService:(NSString *)urlString 
                    isJSON:(BOOL)isJSON 
                      key:(NSString *)jsonKey 
                withSession:(NSURLSession *)session
                completion:(void (^)(NSString *ip, NSError *error))completion {
    NSURL *url = [NSURL URLWithString:urlString];
    PXLog(@"[IPMonitor] Fetching IP from service: %@", urlString);
    
    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            PXLog(@"[IPMonitor] Error fetching from %@: %@", urlString, error.localizedDescription);
            completion(nil, error);
            return;
        }
        
        if (isJSON) {
            NSError *jsonError = nil;
            id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError] : nil;
            if (jsonError) {
                completion(nil, jsonError);
                return;
            }
            
            id ip = [json isKindOfClass:NSDictionary.class] && jsonKey ? json[jsonKey] : nil;
            if (![ip isKindOfClass:NSString.class] || [ip length] == 0) {
                PXLog(@"[IPMonitor] IP not found in JSON response from %@", urlString);
                NSError *missingError = [NSError errorWithDomain:@"com.yourapp.ipconsensus" 
                                                           code:1002 
                                                       userInfo:@{NSLocalizedDescriptionKey: @"IP not found in JSON response"}];
                completion(nil, missingError);
                return;
            }
            
            PXLog(@"[IPMonitor] Successfully fetched IP from %@: %@", urlString, ip);
            completion(ip, nil);
        } else {
            NSString *ip = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
            ip = [ip stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            if (!ip || ip.length == 0) {
                PXLog(@"[IPMonitor] Empty IP response from %@", urlString);
                NSError *emptyError = [NSError errorWithDomain:@"com.yourapp.ipconsensus" 
                                                          code:1003 
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Empty IP response"}];
                completion(nil, emptyError);
                return;
            }
            
            PXLog(@"[IPMonitor] Successfully fetched IP from %@: %@", urlString, ip);
            completion(ip, nil);
        }
    }];
    
    [task resume];
}

- (void)showIPChangeAlertWithOldIP:(NSString *)oldIP newIP:(NSString *)newIP {
    PXLog(@"[IPMonitor] Attempting to show IP change alert: %@ -> %@", oldIP, newIP);
    NSObject *token = self.monitoringToken;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !token || token != self.monitoringToken || !self.isMonitoring) return;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IP Address Changed"
                                                                     message:[NSString stringWithFormat:@"Your IP address has changed from %@ to %@", oldIP, newIP]
                                                              preferredStyle:UIAlertControllerStyleAlert];
        
        // Add "Check New IP" button
        [alert addAction:[UIAlertAction actionWithTitle:@"Check New IP" 
                                                 style:UIAlertActionStyleDefault 
                                               handler:^(UIAlertAction * _Nonnull action) {
            // Create and present the IPStatusViewController
            IPStatusViewController *ipStatusVC = [[IPStatusViewController alloc] init];
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:ipStatusVC];
            
            // Find the top view controller to present the alert
            UIViewController *topVC = [self topViewController];
            if (topVC) {
                [topVC presentViewController:navController animated:YES completion:nil];
            }
        }]];
        
        // Add "Turn OFF IP Monitoring" button
        [alert addAction:[UIAlertAction actionWithTitle:@"Turn OFF IP Monitoring" 
                                                 style:UIAlertActionStyleDestructive 
                                               handler:^(UIAlertAction * _Nonnull action) {
            NSError *error = nil;
            if (![self setMonitoringEnabledAndPersist:NO error:&error]) {
                PXLog(@"[IPMonitor] Failed to disable IP monitoring: %@", error);
                return;
            }
            
            // Show confirmation alert
            UIAlertController *confirmationAlert = [UIAlertController alertControllerWithTitle:@"IP Monitoring Disabled"
                                                                                     message:@"IP monitoring has been turned off. You will no longer receive alerts about IP changes."
                                                                              preferredStyle:UIAlertControllerStyleAlert];
            
            [confirmationAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            
            // Find the top view controller to present the confirmation alert
            UIViewController *topVC = [self topViewController];
            if (topVC) {
                [topVC presentViewController:confirmationAlert animated:YES completion:nil];
            }
        }]];
        
        // Add "OK" button
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        
        // Find the top view controller to present the alert
        UIViewController *topVC = [self topViewController];
        if (topVC) {
            PXLog(@"[IPMonitor] Presenting IP change alert on view controller: %@", NSStringFromClass([topVC class]));
            [topVC presentViewController:alert animated:YES completion:^{
                PXLog(@"[IPMonitor] IP change alert presented successfully");
            }];
        } else {
            PXLog(@"[IPMonitor] ERROR: Could not find top view controller to present IP change alert");
        }
    });
}

- (UIViewController *)topViewController {
    PXLog(@"[IPMonitor] Finding top view controller for alert presentation");
    UIWindow *window = PXKeyWindow();
    if (!window) {
        PXLog(@"[IPMonitor] ERROR: No window found for alert presentation");
        return nil;
    }

    PXLog(@"[IPMonitor] Found window for alert presentation: %@", window);
    return [self topViewControllerWithRootViewController:window.rootViewController];
}

- (UIViewController *)topViewControllerWithRootViewController:(UIViewController *)rootViewController {
    if (!rootViewController) {
        PXLog(@"[IPMonitor] ERROR: Root view controller is nil");
        return nil;
    }
    
    PXLog(@"[IPMonitor] Finding top view controller from root: %@", NSStringFromClass([rootViewController class]));
    
    if ([rootViewController isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabBarController = (UITabBarController *)rootViewController;
        return [self topViewControllerWithRootViewController:tabBarController.selectedViewController];
    }
    
    if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *)rootViewController;
        return [self topViewControllerWithRootViewController:navigationController.visibleViewController];
    }
    
    if (rootViewController.presentedViewController) {
        UIViewController *presentedViewController = rootViewController.presentedViewController;
        return [self topViewControllerWithRootViewController:presentedViewController];
    }
    
    return rootViewController;
}

@end
