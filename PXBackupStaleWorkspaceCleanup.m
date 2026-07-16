#import "PXBackupStaleWorkspaceCleanup.h"
#import "PXBackupBundleLock.h"

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

NSErrorDomain const PXBackupStaleWorkspaceCleanupErrorDomain =
    @"com.hydra.projectx.backup-stale-workspace-cleanup";
NSString * const PXBackupStaleWorkspaceCleanupErrorFieldPathKey = @"fieldPath";

static NSString * const PXBackupStaleWorkspaceCleanupField = @"$.staleCleanup";
static NSString * const PXBackupStaleWorkspaceCleanupLockField = @"$.staleCleanup.lock";
static NSString * const PXBackupStaleWorkspaceCleanupParentField = @"$.staleCleanup.parent";
static NSString * const PXBackupStaleWorkspaceCleanupWorkspaceField = @"$.staleCleanup.workspace";
static NSString * const PXBackupStaleWorkspaceCleanupEntryField = @"$.staleCleanup.entry";
static NSString * const PXBackupStaleWorkspaceCleanupDurabilityField = @"$.staleCleanup.durability";
static NSString * const PXBackupStaleWorkspaceCleanupPublicationField = @"$.staleCleanup.publication";

static const NSUInteger PXBackupStaleWorkspaceCleanupMaximumDepth = 64U;
static const NSUInteger PXBackupStaleWorkspaceCleanupMaximumVisitedEntries = 16384U;
static const NSUInteger PXBackupStaleWorkspaceCleanupMaximumComponentBytes = 255U;
static const NSUInteger PXBackupStaleWorkspaceCleanupMaximumWorkspacePathBytes = 4096U;
static const unsigned long long PXBackupStaleWorkspaceCleanupMaximumAccumulatedNameBytes =
    8ULL * 1024ULL * 1024ULL;
static const char PXBackupStaleWorkspaceCleanupQuarantinePrefix[] =
    ".weaponx-cleanup-quarantine-";
static const NSUInteger PXBackupStaleWorkspaceCleanupQuarantineRandomByteCount = 16U;
static const NSUInteger PXBackupStaleWorkspaceCleanupQuarantineAttemptLimit = 16U;
static const NSUInteger PXBackupStaleWorkspaceCleanupMaximumTopLevelCandidates = 256U;
static const char PXBackupStaleWorkspaceCleanupPartialPrefix[] =
    ".weaponx-backup-partial-";

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
} PXBackupStaleWorkspaceCleanupTraversalState;

typedef enum {
    PXBackupStaleWorkspaceCleanupDirectoryReadModeStrictRecursiveNames = 1,
    PXBackupStaleWorkspaceCleanupDirectoryReadModeRawTopLevelReservedClassification = 2,
} PXBackupStaleWorkspaceCleanupDirectoryReadMode;

typedef enum {
    PXBackupStaleWorkspaceCleanupRawTopLevelNameNonreserved = 0,
    PXBackupStaleWorkspaceCleanupRawTopLevelNameExactReserved = 1,
    PXBackupStaleWorkspaceCleanupRawTopLevelNameMalformedReserved = 2,
} PXBackupStaleWorkspaceCleanupRawTopLevelNameClassification;

static void PXBackupStaleWorkspaceCleanupSetError(
    NSError **error,
    PXBackupStaleWorkspaceCleanupErrorCode code,
    NSString *field,
    NSString *description) {
    if (!error) return;
    *error = [NSError errorWithDomain:PXBackupStaleWorkspaceCleanupErrorDomain
                                 code:code
                             userInfo:@{
                                 NSLocalizedDescriptionKey: description,
                                 PXBackupStaleWorkspaceCleanupErrorFieldPathKey: field,
                             }];
}

static BOOL PXBackupStaleWorkspaceCleanupStatIdentityMatches(const struct stat *left,
                                                       const struct stat *right) {
    return left && right && left->st_dev == right->st_dev &&
           left->st_ino == right->st_ino &&
           (left->st_mode & S_IFMT) == (right->st_mode & S_IFMT);
}

static BOOL PXBackupStaleWorkspaceCleanupStableFileMatches(const struct stat *left,
                                                     const struct stat *right) {
    return PXBackupStaleWorkspaceCleanupStatIdentityMatches(left, right) &&
           left->st_mode == right->st_mode && left->st_nlink == right->st_nlink &&
           left->st_size == right->st_size &&
           PX_BACKUP_CLEANUP_MTIME_SEC(*left) == PX_BACKUP_CLEANUP_MTIME_SEC(*right) &&
           PX_BACKUP_CLEANUP_MTIME_NSEC(*left) == PX_BACKUP_CLEANUP_MTIME_NSEC(*right) &&
           PX_BACKUP_CLEANUP_CTIME_SEC(*left) == PX_BACKUP_CLEANUP_CTIME_SEC(*right) &&
           PX_BACKUP_CLEANUP_CTIME_NSEC(*left) == PX_BACKUP_CLEANUP_CTIME_NSEC(*right);
}

static BOOL PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(int descriptor) {
    if (descriptor < 0) return NO;
    int flags = -1;
    do {
        flags = fcntl(descriptor, F_GETFD);
    } while (flags < 0 && errno == EINTR);
    return flags >= 0 && (flags & FD_CLOEXEC) != 0;
}

static int PXBackupStaleWorkspaceCleanupDuplicateDescriptor(int descriptor) {
    if (descriptor < 0) return -1;
    int duplicate = -1;
    do {
        duplicate = fcntl(descriptor, F_DUPFD_CLOEXEC, 0);
    } while (duplicate < 0 && errno == EINTR);
    if (duplicate < 0 ||
        !PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(duplicate)) {
        if (duplicate >= 0) close(duplicate);
        return -1;
    }
    return duplicate;
}

static BOOL PXBackupStaleWorkspaceCleanupStrictSync(int descriptor) {
    if (descriptor < 0) return NO;
    int result = -1;
    do {
        result = fsync(descriptor);
    } while (result < 0 && errno == EINTR);
    return result == 0;
}


typedef enum {
    PXBackupStaleWorkspaceCleanupCaptureTypeRegularFile = 1,
    PXBackupStaleWorkspaceCleanupCaptureTypeDirectory = 2,
} PXBackupStaleWorkspaceCleanupCaptureType;

static BOOL PXBackupStaleWorkspaceCleanupEntryIsAbsent(int parentDescriptor,
                                                 const char *name);

