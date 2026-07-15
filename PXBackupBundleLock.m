#import "PXBackupBundleLock.h"

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

NSErrorDomain const PXBackupBundleLockErrorDomain =
    @"com.hydra.projectx.backup-bundle-lock";
NSString * const PXBackupBundleLockErrorFieldPathKey = @"fieldPath";
NSString * const PXBackupBundleLockFileName = @".weaponx-backup.lock";

static NSString * const PXBackupBundleLockBackupRootField = @"$.backupRoot";
static NSString * const PXBackupBundleLockBundleIdentifierField = @"$.bundleIdentifier";
static NSString * const PXBackupBundleLockBundleDirectoryField = @"$.bundleDirectory";
static NSString * const PXBackupBundleLockLockField = @"$.lock";

static const NSUInteger PXBackupBundleLockMaximumRootBytes = 4096;
static const NSUInteger PXBackupBundleLockMaximumComponentBytes = 255;
static const char PXBackupBundleLockFileNameCString[] = ".weaponx-backup.lock";

static void PXBackupBundleLockSetError(NSError **error,
                                       PXBackupBundleLockErrorCode code,
                                       NSString *fieldPath,
                                       NSString *description) {
    if (!error) {
        return;
    }
    *error = [NSError errorWithDomain:PXBackupBundleLockErrorDomain
                                 code:code
                             userInfo:@{
                                 NSLocalizedDescriptionKey: description,
                                 PXBackupBundleLockErrorFieldPathKey: fieldPath,
                             }];
}

static BOOL PXBackupBundleLockStatIdentityMatches(const struct stat *left,
                                                   const struct stat *right) {
    return left && right &&
           left->st_dev == right->st_dev &&
           left->st_ino == right->st_ino &&
           ((left->st_mode & S_IFMT) == (right->st_mode & S_IFMT));
}

static BOOL PXBackupBundleLockDescriptorHasCloseOnExec(int descriptor) {
    if (descriptor < 0) {
        return NO;
    }
    int flags = -1;
    do {
        flags = fcntl(descriptor, F_GETFD);
    } while (flags < 0 && errno == EINTR);
    return flags >= 0 && (flags & FD_CLOEXEC) != 0;
}

static BOOL PXBackupBundleLockStringContainsNull(NSString *value) {
    for (NSUInteger index = 0; index < value.length; index++) {
        if ([value characterAtIndex:index] == 0) {
            return YES;
        }
    }
    return NO;
}

