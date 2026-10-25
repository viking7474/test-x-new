#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "PXRuntimePublisher.h"
#import "PXRuntimeSnapshotReader.h"
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>

static NSUInteger gChecks, gFailures;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)

@interface PXPublisherBackend : NSObject
@property (atomic, copy) NSDictionary *payload;
@property (atomic) BOOL failWrite;
@property (atomic) BOOL complete;
@property (atomic) BOOL notifyOK;
@property (atomic) BOOL throwLoad;
@property (atomic) BOOL holdLoad;
@property (atomic) NSUInteger notifications;
@property (atomic) NSUInteger completions;
@property (atomic, strong) NSDictionary *lastResult;
@property (nonatomic, strong) NSMutableArray *writes;
@property (nonatomic, strong) NSMutableArray *mirrors;
@property (nonatomic, strong) dispatch_semaphore_t entered;
@property (nonatomic, strong) dispatch_semaphore_t releaseLoad;
@end
@implementation PXPublisherBackend
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _payload = @{ @"profileID": @"parent", @"deviceIDs": @{ @"marker": @1 } };
    _complete = YES; _notifyOK = YES;
    _writes = [NSMutableArray array]; _mirrors = [NSMutableArray array];
    _entered = dispatch_semaphore_create(0); _releaseLoad = dispatch_semaphore_create(0);
    return self;
}
@end

static PXRuntimePublisher *MakePublisher(NSString *directory, PXPublisherBackend *backend) {
    NSError *error = nil;
    NSString *global = [directory stringByAppendingPathComponent:@"global.plist"];
    PXRuntimePublisher *publisher = [[PXRuntimePublisher alloc] initWithDirectory:directory
        loader:^NSDictionary *(NSError **loadError) {
            (void)loadError;
            if (backend.throwLoad) [NSException raise:@"fixture" format:@"loader exception"];
            if (backend.holdLoad) {
                backend.holdLoad = NO;
                dispatch_semaphore_signal(backend.entered);
                if (dispatch_semaphore_wait(backend.releaseLoad, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC))) return nil;
            }
            return backend.payload;
        } writer:^BOOL(NSDictionary *snapshot, NSError **writeError) {
            if (backend.failWrite) {
                if (writeError) *writeError = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOSPC userInfo:nil];
                return NO;
            }
            usleep(1000); // Expose concurrent-publication ordering errors.
            BOOL written = PXRuntimeWritePropertyList(snapshot, global, geteuid(), getegid(), 0644, writeError);
            if (written) [backend.writes addObject:snapshot];
            return written;
        } distributor:^NSDictionary *(NSDictionary *snapshot) {
            [backend.mirrors addObject:snapshot];
            return @{ @"complete": @(backend.complete) };
        } notifier:^BOOL(NSError **notifyError) {
            backend.notifications++;
            if (!backend.notifyOK && notifyError) *notifyError = [NSError errorWithDomain:@"fixture.notify" code:1 userInfo:nil];
            return backend.notifyOK;
        } completion:^(NSDictionary *result) {
            backend.lastResult = result;
            backend.completions++;
        } error:&error];
    if (!publisher) fprintf(stderr, "publisher init: %s\n", error.description.UTF8String);
    return publisher;
}

static BOOL WaitCompletions(PXPublisherBackend *backend, NSUInteger count, NSTimeInterval seconds) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (backend.completions < count && deadline.timeIntervalSinceNow > 0) usleep(10000);
    return backend.completions >= count;
}
static NSString *Directory(NSString *root, NSString *name) { return [root stringByAppendingPathComponent:name]; }

