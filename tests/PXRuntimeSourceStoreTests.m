#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "PXRuntimeSourceStore.h"
#import "PXRuntimePublisher.h"
#include <unistd.h>
#include <sys/stat.h>

static NSUInteger gChecks, gFailures;
#define CHECK(value, message) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", message); } } while (0)
static NSString *Path(NSString *root, NSString *name) { return [root stringByAppendingPathComponent:name]; }
static PXRuntimeSourceStore *Store(NSString *root) {
    NSSet *allowed = [NSSet setWithArray:@[Path(root, @"a.plist"), Path(root, @"b.plist"), Path(root, @"c.plist")]];
    NSError *error = nil;
    PXRuntimeSourceStore *store = [[PXRuntimeSourceStore alloc] initWithDirectory:Path(root, @"control")
        owner:geteuid() group:getegid() allowsPath:^BOOL(NSString *path) { return [allowed containsObject:path]; } error:&error];
    if (!store) fprintf(stderr, "store init failed: %s\n", error.description.UTF8String);
    return store;
}
static BOOL WritePair(PXRuntimeSourceStore *store, NSString *root, NSUInteger value, BOOL third) {
    return [store performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        NSDictionary *dict = @{ @"value": @(value) };
        return [tx setDictionary:dict atPath:Path(root, @"a.plist") error:error] &&
            [tx setDictionary:dict atPath:Path(root, @"b.plist") error:error] &&
            (!third || [tx setDictionary:dict atPath:Path(root, @"c.plist") error:error]);
    } error:NULL];
}
static NSDictionary *ReadPair(PXRuntimeSourceStore *store, NSString *root) {
    return [store capture:^NSDictionary *(NSError **error) {
        (void)error;
        return @{ @"a": [NSDictionary dictionaryWithContentsOfFile:Path(root, @"a.plist")] ?: @{},
                  @"b": [NSDictionary dictionaryWithContentsOfFile:Path(root, @"b.plist")] ?: @{} };
    } error:NULL];
}
static NSString *NewCase(NSString *root, NSString *name) {
    NSString *folder = Path(root, name);
    [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    return folder;
}

static void TestStaging(NSString *root) {
    NSString *folder = NewCase(root, @"staging");
    PXRuntimeSourceStore *store = Store(folder);
    CHECK(store != nil, "source store initialized");
    NSDictionary *legacy = ReadPair(store, folder);
    CHECK([legacy[@"sourceState"] isEqual:@"legacy"] && !legacy[@"sourceCommitID"], "absent commit is explicit legacy source");
    CHECK(WritePair(store, folder, 1, NO), "paired initial commit");
    NSDictionary *first = ReadPair(store, folder);
    CHECK([first[@"sourceState"] isEqual:@"committed"] && [[NSUUID alloc] initWithUUIDString:first[@"sourceCommitID"]] != nil,
          "source commit identity captured");
    CHECK(![store performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        [tx setDictionary:@{ @"value": @2 } atPath:Path(folder, @"a.plist") error:error];
        CHECK([[NSDictionary dictionaryWithContentsOfFile:Path(folder, @"a.plist")][@"value"] isEqual:@1],
              "staging never mutates live files before body succeeds");
        return NO;
    } error:NULL], "aborted block cannot commit staged values");
    CHECK([ReadPair(store, folder) isEqual:first], "aborted staging preserves source commit identity");

    CHECK([store performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        if (![tx setDictionary:@{ @"value": @3 } atPath:Path(folder, @"a.plist") error:error]) return NO;
        return [store performWrite:^BOOL(PXRuntimeSourceTransaction *nested, NSError **innerError) {
            NSDictionary *a = [nested dictionaryAtPath:Path(folder, @"a.plist") error:innerError];
            return [nested setDictionary:a atPath:Path(folder, @"b.plist") error:innerError];
        } error:error];
    } error:NULL], "nested writer shares staged dictionaries");
    NSDictionary *nestedResult = ReadPair(store, folder);
    CHECK([nestedResult[@"a"] isEqual:nestedResult[@"b"]] && [nestedResult[@"a"][@"value"] isEqual:@3], "one outer commit publishes nested tuple");
    CHECK(![store performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        [tx setDictionary:@{ @"value": @4 } atPath:Path(folder, @"a.plist") error:error];
        [store performWrite:^BOOL(PXRuntimeSourceTransaction *inner, NSError **innerError) { (void)inner; (void)innerError; return NO; } error:NULL];
        return YES; // Deliberately ignore inner failure.
    } error:NULL], "ignored nested failure still poisons outer transaction");
    CHECK([ReadPair(store, folder) isEqual:nestedResult], "nested abort leaves complete prior tuple");

    __block PXRuntimeSourceTransaction *escaped;
    CHECK([store performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        (void)error; escaped = tx;
        CHECK(ReadPair(store, folder) == nil, "reentrant capture rejects staged view");
        __block BOOL wrongThread = YES;
        dispatch_semaphore_t checked = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            wrongThread = [tx setDictionary:@{} atPath:Path(folder, @"a.plist") error:NULL];
            dispatch_semaphore_signal(checked);
        });
        CHECK(dispatch_semaphore_wait(checked, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) == 0 &&
              !wrongThread, "transaction rejects cross-thread use");
        return YES;
    } error:NULL], "no-op transaction succeeds without new commit");
    CHECK(![escaped setDictionary:@{} atPath:Path(folder, @"a.plist") error:NULL], "escaped transaction rejects writes after scope end");
    CHECK(![store performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        (void)tx; (void)error; [NSException raise:@"fixture" format:@"abort writer"]; return YES;
    } error:NULL], "writer exception becomes failure and unlocks");
    CHECK(ReadPair(store, folder) != nil, "source capture recovers after exception");

    NSMutableString *marker = [@"before" mutableCopy];
    NSDictionary *frozen = [store capture:^NSDictionary *(NSError **error) { (void)error; return @{ @"marker": marker }; } error:NULL];
    [marker appendString:@"-after"];
    CHECK([frozen[@"marker"] isEqual:@"before"], "capture detaches mutable payload before unlocking");
    CHECK([store capture:^NSDictionary *(NSError **error) {
        (void)error;
        CHECK(!WritePair(store, folder, 7, NO), "writer cannot upgrade a capture lock");
        return @{};
    } error:NULL] != nil, "capture remains valid after rejected lock upgrade");
}

