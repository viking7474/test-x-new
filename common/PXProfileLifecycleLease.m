#import "PXProfileLifecycleLease.h"
#import "PXPaths.h"
#include <errno.h>
#include <fcntl.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>

static BOOL PXProfileLeaseError(NSError **error, NSInteger code, NSString *message) {
    if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}
@interface PXProfileLifecycleLease () {
    int _rootFD, _lockFD;
}
@property (nonatomic, copy) NSString *directory;
- (instancetype)initForLease;
@end
@implementation PXProfileLifecycleLease
- (instancetype)initForLease {
    if ((self = [super init])) _rootFD = _lockFD = -1;
    return self;
}
+ (instancetype)acquireInDirectory:(NSString *)directory error:(NSError **)error {
    if (!directory.isAbsolutePath) { PXProfileLeaseError(error, 25, @"Invalid profile registry directory"); return nil; }
    PXProfileLifecycleLease *lease = [[self alloc] initForLease]; lease.directory = directory;
    lease->_rootFD = open(directory.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (lease->_rootFD < 0) { PXProfileLeaseError(error, 25, @"Profile registry directory is unavailable"); return nil; }
    lease->_lockFD = openat(lease->_rootFD, ".profile-lifecycle.lock", O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK, 0600);
    struct stat lock;
    if (lease->_lockFD < 0 || fstat(lease->_lockFD, &lock) != 0 || !S_ISREG(lock.st_mode) || lock.st_nlink != 1 || lock.st_uid != geteuid()) {
        PXProfileLeaseError(error, 25, @"Profile lifecycle lock is invalid or has a different owner"); return nil;
    }
    if (fchmod(lease->_lockFD, 0600) != 0) { PXProfileLeaseError(error, 25, @"Cannot secure profile lifecycle lock permissions"); return nil; }
    int result;
    do { result = flock(lease->_lockFD, LOCK_EX | LOCK_NB); } while (result != 0 && errno == EINTR);
    if (result != 0) {
        BOOL busy = errno == EWOULDBLOCK || errno == EAGAIN;
        PXProfileLeaseError(error, busy ? 12 : 25, busy ? @"Another instance is changing profiles; retry after it finishes" : @"Cannot acquire profile lifecycle ownership"); return nil;
    }
    if (![lease validateWithError:error]) return nil;
    return lease;
}
- (BOOL)validateWithError:(NSError **)error {
    struct stat root, path, lock, lockPath;
    if (_rootFD < 0 || _lockFD < 0 || fstat(_rootFD, &root) != 0 || stat(self.directory.fileSystemRepresentation, &path) != 0 ||
        !S_ISDIR(root.st_mode) || !S_ISDIR(path.st_mode) || root.st_dev != path.st_dev || root.st_ino != path.st_ino ||
        fstat(_lockFD, &lock) != 0 || fstatat(_rootFD, ".profile-lifecycle.lock", &lockPath, AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISREG(lockPath.st_mode) || lock.st_nlink != 1 || lock.st_dev != lockPath.st_dev || lock.st_ino != lockPath.st_ino)
        return PXProfileLeaseError(error, 25, @"Profile lifecycle root or lock was replaced");
    return YES;
}
- (NSDictionary *)readRegistryWithError:(NSError **)error {
    if (![self validateWithError:error]) return nil;
    int fd = openat(_rootFD, "profiles.plist", O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
    if (fd < 0) {
        if (errno == ENOENT) return @{ @"exists": @NO };
        PXProfileLeaseError(error, 25, @"Cannot read the current profile registry"); return nil;
    }
    @try {
        struct stat before, after;
        BOOL valid = fstat(fd, &before) == 0 && S_ISREG(before.st_mode) && before.st_nlink == 1 && before.st_size >= 0;
        NSMutableData *data = valid ? [NSMutableData dataWithLength:(NSUInteger)before.st_size] : nil;
        NSUInteger offset = 0;
        while (valid && offset < data.length) {
            ssize_t count = read(fd, (uint8_t *)data.mutableBytes + offset, data.length - offset);
            if (count < 0 && errno == EINTR) continue;
            if (count <= 0) { valid = NO; break; }
            offset += (NSUInteger)count;
        }
        valid = valid && fstatat(_rootFD, "profiles.plist", &after, AT_SYMLINK_NOFOLLOW) == 0 && S_ISREG(after.st_mode) &&
            before.st_dev == after.st_dev && before.st_ino == after.st_ino && before.st_size == after.st_size;
        if (!valid || ![self validateWithError:error]) { PXProfileLeaseError(error, 25, @"Profile registry is invalid or changed while reading"); return nil; }
        return @{ @"exists": @YES, @"bytes": [data copy] };
    } @finally { close(fd); }
}
- (BOOL)validateForDirectory:(NSString *)directory error:(NSError **)error {
    if (![self validateWithError:error]) return NO;
    struct stat owned, requested;
    if (!directory.isAbsolutePath || fstat(_rootFD, &owned) != 0 || stat(directory.fileSystemRepresentation, &requested) != 0 ||
        !S_ISDIR(requested.st_mode) || owned.st_dev != requested.st_dev || owned.st_ino != requested.st_ino)
        return PXProfileLeaseError(error, 25, @"Lifecycle capability belongs to a different profiles root");
    return YES;
}
- (BOOL)writeRegistryData:(NSData *)data expected:(NSDictionary *)expected error:(NSError **)error {
    NSDictionary *observed = [self readRegistryWithError:error];
    if (!observed) return NO;
    if (![observed isEqual:expected]) return PXProfileLeaseError(error, 25, @"Profile registry changed; reload before writing");
    if (![data writeToFile:[self.directory stringByAppendingPathComponent:@"profiles.plist"] options:NSDataWritingAtomic error:error]) return NO;
    // Atomic replacement preserves the last archive on write failure. Never
    // unlink it or compensate by overwriting a newer, unrecognized registry.
    NSDictionary *written = [self readRegistryWithError:error];
    if (![written[@"bytes"] isEqual:data]) return PXProfileLeaseError(error, 25, @"Profile registry changed after replacement");
    return YES;
}
- (NSDictionary *)directoryProofForProfileID:(NSString *)profileID error:(NSError **)error {
    if (![PXValidatedProfileID(profileID) isEqual:profileID]) { PXProfileLeaseError(error, 25, @"Invalid profile deletion ID"); return nil; }
    if (![self validateWithError:error]) return nil;
    struct stat directory;
    if (fstatat(_rootFD, profileID.fileSystemRepresentation, &directory, AT_SYMLINK_NOFOLLOW) != 0) {
        if (errno == ENOENT) return @{ @"exists": @NO };
        PXProfileLeaseError(error, 25, @"Cannot inspect profile directory before deletion"); return nil;
    }
    if (!S_ISDIR(directory.st_mode)) { PXProfileLeaseError(error, 25, @"Deletion target is not a plain profile directory"); return nil; }
    return @{ @"exists": @YES, @"device": @((unsigned long long)directory.st_dev), @"inode": @((unsigned long long)directory.st_ino) };
}
- (BOOL)removeDirectoryForProfileID:(NSString *)profileID proof:(NSDictionary *)proof error:(NSError **)error {
    NSDictionary *observed = [self directoryProofForProfileID:profileID error:error];
    if (!observed) return NO;
    if (![observed isEqual:proof]) return PXProfileLeaseError(error, 25, @"Deletion target was replaced; preserving the new directory");
    if (![proof[@"exists"] boolValue]) return YES;
    return [NSFileManager.defaultManager removeItemAtPath:[self.directory stringByAppendingPathComponent:profileID] error:error];
}
- (void)invalidate {
    // close releases flock on every return/exception/process-exit path.
    if (_lockFD >= 0) { close(_lockFD); _lockFD = -1; }
    if (_rootFD >= 0) { close(_rootFD); _rootFD = -1; }
}
- (void)dealloc { [self invalidate]; }
@end
