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
- (nullable NSDate *)currentBootTimeForProfile:(NSString *)profilePath;
- (void)generateConsistentUptimeAndBootTimeForProfile:(NSString *)profilePath;
- (void)adoptCommittedUptimeInfo:(NSDictionary *)uptimeInfo timestamp:(NSDate *)timestamp;

// With NO, a miss returns 0/nil without generation, persistence or cache adoption.
// Used by writers already owning the profile lifecycle scope.
- (NSTimeInterval)currentUptimeForProfile:(NSString *)profilePath generateIfMissing:(BOOL)generateIfMissing;
- (nullable NSDate *)currentBootTimeForProfile:(NSString *)profilePath generateIfMissing:(BOOL)generateIfMissing;
// Provider preparation only: no persistence, lifecycle acquire or cache effects.
- (nullable NSDictionary *)prepareConsistentUptimeInfo;

// Cache boot/seconds/clock publish as one short observation after commit. Copy,
// parsing, file/provider/source work and formatting stay outside the monitor.
// Newer adoption/setter intent may supersede old generation/cache/error effects;
// busy admission does not revoke its current owner. Separate getters remain
// separate file observations. No profile-tagged/global source cache is implied.
// Non-finite or unsupported time fields follow existing missing/default policy.
// Private per-field KVO/overrides do not join this cache protocol.

// Data validation
- (BOOL)validateBootTimeConsistencyForProfile:(NSString *)profilePath;

// Error handling
// Error is a retained per-instance observation, not a result for an earlier call.
@property (nonatomic, readonly, nullable) NSError *lastError;

@end

NS_ASSUME_NONNULL_END
