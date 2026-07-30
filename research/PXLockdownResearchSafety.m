#ifndef INTERNAL_SECURITY_RESEARCH
#define INTERNAL_SECURITY_RESEARCH 0
#endif
#if !INTERNAL_SECURITY_RESEARCH
#error "PXLockdownResearchSafety must never be compiled outside an Internal Research build"
#endif

#import "PXLockdownResearchSafety.h"
#import <dispatch/dispatch.h>
#import <math.h>

static const NSTimeInterval PXLockdownDefaultTTL = 15.0 * 60.0;
static const NSTimeInterval PXLockdownMinimumTTL = 60.0;
static const NSTimeInterval PXLockdownMaximumTTL = 15.0 * 60.0;

static BOOL PXStrictBool(id value) {
    return [value isKindOfClass:[NSNumber class]] && [value doubleValue] == 1.0;
}

static NSSet<NSString *> *PXExactAllowlist(id value) {
    if (![value isKindOfClass:[NSArray class]]) return [NSSet set];
    NSMutableSet<NSString *> *result = [NSMutableSet set];
    for (id item in (NSArray *)value) {
        if (![item isKindOfClass:[NSString class]]) continue;
        NSString *entry = (NSString *)item;
        if (!entry.length || [entry containsString:@"*"] || [entry containsString:@"?"] ||
            ![entry isEqualToString:[entry stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]) {
            continue;
        }
        [result addObject:entry];
    }
    return [result copy];
}

@interface PXLockdownResearchPolicy ()
- (instancetype)initWithMasterEnabled:(BOOL)masterEnabled
                                  mode:(PXLockdownResearchMode)mode
                       bundleAllowlist:(NSSet<NSString *> *)bundleAllowlist
                      processAllowlist:(NSSet<NSString *> *)processAllowlist
                       sessionDuration:(NSTimeInterval)sessionDuration;
@end

@implementation PXLockdownResearchPolicy
- (instancetype)initWithMasterEnabled:(BOOL)masterEnabled
                                  mode:(PXLockdownResearchMode)mode
                       bundleAllowlist:(NSSet<NSString *> *)bundleAllowlist
                      processAllowlist:(NSSet<NSString *> *)processAllowlist
                       sessionDuration:(NSTimeInterval)sessionDuration {
    self = [super init];
    if (self) {
        _masterEnabled = masterEnabled;
        _mode = mode;
        _bundleAllowlist = [bundleAllowlist copy] ?: [NSSet set];
        _processAllowlist = [processAllowlist copy] ?: [NSSet set];
        _sessionDuration = sessionDuration;
    }
    return self;
}

+ (instancetype)policyFromSettings:(NSDictionary *)settings {
    NSDictionary *safe = [settings isKindOfClass:[NSDictionary class]] ? settings : @{};
    BOOL master = PXStrictBool(safe[@"lockdownResearchEnabled"]); // absent/malformed => OFF
    PXLockdownResearchMode mode = [safe[@"lockdownResearchMode"] isEqual:@"profile-backed"]
        ? PXLockdownResearchModeProfileBacked : PXLockdownResearchModeObserveOnly;
    NSSet *bundles = PXExactAllowlist(safe[@"lockdownResearchBundleAllowlist"]);
    NSSet *processes = PXExactAllowlist(safe[@"lockdownResearchProcessAllowlist"]);
    NSTimeInterval ttl = PXLockdownDefaultTTL;
    id rawTTL = safe[@"lockdownResearchSessionSeconds"];
    if ([rawTTL isKindOfClass:[NSNumber class]]) {
        ttl = [rawTTL doubleValue];
        if (!isfinite(ttl)) ttl = PXLockdownDefaultTTL;
    }
    ttl = MAX(PXLockdownMinimumTTL, MIN(PXLockdownMaximumTTL, ttl));
    return [[self alloc] initWithMasterEnabled:master
                                          mode:mode
                               bundleAllowlist:bundles
                              processAllowlist:processes
                               sessionDuration:ttl];
}
@end

NSString *PXLockdownSafetyReasonCode(PXLockdownSafetyReason reason) {
    switch (reason) {
        case PXLockdownSafetyReasonAllowed: return @"allowed";
        case PXLockdownSafetyReasonBuildGate: return @"build-gate";
        case PXLockdownSafetyReasonMasterDisabled: return @"master-disabled";
        case PXLockdownSafetyReasonSessionInactive: return @"session-inactive";
        case PXLockdownSafetyReasonSessionExpired: return @"session-expired";
        case PXLockdownSafetyReasonProcessDenied: return @"process-denied";
        case PXLockdownSafetyReasonNotAllowlisted: return @"not-allowlisted";
        case PXLockdownSafetyReasonObserveOnly: return @"observe-only";
        case PXLockdownSafetyReasonValidationFailed: return @"validation-failed";
        case PXLockdownSafetyReasonTypeMismatch: return @"type-mismatch";
        case PXLockdownSafetyReasonKillSwitch: return @"kill-switch";
    }
    return @"unknown";
}

@interface PXLockdownSafetyDecision ()
- (instancetype)initWithAllowed:(BOOL)allowed reason:(PXLockdownSafetyReason)reason mode:(PXLockdownResearchMode)mode;
@end

@implementation PXLockdownSafetyDecision
- (instancetype)initWithAllowed:(BOOL)allowed reason:(PXLockdownSafetyReason)reason mode:(PXLockdownResearchMode)mode {
    self = [super init];
    if (self) {
        _allowed = allowed;
        _reason = reason;
        _mode = mode;
        _reasonCode = [PXLockdownSafetyReasonCode(reason) copy];
    }
    return self;
}
@end

static BOOL PXLockdownIsDeniedProcess(NSString *bundleID, NSString *processName) {
    static NSSet<NSString *> *deniedNames;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        deniedNames = [NSSet setWithArray:@[@"lockdownd", @"mobileactivationd", @"securityd", @"trustd",
                                             @"amfid", @"installd", @"containermanagerd", @"SpringBoard"]];
    });
    if ([deniedNames containsObject:processName ?: @""]) return YES;
    NSArray<NSString *> *deniedBundlePrefixes = @[@"com.apple.mobileactivation", @"com.apple.security", @"com.apple.trustd"];
    for (NSString *prefix in deniedBundlePrefixes) {
        if ([bundleID hasPrefix:prefix]) return YES;
    }
    return NO;
}

