#import "PXMainDataStaging.h"
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

NSString * const PXMainDataStagingErrorDomain = @"PXMainDataStagingErrorDomain";
NSString * const PXMainDataStagingErrorFieldPathKey = @"PXMainDataStagingErrorFieldPathKey";

static NSString * const PXMainDataStagingParentPath = @"/private/var/tmp";
static const NSUInteger PXMainDataMaximumLogicalMembers = 200000;
static const NSUInteger PXMainDataMaximumImplicitDirectories = 200000;
static const NSUInteger PXMainDataMaximumStagedEntries = 400000;
static const NSUInteger PXMainDataMaximumCleanupEntries = 500000;
static const NSUInteger PXMainDataMaximumPathBytes = 4096;
static const NSUInteger PXMainDataMaximumComponentBytes = 255;
static const NSUInteger PXMainDataMaximumDepth = 2048;
static const size_t PXMainDataReadBufferSize = 64 * 1024;

typedef struct {
    dev_t device;
    ino_t inode;
    mode_t mode;
    struct timespec modificationTime;
    struct timespec changeTime;
} PXMainDataIdentity;

static PXMainDataIdentity PXMainDataIdentityFromStat(const struct stat *value) {
    PXMainDataIdentity identity;
    identity.device = value->st_dev;
    identity.inode = value->st_ino;
    identity.mode = value->st_mode;
    identity.modificationTime = value->st_mtimespec;
    identity.changeTime = value->st_ctimespec;
    return identity;
}

static BOOL PXMainDataTimesEqual(struct timespec left, struct timespec right) {
    return left.tv_sec == right.tv_sec && left.tv_nsec == right.tv_nsec;
}

static BOOL PXMainDataIdentityMatchesBasic(PXMainDataIdentity expected,
                                           const struct stat *actual) {
    return expected.device == actual->st_dev &&
           expected.inode == actual->st_ino &&
           ((expected.mode & S_IFMT) == (actual->st_mode & S_IFMT));
}

static BOOL PXMainDataIdentityMatchesStableDirectory(PXMainDataIdentity expected,
                                                     const struct stat *actual) {
    return PXMainDataIdentityMatchesBasic(expected, actual) &&
           PXMainDataTimesEqual(expected.modificationTime, actual->st_mtimespec) &&
           PXMainDataTimesEqual(expected.changeTime, actual->st_ctimespec);
}

static BOOL PXMainDataStableFileStatsEqual(const struct stat *before,
                                           const struct stat *after) {
    return before->st_dev == after->st_dev &&
           before->st_ino == after->st_ino &&
           ((before->st_mode & S_IFMT) == (after->st_mode & S_IFMT)) &&
           before->st_nlink == after->st_nlink &&
           before->st_size == after->st_size &&
           PXMainDataTimesEqual(before->st_mtimespec, after->st_mtimespec) &&
           PXMainDataTimesEqual(before->st_ctimespec, after->st_ctimespec);
}

static BOOL PXMainDataFail(NSError **error,
                           PXMainDataStagingErrorCode code,
                           NSString *fieldPath,
                           NSString *description) {
    if (error) {
        *error = [NSError errorWithDomain:PXMainDataStagingErrorDomain
                                     code:code
                                 userInfo:@{
                                     NSLocalizedDescriptionKey: description,
                                     PXMainDataStagingErrorFieldPathKey: fieldPath
                                 }];
    }
    return NO;
}

static id PXMainDataFailObject(NSError **error,
                               PXMainDataStagingErrorCode code,
                               NSString *fieldPath,
                               NSString *description) {
    PXMainDataFail(error, code, fieldPath, description);
    return nil;
}

static void PXMainDataCloseDescriptor(int *descriptor) {
    if (descriptor && *descriptor >= 0) {
        close(*descriptor);
        *descriptor = -1;
    }
}

static BOOL PXMainDataSetCloseOnExec(int descriptor) {
    int flags = fcntl(descriptor, F_GETFD);
    if (flags < 0) {
        return NO;
    }
    if ((flags & FD_CLOEXEC) == 0 &&
        fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC) < 0) {
        return NO;
    }
    int verified = fcntl(descriptor, F_GETFD);
    return verified >= 0 && (verified & FD_CLOEXEC) != 0;
}

static int PXMainDataDuplicateDescriptor(int descriptor) {
    int duplicate = dup(descriptor);
    if (duplicate < 0) {
        return -1;
    }
    if (!PXMainDataSetCloseOnExec(duplicate)) {
        close(duplicate);
        return -1;
    }
    return duplicate;
}

static NSComparisonResult PXMainDataCompareRawNames(NSData *left, NSData *right) {
    NSUInteger commonLength = MIN(left.length, right.length);
    int result = commonLength > 0 ? memcmp(left.bytes, right.bytes, commonLength) : 0;
    if (result < 0) {
        return NSOrderedAscending;
    }
    if (result > 0) {
        return NSOrderedDescending;
    }
    if (left.length < right.length) {
        return NSOrderedAscending;
    }
    if (left.length > right.length) {
        return NSOrderedDescending;
    }
    return NSOrderedSame;
}

static NSArray<NSData *> *PXMainDataReadDirectoryNames(int descriptor,
                                                       NSUInteger maximumNameCount,
                                                       PXMainDataStagingErrorCode code,
                                                       PXMainDataStagingErrorCode limitCode,
                                                       NSString *fieldPath,
                                                       NSError **error) {
    int enumerationDescriptor = PXMainDataDuplicateDescriptor(descriptor);
    if (enumerationDescriptor < 0 ||
        lseek(enumerationDescriptor, 0, SEEK_SET) < 0) {
        if (enumerationDescriptor >= 0) {
            close(enumerationDescriptor);
        }
        return PXMainDataFailObject(error,
                                    code,
                                    fieldPath,
                                    @"A directory enumeration descriptor could not be prepared.");
    }

    DIR *directory = fdopendir(enumerationDescriptor);
    if (!directory) {
        close(enumerationDescriptor);
        return PXMainDataFailObject(error,
                                    code,
                                    fieldPath,
                                    @"A directory could not be enumerated.");
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
        if (names.count >= maximumNameCount) {
            closedir(directory);
            return PXMainDataFailObject(error,
                                        limitCode,
                                        fieldPath,
                                        @"A directory entry limit was exceeded.");
        }
        size_t length = strlen(name);
        NSData *nameData = [NSData dataWithBytes:name length:length];
        [names addObject:nameData];
    }
    int enumerationError = errno;
    if (closedir(directory) != 0 && enumerationError == 0) {
        enumerationError = errno ?: EIO;
    }
    if (enumerationError != 0) {
        return PXMainDataFailObject(error,
                                    code,
                                    fieldPath,
                                    @"Directory enumeration did not complete safely.");
    }

    return [names sortedArrayUsingComparator:^NSComparisonResult(NSData *left, NSData *right) {
        return PXMainDataCompareRawNames(left, right);
    }];
}

static char *PXMainDataCopyTerminatedName(NSData *nameData) {
    if (nameData.length > SIZE_MAX - 1) {
        return NULL;
    }
    char *name = calloc(nameData.length + 1, 1);
    if (!name) {
        return NULL;
    }
    if (nameData.length > 0) {
        memcpy(name, nameData.bytes, nameData.length);
    }
    return name;
}

static BOOL PXMainDataRawNameEquals(NSData *nameData, const char *literal) {
    size_t length = strlen(literal);
    return nameData.length == length &&
           (length == 0 || memcmp(nameData.bytes, literal, length) == 0);
}

