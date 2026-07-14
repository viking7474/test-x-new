#import "PXOptionalRestoreTransaction.h"
#import "PXMainDataStaging.h"
#import "PXOptionalRestoreStaging.h"
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CommonCrypto/CommonDigest.h>

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

NSString * const PXOptionalRestoreTransactionErrorDomain = @"PXOptionalRestoreTransactionErrorDomain";
NSString * const PXOptionalRestoreTransactionErrorFieldPathKey = @"PXOptionalRestoreTransactionErrorFieldPathKey";

static NSString * const PXOptionalRestoreTransactionPrefix = @".weaponx-optional-restore-";
static NSString * const PXOptionalRestoreOriginalName = @"original";
static NSString * const PXOptionalRestoreReplacementName = @"replacement";
static NSString * const PXOptionalRestoreNewName = @"new";
static NSString * const PXOptionalRestoreJournalName = @"transaction.plist";
static NSString * const PXOptionalRestoreJournalTemporaryName = @"transaction.tmp";

static NSString * const PXOptionalRestorePhasePrepared = @"prepared";
static NSString * const PXOptionalRestorePhaseQuarantined = @"quarantined";
static NSString * const PXOptionalRestorePhaseInstalled = @"installed";
static NSString * const PXOptionalRestorePhaseCommitted = @"committed";
static NSString * const PXOptionalRestorePhaseRollingBack = @"rolling-back";
static NSString * const PXOptionalRestorePhaseRolledBack = @"rolled-back";

static const NSUInteger PXOptionalRestoreMaximumItems = 4096;
static const NSUInteger PXOptionalRestoreMaximumTopLevelEntries = 200000;
static const NSUInteger PXOptionalRestoreMaximumAggregateEntries = 500000;
static const unsigned long long PXOptionalRestoreMaximumFileBytes = 64ULL * 1024ULL * 1024ULL * 1024ULL;
static const NSUInteger PXOptionalRestoreMaximumPathBytes = 4096;
static const NSUInteger PXOptionalRestoreMaximumComponentBytes = 255;
static const NSUInteger PXOptionalRestoreMaximumCleanupEntries = 500000;
static const NSUInteger PXOptionalRestoreMaximumCleanupDepth = 2048;
static const NSUInteger PXOptionalRestoreMaximumTreeDepth = 2048;
static const NSUInteger PXOptionalRestoreMaximumJournalBytes = 128 * 1024 * 1024;
static const NSUInteger PXOptionalRestoreMaximumStaleTransactionIdentifiers = 1;
static const NSUInteger PXOptionalRestoreMaximumWorkspaceEntries = 8;
static const size_t PXOptionalRestoreStreamBufferSize = 64 * 1024;

static BOOL PXOptionalRestoreFail(NSError **error,
                                  PXOptionalRestoreTransactionErrorCode code,
                                  NSString *fieldPath,
                                  NSString *description) {
    if (error) {
        *error = [NSError errorWithDomain:PXOptionalRestoreTransactionErrorDomain
                                     code:code
                                 userInfo:@{
                                     NSLocalizedDescriptionKey: description,
                                     PXOptionalRestoreTransactionErrorFieldPathKey: fieldPath
                                 }];
    }
    return NO;
}

static id PXOptionalRestoreFailObject(NSError **error,
                                      PXOptionalRestoreTransactionErrorCode code,
                                      NSString *fieldPath,
                                      NSString *description) {
    PXOptionalRestoreFail(error, code, fieldPath, description);
    return nil;
}

static BOOL PXOptionalRestoreReadUnsignedIntegralNumber(id value,
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

static void PXOptionalRestoreCloseDescriptor(int *descriptor) {
    if (descriptor && *descriptor >= 0) {
        close(*descriptor);
        *descriptor = -1;
    }
}

static BOOL PXOptionalRestoreSetCloseOnExec(int descriptor) {
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

static int PXOptionalRestoreDuplicateDescriptor(int descriptor) {
    int duplicate = dup(descriptor);
    if (duplicate < 0) {
        return -1;
    }
    if (!PXOptionalRestoreSetCloseOnExec(duplicate)) {
        close(duplicate);
        return -1;
    }
    return duplicate;
}

static BOOL PXOptionalRestoreSyncDescriptor(int descriptor) {
    int result = -1;
    do {
        result = fsync(descriptor);
    } while (result != 0 && errno == EINTR);
    return result == 0;
}

static BOOL PXOptionalRestoreSyncDirectory(int descriptor) {
    return PXOptionalRestoreSyncDescriptor(descriptor);
}

static BOOL PXOptionalRestoreStatIdentityMatches(const struct stat *expected,
                                                 const struct stat *actual) {
    return expected && actual &&
           expected->st_dev == actual->st_dev &&
           expected->st_ino == actual->st_ino &&
           ((expected->st_mode & S_IFMT) == (actual->st_mode & S_IFMT));
}

static NSComparisonResult PXOptionalRestoreCompareRawNames(NSData *left, NSData *right) {
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

static char *PXOptionalRestoreCopyTerminatedName(NSData *nameData) {
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

static NSData *PXOptionalRestoreNameData(NSString *name) {
    return [name dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
}

static BOOL PXOptionalRestoreRawNameEquals(NSData *nameData, NSString *name) {
    NSData *expected = PXOptionalRestoreNameData(name);
    return expected && [nameData isEqualToData:expected];
}

static BOOL PXOptionalRestoreRawNameHasPrefix(NSData *nameData, NSString *prefix) {
    NSData *prefixData = PXOptionalRestoreNameData(prefix);
    if (!prefixData || nameData.length < prefixData.length) {
        return NO;
    }
    return prefixData.length == 0 ||
           memcmp(nameData.bytes, prefixData.bytes, prefixData.length) == 0;
}

static BOOL PXOptionalRestoreNameIsSafe(NSData *nameData) {
    if (![nameData isKindOfClass:[NSData class]] ||
        nameData.length == 0 ||
        nameData.length > PXOptionalRestoreMaximumComponentBytes) {
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

static BOOL PXOptionalRestoreNameIsContainerMetadata(NSData *nameData) {
    return PXOptionalRestoreRawNameEquals(nameData,
                                          @".com.apple.mobile_container_manager.metadata.plist") ||
           PXOptionalRestoreRawNameEquals(nameData,
                                          @".com.apple.containermanagerd.metadata.plist");
}

static NSArray<NSData *> *PXOptionalRestoreReadDirectoryNames(int descriptor,
                                                              NSUInteger maximumNameCount,
                                                              NSError **error,
                                                              NSString *fieldPath) {
    int enumerationDescriptor = PXOptionalRestoreDuplicateDescriptor(descriptor);
    if (enumerationDescriptor < 0 ||
        lseek(enumerationDescriptor, 0, SEEK_SET) < 0) {
        if (enumerationDescriptor >= 0) {
            close(enumerationDescriptor);
        }
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                           fieldPath,
                                           @"A directory enumeration descriptor could not be prepared.");
    }

    DIR *directory = fdopendir(enumerationDescriptor);
    if (!directory) {
        close(enumerationDescriptor);
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
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
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorEntryLimitExceeded,
                                               fieldPath,
                                               @"A transaction directory entry limit was exceeded.");
        }
        size_t length = strlen(name);
        NSData *nameData = [NSData dataWithBytes:name length:length];
        if (!PXOptionalRestoreNameIsSafe(nameData)) {
            closedir(directory);
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                               fieldPath,
                                               @"A transaction directory contains an unsafe entry name.");
        }
        [names addObject:nameData];
    }

    if (closedir(directory) != 0 && enumerationError == 0) {
        enumerationError = errno ?: EIO;
    }
    if (enumerationError != 0) {
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                           fieldPath,
                                           @"Directory enumeration did not complete safely.");
    }

    return [names sortedArrayUsingComparator:^NSComparisonResult(NSData *left, NSData *right) {
        return PXOptionalRestoreCompareRawNames(left, right);
    }];
}

static BOOL PXOptionalRestorePathMatchesDescriptor(NSString *path, int descriptor) {
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

static BOOL PXOptionalRestoreNameState(int descriptor,
                                       NSData *nameData,
                                       BOOL *existsOut,
                                       struct stat *statOut) {
    if (existsOut) {
        *existsOut = NO;
    }
    char *name = PXOptionalRestoreCopyTerminatedName(nameData);
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

@interface PXOptionalRestoreEntry : NSObject
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

@implementation PXOptionalRestoreEntry

+ (instancetype)entryForNameData:(NSData *)nameData
                      descriptor:(int)descriptor
                           error:(NSError **)error
                       fieldPath:(NSString *)fieldPath {
    if (!PXOptionalRestoreNameIsSafe(nameData)) {
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                           fieldPath,
                                           @"A transaction entry name is invalid.");
    }
    BOOL exists = NO;
    struct stat value;
    memset(&value, 0, sizeof(value));
    if (!PXOptionalRestoreNameState(descriptor, nameData, &exists, &value) || !exists) {
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorFilesystemChanged,
                                           fieldPath,
                                           @"A planned transaction entry changed before inspection completed.");
    }
    PXOptionalRestoreEntry *entry = [[self alloc] init];
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
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorJournalInvalid,
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
    if (!PXOptionalRestoreNameIsSafe(nameData) ||
        !PXOptionalRestoreReadUnsignedIntegralNumber(device, &deviceValue) ||
        !PXOptionalRestoreReadUnsignedIntegralNumber(inode, &inodeValue) ||
        !PXOptionalRestoreReadUnsignedIntegralNumber(modeType, &modeValue)) {
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorJournalInvalid,
                                           fieldPath,
                                           @"A transaction journal entry is invalid.");
    }
    if (inodeValue == 0 || modeValue > UINT_MAX || (modeValue & S_IFMT) == 0) {
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorJournalInvalid,
                                           fieldPath,
                                           @"A transaction journal entry identity is invalid.");
    }
    PXOptionalRestoreEntry *entry = [[self alloc] init];
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

static NSArray<PXOptionalRestoreEntry *> *PXOptionalRestoreCollectEntries(
    int descriptor,
    BOOL rejectContainerMetadata,
    BOOL rejectTransactionPrefix,
    BOOL skipContainerMetadata,
    BOOL skipTransactionPrefix,
    NSError **error,
    NSString *fieldPath) {
    NSArray<NSData *> *names =
        PXOptionalRestoreReadDirectoryNames(descriptor,
                                            PXOptionalRestoreMaximumTopLevelEntries,
                                            error,
                                            fieldPath);
    if (!names) {
        return nil;
    }
    NSMutableArray<PXOptionalRestoreEntry *> *entries =
        [NSMutableArray arrayWithCapacity:names.count];
    for (NSData *nameData in names) {
        BOOL metadata = PXOptionalRestoreNameIsContainerMetadata(nameData);
        BOOL transactionName =
            PXOptionalRestoreRawNameHasPrefix(nameData, PXOptionalRestoreTransactionPrefix);
        if ((rejectContainerMetadata && metadata) ||
            (rejectTransactionPrefix && transactionName)) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                               fieldPath,
                                               @"A reserved transaction entry name is present.");
        }
        if ((skipContainerMetadata && metadata) ||
            (skipTransactionPrefix && transactionName)) {
            continue;
        }
        PXOptionalRestoreEntry *entry =
            [PXOptionalRestoreEntry entryForNameData:nameData
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

static BOOL PXOptionalRestoreEntryArraysMatch(NSArray<PXOptionalRestoreEntry *> *expected,
                                               NSArray<PXOptionalRestoreEntry *> *actual) {
    if (expected.count != actual.count) {
        return NO;
    }
    for (NSUInteger index = 0; index < expected.count; index++) {
        PXOptionalRestoreEntry *left = expected[index];
        PXOptionalRestoreEntry *right = actual[index];
        if (![left.nameData isEqualToData:right.nameData] ||
            left.device != right.device ||
            left.inode != right.inode ||
            left.modeType != right.modeType) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXOptionalRestoreRequireExactEntries(
    int descriptor,
    NSArray<PXOptionalRestoreEntry *> *expectedEntries,
    BOOL rejectContainerMetadata,
    BOOL rejectTransactionPrefix,
    BOOL skipContainerMetadata,
    BOOL skipTransactionPrefix,
    PXOptionalRestoreTransactionErrorCode code,
    NSString *fieldPath,
    NSString *description,
    NSError **error) {
    NSError *inspectionError = nil;
    NSArray<PXOptionalRestoreEntry *> *actualEntries =
        PXOptionalRestoreCollectEntries(descriptor,
                                        rejectContainerMetadata,
                                        rejectTransactionPrefix,
                                        skipContainerMetadata,
                                        skipTransactionPrefix,
                                        &inspectionError,
                                        fieldPath);
    if (!actualEntries ||
        !PXOptionalRestoreEntryArraysMatch(expectedEntries, actualEntries)) {
        return PXOptionalRestoreFail(error,
                                     code,
                                     fieldPath,
                                     description);
    }
    return YES;
}

static BOOL PXOptionalRestoreEntryMatchesAt(PXOptionalRestoreEntry *entry,
                                             int descriptor,
                                             BOOL *existsOut) {
    BOOL exists = NO;
    struct stat value;
    memset(&value, 0, sizeof(value));
    if (!PXOptionalRestoreNameState(descriptor, entry.nameData, &exists, &value)) {
        return NO;
    }
    if (existsOut) {
        *existsOut = exists;
    }
    return !exists || [entry matchesStat:&value];
}

@interface PXOptionalRestoreCleanupFrame : NSObject
@property (nonatomic, assign) int descriptor;
@property (nonatomic, copy) NSArray<NSData *> *names;
@property (nonatomic, assign) NSUInteger nextIndex;
@property (nonatomic, copy, nullable) NSData *entryName;
@end

@implementation PXOptionalRestoreCleanupFrame
- (instancetype)init {
    self = [super init];
    if (self) {
        _descriptor = -1;
    }
    return self;
}
- (void)dealloc {
    PXOptionalRestoreCloseDescriptor(&_descriptor);
}
@end

static BOOL PXOptionalRestoreRemoveDirectoryContents(int rootDescriptor,
                                                      NSError **error,
                                                      NSString *fieldPath) {
    struct stat rootStat;
    memset(&rootStat, 0, sizeof(rootStat));
    if (fstat(rootDescriptor, &rootStat) != 0 || !S_ISDIR(rootStat.st_mode)) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorCleanupFailed,
                                     fieldPath,
                                     @"A transaction cleanup root could not be inspected.");
    }
    NSArray<NSData *> *rootNames =
        PXOptionalRestoreReadDirectoryNames(rootDescriptor,
                                            PXOptionalRestoreMaximumCleanupEntries,
                                            error,
                                            fieldPath);
    if (!rootNames) {
        return NO;
    }
    int rootDuplicate = PXOptionalRestoreDuplicateDescriptor(rootDescriptor);
    if (rootDuplicate < 0) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorCleanupFailed,
                                     fieldPath,
                                     @"A transaction cleanup descriptor could not be prepared.");
    }

    PXOptionalRestoreCleanupFrame *rootFrame = [[PXOptionalRestoreCleanupFrame alloc] init];
    rootFrame.descriptor = rootDuplicate;
    rootFrame.names = rootNames;
    NSMutableArray<PXOptionalRestoreCleanupFrame *> *stack = [NSMutableArray arrayWithObject:rootFrame];
    NSUInteger visited = 0;

    while (stack.count > 0) {
        PXOptionalRestoreCleanupFrame *frame = stack.lastObject;
        if (frame.nextIndex >= frame.names.count) {
            NSData *entryName = frame.entryName;
            [stack removeLastObject];
            if (entryName && stack.count > 0) {
                PXOptionalRestoreCleanupFrame *parent = stack.lastObject;
                char *name = PXOptionalRestoreCopyTerminatedName(entryName);
                if (!name || unlinkat(parent.descriptor, name, AT_REMOVEDIR) != 0) {
                    free(name);
                    return PXOptionalRestoreFail(error,
                                                 PXOptionalRestoreTransactionErrorCleanupFailed,
                                                 fieldPath,
                                                 @"A transaction cleanup directory could not be removed.");
                }
                free(name);
            }
            continue;
        }

        if (stack.count > PXOptionalRestoreMaximumCleanupDepth ||
            visited >= PXOptionalRestoreMaximumCleanupEntries) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorEntryLimitExceeded,
                                         fieldPath,
                                         @"A transaction cleanup limit was exceeded.");
        }

        NSData *nameData = frame.names[frame.nextIndex++];
        visited++;
        char *name = PXOptionalRestoreCopyTerminatedName(nameData);
        if (!name) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorCleanupFailed,
                                         fieldPath,
                                         @"A transaction cleanup entry name could not be prepared.");
        }
        struct stat before;
        memset(&before, 0, sizeof(before));
        if (fstatat(frame.descriptor, name, &before, AT_SYMLINK_NOFOLLOW) != 0) {
            free(name);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorCleanupFailed,
                                         fieldPath,
                                         @"A transaction cleanup entry could not be inspected.");
        }

        if (!S_ISDIR(before.st_mode)) {
            int unlinkResult = unlinkat(frame.descriptor, name, 0);
            free(name);
            if (unlinkResult != 0) {
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorCleanupFailed,
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
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorCleanupFailed,
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
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorFilesystemChanged,
                                         fieldPath,
                                         @"A transaction cleanup directory changed during traversal.");
        }
        NSUInteger remaining = PXOptionalRestoreMaximumCleanupEntries - visited;
        NSArray<NSData *> *childNames =
            PXOptionalRestoreReadDirectoryNames(childDescriptor,
                                                remaining,
                                                error,
                                                fieldPath);
        if (!childNames) {
            close(childDescriptor);
            return NO;
        }
        PXOptionalRestoreCleanupFrame *child = [[PXOptionalRestoreCleanupFrame alloc] init];
        child.descriptor = childDescriptor;
        child.names = childNames;
        child.entryName = nameData;
        [stack addObject:child];
    }
    return YES;
}

static BOOL PXOptionalRestoreWriteAll(int descriptor, const void *bytes, size_t length) {
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

static NSData *PXOptionalRestoreReadAll(int descriptor,
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
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorJournalInvalid,
                                               fieldPath,
                                               @"A transaction journal could not be read.");
        }
        if (count == 0) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorJournalInvalid,
                                               fieldPath,
                                               @"A transaction journal ended unexpectedly.");
        }
        cursor += (size_t)count;
        remaining -= (size_t)count;
    }
    return data;
}

static BOOL PXOptionalRestorePhaseIsValid(NSString *phase) {
    return [phase isEqualToString:PXOptionalRestorePhasePrepared] ||
           [phase isEqualToString:PXOptionalRestorePhaseQuarantined] ||
           [phase isEqualToString:PXOptionalRestorePhaseInstalled] ||
           [phase isEqualToString:PXOptionalRestorePhaseCommitted] ||
           [phase isEqualToString:PXOptionalRestorePhaseRollingBack] ||
           [phase isEqualToString:PXOptionalRestorePhaseRolledBack];
}

static NSArray<PXOptionalRestoreEntry *> *PXOptionalRestoreParseJournalEntries(
    id value,
    NSError **error,
    NSString *fieldPath) {
    if (![value isKindOfClass:[NSArray class]] ||
        [(NSArray *)value count] > PXOptionalRestoreMaximumTopLevelEntries) {
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorJournalInvalid,
                                           fieldPath,
                                           @"A transaction journal entry list is invalid.");
    }
    NSMutableArray<PXOptionalRestoreEntry *> *entries =
        [NSMutableArray arrayWithCapacity:[(NSArray *)value count]];
    NSMutableSet<NSData *> *names = [NSMutableSet set];
    for (id object in (NSArray *)value) {
        PXOptionalRestoreEntry *entry =
            [PXOptionalRestoreEntry entryFromJournalObject:object
                                                     error:error
                                                 fieldPath:fieldPath];
        if (!entry) {
            return nil;
        }
        if ([names containsObject:entry.nameData] ||
            PXOptionalRestoreNameIsContainerMetadata(entry.nameData) ||
            PXOptionalRestoreRawNameHasPrefix(entry.nameData,
                                              PXOptionalRestoreTransactionPrefix)) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorJournalInvalid,
                                               fieldPath,
                                               @"A transaction journal contains a duplicate or reserved entry.");
        }
        [names addObject:entry.nameData];
        [entries addObject:entry];
    }
    return [entries copy];
}
static int PXOptionalRestoreOpenDirectoryAt(int parentDescriptor,
                                             NSString *name,
                                             BOOL *existsOut) {
    if (existsOut) {
        *existsOut = NO;
    }
    NSData *nameData = PXOptionalRestoreNameData(name);
    char *rawName = PXOptionalRestoreCopyTerminatedName(nameData);
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

static BOOL PXOptionalRestoreRemoveNamedDirectoryIfPresent(int parentDescriptor,
                                                            NSString *name,
                                                            NSError **error,
                                                            NSString *fieldPath) {
    BOOL exists = NO;
    int descriptor = PXOptionalRestoreOpenDirectoryAt(parentDescriptor, name, &exists);
    if (descriptor < 0) {
        if (!exists && errno == ENOENT) {
            return YES;
        }
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorCleanupFailed,
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
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorCleanupFailed,
                                     fieldPath,
                                     @"A transaction cleanup directory crosses a filesystem boundary.");
    }
    BOOL removedContents =
        PXOptionalRestoreRemoveDirectoryContents(descriptor, error, fieldPath);
    close(descriptor);
    if (!removedContents) {
        return NO;
    }
    NSData *nameData = PXOptionalRestoreNameData(name);
    char *rawName = PXOptionalRestoreCopyTerminatedName(nameData);
    if (!rawName || unlinkat(parentDescriptor, rawName, AT_REMOVEDIR) != 0) {
        free(rawName);
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorCleanupFailed,
                                     fieldPath,
                                     @"A transaction cleanup directory could not be removed.");
    }
    free(rawName);
    return YES;
}
static BOOL PXOptionalRestoreMoveEntry(PXOptionalRestoreEntry *entry,
                                       int sourceDescriptor,
                                       int destinationDescriptor,
                                       NSError **error,
                                       PXOptionalRestoreTransactionErrorCode code,
                                       NSString *fieldPath,
                                       NSString *description) {
    BOOL sourceExists = NO;
    BOOL destinationExists = NO;
    if (!PXOptionalRestoreEntryMatchesAt(entry, sourceDescriptor, &sourceExists) ||
        !sourceExists ||
        !PXOptionalRestoreNameState(destinationDescriptor,
                                    entry.nameData,
                                    &destinationExists,
                                    NULL) ||
        destinationExists) {
        return PXOptionalRestoreFail(error, code, fieldPath, description);
    }
    char *name = PXOptionalRestoreCopyTerminatedName(entry.nameData);
    if (!name ||
        renameat(sourceDescriptor, name, destinationDescriptor, name) != 0) {
        free(name);
        return PXOptionalRestoreFail(error, code, fieldPath, description);
    }
    free(name);
    BOOL movedExists = NO;
    if (!PXOptionalRestoreEntryMatchesAt(entry, destinationDescriptor, &movedExists) ||
        !movedExists) {
        return PXOptionalRestoreFail(error, code, fieldPath, description);
    }
    return YES;
}