static void TestFailures(NSString *root) {
    NSString *folder = NewCase(root, @"failures");
    PXRuntimeSourceStore *store = Store(folder);
    CHECK(WritePair(store, folder, 1, NO), "failure fixture seeded");
    NSData *before = [NSData dataWithContentsOfFile:Path(folder, @"a.plist")];
    chmod(Path(folder, @"a.plist").fileSystemRepresentation, 0600);
    __block NSUInteger writes = 0;
    store.testCheckpoint = ^(NSString *stage) {
        if ([stage isEqual:@"source-written"] && ++writes == 1) [NSException raise:@"fixture" format:@"interrupt file group"];
    };
    CHECK(!WritePair(store, folder, 2, NO), "failure between files aborts whole group");
    store.testCheckpoint = nil;
    NSDictionary *after = ReadPair(store, folder);
    CHECK([after[@"a"][@"value"] isEqual:@1] && [after[@"a"] isEqual:after[@"b"]] &&
          [before isEqual:[NSData dataWithContentsOfFile:Path(folder, @"a.plist")]], "rollback restores exact prior bytes");
    struct stat st = {0}; lstat(Path(folder, @"a.plist").fileSystemRepresentation, &st);
    CHECK((st.st_mode & 0777) == 0600, "rollback preserves original source permissions");
    NSString *forbidden = Path(folder, @"sentinel.plist");
    [@{ @"keep": @YES } writeToFile:forbidden atomically:YES];
    CHECK(![store performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        [tx setDictionary:@{} atPath:forbidden error:error]; return YES;
    } error:NULL], "unapproved source path taints transaction");
    CHECK([[NSDictionary dictionaryWithContentsOfFile:forbidden][@"keep"] boolValue], "unapproved file unchanged");
    NSData *goodCommit = [NSData dataWithContentsOfFile:Path(folder, @"control/commit.plist")];
    [@{ @"broken": @YES } writeToFile:Path(folder, @"control/commit.plist") atomically:YES];
    CHECK(ReadPair(store, folder) == nil && !WritePair(store, folder, 3, NO), "corrupt commit refuses capture and mutation");
    [goodCommit writeToFile:Path(folder, @"control/commit.plist") atomically:YES];
    NSDictionary *badJournal = @{ @"schemaVersion": @1, @"transactionID": NSUUID.UUID.UUIDString,
        @"entries": @[
            @{ @"path": Path(folder, @"a.plist"), @"existed": @YES,
               @"data": [NSPropertyListSerialization dataWithPropertyList:@{ @"value": @123 }
                    format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL], @"mode": @0644 },
            @{ @"path": forbidden, @"existed": @NO, @"data": [NSData data], @"mode": @0644 } ] };
    [badJournal writeToFile:Path(folder, @"control/pending.plist") atomically:YES];
    CHECK(ReadPair(store, folder) == nil && !WritePair(store, folder, 3, NO), "malformed journal remains unavailable");
    CHECK([[NSDictionary dictionaryWithContentsOfFile:forbidden][@"keep"] boolValue] &&
          [before isEqual:[NSData dataWithContentsOfFile:Path(folder, @"a.plist")]], "validate all journal paths before any recovery writes");
    [NSFileManager.defaultManager removeItemAtPath:Path(folder, @"control/pending.plist") error:nil];
}

