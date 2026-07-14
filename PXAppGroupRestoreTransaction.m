#import "PXAppGroupRestoreTransaction.h"
#import "PXAppGroupRestoreTargetPlan.h"
#import "PXMainDataStaging.h"
#import "PXResolvedContainer.h"
#import "PXDestructivePathValidator.h"
#import <Foundation/Foundation.h>
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

NSString * const PXAppGroupRestoreTransactionErrorDomain = @"PXAppGroupRestoreTransactionErrorDomain";
NSString * const PXAppGroupRestoreTransactionErrorFieldPathKey = @"PXAppGroupRestoreTransactionErrorFieldPathKey";

static NSString * const PXAppGroupRestoreTransactionPrefix = @".weaponx-app-group-restore-";
static NSString * const PXAppGroupRestoreOriginalDirectoryName = @"original";
static NSString * const PXAppGroupRestoreNewDirectoryName = @"new";
static NSString * const PXAppGroupRestoreJournalName = @"batch.plist";
static NSString * const PXAppGroupRestoreJournalTemporaryName = @"batch.tmp";

static NSString * const PXAppGroupRestorePhasePrepared = @"prepared";
static NSString * const PXAppGroupRestorePhaseQuarantined = @"quarantined";
static NSString * const PXAppGroupRestorePhaseInstalled = @"installed";
static NSString * const PXAppGroupRestorePhaseCommitted = @"committed";
static NSString * const PXAppGroupRestorePhaseRollingBack = @"rolling-back";
static NSString * const PXAppGroupRestorePhaseRolledBack = @"rolled-back";

static const NSUInteger PXAppGroupRestoreMaximumTargets = 256;
static const NSUInteger PXAppGroupRestoreMaximumTopLevelEntries = 100000;
static const NSUInteger PXAppGroupRestoreMaximumAggregateEntries = 500000;
static const NSUInteger PXAppGroupRestoreMaximumCleanupEntries = 500000;
static const NSUInteger PXAppGroupRestoreMaximumCleanupDepth = 2048;
static const NSUInteger PXAppGroupRestoreMaximumComponentBytes = 255;
static const NSUInteger PXAppGroupRestoreMaximumJournalBytes = 128 * 1024 * 1024;
static const NSUInteger PXAppGroupRestoreMaximumStaleBatchIdentifiers = 1;
static const NSUInteger PXAppGroupRestoreMaximumWorkspaceEntries = 4;

static BOOL PXAppGroupRestoreFail(NSError **error,
                                  PXAppGroupRestoreTransactionErrorCode code,
                                  NSString *fieldPath,
                                  NSString *description) {
    if (error) {
        *error = [NSError errorWithDomain:PXAppGroupRestoreTransactionErrorDomain
                                     code:code
                                 userInfo:@{
                                     NSLocalizedDescriptionKey: description,
                                     PXAppGroupRestoreTransactionErrorFieldPathKey: fieldPath
                                 }];
    }
    return NO;
}

static id PXAppGroupRestoreFailObject(NSError **error,
                                      PXAppGroupRestoreTransactionErrorCode code,
                                      NSString *fieldPath,
                                      NSString *description) {
    PXAppGroupRestoreFail(error, code, fieldPath, description);
    return nil;
}

