#import "PXRuntimeSourceStore.h"
#import "PXRuntimePublisher.h"
#include <sys/file.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>

static const NSUInteger kPXSourceSizeLimit = 32 * 1024 * 1024;
static NSError *PXSourceError(NSString *message) {
    return [NSError errorWithDomain:@"com.hydra.tlinkios.runtime-source" code:1
                          userInfo:@{NSLocalizedDescriptionKey: message ?: @"Source transaction failed"}];
}
static double PXSourceNow(void) {
    struct timespec ts = {0}; clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}
static id PXSourceReadPlist(NSString *path, BOOL *absent, NSData **bytes, mode_t *mode, NSError **error) {
    struct stat st = {0};
    if (lstat(path.fileSystemRepresentation, &st) != 0) {
        if (errno == ENOENT) { if (absent) *absent = YES; return nil; }
        if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        return nil;
    }
    // Journal includes bounded before-images plus plist/path overhead.
    if (!S_ISREG(st.st_mode) || st.st_size < 0 || st.st_size > (off_t)(2 * kPXSourceSizeLimit)) {
        if (error) *error = PXSourceError(@"Source must be a bounded regular file"); return nil;
    }
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (bytes) *bytes = data;
    if (mode) *mode = st.st_mode & 0777;
    return data ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:error] : nil;
}

@interface PXRuntimeSourceTransaction ()
@property (nonatomic, copy) BOOL (^allowsPath)(NSString *);
// NSNull is an in-memory removal marker; it is never serialized to the journal.
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *staged;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *stagedSizes;
@property (nonatomic) NSUInteger stagedBytes;
@property (nonatomic, strong) NSError *failure;
@property (nonatomic, strong) NSThread *thread;
@property (nonatomic) BOOL active;
- (instancetype)initForPaths:(BOOL (^)(NSString *))allowsPath;
- (BOOL)checkPath:(NSString *)path error:(NSError **)error;
@end
@implementation PXRuntimeSourceTransaction
- (instancetype)initForPaths:(BOOL (^)(NSString *))allowsPath {
    if (!(self = [super init])) return nil;
    _allowsPath = [allowsPath copy]; _staged = [NSMutableDictionary dictionary];
    _stagedSizes = [NSMutableDictionary dictionary];
    _thread = NSThread.currentThread; _active = YES;
    return self;
}
- (BOOL)checkPath:(NSString *)path error:(NSError **)error {
    if (self.thread != NSThread.currentThread) {
        if (error) *error = PXSourceError(@"Source transaction used from another thread"); return NO;
    }
    if (!self.active || ![path isKindOfClass:NSString.class] ||
        !path.isAbsolutePath || ![path isEqual:path.stringByStandardizingPath] || !self.allowsPath(path)) {
        self.failure = PXSourceError(@"Inactive transaction, wrong thread, or unapproved source path");
        if (error) *error = self.failure; return NO;
    }
    return YES;
}
- (NSDictionary *)dictionaryAtPath:(NSString *)path error:(NSError **)error {
    return [self dictionaryAtPath:path exists:NULL error:error];
}
- (NSDictionary *)dictionaryAtPath:(NSString *)path exists:(BOOL *)exists error:(NSError **)error {
    if (exists) *exists = NO;
    if (![self checkPath:path error:error]) return nil;
    if (self.staged[path] == NSNull.null) return @{};
    if (self.staged[path]) { if (exists) *exists = YES; return self.staged[path]; }
    BOOL absent = NO; NSError *failure = nil;
    id value = PXSourceReadPlist(path, &absent, NULL, NULL, &failure);
    if (absent) return @{};
    if (![value isKindOfClass:NSDictionary.class]) {
        self.failure = failure ?: PXSourceError(@"Malformed source dictionary");
        if (error) *error = self.failure; return nil;
    }
    if (exists) *exists = YES;
    return value;
}
- (BOOL)setDictionary:(NSDictionary *)value atPath:(NSString *)path error:(NSError **)error {
    if (![self checkPath:path error:error]) return NO;
    NSError *failure = nil;
    NSData *data = [value isKindOfClass:NSDictionary.class] ? [NSPropertyListSerialization dataWithPropertyList:value
        format:NSPropertyListBinaryFormat_v1_0 options:0 error:&failure] : nil;
    NSUInteger nextSize = self.stagedBytes - [self.stagedSizes[path] unsignedIntegerValue] + data.length;
    if (!data || nextSize > kPXSourceSizeLimit) {
        self.failure = failure ?: PXSourceError(@"Invalid or oversized staged dictionary");
        if (error) *error = self.failure; return NO;
    }
    self.staged[path] = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&failure];
    if (failure) { self.failure = failure; if (error) *error = failure; return NO; }
    self.stagedBytes = nextSize; self.stagedSizes[path] = @(data.length);
    return YES;
}
- (BOOL)removeDictionaryAtPath:(NSString *)path error:(NSError **)error {
    if (![self checkPath:path error:error]) return NO;
    self.stagedBytes -= [self.stagedSizes[path] unsignedIntegerValue];
    self.stagedSizes[path] = @0;
    self.staged[path] = NSNull.null;
    return YES;
}
@end

