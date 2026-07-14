#import "PXMainDataRestoreTransaction.h"

#import "PXDestructivePathValidator.h"
#import "PXMainDataStaging.h"
#import "PXResolvedContainer.h"

#import <CoreFoundation/CoreFoundation.h>

#include <dirent.h>
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

NSString * const PXMainDataRestoreTransactionErrorDomain = @"PXMainDataRestoreTransactionErrorDomain";
NSString * const PXMainDataRestoreTransactionErrorFieldPathKey = @"PXMainDataRestoreTransactionErrorFieldPathKey";

static NSString * const PXMainDataRestoreTransactionPrefix = @".weaponx-main-restore-";
static NSString * const PXMainDataRestoreOriginalDirectoryName = @"original";
static NSString * const PXMainDataRestoreNewDirectoryName = @"new";
static NSString * const PXMainDataRestoreJournalName = @"journal.plist";
static NSString * const PXMainDataRestoreJournalTemporaryName = @"journal.tmp";

static NSString * const PXMainDataRestorePhasePrepared = @"prepared";
static NSString * const PXMainDataRestorePhaseQuarantined = @"quarantined";
static NSString * const PXMainDataRestorePhaseInstalled = @"installed";
static NSString * const PXMainDataRestorePhaseCommitted = @"committed";
static NSString * const PXMainDataRestorePhaseRollingBack = @"rolling-back";
static NSString * const PXMainDataRestorePhaseRolledBack = @"rolled-back";

static const NSUInteger PXMainDataRestoreMaximumTopLevelEntries = 100000;
static const NSUInteger PXMainDataRestoreMaximumCleanupEntries = 500000;
static const NSUInteger PXMainDataRestoreMaximumCleanupDepth = 2048;
static const NSUInteger PXMainDataRestoreMaximumJournalBytes = 64 * 1024 * 1024;
static const NSUInteger PXMainDataRestoreMaximumComponentBytes = 255;

static BOOL PXMainDataRestoreFail(NSError **error,
                                  PXMainDataRestoreTransactionErrorCode code,
                                  NSString *fieldPath,
                                  NSString *description) {
    if (error) {
        *error = [NSError errorWithDomain:PXMainDataRestoreTransactionErrorDomain
                                     code:code
                                 userInfo:@{
                                     NSLocalizedDescriptionKey: description,
                                     PXMainDataRestoreTransactionErrorFieldPathKey: fieldPath
                                 }];
    }
    return NO;
}

static id PXMainDataRestoreFailObject(NSError **error,
                                      PXMainDataRestoreTransactionErrorCode code,
                                      NSString *fieldPath,
                                      NSString *description) {
    PXMainDataRestoreFail(error, code, fieldPath, description);
    return nil;
}

static BOOL PXMainDataRestoreReadUnsignedIntegralNumber(id value,
                                                        unsigned long long *numberOut) {
    if (![value isKindOfClass:[NSNumber class]] ||
        CFGetTypeID((__bridge CFTypeRef)value) != CFNumberGetTypeID()) {
        return NO;
    }
    const char *type = [(NSNumber *)value objCType];
    if (!type || !type[0]) {
        return NO;
    }
    unsigned long long unsignedValue = 0;
    switch (type[0]) {
        case 'C':
        case 'S':
        case 'I':
        case 'L':
        case 'Q':
            unsignedValue = [(NSNumber *)value unsignedLongLongValue];
            break;
        case 'c':
        case 's':
        case 'i':
        case 'l':
        case 'q': {
            long long signedValue = [(NSNumber *)value longLongValue];
            if (signedValue < 0) {
                return NO;
            }
            unsignedValue = (unsigned long long)signedValue;
            break;
        }
        default:
            return NO;
    }
    if (numberOut) {
        *numberOut = unsignedValue;
    }
    return YES;
}

static void PXMainDataRestoreCloseDescriptor(int *descriptor) {
    if (descriptor && *descriptor >= 0) {
        close(*descriptor);
        *descriptor = -1;
    }
}

static BOOL PXMainDataRestoreSetCloseOnExec(int descriptor) {
    int flags = fcntl(descriptor, F_GETFD);
    if (flags < 0) {
        return NO;
    }
    if ((flags & FD_CLOEXEC) == 0 &&
        fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC) != 0) {
        return NO;
    }
    int verified = fcntl(descriptor, F_GETFD);
    return verified >= 0 && (verified & FD_CLOEXEC) != 0;
}

static int PXMainDataRestoreDuplicateDescriptor(int descriptor) {
    int duplicate = dup(descriptor);
    if (duplicate < 0) {
        return -1;
    }
    if (!PXMainDataRestoreSetCloseOnExec(duplicate)) {
        close(duplicate);
        return -1;
    }
    return duplicate;
}

static BOOL PXMainDataRestoreSyncDescriptor(int descriptor) {
    int result = -1;
    do {
        result = fsync(descriptor);
    } while (result != 0 && errno == EINTR);
    return result == 0;
}

static BOOL PXMainDataRestoreSyncDirectory(int descriptor) {
    return PXMainDataRestoreSyncDescriptor(descriptor);
}

static BOOL PXMainDataRestoreStatIdentityMatches(const struct stat *expected,
                                                 const struct stat *actual) {
    return expected && actual &&
           expected->st_dev == actual->st_dev &&
           expected->st_ino == actual->st_ino &&
           ((expected->st_mode & S_IFMT) == (actual->st_mode & S_IFMT));
}

static NSComparisonResult PXMainDataRestoreCompareRawNames(NSData *left, NSData *right) {
    NSUInteger commonLength = MIN(left.length, right.length);
    int comparison = commonLength > 0 ? memcmp(left.bytes, right.bytes, commonLength) : 0;
    if (comparison < 0) {
        return NSOrderedAscending;
    }
    if (comparison > 0) {
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

static char *PXMainDataRestoreCopyTerminatedName(NSData *nameData) {
    if (nameData.length == 0 || nameData.length > SIZE_MAX - 1) {
        return NULL;
    }
    char *name = calloc(nameData.length + 1, 1);
    if (!name) {
        return NULL;
    }
    memcpy(name, nameData.bytes, nameData.length);
    return name;
}

static NSData *PXMainDataRestoreNameData(NSString *name) {
    return [name dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
}

static BOOL PXMainDataRestoreRawNameEquals(NSData *nameData, NSString *name) {
    NSData *expected = PXMainDataRestoreNameData(name);
    return expected && [nameData isEqualToData:expected];
}

static BOOL PXMainDataRestoreRawNameHasPrefix(NSData *nameData, NSString *prefix) {
    NSData *prefixData = PXMainDataRestoreNameData(prefix);
    if (!prefixData || nameData.length < prefixData.length) {
        return NO;
    }
    return prefixData.length == 0 ||
           memcmp(nameData.bytes, prefixData.bytes, prefixData.length) == 0;
}

static BOOL PXMainDataRestoreNameIsSafe(NSData *nameData) {
    if (![nameData isKindOfClass:[NSData class]] ||
        nameData.length == 0 ||
        nameData.length > PXMainDataRestoreMaximumComponentBytes) {
        return NO;
    }
    const unsigned char *bytes = nameData.bytes;
    for (NSUInteger index = 0; index < nameData.length; index++) {
        if (bytes[index] == 0 || bytes[index] == '/') {
            return NO;
        }
    }
    static const unsigned char dot[] = {'.'};
    static const unsigned char dotDot[] = {'.', '.'};
    if ((nameData.length == sizeof(dot) && memcmp(nameData.bytes, dot, sizeof(dot)) == 0) ||
        (nameData.length == sizeof(dotDot) && memcmp(nameData.bytes, dotDot, sizeof(dotDot)) == 0)) {
        return NO;
    }
    return YES;
}

static BOOL PXMainDataRestoreNameIsContainerMetadata(NSData *nameData) {
    return PXMainDataRestoreRawNameEquals(nameData,
                                          @".com.apple.mobile_container_manager.metadata.plist") ||
           PXMainDataRestoreRawNameEquals(nameData,
                                          @".com.apple.containermanagerd.metadata.plist");
}

static NSArray<NSData *> *PXMainDataRestoreReadDirectoryNames(int descriptor,
                                                              NSUInteger maximumNameCount,
                                                              NSError **error,
                                                              NSString *fieldPath) {
    int enumerationDescriptor = PXMainDataRestoreDuplicateDescriptor(descriptor);
    if (enumerationDescriptor < 0 ||
        lseek(enumerationDescriptor, 0, SEEK_SET) < 0) {
        if (enumerationDescriptor >= 0) {
            close(enumerationDescriptor);
        }
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorFilesystemInspectionFailed,
                                           fieldPath,
                                           @"A directory enumeration descriptor could not be prepared.");
    }

    DIR *directory = fdopendir(enumerationDescriptor);
    if (!directory) {
        close(enumerationDescriptor);
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorFilesystemInspectionFailed,
                                           fieldPath,
                                           @"A directory could not be enumerated.");
    }

    NSMutableArray<NSData *> *names = [NSMutableArray array];
    int enumerationError = 0;
    for (;;) {
        errno = 0;
        struct dirent *entry = readdir(directory);
        if (!entry) {
            enumerationError = errno;
            break;
        }
        const char *name = entry->d_name;
        if ((name[0] == '.' && name[1] == '\0') ||
            (name[0] == '.' && name[1] == '.' && name[2] == '\0')) {
            continue;
        }
        if (names.count >= maximumNameCount) {
            closedir(directory);
            return PXMainDataRestoreFailObject(error,
                                               PXMainDataRestoreTransactionErrorEntryLimitExceeded,
                                               fieldPath,
                                               @"A transaction directory entry limit was exceeded.");
        }
        size_t length = strlen(name);
        NSData *nameData = [NSData dataWithBytes:name length:length];
        if (!PXMainDataRestoreNameIsSafe(nameData)) {
            closedir(directory);
            return PXMainDataRestoreFailObject(error,
                                               PXMainDataRestoreTransactionErrorFilesystemInspectionFailed,
                                               fieldPath,
                                               @"A transaction directory contains an unsafe entry name.");
        }
        [names addObject:nameData];
    }

    if (closedir(directory) != 0 && enumerationError == 0) {
        enumerationError = errno ?: EIO;
    }
    if (enumerationError != 0) {
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorFilesystemInspectionFailed,
                                           fieldPath,
                                           @"Directory enumeration did not complete safely.");
    }

    return [names sortedArrayUsingComparator:^NSComparisonResult(NSData *left, NSData *right) {
        return PXMainDataRestoreCompareRawNames(left, right);
    }];
}

static BOOL PXMainDataRestorePathMatchesDescriptor(NSString *path, int descriptor) {
    if (![path isKindOfClass:[NSString class]] || path.length == 0 || descriptor < 0) {
        return NO;
    }
    struct stat pathStat;
    struct stat descriptorStat;
    memset(&pathStat, 0, sizeof(pathStat));
    memset(&descriptorStat, 0, sizeof(descriptorStat));
    if (lstat(path.fileSystemRepresentation, &pathStat) != 0 ||
        fstat(descriptor, &descriptorStat) != 0) {
        return NO;
    }
    return S_ISDIR(pathStat.st_mode) &&
           S_ISDIR(descriptorStat.st_mode) &&
           pathStat.st_dev == descriptorStat.st_dev &&
           pathStat.st_ino == descriptorStat.st_ino;
}

static BOOL PXMainDataRestoreNameState(int descriptor,
                                       NSData *nameData,
                                       BOOL *existsOut,
                                       struct stat *statOut) {
    if (existsOut) {
        *existsOut = NO;
    }
    char *name = PXMainDataRestoreCopyTerminatedName(nameData);
    if (!name) {
        return NO;
    }
    struct stat value;
    memset(&value, 0, sizeof(value));
    int result = fstatat(descriptor, name, &value, AT_SYMLINK_NOFOLLOW);
    int savedError = errno;
    free(name);
    if (result == 0) {
        if (existsOut) {
            *existsOut = YES;
        }
        if (statOut) {
            *statOut = value;
        }
        return YES;
    }
    return savedError == ENOENT;
}

