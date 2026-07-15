#import "PXBackupDirectoryPublisher.h"
#import "PXBackupPublicationWorkspace.h"
#import "PXBackupBundleLock.h"
#import "PXBackupArtifactWriter.h"
#import "PXBackupManifestWriter.h"
#import "PXBackupManifestValidator.h"

#import <CommonCrypto/CommonDigest.h>

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

NSErrorDomain const PXBackupDirectoryPublisherErrorDomain =
    @"com.hydra.projectx.backup-directory-publisher";
NSString * const PXBackupDirectoryPublisherErrorFieldPathKey = @"fieldPath";

static NSString * const PXBackupDirectoryPublisherField = @"$.publication";
static NSString * const PXBackupDirectoryPublisherLockField = @"$.publication.lock";
static NSString * const PXBackupDirectoryPublisherParentField = @"$.publication.parent";
static NSString * const PXBackupDirectoryPublisherWorkspaceField = @"$.publication.workspace";
static NSString * const PXBackupDirectoryPublisherFinalField = @"$.publication.finalDirectory";
static NSString * const PXBackupDirectoryPublisherManifestField = @"$.publication.manifest";
static NSString * const PXBackupDirectoryPublisherSnapshotField = @"$.publication.snapshot";

static const NSUInteger PXBackupDirectoryMaximumPathBytes = 4096U;
static const NSUInteger PXBackupDirectoryMaximumComponentBytes = 255U;
static const unsigned long long PXBackupDirectoryMaximumManifestBytes =
    128ULL * 1024ULL * 1024ULL;
static const size_t PXBackupDirectoryManifestReadBufferBytes = 64U * 1024U;
static const char PXBackupDirectoryManifestFileNameBytes[] = "manifest.plist";
static const char PXBackupDirectoryManifestTemporaryPrefixBytes[] =
    ".weaponx-manifest-partial-";

#if defined(__APPLE__)
#define PX_BACKUP_DIRECTORY_MTIME_SEC(value) ((value).st_mtimespec.tv_sec)
#define PX_BACKUP_DIRECTORY_MTIME_NSEC(value) ((value).st_mtimespec.tv_nsec)
#define PX_BACKUP_DIRECTORY_CTIME_SEC(value) ((value).st_ctimespec.tv_sec)
#define PX_BACKUP_DIRECTORY_CTIME_NSEC(value) ((value).st_ctimespec.tv_nsec)
#else
#define PX_BACKUP_DIRECTORY_MTIME_SEC(value) ((value).st_mtim.tv_sec)
#define PX_BACKUP_DIRECTORY_MTIME_NSEC(value) ((value).st_mtim.tv_nsec)
#define PX_BACKUP_DIRECTORY_CTIME_SEC(value) ((value).st_ctim.tv_sec)
#define PX_BACKUP_DIRECTORY_CTIME_NSEC(value) ((value).st_ctim.tv_nsec)
#endif

static void PXBackupDirectorySetError(
    NSError **error,
    PXBackupDirectoryPublisherErrorCode code,
    NSString *fieldPath,
    NSString *description) {
    if (!error) return;
    *error = [NSError errorWithDomain:PXBackupDirectoryPublisherErrorDomain
                                 code:code
                             userInfo:@{
                                 NSLocalizedDescriptionKey: description,
                                 PXBackupDirectoryPublisherErrorFieldPathKey: fieldPath,
                             }];
}

static BOOL PXBackupDirectoryStatIdentityMatches(const struct stat *left,
                                                  const struct stat *right) {
    return left && right &&
           left->st_dev == right->st_dev &&
           left->st_ino == right->st_ino &&
           ((left->st_mode & S_IFMT) == (right->st_mode & S_IFMT));
}

static BOOL PXBackupDirectoryStableFileStatMatches(const struct stat *left,
                                                    const struct stat *right) {
    return PXBackupDirectoryStatIdentityMatches(left, right) &&
           (left->st_mode & 07777) == (right->st_mode & 07777) &&
           left->st_nlink == right->st_nlink &&
           left->st_size == right->st_size &&
           PX_BACKUP_DIRECTORY_MTIME_SEC(*left) ==
               PX_BACKUP_DIRECTORY_MTIME_SEC(*right) &&
           PX_BACKUP_DIRECTORY_MTIME_NSEC(*left) ==
               PX_BACKUP_DIRECTORY_MTIME_NSEC(*right) &&
           PX_BACKUP_DIRECTORY_CTIME_SEC(*left) ==
               PX_BACKUP_DIRECTORY_CTIME_SEC(*right) &&
           PX_BACKUP_DIRECTORY_CTIME_NSEC(*left) ==
               PX_BACKUP_DIRECTORY_CTIME_NSEC(*right);
}

static BOOL PXBackupDirectoryDescriptorHasCloseOnExec(int descriptor) {
    if (descriptor < 0) return NO;
    int flags = -1;
    do {
        flags = fcntl(descriptor, F_GETFD);
    } while (flags < 0 && errno == EINTR);
    return flags >= 0 && (flags & FD_CLOEXEC) != 0;
}

static int PXBackupDirectoryDuplicateDescriptor(int descriptor) {
    if (descriptor < 0) return -1;
    int duplicated = -1;
#if defined(F_DUPFD_CLOEXEC)
    do {
        duplicated = fcntl(descriptor, F_DUPFD_CLOEXEC, 0);
    } while (duplicated < 0 && errno == EINTR);
    if (duplicated >= 0) return duplicated;
#endif
    do {
        duplicated = dup(descriptor);
    } while (duplicated < 0 && errno == EINTR);
    if (duplicated < 0) return -1;
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
    if (setResult < 0 ||
        !PXBackupDirectoryDescriptorHasCloseOnExec(duplicated)) {
        close(duplicated);
        return -1;
    }
    return duplicated;
}

static BOOL PXBackupDirectoryStrictSync(int descriptor) {
    if (descriptor < 0) return NO;
    int result = -1;
    do {
        result = fsync(descriptor);
    } while (result < 0 && errno == EINTR);
    return result == 0;
}

