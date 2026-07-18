#import "PXDestructivePathValidator.h"

#include <errno.h>
#include <limits.h>
#include <pwd.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

NSString * const PXDestructivePathValidatorErrorDomain = @"PXDestructivePathValidatorErrorDomain";

static NSString * const PXRootfulApplicationDataBase = @"/private/var/mobile/Containers/Data/Application";
static NSString * const PXRootlessApplicationDataBase = @"/containers/Data/Application";
static NSString * const PXRootfulAppGroupBase = @"/private/var/mobile/Containers/Shared/AppGroup";
static NSString * const PXRootlessAppGroupBase = @"/containers/Shared/AppGroup";
static NSString * const PXRootfulPluginKitDataBase = @"/private/var/mobile/Containers/Data/PluginKitPlugin";
static NSString * const PXRootlessPluginKitDataBase = @"/containers/Data/PluginKitPlugin";
static NSString * const PXContainerMetadataFilename = @".com.apple.mobile_container_manager.metadata.plist";
static NSString * const PXContainerMetadataIdentifierKey = @"MCMMetadataIdentifier";

static void PXSetDestructivePathValidatorError(NSError * _Nullable * _Nullable error,
                                               PXDestructivePathValidatorErrorCode code,
                                               NSString *description,
                                               int posixError) {
    if (error == NULL) {
        return;
    }

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:description
                                                                        forKey:NSLocalizedDescriptionKey];
    if (posixError != 0) {
        userInfo[NSUnderlyingErrorKey] = [NSError errorWithDomain:NSPOSIXErrorDomain
                                                             code:posixError
                                                         userInfo:nil];
    }
    *error = [NSError errorWithDomain:PXDestructivePathValidatorErrorDomain
                                 code:code
                             userInfo:userInfo];
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

static BOOL PXIdentifierIsValid(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }

    NSString *identifier = (NSString *)value;
    return identifier.length > 0 &&
           PXStringContainsNonWhitespace(identifier) &&
           !PXStringContainsNUL(identifier);
}

static BOOL PXContainerKindIsValid(PXResolvedContainerKind kind) {
    switch (kind) {
        case PXResolvedContainerKindApplicationData:
        case PXResolvedContainerKindAppGroup:
        case PXResolvedContainerKindExtensionData:
        case PXResolvedContainerKindPluginKitData:
            return YES;
    }
    return NO;
}

static BOOL PXContainerRootIsValid(PXResolvedContainerRoot root) {
    return root == PXResolvedContainerRootRootful ||
           root == PXResolvedContainerRootRootless;
}

static NSString *PXAllowedBaseForKindAndRoot(PXResolvedContainerKind kind,
                                             PXResolvedContainerRoot root) {
    switch (kind) {
        case PXResolvedContainerKindApplicationData:
        case PXResolvedContainerKindExtensionData:
            return root == PXResolvedContainerRootRootful
                ? PXRootfulApplicationDataBase
                : PXRootlessApplicationDataBase;
        case PXResolvedContainerKindAppGroup:
            return root == PXResolvedContainerRootRootful
                ? PXRootfulAppGroupBase
                : PXRootlessAppGroupBase;
        case PXResolvedContainerKindPluginKitData:
            return root == PXResolvedContainerRootRootful
                ? PXRootfulPluginKitDataBase
                : PXRootlessPluginKitDataBase;
    }
    return nil;
}

