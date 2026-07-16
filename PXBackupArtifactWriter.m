#import "PXBackupArtifactWriter.h"
#import "PXBackupPublicationWorkspace.h"
#import "PXFileProtection.h"

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

NSErrorDomain const PXBackupArtifactWriterErrorDomain =
    @"com.hydra.projectx.backup-artifact-writer";
NSString * const PXBackupArtifactWriterErrorFieldPathKey = @"fieldPath";
NSString * const PXBackupArtifactTemporaryDirectoryPrefix =
    @".weaponx-artifact-partial-";

static NSString * const PXBackupArtifactWorkspaceField = @"$.workspace";
static NSString * const PXBackupArtifactField = @"$.artifact";
static NSString * const PXBackupArtifactRelativePathField = @"$.artifact.relativePath";
static NSString * const PXBackupArtifactParentField = @"$.artifact.parent";
static NSString * const PXBackupArtifactTemporaryField = @"$.artifact.temporary";
static NSString * const PXBackupArtifactPayloadField = @"$.artifact.payload";
static NSString * const PXBackupArtifactPolicyField = @"$.artifact.policy";
static NSString * const PXBackupArtifactProtectionField = @"$.artifact.payload.protection";

static const NSUInteger PXBackupArtifactMaximumArtifacts = 4096;
static const NSUInteger PXBackupArtifactMaximumRelativePathBytes = 4096;
static const NSUInteger PXBackupArtifactMaximumComponentBytes = 255;
static const NSUInteger PXBackupArtifactMaximumRelativeDepth = 32;
static const unsigned long long PXBackupArtifactMaximumFileBytes =
    64ULL * 1024ULL * 1024ULL * 1024ULL;
static const size_t PXBackupArtifactStreamBufferBytes = 64U * 1024U;
static const NSUInteger PXBackupArtifactTemporaryOperationalEntries = 1;
static const NSUInteger PXBackupArtifactFailureCleanupEntries = 8;
static const NSUInteger PXBackupArtifactMaximumAbsolutePathBytes = 4096;
static const char PXBackupArtifactTemporaryTemplate[] =
    ".weaponx-artifact-partial-XXXXXX";
static const char PXBackupArtifactPayloadName[] = "payload";

#if defined(__APPLE__)
#define PX_BACKUP_ARTIFACT_MTIME_SEC(value) ((value).st_mtimespec.tv_sec)
#define PX_BACKUP_ARTIFACT_MTIME_NSEC(value) ((value).st_mtimespec.tv_nsec)
#define PX_BACKUP_ARTIFACT_CTIME_SEC(value) ((value).st_ctimespec.tv_sec)
#define PX_BACKUP_ARTIFACT_CTIME_NSEC(value) ((value).st_ctimespec.tv_nsec)
#else
#define PX_BACKUP_ARTIFACT_MTIME_SEC(value) ((value).st_mtim.tv_sec)
#define PX_BACKUP_ARTIFACT_MTIME_NSEC(value) ((value).st_mtim.tv_nsec)
#define PX_BACKUP_ARTIFACT_CTIME_SEC(value) ((value).st_ctim.tv_sec)
#define PX_BACKUP_ARTIFACT_CTIME_NSEC(value) ((value).st_ctim.tv_nsec)
#endif

static void PXBackupArtifactSetError(NSError **error,
                                     PXBackupArtifactWriterErrorCode code,
                                     NSString *fieldPath,
                                     NSString *description) {
    if (!error) {
        return;
    }
    *error = [NSError errorWithDomain:PXBackupArtifactWriterErrorDomain
                                 code:code
                             userInfo:@{
                                 NSLocalizedDescriptionKey: description,
                                 PXBackupArtifactWriterErrorFieldPathKey: fieldPath,
                             }];
}

static BOOL PXBackupArtifactStatIdentityMatches(const struct stat *left,
                                                const struct stat *right) {
    return left && right &&
           left->st_dev == right->st_dev &&
           left->st_ino == right->st_ino &&
           ((left->st_mode & S_IFMT) == (right->st_mode & S_IFMT));
}

static BOOL PXBackupArtifactStableFileStatMatches(const struct stat *before,
                                                   const struct stat *after) {
    return PXBackupArtifactStatIdentityMatches(before, after) &&
           (before->st_mode & 07777) == (after->st_mode & 07777) &&
           before->st_nlink == after->st_nlink &&
           before->st_size == after->st_size &&
           PX_BACKUP_ARTIFACT_MTIME_SEC(*before) ==
               PX_BACKUP_ARTIFACT_MTIME_SEC(*after) &&
           PX_BACKUP_ARTIFACT_MTIME_NSEC(*before) ==
               PX_BACKUP_ARTIFACT_MTIME_NSEC(*after) &&
           PX_BACKUP_ARTIFACT_CTIME_SEC(*before) ==
               PX_BACKUP_ARTIFACT_CTIME_SEC(*after) &&
           PX_BACKUP_ARTIFACT_CTIME_NSEC(*before) ==
               PX_BACKUP_ARTIFACT_CTIME_NSEC(*after);
}

static BOOL PXBackupArtifactDescriptorHasCloseOnExec(int descriptor) {
    if (descriptor < 0) {
        return NO;
    }
    int flags = -1;
    do {
        flags = fcntl(descriptor, F_GETFD);
    } while (flags < 0 && errno == EINTR);
    return flags >= 0 && (flags & FD_CLOEXEC) != 0;
}

static int PXBackupArtifactDuplicateDescriptor(int descriptor) {
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
    if (setResult < 0 ||
        !PXBackupArtifactDescriptorHasCloseOnExec(duplicated)) {
        close(duplicated);
        return -1;
    }
    return duplicated;
}

static BOOL PXBackupArtifactStrictSync(int descriptor) {
    if (descriptor < 0) {
        return NO;
    }
    int result = -1;
    do {
        result = fsync(descriptor);
    } while (result < 0 && errno == EINTR);
    return result == 0;
}

static BOOL PXBackupArtifactSetMode(int descriptor, mode_t mode) {
    if (descriptor < 0) return NO;
    int result = -1;
    do {
        result = fchmod(descriptor, mode);
    } while (result < 0 && errno == EINTR);
    return result == 0;
}

static BOOL PXBackupArtifactProtectedStatMatchesPolicy(
    const struct stat *status,
    PXBackupArtifactPolicy *policy) {
    return status &&
           [policy isMemberOfClass:[PXBackupArtifactPolicy class]] &&
           S_ISREG(status->st_mode) &&
           status->st_nlink == 1 &&
           status->st_uid == geteuid() &&
           status->st_gid == getegid() &&
           (status->st_mode & (S_ISUID | S_ISGID)) == 0 &&
           (status->st_mode & 07777) == (mode_t)policy.requiredPOSIXMode;
}

static BOOL PXBackupArtifactVerifyDescriptorForPolicy(
    int descriptor,
    PXBackupArtifactPolicy *policy,
    struct stat *statusOut) {
    if (descriptor < 0 ||
        ![policy isMemberOfClass:[PXBackupArtifactPolicy class]] ||
        !PXBackupArtifactDescriptorHasCloseOnExec(descriptor)) return NO;
    if (policy.dataProtectionRequirement ==
        PXBackupArtifactDataProtectionRequirementComplete) {
        if (!PXVerifyCompleteFileProtectionOnDescriptor(descriptor, NULL)) return NO;
    } else if (policy.dataProtectionRequirement !=
               PXBackupArtifactDataProtectionRequirementUnspecified) {
        return NO;
    }
    struct stat status;
    if (fstat(descriptor, &status) != 0 ||
        !PXBackupArtifactProtectedStatMatchesPolicy(&status, policy)) return NO;
    if (statusOut) *statusOut = status;
    return YES;
}

static BOOL PXBackupArtifactStringContainsNull(NSString *value) {
    for (NSUInteger index = 0; index < value.length; index++) {
        if ([value characterAtIndex:index] == 0) {
            return YES;
        }
    }
    return NO;
}

static NSData *PXBackupArtifactLosslessUTF8Data(NSString *value) {
    if (![value isKindOfClass:[NSString class]] ||
        PXBackupArtifactStringContainsNull(value)) {
        return nil;
    }
    return [value dataUsingEncoding:NSUTF8StringEncoding
                allowLossyConversion:NO];
}

