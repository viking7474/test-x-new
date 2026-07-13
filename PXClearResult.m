#import "PXClearResult.h"

static BOOL PXClearResultStringContainsNUL(NSString *value) {
    unichar nulCharacter = 0;
    NSString *nulString = [NSString stringWithCharacters:&nulCharacter length:1];
    return [value rangeOfString:nulString].location != NSNotFound;
}

static BOOL PXClearResultStringContainsNonWhitespace(NSString *value) {
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return [value rangeOfCharacterFromSet:[whitespace invertedSet]].location != NSNotFound;
}

static BOOL PXClearResultRequiredStringIsValid(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }

    NSString *stringValue = (NSString *)value;
    return stringValue.length > 0 &&
           PXClearResultStringContainsNonWhitespace(stringValue) &&
           !PXClearResultStringContainsNUL(stringValue);
}

static BOOL PXClearResultOptionalStringIsValid(id value) {
    return value == nil || PXClearResultRequiredStringIsValid(value);
}

static BOOL PXClearResultScopeIsOneKnownBit(PXClearScope scope) {
    return scope != 0 &&
           (scope & ~PXClearScopeKnownMask) == 0 &&
           (scope & (scope - 1)) == 0;
}

static BOOL PXClearResultStatusIsValid(PXClearComponentStatus status) {
    return status == PXClearComponentStatusSucceeded ||
           status == PXClearComponentStatusSkipped ||
           status == PXClearComponentStatusFailed;
}

static BOOL PXClearResultObjectsAreEqual(id first, id second) {
    return first == second || [first isEqual:second];
}

@implementation PXClearFailure

@synthesize domain = _domain;
@synthesize code = _code;
@synthesize message = _message;

- (nullable instancetype)initWithDomain:(NSString *)domain
                                   code:(NSInteger)code
                                message:(NSString *)message {
    if (!PXClearResultRequiredStringIsValid(domain) ||
        !PXClearResultRequiredStringIsValid(message)) {
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

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isMemberOfClass:[PXClearFailure class]]) {
        return NO;
    }

    PXClearFailure *other = (PXClearFailure *)object;
    return [_domain isEqualToString:other->_domain] &&
           _code == other->_code &&
           [_message isEqualToString:other->_message];
}

- (NSUInteger)hash {
    NSUInteger hashValue = _domain.hash;
    hashValue = hashValue * 31u + (NSUInteger)_code;
    hashValue = hashValue * 31u + _message.hash;
    return hashValue;
}

@end

@implementation PXClearComponentResult

@synthesize scope = _scope;
@synthesize status = _status;
@synthesize attemptedUnitCount = _attemptedUnitCount;
@synthesize succeededUnitCount = _succeededUnitCount;
@synthesize failedUnitCount = _failedUnitCount;
@synthesize detail = _detail;
@synthesize failure = _failure;

- (nullable instancetype)initWithScope:(PXClearScope)scope
                                status:(PXClearComponentStatus)status
                    attemptedUnitCount:(NSUInteger)attemptedUnitCount
                    succeededUnitCount:(NSUInteger)succeededUnitCount
                       failedUnitCount:(NSUInteger)failedUnitCount
                                detail:(nullable NSString *)detail
                               failure:(nullable PXClearFailure *)failure {
    if (!PXClearResultScopeIsOneKnownBit(scope) ||
        !PXClearResultStatusIsValid(status) ||
        !PXClearResultOptionalStringIsValid(detail) ||
        (failure != nil && ![failure isKindOfClass:[PXClearFailure class]])) {
        return nil;
    }

    if (succeededUnitCount > attemptedUnitCount ||
        failedUnitCount != attemptedUnitCount - succeededUnitCount) {
        return nil;
    }

    switch (status) {
        case PXClearComponentStatusSucceeded:
            if (attemptedUnitCount == 0 ||
                succeededUnitCount != attemptedUnitCount ||
                failedUnitCount != 0 ||
                failure != nil) {
                return nil;
            }
            break;

        case PXClearComponentStatusSkipped:
            if (attemptedUnitCount != 0 ||
                succeededUnitCount != 0 ||
                failedUnitCount != 0 ||
                failure != nil ||
                detail == nil) {
                return nil;
            }
            break;

        case PXClearComponentStatusFailed:
            if (attemptedUnitCount == 0 ||
                failedUnitCount == 0 ||
                failure == nil) {
                return nil;
            }
            break;
    }

    self = [super init];
    if (self) {
        _scope = scope;
        _status = status;
        _attemptedUnitCount = attemptedUnitCount;
        _succeededUnitCount = succeededUnitCount;
        _failedUnitCount = failedUnitCount;
        _detail = [detail copy];
        _failure = [failure copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isMemberOfClass:[PXClearComponentResult class]]) {
        return NO;
    }

    PXClearComponentResult *other = (PXClearComponentResult *)object;
    return _scope == other->_scope &&
           _status == other->_status &&
           _attemptedUnitCount == other->_attemptedUnitCount &&
           _succeededUnitCount == other->_succeededUnitCount &&
           _failedUnitCount == other->_failedUnitCount &&
           PXClearResultObjectsAreEqual(_detail, other->_detail) &&
           PXClearResultObjectsAreEqual(_failure, other->_failure);
}