@interface PXMainDataRestoreEntry : NSObject
@property (nonatomic, copy) NSData *nameData;
@property (nonatomic, assign) unsigned long long device;
@property (nonatomic, assign) unsigned long long inode;
@property (nonatomic, assign) unsigned int modeType;
+ (nullable instancetype)entryForNameData:(NSData *)nameData
                              descriptor:(int)descriptor
                                   error:(NSError * _Nullable * _Nullable)error
                               fieldPath:(NSString *)fieldPath;
+ (nullable instancetype)entryFromJournalObject:(id)object
                                          error:(NSError * _Nullable * _Nullable)error
                                      fieldPath:(NSString *)fieldPath;
- (NSDictionary<NSString *, id> *)journalObject;
- (BOOL)matchesStat:(const struct stat *)value;
@end

@implementation PXMainDataRestoreEntry

+ (instancetype)entryForNameData:(NSData *)nameData
                      descriptor:(int)descriptor
                           error:(NSError **)error
                       fieldPath:(NSString *)fieldPath {
    if (!PXMainDataRestoreNameIsSafe(nameData)) {
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorFilesystemInspectionFailed,
                                           fieldPath,
                                           @"A transaction entry name is invalid.");
    }
    BOOL exists = NO;
    struct stat value;
    memset(&value, 0, sizeof(value));
    if (!PXMainDataRestoreNameState(descriptor, nameData, &exists, &value) || !exists) {
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorFilesystemChanged,
                                           fieldPath,
                                           @"A planned transaction entry changed before inspection completed.");
    }
    PXMainDataRestoreEntry *entry = [[self alloc] init];
    entry.nameData = [nameData copy];
    entry.device = (unsigned long long)value.st_dev;
    entry.inode = (unsigned long long)value.st_ino;
    entry.modeType = (unsigned int)(value.st_mode & S_IFMT);
    return entry;
}

+ (instancetype)entryFromJournalObject:(id)object
                                  error:(NSError **)error
                              fieldPath:(NSString *)fieldPath {
    if (![object isKindOfClass:[NSDictionary class]]) {
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorJournalInvalid,
                                           fieldPath,
                                           @"A transaction journal entry is not a dictionary.");
    }
    NSDictionary *dictionary = object;
    NSData *nameData = dictionary[@"name"];
    id device = dictionary[@"device"];
    id inode = dictionary[@"inode"];
    id modeType = dictionary[@"modeType"];
    unsigned long long deviceValue = 0;
    unsigned long long inodeValue = 0;
    unsigned long long modeValue = 0;
    if (!PXMainDataRestoreNameIsSafe(nameData) ||
        !PXMainDataRestoreReadUnsignedIntegralNumber(device, &deviceValue) ||
        !PXMainDataRestoreReadUnsignedIntegralNumber(inode, &inodeValue) ||
        !PXMainDataRestoreReadUnsignedIntegralNumber(modeType, &modeValue)) {
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorJournalInvalid,
                                           fieldPath,
                                           @"A transaction journal entry is invalid.");
    }
    if (inodeValue == 0 || modeValue > UINT_MAX || (modeValue & S_IFMT) == 0) {
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorJournalInvalid,
                                           fieldPath,
                                           @"A transaction journal entry identity is invalid.");
    }
    PXMainDataRestoreEntry *entry = [[self alloc] init];
    entry.nameData = [nameData copy];
    entry.device = deviceValue;
    entry.inode = inodeValue;
    entry.modeType = (unsigned int)(modeValue & S_IFMT);
    return entry;
}

- (NSDictionary<NSString *,id> *)journalObject {
    return @{
        @"name": self.nameData,
        @"device": @(self.device),
        @"inode": @(self.inode),
        @"modeType": @(self.modeType)
    };
}

- (BOOL)matchesStat:(const struct stat *)value {
    return value &&
           self.device == (unsigned long long)value->st_dev &&
           self.inode == (unsigned long long)value->st_ino &&
           self.modeType == (unsigned int)(value->st_mode & S_IFMT);
}

@end

static NSArray<PXMainDataRestoreEntry *> *PXMainDataRestoreCollectEntries(
    int descriptor,
    BOOL rejectContainerMetadata,
    BOOL rejectTransactionPrefix,
    BOOL skipContainerMetadata,
    BOOL skipTransactionPrefix,
    NSError **error,
    NSString *fieldPath) {
    NSArray<NSData *> *names =
        PXMainDataRestoreReadDirectoryNames(descriptor,
                                            PXMainDataRestoreMaximumTopLevelEntries,
                                            error,
                                            fieldPath);
    if (!names) {
        return nil;
    }
    NSMutableArray<PXMainDataRestoreEntry *> *entries =
        [NSMutableArray arrayWithCapacity:names.count];
    for (NSData *nameData in names) {
        BOOL metadata = PXMainDataRestoreNameIsContainerMetadata(nameData);
        BOOL transactionName =
            PXMainDataRestoreRawNameHasPrefix(nameData, PXMainDataRestoreTransactionPrefix);
        if ((rejectContainerMetadata && metadata) ||
            (rejectTransactionPrefix && transactionName)) {
            return PXMainDataRestoreFailObject(error,
                                               PXMainDataRestoreTransactionErrorFilesystemInspectionFailed,
                                               fieldPath,
                                               @"A reserved transaction entry name is present.");
        }
        if ((skipContainerMetadata && metadata) ||
            (skipTransactionPrefix && transactionName)) {
            continue;
        }
        PXMainDataRestoreEntry *entry =
            [PXMainDataRestoreEntry entryForNameData:nameData
                                          descriptor:descriptor
                                               error:error
                                           fieldPath:fieldPath];
        if (!entry) {
            return nil;
        }
        [entries addObject:entry];
    }
    return [entries copy];
}

