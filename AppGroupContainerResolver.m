#import "AppGroupContainerResolver.h"

#import <sys/stat.h>
#import <objc/message.h>

NSString * const PXAppGroupContainerResolverErrorDomain = @"PXAppGroupContainerResolver";

static BOOL PXAppGroupResolverStringContainsNUL(NSString *value) {
    unichar nulCharacter = 0;
    NSString *nulString =
        [NSString stringWithCharacters:&nulCharacter length:1];
    return [value rangeOfString:nulString].location != NSNotFound;
}

static BOOL PXAppGroupResolverStringContainsNonWhitespace(NSString *value) {
    NSCharacterSet *whitespace =
        [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return [value rangeOfCharacterFromSet:[whitespace invertedSet]].location
        != NSNotFound;
}

static BOOL PXAppGroupResolverIdentifierIsValid(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }

    NSString *identifier = (NSString *)value;
    return identifier.length > 0 &&
           PXAppGroupResolverStringContainsNonWhitespace(identifier) &&
           !PXAppGroupResolverStringContainsNUL(identifier);
}

static BOOL PXAppGroupResolverRootIsValid(PXResolvedContainerRoot root) {
    return root == PXResolvedContainerRootRootful ||
           root == PXResolvedContainerRootRootless;
}

static NSString *PXAppGroupResolverBaseForRoot(PXResolvedContainerRoot root) {
    if (root == PXResolvedContainerRootRootful) {
        return @"/private/var/mobile/Containers/Shared/AppGroup";
    }
    if (root == PXResolvedContainerRootRootless) {
        return @"/containers/Shared/AppGroup";
    }
    return nil;
}

static void PXAppGroupResolverAssignError(NSError **error,
                                          PXAppGroupContainerResolverErrorCode code,
                                          NSString *message) {
    if (!error) {
        return;
    }
    *error = [NSError errorWithDomain:PXAppGroupContainerResolverErrorDomain
                                 code:code
                             userInfo:@{NSLocalizedDescriptionKey:
                                            message ?: @"App Group container resolution failed"}];
}

static BOOL PXAppGroupResolverRealDirectoryAtPath(NSString *path) {
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

static BOOL PXAppGroupResolverRegularFileAtPath(NSString *path) {
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

typedef NS_ENUM(NSInteger, PXAppGroupMCMResolutionState) {
    PXAppGroupMCMResolutionStateUnavailable = 0,
    PXAppGroupMCMResolutionStateResolved = 1,
    PXAppGroupMCMResolutionStateMissing = 2,
    PXAppGroupMCMResolutionStateFailed = 3,
};

static PXAppGroupMCMResolutionState PXAppGroupResolverRegisteredContainer(NSString *groupIdentifier,
                                                                          NSString **containerPathOut,
                                                                          NSString **containerUUIDOut,
                                                                          NSError **queryErrorOut) {
    if (containerPathOut) *containerPathOut = nil;
    if (containerUUIDOut) *containerUUIDOut = nil;
    if (queryErrorOut) *queryErrorOut = nil;

    static Class sharedDataContainerClass = Nil;
    static SEL noCreateSelector = NULL;
    static SEL simpleSelector = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *framework = [NSBundle bundleWithPath:
            @"/System/Library/PrivateFrameworks/MobileContainerManager.framework"];
        Class candidateClass = NSClassFromString(@"MCMSharedDataContainer");
        if (!candidateClass && framework) {
            (void)([framework isLoaded] || [framework load]);
            candidateClass = NSClassFromString(@"MCMSharedDataContainer");
        }
        SEL candidateNoCreateSelector = NSSelectorFromString(@"containerWithIdentifier:createIfNecessary:existed:error:");
        SEL candidateSimpleSelector = NSSelectorFromString(@"containerWithIdentifier:error:");
        if (candidateClass && [candidateClass respondsToSelector:candidateNoCreateSelector]) {
            sharedDataContainerClass = candidateClass;
            noCreateSelector = candidateNoCreateSelector;
        } else if (candidateClass && [candidateClass respondsToSelector:candidateSimpleSelector]) {
            sharedDataContainerClass = candidateClass;
            simpleSelector = candidateSimpleSelector;
        }
    });

    if (!sharedDataContainerClass || (!noCreateSelector && !simpleSelector)) {
        return PXAppGroupMCMResolutionStateUnavailable;
    }

    NSError *queryError = nil;
    id container = nil;
    if (noCreateSelector) {
        id (*sendNoCreate)(id, SEL, id, BOOL, BOOL *, NSError **) =
            (id (*)(id, SEL, id, BOOL, BOOL *, NSError **))objc_msgSend;
        container = sendNoCreate((id)sharedDataContainerClass,
                                 noCreateSelector,
                                 groupIdentifier,
                                 NO,
                                 NULL,
                                 &queryError);
    } else {
        id (*sendSimple)(id, SEL, id, NSError **) =
            (id (*)(id, SEL, id, NSError **))objc_msgSend;
        container = sendSimple((id)sharedDataContainerClass,
                               simpleSelector,
                               groupIdentifier,
                               &queryError);
    }

    if (!container) {
        if (queryError) {
            if (queryErrorOut) *queryErrorOut = queryError;
            return PXAppGroupMCMResolutionStateFailed;
        }
        return PXAppGroupMCMResolutionStateMissing;
    }

    SEL urlSelector = NSSelectorFromString(@"url");
    SEL uuidSelector = NSSelectorFromString(@"uuid");
    if (![container respondsToSelector:urlSelector] || ![container respondsToSelector:uuidSelector]) {
        return PXAppGroupMCMResolutionStateFailed;
    }

    id (*sendObject)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
    id urlObject = sendObject(container, urlSelector);
    id uuidObject = sendObject(container, uuidSelector);
    NSString *path = [urlObject isKindOfClass:[NSURL class]] ? [(NSURL *)urlObject path] : nil;
    NSString *uuidString = [uuidObject isKindOfClass:[NSUUID class]]
        ? [(NSUUID *)uuidObject UUIDString]
        : ([uuidObject isKindOfClass:[NSString class]] ? (NSString *)uuidObject : nil);
    if (![path isKindOfClass:[NSString class]] || path.length == 0 ||
        ![path hasPrefix:@"/"] ||
        ![uuidString isKindOfClass:[NSString class]] ||
        [[NSUUID alloc] initWithUUIDString:uuidString] == nil) {
        return PXAppGroupMCMResolutionStateFailed;
    }

    NSString *canonicalPath = [path stringByResolvingSymlinksInPath];
    if (![canonicalPath isKindOfClass:[NSString class]] || canonicalPath.length == 0 ||
        ![canonicalPath hasPrefix:@"/"]) {
        return PXAppGroupMCMResolutionStateFailed;
    }

    if (containerPathOut) *containerPathOut = [canonicalPath copy];
    if (containerUUIDOut) *containerUUIDOut = [uuidString copy];
    return PXAppGroupMCMResolutionStateResolved;
}