static BOOL PXBackupDirectoryRenameEntryNoReplace(
    int sourceParentDescriptor,
    const char *sourceName,
    int destinationParentDescriptor,
    const char *destinationName,
    int *failureErrnoOut) {
    if (failureErrnoOut) *failureErrnoOut = 0;
    if (sourceParentDescriptor < 0 || !sourceName || sourceName[0] == '\0' ||
        destinationParentDescriptor < 0 || !destinationName ||
        destinationName[0] == '\0') {
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

static BOOL PXBackupDirectoryStringContainsNUL(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return YES;
    for (NSUInteger index = 0; index < value.length; index++) {
        if ([value characterAtIndex:index] == 0) return YES;
    }
    return NO;
}

static BOOL PXBackupDirectoryStringContainsControl(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return YES;
    for (NSUInteger index = 0; index < value.length; index++) {
        unichar character = [value characterAtIndex:index];
        if (character < 0x20 || character == 0x7f) return YES;
    }
    return NO;
}

static NSData *PXBackupDirectoryLosslessUTF8Data(NSString *value,
                                                  NSUInteger maximumBytes,
                                                  BOOL requireAbsolute) {
    if (![value isKindOfClass:[NSString class]] || value.length == 0 ||
        PXBackupDirectoryStringContainsNUL(value) ||
        (requireAbsolute && ![value hasPrefix:@"/"])) return nil;
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding
                       allowLossyConversion:NO];
    if (!data || data.length == 0 || data.length > maximumBytes) return nil;
    NSString *roundTrip = [[NSString alloc] initWithData:data
                                                encoding:NSUTF8StringEncoding];
    if (!roundTrip || ![roundTrip isEqualToString:value]) return nil;
    return data;
}

static char *PXBackupDirectoryCopyCString(NSData *data) {
    if (![data isKindOfClass:[NSData class]] || data.length == 0 ||
        data.length > SIZE_MAX - 1) return NULL;
    char *bytes = calloc(data.length + 1, 1);
    if (!bytes) return NULL;
    memcpy(bytes, data.bytes, data.length);
    return bytes;
}

static BOOL PXBackupDirectoryValidateSafeComponent(NSString *component,
                                                    NSData **dataOut) {
    if (dataOut) *dataOut = nil;
    NSData *data = PXBackupDirectoryLosslessUTF8Data(
        component,
        PXBackupDirectoryMaximumComponentBytes,
        NO);
    if (!data || PXBackupDirectoryStringContainsControl(component) ||
        [component isEqualToString:@"."] ||
        [component isEqualToString:@".."] ||
        [component containsString:@"/"] ||
        [component containsString:@"\\"]) return NO;
    if (dataOut) *dataOut = data;
    return YES;
}

static BOOL PXBackupDirectoryValidateTimestamp(NSString *timestamp) {
    NSData *data = PXBackupDirectoryLosslessUTF8Data(timestamp, 15U, NO);
    if (!data || data.length != 15U) return NO;
    const unsigned char *bytes = data.bytes;
    for (NSUInteger index = 0; index < data.length; index++) {
        if (index == 8U) {
            if (bytes[index] != '-') return NO;
        } else if (bytes[index] < '0' || bytes[index] > '9') {
            return NO;
        }
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    formatter.dateFormat = @"yyyyMMdd-HHmmss";
    formatter.lenient = NO;
    NSDate *date = [formatter dateFromString:timestamp];
    NSString *roundTrip = date ? [formatter stringFromDate:date] : nil;
    return roundTrip && [roundTrip isEqualToString:timestamp];
}

static BOOL PXBackupDirectoryValidateBackupIdentifier(NSString *identifier) {
    NSData *data = PXBackupDirectoryLosslessUTF8Data(identifier, 36U, NO);
    if (!data || data.length != 36U) return NO;
    const unsigned char *bytes = data.bytes;
    for (NSUInteger index = 0; index < data.length; index++) {
        BOOL hyphen = index == 8U || index == 13U || index == 18U || index == 23U;
        if (hyphen) {
            if (bytes[index] != '-') return NO;
            continue;
        }
        BOOL digit = bytes[index] >= '0' && bytes[index] <= '9';
        BOOL lowerHex = bytes[index] >= 'a' && bytes[index] <= 'f';
        if (!digit && !lowerHex) return NO;
    }
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:identifier];
    NSString *roundTrip = uuid.UUIDString.lowercaseString;
    return roundTrip && [roundTrip isEqualToString:identifier];
}

static BOOL PXBackupDirectoryValidateFinalName(NSString *finalName,
                                               NSData **dataOut) {
    NSData *data = nil;
    if (!PXBackupDirectoryValidateSafeComponent(finalName, &data)) return NO;
    if ([finalName hasPrefix:PXBackupPublicationPartialDirectoryPrefix] ||
        [finalName hasPrefix:PXBackupArtifactTemporaryDirectoryPrefix] ||
        [finalName hasPrefix:PXBackupManifestTemporaryFilePrefix] ||
        [finalName isEqualToString:PXBackupBundleLockFileName] ||
        [finalName isEqualToString:PXBackupManifestFinalFileName]) return NO;
    if (dataOut) *dataOut = data;
    return YES;
}

static BOOL PXBackupDirectoryPathMatchesDescriptor(NSString *path,
                                                    int descriptor,
                                                    const struct stat *expected,
                                                    BOOL requireMode0700,
                                                    struct stat *currentOut) {
    NSData *data = PXBackupDirectoryLosslessUTF8Data(
        path,
        PXBackupDirectoryMaximumPathBytes,
        YES);
    char *bytes = PXBackupDirectoryCopyCString(data);
    if (!bytes) return NO;
    struct stat pathStat;
    struct stat descriptorStat;
    BOOL valid = lstat(bytes, &pathStat) == 0 &&
                 !S_ISLNK(pathStat.st_mode) &&
                 S_ISDIR(pathStat.st_mode) &&
                 (pathStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
                 (!requireMode0700 || (pathStat.st_mode & 07777) == 0700) &&
                 fstat(descriptor, &descriptorStat) == 0 &&
                 S_ISDIR(descriptorStat.st_mode) &&
                 (descriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
                 (!requireMode0700 || (descriptorStat.st_mode & 07777) == 0700) &&
                 PXBackupDirectoryStatIdentityMatches(&pathStat, &descriptorStat) &&
                 (!expected ||
                  PXBackupDirectoryStatIdentityMatches(expected, &descriptorStat)) &&
                 PXBackupDirectoryDescriptorHasCloseOnExec(descriptor);
    free(bytes);
    if (valid && currentOut) *currentOut = descriptorStat;
    return valid;
}

static BOOL PXBackupDirectoryEntryIsAbsent(int parentDescriptor,
                                           const char *name) {
    struct stat namespaceStat;
    if (fstatat(parentDescriptor,
                name,
                &namespaceStat,
                AT_SYMLINK_NOFOLLOW) == 0) return NO;
    return errno == ENOENT;
}

static BOOL PXBackupDirectoryDirectoryBindingValid(
    int parentDescriptor,
    const char *name,
    int descriptor,
    const struct stat *expected,
    dev_t expectedDevice,
    struct stat *currentOut) {
    if (parentDescriptor < 0 || !name || descriptor < 0 || !expected) return NO;
    struct stat namespaceStat;
    struct stat descriptorStat;
    if (fstatat(parentDescriptor,
                name,
                &namespaceStat,
                AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(namespaceStat.st_mode) ||
        (namespaceStat.st_mode & 07777) != 0700 ||
        (namespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        namespaceStat.st_dev != expectedDevice ||
        fstat(descriptor, &descriptorStat) != 0 ||
        !S_ISDIR(descriptorStat.st_mode) ||
        (descriptorStat.st_mode & 07777) != 0700 ||
        (descriptorStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        descriptorStat.st_dev != expectedDevice ||
        !PXBackupDirectoryStatIdentityMatches(&namespaceStat, &descriptorStat) ||
        !PXBackupDirectoryStatIdentityMatches(expected, &descriptorStat) ||
        !PXBackupDirectoryDescriptorHasCloseOnExec(descriptor)) return NO;
    if (currentOut) *currentOut = descriptorStat;
    return YES;
}

static BOOL PXBackupDirectoryManifestBindingValid(
    int directoryDescriptor,
    int manifestDescriptor,
    const struct stat *expected,
    unsigned long long expectedSize,
    struct stat *currentOut) {
    if (directoryDescriptor < 0 || manifestDescriptor < 0 || !expected ||
        expectedSize == 0 || expectedSize > (unsigned long long)LLONG_MAX) return NO;
    struct stat namespaceStat;
    struct stat descriptorStat;
    if (fstatat(directoryDescriptor,
                PXBackupDirectoryManifestFileNameBytes,
                &namespaceStat,
                AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISREG(namespaceStat.st_mode) ||
        namespaceStat.st_nlink != 1 ||
        (namespaceStat.st_mode & 07777) != 0600 ||
        fstat(manifestDescriptor, &descriptorStat) != 0 ||
        !S_ISREG(descriptorStat.st_mode) ||
        descriptorStat.st_nlink != 1 ||
        (descriptorStat.st_mode & 07777) != 0600 ||
        descriptorStat.st_size < 0 ||
        (unsigned long long)descriptorStat.st_size != expectedSize ||
        namespaceStat.st_size != descriptorStat.st_size ||
        namespaceStat.st_dev != descriptorStat.st_dev ||
        !PXBackupDirectoryStatIdentityMatches(&namespaceStat, &descriptorStat) ||
        !PXBackupDirectoryStableFileStatMatches(expected, &descriptorStat) ||
        !PXBackupDirectoryDescriptorHasCloseOnExec(manifestDescriptor)) return NO;
    if (currentOut) *currentOut = descriptorStat;
    return YES;
}

static BOOL PXBackupDirectoryScanManifestTemporaryEntries(int directoryDescriptor) {
    int duplicated = PXBackupDirectoryDuplicateDescriptor(directoryDescriptor);
    if (duplicated < 0) return NO;
    DIR *directory = fdopendir(duplicated);
    if (!directory) {
        close(duplicated);
        return NO;
    }
    const size_t prefixLength =
        sizeof(PXBackupDirectoryManifestTemporaryPrefixBytes) - 1;
    BOOL valid = YES;
    errno = 0;
    struct dirent *entry = NULL;
    while ((entry = readdir(directory)) != NULL) {
        if (strncmp(entry->d_name,
                    PXBackupDirectoryManifestTemporaryPrefixBytes,
                    prefixLength) == 0) {
            valid = NO;
            break;
        }
    }
    if (!entry && errno != 0) valid = NO;
    if (closedir(directory) != 0) valid = NO;
    return valid;
}

static NSString *PXBackupDirectoryHexDigest(const unsigned char *digest,
                                            size_t length) {
    static const char alphabet[] = "0123456789abcdef";
    if (!digest || length != CC_SHA256_DIGEST_LENGTH) return nil;
    char bytes[(CC_SHA256_DIGEST_LENGTH * 2) + 1];
    for (size_t index = 0; index < length; index++) {
        bytes[index * 2] = alphabet[(digest[index] >> 4) & 0x0f];
        bytes[(index * 2) + 1] = alphabet[digest[index] & 0x0f];
    }
    bytes[CC_SHA256_DIGEST_LENGTH * 2] = '\0';
    return [[NSString alloc] initWithBytes:bytes
                                   length:CC_SHA256_DIGEST_LENGTH * 2
                                 encoding:NSASCIIStringEncoding];
}

static BOOL PXBackupDirectoryDigestIsLowercaseSHA256(NSString *digest) {
    NSData *data = PXBackupDirectoryLosslessUTF8Data(digest, 64U, NO);
    if (!data || data.length != 64U) return NO;
    const unsigned char *bytes = data.bytes;
    for (NSUInteger index = 0; index < data.length; index++) {
        BOOL digit = bytes[index] >= '0' && bytes[index] <= '9';
        BOOL lowerHex = bytes[index] >= 'a' && bytes[index] <= 'f';
        if (!digit && !lowerHex) return NO;
    }
    return YES;
}

static BOOL PXBackupDirectoryReadUnsignedIntegral(id value,
                                                  unsigned long long *valueOut) {
    if (![value isKindOfClass:[NSNumber class]] ||
        CFGetTypeID((__bridge CFTypeRef)value) != CFNumberGetTypeID()) return NO;
    const char *type = [(NSNumber *)value objCType];
    if (!type || !type[0]) return NO;
    unsigned long long result = 0;
    switch (type[0]) {
        case 'C': case 'S': case 'I': case 'L': case 'Q':
            result = [(NSNumber *)value unsignedLongLongValue];
            break;
        case 'c': case 's': case 'i': case 'l': case 'q': {
            long long signedValue = [(NSNumber *)value longLongValue];
            if (signedValue < 0) return NO;
            result = (unsigned long long)signedValue;
            break;
        }
        default:
            return NO;
    }
    if (valueOut) *valueOut = result;
    return YES;
}

static NSDictionary *PXBackupDirectoryParseManifestData(NSData *data) {
    if (![data isKindOfClass:[NSData class]] || data.length == 0) return nil;
    id object = nil;
    @try {
        object = [NSPropertyListSerialization
            propertyListWithData:data
                         options:NSPropertyListImmutable
                          format:NULL
                           error:NULL];
    } @catch (NSException *exception) {
        (void)exception;
        object = nil;
    }
    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}

static BOOL PXBackupDirectoryReadManifestDescriptor(
    int descriptor,
    const struct stat *expectedIdentity,
    unsigned long long expectedSize,
    NSData **dataOut,
    NSString **digestOut,
    struct stat *stableIdentityOut) {
    if (dataOut) *dataOut = nil;
    if (digestOut) *digestOut = nil;
    if (descriptor < 0 || !expectedIdentity || expectedSize == 0 ||
        expectedSize > PXBackupDirectoryMaximumManifestBytes ||
        expectedSize > NSUIntegerMax ||
        expectedSize > (unsigned long long)LLONG_MAX) return NO;
    struct stat before;
    if (fstat(descriptor, &before) != 0 ||
        !PXBackupDirectoryStableFileStatMatches(expectedIdentity, &before) ||
        before.st_size < 0 ||
        (unsigned long long)before.st_size != expectedSize) return NO;
    off_t seekResult = (off_t)-1;
    do {
        seekResult = lseek(descriptor, 0, SEEK_SET);
    } while (seekResult < 0 && errno == EINTR);
    if (seekResult != 0) return NO;
    NSMutableData *mutableData = nil;
    @try {
        mutableData = [NSMutableData dataWithLength:(NSUInteger)expectedSize];
    } @catch (NSException *exception) {
        (void)exception;
        mutableData = nil;
    }
    if (!mutableData || mutableData.length != (NSUInteger)expectedSize) return NO;
    CC_SHA256_CTX context;
    if (CC_SHA256_Init(&context) != 1) return NO;
    unsigned long long offset = 0;
    unsigned char buffer[PXBackupDirectoryManifestReadBufferBytes];
    while (offset < expectedSize) {
        unsigned long long remaining = expectedSize - offset;
        size_t request = remaining > sizeof(buffer) ? sizeof(buffer) : (size_t)remaining;
        ssize_t count = -1;
        do {
            count = read(descriptor, buffer, request);
        } while (count < 0 && errno == EINTR);
        if (count <= 0 || (size_t)count > request ||
            offset > expectedSize - (unsigned long long)count) return NO;
        memcpy((unsigned char *)mutableData.mutableBytes + (NSUInteger)offset,
               buffer,
               (size_t)count);
        if (CC_SHA256_Update(&context, buffer, (CC_LONG)count) != 1) return NO;
        offset += (unsigned long long)count;
    }
    unsigned char extra = 0;
    ssize_t extraCount = -1;
    do {
        extraCount = read(descriptor, &extra, 1);
    } while (extraCount < 0 && errno == EINTR);
    if (extraCount != 0) return NO;
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    if (CC_SHA256_Final(digest, &context) != 1) return NO;
    NSString *digestString = PXBackupDirectoryHexDigest(digest, sizeof(digest));
    struct stat after;
    if (!digestString || fstat(descriptor, &after) != 0 ||
        !PXBackupDirectoryStableFileStatMatches(&before, &after)) return NO;
    NSData *immutableData = [mutableData copy];
    if (!immutableData || immutableData.length != mutableData.length) return NO;
    if (dataOut) *dataOut = immutableData;
    if (digestOut) *digestOut = digestString;
    if (stableIdentityOut) *stableIdentityOut = after;
    return YES;
}

static BOOL PXBackupDirectoryManifestMatches(
    NSDictionary *parsed,
    NSDictionary *expectedRepresentation,
    NSString *backupIdentifier,
    NSString *timestamp,
    NSUInteger artifactCount) {
    if (![parsed isKindOfClass:[NSDictionary class]] ||
        ![expectedRepresentation isKindOfClass:[NSDictionary class]] ||
        ![parsed isEqualToDictionary:expectedRepresentation]) return NO;
    NSNumber *version = parsed[@"manifestVersion"];
    NSString *parsedBackupIdentifier = parsed[@"backupID"];
    NSString *parsedTimestamp = parsed[@"timestamp"];
    NSDictionary *publication = parsed[@"publication"];
    NSString *protocol = [publication isKindOfClass:[NSDictionary class]]
        ? publication[@"protocol"] : nil;
    NSString *contentState = [publication isKindOfClass:[NSDictionary class]]
        ? publication[@"contentState"] : nil;
    NSString *checksum = parsed[@"archiveChecksum"];
    NSString *expectedChecksum = expectedRepresentation[@"archiveChecksum"];
    unsigned long long versionValue = 0;
    unsigned long long countValue = 0;
    unsigned long long totalValue = 0;
    unsigned long long expectedTotalValue = 0;
    if (!PXBackupDirectoryReadUnsignedIntegral(version, &versionValue) ||
        versionValue != 4ULL ||
        ![parsedBackupIdentifier isKindOfClass:[NSString class]] ||
        ![parsedBackupIdentifier isEqualToString:backupIdentifier] ||
        ![parsedTimestamp isKindOfClass:[NSString class]] ||
        ![parsedTimestamp isEqualToString:timestamp] ||
        ![protocol isKindOfClass:[NSString class]] ||
        ![protocol isEqualToString:@"atomic-directory-v1"] ||
        ![contentState isKindOfClass:[NSString class]] ||
        ![contentState isEqualToString:@"complete"] ||
        ![checksum isKindOfClass:[NSString class]] ||
        ![expectedChecksum isKindOfClass:[NSString class]] ||
        ![checksum isEqualToString:expectedChecksum] ||
        !PXBackupDirectoryReadUnsignedIntegral(parsed[@"artifactCount"],
                                               &countValue) ||
        countValue != (unsigned long long)artifactCount ||
        !PXBackupDirectoryReadUnsignedIntegral(parsed[@"totalSize"],
                                               &totalValue) ||
        !PXBackupDirectoryReadUnsignedIntegral(expectedRepresentation[@"totalSize"],
                                               &expectedTotalValue) ||
        totalValue != expectedTotalValue) return NO;
    return YES;
}

@interface PXBackupDirectoryPublisher ()

- (instancetype)initWithWorkspace:(PXBackupPublicationWorkspace *)workspace
                        bundleLock:(PXBackupBundleLock *)bundleLock
                   workspacePath:(NSString *)workspacePath
                     workspaceName:(NSString *)workspaceName
                       parentPath:(NSString *)parentPath
             publishedDirectoryPath:(NSString *)publishedDirectoryPath
             publishedDirectoryName:(NSString *)publishedDirectoryName
               publishedManifestPath:(NSString *)publishedManifestPath
                  backupIdentifier:(NSString *)backupIdentifier
                         timestamp:(NSString *)timestamp
                  parentDescriptor:(int)parentDescriptor
               workspaceDescriptor:(int)workspaceDescriptor
                    parentIdentity:(const struct stat *)parentIdentity
                 workspaceIdentity:(const struct stat *)workspaceIdentity;

@end

@implementation PXBackupDirectoryPublisher {
    PXBackupPublicationWorkspace *_workspace;
    PXBackupBundleLock *_bundleLock;
    NSString *_workspacePath;
    NSString *_workspaceName;
    NSString *_parentPath;
    NSString *_publishedDirectoryPath;
    NSString *_publishedDirectoryName;
    NSString *_publishedManifestPath;
    NSString *_backupIdentifier;
    NSString *_timestamp;
    BOOL _published;
    BOOL _publishAttempted;
    int _parentDescriptor;
    int _workspaceDescriptor;
    int _finalDirectoryDescriptor;
    int _finalManifestDescriptor;
    struct stat _parentIdentity;
    struct stat _workspaceIdentity;
    struct stat _finalDirectoryIdentity;
    struct stat _finalManifestIdentity;
    unsigned long long _acceptedManifestSize;
    NSString *_acceptedManifestSHA256;
    NSDictionary<NSString *, id> *_acceptedManifestRepresentation;
    NSUInteger _acceptedArtifactCount;
}

+ (nullable instancetype)
    publisherForWorkspace:(PXBackupPublicationWorkspace *)workspace
               bundleLock:(PXBackupBundleLock *)bundleLock
         backupIdentifier:(NSString *)backupIdentifier
                timestamp:(NSString *)timestamp
                    error:(NSError **)error {
    if (error) *error = nil;
    if (![workspace isMemberOfClass:[PXBackupPublicationWorkspace class]] ||
        ![bundleLock isMemberOfClass:[PXBackupBundleLock class]]) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorInvalidInput,
                                  PXBackupDirectoryPublisherField,
                                  @"The directory publication inputs are invalid");
        return nil;
    }
    if (![workspace.bundleIdentifier isEqualToString:bundleLock.bundleIdentifier] ||
        ![workspace.canonicalBundleDirectoryPath
            isEqualToString:bundleLock.canonicalBundleDirectoryPath] ||
        ![workspace.workspaceName hasPrefix:PXBackupPublicationPartialDirectoryPrefix]) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorInvalidInput,
                                  PXBackupDirectoryPublisherField,
                                  @"The directory publication identity is invalid");
        return nil;
    }
    if (!PXBackupDirectoryValidateTimestamp(timestamp) ||
        !PXBackupDirectoryValidateBackupIdentifier(backupIdentifier)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorInvalidFinalName,
                                  PXBackupDirectoryPublisherFinalField,
                                  @"The final backup directory identity is invalid");
        return nil;
    }
    NSError *lockError = nil;
    if (![bundleLock validateOwnershipWithError:&lockError]) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorLockValidationFailed,
                                  PXBackupDirectoryPublisherLockField,
                                  @"The backup lock failed validation");
        return nil;
    }
    NSError *workspaceError = nil;
    if (![workspace validateIdentityWithError:&workspaceError]) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorWorkspaceValidationFailed,
                                  PXBackupDirectoryPublisherWorkspaceField,
                                  @"The backup workspace failed validation");
        return nil;
    }
    NSString *parentPath = bundleLock.canonicalBundleDirectoryPath;
    NSString *workspacePath = workspace.workspacePath;
    NSString *expectedWorkspacePath =
        [parentPath stringByAppendingPathComponent:workspace.workspaceName];
    NSString *publishedDirectoryName =
        [NSString stringWithFormat:@"%@-%@", timestamp, backupIdentifier];
    NSString *publishedDirectoryPath =
        [parentPath stringByAppendingPathComponent:publishedDirectoryName];
    NSString *publishedManifestPath =
        [publishedDirectoryPath stringByAppendingPathComponent:PXBackupManifestFinalFileName];
    NSData *parentPathData = PXBackupDirectoryLosslessUTF8Data(
        parentPath,
        PXBackupDirectoryMaximumPathBytes,
        YES);
    NSData *workspaceNameData = nil;
    NSData *publishedNameData = nil;
    NSData *publishedPathData = PXBackupDirectoryLosslessUTF8Data(
        publishedDirectoryPath,
        PXBackupDirectoryMaximumPathBytes,
        YES);
    if (!parentPathData || !publishedPathData ||
        ![workspacePath isEqualToString:expectedWorkspacePath] ||
        !PXBackupDirectoryValidateSafeComponent(workspace.workspaceName,
                                                &workspaceNameData) ||
        !PXBackupDirectoryValidateFinalName(publishedDirectoryName,
                                            &publishedNameData)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorInvalidFinalName,
                                  PXBackupDirectoryPublisherFinalField,
                                  @"The final backup directory name is invalid");
        return nil;
    }
    char *parentPathBytes = PXBackupDirectoryCopyCString(parentPathData);
    char *workspaceNameBytes = PXBackupDirectoryCopyCString(workspaceNameData);
    char *publishedNameBytes = PXBackupDirectoryCopyCString(publishedNameData);
    int parentDescriptor = -1;
    int workspaceDescriptor = -1;
    PXBackupDirectoryPublisher *publisher = nil;
    struct stat parentPathStat;
    struct stat parentDescriptorStat;
    struct stat workspacePathStat;
    struct stat workspaceNamespaceStat;
    struct stat workspaceDescriptorStat;
    if (!parentPathBytes || !workspaceNameBytes || !publishedNameBytes) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorInvalidFinalName,
                                  PXBackupDirectoryPublisherFinalField,
                                  @"The final backup path exceeds resource limits");
        goto cleanup;
    }
    if (lstat(parentPathBytes, &parentPathStat) != 0 ||
        S_ISLNK(parentPathStat.st_mode) ||
        !S_ISDIR(parentPathStat.st_mode) ||
        (parentPathStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorParentInspectionFailed,
                                  PXBackupDirectoryPublisherParentField,
                                  @"The backup parent directory is invalid");
        goto cleanup;
    }
    parentDescriptor = open(parentPathBytes,
                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (parentDescriptor < 0 ||
        fstat(parentDescriptor, &parentDescriptorStat) != 0 ||
        !S_ISDIR(parentDescriptorStat.st_mode) ||
        (parentDescriptorStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        !PXBackupDirectoryStatIdentityMatches(&parentPathStat,
                                              &parentDescriptorStat) ||
        !PXBackupDirectoryDescriptorHasCloseOnExec(parentDescriptor)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorParentInspectionFailed,
                                  PXBackupDirectoryPublisherParentField,
                                  @"The backup parent descriptor is invalid");
        goto cleanup;
    }
    if (fstatat(parentDescriptor,
                workspaceNameBytes,
                &workspaceNamespaceStat,
                AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(workspaceNamespaceStat.st_mode) ||
        (workspaceNamespaceStat.st_mode & 07777) != 0700 ||
        (workspaceNamespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        workspaceNamespaceStat.st_dev != parentDescriptorStat.st_dev) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorWorkspaceInspectionFailed,
                                  PXBackupDirectoryPublisherWorkspaceField,
                                  @"The backup workspace namespace is invalid");
        goto cleanup;
    }
    workspaceDescriptor = openat(parentDescriptor,
                                 workspaceNameBytes,
                                 O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (workspaceDescriptor < 0 ||
        fstat(workspaceDescriptor, &workspaceDescriptorStat) != 0 ||
        !S_ISDIR(workspaceDescriptorStat.st_mode) ||
        (workspaceDescriptorStat.st_mode & 07777) != 0700 ||
        workspaceDescriptorStat.st_dev != parentDescriptorStat.st_dev ||
        !PXBackupDirectoryStatIdentityMatches(&workspaceNamespaceStat,
                                              &workspaceDescriptorStat) ||
        !PXBackupDirectoryDescriptorHasCloseOnExec(workspaceDescriptor) ||
        !PXBackupDirectoryPathMatchesDescriptor(workspacePath,
                                                workspaceDescriptor,
                                                &workspaceDescriptorStat,
                                                YES,
                                                &workspacePathStat)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorWorkspaceInspectionFailed,
                                  PXBackupDirectoryPublisherWorkspaceField,
                                  @"The backup workspace descriptor is invalid");
        goto cleanup;
    }
    workspaceError = nil;
    if (![workspace validateIdentityWithError:&workspaceError]) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorWorkspaceValidationFailed,
                                  PXBackupDirectoryPublisherWorkspaceField,
                                  @"The backup workspace identity changed");
        goto cleanup;
    }
    if (!PXBackupDirectoryEntryIsAbsent(parentDescriptor, publishedNameBytes)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorFinalDirectoryAlreadyExists,
                                  PXBackupDirectoryPublisherFinalField,
                                  @"The final backup directory already exists");
        goto cleanup;
    }
    publisher = [[PXBackupDirectoryPublisher alloc]
        initWithWorkspace:workspace
               bundleLock:bundleLock
            workspacePath:workspacePath
            workspaceName:workspace.workspaceName
              parentPath:parentPath
  publishedDirectoryPath:publishedDirectoryPath
  publishedDirectoryName:publishedDirectoryName
    publishedManifestPath:publishedManifestPath
         backupIdentifier:backupIdentifier
                timestamp:timestamp
         parentDescriptor:parentDescriptor
      workspaceDescriptor:workspaceDescriptor
           parentIdentity:&parentDescriptorStat
        workspaceIdentity:&workspaceDescriptorStat];
    if (!publisher) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorWorkspaceInspectionFailed,
                                  PXBackupDirectoryPublisherWorkspaceField,
                                  @"The directory publisher could not retain its authority");
        goto cleanup;
    }
    parentDescriptor = -1;
    workspaceDescriptor = -1;