static BOOL PXBackupStaleWorkspaceCleanupMoveNoReplace(
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

static BOOL PXBackupStaleWorkspaceCleanupGenerateQuarantineName(
    char *buffer,
    size_t bufferSize) {
    static const char lowercaseHex[] = "0123456789abcdef";
    const size_t prefixLength = sizeof(PXBackupStaleWorkspaceCleanupQuarantinePrefix) - 1U;
    const size_t suffixLength = PXBackupStaleWorkspaceCleanupQuarantineRandomByteCount * 2U;
    const size_t requiredLength = prefixLength + suffixLength + 1U;
    if (!buffer || bufferSize < requiredLength ||
        requiredLength - 1U > PXBackupStaleWorkspaceCleanupMaximumComponentBytes) return NO;
    unsigned char randomBytes[PXBackupStaleWorkspaceCleanupQuarantineRandomByteCount];
    arc4random_buf(randomBytes, sizeof(randomBytes));
    memcpy(buffer, PXBackupStaleWorkspaceCleanupQuarantinePrefix, prefixLength);
    for (size_t index = 0; index < sizeof(randomBytes); index++) {
        unsigned char byte = randomBytes[index];
        buffer[prefixLength + (index * 2U)] = lowercaseHex[(byte >> 4U) & 0x0fU];
        buffer[prefixLength + (index * 2U) + 1U] = lowercaseHex[byte & 0x0fU];
    }
    buffer[requiredLength - 1U] = '\0';
    return YES;
}

static BOOL PXBackupStaleWorkspaceCleanupCapturedBindingValid(
    int parentDescriptor,
    const char *quarantineName,
    int retainedDescriptor,
    const struct stat *retainedIdentity,
    PXBackupStaleWorkspaceCleanupCaptureType captureType,
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
        !PXBackupStaleWorkspaceCleanupStatIdentityMatches(&namespaceStat,
                                                   &descriptorStat) ||
        !PXBackupStaleWorkspaceCleanupStatIdentityMatches(retainedIdentity,
                                                   &descriptorStat) ||
        !PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(retainedDescriptor)) return NO;
    if (captureType == PXBackupStaleWorkspaceCleanupCaptureTypeRegularFile) {
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
    } else if (captureType == PXBackupStaleWorkspaceCleanupCaptureTypeDirectory) {
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

static BOOL PXBackupStaleWorkspaceCleanupRollbackCapturedMismatch(
    int parentDescriptor,
    const char *quarantineName,
    const char *originalName) {
    if (!PXBackupStaleWorkspaceCleanupEntryIsAbsent(parentDescriptor, originalName)) {
        return NO;
    }
    int rollbackErrno = 0;
    if (!PXBackupStaleWorkspaceCleanupMoveNoReplace(parentDescriptor,
                                             quarantineName,
                                             parentDescriptor,
                                             originalName,
                                             &rollbackErrno) ||
        !PXBackupStaleWorkspaceCleanupStrictSync(parentDescriptor) ||
        !PXBackupStaleWorkspaceCleanupEntryIsAbsent(parentDescriptor, quarantineName)) {
        return NO;
    }
    struct stat restored;
    return fstatat(parentDescriptor,
                   originalName,
                   &restored,
                   AT_SYMLINK_NOFOLLOW) == 0;
}

static PXBackupStaleWorkspaceCleanupErrorCode
PXBackupStaleWorkspaceCleanupPostCaptureErrorCode(
    BOOL rollbackSucceeded,
    BOOL priorDestructiveMutation,
    PXBackupStaleWorkspaceCleanupErrorCode operationSpecificCode) {
    if (rollbackSucceeded) return operationSpecificCode;
    return priorDestructiveMutation
        ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
        : PXBackupStaleWorkspaceCleanupErrorRollbackFailed;
}

static BOOL PXBackupStaleWorkspaceCleanupCaptureEntry(
    int parentDescriptor,
    const char *sourceName,
    int retainedDescriptor,
    const struct stat *retainedIdentity,
    PXBackupStaleWorkspaceCleanupCaptureType captureType,
    dev_t expectedDevice,
    BOOL requireWorkspaceMode,
    BOOL priorDestructiveMutation,
    char **quarantineNameOut,
    NSError **error) {
    if (quarantineNameOut) *quarantineNameOut = NULL;
    if (parentDescriptor < 0 || retainedDescriptor < 0 ||
        !sourceName || sourceName[0] == '\0' || !retainedIdentity ||
        !quarantineNameOut) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorInvalidInput,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"The cleanup capture inputs are invalid");
        return NO;
    }
    const size_t quarantineCapacity =
        sizeof(PXBackupStaleWorkspaceCleanupQuarantinePrefix) +
        (PXBackupStaleWorkspaceCleanupQuarantineRandomByteCount * 2U);
    char quarantineName[sizeof(PXBackupStaleWorkspaceCleanupQuarantinePrefix) +
                        (PXBackupStaleWorkspaceCleanupQuarantineRandomByteCount * 2U)];
    BOOL moved = NO;
    int moveErrno = 0;
    for (NSUInteger attempt = 0;
         attempt < PXBackupStaleWorkspaceCleanupQuarantineAttemptLimit;
         attempt++) {
        if (!PXBackupStaleWorkspaceCleanupGenerateQuarantineName(quarantineName,
                                                          quarantineCapacity)) {
            PXBackupStaleWorkspaceCleanupSetError(
                error,
                priorDestructiveMutation
                    ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
                    : PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
                PXBackupStaleWorkspaceCleanupEntryField,
                @"A private cleanup quarantine name could not be generated");
            return NO;
        }
        moveErrno = 0;
        if (PXBackupStaleWorkspaceCleanupMoveNoReplace(parentDescriptor,
                                                sourceName,
                                                parentDescriptor,
                                                quarantineName,
                                                &moveErrno)) {
            moved = YES;
            break;
        }
        if (moveErrno == EEXIST || moveErrno == ENOTEMPTY) continue;
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            priorDestructiveMutation
                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
                : PXBackupStaleWorkspaceCleanupErrorEntryChanged,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"A cleanup entry changed before atomic capture");
        return NO;
    }
    if (!moved) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            priorDestructiveMutation
                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
                : PXBackupStaleWorkspaceCleanupErrorRemovalFailed,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"A private cleanup quarantine name could not be reserved");
        return NO;
    }
    BOOL originalAbsent =
        PXBackupStaleWorkspaceCleanupEntryIsAbsent(parentDescriptor, sourceName);
    BOOL exactCapture = originalAbsent &&
        PXBackupStaleWorkspaceCleanupCapturedBindingValid(parentDescriptor,
                                                   quarantineName,
                                                   retainedDescriptor,
                                                   retainedIdentity,
                                                   captureType,
                                                   expectedDevice,
                                                   requireWorkspaceMode,
                                                   NULL);
    if (!exactCapture) {
        BOOL rollbackSucceeded = originalAbsent &&
            PXBackupStaleWorkspaceCleanupRollbackCapturedMismatch(parentDescriptor,
                                                           quarantineName,
                                                           sourceName);
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupPostCaptureErrorCode(
                rollbackSucceeded,
                priorDestructiveMutation,
                PXBackupStaleWorkspaceCleanupErrorEntryChanged),
            PXBackupStaleWorkspaceCleanupEntryField,
            rollbackSucceeded
                ? @"A changed cleanup entry was restored without deletion"
                : @"A changed cleanup entry could not be restored safely");
        return NO;
    }
    size_t quarantineLength = strlen(quarantineName);
    if (quarantineLength == 0 || quarantineLength > SIZE_MAX - 1U) {
        BOOL rollbackSucceeded =
            PXBackupStaleWorkspaceCleanupRollbackCapturedMismatch(parentDescriptor,
                                                           quarantineName,
                                                           sourceName);
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupPostCaptureErrorCode(
                rollbackSucceeded,
                priorDestructiveMutation,
                PXBackupStaleWorkspaceCleanupErrorLimitExceeded),
            PXBackupStaleWorkspaceCleanupEntryField,
            @"The private cleanup quarantine name exceeded fixed limits");
        return NO;
    }
    char *retainedName = malloc(quarantineLength + 1U);
    if (!retainedName) {
        BOOL rollbackSucceeded =
            PXBackupStaleWorkspaceCleanupRollbackCapturedMismatch(parentDescriptor,
                                                           quarantineName,
                                                           sourceName);
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupPostCaptureErrorCode(
                rollbackSucceeded,
                priorDestructiveMutation,
                PXBackupStaleWorkspaceCleanupErrorLimitExceeded),
            PXBackupStaleWorkspaceCleanupEntryField,
            @"The private cleanup quarantine name could not be retained");
        return NO;
    }
    memcpy(retainedName, quarantineName, quarantineLength + 1U);
    *quarantineNameOut = retainedName;
    return YES;
}

static BOOL PXBackupStaleWorkspaceCleanupStringContainsNUL(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return YES;
    for (NSUInteger index = 0; index < value.length; index++) {
        if ([value characterAtIndex:index] == 0) return YES;
    }
    return NO;
}

static BOOL PXBackupStaleWorkspaceCleanupStringContainsControl(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return YES;
    for (NSUInteger index = 0; index < value.length; index++) {
        unichar character = [value characterAtIndex:index];
        if (character < 0x20 || character == 0x7f) return YES;
    }
    return NO;
}

static NSData *PXBackupStaleWorkspaceCleanupLosslessUTF8Data(NSString *value,
                                                       NSUInteger maximumBytes,
                                                       BOOL requireAbsolute) {
    if (![value isKindOfClass:[NSString class]] || value.length == 0 ||
        PXBackupStaleWorkspaceCleanupStringContainsNUL(value) ||
        (requireAbsolute && ![value hasPrefix:@"/"])) return nil;
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding
                        allowLossyConversion:NO];
    if (!data || data.length == 0 || data.length > maximumBytes) return nil;
    NSString *roundTrip = [[NSString alloc] initWithData:data
                                                encoding:NSUTF8StringEncoding];
    return roundTrip && [roundTrip isEqualToString:value] ? data : nil;
}