static BOOL PXAppGroupRestoreReadUnsignedIntegralNumber(id value,
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

static void PXAppGroupRestoreCloseDescriptor(int *descriptor) {
    if (descriptor && *descriptor >= 0) {
        close(*descriptor);
        *descriptor = -1;
    }
}

static BOOL PXAppGroupRestoreSetCloseOnExec(int descriptor) {
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

static int PXAppGroupRestoreDuplicateDescriptor(int descriptor) {
    int duplicate = dup(descriptor);
    if (duplicate < 0) {
        return -1;
    }
    if (!PXAppGroupRestoreSetCloseOnExec(duplicate)) {
        close(duplicate);
        return -1;
    }
    return duplicate;
}

static BOOL PXAppGroupRestoreSyncDescriptor(int descriptor) {
    int result = -1;
    do {
        result = fsync(descriptor);
    } while (result != 0 && errno == EINTR);
    return result == 0;
}

static BOOL PXAppGroupRestoreSyncDirectory(int descriptor) {
    return PXAppGroupRestoreSyncDescriptor(descriptor);
}

static BOOL PXAppGroupRestoreStatIdentityMatches(const struct stat *expected,
                                                 const struct stat *actual) {
    return expected && actual &&
           expected->st_dev == actual->st_dev &&
           expected->st_ino == actual->st_ino &&
           ((expected->st_mode & S_IFMT) == (actual->st_mode & S_IFMT));
}

static NSComparisonResult PXAppGroupRestoreCompareRawNames(NSData *left, NSData *right) {
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

static char *PXAppGroupRestoreCopyTerminatedName(NSData *nameData) {
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

static NSData *PXAppGroupRestoreNameData(NSString *name) {
    return [name dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
}

static BOOL PXAppGroupRestoreRawNameEquals(NSData *nameData, NSString *name) {
    NSData *expected = PXAppGroupRestoreNameData(name);
    return expected && [nameData isEqualToData:expected];
}

static BOOL PXAppGroupRestoreRawNameHasPrefix(NSData *nameData, NSString *prefix) {
    NSData *prefixData = PXAppGroupRestoreNameData(prefix);
    if (!prefixData || nameData.length < prefixData.length) {
        return NO;
    }
    return prefixData.length == 0 ||
           memcmp(nameData.bytes, prefixData.bytes, prefixData.length) == 0;
}

static BOOL PXAppGroupRestoreNameIsSafe(NSData *nameData) {
    if (![nameData isKindOfClass:[NSData class]] ||
        nameData.length == 0 ||
        nameData.length > PXAppGroupRestoreMaximumComponentBytes) {
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

static BOOL PXAppGroupRestoreNameIsContainerMetadata(NSData *nameData) {
    return PXAppGroupRestoreRawNameEquals(nameData,
                                          @".com.apple.mobile_container_manager.metadata.plist") ||
           PXAppGroupRestoreRawNameEquals(nameData,
                                          @".com.apple.containermanagerd.metadata.plist");
}

static NSArray<NSData *> *PXAppGroupRestoreReadDirectoryNames(int descriptor,
                                                              NSUInteger maximumNameCount,
                                                              NSError **error,
                                                              NSString *fieldPath) {
    int enumerationDescriptor = PXAppGroupRestoreDuplicateDescriptor(descriptor);
    if (enumerationDescriptor < 0 ||
        lseek(enumerationDescriptor, 0, SEEK_SET) < 0) {
        if (enumerationDescriptor >= 0) {
            close(enumerationDescriptor);
        }
        return PXAppGroupRestoreFailObject(error,
                                           PXAppGroupRestoreTransactionErrorFilesystemInspectionFailed,
                                           fieldPath,
                                           @"A directory enumeration descriptor could not be prepared.");
    }

    DIR *directory = fdopendir(enumerationDescriptor);
    if (!directory) {
        close(enumerationDescriptor);
        return PXAppGroupRestoreFailObject(error,
                                           PXAppGroupRestoreTransactionErrorFilesystemInspectionFailed,
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
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorEntryLimitExceeded,
                                               fieldPath,
                                               @"A transaction directory entry limit was exceeded.");
        }
        size_t length = strlen(name);
        NSData *nameData = [NSData dataWithBytes:name length:length];
        if (!PXAppGroupRestoreNameIsSafe(nameData)) {
            closedir(directory);
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorFilesystemInspectionFailed,
                                               fieldPath,
                                               @"A transaction directory contains an unsafe entry name.");
        }
        [names addObject:nameData];
    }

    if (closedir(directory) != 0 && enumerationError == 0) {
        enumerationError = errno ?: EIO;
    }
    if (enumerationError != 0) {
        return PXAppGroupRestoreFailObject(error,
                                           PXAppGroupRestoreTransactionErrorFilesystemInspectionFailed,
                                           fieldPath,
                                           @"Directory enumeration did not complete safely.");
    }

    return [names sortedArrayUsingComparator:^NSComparisonResult(NSData *left, NSData *right) {
        return PXAppGroupRestoreCompareRawNames(left, right);
    }];
}

static BOOL PXAppGroupRestorePathMatchesDescriptor(NSString *path, int descriptor) {
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

static BOOL PXAppGroupRestoreNameState(int descriptor,
                                       NSData *nameData,
                                       BOOL *existsOut,
                                       struct stat *statOut) {
    if (existsOut) {
        *existsOut = NO;
    }
    char *name = PXAppGroupRestoreCopyTerminatedName(nameData);
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

@interface PXAppGroupRestoreEntry : NSObject
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

@implementation PXAppGroupRestoreEntry

+ (instancetype)entryForNameData:(NSData *)nameData
                      descriptor:(int)descriptor
                           error:(NSError **)error
                       fieldPath:(NSString *)fieldPath {
    if (!PXAppGroupRestoreNameIsSafe(nameData)) {
        return PXAppGroupRestoreFailObject(error,
                                           PXAppGroupRestoreTransactionErrorFilesystemInspectionFailed,
                                           fieldPath,
                                           @"A transaction entry name is invalid.");
    }
    BOOL exists = NO;
    struct stat value;
    memset(&value, 0, sizeof(value));
    if (!PXAppGroupRestoreNameState(descriptor, nameData, &exists, &value) || !exists) {
        return PXAppGroupRestoreFailObject(error,
                                           PXAppGroupRestoreTransactionErrorFilesystemChanged,
                                           fieldPath,
                                           @"A planned transaction entry changed before inspection completed.");
    }
    PXAppGroupRestoreEntry *entry = [[self alloc] init];
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
        return PXAppGroupRestoreFailObject(error,
                                           PXAppGroupRestoreTransactionErrorJournalInvalid,
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
    if (!PXAppGroupRestoreNameIsSafe(nameData) ||
        !PXAppGroupRestoreReadUnsignedIntegralNumber(device, &deviceValue) ||
        !PXAppGroupRestoreReadUnsignedIntegralNumber(inode, &inodeValue) ||
        !PXAppGroupRestoreReadUnsignedIntegralNumber(modeType, &modeValue)) {
        return PXAppGroupRestoreFailObject(error,
                                           PXAppGroupRestoreTransactionErrorJournalInvalid,
                                           fieldPath,
                                           @"A transaction journal entry is invalid.");
    }
    if (inodeValue == 0 || modeValue > UINT_MAX || (modeValue & S_IFMT) == 0) {
        return PXAppGroupRestoreFailObject(error,
                                           PXAppGroupRestoreTransactionErrorJournalInvalid,
                                           fieldPath,
                                           @"A transaction journal entry identity is invalid.");
    }
    PXAppGroupRestoreEntry *entry = [[self alloc] init];
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

static NSArray<PXAppGroupRestoreEntry *> *PXAppGroupRestoreCollectEntries(
    int descriptor,
    BOOL rejectContainerMetadata,
    BOOL rejectTransactionPrefix,
    BOOL skipContainerMetadata,
    BOOL skipTransactionPrefix,
    NSError **error,
    NSString *fieldPath) {
    NSArray<NSData *> *names =
        PXAppGroupRestoreReadDirectoryNames(descriptor,
                                            PXAppGroupRestoreMaximumTopLevelEntries,
                                            error,
                                            fieldPath);
    if (!names) {
        return nil;
    }
    NSMutableArray<PXAppGroupRestoreEntry *> *entries =
        [NSMutableArray arrayWithCapacity:names.count];
    for (NSData *nameData in names) {
        BOOL metadata = PXAppGroupRestoreNameIsContainerMetadata(nameData);
        BOOL transactionName =
            PXAppGroupRestoreRawNameHasPrefix(nameData, PXAppGroupRestoreTransactionPrefix);
        if ((rejectContainerMetadata && metadata) ||
            (rejectTransactionPrefix && transactionName)) {
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorFilesystemInspectionFailed,
                                               fieldPath,
                                               @"A reserved transaction entry name is present.");
        }
        if ((skipContainerMetadata && metadata) ||
            (skipTransactionPrefix && transactionName)) {
            continue;
        }
        PXAppGroupRestoreEntry *entry =
            [PXAppGroupRestoreEntry entryForNameData:nameData
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

static BOOL PXAppGroupRestoreEntryArraysMatch(NSArray<PXAppGroupRestoreEntry *> *expected,
                                               NSArray<PXAppGroupRestoreEntry *> *actual) {
    if (expected.count != actual.count) {
        return NO;
    }
    for (NSUInteger index = 0; index < expected.count; index++) {
        PXAppGroupRestoreEntry *left = expected[index];
        PXAppGroupRestoreEntry *right = actual[index];
        if (![left.nameData isEqualToData:right.nameData] ||
            left.device != right.device ||
            left.inode != right.inode ||
            left.modeType != right.modeType) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXAppGroupRestoreRequireExactEntries(
    int descriptor,
    NSArray<PXAppGroupRestoreEntry *> *expectedEntries,
    BOOL rejectContainerMetadata,
    BOOL rejectTransactionPrefix,
    BOOL skipContainerMetadata,
    BOOL skipTransactionPrefix,
    PXAppGroupRestoreTransactionErrorCode code,
    NSString *fieldPath,
    NSString *description,
    NSError **error) {
    NSError *inspectionError = nil;
    NSArray<PXAppGroupRestoreEntry *> *actualEntries =
        PXAppGroupRestoreCollectEntries(descriptor,
                                        rejectContainerMetadata,
                                        rejectTransactionPrefix,
                                        skipContainerMetadata,
                                        skipTransactionPrefix,
                                        &inspectionError,
                                        fieldPath);
    if (!actualEntries ||
        !PXAppGroupRestoreEntryArraysMatch(expectedEntries, actualEntries)) {
        return PXAppGroupRestoreFail(error,
                                     code,
                                     fieldPath,
                                     description);
    }
    return YES;
}

static BOOL PXAppGroupRestoreEntryMatchesAt(PXAppGroupRestoreEntry *entry,
                                             int descriptor,
                                             BOOL *existsOut) {
    BOOL exists = NO;
    struct stat value;
    memset(&value, 0, sizeof(value));
    if (!PXAppGroupRestoreNameState(descriptor, entry.nameData, &exists, &value)) {
        return NO;
    }
    if (existsOut) {
        *existsOut = exists;
    }
    return !exists || [entry matchesStat:&value];
}

@interface PXAppGroupRestoreCleanupFrame : NSObject
@property (nonatomic, assign) int descriptor;
@property (nonatomic, copy) NSArray<NSData *> *names;
@property (nonatomic, assign) NSUInteger nextIndex;
@property (nonatomic, copy, nullable) NSData *entryName;
@end

@implementation PXAppGroupRestoreCleanupFrame
- (instancetype)init {
    self = [super init];
    if (self) {
        _descriptor = -1;
    }
    return self;
}
- (void)dealloc {
    PXAppGroupRestoreCloseDescriptor(&_descriptor);
}
@end

static BOOL PXAppGroupRestoreRemoveDirectoryContents(int rootDescriptor,
                                                      NSError **error,
                                                      NSString *fieldPath) {
    struct stat rootStat;
    memset(&rootStat, 0, sizeof(rootStat));
    if (fstat(rootDescriptor, &rootStat) != 0 || !S_ISDIR(rootStat.st_mode)) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorCleanupFailed,
                                     fieldPath,
                                     @"A transaction cleanup root could not be inspected.");
    }
    NSArray<NSData *> *rootNames =
        PXAppGroupRestoreReadDirectoryNames(rootDescriptor,
                                            PXAppGroupRestoreMaximumCleanupEntries,
                                            error,
                                            fieldPath);
    if (!rootNames) {
        return NO;
    }
    int rootDuplicate = PXAppGroupRestoreDuplicateDescriptor(rootDescriptor);
    if (rootDuplicate < 0) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorCleanupFailed,
                                     fieldPath,
                                     @"A transaction cleanup descriptor could not be prepared.");
    }

    PXAppGroupRestoreCleanupFrame *rootFrame = [[PXAppGroupRestoreCleanupFrame alloc] init];
    rootFrame.descriptor = rootDuplicate;
    rootFrame.names = rootNames;
    NSMutableArray<PXAppGroupRestoreCleanupFrame *> *stack = [NSMutableArray arrayWithObject:rootFrame];
    NSUInteger visited = 0;

    while (stack.count > 0) {
        PXAppGroupRestoreCleanupFrame *frame = stack.lastObject;
        if (frame.nextIndex >= frame.names.count) {
            NSData *entryName = frame.entryName;
            [stack removeLastObject];
            if (entryName && stack.count > 0) {
                PXAppGroupRestoreCleanupFrame *parent = stack.lastObject;
                char *name = PXAppGroupRestoreCopyTerminatedName(entryName);
                if (!name || unlinkat(parent.descriptor, name, AT_REMOVEDIR) != 0) {
                    free(name);
                    return PXAppGroupRestoreFail(error,
                                                 PXAppGroupRestoreTransactionErrorCleanupFailed,
                                                 fieldPath,
                                                 @"A transaction cleanup directory could not be removed.");
                }
                free(name);
            }
            continue;
        }

        if (stack.count > PXAppGroupRestoreMaximumCleanupDepth ||
            visited >= PXAppGroupRestoreMaximumCleanupEntries) {
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorEntryLimitExceeded,
                                         fieldPath,
                                         @"A transaction cleanup limit was exceeded.");
        }

        NSData *nameData = frame.names[frame.nextIndex++];
        visited++;
        char *name = PXAppGroupRestoreCopyTerminatedName(nameData);
        if (!name) {
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorCleanupFailed,
                                         fieldPath,
                                         @"A transaction cleanup entry name could not be prepared.");
        }
        struct stat before;
        memset(&before, 0, sizeof(before));
        if (fstatat(frame.descriptor, name, &before, AT_SYMLINK_NOFOLLOW) != 0) {
            free(name);
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorCleanupFailed,
                                         fieldPath,
                                         @"A transaction cleanup entry could not be inspected.");
        }

        if (!S_ISDIR(before.st_mode)) {
            int unlinkResult = unlinkat(frame.descriptor, name, 0);
            free(name);
            if (unlinkResult != 0) {
                return PXAppGroupRestoreFail(error,
                                             PXAppGroupRestoreTransactionErrorCleanupFailed,
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
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorCleanupFailed,
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
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorFilesystemChanged,
                                         fieldPath,
                                         @"A transaction cleanup directory changed during traversal.");
        }
        NSUInteger remaining = PXAppGroupRestoreMaximumCleanupEntries - visited;
        NSArray<NSData *> *childNames =
            PXAppGroupRestoreReadDirectoryNames(childDescriptor,
                                                remaining,
                                                error,
                                                fieldPath);
        if (!childNames) {
            close(childDescriptor);
            return NO;
        }
        PXAppGroupRestoreCleanupFrame *child = [[PXAppGroupRestoreCleanupFrame alloc] init];
        child.descriptor = childDescriptor;
        child.names = childNames;
        child.entryName = nameData;
        [stack addObject:child];
    }
    return YES;
}

static BOOL PXAppGroupRestoreWriteAll(int descriptor, const void *bytes, size_t length) {
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

static NSData *PXAppGroupRestoreReadAll(int descriptor,
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
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorJournalInvalid,
                                               fieldPath,
                                               @"A transaction journal could not be read.");
        }
        if (count == 0) {
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorJournalInvalid,
                                               fieldPath,
                                               @"A transaction journal ended unexpectedly.");
        }
        cursor += (size_t)count;
        remaining -= (size_t)count;
    }
    return data;
}

static BOOL PXAppGroupRestorePhaseIsValid(NSString *phase) {
    return [phase isEqualToString:PXAppGroupRestorePhasePrepared] ||
           [phase isEqualToString:PXAppGroupRestorePhaseQuarantined] ||
           [phase isEqualToString:PXAppGroupRestorePhaseInstalled] ||
           [phase isEqualToString:PXAppGroupRestorePhaseCommitted] ||
           [phase isEqualToString:PXAppGroupRestorePhaseRollingBack] ||
           [phase isEqualToString:PXAppGroupRestorePhaseRolledBack];
}

static NSArray<PXAppGroupRestoreEntry *> *PXAppGroupRestoreParseJournalEntries(
    id value,
    NSError **error,
    NSString *fieldPath) {
    if (![value isKindOfClass:[NSArray class]] ||
        [(NSArray *)value count] > PXAppGroupRestoreMaximumTopLevelEntries) {
        return PXAppGroupRestoreFailObject(error,
                                           PXAppGroupRestoreTransactionErrorJournalInvalid,
                                           fieldPath,
                                           @"A transaction journal entry list is invalid.");
    }
    NSMutableArray<PXAppGroupRestoreEntry *> *entries =
        [NSMutableArray arrayWithCapacity:[(NSArray *)value count]];
    NSMutableSet<NSData *> *names = [NSMutableSet set];
    for (id object in (NSArray *)value) {
        PXAppGroupRestoreEntry *entry =
            [PXAppGroupRestoreEntry entryFromJournalObject:object
                                                     error:error
                                                 fieldPath:fieldPath];
        if (!entry) {
            return nil;
        }
        if ([names containsObject:entry.nameData] ||
            PXAppGroupRestoreNameIsContainerMetadata(entry.nameData) ||
            PXAppGroupRestoreRawNameHasPrefix(entry.nameData,
                                              PXAppGroupRestoreTransactionPrefix)) {
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorJournalInvalid,
                                               fieldPath,
                                               @"A transaction journal contains a duplicate or reserved entry.");
        }
        [names addObject:entry.nameData];
        [entries addObject:entry];
    }
    return [entries copy];
}
static int PXAppGroupRestoreOpenDirectoryAt(int parentDescriptor,
                                             NSString *name,
                                             BOOL *existsOut) {
    if (existsOut) {
        *existsOut = NO;
    }
    NSData *nameData = PXAppGroupRestoreNameData(name);
    char *rawName = PXAppGroupRestoreCopyTerminatedName(nameData);
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

static BOOL PXAppGroupRestoreRemoveNamedDirectoryIfPresent(int parentDescriptor,
                                                            NSString *name,
                                                            NSError **error,
                                                            NSString *fieldPath) {
    BOOL exists = NO;
    int descriptor = PXAppGroupRestoreOpenDirectoryAt(parentDescriptor, name, &exists);
    if (descriptor < 0) {
        if (!exists && errno == ENOENT) {
            return YES;
        }
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorCleanupFailed,
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
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorCleanupFailed,
                                     fieldPath,
                                     @"A transaction cleanup directory crosses a filesystem boundary.");
    }
    BOOL removedContents =
        PXAppGroupRestoreRemoveDirectoryContents(descriptor, error, fieldPath);
    close(descriptor);
    if (!removedContents) {
        return NO;
    }
    NSData *nameData = PXAppGroupRestoreNameData(name);
    char *rawName = PXAppGroupRestoreCopyTerminatedName(nameData);
    if (!rawName || unlinkat(parentDescriptor, rawName, AT_REMOVEDIR) != 0) {
        free(rawName);
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorCleanupFailed,
                                     fieldPath,
                                     @"A transaction cleanup directory could not be removed.");
    }
    free(rawName);
    return YES;
}
static BOOL PXAppGroupRestoreMoveEntry(PXAppGroupRestoreEntry *entry,
                                       int sourceDescriptor,
                                       int destinationDescriptor,
                                       NSError **error,
                                       PXAppGroupRestoreTransactionErrorCode code,
                                       NSString *fieldPath,
                                       NSString *description) {
    BOOL sourceExists = NO;
    BOOL destinationExists = NO;
    if (!PXAppGroupRestoreEntryMatchesAt(entry, sourceDescriptor, &sourceExists) ||
        !sourceExists ||
        !PXAppGroupRestoreNameState(destinationDescriptor,
                                    entry.nameData,
                                    &destinationExists,
                                    NULL) ||
        destinationExists) {
        return PXAppGroupRestoreFail(error, code, fieldPath, description);
    }
    char *name = PXAppGroupRestoreCopyTerminatedName(entry.nameData);
    if (!name ||
        renameat(sourceDescriptor, name, destinationDescriptor, name) != 0) {
        free(name);
        return PXAppGroupRestoreFail(error, code, fieldPath, description);
    }
    free(name);
    BOOL movedExists = NO;
    if (!PXAppGroupRestoreEntryMatchesAt(entry, destinationDescriptor, &movedExists) ||
        !movedExists) {
        return PXAppGroupRestoreFail(error, code, fieldPath, description);
    }
    return YES;
}

static BOOL PXAppGroupRestoreMoveInstalledEntriesToNew(
    NSArray<PXAppGroupRestoreEntry *> *originalEntries,
    NSArray<PXAppGroupRestoreEntry *> *stagedEntries,
    int targetDescriptor,
    int newDescriptor,
    NSError **error) {
    NSMutableDictionary<NSData *, PXAppGroupRestoreEntry *> *originalEntriesByName =
        [NSMutableDictionary dictionaryWithCapacity:originalEntries.count];
    for (PXAppGroupRestoreEntry *originalEntry in originalEntries) {
        originalEntriesByName[originalEntry.nameData] = originalEntry;
    }

    for (PXAppGroupRestoreEntry *entry in stagedEntries.reverseObjectEnumerator) {
        BOOL targetExists = NO;
        BOOL newExists = NO;
        struct stat targetStat;
        struct stat newStat;
        memset(&targetStat, 0, sizeof(targetStat));
        memset(&newStat, 0, sizeof(newStat));
        if (!PXAppGroupRestoreNameState(targetDescriptor,
                                        entry.nameData,
                                        &targetExists,
                                        &targetStat) ||
            !PXAppGroupRestoreNameState(newDescriptor,
                                        entry.nameData,
                                        &newExists,
                                        &newStat)) {
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorRollbackFailed,
                                         @"$.transaction.rollback.new",
                                         @"A newly installed App Group entry could not be inspected during rollback.");
        }

        BOOL targetIsStagedEntry = targetExists && [entry matchesStat:&targetStat];
        BOOL newIsStagedEntry = newExists && [entry matchesStat:&newStat];
        PXAppGroupRestoreEntry *originalEntry = originalEntriesByName[entry.nameData];
        BOOL targetIsOriginalEntry =
            targetExists && originalEntry && [originalEntry matchesStat:&targetStat];

        if ((targetExists && !targetIsStagedEntry && !targetIsOriginalEntry) ||
            (newExists && !newIsStagedEntry) ||
            (targetIsStagedEntry && newIsStagedEntry)) {
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorRollbackFailed,
                                         @"$.transaction.rollback.new",
                                         @"A App Group entry has an inconsistent rollback identity.");
        }
        if (!targetIsStagedEntry) {
            continue;
        }
        if (!PXAppGroupRestoreMoveEntry(entry,
                                        targetDescriptor,
                                        newDescriptor,
                                        error,
                                        PXAppGroupRestoreTransactionErrorRollbackFailed,
                                        @"$.transaction.rollback.new",
                                        @"A newly installed App Group entry could not be quarantined during rollback.")) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXAppGroupRestoreRestoreOriginalEntries(
    NSArray<PXAppGroupRestoreEntry *> *originalEntries,
    int originalDescriptor,
    int targetDescriptor,
    NSError **error) {
    for (PXAppGroupRestoreEntry *entry in originalEntries.reverseObjectEnumerator) {
        BOOL originalExists = NO;
        BOOL targetExists = NO;
        if (!PXAppGroupRestoreEntryMatchesAt(entry, originalDescriptor, &originalExists) ||
            !PXAppGroupRestoreEntryMatchesAt(entry, targetDescriptor, &targetExists)) {
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorRollbackFailed,
                                         @"$.transaction.rollback.original",
                                         @"An original App Group entry changed before rollback.");
        }
        if (originalExists && targetExists) {
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorRollbackFailed,
                                         @"$.transaction.rollback.original",
                                         @"An original App Group entry exists in two rollback locations.");
        }
        if (!originalExists) {
            if (!targetExists) {
                return PXAppGroupRestoreFail(error,
                                             PXAppGroupRestoreTransactionErrorRollbackFailed,
                                             @"$.transaction.rollback.original",
                                             @"An original App Group entry is missing during rollback.");
            }
            continue;
        }
        if (!PXAppGroupRestoreMoveEntry(entry,
                                        originalDescriptor,
                                        targetDescriptor,
                                        error,
                                        PXAppGroupRestoreTransactionErrorRollbackFailed,
                                        @"$.transaction.rollback.original",
                                        @"An original App Group entry could not be restored during rollback.")) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXAppGroupRestoreRollbackEntries(
    NSArray<PXAppGroupRestoreEntry *> *originalEntries,
    NSArray<PXAppGroupRestoreEntry *> *stagedEntries,
    int targetDescriptor,
    int originalDescriptor,
    int newDescriptor,
    NSError **error) {
    if (!PXAppGroupRestoreMoveInstalledEntriesToNew(originalEntries,
                                                    stagedEntries,
                                                    targetDescriptor,
                                                    newDescriptor,
                                                    error) ||
        !PXAppGroupRestoreRestoreOriginalEntries(originalEntries,
                                                 originalDescriptor,
                                                 targetDescriptor,
                                                 error) ||
        !PXAppGroupRestoreRequireExactEntries(
            targetDescriptor,
            originalEntries,
            NO,
            NO,
            YES,
            YES,
            PXAppGroupRestoreTransactionErrorRollbackFailed,
            @"$.transaction.rollback",
            @"The restored App Group namespace does not match the original journal.",
            error) ||
        !PXAppGroupRestoreSyncDirectory(targetDescriptor) ||
        !PXAppGroupRestoreSyncDirectory(originalDescriptor) ||
        !PXAppGroupRestoreSyncDirectory(newDescriptor)) {
        if (error && !*error) {
            PXAppGroupRestoreFail(error,
                                  PXAppGroupRestoreTransactionErrorRollbackFailed,
                                  @"$.transaction.rollback",
                                  @"The App Group rollback could not be synchronized.");
        }
        return NO;
    }
    return YES;
}

@interface PXAppGroupRestoreParticipant : NSObject
@property (nonatomic, strong) PXAppGroupRestoreTarget *target;
@property (nonatomic, strong) PXValidatedMainDataStage *stage;
@property (nonatomic, copy) NSString *canonicalPath;
@property (nonatomic, copy) NSData *canonicalBytes;
@property (nonatomic, copy) NSString *stagePath;
@property (nonatomic, assign) NSUInteger planOrder;
@property (nonatomic, assign) NSUInteger lockOrdinal;
@property (nonatomic, assign) int targetDescriptor;
@property (nonatomic, assign) int lockDescriptor;
@property (nonatomic, assign) int stageDescriptor;
@property (nonatomic, assign) int workspaceDescriptor;
@property (nonatomic, assign) int originalDescriptor;
@property (nonatomic, assign) int newDescriptor;
@property (nonatomic, assign) struct stat targetStat;
@property (nonatomic, assign) struct stat lockStat;
@property (nonatomic, assign) struct stat stageStat;
@property (nonatomic, copy) NSArray<PXAppGroupRestoreEntry *> *originalEntries;
@property (nonatomic, copy) NSArray<PXAppGroupRestoreEntry *> *stagedEntries;
@property (nonatomic, copy, nullable) NSData *workspaceNameData;
@end

@implementation PXAppGroupRestoreParticipant
- (instancetype)init {
    self = [super init];
    if (self) {
        _targetDescriptor = -1;
        _lockDescriptor = -1;
        _stageDescriptor = -1;
        _workspaceDescriptor = -1;
        _originalDescriptor = -1;
        _newDescriptor = -1;
    }
    return self;
}
- (void)dealloc {
    PXAppGroupRestoreCloseDescriptor(&_newDescriptor);
    PXAppGroupRestoreCloseDescriptor(&_originalDescriptor);
    PXAppGroupRestoreCloseDescriptor(&_workspaceDescriptor);
    PXAppGroupRestoreCloseDescriptor(&_stageDescriptor);
    PXAppGroupRestoreCloseDescriptor(&_targetDescriptor);
    PXAppGroupRestoreCloseDescriptor(&_lockDescriptor);
}
@end

static void PXAppGroupRestoreCloseWorkspaceDescriptors(PXAppGroupRestoreParticipant *participant) {
    if (participant.newDescriptor >= 0) {
        close(participant.newDescriptor);
        participant.newDescriptor = -1;
    }
    if (participant.originalDescriptor >= 0) {
        close(participant.originalDescriptor);
        participant.originalDescriptor = -1;
    }
    if (participant.workspaceDescriptor >= 0) {
        close(participant.workspaceDescriptor);
        participant.workspaceDescriptor = -1;
    }
}

static void PXAppGroupRestoreCloseAllDescriptors(NSArray<PXAppGroupRestoreParticipant *> *participants) {
    for (PXAppGroupRestoreParticipant *participant in participants) {
        PXAppGroupRestoreCloseWorkspaceDescriptors(participant);
        if (participant.stageDescriptor >= 0) {
            close(participant.stageDescriptor);
            participant.stageDescriptor = -1;
        }
        if (participant.targetDescriptor >= 0) {
            close(participant.targetDescriptor);
            participant.targetDescriptor = -1;
        }
        if (participant.lockDescriptor >= 0) {
            close(participant.lockDescriptor);
            participant.lockDescriptor = -1;
        }
    }
}

static BOOL PXAppGroupRestoreCanonicalBytesAreValid(NSData *bytes) {
    if (![bytes isKindOfClass:[NSData class]] || bytes.length == 0) {
        return NO;
    }
    const unsigned char *cursor = bytes.bytes;
    for (NSUInteger index = 0; index < bytes.length; index++) {
        if (cursor[index] == 0) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXAppGroupRestoreStringArrayIsValid(NSArray *values) {
    if (![values isKindOfClass:[NSArray class]] || values.count == 0) {
        return NO;
    }
    for (id value in values) {
        if (![value isKindOfClass:[NSString class]] || [(NSString *)value length] == 0) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXAppGroupRestoreValidateTargetModels(PXAppGroupRestoreParticipant *participant,
                                                   NSError **error) {
    if (![participant.target isKindOfClass:[PXAppGroupRestoreTarget class]] ||
        participant.canonicalPath.length == 0 ||
        ![participant.target.containerModels isKindOfClass:[NSArray class]] ||
        participant.target.containerModels.count == 0 ||
        !PXAppGroupRestoreStringArrayIsValid(participant.target.groupIdentifiers)) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorTargetValidationFailed,
                                     @"$.target",
                                     @"An exact App Group restore target is invalid.");
    }
    PXDestructivePathValidator *validator = [[PXDestructivePathValidator alloc] init];
    for (id model in participant.target.containerModels) {
        if (![model isKindOfClass:[PXResolvedContainer class]]) {
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorTargetValidationFailed,
                                         @"$.target",
                                         @"An exact App Group restore target model is invalid.");
        }
        NSError *validationError = nil;
        NSString *validatedPath =
            [validator validatedCanonicalPathForContainer:(PXResolvedContainer *)model
                                                     error:&validationError];
        if (validationError ||
            validatedPath.length == 0 ||
            ![validatedPath isEqualToString:participant.canonicalPath]) {
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorTargetValidationFailed,
                                         @"$.target",
                                         @"An exact App Group restore target could not be revalidated.");
        }
    }
    return YES;
}

static BOOL PXAppGroupRestoreParticipantIdentityIsValid(PXAppGroupRestoreParticipant *participant,
                                                         BOOL requireLock,
                                                         BOOL requireStage,
                                                         NSError **error) {
    struct stat targetNow;
    struct stat lockNow;
    struct stat stageNow;
    struct stat expectedTarget = participant.targetStat;
    struct stat expectedLock = participant.lockStat;
    struct stat expectedStage = participant.stageStat;
    memset(&targetNow, 0, sizeof(targetNow));
    memset(&lockNow, 0, sizeof(lockNow));
    memset(&stageNow, 0, sizeof(stageNow));
    if (!PXAppGroupRestoreValidateTargetModels(participant, error) ||
        !PXAppGroupRestorePathMatchesDescriptor(participant.canonicalPath,
                                                participant.targetDescriptor) ||
        !PXAppGroupRestorePathMatchesDescriptor(participant.canonicalPath,
                                                participant.lockDescriptor) ||
        fstat(participant.targetDescriptor, &targetNow) != 0 ||
        fstat(participant.lockDescriptor, &lockNow) != 0 ||
        !S_ISDIR(targetNow.st_mode) ||
        !S_ISDIR(lockNow.st_mode) ||
        !PXAppGroupRestoreStatIdentityMatches(&expectedTarget, &targetNow) ||
        !PXAppGroupRestoreStatIdentityMatches(&expectedLock, &lockNow) ||
        targetNow.st_dev != lockNow.st_dev ||
        targetNow.st_ino != lockNow.st_ino) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorTargetValidationFailed,
                                     @"$.target",
                                     @"An App Group target or lock identity changed.");
    }
    if (requireLock && flock(participant.lockDescriptor, LOCK_EX | LOCK_NB) != 0) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorLockFailed,
                                     @"$.locks",
                                     @"An App Group transaction lock is no longer retained.");
    }
    if (requireStage) {
        if (!PXAppGroupRestorePathMatchesDescriptor(participant.stagePath,
                                                    participant.stageDescriptor) ||
            fstat(participant.stageDescriptor, &stageNow) != 0 ||
            !S_ISDIR(stageNow.st_mode) ||
            !PXAppGroupRestoreStatIdentityMatches(&expectedStage, &stageNow) ||
            stageNow.st_dev != targetNow.st_dev) {
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorFilesystemChanged,
                                         @"$.stage",
                                         @"A validated App Group stage identity changed.");
        }
    }
    return YES;
}

