#import "PXBackupFailureCleanup.h"
#import "PXBackupPublicationWorkspace.h"
#import "PXBackupBundleLock.h"
#import "PXBackupDirectoryPublisher.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

NSErrorDomain const PXBackupFailureCleanupErrorDomain =
    @"com.hydra.tlinkios.backup-failure-cleanup";
NSString * const PXBackupFailureCleanupErrorFieldPathKey = @"fieldPath";

static NSString * const PXBackupFailureCleanupField = @"$.cleanup";
static NSString * const PXBackupFailureCleanupLockField = @"$.cleanup.lock";
static NSString * const PXBackupFailureCleanupParentField = @"$.cleanup.parent";
static NSString * const PXBackupFailureCleanupWorkspaceField = @"$.cleanup.workspace";
static NSString * const PXBackupFailureCleanupEntryField = @"$.cleanup.entry";
static NSString * const PXBackupFailureCleanupDurabilityField = @"$.cleanup.durability";
static NSString * const PXBackupFailureCleanupPublicationField = @"$.cleanup.publication";

static const NSUInteger PXBackupFailureCleanupMaximumDepth = 64U;
static const NSUInteger PXBackupFailureCleanupMaximumVisitedEntries = 16384U;
static const NSUInteger PXBackupFailureCleanupMaximumComponentBytes = 255U;
static const NSUInteger PXBackupFailureCleanupMaximumWorkspacePathBytes = 4096U;
static const unsigned long long PXBackupFailureCleanupMaximumAccumulatedNameBytes =
    8ULL * 1024ULL * 1024ULL;
static const char PXBackupFailureCleanupQuarantinePrefix[] =
    ".weaponx-cleanup-quarantine-";
static const NSUInteger PXBackupFailureCleanupQuarantineRandomByteCount = 16U;
static const NSUInteger PXBackupFailureCleanupQuarantineAttemptLimit = 16U;

#if defined(__APPLE__)
#define PX_BACKUP_CLEANUP_MTIME_SEC(value) ((value).st_mtimespec.tv_sec)
#define PX_BACKUP_CLEANUP_MTIME_NSEC(value) ((value).st_mtimespec.tv_nsec)
#define PX_BACKUP_CLEANUP_CTIME_SEC(value) ((value).st_ctimespec.tv_sec)
#define PX_BACKUP_CLEANUP_CTIME_NSEC(value) ((value).st_ctimespec.tv_nsec)
#else
#define PX_BACKUP_CLEANUP_MTIME_SEC(value) ((value).st_mtim.tv_sec)
#define PX_BACKUP_CLEANUP_MTIME_NSEC(value) ((value).st_mtim.tv_nsec)
#define PX_BACKUP_CLEANUP_CTIME_SEC(value) ((value).st_ctim.tv_sec)
#define PX_BACKUP_CLEANUP_CTIME_NSEC(value) ((value).st_ctim.tv_nsec)
#endif

typedef struct {
    NSUInteger visitedEntries;
    unsigned long long accumulatedNameBytes;
    NSUInteger removedEntries;
    BOOL destructiveMutationOccurred;
    dev_t workspaceDevice;
} PXBackupFailureCleanupTraversalState;

static void PXBackupFailureCleanupSetError(
    NSError **error,
    PXBackupFailureCleanupErrorCode code,
    NSString *field,
    NSString *description) {
    if (!error) return;
    *error = [NSError errorWithDomain:PXBackupFailureCleanupErrorDomain
                                 code:code
                             userInfo:@{
                                 NSLocalizedDescriptionKey: description,
                                 PXBackupFailureCleanupErrorFieldPathKey: field,
                             }];
}

static BOOL PXBackupFailureCleanupStatIdentityMatches(const struct stat *left,
                                                       const struct stat *right) {
    return left && right && left->st_dev == right->st_dev &&
           left->st_ino == right->st_ino &&
           (left->st_mode & S_IFMT) == (right->st_mode & S_IFMT);
}

static BOOL PXBackupFailureCleanupStableFileMatches(const struct stat *left,
                                                     const struct stat *right) {
    return PXBackupFailureCleanupStatIdentityMatches(left, right) &&
           left->st_mode == right->st_mode && left->st_nlink == right->st_nlink &&
           left->st_size == right->st_size &&
           PX_BACKUP_CLEANUP_MTIME_SEC(*left) == PX_BACKUP_CLEANUP_MTIME_SEC(*right) &&
           PX_BACKUP_CLEANUP_MTIME_NSEC(*left) == PX_BACKUP_CLEANUP_MTIME_NSEC(*right) &&
           PX_BACKUP_CLEANUP_CTIME_SEC(*left) == PX_BACKUP_CLEANUP_CTIME_SEC(*right) &&
           PX_BACKUP_CLEANUP_CTIME_NSEC(*left) == PX_BACKUP_CLEANUP_CTIME_NSEC(*right);
}

static BOOL PXBackupFailureCleanupDescriptorHasCloseOnExec(int descriptor) {
    if (descriptor < 0) return NO;
    int flags = -1;
    do {
        flags = fcntl(descriptor, F_GETFD);
    } while (flags < 0 && errno == EINTR);
    return flags >= 0 && (flags & FD_CLOEXEC) != 0;
}

static int PXBackupFailureCleanupDuplicateDescriptor(int descriptor) {
    if (descriptor < 0) return -1;
    int duplicate = -1;
    do {
        duplicate = fcntl(descriptor, F_DUPFD_CLOEXEC, 0);
    } while (duplicate < 0 && errno == EINTR);
    if (duplicate < 0 ||
        !PXBackupFailureCleanupDescriptorHasCloseOnExec(duplicate)) {
        if (duplicate >= 0) close(duplicate);
        return -1;
    }
    return duplicate;
}

static BOOL PXBackupFailureCleanupStrictSync(int descriptor) {
    if (descriptor < 0) return NO;
    int result = -1;
    do {
        result = fsync(descriptor);
    } while (result < 0 && errno == EINTR);
    return result == 0;
}


typedef enum {
    PXBackupFailureCleanupCaptureTypeRegularFile = 1,
    PXBackupFailureCleanupCaptureTypeDirectory = 2,
} PXBackupFailureCleanupCaptureType;

static BOOL PXBackupFailureCleanupEntryIsAbsent(int parentDescriptor,
                                                 const char *name);

static BOOL PXBackupFailureCleanupMoveNoReplace(
    int sourceParentDescriptor,
    const char *sourceName,
    int destinationParentDescriptor,
    const char *destinationName,
    int *failureErrnoOut) {
    if (failureErrnoOut) *failureErrnoOut = 0;
    if (sourceParentDescriptor < 0 || destinationParentDescriptor < 0 ||
        !sourceName || sourceName[0] == '\0' ||
        !destinationName || destinationName[0] == '\0') {
        if (failureErrnoOut) *failureErrnoOut = EINVAL;
        return NO;
    }
    int result = -1;
    int failureErrno = 0;
    do {
        result = renameatx_np(sourceParentDescriptor,
                              sourceName,
                              destinationParentDescriptor,
                              destinationName,
                              RENAME_EXCL);
        failureErrno = result == 0 ? 0 : errno;
    } while (result < 0 && failureErrno == EINTR);
    if (result == 0) return YES;
    if (failureErrnoOut) *failureErrnoOut = failureErrno;
    return NO;
}

static BOOL PXBackupFailureCleanupGenerateQuarantineName(
    char *buffer,
    size_t bufferSize) {
    static const char lowercaseHex[] = "0123456789abcdef";
    const size_t prefixLength = sizeof(PXBackupFailureCleanupQuarantinePrefix) - 1U;
    const size_t suffixLength = PXBackupFailureCleanupQuarantineRandomByteCount * 2U;
    const size_t requiredLength = prefixLength + suffixLength + 1U;
    if (!buffer || bufferSize < requiredLength ||
        requiredLength - 1U > PXBackupFailureCleanupMaximumComponentBytes) return NO;
    unsigned char randomBytes[PXBackupFailureCleanupQuarantineRandomByteCount];
    arc4random_buf(randomBytes, sizeof(randomBytes));
    memcpy(buffer, PXBackupFailureCleanupQuarantinePrefix, prefixLength);
    for (size_t index = 0; index < sizeof(randomBytes); index++) {
        unsigned char byte = randomBytes[index];
        buffer[prefixLength + (index * 2U)] = lowercaseHex[(byte >> 4U) & 0x0fU];
        buffer[prefixLength + (index * 2U) + 1U] = lowercaseHex[byte & 0x0fU];
    }
    buffer[requiredLength - 1U] = '\0';
    return YES;
}

