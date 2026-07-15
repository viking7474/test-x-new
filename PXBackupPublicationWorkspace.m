#import "PXBackupPublicationWorkspace.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

NSErrorDomain const PXBackupPublicationWorkspaceErrorDomain =
    @"com.hydra.projectx.backup-publication-workspace";
NSString * const PXBackupPublicationWorkspaceErrorFieldPathKey = @"fieldPath";
NSString * const PXBackupPublicationPartialDirectoryPrefix = @".weaponx-backup-partial-";

static NSString * const PXBackupPublicationBackupRootField = @"$.backupRoot";
static NSString * const PXBackupPublicationBundleIdentifierField = @"$.bundleIdentifier";
static NSString * const PXBackupPublicationBundleDirectoryField = @"$.bundleDirectory";
static NSString * const PXBackupPublicationWorkspaceField = @"$.workspace";

static const NSUInteger PXBackupPublicationMaximumRootBytes = 4096;
static const NSUInteger PXBackupPublicationMaximumComponentBytes = 255;
static const char PXBackupPublicationWorkspaceTemplate[] =
    ".weaponx-backup-partial-XXXXXX";

static void PXBackupPublicationSetError(NSError **error,
                                        PXBackupPublicationWorkspaceErrorCode code,
                                        NSString *fieldPath,
                                        NSString *description) {
    if (!error) {
        return;
    }
    *error = [NSError errorWithDomain:PXBackupPublicationWorkspaceErrorDomain
                                 code:code
                             userInfo:@{
                                 NSLocalizedDescriptionKey: description,
                                 PXBackupPublicationWorkspaceErrorFieldPathKey: fieldPath,
                             }];
}

static BOOL PXBackupPublicationStatIdentityMatches(const struct stat *left,
                                                    const struct stat *right) {
    return left && right &&
           left->st_dev == right->st_dev &&
           left->st_ino == right->st_ino &&
           ((left->st_mode & S_IFMT) == (right->st_mode & S_IFMT));
}

static BOOL PXBackupPublicationDescriptorHasCloseOnExec(int descriptor) {
    if (descriptor < 0) {
        return NO;
    }
    int flags = -1;
    do {
        flags = fcntl(descriptor, F_GETFD);
    } while (flags < 0 && errno == EINTR);
    return flags >= 0 && (flags & FD_CLOEXEC) != 0;
}

static int PXBackupPublicationDuplicateDescriptor(int descriptor) {
    if (descriptor < 0) {
        return -1;
    }
    int duplicated = -1;
#if defined(F_DUPFD_CLOEXEC)
    do {
        duplicated = fcntl(descriptor, F_DUPFD_CLOEXEC, 0);
    } while (duplicated < 0 && errno == EINTR);
    if (duplicated >= 0) {
        return duplicated;
    }
#endif
    duplicated = -1;
    do {
        duplicated = dup(descriptor);
    } while (duplicated < 0 && errno == EINTR);
    if (duplicated < 0) {
        return -1;
    }
    int flags = -1;
    do {
        flags = fcntl(duplicated, F_GETFD);
    } while (flags < 0 && errno == EINTR);
    if (flags < 0) {
        close(duplicated);
        return -1;
    }
    int setResult = -1;
    do {
        setResult = fcntl(duplicated, F_SETFD, flags | FD_CLOEXEC);
    } while (setResult < 0 && errno == EINTR);
    if (setResult < 0 || !PXBackupPublicationDescriptorHasCloseOnExec(duplicated)) {
        close(duplicated);
        return -1;
    }
    return duplicated;
}

static BOOL PXBackupPublicationStringContainsNull(NSString *value) {
    for (NSUInteger index = 0; index < value.length; index++) {
        if ([value characterAtIndex:index] == 0) {
            return YES;
        }
    }
    return NO;
}

