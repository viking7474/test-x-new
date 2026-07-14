#import "PXOptionalRestoreStaging.h"
#import "PXRestorePlan.h"
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

#ifndef O_DIRECTORY
#define O_DIRECTORY 0
#endif
#ifndef O_NOFOLLOW
#define O_NOFOLLOW 0
#endif
#ifndef O_CLOEXEC
#define O_CLOEXEC 0
#endif
#ifndef O_NONBLOCK
#define O_NONBLOCK 0
#endif
#ifndef AT_SYMLINK_NOFOLLOW
#define AT_SYMLINK_NOFOLLOW 0
#endif
#ifndef AT_REMOVEDIR
#define AT_REMOVEDIR 0
#endif

NSString * const PXOptionalRestoreStagingErrorDomain =
    @"com.hydra.projectx.optional-restore-staging";
NSString * const PXOptionalRestoreStagingErrorFieldPathKey =
    @"PXOptionalRestoreStagingErrorFieldPathKey";

static const NSUInteger PXOptionalMaximumTarDirectoryItems = 1024;
static const NSUInteger PXOptionalMaximumFileItems = 4096;
static const NSUInteger PXOptionalMaximumTotalItems = 4096;
static const unsigned long long PXOptionalMaximumFileBytes = 64ULL * 1024ULL * 1024ULL * 1024ULL;
static const NSUInteger PXOptionalMaximumPathBytes = 4096;
static const NSUInteger PXOptionalMaximumComponentBytes = 255;
static const NSUInteger PXOptionalMaximumCleanupEntries = 8;
static const size_t PXOptionalStreamBufferSize = 64 * 1024;

static id PXOptionalFailObject(NSError **error,
                               PXOptionalRestoreStagingErrorCode code,
                               NSString *fieldPath,
                               NSString *description) {
    if (error) {
        *error = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                     code:code
                                 userInfo:@{
                                     NSLocalizedDescriptionKey: description,
                                     PXOptionalRestoreStagingErrorFieldPathKey: fieldPath
                                 }];
    }
    return nil;
}

static BOOL PXOptionalFail(NSError **error,
                           PXOptionalRestoreStagingErrorCode code,
                           NSString *fieldPath,
                           NSString *description) {
    PXOptionalFailObject(error, code, fieldPath, description);
    return NO;
}

typedef struct {
    dev_t device;
    ino_t inode;
    mode_t mode;
    off_t size;
    nlink_t linkCount;
    struct timespec modificationTime;
    struct timespec changeTime;
} PXOptionalIdentity;

static PXOptionalIdentity PXOptionalIdentityFromStat(const struct stat *value) {
    PXOptionalIdentity identity;
    memset(&identity, 0, sizeof(identity));
    identity.device = value->st_dev;
    identity.inode = value->st_ino;
    identity.mode = value->st_mode;
    identity.size = value->st_size;
    identity.linkCount = value->st_nlink;
    identity.modificationTime = value->st_mtimespec;
    identity.changeTime = value->st_ctimespec;
    return identity;
}

static BOOL PXOptionalTimespecEqual(struct timespec left, struct timespec right) {
    return left.tv_sec == right.tv_sec && left.tv_nsec == right.tv_nsec;
}

static BOOL PXOptionalIdentityMatchesBasic(PXOptionalIdentity expected,
                                           const struct stat *actual) {
    return expected.device == actual->st_dev &&
           expected.inode == actual->st_ino &&
           ((expected.mode & S_IFMT) == (actual->st_mode & S_IFMT));
}

static BOOL PXOptionalStableFileIdentityMatches(PXOptionalIdentity expected,
                                                const struct stat *actual) {
    return PXOptionalIdentityMatchesBasic(expected, actual) &&
           expected.linkCount == actual->st_nlink &&
           expected.size == actual->st_size &&
           PXOptionalTimespecEqual(expected.modificationTime, actual->st_mtimespec) &&
           PXOptionalTimespecEqual(expected.changeTime, actual->st_ctimespec);
}

static BOOL PXOptionalSetCloseOnExec(int descriptor) {
    int flags = fcntl(descriptor, F_GETFD);
    if (flags < 0) {
        return NO;
    }
    return fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC) == 0;
}

static int PXOptionalDuplicateDescriptor(int descriptor) {
#ifdef F_DUPFD_CLOEXEC
    int duplicate = fcntl(descriptor, F_DUPFD_CLOEXEC, 0);
    if (duplicate >= 0) {
        return duplicate;
    }
#endif
    int duplicate = dup(descriptor);
    if (duplicate < 0) {
        return -1;
    }
    if (!PXOptionalSetCloseOnExec(duplicate)) {
        close(duplicate);
        return -1;
    }
    return duplicate;
}

static void PXOptionalCloseDescriptor(int *descriptor) {
    if (descriptor && *descriptor >= 0) {
        close(*descriptor);
        *descriptor = -1;
    }
}

static BOOL PXOptionalStringContainsNUL(NSString *value) {
    for (NSUInteger index = 0; index < value.length; index++) {
        if ([value characterAtIndex:index] == 0) {
            return YES;
        }
    }
    return NO;
}

static BOOL PXOptionalStringHasNonWhitespaceText(NSString *value) {
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    for (NSUInteger index = 0; index < value.length; index++) {
        if (![whitespace characterIsMember:[value characterAtIndex:index]]) {
            return YES;
        }
    }
    return NO;
}

