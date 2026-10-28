#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "ProfileManager.h"
#import "PXRuntimeProfileSelection.h"
#import "PXRuntimeGeneration.h"
#import "PXRuntimeArtifactWriter.h"
#import "PXProfileCreationReservation.h"
#import "PXProfileLifecycleLease.h"
#import "PXProfileDeletionJournal.h"
#import "PXProfileMetadataWriter.h"
#import "PXDefaultProfileSeed.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <errno.h>
#include <fcntl.h>
#include <spawn.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>
extern char **environ;

@class PXProfileCreationFixture;
static __weak PXProfileCreationFixture *gNotifyingManager;

static NSUInteger gChecks, gFailures, gNotices, gCanvas, gMirrors, gTerminations, gCachePublications, gSettingsNotices;
static NSString *gRoot, *gRequested, *gMirroredID, *gMemoryAtLastMirrorID;
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
NSString *PXProfileRootPath(NSString *profile) { return PXValidatedProfileID(profile) ? Path(PXProfilesPath(), profile) : nil; }
NSString *PXTLinkIOSSettingsPath(void) { return Path(gRoot, @"settings.plist"); }
NSString *PXGlobalScopePath(void) { return Path(gRoot, @"scope.plist"); }
void PXPostSettingsChangedNotification(void) { gSettingsNotices++; }
static NSDictionary *Record(NSString *path) { return [NSDictionary dictionaryWithContentsOfFile:path] ?: @{}; }
BOOL PXPerformRuntimeSourceWrite(BOOL (^body)(PXRuntimeSourceTransaction *, NSError **), NSError **error) { return [gStore performWrite:body error:error]; }
BOOL PXPerformStandaloneRuntimeSourceWrite(BOOL (^body)(PXRuntimeSourceTransaction *, NSError **), NSError **error) { return [gStore performStandaloneWrite:body error:error]; }
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
- (PXCommittedRuntimeGeneration *)commitRuntimeGenerationForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)artifacts lifecycleLease:(PXProfileLifecycleLease *)lease error:(NSError **)error;
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
- (PXCommittedRuntimeGeneration *)commitRuntimeGenerationForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)artifacts lifecycleLease:(PXProfileLifecycleLease *)lease error:(NSError **)error {
    OutsideGate();
    if (![lease validateForDirectory:PXProfilesPath() error:error]) return nil;
    NSError *busy = nil;
    PXProfileLifecycleLease *competitor = [PXProfileLifecycleLease acquireInDirectory:PXProfilesPath() error:&busy];
    BOOL held = competitor == nil && [busy.domain isEqual:@"WeaponXProfileError"] && busy.code == 12;
    [competitor invalidate];
    if (!held) [NSException raise:@"fixture" format:@"creation did not retain lifecycle ownership on worker"];
    PXCommittedRuntimeGeneration *receipt = [self commitRuntimeGenerationForProfileID:profileID networkArtifacts:artifacts error:error];
    if (![lease validateWithError:NULL]) [NSException raise:@"fixture" format:@"generation invalidated caller lease"];
    return receipt;
}
- (void)publishCommittedRuntimeGeneration:(PXCommittedRuntimeGeneration *)generation {
    gCachePublications++;
    NSString *target = generation.identityDirectory.stringByDeletingLastPathComponent.lastPathComponent;
    CHECK(NSThread.isMainThread && atomic_load(&gCommitted) && [gMemoryAtLastMirrorID isEqual:target] &&
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
    gMirrors++; gMemoryAtLastMirrorID = [self.mutableCurrentProfile.profileId copy]; gMirroredID = [profile copy];
    CHECK([Record(PXCurrentProfileInfoPath())[@"ProfileId"] isEqual:profile] &&
          [Record(PXLegacyActiveProfileInfoPath())[@"ProfileId"] isEqual:profile], "defaults mirror follows committed selection pair");
    OutsideGate();
}
#include "PXProfileFlowMethods.inc"
@end
// Associate each synchronous notification with its actual producer while
// forwarding through the unmodified, extracted production implementation.
@interface PXObservedProfileCreationFixture : PXProfileCreationFixture
@end
@implementation PXObservedProfileCreationFixture
- (void)publishProfileChangedNotification {
    PXProfileCreationFixture *previous = gNotifyingManager;
    gNotifyingManager = self;
    @try { [super publishProfileChangedNotification]; }
    @finally { gNotifyingManager = previous; }
}
@end
static PXProfileCreationFixture *NewManager(void) { return [PXObservedProfileCreationFixture new]; }
static BOOL ProfileNoticeHasCommittedMemory(PXProfileCreationFixture *producer) {
    return NSThread.isMainThread && producer != nil &&
        [Record(PXCurrentProfileInfoPath())[@"ProfileId"] isEqual:producer.mutableCurrentProfile.profileId];
}
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
    PXProfileCreationFixture *other = NewManager();
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
    PXProfileCreationFixture *fresh = NewManager(); __block BOOL loaded = NO, ok = NO;
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
// Model the strict missing-key failure independently of NSKeyedArchiver's
// fixture subclass: the exact production initWithCoder must not request an
// absent optional field, and must not erase a genuine decoder failure.
@interface PXMissingKeyCoderFixture : NSCoder
@property (nonatomic, copy) NSDictionary *values;
@property (nonatomic, strong) NSMutableArray<NSString *> *missingRequests;
@property (nonatomic, strong) NSError *failure;
- (id)lookup:(NSString *)key;
@end
@implementation PXMissingKeyCoderFixture
- (instancetype)init {
    if ((self = [super init])) { _values = @{}; _missingRequests = [NSMutableArray array]; }
    return self;
}
- (BOOL)allowsKeyedCoding { return YES; }
- (BOOL)containsValueForKey:(NSString *)key { return self.values[key] != nil; }
- (NSError *)error { return self.failure; }
- (void)failWithError:(NSError *)error { if (!self.failure) self.failure = error; }
- (id)lookup:(NSString *)key {
    if (self.failure) return nil;
    id value = self.values[key];
    if (!value) {
        [self.missingRequests addObject:key];
        [self failWithError:[NSError errorWithDomain:@"fixture.missing-key" code:1 userInfo:nil]];
    }
    return value == NSNull.null ? nil : value;
}
- (id)decodeObjectOfClass:(Class)class forKey:(NSString *)key { (void)class; return [self lookup:key]; }
- (id)decodeObjectOfClasses:(NSSet<Class> *)classes forKey:(NSString *)key { (void)classes; return [self lookup:key]; }
@end
static void TestOptionalProfileDecoding(void) {
    NSDictionary *settings = @{ @"preserved": @YES };
    PXMissingKeyCoderFixture *coder = [PXMissingKeyCoderFixture new];
    coder.values = @{ @"profileId": @"optional-fixture", @"name": @"optional", @"iconName": @"default_profile", @"settings": settings };
    Profile *profile = [[Profile alloc] initWithCoder:coder];
    CHECK(!coder.error && coder.missingRequests.count == 0 && profile.pxDecodedMissingCreatedAt && profile.pxDecodedMissingLastUsed &&
          [profile.settings isEqual:settings] && profile.shortDescription == nil &&
          [profile.createdAt isKindOfClass:NSDate.class] && [profile.lastUsed isKindOfClass:NSDate.class],
          "absent optional timestamps and description never poison decoder or discard later settings");
    NSMutableDictionary *values = [coder.values mutableCopy]; [values removeObjectForKey:@"settings"];
    coder = [PXMissingKeyCoderFixture new]; coder.values = values; profile = [[Profile alloc] initWithCoder:coder];
    CHECK(!coder.error && coder.missingRequests.count == 0 && profile.settings.count == 0,
          "absent legacy settings uses the existing empty dictionary fallback without decoding a missing key");
    values[@"createdAt"] = NSNull.null; values[@"lastUsed"] = NSNull.null;
    coder = [PXMissingKeyCoderFixture new]; coder.values = values; profile = [[Profile alloc] initWithCoder:coder];
    CHECK(!coder.error && profile.pxDecodedMissingCreatedAt && profile.pxDecodedMissingLastUsed,
          "explicit nil timestamps preserve the existing date fallback");
    values[@"createdAt"] = @42;
    coder = [PXMissingKeyCoderFixture new]; coder.values = values; profile = [[Profile alloc] initWithCoder:coder];
    CHECK(coder.error && [coder.error.domain isEqual:@"WeaponXProfileError"],
          "present invalid timestamp still fails validation instead of using a missing-key fallback");
    [values removeObjectForKey:@"profileId"];
    coder = [PXMissingKeyCoderFixture new]; coder.values = values; profile = [[Profile alloc] initWithCoder:coder];
    CHECK(coder.error && [coder.missingRequests containsObject:@"profileId"], "required profile ID remains a required decode request");
}
@interface PXLegacyDatesProfileFixture : Profile
@end
@implementation PXLegacyDatesProfileFixture
- (Class)classForKeyedArchiver { return Profile.class; }
- (void)encodeWithCoder:(NSCoder *)coder {
    // Use the standard archiver envelope and the production Profile class name;
    // only these two historical fields are intentionally absent from the object.
    [coder encodeObject:self.profileId forKey:@"profileId"];
    [coder encodeObject:self.name forKey:@"name"];
    [coder encodeObject:self.shortDescription forKey:@"shortDescription"];
    [coder encodeObject:self.iconName forKey:@"iconName"];
    [coder encodeObject:self.settings forKey:@"settings"];
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
static NSArray<NSString *> *PXMetadataFixturePaths(NSString *profileID) {
    NSString *root = PXProfileRootPath(profileID);
    return @[Path(root, @"Info.plist"), Path(Path(root, @"appdata"), @"Info.plist"),
        Path(root, @"identifiers.plist"), Path(root, @"scoped-apps.plist")];
}
static NSDictionary *PXCaptureMetadataFixture(NSString *profileID) {
    NSError *captureError = nil;
    NSDictionary *captured = [gStore capture:^NSDictionary *(NSError **error) {
        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        // capture deep-copies through plist serialization. NSNull is not a
        // valid absence marker here; preserve presence separately from bytes,
        // including the distinction between an absent and an empty file.
        for (NSString *path in PXMetadataFixturePaths(profileID)) {
            BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:path];
            NSData *bytes = exists ? [NSData dataWithContentsOfFile:path options:0 error:error] : NSData.data;
            if (!bytes) return nil;
            result[path] = @{ @"exists": @(exists), @"bytes": bytes };
        }
        return result;
    } error:&captureError];
    if (!captured) fprintf(stderr, "Metadata snapshot failed: %s\n", captureError.description.UTF8String ?: "unknown error");
    return captured;
}
static NSUInteger PXMetadataFixtureDescriptorCount(void) {
    NSUInteger count = 0;
    for (int fd = 0; fd < 1024; fd++) if (fcntl(fd, F_GETFD) != -1) count++;
    return count;
}
static void TestProfileMetadataUpdates(void) {
    PXProfileCreationFixture *manager = NewManager(); CHECK(Reload(manager), "metadata manager loads registry basis");
    Profile *previous = SeedRegistered(manager, @"metadata-before");
    Profile *edit = New(@"metadata-after"); [edit setValue:previous.profileId forKey:@"profileId"];
    edit.shortDescription = @"edited description"; edit.createdAt = previous.createdAt; edit.lastUsed = previous.lastUsed;
    NSString *target = edit.profileId, *archivePath = Path(PXProfilesPath(), @"profiles.plist");
    NSString *scopedPath = PXMetadataFixturePaths(target).lastObject;
    NSDictionary *scoped = @{ @"Apps": @[@"fixture.app"], @"keep": @YES };
    CHECK([scoped writeToFile:scopedPath atomically:YES], "metadata scoped extras seeded");
    NSDictionary *before = PXCaptureMetadataFixture(target), *selection = ActiveFiles();
    NSArray *initialPaths = PXMetadataFixturePaths(target);
    CHECK(before && ![before[initialPaths[0]][@"exists"] boolValue] && ![before[initialPaths[1]][@"exists"] boolValue] &&
        ![before[initialPaths[2]][@"exists"] boolValue] && [before[initialPaths[3]][@"exists"] boolValue] &&
        [before[initialPaths[0]][@"bytes"] length] == 0 && [before[initialPaths[3]][@"bytes"] length] > 0 &&
        [NSPropertyListSerialization propertyList:before isValidForFormat:NSPropertyListBinaryFormat_v1_0],
        "metadata absence snapshot is nonnil plist-safe and preserves file presence separately from bytes");
    CHECK([NSData.data writeToFile:initialPaths[0] atomically:YES], "metadata empty file oracle seeded");
    NSDictionary *emptyFile = PXCaptureMetadataFixture(target);
    CHECK(emptyFile && [emptyFile[initialPaths[0]][@"exists"] boolValue] && [emptyFile[initialPaths[0]][@"bytes"] length] == 0 &&
        ![emptyFile isEqual:before], "metadata snapshot distinguishes empty file from absence");
    CHECK([manager.fileManager removeItemAtPath:initialPaths[0] error:NULL] && [before isEqual:PXCaptureMetadataFixture(target)],
        "metadata empty file oracle restores original absence");
    NSData *archiveBefore = [NSData dataWithContentsOfFile:archivePath];
    NSUInteger notices = gNotices, terminations = gTerminations;
    for (NSUInteger failAfter = 1; failAfter <= 4; failAfter++) {
        __block NSUInteger writes = 0, callbacks = 0; __block BOOL success = YES; __block NSError *failure = nil;
        gStore.testCheckpoint = ^(NSString *phase) {
            if ([phase isEqual:@"source-written"] && ++writes == failAfter) [NSException raise:@"fixture.metadata" format:@"partial metadata fault"];
        };
        [manager updateProfile:edit completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
        gStore.testCheckpoint = nil;
        NSDictionary *after = PXCaptureMetadataFixture(target);
        BOOL filesRestored = before && after && [before isEqual:after];
        BOOL archiveRestored = [archiveBefore isEqual:[NSData dataWithContentsOfFile:archivePath]];
        BOOL rollbackOK = callbacks == 1 && writes == failAfter && !success && failure && filesRestored && archiveRestored &&
            manager.mutableProfiles.lastObject == previous && notices == gNotices && !manager.lifecycleLease && !manager.creationInProgress;
        CHECK(rollbackOK, "metadata fault after each file rolls back bytes and absence before registry memory or notification");
        if (!rollbackOK) fprintf(stderr, "Metadata rollback: fault=%lu writes=%lu callbacks=%lu success=%d before=%d after=%d files=%d archive=%d memory=%d notices=%lu/%lu lease=%d busy=%d error=%s\n",
            (unsigned long)failAfter, (unsigned long)writes, (unsigned long)callbacks, success, before != nil, after != nil, filesRestored,
            archiveRestored, manager.mutableProfiles.lastObject == previous, (unsigned long)notices, (unsigned long)gNotices,
            manager.lifecycleLease != nil, manager.creationInProgress, failure.description.UTF8String ?: "nil");
    }
    __block NSUInteger commits = 0, callbacks = 0; __block BOOL success = NO; __block NSError *failure = nil;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"commit-written"]) commits++; };
    [manager updateProfile:edit completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    gStore.testCheckpoint = nil;
    NSArray *paths = PXMetadataFixturePaths(target);
    CHECK(callbacks == 1 && success && !failure && commits == 1 && manager.mutableProfiles.lastObject == edit &&
        [Record(paths[0])[@"Name"] isEqual:edit.name] && [Record(paths[1])[@"ProfileName"] isEqual:edit.name] &&
        [Record(paths[2])[@"DisplayName"] isEqual:edit.name] && [Record(paths[3])[@"ProfileName"] isEqual:edit.name] &&
        [Record(paths[3])[@"Apps"] isEqual:scoped[@"Apps"]] && [Record(paths[3])[@"keep"] boolValue] &&
        notices + 1 == gNotices && [selection isEqual:ActiveFiles()] && terminations == gTerminations,
        "metadata update commits all display files once before registry adoption and preserves scoped extras and selection");
    CHECK([manager.registryRecord[@"bytes"] isEqual:[NSData dataWithContentsOfFile:archivePath]], "metadata registry receipt matches persisted archive");

    // A bypass writer changes the archive between display commit and registry
    // CAS. Report partial failure without adopting the candidate or notifying.
    Profile *later = New(@"metadata-later"); [later setValue:target forKey:@"profileId"];
    archiveBefore = [NSData dataWithContentsOfFile:archivePath]; notices = gNotices; __block NSUInteger writes = 0;
    NSData *drift = [@"unknown bypass archive" dataUsingEncoding:NSUTF8StringEncoding];
    gStore.testCheckpoint = ^(NSString *phase) {
        if ([phase isEqual:@"source-written"] && ++writes == 4) CHECK([drift writeToFile:archivePath atomically:YES], "metadata registry drift installed");
    };
    callbacks = 0; [manager updateProfile:later completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    gStore.testCheckpoint = nil;
    CHECK(callbacks == 1 && !success && failure && manager.mutableProfiles.lastObject == edit && notices == gNotices &&
        [Record(paths[0])[@"Name"] isEqual:later.name] && [drift isEqual:[NSData dataWithContentsOfFile:archivePath]],
        "registry failure after metadata commit reports partial failure without memory adoption or success notification");
    CHECK([archiveBefore writeToFile:archivePath atomically:YES], "metadata registry drift restored");

    NSData *scopedBefore = [NSData dataWithContentsOfFile:scopedPath];
    CHECK([[@"bad scoped root" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:scopedPath atomically:YES], "corrupt metadata source seeded");
    before = PXCaptureMetadataFixture(target); callbacks = 0;
    [manager updateProfile:edit completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    CHECK(callbacks == 1 && !success && failure && [before isEqual:PXCaptureMetadataFixture(target)] && notices == gNotices,
        "corrupt scoped metadata rejects entire edit without silent repair");
    CHECK([scopedBefore writeToFile:scopedPath atomically:YES], "metadata scoped source restored");

    Profile *invalid = New(@"metadata-invalid-archive"); [invalid setValue:target forKey:@"profileId"];
    invalid.settings = @{ @"unsupported": NSObject.new }; before = PXCaptureMetadataFixture(target); callbacks = 0;
    [manager updateProfile:invalid completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    CHECK(callbacks == 1 && !success && failure && [before isEqual:PXCaptureMetadataFixture(target)] &&
        [archiveBefore isEqual:[NSData dataWithContentsOfFile:archivePath]] && notices == gNotices,
        "metadata registry encoding failure stops before any display file write");

    NSString *appDataPath = Path(PXProfileRootPath(target), @"appdata"), *movedAppData = [appDataPath stringByAppendingString:@".held"];
    CHECK([manager.fileManager moveItemAtPath:appDataPath toPath:movedAppData error:NULL] &&
        [manager.fileManager createSymbolicLinkAtPath:appDataPath withDestinationPath:movedAppData error:NULL], "metadata appdata symlink fixture installed");
    NSData *appDataBefore = [NSData dataWithContentsOfFile:Path(movedAppData, @"Info.plist")]; callbacks = 0;
    [manager updateProfile:edit completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    CHECK(callbacks == 1 && !success && failure && [appDataBefore isEqual:[NSData dataWithContentsOfFile:Path(movedAppData, @"Info.plist")]] &&
        [archiveBefore isEqual:[NSData dataWithContentsOfFile:archivePath]], "metadata writer rejects appdata symlink without writing its target or registry");
    CHECK([manager.fileManager removeItemAtPath:appDataPath error:NULL] &&
        [manager.fileManager moveItemAtPath:movedAppData toPath:appDataPath error:NULL], "metadata appdata restored");

    NSString *identity = Identity(target), *heldIdentity = [identity stringByAppendingString:@".held"];
    CHECK([manager.fileManager moveItemAtPath:identity toPath:heldIdentity error:NULL], "metadata legacy root without identity prepared");
    PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:PXProfilesPath() error:NULL];
    NSDictionary *fields = @{ @"Name": edit.name, @"Description": edit.shortDescription, @"CreatedAt": edit.createdAt, @"LastUsed": edit.lastUsed };
    NSError *error = nil; NSUInteger descriptors = PXMetadataFixtureDescriptorCount();
    CHECK(lease && PXWriteProfileDisplayMetadata(lease, target, fields, &error) && !error && [lease validateWithError:NULL] &&
        ![manager.fileManager fileExistsAtPath:identity] && descriptors == PXMetadataFixtureDescriptorCount(),
        "metadata borrowed root supports legacy profile without creating identity or releasing parent lease");
    before = PXCaptureMetadataFixture(target);
    CHECK(![gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        (void)tx; return PXWriteProfileDisplayMetadata(lease, target, fields, writeError);
    } error:&error] && error && [before isEqual:PXCaptureMetadataFixture(target)] && descriptors == PXMetadataFixtureDescriptorCount(),
        "metadata high-level writer cannot acknowledge an uncommitted outer transaction");
    CHECK(!PXWriteProfileDisplayMetadata(lease, @"metadata-missing", fields, &error) && error &&
        ![manager.fileManager fileExistsAtPath:PXProfileRootPath(@"metadata-missing")] && descriptors == PXMetadataFixtureDescriptorCount(),
        "metadata writer rejects missing root without recreating it or leaking descriptors");
    [lease invalidate];
    CHECK(!PXWriteProfileDisplayMetadata(lease, target, fields, &error) && error, "metadata writer rejects expired caller lease");
    CHECK([manager.fileManager moveItemAtPath:heldIdentity toPath:identity error:NULL], "metadata identity fixture restored");
}

static NSDictionary *PXCaptureDefaultSeedFixture(void) {
    return [gStore capture:^NSDictionary *(NSError **error) {
        NSMutableDictionary *files = [NSMutableDictionary dictionary];
        NSArray *paths = @[Path(PXProfileRootPath(@"0"), @"identifiers.plist"), Path(Identity(@"0"), @"device_ids.plist")];
        for (NSString *path in paths) {
            BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:path];
            NSData *bytes = exists ? [NSData dataWithContentsOfFile:path options:0 error:error] : NSData.data;
            if (!bytes) return nil;
            files[path] = @{ @"exists": @(exists), @"bytes": bytes };
        }
        return files;
    } error:NULL];
}
@interface PXDefaultSeedControlFixture : PXProfileCreationFixture
@property (nonatomic) NSUInteger seedBootstrapCalls;
@property (nonatomic) NSUInteger seedLoadCalls;
@end
@implementation PXDefaultSeedControlFixture
- (BOOL)bootstrapProfileSelectionWithError:(NSError **)error { self.seedBootstrapCalls++; return [super bootstrapProfileSelectionWithError:error]; }
- (void)loadProfilesWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion { self.seedLoadCalls++; [super loadProfilesWithCompletion:completion]; }
@end
static void TestDefaultProfileSeeding(void) {
    PXProfileCreationFixture *manager = NewManager(); NSFileManager *fm = manager.fileManager;
    NSString *profile = PXProfileRootPath(@"0"), *identity = Identity(@"0");
    NSString *display = Path(profile, @"identifiers.plist"), *ids = Path(identity, @"device_ids.plist");
    NSDictionary *selection = ActiveFiles(); NSData *archive = [NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")];
    NSData *idsBefore = [NSData dataWithContentsOfFile:ids];
    NSUInteger notices = gNotices, mirrors = gMirrors, settingsNotices = gSettingsNotices, terminations = gTerminations;
    __block NSUInteger commits = 0; NSError *error = nil;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"commit-written"]) commits++; };
    CHECK([manager createProfileZeroWithError:&error] && !error && commits == 1 && [idsBefore isEqual:[NSData dataWithContentsOfFile:ids]] &&
        [Record(display)[@"DisplayName"] isEqual:@"Default"] && [Record(display)[@"Description"] isEqual:@"Default Profile"] &&
        [Record(display)[@"Identifier"] isEqual:@"0"], "default seed commits display while preserving existing identity bytes");
    gStore.testCheckpoint = nil;
    NSUInteger baselineDescriptors = PXMetadataFixtureDescriptorCount();
    NSData *savedDisplay = [NSData dataWithContentsOfFile:display], *savedIDs = [NSData dataWithContentsOfFile:ids];
    CHECK([fm removeItemAtPath:display error:NULL] && [fm removeItemAtPath:ids error:NULL], "default seed absence fixture prepared");
    NSDictionary *before = PXCaptureDefaultSeedFixture();
    CHECK(before != nil && ![before[display][@"exists"] boolValue] && ![before[ids][@"exists"] boolValue],
        "default seed absence oracle is plist-safe and nonnil");
    for (NSUInteger failAfter = 1; failAfter <= 2; failAfter++) {
        __block NSUInteger writes = 0;
        gStore.testCheckpoint = ^(NSString *phase) {
            if ([phase isEqual:@"source-written"] && ++writes == failAfter) [NSException raise:@"fixture.seed" format:@"default seed partial fault"];
        };
        BOOL success = [manager createProfileZeroWithError:&error]; gStore.testCheckpoint = nil;
        CHECK(!success && error && writes == failAfter && [before isEqual:PXCaptureDefaultSeedFixture()],
            "default seed failure after each file restores paired original absence");
    }
    CHECK([manager createProfileZeroWithError:&error] && !error && [NSDictionary dictionaryWithContentsOfFile:ids] != nil && Record(ids).count == 0 &&
        [Record(display)[@"Identifier"] isEqual:@"0"], "default seed creates empty identity only when missing");
    CHECK([savedIDs writeToFile:ids atomically:YES] && [savedDisplay writeToFile:display atomically:YES], "default seed originals restored");

    NSData *corrupt = [@"corrupt seed source" dataUsingEncoding:NSUTF8StringEncoding];
    for (NSString *path in @[display, ids]) {
        NSData *original = [NSData dataWithContentsOfFile:path]; CHECK([corrupt writeToFile:path atomically:YES], "corrupt default seed source installed");
        before = PXCaptureDefaultSeedFixture();
        CHECK(![manager createProfileZeroWithError:&error] && error && [before isEqual:PXCaptureDefaultSeedFixture()],
            "default seed rejects corrupt display or identity without partial repair");
        CHECK([original writeToFile:path atomically:YES], "corrupt default seed source restored");
    }
    PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:PXProfilesPath() error:NULL];
    before = PXCaptureDefaultSeedFixture(); NSUInteger descriptors = PXMetadataFixtureDescriptorCount();
    CHECK(lease && ![manager createProfileZeroWithError:&error] && error.code == 12 && [lease validateWithError:NULL] &&
        [before isEqual:PXCaptureDefaultSeedFixture()] && descriptors == PXMetadataFixtureDescriptorCount(),
        "busy default seed rejects before namespace or source effects and releases failed acquire descriptors");
    CHECK(PXSeedDefaultProfile(lease, &error) && !error && [lease validateWithError:NULL] && descriptors == PXMetadataFixtureDescriptorCount(),
        "default seed borrowed lifecycle remains owned and closes every helper descriptor");
    [lease invalidate]; before = PXCaptureDefaultSeedFixture();
    CHECK(!PXSeedDefaultProfile(lease, &error) && error && [before isEqual:PXCaptureDefaultSeedFixture()], "default seed rejects expired lifecycle capability");

    CHECK(SaveRecord(PXProfileDeletionJournalPath(), @{ @"fixture": @YES }), "default seed pending deletion installed"); before = PXCaptureDefaultSeedFixture();
    CHECK(![manager createProfileZeroWithError:&error] && error && [before isEqual:PXCaptureDefaultSeedFixture()],
        "default seed pending deletion rejects before changing either source file");
    PXDefaultSeedControlFixture *control = [PXDefaultSeedControlFixture new]; [control createProfileZero];
    CHECK(control.seedBootstrapCalls == 0 && control.seedLoadCalls == 0, "explicit default create stops before bootstrap or reload when seed fails");
    CHECK([gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return [tx removeDictionaryAtPath:PXProfileDeletionJournalPath() error:writeError];
    } error:NULL], "default seed pending deletion cleared");

    NSString *heldIdentity = [identity stringByAppendingString:@".seed-held"];
    CHECK([fm moveItemAtPath:identity toPath:heldIdentity error:NULL] && [fm createSymbolicLinkAtPath:identity withDestinationPath:heldIdentity error:NULL],
        "default seed identity symlink prepared");
    before = PXCaptureDefaultSeedFixture();
    CHECK(![manager createProfileZeroWithError:&error] && error && [before isEqual:PXCaptureDefaultSeedFixture()],
        "default seed rejects identity symlink without changing its target");
    CHECK([fm removeItemAtPath:identity error:NULL] && [fm moveItemAtPath:heldIdentity toPath:identity error:NULL], "default seed identity restored");
    NSString *heldProfile = [profile stringByAppendingString:@".seed-held"];
    CHECK([fm moveItemAtPath:profile toPath:heldProfile error:NULL] && [fm createSymbolicLinkAtPath:profile withDestinationPath:heldProfile error:NULL],
        "default seed profile symlink prepared");
    before = PXCaptureDefaultSeedFixture();
    CHECK(![manager createProfileZeroWithError:&error] && error && [before isEqual:PXCaptureDefaultSeedFixture()],
        "default seed rejects profile symlink without changing its target");
    CHECK([fm removeItemAtPath:profile error:NULL] && [fm moveItemAtPath:heldProfile toPath:profile error:NULL], "default seed profile restored");

    CHECK([fm moveItemAtPath:profile toPath:heldProfile error:NULL], "default seed missing root prepared");
    CHECK([manager createProfileZeroWithError:&error] && !error && [fm fileExistsAtPath:identity] &&
        [NSDictionary dictionaryWithContentsOfFile:ids] != nil && Record(ids).count == 0 &&
        [Record(display)[@"Identifier"] isEqual:@"0"] && ![fm fileExistsAtPath:Path(profile, @"appdata")] &&
        ![fm fileExistsAtPath:Path(profile, @"scoped-apps.plist")], "default seed creates only legacy directories and source files for missing zero");
    CHECK([fm removeItemAtPath:profile error:NULL] && [fm moveItemAtPath:heldProfile toPath:profile error:NULL], "default seed original root restored");
    CHECK([selection isEqual:ActiveFiles()] && [archive isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]] &&
        notices == gNotices && mirrors == gMirrors && settingsNotices == gSettingsNotices && terminations == gTerminations,
        "default seed never changes selection registry memory notifications or app termination policy");
    CHECK(manager.mutableProfiles.count == 0 && manager.mutableCurrentProfile == nil && baselineDescriptors == PXMetadataFixtureDescriptorCount(),
        "default seed leaves manager slots unchanged and closes descriptors on every tested return");
}