static char *PXBackupArtifactCopyCString(NSData *data) {
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

static int PXBackupArtifactOpenRelativeFile(int rootDescriptor,
                                            NSString *relativePath,
                                            int accessMode) {
    if (rootDescriptor < 0 ||
        ![relativePath isKindOfClass:[NSString class]] ||
        relativePath.length == 0 ||
        (accessMode != O_RDONLY && accessMode != O_RDWR)) return -1;
    NSArray<NSString *> *components =
        [relativePath componentsSeparatedByString:@"/"];
    if (components.count == 0 ||
        components.count > PXBackupArtifactMaximumRelativeDepth) return -1;
    int currentDescriptor = rootDescriptor;
    BOOL ownsCurrentDescriptor = NO;
    for (NSUInteger index = 0; index + 1 < components.count; index++) {
        NSData *componentData = PXBackupArtifactLosslessUTF8Data(components[index]);
        char *componentName = PXBackupArtifactCopyCString(componentData);
        if (!componentName || componentName[0] == '\0') {
            free(componentName);
            if (ownsCurrentDescriptor) close(currentDescriptor);
            return -1;
        }
        int nextDescriptor = openat(currentDescriptor,
                                    componentName,
                                    O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        free(componentName);
        struct stat status;
        BOOL valid = nextDescriptor >= 0 &&
                     PXBackupArtifactDescriptorHasCloseOnExec(nextDescriptor) &&
                     fstat(nextDescriptor, &status) == 0 &&
                     S_ISDIR(status.st_mode);
        if (!valid) {
            if (nextDescriptor >= 0) close(nextDescriptor);
            if (ownsCurrentDescriptor) close(currentDescriptor);
            return -1;
        }
        if (ownsCurrentDescriptor) close(currentDescriptor);
        currentDescriptor = nextDescriptor;
        ownsCurrentDescriptor = YES;
    }
    NSData *finalData = PXBackupArtifactLosslessUTF8Data(components.lastObject);
    char *finalName = PXBackupArtifactCopyCString(finalData);
    if (!finalName || finalName[0] == '\0') {
        free(finalName);
        if (ownsCurrentDescriptor) close(currentDescriptor);
        return -1;
    }
    int descriptor = openat(currentDescriptor,
                            finalName,
                            accessMode | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
    free(finalName);
    if (ownsCurrentDescriptor) close(currentDescriptor);
    if (descriptor < 0 || !PXBackupArtifactDescriptorHasCloseOnExec(descriptor)) {
        if (descriptor >= 0) close(descriptor);
        return -1;
    }
    return descriptor;
}

static NSString *PXBackupArtifactAppendComponent(NSString *parent,
                                                  NSString *component) {
    if ([parent isEqualToString:@"/"]) {
        return [@"/" stringByAppendingString:component];
    }
    return [NSString stringWithFormat:@"%@/%@", parent, component];
}

static BOOL PXBackupArtifactPathRoundTrips(NSString *value,
                                           NSData *expectedBytes) {
    NSData *roundTrip = PXBackupArtifactLosslessUTF8Data(value);
    return roundTrip && expectedBytes &&
           roundTrip.length == expectedBytes.length &&
           memcmp(roundTrip.bytes,
                  expectedBytes.bytes,
                  expectedBytes.length) == 0;
}

static BOOL PXBackupArtifactValidateComponent(NSString *component,
                                              NSData **componentData,
                                              BOOL *limitExceeded) {
    if (componentData) {
        *componentData = nil;
    }
    if (limitExceeded) {
        *limitExceeded = NO;
    }
    if (![component isKindOfClass:[NSString class]] || component.length == 0 ||
        [component isEqualToString:@"."] ||
        [component isEqualToString:@".."]) {
        return NO;
    }
    NSCharacterSet *controls = [NSCharacterSet controlCharacterSet];
    for (NSUInteger index = 0; index < component.length; index++) {
        unichar character = [component characterAtIndex:index];
        if (character == 0 || character == '\\' || character == '/' ||
            [controls characterIsMember:character]) {
            return NO;
        }
    }
    if ([component isEqualToString:@".weaponx-backup.lock"] ||
        [component isEqualToString:@"manifest.plist"] ||
        [component hasPrefix:@".weaponx-backup-partial-"] ||
        [component hasPrefix:PXBackupArtifactTemporaryDirectoryPrefix]) {
        return NO;
    }
    NSData *data = PXBackupArtifactLosslessUTF8Data(component);
    if (!data || data.length == 0 ||
        !PXBackupArtifactPathRoundTrips(component, data)) {
        return NO;
    }
    if (data.length > PXBackupArtifactMaximumComponentBytes) {
        if (limitExceeded) {
            *limitExceeded = YES;
        }
        return NO;
    }
    if (componentData) {
        *componentData = data;
    }
    return YES;
}

static BOOL PXBackupArtifactValidateTemporaryComponent(NSString *component,
                                                       NSData **componentData) {
    if (componentData) {
        *componentData = nil;
    }
    if (![component isKindOfClass:[NSString class]] ||
        component.length == 0 ||
        ![component hasPrefix:PXBackupArtifactTemporaryDirectoryPrefix] ||
        [component isEqualToString:@"."] ||
        [component isEqualToString:@".."]) {
        return NO;
    }
    NSCharacterSet *controls = [NSCharacterSet controlCharacterSet];
    for (NSUInteger index = 0; index < component.length; index++) {
        unichar character = [component characterAtIndex:index];
        if (character == 0 || character == '\\' || character == '/' ||
            [controls characterIsMember:character]) {
            return NO;
        }
    }
    NSData *data = PXBackupArtifactLosslessUTF8Data(component);
    if (!data || data.length == 0 ||
        data.length > PXBackupArtifactMaximumComponentBytes ||
        !PXBackupArtifactPathRoundTrips(component, data)) {
        return NO;
    }
    if (componentData) {
        *componentData = data;
    }
    return YES;
}

static NSArray<NSString *> *PXBackupArtifactValidateRelativePath(
    NSString *relativePath,
    BOOL *limitExceeded) {
    if (limitExceeded) {
        *limitExceeded = NO;
    }
    if (![relativePath isKindOfClass:[NSString class]] ||
        relativePath.length == 0 ||
        [relativePath hasPrefix:@"/"] ||
        [relativePath hasSuffix:@"/"] ||
        PXBackupArtifactStringContainsNull(relativePath)) {
        return nil;
    }
    NSData *pathData = PXBackupArtifactLosslessUTF8Data(relativePath);
    if (!pathData || pathData.length == 0 ||
        !PXBackupArtifactPathRoundTrips(relativePath, pathData)) {
        return nil;
    }
    if (pathData.length > PXBackupArtifactMaximumRelativePathBytes) {
        if (limitExceeded) {
            *limitExceeded = YES;
        }
        return nil;
    }
    NSArray<NSString *> *components = [relativePath componentsSeparatedByString:@"/"];
    if (components.count == 0 ||
        components.count > PXBackupArtifactMaximumRelativeDepth) {
        if (limitExceeded &&
            components.count > PXBackupArtifactMaximumRelativeDepth) {
            *limitExceeded = YES;
        }
        return nil;
    }
    NSMutableArray<NSString *> *validated =
        [NSMutableArray arrayWithCapacity:components.count];
    for (id candidate in components) {
        NSData *componentData = nil;
        BOOL componentLimitExceeded = NO;
        if (![candidate isKindOfClass:[NSString class]] ||
            !PXBackupArtifactValidateComponent(candidate,
                                               &componentData,
                                               &componentLimitExceeded)) {
            if (limitExceeded && componentLimitExceeded) {
                *limitExceeded = YES;
            }
            return nil;
        }
        [validated addObject:[(NSString *)candidate copy]];
    }
    NSString *joined = [validated componentsJoinedByString:@"/"];
    if (![joined isEqualToString:relativePath] ||
        !PXBackupArtifactPathRoundTrips(joined, pathData)) {
        return nil;
    }
    return [validated copy];
}

static BOOL PXBackupArtifactDirectoryEntries(int descriptor,
                                             NSUInteger maximumEntries,
                                             NSArray<NSString *> **entriesOut) {
    if (entriesOut) {
        *entriesOut = nil;
    }
    int duplicated = PXBackupArtifactDuplicateDescriptor(descriptor);
    if (duplicated < 0) {
        return NO;
    }
    DIR *directory = fdopendir(duplicated);
    if (!directory) {
        close(duplicated);
        return NO;
    }
    NSMutableArray<NSString *> *entries = [NSMutableArray array];
    BOOL complete = YES;
    errno = 0;
    struct dirent *entry = NULL;
    while ((entry = readdir(directory)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 ||
            strcmp(entry->d_name, "..") == 0) {
            continue;
        }
        if (entries.count >= maximumEntries) {
            complete = NO;
            break;
        }
        size_t length = strlen(entry->d_name);
        NSString *name = [[NSString alloc] initWithBytes:entry->d_name
                                                 length:length
                                               encoding:NSUTF8StringEncoding];
        NSData *roundTrip = [name dataUsingEncoding:NSUTF8StringEncoding
                                allowLossyConversion:NO];
        if (!name || !roundTrip || roundTrip.length != length ||
            memcmp(roundTrip.bytes, entry->d_name, length) != 0) {
            complete = NO;
            break;
        }
        [entries addObject:name];
    }
    if (!entry && errno != 0) {
        complete = NO;
    }
    if (closedir(directory) != 0) {
        complete = NO;
    }
    if (complete && entriesOut) {
        *entriesOut = [entries copy];
    }
    return complete;
}

static BOOL PXBackupArtifactRemoveCreatedEmptyDirectoryIfSafe(
    int parentDescriptor,
    const char *name,
    const struct stat *expectedIdentity,
    dev_t expectedDevice) {
    if (parentDescriptor < 0 || !name || !expectedIdentity) {
        return NO;
    }
    struct stat namespaceStat;
    if (fstatat(parentDescriptor,
                name,
                &namespaceStat,
                AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(namespaceStat.st_mode) ||
        namespaceStat.st_dev != expectedDevice ||
        !PXBackupArtifactStatIdentityMatches(&namespaceStat,
                                            expectedIdentity)) {
        return NO;
    }
    int descriptor = openat(parentDescriptor,
                            name,
                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (descriptor < 0) {
        return NO;
    }
    struct stat descriptorStat;
    NSArray<NSString *> *entries = nil;
    BOOL safe = fstat(descriptor, &descriptorStat) == 0 &&
                S_ISDIR(descriptorStat.st_mode) &&
                descriptorStat.st_dev == expectedDevice &&
                PXBackupArtifactStatIdentityMatches(&descriptorStat,
                                                    expectedIdentity) &&
                PXBackupArtifactStatIdentityMatches(&descriptorStat,
                                                    &namespaceStat) &&
                PXBackupArtifactDescriptorHasCloseOnExec(descriptor) &&
                PXBackupArtifactDirectoryEntries(descriptor,
                                                 PXBackupArtifactFailureCleanupEntries,
                                                 &entries) &&
                entries.count == 0;
    struct stat finalNamespaceStat;
    safe = safe &&
           fstatat(parentDescriptor,
                   name,
                   &finalNamespaceStat,
                   AT_SYMLINK_NOFOLLOW) == 0 &&
           S_ISDIR(finalNamespaceStat.st_mode) &&
           PXBackupArtifactStatIdentityMatches(&finalNamespaceStat,
                                               expectedIdentity) &&
           unlinkat(parentDescriptor, name, AT_REMOVEDIR) == 0 &&
           PXBackupArtifactStrictSync(parentDescriptor);
    close(descriptor);
    return safe;
}

static BOOL PXBackupArtifactPathMatchesDirectoryDescriptor(
    NSString *path,
    int descriptor,
    const struct stat *expectedIdentity) {
    NSData *pathData = PXBackupArtifactLosslessUTF8Data(path);
    char *pathCString = PXBackupArtifactCopyCString(pathData);
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
                 PXBackupArtifactStatIdentityMatches(&pathStat,
                                                     &descriptorStat) &&
                 (!expectedIdentity ||
                  PXBackupArtifactStatIdentityMatches(expectedIdentity,
                                                      &descriptorStat));
    free(pathCString);
    return valid;
}

static BOOL PXBackupArtifactDirectoryIdentityValid(int descriptor,
                                                    const struct stat *expected,
                                                    dev_t expectedDevice,
                                                    BOOL requireMode0700) {
    struct stat current;
    return descriptor >= 0 &&
           fstat(descriptor, &current) == 0 &&
           S_ISDIR(current.st_mode) &&
           (current.st_mode & (S_ISUID | S_ISGID)) == 0 &&
           (!requireMode0700 || (current.st_mode & 07777) == 0700) &&
           current.st_dev == expectedDevice &&
           PXBackupArtifactStatIdentityMatches(&current, expected) &&
           PXBackupArtifactDescriptorHasCloseOnExec(descriptor);
}

static NSString *PXBackupArtifactHexDigest(const unsigned char *digest,
                                           size_t length) {
    static const char alphabet[] = "0123456789abcdef";
    if (!digest || length != CC_SHA256_DIGEST_LENGTH) {
        return nil;
    }
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

@interface PXBackupArtifactParentBinding : NSObject

@property (nonatomic, assign) int descriptor;
@property (nonatomic, assign) int authorityDescriptor;
@property (nonatomic, copy) NSData *authorityComponentData;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, assign) struct stat identity;
@property (nonatomic, assign) struct stat authorityIdentity;
@property (nonatomic, assign) BOOL workspaceRoot;

- (const struct stat *)identityPointer;
- (const struct stat *)authorityIdentityPointer;

@end

@implementation PXBackupArtifactParentBinding

- (instancetype)init {
    self = [super init];
    if (self) {
        _descriptor = -1;
        _authorityDescriptor = -1;
    }
    return self;
}

- (const struct stat *)identityPointer {
    return &_identity;
}

- (const struct stat *)authorityIdentityPointer {
    return &_authorityIdentity;
}

- (void)dealloc {
    if (_descriptor >= 0) {
        close(_descriptor);
        _descriptor = -1;
    }
    if (_authorityDescriptor >= 0) {
        close(_authorityDescriptor);
        _authorityDescriptor = -1;
    }
}

@end

@interface PXBackupArtifactTemporaryBinding : NSObject

@property (nonatomic, assign) int descriptor;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSData *nameData;
@property (nonatomic, assign) struct stat identity;

- (const struct stat *)identityPointer;

@end

@implementation PXBackupArtifactTemporaryBinding

- (instancetype)init {
    self = [super init];
    if (self) {
        _descriptor = -1;
    }
    return self;
}

- (const struct stat *)identityPointer {
    return &_identity;
}

- (void)dealloc {
    if (_descriptor >= 0) {
        close(_descriptor);
        _descriptor = -1;
    }
}

@end

@interface PXVerifiedBackupArtifact ()

- (instancetype)initWithRelativePath:(NSString *)relativePath
                            filePath:(NSString *)filePath
                                size:(unsigned long long)size
                              sha256:(NSString *)sha256
                              policy:(PXBackupArtifactPolicy *)policy
                          descriptor:(int)descriptor
                            identity:(const struct stat *)identity;
- (BOOL)validateRetainedDescriptor;
- (const struct stat *)identityPointer;

@end

@implementation PXVerifiedBackupArtifact {
    NSString *_relativePath;
    NSString *_filePath;
    unsigned long long _size;
    NSString *_sha256;
    PXBackupArtifactPolicy *_policy;
    BOOL _protectionVerified;
    NSDictionary<NSString *, id> *_manifestRepresentation;
    int _descriptor;
    struct stat _identity;
}

- (instancetype)initWithRelativePath:(NSString *)relativePath
                            filePath:(NSString *)filePath
                                size:(unsigned long long)size
                              sha256:(NSString *)sha256
                              policy:(PXBackupArtifactPolicy *)policy
                          descriptor:(int)descriptor
                            identity:(const struct stat *)identity {
    if (![policy isMemberOfClass:[PXBackupArtifactPolicy class]] ||
        descriptor < 0 || !identity ||
        !PXBackupArtifactVerifyDescriptorForPolicy(descriptor, policy, NULL)) {
        if (descriptor >= 0) close(descriptor);
        return nil;
    }
    self = [super init];
    if (!self) {
        close(descriptor);
        return nil;
    }
    {
        _relativePath = [relativePath copy];
        _filePath = [filePath copy];
        _size = size;
        _sha256 = [sha256 copy];
        _policy = policy;
        _protectionVerified = YES;
        _descriptor = descriptor;
        _identity = *identity;
        _manifestRepresentation = @{
            @"name": _relativePath,
            @"path": _filePath,
            @"size": [NSNumber numberWithUnsignedLongLong:_size],
            @"sha256": _sha256,
        };
    }
    return self;
}

- (NSString *)relativePath { return _relativePath; }
- (NSString *)filePath { return _filePath; }
- (unsigned long long)size { return _size; }
- (NSString *)sha256 { return _sha256; }
- (PXBackupArtifactPolicy *)policy { return _policy; }
- (BOOL)protectionVerified { return _protectionVerified; }
- (NSDictionary<NSString *,id> *)manifestRepresentation {
    return _manifestRepresentation;
}
- (const struct stat *)identityPointer { return &_identity; }
- (BOOL)validateRetainedDescriptor {
    struct stat current;
    return _descriptor >= 0 &&
           PXBackupArtifactVerifyDescriptorForPolicy(_descriptor,
                                                     _policy,
                                                     &current) &&
           PXBackupArtifactStableFileStatMatches(&_identity, &current);
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[PXVerifiedBackupArtifact class]]) {
        return NO;
    }
    PXVerifiedBackupArtifact *other = object;
    return self.size == other.size &&
           [self.relativePath isEqualToString:other.relativePath] &&
           [self.filePath isEqualToString:other.filePath] &&
           [self.sha256 isEqualToString:other.sha256] &&
           [self.policy isEqual:other.policy];
}

- (NSUInteger)hash {
    NSUInteger value = self.relativePath.hash;
    value ^= self.filePath.hash + (NSUInteger)0x9e3779b9 + (value << 6) + (value >> 2);
    value ^= (NSUInteger)self.size + (NSUInteger)0x9e3779b9 + (value << 6) + (value >> 2);
    value ^= self.sha256.hash + (NSUInteger)0x9e3779b9 + (value << 6) + (value >> 2);
    value ^= self.policy.hash + (NSUInteger)0x9e3779b9 + (value << 6) + (value >> 2);
    return value;
}

- (void)dealloc {
    if (_descriptor >= 0) {
        close(_descriptor);
        _descriptor = -1;
    }
}

@end

@interface PXBackupArtifactWriter ()

- (instancetype)initWithWorkspace:(PXBackupPublicationWorkspace *)workspace
                    workspacePath:(NSString *)workspacePath
               workspaceDescriptor:(int)workspaceDescriptor
                 workspaceIdentity:(const struct stat *)workspaceIdentity;

@end

@implementation PXBackupArtifactWriter {
    PXBackupPublicationWorkspace *_workspace;
    NSString *_workspacePath;
    int _workspaceDescriptor;
    struct stat _workspaceIdentity;
    NSMutableSet<NSString *> *_acceptedPaths;
    NSMutableSet<NSString *> *_acceptedNormalizedAliases;
    NSMutableArray<PXVerifiedBackupArtifact *> *_acceptedArtifacts;
    NSUInteger _artifactCount;
}

+ (nullable instancetype)writerForWorkspace:(PXBackupPublicationWorkspace *)workspace
                                      error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    if (!workspace ||
        ![workspace isMemberOfClass:[PXBackupPublicationWorkspace class]]) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorInvalidInput,
                                 PXBackupArtifactWorkspaceField,
                                 @"The workspace input is invalid");
        return nil;
    }
    NSError *workspaceError = nil;
    if (![workspace validateIdentityWithError:&workspaceError]) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorWorkspaceValidationFailed,
                                 PXBackupArtifactWorkspaceField,
                                 @"The workspace identity is invalid");
        return nil;
    }
    NSString *workspacePath = workspace.workspacePath;
    NSData *workspaceData = PXBackupArtifactLosslessUTF8Data(workspacePath);
    if (!workspaceData || workspaceData.length == 0 ||
        workspaceData.length > PXBackupArtifactMaximumAbsolutePathBytes ||
        ![workspacePath hasPrefix:@"/"] ||
        !PXBackupArtifactPathRoundTrips(workspacePath, workspaceData)) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorInvalidInput,
                                 PXBackupArtifactWorkspaceField,
                                 @"The workspace path is invalid");
        return nil;
    }
    char *workspaceCString = PXBackupArtifactCopyCString(workspaceData);
    if (!workspaceCString) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorLimitExceeded,
                                 PXBackupArtifactWorkspaceField,
                                 @"The workspace exceeded resource limits");
        return nil;
    }
    struct stat pathStat;
    struct stat descriptorStat;
    int descriptor = -1;
    BOOL valid = lstat(workspaceCString, &pathStat) == 0 &&
                 !S_ISLNK(pathStat.st_mode) &&
                 S_ISDIR(pathStat.st_mode);
    if (valid) {
        descriptor = open(workspaceCString,
                          O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        valid = descriptor >= 0 &&
                fstat(descriptor, &descriptorStat) == 0 &&
                S_ISDIR(descriptorStat.st_mode) &&
                (descriptorStat.st_mode & 07777) == 0700 &&
                PXBackupArtifactStatIdentityMatches(&pathStat,
                                                    &descriptorStat) &&
                PXBackupArtifactDescriptorHasCloseOnExec(descriptor);
    }
    free(workspaceCString);
    if (!valid) {
        if (descriptor >= 0) {
            close(descriptor);
        }
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorWorkspaceInspectionFailed,
                                 PXBackupArtifactWorkspaceField,
                                 @"The workspace could not be opened safely");
        return nil;
    }
    workspaceError = nil;
    if (![workspace validateIdentityWithError:&workspaceError] ||
        !PXBackupArtifactPathMatchesDirectoryDescriptor(workspacePath,
                                                        descriptor,
                                                        &descriptorStat)) {
        close(descriptor);
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorFilesystemChanged,
                                 PXBackupArtifactWorkspaceField,
                                 @"The workspace identity changed");
        return nil;
    }
    PXBackupArtifactWriter *writer =
        [[PXBackupArtifactWriter alloc] initWithWorkspace:workspace
                                           workspacePath:workspacePath
                                      workspaceDescriptor:descriptor
                                        workspaceIdentity:&descriptorStat];
    if (!writer) {
        close(descriptor);
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorWorkspaceInspectionFailed,
                                 PXBackupArtifactWorkspaceField,
                                 @"The workspace writer could not be retained");
        return nil;
    }
    return writer;
}

