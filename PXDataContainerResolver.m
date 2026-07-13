#import "PXDataContainerResolver.h"

NSString * const PXDataContainerResolverErrorDomain = @"PXDataContainerResolverErrorDomain";

static NSString * const PXRootfulApplicationDataBase = @"/private/var/mobile/Containers/Data/Application";
static NSString * const PXRootlessApplicationDataBase = @"/containers/Data/Application";
static NSString * const PXContainerMetadataFilename = @".com.apple.mobile_container_manager.metadata.plist";
static NSString * const PXContainerMetadataIdentifierKey = @"MCMMetadataIdentifier";

static void PXSetDataContainerResolverError(NSError * _Nullable * _Nullable error,
                                            PXDataContainerResolverErrorCode code,
                                            NSString *description) {
    if (error == NULL) {
        return;
    }

    *error = [NSError errorWithDomain:PXDataContainerResolverErrorDomain
                                 code:code
                             userInfo:@{NSLocalizedDescriptionKey: description}];
}

static BOOL PXStringContainsNUL(NSString *value) {
    unichar nulCharacter = 0;
    NSString *nulString = [NSString stringWithCharacters:&nulCharacter length:1];
    return [value rangeOfString:nulString].location != NSNotFound;
}

static BOOL PXStringContainsNonWhitespace(NSString *value) {
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return [value rangeOfCharacterFromSet:[whitespace invertedSet]].location != NSNotFound;
}

static BOOL PXResolverIdentifierIsValid(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }

    NSString *identifier = (NSString *)value;
    return identifier.length > 0 &&
           PXStringContainsNonWhitespace(identifier) &&
           !PXStringContainsNUL(identifier);
}

static BOOL PXResolverRootIsValid(PXResolvedContainerRoot root) {
    return root == PXResolvedContainerRootRootful ||
           root == PXResolvedContainerRootRootless;
}

static NSString *PXApplicationDataBaseForRoot(PXResolvedContainerRoot root) {
    switch (root) {
        case PXResolvedContainerRootRootful:
            return PXRootfulApplicationDataBase;
        case PXResolvedContainerRootRootless:
            return PXRootlessApplicationDataBase;
    }
    return nil;
}

static BOOL PXDirectoryEntryIsValid(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }

    NSString *entry = (NSString *)value;
    if (entry.length == 0 ||
        [entry isEqualToString:@"."] ||
        [entry isEqualToString:@".."] ||
        [entry hasPrefix:@"."] ||
        [entry rangeOfString:@"/"].location != NSNotFound ||
        PXStringContainsNUL(entry)) {
        return NO;
    }

    return [[NSUUID alloc] initWithUUIDString:entry] != nil;
}

@implementation PXDataContainerResolver

- (nullable PXResolvedContainer *)resolveApplicationDataContainerForIdentifier:(NSString *)identifier
                                                                          root:(PXResolvedContainerRoot)root
                                                                         error:(NSError * _Nullable * _Nullable)error {
    if (error != NULL) {
        *error = nil;
    }

    if (!PXResolverIdentifierIsValid(identifier) || !PXResolverRootIsValid(root)) {
        PXSetDataContainerResolverError(error,
                                        PXDataContainerResolverErrorInvalidInput,
                                        @"The application identifier or container root is invalid.");
        return nil;
    }

    NSString *basePath = PXApplicationDataBaseForRoot(root);
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL baseIsDirectory = NO;
    if (![fileManager fileExistsAtPath:basePath isDirectory:&baseIsDirectory]) {
        return nil;
    }
    if (!baseIsDirectory) {
        PXSetDataContainerResolverError(error,
                                        PXDataContainerResolverErrorEnumerationFailed,
                                        @"The selected application-data container base is not a directory.");
        return nil;
    }

    NSError *enumerationError = nil;
    NSArray *rawChildNames = [fileManager contentsOfDirectoryAtPath:basePath
                                                              error:&enumerationError];
    if (![rawChildNames isKindOfClass:[NSArray class]] || enumerationError != nil) {
        PXSetDataContainerResolverError(error,
                                        PXDataContainerResolverErrorEnumerationFailed,
                                        @"The selected application-data container base could not be enumerated.");
        return nil;
    }

    NSMutableArray<NSString *> *childNames = [NSMutableArray array];
    for (id rawChildName in rawChildNames) {
        if ([rawChildName isKindOfClass:[NSString class]]) {
            [childNames addObject:(NSString *)rawChildName];
        }
    }
    [childNames sortUsingSelector:@selector(compare:)];

    PXResolvedContainer *resolvedContainer = nil;
    for (NSString *containerUUID in childNames) {
        if (!PXDirectoryEntryIsValid(containerUUID)) {
            continue;
        }

        NSString *containerPath = [basePath stringByAppendingPathComponent:containerUUID];
        BOOL candidateIsDirectory = NO;
        if (![fileManager fileExistsAtPath:containerPath isDirectory:&candidateIsDirectory] ||
            !candidateIsDirectory) {
            continue;
        }

        NSString *metadataPath = [containerPath stringByAppendingPathComponent:PXContainerMetadataFilename];
        id metadataObject = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        if (![metadataObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        id rawMetadataIdentifier = [(NSDictionary *)metadataObject objectForKey:PXContainerMetadataIdentifierKey];
        if (!PXResolverIdentifierIsValid(rawMetadataIdentifier)) {
            continue;
        }

        NSString *metadataIdentifier = (NSString *)rawMetadataIdentifier;
        if (![metadataIdentifier isEqualToString:identifier]) {
            continue;
        }

        PXResolvedContainer *candidate = [[PXResolvedContainer alloc]
            initWithKind:PXResolvedContainerKindApplicationData
                    root:root
     requestedIdentifier:identifier
      metadataIdentifier:metadataIdentifier
           containerUUID:containerUUID
           containerPath:containerPath];
        if (candidate == nil) {
            PXSetDataContainerResolverError(error,
                                            PXDataContainerResolverErrorInvalidCandidate,
                                            @"An exact metadata match could not produce a valid resolved container.");
            return nil;
        }

        if (resolvedContainer != nil) {
            PXSetDataContainerResolverError(error,
                                            PXDataContainerResolverErrorAmbiguousMatch,
                                            @"Multiple exact application-data container matches were found.");
            return nil;
        }
        resolvedContainer = candidate;
    }

    return resolvedContainer;
}

@end
