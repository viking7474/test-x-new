#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "../AppDataBackupManager.h"
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
static PXProfileCreationFixture *gControllerManager;

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
+ (instancetype)sharedManager;
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
+ (instancetype)sharedManager { return gControllerManager; }
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
static Profile *PXFindFixtureProfile(NSArray<Profile *> *profiles, NSString *profileID) {
    for (Profile *profile in profiles) if ([profile.profileId isEqual:profileID]) return profile;
    return nil;
}
static void TestCreationOwnedModel(PXProfileCreationFixture *manager) {
    ResetWorker();
    NSMutableString *name = [@"owned-input" mutableCopy], *description = [@"description-before" mutableCopy], *icon = [@"icon-before" mutableCopy];
    NSMutableArray *steps = [NSMutableArray arrayWithObject:@"step-before"];
    NSMutableDictionary *nested = [@{ @"steps": steps } mutableCopy];
    NSMutableData *blob = [[@"bytes-before" dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    Profile *child = New(@"child-before");
    Profile *input = [[Profile alloc] initWithName:name shortDescription:description iconName:icon];
    input.settings = @{ @"nested": nested, @"blob": blob, @"child": child };
    __block NSUInteger callbacks = 0; __block BOOL success = NO; __block NSError *failure = nil;
    [manager createProfile:input completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    NSString *acceptedID = [input.profileId copy]; NSDate *acceptedCreated = input.createdAt, *acceptedUsed = input.lastUsed;
    CHECK(Pump(^BOOL { return atomic_load(&gEntered); }), "owned creation worker pauses after model admission");
    [name setString:@"caller-renamed"]; [description setString:@"caller-description"]; [icon setString:@"caller-icon"];
    [steps addObject:@"later-step"]; nested[@"late"] = @YES; [blob appendData:[@"later" dataUsingEncoding:NSUTF8StringEncoding]];
    child.name = @"caller-child"; input.settings = @{ @"replacement": @YES };
    input.createdAt = [NSDate dateWithTimeIntervalSince1970:1]; input.lastUsed = [NSDate dateWithTimeIntervalSince1970:2];
    [input setValue:@"caller-retarget" forKey:@"profileId"];
    dispatch_semaphore_signal(gRelease);
    CHECK(Pump(^BOOL { return callbacks > 0; }) && callbacks == 1 && success && !failure && !manager.creationInProgress && !manager.lifecycleLease,
        "owned creation completes once despite later caller model mutation");
    Profile *owned = manager.mutableCurrentProfile, *ownedChild = owned.settings[@"child"];
    NSData *expectedBytes = [@"bytes-before" dataUsingEncoding:NSUTF8StringEncoding];
    CHECK(owned != input && [owned.profileId isEqual:acceptedID] && [owned.name isEqual:@"owned-input"] &&
        [owned.shortDescription isEqual:@"description-before"] && [owned.iconName isEqual:@"icon-before"] &&
        [owned.createdAt isEqual:acceptedCreated] && [owned.lastUsed isEqual:acceptedUsed] &&
        [owned.settings[@"nested"][@"steps"] count] == 1 && !owned.settings[@"nested"][@"late"] &&
        [owned.settings[@"blob"] isEqual:expectedBytes] && ownedChild != child && [ownedChild.name isEqual:@"child-before"],
        "creation owns a deep secure snapshot including nested mutable settings and allowed Profile values");
    NSError *decodeError = nil;
    Profile *archived = PXFindFixtureProfile([manager decodeRegistryRecord:manager.registryRecord error:&decodeError], acceptedID);
    CHECK(archived && !decodeError && [archived.name isEqual:owned.name] && [archived.settings[@"blob"] isEqual:expectedBytes] &&
        [Record(Path(PXProfileRootPath(acceptedID), @"identifiers.plist"))[@"DisplayName"] isEqual:owned.name] &&
        [Record(PXCurrentProfileInfoPath())[@"ProfileName"] isEqual:owned.name] && [gRequested isEqual:acceptedID] &&
        [input.profileId isEqual:@"caller-retarget"] && [input.name isEqual:@"caller-renamed"],
        "creation display registry selection and generation agree without overwriting later caller edits");

    Profile *alias = New(@"alias-untrusted-name"); [alias setValue:acceptedID forKey:@"profileId"];
    alias.settings = @{ @"alias-only": @YES }; alias.lastUsed = [NSDate dateWithTimeIntervalSince1970:123];
    NSDate *aliasUsed = alias.lastUsed; NSUInteger terminations = gTerminations; callbacks = 0;
    [manager switchToProfile:alias completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    archived = PXFindFixtureProfile([manager decodeRegistryRecord:manager.registryRecord error:&decodeError], acceptedID);
    CHECK(callbacks == 1 && success && !failure && manager.mutableCurrentProfile == owned && [owned.name isEqual:@"owned-input"] &&
        [archived.lastUsed isEqual:owned.lastUsed] && ![owned.lastUsed isEqual:aliasUsed] && [alias.lastUsed isEqual:aliasUsed] &&
        !owned.settings[@"alias-only"] && terminations == gTerminations,
        "switch resolves registered model by ID and persists canonical lastUsed without adopting alias fields");
    NSDictionary *before = ActiveFiles(); NSData *archiveBefore = [NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")];
    [alias setValue:@"unregistered-alias" forKey:@"profileId"]; callbacks = 0;
    [manager switchToProfile:alias completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    CHECK(callbacks == 1 && !success && failure.code == 21 && [before isEqual:ActiveFiles()] &&
        [archiveBefore isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]], "unregistered switch alias has no persistence effects");

    ResetWorker(); callbacks = 0; __weak Profile *weakInput; NSString *temporaryID;
    @autoreleasepool {
        Profile *temporary = New(@"owned-lifetime"); weakInput = temporary;
        [manager createProfile:temporary completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
        temporaryID = [temporary.profileId copy];
    }
    CHECK(Pump(^BOOL { return atomic_load(&gEntered); }) && !weakInput, "queued creation does not retain the caller input model");
    dispatch_semaphore_signal(gRelease);
    CHECK(Pump(^BOOL { return callbacks > 0; }) && callbacks == 1 && success && !failure &&
        [manager.mutableCurrentProfile.profileId isEqual:temporaryID] && [manager.mutableCurrentProfile.name isEqual:@"owned-lifetime"],
        "owned creation survives caller model deallocation");

    ResetWorker(); Profile *invalid = New(@"uncapturable-input"); invalid.settings = @{ @"unsupported": NSObject.new };
    before = ActiveFiles(); archiveBefore = [NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")];
    NSUInteger count = manager.mutableProfiles.count, notices = gNotices, mirrors = gMirrors, caches = gCachePublications;
    callbacks = 0;
    [manager createProfile:invalid completion:^(BOOL ok, NSError *error) {
        callbacks++; success = ok; failure = error;
        PXProfileLifecycleLease *available = [PXProfileLifecycleLease acquireInDirectory:PXProfilesPath() error:NULL];
        CHECK(available && !manager.creationInProgress && !manager.lifecycleLease, "failed creation capture releases ownership before completion"); [available invalidate];
    }];
    CHECK(callbacks == 1 && !success && failure && !atomic_load(&gEntered) && manager.mutableProfiles.count == count &&
        ![manager.fileManager fileExistsAtPath:PXProfileRootPath(invalid.profileId)] && [before isEqual:ActiveFiles()] &&
        [archiveBefore isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]] &&
        notices == gNotices && mirrors == gMirrors && caches == gCachePublications,
        "uncapturable creation input fails before reservation providers registry or publication");
}

static void TestNestedProfileArchiveValidation(PXProfileCreationFixture *manager) {
    Profile *retained = New(@"nested-retained"), *removed = New(@"nested-removed"), *child = New(@"nested-child");
    [retained setValue:@"nested-retained" forKey:@"profileId"]; [removed setValue:@"nested-removed" forKey:@"profileId"];
    retained.settings = @{ @"nested": @{ @"children": @[child] }, @"bytes": [@"value" dataUsingEncoding:NSUTF8StringEncoding] };
    NSArray *beforeModels = @[retained, removed], *afterModels = @[retained]; NSError *error = nil;
    NSData *beforeBytes = [NSKeyedArchiver archivedDataWithRootObject:beforeModels requiringSecureCoding:YES error:&error];
    NSData *afterBytes = [NSKeyedArchiver archivedDataWithRootObject:afterModels requiringSecureCoding:YES error:&error];
    NSDictionary *selected = @{ @"exists": @YES, @"info": @{ @"ProfileId": retained.profileId } };
    NSDictionary *pair = @{ PXCurrentProfileInfoPath(): selected, PXLegacyActiveProfileInfoPath(): selected };
    NSDictionary *beforeRecord = @{ @"exists": @YES, @"bytes": beforeBytes ?: NSData.data };
    NSDictionary *afterRecord = @{ @"exists": @YES, @"bytes": afterBytes ?: NSData.data };
    NSMutableDictionary *intent = [@{ @"registryBefore": beforeRecord, @"registryAfter": afterRecord,
        @"targetID": removed.profileId, @"selectionAfter": pair } mutableCopy];
    CHECK(beforeBytes && afterBytes && !error && [manager validateDeletionArchives:intent error:&error] && !error,
        "deletion archive validation preserves equal nested Profile values across separate decodes");
    for (NSUInteger field = 0; field < 7; field++) {
        Profile *changed = [manager detachedProfileForCreation:retained expectedID:retained.profileId error:NULL];
        Profile *changedChild = [changed.settings[@"nested"][@"children"] firstObject];
        if (field == 0) [changedChild setValue:@"different-child-id" forKey:@"profileId"];
        else if (field == 1) changedChild.name = @"changed child";
        else if (field == 2) changedChild.shortDescription = @"changed description";
        else if (field == 3) changedChild.iconName = @"changed icon";
        else if (field == 4) changedChild.createdAt = [changedChild.createdAt dateByAddingTimeInterval:10];
        else if (field == 5) changedChild.lastUsed = [changedChild.lastUsed dateByAddingTimeInterval:10];
        else changedChild.settings = @{ @"changed": @YES };
        NSArray *changedModels = changed ? @[changed] : @[];
        NSData *changedBytes = [NSKeyedArchiver archivedDataWithRootObject:changedModels requiringSecureCoding:YES error:NULL];
        intent[@"registryAfter"] = @{ @"exists": @YES, @"bytes": changedBytes ?: NSData.data }; error = nil;
        CHECK(changed && changedChild && changedBytes && ![manager validateDeletionArchives:intent error:&error] && error.code == 27,
            "deletion archive validation rejects changes to every nested Profile identity metadata date or settings field");
    }
    intent[@"registryAfter"] = afterRecord; error = nil;
    CHECK([manager validateDeletionArchives:intent error:&error] && !error && [intent[@"registryBefore"] isEqual:beforeRecord],
        "nested archive comparison has no persistent memo state and preserves original before bytes");
    NSMutableArray *left = [NSMutableArray array], *right = [NSMutableArray array];
    [left addObject:left]; [left addObject:@"same"];
    [right addObject:right]; [right addObject:@"same"];
    CHECK([manager registryValue:left matchesValue:right seen:nil], "registry value comparison terminates for equivalent cyclic containers");
    right[1] = @"different";
    CHECK(![manager registryValue:left matchesValue:right seen:nil], "registry value comparison still rejects mismatched values inside cycles");
    [left removeAllObjects]; [right removeAllObjects];
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
static void PXCorruptReservationDisplay(NSString *path, BOOL atEnd) {
    NSMutableData *bytes = [[NSData dataWithContentsOfFile:path] mutableCopy];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!bytes.length || !handle) [NSException raise:@"fixture.metadata" format:@"Missing display file for same-inode corruption"];
    ((uint8_t *)bytes.mutableBytes)[atEnd ? bytes.length - 1 : 0] ^= 1;
    [handle writeData:bytes]; [handle closeFile];
}
static void TestReservationMetadata(NSString *root) {
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSUInteger mode = 0; mode < 9; mode++) {
        NSString *profileID = [NSString stringWithFormat:@"invalid-meta-%lu", (unsigned long)mode];
        NSMutableDictionary *fields = [@{ @"DisplayName": @"preflight", @"Identifier": profileID } mutableCopy];
        id record = fields;
        if (mode == 0) record = NSNull.null;
        else if (mode == 1) record = @[];
        else if (mode == 2) [fields removeObjectForKey:@"DisplayName"];
        else if (mode == 3) fields[@"DisplayName"] = @[];
        else if (mode == 4) fields[@"Identifier"] = @"different-id";
        else if (mode == 5) fields[@"Description"] = @[];
        else if (mode == 6) fields[@"extra"] = NSObject.new;
        else if (mode == 7) fields[@"extra"] = NSNull.null;
        else fields[@"Identifier"] = @1;
        NSError *stale = [NSError errorWithDomain:@"fixture.stale" code:1 userInfo:nil], *error = stale;
        CHECK(![PXProfileCreationReservation reserveProfileID:profileID inProfilesDirectory:root metadata:record error:&error] &&
            error && error != stale && ![fm fileExistsAtPath:Path(root, profileID)],
            "invalid reservation metadata fails before creating a directory or orphan marker");
    }
    @autoreleasepool {
        NSMutableString *profileID = [@"mutable-metadata" mutableCopy], *name = [@"name-before" mutableCopy], *description = [@"description-before" mutableCopy];
        NSMutableArray *extras = [NSMutableArray arrayWithObject:@"extra-before"];
        NSMutableDictionary *record = [@{ @"DisplayName": name, @"Identifier": profileID, @"Description": description, @"extra": extras } mutableCopy];
        NSError *error = [NSError errorWithDomain:@"fixture.stale" code:1 userInfo:nil];
        PXProfileCreationReservation *reservation = [PXProfileCreationReservation reserveProfileID:profileID inProfilesDirectory:root metadata:record error:&error];
        NSString *display = Path(Path(root, @"mutable-metadata"), @"identifiers.plist");
        NSData *original = [NSData dataWithContentsOfFile:display];
        [profileID setString:@"changed-id"]; [name setString:@"changed-name"]; [description setString:@"changed-description"]; [extras addObject:@"later"]; [record removeAllObjects];
        CHECK(reservation && !error && [reservation validateWithError:&error] && !error &&
            [reservation.profileID isEqual:@"mutable-metadata"] && [Record(display)[@"DisplayName"] isEqual:@"name-before"] &&
            [Record(display)[@"Description"] isEqual:@"description-before"] && [Record(display)[@"extra"] count] == 1 &&
            [original isEqual:[NSData dataWithContentsOfFile:display]], "reservation freezes actual XML bytes independently of mutable caller metadata");
    }
    for (NSUInteger mode = 0; mode < 7; mode++) {
        @autoreleasepool {
            NSString *profileID = [NSString stringWithFormat:@"display-proof-%lu", (unsigned long)mode];
            PXProfileCreationReservation *reservation = Reserve(root, profileID, NULL);
            NSString *display = Path(Path(root, profileID), @"identifiers.plist"), *old = [display stringByAppendingString:@".old"];
            CHECK(reservation && [reservation validateWithError:NULL], "display provenance fixture starts valid");
            if (!reservation) continue;
            if (mode == 0) CHECK([fm removeItemAtPath:display error:NULL], "display deletion fixture installed");
            else if (mode == 1) CHECK([fm moveItemAtPath:display toPath:old error:NULL] && [fm copyItemAtPath:old toPath:display error:NULL], "display same-byte inode replacement installed");
            else if (mode == 2) CHECK([fm moveItemAtPath:display toPath:old error:NULL] && [fm createSymbolicLinkAtPath:display withDestinationPath:old error:NULL], "display symlink fixture installed");
            else if (mode == 3) PXCorruptReservationDisplay(display, NO);
            else if (mode == 4) { NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:display]; [handle truncateFileAtOffset:0]; [handle closeFile]; }
            else if (mode == 5) CHECK(link(display.fileSystemRepresentation, old.fileSystemRepresentation) == 0, "display hardlink fixture installed");
            else { NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:display]; [handle seekToEndOfFile]; [handle writeData:[@"x" dataUsingEncoding:NSUTF8StringEncoding]]; [handle closeFile]; }
            NSError *error = nil;
            CHECK(![reservation validateWithError:&error] && [error.domain isEqual:@"WeaponXProfileDirectoryError"] && error.code == ESTALE,
                "reservation rejects missing replaced symlink mutated truncated hardlinked or extended display metadata");
        }
    }
    @autoreleasepool {
        NSString *profileID = @"large-display-proof";
        NSString *large = [@"description" stringByPaddingToLength:20000 withString:@"x" startingAtIndex:0];
        NSDictionary *record = @{ @"DisplayName": @"large", @"Identifier": profileID, @"Description": large };
        PXProfileCreationReservation *reservation = [PXProfileCreationReservation reserveProfileID:profileID inProfilesDirectory:root metadata:record error:NULL];
        CHECK(reservation && [reservation validateWithError:NULL], "multi-chunk reservation display starts valid");
        if (reservation) PXCorruptReservationDisplay(Path(Path(root, profileID), @"identifiers.plist"), YES);
        CHECK(![reservation validateWithError:NULL], "streaming display comparison detects corruption beyond the first buffer");
    }
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
    @autoreleasepool { TestReservationMetadata(root); }
    CHECK(OpenDescriptorCount() == descriptors, "metadata reservation success and rejection release every descriptor");
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
static void TestCreationDisplayDrift(PXProfileCreationFixture *manager) {
    for (NSUInteger phase = 0; phase < 2; phase++) {
        ResetWorker(); gPause = NO;
        Profile *candidate = New([NSString stringWithFormat:@"display-drift-%lu", (unsigned long)phase]);
        __block NSUInteger callbacks = 0; __block BOOL success = YES, corrupted = NO; __block NSError *failure = nil;
        NSDictionary *before = ActiveFiles(); NSData *archive = [NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")];
        NSUInteger notices = gNotices, caches = gCachePublications, mirrors = gMirrors, terminations = gTerminations;
        void (^corrupt)(void) = ^{
            PXCorruptReservationDisplay(Path(PXProfileRootPath(candidate.profileId), @"identifiers.plist"), NO); corrupted = YES;
        };
        if (phase == 0) gAfterGeneration = corrupt; else gDuringTermination = corrupt;
        [manager createProfile:candidate completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
        CHECK(Pump(^BOOL { return callbacks > 0; }) && callbacks == 1 && corrupted && !success && failure &&
            !manager.creationInProgress && !manager.creationReservation && !manager.lifecycleLease && [before isEqual:ActiveFiles()] &&
            notices == gNotices && caches == gCachePublications && mirrors == gMirrors,
            "display ownership loss never activates or publishes creation success");
        if (phase == 0) CHECK(terminations == gTerminations && [archive isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]],
            "display corruption after generation rejects before registry or termination");
        else CHECK(terminations + 1 == gTerminations && ![archive isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]],
            "display corruption during termination leaves inactive registration without activating it");
        CHECK([manager.fileManager fileExistsAtPath:PXProfileRootPath(candidate.profileId)], "display rejection retains reserved directory without automatic cleanup");
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

static void TestRegistryEncodingPreflight(void) {
    PXProfileCreationFixture *manager = NewManager(); CHECK(Reload(manager), "registry preflight fixture loads committed basis");
    Profile *previous = SeedRegistered(manager, @"registry-preflight-target");
    __block BOOL drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
    CHECK(Pump(^BOOL { return drained; }), "registry preflight fixture drains startup mirror before baseline");
    NSArray *basis = [manager.mutableProfiles copy]; Profile *current = manager.mutableCurrentProfile;
    NSString *target = previous.profileId, *archivePath = Path(PXProfilesPath(), @"profiles.plist");
    NSData *archiveBefore = [NSData dataWithContentsOfFile:archivePath]; NSDictionary *receipt = manager.registryRecord;
    NSDictionary *displayBefore = PXCaptureMetadataFixture(target), *active = ActiveFiles();
    NSUInteger notices = gNotices, mirrors = gMirrors, caches = gCachePublications, settingsNotices = gSettingsNotices, terminations = gTerminations;
    for (NSUInteger mode = 0; mode < 10; mode++) {
        Profile *bad = New(@"registry-preflight-edit"); [bad setValue:target forKey:@"profileId"];
        NSArray *keys = @[@"name", @"shortDescription", @"iconName", @"createdAt", @"lastUsed", @"settings"];
        if (mode < keys.count) [bad setValue:@[@"wrong field type"] forKey:keys[mode]];
        else if (mode == 6) [bad setValue:@1 forKey:@"profileId"];
        else if (mode == 7) {
            Profile *child = New(@"registry-invalid-child"); [child setValue:@[@"wrong icon type"] forKey:@"iconName"];
            bad.settings = @{ @"child": child };
        }
        NSMutableArray *candidate = [basis mutableCopy]; candidate[candidate.count - 1] = bad;
        if (mode == 8) [candidate addObject:bad];
        if (mode == 9) [candidate addObject:@"unexpected root member"];
        NSError *encodeError = nil, *error = nil;
        NSData *encodable = [NSKeyedArchiver archivedDataWithRootObject:candidate requiringSecureCoding:YES error:&encodeError];
        CHECK(encodable && !encodeError && ![manager preparedRegistryRecordForProfiles:candidate error:&error] && error.localizedDescription.length > 0,
            "registry preflight rejects securely encodable records that the reader cannot load");

        manager.mutableProfiles = candidate;
        __block NSUInteger callbacks = 0, writes = 0; __block BOOL success = YES; __block NSError *failure = nil;
        gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"]) writes++; };
        [manager saveProfilesWithCompletion:^(BOOL ok, NSError *saveError) { callbacks++; success = ok; failure = saveError; }];
        gStore.testCheckpoint = nil;
        BOOL preserved = [archiveBefore isEqual:[NSData dataWithContentsOfFile:archivePath]] && [receipt isEqual:manager.registryRecord];
        CHECK(callbacks == 1 && !success && failure && preserved && writes == 0 &&
            [displayBefore isEqual:PXCaptureMetadataFixture(target)] && [active isEqual:ActiveFiles()] &&
            manager.mutableCurrentProfile == current && notices == gNotices && mirrors == gMirrors && caches == gCachePublications &&
            settingsNotices == gSettingsNotices && terminations == gTerminations && !manager.lifecycleLease && !manager.creationInProgress,
            "rejected registry save preserves acknowledged bytes receipt and publication state");
        manager.mutableProfiles = [basis mutableCopy];
        if (!preserved) { [archiveBefore writeToFile:archivePath atomically:YES]; manager.registryRecord = receipt; }

        if (mode < 8) {
            callbacks = 0; writes = 0; success = YES; failure = nil;
            gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"]) writes++; };
            [manager updateProfile:bad completion:^(BOOL ok, NSError *updateError) { callbacks++; success = ok; failure = updateError; }];
            gStore.testCheckpoint = nil;
            CHECK(callbacks == 1 && !success && failure && writes == 0 && manager.mutableProfiles.lastObject == previous &&
                manager.mutableCurrentProfile == current && [displayBefore isEqual:PXCaptureMetadataFixture(target)] &&
                [archiveBefore isEqual:[NSData dataWithContentsOfFile:archivePath]] && [receipt isEqual:manager.registryRecord] &&
                notices == gNotices && [active isEqual:ActiveFiles()] && !manager.lifecycleLease && !manager.creationInProgress,
                "invalid edit archive fails before display writes registry adoption or notification");
        }
    }
    Profile *legacy = New(@"registry-legacy-defaults"); legacy.createdAt = nil; legacy.lastUsed = nil; legacy.settings = nil;
    NSArray *legacyModels = @[legacy]; NSError *error = nil;
    NSDictionary *legacyRecord = [manager preparedRegistryRecordForProfiles:legacyModels error:&error];
    Profile *decoded = [[manager decodeRegistryRecord:legacyRecord error:&error] firstObject];
    CHECK(legacyRecord && !error && decoded.createdAt && decoded.lastUsed && decoded.settings.count == 0 && !decoded.shortDescription,
        "registry preflight preserves optional field and legacy timestamp fallbacks");

    Profile *valid = New(@"registry-preflight-valid"), *child = New(@"registry-valid-child");
    [valid setValue:target forKey:@"profileId"]; valid.settings = @{ @"child": child };
    __block BOOL accepted = NO; [manager updateProfile:valid completion:^(BOOL ok, NSError *updateError) { accepted = ok && !updateError; }];
    Profile *saved = PXFindFixtureProfile([manager decodeRegistryRecord:manager.registryRecord error:NULL], target);
    Profile *savedChild = saved.settings[@"child"];
    CHECK(accepted && manager.mutableProfiles.lastObject == valid && [manager.registryRecord[@"bytes"] isEqual:[NSData dataWithContentsOfFile:archivePath]] &&
        [savedChild.name isEqual:child.name] && [active isEqual:ActiveFiles()] && notices + 1 == gNotices,
        "valid edit still saves exact validated bytes and keeps legal nested Profile values");
}

static void TestOwnedMetadataEdits(void) {
    ResetWorker(); gPause = NO;
    PXProfileCreationFixture *manager = NewManager(); manager.fileManager = [PXProfileFileManagerFixture new];
    CHECK(Reload(manager), "metadata edit API fixture loads committed registry");
    Profile *original = SeedRegistered(manager, @"edit-api-before"), *child = New(@"edit-api-child");
    original.settings = @{ @"child": child };
    [manager saveProfilesWithCompletion:^(BOOL ok, NSError *error) { CHECK(ok && !error, "metadata edit nested basis saved"); }];
    NSString *target = [original.profileId copy], *archivePath = Path(PXProfilesPath(), @"profiles.plist");
    __block BOOL drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
    CHECK(Pump(^BOOL { return drained; }), "metadata edit startup mirror drains before baseline");
    NSData *archive = [NSData dataWithContentsOfFile:archivePath]; NSDictionary *receipt = manager.registryRecord;
    NSDictionary *display = PXCaptureMetadataFixture(target), *active = ActiveFiles();
    NSUInteger notices = gNotices, mirrors = gMirrors, terminations = gTerminations, caches = gCachePublications;
    for (NSUInteger failAfter = 1; failAfter <= 4; failAfter++) {
        __block NSUInteger writes = 0, callbacks = 0; __block BOOL success = YES; __block NSError *failure = nil;
        gStore.testCheckpoint = ^(NSString *phase) {
            if ([phase isEqual:@"source-written"] && ++writes == failAfter) [NSException raise:@"fixture.edit" format:@"metadata edit source fault"];
        };
        [manager editProfileID:target name:@"edit-api-after" shortDescription:@"new description" completion:^(BOOL ok, NSError *error) {
            callbacks++; success = ok; failure = error;
            CHECK(NSThread.isMainThread && !manager.lifecycleLease && !manager.creationInProgress, "metadata edit failure callback runs after main lifecycle release");
        }];
        gStore.testCheckpoint = nil;
        CHECK(callbacks == 1 && writes == failAfter && !success && failure && [original.name isEqual:@"edit-api-before"] &&
            !original.shortDescription && manager.mutableProfiles.lastObject == original && [receipt isEqual:manager.registryRecord] &&
            [archive isEqual:[NSData dataWithContentsOfFile:archivePath]] && [display isEqual:PXCaptureMetadataFixture(target)] &&
            [active isEqual:ActiveFiles()] && notices == gNotices && mirrors == gMirrors,
            "owned metadata edit faults preserve caller model archive display absence and selection");
    }
    __block NSUInteger callbacks = 0; __block BOOL success = NO; __block NSError *failure = nil;
    [manager editProfileID:target name:@"edit-api-after" shortDescription:@"" completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    Profile *owned = manager.mutableProfiles.lastObject, *ownedChild = owned.settings[@"child"];
    NSArray *paths = PXMetadataFixturePaths(target);
    CHECK(callbacks == 1 && success && !failure && owned != original && [owned.name isEqual:@"edit-api-after"] &&
        [owned.shortDescription isEqual:@""] && [original.name isEqual:@"edit-api-before"] && !original.shortDescription &&
        ownedChild != child && [ownedChild.name isEqual:child.name] && notices + 1 == gNotices && mirrors == gMirrors &&
        [Record(paths[3])[@"Description"] isEqual:@""] && [Record(paths[3])[@"ProfileDescription"] isEqual:@""] &&
        [active isEqual:ActiveFiles()] && terminations == gTerminations && caches == gCachePublications,
        "inactive metadata edit owns the graph preserves empty description and leaves active selection unchanged");

    Select(manager, owned); active = ActiveFiles(); notices = gNotices; mirrors = gMirrors; terminations = gTerminations;
    NSUInteger settingsNotices = gSettingsNotices; __block NSUInteger commits = 0; __block NSData *archiveAtLabelCommit = nil;
    gStore.testCheckpoint = ^(NSString *phase) {
        if ([phase isEqual:@"commit-written"] && ++commits == 2) archiveAtLabelCommit = [NSData dataWithContentsOfFile:archivePath];
    };
    callbacks = 0; [manager editProfileID:target name:@"edit-active-after" shortDescription:@"active description" completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    gStore.testCheckpoint = nil;
    CHECK(callbacks == 1 && success && !failure && commits == 2 && [archiveAtLabelCommit isEqual:manager.registryRecord[@"bytes"]] &&
        [Record(PXCurrentProfileInfoPath())[@"ProfileName"] isEqual:@"edit-active-after"] &&
        [Record(PXCurrentProfileInfoPath()) isEqual:Record(PXLegacyActiveProfileInfoPath())] &&
        [manager.mutableCurrentProfile.shortDescription isEqual:@"active description"] && notices + 1 == gNotices && mirrors + 1 == gMirrors &&
        terminations == gTerminations && caches == gCachePublications && settingsNotices == gSettingsNotices,
        "active metadata edit commits registry before selection labels and publishes only after both phases");

    for (NSUInteger failAfter = 5; failAfter <= 6; failAfter++) {
        active = ActiveFiles(); notices = gNotices; mirrors = gMirrors; __block NSUInteger writes = 0;
        NSString *name = [NSString stringWithFormat:@"edit-label-fault-%lu", (unsigned long)failAfter];
        gStore.testCheckpoint = ^(NSString *phase) {
            if ([phase isEqual:@"source-written"] && ++writes == failAfter) [NSException raise:@"fixture.edit" format:@"metadata edit label fault"];
        };
        callbacks = 0; [manager editProfileID:target name:name shortDescription:nil completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
        gStore.testCheckpoint = nil;
        Profile *saved = PXFindFixtureProfile([manager decodeRegistryRecord:manager.registryRecord error:NULL], target);
        CHECK(callbacks == 1 && writes == failAfter && !success && failure && [saved.name isEqual:name] &&
            [Record(paths[0])[@"Name"] isEqual:name] && [active isEqual:ActiveFiles()] && notices == gNotices && mirrors == gMirrors &&
            !manager.lifecycleLease && !manager.creationInProgress,
            "label failure reports partial metadata commit without overwriting selection or publishing success");
    }
    active = ActiveFiles(); notices = gNotices; mirrors = gMirrors;
    gAfterArchive = ^{ PXFindFixtureProfile(manager.mutableProfiles, target).name = nil; };
    callbacks = 0; [manager editProfileID:target name:@"edit-post-commit-exception" shortDescription:nil completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    gAfterArchive = nil;
    CHECK(callbacks == 1 && !success && failure.code == 17 && [active isEqual:ActiveFiles()] && notices == gNotices && mirrors == gMirrors &&
        !manager.lifecycleLease && !manager.creationInProgress,
        "post-registry edit exception clears success and releases lifecycle before completion");
    CHECK(Reload(manager), "post-registry edit exception reloads saved values");
    drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
    CHECK(Pump(^BOOL { return drained; }), "post-exception edit mirror drains before selection conflict");
    notices = gNotices; mirrors = gMirrors;
    __block NSDictionary *newer = nil;
    gAfterArchive = ^{ CHECK(ExternalSelectionWrite(@{ @"ProfileId": @"0" }), "metadata edit bypass selection installed"); newer = ActiveFiles(); };
    callbacks = 0; [manager editProfileID:target name:@"edit-selection-conflict" shortDescription:nil completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    gAfterArchive = nil;
    CHECK(callbacks == 1 && !success && failure.code == 20 && [newer isEqual:ActiveFiles()] && notices == gNotices && mirrors == gMirrors,
        "metadata edit selection CAS preserves a newer target after registry commit");
    CHECK(Reload(manager), "metadata edit partial failure supports explicit reload");
    drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
    CHECK(Pump(^BOOL { return drained; }), "metadata edit reload mirror drains before admission tests");
    active = ActiveFiles(); archive = [NSData dataWithContentsOfFile:archivePath]; notices = gNotices;
    callbacks = 0;
    [manager editProfileID:@"missing-edit-id" name:@"missing" shortDescription:nil completion:^(BOOL ok, NSError *error) { if (!ok && error.code == 3) callbacks++; }];
    [manager editProfileID:target name:@"" shortDescription:nil completion:^(BOOL ok, NSError *error) { if (!ok && error.code == 1) callbacks++; }];
    [manager editProfileID:target name:nil shortDescription:nil completion:^(BOOL ok, NSError *error) { if (!ok && error.code == 1) callbacks++; }];
    PXProfileLifecycleLease *other = [PXProfileLifecycleLease acquireInDirectory:PXProfilesPath() error:NULL];
    [manager editProfileID:target name:@"busy" shortDescription:nil completion:^(BOOL ok, NSError *error) { if (!ok && error.code == 12) callbacks++; }];
    [other invalidate];
    CHECK(other && callbacks == 4 && [active isEqual:ActiveFiles()] && [archive isEqual:[NSData dataWithContentsOfFile:archivePath]] && notices == gNotices,
        "metadata edit rejects invalid unknown and busy requests before persistence");
    __block BOOL done = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [manager editProfileID:target name:@"edit-background" shortDescription:nil completion:^(BOOL ok, NSError *error) {
            success = ok; failure = error; done = NSThread.isMainThread && !manager.lifecycleLease;
        }];
    });
    CHECK(Pump(^BOOL { return done; }) && success && !failure && [active isEqual:ActiveFiles()], "background metadata edit delivers on main after releasing ownership");
    [manager renameProfile:@"edit-background" to:@"edit-compatibility"];
    CHECK([PXFindFixtureProfile(manager.mutableProfiles, target).name isEqual:@"edit-compatibility"], "legacy rename routes through the owned metadata edit API");
    Profile *first = SeedRegistered(manager, @"edit-duplicate-label"), *second = SeedRegistered(manager, @"edit-duplicate-label");
    callbacks = 0;
    [manager editProfileID:second.profileId name:@"edit-exact-target" shortDescription:nil completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    CHECK(callbacks == 1 && success && !failure && [PXFindFixtureProfile(manager.mutableProfiles, first.profileId).name isEqual:@"edit-duplicate-label"] &&
        [PXFindFixtureProfile(manager.mutableProfiles, second.profileId).name isEqual:@"edit-exact-target"] && [second.name isEqual:@"edit-duplicate-label"],
        "ID-based edits do not select another profile with the same display name");
}

static void TestActivationModelPolicy(void) {
    PXProfileCreationFixture *manager = NewManager();
    Profile *model = New(@"activation-proof"), *child = New(@"activation-child");
    model.settings = @{ @"child": child };
    NSArray *models = @[model]; NSError *error = nil;
    NSData *bytes = [NSKeyedArchiver archivedDataWithRootObject:models requiringSecureCoding:YES error:&error];
    NSDictionary *record = @{ @"exists": @YES, @"bytes": bytes ?: NSData.data };
    model.pxDecodedMissingCreatedAt = YES; model.pxDecodedMissingLastUsed = YES;
    child.pxDecodedMissingCreatedAt = YES; child.pxDecodedMissingLastUsed = YES;
    CHECK(bytes && !error && [manager activationProfile:model matchesRegistry:record error:&error] && !error,
        "activation accepts equal persisted date values despite transient legacy provenance flags");
    Profile *persisted = [[manager decodeRegistryRecord:record error:NULL] firstObject];
    model.createdAt = [model.createdAt dateByAddingTimeInterval:10]; error = nil;
    CHECK([manager registryValue:model matchesValue:persisted seen:nil] &&
        ![manager activationProfile:model matchesRegistry:record error:&error] && error.code == 31,
        "activation strict date matching does not inherit deletion legacy timestamp relaxation");
    for (NSUInteger field = 0; field < 8; field++) {
        Profile *changed = [[manager decodeRegistryRecord:record error:NULL] firstObject];
        Profile *changedChild = changed.settings[@"child"];
        if (field == 0) [changed setValue:@"activation-unknown" forKey:@"profileId"];
        else if (field == 1) changed.name = @"different name";
        else if (field == 2) changed.shortDescription = @"different description";
        else if (field == 3) changed.iconName = @"different icon";
        else if (field == 4) changed.createdAt = [changed.createdAt dateByAddingTimeInterval:10];
        else if (field == 5) changed.lastUsed = [changed.lastUsed dateByAddingTimeInterval:10];
        else if (field == 6) changed.settings = @{ @"different": @YES };
        else { changedChild.pxDecodedMissingCreatedAt = YES; changedChild.createdAt = [changedChild.createdAt dateByAddingTimeInterval:10]; }
        error = nil;
        CHECK(changed && changedChild && ![manager activationProfile:changed matchesRegistry:record error:&error] && error.code == 31,
            "activation model proof rejects target metadata dates settings and nested date drift");
    }
}
static void TestActivationCallbackDrift(void) {
    for (NSUInteger operation = 0; operation < 2; operation++) for (NSUInteger phase = 0; phase < 2; phase++) {
        ResetWorker(); gPause = NO; gAfterArchive = nil;
        PXProfileCreationFixture *manager = NewManager(); manager.fileManager = [PXProfileFileManagerFixture new];
        CHECK(Reload(manager), "activation callback fixture loads committed registry");
        __block BOOL drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
        CHECK(Pump(^BOOL { return drained; }), "activation fixture drains deferred startup mirror before baseline");
        Profile *input = operation == 0 ? New([NSString stringWithFormat:@"create-model-drift-%lu", (unsigned long)phase]) :
            SeedRegistered(manager, [NSString stringWithFormat:@"switch-model-drift-%lu", (unsigned long)phase]);
        NSString *acceptedName = [input.name copy];
        NSDictionary *before = ActiveFiles(); Profile *previousCurrent = manager.mutableCurrentProfile;
        NSUInteger notices = gNotices, mirrors = gMirrors, caches = gCachePublications, settingsNotices = gSettingsNotices, terminations = gTerminations;
        __block BOOL changed = NO, success = YES; __block NSUInteger callbacks = 0; __block NSError *failure = nil;
        void (^mutate)(void) = ^{
            Profile *live = PXFindFixtureProfile(manager.mutableProfiles, input.profileId);
            if (!live) [NSException raise:@"fixture.activation" format:@"Registered target missing during model drift"];
            if (phase == 0) live.name = @"callback model drift";
            else { live.pxDecodedMissingLastUsed = YES; live.lastUsed = [NSDate dateWithTimeIntervalSince1970:1]; }
            changed = YES;
        };
        if (phase == 0) gAfterArchive = mutate; else gDuringTermination = mutate;
        void (^completion)(BOOL, NSError *) = ^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; };
        if (operation == 0) [manager createProfile:input completion:completion]; else [manager switchToProfile:input completion:completion];
        CHECK(Pump(^BOOL { return callbacks > 0; }) && callbacks == 1 && changed && !success && failure.code == 31 &&
            [before isEqual:ActiveFiles()] && manager.mutableCurrentProfile == previousCurrent &&
            notices == gNotices && mirrors == gMirrors && caches == gCachePublications && settingsNotices == gSettingsNotices &&
            !manager.creationInProgress && !manager.lifecycleLease && !manager.creationReservation,
            "create and switch reject callback model drift without activating or publishing success");
        gAfterArchive = nil; gDuringTermination = nil;
        CHECK(gTerminations == terminations + phase, "post-archive model drift rejects before termination and post-termination drift is not repeated");
        Profile *committed = PXFindFixtureProfile([manager decodeRegistryRecord:manager.registryRecord error:NULL], input.profileId);
        CHECK(committed && [committed.name isEqual:acceptedName] && ![committed.lastUsed isEqual:[NSDate dateWithTimeIntervalSince1970:1]],
            "callback model drift does not rewrite the acknowledged registry archive");
        CHECK(Reload(manager) && [PXFindFixtureProfile(manager.mutableProfiles, input.profileId).name isEqual:acceptedName],
            "explicit reload replaces callback-mutated slots with committed registry values");
        drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
        CHECK(Pump(^BOOL { return drained; }), "activation drift reload mirror drains before next lifecycle fixture");
    }
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
@interface PXUIDeletionFixture : PXObservedProfileCreationFixture
@property (nonatomic, copy) void (^afterInactiveAttempt)(NSString *profileID, BOOL success);
@end
@implementation PXUIDeletionFixture
- (void)deleteInactiveProfileID:(NSString *)profileID completion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    [super deleteInactiveProfileID:profileID completion:^(BOOL ok, NSError *error) {
        if (completion) completion(ok, error);
        if (self.afterInactiveAttempt) self.afterInactiveAttempt(profileID, ok);
    }];
}
@end
static void TestUIDeletionAuthority(void) {
    __block BOOL drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
    CHECK(Pump(^BOOL { return drained; }), "UI deletion fixture drains previous namespace callbacks");
    NSString *previousRoot = gRoot; PXRuntimeSourceStore *previousStore = gStore;
    gRoot = Path(previousRoot, @"ui-delete-authority");
    NSFileManager *fm = NSFileManager.defaultManager;
    CHECK([fm createDirectoryAtPath:Identity(@"0") withIntermediateDirectories:YES attributes:nil error:NULL], "UI deletion isolated root created");
    SetupStore(); ResetWorker(); gPause = NO;
    PXUIDeletionFixture *manager = [PXUIDeletionFixture new];
    Profile *zero = New(@"ui-zero"); [zero setValue:@"0" forKey:@"profileId"];
    [manager.mutableProfiles addObject:zero]; manager.mutableCurrentProfile = zero;
    CHECK(gStore && [manager updateCurrentProfileInfoWithProfile:zero error:NULL], "UI deletion initial selection committed");
    [manager saveProfilesWithCompletion:^(BOOL ok, NSError *error) { CHECK(ok && !error, "UI deletion initial registry saved"); }];
    Profile *one = SeedRegistered(manager, @"ui-delete-one"), *two = SeedRegistered(manager, @"ui-delete-two");
    Profile *protected = New(@"ui-protected"); [protected setValue:@"profile_0" forKey:@"profileId"];
    [manager createDirectoryIfNeeded:Identity(protected.profileId)]; [manager.mutableProfiles addObject:protected];
    [manager saveProfilesWithCompletion:^(BOOL ok, NSError *error) { CHECK(ok && !error, "UI deletion protected alias saved"); }];
    [manager createDirectoryIfNeeded:Identity(@"orphan-only")];
    PXProfileCreationReservation *reservation = Reserve(PXProfilesPath(), @"reserved-only", NULL);
    NSArray *published = manager.profiles;
    CHECK(reservation && published.count == 4 && !PXFindFixtureProfile(published, @"orphan-only") && !PXFindFixtureProfile(published, @"reserved-only"),
        "verified list exposes registered models without adopting orphan or reserved directories");
    NSData *archive = [NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]; NSDictionary *active = ActiveFiles();
    NSUInteger notices = gNotices; __block NSUInteger callbacks = 0; __block BOOL success = YES; __block NSError *failure = nil;
    manager.mutableCurrentProfile = one;
    [manager deleteInactiveProfileID:@"0" completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    CHECK(callbacks == 1 && !success && failure.code == 32 && [archive isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]] &&
        [active isEqual:ActiveFiles()] && notices == gNotices && [fm fileExistsAtPath:Identity(@"0")],
        "inactive-only delete checks committed active ID instead of stale UI memory");
    manager.mutableCurrentProfile = zero;
    Select(manager, one); archive = [NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]; active = ActiveFiles(); notices = gNotices;
    callbacks = 0; [manager deleteInactiveProfileID:one.profileId completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    CHECK(callbacks == 1 && !success && failure.code == 32 && [active isEqual:ActiveFiles()] && notices == gNotices &&
        [archive isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]] && [fm fileExistsAtPath:Identity(one.profileId)],
        "profile activated after confirmation cannot be removed through UI deletion");
    Select(manager, zero); archive = [NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]; active = ActiveFiles(); notices = gNotices;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"]) [NSException raise:@"fixture.ui-delete" format:@"delete decision fault"]; };
    callbacks = 0; [manager deleteInactiveProfileID:one.profileId completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    gStore.testCheckpoint = nil;
    CHECK(callbacks == 1 && !success && failure && [active isEqual:ActiveFiles()] && [archive isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]] &&
        [fm fileExistsAtPath:Identity(one.profileId)] && notices == gNotices && !manager.lifecycleLease && !manager.creationInProgress,
        "UI delete decision failure preserves registry directory and callback lifecycle");
    callbacks = 0; [manager deleteInactiveProfileID:one.profileId completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    CHECK(callbacks == 1 && success && !failure && !PXFindFixtureProfile(manager.profiles, one.profileId) && ![fm fileExistsAtPath:Identity(one.profileId)] &&
        published.count == 4 && notices + 1 == gNotices, "UI delete success unregisters before file cleanup without mutating a captured list");

    notices = gNotices;
    PXProfileDeletionTestCheckpoint = ^(NSString *stage) {
        if ([stage isEqual:@"settled"]) CHECK(ExternalSelectionWrite(@{ @"ProfileId": two.profileId }), "post-settlement active selection installed");
    };
    callbacks = 0; [manager deleteInactiveProfileID:two.profileId completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    PXProfileDeletionTestCheckpoint = nil;
    CHECK(callbacks == 1 && !success && failure.code == 20 && manager.registryUnavailable && [fm fileExistsAtPath:Identity(two.profileId)] &&
        [Record(PXCurrentProfileInfoPath())[@"ProfileId"] isEqual:two.profileId] && notices == gNotices,
        "source drift after logical deletion preserves newly active files and reports partial failure");
    CHECK(Reload(manager), "post-settlement drift reload restores the explicit committed target without cleanup retry");
    drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
    CHECK(Pump(^BOOL { return drained; }), "UI deletion recovery mirror drains before bulk fixture");
    Select(manager, zero);
    Profile *three = SeedRegistered(manager, @"bulk-becomes-active");
    __block NSString *lateID = nil; NSMutableArray *attempts = [NSMutableArray array];
    __weak PXUIDeletionFixture *weakManager = manager;
    manager.afterInactiveAttempt = ^(NSString *profileID, BOOL ok) {
        [attempts addObject:profileID];
        PXUIDeletionFixture *owner = weakManager;
        if (ok && [profileID isEqual:two.profileId] && !lateID) {
            Select(owner, three); lateID = [SeedRegistered(owner, @"created-between-bulk-items").profileId copy];
        }
    };
    __block NSDictionary *report = nil; callbacks = 0;
    [manager deleteInactiveProfilesWithCompletion:^(NSDictionary *value) { callbacks++; report = value; CHECK(NSThread.isMainThread && !manager.lifecycleLease, "bulk completion runs on main outside lifecycle ownership"); }];
    CHECK(Pump(^BOOL { return report != nil; }) && callbacks == 1 && [report[@"deleted"] count] == 1 && [report[@"deleted"] containsObject:two.profileId] &&
        [report[@"skipped"] containsObject:@"0"] && [report[@"skipped"] containsObject:@"profile_0"] && [report[@"skipped"] containsObject:three.profileId] &&
        [report[@"failed"] count] == 0 && lateID && attempts.count == 2 && [fm fileExistsAtPath:Identity(three.profileId)] &&
        [fm fileExistsAtPath:Identity(lateID)] && [fm fileExistsAtPath:Identity(@"orphan-only")] && [fm fileExistsAtPath:Identity(@"reserved-only")] &&
        [fm fileExistsAtPath:Identity(@"profile_0")], "bulk delete preserves live active protected orphan reserved and newly created profiles");
    manager.afterInactiveAttempt = nil;
    Profile *blocked = SeedRegistered(manager, @"bulk-busy"); (void)blocked;
    active = ActiveFiles(); archive = [NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]; notices = gNotices;
    PXProfileLifecycleLease *other = [PXProfileLifecycleLease acquireInDirectory:PXProfilesPath() error:NULL];
    report = nil; callbacks = 0;
    [manager deleteInactiveProfilesWithCompletion:^(NSDictionary *value) { callbacks++; report = value; }];
    CHECK(Pump(^BOOL { return report != nil; }) && other && callbacks == 1 && [report[@"failed"] count] == 3 && [report[@"deleted"] count] == 0 &&
        [archive isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]] && [active isEqual:ActiveFiles()] && notices == gNotices,
        "busy bulk deletion reports one bounded failure per captured candidate without retry or mutation");
    [other invalidate];
    __block BOOL delivered = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [manager deleteInactiveProfileID:blocked.profileId completion:^(BOOL ok, NSError *error) {
            success = ok; failure = error; delivered = NSThread.isMainThread && !manager.lifecycleLease && !manager.creationInProgress;
        }];
    });
    CHECK(Pump(^BOOL { return delivered; }) && success && !failure && ![fm fileExistsAtPath:Identity(blocked.profileId)],
        "background inactive delete completes on main after releasing lifecycle ownership");
    manager.registryUnavailable = YES; report = nil; callbacks = 0;
    [manager deleteInactiveProfilesWithCompletion:^(NSDictionary *value) { callbacks++; report = value; }];
    CHECK(callbacks == 1 && [report[@"error"] length] && [report[@"deleted"] count] == 0, "invalid registry stops bulk deletion before any namespace cleanup");
    drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
    CHECK(Pump(^BOOL { return drained; }), "UI deletion isolated callbacks drained before root restore");
    [fm removeItemAtPath:gRoot error:NULL]; gRoot = previousRoot; gStore = previousStore;
}

@interface PXAllocationRaceFixture : Profile
@end
@implementation PXAllocationRaceFixture
- (Class)classForKeyedArchiver { return Profile.class; }
- (void)setValue:(id)value forKey:(NSString *)key {
    if ([key isEqual:@"profileId"]) CHECK([NSData.data writeToFile:Path(PXProfilesPath(), value) atomically:NO], "allocation race blocker installed after discovery");
    [super setValue:value forKey:key];
}
@end
static void TestProfileIDAllocation(void) {
    PXProfileCreationFixture *pure = NewManager();
    NSArray *cases = @[
        @{ @"ids": @[], @"blocked": @[], @"next": @"1" },
        @{ @"ids": @[@"0", @"17", @"A77"], @"blocked": @[], @"next": @"18" },
        @{ @"ids": @[@"999", @"A01", @"z-foreign", @"profile_0"], @"blocked": @[], @"next": @"A02" },
        @{ @"ids": @[@"999", @"A99"], @"blocked": @[], @"next": @"B01" },
        @{ @"ids": @[@"999", @"Z98"], @"blocked": @[], @"next": @"Z99" },
        @{ @"ids": @[@"999", @"Z99"], @"blocked": @[], @"next": NSNull.null },
        @{ @"ids": @[@"000998"], @"blocked": @[], @"next": @"999" },
        @{ @"ids": @[@"184467440737095516160000000000000"], @"blocked": @[], @"next": @"A01" },
        @{ @"ids": @[@"A05"], @"blocked": @[], @"next": @"A06" },
        @{ @"ids": @[@"0", @"998", @"B99"], @"blocked": @[@"999", @"C01"], @"next": @"C02" },
        @{ @"ids": @[@"0"], @"blocked": @[@"1", @"2", @"3"], @"next": @"4" },
        @{ @"ids": @[@"0", @"١٧", @"foreign-uuid", @"A099"], @"blocked": @[], @"next": @"1" }
    ];
    for (NSDictionary *row in cases) {
        NSError *error = nil;
        NSString *candidate = [pure nextProfileIDForExistingIDs:[NSSet setWithArray:row[@"ids"]] occupied:[NSSet setWithArray:row[@"blocked"]] error:&error];
        BOOL exhausted = row[@"next"] == NSNull.null;
        CHECK(exhausted ? (!candidate && error.code == 33) : ([candidate isEqual:row[@"next"]] && !error),
            "ID ordering preserves normal numeric and alpha progression without overflow or foreign-name poisoning");
    }
    CHECK(![pure isNumericString:@""] && ![pure isNumericString:@"١٧"] && [pure isNumericString:@"0017"] &&
        [pure allocationOrdinalForID:@"A00"] == NSNotFound && [pure allocationOrdinalForID:@"a01"] == NSNotFound,
        "allocation grammar is nonempty ASCII with bounded canonical alpha suffixes");
    NSSet *zeroIDs = [NSSet setWithObject:@"0"]; NSMutableSet *probed = [NSMutableSet set]; __block NSUInteger probes = 0; NSError *probeError = nil;
    NSString *probedID = [pure nextProfileIDForExistingIDs:zeroIDs occupied:NSSet.set probe:^BOOL(NSString *candidate, BOOL *exists, NSError **error) {
        (void)error; probes++; [probed addObject:candidate]; *exists = ![candidate isEqual:@"3"]; return YES;
    } error:&probeError];
    CHECK([probedID isEqual:@"3"] && !probeError && probes == 3 && probed.count == 3, "namespace probing advances each candidate once without redoing sequence discovery");
    probes = 0;
    probedID = [pure nextProfileIDForExistingIDs:zeroIDs occupied:NSSet.set probe:^BOOL(NSString *candidate, BOOL *exists, NSError **error) {
        (void)candidate; (void)exists; probes++; if (error) *error = [NSError errorWithDomain:@"fixture.probe" code:55 userInfo:nil]; return NO;
    } error:&probeError];
    CHECK(!probedID && probes == 1 && probeError.code == 55, "namespace probe errors stop allocation without fallback or retry");

    __block BOOL drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
    CHECK(Pump(^BOOL { return drained; }), "allocation fixture drains previous namespace callbacks");
    NSString *previousRoot = gRoot; PXRuntimeSourceStore *previousStore = gStore;
    gRoot = Path(previousRoot, @"allocation-fixture"); NSFileManager *fm = NSFileManager.defaultManager;
    [fm createDirectoryAtPath:Identity(@"0") withIntermediateDirectories:YES attributes:nil error:NULL]; SetupStore();
    PXProfileCreationFixture *manager = NewManager(); Profile *zero = New(@"allocation-zero"); [zero setValue:@"0" forKey:@"profileId"];
    [manager.mutableProfiles addObject:zero]; manager.mutableCurrentProfile = zero;
    CHECK(gStore && [manager updateCurrentProfileInfoWithProfile:zero error:NULL], "allocation namespace initial selection committed");
    [manager saveProfilesWithCompletion:^(BOOL ok, NSError *error) { CHECK(ok && !error, "allocation namespace initial registry saved"); }];
    for (NSString *name in @[@"999", @"A01", @"z-foreign", @"A099"]) [manager createDirectoryIfNeeded:Path(PXProfilesPath(), name)];
    NSData *blocker = [@"keep this file" dataUsingEncoding:NSUTF8StringEncoding];
    CHECK([blocker writeToFile:Path(PXProfilesPath(), @"A02") atomically:YES] &&
        [fm createSymbolicLinkAtPath:Path(PXProfilesPath(), @"A03") withDestinationPath:@"missing-target" error:NULL], "allocation file and dangling symlink blockers created");
    NSString *outside = Path(gRoot, @"unrelated-tree"); [manager createDirectoryIfNeeded:outside];
    CHECK([blocker writeToFile:Path(outside, @"sentinel") atomically:YES] &&
        [fm createSymbolicLinkAtPath:Path(PXProfilesPath(), @"Z99") withDestinationPath:outside error:NULL], "allocation live directory symlink blocker created");
    NSError *error = nil;
    CHECK([[manager generateProfileIDWithError:&error] isEqual:@"A04"] && !error && [blocker isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"A02")]] &&
        [blocker isEqual:[NSData dataWithContentsOfFile:Path(outside, @"sentinel")]], "verified allocation skips occupied leaves without following symlinks or modifying files");
    Profile *registered = New(@"allocation-missing-directory"); [registered setValue:@"A08" forKey:@"profileId"];
    [manager.mutableProfiles addObject:registered];
    [manager saveProfilesWithCompletion:^(BOOL ok, NSError *failure) { CHECK(ok && !failure, "allocation missing-directory record saved"); }];
    CHECK([[manager generateProfileIDWithError:&error] isEqual:@"A09"] && !error && ![fm fileExistsAtPath:Identity(@"A08")],
        "registered IDs remain occupied even when their directories are missing");

    PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:PXProfilesPath() error:NULL]; manager.lifecycleLease = lease;
    NSUInteger descriptors = OpenDescriptorCount();
    NSDictionary *first = [lease allocationInventoryWithError:&error], *second = [lease allocationInventoryWithError:&error];
    NSSet *firstNames = [NSSet setWithArray:first[@"occupied"] ?: @[]], *secondNames = [NSSet setWithArray:second[@"occupied"] ?: @[]];
    CHECK(first && second && !error && [firstNames isEqual:secondNames] && [firstNames containsObject:@"Z99"] &&
        ![first[@"directories"] containsObject:@"Z99"] && ![first[@"directories"] containsObject:@"A03"] &&
        [[manager generateProfileIDWithError:&error] isEqual:@"A09"] && [lease validateWithError:NULL] && descriptors == OpenDescriptorCount(),
        "repeated borrowed allocation inventories reset directory offsets retain ownership and close descriptors");
    [lease invalidate]; descriptors = OpenDescriptorCount();
    CHECK(![manager generateProfileIDWithError:&error] && error && descriptors == OpenDescriptorCount(), "expired allocation capability fails without leaking descriptors");
    manager.lifecycleLease = nil;
    PXProfileLifecycleLease *other = [PXProfileLifecycleLease acquireInDirectory:PXProfilesPath() error:NULL];
    CHECK(other && ![manager generateProfileIDWithError:&error] && error.code == 12 && ![manager generateProfileID] && [other validateWithError:NULL],
        "busy allocation reports failure without a guessed legacy fallback"); [other invalidate];

    NSString *archivePath = Path(PXProfilesPath(), @"profiles.plist"); NSData *archive = [NSData dataWithContentsOfFile:archivePath]; NSDictionary *receipt = manager.registryRecord;
    NSData *bad = [@"invalid registry bytes" dataUsingEncoding:NSUTF8StringEncoding];
    CHECK([bad writeToFile:archivePath atomically:YES] && ![manager generateProfileIDWithError:&error] && error.code == 25,
        "allocation rejects stale registry receipts instead of guessing an ID");
    manager.registryRecord = @{ @"exists": @YES, @"bytes": bad };
    CHECK(![manager generateProfileIDWithError:&error] && error, "allocation rejects unreadable registry bytes through the shared decoder");
    Profile *input = New(@"allocation-failure-before-input-edit"); NSString *inputID = [input.profileId copy]; NSDate *created = input.createdAt, *used = input.lastUsed;
    NSDictionary *active = ActiveFiles(); NSSet *leaves = [NSSet setWithArray:[fm contentsOfDirectoryAtPath:PXProfilesPath() error:NULL]];
    ResetWorker(); gPause = NO; __block NSUInteger callbacks = 0; __block BOOL success = YES; __block NSError *failure = nil;
    [manager createProfile:input completion:^(BOOL ok, NSError *value) { callbacks++; success = ok; failure = value; }];
    CHECK(Pump(^BOOL { return callbacks > 0; }) && callbacks == 1 && !success && failure && [inputID isEqual:input.profileId] && [created isEqual:input.createdAt] && [used isEqual:input.lastUsed] &&
        !atomic_load(&gEntered) && !manager.lifecycleLease && !manager.creationInProgress && [active isEqual:ActiveFiles()] &&
        [leaves isEqual:[NSSet setWithArray:[fm contentsOfDirectoryAtPath:PXProfilesPath() error:NULL]]],
        "allocation failure stops create before caller mutation reservation provider or selection effects");
    CHECK([archive writeToFile:archivePath atomically:YES], "allocation valid registry restored"); manager.registryRecord = receipt;
    NSString *heldRoot = [PXProfilesPath() stringByAppendingString:@".held"];
    CHECK([fm moveItemAtPath:PXProfilesPath() toPath:heldRoot error:NULL] && ![manager generateProfileIDWithError:&error] && error &&
        ![fm fileExistsAtPath:PXProfilesPath()], "missing allocation root is not recreated or replaced by fallback");
    CHECK([fm moveItemAtPath:heldRoot toPath:PXProfilesPath() error:NULL], "allocation namespace root restored");
    __block BOOL offMainDone = NO; __block NSString *offCandidate = nil; __block NSInteger offCode = 0;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *workerError = nil; NSString *candidate = [manager generateProfileIDWithError:&workerError];
        dispatch_async(dispatch_get_main_queue(), ^{ offCandidate = candidate; offCode = workerError.code; offMainDone = YES; });
    });
    CHECK(Pump(^BOOL { return offMainDone; }) && !offCandidate && offCode == 23, "off-main allocation rejects before namespace access");

    PXAllocationRaceFixture *race = [[PXAllocationRaceFixture alloc] initWithName:@"allocation-reservation-race" iconName:@"default_profile"];
    callbacks = 0; ResetWorker(); gPause = NO;
    [manager createProfile:race completion:^(BOOL ok, NSError *value) { callbacks++; success = ok; failure = value; }];
    CHECK(Pump(^BOOL { return callbacks > 0; }) && callbacks == 1 && !success && failure.code == 13 && !atomic_load(&gEntered) && ![fm fileExistsAtPath:Identity(race.profileId)] &&
        [fm fileExistsAtPath:Path(PXProfilesPath(), race.profileId)] && [archive isEqual:[NSData dataWithContentsOfFile:archivePath]],
        "exclusive reservation remains authoritative when a leaf appears after allocation");
    CHECK([blocker writeToFile:Path(PXProfilesPath(), @"a10") atomically:YES], "filesystem alias blocker created");
    NSString *expected = [fm fileExistsAtPath:Path(PXProfilesPath(), @"A10")] ? @"A11" : @"A10";
    CHECK([[manager generateProfileIDWithError:&error] isEqual:expected] && !error && [blocker isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"a10")]],
        "allocation respects the actual filesystem case-alias policy without assuming case sensitivity");
    CHECK([fm removeItemAtPath:Path(PXProfilesPath(), @"Z99") error:NULL] && [fm createDirectoryAtPath:Path(PXProfilesPath(), @"Z99") withIntermediateDirectories:NO attributes:nil error:NULL] &&
        ![manager generateProfileIDWithError:&error] && error.code == 33 && [blocker isEqual:[NSData dataWithContentsOfFile:Path(outside, @"sentinel")]],
        "sequence exhaustion preserves occupied namespace instead of inventing an invalid next prefix");
    drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
    CHECK(Pump(^BOOL { return drained; }), "allocation isolated callbacks drained before root restore");
    [fm removeItemAtPath:gRoot error:NULL]; gRoot = previousRoot; gStore = previousStore;
}

static NSUInteger gCreationUIEvents;
static void CreationUIEvent(void) { CHECK(NSThread.isMainThread, "creation UI adapter effects run on main"); gCreationUIEvents++; }
@interface PXControlledCreationManager : PXProfileCreationFixture
@property (nonatomic) NSUInteger requests, selectionChecks;
@property (nonatomic, strong) Profile *requestedInput;
@property (nonatomic, copy) NSString *activeID;
@property (nonatomic, copy) void (^pendingCreation)(BOOL, NSError *);
- (void)completeCreation:(BOOL)success;
@end
@implementation PXControlledCreationManager
- (void)createProfile:(Profile *)profile completion:(void (^)(BOOL, NSError *))completion {
    CHECK(NSThread.isMainThread, "controlled controller create enters on main"); self.requests++;
    [profile setValue:@"controller-target" forKey:@"profileId"]; self.requestedInput = profile;
    self.mutableProfiles = [NSMutableArray arrayWithObject:profile]; self.pendingCreation = completion;
}
- (BOOL)validateCurrentProfileID:(NSString *)profileID error:(NSError **)error {
    CHECK(NSThread.isMainThread, "controller selection checkpoint enters on main"); self.selectionChecks++;
    if ([profileID isEqual:self.activeID]) return YES;
    if (error) *error = [NSError errorWithDomain:@"fixture.selection" code:20 userInfo:nil]; return NO;
}
- (void)completeCreation:(BOOL)success {
    void (^callback)(BOOL, NSError *) = self.pendingCreation; self.pendingCreation = nil;
    CHECK(callback != nil, "controlled creation callback exists exactly once");
    if (callback) callback(success, success ? nil : [NSError errorWithDomain:@"fixture.create" code:9 userInfo:nil]);
}
@end
@interface PXCreationButtons : NSObject
@property (nonatomic) BOOL userInteractionEnabled, enabled;
@end
@implementation PXCreationButtons
- (instancetype)init { if ((self = [super init])) { _enabled = YES; _userInteractionEnabled = YES; } return self; }
@end
@interface PXDeviceCreateUIFixture : NSObject
@property (nonatomic) BOOL profileCreationInProgress;
@property (nonatomic, strong) PXCreationButtons *profileButtonsView;
@property (nonatomic) NSUInteger refreshes, failures, warnings;
- (void)createDeviceProfileWithName:(NSString *)name shortDescription:(NSString *)shortDescription;
- (void)refreshProfileUI;
- (void)presentDeviceProfileCreationResult:(BOOL)created error:(NSError *)error;
@end
@interface PXManualCreateUIFixture : NSObject
@property (nonatomic) BOOL manualProfileCreationInProgress;
@property (nonatomic, strong) NSMutableArray *profiles;
@property (nonatomic) NSUInteger shows, hides, refreshes, indicators, successes, failures, warnings;
- (void)submitManualProfileName:(NSString *)name shortDescription:(NSString *)shortDescription;
- (void)showLoadingIndicator; - (void)hideLoadingIndicator; - (void)updateProfileIndicator; - (void)refreshIdentifierValuesInUI;
- (void)showError:(NSError *)error; - (void)showSuccessMessage:(NSString *)message; - (void)showManualProfileCreationUnconfirmed:(NSError *)error;
@end
@interface UITextField : NSObject
@property (nonatomic, copy) NSString *text;
@end
@implementation UITextField
@end
@interface PXCreationSpinner : NSObject
@property (nonatomic) NSUInteger starts, stops;
- (void)startAnimating; - (void)stopAnimating;
@end
@implementation PXCreationSpinner
- (void)startAnimating { CreationUIEvent(); self.starts++; }
- (void)stopAnimating { CreationUIEvent(); self.stops++; }
@end
@protocol PXCreationDelegate <NSObject>
- (void)profileCreationViewController:(id)controller didCreateProfile:(NSString *)name;
@end
@interface PXCreationDelegateFixture : NSObject <PXCreationDelegate>
@property (nonatomic) NSUInteger calls;
@property (nonatomic, copy) NSString *name;
@end
@implementation PXCreationDelegateFixture
- (void)profileCreationViewController:(id)controller didCreateProfile:(NSString *)name { (void)controller; CreationUIEvent(); self.calls++; self.name = name; }
@end
@interface PXFormCreateUIFixture : NSObject
@property (nonatomic) BOOL profileCreationInProgress;
@property (nonatomic, strong) UITextField *nameTextField;
@property (nonatomic, strong) PXCreationButtons *createButton, *cancelButton;
@property (nonatomic, strong) PXCreationSpinner *activityIndicator;
@property (nonatomic, weak) id<PXCreationDelegate> delegate;
@property (nonatomic) NSUInteger alerts, dismissals;
- (void)createButtonTapped; - (void)cancelButtonTapped; - (void)textFieldDidChangeSelection:(UITextField *)textField;
- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message;
- (void)dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion;
@end
// Compile the exact controller adapter bodies with controlled collaborators;
// UIKit presentation/layout is deliberately outside this Foundation fixture.
#define ProfileManager PXProfileCreationFixture
@implementation PXDeviceCreateUIFixture
- (instancetype)init { if ((self = [super init])) _profileButtonsView = [PXCreationButtons new]; return self; }
- (void)refreshProfileUI { CreationUIEvent(); self.refreshes++; }
- (void)presentDeviceProfileCreationResult:(BOOL)created error:(NSError *)error { (void)error; CreationUIEvent(); if (created) self.warnings++; else self.failures++; }
#include "PXDeviceCreateUI.inc"
@end
@implementation PXManualCreateUIFixture
- (void)showLoadingIndicator { CreationUIEvent(); self.shows++; }
- (void)hideLoadingIndicator { CreationUIEvent(); self.hides++; }
- (void)updateProfileIndicator { CreationUIEvent(); self.indicators++; }
- (void)refreshIdentifierValuesInUI { CreationUIEvent(); self.refreshes++; }
- (void)showError:(NSError *)error { (void)error; CreationUIEvent(); self.failures++; }
- (void)showSuccessMessage:(NSString *)message { (void)message; CreationUIEvent(); self.successes++; }
- (void)showManualProfileCreationUnconfirmed:(NSError *)error { (void)error; CreationUIEvent(); self.warnings++; }
#include "PXManualCreateUI.inc"
@end
@implementation PXFormCreateUIFixture
- (instancetype)init {
    if ((self = [super init])) { _nameTextField = [UITextField new]; _nameTextField.text = @"form entry"; _createButton = [PXCreationButtons new]; _cancelButton = [PXCreationButtons new]; _activityIndicator = [PXCreationSpinner new]; }
    return self;
}
- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message { (void)title; (void)message; CreationUIEvent(); self.alerts++; }
- (void)dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion { (void)animated; CreationUIEvent(); self.dismissals++; if (completion) completion(); }
#include "PXFormCreateUI.inc"
@end
#undef ProfileManager
static PXControlledCreationManager *ControlledCreationManager(void) {
    PXControlledCreationManager *manager = [PXControlledCreationManager new]; manager.activeID = @"controller-target"; gControllerManager = manager; return manager;
}
static void TestCreationUIAdapters(void) {
    for (NSUInteger mode = 0; mode < 3; mode++) {
        PXControlledCreationManager *manager = ControlledCreationManager(); PXDeviceCreateUIFixture *view = [PXDeviceCreateUIFixture new];
        NSMutableString *name = [@"device request" mutableCopy]; [view createDeviceProfileWithName:name shortDescription:@"description"];
        [name setString:@"later edit"]; [view createDeviceProfileWithName:@"duplicate" shortDescription:nil];
        CHECK(manager.requests == 1 && view.profileCreationInProgress && !view.profileButtonsView.userInteractionEnabled && view.refreshes == 0 &&
            view.failures == 0 && manager.selectionChecks == 0 && [manager.requestedInput.name isEqual:@"device request"], "device creation adapter waits for completion and rejects duplicate submission");
        [manager completeCreation:mode != 0]; if (mode == 2) manager.activeID = @"newer-selection";
        CHECK(Pump(^BOOL { return !view.profileCreationInProgress; }) && view.profileButtonsView.userInteractionEnabled &&
            view.refreshes == (mode == 1 ? 1 : 0) && view.failures == (mode == 0 ? 1 : 0) && view.warnings == (mode == 2 ? 1 : 0) &&
            manager.selectionChecks == (mode == 0 ? 0 : 1), "device creation adapter refreshes only committed current success and reports failure or supersession");
    }
    for (NSUInteger mode = 0; mode < 3; mode++) {
        PXControlledCreationManager *manager = ControlledCreationManager(); PXManualCreateUIFixture *view = [PXManualCreateUIFixture new];
        [view submitManualProfileName:@"manual request" shortDescription:nil]; [view submitManualProfileName:@"duplicate" shortDescription:nil];
        CHECK(manager.requests == 1 && view.manualProfileCreationInProgress && view.shows == 1 && view.hides == 0 && view.refreshes == 0 && view.successes == 0,
            "manual popup adapter submits once and publishes no premature success");
        [manager completeCreation:mode != 0]; if (mode == 2) manager.activeID = @"newer-selection";
        CHECK(Pump(^BOOL { return !view.manualProfileCreationInProgress; }) && view.hides == 1 && view.refreshes == (mode == 1 ? 1 : 0) &&
            view.indicators == (mode == 1 ? 1 : 0) && view.successes == (mode == 1 ? 1 : 0) && view.failures == (mode == 0 ? 1 : 0) &&
            view.warnings == (mode == 2 ? 1 : 0), "manual popup adapter gates active success on completion and current selection without delayed regeneration");
    }
    for (NSUInteger mode = 0; mode < 2; mode++) {
        PXControlledCreationManager *manager = ControlledCreationManager(); PXFormCreateUIFixture *view = [PXFormCreateUIFixture new];
        PXCreationDelegateFixture *delegate = [PXCreationDelegateFixture new]; view.delegate = delegate;
        [view createButtonTapped]; view.nameTextField.text = @"later form edit"; [view textFieldDidChangeSelection:view.nameTextField];
        [view createButtonTapped]; [view cancelButtonTapped];
        CHECK(manager.requests == 1 && view.profileCreationInProgress && !view.createButton.enabled && !view.cancelButton.enabled &&
            view.activityIndicator.starts == 1 && view.dismissals == 0 && delegate.calls == 0, "form pending state survives text changes duplicate submit and cancel attempts");
        [manager completeCreation:mode == 1];
        CHECK(Pump(^BOOL { return !view.profileCreationInProgress; }) && view.createButton.enabled && view.cancelButton.enabled && view.activityIndicator.stops == 1 &&
            delegate.calls == mode && view.dismissals == mode && view.alerts == (mode == 0 ? 1 : 0) && (mode == 0 || [delegate.name isEqual:@"form entry"]),
            "form creation publishes captured name once only on success after restoring controls");
    }
    for (NSUInteger kind = 0; kind < 3; kind++) {
        PXControlledCreationManager *manager = ControlledCreationManager(); __weak id released; NSUInteger events;
        @autoreleasepool {
            if (kind == 0) { PXDeviceCreateUIFixture *view = [PXDeviceCreateUIFixture new]; released = view; [view createDeviceProfileWithName:@"released device" shortDescription:nil]; }
            else if (kind == 1) { PXManualCreateUIFixture *view = [PXManualCreateUIFixture new]; released = view; [view submitManualProfileName:@"released popup" shortDescription:nil]; }
            else { PXFormCreateUIFixture *view = [PXFormCreateUIFixture new]; released = view; [view createButtonTapped]; }
        }
        events = gCreationUIEvents; CHECK(!released && manager.pendingCreation, "pending core creation does not retain controller ownership");
        [manager completeCreation:YES]; __block BOOL drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
        CHECK(Pump(^BOOL { return drained; }) && events == gCreationUIEvents && manager.selectionChecks == 0, "late creation completion skips released UI while producer still completes");
    }
    PXControlledCreationManager *manager = ControlledCreationManager(); PXManualCreateUIFixture *view = [PXManualCreateUIFixture new];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ [view submitManualProfileName:@"background popup" shortDescription:nil]; });
    CHECK(Pump(^BOOL { return manager.requests == 1; }) && view.manualProfileCreationInProgress, "off-main manual create handoff reaches producer on main");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ [manager completeCreation:YES]; });
    CHECK(Pump(^BOOL { return !view.manualProfileCreationInProgress; }) && view.successes == 1, "off-main request and producer callback receive normal main-thread UI acknowledgement");
    gControllerManager = nil;
}
static void TestCurrentProfileCheckpoint(void) {
    PXProfileCreationFixture *manager = NewManager(); CHECK(Reload(manager), "current profile checkpoint loads known state");
    __block BOOL drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; }); CHECK(Pump(^BOOL { return drained; }), "current profile checkpoint drains reload mirror");
    NSDictionary *before = ActiveFiles(), *info = Record(PXCurrentProfileInfoPath()); NSString *profileID = info[@"ProfileId"];
    NSData *archive = [NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")];
    Profile *memory = manager.mutableCurrentProfile; manager.mutableCurrentProfile = New(@"stale UI memory");
    NSUInteger notices = gNotices, mirrors = gMirrors; NSError *error = nil;
    CHECK([manager validateCurrentProfileID:profileID error:&error] && !error && ![manager validateCurrentProfileID:@"not-current" error:&error] && error.code == 20 &&
        ![manager validateCurrentProfileID:nil error:&error] && error.code == 10 && [before isEqual:ActiveFiles()] &&
        [archive isEqual:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")]] && notices == gNotices && mirrors == gMirrors,
        "current profile checkpoint reads committed ID without repairing selection memory archive or defaults");
    manager.mutableCurrentProfile = memory;
    CHECK(ExternalSelectionWrite(@{ @"ProfileId": @"newer-ui-intent" }), "current profile checkpoint newer selection installed");
    NSDictionary *newer = ActiveFiles();
    CHECK(![manager validateCurrentProfileID:profileID error:&error] && error.code == 20 && [newer isEqual:ActiveFiles()], "completion checkpoint preserves newer selection instead of switching back");
    CHECK(ExternalSelectionWrite(info), "current profile checkpoint original target restored explicitly by fixture");
}

@interface PXResetIdentifierFixture : NSObject
@property (nonatomic, strong) NSMutableDictionary *enabled;
@property (nonatomic, strong) NSMutableArray *events;
@property (nonatomic, copy) NSString *failKey;
@property (nonatomic) NSUInteger writes, reads, generations, failWriteOrdinal;
@property (nonatomic) BOOL failGeneration;
@property (nonatomic, strong) NSError *failure;
@property (nonatomic, copy) dispatch_block_t afterToggle, afterGeneration;
- (BOOL)isIdentifierEnabled:(NSString *)identifier;
- (BOOL)setIdentifierEnabledAndPersist:(BOOL)enabled forType:(NSString *)identifier;
- (BOOL)regenerateAllEnabledIdentifiersWithError:(NSError **)error;
- (NSError *)lastError;
- (NSString *)currentValueForIdentifier:(NSString *)identifier;
- (NSString *)profileIdentityPath;
@end
@implementation PXResetIdentifierFixture
- (instancetype)init { if ((self = [super init])) { _enabled = [NSMutableDictionary dictionary]; _events = [NSMutableArray array]; } return self; }
- (BOOL)isIdentifierEnabled:(NSString *)identifier { CHECK(NSThread.isMainThread, "reset enable read on main"); self.reads++; return [self.enabled[identifier] boolValue]; }
- (BOOL)setIdentifierEnabledAndPersist:(BOOL)enabled forType:(NSString *)identifier {
    CHECK(NSThread.isMainThread && enabled, "reset only enables requested identifiers on main");
    self.writes++; [self.events addObject:identifier];
    if ([identifier isEqual:self.failKey] || (self.failWriteOrdinal && self.writes == self.failWriteOrdinal)) return NO;
    self.enabled[identifier] = @(enabled);
    dispatch_block_t callback = self.afterToggle; self.afterToggle = nil; if (callback) callback(); return YES;
}
- (BOOL)regenerateAllEnabledIdentifiersWithError:(NSError **)error {
    CHECK(NSThread.isMainThread, "reset generation on main"); self.generations++; [self.events addObject:@"generation"];
    dispatch_block_t callback = self.afterGeneration; self.afterGeneration = nil; if (callback) callback();
    if (error) *error = self.failGeneration ? self.failure : nil; return !self.failGeneration;
}
- (NSError *)lastError { return self.failure; }
- (NSString *)currentValueForIdentifier:(NSString *)identifier { (void)identifier; return @"iPhone15,4"; }
- (NSString *)profileIdentityPath { return nil; }
@end
@interface PXResetPreparationUIFixture : NSObject
@property (nonatomic, strong) PXResetIdentifierFixture *manager;
@property (nonatomic, strong) NSDictionary *nextFakeOptions, *nextFakePreview;
@property (nonatomic) BOOL failPreview;
@property (nonatomic) NSUInteger previews;
@property (nonatomic, strong) NSDictionary *seenPreview;
@property (nonatomic, copy) dispatch_block_t afterPreview;
- (BOOL)applyFakePreviewToCurrentProfile:(NSDictionary *)preview;
- (BOOL)ensureDashboardFakeOptionsEnableRequiredIdentifiers:(NSDictionary *)options error:(NSError **)error;
- (BOOL)prepareResetProfileWithOptions:(NSDictionary *)options preview:(NSDictionary *)preview error:(NSError **)error;
- (BOOL)prepareResetProfileWithOptions:(NSDictionary *)options preview:(NSDictionary *)preview expectedProfileID:(NSString *)profileID error:(NSError **)error;
- (BOOL)validateDashboardResetProfileID:(NSString *)profileID error:(NSError **)error;
- (NSDictionary *)captureResetIntentWithOptions:(NSDictionary *)options preview:(NSDictionary *)preview error:(NSError **)error;
- (BOOL)discardConsumedResetPreviewForIntent:(NSDictionary *)intent;
@end
#define ProfileManager PXProfileCreationFixture
@implementation PXResetPreparationUIFixture
- (instancetype)init { if ((self = [super init])) _manager = [PXResetIdentifierFixture new]; return self; }
- (BOOL)applyFakePreviewToCurrentProfile:(NSDictionary *)preview {
    CHECK(NSThread.isMainThread, "reset preview on main"); self.previews++; self.seenPreview = preview;
    [self.manager.events addObject:@"preview"];
    dispatch_block_t callback = self.afterPreview; self.afterPreview = nil; if (callback) callback(); return !self.failPreview;
}
#include "PXResetPreparationUI.inc"
@end
#undef ProfileManager
static void TestResetPreparationStatus(void) {
    NSDictionary *preview = @{ @"DeviceModel": @"iPhone15,4" };
    for (NSUInteger bits = 0; bits < 9; bits++) {
        BOOL ios = bits == 8 || (bits & 1), model = bits == 8 || (bits & 2), name = bits != 8 && (bits & 4);
        NSDictionary *options = bits == 8 ? nil : @{ @"fakeIOSVersionEnabled": @(ios), @"fakeModelEnabled": @(model), @"fakeNameEnabled": @(name) };
        PXResetPreparationUIFixture *view = [PXResetPreparationUIFixture new]; NSError *error = [NSError errorWithDomain:@"old" code:9 userInfo:nil];
        NSDictionary *expected = @{ @"IOSVersion": @(ios), @"DeviceModel": @(model), @"StorageSystem": @(model), @"DeviceName": @(name) };
        BOOL prepared = [view prepareResetProfileWithOptions:options preview:preview error:&error];
        BOOL matches = YES; for (NSString *key in expected) if ([view.manager.enabled[key] boolValue] != [expected[key] boolValue]) matches = NO;
        CHECK(prepared && !error && matches && view.manager.writes == (NSUInteger)ios + 2 * (NSUInteger)model + (NSUInteger)name && view.manager.generations == 1 && view.previews == 1,
            "reset required identifier defaults and option matrix preserve enable-only policy");
    }
    NSDictionary *all = @{ @"fakeIOSVersionEnabled": @YES, @"fakeModelEnabled": @YES, @"fakeNameEnabled": @YES };
    NSError *cause = [NSError errorWithDomain:@"fixture.reset" code:91 userInfo:nil];
    for (NSString *key in @[@"IOSVersion", @"DeviceModel", @"StorageSystem", @"DeviceName"]) {
        PXResetPreparationUIFixture *view = [PXResetPreparationUIFixture new]; view.manager.failKey = key; view.manager.failure = cause; NSError *error = nil;
        BOOL prepared = [view prepareResetProfileWithOptions:all preview:preview error:&error];
        CHECK(!prepared && error.code == 1 && error.userInfo[NSUnderlyingErrorKey] == cause && !view.manager.generations && !view.previews &&
            [view.manager.events.lastObject isEqual:key] && !view.manager.enabled[key], "reset stops at each failed required identifier before generation and preview");
    }
    PXResetPreparationUIFixture *view = [PXResetPreparationUIFixture new]; view.manager.failWriteOrdinal = 2; NSError *error = nil;
    CHECK(![view prepareResetProfileWithOptions:all preview:preview error:&error] && error.code == 1 && view.manager.writes == 2 &&
        view.manager.enabled.count == 1 && !view.manager.generations && !view.previews, "reset preserves earlier verified toggles when a later toggle fails");
    for (NSUInteger withError = 0; withError < 2; withError++) {
        view = [PXResetPreparationUIFixture new]; view.manager.failGeneration = YES; view.manager.failure = withError ? cause : nil; error = nil;
        CHECK(![view prepareResetProfileWithOptions:all preview:preview error:&error] && error && (withError ? error == cause : error.code == 2) &&
            view.manager.generations == 1 && !view.previews && view.manager.enabled.count == 4, "reset generation failure never applies preview and always returns an error");
    }
    view = [PXResetPreparationUIFixture new]; view.failPreview = YES; error = nil;
    CHECK(![view prepareResetProfileWithOptions:all preview:preview error:&error] && error.code == 3 && view.manager.generations == 1 && view.previews == 1,
        "reset preview failure is reported after one successful generation");
    view = [PXResetPreparationUIFixture new]; [view.manager.enabled addEntriesFromDictionary:@{ @"IOSVersion": @YES, @"DeviceModel": @YES, @"StorageSystem": @YES, @"DeviceName": @YES, @"IDFA": @YES }]; error = cause;
    NSArray *ordered = @[@"generation", @"preview"];
    CHECK([view prepareResetProfileWithOptions:all preview:preview error:&error] && !error && view.manager.writes == 0 && view.manager.generations == 1 && view.previews == 1 &&
        view.seenPreview == preview && [view.manager.events isEqual:ordered] && [view.manager.enabled[@"IDFA"] boolValue],
        "reset full preparation preserves ordering and skips already enabled identifiers");
    NSDictionary *disabledOptions = @{ @"fakeIOSVersionEnabled": @NO, @"fakeModelEnabled": @NO, @"fakeNameEnabled": @NO };
    NSDictionary *alreadyEnabled = [view.manager.enabled copy];
    CHECK([view prepareResetProfileWithOptions:disabledOptions preview:preview error:NULL] && [alreadyEnabled isEqual:view.manager.enabled] && view.manager.writes == 0,
        "reset disabled fake options never turn off previously enabled identifiers and allow null error output");
    view = [PXResetPreparationUIFixture new]; view.manager.failGeneration = YES;
    CHECK(![view prepareResetProfileWithOptions:all preview:preview error:NULL] && !view.previews,
        "reset preparation failure supports null error output without continuing");
    view = [PXResetPreparationUIFixture new]; __block BOOL rejected = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *threadError = nil; BOOL prepared = [view prepareResetProfileWithOptions:all preview:preview error:&threadError];
        dispatch_async(dispatch_get_main_queue(), ^{ rejected = !prepared && threadError.code == 4; });
    });
    CHECK(Pump(^BOOL { return rejected; }) && !view.manager.reads && !view.manager.writes && !view.manager.generations && !view.previews,
        "off-main reset preparation rejects before providers or persistence");
}

