#import "PXBackupManifestWriter.h"
#import "PXBackupPublicationWorkspace.h"
#import "PXBackupManifestV4.h"
#import "PXBackupManifestValidator.h"

#import <CommonCrypto/CommonDigest.h>

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

NSErrorDomain const PXBackupManifestWriterErrorDomain =
    @"com.hydra.projectx.backup-manifest-writer";
NSString * const PXBackupManifestWriterErrorFieldPathKey = @"fieldPath";
NSString * const PXBackupManifestFinalFileName = @"manifest.plist";
NSString * const PXBackupManifestTemporaryFilePrefix =
    @".weaponx-manifest-partial-";

static NSString * const PXBackupManifestWorkspaceField = @"$.workspace";
static NSString * const PXBackupManifestField = @"$.manifest";
static NSString * const PXBackupManifestTemporaryField = @"$.manifest.temporary";
static NSString * const PXBackupManifestSnapshotField = @"$.manifest.snapshot";

static const unsigned long long PXBackupManifestMaximumSerializedBytes =
    128ULL * 1024ULL * 1024ULL;
static const size_t PXBackupManifestReadBufferBytes = 64U * 1024U;
static const size_t PXBackupManifestRandomSuffixBytes = 16U;
static const NSUInteger PXBackupManifestTemporaryCreationAttempts = 16U;
static const NSUInteger PXBackupManifestMaximumOwnedTemporaryEntries = 1U;
static const NSUInteger PXBackupManifestMaximumCleanupEntries = 2U;
static const NSUInteger PXBackupManifestMaximumPathBytes = 4096U;
static const char PXBackupManifestFinalFileNameBytes[] = "manifest.plist";
static const char PXBackupManifestTemporaryFilePrefixBytes[] =
    ".weaponx-manifest-partial-";

#if defined(__APPLE__)
#define PX_BACKUP_MANIFEST_MTIME_SEC(value) ((value).st_mtimespec.tv_sec)
#define PX_BACKUP_MANIFEST_MTIME_NSEC(value) ((value).st_mtimespec.tv_nsec)
#define PX_BACKUP_MANIFEST_CTIME_SEC(value) ((value).st_ctimespec.tv_sec)
#define PX_BACKUP_MANIFEST_CTIME_NSEC(value) ((value).st_ctimespec.tv_nsec)
#else
#define PX_BACKUP_MANIFEST_MTIME_SEC(value) ((value).st_mtim.tv_sec)
#define PX_BACKUP_MANIFEST_MTIME_NSEC(value) ((value).st_mtim.tv_nsec)
#define PX_BACKUP_MANIFEST_CTIME_SEC(value) ((value).st_ctim.tv_sec)
#define PX_BACKUP_MANIFEST_CTIME_NSEC(value) ((value).st_ctim.tv_nsec)
#endif

static void PXBackupManifestSetError(NSError **error,
                                     PXBackupManifestWriterErrorCode code,
                                     NSString *fieldPath,
                                     NSString *description) {
    if (!error) return;
    *error = [NSError errorWithDomain:PXBackupManifestWriterErrorDomain
                                 code:code
                             userInfo:@{
                                 NSLocalizedDescriptionKey: description,
                                 PXBackupManifestWriterErrorFieldPathKey: fieldPath,
                             }];
}

static BOOL PXBackupManifestStatIdentityMatches(const struct stat *left,
                                                 const struct stat *right) {
    return left && right &&
           left->st_dev == right->st_dev &&
           left->st_ino == right->st_ino &&
           ((left->st_mode & S_IFMT) == (right->st_mode & S_IFMT));
}

static BOOL PXBackupManifestStableFileStatMatches(const struct stat *left,
                                                   const struct stat *right) {
    return PXBackupManifestStatIdentityMatches(left, right) &&
           (left->st_mode & 07777) == (right->st_mode & 07777) &&
           left->st_nlink == right->st_nlink &&
           left->st_size == right->st_size &&
           PX_BACKUP_MANIFEST_MTIME_SEC(*left) ==
               PX_BACKUP_MANIFEST_MTIME_SEC(*right) &&
           PX_BACKUP_MANIFEST_MTIME_NSEC(*left) ==
               PX_BACKUP_MANIFEST_MTIME_NSEC(*right) &&
           PX_BACKUP_MANIFEST_CTIME_SEC(*left) ==
               PX_BACKUP_MANIFEST_CTIME_SEC(*right) &&
           PX_BACKUP_MANIFEST_CTIME_NSEC(*left) ==
               PX_BACKUP_MANIFEST_CTIME_NSEC(*right);
}

static BOOL PXBackupManifestPublishedFileStatMatches(const struct stat *before,
                                                      const struct stat *after) {
    return PXBackupManifestStatIdentityMatches(before, after) &&
           (before->st_mode & 07777) == (after->st_mode & 07777) &&
           before->st_nlink == after->st_nlink &&
           before->st_size == after->st_size;
}

static BOOL PXBackupManifestDescriptorHasCloseOnExec(int descriptor) {
    if (descriptor < 0) return NO;
    int flags = -1;
    do {
        flags = fcntl(descriptor, F_GETFD);
    } while (flags < 0 && errno == EINTR);
    return flags >= 0 && (flags & FD_CLOEXEC) != 0;
}

static int PXBackupManifestDuplicateDescriptor(int descriptor) {
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
        !PXBackupManifestDescriptorHasCloseOnExec(duplicated)) {
        close(duplicated);
        return -1;
    }
    return duplicated;
}

