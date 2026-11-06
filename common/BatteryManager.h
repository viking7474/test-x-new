#import "UIKit/UIKit.h"

@interface BatteryManager : NSObject

+ (instancetype)sharedManager;

// Own cache level/LPM/loaded fields are protected as one short observation.
// I/O, parsing/copying, generation, persistence and notifications stay outside it.
// Separate public getter calls are separate observations, not a profile transaction.
// Battery level string; reads accept 0.01-1.0 in float precision.
// Repair is bounded: superseded work returns the latest valid cache or nil.
- (NSString *)batteryLevel;
// Setter freezes NSString input; nil clears without saving. Unsupported roots are ignored.
- (void)setBatteryLevel:(NSString *)level;
- (NSString *)generateBatteryLevel;
- (NSString *)randomizeBatteryLevel;

// Low Power Mode (profile-scoped Boolean; default NO)
- (BOOL)lowPowerModeEnabled;
- (void)setLowPowerModeEnabled:(BOOL)enabled;

// Generate battery info for UI display (keeps current LPM; does not randomize it)
// Candidate/cache-first return remains compatible. Failed persistence sets
// lastError and suppresses success notifications; it does not undo the cache.
- (NSDictionary *)generateBatteryInfo;
// Cache only; caller publishes compatibility effects after the source commit.
- (void)adoptCommittedBatteryInfo:(NSDictionary *)batteryInfo;
- (void)publishCommittedBatteryInfo:(NSDictionary *)batteryInfo timestamp:(NSDate *)timestamp;

// File operations
// Existing profile: commit source first, then best-effort legacy mirror. With no
// canonical active ID, retain global-only persistence under lifecycle ownership.
// Busy/pending/invalid or unavailable namespace never changes the mirror. Reads
// retain profile/legacy/global fallback and never create profile directories.
// Reads accept string/numeric levels; unsupported fields use missing-field policy.
// Level requests retain one-save repair for invalid/non-finite values. A load
// started before a mutation/newer load cannot overwrite its cache result. Pending
// candidates also reject disk adoption until their writer releases ownership.
// Later reads still reload disk after completion, including after failed saves;
// write/cache/source are not a single global transaction.
- (void)saveBatteryInfoToDisk;
- (void)loadBatteryInfoFromDisk;

// Error handling (retained atomically; late older-mutation results are ignored)
- (NSError *)lastError;

@end