static NSData *PXBackupPublicationLosslessUTF8Data(NSString *value) {
    if (![value isKindOfClass:[NSString class]] ||
        PXBackupPublicationStringContainsNull(value)) {
        return nil;
    }
    return [value dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
}

static BOOL PXBackupPublicationValidateBackupRoot(NSString *backupRoot,
                                                  NSData **utf8Data,
                                                  BOOL *limitExceeded) {
    if (utf8Data) {
        *utf8Data = nil;
    }
    if (limitExceeded) {
        *limitExceeded = NO;
    }
    if (![backupRoot isKindOfClass:[NSString class]] ||
        backupRoot.length == 0 ||
        ![backupRoot hasPrefix:@"/"] ||
        PXBackupPublicationStringContainsNull(backupRoot)) {
        return NO;
    }
    NSData *data = PXBackupPublicationLosslessUTF8Data(backupRoot);
    if (!data || data.length == 0) {
        return NO;
    }
    if (data.length > PXBackupPublicationMaximumRootBytes) {
        if (limitExceeded) {
            *limitExceeded = YES;
        }
        return NO;
    }
    if (utf8Data) {
        *utf8Data = data;
    }
    return YES;
}

static BOOL PXBackupPublicationValidateSafeComponent(NSString *component,
                                                      NSData **utf8Data,
                                                      BOOL *limitExceeded) {
    if (utf8Data) {
        *utf8Data = nil;
    }
    if (limitExceeded) {
        *limitExceeded = NO;
    }
    if (![component isKindOfClass:[NSString class]] || component.length == 0 ||
        [component isEqualToString:@"."] || [component isEqualToString:@".."]) {
        return NO;
    }
    BOOL containsNonWhitespace = NO;
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    for (NSUInteger index = 0; index < component.length; index++) {
        unichar character = [component characterAtIndex:index];
        if (character == 0 || character == '/' || character == '\\' ||
            character < 0x20 || character == 0x7f) {
            return NO;
        }
        if (![whitespace characterIsMember:character]) {
            containsNonWhitespace = YES;
        }
    }
    if (!containsNonWhitespace) {
        return NO;
    }
    NSData *data = PXBackupPublicationLosslessUTF8Data(component);
    if (!data || data.length == 0) {
        return NO;
    }
    if (data.length > PXBackupPublicationMaximumComponentBytes) {
        if (limitExceeded) {
            *limitExceeded = YES;
        }
        return NO;
    }
    if (utf8Data) {
        *utf8Data = data;
    }
    return YES;
}

static char *PXBackupPublicationCopyCString(NSData *data) {
    if (![data isKindOfClass:[NSData class]] || data.length > SIZE_MAX - 1) {
        return NULL;
    }
    char *result = calloc(data.length + 1, 1);
    if (!result) {
        return NULL;
    }
    if (data.length > 0) {
        memcpy(result, data.bytes, data.length);
    }
    result[data.length] = '\0';
    return result;
}

static char *PXBackupPublicationCopyFinalComponentInspectionPath(const char *path) {
    if (!path || path[0] != '/') {
        return NULL;
    }
    char *result = strdup(path);
    if (!result) {
        return NULL;
    }
    size_t length = strlen(result);
    while (length > 1 && result[length - 1] == '/') {
        result[length - 1] = '\0';
        length--;
    }
    return result;
}

static BOOL PXBackupPublicationEnsureRootExists(const char *path,
                                                BOOL *finalDirectoryCreated) {
    if (finalDirectoryCreated) {
        *finalDirectoryCreated = NO;
    }
    if (!path || path[0] != '/') {
        return NO;
    }
    if (strcmp(path, "/") == 0) {
        return YES;
    }
    size_t length = strlen(path);
    size_t finalComponentLength = length;
    while (finalComponentLength > 1 && path[finalComponentLength - 1] == '/') {
        finalComponentLength--;
    }
    char *mutablePath = strdup(path);
    if (!mutablePath) {
        return NO;
    }
    BOOL success = YES;
    for (size_t index = 1; index < length; index++) {
        if (mutablePath[index] != '/' || mutablePath[index - 1] == '/') {
            continue;
        }
        mutablePath[index] = '\0';
        if (mkdir(mutablePath, 0700) == 0) {
            if (finalDirectoryCreated && index == finalComponentLength) {
                *finalDirectoryCreated = YES;
            }
        } else if (errno != EEXIST) {
            success = NO;
            mutablePath[index] = '/';
            break;
        }
        mutablePath[index] = '/';
    }
    if (success) {
        if (mkdir(mutablePath, 0700) == 0) {
            if (finalDirectoryCreated) {
                *finalDirectoryCreated = YES;
            }
        } else if (errno != EEXIST) {
            success = NO;
        }
    }
    free(mutablePath);
    return success;
}

static NSString *PXBackupPublicationStringFromFileSystemBytes(const char *bytes,
                                                              NSUInteger maximumBytes) {
    if (!bytes) {
        return nil;
    }
    size_t length = strlen(bytes);
    if (length == 0 || length > maximumBytes) {
        return nil;
    }
    NSString *string = [[NSString alloc] initWithBytes:bytes
                                                length:length
                                              encoding:NSUTF8StringEncoding];
    if (!string) {
        return nil;
    }
    NSData *roundTrip = [string dataUsingEncoding:NSUTF8StringEncoding
                              allowLossyConversion:NO];
    if (!roundTrip || roundTrip.length != length ||
        memcmp(roundTrip.bytes, bytes, length) != 0) {
        return nil;
    }
    return string;
}

static NSString *PXBackupPublicationAppendComponent(NSString *parent,
                                                     NSString *component) {
    if ([parent isEqualToString:@"/"]) {
        return [@"/" stringByAppendingString:component];
    }
    return [NSString stringWithFormat:@"%@/%@", parent, component];
}

static BOOL PXBackupPublicationDirectoryIsEmpty(int descriptor,
                                                BOOL *inspectionComplete) {
    if (inspectionComplete) {
        *inspectionComplete = NO;
    }
    int duplicated = PXBackupPublicationDuplicateDescriptor(descriptor);
    if (duplicated < 0) {
        return NO;
    }
    DIR *directory = fdopendir(duplicated);
    if (!directory) {
        close(duplicated);
        return NO;
    }
    BOOL empty = YES;
    BOOL complete = YES;
    errno = 0;
    struct dirent *entry = NULL;
    while ((entry = readdir(directory)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 ||
            strcmp(entry->d_name, "..") == 0) {
            continue;
        }
        empty = NO;
        break;
    }
    if (!entry && errno != 0) {
        complete = NO;
    }
    if (closedir(directory) != 0) {
        complete = NO;
    }
    if (inspectionComplete) {
        *inspectionComplete = complete;
    }
    return empty && complete;
}

static BOOL PXBackupPublicationPathMatchesDescriptor(NSString *path,
                                                      int descriptor,
                                                      const struct stat *expected,
                                                      struct stat *pathStatOut,
                                                      struct stat *descriptorStatOut) {
    NSData *pathData = PXBackupPublicationLosslessUTF8Data(path);
    char *pathCString = PXBackupPublicationCopyCString(pathData);
    if (!pathCString) {
        return NO;
    }
    struct stat pathStat;
    struct stat descriptorStat;
    BOOL valid = lstat(pathCString, &pathStat) == 0 &&
                 !S_ISLNK(pathStat.st_mode) &&
                 S_ISDIR(pathStat.st_mode) &&
                 fstat(descriptor, &descriptorStat) == 0 &&
                 S_ISDIR(descriptorStat.st_mode) &&
                 PXBackupPublicationStatIdentityMatches(&pathStat, &descriptorStat) &&
                 (!expected || PXBackupPublicationStatIdentityMatches(expected,
                                                                       &descriptorStat));
    free(pathCString);
    if (valid && pathStatOut) {
        *pathStatOut = pathStat;
    }
    if (valid && descriptorStatOut) {
        *descriptorStatOut = descriptorStat;
    }
    return valid;
}

static void PXBackupPublicationRemoveCreatedWorkspaceIfSafe(int bundleDescriptor,
                                                            const char *workspaceName,
                                                            const struct stat *expectedIdentity) {
    if (bundleDescriptor < 0 || !workspaceName || !expectedIdentity) {
        return;
    }
    struct stat namespaceStat;
    if (fstatat(bundleDescriptor,
                workspaceName,
                &namespaceStat,
                AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(namespaceStat.st_mode) ||
        !PXBackupPublicationStatIdentityMatches(&namespaceStat, expectedIdentity)) {
        return;
    }
    int descriptor = openat(bundleDescriptor,
                            workspaceName,
                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (descriptor < 0) {
        return;
    }
    struct stat descriptorStat;
    BOOL exactIdentity = fstat(descriptor, &descriptorStat) == 0 &&
                         S_ISDIR(descriptorStat.st_mode) &&
                         PXBackupPublicationStatIdentityMatches(&descriptorStat,
                                                                 expectedIdentity) &&
                         PXBackupPublicationStatIdentityMatches(&descriptorStat,
                                                                 &namespaceStat);
    BOOL inspectionComplete = NO;
    BOOL empty = exactIdentity &&
                 PXBackupPublicationDirectoryIsEmpty(descriptor,
                                                     &inspectionComplete);
    struct stat finalNamespaceStat;
    BOOL finalIdentity = empty && inspectionComplete &&
                         fstatat(bundleDescriptor,
                                 workspaceName,
                                 &finalNamespaceStat,
                                 AT_SYMLINK_NOFOLLOW) == 0 &&
                         S_ISDIR(finalNamespaceStat.st_mode) &&
                         PXBackupPublicationStatIdentityMatches(&finalNamespaceStat,
                                                                 expectedIdentity);
    if (finalIdentity) {
        (void)unlinkat(bundleDescriptor, workspaceName, AT_REMOVEDIR);
    }
    close(descriptor);
}

@interface PXBackupPublicationWorkspace ()

- (instancetype)initWithCanonicalBackupRootPath:(NSString *)canonicalBackupRootPath
                   canonicalBundleDirectoryPath:(NSString *)canonicalBundleDirectoryPath
                                  workspacePath:(NSString *)workspacePath
                                  workspaceName:(NSString *)workspaceName
                                bundleIdentifier:(NSString *)bundleIdentifier
                                 rootDescriptor:(int)rootDescriptor
                               bundleDescriptor:(int)bundleDescriptor
                            workspaceDescriptor:(int)workspaceDescriptor
                                    rootIdentity:(const struct stat *)rootIdentity
                                  bundleIdentity:(const struct stat *)bundleIdentity
                               workspaceIdentity:(const struct stat *)workspaceIdentity;

@end

@implementation PXBackupPublicationWorkspace {
    NSString *_canonicalBackupRootPath;
    NSString *_canonicalBundleDirectoryPath;
    NSString *_workspacePath;
    NSString *_workspaceName;
    NSString *_bundleIdentifier;
    int _rootDescriptor;
    int _bundleDescriptor;
    int _workspaceDescriptor;
    struct stat _rootIdentity;
    struct stat _bundleIdentity;
    struct stat _workspaceIdentity;
}

+ (nullable instancetype)createWorkspaceAtBackupRoot:(NSString *)backupRoot
                                    bundleIdentifier:(NSString *)bundleIdentifier
                                               error:(NSError **)error {
    if (error) {
        *error = nil;
    }

    NSData *rootData = nil;
    NSData *bundleData = nil;
    NSData *canonicalBundleData = nil;
    NSData *workspaceTemplateData = nil;
    NSData *validatedWorkspaceNameData = nil;
    BOOL rootLimitExceeded = NO;
    BOOL bundleLimitExceeded = NO;
    BOOL workspaceNameLimitExceeded = NO;
    BOOL emptyInspectionComplete = NO;
    char *requestedRootCString = NULL;
    char *requestedRootInspectionCString = NULL;
    char *bundleCString = NULL;
    char *canonicalRootCString = NULL;
    char *workspaceTemplateCString = NULL;
    char *createdWorkspaceCString = NULL;
    const char *workspaceNameCString = NULL;
    NSString *canonicalRootPath = nil;
    NSString *canonicalBundlePath = nil;
    NSString *workspaceTemplateName = nil;
    NSString *workspaceTemplatePath = nil;
    NSString *workspacePath = nil;
    NSString *workspaceName = nil;
    int rootDescriptor = -1;
    int bundleDescriptor = -1;
    int workspaceDescriptor = -1;
    BOOL rootCreated = NO;
    BOOL bundleCreated = NO;
    BOOL workspaceCreated = NO;
    BOOL workspaceIdentityKnown = NO;
    struct stat requestedRootStat;
    struct stat canonicalRootStat;
    struct stat rootStat;
    struct stat bundleNamespaceStat;
    struct stat bundleStat;
    struct stat workspacePathStat;
    struct stat workspaceNamespaceStat;
    struct stat workspaceStat;
    PXBackupPublicationWorkspace *result = nil;

    if (!PXBackupPublicationValidateBackupRoot(backupRoot,
                                               &rootData,
                                               &rootLimitExceeded)) {
        PXBackupPublicationSetError(error,
                                    rootLimitExceeded
                                        ? PXBackupPublicationWorkspaceErrorLimitExceeded
                                        : PXBackupPublicationWorkspaceErrorInvalidInput,
                                    PXBackupPublicationBackupRootField,
                                    @"The backup root is invalid");
        goto cleanup;
    }
    if (!PXBackupPublicationValidateSafeComponent(bundleIdentifier,
                                                  &bundleData,
                                                  &bundleLimitExceeded)) {
        PXBackupPublicationSetError(error,
                                    bundleLimitExceeded
                                        ? PXBackupPublicationWorkspaceErrorLimitExceeded
                                        : PXBackupPublicationWorkspaceErrorInvalidInput,
                                    PXBackupPublicationBundleIdentifierField,
                                    @"The bundle identifier is invalid");
        goto cleanup;
    }

    requestedRootCString = PXBackupPublicationCopyCString(rootData);
    requestedRootInspectionCString =
        PXBackupPublicationCopyFinalComponentInspectionPath(requestedRootCString);
    bundleCString = PXBackupPublicationCopyCString(bundleData);
    if (!requestedRootCString || !requestedRootInspectionCString || !bundleCString) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorLimitExceeded,
                                    (!requestedRootCString || !requestedRootInspectionCString)
                                        ? PXBackupPublicationBackupRootField
                                        : PXBackupPublicationBundleIdentifierField,
                                    @"A workspace input exceeded resource limits");
        goto cleanup;
    }

    if (!PXBackupPublicationEnsureRootExists(requestedRootCString, &rootCreated)) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorRootCreationFailed,
                                    PXBackupPublicationBackupRootField,
                                    @"The backup root could not be created");
        goto cleanup;
    }
    if (lstat(requestedRootInspectionCString, &requestedRootStat) != 0) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorRootInspectionFailed,
                                    PXBackupPublicationBackupRootField,
                                    @"The backup root could not be inspected");
        goto cleanup;
    }
    if (S_ISLNK(requestedRootStat.st_mode) ||
        !S_ISDIR(requestedRootStat.st_mode) ||
        (requestedRootStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorUnsafeRoot,
                                    PXBackupPublicationBackupRootField,
                                    @"The backup root is unsafe");
        goto cleanup;
    }

    canonicalRootCString = realpath(requestedRootCString, NULL);
    if (!canonicalRootCString) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorRootInspectionFailed,
                                    PXBackupPublicationBackupRootField,
                                    @"The backup root could not be canonicalized");
        goto cleanup;
    }
    canonicalRootPath = PXBackupPublicationStringFromFileSystemBytes(
        canonicalRootCString,
        PXBackupPublicationMaximumRootBytes);
    if (!canonicalRootPath || ![canonicalRootPath hasPrefix:@"/"]) {
        PXBackupPublicationSetError(error,
                                    strlen(canonicalRootCString) >
                                            PXBackupPublicationMaximumRootBytes
                                        ? PXBackupPublicationWorkspaceErrorLimitExceeded
                                        : PXBackupPublicationWorkspaceErrorRootInspectionFailed,
                                    PXBackupPublicationBackupRootField,
                                    @"The canonical backup root is invalid");
        goto cleanup;
    }
    if (lstat(canonicalRootCString, &canonicalRootStat) != 0 ||
        S_ISLNK(canonicalRootStat.st_mode) ||
        !S_ISDIR(canonicalRootStat.st_mode)) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorRootInspectionFailed,
                                    PXBackupPublicationBackupRootField,
                                    @"The canonical backup root could not be inspected");
        goto cleanup;
    }

    rootDescriptor = open(canonicalRootCString,
                          O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (rootDescriptor < 0) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorRootInspectionFailed,
                                    PXBackupPublicationBackupRootField,
                                    @"The backup root could not be opened safely");
        goto cleanup;
    }
    if (rootCreated && fchmod(rootDescriptor, 0700) != 0) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorRootInspectionFailed,
                                    PXBackupPublicationBackupRootField,
                                    @"The backup root permissions could not be secured");
        goto cleanup;
    }
    if (fstat(rootDescriptor, &rootStat) != 0 ||
        !S_ISDIR(rootStat.st_mode) ||
        (rootStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        (rootCreated && (rootStat.st_mode & 07777) != 0700) ||
        !PXBackupPublicationDescriptorHasCloseOnExec(rootDescriptor)) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorUnsafeRoot,
                                    PXBackupPublicationBackupRootField,
                                    @"The backup root descriptor is invalid");
        goto cleanup;
    }
    if (lstat(requestedRootInspectionCString, &requestedRootStat) != 0 ||
        lstat(canonicalRootCString, &canonicalRootStat) != 0 ||
        S_ISLNK(requestedRootStat.st_mode) ||
        S_ISLNK(canonicalRootStat.st_mode) ||
        !PXBackupPublicationStatIdentityMatches(&requestedRootStat, &rootStat) ||
        !PXBackupPublicationStatIdentityMatches(&canonicalRootStat, &rootStat)) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorFilesystemChanged,
                                    PXBackupPublicationBackupRootField,
                                    @"The backup root identity changed");
        goto cleanup;
    }

    if (fstatat(rootDescriptor,
                bundleCString,
                &bundleNamespaceStat,
                AT_SYMLINK_NOFOLLOW) != 0) {
        if (errno != ENOENT) {
            PXBackupPublicationSetError(error,
                                        PXBackupPublicationWorkspaceErrorBundleDirectoryInvalid,
                                        PXBackupPublicationBundleDirectoryField,
                                        @"The bundle directory could not be inspected");
            goto cleanup;
        }
        if (mkdirat(rootDescriptor, bundleCString, 0700) != 0) {
            PXBackupPublicationSetError(error,
                                        PXBackupPublicationWorkspaceErrorBundleDirectoryCreationFailed,
                                        PXBackupPublicationBundleDirectoryField,
                                        @"The bundle directory could not be created");
            goto cleanup;
        }
        bundleCreated = YES;
        if (fstatat(rootDescriptor,
                    bundleCString,
                    &bundleNamespaceStat,
                    AT_SYMLINK_NOFOLLOW) != 0) {
            PXBackupPublicationSetError(error,
                                        PXBackupPublicationWorkspaceErrorBundleDirectoryInvalid,
                                        PXBackupPublicationBundleDirectoryField,
                                        @"The bundle directory could not be inspected");
            goto cleanup;
        }
    }
    if (!S_ISDIR(bundleNamespaceStat.st_mode) ||
        (bundleNamespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorBundleDirectoryInvalid,
                                    PXBackupPublicationBundleDirectoryField,
                                    @"The bundle directory is invalid");
        goto cleanup;
    }

    bundleDescriptor = openat(rootDescriptor,
                              bundleCString,
                              O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (bundleDescriptor < 0) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorBundleDirectoryInvalid,
                                    PXBackupPublicationBundleDirectoryField,
                                    @"The bundle directory could not be opened safely");
        goto cleanup;
    }
    if (bundleCreated && fchmod(bundleDescriptor, 0700) != 0) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorBundleDirectoryInvalid,
                                    PXBackupPublicationBundleDirectoryField,
                                    @"The bundle directory permissions could not be secured");
        goto cleanup;
    }
    if (fstat(bundleDescriptor, &bundleStat) != 0 ||
        !S_ISDIR(bundleStat.st_mode) ||
        (bundleStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        (bundleCreated && (bundleStat.st_mode & 07777) != 0700) ||
        bundleStat.st_dev != rootStat.st_dev ||
        !PXBackupPublicationStatIdentityMatches(&bundleNamespaceStat, &bundleStat) ||
        !PXBackupPublicationDescriptorHasCloseOnExec(bundleDescriptor)) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorBundleDirectoryInvalid,
                                    PXBackupPublicationBundleDirectoryField,
                                    @"The bundle directory descriptor is invalid");
        goto cleanup;
    }

    canonicalBundlePath = PXBackupPublicationAppendComponent(canonicalRootPath,
                                                              bundleIdentifier);
    canonicalBundleData = PXBackupPublicationLosslessUTF8Data(canonicalBundlePath);
    if (!canonicalBundleData ||
        canonicalBundleData.length > PXBackupPublicationMaximumRootBytes) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorLimitExceeded,
                                    PXBackupPublicationBundleDirectoryField,
                                    @"The bundle directory path exceeded resource limits");
        goto cleanup;
    }
    if (!PXBackupPublicationPathMatchesDescriptor(canonicalBundlePath,
                                                   bundleDescriptor,
                                                   &bundleStat,
                                                   NULL,
                                                   NULL) ||
        !PXBackupPublicationPathMatchesDescriptor(canonicalRootPath,
                                                   rootDescriptor,
                                                   &rootStat,
                                                   NULL,
                                                   NULL)) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorFilesystemChanged,
                                    PXBackupPublicationBundleDirectoryField,
                                    @"The bundle directory identity changed");
        goto cleanup;
    }

    workspaceTemplateName = PXBackupPublicationStringFromFileSystemBytes(
        PXBackupPublicationWorkspaceTemplate,
        PXBackupPublicationMaximumComponentBytes);
    workspaceTemplatePath = workspaceTemplateName
        ? PXBackupPublicationAppendComponent(canonicalBundlePath,
                                             workspaceTemplateName)
        : nil;
    workspaceTemplateData = PXBackupPublicationLosslessUTF8Data(
        workspaceTemplatePath);
    if (!workspaceTemplateData ||
        workspaceTemplateData.length > PXBackupPublicationMaximumRootBytes) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorLimitExceeded,
                                    PXBackupPublicationWorkspaceField,
                                    @"The workspace path exceeded resource limits");
        goto cleanup;
    }
    workspaceTemplateCString = PXBackupPublicationCopyCString(workspaceTemplateData);
    if (!workspaceTemplateCString) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorLimitExceeded,
                                    PXBackupPublicationWorkspaceField,
                                    @"The workspace path exceeded resource limits");
        goto cleanup;
    }

    createdWorkspaceCString = mkdtemp(workspaceTemplateCString);
    if (!createdWorkspaceCString) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorWorkspaceCreationFailed,
                                    PXBackupPublicationWorkspaceField,
                                    @"The partial workspace could not be created");
        goto cleanup;
    }
    workspaceCreated = YES;
    workspaceNameCString = strrchr(createdWorkspaceCString, '/');
    workspaceNameCString = workspaceNameCString
        ? workspaceNameCString + 1
        : createdWorkspaceCString;
    if (lstat(createdWorkspaceCString, &workspacePathStat) != 0) {
        if (workspaceNameCString[0] != '\0' &&
            fstatat(bundleDescriptor,
                    workspaceNameCString,
                    &workspaceStat,
                    AT_SYMLINK_NOFOLLOW) == 0) {
            workspaceIdentityKnown = YES;
        }
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorWorkspaceInvalid,
                                    PXBackupPublicationWorkspaceField,
                                    @"The partial workspace could not be inspected");
        goto cleanup;
    }
    workspaceStat = workspacePathStat;
    workspaceIdentityKnown = YES;
    if (S_ISLNK(workspacePathStat.st_mode) ||
        !S_ISDIR(workspacePathStat.st_mode)) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorWorkspaceInvalid,
                                    PXBackupPublicationWorkspaceField,
                                    @"The partial workspace is invalid");
        goto cleanup;
    }
    if (strncmp(workspaceNameCString,
                PXBackupPublicationWorkspaceTemplate,
                strlen(".weaponx-backup-partial-")) != 0) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorWorkspaceInvalid,
                                    PXBackupPublicationWorkspaceField,
                                    @"The partial workspace name is invalid");
        goto cleanup;
    }
    workspaceName = PXBackupPublicationStringFromFileSystemBytes(
        workspaceNameCString,
        PXBackupPublicationMaximumComponentBytes);
    if (!workspaceName ||
        ![workspaceName hasPrefix:PXBackupPublicationPartialDirectoryPrefix] ||
        !PXBackupPublicationValidateSafeComponent(workspaceName,
                                                  &validatedWorkspaceNameData,
                                                  &workspaceNameLimitExceeded)) {
        PXBackupPublicationSetError(error,
                                    workspaceNameLimitExceeded
                                        ? PXBackupPublicationWorkspaceErrorLimitExceeded
                                        : PXBackupPublicationWorkspaceErrorWorkspaceInvalid,
                                    PXBackupPublicationWorkspaceField,
                                    @"The partial workspace name is invalid");
        goto cleanup;
    }

    workspacePath = PXBackupPublicationStringFromFileSystemBytes(
        createdWorkspaceCString,
        PXBackupPublicationMaximumRootBytes);
    if (!workspacePath ||
        ![workspacePath isEqualToString:PXBackupPublicationAppendComponent(
                                            canonicalBundlePath,
                                            workspaceName)]) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorWorkspaceInvalid,
                                    PXBackupPublicationWorkspaceField,
                                    @"The partial workspace path is invalid");
        goto cleanup;
    }

    struct stat workspacePathRevalidationStat;
    if (lstat(createdWorkspaceCString, &workspacePathRevalidationStat) != 0 ||
        S_ISLNK(workspacePathRevalidationStat.st_mode) ||
        !S_ISDIR(workspacePathRevalidationStat.st_mode) ||
        !PXBackupPublicationStatIdentityMatches(&workspacePathStat,
                                                 &workspacePathRevalidationStat)) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorFilesystemChanged,
                                    PXBackupPublicationWorkspaceField,
                                    @"The partial workspace identity changed");
        goto cleanup;
    }
    if (fstatat(bundleDescriptor,
                workspaceNameCString,
                &workspaceNamespaceStat,
                AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(workspaceNamespaceStat.st_mode) ||
        !PXBackupPublicationStatIdentityMatches(&workspacePathStat,
                                                 &workspaceNamespaceStat)) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorFilesystemChanged,
                                    PXBackupPublicationWorkspaceField,
                                    @"The partial workspace identity changed");
        goto cleanup;
    }

    workspaceDescriptor = openat(bundleDescriptor,
                                  workspaceNameCString,
                                  O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (workspaceDescriptor < 0) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorWorkspaceInvalid,
                                    PXBackupPublicationWorkspaceField,
                                    @"The partial workspace could not be opened safely");
        goto cleanup;
    }
    if (fchmod(workspaceDescriptor, 0700) != 0 ||
        fstat(workspaceDescriptor, &workspaceStat) != 0 ||
        !S_ISDIR(workspaceStat.st_mode) ||
        (workspaceStat.st_mode & 07777) != 0700 ||
        workspaceStat.st_dev != bundleStat.st_dev ||
        !PXBackupPublicationStatIdentityMatches(&workspacePathStat, &workspaceStat) ||
        !PXBackupPublicationStatIdentityMatches(&workspaceNamespaceStat, &workspaceStat) ||
        !PXBackupPublicationDescriptorHasCloseOnExec(workspaceDescriptor)) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorWorkspaceInvalid,
                                    PXBackupPublicationWorkspaceField,
                                    @"The partial workspace descriptor is invalid");
        goto cleanup;
    }
    workspaceIdentityKnown = YES;

    if (!PXBackupPublicationDirectoryIsEmpty(workspaceDescriptor,
                                             &emptyInspectionComplete) ||
        !emptyInspectionComplete) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorWorkspaceInvalid,
                                    PXBackupPublicationWorkspaceField,
                                    @"The partial workspace is not empty");
        goto cleanup;
    }

    if (!PXBackupPublicationPathMatchesDescriptor(canonicalRootPath,
                                                   rootDescriptor,
                                                   &rootStat,
                                                   NULL,
                                                   NULL) ||
        !PXBackupPublicationPathMatchesDescriptor(canonicalBundlePath,
                                                   bundleDescriptor,
                                                   &bundleStat,
                                                   NULL,
                                                   NULL) ||
        !PXBackupPublicationPathMatchesDescriptor(workspacePath,
                                                   workspaceDescriptor,
                                                   &workspaceStat,
                                                   NULL,
                                                   NULL) ||
        rootStat.st_dev != bundleStat.st_dev ||
        bundleStat.st_dev != workspaceStat.st_dev) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorFilesystemChanged,
                                    PXBackupPublicationWorkspaceField,
                                    @"The partial workspace identity changed");
        goto cleanup;
    }

    result = [[PXBackupPublicationWorkspace alloc]
        initWithCanonicalBackupRootPath:canonicalRootPath
           canonicalBundleDirectoryPath:canonicalBundlePath
                          workspacePath:workspacePath
                          workspaceName:workspaceName
                        bundleIdentifier:bundleIdentifier
                         rootDescriptor:rootDescriptor
                       bundleDescriptor:bundleDescriptor
                    workspaceDescriptor:workspaceDescriptor
                            rootIdentity:&rootStat
                          bundleIdentity:&bundleStat
                       workspaceIdentity:&workspaceStat];
    if (!result) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorWorkspaceInvalid,
                                    PXBackupPublicationWorkspaceField,
                                    @"The partial workspace could not be retained");
        goto cleanup;
    }
    rootDescriptor = -1;
    bundleDescriptor = -1;
    workspaceDescriptor = -1;

