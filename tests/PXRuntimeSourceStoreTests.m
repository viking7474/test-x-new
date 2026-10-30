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
        // dispatch_sync may inline on this owner thread. Async work plus a
        // bounded semaphore wait provides a genuinely foreign-thread probe.
        NSThread *ownerThread = NSThread.currentThread;
        __block BOOL rejected = NO;
        __block BOOL offOwner = NO;
        dispatch_semaphore_t checked = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            @autoreleasepool {
                offOwner = NSThread.currentThread != ownerThread;
                NSError *requireError = nil, *baseError = nil, *candidateError = nil;
                BOOL requireRejected = ![tx requireBaseCommitIdentifier:current error:&requireError];
                BOOL baseRejected = [tx baseCommitIdentifierWithError:&baseError] == nil;
                BOOL candidateRejected = [tx prospectiveCommitIdentifierWithError:&candidateError] == nil;
                rejected = requireRejected && baseRejected && candidateRejected && requireError && baseError && candidateError;
            }
            dispatch_semaphore_signal(checked);
        });
        BOOL completed = dispatch_semaphore_wait(checked, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC)) == 0;
        // On timeout, do not read fields that the still-running worker may write.
        CHECK(completed && offOwner, "source commit probe completes on a distinct thread");
        return completed && offOwner && rejected && [tx requireBaseCommitIdentifier:current error:error];
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

static void TestCommitAcknowledgement(NSString *root) {
    NSArray *phases = @[@"commit-written", @"journal-cleanup", @"transaction-recovery", @"both-cleanups"];
    for (NSString *phase in phases) {
        NSString *folder = NewCase(root, [@"ack-" stringByAppendingString:phase]);
        PXRuntimeSourceStore *store = Store(folder);
        CHECK(WritePair(store, folder, 1, NO), "commit acknowledgement baseline seeded");
        __block NSString *receipt = nil; __block NSUInteger faults = 0, markers = 0, restores = 0;
        store.testCheckpoint = ^(NSString *stage) {
            if ([stage isEqual:@"commit-written"]) markers++;
            if ([stage isEqual:@"recovery-source-written"]) restores++;
            BOOL cleanup = [stage isEqual:@"journal-cleanup"] || [stage isEqual:@"transaction-recovery"];
            if ([stage isEqual:phase] || ([phase isEqual:@"both-cleanups"] && cleanup)) {
                faults++; [NSException raise:@"fixture.ack" format:@"post marker housekeeping failed"];
            }
        };
        NSError *failure = [NSError errorWithDomain:@"fixture.stale" code:1 userInfo:nil];
        BOOL success = [store performStandaloneWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
            if (![tx setDictionary:@{ @"value": @2 } atPath:Path(folder, @"a.plist") error:error] ||
                ![tx setDictionary:@{ @"value": @2 } atPath:Path(folder, @"b.plist") error:error]) return NO;
            receipt = [tx prospectiveCommitIdentifierWithError:error]; return receipt != nil;
        } error:&failure];
        store.testCheckpoint = nil;
        PXRuntimeSourceStore *reader = Store(folder); // A second fd must acquire the released gate.
        NSDictionary *committed = ReadPair(reader, folder);
        BOOL pending = [NSFileManager.defaultManager fileExistsAtPath:Path(folder, @"control/pending.plist")];
        CHECK(success && !failure && receipt && [receipt isEqual:committed[@"sourceCommitID"]] &&
              [committed[@"a"][@"value"] isEqual:@2] && [committed[@"b"][@"value"] isEqual:@2] &&
              markers == 1 && restores == 0 && faults == ([phase isEqual:@"both-cleanups"] ? 2 : 1),
              "acknowledged marker survives post-commit and finally exceptions without rollback or error");
        CHECK(pending == [phase isEqual:@"both-cleanups"], "failed post-commit housekeeping retains only a matching committed journal");
        CHECK(WritePair(reader, folder, 3, NO) && ![NSFileManager.defaultManager fileExistsAtPath:Path(folder, @"control/pending.plist")] &&
              [ReadPair(store, folder)[@"a"][@"value"] isEqual:@3], "subsequent owner cleans committed journal and writes after acknowledgement exception");
        NSDictionary *before = ReadPair(store, folder); __block NSString *candidate = nil;
        failure = nil;
        CHECK(![store performStandaloneWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
            candidate = [tx prospectiveCommitIdentifierWithError:error];
            [tx setDictionary:@{ @"value": @9 } atPath:Path(folder, @"a.plist") error:error];
            [NSException raise:@"fixture.ack" format:@"body rejected candidate"]; return YES;
        } error:&failure] && failure && candidate && [before isEqual:ReadPair(store, folder)],
              "candidate and earlier committed marker never acknowledge a throwing body");
    }
    NSString *folder = NewCase(root, @"ack-pre-marker-recovery"); PXRuntimeSourceStore *store = Store(folder);
    CHECK(WritePair(store, folder, 1, NO), "pre marker recovery exception baseline seeded");
    NSDictionary *before = ReadPair(store, folder);
    store.testCheckpoint = ^(NSString *stage) {
        if ([stage isEqual:@"source-written"] || [stage isEqual:@"recovery-source-written"])
            [NSException raise:@"fixture.ack" format:@"pre marker and restore failure"];
    };
    NSError *failure = nil;
    CHECK(!WritePair(store, folder, 2, NO) && ReadPair(store, folder) == nil &&
          [NSFileManager.defaultManager fileExistsAtPath:Path(folder, @"control/pending.plist")],
          "pre-marker recovery exception still fails closed and keeps uncommitted journal");
    store.testCheckpoint = nil;
    CHECK([store performStandaloneWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        (void)tx; (void)error; return YES;
    } error:&failure] && !failure && [before isEqual:ReadPair(store, folder)], "retry recovers complete old tuple after pre-marker recovery exception");

    folder = NewCase(root, @"ack-marker-write-failure"); store = Store(folder);
    CHECK(WritePair(store, folder, 1, NO), "marker write failure baseline seeded"); before = ReadPair(store, folder);
    NSString *markerPath = Path(folder, @"control/commit.plist"); NSData *marker = [NSData dataWithContentsOfFile:markerPath];
    __block NSUInteger writes = 0;
    @try {
        store.testCheckpoint = ^(NSString *stage) {
            if ([stage isEqual:@"source-written"] && ++writes == 2) {
                CHECK([NSFileManager.defaultManager removeItemAtPath:markerPath error:NULL] &&
                      [NSFileManager.defaultManager createDirectoryAtPath:markerPath withIntermediateDirectories:NO attributes:nil error:NULL],
                      "marker failure fixture reserves a directory at marker destination");
            }
        };
        failure = nil;
        CHECK(![store performStandaloneWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
            return [tx setDictionary:@{ @"value": @2 } atPath:Path(folder, @"a.plist") error:error] &&
                   [tx setDictionary:@{ @"value": @2 } atPath:Path(folder, @"b.plist") error:error];
        } error:&failure] && failure && ReadPair(store, folder) == nil,
              "failed marker rename never acknowledges completed source writes");
    } @finally {
        store.testCheckpoint = nil;
        CHECK([NSFileManager.defaultManager removeItemAtPath:markerPath error:NULL] && [marker writeToFile:markerPath atomically:YES] &&
              chmod(markerPath.fileSystemRepresentation, 0600) == 0,
              "marker failure teardown restores the original marker bytes");
    }
    CHECK([store performStandaloneWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        (void)tx; (void)error; return YES;
    } error:&failure] && !failure && [before isEqual:ReadPair(store, folder)], "marker failure recovery restores old tuple and releases source ownership");
}

