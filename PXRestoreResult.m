#import "PXRestoreResult.h"

static const NSUInteger PXRestoreMaximumStringBytes = 4096;
static const NSUInteger PXRestoreMaximumDomainBytes = 255;
static const NSUInteger PXRestoreMaximumWarnings = 4096;
static const NSUInteger PXRestoreMaximumPlannedUnits = 4096;

static const PXRestoreComponent PXRestoreCanonicalComponents[] = {
    PXRestoreComponentApplicationData,
    PXRestoreComponentProfileAppData,
    PXRestoreComponentGlobalSafari,
    PXRestoreComponentAppGroups,
    PXRestoreComponentSystemGlobal,
    PXRestoreComponentSharedSystemDatabases,
    PXRestoreComponentPreferences,
    PXRestoreComponentKeychain,
};

static BOOL PXRestoreStringIsValid(NSString *value, NSUInteger maximumUTF8Bytes) {
    if (![value isKindOfClass:[NSString class]] || value.length == 0) {
        return NO;
    }
    for (NSUInteger index = 0; index < value.length; index++) {
        if ([value characterAtIndex:index] == 0) {
            return NO;
        }
    }
    NSData *bytes = [value dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    return bytes != nil && bytes.length > 0 && bytes.length <= maximumUTF8Bytes;
}

static NSArray<NSString *> *PXRestoreCopyWarnings(NSArray<NSString *> *warnings) {
    if (![warnings isKindOfClass:[NSArray class]] || warnings.count > PXRestoreMaximumWarnings) {
        return nil;
    }
    NSMutableArray<NSString *> *copied = [NSMutableArray arrayWithCapacity:warnings.count];
    for (id value in warnings) {
        if (!PXRestoreStringIsValid(value, PXRestoreMaximumStringBytes)) {
            return nil;
        }
        [copied addObject:[(NSString *)value copy]];
    }
    return [copied copy];
}

static BOOL PXRestoreComponentIsKnownSingleBit(PXRestoreComponent component) {
    NSUInteger value = (NSUInteger)component;
    return value != 0 &&
           (value & (value - 1)) == 0 &&
           (value & ~(NSUInteger)PXRestoreComponentAll) == 0;
}

static BOOL PXRestoreComponentStatusIsKnown(PXRestoreComponentStatus status) {
    switch (status) {
        case PXRestoreComponentStatusSkipped:
        case PXRestoreComponentStatusNotAttempted:
        case PXRestoreComponentStatusSucceeded:
        case PXRestoreComponentStatusFailed:
            return YES;
    }
    return NO;
}

static BOOL PXRestoreRollbackStatusIsKnown(PXRestoreRollbackStatus status) {
    switch (status) {
        case PXRestoreRollbackStatusNotPerformed:
        case PXRestoreRollbackStatusCompleted:
        case PXRestoreRollbackStatusIncomplete:
            return YES;
    }
    return NO;
}

static NSUInteger PXRestoreHashCombine(NSUInteger seed, NSUInteger value) {
    return seed ^ (value + (NSUInteger)0x9e3779b9 + (seed << 6) + (seed >> 2));
}

@implementation PXRestoreFailure {
    NSString *_domain;
    NSInteger _code;
    NSString *_message;
}

- (nullable instancetype)initWithDomain:(NSString *)domain
                                   code:(NSInteger)code
                                message:(NSString *)message {
    if (!PXRestoreStringIsValid(domain, PXRestoreMaximumDomainBytes) ||
        !PXRestoreStringIsValid(message, PXRestoreMaximumStringBytes)) {
        return nil;
    }
    self = [super init];
    if (self) {
        _domain = [domain copy];
        _code = code;
        _message = [message copy];
    }
    return self;
}

- (NSString *)domain { return _domain; }
- (NSInteger)code { return _code; }
- (NSString *)message { return _message; }

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[PXRestoreFailure class]]) {
        return NO;
    }
    PXRestoreFailure *other = object;
    return self.code == other.code &&
           [self.domain isEqualToString:other.domain] &&
           [self.message isEqualToString:other.message];
}