static BOOL PXOptionalRestoreMoveInstalledEntriesToNew(
    NSArray<PXOptionalRestoreEntry *> *originalEntries,
    NSArray<PXOptionalRestoreEntry *> *stagedEntries,
    int targetDescriptor,
    int newDescriptor,
    NSError **error) {
    NSMutableDictionary<NSData *, PXOptionalRestoreEntry *> *originalEntriesByName =
        [NSMutableDictionary dictionaryWithCapacity:originalEntries.count];
    for (PXOptionalRestoreEntry *originalEntry in originalEntries) {
        originalEntriesByName[originalEntry.nameData] = originalEntry;
    }

    for (PXOptionalRestoreEntry *entry in stagedEntries.reverseObjectEnumerator) {
        BOOL targetExists = NO;
        BOOL newExists = NO;
        struct stat targetStat;
        struct stat newStat;
        memset(&targetStat, 0, sizeof(targetStat));
        memset(&newStat, 0, sizeof(newStat));
        if (!PXOptionalRestoreNameState(targetDescriptor,
                                        entry.nameData,
                                        &targetExists,
                                        &targetStat) ||
            !PXOptionalRestoreNameState(newDescriptor,
                                        entry.nameData,
                                        &newExists,
                                        &newStat)) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorRollbackFailed,
                                         @"$.transaction.rollback.new",
                                         @"A newly installed optional Restore entry could not be inspected during rollback.");
        }

        BOOL targetIsStagedEntry = targetExists && [entry matchesStat:&targetStat];
        BOOL newIsStagedEntry = newExists && [entry matchesStat:&newStat];
        PXOptionalRestoreEntry *originalEntry = originalEntriesByName[entry.nameData];
        BOOL targetIsOriginalEntry =
            targetExists && originalEntry && [originalEntry matchesStat:&targetStat];

        if ((targetExists && !targetIsStagedEntry && !targetIsOriginalEntry) ||
            (newExists && !newIsStagedEntry) ||
            (targetIsStagedEntry && newIsStagedEntry)) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorRollbackFailed,
                                         @"$.transaction.rollback.new",
                                         @"A optional Restore entry has an inconsistent rollback identity.");
        }
        if (!targetIsStagedEntry) {
            continue;
        }
        if (!PXOptionalRestoreMoveEntry(entry,
                                        targetDescriptor,
                                        newDescriptor,
                                        error,
                                        PXOptionalRestoreTransactionErrorRollbackFailed,
                                        @"$.transaction.rollback.new",
                                        @"A newly installed optional Restore entry could not be quarantined during rollback.")) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXOptionalRestoreRestoreOriginalEntries(
    NSArray<PXOptionalRestoreEntry *> *originalEntries,
    int originalDescriptor,
    int targetDescriptor,
    NSError **error) {
    for (PXOptionalRestoreEntry *entry in originalEntries.reverseObjectEnumerator) {
        BOOL originalExists = NO;
        BOOL targetExists = NO;
        if (!PXOptionalRestoreEntryMatchesAt(entry, originalDescriptor, &originalExists) ||
            !PXOptionalRestoreEntryMatchesAt(entry, targetDescriptor, &targetExists)) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorRollbackFailed,
                                         @"$.transaction.rollback.original",
                                         @"An original optional Restore entry changed before rollback.");
        }
        if (originalExists && targetExists) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorRollbackFailed,
                                         @"$.transaction.rollback.original",
                                         @"An original optional Restore entry exists in two rollback locations.");
        }
        if (!originalExists) {
            if (!targetExists) {
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorRollbackFailed,
                                             @"$.transaction.rollback.original",
                                             @"An original optional Restore entry is missing during rollback.");
            }
            continue;
        }
        if (!PXOptionalRestoreMoveEntry(entry,
                                        originalDescriptor,
                                        targetDescriptor,
                                        error,
                                        PXOptionalRestoreTransactionErrorRollbackFailed,
                                        @"$.transaction.rollback.original",
                                        @"An original optional Restore entry could not be restored during rollback.")) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXOptionalRestoreRollbackEntries(
    NSArray<PXOptionalRestoreEntry *> *originalEntries,
    NSArray<PXOptionalRestoreEntry *> *stagedEntries,
    int targetDescriptor,
    int originalDescriptor,
    int newDescriptor,
    NSError **error) {
    if (!PXOptionalRestoreMoveInstalledEntriesToNew(originalEntries,
                                                    stagedEntries,
                                                    targetDescriptor,
                                                    newDescriptor,
                                                    error) ||
        !PXOptionalRestoreRestoreOriginalEntries(originalEntries,
                                                 originalDescriptor,
                                                 targetDescriptor,
                                                 error) ||
        !PXOptionalRestoreRequireExactEntries(
            targetDescriptor,
            originalEntries,
            NO,
            NO,
            YES,
            YES,
            PXOptionalRestoreTransactionErrorRollbackFailed,
            @"$.transaction.rollback",
            @"The restored optional Restore namespace does not match the original journal.",
            error) ||
        !PXOptionalRestoreSyncDirectory(targetDescriptor) ||
        !PXOptionalRestoreSyncDirectory(originalDescriptor) ||
        !PXOptionalRestoreSyncDirectory(newDescriptor)) {
        if (error && !*error) {
            PXOptionalRestoreFail(error,
                                  PXOptionalRestoreTransactionErrorRollbackFailed,
                                  @"$.transaction.rollback",
                                  @"The optional Restore rollback could not be synchronized.");
        }
        return NO;
    }
    return YES;
}

#pragma mark - Item contract and replacement verification

static BOOL PXOptionalRestoreCanonicalBytesAreValid(NSData *bytes) {
    if (![bytes isKindOfClass:[NSData class]] || bytes.length == 0 ||
        bytes.length > PXOptionalRestoreMaximumPathBytes) {
        return NO;
    }
    return memchr(bytes.bytes, 0, bytes.length) == NULL;
}

static BOOL PXOptionalRestorePathIsValid(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || path.length == 0 ||
        ![path hasPrefix:@"/"] || [path isEqualToString:@"/"] ||
        [path hasSuffix:@"/"] || [path containsString:@"//"] ||
        [path rangeOfString:@"\0"].location != NSNotFound) {
        return NO;
    }
    NSData *bytes = [path dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if (!PXOptionalRestoreCanonicalBytesAreValid(bytes)) {
        return NO;
    }
    NSArray<NSString *> *components = [path componentsSeparatedByString:@"/"];
    for (NSUInteger index = 1; index < components.count; index++) {
        NSString *component = components[index];
        if (component.length == 0 || [component isEqualToString:@"."] ||
            [component isEqualToString:@".."]) {
            return NO;
        }
        NSData *componentBytes =
            [component dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
        if (!componentBytes || componentBytes.length == 0 ||
            componentBytes.length > PXOptionalRestoreMaximumComponentBytes ||
            memchr(componentBytes.bytes, 0, componentBytes.length) != NULL) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXOptionalRestoreLowercaseSHA256IsValid(NSString *digest) {
    if (![digest isKindOfClass:[NSString class]] || digest.length != 64) {
        return NO;
    }
    for (NSUInteger index = 0; index < digest.length; index++) {
        unichar value = [digest characterAtIndex:index];
        if (!((value >= '0' && value <= '9') || (value >= 'a' && value <= 'f'))) {
            return NO;
        }
    }
    return YES;
}

@interface PXOptionalRestoreTransactionItem ()
- (instancetype)initPrivateWithKind:(PXOptionalRestoreTransactionItemKind)kind
                    destinationPath:(NSString *)destinationPath
             validatedDirectoryStage:(nullable PXValidatedMainDataStage *)directoryStage
                  validatedFileStage:(nullable PXValidatedOptionalFileStage *)fileStage;
@end

@implementation PXOptionalRestoreTransactionItem

+ (instancetype)itemWithKind:(PXOptionalRestoreTransactionItemKind)kind
              destinationPath:(NSString *)destinationPath
       validatedDirectoryStage:(PXValidatedMainDataStage *)directoryStage
            validatedFileStage:(PXValidatedOptionalFileStage *)fileStage
                         error:(NSError **)error {
    if (error) *error = nil;
    BOOL directoryKind = kind == PXOptionalRestoreTransactionItemKindDirectoryContents ||
                         kind == PXOptionalRestoreTransactionItemKindDirectoryObject;
    BOOL fileKind = kind == PXOptionalRestoreTransactionItemKindFileObject;
    if (!PXOptionalRestorePathIsValid(destinationPath) ||
        (directoryKind &&
         (![directoryStage isKindOfClass:[PXValidatedMainDataStage class]] || fileStage != nil ||
          directoryStage.dataPath.length == 0 || directoryStage.treeSHA256.length != 64)) ||
        (fileKind &&
         (![fileStage isKindOfClass:[PXValidatedOptionalFileStage class]] || directoryStage != nil ||
          fileStage.filePath.length == 0 ||
          fileStage.byteCount > PXOptionalRestoreMaximumFileBytes ||
          !PXOptionalRestoreLowercaseSHA256IsValid(fileStage.sha256))) ||
        (!directoryKind && !fileKind)) {
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorInvalidInput,
                                           @"$",
                                           @"An optional transaction item is invalid.");
    }
    return [[self alloc] initPrivateWithKind:kind
                             destinationPath:destinationPath
                    validatedDirectoryStage:directoryStage
                         validatedFileStage:fileStage];
}

+ (instancetype)directoryContentsItemWithDestinationPath:(NSString *)destinationPath
                                           validatedStage:(PXValidatedMainDataStage *)validatedStage
                                                    error:(NSError **)error {
    return [self itemWithKind:PXOptionalRestoreTransactionItemKindDirectoryContents
              destinationPath:destinationPath
       validatedDirectoryStage:validatedStage
            validatedFileStage:nil
                         error:error];
}

+ (instancetype)directoryObjectItemWithDestinationPath:(NSString *)destinationPath
                                         validatedStage:(PXValidatedMainDataStage *)validatedStage
                                                  error:(NSError **)error {
    return [self itemWithKind:PXOptionalRestoreTransactionItemKindDirectoryObject
              destinationPath:destinationPath
       validatedDirectoryStage:validatedStage
            validatedFileStage:nil
                         error:error];
}

+ (instancetype)fileObjectItemWithDestinationPath:(NSString *)destinationPath
                                    validatedStage:(PXValidatedOptionalFileStage *)validatedStage
                                             error:(NSError **)error {
    return [self itemWithKind:PXOptionalRestoreTransactionItemKindFileObject
              destinationPath:destinationPath
       validatedDirectoryStage:nil
            validatedFileStage:validatedStage
                         error:error];
}

- (instancetype)initPrivateWithKind:(PXOptionalRestoreTransactionItemKind)kind
                    destinationPath:(NSString *)destinationPath
             validatedDirectoryStage:(PXValidatedMainDataStage *)directoryStage
                  validatedFileStage:(PXValidatedOptionalFileStage *)fileStage {
    self = [super init];
    if (self) {
        _kind = kind;
        _destinationPath = [destinationPath copy];
        _validatedDirectoryStage = directoryStage;
        _validatedFileStage = fileStage;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

@end

static NSString *PXOptionalRestoreLowercaseHexDigest(
    const unsigned char digest[CC_SHA256_DIGEST_LENGTH]) {
    static const char hex[] = "0123456789abcdef";
    char output[(CC_SHA256_DIGEST_LENGTH * 2) + 1];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
        output[index * 2] = hex[(digest[index] >> 4) & 0x0f];
        output[index * 2 + 1] = hex[digest[index] & 0x0f];
    }
    output[CC_SHA256_DIGEST_LENGTH * 2] = '\0';
    return [NSString stringWithUTF8String:output];
}

static BOOL PXOptionalRestoreStableFileStatsEqual(const struct stat *left,
                                                   const struct stat *right) {
    return left && right && left->st_dev == right->st_dev &&
           left->st_ino == right->st_ino && left->st_mode == right->st_mode &&
           left->st_nlink == right->st_nlink && left->st_size == right->st_size &&
           left->st_mtimespec.tv_sec == right->st_mtimespec.tv_sec &&
           left->st_mtimespec.tv_nsec == right->st_mtimespec.tv_nsec;
}

static void PXOptionalRestoreHashUInt32(CC_SHA256_CTX *context, uint32_t value) {
    unsigned char bytes[4] = {
        (unsigned char)((value >> 24) & 0xff),
        (unsigned char)((value >> 16) & 0xff),
        (unsigned char)((value >> 8) & 0xff),
        (unsigned char)(value & 0xff)
    };
    CC_SHA256_Update(context, bytes, (CC_LONG)sizeof(bytes));
}

static void PXOptionalRestoreHashUInt64(CC_SHA256_CTX *context, uint64_t value) {
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

static void PXOptionalRestoreHashTreeHeader(CC_SHA256_CTX *context,
                                            unsigned char type,
                                            NSData *relativePath,
                                            mode_t mode,
                                            uint64_t size) {
    CC_SHA256_Update(context, &type, 1);
    PXOptionalRestoreHashUInt32(context, (uint32_t)relativePath.length);
    if (relativePath.length > 0) {
        CC_SHA256_Update(context, relativePath.bytes, (CC_LONG)relativePath.length);
    }
    PXOptionalRestoreHashUInt32(context, (uint32_t)(mode & 07777));
    PXOptionalRestoreHashUInt64(context, size);
}

static NSData *PXOptionalRestoreRelativePath(NSData *parent, NSData *name) {
    NSUInteger separator = parent.length > 0 ? 1 : 0;
    if (parent.length > NSUIntegerMax - separator ||
        parent.length + separator > NSUIntegerMax - name.length ||
        parent.length + separator + name.length > PXOptionalRestoreMaximumPathBytes) {
        return nil;
    }
    NSMutableData *result = [NSMutableData dataWithCapacity:parent.length + separator + name.length];
    if (parent.length > 0) {
        [result appendData:parent];
        const unsigned char slash = '/';
        [result appendBytes:&slash length:1];
    }
    [result appendData:name];
    return result;
}

@interface PXOptionalRestoreTreeFrame : NSObject
@property (nonatomic, assign) int descriptor;
@property (nonatomic, copy) NSArray<NSData *> *names;
@property (nonatomic, assign) NSUInteger nextIndex;
@property (nonatomic, copy) NSData *relativePath;
@property (nonatomic, assign) NSUInteger depth;
@property (nonatomic, assign) struct stat retainedStat;
@end

@implementation PXOptionalRestoreTreeFrame
- (instancetype)init {
    self = [super init];
    if (self) _descriptor = -1;
    return self;
}
- (void)dealloc {
    PXOptionalRestoreCloseDescriptor(&_descriptor);
}
@end

static BOOL PXOptionalRestoreVerifierStableDirectoryStatsEqual(const struct stat *before,
                                                                const struct stat *after) {
    return before && after &&
           before->st_dev == after->st_dev &&
           before->st_ino == after->st_ino &&
           before->st_mode == after->st_mode &&
           before->st_mtimespec.tv_sec == after->st_mtimespec.tv_sec &&
           before->st_mtimespec.tv_nsec == after->st_mtimespec.tv_nsec &&
           before->st_ctimespec.tv_sec == after->st_ctimespec.tv_sec &&
           before->st_ctimespec.tv_nsec == after->st_ctimespec.tv_nsec;
}

static BOOL PXOptionalRestoreVerifierStableFileStatsEqual(const struct stat *before,
                                                           const struct stat *after) {
    return before && after &&
           before->st_dev == after->st_dev &&
           before->st_ino == after->st_ino &&
           before->st_mode == after->st_mode &&
           before->st_nlink == after->st_nlink &&
           before->st_size == after->st_size &&
           before->st_mtimespec.tv_sec == after->st_mtimespec.tv_sec &&
           before->st_mtimespec.tv_nsec == after->st_mtimespec.tv_nsec &&
           before->st_ctimespec.tv_sec == after->st_ctimespec.tv_sec &&
           before->st_ctimespec.tv_nsec == after->st_ctimespec.tv_nsec;
}

static BOOL PXOptionalRestoreVerifierNameIsStrictUTF8(NSData *nameData) {
    if (![nameData isKindOfClass:[NSData class]] ||
        nameData.length == 0 ||
        nameData.length > PXOptionalRestoreMaximumComponentBytes) {
        return NO;
    }
    const unsigned char *bytes = nameData.bytes;
    for (NSUInteger index = 0; index < nameData.length; index++) {
        unsigned char value = bytes[index];
        if (value == 0 || value == '/' || value == '\\' ||
            value < 0x20 || value == 0x7f) {
            return NO;
        }
    }
    if (PXOptionalRestoreRawNameEquals(nameData, @".") ||
        PXOptionalRestoreRawNameEquals(nameData, @"..")) {
        return NO;
    }
    NSString *decoded = [[NSString alloc] initWithData:nameData
                                               encoding:NSUTF8StringEncoding];
    if (!decoded) {
        return NO;
    }
    NSData *roundTrip = [decoded dataUsingEncoding:NSUTF8StringEncoding
                               allowLossyConversion:NO];
    return roundTrip && [roundTrip isEqualToData:nameData];
}

static NSArray<NSData *> *PXOptionalRestoreVerifierReadDirectoryNames(
    int descriptor,
    NSUInteger maximumNameCount,
    NSError **error) {
    int enumerationDescriptor = PXOptionalRestoreDuplicateDescriptor(descriptor);
    if (enumerationDescriptor < 0 || lseek(enumerationDescriptor, 0, SEEK_SET) < 0) {
        if (enumerationDescriptor >= 0) {
            close(enumerationDescriptor);
        }
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                           @"$.replacement",
                                           @"The replacement directory could not be inspected safely.");
    }
    DIR *directory = fdopendir(enumerationDescriptor);
    if (!directory) {
        close(enumerationDescriptor);
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                           @"$.replacement",
                                           @"The replacement directory could not be inspected safely.");
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
        size_t length = strlen(name);
        if (length == 0 || length > PXOptionalRestoreMaximumComponentBytes ||
            names.count >= maximumNameCount) {
            closedir(directory);
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorEntryLimitExceeded,
                                               @"$.replacement",
                                               @"The replacement tree exceeds a fixed safety limit.");
        }
        [names addObject:[NSData dataWithBytes:name length:length]];
    }
    if (closedir(directory) != 0 && enumerationError == 0) {
        enumerationError = errno ?: EIO;
    }
    if (enumerationError != 0) {
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                           @"$.replacement",
                                           @"The replacement directory could not be inspected safely.");
    }
    return [names sortedArrayUsingComparator:^NSComparisonResult(NSData *left, NSData *right) {
        return PXOptionalRestoreCompareRawNames(left, right);
    }];
}

static PXOptionalRestoreTreeFrame *PXOptionalRestoreCreateTreeFrame(
    int descriptor,
    NSData *relativePath,
    NSUInteger depth,
    NSUInteger maximumNameCount,
    dev_t rootDevice,
    const struct stat *expectedStat,
    NSError **error) {
    if (descriptor < 0 || !PXOptionalRestoreSetCloseOnExec(descriptor)) {
        if (descriptor >= 0) {
            close(descriptor);
        }
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                           @"$.replacement",
                                           @"The replacement directory could not be inspected safely.");
    }
    struct stat before;
    struct stat after;
    memset(&before, 0, sizeof(before));
    memset(&after, 0, sizeof(after));
    if (fstat(descriptor, &before) != 0) {
        close(descriptor);
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                           @"$.replacement",
                                           @"The replacement directory could not be inspected safely.");
    }
    if (expectedStat &&
        !PXOptionalRestoreVerifierStableDirectoryStatsEqual(expectedStat, &before)) {
        close(descriptor);
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorFilesystemChanged,
                                           @"$.replacement",
                                           @"The replacement tree changed during verification.");
    }
    if (!S_ISDIR(before.st_mode) || before.st_dev != rootDevice ||
        (before.st_mode & (S_ISUID | S_ISGID)) != 0) {
        close(descriptor);
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorReplacementMismatch,
                                           @"$.replacement",
                                           @"The replacement tree does not match the accepted stage.");
    }
    NSArray<NSData *> *names =
        PXOptionalRestoreVerifierReadDirectoryNames(descriptor, maximumNameCount, error);
    if (!names) {
        close(descriptor);
        return nil;
    }
    if (fstat(descriptor, &after) != 0) {
        close(descriptor);
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                           @"$.replacement",
                                           @"The replacement directory could not be inspected safely.");
    }
    if (!PXOptionalRestoreVerifierStableDirectoryStatsEqual(&before, &after)) {
        close(descriptor);
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorFilesystemChanged,
                                           @"$.replacement",
                                           @"The replacement tree changed during verification.");
    }
    PXOptionalRestoreTreeFrame *frame = [[PXOptionalRestoreTreeFrame alloc] init];
    frame.descriptor = descriptor;
    frame.names = names;
    frame.nextIndex = 0;
    frame.relativePath = relativePath;
    frame.depth = depth;
    frame.retainedStat = after;
    return frame;
}

