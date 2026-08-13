#import "PXBackupDirectoryDiscovery.h"
#import "PXBackupManifestValidator.h"

#import <CoreFoundation/CoreFoundation.h>

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

NSErrorDomain const PXBackupDirectoryDiscoveryErrorDomain =
    @"com.hydra.tlinkios.backup-directory-discovery";
NSString * const PXBackupDirectoryDiscoveryErrorFieldPathKey = @"fieldPath";

static NSString * const PXDiscoveryInputField = @"$.discovery.input";
static NSString * const PXDiscoveryRootField = @"$.discovery.root";
static NSString * const PXDiscoveryBundleField = @"$.discovery.bundle";
static NSString * const PXDiscoveryTraversalField = @"$.discovery.traversal";

static const NSUInteger PXDiscoveryMaximumRoots = 8U;
static const NSUInteger PXDiscoveryMaximumRootPathBytes = 4096U;
static const NSUInteger PXDiscoveryMaximumComponentBytes = 255U;
static const NSUInteger PXDiscoveryMaximumEntriesPerBundleRoot = 16384U;
static const NSUInteger PXDiscoveryMaximumAggregateEntries = 32768U;
static const unsigned long long PXDiscoveryMaximumManifestBytes =
    128ULL * 1024ULL * 1024ULL;
static const size_t PXDiscoveryReadBufferBytes = 64U * 1024U;
static const NSUInteger PXDiscoveryMaximumAcceptedBackups = 4096U;

static const char PXDiscoveryManifestFileName[] = "manifest.plist";
static const char PXDiscoveryPartialPrefix[] = ".weaponx-backup-partial-";
static const char PXDiscoveryQuarantinePrefix[] = ".weaponx-cleanup-quarantine-";
static const char PXDiscoveryLockFileName[] = ".weaponx-backup.lock";

#if defined(__APPLE__)
#define PX_DISCOVERY_MTIME_SEC(value) ((value).st_mtimespec.tv_sec)
#define PX_DISCOVERY_MTIME_NSEC(value) ((value).st_mtimespec.tv_nsec)
#define PX_DISCOVERY_CTIME_SEC(value) ((value).st_ctimespec.tv_sec)
#define PX_DISCOVERY_CTIME_NSEC(value) ((value).st_ctimespec.tv_nsec)
#else
#define PX_DISCOVERY_MTIME_SEC(value) ((value).st_mtim.tv_sec)
#define PX_DISCOVERY_MTIME_NSEC(value) ((value).st_mtim.tv_nsec)
#define PX_DISCOVERY_CTIME_SEC(value) ((value).st_ctim.tv_sec)
#define PX_DISCOVERY_CTIME_NSEC(value) ((value).st_ctim.tv_nsec)
#endif

static void PXDiscoverySetError(NSError **error,
                                PXBackupDirectoryDiscoveryErrorCode code,
                                NSString *field,
                                NSString *description) {
    if (!error) return;
    *error = [NSError errorWithDomain:PXBackupDirectoryDiscoveryErrorDomain
                                 code:code
                             userInfo:@{
                                 NSLocalizedDescriptionKey: description,
                                 PXBackupDirectoryDiscoveryErrorFieldPathKey: field,
                             }];
}

static BOOL PXDiscoveryDescriptorHasCloseOnExec(int descriptor) {
    if (descriptor < 0) return NO;
    int flags = -1;
    do {
        flags = fcntl(descriptor, F_GETFD);
    } while (flags < 0 && errno == EINTR);
    return flags >= 0 && (flags & FD_CLOEXEC) != 0;
}

static int PXDiscoveryDuplicateDescriptor(int descriptor) {
    if (descriptor < 0) return -1;
    int duplicate = -1;
    do {
        duplicate = fcntl(descriptor, F_DUPFD_CLOEXEC, 0);
    } while (duplicate < 0 && errno == EINTR);
    if (duplicate < 0 || !PXDiscoveryDescriptorHasCloseOnExec(duplicate)) {
        if (duplicate >= 0) close(duplicate);
        return -1;
    }
    return duplicate;
}

static BOOL PXDiscoveryStatIdentityMatches(const struct stat *left,
                                           const struct stat *right) {
    return left && right &&
        left->st_dev == right->st_dev &&
        left->st_ino == right->st_ino &&
        ((left->st_mode & S_IFMT) == (right->st_mode & S_IFMT));
}