static NSString *PXMainDataStrictStringForName(NSData *nameData) {
    NSString *value = [[NSString alloc] initWithData:nameData
                                             encoding:NSUTF8StringEncoding];
    if (!value) {
        return nil;
    }
    NSData *roundTrip = [value dataUsingEncoding:NSUTF8StringEncoding
                            allowLossyConversion:NO];
    if (!roundTrip || ![roundTrip isEqualToData:nameData]) {
        return nil;
    }
    return value;
}

static BOOL PXMainDataNameBytesAreSafe(NSData *nameData) {
    if (nameData.length == 0 || nameData.length > PXMainDataMaximumComponentBytes) {
        return NO;
    }
    const unsigned char *bytes = nameData.bytes;
    for (NSUInteger index = 0; index < nameData.length; index++) {
        unsigned char value = bytes[index];
        if (value == 0 || value < 0x20 || value == 0x7f || value == '\\' || value == '/') {
            return NO;
        }
    }
    return !PXMainDataRawNameEquals(nameData, ".") &&
           !PXMainDataRawNameEquals(nameData, "..");
}

static NSData *PXMainDataRelativePath(NSData *parent,
                                      NSData *name,
                                      NSError **error,
                                      NSString *fieldPath) {
    NSUInteger separatorLength = parent.length > 0 ? 1 : 0;
    if (parent.length > NSUIntegerMax - separatorLength ||
        parent.length + separatorLength > NSUIntegerMax - name.length) {
        return PXMainDataFailObject(error,
                                    PXMainDataStagingErrorLimitExceeded,
                                    fieldPath,
                                    @"A staged path length overflowed.");
    }
    NSUInteger totalLength = parent.length + separatorLength + name.length;
    if (totalLength > PXMainDataMaximumPathBytes) {
        return PXMainDataFailObject(error,
                                    PXMainDataStagingErrorUnsafeEntryPath,
                                    fieldPath,
                                    @"A staged path exceeds the fixed path limit.");
    }
    NSMutableData *path = [NSMutableData dataWithCapacity:totalLength];
    if (parent.length > 0) {
        [path appendData:parent];
        const unsigned char separator = '/';
        [path appendBytes:&separator length:1];
    }
    [path appendData:name];
    return [path copy];
}

static void PXMainDataHashUInt32(CC_SHA256_CTX *context, uint32_t value) {
    unsigned char bytes[4] = {
        (unsigned char)((value >> 24) & 0xff),
        (unsigned char)((value >> 16) & 0xff),
        (unsigned char)((value >> 8) & 0xff),
        (unsigned char)(value & 0xff)
    };
    CC_SHA256_Update(context, bytes, (CC_LONG)sizeof(bytes));
}

static void PXMainDataHashUInt64(CC_SHA256_CTX *context, uint64_t value) {
    unsigned char bytes[8] = {
        (unsigned char)((value >> 56) & 0xff),
        (unsigned char)((value >> 48) & 0xff),
        (unsigned char)((value >> 40) & 0xff),
        (unsigned char)((value >> 32) & 0xff),
        (unsigned char)((value >> 24) & 0xff),
        (unsigned char)((value >> 16) & 0xff),
        (unsigned char)((value >> 8) & 0xff),
        (unsigned char)(value & 0xff)
    };
    CC_SHA256_Update(context, bytes, (CC_LONG)sizeof(bytes));
}

static void PXMainDataHashEntryHeader(CC_SHA256_CTX *context,
                                      unsigned char type,
                                      NSData *relativePath,
                                      mode_t mode,
                                      uint64_t size) {
    CC_SHA256_Update(context, &type, 1);
    PXMainDataHashUInt32(context, (uint32_t)relativePath.length);
    if (relativePath.length > 0) {
        CC_SHA256_Update(context, relativePath.bytes, (CC_LONG)relativePath.length);
    }
    PXMainDataHashUInt32(context, (uint32_t)(mode & 07777));
    PXMainDataHashUInt64(context, size);
}

static NSString *PXMainDataLowercaseHexDigest(const unsigned char digest[CC_SHA256_DIGEST_LENGTH]) {
    static const char hex[] = "0123456789abcdef";
    char output[(CC_SHA256_DIGEST_LENGTH * 2) + 1];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
        output[index * 2] = hex[(digest[index] >> 4) & 0x0f];
        output[(index * 2) + 1] = hex[digest[index] & 0x0f];
    }
    output[CC_SHA256_DIGEST_LENGTH * 2] = '\0';
    return [NSString stringWithUTF8String:output];
}

@interface PXStageDirectoryFrame : NSObject
@property (nonatomic, assign) int descriptor;
@property (nonatomic, copy) NSArray<NSData *> *names;
@property (nonatomic, assign) NSUInteger nextIndex;
@property (nonatomic, copy) NSData *relativePath;
@property (nonatomic, copy) NSString *fieldPath;
@property (nonatomic, assign) NSUInteger depth;
@property (nonatomic, assign) PXMainDataIdentity identity;
@end

@implementation PXStageDirectoryFrame
- (instancetype)init {
    self = [super init];
    if (self) {
        _descriptor = -1;
    }
    return self;
}
- (void)dealloc {
    if (_descriptor >= 0) {
        close(_descriptor);
        _descriptor = -1;
    }
}
@end

@interface PXCleanupDirectoryFrame : NSObject
@property (nonatomic, assign) int descriptor;
@property (nonatomic, copy) NSArray<NSData *> *names;
@property (nonatomic, assign) NSUInteger nextIndex;
@property (nonatomic, copy, nullable) NSData *entryName;
@property (nonatomic, assign) NSUInteger depth;
@property (nonatomic, assign) PXMainDataIdentity identity;
@end

@implementation PXCleanupDirectoryFrame
- (instancetype)init {
    self = [super init];
    if (self) {
        _descriptor = -1;
    }
    return self;
}
- (void)dealloc {
    if (_descriptor >= 0) {
        close(_descriptor);
        _descriptor = -1;
    }
}
@end

static PXStageDirectoryFrame *PXMainDataCreateValidationFrame(int descriptor,
                                                              NSData *relativePath,
                                                              NSUInteger depth,
                                                              NSUInteger maximumNameCount,
                                                              dev_t expectedDevice,
                                                              NSString *fieldPath,
                                                              NSError **error) {
    struct stat before;
    struct stat after;
    memset(&before, 0, sizeof(before));
    memset(&after, 0, sizeof(after));
    if (fstat(descriptor, &before) != 0 ||
        !S_ISDIR(before.st_mode) ||
        before.st_dev != expectedDevice ||
        (before.st_mode & (S_ISUID | S_ISGID)) != 0) {
        close(descriptor);
        return PXMainDataFailObject(error,
                                    PXMainDataStagingErrorUnsupportedEntryType,
                                    fieldPath,
                                    @"A staged directory is not supported.");
    }
    NSArray<NSData *> *names = PXMainDataReadDirectoryNames(descriptor,
                                                           maximumNameCount,
                                                           PXMainDataStagingErrorEnumerationFailed,
                                                           PXMainDataStagingErrorLimitExceeded,
                                                           fieldPath,
                                                           error);
    if (!names) {
        close(descriptor);
        return nil;
    }
    if (fstat(descriptor, &after) != 0 ||
        !PXMainDataIdentityMatchesStableDirectory(PXMainDataIdentityFromStat(&before), &after)) {
        close(descriptor);
        return PXMainDataFailObject(error,
                                    PXMainDataStagingErrorFilesystemChanged,
                                    fieldPath,
                                    @"A staged directory changed during enumeration.");
    }
    PXStageDirectoryFrame *frame = [[PXStageDirectoryFrame alloc] init];
    frame.descriptor = descriptor;
    frame.names = names;
    frame.nextIndex = 0;
    frame.relativePath = [relativePath copy];
    frame.fieldPath = [fieldPath copy];
    frame.depth = depth;
    frame.identity = PXMainDataIdentityFromStat(&before);
    return frame;
}