static void PXOptionalRestoreCloseTreeFrames(
    NSMutableArray<PXOptionalRestoreTreeFrame *> *stack) {
    for (PXOptionalRestoreTreeFrame *frame in stack) {
        int descriptor = frame.descriptor;
        frame.descriptor = -1;
        if (descriptor >= 0) {
            close(descriptor);
        }
    }
    [stack removeAllObjects];
}

static BOOL PXOptionalRestoreVerifyDirectoryTree(
    int rootDescriptor,
    PXValidatedMainDataStage *expectedStage,
    NSError **error) {
    if (error) {
        *error = nil;
    }
    if (rootDescriptor < 0 ||
        ![expectedStage isKindOfClass:[PXValidatedMainDataStage class]] ||
        !PXOptionalRestoreLowercaseSHA256IsValid(expectedStage.treeSHA256) ||
        expectedStage.regularFileCount > expectedStage.entryCount ||
        expectedStage.directoryCount > expectedStage.entryCount ||
        expectedStage.regularFileCount > NSUIntegerMax - expectedStage.directoryCount ||
        expectedStage.regularFileCount + expectedStage.directoryCount != expectedStage.entryCount ||
        expectedStage.entryCount > PXOptionalRestoreMaximumAggregateEntries) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorInvalidInput,
                                     @"$.replacement",
                                     @"The replacement verification input is invalid.");
    }

    struct stat rootBefore;
    struct stat traversalRootStat;
    memset(&rootBefore, 0, sizeof(rootBefore));
    memset(&traversalRootStat, 0, sizeof(traversalRootStat));
    if (fstat(rootDescriptor, &rootBefore) != 0) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                     @"$.replacement",
                                     @"The replacement root could not be inspected safely.");
    }
    if (!S_ISDIR(rootBefore.st_mode) ||
        (rootBefore.st_mode & (S_ISUID | S_ISGID)) != 0) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorReplacementMismatch,
                                     @"$.replacement",
                                     @"The replacement tree does not match the accepted stage.");
    }

    int traversalRoot = PXOptionalRestoreDuplicateDescriptor(rootDescriptor);
    if (traversalRoot < 0 || fstat(traversalRoot, &traversalRootStat) != 0) {
        if (traversalRoot >= 0) {
            close(traversalRoot);
        }
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                     @"$.replacement",
                                     @"The replacement root could not be inspected safely.");
    }
    if (!PXOptionalRestoreVerifierStableDirectoryStatsEqual(&rootBefore,
                                                             &traversalRootStat)) {
        close(traversalRoot);
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorFilesystemChanged,
                                     @"$.replacement",
                                     @"The replacement tree changed during verification.");
    }

    PXOptionalRestoreTreeFrame *rootFrame =
        PXOptionalRestoreCreateTreeFrame(traversalRoot,
                                         [NSData data],
                                         0,
                                         PXOptionalRestoreMaximumAggregateEntries,
                                         rootBefore.st_dev,
                                         &rootBefore,
                                         error);
    traversalRoot = -1;
    if (!rootFrame) {
        return NO;
    }

    NSMutableArray<PXOptionalRestoreTreeFrame *> *stack =
        [NSMutableArray arrayWithObject:rootFrame];
    NSUInteger enumeratedEntryCount = rootFrame.names.count;
    NSUInteger entryCount = 0;
    NSUInteger regularFileCount = 0;
    NSUInteger directoryCount = 0;
    unsigned long long regularFileBytes = 0;
    CC_SHA256_CTX digestContext;
    CC_SHA256_Init(&digestContext);
    static const unsigned char domainPrefix[] = "PXMainDataStageTreeV1";
    CC_SHA256_Update(&digestContext, domainPrefix, (CC_LONG)sizeof(domainPrefix));

    while (stack.count > 0) {
        PXOptionalRestoreTreeFrame *frame = stack.lastObject;
        if (frame.nextIndex >= frame.names.count) {
            struct stat finalDirectoryStat;
            memset(&finalDirectoryStat, 0, sizeof(finalDirectoryStat));
            struct stat retainedDirectoryStat = frame.retainedStat;
            if (fstat(frame.descriptor, &finalDirectoryStat) != 0) {
                PXOptionalRestoreCloseTreeFrames(stack);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                             @"$.replacement",
                                             @"The replacement directory could not be inspected safely.");
            }
            if (!PXOptionalRestoreVerifierStableDirectoryStatsEqual(&retainedDirectoryStat,
                                                                     &finalDirectoryStat) ||
                finalDirectoryStat.st_dev != rootBefore.st_dev ||
                (finalDirectoryStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
                PXOptionalRestoreCloseTreeFrames(stack);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorFilesystemChanged,
                                             @"$.replacement",
                                             @"The replacement tree changed during verification.");
            }
            int completedDescriptor = frame.descriptor;
            frame.descriptor = -1;
            [stack removeLastObject];
            if (close(completedDescriptor) != 0) {
                PXOptionalRestoreCloseTreeFrames(stack);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                             @"$.replacement",
                                             @"The replacement directory could not be closed safely.");
            }
            continue;
        }

        NSData *nameData = frame.names[frame.nextIndex++];
        if (nameData.length == 0 ||
            nameData.length > PXOptionalRestoreMaximumComponentBytes) {
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorEntryLimitExceeded,
                                         @"$.replacement",
                                         @"The replacement tree exceeds a fixed safety limit.");
        }
        if (!PXOptionalRestoreVerifierNameIsStrictUTF8(nameData)) {
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorReplacementMismatch,
                                         @"$.replacement",
                                         @"The replacement tree does not match the accepted stage.");
        }
        if (frame.depth >= PXOptionalRestoreMaximumTreeDepth) {
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorEntryLimitExceeded,
                                         @"$.replacement",
                                         @"The replacement tree exceeds a fixed safety limit.");
        }
        NSData *relativePath = PXOptionalRestoreRelativePath(frame.relativePath, nameData);
        if (!relativePath || relativePath.length > UINT32_MAX) {
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorEntryLimitExceeded,
                                         @"$.replacement",
                                         @"The replacement tree exceeds a fixed safety limit.");
        }
        NSUInteger entryDepth = frame.depth + 1;
        if (entryDepth > PXOptionalRestoreMaximumTreeDepth ||
            entryCount >= PXOptionalRestoreMaximumAggregateEntries) {
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorEntryLimitExceeded,
                                         @"$.replacement",
                                         @"The replacement tree exceeds a fixed safety limit.");
        }
        entryCount++;

        if ((entryDepth == 1 && PXOptionalRestoreNameIsContainerMetadata(nameData)) ||
            PXOptionalRestoreRawNameHasPrefix(nameData,
                                              PXOptionalRestoreTransactionPrefix)) {
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorReplacementMismatch,
                                         @"$.replacement",
                                         @"The replacement tree does not match the accepted stage.");
        }

        char *entryName = PXOptionalRestoreCopyTerminatedName(nameData);
        if (!entryName) {
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorEntryLimitExceeded,
                                         @"$.replacement",
                                         @"The replacement tree exceeds a fixed safety limit.");
        }
        struct stat namespaceStat;
        memset(&namespaceStat, 0, sizeof(namespaceStat));
        if (fstatat(frame.descriptor,
                    entryName,
                    &namespaceStat,
                    AT_SYMLINK_NOFOLLOW) != 0) {
            free(entryName);
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                         @"$.replacement",
                                         @"A replacement entry could not be inspected safely.");
        }
        if (namespaceStat.st_dev != rootBefore.st_dev ||
            (namespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
            free(entryName);
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorReplacementMismatch,
                                         @"$.replacement",
                                         @"The replacement tree does not match the accepted stage.");
        }

        if (S_ISDIR(namespaceStat.st_mode)) {
            int childDescriptor = openat(frame.descriptor,
                                         entryName,
                                         O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
            free(entryName);
            if (childDescriptor < 0 ||
                !PXOptionalRestoreSetCloseOnExec(childDescriptor)) {
                if (childDescriptor >= 0) {
                    close(childDescriptor);
                }
                PXOptionalRestoreCloseTreeFrames(stack);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                             @"$.replacement",
                                             @"A replacement directory could not be opened safely.");
            }
            struct stat openedDirectoryStat;
            memset(&openedDirectoryStat, 0, sizeof(openedDirectoryStat));
            if (fstat(childDescriptor, &openedDirectoryStat) != 0) {
                close(childDescriptor);
                PXOptionalRestoreCloseTreeFrames(stack);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                             @"$.replacement",
                                             @"A replacement directory could not be inspected safely.");
            }
            if (!S_ISDIR(openedDirectoryStat.st_mode) ||
                openedDirectoryStat.st_dev != namespaceStat.st_dev ||
                openedDirectoryStat.st_ino != namespaceStat.st_ino ||
                (openedDirectoryStat.st_mode & S_IFMT) !=
                    (namespaceStat.st_mode & S_IFMT)) {
                close(childDescriptor);
                PXOptionalRestoreCloseTreeFrames(stack);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorFilesystemChanged,
                                             @"$.replacement",
                                             @"The replacement tree changed during verification.");
            }
            if (openedDirectoryStat.st_dev != rootBefore.st_dev ||
                (openedDirectoryStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
                close(childDescriptor);
                PXOptionalRestoreCloseTreeFrames(stack);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorReplacementMismatch,
                                             @"$.replacement",
                                             @"The replacement tree does not match the accepted stage.");
            }
            if (directoryCount == NSUIntegerMax) {
                close(childDescriptor);
                PXOptionalRestoreCloseTreeFrames(stack);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorEntryLimitExceeded,
                                             @"$.replacement",
                                             @"The replacement tree exceeds a fixed safety limit.");
            }
            directoryCount++;
            PXOptionalRestoreHashTreeHeader(&digestContext,
                                            'D',
                                            relativePath,
                                            openedDirectoryStat.st_mode,
                                            0);
            if (enumeratedEntryCount > PXOptionalRestoreMaximumAggregateEntries) {
                close(childDescriptor);
                PXOptionalRestoreCloseTreeFrames(stack);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorEntryLimitExceeded,
                                             @"$.replacement",
                                             @"The replacement tree exceeds a fixed safety limit.");
            }
            NSUInteger remainingEntryBudget =
                PXOptionalRestoreMaximumAggregateEntries - enumeratedEntryCount;
            PXOptionalRestoreTreeFrame *childFrame =
                PXOptionalRestoreCreateTreeFrame(childDescriptor,
                                                 relativePath,
                                                 entryDepth,
                                                 remainingEntryBudget,
                                                 rootBefore.st_dev,
                                                 &openedDirectoryStat,
                                                 error);
            childDescriptor = -1;
            if (!childFrame) {
                PXOptionalRestoreCloseTreeFrames(stack);
                return NO;
            }
            if (childFrame.names.count >
                PXOptionalRestoreMaximumAggregateEntries - enumeratedEntryCount) {
                PXOptionalRestoreCloseTreeFrames(stack);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorEntryLimitExceeded,
                                             @"$.replacement",
                                             @"The replacement tree exceeds a fixed safety limit.");
            }
            enumeratedEntryCount += childFrame.names.count;
            [stack addObject:childFrame];
            continue;
        }

        if (!S_ISREG(namespaceStat.st_mode) ||
            namespaceStat.st_nlink != 1 ||
            namespaceStat.st_size < 0) {
            free(entryName);
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorReplacementMismatch,
                                         @"$.replacement",
                                         @"The replacement tree does not match the accepted stage.");
        }

        int fileDescriptor = openat(frame.descriptor,
                                    entryName,
                                    O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
        free(entryName);
        if (fileDescriptor < 0 || !PXOptionalRestoreSetCloseOnExec(fileDescriptor)) {
            if (fileDescriptor >= 0) {
                close(fileDescriptor);
            }
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                         @"$.replacement",
                                         @"A replacement file could not be opened safely.");
        }
        struct stat fileBefore;
        memset(&fileBefore, 0, sizeof(fileBefore));
        if (fstat(fileDescriptor, &fileBefore) != 0) {
            close(fileDescriptor);
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                         @"$.replacement",
                                         @"A replacement file could not be inspected safely.");
        }
        if (!S_ISREG(fileBefore.st_mode) ||
            fileBefore.st_dev != namespaceStat.st_dev ||
            fileBefore.st_ino != namespaceStat.st_ino ||
            (fileBefore.st_mode & S_IFMT) != (namespaceStat.st_mode & S_IFMT)) {
            close(fileDescriptor);
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorFilesystemChanged,
                                         @"$.replacement",
                                         @"The replacement tree changed during verification.");
        }
        if (fileBefore.st_dev != rootBefore.st_dev ||
            fileBefore.st_nlink != 1 ||
            fileBefore.st_size < 0 ||
            (fileBefore.st_mode & (S_ISUID | S_ISGID)) != 0) {
            close(fileDescriptor);
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorReplacementMismatch,
                                         @"$.replacement",
                                         @"The replacement tree does not match the accepted stage.");
        }
        unsigned long long fileSize = (unsigned long long)fileBefore.st_size;
        if (regularFileBytes > ULLONG_MAX - fileSize ||
            regularFileCount == NSUIntegerMax) {
            close(fileDescriptor);
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorEntryLimitExceeded,
                                         @"$.replacement",
                                         @"The replacement tree exceeds a fixed safety limit.");
        }
        regularFileCount++;
        PXOptionalRestoreHashTreeHeader(&digestContext,
                                        'F',
                                        relativePath,
                                        fileBefore.st_mode,
                                        fileSize);
        unsigned char buffer[PXOptionalRestoreStreamBufferSize];
        unsigned long long bytesRead = 0;
        BOOL readFailed = NO;
        for (;;) {
            ssize_t amount = read(fileDescriptor, buffer, sizeof(buffer));
            if (amount < 0 && errno == EINTR) {
                continue;
            }
            if (amount < 0) {
                readFailed = YES;
                break;
            }
            if (amount == 0) {
                break;
            }
            if (bytesRead > ULLONG_MAX - (unsigned long long)amount) {
                close(fileDescriptor);
                PXOptionalRestoreCloseTreeFrames(stack);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorEntryLimitExceeded,
                                             @"$.replacement",
                                             @"The replacement tree exceeds a fixed safety limit.");
            }
            bytesRead += (unsigned long long)amount;
            if (bytesRead > fileSize) {
                close(fileDescriptor);
                PXOptionalRestoreCloseTreeFrames(stack);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorFilesystemChanged,
                                             @"$.replacement",
                                             @"The replacement tree changed during verification.");
            }
            CC_SHA256_Update(&digestContext, buffer, (CC_LONG)amount);
        }
        if (readFailed) {
            close(fileDescriptor);
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                         @"$.replacement",
                                         @"A replacement file could not be read safely.");
        }
        struct stat fileAfter;
        memset(&fileAfter, 0, sizeof(fileAfter));
        if (fstat(fileDescriptor, &fileAfter) != 0) {
            close(fileDescriptor);
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                         @"$.replacement",
                                         @"A replacement file could not be inspected safely.");
        }
        int fileCloseResult = close(fileDescriptor);
        fileDescriptor = -1;
        if (fileCloseResult != 0) {
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                         @"$.replacement",
                                         @"A replacement file could not be closed safely.");
        }
        if (bytesRead != fileSize ||
            !PXOptionalRestoreVerifierStableFileStatsEqual(&fileBefore, &fileAfter)) {
            PXOptionalRestoreCloseTreeFrames(stack);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorFilesystemChanged,
                                         @"$.replacement",
                                         @"The replacement tree changed during verification.");
        }
        regularFileBytes += fileSize;
    }

    struct stat rootAfter;
    memset(&rootAfter, 0, sizeof(rootAfter));
    if (fstat(rootDescriptor, &rootAfter) != 0) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                     @"$.replacement",
                                     @"The replacement root could not be inspected safely.");
    }
    if (!PXOptionalRestoreVerifierStableDirectoryStatsEqual(&rootBefore, &rootAfter) ||
        !S_ISDIR(rootAfter.st_mode) ||
        (rootAfter.st_mode & (S_ISUID | S_ISGID)) != 0) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorFilesystemChanged,
                                     @"$.replacement",
                                     @"The replacement tree changed during verification.");
    }

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &digestContext);
    NSString *treeSHA256 = PXOptionalRestoreLowercaseHexDigest(digest);
    if (entryCount != expectedStage.entryCount ||
        regularFileCount != expectedStage.regularFileCount ||
        directoryCount != expectedStage.directoryCount ||
        regularFileBytes != expectedStage.regularFileBytes ||
        ![treeSHA256 isEqualToString:expectedStage.treeSHA256]) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorReplacementMismatch,
                                     @"$.replacement",
                                     @"The replacement tree does not match the accepted stage.");
    }
    return YES;
}

static BOOL PXOptionalRestoreDigestFileDescriptor(int descriptor,
                                                   unsigned long long maximumBytes,
                                                   unsigned long long *byteCountOut,
                                                   NSString **digestOut) {
    if (lseek(descriptor, 0, SEEK_SET) < 0) return NO;
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    unsigned char buffer[PXOptionalRestoreStreamBufferSize];
    unsigned long long total = 0;
    for (;;) {
        ssize_t amount = read(descriptor, buffer, sizeof(buffer));
        if (amount < 0 && errno == EINTR) continue;
        if (amount < 0) return NO;
        if (amount == 0) break;
        if (total > ULLONG_MAX - (unsigned long long)amount) return NO;
        total += (unsigned long long)amount;
        if (total > maximumBytes) return NO;
        CC_SHA256_Update(&context, buffer, (CC_LONG)amount);
    }
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &context);
    if (byteCountOut) *byteCountOut = total;
    if (digestOut) *digestOut = PXOptionalRestoreLowercaseHexDigest(digest);
    return YES;
}

@interface PXOptionalRestoreAuthority : NSObject
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSData *orderBytes;
@property (nonatomic, assign) struct stat retainedStat;
@property (nonatomic, assign) int descriptor;
@property (nonatomic, assign) int lockDescriptor;
@property (nonatomic, assign) NSUInteger lockOrdinal;
@end

@implementation PXOptionalRestoreAuthority
- (instancetype)init { self = [super init]; if (self) { _descriptor = -1; _lockDescriptor = -1; } return self; }
- (void)dealloc { PXOptionalRestoreCloseDescriptor(&_lockDescriptor); PXOptionalRestoreCloseDescriptor(&_descriptor); }
@end

@interface PXOptionalRestoreParticipant : NSObject
@property (nonatomic, strong) PXOptionalRestoreTransactionItem *item;
@property (nonatomic, strong) PXOptionalRestoreAuthority *authority;
@property (nonatomic, assign) NSUInteger managerOrder;
@property (nonatomic, assign) NSUInteger itemOrdinal;
@property (nonatomic, copy) NSData *destinationBytes;
@property (nonatomic, copy) NSData *destinationNameData;
@property (nonatomic, copy) NSString *authorityPath;
@property (nonatomic, copy) NSString *stagePath;
@property (nonatomic, assign) int stageDescriptor;
@property (nonatomic, assign) struct stat stageStat;
@property (nonatomic, assign) BOOL observedDestinationExists;
@property (nonatomic, assign) BOOL initiallyExisted;
@property (nonatomic, assign) struct stat originalDestinationStat;
@property (nonatomic, copy, nullable) NSData *workspaceNameData;
@property (nonatomic, assign) int workspaceDescriptor;
@property (nonatomic, assign) int originalDescriptor;
@property (nonatomic, assign) int replacementDescriptor;
@property (nonatomic, assign) int newDescriptor;
@property (nonatomic, copy) NSArray<PXOptionalRestoreEntry *> *originalEntries;
@property (nonatomic, copy) NSArray<PXOptionalRestoreEntry *> *stagedEntries;
@property (nonatomic, strong, nullable) PXOptionalRestoreEntry *originalObject;
@property (nonatomic, strong, nullable) PXOptionalRestoreEntry *replacementObject;
@property (nonatomic, assign) unsigned long long fileByteCount;
@property (nonatomic, copy, nullable) NSString *fileSHA256;
@end

@implementation PXOptionalRestoreParticipant
- (instancetype)init {
    self = [super init];
    if (self) {
        _stageDescriptor = -1;
        _workspaceDescriptor = -1;
        _originalDescriptor = -1;
        _replacementDescriptor = -1;
        _newDescriptor = -1;
        _originalEntries = @[];
        _stagedEntries = @[];
    }
    return self;
}
- (void)dealloc {
    PXOptionalRestoreCloseDescriptor(&_newDescriptor);
    PXOptionalRestoreCloseDescriptor(&_replacementDescriptor);
    PXOptionalRestoreCloseDescriptor(&_originalDescriptor);
    PXOptionalRestoreCloseDescriptor(&_workspaceDescriptor);
    PXOptionalRestoreCloseDescriptor(&_stageDescriptor);
}
@end

#pragma mark - Descriptor authority and deterministic order

static BOOL PXOptionalRestorePathMatchesDescriptorType(NSString *path,
                                                        int descriptor,
                                                        mode_t expectedType) {
    if (![path isKindOfClass:[NSString class]] || path.length == 0 || descriptor < 0) return NO;
    struct stat pathStat;
    struct stat descriptorStat;
    memset(&pathStat, 0, sizeof(pathStat));
    memset(&descriptorStat, 0, sizeof(descriptorStat));
    if (lstat(path.fileSystemRepresentation, &pathStat) != 0 ||
        fstat(descriptor, &descriptorStat) != 0) return NO;
    return (pathStat.st_mode & S_IFMT) == expectedType &&
           (descriptorStat.st_mode & S_IFMT) == expectedType &&
           pathStat.st_dev == descriptorStat.st_dev &&
           pathStat.st_ino == descriptorStat.st_ino;
}

static BOOL PXOptionalRestoreDestinationNameState(PXOptionalRestoreParticipant *participant,
                                                   BOOL *existsOut,
                                                   struct stat *statOut) {
    if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents) {
        if (existsOut) *existsOut = YES;
        if (statOut) *statOut = participant.authority.retainedStat;
        return YES;
    }
    return PXOptionalRestoreNameState(participant.authority.descriptor,
                                      participant.destinationNameData,
                                      existsOut,
                                      statOut);
}