static void TestResetIntentSnapshots(void) {
    PXResetPreparationUIFixture *view = [PXResetPreparationUIFixture new];
    NSMutableString *model = [@"iPhone15,4" mutableCopy], *range = [@"15.0" mutableCopy], *nested = [@"before" mutableCopy];
    NSMutableArray *array = [NSMutableArray arrayWithObject:[NSMutableDictionary dictionaryWithObject:nested forKey:@"label"]];
    NSMutableDictionary *options = [@{ @"fakeIOSVersionEnabled": @"0", @"fakeModelEnabled": @YES, @"modelMinIndex": @"1", @"iosMin": range, @"extra": array } mutableCopy];
    NSMutableDictionary *preview = [@{ @"DeviceModel": model, @"extra": array } mutableCopy];
    NSError *error = [NSError errorWithDomain:@"old" code:1 userInfo:nil];
    NSDictionary *captured = [view captureResetIntentWithOptions:options preview:preview error:&error];
    [model setString:@"later model"]; [range setString:@"18.0"]; [nested setString:@"after"]; [array addObject:@"later item"]; options[@"fakeModelEnabled"] = @NO;
    NSArray *savedArray = captured[@"preview"][@"extra"];
    CHECK(captured && !error && [captured[@"preview"][@"DeviceModel"] isEqual:@"iPhone15,4"] && [captured[@"options"][@"iosMin"] isEqual:@"15.0"] &&
        [captured[@"options"][@"fakeModelEnabled"] boolValue] && [captured[@"options"][@"fakeIOSVersionEnabled"] isEqual:@"0"] &&
        savedArray.count == 1 && [savedArray[0][@"label"] isEqual:@"before"] && [captured[@"options"][@"extra"] isEqual:savedArray],
        "reset request deeply detaches mutable options preview strings and nested containers");
    NSDictionary *empty = [view captureResetIntentWithOptions:nil preview:nil error:&error];
    CHECK(empty && !error && [empty[@"options"] count] == 0 && [empty[@"preview"] count] == 0 && !view.manager.reads && !view.manager.writes && !view.manager.generations && !view.previews,
        "reset nil request keeps defaults and capture has no persistence or provider effects");
    for (NSString *key in @[@"fakeIOSVersionEnabled", @"fakeModelEnabled", @"fakeNameEnabled", @"modelMinIndex", @"modelMaxIndex"]) {
        for (id invalid in @[@[], @{}, NSDate.date, NSData.data]) {
            NSDictionary *bad = @{ key: invalid }; error = nil;
            CHECK(![view captureResetIntentWithOptions:bad preview:nil error:&error] && error,
                "reset malformed option scalars and invalid property lists fail with an error");
        }
    }
    for (id invalid in @[@[], @"wrong root", NSNull.null]) {
        error = nil; CHECK(![view captureResetIntentWithOptions:invalid preview:nil error:&error] && error, "reset wrong options root rejects capture");
        error = nil; CHECK(![view captureResetIntentWithOptions:nil preview:invalid error:&error] && error, "reset wrong preview root rejects capture");
    }
    NSDictionary *notPlist = @{ @"DeviceModel": NSObject.new };
    error = nil; CHECK(![view captureResetIntentWithOptions:nil preview:notPlist error:&error] && error, "reset unsupported preview objects fail before async creation");
    CHECK(![view captureResetIntentWithOptions:nil preview:notPlist error:NULL], "reset invalid capture supports null error output");
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:100]; NSData *data = [@"extra" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *extras = @{ @"date": date, @"data": data };
    NSDictionary *withExtras = [view captureResetIntentWithOptions:extras preview:extras error:NULL];
    CHECK([withExtras[@"options"] isEqual:extras] && [withExtras[@"preview"] isEqual:extras], "reset capture preserves unrecognized property list fields without schema rewriting");
    NSDictionary *baseOptions = @{ @"fakeModelEnabled": @YES }, *basePreview = @{ @"DeviceModel": @"iPhone15,4" };
    NSDictionary *intent = [view captureResetIntentWithOptions:baseOptions preview:basePreview error:NULL];
    view.nextFakeOptions = [baseOptions mutableCopy]; view.nextFakePreview = [basePreview mutableCopy];
    CHECK([view discardConsumedResetPreviewForIntent:intent] && !view.nextFakePreview && [view.nextFakeOptions isEqual:baseOptions],
        "reset consumes only an unchanged options and preview packet");
    for (NSUInteger mode = 0; mode < 4; mode++) {
        NSMutableString *liveModel = [@"iPhone15,4" mutableCopy];
        NSMutableDictionary *liveOptions = [baseOptions mutableCopy], *livePreview = [@{ @"DeviceModel": liveModel } mutableCopy];
        view.nextFakeOptions = liveOptions; view.nextFakePreview = livePreview;
        if (mode == 0) view.nextFakePreview = @{ @"DeviceModel": @"new choice" };
        else if (mode == 1) view.nextFakeOptions = @{ @"fakeModelEnabled": @NO };
        else if (mode == 2) [liveModel setString:@"mutated choice"];
        else liveOptions[@"fakeModelEnabled"] = @NO;
        NSDictionary *newPreview = view.nextFakePreview, *newOptions = view.nextFakeOptions;
        CHECK(![view discardConsumedResetPreviewForIntent:intent] && view.nextFakePreview == newPreview && view.nextFakeOptions == newOptions,
            "reset completion preserves a replaced or mutated newer preview or options");
    }
    view.nextFakeOptions = nil; view.nextFakePreview = nil;
    CHECK([view discardConsumedResetPreviewForIntent:empty] && !view.nextFakePreview && ![view discardConsumedResetPreviewForIntent:nil], "reset nil normalization and missing consumed intent are safe");
    view.nextFakePreview = basePreview;
    CHECK(![view discardConsumedResetPreviewForIntent:empty] && view.nextFakePreview == basePreview, "reset generated preview does not consume a new preview selected after an empty submitted packet");
    view = [PXResetPreparationUIFixture new];
    options = [@{ @"fakeModelEnabled": @YES, @"fakeIOSVersionEnabled": @NO, @"fakeNameEnabled": @NO } mutableCopy];
    NSDictionary *submitted = [view captureResetIntentWithOptions:options preview:nil error:NULL];
    NSMutableString *providerModel = [@"iPhone16,1" mutableCopy];
    NSMutableDictionary *providerPreview = [@{ @"DeviceModel": providerModel } mutableCopy];
    NSDictionary *prepared = [view captureResetIntentWithOptions:submitted[@"options"] preview:providerPreview error:NULL];
    __block BOOL done = NO, preparedOK = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        preparedOK = [view prepareResetProfileWithOptions:prepared[@"options"] preview:prepared[@"preview"] error:NULL]; done = YES;
    });
    options[@"fakeModelEnabled"] = @NO; options[@"fakeIOSVersionEnabled"] = @YES;
    [providerModel setString:@"later provider edit"]; providerPreview[@"DeviceName"] = @"later name";
    BOOL delivered = Pump(^BOOL { return done; });
    CHECK(delivered && preparedOK && [view.seenPreview[@"DeviceModel"] isEqual:@"iPhone16,1"] && !view.seenPreview[@"DeviceName"],
        "reset final provider preview is detached before asynchronous creation");
    CHECK(delivered && [view.manager.enabled[@"DeviceModel"] boolValue] && [view.manager.enabled[@"StorageSystem"] boolValue] && !view.manager.enabled[@"IOSVersion"],
        "reset pending preparation uses the captured options after the caller edits its packet");
    view.nextFakeOptions = baseOptions; view.nextFakePreview = basePreview;
    __block BOOL offMainDone = NO, consumed = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL result = [view discardConsumedResetPreviewForIntent:intent];
        dispatch_async(dispatch_get_main_queue(), ^{ consumed = result; offMainDone = YES; });
    });
    CHECK(Pump(^BOOL { return offMainDone; }) && !consumed && view.nextFakePreview == basePreview,
        "off-main reset preview consumption preserves current pending intent");
}