@interface PXRuntimeSourceStore () {
    NSString *_directory;
    uid_t _owner;
    gid_t _group;
    int _lockFD;
    NSRecursiveLock *_threadLock;
    BOOL (^_allowsPath)(NSString *);
    PXRuntimeSourceTransaction *_activeTransaction;
    BOOL _inCapture;
}
@end

@implementation PXRuntimeSourceStore
- (instancetype)initWithDirectory:(NSString *)directory owner:(uid_t)owner group:(gid_t)group
                       allowsPath:(BOOL (^)(NSString *))allowsPath error:(NSError **)error {
    if (!(self = [super init])) return nil;
    _lockFD = -1;
    if (!directory.isAbsolutePath || !allowsPath) { if (error) *error = PXSourceError(@"Invalid source store configuration"); return nil; }
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:@{
        NSFilePosixPermissions: @0700, NSFileOwnerAccountID: @(owner), NSFileGroupOwnerAccountID: @(group) } error:error]) return nil;
    struct stat st = {0};
    if (lstat(directory.fileSystemRepresentation, &st) != 0 || !S_ISDIR(st.st_mode) || st.st_uid != owner ||
        (st.st_mode & 0777) != 0700) {
        if (error) *error = PXSourceError(@"Source store must be an owner-only directory"); return nil;
    }
    NSString *lockPath = [directory stringByAppendingPathComponent:@"source.lock"];
    int fd = open(lockPath.fileSystemRepresentation, O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0600);
    BOOL created = fd >= 0;
    if (fd < 0 && errno == EEXIST) fd = open(lockPath.fileSystemRepresentation, O_RDWR | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) { if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil]; return nil; }
    if (fstat(fd, &st) != 0) {
        int failure = errno; close(fd);
        if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:failure userInfo:nil]; return nil;
    }
    if (created && (((st.st_uid != owner || st.st_gid != group) && fchown(fd, owner, group) != 0) || fchmod(fd, 0600) != 0)) {
        int failure = errno; close(fd);
        if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:failure userInfo:nil]; return nil;
    }
    if (fstat(fd, &st) != 0 || !S_ISREG(st.st_mode) || st.st_uid != owner || st.st_nlink != 1 || (st.st_mode & 0777) != 0600) {
        close(fd); if (error) *error = PXSourceError(@"Unsafe source lock inode"); return nil;
    }
    _lockFD = fd; _directory = [directory copy]; _owner = owner; _group = group;
    _allowsPath = [allowsPath copy]; _threadLock = [NSRecursiveLock new];
    return self;
}
- (void)dealloc { if (_lockFD >= 0) close(_lockFD); }
- (NSString *)journalPath { return [_directory stringByAppendingPathComponent:@"pending.plist"]; }
- (NSString *)commitPath { return [_directory stringByAppendingPathComponent:@"commit.plist"]; }
- (BOOL)enterBefore:(double)deadline error:(NSError **)error {
    while (![_threadLock tryLock]) {
        if (PXSourceNow() >= deadline) { if (error) *error = PXSourceError(@"Timed out waiting for source thread gate"); return NO; }
        usleep(5000);
    }
    return YES;
}
- (BOOL)lockFile:(int)operation before:(double)deadline error:(NSError **)error {
    while (flock(_lockFD, operation | LOCK_NB) != 0) {
        int failure = errno;
        if (failure != EWOULDBLOCK && failure != EAGAIN && failure != EINTR) {
            if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:failure userInfo:nil]; return NO;
        }
        if (PXSourceNow() >= deadline) { if (error) *error = PXSourceError(@"Timed out waiting for source file gate"); return NO; }
        usleep(5000);
    }
    return YES;
}
- (NSDictionary *)commitRecord:(NSError **)error {
    BOOL absent = NO; NSError *failure = nil;
    id record = PXSourceReadPlist(self.commitPath, &absent, NULL, NULL, &failure);
    if (absent) return @{}; // Explicit legacy state, not a malformed commit.
    NSString *identifier = [record isKindOfClass:NSDictionary.class] && [record[@"commitID"] isKindOfClass:NSString.class] ? record[@"commitID"] : nil;
    if (!identifier.length || ![[NSUUID alloc] initWithUUIDString:identifier] || ![record[@"schemaVersion"] isEqual:@1]) {
        if (error) *error = failure ?: PXSourceError(@"Malformed source commit record"); return nil;
    }
    return record;
}
- (BOOL)checkPaths:(NSArray<NSDictionary *> *)entries error:(NSError **)error {
    NSMutableSet *seen = [NSMutableSet set];
    NSUInteger size = 0;
    if (![entries isKindOfClass:NSArray.class] || entries.count > 256) { if (error) *error = PXSourceError(@"Invalid source journal entries"); return NO; }
    for (id entry in entries) {
        NSString *path = [entry isKindOfClass:NSDictionary.class] && [entry[@"path"] isKindOfClass:NSString.class] ? entry[@"path"] : nil;
        id existed = [entry isKindOfClass:NSDictionary.class] ? entry[@"existed"] : nil;
        id data = [entry isKindOfClass:NSDictionary.class] ? entry[@"data"] : nil;
        id mode = [entry isKindOfClass:NSDictionary.class] ? entry[@"mode"] : nil;
        if (!path.isAbsolutePath || ![path isEqual:path.stringByStandardizingPath] || !_allowsPath(path) || [seen containsObject:path] ||
            (![existed isEqual:@YES] && ![existed isEqual:@NO]) || ![data isKindOfClass:NSData.class] ||
            ![mode isKindOfClass:NSNumber.class] || [mode unsignedLongLongValue] > 0777) {
            if (error) *error = PXSourceError(@"Unapproved or malformed journal entry"); return NO;
        }
        size += [data length];
        if (size > kPXSourceSizeLimit) { if (error) *error = PXSourceError(@"Oversized journal"); return NO; }
        if ([existed boolValue]) {
            id original = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
            if (![original isKindOfClass:NSDictionary.class]) {
                if (error) *error = PXSourceError(@"Malformed journal before-image"); return NO;
            }
        } else if ([data length]) { if (error) *error = PXSourceError(@"Absent source has unexpected before-image"); return NO; }
        [seen addObject:path];
    }
    return YES;
}
- (BOOL)restoreEntries:(NSArray<NSDictionary *> *)entries error:(NSError **)error {
    // Validate the COMPLETE journal before touching any source, including paths
    // that occur after the first legitimate entry.
    if (![self checkPaths:entries error:error]) return NO;
    for (NSDictionary *entry in entries) {
        NSString *path = entry[@"path"];
        if ([entry[@"existed"] boolValue]) {
            if (![entry[@"data"] writeToFile:path options:NSDataWritingAtomic error:error]) return NO;
            if (chmod(path.fileSystemRepresentation, [entry[@"mode"] unsignedShortValue]) != 0) {
                if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil]; return NO;
            }
        } else {
            if (unlink(path.fileSystemRepresentation) != 0 && errno != ENOENT) {
                if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil]; return NO;
            }
        }