static BOOL PXBackupFailureCleanupCapturedBindingValid(
    int parentDescriptor,
    const char *quarantineName,
    int retainedDescriptor,
    const struct stat *retainedIdentity,
    PXBackupFailureCleanupCaptureType captureType,
    dev_t expectedDevice,
    BOOL requireWorkspaceMode,
    struct stat *currentOut) {
    if (parentDescriptor < 0 || retainedDescriptor < 0 ||
        !quarantineName || quarantineName[0] == '\0' || !retainedIdentity) return NO;
    struct stat namespaceStat;
    struct stat descriptorStat;
    if (fstatat(parentDescriptor,
                quarantineName,
                &namespaceStat,
                AT_SYMLINK_NOFOLLOW) != 0 ||
        fstat(retainedDescriptor, &descriptorStat) != 0 ||
        namespaceStat.st_dev != expectedDevice ||
        descriptorStat.st_dev != expectedDevice ||
        (namespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        (descriptorStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        !PXBackupFailureCleanupStatIdentityMatches(&namespaceStat,
                                                   &descriptorStat) ||
        !PXBackupFailureCleanupStatIdentityMatches(retainedIdentity,
                                                   &descriptorStat) ||
        !PXBackupFailureCleanupDescriptorHasCloseOnExec(retainedDescriptor)) return NO;
    if (captureType == PXBackupFailureCleanupCaptureTypeRegularFile) {
        if (!S_ISREG(namespaceStat.st_mode) || !S_ISREG(descriptorStat.st_mode) ||
            namespaceStat.st_nlink != 1 || descriptorStat.st_nlink != 1 ||
            namespaceStat.st_mode != retainedIdentity->st_mode ||
            descriptorStat.st_mode != retainedIdentity->st_mode ||
            namespaceStat.st_size != retainedIdentity->st_size ||
            descriptorStat.st_size != retainedIdentity->st_size ||
            PX_BACKUP_CLEANUP_MTIME_SEC(namespaceStat) !=
                PX_BACKUP_CLEANUP_MTIME_SEC(*retainedIdentity) ||
            PX_BACKUP_CLEANUP_MTIME_NSEC(namespaceStat) !=
                PX_BACKUP_CLEANUP_MTIME_NSEC(*retainedIdentity) ||
            PX_BACKUP_CLEANUP_MTIME_SEC(descriptorStat) !=
                PX_BACKUP_CLEANUP_MTIME_SEC(*retainedIdentity) ||
            PX_BACKUP_CLEANUP_MTIME_NSEC(descriptorStat) !=
                PX_BACKUP_CLEANUP_MTIME_NSEC(*retainedIdentity)) return NO;
    } else if (captureType == PXBackupFailureCleanupCaptureTypeDirectory) {
        if (!S_ISDIR(namespaceStat.st_mode) || !S_ISDIR(descriptorStat.st_mode) ||
            (requireWorkspaceMode &&
             ((namespaceStat.st_mode & 07777) != 0700 ||
              (descriptorStat.st_mode & 07777) != 0700))) return NO;
    } else {
        return NO;
    }
    if (currentOut) *currentOut = descriptorStat;
    return YES;
}

static BOOL PXBackupFailureCleanupRollbackCapturedMismatch(
    int parentDescriptor,
    const char *quarantineName,
    const char *originalName) {
    if (!PXBackupFailureCleanupEntryIsAbsent(parentDescriptor, originalName)) {
        return NO;
    }
    int rollbackErrno = 0;
    if (!PXBackupFailureCleanupMoveNoReplace(parentDescriptor,
                                             quarantineName,
                                             parentDescriptor,
                                             originalName,
                                             &rollbackErrno) ||
        !PXBackupFailureCleanupStrictSync(parentDescriptor) ||
        !PXBackupFailureCleanupEntryIsAbsent(parentDescriptor, quarantineName)) {
        return NO;
    }
    struct stat restored;
    return fstatat(parentDescriptor,
                   originalName,
                   &restored,
                   AT_SYMLINK_NOFOLLOW) == 0;
}

static BOOL PXBackupFailureCleanupCaptureEntry(
    int parentDescriptor,
    const char *sourceName,
    int retainedDescriptor,
    const struct stat *retainedIdentity,
    PXBackupFailureCleanupCaptureType captureType,
    dev_t expectedDevice,
    BOOL requireWorkspaceMode,
    BOOL priorDestructiveMutation,
    char **quarantineNameOut,
    NSError **error) {
    if (quarantineNameOut) *quarantineNameOut = NULL;
    if (parentDescriptor < 0 || retainedDescriptor < 0 ||
        !sourceName || sourceName[0] == '\0' || !retainedIdentity ||
        !quarantineNameOut) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorInvalidInput,
            PXBackupFailureCleanupEntryField,
            @"The cleanup capture inputs are invalid");
        return NO;
    }
    const size_t quarantineCapacity =
        sizeof(PXBackupFailureCleanupQuarantinePrefix) +
        (PXBackupFailureCleanupQuarantineRandomByteCount * 2U);
    char quarantineName[sizeof(PXBackupFailureCleanupQuarantinePrefix) +
                        (PXBackupFailureCleanupQuarantineRandomByteCount * 2U)];
    BOOL moved = NO;
    int moveErrno = 0;
    for (NSUInteger attempt = 0;
         attempt < PXBackupFailureCleanupQuarantineAttemptLimit;
         attempt++) {
        if (!PXBackupFailureCleanupGenerateQuarantineName(quarantineName,
                                                          quarantineCapacity)) {
            PXBackupFailureCleanupSetError(
                error,
                priorDestructiveMutation
                    ? PXBackupFailureCleanupErrorCleanupIncomplete
                    : PXBackupFailureCleanupErrorLimitExceeded,
                PXBackupFailureCleanupEntryField,
                @"A private cleanup quarantine name could not be generated");
            return NO;
        }
        moveErrno = 0;
        if (PXBackupFailureCleanupMoveNoReplace(parentDescriptor,
                                                sourceName,
                                                parentDescriptor,
                                                quarantineName,
                                                &moveErrno)) {
            moved = YES;
            break;
        }
        if (moveErrno == EEXIST || moveErrno == ENOTEMPTY) continue;
        PXBackupFailureCleanupSetError(
            error,
            priorDestructiveMutation
                ? PXBackupFailureCleanupErrorCleanupIncomplete
                : PXBackupFailureCleanupErrorEntryChanged,
            PXBackupFailureCleanupEntryField,
            @"A cleanup entry changed before atomic capture");
        return NO;
    }
    if (!moved) {
        PXBackupFailureCleanupSetError(
            error,
            priorDestructiveMutation
                ? PXBackupFailureCleanupErrorCleanupIncomplete
                : PXBackupFailureCleanupErrorRemovalFailed,
            PXBackupFailureCleanupEntryField,
            @"A private cleanup quarantine name could not be reserved");
        return NO;
    }
    BOOL originalAbsent =
        PXBackupFailureCleanupEntryIsAbsent(parentDescriptor, sourceName);
    BOOL exactCapture = originalAbsent &&
        PXBackupFailureCleanupCapturedBindingValid(parentDescriptor,
                                                   quarantineName,
                                                   retainedDescriptor,
                                                   retainedIdentity,
                                                   captureType,
                                                   expectedDevice,
                                                   requireWorkspaceMode,
                                                   NULL);
    if (!exactCapture) {
        BOOL rollbackSucceeded = originalAbsent &&
            PXBackupFailureCleanupRollbackCapturedMismatch(parentDescriptor,
                                                           quarantineName,
                                                           sourceName);
        PXBackupFailureCleanupSetError(
            error,
            (!rollbackSucceeded && priorDestructiveMutation)
                ? PXBackupFailureCleanupErrorCleanupIncomplete
                : PXBackupFailureCleanupErrorEntryChanged,
            PXBackupFailureCleanupEntryField,
            rollbackSucceeded
                ? @"A changed cleanup entry was restored without deletion"
                : @"A changed cleanup entry could not be restored safely");
        return NO;
    }
    size_t quarantineLength = strlen(quarantineName);
    if (quarantineLength == 0 || quarantineLength > SIZE_MAX - 1U) {
        BOOL rollbackSucceeded =
            PXBackupFailureCleanupRollbackCapturedMismatch(parentDescriptor,
                                                           quarantineName,
                                                           sourceName);
        PXBackupFailureCleanupSetError(
            error,
            (!rollbackSucceeded && priorDestructiveMutation)
                ? PXBackupFailureCleanupErrorCleanupIncomplete
                : PXBackupFailureCleanupErrorLimitExceeded,
            PXBackupFailureCleanupEntryField,
            @"The private cleanup quarantine name exceeded fixed limits");
        return NO;
    }
    char *retainedName = malloc(quarantineLength + 1U);
    if (!retainedName) {
        BOOL rollbackSucceeded =
            PXBackupFailureCleanupRollbackCapturedMismatch(parentDescriptor,
                                                           quarantineName,
                                                           sourceName);
        PXBackupFailureCleanupSetError(
            error,
            (!rollbackSucceeded && priorDestructiveMutation)
                ? PXBackupFailureCleanupErrorCleanupIncomplete
                : PXBackupFailureCleanupErrorLimitExceeded,
            PXBackupFailureCleanupEntryField,
            @"The private cleanup quarantine name could not be retained");
        return NO;
    }
    memcpy(retainedName, quarantineName, quarantineLength + 1U);
    *quarantineNameOut = retainedName;
    return YES;
}

static BOOL PXBackupFailureCleanupStringContainsNUL(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return YES;
    for (NSUInteger index = 0; index < value.length; index++) {
        if ([value characterAtIndex:index] == 0) return YES;
    }
    return NO;
}

static BOOL PXBackupFailureCleanupStringContainsControl(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return YES;
    for (NSUInteger index = 0; index < value.length; index++) {
        unichar character = [value characterAtIndex:index];
        if (character < 0x20 || character == 0x7f) return YES;
    }
    return NO;
}