static NSTask *Child(NSString *binary, NSString *mode, NSString *folder, NSString *argument) {
    NSTask *task = [NSTask new]; task.launchPath = binary;
    task.arguments = @[mode, folder, argument]; [task launch]; return task;
}
static BOOL RemovePair(PXRuntimeSourceStore *store, NSString *folder) {
    return [store performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx removeDictionaryAtPath:Path(folder, @"a.plist") error:error] &&
            [tx setDictionary:@{ @"value": @99 } atPath:Path(folder, @"b.plist") error:error] &&
            [tx removeDictionaryAtPath:Path(folder, @"c.plist") error:error];
    } error:NULL];
}
static void TestRemovals(NSString *root, NSString *binary) {
    NSString *folder = NewCase(root, @"removal-staging");
    PXRuntimeSourceStore *store = Store(folder);
    CHECK(WritePair(store, folder, 1, NO), "removal fixture seeded");
    CHECK([store performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        NSString *path = Path(folder, @"a.plist");
        if (![tx removeDictionaryAtPath:path error:error]) return NO;
        BOOL exists = YES;
        NSDictionary *absent = [tx dictionaryAtPath:path exists:&exists error:error];
        CHECK(absent != nil && !absent.count && !exists, "staged removal reads as absence");
        CHECK([NSFileManager.defaultManager fileExistsAtPath:path], "staged removal does not unlink live source");
        if (![tx removeDictionaryAtPath:path error:error]) return NO;
        return [tx setDictionary:@{ @"value": @2 } atPath:path error:error];
    } error:NULL], "set after repeated removal wins without size underflow");
    CHECK([[ReadPair(store, folder)[@"a"] objectForKey:@"value"] isEqual:@2], "replaced staged removal commits dictionary");
    NSDictionary *before = ReadPair(store, folder);
    CHECK(![store performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        [tx removeDictionaryAtPath:Path(folder, @"unapproved.plist") error:error]; return YES;
    } error:NULL] && [before isEqual:ReadPair(store, folder)], "unapproved removal poisons outer transaction");
    NSData *badBytes = [@"malformed" dataUsingEncoding:NSUTF8StringEncoding];
    CHECK([badBytes writeToFile:Path(folder, @"a.plist") atomically:YES], "malformed removal fixture prepared");
    before = ReadPair(store, folder);
    CHECK(!RemovePair(store, folder) && [badBytes isEqual:[NSData dataWithContentsOfFile:Path(folder, @"a.plist")]] &&
          [before isEqual:ReadPair(store, folder)], "malformed source deletion fails before mutation");

    for (NSString *phase in @[@"source-written", @"commit-written"]) {
        NSString *crashFolder = NewCase(root, [@"removal-" stringByAppendingString:phase]);
        PXRuntimeSourceStore *crashStore = Store(crashFolder);
        CHECK(WritePair(crashStore, crashFolder, 1, NO), "removal crash fixture seeded");
        NSString *deletedPath = Path(crashFolder, @"a.plist");
        chmod(deletedPath.fileSystemRepresentation, 0600);
        NSData *bytes = [NSData dataWithContentsOfFile:deletedPath];
        NSTask *child = Child(binary, @"--remove-crash", crashFolder, phase); [child waitUntilExit];
        CHECK(child.terminationStatus == 77, "removal child exits at exact checkpoint");
        BOOL committed = [phase isEqual:@"commit-written"];
        CHECK(committed ? ReadPair(crashStore, crashFolder) != nil : ReadPair(crashStore, crashFolder) == nil,
              "capture observes committed deletion or rejects pending deletion");
        CHECK([crashStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) { (void)tx; (void)error; return YES; } error:NULL],
              "owner recovers interrupted removal");
        struct stat st = {0}; int status = stat(deletedPath.fileSystemRepresentation, &st);
        CHECK(committed ? status != 0 : (status == 0 && (st.st_mode & 0777) == 0600 && [bytes isEqual:[NSData dataWithContentsOfFile:deletedPath]]),
              "removal recovery preserves committed absence or exact before-image and mode");
        CHECK([ReadPair(crashStore, crashFolder)[@"b"][@"value"] isEqual:(committed ? @99 : @1)], "paired write follows deletion commit decision");
    }
}
static void TestCrashRecovery(NSString *root, NSString *binary) {
    for (NSString *phase in @[@"journal-prepared", @"source-written", @"last-source-written", @"commit-written"]) {
        NSString *folder = NewCase(root, phase);
        PXRuntimeSourceStore *store = Store(folder);
        CHECK(WritePair(store, folder, 1, NO), "crash fixture seeded");
        NSTask *child = Child(binary, @"--crash", folder, phase);
        [child waitUntilExit];
        CHECK(child.terminationStatus == 77, "fixture exited at exact transaction checkpoint");
        NSData *journal = [NSData dataWithContentsOfFile:Path(folder, @"control/pending.plist")];
        NSDictionary *beforeRecovery = ReadPair(store, folder);
        CHECK(journal != nil && ([phase isEqual:@"commit-written"] ?
              [beforeRecovery[@"a"][@"value"] isEqual:@99] : beforeRecovery == nil),
              "uncommitted crash blocks capture; committed journal does not block revocation");
        CHECK([journal isEqual:[NSData dataWithContentsOfFile:Path(folder, @"control/pending.plist")]], "capture never rewrites or recovers journal");
        CHECK([store performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) { (void)tx; (void)error; return YES; } error:NULL],
              "source owner recovers on next writer operation");
        NSDictionary *recovered = ReadPair(store, folder);
        NSNumber *expected = [phase isEqual:@"commit-written"] ? @99 : @1;
        CHECK([recovered[@"a"][@"value"] isEqual:expected] && [recovered[@"a"] isEqual:recovered[@"b"]],
              "commit marker decides complete new tuple versus rollback");
        CHECK([NSFileManager.defaultManager fileExistsAtPath:Path(folder, @"c.plist")] == [phase isEqual:@"commit-written"],
              "rollback restores absence of newly created source");
        CHECK(WritePair(store, folder, 100, NO), "normal writes resume after crash recovery");
    }
    NSString *folder = NewCase(root, @"recovery-crash");
    PXRuntimeSourceStore *store = Store(folder);
    CHECK(WritePair(store, folder, 1, NO), "recovery crash fixture seeded");
    NSTask *writer = Child(binary, @"--crash", folder, @"last-source-written");
    [writer waitUntilExit];
    NSTask *recovery = Child(binary, @"--recover-crash", folder, @"unused");
    [recovery waitUntilExit];
    CHECK(writer.terminationStatus == 77 && recovery.terminationStatus == 78 && ReadPair(store, folder) == nil,
          "crash during rollback keeps journal and blocks capture");
    CHECK([store performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) { (void)tx; (void)error; return YES; } error:NULL],
          "rollback is idempotent after recovery process crash");
    NSDictionary *view = ReadPair(store, folder);
    CHECK([view[@"a"][@"value"] isEqual:@1] && [view[@"a"] isEqual:view[@"b"]] &&
          ![NSFileManager.defaultManager fileExistsAtPath:Path(folder, @"c.plist")], "repeated recovery restores complete original tuple and absence");
}
static void TestProcesses(NSString *root, NSString *binary) {
    NSString *folder = NewCase(root, @"processes");
    __attribute__((objc_precise_lifetime)) PXRuntimeSourceStore *store = Store(folder);
    CHECK(WritePair(store, folder, 0, NO), "concurrent fixture seeded");
    NSTask *a = Child(binary, @"--increment", folder, @"30"), *b = Child(binary, @"--increment", folder, @"30");
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:15];
    NSUInteger mixed = 0, captures = 0;
    while ((a.running || b.running) && deadline.timeIntervalSinceNow > 0) {
        NSDictionary *view = ReadPair(store, folder);
        if (view) { captures++; if (![view[@"a"] isEqual:view[@"b"]]) mixed++; }
        usleep(1000);
    }
    if (a.running) [a terminate]; if (b.running) [b terminate];
    [a waitUntilExit]; [b waitUntilExit];
    CHECK(a.terminationStatus == 0 && b.terminationStatus == 0, "two source writer processes complete");
    CHECK(captures > 0 && mixed == 0, "concurrent capture never mixes paired source generations");
    NSDictionary *result = ReadPair(store, folder);
    CHECK([result[@"a"][@"value"] unsignedIntegerValue] == 60 && [result[@"a"] isEqual:result[@"b"]], "cross-process read modify write has no lost increments");
    NSTask *holder = Child(binary, @"--hold", folder, @"unused");
    deadline = [NSDate dateWithTimeIntervalSinceNow:5];
    while (![NSFileManager.defaultManager fileExistsAtPath:Path(folder, @"ready")] && holder.running && deadline.timeIntervalSinceNow > 0) usleep(10000);
    CHECK(ReadPair(store, folder) == nil, "source capture times out while exclusive owner is busy");
    if (holder.running) [holder terminate]; [holder waitUntilExit];
    CHECK(ReadPair(store, folder) != nil, "process death releases source gate");
}