static void TestSerialPublication(NSString *root) {
    PXPublisherBackend *backend = [PXPublisherBackend new];
    NSMutableString *mutableMarker = [@"frozen" mutableCopy];
    backend.payload = @{ @"profileID": @"parent", @"deviceIDs": @{ @"marker": mutableMarker } };
    NSString *directory = Directory(root, @"serial");
    __attribute__((objc_precise_lifetime)) PXRuntimePublisher *publisher = MakePublisher(directory, backend);
    CHECK(publisher != nil && [publisher tryAcquireOwnership:NULL], "acquire privileged ownership");
    NSDictionary *first = [publisher publishNow];
    NSDictionary *snapshot = first[@"snapshot"];
    [mutableMarker appendString:@"-changed"];
    CHECK([snapshot[@"deviceIDs"][@"marker"] isEqual:@"frozen"], "publisher detaches mutable source graph");
    PXRuntimeReadSnapshot *read = [[PXRuntimeReadSnapshot alloc] initWithPropertyList:snapshot readerGeneration:1];
    CHECK([first[@"success"] boolValue] && read.valid && read.schemaVersion == 2 && read.hasPublicationIdentity,
          "production reader accepts published identity");
    CHECK(read.revision == 1, "revision starts at one");
    CHECK([snapshot isEqual:[NSDictionary dictionaryWithContentsOfFile:Directory(directory, @"global.plist")]],
          "result is the exact global commit");
    PXRuntimePublisher *contender = MakePublisher(directory, [PXPublisherBackend new]);
    CHECK(![contender tryAcquireOwnership:NULL], "same-process independent publisher cannot bypass lease");
    CHECK(![[contender publishNow][@"success"] boolValue], "unowned direct publication rejected");
    NSDictionary *timeout = [contender syncOnceWithTimeout:0.15];
    CHECK(![timeout[@"success"] boolValue] && [timeout[@"error"] containsString:@"Timed out"],
          "unacknowledged sync times out without success");

    dispatch_group_t workers = dispatch_group_create();
    for (NSUInteger i = 0; i < 32; ++i) dispatch_group_async(workers, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool { [publisher publishNow]; }
    });
    CHECK(dispatch_group_wait(workers, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0,
          "concurrent owner requests complete");
    CHECK(backend.writes.count == 33 && backend.mirrors.count == 33, "each explicit publication commits and distributes once");
    for (NSUInteger i = 0; i < backend.writes.count; ++i) {
        NSDictionary *written = backend.writes[i];
        CHECK([written[@"revision"] unsignedLongLongValue] == i + 1 &&
              [written[@"publisherEpoch"] isEqual:snapshot[@"publisherEpoch"]] &&
              [written isEqual:backend.mirrors[i]], "serialized global mirror identity ordering");
    }
    NSUInteger before = backend.notifications;
    backend.failWrite = YES;
    NSDictionary *failed = [publisher publishNow];
    CHECK(![failed[@"globalCommitted"] boolValue] && ![failed[@"success"] boolValue] &&
          backend.notifications == before, "global failure never notifies success");
    backend.failWrite = NO;
    NSDictionary *after = [publisher publishNow];
    CHECK([after[@"snapshot"][@"revision"] unsignedLongLongValue] == 35, "failed revision never reused");
    backend.throwLoad = YES;
    CHECK(![[publisher publishNow][@"success"] boolValue], "loader exception becomes failed publication");
    backend.throwLoad = NO;
    CHECK([[publisher publishNow][@"success"] boolValue], "queue recovers after loader exception");

    __block NSDictionary *reentrant;
    // Weak self-reference avoids adding a fixture-only publisher retain cycle.
    __block __weak PXRuntimePublisher *weakSame;
    PXRuntimePublisher *same = [[PXRuntimePublisher alloc] initWithDirectory:Directory(root, @"same-queue")
        loader:^NSDictionary *(NSError **error) { (void)error; reentrant = [weakSame publishNow]; return @{}; }
        writer:^BOOL(NSDictionary *value, NSError **error) { (void)value; (void)error; return YES; }
        distributor:^NSDictionary *(NSDictionary *value) { (void)value; return @{ @"complete": @YES }; }
        notifier:^BOOL(NSError **error) { (void)error; return YES; } completion:nil error:NULL];
    weakSame = same;
    CHECK([same tryAcquireOwnership:NULL] && [[same publishNow][@"success"] boolValue] &&
          ![reentrant[@"success"] boolValue], "same-queue reentry fails without deadlock");
}