static NSData *PXBackupFailureCleanupLosslessUTF8Data(NSString *value,
                                                       NSUInteger maximumBytes,
                                                       BOOL requireAbsolute) {
    if (![value isKindOfClass:[NSString class]] || value.length == 0 ||
        PXBackupFailureCleanupStringContainsNUL(value) ||
        (requireAbsolute && ![value hasPrefix:@"/"])) return nil;
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding
                        allowLossyConversion:NO];
    if (!data || data.length == 0 || data.length > maximumBytes) return nil;
    NSString *roundTrip = [[NSString alloc] initWithData:data
                                                encoding:NSUTF8StringEncoding];
    return roundTrip && [roundTrip isEqualToString:value] ? data : nil;
}

static BOOL PXBackupFailureCleanupValidateComponentString(NSString *component,
                                                           NSData **dataOut) {
    if (dataOut) *dataOut = nil;
    NSData *data = PXBackupFailureCleanupLosslessUTF8Data(
        component,
        PXBackupFailureCleanupMaximumComponentBytes,
        NO);
    if (!data || PXBackupFailureCleanupStringContainsControl(component) ||
        [component isEqualToString:@"."] ||
        [component isEqualToString:@".."] ||
        [component containsString:@"/"] ||
        [component containsString:@"\\"]) return NO;
    if (dataOut) *dataOut = data;
    return YES;
}

static BOOL PXBackupFailureCleanupValidateEntryName(const char *name,
                                                     NSUInteger *lengthOut,
                                                     NSData **dataOut) {
    if (lengthOut) *lengthOut = 0;
    if (dataOut) *dataOut = nil;
    if (!name) return NO;
    size_t length = 0;
    while (length <= PXBackupFailureCleanupMaximumComponentBytes &&
           name[length] != '\0') {
        length += 1U;
    }
    const size_t quarantinePrefixLength =
        sizeof(PXBackupFailureCleanupQuarantinePrefix) - 1U;
    if (length == 0 || length > PXBackupFailureCleanupMaximumComponentBytes ||
        (length == 1U && name[0] == '.') ||
        (length == 2U && name[0] == '.' && name[1] == '.') ||
        (length >= quarantinePrefixLength &&
         memcmp(name,
                PXBackupFailureCleanupQuarantinePrefix,
                quarantinePrefixLength) == 0)) return NO;
    for (size_t index = 0; index < length; index++) {
        unsigned char byte = (unsigned char)name[index];
        if (byte == '/' || byte == '\\' || byte < 0x20 || byte == 0x7f) return NO;
    }
    NSData *data = [NSData dataWithBytes:name length:length];
    NSString *string = [[NSString alloc] initWithData:data
                                              encoding:NSUTF8StringEncoding];
    NSData *roundTrip = [string dataUsingEncoding:NSUTF8StringEncoding
                              allowLossyConversion:NO];
    if (!string || !roundTrip || ![roundTrip isEqualToData:data] ||
        PXBackupFailureCleanupStringContainsControl(string)) return NO;
    if (lengthOut) *lengthOut = (NSUInteger)length;
    if (dataOut) *dataOut = data;
    return YES;
}

static char *PXBackupFailureCleanupCopyCString(NSData *data) {
    if (![data isKindOfClass:[NSData class]] || data.length == 0 ||
        data.length > SIZE_MAX - 1U) return NULL;
    char *bytes = malloc(data.length + 1U);
    if (!bytes) return NULL;
    memcpy(bytes, data.bytes, data.length);
    bytes[data.length] = '\0';
    return bytes;
}

static BOOL PXBackupFailureCleanupEntryIsAbsent(int parentDescriptor,
                                                 const char *name) {
    if (parentDescriptor < 0 || !name || name[0] == '\0') return NO;
    struct stat current;
    if (fstatat(parentDescriptor, name, &current, AT_SYMLINK_NOFOLLOW) == 0) {
        return NO;
    }
    return errno == ENOENT;
}

static BOOL PXBackupFailureCleanupPathMatchesDescriptor(
    NSString *path,
    int descriptor,
    const struct stat *expected,
    BOOL requireWorkspaceMode,
    struct stat *currentOut) {
    NSData *pathData = PXBackupFailureCleanupLosslessUTF8Data(
        path,
        PXBackupFailureCleanupMaximumWorkspacePathBytes,
        YES);
    char *pathBytes = PXBackupFailureCleanupCopyCString(pathData);
    if (!pathBytes || descriptor < 0 || !expected) {
        free(pathBytes);
        return NO;
    }
    struct stat pathStat;
    struct stat descriptorStat;
    BOOL valid = lstat(pathBytes, &pathStat) == 0 &&
                 !S_ISLNK(pathStat.st_mode) && S_ISDIR(pathStat.st_mode) &&
                 (pathStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
                 fstat(descriptor, &descriptorStat) == 0 &&
                 S_ISDIR(descriptorStat.st_mode) &&
                 (descriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
                 (!requireWorkspaceMode ||
                  (descriptorStat.st_mode & 07777) == 0700) &&
                 PXBackupFailureCleanupStatIdentityMatches(&pathStat,
                                                           &descriptorStat) &&
                 PXBackupFailureCleanupStatIdentityMatches(expected,
                                                           &descriptorStat) &&
                 PXBackupFailureCleanupDescriptorHasCloseOnExec(descriptor);
    if (valid && currentOut) *currentOut = descriptorStat;
    free(pathBytes);
    return valid;
}

static BOOL PXBackupFailureCleanupDirectoryBindingValid(
    int parentDescriptor,
    const char *name,
    int descriptor,
    const struct stat *expected,
    dev_t expectedDevice,
    BOOL requireWorkspaceMode,
    struct stat *currentOut) {
    if (parentDescriptor < 0 || descriptor < 0 || !name || name[0] == '\0' ||
        !expected) return NO;
    struct stat namespaceStat;
    struct stat descriptorStat;
    if (fstatat(parentDescriptor,
                name,
                &namespaceStat,
                AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(namespaceStat.st_mode) ||
        (namespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        fstat(descriptor, &descriptorStat) != 0 ||
        !S_ISDIR(descriptorStat.st_mode) ||
        (descriptorStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        (requireWorkspaceMode && (descriptorStat.st_mode & 07777) != 0700) ||
        namespaceStat.st_dev != expectedDevice ||
        descriptorStat.st_dev != expectedDevice ||
        !PXBackupFailureCleanupStatIdentityMatches(&namespaceStat,
                                                   &descriptorStat) ||
        !PXBackupFailureCleanupStatIdentityMatches(expected,
                                                   &descriptorStat) ||
        !PXBackupFailureCleanupDescriptorHasCloseOnExec(descriptor)) return NO;
    if (currentOut) *currentOut = descriptorStat;
    return YES;
}

static BOOL PXBackupFailureCleanupReadDirectory(
    int descriptor,
    PXBackupFailureCleanupTraversalState *state,
    BOOL collectNames,
    NSArray<NSData *> **namesOut,
    BOOL *emptyOut,
    NSError **error) {
    if (namesOut) *namesOut = nil;
    if (emptyOut) *emptyOut = NO;
    if (descriptor < 0 || (collectNames && !state)) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorTraversalFailed,
            PXBackupFailureCleanupEntryField,
            @"The cleanup directory could not be traversed");
        return NO;
    }
    int duplicate = PXBackupFailureCleanupDuplicateDescriptor(descriptor);
    if (duplicate < 0) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorTraversalFailed,
            PXBackupFailureCleanupEntryField,
            @"The cleanup directory could not be traversed");
        return NO;
    }
    DIR *directory = fdopendir(duplicate);
    if (!directory) {
        close(duplicate);
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorTraversalFailed,
            PXBackupFailureCleanupEntryField,
            @"The cleanup directory could not be traversed");
        return NO;
    }
    NSMutableArray<NSData *> *names = collectNames ? [NSMutableArray array] : nil;
    BOOL empty = YES;
    BOOL valid = YES;
    for (;;) {
        errno = 0;
        struct dirent *entry = readdir(directory);
        if (!entry) {
            if (errno != 0) valid = NO;
            break;
        }
        if (strcmp(entry->d_name, ".") == 0 ||
            strcmp(entry->d_name, "..") == 0) continue;
        empty = NO;
        if (!collectNames) continue;
        NSUInteger nameLength = 0;
        NSData *nameData = nil;
        if (!PXBackupFailureCleanupValidateEntryName(entry->d_name,
                                                     &nameLength,
                                                     &nameData)) {
            PXBackupFailureCleanupSetError(
                error,
                PXBackupFailureCleanupErrorUnsafeEntry,
                PXBackupFailureCleanupEntryField,
                @"The cleanup tree contains an unsafe entry name");
            valid = NO;
            break;
        }
        if (state->visitedEntries >=
                PXBackupFailureCleanupMaximumVisitedEntries ||
            nameLength > ULLONG_MAX - state->accumulatedNameBytes ||
            state->accumulatedNameBytes + nameLength >
                PXBackupFailureCleanupMaximumAccumulatedNameBytes) {
            PXBackupFailureCleanupSetError(
                error,
                PXBackupFailureCleanupErrorLimitExceeded,
                PXBackupFailureCleanupEntryField,
                @"The cleanup tree exceeds fixed traversal limits");
            valid = NO;
            break;
        }
        state->visitedEntries += 1U;
        state->accumulatedNameBytes += nameLength;
        [names addObject:nameData];
    }
    if (closedir(directory) != 0 && valid) valid = NO;
    if (!valid) {
        if (error && !*error) {
            PXBackupFailureCleanupSetError(
                error,
                PXBackupFailureCleanupErrorTraversalFailed,
                PXBackupFailureCleanupEntryField,
                @"The cleanup directory scan failed");
        }
        return NO;
    }
    if (collectNames && namesOut) *namesOut = [names copy];
    if (emptyOut) *emptyOut = empty;
    return YES;
}

