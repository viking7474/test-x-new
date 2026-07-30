#import "PXClearRequest.h"

const PXClearScope PXClearScopeKnownMask =
    PXClearScopeApplicationData |
    PXClearScopeExtensionData |
    PXClearScopeAppGroups |
    PXClearScopePluginKitData |
    PXClearScopeKeychain;

const PXClearScope PXClearScopeDefaultMask =
    PXClearScopeApplicationData |
    PXClearScopeExtensionData |
    PXClearScopeAppGroups |
    PXClearScopePluginKitData |
    PXClearScopeKeychain;

BOOL PXClearModeIsValid(PXClearMode mode) {
    return mode == PXClearModeQuick || mode == PXClearModeFull || mode == PXClearModeDeep;
}

NSString *PXClearModeName(PXClearMode mode) {
    switch (mode) {
        case PXClearModeQuick: return @"Quick";
        case PXClearModeFull: return @"Full";
        case PXClearModeDeep: return @"Deep";
    }
    return @"Invalid";
}

BOOL PXClearModeIncludesExtendedContainers(PXClearMode mode) {
    return mode == PXClearModeFull || mode == PXClearModeDeep;
}

BOOL PXClearModeIncludesDeepDiagnostics(PXClearMode mode) {
    return mode == PXClearModeDeep;
}

static BOOL PXClearRequestStringContainsNUL(NSString *value) {
    unichar nulCharacter = 0;
    NSString *nulString = [NSString stringWithCharacters:&nulCharacter length:1];
    return [value rangeOfString:nulString].location != NSNotFound;
}

static BOOL PXClearRequestStringContainsNonWhitespace(NSString *value) {
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return [value rangeOfCharacterFromSet:[whitespace invertedSet]].location != NSNotFound;
}

static BOOL PXClearRequestCharacterIsAllowed(unichar character) {
    return (character >= (unichar)'A' && character <= (unichar)'Z') ||
           (character >= (unichar)'a' && character <= (unichar)'z') ||
           (character >= (unichar)'0' && character <= (unichar)'9') ||
           character == (unichar)'-' ||
           character == (unichar)'.';
}

static BOOL PXClearRequestBundleIdentifierIsValid(id value) {
    if (![value isKindOfClass:[NSString class]]) return NO;

    NSString *identifier = (NSString *)value;
    if (identifier.length == 0 ||
        !PXClearRequestStringContainsNonWhitespace(identifier) ||
        PXClearRequestStringContainsNUL(identifier)) return NO;

    if ([identifier rangeOfString:@"/"].location != NSNotFound ||
        [identifier rangeOfString:@"\\"].location != NSNotFound ||
        [identifier rangeOfString:@"*"].location != NSNotFound ||
        [identifier characterAtIndex:0] == (unichar)'.' ||
        [identifier characterAtIndex:(identifier.length - 1)] == (unichar)'.' ||
        [identifier rangeOfString:@".."].location != NSNotFound) return NO;

    NSUInteger componentLength = 0;
    for (NSUInteger index = 0; index < identifier.length; index++) {
        unichar character = [identifier characterAtIndex:index];
        if (!PXClearRequestCharacterIsAllowed(character)) return NO;
        if (character == (unichar)'.') {
            if (componentLength == 0) return NO;
            componentLength = 0;
        } else {
            componentLength++;
        }
    }
    return componentLength > 0;
}

static BOOL PXClearRequestScopesAreValid(PXClearScope scopes) {
    return scopes != 0 && (scopes & ~PXClearScopeKnownMask) == 0;
}

@implementation PXClearRequest

@synthesize bundleIdentifier = _bundleIdentifier;
@synthesize scopes = _scopes;
@synthesize mode = _mode;

- (nullable instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                                            scopes:(PXClearScope)scopes
                                              mode:(PXClearMode)mode {
    if (!PXClearRequestBundleIdentifierIsValid(bundleIdentifier) ||
        !PXClearRequestScopesAreValid(scopes) ||
        !PXClearModeIsValid(mode)) return nil;

    self = [super init];
    if (self) {
        _bundleIdentifier = [bundleIdentifier copy];
        _scopes = scopes;
        _mode = mode;
    }
    return self;
}

- (nullable instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                                            scopes:(PXClearScope)scopes
                                         deepClean:(BOOL)deepClean {
    return [self initWithBundleIdentifier:bundleIdentifier
                                   scopes:scopes
                                     mode:deepClean ? PXClearModeDeep : PXClearModeFull];
}

- (BOOL)isDeepClean {
    return _mode == PXClearModeDeep;
}

+ (nullable instancetype)defaultRequestForBundleIdentifier:(NSString *)bundleIdentifier {
    return [[self alloc] initWithBundleIdentifier:bundleIdentifier
                                           scopes:PXClearScopeDefaultMask
                                             mode:PXClearModeFull];
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isMemberOfClass:[PXClearRequest class]]) return NO;
    PXClearRequest *other = (PXClearRequest *)object;
    return [_bundleIdentifier isEqualToString:other->_bundleIdentifier] &&
           _scopes == other->_scopes && _mode == other->_mode;
}

- (NSUInteger)hash {
    NSUInteger hashValue = _bundleIdentifier.hash;
    hashValue = hashValue * 31u + (NSUInteger)_scopes;
    hashValue = hashValue * 31u + (NSUInteger)_mode;
    return hashValue;
}

@end