cleanup:
    free(parentPathBytes);
    free(workspaceNameBytes);
    free(publishedNameBytes);
    if (workspaceDescriptor >= 0) close(workspaceDescriptor);
    if (parentDescriptor >= 0) close(parentDescriptor);
    return publisher;
}

- (instancetype)initWithWorkspace:(PXBackupPublicationWorkspace *)workspace
                        bundleLock:(PXBackupBundleLock *)bundleLock
                     workspacePath:(NSString *)workspacePath
                     workspaceName:(NSString *)workspaceName
                        parentPath:(NSString *)parentPath
          publishedDirectoryPath:(NSString *)publishedDirectoryPath
          publishedDirectoryName:(NSString *)publishedDirectoryName
            publishedManifestPath:(NSString *)publishedManifestPath
               backupIdentifier:(NSString *)backupIdentifier
                      timestamp:(NSString *)timestamp
               parentDescriptor:(int)parentDescriptor
            workspaceDescriptor:(int)workspaceDescriptor
                 parentIdentity:(const struct stat *)parentIdentity
              workspaceIdentity:(const struct stat *)workspaceIdentity {
    self = [super init];
    if (self) {
        _workspace = workspace;
        _bundleLock = bundleLock;
        _workspacePath = [workspacePath copy];
        _workspaceName = [workspaceName copy];
        _parentPath = [parentPath copy];
        _publishedDirectoryPath = [publishedDirectoryPath copy];
        _publishedDirectoryName = [publishedDirectoryName copy];
        _publishedManifestPath = [publishedManifestPath copy];
        _backupIdentifier = [backupIdentifier copy];
        _timestamp = [timestamp copy];
        _parentDescriptor = parentDescriptor;
        _workspaceDescriptor = workspaceDescriptor;
        _finalDirectoryDescriptor = -1;
        _finalManifestDescriptor = -1;
        if (parentIdentity) _parentIdentity = *parentIdentity;
        if (workspaceIdentity) _workspaceIdentity = *workspaceIdentity;
    }
    return self;
}