static BOOL PXBackupFailureCleanupDirectoryIsEmpty(int descriptor,
                                                    BOOL *emptyOut,
                                                    NSError **error) {
    return PXBackupFailureCleanupReadDirectory(descriptor,
                                               NULL,
                                               NO,
                                               NULL,
                                               emptyOut,
                                               error);
}

static BOOL PXBackupFailureCleanupScanEntryNames(
    int descriptor,
    PXBackupFailureCleanupTraversalState *state,
    NSArray<NSData *> **namesOut,
    NSError **error) {
    return PXBackupFailureCleanupReadDirectory(descriptor,
                                               state,
                                               YES,
                                               namesOut,
                                               NULL,
                                               error);
}

static BOOL PXBackupFailureCleanupRemoveDirectoryContents(
    int descriptor,
    const struct stat *directoryIdentity,
    NSUInteger depth,
    PXBackupFailureCleanupTraversalState *state,
    NSError **error);

static BOOL PXBackupFailureCleanupRemoveRegularFile(
    int parentDescriptor,
    const char *name,
    const struct stat *observed,
    PXBackupFailureCleanupTraversalState *state,
    NSError **error) {
    if (!observed || !state || !S_ISREG(observed->st_mode) ||
        observed->st_dev != state->workspaceDevice ||
        (observed->st_mode & (S_ISUID | S_ISGID)) != 0 ||
        observed->st_nlink != 1) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorUnsafeEntry,
            PXBackupFailureCleanupEntryField,
            @"The cleanup tree contains an unsafe regular file");
        return NO;
    }
    int descriptor = openat(parentDescriptor,
                            name,
                            O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
    if (descriptor < 0) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorEntryChanged,
            PXBackupFailureCleanupEntryField,
            @"A cleanup file changed before it could be opened");
        return NO;
    }
    struct stat descriptorStat;
    struct stat namespaceStat;
    BOOL valid = fstat(descriptor, &descriptorStat) == 0 &&
                 S_ISREG(descriptorStat.st_mode) &&
                 descriptorStat.st_dev == state->workspaceDevice &&
                 (descriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
                 descriptorStat.st_nlink == 1 &&
                 PXBackupFailureCleanupStableFileMatches(observed,
                                                         &descriptorStat) &&
                 PXBackupFailureCleanupDescriptorHasCloseOnExec(descriptor) &&
                 fstatat(parentDescriptor,
                         name,
                         &namespaceStat,
                         AT_SYMLINK_NOFOLLOW) == 0 &&
                 PXBackupFailureCleanupStableFileMatches(&namespaceStat,
                                                         &descriptorStat);
    if (!valid) {
        close(descriptor);
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorEntryChanged,
            PXBackupFailureCleanupEntryField,
            @"A cleanup file changed during identity validation");
        return NO;
    }
    if (state->removedEntries == NSUIntegerMax) {
        close(descriptor);
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorLimitExceeded,
            PXBackupFailureCleanupEntryField,
            @"The cleanup removal count overflowed");
        return NO;
    }
    char *quarantineName = NULL;
    if (!PXBackupFailureCleanupCaptureEntry(
            parentDescriptor,
            name,
            descriptor,
            &descriptorStat,
            PXBackupFailureCleanupCaptureTypeRegularFile,
            state->workspaceDevice,
            NO,
            state->destructiveMutationOccurred || state->removedEntries > 0,
            &quarantineName,
            error)) {
        close(descriptor);
        return NO;
    }
    if (!PXBackupFailureCleanupCapturedBindingValid(
            parentDescriptor,
            quarantineName,
            descriptor,
            &descriptorStat,
            PXBackupFailureCleanupCaptureTypeRegularFile,
            state->workspaceDevice,
            NO,
            NULL)) {
        free(quarantineName);
        close(descriptor);
        PXBackupFailureCleanupSetError(
            error,
            state->destructiveMutationOccurred || state->removedEntries > 0
                ? PXBackupFailureCleanupErrorCleanupIncomplete
                : PXBackupFailureCleanupErrorEntryChanged,
            PXBackupFailureCleanupEntryField,
            @"A quarantined cleanup file changed before removal");
        return NO;
    }
    if (unlinkat(parentDescriptor, quarantineName, 0) != 0) {
        free(quarantineName);
        close(descriptor);
        PXBackupFailureCleanupSetError(
            error,
            state->destructiveMutationOccurred || state->removedEntries > 0
                ? PXBackupFailureCleanupErrorCleanupIncomplete
                : PXBackupFailureCleanupErrorRemovalFailed,
            PXBackupFailureCleanupEntryField,
            @"A quarantined cleanup file could not be removed");
        return NO;
    }
    state->destructiveMutationOccurred = YES;
    struct stat unlinkedStat;
    BOOL removed =
        PXBackupFailureCleanupEntryIsAbsent(parentDescriptor, quarantineName) &&
        fstat(descriptor, &unlinkedStat) == 0 &&
        PXBackupFailureCleanupStatIdentityMatches(&descriptorStat,
                                                  &unlinkedStat) &&
        unlinkedStat.st_nlink == 0;
    free(quarantineName);
    close(descriptor);
    if (!removed) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorCleanupIncomplete,
            PXBackupFailureCleanupEntryField,
            @"A cleanup file removal could not be proven");
        return NO;
    }
    if (!PXBackupFailureCleanupStrictSync(parentDescriptor)) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorCleanupIncomplete,
            PXBackupFailureCleanupDurabilityField,
            @"A cleanup file removal could not be synchronized");
        return NO;
    }
    state->removedEntries += 1U;
    return YES;
}