@interface PXResetRunProfileManager : PXControlledCreationManager
@property (nonatomic) BOOL allocationFails;
@property (nonatomic) NSUInteger switches;
@property (nonatomic, copy) void (^pendingSwitch)(BOOL, NSError *);
@end
@implementation PXResetRunProfileManager
- (NSString *)generateProfileIDWithError:(NSError **)error {
    if (error) *error = self.allocationFails ? [NSError errorWithDomain:@"fixture.allocation" code:9 userInfo:nil] : nil;
    return self.allocationFails ? nil : @"42";
}
- (void)switchToProfile:(Profile *)profile completion:(void (^)(BOOL, NSError *))completion {
    CHECK(NSThread.isMainThread && profile == self.requestedInput, "reset switch uses the created input on main"); self.switches++; self.pendingSwitch = completion;
}
@end
static dispatch_block_t gResetRestart;
static NSUInteger gResetRestartSchedules, gResetFinalNotifications;
static void PXResetWorkflowSchedule(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block) {
    (void)when; CHECK(NSThread.isMainThread && queue == dispatch_get_main_queue(), "reset restart scheduled on main");
    gResetRestartSchedules++; gResetRestart = [block copy];
}
static void PXResetWorkflowNotification(void) { CHECK(NSThread.isMainThread, "reset final notice on main"); gResetFinalNotifications++; }
@interface PXResetRunUIFixture : PXResetPreparationUIFixture
@property (nonatomic, strong) NSObject *dashboardResetToken;
@property (nonatomic, copy) NSString *dashboardResetPhase;
@property (nonatomic, strong) NSDictionary *dashboardResetInputs;
@property (nonatomic, strong) UITextField *rrsNoteTextField;
@property (nonatomic, copy) NSArray *lastScopeApps, *lastBackupApps, *lastClearApps;
@property (nonatomic, copy) NSString *lastDashboardMessage;
@property (nonatomic, copy) dispatch_block_t afterPersist;
@property (nonatomic, strong) NSArray *selectedRRSAppIDs, *selectedResetAppIDs;
@property (nonatomic) NSUInteger backups, clears, filters, shows, hides, errors, messages, successes, persists, refreshes, restarts;
@property (nonatomic) BOOL filterFails, throwRestart;
@property (nonatomic) NSUInteger previewMode;
@property (nonatomic, copy) void (^backupCompletion)(NSArray *, NSUInteger);
@property (nonatomic, copy) void (^clearCompletion)(NSArray *);
- (NSObject *)beginDashboardResetInPhase:(NSString *)phase;
- (BOOL)advanceDashboardReset:(NSObject *)token fromPhase:(NSString *)phase toPhase:(NSString *)nextPhase;
- (BOOL)finishDashboardReset:(NSObject *)token;
- (void)saveRRSThenResetTapped; - (void)resetDataTapped;
- (void)performResetAndPrepareNextProfileWithWarnings:(NSArray<NSString *> *)warnings;
- (void)createNextProfileAndRandomizeWithWarnings:(NSArray<NSString *> *)warnings;
- (void)showProgressHUDWithTitle:(NSString *)title; - (void)hideProgressHUD;
- (void)showError:(NSError *)error; - (void)showDashboardMessage:(NSString *)title message:(NSString *)message;
- (BOOL)syncHookScopeToResetApps;
- (BOOL)syncHookScopeToResetAppIDs:(NSArray<NSString *> *)bundleIDs waitingForDaemon:(BOOL)waitForDaemon;
- (NSArray<NSString *> *)captureDashboardAppIDs:(NSArray<NSString *> *)apps error:(NSError **)error;
- (NSDictionary *)captureDashboardResetInputsForBackup:(BOOL)backup error:(NSError **)error;
- (void)backupApps:(NSArray<NSString *> *)apps index:(NSUInteger)index savedCount:(NSUInteger)saved warnings:(NSMutableArray<NSString *> *)warnings completion:(void (^)(NSArray<NSString *> *, NSUInteger))completion;
- (void)clearApps:(NSArray<NSString *> *)apps index:(NSUInteger)index warnings:(NSMutableArray<NSString *> *)warnings completion:(void (^)(NSArray<NSString *> *))completion;
- (void)backupApps:(NSArray<NSString *> *)apps index:(NSUInteger)index savedCount:(NSUInteger)saved warnings:(NSMutableArray<NSString *> *)warnings resetToken:(NSObject *)token completion:(void (^)(NSArray<NSString *> *, NSUInteger))completion;
- (void)clearApps:(NSArray<NSString *> *)apps index:(NSUInteger)index warnings:(NSMutableArray<NSString *> *)warnings resetToken:(NSObject *)token completion:(void (^)(NSArray<NSString *> *))completion;
- (NSDictionary *)generateFakePreviewFromOptions:(NSDictionary *)options;
- (void)persistDashboardSelections; - (void)refreshDashboardSelectionLabels; - (void)killEnabledAppsAndRespring;
@end
#define ProfileManager PXProfileCreationFixture
#define dispatch_after PXResetWorkflowSchedule
#define CFNotificationCenterPostNotification(...) PXResetWorkflowNotification()
@implementation PXResetRunUIFixture
- (instancetype)init {
    if ((self = [super init])) { _selectedRRSAppIDs = @[@"test.rrs"]; _selectedResetAppIDs = @[@"test.reset"];
        _rrsNoteTextField = [UITextField new]; _rrsNoteTextField.text = @"";
        self.nextFakeOptions = @{ @"fakeModelEnabled": @YES, @"fakeIOSVersionEnabled": @YES };
        self.nextFakePreview = [self generateFakePreviewFromOptions:self.nextFakeOptions]; }
    return self;
}
- (void)showProgressHUDWithTitle:(NSString *)title { (void)title; CreationUIEvent(); self.shows++; }
- (void)hideProgressHUD { CreationUIEvent(); self.hides++; }
- (void)showError:(NSError *)error { CreationUIEvent(); CHECK(error != nil, "reset failure presents an error"); self.errors++; }
- (void)showDashboardMessage:(NSString *)title message:(NSString *)message { self.lastDashboardMessage = message; CreationUIEvent(); if ([title isEqual:@"Hoàn tất"]) self.successes++; else self.messages++; }
- (BOOL)syncHookScopeToResetApps { CreationUIEvent(); self.filters++; return !self.filterFails; }
- (BOOL)syncHookScopeToResetAppIDs:(NSArray<NSString *> *)bundleIDs waitingForDaemon:(BOOL)waitForDaemon {
    CHECK(waitForDaemon, "reset waits for the selected injection filter"); self.lastScopeApps = bundleIDs; return [self syncHookScopeToResetApps];
}
- (void)backupApps:(NSArray<NSString *> *)apps index:(NSUInteger)index savedCount:(NSUInteger)saved warnings:(NSMutableArray<NSString *> *)warnings completion:(void (^)(NSArray<NSString *> *, NSUInteger))completion {
    (void)index; (void)saved; (void)warnings; CreationUIEvent(); self.lastBackupApps = apps; self.backups++; self.backupCompletion = completion;
}
- (void)clearApps:(NSArray<NSString *> *)apps index:(NSUInteger)index warnings:(NSMutableArray<NSString *> *)warnings completion:(void (^)(NSArray<NSString *> *))completion {
    (void)index; (void)warnings; CreationUIEvent(); self.lastClearApps = apps; self.clears++; self.clearCompletion = completion;
}
- (NSDictionary *)generateFakePreviewFromOptions:(NSDictionary *)options {
    (void)options;
    if (self.previewMode == 1) return nil;
    if (self.previewMode == 2) return @{ @"DeviceModel": NSObject.new };
    return @{ @"DeviceModel": @"iPhone15,4", @"IOSVersion": @"16.0", @"IOSProductType": @"iPhone15,4" };
}
- (void)backupApps:(NSArray<NSString *> *)apps index:(NSUInteger)index savedCount:(NSUInteger)saved warnings:(NSMutableArray<NSString *> *)warnings resetToken:(NSObject *)token completion:(void (^)(NSArray<NSString *> *, NSUInteger))completion {
    (void)token; [self backupApps:apps index:index savedCount:saved warnings:warnings completion:completion];
}
- (void)clearApps:(NSArray<NSString *> *)apps index:(NSUInteger)index warnings:(NSMutableArray<NSString *> *)warnings resetToken:(NSObject *)token completion:(void (^)(NSArray<NSString *> *))completion {
    (void)token; [self clearApps:apps index:index warnings:warnings completion:completion];
}
- (void)persistDashboardSelections { CreationUIEvent(); self.persists++; dispatch_block_t callback = self.afterPersist; self.afterPersist = nil; if (callback) callback(); }
- (void)refreshDashboardSelectionLabels { CreationUIEvent(); self.refreshes++; }
- (void)killEnabledAppsAndRespring { CreationUIEvent(); self.restarts++; if (self.throwRestart) [NSException raise:@"fixture.restart" format:@"restart failed"]; }
#include "PXResetInputsUI.inc"
#include "PXResetWorkflowUI.inc"
@end
#undef CFNotificationCenterPostNotification
#undef dispatch_after
#undef ProfileManager
static PXResetRunProfileManager *ResetRunManager(void) {
    gResetRestart = nil; gResetRestartSchedules = gResetFinalNotifications = 0;
    PXResetRunProfileManager *manager = [PXResetRunProfileManager new]; manager.activeID = @"controller-target"; gControllerManager = manager; return manager;
}
static void ResetRunRelease(PXResetRunUIFixture *view, PXResetRunProfileManager *manager) {
    view.backupCompletion = nil; view.clearCompletion = nil; manager.pendingCreation = nil; manager.pendingSwitch = nil;
    gResetRestart = nil; gControllerManager = nil;
}
static void DrainResetUI(void) {
    __block BOOL done = NO; dispatch_async(dispatch_get_main_queue(), ^{ done = YES; }); CHECK(Pump(^BOOL { return done; }), "reset UI callbacks drain");
}
static void TestResetRunAdmission(void) {
    PXResetRunProfileManager *manager = ResetRunManager(); PXResetRunUIFixture *view = [PXResetRunUIFixture new];
    [view resetDataTapped]; NSObject *token = view.dashboardResetToken;
    [view resetDataTapped]; [view saveRRSThenResetTapped];
    CHECK(token && [view.dashboardResetPhase isEqual:@"clearing"] && view.shows == 1 && view.clears == 1 && !view.backups,
        "reset admission excludes both buttons before clear through scheduled restart");
    void (^cleared)(NSArray *) = view.clearCompletion;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ cleared(@[]); cleared(@[]); });
    CHECK(Pump(^BOOL { return manager.requests == 1; }), "reset clear completion reaches one create");
    void (^created)(BOOL, NSError *) = manager.pendingCreation;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ created(YES, nil); created(YES, nil); });
    CHECK(Pump(^BOOL { return manager.switches == 1; }), "reset create completion reaches one switch");
    void (^switched)(BOOL, NSError *) = manager.pendingSwitch;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ switched(YES, nil); switched(YES, nil); });
    CHECK(Pump(^BOOL { return gResetRestartSchedules == 1; }) && view.manager.generations == 1 && view.previews == 1 && gResetFinalNotifications == 1 && view.successes == 1 && view.persists == 1,
        "duplicate phase callbacks produce one create switch apply notification and restart");
    [view resetDataTapped]; [view saveRRSThenResetTapped];
    CHECK(view.clears == 1 && view.dashboardResetToken == token && [view.dashboardResetPhase isEqual:@"restart"], "reset keeps admission while waiting for restart");
    dispatch_block_t restarted = gResetRestart; restarted(); restarted();
    CHECK(view.restarts == 1 && !view.dashboardResetToken, "reset restart executes once and releases admission when it returns");
    [view resetDataTapped]; NSObject *newToken = view.dashboardResetToken;
    cleared(@[]); created(YES, nil); switched(YES, nil); restarted(); DrainResetUI();
    CHECK(newToken && newToken != token && view.dashboardResetToken == newToken && manager.requests == 1 && manager.switches == 1 && view.restarts == 1 && view.clears == 2,
        "old reset callbacks and delayed restart cannot affect a newer run");
    CHECK(![view finishDashboardReset:token] && view.dashboardResetToken == newToken && [view finishDashboardReset:newToken], "stale reset finish never clears the newer token");
    ResetRunRelease(view, manager);
    for (NSUInteger mode = 0; mode < 8; mode++) {
        manager = ResetRunManager(); view = [PXResetRunUIFixture new];
        if (mode == 0) view.nextFakeOptions = @{ @"fakeModelEnabled": @[] };
        if (mode == 1 || mode == 2) { view.nextFakePreview = nil; view.previewMode = mode; }
        if (mode == 3) manager.allocationFails = YES;
        if (mode == 6) view.manager.failGeneration = YES;
        if (mode == 7) view.failPreview = YES;
        [view resetDataTapped]; view.clearCompletion(@[]);
        CHECK(Pump(^BOOL { return !view.dashboardResetToken || manager.requests; }), "reset failure matrix reaches create or terminal preflight");
        NSError *failure = [NSError errorWithDomain:@"fixture.reset.phase" code:9 userInfo:nil];
        if (mode >= 4) {
            manager.pendingCreation(mode != 4, mode == 4 ? failure : nil);
            CHECK(Pump(^BOOL { return !view.dashboardResetToken || manager.switches; }), "reset failure matrix reaches switch or terminal create");
        }
        if (mode >= 5) manager.pendingSwitch(mode != 5, mode == 5 ? failure : nil);
        CHECK(Pump(^BOOL { return !view.dashboardResetToken; }) && view.errors + view.messages == 1 && !view.successes && !gResetRestartSchedules && !gResetFinalNotifications && !view.persists,
            "reset terminal preparation failures release admission and skip success tail");
        [view resetDataTapped]; CHECK(view.dashboardResetToken && view.clears == 2, "reset can be retried explicitly after terminal failure");
        [view finishDashboardReset:view.dashboardResetToken]; ResetRunRelease(view, manager);
    }
    manager = ResetRunManager(); view = [PXResetRunUIFixture new]; view.selectedRRSAppIDs = @[]; [view saveRRSThenResetTapped];
    CHECK(!view.dashboardResetToken && !view.backups && !view.shows, "missing RRS selection never admits a reset");
    view.selectedRRSAppIDs = @[@"test.rrs"]; [view saveRRSThenResetTapped]; void (^backed)(NSArray *, NSUInteger) = view.backupCompletion;
    backed(@[], 0); CHECK(Pump(^BOOL { return !view.dashboardResetToken; }) && !view.clears, "backup failure and missing selections release reset admission without clearing");
    view.selectedResetAppIDs = @[]; [view resetDataTapped]; CHECK(!view.dashboardResetToken && !view.clears, "missing clear selection releases reset admission");
    view.selectedResetAppIDs = @[@"test.reset"]; [view saveRRSThenResetTapped]; view.filterFails = YES;
    void (^backupOK)(NSArray *, NSUInteger) = view.backupCompletion; backupOK(@[], 1); backupOK(@[], 1);
    CHECK(Pump(^BOOL { return !view.dashboardResetToken; }) && view.filters == 1 && !view.clears, "backup success advances once and filter failure permits a later reset");
    view.filterFails = NO; [view resetDataTapped]; NSObject *retry = view.dashboardResetToken; backed(@[], 1); DrainResetUI();
    CHECK(view.dashboardResetToken == retry && view.clears == 1, "late backup completion cannot advance a newer clear run");
    [view finishDashboardReset:retry]; ResetRunRelease(view, manager);
    manager = ResetRunManager(); view = [PXResetRunUIFixture new]; [view resetDataTapped]; view.clearCompletion(@[]);
    CHECK(Pump(^BOOL { return manager.requests == 1; }), "restart exception case creates"); manager.pendingCreation(YES, nil);
    CHECK(Pump(^BOOL { return manager.switches == 1; }), "restart exception case switches"); manager.pendingSwitch(YES, nil);
    CHECK(Pump(^BOOL { return gResetRestartSchedules == 1; }), "restart exception case schedules");
    view.throwRestart = YES; BOOL threw = NO; @try { gResetRestart(); } @catch (NSException *exception) { (void)exception; threw = YES; }
    CHECK(threw && !view.dashboardResetToken && view.restarts == 1, "restart exception releases only its own reset token"); ResetRunRelease(view, manager);
    manager = ResetRunManager(); view = [PXResetRunUIFixture new]; __block BOOL submitted = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [view resetDataTapped]; [view saveRRSThenResetTapped]; dispatch_async(dispatch_get_main_queue(), ^{ submitted = YES; });
    });
    CHECK(Pump(^BOOL { return submitted; }) && view.dashboardResetToken && view.clears == 1 && !view.backups && view.shows == 1,
        "off-main reset entries admit one run and keep UI effects on main");
    [view finishDashboardReset:view.dashboardResetToken]; ResetRunRelease(view, manager);
}