cleanup:
    if (!result && workspaceCreated && workspaceIdentityKnown &&
        bundleDescriptor >= 0 && workspaceNameCString &&
        workspaceNameCString[0] != '\0') {
        PXBackupPublicationRemoveCreatedWorkspaceIfSafe(bundleDescriptor,
                                                         workspaceNameCString,
                                                         &workspaceStat);
    }
    if (workspaceDescriptor >= 0) {
        close(workspaceDescriptor);
    }
    if (bundleDescriptor >= 0) {
        close(bundleDescriptor);
    }
    if (rootDescriptor >= 0) {
        close(rootDescriptor);
    }
    free(workspaceTemplateCString);
    free(canonicalRootCString);
    free(bundleCString);
    free(requestedRootInspectionCString);
    free(requestedRootCString);
    return result;
}

- (instancetype)initWithCanonicalBackupRootPath:(NSString *)canonicalBackupRootPath
                   canonicalBundleDirectoryPath:(NSString *)canonicalBundleDirectoryPath
                                  workspacePath:(NSString *)workspacePath
                                  workspaceName:(NSString *)workspaceName
                                bundleIdentifier:(NSString *)bundleIdentifier
                                 rootDescriptor:(int)rootDescriptor
                               bundleDescriptor:(int)bundleDescriptor
                            workspaceDescriptor:(int)workspaceDescriptor
                                    rootIdentity:(const struct stat *)rootIdentity
                                  bundleIdentity:(const struct stat *)bundleIdentity
                               workspaceIdentity:(const struct stat *)workspaceIdentity {
    self = [super init];
    if (self) {
        _canonicalBackupRootPath = [canonicalBackupRootPath copy];
        _canonicalBundleDirectoryPath = [canonicalBundleDirectoryPath copy];
        _workspacePath = [workspacePath copy];
        _workspaceName = [workspaceName copy];
        _bundleIdentifier = [bundleIdentifier copy];
        _rootDescriptor = rootDescriptor;
        _bundleDescriptor = bundleDescriptor;
        _workspaceDescriptor = workspaceDescriptor;
        _rootIdentity = *rootIdentity;
        _bundleIdentity = *bundleIdentity;
        _workspaceIdentity = *workspaceIdentity;
    }
    return self;
}