static BOOL PXBackupFailureCleanupRemoveSubdirectory(
    int parentDescriptor,
    const char *name,
    const struct stat *observed,
    NSUInteger depth,
    PXBackupFailureCleanupTraversalState *state,
    NSError **error) {
    if (!observed || !state || !S_ISDIR(observed->st_mode) ||
        observed->st_dev != state->workspaceDevice ||
        (observed->st_mode & (S_ISUID | S_ISGID)) != 0) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorUnsafeEntry,
            PXBackupFailureCleanupEntryField,
            @"The cleanup tree contains an unsafe directory");
        return NO;
    }
    if (depth >= PXBackupFailureCleanupMaximumDepth) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorLimitExceeded,
            PXBackupFailureCleanupEntryField,
            @"The cleanup tree exceeds the maximum depth");
        return NO;
    }
    int descriptor = openat(parentDescriptor,
                            name,
                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (descriptor < 0) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorEntryChanged,
            PXBackupFailureCleanupEntryField,
            @"A cleanup directory changed before it could be opened");
        return NO;
    }
    struct stat descriptorStat;
    BOOL bindingValid = fstat(descriptor, &descriptorStat) == 0 &&
                        S_ISDIR(descriptorStat.st_mode) &&
                        descriptorStat.st_dev == state->workspaceDevice &&
                        (descriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
                        PXBackupFailureCleanupStatIdentityMatches(observed,
                                                                 &descriptorStat) &&
                        PXBackupFailureCleanupDescriptorHasCloseOnExec(descriptor);
    if (!bindingValid) {
        close(descriptor);
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorEntryChanged,
            PXBackupFailureCleanupEntryField,
            @"A cleanup directory changed during identity validation");
        return NO;
    }
    if (!PXBackupFailureCleanupRemoveDirectoryContents(descriptor,
                                                       &descriptorStat,
                                                       depth + 1U,
                                                       state,
                                                       error)) {
        close(descriptor);
        return NO;
    }
    BOOL empty = NO;
    if (!PXBackupFailureCleanupDirectoryIsEmpty(descriptor, &empty, error) ||
        !empty) {
        close(descriptor);
        if (error && !*error) {
            PXBackupFailureCleanupSetError(
                error,
                PXBackupFailureCleanupErrorEntryChanged,
                PXBackupFailureCleanupEntryField,
                @"A cleanup directory was repopulated during traversal");
        }
        return NO;
    }
    if (!PXBackupFailureCleanupStrictSync(descriptor)) {
        close(descriptor);
        PXBackupFailureCleanupSetError(
            error,
            state->destructiveMutationOccurred || state->removedEntries > 0
                ? PXBackupFailureCleanupErrorCleanupIncomplete
                : PXBackupFailureCleanupErrorDurabilityFailed,
            PXBackupFailureCleanupDurabilityField,
            @"A cleanup directory could not be synchronized");
        return NO;
    }
    struct stat namespaceStat;
    struct stat currentDescriptorStat;
    BOOL stable = fstatat(parentDescriptor,
                          name,
                          &namespaceStat,
                          AT_SYMLINK_NOFOLLOW) == 0 &&
                  fstat(descriptor, &currentDescriptorStat) == 0 &&
                  S_ISDIR(namespaceStat.st_mode) &&
                  S_ISDIR(currentDescriptorStat.st_mode) &&
                  namespaceStat.st_dev == state->workspaceDevice &&
                  currentDescriptorStat.st_dev == state->workspaceDevice &&
                  (namespaceStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
                  (currentDescriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
                  PXBackupFailureCleanupStatIdentityMatches(&namespaceStat,
                                                            &descriptorStat) &&
                  PXBackupFailureCleanupStatIdentityMatches(&currentDescriptorStat,
                                                            &descriptorStat);
    if (!stable) {
        close(descriptor);
        PXBackupFailureCleanupSetError(
            error,
            state->destructiveMutationOccurred || state->removedEntries > 0
                ? PXBackupFailureCleanupErrorCleanupIncomplete
                : PXBackupFailureCleanupErrorEntryChanged,
            PXBackupFailureCleanupEntryField,
            @"A cleanup directory changed before atomic capture");
        return NO;
    }
    if (state->removedEntries == NSUIntegerMax) {
        close(descriptor);
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorLimitExceeded,
            PXBackupFailureCleanupEntryField,
            @"The cleanup removal count overflowed");
        return NO;
    }
    char *quarantineName = NULL;
    if (!PXBackupFailureCleanupCaptureEntry(
            parentDescriptor,
            name,
            descriptor,
            &descriptorStat,
            PXBackupFailureCleanupCaptureTypeDirectory,
            state->workspaceDevice,
            NO,
            state->destructiveMutationOccurred || state->removedEntries > 0,
            &quarantineName,
            error)) {
        close(descriptor);
        return NO;
    }
    BOOL capturedEmpty = NO;
    NSError *capturedEmptyError = nil;
    BOOL capturedValid =
        PXBackupFailureCleanupCapturedBindingValid(
            parentDescriptor,
            quarantineName,
            descriptor,
            &descriptorStat,
            PXBackupFailureCleanupCaptureTypeDirectory,
            state->workspaceDevice,
            NO,
            NULL) &&
        PXBackupFailureCleanupDirectoryIsEmpty(descriptor,
                                               &capturedEmpty,
                                               &capturedEmptyError) &&
        capturedEmpty;
    if (!capturedValid) {
        free(quarantineName);
        close(descriptor);
        if (error) {
            *error = capturedEmptyError;
            if (!*error) {
                PXBackupFailureCleanupSetError(
                    error,
                    state->destructiveMutationOccurred || state->removedEntries > 0
                        ? PXBackupFailureCleanupErrorCleanupIncomplete
                        : PXBackupFailureCleanupErrorEntryChanged,
                    PXBackupFailureCleanupEntryField,
                    @"A quarantined cleanup directory changed before removal");
            }
        }
        return NO;
    }
    if (unlinkat(parentDescriptor, quarantineName, AT_REMOVEDIR) != 0) {
        free(quarantineName);
        close(descriptor);
        PXBackupFailureCleanupSetError(
            error,
            state->destructiveMutationOccurred || state->removedEntries > 0
                ? PXBackupFailureCleanupErrorCleanupIncomplete
                : PXBackupFailureCleanupErrorRemovalFailed,
            PXBackupFailureCleanupEntryField,
            @"A quarantined cleanup directory could not be removed");
        return NO;
    }
    state->destructiveMutationOccurred = YES;
    BOOL removed =
        PXBackupFailureCleanupEntryIsAbsent(parentDescriptor, quarantineName);
    free(quarantineName);
    close(descriptor);
    if (!removed) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorCleanupIncomplete,
            PXBackupFailureCleanupEntryField,
            @"A cleanup directory removal could not be proven");
        return NO;
    }
    if (!PXBackupFailureCleanupStrictSync(parentDescriptor)) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorCleanupIncomplete,
            PXBackupFailureCleanupDurabilityField,
            @"A cleanup directory removal could not be synchronized");
        return NO;
    }
    state->removedEntries += 1U;
    return YES;
}

static BOOL PXBackupFailureCleanupRemoveDirectoryContents(
    int descriptor,
    const struct stat *directoryIdentity,
    NSUInteger depth,
    PXBackupFailureCleanupTraversalState *state,
    NSError **error) {
    if (descriptor < 0 || !directoryIdentity || !state ||
        depth > PXBackupFailureCleanupMaximumDepth) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorLimitExceeded,
            PXBackupFailureCleanupEntryField,
            @"The cleanup traversal exceeded fixed limits");
        return NO;
    }
    struct stat currentDirectory;
    if (fstat(descriptor, &currentDirectory) != 0 ||
        !S_ISDIR(currentDirectory.st_mode) ||
        currentDirectory.st_dev != state->workspaceDevice ||
        (currentDirectory.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        !PXBackupFailureCleanupStatIdentityMatches(directoryIdentity,
                                                   &currentDirectory) ||
        !PXBackupFailureCleanupDescriptorHasCloseOnExec(descriptor)) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorEntryChanged,
            PXBackupFailureCleanupEntryField,
            @"A cleanup directory identity changed during traversal");
        return NO;
    }
    NSArray<NSData *> *names = nil;
    if (!PXBackupFailureCleanupScanEntryNames(descriptor,
                                              state,
                                              &names,
                                              error)) return NO;
    for (NSData *nameData in names) {
        char *name = PXBackupFailureCleanupCopyCString(nameData);
        if (!name) {
            PXBackupFailureCleanupSetError(
                error,
                PXBackupFailureCleanupErrorLimitExceeded,
                PXBackupFailureCleanupEntryField,
                @"A cleanup entry name could not be represented safely");
            return NO;
        }
        struct stat observed;
        BOOL observedValid = fstatat(descriptor,
                                     name,
                                     &observed,
                                     AT_SYMLINK_NOFOLLOW) == 0;
        if (!observedValid) {
            free(name);
            PXBackupFailureCleanupSetError(
                error,
                PXBackupFailureCleanupErrorEntryChanged,
                PXBackupFailureCleanupEntryField,
                @"A cleanup entry changed before inspection");
            return NO;
        }
        BOOL removed = NO;
        if (S_ISREG(observed.st_mode)) {
            removed = PXBackupFailureCleanupRemoveRegularFile(descriptor,
                                                              name,
                                                              &observed,
                                                              state,
                                                              error);
        } else if (S_ISDIR(observed.st_mode)) {
            removed = PXBackupFailureCleanupRemoveSubdirectory(descriptor,
                                                               name,
                                                               &observed,
                                                               depth,
                                                               state,
                                                               error);
        } else {
            PXBackupFailureCleanupSetError(
                error,
                PXBackupFailureCleanupErrorUnsafeEntry,
                PXBackupFailureCleanupEntryField,
                @"The cleanup tree contains an unsupported entry type");
        }
        free(name);
        if (!removed) return NO;
    }
    BOOL empty = NO;
    if (!PXBackupFailureCleanupDirectoryIsEmpty(descriptor, &empty, error)) {
        return NO;
    }
    if (!empty) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorEntryChanged,
            PXBackupFailureCleanupEntryField,
            @"The cleanup directory changed during traversal");
        return NO;
    }
    return YES;
}

static BOOL PXBackupFailureCleanupRemoveExactEmptyWorkspace(
    int parentDescriptor,
    const char *workspaceName,
    int workspaceDescriptor,
    const struct stat *workspaceIdentity,
    dev_t expectedDevice) {
    BOOL empty = NO;
    NSError *ignoredError = nil;
    if (!PXBackupFailureCleanupDirectoryBindingValid(parentDescriptor,
                                                     workspaceName,
                                                     workspaceDescriptor,
                                                     workspaceIdentity,
                                                     expectedDevice,
                                                     YES,
                                                     NULL) ||
        !PXBackupFailureCleanupDirectoryIsEmpty(workspaceDescriptor,
                                                &empty,
                                                &ignoredError) ||
        !empty ||
        !PXBackupFailureCleanupStrictSync(workspaceDescriptor)) return NO;
    char *quarantineName = NULL;
    if (!PXBackupFailureCleanupCaptureEntry(
            parentDescriptor,
            workspaceName,
            workspaceDescriptor,
            workspaceIdentity,
            PXBackupFailureCleanupCaptureTypeDirectory,
            expectedDevice,
            YES,
            NO,
            &quarantineName,
            &ignoredError)) return NO;
    BOOL capturedEmpty = NO;
    BOOL capturedValid =
        PXBackupFailureCleanupCapturedBindingValid(
            parentDescriptor,
            quarantineName,
            workspaceDescriptor,
            workspaceIdentity,
            PXBackupFailureCleanupCaptureTypeDirectory,
            expectedDevice,
            YES,
            NULL) &&
        PXBackupFailureCleanupDirectoryIsEmpty(workspaceDescriptor,
                                               &capturedEmpty,
                                               &ignoredError) &&
        capturedEmpty;
    if (!capturedValid ||
        unlinkat(parentDescriptor, quarantineName, AT_REMOVEDIR) != 0) {
        free(quarantineName);
        return NO;
    }
    BOOL removed = PXBackupFailureCleanupEntryIsAbsent(parentDescriptor,
                                                       quarantineName) &&
                   PXBackupFailureCleanupEntryIsAbsent(parentDescriptor,
                                                       workspaceName) &&
                   PXBackupFailureCleanupStrictSync(parentDescriptor);
    free(quarantineName);
    return removed;
}