static BOOL PXDiscoveryStableMetadataMatches(const struct stat *left,
                                             const struct stat *right) {
    return PXDiscoveryStatIdentityMatches(left, right) &&
        left->st_mode == right->st_mode &&
        left->st_nlink == right->st_nlink &&
        left->st_size == right->st_size &&
        PX_DISCOVERY_MTIME_SEC(*left) == PX_DISCOVERY_MTIME_SEC(*right) &&
        PX_DISCOVERY_MTIME_NSEC(*left) == PX_DISCOVERY_MTIME_NSEC(*right) &&
        PX_DISCOVERY_CTIME_SEC(*left) == PX_DISCOVERY_CTIME_SEC(*right) &&
        PX_DISCOVERY_CTIME_NSEC(*left) == PX_DISCOVERY_CTIME_NSEC(*right);
}

static BOOL PXDiscoveryStringContainsNUL(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return YES;
    for (NSUInteger index = 0; index < value.length; index++) {
        if ([value characterAtIndex:index] == 0) return YES;
    }
    return NO;
}

static BOOL PXDiscoveryValidateLosslessString(NSString *value,
                                              NSUInteger maximumBytes,
                                              BOOL requireAbsolute,
                                              BOOL requireComponent,
                                              NSData **dataOut) {
    if (dataOut) *dataOut = nil;
    if (![value isKindOfClass:[NSString class]] || value.length == 0 ||
        PXDiscoveryStringContainsNUL(value)) return NO;
    if (requireAbsolute && ![value hasPrefix:@"/"]) return NO;
    if (requireComponent && ([value isEqualToString:@"."] ||
                             [value isEqualToString:@".."])) return NO;
    if (requireComponent) {
        for (NSUInteger index = 0; index < value.length; index++) {
            unichar character = [value characterAtIndex:index];
            if (character == '/' || character == '\\' ||
                character < 0x20 || character == 0x7f || character == 0) {
                return NO;
            }
        }
    }
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding
                       allowLossyConversion:NO];
    if (![data isKindOfClass:[NSData class]] ||
        data.length == 0 || data.length > maximumBytes) return NO;
    NSString *roundTrip = [[NSString alloc] initWithData:data
                                                encoding:NSUTF8StringEncoding];
    if (![roundTrip isKindOfClass:[NSString class]] ||
        ![roundTrip isEqualToString:value]) return NO;
    if (dataOut) *dataOut = data;
    return YES;
}

static char *PXDiscoveryCopyCString(NSData *data) {
    if (![data isKindOfClass:[NSData class]] || data.length == 0 ||
        data.length > SIZE_MAX - 1U) return NULL;
    char *bytes = malloc(data.length + 1U);
    if (!bytes) return NULL;
    memcpy(bytes, data.bytes, data.length);
    bytes[data.length] = '\0';
    return bytes;
}

static BOOL PXDiscoveryValidateRawComponent(const char *name,
                                            NSString **stringOut) {
    if (stringOut) *stringOut = nil;
    if (!name) return NO;
    size_t length = 0;
    while (length <= PXDiscoveryMaximumComponentBytes && name[length] != '\0') {
        length += 1U;
    }
    if (length == 0 || length > PXDiscoveryMaximumComponentBytes ||
        (length == 1U && name[0] == '.') ||
        (length == 2U && name[0] == '.' && name[1] == '.')) return NO;
    for (size_t index = 0; index < length; index++) {
        unsigned char byte = (unsigned char)name[index];
        if (byte == '/' || byte == '\\' || byte < 0x20 || byte == 0x7f) return NO;
    }
    NSString *value = [[NSString alloc] initWithBytes:name
                                                length:length
                                              encoding:NSUTF8StringEncoding];
    if (![value isKindOfClass:[NSString class]]) return NO;
    NSData *roundTrip = [value dataUsingEncoding:NSUTF8StringEncoding
                            allowLossyConversion:NO];
    if (![roundTrip isKindOfClass:[NSData class]] ||
        roundTrip.length != length ||
        memcmp(roundTrip.bytes, name, length) != 0) return NO;
    if (stringOut) *stringOut = value;
    return YES;
}

static BOOL PXDiscoveryIsReservedOrHidden(const char *name) {
    if (!name || name[0] == '\0' || name[0] == '.') return YES;
    return strcmp(name, PXDiscoveryLockFileName) == 0 ||
        strncmp(name,
                PXDiscoveryPartialPrefix,
                sizeof(PXDiscoveryPartialPrefix) - 1U) == 0 ||
        strncmp(name,
                PXDiscoveryQuarantinePrefix,
                sizeof(PXDiscoveryQuarantinePrefix) - 1U) == 0;
}

