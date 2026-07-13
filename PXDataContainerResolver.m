#import "PXDataContainerResolver.h"

#import <sys/stat.h>

NSString * const PXDataContainerResolverErrorDomain = @"PXDataContainerResolverErrorDomain";

static BOOL PXResolverStringContainsNUL(NSString *value) {
    unichar nulCharacter = 0;
    NSString *nulString =
        [NSString stringWithCharacters:&nulCharacter length:1];
    return [value rangeOfString:nulString].location != NSNotFound;
}

static BOOL PXResolverStringContainsNonWhitespace(NSString *value) {
    NSCharacterSet *whitespace =
        [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return [value rangeOfCharacterFromSet:[whitespace invertedSet]].location
        != NSNotFound;
}

static BOOL PXResolverIdentifierIsValid(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }

    NSString *identifier = (NSString *)value;
    return identifier.length > 0 &&
           PXResolverStringContainsNonWhitespace(identifier) &&
           !PXResolverStringContainsNUL(identifier);
}

static BOOL PXResolverKindIsAllowed(PXResolvedContainerKind kind) {
    return kind == PXResolvedContainerKindApplicationData ||
           kind == PXResolvedContainerKindExtensionData ||
           kind == PXResolvedContainerKindPluginKitData;
}

static BOOL PXResolverRootIsValid(PXResolvedContainerRoot root) {
    return root == PXResolvedContainerRootRootful ||
           root == PXResolvedContainerRootRootless;
}

static NSString *PXResolverBasePath(PXResolvedContainerKind kind,
                                    PXResolvedContainerRoot root) {
    if (!PXResolverKindIsAllowed(kind) || !PXResolverRootIsValid(root)) {
        return nil;
    }

    if (kind == PXResolvedContainerKindPluginKitData) {
        return root == PXResolvedContainerRootRootful
            ? @"/private/var/mobile/Containers/Data/PluginKitPlugin"
            : @"/containers/Data/PluginKitPlugin";
    }

    return root == PXResolvedContainerRootRootful
        ? @"/private/var/mobile/Containers/Data/Application"
        : @"/containers/Data/Application";
}

static void PXResolverAssignError(NSError **error,
                                  PXDataContainerResolverErrorCode code,
                                  NSString *message) {
    if (!error) {
        return;
    }
    *error = [NSError errorWithDomain:PXDataContainerResolverErrorDomain
                                 code:code
                             userInfo:@{NSLocalizedDescriptionKey: message ?: @"Data container resolution failed"}];
}

static BOOL PXResolverImmediateDirectoryIsValid(NSString *path) {
    const char *fileSystemPath = path.fileSystemRepresentation;
    if (!fileSystemPath) {
        return NO;
    }

    struct stat entryStat;
    if (lstat(fileSystemPath, &entryStat) != 0) {
        return NO;
    }
    return S_ISDIR(entryStat.st_mode) && !S_ISLNK(entryStat.st_mode);
}

static BOOL PXResolverMetadataFileIsValid(NSString *path) {
    const char *fileSystemPath = path.fileSystemRepresentation;
    if (!fileSystemPath) {
        return NO;
    }

    struct stat entryStat;
    if (lstat(fileSystemPath, &entryStat) != 0) {
        return NO;
    }
    return S_ISREG(entryStat.st_mode) && !S_ISLNK(entryStat.st_mode);
}

@implementation PXDataContainerResolver

- (PXResolvedContainer *)resolveDataContainerForIdentifier:(NSString *)identifier
                                                       kind:(PXResolvedContainerKind)kind
                                                       root:(PXResolvedContainerRoot)root
                                                      error:(NSError **)error {
    if (error) {
        *error = nil;
    }

    if (!PXResolverIdentifierIsValid(identifier) ||
        !PXResolverKindIsAllowed(kind) ||
        !PXResolverRootIsValid(root)) {
        PXResolverAssignError(error,
                              PXDataContainerResolverErrorInvalidInput,
                              @"Invalid data container resolution request");
        return nil;
    }

    NSString *basePath = PXResolverBasePath(kind, root);
    if (basePath.length == 0) {
        PXResolverAssignError(error,
                              PXDataContainerResolverErrorInvalidInput,
                              @"Invalid data container resolution request");
        return nil;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL baseIsDirectory = NO;
    if (![fileManager fileExistsAtPath:basePath isDirectory:&baseIsDirectory]) {
        return nil;
    }
    if (!baseIsDirectory) {
        PXResolverAssignError(error,
                              PXDataContainerResolverErrorEnumerationFailed,
                              @"Data container root is not a directory");
        return nil;
    }

    NSError *enumerationError = nil;
    NSArray<NSString *> *entries = [fileManager contentsOfDirectoryAtPath:basePath
                                                                     error:&enumerationError];
    if (![entries isKindOfClass:[NSArray class]] || enumerationError) {
        PXResolverAssignError(error,
                              PXDataContainerResolverErrorEnumerationFailed,
                              @"Data container root enumeration failed");
        return nil;
    }

    entries = [entries sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray<PXResolvedContainer *> *matches = [NSMutableArray array];

    for (NSString *entry in entries) {
        if (![entry isKindOfClass:[NSString class]] || entry.length == 0 ||
            [entry characterAtIndex:0] == (unichar)'.' ||
            [[NSUUID alloc] initWithUUIDString:entry] == nil) {
            continue;
        }

        NSString *containerPath = [basePath stringByAppendingPathComponent:entry];
        if (!PXResolverImmediateDirectoryIsValid(containerPath)) {
            continue;
        }

        NSString *metadataPath = [containerPath stringByAppendingPathComponent:
                                  @".com.apple.mobile_container_manager.metadata.plist"];
        if (!PXResolverMetadataFileIsValid(metadataPath)) {
            continue;
        }

        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        if (![metadata isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        id metadataIdentifier = metadata[@"MCMMetadataIdentifier"];
        if (![metadataIdentifier isKindOfClass:[NSString class]] ||
            ![(NSString *)metadataIdentifier isEqualToString:identifier]) {
            continue;
        }

        PXResolvedContainer *candidate = [[PXResolvedContainer alloc] initWithKind:kind
                                                                              root:root
                                                               requestedIdentifier:identifier
                                                                metadataIdentifier:(NSString *)metadataIdentifier
                                                                     containerUUID:entry
                                                                     containerPath:containerPath];
        if (!candidate) {
            PXResolverAssignError(error,
                                  PXDataContainerResolverErrorInvalidCandidate,
                                  @"Exact data container match could not be represented safely");
            return nil;
        }
        [matches addObject:candidate];
    }

    if (matches.count == 0) {
        return nil;
    }
    if (matches.count > 1) {
        PXResolverAssignError(error,
                              PXDataContainerResolverErrorAmbiguousMatch,
                              @"Multiple exact data container matches were found");
        return nil;
    }
    return matches.firstObject;
}

- (PXResolvedContainer *)resolveApplicationDataContainerForIdentifier:(NSString *)identifier
                                                                  root:(PXResolvedContainerRoot)root
                                                                 error:(NSError **)error {
    return [self resolveDataContainerForIdentifier:identifier
                                              kind:PXResolvedContainerKindApplicationData
                                              root:root
                                             error:error];
}

@end
