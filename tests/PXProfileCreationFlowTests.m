#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "ProfileManager.h"
#import "PXRuntimeProfileSelection.h"
#include <stdatomic.h>
#include <unistd.h>

static NSUInteger gChecks, gFailures, gNotices, gCanvas, gMirrors, gTerminations;
static NSString *gRoot, *gRequested;
static NSDictionary *gPreparedNetwork;
static PXRuntimeSourceStore *gStore;
static NSDictionary *gNetworkOptions;
static _Atomic BOOL gEntered, gCommitted;
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
- (BOOL)regenerateAllEnabledIdentifiersForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)artifacts error:(NSError **)error;
- (void)resetCanvasNoise;
@end
@implementation IdentifierManager
+ (instancetype)sharedManager { static id manager; static dispatch_once_t once; dispatch_once(&once, ^{ manager = [self new]; }); return manager; }
- (BOOL)regenerateAllEnabledIdentifiersForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)artifacts error:(NSError **)error {
    OutsideGate(); gRequested = [profileID copy]; gPreparedNetwork = [artifacts copy]; atomic_store(&gEntered, YES);
    if (gPause && dispatch_semaphore_wait(gRelease, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) != 0)
        [NSException raise:@"fixture" format:@"worker release timed out"];
    if (gThrowGeneration) [NSException raise:@"fixture" format:@"generation exception"];
    if (gFailGeneration) { if (error) *error = [NSError errorWithDomain:@"fixture.generation" code:1 userInfo:nil]; return NO; }
    BOOL ok = [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return [tx setDictionary:@{ @"generatedFor": profileID } atPath:Path(Identity(profileID), @"device_ids.plist") error:writeError];
    } error:error];
    atomic_store(&gCommitted, ok); return ok;
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
- (void)terminateEnabledScopedApps { gTerminations++; CHECK(NSThread.isMainThread, "termination backend runs on main without killing apps"); }
- (void)randomizeAppVersionsForProfile:(NSString *)profile { (void)profile; CHECK(NSThread.isMainThread, "version adapter retains caller queue policy"); }
- (NSDictionary *)captureProfileNetworkOptions {
    return @{ @"enabled": gNetworkOptions[@"enabled"], @"connectionType": gNetworkOptions[@"connectionType"], @"country": [gNetworkOptions[@"country"] copy] };
}
- (void)mirrorCurrentProfileID:(NSString *)profile {
    gMirrors++;
    CHECK([Record(PXCurrentProfileInfoPath())[@"ProfileId"] isEqual:profile] &&
          [Record(PXLegacyActiveProfileInfoPath())[@"ProfileId"] isEqual:profile], "defaults mirror follows committed selection pair");
    OutsideGate();
}
#include "PXProfileFlowMethods.inc"
@end
static Profile *New(NSString *name) { return [[Profile alloc] initWithName:name iconName:@"default_profile"]; }
static void ResetWorker(void) {
    atomic_store(&gEntered, NO); atomic_store(&gCommitted, NO);
    gRelease = dispatch_semaphore_create(0); gPause = YES; gFailGeneration = NO; gThrowGeneration = NO;
}
static void TestCreation(PXProfileCreationFixture *manager, Profile *zero) {
    ResetWorker(); Profile *one = New(@"one"); __block NSUInteger callbacks = 0;
    __block BOOL success = NO; __block NSError *failure = nil;
    NSUInteger notices = gNotices;
    [manager createProfile:one completion:^(BOOL ok, NSError *error) {
        callbacks++; success = ok; failure = error;
        CHECK(NSThread.isMainThread && atomic_load(&gCommitted) && !manager.creationInProgress, "creation waits for generation and completion runs once on main");
    }];
    CHECK(Pump(^BOOL { return atomic_load(&gEntered); }) && callbacks == 0 && manager.creationInProgress, "creation cannot complete while worker is paused");
    __block NSUInteger busy = 0;
    void (^rejected)(BOOL, NSError *) = ^(BOOL ok, NSError *error) { if (!ok && error.code == 12 && NSThread.isMainThread) busy++; };
    [manager createProfile:New(@"overlap") completion:rejected]; [manager switchToProfile:zero completion:rejected];
    [manager updateProfile:zero completion:rejected]; [manager deleteProfile:zero completion:rejected];
    CHECK(busy == 4 && callbacks == 0, "overlapping lifecycle operations reject while creation is pending");
    CHECK([manager persistProfileSelectionInfo:@{ @"ProfileId": @"0" } error:NULL], "external selection drift fixture committed");
    dispatch_semaphore_signal(gRelease);
    CHECK(Pump(^BOOL { return callbacks > 0; }) && callbacks == 1 && success && !failure && gNotices == notices + 1,
          "creation completion follows generation metadata and one success notification");
    CHECK([Record(Path(Identity(one.profileId), @"device_ids.plist"))[@"generatedFor"] isEqual:one.profileId] &&
          !Record(Path(Identity(@"0"), @"device_ids.plist"))[@"generatedFor"] && [gRequested isEqual:one.profileId],
          "creation worker preserves supplied profile after selection drift");
    CHECK([gPreparedNetwork[@"carrier"][@"carrierName"] isEqual:@"us"] && [gPreparedNetwork[@"ipv4"] isEqual:@"192.168.1.77"] &&
          [gPreparedNetwork[@"ipv6"] isEqual:@"fd00::77"], "creation passes one prepared network bundle to generation");
    NSString *orphan = Path(PXProfilesPath(), @"17"); [manager createDirectoryIfNeeded:orphan];
    CHECK([[manager generateProfileID] isEqual:@"18"], "directory-only IDs are never reused when archive already has entries");
    NSError *archiveError = nil;
    NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingFromData:[NSData dataWithContentsOfFile:Path(PXProfilesPath(), @"profiles.plist")] error:&archiveError];
    decoder.requiresSecureCoding = YES;
    NSArray *roundTrip = [decoder decodeObjectOfClasses:PXProfileArchiveClasses() forKey:NSKeyedArchiveRootObjectKey];
    [decoder finishDecoding];
    Profile *decodedZero = [roundTrip isKindOfClass:NSArray.class] ? roundTrip.firstObject : nil;
    CHECK(!archiveError && [decodedZero isKindOfClass:Profile.class] && [decodedZero.settings[@"enabled"] boolValue] &&
          [decodedZero.settings[@"nested"] count] == 3 && [decodedZero.settings[@"data"] isKindOfClass:NSData.class],
          "secure profile archive preserves nested property list settings");
    for (NSUInteger mode = 0; mode < 2; mode++) {
        ResetWorker(); gPause = NO; gFailGeneration = mode == 0; gThrowGeneration = mode == 1;
        callbacks = 0; notices = gNotices; NSUInteger canvas = gCanvas;
        [manager createProfile:New(mode == 0 ? @"failed" : @"exception") completion:^(BOOL ok, NSError *error) {
            callbacks++; success = ok; failure = error; CHECK(NSThread.isMainThread, "failure completion runs on main");
        }];
        CHECK(Pump(^BOOL { return callbacks > 0; }) && !success && failure && callbacks == 1 && gNotices == notices && gCanvas == canvas && !manager.creationInProgress,
              mode == 0 ? "generation failure never publishes profile success" : "generation exception releases busy state and reports failure");
    }
    ResetWorker(); callbacks = 0; notices = gNotices;
    NSString *archive = Path(PXProfilesPath(), @"profiles.plist"); NSData *saved = [NSData dataWithContentsOfFile:archive];
    [manager createProfile:New(@"archive-failure") completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    CHECK(Pump(^BOOL { return atomic_load(&gEntered); }), "archive failure worker paused");
    [manager.fileManager removeItemAtPath:archive error:NULL]; [manager createDirectoryIfNeeded:archive];
    dispatch_semaphore_signal(gRelease);
    CHECK(Pump(^BOOL { return callbacks > 0; }), "archive failure completion arrives");
    BOOL directory = NO;
    CHECK(!success && failure && callbacks == 1 && !manager.creationInProgress && gNotices == notices &&
          [manager.fileManager fileExistsAtPath:archive isDirectory:&directory] && directory,
          "metadata failure never unlinks the last archive destination");
    [manager.fileManager removeItemAtPath:archive error:NULL]; CHECK([saved writeToFile:archive atomically:YES], "archive fixture restored");
    ResetWorker(); gPause = NO; callbacks = 0; gThrowObserver = YES;
    [manager createProfile:New(@"observer-exception") completion:^(BOOL ok, NSError *error) { callbacks++; success = ok; failure = error; }];
    CHECK(Pump(^BOOL { return callbacks > 0; }) && success && !failure && callbacks == 1 && !manager.creationInProgress,
          "post commit observer exception never suppresses completion or reports false rollback");
    gThrowObserver = NO;
}
static void TestSelectionFailure(PXProfileCreationFixture *manager, Profile *zero) {
    NSData *central = [NSData dataWithContentsOfFile:PXCurrentProfileInfoPath()], *legacy = [NSData dataWithContentsOfFile:PXLegacyActiveProfileInfoPath()];
    Profile *current = manager.mutableCurrentProfile; NSUInteger mirrors = gMirrors;
    __block BOOL called = NO, result = YES; __block NSError *failure = nil;
    gStore.testCheckpoint = ^(NSString *stage) { if ([stage isEqual:@"source-written"]) [NSException raise:@"fixture" format:@"selection write fault"]; };
    [manager switchToProfile:zero completion:^(BOOL ok, NSError *error) { called = YES; result = ok; failure = error; }];
    gStore.testCheckpoint = nil;
    CHECK(called && !result && failure && current == manager.mutableCurrentProfile && mirrors == gMirrors &&
          [central isEqual:[NSData dataWithContentsOfFile:PXCurrentProfileInfoPath()]] && [legacy isEqual:[NSData dataWithContentsOfFile:PXLegacyActiveProfileInfoPath()]],
          "selection pair failure preserves files memory and defaults mirror");
    ResetWorker(); gPause = NO; atomic_store(&gEntered, NO); called = NO;
    NSUInteger count = manager.mutableProfiles.count;
    gStore.testCheckpoint = ^(NSString *stage) { if ([stage isEqual:@"source-written"]) [NSException raise:@"fixture" format:@"creation selection fault"]; };
    [manager createProfile:New(@"selection-failure") completion:^(BOOL ok, NSError *error) { called = YES; result = ok; failure = error; }];
    gStore.testCheckpoint = nil;
    CHECK(called && !result && failure && !manager.creationInProgress && !atomic_load(&gEntered) &&
          manager.mutableProfiles.count == count && manager.mutableCurrentProfile == current && mirrors == gMirrors &&
          [central isEqual:[NSData dataWithContentsOfFile:PXCurrentProfileInfoPath()]], "creation selection failure stops before worker and releases busy state");
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
            (void)note; gNotices++; CHECK(NSThread.isMainThread && atomic_load(&gCommitted), "profile success notification follows generation on main");
            if (gThrowObserver) [NSException raise:@"fixture" format:@"observer failed after commit"];
        }];
        TestCreation(manager, zero); TestSelectionFailure(manager, zero); TestBackgroundAndPolicy(manager);
        [NSNotificationCenter.defaultCenter removeObserver:observer]; gStore = nil;
        [fm removeItemAtPath:gRoot error:NULL];
        printf("Profile creation flow: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
