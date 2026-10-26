#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "ProfileManager.h"
#import "PXRuntimeProfileSelection.h"
#import "PXRuntimeGeneration.h"
#import "PXRuntimeArtifactWriter.h"
#import "PXProfileCreationReservation.h"
#import "PXProfileLifecycleLease.h"
#import "PXProfileDeletionJournal.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <errno.h>
#include <fcntl.h>
#include <spawn.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>
extern char **environ;

static NSUInteger gChecks, gFailures, gNotices, gCanvas, gMirrors, gTerminations, gCachePublications, gSettingsNotices;
static NSString *gRoot, *gRequested, *gMirroredID, *gMemoryID;
static NSDictionary *gPreparedNetwork;
static PXRuntimeSourceStore *gStore;
static NSDictionary *gNetworkOptions;
static _Atomic BOOL gEntered, gCommitted, gInActivation;
static void (^gDuringTermination)(void);
static void (^gAfterGeneration)(void);
static void (^gAfterArchive)(void);
static BOOL gPause, gFailGeneration, gThrowGeneration, gNoIPv4, gThrowObserver, gThrowNetworkOptions;
static dispatch_semaphore_t gRelease;
#define CHECK(value, message) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", message); } } while (0)
static NSString *Path(NSString *root, NSString *name) { return [root stringByAppendingPathComponent:name]; }
NSString *PXProfilesPath(void) { return Path(gRoot, @"profiles"); }
NSString *PXCurrentProfileInfoPath(void) { return Path(PXProfilesPath(), @"current_profile_info.plist"); }
NSString *PXLegacyActiveProfileInfoPath(void) { return Path(gRoot, @"active_profile_info.plist"); }
NSString *PXProfileDeletionJournalPath(void) { return Path(PXProfilesPath(), @".profile-delete-journal.plist"); }
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
@interface PXProfileFileManagerFixture : NSFileManager
@end
@implementation PXProfileFileManagerFixture
- (BOOL)setAttributes:(NSDictionary<NSFileAttributeKey, id> *)attributes ofItemAtPath:(NSString *)path error:(NSError **)error {
    BOOL ok = [super setAttributes:attributes ofItemAtPath:path error:error];
    if ([path isEqual:Path(PXProfilesPath(), @"profiles.plist")]) {
        void (^callback)(void) = gAfterArchive; gAfterArchive = nil;
        if (callback) callback();
    }
    return ok;
}
@end
@interface PXProfileCreationFixture : NSObject
@property (nonatomic, strong) NSMutableArray<Profile *> *mutableProfiles;
@property (nonatomic, strong) Profile *mutableCurrentProfile;
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) NSString *profilesDirectory;
@property (nonatomic) BOOL creationInProgress;
@property (nonatomic, strong) PXProfileCreationReservation *creationReservation;
@property (nonatomic, strong) PXProfileLifecycleLease *lifecycleLease;
@property (nonatomic, copy) NSDictionary *registryRecord;
@property (nonatomic) BOOL deletionRecoveryNoticePending;
@property (nonatomic) BOOL didLoadCommittedProfiles;
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
    if (gThrowNetworkOptions) [NSException raise:@"fixture" format:@"synchronous options capture failed"];
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
// Deliberately bypass the lifecycle lease to model a legacy/external writer.
// Normal ProfileManager selection writers now reject a concurrent lifecycle op.
static BOOL ExternalSelectionWrite(NSDictionary *info) {
    NSMutableDictionary *revisioned = [info mutableCopy]; revisioned[@"SelectionRevision"] = NSUUID.UUID.UUIDString;
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return PXStageRuntimeProfileSelection(tx, revisioned, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), error);
    } error:NULL];
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
    PXProfileCreationFixture *other = [PXProfileCreationFixture new];
    [other loadProfilesWithCompletion:rejected];
    [other createProfile:New(@"other-instance") completion:rejected];
    [manager loadProfilesWithCompletion:rejected];
    NSError *selectionError = nil;
    CHECK(busy == 7 && ![manager persistProfileSelectionInfo:@{ @"ProfileId": @"0" } error:&selectionError] && selectionError.code == 12 &&
          [before isEqual:ActiveFiles()], "pending create excludes other instances reload and raw selection writers");
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
    ResetWorker(); gThrowNetworkOptions = YES; callbacks = 0; before = ActiveFiles();
    [manager createProfile:New(@"options-exception") completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    gThrowNetworkOptions = NO;
    CHECK(callbacks == 1 && !success && failure && !manager.creationInProgress && !manager.lifecycleLease && [before isEqual:ActiveFiles()],
          "synchronous preparation exception releases lifecycle ownership before failure completion");
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
            CHECK(ExternalSelectionWrite(@{ @"ProfileId": @"0" }), "newer selection commits during pending create");
            if (mode == 1) CHECK(ExternalSelectionWrite(old), "ABA returns to same selection with new revision");
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
    gDuringTermination = ^{ ExternalSelectionWrite(@{ @"ProfileId": @"0" }); competitor = ActiveFiles(); };
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
static PXProfileCreationReservation *Reserve(NSString *directory, NSString *profileID, NSError **error) {
    return [PXProfileCreationReservation reserveProfileID:profileID inProfilesDirectory:directory
        metadata:@{ @"DisplayName": @"reserved", @"Identifier": profileID } error:error];
}
static NSUInteger OpenDescriptorCount(void) {
    NSUInteger count = 0;
    for (int fd = 0; fd < 1024; fd++) if (fcntl(fd, F_GETFD) != -1) count++;
    return count;
}
static void TestReservation(NSString *executable) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *root = Path(gRoot, @"reservation-fixtures");
    CHECK([fm createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL], "reservation fixture directory created");
    // Competing processes execute the real production mkdirat path. An exited
    // winner still owns its path; a new process must not reuse an orphan.
    pid_t children[8]; NSUInteger launched = 0;
    for (NSUInteger i = 0; i < 8; i++) {
        char *arguments[] = { (char *)executable.fileSystemRepresentation, "--reserve",
            (char *)root.fileSystemRepresentation, "1", NULL };
        pid_t child = 0;
        int result = posix_spawn(&child, arguments[0], NULL, NULL, arguments, environ);
        CHECK(result == 0, "competing reservation process launched");
        if (!result) children[launched++] = child;
    }
    NSUInteger winners = 0, conflicts = 0;
    for (NSUInteger i = 0; i < launched; i++) {
        int status = 0; pid_t waited;
        do { waited = waitpid(children[i], &status, 0); } while (waited < 0 && errno == EINTR);
        CHECK(waited == children[i] && WIFEXITED(status), "reservation subprocess exits normally");
        if (waited == children[i] && WIFEXITED(status)) {
            if (WEXITSTATUS(status) == 0) winners++;
            if (WEXITSTATUS(status) == 2) conflicts++;
        }
    }
    CHECK(launched == 8 && winners == 1 && conflicts == 7, "exactly one process exclusively reserves the same profile ID");
    NSString *markerPath = Path(Path(root, @"1"), @".creation-owner.plist");
    NSData *markerBefore = [NSData dataWithContentsOfFile:markerPath];
    NSError *error = nil;
    CHECK(!Reserve(root, @"1", &error) && error.code == EEXIST &&
          [markerBefore isEqual:[NSData dataWithContentsOfFile:markerPath]], "exited creator leaves an untouched reservation and restart cannot adopt it");
    CHECK(!Reserve(root, @"../outside", &error), "reservation rejects traversal IDs");
    NSString *file = Path(root, @"2"); CHECK([@"existing" writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:NULL], "preexisting file seeded");
    CHECK(!Reserve(root, @"2", &error) && [[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:NULL] isEqual:@"existing"], "reservation never replaces an existing file");
    CHECK([fm createSymbolicLinkAtPath:Path(root, @"3") withDestinationPath:Path(root, @"1") error:NULL], "symlink fixture seeded");
    CHECK(!Reserve(root, @"3", &error) && [markerBefore isEqual:[NSData dataWithContentsOfFile:markerPath]], "reservation rejects preexisting symlink without touching its destination");
    // Warm up Foundation allocation before measuring descriptor lifetime.
    @autoreleasepool { CHECK(Reserve(root, @"4", NULL) != nil, "reservation lifetime warmup"); }
    NSUInteger descriptors = OpenDescriptorCount();
    for (NSUInteger i = 0; i < 24; i++) {
        @autoreleasepool {
            PXProfileCreationReservation *reservation = Reserve(root, [NSString stringWithFormat:@"life-%lu", (unsigned long)i], NULL);
            CHECK(reservation && [reservation validateWithError:NULL], "new reservation validates held directory and marker descriptors");
            CHECK(!Reserve(root, @"1", NULL), "failed reservation releases its root descriptor");
        }
    }
    CHECK(OpenDescriptorCount() == descriptors, "success and failure reservations close every held descriptor");
    for (NSUInteger mode = 0; mode < 5; mode++) {
        NSString *profileID = [NSString stringWithFormat:@"proof-%lu", (unsigned long)mode];
        PXProfileCreationReservation *reservation = Reserve(root, profileID, NULL);
        CHECK(reservation != nil, "directory proof fixture reserved");
        NSString *profile = Path(root, profileID), *identity = Path(profile, @"identity");
        NSString *marker = Path(profile, @".creation-owner.plist");
        NSString *target = mode == 0 ? identity : mode == 1 ? profile : marker;
        if (mode < 3) {
            NSString *old = [target stringByAppendingString:@".old"];
            CHECK([fm moveItemAtPath:target toPath:old error:NULL] && [fm copyItemAtPath:old toPath:target error:NULL], "replace owned inode while preserving its bytes");
        } else if (mode == 3) {
            NSMutableData *bytes = [[NSData dataWithContentsOfFile:marker] mutableCopy];
            if (bytes.length) ((uint8_t *)bytes.mutableBytes)[0] ^= 1;
            NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:marker];
            [handle writeData:bytes]; [handle closeFile];
        } else {
            CHECK([fm removeItemAtPath:marker error:NULL] && [fm createSymbolicLinkAtPath:marker withDestinationPath:markerPath error:NULL], "replace marker with symlink");
        }
        error = nil;
        CHECK(![reservation validateWithError:&error] && [error.domain isEqual:@"WeaponXProfileDirectoryError"], "directory proof rejects replacement symlink and in-place marker mutation");
    }
    NSString *aliasedRoot = Path(gRoot, @"profiles-alias");
    CHECK([fm createSymbolicLinkAtPath:aliasedRoot withDestinationPath:root error:NULL], "configured profiles root alias created");
    PXProfileCreationReservation *alias = Reserve(aliasedRoot, @"aliased", NULL);
    CHECK(alias && [alias validateWithError:NULL], "configured root aliases remain supported");
    NSString *oldRoot = [root stringByAppendingString:@".old"];
    CHECK([fm moveItemAtPath:root toPath:oldRoot error:NULL] && [fm createDirectoryAtPath:root withIntermediateDirectories:NO attributes:nil error:NULL], "profiles root replaced");
    CHECK(![alias validateWithError:NULL], "directory proof rejects replacement of configured root");
}
static void ReplaceCreationDirectory(Profile *profile, NSUInteger mode) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *directory = Path(PXProfilesPath(), profile.profileId);
    NSString *target = mode == 0 ? Path(directory, @"identity") : mode == 1 ? directory : Path(directory, @".creation-owner.plist");
    NSString *old = [target stringByAppendingString:@".old"];
    if (![fm moveItemAtPath:target toPath:old error:NULL] || ![fm copyItemAtPath:old toPath:target error:NULL])
        [NSException raise:@"fixture" format:@"directory replacement failed"];
}
static void TestCreationDirectoryDrift(PXProfileCreationFixture *manager) {
    for (NSUInteger mode = 0; mode < 4; mode++) {
        ResetWorker(); gPause = NO;
        Profile *candidate = New([NSString stringWithFormat:@"directory-drift-%lu", (unsigned long)mode]);
        __block NSUInteger callbacks = 0; __block BOOL success = YES; __block NSError *failure = nil;
        NSDictionary *before = ActiveFiles(); NSData *archive = [NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")];
        NSUInteger notices = gNotices, caches = gCachePublications, mirrors = gMirrors, terminations = gTerminations;
        if (mode < 3) gAfterGeneration = ^{ ReplaceCreationDirectory(candidate, mode); };
        else gDuringTermination = ^{ ReplaceCreationDirectory(candidate, 0); };
        [manager createProfile:candidate completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
        CHECK(Pump(^BOOL { return callbacks > 0; }) && callbacks == 1 && !success && failure &&
            !manager.creationInProgress && !manager.creationReservation && [before isEqual:ActiveFiles()] &&
            notices == gNotices && caches == gCachePublications && mirrors == gMirrors,
            "replaced creation directory never activates or publishes success");
        if (mode < 3) CHECK(terminations == gTerminations && [archive isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]],
            "ownership loss after generation preserves registry and never invokes termination");
        else CHECK(gTerminations == terminations + 1, "directory change in termination adapter is rechecked before activation");
    }
}
static int TryLeaseInChild(NSString *executable, NSString *directory) {
    char *arguments[] = { (char *)executable.fileSystemRepresentation, "--try-lease", (char *)directory.fileSystemRepresentation, NULL };
    pid_t child = 0;
    if (posix_spawn(&child, arguments[0], NULL, NULL, arguments, environ) != 0) return -1;
    int status = 0; pid_t waited;
    do { waited = waitpid(child, &status, 0); } while (waited < 0 && errno == EINTR);
    return waited == child && WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}
static void TestLifecycleLease(NSString *executable) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *directory = Path(gRoot, @"lifecycle-fixtures");
    CHECK([fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL], "lifecycle fixture root created");
    NSData *first = [@"first registry" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *second = [@"second registry" dataUsingEncoding:NSUTF8StringEncoding];
    @autoreleasepool {
        __attribute__((objc_precise_lifetime)) PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:directory error:NULL];
        CHECK(lease && TryLeaseInChild(executable, directory) == 2, "lifecycle lease excludes another process without waiting");
        NSDictionary *absent = [lease readRegistryWithError:NULL];
        CHECK(![absent[@"exists"] boolValue] && [lease writeRegistryData:first expected:absent error:NULL], "registry CAS captures absence and commits initial bytes");
        NSDictionary *basis = [lease readRegistryWithError:NULL];
        CHECK([lease writeRegistryData:second expected:basis error:NULL] && ![lease writeRegistryData:first expected:basis error:NULL] &&
              [[lease readRegistryWithError:NULL][@"bytes"] isEqual:second], "registry CAS rejects stale bytes without overwriting the newer archive");
    }
    CHECK(TryLeaseInChild(executable, directory) == 0, "releasing lifecycle lease lets another process continue");
    // A dead process cannot strand an in-memory busy flag or a flock owner.
    CHECK(TryLeaseInChild(executable, directory) == 0, "exited process releases lifecycle ownership");
    @autoreleasepool {
        __attribute__((objc_precise_lifetime)) PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:directory error:NULL];
        NSString *archive = Path(directory, @"profiles.plist");
        CHECK([fm removeItemAtPath:archive error:NULL] && [fm createSymbolicLinkAtPath:archive withDestinationPath:Path(directory, @"other") error:NULL], "registry symlink fixture created");
        CHECK([lease readRegistryWithError:NULL] == nil, "registry reader rejects a symlink destination");
        NSString *lock = Path(directory, @".profile-lifecycle.lock");
        CHECK([fm moveItemAtPath:lock toPath:[lock stringByAppendingString:@".old"] error:NULL] &&
              [@"replacement" writeToFile:lock atomically:YES encoding:NSUTF8StringEncoding error:NULL], "lifecycle lock replacement fixture created");
        CHECK(![lease validateWithError:NULL], "lifecycle lease detects replacement of its lock inode");
    }
}
static BOOL Reload(PXProfileCreationFixture *manager) {
    __block BOOL loaded = NO;
    [manager loadProfilesWithCompletion:^(BOOL ok, NSError *error) { loaded = ok && error == nil; }];
    return loaded;
}
@interface PXLegacyDatesArchiverFixture : NSKeyedArchiver
@end
@implementation PXLegacyDatesArchiverFixture
- (void)encodeObject:(id)object forKey:(NSString *)key {
    if ([key isEqual:@"createdAt"] || [key isEqual:@"lastUsed"]) return;
    [super encodeObject:object forKey:key];
}
@end
@interface PXBadProfileNameFixture : Profile
@end
@implementation PXBadProfileNameFixture
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.profileId forKey:@"profileId"];
    [coder encodeObject:@42 forKey:@"name"]; // Wrong secure-decoding field type.
    [coder encodeObject:self.iconName forKey:@"iconName"];
    [coder encodeObject:self.createdAt forKey:@"createdAt"];
    [coder encodeObject:self.lastUsed forKey:@"lastUsed"];
    [coder encodeObject:self.settings forKey:@"settings"];
}
@end
static Profile *SeedRegistered(PXProfileCreationFixture *manager, NSString *name) {
    Profile *profile = New(name); [profile setValue:[manager generateProfileID] forKey:@"profileId"];
    [manager createDirectoryIfNeeded:Identity(profile.profileId)];
    [@"keep until metadata commits" writeToFile:Path(Identity(profile.profileId), @"sentinel") atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [manager.mutableProfiles addObject:profile];
    [manager saveProfilesWithCompletion:^(BOOL ok, NSError *error) { CHECK(ok && !error, "deletion fixture registry seeded"); }];
    return profile;
}
static void Select(PXProfileCreationFixture *manager, Profile *profile) {
    __block BOOL done = NO, success = NO;
    [manager switchToProfile:profile completion:^(BOOL ok, NSError *error) { done = YES; success = ok && error == nil; }];
    CHECK(done && success, "deletion fixture selection committed");
}
static void TestRegistryAndDeletion(void) {
    PXProfileCreationFixture *manager = [PXProfileCreationFixture new]; manager.fileManager = [PXProfileFileManagerFixture new];
    CHECK(Reload(manager), "deletion manager reloads current registry basis");
    PXProfileCreationFixture *stale = [PXProfileCreationFixture new]; CHECK(Reload(stale), "second manager captures old registry basis");
    Profile *inactive = SeedRegistered(manager, @"delete-inactive");
    NSData *currentBytes = [NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")];
    __block BOOL called = NO, success = YES; __block NSError *failure = nil;
    [stale createProfile:New(@"stale-instance") completion:^(BOOL ok, NSError *error) { called = YES; success = ok; failure = error; }];
    CHECK(called && !success && failure.code == 25 && !stale.creationInProgress &&
          [currentBytes isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]], "stale manager cannot overwrite a registry changed by another instance");
    // Match by registered ID, even when the UI passes a different Profile object.
    Profile *alias = New(@"different-object"); [alias setValue:inactive.profileId forKey:@"profileId"];
    NSDictionary *before = ActiveFiles(); NSUInteger terminations = gTerminations;
    called = NO;
    [manager deleteProfile:alias completion:^(BOOL ok, NSError *error) { called = YES; success = ok; failure = error; }];
    CHECK(called && success && !failure && [before isEqual:ActiveFiles()] && ![manager.fileManager fileExistsAtPath:Identity(inactive.profileId)] &&
          gTerminations == terminations && !manager.lifecycleLease, "inactive deletion removes registered ID after metadata commit without changing selection");
    Profile *active = SeedRegistered(manager, @"delete-active"); Select(manager, active);
    NSString *activeID = active.profileId; manager.mutableCurrentProfile = manager.mutableProfiles.firstObject;
    NSUInteger settingsNotices = gSettingsNotices; terminations = gTerminations;
    [manager deleteProfile:active completion:^(BOOL ok, NSError *error) {
        success = ok; failure = error;
        __attribute__((objc_precise_lifetime)) PXProfileLifecycleLease *next = [PXProfileLifecycleLease acquireInDirectory:PXProfilesPath() error:NULL];
        CHECK(!manager.creationInProgress && !manager.lifecycleLease && next, "delete completion runs after releasing lifecycle ownership");
    }];
    NSString *selected = Record(PXCurrentProfileInfoPath())[@"ProfileId"];
    CHECK(success && !failure && ![selected isEqual:activeID] && [Record(PXLegacyActiveProfileInfoPath())[@"ProfileId"] isEqual:selected] &&
          [manager.mutableCurrentProfile.profileId isEqual:selected] && [manager.fileManager fileExistsAtPath:Identity(selected)] &&
          ![manager.fileManager fileExistsAtPath:Identity(activeID)] && settingsNotices + 1 == gSettingsNotices && terminations == gTerminations,
          "active deletion uses committed selection and persists a valid fallback before removing files");
    active = SeedRegistered(manager, @"delete-selection-failure"); Select(manager, active);
    before = ActiveFiles(); currentBytes = [NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")];
    gStore.testCheckpoint = ^(NSString *stage) { if ([stage isEqual:@"source-written"]) [NSException raise:@"fixture" format:@"delete selection failure"]; };
    [manager deleteProfile:active completion:^(BOOL ok, NSError *error) { success = ok; failure = error; }]; gStore.testCheckpoint = nil;
    CHECK(!success && failure && [before isEqual:ActiveFiles()] && [manager.fileManager fileExistsAtPath:Identity(active.profileId)] &&
          [currentBytes isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]], "delete selection failure preserves registry and directory");
    // Encoding is now preparation: it must fail before any selection commit.
    Profile *fallback = manager.mutableProfiles.firstObject;
    NSDictionary *oldSettings = fallback.settings; fallback.settings = @{ @"unsupported": [NSObject new] };
    settingsNotices = gSettingsNotices; before = ActiveFiles();
    [manager deleteProfile:active completion:^(BOOL ok, NSError *error) { success = ok; failure = error; }]; fallback.settings = oldSettings;
    CHECK(!success && failure && [manager.fileManager fileExistsAtPath:Identity(active.profileId)] && [manager.mutableProfiles containsObject:active] &&
          [before isEqual:ActiveFiles()] && settingsNotices == gSettingsNotices && [currentBytes isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]],
          "archive preparation failure preserves selection registry and directory");
    inactive = SeedRegistered(manager, @"delete-external-drift"); NSString *driftID = inactive.profileId;
    gAfterArchive = ^{ if (!ExternalSelectionWrite(@{ @"ProfileId": driftID })) [NSException raise:@"fixture" format:@"delete external drift failed"]; };
    [manager deleteProfile:inactive completion:^(BOOL ok, NSError *error) { success = ok; failure = error; }];
    CHECK(!success && failure && [manager.fileManager fileExistsAtPath:Identity(driftID)] && Reload(manager) &&
          [manager.mutableCurrentProfile.profileId isEqual:driftID], "selection drift after unregister restores only our own registry and preserves all files");
    CHECK(Pump(^BOOL { return [gMemoryID isEqual:driftID]; }), "external drift defaults mirror catches up before the next lifecycle operation");
    Profile *registryDrift = SeedRegistered(manager, @"delete-registry-drift");
    NSData *externalRegistry = [NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")];
    gAfterArchive = ^{ [externalRegistry writeToFile:Path(PXProfilesPath(), @"profiles.plist") atomically:YES]; };
    [manager deleteProfile:registryDrift completion:^(BOOL ok, NSError *error) { success = ok; failure = error; }];
    CHECK(!success && failure.code == 25 && manager.registryUnavailable && [manager.fileManager fileExistsAtPath:Identity(registryDrift.profileId)] &&
          [externalRegistry isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]] && !Reload(manager),
          "registry drift after unregister preserves files and never overwrites an external archive");
    // Resolve the injected external archive explicitly in this fixture; recovery
    // must not invent a decision or overwrite it on its own.
    NSDictionary *pending = Record(PXProfileDeletionJournalPath());
    CHECK([pending[@"registryAfter"][@"bytes"] writeToFile:Path(PXProfilesPath(), @"profiles.plist") atomically:YES] && Reload(manager),
          "known archive restoration permits pending deletion recovery");
    Profile *cloneCurrent = manager.mutableCurrentProfile;
    Profile *replacementTarget = SeedRegistered(manager, @"delete-replaced-target"); NSString *replacementID = replacementTarget.profileId;
    gAfterArchive = ^{
        ReplaceCreationDirectory(replacementTarget, 1);
        [@"replacement" writeToFile:Path(Identity(replacementID), @"new-owner") atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    };
    [manager deleteProfile:replacementTarget completion:^(BOOL ok, NSError *error) { success = ok; failure = error; }];
    CHECK(success && !failure && [manager.fileManager fileExistsAtPath:Path(Identity(replacementID), @"new-owner")] && Reload(manager) &&
          [manager.mutableCurrentProfile.profileId isEqual:cloneCurrent.profileId], "cleanup refuses a replaced target and restart preserves the committed registry");
    BOOL registered = NO;
    for (Profile *profile in manager.mutableProfiles) if ([profile.profileId isEqual:replacementID]) registered = YES;
    CHECK(!registered, "restart never adopts an inactive directory from a reserved marker alone");
    PXProfileCreationFixture *single = [PXProfileCreationFixture new]; [single.mutableProfiles addObject:manager.mutableCurrentProfile];
    [single deleteProfile:manager.mutableCurrentProfile completion:^(BOOL ok, NSError *error) { success = ok; failure = error; }];
    CHECK(!success && failure.code == 4, "last profile deletion is rejected before filesystem mutation");
    NSString *archive = Path(PXProfilesPath(), @"profiles.plist");
    NSData *validArchive = [NSData dataWithContentsOfFile:archive];
    NSData *duplicate = [NSKeyedArchiver archivedDataWithRootObject:@[manager.mutableCurrentProfile, manager.mutableCurrentProfile] requiringSecureCoding:YES error:NULL];
    CHECK([duplicate writeToFile:archive atomically:YES], "duplicate registry fixture installed");
    PXProfileCreationFixture *invalid = [PXProfileCreationFixture new];
    CHECK(!Reload(invalid) && invalid.registryUnavailable && [duplicate isEqual:[NSData dataWithContentsOfFile:archive]], "duplicate registry IDs reject load without guessing or rewriting the archive");
    CHECK([validArchive writeToFile:archive atomically:YES] && Reload(manager), "valid registry restored after duplicate fixture");
    PXBadProfileNameFixture *bad = [[PXBadProfileNameFixture alloc] initWithName:@"bad-name-type" iconName:@"default_profile"];
    [bad setValue:manager.mutableCurrentProfile.profileId forKey:@"profileId"];
    NSData *badData = [NSKeyedArchiver archivedDataWithRootObject:@[bad] requiringSecureCoding:YES error:NULL];
    CHECK([badData writeToFile:archive atomically:YES] && !Reload(manager) && [badData isEqual:[NSData dataWithContentsOfFile:archive]],
          "secure decoder field errors never silently replace invalid profile metadata");
    CHECK([validArchive writeToFile:archive atomically:YES] && Reload(manager), "valid registry restored after field type fixture");
    __block BOOL drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
    CHECK(Pump(^BOOL { return drained; }), "registry and deletion mirrors drained");
}
static int RunDeletionChild(NSString *executable, NSArray<NSString *> *arguments) {
    __attribute__((objc_precise_lifetime)) NSMutableArray *strings = [NSMutableArray arrayWithObject:executable]; [strings addObjectsFromArray:arguments];
    char **values = calloc(strings.count + 1, sizeof(char *));
    if (!values) return -1;
    for (NSUInteger i = 0; i < strings.count; i++) values[i] = (char *)[strings[i] fileSystemRepresentation];
    pid_t child = 0; int result = posix_spawn(&child, values[0], NULL, NULL, values, environ); free(values);
    if (result != 0) return -1;
    int status = 0; pid_t waited;
    do { waited = waitpid(child, &status, 0); } while (waited < 0 && errno == EINTR);
    return waited == child && WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}
static void SetupStore(void) {
    gStore = [[PXRuntimeSourceStore alloc] initWithDirectory:Path(gRoot, @"control") owner:geteuid() group:getegid()
        allowsPath:^BOOL(NSString *path) { return [path hasPrefix:[gRoot stringByAppendingString:@"/"]] && [path hasSuffix:@".plist"] && ![path hasPrefix:Path(gRoot, @"control/")]; } error:NULL];
}
static void TestDeletionRecovery(NSString *executable) {
    PXProfileCreationFixture *manager = [PXProfileCreationFixture new]; CHECK(Reload(manager), "journal manager loads known registry");
    NSString *archive = Path(PXProfilesPath(), @"profiles.plist");
    for (NSString *stage in @[@"prepared", @"committed", @"archive-written", @"settled"]) {
        Profile *target = SeedRegistered(manager, [@"crash-" stringByAppendingString:stage]); Select(manager, target);
        NSDictionary *before = ActiveFiles(); NSData *archiveBefore = [NSData dataWithContentsOfFile:archive];
        NSArray *arguments = @[@"--delete-crash", gRoot, target.profileId, stage];
        CHECK(RunDeletionChild(executable, arguments) == 77, "delete subprocess exits at the requested production checkpoint");
        CHECK([manager.fileManager fileExistsAtPath:Identity(target.profileId)], "crash before cleanup preserves target directory");
        if ([stage isEqual:@"committed"]) {
            CHECK(RunDeletionChild(executable, @[@"--recover-crash", gRoot, @"recovery-archive-written"]) == 77,
                  "recovery subprocess can exit after archive replay before journal cleanup");
        }
        NSUInteger wakeups = gSettingsNotices;
        manager = [PXProfileCreationFixture new]; // Model process memory being lost.
        CHECK(Reload(manager) && ![manager.fileManager fileExistsAtPath:PXProfileDeletionJournalPath()] && !manager.lifecycleLease,
              "restart settles deletion journal and releases lifecycle ownership");
        CHECK(gSettingsNotices == wakeups + 1, "first restart load requests publication after a settled-before-notify exit");
        BOOL found = NO; for (Profile *profile in manager.mutableProfiles) if ([profile.profileId isEqual:target.profileId]) found = YES;
        if ([stage isEqual:@"prepared"]) {
            CHECK(found && [before isEqual:ActiveFiles()] && [archiveBefore isEqual:[NSData dataWithContentsOfFile:archive]],
                  "prepared intent aborts on restart without changing selection registry or files");
        } else {
            CHECK(!found && ![manager.mutableCurrentProfile.profileId isEqual:target.profileId] &&
                  [Record(PXCurrentProfileInfoPath())[@"ProfileId"] isEqual:manager.mutableCurrentProfile.profileId],
                  "committed deletion replays known archive and preserves the committed fallback");
        }
        CHECK([manager.fileManager fileExistsAtPath:Identity(target.profileId)] && Reload(manager),
              "recovery is idempotent and never retries recursive directory removal");
    }
    Profile *target = SeedRegistered(manager, @"recover-external-selection"); Select(manager, target);
    CHECK(RunDeletionChild(executable, @[@"--delete-crash", gRoot, target.profileId, @"archive-written"]) == 77, "selection drift recovery fixture committed");
    CHECK(ExternalSelectionWrite(@{ @"ProfileId": target.profileId }), "external writer reselects target before recovery");
    CHECK(RunDeletionChild(executable, @[@"--recover-crash", gRoot, @"recovery-archive-written"]) == 77,
          "compensation can exit after restoring archive before clearing journal");
    CHECK([Record(PXProfileDeletionJournalPath())[@"state"] isEqual:@"compensating"] && Reload(manager) &&
          [manager.mutableCurrentProfile.profileId isEqual:target.profileId] && [manager.fileManager fileExistsAtPath:Identity(target.profileId)],
          "compensating decision survives restart and never rolls back a newer selection");
    target = SeedRegistered(manager, @"recover-corrupt-intent"); Select(manager, target);
    CHECK(RunDeletionChild(executable, @[@"--delete-crash", gRoot, target.profileId, @"committed"]) == 77, "corrupt intent recovery fixture committed");
    NSDictionary *intent = Record(PXProfileDeletionJournalPath()); NSDictionary *sourceBefore = ActiveFiles();
    NSData *registryBefore = [NSData dataWithContentsOfFile:archive];
    for (NSUInteger mode = 0; mode < 3; mode++) {
        NSMutableDictionary *corrupt = [intent mutableCopy];
        if (mode == 0) corrupt[@"schemaVersion"] = @999;
        else if (mode == 1) corrupt[@"targetID"] = @"../outside";
        else corrupt[@"registryAfter"] = @{ @"exists": @YES, @"bytes": [@"invalid archive" dataUsingEncoding:NSUTF8StringEncoding] };
        CHECK([corrupt writeToFile:PXProfileDeletionJournalPath() atomically:YES], "corrupt journal installed");
        CHECK(!Reload(manager) && manager.registryUnavailable && [sourceBefore isEqual:ActiveFiles()] &&
              [registryBefore isEqual:[NSData dataWithContentsOfFile:archive]] && [manager.fileManager fileExistsAtPath:Identity(target.profileId)],
              "malformed deletion intent never rewrites selection archive or directory");
    }
    CHECK(SaveRecord(PXProfileDeletionJournalPath(), intent), "validated journal restored without losing timestamp precision");
    NSData *unknown = [@"external registry bytes" dataUsingEncoding:NSUTF8StringEncoding]; CHECK([unknown writeToFile:archive atomically:YES], "unknown archive installed");
    CHECK(!Reload(manager) && [unknown isEqual:[NSData dataWithContentsOfFile:archive]] && [manager.fileManager fileExistsAtPath:PXProfileDeletionJournalPath()],
          "unknown registry blocks replay and preserves the deletion journal");
    CHECK([registryBefore writeToFile:archive atomically:YES] && Reload(manager), "known registry permits replay after explicit fixture repair");
    // Legacy archives can omit timestamps; validation must distinguish decoder
    // fallback values from an actual change to persisted timestamp fields.
    Profile *legacyTarget = SeedRegistered(manager, @"legacy-timestamps-delete");
    PXLegacyDatesArchiverFixture *encoder = [[PXLegacyDatesArchiverFixture alloc] initRequiringSecureCoding:YES];
    [encoder encodeObject:manager.mutableProfiles forKey:NSKeyedArchiveRootObjectKey]; [encoder finishEncoding];
    CHECK([encoder.encodedData writeToFile:archive atomically:YES] && Reload(manager), "legacy missing timestamp archive loaded");
    Profile *loadedTarget = nil; for (Profile *profile in manager.mutableProfiles) if ([profile.profileId isEqual:legacyTarget.profileId]) loadedTarget = profile;
    CHECK(loadedTarget.pxDecodedMissingCreatedAt && loadedTarget.pxDecodedMissingLastUsed, "legacy fixture actually omits encoded timestamps");
    __block BOOL deleted = NO;
    [manager deleteProfile:loadedTarget completion:^(BOOL ok, NSError *error) { deleted = ok && error == nil; }];
    CHECK(deleted && Reload(manager), "journal validation preserves legacy timestamp fallback compatibility");
    __block BOOL drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
    CHECK(Pump(^BOOL { return drained; }), "journal recovery mirrors drained before teardown");
}
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if ((argc == 5 && strcmp(argv[1], "--delete-crash") == 0) || (argc == 4 && strcmp(argv[1], "--recover-crash") == 0)) {
            gRoot = [NSString stringWithUTF8String:argv[2]]; SetupStore();
            PXProfileCreationFixture *manager = [PXProfileCreationFixture new];
            NSString *stage = [NSString stringWithUTF8String:argv[argc - 1]];
            if (argc == 4) {
                PXProfileDeletionTestCheckpoint = ^(NSString *value) { OutsideGate(); if ([value isEqual:stage]) _exit(77); };
                return Reload(manager) ? 91 : 92;
            }
            if (!Reload(manager)) return 93;
            NSString *targetID = [NSString stringWithUTF8String:argv[3]]; Profile *target = nil;
            for (Profile *profile in manager.mutableProfiles) if ([profile.profileId isEqual:targetID]) target = profile;
            if (!target) return 94;
            PXProfileDeletionTestCheckpoint = ^(NSString *value) { OutsideGate(); if ([value isEqual:stage]) _exit(77); };
            [manager deleteProfile:target completion:nil];
            return 95;
        }
        if (argc == 3 && strcmp(argv[1], "--try-lease") == 0) {
            NSError *error = nil;
            __attribute__((objc_precise_lifetime)) PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:[NSString stringWithUTF8String:argv[2]] error:&error];
            return lease ? 0 : error.code == 12 ? 2 : 3;
        }
        if (argc == 4 && strcmp(argv[1], "--reserve") == 0) {
            NSError *error = nil;
            PXProfileCreationReservation *reservation = Reserve([NSString stringWithUTF8String:argv[2]], [NSString stringWithUTF8String:argv[3]], &error);
            return reservation ? 0 : error.code == EEXIST ? 2 : 3;
        }
        gRoot = Path(NSTemporaryDirectory(), NSUUID.UUID.UUIDString);
        NSFileManager *fm = NSFileManager.defaultManager;
        [fm createDirectoryAtPath:Identity(@"0") withIntermediateDirectories:YES attributes:nil error:NULL];
        TestReservation([NSString stringWithUTF8String:argv[0]]);
        TestLifecycleLease([NSString stringWithUTF8String:argv[0]]);
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
        TestCreationDirectoryDrift(manager);
        TestRegistryAndDeletion();
        TestDeletionRecovery([NSString stringWithUTF8String:argv[0]]);
        __block BOOL drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
        CHECK(Pump(^BOOL { return drained; }), "deferred mirror callbacks drained before source teardown");
        [NSNotificationCenter.defaultCenter removeObserver:observer]; gStore = nil;
        [fm removeItemAtPath:gRoot error:NULL];
        printf("Profile creation flow: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