- (NSUInteger)hash {
    NSUInteger value = self.domain.hash;
    value = PXRestoreHashCombine(value, (NSUInteger)self.code);
    return PXRestoreHashCombine(value, self.message.hash);
}

@end

@implementation PXRestoreComponentResult {
    PXRestoreComponent _component;
    PXRestoreComponentStatus _status;
    NSUInteger _plannedUnitCount;
    NSUInteger _committedUnitCount;
    PXRestoreRollbackStatus _rollbackStatus;
    NSArray<NSString *> *_warnings;
    PXRestoreFailure *_failure;
}

- (nullable instancetype)initWithComponent:(PXRestoreComponent)component
                                    status:(PXRestoreComponentStatus)status
                          plannedUnitCount:(NSUInteger)plannedUnitCount
                        committedUnitCount:(NSUInteger)committedUnitCount
                            rollbackStatus:(PXRestoreRollbackStatus)rollbackStatus
                                  warnings:(NSArray<NSString *> *)warnings
                                   failure:(nullable PXRestoreFailure *)failure {
    if (!PXRestoreComponentIsKnownSingleBit(component) ||
        !PXRestoreComponentStatusIsKnown(status) ||
        !PXRestoreRollbackStatusIsKnown(rollbackStatus) ||
        plannedUnitCount > PXRestoreMaximumPlannedUnits ||
        (failure && ![failure isKindOfClass:[PXRestoreFailure class]])) {
        return nil;
    }
    NSArray<NSString *> *copiedWarnings = PXRestoreCopyWarnings(warnings);
    if (!copiedWarnings) {
        return nil;
    }

    BOOL valid = NO;
    switch (status) {
        case PXRestoreComponentStatusSkipped:
            valid = plannedUnitCount == 0 &&
                    committedUnitCount == 0 &&
                    rollbackStatus == PXRestoreRollbackStatusNotPerformed &&
                    copiedWarnings.count == 0 &&
                    failure == nil;
            break;
        case PXRestoreComponentStatusNotAttempted:
            valid = plannedUnitCount >= 1 &&
                    committedUnitCount == 0 &&
                    rollbackStatus == PXRestoreRollbackStatusNotPerformed &&
                    failure == nil;
            break;
        case PXRestoreComponentStatusSucceeded:
            valid = plannedUnitCount >= 1 &&
                    committedUnitCount == plannedUnitCount &&
                    rollbackStatus == PXRestoreRollbackStatusNotPerformed &&
                    failure == nil;
            break;
        case PXRestoreComponentStatusFailed:
            valid = plannedUnitCount >= 1 &&
                    committedUnitCount == 0 &&
                    failure != nil;
            break;
    }
    if (!valid) {
        return nil;
    }

    self = [super init];
    if (self) {
        _component = component;
        _status = status;
        _plannedUnitCount = plannedUnitCount;
        _committedUnitCount = committedUnitCount;
        _rollbackStatus = rollbackStatus;
        _warnings = copiedWarnings;
        _failure = [failure copy];
    }
    return self;
}

- (PXRestoreComponent)component { return _component; }
- (PXRestoreComponentStatus)status { return _status; }
- (NSUInteger)plannedUnitCount { return _plannedUnitCount; }
- (NSUInteger)committedUnitCount { return _committedUnitCount; }
- (PXRestoreRollbackStatus)rollbackStatus { return _rollbackStatus; }
- (NSArray<NSString *> *)warnings { return _warnings; }
- (PXRestoreFailure *)failure { return _failure; }

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[PXRestoreComponentResult class]]) {
        return NO;
    }
    PXRestoreComponentResult *other = object;
    return self.component == other.component &&
           self.status == other.status &&
           self.plannedUnitCount == other.plannedUnitCount &&
           self.committedUnitCount == other.committedUnitCount &&
           self.rollbackStatus == other.rollbackStatus &&
           [self.warnings isEqualToArray:other.warnings] &&
           ((self.failure == nil && other.failure == nil) ||
            [self.failure isEqual:other.failure]);
}