- (NSString *)workspacePath { return _workspacePath; }
- (NSString *)publishedDirectoryPath { return _publishedDirectoryPath; }
- (NSString *)publishedDirectoryName { return _publishedDirectoryName; }
- (NSString *)publishedManifestPath { return _publishedManifestPath; }
- (NSString *)backupIdentifier { return _backupIdentifier; }
- (NSString *)timestamp { return _timestamp; }
- (BOOL)isPublished { return _published; }

- (BOOL)validateIdentityWithError:(NSError **)error {
    if (error) *error = nil;
    NSError *lockError = nil;
    if (![_bundleLock validateOwnershipWithError:&lockError]) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorLockValidationFailed,
                                  PXBackupDirectoryPublisherLockField,
                                  @"The retained backup lock is invalid");
        return NO;
    }
    if (!PXBackupDirectoryPathMatchesDescriptor(_parentPath,
                                                _parentDescriptor,
                                                &_parentIdentity,
                                                NO,
                                                NULL)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorFilesystemChanged,
                                  PXBackupDirectoryPublisherParentField,
                                  @"The retained parent directory identity changed");
        return NO;
    }
    NSData *workspaceNameData = nil;
    NSData *publishedNameData = nil;
    if (!PXBackupDirectoryValidateSafeComponent(_workspaceName,
                                                &workspaceNameData) ||
        !PXBackupDirectoryValidateFinalName(_publishedDirectoryName,
                                            &publishedNameData)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorFilesystemChanged,
                                  PXBackupDirectoryPublisherField,
                                  @"The retained publication names are inconsistent");
        return NO;
    }
    char *workspaceNameBytes = PXBackupDirectoryCopyCString(workspaceNameData);
    char *publishedNameBytes = PXBackupDirectoryCopyCString(publishedNameData);
    NSData *manifestData = nil;
    NSString *manifestDigest = nil;
    NSDictionary *parsed = nil;
    NSError *validationError = nil;
    BOOL valid = NO;
    if (!workspaceNameBytes || !publishedNameBytes) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorFilesystemChanged,
                                  PXBackupDirectoryPublisherField,
                                  @"The retained publication names exceed limits");
        goto cleanup;
    }
    if (!_published) {
        NSError *workspaceError = nil;
        if (_finalDirectoryDescriptor >= 0 || _finalManifestDescriptor >= 0 ||
            _acceptedManifestSize != 0 || _acceptedManifestSHA256 != nil ||
            _acceptedManifestRepresentation != nil ||
            ![_workspace validateIdentityWithError:&workspaceError] ||
            !PXBackupDirectoryDirectoryBindingValid(_parentDescriptor,
                                                     workspaceNameBytes,
                                                     _workspaceDescriptor,
                                                     &_workspaceIdentity,
                                                     _parentIdentity.st_dev,
                                                     NULL) ||
            !PXBackupDirectoryPathMatchesDescriptor(_workspacePath,
                                                    _workspaceDescriptor,
                                                    &_workspaceIdentity,
                                                    YES,
                                                    NULL) ||
            !PXBackupDirectoryEntryIsAbsent(_parentDescriptor,
                                            publishedNameBytes)) {
            PXBackupDirectorySetError(error,
                                      PXBackupDirectoryPublisherErrorFilesystemChanged,
                                      PXBackupDirectoryPublisherWorkspaceField,
                                      @"The unpublished workspace identity changed");
            goto cleanup;
        }
        valid = YES;
        goto cleanup;
    }
    if (_finalDirectoryDescriptor < 0 || _finalManifestDescriptor < 0 ||
        _acceptedManifestSize == 0 ||
        !PXBackupDirectoryDigestIsLowercaseSHA256(_acceptedManifestSHA256) ||
        ![_acceptedManifestRepresentation isKindOfClass:[NSDictionary class]] ||
        [_acceptedManifestRepresentation isKindOfClass:[NSMutableDictionary class]] ||
        !PXBackupDirectoryEntryIsAbsent(_parentDescriptor, workspaceNameBytes) ||
        !PXBackupDirectoryDirectoryBindingValid(_parentDescriptor,
                                                 publishedNameBytes,
                                                 _finalDirectoryDescriptor,
                                                 &_finalDirectoryIdentity,
                                                 _parentIdentity.st_dev,
                                                 NULL) ||
        !PXBackupDirectoryStatIdentityMatches(&_workspaceIdentity,
                                              &_finalDirectoryIdentity) ||
        ![_publishedDirectoryPath isEqualToString:
            [_parentPath stringByAppendingPathComponent:_publishedDirectoryName]] ||
        ![_publishedManifestPath isEqualToString:
            [_publishedDirectoryPath stringByAppendingPathComponent:
                PXBackupManifestFinalFileName]]) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorFilesystemChanged,
                                  PXBackupDirectoryPublisherFinalField,
                                  @"The published directory identity changed");
        goto cleanup;
    }
    struct stat finalManifestStat;
    if (!PXBackupDirectoryManifestBindingValid(_finalDirectoryDescriptor,
                                               _finalManifestDescriptor,
                                               &_finalManifestIdentity,
                                               _acceptedManifestSize,
                                               &finalManifestStat)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorFilesystemChanged,
                                  PXBackupDirectoryPublisherManifestField,
                                  @"The published manifest identity changed");
        goto cleanup;
    }
    struct stat stableManifestIdentity;
    if (!PXBackupDirectoryReadManifestDescriptor(_finalManifestDescriptor,
                                                 &finalManifestStat,
                                                 _acceptedManifestSize,
                                                 &manifestData,
                                                 &manifestDigest,
                                                 &stableManifestIdentity) ||
        ![manifestDigest isEqualToString:_acceptedManifestSHA256]) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorManifestReadBackFailed,
                                  PXBackupDirectoryPublisherManifestField,
                                  @"The published manifest content changed");
        goto cleanup;
    }
    parsed = PXBackupDirectoryParseManifestData(manifestData);
    validationError = nil;
    if (!parsed ||
        ![PXBackupManifestValidator validateManifestObject:parsed
                                                     error:&validationError]) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorManifestValidationFailed,
                                  PXBackupDirectoryPublisherManifestField,
                                  @"The published manifest failed validation");
        goto cleanup;
    }
    if (!PXBackupDirectoryManifestMatches(parsed,
                                          _acceptedManifestRepresentation,
                                          _backupIdentifier,
                                          _timestamp,
                                          _acceptedArtifactCount)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorSnapshotMismatch,
                                  PXBackupDirectoryPublisherSnapshotField,
                                  @"The published manifest no longer matches its accepted snapshot");
        goto cleanup;
    }
    valid = YES;