@implementation PXBackupResult
@end
static PXBackupResult *BatchBackupResult(NSString *bundleID) {
    PXBackupResult *result = [PXBackupResult new]; result.backupDirectory = [@"fixture-backup/" stringByAppendingString:bundleID]; result.warnings = @[]; return result;
}
@interface PXBatchBackupProducer : NSObject
@property (nonatomic, strong) NSMutableArray *requests, *callbacks;
@property (nonatomic) BOOL synchronous;
@property (nonatomic) NSUInteger depth, maxDepth;
+ (instancetype)shared;
- (void)createBackupForBundleID:(NSString *)bundleID appName:(NSString *)name options:(PXBackupOptions)options completion:(void (^)(PXBackupResult *, NSError *))completion;
@end
@interface PXBatchClearProducer : NSObject
@property (nonatomic, strong) NSMutableArray *requests, *callbacks;
@property (nonatomic) BOOL synchronous;
@property (nonatomic) NSUInteger depth, maxDepth;
+ (instancetype)sharedManager;
- (void)clearDataForBundleID:(NSString *)bundleID completion:(void (^)(BOOL, NSError *))completion;
@end
static PXBatchBackupProducer *gBatchBackup;
static PXBatchClearProducer *gBatchClear;
@implementation PXBatchBackupProducer
+ (instancetype)shared { return gBatchBackup; }
- (instancetype)init { if ((self = [super init])) { _requests = [NSMutableArray array]; _callbacks = [NSMutableArray array]; } return self; }
- (void)createBackupForBundleID:(NSString *)bundleID appName:(NSString *)name options:(PXBackupOptions)options completion:(void (^)(PXBackupResult *, NSError *))completion {
    CHECK(NSThread.isMainThread && name.length && options == (PXBackupOptionIncludeAppGroups | PXBackupOptionIncludePreferences), "backup batch submits legacy options on main");
    [self.requests addObject:bundleID]; [self.callbacks addObject:[completion copy]];
    if (self.synchronous) { self.depth++; self.maxDepth = MAX(self.maxDepth, self.depth); completion(BatchBackupResult(bundleID), nil); completion(nil, nil); self.depth--; }
}
@end
@implementation PXBatchClearProducer
+ (instancetype)sharedManager { return gBatchClear; }
- (instancetype)init { if ((self = [super init])) { _requests = [NSMutableArray array]; _callbacks = [NSMutableArray array]; } return self; }
- (void)clearDataForBundleID:(NSString *)bundleID completion:(void (^)(BOOL, NSError *))completion {
    CHECK(NSThread.isMainThread, "clear batch submits on main"); [self.requests addObject:bundleID]; [self.callbacks addObject:[completion copy]];
    if (self.synchronous) { self.depth++; self.maxDepth = MAX(self.maxDepth, self.depth); completion(YES, nil); completion(NO, nil); self.depth--; }
}
@end
@interface PXResetBatchUIFixture : PXResetRunUIFixture
@property (nonatomic) NSUInteger metadataWrites, progressUpdates;
@property (nonatomic) BOOL metadataFails;
@property (nonatomic, strong) NSMutableArray *notes;
- (BOOL)isDashboardReset:(NSObject *)token inPhase:(NSString *)phase;
- (NSString *)displayNameForBundleID:(NSString *)bundleID;
- (void)updateProgress:(float)progress detail:(NSString *)detail;
- (BOOL)updateRRSMetadataAtBackupDirectory:(NSString *)directory bundleID:(NSString *)bundleID appName:(NSString *)name note:(NSString *)note;
@end
#define AppDataBackupManager PXBatchBackupProducer
#define AppDataCleaner PXBatchClearProducer
@implementation PXResetBatchUIFixture
- (instancetype)init { if ((self = [super init])) { self.rrsNoteTextField.text = @"note"; _notes = [NSMutableArray array]; } return self; }
- (NSString *)displayNameForBundleID:(NSString *)bundleID { CreationUIEvent(); return bundleID; }
- (void)updateProgress:(float)progress detail:(NSString *)detail { (void)progress; (void)detail; CreationUIEvent(); self.progressUpdates++; }
- (BOOL)updateRRSMetadataAtBackupDirectory:(NSString *)directory bundleID:(NSString *)bundleID appName:(NSString *)name note:(NSString *)note {
    (void)directory; (void)bundleID; (void)name; CreationUIEvent(); self.metadataWrites++; [self.notes addObject:note]; return !self.metadataFails;
}
#include "PXResetBatchUI.inc"
@end
#undef AppDataCleaner
#undef AppDataBackupManager
static PXResetBatchUIFixture *NewBatchUI(void) {
    gBatchBackup = [PXBatchBackupProducer new]; gBatchClear = [PXBatchClearProducer new]; return [PXResetBatchUIFixture new];
}
static void TestResetPerAppCallbacks(void) {
    PXResetBatchUIFixture *view = NewBatchUI(); NSArray *apps = @[@"app.A", @"app.B"]; NSMutableArray *warnings = [NSMutableArray array];
    __block NSUInteger completions = 0, saved = 0;
    [view backupApps:apps index:0 savedCount:0 warnings:warnings completion:^(NSArray *result, NSUInteger count) { CHECK(NSThread.isMainThread && result == warnings, "backup terminal callback preserves warning accumulator on main"); completions++; saved = count; }];
    void (^firstBackup)(PXBackupResult *, NSError *) = gBatchBackup.callbacks[0];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ firstBackup(BatchBackupResult(@"app.A"), nil); firstBackup(nil, nil); });
    CHECK(Pump(^BOOL { return gBatchBackup.requests.count == 2; }) && view.metadataWrites == 1 && !completions && !warnings.count,
        "backup per-app callbacks advance once with one metadata write on main");
    view.metadataFails = YES; view.rrsNoteTextField.text = @"later note";
    PXBackupResult *result = BatchBackupResult(@"app.B"); result.warnings = @[@"provider warning"];
    void (^secondBackup)(PXBackupResult *, NSError *) = gBatchBackup.callbacks[1]; secondBackup(result, nil); secondBackup(result, nil);
    CHECK(Pump(^BOOL { return completions == 1; }) && saved == 1 && view.metadataWrites == 2 && warnings.count == 2 && [view.notes.lastObject isEqual:@"later note"] && view.progressUpdates == 2,
        "backup batch keeps metadata success count provider warnings and live note policy");
    firstBackup(result, nil); secondBackup(result, nil); DrainResetUI(); CHECK(completions == 1 && view.metadataWrites == 2, "replayed backup callbacks cannot repeat terminal or metadata effects");
    view = NewBatchUI(); warnings = [NSMutableArray array]; completions = 0;
    [view clearApps:apps index:0 warnings:warnings completion:^(NSArray *allWarnings) { CHECK(NSThread.isMainThread && allWarnings == warnings, "clear terminal on main preserves accumulator"); completions++; }];
    void (^firstClear)(BOOL, NSError *) = gBatchClear.callbacks[0];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ firstClear(NO, nil); firstClear(YES, nil); });
    CHECK(Pump(^BOOL { return gBatchClear.requests.count == 2; }) && warnings.count == 1 && !completions && view.progressUpdates == 2,
        "clear per-app callbacks append one failure and advance once on main");
    void (^secondClear)(BOOL, NSError *) = gBatchClear.callbacks[1]; secondClear(YES, nil); secondClear(NO, nil);
    CHECK(Pump(^BOOL { return completions == 1; }) && warnings.count == 1 && gBatchClear.requests.count == 2, "clear continues after a failed app and completes once after the full list");
    firstClear(NO, nil); secondClear(NO, nil); DrainResetUI(); CHECK(completions == 1 && warnings.count == 1, "replayed clear callbacks have no late warning or terminal effects");
    for (NSUInteger backup = 0; backup < 2; backup++) {
        view = NewBatchUI(); warnings = [NSMutableArray array]; completions = 0;
        NSString *phase = backup ? @"backup" : @"clearing"; NSObject *token = [view beginDashboardResetInPhase:phase];
        if (backup) [view backupApps:apps index:0 savedCount:0 warnings:warnings resetToken:token completion:^(NSArray *w, NSUInteger count) { (void)w; (void)count; completions++; }];
        else [view clearApps:apps index:0 warnings:warnings resetToken:token completion:^(NSArray *w) { (void)w; completions++; }];
        [view finishDashboardReset:token]; NSObject *newToken = [view beginDashboardResetInPhase:phase];
        if (backup) { void (^callback)(PXBackupResult *, NSError *) = gBatchBackup.callbacks[0]; callback(BatchBackupResult(@"app.A"), nil); }
        else { void (^callback)(BOOL, NSError *) = gBatchClear.callbacks[0]; callback(NO, nil); }
        DrainResetUI();
        CHECK(!view.metadataWrites && !warnings.count && !completions && gBatchBackup.requests.count + gBatchClear.requests.count == 1 && view.dashboardResetToken == newToken,
            "retired reset batches ignore metadata warnings and remaining app submissions");
        [view advanceDashboardReset:newToken fromPhase:phase toPhase:@"apply"];
        [view backupApps:apps index:0 savedCount:0 warnings:warnings resetToken:newToken completion:nil];
        [view clearApps:apps index:0 warnings:warnings resetToken:newToken completion:nil];
        CHECK(gBatchBackup.requests.count + gBatchClear.requests.count == 1, "wrong-phase reset batches submit no service requests");
        [view finishDashboardReset:newToken];
    }
    view = NewBatchUI(); NSObject *unrelated = [view beginDashboardResetInPhase:@"clearing"]; gBatchBackup.synchronous = YES; gBatchClear.synchronous = YES;
    NSMutableArray *many = [NSMutableArray array]; for (NSUInteger i = 0; i < 64; i++) [many addObject:[NSString stringWithFormat:@"app.%lu", (unsigned long)i]];
    warnings = [NSMutableArray array]; completions = 0; saved = 0;
    [view backupApps:many index:0 savedCount:0 warnings:warnings completion:^(NSArray *w, NSUInteger count) { (void)w; saved = count; completions++; }];
    CHECK(Pump(^BOOL { return completions == 1; }) && saved == many.count && view.dashboardResetToken == unrelated && view.metadataWrites == many.count,
        "generic backup keeps nil-token behavior during an unrelated reset");
    [view clearApps:many index:0 warnings:warnings completion:^(NSArray *w) { (void)w; completions++; }];
    CHECK(Pump(^BOOL { return completions == 2; }) && gBatchBackup.maxDepth == 1 && gBatchClear.maxDepth == 1 && gBatchBackup.requests.count == many.count && gBatchClear.requests.count == many.count && !warnings.count,
        "synchronous duplicate service results stay sequential without recursive stack growth");
    [view finishDashboardReset:unrelated];
    for (NSUInteger mode = 0; mode < 4; mode++) {
        view = NewBatchUI(); warnings = [NSMutableArray array]; completions = 0; saved = 99;
        [view backupApps:@[@"app.A"] index:0 savedCount:0 warnings:warnings completion:^(NSArray *w, NSUInteger count) { (void)w; completions++; saved = count; }];
        PXBackupResult *backupResult = mode < 2 ? nil : BatchBackupResult(@"app.A");
        if (mode == 2) backupResult.backupDirectory = @"";
        if (mode == 3) view.metadataFails = YES;
        NSError *failure = mode == 0 ? [NSError errorWithDomain:@"fixture.backup" code:9 userInfo:nil] : nil;
        void (^callback)(PXBackupResult *, NSError *) = gBatchBackup.callbacks[0]; callback(backupResult, failure);
        CHECK(Pump(^BOOL { return completions == 1; }) && saved == 0 && warnings.count == 1, "backup error nil result missing directory and metadata failure keep unsuccessful saved count");
    }
    view = NewBatchUI(); completions = 0; saved = 0;
    [view backupApps:apps index:apps.count savedCount:5 warnings:[NSMutableArray array] completion:^(NSArray *w, NSUInteger count) { (void)w; completions++; saved = count; }];
    [view clearApps:@[] index:0 warnings:[NSMutableArray array] completion:^(NSArray *w) { (void)w; completions++; }];
    [view backupApps:@[] index:0 savedCount:0 warnings:[NSMutableArray array] completion:nil]; [view clearApps:@[] index:0 warnings:[NSMutableArray array] completion:nil];
    CHECK(completions == 2 && saved == 5 && !gBatchBackup.requests.count && !gBatchClear.requests.count, "batch empty suffix and null completion preserve terminal behavior");
    gBatchClear.synchronous = YES; __block BOOL handedOff = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [view clearApps:@[@"app.A"] index:0 warnings:[NSMutableArray array] completion:^(NSArray *w) {
            (void)w; CHECK(NSThread.isMainThread, "off-main batch entry delivers completion on main"); handedOff = YES;
        }];
    });
    CHECK(Pump(^BOOL { return handedOff; }) && gBatchClear.requests.count == 1, "off-main batch entry reaches one main-thread service submission");
    gBatchBackup = nil; gBatchClear = nil;
}

