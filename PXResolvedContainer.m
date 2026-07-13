#import "PXResolvedContainer.h"

static BOOL PXResolvedContainerKindIsValid(PXResolvedContainerKind kind) {
    switch (kind) {
        case PXResolvedContainerKindApplicationData:
        case PXResolvedContainerKindAppGroup:
        case PXResolvedContainerKindExtensionData:
        case PXResolvedContainerKindPluginKitData:
            return YES;
    }
    return NO;
}

static BOOL PXResolvedContainerRootIsValid(PXResolvedContainerRoot root) {
    switch (root) {
        case PXResolvedContainerRootRootful:
        case PXResolvedContainerRootRootless:
            return YES;
    }
    return NO;
}

static BOOL PXStringContainsNUL(NSString *value) {
    unichar nulCharacter = 0;
    NSString *nulString = [NSString stringWithCharacters:&nulCharacter length:1];
    return [value rangeOfString:nulString].location != NSNotFound;
}

static BOOL PXIdentifierContainsNonWhitespace(NSString *identifier) {
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return [identifier rangeOfCharacterFromSet:[whitespace invertedSet]].location != NSNotFound;
}

static BOOL PXContainerPathIsLexicallyValid(NSString *containerPath,
                                            NSString *containerUUID) {
    if (![containerPath hasPrefix:@"/"] ||
        [containerPath isEqualToString:@"/"] ||
        [containerPath hasSuffix:@"/"] ||
        [containerPath rangeOfString:@"//"].location != NSNotFound) {
        return NO;
    }

    NSArray<NSString *> *components = [containerPath componentsSeparatedByString:@"/"];
    for (NSString *component in components) {
        if ([component isEqualToString:@"."] || [component isEqualToString:@".."]) {
            return NO;
        }
    }

    return [[containerPath lastPathComponent] isEqualToString:containerUUID];
}

@implementation PXResolvedContainer

@synthesize kind = _kind;
@synthesize root = _root;
@synthesize requestedIdentifier = _requestedIdentifier;
@synthesize metadataIdentifier = _metadataIdentifier;
@synthesize containerUUID = _containerUUID;
@synthesize containerPath = _containerPath;

- (nullable instancetype)initWithKind:(PXResolvedContainerKind)kind
                                 root:(PXResolvedContainerRoot)root
                  requestedIdentifier:(NSString *)requestedIdentifier
                   metadataIdentifier:(NSString *)metadataIdentifier
                        containerUUID:(NSString *)containerUUID
                        containerPath:(NSString *)containerPath {
    if (!PXResolvedContainerKindIsValid(kind) ||
        !PXResolvedContainerRootIsValid(root)) {
        return nil;
    }

    if (![requestedIdentifier isKindOfClass:[NSString class]] ||
        ![metadataIdentifier isKindOfClass:[NSString class]] ||
        ![containerUUID isKindOfClass:[NSString class]] ||
        ![containerPath isKindOfClass:[NSString class]]) {
        return nil;
    }

    if (requestedIdentifier.length == 0 ||
        metadataIdentifier.length == 0 ||
        containerUUID.length == 0 ||
        containerPath.length == 0) {
        return nil;
    }

    if (!PXIdentifierContainsNonWhitespace(requestedIdentifier) ||
        !PXIdentifierContainsNonWhitespace(metadataIdentifier)) {
        return nil;
    }

    if (PXStringContainsNUL(requestedIdentifier) ||
        PXStringContainsNUL(metadataIdentifier) ||
        PXStringContainsNUL(containerUUID) ||
        PXStringContainsNUL(containerPath)) {
        return nil;
    }

    if (![requestedIdentifier isEqualToString:metadataIdentifier]) {
        return nil;
    }

    if ([containerUUID rangeOfString:@"/"].location != NSNotFound ||
        [containerUUID isEqualToString:@"."] ||
        [containerUUID isEqualToString:@".."] ||
        [[NSUUID alloc] initWithUUIDString:containerUUID] == nil) {
        return nil;
    }

    if (!PXContainerPathIsLexicallyValid(containerPath, containerUUID)) {
        return nil;
    }

    self = [super init];
    if (self) {
        _kind = kind;
        _root = root;
        _requestedIdentifier = [requestedIdentifier copy];
        _metadataIdentifier = [metadataIdentifier copy];
        _containerUUID = [containerUUID copy];
        _containerPath = [containerPath copy];
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
    if (![object isKindOfClass:[PXResolvedContainer class]]) {
        return NO;
    }

    PXResolvedContainer *other = (PXResolvedContainer *)object;
    return _kind == other->_kind &&
           _root == other->_root &&
           [_requestedIdentifier isEqualToString:other->_requestedIdentifier] &&
           [_metadataIdentifier isEqualToString:other->_metadataIdentifier] &&
           [_containerUUID isEqualToString:other->_containerUUID] &&
           [_containerPath isEqualToString:other->_containerPath];
}

- (NSUInteger)hash {
    NSUInteger hashValue = (NSUInteger)_kind;
    hashValue = hashValue * 31u + (NSUInteger)_root;
    hashValue = hashValue * 31u + _requestedIdentifier.hash;
    hashValue = hashValue * 31u + _metadataIdentifier.hash;
    hashValue = hashValue * 31u + _containerUUID.hash;
    hashValue = hashValue * 31u + _containerPath.hash;
    return hashValue;
}

@end