static BOOL PXOptionalRestoreDestinationTypeIsAllowed(PXOptionalRestoreParticipant *participant,
                                                       BOOL exists,
                                                       const struct stat *value) {
    if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents) {
        return exists && value && S_ISDIR(value->st_mode);
    }
    if (!exists) return YES;
    if (!value) return NO;
    if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryObject) {
        return S_ISDIR(value->st_mode);
    }
    return S_ISREG(value->st_mode) && value->st_nlink == 1 && value->st_size >= 0;
}

static BOOL PXOptionalRestoreInspectCurrentDestination(PXOptionalRestoreParticipant *participant,
                                                        BOOL updateInitialState,
                                                        NSError **error) {
    BOOL exists = NO;
    struct stat value;
    memset(&value, 0, sizeof(value));
    if (!PXOptionalRestoreDestinationNameState(participant, &exists, &value) ||
        !PXOptionalRestoreDestinationTypeIsAllowed(participant, exists, &value) ||
        (exists && value.st_dev != participant.authority.retainedStat.st_dev)) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorDestinationValidationFailed,
                                     @"$.destination",
                                     @"An optional Restore destination has an unsafe current state.");
    }
    participant.observedDestinationExists = exists;
    if (updateInitialState) {
        participant.initiallyExisted = exists;
        if (exists) participant.originalDestinationStat = value;
        participant.originalObject = nil;
        if (exists && participant.item.kind != PXOptionalRestoreTransactionItemKindDirectoryContents) {
            participant.originalObject =
                [PXOptionalRestoreEntry entryForNameData:participant.destinationNameData
                                               descriptor:participant.authority.descriptor
                                                    error:error
                                                fieldPath:@"$.destination"];
            if (!participant.originalObject) return NO;
        }
    }
    return YES;
}

static BOOL PXOptionalRestoreAuthorityIdentityIsValid(PXOptionalRestoreAuthority *authority,
                                                       BOOL requireLock,
                                                       NSError **error) {
    struct stat authorityNow;
    struct stat lockNow;
    memset(&authorityNow, 0, sizeof(authorityNow));
    memset(&lockNow, 0, sizeof(lockNow));
    struct stat retainedAuthorityStat = authority.retainedStat;
    if (!PXOptionalRestorePathMatchesDescriptor(authority.path, authority.descriptor) ||
        !PXOptionalRestorePathMatchesDescriptor(authority.path, authority.lockDescriptor) ||
        fstat(authority.descriptor, &authorityNow) != 0 ||
        fstat(authority.lockDescriptor, &lockNow) != 0 ||
        !S_ISDIR(authorityNow.st_mode) || !S_ISDIR(lockNow.st_mode) ||
        !PXOptionalRestoreStatIdentityMatches(&retainedAuthorityStat, &authorityNow) ||
        authorityNow.st_dev != lockNow.st_dev || authorityNow.st_ino != lockNow.st_ino) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorFilesystemChanged,
                                     @"$.locks",
                                     @"An optional Restore authority or lock identity changed.");
    }
    if (requireLock && flock(authority.lockDescriptor, LOCK_EX | LOCK_NB) != 0) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorLockFailed,
                                     @"$.locks",
                                     @"An optional Restore authority lock is no longer retained.");
    }
    return YES;
}

static BOOL PXOptionalRestoreStageIdentityIsValid(PXOptionalRestoreParticipant *participant,
                                                   NSError **error) {
    struct stat stageNow;
    memset(&stageNow, 0, sizeof(stageNow));
    mode_t expectedType = participant.item.kind == PXOptionalRestoreTransactionItemKindFileObject
                            ? S_IFREG : S_IFDIR;
    struct stat retainedStageStat = participant.stageStat;
    if (!PXOptionalRestorePathMatchesDescriptorType(participant.stagePath,
                                                     participant.stageDescriptor,
                                                     expectedType) ||
        fstat(participant.stageDescriptor, &stageNow) != 0 ||
        !PXOptionalRestoreStatIdentityMatches(&retainedStageStat, &stageNow) ||
        stageNow.st_dev != participant.authority.retainedStat.st_dev ||
        (expectedType == S_IFREG &&
         (!S_ISREG(stageNow.st_mode) || stageNow.st_nlink != 1 || stageNow.st_size < 0))) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorFilesystemChanged,
                                     @"$.stage",
                                     @"An accepted optional Restore stage identity changed.");
    }
    return YES;
}

static BOOL PXOptionalRestoreParticipantProofIsValid(PXOptionalRestoreParticipant *participant,
                                                       BOOL requireLock,
                                                       BOOL requireInitialState,
                                                       BOOL requireStage,
                                                       NSError **error) {
    if (!PXOptionalRestoreAuthorityIdentityIsValid(participant.authority, requireLock, error)) return NO;
    if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents &&
        ![participant.item.destinationPath isEqualToString:participant.authority.path]) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorDestinationValidationFailed,
                                     @"$.destination",
                                     @"A directory-contents destination authority is inconsistent.");
    }
    BOOL exists = NO;
    struct stat value;
    memset(&value, 0, sizeof(value));
    if (!PXOptionalRestoreDestinationNameState(participant, &exists, &value) ||
        !PXOptionalRestoreDestinationTypeIsAllowed(participant, exists, &value)) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorFilesystemChanged,
                                     @"$.destination",
                                     @"An optional Restore destination state changed.");
    }
    if (requireInitialState) {
        struct stat retainedOriginalStat = participant.originalDestinationStat;
        if (exists != participant.initiallyExisted ||
            (exists && !PXOptionalRestoreStatIdentityMatches(&retainedOriginalStat, &value))) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorFilesystemChanged,
                                         @"$.destination",
                                         @"An optional Restore destination changed before commit.");
        }
    }
    if (requireStage && !PXOptionalRestoreStageIdentityIsValid(participant, error)) return NO;
    return YES;
}

static NSArray<PXOptionalRestoreParticipant *> *PXOptionalRestoreItemLockOrder(
    NSArray<PXOptionalRestoreParticipant *> *participants) {
    return [participants sortedArrayUsingComparator:^NSComparisonResult(
        PXOptionalRestoreParticipant *left,
        PXOptionalRestoreParticipant *right) {
        NSComparisonResult result = PXOptionalRestoreCompareRawNames(left.destinationBytes,
                                                                     right.destinationBytes);
        if (result != NSOrderedSame) return result;
        if (left.managerOrder < right.managerOrder) return NSOrderedAscending;
        if (left.managerOrder > right.managerOrder) return NSOrderedDescending;
        return NSOrderedSame;
    }];
}

static NSArray<PXOptionalRestoreParticipant *> *PXOptionalRestoreManagerOrder(
    NSArray<PXOptionalRestoreParticipant *> *participants) {
    return [participants sortedArrayUsingComparator:^NSComparisonResult(
        PXOptionalRestoreParticipant *left,
        PXOptionalRestoreParticipant *right) {
        if (left.managerOrder < right.managerOrder) return NSOrderedAscending;
        if (left.managerOrder > right.managerOrder) return NSOrderedDescending;
        return NSOrderedSame;
    }];
}

static NSArray<PXOptionalRestoreAuthority *> *PXOptionalRestoreAuthorityLockOrder(
    NSArray<PXOptionalRestoreAuthority *> *authorities) {
    return [authorities sortedArrayUsingComparator:^NSComparisonResult(
        PXOptionalRestoreAuthority *left,
        PXOptionalRestoreAuthority *right) {
        NSComparisonResult result = PXOptionalRestoreCompareRawNames(left.orderBytes,
                                                                     right.orderBytes);
        if (result != NSOrderedSame) return result;
        if (left.retainedStat.st_dev < right.retainedStat.st_dev) return NSOrderedAscending;
        if (left.retainedStat.st_dev > right.retainedStat.st_dev) return NSOrderedDescending;
        if (left.retainedStat.st_ino < right.retainedStat.st_ino) return NSOrderedAscending;
        if (left.retainedStat.st_ino > right.retainedStat.st_ino) return NSOrderedDescending;
        return NSOrderedSame;
    }];
}

static BOOL PXOptionalRestorePathsCollide(NSString *left, NSString *right) {
    if ([left isEqualToString:right]) return YES;
    NSString *leftPrefix = [left stringByAppendingString:@"/"];
    NSString *rightPrefix = [right stringByAppendingString:@"/"];
    return [right hasPrefix:leftPrefix] || [left hasPrefix:rightPrefix];
}

static NSString *PXOptionalRestoreWorkspaceName(NSString *transactionIdentifier,
                                                 NSUInteger ordinal) {
    if (![transactionIdentifier isKindOfClass:[NSString class]] ||
        transactionIdentifier.length != 36 || ordinal >= PXOptionalRestoreMaximumItems) return nil;
    return [NSString stringWithFormat:@"%@%@-%04lu",
            PXOptionalRestoreTransactionPrefix,
            transactionIdentifier,
            (unsigned long)ordinal];
}

static BOOL PXOptionalRestoreParseWorkspaceName(NSData *nameData,
                                                 NSString **transactionIdentifierOut,
                                                 NSUInteger *ordinalOut) {
    if (!PXOptionalRestoreNameIsSafe(nameData) ||
        !PXOptionalRestoreRawNameHasPrefix(nameData, PXOptionalRestoreTransactionPrefix)) return NO;
    NSString *name = [[NSString alloc] initWithData:nameData encoding:NSUTF8StringEncoding];
    NSUInteger prefixLength = PXOptionalRestoreTransactionPrefix.length;
    if (!name || name.length != prefixLength + 36 + 1 + 4 ||
        ![[name substringWithRange:NSMakeRange(prefixLength + 36, 1)] isEqualToString:@"-"]) return NO;
    NSString *identifier = [name substringWithRange:NSMakeRange(prefixLength, 36)];
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:identifier];
    if (!uuid || ![[uuid.UUIDString lowercaseString] isEqualToString:identifier]) return NO;
    NSString *ordinalString = [name substringFromIndex:prefixLength + 37];
    NSUInteger ordinal = 0;
    for (NSUInteger index = 0; index < ordinalString.length; index++) {
        unichar character = [ordinalString characterAtIndex:index];
        if (character < '0' || character > '9') return NO;
        ordinal = ordinal * 10 + (NSUInteger)(character - '0');
    }
    if (ordinal >= PXOptionalRestoreMaximumItems) return NO;
    if (transactionIdentifierOut) *transactionIdentifierOut = identifier;
    if (ordinalOut) *ordinalOut = ordinal;
    return YES;
}

static PXOptionalRestoreParticipant *PXOptionalRestoreLeader(
    NSArray<PXOptionalRestoreParticipant *> *participants) {
    for (PXOptionalRestoreParticipant *participant in participants) {
        if (participant.itemOrdinal == 0) return participant;
    }
    return nil;
}

static NSDictionary<NSNumber *, PXOptionalRestoreParticipant *> *
PXOptionalRestoreParticipantsByOrdinal(NSArray<PXOptionalRestoreParticipant *> *participants) {
    NSMutableDictionary<NSNumber *, PXOptionalRestoreParticipant *> *result =
        [NSMutableDictionary dictionaryWithCapacity:participants.count];
    for (PXOptionalRestoreParticipant *participant in participants) {
        result[@(participant.itemOrdinal)] = participant;
    }
    return result;
}

#pragma mark - Leader journal

static BOOL PXOptionalRestoreReadBoolean(id value, BOOL *booleanOut) {
    if (![value isKindOfClass:[NSNumber class]] ||
        CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID()) return NO;
    if (booleanOut) *booleanOut = [(NSNumber *)value boolValue];
    return YES;
}

static NSArray<NSDictionary<NSString *, id> *> *PXOptionalRestoreJournalEntries(
    NSArray<PXOptionalRestoreEntry *> *entries) {
    NSMutableArray<NSDictionary<NSString *, id> *> *objects =
        [NSMutableArray arrayWithCapacity:entries.count];
    for (PXOptionalRestoreEntry *entry in entries) [objects addObject:[entry journalObject]];
    return [objects copy];
}

static NSDictionary<NSString *, id> *PXOptionalRestoreJournalObjectForParticipant(
    PXOptionalRestoreParticipant *participant) {
    NSDictionary *originalObject = participant.originalObject
        ? [participant.originalObject journalObject] : @{};
    NSDictionary *replacementObject = participant.replacementObject
        ? [participant.replacementObject journalObject] : @{};
    return @{
        @"lockOrdinal": @(participant.itemOrdinal),
        @"managerOrder": @(participant.managerOrder),
        @"kind": @(participant.item.kind),
        @"workspaceName": participant.workspaceNameData ?: [NSData data],
        @"authorityDevice": @((unsigned long long)participant.authority.retainedStat.st_dev),
        @"authorityInode": @((unsigned long long)participant.authority.retainedStat.st_ino),
        @"destinationName": participant.destinationNameData ?: [NSData data],
        @"initiallyExisted": @(participant.initiallyExisted),
        @"originalEntries": PXOptionalRestoreJournalEntries(participant.originalEntries),
        @"replacementEntries": PXOptionalRestoreJournalEntries(participant.stagedEntries),
        @"originalObject": originalObject,
        @"replacementObject": replacementObject,
        @"fileByteCount": @(participant.fileByteCount),
        @"fileSHA256": participant.fileSHA256 ?: @""
    };
}

static BOOL PXOptionalRestoreWriteLeaderJournal(
    NSArray<PXOptionalRestoreParticipant *> *participants,
    NSString *transactionIdentifier,
    NSString *phase,
    NSError **error) {
    PXOptionalRestoreParticipant *leader = PXOptionalRestoreLeader(participants);
    if (!leader || leader.workspaceDescriptor < 0 ||
        !PXOptionalRestorePhaseIsValid(phase) ||
        ![transactionIdentifier isKindOfClass:[NSString class]]) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"The optional transaction leader journal input is invalid.");
    }
    NSArray<PXOptionalRestoreParticipant *> *lockOrder = PXOptionalRestoreItemLockOrder(participants);
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:lockOrder.count];
    for (PXOptionalRestoreParticipant *participant in lockOrder) {
        [items addObject:PXOptionalRestoreJournalObjectForParticipant(participant)];
    }
    NSDictionary *journal = @{
        @"version": @1,
        @"transactionIdentifier": transactionIdentifier,
        @"phase": phase,
        @"itemCount": @(participants.count),
        @"items": items
    };
    NSError *serializationError = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:journal
                                                               format:NSPropertyListBinaryFormat_v1_0
                                                              options:0
                                                                error:&serializationError];
    if (!data || data.length == 0 || data.length > PXOptionalRestoreMaximumJournalBytes) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"The optional transaction journal could not be serialized within bounds.");
    }
    NSData *temporaryNameData = PXOptionalRestoreNameData(PXOptionalRestoreJournalTemporaryName);
    NSData *journalNameData = PXOptionalRestoreNameData(PXOptionalRestoreJournalName);
    char *temporaryName = PXOptionalRestoreCopyTerminatedName(temporaryNameData);
    char *journalName = PXOptionalRestoreCopyTerminatedName(journalNameData);
    if (!temporaryName || !journalName) {
        free(temporaryName); free(journalName);
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"The optional transaction journal name is invalid.");
    }
    BOOL temporaryExists = NO;
    struct stat temporaryStat;
    memset(&temporaryStat, 0, sizeof(temporaryStat));
    if (!PXOptionalRestoreNameState(leader.workspaceDescriptor,
                                    temporaryNameData,
                                    &temporaryExists,
                                    &temporaryStat) ||
        (temporaryExists &&
         (!S_ISREG(temporaryStat.st_mode) || temporaryStat.st_nlink != 1 ||
          (temporaryStat.st_mode & 0777) != 0600 ||
          temporaryStat.st_dev != leader.authority.retainedStat.st_dev ||
          temporaryStat.st_size < 0 ||
          (unsigned long long)temporaryStat.st_size > PXOptionalRestoreMaximumJournalBytes))) {
        free(temporaryName); free(journalName);
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"A stale optional transaction temporary journal is unsafe.");
    }
    if (temporaryExists && unlinkat(leader.workspaceDescriptor, temporaryName, 0) != 0) {
        free(temporaryName); free(journalName);
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"A stale optional transaction temporary journal could not be removed.");
    }
    int descriptor = openat(leader.workspaceDescriptor,
                            temporaryName,
                            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
                            0600);
    struct stat fileStat;
    memset(&fileStat, 0, sizeof(fileStat));
    BOOL written = descriptor >= 0 &&
                   fchmod(descriptor, 0600) == 0 &&
                   fstat(descriptor, &fileStat) == 0 &&
                   S_ISREG(fileStat.st_mode) && fileStat.st_nlink == 1 &&
                   (fileStat.st_mode & 0777) == 0600 &&
                   fileStat.st_dev == leader.authority.retainedStat.st_dev &&
                   PXOptionalRestoreWriteAll(descriptor, data.bytes, data.length) &&
                   PXOptionalRestoreSyncDescriptor(descriptor);
    int closeResult = descriptor >= 0 ? close(descriptor) : -1;
    if (!written || closeResult != 0 ||
        renameat(leader.workspaceDescriptor, temporaryName,
                 leader.workspaceDescriptor, journalName) != 0 ||
        !PXOptionalRestoreSyncDirectory(leader.workspaceDescriptor)) {
        if (descriptor < 0 || closeResult == 0) unlinkat(leader.workspaceDescriptor, temporaryName, 0);
        free(temporaryName); free(journalName);
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"The optional transaction journal could not be published durably.");
    }
    free(temporaryName); free(journalName);
    return YES;
}