- (NSString *)canonicalBackupRootPath {
    return _canonicalBackupRootPath;
}

- (NSString *)canonicalBundleDirectoryPath {
    return _canonicalBundleDirectoryPath;
}

- (NSString *)workspacePath {
    return _workspacePath;
}

- (NSString *)workspaceName {
    return _workspaceName;
}

- (NSString *)bundleIdentifier {
    return _bundleIdentifier;
}

- (BOOL)validateIdentityWithError:(NSError **)error {
    if (error) {
        *error = nil;
    }
    if (_rootDescriptor < 0 || _bundleDescriptor < 0 ||
        _workspaceDescriptor < 0 ||
        ![_canonicalBackupRootPath isKindOfClass:[NSString class]] ||
        ![_canonicalBundleDirectoryPath isKindOfClass:[NSString class]] ||
        ![_workspacePath isKindOfClass:[NSString class]] ||
        ![_workspaceName isKindOfClass:[NSString class]] ||
        ![_bundleIdentifier isKindOfClass:[NSString class]] ||
        ![_workspaceName hasPrefix:PXBackupPublicationPartialDirectoryPrefix] ||
        ![_canonicalBundleDirectoryPath isEqualToString:
            PXBackupPublicationAppendComponent(_canonicalBackupRootPath,
                                                _bundleIdentifier)] ||
        ![_workspacePath isEqualToString:
            PXBackupPublicationAppendComponent(_canonicalBundleDirectoryPath,
                                                _workspaceName)]) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorFilesystemChanged,
                                    PXBackupPublicationWorkspaceField,
                                    @"The retained workspace identity is invalid");
        return NO;
    }

    struct stat rootStat;
    struct stat bundleStat;
    struct stat workspaceStat;
    if (fstat(_rootDescriptor, &rootStat) != 0 ||
        fstat(_bundleDescriptor, &bundleStat) != 0 ||
        fstat(_workspaceDescriptor, &workspaceStat) != 0) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorFilesystemChanged,
                                    PXBackupPublicationWorkspaceField,
                                    @"The retained workspace could not be inspected");
        return NO;
    }
    if (!S_ISDIR(rootStat.st_mode) || !S_ISDIR(bundleStat.st_mode) ||
        !S_ISDIR(workspaceStat.st_mode) ||
        (rootStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        (bundleStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        (workspaceStat.st_mode & 07777) != 0700 ||
        !PXBackupPublicationStatIdentityMatches(&rootStat, &_rootIdentity) ||
        !PXBackupPublicationStatIdentityMatches(&bundleStat, &_bundleIdentity) ||
        !PXBackupPublicationStatIdentityMatches(&workspaceStat,
                                                 &_workspaceIdentity) ||
        rootStat.st_dev != bundleStat.st_dev ||
        bundleStat.st_dev != workspaceStat.st_dev ||
        !PXBackupPublicationDescriptorHasCloseOnExec(_rootDescriptor) ||
        !PXBackupPublicationDescriptorHasCloseOnExec(_bundleDescriptor) ||
        !PXBackupPublicationDescriptorHasCloseOnExec(_workspaceDescriptor)) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorFilesystemChanged,
                                    PXBackupPublicationWorkspaceField,
                                    @"The retained workspace identity changed");
        return NO;
    }

    if (!PXBackupPublicationPathMatchesDescriptor(_canonicalBackupRootPath,
                                                   _rootDescriptor,
                                                   &_rootIdentity,
                                                   NULL,
                                                   NULL) ||
        !PXBackupPublicationPathMatchesDescriptor(_canonicalBundleDirectoryPath,
                                                   _bundleDescriptor,
                                                   &_bundleIdentity,
                                                   NULL,
                                                   NULL) ||
        !PXBackupPublicationPathMatchesDescriptor(_workspacePath,
                                                   _workspaceDescriptor,
                                                   &_workspaceIdentity,
                                                   NULL,
                                                   NULL)) {
        PXBackupPublicationSetError(error,
                                    PXBackupPublicationWorkspaceErrorFilesystemChanged,
                                    PXBackupPublicationWorkspaceField,
                                    @"A workspace path identity changed");
        return NO;
    }
    return YES;
}

- (void)dealloc {
    if (_workspaceDescriptor >= 0) {
        close(_workspaceDescriptor);
        _workspaceDescriptor = -1;
    }
    if (_bundleDescriptor >= 0) {
        close(_bundleDescriptor);
        _bundleDescriptor = -1;
    }
    if (_rootDescriptor >= 0) {
        close(_rootDescriptor);
        _rootDescriptor = -1;
    }
}

@end