static BOOL PXOptionalStringContainsASCIIControl(NSString *value) {
    NSData *utf8 = [value dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if (!utf8) {
        return YES;
    }
    const unsigned char *bytes = utf8.bytes;
    for (NSUInteger index = 0; index < utf8.length; index++) {
        if (bytes[index] < 0x20 || bytes[index] == 0x7f) {
            return YES;
        }
    }
    return NO;
}

static BOOL PXOptionalSafeComponent(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }
    NSString *component = (NSString *)value;
    if (component.length == 0 ||
        !PXOptionalStringHasNonWhitespaceText(component) ||
        PXOptionalStringContainsNUL(component) ||
        PXOptionalStringContainsASCIIControl(component) ||
        [component containsString:@"/"] ||
        [component containsString:@"\\"] ||
        [component isEqualToString:@"."] ||
        [component isEqualToString:@".."]) {
        return NO;
    }
    NSData *utf8 = [component dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    return utf8 && utf8.length >= 1 && utf8.length <= PXOptionalMaximumComponentBytes;
}

static NSArray<NSString *> *PXOptionalSafeRelativeComponents(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *relativePath = (NSString *)value;
    if (relativePath.length == 0 ||
        !PXOptionalStringHasNonWhitespaceText(relativePath) ||
        PXOptionalStringContainsNUL(relativePath) ||
        PXOptionalStringContainsASCIIControl(relativePath) ||
        [relativePath hasPrefix:@"/"] ||
        [relativePath hasSuffix:@"/"] ||
        [relativePath containsString:@"//"] ||
        [relativePath containsString:@"\\"]) {
        return nil;
    }
    NSData *pathBytes = [relativePath dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if (!pathBytes || pathBytes.length > PXOptionalMaximumPathBytes) {
        return nil;
    }
    NSArray<NSString *> *components = [relativePath componentsSeparatedByString:@"/"];
    if (components.count == 0) {
        return nil;
    }
    for (NSString *component in components) {
        if (!PXOptionalSafeComponent(component)) {
            return nil;
        }
    }
    return components;
}

static BOOL PXOptionalPathIsContained(NSString *rootPath, NSString *path) {
    if ([path isEqualToString:rootPath]) {
        return YES;
    }
    NSString *prefix = [rootPath stringByAppendingString:@"/"];
    return [path hasPrefix:prefix];
}

static BOOL PXOptionalPathIsAncestor(NSString *ancestor, NSString *descendant) {
    if ([ancestor isEqualToString:descendant]) {
        return NO;
    }
    return [descendant hasPrefix:[ancestor stringByAppendingString:@"/"]];
}

static NSString *PXOptionalPathForComponents(NSString *rootPath,
                                             NSArray<NSString *> *components) {
    NSString *path = rootPath;
    for (NSString *component in components) {
        path = [path stringByAppendingPathComponent:component];
    }
    NSData *utf8 = [path dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if (!utf8 || utf8.length > PXOptionalMaximumPathBytes) {
        return nil;
    }
    return path;
}

static char *PXOptionalCopyFileSystemRepresentation(NSString *value) {
    const char *representation = value.fileSystemRepresentation;
    if (!representation) {
        return NULL;
    }
    size_t length = strlen(representation);
    if (length > PXOptionalMaximumPathBytes) {
        return NULL;
    }
    char *copy = calloc(length + 1, 1);
    if (!copy) {
        return NULL;
    }
    memcpy(copy, representation, length);
    return copy;
}

static char *PXOptionalCopyComponentRepresentation(NSString *value) {
    if (!PXOptionalSafeComponent(value)) {
        return NULL;
    }
    const char *representation = value.fileSystemRepresentation;
    if (!representation) {
        return NULL;
    }
    size_t length = strlen(representation);
    if (length == 0 || length > PXOptionalMaximumComponentBytes) {
        return NULL;
    }
    char *copy = calloc(length + 1, 1);
    if (!copy) {
        return NULL;
    }
    memcpy(copy, representation, length);
    return copy;
}

static NSString *PXOptionalLowercaseDigest(const unsigned char digest[CC_SHA256_DIGEST_LENGTH]) {
    static const char hex[] = "0123456789abcdef";
    char output[(CC_SHA256_DIGEST_LENGTH * 2) + 1];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
        output[index * 2] = hex[(digest[index] >> 4) & 0x0f];
        output[(index * 2) + 1] = hex[digest[index] & 0x0f];
    }
    output[CC_SHA256_DIGEST_LENGTH * 2] = '\0';
    return [NSString stringWithUTF8String:output];
}

typedef NS_ENUM(NSUInteger, PXOptionalDestinationType) {
    PXOptionalDestinationTypeDirectory = 1,
    PXOptionalDestinationTypeRegularFile = 2,
};

@interface PXOptionalDestinationRecord : NSObject
@property (nonatomic, copy, readonly) NSString *path;
@property (nonatomic, copy, readonly) NSArray<NSString *> *components;
@property (nonatomic, copy, readonly) NSString *fieldPath;
@property (nonatomic, assign, readonly) PXOptionalDestinationType type;
@property (nonatomic, assign, readonly, getter=isPresent) BOOL present;
@property (nonatomic, assign, readonly) PXOptionalIdentity parentIdentity;
@property (nonatomic, assign, readonly) PXOptionalIdentity finalIdentity;
- (instancetype)initWithPath:(NSString *)path
                  components:(NSArray<NSString *> *)components
                   fieldPath:(NSString *)fieldPath
                        type:(PXOptionalDestinationType)type
                     present:(BOOL)present
              parentIdentity:(PXOptionalIdentity)parentIdentity
               finalIdentity:(PXOptionalIdentity)finalIdentity;
@end

@implementation PXOptionalDestinationRecord
- (instancetype)initWithPath:(NSString *)path
                  components:(NSArray<NSString *> *)components
                   fieldPath:(NSString *)fieldPath
                        type:(PXOptionalDestinationType)type
                     present:(BOOL)present
              parentIdentity:(PXOptionalIdentity)parentIdentity
               finalIdentity:(PXOptionalIdentity)finalIdentity {
    self = [super init];
    if (self) {
        _path = [path copy];
        _components = [components copy];
        _fieldPath = [fieldPath copy];
        _type = type;
        _present = present;
        _parentIdentity = parentIdentity;
        _finalIdentity = finalIdentity;
    }
    return self;
}
@end

static BOOL PXOptionalOpenRootAndVerify(NSString *rootPath,
                                        PXOptionalIdentity expectedIdentity,
                                        int *descriptorOut) {
    if (descriptorOut) {
        *descriptorOut = -1;
    }
    char *root = PXOptionalCopyFileSystemRepresentation(rootPath);
    if (!root) {
        return NO;
    }
    struct stat pathStat;
    memset(&pathStat, 0, sizeof(pathStat));
    if (lstat(root, &pathStat) != 0 ||
        !S_ISDIR(pathStat.st_mode) ||
        S_ISLNK(pathStat.st_mode) ||
        !PXOptionalIdentityMatchesBasic(expectedIdentity, &pathStat)) {
        free(root);
        return NO;
    }
    int descriptor = open(root, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    free(root);
    if (descriptor < 0 || !PXOptionalSetCloseOnExec(descriptor)) {
        if (descriptor >= 0) {
            close(descriptor);
        }
        return NO;
    }
    struct stat descriptorStat;
    memset(&descriptorStat, 0, sizeof(descriptorStat));
    if (fstat(descriptor, &descriptorStat) != 0 ||
        !S_ISDIR(descriptorStat.st_mode) ||
        !PXOptionalIdentityMatchesBasic(expectedIdentity, &descriptorStat)) {
        close(descriptor);
        return NO;
    }
    if (descriptorOut) {
        *descriptorOut = descriptor;
    } else {
        close(descriptor);
    }
    return YES;
}

static PXOptionalDestinationRecord *PXOptionalInspectDestination(
    NSString *rootPath,
    PXOptionalIdentity rootIdentity,
    NSArray<NSString *> *components,
    PXOptionalDestinationType type,
    BOOL allowAbsentFinal,
    NSString *fieldPath,
    PXOptionalRestoreStagingErrorCode missingCode,
    NSError **error) {
    if (components.count == 0) {
        return PXOptionalFailObject(error,
                                    PXOptionalRestoreStagingErrorUnsafeDestination,
                                    fieldPath,
                                    @"The optional Restore destination is unsafe.");
    }
    NSString *fullPath = PXOptionalPathForComponents(rootPath, components);
    if (!fullPath || !PXOptionalPathIsContained(rootPath, fullPath)) {
        return PXOptionalFailObject(error,
                                    PXOptionalRestoreStagingErrorUnsafeDestination,
                                    fieldPath,
                                    @"The optional Restore destination is outside the accepted root.");
    }

    int currentDescriptor = -1;
    if (!PXOptionalOpenRootAndVerify(rootPath, rootIdentity, &currentDescriptor)) {
        return PXOptionalFailObject(error,
                                    PXOptionalRestoreStagingErrorInvalidDestinationIdentity,
                                    fieldPath,
                                    @"The optional Restore destination root identity changed.");
    }

    BOOL success = NO;
    PXOptionalDestinationRecord *record = nil;
    PXOptionalRestoreStagingErrorCode failureCode = missingCode;
    NSString *failureDescription = @"The optional Restore destination is missing.";
    do {
        BOOL parentChainValid = YES;
        for (NSUInteger index = 0; index + 1 < components.count; index++) {
            NSString *component = components[index];
            char *name = PXOptionalCopyComponentRepresentation(component);
            if (!name) {
                failureCode = PXOptionalRestoreStagingErrorUnsafeDestination;
                failureDescription = @"An optional Restore destination component is unsafe.";
                parentChainValid = NO;
                break;
            }
            struct stat pathStat;
            memset(&pathStat, 0, sizeof(pathStat));
            if (fstatat(currentDescriptor, name, &pathStat, AT_SYMLINK_NOFOLLOW) != 0) {
                int inspectionError = errno;
                free(name);
                failureCode = inspectionError == ENOENT
                    ? PXOptionalRestoreStagingErrorMissingDestination
                    : PXOptionalRestoreStagingErrorUnsafeDestination;
                failureDescription = inspectionError == ENOENT
                    ? @"An optional Restore destination parent is missing."
                    : @"An optional Restore destination parent is unsafe.";
                parentChainValid = NO;
                break;
            }
            if (!S_ISDIR(pathStat.st_mode) ||
                S_ISLNK(pathStat.st_mode) ||
                pathStat.st_dev != rootIdentity.device) {
                free(name);
                failureCode = PXOptionalRestoreStagingErrorUnsafeDestination;
                failureDescription = @"An optional Restore destination parent is unsafe.";
                parentChainValid = NO;
                break;
            }
            int childDescriptor = openat(currentDescriptor,
                                         name,
                                         O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
            free(name);
            if (childDescriptor < 0 || !PXOptionalSetCloseOnExec(childDescriptor)) {
                if (childDescriptor >= 0) {
                    close(childDescriptor);
                }
                failureCode = PXOptionalRestoreStagingErrorInvalidDestinationIdentity;
                failureDescription = @"An optional Restore destination parent identity changed.";
                parentChainValid = NO;
                break;
            }
            struct stat childStat;
            memset(&childStat, 0, sizeof(childStat));
            if (fstat(childDescriptor, &childStat) != 0 ||
                !S_ISDIR(childStat.st_mode) ||
                childStat.st_dev != pathStat.st_dev ||
                childStat.st_ino != pathStat.st_ino) {
                close(childDescriptor);
                failureCode = PXOptionalRestoreStagingErrorInvalidDestinationIdentity;
                failureDescription = @"An optional Restore destination parent identity changed.";
                parentChainValid = NO;
                break;
            }
            close(currentDescriptor);
            currentDescriptor = childDescriptor;
        }
        if (!parentChainValid) {
            break;
        }

        struct stat parentStat;
        memset(&parentStat, 0, sizeof(parentStat));
        if (fstat(currentDescriptor, &parentStat) != 0 ||
            !S_ISDIR(parentStat.st_mode) ||
            parentStat.st_dev != rootIdentity.device) {
            failureCode = PXOptionalRestoreStagingErrorInvalidDestinationIdentity;
            failureDescription = @"The optional Restore destination parent identity changed.";
            break;
        }
        PXOptionalIdentity parentIdentity = PXOptionalIdentityFromStat(&parentStat);

        NSString *finalComponent = components.lastObject;
        char *finalName = PXOptionalCopyComponentRepresentation(finalComponent);
        if (!finalName) {
            failureCode = PXOptionalRestoreStagingErrorUnsafeDestination;
            failureDescription = @"The optional Restore destination filename is unsafe.";
            break;
        }
        struct stat finalPathStat;
        memset(&finalPathStat, 0, sizeof(finalPathStat));
        int finalResult = fstatat(currentDescriptor,
                                  finalName,
                                  &finalPathStat,
                                  AT_SYMLINK_NOFOLLOW);
        if (finalResult != 0) {
            int finalError = errno;
            free(finalName);
            if (finalError != ENOENT || !allowAbsentFinal) {
                failureCode = finalError == ENOENT
                    ? missingCode
                    : PXOptionalRestoreStagingErrorUnsafeDestination;
                failureDescription = finalError == ENOENT
                    ? @"The optional Restore destination is missing."
                    : @"The optional Restore destination could not be inspected safely.";
                break;
            }
            PXOptionalIdentity emptyIdentity;
            memset(&emptyIdentity, 0, sizeof(emptyIdentity));
            record = [[PXOptionalDestinationRecord alloc] initWithPath:fullPath
                                                            components:components
                                                             fieldPath:fieldPath
                                                                  type:type
                                                               present:NO
                                                        parentIdentity:parentIdentity
                                                         finalIdentity:emptyIdentity];
            success = record != nil;
            break;
        }

        BOOL expectedType =
            (type == PXOptionalDestinationTypeDirectory && S_ISDIR(finalPathStat.st_mode)) ||
            (type == PXOptionalDestinationTypeRegularFile && S_ISREG(finalPathStat.st_mode));
        if (!expectedType ||
            S_ISLNK(finalPathStat.st_mode) ||
            finalPathStat.st_dev != rootIdentity.device) {
            free(finalName);
            failureCode = PXOptionalRestoreStagingErrorUnsafeDestination;
            failureDescription = @"The optional Restore destination type is unsafe.";
            break;
        }
        int finalFlags = O_RDONLY | O_NOFOLLOW | O_CLOEXEC;
        if (type == PXOptionalDestinationTypeDirectory) {
            finalFlags |= O_DIRECTORY;
        } else {
            finalFlags |= O_NONBLOCK;
        }
        int finalDescriptor = openat(currentDescriptor, finalName, finalFlags);
        free(finalName);
        if (finalDescriptor < 0 || !PXOptionalSetCloseOnExec(finalDescriptor)) {
            if (finalDescriptor >= 0) {
                close(finalDescriptor);
            }
            failureCode = PXOptionalRestoreStagingErrorInvalidDestinationIdentity;
            failureDescription = @"The optional Restore destination identity changed.";
            break;
        }
        struct stat finalDescriptorStat;
        memset(&finalDescriptorStat, 0, sizeof(finalDescriptorStat));
        BOOL finalStable =
            fstat(finalDescriptor, &finalDescriptorStat) == 0 &&
            finalDescriptorStat.st_dev == finalPathStat.st_dev &&
            finalDescriptorStat.st_ino == finalPathStat.st_ino &&
            ((finalDescriptorStat.st_mode & S_IFMT) == (finalPathStat.st_mode & S_IFMT));
        close(finalDescriptor);
        if (!finalStable) {
            failureCode = PXOptionalRestoreStagingErrorInvalidDestinationIdentity;
            failureDescription = @"The optional Restore destination identity changed.";
            break;
        }

        char resolvedBuffer[PATH_MAX];
        memset(resolvedBuffer, 0, sizeof(resolvedBuffer));
        char *fullRepresentation = PXOptionalCopyFileSystemRepresentation(fullPath);
        if (!fullRepresentation) {
            failureCode = PXOptionalRestoreStagingErrorUnsafeDestination;
            failureDescription = @"The optional Restore destination path is unsafe.";
            break;
        }
        char *resolved = realpath(fullRepresentation, resolvedBuffer);
        free(fullRepresentation);
        if (!resolved) {
            failureCode = PXOptionalRestoreStagingErrorUnsafeDestination;
            failureDescription = @"The optional Restore destination could not be canonicalized safely.";
            break;
        }
        NSString *resolvedPath = [NSString stringWithUTF8String:resolvedBuffer];
        if (![resolvedPath isEqualToString:fullPath] ||
            !PXOptionalPathIsContained(rootPath, resolvedPath)) {
            failureCode = PXOptionalRestoreStagingErrorUnsafeDestination;
            failureDescription = @"The optional Restore destination escaped the accepted root.";
            break;
        }

        record = [[PXOptionalDestinationRecord alloc]
            initWithPath:fullPath
              components:components
               fieldPath:fieldPath
                    type:type
                 present:YES
          parentIdentity:parentIdentity
           finalIdentity:PXOptionalIdentityFromStat(&finalDescriptorStat)];
        success = record != nil;
        if (!success) {
            failureCode = PXOptionalRestoreStagingErrorInconsistentPlan;
            failureDescription = @"The optional Restore destination snapshot could not be represented safely.";
        }
    } while (NO);

    close(currentDescriptor);
    if (!success) {
        return PXOptionalFailObject(error,
                                    failureCode,
                                    fieldPath,
                                    failureDescription);
    }
    return record;
}

static NSString *PXOptionalRevalidateDestinationRecord(NSString *rootPath,
                                                       PXOptionalIdentity rootIdentity,
                                                       PXOptionalDestinationRecord *record,
                                                       NSError **error) {
    if (![record isKindOfClass:[PXOptionalDestinationRecord class]]) {
        return PXOptionalFailObject(error,
                                    PXOptionalRestoreStagingErrorInconsistentPlan,
                                    @"$",
                                    @"The optional Restore destination key is not present in the accepted plan.");
    }
    NSError *inspectionError = nil;
    PXOptionalDestinationRecord *current =
        PXOptionalInspectDestination(rootPath,
                                     rootIdentity,
                                     record.components,
                                     record.type,
                                     !record.isPresent,
                                     record.fieldPath,
                                     PXOptionalRestoreStagingErrorInvalidDestinationIdentity,
                                     &inspectionError);
    if (!current) {
        if (error) {
            *error = inspectionError ?: [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                                             code:PXOptionalRestoreStagingErrorInvalidDestinationIdentity
                                                         userInfo:@{
                                                             NSLocalizedDescriptionKey: @"The optional Restore destination identity changed.",
                                                             PXOptionalRestoreStagingErrorFieldPathKey: record.fieldPath
                                                         }];
        }
        return nil;
    }
    BOOL parentMatches =
        current.parentIdentity.device == record.parentIdentity.device &&
        current.parentIdentity.inode == record.parentIdentity.inode &&
        ((current.parentIdentity.mode & S_IFMT) == (record.parentIdentity.mode & S_IFMT));
    BOOL finalMatches = current.isPresent == record.isPresent;
    if (finalMatches && record.isPresent) {
        finalMatches =
            current.finalIdentity.device == record.finalIdentity.device &&
            current.finalIdentity.inode == record.finalIdentity.inode &&
            ((current.finalIdentity.mode & S_IFMT) == (record.finalIdentity.mode & S_IFMT));
    }
    if (!parentMatches || !finalMatches || ![current.path isEqualToString:record.path]) {
        return PXOptionalFailObject(error,
                                    PXOptionalRestoreStagingErrorInvalidDestinationIdentity,
                                    record.fieldPath,
                                    @"The optional Restore destination identity changed.");
    }
    return record.path;
}

static BOOL PXOptionalResolveMobileLibrary(NSString **pathOut,
                                           PXOptionalIdentity *identityOut,
                                           NSError **error) {
    if (pathOut) {
        *pathOut = nil;
    }
    if (identityOut) {
        memset(identityOut, 0, sizeof(*identityOut));
    }
    NSArray<NSString *> *candidates = @[
        @"/private/var/mobile/Library",
        @"/var/mobile/Library",
        @"/private/var/jb/var/mobile/Library",
        @"/var/jb/var/mobile/Library"
    ];
    NSMutableDictionary<NSString *, NSDictionary *> *rootsByIdentity = [NSMutableDictionary dictionary];
    for (NSString *candidate in candidates) {
        char *candidateRepresentation = PXOptionalCopyFileSystemRepresentation(candidate);
        if (!candidateRepresentation) {
            return PXOptionalFail(error,
                                  PXOptionalRestoreStagingErrorUnsafeDestination,
                                  @"$.mobileLibrary",
                                  @"A fixed mobile Library candidate is unsafe.");
        }
        struct stat candidateStat;
        memset(&candidateStat, 0, sizeof(candidateStat));
        if (lstat(candidateRepresentation, &candidateStat) != 0) {
            int candidateError = errno;
            free(candidateRepresentation);
            if (candidateError == ENOENT) {
                continue;
            }
            return PXOptionalFail(error,
                                  PXOptionalRestoreStagingErrorUnsafeDestination,
                                  @"$.mobileLibrary",
                                  @"A fixed mobile Library candidate could not be inspected.");
        }
        if (!S_ISDIR(candidateStat.st_mode) || S_ISLNK(candidateStat.st_mode)) {
            free(candidateRepresentation);
            return PXOptionalFail(error,
                                  PXOptionalRestoreStagingErrorUnsafeDestination,
                                  @"$.mobileLibrary",
                                  @"A fixed mobile Library candidate is not a real directory.");
        }
        char resolvedBuffer[PATH_MAX];
        memset(resolvedBuffer, 0, sizeof(resolvedBuffer));
        char *resolved = realpath(candidateRepresentation, resolvedBuffer);
        free(candidateRepresentation);
        if (!resolved) {
            return PXOptionalFail(error,
                                  PXOptionalRestoreStagingErrorUnsafeDestination,
                                  @"$.mobileLibrary",
                                  @"A fixed mobile Library candidate could not be canonicalized.");
        }
        NSString *canonicalPath = [NSString stringWithUTF8String:resolvedBuffer];
        char *canonicalRepresentation = PXOptionalCopyFileSystemRepresentation(canonicalPath);
        if (!canonicalRepresentation) {
            return PXOptionalFail(error,
                                  PXOptionalRestoreStagingErrorUnsafeDestination,
                                  @"$.mobileLibrary",
                                  @"A fixed mobile Library candidate is invalid.");
        }
        struct stat canonicalPathStat;
        memset(&canonicalPathStat, 0, sizeof(canonicalPathStat));
        int descriptor = -1;
        if (lstat(canonicalRepresentation, &canonicalPathStat) != 0 ||
            !S_ISDIR(canonicalPathStat.st_mode) ||
            S_ISLNK(canonicalPathStat.st_mode) ||
            (descriptor = open(canonicalRepresentation,
                               O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)) < 0 ||
            !PXOptionalSetCloseOnExec(descriptor)) {
            free(canonicalRepresentation);
            if (descriptor >= 0) {
                close(descriptor);
            }
            return PXOptionalFail(error,
                                  PXOptionalRestoreStagingErrorUnsafeDestination,
                                  @"$.mobileLibrary",
                                  @"A fixed mobile Library candidate could not be opened safely.");
        }
        free(canonicalRepresentation);
        struct stat descriptorStat;
        memset(&descriptorStat, 0, sizeof(descriptorStat));
        BOOL identityValid =
            fstat(descriptor, &descriptorStat) == 0 &&
            S_ISDIR(descriptorStat.st_mode) &&
            candidateStat.st_dev == canonicalPathStat.st_dev &&
            candidateStat.st_ino == canonicalPathStat.st_ino &&
            descriptorStat.st_dev == canonicalPathStat.st_dev &&
            descriptorStat.st_ino == canonicalPathStat.st_ino;
        close(descriptor);
        if (!identityValid) {
            return PXOptionalFail(error,
                                  PXOptionalRestoreStagingErrorInvalidDestinationIdentity,
                                  @"$.mobileLibrary",
                                  @"A fixed mobile Library candidate identity is unstable.");
        }
        NSString *identityKey = [NSString stringWithFormat:@"%llu:%llu",
                                 (unsigned long long)descriptorStat.st_dev,
                                 (unsigned long long)descriptorStat.st_ino];
        if (!rootsByIdentity[identityKey]) {
            PXOptionalIdentity identity = PXOptionalIdentityFromStat(&descriptorStat);
            rootsByIdentity[identityKey] = @{
                @"path": [canonicalPath copy],
                @"identity": [NSValue valueWithBytes:&identity objCType:@encode(PXOptionalIdentity)]
            };
        }
    }
    if (rootsByIdentity.count == 0) {
        return PXOptionalFail(error,
                              PXOptionalRestoreStagingErrorMissingDestination,
                              @"$.mobileLibrary",
                              @"No accepted mobile Library destination exists.");
    }
    if (rootsByIdentity.count != 1) {
        return PXOptionalFail(error,
                              PXOptionalRestoreStagingErrorAmbiguousDestination,
                              @"$.mobileLibrary",
                              @"Multiple distinct mobile Library destinations exist.");
    }
    NSDictionary *selected = rootsByIdentity.allValues.firstObject;
    PXOptionalIdentity selectedIdentity;
    memset(&selectedIdentity, 0, sizeof(selectedIdentity));
    [selected[@"identity"] getValue:&selectedIdentity];
    if (pathOut) {
        *pathOut = [selected[@"path"] copy];
    }
    if (identityOut) {
        *identityOut = selectedIdentity;
    }
    return YES;
}

@interface PXValidatedOptionalFileStage ()
- (instancetype)initWithWorkspaceRootPath:(NSString *)workspaceRootPath
                                 filePath:(NSString *)filePath
                                byteCount:(unsigned long long)byteCount
                                   sha256:(NSString *)sha256;
@end

@implementation PXValidatedOptionalFileStage
- (instancetype)initWithWorkspaceRootPath:(NSString *)workspaceRootPath
                                 filePath:(NSString *)filePath
                                byteCount:(unsigned long long)byteCount
                                   sha256:(NSString *)sha256 {
    self = [super init];
    if (self) {
        _workspaceRootPath = [workspaceRootPath copy];
        _filePath = [filePath copy];
        _byteCount = byteCount;
        _sha256 = [sha256 copy];
    }
    return self;
}
- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}
@end

@interface PXOptionalFileStagingWorkspace ()
@property (nonatomic, copy, readwrite) NSString *rootPath;
@property (nonatomic, copy, readwrite) NSString *filePath;
@property (nonatomic, strong, readwrite) PXValidatedOptionalFileStage *validatedStage;
@property (nonatomic, assign) int parentDescriptor;
@property (nonatomic, assign) int rootDescriptor;
@property (nonatomic, assign) int payloadDescriptor;
@property (nonatomic, copy) NSString *rootBasename;
@property (nonatomic, assign) PXOptionalIdentity parentIdentity;
@property (nonatomic, assign) PXOptionalIdentity rootIdentity;
@property (nonatomic, assign) PXOptionalIdentity payloadIdentity;
@property (nonatomic, assign, getter=isCleaned) BOOL cleaned;
@property (nonatomic, assign) BOOL ownershipLost;
- (instancetype)initWithRootPath:(NSString *)rootPath
                        filePath:(NSString *)filePath
                  rootBasename:(NSString *)rootBasename
                parentDescriptor:(int)parentDescriptor
                  rootDescriptor:(int)rootDescriptor
               payloadDescriptor:(int)payloadDescriptor
                  parentIdentity:(PXOptionalIdentity)parentIdentity
                    rootIdentity:(PXOptionalIdentity)rootIdentity
                 payloadIdentity:(PXOptionalIdentity)payloadIdentity
                  validatedStage:(PXValidatedOptionalFileStage *)validatedStage;
@end

static BOOL PXOptionalReadDigestFromDescriptor(int descriptor,
                                               unsigned long long *byteCountOut,
                                               unsigned char digestOut[CC_SHA256_DIGEST_LENGTH]) {
    if (lseek(descriptor, 0, SEEK_SET) < 0) {
        return NO;
    }
    unsigned char *buffer = malloc(PXOptionalStreamBufferSize);
    if (!buffer) {
        return NO;
    }
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    unsigned long long total = 0;
    BOOL success = YES;
    for (;;) {
        ssize_t amount = read(descriptor, buffer, PXOptionalStreamBufferSize);
        if (amount < 0 && errno == EINTR) {
            continue;
        }
        if (amount < 0) {
            success = NO;
            break;
        }
        if (amount == 0) {
            break;
        }
        if (total > ULLONG_MAX - (unsigned long long)amount) {
            success = NO;
            break;
        }
        total += (unsigned long long)amount;
        CC_SHA256_Update(&context, buffer, (CC_LONG)amount);
    }
    free(buffer);
    if (!success) {
        return NO;
    }
    CC_SHA256_Final(digestOut, &context);
    if (byteCountOut) {
        *byteCountOut = total;
    }
    return YES;
}

static BOOL PXOptionalWriteAll(int descriptor, const unsigned char *bytes, size_t length) {
    size_t offset = 0;
    while (offset < length) {
        ssize_t written = write(descriptor, bytes + offset, length - offset);
        if (written < 0 && errno == EINTR) {
            continue;
        }
        if (written <= 0) {
            return NO;
        }
        offset += (size_t)written;
    }
    return YES;
}

static NSArray<NSData *> *PXOptionalReadDirectoryNames(int descriptor) {
    int duplicate = PXOptionalDuplicateDescriptor(descriptor);
    if (duplicate < 0) {
        return nil;
    }
    DIR *directory = fdopendir(duplicate);
    if (!directory) {
        close(duplicate);
        return nil;
    }
    NSMutableArray<NSData *> *names = [NSMutableArray array];
    errno = 0;
    for (;;) {
        struct dirent *entry = readdir(directory);
        if (!entry) {
            break;
        }
        const char *name = entry->d_name;
        if ((name[0] == '.' && name[1] == '\0') ||
            (name[0] == '.' && name[1] == '.' && name[2] == '\0')) {
            continue;
        }
        if (names.count >= PXOptionalMaximumCleanupEntries) {
            closedir(directory);
            return nil;
        }
        size_t length = strlen(name);
        [names addObject:[NSData dataWithBytes:name length:length]];
    }
    int readError = errno;
    if (closedir(directory) != 0 && readError == 0) {
        readError = errno ?: EIO;
    }
    return readError == 0 ? names : nil;
}

static char *PXOptionalCopyRawName(NSData *nameData) {
    if (nameData.length > PXOptionalMaximumComponentBytes) {
        return NULL;
    }
    char *name = calloc(nameData.length + 1, 1);
    if (!name) {
        return NULL;
    }
    memcpy(name, nameData.bytes, nameData.length);
    return name;
}

static BOOL PXOptionalCleanupDirectoryContents(int descriptor,
                                               dev_t expectedDevice,
                                               NSUInteger *entryCount) {
    NSArray<NSData *> *names = PXOptionalReadDirectoryNames(descriptor);
    if (!names) {
        return NO;
    }
    for (NSData *nameData in names) {
        if (*entryCount >= PXOptionalMaximumCleanupEntries) {
            return NO;
        }
        (*entryCount)++;
        char *name = PXOptionalCopyRawName(nameData);
        if (!name) {
            return NO;
        }
        struct stat firstStat;
        memset(&firstStat, 0, sizeof(firstStat));
        if (fstatat(descriptor, name, &firstStat, AT_SYMLINK_NOFOLLOW) != 0 ||
            firstStat.st_dev != expectedDevice) {
            free(name);
            return NO;
        }
        if (S_ISDIR(firstStat.st_mode)) {
            int child = openat(descriptor,
                               name,
                               O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
            if (child < 0 || !PXOptionalSetCloseOnExec(child)) {
                if (child >= 0) {
                    close(child);
                }
                free(name);
                return NO;
            }
            struct stat childStat;
            memset(&childStat, 0, sizeof(childStat));
            BOOL childValid =
                fstat(child, &childStat) == 0 &&
                childStat.st_dev == firstStat.st_dev &&
                childStat.st_ino == firstStat.st_ino &&
                S_ISDIR(childStat.st_mode);
            if (!childValid ||
                !PXOptionalCleanupDirectoryContents(child, expectedDevice, entryCount)) {
                close(child);
                free(name);
                return NO;
            }
            struct stat secondStat;
            memset(&secondStat, 0, sizeof(secondStat));
            BOOL stable =
                fstatat(descriptor, name, &secondStat, AT_SYMLINK_NOFOLLOW) == 0 &&
                secondStat.st_dev == firstStat.st_dev &&
                secondStat.st_ino == firstStat.st_ino &&
                S_ISDIR(secondStat.st_mode);
            close(child);
            if (!stable || unlinkat(descriptor, name, AT_REMOVEDIR) != 0) {
                free(name);
                return NO;
            }
        } else if (unlinkat(descriptor, name, 0) != 0) {
            free(name);
            return NO;
        }
        free(name);
    }
    return YES;
}

@implementation PXOptionalFileStagingWorkspace

- (instancetype)initWithRootPath:(NSString *)rootPath
                        filePath:(NSString *)filePath
                  rootBasename:(NSString *)rootBasename
                parentDescriptor:(int)parentDescriptor
                  rootDescriptor:(int)rootDescriptor
               payloadDescriptor:(int)payloadDescriptor
                  parentIdentity:(PXOptionalIdentity)parentIdentity
                    rootIdentity:(PXOptionalIdentity)rootIdentity
                 payloadIdentity:(PXOptionalIdentity)payloadIdentity
                  validatedStage:(PXValidatedOptionalFileStage *)validatedStage {
    self = [super init];
    if (self) {
        _parentDescriptor = -1;
        _rootDescriptor = -1;
        _payloadDescriptor = -1;
        _rootPath = [rootPath copy];
        _filePath = [filePath copy];
        _rootBasename = [rootBasename copy];
        _parentDescriptor = parentDescriptor;
        _rootDescriptor = rootDescriptor;
        _payloadDescriptor = payloadDescriptor;
        _parentIdentity = parentIdentity;
        _rootIdentity = rootIdentity;
        _payloadIdentity = payloadIdentity;
        _validatedStage = validatedStage;
    }
    return self;
}

+ (instancetype)workspaceByStagingSourceFileAtPath:(NSString *)sourcePath
                                             error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    if (![sourcePath isKindOfClass:[NSString class]] ||
        sourcePath.length == 0 ||
        PXOptionalStringContainsNUL(sourcePath)) {
        return PXOptionalFailObject(error,
                                    PXOptionalRestoreStagingErrorInvalidInput,
                                    @"$.source",
                                    @"The optional file staging source is invalid.");
    }
    NSData *sourceBytes = [sourcePath dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if (!sourceBytes || sourceBytes.length > PXOptionalMaximumPathBytes) {
        return PXOptionalFailObject(error,
                                    PXOptionalRestoreStagingErrorLimitExceeded,
                                    @"$.source",
                                    @"The optional file staging source path limit was exceeded.");
    }

    int sourceDescriptor = -1;
    int parentDescriptor = -1;
    int rootDescriptor = -1;
    int payloadDescriptor = -1;
    NSString *rootPath = nil;
    NSString *filePath = nil;
    NSString *rootBasename = nil;
    BOOL rootCreated = NO;
    PXOptionalIdentity parentIdentity;
    PXOptionalIdentity rootIdentity;
    PXOptionalIdentity payloadIdentity;
    memset(&parentIdentity, 0, sizeof(parentIdentity));
    memset(&rootIdentity, 0, sizeof(rootIdentity));
    memset(&payloadIdentity, 0, sizeof(payloadIdentity));
    NSError *failure = nil;

    do {
        char *sourceRepresentation = PXOptionalCopyFileSystemRepresentation(sourcePath);
        if (!sourceRepresentation) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorInvalidInput
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file staging source is invalid.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
                                      }];
            break;
        }
        struct stat sourcePathStat;
        memset(&sourcePathStat, 0, sizeof(sourcePathStat));
        if (lstat(sourceRepresentation, &sourcePathStat) != 0 ||
            S_ISLNK(sourcePathStat.st_mode)) {
            free(sourceRepresentation);
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorSourceOpenFailed
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file source could not be opened safely.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
                                      }];
            break;
        }
        sourceDescriptor = open(sourceRepresentation,
                                O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
        free(sourceRepresentation);
        if (sourceDescriptor < 0 || !PXOptionalSetCloseOnExec(sourceDescriptor)) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorSourceOpenFailed
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file source could not be opened safely.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
                                      }];
            break;
        }
        struct stat sourceBefore;
        memset(&sourceBefore, 0, sizeof(sourceBefore));
        if (fstat(sourceDescriptor, &sourceBefore) != 0 ||
            sourceBefore.st_dev != sourcePathStat.st_dev ||
            sourceBefore.st_ino != sourcePathStat.st_ino ||
            !S_ISREG(sourceBefore.st_mode) ||
            sourceBefore.st_nlink != 1 ||
            (sourceBefore.st_mode & (S_ISUID | S_ISGID)) != 0 ||
            sourceBefore.st_size < 0) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorSourceUnsupported
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file source type is unsupported.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
                                      }];
            break;
        }
        unsigned long long sourceSize = (unsigned long long)sourceBefore.st_size;
        if (sourceSize > PXOptionalMaximumFileBytes) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorLimitExceeded
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file source size limit was exceeded.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
                                      }];
            break;
        }
        PXOptionalIdentity sourceIdentity = PXOptionalIdentityFromStat(&sourceBefore);

        const char *parentPath = "/private/var/tmp";
        struct stat parentPathStat;
        memset(&parentPathStat, 0, sizeof(parentPathStat));
        if (lstat(parentPath, &parentPathStat) != 0 ||
            !S_ISDIR(parentPathStat.st_mode) ||
            S_ISLNK(parentPathStat.st_mode)) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file workspace parent is unavailable.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
                                      }];
            break;
        }
        parentDescriptor = open(parentPath,
                                O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (parentDescriptor < 0 || !PXOptionalSetCloseOnExec(parentDescriptor)) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file workspace parent could not be opened.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
                                      }];
            break;
        }
        struct stat parentDescriptorStat;
        memset(&parentDescriptorStat, 0, sizeof(parentDescriptorStat));
        if (fstat(parentDescriptor, &parentDescriptorStat) != 0 ||
            parentDescriptorStat.st_dev != parentPathStat.st_dev ||
            parentDescriptorStat.st_ino != parentPathStat.st_ino ||
            !S_ISDIR(parentDescriptorStat.st_mode)) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file workspace parent identity is unstable.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
                                      }];
            break;
        }
        parentIdentity = PXOptionalIdentityFromStat(&parentDescriptorStat);

        char templatePath[] = "/private/var/tmp/weaponx_restore_optional_file.XXXXXX";
        char *createdPath = mkdtemp(templatePath);
        if (!createdPath) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file workspace could not be created.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
                                      }];
            break;
        }
        rootCreated = YES;
        rootPath = [NSString stringWithUTF8String:createdPath];
        rootBasename = rootPath.lastPathComponent;
        if (!rootPath ||
            !rootBasename ||
            ![[rootPath stringByDeletingLastPathComponent] isEqualToString:@"/private/var/tmp"] ||
            !PXOptionalSafeComponent(rootBasename)) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file workspace identity is invalid.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
                                      }];
            break;
        }
        char *rootName = PXOptionalCopyComponentRepresentation(rootBasename);
        if (!rootName) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file workspace identity is invalid.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
                                      }];
            break;
        }
        struct stat rootPathStat;
        memset(&rootPathStat, 0, sizeof(rootPathStat));
        if (fstatat(parentDescriptor, rootName, &rootPathStat, AT_SYMLINK_NOFOLLOW) != 0 ||
            !S_ISDIR(rootPathStat.st_mode) ||
            rootPathStat.st_dev != parentIdentity.device) {
            free(rootName);
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file workspace identity is invalid.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
                                      }];
            break;
        }
        rootDescriptor = openat(parentDescriptor,
                                rootName,
                                O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        free(rootName);
        if (rootDescriptor < 0 ||
            !PXOptionalSetCloseOnExec(rootDescriptor) ||
            fchmod(rootDescriptor, 0700) != 0) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file workspace could not be secured.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
                                      }];
            break;
        }
        struct stat rootDescriptorStat;
        memset(&rootDescriptorStat, 0, sizeof(rootDescriptorStat));
        if (fstat(rootDescriptor, &rootDescriptorStat) != 0 ||
            rootDescriptorStat.st_dev != rootPathStat.st_dev ||
            rootDescriptorStat.st_ino != rootPathStat.st_ino ||
            !S_ISDIR(rootDescriptorStat.st_mode) ||
            (rootDescriptorStat.st_mode & 07777) != 0700) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file workspace could not be secured.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
                                      }];
            break;
        }
        rootIdentity = PXOptionalIdentityFromStat(&rootDescriptorStat);

        payloadDescriptor = openat(rootDescriptor,
                                   "payload",
                                   O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
                                   0600);
        if (payloadDescriptor < 0 ||
            !PXOptionalSetCloseOnExec(payloadDescriptor) ||
            fchmod(payloadDescriptor, 0600) != 0) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file workspace payload could not be created.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.payload"
                                      }];
            break;
        }

        unsigned char *buffer = malloc(PXOptionalStreamBufferSize);
        if (!buffer) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorCopyFailed
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file source could not be staged.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
                                      }];
            break;
        }
        CC_SHA256_CTX sourceDigestContext;
        CC_SHA256_Init(&sourceDigestContext);
        unsigned long long copiedBytes = 0;
        BOOL copySucceeded = YES;
        for (;;) {
            ssize_t amount = read(sourceDescriptor, buffer, PXOptionalStreamBufferSize);
            if (amount < 0 && errno == EINTR) {
                continue;
            }
            if (amount < 0) {
                copySucceeded = NO;
                break;
            }
            if (amount == 0) {
                break;
            }
            if (copiedBytes > ULLONG_MAX - (unsigned long long)amount ||
                copiedBytes + (unsigned long long)amount > PXOptionalMaximumFileBytes ||
                !PXOptionalWriteAll(payloadDescriptor, buffer, (size_t)amount)) {
                copySucceeded = NO;
                break;
            }
            copiedBytes += (unsigned long long)amount;
            CC_SHA256_Update(&sourceDigestContext, buffer, (CC_LONG)amount);
        }
        free(buffer);
        if (!copySucceeded || copiedBytes != sourceSize || fsync(payloadDescriptor) != 0) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorCopyFailed
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file source could not be staged completely.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
                                      }];
            break;
        }
        unsigned char sourceDigest[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256_Final(sourceDigest, &sourceDigestContext);

        struct stat sourceAfter;
        memset(&sourceAfter, 0, sizeof(sourceAfter));
        if (fstat(sourceDescriptor, &sourceAfter) != 0 ||
            !PXOptionalStableFileIdentityMatches(sourceIdentity, &sourceAfter)) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorSourceChanged
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file source changed during staging.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
                                      }];
            break;
        }

        struct stat payloadBeforeRead;
        memset(&payloadBeforeRead, 0, sizeof(payloadBeforeRead));
        if (fstat(payloadDescriptor, &payloadBeforeRead) != 0 ||
            !S_ISREG(payloadBeforeRead.st_mode) ||
            payloadBeforeRead.st_nlink != 1 ||
            payloadBeforeRead.st_dev != rootIdentity.device ||
            payloadBeforeRead.st_size < 0 ||
            (payloadBeforeRead.st_mode & 07777) != 0600 ||
            (unsigned long long)payloadBeforeRead.st_size != copiedBytes) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorStagedFileInvalid
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The staged optional file is invalid.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.payload"
                                      }];
            break;
        }
        payloadIdentity = PXOptionalIdentityFromStat(&payloadBeforeRead);

        int payloadReadDescriptor = openat(rootDescriptor,
                                           "payload",
                                           O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
        if (payloadReadDescriptor < 0 || !PXOptionalSetCloseOnExec(payloadReadDescriptor)) {
            if (payloadReadDescriptor >= 0) {
                close(payloadReadDescriptor);
            }
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorStagedFileInvalid
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The staged optional file could not be verified.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.payload"
                                      }];
            break;
        }
        struct stat payloadReadStat;
        memset(&payloadReadStat, 0, sizeof(payloadReadStat));
        if (fstat(payloadReadDescriptor, &payloadReadStat) != 0 ||
            !PXOptionalIdentityMatchesBasic(payloadIdentity, &payloadReadStat)) {
            close(payloadReadDescriptor);
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorStagedFileInvalid
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The staged optional file identity changed.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.payload"
                                      }];
            break;
        }
        unsigned long long payloadBytes = 0;
        unsigned char payloadDigest[CC_SHA256_DIGEST_LENGTH];
        BOOL payloadReadSucceeded =
            PXOptionalReadDigestFromDescriptor(payloadReadDescriptor,
                                               &payloadBytes,
                                               payloadDigest);
        struct stat payloadAfterRead;
        memset(&payloadAfterRead, 0, sizeof(payloadAfterRead));
        BOOL payloadStable =
            fstat(payloadReadDescriptor, &payloadAfterRead) == 0 &&
            PXOptionalStableFileIdentityMatches(payloadIdentity, &payloadAfterRead);
        close(payloadReadDescriptor);
        if (!payloadReadSucceeded || !payloadStable) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorStagedFileInvalid
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The staged optional file could not be verified.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.payload"
                                      }];
            break;
        }
        if (payloadBytes != copiedBytes) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorSizeMismatch
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The staged optional file size does not match.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.payload"
                                      }];
            break;
        }
        if (memcmp(sourceDigest, payloadDigest, CC_SHA256_DIGEST_LENGTH) != 0) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorDigestMismatch
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The staged optional file digest does not match.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.payload"
                                      }];
            break;
        }

        struct stat parentAfter;
        struct stat rootNamespaceStat;
        struct stat payloadPathStat;
        struct stat rootAfter;
        memset(&parentAfter, 0, sizeof(parentAfter));
        memset(&rootNamespaceStat, 0, sizeof(rootNamespaceStat));
        memset(&payloadPathStat, 0, sizeof(payloadPathStat));
        memset(&rootAfter, 0, sizeof(rootAfter));
        char *finalRootName = PXOptionalCopyComponentRepresentation(rootBasename);
        BOOL finalNamespaceStable =
            finalRootName != NULL &&
            fstat(parentDescriptor, &parentAfter) == 0 &&
            PXOptionalIdentityMatchesBasic(parentIdentity, &parentAfter) &&
            fstatat(parentDescriptor,
                    finalRootName,
                    &rootNamespaceStat,
                    AT_SYMLINK_NOFOLLOW) == 0 &&
            PXOptionalIdentityMatchesBasic(rootIdentity, &rootNamespaceStat) &&
            fstat(rootDescriptor, &rootAfter) == 0 &&
            PXOptionalIdentityMatchesBasic(rootIdentity, &rootAfter) &&
            fstatat(rootDescriptor,
                    "payload",
                    &payloadPathStat,
                    AT_SYMLINK_NOFOLLOW) == 0 &&
            PXOptionalIdentityMatchesBasic(payloadIdentity, &payloadPathStat);
        free(finalRootName);
        if (!finalNamespaceStable) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorStagedFileInvalid
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file workspace identity changed.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
                                      }];
            break;
        }

        filePath = [rootPath stringByAppendingPathComponent:@"payload"];
        NSString *digestString = PXOptionalLowercaseDigest(sourceDigest);
        PXValidatedOptionalFileStage *stage =
            [[PXValidatedOptionalFileStage alloc] initWithWorkspaceRootPath:rootPath
                                                                   filePath:filePath
                                                                  byteCount:copiedBytes
                                                                     sha256:digestString];
        if (!stage || digestString.length != 64) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorStagedFileInvalid
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The staged optional file result is invalid.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.payload"
                                      }];
            break;
        }
        PXOptionalFileStagingWorkspace *workspace =
            [[PXOptionalFileStagingWorkspace alloc] initWithRootPath:rootPath
                                                            filePath:filePath
                                                      rootBasename:rootBasename
                                                    parentDescriptor:parentDescriptor
                                                      rootDescriptor:rootDescriptor
                                                   payloadDescriptor:payloadDescriptor
                                                      parentIdentity:parentIdentity
                                                        rootIdentity:rootIdentity
                                                     payloadIdentity:payloadIdentity
                                                      validatedStage:stage];
        if (!workspace) {
            failure = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                          code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
                                      userInfo:@{
                                          NSLocalizedDescriptionKey: @"The optional file workspace could not be represented safely.",
                                          PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
                                      }];
            break;
        }
        close(sourceDescriptor);
        sourceDescriptor = -1;
        return workspace;
    } while (NO);

    PXOptionalCloseDescriptor(&sourceDescriptor);
    PXOptionalCloseDescriptor(&payloadDescriptor);
    if (rootCreated && rootDescriptor >= 0) {
        struct stat partialRootStat;
        memset(&partialRootStat, 0, sizeof(partialRootStat));
        if (fstat(rootDescriptor, &partialRootStat) == 0 &&
            S_ISDIR(partialRootStat.st_mode)) {
            NSUInteger cleanupCount = 0;
            PXOptionalCleanupDirectoryContents(rootDescriptor,
                                               partialRootStat.st_dev,
                                               &cleanupCount);
        }
    }
    PXOptionalCloseDescriptor(&rootDescriptor);
    if (rootCreated && parentDescriptor >= 0 && rootBasename.length) {
        char *rootName = PXOptionalCopyComponentRepresentation(rootBasename);
        if (rootName) {
            unlinkat(parentDescriptor, rootName, AT_REMOVEDIR);
            free(rootName);
        }
    }
    PXOptionalCloseDescriptor(&parentDescriptor);
    if (error) {
        *error = failure ?: [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                                code:PXOptionalRestoreStagingErrorWorkspaceCreationFailed
                                            userInfo:@{
                                                NSLocalizedDescriptionKey: @"The optional file staging workspace could not be created.",
                                                PXOptionalRestoreStagingErrorFieldPathKey: @"$.workspace"
                                            }];
    }
    return nil;
}

