#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#include <math.h>
#include <stdatomic.h>
#include <stdio.h>

static NSUInteger gChecks, gFailures, gReads, gWrites, gProviders, gSourceCalls;
static BOOL gHeld, gObserveResolver;
static NSString *gFault;
static NSMutableDictionary *gFiles;
static void (^gDuringRead)(void), (^gDuringPrepare)(void), (^gDuringAcquire)(void), (^gBeforeWrite)(void), (^gAfterCommit)(void), (^gDuringCopy)(void), (^gDuringInput)(void), (^gDuringDealloc)(void);
static NSHashTable *gCallbackRoots;
static __weak id gMutationRoot, gTransactionRoot;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
static void Raise(void) { [NSException raise:@"fixture.storage" format:@"controlled failure"]; }
static void Run(void (^ __strong *slot)(void)) {
    void (^callback)(void) = *slot; *slot = nil;
    @try { if (callback) callback(); } @finally { callback = nil; }
}
static NSString *PXValidatedProfileID(NSString * __unsafe_unretained value) {
    return [value isKindOfClass:NSString.class] && ([value isEqual:@"a"] || [value isEqual:@"b"]) ? value : nil;
}
static NSString *PXCurrentProfileInfoPath(void) { return @"/selection"; }
static NSString *PXActiveProfileID(void) { return @"a"; }
static NSString *PXProfileRootPath(NSString * __unsafe_unretained value) { return [@"/profiles/" stringByAppendingString:value]; }
static NSString *PXProfileIdentityPath(NSString * __unsafe_unretained value) { return [PXProfileRootPath(value) stringByAppendingPathComponent:@"identity"]; }
static NSString *PXTLinkIOSSettingsPath(void) { return @"/settings"; }
#define PXLog(...) do {} while (0)
@interface NSDictionary (StorageFixtureRead)
+ (NSDictionary *)px_storageRead:(NSString *)path;
@end
@implementation NSDictionary (StorageFixtureRead)
+ (NSDictionary *)px_storageRead:(NSString * __unsafe_unretained)path {
    NSDictionary *row = gFiles[path]; gReads++;
    @try {
        if ([gFault isEqual:@"read"]) Raise();
        Run(&gDuringRead); return row;
    } @finally { row = nil; }
}
@end
@interface IPhoneModelDB : NSObject
+ (instancetype)sharedManager;
- (NSDictionary *)specForProductType:(NSString *)model;
- (NSDictionary *)canonicalHardwareSpecForProductType:(NSString *)model;
@end
@implementation IPhoneModelDB
+ (instancetype)sharedManager { return [self new]; }
- (NSDictionary *)specForProductType:(NSString *)model { (void)model; return @{}; }
- (NSDictionary *)canonicalHardwareSpecForProductType:(NSString *)model { (void)model; return @{ @"storageCapacitiesGB": @[@64, @128] }; }
@end
@interface DeviceModelManager : NSObject
+ (instancetype)sharedManager;
- (NSDictionary *)deviceSpecificationsForModel:(NSString *)model;
@end
@implementation DeviceModelManager
+ (instancetype)sharedManager { return [self new]; }
- (NSDictionary *)deviceSpecificationsForModel:(NSString *)model { (void)model; return @{}; }
@end
static NSDictionary *PXPrepareRuntimeStorage(NSString * __unsafe_unretained capacity) {
    gProviders++; Run(&gDuringPrepare);
    if ([gFault isEqual:@"prepare"]) Raise();
    return capacity ? @{ @"TotalStorage": capacity, @"FreeStorage": @"12", @"FilesystemType": @"0x1A" } : nil;
}
@interface PXRuntimeSourceTransaction : NSObject
@property (nonatomic, strong) NSMutableDictionary *staged;
- (BOOL)setDictionary:(NSDictionary *)value atPath:(NSString *)path error:(NSError **)error;
- (NSDictionary *)dictionaryAtPath:(NSString *)path error:(NSError **)error;
@end
@implementation PXRuntimeSourceTransaction
- (BOOL)setDictionary:(NSDictionary * __unsafe_unretained)value atPath:(NSString * __unsafe_unretained)path error:(NSError **)error {
    (void)error; if ([gFault isEqual:@"stage"]) Raise();
    if (!value || !path) return NO;
    if (!self.staged) self.staged = [NSMutableDictionary dictionary];
    self.staged[path] = [value copy]; return YES;
}
- (NSDictionary *)dictionaryAtPath:(NSString * __unsafe_unretained)path error:(NSError **)error {
    (void)error; if ([gFault isEqual:@"stage-read"]) Raise();
    return self.staged[path] ?: gFiles[path];
}
@end
static BOOL PXPerformStandaloneRuntimeSourceWrite(BOOL (^ __unsafe_unretained body)(PXRuntimeSourceTransaction *, NSError **), NSError **error) {
    PXRuntimeSourceTransaction *tx = [PXRuntimeSourceTransaction new];
    @try { return body(tx, error); } @finally { tx = nil; }
}
@interface PXProfileArtifactMutation : NSObject
@property (nonatomic, copy) NSString *profileDirectory;
@property (nonatomic) BOOL active;
+ (instancetype)acquireWithProfileIDResolver:(NSString *(^)(void))resolver error:(NSError **)error NS_RETURNS_RETAINED;
- (BOOL)performSourceWrite:(BOOL (^)(PXRuntimeSourceTransaction *, NSError **))body error:(NSError **)error;
- (void)invalidate;
@end
@implementation PXProfileArtifactMutation
+ (instancetype)acquireWithProfileIDResolver:(NSString *(^ __unsafe_unretained)(void))resolver error:(NSError **)error {
    if (gHeld) { if (error) *error = [NSError errorWithDomain:@"fixture.busy" code:12 userInfo:nil]; return nil; }
    PXProfileArtifactMutation *owner = [self new];
    NSString *target = nil; BOOL handedOff = NO;
    owner.active = YES; gHeld = YES; gMutationRoot = owner;
    @try {
        // Display's resolver has no captures and may be a permanent global
        // block. Observe resolver lifetime only for explicit save tests, whose
        // resolver carries the requested target/current flag. Write bodies
        // below always carry captured records/owner and are observed in all tests.
        if (gObserveResolver) [gCallbackRoots addObject:resolver];
        Run(&gDuringAcquire);
        if ([gFault isEqual:@"acquire"]) Raise();
        target = resolver(); if (!target) return nil;
        owner.profileDirectory = PXProfileRootPath(target);
        handedOff = YES; return owner;
    } @finally { if (!handedOff) [owner invalidate]; target = nil; owner = nil; }
}
- (BOOL)performSourceWrite:(BOOL (^ __unsafe_unretained)(PXRuntimeSourceTransaction *, NSError **))body error:(NSError **)error {
    PXRuntimeSourceTransaction *tx = [PXRuntimeSourceTransaction new]; gTransactionRoot = tx;
    @try {
        gSourceCalls++; [gCallbackRoots addObject:body]; Run(&gBeforeWrite);
        BOOL result = body(tx, error);
        if (result) { [gFiles addEntriesFromDictionary:tx.staged]; gWrites++; Run(&gAfterCommit); }
        return result;
    } @finally { tx = nil; }
}
- (void)invalidate { if (self.active) { self.active = NO; gHeld = NO; } }
@end