- (NSUInteger)hash {
    NSUInteger value = (NSUInteger)self.component;
    value = PXRestoreHashCombine(value, (NSUInteger)self.status);
    value = PXRestoreHashCombine(value, self.plannedUnitCount);
    value = PXRestoreHashCombine(value, self.committedUnitCount);
    value = PXRestoreHashCombine(value, (NSUInteger)self.rollbackStatus);
    value = PXRestoreHashCombine(value, self.warnings.hash);
    return PXRestoreHashCombine(value, self.failure.hash);
}

@end

@implementation PXRestoreResult {
    PXRestoreComponent _requestedComponents;
    NSArray<PXRestoreComponentResult *> *_componentResults;
    PXRestoreComponent _succeededComponents;
    PXRestoreComponent _skippedComponents;
    PXRestoreComponent _notAttemptedComponents;
    PXRestoreComponent _failedComponents;
    NSArray<NSString *> *_warnings;
    BOOL _hasWarnings;
    BOOL _hasFailures;
    BOOL _hasIncompleteRollback;
    BOOL _allRequestedComponentsSucceeded;
}

- (nullable instancetype)initWithRequestedComponents:(PXRestoreComponent)requestedComponents
                                    componentResults:(NSArray<PXRestoreComponentResult *> *)componentResults
                                            warnings:(NSArray<NSString *> *)warnings {
    if (((NSUInteger)requestedComponents & ~(NSUInteger)PXRestoreComponentAll) != 0 ||
        (requestedComponents & PXRestoreComponentApplicationData) == 0 ||
        ![componentResults isKindOfClass:[NSArray class]] ||
        componentResults.count != 8) {
        return nil;
    }
    NSArray<NSString *> *copiedWarnings = PXRestoreCopyWarnings(warnings);
    if (!copiedWarnings) {
        return nil;
    }

    NSMutableDictionary<NSNumber *, PXRestoreComponentResult *> *byComponent =
        [NSMutableDictionary dictionaryWithCapacity:8];
    PXRestoreComponent succeeded = 0;
    PXRestoreComponent skipped = 0;
    PXRestoreComponent notAttempted = 0;
    PXRestoreComponent failed = 0;
    BOOL incompleteRollback = NO;

    for (id value in componentResults) {
        if (![value isKindOfClass:[PXRestoreComponentResult class]]) {
            return nil;
        }
        PXRestoreComponentResult *result = value;
        if (!PXRestoreComponentIsKnownSingleBit(result.component) ||
            byComponent[@(result.component)] != nil) {
            return nil;
        }
        BOOL requested = (requestedComponents & result.component) != 0;
        if ((requested && result.status == PXRestoreComponentStatusSkipped) ||
            (!requested && result.status != PXRestoreComponentStatusSkipped)) {
            return nil;
        }
        byComponent[@(result.component)] = result;
        switch (result.status) {
            case PXRestoreComponentStatusSkipped:
                skipped |= result.component;
                break;
            case PXRestoreComponentStatusNotAttempted:
                notAttempted |= result.component;
                break;
            case PXRestoreComponentStatusSucceeded:
                succeeded |= result.component;
                break;
            case PXRestoreComponentStatusFailed:
                failed |= result.component;
                break;
        }
        if (result.rollbackStatus == PXRestoreRollbackStatusIncomplete) {
            incompleteRollback = YES;
        }
    }

    NSMutableArray<PXRestoreComponentResult *> *canonical =
        [NSMutableArray arrayWithCapacity:8];
    for (NSUInteger index = 0; index < 8; index++) {
        PXRestoreComponent component = PXRestoreCanonicalComponents[index];
        PXRestoreComponentResult *result = byComponent[@(component)];
        if (!result) {
            return nil;
        }
        [canonical addObject:result];
    }

    PXRestoreComponent unionMask = succeeded | skipped | notAttempted | failed;
    BOOL masksDisjoint =
        (succeeded & skipped) == 0 &&
        (succeeded & notAttempted) == 0 &&
        (succeeded & failed) == 0 &&
        (skipped & notAttempted) == 0 &&
        (skipped & failed) == 0 &&
        (notAttempted & failed) == 0;
    if (!masksDisjoint || unionMask != PXRestoreComponentAll ||
        requestedComponents != (succeeded | notAttempted | failed) ||
        skipped != (PXRestoreComponentAll & ~requestedComponents)) {
        return nil;
    }

    self = [super init];
    if (self) {
        _requestedComponents = requestedComponents;
        _componentResults = [canonical copy];
        _succeededComponents = succeeded;
        _skippedComponents = skipped;
        _notAttemptedComponents = notAttempted;
        _failedComponents = failed;
        _warnings = copiedWarnings;
        _hasWarnings = copiedWarnings.count > 0;
        _hasFailures = failed != 0;
        _hasIncompleteRollback = incompleteRollback;
        _allRequestedComponentsSucceeded = succeeded == requestedComponents;
    }
    return self;
}

