#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "ProfileManager.h"
#import "PXRuntimeProfileSelection.h"
#import "PXRuntimeGeneration.h"
#import "PXRuntimeArtifactWriter.h"
#include <stdatomic.h>
#include <unistd.h>

static NSUInteger gChecks, gFailures, gNotices, gCanvas, gMirrors, gTerminations, gCachePublications, gSettingsNotices;
static NSString *gRoot, *gRequested, *gMirroredID, *gMemoryID;
static NSDictionary *gPreparedNetwork;
static PXRuntimeSourceStore *gStore;
static NSDictionary *gNetworkOptions;
static _Atomic BOOL gEntered, gCommitted, gInActivation;
static void (^gDuringTermination)(void);
static void (^gAfterGeneration)(void);
static BOOL gPause, gFailGeneration, gThrowGeneration, gNoIPv4, gThrowObserver;
static dispatch_semaphore_t gRelease;
#define CHECK(value, message) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", message); } } while (0)
static NSString *Path(NSString *root, NSString *name) { return [root stringByAppendingPathComponent:name]; }
NSString *PXProfilesPath(void) { return Path(gRoot, @"profiles"); }
NSString *PXCurrentProfileInfoPath(void) { return Path(PXProfilesPath(), @"current_profile_info.plist"); }
NSString *PXLegacyActiveProfileInfoPath(void) { return Path(gRoot, @"active_profile_info.plist"); }
NSString *PXValidatedProfileID(id value) {
    if (![value isKindOfClass:NSString.class] || ![value length] || [value containsString:@"/"] || [value containsString:@"\\"] ||
        [value isEqual:@"."] || [value isEqual:@".."]) return nil;
    return [value copy];
}
static NSString *Identity(NSString *profile) { return Path(Path(PXProfilesPath(), profile), @"identity"); }
NSString *PXProfileIdentityPath(NSString *profile) { return PXValidatedProfileID(profile) ? Identity(profile) : nil; }
NSString *PXTLinkIOSSettingsPath(void) { return Path(gRoot, @"settings.plist"); }
NSString *PXGlobalScopePath(void) { return Path(gRoot, @"scope.plist"); }
void PXPostSettingsChangedNotification(void) { gSettingsNotices++; }
static NSDictionary *Record(NSString *path) { return [NSDictionary dictionaryWithContentsOfFile:path] ?: @{}; }
BOOL PXPerformRuntimeSourceWrite(BOOL (^body)(PXRuntimeSourceTransaction *, NSError **), NSError **error) { return [gStore performWrite:body error:error]; }
static BOOL Pump(BOOL (^done)(void)) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
    while (!done() && [deadline timeIntervalSinceNow] > 0)
        [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    return done();
}
static void OutsideGate(void) {
    // This helper can run on a worker; leave CHECK counters on main.
    NSDictionary *captured = [gStore capture:^NSDictionary *(NSError **error) { (void)error; return @{}; } error:NULL];
    if (!captured) [NSException raise:@"fixture" format:@"provider ran under source gate"];
}
@interface NetworkManager : NSObject
+ (NSDictionary *)getRandomCarrierForCountry:(NSString *)country;
+ (NSString *)generateSpoofedLocalIPAddressFromCurrent;
+ (NSString *)generateSpoofedLocalIPv6AddressFromCurrent;
@end
@implementation NetworkManager
+ (NSDictionary *)getRandomCarrierForCountry:(NSString *)country { OutsideGate(); return @{ @"name": country, @"mcc": @"310", @"mnc": @"260" }; }
+ (NSString *)generateSpoofedLocalIPAddressFromCurrent { OutsideGate(); return gNoIPv4 ? nil : @"192.168.1.77"; }
+ (NSString *)generateSpoofedLocalIPv6AddressFromCurrent { OutsideGate(); return @"fd00::77"; }
@end
@interface IdentifierManager : NSObject
+ (instancetype)sharedManager;
- (PXCommittedRuntimeGeneration *)commitRuntimeGenerationForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)artifacts error:(NSError **)error;
- (void)publishCommittedRuntimeGeneration:(PXCommittedRuntimeGeneration *)generation;
- (void)resetCanvasNoise;
@end
@implementation IdentifierManager
+ (instancetype)sharedManager { static id manager; static dispatch_once_t once; dispatch_once(&once, ^{ manager = [self new]; }); return manager; }
- (PXCommittedRuntimeGeneration *)commitRuntimeGenerationForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)artifacts error:(NSError **)error {
    OutsideGate(); gRequested = [profileID copy]; gPreparedNetwork = [artifacts copy]; atomic_store(&gEntered, YES);
    if (gPause && dispatch_semaphore_wait(gRelease, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) != 0)
        [NSException raise:@"fixture" format:@"worker release timed out"];
    if (gThrowGeneration) [NSException raise:@"fixture" format:@"generation exception"];
    if (gFailGeneration) { if (error) *error = [NSError errorWithDomain:@"fixture.generation" code:1 userInfo:nil]; return nil; }
    NSDictionary *payload = @{ @"timestamp": NSDate.date, @"deferSettings": @YES,
        @"settingsPath": PXTLinkIOSSettingsPath(), @"scopePath": PXGlobalScopePath(),
        @"flags": @{ @"Fixture": @YES, @"StorageSystem": @YES }, @"scope": @{ @"fixture.app": @{ @"enabled": @YES } },
        @"scalars": @{}, @"wifi": @{ @"ssid": @"created-wifi", @"bssid": @"02:11:22:33:44:55" }, @"network": artifacts };
    __block PXCommittedRuntimeGeneration *receipt = nil;
    BOOL ok = [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        if (![tx setDictionary:@{ @"generatedFor": profileID } atPath:Path(Identity(profileID), @"device_ids.plist") error:writeError] ||
            !PXStageRuntimeGeneration(tx, Identity(profileID), payload, @{}, writeError)) return NO;
        NSDictionary *proof = PXReadRuntimeGenerationProof(tx, Identity(profileID), payload, writeError);
        if (!proof) return NO;
        receipt = [[PXCommittedRuntimeGeneration alloc] initWithIdentityDirectory:Identity(profileID) payload:payload proof:proof model:nil error:writeError];
        return receipt != nil;
    } error:error];
    atomic_store(&gCommitted, ok);
    void (^callback)(void) = gAfterGeneration; gAfterGeneration = nil; if (callback) callback();
    return ok ? receipt : nil;
}
- (void)publishCommittedRuntimeGeneration:(PXCommittedRuntimeGeneration *)generation {
    gCachePublications++;
    NSString *target = generation.identityDirectory.stringByDeletingLastPathComponent.lastPathComponent;
    CHECK(NSThread.isMainThread && atomic_load(&gCommitted) && [gMemoryID isEqual:target] &&
          [Record(PXCurrentProfileInfoPath())[@"ProfileId"] isEqual:target] &&
          [Record(PXTLinkIOSSettingsPath())[@"EnabledIdentifiers"][@"Fixture"] boolValue], "generation caches publish only after memory selection and settings activation");
    OutsideGate(); PXPostSettingsChangedNotification();
}
- (void)resetCanvasNoise { gCanvas++; CHECK(NSThread.isMainThread && atomic_load(&gCommitted), "canvas reset follows committed generation on main"); }
@end
#include "PXProfileModel.inc"
@interface PXProfileCreationFixture : NSObject
@property (nonatomic, strong) NSMutableArray<Profile *> *mutableProfiles;
@property (nonatomic, strong) Profile *mutableCurrentProfile;
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) NSString *profilesDirectory;
@property (nonatomic) BOOL creationInProgress;
@property (nonatomic) BOOL selectionUnavailable;
@property (nonatomic) BOOL registryUnavailable;
- (void)createDirectoryIfNeeded:(NSString *)path;
- (void)terminateEnabledScopedApps;
- (void)randomizeAppVersionsForProfile:(NSString *)profile;
- (NSDictionary *)captureProfileNetworkOptions;
- (void)mirrorCurrentProfileID:(NSString *)profile;
#include "PXProfileFlowDeclarations.inc"
@end
@implementation PXProfileCreationFixture
- (instancetype)init {
    if ((self = [super init])) { _fileManager = NSFileManager.defaultManager; _profilesDirectory = PXProfilesPath(); _mutableProfiles = [NSMutableArray array]; }
    return self;
}
- (void)createDirectoryIfNeeded:(NSString *)path { [self.fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL]; }
- (void)terminateEnabledScopedApps {
    gTerminations++; atomic_store(&gInActivation, YES);
    CHECK(NSThread.isMainThread, "termination backend runs on main without killing apps");
    void (^callback)(void) = gDuringTermination; gDuringTermination = nil; if (callback) callback();
}
- (void)randomizeAppVersionsForProfile:(NSString *)profile { (void)profile; CHECK(NSThread.isMainThread, "version adapter retains caller queue policy"); }
- (NSDictionary *)captureProfileNetworkOptions {
    return @{ @"enabled": gNetworkOptions[@"enabled"], @"connectionType": gNetworkOptions[@"connectionType"], @"country": [gNetworkOptions[@"country"] copy] };
}
- (void)mirrorCurrentProfileID:(NSString *)profile {
    gMirrors++; gMemoryID = [self.mutableCurrentProfile.profileId copy]; gMirroredID = [profile copy];
    CHECK([Record(PXCurrentProfileInfoPath())[@"ProfileId"] isEqual:profile] &&
          [Record(PXLegacyActiveProfileInfoPath())[@"ProfileId"] isEqual:profile], "defaults mirror follows committed selection pair");
    OutsideGate();
}
#include "PXProfileFlowMethods.inc"
@end
static Profile *New(NSString *name) { return [[Profile alloc] initWithName:name iconName:@"default_profile"]; }
static void ResetWorker(void) {
    atomic_store(&gEntered, NO); atomic_store(&gCommitted, NO); atomic_store(&gInActivation, NO); gDuringTermination = nil; gAfterGeneration = nil;
    gRelease = dispatch_semaphore_create(0); gPause = YES; gFailGeneration = NO; gThrowGeneration = NO;
}
static NSDictionary *ActiveFiles(void) {
    NSMutableDictionary *files = [NSMutableDictionary dictionary];
    for (NSString *path in @[PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), PXTLinkIOSSettingsPath(), PXGlobalScopePath()])
        files[path] = [NSData dataWithContentsOfFile:path] ?: (id)NSNull.null;
    return [files copy];
}
static BOOL SaveRecord(NSString *path, NSDictionary *info) {
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) { return [tx setDictionary:info atPath:path error:error]; } error:NULL];
}
static void TestCreation(PXProfileCreationFixture *manager, Profile *zero) {
    ResetWorker(); Profile *one = New(@"one"); __block NSUInteger callbacks = 0;
    __block BOOL success = NO; __block NSError *failure = nil;
    NSDictionary *before = ActiveFiles(); NSData *archiveBefore = [NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")];
    NSUInteger notices = gNotices, mirrors = gMirrors, caches = gCachePublications, terminations = gTerminations;
    [manager createProfile:one completion:^(BOOL ok, NSError *error) {
        callbacks++; success = ok; failure = error;
        CHECK(NSThread.isMainThread && atomic_load(&gCommitted) && !manager.creationInProgress, "creation waits for generation and completion runs once on main");
    }];
    CHECK(Pump(^BOOL { return atomic_load(&gEntered); }) && callbacks == 0 && manager.creationInProgress &&
          [before isEqual:ActiveFiles()] && manager.mutableCurrentProfile == zero && manager.mutableProfiles.count == 1 &&
          mirrors == gMirrors && caches == gCachePublications && terminations == gTerminations,
          "pending creation preserves active selection settings registry caches and apps");
    __block NSUInteger busy = 0;
    void (^rejected)(BOOL, NSError *) = ^(BOOL ok, NSError *error) { if (!ok && error.code == 12 && NSThread.isMainThread) busy++; };
    [manager createProfile:New(@"overlap") completion:rejected]; [manager switchToProfile:zero completion:rejected];
    [manager updateProfile:zero completion:rejected]; [manager deleteProfile:zero completion:rejected];
    CHECK(busy == 4 && callbacks == 0, "overlapping lifecycle operations reject while creation is pending");
    dispatch_semaphore_signal(gRelease);
    CHECK(Pump(^BOOL { return callbacks > 0; }) && callbacks == 1 && success && !failure && gNotices == notices + 1 &&
          [manager.mutableCurrentProfile.profileId isEqual:one.profileId] && mirrors == gMirrors - 1 && caches == gCachePublications - 1,
          "creation activates and publishes only after generation and metadata commit");
    CHECK([Record(Path(Identity(one.profileId), @"device_ids.plist"))[@"generatedFor"] isEqual:one.profileId] &&
          !Record(Path(Identity(@"0"), @"device_ids.plist"))[@"generatedFor"] && [gRequested isEqual:one.profileId],
          "creation generation writes only the supplied target");
    CHECK([gPreparedNetwork[@"carrier"][@"carrierName"] isEqual:@"us"] && [gPreparedNetwork[@"ipv4"] isEqual:@"192.168.1.77"] &&
          [gPreparedNetwork[@"ipv6"] isEqual:@"fd00::77"], "creation passes one prepared network bundle to generation");
    CHECK(![archiveBefore isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]], "ready profile metadata saved before activation");
    [manager createDirectoryIfNeeded:Path(PXProfilesPath(), @"17")];
    CHECK([[manager generateProfileID] isEqual:@"18"], "directory-only IDs are never reused when archive already has entries");
    for (NSUInteger mode = 0; mode < 2; mode++) {
        ResetWorker(); gPause = NO; gFailGeneration = mode == 0; gThrowGeneration = mode == 1;
        callbacks = 0; notices = gNotices; before = ActiveFiles(); NSUInteger count = manager.mutableProfiles.count;
        archiveBefore = [NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]; mirrors = gMirrors;
        [manager createProfile:New(mode == 0 ? @"failed" : @"exception") completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
        CHECK(Pump(^BOOL { return callbacks > 0; }) && !success && failure && callbacks == 1 && gNotices == notices && mirrors == gMirrors &&
              !manager.creationInProgress && [before isEqual:ActiveFiles()] && count == manager.mutableProfiles.count &&
              [archiveBefore isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]],
              mode == 0 ? "generation failure never publishes profile success" : "generation exception releases busy state and reports failure");
    }
    ResetWorker(); callbacks = 0; notices = gNotices; before = ActiveFiles();
    NSString *archive = Path(PXProfilesPath(), @"profiles.plist"); NSData *saved = [NSData dataWithContentsOfFile:archive];
    NSUInteger count = manager.mutableProfiles.count;
    [manager createProfile:New(@"archive-failure") completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    CHECK(Pump(^BOOL { return atomic_load(&gEntered); }), "archive failure worker paused");
    [manager.fileManager removeItemAtPath:archive error:NULL]; [manager createDirectoryIfNeeded:archive];
    dispatch_semaphore_signal(gRelease);
    CHECK(Pump(^BOOL { return callbacks > 0; }), "archive failure completion arrives");
    BOOL directory = NO;
    CHECK(!success && failure && callbacks == 1 && !manager.creationInProgress && gNotices == notices && [before isEqual:ActiveFiles()] &&
          manager.mutableProfiles.count == count && [manager.fileManager fileExistsAtPath:archive isDirectory:&directory] && directory,
          "metadata failure never unlinks the last archive destination");
    [manager.fileManager removeItemAtPath:archive error:NULL]; CHECK([saved writeToFile:archive atomically:YES], "archive fixture restored");
    ResetWorker(); gPause = NO; callbacks = 0; gThrowObserver = YES;
    [manager createProfile:New(@"observer-exception") completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    CHECK(Pump(^BOOL { return callbacks > 0; }) && success && !failure && callbacks == 1 && !manager.creationInProgress,
          "post commit observer exception never suppresses completion or reports false rollback");
    gThrowObserver = NO;
}
static void TestConflicts(PXProfileCreationFixture *manager) {
    for (NSUInteger mode = 0; mode < 3; mode++) {
        ResetWorker(); __block NSUInteger callbacks = 0; __block BOOL success = YES; __block NSError *failure;
        NSUInteger notices = gNotices, mirrors = gMirrors, caches = gCachePublications, count = manager.mutableProfiles.count;
        NSData *archive = [NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")];
        Profile *candidate = New([NSString stringWithFormat:@"conflict-%lu", (unsigned long)mode]);
        [manager createProfile:candidate completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
        CHECK(Pump(^BOOL { return atomic_load(&gEntered); }), "conflict worker paused");
        NSDictionary *old = Record(PXCurrentProfileInfoPath());
        __block NSDictionary *competitor = nil;
        if (mode < 2) {
            CHECK([manager persistProfileSelectionInfo:@{ @"ProfileId": @"0" } error:NULL], "newer selection commits during pending create");
            if (mode == 1) CHECK([manager persistProfileSelectionInfo:old error:NULL], "ABA returns to same selection with new revision");
            competitor = ActiveFiles();
        } else gAfterGeneration = ^{
            if (!SaveRecord(PXTLinkIOSSettingsPath(), @{ @"newer": @YES })) [NSException raise:@"fixture" format:@"settings competitor failed"];
            competitor = ActiveFiles();
        };
        dispatch_semaphore_signal(gRelease);
        CHECK(Pump(^BOOL { return callbacks > 0; }) && !success && failure && callbacks == 1 && notices == gNotices && mirrors == gMirrors &&
              caches == gCachePublications && count == manager.mutableProfiles.count && [competitor isEqual:ActiveFiles()] &&
              [archive isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]],
              "selection drift ABA and settings changes never clobber newer state");
        CHECK([Record(Path(Identity(candidate.profileId), @"device_ids.plist"))[@"generatedFor"] isEqual:candidate.profileId],
              "creation worker preserves supplied profile after selection drift");
    }
    // A writer in the termination adapter lands after preflight. The final CAS
    // must still reject it, leaving the ready candidate registered but inactive.
    ResetWorker(); gPause = NO; __block BOOL done = NO, success = YES; __block NSDictionary *competitor;
    gDuringTermination = ^{ [manager persistProfileSelectionInfo:@{ @"ProfileId": @"0" } error:NULL]; competitor = ActiveFiles(); };
    [manager createProfile:New(@"late-conflict") completion:^(BOOL ok, NSError *error) { (void)error; done = YES; success = ok; }];
    CHECK(Pump(^BOOL { return done; }) && !success && competitor && [competitor isEqual:ActiveFiles()], "activation rechecks selection after external termination adapter");
}
static void TestSelectionFailure(PXProfileCreationFixture *manager, Profile *zero) {
    NSDictionary *before = ActiveFiles(); Profile *current = manager.mutableCurrentProfile;
    NSUInteger mirrors = gMirrors, caches = gCachePublications, notices = gNotices;
    __block BOOL called = NO, result = YES; __block NSError *failure = nil;
    ResetWorker(); gPause = NO;
    gStore.testCheckpoint = ^(NSString *stage) { if (atomic_load(&gInActivation) && [stage isEqual:@"source-written"]) [NSException raise:@"fixture" format:@"activation fault"]; };
    [manager createProfile:New(@"activation-failure") completion:^(BOOL ok, NSError *error) { called = YES; result = ok; failure = error; }];
    CHECK(Pump(^BOOL { return called; }), "activation fault completion arrives"); gStore.testCheckpoint = nil;
    CHECK(!result && failure && current == manager.mutableCurrentProfile && mirrors == gMirrors && caches == gCachePublications &&
          notices == gNotices && [before isEqual:ActiveFiles()], "activation rollback restores selection settings and scope without publication");
    // Switch must save its metadata before touching selection too.
    NSString *archive = Path(PXProfilesPath(), @"profiles.plist"); NSData *saved = [NSData dataWithContentsOfFile:archive];
    [manager.fileManager removeItemAtPath:archive error:NULL]; [manager createDirectoryIfNeeded:archive]; called = NO;
    [manager switchToProfile:zero completion:^(BOOL ok, NSError *error) { called = YES; result = ok; failure = error; }];
    CHECK(called && !result && failure && current == manager.mutableCurrentProfile && mirrors == gMirrors && [before isEqual:ActiveFiles()],
          "selection pair failure preserves files memory and defaults mirror");
    [manager.fileManager removeItemAtPath:archive error:NULL]; CHECK([saved writeToFile:archive atomically:YES], "switch archive fixture restored");
}
static void TestBackgroundAndPolicy(PXProfileCreationFixture *manager) {
    ResetWorker(); gPause = NO; __block BOOL done = NO, success = NO;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [manager createProfile:New(@"background") completion:^(BOOL ok, NSError *error) { done = YES; success = ok && error == nil && NSThread.isMainThread; }];
    });
    CHECK(Pump(^BOOL { return done; }) && success, "background creation is marshalled to main");
    for (NSNumber *connection in @[@0, @1, @2, @3]) for (NSNumber *enabled in @[@NO, @YES]) {
        NSDictionary *record = [manager prepareNetworkArtifactsWithOptions:@{ @"connectionType": connection, @"enabled": enabled, @"country": @"ca" } error:NULL];
        CHECK((record[@"carrier"] != nil) == (connection.integerValue == 0 || connection.integerValue == 2) &&
              (record[@"ipv4"] != nil) == (enabled.boolValue && connection.integerValue <= 2), "network creation policy preserves carrier and spoof gating");
    }
    gNoIPv4 = YES;
    NSDictionary *record = [manager prepareNetworkArtifactsWithOptions:@{ @"connectionType": @1, @"enabled": @YES, @"country": @"us" } error:NULL];
    CHECK(!record[@"ipv4"] && !record[@"ipv6"], "missing interface preserves skip policy without real IP fallback"); gNoIPv4 = NO;
}
static void TestRestart(PXProfileCreationFixture *manager, Profile *zero) {
    NSString *selected = Record(PXCurrentProfileInfoPath())[@"ProfileId"]; gMirroredID = @"stale-default";
    PXProfileCreationFixture *fresh = [PXProfileCreationFixture new]; __block BOOL loaded = NO, ok = NO;
    [fresh loadProfilesWithCompletion:^(BOOL success, NSError *error) { loaded = YES; ok = success && !error; }];
    CHECK(loaded && ok && [fresh.mutableCurrentProfile.profileId isEqual:selected] && [gMirroredID isEqual:@"stale-default"],
          "restart restores committed selection before stale defaults mirror");
    CHECK(Pump(^BOOL { return [gMirroredID isEqual:selected]; }), "deferred defaults mirror repairs committed selection");
    [fresh loadProfilesWithCompletion:nil];
    NSDictionary *expected = [fresh captureProfileSelectionWithError:NULL];
    CHECK([fresh activateProfile:zero expectedSelection:expected generation:nil error:NULL], "newer activation precedes stale deferred mirror");
    NSUInteger mirrors = gMirrors; __block BOOL flushed = NO;
    dispatch_async(dispatch_get_main_queue(), ^{ flushed = YES; });
    CHECK(Pump(^BOOL { return flushed; }) && [gMirroredID isEqual:@"0"] && mirrors == gMirrors, "stale startup mirror never overwrites newer activation");
    NSDictionary *before = ActiveFiles();
    NSError *metadataError = nil;
    CHECK(![manager updateCurrentProfileInfoWithProfile:manager.mutableCurrentProfile error:&metadataError] && metadataError && [before isEqual:ActiveFiles()],
          "stale metadata update cannot retarget a newer active profile");
    fresh.mutableCurrentProfile = manager.mutableCurrentProfile;
    CHECK([fresh refreshCurrentProfileFromCommittedSelectionWithError:NULL] && [fresh.mutableCurrentProfile.profileId isEqual:@"0"] && [before isEqual:ActiveFiles()],
          "UI memory refresh never writes profile selection");
    CHECK([fresh bootstrapProfileSelectionWithError:NULL] && [before isEqual:ActiveFiles()], "bootstrap preserves an already committed selection");
    NSString *ids0 = Path(Identity(@"0"), @"device_ids.plist"); CHECK(SaveRecord(ids0, @{ @"keep": @YES }), "profile zero identity seeded");
    [fresh createProfileZeroImmediately]; CHECK([Record(ids0)[@"keep"] boolValue], "bootstrap never resets existing profile zero identity");
    NSString *archive = Path(PXProfilesPath(), @"profiles.plist"); NSData *saved = [NSData dataWithContentsOfFile:archive];
    CHECK([[@"invalid archive" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:archive atomically:YES], "corrupt archive injected");
    loaded = NO; ok = YES; [fresh loadProfilesWithCompletion:^(BOOL success, NSError *error) { loaded = YES; ok = success || !error; }];
    CHECK(loaded && !ok && fresh.currentProfile == nil && [before isEqual:ActiveFiles()], "corrupt archive never guesses or rewrites selection");
    CHECK([fresh loadCentralProfileInfo] != nil && fresh.currentProfile == nil, "valid label read never clears a corrupt registry guard");
    __block BOOL mutationRejected = NO;
    [fresh createProfile:New(@"blocked-corrupt-registry") completion:^(BOOL success, NSError *error) { mutationRejected = !success && error.code == 23; }];
    CHECK(mutationRejected && [before isEqual:ActiveFiles()], "restore failure rejects mutation instead of replacing unknown registry");
    CHECK([saved writeToFile:archive atomically:YES], "restart archive restored");
    // Model a missing canonical record with a valid legacy alias.
    BOOL repairedLegacySelection = [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx removeDictionaryAtPath:PXCurrentProfileInfoPath() error:error] &&
            [tx setDictionary:@{ @"currentProfileId": @"0", @"ProfileName": @"zero" } atPath:PXLegacyActiveProfileInfoPath() error:error];
    } error:NULL];
    CHECK(repairedLegacySelection && [fresh bootstrapProfileSelectionWithError:NULL] && [Record(PXCurrentProfileInfoPath())[@"ProfileId"] isEqual:@"0"],
          "bootstrap repairs legacy alias without selecting a different profile");
    (void)manager;
}
int main(void) {
    @autoreleasepool {
        gRoot = Path(NSTemporaryDirectory(), NSUUID.UUID.UUIDString);
        NSFileManager *fm = NSFileManager.defaultManager;
        [fm createDirectoryAtPath:Identity(@"0") withIntermediateDirectories:YES attributes:nil error:NULL];
        gStore = [[PXRuntimeSourceStore alloc] initWithDirectory:Path(gRoot, @"control") owner:geteuid() group:getegid()
            allowsPath:^BOOL(NSString *path) { return [path hasPrefix:[gRoot stringByAppendingString:@"/"]] && [path hasSuffix:@".plist"] && ![path hasPrefix:Path(gRoot, @"control/")]; } error:NULL];
        CHECK(gStore != nil, "profile source store initialized");
        gNetworkOptions = @{ @"enabled": @YES, @"connectionType": @0, @"country": @"us" };
        PXProfileCreationFixture *manager = [PXProfileCreationFixture new]; Profile *zero = New(@"zero"); [zero setValue:@"0" forKey:@"profileId"];
        zero.settings = @{ @"enabled": @YES, @"nested": @[@1, @"value", NSDate.date], @"data": [@"bytes" dataUsingEncoding:NSUTF8StringEncoding] };
        [manager.mutableProfiles addObject:zero]; manager.mutableCurrentProfile = zero;
        CHECK([manager updateCurrentProfileInfoWithProfile:zero error:NULL], "initial selection pair committed");
        [manager saveProfilesWithCompletion:^(BOOL ok, NSError *error) { CHECK(ok && !error, "secure profile archive seeded"); }];
        id observer = [NSNotificationCenter.defaultCenter addObserverForName:@"com.hydra.tlinkios.profileChanged" object:nil queue:nil usingBlock:^(NSNotification *note) {
            (void)note; gNotices++; CHECK(NSThread.isMainThread && [Record(PXCurrentProfileInfoPath())[@"ProfileId"] isEqual:gMemoryID], "profile success notification follows activation on main");
            if (gThrowObserver) [NSException raise:@"fixture" format:@"observer failed after commit"];
        }];
        TestCreation(manager, zero); TestConflicts(manager); TestSelectionFailure(manager, zero); TestBackgroundAndPolicy(manager); TestRestart(manager, zero);
        __block BOOL drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
        CHECK(Pump(^BOOL { return drained; }), "deferred mirror callbacks drained before source teardown");
        [NSNotificationCenter.defaultCenter removeObserver:observer]; gStore = nil;
        [fm removeItemAtPath:gRoot error:NULL];
        printf("Profile creation flow: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