static BOOL PXMainDataRestoreEntryArraysMatch(NSArray<PXMainDataRestoreEntry *> *expected,
                                               NSArray<PXMainDataRestoreEntry *> *actual) {
    if (expected.count != actual.count) {
        return NO;
    }
    for (NSUInteger index = 0; index < expected.count; index++) {
        PXMainDataRestoreEntry *left = expected[index];
        PXMainDataRestoreEntry *right = actual[index];
        if (![left.nameData isEqualToData:right.nameData] ||
            left.device != right.device ||
            left.inode != right.inode ||
            left.modeType != right.modeType) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXMainDataRestoreRequireExactEntries(
    int descriptor,
    NSArray<PXMainDataRestoreEntry *> *expectedEntries,
    BOOL rejectContainerMetadata,
    BOOL rejectTransactionPrefix,
    BOOL skipContainerMetadata,
    BOOL skipTransactionPrefix,
    PXMainDataRestoreTransactionErrorCode code,
    NSString *fieldPath,
    NSString *description,
    NSError **error) {
    NSError *inspectionError = nil;
    NSArray<PXMainDataRestoreEntry *> *actualEntries =
        PXMainDataRestoreCollectEntries(descriptor,
                                        rejectContainerMetadata,
                                        rejectTransactionPrefix,
                                        skipContainerMetadata,
                                        skipTransactionPrefix,
                                        &inspectionError,
                                        fieldPath);
    if (!actualEntries ||
        !PXMainDataRestoreEntryArraysMatch(expectedEntries, actualEntries)) {
        return PXMainDataRestoreFail(error,
                                     code,
                                     fieldPath,
                                     description);
    }
    return YES;
}

static BOOL PXMainDataRestoreEntryMatchesAt(PXMainDataRestoreEntry *entry,
                                             int descriptor,
                                             BOOL *existsOut) {
    BOOL exists = NO;
    struct stat value;
    memset(&value, 0, sizeof(value));
    if (!PXMainDataRestoreNameState(descriptor, entry.nameData, &exists, &value)) {
        return NO;
    }
    if (existsOut) {
        *existsOut = exists;
    }
    return !exists || [entry matchesStat:&value];
}

@interface PXMainDataRestoreCleanupFrame : NSObject
@property (nonatomic, assign) int descriptor;
@property (nonatomic, copy) NSArray<NSData *> *names;
@property (nonatomic, assign) NSUInteger nextIndex;
@property (nonatomic, copy, nullable) NSData *entryName;
@end

@implementation PXMainDataRestoreCleanupFrame
- (instancetype)init {
    self = [super init];
    if (self) {
        _descriptor = -1;
    }
    return self;
}
- (void)dealloc {
    PXMainDataRestoreCloseDescriptor(&_descriptor);
}
@end

static BOOL PXMainDataRestoreRemoveDirectoryContents(int rootDescriptor,
                                                      NSError **error,
                                                      NSString *fieldPath) {
    struct stat rootStat;
    memset(&rootStat, 0, sizeof(rootStat));
    if (fstat(rootDescriptor, &rootStat) != 0 || !S_ISDIR(rootStat.st_mode)) {
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorCleanupFailed,
                                     fieldPath,
                                     @"A transaction cleanup root could not be inspected.");
    }
    NSArray<NSData *> *rootNames =
        PXMainDataRestoreReadDirectoryNames(rootDescriptor,
                                            PXMainDataRestoreMaximumCleanupEntries,
                                            error,
                                            fieldPath);
    if (!rootNames) {
        return NO;
    }
    int rootDuplicate = PXMainDataRestoreDuplicateDescriptor(rootDescriptor);
    if (rootDuplicate < 0) {
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorCleanupFailed,
                                     fieldPath,
                                     @"A transaction cleanup descriptor could not be prepared.");
    }

    PXMainDataRestoreCleanupFrame *rootFrame = [[PXMainDataRestoreCleanupFrame alloc] init];
    rootFrame.descriptor = rootDuplicate;
    rootFrame.names = rootNames;
    NSMutableArray<PXMainDataRestoreCleanupFrame *> *stack = [NSMutableArray arrayWithObject:rootFrame];
    NSUInteger visited = 0;

    while (stack.count > 0) {
        PXMainDataRestoreCleanupFrame *frame = stack.lastObject;
        if (frame.nextIndex >= frame.names.count) {
            NSData *entryName = frame.entryName;
            [stack removeLastObject];
            if (entryName && stack.count > 0) {
                PXMainDataRestoreCleanupFrame *parent = stack.lastObject;
                char *name = PXMainDataRestoreCopyTerminatedName(entryName);
                if (!name || unlinkat(parent.descriptor, name, AT_REMOVEDIR) != 0) {
                    free(name);
                    return PXMainDataRestoreFail(error,
                                                 PXMainDataRestoreTransactionErrorCleanupFailed,
                                                 fieldPath,
                                                 @"A transaction cleanup directory could not be removed.");
                }
                free(name);
            }
            continue;
        }

        if (stack.count > PXMainDataRestoreMaximumCleanupDepth ||
            visited >= PXMainDataRestoreMaximumCleanupEntries) {
            return PXMainDataRestoreFail(error,
                                         PXMainDataRestoreTransactionErrorEntryLimitExceeded,
                                         fieldPath,
                                         @"A transaction cleanup limit was exceeded.");
        }

        NSData *nameData = frame.names[frame.nextIndex++];
        visited++;
        char *name = PXMainDataRestoreCopyTerminatedName(nameData);
        if (!name) {
            return PXMainDataRestoreFail(error,
                                         PXMainDataRestoreTransactionErrorCleanupFailed,
                                         fieldPath,
                                         @"A transaction cleanup entry name could not be prepared.");
        }
        struct stat before;
        memset(&before, 0, sizeof(before));
        if (fstatat(frame.descriptor, name, &before, AT_SYMLINK_NOFOLLOW) != 0) {
            free(name);
            return PXMainDataRestoreFail(error,
                                         PXMainDataRestoreTransactionErrorCleanupFailed,
                                         fieldPath,
                                         @"A transaction cleanup entry could not be inspected.");
        }

        if (!S_ISDIR(before.st_mode)) {
            int unlinkResult = unlinkat(frame.descriptor, name, 0);
            free(name);
            if (unlinkResult != 0) {
                return PXMainDataRestoreFail(error,
                                             PXMainDataRestoreTransactionErrorCleanupFailed,
                                             fieldPath,
                                             @"A transaction cleanup entry could not be removed.");
            }
            continue;
        }

        int childDescriptor = openat(frame.descriptor,
                                     name,
                                     O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        free(name);
        if (childDescriptor < 0) {
            return PXMainDataRestoreFail(error,
                                         PXMainDataRestoreTransactionErrorCleanupFailed,
                                         fieldPath,
                                         @"A transaction cleanup directory could not be opened.");
        }
        struct stat after;
        memset(&after, 0, sizeof(after));
        if (fstat(childDescriptor, &after) != 0 ||
            before.st_dev != rootStat.st_dev ||
            after.st_dev != rootStat.st_dev ||
            before.st_dev != after.st_dev ||
            before.st_ino != after.st_ino ||
            !S_ISDIR(after.st_mode)) {
            close(childDescriptor);
            return PXMainDataRestoreFail(error,
                                         PXMainDataRestoreTransactionErrorFilesystemChanged,
                                         fieldPath,
                                         @"A transaction cleanup directory changed during traversal.");
        }
        NSUInteger remaining = PXMainDataRestoreMaximumCleanupEntries - visited;
        NSArray<NSData *> *childNames =
            PXMainDataRestoreReadDirectoryNames(childDescriptor,
                                                remaining,
                                                error,
                                                fieldPath);
        if (!childNames) {
            close(childDescriptor);
            return NO;
        }
        PXMainDataRestoreCleanupFrame *child = [[PXMainDataRestoreCleanupFrame alloc] init];
        child.descriptor = childDescriptor;
        child.names = childNames;
        child.entryName = nameData;
        [stack addObject:child];
    }
    return YES;
}

static BOOL PXMainDataRestoreWriteAll(int descriptor, const void *bytes, size_t length) {
    const unsigned char *cursor = bytes;
    size_t remaining = length;
    while (remaining > 0) {
        ssize_t written = write(descriptor, cursor, remaining);
        if (written < 0) {
            if (errno == EINTR) {
                continue;
            }
            return NO;
        }
        if (written == 0) {
            return NO;
        }
        cursor += (size_t)written;
        remaining -= (size_t)written;
    }
    return YES;
}

static NSData *PXMainDataRestoreReadAll(int descriptor,
                                        size_t length,
                                        NSError **error,
                                        NSString *fieldPath) {
    NSMutableData *data = [NSMutableData dataWithLength:length];
    unsigned char *cursor = data.mutableBytes;
    size_t remaining = length;
    while (remaining > 0) {
        ssize_t count = read(descriptor, cursor, remaining);
        if (count < 0) {
            if (errno == EINTR) {
                continue;
            }
            return PXMainDataRestoreFailObject(error,
                                               PXMainDataRestoreTransactionErrorJournalInvalid,
                                               fieldPath,
                                               @"A transaction journal could not be read.");
        }
        if (count == 0) {
            return PXMainDataRestoreFailObject(error,
                                               PXMainDataRestoreTransactionErrorJournalInvalid,
                                               fieldPath,
                                               @"A transaction journal ended unexpectedly.");
        }
        cursor += (size_t)count;
        remaining -= (size_t)count;
    }
    return data;
}

static NSArray<NSDictionary<NSString *, id> *> *PXMainDataRestoreJournalEntries(
    NSArray<PXMainDataRestoreEntry *> *entries) {
    NSMutableArray<NSDictionary<NSString *, id> *> *objects =
        [NSMutableArray arrayWithCapacity:entries.count];
    for (PXMainDataRestoreEntry *entry in entries) {
        [objects addObject:[entry journalObject]];
    }
    return [objects copy];
}

static BOOL PXMainDataRestoreWriteJournal(int transactionDescriptor,
                                           NSData *transactionName,
                                           const struct stat *targetStat,
                                           NSArray<PXMainDataRestoreEntry *> *originalEntries,
                                           NSArray<PXMainDataRestoreEntry *> *stagedEntries,
                                           NSString *phase,
                                           NSError **error) {
    NSDictionary *journal = @{
        @"version": @1,
        @"transactionName": transactionName,
        @"targetDevice": @((unsigned long long)targetStat->st_dev),
        @"targetInode": @((unsigned long long)targetStat->st_ino),
        @"phase": phase,
        @"originalEntries": PXMainDataRestoreJournalEntries(originalEntries),
        @"stagedEntries": PXMainDataRestoreJournalEntries(stagedEntries)
    };
    NSError *serializationError = nil;
    NSData *journalData =
        [NSPropertyListSerialization dataWithPropertyList:journal
                                                   format:NSPropertyListBinaryFormat_v1_0
                                                  options:0
                                                    error:&serializationError];
    if (!journalData ||
        journalData.length == 0 ||
        journalData.length > PXMainDataRestoreMaximumJournalBytes) {
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"The main-data transaction journal could not be serialized safely.");
    }

    NSData *temporaryNameData = PXMainDataRestoreNameData(PXMainDataRestoreJournalTemporaryName);
    NSData *journalNameData = PXMainDataRestoreNameData(PXMainDataRestoreJournalName);
    char *temporaryName = PXMainDataRestoreCopyTerminatedName(temporaryNameData);
    char *journalName = PXMainDataRestoreCopyTerminatedName(journalNameData);
    if (!temporaryName || !journalName) {
        free(temporaryName);
        free(journalName);
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"The main-data transaction journal name could not be prepared.");
    }

    if (unlinkat(transactionDescriptor, temporaryName, 0) != 0 && errno != ENOENT) {
        free(temporaryName);
        free(journalName);
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"A stale temporary transaction journal could not be removed.");
    }

    int journalDescriptor = openat(transactionDescriptor,
                                   temporaryName,
                                   O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
                                   0600);
    if (journalDescriptor < 0) {
        free(temporaryName);
        free(journalName);
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"The main-data transaction journal could not be created.");
    }
    struct stat journalStat;
    memset(&journalStat, 0, sizeof(journalStat));
    BOOL journalIdentityValid =
        fchmod(journalDescriptor, 0600) == 0 &&
        fstat(journalDescriptor, &journalStat) == 0 &&
        S_ISREG(journalStat.st_mode) &&
        journalStat.st_nlink == 1;
    BOOL wrote = journalIdentityValid &&
                 PXMainDataRestoreWriteAll(journalDescriptor,
                                           journalData.bytes,
                                           journalData.length) &&
                 PXMainDataRestoreSyncDescriptor(journalDescriptor);
    int closeResult = close(journalDescriptor);
    if (!wrote || closeResult != 0) {
        unlinkat(transactionDescriptor, temporaryName, 0);
        free(temporaryName);
        free(journalName);
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"The main-data transaction journal could not be written durably.");
    }

    if (renameat(transactionDescriptor,
                 temporaryName,
                 transactionDescriptor,
                 journalName) != 0 ||
        !PXMainDataRestoreSyncDirectory(transactionDescriptor)) {
        unlinkat(transactionDescriptor, temporaryName, 0);
        free(temporaryName);
        free(journalName);
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"The main-data transaction journal could not be published durably.");
    }
    free(temporaryName);
    free(journalName);
    return YES;
}

static BOOL PXMainDataRestorePhaseIsValid(NSString *phase) {
    return [phase isEqualToString:PXMainDataRestorePhasePrepared] ||
           [phase isEqualToString:PXMainDataRestorePhaseQuarantined] ||
           [phase isEqualToString:PXMainDataRestorePhaseInstalled] ||
           [phase isEqualToString:PXMainDataRestorePhaseCommitted] ||
           [phase isEqualToString:PXMainDataRestorePhaseRollingBack] ||
           [phase isEqualToString:PXMainDataRestorePhaseRolledBack];
}

static NSArray<PXMainDataRestoreEntry *> *PXMainDataRestoreParseJournalEntries(
    id value,
    NSError **error,
    NSString *fieldPath) {
    if (![value isKindOfClass:[NSArray class]] ||
        [(NSArray *)value count] > PXMainDataRestoreMaximumTopLevelEntries) {
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorJournalInvalid,
                                           fieldPath,
                                           @"A transaction journal entry list is invalid.");
    }
    NSMutableArray<PXMainDataRestoreEntry *> *entries =
        [NSMutableArray arrayWithCapacity:[(NSArray *)value count]];
    NSMutableSet<NSData *> *names = [NSMutableSet set];
    for (id object in (NSArray *)value) {
        PXMainDataRestoreEntry *entry =
            [PXMainDataRestoreEntry entryFromJournalObject:object
                                                     error:error
                                                 fieldPath:fieldPath];
        if (!entry) {
            return nil;
        }
        if ([names containsObject:entry.nameData] ||
            PXMainDataRestoreNameIsContainerMetadata(entry.nameData) ||
            PXMainDataRestoreRawNameHasPrefix(entry.nameData,
                                              PXMainDataRestoreTransactionPrefix)) {
            return PXMainDataRestoreFailObject(error,
                                               PXMainDataRestoreTransactionErrorJournalInvalid,
                                               fieldPath,
                                               @"A transaction journal contains a duplicate or reserved entry.");
        }
        [names addObject:entry.nameData];
        [entries addObject:entry];
    }
    return [entries copy];
}