- (PXRestoreComponent)requestedComponents { return _requestedComponents; }
- (NSArray<PXRestoreComponentResult *> *)componentResults { return _componentResults; }
- (PXRestoreComponent)succeededComponents { return _succeededComponents; }
- (PXRestoreComponent)skippedComponents { return _skippedComponents; }
- (PXRestoreComponent)notAttemptedComponents { return _notAttemptedComponents; }
- (PXRestoreComponent)failedComponents { return _failedComponents; }
- (NSArray<NSString *> *)warnings { return _warnings; }
- (BOOL)hasWarnings { return _hasWarnings; }
- (BOOL)hasFailures { return _hasFailures; }
- (BOOL)hasIncompleteRollback { return _hasIncompleteRollback; }
- (BOOL)allRequestedComponentsSucceeded { return _allRequestedComponentsSucceeded; }

- (nullable PXRestoreComponentResult *)componentResultForComponent:(PXRestoreComponent)component {
    if (!PXRestoreComponentIsKnownSingleBit(component)) {
        return nil;
    }
    for (PXRestoreComponentResult *result in self.componentResults) {
        if (result.component == component) {
            return result;
        }
    }
    return nil;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[PXRestoreResult class]]) {
        return NO;
    }
    PXRestoreResult *other = object;
    return self.requestedComponents == other.requestedComponents &&
           self.succeededComponents == other.succeededComponents &&
           self.skippedComponents == other.skippedComponents &&
           self.notAttemptedComponents == other.notAttemptedComponents &&
           self.failedComponents == other.failedComponents &&
           self.hasWarnings == other.hasWarnings &&
           self.hasFailures == other.hasFailures &&
           self.hasIncompleteRollback == other.hasIncompleteRollback &&
           self.allRequestedComponentsSucceeded == other.allRequestedComponentsSucceeded &&
           [self.componentResults isEqualToArray:other.componentResults] &&
           [self.warnings isEqualToArray:other.warnings];
}

- (NSUInteger)hash {
    NSUInteger value = (NSUInteger)self.requestedComponents;
    value = PXRestoreHashCombine(value, self.componentResults.hash);
    value = PXRestoreHashCombine(value, (NSUInteger)self.succeededComponents);
    value = PXRestoreHashCombine(value, (NSUInteger)self.skippedComponents);
    value = PXRestoreHashCombine(value, (NSUInteger)self.notAttemptedComponents);
    value = PXRestoreHashCombine(value, (NSUInteger)self.failedComponents);
    value = PXRestoreHashCombine(value, self.warnings.hash);
    value = PXRestoreHashCombine(value, self.hasWarnings ? 1 : 0);
    value = PXRestoreHashCombine(value, self.hasFailures ? 1 : 0);
    value = PXRestoreHashCombine(value, self.hasIncompleteRollback ? 1 : 0);
    return PXRestoreHashCombine(value, self.allRequestedComponentsSucceeded ? 1 : 0);
}

@end