#if defined(PX_SOURCE_TRANSACTION_TESTING)
        if (self.testCheckpoint) self.testCheckpoint(@"recovery-source-written");
#endif
    }
    return YES;
}
- (NSDictionary *)journalRecord:(BOOL *)absent error:(NSError **)error {
    NSError *failure = nil;
    id journal = PXSourceReadPlist(self.journalPath, absent, NULL, NULL, &failure);
    if (*absent) return nil;
    NSString *identifier = [journal isKindOfClass:NSDictionary.class] && [journal[@"transactionID"] isKindOfClass:NSString.class] ? journal[@"transactionID"] : nil;
    if (!identifier.length || ![[NSUUID alloc] initWithUUIDString:identifier] || ![journal[@"schemaVersion"] isEqual:@1] ||
        ![self checkPaths:journal[@"entries"] error:&failure]) {
        if (error) *error = failure ?: PXSourceError(@"Malformed source journal; recovery refused"); return nil;
    }
    return journal;
}
- (BOOL)recover:(NSError **)error {
    BOOL absent = NO; NSError *failure = nil;
    NSDictionary *journal = [self journalRecord:&absent error:&failure];
    if (absent) return YES;
    if (!journal) { if (error) *error = failure; return NO; }
    NSString *identifier = journal[@"transactionID"];
    NSDictionary *commit = [self commitRecord:&failure];
    if (!commit) { if (error) *error = failure; return NO; }
    // Crash after commit-marker rename is committed. Every earlier crash rolls
    // back; the journal stays until the entire restore succeeds (idempotent).
    if (![commit[@"commitID"] isEqual:identifier] && ![self restoreEntries:journal[@"entries"] error:error]) return NO;
    return [NSFileManager.defaultManager removeItemAtPath:self.journalPath error:error];
}
- (BOOL)commitTransaction:(PXRuntimeSourceTransaction *)transaction error:(NSError **)error {
    if (!transaction.staged.count) return YES;
    if (transaction.staged.count > 256) { if (error) *error = PXSourceError(@"Too many source files in a transaction"); return NO; }
    NSMutableArray *entries = [NSMutableArray array];
    NSArray<NSString *> *paths = [transaction.staged.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *path in paths) {
        // Capture raw bytes for writes AND removals, preserving exact rollback,
        // including absence. Existing malformed files are never silently blessed.
        BOOL absent = NO; NSError *failure = nil;
        NSData *data = nil; mode_t mode = 0644;
        id original = PXSourceReadPlist(path, &absent, &data, &mode, &failure);
        if (!absent && ![original isKindOfClass:NSDictionary.class]) { if (error) *error = failure ?: PXSourceError(@"Malformed source before commit"); return NO; }
        if (absent) data = [NSData data];
        if (!data) { if (error) *error = failure; return NO; }
        [entries addObject:@{ @"path": path, @"existed": @(!absent), @"data": data,
                             @"mode": @((unsigned)mode) }];
    }
    if (![self checkPaths:entries error:error]) return NO;
    NSString *identifier = NSUUID.UUID.UUIDString;
    NSDictionary *journal = @{ @"schemaVersion": @1, @"transactionID": identifier, @"entries": entries };
    if (!PXRuntimeWritePropertyList(journal, self.journalPath, _owner, _group, 0600, error)) return NO;
    @try {
#if defined(PX_SOURCE_TRANSACTION_TESTING)
        if (self.testCheckpoint) self.testCheckpoint(@"journal-prepared");
#endif
        for (NSDictionary *entry in entries) {
            NSString *path = entry[@"path"];
            if (transaction.staged[path] == NSNull.null) {
                if (unlink(path.fileSystemRepresentation) != 0 && errno != ENOENT) {
                    if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
                    return NO;
                }
            } else if (!PXRuntimeWritePropertyList(transaction.staged[path], path, _owner, _group,
                                                 [entry[@"mode"] unsignedShortValue], error)) return NO;
#if defined(PX_SOURCE_TRANSACTION_TESTING)
            if (self.testCheckpoint) self.testCheckpoint(@"source-written");
#endif
        }
        NSDictionary *commit = @{ @"schemaVersion": @1, @"commitID": identifier };
        if (!PXRuntimeWritePropertyList(commit, self.commitPath, _owner, _group, 0600, error)) return NO;
#if defined(PX_SOURCE_TRANSACTION_TESTING)
        if (self.testCheckpoint) self.testCheckpoint(@"commit-written");
#endif
        // Marker is the boundary. A failed cleanup leaves a committed journal
        // for the next writer; do not report an aborted operation after commit.
        [NSFileManager.defaultManager removeItemAtPath:self.journalPath error:nil];
        return YES;
    } @finally {
        // On pre-commit failure/exception, recover immediately. If I/O still
        // fails, keep the journal: publisher capture must stay unavailable.
        [self recover:NULL];
    }
}
- (BOOL)performWrite:(BOOL (^)(PXRuntimeSourceTransaction *, NSError **))body error:(NSError **)error {
    if (geteuid() != _owner) { if (error) *error = PXSourceError(@"Only the source owner may write or recover"); return NO; }
    double deadline = PXSourceNow() + 1.0;
    if (!body || ![self enterBefore:deadline error:error]) return NO;
    BOOL locked = NO;
    @try {
        if (_inCapture) { if (error) *error = PXSourceError(@"Source write during capture rejected"); return NO; }
        if (_activeTransaction) {
            NSError *failure = nil;
            BOOL success = body(_activeTransaction, &failure);
            if (!success) _activeTransaction.failure = failure ?: PXSourceError(@"Nested write aborted");
            if (_activeTransaction.failure && error) *error = _activeTransaction.failure;
            return success && !_activeTransaction.failure;
        }
        if (!(locked = [self lockFile:LOCK_EX before:deadline error:error]) || ![self recover:error] || ![self commitRecord:error]) return NO;
        _activeTransaction = [[PXRuntimeSourceTransaction alloc] initForPaths:_allowsPath];
        NSError *failure = nil;
        BOOL success = body(_activeTransaction, &failure);
        if (!success || _activeTransaction.failure) {
            if (error) *error = _activeTransaction.failure ?: failure ?: PXSourceError(@"Source write aborted"); return NO;
        }
        return [self commitTransaction:_activeTransaction error:error];
    } @catch (NSException *exception) {
        if (_activeTransaction) _activeTransaction.failure = PXSourceError(exception.reason);
        if (error) *error = PXSourceError(exception.reason); return NO;
    } @finally {
        if (locked) {
            _activeTransaction.active = NO; _activeTransaction = nil;
            flock(_lockFD, LOCK_UN);
        }
        [_threadLock unlock];
    }
}
- (NSDictionary *)capture:(NSDictionary *(^)(NSError **))loader error:(NSError **)error {
    double deadline = PXSourceNow() + 1.0;
    if (!loader || ![self enterBefore:deadline error:error]) return nil;
    BOOL locked = NO;
    @try {
        if (_activeTransaction || _inCapture) { if (error) *error = PXSourceError(@"Reentrant source capture rejected"); return nil; }
        if (!(locked = [self lockFile:LOCK_SH before:deadline error:error])) return nil;
        NSDictionary *commit = [self commitRecord:error];
        if (!commit) return nil;
        BOOL absent = NO;
        NSDictionary *journal = [self journalRecord:&absent error:error];
        if (!absent && (!journal || ![journal[@"transactionID"] isEqual:commit[@"commitID"]])) {
            if (journal && error) *error = PXSourceError(@"Source transaction pending recovery"); return nil;
        }
        _inCapture = YES;
        NSDictionary *loaded = loader(error);
        if (![loaded isKindOfClass:NSDictionary.class]) return nil;
        NSMutableDictionary *candidate = [loaded mutableCopy];
        candidate[@"sourceState"] = commit.count ? @"committed" : @"legacy";
        if (commit[@"commitID"]) candidate[@"sourceCommitID"] = commit[@"commitID"];
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:candidate format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
        return data ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:error] : nil;
    } @catch (NSException *exception) {
        if (error) *error = PXSourceError(exception.reason); return nil;
    } @finally {
        if (locked) { _inCapture = NO; flock(_lockFD, LOCK_UN); }
        [_threadLock unlock];
    }
}
@end