cleanup:
    free(workspaceNameBytes);
    free(publishedNameBytes);
    return valid;
}

- (BOOL)publishWithArtifactWriter:(PXBackupArtifactWriter *)artifactWriter
                   manifestWriter:(PXBackupManifestWriter *)manifestWriter
                            error:(NSError **)error {
    if (error) *error = nil;
    if (_publishAttempted || _published) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorInvalidInput,
                                  PXBackupDirectoryPublisherField,
                                  @"The directory publisher has already been used");
        return NO;
    }
    _publishAttempted = YES;
    if (![artifactWriter isMemberOfClass:[PXBackupArtifactWriter class]] ||
        ![manifestWriter isMemberOfClass:[PXBackupManifestWriter class]]) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorInvalidInput,
                                  PXBackupDirectoryPublisherField,
                                  @"The directory publication writers are invalid");
        return NO;
    }
    NSData *workspaceNameData = nil;
    NSData *publishedNameData = nil;
    char *workspaceNameBytes = NULL;
    char *publishedNameBytes = NULL;
    BOOL forwardRenamed = NO;
    BOOL accepted = NO;
    int finalDirectoryDescriptor = -1;
    int finalManifestDescriptor = -1;
    int forwardRenameErrno = 0;
    int rollbackRenameErrno = 0;
    NSError *originalError = nil;
    NSError *identityError = nil;
    NSError *lockError = nil;
    NSError *workspaceError = nil;
    NSError *artifactError = nil;
    NSError *manifestWriterError = nil;
    NSDictionary *manifestRepresentation = nil;
    NSString *manifestDigest = nil;
    NSData *manifestData = nil;
    NSDictionary *parsedManifest = nil;
    NSError *validationError = nil;
    struct stat finalNamespaceIdentity;
    struct stat finalDirectoryIdentity;
    struct stat finalManifestIdentity;
    struct stat stableManifestIdentity;
    memset(&finalNamespaceIdentity, 0, sizeof(finalNamespaceIdentity));
    memset(&finalDirectoryIdentity, 0, sizeof(finalDirectoryIdentity));
    memset(&finalManifestIdentity, 0, sizeof(finalManifestIdentity));
    memset(&stableManifestIdentity, 0, sizeof(stableManifestIdentity));

    if (!PXBackupDirectoryValidateSafeComponent(_workspaceName,
                                                &workspaceNameData) ||
        !PXBackupDirectoryValidateFinalName(_publishedDirectoryName,
                                            &publishedNameData)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorInvalidFinalName,
                                  PXBackupDirectoryPublisherFinalField,
                                  @"The retained final directory name is invalid");
        goto cleanup;
    }
    workspaceNameBytes = PXBackupDirectoryCopyCString(workspaceNameData);
    publishedNameBytes = PXBackupDirectoryCopyCString(publishedNameData);
    if (!workspaceNameBytes || !publishedNameBytes) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorInvalidFinalName,
                                  PXBackupDirectoryPublisherFinalField,
                                  @"The retained final directory name exceeds limits");
        goto cleanup;
    }
    identityError = nil;
    if (![self validateIdentityWithError:&identityError]) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorFilesystemChanged,
                                  PXBackupDirectoryPublisherWorkspaceField,
                                  @"The directory publisher identity is invalid");
        goto cleanup;
    }
    lockError = nil;
    if (![_bundleLock validateOwnershipWithError:&lockError]) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorLockValidationFailed,
                                  PXBackupDirectoryPublisherLockField,
                                  @"The backup lock failed pre-publication validation");
        goto cleanup;
    }
    workspaceError = nil;
    if (![_workspace validateIdentityWithError:&workspaceError] ||
        !PXBackupDirectoryDirectoryBindingValid(_parentDescriptor,
                                                 workspaceNameBytes,
                                                 _workspaceDescriptor,
                                                 &_workspaceIdentity,
                                                 _parentIdentity.st_dev,
                                                 NULL)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorWorkspaceValidationFailed,
                                  PXBackupDirectoryPublisherWorkspaceField,
                                  @"The backup workspace failed pre-publication validation");
        goto cleanup;
    }
    artifactError = nil;
    if (![artifactWriter validateIdentityWithError:&artifactError] ||
        ![artifactWriter.workspacePath isEqualToString:_workspacePath]) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorArtifactWriterValidationFailed,
                                  PXBackupDirectoryPublisherWorkspaceField,
                                  @"The artifact writer failed publication validation");
        goto cleanup;
    }
    manifestWriterError = nil;
    if (![manifestWriter validateIdentityWithError:&manifestWriterError] ||
        ![manifestWriter.workspacePath isEqualToString:_workspacePath]) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorManifestWriterValidationFailed,
                                  PXBackupDirectoryPublisherManifestField,
                                  @"The manifest writer failed publication validation");
        goto cleanup;
    }
    manifestRepresentation = manifestWriter.manifestRepresentation;
    manifestDigest = manifestWriter.manifestSHA256;
    if (!manifestWriter.isManifestWritten || manifestWriter.manifestSize == 0 ||
        manifestWriter.manifestSize > PXBackupDirectoryMaximumManifestBytes ||
        !PXBackupDirectoryDigestIsLowercaseSHA256(manifestDigest) ||
        ![manifestRepresentation isKindOfClass:[NSDictionary class]] ||
        [manifestRepresentation isKindOfClass:[NSMutableDictionary class]] ||
        ![manifestWriter.manifestPath isEqualToString:
            [_workspacePath stringByAppendingPathComponent:
                PXBackupManifestFinalFileName]]) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorManifestNotReady,
                                  PXBackupDirectoryPublisherManifestField,
                                  @"The manifest is not ready for directory publication");
        goto cleanup;
    }
    validationError = nil;
    if (![PXBackupManifestValidator validateManifestObject:manifestRepresentation
                                                     error:&validationError]) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorManifestValidationFailed,
                                  PXBackupDirectoryPublisherManifestField,
                                  @"The accepted manifest failed publication validation");
        goto cleanup;
    }
    if (!PXBackupDirectoryManifestMatches(manifestRepresentation,
                                          manifestRepresentation,
                                          _backupIdentifier,
                                          _timestamp,
                                          artifactWriter.artifactCount)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorSnapshotMismatch,
                                  PXBackupDirectoryPublisherSnapshotField,
                                  @"The accepted manifest does not match publication identity");
        goto cleanup;
    }
    if (!PXBackupDirectoryEntryIsAbsent(_parentDescriptor, publishedNameBytes)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorFinalDirectoryAlreadyExists,
                                  PXBackupDirectoryPublisherFinalField,
                                  @"The final backup directory already exists");
        goto cleanup;
    }
    if (!PXBackupDirectoryScanManifestTemporaryEntries(_workspaceDescriptor)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorManifestNotReady,
                                  PXBackupDirectoryPublisherManifestField,
                                  @"The workspace contains a manifest temporary entry");
        goto cleanup;
    }
    if (!PXBackupDirectoryStrictSync(_workspaceDescriptor)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorDurabilityFailed,
                                  PXBackupDirectoryPublisherWorkspaceField,
                                  @"The backup workspace could not be synchronized");
        goto cleanup;
    }
    lockError = nil;
    if (![_bundleLock validateOwnershipWithError:&lockError] ||
        !PXBackupDirectoryPathMatchesDescriptor(_parentPath,
                                                _parentDescriptor,
                                                &_parentIdentity,
                                                NO,
                                                NULL) ||
        !PXBackupDirectoryDirectoryBindingValid(_parentDescriptor,
                                                 workspaceNameBytes,
                                                 _workspaceDescriptor,
                                                 &_workspaceIdentity,
                                                 _parentIdentity.st_dev,
                                                 NULL) ||
        !PXBackupDirectoryEntryIsAbsent(_parentDescriptor, publishedNameBytes)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorFilesystemChanged,
                                  PXBackupDirectoryPublisherFinalField,
                                  @"The publication filesystem identity changed before rename");
        goto cleanup;
    }
    if (!PXBackupDirectoryRenameEntryNoReplace(_parentDescriptor,
                                               workspaceNameBytes,
                                               _parentDescriptor,
                                               publishedNameBytes,
                                               &forwardRenameErrno)) {
        BOOL destinationCollision =
            forwardRenameErrno == EEXIST || forwardRenameErrno == ENOTEMPTY;
        PXBackupDirectorySetError(
            error,
            destinationCollision
                ? PXBackupDirectoryPublisherErrorFinalDirectoryAlreadyExists
                : PXBackupDirectoryPublisherErrorPublicationFailed,
            PXBackupDirectoryPublisherFinalField,
            destinationCollision
                ? @"The final backup directory already exists"
                : @"The backup directory could not be published atomically");
        goto cleanup;
    }
    forwardRenamed = YES;
    if (!PXBackupDirectoryEntryIsAbsent(_parentDescriptor, workspaceNameBytes) ||
        fstatat(_parentDescriptor,
                publishedNameBytes,
                &finalNamespaceIdentity,
                AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(finalNamespaceIdentity.st_mode) ||
        (finalNamespaceIdentity.st_mode & 07777) != 0700 ||
        !PXBackupDirectoryStatIdentityMatches(&_workspaceIdentity,
                                              &finalNamespaceIdentity)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorFinalDirectoryInspectionFailed,
                                  PXBackupDirectoryPublisherFinalField,
                                  @"The published directory namespace is invalid");
        goto rollback;
    }
    if (!PXBackupDirectoryStrictSync(_workspaceDescriptor) ||
        !PXBackupDirectoryStrictSync(_parentDescriptor)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorDurabilityFailed,
                                  PXBackupDirectoryPublisherFinalField,
                                  @"The published directory could not be synchronized");
        goto rollback;
    }
    finalDirectoryDescriptor = openat(_parentDescriptor,
                                      publishedNameBytes,
                                      O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (finalDirectoryDescriptor < 0 ||
        !PXBackupDirectoryDirectoryBindingValid(_parentDescriptor,
                                                 publishedNameBytes,
                                                 finalDirectoryDescriptor,
                                                 &_workspaceIdentity,
                                                 _parentIdentity.st_dev,
                                                 &finalDirectoryIdentity)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorFinalDirectoryInspectionFailed,
                                  PXBackupDirectoryPublisherFinalField,
                                  @"The published directory descriptor is invalid");
        goto rollback;
    }
    finalManifestDescriptor = openat(finalDirectoryDescriptor,
                                     PXBackupDirectoryManifestFileNameBytes,
                                     O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
    if (finalManifestDescriptor < 0 ||
        fstat(finalManifestDescriptor, &finalManifestIdentity) != 0 ||
        !S_ISREG(finalManifestIdentity.st_mode) ||
        finalManifestIdentity.st_nlink != 1 ||
        (finalManifestIdentity.st_mode & 07777) != 0600 ||
        finalManifestIdentity.st_dev != finalDirectoryIdentity.st_dev ||
        finalManifestIdentity.st_size < 0 ||
        (unsigned long long)finalManifestIdentity.st_size !=
            manifestWriter.manifestSize ||
        !PXBackupDirectoryDescriptorHasCloseOnExec(finalManifestDescriptor) ||
        !PXBackupDirectoryManifestBindingValid(finalDirectoryDescriptor,
                                               finalManifestDescriptor,
                                               &finalManifestIdentity,
                                               manifestWriter.manifestSize,
                                               NULL)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorFinalDirectoryInspectionFailed,
                                  PXBackupDirectoryPublisherManifestField,
                                  @"The published manifest descriptor is invalid");
        goto rollback;
    }
    if (!PXBackupDirectoryReadManifestDescriptor(finalManifestDescriptor,
                                                 &finalManifestIdentity,
                                                 manifestWriter.manifestSize,
                                                 &manifestData,
                                                 &manifestDigest,
                                                 &stableManifestIdentity) ||
        ![manifestDigest isEqualToString:manifestWriter.manifestSHA256]) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorManifestReadBackFailed,
                                  PXBackupDirectoryPublisherManifestField,
                                  @"The published manifest could not be read back exactly");
        goto rollback;
    }
    parsedManifest = PXBackupDirectoryParseManifestData(manifestData);
    validationError = nil;
    if (!parsedManifest ||
        ![PXBackupManifestValidator validateManifestObject:parsedManifest
                                                     error:&validationError]) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorManifestValidationFailed,
                                  PXBackupDirectoryPublisherManifestField,
                                  @"The published manifest failed validation");
        goto rollback;
    }
    if (!PXBackupDirectoryManifestMatches(parsedManifest,
                                          manifestWriter.manifestRepresentation,
                                          _backupIdentifier,
                                          _timestamp,
                                          artifactWriter.artifactCount)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorSnapshotMismatch,
                                  PXBackupDirectoryPublisherSnapshotField,
                                  @"The published manifest does not match its accepted snapshot");
        goto rollback;
    }
    if (!PXBackupDirectoryPathMatchesDescriptor(_parentPath,
                                                _parentDescriptor,
                                                &_parentIdentity,
                                                NO,
                                                NULL) ||
        !PXBackupDirectoryEntryIsAbsent(_parentDescriptor, workspaceNameBytes) ||
        !PXBackupDirectoryDirectoryBindingValid(_parentDescriptor,
                                                 publishedNameBytes,
                                                 finalDirectoryDescriptor,
                                                 &finalDirectoryIdentity,
                                                 _parentIdentity.st_dev,
                                                 NULL) ||
        !PXBackupDirectoryManifestBindingValid(finalDirectoryDescriptor,
                                               finalManifestDescriptor,
                                               &stableManifestIdentity,
                                               manifestWriter.manifestSize,
                                               NULL)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorFilesystemChanged,
                                  PXBackupDirectoryPublisherFinalField,
                                  @"The published backup identity changed before acceptance");
        goto rollback;
    }
    _finalDirectoryDescriptor = finalDirectoryDescriptor;
    finalDirectoryDescriptor = -1;
    _finalManifestDescriptor = finalManifestDescriptor;
    finalManifestDescriptor = -1;
    _finalDirectoryIdentity = finalDirectoryIdentity;
    _finalManifestIdentity = stableManifestIdentity;
    _acceptedManifestSize = manifestWriter.manifestSize;
    _acceptedManifestSHA256 = [manifestWriter.manifestSHA256 copy];
    _acceptedManifestRepresentation =
        [manifestWriter.manifestRepresentation copy];
    _acceptedArtifactCount = artifactWriter.artifactCount;
    _published = YES;
    accepted = YES;
    if (error) *error = nil;
    goto cleanup;