static BOOL PXBackupStaleWorkspaceCleanupValidateComponentString(NSString *component,
                                                           NSData **dataOut) {
    if (dataOut) *dataOut = nil;
    NSData *data = PXBackupStaleWorkspaceCleanupLosslessUTF8Data(
        component,
        PXBackupStaleWorkspaceCleanupMaximumComponentBytes,
        NO);
    if (!data || PXBackupStaleWorkspaceCleanupStringContainsControl(component) ||
        [component isEqualToString:@"."] ||
        [component isEqualToString:@".."] ||
        [component containsString:@"/"] ||
        [component containsString:@"\\"]) return NO;
    if (dataOut) *dataOut = data;
    return YES;
}

static BOOL PXBackupStaleWorkspaceCleanupReadBoundedRawNameLength(
    const char *name,
    NSUInteger *lengthOut,
    BOOL *exceedsComponentLimitOut) {
    if (lengthOut) *lengthOut = 0U;
    if (exceedsComponentLimitOut) *exceedsComponentLimitOut = NO;
    if (!name) return NO;
    size_t length = 0U;
    while (length <= PXBackupStaleWorkspaceCleanupMaximumComponentBytes &&
           name[length] != '\0') {
        length += 1U;
    }
    if (length == 0U) return NO;
    if (length > PXBackupStaleWorkspaceCleanupMaximumComponentBytes) {
        if (lengthOut) {
            *lengthOut = PXBackupStaleWorkspaceCleanupMaximumComponentBytes + 1U;
        }
        if (exceedsComponentLimitOut) *exceedsComponentLimitOut = YES;
        return YES;
    }
    if (lengthOut) *lengthOut = (NSUInteger)length;
    return YES;
}

static BOOL PXBackupStaleWorkspaceCleanupValidateStrictRecursiveEntryName(
    const char *name,
    NSUInteger length,
    NSData **dataOut) {
    if (dataOut) *dataOut = nil;
    if (!name || length == 0U ||
        length > PXBackupStaleWorkspaceCleanupMaximumComponentBytes ||
        (length == 1U && name[0] == '.') ||
        (length == 2U && name[0] == '.' && name[1] == '.')) return NO;
    for (NSUInteger index = 0U; index < length; index++) {
        unsigned char byte = (unsigned char)name[index];
        if (byte == '/' || byte == '\\' || byte < 0x20 || byte == 0x7f) return NO;
    }
    NSData *data = [NSData dataWithBytes:name length:length];
    NSString *string = [[NSString alloc] initWithData:data
                                              encoding:NSUTF8StringEncoding];
    NSData *roundTrip = [string dataUsingEncoding:NSUTF8StringEncoding
                              allowLossyConversion:NO];
    if (!string || !roundTrip || ![roundTrip isEqualToData:data] ||
        PXBackupStaleWorkspaceCleanupStringContainsControl(string)) return NO;
    if (dataOut) *dataOut = data;
    return YES;
}

static BOOL PXBackupStaleWorkspaceCleanupRawNameHasPrefix(
    const char *name,
    NSUInteger length,
    const char *prefix,
    size_t prefixLength) {
    return name && prefix && length >= prefixLength &&
        memcmp(name, prefix, prefixLength) == 0;
}

static PXBackupStaleWorkspaceCleanupRawTopLevelNameClassification
PXBackupStaleWorkspaceCleanupClassifyRawTopLevelName(
    const char *name,
    NSUInteger length) {
    const size_t partialPrefixLength =
        sizeof(PXBackupStaleWorkspaceCleanupPartialPrefix) - 1U;
    const size_t quarantinePrefixLength =
        sizeof(PXBackupStaleWorkspaceCleanupQuarantinePrefix) - 1U;
    BOOL partialPrefix = PXBackupStaleWorkspaceCleanupRawNameHasPrefix(
        name,
        length,
        PXBackupStaleWorkspaceCleanupPartialPrefix,
        partialPrefixLength);
    BOOL quarantinePrefix = PXBackupStaleWorkspaceCleanupRawNameHasPrefix(
        name,
        length,
        PXBackupStaleWorkspaceCleanupQuarantinePrefix,
        quarantinePrefixLength);
    if (!partialPrefix && !quarantinePrefix) {
        return PXBackupStaleWorkspaceCleanupRawTopLevelNameNonreserved;
    }
    if (partialPrefix) {
        if (length != partialPrefixLength + 6U) {
            return PXBackupStaleWorkspaceCleanupRawTopLevelNameMalformedReserved;
        }
        for (NSUInteger index = (NSUInteger)partialPrefixLength;
             index < length;
             index++) {
            unsigned char byte = (unsigned char)name[index];
            BOOL alphanumeric = (byte >= '0' && byte <= '9') ||
                (byte >= 'A' && byte <= 'Z') ||
                (byte >= 'a' && byte <= 'z');
            if (!alphanumeric) {
                return PXBackupStaleWorkspaceCleanupRawTopLevelNameMalformedReserved;
            }
        }
        return PXBackupStaleWorkspaceCleanupRawTopLevelNameExactReserved;
    }
    if (length != quarantinePrefixLength + 32U) {
        return PXBackupStaleWorkspaceCleanupRawTopLevelNameMalformedReserved;
    }
    for (NSUInteger index = (NSUInteger)quarantinePrefixLength;
         index < length;
         index++) {
        unsigned char byte = (unsigned char)name[index];
        if (!((byte >= '0' && byte <= '9') ||
              (byte >= 'a' && byte <= 'f'))) {
            return PXBackupStaleWorkspaceCleanupRawTopLevelNameMalformedReserved;
        }
    }
    return PXBackupStaleWorkspaceCleanupRawTopLevelNameExactReserved;
}

static char *PXBackupStaleWorkspaceCleanupCopyCString(NSData *data) {
    if (![data isKindOfClass:[NSData class]] || data.length == 0 ||
        data.length > SIZE_MAX - 1U) return NULL;
    char *bytes = malloc(data.length + 1U);
    if (!bytes) return NULL;
    memcpy(bytes, data.bytes, data.length);
    bytes[data.length] = '\0';
    return bytes;
}

static BOOL PXBackupStaleWorkspaceCleanupEntryIsAbsent(int parentDescriptor,
                                                 const char *name) {
    if (parentDescriptor < 0 || !name || name[0] == '\0') return NO;
    struct stat current;
    if (fstatat(parentDescriptor, name, &current, AT_SYMLINK_NOFOLLOW) == 0) {
        return NO;
    }
    return errno == ENOENT;
}

static BOOL PXBackupStaleWorkspaceCleanupPathMatchesDescriptor(
    NSString *path,
    int descriptor,
    const struct stat *expected,
    BOOL requireWorkspaceMode,
    struct stat *currentOut) {
    NSData *pathData = PXBackupStaleWorkspaceCleanupLosslessUTF8Data(
        path,
        PXBackupStaleWorkspaceCleanupMaximumWorkspacePathBytes,
        YES);
    char *pathBytes = PXBackupStaleWorkspaceCleanupCopyCString(pathData);
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
                 PXBackupStaleWorkspaceCleanupStatIdentityMatches(&pathStat,
                                                           &descriptorStat) &&
                 PXBackupStaleWorkspaceCleanupStatIdentityMatches(expected,
                                                           &descriptorStat) &&
                 PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(descriptor);
    if (valid && currentOut) *currentOut = descriptorStat;
    free(pathBytes);
    return valid;
}

static BOOL PXBackupStaleWorkspaceCleanupDirectoryBindingValid(
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
        !PXBackupStaleWorkspaceCleanupStatIdentityMatches(&namespaceStat,
                                                   &descriptorStat) ||
        !PXBackupStaleWorkspaceCleanupStatIdentityMatches(expected,
                                                   &descriptorStat) ||
        !PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(descriptor)) return NO;
    if (currentOut) *currentOut = descriptorStat;
    return YES;
}