static NSDictionary<NSString *, id> *PXMainDataRestoreReadJournal(
    int transactionDescriptor,
    NSData *expectedTransactionName,
    const struct stat *targetStat,
    NSError **error) {
    NSData *journalNameData = PXMainDataRestoreNameData(PXMainDataRestoreJournalName);
    char *journalName = PXMainDataRestoreCopyTerminatedName(journalNameData);
    if (!journalName) {
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorJournalInvalid,
                                           @"$.journal",
                                           @"The transaction journal name could not be prepared.");
    }
    int journalDescriptor = openat(transactionDescriptor,
                                   journalName,
                                   O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    free(journalName);
    if (journalDescriptor < 0) {
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorJournalInvalid,
                                           @"$.journal",
                                           @"A stale main-data transaction journal is missing.");
    }
    struct stat journalStat;
    memset(&journalStat, 0, sizeof(journalStat));
    if (fstat(journalDescriptor, &journalStat) != 0 ||
        !S_ISREG(journalStat.st_mode) ||
        journalStat.st_nlink != 1 ||
        journalStat.st_size <= 0 ||
        (unsigned long long)journalStat.st_size > PXMainDataRestoreMaximumJournalBytes) {
        close(journalDescriptor);
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorJournalInvalid,
                                           @"$.journal",
                                           @"A stale main-data transaction journal has invalid metadata.");
    }
    NSData *data = PXMainDataRestoreReadAll(journalDescriptor,
                                            (size_t)journalStat.st_size,
                                            error,
                                            @"$.journal");
    int closeResult = close(journalDescriptor);
    if (!data || closeResult != 0) {
        if (data && error && !*error) {
            PXMainDataRestoreFail(error,
                                  PXMainDataRestoreTransactionErrorJournalInvalid,
                                  @"$.journal",
                                  @"A stale main-data transaction journal could not be closed safely.");
        }
        return nil;
    }

    NSError *parseError = nil;
    id propertyList = [NSPropertyListSerialization propertyListWithData:data
                                                               options:NSPropertyListImmutable
                                                                format:NULL
                                                                 error:&parseError];
    if (![propertyList isKindOfClass:[NSDictionary class]]) {
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorJournalInvalid,
                                           @"$.journal",
                                           @"A stale main-data transaction journal could not be parsed.");
    }
    NSDictionary *journal = propertyList;
    id version = journal[@"version"];
    NSData *transactionName = journal[@"transactionName"];
    id targetDevice = journal[@"targetDevice"];
    id targetInode = journal[@"targetInode"];
    NSString *phase = journal[@"phase"];
    unsigned long long versionValue = 0;
    unsigned long long targetDeviceValue = 0;
    unsigned long long targetInodeValue = 0;
    if (!PXMainDataRestoreReadUnsignedIntegralNumber(version, &versionValue) ||
        versionValue != 1 ||
        ![transactionName isKindOfClass:[NSData class]] ||
        !PXMainDataRestoreNameIsSafe(transactionName) ||
        ![transactionName isEqualToData:expectedTransactionName] ||
        !PXMainDataRestoreReadUnsignedIntegralNumber(targetDevice, &targetDeviceValue) ||
        !PXMainDataRestoreReadUnsignedIntegralNumber(targetInode, &targetInodeValue) ||
        targetDeviceValue != (unsigned long long)targetStat->st_dev ||
        targetInodeValue != (unsigned long long)targetStat->st_ino ||
        ![phase isKindOfClass:[NSString class]] ||
        !PXMainDataRestorePhaseIsValid(phase)) {
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorJournalInvalid,
                                           @"$.journal",
                                           @"A stale main-data transaction journal identity is invalid.");
    }
    NSArray<PXMainDataRestoreEntry *> *originalEntries =
        PXMainDataRestoreParseJournalEntries(journal[@"originalEntries"],
                                             error,
                                             @"$.journal.originalEntries");
    if (!originalEntries) {
        return nil;
    }
    NSArray<PXMainDataRestoreEntry *> *stagedEntries =
        PXMainDataRestoreParseJournalEntries(journal[@"stagedEntries"],
                                             error,
                                             @"$.journal.stagedEntries");
    if (!stagedEntries) {
        return nil;
    }
    return @{
        @"phase": phase,
        @"originalEntries": originalEntries,
        @"stagedEntries": stagedEntries
    };
}

static int PXMainDataRestoreOpenDirectoryAt(int parentDescriptor,
                                             NSString *name,
                                             BOOL *existsOut) {
    if (existsOut) {
        *existsOut = NO;
    }
    NSData *nameData = PXMainDataRestoreNameData(name);
    char *rawName = PXMainDataRestoreCopyTerminatedName(nameData);
    if (!rawName) {
        return -1;
    }
    int descriptor = openat(parentDescriptor,
                            rawName,
                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    int savedError = errno;
    free(rawName);
    if (descriptor >= 0) {
        if (existsOut) {
            *existsOut = YES;
        }
        return descriptor;
    }
    errno = savedError;
    return -1;
}

static BOOL PXMainDataRestoreRemoveNamedDirectoryIfPresent(int parentDescriptor,
                                                            NSString *name,
                                                            NSError **error,
                                                            NSString *fieldPath) {
    BOOL exists = NO;
    int descriptor = PXMainDataRestoreOpenDirectoryAt(parentDescriptor, name, &exists);
    if (descriptor < 0) {
        if (!exists && errno == ENOENT) {
            return YES;
        }
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorCleanupFailed,
                                     fieldPath,
                                     @"A transaction cleanup directory could not be opened.");
    }
    struct stat parentStat;
    struct stat directoryStat;
    memset(&parentStat, 0, sizeof(parentStat));
    memset(&directoryStat, 0, sizeof(directoryStat));
    if (fstat(parentDescriptor, &parentStat) != 0 ||
        fstat(descriptor, &directoryStat) != 0 ||
        !S_ISDIR(parentStat.st_mode) ||
        !S_ISDIR(directoryStat.st_mode) ||
        parentStat.st_dev != directoryStat.st_dev) {
        close(descriptor);
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorCleanupFailed,
                                     fieldPath,
                                     @"A transaction cleanup directory crosses a filesystem boundary.");
    }
    BOOL removedContents =
        PXMainDataRestoreRemoveDirectoryContents(descriptor, error, fieldPath);
    close(descriptor);
    if (!removedContents) {
        return NO;
    }
    NSData *nameData = PXMainDataRestoreNameData(name);
    char *rawName = PXMainDataRestoreCopyTerminatedName(nameData);
    if (!rawName || unlinkat(parentDescriptor, rawName, AT_REMOVEDIR) != 0) {
        free(rawName);
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorCleanupFailed,
                                     fieldPath,
                                     @"A transaction cleanup directory could not be removed.");
    }
    free(rawName);
    return YES;
}

static BOOL PXMainDataRestoreCleanupTransaction(int targetDescriptor,
                                                 int transactionDescriptor,
                                                 NSData *transactionName,
                                                 NSError **error) {
    NSArray<NSData *> *transactionEntries =
        PXMainDataRestoreReadDirectoryNames(transactionDescriptor,
                                            8,
                                            error,
                                            @"$.transaction.cleanup");
    if (!transactionEntries) {
        return NO;
    }
    for (NSData *nameData in transactionEntries) {
        BOOL allowed =
            PXMainDataRestoreRawNameEquals(nameData, PXMainDataRestoreOriginalDirectoryName) ||
            PXMainDataRestoreRawNameEquals(nameData, PXMainDataRestoreNewDirectoryName) ||
            PXMainDataRestoreRawNameEquals(nameData, PXMainDataRestoreJournalName) ||
            PXMainDataRestoreRawNameEquals(nameData, PXMainDataRestoreJournalTemporaryName);
        if (!allowed) {
            return PXMainDataRestoreFail(error,
                                         PXMainDataRestoreTransactionErrorCleanupFailed,
                                         @"$.transaction.cleanup",
                                         @"A transaction workspace contains an unexpected entry.");
        }
    }

    if (!PXMainDataRestoreRemoveNamedDirectoryIfPresent(transactionDescriptor,
                                                         PXMainDataRestoreOriginalDirectoryName,
                                                         error,
                                                         @"$.transaction.cleanup.original") ||
        !PXMainDataRestoreRemoveNamedDirectoryIfPresent(transactionDescriptor,
                                                         PXMainDataRestoreNewDirectoryName,
                                                         error,
                                                         @"$.transaction.cleanup.new")) {
        return NO;
    }

    for (NSString *fileName in @[PXMainDataRestoreJournalTemporaryName,
                                 PXMainDataRestoreJournalName]) {
        NSData *fileNameData = PXMainDataRestoreNameData(fileName);
        char *rawName = PXMainDataRestoreCopyTerminatedName(fileNameData);
        if (!rawName) {
            return PXMainDataRestoreFail(error,
                                         PXMainDataRestoreTransactionErrorCleanupFailed,
                                         @"$.transaction.cleanup",
                                         @"A transaction cleanup file name could not be prepared.");
        }
        if (unlinkat(transactionDescriptor, rawName, 0) != 0 && errno != ENOENT) {
            free(rawName);
            return PXMainDataRestoreFail(error,
                                         PXMainDataRestoreTransactionErrorCleanupFailed,
                                         @"$.transaction.cleanup",
                                         @"A transaction cleanup file could not be removed.");
        }
        free(rawName);
    }
    if (!PXMainDataRestoreSyncDirectory(transactionDescriptor)) {
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorCleanupFailed,
                                     @"$.transaction.cleanup",
                                     @"A transaction workspace cleanup could not be synchronized.");
    }

    char *rawTransactionName = PXMainDataRestoreCopyTerminatedName(transactionName);
    if (!rawTransactionName ||
        unlinkat(targetDescriptor, rawTransactionName, AT_REMOVEDIR) != 0 ||
        !PXMainDataRestoreSyncDirectory(targetDescriptor)) {
        free(rawTransactionName);
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorCleanupFailed,
                                     @"$.transaction.cleanup",
                                     @"The transaction workspace could not be removed.");
    }
    free(rawTransactionName);
    return YES;
}

static BOOL PXMainDataRestoreMoveEntry(PXMainDataRestoreEntry *entry,
                                       int sourceDescriptor,
                                       int destinationDescriptor,
                                       NSError **error,
                                       PXMainDataRestoreTransactionErrorCode code,
                                       NSString *fieldPath,
                                       NSString *description) {
    BOOL sourceExists = NO;
    BOOL destinationExists = NO;
    if (!PXMainDataRestoreEntryMatchesAt(entry, sourceDescriptor, &sourceExists) ||
        !sourceExists ||
        !PXMainDataRestoreNameState(destinationDescriptor,
                                    entry.nameData,
                                    &destinationExists,
                                    NULL) ||
        destinationExists) {
        return PXMainDataRestoreFail(error, code, fieldPath, description);
    }
    char *name = PXMainDataRestoreCopyTerminatedName(entry.nameData);
    if (!name ||
        renameat(sourceDescriptor, name, destinationDescriptor, name) != 0) {
        free(name);
        return PXMainDataRestoreFail(error, code, fieldPath, description);
    }
    free(name);
    BOOL movedExists = NO;
    if (!PXMainDataRestoreEntryMatchesAt(entry, destinationDescriptor, &movedExists) ||
        !movedExists) {
        return PXMainDataRestoreFail(error, code, fieldPath, description);
    }
    return YES;
}