@interface PXBackupFailureCleanup () {
    PXBackupPublicationWorkspace *_workspace;
    PXBackupBundleLock *_bundleLock;
    NSString *_parentPath;
    NSString *_workspacePath;
    NSString *_workspaceName;
    int _parentDescriptor;
    int _workspaceDescriptor;
    struct stat _parentIdentity;
    struct stat _workspaceIdentity;
    BOOL _cleanupAttempted;
    BOOL _cleaned;
    BOOL _disarmed;
    NSUInteger _removedEntryCount;
}

- (instancetype)initWithWorkspace:(PXBackupPublicationWorkspace *)workspace
                       bundleLock:(PXBackupBundleLock *)bundleLock
                       parentPath:(NSString *)parentPath
                    workspacePath:(NSString *)workspacePath
                    workspaceName:(NSString *)workspaceName
                 parentDescriptor:(int)parentDescriptor
              workspaceDescriptor:(int)workspaceDescriptor
                   parentIdentity:(const struct stat *)parentIdentity
                workspaceIdentity:(const struct stat *)workspaceIdentity;

- (BOOL)validateActiveIdentityAllowAttempted:(BOOL)allowAttempted
                                       error:(NSError **)error;

@end

@implementation PXBackupFailureCleanup

+ (instancetype)cleanupForWorkspace:(PXBackupPublicationWorkspace *)workspace
                         bundleLock:(PXBackupBundleLock *)bundleLock
                              error:(NSError **)error {
    if (error) *error = nil;
    NSError *setupError = nil;
    NSError *lockError = nil;
    NSError *workspaceError = nil;
    NSString *parentPath = nil;
    NSString *workspacePath = nil;
    NSString *workspaceName = nil;
    NSString *expectedWorkspacePath = nil;
    NSData *parentPathData = nil;
    NSData *workspaceNameData = nil;
    char *parentPathBytes = NULL;
    char *workspaceNameBytes = NULL;
    int parentDescriptor = -1;
    int workspaceDescriptor = -1;
    BOOL authorityEstablished = NO;
    PXBackupFailureCleanup *cleanup = nil;
    struct stat parentPathStat;
    struct stat parentDescriptorStat;
    struct stat workspaceNamespaceStat;
    struct stat workspaceDescriptorStat;
    memset(&parentPathStat, 0, sizeof(parentPathStat));
    memset(&parentDescriptorStat, 0, sizeof(parentDescriptorStat));
    memset(&workspaceNamespaceStat, 0, sizeof(workspaceNamespaceStat));
    memset(&workspaceDescriptorStat, 0, sizeof(workspaceDescriptorStat));

    if (![workspace isMemberOfClass:[PXBackupPublicationWorkspace class]] ||
        ![bundleLock isMemberOfClass:[PXBackupBundleLock class]]) {
        PXBackupFailureCleanupSetError(
            &setupError,
            PXBackupFailureCleanupErrorInvalidInput,
            PXBackupFailureCleanupField,
            @"The backup cleanup inputs are invalid");
        goto finish;
    }
    parentPath = bundleLock.canonicalBundleDirectoryPath;
    workspacePath = workspace.workspacePath;
    workspaceName = workspace.workspaceName;
    expectedWorkspacePath =
        [parentPath stringByAppendingPathComponent:workspaceName];
    if (![workspace.bundleIdentifier isEqualToString:bundleLock.bundleIdentifier] ||
        ![workspace.canonicalBundleDirectoryPath isEqualToString:parentPath] ||
        ![workspaceName hasPrefix:PXBackupPublicationPartialDirectoryPrefix] ||
        ![workspacePath isEqualToString:expectedWorkspacePath]) {
        PXBackupFailureCleanupSetError(
            &setupError,
            PXBackupFailureCleanupErrorInvalidInput,
            PXBackupFailureCleanupWorkspaceField,
            @"The backup cleanup identity is inconsistent");
        goto finish;
    }
    parentPathData = PXBackupFailureCleanupLosslessUTF8Data(
        parentPath,
        PXBackupFailureCleanupMaximumWorkspacePathBytes,
        YES);
    if (!parentPathData ||
        !PXBackupFailureCleanupValidateComponentString(workspaceName,
                                                       &workspaceNameData)) {
        PXBackupFailureCleanupSetError(
            &setupError,
            PXBackupFailureCleanupErrorLimitExceeded,
            PXBackupFailureCleanupWorkspaceField,
            @"The backup cleanup path exceeds fixed limits");
        goto finish;
    }
    lockError = nil;
    if (![bundleLock validateOwnershipWithError:&lockError]) {
        PXBackupFailureCleanupSetError(
            &setupError,
            PXBackupFailureCleanupErrorLockValidationFailed,
            PXBackupFailureCleanupLockField,
            @"The backup lock failed cleanup validation");
        goto finish;
    }
    workspaceError = nil;
    if (![workspace validateIdentityWithError:&workspaceError]) {
        PXBackupFailureCleanupSetError(
            &setupError,
            PXBackupFailureCleanupErrorWorkspaceInspectionFailed,
            PXBackupFailureCleanupWorkspaceField,
            @"The backup workspace failed cleanup validation");
        goto finish;
    }
    parentPathBytes = PXBackupFailureCleanupCopyCString(parentPathData);
    workspaceNameBytes = PXBackupFailureCleanupCopyCString(workspaceNameData);
    if (!parentPathBytes || !workspaceNameBytes) {
        PXBackupFailureCleanupSetError(
            &setupError,
            PXBackupFailureCleanupErrorLimitExceeded,
            PXBackupFailureCleanupField,
            @"The backup cleanup path could not be represented safely");
        goto finish;
    }
    if (lstat(parentPathBytes, &parentPathStat) != 0 ||
        S_ISLNK(parentPathStat.st_mode) ||
        !S_ISDIR(parentPathStat.st_mode) ||
        (parentPathStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
        PXBackupFailureCleanupSetError(
            &setupError,
            PXBackupFailureCleanupErrorParentInspectionFailed,
            PXBackupFailureCleanupParentField,
            @"The backup cleanup parent is invalid");
        goto finish;
    }
    parentDescriptor = open(parentPathBytes,
                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (parentDescriptor < 0 ||
        fstat(parentDescriptor, &parentDescriptorStat) != 0 ||
        !S_ISDIR(parentDescriptorStat.st_mode) ||
        (parentDescriptorStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        !PXBackupFailureCleanupStatIdentityMatches(&parentPathStat,
                                                   &parentDescriptorStat) ||
        !PXBackupFailureCleanupDescriptorHasCloseOnExec(parentDescriptor)) {
        PXBackupFailureCleanupSetError(
            &setupError,
            PXBackupFailureCleanupErrorParentInspectionFailed,
            PXBackupFailureCleanupParentField,
            @"The backup cleanup parent descriptor is invalid");
        goto finish;
    }
    if (fstatat(parentDescriptor,
                workspaceNameBytes,
                &workspaceNamespaceStat,
                AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(workspaceNamespaceStat.st_mode) ||
        (workspaceNamespaceStat.st_mode & 07777) != 0700 ||
        (workspaceNamespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        workspaceNamespaceStat.st_dev != parentDescriptorStat.st_dev) {
        PXBackupFailureCleanupSetError(
            &setupError,
            PXBackupFailureCleanupErrorWorkspaceInspectionFailed,
            PXBackupFailureCleanupWorkspaceField,
            @"The backup cleanup workspace namespace is invalid");
        goto finish;
    }
    workspaceDescriptor = openat(parentDescriptor,
                                 workspaceNameBytes,
                                 O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (workspaceDescriptor < 0 ||
        fstat(workspaceDescriptor, &workspaceDescriptorStat) != 0 ||
        !S_ISDIR(workspaceDescriptorStat.st_mode) ||
        (workspaceDescriptorStat.st_mode & 07777) != 0700 ||
        (workspaceDescriptorStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        workspaceDescriptorStat.st_dev != parentDescriptorStat.st_dev ||
        !PXBackupFailureCleanupStatIdentityMatches(&workspaceNamespaceStat,
                                                   &workspaceDescriptorStat) ||
        !PXBackupFailureCleanupDescriptorHasCloseOnExec(workspaceDescriptor) ||
        !PXBackupFailureCleanupPathMatchesDescriptor(workspacePath,
                                                     workspaceDescriptor,
                                                     &workspaceDescriptorStat,
                                                     YES,
                                                     NULL)) {
        PXBackupFailureCleanupSetError(
            &setupError,
            PXBackupFailureCleanupErrorWorkspaceInspectionFailed,
            PXBackupFailureCleanupWorkspaceField,
            @"The backup cleanup workspace descriptor is invalid");
        goto finish;
    }
    authorityEstablished = YES;
    workspaceError = nil;
    if (![workspace validateIdentityWithError:&workspaceError] ||
        !PXBackupFailureCleanupDirectoryBindingValid(parentDescriptor,
                                                     workspaceNameBytes,
                                                     workspaceDescriptor,
                                                     &workspaceDescriptorStat,
                                                     parentDescriptorStat.st_dev,
                                                     YES,
                                                     NULL)) {
        PXBackupFailureCleanupSetError(
            &setupError,
            PXBackupFailureCleanupErrorWorkspaceChanged,
            PXBackupFailureCleanupWorkspaceField,
            @"The backup cleanup workspace identity changed");
        goto finish;
    }
    cleanup = [[PXBackupFailureCleanup alloc]
        initWithWorkspace:workspace
               bundleLock:bundleLock
               parentPath:parentPath
            workspacePath:workspacePath
            workspaceName:workspaceName
         parentDescriptor:parentDescriptor
      workspaceDescriptor:workspaceDescriptor
           parentIdentity:&parentDescriptorStat
        workspaceIdentity:&workspaceDescriptorStat];
    if (!cleanup) {
        PXBackupFailureCleanupSetError(
            &setupError,
            PXBackupFailureCleanupErrorWorkspaceInspectionFailed,
            PXBackupFailureCleanupWorkspaceField,
            @"The backup cleanup authority could not be retained");
        goto finish;
    }
    parentDescriptor = -1;
    workspaceDescriptor = -1;

finish:
    if (!cleanup && authorityEstablished) {
        BOOL factoryCleanupSucceeded =
            PXBackupFailureCleanupRemoveExactEmptyWorkspace(
                parentDescriptor,
                workspaceNameBytes,
                workspaceDescriptor,
                &workspaceDescriptorStat,
                parentDescriptorStat.st_dev);
        if (!factoryCleanupSucceeded) {
            PXBackupFailureCleanupSetError(
                &setupError,
                PXBackupFailureCleanupErrorFactoryCleanupFailed,
                PXBackupFailureCleanupWorkspaceField,
                @"The failed cleanup factory could not remove its empty workspace safely");
        }
    }
    if (workspaceDescriptor >= 0) close(workspaceDescriptor);
    if (parentDescriptor >= 0) close(parentDescriptor);
    free(parentPathBytes);
    free(workspaceNameBytes);
    if (!cleanup && error) *error = setupError ?: [NSError
        errorWithDomain:PXBackupFailureCleanupErrorDomain
                   code:PXBackupFailureCleanupErrorWorkspaceInspectionFailed
               userInfo:@{
                   NSLocalizedDescriptionKey: @"The backup cleanup authority could not be created",
                   PXBackupFailureCleanupErrorFieldPathKey: PXBackupFailureCleanupField,
               }];
    return cleanup;
}

- (instancetype)initWithWorkspace:(PXBackupPublicationWorkspace *)workspace
                       bundleLock:(PXBackupBundleLock *)bundleLock
                       parentPath:(NSString *)parentPath
                    workspacePath:(NSString *)workspacePath
                    workspaceName:(NSString *)workspaceName
                 parentDescriptor:(int)parentDescriptor
              workspaceDescriptor:(int)workspaceDescriptor
                   parentIdentity:(const struct stat *)parentIdentity
                workspaceIdentity:(const struct stat *)workspaceIdentity {
    self = [super init];
    if (self) {
        _workspace = workspace;
        _bundleLock = bundleLock;
        _parentPath = [parentPath copy];
        _workspacePath = [workspacePath copy];
        _workspaceName = [workspaceName copy];
        _parentDescriptor = parentDescriptor;
        _workspaceDescriptor = workspaceDescriptor;
        if (parentIdentity) _parentIdentity = *parentIdentity;
        if (workspaceIdentity) _workspaceIdentity = *workspaceIdentity;
    }
    return self;
}

- (NSString *)workspacePath { return _workspacePath; }
- (NSString *)workspaceName { return _workspaceName; }
- (BOOL)cleanupAttempted { return _cleanupAttempted; }
- (BOOL)cleaned { return _cleaned; }
- (BOOL)disarmed { return _disarmed; }
- (NSUInteger)removedEntryCount { return _removedEntryCount; }

- (BOOL)validateActiveIdentityAllowAttempted:(BOOL)allowAttempted
                                       error:(NSError **)error {
    if (error) *error = nil;
    if (_cleaned || _disarmed || (!allowAttempted && _cleanupAttempted) ||
        _parentDescriptor < 0 || _workspaceDescriptor < 0) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorAlreadyFinished,
            PXBackupFailureCleanupField,
            @"The backup cleanup operation is already finished");
        return NO;
    }
    NSError *lockError = nil;
    if (![_bundleLock validateOwnershipWithError:&lockError]) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorLockValidationFailed,
            PXBackupFailureCleanupLockField,
            @"The retained backup lock is invalid");
        return NO;
    }
    if (!PXBackupFailureCleanupPathMatchesDescriptor(_parentPath,
                                                     _parentDescriptor,
                                                     &_parentIdentity,
                                                     NO,
                                                     NULL)) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorWorkspaceChanged,
            PXBackupFailureCleanupParentField,
            @"The retained cleanup parent identity changed");
        return NO;
    }
    NSData *workspaceNameData = nil;
    if (!PXBackupFailureCleanupValidateComponentString(_workspaceName,
                                                       &workspaceNameData)) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorWorkspaceChanged,
            PXBackupFailureCleanupWorkspaceField,
            @"The retained cleanup workspace name is invalid");
        return NO;
    }
    char *workspaceNameBytes = PXBackupFailureCleanupCopyCString(workspaceNameData);
    if (!workspaceNameBytes) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorLimitExceeded,
            PXBackupFailureCleanupWorkspaceField,
            @"The retained cleanup workspace name exceeds limits");
        return NO;
    }
    struct stat namespaceStat;
    if (fstatat(_parentDescriptor,
                workspaceNameBytes,
                &namespaceStat,
                AT_SYMLINK_NOFOLLOW) != 0) {
        int failureErrno = errno;
        free(workspaceNameBytes);
        PXBackupFailureCleanupSetError(
            error,
            failureErrno == ENOENT
                ? PXBackupFailureCleanupErrorPublishedStateDetected
                : PXBackupFailureCleanupErrorWorkspaceChanged,
            PXBackupFailureCleanupPublicationField,
            failureErrno == ENOENT
                ? @"The original partial workspace is no longer present"
                : @"The original partial workspace could not be inspected");
        return NO;
    }
    BOOL bindingValid =
        PXBackupFailureCleanupDirectoryBindingValid(_parentDescriptor,
                                                     workspaceNameBytes,
                                                     _workspaceDescriptor,
                                                     &_workspaceIdentity,
                                                     _parentIdentity.st_dev,
                                                     YES,
                                                     NULL) &&
        PXBackupFailureCleanupPathMatchesDescriptor(_workspacePath,
                                                    _workspaceDescriptor,
                                                    &_workspaceIdentity,
                                                    YES,
                                                    NULL);
    free(workspaceNameBytes);
    NSError *workspaceError = nil;
    if (!bindingValid ||
        ![_workspace validateIdentityWithError:&workspaceError]) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorWorkspaceChanged,
            PXBackupFailureCleanupWorkspaceField,
            @"The retained cleanup workspace identity changed");
        return NO;
    }
    return YES;
}