static NSString *PXDiscoveryAppendComponent(NSString *base,
                                            NSString *component) {
    if (![base isKindOfClass:[NSString class]] ||
        ![component isKindOfClass:[NSString class]]) return nil;
    return [base hasSuffix:@"/"]
        ? [base stringByAppendingString:component]
        : [base stringByAppendingFormat:@"/%@", component];
}

static NSArray<NSString *> *PXDiscoveryCopySortedEntryNames(
    int directoryDescriptor,
    NSUInteger maximumEntries,
    NSUInteger *aggregateCount,
    NSError **error) {
    if (directoryDescriptor < 0 || !aggregateCount) {
        PXDiscoverySetError(error,
                            PXBackupDirectoryDiscoveryErrorInvalidInput,
                            PXDiscoveryTraversalField,
                            @"The directory enumeration inputs are invalid");
        return nil;
    }
    int duplicate = PXDiscoveryDuplicateDescriptor(directoryDescriptor);
    if (duplicate < 0) {
        PXDiscoverySetError(error,
                            PXBackupDirectoryDiscoveryErrorTraversalFailed,
                            PXDiscoveryTraversalField,
                            @"The backup directory could not be enumerated safely");
        return nil;
    }
    DIR *directory = fdopendir(duplicate);
    if (!directory) {
        close(duplicate);
        PXDiscoverySetError(error,
                            PXBackupDirectoryDiscoveryErrorTraversalFailed,
                            PXDiscoveryTraversalField,
                            @"The backup directory enumeration could not be opened");
        return nil;
    }
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    BOOL succeeded = YES;
    for (;;) {
        errno = 0;
        struct dirent *entry = readdir(directory);
        if (!entry) {
            if (errno != 0) succeeded = NO;
            break;
        }
        if ((entry->d_name[0] == '.' && entry->d_name[1] == '\0') ||
            (entry->d_name[0] == '.' && entry->d_name[1] == '.' &&
             entry->d_name[2] == '\0')) continue;
        if (names.count >= maximumEntries ||
            *aggregateCount >= PXDiscoveryMaximumAggregateEntries ||
            *aggregateCount == NSUIntegerMax) {
            succeeded = NO;
            PXDiscoverySetError(error,
                                PXBackupDirectoryDiscoveryErrorLimitExceeded,
                                PXDiscoveryTraversalField,
                                @"The backup discovery entry limit was exceeded");
            break;
        }
        NSString *name = nil;
        if (!PXDiscoveryValidateRawComponent(entry->d_name, &name)) continue;
        [names addObject:name];
        *aggregateCount += 1U;
    }
    closedir(directory);
    if (!succeeded) {
        if (error && !*error) {
            PXDiscoverySetError(error,
                                PXBackupDirectoryDiscoveryErrorTraversalFailed,
                                PXDiscoveryTraversalField,
                                @"The backup directory enumeration failed");
        }
        return nil;
    }
    [names sortUsingComparator:^NSComparisonResult(NSString *left,
                                                    NSString *right) {
        NSData *leftData = [left dataUsingEncoding:NSUTF8StringEncoding];
        NSData *rightData = [right dataUsingEncoding:NSUTF8StringEncoding];
        NSUInteger common = MIN(leftData.length, rightData.length);
        int comparison = common == 0 ? 0 :
            memcmp(leftData.bytes, rightData.bytes, common);
        if (comparison < 0) return NSOrderedAscending;
        if (comparison > 0) return NSOrderedDescending;
        if (leftData.length < rightData.length) return NSOrderedAscending;
        if (leftData.length > rightData.length) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return [names copy];
}

static BOOL PXDiscoveryReadUnsignedIntegral(id value,
                                            unsigned long long *numberOut) {
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
    if (numberOut) *numberOut = result;
    return YES;
}

static BOOL PXDiscoveryReadString(id value, NSString **stringOut) {
    if (stringOut) *stringOut = nil;
    if (![value isKindOfClass:[NSString class]]) return NO;
    if (stringOut) *stringOut = (NSString *)value;
    return YES;
}

static BOOL PXDiscoveryTimestampIsCanonical(NSString *timestamp) {
    NSData *ascii = [timestamp dataUsingEncoding:NSASCIIStringEncoding
                            allowLossyConversion:NO];
    if (![ascii isKindOfClass:[NSData class]] || ascii.length != 15U) return NO;
    const unsigned char *bytes = ascii.bytes;
    for (NSUInteger index = 0; index < 15U; index++) {
        if (index == 8U) {
            if (bytes[index] != '-') return NO;
        } else if (bytes[index] < '0' || bytes[index] > '9') {
            return NO;
        }
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    formatter.dateFormat = @"yyyyMMdd-HHmmss";
    formatter.lenient = NO;
    NSDate *date = [formatter dateFromString:timestamp];
    return date && [[formatter stringFromDate:date] isEqualToString:timestamp];
}

static BOOL PXDiscoveryBackupIdentifierIsCanonical(NSString *backupIdentifier) {
    NSData *ascii = [backupIdentifier dataUsingEncoding:NSASCIIStringEncoding
                                   allowLossyConversion:NO];
    if (![ascii isKindOfClass:[NSData class]] || ascii.length != 36U) return NO;
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:backupIdentifier];
    return uuid && [[uuid.UUIDString lowercaseString] isEqualToString:backupIdentifier];
}

static NSData *PXDiscoveryReadManifestData(int candidateDescriptor,
                                          const struct stat *candidateIdentity,
                                          struct stat *manifestIdentityOut) {
    int manifestDescriptor = -1;
    NSMutableData *data = nil;
    unsigned char *buffer = NULL;
    NSData *result = nil;
    struct stat namespaceBefore;
    struct stat descriptorBefore;
    struct stat descriptorAfter;
    struct stat namespaceAfter;
    if (candidateDescriptor < 0 || !candidateIdentity || !manifestIdentityOut) goto cleanup;
    if (fstatat(candidateDescriptor,
                PXDiscoveryManifestFileName,
                &namespaceBefore,
                AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISREG(namespaceBefore.st_mode) ||
        namespaceBefore.st_nlink != 1 ||
        (namespaceBefore.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        namespaceBefore.st_dev != candidateIdentity->st_dev ||
        namespaceBefore.st_size <= 0 ||
        (unsigned long long)namespaceBefore.st_size > PXDiscoveryMaximumManifestBytes) goto cleanup;
    manifestDescriptor = openat(candidateDescriptor,
                                PXDiscoveryManifestFileName,
                                O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
    if (manifestDescriptor < 0 ||
        !PXDiscoveryDescriptorHasCloseOnExec(manifestDescriptor) ||
        fstat(manifestDescriptor, &descriptorBefore) != 0 ||
        !PXDiscoveryStableMetadataMatches(&namespaceBefore, &descriptorBefore)) goto cleanup;
    data = [NSMutableData dataWithCapacity:(NSUInteger)descriptorBefore.st_size];
    buffer = malloc(PXDiscoveryReadBufferBytes);
    if (!data || !buffer) goto cleanup;
    unsigned long long remaining = (unsigned long long)descriptorBefore.st_size;
    while (remaining > 0) {
        size_t request = remaining > PXDiscoveryReadBufferBytes
            ? PXDiscoveryReadBufferBytes : (size_t)remaining;
        ssize_t count = -1;
        do {
            count = read(manifestDescriptor, buffer, request);
        } while (count < 0 && errno == EINTR);
        if (count <= 0 || (unsigned long long)count > remaining) goto cleanup;
        [data appendBytes:buffer length:(NSUInteger)count];
        remaining -= (unsigned long long)count;
    }
    unsigned char extra = 0;
    ssize_t extraCount = -1;
    do {
        extraCount = read(manifestDescriptor, &extra, 1U);
    } while (extraCount < 0 && errno == EINTR);
    if (extraCount != 0 ||
        fstat(manifestDescriptor, &descriptorAfter) != 0 ||
        fstatat(candidateDescriptor,
                PXDiscoveryManifestFileName,
                &namespaceAfter,
                AT_SYMLINK_NOFOLLOW) != 0 ||
        !PXDiscoveryStableMetadataMatches(&descriptorBefore, &descriptorAfter) ||
        !PXDiscoveryStableMetadataMatches(&descriptorAfter, &namespaceAfter) ||
        data.length != (NSUInteger)descriptorBefore.st_size) goto cleanup;
    *manifestIdentityOut = descriptorAfter;
    result = [data copy];
cleanup:
    if (buffer) free(buffer);
    if (manifestDescriptor >= 0) close(manifestDescriptor);
    return result;
}

static NSString *PXDiscoveryInspectCandidate(int bundleDescriptor,
                                             const struct stat *bundleIdentity,
                                             NSString *rootPath,
                                             NSString *bundleIdentifier,
                                             NSString *candidateName,
                                             NSMutableSet<NSString *> *acceptedIdentities) {
    NSData *candidateNameData = nil;
    char *candidateNameBytes = NULL;
    int candidateDescriptor = -1;
    NSString *result = nil;
    @try {
        if (!PXDiscoveryValidateLosslessString(candidateName,
                                               PXDiscoveryMaximumComponentBytes,
                                               NO,
                                               YES,
                                               &candidateNameData)) goto cleanup;
        candidateNameBytes = PXDiscoveryCopyCString(candidateNameData);
        if (!candidateNameBytes || PXDiscoveryIsReservedOrHidden(candidateNameBytes)) goto cleanup;
        struct stat namespaceBefore;
        struct stat descriptorBefore;
        if (fstatat(bundleDescriptor,
                    candidateNameBytes,
                    &namespaceBefore,
                    AT_SYMLINK_NOFOLLOW) != 0 ||
            !S_ISDIR(namespaceBefore.st_mode) ||
            (namespaceBefore.st_mode & (S_ISUID | S_ISGID)) != 0 ||
            namespaceBefore.st_dev != bundleIdentity->st_dev) goto cleanup;
        candidateDescriptor = openat(bundleDescriptor,
                                     candidateNameBytes,
                                     O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (candidateDescriptor < 0 ||
            !PXDiscoveryDescriptorHasCloseOnExec(candidateDescriptor) ||
            fstat(candidateDescriptor, &descriptorBefore) != 0 ||
            !PXDiscoveryStableMetadataMatches(&namespaceBefore, &descriptorBefore)) goto cleanup;
        struct stat manifestIdentity;
        NSData *manifestData = PXDiscoveryReadManifestData(candidateDescriptor,
                                                           &descriptorBefore,
                                                           &manifestIdentity);
        if (![manifestData isKindOfClass:[NSData class]]) goto cleanup;
        NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
        NSError *parseError = nil;
        id object = [NSPropertyListSerialization propertyListWithData:manifestData
                                                              options:NSPropertyListImmutable
                                                               format:&format
                                                                error:&parseError];
        (void)parseError;
        if (![object isKindOfClass:[NSDictionary class]]) goto cleanup;
        NSDictionary *manifest = (NSDictionary *)object;
        NSError *validationError = nil;
        if (![PXBackupManifestValidator validateManifestObject:manifest
                                                          error:&validationError]) goto cleanup;
        (void)validationError;
        unsigned long long version = 0;
        if (!PXDiscoveryReadUnsignedIntegral(manifest[@"manifestVersion"], &version) ||
            (version != 2ULL && version != 3ULL && version != 4ULL)) goto cleanup;
        NSString *manifestBundleIdentifier = nil;
        if (!PXDiscoveryReadString(manifest[@"bundleID"], &manifestBundleIdentifier) ||
            ![manifestBundleIdentifier isEqualToString:bundleIdentifier]) goto cleanup;
        if (version == 4ULL) {
            if ((descriptorBefore.st_mode & 07777) != 0700 ||
                (manifestIdentity.st_mode & 07777) != 0600) goto cleanup;
            NSDictionary *publication = manifest[@"publication"];
            NSString *protocol = nil;
            NSString *contentState = nil;
            NSString *timestamp = nil;
            NSString *backupIdentifier = nil;
            if (![publication isKindOfClass:[NSDictionary class]] ||
                !PXDiscoveryReadString(publication[@"protocol"], &protocol) ||
                !PXDiscoveryReadString(publication[@"contentState"], &contentState) ||
                !PXDiscoveryReadString(manifest[@"timestamp"], &timestamp) ||
                !PXDiscoveryReadString(manifest[@"backupID"], &backupIdentifier) ||
                ![protocol isEqualToString:@"atomic-directory-v1"] ||
                ![contentState isEqualToString:@"complete"] ||
                !PXDiscoveryTimestampIsCanonical(timestamp) ||
                !PXDiscoveryBackupIdentifierIsCanonical(backupIdentifier)) goto cleanup;
            NSString *expectedName = [NSString stringWithFormat:@"%@-%@",
                                      timestamp,
                                      backupIdentifier];
            if (![candidateName isEqualToString:expectedName]) goto cleanup;
        }
        struct stat descriptorAfter;
        struct stat namespaceAfter;
        struct stat manifestAfter;
        if (fstat(candidateDescriptor, &descriptorAfter) != 0 ||
            fstatat(bundleDescriptor,
                    candidateNameBytes,
                    &namespaceAfter,
                    AT_SYMLINK_NOFOLLOW) != 0 ||
            fstatat(candidateDescriptor,
                    PXDiscoveryManifestFileName,
                    &manifestAfter,
                    AT_SYMLINK_NOFOLLOW) != 0 ||
            !PXDiscoveryStableMetadataMatches(&descriptorBefore, &descriptorAfter) ||
            !PXDiscoveryStableMetadataMatches(&descriptorAfter, &namespaceAfter) ||
            !PXDiscoveryStableMetadataMatches(&manifestIdentity, &manifestAfter)) goto cleanup;
        NSString *identityKey = [NSString stringWithFormat:@"%llu:%llu",
                                 (unsigned long long)descriptorAfter.st_dev,
                                 (unsigned long long)descriptorAfter.st_ino];
        if ([acceptedIdentities containsObject:identityKey]) goto cleanup;
        NSString *candidatePath = PXDiscoveryAppendComponent(
            PXDiscoveryAppendComponent(rootPath, bundleIdentifier), candidateName);
        NSString *expectedPath = PXDiscoveryAppendComponent(
            PXDiscoveryAppendComponent(rootPath, bundleIdentifier), candidateName);
        if (![candidatePath isKindOfClass:[NSString class]] ||
            ![candidatePath isEqualToString:expectedPath]) goto cleanup;
        [acceptedIdentities addObject:identityKey];
        result = candidatePath;
    } @catch (NSException *exception) {
        (void)exception;
        result = nil;
    }
cleanup:
    if (candidateDescriptor >= 0) close(candidateDescriptor);
    if (candidateNameBytes) free(candidateNameBytes);
    return result;
}

@implementation PXBackupDirectoryDiscovery

+ (nullable NSArray<NSString *> *)discoverBackupDirectoriesAtBackupRoots:
    (NSArray<NSString *> *)backupRoots
    bundleIdentifier:(NSString *)bundleIdentifier
    error:(NSError **)error {
    if (error) *error = nil;
    @try {
        if (![backupRoots isKindOfClass:[NSArray class]] ||
            backupRoots.count == 0 || backupRoots.count > PXDiscoveryMaximumRoots) {
            PXDiscoverySetError(error,
                                PXBackupDirectoryDiscoveryErrorInvalidInput,
                                PXDiscoveryInputField,
                                @"The backup discovery roots are invalid");
            return nil;
        }
        NSData *bundleData = nil;
        if (!PXDiscoveryValidateLosslessString(bundleIdentifier,
                                               PXDiscoveryMaximumComponentBytes,
                                               NO,
                                               YES,
                                               &bundleData)) {
            PXDiscoverySetError(error,
                                PXBackupDirectoryDiscoveryErrorInvalidInput,
                                PXDiscoveryBundleField,
                                @"The backup discovery bundle identifier is invalid");
            return nil;
        }
        char *bundleBytes = PXDiscoveryCopyCString(bundleData);
        if (!bundleBytes) {
            PXDiscoverySetError(error,
                                PXBackupDirectoryDiscoveryErrorInternalInvariantFailed,
                                PXDiscoveryBundleField,
                                @"The backup discovery bundle identifier could not be retained");
            return nil;
        }
        NSMutableArray<NSString *> *accepted = [NSMutableArray array];
        NSMutableSet<NSString *> *acceptedIdentities = [NSMutableSet set];
        NSMutableSet<NSString *> *scannedBundleIdentities = [NSMutableSet set];
        NSUInteger aggregateEntries = 0U;
        BOOL failed = NO;
        for (id rootValue in backupRoots) {
            NSData *rootData = nil;
            if (!PXDiscoveryValidateLosslessString(rootValue,
                                                   PXDiscoveryMaximumRootPathBytes,
                                                   YES,
                                                   NO,
                                                   &rootData)) {
                PXDiscoverySetError(error,
                                    PXBackupDirectoryDiscoveryErrorInvalidInput,
                                    PXDiscoveryRootField,
                                    @"A backup discovery root is invalid");
                failed = YES;
                break;
            }
            NSString *rootPath = (NSString *)rootValue;
            char *rootBytes = PXDiscoveryCopyCString(rootData);
            if (!rootBytes) {
                PXDiscoverySetError(error,
                                    PXBackupDirectoryDiscoveryErrorInternalInvariantFailed,
                                    PXDiscoveryRootField,
                                    @"A backup discovery root could not be retained");
                failed = YES;
                break;
            }
            struct stat rootNamespace;
            if (lstat(rootBytes, &rootNamespace) != 0) {
                int failureErrno = errno;
                free(rootBytes);
                if (failureErrno == ENOENT) continue;
                PXDiscoverySetError(error,
                                    PXBackupDirectoryDiscoveryErrorRootInspectionFailed,
                                    PXDiscoveryRootField,
                                    @"A backup discovery root could not be inspected");
                failed = YES;
                break;
            }
            if (!S_ISDIR(rootNamespace.st_mode) ||
                (rootNamespace.st_mode & (S_ISUID | S_ISGID)) != 0) {
                free(rootBytes);
                PXDiscoverySetError(error,
                                    PXBackupDirectoryDiscoveryErrorRootInspectionFailed,
                                    PXDiscoveryRootField,
                                    @"A backup discovery root is unsafe");
                failed = YES;
                break;
            }
            int rootDescriptor = open(rootBytes,
                                      O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
            free(rootBytes);
            if (rootDescriptor < 0) {
                PXDiscoverySetError(error,
                                    PXBackupDirectoryDiscoveryErrorRootInspectionFailed,
                                    PXDiscoveryRootField,
                                    @"A backup discovery root could not be opened safely");
                failed = YES;
                break;
            }
            struct stat rootDescriptorStat;
            if (!PXDiscoveryDescriptorHasCloseOnExec(rootDescriptor) ||
                fstat(rootDescriptor, &rootDescriptorStat) != 0 ||
                !PXDiscoveryStableMetadataMatches(&rootNamespace,
                                                  &rootDescriptorStat)) {
                close(rootDescriptor);
                PXDiscoverySetError(error,
                                    PXBackupDirectoryDiscoveryErrorFilesystemChanged,
                                    PXDiscoveryRootField,
                                    @"A backup discovery root identity changed");
                failed = YES;
                break;
            }
            struct stat bundleNamespace;
            if (fstatat(rootDescriptor,
                        bundleBytes,
                        &bundleNamespace,
                        AT_SYMLINK_NOFOLLOW) != 0) {
                int failureErrno = errno;
                close(rootDescriptor);
                if (failureErrno == ENOENT) continue;
                PXDiscoverySetError(error,
                                    PXBackupDirectoryDiscoveryErrorBundleDirectoryInvalid,
                                    PXDiscoveryBundleField,
                                    @"The backup bundle directory could not be inspected");
                failed = YES;
                break;
            }
            if (!S_ISDIR(bundleNamespace.st_mode) ||
                (bundleNamespace.st_mode & (S_ISUID | S_ISGID)) != 0 ||
                bundleNamespace.st_dev != rootDescriptorStat.st_dev) {
                close(rootDescriptor);
                PXDiscoverySetError(error,
                                    PXBackupDirectoryDiscoveryErrorBundleDirectoryInvalid,
                                    PXDiscoveryBundleField,
                                    @"The backup bundle directory is unsafe");
                failed = YES;
                break;
            }
            int bundleDescriptor = openat(rootDescriptor,
                                          bundleBytes,
                                          O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
            if (bundleDescriptor < 0) {
                close(rootDescriptor);
                PXDiscoverySetError(error,
                                    PXBackupDirectoryDiscoveryErrorBundleDirectoryInvalid,
                                    PXDiscoveryBundleField,
                                    @"The backup bundle directory could not be opened safely");
                failed = YES;
                break;
            }
            struct stat bundleDescriptorStat;
            if (!PXDiscoveryDescriptorHasCloseOnExec(bundleDescriptor) ||
                fstat(bundleDescriptor, &bundleDescriptorStat) != 0 ||
                !PXDiscoveryStableMetadataMatches(&bundleNamespace,
                                                  &bundleDescriptorStat)) {
                close(bundleDescriptor);
                close(rootDescriptor);
                PXDiscoverySetError(error,
                                    PXBackupDirectoryDiscoveryErrorFilesystemChanged,
                                    PXDiscoveryBundleField,
                                    @"The backup bundle directory identity changed");
                failed = YES;
                break;
            }
            NSString *bundleIdentity = [NSString stringWithFormat:@"%llu:%llu",
                                        (unsigned long long)bundleDescriptorStat.st_dev,
                                        (unsigned long long)bundleDescriptorStat.st_ino];
            if ([scannedBundleIdentities containsObject:bundleIdentity]) {
                close(bundleDescriptor);
                close(rootDescriptor);
                continue;
            }
            [scannedBundleIdentities addObject:bundleIdentity];
            NSError *enumerationError = nil;
            NSArray<NSString *> *names = PXDiscoveryCopySortedEntryNames(
                bundleDescriptor,
                PXDiscoveryMaximumEntriesPerBundleRoot,
                &aggregateEntries,
                &enumerationError);
            if (!names) {
                close(bundleDescriptor);
                close(rootDescriptor);
                if (error) *error = enumerationError;
                failed = YES;
                break;
            }
            for (NSString *candidateName in names) {
                if (accepted.count >= PXDiscoveryMaximumAcceptedBackups) {
                    PXDiscoverySetError(error,
                                        PXBackupDirectoryDiscoveryErrorLimitExceeded,
                                        PXDiscoveryTraversalField,
                                        @"The accepted backup limit was exceeded");
                    failed = YES;
                    break;
                }
                NSString *path = PXDiscoveryInspectCandidate(bundleDescriptor,
                                                             &bundleDescriptorStat,
                                                             rootPath,
                                                             bundleIdentifier,
                                                             candidateName,
                                                             acceptedIdentities);
                if (path) [accepted addObject:path];
            }
            if (!failed) {
                char *finalRootBytes = PXDiscoveryCopyCString(rootData);
                struct stat rootNamespaceAfter;
                struct stat rootDescriptorAfter;
                struct stat bundleNamespaceAfter;
                struct stat bundleDescriptorAfter;
                BOOL authorityStable = finalRootBytes &&
                    lstat(finalRootBytes, &rootNamespaceAfter) == 0 &&
                    fstat(rootDescriptor, &rootDescriptorAfter) == 0 &&
                    fstatat(rootDescriptor,
                            bundleBytes,
                            &bundleNamespaceAfter,
                            AT_SYMLINK_NOFOLLOW) == 0 &&
                    fstat(bundleDescriptor, &bundleDescriptorAfter) == 0 &&
                    PXDiscoveryStableMetadataMatches(&rootNamespace,
                                                     &rootNamespaceAfter) &&
                    PXDiscoveryStableMetadataMatches(&rootDescriptorStat,
                                                     &rootDescriptorAfter) &&
                    PXDiscoveryStableMetadataMatches(&bundleNamespace,
                                                     &bundleNamespaceAfter) &&
                    PXDiscoveryStableMetadataMatches(&bundleDescriptorStat,
                                                     &bundleDescriptorAfter) &&
                    PXDiscoveryStatIdentityMatches(&rootNamespaceAfter,
                                                   &rootDescriptorAfter) &&
                    PXDiscoveryStatIdentityMatches(&bundleNamespaceAfter,
                                                   &bundleDescriptorAfter);
                if (finalRootBytes) free(finalRootBytes);
                if (!authorityStable) {
                    PXDiscoverySetError(error,
                                        PXBackupDirectoryDiscoveryErrorFilesystemChanged,
                                        PXDiscoveryRootField,
                                        @"The backup discovery authority changed during traversal");
                    failed = YES;
                }
            }
            close(bundleDescriptor);
            close(rootDescriptor);
            if (failed) break;
        }
        free(bundleBytes);
        if (failed) return nil;
        [accepted sortUsingComparator:^NSComparisonResult(NSString *left,
                                                          NSString *right) {
            NSComparisonResult component =
                [right.lastPathComponent compare:left.lastPathComponent];
            if (component != NSOrderedSame) return component;
            return [left compare:right];
        }];
        if (error) *error = nil;
        return [accepted copy];
    } @catch (NSException *exception) {
        (void)exception;
        PXDiscoverySetError(error,
                            PXBackupDirectoryDiscoveryErrorInternalInvariantFailed,
                            PXDiscoveryTraversalField,
                            @"The backup discovery operation failed safely");
        return nil;
    }
}

@end
