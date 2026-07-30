#import <Foundation/Foundation.h>
#import "PXLockdownResearchSafety.h"

NS_ASSUME_NONNULL_BEGIN

// L0 — Observe only (plan §4.6). A strictly read-only observability layer for
// the Lockdown research surface. It never mutates a Lockdown value; every active
// replacement stays owned by the L1/L2/L3 providers (Phases 5/6/7).
//
// Responsibilities, matching the L0 bullets:
//   * a consolidated inventory of every Lockdown key/domain the app looks up,
//     each annotated with its expected type and source provider;
//   * redacted observation records (process, key, expected type, provider) that
//     never carry a raw identifier value;
//   * refusal to emit pair-record / certificate / private-key / escrow data;
//   * access metrics for frequency, timeout and cache behavior.

typedef NS_ENUM(NSUInteger, PXLockdownObservedDomain) {
    PXLockdownObservedDomainSoftwareModel = 0,  // L1 — PXLockdownSoftwareModelProvider
    PXLockdownObservedDomainDeviceIdentity,     // L2 — PXLockdownDeviceIdentityProvider
    PXLockdownObservedDomainSoCCellular,        // L3 — PXLockdownSoCCellularProvider
};

@interface PXLockdownObservedKey : NSObject
/// Lockdown key the app looks up, e.g. kLockdownUniqueDeviceIDKey.
@property (nonatomic, copy, readonly) NSString *lockdownKey;
/// Logical observation domain / risk-stage owner.
@property (nonatomic, readonly) PXLockdownObservedDomain domain;
/// Source provider that owns the active replacement for this key.
@property (nonatomic, copy, readonly) NSString *sourceProvider;
/// Objective-C class the resolved value is expected to project as.
@property (nonatomic, readonly) Class expectedClass;
/// YES for personal hardware identifiers that must be redacted in any log.
@property (nonatomic, readonly, getter=isSensitive) BOOL sensitive;
@end

/// Consolidated, deterministic inventory of every observed Lockdown key across
/// the software/model, device-identity and SoC/cellular providers.
FOUNDATION_EXPORT NSArray<PXLockdownObservedKey *> *PXLockdownObservedKeyInventory(void);
FOUNDATION_EXPORT PXLockdownObservedKey * _Nullable
PXLockdownObservedKeyForLockdownKey(NSString *lockdownKey);

/// Structural self-check: the inventory represents every provider entry exactly
/// once, each maps to a real domain, a non-empty source provider and a concrete
/// expected class, and no key appears twice.
FOUNDATION_EXPORT BOOL
PXLockdownObservabilityInventoryIsWellFormed(NSArray<NSString *> * _Nullable * _Nullable outFailures);

/// Forbidden observation domains that must never be logged, even as metadata:
/// pairing records, certificates, private keys and escrow material.
FOUNDATION_EXPORT BOOL PXLockdownObservationDomainIsForbidden(NSString * _Nullable rawDomain);

/// Build a redacted observation record for one observe-only access. Returns nil
/// when the key is unknown or when rawDomain is a forbidden pairing/certificate/
/// private-key/escrow domain. The record carries process, key, expectedType,
/// sourceProvider, domain and mode; the payload is "<redacted>" for sensitive
/// keys and the raw sensitive value is never copied into the record.
FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable
PXLockdownObservationRecord(NSString * _Nullable processName,
                            NSString *lockdownKey,
                            id _Nullable sensitiveValue,
                            NSString * _Nullable rawDomain);

/// Lightweight, thread-safe access metrics for the observe-only stage: total
/// accesses (frequency), timeouts and cache hits/misses, keyed by Lockdown key.
@interface PXLockdownAccessMetrics : NSObject
- (void)recordAccessForKey:(NSString *)lockdownKey
                  timedOut:(BOOL)timedOut
                  cacheHit:(BOOL)cacheHit;
- (NSUInteger)accessCountForKey:(NSString *)lockdownKey;
- (NSUInteger)timeoutCountForKey:(NSString *)lockdownKey;
- (NSUInteger)cacheHitCountForKey:(NSString *)lockdownKey;
- (NSUInteger)cacheMissCountForKey:(NSString *)lockdownKey;
- (NSUInteger)totalAccessCount;
/// Metadata-only snapshot (key names and counters) suitable for redacted audit.
- (NSDictionary<NSString *, id> *)redactedSnapshot;
@end

NS_ASSUME_NONNULL_END