static BOOL PXMainDataRestoreMoveInstalledEntriesToNew(
    NSArray<PXMainDataRestoreEntry *> *originalEntries,
    NSArray<PXMainDataRestoreEntry *> *stagedEntries,
    int targetDescriptor,
    int newDescriptor,
    NSError **error) {
    NSMutableDictionary<NSData *, PXMainDataRestoreEntry *> *originalEntriesByName =
        [NSMutableDictionary dictionaryWithCapacity:originalEntries.count];
    for (PXMainDataRestoreEntry *originalEntry in originalEntries) {
        originalEntriesByName[originalEntry.nameData] = originalEntry;
    }

    for (PXMainDataRestoreEntry *entry in stagedEntries.reverseObjectEnumerator) {
        BOOL targetExists = NO;
        BOOL newExists = NO;
        struct stat targetStat;
        struct stat newStat;
        memset(&targetStat, 0, sizeof(targetStat));
        memset(&newStat, 0, sizeof(newStat));
        if (!PXMainDataRestoreNameState(targetDescriptor,
                                        entry.nameData,
                                        &targetExists,
                                        &targetStat) ||
            !PXMainDataRestoreNameState(newDescriptor,
                                        entry.nameData,
                                        &newExists,
                                        &newStat)) {
            return PXMainDataRestoreFail(error,
                                         PXMainDataRestoreTransactionErrorRollbackFailed,
                                         @"$.transaction.rollback.new",
                                         @"A newly installed main-data entry could not be inspected during rollback.");
        }

        BOOL targetIsStagedEntry = targetExists && [entry matchesStat:&targetStat];
        BOOL newIsStagedEntry = newExists && [entry matchesStat:&newStat];
        PXMainDataRestoreEntry *originalEntry = originalEntriesByName[entry.nameData];
        BOOL targetIsOriginalEntry =
            targetExists && originalEntry && [originalEntry matchesStat:&targetStat];

        if ((targetExists && !targetIsStagedEntry && !targetIsOriginalEntry) ||
            (newExists && !newIsStagedEntry) ||
            (targetIsStagedEntry && newIsStagedEntry)) {
            return PXMainDataRestoreFail(error,
                                         PXMainDataRestoreTransactionErrorRollbackFailed,
                                         @"$.transaction.rollback.new",
                                         @"A main-data entry has an inconsistent rollback identity.");
        }
        if (!targetIsStagedEntry) {
            continue;
        }
        if (!PXMainDataRestoreMoveEntry(entry,
                                        targetDescriptor,
                                        newDescriptor,
                                        error,
                                        PXMainDataRestoreTransactionErrorRollbackFailed,
                                        @"$.transaction.rollback.new",
                                        @"A newly installed main-data entry could not be quarantined during rollback.")) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXMainDataRestoreRestoreOriginalEntries(
    NSArray<PXMainDataRestoreEntry *> *originalEntries,
    int originalDescriptor,
    int targetDescriptor,
    NSError **error) {
    for (PXMainDataRestoreEntry *entry in originalEntries.reverseObjectEnumerator) {
        BOOL originalExists = NO;
        BOOL targetExists = NO;
        if (!PXMainDataRestoreEntryMatchesAt(entry, originalDescriptor, &originalExists) ||
            !PXMainDataRestoreEntryMatchesAt(entry, targetDescriptor, &targetExists)) {
            return PXMainDataRestoreFail(error,
                                         PXMainDataRestoreTransactionErrorRollbackFailed,
                                         @"$.transaction.rollback.original",
                                         @"An original main-data entry changed before rollback.");
        }
        if (originalExists && targetExists) {
            return PXMainDataRestoreFail(error,
                                         PXMainDataRestoreTransactionErrorRollbackFailed,
                                         @"$.transaction.rollback.original",
                                         @"An original main-data entry exists in two rollback locations.");
        }
        if (!originalExists) {
            if (!targetExists) {
                return PXMainDataRestoreFail(error,
                                             PXMainDataRestoreTransactionErrorRollbackFailed,
                                             @"$.transaction.rollback.original",
                                             @"An original main-data entry is missing during rollback.");
            }
            continue;
        }
        if (!PXMainDataRestoreMoveEntry(entry,
                                        originalDescriptor,
                                        targetDescriptor,
                                        error,
                                        PXMainDataRestoreTransactionErrorRollbackFailed,
                                        @"$.transaction.rollback.original",
                                        @"An original main-data entry could not be restored during rollback.")) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXMainDataRestoreRollbackEntries(
    NSArray<PXMainDataRestoreEntry *> *originalEntries,
    NSArray<PXMainDataRestoreEntry *> *stagedEntries,
    int targetDescriptor,
    int originalDescriptor,
    int newDescriptor,
    NSError **error) {
    if (!PXMainDataRestoreMoveInstalledEntriesToNew(originalEntries,
                                                    stagedEntries,
                                                    targetDescriptor,
                                                    newDescriptor,
                                                    error) ||
        !PXMainDataRestoreRestoreOriginalEntries(originalEntries,
                                                 originalDescriptor,
                                                 targetDescriptor,
                                                 error) ||
        !PXMainDataRestoreRequireExactEntries(
            targetDescriptor,
            originalEntries,
            NO,
            NO,
            YES,
            YES,
            PXMainDataRestoreTransactionErrorRollbackFailed,
            @"$.transaction.rollback",
            @"The restored main-data namespace does not match the original journal.",
            error) ||
        !PXMainDataRestoreSyncDirectory(targetDescriptor) ||
        !PXMainDataRestoreSyncDirectory(originalDescriptor) ||
        !PXMainDataRestoreSyncDirectory(newDescriptor)) {
        if (error && !*error) {
            PXMainDataRestoreFail(error,
                                  PXMainDataRestoreTransactionErrorRollbackFailed,
                                  @"$.transaction.rollback",
                                  @"The main-data rollback could not be synchronized.");
        }
        return NO;
    }
    return YES;
}

static BOOL PXMainDataRestoreCreateTransactionWorkspace(
    int targetDescriptor,
    NSData * __strong *transactionNameOut,
    int *transactionDescriptorOut,
    int *originalDescriptorOut,
    int *newDescriptorOut,
    NSError **error) {
    if (transactionNameOut) {
        *transactionNameOut = nil;
    }
    if (transactionDescriptorOut) {
        *transactionDescriptorOut = -1;
    }
    if (originalDescriptorOut) {
        *originalDescriptorOut = -1;
    }
    if (newDescriptorOut) {
        *newDescriptorOut = -1;
    }

    int transactionDescriptor = -1;
    int originalDescriptor = -1;
    int newDescriptor = -1;
    NSData *transactionName = nil;

    for (NSUInteger attempt = 0; attempt < 16; attempt++) {
        NSString *name = [PXMainDataRestoreTransactionPrefix
            stringByAppendingString:[NSUUID UUID].UUIDString.lowercaseString];
        NSData *nameData = PXMainDataRestoreNameData(name);
        char *rawName = PXMainDataRestoreCopyTerminatedName(nameData);
        if (!rawName) {
            break;
        }
        if (mkdirat(targetDescriptor, rawName, 0700) == 0) {
            transactionName = nameData;
            transactionDescriptor = openat(targetDescriptor,
                                           rawName,
                                           O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
            if (transactionDescriptor < 0) {
                unlinkat(targetDescriptor, rawName, AT_REMOVEDIR);
                transactionName = nil;
                free(rawName);
                break;
            }
            struct stat transactionStat;
            struct stat targetStat;
            memset(&transactionStat, 0, sizeof(transactionStat));
            memset(&targetStat, 0, sizeof(targetStat));
            if (fchmod(transactionDescriptor, 0700) != 0 ||
                fstat(transactionDescriptor, &transactionStat) != 0 ||
                fstat(targetDescriptor, &targetStat) != 0 ||
                !S_ISDIR(transactionStat.st_mode) ||
                transactionStat.st_dev != targetStat.st_dev) {
                close(transactionDescriptor);
                transactionDescriptor = -1;
                unlinkat(targetDescriptor, rawName, AT_REMOVEDIR);
                transactionName = nil;
                free(rawName);
                break;
            }
            free(rawName);
            break;
        }
        int savedError = errno;
        free(rawName);
        if (savedError != EEXIST) {
            break;
        }
    }
    if (transactionDescriptor < 0 || !transactionName) {
        PXMainDataRestoreCloseDescriptor(&transactionDescriptor);
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorJournalCreationFailed,
                                     @"$.transaction",
                                     @"A private main-data transaction workspace could not be created.");
    }

    for (NSString *directoryName in @[PXMainDataRestoreOriginalDirectoryName,
                                      PXMainDataRestoreNewDirectoryName]) {
        NSData *nameData = PXMainDataRestoreNameData(directoryName);
        char *rawName = PXMainDataRestoreCopyTerminatedName(nameData);
        if (!rawName || mkdirat(transactionDescriptor, rawName, 0700) != 0) {
            free(rawName);
            goto failure;
        }
        int descriptor = openat(transactionDescriptor,
                                rawName,
                                O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        free(rawName);
        struct stat parentStat;
        struct stat directoryStat;
        memset(&parentStat, 0, sizeof(parentStat));
        memset(&directoryStat, 0, sizeof(directoryStat));
        if (descriptor < 0 ||
            fchmod(descriptor, 0700) != 0 ||
            fstat(transactionDescriptor, &parentStat) != 0 ||
            fstat(descriptor, &directoryStat) != 0 ||
            !S_ISDIR(parentStat.st_mode) ||
            !S_ISDIR(directoryStat.st_mode) ||
            parentStat.st_dev != directoryStat.st_dev) {
            PXMainDataRestoreCloseDescriptor(&descriptor);
            goto failure;
        }
        if ([directoryName isEqualToString:PXMainDataRestoreOriginalDirectoryName]) {
            originalDescriptor = descriptor;
        } else {
            newDescriptor = descriptor;
        }
    }
    if (!PXMainDataRestoreSyncDirectory(transactionDescriptor) ||
        !PXMainDataRestoreSyncDirectory(targetDescriptor)) {
        goto failure;
    }

    if (transactionNameOut) {
        *transactionNameOut = transactionName;
    }
    if (transactionDescriptorOut) {
        *transactionDescriptorOut = transactionDescriptor;
    }
    if (originalDescriptorOut) {
        *originalDescriptorOut = originalDescriptor;
    }
    if (newDescriptorOut) {
        *newDescriptorOut = newDescriptor;
    }
    return YES;

failure:
    PXMainDataRestoreCloseDescriptor(&originalDescriptor);
    PXMainDataRestoreCloseDescriptor(&newDescriptor);
    NSError *cleanupError = nil;
    PXMainDataRestoreCleanupTransaction(targetDescriptor,
                                        transactionDescriptor,
                                        transactionName,
                                        &cleanupError);
    PXMainDataRestoreCloseDescriptor(&transactionDescriptor);
    return PXMainDataRestoreFail(error,
                                 PXMainDataRestoreTransactionErrorJournalCreationFailed,
                                 @"$.transaction",
                                 @"The private main-data transaction workspace could not be initialized.");
}

static BOOL PXMainDataRestoreWorkspaceHasNoRecoveryData(int transactionDescriptor,
                                                        NSError **error) {
    NSArray<NSData *> *names =
        PXMainDataRestoreReadDirectoryNames(transactionDescriptor,
                                            4,
                                            error,
                                            @"$.recovery");
    if (!names) {
        return NO;
    }
    for (NSData *nameData in names) {
        if (PXMainDataRestoreRawNameEquals(nameData,
                                           PXMainDataRestoreOriginalDirectoryName) ||
            PXMainDataRestoreRawNameEquals(nameData,
                                           PXMainDataRestoreNewDirectoryName)) {
            char *rawName = PXMainDataRestoreCopyTerminatedName(nameData);
            if (!rawName) {
                return PXMainDataRestoreFail(error,
                                             PXMainDataRestoreTransactionErrorJournalInvalid,
                                             @"$.recovery",
                                             @"A stale recovery directory name could not be prepared.");
            }
            int descriptor = openat(transactionDescriptor,
                                    rawName,
                                    O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
            free(rawName);
            if (descriptor < 0) {
                return PXMainDataRestoreFail(error,
                                             PXMainDataRestoreTransactionErrorJournalInvalid,
                                             @"$.recovery",
                                             @"A stale recovery directory has an invalid identity.");
            }
            NSArray<NSData *> *entryNames =
                PXMainDataRestoreReadDirectoryNames(descriptor,
                                                    1,
                                                    error,
                                                    @"$.recovery");
            close(descriptor);
            if (!entryNames || entryNames.count != 0) {
                if (entryNames && error && !*error) {
                    PXMainDataRestoreFail(error,
                                          PXMainDataRestoreTransactionErrorJournalInvalid,
                                          @"$.recovery",
                                          @"A stale transaction without a journal contains recovery data.");
                }
                return NO;
            }
            continue;
        }

        if (PXMainDataRestoreRawNameEquals(nameData,
                                           PXMainDataRestoreJournalTemporaryName)) {
            BOOL exists = NO;
            struct stat value;
            memset(&value, 0, sizeof(value));
            if (!PXMainDataRestoreNameState(transactionDescriptor,
                                            nameData,
                                            &exists,
                                            &value) ||
                !exists ||
                !S_ISREG(value.st_mode) ||
                value.st_nlink != 1 ||
                value.st_size < 0 ||
                (unsigned long long)value.st_size > PXMainDataRestoreMaximumJournalBytes) {
                return PXMainDataRestoreFail(error,
                                             PXMainDataRestoreTransactionErrorJournalInvalid,
                                             @"$.recovery",
                                             @"A stale temporary journal has an invalid identity.");
            }
            continue;
        }

        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorJournalInvalid,
                                     @"$.recovery",
                                     @"A stale transaction without a journal contains an unexpected entry.");
    }
    return YES;
}

static BOOL PXMainDataRestoreRecoverOneTransaction(int targetDescriptor,
                                                    const struct stat *targetStat,
                                                    NSData *transactionName,
                                                    NSError **error) {
    char *rawTransactionName = PXMainDataRestoreCopyTerminatedName(transactionName);
    if (!rawTransactionName) {
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorJournalInvalid,
                                     @"$.recovery",
                                     @"A stale transaction name could not be prepared.");
    }
    int transactionDescriptor = openat(targetDescriptor,
                                       rawTransactionName,
                                       O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    free(rawTransactionName);
    if (transactionDescriptor < 0) {
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorJournalInvalid,
                                     @"$.recovery",
                                     @"A stale main-data transaction workspace could not be opened.");
    }
    struct stat transactionStat;
    memset(&transactionStat, 0, sizeof(transactionStat));
    if (fstat(transactionDescriptor, &transactionStat) != 0 ||
        !S_ISDIR(transactionStat.st_mode) ||
        transactionStat.st_dev != targetStat->st_dev) {
        close(transactionDescriptor);
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorJournalInvalid,
                                     @"$.recovery",
                                     @"A stale main-data transaction workspace crosses a filesystem boundary.");
    }

    BOOL journalExists = NO;
    NSData *journalNameData = PXMainDataRestoreNameData(PXMainDataRestoreJournalName);
    if (!PXMainDataRestoreNameState(transactionDescriptor,
                                    journalNameData,
                                    &journalExists,
                                    NULL)) {
        close(transactionDescriptor);
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorJournalInvalid,
                                     @"$.recovery",
                                     @"A stale transaction journal could not be inspected.");
    }
    if (!journalExists) {
        if (!PXMainDataRestoreWorkspaceHasNoRecoveryData(transactionDescriptor,
                                                         error)) {
            close(transactionDescriptor);
            return NO;
        }
        BOOL cleaned = PXMainDataRestoreCleanupTransaction(targetDescriptor,
                                                            transactionDescriptor,
                                                            transactionName,
                                                            error);
        close(transactionDescriptor);
        return cleaned;
    }

    NSDictionary<NSString *, id> *journal =
        PXMainDataRestoreReadJournal(transactionDescriptor,
                                     transactionName,
                                     targetStat,
                                     error);
    if (!journal) {
        close(transactionDescriptor);
        return NO;
    }
    NSString *phase = journal[@"phase"];
    NSArray<PXMainDataRestoreEntry *> *originalEntries = journal[@"originalEntries"];
    NSArray<PXMainDataRestoreEntry *> *stagedEntries = journal[@"stagedEntries"];

    if ([phase isEqualToString:PXMainDataRestorePhaseCommitted] ||
        [phase isEqualToString:PXMainDataRestorePhaseRolledBack]) {
        BOOL cleaned = PXMainDataRestoreCleanupTransaction(targetDescriptor,
                                                            transactionDescriptor,
                                                            transactionName,
                                                            error);
        close(transactionDescriptor);
        return cleaned;
    }

    BOOL originalExists = NO;
    BOOL newExists = NO;
    int originalDescriptor =
        PXMainDataRestoreOpenDirectoryAt(transactionDescriptor,
                                         PXMainDataRestoreOriginalDirectoryName,
                                         &originalExists);
    int newDescriptor =
        PXMainDataRestoreOpenDirectoryAt(transactionDescriptor,
                                         PXMainDataRestoreNewDirectoryName,
                                         &newExists);
    if (originalDescriptor < 0 || newDescriptor < 0 || !originalExists || !newExists) {
        PXMainDataRestoreCloseDescriptor(&originalDescriptor);
        PXMainDataRestoreCloseDescriptor(&newDescriptor);
        close(transactionDescriptor);
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorJournalInvalid,
                                     @"$.recovery",
                                     @"A stale main-data transaction workspace is incomplete.");
    }

    PXMainDataRestoreWriteJournal(transactionDescriptor,
                                  transactionName,
                                  targetStat,
                                  originalEntries,
                                  stagedEntries,
                                  PXMainDataRestorePhaseRollingBack,
                                  nil);
    BOOL rolledBack = PXMainDataRestoreRollbackEntries(originalEntries,
                                                       stagedEntries,
                                                       targetDescriptor,
                                                       originalDescriptor,
                                                       newDescriptor,
                                                       error);
    if (rolledBack) {
        NSError *rolledBackJournalError = nil;
        if (!PXMainDataRestoreWriteJournal(transactionDescriptor,
                                           transactionName,
                                           targetStat,
                                           originalEntries,
                                           stagedEntries,
                                           PXMainDataRestorePhaseRolledBack,
                                           &rolledBackJournalError)) {
            rolledBack = PXMainDataRestoreFail(error,
                                               PXMainDataRestoreTransactionErrorRollbackFailed,
                                               @"$.recovery",
                                               @"The recovered main-data state could not be journaled durably.");
        }
    }
    PXMainDataRestoreCloseDescriptor(&originalDescriptor);
    PXMainDataRestoreCloseDescriptor(&newDescriptor);
    if (rolledBack) {
        rolledBack = PXMainDataRestoreCleanupTransaction(targetDescriptor,
                                                         transactionDescriptor,
                                                         transactionName,
                                                         error);
    }
    close(transactionDescriptor);
    return rolledBack;
}

static BOOL PXMainDataRestoreRecoverStaleTransactions(int targetDescriptor,
                                                       const struct stat *targetStat,
                                                       NSUInteger *recoveredCountOut,
                                                       NSError **error) {
    if (recoveredCountOut) {
        *recoveredCountOut = 0;
    }
    NSArray<NSData *> *names =
        PXMainDataRestoreReadDirectoryNames(targetDescriptor,
                                            PXMainDataRestoreMaximumTopLevelEntries,
                                            error,
                                            @"$.recovery");
    if (!names) {
        return NO;
    }
    NSMutableArray<NSData *> *transactionNames = [NSMutableArray array];
    for (NSData *nameData in names) {
        if (PXMainDataRestoreRawNameHasPrefix(nameData,
                                              PXMainDataRestoreTransactionPrefix)) {
            [transactionNames addObject:nameData];
        }
    }
    if (transactionNames.count > 1) {
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorJournalInvalid,
                                     @"$.recovery",
                                     @"Multiple stale main-data transactions require manual recovery.");
    }
    if (transactionNames.count == 1 &&
        !PXMainDataRestoreRecoverOneTransaction(targetDescriptor,
                                                 targetStat,
                                                 transactionNames.firstObject,
                                                 error)) {
        return NO;
    }
    if (recoveredCountOut) {
        *recoveredCountOut = transactionNames.count;
    }
    return YES;
}