static BOOL PXBackupManifestStrictSync(int descriptor) {
    if (descriptor < 0) return NO;
    int result = -1;
    do {
        result = fsync(descriptor);
    } while (result < 0 && errno == EINTR);
    return result == 0;
}

static BOOL PXBackupManifestStringContainsNUL(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return YES;
    for (NSUInteger index = 0; index < value.length; index++) {
        if ([value characterAtIndex:index] == 0) return YES;
    }
    return NO;
}

static NSData *PXBackupManifestLosslessUTF8Data(NSString *value) {
    if (![value isKindOfClass:[NSString class]] ||
        value.length == 0 ||
        PXBackupManifestStringContainsNUL(value)) return nil;
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding
                       allowLossyConversion:NO];
    if (!data || data.length == 0 || data.length > PXBackupManifestMaximumPathBytes) {
        return nil;
    }
    NSString *roundTrip = [[NSString alloc] initWithData:data
                                                encoding:NSUTF8StringEncoding];
    if (!roundTrip || ![roundTrip isEqualToString:value]) return nil;
    return data;
}

static char *PXBackupManifestCopyCString(NSData *data) {
    if (![data isKindOfClass:[NSData class]] || data.length == 0 ||
        data.length > SIZE_MAX - 1) return NULL;
    char *bytes = calloc(data.length + 1, 1);
    if (!bytes) return NULL;
    memcpy(bytes, data.bytes, data.length);
    return bytes;
}