- (BOOL)cleanupWithError:(NSError **)error {
    if (error) {
        *error = nil;
    }
    if (self.isCleaned) {
        return YES;
    }
    if (self.ownershipLost ||
        self.parentDescriptor < 0 ||
        self.rootDescriptor < 0 ||
        self.payloadDescriptor < 0 ||
        self.rootBasename.length == 0) {
        return PXOptionalFail(error,
                              PXOptionalRestoreStagingErrorCleanupFailed,
                              @"$.workspace",
                              @"The optional file workspace can no longer be cleaned safely.");
    }

    char *rootName = PXOptionalCopyComponentRepresentation(self.rootBasename);
    if (!rootName) {
        self.ownershipLost = YES;
        PXOptionalCloseDescriptor(&_payloadDescriptor);
        PXOptionalCloseDescriptor(&_rootDescriptor);
        PXOptionalCloseDescriptor(&_parentDescriptor);
        return PXOptionalFail(error,
                              PXOptionalRestoreStagingErrorCleanupFailed,
                              @"$.workspace",
                              @"The optional file workspace can no longer be cleaned safely.");
    }
    struct stat parentStat;
    struct stat rootDescriptorStat;
    struct stat rootPathStat;
    struct stat payloadDescriptorStat;
    struct stat payloadPathStat;
    memset(&parentStat, 0, sizeof(parentStat));
    memset(&rootDescriptorStat, 0, sizeof(rootDescriptorStat));
    memset(&rootPathStat, 0, sizeof(rootPathStat));
    memset(&payloadDescriptorStat, 0, sizeof(payloadDescriptorStat));
    memset(&payloadPathStat, 0, sizeof(payloadPathStat));
    BOOL identityValid =
        fstat(self.parentDescriptor, &parentStat) == 0 &&
        PXOptionalIdentityMatchesBasic(self.parentIdentity, &parentStat) &&
        fstat(self.rootDescriptor, &rootDescriptorStat) == 0 &&
        PXOptionalIdentityMatchesBasic(self.rootIdentity, &rootDescriptorStat) &&
        fstatat(self.parentDescriptor, rootName, &rootPathStat, AT_SYMLINK_NOFOLLOW) == 0 &&
        PXOptionalIdentityMatchesBasic(self.rootIdentity, &rootPathStat) &&
        fstat(self.payloadDescriptor, &payloadDescriptorStat) == 0 &&
        PXOptionalIdentityMatchesBasic(self.payloadIdentity, &payloadDescriptorStat) &&
        fstatat(self.rootDescriptor, "payload", &payloadPathStat, AT_SYMLINK_NOFOLLOW) == 0 &&
        PXOptionalIdentityMatchesBasic(self.payloadIdentity, &payloadPathStat);
    if (!identityValid) {
        free(rootName);
        self.ownershipLost = YES;
        PXOptionalCloseDescriptor(&_payloadDescriptor);
        PXOptionalCloseDescriptor(&_rootDescriptor);
        PXOptionalCloseDescriptor(&_parentDescriptor);
        return PXOptionalFail(error,
                              PXOptionalRestoreStagingErrorCleanupFailed,
                              @"$.workspace",
                              @"The optional file workspace identity changed before cleanup.");
    }

    NSUInteger cleanupCount = 0;
    BOOL contentsRemoved =
        PXOptionalCleanupDirectoryContents(self.rootDescriptor,
                                           self.rootIdentity.device,
                                           &cleanupCount);
    if (!contentsRemoved) {
        free(rootName);
        self.ownershipLost = YES;
        PXOptionalCloseDescriptor(&_payloadDescriptor);
        PXOptionalCloseDescriptor(&_rootDescriptor);
        PXOptionalCloseDescriptor(&_parentDescriptor);
        return PXOptionalFail(error,
                              PXOptionalRestoreStagingErrorCleanupFailed,
                              @"$.workspace",
                              @"The optional file workspace cleanup could not complete safely.");
    }

    PXOptionalCloseDescriptor(&_payloadDescriptor);
    int removeResult = unlinkat(self.parentDescriptor, rootName, AT_REMOVEDIR);
    int removeError = errno;
    free(rootName);
    if (removeResult != 0 && removeError != ENOENT) {
        self.ownershipLost = YES;
        PXOptionalCloseDescriptor(&_rootDescriptor);
        PXOptionalCloseDescriptor(&_parentDescriptor);
        return PXOptionalFail(error,
                              PXOptionalRestoreStagingErrorCleanupFailed,
                              @"$.workspace",
                              @"The optional file workspace root could not be removed safely.");
    }
    if (removeResult != 0 && removeError == ENOENT) {
        struct stat replacementStat;
        memset(&replacementStat, 0, sizeof(replacementStat));
        char *verifyName = PXOptionalCopyComponentRepresentation(self.rootBasename);
        if (!verifyName ||
            fstatat(self.parentDescriptor,
                    verifyName,
                    &replacementStat,
                    AT_SYMLINK_NOFOLLOW) == 0 ||
            errno != ENOENT) {
            free(verifyName);
            self.ownershipLost = YES;
            PXOptionalCloseDescriptor(&_rootDescriptor);
            PXOptionalCloseDescriptor(&_parentDescriptor);
            return PXOptionalFail(error,
                                  PXOptionalRestoreStagingErrorCleanupFailed,
                                  @"$.workspace",
                                  @"The optional file workspace absence could not be proven safely.");
        }
        free(verifyName);
    }
    PXOptionalCloseDescriptor(&_rootDescriptor);
    PXOptionalCloseDescriptor(&_parentDescriptor);
    self.cleaned = YES;
    return YES;
}

