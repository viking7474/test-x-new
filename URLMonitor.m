#import "URLMonitor.h"
#import "UberOrderViewController.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>

// Use the same key as in UberURLHooks.x
static BOOL isMonitoringEnabled = NO; // Default to disabled
static NSString * const kMonitoringEnabledKey = @"UberMonitoringEnabled";
static NSTimer *autoDisableTimer = nil;
static NSTimer *periodicNetworkCheckTimer = nil;
static NSDate *monitoringStartTime = nil;
static NSTimeInterval monitoringDuration = 180; // 3 minutes in seconds
static BOOL networkStateInitialized = NO;
static BOOL lastNetworkConnected = YES;
static BOOL offlineEpisodeHandled = NO;

static BOOL URLMonitoringDeadlineExpired(void) {
    if (!isMonitoringEnabled || !monitoringStartTime) return NO;
    NSTimeInterval elapsed = -[monitoringStartTime timeIntervalSinceNow];
    return elapsed >= monitoringDuration;
}

@interface URLMonitor()
@property (nonatomic, assign) SCNetworkReachabilityRef reachabilityRef;
@end

@implementation URLMonitor

+ (instancetype)sharedInstance {
    static URLMonitor *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[URLMonitor alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Create reachability reference for monitoring
        struct sockaddr_in zeroAddress;
        bzero(&zeroAddress, sizeof(zeroAddress));
        zeroAddress.sin_len = sizeof(zeroAddress);
        zeroAddress.sin_family = AF_INET;
        
        _reachabilityRef = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&zeroAddress);
    }
    return self;
}

- (void)dealloc {
    // Clean up reachability
    if (_reachabilityRef) {
        SCNetworkReachabilityUnscheduleFromRunLoop(_reachabilityRef, CFRunLoopGetMain(), kCFRunLoopCommonModes);
        CFRelease(_reachabilityRef);
    }
}

+ (void)setupNetworkMonitoring {
    // Get shared instance to initialize reachability
    URLMonitor *monitor = [URLMonitor sharedInstance];
    
    // Set up callback context
    SCNetworkReachabilityContext context = {0, (__bridge void *)monitor, NULL, NULL, NULL};
    
    // Set callback function
    if (monitor.reachabilityRef) {
        SCNetworkReachabilitySetCallback(monitor.reachabilityRef, NetworkReachabilityCallback, &context);
        SCNetworkReachabilityScheduleWithRunLoop(monitor.reachabilityRef, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    }
    
    // A monitoring session is process-local and always has a live deadline. Do not
    // resurrect a stale persisted YES after the app has restarted without that session.
    if (!isMonitoringEnabled) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kMonitoringEnabledKey];
    }

    // Check initial state immediately
    [self checkNetworkStatus];
    
    // Set up periodic check every 10 seconds
    if (periodicNetworkCheckTimer) {
        [periodicNetworkCheckTimer invalidate];
    }
    
    periodicNetworkCheckTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                                 target:self
                                                               selector:@selector(checkNetworkStatus)
                                                               userInfo:nil
                                                                repeats:YES];
}

// Check current network status manually
+ (void)checkNetworkStatus {
    BOOL isConnected = [self isNetworkConnected];
    if (URLMonitoringDeadlineExpired()) {
        [self deactivateMonitoring];
    }

    BOOL hadKnownState = networkStateInitialized;
    BOOL networkChanged = hadKnownState && (isConnected != lastNetworkConnected);

    networkStateInitialized = YES;
    lastNetworkConnected = isConnected;

    if (isConnected) {
        // A reconnect ends the current offline episode. The next real transition
        // back to offline may start a fresh fixed-duration monitoring session.
        offlineEpisodeHandled = NO;
    } else if (!offlineEpisodeHandled) {
        // Handle each continuous offline episode once. Repeated 10-second polls must
        // never restart the 180-second deadline.
        offlineEpisodeHandled = YES;
        if (!isMonitoringEnabled) {
            [self activateMonitoringWithTimeout:180];
            return; // Activation already publishes the monitoring state change.
        }
    }

    // Network status observers only need a refresh for a real transition. This keeps
    // the UI synchronized without broadcasting the same Darwin notification every 10s.
    if (networkChanged) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                           (CFStringRef)@"com.weaponx.uberMonitoringChanged",
                                           NULL, NULL, YES);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UberMonitoringStatusChanged"
                                                            object:@(isMonitoringEnabled)];
    }
}