- (instancetype)initWithWorkspace:(PXBackupPublicationWorkspace *)workspace
                    workspacePath:(NSString *)workspacePath
               workspaceDescriptor:(int)workspaceDescriptor
                 workspaceIdentity:(const struct stat *)workspaceIdentity {
    NSMutableSet<NSString *> *acceptedPaths = [NSMutableSet set];
    NSMutableSet<NSString *> *acceptedAliases = [NSMutableSet set];
    NSMutableArray<PXVerifiedBackupArtifact *> *acceptedArtifacts =
        [NSMutableArray array];
    NSString *copiedWorkspacePath = [workspacePath copy];
    if (!acceptedPaths || !acceptedAliases || !acceptedArtifacts ||
        !copiedWorkspacePath) {
        return nil;
    }
    self = [super init];
    if (self) {
        _workspace = workspace;
        _workspacePath = copiedWorkspacePath;
        _workspaceDescriptor = workspaceDescriptor;
        _workspaceIdentity = *workspaceIdentity;
        _acceptedPaths = acceptedPaths;
        _acceptedNormalizedAliases = acceptedAliases;
        _acceptedArtifacts = acceptedArtifacts;
        _artifactCount = 0;
    }
    return self;
}

- (NSString *)workspacePath { return _workspacePath; }
- (NSUInteger)artifactCount { return _artifactCount; }