@interface PXMainDataRestoreTransaction ()
- (instancetype)initPrivate;
@property (nonatomic, strong) PXResolvedContainer *container;
@property (nonatomic, strong) PXValidatedMainDataStage *validatedStage;
@property (nonatomic, copy) NSString *canonicalPath;
@property (nonatomic, copy) NSString *stagePath;
@property (nonatomic, copy) NSArray<PXMainDataRestoreEntry *> *originalEntries;
@property (nonatomic, copy) NSArray<PXMainDataRestoreEntry *> *stagedEntries;
@property (nonatomic, assign) int lockDescriptor;
@property (nonatomic, assign) int targetDescriptor;
@property (nonatomic, assign) int stageDescriptor;
@property (nonatomic, assign) struct stat targetStat;
@property (nonatomic, assign) struct stat stageStat;
@property (nonatomic, assign) int transactionDescriptor;
@property (nonatomic, assign) int originalDescriptor;
@property (nonatomic, assign) int newDescriptor;
@property (nonatomic, copy, nullable) NSData *transactionName;
@property (nonatomic, assign) BOOL attempted;
@property (nonatomic, assign, readwrite, getter=isCommitted) BOOL committed;
@property (nonatomic, assign, readwrite) BOOL rollbackPerformed;
@property (nonatomic, assign, readwrite) BOOL rollbackComplete;
@property (nonatomic, assign, readwrite) NSUInteger recoveredStaleTransactionCount;
@end

@implementation PXMainDataRestoreTransaction