- (BOOL)validateIdentityWithError:(NSError **)error {
    return [self validateActiveIdentityAllowAttempted:NO error:error];
}

- (BOOL)cleanupWithError:(NSError **)error {
    if (error) *error = nil;
    if (_cleanupAttempted || _cleaned || _disarmed) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorAlreadyFinished,
            PXBackupFailureCleanupField,
            @"The backup cleanup operation is already finished");
        return NO;
    }
    _cleanupAttempted = YES;
    NSError *identityError = nil;
    if (![self validateActiveIdentityAllowAttempted:YES
                                             error:&identityError]) {
        if (error) *error = identityError;
        return NO;
    }
    PXBackupFailureCleanupTraversalState state;
    memset(&state, 0, sizeof(state));
    state.workspaceDevice = _workspaceIdentity.st_dev;
    NSError *traversalError = nil;
    BOOL traversalSucceeded =
        PXBackupFailureCleanupRemoveDirectoryContents(_workspaceDescriptor,
                                                       &_workspaceIdentity,
                                                       0U,
                                                       &state,
                                                       &traversalError);
    _removedEntryCount = state.removedEntries;
    if (!traversalSucceeded) {
        if (_removedEntryCount > 0) {
            PXBackupFailureCleanupSetError(
                error,
                PXBackupFailureCleanupErrorCleanupIncomplete,
                PXBackupFailureCleanupEntryField,
                @"The backup cleanup stopped after removing verified entries");
        } else if (error) {
            *error = traversalError ?: [NSError
                errorWithDomain:PXBackupFailureCleanupErrorDomain
                           code:PXBackupFailureCleanupErrorTraversalFailed
                       userInfo:@{
                           NSLocalizedDescriptionKey: @"The backup cleanup traversal failed",
                           PXBackupFailureCleanupErrorFieldPathKey: PXBackupFailureCleanupEntryField,
                       }];
        }
        return NO;
    }
    BOOL empty = NO;
    NSError *emptyError = nil;
    if (!PXBackupFailureCleanupDirectoryIsEmpty(_workspaceDescriptor,
                                                &empty,
                                                &emptyError) ||
        !empty) {
        if (_removedEntryCount > 0) {
            PXBackupFailureCleanupSetError(
                error,
                PXBackupFailureCleanupErrorCleanupIncomplete,
                PXBackupFailureCleanupEntryField,
                @"The backup cleanup workspace was repopulated during cleanup");
        } else if (error) {
            *error = emptyError ?: [NSError
                errorWithDomain:PXBackupFailureCleanupErrorDomain
                           code:PXBackupFailureCleanupErrorEntryChanged
                       userInfo:@{
                           NSLocalizedDescriptionKey: @"The backup cleanup workspace is not empty",
                           PXBackupFailureCleanupErrorFieldPathKey: PXBackupFailureCleanupEntryField,
                       }];
        }
        return NO;
    }
    if (!PXBackupFailureCleanupStrictSync(_workspaceDescriptor)) {
        PXBackupFailureCleanupSetError(
            error,
            _removedEntryCount > 0
                ? PXBackupFailureCleanupErrorCleanupIncomplete
                : PXBackupFailureCleanupErrorDurabilityFailed,
            PXBackupFailureCleanupDurabilityField,
            @"The backup cleanup workspace could not be synchronized");
        return NO;
    }
    NSError *rootLockError = nil;
    if (![_bundleLock validateOwnershipWithError:&rootLockError] ||
        !PXBackupFailureCleanupPathMatchesDescriptor(_parentPath,
                                                     _parentDescriptor,
                                                     &_parentIdentity,
                                                     NO,
                                                     NULL)) {
        PXBackupFailureCleanupSetError(
            error,
            _removedEntryCount > 0 || state.destructiveMutationOccurred
                ? PXBackupFailureCleanupErrorCleanupIncomplete
                : PXBackupFailureCleanupErrorLockValidationFailed,
            PXBackupFailureCleanupLockField,
            @"The cleanup authority changed before root capture");
        return NO;
    }
    NSData *workspaceNameData = nil;
    char *workspaceNameBytes = NULL;
    if (!PXBackupFailureCleanupValidateComponentString(_workspaceName,
                                                       &workspaceNameData) ||
        !(workspaceNameBytes =
              PXBackupFailureCleanupCopyCString(workspaceNameData)) ||
        !PXBackupFailureCleanupDirectoryBindingValid(_parentDescriptor,
                                                     workspaceNameBytes,
                                                     _workspaceDescriptor,
                                                     &_workspaceIdentity,
                                                     _parentIdentity.st_dev,
                                                     YES,
                                                     NULL)) {
        free(workspaceNameBytes);
        PXBackupFailureCleanupSetError(
            error,
            _removedEntryCount > 0 || state.destructiveMutationOccurred
                ? PXBackupFailureCleanupErrorCleanupIncomplete
                : PXBackupFailureCleanupErrorWorkspaceChanged,
            PXBackupFailureCleanupWorkspaceField,
            @"The backup cleanup workspace changed before root capture");
        return NO;
    }
    if (_removedEntryCount == NSUIntegerMax) {
        free(workspaceNameBytes);
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorCleanupIncomplete,
            PXBackupFailureCleanupEntryField,
            @"The cleanup removal count overflowed");
        return NO;
    }
    char *quarantineName = NULL;
    NSError *captureError = nil;
    if (!PXBackupFailureCleanupCaptureEntry(
            _parentDescriptor,
            workspaceNameBytes,
            _workspaceDescriptor,
            &_workspaceIdentity,
            PXBackupFailureCleanupCaptureTypeDirectory,
            _parentIdentity.st_dev,
            YES,
            _removedEntryCount > 0 || state.destructiveMutationOccurred,
            &quarantineName,
            &captureError)) {
        free(workspaceNameBytes);
        if (error) *error = captureError;
        return NO;
    }
    BOOL capturedEmpty = NO;
    NSError *capturedEmptyError = nil;
    BOOL capturedValid =
        PXBackupFailureCleanupCapturedBindingValid(
            _parentDescriptor,
            quarantineName,
            _workspaceDescriptor,
            &_workspaceIdentity,
            PXBackupFailureCleanupCaptureTypeDirectory,
            _parentIdentity.st_dev,
            YES,
            NULL) &&
        PXBackupFailureCleanupDirectoryIsEmpty(_workspaceDescriptor,
                                               &capturedEmpty,
                                               &capturedEmptyError) &&
        capturedEmpty;
    if (!capturedValid) {
        free(quarantineName);
        free(workspaceNameBytes);
        if (error) {
            *error = capturedEmptyError;
            if (!*error) {
                PXBackupFailureCleanupSetError(
                    error,
                    PXBackupFailureCleanupErrorCleanupIncomplete,
                    PXBackupFailureCleanupWorkspaceField,
                    @"The quarantined backup workspace changed before removal");
            }
        }
        return NO;
    }
    if (unlinkat(_parentDescriptor, quarantineName, AT_REMOVEDIR) != 0) {
        free(quarantineName);
        free(workspaceNameBytes);
        PXBackupFailureCleanupSetError(
            error,
            _removedEntryCount > 0 || state.destructiveMutationOccurred
                ? PXBackupFailureCleanupErrorCleanupIncomplete
                : PXBackupFailureCleanupErrorRemovalFailed,
            PXBackupFailureCleanupWorkspaceField,
            @"The quarantined backup workspace could not be removed");
        return NO;
    }
    BOOL rootMutationOccurred = YES;
    BOOL removed =
        PXBackupFailureCleanupEntryIsAbsent(_parentDescriptor, quarantineName) &&
        PXBackupFailureCleanupEntryIsAbsent(_parentDescriptor,
                                            workspaceNameBytes);
    free(quarantineName);
    free(workspaceNameBytes);
    if (!removed || !PXBackupFailureCleanupStrictSync(_parentDescriptor)) {
        PXBackupFailureCleanupSetError(
            error,
            rootMutationOccurred
                ? PXBackupFailureCleanupErrorCleanupIncomplete
                : PXBackupFailureCleanupErrorRemovalFailed,
            PXBackupFailureCleanupDurabilityField,
            @"The backup workspace removal could not be proven durable");
        return NO;
    }
    _removedEntryCount += 1U;
    _cleaned = YES;
    close(_workspaceDescriptor);
    _workspaceDescriptor = -1;
    close(_parentDescriptor);
    _parentDescriptor = -1;
    return YES;
}