- (void)dealloc {
    if (!_cleaned && !_ownershipLost) {
        [self cleanupWithError:nil];
    }
    PXOptionalCloseDescriptor(&_payloadDescriptor);
    PXOptionalCloseDescriptor(&_rootDescriptor);
    PXOptionalCloseDescriptor(&_parentDescriptor);
}

@end

@interface PXOptionalRestoreDestinationPlan ()
@property (nonatomic, copy, readwrite) NSString *mobileLibraryPath;
@property (nonatomic, copy, nullable, readwrite) NSString *profileAppDataPath;
@property (nonatomic, copy, nullable, readwrite) NSString *globalSafariPath;
@property (nonatomic, copy, nullable, readwrite) NSString *preferencesPath;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, NSString *> *systemGlobalPathsBySubdirectory;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, NSString *> *sharedDatabasePathsByRelativePath;
@property (nonatomic, assign) PXOptionalIdentity mobileLibraryIdentity;
@property (nonatomic, strong, nullable) PXOptionalDestinationRecord *profileRecord;
@property (nonatomic, strong, nullable) PXOptionalDestinationRecord *globalSafariRecord;
@property (nonatomic, strong, nullable) PXOptionalDestinationRecord *preferencesRecord;
@property (nonatomic, copy) NSDictionary<NSString *, PXOptionalDestinationRecord *> *systemRecordsBySubdirectory;
@property (nonatomic, copy) NSDictionary<NSString *, PXOptionalDestinationRecord *> *sharedRecordsByRelativePath;
- (instancetype)initWithMobileLibraryPath:(NSString *)mobileLibraryPath
                    mobileLibraryIdentity:(PXOptionalIdentity)mobileLibraryIdentity
                            profileRecord:(nullable PXOptionalDestinationRecord *)profileRecord
                       globalSafariRecord:(nullable PXOptionalDestinationRecord *)globalSafariRecord
                         preferencesRecord:(nullable PXOptionalDestinationRecord *)preferencesRecord
              systemRecordsBySubdirectory:(NSDictionary<NSString *, PXOptionalDestinationRecord *> *)systemRecords
              sharedRecordsByRelativePath:(NSDictionary<NSString *, PXOptionalDestinationRecord *> *)sharedRecords;