+ (instancetype)transactionForContainer:(PXResolvedContainer *)container
                           canonicalPath:(NSString *)canonicalPath
                          validatedStage:(PXValidatedMainDataStage *)validatedStage
                                   error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    if (![container isKindOfClass:[PXResolvedContainer class]] ||
        container.kind != PXResolvedContainerKindApplicationData ||
        ![canonicalPath isKindOfClass:[NSString class]] ||
        canonicalPath.length == 0 ||
        ![validatedStage isKindOfClass:[PXValidatedMainDataStage class]] ||
        validatedStage.dataPath.length == 0 ||
        validatedStage.treeSHA256.length != 64) {
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorInvalidInput,
                                           @"$",
                                           @"The main-data transaction input is invalid.");
    }

    PXDestructivePathValidator *validator = [[PXDestructivePathValidator alloc] init];
    NSError *validationError = nil;
    NSString *validatedPath =
        [validator validatedCanonicalPathForContainer:container error:&validationError];
    if (validationError ||
        validatedPath.length == 0 ||
        ![validatedPath isEqualToString:canonicalPath]) {
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorDestinationValidationFailed,
                                           @"$.destination",
                                           @"The exact main-data destination could not be revalidated.");
    }

    int targetDescriptor = open(canonicalPath.fileSystemRepresentation,
                                O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (targetDescriptor < 0 ||
        !PXMainDataRestorePathMatchesDescriptor(canonicalPath, targetDescriptor)) {
        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorDestinationValidationFailed,
                                           @"$.destination",
                                           @"The exact main-data destination changed before transaction preparation.");
    }

    struct stat targetStat;
    memset(&targetStat, 0, sizeof(targetStat));
    if (fstat(targetDescriptor, &targetStat) != 0 || !S_ISDIR(targetStat.st_mode)) {
        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorFilesystemInspectionFailed,
                                           @"$.destination",
                                           @"The exact main-data destination could not be inspected.");
    }

    int lockDescriptor = open(canonicalPath.fileSystemRepresentation,
                              O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (lockDescriptor < 0 ||
        !PXMainDataRestorePathMatchesDescriptor(canonicalPath, lockDescriptor)) {
        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorFilesystemInspectionFailed,
                                           @"$.destination",
                                           @"The main-data transaction lock could not be bound safely.");
    }

    struct stat lockStat;
    memset(&lockStat, 0, sizeof(lockStat));
    if (fstat(lockDescriptor, &lockStat) != 0 ||
        !S_ISDIR(targetStat.st_mode) ||
        !S_ISDIR(lockStat.st_mode) ||
        targetStat.st_dev != lockStat.st_dev ||
        targetStat.st_ino != lockStat.st_ino) {
        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorFilesystemInspectionFailed,
                                           @"$.destination",
                                           @"The main-data transaction lock does not protect the exact destination.");
    }

    if (flock(lockDescriptor, LOCK_EX | LOCK_NB) != 0) {
        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorFilesystemInspectionFailed,
                                           @"$.destination",
                                           @"Another main-data transaction is already active for this destination.");
    }

    validationError = nil;
    validatedPath = [validator validatedCanonicalPathForContainer:container
                                                            error:&validationError];
    struct stat targetLockedStat;
    struct stat lockLockedStat;
    memset(&targetLockedStat, 0, sizeof(targetLockedStat));
    memset(&lockLockedStat, 0, sizeof(lockLockedStat));
    if (validationError ||
        validatedPath.length == 0 ||
        ![validatedPath isEqualToString:canonicalPath] ||
        !PXMainDataRestorePathMatchesDescriptor(canonicalPath, targetDescriptor) ||
        !PXMainDataRestorePathMatchesDescriptor(canonicalPath, lockDescriptor) ||
        fstat(targetDescriptor, &targetLockedStat) != 0 ||
        fstat(lockDescriptor, &lockLockedStat) != 0 ||
        !PXMainDataRestoreStatIdentityMatches(&targetStat, &targetLockedStat) ||
        !PXMainDataRestoreStatIdentityMatches(&lockStat, &lockLockedStat) ||
        !S_ISDIR(targetLockedStat.st_mode) ||
        !S_ISDIR(lockLockedStat.st_mode) ||
        targetLockedStat.st_dev != lockLockedStat.st_dev ||
        targetLockedStat.st_ino != lockLockedStat.st_ino) {
        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorDestinationValidationFailed,
                                           @"$.destination",
                                           @"The exact main-data destination changed before recovery preparation.");
    }

    int stageDescriptor = open(validatedStage.dataPath.fileSystemRepresentation,
                               O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (stageDescriptor < 0 ||
        !PXMainDataRestorePathMatchesDescriptor(validatedStage.dataPath, stageDescriptor)) {
        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorFilesystemChanged,
                                           @"$.stage",
                                           @"The validated main-data stage changed before recovery preparation.");
    }

    struct stat stageStat;
    memset(&stageStat, 0, sizeof(stageStat));
    if (fstat(stageDescriptor, &stageStat) != 0 || !S_ISDIR(stageStat.st_mode)) {
        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorFilesystemInspectionFailed,
                                           @"$.stage",
                                           @"The validated main-data stage could not be inspected.");
    }
    if (stageStat.st_dev != targetStat.st_dev) {
        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorCrossDeviceBoundary,
                                           @"$.stage",
                                           @"The validated main-data stage is not on the destination filesystem.");
    }

    struct stat targetPreRecoveryStat;
    struct stat lockPreRecoveryStat;
    struct stat stagePreRecoveryStat;
    memset(&targetPreRecoveryStat, 0, sizeof(targetPreRecoveryStat));
    memset(&lockPreRecoveryStat, 0, sizeof(lockPreRecoveryStat));
    memset(&stagePreRecoveryStat, 0, sizeof(stagePreRecoveryStat));
    if (!PXMainDataRestorePathMatchesDescriptor(canonicalPath, targetDescriptor) ||
        !PXMainDataRestorePathMatchesDescriptor(canonicalPath, lockDescriptor) ||
        !PXMainDataRestorePathMatchesDescriptor(validatedStage.dataPath, stageDescriptor) ||
        fstat(targetDescriptor, &targetPreRecoveryStat) != 0 ||
        fstat(lockDescriptor, &lockPreRecoveryStat) != 0 ||
        fstat(stageDescriptor, &stagePreRecoveryStat) != 0 ||
        !PXMainDataRestoreStatIdentityMatches(&targetStat, &targetPreRecoveryStat) ||
        !PXMainDataRestoreStatIdentityMatches(&lockStat, &lockPreRecoveryStat) ||
        !PXMainDataRestoreStatIdentityMatches(&stageStat, &stagePreRecoveryStat) ||
        !S_ISDIR(targetPreRecoveryStat.st_mode) ||
        !S_ISDIR(lockPreRecoveryStat.st_mode) ||
        !S_ISDIR(stagePreRecoveryStat.st_mode) ||
        targetPreRecoveryStat.st_dev != lockPreRecoveryStat.st_dev ||
        targetPreRecoveryStat.st_ino != lockPreRecoveryStat.st_ino) {
        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorFilesystemChanged,
                                           @"$.transaction.preflight",
                                           @"The main-data transaction identity changed before stale recovery.");
    }
    if (stagePreRecoveryStat.st_dev != targetPreRecoveryStat.st_dev) {
        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorCrossDeviceBoundary,
                                           @"$.stage",
                                           @"The validated main-data stage crossed the destination filesystem boundary.");
    }

    NSUInteger recoveredCount = 0;
    if (!PXMainDataRestoreRecoverStaleTransactions(targetDescriptor,
                                                   &targetStat,
                                                   &recoveredCount,
                                                   error)) {
        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
        return nil;
    }

    validationError = nil;
    validatedPath = [validator validatedCanonicalPathForContainer:container
                                                            error:&validationError];
    struct stat targetPostRecoveryStat;
    struct stat lockPostRecoveryStat;
    struct stat stagePostRecoveryStat;
    memset(&targetPostRecoveryStat, 0, sizeof(targetPostRecoveryStat));
    memset(&lockPostRecoveryStat, 0, sizeof(lockPostRecoveryStat));
    memset(&stagePostRecoveryStat, 0, sizeof(stagePostRecoveryStat));
    if (validationError ||
        validatedPath.length == 0 ||
        ![validatedPath isEqualToString:canonicalPath] ||
        !PXMainDataRestorePathMatchesDescriptor(canonicalPath, targetDescriptor) ||
        !PXMainDataRestorePathMatchesDescriptor(canonicalPath, lockDescriptor) ||
        !PXMainDataRestorePathMatchesDescriptor(validatedStage.dataPath, stageDescriptor) ||
        fstat(targetDescriptor, &targetPostRecoveryStat) != 0 ||
        fstat(lockDescriptor, &lockPostRecoveryStat) != 0 ||
        fstat(stageDescriptor, &stagePostRecoveryStat) != 0 ||
        !PXMainDataRestoreStatIdentityMatches(&targetStat, &targetPostRecoveryStat) ||
        !PXMainDataRestoreStatIdentityMatches(&lockStat, &lockPostRecoveryStat) ||
        !PXMainDataRestoreStatIdentityMatches(&stageStat, &stagePostRecoveryStat) ||
        !S_ISDIR(targetPostRecoveryStat.st_mode) ||
        !S_ISDIR(lockPostRecoveryStat.st_mode) ||
        !S_ISDIR(stagePostRecoveryStat.st_mode) ||
        targetPostRecoveryStat.st_dev != lockPostRecoveryStat.st_dev ||
        targetPostRecoveryStat.st_ino != lockPostRecoveryStat.st_ino) {
        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorDestinationValidationFailed,
                                           @"$.transaction.recovery",
                                           @"The main-data transaction authority changed during stale recovery.");
    }
    if (stagePostRecoveryStat.st_dev != targetPostRecoveryStat.st_dev) {
        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
        return PXMainDataRestoreFailObject(error,
                                           PXMainDataRestoreTransactionErrorCrossDeviceBoundary,
                                           @"$.stage",
                                           @"The validated main-data stage crossed the destination filesystem boundary during recovery.");
    }

    NSArray<PXMainDataRestoreEntry *> *originalEntries =
        PXMainDataRestoreCollectEntries(targetDescriptor,
                                        NO,
                                        NO,
                                        YES,
                                        YES,
                                        error,
                                        @"$.destination.entries");
    if (!originalEntries) {
        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
        return nil;
    }
    NSArray<PXMainDataRestoreEntry *> *stagedEntries =
        PXMainDataRestoreCollectEntries(stageDescriptor,
                                        YES,
                                        YES,
                                        NO,
                                        NO,
                                        error,
                                        @"$.stage.entries");
    if (!stagedEntries) {
        PXMainDataRestoreCloseDescriptor(&stageDescriptor);
        PXMainDataRestoreCloseDescriptor(&lockDescriptor);
        PXMainDataRestoreCloseDescriptor(&targetDescriptor);
        return nil;
    }

    PXMainDataRestoreTransaction *transaction = [[self alloc] initPrivate];
    transaction.container = container;
    transaction.validatedStage = validatedStage;
    transaction.canonicalPath = [canonicalPath copy];
    transaction.stagePath = [validatedStage.dataPath copy];
    transaction.originalEntries = originalEntries;
    transaction.stagedEntries = stagedEntries;
    transaction.lockDescriptor = lockDescriptor;
    transaction.targetDescriptor = targetDescriptor;
    transaction.stageDescriptor = stageDescriptor;
    transaction.targetStat = targetStat;
    transaction.stageStat = stageStat;
    transaction.transactionDescriptor = -1;
    transaction.originalDescriptor = -1;
    transaction.newDescriptor = -1;
    transaction.recoveredStaleTransactionCount = recoveredCount;
    return transaction;
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _lockDescriptor = -1;
        _targetDescriptor = -1;
        _stageDescriptor = -1;
        _transactionDescriptor = -1;
        _originalDescriptor = -1;
        _newDescriptor = -1;
    }
    return self;
}

- (BOOL)revalidatePreparedStateWithError:(NSError **)error {
    PXDestructivePathValidator *validator = [[PXDestructivePathValidator alloc] init];
    NSError *validationError = nil;
    NSString *validatedPath =
        [validator validatedCanonicalPathForContainer:self.container error:&validationError];
    if (validationError ||
        validatedPath.length == 0 ||
        ![validatedPath isEqualToString:self.canonicalPath] ||
        !PXMainDataRestorePathMatchesDescriptor(self.canonicalPath, self.lockDescriptor) ||
        !PXMainDataRestorePathMatchesDescriptor(self.canonicalPath, self.targetDescriptor) ||
        !PXMainDataRestorePathMatchesDescriptor(self.stagePath, self.stageDescriptor)) {
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorFilesystemChanged,
                                     @"$.transaction.preflight",
                                     @"The main-data transaction source or destination changed before commit.");
    }
    struct stat lockStat;
    struct stat targetStat;
    struct stat stageStat;
    memset(&lockStat, 0, sizeof(lockStat));
    memset(&targetStat, 0, sizeof(targetStat));
    memset(&stageStat, 0, sizeof(stageStat));
    if (fstat(self.lockDescriptor, &lockStat) != 0 ||
        fstat(self.targetDescriptor, &targetStat) != 0 ||
        fstat(self.stageDescriptor, &stageStat) != 0 ||
        lockStat.st_dev != self.targetStat.st_dev ||
        lockStat.st_ino != self.targetStat.st_ino ||
        targetStat.st_dev != self.targetStat.st_dev ||
        targetStat.st_ino != self.targetStat.st_ino ||
        stageStat.st_dev != self.stageStat.st_dev ||
        stageStat.st_ino != self.stageStat.st_ino) {
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorFilesystemChanged,
                                     @"$.transaction.preflight",
                                     @"The main-data transaction directory identity changed before commit.");
    }

    NSArray<PXMainDataRestoreEntry *> *currentOriginalEntries =
        PXMainDataRestoreCollectEntries(self.targetDescriptor,
                                        NO,
                                        NO,
                                        YES,
                                        YES,
                                        error,
                                        @"$.destination.entries");
    if (!currentOriginalEntries ||
        !PXMainDataRestoreEntryArraysMatch(self.originalEntries, currentOriginalEntries)) {
        if (currentOriginalEntries && error && !*error) {
            PXMainDataRestoreFail(error,
                                  PXMainDataRestoreTransactionErrorFilesystemChanged,
                                  @"$.destination.entries",
                                  @"The main-data destination changed before commit.");
        }
        return NO;
    }
    NSArray<PXMainDataRestoreEntry *> *currentStagedEntries =
        PXMainDataRestoreCollectEntries(self.stageDescriptor,
                                        YES,
                                        YES,
                                        NO,
                                        NO,
                                        error,
                                        @"$.stage.entries");
    if (!currentStagedEntries ||
        !PXMainDataRestoreEntryArraysMatch(self.stagedEntries, currentStagedEntries)) {
        if (currentStagedEntries && error && !*error) {
            PXMainDataRestoreFail(error,
                                  PXMainDataRestoreTransactionErrorFilesystemChanged,
                                  @"$.stage.entries",
                                  @"The validated main-data stage changed before commit.");
        }
        return NO;
    }
    return YES;
}