static NSString *PXBackupManifestHexDigest(const unsigned char *digest,
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

static BOOL PXBackupManifestGenerateTemporaryName(char *buffer,
                                                   size_t bufferSize,
                                                   NSString **nameOut) {
    if (nameOut) *nameOut = nil;
    const size_t prefixLength = sizeof(PXBackupManifestTemporaryFilePrefixBytes) - 1;
    const size_t suffixCharacters = PXBackupManifestRandomSuffixBytes * 2;
    const size_t required = prefixLength + suffixCharacters + 1;
    if (!buffer || bufferSize < required) return NO;
    unsigned char randomBytes[PXBackupManifestRandomSuffixBytes];
    arc4random_buf(randomBytes, sizeof(randomBytes));
    static const char alphabet[] = "0123456789abcdef";
    memcpy(buffer, PXBackupManifestTemporaryFilePrefixBytes, prefixLength);
    for (size_t index = 0; index < sizeof(randomBytes); index++) {
        buffer[prefixLength + (index * 2)] =
            alphabet[(randomBytes[index] >> 4) & 0x0f];
        buffer[prefixLength + (index * 2) + 1] =
            alphabet[randomBytes[index] & 0x0f];
    }
    buffer[required - 1] = '\0';
    NSString *name = [[NSString alloc] initWithBytes:buffer
                                              length:required - 1
                                            encoding:NSASCIIStringEncoding];
    if (!name || ![name hasPrefix:PXBackupManifestTemporaryFilePrefix] ||
        name.length != PXBackupManifestTemporaryFilePrefix.length + 32) return NO;
    if (nameOut) *nameOut = name;
    return YES;
}

static BOOL PXBackupManifestScanTemporaryEntries(int workspaceDescriptor,
                                                  const char *allowedName,
                                                  NSUInteger *temporaryCountOut) {
    if (temporaryCountOut) *temporaryCountOut = 0;
    int duplicated = PXBackupManifestDuplicateDescriptor(workspaceDescriptor);
    if (duplicated < 0) return NO;
    DIR *directory = fdopendir(duplicated);
    if (!directory) {
        close(duplicated);
        return NO;
    }
    const size_t prefixLength = sizeof(PXBackupManifestTemporaryFilePrefixBytes) - 1;
    NSUInteger temporaryCount = 0;
    BOOL valid = YES;
    errno = 0;
    struct dirent *entry = NULL;
    while ((entry = readdir(directory)) != NULL) {
        if (strncmp(entry->d_name,
                    PXBackupManifestTemporaryFilePrefixBytes,
                    prefixLength) != 0) continue;
        if (temporaryCount == NSUIntegerMax) {
            valid = NO;
            break;
        }
        temporaryCount += 1;
        if (!allowedName || strcmp(entry->d_name, allowedName) != 0 ||
            temporaryCount > PXBackupManifestMaximumOwnedTemporaryEntries) {
            valid = NO;
            break;
        }
    }
    if (!entry && errno != 0) valid = NO;
    if (closedir(directory) != 0) valid = NO;
    if (temporaryCountOut) *temporaryCountOut = temporaryCount;
    return valid;
}

static BOOL PXBackupManifestWorkspacePathMatchesDescriptor(
    NSString *workspacePath,
    int descriptor,
    const struct stat *expected,
    struct stat *currentOut) {
    NSData *pathData = PXBackupManifestLosslessUTF8Data(workspacePath);
    char *pathBytes = PXBackupManifestCopyCString(pathData);
    if (!pathBytes) return NO;
    struct stat pathStat;
    struct stat descriptorStat;
    BOOL valid = lstat(pathBytes, &pathStat) == 0 &&
                 !S_ISLNK(pathStat.st_mode) &&
                 S_ISDIR(pathStat.st_mode) &&
                 (pathStat.st_mode & 07777) == 0700 &&
                 fstat(descriptor, &descriptorStat) == 0 &&
                 S_ISDIR(descriptorStat.st_mode) &&
                 (descriptorStat.st_mode & 07777) == 0700 &&
                 PXBackupManifestStatIdentityMatches(&pathStat, &descriptorStat) &&
                 (!expected ||
                  PXBackupManifestStatIdentityMatches(expected, &descriptorStat)) &&
                 PXBackupManifestDescriptorHasCloseOnExec(descriptor);
    free(pathBytes);
    if (valid && currentOut) *currentOut = descriptorStat;
    return valid;
}

static BOOL PXBackupManifestFinalNameIsAbsent(int workspaceDescriptor) {
    struct stat namespaceStat;
    if (fstatat(workspaceDescriptor,
                PXBackupManifestFinalFileNameBytes,
                &namespaceStat,
                AT_SYMLINK_NOFOLLOW) == 0) return NO;
    return errno == ENOENT;
}

static BOOL PXBackupManifestFileBindingValid(int workspaceDescriptor,
                                             const char *name,
                                             int descriptor,
                                             const struct stat *expected,
                                             unsigned long long expectedSize,
                                             BOOL requireStableMetadata,
                                             struct stat *currentOut) {
    if (workspaceDescriptor < 0 || !name || descriptor < 0 ||
        expectedSize > (unsigned long long)LLONG_MAX) return NO;
    struct stat namespaceStat;
    struct stat descriptorStat;
    if (fstatat(workspaceDescriptor,
                name,
                &namespaceStat,
                AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISREG(namespaceStat.st_mode) ||
        namespaceStat.st_nlink != 1 ||
        (namespaceStat.st_mode & 07777) != 0600 ||
        fstat(descriptor, &descriptorStat) != 0 ||
        !S_ISREG(descriptorStat.st_mode) ||
        descriptorStat.st_nlink != 1 ||
        (descriptorStat.st_mode & 07777) != 0600 ||
        descriptorStat.st_size < 0 ||
        (unsigned long long)descriptorStat.st_size != expectedSize ||
        namespaceStat.st_size != descriptorStat.st_size ||
        descriptorStat.st_dev != namespaceStat.st_dev ||
        !PXBackupManifestStatIdentityMatches(&namespaceStat, &descriptorStat) ||
        (expected &&
         !(requireStableMetadata
             ? PXBackupManifestStableFileStatMatches(expected, &descriptorStat)
             : PXBackupManifestStatIdentityMatches(expected, &descriptorStat))) ||
        !PXBackupManifestDescriptorHasCloseOnExec(descriptor)) return NO;
    if (currentOut) *currentOut = descriptorStat;
    return YES;
}

static BOOL PXBackupManifestReadUnsignedIntegral(id value,
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

static BOOL PXBackupManifestSnapshotMatches(
    NSDictionary *parsed,
    PXBackupManifestV4 *snapshot) {
    if (![parsed isKindOfClass:[NSDictionary class]] ||
        ![snapshot isMemberOfClass:[PXBackupManifestV4 class]] ||
        ![parsed isEqualToDictionary:snapshot.manifestRepresentation]) return NO;
    NSString *backupIdentifier = parsed[@"backupID"];
    NSString *checksum = parsed[@"archiveChecksum"];
    unsigned long long artifactCount = 0;
    unsigned long long totalSize = 0;
    if (![backupIdentifier isKindOfClass:[NSString class]] ||
        ![backupIdentifier isEqualToString:snapshot.backupIdentifier] ||
        ![checksum isKindOfClass:[NSString class]] ||
        ![checksum isEqualToString:snapshot.applicationDataChecksum] ||
        !PXBackupManifestReadUnsignedIntegral(parsed[@"artifactCount"],
                                              &artifactCount) ||
        artifactCount != (unsigned long long)snapshot.artifactCount ||
        !PXBackupManifestReadUnsignedIntegral(parsed[@"totalSize"],
                                              &totalSize) ||
        totalSize != snapshot.totalSize) return NO;
    return YES;
}

static NSDictionary *PXBackupManifestParseData(NSData *data) {
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

static NSData *PXBackupManifestSerializeSnapshot(PXBackupManifestV4 *snapshot) {
    if (![snapshot isMemberOfClass:[PXBackupManifestV4 class]]) return nil;
    NSData *data = nil;
    @try {
        data = [NSPropertyListSerialization
            dataWithPropertyList:snapshot.manifestRepresentation
                          format:NSPropertyListBinaryFormat_v1_0
                         options:0
                           error:NULL];
    } @catch (NSException *exception) {
        (void)exception;
        data = nil;
    }
    return [data isKindOfClass:[NSData class]] ? data : nil;
}

static BOOL PXBackupManifestReadDescriptor(int descriptor,
                                           const struct stat *expectedIdentity,
                                           unsigned long long expectedSize,
                                           NSData **dataOut,
                                           NSString **digestOut,
                                           struct stat *stableIdentityOut) {
    if (dataOut) *dataOut = nil;
    if (digestOut) *digestOut = nil;
    if (descriptor < 0 || !expectedIdentity ||
        expectedSize == 0 ||
        expectedSize > PXBackupManifestMaximumSerializedBytes ||
        expectedSize > NSUIntegerMax ||
        expectedSize > (unsigned long long)LLONG_MAX) return NO;
    struct stat before;
    if (fstat(descriptor, &before) != 0 ||
        !PXBackupManifestStableFileStatMatches(expectedIdentity, &before) ||
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
    unsigned char buffer[PXBackupManifestReadBufferBytes];
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
    NSString *digestString = PXBackupManifestHexDigest(digest,
                                                        sizeof(digest));
    struct stat after;
    if (!digestString || fstat(descriptor, &after) != 0 ||
        !PXBackupManifestStableFileStatMatches(&before, &after)) return NO;
    NSData *immutableData = [mutableData copy];
    if (!immutableData || immutableData.length != mutableData.length) return NO;
    if (dataOut) *dataOut = immutableData;
    if (digestOut) *digestOut = digestString;
    if (stableIdentityOut) *stableIdentityOut = after;
    return YES;
}

static BOOL PXBackupManifestFullWrite(int descriptor, NSData *data) {
    if (descriptor < 0 || ![data isKindOfClass:[NSData class]] ||
        data.length == 0 || data.length > PXBackupManifestMaximumSerializedBytes) {
        return NO;
    }
    const unsigned char *bytes = data.bytes;
    NSUInteger offset = 0;
    while (offset < data.length) {
        NSUInteger remaining = data.length - offset;
        ssize_t count = -1;
        do {
            count = write(descriptor, bytes + offset, remaining);
        } while (count < 0 && errno == EINTR);
        if (count <= 0 || (NSUInteger)count > remaining) return NO;
        offset += (NSUInteger)count;
    }
    return offset == data.length;
}

static BOOL PXBackupManifestRemoveExactFile(int workspaceDescriptor,
                                            const char *name,
                                            int descriptor,
                                            const struct stat *expected,
                                            NSUInteger *cleanupEntries) {
    if (!cleanupEntries || *cleanupEntries >= PXBackupManifestMaximumCleanupEntries ||
        workspaceDescriptor < 0 || !name || descriptor < 0 || !expected) return NO;
    struct stat namespaceStat;
    struct stat descriptorStat;
    if (fstatat(workspaceDescriptor,
                name,
                &namespaceStat,
                AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISREG(namespaceStat.st_mode) ||
        namespaceStat.st_nlink != 1 ||
        (namespaceStat.st_mode & 07777) != 0600 ||
        fstat(descriptor, &descriptorStat) != 0 ||
        !S_ISREG(descriptorStat.st_mode) ||
        descriptorStat.st_nlink != 1 ||
        (descriptorStat.st_mode & 07777) != 0600 ||
        !PXBackupManifestStatIdentityMatches(expected, &namespaceStat) ||
        !PXBackupManifestStatIdentityMatches(expected, &descriptorStat) ||
        !PXBackupManifestStatIdentityMatches(&namespaceStat, &descriptorStat)) return NO;
    if (unlinkat(workspaceDescriptor, name, 0) != 0) return NO;
    *cleanupEntries += 1;
    return PXBackupManifestStrictSync(workspaceDescriptor);
}

@interface PXBackupManifestWriter ()

- (instancetype)initWithWorkspace:(PXBackupPublicationWorkspace *)workspace
                    workspacePath:(NSString *)workspacePath
              workspaceDescriptor:(int)workspaceDescriptor
                workspaceIdentity:(const struct stat *)workspaceIdentity;

@end

@implementation PXBackupManifestWriter {
    PXBackupPublicationWorkspace *_workspace;
    NSString *_workspacePath;
    NSString *_manifestPath;
    BOOL _manifestWritten;
    BOOL _writeAttempted;
    unsigned long long _manifestSize;
    NSString *_manifestSHA256;
    NSDictionary<NSString *, id> *_manifestRepresentation;
    int _workspaceDescriptor;
    int _finalDescriptor;
    struct stat _workspaceIdentity;
    struct stat _finalIdentity;
}

+ (nullable instancetype)writerForWorkspace:(PXBackupPublicationWorkspace *)workspace
                                      error:(NSError **)error {
    if (error) *error = nil;
    if (![workspace isMemberOfClass:[PXBackupPublicationWorkspace class]]) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorInvalidInput,
                                 PXBackupManifestWorkspaceField,
                                 @"The manifest workspace is invalid");
        return nil;
    }
    NSError *workspaceError = nil;
    if (![workspace validateIdentityWithError:&workspaceError]) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorWorkspaceValidationFailed,
                                 PXBackupManifestWorkspaceField,
                                 @"The manifest workspace failed validation");
        return nil;
    }
    NSString *workspacePath = workspace.workspacePath;
    NSData *workspacePathData = PXBackupManifestLosslessUTF8Data(workspacePath);
    char *workspacePathBytes = PXBackupManifestCopyCString(workspacePathData);
    if (!workspacePathBytes) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorLimitExceeded,
                                 PXBackupManifestWorkspaceField,
                                 @"The manifest workspace path exceeds limits");
        return nil;
    }
    struct stat pathStat;
    struct stat descriptorStat;
    int workspaceDescriptor = -1;
    PXBackupManifestWriter *writer = nil;
    if (lstat(workspacePathBytes, &pathStat) != 0 ||
        S_ISLNK(pathStat.st_mode) ||
        !S_ISDIR(pathStat.st_mode) ||
        (pathStat.st_mode & 07777) != 0700) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorWorkspaceInspectionFailed,
                                 PXBackupManifestWorkspaceField,
                                 @"The manifest workspace could not be inspected safely");
        goto cleanup;
    }
    workspaceDescriptor = open(workspacePathBytes,
                               O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (workspaceDescriptor < 0 ||
        fstat(workspaceDescriptor, &descriptorStat) != 0 ||
        !S_ISDIR(descriptorStat.st_mode) ||
        (descriptorStat.st_mode & 07777) != 0700 ||
        !PXBackupManifestStatIdentityMatches(&pathStat, &descriptorStat) ||
        !PXBackupManifestDescriptorHasCloseOnExec(workspaceDescriptor)) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorWorkspaceInspectionFailed,
                                 PXBackupManifestWorkspaceField,
                                 @"The manifest workspace descriptor is invalid");
        goto cleanup;
    }
    workspaceError = nil;
    if (![workspace validateIdentityWithError:&workspaceError] ||
        !PXBackupManifestWorkspacePathMatchesDescriptor(workspacePath,
                                                        workspaceDescriptor,
                                                        &descriptorStat,
                                                        NULL)) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorWorkspaceValidationFailed,
                                 PXBackupManifestWorkspaceField,
                                 @"The manifest workspace identity changed");
        goto cleanup;
    }
    if (!PXBackupManifestFinalNameIsAbsent(workspaceDescriptor)) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorFinalManifestAlreadyExists,
                                 PXBackupManifestField,
                                 @"A final manifest already exists");
        goto cleanup;
    }
    NSUInteger temporaryCount = 0;
    if (!PXBackupManifestScanTemporaryEntries(workspaceDescriptor,
                                              NULL,
                                              &temporaryCount) ||
        temporaryCount != 0) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorWorkspaceInspectionFailed,
                                 PXBackupManifestTemporaryField,
                                 @"The manifest workspace contains an unexpected temporary entry");
        goto cleanup;
    }
    writer = [[PXBackupManifestWriter alloc]
        initWithWorkspace:workspace
            workspacePath:workspacePath
      workspaceDescriptor:workspaceDescriptor
        workspaceIdentity:&descriptorStat];
    if (!writer) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorWorkspaceInspectionFailed,
                                 PXBackupManifestWorkspaceField,
                                 @"The manifest writer could not retain the workspace");
        goto cleanup;
    }
    workspaceDescriptor = -1;