- (BOOL)validateIdentityWithError:(NSError **)error {
    if (error) {
        *error = nil;
    }
    if (!_workspace || _workspaceDescriptor < 0 ||
        ![_workspacePath isKindOfClass:[NSString class]]) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorFilesystemChanged,
                                 PXBackupArtifactWorkspaceField,
                                 @"The retained writer identity is invalid");
        return NO;
    }
    NSError *workspaceError = nil;
    if (![_workspace validateIdentityWithError:&workspaceError]) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorWorkspaceValidationFailed,
                                 PXBackupArtifactWorkspaceField,
                                 @"The workspace identity is invalid");
        return NO;
    }
    struct stat descriptorStat;
    if (fstat(_workspaceDescriptor, &descriptorStat) != 0 ||
        !S_ISDIR(descriptorStat.st_mode) ||
        (descriptorStat.st_mode & 07777) != 0700 ||
        !PXBackupArtifactStatIdentityMatches(&descriptorStat,
                                            &_workspaceIdentity) ||
        !PXBackupArtifactDescriptorHasCloseOnExec(_workspaceDescriptor) ||
        !PXBackupArtifactPathMatchesDirectoryDescriptor(_workspacePath,
                                                        _workspaceDescriptor,
                                                        &_workspaceIdentity)) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorFilesystemChanged,
                                 PXBackupArtifactWorkspaceField,
                                 @"The writer workspace identity changed");
        return NO;
    }
    for (PXVerifiedBackupArtifact *artifact in _acceptedArtifacts) {
        if (![artifact isMemberOfClass:[PXVerifiedBackupArtifact class]] ||
            !artifact.protectionVerified ||
            ![artifact validateRetainedDescriptor]) {
            PXBackupArtifactSetError(error,
                                     PXBackupArtifactWriterErrorProtectionFailed,
                                     PXBackupArtifactProtectionField,
                                     @"An accepted artifact protection invariant is invalid");
            return NO;
        }
        int namespaceDescriptor =
            PXBackupArtifactOpenRelativeFile(_workspaceDescriptor,
                                             artifact.relativePath,
                                             O_RDONLY);
        struct stat namespaceStatus;
        BOOL namespaceValid = namespaceDescriptor >= 0 &&
            PXBackupArtifactVerifyDescriptorForPolicy(namespaceDescriptor,
                                                      artifact.policy,
                                                      &namespaceStatus) &&
            PXBackupArtifactStableFileStatMatches([artifact identityPointer],
                                                  &namespaceStatus);
        if (namespaceDescriptor >= 0) close(namespaceDescriptor);
        if (!namespaceValid) {
            PXBackupArtifactSetError(error,
                                     PXBackupArtifactWriterErrorProtectionFailed,
                                     PXBackupArtifactProtectionField,
                                     @"An accepted artifact protection invariant is invalid");
            return NO;
        }
    }
    return YES;
}

- (BOOL)acceptedPathConflicts:(NSString *)relativePath {
    if ([_acceptedPaths containsObject:relativePath]) {
        return YES;
    }
    NSString *candidatePrefix = [relativePath stringByAppendingString:@"/"];
    for (NSString *accepted in _acceptedPaths) {
        if ([relativePath hasPrefix:[accepted stringByAppendingString:@"/"]] ||
            [accepted hasPrefix:candidatePrefix]) {
            return YES;
        }
    }
    NSString *precomposed = [relativePath precomposedStringWithCanonicalMapping];
    NSString *decomposed = [relativePath decomposedStringWithCanonicalMapping];
    NSString *precomposedPrefix = [precomposed stringByAppendingString:@"/"];
    NSString *decomposedPrefix = [decomposed stringByAppendingString:@"/"];
    for (NSString *acceptedAlias in _acceptedNormalizedAliases) {
        if ([acceptedAlias isEqualToString:precomposed] ||
            [acceptedAlias isEqualToString:decomposed] ||
            [precomposed hasPrefix:[acceptedAlias stringByAppendingString:@"/"]] ||
            [decomposed hasPrefix:[acceptedAlias stringByAppendingString:@"/"]] ||
            [acceptedAlias hasPrefix:precomposedPrefix] ||
            [acceptedAlias hasPrefix:decomposedPrefix]) {
            return YES;
        }
    }
    return NO;
}

