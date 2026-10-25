#import "PXRuntimePublisher.h"
#import <dispatch/dispatch.h>
#import <notify.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

NSString * const PXRuntimeSyncRequestedNotification = @"com.hydra.tlinkios.runtimeSyncRequested";
static char kPXPublisherQueue;

static NSError *PXPublisherError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"com.hydra.tlinkios.runtime-publication" code:code
                          userInfo:@{NSLocalizedDescriptionKey: message ?: @"Publication failed"}];
}
static NSTimeInterval PXPublisherNow(void) {
    struct timespec ts = {0};
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}
static NSDictionary *PXPublisherFailure(NSError *error) {
    return @{ @"success": @NO, @"globalCommitted": @NO, @"distributionComplete": @NO,
              @"notified": @NO, @"snapshot": @{}, @"stats": @{},
              @"error": error.localizedDescription ?: @"Publication failed" };
}

BOOL PXRuntimeWritePropertyList(NSDictionary *value, NSString *path,
                               uid_t owner, gid_t group, mode_t mode, NSError **error) {
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:value
        format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
    if (!data || !path.length) return NO;
    // mkstemp reserves a unique inode; never remove/reuse another call's temp.
    char *temporary = strdup([[path stringByAppendingString:@".tmp.XXXXXX"] fileSystemRepresentation]);
    int fd = temporary ? mkstemp(temporary) : -1;
    if (fd < 0) {
        if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        free(temporary); return NO;
    }
    int failure = 0;
    struct stat st = {0};
    if (fstat(fd, &st) != 0) failure = errno;
    if (!failure && (st.st_uid != owner || st.st_gid != group) && fchown(fd, owner, group) != 0) failure = errno;
    if (!failure && fchmod(fd, mode) != 0) failure = errno;
    const uint8_t *bytes = data.bytes;
    NSUInteger remaining = data.length;
    while (!failure && remaining) {
        ssize_t count = write(fd, bytes, remaining);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) { failure = count == 0 ? EIO : errno; break; }
        bytes += count; remaining -= (NSUInteger)count;
    }
    if (close(fd) != 0 && !failure) failure = errno;
    if (!failure && rename(temporary, path.fileSystemRepresentation) != 0) failure = errno;
    if (failure) {
        unlink(temporary);
        if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:failure userInfo:nil];
    }
    free(temporary);
    return failure == 0;
}

@interface PXRuntimePublisher () {
    NSString *_directory;
    int _leaseFD;
    NSString *_epoch;
    uint64_t _revision;
    dispatch_queue_t _queue;
    dispatch_source_t _source;
    PXRuntimePublicationLoader _loader;
    PXRuntimePublicationWriter _writer;
    PXRuntimePublicationDistributor _distributor;
    PXRuntimePublicationNotifier _notifier;
    void (^_completion)(NSDictionary *);
    NSDictionary *_pendingSnapshot;
    NSTimeInterval _nextRetry;
    NSUInteger _retryCount;
    BOOL _needsPublication;
}
- (void)drain:(unsigned long)flags;
@end