cleanup:
    free(workspacePathBytes);
    if (workspaceDescriptor >= 0) close(workspaceDescriptor);
    return writer;
}

- (instancetype)initWithWorkspace:(PXBackupPublicationWorkspace *)workspace
                    workspacePath:(NSString *)workspacePath
              workspaceDescriptor:(int)workspaceDescriptor
                workspaceIdentity:(const struct stat *)workspaceIdentity {
    self = [super init];
    if (self) {
        _workspace = workspace;
        _workspacePath = [workspacePath copy];
        _workspaceDescriptor = workspaceDescriptor;
        _finalDescriptor = -1;
        if (workspaceIdentity) _workspaceIdentity = *workspaceIdentity;
    }
    return self;
}

- (NSString *)workspacePath { return _workspacePath; }
- (NSString *)manifestPath { return _manifestPath; }
- (BOOL)isManifestWritten { return _manifestWritten; }
- (unsigned long long)manifestSize { return _manifestSize; }
- (NSString *)manifestSHA256 { return _manifestSHA256; }
- (NSDictionary<NSString *,id> *)manifestRepresentation {
    return _manifestRepresentation;
}

- (BOOL)validateIdentityWithError:(NSError **)error {
    if (error) *error = nil;
    NSError *workspaceError = nil;
    struct stat workspaceStat;
    if (![_workspace validateIdentityWithError:&workspaceError] ||
        !PXBackupManifestWorkspacePathMatchesDescriptor(_workspacePath,
                                                        _workspaceDescriptor,
                                                        &_workspaceIdentity,
                                                        &workspaceStat)) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorWorkspaceValidationFailed,
                                 PXBackupManifestWorkspaceField,
                                 @"The manifest workspace identity is invalid");
        return NO;
    }
    NSUInteger temporaryCount = 0;
    if (!PXBackupManifestScanTemporaryEntries(_workspaceDescriptor,
                                              NULL,
                                              &temporaryCount) ||
        temporaryCount != 0) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorFilesystemChanged,
                                 PXBackupManifestTemporaryField,
                                 @"The manifest temporary namespace changed");
        return NO;
    }
    if (!_manifestWritten) {
        if (_finalDescriptor >= 0 || _manifestSize != 0 ||
            _manifestSHA256 != nil || _manifestRepresentation != nil ||
            _manifestPath != nil ||
            !PXBackupManifestFinalNameIsAbsent(_workspaceDescriptor)) {
            PXBackupManifestSetError(error,
                                     PXBackupManifestWriterErrorFilesystemChanged,
                                     PXBackupManifestField,
                                     @"The unwritten manifest state is inconsistent");
            return NO;
        }
        return YES;
    }
    if (_finalDescriptor < 0 || _manifestSize == 0 ||
        ![_manifestSHA256 isKindOfClass:[NSString class]] ||
        ![_manifestRepresentation isKindOfClass:[NSDictionary class]] ||
        ![_manifestPath isKindOfClass:[NSString class]] ||
        ![_manifestPath isEqualToString:
            [_workspacePath stringByAppendingPathComponent:PXBackupManifestFinalFileName]]) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorFilesystemChanged,
                                 PXBackupManifestField,
                                 @"The retained manifest state is inconsistent");
        return NO;
    }
    struct stat finalStat;
    if (!PXBackupManifestFileBindingValid(_workspaceDescriptor,
                                          PXBackupManifestFinalFileNameBytes,
                                          _finalDescriptor,
                                          &_finalIdentity,
                                          _manifestSize,
                                          YES,
                                          &finalStat)) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorFilesystemChanged,
                                 PXBackupManifestField,
                                 @"The retained manifest identity changed");
        return NO;
    }
    NSData *data = nil;
    NSString *digest = nil;
    struct stat stableIdentity;
    if (!PXBackupManifestReadDescriptor(_finalDescriptor,
                                        &finalStat,
                                        _manifestSize,
                                        &data,
                                        &digest,
                                        &stableIdentity) ||
        ![digest isEqualToString:_manifestSHA256]) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorReadBackFailed,
                                 PXBackupManifestField,
                                 @"The retained manifest content changed");
        return NO;
    }
    NSDictionary *parsed = PXBackupManifestParseData(data);
    NSError *validationError = nil;
    if (!parsed ||
        ![PXBackupManifestValidator validateManifestObject:parsed
                                                     error:&validationError]) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorValidationFailed,
                                 PXBackupManifestSnapshotField,
                                 @"The retained manifest failed validation");
        return NO;
    }
    if (![parsed isEqualToDictionary:_manifestRepresentation]) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorSnapshotMismatch,
                                 PXBackupManifestSnapshotField,
                                 @"The retained manifest does not match the accepted snapshot");
        return NO;
    }
    return YES;
}