static NSDictionary<NSString *, id> *PXOptionalRestoreReadLeaderJournal(
    NSArray<PXOptionalRestoreParticipant *> *participants,
    NSString *expectedTransactionIdentifier,
    NSError **error) {
    PXOptionalRestoreParticipant *leader = PXOptionalRestoreLeader(participants);
    NSData *journalNameData = PXOptionalRestoreNameData(PXOptionalRestoreJournalName);
    char *journalName = PXOptionalRestoreCopyTerminatedName(journalNameData);
    if (!leader || leader.workspaceDescriptor < 0 || !journalName) {
        free(journalName);
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorJournalInvalid,
                                           @"$.journal",
                                           @"The optional transaction leader journal is unavailable.");
    }
    int descriptor = openat(leader.workspaceDescriptor,
                            journalName,
                            O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    free(journalName);
    if (descriptor < 0) {
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorJournalInvalid,
                                           @"$.journal",
                                           @"The optional transaction leader journal is missing.");
    }
    struct stat fileStat;
    memset(&fileStat, 0, sizeof(fileStat));
    if (fstat(descriptor, &fileStat) != 0 || !S_ISREG(fileStat.st_mode) ||
        fileStat.st_nlink != 1 || (fileStat.st_mode & 0777) != 0600 ||
        fileStat.st_dev != leader.authority.retainedStat.st_dev ||
        fileStat.st_size <= 0 ||
        (unsigned long long)fileStat.st_size > PXOptionalRestoreMaximumJournalBytes) {
        close(descriptor);
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorJournalInvalid,
                                           @"$.journal",
                                           @"The optional transaction journal metadata is invalid.");
    }
    NSData *data = PXOptionalRestoreReadAll(descriptor,
                                            (size_t)fileStat.st_size,
                                            error,
                                            @"$.journal");
    int closeResult = close(descriptor);
    if (!data || closeResult != 0) {
        if (data && error && !*error) {
            PXOptionalRestoreFail(error,
                                  PXOptionalRestoreTransactionErrorJournalInvalid,
                                  @"$.journal",
                                  @"The optional transaction journal could not be closed safely.");
        }
        return nil;
    }
    NSError *parseError = nil;
    id object = [NSPropertyListSerialization propertyListWithData:data
                                                          options:NSPropertyListImmutable
                                                           format:NULL
                                                            error:&parseError];
    if (![object isKindOfClass:[NSDictionary class]]) {
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorJournalInvalid,
                                           @"$.journal",
                                           @"The optional transaction journal could not be parsed.");
    }
    NSDictionary *journal = object;
    unsigned long long version = 0;
    unsigned long long itemCount = 0;
    NSString *identifier = journal[@"transactionIdentifier"];
    NSString *phase = journal[@"phase"];
    NSArray *records = journal[@"items"];
    if (!PXOptionalRestoreReadUnsignedIntegralNumber(journal[@"version"], &version) ||
        version != 1 || ![identifier isKindOfClass:[NSString class]] ||
        ![identifier isEqualToString:expectedTransactionIdentifier] ||
        ![phase isKindOfClass:[NSString class]] || !PXOptionalRestorePhaseIsValid(phase) ||
        !PXOptionalRestoreReadUnsignedIntegralNumber(journal[@"itemCount"], &itemCount) ||
        itemCount != participants.count || ![records isKindOfClass:[NSArray class]] ||
        records.count != participants.count) {
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorJournalInvalid,
                                           @"$.journal",
                                           @"The optional transaction journal identity is invalid.");
    }
    NSDictionary<NSNumber *, PXOptionalRestoreParticipant *> *byOrdinal =
        PXOptionalRestoreParticipantsByOrdinal(participants);
    NSMutableSet<NSNumber *> *seenOrdinals = [NSMutableSet set];
    NSMutableSet<NSNumber *> *seenManagerOrders = [NSMutableSet set];
    NSUInteger aggregateEntries = 0;
    for (NSUInteger recordIndex = 0; recordIndex < records.count; recordIndex++) {
        id recordObject = records[recordIndex];
        if (![recordObject isKindOfClass:[NSDictionary class]]) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorJournalInvalid,
                                               @"$.journal.items",
                                               @"An optional transaction journal item is invalid.");
        }
        NSDictionary *record = recordObject;
        unsigned long long ordinalValue = 0;
        unsigned long long managerValue = 0;
        unsigned long long kindValue = 0;
        unsigned long long deviceValue = 0;
        unsigned long long inodeValue = 0;
        unsigned long long byteCountValue = 0;
        BOOL initiallyExisted = NO;
        NSData *workspaceName = record[@"workspaceName"];
        NSData *destinationName = record[@"destinationName"];
        if (!PXOptionalRestoreReadUnsignedIntegralNumber(record[@"lockOrdinal"], &ordinalValue) ||
            !PXOptionalRestoreReadUnsignedIntegralNumber(record[@"managerOrder"], &managerValue) ||
            !PXOptionalRestoreReadUnsignedIntegralNumber(record[@"kind"], &kindValue) ||
            !PXOptionalRestoreReadUnsignedIntegralNumber(record[@"authorityDevice"], &deviceValue) ||
            !PXOptionalRestoreReadUnsignedIntegralNumber(record[@"authorityInode"], &inodeValue) ||
            !PXOptionalRestoreReadUnsignedIntegralNumber(record[@"fileByteCount"], &byteCountValue) ||
            !PXOptionalRestoreReadBoolean(record[@"initiallyExisted"], &initiallyExisted) ||
            ordinalValue >= participants.count || managerValue >= participants.count ||
            kindValue < PXOptionalRestoreTransactionItemKindDirectoryContents ||
            kindValue > PXOptionalRestoreTransactionItemKindFileObject ||
            !PXOptionalRestoreNameIsSafe(workspaceName) ||
            !PXOptionalRestoreNameIsSafe(destinationName)) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorJournalInvalid,
                                               @"$.journal.items",
                                               @"An optional transaction journal item identity is invalid.");
        }
        NSNumber *ordinalKey = @((NSUInteger)ordinalValue);
        NSNumber *managerKey = @((NSUInteger)managerValue);
        if (recordIndex != (NSUInteger)ordinalValue ||
            [seenOrdinals containsObject:ordinalKey] ||
            [seenManagerOrders containsObject:managerKey]) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorJournalInvalid,
                                               @"$.journal.items",
                                               @"The optional transaction journal item order is invalid.");
        }
        PXOptionalRestoreParticipant *participant = byOrdinal[ordinalKey];
        NSString *workspaceIdentifier = nil;
        NSUInteger workspaceOrdinal = NSNotFound;
        if (!participant || participant.managerOrder != (NSUInteger)managerValue ||
            participant.item.kind != (PXOptionalRestoreTransactionItemKind)kindValue ||
            deviceValue != (unsigned long long)participant.authority.retainedStat.st_dev ||
            inodeValue != (unsigned long long)participant.authority.retainedStat.st_ino ||
            ![destinationName isEqualToData:participant.destinationNameData] ||
            ![workspaceName isEqualToData:participant.workspaceNameData] ||
            !PXOptionalRestoreParseWorkspaceName(workspaceName,
                                                 &workspaceIdentifier,
                                                 &workspaceOrdinal) ||
            ![workspaceIdentifier isEqualToString:expectedTransactionIdentifier] ||
            workspaceOrdinal != participant.itemOrdinal ||
            (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents &&
             !initiallyExisted)) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorInconsistentBatch,
                                               @"$.recovery",
                                               @"A stale optional transaction does not match the current item set.");
        }
        NSArray<PXOptionalRestoreEntry *> *originalEntries =
            PXOptionalRestoreParseJournalEntries(record[@"originalEntries"],
                                                  error,
                                                  @"$.journal.originalEntries");
        NSArray<PXOptionalRestoreEntry *> *replacementEntries =
            PXOptionalRestoreParseJournalEntries(record[@"replacementEntries"],
                                                  error,
                                                  @"$.journal.replacementEntries");
        if (!originalEntries || !replacementEntries ||
            originalEntries.count > PXOptionalRestoreMaximumAggregateEntries - aggregateEntries) return nil;
        aggregateEntries += originalEntries.count;
        if (replacementEntries.count > PXOptionalRestoreMaximumAggregateEntries - aggregateEntries) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorEntryLimitExceeded,
                                               @"$.journal",
                                               @"The optional transaction aggregate entry limit was exceeded.");
        }
        aggregateEntries += replacementEntries.count;
        NSDictionary *originalObjectValue = record[@"originalObject"];
        NSDictionary *replacementObjectValue = record[@"replacementObject"];
        PXOptionalRestoreEntry *originalObject = nil;
        PXOptionalRestoreEntry *replacementObject = nil;
        if (![originalObjectValue isKindOfClass:[NSDictionary class]] ||
            ![replacementObjectValue isKindOfClass:[NSDictionary class]]) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorJournalInvalid,
                                               @"$.journal.items",
                                               @"An optional transaction object record is invalid.");
        }
        if (originalObjectValue.count > 0) {
            originalObject = [PXOptionalRestoreEntry entryFromJournalObject:originalObjectValue
                                                                       error:error
                                                                   fieldPath:@"$.journal.originalObject"];
            if (!originalObject) return nil;
        }
        if (replacementObjectValue.count > 0) {
            replacementObject = [PXOptionalRestoreEntry entryFromJournalObject:replacementObjectValue
                                                                          error:error
                                                                      fieldPath:@"$.journal.replacementObject"];
            if (!replacementObject) return nil;
        }
        NSString *fileSHA = record[@"fileSHA256"];
        if (![fileSHA isKindOfClass:[NSString class]] ||
            (participant.item.kind == PXOptionalRestoreTransactionItemKindFileObject &&
             (byteCountValue > PXOptionalRestoreMaximumFileBytes ||
              !PXOptionalRestoreLowercaseSHA256IsValid(fileSHA))) ||
            (participant.item.kind != PXOptionalRestoreTransactionItemKindFileObject &&
             (byteCountValue != 0 || fileSHA.length != 0)) ||
            (initiallyExisted && participant.item.kind != PXOptionalRestoreTransactionItemKindDirectoryContents &&
             !originalObject) ||
            (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents &&
             (originalObject || replacementObject))) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorJournalInvalid,
                                               @"$.journal.items",
                                               @"An optional transaction journal payload is inconsistent.");
        }
        participant.initiallyExisted = initiallyExisted;
        participant.originalEntries = originalEntries;
        participant.stagedEntries = replacementEntries;
        participant.originalObject = originalObject;
        participant.replacementObject = replacementObject;
        participant.fileByteCount = byteCountValue;
        participant.fileSHA256 = fileSHA.length ? fileSHA : nil;
        [seenOrdinals addObject:ordinalKey];
        [seenManagerOrders addObject:managerKey];
    }
    if (seenOrdinals.count != participants.count || seenManagerOrders.count != participants.count) {
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorInconsistentBatch,
                                           @"$.recovery",
                                           @"The stale optional transaction item set is incomplete.");
    }
    return @{ @"phase": phase };
}

#pragma mark - Workspace and replacement preparation

static void PXOptionalRestoreCloseWorkspaceDescriptors(PXOptionalRestoreParticipant *participant) {
    int value = participant.newDescriptor;
    PXOptionalRestoreCloseDescriptor(&value);
    participant.newDescriptor = value;
    value = participant.replacementDescriptor;
    PXOptionalRestoreCloseDescriptor(&value);
    participant.replacementDescriptor = value;
    value = participant.originalDescriptor;
    PXOptionalRestoreCloseDescriptor(&value);
    participant.originalDescriptor = value;
    value = participant.workspaceDescriptor;
    PXOptionalRestoreCloseDescriptor(&value);
    participant.workspaceDescriptor = value;
}

static int PXOptionalRestoreOpenNamedDirectory(int parentDescriptor,
                                               NSString *name,
                                               BOOL *existsOut) {
    return PXOptionalRestoreOpenDirectoryAt(parentDescriptor, name, existsOut);
}

static BOOL PXOptionalRestoreOpenWorkspace(PXOptionalRestoreParticipant *participant,
                                            BOOL requireWorkspace,
                                            NSError **error) {
    PXOptionalRestoreCloseWorkspaceDescriptors(participant);
    if (!participant.workspaceNameData) {
        return requireWorkspace
            ? PXOptionalRestoreFail(error,
                                    PXOptionalRestoreTransactionErrorRecoveryFailed,
                                    @"$.recovery",
                                    @"An optional transaction workspace name is missing.")
            : YES;
    }
    char *workspaceName = PXOptionalRestoreCopyTerminatedName(participant.workspaceNameData);
    if (!workspaceName) return NO;
    int workspaceDescriptor = openat(participant.authority.descriptor,
                                     workspaceName,
                                     O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    int savedError = errno;
    free(workspaceName);
    if (workspaceDescriptor < 0) {
        if (!requireWorkspace && savedError == ENOENT) return YES;
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorRecoveryFailed,
                                     @"$.recovery",
                                     @"An optional transaction workspace could not be opened.");
    }
    struct stat workspaceStat;
    memset(&workspaceStat, 0, sizeof(workspaceStat));
    if (fstat(workspaceDescriptor, &workspaceStat) != 0 ||
        !S_ISDIR(workspaceStat.st_mode) || (workspaceStat.st_mode & 0777) != 0700 ||
        workspaceStat.st_dev != participant.authority.retainedStat.st_dev) {
        close(workspaceDescriptor);
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorRecoveryFailed,
                                     @"$.recovery",
                                     @"An optional transaction workspace identity is unsafe.");
    }
    participant.workspaceDescriptor = workspaceDescriptor;
    if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents) {
        BOOL originalExists = NO;
        BOOL newExists = NO;
        int original = PXOptionalRestoreOpenNamedDirectory(workspaceDescriptor,
                                                            PXOptionalRestoreOriginalName,
                                                            &originalExists);
        int newDescriptor = PXOptionalRestoreOpenNamedDirectory(workspaceDescriptor,
                                                                 PXOptionalRestoreNewName,
                                                                 &newExists);
        if (original < 0 || newDescriptor < 0 || !originalExists || !newExists) {
            if (original >= 0) close(original);
            if (newDescriptor >= 0) close(newDescriptor);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorRecoveryFailed,
                                         @"$.recovery",
                                         @"An optional directory-contents recovery workspace is incomplete.");
        }
        participant.originalDescriptor = original;
        participant.newDescriptor = newDescriptor;
    } else if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryObject) {
        for (NSString *name in @[PXOptionalRestoreOriginalName,
                                 PXOptionalRestoreReplacementName,
                                 PXOptionalRestoreNewName]) {
            BOOL exists = NO;
            int descriptor = PXOptionalRestoreOpenNamedDirectory(workspaceDescriptor, name, &exists);
            if (descriptor < 0 && errno != ENOENT) {
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorRecoveryFailed,
                                             @"$.recovery",
                                             @"An optional directory-object workspace entry is unsafe.");
            }
            if (!exists) continue;
            struct stat value;
            memset(&value, 0, sizeof(value));
            if (fstat(descriptor, &value) != 0 || !S_ISDIR(value.st_mode) ||
                value.st_dev != participant.authority.retainedStat.st_dev) {
                close(descriptor);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorRecoveryFailed,
                                             @"$.recovery",
                                             @"An optional directory-object workspace entry changed.");
            }
            if ([name isEqualToString:PXOptionalRestoreOriginalName]) participant.originalDescriptor = descriptor;
            else if ([name isEqualToString:PXOptionalRestoreReplacementName]) participant.replacementDescriptor = descriptor;
            else participant.newDescriptor = descriptor;
        }
    }
    return YES;
}

static BOOL PXOptionalRestoreCreateWorkspace(PXOptionalRestoreParticipant *participant,
                                              NSString *transactionIdentifier,
                                              NSError **error) {
    NSString *workspaceName = PXOptionalRestoreWorkspaceName(transactionIdentifier,
                                                              participant.itemOrdinal);
    NSData *workspaceNameData = PXOptionalRestoreNameData(workspaceName);
    char *rawWorkspaceName = PXOptionalRestoreCopyTerminatedName(workspaceNameData);
    if (!workspaceName || !workspaceNameData || !rawWorkspaceName) {
        free(rawWorkspaceName);
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorWorkspaceCreationFailed,
                                     @"$.workspace",
                                     @"An optional transaction workspace name is invalid.");
    }
    if (mkdirat(participant.authority.descriptor, rawWorkspaceName, 0700) != 0) {
        free(rawWorkspaceName);
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorWorkspaceCreationFailed,
                                     @"$.workspace",
                                     @"An optional transaction workspace could not be created.");
    }
    int workspaceDescriptor = openat(participant.authority.descriptor,
                                     rawWorkspaceName,
                                     O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (workspaceDescriptor < 0) {
        unlinkat(participant.authority.descriptor, rawWorkspaceName, AT_REMOVEDIR);
        PXOptionalRestoreSyncDirectory(participant.authority.descriptor);
        free(rawWorkspaceName);
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorWorkspaceCreationFailed,
                                     @"$.workspace",
                                     @"An optional transaction workspace could not be opened.");
    }
    free(rawWorkspaceName);
    participant.workspaceNameData = workspaceNameData;
    participant.workspaceDescriptor = workspaceDescriptor;
    struct stat workspaceStat;
    memset(&workspaceStat, 0, sizeof(workspaceStat));
    if (fchmod(workspaceDescriptor, 0700) != 0 ||
        fstat(workspaceDescriptor, &workspaceStat) != 0 ||
        !S_ISDIR(workspaceStat.st_mode) || (workspaceStat.st_mode & 0777) != 0700 ||
        workspaceStat.st_dev != participant.authority.retainedStat.st_dev) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorWorkspaceCreationFailed,
                                     @"$.workspace",
                                     @"An optional transaction workspace identity is invalid.");
    }
    if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents) {
        for (NSString *name in @[PXOptionalRestoreOriginalName, PXOptionalRestoreNewName]) {
            NSData *nameData = PXOptionalRestoreNameData(name);
            char *rawName = PXOptionalRestoreCopyTerminatedName(nameData);
            if (!rawName || mkdirat(workspaceDescriptor, rawName, 0700) != 0) {
                free(rawName);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorWorkspaceCreationFailed,
                                             @"$.workspace",
                                             @"An optional transaction recovery directory could not be created.");
            }
            int descriptor = openat(workspaceDescriptor,
                                    rawName,
                                    O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
            free(rawName);
            struct stat value;
            memset(&value, 0, sizeof(value));
            if (descriptor < 0 || fchmod(descriptor, 0700) != 0 ||
                fstat(descriptor, &value) != 0 || !S_ISDIR(value.st_mode) ||
                (value.st_mode & 0777) != 0700 ||
                value.st_dev != participant.authority.retainedStat.st_dev) {
                if (descriptor >= 0) close(descriptor);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorWorkspaceCreationFailed,
                                             @"$.workspace",
                                             @"An optional transaction recovery directory is invalid.");
            }
            if ([name isEqualToString:PXOptionalRestoreOriginalName]) participant.originalDescriptor = descriptor;
            else participant.newDescriptor = descriptor;
        }
    } else if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryObject) {
        NSData *nameData = PXOptionalRestoreNameData(PXOptionalRestoreReplacementName);
        char *rawName = PXOptionalRestoreCopyTerminatedName(nameData);
        if (!rawName || mkdirat(workspaceDescriptor, rawName, 0700) != 0) {
            free(rawName);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorWorkspaceCreationFailed,
                                         @"$.workspace",
                                         @"An optional replacement directory could not be created.");
        }
        int descriptor = openat(workspaceDescriptor,
                                rawName,
                                O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        free(rawName);
        struct stat value;
        memset(&value, 0, sizeof(value));
        if (descriptor < 0 || fchmod(descriptor, 0700) != 0 ||
            fstat(descriptor, &value) != 0 || !S_ISDIR(value.st_mode) ||
            (value.st_mode & 0777) != 0700 ||
            value.st_dev != participant.authority.retainedStat.st_dev) {
            if (descriptor >= 0) close(descriptor);
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorWorkspaceCreationFailed,
                                         @"$.workspace",
                                         @"An optional replacement directory identity is invalid.");
        }
        participant.replacementDescriptor = descriptor;
    }
    if (!PXOptionalRestoreSyncDirectory(workspaceDescriptor) ||
        !PXOptionalRestoreSyncDirectory(participant.authority.descriptor)) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorWorkspaceCreationFailed,
                                     @"$.workspace",
                                     @"An optional transaction workspace could not be synchronized.");
    }
    return YES;
}

static BOOL PXOptionalRestoreMoveEntryList(NSArray<PXOptionalRestoreEntry *> *entries,
                                           int sourceDescriptor,
                                           int destinationDescriptor,
                                           PXOptionalRestoreTransactionErrorCode code,
                                           NSString *fieldPath,
                                           NSString *description,
                                           NSError **error) {
    for (PXOptionalRestoreEntry *entry in entries) {
        if (!PXOptionalRestoreMoveEntry(entry,
                                        sourceDescriptor,
                                        destinationDescriptor,
                                        error,
                                        code,
                                        fieldPath,
                                        description)) return NO;
    }
    return YES;
}

static BOOL PXOptionalRestorePrepareDirectoryReplacement(PXOptionalRestoreParticipant *participant,
                                                          NSError **error) {
    if (!PXOptionalRestoreRequireExactEntries(participant.stageDescriptor,
                                               participant.stagedEntries,
                                               YES, YES, NO, NO,
                                               PXOptionalRestoreTransactionErrorReplacementMismatch,
                                               @"$.replacement",
                                               @"The accepted directory stage changed before replacement preparation.",
                                               error) ||
        !PXOptionalRestoreMoveEntryList(participant.stagedEntries,
                                        participant.stageDescriptor,
                                        participant.replacementDescriptor,
                                        PXOptionalRestoreTransactionErrorReplacementPreparationFailed,
                                        @"$.replacement",
                                        @"A staged directory entry could not be moved into replacement.",
                                        error) ||
        !PXOptionalRestoreRequireExactEntries(participant.stageDescriptor,
                                               @[], NO, NO, NO, NO,
                                               PXOptionalRestoreTransactionErrorReplacementMismatch,
                                               @"$.replacement",
                                               @"A directory stage is not empty after replacement preparation.",
                                               error) ||
        !PXOptionalRestoreRequireExactEntries(participant.replacementDescriptor,
                                               participant.stagedEntries,
                                               YES, YES, NO, NO,
                                               PXOptionalRestoreTransactionErrorReplacementMismatch,
                                               @"$.replacement",
                                               @"A replacement directory namespace is inconsistent.",
                                               error) ||
        !PXOptionalRestoreVerifyDirectoryTree(participant.replacementDescriptor,
                                              participant.item.validatedDirectoryStage,
                                              error) ||
        !PXOptionalRestoreSyncDirectory(participant.stageDescriptor) ||
        !PXOptionalRestoreSyncDirectory(participant.replacementDescriptor) ||
        !PXOptionalRestoreSyncDirectory(participant.workspaceDescriptor)) {
        if (error && !*error) {
            PXOptionalRestoreFail(error,
                                  PXOptionalRestoreTransactionErrorReplacementPreparationFailed,
                                  @"$.replacement",
                                  @"A replacement directory could not be synchronized.");
        }
        return NO;
    }
    participant.replacementObject =
        [PXOptionalRestoreEntry entryForNameData:PXOptionalRestoreNameData(PXOptionalRestoreReplacementName)
                                       descriptor:participant.workspaceDescriptor
                                            error:error
                                        fieldPath:@"$.replacement"];
    return participant.replacementObject != nil;
}

static BOOL PXOptionalRestoreCopyFileReplacement(PXOptionalRestoreParticipant *participant,
                                                  NSError **error) {
    NSData *replacementNameData = PXOptionalRestoreNameData(PXOptionalRestoreReplacementName);
    char *replacementName = PXOptionalRestoreCopyTerminatedName(replacementNameData);
    if (!replacementName) return NO;
    int descriptor = openat(participant.workspaceDescriptor,
                            replacementName,
                            O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
                            0600);
    free(replacementName);
    struct stat sourceBefore;
    struct stat replacementBefore;
    memset(&sourceBefore, 0, sizeof(sourceBefore));
    memset(&replacementBefore, 0, sizeof(replacementBefore));
    if (descriptor < 0 || fchmod(descriptor, 0600) != 0 ||
        fstat(participant.stageDescriptor, &sourceBefore) != 0 ||
        fstat(descriptor, &replacementBefore) != 0 ||
        !S_ISREG(sourceBefore.st_mode) || sourceBefore.st_nlink != 1 || sourceBefore.st_size < 0 ||
        !S_ISREG(replacementBefore.st_mode) || replacementBefore.st_nlink != 1 ||
        (replacementBefore.st_mode & 0777) != 0600 ||
        replacementBefore.st_dev != participant.authority.retainedStat.st_dev ||
        (unsigned long long)sourceBefore.st_size != participant.item.validatedFileStage.byteCount ||
        participant.item.validatedFileStage.byteCount > PXOptionalRestoreMaximumFileBytes ||
        lseek(participant.stageDescriptor, 0, SEEK_SET) < 0) {
        if (descriptor >= 0) close(descriptor);
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorReplacementPreparationFailed,
                                     @"$.replacement",
                                     @"A file replacement could not be prepared safely.");
    }
    CC_SHA256_CTX sourceDigest;
    CC_SHA256_Init(&sourceDigest);
    unsigned char buffer[PXOptionalRestoreStreamBufferSize];
    unsigned long long total = 0;
    BOOL copied = YES;
    for (;;) {
        ssize_t amount = read(participant.stageDescriptor, buffer, sizeof(buffer));
        if (amount < 0 && errno == EINTR) continue;
        if (amount < 0) { copied = NO; break; }
        if (amount == 0) break;
        if (total > ULLONG_MAX - (unsigned long long)amount) { copied = NO; break; }
        total += (unsigned long long)amount;
        if (total > participant.item.validatedFileStage.byteCount) { copied = NO; break; }
        CC_SHA256_Update(&sourceDigest, buffer, (CC_LONG)amount);
        if (!PXOptionalRestoreWriteAll(descriptor, buffer, (size_t)amount)) { copied = NO; break; }
    }
    unsigned char sourceBytes[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(sourceBytes, &sourceDigest);
    NSString *sourceSHA = PXOptionalRestoreLowercaseHexDigest(sourceBytes);
    struct stat sourceAfter;
    struct stat replacementAfterWrite;
    memset(&sourceAfter, 0, sizeof(sourceAfter));
    memset(&replacementAfterWrite, 0, sizeof(replacementAfterWrite));
    copied = copied && total == participant.item.validatedFileStage.byteCount &&
             [sourceSHA isEqualToString:participant.item.validatedFileStage.sha256] &&
             fstat(participant.stageDescriptor, &sourceAfter) == 0 &&
             PXOptionalRestoreStableFileStatsEqual(&sourceBefore, &sourceAfter) &&
             PXOptionalRestoreSyncDescriptor(descriptor) &&
             fstat(descriptor, &replacementAfterWrite) == 0 &&
             replacementAfterWrite.st_size >= 0 &&
             (unsigned long long)replacementAfterWrite.st_size == total;
    unsigned long long rereadBytes = 0;
    NSString *replacementSHA = nil;
    copied = copied && PXOptionalRestoreDigestFileDescriptor(descriptor,
                                                              PXOptionalRestoreMaximumFileBytes,
                                                              &rereadBytes,
                                                              &replacementSHA);
    struct stat replacementAfterRead;
    memset(&replacementAfterRead, 0, sizeof(replacementAfterRead));
    copied = copied && fstat(descriptor, &replacementAfterRead) == 0 &&
             PXOptionalRestoreStableFileStatsEqual(&replacementAfterWrite, &replacementAfterRead) &&
             rereadBytes == participant.item.validatedFileStage.byteCount &&
             [replacementSHA isEqualToString:participant.item.validatedFileStage.sha256];
    int closeResult = close(descriptor);
    if (!copied || closeResult != 0 || !PXOptionalRestoreSyncDirectory(participant.workspaceDescriptor)) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorReplacementMismatch,
                                     @"$.replacement",
                                     @"A file replacement does not match the accepted stage.");
    }
    participant.fileByteCount = rereadBytes;
    participant.fileSHA256 = replacementSHA;
    participant.replacementObject =
        [PXOptionalRestoreEntry entryForNameData:replacementNameData
                                       descriptor:participant.workspaceDescriptor
                                            error:error
                                        fieldPath:@"$.replacement"];
    return participant.replacementObject != nil;
}

