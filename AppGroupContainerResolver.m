#import "AppGroupContainerResolver.h"

#import <sys/stat.h>

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
    if (!groupIDs.count) {
        return @[];
    }

    NSSet<NSString *> *wanted = [NSSet setWithArray:groupIDs];
    NSMutableArray<AppGroupContainerInfo *> *results = [NSMutableArray array];

    // Prefer canonical rootful paths to avoid duplicate results (/var is typically a symlink to /private/var).
    NSArray<NSString *> *baseDirs = @[
        @"/private/var/mobile/Containers/Shared/AppGroup",
        @"/containers/Shared/AppGroup"
    ];

    NSMutableSet<NSString *> *seen = [NSMutableSet set];

    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *base in baseDirs) {
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:base isDirectory:&isDir] || !isDir) {
            continue;
        }

        NSArray<NSString *> *uuids = [fm contentsOfDirectoryAtPath:base error:nil];
        for (NSString *uuid in uuids) {
            if ([uuid hasPrefix:@"."]) {
                continue;
            }

            NSString *containerPath = [base stringByAppendingPathComponent:uuid];
            NSString *metadataPath = [containerPath stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
            NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
            if (![metadata isKindOfClass:[NSDictionary class]]) {
                continue;
            }

            id ident = metadata[@"MCMMetadataIdentifier"];
            if ([ident isKindOfClass:[NSString class]]) {
                NSString *gid = (NSString *)ident;
                if ([wanted containsObject:gid]) {
                    NSString *key = [NSString stringWithFormat:@"%@|%@", uuid, gid];
                    if ([seen containsObject:key]) {
                        continue;
                    }
                    [seen addObject:key];
                    AppGroupContainerInfo *info = [[AppGroupContainerInfo alloc] init];
                    info.groupID = gid;
                    info.uuid = uuid;
                    info.path = containerPath;
                    [results addObject:info];
                }
            } else if ([ident isKindOfClass:[NSArray class]]) {
                for (id g in (NSArray *)ident) {
                    if ([g isKindOfClass:[NSString class]] && [wanted containsObject:(NSString *)g]) {
                        NSString *gid = (NSString *)g;
                        NSString *key = [NSString stringWithFormat:@"%@|%@", uuid, gid];
                        if ([seen containsObject:key]) {
                            break;
                        }
                        [seen addObject:key];
                        AppGroupContainerInfo *info = [[AppGroupContainerInfo alloc] init];
                        info.groupID = gid;
                        info.uuid = uuid;
                        info.path = containerPath;
                        [results addObject:info];
                        break;
                    }
                }
            }
        }
    }

    return results;
}

@end
