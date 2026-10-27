#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UptimeManager : NSObject

// Singleton accessor
+ (instancetype)sharedManager;

// System Uptime Generation (legacy)
- (NSString *)generateUptime;
- (NSTimeInterval)currentUptime;
- (void)setCurrentUptime:(NSTimeInterval)uptime;

// Boot Time Generation (legacy)
- (NSString *)generateBootTime;
- (NSDate *)currentBootTime;
- (void)setCurrentBootTime:(NSDate *)bootTime;

// New profile-specific methods
// Generation owns an existing identity directory through preparation/commit.
// Busy, pending recovery or missing target leaves source/cache intact and sets
// lastError. Legacy getters retain their existing read/fallback return policy.
- (NSString *)generateUptimeForProfile:(NSString *)profilePath;
- (NSTimeInterval)currentUptimeForProfile:(NSString *)profilePath;
- (NSString *)generateBootTimeForProfile:(NSString *)profilePath;
- (NSDate *)currentBootTimeForProfile:(NSString *)profilePath;
- (void)generateConsistentUptimeAndBootTimeForProfile:(NSString *)profilePath;
- (void)adoptCommittedUptimeInfo:(NSDictionary *)uptimeInfo timestamp:(NSDate *)timestamp;

// Data validation
- (BOOL)validateBootTimeConsistencyForProfile:(NSString *)profilePath;

// Error handling
@property (nonatomic, readonly) NSError *lastError;

@end

NS_ASSUME_NONNULL_END