static BOOL PXBackupStaleWorkspaceCleanupReadDirectory(
    int descriptor,
    PXBackupStaleWorkspaceCleanupTraversalState *state,
    BOOL collectNames,
    PXBackupStaleWorkspaceCleanupDirectoryReadMode readMode,
    NSArray<NSData *> **namesOut,
    BOOL *emptyOut,
    NSError **error) {
    if (namesOut) *namesOut = nil;
    if (emptyOut) *emptyOut = NO;
    BOOL supportedMode =
        readMode == PXBackupStaleWorkspaceCleanupDirectoryReadModeStrictRecursiveNames ||
        readMode == PXBackupStaleWorkspaceCleanupDirectoryReadModeRawTopLevelReservedClassification;
    if (descriptor < 0 || (collectNames && (!state || !supportedMode))) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorTraversalFailed,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"The cleanup directory could not be traversed");
        return NO;
    }
    int duplicate = PXBackupStaleWorkspaceCleanupDuplicateDescriptor(descriptor);
    if (duplicate < 0) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorTraversalFailed,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"The cleanup directory could not be traversed");
        return NO;
    }
    DIR *directory = fdopendir(duplicate);
    if (!directory) {
        close(duplicate);
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorTraversalFailed,
            PXBackupStaleWorkspaceCleanupEntryField,
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
        NSUInteger nameLength = 0U;
        BOOL exceedsComponentLimit = NO;
        if (!PXBackupStaleWorkspaceCleanupReadBoundedRawNameLength(
                entry->d_name,
                &nameLength,
                &exceedsComponentLimit)) {
            PXBackupStaleWorkspaceCleanupSetError(
                error,
                PXBackupStaleWorkspaceCleanupErrorTraversalFailed,
                PXBackupStaleWorkspaceCleanupEntryField,
                @"The cleanup directory contains an unreadable entry name");
            valid = NO;
            break;
        }
        if (!exceedsComponentLimit &&
            ((nameLength == 1U && entry->d_name[0] == '.') ||
             (nameLength == 2U && entry->d_name[0] == '.' &&
              entry->d_name[1] == '.'))) {
            continue;
        }
        empty = NO;
        if (!collectNames) continue;
        if (state->visitedEntries >=
                PXBackupStaleWorkspaceCleanupMaximumVisitedEntries ||
            (unsigned long long)nameLength >
                ULLONG_MAX - state->accumulatedNameBytes ||
            state->accumulatedNameBytes + (unsigned long long)nameLength >
                PXBackupStaleWorkspaceCleanupMaximumAccumulatedNameBytes) {
            PXBackupStaleWorkspaceCleanupSetError(
                error,
                PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
                PXBackupStaleWorkspaceCleanupEntryField,
                @"The cleanup tree exceeds fixed traversal limits");
            valid = NO;
            break;
        }
        state->visitedEntries += 1U;
        state->accumulatedNameBytes += (unsigned long long)nameLength;

        if (readMode ==
                PXBackupStaleWorkspaceCleanupDirectoryReadModeStrictRecursiveNames) {
            NSData *nameData = nil;
            if (exceedsComponentLimit ||
                !PXBackupStaleWorkspaceCleanupValidateStrictRecursiveEntryName(
                    entry->d_name,
                    nameLength,
                    &nameData)) {
                PXBackupStaleWorkspaceCleanupSetError(
                    error,
                    PXBackupStaleWorkspaceCleanupErrorUnsafeReservedEntry,
                    PXBackupStaleWorkspaceCleanupEntryField,
                    @"The cleanup tree contains an unsafe entry name");
                valid = NO;
                break;
            }
            [names addObject:nameData];
            continue;
        }

        PXBackupStaleWorkspaceCleanupRawTopLevelNameClassification classification =
            PXBackupStaleWorkspaceCleanupClassifyRawTopLevelName(
                entry->d_name,
                nameLength);
        if (classification ==
                PXBackupStaleWorkspaceCleanupRawTopLevelNameNonreserved) {
            if (exceedsComponentLimit) {
                PXBackupStaleWorkspaceCleanupSetError(
                    error,
                    PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
                    PXBackupStaleWorkspaceCleanupEntryField,
                    @"A top-level cleanup name exceeds fixed limits");
                valid = NO;
                break;
            }
            continue;
        }
        if (classification ==
                PXBackupStaleWorkspaceCleanupRawTopLevelNameMalformedReserved ||
            exceedsComponentLimit) {
            PXBackupStaleWorkspaceCleanupSetError(
                error,
                PXBackupStaleWorkspaceCleanupErrorReservedNameInvalid,
                PXBackupStaleWorkspaceCleanupEntryField,
                @"A reserved stale-workspace name is malformed");
            valid = NO;
            break;
        }
        if (names.count >= PXBackupStaleWorkspaceCleanupMaximumTopLevelCandidates) {
            PXBackupStaleWorkspaceCleanupSetError(
                error,
                PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
                PXBackupStaleWorkspaceCleanupEntryField,
                @"The stale-workspace candidate limit was exceeded");
            valid = NO;
            break;
        }
        NSData *nameData = [NSData dataWithBytes:entry->d_name length:nameLength];
        if (![nameData isKindOfClass:[NSData class]]) {
            PXBackupStaleWorkspaceCleanupSetError(
                error,
                PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
                PXBackupStaleWorkspaceCleanupEntryField,
                @"A reserved stale-workspace name could not be retained");
            valid = NO;
            break;
        }
        [names addObject:nameData];
    }
    if (closedir(directory) != 0 && valid) valid = NO;
    if (!valid) {
        if (error && !*error) {
            PXBackupStaleWorkspaceCleanupSetError(
                error,
                PXBackupStaleWorkspaceCleanupErrorTraversalFailed,
                PXBackupStaleWorkspaceCleanupEntryField,
                @"The cleanup directory scan failed");
        }
        return NO;
    }
    if (collectNames && namesOut) *namesOut = [names copy];
    if (emptyOut) *emptyOut = empty;
    return YES;
}

static BOOL PXBackupStaleWorkspaceCleanupDirectoryIsEmpty(int descriptor,
                                                    BOOL *emptyOut,
                                                    NSError **error) {
    return PXBackupStaleWorkspaceCleanupReadDirectory(
        descriptor,
        NULL,
        NO,
        PXBackupStaleWorkspaceCleanupDirectoryReadModeStrictRecursiveNames,
        NULL,
        emptyOut,
        error);
}

static BOOL PXBackupStaleWorkspaceCleanupScanStrictRecursiveEntryNames(
    int descriptor,
    PXBackupStaleWorkspaceCleanupTraversalState *state,
    NSArray<NSData *> **namesOut,
    NSError **error) {
    return PXBackupStaleWorkspaceCleanupReadDirectory(
        descriptor,
        state,
        YES,
        PXBackupStaleWorkspaceCleanupDirectoryReadModeStrictRecursiveNames,
        namesOut,
        NULL,
        error);
}

static BOOL PXBackupStaleWorkspaceCleanupScanRawTopLevelReservedNames(
    int descriptor,
    PXBackupStaleWorkspaceCleanupTraversalState *state,
    NSArray<NSData *> **namesOut,
    NSError **error) {
    return PXBackupStaleWorkspaceCleanupReadDirectory(
        descriptor,
        state,
        YES,
        PXBackupStaleWorkspaceCleanupDirectoryReadModeRawTopLevelReservedClassification,
        namesOut,
        NULL,
        error);
}

static BOOL PXBackupStaleWorkspaceCleanupRemoveDirectoryContents(
    int descriptor,
    const struct stat *directoryIdentity,
    NSUInteger depth,
    PXBackupStaleWorkspaceCleanupTraversalState *state,
    NSError **error);