static NSString *PXAppGroupRestoreWorkspaceName(NSString *batchIdentifier,
                                                 NSUInteger ordinal) {
    if (![batchIdentifier isKindOfClass:[NSString class]] ||
        batchIdentifier.length != 36 ||
        ordinal >= PXAppGroupRestoreMaximumTargets) {
        return nil;
    }
    return [NSString stringWithFormat:@"%@%@-%03lu",
            PXAppGroupRestoreTransactionPrefix,
            batchIdentifier,
            (unsigned long)ordinal];
}

static BOOL PXAppGroupRestoreParseWorkspaceName(NSData *nameData,
                                                 NSString **batchIdentifierOut,
                                                 NSUInteger *ordinalOut) {
    if (!PXAppGroupRestoreNameIsSafe(nameData) ||
        !PXAppGroupRestoreRawNameHasPrefix(nameData, PXAppGroupRestoreTransactionPrefix)) {
        return NO;
    }
    NSString *name = [[NSString alloc] initWithData:nameData encoding:NSUTF8StringEncoding];
    NSData *roundTrip = PXAppGroupRestoreNameData(name);
    if (!name || !roundTrip || ![roundTrip isEqualToData:nameData]) {
        return NO;
    }
    NSUInteger prefixLength = PXAppGroupRestoreTransactionPrefix.length;
    if (name.length != prefixLength + 36 + 1 + 3 ||
        ![[name substringWithRange:NSMakeRange(prefixLength + 36, 1)] isEqualToString:@"-"]) {
        return NO;
    }
    NSString *batchIdentifier =
        [name substringWithRange:NSMakeRange(prefixLength, 36)];
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:batchIdentifier];
    if (!uuid || ![[uuid.UUIDString lowercaseString] isEqualToString:batchIdentifier]) {
        return NO;
    }
    NSString *ordinalString = [name substringFromIndex:prefixLength + 37];
    if (ordinalString.length != 3) {
        return NO;
    }
    NSUInteger ordinal = 0;
    for (NSUInteger index = 0; index < ordinalString.length; index++) {
        unichar character = [ordinalString characterAtIndex:index];
        if (character < '0' || character > '9') {
            return NO;
        }
        ordinal = ordinal * 10 + (NSUInteger)(character - '0');
    }
    if (ordinal >= PXAppGroupRestoreMaximumTargets ||
        ![PXAppGroupRestoreWorkspaceName(batchIdentifier, ordinal) isEqualToString:name]) {
        return NO;
    }
    if (batchIdentifierOut) {
        *batchIdentifierOut = batchIdentifier;
    }
    if (ordinalOut) {
        *ordinalOut = ordinal;
    }
    return YES;
}