static void TestRetryAndCoalescing(NSString *root) {
    PXPublisherBackend *backend = [PXPublisherBackend new];
    __attribute__((objc_precise_lifetime)) PXRuntimePublisher *publisher = MakePublisher(Directory(root, @"retry"), backend);
    CHECK([publisher tryAcquireOwnership:NULL], "retry owner acquired");
    backend.complete = NO;
    NSDictionary *partial = [publisher publishNow];
    CHECK([partial[@"globalCommitted"] boolValue] && ![partial[@"distributionComplete"] boolValue] &&
          [partial[@"notified"] boolValue] && ![partial[@"success"] boolValue], "partial distribution is explicit and wakes successful readers");
    backend.payload = @{ @"profileID": @"new-source" };
    backend.complete = YES;
    NSUInteger expected = backend.completions + 1;
    usleep(2100000);
    [publisher serviceRequestsAndRetry];
    CHECK(WaitCompletions(backend, expected, 3), "bounded retry serviced by existing timer");
    CHECK([backend.lastResult[@"snapshot"] isEqual:partial[@"snapshot"]] && backend.writes.count == 1,
          "retry uses exact committed snapshot without global recapture");
    backend.notifyOK = NO;
    NSDictionary *unnotified = [publisher publishNow];
    CHECK([unnotified[@"distributionComplete"] boolValue] && ![unnotified[@"notified"] boolValue] &&
          ![unnotified[@"success"] boolValue], "notification error cannot report full success");
    backend.notifyOK = YES;
    NSDictionary *newer = [publisher publishNow];
    usleep(2100000);
    NSUInteger completed = backend.completions;
    [publisher serviceRequestsAndRetry];
    usleep(100000);
    CHECK(backend.completions == completed && [backend.mirrors.lastObject isEqual:newer[@"snapshot"]],
          "new publication supersedes old retry");

    backend.failWrite = YES;
    [publisher publishNow];
    expected = backend.completions + 1;
    backend.failWrite = NO;
    usleep(2100000);
    [publisher serviceRequestsAndRetry];
    CHECK(WaitCompletions(backend, expected, 3) && [backend.lastResult[@"success"] boolValue],
          "transient global write failure retries without another source notification");

    PXPublisherBackend *burst = [PXPublisherBackend new];
    __attribute__((objc_precise_lifetime)) PXRuntimePublisher *coalesced = MakePublisher(Directory(root, @"burst"), burst);
    CHECK([coalesced tryAcquireOwnership:NULL], "coalescing owner acquired");
    burst.holdLoad = YES;
    [coalesced requestPublication];
    CHECK(dispatch_semaphore_wait(burst.entered, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) == 0,
          "first publication in flight");
    for (NSUInteger i = 0; i < 128; ++i) [coalesced requestPublication];
    dispatch_semaphore_signal(burst.releaseLoad);
    CHECK(WaitCompletions(burst, 2, 5), "burst converges after in-flight publication");
    usleep(100000);
    CHECK(burst.completions == 2, "notification burst coalesced to one trailing publication");
}

static NSTask *Client(NSString *binary, NSString *directory, NSString *output) {
    NSTask *task = [NSTask new];
    task.launchPath = binary;
    task.arguments = @[ @"--client", directory, output ];
    [task launch];
    return task;
}
static void TestProcessOwnership(NSString *root, NSString *binary) {
    NSString *directory = Directory(root, @"ipc");
    PXPublisherBackend *backend = [PXPublisherBackend new];
    __attribute__((objc_precise_lifetime)) PXRuntimePublisher *publisher = MakePublisher(directory, backend);
    CHECK([publisher tryAcquireOwnership:NULL], "IPC daemon lease acquired");
    NSDictionary *initial = [publisher publishNow];
    NSString *aPath = Directory(root, @"client-a.plist"), *bPath = Directory(root, @"client-b.plist");
    NSTask *a = Client(binary, directory, aPath), *b = Client(binary, directory, bPath);
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
    while ((a.running || b.running) && deadline.timeIntervalSinceNow > 0) {
        [publisher serviceRequestsAndRetry]; usleep(50000);
    }
    if (a.running) [a terminate];
    if (b.running) [b terminate];
    [a waitUntilExit]; [b waitUntilExit];
    CHECK(a.terminationStatus == 0 && b.terminationStatus == 0, "two CLI clients receive acknowledgements");
    for (NSString *path in @[aPath, bPath]) {
        NSDictionary *result = [NSDictionary dictionaryWithContentsOfFile:path];
        CHECK([result[@"success"] boolValue] && [result[@"snapshot"][@"profileID"] isEqual:@"parent"] &&
              [result[@"snapshot"][@"publisherEpoch"] isEqual:initial[@"snapshot"][@"publisherEpoch"]],
              "ack identifies daemon publication rather than competing CLI writer");
    }
    backend.complete = NO;
    NSString *partialPath = Directory(root, @"client-partial.plist");
    NSTask *partialClient = Client(binary, directory, partialPath);
    deadline = [NSDate dateWithTimeIntervalSinceNow:10];
    while (partialClient.running && deadline.timeIntervalSinceNow > 0) {
        [publisher serviceRequestsAndRetry]; usleep(50000);
    }
    if (partialClient.running) [partialClient terminate];
    [partialClient waitUntilExit];
    NSDictionary *partial = [NSDictionary dictionaryWithContentsOfFile:partialPath];
    CHECK(partialClient.terminationStatus == 1 && [partial[@"globalCommitted"] boolValue] &&
          ![partial[@"success"] boolValue], "partial daemon distribution returns nonzero CLI exit");

    NSString *crashDir = Directory(root, @"crash"), *ready = Directory(root, @"ready.plist");
    NSTask *holder = [NSTask new];
    holder.launchPath = binary; holder.arguments = @[ @"--hold", crashDir, ready ]; [holder launch];
    deadline = [NSDate dateWithTimeIntervalSinceNow:5];
    while (![NSFileManager.defaultManager fileExistsAtPath:ready] && holder.running && deadline.timeIntervalSinceNow > 0) usleep(10000);
    NSDictionary *old = [NSDictionary dictionaryWithContentsOfFile:ready];
    PXRuntimePublisher *replacement = MakePublisher(crashDir, [PXPublisherBackend new]);
    CHECK([old[@"success"] boolValue] && ![replacement tryAcquireOwnership:NULL], "separate process lease excludes replacement");
    [holder terminate]; [holder waitUntilExit]; // Only the fixture child, never an application.
    CHECK([replacement tryAcquireOwnership:NULL], "process exit releases ownership without deleting lock inode");
    NSDictionary *fresh = [replacement publishNow];
    CHECK([fresh[@"success"] boolValue] && ![fresh[@"snapshot"][@"publisherEpoch"] isEqual:old[@"snapshot"][@"publisherEpoch"]] &&
          [fresh[@"snapshot"][@"revision"] unsignedLongLongValue] == 1, "new owner starts new epoch and revision");
}