@end

@implementation PXOptionalRestoreDestinationPlan

- (instancetype)initWithMobileLibraryPath:(NSString *)mobileLibraryPath
                    mobileLibraryIdentity:(PXOptionalIdentity)mobileLibraryIdentity
                            profileRecord:(PXOptionalDestinationRecord *)profileRecord
                       globalSafariRecord:(PXOptionalDestinationRecord *)globalSafariRecord
                        preferencesRecord:(PXOptionalDestinationRecord *)preferencesRecord
              systemRecordsBySubdirectory:(NSDictionary<NSString *, PXOptionalDestinationRecord *> *)systemRecords
              sharedRecordsByRelativePath:(NSDictionary<NSString *, PXOptionalDestinationRecord *> *)sharedRecords {
    self = [super init];
    if (self) {
        _mobileLibraryPath = [mobileLibraryPath copy];
        _mobileLibraryIdentity = mobileLibraryIdentity;
        _profileRecord = profileRecord;
        _globalSafariRecord = globalSafariRecord;
        _preferencesRecord = preferencesRecord;
        _profileAppDataPath = [profileRecord.path copy];
        _globalSafariPath = [globalSafariRecord.path copy];
        _preferencesPath = [preferencesRecord.path copy];
        _systemRecordsBySubdirectory = [systemRecords copy];
        _sharedRecordsByRelativePath = [sharedRecords copy];
        NSMutableDictionary<NSString *, NSString *> *systemPaths =
            [NSMutableDictionary dictionaryWithCapacity:systemRecords.count];
        [systemRecords enumerateKeysAndObjectsUsingBlock:
            ^(NSString *key, PXOptionalDestinationRecord *record, BOOL *stop) {
                (void)stop;
                systemPaths[key] = record.path;
            }];
        NSMutableDictionary<NSString *, NSString *> *sharedPaths =
            [NSMutableDictionary dictionaryWithCapacity:sharedRecords.count];
        [sharedRecords enumerateKeysAndObjectsUsingBlock:
            ^(NSString *key, PXOptionalDestinationRecord *record, BOOL *stop) {
                (void)stop;
                sharedPaths[key] = record.path;
            }];
        _systemGlobalPathsBySubdirectory = [systemPaths copy];
        _sharedDatabasePathsByRelativePath = [sharedPaths copy];
    }
    return self;
}