- (PXBackupArtifactParentBinding *)openParentForComponents:(NSArray<NSString *> *)components
                                                     error:(NSError **)error {
    int currentDescriptor = PXBackupArtifactDuplicateDescriptor(_workspaceDescriptor);
    if (currentDescriptor < 0) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorParentInvalid,
                                 PXBackupArtifactParentField,
                                 @"The artifact parent could not be opened safely");
        return nil;
    }
    struct stat currentIdentity;
    if (fstat(currentDescriptor, &currentIdentity) != 0 ||
        !PXBackupArtifactStatIdentityMatches(&currentIdentity,
                                            &_workspaceIdentity)) {
        close(currentDescriptor);
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorFilesystemChanged,
                                 PXBackupArtifactParentField,
                                 @"The artifact parent identity changed");
        return nil;
    }
    int authorityDescriptor = -1;
    struct stat authorityIdentity;
    memset(&authorityIdentity, 0, sizeof(authorityIdentity));
    NSData *authorityComponentData = nil;
    NSString *currentPath = _workspacePath;
    NSUInteger parentCount = components.count > 0 ? components.count - 1 : 0;
    for (NSUInteger index = 0; index < parentCount; index++) {
        NSString *component = components[index];
        NSData *componentData = PXBackupArtifactLosslessUTF8Data(component);
        char *componentCString = PXBackupArtifactCopyCString(componentData);
        if (!componentCString) {
            if (authorityDescriptor >= 0) close(authorityDescriptor);
            close(currentDescriptor);
            PXBackupArtifactSetError(error,
                                     PXBackupArtifactWriterErrorLimitExceeded,
                                     PXBackupArtifactParentField,
                                     @"The artifact parent exceeded resource limits");
            return nil;
        }
        struct stat namespaceStat;
        BOOL created = NO;
        if (fstatat(currentDescriptor,
                    componentCString,
                    &namespaceStat,
                    AT_SYMLINK_NOFOLLOW) != 0) {
            if (errno != ENOENT) {
                free(componentCString);
                if (authorityDescriptor >= 0) close(authorityDescriptor);
                close(currentDescriptor);
                PXBackupArtifactSetError(error,
                                         PXBackupArtifactWriterErrorParentInvalid,
                                         PXBackupArtifactParentField,
                                         @"The artifact parent could not be inspected");
                return nil;
            }
            if (mkdirat(currentDescriptor, componentCString, 0700) != 0) {
                free(componentCString);
                if (authorityDescriptor >= 0) close(authorityDescriptor);
                close(currentDescriptor);
                PXBackupArtifactSetError(error,
                                         PXBackupArtifactWriterErrorParentCreationFailed,
                                         PXBackupArtifactParentField,
                                         @"The artifact parent could not be created");
                return nil;
            }
            created = YES;
            if (fstatat(currentDescriptor,
                        componentCString,
                        &namespaceStat,
                        AT_SYMLINK_NOFOLLOW) != 0) {
                free(componentCString);
                if (authorityDescriptor >= 0) close(authorityDescriptor);
                close(currentDescriptor);
                PXBackupArtifactSetError(error,
                                         PXBackupArtifactWriterErrorParentInvalid,
                                         PXBackupArtifactParentField,
                                         @"The artifact parent could not be inspected");
                return nil;
            }
        }
        if (!S_ISDIR(namespaceStat.st_mode) ||
            (namespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
            free(componentCString);
            if (authorityDescriptor >= 0) close(authorityDescriptor);
            close(currentDescriptor);
            PXBackupArtifactSetError(error,
                                     PXBackupArtifactWriterErrorParentInvalid,
                                     PXBackupArtifactParentField,
                                     @"The artifact parent is invalid");
            return nil;
        }
        int nextDescriptor = openat(currentDescriptor,
                                    componentCString,
                                    O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (nextDescriptor < 0) {
            free(componentCString);
            if (authorityDescriptor >= 0) close(authorityDescriptor);
            close(currentDescriptor);
            PXBackupArtifactSetError(error,
                                     PXBackupArtifactWriterErrorParentInvalid,
                                     PXBackupArtifactParentField,
                                     @"The artifact parent could not be opened safely");
            return nil;
        }
        if (created && fchmod(nextDescriptor, 0700) != 0) {
            close(nextDescriptor);
            free(componentCString);
            if (authorityDescriptor >= 0) close(authorityDescriptor);
            close(currentDescriptor);
            PXBackupArtifactSetError(error,
                                     PXBackupArtifactWriterErrorParentInvalid,
                                     PXBackupArtifactParentField,
                                     @"The artifact parent permissions could not be secured");
            return nil;
        }
        struct stat nextIdentity;
        BOOL valid = fstat(nextDescriptor, &nextIdentity) == 0 &&
                     S_ISDIR(nextIdentity.st_mode) &&
                     (nextIdentity.st_mode & (S_ISUID | S_ISGID)) == 0 &&
                     (!created || (nextIdentity.st_mode & 07777) == 0700) &&
                     nextIdentity.st_dev == _workspaceIdentity.st_dev &&
                     PXBackupArtifactStatIdentityMatches(&namespaceStat,
                                                        &nextIdentity) &&
                     PXBackupArtifactDescriptorHasCloseOnExec(nextDescriptor);
        NSString *nextPath = PXBackupArtifactAppendComponent(currentPath,
                                                             component);
        NSData *nextPathData = PXBackupArtifactLosslessUTF8Data(nextPath);
        valid = valid && nextPathData &&
                nextPathData.length <= PXBackupArtifactMaximumAbsolutePathBytes &&
                PXBackupArtifactPathMatchesDirectoryDescriptor(nextPath,
                                                               nextDescriptor,
                                                               &nextIdentity);
        if (!valid) {
            close(nextDescriptor);
            free(componentCString);
            if (authorityDescriptor >= 0) close(authorityDescriptor);
            close(currentDescriptor);
            PXBackupArtifactSetError(error,
                                     PXBackupArtifactWriterErrorFilesystemChanged,
                                     PXBackupArtifactParentField,
                                     @"The artifact parent identity changed");
            return nil;
        }
        if (authorityDescriptor >= 0) {
            close(authorityDescriptor);
        }
        authorityDescriptor = currentDescriptor;
        authorityIdentity = currentIdentity;
        authorityComponentData = componentData;
        currentDescriptor = nextDescriptor;
        currentIdentity = nextIdentity;
        currentPath = nextPath;
        free(componentCString);
    }
    PXBackupArtifactParentBinding *binding =
        [[PXBackupArtifactParentBinding alloc] init];
    if (!binding) {
        if (authorityDescriptor >= 0) close(authorityDescriptor);
        close(currentDescriptor);
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorLimitExceeded,
                                 PXBackupArtifactParentField,
                                 @"The artifact parent exceeded resource limits");
        return nil;
    }
    binding.descriptor = currentDescriptor;
    binding.authorityDescriptor = authorityDescriptor;
    binding.authorityComponentData = authorityComponentData;
    binding.path = currentPath;
    binding.identity = currentIdentity;
    binding.authorityIdentity = authorityIdentity;
    binding.workspaceRoot = parentCount == 0;
    return binding;
}

- (BOOL)validateParentBinding:(PXBackupArtifactParentBinding *)parent
                        error:(NSError **)error {
    if (!parent ||
        !PXBackupArtifactDirectoryIdentityValid(parent.descriptor,
                                                [parent identityPointer],
                                                _workspaceIdentity.st_dev,
                                                NO) ||
        !PXBackupArtifactPathMatchesDirectoryDescriptor(parent.path,
                                                        parent.descriptor,
                                                        [parent identityPointer])) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorFilesystemChanged,
                                 PXBackupArtifactParentField,
                                 @"The artifact parent identity changed");
        return NO;
    }
    if (parent.workspaceRoot) {
        if (!PXBackupArtifactStatIdentityMatches([parent identityPointer],
                                                &_workspaceIdentity)) {
            PXBackupArtifactSetError(error,
                                     PXBackupArtifactWriterErrorFilesystemChanged,
                                     PXBackupArtifactParentField,
                                     @"The artifact parent identity changed");
            return NO;
        }
        return YES;
    }
    char *componentCString =
        PXBackupArtifactCopyCString(parent.authorityComponentData);
    struct stat namespaceStat;
    BOOL valid = componentCString && parent.authorityDescriptor >= 0 &&
                 PXBackupArtifactDirectoryIdentityValid(parent.authorityDescriptor,
                                                         [parent authorityIdentityPointer],
                                                         _workspaceIdentity.st_dev,
                                                         NO) &&
                 fstatat(parent.authorityDescriptor,
                         componentCString,
                         &namespaceStat,
                         AT_SYMLINK_NOFOLLOW) == 0 &&
                 S_ISDIR(namespaceStat.st_mode) &&
                 PXBackupArtifactStatIdentityMatches(&namespaceStat,
                                                     [parent identityPointer]);
    free(componentCString);
    if (!valid) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorFilesystemChanged,
                                 PXBackupArtifactParentField,
                                 @"The artifact parent namespace changed");
        return NO;
    }
    return YES;
}

- (PXBackupArtifactTemporaryBinding *)createTemporaryUnderParent:(PXBackupArtifactParentBinding *)parent
                                                           error:(NSError **)error {
    NSString *templateName = [[NSString alloc]
        initWithBytes:PXBackupArtifactTemporaryTemplate
               length:strlen(PXBackupArtifactTemporaryTemplate)
             encoding:NSASCIIStringEncoding];
    NSString *templatePath = templateName
        ? PXBackupArtifactAppendComponent(parent.path, templateName)
        : nil;
    NSData *templateData = PXBackupArtifactLosslessUTF8Data(templatePath);
    if (!templateData ||
        templateData.length > PXBackupArtifactMaximumAbsolutePathBytes) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorLimitExceeded,
                                 PXBackupArtifactTemporaryField,
                                 @"The temporary artifact path exceeded resource limits");
        return nil;
    }
    char *templateCString = PXBackupArtifactCopyCString(templateData);
    if (!templateCString) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorLimitExceeded,
                                 PXBackupArtifactTemporaryField,
                                 @"The temporary artifact path exceeded resource limits");
        return nil;
    }
    char *createdCString = mkdtemp(templateCString);
    if (!createdCString) {
        free(templateCString);
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorTemporaryCreationFailed,
                                 PXBackupArtifactTemporaryField,
                                 @"The temporary artifact directory could not be created");
        return nil;
    }
    const char *nameCString = strrchr(createdCString, '/');
    nameCString = nameCString ? nameCString + 1 : createdCString;
    struct stat createdIdentity;
    BOOL createdIdentityKnown =
        lstat(createdCString, &createdIdentity) == 0 &&
        !S_ISLNK(createdIdentity.st_mode) &&
        S_ISDIR(createdIdentity.st_mode);
    size_t nameLength = strlen(nameCString);
    NSString *name = [[NSString alloc] initWithBytes:nameCString
                                              length:nameLength
                                            encoding:NSUTF8StringEncoding];
    NSData *nameData = nil;
    NSString *createdPath = [[NSString alloc]
        initWithBytes:createdCString
               length:strlen(createdCString)
             encoding:NSUTF8StringEncoding];
    NSData *createdPathData = PXBackupArtifactLosslessUTF8Data(createdPath);
    BOOL validName = PXBackupArtifactValidateTemporaryComponent(name,
                                                                &nameData) &&
                     createdPathData &&
                     createdPathData.length <=
                         PXBackupArtifactMaximumAbsolutePathBytes &&
                     [createdPath isEqualToString:
                         PXBackupArtifactAppendComponent(parent.path, name)];
    if (!validName) {
        BOOL cleanupSucceeded = createdIdentityKnown &&
            PXBackupArtifactRemoveCreatedEmptyDirectoryIfSafe(
                parent.descriptor,
                nameCString,
                &createdIdentity,
                _workspaceIdentity.st_dev);
        free(templateCString);
        PXBackupArtifactSetError(error,
                                 cleanupSucceeded
                                     ? PXBackupArtifactWriterErrorTemporaryCreationFailed
                                     : PXBackupArtifactWriterErrorCleanupFailed,
                                 PXBackupArtifactTemporaryField,
                                 cleanupSucceeded
                                     ? @"The temporary artifact directory name is invalid"
                                     : @"Owned temporary artifact state could not be cleaned safely");
        return nil;
    }
    struct stat pathStat = createdIdentity;
    struct stat namespaceStat;
    struct stat descriptorStat;
    int descriptor = -1;
    BOOL valid = createdIdentityKnown &&
                 fstatat(parent.descriptor,
                         nameCString,
                         &namespaceStat,
                         AT_SYMLINK_NOFOLLOW) == 0 &&
                 S_ISDIR(namespaceStat.st_mode) &&
                 PXBackupArtifactStatIdentityMatches(&pathStat,
                                                     &namespaceStat);
    if (valid) {
        descriptor = openat(parent.descriptor,
                            nameCString,
                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        valid = descriptor >= 0 &&
                fchmod(descriptor, 0700) == 0 &&
                fstat(descriptor, &descriptorStat) == 0 &&
                S_ISDIR(descriptorStat.st_mode) &&
                (descriptorStat.st_mode & 07777) == 0700 &&
                descriptorStat.st_dev == _workspaceIdentity.st_dev &&
                PXBackupArtifactStatIdentityMatches(&pathStat,
                                                    &descriptorStat) &&
                PXBackupArtifactStatIdentityMatches(&namespaceStat,
                                                    &descriptorStat) &&
                PXBackupArtifactDescriptorHasCloseOnExec(descriptor);
    }
    NSArray<NSString *> *initialEntries = nil;
    valid = valid &&
            PXBackupArtifactDirectoryEntries(descriptor,
                                             PXBackupArtifactTemporaryOperationalEntries,
                                             &initialEntries) &&
            initialEntries.count == 0;
    if (!valid) {
        if (descriptor >= 0) close(descriptor);
        BOOL cleanupSucceeded = createdIdentityKnown &&
            PXBackupArtifactRemoveCreatedEmptyDirectoryIfSafe(
                parent.descriptor,
                nameCString,
                &createdIdentity,
                _workspaceIdentity.st_dev);
        free(templateCString);
        PXBackupArtifactSetError(error,
                                 cleanupSucceeded
                                     ? PXBackupArtifactWriterErrorTemporaryCreationFailed
                                     : PXBackupArtifactWriterErrorCleanupFailed,
                                 PXBackupArtifactTemporaryField,
                                 cleanupSucceeded
                                     ? @"The temporary artifact directory is invalid"
                                     : @"Owned temporary artifact state could not be cleaned safely");
        return nil;
    }
    PXBackupArtifactTemporaryBinding *binding =
        [[PXBackupArtifactTemporaryBinding alloc] init];
    if (!binding) {
        close(descriptor);
        BOOL cleanupSucceeded =
            PXBackupArtifactRemoveCreatedEmptyDirectoryIfSafe(
                parent.descriptor,
                nameCString,
                &createdIdentity,
                _workspaceIdentity.st_dev);
        free(templateCString);
        PXBackupArtifactSetError(error,
                                 cleanupSucceeded
                                     ? PXBackupArtifactWriterErrorLimitExceeded
                                     : PXBackupArtifactWriterErrorCleanupFailed,
                                 PXBackupArtifactTemporaryField,
                                 cleanupSucceeded
                                     ? @"The temporary artifact binding exceeded resource limits"
                                     : @"Owned temporary artifact state could not be cleaned safely");
        return nil;
    }
    free(templateCString);
    binding.descriptor = descriptor;
    binding.path = createdPath;
    binding.name = name;
    binding.nameData = nameData;
    binding.identity = descriptorStat;
    return binding;
}