static void TestCommitPreconditions(NSString *root, NSString *binary) {
    NSString *folder = NewCase(root, @"commit-precondition"); PXRuntimeSourceStore *store = Store(folder);
    __block NSString *receipt = nil; __block PXRuntimeSourceTransaction *escaped = nil;
    CHECK([store performStandaloneWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        escaped = tx;
        if (![tx requireBaseCommitIdentifier:@"" error:error]) return NO;
        receipt = [tx prospectiveCommitIdentifierWithError:error];
        return receipt && [receipt isEqual:[tx prospectiveCommitIdentifierWithError:error]] &&
               [tx setDictionary:@{ @"value": @1 } atPath:Path(folder, @"a.plist") error:error] &&
               [tx setDictionary:@{ @"value": @1 } atPath:Path(folder, @"b.plist") error:error];
    } error:NULL] && [receipt isEqual:ReadPair(store, folder)[@"sourceCommitID"]],
          "staged source receipt is exactly the committed marker including legacy admission");
    CHECK(![escaped prospectiveCommitIdentifierWithError:NULL] && ![escaped requireBaseCommitIdentifier:receipt error:NULL],
          "escaped source commit access is rejected"); escaped = nil;
    NSDictionary *before = ReadPair(store, folder); __block NSString *unused = nil;
    CHECK([store performStandaloneWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        unused = [tx prospectiveCommitIdentifierWithError:error]; return unused != nil;
    } error:NULL] && [before isEqual:ReadPair(store, folder)] && ![unused isEqual:receipt],
          "no-op candidate never becomes a committed source receipt");
    PXRuntimeSourceStore *competitor = Store(folder);
    CHECK(WritePair(competitor, folder, 2, NO) && WritePair(competitor, folder, 1, NO), "cooperative source ABA fixture committed");
    before = ReadPair(store, folder); NSError *failure = nil;
    CHECK(![store performStandaloneWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        [tx setDictionary:@{ @"value": @99 } atPath:Path(folder, @"a.plist") error:error];
        [tx requireBaseCommitIdentifier:receipt error:error]; return YES;
    } error:&failure] && failure && [before isEqual:ReadPair(store, folder)],
          "ignored stale source precondition poisons staged writes despite matching ABA values");
    NSString *current = before[@"sourceCommitID"];
    CHECK([store performStandaloneWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        __block BOOL rejected = NO;
        dispatch_sync(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            rejected = ![tx requireBaseCommitIdentifier:current error:NULL] && ![tx prospectiveCommitIdentifierWithError:NULL];
        });
        return rejected && [tx requireBaseCommitIdentifier:current error:error];
    } error:NULL] && [before isEqual:ReadPair(store, folder)], "source commit helpers reject wrong thread without poisoning owner");
    NSTask *child = Child(binary, @"--increment", folder, @"1"); [child waitUntilExit];
    before = ReadPair(store, folder);
    CHECK(child.terminationStatus == 0 && ![store performStandaloneWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx requireBaseCommitIdentifier:current error:error];
    } error:NULL] && [before isEqual:ReadPair(store, folder)], "cross-process source commit invalidates stale precondition without writes");
    current = before[@"sourceCommitID"];
    __block NSString *failedCandidate = nil;
    store.testCheckpoint = ^(NSString *stage) { if ([stage isEqual:@"source-written"]) [NSException raise:@"fixture.receipt" format:@"physical failure"]; };
    CHECK(![store performStandaloneWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        if (![tx requireBaseCommitIdentifier:current error:error]) return NO;
        failedCandidate = [tx prospectiveCommitIdentifierWithError:error];
        return [tx setDictionary:@{ @"value": @4 } atPath:Path(folder, @"a.plist") error:error];
    } error:NULL] && failedCandidate && [before isEqual:ReadPair(store, folder)], "failed candidate preserves old marker and exact source tuple");
    store.testCheckpoint = nil;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc == 4) {
            NSString *mode = @(argv[1]), *folder = @(argv[2]), *argument = @(argv[3]);
            __attribute__((objc_precise_lifetime)) PXRuntimeSourceStore *store = Store(folder);
            if (!store) return 2;
            if ([mode isEqual:@"--crash"] || [mode isEqual:@"--remove-crash"]) {
                __block NSUInteger files = 0;
                store.testCheckpoint = ^(NSString *stage) {
                    if ([stage isEqual:@"source-written"]) files++;
                    if ([stage isEqual:argument] || ([argument isEqual:@"last-source-written"] && files == 3)) _exit(77);
                };
                if ([mode isEqual:@"--remove-crash"]) RemovePair(store, folder);
                else WritePair(store, folder, 99, YES);
                return 3;
            }
            if ([mode isEqual:@"--recover-crash"]) {
                store.testCheckpoint = ^(NSString *stage) { if ([stage isEqual:@"recovery-source-written"]) _exit(78); };
                [store performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) { (void)tx; (void)error; return YES; } error:NULL];
                return 3;
            }
            if ([mode isEqual:@"--hold"]) {
                [store performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
                    (void)tx; (void)error; [@"ready" writeToFile:Path(folder, @"ready") atomically:YES encoding:NSUTF8StringEncoding error:nil];
                    sleep(10); return YES;
                } error:NULL]; return 0;
            }
            if ([mode isEqual:@"--increment"]) {
                NSUInteger iterations = (NSUInteger)MAX(argument.integerValue, (NSInteger)0);
                for (NSUInteger i = 0; i < iterations; i++) {
                    BOOL success = [store performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
                        NSDictionary *old = [tx dictionaryAtPath:Path(folder, @"a.plist") error:error];
                        if (!old) return NO;
                        NSDictionary *value = @{ @"value": @([old[@"value"] unsignedIntegerValue] + 1) };
                        return [tx setDictionary:value atPath:Path(folder, @"a.plist") error:error] &&
                               [tx setDictionary:value atPath:Path(folder, @"b.plist") error:error];
                    } error:NULL];
                    if (!success) return 4;
                    usleep(1000);
                }
                return 0;
            }
        }
        NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        [NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
        TestStaging(root); TestFailures(root);
        NSString *binary = [NSString stringWithUTF8String:argv[0]];
        TestCrashRecovery(root, binary); TestRemovals(root, binary); TestProcesses(root, binary); TestCommitPreconditions(root, binary);
        [NSFileManager.defaultManager removeItemAtPath:root error:nil];
        printf("Runtime source transactions: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