static void TestResetAdmittedInputs(void) {
    PXResetRunProfileManager *manager = ResetRunManager(); PXResetRunUIFixture *view = [PXResetRunUIFixture new];
    NSMutableString *appID = [@"app.reset.A" mutableCopy], *backupID = [@"app.backup.A" mutableCopy];
    NSMutableArray *resetApps = [NSMutableArray arrayWithObjects:appID, @"com.apple.mobilemail", appID, nil];
    NSMutableArray *backupApps = [NSMutableArray arrayWithObject:backupID];
    view.selectedResetAppIDs = resetApps; view.selectedRRSAppIDs = backupApps; view.rrsNoteTextField.text = @"submitted note";
    [view saveRRSThenResetTapped]; NSObject *token = view.dashboardResetToken;
    NSArray *expected = @[@"app.reset.A", @"com.apple.mobilemail", @"app.reset.A"];
    [appID setString:@"edited ID"]; [backupID setString:@"edited backup"]; [resetApps removeAllObjects]; [backupApps removeAllObjects];
    NSArray *newReset = @[@"app.new.choice"], *newBackup = @[@"app.new.backup"];
    view.selectedResetAppIDs = newReset; view.selectedRRSAppIDs = newBackup; view.rrsNoteTextField.text = @"new note";
    CHECK(token && [view.dashboardResetInputs[@"resetApps"] isEqual:expected] && [view.lastBackupApps.firstObject isEqual:@"app.backup.A"] && [view.dashboardResetInputs[@"note"] isEqual:@"submitted note"],
        "reset admission captures app order duplicates and mutable strings without editing live choices");
    view.backupCompletion(@[], 1);
    CHECK(Pump(^BOOL { return view.clears == 1; }) && [view.lastScopeApps isEqual:expected] && [view.lastClearApps isEqual:expected] && view.selectedResetAppIDs == newReset && view.selectedRRSAppIDs == newBackup,
        "reset scope and clear use the admitted list after backup while newer choices survive");
    [view finishDashboardReset:token]; CHECK(!view.dashboardResetInputs, "terminal reset releases captured app lists and note"); ResetRunRelease(view, manager);
    NSArray *invalidLists = @[@"wrong root", @{}, NSNull.null, @[@1], @[@""], @[@"valid", @[]]];
    for (id invalid in invalidLists) {
        view = [PXResetRunUIFixture new]; view.selectedResetAppIDs = invalid; [view resetDataTapped];
        CHECK(!view.dashboardResetToken && !view.dashboardResetInputs && view.errors == 1 && !view.shows && !view.filters && !view.clears && !view.backups,
            "invalid app selections fail before admission HUD filter or service effects");
        view = [PXResetRunUIFixture new]; view.selectedRRSAppIDs = invalid; [view saveRRSThenResetTapped];
        CHECK(!view.dashboardResetToken && view.errors == 1 && !view.shows && !view.backups && !view.clears, "invalid backup list never starts save-before-reset services");
    }
    view = [PXResetRunUIFixture new]; view.rrsNoteTextField.text = (id)@42; [view saveRRSThenResetTapped];
    CHECK(!view.dashboardResetToken && view.errors == 1 && !view.backups, "invalid backup note reports failure before admission");
    view.selectedRRSAppIDs = (id)@"unused malformed RRS"; [view resetDataTapped]; token = view.dashboardResetToken;
    CHECK(token && view.clears == 1 && ![view.dashboardResetInputs[@"backupApps"] count] && [view.dashboardResetInputs[@"note"] isEqual:@""],
        "direct reset ignores unused malformed RRS input and matching finish releases its snapshot");
    [view finishDashboardReset:token]; NSObject *nextToken = [view beginDashboardResetInPhase:@"clear"]; NSDictionary *nextInputs = view.dashboardResetInputs;
    CHECK(![view finishDashboardReset:token] && view.dashboardResetInputs == nextInputs && [view finishDashboardReset:nextToken] && !view.dashboardResetInputs, "stale finish preserves the newer reset input packet");
    ResetRunRelease(view, nil);
    view = [PXResetRunUIFixture new]; view.selectedResetAppIDs = nil; view.selectedRRSAppIDs = nil; view.rrsNoteTextField.text = nil;
    NSError *error = [NSError errorWithDomain:@"old" code:1 userInfo:nil]; NSDictionary *empty = [view captureDashboardResetInputsForBackup:YES error:&error];
    CHECK(empty && !error && ![empty[@"resetApps"] count] && ![empty[@"backupApps"] count] && [empty[@"note"] isEqual:@""], "nil reset inputs preserve existing empty selection and note defaults");
    CHECK(![view captureDashboardAppIDs:(id)@42 error:NULL], "invalid captured app list supports null error output");
    PXResetBatchUIFixture *batch = NewBatchUI(); batch.selectedRRSAppIDs = @[@"app.A", @"app.B"]; batch.rrsNoteTextField.text = @"fixed reset note";
    token = [batch beginDashboardResetInPhase:@"backup"]; __block BOOL done = NO;
    [batch backupApps:batch.dashboardResetInputs[@"backupApps"] index:0 savedCount:0 warnings:[NSMutableArray array] resetToken:token completion:^(NSArray *w, NSUInteger count) { (void)w; done = count == 2; }];
    batch.rrsNoteTextField.text = @"edited while running";
    void (^first)(PXBackupResult *, NSError *) = gBatchBackup.callbacks[0]; first(BatchBackupResult(@"app.A"), nil);
    CHECK(Pump(^BOOL { return gBatchBackup.requests.count == 2; }), "captured-note batch reaches second app");
    void (^second)(PXBackupResult *, NSError *) = gBatchBackup.callbacks[1]; second(BatchBackupResult(@"app.B"), nil);
    NSArray *fixedNotes = @[@"fixed reset note", @"fixed reset note"];
    CHECK(Pump(^BOOL { return done; }) && [batch.notes isEqual:fixedNotes] && [batch.rrsNoteTextField.text isEqual:@"edited while running"], "reset backup metadata uses the admitted note after UI text changes");
    [batch finishDashboardReset:token]; gBatchBackup = nil; gBatchClear = nil;
    view = [PXResetRunUIFixture new]; __block BOOL rejected = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *failure = nil; NSDictionary *packet = [view captureDashboardResetInputsForBackup:YES error:&failure];
        dispatch_async(dispatch_get_main_queue(), ^{ rejected = !packet && failure.code == 4; });
    });
    CHECK(Pump(^BOOL { return rejected; }) && !view.dashboardResetToken && !view.errors && !view.shows, "off-main input capture fails without reading mutable UI state");
}