static BOOL PXBackupStaleWorkspaceCleanupRemoveRegularFile(
    int parentDescriptor,
    const char *name,
    const struct stat *observed,
    PXBackupStaleWorkspaceCleanupTraversalState *state,
    NSError **error) {
    if (!observed || !state || !S_ISREG(observed->st_mode) ||
        observed->st_dev != state->workspaceDevice ||
        (observed->st_mode & (S_ISUID | S_ISGID)) != 0 ||
        observed->st_nlink != 1) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorUnsafeReservedEntry,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"The cleanup tree contains an unsafe regular file");
        return NO;
    }
    int descriptor = openat(parentDescriptor,
                            name,
                            O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
    if (descriptor < 0) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorEntryChanged,
            PXBackupStaleWorkspaceCleanupEntryField,
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
                 PXBackupStaleWorkspaceCleanupStableFileMatches(observed,
                                                         &descriptorStat) &&
                 PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(descriptor) &&
                 fstatat(parentDescriptor,
                         name,
                         &namespaceStat,
                         AT_SYMLINK_NOFOLLOW) == 0 &&
                 PXBackupStaleWorkspaceCleanupStableFileMatches(&namespaceStat,
                                                         &descriptorStat);
    if (!valid) {
        close(descriptor);
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorEntryChanged,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"A cleanup file changed during identity validation");
        return NO;
    }
    if (state->removedEntries == NSUIntegerMax) {
        close(descriptor);
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"The cleanup removal count overflowed");
        return NO;
    }
    char *quarantineName = NULL;
    if (!PXBackupStaleWorkspaceCleanupCaptureEntry(
            parentDescriptor,
            name,
            descriptor,
            &descriptorStat,
            PXBackupStaleWorkspaceCleanupCaptureTypeRegularFile,
            state->workspaceDevice,
            NO,
            state->destructiveMutationOccurred || state->removedEntries > 0,
            &quarantineName,
            error)) {
        close(descriptor);
        return NO;
    }
    if (!PXBackupStaleWorkspaceCleanupCapturedBindingValid(
            parentDescriptor,
            quarantineName,
            descriptor,
            &descriptorStat,
            PXBackupStaleWorkspaceCleanupCaptureTypeRegularFile,
            state->workspaceDevice,
            NO,
            NULL)) {
        free(quarantineName);
        close(descriptor);
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            state->destructiveMutationOccurred || state->removedEntries > 0
                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
                : PXBackupStaleWorkspaceCleanupErrorEntryChanged,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"A quarantined cleanup file changed before removal");
        return NO;
    }
    if (unlinkat(parentDescriptor, quarantineName, 0) != 0) {
        free(quarantineName);
        close(descriptor);
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            state->destructiveMutationOccurred || state->removedEntries > 0
                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
                : PXBackupStaleWorkspaceCleanupErrorRemovalFailed,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"A quarantined cleanup file could not be removed");
        return NO;
    }
    state->destructiveMutationOccurred = YES;
    struct stat unlinkedStat;
    BOOL removed =
        PXBackupStaleWorkspaceCleanupEntryIsAbsent(parentDescriptor, quarantineName) &&
        fstat(descriptor, &unlinkedStat) == 0 &&
        PXBackupStaleWorkspaceCleanupStatIdentityMatches(&descriptorStat,
                                                  &unlinkedStat) &&
        unlinkedStat.st_nlink == 0;
    free(quarantineName);
    close(descriptor);
    if (!removed) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"A cleanup file removal could not be proven");
        return NO;
    }
    if (!PXBackupStaleWorkspaceCleanupStrictSync(parentDescriptor)) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
            PXBackupStaleWorkspaceCleanupDurabilityField,
            @"A cleanup file removal could not be synchronized");
        return NO;
    }
    state->removedEntries += 1U;
    return YES;
}

static BOOL PXBackupStaleWorkspaceCleanupRemoveSubdirectory(
    int parentDescriptor,
    const char *name,
    const struct stat *observed,
    NSUInteger depth,
    PXBackupStaleWorkspaceCleanupTraversalState *state,
    NSError **error) {
    if (!observed || !state || !S_ISDIR(observed->st_mode) ||
        observed->st_dev != state->workspaceDevice ||
        (observed->st_mode & (S_ISUID | S_ISGID)) != 0) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorUnsafeReservedEntry,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"The cleanup tree contains an unsafe directory");
        return NO;
    }
    if (depth >= PXBackupStaleWorkspaceCleanupMaximumDepth) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"The cleanup tree exceeds the maximum depth");
        return NO;
    }
    int descriptor = openat(parentDescriptor,
                            name,
                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (descriptor < 0) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorEntryChanged,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"A cleanup directory changed before it could be opened");
        return NO;
    }
    struct stat descriptorStat;
    BOOL bindingValid = fstat(descriptor, &descriptorStat) == 0 &&
                        S_ISDIR(descriptorStat.st_mode) &&
                        descriptorStat.st_dev == state->workspaceDevice &&
                        (descriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
                        PXBackupStaleWorkspaceCleanupStatIdentityMatches(observed,
                                                                 &descriptorStat) &&
                        PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(descriptor);
    if (!bindingValid) {
        close(descriptor);
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorEntryChanged,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"A cleanup directory changed during identity validation");
        return NO;
    }
    if (!PXBackupStaleWorkspaceCleanupRemoveDirectoryContents(descriptor,
                                                       &descriptorStat,
                                                       depth + 1U,
                                                       state,
                                                       error)) {
        close(descriptor);
        return NO;
    }
    BOOL empty = NO;
    if (!PXBackupStaleWorkspaceCleanupDirectoryIsEmpty(descriptor, &empty, error) ||
        !empty) {
        close(descriptor);
        if (error && !*error) {
            PXBackupStaleWorkspaceCleanupSetError(
                error,
                PXBackupStaleWorkspaceCleanupErrorEntryChanged,
                PXBackupStaleWorkspaceCleanupEntryField,
                @"A cleanup directory was repopulated during traversal");
        }
        return NO;
    }
    if (!PXBackupStaleWorkspaceCleanupStrictSync(descriptor)) {
        close(descriptor);
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            state->destructiveMutationOccurred || state->removedEntries > 0
                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
                : PXBackupStaleWorkspaceCleanupErrorDurabilityFailed,
            PXBackupStaleWorkspaceCleanupDurabilityField,
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
                  PXBackupStaleWorkspaceCleanupStatIdentityMatches(&namespaceStat,
                                                            &descriptorStat) &&
                  PXBackupStaleWorkspaceCleanupStatIdentityMatches(&currentDescriptorStat,
                                                            &descriptorStat);
    if (!stable) {
        close(descriptor);
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            state->destructiveMutationOccurred || state->removedEntries > 0
                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
                : PXBackupStaleWorkspaceCleanupErrorEntryChanged,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"A cleanup directory changed before atomic capture");
        return NO;
    }
    if (state->removedEntries == NSUIntegerMax) {
        close(descriptor);
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"The cleanup removal count overflowed");
        return NO;
    }
    char *quarantineName = NULL;
    if (!PXBackupStaleWorkspaceCleanupCaptureEntry(
            parentDescriptor,
            name,
            descriptor,
            &descriptorStat,
            PXBackupStaleWorkspaceCleanupCaptureTypeDirectory,
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
        PXBackupStaleWorkspaceCleanupCapturedBindingValid(
            parentDescriptor,
            quarantineName,
            descriptor,
            &descriptorStat,
            PXBackupStaleWorkspaceCleanupCaptureTypeDirectory,
            state->workspaceDevice,
            NO,
            NULL) &&
        PXBackupStaleWorkspaceCleanupDirectoryIsEmpty(descriptor,
                                               &capturedEmpty,
                                               &capturedEmptyError) &&
        capturedEmpty;
    if (!capturedValid) {
        free(quarantineName);
        close(descriptor);
        if (error) {
            *error = capturedEmptyError;
            if (!*error) {
                PXBackupStaleWorkspaceCleanupSetError(
                    error,
                    state->destructiveMutationOccurred || state->removedEntries > 0
                        ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
                        : PXBackupStaleWorkspaceCleanupErrorEntryChanged,
                    PXBackupStaleWorkspaceCleanupEntryField,
                    @"A quarantined cleanup directory changed before removal");
            }
        }
        return NO;
    }
    if (unlinkat(parentDescriptor, quarantineName, AT_REMOVEDIR) != 0) {
        free(quarantineName);
        close(descriptor);
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            state->destructiveMutationOccurred || state->removedEntries > 0
                ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
                : PXBackupStaleWorkspaceCleanupErrorRemovalFailed,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"A quarantined cleanup directory could not be removed");
        return NO;
    }
    state->destructiveMutationOccurred = YES;
    BOOL removed =
        PXBackupStaleWorkspaceCleanupEntryIsAbsent(parentDescriptor, quarantineName);
    free(quarantineName);
    close(descriptor);
    if (!removed) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"A cleanup directory removal could not be proven");
        return NO;
    }
    if (!PXBackupStaleWorkspaceCleanupStrictSync(parentDescriptor)) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
            PXBackupStaleWorkspaceCleanupDurabilityField,
            @"A cleanup directory removal could not be synchronized");
        return NO;
    }
    state->removedEntries += 1U;
    return YES;
}