static NSArray<NSDictionary<NSString *, id> *> *PXAppGroupRestoreJournalEntries(
    NSArray<PXAppGroupRestoreEntry *> *entries) {
    NSMutableArray<NSDictionary<NSString *, id> *> *objects =
        [NSMutableArray arrayWithCapacity:entries.count];
    for (PXAppGroupRestoreEntry *entry in entries) {
        [objects addObject:[entry journalObject]];
    }
    return [objects copy];
}

static NSDictionary<NSNumber *, PXAppGroupRestoreParticipant *> *
PXAppGroupRestoreParticipantsByOrdinal(NSArray<PXAppGroupRestoreParticipant *> *participants) {
    NSMutableDictionary<NSNumber *, PXAppGroupRestoreParticipant *> *result =
        [NSMutableDictionary dictionaryWithCapacity:participants.count];
    for (PXAppGroupRestoreParticipant *participant in participants) {
        result[@(participant.lockOrdinal)] = participant;
    }
    return [result copy];
}

static NSArray<PXAppGroupRestoreParticipant *> *PXAppGroupRestoreLockOrder(
    NSArray<PXAppGroupRestoreParticipant *> *participants) {
    return [participants sortedArrayUsingComparator:^NSComparisonResult(
        PXAppGroupRestoreParticipant *left,
        PXAppGroupRestoreParticipant *right) {
        return PXAppGroupRestoreCompareRawNames(left.canonicalBytes, right.canonicalBytes);
    }];
}

static PXAppGroupRestoreParticipant *PXAppGroupRestoreLeader(
    NSArray<PXAppGroupRestoreParticipant *> *participants) {
    for (PXAppGroupRestoreParticipant *participant in participants) {
        if (participant.lockOrdinal == 0) {
            return participant;
        }
    }
    return nil;
}

static BOOL PXAppGroupRestoreWriteLeaderJournal(
    NSArray<PXAppGroupRestoreParticipant *> *participants,
    NSString *batchIdentifier,
    NSString *phase,
    NSError **error) {
    PXAppGroupRestoreParticipant *leader = PXAppGroupRestoreLeader(participants);
    if (!leader || leader.workspaceDescriptor < 0 || !PXAppGroupRestorePhaseIsValid(phase)) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"The App Group leader journal state is invalid.");
    }
    NSArray<PXAppGroupRestoreParticipant *> *lockOrder = PXAppGroupRestoreLockOrder(participants);
    NSMutableArray<NSDictionary<NSString *, id> *> *records =
        [NSMutableArray arrayWithCapacity:lockOrder.count];
    for (PXAppGroupRestoreParticipant *participant in lockOrder) {
        if (!participant.workspaceNameData ||
            !participant.originalEntries ||
            !participant.stagedEntries) {
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorJournalCreationFailed,
                                         @"$.journal",
                                         @"An App Group journal participant is incomplete.");
        }
        [records addObject:@{
            @"lockOrdinal": @(participant.lockOrdinal),
            @"planOrder": @(participant.planOrder),
            @"groupIdentifiers": [participant.target.groupIdentifiers copy],
            @"workspaceName": participant.workspaceNameData,
            @"targetDevice": @((unsigned long long)participant.targetStat.st_dev),
            @"targetInode": @((unsigned long long)participant.targetStat.st_ino),
            @"originalEntries": PXAppGroupRestoreJournalEntries(participant.originalEntries),
            @"stagedEntries": PXAppGroupRestoreJournalEntries(participant.stagedEntries)
        }];
    }
    NSDictionary *journal = @{
        @"version": @1,
        @"batchIdentifier": batchIdentifier,
        @"phase": phase,
        @"participantCount": @(participants.count),
        @"participants": records
    };
    NSError *serializationError = nil;
    NSData *journalData =
        [NSPropertyListSerialization dataWithPropertyList:journal
                                                   format:NSPropertyListBinaryFormat_v1_0
                                                  options:0
                                                    error:&serializationError];
    if (!journalData || journalData.length == 0 ||
        journalData.length > PXAppGroupRestoreMaximumJournalBytes) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"The App Group leader journal could not be serialized safely.");
    }
    NSData *temporaryNameData = PXAppGroupRestoreNameData(PXAppGroupRestoreJournalTemporaryName);
    NSData *journalNameData = PXAppGroupRestoreNameData(PXAppGroupRestoreJournalName);
    char *temporaryName = PXAppGroupRestoreCopyTerminatedName(temporaryNameData);
    char *journalName = PXAppGroupRestoreCopyTerminatedName(journalNameData);
    if (!temporaryName || !journalName) {
        free(temporaryName);
        free(journalName);
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"The App Group leader journal name is invalid.");
    }
    BOOL temporaryExists = NO;
    struct stat temporaryStat;
    memset(&temporaryStat, 0, sizeof(temporaryStat));
    if (!PXAppGroupRestoreNameState(leader.workspaceDescriptor,
                                    temporaryNameData,
                                    &temporaryExists,
                                    &temporaryStat) ||
        (temporaryExists &&
         (!S_ISREG(temporaryStat.st_mode) ||
          (temporaryStat.st_mode & 0777) != 0600 ||
          temporaryStat.st_nlink != 1 ||
          temporaryStat.st_dev != leader.targetStat.st_dev ||
          temporaryStat.st_size < 0 ||
          (unsigned long long)temporaryStat.st_size > PXAppGroupRestoreMaximumJournalBytes))) {
        free(temporaryName);
        free(journalName);
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"A stale App Group temporary journal is unsafe.");
    }
    if (temporaryExists && unlinkat(leader.workspaceDescriptor, temporaryName, 0) != 0) {
        free(temporaryName);
        free(journalName);
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"A stale App Group temporary journal could not be removed.");
    }
    int descriptor = openat(leader.workspaceDescriptor,
                            temporaryName,
                            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
                            0600);
    if (descriptor < 0) {
        free(temporaryName);
        free(journalName);
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"The App Group leader journal could not be created.");
    }
    struct stat fileStat;
    memset(&fileStat, 0, sizeof(fileStat));
    BOOL durable = fchmod(descriptor, 0600) == 0 &&
                   fstat(descriptor, &fileStat) == 0 &&
                   S_ISREG(fileStat.st_mode) &&
                   (fileStat.st_mode & 0777) == 0600 &&
                   fileStat.st_nlink == 1 &&
                   fileStat.st_dev == leader.targetStat.st_dev &&
                   PXAppGroupRestoreWriteAll(descriptor,
                                             journalData.bytes,
                                             journalData.length) &&
                   PXAppGroupRestoreSyncDescriptor(descriptor);
    int closeResult = close(descriptor);
    if (!durable || closeResult != 0) {
        unlinkat(leader.workspaceDescriptor, temporaryName, 0);
        free(temporaryName);
        free(journalName);
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"The App Group leader journal could not be written durably.");
    }
    BOOL published = renameat(leader.workspaceDescriptor,
                              temporaryName,
                              leader.workspaceDescriptor,
                              journalName) == 0 &&
                     PXAppGroupRestoreSyncDirectory(leader.workspaceDescriptor);
    free(temporaryName);
    free(journalName);
    if (!published) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"The App Group leader journal could not be published durably.");
    }
    return YES;
}

static NSDictionary<NSString *, id> *PXAppGroupRestoreReadLeaderJournal(
    PXAppGroupRestoreParticipant *leader,
    NSString *expectedBatchIdentifier,
    NSArray<PXAppGroupRestoreParticipant *> *participants,
    NSError **error) {
    NSData *nameData = PXAppGroupRestoreNameData(PXAppGroupRestoreJournalName);
    char *name = PXAppGroupRestoreCopyTerminatedName(nameData);
    if (!name) {
        return PXAppGroupRestoreFailObject(error,
                                           PXAppGroupRestoreTransactionErrorJournalInvalid,
                                           @"$.journal",
                                           @"The App Group leader journal name is invalid.");
    }
    int descriptor = openat(leader.workspaceDescriptor,
                            name,
                            O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    free(name);
    if (descriptor < 0) {
        return PXAppGroupRestoreFailObject(error,
                                           PXAppGroupRestoreTransactionErrorJournalInvalid,
                                           @"$.journal",
                                           @"The App Group leader journal is missing.");
    }
    struct stat fileStat;
    memset(&fileStat, 0, sizeof(fileStat));
    if (fstat(descriptor, &fileStat) != 0 ||
        !S_ISREG(fileStat.st_mode) ||
        (fileStat.st_mode & 0777) != 0600 ||
        fileStat.st_nlink != 1 ||
        fileStat.st_dev != leader.targetStat.st_dev || fileStat.st_size <= 0 ||
        (unsigned long long)fileStat.st_size > PXAppGroupRestoreMaximumJournalBytes) {
        close(descriptor);
        return PXAppGroupRestoreFailObject(error,
                                           PXAppGroupRestoreTransactionErrorJournalInvalid,
                                           @"$.journal",
                                           @"The App Group leader journal metadata is invalid.");
    }
    NSData *data = PXAppGroupRestoreReadAll(descriptor,
                                            (size_t)fileStat.st_size,
                                            error,
                                            @"$.journal");
    int closeResult = close(descriptor);
    if (!data || closeResult != 0) {
        return nil;
    }
    NSError *parseError = nil;
    id object = [NSPropertyListSerialization propertyListWithData:data
                                                          options:NSPropertyListImmutable
                                                           format:NULL
                                                            error:&parseError];
    if (![object isKindOfClass:[NSDictionary class]]) {
        return PXAppGroupRestoreFailObject(error,
                                           PXAppGroupRestoreTransactionErrorJournalInvalid,
                                           @"$.journal",
                                           @"The App Group leader journal could not be parsed.");
    }
    NSDictionary *journal = object;
    unsigned long long version = 0;
    unsigned long long participantCount = 0;
    NSString *batchIdentifier = journal[@"batchIdentifier"];
    NSString *phase = journal[@"phase"];
    NSArray *records = journal[@"participants"];
    if (!PXAppGroupRestoreReadUnsignedIntegralNumber(journal[@"version"], &version) ||
        version != 1 ||
        ![batchIdentifier isKindOfClass:[NSString class]] ||
        ![batchIdentifier isEqualToString:expectedBatchIdentifier] ||
        ![phase isKindOfClass:[NSString class]] ||
        !PXAppGroupRestorePhaseIsValid(phase) ||
        !PXAppGroupRestoreReadUnsignedIntegralNumber(journal[@"participantCount"],
                                                     &participantCount) ||
        participantCount != participants.count ||
        ![records isKindOfClass:[NSArray class]] || records.count != participants.count) {
        return PXAppGroupRestoreFailObject(error,
                                           PXAppGroupRestoreTransactionErrorJournalInvalid,
                                           @"$.journal",
                                           @"The App Group leader journal identity is invalid.");
    }
    NSDictionary<NSNumber *, PXAppGroupRestoreParticipant *> *byOrdinal =
        PXAppGroupRestoreParticipantsByOrdinal(participants);
    NSMutableSet<NSNumber *> *seenOrdinals = [NSMutableSet set];
    NSMutableSet<NSNumber *> *seenPlanOrders = [NSMutableSet set];
    NSUInteger aggregateEntries = 0;
    for (NSUInteger recordIndex = 0; recordIndex < records.count; recordIndex++) {
        id recordObject = records[recordIndex];
        if (![recordObject isKindOfClass:[NSDictionary class]]) {
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorJournalInvalid,
                                               @"$.journal.participants",
                                               @"An App Group journal participant is invalid.");
        }
        NSDictionary *record = recordObject;
        unsigned long long ordinalValue = 0;
        unsigned long long planValue = 0;
        unsigned long long deviceValue = 0;
        unsigned long long inodeValue = 0;
        NSData *workspaceName = record[@"workspaceName"];
        NSArray *groupIdentifiers = record[@"groupIdentifiers"];
        if (!PXAppGroupRestoreReadUnsignedIntegralNumber(record[@"lockOrdinal"], &ordinalValue) ||
            !PXAppGroupRestoreReadUnsignedIntegralNumber(record[@"planOrder"], &planValue) ||
            !PXAppGroupRestoreReadUnsignedIntegralNumber(record[@"targetDevice"], &deviceValue) ||
            !PXAppGroupRestoreReadUnsignedIntegralNumber(record[@"targetInode"], &inodeValue) ||
            ordinalValue >= participants.count ||
            ordinalValue != recordIndex ||
            planValue >= participants.count ||
            ![workspaceName isKindOfClass:[NSData class]] ||
            ![groupIdentifiers isKindOfClass:[NSArray class]]) {
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorJournalInvalid,
                                               @"$.journal.participants",
                                               @"An App Group journal participant identity is invalid.");
        }
        NSNumber *ordinalKey = @((NSUInteger)ordinalValue);
        NSNumber *planKey = @((NSUInteger)planValue);
        if ([seenOrdinals containsObject:ordinalKey] || [seenPlanOrders containsObject:planKey]) {
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorJournalInvalid,
                                               @"$.journal.participants",
                                               @"The App Group journal contains duplicate participants.");
        }
        PXAppGroupRestoreParticipant *participant = byOrdinal[ordinalKey];
        NSString *workspaceBatch = nil;
        NSUInteger workspaceOrdinal = NSNotFound;
        if (!participant || participant.planOrder != (NSUInteger)planValue ||
            deviceValue != (unsigned long long)participant.targetStat.st_dev ||
            inodeValue != (unsigned long long)participant.targetStat.st_ino ||
            ![groupIdentifiers isEqualToArray:participant.target.groupIdentifiers] ||
            !PXAppGroupRestoreParseWorkspaceName(workspaceName,
                                                 &workspaceBatch,
                                                 &workspaceOrdinal) ||
            ![workspaceBatch isEqualToString:expectedBatchIdentifier] ||
            workspaceOrdinal != participant.lockOrdinal) {
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorInconsistentBatch,
                                               @"$.recovery",
                                               @"A stale App Group batch does not match the current target set.");
        }
        NSArray<PXAppGroupRestoreEntry *> *originalEntries =
            PXAppGroupRestoreParseJournalEntries(record[@"originalEntries"],
                                                  error,
                                                  @"$.journal.originalEntries");
        if (!originalEntries) {
            return nil;
        }
        NSArray<PXAppGroupRestoreEntry *> *stagedEntries =
            PXAppGroupRestoreParseJournalEntries(record[@"stagedEntries"],
                                                  error,
                                                  @"$.journal.stagedEntries");
        if (!stagedEntries) {
            return nil;
        }
        if (originalEntries.count >
            PXAppGroupRestoreMaximumAggregateEntries - aggregateEntries) {
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorEntryLimitExceeded,
                                               @"$.journal",
                                               @"The App Group journal aggregate entry limit was exceeded.");
        }
        aggregateEntries += originalEntries.count;
        if (stagedEntries.count > PXAppGroupRestoreMaximumAggregateEntries - aggregateEntries) {
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorEntryLimitExceeded,
                                               @"$.journal",
                                               @"The App Group journal aggregate entry limit was exceeded.");
        }
        aggregateEntries += stagedEntries.count;
        participant.workspaceNameData = [workspaceName copy];
        participant.originalEntries = originalEntries;
        participant.stagedEntries = stagedEntries;
        [seenOrdinals addObject:ordinalKey];
        [seenPlanOrders addObject:planKey];
    }
    if (seenOrdinals.count != participants.count || seenPlanOrders.count != participants.count) {
        return PXAppGroupRestoreFailObject(error,
                                           PXAppGroupRestoreTransactionErrorInconsistentBatch,
                                           @"$.recovery",
                                           @"The stale App Group batch participant set is incomplete.");
    }
    return @{ @"phase": phase };
}