static NSData *PXBackupBundleLockLosslessUTF8Data(NSString *value) {
    if (![value isKindOfClass:[NSString class]] ||
        PXBackupBundleLockStringContainsNull(value)) {
        return nil;
    }
    return [value dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
}

static BOOL PXBackupBundleLockValidateBackupRoot(NSString *backupRoot,
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
        PXBackupBundleLockStringContainsNull(backupRoot)) {
        return NO;
    }
    NSData *data = PXBackupBundleLockLosslessUTF8Data(backupRoot);
    if (!data || data.length == 0) {
        return NO;
    }
    if (data.length > PXBackupBundleLockMaximumRootBytes) {
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

static BOOL PXBackupBundleLockValidateSafeComponent(NSString *component,
                                                     NSData **utf8Data,
                                                     BOOL *limitExceeded) {
    if (utf8Data) {
        *utf8Data = nil;
    }
    if (limitExceeded) {
        *limitExceeded = NO;
    }
    if (![component isKindOfClass:[NSString class]] ||
        component.length == 0 ||
        [component isEqualToString:@"."] ||
        [component isEqualToString:@".."]) {
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
    NSData *data = PXBackupBundleLockLosslessUTF8Data(component);
    if (!data || data.length == 0) {
        return NO;
    }
    if (data.length > PXBackupBundleLockMaximumComponentBytes) {
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

static char *PXBackupBundleLockCopyCString(NSData *data) {
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

static char *PXBackupBundleLockCopyFinalComponentInspectionPath(const char *path) {
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

static BOOL PXBackupBundleLockEnsureRootExists(const char *path,
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

static NSString *PXBackupBundleLockStringFromFileSystemBytes(const char *bytes,
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

static NSString *PXBackupBundleLockAppendComponent(NSString *parent,
                                                    NSString *component) {
    if ([parent isEqualToString:@"/"]) {
        return [@"/" stringByAppendingString:component];
    }
    return [NSString stringWithFormat:@"%@/%@", parent, component];
}

static BOOL PXBackupBundleLockDirectoryPathMatchesDescriptor(
    NSString *path,
    int descriptor,
    const struct stat *expected) {
    NSData *pathData = PXBackupBundleLockLosslessUTF8Data(path);
    char *pathCString = PXBackupBundleLockCopyCString(pathData);
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
                 PXBackupBundleLockStatIdentityMatches(&pathStat, &descriptorStat) &&
                 (!expected ||
                  PXBackupBundleLockStatIdentityMatches(expected, &descriptorStat));
    free(pathCString);
    return valid;
}

static BOOL PXBackupBundleLockProofIsValid(
    NSString *canonicalRootPath,
    NSString *canonicalBundlePath,
    NSString *bundleIdentifier,
    int rootDescriptor,
    int bundleDescriptor,
    int lockDescriptor,
    const struct stat *expectedRoot,
    const struct stat *expectedBundle,
    const struct stat *expectedLock) {
    if (![canonicalRootPath isKindOfClass:[NSString class]] ||
        ![canonicalBundlePath isKindOfClass:[NSString class]] ||
        ![bundleIdentifier isKindOfClass:[NSString class]] ||
        rootDescriptor < 0 || bundleDescriptor < 0 || lockDescriptor < 0 ||
        !expectedRoot || !expectedBundle || !expectedLock ||
        ![canonicalBundlePath isEqualToString:
            PXBackupBundleLockAppendComponent(canonicalRootPath,
                                               bundleIdentifier)]) {
        return NO;
    }

    struct stat rootStat;
    struct stat bundleStat;
    struct stat lockStat;
    struct stat lockNamespaceStat;
    if (fstat(rootDescriptor, &rootStat) != 0 ||
        fstat(bundleDescriptor, &bundleStat) != 0 ||
        fstat(lockDescriptor, &lockStat) != 0 ||
        fstatat(bundleDescriptor,
                PXBackupBundleLockFileNameCString,
                &lockNamespaceStat,
                AT_SYMLINK_NOFOLLOW) != 0) {
        return NO;
    }
    if (!S_ISDIR(rootStat.st_mode) ||
        !S_ISDIR(bundleStat.st_mode) ||
        !S_ISREG(lockStat.st_mode) ||
        !S_ISREG(lockNamespaceStat.st_mode) ||
        (rootStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        (bundleStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        (lockStat.st_mode & 07777) != 0600 ||
        lockStat.st_nlink != 1 ||
        lockNamespaceStat.st_nlink != 1 ||
        rootStat.st_dev != bundleStat.st_dev ||
        bundleStat.st_dev != lockStat.st_dev ||
        !PXBackupBundleLockStatIdentityMatches(&rootStat, expectedRoot) ||
        !PXBackupBundleLockStatIdentityMatches(&bundleStat, expectedBundle) ||
        !PXBackupBundleLockStatIdentityMatches(&lockStat, expectedLock) ||
        !PXBackupBundleLockStatIdentityMatches(&lockNamespaceStat, expectedLock) ||
        !PXBackupBundleLockStatIdentityMatches(&lockNamespaceStat, &lockStat) ||
        !PXBackupBundleLockDescriptorHasCloseOnExec(rootDescriptor) ||
        !PXBackupBundleLockDescriptorHasCloseOnExec(bundleDescriptor) ||
        !PXBackupBundleLockDescriptorHasCloseOnExec(lockDescriptor)) {
        return NO;
    }
    return PXBackupBundleLockDirectoryPathMatchesDescriptor(canonicalRootPath,
                                                             rootDescriptor,
                                                             expectedRoot) &&
           PXBackupBundleLockDirectoryPathMatchesDescriptor(canonicalBundlePath,
                                                             bundleDescriptor,
                                                             expectedBundle);
}

static int PXBackupBundleLockExclusiveNonblocking(int descriptor) {
    int result = -1;
    do {
        result = flock(descriptor, LOCK_EX | LOCK_NB);
    } while (result != 0 && errno == EINTR);
    return result;
}

static void PXBackupBundleLockBestEffortUnlock(int descriptor) {
    if (descriptor < 0) {
        return;
    }
    int result = -1;
    do {
        result = flock(descriptor, LOCK_UN);
    } while (result != 0 && errno == EINTR);
}

@interface PXBackupBundleLock ()

- (instancetype)initWithCanonicalBackupRootPath:(NSString *)canonicalBackupRootPath
                   canonicalBundleDirectoryPath:(NSString *)canonicalBundleDirectoryPath
                               bundleIdentifier:(NSString *)bundleIdentifier
                                    lockFileName:(NSString *)lockFileName
                                  rootDescriptor:(int)rootDescriptor
                                bundleDescriptor:(int)bundleDescriptor
                                  lockDescriptor:(int)lockDescriptor
                                    rootIdentity:(const struct stat *)rootIdentity
                                  bundleIdentity:(const struct stat *)bundleIdentity
                                    lockIdentity:(const struct stat *)lockIdentity;

@end

@implementation PXBackupBundleLock {
    NSString *_canonicalBackupRootPath;
    NSString *_canonicalBundleDirectoryPath;
    NSString *_bundleIdentifier;
    NSString *_lockFileName;
    int _rootDescriptor;
    int _bundleDescriptor;
    int _lockDescriptor;
    BOOL _locked;
    struct stat _rootIdentity;
    struct stat _bundleIdentity;
    struct stat _lockIdentity;
}

+ (nullable instancetype)acquireLockAtBackupRoot:(NSString *)backupRoot
                                bundleIdentifier:(NSString *)bundleIdentifier
                                           error:(NSError **)error {
    if (error) {
        *error = nil;
    }

    NSData *rootData = nil;
    NSData *bundleData = nil;
    NSData *canonicalBundleData = nil;
    BOOL rootLimitExceeded = NO;
    BOOL bundleLimitExceeded = NO;
    char *requestedRootCString = NULL;
    char *requestedRootInspectionCString = NULL;
    char *bundleCString = NULL;
    char *canonicalRootCString = NULL;
    NSString *canonicalRootPath = nil;
    NSString *canonicalBundlePath = nil;
    int rootDescriptor = -1;
    int bundleDescriptor = -1;
    int lockDescriptor = -1;
    BOOL rootCreated = NO;
    BOOL bundleCreated = NO;
    BOOL lockAcquired = NO;
    struct stat requestedRootStat;
    struct stat canonicalRootStat;
    struct stat rootStat;
    struct stat bundleNamespaceStat;
    struct stat bundleStat;
    struct stat lockNamespaceStat;
    struct stat lockStat;
    PXBackupBundleLock *result = nil;

    if (!PXBackupBundleLockValidateBackupRoot(backupRoot,
                                              &rootData,
                                              &rootLimitExceeded)) {
        PXBackupBundleLockSetError(error,
                                   rootLimitExceeded
                                       ? PXBackupBundleLockErrorLimitExceeded
                                       : PXBackupBundleLockErrorInvalidInput,
                                   PXBackupBundleLockBackupRootField,
                                   @"The backup root is invalid");
        goto cleanup;
    }
    if (!PXBackupBundleLockValidateSafeComponent(bundleIdentifier,
                                                 &bundleData,
                                                 &bundleLimitExceeded)) {
        PXBackupBundleLockSetError(error,
                                   bundleLimitExceeded
                                       ? PXBackupBundleLockErrorLimitExceeded
                                       : PXBackupBundleLockErrorInvalidInput,
                                   PXBackupBundleLockBundleIdentifierField,
                                   @"The bundle identifier is invalid");
        goto cleanup;
    }

    requestedRootCString = PXBackupBundleLockCopyCString(rootData);
    requestedRootInspectionCString =
        PXBackupBundleLockCopyFinalComponentInspectionPath(requestedRootCString);
    bundleCString = PXBackupBundleLockCopyCString(bundleData);
    if (!requestedRootCString || !requestedRootInspectionCString || !bundleCString) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorLimitExceeded,
                                   (!requestedRootCString ||
                                    !requestedRootInspectionCString)
                                       ? PXBackupBundleLockBackupRootField
                                       : PXBackupBundleLockBundleIdentifierField,
                                   @"A lock input exceeded resource limits");
        goto cleanup;
    }

    if (!PXBackupBundleLockEnsureRootExists(requestedRootCString, &rootCreated)) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorRootCreationFailed,
                                   PXBackupBundleLockBackupRootField,
                                   @"The backup root could not be created");
        goto cleanup;
    }
    if (lstat(requestedRootInspectionCString, &requestedRootStat) != 0) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorRootInspectionFailed,
                                   PXBackupBundleLockBackupRootField,
                                   @"The backup root could not be inspected");
        goto cleanup;
    }
    if (S_ISLNK(requestedRootStat.st_mode) ||
        !S_ISDIR(requestedRootStat.st_mode) ||
        (requestedRootStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorUnsafeRoot,
                                   PXBackupBundleLockBackupRootField,
                                   @"The backup root is unsafe");
        goto cleanup;
    }

    canonicalRootCString = realpath(requestedRootCString, NULL);
    if (!canonicalRootCString) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorRootInspectionFailed,
                                   PXBackupBundleLockBackupRootField,
                                   @"The backup root could not be canonicalized");
        goto cleanup;
    }
    canonicalRootPath = PXBackupBundleLockStringFromFileSystemBytes(
        canonicalRootCString,
        PXBackupBundleLockMaximumRootBytes);
    if (!canonicalRootPath || ![canonicalRootPath hasPrefix:@"/"]) {
        PXBackupBundleLockSetError(error,
                                   strlen(canonicalRootCString) >
                                           PXBackupBundleLockMaximumRootBytes
                                       ? PXBackupBundleLockErrorLimitExceeded
                                       : PXBackupBundleLockErrorRootInspectionFailed,
                                   PXBackupBundleLockBackupRootField,
                                   @"The canonical backup root is invalid");
        goto cleanup;
    }
    if (lstat(canonicalRootCString, &canonicalRootStat) != 0 ||
        S_ISLNK(canonicalRootStat.st_mode) ||
        !S_ISDIR(canonicalRootStat.st_mode)) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorRootInspectionFailed,
                                   PXBackupBundleLockBackupRootField,
                                   @"The canonical backup root could not be inspected");
        goto cleanup;
    }

    rootDescriptor = open(canonicalRootCString,
                          O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (rootDescriptor < 0) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorRootInspectionFailed,
                                   PXBackupBundleLockBackupRootField,
                                   @"The backup root could not be opened safely");
        goto cleanup;
    }
    if (rootCreated && fchmod(rootDescriptor, 0700) != 0) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorRootInspectionFailed,
                                   PXBackupBundleLockBackupRootField,
                                   @"The backup root permissions could not be secured");
        goto cleanup;
    }
    if (fstat(rootDescriptor, &rootStat) != 0 ||
        !S_ISDIR(rootStat.st_mode) ||
        (rootStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        (rootCreated && (rootStat.st_mode & 07777) != 0700) ||
        !PXBackupBundleLockDescriptorHasCloseOnExec(rootDescriptor)) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorUnsafeRoot,
                                   PXBackupBundleLockBackupRootField,
                                   @"The backup root descriptor is invalid");
        goto cleanup;
    }
    if (lstat(requestedRootInspectionCString, &requestedRootStat) != 0 ||
        lstat(canonicalRootCString, &canonicalRootStat) != 0 ||
        S_ISLNK(requestedRootStat.st_mode) ||
        S_ISLNK(canonicalRootStat.st_mode) ||
        !PXBackupBundleLockStatIdentityMatches(&requestedRootStat, &rootStat) ||
        !PXBackupBundleLockStatIdentityMatches(&canonicalRootStat, &rootStat)) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorFilesystemChanged,
                                   PXBackupBundleLockBackupRootField,
                                   @"The backup root identity changed");
        goto cleanup;
    }

    if (fstatat(rootDescriptor,
                bundleCString,
                &bundleNamespaceStat,
                AT_SYMLINK_NOFOLLOW) != 0) {
        if (errno != ENOENT) {
            PXBackupBundleLockSetError(error,
                                       PXBackupBundleLockErrorBundleDirectoryInvalid,
                                       PXBackupBundleLockBundleDirectoryField,
                                       @"The bundle directory could not be inspected");
            goto cleanup;
        }
        if (mkdirat(rootDescriptor, bundleCString, 0700) != 0) {
            PXBackupBundleLockSetError(
                error,
                PXBackupBundleLockErrorBundleDirectoryCreationFailed,
                PXBackupBundleLockBundleDirectoryField,
                @"The bundle directory could not be created");
            goto cleanup;
        }
        bundleCreated = YES;
        if (fstatat(rootDescriptor,
                    bundleCString,
                    &bundleNamespaceStat,
                    AT_SYMLINK_NOFOLLOW) != 0) {
            PXBackupBundleLockSetError(error,
                                       PXBackupBundleLockErrorBundleDirectoryInvalid,
                                       PXBackupBundleLockBundleDirectoryField,
                                       @"The bundle directory could not be inspected");
            goto cleanup;
        }
    }
    if (!S_ISDIR(bundleNamespaceStat.st_mode) ||
        (bundleNamespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorBundleDirectoryInvalid,
                                   PXBackupBundleLockBundleDirectoryField,
                                   @"The bundle directory is invalid");
        goto cleanup;
    }

    bundleDescriptor = openat(rootDescriptor,
                              bundleCString,
                              O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (bundleDescriptor < 0) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorBundleDirectoryInvalid,
                                   PXBackupBundleLockBundleDirectoryField,
                                   @"The bundle directory could not be opened safely");
        goto cleanup;
    }
    if (bundleCreated && fchmod(bundleDescriptor, 0700) != 0) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorBundleDirectoryInvalid,
                                   PXBackupBundleLockBundleDirectoryField,
                                   @"The bundle directory permissions could not be secured");
        goto cleanup;
    }
    if (fstat(bundleDescriptor, &bundleStat) != 0 ||
        !S_ISDIR(bundleStat.st_mode) ||
        (bundleStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        (bundleCreated && (bundleStat.st_mode & 07777) != 0700) ||
        bundleStat.st_dev != rootStat.st_dev ||
        !PXBackupBundleLockStatIdentityMatches(&bundleNamespaceStat, &bundleStat) ||
        !PXBackupBundleLockDescriptorHasCloseOnExec(bundleDescriptor)) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorBundleDirectoryInvalid,
                                   PXBackupBundleLockBundleDirectoryField,
                                   @"The bundle directory descriptor is invalid");
        goto cleanup;
    }

    canonicalBundlePath = PXBackupBundleLockAppendComponent(canonicalRootPath,
                                                             bundleIdentifier);
    canonicalBundleData = PXBackupBundleLockLosslessUTF8Data(canonicalBundlePath);
    if (!canonicalBundleData ||
        canonicalBundleData.length > PXBackupBundleLockMaximumRootBytes) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorLimitExceeded,
                                   PXBackupBundleLockBundleDirectoryField,
                                   @"The bundle directory path exceeded resource limits");
        goto cleanup;
    }
    if (!PXBackupBundleLockDirectoryPathMatchesDescriptor(canonicalRootPath,
                                                           rootDescriptor,
                                                           &rootStat) ||
        !PXBackupBundleLockDirectoryPathMatchesDescriptor(canonicalBundlePath,
                                                           bundleDescriptor,
                                                           &bundleStat)) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorFilesystemChanged,
                                   PXBackupBundleLockBundleDirectoryField,
                                   @"The bundle directory identity changed");
        goto cleanup;
    }

    lockDescriptor = openat(bundleDescriptor,
                            PXBackupBundleLockFileNameCString,
                            O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC,
                            0600);
    if (lockDescriptor < 0) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorLockFileOpenFailed,
                                   PXBackupBundleLockLockField,
                                   @"The bundle lock file could not be opened");
        goto cleanup;
    }
    if (fstat(lockDescriptor, &lockStat) != 0 ||
        fstatat(bundleDescriptor,
                PXBackupBundleLockFileNameCString,
                &lockNamespaceStat,
                AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISREG(lockStat.st_mode) ||
        !S_ISREG(lockNamespaceStat.st_mode) ||
        lockStat.st_nlink != 1 ||
        lockNamespaceStat.st_nlink != 1 ||
        lockStat.st_dev != bundleStat.st_dev ||
        !PXBackupBundleLockStatIdentityMatches(&lockNamespaceStat, &lockStat)) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorLockFileInvalid,
                                   PXBackupBundleLockLockField,
                                   @"The bundle lock file is invalid");
        goto cleanup;
    }
    if (fchmod(lockDescriptor, 0600) != 0 ||
        fstat(lockDescriptor, &lockStat) != 0 ||
        fstatat(bundleDescriptor,
                PXBackupBundleLockFileNameCString,
                &lockNamespaceStat,
                AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISREG(lockStat.st_mode) ||
        !S_ISREG(lockNamespaceStat.st_mode) ||
        (lockStat.st_mode & 07777) != 0600 ||
        lockStat.st_nlink != 1 ||
        lockNamespaceStat.st_nlink != 1 ||
        lockStat.st_dev != bundleStat.st_dev ||
        !PXBackupBundleLockStatIdentityMatches(&lockNamespaceStat, &lockStat) ||
        !PXBackupBundleLockDescriptorHasCloseOnExec(lockDescriptor)) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorLockFileInvalid,
                                   PXBackupBundleLockLockField,
                                   @"The bundle lock file descriptor is invalid");
        goto cleanup;
    }

    if (PXBackupBundleLockExclusiveNonblocking(lockDescriptor) != 0) {
        PXBackupBundleLockErrorCode code =
            (errno == EWOULDBLOCK || errno == EAGAIN)
                ? PXBackupBundleLockErrorLockUnavailable
                : PXBackupBundleLockErrorLockFileOpenFailed;
        PXBackupBundleLockSetError(error,
                                   code,
                                   PXBackupBundleLockLockField,
                                   code == PXBackupBundleLockErrorLockUnavailable
                                       ? @"The bundle backup lock is unavailable"
                                       : @"The bundle backup lock could not be acquired");
        goto cleanup;
    }
    lockAcquired = YES;

    if (!PXBackupBundleLockProofIsValid(canonicalRootPath,
                                        canonicalBundlePath,
                                        bundleIdentifier,
                                        rootDescriptor,
                                        bundleDescriptor,
                                        lockDescriptor,
                                        &rootStat,
                                        &bundleStat,
                                        &lockStat)) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorFilesystemChanged,
                                   PXBackupBundleLockLockField,
                                   @"The bundle lock identity changed");
        goto cleanup;
    }

    result = [[PXBackupBundleLock alloc]
        initWithCanonicalBackupRootPath:canonicalRootPath
           canonicalBundleDirectoryPath:canonicalBundlePath
                       bundleIdentifier:bundleIdentifier
                            lockFileName:PXBackupBundleLockFileName
                          rootDescriptor:rootDescriptor
                        bundleDescriptor:bundleDescriptor
                          lockDescriptor:lockDescriptor
                            rootIdentity:&rootStat
                          bundleIdentity:&bundleStat
                            lockIdentity:&lockStat];
    if (!result) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorLockFileInvalid,
                                   PXBackupBundleLockLockField,
                                   @"The bundle lock could not be retained");
        goto cleanup;
    }
    rootDescriptor = -1;
    bundleDescriptor = -1;
    lockDescriptor = -1;
    lockAcquired = NO;