static BOOL PXBackupStaleWorkspaceCleanupRemoveDirectoryContents(
    int descriptor,
    const struct stat *directoryIdentity,
    NSUInteger depth,
    PXBackupStaleWorkspaceCleanupTraversalState *state,
    NSError **error) {
    if (descriptor < 0 || !directoryIdentity || !state ||
        depth > PXBackupStaleWorkspaceCleanupMaximumDepth) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"The cleanup traversal exceeded fixed limits");
        return NO;
    }
    struct stat currentDirectory;
    if (fstat(descriptor, &currentDirectory) != 0 ||
        !S_ISDIR(currentDirectory.st_mode) ||
        currentDirectory.st_dev != state->workspaceDevice ||
        (currentDirectory.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        !PXBackupStaleWorkspaceCleanupStatIdentityMatches(directoryIdentity,
                                                   &currentDirectory) ||
        !PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(descriptor)) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorEntryChanged,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"A cleanup directory identity changed during traversal");
        return NO;
    }
    NSArray<NSData *> *names = nil;
    if (!PXBackupStaleWorkspaceCleanupScanStrictRecursiveEntryNames(
            descriptor,
            state,
            &names,
            error)) return NO;
    for (NSData *nameData in names) {
        char *name = PXBackupStaleWorkspaceCleanupCopyCString(nameData);
        if (!name) {
            PXBackupStaleWorkspaceCleanupSetError(
                error,
                PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
                PXBackupStaleWorkspaceCleanupEntryField,
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
            PXBackupStaleWorkspaceCleanupSetError(
                error,
                PXBackupStaleWorkspaceCleanupErrorEntryChanged,
                PXBackupStaleWorkspaceCleanupEntryField,
                @"A cleanup entry changed before inspection");
            return NO;
        }
        BOOL removed = NO;
        if (S_ISREG(observed.st_mode)) {
            removed = PXBackupStaleWorkspaceCleanupRemoveRegularFile(descriptor,
                                                              name,
                                                              &observed,
                                                              state,
                                                              error);
        } else if (S_ISDIR(observed.st_mode)) {
            removed = PXBackupStaleWorkspaceCleanupRemoveSubdirectory(descriptor,
                                                               name,
                                                               &observed,
                                                               depth,
                                                               state,
                                                               error);
        } else {
            PXBackupStaleWorkspaceCleanupSetError(
                error,
                PXBackupStaleWorkspaceCleanupErrorUnsafeReservedEntry,
                PXBackupStaleWorkspaceCleanupEntryField,
                @"The cleanup tree contains an unsupported entry type");
        }
        free(name);
        if (!removed) return NO;
    }
    BOOL empty = NO;
    if (!PXBackupStaleWorkspaceCleanupDirectoryIsEmpty(descriptor, &empty, error)) {
        return NO;
    }
    if (!empty) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorEntryChanged,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"The cleanup directory changed during traversal");
        return NO;
    }
    return YES;
}


typedef struct {
    char *name;
    int descriptor;
    struct stat identity;
} PXBackupStaleWorkspaceCandidate;

static NSComparisonResult PXBackupStaleWorkspaceCleanupCompareData(NSData *left,
                                                                    NSData *right) {
    NSUInteger common = MIN(left.length, right.length);
    int comparison = common == 0 ? 0 : memcmp(left.bytes, right.bytes, common);
    if (comparison < 0) return NSOrderedAscending;
    if (comparison > 0) return NSOrderedDescending;
    if (left.length < right.length) return NSOrderedAscending;
    if (left.length > right.length) return NSOrderedDescending;
    return NSOrderedSame;
}

static void PXBackupStaleWorkspaceCleanupCloseCandidates(
    PXBackupStaleWorkspaceCandidate *candidates,
    NSUInteger count) {
    if (!candidates) return;
    for (NSUInteger index = 0; index < count; index++) {
        if (candidates[index].descriptor >= 0) {
            close(candidates[index].descriptor);
            candidates[index].descriptor = -1;
        }
        if (candidates[index].name) {
            free(candidates[index].name);
            candidates[index].name = NULL;
        }
    }
    free(candidates);
}

static NSError *PXBackupStaleWorkspaceCleanupErrorOrMissing(NSError *candidate) {
    return candidate ?: [NSError
        errorWithDomain:PXBackupStaleWorkspaceCleanupErrorDomain
                   code:PXBackupStaleWorkspaceCleanupErrorMissingError
               userInfo:@{
                   NSLocalizedDescriptionKey:
                       @"The stale-cleanup operation failed without an error",
                   PXBackupStaleWorkspaceCleanupErrorFieldPathKey:
                       PXBackupStaleWorkspaceCleanupField,
               }];
}

@interface PXBackupStaleWorkspaceCleanup () {
    PXBackupBundleLock *_bundleLock;
    NSString *_canonicalBundleDirectoryPath;
    NSString *_bundleIdentifier;
    int _bundleDescriptor;
    struct stat _bundleIdentity;
    BOOL _cleanupAttempted;
    BOOL _cleanupCompleted;
    BOOL _cleanupFailed;
    NSUInteger _cleanedWorkspaceCount;
    NSUInteger _removedEntryCount;
}

- (instancetype)initWithBundleLock:(PXBackupBundleLock *)bundleLock
             canonicalBundlePath:(NSString *)canonicalBundlePath
                bundleIdentifier:(NSString *)bundleIdentifier
                bundleDescriptor:(int)bundleDescriptor
                  bundleIdentity:(const struct stat *)bundleIdentity;

@end

@implementation PXBackupStaleWorkspaceCleanup

+ (nullable instancetype)cleanupForBundleLock:(PXBackupBundleLock *)bundleLock
                                        error:(NSError **)error {
    if (error) *error = nil;
    if (![bundleLock isMemberOfClass:[PXBackupBundleLock class]]) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorInvalidInput,
            PXBackupStaleWorkspaceCleanupLockField,
            @"The stale-cleanup bundle lock is invalid");
        return nil;
    }
    NSError *lockError = nil;
    if (![bundleLock validateOwnershipWithError:&lockError]) {
        (void)lockError;
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorLockValidationFailed,
            PXBackupStaleWorkspaceCleanupLockField,
            @"The stale-cleanup bundle lock is not owned");
        return nil;
    }
    NSString *path = bundleLock.canonicalBundleDirectoryPath;
    NSString *bundleIdentifier = bundleLock.bundleIdentifier;
    NSData *pathData = [path dataUsingEncoding:NSUTF8StringEncoding
                          allowLossyConversion:NO];
    NSString *pathRoundTrip = [pathData isKindOfClass:[NSData class]]
        ? [[NSString alloc] initWithData:pathData encoding:NSUTF8StringEncoding]
        : nil;
    NSString *expectedPath = [bundleLock.canonicalBackupRootPath
        stringByAppendingPathComponent:bundleIdentifier];
    if (![path isKindOfClass:[NSString class]] || ![path hasPrefix:@"/"] ||
        PXBackupStaleWorkspaceCleanupStringContainsNUL(path) ||
        ![pathData isKindOfClass:[NSData class]] || pathData.length == 0 ||
        pathData.length > PXBackupStaleWorkspaceCleanupMaximumWorkspacePathBytes ||
        ![pathRoundTrip isEqualToString:path] ||
        !PXBackupStaleWorkspaceCleanupValidateComponentString(bundleIdentifier, NULL) ||
        ![path isEqualToString:expectedPath]) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorInvalidInput,
            PXBackupStaleWorkspaceCleanupParentField,
            @"The stale-cleanup bundle directory is invalid");
        return nil;
    }
    char *pathBytes = PXBackupStaleWorkspaceCleanupCopyCString(pathData);
    if (!pathBytes) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorInternalInvariantFailed,
            PXBackupStaleWorkspaceCleanupParentField,
            @"The stale-cleanup bundle directory could not be retained");
        return nil;
    }
    struct stat namespaceStat;
    int descriptor = -1;
    if (lstat(pathBytes, &namespaceStat) != 0 ||
        !S_ISDIR(namespaceStat.st_mode) ||
        (namespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
        free(pathBytes);
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorParentInspectionFailed,
            PXBackupStaleWorkspaceCleanupParentField,
            @"The stale-cleanup bundle directory is unsafe");
        return nil;
    }
    descriptor = open(pathBytes,
                      O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    free(pathBytes);
    struct stat descriptorStat;
    if (descriptor < 0 ||
        !PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(descriptor) ||
        fstat(descriptor, &descriptorStat) != 0 ||
        !PXBackupStaleWorkspaceCleanupStatIdentityMatches(&namespaceStat,
                                                          &descriptorStat)) {
        if (descriptor >= 0) close(descriptor);
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorFilesystemChanged,
            PXBackupStaleWorkspaceCleanupParentField,
            @"The stale-cleanup bundle directory identity changed");
        return nil;
    }
    NSError *finalLockError = nil;
    if (![bundleLock validateOwnershipWithError:&finalLockError]) {
        (void)finalLockError;
        close(descriptor);
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorLockValidationFailed,
            PXBackupStaleWorkspaceCleanupLockField,
            @"The stale-cleanup bundle lock changed during binding");
        return nil;
    }
    PXBackupStaleWorkspaceCleanup *result =
        [[PXBackupStaleWorkspaceCleanup alloc]
            initWithBundleLock:bundleLock
           canonicalBundlePath:path
              bundleIdentifier:bundleIdentifier
              bundleDescriptor:descriptor
                bundleIdentity:&descriptorStat];
    if (!result) {
        close(descriptor);
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorInternalInvariantFailed,
            PXBackupStaleWorkspaceCleanupField,
            @"The stale-cleanup authority could not be created");
        return nil;
    }
    if (error) *error = nil;
    return result;
}