static BOOL PXAppGroupRestoreOpenWorkspace(PXAppGroupRestoreParticipant *participant,
                                            BOOL requireRecoveryDirectories,
                                            NSError **error) {
    PXAppGroupRestoreCloseWorkspaceDescriptors(participant);
    if (!participant.workspaceNameData) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorRecoveryFailed,
                                     @"$.recovery",
                                     @"An App Group recovery workspace name is missing.");
    }
    char *workspaceName = PXAppGroupRestoreCopyTerminatedName(participant.workspaceNameData);
    if (!workspaceName) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorRecoveryFailed,
                                     @"$.recovery",
                                     @"An App Group recovery workspace name is invalid.");
    }
    int workspaceDescriptor = openat(participant.targetDescriptor,
                                     workspaceName,
                                     O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    free(workspaceName);
    if (workspaceDescriptor < 0) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorRecoveryFailed,
                                     @"$.recovery",
                                     @"An App Group recovery workspace could not be opened.");
    }
    struct stat workspaceStat;
    memset(&workspaceStat, 0, sizeof(workspaceStat));
    if (fstat(workspaceDescriptor, &workspaceStat) != 0 ||
        !S_ISDIR(workspaceStat.st_mode) ||
        (workspaceStat.st_mode & 0777) != 0700 ||
        workspaceStat.st_dev != participant.targetStat.st_dev) {
        close(workspaceDescriptor);
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorRecoveryFailed,
                                     @"$.recovery",
                                     @"An App Group recovery workspace crossed a filesystem boundary.");
    }
    participant.workspaceDescriptor = workspaceDescriptor;
    BOOL originalExists = NO;
    BOOL newExists = NO;
    int originalDescriptor =
        PXAppGroupRestoreOpenDirectoryAt(workspaceDescriptor,
                                         PXAppGroupRestoreOriginalDirectoryName,
                                         &originalExists);
    int newDescriptor =
        PXAppGroupRestoreOpenDirectoryAt(workspaceDescriptor,
                                         PXAppGroupRestoreNewDirectoryName,
                                         &newExists);
    if (originalDescriptor >= 0) {
        struct stat value;
        memset(&value, 0, sizeof(value));
        if (fstat(originalDescriptor, &value) != 0 ||
            !S_ISDIR(value.st_mode) ||
            (value.st_mode & 0777) != 0700 ||
            value.st_dev != participant.targetStat.st_dev) {
            close(originalDescriptor);
            if (newDescriptor >= 0) close(newDescriptor);
            PXAppGroupRestoreCloseWorkspaceDescriptors(participant);
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorRecoveryFailed,
                                         @"$.recovery",
                                         @"An App Group original recovery directory is invalid.");
        }
    }
    if (newDescriptor >= 0) {
        struct stat value;
        memset(&value, 0, sizeof(value));
        if (fstat(newDescriptor, &value) != 0 ||
            !S_ISDIR(value.st_mode) ||
            (value.st_mode & 0777) != 0700 ||
            value.st_dev != participant.targetStat.st_dev) {
            if (originalDescriptor >= 0) close(originalDescriptor);
            close(newDescriptor);
            PXAppGroupRestoreCloseWorkspaceDescriptors(participant);
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorRecoveryFailed,
                                         @"$.recovery",
                                         @"An App Group new recovery directory is invalid.");
        }
    }
    if (requireRecoveryDirectories &&
        (originalDescriptor < 0 || newDescriptor < 0 || !originalExists || !newExists)) {
        if (originalDescriptor >= 0) close(originalDescriptor);
        if (newDescriptor >= 0) close(newDescriptor);
        PXAppGroupRestoreCloseWorkspaceDescriptors(participant);
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorRecoveryFailed,
                                     @"$.recovery",
                                     @"An App Group recovery workspace is incomplete.");
    }
    participant.originalDescriptor = originalDescriptor;
    participant.newDescriptor = newDescriptor;
    return YES;
}

static BOOL PXAppGroupRestoreWorkspaceHasNoRecoveryData(
    PXAppGroupRestoreParticipant *participant,
    BOOL leader,
    NSError **error) {
    NSArray<NSData *> *names =
        PXAppGroupRestoreReadDirectoryNames(participant.workspaceDescriptor,
                                            PXAppGroupRestoreMaximumWorkspaceEntries,
                                            error,
                                            @"$.recovery");
    if (!names) {
        return NO;
    }
    for (NSData *nameData in names) {
        if (PXAppGroupRestoreRawNameEquals(nameData, PXAppGroupRestoreOriginalDirectoryName) ||
            PXAppGroupRestoreRawNameEquals(nameData, PXAppGroupRestoreNewDirectoryName)) {
            BOOL exists = NO;
            int descriptor = PXAppGroupRestoreOpenDirectoryAt(
                participant.workspaceDescriptor,
                PXAppGroupRestoreRawNameEquals(nameData,
                                                PXAppGroupRestoreOriginalDirectoryName)
                    ? PXAppGroupRestoreOriginalDirectoryName
                    : PXAppGroupRestoreNewDirectoryName,
                &exists);
            if (descriptor < 0 || !exists) {
                if (descriptor >= 0) close(descriptor);
                return PXAppGroupRestoreFail(error,
                                             PXAppGroupRestoreTransactionErrorRecoveryFailed,
                                             @"$.recovery",
                                             @"An App Group pre-mutation workspace directory is invalid.");
            }
            NSArray<NSData *> *contents =
                PXAppGroupRestoreReadDirectoryNames(descriptor, 1, error, @"$.recovery");
            close(descriptor);
            if (!contents || contents.count != 0) {
                return PXAppGroupRestoreFail(error,
                                             PXAppGroupRestoreTransactionErrorRecoveryFailed,
                                             @"$.recovery",
                                             @"An App Group workspace contains recovery data without a journal.");
            }
            continue;
        }
        if (leader && PXAppGroupRestoreRawNameEquals(nameData,
                                                     PXAppGroupRestoreJournalTemporaryName)) {
            BOOL exists = NO;
            struct stat value;
            memset(&value, 0, sizeof(value));
            if (!PXAppGroupRestoreNameState(participant.workspaceDescriptor,
                                            nameData,
                                            &exists,
                                            &value) ||
                !exists || !S_ISREG(value.st_mode) ||
                (value.st_mode & 0777) != 0600 ||
                value.st_nlink != 1 ||
                value.st_dev != participant.targetStat.st_dev || value.st_size < 0 ||
                (unsigned long long)value.st_size > PXAppGroupRestoreMaximumJournalBytes) {
                return PXAppGroupRestoreFail(error,
                                             PXAppGroupRestoreTransactionErrorRecoveryFailed,
                                             @"$.recovery",
                                             @"An App Group temporary journal is unsafe.");
            }
            continue;
        }
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorRecoveryFailed,
                                     @"$.recovery",
                                     @"An App Group pre-mutation workspace contains an unexpected entry.");
    }
    return YES;
}

static BOOL PXAppGroupRestoreRemoveWorkspace(PXAppGroupRestoreParticipant *participant,
                                              BOOL leader,
                                              NSError **error) {
    if (participant.workspaceDescriptor < 0 || !participant.workspaceNameData) {
        return YES;
    }
    NSArray<NSData *> *entries =
        PXAppGroupRestoreReadDirectoryNames(participant.workspaceDescriptor,
                                            PXAppGroupRestoreMaximumWorkspaceEntries,
                                            error,
                                            @"$.transaction.cleanup");
    if (!entries) {
        return NO;
    }
    for (NSData *nameData in entries) {
        BOOL allowed =
            PXAppGroupRestoreRawNameEquals(nameData, PXAppGroupRestoreOriginalDirectoryName) ||
            PXAppGroupRestoreRawNameEquals(nameData, PXAppGroupRestoreNewDirectoryName) ||
            (leader && PXAppGroupRestoreRawNameEquals(nameData,
                                                      PXAppGroupRestoreJournalName)) ||
            (leader && PXAppGroupRestoreRawNameEquals(nameData,
                                                      PXAppGroupRestoreJournalTemporaryName));
        if (!allowed) {
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorCleanupFailed,
                                         @"$.transaction.cleanup",
                                         @"An App Group transaction workspace contains an unexpected entry.");
        }
    }
    if (participant.originalDescriptor >= 0) {
        close(participant.originalDescriptor);
        participant.originalDescriptor = -1;
    }
    if (participant.newDescriptor >= 0) {
        close(participant.newDescriptor);
        participant.newDescriptor = -1;
    }
    if (!PXAppGroupRestoreRemoveNamedDirectoryIfPresent(participant.workspaceDescriptor,
                                                        PXAppGroupRestoreOriginalDirectoryName,
                                                        error,
                                                        @"$.transaction.cleanup.original") ||
        !PXAppGroupRestoreRemoveNamedDirectoryIfPresent(participant.workspaceDescriptor,
                                                        PXAppGroupRestoreNewDirectoryName,
                                                        error,
                                                        @"$.transaction.cleanup.new")) {
        return NO;
    }
    if (leader) {
        for (NSString *fileName in @[PXAppGroupRestoreJournalTemporaryName,
                                     PXAppGroupRestoreJournalName]) {
            NSData *fileNameData = PXAppGroupRestoreNameData(fileName);
            char *rawName = PXAppGroupRestoreCopyTerminatedName(fileNameData);
            if (!rawName) {
                return PXAppGroupRestoreFail(error,
                                             PXAppGroupRestoreTransactionErrorCleanupFailed,
                                             @"$.transaction.cleanup",
                                             @"An App Group cleanup file name is invalid.");
            }
            if (unlinkat(participant.workspaceDescriptor, rawName, 0) != 0 && errno != ENOENT) {
                free(rawName);
                return PXAppGroupRestoreFail(error,
                                             PXAppGroupRestoreTransactionErrorCleanupFailed,
                                             @"$.transaction.cleanup",
                                             @"An App Group cleanup file could not be removed.");
            }
            free(rawName);
        }
    }
    if (!PXAppGroupRestoreSyncDirectory(participant.workspaceDescriptor)) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorCleanupFailed,
                                     @"$.transaction.cleanup",
                                     @"An App Group workspace cleanup could not be synchronized.");
    }
    if (participant.workspaceDescriptor >= 0) {
        close(participant.workspaceDescriptor);
        participant.workspaceDescriptor = -1;
    }
    char *workspaceName = PXAppGroupRestoreCopyTerminatedName(participant.workspaceNameData);
    if (!workspaceName ||
        unlinkat(participant.targetDescriptor, workspaceName, AT_REMOVEDIR) != 0 ||
        !PXAppGroupRestoreSyncDirectory(participant.targetDescriptor)) {
        free(workspaceName);
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorCleanupFailed,
                                     @"$.transaction.cleanup",
                                     @"An App Group transaction workspace could not be removed.");
    }
    free(workspaceName);
    participant.workspaceNameData = nil;
    return YES;
}