static void TestCaptureDictionaryDecoder(NSString *root) {
    NSString *folder = NewCase(root, @"capture-dictionary"); PXRuntimeSourceStore *store = Store(folder);
    CHECK(WritePair(store, folder, 1, NO), "capture dictionary decoder baseline seeded");
    NSDictionary *view = [store capture:^NSDictionary *(NSError **error) {
        NSDictionary *present = PXReadRuntimeSourceDictionary(Path(folder, @"a.plist"), error);
        if (!present) return nil;
        NSDictionary *missing = PXReadRuntimeSourceDictionary(Path(folder, @"c.plist"), error);
        return missing ? @{ @"present": present, @"missing": missing } : nil;
    } error:NULL];
    CHECK([view[@"present"][@"value"] isEqual:@1] && [view[@"missing"] isEqual:@{}],
          "capture decoder distinguishes valid dictionary from missing empty source");
    NSString *path = Path(folder, @"a.plist"); NSData *saved = [NSData dataWithContentsOfFile:path];
    NSDictionary *before = ReadPair(store, folder);
    @try {
        CHECK([[@"broken plist" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:YES], "capture decoder malformed fixture seeded");
        NSError *failure = nil;
        CHECK(![store capture:^NSDictionary *(NSError **error) { return PXReadRuntimeSourceDictionary(path, error); } error:&failure] && failure,
              "capture decoder rejects malformed source instead of silently treating it as missing");
        CHECK([NSPropertyListSerialization dataWithPropertyList:@[@"wrong root"] format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL] &&
              [@[@"wrong root"] writeToFile:path atomically:YES], "capture decoder non dictionary fixture seeded");
        failure = nil;
        CHECK(![store capture:^NSDictionary *(NSError **error) { return PXReadRuntimeSourceDictionary(path, error); } error:&failure] && failure,
              "capture decoder rejects valid plist with non dictionary root");
    } @finally { CHECK([saved writeToFile:path atomically:YES], "capture decoder teardown restores exact source bytes"); }
    CHECK([before isEqual:ReadPair(store, folder)], "capture decoder failures preserve original commit marker and restored tuple");
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
        TestCrashRecovery(root, binary); TestRemovals(root, binary); TestProcesses(root, binary); TestCommitPreconditions(root, binary); TestCommitAcknowledgement(root); TestCaptureDictionaryDecoder(root);
        [NSFileManager.defaultManager removeItemAtPath:root error:nil];
        printf("Runtime source transactions: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