- (BOOL)rollbackWithCleanupWarning:(NSError **)cleanupWarning error:(NSError **)error {
    self.rollbackPerformed = YES;
    PXMainDataRestoreWriteJournal(self.transactionDescriptor,
                                  self.transactionName,
                                  &self->_targetStat,
                                  self.originalEntries,
                                  self.stagedEntries,
                                  PXMainDataRestorePhaseRollingBack,
                                  nil);
    if (!PXMainDataRestoreRollbackEntries(self.originalEntries,
                                          self.stagedEntries,
                                          self.targetDescriptor,
                                          self.originalDescriptor,
                                          self.newDescriptor,
                                          error)) {
        self.rollbackComplete = NO;
        return NO;
    }
    NSError *rolledBackJournalError = nil;
    if (!PXMainDataRestoreWriteJournal(self.transactionDescriptor,
                                       self.transactionName,
                                       &self->_targetStat,
                                       self.originalEntries,
                                       self.stagedEntries,
                                       PXMainDataRestorePhaseRolledBack,
                                       &rolledBackJournalError)) {
        self.rollbackComplete = NO;
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorRollbackFailed,
                                     @"$.transaction.rollback",
                                     @"The restored main-data state could not be journaled durably.");
    }
    self.rollbackComplete = YES;
    PXMainDataRestoreCloseDescriptor(&_originalDescriptor);
    PXMainDataRestoreCloseDescriptor(&_newDescriptor);
    NSError *cleanupError = nil;
    if (!PXMainDataRestoreCleanupTransaction(self.targetDescriptor,
                                             self.transactionDescriptor,
                                             self.transactionName,
                                             &cleanupError)) {
        if (cleanupWarning) {
            *cleanupWarning = cleanupError;
        }
    } else {
        PXMainDataRestoreCloseDescriptor(&_transactionDescriptor);
        self.transactionName = nil;
    }
    return YES;
}

- (BOOL)commitWithCleanupWarning:(NSError **)cleanupWarning error:(NSError **)error {
    if (cleanupWarning) {
        *cleanupWarning = nil;
    }
    if (error) {
        *error = nil;
    }
    if (self.attempted) {
        return PXMainDataRestoreFail(error,
                                     PXMainDataRestoreTransactionErrorInvalidInput,
                                     @"$.transaction",
                                     @"The main-data transaction has already been attempted.");
    }
    self.attempted = YES;

    if (![self revalidatePreparedStateWithError:error]) {
        return NO;
    }
    NSData *transactionName = nil;
    int transactionDescriptor = -1;
    int originalDescriptor = -1;
    int newDescriptor = -1;
    if (!PXMainDataRestoreCreateTransactionWorkspace(self.targetDescriptor,
                                                      &transactionName,
                                                      &transactionDescriptor,
                                                      &originalDescriptor,
                                                      &newDescriptor,
                                                      error)) {
        return NO;
    }
    self.transactionName = transactionName;
    self.transactionDescriptor = transactionDescriptor;
    self.originalDescriptor = originalDescriptor;
    self.newDescriptor = newDescriptor;
    if (!PXMainDataRestoreWriteJournal(self.transactionDescriptor,
                                       self.transactionName,
                                       &self->_targetStat,
                                       self.originalEntries,
                                       self.stagedEntries,
                                       PXMainDataRestorePhasePrepared,
                                       error)) {
        NSError *cleanupError = nil;
        PXMainDataRestoreCloseDescriptor(&_originalDescriptor);
        PXMainDataRestoreCloseDescriptor(&_newDescriptor);
        if (!PXMainDataRestoreCleanupTransaction(self.targetDescriptor,
                                                 self.transactionDescriptor,
                                                 self.transactionName,
                                                 &cleanupError) &&
            cleanupWarning) {
            *cleanupWarning = cleanupError;
        }
        PXMainDataRestoreCloseDescriptor(&_transactionDescriptor);
        self.transactionName = nil;
        return NO;
    }

    NSError *operationError = nil;
    for (PXMainDataRestoreEntry *entry in self.originalEntries) {
        if (!PXMainDataRestoreMoveEntry(entry,
                                        self.targetDescriptor,
                                        self.originalDescriptor,
                                        &operationError,
                                        PXMainDataRestoreTransactionErrorQuarantineFailed,
                                        @"$.transaction.quarantine",
                                        @"An existing main-data entry could not be quarantined.")) {
            break;
        }
    }
    if (!operationError &&
        (!PXMainDataRestoreSyncDirectory(self.targetDescriptor) ||
         !PXMainDataRestoreSyncDirectory(self.originalDescriptor))) {
        PXMainDataRestoreFail(&operationError,
                              PXMainDataRestoreTransactionErrorQuarantineFailed,
                              @"$.transaction.quarantine",
                              @"The quarantined main-data state could not be synchronized.");
    }
    if (!operationError &&
        (!PXMainDataRestoreRequireExactEntries(
             self.targetDescriptor,
             @[],
             NO,
             NO,
             YES,
             YES,
             PXMainDataRestoreTransactionErrorQuarantineFailed,
             @"$.transaction.quarantine",
             @"The main-data destination is not empty after quarantine.",
             &operationError) ||
         !PXMainDataRestoreRequireExactEntries(
             self.originalDescriptor,
             self.originalEntries,
             YES,
             YES,
             NO,
             NO,
             PXMainDataRestoreTransactionErrorQuarantineFailed,
             @"$.transaction.quarantine",
             @"The quarantined main-data namespace does not match the journal.",
             &operationError))) {
        // Exact namespace validation supplied the operation error.
    }
    if (!operationError &&
        !PXMainDataRestoreWriteJournal(self.transactionDescriptor,
                                       self.transactionName,
                                       &self->_targetStat,
                                       self.originalEntries,
                                       self.stagedEntries,
                                       PXMainDataRestorePhaseQuarantined,
                                       &operationError)) {
        // The journal helper supplied the operation error.
    }

    if (!operationError) {
        for (PXMainDataRestoreEntry *entry in self.stagedEntries) {
            if (!PXMainDataRestoreMoveEntry(entry,
                                            self.stageDescriptor,
                                            self.targetDescriptor,
                                            &operationError,
                                            PXMainDataRestoreTransactionErrorCommitFailed,
                                            @"$.transaction.commit",
                                            @"A validated staged main-data entry could not be committed.")) {
                break;
            }
        }
    }
    if (!operationError &&
        (!PXMainDataRestoreSyncDirectory(self.targetDescriptor) ||
         !PXMainDataRestoreSyncDirectory(self.stageDescriptor))) {
        PXMainDataRestoreFail(&operationError,
                              PXMainDataRestoreTransactionErrorCommitFailed,
                              @"$.transaction.commit",
                              @"The committed main-data state could not be synchronized.");
    }
    if (!operationError &&
        (!PXMainDataRestoreRequireExactEntries(
             self.targetDescriptor,
             self.stagedEntries,
             NO,
             NO,
             YES,
             YES,
             PXMainDataRestoreTransactionErrorCommitFailed,
             @"$.transaction.commit",
             @"The installed main-data namespace does not match the validated stage.",
             &operationError) ||
         !PXMainDataRestoreRequireExactEntries(
             self.stageDescriptor,
             @[],
             YES,
             YES,
             NO,
             NO,
             PXMainDataRestoreTransactionErrorCommitFailed,
             @"$.transaction.commit",
             @"The validated main-data stage is not empty after installation.",
             &operationError))) {
        // Exact namespace validation supplied the operation error.
    }
    if (!operationError &&
        !PXMainDataRestoreWriteJournal(self.transactionDescriptor,
                                       self.transactionName,
                                       &self->_targetStat,
                                       self.originalEntries,
                                       self.stagedEntries,
                                       PXMainDataRestorePhaseInstalled,
                                       &operationError)) {
        // The journal helper supplied the operation error.
    }

    if (!operationError) {
        PXDestructivePathValidator *validator = [[PXDestructivePathValidator alloc] init];
        NSError *validationError = nil;
        NSString *validatedPath =
            [validator validatedCanonicalPathForContainer:self.container error:&validationError];
        if (validationError ||
            validatedPath.length == 0 ||
            ![validatedPath isEqualToString:self.canonicalPath] ||
            !PXMainDataRestorePathMatchesDescriptor(self.canonicalPath,
                                                    self.lockDescriptor) ||
            !PXMainDataRestorePathMatchesDescriptor(self.canonicalPath,
                                                    self.targetDescriptor)) {
            PXMainDataRestoreFail(&operationError,
                                  PXMainDataRestoreTransactionErrorFilesystemChanged,
                                  @"$.transaction.commit",
                                  @"The exact main-data destination changed during commit.");
        }
    }
    if (!operationError &&
        !PXMainDataRestoreRequireExactEntries(
            self.targetDescriptor,
            self.stagedEntries,
            NO,
            NO,
            YES,
            YES,
            PXMainDataRestoreTransactionErrorCommitFailed,
            @"$.transaction.commit",
            @"The final main-data namespace changed before durable commit.",
            &operationError)) {
        // Exact namespace validation supplied the operation error.
    }
    if (!operationError &&
        !PXMainDataRestoreWriteJournal(self.transactionDescriptor,
                                       self.transactionName,
                                       &self->_targetStat,
                                       self.originalEntries,
                                       self.stagedEntries,
                                       PXMainDataRestorePhaseCommitted,
                                       &operationError)) {
        // The journal helper supplied the operation error.
    }

    if (operationError) {
        NSError *rollbackError = nil;
        NSError *rollbackCleanupWarning = nil;
        if (![self rollbackWithCleanupWarning:&rollbackCleanupWarning error:&rollbackError]) {
            if (error) {
                *error = rollbackError ?: [NSError errorWithDomain:PXMainDataRestoreTransactionErrorDomain
                                                               code:PXMainDataRestoreTransactionErrorRollbackFailed
                                                           userInfo:@{
                                                               NSLocalizedDescriptionKey: @"The main-data transaction failed and rollback did not complete.",
                                                               PXMainDataRestoreTransactionErrorFieldPathKey: @"$.transaction.rollback"
                                                           }];
            }
            if (cleanupWarning && rollbackCleanupWarning) {
                *cleanupWarning = rollbackCleanupWarning;
            }
            return NO;
        }
        if (cleanupWarning && rollbackCleanupWarning) {
            *cleanupWarning = rollbackCleanupWarning;
        }
        if (error) {
            *error = operationError;
        }
        return NO;
    }

    self.committed = YES;
    PXMainDataRestoreCloseDescriptor(&_originalDescriptor);
    PXMainDataRestoreCloseDescriptor(&_newDescriptor);
    NSError *transactionCleanupError = nil;
    if (!PXMainDataRestoreCleanupTransaction(self.targetDescriptor,
                                             self.transactionDescriptor,
                                             self.transactionName,
                                             &transactionCleanupError)) {
        if (cleanupWarning) {
            *cleanupWarning = transactionCleanupError;
        }
    } else {
        PXMainDataRestoreCloseDescriptor(&_transactionDescriptor);
        self.transactionName = nil;
    }
    return YES;
}

- (void)dealloc {
    if (self.transactionDescriptor >= 0 && self.transactionName) {
        if (!self.committed && !self.rollbackComplete) {
            [self rollbackWithCleanupWarning:nil error:nil];
        } else {
            PXMainDataRestoreCloseDescriptor(&_originalDescriptor);
            PXMainDataRestoreCloseDescriptor(&_newDescriptor);
            PXMainDataRestoreCleanupTransaction(self.targetDescriptor,
                                                self.transactionDescriptor,
                                                self.transactionName,
                                                nil);
        }
    }
    PXMainDataRestoreCloseDescriptor(&_originalDescriptor);
    PXMainDataRestoreCloseDescriptor(&_newDescriptor);
    PXMainDataRestoreCloseDescriptor(&_transactionDescriptor);
    PXMainDataRestoreCloseDescriptor(&_stageDescriptor);
    PXMainDataRestoreCloseDescriptor(&_targetDescriptor);
    PXMainDataRestoreCloseDescriptor(&_lockDescriptor);
}

@end