static BOOL PXAppGroupRestoreCleanupBatch(
    NSArray<PXAppGroupRestoreParticipant *> *participants,
    NSError **error) {
    PXAppGroupRestoreParticipant *leader = PXAppGroupRestoreLeader(participants);
    for (PXAppGroupRestoreParticipant *participant in participants) {
        if (participant == leader) {
            continue;
        }
        if (!PXAppGroupRestoreRemoveWorkspace(participant, NO, error)) {
            return NO;
        }
    }
    return !leader || PXAppGroupRestoreRemoveWorkspace(leader, YES, error);
}

static BOOL PXAppGroupRestoreCreateWorkspace(
    PXAppGroupRestoreParticipant *participant,
    NSString *batchIdentifier,
    NSError **error) {
    NSString *workspaceName = PXAppGroupRestoreWorkspaceName(batchIdentifier,
                                                             participant.lockOrdinal);
    NSData *workspaceNameData = PXAppGroupRestoreNameData(workspaceName);
    char *rawWorkspaceName = PXAppGroupRestoreCopyTerminatedName(workspaceNameData);
    if (!workspaceName || !workspaceNameData || !rawWorkspaceName) {
        free(rawWorkspaceName);
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"An App Group transaction workspace name is invalid.");
    }
    if (mkdirat(participant.targetDescriptor, rawWorkspaceName, 0700) != 0) {
        free(rawWorkspaceName);
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"An App Group transaction workspace could not be created.");
    }
    participant.workspaceNameData = workspaceNameData;
    int workspaceDescriptor = openat(participant.targetDescriptor,
                                     rawWorkspaceName,
                                     O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (workspaceDescriptor < 0) {
        unlinkat(participant.targetDescriptor, rawWorkspaceName, AT_REMOVEDIR);
        PXAppGroupRestoreSyncDirectory(participant.targetDescriptor);
        participant.workspaceNameData = nil;
        free(rawWorkspaceName);
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"An App Group transaction workspace could not be opened.");
    }
    free(rawWorkspaceName);
    participant.workspaceDescriptor = workspaceDescriptor;
    struct stat workspaceStat;
    memset(&workspaceStat, 0, sizeof(workspaceStat));
    if (fchmod(workspaceDescriptor, 0700) != 0 ||
        fstat(workspaceDescriptor, &workspaceStat) != 0 ||
        !S_ISDIR(workspaceStat.st_mode) ||
        (workspaceStat.st_mode & 0777) != 0700 ||
        workspaceStat.st_dev != participant.targetStat.st_dev) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorJournalCreationFailed,
                                     @"$.journal",
                                     @"An App Group transaction workspace identity is invalid.");
    }
    for (NSString *directoryName in @[PXAppGroupRestoreOriginalDirectoryName,
                                      PXAppGroupRestoreNewDirectoryName]) {
        NSData *directoryNameData = PXAppGroupRestoreNameData(directoryName);
        char *rawName = PXAppGroupRestoreCopyTerminatedName(directoryNameData);
        if (!rawName || mkdirat(workspaceDescriptor, rawName, 0700) != 0) {
            free(rawName);
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorJournalCreationFailed,
                                         @"$.journal",
                                         @"An App Group recovery directory could not be created.");
        }
        int descriptor = openat(workspaceDescriptor,
                                rawName,
                                O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        free(rawName);
        struct stat directoryStat;
        memset(&directoryStat, 0, sizeof(directoryStat));
        if (descriptor < 0 || fchmod(descriptor, 0700) != 0 ||
            fstat(descriptor, &directoryStat) != 0 ||
            !S_ISDIR(directoryStat.st_mode) ||
            (directoryStat.st_mode & 0777) != 0700 ||
            directoryStat.st_dev != participant.targetStat.st_dev) {
            if (descriptor >= 0) close(descriptor);
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorJournalCreationFailed,
                                         @"$.journal",
                                         @"An App Group recovery directory identity is invalid.");
        }
        if ([directoryName isEqualToString:PXAppGroupRestoreOriginalDirectoryName]) {
            participant.originalDescriptor = descriptor;
        } else {
            participant.newDescriptor = descriptor;
        }
    }
    return YES;
}

static NSArray<PXAppGroupRestoreParticipant *> *PXAppGroupRestorePlanOrder(
    NSArray<PXAppGroupRestoreParticipant *> *participants) {
    return [participants sortedArrayUsingComparator:^NSComparisonResult(
        PXAppGroupRestoreParticipant *left,
        PXAppGroupRestoreParticipant *right) {
        if (left.planOrder < right.planOrder) return NSOrderedAscending;
        if (left.planOrder > right.planOrder) return NSOrderedDescending;
        return NSOrderedSame;
    }];
}

static BOOL PXAppGroupRestoreRequireNamespaces(
    NSArray<PXAppGroupRestoreParticipant *> *participants,
    BOOL staged,
    PXAppGroupRestoreTransactionErrorCode code,
    NSString *fieldPath,
    NSString *description,
    NSError **error) {
    for (PXAppGroupRestoreParticipant *participant in participants) {
        NSArray<PXAppGroupRestoreEntry *> *expected =
            staged ? participant.stagedEntries : participant.originalEntries;
        if (!expected ||
            !PXAppGroupRestoreRequireExactEntries(participant.targetDescriptor,
                                                  expected,
                                                  NO,
                                                  NO,
                                                  YES,
                                                  YES,
                                                  code,
                                                  fieldPath,
                                                  description,
                                                  error)) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXAppGroupRestoreRollbackBatch(
    NSArray<PXAppGroupRestoreParticipant *> *participants,
    NSString *batchIdentifier,
    NSError **error) {
    NSError *phaseError = nil;
    PXAppGroupRestoreWriteLeaderJournal(participants,
                                        batchIdentifier,
                                        PXAppGroupRestorePhaseRollingBack,
                                        &phaseError);
    NSArray<PXAppGroupRestoreParticipant *> *planOrder = PXAppGroupRestorePlanOrder(participants);
    for (PXAppGroupRestoreParticipant *participant in planOrder.reverseObjectEnumerator) {
        if (participant.workspaceDescriptor < 0 ||
            participant.originalDescriptor < 0 ||
            participant.newDescriptor < 0 ||
            !participant.originalEntries ||
            !participant.stagedEntries ||
            !PXAppGroupRestoreRollbackEntries(participant.originalEntries,
                                               participant.stagedEntries,
                                               participant.targetDescriptor,
                                               participant.originalDescriptor,
                                               participant.newDescriptor,
                                               error)) {
            if (error && !*error) {
                PXAppGroupRestoreFail(error,
                                      PXAppGroupRestoreTransactionErrorRollbackFailed,
                                      @"$.transaction.rollback",
                                      @"The complete App Group batch could not be rolled back.");
            }
            return NO;
        }
    }
    if (!PXAppGroupRestoreRequireNamespaces(participants,
                                            NO,
                                            PXAppGroupRestoreTransactionErrorRollbackFailed,
                                            @"$.transaction.rollback",
                                            @"The rolled-back App Group batch does not match the original namespaces.",
                                            error)) {
        return NO;
    }
    NSError *journalError = nil;
    if (!PXAppGroupRestoreWriteLeaderJournal(participants,
                                             batchIdentifier,
                                             PXAppGroupRestorePhaseRolledBack,
                                             &journalError)) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorRollbackFailed,
                                     @"$.transaction.rollback",
                                     @"The rolled-back App Group decision could not be published durably.");
    }
    return YES;
}

static BOOL PXAppGroupRestoreRecoverStaleBatch(
    NSArray<PXAppGroupRestoreParticipant *> *participants,
    NSUInteger *recoveredCountOut,
    NSError **error) {
    if (recoveredCountOut) {
        *recoveredCountOut = 0;
    }
    NSMutableSet<NSString *> *batchIdentifiers = [NSMutableSet set];
    NSMutableSet<NSNumber *> *ordinals = [NSMutableSet set];
    NSMutableDictionary<NSNumber *, NSData *> *workspaceNames = [NSMutableDictionary dictionary];
    for (PXAppGroupRestoreParticipant *participant in participants) {
        NSArray<NSData *> *names =
            PXAppGroupRestoreReadDirectoryNames(participant.targetDescriptor,
                                                PXAppGroupRestoreMaximumTopLevelEntries,
                                                error,
                                                @"$.recovery");
        if (!names) {
            return NO;
        }
        for (NSData *nameData in names) {
            if (!PXAppGroupRestoreRawNameHasPrefix(nameData,
                                                   PXAppGroupRestoreTransactionPrefix)) {
                continue;
            }
            NSString *batchIdentifier = nil;
            NSUInteger ordinal = NSNotFound;
            if (!PXAppGroupRestoreParseWorkspaceName(nameData,
                                                     &batchIdentifier,
                                                     &ordinal) ||
                ordinal != participant.lockOrdinal) {
                return PXAppGroupRestoreFail(error,
                                             PXAppGroupRestoreTransactionErrorRecoveryFailed,
                                             @"$.recovery",
                                             @"A reserved App Group recovery workspace name is malformed.");
            }
            NSNumber *ordinalKey = @(ordinal);
            if ([ordinals containsObject:ordinalKey]) {
                return PXAppGroupRestoreFail(error,
                                             PXAppGroupRestoreTransactionErrorInconsistentBatch,
                                             @"$.recovery",
                                             @"A stale App Group batch contains a duplicate participant ordinal.");
            }
            BOOL exists = NO;
            struct stat workspaceStat;
            memset(&workspaceStat, 0, sizeof(workspaceStat));
            if (!PXAppGroupRestoreNameState(participant.targetDescriptor,
                                            nameData,
                                            &exists,
                                            &workspaceStat) ||
                !exists || !S_ISDIR(workspaceStat.st_mode) ||
                (workspaceStat.st_mode & 0777) != 0700 ||
                workspaceStat.st_dev != participant.targetStat.st_dev) {
                return PXAppGroupRestoreFail(error,
                                             PXAppGroupRestoreTransactionErrorRecoveryFailed,
                                             @"$.recovery",
                                             @"A stale App Group recovery workspace is unsafe.");
            }
            [batchIdentifiers addObject:batchIdentifier];
            if (batchIdentifiers.count > PXAppGroupRestoreMaximumStaleBatchIdentifiers) {
                return PXAppGroupRestoreFail(error,
                                             PXAppGroupRestoreTransactionErrorInconsistentBatch,
                                             @"$.recovery",
                                             @"More than one stale App Group batch is present.");
            }
            [ordinals addObject:ordinalKey];
            workspaceNames[ordinalKey] = nameData;
        }
    }
    if (batchIdentifiers.count == 0) {
        return YES;
    }
    NSString *batchIdentifier = batchIdentifiers.anyObject;
    NSDictionary<NSNumber *, PXAppGroupRestoreParticipant *> *byOrdinal =
        PXAppGroupRestoreParticipantsByOrdinal(participants);
    for (NSNumber *ordinalKey in workspaceNames) {
        PXAppGroupRestoreParticipant *participant = byOrdinal[ordinalKey];
        participant.workspaceNameData = workspaceNames[ordinalKey];
        if (!participant || !PXAppGroupRestoreOpenWorkspace(participant, NO, error)) {
            return NO;
        }
    }
    PXAppGroupRestoreParticipant *leader = PXAppGroupRestoreLeader(participants);
    BOOL journalExists = NO;
    struct stat journalStat;
    memset(&journalStat, 0, sizeof(journalStat));
    if (leader.workspaceDescriptor >= 0) {
        NSData *journalNameData = PXAppGroupRestoreNameData(PXAppGroupRestoreJournalName);
        if (!PXAppGroupRestoreNameState(leader.workspaceDescriptor,
                                        journalNameData,
                                        &journalExists,
                                        &journalStat)) {
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorRecoveryFailed,
                                         @"$.recovery",
                                         @"The stale App Group leader journal state could not be inspected.");
        }
    }
    if (!journalExists) {
        for (PXAppGroupRestoreParticipant *participant in participants) {
            if (participant.workspaceDescriptor < 0) {
                continue;
            }
            if (!PXAppGroupRestoreWorkspaceHasNoRecoveryData(participant,
                                                              participant == leader,
                                                              error)) {
                return NO;
            }
        }
        if (!PXAppGroupRestoreCleanupBatch(participants, error)) {
            return NO;
        }
        for (PXAppGroupRestoreParticipant *participant in participants) {
            participant.originalEntries = nil;
            participant.stagedEntries = nil;
        }
        if (recoveredCountOut) {
            *recoveredCountOut = 1;
        }
        return YES;
    }
    if (leader.workspaceDescriptor < 0 ||
        !S_ISREG(journalStat.st_mode) || journalStat.st_nlink != 1 ||
        journalStat.st_dev != leader.targetStat.st_dev) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorRecoveryFailed,
                                     @"$.recovery",
                                     @"The stale App Group leader journal is not bound safely.");
    }
    NSDictionary<NSString *, id> *journal =
        PXAppGroupRestoreReadLeaderJournal(leader,
                                           batchIdentifier,
                                           participants,
                                           error);
    if (!journal) {
        return NO;
    }
    NSString *phase = journal[@"phase"];
    BOOL committedPhase = [phase isEqualToString:PXAppGroupRestorePhaseCommitted];
    BOOL rolledBackPhase = [phase isEqualToString:PXAppGroupRestorePhaseRolledBack];
    if (!committedPhase && !rolledBackPhase) {
        for (PXAppGroupRestoreParticipant *participant in participants) {
            if (participant.workspaceDescriptor < 0) {
                return PXAppGroupRestoreFail(error,
                                             PXAppGroupRestoreTransactionErrorRecoveryFailed,
                                             @"$.recovery",
                                             @"An in-progress App Group batch participant workspace is missing.");
            }
            if (participant.originalDescriptor < 0 || participant.newDescriptor < 0) {
                PXAppGroupRestoreCloseWorkspaceDescriptors(participant);
                if (!PXAppGroupRestoreOpenWorkspace(participant, YES, error)) {
                    return NO;
                }
            }
        }
        if (!PXAppGroupRestoreRollbackBatch(participants, batchIdentifier, error)) {
            return NO;
        }
    } else {
        if (!PXAppGroupRestoreRequireNamespaces(
                participants,
                committedPhase,
                PXAppGroupRestoreTransactionErrorRecoveryFailed,
                @"$.recovery",
                committedPhase
                    ? @"A committed stale App Group batch namespace is inconsistent."
                    : @"A rolled-back stale App Group batch namespace is inconsistent.",
                error)) {
            return NO;
        }
    }
    if (!PXAppGroupRestoreCleanupBatch(participants, error)) {
        return NO;
    }
    for (PXAppGroupRestoreParticipant *participant in participants) {
        participant.originalEntries = nil;
        participant.stagedEntries = nil;
    }
    if (recoveredCountOut) {
        *recoveredCountOut = 1;
    }
    return YES;
}