+ (instancetype)destinationPlanForRestorePlan:(PXRestorePlan *)restorePlan
                              bundleIdentifier:(NSString *)bundleIdentifier
                       activeProfileIdentifier:(NSString *)profileIdentifier
                                         error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    if (![restorePlan isKindOfClass:[PXRestorePlan class]] ||
        !PXOptionalSafeComponent(bundleIdentifier) ||
        ![restorePlan.bundleIdentifier isEqualToString:bundleIdentifier]) {
        return PXOptionalFailObject(error,
                                    PXOptionalRestoreStagingErrorInvalidInput,
                                    @"$",
                                    @"The optional Restore destination-plan input is invalid.");
    }
    if (![restorePlan.systemGlobalItems isKindOfClass:[NSArray class]] ||
        ![restorePlan.sharedDatabaseItems isKindOfClass:[NSArray class]]) {
        return PXOptionalFailObject(error,
                                    PXOptionalRestoreStagingErrorInconsistentPlan,
                                    @"$",
                                    @"The accepted optional Restore plan is inconsistent.");
    }
    if (restorePlan.includesGlobalSafari &&
        ![bundleIdentifier isEqualToString:@"com.apple.mobilesafari"]) {
        return PXOptionalFailObject(error,
                                    PXOptionalRestoreStagingErrorInconsistentPlan,
                                    @"$.globalSafari.destination",
                                    @"The global Safari destination is inconsistent with the Restore target.");
    }
    if (restorePlan.includesProfileAppData && !PXOptionalSafeComponent(profileIdentifier)) {
        return PXOptionalFailObject(error,
                                    PXOptionalRestoreStagingErrorMissingDestination,
                                    @"$.profileAppData.destination",
                                    @"The active profile destination identity is unavailable.");
    }

    NSUInteger baseTarDirectoryCount = 0;
    if (restorePlan.includesProfileAppData) {
        baseTarDirectoryCount++;
    }
    if (restorePlan.includesGlobalSafari) {
        baseTarDirectoryCount++;
    }
    NSUInteger possibleSafariSkip = restorePlan.includesGlobalSafari ? 1 : 0;
    if (baseTarDirectoryCount > PXOptionalMaximumTarDirectoryItems ||
        PXOptionalMaximumTarDirectoryItems - baseTarDirectoryCount > NSUIntegerMax - possibleSafariSkip ||
        restorePlan.systemGlobalItems.count >
            (PXOptionalMaximumTarDirectoryItems - baseTarDirectoryCount + possibleSafariSkip)) {
        return PXOptionalFailObject(error,
                                    PXOptionalRestoreStagingErrorLimitExceeded,
                                    @"$",
                                    @"The optional Restore directory-item limit was exceeded.");
    }

    NSUInteger fileItemCount = restorePlan.sharedDatabaseItems.count;
    if (restorePlan.includesPreferences) {
        if (fileItemCount == NSUIntegerMax) {
            return PXOptionalFailObject(error,
                                        PXOptionalRestoreStagingErrorLimitExceeded,
                                        @"$",
                                        @"The optional Restore item count overflowed.");
        }
        fileItemCount++;
    }
    if (restorePlan.includesKeychain) {
        if (fileItemCount == NSUIntegerMax) {
            return PXOptionalFailObject(error,
                                        PXOptionalRestoreStagingErrorLimitExceeded,
                                        @"$",
                                        @"The optional Restore item count overflowed.");
        }
        fileItemCount++;
    }
    if (fileItemCount > PXOptionalMaximumFileItems) {
        return PXOptionalFailObject(error,
                                    PXOptionalRestoreStagingErrorLimitExceeded,
                                    @"$",
                                    @"The optional Restore file-item limit was exceeded.");
    }

    NSString *mobileLibraryPath = nil;
    PXOptionalIdentity mobileLibraryIdentity;
    memset(&mobileLibraryIdentity, 0, sizeof(mobileLibraryIdentity));
    if (!PXOptionalResolveMobileLibrary(&mobileLibraryPath,
                                        &mobileLibraryIdentity,
                                        error)) {
        return nil;
    }

    NSMutableArray<PXOptionalDestinationRecord *> *inventory = [NSMutableArray array];
    PXOptionalDestinationRecord *profileRecord = nil;
    PXOptionalDestinationRecord *globalSafariRecord = nil;
    PXOptionalDestinationRecord *preferencesRecord = nil;
    NSMutableDictionary<NSString *, PXOptionalDestinationRecord *> *systemRecords =
        [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, PXOptionalDestinationRecord *> *sharedRecords =
        [NSMutableDictionary dictionary];

    if (restorePlan.includesProfileAppData) {
        NSArray *components = @[@"WeaponX", @"Profiles", profileIdentifier, @"appdata", bundleIdentifier];
        profileRecord = PXOptionalInspectDestination(mobileLibraryPath,
                                                     mobileLibraryIdentity,
                                                     components,
                                                     PXOptionalDestinationTypeDirectory,
                                                     NO,
                                                     @"$.profileAppData.destination",
                                                     PXOptionalRestoreStagingErrorMissingDestination,
                                                     error);
        if (!profileRecord ||
            !PXOptionalRevalidateDestinationRecord(mobileLibraryPath,
                                                   mobileLibraryIdentity,
                                                   profileRecord,
                                                   error)) {
            return nil;
        }
        [inventory addObject:profileRecord];
    }

    if (restorePlan.includesGlobalSafari) {
        globalSafariRecord = PXOptionalInspectDestination(mobileLibraryPath,
                                                          mobileLibraryIdentity,
                                                          @[@"Safari"],
                                                          PXOptionalDestinationTypeDirectory,
                                                          NO,
                                                          @"$.globalSafari.destination",
                                                          PXOptionalRestoreStagingErrorMissingDestination,
                                                          error);
        if (!globalSafariRecord ||
            !PXOptionalRevalidateDestinationRecord(mobileLibraryPath,
                                                   mobileLibraryIdentity,
                                                   globalSafariRecord,
                                                   error)) {
            return nil;
        }
        [inventory addObject:globalSafariRecord];
    }

    NSMutableSet<NSString *> *systemKeys = [NSMutableSet set];
    for (NSUInteger index = 0; index < restorePlan.systemGlobalItems.count; index++) {
        id candidate = restorePlan.systemGlobalItems[index];
        NSString *fieldPath = [NSString stringWithFormat:@"$.systemGlobalItems[%lu].destination",
                               (unsigned long)index];
        if (![candidate isKindOfClass:[PXRestorePlanSystemGlobalItem class]]) {
            return PXOptionalFailObject(error,
                                        PXOptionalRestoreStagingErrorInconsistentPlan,
                                        fieldPath,
                                        @"The system-global destination plan is inconsistent.");
        }
        PXRestorePlanSystemGlobalItem *item = candidate;
        NSString *subdirectory = item.librarySubdirectory;
        if (!PXOptionalSafeComponent(subdirectory) ||
            [systemKeys containsObject:subdirectory]) {
            return PXOptionalFailObject(error,
                                        PXOptionalRestoreStagingErrorInconsistentPlan,
                                        fieldPath,
                                        @"The system-global destination plan is inconsistent.");
        }
        [systemKeys addObject:[subdirectory copy]];
        if ([bundleIdentifier isEqualToString:@"com.apple.mobilesafari"] &&
            [subdirectory isEqualToString:@"Safari"] &&
            restorePlan.includesGlobalSafari) {
            continue;
        }
        PXOptionalDestinationRecord *record =
            PXOptionalInspectDestination(mobileLibraryPath,
                                         mobileLibraryIdentity,
                                         @[subdirectory],
                                         PXOptionalDestinationTypeDirectory,
                                         YES,
                                         fieldPath,
                                         PXOptionalRestoreStagingErrorUnsafeDestination,
                                         error);
        if (!record ||
            !PXOptionalRevalidateDestinationRecord(mobileLibraryPath,
                                                   mobileLibraryIdentity,
                                                   record,
                                                   error)) {
            return nil;
        }
        systemRecords[subdirectory] = record;
        [inventory addObject:record];
    }

    NSMutableSet<NSString *> *sharedKeys = [NSMutableSet set];
    for (NSUInteger index = 0; index < restorePlan.sharedDatabaseItems.count; index++) {
        id candidate = restorePlan.sharedDatabaseItems[index];
        NSString *fieldPath = [NSString stringWithFormat:@"$.sharedDatabaseItems[%lu].destination",
                               (unsigned long)index];
        if (![candidate isKindOfClass:[PXRestorePlanSharedDatabaseItem class]]) {
            return PXOptionalFailObject(error,
                                        PXOptionalRestoreStagingErrorInconsistentPlan,
                                        fieldPath,
                                        @"The shared database destination plan is inconsistent.");
        }
        PXRestorePlanSharedDatabaseItem *item = candidate;
        NSString *relativePath = item.libraryRelativePath;
        NSArray<NSString *> *components = PXOptionalSafeRelativeComponents(relativePath);
        if (!components || [sharedKeys containsObject:relativePath]) {
            return PXOptionalFailObject(error,
                                        PXOptionalRestoreStagingErrorInconsistentPlan,
                                        fieldPath,
                                        @"The shared database destination plan is inconsistent.");
        }
        [sharedKeys addObject:[relativePath copy]];
        PXOptionalDestinationRecord *record =
            PXOptionalInspectDestination(mobileLibraryPath,
                                         mobileLibraryIdentity,
                                         components,
                                         PXOptionalDestinationTypeRegularFile,
                                         YES,
                                         fieldPath,
                                         PXOptionalRestoreStagingErrorMissingDestination,
                                         error);
        if (!record ||
            !PXOptionalRevalidateDestinationRecord(mobileLibraryPath,
                                                   mobileLibraryIdentity,
                                                   record,
                                                   error)) {
            return nil;
        }
        sharedRecords[relativePath] = record;
        [inventory addObject:record];
    }

    if (restorePlan.includesPreferences) {
        NSString *preferenceFilename = [bundleIdentifier stringByAppendingString:@".plist"];
        if (!PXOptionalSafeComponent(preferenceFilename)) {
            return PXOptionalFailObject(error,
                                        PXOptionalRestoreStagingErrorUnsafeDestination,
                                        @"$.preferences.destination",
                                        @"The Preferences destination identity is unsafe.");
        }
        preferencesRecord =
            PXOptionalInspectDestination(mobileLibraryPath,
                                         mobileLibraryIdentity,
                                         @[@"Preferences", preferenceFilename],
                                         PXOptionalDestinationTypeRegularFile,
                                         YES,
                                         @"$.preferences.destination",
                                         PXOptionalRestoreStagingErrorMissingDestination,
                                         error);
        if (!preferencesRecord ||
            !PXOptionalRevalidateDestinationRecord(mobileLibraryPath,
                                                   mobileLibraryIdentity,
                                                   preferencesRecord,
                                                   error)) {
            return nil;
        }
        [inventory addObject:preferencesRecord];
    }

    NSUInteger tarDirectoryCount = systemRecords.count;
    if (restorePlan.includesProfileAppData) {
        if (tarDirectoryCount == NSUIntegerMax) {
            return PXOptionalFailObject(error,
                                        PXOptionalRestoreStagingErrorLimitExceeded,
                                        @"$",
                                        @"The optional Restore item count overflowed.");
        }
        tarDirectoryCount++;
    }
    if (restorePlan.includesGlobalSafari) {
        if (tarDirectoryCount == NSUIntegerMax) {
            return PXOptionalFailObject(error,
                                        PXOptionalRestoreStagingErrorLimitExceeded,
                                        @"$",
                                        @"The optional Restore item count overflowed.");
        }
        tarDirectoryCount++;
    }
    if (tarDirectoryCount > PXOptionalMaximumTarDirectoryItems ||
        tarDirectoryCount > NSUIntegerMax - fileItemCount ||
        tarDirectoryCount + fileItemCount > PXOptionalMaximumTotalItems) {
        return PXOptionalFailObject(error,
                                    PXOptionalRestoreStagingErrorLimitExceeded,
                                    @"$",
                                    @"The optional Restore item limit was exceeded.");
    }

    for (NSUInteger leftIndex = 0; leftIndex < inventory.count; leftIndex++) {
        PXOptionalDestinationRecord *left = inventory[leftIndex];
        for (NSUInteger rightIndex = leftIndex + 1; rightIndex < inventory.count; rightIndex++) {
            PXOptionalDestinationRecord *right = inventory[rightIndex];
            if ([left.path isEqualToString:right.path] ||
                PXOptionalPathIsAncestor(left.path, right.path) ||
                PXOptionalPathIsAncestor(right.path, left.path)) {
                return PXOptionalFailObject(error,
                                            PXOptionalRestoreStagingErrorInconsistentPlan,
                                            @"$",
                                            @"Optional Restore destinations overlap unsafely.");
            }
        }
    }

    PXOptionalRestoreDestinationPlan *plan =
        [[PXOptionalRestoreDestinationPlan alloc]
            initWithMobileLibraryPath:mobileLibraryPath
               mobileLibraryIdentity:mobileLibraryIdentity
                       profileRecord:profileRecord
                  globalSafariRecord:globalSafariRecord
                   preferencesRecord:preferencesRecord
         systemRecordsBySubdirectory:systemRecords
         sharedRecordsByRelativePath:sharedRecords];
    if (!plan) {
        return PXOptionalFailObject(error,
                                    PXOptionalRestoreStagingErrorInconsistentPlan,
                                    @"$",
                                    @"The optional Restore destination plan could not be represented safely.");
    }
    return plan;
}