- (BOOL)writeManifestSnapshot:(PXBackupManifestV4 *)manifestSnapshot
                        error:(NSError **)error {
    if (error) *error = nil;
    if (![manifestSnapshot isMemberOfClass:[PXBackupManifestV4 class]]) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorInvalidInput,
                                 PXBackupManifestSnapshotField,
                                 @"The manifest snapshot is invalid");
        return NO;
    }
    if (_writeAttempted || _manifestWritten) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorManifestAlreadyWritten,
                                 PXBackupManifestField,
                                 @"The manifest writer has already been used");
        return NO;
    }
    NSError *identityError = nil;
    if (![self validateIdentityWithError:&identityError]) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorWorkspaceValidationFailed,
                                 PXBackupManifestWorkspaceField,
                                 @"The manifest writer identity is invalid");
        return NO;
    }
    _writeAttempted = YES;

    BOOL accepted = NO;
    BOOL renamed = NO;
    BOOL temporaryCreated = NO;
    NSUInteger cleanupEntries = 0;
    int temporaryDescriptor = -1;
    int finalDescriptor = -1;
    char temporaryName[(sizeof(PXBackupManifestTemporaryFilePrefixBytes) - 1) +
                       (PXBackupManifestRandomSuffixBytes * 2) + 1];
    memset(temporaryName, 0, sizeof(temporaryName));
    NSString *temporaryNameString = nil;
    NSData *serializedData = nil;
    NSData *preRenameData = nil;
    NSString *preRenameDigest = nil;
    NSDictionary *preRenameManifest = nil;
    NSError *preRenameValidationError = nil;
    NSData *postRenameData = nil;
    NSString *postRenameDigest = nil;
    NSDictionary *postRenameManifest = nil;
    NSError *postRenameValidationError = nil;
    struct stat temporaryIdentity;
    struct stat writtenIdentity;
    struct stat publishedIdentity;
    memset(&temporaryIdentity, 0, sizeof(temporaryIdentity));
    memset(&writtenIdentity, 0, sizeof(writtenIdentity));
    memset(&publishedIdentity, 0, sizeof(publishedIdentity));

    serializedData = PXBackupManifestSerializeSnapshot(manifestSnapshot);
    if (!serializedData) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorSerializationFailed,
                                 PXBackupManifestSnapshotField,
                                 @"The manifest snapshot could not be serialized");
        goto cleanup;
    }
    if (serializedData.length == 0 ||
        serializedData.length > PXBackupManifestMaximumSerializedBytes) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorLimitExceeded,
                                 PXBackupManifestSnapshotField,
                                 @"The serialized manifest exceeds fixed limits");
        goto cleanup;
    }
    if (!PXBackupManifestFinalNameIsAbsent(_workspaceDescriptor)) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorFinalManifestAlreadyExists,
                                 PXBackupManifestField,
                                 @"A final manifest already exists");
        goto cleanup;
    }

    for (NSUInteger attempt = 0;
         attempt < PXBackupManifestTemporaryCreationAttempts;
         attempt++) {
        temporaryNameString = nil;
        if (!PXBackupManifestGenerateTemporaryName(temporaryName,
                                                   sizeof(temporaryName),
                                                   &temporaryNameString)) {
            PXBackupManifestSetError(error,
                                     PXBackupManifestWriterErrorTemporaryCreationFailed,
                                     PXBackupManifestTemporaryField,
                                     @"A temporary manifest name could not be generated");
            goto cleanup;
        }
        temporaryDescriptor = openat(_workspaceDescriptor,
                                     temporaryName,
                                     O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
                                     0600);
        if (temporaryDescriptor >= 0) break;
        if (errno != EEXIST) {
            PXBackupManifestSetError(error,
                                     PXBackupManifestWriterErrorTemporaryCreationFailed,
                                     PXBackupManifestTemporaryField,
                                     @"The temporary manifest could not be created");
            goto cleanup;
        }
    }
    if (temporaryDescriptor < 0) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorTemporaryCreationFailed,
                                 PXBackupManifestTemporaryField,
                                 @"The temporary manifest name retry limit was reached");
        goto cleanup;
    }
    temporaryCreated = YES;
    if (fchmod(temporaryDescriptor, 0600) != 0 ||
        fstat(temporaryDescriptor, &temporaryIdentity) != 0 ||
        !S_ISREG(temporaryIdentity.st_mode) ||
        temporaryIdentity.st_nlink != 1 ||
        (temporaryIdentity.st_mode & 07777) != 0600 ||
        temporaryIdentity.st_size != 0 ||
        temporaryIdentity.st_dev != _workspaceIdentity.st_dev ||
        !PXBackupManifestDescriptorHasCloseOnExec(temporaryDescriptor) ||
        !PXBackupManifestFileBindingValid(_workspaceDescriptor,
                                          temporaryName,
                                          temporaryDescriptor,
                                          &temporaryIdentity,
                                          0,
                                          NO,
                                          NULL)) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorFilesystemChanged,
                                 PXBackupManifestTemporaryField,
                                 @"The temporary manifest identity is invalid");
        goto cleanup;
    }
    NSUInteger temporaryCount = 0;
    if (!PXBackupManifestScanTemporaryEntries(_workspaceDescriptor,
                                              temporaryName,
                                              &temporaryCount) ||
        temporaryCount != 1) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorFilesystemChanged,
                                 PXBackupManifestTemporaryField,
                                 @"The temporary manifest namespace is invalid");
        goto cleanup;
    }
    if (!PXBackupManifestFullWrite(temporaryDescriptor, serializedData)) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorWriteFailed,
                                 PXBackupManifestTemporaryField,
                                 @"The manifest bytes could not be written completely");
        goto cleanup;
    }
    if (fstat(temporaryDescriptor, &writtenIdentity) != 0 ||
        !S_ISREG(writtenIdentity.st_mode) ||
        writtenIdentity.st_nlink != 1 ||
        (writtenIdentity.st_mode & 07777) != 0600 ||
        writtenIdentity.st_size < 0 ||
        (unsigned long long)writtenIdentity.st_size !=
            (unsigned long long)serializedData.length ||
        writtenIdentity.st_dev != _workspaceIdentity.st_dev ||
        !PXBackupManifestStatIdentityMatches(&temporaryIdentity,
                                             &writtenIdentity) ||
        !PXBackupManifestFileBindingValid(_workspaceDescriptor,
                                          temporaryName,
                                          temporaryDescriptor,
                                          &writtenIdentity,
                                          (unsigned long long)serializedData.length,
                                          YES,
                                          NULL)) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorFilesystemChanged,
                                 PXBackupManifestTemporaryField,
                                 @"The written temporary manifest identity changed");
        goto cleanup;
    }
    if (!PXBackupManifestStrictSync(temporaryDescriptor) ||
        !PXBackupManifestStrictSync(_workspaceDescriptor)) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorDurabilityFailed,
                                 PXBackupManifestTemporaryField,
                                 @"The temporary manifest could not be synchronized");
        goto cleanup;
    }

    struct stat preRenameIdentity;
    if (!PXBackupManifestReadDescriptor(temporaryDescriptor,
                                        &writtenIdentity,
                                        (unsigned long long)serializedData.length,
                                        &preRenameData,
                                        &preRenameDigest,
                                        &preRenameIdentity)) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorReadBackFailed,
                                 PXBackupManifestTemporaryField,
                                 @"The temporary manifest could not be read back exactly");
        goto cleanup;
    }
    preRenameManifest = PXBackupManifestParseData(preRenameData);
    preRenameValidationError = nil;
    if (!preRenameManifest ||
        ![PXBackupManifestValidator validateManifestObject:preRenameManifest
                                                     error:&preRenameValidationError]) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorValidationFailed,
                                 PXBackupManifestSnapshotField,
                                 @"The temporary manifest failed validation");
        goto cleanup;
    }
    if (!PXBackupManifestSnapshotMatches(preRenameManifest, manifestSnapshot)) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorSnapshotMismatch,
                                 PXBackupManifestSnapshotField,
                                 @"The temporary manifest does not match the accepted snapshot");
        goto cleanup;
    }

    identityError = nil;
    if (![_workspace validateIdentityWithError:&identityError] ||
        !PXBackupManifestWorkspacePathMatchesDescriptor(_workspacePath,
                                                        _workspaceDescriptor,
                                                        &_workspaceIdentity,
                                                        NULL) ||
        !PXBackupManifestFileBindingValid(_workspaceDescriptor,
                                          temporaryName,
                                          temporaryDescriptor,
                                          &preRenameIdentity,
                                          (unsigned long long)serializedData.length,
                                          YES,
                                          NULL) ||
        !PXBackupManifestFinalNameIsAbsent(_workspaceDescriptor)) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorFilesystemChanged,
                                 PXBackupManifestField,
                                 @"The manifest namespace changed before finalization");
        goto cleanup;
    }
    if (renameat(_workspaceDescriptor,
                 temporaryName,
                 _workspaceDescriptor,
                 PXBackupManifestFinalFileNameBytes) != 0) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorFinalizationFailed,
                                 PXBackupManifestField,
                                 @"The manifest could not be finalized atomically");
        goto cleanup;
    }
    renamed = YES;
    if (fstat(temporaryDescriptor, &publishedIdentity) != 0 ||
        !PXBackupManifestPublishedFileStatMatches(&preRenameIdentity,
                                                  &publishedIdentity) ||
        !PXBackupManifestFileBindingValid(_workspaceDescriptor,
                                          PXBackupManifestFinalFileNameBytes,
                                          temporaryDescriptor,
                                          &publishedIdentity,
                                          (unsigned long long)serializedData.length,
                                          YES,
                                          NULL) ||
        !PXBackupManifestStrictSync(temporaryDescriptor) ||
        !PXBackupManifestStrictSync(_workspaceDescriptor)) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorDurabilityFailed,
                                 PXBackupManifestField,
                                 @"The finalized manifest could not be synchronized");
        goto cleanup;
    }
    finalDescriptor = openat(_workspaceDescriptor,
                             PXBackupManifestFinalFileNameBytes,
                             O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
    if (finalDescriptor < 0 ||
        !PXBackupManifestFileBindingValid(_workspaceDescriptor,
                                          PXBackupManifestFinalFileNameBytes,
                                          finalDescriptor,
                                          &publishedIdentity,
                                          (unsigned long long)serializedData.length,
                                          YES,
                                          NULL)) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorFinalizationFailed,
                                 PXBackupManifestField,
                                 @"The finalized manifest descriptor is invalid");
        goto cleanup;
    }
    close(temporaryDescriptor);
    temporaryDescriptor = -1;

    struct stat postRenameIdentity;
    if (!PXBackupManifestReadDescriptor(finalDescriptor,
                                        &publishedIdentity,
                                        (unsigned long long)serializedData.length,
                                        &postRenameData,
                                        &postRenameDigest,
                                        &postRenameIdentity) ||
        ![postRenameDigest isEqualToString:preRenameDigest]) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorReadBackFailed,
                                 PXBackupManifestField,
                                 @"The finalized manifest could not be read back exactly");
        goto cleanup;
    }
    postRenameManifest = PXBackupManifestParseData(postRenameData);
    postRenameValidationError = nil;
    if (!postRenameManifest ||
        ![PXBackupManifestValidator validateManifestObject:postRenameManifest
                                                     error:&postRenameValidationError]) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorValidationFailed,
                                 PXBackupManifestSnapshotField,
                                 @"The finalized manifest failed validation");
        goto cleanup;
    }
    if (!PXBackupManifestSnapshotMatches(postRenameManifest, manifestSnapshot)) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorSnapshotMismatch,
                                 PXBackupManifestSnapshotField,
                                 @"The finalized manifest does not match the accepted snapshot");
        goto cleanup;
    }
    identityError = nil;
    temporaryCount = 0;
    if (![_workspace validateIdentityWithError:&identityError] ||
        !PXBackupManifestWorkspacePathMatchesDescriptor(_workspacePath,
                                                        _workspaceDescriptor,
                                                        &_workspaceIdentity,
                                                        NULL) ||
        !PXBackupManifestFileBindingValid(_workspaceDescriptor,
                                          PXBackupManifestFinalFileNameBytes,
                                          finalDescriptor,
                                          &postRenameIdentity,
                                          (unsigned long long)serializedData.length,
                                          YES,
                                          NULL) ||
        !PXBackupManifestScanTemporaryEntries(_workspaceDescriptor,
                                              NULL,
                                              &temporaryCount) ||
        temporaryCount != 0) {
        PXBackupManifestSetError(error,
                                 PXBackupManifestWriterErrorFilesystemChanged,
                                 PXBackupManifestField,
                                 @"The finalized manifest identity changed");
        goto cleanup;
    }

    _finalDescriptor = finalDescriptor;
    finalDescriptor = -1;
    _finalIdentity = postRenameIdentity;
    _manifestSize = (unsigned long long)serializedData.length;
    _manifestSHA256 = [postRenameDigest copy];
    _manifestRepresentation = [manifestSnapshot.manifestRepresentation copy];
    _manifestPath = [[_workspacePath
        stringByAppendingPathComponent:PXBackupManifestFinalFileName] copy];
    _manifestWritten = YES;
    accepted = YES;
    if (error) *error = nil;