static void TestResetSelectionCheckpoints(void) {
    for (NSUInteger mode = 0; mode < 7; mode++) {
        PXResetRunProfileManager *manager = ResetRunManager(); PXResetRunUIFixture *view = [PXResetRunUIFixture new];
        [view resetDataTapped]; view.clearCompletion(@[]);
        CHECK(Pump(^BOOL { return manager.requests == 1; }), "reset selection fixture reaches pending create");
        if (mode == 0) manager.activeID = @"newer-profile";
        manager.pendingCreation(YES, nil);
        if (mode == 0) {
            CHECK(Pump(^BOOL { return !view.dashboardResetToken; }) && !manager.switches && !view.manager.writes && !view.manager.generations && !view.previews && view.errors == 1 && [manager.activeID isEqual:@"newer-profile"],
                "reset selection change after create never switches back to the old request");
            ResetRunRelease(view, manager); continue;
        }
        CHECK(Pump(^BOOL { return manager.switches == 1; }), "reset selection fixture reaches pending switch");
        if (mode == 1) manager.activeID = @"newer-profile";
        if (mode == 2) view.manager.afterToggle = ^{ manager.activeID = @"newer-profile"; };
        if (mode == 3) view.manager.afterGeneration = ^{ manager.activeID = @"newer-profile"; };
        if (mode == 4) view.afterPreview = ^{ manager.activeID = @"newer-profile"; };
        if (mode == 5) view.afterPersist = ^{ manager.activeID = @"newer-profile"; };
        manager.pendingSwitch(YES, nil);
        if (mode <= 5) {
            BOOL stopped = Pump(^BOOL { return !view.dashboardResetToken; });
            CHECK(stopped && view.errors == 1 && !view.successes && !gResetRestartSchedules && [manager.activeID isEqual:@"newer-profile"] &&
                view.manager.generations == (mode >= 3 ? 1 : 0) && view.previews == (mode >= 4 ? 1 : 0) && (mode != 1 || !view.manager.writes),
                "reset selection checkpoints stop after toggle generation or preview supersession");
            if (mode == 5) CHECK(view.persists == 1 && gResetFinalNotifications == 1 && !view.refreshes,
                "queued reset feedback rejects a selection changed after persistence");
            else CHECK(!view.persists && !gResetFinalNotifications, "failed reset checkpoint stops before final persistence and notice");
        } else {
            CHECK(Pump(^BOOL { return gResetRestartSchedules == 1; }) && view.successes == 1 && view.dashboardResetToken, "matching reset selection reaches delayed restart");
            manager.activeID = @"newer-profile"; dispatch_block_t restart = gResetRestart; restart(); restart();
            CHECK(!view.restarts && !view.dashboardResetToken && !view.dashboardResetInputs && view.successes == 1 && !view.errors && [manager.activeID isEqual:@"newer-profile"],
                "delayed reset restart is skipped after another profile becomes active");
        }
        ResetRunRelease(view, manager);
    }
    PXResetRunProfileManager *manager = ResetRunManager(); PXResetRunUIFixture *view = [PXResetRunUIFixture new];
    [view resetDataTapped]; view.clearCompletion(@[]); CHECK(Pump(^BOOL { return manager.requests == 1; }), "frozen reset ID fixture creates");
    manager.pendingCreation(YES, nil); CHECK(Pump(^BOOL { return manager.switches == 1; }), "frozen reset ID captured before switch");
    [manager.requestedInput setValue:@"later-input-edit" forKey:@"profileId"]; manager.pendingSwitch(YES, nil);
    CHECK(Pump(^BOOL { return gResetRestartSchedules == 1; }) && [view.lastDashboardMessage containsString:@"controller-target"] && ![view.lastDashboardMessage containsString:@"later-input-edit"],
        "reset feedback uses the frozen created ID after caller model edits");
    gResetRestart(); CHECK(view.restarts == 1 && !view.dashboardResetToken, "matching frozen reset ID permits one normal restart"); ResetRunRelease(view, manager);
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
        TestCreation(manager, zero); TestCreationOwnedModel(manager); TestNestedProfileArchiveValidation(manager); TestConflicts(manager); TestSelectionFailure(manager, zero); TestBackgroundAndPolicy(manager); TestRestart(manager, zero);
        TestCreationDirectoryDrift(manager); TestCreationDisplayDrift(manager);
        TestProfileMetadataUpdates(); TestDefaultProfileSeeding(); TestRegistryEncodingPreflight(); TestOwnedMetadataEdits(); TestActivationModelPolicy(); TestActivationCallbackDrift(); TestRegistryAndDeletion();
        TestDeletionRecovery([NSString stringWithUTF8String:argv[0]]);
        TestUIDeletionAuthority();
        TestProfileIDAllocation();
        TestCurrentProfileCheckpoint(); TestCreationUIAdapters(); TestResetPreparationStatus(); TestResetIntentSnapshots(); TestResetRunAdmission(); TestResetPerAppCallbacks(); TestResetAdmittedInputs(); TestResetSelectionCheckpoints();
        __block BOOL drained = NO; dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
        CHECK(Pump(^BOOL { return drained; }), "deferred mirror callbacks drained before source teardown");
        [NSNotificationCenter.defaultCenter removeObserver:observer]; gStore = nil;
        [fm removeItemAtPath:gRoot error:NULL];
        printf("Profile creation flow: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