cleanup:
    if (lockAcquired && lockDescriptor >= 0) {
        PXBackupBundleLockBestEffortUnlock(lockDescriptor);
    }
    if (lockDescriptor >= 0) {
        close(lockDescriptor);
    }
    if (bundleDescriptor >= 0) {
        close(bundleDescriptor);
    }
    if (rootDescriptor >= 0) {
        close(rootDescriptor);
    }
    free(canonicalRootCString);
    free(bundleCString);
    free(requestedRootInspectionCString);
    free(requestedRootCString);
    return result;
}

- (instancetype)initWithCanonicalBackupRootPath:(NSString *)canonicalBackupRootPath
                   canonicalBundleDirectoryPath:(NSString *)canonicalBundleDirectoryPath
                               bundleIdentifier:(NSString *)bundleIdentifier
                                    lockFileName:(NSString *)lockFileName
                                  rootDescriptor:(int)rootDescriptor
                                bundleDescriptor:(int)bundleDescriptor
                                  lockDescriptor:(int)lockDescriptor
                                    rootIdentity:(const struct stat *)rootIdentity
                                  bundleIdentity:(const struct stat *)bundleIdentity
                                    lockIdentity:(const struct stat *)lockIdentity {
    self = [super init];
    if (self) {
        _canonicalBackupRootPath = [canonicalBackupRootPath copy];
        _canonicalBundleDirectoryPath = [canonicalBundleDirectoryPath copy];
        _bundleIdentifier = [bundleIdentifier copy];
        _lockFileName = [lockFileName copy];
        _rootDescriptor = rootDescriptor;
        _bundleDescriptor = bundleDescriptor;
        _lockDescriptor = lockDescriptor;
        _locked = YES;
        _rootIdentity = *rootIdentity;
        _bundleIdentity = *bundleIdentity;
        _lockIdentity = *lockIdentity;
    }
    return self;
}