static BOOL PXOptionalRestorePrepareReplacement(PXOptionalRestoreParticipant *participant,
                                                 NSError **error) {
    if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents) {
        return PXOptionalRestoreRequireExactEntries(participant.stageDescriptor,
                                                     participant.stagedEntries,
                                                     YES, YES, NO, NO,
                                                     PXOptionalRestoreTransactionErrorReplacementMismatch,
                                                     @"$.replacement",
                                                     @"An accepted directory stage changed before commit.",
                                                     error);
    }
    if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryObject) {
        return PXOptionalRestorePrepareDirectoryReplacement(participant, error);
    }
    return PXOptionalRestoreCopyFileReplacement(participant, error);
}

#pragma mark - Object transitions and cleanup

static BOOL PXOptionalRestoreEntryMatchesNamedState(PXOptionalRestoreEntry *entry,
                                                     int descriptor,
                                                     NSData *nameData,
                                                     BOOL *existsOut) {
    BOOL exists = NO;
    struct stat value;
    memset(&value, 0, sizeof(value));
    if (!PXOptionalRestoreNameState(descriptor, nameData, &exists, &value)) return NO;
    if (existsOut) *existsOut = exists;
    return !exists || (entry && [entry matchesStat:&value]);
}

static BOOL PXOptionalRestoreMoveNamedObject(PXOptionalRestoreEntry *entry,
                                              int sourceDescriptor,
                                              NSData *sourceNameData,
                                              int destinationDescriptor,
                                              NSData *destinationNameData,
                                              PXOptionalRestoreTransactionErrorCode code,
                                              NSString *fieldPath,
                                              NSString *description,
                                              NSError **error) {
    BOOL sourceExists = NO;
    BOOL destinationExists = NO;
    if (!PXOptionalRestoreEntryMatchesNamedState(entry,
                                                 sourceDescriptor,
                                                 sourceNameData,
                                                 &sourceExists) ||
        !sourceExists ||
        !PXOptionalRestoreNameState(destinationDescriptor,
                                    destinationNameData,
                                    &destinationExists,
                                    NULL) || destinationExists) {
        return PXOptionalRestoreFail(error, code, fieldPath, description);
    }
    char *sourceName = PXOptionalRestoreCopyTerminatedName(sourceNameData);
    char *destinationName = PXOptionalRestoreCopyTerminatedName(destinationNameData);
    if (!sourceName || !destinationName ||
        renameat(sourceDescriptor, sourceName,
                 destinationDescriptor, destinationName) != 0) {
        free(sourceName); free(destinationName);
        return PXOptionalRestoreFail(error, code, fieldPath, description);
    }
    free(sourceName); free(destinationName);
    BOOL movedExists = NO;
    if (!PXOptionalRestoreEntryMatchesNamedState(entry,
                                                 destinationDescriptor,
                                                 destinationNameData,
                                                 &movedExists) || !movedExists) {
        return PXOptionalRestoreFail(error, code, fieldPath, description);
    }
    return YES;
}

static BOOL PXOptionalRestoreRequireOriginalState(PXOptionalRestoreParticipant *participant,
                                                   NSError **error) {
    if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents) {
        return PXOptionalRestoreRequireExactEntries(participant.authority.descriptor,
                                                     participant.originalEntries,
                                                     NO, NO, YES, YES,
                                                     PXOptionalRestoreTransactionErrorRollbackFailed,
                                                     @"$.transaction.rollback",
                                                     @"A directory-contents destination does not match its original namespace.",
                                                     error);
    }
    BOOL exists = NO;
    if (participant.initiallyExisted) {
        if (!PXOptionalRestoreEntryMatchesNamedState(participant.originalObject,
                                                     participant.authority.descriptor,
                                                     participant.destinationNameData,
                                                     &exists) || !exists) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorRollbackFailed,
                                         @"$.transaction.rollback",
                                         @"An optional object destination does not match its original identity.");
        }
        return YES;
    }
    if (!PXOptionalRestoreNameState(participant.authority.descriptor,
                                    participant.destinationNameData,
                                    &exists,
                                    NULL) || exists) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorRollbackFailed,
                                     @"$.transaction.rollback",
                                     @"An initially absent optional destination is not absent after rollback.");
    }
    return YES;
}

static BOOL PXOptionalRestoreRequireInstalledState(PXOptionalRestoreParticipant *participant,
                                                    NSError **error) {
    if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents) {
        return PXOptionalRestoreRequireExactEntries(participant.authority.descriptor,
                                                     participant.stagedEntries,
                                                     NO, NO, YES, YES,
                                                     PXOptionalRestoreTransactionErrorCommitFailed,
                                                     @"$.transaction.commit",
                                                     @"A directory-contents destination does not match the staged namespace.",
                                                     error);
    }
    BOOL exists = NO;
    if (!PXOptionalRestoreEntryMatchesNamedState(participant.replacementObject,
                                                 participant.authority.descriptor,
                                                 participant.destinationNameData,
                                                 &exists) || !exists) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorCommitFailed,
                                     @"$.transaction.commit",
                                     @"An optional replacement object is not installed exactly.");
    }
    if (participant.workspaceDescriptor >= 0) {
        BOOL replacementExists = NO;
        if (!PXOptionalRestoreNameState(participant.workspaceDescriptor,
                                        PXOptionalRestoreNameData(PXOptionalRestoreReplacementName),
                                        &replacementExists,
                                        NULL) || replacementExists) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorCommitFailed,
                                         @"$.transaction.commit",
                                         @"An installed optional replacement remains in its workspace.");
        }
    }
    return YES;
}

static BOOL PXOptionalRestoreRemoveNamedFileIfPresent(int parentDescriptor,
                                                       NSString *name,
                                                       dev_t expectedDevice,
                                                       NSError **error) {
    NSData *nameData = PXOptionalRestoreNameData(name);
    BOOL exists = NO;
    struct stat value;
    memset(&value, 0, sizeof(value));
    if (!PXOptionalRestoreNameState(parentDescriptor, nameData, &exists, &value)) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorCleanupFailed,
                                     @"$.transaction.cleanup",
                                     @"An optional cleanup file could not be inspected.");
    }
    if (!exists) return YES;
    if (!S_ISREG(value.st_mode) || value.st_nlink != 1 || value.st_dev != expectedDevice) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorCleanupFailed,
                                     @"$.transaction.cleanup",
                                     @"An optional cleanup file is unsafe.");
    }
    char *rawName = PXOptionalRestoreCopyTerminatedName(nameData);
    if (!rawName || unlinkat(parentDescriptor, rawName, 0) != 0) {
        free(rawName);
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorCleanupFailed,
                                     @"$.transaction.cleanup",
                                     @"An optional cleanup file could not be removed.");
    }
    free(rawName);
    return YES;
}

static BOOL PXOptionalRestoreOpenWorkspaceRootOnly(PXOptionalRestoreParticipant *participant,
                                                    BOOL *existsOut,
                                                    NSError **error) {
    if (existsOut) *existsOut = NO;
    PXOptionalRestoreCloseWorkspaceDescriptors(participant);
    char *workspaceName = PXOptionalRestoreCopyTerminatedName(participant.workspaceNameData);
    if (!workspaceName) return NO;
    int descriptor = openat(participant.authority.descriptor,
                            workspaceName,
                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    int savedError = errno;
    free(workspaceName);
    if (descriptor < 0) {
        if (savedError == ENOENT) return YES;
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorRecoveryFailed,
                                     @"$.recovery",
                                     @"An optional transaction workspace root could not be opened.");
    }
    struct stat value;
    memset(&value, 0, sizeof(value));
    if (fstat(descriptor, &value) != 0 || !S_ISDIR(value.st_mode) ||
        (value.st_mode & 0777) != 0700 ||
        value.st_dev != participant.authority.retainedStat.st_dev) {
        close(descriptor);
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorRecoveryFailed,
                                     @"$.recovery",
                                     @"An optional transaction workspace root is unsafe.");
    }
    participant.workspaceDescriptor = descriptor;
    if (existsOut) *existsOut = YES;
    return YES;
}

static BOOL PXOptionalRestoreRemoveWorkspace(PXOptionalRestoreParticipant *participant,
                                              BOOL leader,
                                              NSError **error) {
    BOOL exists = NO;
    if (!PXOptionalRestoreOpenWorkspaceRootOnly(participant, &exists, error)) return NO;
    if (!exists) return YES;
    NSArray<NSData *> *entries =
        PXOptionalRestoreReadDirectoryNames(participant.workspaceDescriptor,
                                             PXOptionalRestoreMaximumWorkspaceEntries,
                                             error,
                                             @"$.transaction.cleanup");
    if (!entries) return NO;
    for (NSData *nameData in entries) {
        BOOL common = PXOptionalRestoreRawNameEquals(nameData, PXOptionalRestoreOriginalName) ||
                      PXOptionalRestoreRawNameEquals(nameData, PXOptionalRestoreReplacementName) ||
                      PXOptionalRestoreRawNameEquals(nameData, PXOptionalRestoreNewName);
        BOOL journal = leader &&
                       (PXOptionalRestoreRawNameEquals(nameData, PXOptionalRestoreJournalName) ||
                        PXOptionalRestoreRawNameEquals(nameData, PXOptionalRestoreJournalTemporaryName));
        if (!common && !journal) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorCleanupFailed,
                                         @"$.transaction.cleanup",
                                         @"An optional transaction workspace contains an unexpected entry.");
        }
    }
    if (participant.item.kind == PXOptionalRestoreTransactionItemKindFileObject) {
        if (!PXOptionalRestoreRemoveNamedFileIfPresent(participant.workspaceDescriptor,
                                                        PXOptionalRestoreOriginalName,
                                                        participant.authority.retainedStat.st_dev,
                                                        error) ||
            !PXOptionalRestoreRemoveNamedFileIfPresent(participant.workspaceDescriptor,
                                                        PXOptionalRestoreReplacementName,
                                                        participant.authority.retainedStat.st_dev,
                                                        error) ||
            !PXOptionalRestoreRemoveNamedFileIfPresent(participant.workspaceDescriptor,
                                                        PXOptionalRestoreNewName,
                                                        participant.authority.retainedStat.st_dev,
                                                        error)) return NO;
    } else {
        if (!PXOptionalRestoreRemoveNamedDirectoryIfPresent(participant.workspaceDescriptor,
                                                             PXOptionalRestoreOriginalName,
                                                             error,
                                                             @"$.transaction.cleanup.original") ||
            !PXOptionalRestoreRemoveNamedDirectoryIfPresent(participant.workspaceDescriptor,
                                                             PXOptionalRestoreReplacementName,
                                                             error,
                                                             @"$.transaction.cleanup.replacement") ||
            !PXOptionalRestoreRemoveNamedDirectoryIfPresent(participant.workspaceDescriptor,
                                                             PXOptionalRestoreNewName,
                                                             error,
                                                             @"$.transaction.cleanup.new")) return NO;
    }
    if (leader) {
        for (NSString *name in @[PXOptionalRestoreJournalTemporaryName,
                                 PXOptionalRestoreJournalName]) {
            NSData *nameData = PXOptionalRestoreNameData(name);
            char *rawName = PXOptionalRestoreCopyTerminatedName(nameData);
            if (!rawName) return NO;
            if (unlinkat(participant.workspaceDescriptor, rawName, 0) != 0 && errno != ENOENT) {
                free(rawName);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorCleanupFailed,
                                             @"$.transaction.cleanup",
                                             @"An optional transaction journal could not be removed.");
            }
            free(rawName);
        }
    }
    if (!PXOptionalRestoreSyncDirectory(participant.workspaceDescriptor)) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorCleanupFailed,
                                     @"$.transaction.cleanup",
                                     @"An optional transaction workspace cleanup could not be synchronized.");
    }
    int workspaceDescriptor = participant.workspaceDescriptor;
    participant.workspaceDescriptor = -1;
    close(workspaceDescriptor);
    char *workspaceName = PXOptionalRestoreCopyTerminatedName(participant.workspaceNameData);
    if (!workspaceName ||
        unlinkat(participant.authority.descriptor, workspaceName, AT_REMOVEDIR) != 0 ||
        !PXOptionalRestoreSyncDirectory(participant.authority.descriptor)) {
        free(workspaceName);
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorCleanupFailed,
                                     @"$.transaction.cleanup",
                                     @"An optional transaction workspace could not be removed.");
    }
    free(workspaceName);
    return YES;
}

static BOOL PXOptionalRestoreCleanupTransaction(
    NSArray<PXOptionalRestoreParticipant *> *participants,
    NSError **error) {
    PXOptionalRestoreParticipant *leader = PXOptionalRestoreLeader(participants);
    for (PXOptionalRestoreParticipant *participant in participants) {
        if (participant == leader) continue;
        if (!PXOptionalRestoreRemoveWorkspace(participant, NO, error)) return NO;
    }
    return !leader || PXOptionalRestoreRemoveWorkspace(leader, YES, error);
}

static BOOL PXOptionalRestoreWorkspaceHasNoRecoveryData(
    PXOptionalRestoreParticipant *participant,
    NSError **error) {
    BOOL workspaceExists = NO;
    if (!PXOptionalRestoreOpenWorkspaceRootOnly(participant, &workspaceExists, error)) return NO;
    if (!workspaceExists) return YES;
    NSArray<NSData *> *entries =
        PXOptionalRestoreReadDirectoryNames(participant.workspaceDescriptor,
                                             PXOptionalRestoreMaximumWorkspaceEntries,
                                             error,
                                             @"$.recovery");
    if (!entries) return NO;
    for (NSData *nameData in entries) {
        BOOL temporaryJournal =
            PXOptionalRestoreRawNameEquals(nameData, PXOptionalRestoreJournalTemporaryName);
        BOOL allowed = PXOptionalRestoreRawNameEquals(nameData, PXOptionalRestoreOriginalName) ||
                       PXOptionalRestoreRawNameEquals(nameData, PXOptionalRestoreReplacementName) ||
                       PXOptionalRestoreRawNameEquals(nameData, PXOptionalRestoreNewName) ||
                       (participant.itemOrdinal == 0 && temporaryJournal);
        if (!allowed) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorRecoveryFailed,
                                         @"$.recovery",
                                         @"A no-journal optional workspace contains an unexpected entry.");
        }
        if (temporaryJournal) {
            BOOL exists = NO;
            struct stat value;
            memset(&value, 0, sizeof(value));
            if (!PXOptionalRestoreNameState(participant.workspaceDescriptor,
                                            nameData,
                                            &exists,
                                            &value) ||
                !exists || !S_ISREG(value.st_mode) || value.st_nlink != 1 ||
                (value.st_mode & 0777) != 0600 ||
                value.st_dev != participant.authority.retainedStat.st_dev ||
                value.st_size < 0 ||
                (unsigned long long)value.st_size > PXOptionalRestoreMaximumJournalBytes) {
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorRecoveryFailed,
                                             @"$.recovery",
                                             @"A no-journal optional temporary journal is unsafe.");
            }
        }
    }
    if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents) {
        for (NSString *name in @[PXOptionalRestoreOriginalName, PXOptionalRestoreNewName]) {
            BOOL exists = NO;
            int descriptor = PXOptionalRestoreOpenNamedDirectory(participant.workspaceDescriptor,
                                                                  name,
                                                                  &exists);
            if (descriptor < 0 && errno != ENOENT) return NO;
            if (!exists) continue;
            struct stat directoryStat;
            memset(&directoryStat, 0, sizeof(directoryStat));
            if (fstat(descriptor, &directoryStat) != 0 ||
                !S_ISDIR(directoryStat.st_mode) ||
                (directoryStat.st_mode & 0777) != 0700 ||
                directoryStat.st_dev != participant.authority.retainedStat.st_dev) {
                close(descriptor);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorRecoveryFailed,
                                             @"$.recovery",
                                             @"A no-journal optional recovery directory is unsafe.");
            }
            NSArray<NSData *> *names =
                PXOptionalRestoreReadDirectoryNames(descriptor, 1, error, @"$.recovery");
            close(descriptor);
            if (!names || names.count != 0) {
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorRecoveryFailed,
                                             @"$.recovery",
                                             @"A no-journal directory-contents workspace contains recovery data.");
            }
        }
    } else if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryObject) {
        for (NSString *name in @[PXOptionalRestoreOriginalName, PXOptionalRestoreNewName]) {
            BOOL exists = NO;
            int descriptor = PXOptionalRestoreOpenNamedDirectory(participant.workspaceDescriptor,
                                                                  name,
                                                                  &exists);
            if (descriptor < 0 && errno != ENOENT) return NO;
            if (!exists) continue;
            struct stat directoryStat;
            memset(&directoryStat, 0, sizeof(directoryStat));
            if (fstat(descriptor, &directoryStat) != 0 ||
                !S_ISDIR(directoryStat.st_mode) ||
                (directoryStat.st_mode & 0777) != 0700 ||
                directoryStat.st_dev != participant.authority.retainedStat.st_dev) {
                close(descriptor);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorRecoveryFailed,
                                             @"$.recovery",
                                             @"A no-journal optional recovery directory is unsafe.");
            }
            NSArray<NSData *> *names =
                PXOptionalRestoreReadDirectoryNames(descriptor, 1, error, @"$.recovery");
            close(descriptor);
            if (!names || names.count != 0) {
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorRecoveryFailed,
                                             @"$.recovery",
                                             @"A no-journal directory-object workspace contains recovery data.");
            }
        }
        BOOL replacementExists = NO;
        int replacement = PXOptionalRestoreOpenNamedDirectory(participant.workspaceDescriptor,
                                                               PXOptionalRestoreReplacementName,
                                                               &replacementExists);
        if (replacement < 0 && errno != ENOENT) return NO;
        if (replacementExists) {
            struct stat replacementDirectoryStat;
            memset(&replacementDirectoryStat, 0, sizeof(replacementDirectoryStat));
            if (fstat(replacement, &replacementDirectoryStat) != 0 ||
                !S_ISDIR(replacementDirectoryStat.st_mode) ||
                (replacementDirectoryStat.st_mode & 0777) != 0700 ||
                replacementDirectoryStat.st_dev != participant.authority.retainedStat.st_dev) {
                close(replacement);
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorRecoveryFailed,
                                             @"$.recovery",
                                             @"A no-journal optional replacement directory is unsafe.");
            }
            BOOL valid = PXOptionalRestoreVerifyDirectoryTree(
                replacement,
                participant.item.validatedDirectoryStage,
                error);
            close(replacement);
            if (!valid) return NO;
        }
    } else {
        for (NSString *name in @[PXOptionalRestoreOriginalName, PXOptionalRestoreNewName]) {
            BOOL exists = NO;
            if (!PXOptionalRestoreNameState(participant.workspaceDescriptor,
                                            PXOptionalRestoreNameData(name),
                                            &exists,
                                            NULL) || exists) {
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorRecoveryFailed,
                                             @"$.recovery",
                                             @"A no-journal file-object workspace contains recovery data.");
            }
        }
        BOOL replacementExists = NO;
        struct stat replacementStat;
        memset(&replacementStat, 0, sizeof(replacementStat));
        if (!PXOptionalRestoreNameState(participant.workspaceDescriptor,
                                        PXOptionalRestoreNameData(PXOptionalRestoreReplacementName),
                                        &replacementExists,
                                        &replacementStat)) return NO;
        if (replacementExists) {
            char *name = PXOptionalRestoreCopyTerminatedName(
                PXOptionalRestoreNameData(PXOptionalRestoreReplacementName));
            int descriptor = openat(participant.workspaceDescriptor,
                                    name,
                                    O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
            free(name);
            struct stat before;
            struct stat after;
            memset(&before, 0, sizeof(before));
            memset(&after, 0, sizeof(after));
            unsigned long long bytes = 0;
            NSString *digest = nil;
            BOOL valid = descriptor >= 0 && fstat(descriptor, &before) == 0 &&
                         S_ISREG(before.st_mode) && before.st_nlink == 1 &&
                         (before.st_mode & 0777) == 0600 &&
                         before.st_dev == participant.authority.retainedStat.st_dev &&
                         PXOptionalRestoreDigestFileDescriptor(descriptor,
                                                               PXOptionalRestoreMaximumFileBytes,
                                                               &bytes,
                                                               &digest) &&
                         fstat(descriptor, &after) == 0 &&
                         PXOptionalRestoreStableFileStatsEqual(&before, &after) &&
                         bytes == participant.item.validatedFileStage.byteCount &&
                         [digest isEqualToString:participant.item.validatedFileStage.sha256];
            if (descriptor >= 0) close(descriptor);
            if (!valid) {
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorRecoveryFailed,
                                             @"$.recovery",
                                             @"A no-journal file replacement does not match the current accepted stage.");
            }
        }
    }
    if (!PXOptionalRestoreParticipantProofIsValid(participant, YES, YES, YES, error)) return NO;
    return YES;
}