#include "PXStorageReadHelpers.inc"
@interface PXStorageManagerFixture : NSObject {
    NSDictionary *_storageSettings;
    uint64_t _storageCacheRevision;
    BOOL _isEnabled, _storagePreferenceWriteInFlight;
}
#include "PXStorageReadDeclarations.inc"
- (NSDictionary *)generateStorageForCapacity:(NSString *)capacity;
- (void)adoptCommittedStorageInfo:(NSDictionary *)storageInfo;
- (NSDictionary *)currentStorageInfo;
- (BOOL)commitDisplayStorageInfo:(NSDictionary *)values updateFilesystem:(BOOL)updateFilesystem error:(NSError **)error;
- (BOOL)persistStorageToProfile:(NSString *)profileID current:(BOOL)current error:(NSError **)error;
- (void)saveToCurrentProfile;
- (void)saveToProfile:(NSString *)profileId;
- (void)setTotalStorageCapacity:(NSString *)capacity;
- (void)setFreeStorageSpace:(NSString *)freeSpace;
- (void)setFilesystemType:(NSString *)fsType;
- (BOOL)isStorageSpoofingEnabled;
- (void)setStorageSpoofingEnabled:(BOOL)enabled;
- (BOOL)setStorageSpoofingEnabled:(BOOL)enabled error:(NSError **)error;
- (void)installCopyProbe:(NSDictionary *)record;
@end
@interface PXStorageCopyProbe : NSObject <NSCopying>
@property (nonatomic, copy) NSDictionary *record;
@end
@implementation PXStorageCopyProbe
- (id)copyWithZone:(NSZone *)zone {
    (void)zone; NSDictionary *record = self.record;
    @try { Run(&gDuringCopy); if ([gFault isEqual:@"copy"]) Raise(); return record; }
    @finally { record = nil; }
}
@end
#define dictionaryWithContentsOfFile px_storageRead
@implementation PXStorageManagerFixture
- (void)installCopyProbe:(NSDictionary *)record {
    PXStorageCopyProbe *probe = [PXStorageCopyProbe new]; probe.record = record;
    @synchronized (self) { _storageSettings = (id)probe; }
}
#include "PXPreparedStorageMethod.inc"
@end
#undef dictionaryWithContentsOfFile