- (NSString *)systemGlobalPathForSubdirectory:(NSString *)subdirectory {
    if (![subdirectory isKindOfClass:[NSString class]] || subdirectory.length == 0) {
        return nil;
    }
    return self.systemGlobalPathsBySubdirectory[subdirectory];
}

- (NSString *)sharedDatabasePathForRelativePath:(NSString *)relativePath {
    if (![relativePath isKindOfClass:[NSString class]] || relativePath.length == 0) {
        return nil;
    }
    return self.sharedDatabasePathsByRelativePath[relativePath];
}

- (NSString *)revalidatedProfileAppDataPathWithError:(NSError **)error {
    if (error) {
        *error = nil;
    }
    return PXOptionalRevalidateDestinationRecord(self.mobileLibraryPath,
                                                 self.mobileLibraryIdentity,
                                                 self.profileRecord,
                                                 error);
}

- (NSString *)revalidatedGlobalSafariPathWithError:(NSError **)error {
    if (error) {
        *error = nil;
    }
    return PXOptionalRevalidateDestinationRecord(self.mobileLibraryPath,
                                                 self.mobileLibraryIdentity,
                                                 self.globalSafariRecord,
                                                 error);
}

- (NSString *)revalidatedPreferencesPathWithError:(NSError **)error {
    if (error) {
        *error = nil;
    }
    return PXOptionalRevalidateDestinationRecord(self.mobileLibraryPath,
                                                 self.mobileLibraryIdentity,
                                                 self.preferencesRecord,
                                                 error);
}

- (NSString *)revalidatedSystemGlobalPathForSubdirectory:(NSString *)subdirectory
                                                   error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    if (![subdirectory isKindOfClass:[NSString class]] || subdirectory.length == 0) {
        return PXOptionalFailObject(error,
                                    PXOptionalRestoreStagingErrorInvalidInput,
                                    @"$",
                                    @"The system-global destination key is invalid.");
    }
    return PXOptionalRevalidateDestinationRecord(self.mobileLibraryPath,
                                                 self.mobileLibraryIdentity,
                                                 self.systemRecordsBySubdirectory[subdirectory],
                                                 error);
}

- (NSString *)revalidatedSharedDatabasePathForRelativePath:(NSString *)relativePath
                                                     error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    if (![relativePath isKindOfClass:[NSString class]] || relativePath.length == 0) {
        return PXOptionalFailObject(error,
                                    PXOptionalRestoreStagingErrorInvalidInput,
                                    @"$",
                                    @"The shared database destination key is invalid.");
    }
    return PXOptionalRevalidateDestinationRecord(self.mobileLibraryPath,
                                                 self.mobileLibraryIdentity,
                                                 self.sharedRecordsByRelativePath[relativePath],
                                                 error);
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

@end