rollback:
    originalError = error ? *error : nil;
    if (finalManifestDescriptor >= 0) {
        close(finalManifestDescriptor);
        finalManifestDescriptor = -1;
    }
    if (finalDirectoryDescriptor >= 0) {
        close(finalDirectoryDescriptor);
        finalDirectoryDescriptor = -1;
    }
    if (!PXBackupDirectoryPathMatchesDescriptor(_parentPath,
                                                _parentDescriptor,
                                                &_parentIdentity,
                                                NO,
                                                NULL) ||
        !PXBackupDirectoryEntryIsAbsent(_parentDescriptor, workspaceNameBytes) ||
        !PXBackupDirectoryDirectoryBindingValid(_parentDescriptor,
                                                 publishedNameBytes,
                                                 _workspaceDescriptor,
                                                 &_workspaceIdentity,
                                                 _parentIdentity.st_dev,
                                                 NULL) ||
        !PXBackupDirectoryRenameEntryNoReplace(_parentDescriptor,
                                               publishedNameBytes,
                                               _parentDescriptor,
                                               workspaceNameBytes,
                                               &rollbackRenameErrno) ||
        !PXBackupDirectoryStrictSync(_parentDescriptor) ||
        !PXBackupDirectoryEntryIsAbsent(_parentDescriptor, publishedNameBytes) ||
        !PXBackupDirectoryDirectoryBindingValid(_parentDescriptor,
                                                 workspaceNameBytes,
                                                 _workspaceDescriptor,
                                                 &_workspaceIdentity,
                                                 _parentIdentity.st_dev,
                                                 NULL)) {
        PXBackupDirectorySetError(error,
                                  PXBackupDirectoryPublisherErrorRollbackFailed,
                                  PXBackupDirectoryPublisherFinalField,
                                  @"The failed directory publication could not be rolled back safely");
        goto cleanup;
    }
    forwardRenamed = NO;
    if (error) *error = originalError;

cleanup:
    if (finalManifestDescriptor >= 0) close(finalManifestDescriptor);
    if (finalDirectoryDescriptor >= 0) close(finalDirectoryDescriptor);
    free(workspaceNameBytes);
    free(publishedNameBytes);
    (void)forwardRenamed;
    return accepted;
}

- (void)dealloc {
    if (_finalManifestDescriptor >= 0) close(_finalManifestDescriptor);
    if (_finalDirectoryDescriptor >= 0) close(_finalDirectoryDescriptor);
    if (_workspaceDescriptor >= 0) close(_workspaceDescriptor);
    if (_parentDescriptor >= 0) close(_parentDescriptor);
}

@end