@interface PXStorageInputRecord : NSObject <NSCopying, NSMutableCopying>
@property (nonatomic, copy) NSDictionary *record;
@end
@implementation PXStorageInputRecord
- (BOOL)isKindOfClass:(Class)type { return type == NSDictionary.class || [super isKindOfClass:type]; }
- (id)copyWithZone:(NSZone *)zone {
    (void)zone; Run(&gDuringInput); if ([gFault isEqual:@"input-copy"]) Raise(); return [self.record copy];
}
- (id)mutableCopyWithZone:(NSZone *)zone {
    (void)zone; Run(&gDuringInput); return [self.record mutableCopy];
}
@end
@interface PXStorageDeallocProbe : NSObject
@end
@implementation PXStorageDeallocProbe
- (void)dealloc { Run(&gDuringDealloc); }
@end

static NSDictionary *Record(NSString *total, NSString *free) { return @{ @"TotalStorage": total, @"FreeStorage": free, @"FilesystemType": @"0x1A" }; }
static void Reset(void) {
    gFault = nil; gHeld = NO; gObserveResolver = NO; gReads = gWrites = gProviders = gSourceCalls = 0;
    gDuringRead = nil; gDuringPrepare = nil; gDuringAcquire = nil; gBeforeWrite = nil; gAfterCommit = nil; gDuringCopy = nil; gDuringInput = nil; gDuringDealloc = nil;
    gFiles = [@{ @"/selection": @{ @"ProfileId": @"a" } } mutableCopy];
    gCallbackRoots = [NSHashTable weakObjectsHashTable]; gMutationRoot = nil; gTransactionRoot = nil;
}
static void TestSnapshotsAndInputs(void) {
    Reset(); PXStorageManagerFixture *manager = [PXStorageManagerFixture new];
    NSMutableString *total = [@"128" mutableCopy], *free = [@"32" mutableCopy];
    NSMutableDictionary *input = [@{ @"TotalStorage": total, @"FreeStorage": free, @"FilesystemType": @26, @"keep": @YES } mutableCopy];
    [manager adoptCommittedStorageInfo:input]; NSDictionary *before = [manager currentStorageInfo];
    [total setString:@"bad"]; [free setString:@"bad"]; [input removeAllObjects];
    CHECK([[manager totalStorageCapacity] isEqual:@"128"] && [[manager freeStorageSpace] isEqual:@"32"] && [[manager filesystemType] isEqual:@"26"], "storage adoption detaches root and owned mutable scalars preserving numeric fields");
    total = [@"256" mutableCopy]; [manager setTotalStorageCapacity:total]; [total setString:@"bad"];
    CHECK([[manager totalStorageCapacity] isEqual:@"256"] && [[gFiles[@"/profiles/a/storage.plist"] objectForKey:@"TotalStorage"] isEqual:@"256"] && [before[@"TotalStorage"] isEqual:@"128"], "storage setter autosaves frozen candidate and preserves prior snapshots");
    [manager setFreeStorageSpace:nil];
    CHECK(![manager freeStorageSpace] && !gFiles[@"/profiles/a/storage.plist"][@"FreeStorage"] && [manager currentStorageInfo][@"keep"], "storage nil setter removes and autosaves only its field preserving metadata");
    NSUInteger writes = gWrites; uint64_t revision = [manager storageCacheRevision];
    [manager setTotalStorageCapacity:(id)@[]]; [manager adoptCommittedStorageInfo:(id)@[]];
    CHECK(gWrites == writes && [manager storageCacheRevision] == revision && [[manager totalStorageCapacity] isEqual:@"256"], "storage unsupported roots do not poison cache or supersede valid work");
    [manager adoptCommittedStorageInfo:nil];
    CHECK(![manager currentStorageInfo].count && ![manager totalStorageCapacity], "storage nil adoption retains empty-cache compatibility");
    [manager setTotalStorageCapacity:@"64"];
    CHECK([[manager totalStorageCapacity] isEqual:@"64"] && [gFiles[@"/profiles/a/storage.plist"][@"TotalStorage"] isEqual:@"64"], "storage valid setter recovers a previously cleared cache instead of messaging nil");
}
static void TestLoadOrdering(void) {
    Reset(); PXStorageManagerFixture *manager = [PXStorageManagerFixture new];
    NSDictionary *a = Record(@"64", @"16"), *b = Record(@"512", @"123");
    gFiles[@"/profiles/a/storage.plist"] = a; gFiles[@"/profiles/b/storage.plist"] = b;
    gDuringRead = ^{ CHECK([manager loadFromProfile:@"b"], "newer storage loader succeeds"); };
    CHECK(![manager loadFromProfile:@"a"] && [[manager currentStorageInfo] isEqual:b], "older storage loader cannot replace newer profile load");
    gDuringRead = ^{ [manager adoptCommittedStorageInfo:b]; };
    CHECK(![manager loadFromProfile:@"a"] && [[manager currentStorageInfo] isEqual:b], "storage load cannot replace committed adoption during file read");
    [gFiles removeObjectForKey:@"/profiles/a/storage.plist"];
    gDuringPrepare = ^{ [manager adoptCommittedStorageInfo:b]; };
    CHECK(![manager loadFromProfile:@"a"] && [[manager currentStorageInfo] isEqual:b], "storage missing-file defaults cannot replace newer cache intent");
    gDuringRead = ^{ [manager adoptCommittedStorageInfo:b]; };
    NSUInteger reads = gReads, providers = gProviders;
    [manager loadFromCurrentProfile];
    CHECK([[manager currentStorageInfo] isEqual:b], "current storage load claims before canonical lookup");
    CHECK(gReads == reads + 1 && gProviders == providers, "superseded current storage load skips target file reads and default generation");
    CHECK(gWrites == 0, "storage loads and defaults perform no source writes");
}
static void TestSourceAndPublicationOrdering(void) {
    Reset(); PXStorageManagerFixture *manager = [PXStorageManagerFixture new];
    NSDictionary *a = Record(@"64", @"16"), *b = Record(@"512", @"123"), *values = Record(@"128", @"32");
    [manager adoptCommittedStorageInfo:a]; NSError *error = nil;
    gDuringAcquire = ^{ [manager adoptCommittedStorageInfo:b]; };
    CHECK(![manager persistStorageToProfile:@"a" current:NO error:&error] && error.code == 3 && !gSourceCalls && !gWrites && [[manager currentStorageInfo] isEqual:b], "storage save rejects newer cache after acquisition without relabeling its record");
    [manager adoptCommittedStorageInfo:a]; error = nil;
    gDuringAcquire = ^{ [manager adoptCommittedStorageInfo:b]; };
    CHECK(![manager commitDisplayStorageInfo:values updateFilesystem:YES error:&error] && error.code == 3 && !gWrites && [[manager currentStorageInfo] isEqual:b], "storage display preparation cannot claim over newer target lookup adoption");
    [manager adoptCommittedStorageInfo:a]; error = nil;
    gBeforeWrite = ^{ [manager adoptCommittedStorageInfo:b]; };
    CHECK(![manager commitDisplayStorageInfo:values updateFilesystem:YES error:&error] && error.code == 3 && !gWrites && [[manager currentStorageInfo] isEqual:b], "storage display checks its revision before source staging");
    [manager adoptCommittedStorageInfo:a]; error = nil;
    gAfterCommit = ^{ [manager adoptCommittedStorageInfo:b]; };
    CHECK([manager commitDisplayStorageInfo:values updateFilesystem:YES error:&error] && !error && [[manager currentStorageInfo] isEqual:b] && [gFiles[@"/profiles/a/storage.plist"] isEqual:values], "storage acknowledged display commit preserves newer cache adoption without negating source success");
    [manager adoptCommittedStorageInfo:a]; error = nil;
    [manager installCopyProbe:a]; gDuringCopy = ^{ [manager adoptCommittedStorageInfo:b]; };
    NSUInteger writes = gWrites;
    CHECK(![manager persistStorageToProfile:@"a" current:NO error:&error] && error.code == 3 && gWrites == writes && [[manager currentStorageInfo] isEqual:b], "storage copy reentry cannot stage a superseded entry snapshot");
    [manager adoptCommittedStorageInfo:a]; error = nil;
    PXStorageInputRecord *input = [PXStorageInputRecord new]; input.record = values;
    gDuringInput = ^{ [manager adoptCommittedStorageInfo:b]; };
    writes = gWrites;
    CHECK(![manager commitDisplayStorageInfo:(id)input updateFilesystem:YES error:&error] && error.code == 3 && gWrites == writes && [[manager currentStorageInfo] isEqual:b], "storage display input copy cannot reclaim ownership after reentrant adoption");
    input.record = a; gDuringInput = ^{ [manager adoptCommittedStorageInfo:b]; };
    [manager adoptCommittedStorageInfo:(id)input];
    CHECK([[manager currentStorageInfo] isEqual:b], "storage committed adoption copy cannot overwrite a newer reentrant adoption");
    CHECK(!gHeld, "storage source outcomes release lifecycle capability");
}
static void TestCopyAndLifetime(void) {
    for (NSString *fault in @[@"acquire", @"copy", @"stage", @"stage-read", @"read", @"prepare", @"input-copy", @"save-acquire", @"save-copy", @"save-stage", @"save-current-stage", @"setter-stage", @"display-no-filesystem-stage"]) {
        Reset(); __weak id weakManager = nil, weakToken = nil, weakTarget = nil;
        BOOL saving = [fault hasPrefix:@"save-"];
        BOOL currentSave = [fault isEqual:@"save-current-stage"], setter = [fault isEqual:@"setter-stage"];
        BOOL noFilesystem = [fault isEqual:@"display-no-filesystem-stage"];
        NSString *activeFault = currentSave || setter || noFilesystem ? @"stage" : (saving ? [fault substringFromIndex:5] : fault);
        gObserveResolver = saving;
        @autoreleasepool {
            PXStorageManagerFixture *manager = [PXStorageManagerFixture new]; weakManager = manager;
            id token = [NSObject new]; weakToken = token;
            NSDictionary *root = @{ @"TotalStorage": @"64", @"FreeStorage": @"16", @"keep": token };
            [manager adoptCommittedStorageInfo:root];
            if ([activeFault isEqual:@"copy"]) [manager installCopyProbe:root];
            gFault = activeFault; BOOL threw = NO;
            @try {
                if (currentSave) [manager saveToCurrentProfile];
                else if (setter) [manager setTotalStorageCapacity:@"128"];
                else if (saving) {
                    NSMutableString *target = [@"a" mutableCopy]; weakTarget = target;
                    @try { [manager saveToProfile:target]; } @finally { target = nil; }
                } else if ([fault isEqual:@"read"] || [fault isEqual:@"prepare"]) [manager loadFromProfile:@"a"];
                else if ([fault isEqual:@"input-copy"]) {
                    PXStorageInputRecord *input = [PXStorageInputRecord new]; input.record = root;
                    @try { [manager commitDisplayStorageInfo:(id)input updateFilesystem:YES error:NULL]; }
                    @finally { input = nil; }
                } else [manager commitDisplayStorageInfo:Record(@"128", @"32") updateFilesystem:!noFilesystem error:NULL];
            } @catch (NSException *exception) { threw = [exception.name isEqual:@"fixture.storage"]; }
            CHECK(threw && !gHeld && !gWrites, "storage exceptional preparation keeps propagation and releases capability without writes");
            if (setter) CHECK([[manager totalStorageCapacity] isEqual:@"128"], "storage setter stage exception preserves cache-first candidate policy");
            manager = nil; root = nil; token = nil; [gFiles removeAllObjects];
        }
        if (weakManager || weakToken || weakTarget || gMutationRoot || gTransactionRoot || gCallbackRoots.allObjects.count)
            fprintf(stderr, "DETAIL: storage fault=%s manager=%d token=%d target=%d mutation=%d tx=%d callbacks=%lu\n", fault.UTF8String, weakManager != nil, weakToken != nil, weakTarget != nil, gMutationRoot != nil, gTransactionRoot != nil, (unsigned long)gCallbackRoots.allObjects.count);
        CHECK(!weakManager && !weakToken && !weakTarget && !gMutationRoot && !gTransactionRoot && !gCallbackRoots.allObjects.count, "storage exceptional exit drops owner records and method argument block captures after pool drain");
    }
}
static void TestSuccessfulCallbackLifetime(void) {
    for (NSUInteger saving = 0; saving < 2; saving++) {
        Reset(); gObserveResolver = saving != 0;
        __weak id weakManager = nil, weakToken = nil;
        @autoreleasepool {
            PXStorageManagerFixture *manager = [PXStorageManagerFixture new]; weakManager = manager;
            id token = [NSObject new]; weakToken = token;
            NSDictionary *root = @{ @"TotalStorage": @"64", @"FreeStorage": @"16", @"keep": token };
            [manager adoptCommittedStorageInfo:root];
            if (saving) [manager saveToProfile:@"a"];
            else CHECK([manager commitDisplayStorageInfo:Record(@"128", @"32") updateFilesystem:YES error:NULL],
                       "storage callback success control preserves acknowledged display commit");
            CHECK(gWrites == 1 && gSourceCalls == 1 && !gHeld,
                  "storage callback construction scopes preserve single save and display source invocation");
            [gFiles removeAllObjects]; manager = nil; root = nil; token = nil;
        }
        CHECK(!weakManager && !weakToken && !gMutationRoot && !gTransactionRoot && !gCallbackRoots.allObjects.count,
              "storage successful callbacks release manager metadata capability and captured heap blocks after pool drain");
    }
}
static void TestMonitorBoundariesAndStress(void) {
    Reset(); PXStorageManagerFixture *manager = [PXStorageManagerFixture new];
    NSDictionary *a = Record(@"64", @"16"), *b = Record(@"512", @"123");
    [manager installCopyProbe:a];
    dispatch_group_t group = dispatch_group_create(); dispatch_semaphore_t done = dispatch_semaphore_create(0);
    gDuringCopy = ^{
        dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            @autoreleasepool { (void)[manager currentStorageInfo]; dispatch_semaphore_signal(done); }
        });
        CHECK(dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0, "storage copy executes outside cache monitor allowing another-thread reader");
    };
    (void)[manager currentStorageInfo]; dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    [manager adoptCommittedStorageInfo:a];
    __block _Atomic unsigned failures = 0;
    dispatch_apply(256, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
        @autoreleasepool {
            [manager adoptCommittedStorageInfo:index % 2 ? a : b];
            NSDictionary *record = [manager currentStorageInfo];
            if (![record isEqual:a] && ![record isEqual:b]) atomic_fetch_add_explicit(&failures, 1, memory_order_relaxed);
        }
    });
    CHECK(atomic_load_explicit(&failures, memory_order_relaxed) == 0, "concurrent storage root replacements never expose mixed or partially mutated records");
    CHECK(!gReads && !gWrites && !gProviders, "storage cache observations perform no disk generation or source work");
    __block BOOL released = NO;
    @autoreleasepool {
        PXStorageDeallocProbe *token = [PXStorageDeallocProbe new];
        [manager adoptCommittedStorageInfo:@{ @"TotalStorage": @"64", @"FreeStorage": @"16", @"release": token }];
        token = nil;
    }
    gDuringDealloc = ^{
        dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            @autoreleasepool { (void)[manager currentStorageInfo]; dispatch_semaphore_signal(done); }
        });
        released = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0;
    };
    [manager adoptCommittedStorageInfo:b]; dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    CHECK(released, "discarded storage cache root deallocates outside monitor allowing another-thread reader");
}
int main(void) {
    @autoreleasepool {
        @try { TestSnapshotsAndInputs(); TestLoadOrdering(); TestSourceAndPublicationOrdering(); TestCopyAndLifetime(); TestSuccessfulCallbackLifetime(); TestMonitorBoundariesAndStress(); }
        @catch (NSException *exception) { gFailures++; fprintf(stderr, "FAIL: unexpected storage exception: %s\n", exception.description.UTF8String); }
        printf("Storage manager cache: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