#pragma mark - Rollback and stale recovery

static BOOL PXOptionalRestoreRollbackObject(PXOptionalRestoreParticipant *participant,
                                             NSError **error) {
    NSData *replacementName = PXOptionalRestoreNameData(PXOptionalRestoreReplacementName);
    NSData *originalName = PXOptionalRestoreNameData(PXOptionalRestoreOriginalName);
    NSData *newName = PXOptionalRestoreNameData(PXOptionalRestoreNewName);
    BOOL destinationExists = NO;
    struct stat destinationStat;
    memset(&destinationStat, 0, sizeof(destinationStat));
    if (!PXOptionalRestoreNameState(participant.authority.descriptor,
                                    participant.destinationNameData,
                                    &destinationExists,
                                    &destinationStat)) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorRollbackFailed,
                                     @"$.transaction.rollback",
                                     @"An optional destination could not be inspected during rollback.");
    }
    BOOL destinationIsReplacement = destinationExists && participant.replacementObject &&
                                    [participant.replacementObject matchesStat:&destinationStat];
    BOOL destinationIsOriginal = destinationExists && participant.originalObject &&
                                 [participant.originalObject matchesStat:&destinationStat];
    if (destinationExists && !destinationIsReplacement && !destinationIsOriginal) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorRollbackFailed,
                                     @"$.transaction.rollback",
                                     @"An optional destination has an unknown rollback identity.");
    }
    if (destinationIsReplacement) {
        if (!PXOptionalRestoreMoveNamedObject(participant.replacementObject,
                                              participant.authority.descriptor,
                                              participant.destinationNameData,
                                              participant.workspaceDescriptor,
                                              newName,
                                              PXOptionalRestoreTransactionErrorRollbackFailed,
                                              @"$.transaction.rollback.new",
                                              @"An installed optional replacement could not be quarantined during rollback.",
                                              error)) return NO;
        destinationExists = NO;
        destinationIsOriginal = NO;
    }
    if (participant.initiallyExisted) {
        BOOL originalInWorkspace = NO;
        BOOL originalAtDestination = NO;
        if (!PXOptionalRestoreEntryMatchesNamedState(participant.originalObject,
                                                     participant.workspaceDescriptor,
                                                     originalName,
                                                     &originalInWorkspace) ||
            !PXOptionalRestoreEntryMatchesNamedState(participant.originalObject,
                                                     participant.authority.descriptor,
                                                     participant.destinationNameData,
                                                     &originalAtDestination) ||
            (originalInWorkspace && originalAtDestination) ||
            (!originalInWorkspace && !originalAtDestination)) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorRollbackFailed,
                                         @"$.transaction.rollback.original",
                                         @"An original optional object has an inconsistent rollback identity.");
        }
        if (originalInWorkspace &&
            !PXOptionalRestoreMoveNamedObject(participant.originalObject,
                                              participant.workspaceDescriptor,
                                              originalName,
                                              participant.authority.descriptor,
                                              participant.destinationNameData,
                                              PXOptionalRestoreTransactionErrorRollbackFailed,
                                              @"$.transaction.rollback.original",
                                              @"An original optional object could not be restored.",
                                              error)) return NO;
    } else {
        BOOL exists = NO;
        if (!PXOptionalRestoreNameState(participant.authority.descriptor,
                                        participant.destinationNameData,
                                        &exists,
                                        NULL) || exists) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorRollbackFailed,
                                         @"$.transaction.rollback",
                                         @"An initially absent optional destination could not be restored to absence.");
        }
    }
    if (!PXOptionalRestoreSyncDirectory(participant.authority.descriptor) ||
        !PXOptionalRestoreSyncDirectory(participant.workspaceDescriptor) ||
        !PXOptionalRestoreRequireOriginalState(participant, error)) {
        if (error && !*error) {
            PXOptionalRestoreFail(error,
                                  PXOptionalRestoreTransactionErrorRollbackFailed,
                                  @"$.transaction.rollback",
                                  @"An optional object rollback could not be synchronized.");
        }
        return NO;
    }
    (void)replacementName;
    return YES;
}

static BOOL PXOptionalRestoreRollbackParticipant(PXOptionalRestoreParticipant *participant,
                                                  NSError **error) {
    if (participant.workspaceDescriptor < 0) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorRollbackFailed,
                                     @"$.transaction.rollback",
                                     @"An optional rollback workspace is unavailable.");
    }
    if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents) {
        if (participant.originalDescriptor < 0 || participant.newDescriptor < 0) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorRollbackFailed,
                                         @"$.transaction.rollback",
                                         @"A directory-contents rollback workspace is incomplete.");
        }
        return PXOptionalRestoreRollbackEntries(participant.originalEntries,
                                                 participant.stagedEntries,
                                                 participant.authority.descriptor,
                                                 participant.originalDescriptor,
                                                 participant.newDescriptor,
                                                 error);
    }
    return PXOptionalRestoreRollbackObject(participant, error);
}

static BOOL PXOptionalRestoreRollbackTransaction(
    NSArray<PXOptionalRestoreParticipant *> *participants,
    NSString *transactionIdentifier,
    BOOL *rollbackPerformedOut,
    BOOL *rollbackCompleteOut,
    NSError **cleanupWarning,
    NSError **error) {
    if (rollbackPerformedOut) *rollbackPerformedOut = YES;
    if (rollbackCompleteOut) *rollbackCompleteOut = NO;
    NSError *phaseError = nil;
    PXOptionalRestoreWriteLeaderJournal(participants,
                                        transactionIdentifier,
                                        PXOptionalRestorePhaseRollingBack,
                                        &phaseError);
    NSArray<PXOptionalRestoreParticipant *> *managerOrder = PXOptionalRestoreManagerOrder(participants);
    for (PXOptionalRestoreParticipant *participant in managerOrder.reverseObjectEnumerator) {
        if (!PXOptionalRestoreRollbackParticipant(participant, error)) return NO;
    }
    for (PXOptionalRestoreParticipant *participant in participants) {
        if (!PXOptionalRestoreRequireOriginalState(participant, error)) return NO;
    }
    if (!PXOptionalRestoreWriteLeaderJournal(participants,
                                             transactionIdentifier,
                                             PXOptionalRestorePhaseRolledBack,
                                             error)) {
        if (error && *error) {
            *error = [NSError errorWithDomain:PXOptionalRestoreTransactionErrorDomain
                                         code:PXOptionalRestoreTransactionErrorRollbackFailed
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"The optional transaction rolled-back decision could not be published.",
                                         PXOptionalRestoreTransactionErrorFieldPathKey: @"$.transaction.rollback"
                                     }];
        }
        return NO;
    }
    if (rollbackCompleteOut) *rollbackCompleteOut = YES;
    NSError *cleanupError = nil;
    if (!PXOptionalRestoreCleanupTransaction(participants, &cleanupError) && cleanupWarning) {
        *cleanupWarning = cleanupError;
    }
    return YES;
}

static BOOL PXOptionalRestoreResetAfterRecovery(
    NSArray<PXOptionalRestoreParticipant *> *participants,
    NSError **error) {
    for (PXOptionalRestoreParticipant *participant in participants) {
        PXOptionalRestoreCloseWorkspaceDescriptors(participant);
        participant.workspaceNameData = nil;
        participant.originalEntries = @[];
        participant.stagedEntries = @[];
        participant.originalObject = nil;
        participant.replacementObject = nil;
        participant.fileByteCount = 0;
        participant.fileSHA256 = nil;
        if (!PXOptionalRestoreParticipantProofIsValid(participant, YES, NO, YES, error) ||
            !PXOptionalRestoreInspectCurrentDestination(participant, YES, error)) return NO;
    }
    return YES;
}

static BOOL PXOptionalRestoreRecoverStaleTransaction(
    NSArray<PXOptionalRestoreParticipant *> *participants,
    NSArray<PXOptionalRestoreAuthority *> *authorities,
    NSUInteger *recoveredCountOut,
    NSError **error) {
    if (recoveredCountOut) *recoveredCountOut = 0;
    NSDictionary<NSNumber *, PXOptionalRestoreParticipant *> *byOrdinal =
        PXOptionalRestoreParticipantsByOrdinal(participants);
    NSMutableSet<NSString *> *identifiers = [NSMutableSet set];
    NSMutableSet<NSNumber *> *detectedOrdinals = [NSMutableSet set];
    for (PXOptionalRestoreAuthority *authority in authorities) {
        NSArray<NSData *> *names =
            PXOptionalRestoreReadDirectoryNames(authority.descriptor,
                                                 PXOptionalRestoreMaximumTopLevelEntries,
                                                 error,
                                                 @"$.recovery");
        if (!names) return NO;
        for (NSData *nameData in names) {
            if (!PXOptionalRestoreRawNameHasPrefix(nameData, PXOptionalRestoreTransactionPrefix)) continue;
            NSString *identifier = nil;
            NSUInteger ordinal = NSNotFound;
            if (!PXOptionalRestoreParseWorkspaceName(nameData, &identifier, &ordinal)) {
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorRecoveryFailed,
                                             @"$.recovery",
                                             @"A reserved optional transaction workspace name is malformed.");
            }
            NSNumber *ordinalKey = @(ordinal);
            PXOptionalRestoreParticipant *participant = byOrdinal[ordinalKey];
            if (!participant || participant.authority != authority ||
                [detectedOrdinals containsObject:ordinalKey]) {
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorInconsistentBatch,
                                             @"$.recovery",
                                             @"A stale optional transaction workspace cannot be bound exactly.");
            }
            BOOL exists = NO;
            struct stat workspaceStat;
            memset(&workspaceStat, 0, sizeof(workspaceStat));
            if (!PXOptionalRestoreNameState(authority.descriptor,
                                            nameData,
                                            &exists,
                                            &workspaceStat) || !exists ||
                !S_ISDIR(workspaceStat.st_mode) ||
                (workspaceStat.st_mode & 0777) != 0700 ||
                workspaceStat.st_dev != authority.retainedStat.st_dev) {
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorRecoveryFailed,
                                             @"$.recovery",
                                             @"A stale optional transaction workspace is unsafe.");
            }
            participant.workspaceNameData = nameData;
            [identifiers addObject:identifier];
            [detectedOrdinals addObject:ordinalKey];
            if (identifiers.count > PXOptionalRestoreMaximumStaleTransactionIdentifiers) {
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorInconsistentBatch,
                                             @"$.recovery",
                                             @"Multiple stale optional transaction identifiers are present.");
            }
        }
    }
    if (identifiers.count == 0) return YES;
    NSString *identifier = identifiers.anyObject;
    for (PXOptionalRestoreParticipant *participant in participants) {
        NSString *expectedName = PXOptionalRestoreWorkspaceName(identifier, participant.itemOrdinal);
        NSData *expectedData = PXOptionalRestoreNameData(expectedName);
        if (!participant.workspaceNameData) participant.workspaceNameData = expectedData;
        else if (![participant.workspaceNameData isEqualToData:expectedData]) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorInconsistentBatch,
                                         @"$.recovery",
                                         @"A stale optional transaction workspace name is inconsistent.");
        }
    }
    PXOptionalRestoreParticipant *leader = PXOptionalRestoreLeader(participants);
    BOOL leaderExists = NO;
    if (!PXOptionalRestoreOpenWorkspaceRootOnly(leader, &leaderExists, error)) return NO;
    BOOL journalExists = NO;
    if (leaderExists &&
        !PXOptionalRestoreNameState(leader.workspaceDescriptor,
                                    PXOptionalRestoreNameData(PXOptionalRestoreJournalName),
                                    &journalExists,
                                    NULL)) return NO;
    if (!journalExists) {
        for (NSNumber *ordinalKey in detectedOrdinals) {
            PXOptionalRestoreParticipant *participant = byOrdinal[ordinalKey];
            if (!PXOptionalRestoreWorkspaceHasNoRecoveryData(participant, error)) return NO;
        }
        NSError *cleanupError = nil;
        if (!PXOptionalRestoreCleanupTransaction(participants, &cleanupError)) {
            if (error) *error = cleanupError;
            return NO;
        }
        if (recoveredCountOut) *recoveredCountOut = 1;
        return PXOptionalRestoreResetAfterRecovery(participants, error);
    }
    NSDictionary *journal =
        PXOptionalRestoreReadLeaderJournal(participants, identifier, error);
    if (!journal) return NO;
    NSString *phase = journal[@"phase"];
    BOOL terminalPhase = [phase isEqualToString:PXOptionalRestorePhaseCommitted] ||
                         [phase isEqualToString:PXOptionalRestorePhaseRolledBack];
    for (PXOptionalRestoreParticipant *participant in participants) {
        if (!PXOptionalRestoreOpenWorkspace(participant, !terminalPhase, error)) return NO;
    }
    if ([phase isEqualToString:PXOptionalRestorePhaseCommitted]) {
        for (PXOptionalRestoreParticipant *participant in participants) {
            if (!PXOptionalRestoreRequireInstalledState(participant, error)) return NO;
        }
        if (!PXOptionalRestoreCleanupTransaction(participants, error)) return NO;
    } else if ([phase isEqualToString:PXOptionalRestorePhaseRolledBack]) {
        for (PXOptionalRestoreParticipant *participant in participants) {
            if (!PXOptionalRestoreRequireOriginalState(participant, error)) return NO;
        }
        if (!PXOptionalRestoreCleanupTransaction(participants, error)) return NO;
    } else {
        BOOL performed = NO;
        BOOL complete = NO;
        NSError *cleanupWarning = nil;
        NSError *rollbackError = nil;
        if (!PXOptionalRestoreRollbackTransaction(participants,
                                                  identifier,
                                                  &performed,
                                                  &complete,
                                                  &cleanupWarning,
                                                  &rollbackError) || !complete) {
            if (error) {
                *error = rollbackError ?:
                    [NSError errorWithDomain:PXOptionalRestoreTransactionErrorDomain
                                         code:PXOptionalRestoreTransactionErrorRollbackFailed
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"A stale optional transaction could not be rolled back completely.",
                                         PXOptionalRestoreTransactionErrorFieldPathKey: @"$.recovery"
                                     }];
            }
            return NO;
        }
        if (cleanupWarning) {
            if (error) *error = cleanupWarning;
            return NO;
        }
    }
    if (recoveredCountOut) *recoveredCountOut = 1;
    return PXOptionalRestoreResetAfterRecovery(participants, error);
}

#pragma mark - Transaction factory

@interface PXOptionalRestoreTransaction ()
@property (nonatomic, assign, readwrite, getter=isCommitted) BOOL committed;
@property (nonatomic, assign, readwrite) BOOL rollbackPerformed;
@property (nonatomic, assign, readwrite) BOOL rollbackComplete;
@property (nonatomic, assign, readwrite) NSUInteger recoveredStaleTransactionCount;
@property (nonatomic, assign, readwrite) NSUInteger itemCount;
@property (nonatomic, copy) NSArray<PXOptionalRestoreTransactionItem *> *items;
@property (nonatomic, copy) NSArray<PXOptionalRestoreParticipant *> *participants;
@property (nonatomic, copy) NSArray<PXOptionalRestoreAuthority *> *authorities;
@property (nonatomic, copy, nullable) NSString *transactionIdentifier;
@property (nonatomic, assign) BOOL prepared;
@property (nonatomic, assign) BOOL attempted;
- (instancetype)initPrivate;
@end

@implementation PXOptionalRestoreTransaction