static BOOL PXContainerPathIsLexicallyValid(NSString *containerPath,
                                            NSString *containerUUID) {
    if (containerPath.length == 0 ||
        [containerPath characterAtIndex:0] != (unichar)'/' ||
        [containerPath isEqualToString:@"/"] ||
        [containerPath characterAtIndex:(containerPath.length - 1)] == (unichar)'/' ||
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

static BOOL PXCanonicalPathIsAbsoluteNonRoot(NSString *path) {
    return path.length > 1 &&
           [path characterAtIndex:0] == (unichar)'/' &&
           [path characterAtIndex:(path.length - 1)] != (unichar)'/';
}

static NSString *PXStringFromCanonicalBuffer(const char *buffer) {
    if (buffer == NULL) {
        return nil;
    }
    return [[NSString alloc] initWithBytes:buffer
                                    length:strlen(buffer)
                                  encoding:NSUTF8StringEncoding];
}

static BOOL PXStatIdentityMatches(const struct stat *left,
                                  const struct stat *right) {
    return left->st_dev == right->st_dev && left->st_ino == right->st_ino;
}

static BOOL PXModeIsWorldWritable(mode_t mode) {
    return (mode & S_IWOTH) != 0;
}

static BOOL PXContainerOwnerIsAuthorized(uid_t owner,
                                         uid_t mobileUserID,
                                         PXResolvedContainerRoot root) {
    if (owner == mobileUserID) {
        return YES;
    }
    return root == PXResolvedContainerRootRootful && owner == 0;
}

static BOOL PXResolveMobileUserID(uid_t *mobileUserID, int *lookupError) {
    struct passwd passwordEntry;
    struct passwd *result = NULL;
    char lookupBuffer[16384];
    int status = getpwnam_r("mobile",
                            &passwordEntry,
                            lookupBuffer,
                            sizeof(lookupBuffer),
                            &result);
    if (status != 0 || result == NULL) {
        if (lookupError != NULL) {
            *lookupError = status != 0 ? status : ENOENT;
        }
        return NO;
    }

    if (mobileUserID != NULL) {
        *mobileUserID = result->pw_uid;
    }
    if (lookupError != NULL) {
        *lookupError = 0;
    }
    return YES;
}

@implementation PXDestructivePathValidator

- (nullable NSString *)validatedCanonicalPathForContainer:(PXResolvedContainer *)container
                                                    error:(NSError * _Nullable * _Nullable)error {
    if (error != NULL) {
        *error = nil;
    }

    if (![container isKindOfClass:[PXResolvedContainer class]]) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorInvalidInput,
                                           @"The resolved container input is invalid.",
                                           0);
        return nil;
    }

    id requestedIdentifierObject = container.requestedIdentifier;
    id metadataIdentifierObject = container.metadataIdentifier;
    id containerUUIDObject = container.containerUUID;
    id containerPathObject = container.containerPath;

    if (!PXContainerKindIsValid(container.kind) ||
        !PXContainerRootIsValid(container.root) ||
        !PXIdentifierIsValid(requestedIdentifierObject) ||
        !PXIdentifierIsValid(metadataIdentifierObject) ||
        ![containerUUIDObject isKindOfClass:[NSString class]] ||
        ![containerPathObject isKindOfClass:[NSString class]]) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorInvalidInput,
                                           @"The resolved container fields are invalid.",
                                           0);
        return nil;
    }

    NSString *requestedIdentifier = (NSString *)requestedIdentifierObject;
    NSString *metadataIdentifier = (NSString *)metadataIdentifierObject;
    NSString *containerUUID = (NSString *)containerUUIDObject;
    NSString *containerPath = (NSString *)containerPathObject;

    if (containerUUID.length == 0 ||
        containerPath.length == 0 ||
        PXStringContainsNUL(containerUUID) ||
        PXStringContainsNUL(containerPath) ||
        ![requestedIdentifier isEqualToString:metadataIdentifier] ||
        [containerUUID rangeOfString:@"/"].location != NSNotFound ||
        [containerUUID isEqualToString:@"."] ||
        [containerUUID isEqualToString:@".."] ||
        [[NSUUID alloc] initWithUUIDString:containerUUID] == nil ||
        !PXContainerPathIsLexicallyValid(containerPath, containerUUID)) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorInvalidInput,
                                           @"The resolved container invariants are invalid.",
                                           0);
        return nil;
    }

    NSString *allowedBase = PXAllowedBaseForKindAndRoot(container.kind, container.root);
    if (allowedBase == nil) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorInvalidInput,
                                           @"The resolved container kind and root are not allowed.",
                                           0);
        return nil;
    }

    NSString *expectedRawPath = [allowedBase stringByAppendingPathComponent:containerUUID];
    if (![containerPath isEqualToString:expectedRawPath]) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorCandidatePathMismatch,
                                           @"The candidate path does not match the fixed base and UUID.",
                                           0);
        return nil;
    }

    NSString *rawCandidatePath = [containerPath copy];
    struct stat initialCandidateStatus;
    const char *rawCandidateFileSystemPath = [rawCandidatePath fileSystemRepresentation];
    if (rawCandidateFileSystemPath == NULL) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemInspectionFailed,
                                           @"The candidate path cannot be represented for filesystem inspection.",
                                           EINVAL);
        return nil;
    }
    errno = 0;
    if (lstat(rawCandidateFileSystemPath, &initialCandidateStatus) != 0) {
        int capturedError = errno;
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemInspectionFailed,
                                           @"The candidate path cannot be inspected.",
                                           capturedError);
        return nil;
    }
    if (S_ISLNK(initialCandidateStatus.st_mode)) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorSymlinkRejected,
                                           @"The candidate path is a symbolic link.",
                                           0);
        return nil;
    }
    if (!S_ISDIR(initialCandidateStatus.st_mode)) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemInspectionFailed,
                                           @"The candidate path is not a directory.",
                                           0);
        return nil;
    }

    char canonicalBaseBuffer[PATH_MAX];
    const char *allowedBaseFileSystemPath = [allowedBase fileSystemRepresentation];
    if (allowedBaseFileSystemPath == NULL) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemInspectionFailed,
                                           @"The allowed base cannot be represented for filesystem inspection.",
                                           EINVAL);
        return nil;
    }
    errno = 0;
    if (realpath(allowedBaseFileSystemPath, canonicalBaseBuffer) == NULL) {
        int capturedError = errno;
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorCanonicalizationFailed,
                                           @"The allowed base cannot be canonicalized.",
                                           capturedError);
        return nil;
    }
    NSString *canonicalBase = PXStringFromCanonicalBuffer(canonicalBaseBuffer);
    if (canonicalBase == nil) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorCanonicalizationFailed,
                                           @"The canonical allowed base is not a valid filesystem string.",
                                           0);
        return nil;
    }

    char canonicalCandidateBuffer[PATH_MAX];
    rawCandidateFileSystemPath = [rawCandidatePath fileSystemRepresentation];
    if (rawCandidateFileSystemPath == NULL) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemInspectionFailed,
                                           @"The candidate path cannot be represented for canonicalization.",
                                           EINVAL);
        return nil;
    }
    errno = 0;
    if (realpath(rawCandidateFileSystemPath, canonicalCandidateBuffer) == NULL) {
        int capturedError = errno;
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorCanonicalizationFailed,
                                           @"The candidate path cannot be canonicalized.",
                                           capturedError);
        return nil;
    }
    NSString *canonicalCandidate = PXStringFromCanonicalBuffer(canonicalCandidateBuffer);
    if (canonicalCandidate == nil) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorCanonicalizationFailed,
                                           @"The canonical candidate is not a valid filesystem string.",
                                           0);
        return nil;
    }

    NSString *canonicalCandidateParent = [canonicalCandidate stringByDeletingLastPathComponent];
    if (!PXCanonicalPathIsAbsoluteNonRoot(canonicalBase) ||
        !PXCanonicalPathIsAbsoluteNonRoot(canonicalCandidate) ||
        [canonicalCandidate isEqualToString:canonicalBase] ||
        ![[canonicalCandidate lastPathComponent] isEqualToString:containerUUID] ||
        ![canonicalCandidateParent isEqualToString:canonicalBase]) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorCanonicalBaseViolation,
                                           @"The canonical candidate is not one immediate child of the allowed base.",
                                           0);
        return nil;
    }

    struct stat canonicalBaseStatus;
    const char *canonicalBaseFileSystemPath = [canonicalBase fileSystemRepresentation];
    if (canonicalBaseFileSystemPath == NULL) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemInspectionFailed,
                                           @"The canonical base cannot be represented for filesystem inspection.",
                                           EINVAL);
        return nil;
    }
    errno = 0;
    if (stat(canonicalBaseFileSystemPath, &canonicalBaseStatus) != 0) {
        int capturedError = errno;
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemInspectionFailed,
                                           @"The canonical base cannot be inspected.",
                                           capturedError);
        return nil;
    }
    if (!S_ISDIR(canonicalBaseStatus.st_mode)) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemInspectionFailed,
                                           @"The canonical base is not a directory.",
                                           0);
        return nil;
    }

    struct stat canonicalCandidateStatus;
    const char *canonicalCandidateFileSystemPath = [canonicalCandidate fileSystemRepresentation];
    if (canonicalCandidateFileSystemPath == NULL) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemInspectionFailed,
                                           @"The canonical candidate cannot be represented for filesystem inspection.",
                                           EINVAL);
        return nil;
    }
    errno = 0;
    if (stat(canonicalCandidateFileSystemPath, &canonicalCandidateStatus) != 0) {
        int capturedError = errno;
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemInspectionFailed,
                                           @"The canonical candidate cannot be inspected.",
                                           capturedError);
        return nil;
    }
    if (!S_ISDIR(canonicalCandidateStatus.st_mode)) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemInspectionFailed,
                                           @"The canonical candidate is not a directory.",
                                           0);
        return nil;
    }
    if (!PXStatIdentityMatches(&initialCandidateStatus, &canonicalCandidateStatus)) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemChanged,
                                           @"The candidate filesystem identity changed during validation.",
                                           0);
        return nil;
    }
    if (canonicalCandidateStatus.st_dev != canonicalBaseStatus.st_dev) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorCrossDeviceBoundary,
                                           @"The candidate crosses the allowed filesystem device boundary.",
                                           0);
        return nil;
    }

    uid_t mobileUserID = 0;
    int mobileLookupError = 0;
    if (!PXResolveMobileUserID(&mobileUserID, &mobileLookupError)) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemInspectionFailed,
                                           @"The mobile user account cannot be resolved.",
                                           mobileLookupError);
        return nil;
    }

    if (!PXContainerOwnerIsAuthorized(canonicalCandidateStatus.st_uid,
                                       mobileUserID,
                                       container.root)) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorOwnershipOrModeViolation,
                                           @"The candidate owner is not authorized for this container root.",
                                           0);
        return nil;
    }
    if (PXModeIsWorldWritable(canonicalCandidateStatus.st_mode)) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorOwnershipOrModeViolation,
                                           @"The candidate directory is world-writable.",
                                           0);
        return nil;
    }
    if (PXModeIsWorldWritable(canonicalBaseStatus.st_mode)) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorOwnershipOrModeViolation,
                                           @"The allowed base directory is world-writable.",
                                           0);
        return nil;
    }

    NSString *metadataPath = [canonicalCandidate stringByAppendingPathComponent:PXContainerMetadataFilename];
    struct stat initialMetadataStatus;
    const char *metadataFileSystemPath = [metadataPath fileSystemRepresentation];
    if (metadataFileSystemPath == NULL) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemInspectionFailed,
                                           @"The metadata path cannot be represented for filesystem inspection.",
                                           EINVAL);
        return nil;
    }
    errno = 0;
    if (lstat(metadataFileSystemPath, &initialMetadataStatus) != 0) {
        int capturedError = errno;
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorMetadataInvalid,
                                           @"The container metadata file is missing or cannot be inspected.",
                                           capturedError);
        return nil;
    }
    if (S_ISLNK(initialMetadataStatus.st_mode)) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorSymlinkRejected,
                                           @"The container metadata file is a symbolic link.",
                                           0);
        return nil;
    }
    if (!S_ISREG(initialMetadataStatus.st_mode)) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorMetadataInvalid,
                                           @"The container metadata object is not a regular file.",
                                           0);
        return nil;
    }
    if (initialMetadataStatus.st_dev != canonicalCandidateStatus.st_dev) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorCrossDeviceBoundary,
                                           @"The container metadata crosses the candidate filesystem device boundary.",
                                           0);
        return nil;
    }
    if (!PXContainerOwnerIsAuthorized(initialMetadataStatus.st_uid,
                                       mobileUserID,
                                       container.root)) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorOwnershipOrModeViolation,
                                           @"The container metadata owner is not authorized for this container root.",
                                           0);
        return nil;
    }
    if (PXModeIsWorldWritable(initialMetadataStatus.st_mode)) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorOwnershipOrModeViolation,
                                           @"The container metadata file is world-writable.",
                                           0);
        return nil;
    }

    char canonicalMetadataBuffer[PATH_MAX];
    metadataFileSystemPath = [metadataPath fileSystemRepresentation];
    if (metadataFileSystemPath == NULL) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemInspectionFailed,
                                           @"The metadata path cannot be represented for canonicalization.",
                                           EINVAL);
        return nil;
    }
    errno = 0;
    if (realpath(metadataFileSystemPath, canonicalMetadataBuffer) == NULL) {
        int capturedError = errno;
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorCanonicalizationFailed,
                                           @"The container metadata path cannot be canonicalized.",
                                           capturedError);
        return nil;
    }
    NSString *canonicalMetadataPath = PXStringFromCanonicalBuffer(canonicalMetadataBuffer);
    if (canonicalMetadataPath == nil) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorCanonicalizationFailed,
                                           @"The canonical metadata path is not a valid filesystem string.",
                                           0);
        return nil;
    }

    NSString *canonicalMetadataParent = [canonicalMetadataPath stringByDeletingLastPathComponent];
    if (![[canonicalMetadataPath lastPathComponent] isEqualToString:PXContainerMetadataFilename] ||
        ![canonicalMetadataParent isEqualToString:canonicalCandidate]) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorCanonicalBaseViolation,
                                           @"The canonical metadata path escapes the validated candidate.",
                                           0);
        return nil;
    }

    id metadataObject = [NSDictionary dictionaryWithContentsOfFile:canonicalMetadataPath];
    if (![metadataObject isKindOfClass:[NSDictionary class]]) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorMetadataInvalid,
                                           @"The container metadata property list is invalid.",
                                           0);
        return nil;
    }

    id liveIdentifier = [(NSDictionary *)metadataObject objectForKey:PXContainerMetadataIdentifierKey];
    if (container.kind == PXResolvedContainerKindAppGroup) {
        if ([liveIdentifier isKindOfClass:[NSString class]]) {
            if (!PXIdentifierIsValid(liveIdentifier)) {
                PXSetDestructivePathValidatorError(error,
                                                   PXDestructivePathValidatorErrorMetadataInvalid,
                                                   @"The App Group metadata identifier is invalid.",
                                                   0);
                return nil;
            }
            NSString *liveString = (NSString *)liveIdentifier;
            if (![liveString isEqualToString:requestedIdentifier] ||
                ![liveString isEqualToString:metadataIdentifier]) {
                PXSetDestructivePathValidatorError(error,
                                                   PXDestructivePathValidatorErrorIdentityMismatch,
                                                   @"The live App Group metadata identity does not match the model.",
                                                   0);
                return nil;
            }
        } else if ([liveIdentifier isKindOfClass:[NSArray class]]) {
            NSUInteger exactOccurrenceCount = 0;
            NSString *exactMatchedIdentifier = nil;
            for (id element in (NSArray *)liveIdentifier) {
                if (![element isKindOfClass:[NSString class]]) {
                    continue;
                }
                NSString *elementString = (NSString *)element;
                if ([elementString isEqualToString:requestedIdentifier]) {
                    exactOccurrenceCount++;
                    exactMatchedIdentifier = elementString;
                }
            }
            if (exactOccurrenceCount == 0) {
                PXSetDestructivePathValidatorError(error,
                                                   PXDestructivePathValidatorErrorIdentityMismatch,
                                                   @"The live App Group metadata does not contain the exact model identity.",
                                                   0);
                return nil;
            }
            if (exactOccurrenceCount > 1) {
                PXSetDestructivePathValidatorError(error,
                                                   PXDestructivePathValidatorErrorMetadataInvalid,
                                                   @"The live App Group metadata contains duplicate exact identities.",
                                                   0);
                return nil;
            }
            if (![exactMatchedIdentifier isEqualToString:metadataIdentifier]) {
                PXSetDestructivePathValidatorError(error,
                                                   PXDestructivePathValidatorErrorIdentityMismatch,
                                                   @"The live App Group metadata identity does not match the model.",
                                                   0);
                return nil;
            }
        } else {
            PXSetDestructivePathValidatorError(error,
                                               PXDestructivePathValidatorErrorMetadataInvalid,
                                               @"The App Group metadata identifier has an invalid type.",
                                               0);
            return nil;
        }
    } else {
        if (!PXIdentifierIsValid(liveIdentifier)) {
            PXSetDestructivePathValidatorError(error,
                                               PXDestructivePathValidatorErrorMetadataInvalid,
                                               @"The container metadata identifier is invalid.",
                                               0);
            return nil;
        }
        NSString *liveString = (NSString *)liveIdentifier;
        if (![liveString isEqualToString:requestedIdentifier] ||
            ![liveString isEqualToString:metadataIdentifier]) {
            PXSetDestructivePathValidatorError(error,
                                               PXDestructivePathValidatorErrorIdentityMismatch,
                                               @"The live container metadata identity does not match the model.",
                                               0);
            return nil;
        }
    }

    struct stat finalCandidateStatus;
    rawCandidateFileSystemPath = [rawCandidatePath fileSystemRepresentation];
    if (rawCandidateFileSystemPath == NULL) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemInspectionFailed,
                                           @"The candidate path cannot be represented for final filesystem inspection.",
                                           EINVAL);
        return nil;
    }
    errno = 0;
    if (lstat(rawCandidateFileSystemPath, &finalCandidateStatus) != 0) {
        int capturedError = errno;
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemChanged,
                                           @"The candidate changed before validation completed.",
                                           capturedError);
        return nil;
    }
    if (S_ISLNK(finalCandidateStatus.st_mode) ||
        !S_ISDIR(finalCandidateStatus.st_mode) ||
        !PXStatIdentityMatches(&initialCandidateStatus, &finalCandidateStatus)) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemChanged,
                                           @"The candidate changed before validation completed.",
                                           0);
        return nil;
    }

    struct stat finalMetadataStatus;
    const char *canonicalMetadataFileSystemPath = [canonicalMetadataPath fileSystemRepresentation];
    if (canonicalMetadataFileSystemPath == NULL) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemInspectionFailed,
                                           @"The metadata path cannot be represented for final filesystem inspection.",
                                           EINVAL);
        return nil;
    }
    errno = 0;
    if (lstat(canonicalMetadataFileSystemPath, &finalMetadataStatus) != 0) {
        int capturedError = errno;
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemChanged,
                                           @"The metadata file changed before validation completed.",
                                           capturedError);
        return nil;
    }
    if (S_ISLNK(finalMetadataStatus.st_mode) ||
        !S_ISREG(finalMetadataStatus.st_mode) ||
        !PXStatIdentityMatches(&initialMetadataStatus, &finalMetadataStatus)) {
        PXSetDestructivePathValidatorError(error,
                                           PXDestructivePathValidatorErrorFilesystemChanged,
                                           @"The metadata file changed before validation completed.",
                                           0);
        return nil;
    }

    return [[NSString alloc] initWithString:canonicalCandidate];
}

@end