- (NSString *)canonicalBackupRootPath {
    return _canonicalBackupRootPath;
}

- (NSString *)canonicalBundleDirectoryPath {
    return _canonicalBundleDirectoryPath;
}

- (NSString *)bundleIdentifier {
    return _bundleIdentifier;
}

- (NSString *)lockFileName {
    return _lockFileName;
}

- (BOOL)validateOwnershipWithError:(NSError **)error {
    if (error) {
        *error = nil;
    }
    if (!_locked ||
        _rootDescriptor < 0 ||
        _bundleDescriptor < 0 ||
        _lockDescriptor < 0 ||
        ![_canonicalBackupRootPath isKindOfClass:[NSString class]] ||
        ![_canonicalBundleDirectoryPath isKindOfClass:[NSString class]] ||
        ![_bundleIdentifier isKindOfClass:[NSString class]] ||
        ![_lockFileName isKindOfClass:[NSString class]] ||
        ![_lockFileName isEqualToString:PXBackupBundleLockFileName] ||
        ![_canonicalBundleDirectoryPath isEqualToString:
            PXBackupBundleLockAppendComponent(_canonicalBackupRootPath,
                                               _bundleIdentifier)]) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorFilesystemChanged,
                                   PXBackupBundleLockLockField,
                                   @"The retained bundle lock is invalid");
        return NO;
    }
    if (!PXBackupBundleLockProofIsValid(_canonicalBackupRootPath,
                                        _canonicalBundleDirectoryPath,
                                        _bundleIdentifier,
                                        _rootDescriptor,
                                        _bundleDescriptor,
                                        _lockDescriptor,
                                        &_rootIdentity,
                                        &_bundleIdentity,
                                        &_lockIdentity)) {
        PXBackupBundleLockSetError(error,
                                   PXBackupBundleLockErrorFilesystemChanged,
                                   PXBackupBundleLockLockField,
                                   @"The retained bundle lock identity changed");
        return NO;
    }
    return YES;
}

- (void)dealloc {
    if (_lockDescriptor >= 0) {
        if (_locked) {
            PXBackupBundleLockBestEffortUnlock(_lockDescriptor);
            _locked = NO;
        }
        close(_lockDescriptor);
        _lockDescriptor = -1;
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
