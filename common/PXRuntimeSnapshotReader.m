#import "PXRuntimeSnapshotReader.h"
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#import <os/lock.h>
#include <errno.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

BOOL PXRuntimeReadBool(id value) {
    return ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class]) && [value boolValue];
}

static BOOL PXRuntimeUnsignedInteger(id value, uint64_t *result) {
    if (![value isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) return NO;
    const char *type = [value objCType];
    if (!type || !type[0] || !strchr("cCsSiIlLqQ", type[0])) return NO;
    const char *text = [[value stringValue] UTF8String];
    if (!text || text[0] < '0' || text[0] > '9') return NO;
    int savedErrno = errno;
    errno = 0;
    char *end = NULL;
    unsigned long long parsed = strtoull(text, &end, 10);
    BOOL valid = errno != ERANGE && end && *end == '\0';
    errno = savedErrno;
    if (valid && result) *result = (uint64_t)parsed;
    return valid;
}

static NSDictionary *PXRuntimeViewDictionary(NSDictionary *root, NSString *key) {
    id value = root[key];
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

@implementation PXRuntimeReadSnapshot
- (instancetype)initWithPropertyList:(NSDictionary *)propertyList readerGeneration:(uint64_t)readerGeneration {
    if (!(self = [super init])) return nil;
    _readerGeneration = readerGeneration;
    _propertyList = @{};
    _globalScope = @{}; _securitySettings = @{}; _tlinkSettings = @{};
    _profileSettings = @{}; _deviceIDs = @{};
    if (![propertyList isKindOfClass:NSDictionary.class]) return self;
    // Freeze all descendants, including mutable strings/data. Shallow copy alone
    // leaves fields writable through the loader's original object graph.
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:propertyList
        format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
    id frozen = data ? [NSPropertyListSerialization propertyListWithData:data
        options:NSPropertyListImmutable format:NULL error:NULL] : nil;
    if (![frozen isKindOfClass:NSDictionary.class]) return self;
    uint64_t schema = 0, revision = 0;
    if (!PXRuntimeUnsignedInteger(frozen[@"schemaVersion"], &schema) || (schema != 1 && schema != 2)) return self;
    id epoch = frozen[@"publisherEpoch"];
    id rawRevision = frozen[@"revision"];
    BOOL identityPresent = epoch != nil || rawRevision != nil;
    NSUUID *publisherID = [epoch isKindOfClass:NSString.class] ? [[NSUUID alloc] initWithUUIDString:epoch] : nil;
    BOOL validIdentity = publisherID != nil && PXRuntimeUnsignedInteger(rawRevision, &revision);
    if ((identityPresent || schema == 2) && !validIdentity) return self;
    _valid = YES;
    _schemaVersion = (NSUInteger)schema;
    _hasPublicationIdentity = validIdentity;
    _publisherEpoch = validIdentity ? publisherID.UUIDString : nil;
    _revision = validIdentity ? revision : 0;
    _propertyList = frozen;
    id profile = frozen[@"profileID"];
    _profileID = [profile isKindOfClass:NSString.class] && [profile length] ? profile : nil;
    _globalScope = PXRuntimeViewDictionary(frozen, @"globalScope");
    _securitySettings = PXRuntimeViewDictionary(frozen, @"securitySettings");
    _tlinkSettings = PXRuntimeViewDictionary(frozen, @"tlinkSettings");
    _profileSettings = PXRuntimeViewDictionary(frozen, @"profileSettings");
    _deviceIDs = PXRuntimeViewDictionary(frozen, @"deviceIDs");
    return self;
}
- (NSDictionary *)profileArtifact:(NSString *)key {
    if (![key isKindOfClass:NSString.class] || !key.length) return @{};
    return PXRuntimeViewDictionary(PXRuntimeViewDictionary(self.propertyList, @"profileArtifacts"), key);
}
@end

static char kPXRuntimeReaderQueue;
static NSTimeInterval PXRuntimeReaderNow(void) {
    struct timespec now = {0};
    if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) return 0;
    return (NSTimeInterval)now.tv_sec + (NSTimeInterval)now.tv_nsec / 1000000000.0;
}

@interface PXRuntimeSnapshotReader () {
    os_unfair_lock _lock;
    PXRuntimeSnapshotLoader _loader;
    void (^_preparer)(PXRuntimeReadSnapshot *);
    dispatch_queue_t _queue;
    dispatch_group_t _pending;
    PXRuntimeReadSnapshot *_snapshot;
    uint64_t _requestedGeneration;
    BOOL _queued;
    BOOL _dirty;
    NSTimeInterval _refreshInterval;
    NSTimeInterval _nextRefresh;
    // Worker-only metadata: keep identity for anti-rollback without keeping any
    // old enabled fields available to captures after invalidation/failure.
    NSString *_lastEpoch;
    uint64_t _lastRevision;
}
@end

@implementation PXRuntimeSnapshotReader
- (instancetype)initWithLoader:(PXRuntimeSnapshotLoader)loader refreshInterval:(NSTimeInterval)refreshInterval {
    if (!loader) return nil;
    if (!(self = [super init])) return nil;
    _lock = (os_unfair_lock){0};
    _loader = [loader copy];
    _refreshInterval = isfinite(refreshInterval) && refreshInterval > 0 ? refreshInterval : 5.0;
    _queue = dispatch_queue_create("com.hydra.tlinkios.runtime-reader", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(_queue, &kPXRuntimeReaderQueue, (__bridge void *)self, NULL);
    _pending = dispatch_group_create();
    return self;
}

// Called with _lock held; enqueue the worker only after unlocking. Group entry
// happens before the request returns so bootstrap waits cannot miss queued work.
- (BOOL)markRefreshLocked:(BOOL)invalidate now:(NSTimeInterval)now {
    if (++_requestedGeneration == 0) ++_requestedGeneration;
    if (invalidate) _snapshot = nil;
    _nextRefresh = now + _refreshInterval;
    _dirty = YES;
    if (_queued) return NO;
    _queued = YES;
    dispatch_group_enter(_pending);
    return YES;
}

- (void)drainRefreshes {
    @try {
        for (;;) {
            uint64_t generation;
            void (^preparer)(PXRuntimeReadSnapshot *);
            os_unfair_lock_lock(&_lock);
            generation = _requestedGeneration;
            preparer = _preparer;
            _dirty = NO;
            os_unfair_lock_unlock(&_lock);
            PXRuntimeReadSnapshot *candidate;
            @autoreleasepool {
                @try {
                    candidate = [[PXRuntimeReadSnapshot alloc] initWithPropertyList:_loader() readerGeneration:generation];
                    if (candidate.valid && preparer) preparer(candidate);
                } @catch (__unused NSException *exception) {
                    candidate = [[PXRuntimeReadSnapshot alloc] initWithPropertyList:nil readerGeneration:generation];
                }
                if (candidate.hasPublicationIdentity && [candidate.publisherEpoch isEqualToString:_lastEpoch] &&
                    candidate.revision < _lastRevision) {
                    candidate = [[PXRuntimeReadSnapshot alloc] initWithPropertyList:nil readerGeneration:generation];
                }
            }
            __attribute__((objc_precise_lifetime)) PXRuntimeReadSnapshot *previous = nil;
            os_unfair_lock_lock(&_lock);
            if (generation == _requestedGeneration) {
                previous = _snapshot;
                _snapshot = candidate;
            }
            BOOL accepted = generation == _requestedGeneration;
            BOOL again = _dirty || generation != _requestedGeneration;
            if (!again) _queued = NO;
            os_unfair_lock_unlock(&_lock);
            (void)previous;
            if (accepted && candidate.hasPublicationIdentity) {
                _lastEpoch = candidate.publisherEpoch;
                _lastRevision = candidate.revision;
            }
            if (!again) break;
        }
    } @finally {
        dispatch_group_leave(_pending);
    }
}

- (void)enqueueWorker:(BOOL)needed {
    if (needed) dispatch_async(_queue, ^{ [self drainRefreshes]; });
}

- (PXRuntimeReadSnapshot *)capture {
    int savedErrno = errno;
    NSTimeInterval now = PXRuntimeReaderNow();
    os_unfair_lock_lock(&_lock);
    PXRuntimeReadSnapshot *snapshot = _snapshot;
    BOOL schedule = NO;
    if (!_queued && (!snapshot || now >= _nextRefresh)) schedule = [self markRefreshLocked:NO now:now];
    os_unfair_lock_unlock(&_lock);
    [self enqueueWorker:schedule];
    errno = savedErrno;
    return snapshot;
}

- (void)requestRefreshInvalidating:(BOOL)invalidate {
    int savedErrno = errno;
    NSTimeInterval now = PXRuntimeReaderNow();
    __attribute__((objc_precise_lifetime)) PXRuntimeReadSnapshot *previous = nil;
    os_unfair_lock_lock(&_lock);
    if (invalidate) previous = _snapshot;
    BOOL schedule = [self markRefreshLocked:invalidate now:now];
    os_unfair_lock_unlock(&_lock);
    (void)previous;
    [self enqueueWorker:schedule];
    errno = savedErrno;
}
- (void)invalidateAndRefresh { [self requestRefreshInvalidating:YES]; }
- (void)requestRefresh { [self requestRefreshInvalidating:NO]; }
- (void)setPreparationHandler:(void (^)(PXRuntimeReadSnapshot *))handler {
    void (^copy)(PXRuntimeReadSnapshot *) = [handler copy];
    __attribute__((objc_precise_lifetime)) id previous = nil;
    __attribute__((objc_precise_lifetime)) PXRuntimeReadSnapshot *previousView = nil;
    NSTimeInterval now = PXRuntimeReaderNow();
    os_unfair_lock_lock(&_lock);
    previous = _preparer;
    previousView = _snapshot;
    _preparer = copy;
    BOOL schedule = [self markRefreshLocked:YES now:now];
    os_unfair_lock_unlock(&_lock);
    (void)previous; (void)previousView;
    [self enqueueWorker:schedule];
}
- (BOOL)waitForPendingRefresh:(NSTimeInterval)timeout {
    if (dispatch_get_specific(&kPXRuntimeReaderQueue) == (__bridge void *)self) return NO;
    if (!isfinite(timeout) || timeout < 0 || timeout > 60) return NO;
    return dispatch_group_wait(_pending, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC))) == 0;
}
@end
