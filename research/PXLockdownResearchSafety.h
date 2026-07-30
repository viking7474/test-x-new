#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, PXLockdownResearchMode) {
    PXLockdownResearchModeObserveOnly = 0,
    PXLockdownResearchModeProfileBacked = 1,
};

typedef NS_ENUM(NSUInteger, PXLockdownSafetyReason) {
    PXLockdownSafetyReasonAllowed = 0,
    PXLockdownSafetyReasonBuildGate,
    PXLockdownSafetyReasonMasterDisabled,
    PXLockdownSafetyReasonSessionInactive,
    PXLockdownSafetyReasonSessionExpired,
    PXLockdownSafetyReasonProcessDenied,
    PXLockdownSafetyReasonNotAllowlisted,
    PXLockdownSafetyReasonObserveOnly,
    PXLockdownSafetyReasonValidationFailed,
    PXLockdownSafetyReasonTypeMismatch,
    PXLockdownSafetyReasonKillSwitch,
};

@interface PXLockdownResearchPolicy : NSObject
@property (nonatomic, readonly) BOOL masterEnabled;
@property (nonatomic, readonly) PXLockdownResearchMode mode;
@property (nonatomic, copy, readonly) NSSet<NSString *> *bundleAllowlist;
@property (nonatomic, copy, readonly) NSSet<NSString *> *processAllowlist;
@property (nonatomic, readonly) NSTimeInterval sessionDuration;
+ (instancetype)policyFromSettings:(NSDictionary *)settings;
@end

@interface PXLockdownSafetyDecision : NSObject
@property (nonatomic, readonly, getter=isAllowed) BOOL allowed;
@property (nonatomic, readonly) PXLockdownSafetyReason reason;
@property (nonatomic, readonly) PXLockdownResearchMode mode;
@property (nonatomic, copy, readonly) NSString *reasonCode;
@end

/// Process-local safety gate. A persisted master switch never arms a session:
/// activateAt: must be called after each process start, so reboot/relaunch fails closed.
@interface PXLockdownResearchRuntime : NSObject
@property (nonatomic, strong, readonly) PXLockdownResearchPolicy *policy;
@property (nonatomic, readonly, getter=isSessionActive) BOOL sessionActive;
@property (nonatomic, strong, readonly, nullable) NSDate *expiresAt;
- (instancetype)initWithPolicy:(PXLockdownResearchPolicy *)policy;
- (BOOL)activateAt:(NSDate *)now;
- (PXLockdownSafetyDecision *)decisionForBundleID:(nullable NSString *)bundleID
                                      processName:(nullable NSString *)processName
                                              now:(NSDate *)now;
/// Immediate process-local kill switch. Clears all armed/session state.
- (void)disableAllAndClearSnapshot;
@end

/// Observe-only, denied, expired and invalid/type-mismatched paths always return original.
FOUNDATION_EXPORT id _Nullable PXLockdownOriginalOrReplacement(id _Nullable original,
                                                               id _Nullable candidate,
                                                               Class _Nullable expectedClass,
                                                               PXLockdownSafetyDecision *decision,
                                                               BOOL validationPassed);

/// Emits metadata only. Raw values are never returned by this API.
FOUNDATION_EXPORT NSDictionary<NSString *, id> *PXLockdownRedactedAuditEvent(PXLockdownSafetyDecision *decision,
                                                                              NSString *key,
                                                                              id _Nullable sensitiveValue);

FOUNDATION_EXPORT NSString *PXLockdownSafetyReasonCode(PXLockdownSafetyReason reason);

NS_ASSUME_NONNULL_END