cleanup:
    if (!accepted && temporaryCreated) {
        int cleanupDescriptor = renamed
            ? (finalDescriptor >= 0 ? finalDescriptor : temporaryDescriptor)
            : temporaryDescriptor;
        const char *cleanupName = renamed
            ? PXBackupManifestFinalFileNameBytes
            : temporaryName;
        const struct stat *cleanupIdentity = renamed
            ? (publishedIdentity.st_ino != 0 ? &publishedIdentity : &preRenameIdentity)
            : (writtenIdentity.st_ino != 0 ? &writtenIdentity : &temporaryIdentity);
        if (!PXBackupManifestRemoveExactFile(_workspaceDescriptor,
                                             cleanupName,
                                             cleanupDescriptor,
                                             cleanupIdentity,
                                             &cleanupEntries)) {
            PXBackupManifestSetError(error,
                                     PXBackupManifestWriterErrorCleanupFailed,
                                     renamed ? PXBackupManifestField
                                             : PXBackupManifestTemporaryField,
                                     @"The failed manifest entry could not be removed safely");
        }
    }
    if (temporaryDescriptor >= 0) close(temporaryDescriptor);
    if (finalDescriptor >= 0) close(finalDescriptor);
    return accepted;
}

- (void)dealloc {
    if (_finalDescriptor >= 0) close(_finalDescriptor);
    if (_workspaceDescriptor >= 0) close(_workspaceDescriptor);
}

@end