- (BOOL)disarmAfterPublishedDirectory:(PXBackupDirectoryPublisher *)publisher
                                error:(NSError **)error {
    if (error) *error = nil;
    if (_cleanupAttempted || _cleaned || _disarmed ||
        _parentDescriptor < 0 || _workspaceDescriptor < 0) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorAlreadyFinished,
            PXBackupFailureCleanupField,
            @"The backup cleanup operation is already finished");
        return NO;
    }
    if (![publisher isMemberOfClass:[PXBackupDirectoryPublisher class]] ||
        !publisher.isPublished ||
        ![publisher.workspacePath isEqualToString:_workspacePath] ||
        publisher.publishedDirectoryPath.length == 0 ||
        [publisher.publishedDirectoryPath isEqualToString:_workspacePath] ||
        publisher.publishedManifestPath.length == 0 ||
        ![[publisher.publishedManifestPath stringByDeletingLastPathComponent]
            isEqualToString:publisher.publishedDirectoryPath]) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorDisarmValidationFailed,
            PXBackupFailureCleanupPublicationField,
            @"The published backup cannot disarm the cleanup authority");
        return NO;
    }
    NSError *publisherError = nil;
    if (![publisher validateIdentityWithError:&publisherError]) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorDisarmValidationFailed,
            PXBackupFailureCleanupPublicationField,
            @"The published backup failed cleanup disarm validation");
        return NO;
    }
    NSError *lockError = nil;
    if (![_bundleLock validateOwnershipWithError:&lockError]) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorLockValidationFailed,
            PXBackupFailureCleanupLockField,
            @"The backup lock failed cleanup disarm validation");
        return NO;
    }
    if (!PXBackupFailureCleanupPathMatchesDescriptor(_parentPath,
                                                     _parentDescriptor,
                                                     &_parentIdentity,
                                                     NO,
                                                     NULL)) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorDisarmValidationFailed,
            PXBackupFailureCleanupParentField,
            @"The cleanup parent changed before disarm");
        return NO;
    }
    NSData *workspaceNameData = nil;
    char *workspaceNameBytes = NULL;
    BOOL originalPartialAbsent =
        PXBackupFailureCleanupValidateComponentString(_workspaceName,
                                                      &workspaceNameData) &&
        (workspaceNameBytes =
             PXBackupFailureCleanupCopyCString(workspaceNameData)) &&
        PXBackupFailureCleanupEntryIsAbsent(_parentDescriptor,
                                            workspaceNameBytes);
    free(workspaceNameBytes);
    if (!originalPartialAbsent) {
        PXBackupFailureCleanupSetError(
            error,
            PXBackupFailureCleanupErrorDisarmValidationFailed,
            PXBackupFailureCleanupPublicationField,
            @"The original partial workspace is still present during disarm");
        return NO;
    }
    _disarmed = YES;
    close(_workspaceDescriptor);
    _workspaceDescriptor = -1;
    close(_parentDescriptor);
    _parentDescriptor = -1;
    return YES;
}

- (void)dealloc {
    if (_workspaceDescriptor >= 0) close(_workspaceDescriptor);
    if (_parentDescriptor >= 0) close(_parentDescriptor);
}

@end