- (NSUInteger)hash {
    NSUInteger hashValue = (NSUInteger)_scope;
    hashValue = hashValue * 31u + (NSUInteger)_status;
    hashValue = hashValue * 31u + _attemptedUnitCount;
    hashValue = hashValue * 31u + _succeededUnitCount;
    hashValue = hashValue * 31u + _failedUnitCount;
    hashValue = hashValue * 31u + _detail.hash;
    hashValue = hashValue * 31u + _failure.hash;
    return hashValue;
}

@end

@implementation PXClearResult

@synthesize request = _request;
@synthesize componentResults = _componentResults;
@synthesize succeededScopes = _succeededScopes;
@synthesize skippedScopes = _skippedScopes;
@synthesize failedScopes = _failedScopes;

- (nullable instancetype)initWithRequest:(PXClearRequest *)request
                        componentResults:(NSArray<PXClearComponentResult *> *)componentResults {
    if (![request isKindOfClass:[PXClearRequest class]] ||
        ![componentResults isKindOfClass:[NSArray class]] ||
        componentResults.count == 0) {
        return nil;
    }

    PXClearScope seenScopes = 0;
    PXClearScope succeededScopes = 0;
    PXClearScope skippedScopes = 0;
    PXClearScope failedScopes = 0;

    for (id value in componentResults) {
        if (![value isKindOfClass:[PXClearComponentResult class]]) {
            return nil;
        }

        PXClearComponentResult *componentResult = (PXClearComponentResult *)value;
        PXClearScope scope = componentResult.scope;
        if (!PXClearResultScopeIsOneKnownBit(scope) ||
            (request.scopes & scope) != scope ||
            (seenScopes & scope) != 0) {
            return nil;
        }

        seenScopes |= scope;
        switch (componentResult.status) {
            case PXClearComponentStatusSucceeded:
                succeededScopes |= scope;
                break;

            case PXClearComponentStatusSkipped:
                skippedScopes |= scope;
                break;

            case PXClearComponentStatusFailed:
                failedScopes |= scope;
                break;

            default:
                return nil;
        }
    }

    if (seenScopes != request.scopes ||
        (succeededScopes & skippedScopes) != 0 ||
        (succeededScopes & failedScopes) != 0 ||
        (skippedScopes & failedScopes) != 0 ||
        (succeededScopes | skippedScopes | failedScopes) != request.scopes) {
        return nil;
    }

    const PXClearScope canonicalScopes[] = {
        PXClearScopeApplicationData,
        PXClearScopeExtensionData,
        PXClearScopeAppGroups,
        PXClearScopePluginKitData,
        PXClearScopeKeychain,
    };
    NSArray<PXClearComponentResult *> *canonicalResults = @[];
    for (NSUInteger scopeIndex = 0;
         scopeIndex < sizeof(canonicalScopes) / sizeof(canonicalScopes[0]);
         scopeIndex++) {
        PXClearScope canonicalScope = canonicalScopes[scopeIndex];
        if ((request.scopes & canonicalScope) == 0) {
            continue;
        }

        for (PXClearComponentResult *componentResult in componentResults) {
            if (componentResult.scope == canonicalScope) {
                canonicalResults = [canonicalResults arrayByAddingObject:componentResult];
                break;
            }
        }
    }
    if (canonicalResults.count != componentResults.count) {
        return nil;
    }

    self = [super init];
    if (self) {
        _request = [request copy];
        _componentResults = [canonicalResults copy];
        _succeededScopes = succeededScopes;
        _skippedScopes = skippedScopes;
        _failedScopes = failedScopes;
    }
    return self;
}

- (BOOL)hasFailures {
    return _failedScopes != 0;
}

- (BOOL)allRequestedScopesSucceeded {
    return _succeededScopes == _request.scopes;
}

- (nullable PXClearComponentResult *)componentResultForScope:(PXClearScope)scope {
    if (!PXClearResultScopeIsOneKnownBit(scope) ||
        (_request.scopes & scope) != scope) {
        return nil;
    }

    for (PXClearComponentResult *componentResult in _componentResults) {
        if (componentResult.scope == scope) {
            return componentResult;
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
    if (![object isMemberOfClass:[PXClearResult class]]) {
        return NO;
    }

    PXClearResult *other = (PXClearResult *)object;
    return [_request isEqual:other->_request] &&
           [_componentResults isEqualToArray:other->_componentResults];
}

- (NSUInteger)hash {
    NSUInteger hashValue = _request.hash;
    hashValue = hashValue * 31u + _componentResults.hash;
    return hashValue;
}

@end