@implementation PXRuntimePublisher
- (instancetype)initWithDirectory:(NSString *)directory loader:(PXRuntimePublicationLoader)loader
                           writer:(PXRuntimePublicationWriter)writer
                      distributor:(PXRuntimePublicationDistributor)distributor
                         notifier:(PXRuntimePublicationNotifier)notifier
                       completion:(void (^)(NSDictionary *))completion error:(NSError **)error {
    if (!(self = [super init])) return nil;
    _leaseFD = -1;
    if (!directory.length || !loader || !writer || !distributor || !notifier) {
        if (error) *error = PXPublisherError(1, @"Missing publisher dependency");
        return nil;
    }
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm createDirectoryAtPath:directory withIntermediateDirectories:YES
                        attributes:@{NSFilePosixPermissions: @0700} error:error]) return nil;
    struct stat st = {0};
    if (lstat(directory.fileSystemRepresentation, &st) != 0 || !S_ISDIR(st.st_mode) || st.st_uid != geteuid() ||
        chmod(directory.fileSystemRepresentation, 0700) != 0) {
        if (error) *error = PXPublisherError(2, @"Publisher directory must be owned by the current privileged user");
        return nil;
    }
    _directory = [directory copy];
    _loader = [loader copy]; _writer = [writer copy];
    _distributor = [distributor copy]; _notifier = [notifier copy]; _completion = [completion copy];
    _queue = dispatch_queue_create("com.hydra.tlinkios.runtime-publisher", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(_queue, &kPXPublisherQueue, (__bridge void *)self, NULL);
    _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_OR, 0, 0, _queue);
    __weak PXRuntimePublisher *weakSelf = self;
    dispatch_source_set_event_handler(_source, ^{
        PXRuntimePublisher *publisher = weakSelf;
        if (publisher) [publisher drain:dispatch_source_get_data(publisher->_source)];
    });
    dispatch_resume(_source);
    return self;
}
- (void)dealloc {
    if (_source) dispatch_source_cancel(_source);
    if (_leaseFD >= 0) close(_leaseFD);
}
- (BOOL)onQueue { return dispatch_get_specific(&kPXPublisherQueue) == (__bridge void *)self; }
- (BOOL)acquireOnQueue:(NSError **)error {
    if (_leaseFD >= 0) return YES;
    NSString *path = [_directory stringByAppendingPathComponent:@"publisher.lock"];
    int fd = open(path.fileSystemRepresentation, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, 0600);
    if (fd < 0) {
        if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        return NO;
    }
    struct stat st = {0};
    if (fstat(fd, &st) != 0 || !S_ISREG(st.st_mode) || st.st_uid != geteuid() || st.st_nlink != 1) {
        close(fd); if (error) *error = PXPublisherError(3, @"Unsafe publisher lock inode"); return NO;
    }
    if (flock(fd, LOCK_EX | LOCK_NB) != 0) {
        int failure = errno; close(fd);
        if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:failure userInfo:nil];
        return NO;
    }
    _leaseFD = fd;
    _epoch = NSUUID.UUID.UUIDString;
    _revision = 0;
    return YES;
}
- (BOOL)tryAcquireOwnership:(NSError **)error {
    if ([self onQueue]) return [self acquireOnQueue:error];
    __block BOOL acquired;
    __block NSError *failure;
    dispatch_sync(_queue, ^{ acquired = [self acquireOnQueue:&failure]; });
    if (!acquired && error) *error = failure;
    return acquired;
}
- (NSDictionary *)distribute:(NSDictionary *)snapshot {
    NSDictionary *stats;
    @try { stats = _distributor(snapshot) ?: @{}; }
    @catch (NSException *exception) {
        stats = @{ @"complete": @NO, @"error": exception.reason ?: @"Distribution exception" };
    }
    BOOL complete = [stats[@"complete"] boolValue];
    NSError *error = nil;
    // Readers are woken after distribution attempts, including partial failure:
    // updated/revoked containers must not wait for an unrelated broken target.
    BOOL notified = NO;
    @try { notified = _notifier(&error); }
    @catch (NSException *exception) { error = PXPublisherError(9, exception.reason); }
    BOOL success = complete && notified;
    _pendingSnapshot = success ? nil : snapshot;
    if (!success) {
        _retryCount = MIN(_retryCount + 1, (NSUInteger)5);
        _nextRetry = PXPublisherNow() + (double)(1u << _retryCount); // 2..32s, existing timer only
    } else { _retryCount = 0; }
    NSDictionary *result = @{ @"success": @(success), @"globalCommitted": @YES,
        @"distributionComplete": @(complete), @"notified": @(notified),
        @"snapshot": snapshot, @"stats": stats,
        @"error": complete ? (error.localizedDescription ?: @"") : @"Runtime mirror distribution incomplete" };
    if (_completion) _completion(result);
    return result;
}
- (NSDictionary *)failedPublication:(NSError *)error {
    _needsPublication = YES;
    _retryCount = MIN(_retryCount + 1, (NSUInteger)5);
    _nextRetry = PXPublisherNow() + (double)(1u << _retryCount);
    NSDictionary *result = PXPublisherFailure(error);
    if (_completion) _completion(result);
    return result;
}
- (NSDictionary *)publishOnQueue {
    if (_leaseFD < 0) return PXPublisherFailure(PXPublisherError(4, @"Publisher ownership required"));
    // A new candidate supersedes every retry of the previous publication.
    _pendingSnapshot = nil; _needsPublication = NO;
    if (_revision == UINT64_MAX) return PXPublisherFailure(PXPublisherError(5, @"Publication revision exhausted"));
    uint64_t revision = ++_revision; // failed attempts may leave gaps; never reuse an identity
    NSError *error = nil;
    NSDictionary *snapshot;
    @try {
        NSDictionary *loaded = _loader(&error);
        if (![loaded isKindOfClass:NSDictionary.class]) return [self failedPublication:error];
        NSMutableDictionary *candidate = [loaded mutableCopy];
        candidate[@"schemaVersion"] = @2;
        candidate[@"publisherEpoch"] = _epoch;
        candidate[@"revision"] = @(revision);
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:candidate
            format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
        snapshot = data ? [NSPropertyListSerialization propertyListWithData:data
            options:NSPropertyListImmutable format:NULL error:&error] : nil;
        if (!snapshot || !_writer(snapshot, &error)) return [self failedPublication:error];
    } @catch (NSException *exception) {
        return [self failedPublication:PXPublisherError(9, exception.reason)];
    }
    _retryCount = 0;
    return [self distribute:snapshot];
}
- (NSDictionary *)publishNow {
    if ([self onQueue]) return PXPublisherFailure(PXPublisherError(6, @"Reentrant publication rejected"));
    __block NSDictionary *result;
    dispatch_sync(_queue, ^{ @autoreleasepool { result = [self publishOnQueue]; } });
    return result;
}
- (void)requestPublication { dispatch_source_merge_data(_source, 1); }
- (void)serviceRequestsAndRetry { dispatch_source_merge_data(_source, 2); }
- (NSArray<NSString *> *)requestsOnQueue {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSMutableArray *requests = [NSMutableArray array];
    for (NSString *name in [fm contentsOfDirectoryAtPath:_directory error:nil]) {
        if (![name hasSuffix:@".request.plist"] && ![name hasSuffix:@".ack.plist"]) continue;
        NSString *path = [_directory stringByAppendingPathComponent:name];
        NSDictionary *attributes = [fm attributesOfItemAtPath:path error:nil];
        if ([attributes[NSFileModificationDate] timeIntervalSinceNow] < -120.0) {
            [fm removeItemAtPath:path error:nil]; continue;
        }
        if (![name hasSuffix:@".request.plist"]) continue;
        NSString *identifier = [name substringToIndex:name.length - @".request.plist".length];
        NSDictionary *request = [NSDictionary dictionaryWithContentsOfFile:path];
        if ([[[NSUUID alloc] initWithUUIDString:identifier].UUIDString isEqualToString:identifier] &&
            [request[@"requestID"] isEqual:identifier]) [requests addObject:identifier];
    }
    return requests;
}
- (void)drain:(unsigned long)flags {
    @autoreleasepool {
        if (_leaseFD < 0) return;
        NSArray<NSString *> *requests = [self requestsOnQueue]; // captured before publication
        NSDictionary *result = nil;
        if ((flags & 1) || requests.count) result = [self publishOnQueue];
        else if (PXPublisherNow() >= _nextRetry) {
            if (_needsPublication) result = [self publishOnQueue];
            else if (_pendingSnapshot) {
                __attribute__((objc_precise_lifetime)) NSDictionary *retry = _pendingSnapshot;
                result = [self distribute:retry];
            }
        }
        for (NSString *identifier in requests) {
            NSString *ack = [_directory stringByAppendingPathComponent:[identifier stringByAppendingString:@".ack.plist"]];
            if (PXRuntimeWritePropertyList(@{ @"requestID": identifier, @"result": result }, ack,
                                          geteuid(), getegid(), 0600, NULL)) {
                NSString *request = [_directory stringByAppendingPathComponent:[identifier stringByAppendingString:@".request.plist"]];
                [NSFileManager.defaultManager removeItemAtPath:request error:nil];
            }
        }
    }
}
- (NSDictionary *)syncOnceWithTimeout:(NSTimeInterval)timeout {
    if ([self onQueue]) return PXPublisherFailure(PXPublisherError(6, @"Reentrant sync rejected"));
    NSError *error = nil;
    if ([self tryAcquireOwnership:&error]) return [self publishNow];
    if (![error.domain isEqual:NSPOSIXErrorDomain] || (error.code != EWOULDBLOCK && error.code != EAGAIN))
        return PXPublisherFailure(error);
    if (!isfinite(timeout) || timeout <= 0) return PXPublisherFailure(PXPublisherError(7, @"Invalid sync deadline"));
    NSString *identifier = NSUUID.UUID.UUIDString;
    NSString *requestPath = [_directory stringByAppendingPathComponent:[identifier stringByAppendingString:@".request.plist"]];
    NSString *ackPath = [_directory stringByAppendingPathComponent:[identifier stringByAppendingString:@".ack.plist"]];
    if (!PXRuntimeWritePropertyList(@{ @"requestID": identifier }, requestPath, geteuid(), getegid(), 0600, &error))
        return PXPublisherFailure(error);
    // Darwin notification is a wakeup hint. The daemon's existing timer also drains requests.
    notify_post(PXRuntimeSyncRequestedNotification.UTF8String);
    NSTimeInterval deadline = PXPublisherNow() + MIN(timeout, 30.0);
    NSDictionary *result = nil;
    do {
        NSDictionary *ack = [NSDictionary dictionaryWithContentsOfFile:ackPath];
        if ([ack[@"requestID"] isEqual:identifier] && [ack[@"result"] isKindOfClass:NSDictionary.class]) {
            result = ack[@"result"]; break;
        }
        // A crashed/stopped owner releases flock; takeover creates a fresh epoch.
        if ([self tryAcquireOwnership:NULL]) { result = [self publishNow]; break; }
        usleep(50000);
    } while (PXPublisherNow() < deadline);
    [NSFileManager.defaultManager removeItemAtPath:requestPath error:nil];
    [NSFileManager.defaultManager removeItemAtPath:ackPath error:nil];
    return result ?: PXPublisherFailure(PXPublisherError(8, @"Timed out waiting for publisher acknowledgement"));
}
@end