static void TestAtomicWriter(NSString *root) {
    NSString *path = Directory(root, @"atomic.plist");
    dispatch_group_t group = dispatch_group_create();
    NSObject *counterLock = [NSObject new];
    __block NSUInteger failedWrites = 0;
    for (NSUInteger i = 0; i < 64; ++i) dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            if (!PXRuntimeWritePropertyList(@{ @"marker": @(i) }, path, geteuid(), getegid(), 0644, NULL)) {
                @synchronized (counterLock) { failedWrites++; }
            }
        }
    });
    CHECK(dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0,
          "parallel atomic writers complete");
    CHECK([NSDictionary dictionaryWithContentsOfFile:path][@"marker"] != nil, "atomic target always contains complete property list");
    CHECK(failedWrites == 0, "unique temp names support concurrent writers in the same process");
    for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:root error:nil])
        CHECK(![name containsString:@".tmp."], "exclusive temporary files cleaned up");
    CHECK(!PXRuntimeWritePropertyList(@{}, root, geteuid(), getegid(), 0644, NULL), "rename failure reported");
    NSString *link = Directory(root, @"unsafe-link");
    symlink(root.fileSystemRepresentation, link.fileSystemRepresentation);
    CHECK(MakePublisher(link, [PXPublisherBackend new]) == nil, "symlink ownership directory rejected");
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc == 4) {
            NSString *mode = @(argv[1]), *directory = @(argv[2]), *output = @(argv[3]);
            PXPublisherBackend *backend = [PXPublisherBackend new];
            backend.payload = @{ @"profileID": @"child" };
            __attribute__((objc_precise_lifetime)) PXRuntimePublisher *publisher = MakePublisher(directory, backend);
            if ([mode isEqual:@"--client"]) {
                NSDictionary *result = [publisher syncOnceWithTimeout:5];
                [result writeToFile:output atomically:YES];
                return [result[@"success"] boolValue] ? 0 : 1;
            }
            if ([mode isEqual:@"--hold"]) {
                if (![publisher tryAcquireOwnership:NULL]) return 2;
                [[publisher publishNow] writeToFile:output atomically:YES];
                sleep(30); return 0;
            }
        }
        NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        [NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
        TestSerialPublication(root);
        TestRetryAndCoalescing(root);
        TestProcessOwnership(root, [NSString stringWithUTF8String:argv[0]]);
        TestAtomicWriter(root);
        [NSFileManager.defaultManager removeItemAtPath:root error:nil];
        printf("Runtime publication: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