@implementation PXLockdownResearchRuntime {
    BOOL _armed;
    BOOL _killed;
    NSDate *_expiresAt;
}

- (instancetype)initWithPolicy:(PXLockdownResearchPolicy *)policy {
    self = [super init];
    if (self) _policy = policy ?: [PXLockdownResearchPolicy policyFromSettings:@{}];
    return self;
}

- (BOOL)activateAt:(NSDate *)now {
    @synchronized (self) {
        if (_killed || !_policy.masterEnabled || !_policy.bundleAllowlist.count || ![now isKindOfClass:[NSDate class]]) return NO;
        _armed = YES;
        _expiresAt = [now dateByAddingTimeInterval:_policy.sessionDuration];
        return YES;
    }
}

- (BOOL)isSessionActive {
    @synchronized (self) { return _armed && !_killed && _expiresAt != nil; }
}

- (NSDate *)expiresAt {
    @synchronized (self) { return _expiresAt; }
}

- (PXLockdownSafetyDecision *)decisionForBundleID:(NSString *)bundleID
                                      processName:(NSString *)processName
                                              now:(NSDate *)now {
    @synchronized (self) {
        PXLockdownSafetyReason reason = PXLockdownSafetyReasonAllowed;
        if (_killed) reason = PXLockdownSafetyReasonKillSwitch;
        else if (!_policy.masterEnabled) reason = PXLockdownSafetyReasonMasterDisabled;
        else if (!_armed || !_expiresAt) reason = PXLockdownSafetyReasonSessionInactive;
        else if (![now isKindOfClass:[NSDate class]] || [now compare:_expiresAt] != NSOrderedAscending) {
            _armed = NO;
            _expiresAt = nil;
            reason = PXLockdownSafetyReasonSessionExpired;
        } else if (PXLockdownIsDeniedProcess(bundleID, processName)) reason = PXLockdownSafetyReasonProcessDenied;
        else if (![bundleID isKindOfClass:[NSString class]] || ![_policy.bundleAllowlist containsObject:bundleID]) {
            reason = PXLockdownSafetyReasonNotAllowlisted;
        } else if (_policy.processAllowlist.count &&
                   (![processName isKindOfClass:[NSString class]] || ![_policy.processAllowlist containsObject:processName])) {
            reason = PXLockdownSafetyReasonNotAllowlisted;
        }
        BOOL allowed = reason == PXLockdownSafetyReasonAllowed;
        return [[PXLockdownSafetyDecision alloc] initWithAllowed:allowed reason:reason mode:_policy.mode];
    }
}

- (void)disableAllAndClearSnapshot {
    @synchronized (self) {
        _killed = YES;
        _armed = NO;
        _expiresAt = nil;
    }
}
@end

id PXLockdownOriginalOrReplacement(id original,
                                   id candidate,
                                   Class expectedClass,
                                   PXLockdownSafetyDecision *decision,
                                   BOOL validationPassed) {
    if (!decision.allowed || decision.mode == PXLockdownResearchModeObserveOnly) return original;
    if (!validationPassed || !candidate) return original;
    if (expectedClass && ![candidate isKindOfClass:expectedClass]) return original;
    if (original && expectedClass && ![original isKindOfClass:expectedClass]) return original;
    if (original && !expectedClass && ![candidate isKindOfClass:[original class]]) return original;
    return candidate;
}

NSDictionary<NSString *, id> *PXLockdownRedactedAuditEvent(PXLockdownSafetyDecision *decision,
                                                             NSString *key,
                                                             id sensitiveValue) {
    NSString *valueClass = sensitiveValue ? NSStringFromClass([sensitiveValue class]) : @"nil";
    return @{
        @"component": @"lockdown-research",
        @"decision": decision.reasonCode ?: @"unknown",
        @"mode": decision.mode == PXLockdownResearchModeProfileBacked ? @"profile-backed" : @"observe-only",
        @"key": [key isKindOfClass:[NSString class]] ? key : @"<invalid-key>",
        @"value": @"<redacted>",
        @"valueClass": valueClass,
    };
}
