#import <Foundation/Foundation.h>

@interface IPMonitorService : NSObject

+ (instancetype)sharedInstance;
- (void)startMonitoring;
- (void)stopMonitoring;
/// Persist the toggle before changing service state. Call from the UI/main thread.
- (BOOL)setMonitoringEnabledAndPersist:(BOOL)enabled error:(NSError **)error;
- (BOOL)isMonitoring;
- (NSString *)loadLastKnownIP;

@end