static void TestRegistryAndDeletion(void) {
    PXProfileCreationFixture *manager = NewManager(); manager.fileManager = [PXProfileFileManagerFixture new];
    CHECK(Reload(manager), "deletion manager reloads current registry basis");
    PXProfileCreationFixture *stale = NewManager(); CHECK(Reload(stale), "second manager captures old registry basis");
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
    CHECK(Pump(^BOOL { return [gMemoryAtLastMirrorID isEqual:driftID]; }), "external drift defaults mirror catches up before the next lifecycle operation");
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
    PXProfileCreationFixture *single = NewManager(); [single.mutableProfiles addObject:manager.mutableCurrentProfile];
    [single deleteProfile:manager.mutableCurrentProfile completion:^(BOOL ok, NSError *error) { success = ok; failure = error; }];
    CHECK(!success && failure.code == 4, "last profile deletion is rejected before filesystem mutation");
    NSString *archive = Path(PXProfilesPath(), @"profiles.plist");
    NSData *validArchive = [NSData dataWithContentsOfFile:archive];
    NSData *duplicate = [NSKeyedArchiver archivedDataWithRootObject:@[manager.mutableCurrentProfile, manager.mutableCurrentProfile] requiringSecureCoding:YES error:NULL];
    CHECK([duplicate writeToFile:archive atomically:YES], "duplicate registry fixture installed");
    PXProfileCreationFixture *invalid = NewManager();
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
    PXProfileCreationFixture *manager = NewManager(); CHECK(Reload(manager), "journal manager loads known registry");
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
        manager = NewManager(); // Model process memory being lost.
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
    NSMutableArray *legacyProfiles = [NSMutableArray array];
    for (Profile *profile in manager.mutableProfiles)
        [legacyProfiles addObject:[[PXLegacyDatesProfileFixture alloc] initWithDictionary:profile.toDictionary]];
    NSError *legacyEncodeError = nil;
    NSData *legacyData = [NSKeyedArchiver archivedDataWithRootObject:legacyProfiles requiringSecureCoding:YES error:&legacyEncodeError];
    BOOL legacyWritten = legacyData && [legacyData writeToFile:archive atomically:YES];
    __block BOOL legacyLoaded = NO; __block NSError *legacyError = nil;
    gMirroredID = @"legacy-pending-defaults";
    gMemoryAtLastMirrorID = @"legacy-last-mirror-memory";
    if (legacyWritten) [manager loadProfilesWithCompletion:^(BOOL ok, NSError *error) { legacyLoaded = ok; legacyError = error; }];
    CHECK(legacyWritten && legacyLoaded, "legacy missing timestamp archive loaded");
    if (!legacyWritten || !legacyLoaded) fprintf(stderr, "Legacy timestamp fixture: encoded=%lu bytes, write=%d, encodeError=%s, loadError=%s\n",
        (unsigned long)legacyData.length, legacyWritten, legacyEncodeError.description.UTF8String ?: "none", legacyError.description.UTF8String ?: "none");
    Profile *loadedTarget = nil; for (Profile *profile in manager.mutableProfiles) if ([profile.profileId isEqual:legacyTarget.profileId]) loadedTarget = profile;
    CHECK([loadedTarget isMemberOfClass:Profile.class] && loadedTarget.pxDecodedMissingCreatedAt && loadedTarget.pxDecodedMissingLastUsed, "legacy fixture actually omits encoded timestamps");
    PXProfileCreationFixture *wrongProducer = NewManager();
    Profile *wrongMemory = New(@"stale-notification-memory"); [wrongMemory setValue:@"stale-notification-id" forKey:@"profileId"];
    wrongProducer.mutableCurrentProfile = wrongMemory;
    CHECK(!ProfileNoticeHasCommittedMemory(wrongProducer) && ProfileNoticeHasCommittedMemory(manager),
          "notification oracle rejects stale producer memory and accepts committed memory independently of mirror samples");
    CHECK([manager.mutableCurrentProfile.profileId isEqual:Record(PXCurrentProfileInfoPath())[@"ProfileId"]] &&
          ![loadedTarget.profileId isEqual:manager.mutableCurrentProfile.profileId] &&
          [gMirroredID isEqual:@"legacy-pending-defaults"] && [gMemoryAtLastMirrorID isEqual:@"legacy-last-mirror-memory"],
          "legacy reload adopts committed memory while the defaults mirror is still queued");
    NSUInteger noticesBeforeDelete = gNotices;
    __block BOOL deleted = NO;
    [manager deleteProfile:loadedTarget completion:^(BOOL ok, NSError *error) { deleted = ok && error == nil; }];
    CHECK(deleted, "journal validation preserves legacy timestamp fallback compatibility");
    CHECK(deleted && gNotices == noticesBeforeDelete + 1 && [gMirroredID isEqual:@"legacy-pending-defaults"] &&
          [gMemoryAtLastMirrorID isEqual:@"legacy-last-mirror-memory"],
          "inactive deletion notifies committed producer memory before deferred defaults mirroring");
    CHECK(Reload(manager), "registry remains loadable after legacy inactive deletion");
    __block BOOL drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
    CHECK(Pump(^BOOL { return drained; }), "journal recovery mirrors drained before teardown");
    CHECK([gMirroredID isEqual:manager.mutableCurrentProfile.profileId],
          "queued defaults mirror eventually adopts the committed profile after inactive deletion");
}
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if ((argc == 5 && strcmp(argv[1], "--delete-crash") == 0) || (argc == 4 && strcmp(argv[1], "--recover-crash") == 0)) {
            gRoot = [NSString stringWithUTF8String:argv[2]]; SetupStore();
            PXProfileCreationFixture *manager = NewManager();
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
        TestOptionalProfileDecoding();
        NSFileManager *fm = NSFileManager.defaultManager;
        [fm createDirectoryAtPath:Identity(@"0") withIntermediateDirectories:YES attributes:nil error:NULL];
        TestReservation([NSString stringWithUTF8String:argv[0]]);
        TestLifecycleLease([NSString stringWithUTF8String:argv[0]]);
        gStore = [[PXRuntimeSourceStore alloc] initWithDirectory:Path(gRoot, @"control") owner:geteuid() group:getegid()
            allowsPath:^BOOL(NSString *path) { return [path hasPrefix:[gRoot stringByAppendingString:@"/"]] && [path hasSuffix:@".plist"] && ![path hasPrefix:Path(gRoot, @"control/")]; } error:NULL];
        CHECK(gStore != nil, "profile source store initialized");
        gNetworkOptions = @{ @"enabled": @YES, @"connectionType": @0, @"country": @"us" };
        PXProfileCreationFixture *manager = NewManager(); Profile *zero = New(@"zero"); [zero setValue:@"0" forKey:@"profileId"];
        zero.settings = @{ @"enabled": @YES, @"nested": @[@1, @"value", NSDate.date], @"data": [@"bytes" dataUsingEncoding:NSUTF8StringEncoding] };
        [manager.mutableProfiles addObject:zero]; manager.mutableCurrentProfile = zero;
        CHECK([manager updateCurrentProfileInfoWithProfile:zero error:NULL], "initial selection pair committed");
        [manager saveProfilesWithCompletion:^(BOOL ok, NSError *error) { CHECK(ok && !error, "secure profile archive seeded"); }];
        id observer = [NSNotificationCenter.defaultCenter addObserverForName:@"com.hydra.tlinkios.profileChanged" object:nil queue:nil usingBlock:^(NSNotification *note) {
            (void)note; gNotices++;
            NSString *committedID = Record(PXCurrentProfileInfoPath())[@"ProfileId"];
            NSString *memoryID = gNotifyingManager.mutableCurrentProfile.profileId;
            BOOL ordered = ProfileNoticeHasCommittedMemory(gNotifyingManager);
            CHECK(ordered, "profile success notification follows activation on main");
            if (!ordered) fprintf(stderr, "Profile notification: source=%s, producerMemory=%s, lastDefaults=%s, lastMirrorMemory=%s\n",
                committedID.UTF8String ?: "nil", memoryID.UTF8String ?: "nil", gMirroredID.UTF8String ?: "nil", gMemoryAtLastMirrorID.UTF8String ?: "nil");
            if (gThrowObserver) [NSException raise:@"fixture" format:@"observer failed after commit"];
        }];
        TestCreation(manager, zero); TestConflicts(manager); TestSelectionFailure(manager, zero); TestBackgroundAndPolicy(manager); TestRestart(manager, zero);
        TestCreationDirectoryDrift(manager);
        TestProfileMetadataUpdates(); TestDefaultProfileSeeding(); TestRegistryAndDeletion();
        TestDeletionRecovery([NSString stringWithUTF8String:argv[0]]);
        __block BOOL drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
        CHECK(Pump(^BOOL { return drained; }), "deferred mirror callbacks drained before source teardown");
        [NSNotificationCenter.defaultCenter removeObserver:observer]; gStore = nil;
        [fm removeItemAtPath:gRoot error:NULL];
        printf("Profile creation flow: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