static BOOL PXMainDataCleanupStatsMatch(const struct stat *first,
                                        const struct stat *second) {
    return first->st_dev == second->st_dev &&
           first->st_ino == second->st_ino &&
           ((first->st_mode & S_IFMT) == (second->st_mode & S_IFMT));
}

@interface PXValidatedMainDataStage ()
- (instancetype)initWithWorkspaceRootPath:(NSString *)workspaceRootPath
                                 dataPath:(NSString *)dataPath
                               entryCount:(NSUInteger)entryCount
                         regularFileCount:(NSUInteger)regularFileCount
                           directoryCount:(NSUInteger)directoryCount
                         regularFileBytes:(unsigned long long)regularFileBytes
                               treeSHA256:(NSString *)treeSHA256;
@end

@implementation PXValidatedMainDataStage

- (instancetype)initWithWorkspaceRootPath:(NSString *)workspaceRootPath
                                 dataPath:(NSString *)dataPath
                               entryCount:(NSUInteger)entryCount
                         regularFileCount:(NSUInteger)regularFileCount
                           directoryCount:(NSUInteger)directoryCount
                         regularFileBytes:(unsigned long long)regularFileBytes
                               treeSHA256:(NSString *)treeSHA256 {
    self = [super init];
    if (self) {
        _workspaceRootPath = [workspaceRootPath copy];
        _dataPath = [dataPath copy];
        _entryCount = entryCount;
        _regularFileCount = regularFileCount;
        _directoryCount = directoryCount;
        _regularFileBytes = regularFileBytes;
        _treeSHA256 = [treeSHA256 copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

@end

@interface PXMainDataStagingWorkspace ()
@property (nonatomic, copy, readwrite) NSString *rootPath;
@property (nonatomic, copy, readwrite) NSString *dataPath;
@property (nonatomic, copy) NSString *rootBasename;
@property (nonatomic, assign) int parentDescriptor;
@property (nonatomic, assign) int rootDescriptor;
@property (nonatomic, assign) int dataDescriptor;
@property (nonatomic, assign) PXMainDataIdentity parentIdentity;
@property (nonatomic, assign) PXMainDataIdentity rootIdentity;
@property (nonatomic, assign) PXMainDataIdentity dataIdentity;
@property (nonatomic, assign) BOOL cleaned;
- (instancetype)initWithRootPath:(NSString *)rootPath
                        dataPath:(NSString *)dataPath
                    rootBasename:(NSString *)rootBasename
                parentDescriptor:(int)parentDescriptor
                  rootDescriptor:(int)rootDescriptor
                  dataDescriptor:(int)dataDescriptor
                  parentIdentity:(PXMainDataIdentity)parentIdentity
                    rootIdentity:(PXMainDataIdentity)rootIdentity
                    dataIdentity:(PXMainDataIdentity)dataIdentity;
- (BOOL)verifyWorkspaceIdentityWithError:(NSError * _Nullable * _Nullable)error;
- (BOOL)closeOwnedDescriptorsAfterCleanupFailure:(NSError * _Nullable * _Nullable)error;
@end

@implementation PXMainDataStagingWorkspace

- (instancetype)initWithRootPath:(NSString *)rootPath
                        dataPath:(NSString *)dataPath
                    rootBasename:(NSString *)rootBasename
                parentDescriptor:(int)parentDescriptor
                  rootDescriptor:(int)rootDescriptor
                  dataDescriptor:(int)dataDescriptor
                  parentIdentity:(PXMainDataIdentity)parentIdentity
                    rootIdentity:(PXMainDataIdentity)rootIdentity
                    dataIdentity:(PXMainDataIdentity)dataIdentity {
    self = [super init];
    if (self) {
        _rootPath = [rootPath copy];
        _dataPath = [dataPath copy];
        _rootBasename = [rootBasename copy];
        _parentDescriptor = parentDescriptor;
        _rootDescriptor = rootDescriptor;
        _dataDescriptor = dataDescriptor;
        _parentIdentity = parentIdentity;
        _rootIdentity = rootIdentity;
        _dataIdentity = dataIdentity;
        _cleaned = NO;
    }
    return self;
}

+ (instancetype)createWorkspaceWithError:(NSError **)error {
    if (error) {
        *error = nil;
    }

    int parentDescriptor = -1;
    int rootDescriptor = -1;
    int dataDescriptor = -1;
    BOOL rootCreated = NO;
    BOOL dataCreated = NO;
    NSString *rootBasename = nil;
    NSString *rootPath = nil;
    NSString *dataPath = nil;
    PXMainDataStagingErrorCode failureCode = PXMainDataStagingErrorWorkspaceCreationFailed;
    NSString *failureField = @"$.workspace";
    NSString *failureDescription = @"The private main-data staging workspace could not be created.";

    struct stat parentPathStat;
    memset(&parentPathStat, 0, sizeof(parentPathStat));
    if (lstat(PXMainDataStagingParentPath.fileSystemRepresentation, &parentPathStat) != 0 ||
        !S_ISDIR(parentPathStat.st_mode)) {
        goto failure;
    }

    parentDescriptor = open(PXMainDataStagingParentPath.fileSystemRepresentation,
                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (parentDescriptor < 0 || !PXMainDataSetCloseOnExec(parentDescriptor)) {
        goto failure;
    }
    struct stat parentDescriptorStat;
    memset(&parentDescriptorStat, 0, sizeof(parentDescriptorStat));
    if (fstat(parentDescriptor, &parentDescriptorStat) != 0 ||
        !S_ISDIR(parentDescriptorStat.st_mode) ||
        parentDescriptorStat.st_dev != parentPathStat.st_dev ||
        parentDescriptorStat.st_ino != parentPathStat.st_ino) {
        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
        goto failure;
    }

    char workspaceTemplate[] = "/private/var/tmp/weaponx_restore_main.XXXXXX";
    char *generatedPath = mkdtemp(workspaceTemplate);
    if (!generatedPath) {
        goto failure;
    }
    rootCreated = YES;

    const char prefix[] = "/private/var/tmp/";
    size_t prefixLength = sizeof(prefix) - 1;
    size_t generatedLength = strlen(generatedPath);
    if (generatedLength <= prefixLength ||
        memcmp(generatedPath, prefix, prefixLength) != 0 ||
        strchr(generatedPath + prefixLength, '/') != NULL) {
        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
        goto failure;
    }
    rootBasename = [NSString stringWithUTF8String:generatedPath + prefixLength];
    rootPath = [NSString stringWithUTF8String:generatedPath];
    if (!rootBasename.length || !rootPath.length ||
        ![rootBasename hasPrefix:@"weaponx_restore_main."]) {
        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
        goto failure;
    }

    struct stat parentPathAfterCreation;
    memset(&parentPathAfterCreation, 0, sizeof(parentPathAfterCreation));
    if (lstat(PXMainDataStagingParentPath.fileSystemRepresentation,
              &parentPathAfterCreation) != 0 ||
        !S_ISDIR(parentPathAfterCreation.st_mode) ||
        parentPathAfterCreation.st_dev != parentDescriptorStat.st_dev ||
        parentPathAfterCreation.st_ino != parentDescriptorStat.st_ino) {
        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
        goto failure;
    }

    struct stat rootPathStat;
    memset(&rootPathStat, 0, sizeof(rootPathStat));
    if (lstat(generatedPath, &rootPathStat) != 0 || !S_ISDIR(rootPathStat.st_mode)) {
        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
        goto failure;
    }
    rootDescriptor = openat(parentDescriptor,
                            rootBasename.fileSystemRepresentation,
                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (rootDescriptor < 0 || !PXMainDataSetCloseOnExec(rootDescriptor)) {
        goto failure;
    }
    struct stat rootDescriptorStat;
    memset(&rootDescriptorStat, 0, sizeof(rootDescriptorStat));
    if (fstat(rootDescriptor, &rootDescriptorStat) != 0 ||
        !S_ISDIR(rootDescriptorStat.st_mode) ||
        rootDescriptorStat.st_dev != rootPathStat.st_dev ||
        rootDescriptorStat.st_ino != rootPathStat.st_ino) {
        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
        goto failure;
    }
    if ((rootDescriptorStat.st_mode & 07777) != 0700) {
        if (fchmod(rootDescriptor, 0700) != 0 ||
            fstat(rootDescriptor, &rootDescriptorStat) != 0 ||
            (rootDescriptorStat.st_mode & 07777) != 0700) {
            goto failure;
        }
    }

    if (mkdirat(rootDescriptor, "data", 0700) != 0) {
        goto failure;
    }
    dataCreated = YES;
    dataDescriptor = openat(rootDescriptor,
                            "data",
                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (dataDescriptor < 0 || !PXMainDataSetCloseOnExec(dataDescriptor)) {
        goto failure;
    }
    struct stat dataDescriptorStat;
    memset(&dataDescriptorStat, 0, sizeof(dataDescriptorStat));
    if (fstat(dataDescriptor, &dataDescriptorStat) != 0 ||
        !S_ISDIR(dataDescriptorStat.st_mode)) {
        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
        goto failure;
    }
    if ((dataDescriptorStat.st_mode & 07777) != 0700) {
        if (fchmod(dataDescriptor, 0700) != 0 ||
            fstat(dataDescriptor, &dataDescriptorStat) != 0 ||
            (dataDescriptorStat.st_mode & 07777) != 0700) {
            goto failure;
        }
    }

    struct stat dataPathStat;
    memset(&dataPathStat, 0, sizeof(dataPathStat));
    if (fstatat(rootDescriptor, "data", &dataPathStat, AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISDIR(dataPathStat.st_mode) ||
        dataPathStat.st_dev != dataDescriptorStat.st_dev ||
        dataPathStat.st_ino != dataDescriptorStat.st_ino ||
        dataDescriptorStat.st_dev != rootDescriptorStat.st_dev) {
        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
        failureField = @"$.data";
        goto failure;
    }

    if (fstat(parentDescriptor, &parentDescriptorStat) != 0 ||
        fstat(rootDescriptor, &rootDescriptorStat) != 0 ||
        fstat(dataDescriptor, &dataDescriptorStat) != 0) {
        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
        goto failure;
    }
    if ((rootDescriptorStat.st_mode & 07777) != 0700 ||
        (dataDescriptorStat.st_mode & 07777) != 0700 ||
        (rootDescriptorStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        (dataDescriptorStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
        rootDescriptorStat.st_dev != dataDescriptorStat.st_dev) {
        failureCode = PXMainDataStagingErrorWorkspaceIdentityChanged;
        goto failure;
    }

    dataPath = [rootPath stringByAppendingPathComponent:@"data"];
    if (!dataPath.length) {
        goto failure;
    }

    return [[self alloc] initWithRootPath:rootPath
                                dataPath:dataPath
                            rootBasename:rootBasename
                        parentDescriptor:parentDescriptor
                          rootDescriptor:rootDescriptor
                          dataDescriptor:dataDescriptor
                          parentIdentity:PXMainDataIdentityFromStat(&parentDescriptorStat)
                            rootIdentity:PXMainDataIdentityFromStat(&rootDescriptorStat)
                            dataIdentity:PXMainDataIdentityFromStat(&dataDescriptorStat)];

failure:
    PXMainDataCloseDescriptor(&dataDescriptor);
    if (rootDescriptor >= 0 && dataCreated) {
        unlinkat(rootDescriptor, "data", AT_REMOVEDIR);
    }
    PXMainDataCloseDescriptor(&rootDescriptor);
    if (parentDescriptor >= 0 && rootCreated && rootBasename.length) {
        unlinkat(parentDescriptor,
                 rootBasename.fileSystemRepresentation,
                 AT_REMOVEDIR);
    }
    PXMainDataCloseDescriptor(&parentDescriptor);
    PXMainDataFail(error, failureCode, failureField, failureDescription);
    return nil;
}

- (BOOL)verifyWorkspaceIdentityWithError:(NSError **)error {
    if (self.cleaned ||
        self.parentDescriptor < 0 ||
        self.rootDescriptor < 0 ||
        self.dataDescriptor < 0 ||
        !self.rootBasename.length) {
        return PXMainDataFail(error,
                              PXMainDataStagingErrorInvalidInput,
                              @"$.workspace",
                              @"The staging workspace is no longer available.");
    }

    struct stat parentPathStat;
    struct stat parentDescriptorStat;
    struct stat rootDescriptorStat;
    struct stat dataDescriptorStat;
    struct stat rootPathStat;
    struct stat dataPathStat;
    memset(&parentPathStat, 0, sizeof(parentPathStat));
    memset(&parentDescriptorStat, 0, sizeof(parentDescriptorStat));
    memset(&rootDescriptorStat, 0, sizeof(rootDescriptorStat));
    memset(&dataDescriptorStat, 0, sizeof(dataDescriptorStat));
    memset(&rootPathStat, 0, sizeof(rootPathStat));
    memset(&dataPathStat, 0, sizeof(dataPathStat));

    if (lstat(PXMainDataStagingParentPath.fileSystemRepresentation,
              &parentPathStat) != 0 ||
        fstat(self.parentDescriptor, &parentDescriptorStat) != 0 ||
        fstat(self.rootDescriptor, &rootDescriptorStat) != 0 ||
        fstat(self.dataDescriptor, &dataDescriptorStat) != 0 ||
        fstatat(self.parentDescriptor,
                self.rootBasename.fileSystemRepresentation,
                &rootPathStat,
                AT_SYMLINK_NOFOLLOW) != 0 ||
        fstatat(self.rootDescriptor,
                "data",
                &dataPathStat,
                AT_SYMLINK_NOFOLLOW) != 0) {
        return PXMainDataFail(error,
                              PXMainDataStagingErrorWorkspaceIdentityChanged,
                              @"$.workspace",
                              @"The staging workspace identity could not be verified.");
    }

    BOOL valid = S_ISDIR(parentPathStat.st_mode) &&
                 S_ISDIR(parentDescriptorStat.st_mode) &&
                 PXMainDataIdentityMatchesBasic(self.parentIdentity, &parentPathStat) &&
                 S_ISDIR(rootDescriptorStat.st_mode) &&
                 S_ISDIR(dataDescriptorStat.st_mode) &&
                 S_ISDIR(rootPathStat.st_mode) &&
                 S_ISDIR(dataPathStat.st_mode) &&
                 PXMainDataIdentityMatchesBasic(self.parentIdentity, &parentDescriptorStat) &&
                 PXMainDataIdentityMatchesBasic(self.rootIdentity, &rootDescriptorStat) &&
                 PXMainDataIdentityMatchesBasic(self.dataIdentity, &dataDescriptorStat) &&
                 PXMainDataIdentityMatchesBasic(self.rootIdentity, &rootPathStat) &&
                 PXMainDataIdentityMatchesBasic(self.dataIdentity, &dataPathStat) &&
                 rootDescriptorStat.st_dev == self.rootIdentity.device &&
                 dataDescriptorStat.st_dev == self.rootIdentity.device &&
                 rootPathStat.st_dev == self.rootIdentity.device &&
                 dataPathStat.st_dev == self.rootIdentity.device &&
                 (rootDescriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
                 (dataDescriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0;
    if (!valid) {
        return PXMainDataFail(error,
                              PXMainDataStagingErrorWorkspaceIdentityChanged,
                              @"$.workspace",
                              @"The staging workspace identity changed.");
    }
    return YES;
}

- (BOOL)validateEmptyDataDirectoryWithError:(NSError **)error {
    if (error) {
        *error = nil;
    }
    if (![self verifyWorkspaceIdentityWithError:error]) {
        return NO;
    }

    struct stat rootBefore;
    struct stat rootAfter;
    struct stat dataBefore;
    struct stat dataAfter;
    memset(&rootBefore, 0, sizeof(rootBefore));
    memset(&rootAfter, 0, sizeof(rootAfter));
    memset(&dataBefore, 0, sizeof(dataBefore));
    memset(&dataAfter, 0, sizeof(dataAfter));

    if (fstat(self.rootDescriptor, &rootBefore) != 0 ||
        fstat(self.dataDescriptor, &dataBefore) != 0) {
        return PXMainDataFail(error,
                              PXMainDataStagingErrorEnumerationFailed,
                              @"$.workspace",
                              @"The empty staging workspace could not be inspected.");
    }

    NSArray<NSData *> *rootNames = PXMainDataReadDirectoryNames(self.rootDescriptor,
                                                               2,
                                                               PXMainDataStagingErrorEnumerationFailed,
                                                               PXMainDataStagingErrorWorkspaceNotEmpty,
                                                               @"$.workspace",
                                                               error);
    if (!rootNames) {
        return NO;
    }
    if (rootNames.count != 1 || !PXMainDataRawNameEquals(rootNames.firstObject, "data")) {
        return PXMainDataFail(error,
                              PXMainDataStagingErrorWorkspaceNotEmpty,
                              @"$.workspace",
                              @"The staging workspace root contains an unexpected entry.");
    }

    NSArray<NSData *> *dataNames = PXMainDataReadDirectoryNames(self.dataDescriptor,
                                                               1,
                                                               PXMainDataStagingErrorEnumerationFailed,
                                                               PXMainDataStagingErrorWorkspaceNotEmpty,
                                                               @"$.data",
                                                               error);
    if (!dataNames) {
        return NO;
    }
    if (dataNames.count != 0) {
        return PXMainDataFail(error,
                              PXMainDataStagingErrorWorkspaceNotEmpty,
                              @"$.data",
                              @"The staging data directory is not empty.");
    }

    if (fstat(self.rootDescriptor, &rootAfter) != 0 ||
        fstat(self.dataDescriptor, &dataAfter) != 0 ||
        !PXMainDataIdentityMatchesStableDirectory(PXMainDataIdentityFromStat(&rootBefore), &rootAfter) ||
        !PXMainDataIdentityMatchesStableDirectory(PXMainDataIdentityFromStat(&dataBefore), &dataAfter)) {
        return PXMainDataFail(error,
                              PXMainDataStagingErrorFilesystemChanged,
                              @"$.workspace",
                              @"The staging workspace changed during empty validation.");
    }

    return [self verifyWorkspaceIdentityWithError:error];
}

- (PXValidatedMainDataStage *)validatedStageWithExpectedLogicalMemberCount:(NSUInteger)logicalMemberCount
                                                  expectedRegularFileBytes:(unsigned long long)regularFileBytes
                                                                      error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    if (logicalMemberCount > PXMainDataMaximumLogicalMembers) {
        return PXMainDataFailObject(error,
                                    PXMainDataStagingErrorLimitExceeded,
                                    @"$.data",
                                    @"The accepted archive member limit was exceeded.");
    }
    if (![self verifyWorkspaceIdentityWithError:error]) {
        return nil;
    }

    NSUInteger maximumEntries = 0;
    if (logicalMemberCount > 0) {
        if (logicalMemberCount > NSUIntegerMax - PXMainDataMaximumImplicitDirectories) {
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorLimitExceeded,
                                        @"$.data",
                                        @"The staged entry limit overflowed.");
        }
        maximumEntries = logicalMemberCount + PXMainDataMaximumImplicitDirectories;
        if (maximumEntries > PXMainDataMaximumStagedEntries) {
            maximumEntries = PXMainDataMaximumStagedEntries;
        }
    }

    int rootDataDescriptor = PXMainDataDuplicateDescriptor(self.dataDescriptor);
    if (rootDataDescriptor < 0) {
        return PXMainDataFailObject(error,
                                    PXMainDataStagingErrorEnumerationFailed,
                                    @"$.data",
                                    @"The staged data root could not be opened for validation.");
    }

    NSError *frameError = nil;
    PXStageDirectoryFrame *rootFrame = PXMainDataCreateValidationFrame(rootDataDescriptor,
                                                                      [NSData data],
                                                                      0,
                                                                      maximumEntries,
                                                                      self.dataIdentity.device,
                                                                      @"$.data",
                                                                      &frameError);
    if (!rootFrame) {
        if (error) {
            *error = frameError;
        }
        return nil;
    }

    NSMutableArray<PXStageDirectoryFrame *> *stack = [NSMutableArray arrayWithObject:rootFrame];
    NSUInteger enumeratedEntryCount = rootFrame.names.count;
    NSUInteger entryCount = 0;
    NSUInteger regularFileCount = 0;
    NSUInteger directoryCount = 0;
    unsigned long long actualRegularFileBytes = 0;
    CC_SHA256_CTX digestContext;
    CC_SHA256_Init(&digestContext);
    static const unsigned char domainPrefix[] = "PXMainDataStageTreeV1";
    CC_SHA256_Update(&digestContext, domainPrefix, (CC_LONG)sizeof(domainPrefix));

    while (stack.count > 0) {
        PXStageDirectoryFrame *frame = stack.lastObject;
        if (frame.nextIndex >= frame.names.count) {
            struct stat finalDirectoryStat;
            memset(&finalDirectoryStat, 0, sizeof(finalDirectoryStat));
            if (fstat(frame.descriptor, &finalDirectoryStat) != 0 ||
                !PXMainDataIdentityMatchesStableDirectory(frame.identity, &finalDirectoryStat)) {
                return PXMainDataFailObject(error,
                                            PXMainDataStagingErrorFilesystemChanged,
                                            frame.fieldPath ?: @"$.data",
                                            @"A staged directory changed during validation.");
            }
            [stack removeLastObject];
            continue;
        }

        NSData *nameData = frame.names[frame.nextIndex++];
        NSUInteger currentIndex = entryCount;
        NSString *entryField = [NSString stringWithFormat:@"$.data.entries[%lu]",
                                (unsigned long)currentIndex];
        NSString *pathField = [entryField stringByAppendingString:@".path"];

        if (!PXMainDataNameBytesAreSafe(nameData) || !PXMainDataStrictStringForName(nameData)) {
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorUnsafeEntryPath,
                                        pathField,
                                        @"A staged entry path is unsafe.");
        }
        if (frame.depth >= PXMainDataMaximumDepth) {
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorLimitExceeded,
                                        pathField,
                                        @"The staged tree depth limit was exceeded.");
        }
        NSData *relativePath = PXMainDataRelativePath(frame.relativePath,
                                                      nameData,
                                                      error,
                                                      pathField);
        if (!relativePath) {
            return nil;
        }
        NSUInteger entryDepth = frame.depth + 1;
        if (entryDepth > PXMainDataMaximumDepth) {
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorLimitExceeded,
                                        pathField,
                                        @"The staged tree depth limit was exceeded.");
        }
        if (entryCount == NSUIntegerMax || entryCount >= maximumEntries) {
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorLimitExceeded,
                                        entryField,
                                        @"The staged entry limit was exceeded.");
        }
        entryCount++;

        if (entryDepth == 1 &&
            (PXMainDataRawNameEquals(nameData, ".com.apple.mobile_container_manager.metadata.plist") ||
             PXMainDataRawNameEquals(nameData, ".com.apple.containermanagerd.metadata.plist"))) {
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorForbiddenContainerMetadata,
                                        pathField,
                                        @"A forbidden container metadata entry is present.");
        }

        char *entryName = PXMainDataCopyTerminatedName(nameData);
        if (!entryName) {
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorLimitExceeded,
                                        entryField,
                                        @"A staged entry name could not be represented safely.");
        }
        struct stat pathStat;
        memset(&pathStat, 0, sizeof(pathStat));
        int statResult = fstatat(frame.descriptor,
                                entryName,
                                &pathStat,
                                AT_SYMLINK_NOFOLLOW);
        if (statResult != 0) {
            free(entryName);
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorEnumerationFailed,
                                        entryField,
                                        @"A staged entry could not be inspected.");
        }
        if (pathStat.st_dev != self.dataIdentity.device ||
            (pathStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
            free(entryName);
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorUnsupportedEntryType,
                                        entryField,
                                        @"A staged entry type is not supported.");
        }

        if (S_ISDIR(pathStat.st_mode)) {
            int childDescriptor = openat(frame.descriptor,
                                         entryName,
                                         O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
            free(entryName);
            if (childDescriptor < 0 || !PXMainDataSetCloseOnExec(childDescriptor)) {
                if (childDescriptor >= 0) {
                    close(childDescriptor);
                }
                return PXMainDataFailObject(error,
                                            PXMainDataStagingErrorFilesystemChanged,
                                            entryField,
                                            @"A staged directory could not be opened safely.");
            }
            struct stat openedDirectoryStat;
            memset(&openedDirectoryStat, 0, sizeof(openedDirectoryStat));
            if (fstat(childDescriptor, &openedDirectoryStat) != 0 ||
                !S_ISDIR(openedDirectoryStat.st_mode) ||
                openedDirectoryStat.st_dev != pathStat.st_dev ||
                openedDirectoryStat.st_ino != pathStat.st_ino ||
                (openedDirectoryStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
                close(childDescriptor);
                return PXMainDataFailObject(error,
                                            PXMainDataStagingErrorFilesystemChanged,
                                            entryField,
                                            @"A staged directory identity changed.");
            }
            if (directoryCount == NSUIntegerMax) {
                close(childDescriptor);
                return PXMainDataFailObject(error,
                                            PXMainDataStagingErrorLimitExceeded,
                                            entryField,
                                            @"The staged directory count overflowed.");
            }
            directoryCount++;
            PXMainDataHashEntryHeader(&digestContext,
                                      'D',
                                      relativePath,
                                      openedDirectoryStat.st_mode,
                                      0);
            if (enumeratedEntryCount > maximumEntries) {
                close(childDescriptor);
                return PXMainDataFailObject(error,
                                            PXMainDataStagingErrorLimitExceeded,
                                            entryField,
                                            @"The staged entry limit was exceeded.");
            }
            NSUInteger remainingEntryBudget = maximumEntries - enumeratedEntryCount;
            PXStageDirectoryFrame *childFrame =
                PXMainDataCreateValidationFrame(childDescriptor,
                                                relativePath,
                                                entryDepth,
                                                remainingEntryBudget,
                                                self.dataIdentity.device,
                                                entryField,
                                                error);
            if (!childFrame) {
                return nil;
            }
            if (childFrame.names.count > maximumEntries - enumeratedEntryCount) {
                return PXMainDataFailObject(error,
                                            PXMainDataStagingErrorLimitExceeded,
                                            entryField,
                                            @"The staged entry limit was exceeded.");
            }
            enumeratedEntryCount += childFrame.names.count;
            [stack addObject:childFrame];
            continue;
        }

        if (!S_ISREG(pathStat.st_mode)) {
            free(entryName);
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorUnsupportedEntryType,
                                        entryField,
                                        @"A staged entry type is not supported.");
        }
        if (pathStat.st_nlink != 1) {
            free(entryName);
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorHardLinkRejected,
                                        entryField,
                                        @"A staged hard-linked file is not supported.");
        }

        int fileDescriptor = openat(frame.descriptor,
                                    entryName,
                                    O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
        free(entryName);
        if (fileDescriptor < 0 || !PXMainDataSetCloseOnExec(fileDescriptor)) {
            if (fileDescriptor >= 0) {
                close(fileDescriptor);
            }
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorFilesystemChanged,
                                        entryField,
                                        @"A staged file could not be opened safely.");
        }

        struct stat fileBefore;
        memset(&fileBefore, 0, sizeof(fileBefore));
        if (fstat(fileDescriptor, &fileBefore) != 0 ||
            !S_ISREG(fileBefore.st_mode) ||
            fileBefore.st_dev != self.dataIdentity.device ||
            fileBefore.st_dev != pathStat.st_dev ||
            fileBefore.st_ino != pathStat.st_ino ||
            fileBefore.st_nlink != 1 ||
            fileBefore.st_size < 0 ||
            (fileBefore.st_mode & (S_ISUID | S_ISGID)) != 0) {
            close(fileDescriptor);
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorFilesystemChanged,
                                        entryField,
                                        @"A staged file identity changed.");
        }

        unsigned long long fileSize = (unsigned long long)fileBefore.st_size;
        if (actualRegularFileBytes > ULLONG_MAX - fileSize) {
            close(fileDescriptor);
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorLimitExceeded,
                                        @"$.data.regularFileBytes",
                                        @"The staged regular-file byte total overflowed.");
        }
        if (regularFileCount == NSUIntegerMax || regularFileCount >= logicalMemberCount) {
            close(fileDescriptor);
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorLimitExceeded,
                                        entryField,
                                        @"The staged regular-file count exceeds the accepted archive summary.");
        }
        regularFileCount++;
        PXMainDataHashEntryHeader(&digestContext,
                                  'F',
                                  relativePath,
                                  fileBefore.st_mode,
                                  fileSize);

        unsigned char buffer[PXMainDataReadBufferSize];
        unsigned long long bytesRead = 0;
        for (;;) {
            ssize_t amount = read(fileDescriptor, buffer, sizeof(buffer));
            if (amount < 0 && errno == EINTR) {
                continue;
            }
            if (amount < 0) {
                close(fileDescriptor);
                return PXMainDataFailObject(error,
                                            PXMainDataStagingErrorReadFailed,
                                            entryField,
                                            @"A staged file could not be read completely.");
            }
            if (amount == 0) {
                break;
            }
            if (bytesRead > ULLONG_MAX - (unsigned long long)amount) {
                close(fileDescriptor);
                return PXMainDataFailObject(error,
                                            PXMainDataStagingErrorLimitExceeded,
                                            @"$.data.regularFileBytes",
                                            @"The staged read byte count overflowed.");
            }
            bytesRead += (unsigned long long)amount;
            if (bytesRead > fileSize) {
                close(fileDescriptor);
                return PXMainDataFailObject(error,
                                            PXMainDataStagingErrorFilesystemChanged,
                                            entryField,
                                            @"A staged file changed while it was read.");
            }
            CC_SHA256_Update(&digestContext, buffer, (CC_LONG)amount);
        }

        struct stat fileAfter;
        memset(&fileAfter, 0, sizeof(fileAfter));
        if (fstat(fileDescriptor, &fileAfter) != 0) {
            close(fileDescriptor);
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorReadFailed,
                                        entryField,
                                        @"A staged file could not be rechecked after reading.");
        }
        close(fileDescriptor);
        if (bytesRead != fileSize) {
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorReadFailed,
                                        entryField,
                                        @"A staged file read was incomplete.");
        }
        if (!PXMainDataStableFileStatsEqual(&fileBefore, &fileAfter)) {
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorFilesystemChanged,
                                        entryField,
                                        @"A staged file changed while it was read.");
        }
        actualRegularFileBytes += fileSize;
    }

    if (entryCount > logicalMemberCount) {
        NSUInteger derivedDirectories = entryCount - logicalMemberCount;
        if (derivedDirectories > PXMainDataMaximumImplicitDirectories) {
            return PXMainDataFailObject(error,
                                        PXMainDataStagingErrorLimitExceeded,
                                        @"$.data",
                                        @"The staged implicit-directory limit was exceeded.");
        }
    }
    if (regularFileCount > logicalMemberCount) {
        return PXMainDataFailObject(error,
                                    PXMainDataStagingErrorLimitExceeded,
                                    @"$.data",
                                    @"The staged regular-file count exceeds the accepted archive summary.");
    }
    if (actualRegularFileBytes != regularFileBytes) {
        return PXMainDataFailObject(error,
                                    PXMainDataStagingErrorSizeMismatch,
                                    @"$.data.regularFileBytes",
                                    @"The staged regular-file byte total does not match the accepted archive summary.");
    }
    if (![self verifyWorkspaceIdentityWithError:error]) {
        return nil;
    }

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &digestContext);
    NSString *treeSHA256 = PXMainDataLowercaseHexDigest(digest);
    if (treeSHA256.length != CC_SHA256_DIGEST_LENGTH * 2) {
        return PXMainDataFailObject(error,
                                    PXMainDataStagingErrorReadFailed,
                                    @"$.data",
                                    @"The staged tree digest could not be finalized.");
    }

    return [[PXValidatedMainDataStage alloc]
        initWithWorkspaceRootPath:self.rootPath
                        dataPath:self.dataPath
                      entryCount:entryCount
                regularFileCount:regularFileCount
                  directoryCount:directoryCount
                regularFileBytes:actualRegularFileBytes
                      treeSHA256:treeSHA256];
}