- (instancetype)initWithBundleLock:(PXBackupBundleLock *)bundleLock
             canonicalBundlePath:(NSString *)canonicalBundlePath
                bundleIdentifier:(NSString *)bundleIdentifier
                bundleDescriptor:(int)bundleDescriptor
                  bundleIdentity:(const struct stat *)bundleIdentity {
    self = [super init];
    if (self) {
        _bundleLock = bundleLock;
        _canonicalBundleDirectoryPath = [canonicalBundlePath copy];
        _bundleIdentifier = [bundleIdentifier copy];
        _bundleDescriptor = bundleDescriptor;
        _bundleIdentity = *bundleIdentity;
    }
    return self;
}

- (NSString *)canonicalBundleDirectoryPath {
    return _canonicalBundleDirectoryPath;
}

- (BOOL)cleanupAttempted {
    return _cleanupAttempted;
}

- (NSUInteger)cleanedWorkspaceCount {
    return _cleanedWorkspaceCount;
}

- (NSUInteger)removedEntryCount {
    return _removedEntryCount;
}

- (BOOL)validateIdentityWithError:(NSError **)error {
    if (error) *error = nil;
    if (_cleanupFailed || (_cleanupAttempted && !_cleanupCompleted)) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
            PXBackupStaleWorkspaceCleanupField,
            @"The stale-cleanup operation did not finish safely");
        return NO;
    }
    if (_bundleDescriptor < 0 ||
        ![_bundleLock isMemberOfClass:[PXBackupBundleLock class]] ||
        ![_canonicalBundleDirectoryPath isKindOfClass:[NSString class]] ||
        ![_bundleIdentifier isKindOfClass:[NSString class]]) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorInternalInvariantFailed,
            PXBackupStaleWorkspaceCleanupField,
            @"The stale-cleanup retained state is invalid");
        return NO;
    }
    NSError *lockError = nil;
    if (![_bundleLock validateOwnershipWithError:&lockError] ||
        !PXBackupStaleWorkspaceCleanupPathMatchesDescriptor(
            _canonicalBundleDirectoryPath,
            _bundleDescriptor,
            &_bundleIdentity,
            NO,
            NULL)) {
        (void)lockError;
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorFilesystemChanged,
            PXBackupStaleWorkspaceCleanupParentField,
            @"The stale-cleanup retained authority changed");
        return NO;
    }
    if (_cleanupCompleted) {
        PXBackupStaleWorkspaceCleanupTraversalState validationState = {0};
        validationState.workspaceDevice = _bundleIdentity.st_dev;
        NSArray<NSData *> *names = nil;
        NSError *scanError = nil;
        if (!PXBackupStaleWorkspaceCleanupScanRawTopLevelReservedNames(
                _bundleDescriptor,
                &validationState,
                &names,
                &scanError)) {
            if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(scanError);
            return NO;
        }
        if (names.count > 0U) {
            PXBackupStaleWorkspaceCleanupSetError(
                error,
                PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
                PXBackupStaleWorkspaceCleanupEntryField,
                @"Reserved stale-cleanup evidence remains after cleanup");
            return NO;
        }
    }
    if (error) *error = nil;
    return YES;
}