static BOOL PXAppGroupResolverMetadataMatchesIdentifier(NSString *containerPath,
                                                         NSString *groupIdentifier,
                                                         BOOL *metadataMalformed) {
    if (metadataMalformed) *metadataMalformed = NO;
    NSString *metadataPath = [containerPath stringByAppendingPathComponent:
                              @".com.apple.mobile_container_manager.metadata.plist"];
    if (!PXAppGroupResolverRegularFileAtPath(metadataPath)) {
        return NO;
    }
    NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
    if (![metadata isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    id metadataIdentifier = metadata[@"MCMMetadataIdentifier"];
    if ([metadataIdentifier isKindOfClass:[NSString class]]) {
        NSString *metadataString = (NSString *)metadataIdentifier;
        return PXAppGroupResolverIdentifierIsValid(metadataString) &&
               [metadataString isEqualToString:groupIdentifier];
    }
    if ([metadataIdentifier isKindOfClass:[NSArray class]]) {
        NSUInteger exactOccurrenceCount = 0;
        for (id element in (NSArray *)metadataIdentifier) {
            if ([element isKindOfClass:[NSString class]] &&
                [(NSString *)element isEqualToString:groupIdentifier]) {
                exactOccurrenceCount++;
            }
        }
        if (exactOccurrenceCount > 1) {
            if (metadataMalformed) *metadataMalformed = YES;
            return NO;
        }
        return exactOccurrenceCount == 1;
    }
    return NO;
}

@implementation AppGroupContainerInfo
@end

@implementation AppGroupContainerResolver

- (NSArray<PXResolvedContainer *> *)resolveAllAppGroupContainersForGroupIdentifier:(NSString *)groupIdentifier
                                                                               root:(PXResolvedContainerRoot)root
                                                                              error:(NSError **)error {
    if (error) {
        *error = nil;
    }

    if (!PXAppGroupResolverIdentifierIsValid(groupIdentifier) ||
        !PXAppGroupResolverRootIsValid(root)) {
        PXAppGroupResolverAssignError(error,
                                      PXAppGroupContainerResolverErrorInvalidInput,
                                      @"Invalid App Group container resolution request");
        return nil;
    }

    NSString *basePath = PXAppGroupResolverBaseForRoot(root);

    NSString *registeredPath = nil;
    NSString *registeredUUID = nil;
    NSError *mcmQueryError = nil;
    PXAppGroupMCMResolutionState mcmState =
        PXAppGroupResolverRegisteredContainer(groupIdentifier,
                                              &registeredPath,
                                              &registeredUUID,
                                              &mcmQueryError);
    if (mcmState == PXAppGroupMCMResolutionStateFailed) {
        NSString *detail = mcmQueryError.localizedDescription.length
            ? mcmQueryError.localizedDescription
            : @"MobileContainerManager returned an invalid App Group container";
        PXAppGroupResolverAssignError(error,
                                      PXAppGroupContainerResolverErrorInvalidCandidate,
                                      [NSString stringWithFormat:@"Registered App Group resolution failed: %@", detail]);
        return nil;
    }
    if (mcmState == PXAppGroupMCMResolutionStateMissing) {
        return @[];
    }
    if (mcmState == PXAppGroupMCMResolutionStateResolved) {
        NSArray<NSString *> *allowedPrefixes = root == PXResolvedContainerRootRootful
            ? @[@"/private/var/mobile/Containers/Shared/AppGroup/",
                @"/var/mobile/Containers/Shared/AppGroup/"]
            : @[@"/containers/Shared/AppGroup/"];
        BOOL belongsToRequestedRoot = NO;
        for (NSString *prefix in allowedPrefixes) {
            if ([registeredPath hasPrefix:prefix]) {
                NSString *remainder = [registeredPath substringFromIndex:prefix.length];
                belongsToRequestedRoot = remainder.length > 0 &&
                    [remainder rangeOfString:@"/"].location == NSNotFound;
                if (belongsToRequestedRoot) break;
            }
        }
        if (!belongsToRequestedRoot) {
            return @[];
        }

        NSUUID *pathUUID = [[NSUUID alloc] initWithUUIDString:registeredPath.lastPathComponent];
        NSUUID *mcmUUID = [[NSUUID alloc] initWithUUIDString:registeredUUID];
        BOOL metadataMalformed = NO;
        BOOL metadataMatches = PXAppGroupResolverMetadataMatchesIdentifier(registeredPath,
                                                                           groupIdentifier,
                                                                           &metadataMalformed);
        if (!PXAppGroupResolverRealDirectoryAtPath(registeredPath) ||
            !pathUUID || !mcmUUID || ![pathUUID isEqual:mcmUUID] || !metadataMatches) {
            PXAppGroupResolverAssignError(error,
                                          metadataMalformed
                                              ? PXAppGroupContainerResolverErrorMetadataInvalid
                                              : PXAppGroupContainerResolverErrorInvalidCandidate,
                                          @"Registered App Group container failed exact filesystem validation");
            return nil;
        }

        PXResolvedContainer *registeredCandidate =
            [[PXResolvedContainer alloc] initWithKind:PXResolvedContainerKindAppGroup
                                                 root:root
                                  requestedIdentifier:groupIdentifier
                                   metadataIdentifier:groupIdentifier
                                        containerUUID:registeredPath.lastPathComponent
                                        containerPath:registeredPath];
        if (!registeredCandidate) {
            PXAppGroupResolverAssignError(error,
                                          PXAppGroupContainerResolverErrorInvalidCandidate,
                                          @"Registered App Group container could not be represented safely");
            return nil;
        }
        return @[registeredCandidate];
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL baseIsDirectory = NO;
    if (![fileManager fileExistsAtPath:basePath isDirectory:&baseIsDirectory]) {
        return @[];
    }
    if (!baseIsDirectory) {
        PXAppGroupResolverAssignError(error,
                                      PXAppGroupContainerResolverErrorEnumerationFailed,
                                      @"App Group container root is not a directory");
        return nil;
    }

    NSError *enumerationError = nil;
    NSArray<NSString *> *entries =
        [fileManager contentsOfDirectoryAtPath:basePath error:&enumerationError];
    if (![entries isKindOfClass:[NSArray class]] || enumerationError) {
        PXAppGroupResolverAssignError(error,
                                      PXAppGroupContainerResolverErrorEnumerationFailed,
                                      @"App Group container root enumeration failed");
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
        if (!PXAppGroupResolverRealDirectoryAtPath(containerPath)) {
            continue;
        }

        NSString *metadataPath = [containerPath stringByAppendingPathComponent:
                                  @".com.apple.mobile_container_manager.metadata.plist"];
        if (!PXAppGroupResolverRegularFileAtPath(metadataPath)) {
            continue;
        }

        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        if (![metadata isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        id metadataIdentifier = metadata[@"MCMMetadataIdentifier"];
        BOOL exactMatch = NO;
        if ([metadataIdentifier isKindOfClass:[NSString class]]) {
            NSString *metadataString = (NSString *)metadataIdentifier;
            exactMatch = PXAppGroupResolverIdentifierIsValid(metadataString) &&
                         [metadataString isEqualToString:groupIdentifier];
        } else if ([metadataIdentifier isKindOfClass:[NSArray class]]) {
            NSUInteger exactOccurrenceCount = 0;
            for (id element in (NSArray *)metadataIdentifier) {
                if ([element isKindOfClass:[NSString class]] &&
                    [(NSString *)element isEqualToString:groupIdentifier]) {
                    exactOccurrenceCount++;
                }
            }
            if (exactOccurrenceCount > 1) {
                PXAppGroupResolverAssignError(error,
                                              PXAppGroupContainerResolverErrorMetadataInvalid,
                                              @"App Group metadata contains duplicate exact identities");
                return nil;
            }
            exactMatch = exactOccurrenceCount == 1;
        }

        if (!exactMatch) {
            continue;
        }

        PXResolvedContainer *candidate =
            [[PXResolvedContainer alloc] initWithKind:PXResolvedContainerKindAppGroup
                                                 root:root
                                  requestedIdentifier:groupIdentifier
                                   metadataIdentifier:groupIdentifier
                                        containerUUID:entry
                                        containerPath:containerPath];
        if (!candidate) {
            PXAppGroupResolverAssignError(error,
                                          PXAppGroupContainerResolverErrorInvalidCandidate,
                                          @"Exact App Group match could not be represented safely");
            return nil;
        }
        [matches addObject:candidate];
    }

    return [matches copy];
}

- (PXResolvedContainer *)resolveAppGroupContainerForGroupIdentifier:(NSString *)groupIdentifier
                                                               root:(PXResolvedContainerRoot)root
                                                              error:(NSError **)error {
    NSArray<PXResolvedContainer *> *matches =
        [self resolveAllAppGroupContainersForGroupIdentifier:groupIdentifier
                                                       root:root
                                                      error:error];
    if (!matches || matches.count == 0) {
        return nil;
    }
    if (matches.count > 1) {
        PXAppGroupResolverAssignError(error,
                                      PXAppGroupContainerResolverErrorAmbiguousMatch,
                                      @"Multiple exact App Group container matches were found");
        return nil;
    }
    return matches.firstObject;
}

- (NSArray<AppGroupContainerInfo *> *)resolveGroupContainersForGroupIDs:(NSArray<NSString *> *)groupIDs {
    if (![groupIDs isKindOfClass:[NSArray class]] || groupIDs.count == 0) {
        return @[];
    }

    NSMutableArray<AppGroupContainerInfo *> *results = [NSMutableArray arrayWithCapacity:groupIDs.count];
    NSMutableSet<NSString *> *seenGroupIdentifiers = [NSMutableSet setWithCapacity:groupIDs.count];

    for (id rawGroupIdentifier in groupIDs) {
        if (!PXAppGroupResolverIdentifierIsValid(rawGroupIdentifier)) {
            continue;
        }
        NSString *groupIdentifier = (NSString *)rawGroupIdentifier;
        if ([seenGroupIdentifiers containsObject:groupIdentifier]) {
            continue;
        }
        [seenGroupIdentifiers addObject:[groupIdentifier copy]];

        NSError *rootfulError = nil;
        NSArray<PXResolvedContainer *> *rootfulMatches =
            [self resolveAllAppGroupContainersForGroupIdentifier:groupIdentifier
                                                           root:PXResolvedContainerRootRootful
                                                          error:&rootfulError];
        if (!rootfulMatches || rootfulError) {
            continue;
        }

        NSError *rootlessError = nil;
        NSArray<PXResolvedContainer *> *rootlessMatches =
            [self resolveAllAppGroupContainersForGroupIdentifier:groupIdentifier
                                                           root:PXResolvedContainerRootRootless
                                                          error:&rootlessError];
        if (!rootlessMatches || rootlessError) {
            continue;
        }

        NSMutableArray<PXResolvedContainer *> *physicalMatches = [NSMutableArray arrayWithCapacity:2];
        NSMutableSet<NSString *> *seenPaths = [NSMutableSet setWithCapacity:2];
        for (PXResolvedContainer *candidate in [rootfulMatches arrayByAddingObjectsFromArray:rootlessMatches]) {
            if (![candidate isKindOfClass:[PXResolvedContainer class]] ||
                candidate.containerPath.length == 0 ||
                [seenPaths containsObject:candidate.containerPath]) {
                continue;
            }
            [seenPaths addObject:candidate.containerPath];
            [physicalMatches addObject:candidate];
        }

        // Backup publishes at most one artifact per signed group identity. If MCM is unavailable and the
        // filesystem fallback is ambiguous, skip the optional group rather than guessing a destination.
        if (physicalMatches.count != 1) {
            continue;
        }

        PXResolvedContainer *model = physicalMatches.firstObject;
        AppGroupContainerInfo *info = [[AppGroupContainerInfo alloc] init];
        info.groupID = groupIdentifier;
        info.uuid = model.containerUUID;
        info.path = model.containerPath;
        [results addObject:info];
    }

    return [results copy];
}

@end