+ (instancetype)transactionForItems:(NSArray<PXOptionalRestoreTransactionItem *> *)items
                                error:(NSError **)error {
    if (error) *error = nil;
    if (![items isKindOfClass:[NSArray class]] ||
        items.count == 0 || items.count > PXOptionalRestoreMaximumItems) {
        return PXOptionalRestoreFailObject(error,
                                           PXOptionalRestoreTransactionErrorInvalidInput,
                                           @"$.items",
                                           @"The optional transaction item array is invalid.");
    }
    NSArray<PXOptionalRestoreTransactionItem *> *copiedItems = [items copy];
    NSMutableArray<PXOptionalRestoreParticipant *> *participants =
        [NSMutableArray arrayWithCapacity:copiedItems.count];
    NSMutableArray<PXOptionalRestoreAuthority *> *authorities = [NSMutableArray array];
    NSMutableDictionary<NSString *, PXOptionalRestoreAuthority *> *authorityByIdentity =
        [NSMutableDictionary dictionary];
    NSMutableSet<NSData *> *destinationPaths = [NSMutableSet set];
    NSMutableSet<NSString *> *physicalDestinations = [NSMutableSet set];

    for (NSUInteger index = 0; index < copiedItems.count; index++) {
        id object = copiedItems[index];
        if (![object isKindOfClass:[PXOptionalRestoreTransactionItem class]]) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorInvalidInput,
                                               @"$.items",
                                               @"An optional transaction item has an invalid runtime class.");
        }
        PXOptionalRestoreTransactionItem *item = object;
        if (!PXOptionalRestorePathIsValid(item.destinationPath)) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorInvalidInput,
                                               @"$.destination",
                                               @"An optional transaction destination path is invalid.");
        }
        NSData *destinationBytes =
            [item.destinationPath dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
        if (!PXOptionalRestoreCanonicalBytesAreValid(destinationBytes) ||
            [destinationPaths containsObject:destinationBytes]) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorInconsistentBatch,
                                               @"$.items",
                                               @"Optional transaction destinations are duplicated.");
        }
        for (PXOptionalRestoreParticipant *earlier in participants) {
            if (PXOptionalRestorePathsCollide(earlier.item.destinationPath,
                                              item.destinationPath)) {
                return PXOptionalRestoreFailObject(error,
                                                   PXOptionalRestoreTransactionErrorInconsistentBatch,
                                                   @"$.items",
                                                   @"Optional transaction destinations overlap.");
            }
        }
        [destinationPaths addObject:destinationBytes];
        BOOL directoryKind = item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents ||
                             item.kind == PXOptionalRestoreTransactionItemKindDirectoryObject;
        BOOL fileKind = item.kind == PXOptionalRestoreTransactionItemKindFileObject;
        if ((directoryKind &&
             (![item.validatedDirectoryStage isKindOfClass:[PXValidatedMainDataStage class]] ||
              item.validatedFileStage != nil || item.validatedDirectoryStage.dataPath.length == 0 ||
              !PXOptionalRestoreLowercaseSHA256IsValid(item.validatedDirectoryStage.treeSHA256))) ||
            (fileKind &&
             (![item.validatedFileStage isKindOfClass:[PXValidatedOptionalFileStage class]] ||
              item.validatedDirectoryStage != nil || item.validatedFileStage.filePath.length == 0 ||
              item.validatedFileStage.byteCount > PXOptionalRestoreMaximumFileBytes ||
              !PXOptionalRestoreLowercaseSHA256IsValid(item.validatedFileStage.sha256))) ||
            (!directoryKind && !fileKind)) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorInvalidInput,
                                               @"$.stage",
                                               @"An optional transaction stage is invalid.");
        }

        PXOptionalRestoreParticipant *participant = [[PXOptionalRestoreParticipant alloc] init];
        participant.item = item;
        participant.managerOrder = index;
        participant.destinationBytes = destinationBytes;
        participant.destinationNameData = PXOptionalRestoreNameData(item.destinationPath.lastPathComponent);
        participant.authorityPath = item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents
            ? item.destinationPath : [item.destinationPath stringByDeletingLastPathComponent];
        participant.stagePath = fileKind
            ? item.validatedFileStage.filePath : item.validatedDirectoryStage.dataPath;
        if (!PXOptionalRestoreNameIsSafe(participant.destinationNameData) ||
            ![participant.authorityPath isKindOfClass:[NSString class]] ||
            participant.authorityPath.length == 0 ||
            ![participant.stagePath isKindOfClass:[NSString class]] ||
            participant.stagePath.length == 0) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorInvalidInput,
                                               @"$.destination",
                                               @"An optional transaction destination component is invalid.");
        }
        int authorityDescriptor = open(participant.authorityPath.fileSystemRepresentation,
                                       O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        struct stat authorityStat;
        memset(&authorityStat, 0, sizeof(authorityStat));
        if (authorityDescriptor < 0 || fstat(authorityDescriptor, &authorityStat) != 0 ||
            !S_ISDIR(authorityStat.st_mode) ||
            !PXOptionalRestorePathMatchesDescriptor(participant.authorityPath,
                                                     authorityDescriptor)) {
            if (authorityDescriptor >= 0) close(authorityDescriptor);
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorDestinationValidationFailed,
                                               @"$.destination",
                                               @"An optional transaction authority directory could not be bound.");
        }
        NSString *authorityKey = [NSString stringWithFormat:@"%llu:%llu",
                                  (unsigned long long)authorityStat.st_dev,
                                  (unsigned long long)authorityStat.st_ino];
        PXOptionalRestoreAuthority *authority = authorityByIdentity[authorityKey];
        if (authority) {
            close(authorityDescriptor);
            if (PXOptionalRestoreCompareRawNames(destinationBytes, authority.orderBytes) == NSOrderedAscending) {
                authority.orderBytes = destinationBytes;
                authority.path = participant.authorityPath;
            }
        } else {
            authority = [[PXOptionalRestoreAuthority alloc] init];
            authority.path = participant.authorityPath;
            authority.orderBytes = destinationBytes;
            authority.retainedStat = authorityStat;
            authority.descriptor = authorityDescriptor;
            authorityByIdentity[authorityKey] = authority;
            [authorities addObject:authority];
        }
        participant.authority = authority;
        if (!PXOptionalRestoreInspectCurrentDestination(participant, YES, error)) return nil;
        struct stat destinationStat = participant.originalDestinationStat;
        NSString *physicalKey = nil;
        if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents) {
            physicalKey = [NSString stringWithFormat:@"%llu:%llu:%u",
                           (unsigned long long)authority.retainedStat.st_dev,
                           (unsigned long long)authority.retainedStat.st_ino,
                           (unsigned int)(authority.retainedStat.st_mode & S_IFMT)];
        } else if (participant.initiallyExisted) {
            physicalKey = [NSString stringWithFormat:@"%llu:%llu:%u",
                           (unsigned long long)destinationStat.st_dev,
                           (unsigned long long)destinationStat.st_ino,
                           (unsigned int)(destinationStat.st_mode & S_IFMT)];
        }
        if (physicalKey && [physicalDestinations containsObject:physicalKey]) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorInconsistentBatch,
                                               @"$.items",
                                               @"Two optional transaction items resolve to one physical destination.");
        }
        if (physicalKey) [physicalDestinations addObject:physicalKey];
        [participants addObject:participant];
    }

    NSArray<PXOptionalRestoreParticipant *> *itemLockOrder =
        PXOptionalRestoreItemLockOrder(participants);
    for (NSUInteger index = 0; index < itemLockOrder.count; index++) {
        itemLockOrder[index].itemOrdinal = index;
    }
    NSArray<PXOptionalRestoreAuthority *> *authorityLockOrder =
        PXOptionalRestoreAuthorityLockOrder(authorities);
    for (NSUInteger index = 0; index < authorityLockOrder.count; index++) {
        PXOptionalRestoreAuthority *authority = authorityLockOrder[index];
        authority.lockOrdinal = index;
        int lockDescriptor = open(authority.path.fileSystemRepresentation,
                                  O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        struct stat lockStat;
        memset(&lockStat, 0, sizeof(lockStat));
        if (lockDescriptor < 0 || fstat(lockDescriptor, &lockStat) != 0 ||
            !S_ISDIR(lockStat.st_mode) ||
            lockStat.st_dev != authority.retainedStat.st_dev ||
            lockStat.st_ino != authority.retainedStat.st_ino ||
            !PXOptionalRestorePathMatchesDescriptor(authority.path, lockDescriptor)) {
            if (lockDescriptor >= 0) close(lockDescriptor);
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorLockFailed,
                                               @"$.locks",
                                               @"An optional transaction lock authority could not be bound.");
        }
        authority.lockDescriptor = lockDescriptor;
        if (flock(lockDescriptor, LOCK_EX | LOCK_NB) != 0) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorLockFailed,
                                               @"$.locks",
                                               @"An optional transaction authority lock is unavailable.");
        }
    }

    for (PXOptionalRestoreParticipant *participant in participants) {
        if (!PXOptionalRestoreParticipantProofIsValid(participant, YES, YES, NO, error)) return nil;
        BOOL fileKind = participant.item.kind == PXOptionalRestoreTransactionItemKindFileObject;
        int stageDescriptor = open(participant.stagePath.fileSystemRepresentation,
                                   fileKind
                                     ? (O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC)
                                     : (O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC));
        struct stat stageStat;
        memset(&stageStat, 0, sizeof(stageStat));
        if (stageDescriptor < 0 || fstat(stageDescriptor, &stageStat) != 0 ||
            (fileKind && (!S_ISREG(stageStat.st_mode) || stageStat.st_nlink != 1 ||
                          stageStat.st_size < 0 ||
                          (unsigned long long)stageStat.st_size !=
                              participant.item.validatedFileStage.byteCount)) ||
            (!fileKind && !S_ISDIR(stageStat.st_mode)) ||
            stageStat.st_dev != participant.authority.retainedStat.st_dev ||
            !PXOptionalRestorePathMatchesDescriptorType(participant.stagePath,
                                                        stageDescriptor,
                                                        fileKind ? S_IFREG : S_IFDIR)) {
            if (stageDescriptor >= 0) close(stageDescriptor);
            return PXOptionalRestoreFailObject(error,
                                               stageStat.st_dev != participant.authority.retainedStat.st_dev
                                                 ? PXOptionalRestoreTransactionErrorCrossDeviceBoundary
                                                 : PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
                                               @"$.stage",
                                               @"An optional transaction stage could not be bound on the destination filesystem.");
        }
        participant.stageDescriptor = stageDescriptor;
        participant.stageStat = stageStat;
        if (!PXOptionalRestoreParticipantProofIsValid(participant, YES, YES, YES, error)) return nil;
    }

    NSUInteger recoveredCount = 0;
    if (!PXOptionalRestoreRecoverStaleTransaction(participants,
                                                  authorities,
                                                  &recoveredCount,
                                                  error)) return nil;
    for (PXOptionalRestoreParticipant *participant in participants) {
        if (!PXOptionalRestoreParticipantProofIsValid(participant, YES, YES, YES, error)) return nil;
    }

    NSUInteger aggregateEntries = 0;
    for (PXOptionalRestoreParticipant *participant in participants) {
        if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents) {
            participant.originalEntries =
                PXOptionalRestoreCollectEntries(participant.authority.descriptor,
                                                 NO, NO, YES, YES,
                                                 error,
                                                 @"$.destination");
            participant.stagedEntries =
                PXOptionalRestoreCollectEntries(participant.stageDescriptor,
                                                 YES, YES, NO, NO,
                                                 error,
                                                 @"$.stage");
        } else if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryObject) {
            participant.originalEntries = @[];
            participant.stagedEntries =
                PXOptionalRestoreCollectEntries(participant.stageDescriptor,
                                                 YES, YES, NO, NO,
                                                 error,
                                                 @"$.stage");
        } else {
            participant.originalEntries = @[];
            participant.stagedEntries = @[];
            participant.fileByteCount = participant.item.validatedFileStage.byteCount;
            participant.fileSHA256 = participant.item.validatedFileStage.sha256;
        }
        if (!participant.originalEntries || !participant.stagedEntries ||
            participant.originalEntries.count > PXOptionalRestoreMaximumTopLevelEntries ||
            participant.stagedEntries.count > PXOptionalRestoreMaximumTopLevelEntries ||
            participant.originalEntries.count > PXOptionalRestoreMaximumAggregateEntries - aggregateEntries) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorEntryLimitExceeded,
                                               @"$.items",
                                               @"An optional transaction entry limit was exceeded.");
        }
        aggregateEntries += participant.originalEntries.count;
        if (participant.stagedEntries.count > PXOptionalRestoreMaximumAggregateEntries - aggregateEntries) {
            return PXOptionalRestoreFailObject(error,
                                               PXOptionalRestoreTransactionErrorEntryLimitExceeded,
                                               @"$.items",
                                               @"The optional transaction aggregate entry limit was exceeded.");
        }
        aggregateEntries += participant.stagedEntries.count;
    }

    PXOptionalRestoreTransaction *transaction = [[self alloc] initPrivate];
    transaction.items = copiedItems;
    transaction.participants = [participants copy];
    transaction.authorities = [authorities copy];
    transaction.itemCount = copiedItems.count;
    transaction.recoveredStaleTransactionCount = recoveredCount;
    return transaction;
}

- (instancetype)initPrivate {
    self = [super init];
    return self;
}

#pragma mark - New transaction commit

- (BOOL)revalidatePreparedStateWithError:(NSError **)error {
    for (PXOptionalRestoreAuthority *authority in self.authorities) {
        if (!PXOptionalRestoreAuthorityIdentityIsValid(authority, YES, error)) return NO;
    }
    for (PXOptionalRestoreParticipant *participant in self.participants) {
        if (!PXOptionalRestoreParticipantProofIsValid(participant, YES, YES, YES, error)) return NO;
        if (participant.item.kind != PXOptionalRestoreTransactionItemKindFileObject &&
            !PXOptionalRestoreRequireExactEntries(participant.stageDescriptor,
                                                   participant.stagedEntries,
                                                   YES, YES, NO, NO,
                                                   PXOptionalRestoreTransactionErrorFilesystemChanged,
                                                   @"$.stage",
                                                   @"An accepted optional directory stage changed before commit.",
                                                   error)) return NO;
        if (participant.item.kind == PXOptionalRestoreTransactionItemKindFileObject) {
            struct stat value;
            memset(&value, 0, sizeof(value));
            struct stat retainedStageStat = participant.stageStat;
            if (fstat(participant.stageDescriptor, &value) != 0 ||
                !PXOptionalRestoreStatIdentityMatches(&retainedStageStat, &value) ||
                value.st_size < 0 ||
                (unsigned long long)value.st_size != participant.item.validatedFileStage.byteCount) {
                return PXOptionalRestoreFail(error,
                                             PXOptionalRestoreTransactionErrorFilesystemChanged,
                                             @"$.stage",
                                             @"An accepted optional file stage changed before commit.");
            }
        }
    }
    return YES;
}

static BOOL PXOptionalRestoreReturnDirectoryReplacementToStage(
    PXOptionalRestoreParticipant *participant,
    NSError **error) {
    if (participant.item.kind != PXOptionalRestoreTransactionItemKindDirectoryObject ||
        participant.replacementDescriptor < 0) return YES;
    for (PXOptionalRestoreEntry *entry in participant.stagedEntries.reverseObjectEnumerator) {
        BOOL stageExists = NO;
        BOOL replacementExists = NO;
        if (!PXOptionalRestoreEntryMatchesAt(entry, participant.stageDescriptor, &stageExists) ||
            !PXOptionalRestoreEntryMatchesAt(entry, participant.replacementDescriptor, &replacementExists) ||
            (stageExists && replacementExists) || (!stageExists && !replacementExists)) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorReplacementPreparationFailed,
                                         @"$.replacement",
                                         @"A prepared directory replacement cannot be returned to staging safely.");
        }
        if (replacementExists &&
            !PXOptionalRestoreMoveEntry(entry,
                                        participant.replacementDescriptor,
                                        participant.stageDescriptor,
                                        error,
                                        PXOptionalRestoreTransactionErrorReplacementPreparationFailed,
                                        @"$.replacement",
                                        @"A prepared directory entry could not be returned to staging.")) return NO;
    }
    return PXOptionalRestoreSyncDirectory(participant.stageDescriptor) &&
           PXOptionalRestoreSyncDirectory(participant.replacementDescriptor);
}

- (BOOL)cleanupUnpreparedWorkspacesWithError:(NSError **)error {
    BOOL restored = YES;
    for (PXOptionalRestoreParticipant *participant in self.participants.reverseObjectEnumerator) {
        NSError *restoreError = nil;
        if (!PXOptionalRestoreReturnDirectoryReplacementToStage(participant, &restoreError)) {
            restored = NO;
            if (error && !*error) *error = restoreError;
        }
    }
    NSError *cleanupError = nil;
    BOOL cleaned = PXOptionalRestoreCleanupTransaction(self.participants, &cleanupError);
    if (!cleaned && error && !*error) *error = cleanupError;
    return restored && cleaned;
}

- (BOOL)prepareWorkspacesAndReplacementsWithError:(NSError **)error {
    NSString *identifier = [[[NSUUID UUID] UUIDString] lowercaseString];
    if (identifier.length != 36) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorWorkspaceCreationFailed,
                                     @"$.workspace",
                                     @"An optional transaction identifier could not be created.");
    }
    self.transactionIdentifier = identifier;
    for (PXOptionalRestoreParticipant *participant in PXOptionalRestoreManagerOrder(self.participants)) {
        if (!PXOptionalRestoreCreateWorkspace(participant, identifier, error)) {
            [self cleanupUnpreparedWorkspacesWithError:nil];
            return NO;
        }
    }
    for (PXOptionalRestoreParticipant *participant in PXOptionalRestoreManagerOrder(self.participants)) {
        if (!PXOptionalRestorePrepareReplacement(participant, error)) {
            NSError *cleanupError = nil;
            if (![self cleanupUnpreparedWorkspacesWithError:&cleanupError] && error && !*error) {
                *error = cleanupError;
            }
            return NO;
        }
    }
    for (PXOptionalRestoreParticipant *participant in self.participants) {
        if (!PXOptionalRestoreSyncDirectory(participant.authority.descriptor) ||
            !PXOptionalRestoreSyncDirectory(participant.workspaceDescriptor) ||
            (participant.item.kind != PXOptionalRestoreTransactionItemKindFileObject &&
             !PXOptionalRestoreSyncDirectory(participant.stageDescriptor))) {
            [self cleanupUnpreparedWorkspacesWithError:nil];
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorWorkspaceCreationFailed,
                                         @"$.workspace",
                                         @"Optional transaction replacement preparation could not be synchronized.");
        }
    }
    return YES;
}

- (BOOL)quarantineItemsWithError:(NSError **)error {
    for (PXOptionalRestoreParticipant *participant in PXOptionalRestoreManagerOrder(self.participants)) {
        if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents) {
            if (!PXOptionalRestoreMoveEntryList(participant.originalEntries,
                                                participant.authority.descriptor,
                                                participant.originalDescriptor,
                                                PXOptionalRestoreTransactionErrorQuarantineFailed,
                                                @"$.transaction.quarantine",
                                                @"An original directory-contents entry could not be quarantined.",
                                                error) ||
                !PXOptionalRestoreRequireExactEntries(participant.authority.descriptor,
                                                       @[], NO, NO, YES, YES,
                                                       PXOptionalRestoreTransactionErrorQuarantineFailed,
                                                       @"$.transaction.quarantine",
                                                       @"A directory-contents destination is not empty after quarantine.",
                                                       error) ||
                !PXOptionalRestoreRequireExactEntries(participant.originalDescriptor,
                                                       participant.originalEntries,
                                                       NO, NO, NO, NO,
                                                       PXOptionalRestoreTransactionErrorQuarantineFailed,
                                                       @"$.transaction.quarantine",
                                                       @"A directory-contents quarantine does not match the journal.",
                                                       error) ||
                !PXOptionalRestoreSyncDirectory(participant.authority.descriptor) ||
                !PXOptionalRestoreSyncDirectory(participant.originalDescriptor)) {
                if (error && !*error) {
                    PXOptionalRestoreFail(error,
                                          PXOptionalRestoreTransactionErrorQuarantineFailed,
                                          @"$.transaction.quarantine",
                                          @"A directory-contents quarantine could not be synchronized.");
                }
                return NO;
            }
            continue;
        }
        BOOL destinationExists = NO;
        if (!PXOptionalRestoreNameState(participant.authority.descriptor,
                                        participant.destinationNameData,
                                        &destinationExists,
                                        NULL)) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorQuarantineFailed,
                                         @"$.transaction.quarantine",
                                         @"An optional destination could not be inspected before quarantine.");
        }
        if (participant.initiallyExisted) {
            if (!PXOptionalRestoreMoveNamedObject(participant.originalObject,
                                                  participant.authority.descriptor,
                                                  participant.destinationNameData,
                                                  participant.workspaceDescriptor,
                                                  PXOptionalRestoreNameData(PXOptionalRestoreOriginalName),
                                                  PXOptionalRestoreTransactionErrorQuarantineFailed,
                                                  @"$.transaction.quarantine",
                                                  @"An original optional object could not be quarantined.",
                                                  error)) return NO;
        } else if (destinationExists) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorQuarantineFailed,
                                         @"$.transaction.quarantine",
                                         @"An initially absent optional destination appeared before quarantine.");
        }
        BOOL remaining = NO;
        if (!PXOptionalRestoreNameState(participant.authority.descriptor,
                                        participant.destinationNameData,
                                        &remaining,
                                        NULL) || remaining ||
            !PXOptionalRestoreSyncDirectory(participant.authority.descriptor) ||
            !PXOptionalRestoreSyncDirectory(participant.workspaceDescriptor)) {
            return PXOptionalRestoreFail(error,
                                         PXOptionalRestoreTransactionErrorQuarantineFailed,
                                         @"$.transaction.quarantine",
                                         @"An optional object quarantine is inconsistent.");
        }
    }
    return PXOptionalRestoreWriteLeaderJournal(self.participants,
                                                self.transactionIdentifier,
                                                PXOptionalRestorePhaseQuarantined,
                                                error);
}

- (BOOL)installItemsWithError:(NSError **)error {
    for (PXOptionalRestoreParticipant *participant in PXOptionalRestoreManagerOrder(self.participants)) {
        if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents) {
            if (!PXOptionalRestoreMoveEntryList(participant.stagedEntries,
                                                participant.stageDescriptor,
                                                participant.authority.descriptor,
                                                PXOptionalRestoreTransactionErrorCommitFailed,
                                                @"$.transaction.commit",
                                                @"A staged directory-contents entry could not be installed.",
                                                error) ||
                !PXOptionalRestoreRequireExactEntries(participant.stageDescriptor,
                                                       @[], NO, NO, NO, NO,
                                                       PXOptionalRestoreTransactionErrorCommitFailed,
                                                       @"$.transaction.commit",
                                                       @"A directory-contents stage is not empty after install.",
                                                       error) ||
                !PXOptionalRestoreRequireInstalledState(participant, error) ||
                !PXOptionalRestoreSyncDirectory(participant.stageDescriptor) ||
                !PXOptionalRestoreSyncDirectory(participant.authority.descriptor)) {
                if (error && !*error) {
                    PXOptionalRestoreFail(error,
                                          PXOptionalRestoreTransactionErrorCommitFailed,
                                          @"$.transaction.commit",
                                          @"A directory-contents install could not be synchronized.");
                }
                return NO;
            }
            continue;
        }
        if (!PXOptionalRestoreMoveNamedObject(participant.replacementObject,
                                              participant.workspaceDescriptor,
                                              PXOptionalRestoreNameData(PXOptionalRestoreReplacementName),
                                              participant.authority.descriptor,
                                              participant.destinationNameData,
                                              PXOptionalRestoreTransactionErrorCommitFailed,
                                              @"$.transaction.commit",
                                              @"An optional replacement object could not be installed.",
                                              error) ||
            !PXOptionalRestoreRequireInstalledState(participant, error) ||
            !PXOptionalRestoreSyncDirectory(participant.workspaceDescriptor) ||
            !PXOptionalRestoreSyncDirectory(participant.authority.descriptor)) return NO;
    }
    return PXOptionalRestoreWriteLeaderJournal(self.participants,
                                                self.transactionIdentifier,
                                                PXOptionalRestorePhaseInstalled,
                                                error);
}

- (BOOL)publishCommittedDecisionWithError:(NSError **)error {
    for (PXOptionalRestoreAuthority *authority in self.authorities) {
        if (!PXOptionalRestoreAuthorityIdentityIsValid(authority, YES, error)) return NO;
    }
    for (PXOptionalRestoreParticipant *participant in self.participants) {
        if (!PXOptionalRestoreStageIdentityIsValid(participant, error) ||
            !PXOptionalRestoreRequireInstalledState(participant, error)) return NO;
        if (participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryContents ||
            participant.item.kind == PXOptionalRestoreTransactionItemKindDirectoryObject) {
            if (!PXOptionalRestoreRequireExactEntries(participant.stageDescriptor,
                                                       @[], NO, NO, NO, NO,
                                                       PXOptionalRestoreTransactionErrorCommitFailed,
                                                       @"$.transaction.commit",
                                                       @"An optional directory stage is not empty at commit decision.",
                                                       error)) return NO;
        }
    }
    if (!PXOptionalRestoreWriteLeaderJournal(self.participants,
                                             self.transactionIdentifier,
                                             PXOptionalRestorePhaseCommitted,
                                             error)) return NO;
    self.committed = YES;
    return YES;
}

- (BOOL)rollbackPreparedWithCleanupWarning:(NSError **)cleanupWarning
                                      error:(NSError **)error {
    return PXOptionalRestoreRollbackTransaction(self.participants,
                                                 self.transactionIdentifier,
                                                 &_rollbackPerformed,
                                                 &_rollbackComplete,
                                                 cleanupWarning,
                                                 error);
}

- (BOOL)commitWithCleanupWarning:(NSError **)cleanupWarning
                           error:(NSError **)error {
    if (cleanupWarning) *cleanupWarning = nil;
    if (error) *error = nil;
    if (self.attempted || self.committed || self.participants.count == 0) {
        return PXOptionalRestoreFail(error,
                                     PXOptionalRestoreTransactionErrorInvalidInput,
                                     @"$",
                                     @"The optional transaction is one-shot or invalid.");
    }
    self.attempted = YES;
    if (![self revalidatePreparedStateWithError:error] ||
        ![self prepareWorkspacesAndReplacementsWithError:error]) return NO;

    self.prepared = YES;
    NSError *operationError = nil;
    BOOL succeeded =
        PXOptionalRestoreWriteLeaderJournal(self.participants,
                                            self.transactionIdentifier,
                                            PXOptionalRestorePhasePrepared,
                                            &operationError) &&
        [self quarantineItemsWithError:&operationError] &&
        [self installItemsWithError:&operationError] &&
        [self publishCommittedDecisionWithError:&operationError];
    if (!succeeded) {
        NSError *rollbackError = nil;
        NSError *rollbackCleanupWarning = nil;
        if (![self rollbackPreparedWithCleanupWarning:&rollbackCleanupWarning
                                                 error:&rollbackError]) {
            if (error) {
                *error = rollbackError ?:
                    [NSError errorWithDomain:PXOptionalRestoreTransactionErrorDomain
                                         code:PXOptionalRestoreTransactionErrorRollbackFailed
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"The optional transaction could not be rolled back completely.",
                                         PXOptionalRestoreTransactionErrorFieldPathKey: @"$.transaction.rollback"
                                     }];
            }
            return NO;
        }
        if (cleanupWarning && rollbackCleanupWarning) *cleanupWarning = rollbackCleanupWarning;
        if (error) {
            *error = operationError ?:
                [NSError errorWithDomain:PXOptionalRestoreTransactionErrorDomain
                                     code:PXOptionalRestoreTransactionErrorCommitFailed
                                 userInfo:@{
                                     NSLocalizedDescriptionKey: @"The optional transaction failed before durable commit.",
                                     PXOptionalRestoreTransactionErrorFieldPathKey: @"$.transaction.commit"
                                 }];
        }
        return NO;
    }

    NSError *cleanupError = nil;
    if (!PXOptionalRestoreCleanupTransaction(self.participants, &cleanupError) && cleanupWarning) {
        *cleanupWarning = cleanupError;
    }
    return YES;
}

@end