- (BOOL)removeStaleWorkspacesWithError:(NSError **)error {
    if (error) *error = nil;
    if (_cleanupAttempted) {
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorAlreadyPerformed,
            PXBackupStaleWorkspaceCleanupField,
            @"The stale-cleanup operation is one-shot");
        return NO;
    }
    NSError *identityError = nil;
    if (![self validateIdentityWithError:&identityError]) {
        _cleanupAttempted = YES;
        _cleanupFailed = YES;
        if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(identityError);
        return NO;
    }
    _cleanupAttempted = YES;

    PXBackupStaleWorkspaceCleanupTraversalState state = {0};
    state.workspaceDevice = _bundleIdentity.st_dev;
    NSArray<NSData *> *allNames = nil;
    NSError *scanError = nil;
    if (!PXBackupStaleWorkspaceCleanupScanRawTopLevelReservedNames(
            _bundleDescriptor,
            &state,
            &allNames,
            &scanError)) {
        _cleanupFailed = YES;
        if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(scanError);
        return NO;
    }
    NSArray<NSData *> *sortedNames = [allNames sortedArrayUsingComparator:
        ^NSComparisonResult(NSData *left, NSData *right) {
            return PXBackupStaleWorkspaceCleanupCompareData(left, right);
        }];
    PXBackupStaleWorkspaceCandidate *candidates = calloc(
        PXBackupStaleWorkspaceCleanupMaximumTopLevelCandidates,
        sizeof(PXBackupStaleWorkspaceCandidate));
    if (!candidates) {
        _cleanupFailed = YES;
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"The stale-cleanup candidate list could not be allocated");
        return NO;
    }
    for (NSUInteger index = 0;
         index < PXBackupStaleWorkspaceCleanupMaximumTopLevelCandidates;
         index++) {
        candidates[index].descriptor = -1;
    }
    NSUInteger candidateCount = 0U;
    BOOL preflightValid = YES;
    NSError *preflightError = nil;
    for (NSData *nameData in sortedNames) {
        if (candidateCount >= PXBackupStaleWorkspaceCleanupMaximumTopLevelCandidates) {
            PXBackupStaleWorkspaceCleanupSetError(
                &preflightError,
                PXBackupStaleWorkspaceCleanupErrorLimitExceeded,
                PXBackupStaleWorkspaceCleanupEntryField,
                @"The stale-workspace candidate limit was exceeded");
            preflightValid = NO;
            break;
        }
        char *nameBytes = PXBackupStaleWorkspaceCleanupCopyCString(nameData);
        struct stat namespaceStat;
        if (!nameBytes ||
            fstatat(_bundleDescriptor,
                    nameBytes,
                    &namespaceStat,
                    AT_SYMLINK_NOFOLLOW) != 0 ||
            !S_ISDIR(namespaceStat.st_mode) ||
            (namespaceStat.st_mode & 07777) != 0700 ||
            (namespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
            namespaceStat.st_dev != _bundleIdentity.st_dev) {
            free(nameBytes);
            PXBackupStaleWorkspaceCleanupSetError(
                &preflightError,
                PXBackupStaleWorkspaceCleanupErrorUnsafeReservedEntry,
                PXBackupStaleWorkspaceCleanupEntryField,
                @"A reserved stale-workspace entry is unsafe");
            preflightValid = NO;
            break;
        }
        int descriptor = openat(_bundleDescriptor,
                                nameBytes,
                                O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        struct stat descriptorStat;
        if (descriptor < 0 ||
            !PXBackupStaleWorkspaceCleanupDescriptorHasCloseOnExec(descriptor) ||
            fstat(descriptor, &descriptorStat) != 0 ||
            !PXBackupStaleWorkspaceCleanupStatIdentityMatches(&namespaceStat,
                                                              &descriptorStat) ||
            (descriptorStat.st_mode & 07777) != 0700) {
            if (descriptor >= 0) close(descriptor);
            free(nameBytes);
            PXBackupStaleWorkspaceCleanupSetError(
                &preflightError,
                PXBackupStaleWorkspaceCleanupErrorEntryChanged,
                PXBackupStaleWorkspaceCleanupEntryField,
                @"A reserved stale-workspace entry changed during preflight");
            preflightValid = NO;
            break;
        }
        candidates[candidateCount].name = nameBytes;
        candidates[candidateCount].descriptor = descriptor;
        candidates[candidateCount].identity = descriptorStat;
        candidateCount += 1U;
    }
    if (!preflightValid) {
        PXBackupStaleWorkspaceCleanupCloseCandidates(candidates, candidateCount);
        _cleanupFailed = YES;
        if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(preflightError);
        return NO;
    }

    for (NSUInteger index = 0; index < candidateCount; index++) {
        PXBackupStaleWorkspaceCandidate *candidate = &candidates[index];
        NSError *operationError = nil;
        NSError *candidateLockError = nil;
        BOOL validBefore = [_bundleLock validateOwnershipWithError:&candidateLockError] &&
            PXBackupStaleWorkspaceCleanupPathMatchesDescriptor(
                _canonicalBundleDirectoryPath,
                _bundleDescriptor,
                &_bundleIdentity,
                NO,
                NULL) &&
            PXBackupStaleWorkspaceCleanupDirectoryBindingValid(
                _bundleDescriptor,
                candidate->name,
                candidate->descriptor,
                &candidate->identity,
                _bundleIdentity.st_dev,
                YES,
                NULL);
        if (!validBefore) {
            if (!operationError) {
                PXBackupStaleWorkspaceCleanupSetError(
                    &operationError,
                    PXBackupStaleWorkspaceCleanupErrorEntryChanged,
                    PXBackupStaleWorkspaceCleanupEntryField,
                    @"A stale-workspace authority changed before cleanup");
            }
            _cleanupFailed = YES;
            _removedEntryCount = state.removedEntries;
            PXBackupStaleWorkspaceCleanupCloseCandidates(candidates, candidateCount);
            if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(operationError);
            return NO;
        }
        if (!PXBackupStaleWorkspaceCleanupRemoveDirectoryContents(
                candidate->descriptor,
                &candidate->identity,
                0U,
                &state,
                &operationError)) {
            _cleanupFailed = YES;
            _removedEntryCount = state.removedEntries;
            PXBackupStaleWorkspaceCleanupCloseCandidates(candidates, candidateCount);
            if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(operationError);
            return NO;
        }
        BOOL empty = NO;
        if (!PXBackupStaleWorkspaceCleanupDirectoryIsEmpty(
                candidate->descriptor,
                &empty,
                &operationError) ||
            !empty ||
            !PXBackupStaleWorkspaceCleanupStrictSync(candidate->descriptor)) {
            if (!operationError) {
                PXBackupStaleWorkspaceCleanupSetError(
                    &operationError,
                    state.removedEntries > 0
                        ? PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete
                        : PXBackupStaleWorkspaceCleanupErrorDurabilityFailed,
                    PXBackupStaleWorkspaceCleanupDurabilityField,
                    @"A stale workspace could not be synchronized before capture");
            }
            _cleanupFailed = YES;
            _removedEntryCount = state.removedEntries;
            PXBackupStaleWorkspaceCleanupCloseCandidates(candidates, candidateCount);
            if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(operationError);
            return NO;
        }
        char *quarantineName = NULL;
        if (!PXBackupStaleWorkspaceCleanupCaptureEntry(
                _bundleDescriptor,
                candidate->name,
                candidate->descriptor,
                &candidate->identity,
                PXBackupStaleWorkspaceCleanupCaptureTypeDirectory,
                _bundleIdentity.st_dev,
                YES,
                state.destructiveMutationOccurred || state.removedEntries > 0,
                &quarantineName,
                &operationError)) {
            _cleanupFailed = YES;
            _removedEntryCount = state.removedEntries;
            PXBackupStaleWorkspaceCleanupCloseCandidates(candidates, candidateCount);
            if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(operationError);
            return NO;
        }
        BOOL capturedEmpty = NO;
        BOOL capturedValid =
            PXBackupStaleWorkspaceCleanupCapturedBindingValid(
                _bundleDescriptor,
                quarantineName,
                candidate->descriptor,
                &candidate->identity,
                PXBackupStaleWorkspaceCleanupCaptureTypeDirectory,
                _bundleIdentity.st_dev,
                YES,
                NULL) &&
            PXBackupStaleWorkspaceCleanupDirectoryIsEmpty(
                candidate->descriptor,
                &capturedEmpty,
                &operationError) &&
            capturedEmpty;
        if (!capturedValid ||
            unlinkat(_bundleDescriptor, quarantineName, AT_REMOVEDIR) != 0) {
            free(quarantineName);
            _cleanupFailed = YES;
            _removedEntryCount = state.removedEntries;
            if (!operationError) {
                PXBackupStaleWorkspaceCleanupSetError(
                    &operationError,
                    PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
                    PXBackupStaleWorkspaceCleanupEntryField,
                    @"A captured stale workspace could not be removed safely");
            }
            PXBackupStaleWorkspaceCleanupCloseCandidates(candidates, candidateCount);
            if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(operationError);
            return NO;
        }
        state.destructiveMutationOccurred = YES;
        BOOL removed =
            PXBackupStaleWorkspaceCleanupEntryIsAbsent(_bundleDescriptor,
                                                       quarantineName) &&
            PXBackupStaleWorkspaceCleanupEntryIsAbsent(_bundleDescriptor,
                                                       candidate->name) &&
            PXBackupStaleWorkspaceCleanupStrictSync(_bundleDescriptor);
        free(quarantineName);
        if (!removed || state.removedEntries == NSUIntegerMax ||
            _cleanedWorkspaceCount == NSUIntegerMax) {
            _cleanupFailed = YES;
            _removedEntryCount = state.removedEntries;
            PXBackupStaleWorkspaceCleanupSetError(
                &operationError,
                PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
                PXBackupStaleWorkspaceCleanupDurabilityField,
                @"A stale workspace removal could not be proven durable");
            PXBackupStaleWorkspaceCleanupCloseCandidates(candidates, candidateCount);
            if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(operationError);
            return NO;
        }
        state.removedEntries += 1U;
        _cleanedWorkspaceCount += 1U;
        close(candidate->descriptor);
        candidate->descriptor = -1;
    }
    PXBackupStaleWorkspaceCleanupCloseCandidates(candidates, candidateCount);
    _removedEntryCount = state.removedEntries;

    PXBackupStaleWorkspaceCleanupTraversalState finalState = {0};
    finalState.workspaceDevice = _bundleIdentity.st_dev;
    NSArray<NSData *> *finalNames = nil;
    NSError *finalError = nil;
    if (!PXBackupStaleWorkspaceCleanupScanRawTopLevelReservedNames(
            _bundleDescriptor,
            &finalState,
            &finalNames,
            &finalError)) {
        _cleanupFailed = YES;
        if (error) *error = PXBackupStaleWorkspaceCleanupErrorOrMissing(finalError);
        return NO;
    }
    if (finalNames.count > 0U) {
        _cleanupFailed = YES;
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorCleanupIncomplete,
            PXBackupStaleWorkspaceCleanupEntryField,
            @"Reserved stale-workspace evidence remains after cleanup");
        return NO;
    }
    NSError *finalLockError = nil;
    if (![_bundleLock validateOwnershipWithError:&finalLockError] ||
        !PXBackupStaleWorkspaceCleanupPathMatchesDescriptor(
            _canonicalBundleDirectoryPath,
            _bundleDescriptor,
            &_bundleIdentity,
            NO,
            NULL)) {
        (void)finalLockError;
        _cleanupFailed = YES;
        PXBackupStaleWorkspaceCleanupSetError(
            error,
            PXBackupStaleWorkspaceCleanupErrorFilesystemChanged,
            PXBackupStaleWorkspaceCleanupParentField,
            @"The stale-cleanup authority changed after cleanup");
        return NO;
    }
    _cleanupCompleted = YES;
    if (error) *error = nil;
    return YES;
}

- (void)dealloc {
    if (_bundleDescriptor >= 0) {
        close(_bundleDescriptor);
        _bundleDescriptor = -1;
    }
}

@end