// Callback for network reachability changes
static void NetworkReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    [URLMonitor checkNetworkStatus];
}

+ (BOOL)isNetworkConnectedWithFlags:(SCNetworkReachabilityFlags)flags {
    // Check if the network is reachable
    BOOL isReachable = ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
    BOOL needsConnection = ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0);
    
    return (isReachable && !needsConnection);
}

+ (BOOL)isNetworkConnected {
    // Check current network status
    URLMonitor *monitor = [URLMonitor sharedInstance];
    if (!monitor.reachabilityRef) {
        return YES; // Fail open if reachability could not be created.
    }

    SCNetworkReachabilityFlags flags;
    BOOL success = SCNetworkReachabilityGetFlags(monitor.reachabilityRef, &flags);
    
    if (!success) {
        return YES; // Default to YES if we can't determine
    }
    
    return [self isNetworkConnectedWithFlags:flags];
}

+ (void)activateMonitoringWithTimeout:(NSTimeInterval)timeout {
    if (timeout <= 0) {
        [self deactivateMonitoring];
        return;
    }

    // Activation is idempotent while a session is already running. In particular,
    // repeated offline polls must never move the current deadline forward.
    if (isMonitoringEnabled) {
        return;
    }

    if (autoDisableTimer) {
        [autoDisableTimer invalidate];
        autoDisableTimer = nil;
    }

    monitoringDuration = timeout;
    monitoringStartTime = [NSDate date];
    isMonitoringEnabled = YES;
    if (networkStateInitialized && !lastNetworkConnected) {
        offlineEpisodeHandled = YES;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:YES forKey:kMonitoringEnabledKey];

    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                        (CFStringRef)@"com.weaponx.uberMonitoringChanged",
                                        NULL, NULL, YES);

    autoDisableTimer = [NSTimer scheduledTimerWithTimeInterval:timeout
                                                       target:self
                                                     selector:@selector(deactivateMonitoring)
                                                     userInfo:nil
                                                      repeats:NO];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"UberMonitoringStatusChanged" object:@(YES)];
}

+ (void)deactivateMonitoring {
    BOOL wasEnabled = isMonitoringEnabled;

    if (autoDisableTimer) {
        [autoDisableTimer invalidate];
        autoDisableTimer = nil;
    }

    isMonitoringEnabled = NO;
    monitoringStartTime = nil;
    if (networkStateInitialized && !lastNetworkConnected) {
        // Do not restart monitoring again during the same continuous offline episode.
        offlineEpisodeHandled = YES;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL wasPersistedEnabled = [defaults boolForKey:kMonitoringEnabledKey];
    [defaults setBool:NO forKey:kMonitoringEnabledKey];

    // Publish only an actual monitoring-state transition. Repeated deactivation calls
    // (including a stale timer firing after a manual stop) are intentionally silent.
    if (wasEnabled || wasPersistedEnabled) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                            (CFStringRef)@"com.weaponx.uberMonitoringChanged",
                                            NULL, NULL, YES);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UberMonitoringStatusChanged" object:@(NO)];
    }
}

+ (NSTimeInterval)getRemainingMonitoringTime {
    // If monitoring is not active, return 0
    if (!isMonitoringEnabled || !monitoringStartTime) {
        return 0;
    }
    
    // Calculate elapsed time since monitoring started
    NSTimeInterval elapsedTime = -[monitoringStartTime timeIntervalSinceNow];
    
    // Calculate remaining time
    NSTimeInterval remainingTime = monitoringDuration - elapsedTime;
    
    // Make sure it's not negative
    if (remainingTime < 0) {
        remainingTime = 0;
    }
    
    return remainingTime;
}

+ (BOOL)isMonitoringActive {
    if (URLMonitoringDeadlineExpired()) {
        [self deactivateMonitoring];
        return NO;
    }

    // Monitoring state is session-based. Network offline by itself must not force this
    // back to YES after the fixed deadline has expired.
    return isMonitoringEnabled;
}

@end 