- (BOOL)closeOwnedDescriptorsAfterCleanupFailure:(NSError **)error {
    PXMainDataCloseDescriptor(&_dataDescriptor);
    PXMainDataCloseDescriptor(&_rootDescriptor);
    PXMainDataCloseDescriptor(&_parentDescriptor);
    return PXMainDataFail(error,
                          PXMainDataStagingErrorCleanupFailed,
                          @"$.workspace",
                          @"The staging workspace could not be cleaned safely.");
}

- (BOOL)cleanupWithError:(NSError **)error {
    if (error) {
        *error = nil;
    }
    if (self.cleaned) {
        return YES;
    }
    if (self.parentDescriptor < 0 ||
        self.rootDescriptor < 0 ||
        !self.rootBasename.length) {
        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
    }

    struct stat retainedParentStat;
    struct stat retainedRootStat;
    struct stat namespaceRootStat;
    memset(&retainedParentStat, 0, sizeof(retainedParentStat));
    memset(&retainedRootStat, 0, sizeof(retainedRootStat));
    memset(&namespaceRootStat, 0, sizeof(namespaceRootStat));
    if (fstat(self.parentDescriptor, &retainedParentStat) != 0 ||
        fstat(self.rootDescriptor, &retainedRootStat) != 0 ||
        !PXMainDataIdentityMatchesBasic(self.parentIdentity, &retainedParentStat) ||
        !PXMainDataIdentityMatchesBasic(self.rootIdentity, &retainedRootStat)) {
        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
    }
    if (fstatat(self.parentDescriptor,
                self.rootBasename.fileSystemRepresentation,
                &namespaceRootStat,
                AT_SYMLINK_NOFOLLOW) != 0) {
        if (errno == ENOENT) {
            PXMainDataCloseDescriptor(&_dataDescriptor);
            PXMainDataCloseDescriptor(&_rootDescriptor);
            PXMainDataCloseDescriptor(&_parentDescriptor);
            self.cleaned = YES;
            return YES;
        }
        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
    }
    if (!PXMainDataIdentityMatchesBasic(self.rootIdentity, &namespaceRootStat) ||
        !S_ISDIR(namespaceRootStat.st_mode)) {
        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
    }

    NSError *identityError = nil;
    if (![self verifyWorkspaceIdentityWithError:&identityError]) {
        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
    }

    PXMainDataCloseDescriptor(&_dataDescriptor);
    int cleanupRootDescriptor = PXMainDataDuplicateDescriptor(self.rootDescriptor);
    if (cleanupRootDescriptor < 0) {
        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
    }
    struct stat cleanupRootStat;
    memset(&cleanupRootStat, 0, sizeof(cleanupRootStat));
    if (fstat(cleanupRootDescriptor, &cleanupRootStat) != 0 ||
        !PXMainDataIdentityMatchesBasic(self.rootIdentity, &cleanupRootStat)) {
        close(cleanupRootDescriptor);
        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
    }

    NSError *enumerationError = nil;
    NSArray<NSData *> *rootNames = PXMainDataReadDirectoryNames(cleanupRootDescriptor,
                                                               PXMainDataMaximumCleanupEntries,
                                                               PXMainDataStagingErrorCleanupFailed,
                                                               PXMainDataStagingErrorCleanupFailed,
                                                               @"$.workspace",
                                                               &enumerationError);
    if (!rootNames) {
        close(cleanupRootDescriptor);
        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
    }

    PXCleanupDirectoryFrame *rootFrame = [[PXCleanupDirectoryFrame alloc] init];
    rootFrame.descriptor = cleanupRootDescriptor;
    rootFrame.names = rootNames;
    rootFrame.nextIndex = 0;
    rootFrame.entryName = nil;
    rootFrame.depth = 0;
    rootFrame.identity = PXMainDataIdentityFromStat(&cleanupRootStat);
    NSMutableArray<PXCleanupDirectoryFrame *> *stack = [NSMutableArray arrayWithObject:rootFrame];
    NSUInteger enumeratedCleanupEntryCount = rootNames.count;
    NSUInteger cleanupEntryCount = 0;

    while (stack.count > 0) {
        PXCleanupDirectoryFrame *frame = stack.lastObject;
        if (frame.nextIndex >= frame.names.count) {
            if (stack.count == 1) {
                [stack removeLastObject];
                break;
            }
            PXCleanupDirectoryFrame *parent = stack[stack.count - 2];
            char *childName = PXMainDataCopyTerminatedName(frame.entryName);
            if (!childName) {
                return [self closeOwnedDescriptorsAfterCleanupFailure:error];
            }
            struct stat descriptorStat;
            struct stat pathStat;
            memset(&descriptorStat, 0, sizeof(descriptorStat));
            memset(&pathStat, 0, sizeof(pathStat));
            BOOL childIdentityValid =
                fstat(frame.descriptor, &descriptorStat) == 0 &&
                fstatat(parent.descriptor, childName, &pathStat, AT_SYMLINK_NOFOLLOW) == 0 &&
                S_ISDIR(descriptorStat.st_mode) &&
                S_ISDIR(pathStat.st_mode) &&
                PXMainDataIdentityMatchesBasic(frame.identity, &descriptorStat) &&
                PXMainDataIdentityMatchesBasic(frame.identity, &pathStat) &&
                descriptorStat.st_dev == self.rootIdentity.device;
            if (!childIdentityValid) {
                free(childName);
                return [self closeOwnedDescriptorsAfterCleanupFailure:error];
            }
            if (unlinkat(parent.descriptor, childName, AT_REMOVEDIR) != 0) {
                free(childName);
                return [self closeOwnedDescriptorsAfterCleanupFailure:error];
            }
            close(frame.descriptor);
            frame.descriptor = -1;
            free(childName);
            [stack removeLastObject];
            continue;
        }

        if (cleanupEntryCount == NSUIntegerMax ||
            cleanupEntryCount >= PXMainDataMaximumCleanupEntries) {
            return [self closeOwnedDescriptorsAfterCleanupFailure:error];
        }
        cleanupEntryCount++;

        NSData *nameData = frame.names[frame.nextIndex++];
        char *entryName = PXMainDataCopyTerminatedName(nameData);
        if (!entryName) {
            return [self closeOwnedDescriptorsAfterCleanupFailure:error];
        }
        struct stat firstStat;
        memset(&firstStat, 0, sizeof(firstStat));
        if (fstatat(frame.descriptor,
                    entryName,
                    &firstStat,
                    AT_SYMLINK_NOFOLLOW) != 0 ||
            firstStat.st_dev != self.rootIdentity.device) {
            free(entryName);
            return [self closeOwnedDescriptorsAfterCleanupFailure:error];
        }
        BOOL isRootDataEntry =
            stack.count == 1 && PXMainDataRawNameEquals(nameData, "data");
        if (isRootDataEntry &&
            (!S_ISDIR(firstStat.st_mode) ||
             !PXMainDataIdentityMatchesBasic(self.dataIdentity, &firstStat))) {
            free(entryName);
            return [self closeOwnedDescriptorsAfterCleanupFailure:error];
        }

        if (S_ISDIR(firstStat.st_mode)) {
            BOOL isRetainedDataDirectory =
                stack.count == 1 && PXMainDataRawNameEquals(nameData, "data");
            NSUInteger childDepth = frame.depth;
            if (!isRetainedDataDirectory) {
                if (frame.depth >= PXMainDataMaximumDepth) {
                    free(entryName);
                    return [self closeOwnedDescriptorsAfterCleanupFailure:error];
                }
                childDepth = frame.depth + 1;
            }
            int childDescriptor = openat(frame.descriptor,
                                         entryName,
                                         O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
            if (childDescriptor < 0 || !PXMainDataSetCloseOnExec(childDescriptor)) {
                if (childDescriptor >= 0) {
                    close(childDescriptor);
                }
                free(entryName);
                return [self closeOwnedDescriptorsAfterCleanupFailure:error];
            }
            struct stat openedStat;
            memset(&openedStat, 0, sizeof(openedStat));
            if (fstat(childDescriptor, &openedStat) != 0 ||
                !PXMainDataCleanupStatsMatch(&firstStat, &openedStat) ||
                !S_ISDIR(openedStat.st_mode) ||
                openedStat.st_dev != self.rootIdentity.device) {
                close(childDescriptor);
                free(entryName);
                return [self closeOwnedDescriptorsAfterCleanupFailure:error];
            }
            if (enumeratedCleanupEntryCount > PXMainDataMaximumCleanupEntries) {
                close(childDescriptor);
                free(entryName);
                return [self closeOwnedDescriptorsAfterCleanupFailure:error];
            }
            NSUInteger remainingCleanupBudget =
                PXMainDataMaximumCleanupEntries - enumeratedCleanupEntryCount;
            NSArray<NSData *> *childNames = PXMainDataReadDirectoryNames(childDescriptor,
                                                                        remainingCleanupBudget,
                                                                        PXMainDataStagingErrorCleanupFailed,
                                                                        PXMainDataStagingErrorCleanupFailed,
                                                                        @"$.workspace",
                                                                        &enumerationError);
            if (!childNames) {
                close(childDescriptor);
                free(entryName);
                return [self closeOwnedDescriptorsAfterCleanupFailure:error];
            }
            PXCleanupDirectoryFrame *childFrame = [[PXCleanupDirectoryFrame alloc] init];
            childFrame.descriptor = childDescriptor;
            childFrame.names = childNames;
            if (childNames.count >
                PXMainDataMaximumCleanupEntries - enumeratedCleanupEntryCount) {
                close(childDescriptor);
                free(entryName);
                return [self closeOwnedDescriptorsAfterCleanupFailure:error];
            }
            enumeratedCleanupEntryCount += childNames.count;
            childFrame.nextIndex = 0;
            childFrame.entryName = nameData;
            childFrame.depth = childDepth;
            childFrame.identity = PXMainDataIdentityFromStat(&openedStat);
            [stack addObject:childFrame];
            free(entryName);
            continue;
        }

        struct stat secondStat;
        memset(&secondStat, 0, sizeof(secondStat));
        if (fstatat(frame.descriptor,
                    entryName,
                    &secondStat,
                    AT_SYMLINK_NOFOLLOW) != 0 ||
            !PXMainDataCleanupStatsMatch(&firstStat, &secondStat) ||
            unlinkat(frame.descriptor, entryName, 0) != 0) {
            free(entryName);
            return [self closeOwnedDescriptorsAfterCleanupFailure:error];
        }
        free(entryName);
    }

    struct stat rootDescriptorStat;
    struct stat rootPathStat;
    memset(&rootDescriptorStat, 0, sizeof(rootDescriptorStat));
    memset(&rootPathStat, 0, sizeof(rootPathStat));
    if (fstat(self.rootDescriptor, &rootDescriptorStat) != 0 ||
        fstatat(self.parentDescriptor,
                self.rootBasename.fileSystemRepresentation,
                &rootPathStat,
                AT_SYMLINK_NOFOLLOW) != 0 ||
        !PXMainDataIdentityMatchesBasic(self.rootIdentity, &rootDescriptorStat) ||
        !PXMainDataIdentityMatchesBasic(self.rootIdentity, &rootPathStat) ||
        !S_ISDIR(rootDescriptorStat.st_mode) ||
        !S_ISDIR(rootPathStat.st_mode)) {
        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
    }

    if (unlinkat(self.parentDescriptor,
                 self.rootBasename.fileSystemRepresentation,
                 AT_REMOVEDIR) != 0) {
        return [self closeOwnedDescriptorsAfterCleanupFailure:error];
    }
    PXMainDataCloseDescriptor(&_rootDescriptor);
    PXMainDataCloseDescriptor(&_parentDescriptor);
    self.cleaned = YES;
    return YES;
}

- (void)dealloc {
    if (!self.cleaned) {
        [self cleanupWithError:nil];
    }
    PXMainDataCloseDescriptor(&_dataDescriptor);
    PXMainDataCloseDescriptor(&_rootDescriptor);
    PXMainDataCloseDescriptor(&_parentDescriptor);
}

@end