- (BOOL)validateTemporaryBinding:(PXBackupArtifactTemporaryBinding *)temporary
                          parent:(PXBackupArtifactParentBinding *)parent {
    char *nameCString = PXBackupArtifactCopyCString(temporary.nameData);
    struct stat namespaceStat;
    BOOL valid = temporary && nameCString &&
                 PXBackupArtifactDirectoryIdentityValid(temporary.descriptor,
                                                         [temporary identityPointer],
                                                         _workspaceIdentity.st_dev,
                                                         YES) &&
                 fstatat(parent.descriptor,
                         nameCString,
                         &namespaceStat,
                         AT_SYMLINK_NOFOLLOW) == 0 &&
                 S_ISDIR(namespaceStat.st_mode) &&
                 PXBackupArtifactStatIdentityMatches(&namespaceStat,
                                                     [temporary identityPointer]) &&
                 PXBackupArtifactPathMatchesDirectoryDescriptor(temporary.path,
                                                                temporary.descriptor,
                                                                [temporary identityPointer]);
    free(nameCString);
    return valid;
}

- (BOOL)cleanupParent:(PXBackupArtifactParentBinding *)parent
             temporary:(PXBackupArtifactTemporaryBinding *)temporary
        payloadIdentity:(const struct stat *)payloadIdentity
           finalNameData:(NSData *)finalNameData
            finalRenamed:(BOOL)finalRenamed
        temporaryRemoved:(BOOL)temporaryRemoved {
    BOOL safe = YES;
    if (finalRenamed && payloadIdentity && finalNameData) {
        char *finalNameCString = PXBackupArtifactCopyCString(finalNameData);
        struct stat finalStat;
        if (!finalNameCString ||
            fstatat(parent.descriptor,
                    finalNameCString,
                    &finalStat,
                    AT_SYMLINK_NOFOLLOW) != 0 ||
            !S_ISREG(finalStat.st_mode) ||
            finalStat.st_nlink != 1 ||
            (finalStat.st_mode & 07777) != 0600 ||
            finalStat.st_dev != _workspaceIdentity.st_dev ||
            !PXBackupArtifactStatIdentityMatches(&finalStat,
                                                payloadIdentity) ||
            unlinkat(parent.descriptor, finalNameCString, 0) != 0 ||
            !PXBackupArtifactStrictSync(parent.descriptor)) {
            safe = NO;
        }
        free(finalNameCString);
    }
    if (!temporaryRemoved && temporary) {
        NSArray<NSString *> *entries = nil;
        if (!PXBackupArtifactDirectoryEntries(temporary.descriptor,
                                              PXBackupArtifactFailureCleanupEntries,
                                              &entries)) {
            safe = NO;
        } else {
            for (NSString *entryName in entries) {
                if (![entryName isEqualToString:@"payload"]) {
                    safe = NO;
                    continue;
                }
                struct stat namespaceStat;
                if (fstatat(temporary.descriptor,
                            PXBackupArtifactPayloadName,
                            &namespaceStat,
                            AT_SYMLINK_NOFOLLOW) != 0 ||
                    !S_ISREG(namespaceStat.st_mode) ||
                    namespaceStat.st_nlink != 1 ||
                    namespaceStat.st_dev != _workspaceIdentity.st_dev ||
                    (payloadIdentity &&
                     !PXBackupArtifactStatIdentityMatches(&namespaceStat,
                                                         payloadIdentity))) {
                    safe = NO;
                    continue;
                }
                int descriptor = openat(temporary.descriptor,
                                        PXBackupArtifactPayloadName,
                                        O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
                struct stat descriptorStat;
                BOOL exact = descriptor >= 0 &&
                             fstat(descriptor, &descriptorStat) == 0 &&
                             S_ISREG(descriptorStat.st_mode) &&
                             descriptorStat.st_nlink == 1 &&
                             descriptorStat.st_dev == _workspaceIdentity.st_dev &&
                             PXBackupArtifactStatIdentityMatches(&namespaceStat,
                                                                &descriptorStat) &&
                             (!payloadIdentity ||
                              PXBackupArtifactStatIdentityMatches(payloadIdentity,
                                                                  &descriptorStat));
                if (descriptor >= 0) close(descriptor);
                if (!exact ||
                    unlinkat(temporary.descriptor,
                             PXBackupArtifactPayloadName,
                             0) != 0) {
                    safe = NO;
                }
            }
        }
        NSArray<NSString *> *remaining = nil;
        char *temporaryNameCString =
            PXBackupArtifactCopyCString(temporary.nameData);
        struct stat temporaryNamespaceStat;
        BOOL removable = temporaryNameCString &&
                         PXBackupArtifactDirectoryEntries(temporary.descriptor,
                                                          1,
                                                          &remaining) &&
                         remaining.count == 0 &&
                         fstatat(parent.descriptor,
                                 temporaryNameCString,
                                 &temporaryNamespaceStat,
                                 AT_SYMLINK_NOFOLLOW) == 0 &&
                         S_ISDIR(temporaryNamespaceStat.st_mode) &&
                         PXBackupArtifactStatIdentityMatches(&temporaryNamespaceStat,
                                                            [temporary identityPointer]) &&
                         unlinkat(parent.descriptor,
                                  temporaryNameCString,
                                  AT_REMOVEDIR) == 0 &&
                         PXBackupArtifactStrictSync(parent.descriptor);
        free(temporaryNameCString);
        if (!removable) {
            safe = NO;
        }
    }
    return safe;
}

- (nullable PXVerifiedBackupArtifact *)writeArtifactAtRelativePath:(NSString *)relativePath
                                                            policy:(PXBackupArtifactPolicy *)policy
                                                          producer:(PXBackupArtifactProducer)producer
                                                             error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    PXBackupArtifactPolicy *canonicalPolicy =
        [policy isMemberOfClass:[PXBackupArtifactPolicy class]]
            ? [PXBackupArtifactPolicy policyForKind:policy.kind]
            : nil;
    if (!canonicalPolicy || ![policy isEqual:canonicalPolicy] ||
        policy.requiredPOSIXMode != 0600 ||
        (policy.dataProtectionRequirement !=
             PXBackupArtifactDataProtectionRequirementUnspecified &&
         policy.dataProtectionRequirement !=
             PXBackupArtifactDataProtectionRequirementComplete)) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorInvalidInput,
                                 PXBackupArtifactPolicyField,
                                 @"The artifact policy is invalid");
        return nil;
    }
    if (!producer) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorInvalidInput,
                                 PXBackupArtifactField,
                                 @"The artifact producer is invalid");
        return nil;
    }
    BOOL limitExceeded = NO;
    NSArray<NSString *> *components =
        PXBackupArtifactValidateRelativePath(relativePath, &limitExceeded);
    if (!components) {
        PXBackupArtifactSetError(error,
                                 limitExceeded
                                     ? PXBackupArtifactWriterErrorLimitExceeded
                                     : PXBackupArtifactWriterErrorInvalidInput,
                                 PXBackupArtifactRelativePathField,
                                 @"The artifact relative path is invalid");
        return nil;
    }
    if (_artifactCount >= PXBackupArtifactMaximumArtifacts) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorLimitExceeded,
                                 PXBackupArtifactField,
                                 @"The artifact count exceeded resource limits");
        return nil;
    }
    if ([self acceptedPathConflicts:relativePath]) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorDuplicateArtifact,
                                 PXBackupArtifactRelativePathField,
                                 @"The artifact path conflicts with an accepted artifact");
        return nil;
    }
    NSString *finalFilePath = PXBackupArtifactAppendComponent(_workspacePath,
                                                              relativePath);
    NSData *finalFilePathData = PXBackupArtifactLosslessUTF8Data(finalFilePath);
    if (!finalFilePathData ||
        finalFilePathData.length > PXBackupArtifactMaximumAbsolutePathBytes) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorLimitExceeded,
                                 PXBackupArtifactField,
                                 @"The finalized artifact path exceeded resource limits");
        return nil;
    }
    NSError *identityError = nil;
    if (![self validateIdentityWithError:&identityError]) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorWorkspaceValidationFailed,
                                 PXBackupArtifactWorkspaceField,
                                 @"The writer workspace identity is invalid");
        return nil;
    }
    NSError *operationError = nil;
    PXBackupArtifactParentBinding *parent =
        [self openParentForComponents:components error:&operationError];
    if (!parent) {
        if (error) *error = operationError;
        return nil;
    }
    NSString *finalComponent = components.lastObject;
    NSData *finalNameData = PXBackupArtifactLosslessUTF8Data(finalComponent);
    char *finalNameCString = PXBackupArtifactCopyCString(finalNameData);
    if (!finalNameCString) {
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorLimitExceeded,
                                 PXBackupArtifactRelativePathField,
                                 @"The artifact name exceeded resource limits");
        return nil;
    }
    struct stat existingFinalStat;
    if (fstatat(parent.descriptor,
                finalNameCString,
                &existingFinalStat,
                AT_SYMLINK_NOFOLLOW) == 0 ||
        errno != ENOENT) {
        free(finalNameCString);
        PXBackupArtifactSetError(error,
                                 PXBackupArtifactWriterErrorDuplicateArtifact,
                                 PXBackupArtifactRelativePathField,
                                 @"The final artifact already exists");
        return nil;
    }
    PXBackupArtifactTemporaryBinding *temporary =
        [self createTemporaryUnderParent:parent error:&operationError];
    if (!temporary) {
        free(finalNameCString);
        if (error) *error = operationError;
        return nil;
    }
    struct stat payloadIdentity;
    memset(&payloadIdentity, 0, sizeof(payloadIdentity));
    BOOL payloadIdentityKnown = NO;
    BOOL finalRenamed = NO;
    BOOL temporaryRemoved = NO;
    int payloadDescriptor = -1;
    int retainedArtifactDescriptor = -1;
    NSString *digestString = nil;
    unsigned long long streamedBytes = 0;
    PXVerifiedBackupArtifact *record = nil;

    do {
        struct stat preProducerPayloadStat;
        if (fstatat(temporary.descriptor,
                    PXBackupArtifactPayloadName,
                    &preProducerPayloadStat,
                    AT_SYMLINK_NOFOLLOW) == 0 ||
            errno != ENOENT) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorOutputInvalid,
                                     PXBackupArtifactPayloadField,
                                     @"The producer output location is not empty");
            break;
        }
        NSString *payloadPath = PXBackupArtifactAppendComponent(temporary.path,
                                                                @"payload");
        NSData *payloadPathData = PXBackupArtifactLosslessUTF8Data(payloadPath);
        if (!payloadPathData ||
            payloadPathData.length > PXBackupArtifactMaximumAbsolutePathBytes) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorLimitExceeded,
                                     PXBackupArtifactPayloadField,
                                     @"The producer output path exceeded resource limits");
            break;
        }
        BOOL producerSucceeded = producer(payloadPath);
        if (!producerSucceeded) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorProducerFailed,
                                     PXBackupArtifactPayloadField,
                                     @"The artifact producer failed");
            break;
        }
        NSArray<NSString *> *temporaryEntries = nil;
        if (!PXBackupArtifactDirectoryEntries(temporary.descriptor,
                                              PXBackupArtifactTemporaryOperationalEntries + 1,
                                              &temporaryEntries)) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorWorkspaceInspectionFailed,
                                     PXBackupArtifactTemporaryField,
                                     @"The temporary artifact directory could not be inspected");
            break;
        }
        if (temporaryEntries.count == 0) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorOutputMissing,
                                     PXBackupArtifactPayloadField,
                                     @"The producer output is missing");
            break;
        }
        if (temporaryEntries.count != 1 ||
            ![temporaryEntries.firstObject isEqualToString:@"payload"]) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorOutputInvalid,
                                     PXBackupArtifactTemporaryField,
                                     @"The producer created unexpected temporary output");
            break;
        }
        struct stat payloadNamespaceStat;
        if (fstatat(temporary.descriptor,
                    PXBackupArtifactPayloadName,
                    &payloadNamespaceStat,
                    AT_SYMLINK_NOFOLLOW) != 0) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorOutputMissing,
                                     PXBackupArtifactPayloadField,
                                     @"The producer output is missing");
            break;
        }
        if (!S_ISREG(payloadNamespaceStat.st_mode) ||
            payloadNamespaceStat.st_nlink != 1 ||
            (payloadNamespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
            payloadNamespaceStat.st_dev != _workspaceIdentity.st_dev ||
            payloadNamespaceStat.st_size < 0 ||
            (unsigned long long)payloadNamespaceStat.st_size >
                PXBackupArtifactMaximumFileBytes) {
            PXBackupArtifactSetError(&operationError,
                                     (payloadNamespaceStat.st_size >= 0 &&
                                      (unsigned long long)payloadNamespaceStat.st_size >
                                          PXBackupArtifactMaximumFileBytes)
                                         ? PXBackupArtifactWriterErrorLimitExceeded
                                         : PXBackupArtifactWriterErrorOutputInvalid,
                                     PXBackupArtifactPayloadField,
                                     @"The producer output is invalid");
            break;
        }
        int payloadAccessMode =
            policy.dataProtectionRequirement ==
                    PXBackupArtifactDataProtectionRequirementComplete
                ? O_RDWR
                : O_RDONLY;
        payloadDescriptor = openat(temporary.descriptor,
                                   PXBackupArtifactPayloadName,
                                   payloadAccessMode | O_NONBLOCK |
                                       O_NOFOLLOW | O_CLOEXEC);
        if (payloadDescriptor < 0) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorOutputInvalid,
                                     PXBackupArtifactPayloadField,
                                     @"The producer output could not be opened safely");
            break;
        }
        struct stat preProtectionStatus;
        if (fstat(payloadDescriptor, &preProtectionStatus) != 0 ||
            !S_ISREG(preProtectionStatus.st_mode) ||
            preProtectionStatus.st_nlink != 1 ||
            preProtectionStatus.st_uid != geteuid() ||
            preProtectionStatus.st_gid != getegid() ||
            (preProtectionStatus.st_mode & (S_ISUID | S_ISGID)) != 0 ||
            preProtectionStatus.st_dev != _workspaceIdentity.st_dev ||
            preProtectionStatus.st_size < 0 ||
            (unsigned long long)preProtectionStatus.st_size >
                PXBackupArtifactMaximumFileBytes ||
            !PXBackupArtifactStatIdentityMatches(&payloadNamespaceStat,
                                                &preProtectionStatus) ||
            !PXBackupArtifactDescriptorHasCloseOnExec(payloadDescriptor)) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorOutputInvalid,
                                     PXBackupArtifactPayloadField,
                                     @"The producer output is invalid");
            break;
        }
        BOOL protectionApplied = NO;
        if (policy.dataProtectionRequirement ==
            PXBackupArtifactDataProtectionRequirementComplete) {
            protectionApplied =
                PXApplyCompleteFileProtectionToDescriptor(payloadDescriptor, NULL);
        } else {
            protectionApplied =
                PXBackupArtifactSetMode(payloadDescriptor,
                                        (mode_t)policy.requiredPOSIXMode);
        }
        if (!protectionApplied ||
            !PXBackupArtifactVerifyDescriptorForPolicy(payloadDescriptor,
                                                       policy,
                                                       &payloadIdentity) ||
            payloadIdentity.st_dev != _workspaceIdentity.st_dev ||
            payloadIdentity.st_size < 0 ||
            (unsigned long long)payloadIdentity.st_size >
                PXBackupArtifactMaximumFileBytes ||
            !PXBackupArtifactStatIdentityMatches(&preProtectionStatus,
                                                &payloadIdentity) ||
            preProtectionStatus.st_size != payloadIdentity.st_size) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorProtectionFailed,
                                     PXBackupArtifactProtectionField,
                                     @"The artifact protection policy could not be enforced");
            break;
        }
        payloadIdentityKnown = YES;
        CC_SHA256_CTX digestContext;
        CC_SHA256_Init(&digestContext);
        unsigned char *buffer = malloc(PXBackupArtifactStreamBufferBytes);
        if (!buffer) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorLimitExceeded,
                                     PXBackupArtifactPayloadField,
                                     @"The artifact stream exceeded resource limits");
            break;
        }
        BOOL readSucceeded = YES;
        for (;;) {
            ssize_t count = read(payloadDescriptor,
                                 buffer,
                                 PXBackupArtifactStreamBufferBytes);
            if (count < 0 && errno == EINTR) {
                continue;
            }
            if (count < 0) {
                readSucceeded = NO;
                break;
            }
            if (count == 0) {
                break;
            }
            unsigned long long unsignedCount = (unsigned long long)count;
            if (streamedBytes > ULLONG_MAX - unsignedCount ||
                streamedBytes + unsignedCount > PXBackupArtifactMaximumFileBytes) {
                readSucceeded = NO;
                limitExceeded = YES;
                break;
            }
            CC_SHA256_Update(&digestContext, buffer, (CC_LONG)count);
            streamedBytes += unsignedCount;
        }
        free(buffer);
        if (!readSucceeded ||
            streamedBytes != (unsigned long long)payloadIdentity.st_size) {
            PXBackupArtifactSetError(&operationError,
                                     limitExceeded
                                         ? PXBackupArtifactWriterErrorLimitExceeded
                                         : PXBackupArtifactWriterErrorReadFailed,
                                     PXBackupArtifactPayloadField,
                                     @"The artifact could not be read completely");
            break;
        }
        struct stat afterReadStat;
        if (fstat(payloadDescriptor, &afterReadStat) != 0 ||
            !PXBackupArtifactStableFileStatMatches(&payloadIdentity,
                                                   &afterReadStat)) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorFilesystemChanged,
                                     PXBackupArtifactPayloadField,
                                     @"The artifact changed while being verified");
            break;
        }
        unsigned char digest[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256_Final(digest, &digestContext);
        digestString = PXBackupArtifactHexDigest(digest,
                                                CC_SHA256_DIGEST_LENGTH);
        if (!digestString || digestString.length != 64) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorReadFailed,
                                     PXBackupArtifactPayloadField,
                                     @"The artifact digest could not be finalized");
            break;
        }
        if (![policy acceptsFileSize:streamedBytes]) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorPolicyRejected,
                                     PXBackupArtifactPolicyField,
                                     @"The artifact output was rejected by policy");
            break;
        }
        if (!PXBackupArtifactStrictSync(payloadDescriptor)) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorDurabilityFailed,
                                     PXBackupArtifactPayloadField,
                                     @"The artifact could not be synchronized");
            break;
        }
        identityError = nil;
        if (![self validateIdentityWithError:&identityError] ||
            ![self validateParentBinding:parent error:&operationError] ||
            ![self validateTemporaryBinding:temporary parent:parent]) {
            if (!operationError) {
                PXBackupArtifactSetError(&operationError,
                                         PXBackupArtifactWriterErrorFilesystemChanged,
                                         PXBackupArtifactTemporaryField,
                                         @"The artifact namespace changed before finalization");
            }
            break;
        }
        struct stat payloadNamespaceRevalidation;
        struct stat preRenameDescriptorStat;
        if (!PXBackupArtifactVerifyDescriptorForPolicy(payloadDescriptor,
                                                       policy,
                                                       &preRenameDescriptorStat) ||
            !PXBackupArtifactStableFileStatMatches(&payloadIdentity,
                                                   &preRenameDescriptorStat) ||
            fstatat(temporary.descriptor,
                    PXBackupArtifactPayloadName,
                    &payloadNamespaceRevalidation,
                    AT_SYMLINK_NOFOLLOW) != 0 ||
            !S_ISREG(payloadNamespaceRevalidation.st_mode) ||
            payloadNamespaceRevalidation.st_nlink != 1 ||
            payloadNamespaceRevalidation.st_uid != geteuid() ||
            payloadNamespaceRevalidation.st_gid != getegid() ||
            (payloadNamespaceRevalidation.st_mode & 07777) !=
                (mode_t)policy.requiredPOSIXMode ||
            !PXBackupArtifactStatIdentityMatches(&payloadNamespaceRevalidation,
                                                &payloadIdentity) ||
            fstatat(parent.descriptor,
                    finalNameCString,
                    &existingFinalStat,
                    AT_SYMLINK_NOFOLLOW) == 0 ||
            errno != ENOENT) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorFilesystemChanged,
                                     PXBackupArtifactPayloadField,
                                     @"The artifact namespace changed before finalization");
            break;
        }
        if (renameat(temporary.descriptor,
                     PXBackupArtifactPayloadName,
                     parent.descriptor,
                     finalNameCString) != 0) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorFinalizationFailed,
                                     PXBackupArtifactField,
                                     @"The artifact could not be finalized");
            break;
        }
        finalRenamed = YES;
        struct stat finalNamespaceStat;
        if (fstatat(parent.descriptor,
                    finalNameCString,
                    &finalNamespaceStat,
                    AT_SYMLINK_NOFOLLOW) != 0 ||
            !S_ISREG(finalNamespaceStat.st_mode) ||
            finalNamespaceStat.st_nlink != 1 ||
            finalNamespaceStat.st_uid != geteuid() ||
            finalNamespaceStat.st_gid != getegid() ||
            (finalNamespaceStat.st_mode & 07777) !=
                (mode_t)policy.requiredPOSIXMode ||
            finalNamespaceStat.st_dev != _workspaceIdentity.st_dev ||
            !PXBackupArtifactStatIdentityMatches(&finalNamespaceStat,
                                                &payloadIdentity)) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorFilesystemChanged,
                                     PXBackupArtifactField,
                                     @"The finalized artifact identity is invalid");
            break;
        }
        if (!PXBackupArtifactVerifyDescriptorForPolicy(payloadDescriptor,
                                                       policy,
                                                       NULL)) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorProtectionFailed,
                                     PXBackupArtifactProtectionField,
                                     @"The finalized artifact protection is invalid");
            break;
        }
        int finalizedDescriptor = openat(parent.descriptor,
                                         finalNameCString,
                                         O_RDONLY | O_NONBLOCK |
                                             O_NOFOLLOW | O_CLOEXEC);
        struct stat finalizedDescriptorStat;
        BOOL finalizedProtectionValid = finalizedDescriptor >= 0 &&
            PXBackupArtifactVerifyDescriptorForPolicy(finalizedDescriptor,
                                                      policy,
                                                      &finalizedDescriptorStat) &&
            PXBackupArtifactStatIdentityMatches(&payloadIdentity,
                                                &finalizedDescriptorStat) &&
            payloadIdentity.st_size == finalizedDescriptorStat.st_size;
        if (finalizedDescriptor >= 0) close(finalizedDescriptor);
        if (!finalizedProtectionValid) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorProtectionFailed,
                                     PXBackupArtifactProtectionField,
                                     @"The finalized artifact protection is invalid");
            break;
        }
        payloadIdentity = finalizedDescriptorStat;
        retainedArtifactDescriptor =
            PXBackupArtifactDuplicateDescriptor(payloadDescriptor);
        if (retainedArtifactDescriptor < 0) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorProtectionFailed,
                                     PXBackupArtifactProtectionField,
                                     @"The finalized artifact protection authority could not be retained");
            break;
        }
        if (!PXBackupArtifactStrictSync(parent.descriptor)) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorDurabilityFailed,
                                     PXBackupArtifactParentField,
                                     @"The artifact parent could not be synchronized");
            break;
        }
        NSArray<NSString *> *remainingEntries = nil;
        char *temporaryNameCString =
            PXBackupArtifactCopyCString(temporary.nameData);
        struct stat temporaryNamespaceStat;
        BOOL removed = temporaryNameCString &&
                       PXBackupArtifactDirectoryEntries(temporary.descriptor,
                                                        1,
                                                        &remainingEntries) &&
                       remainingEntries.count == 0 &&
                       fstatat(parent.descriptor,
                               temporaryNameCString,
                               &temporaryNamespaceStat,
                               AT_SYMLINK_NOFOLLOW) == 0 &&
                       S_ISDIR(temporaryNamespaceStat.st_mode) &&
                       PXBackupArtifactStatIdentityMatches(&temporaryNamespaceStat,
                                                          [temporary identityPointer]) &&
                       unlinkat(parent.descriptor,
                                temporaryNameCString,
                                AT_REMOVEDIR) == 0;
        free(temporaryNameCString);
        if (!removed) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorCleanupFailed,
                                     PXBackupArtifactTemporaryField,
                                     @"The temporary artifact directory could not be removed safely");
            break;
        }
        temporaryRemoved = YES;
        if (!PXBackupArtifactStrictSync(parent.descriptor)) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorDurabilityFailed,
                                     PXBackupArtifactParentField,
                                     @"The artifact parent could not be synchronized");
            break;
        }
        identityError = nil;
        if (![self validateIdentityWithError:&identityError] ||
            ![self validateParentBinding:parent error:&operationError]) {
            if (!operationError) {
                PXBackupArtifactSetError(&operationError,
                                         PXBackupArtifactWriterErrorFilesystemChanged,
                                         PXBackupArtifactWorkspaceField,
                                         @"The writer identity changed after finalization");
            }
            break;
        }
        record = [[PXVerifiedBackupArtifact alloc]
            initWithRelativePath:relativePath
                        filePath:finalFilePath
                            size:streamedBytes
                          sha256:digestString
                          policy:policy
                      descriptor:retainedArtifactDescriptor
                        identity:&payloadIdentity];
        retainedArtifactDescriptor = -1;
        if (!record) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorFinalizationFailed,
                                     PXBackupArtifactField,
                                     @"The verified artifact record could not be retained");
            break;
        }
    } while (0);

    if (payloadDescriptor >= 0) {
        close(payloadDescriptor);
        payloadDescriptor = -1;
    }
    if (!record && retainedArtifactDescriptor >= 0) {
        close(retainedArtifactDescriptor);
        retainedArtifactDescriptor = -1;
    }
    if (!record) {
        BOOL cleanupSucceeded =
            [self cleanupParent:parent
                       temporary:temporary
                  payloadIdentity:payloadIdentityKnown ? &payloadIdentity : NULL
                     finalNameData:finalNameData
                      finalRenamed:finalRenamed
                  temporaryRemoved:temporaryRemoved];
        if (!cleanupSucceeded) {
            PXBackupArtifactSetError(&operationError,
                                     PXBackupArtifactWriterErrorCleanupFailed,
                                     PXBackupArtifactField,
                                     @"Owned artifact state could not be cleaned safely");
        }
        free(finalNameCString);
        if (error) {
            *error = operationError ?: [NSError errorWithDomain:PXBackupArtifactWriterErrorDomain
                                                            code:PXBackupArtifactWriterErrorFinalizationFailed
                                                        userInfo:@{
                                                            NSLocalizedDescriptionKey: @"The artifact operation failed",
                                                            PXBackupArtifactWriterErrorFieldPathKey: PXBackupArtifactField,
                                                        }];
        }
        return nil;
    }
    [_acceptedPaths addObject:[relativePath copy]];
    [_acceptedNormalizedAliases addObject:
        [relativePath precomposedStringWithCanonicalMapping]];
    [_acceptedNormalizedAliases addObject:
        [relativePath decomposedStringWithCanonicalMapping]];
    [_acceptedArtifacts addObject:record];
    _artifactCount += 1;
    free(finalNameCString);
    return record;
}

- (void)dealloc {
    if (_workspaceDescriptor >= 0) {
        close(_workspaceDescriptor);
        _workspaceDescriptor = -1;
    }
}

@end