@interface PXAppGroupRestoreTransaction ()
- (instancetype)initPrivate;
@property (nonatomic, copy) NSArray<PXAppGroupRestoreTarget *> *targets;
@property (nonatomic, copy) NSArray<PXValidatedMainDataStage *> *validatedStages;
@property (nonatomic, copy) NSArray<PXAppGroupRestoreParticipant *> *participants;
@property (nonatomic, copy, nullable) NSString *batchIdentifier;
@property (nonatomic, assign) BOOL commitAttempted;
@property (nonatomic, assign) BOOL prepared;
@property (nonatomic, assign, readwrite, getter=isCommitted) BOOL committed;
@property (nonatomic, assign, readwrite) BOOL rollbackPerformed;
@property (nonatomic, assign, readwrite) BOOL rollbackComplete;
@property (nonatomic, assign, readwrite) NSUInteger recoveredStaleBatchCount;
@property (nonatomic, assign, readwrite) NSUInteger targetCount;
@end

@implementation PXAppGroupRestoreTransaction

+ (instancetype)transactionForTargets:(NSArray<PXAppGroupRestoreTarget *> *)targets
                       validatedStages:(NSArray<PXValidatedMainDataStage *> *)validatedStages
                                 error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    if (![targets isKindOfClass:[NSArray class]] ||
        ![validatedStages isKindOfClass:[NSArray class]] ||
        targets.count == 0 || targets.count > PXAppGroupRestoreMaximumTargets ||
        targets.count != validatedStages.count) {
        return PXAppGroupRestoreFailObject(error,
                                           PXAppGroupRestoreTransactionErrorInvalidInput,
                                           @"$.targets",
                                           @"The App Group transaction input arrays are invalid.");
    }
    NSArray *targetCopy = [targets copy];
    NSArray *stageCopy = [validatedStages copy];
    NSMutableArray<PXAppGroupRestoreParticipant *> *participants =
        [NSMutableArray arrayWithCapacity:targetCopy.count];
    NSMutableSet<NSData *> *canonicalPaths = [NSMutableSet set];
    for (NSUInteger index = 0; index < targetCopy.count; index++) {
        id targetObject = targetCopy[index];
        id stageObject = stageCopy[index];
        if (![targetObject isKindOfClass:[PXAppGroupRestoreTarget class]] ||
            ![stageObject isKindOfClass:[PXValidatedMainDataStage class]]) {
            PXAppGroupRestoreCloseAllDescriptors(participants);
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorInvalidInput,
                                               @"$.targets",
                                               @"An App Group transaction array contains an invalid object.");
        }
        PXAppGroupRestoreTarget *target = targetObject;
        PXValidatedMainDataStage *stage = stageObject;
        NSData *canonicalBytes =
            [target.canonicalPath dataUsingEncoding:NSUTF8StringEncoding
                                allowLossyConversion:NO];
        if (target.canonicalPath.length == 0 ||
            !PXAppGroupRestoreCanonicalBytesAreValid(canonicalBytes) ||
            stage.dataPath.length == 0 || stage.treeSHA256.length != 64 ||
            [canonicalPaths containsObject:canonicalBytes]) {
            PXAppGroupRestoreCloseAllDescriptors(participants);
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorInvalidInput,
                                               @"$.targets",
                                               @"An App Group transaction target or stage is inconsistent.");
        }
        PXAppGroupRestoreParticipant *participant =
            [[PXAppGroupRestoreParticipant alloc] init];
        participant.target = target;
        participant.stage = stage;
        participant.canonicalPath = [target.canonicalPath copy];
        participant.canonicalBytes = [canonicalBytes copy];
        participant.stagePath = [stage.dataPath copy];
        participant.planOrder = index;
        if (!PXAppGroupRestoreValidateTargetModels(participant, error)) {
            [participants addObject:participant];
            PXAppGroupRestoreCloseAllDescriptors(participants);
            return nil;
        }
        [canonicalPaths addObject:canonicalBytes];
        [participants addObject:participant];
    }
    NSArray<PXAppGroupRestoreParticipant *> *lockOrder =
        PXAppGroupRestoreLockOrder(participants);
    for (NSUInteger index = 0; index < lockOrder.count; index++) {
        lockOrder[index].lockOrdinal = index;
    }
    NSMutableSet<NSString *> *physicalTargets = [NSMutableSet set];
    for (PXAppGroupRestoreParticipant *participant in lockOrder) {
        int targetDescriptor = open(participant.canonicalPath.fileSystemRepresentation,
                                    O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (targetDescriptor < 0 ||
            !PXAppGroupRestorePathMatchesDescriptor(participant.canonicalPath,
                                                    targetDescriptor)) {
            if (targetDescriptor >= 0) close(targetDescriptor);
            PXAppGroupRestoreCloseAllDescriptors(participants);
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorTargetValidationFailed,
                                               @"$.target",
                                               @"An exact App Group target could not be bound safely.");
        }
        participant.targetDescriptor = targetDescriptor;
        struct stat targetStat;
        memset(&targetStat, 0, sizeof(targetStat));
        if (fstat(targetDescriptor, &targetStat) != 0 || !S_ISDIR(targetStat.st_mode)) {
            PXAppGroupRestoreCloseAllDescriptors(participants);
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorFilesystemInspectionFailed,
                                               @"$.target",
                                               @"An exact App Group target could not be inspected.");
        }
        participant.targetStat = targetStat;
        NSString *physicalKey = [NSString stringWithFormat:@"%llu:%llu",
                                 (unsigned long long)targetStat.st_dev,
                                 (unsigned long long)targetStat.st_ino];
        if ([physicalTargets containsObject:physicalKey]) {
            PXAppGroupRestoreCloseAllDescriptors(participants);
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorInconsistentBatch,
                                               @"$.targets",
                                               @"Two App Group targets refer to the same physical directory.");
        }
        [physicalTargets addObject:physicalKey];
        int lockDescriptor = open(participant.canonicalPath.fileSystemRepresentation,
                                  O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (lockDescriptor < 0 ||
            !PXAppGroupRestorePathMatchesDescriptor(participant.canonicalPath,
                                                    lockDescriptor)) {
            if (lockDescriptor >= 0) close(lockDescriptor);
            PXAppGroupRestoreCloseAllDescriptors(participants);
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorLockFailed,
                                               @"$.locks",
                                               @"An App Group transaction lock could not be bound safely.");
        }
        participant.lockDescriptor = lockDescriptor;
        struct stat lockStat;
        memset(&lockStat, 0, sizeof(lockStat));
        if (fstat(lockDescriptor, &lockStat) != 0 ||
            !S_ISDIR(lockStat.st_mode) ||
            targetStat.st_dev != lockStat.st_dev ||
            targetStat.st_ino != lockStat.st_ino) {
            PXAppGroupRestoreCloseAllDescriptors(participants);
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorLockFailed,
                                               @"$.locks",
                                               @"An App Group transaction lock does not protect the exact target.");
        }
        participant.lockStat = lockStat;
        if (flock(lockDescriptor, LOCK_EX | LOCK_NB) != 0) {
            PXAppGroupRestoreCloseAllDescriptors(participants);
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorLockFailed,
                                               @"$.locks",
                                               @"An App Group transaction lock is already held.");
        }
        if (!PXAppGroupRestoreValidateTargetModels(participant, error)) {
            PXAppGroupRestoreCloseAllDescriptors(participants);
            return nil;
        }
        struct stat targetLockedStat;
        struct stat lockLockedStat;
        memset(&targetLockedStat, 0, sizeof(targetLockedStat));
        memset(&lockLockedStat, 0, sizeof(lockLockedStat));
        if (!PXAppGroupRestorePathMatchesDescriptor(participant.canonicalPath,
                                                    targetDescriptor) ||
            !PXAppGroupRestorePathMatchesDescriptor(participant.canonicalPath,
                                                    lockDescriptor) ||
            fstat(targetDescriptor, &targetLockedStat) != 0 ||
            fstat(lockDescriptor, &lockLockedStat) != 0 ||
            !PXAppGroupRestoreStatIdentityMatches(&targetStat, &targetLockedStat) ||
            !PXAppGroupRestoreStatIdentityMatches(&lockStat, &lockLockedStat) ||
            targetLockedStat.st_dev != lockLockedStat.st_dev ||
            targetLockedStat.st_ino != lockLockedStat.st_ino) {
            PXAppGroupRestoreCloseAllDescriptors(participants);
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorFilesystemChanged,
                                               @"$.target",
                                               @"An App Group target changed while its lock was acquired.");
        }
        int stageDescriptor = open(participant.stagePath.fileSystemRepresentation,
                                   O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (stageDescriptor < 0 ||
            !PXAppGroupRestorePathMatchesDescriptor(participant.stagePath,
                                                    stageDescriptor)) {
            if (stageDescriptor >= 0) close(stageDescriptor);
            PXAppGroupRestoreCloseAllDescriptors(participants);
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorFilesystemChanged,
                                               @"$.stage",
                                               @"A validated App Group stage could not be bound safely.");
        }
        participant.stageDescriptor = stageDescriptor;
        struct stat stageStat;
        memset(&stageStat, 0, sizeof(stageStat));
        if (fstat(stageDescriptor, &stageStat) != 0 || !S_ISDIR(stageStat.st_mode)) {
            PXAppGroupRestoreCloseAllDescriptors(participants);
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorFilesystemInspectionFailed,
                                               @"$.stage",
                                               @"A validated App Group stage could not be inspected.");
        }
        participant.stageStat = stageStat;
        if (stageStat.st_dev != targetStat.st_dev) {
            PXAppGroupRestoreCloseAllDescriptors(participants);
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorCrossDeviceBoundary,
                                               @"$.stage",
                                               @"A validated App Group stage is not on its target filesystem.");
        }
        if (!PXAppGroupRestoreParticipantIdentityIsValid(participant,
                                                         YES,
                                                         YES,
                                                         error)) {
            PXAppGroupRestoreCloseAllDescriptors(participants);
            return nil;
        }
    }
    NSUInteger recoveredCount = 0;
    if (!PXAppGroupRestoreRecoverStaleBatch(participants,
                                            &recoveredCount,
                                            error)) {
        PXAppGroupRestoreCloseAllDescriptors(participants);
        return nil;
    }
    for (PXAppGroupRestoreParticipant *participant in lockOrder) {
        if (!PXAppGroupRestoreParticipantIdentityIsValid(participant,
                                                         YES,
                                                         YES,
                                                         error)) {
            PXAppGroupRestoreCloseAllDescriptors(participants);
            return nil;
        }
    }
    NSUInteger aggregateEntries = 0;
    for (PXAppGroupRestoreParticipant *participant in participants) {
        NSArray<PXAppGroupRestoreEntry *> *originalEntries =
            PXAppGroupRestoreCollectEntries(participant.targetDescriptor,
                                             NO,
                                             NO,
                                             YES,
                                             YES,
                                             error,
                                             @"$.target.entries");
        NSArray<PXAppGroupRestoreEntry *> *stagedEntries =
            PXAppGroupRestoreCollectEntries(participant.stageDescriptor,
                                             YES,
                                             YES,
                                             NO,
                                             NO,
                                             error,
                                             @"$.stage.entries");
        if (!originalEntries || !stagedEntries ||
            originalEntries.count > PXAppGroupRestoreMaximumAggregateEntries - aggregateEntries) {
            PXAppGroupRestoreCloseAllDescriptors(participants);
            if (error && !*error) {
                PXAppGroupRestoreFail(error,
                                      PXAppGroupRestoreTransactionErrorEntryLimitExceeded,
                                      @"$.targets",
                                      @"The App Group transaction aggregate entry limit was exceeded.");
            }
            return nil;
        }
        aggregateEntries += originalEntries.count;
        if (stagedEntries.count > PXAppGroupRestoreMaximumAggregateEntries - aggregateEntries) {
            PXAppGroupRestoreCloseAllDescriptors(participants);
            return PXAppGroupRestoreFailObject(error,
                                               PXAppGroupRestoreTransactionErrorEntryLimitExceeded,
                                               @"$.targets",
                                               @"The App Group transaction aggregate entry limit was exceeded.");
        }
        aggregateEntries += stagedEntries.count;
        participant.originalEntries = originalEntries;
        participant.stagedEntries = stagedEntries;
    }
    PXAppGroupRestoreTransaction *transaction = [[self alloc] initPrivate];
    transaction.targets = targetCopy;
    transaction.validatedStages = stageCopy;
    transaction.participants = [participants copy];
    transaction.recoveredStaleBatchCount = recoveredCount;
    transaction.targetCount = participants.count;
    return transaction;
}

- (instancetype)initPrivate {
    return [super init];
}

- (BOOL)revalidatePreparedBatchWithError:(NSError **)error {
    for (PXAppGroupRestoreParticipant *participant in self.participants) {
        if (!PXAppGroupRestoreParticipantIdentityIsValid(participant,
                                                         YES,
                                                         YES,
                                                         error) ||
            !PXAppGroupRestoreRequireExactEntries(
                participant.targetDescriptor,
                participant.originalEntries,
                NO,
                NO,
                YES,
                YES,
                PXAppGroupRestoreTransactionErrorFilesystemChanged,
                @"$.target",
                @"An App Group target namespace changed before transaction preparation.",
                error) ||
            !PXAppGroupRestoreRequireExactEntries(
                participant.stageDescriptor,
                participant.stagedEntries,
                YES,
                YES,
                NO,
                NO,
                PXAppGroupRestoreTransactionErrorFilesystemChanged,
                @"$.stage",
                @"A validated App Group stage changed before transaction preparation.",
                error)) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)prepareWorkspacesWithError:(NSError **)error {
    self.batchIdentifier = [[[NSUUID UUID] UUIDString] lowercaseString];
    NSArray<PXAppGroupRestoreParticipant *> *lockOrder =
        PXAppGroupRestoreLockOrder(self.participants);
    for (PXAppGroupRestoreParticipant *participant in lockOrder) {
        if (!PXAppGroupRestoreCreateWorkspace(participant,
                                              self.batchIdentifier,
                                              error)) {
            PXAppGroupRestoreCleanupBatch(self.participants, nil);
            return NO;
        }
    }
    for (PXAppGroupRestoreParticipant *participant in lockOrder) {
        if (!PXAppGroupRestoreSyncDirectory(participant.workspaceDescriptor) ||
            !PXAppGroupRestoreSyncDirectory(participant.targetDescriptor)) {
            PXAppGroupRestoreCleanupBatch(self.participants, nil);
            return PXAppGroupRestoreFail(error,
                                         PXAppGroupRestoreTransactionErrorJournalCreationFailed,
                                         @"$.journal",
                                         @"The App Group transaction workspaces could not be synchronized.");
        }
    }
    if (!PXAppGroupRestoreWriteLeaderJournal(self.participants,
                                             self.batchIdentifier,
                                             PXAppGroupRestorePhasePrepared,
                                             error)) {
        PXAppGroupRestoreCleanupBatch(self.participants, nil);
        return NO;
    }
    self.prepared = YES;
    return YES;
}

- (BOOL)quarantineWholeBatchWithError:(NSError **)error {
    for (PXAppGroupRestoreParticipant *participant in PXAppGroupRestorePlanOrder(self.participants)) {
        for (PXAppGroupRestoreEntry *entry in participant.originalEntries) {
            if (!PXAppGroupRestoreMoveEntry(entry,
                                            participant.targetDescriptor,
                                            participant.originalDescriptor,
                                            error,
                                            PXAppGroupRestoreTransactionErrorQuarantineFailed,
                                            @"$.transaction.quarantine",
                                            @"An App Group original entry could not be quarantined.")) {
                return NO;
            }
        }
    }
    for (PXAppGroupRestoreParticipant *participant in self.participants) {
        if (!PXAppGroupRestoreSyncDirectory(participant.targetDescriptor) ||
            !PXAppGroupRestoreSyncDirectory(participant.originalDescriptor) ||
            !PXAppGroupRestoreRequireExactEntries(
                participant.targetDescriptor,
                @[],
                NO,
                NO,
                YES,
                YES,
                PXAppGroupRestoreTransactionErrorQuarantineFailed,
                @"$.transaction.quarantine",
                @"An App Group target namespace is not empty after quarantine.",
                error) ||
            !PXAppGroupRestoreRequireExactEntries(
                participant.originalDescriptor,
                participant.originalEntries,
                NO,
                NO,
                NO,
                NO,
                PXAppGroupRestoreTransactionErrorQuarantineFailed,
                @"$.transaction.quarantine",
                @"An App Group original quarantine does not match its journal.",
                error)) {
            if (error && !*error) {
                PXAppGroupRestoreFail(error,
                                      PXAppGroupRestoreTransactionErrorQuarantineFailed,
                                      @"$.transaction.quarantine",
                                      @"The App Group quarantine state could not be synchronized.");
            }
            return NO;
        }
    }
    NSError *journalError = nil;
    if (!PXAppGroupRestoreWriteLeaderJournal(self.participants,
                                             self.batchIdentifier,
                                             PXAppGroupRestorePhaseQuarantined,
                                             &journalError)) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorQuarantineFailed,
                                     @"$.transaction.quarantine",
                                     @"The App Group quarantined decision could not be published durably.");
    }
    return YES;
}

- (BOOL)installWholeBatchWithError:(NSError **)error {
    for (PXAppGroupRestoreParticipant *participant in PXAppGroupRestorePlanOrder(self.participants)) {
        for (PXAppGroupRestoreEntry *entry in participant.stagedEntries) {
            if (!PXAppGroupRestoreMoveEntry(entry,
                                            participant.stageDescriptor,
                                            participant.targetDescriptor,
                                            error,
                                            PXAppGroupRestoreTransactionErrorCommitFailed,
                                            @"$.transaction.commit",
                                            @"A validated App Group staged entry could not be installed.")) {
                return NO;
            }
        }
    }
    for (PXAppGroupRestoreParticipant *participant in self.participants) {
        if (!PXAppGroupRestoreSyncDirectory(participant.targetDescriptor) ||
            !PXAppGroupRestoreSyncDirectory(participant.stageDescriptor) ||
            !PXAppGroupRestoreRequireExactEntries(
                participant.targetDescriptor,
                participant.stagedEntries,
                NO,
                NO,
                YES,
                YES,
                PXAppGroupRestoreTransactionErrorCommitFailed,
                @"$.transaction.commit",
                @"An installed App Group namespace does not match its journal.",
                error) ||
            !PXAppGroupRestoreRequireExactEntries(
                participant.stageDescriptor,
                @[],
                YES,
                YES,
                NO,
                NO,
                PXAppGroupRestoreTransactionErrorCommitFailed,
                @"$.transaction.commit",
                @"A validated App Group stage is not empty after installation.",
                error)) {
            if (error && !*error) {
                PXAppGroupRestoreFail(error,
                                      PXAppGroupRestoreTransactionErrorCommitFailed,
                                      @"$.transaction.commit",
                                      @"The installed App Group state could not be synchronized.");
            }
            return NO;
        }
    }
    NSError *journalError = nil;
    if (!PXAppGroupRestoreWriteLeaderJournal(self.participants,
                                             self.batchIdentifier,
                                             PXAppGroupRestorePhaseInstalled,
                                             &journalError)) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorCommitFailed,
                                     @"$.transaction.commit",
                                     @"The installed App Group decision could not be published durably.");
    }
    return YES;
}

- (BOOL)publishCommittedDecisionWithError:(NSError **)error {
    for (PXAppGroupRestoreParticipant *participant in self.participants) {
        if (!PXAppGroupRestoreParticipantIdentityIsValid(participant,
                                                         YES,
                                                         YES,
                                                         error) ||
            !PXAppGroupRestoreRequireExactEntries(
                participant.targetDescriptor,
                participant.stagedEntries,
                NO,
                NO,
                YES,
                YES,
                PXAppGroupRestoreTransactionErrorCommitFailed,
                @"$.transaction.commit",
                @"An App Group target changed before the durable commit decision.",
                error) ||
            !PXAppGroupRestoreRequireExactEntries(
                participant.stageDescriptor,
                @[],
                YES,
                YES,
                NO,
                NO,
                PXAppGroupRestoreTransactionErrorCommitFailed,
                @"$.transaction.commit",
                @"An App Group stage changed before the durable commit decision.",
                error)) {
            return NO;
        }
    }
    NSError *journalError = nil;
    if (!PXAppGroupRestoreWriteLeaderJournal(self.participants,
                                             self.batchIdentifier,
                                             PXAppGroupRestorePhaseCommitted,
                                             &journalError)) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorCommitFailed,
                                     @"$.transaction.commit",
                                     @"The App Group committed decision could not be published durably.");
    }
    self.committed = YES;
    return YES;
}

- (BOOL)rollbackPreparedBatchWithCleanupWarning:(NSError **)cleanupWarning
                                           error:(NSError **)error {
    self.rollbackPerformed = YES;
    NSError *rollbackError = nil;
    if (!PXAppGroupRestoreRollbackBatch(self.participants,
                                        self.batchIdentifier,
                                        &rollbackError)) {
        self.rollbackComplete = NO;
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorRollbackFailed,
                                     @"$.transaction.rollback",
                                     @"The App Group transaction could not restore every original target.");
    }
    self.rollbackComplete = YES;
    NSError *cleanupError = nil;
    if (!PXAppGroupRestoreCleanupBatch(self.participants, &cleanupError) && cleanupWarning) {
        *cleanupWarning = cleanupError;
    }
    return YES;
}

- (BOOL)commitWithCleanupWarning:(NSError **)cleanupWarning
                           error:(NSError **)error {
    if (cleanupWarning) {
        *cleanupWarning = nil;
    }
    if (error) {
        *error = nil;
    }
    if (self.commitAttempted) {
        return PXAppGroupRestoreFail(error,
                                     PXAppGroupRestoreTransactionErrorInvalidInput,
                                     @"$",
                                     @"The App Group transaction is one-shot.");
    }
    self.commitAttempted = YES;
    if (![self revalidatePreparedBatchWithError:error] ||
        ![self prepareWorkspacesWithError:error]) {
        return NO;
    }
    NSError *operationError = nil;
    if (![self quarantineWholeBatchWithError:&operationError] ||
        ![self installWholeBatchWithError:&operationError] ||
        ![self publishCommittedDecisionWithError:&operationError]) {
        NSError *rollbackFailure = nil;
        if (![self rollbackPreparedBatchWithCleanupWarning:cleanupWarning
                                                      error:&rollbackFailure]) {
            if (error) {
                *error = rollbackFailure;
            }
            return NO;
        }
        if (error) {
            *error = operationError ?:
                [NSError errorWithDomain:PXAppGroupRestoreTransactionErrorDomain
                                    code:PXAppGroupRestoreTransactionErrorCommitFailed
                                userInfo:@{
                                    NSLocalizedDescriptionKey: @"The App Group transaction failed before its durable decision.",
                                    PXAppGroupRestoreTransactionErrorFieldPathKey: @"$.transaction.commit"
                                }];
        }
        return NO;
    }
    NSError *cleanupError = nil;
    if (!PXAppGroupRestoreCleanupBatch(self.participants, &cleanupError) && cleanupWarning) {
        *cleanupWarning = cleanupError;
    }
    return YES;
}

- (void)dealloc {
    if (self.prepared && !self.committed && !self.rollbackComplete) {
        NSError *rollbackError = nil;
        if (PXAppGroupRestoreRollbackBatch(self.participants,
                                           self.batchIdentifier,
                                           &rollbackError)) {
            self.rollbackPerformed = YES;
            self.rollbackComplete = YES;
            PXAppGroupRestoreCleanupBatch(self.participants, nil);
        }
    }
    PXAppGroupRestoreCloseAllDescriptors(self.participants);
}

@end
