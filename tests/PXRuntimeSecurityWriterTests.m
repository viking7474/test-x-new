#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#import "PXSecuritySettingsStore.h"
#import "PXRuntimeSourceStore.h"
#import "PXRuntimeSnapshot.h"
#import "PXPaths.h"
#import "TLinkIOSLogging.h"
#import "VersionCompare.h"
#include <stdatomic.h>
#include <unistd.h>

static NSUInteger gChecks, gFailures, gMirrors, gSettingsNotices, gResetNotices;
static NSUInteger gRegionCarrierNotices, gRegionISONotices;
static _Atomic NSUInteger gAttempts;
static NSString *gRoot, *gPath, *gThrowMirrorSuite;
static PXRuntimeSourceStore *gStore;
static NSObject *gMirrorGuard;
static NSMutableDictionary *gSuites;
static BOOL gCheckMirror;
static void (^gDuringMirror)(void);
#define CHECK(value, message) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", message); } } while (0)
NSString *PXSecuritySettingsPath(void) { return gPath; }
PXRuntimeReadSnapshot *PXCaptureRuntimeSnapshot(void) { return nil; }
BOOL PXPerformStandaloneRuntimeSourceWrite(BOOL (^body)(PXRuntimeSourceTransaction *, NSError **), NSError **error) {
    atomic_fetch_add(&gAttempts, 1);
    return [gStore performStandaloneWrite:body error:error];
}
void PXLog(NSString *format, ...) { (void)format; }
static NSDictionary *Load(void) { return [NSDictionary dictionaryWithContentsOfFile:gPath] ?: @{}; }
static NSDictionary *Capture(void) {
    return [gStore capture:^NSDictionary *(NSError **error) {
        (void)error;
        return @{ @"exists": @([NSFileManager.defaultManager fileExistsAtPath:gPath]),
            @"bytes": [NSData dataWithContentsOfFile:gPath] ?: NSData.data };
    } error:NULL];
}
static BOOL Seed(NSDictionary *settings) {
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx setDictionary:settings atPath:gPath error:error];
    } error:NULL];
}

// Production store runs unchanged against an in-memory compatibility backend.
// No test writes to the user's real preferences domains or sends Darwin IPC.
@interface PXFixtureDefaults : NSObject
@property (nonatomic, copy) NSString *suite;
- (instancetype)initWithSuiteName:(NSString *)suite;
- (void)setObject:(id)value forKey:(NSString *)key;
- (id)objectForKey:(NSString *)key;
- (BOOL)synchronize;
@end
@implementation PXFixtureDefaults
- (instancetype)initWithSuiteName:(NSString *)suite { if ((self = [super init])) _suite = [suite copy]; return self; }
- (void)setObject:(id)value forKey:(NSString *)key {
    void (^callback)(void) = nil; BOOL throws = NO;
    @synchronized (gMirrorGuard) { gMirrors++; callback = gDuringMirror; gDuringMirror = nil; throws = [self.suite isEqual:gThrowMirrorSuite]; }
    if (throws) [NSException raise:@"fixture.mirror" format:@"injected mirror failure"];
    if (gCheckMirror) {
        CHECK(Capture() != nil && [Load()[key] isEqual:value], "security mirror observes committed source outside source gate");
        if ([key isEqual:@"CanvasFingerprint"] || [key isEqual:@"canvasFingerprintingEnabled"])
            CHECK([Load()[@"CanvasFingerprint"] isEqual:Load()[@"canvasFingerprintingEnabled"]], "security aliases are never mirrored before paired commit");
    }
    if (callback) callback();
    @synchronized (gMirrorGuard) {
        NSMutableDictionary *suite = gSuites[self.suite];
        if (!suite) { suite = [NSMutableDictionary dictionary]; gSuites[self.suite] = suite; }
        suite[key] = value;
    }
}
- (id)objectForKey:(NSString *)key { @synchronized (gMirrorGuard) { return gSuites[self.suite][key]; } }
- (BOOL)synchronize { return YES; }
@end
#define NSUserDefaults PXFixtureDefaults
#include "../common/PXSecuritySettingsStore.m"
#undef NSUserDefaults

static void PXFixturePostSettings(void) { gSettingsNotices++; CHECK(Capture() != nil, "canvas notification runs after source gate release"); }
static void PXFixturePostDarwin(CFNotificationCenterRef center, CFStringRef name, const void *object, CFDictionaryRef info, Boolean immediate) {
    (void)center; (void)object; (void)info; (void)immediate;
    if (CFEqual(name, CFSTR("com.hydra.tlinkios.resetCanvasNoise"))) gResetNotices++;
    else if (CFEqual(name, CFSTR("com.hydra.tlinkios.settings.changed"))) gSettingsNotices++;
    else if (CFEqual(name, CFSTR("com.hydra.tlinkios.carrierDetailsChanged"))) gRegionCarrierNotices++;
    else if (CFEqual(name, CFSTR("com.hydra.tlinkios.networkISOCountryCodeChanged"))) gRegionISONotices++;
    CHECK(Capture() != nil, "canvas Darwin callback observes released source gate");
}
#define PXPostSettingsChangedNotification PXFixturePostSettings
#define CFNotificationCenterGetDarwinNotifyCenter() NULL
#define CFNotificationCenterPostNotification PXFixturePostDarwin
@interface PXCanvasManagerFixture : NSObject
- (BOOL)setCanvasFingerprintProtection:(BOOL)enabled;
- (BOOL)resetCanvasNoiseAndPersist;
@end
@implementation PXCanvasManagerFixture
#include "PXCanvasManagerMethods.inc"
@end
@interface PXCanvasDetailFixture : NSObject
- (BOOL)persistCanvasValues:(NSDictionary<NSString *, id> *)values;
@end
@implementation PXCanvasDetailFixture
#include "PXCanvasDetailMethod.inc"
@end
#undef CFNotificationCenterPostNotification
#undef CFNotificationCenterGetDarwinNotifyCenter
#undef PXPostSettingsChangedNotification

// Only persistence/stop and the UI handler are extracted. No network requests,
// scheduled run loop timers, UIKit, or real user defaults are used here.
@interface PXIPMonitorFixture : NSObject
@property (nonatomic, assign) BOOL isMonitoring;
@property (nonatomic, strong) NSTimer *monitoringTimer;
@property (nonatomic, strong) NSObject *monitoringToken;
@property (nonatomic, strong) NSMutableSet<NSURLSession *> *monitoringSessions;
@property (nonatomic, assign) NSUInteger starts;
+ (instancetype)sharedInstance;
- (BOOL)isIPMonitoringEnabled;
- (BOOL)runningFlag;
- (void)startMonitoring;
- (void)saveLastKnownIP:(NSString *)ip;
- (void)saveIPToCache:(NSString *)ip;
- (BOOL)setMonitoringEnabledAndPersist:(BOOL)enabled error:(NSError **)error;
- (void)stopMonitoring;
@end
@implementation PXIPMonitorFixture
@synthesize isMonitoring = _isMonitoring;
+ (instancetype)sharedInstance { static id monitor; static dispatch_once_t once; dispatch_once(&once, ^{ monitor = [self new]; }); return monitor; }
- (BOOL)isIPMonitoringEnabled { return [Load()[@"ipMonitorEnabled"] boolValue]; }
- (BOOL)runningFlag { return _isMonitoring; }
- (void)startMonitoring {
    CHECK(Capture() != nil && [Load()[@"ipMonitorEnabled"] boolValue], "IP monitor start observes committed toggle outside source gate");
    self.starts++; self.isMonitoring = YES;
    self.monitoringTimer = [NSTimer timerWithTimeInterval:3600 repeats:NO block:^(__unused NSTimer *timer) {}];
}
#include "PXIPMonitorMethods.inc"
@end
@interface PXMonitorSwitch : NSObject
@property (nonatomic, assign, getter=isOn) BOOL on;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end
@implementation PXMonitorSwitch
- (void)setOn:(BOOL)on animated:(BOOL)animated { (void)animated; self.on = on; }
@end
// Model the manager app's disk-precedence read in both host compilation lanes.
// A macOS command-line bundle is not the real RootHide manager bundle identity.
static BOOL PXManagerReadSecurityBool(NSString *key, BOOL fallback) {
    id value = Load()[key]; return value ? [value boolValue] : fallback;
}
@interface PXIPMonitorUIFixture : NSObject
@property (nonatomic, assign) NSUInteger heroChanges;
@property (nonatomic, copy) NSString *toast;
- (void)showToastWithMessage:(NSString *)message;
- (void)updateSecurityHeroCount;
- (void)ipMonitorToggleChanged:(PXMonitorSwitch *)sender;
@end
@implementation PXIPMonitorUIFixture
- (void)showToastWithMessage:(NSString *)message { self.toast = message; CHECK(Capture() != nil, "IP monitor UI feedback runs outside source gate"); }
- (void)updateSecurityHeroCount { self.heroChanges++; }
#define UISwitch PXMonitorSwitch
#define IPMonitorService PXIPMonitorFixture
#define PXReadSecurityBool PXManagerReadSecurityBool
#include "PXIPMonitorUIMethod.inc"
#undef PXReadSecurityBool
#undef IPMonitorService
#undef UISwitch
@end

// Carrier catalogue and UIKit are fixture boundaries; exact packet, toggle and
// timezone methods still use the real source store and detached mirror packet.
static NSDictionary *gRegionDefaults;
@interface CarrierDB : NSObject
+ (instancetype)sharedManager;
- (NSDictionary *)regionDefaultsForCountryCode:(NSString *)country;
@end
@implementation CarrierDB
+ (instancetype)sharedManager { static id database; static dispatch_once_t once; dispatch_once(&once, ^{ database = [self new]; }); return database; }
- (NSDictionary *)regionDefaultsForCountryCode:(NSString *)country { (void)country; return gRegionDefaults; }
@end
@interface PXRegionFixture : PXIPMonitorUIFixture
- (NSDictionary *)targetRegionDefaultsForCountryCode:(NSString *)countryCode;
- (BOOL)persistPinnedTargetRegionFromResponse:(NSDictionary *)json error:(NSError **)error;
- (BOOL)persistTimeZoneName:(NSString *)name forKey:(NSString *)key;
- (void)publishTargetRegionChanged;
@end
#define UISwitch PXMonitorSwitch
#define PXReadSecurityBool PXManagerReadSecurityBool
#define CFNotificationCenterGetDarwinNotifyCenter() ((CFNotificationCenterRef)(uintptr_t)1)
#define CFNotificationCenterPostNotification PXFixturePostDarwin
#include "PXRegionSecurityHelpers.inc"
@implementation PXRegionFixture
#include "PXRegionSecurityMethods.inc"
@end
@interface PXTimeZoneFixture : NSObject
- (void)publishTimeSpoofSettingsChanged;
- (BOOL)persistLocationTimeZoneName:(NSString *)name;
@end
@implementation PXTimeZoneFixture
#include "PXTimeZoneSecurityMethods.inc"
@end
#undef CFNotificationCenterPostNotification
#undef CFNotificationCenterGetDarwinNotifyCenter
#undef PXReadSecurityBool
#undef UISwitch

// Exact scalar readers with a raw getter seam in both host compilation lanes.
static id gScalarReaderValue;
static id PXFixtureScalarInput(NSString *key) { (void)key; return gScalarReaderValue; }
#define PXReadSecuritySetting PXFixtureScalarInput
#define PXReadSecurityBool PXFixtureScalarBool
#define PXReadSecurityInteger PXFixtureScalarInteger
#include "PXSecurityScalarReaders.inc"
#undef PXReadSecurityInteger
#undef PXReadSecurityBool
#undef PXReadSecuritySetting

// UIKit/manager boundaries only. The two actual UI actions, version comparison,
// source transaction, byte rollback, compatibility mirrors and notices are real.
static NSString *gDisplayPolicyVersion;
static NSUInteger gDisplayPolicyVersionReads;
@interface PXDisplayPolicyManager : NSObject
+ (instancetype)sharedManager;
- (NSString *)currentValueForIdentifier:(NSString *)identifier;
@end
@implementation PXDisplayPolicyManager
+ (instancetype)sharedManager { static id manager; static dispatch_once_t once; dispatch_once(&once, ^{ manager = [self new]; }); return manager; }
- (NSString *)currentValueForIdentifier:(NSString *)identifier {
    (void)identifier; gDisplayPolicyVersionReads++;
    CHECK(NSThread.isMainThread && Capture() != nil, "WebCompat version read follows source commit on main outside gate");
    return gDisplayPolicyVersion;
}
@end
@interface PXSecurityWarningLabel : NSObject
@property (nonatomic, getter=isHidden) BOOL hidden;
@end
@implementation PXSecurityWarningLabel
@synthesize hidden = _hidden;
- (void)setHidden:(BOOL)hidden { CHECK(NSThread.isMainThread, "WebCompat warning mutates only on main"); _hidden = hidden; }
@end
@interface PXSecurityWarningConstraint : NSObject
@property (nonatomic) double constant;
@end
@implementation PXSecurityWarningConstraint
@end
@interface PXDisplayPolicyFixture : PXIPMonitorUIFixture
@property (nonatomic, strong) PXSecurityWarningLabel *webCompatIOSRangeWarningLabel;
@property (nonatomic, strong) PXSecurityWarningConstraint *webCompatIOSRangeWarningHeightConstraint;
- (void)webCompatIOSRangeToggleChanged:(PXMonitorSwitch *)sender;
- (void)displayUIScaleSpoofToggleChanged:(PXMonitorSwitch *)sender;
@end
#define UISwitch PXMonitorSwitch
#define IdentifierManager PXDisplayPolicyManager
#define PXReadSecurityBool PXManagerReadSecurityBool
#define CFNotificationCenterGetDarwinNotifyCenter() ((CFNotificationCenterRef)(uintptr_t)1)
#define CFNotificationCenterPostNotification PXFixturePostDarwin
@implementation PXDisplayPolicyFixture
#include "PXDisplayPolicyMethods.inc"
@end
#undef CFNotificationCenterPostNotification
#undef CFNotificationCenterGetDarwinNotifyCenter
#undef PXReadSecurityBool
#undef IdentifierManager
#undef UISwitch

static void TestSecurityPackets(void) {
    NSError *error = nil;
    CHECK(Seed(@{ @"keep": @YES }), "security packet baseline seeded");
    NSUInteger attempts = atomic_load(&gAttempts), mirrors = gMirrors;
    CHECK(PXWriteSecuritySettings(@{}, &error) && !error && attempts == atomic_load(&gAttempts) && mirrors == gMirrors,
          "empty security packet is a no-op without source or compatibility effects");
    NSDictionary *before = Capture();
    NSDictionary *badKey = @{ @1: @YES }, *badValue = @{ @"bad": NSObject.new };
    CHECK(!PXWriteSecuritySettings(badKey, &error) && error && !PXWriteSecuritySettings(badValue, &error) && error &&
          !PXWriteSecuritySetting(nil, @YES, &error) && error && !PXWriteSecuritySetting(@"valid", nil, &error) && error &&
          [before isEqual:Capture()] && attempts == atomic_load(&gAttempts) && mirrors == gMirrors,
          "invalid security keys values and payloads fail before source entry");
    NSMutableString *text = [@"frozen-value" mutableCopy]; NSMutableDictionary *packet = [@{ @"text": text, @"enabled": @YES } mutableCopy];
    __block NSUInteger commits = 0;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"commit-written"]) { commits++; [text setString:@"changed"]; packet[@"enabled"] = @NO; } };
    gCheckMirror = YES;
    CHECK(PXWriteSecuritySettings(packet, &error) && !error && commits == 1 && [Load()[@"text"] isEqual:@"frozen-value"] && [Load()[@"enabled"] boolValue] && [Load()[@"keep"] boolValue],
          "security packet freezes caller graph before staging and mirrors same committed values");
    gStore.testCheckpoint = nil;
    gDuringMirror = ^{ CHECK(PXWriteSecurityBool(@"reentered", YES, NULL), "security compatibility callback can reenter standalone source writer after commit"); };
    CHECK(PXWriteSecurityInteger(@"integer", 17, &error) && !error && [Load()[@"reentered"] boolValue], "security callback reentry cannot deadlock source gate");
    gThrowMirrorSuite = @"com.weaponx.securitySettings";
    CHECK(PXWriteSecurityBool(@"mirror-failure", YES, &error) && !error && [Load()[@"mirror-failure"] boolValue] &&
          [gSuites[@"com.hydra.tlinkios.SecuritySettings"][@"mirror-failure"] boolValue], "mirror exception cannot negate committed source or suppress other suites");
    gThrowMirrorSuite = nil; gCheckMirror = NO;
#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    CHECK(PXReadSecurityBool(@"enabled", NO) && PXReadSecurityInteger(@"integer", 0) == 17 && PXReadSecurityBool(@"absent", YES),
          "rootful security readers retain disk precedence and default fallback policy");
#endif
    before = Capture(); mirrors = gMirrors;
    CHECK(![gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **outerError) {
        if (![tx setDictionary:@{ @"uncommitted": @YES } atPath:gPath error:outerError]) return NO;
        NSError *nestedError = nil;
        CHECK(!PXWriteSecurityBool(@"nested", YES, &nestedError) && nestedError, "security standalone API rejects nested join before mirroring");
        return YES; // Deliberately ignore rejected high-level call.
    } error:&error] && error && mirrors == gMirrors && [before isEqual:Capture()], "nested security rejection poisons outer staging and emits no mirror");
    CHECK([gStore capture:^NSDictionary *(NSError **captureError) {
        (void)captureError; CHECK(!PXWriteSecurityBool(@"during-capture", YES, NULL), "security source mutation rejects capture reentry"); return @{};
    } error:NULL] != nil && mirrors == gMirrors && [before isEqual:Capture()], "capture reentry preserves source and compatibility state");
    __block BOOL interrupted = NO;
    gStore.testCheckpoint = ^(NSString *phase) { if (!interrupted && [phase isEqual:@"source-written"]) { interrupted = YES; [NSException raise:@"fixture" format:@"security commit fault"]; } };
    uint32_t output = 99;
    CHECK(!PXAdvanceSecurityNonce(@"nonce", &output, &error) && error && interrupted && output == 99 && [before isEqual:Capture()] && mirrors == gMirrors,
          "security commit failure restores source bytes token nonce output and suppresses mirrors"); gStore.testCheckpoint = nil;
    NSData *bad = [@"corrupt-security-source" dataUsingEncoding:NSUTF8StringEncoding];
    CHECK([bad writeToFile:gPath atomically:YES], "corrupt security source fixture installed"); before = Capture();
    CHECK(!PXWriteSecurityBool(@"must-not-replace", YES, &error) && error && [before isEqual:Capture()] && mirrors == gMirrors,
          "malformed security dictionary is preserved instead of replaced with empty defaults");
    CHECK([NSFileManager.defaultManager removeItemAtPath:gPath error:NULL] && Seed(@{ @"keep": @YES }), "security corruption fixture restored");
}

static void TestNonceAndCanvas(void) {
    NSError *error = nil; uint32_t value = 77;
    CHECK(Seed(@{ @"nonce": @(UINT32_MAX), @"keep": @YES }) && PXAdvanceSecurityNonce(@"nonce", &value, &error) && !error && value == 1 && [Load()[@"keep"] boolValue],
          "security nonce wraps uint32 max to one while preserving unrelated keys");
    CHECK(Seed(@{ @"nonce": @[] }) && PXAdvanceSecurityNonce(@"nonce", &value, &error) && value == 1,
          "malformed security nonce cannot receive unsafe numeric selector");
    CHECK(Seed(@{ @"nonce": @0 }), "concurrent security nonce baseline seeded");
    dispatch_group_t group = dispatch_group_create(); NSMutableSet *values = [NSMutableSet set];
    static _Atomic NSUInteger failures; atomic_store(&failures, 0);
    for (NSUInteger worker = 0; worker < 6; worker++) dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            for (NSUInteger iteration = 0; iteration < 8; iteration++) {
                uint32_t next = 0; NSError *failure = nil;
                if (!PXAdvanceSecurityNonce(@"nonce", &next, &failure) || failure) atomic_fetch_add(&failures, 1);
                else @synchronized (values) { [values addObject:@(next)]; }
            }
        }
    });
    CHECK(dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC)) == 0 && !atomic_load(&failures) && values.count == 48 && [Load()[@"nonce"] unsignedIntValue] == 48,
          "concurrent security nonce updates have no duplicates or lost increments");
    PXCanvasManagerFixture *manager = [PXCanvasManagerFixture new]; PXCanvasDetailFixture *detail = [PXCanvasDetailFixture new];
    gCheckMirror = YES;
    CHECK([manager setCanvasFingerprintProtection:YES] && [Load()[@"canvasFingerprintingEnabled"] boolValue] && [Load()[@"CanvasFingerprint"] boolValue],
          "canvas protection aliases commit together before notification");
    NSDictionary *updates = @{ @"canvasNoiseLevel": @2, @"canvasWebKitEnabled": @YES };
    CHECK([detail persistCanvasValues:updates] && [Load()[@"canvasNoiseLevel"] isEqual:@2] && [Load()[@"canvasWebKitEnabled"] boolValue], "canvas detail values merge as one source packet");
    NSUInteger notices = gSettingsNotices, resets = gResetNotices;
    CHECK([manager resetCanvasNoiseAndPersist] && notices + 1 == gSettingsNotices && resets + 1 == gResetNotices && [Load()[@"canvasNoiseSeedNonce"] isEqual:@1],
          "canvas nonce success sends both original topics after committed increment");
    NSDictionary *before = Capture(); NSUInteger mirrors = gMirrors; notices = gSettingsNotices; resets = gResetNotices;
    NSDictionary *failedUpdates = @{ @"canvasNoiseLevel": @3, @"canvasWebKitEnabled": @NO };
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"]) [NSException raise:@"fixture" format:@"canvas commit failure"]; };
    CHECK(![manager setCanvasFingerprintProtection:NO] && ![detail persistCanvasValues:failedUpdates] && ![manager resetCanvasNoiseAndPersist] &&
          [before isEqual:Capture()] && mirrors == gMirrors && notices == gSettingsNotices && resets == gResetNotices,
          "failed canvas alias detail and nonce writes preserve all bytes and emit no success callbacks");
    gStore.testCheckpoint = nil; gCheckMirror = NO;
}
static void TestIPMonitorWriters(void) {
    CHECK(Seed(@{ @"keep": @YES, @"ipMonitorEnabled": @NO, @"lastKnownIP": @"old" }), "IP monitor source baseline seeded");
    PXIPMonitorFixture *monitor = PXIPMonitorFixture.sharedInstance;
    __block NSUInteger commits = 0;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"commit-written"]) commits++; };
    NSUInteger notices = gSettingsNotices, resets = gResetNotices;
    gCheckMirror = YES;
    [monitor saveLastKnownIP:@"203.0.113.7"];
    CHECK(commits == 1 && [Load()[@"lastKnownIP"] isEqual:@"203.0.113.7"] && [Load()[@"CachedIP"] isEqual:@"203.0.113.7"] &&
          [Load()[@"IPCacheTime"] isKindOfClass:NSDate.class] && [Load()[@"keep"] boolValue] && notices == gSettingsNotices && resets == gResetNotices,
          "observed IP cache and timestamp commit once preserving unrelated security values");
    [monitor saveIPToCache:@"203.0.113.8"];
    CHECK(commits == 2 && [Load()[@"lastKnownIP"] isEqual:@"203.0.113.7"] && [Load()[@"CachedIP"] isEqual:@"203.0.113.8"] &&
          [Load()[@"IPCacheTime"] isKindOfClass:NSDate.class], "cache-only IP save preserves last known IP and uses one source commit");
    NSUInteger attempts = atomic_load(&gAttempts);
    [monitor saveLastKnownIP:nil]; [monitor saveIPToCache:nil];
    CHECK(attempts == atomic_load(&gAttempts) && commits == 2, "nil IP candidates do not enter source transaction");
    NSDictionary *before = Capture(); NSUInteger mirrors = gMirrors;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"]) [NSException raise:@"fixture" format:@"IP packet fault"]; };
    [monitor saveLastKnownIP:@"203.0.113.9"]; [monitor saveIPToCache:@"203.0.113.10"];
    CHECK([before isEqual:Capture()] && mirrors == gMirrors && notices == gSettingsNotices && resets == gResetNotices,
          "failed IP cache packets preserve bytes token mirrors and notifications");
    gStore.testCheckpoint = nil;
    NSError *error = nil;
    CHECK([monitor setMonitoringEnabledAndPersist:YES error:&error] && !error && monitor.runningFlag && monitor.monitoringTimer.valid,
          "IP monitor enabled source starts service after commit");
    NSTimer *timer = monitor.monitoringTimer;
    CHECK([monitor setMonitoringEnabledAndPersist:NO error:&error] && !error && !monitor.isMonitoring && !monitor.runningFlag && !timer.valid && !monitor.monitoringTimer,
          "IP monitor stops and invalidates timer after persisted toggle makes effective getter false");
    monitor.monitoringTimer = [NSTimer timerWithTimeInterval:3600 repeats:NO block:^(__unused NSTimer *tick) {}]; timer = monitor.monitoringTimer;
    [monitor stopMonitoring]; [monitor stopMonitoring];
    CHECK(!timer.valid && !monitor.monitoringTimer && !monitor.runningFlag, "IP monitor cleans a leftover timer even when running flag is false");
    CHECK([monitor setMonitoringEnabledAndPersist:YES error:&error], "IP monitor disable fault baseline enabled");
    timer = monitor.monitoringTimer; before = Capture(); mirrors = gMirrors; NSUInteger starts = monitor.starts;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"]) [NSException raise:@"fixture" format:@"IP toggle fault"]; };
    CHECK(![monitor setMonitoringEnabledAndPersist:NO error:&error] && error && monitor.runningFlag && timer.valid && monitor.monitoringTimer == timer &&
          starts == monitor.starts && mirrors == gMirrors && [before isEqual:Capture()], "failed IP toggle preserves running timer and emits no service success");
    PXIPMonitorUIFixture *ui = [PXIPMonitorUIFixture new]; PXMonitorSwitch *sender = [PXMonitorSwitch new]; sender.on = NO;
    [ui ipMonitorToggleChanged:sender];
    CHECK(sender.isOn && ui.heroChanges == 0 && [ui.toast hasPrefix:@"Unable"] && timer.valid && monitor.runningFlag && [before isEqual:Capture()],
          "IP monitor UI rolls back failed disable without stopping active timer");
    gStore.testCheckpoint = nil;
    CHECK([monitor setMonitoringEnabledAndPersist:NO error:&error], "IP monitor enable fault baseline disabled"); before = Capture();
    sender.on = YES;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"]) [NSException raise:@"fixture" format:@"IP toggle fault"]; };
    [ui ipMonitorToggleChanged:sender];
    CHECK(!sender.isOn && ui.heroChanges == 0 && [ui.toast hasPrefix:@"Unable"] && !monitor.runningFlag && !monitor.monitoringTimer && starts == monitor.starts && [before isEqual:Capture()],
          "IP monitor UI rolls back failed enable without starting service");
    gStore.testCheckpoint = nil;
    sender.on = YES; [ui ipMonitorToggleChanged:sender]; timer = monitor.monitoringTimer;
    CHECK(sender.isOn && ui.heroChanges == 1 && [ui.toast isEqual:@"IP Monitoring Enabled"] && [Load()[@"ipMonitorEnabled"] boolValue] && monitor.runningFlag && timer.valid,
          "IP monitor UI enables only after committed setting");
    sender.on = NO; [ui ipMonitorToggleChanged:sender];
    CHECK(!sender.isOn && ui.heroChanges == 2 && [ui.toast isEqual:@"IP Monitoring Disabled"] && ![Load()[@"ipMonitorEnabled"] boolValue] && !monitor.runningFlag && !timer.valid && !monitor.monitoringTimer &&
          notices == gSettingsNotices && resets == gResetNotices, "IP monitor UI success starts and stops only after committed setting");
    gCheckMirror = NO;
}

static NSDictionary *RegionResponse(void) {
    return @{ @"status": @"success", @"countryCode": @"vn", @"lat": @10.75, @"lon": @106.5,
        @"timezone": @"Asia/Ho_Chi_Minh", @"query": @"203.0.113.20" };
}
static NSDictionary *RegionDefaults(void) {
    return @{ @"carrierISO": @"vn", @"mcc": @"452", @"mnc": @"04", @"carrierName": @"Viettel",
        @"localeIdentifier": @"vi_VN", @"preferredLanguages": @[@"vi-VN"] };
}
static void TestRegionAndTimeZoneWriters(void) {
    PXRegionFixture *region = [PXRegionFixture new]; PXTimeZoneFixture *time = [PXTimeZoneFixture new];
    CHECK(Seed(@{ @"keep": @YES, @"targetRegionFollowsIPEnabled": @NO }), "region primary baseline seeded");
    NSMutableString *zone = [@"Asia/Ho_Chi_Minh" mutableCopy], *mcc = [@"452" mutableCopy], *ip = [@"203.0.113.20" mutableCopy];
    NSMutableDictionary *response = [RegionResponse() mutableCopy], *defaults = [RegionDefaults() mutableCopy];
    response[@"timezone"] = zone; response[@"query"] = ip; defaults[@"mcc"] = mcc; gRegionDefaults = defaults;
    __block NSUInteger commits = 0;
    gStore.testCheckpoint = ^(NSString *phase) {
        if ([phase isEqual:@"commit-written"]) { commits++; [zone setString:@"Asia/Tokyo"]; [mcc setString:@"440"]; [ip setString:@"203.0.113.99"]; }
    };
    NSError *error = nil;
    NSUInteger notices = gSettingsNotices, carriers = gRegionCarrierNotices, isos = gRegionISONotices;
    gCheckMirror = YES;
    CHECK([region persistPinnedTargetRegionFromResponse:response error:&error] && !error && commits == 1 && [Load()[@"keep"] boolValue] &&
          [Load()[@"targetRegionFollowsIPEnabled"] boolValue] && [Load()[@"targetRegionPinnedCountryCode"] isEqual:@"VN"] &&
          [Load()[@"targetRegionPinnedTimeZoneName"] isEqual:@"Asia/Ho_Chi_Minh"] && [Load()[@"targetRegionPinnedCarrierMCC"] isEqual:@"452"] &&
          [Load()[@"targetRegionPinnedCarrierMNC"] isEqual:@"04"] && [Load()[@"targetRegionPinnedCarrierName"] isEqual:@"Viettel"] &&
          [Load()[@"targetRegionPinnedLocaleIdentifier"] isEqual:@"vi_VN"] && [Load()[@"targetRegionPinnedCarrierISO"] isEqual:@"vn"] &&
          [Load()[@"networkISOCountryCode"] isEqual:@"vn"] && [Load()[@"targetRegionPinnedLatitude"] isEqual:@10.75] &&
          [Load()[@"targetRegionPinnedLongitude"] isEqual:@106.5] && [Load()[@"targetRegionPinnedTimestamp"] isKindOfClass:NSNumber.class] &&
          [Load()[@"targetRegionPinnedSourceIP"] isEqual:@"203.0.113.20"] && [Load()[@"targetRegionPinnedPreferredLanguages"] isEqual:RegionDefaults()[@"preferredLanguages"]] &&
          notices == gSettingsNotices && carriers == gRegionCarrierNotices && isos == gRegionISONotices,
          "region primary security packet commits all pins and network ISO together once");
    gStore.testCheckpoint = nil;
    NSDictionary *legacy = @{ @"keep": @YES, @"targetRegionFollowsIPEnabled": @NO, @"targetRegionPinnedSourceIP": @"keep-ip",
        @"targetRegionPinnedPreferredLanguages": @[@"keep-language"], @"networkISOCountryCode": @"keep-iso" };
    CHECK(Seed(legacy), "region optional policy baseline seeded");
    response = [RegionResponse() mutableCopy]; [response removeObjectForKey:@"query"];
    defaults = [RegionDefaults() mutableCopy]; defaults[@"preferredLanguages"] = @42; defaults[@"carrierISO"] = @""; gRegionDefaults = defaults;
    CHECK([region persistPinnedTargetRegionFromResponse:response error:&error] && !error && [Load()[@"targetRegionPinnedSourceIP"] isEqual:@"keep-ip"] &&
          [Load()[@"targetRegionPinnedPreferredLanguages"] isEqual:legacy[@"targetRegionPinnedPreferredLanguages"]] && [Load()[@"networkISOCountryCode"] isEqual:@"keep-iso"] &&
          [Load()[@"targetRegionPinnedCarrierISO"] isEqual:@""], "region packet preserves omitted language source IP and legacy ISO policy");
    NSDictionary *before = Capture(); NSUInteger attempts = atomic_load(&gAttempts);
    NSMutableDictionary *badLatitude = [RegionResponse() mutableCopy], *badStatus = [RegionResponse() mutableCopy];
    badLatitude[@"lat"] = @"wrong-type"; badStatus[@"status"] = @"fail";
    NSArray *invalid = @[@[], @{}, badLatitude, badStatus]; gRegionDefaults = RegionDefaults();
    for (id candidate in invalid)
        CHECK(![region persistPinnedTargetRegionFromResponse:candidate error:&error] && error && [before isEqual:Capture()] && attempts == atomic_load(&gAttempts),
              "invalid region payload and defaults fail before source entry");
    defaults = [RegionDefaults() mutableCopy]; [defaults removeObjectForKey:@"mnc"]; gRegionDefaults = defaults;
    CHECK(![region persistPinnedTargetRegionFromResponse:RegionResponse() error:&error] && error.code == 2 && [before isEqual:Capture()] && attempts == atomic_load(&gAttempts),
          "invalid region payload and defaults fail before source entry");
    defaults = [RegionDefaults() mutableCopy]; defaults[@"preferredLanguages"] = @[NSObject.new]; gRegionDefaults = defaults;
    CHECK(![region persistPinnedTargetRegionFromResponse:RegionResponse() error:&error] && error && [before isEqual:Capture()] && attempts == atomic_load(&gAttempts),
          "non property list region languages reject the whole packet before source entry");
    gRegionDefaults = nil;
    CHECK([region persistPinnedTargetRegionFromResponse:RegionResponse() error:&error] && !error && [Load()[@"targetRegionPinnedLocaleIdentifier"] isEqual:@"en_VN"] &&
          [Load()[@"targetRegionPinnedCarrierMCC"] isEqual:@"310"], "region preparation retains original catalogue fallback policy");
    gRegionDefaults = RegionDefaults();
    CHECK(Seed(legacy), "region fault baseline seeded"); before = Capture(); NSUInteger mirrors = gMirrors;
    PXMonitorSwitch *sender = [PXMonitorSwitch new]; sender.on = YES;
    __block NSUInteger faults = 0;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"]) { faults++; [NSException raise:@"fixture" format:@"region or timezone write fault"]; } };
    BOOL pinned = [region persistPinnedTargetRegionFromResponse:RegionResponse() error:&error];
    BOOL locationZone = [region persistTimeZoneName:@"Asia/Tokyo" forKey:@"timeSpoofLocationTimeZoneName"];
    BOOL ipZone = [region persistTimeZoneName:@"Asia/Tokyo" forKey:@"timeSpoofIPAddressTimeZoneName"];
    BOOL detailZone = [time persistLocationTimeZoneName:@"Asia/Tokyo"];
    CHECK(!pinned && !locationZone && !ipZone && !detailZone && faults == 4 && [before isEqual:Capture()] && mirrors == gMirrors &&
          notices == gSettingsNotices && carriers == gRegionCarrierNotices && isos == gRegionISONotices,
          "region and timezone source faults preserve bytes token mirrors and notifications");
    NSDictionary *toggleResult = PXCommitTargetRegionToggle(sender.isOn);
    CHECK(![toggleResult[@"enabled"] boolValue] && [toggleResult[@"message"] hasPrefix:@"Could not"] && [before isEqual:Capture()] && notices == gSettingsNotices && carriers == gRegionCarrierNotices && isos == gRegionISONotices,
          "region toggle commit returns previous state on failure without publishing success");
    void (^faultCheckpoint)(NSString *) = gStore.testCheckpoint;
    gStore.testCheckpoint = nil;
    NSMutableDictionary *enabledLegacy = [legacy mutableCopy]; enabledLegacy[@"targetRegionFollowsIPEnabled"] = @YES;
    CHECK(Seed(enabledLegacy), "region failed disable baseline seeded"); before = Capture(); sender.on = NO;
    gStore.testCheckpoint = faultCheckpoint;
    toggleResult = PXCommitTargetRegionToggle(sender.isOn);
    CHECK([toggleResult[@"enabled"] boolValue] && [before isEqual:Capture()] && notices == gSettingsNotices && carriers == gRegionCarrierNotices && isos == gRegionISONotices,
          "region toggle commit returns previous state on failure without publishing success");
    gStore.testCheckpoint = nil;
    CHECK(Seed(legacy), "region successful toggles baseline seeded");
    sender.on = YES; toggleResult = PXCommitTargetRegionToggle(sender.isOn);
    CHECK([toggleResult[@"success"] boolValue] && [toggleResult[@"enabled"] boolValue], "region successful enable commit returns enabled state");
    sender.on = NO; toggleResult = PXCommitTargetRegionToggle(sender.isOn);
    CHECK([toggleResult[@"success"] boolValue] && ![toggleResult[@"enabled"] boolValue] && ![Load()[@"targetRegionFollowsIPEnabled"] boolValue] && notices + 2 == gSettingsNotices && carriers + 2 == gRegionCarrierNotices && isos + 2 == gRegionISONotices,
          "region toggle success retains all three notification topics");
    notices = gSettingsNotices; carriers = gRegionCarrierNotices; isos = gRegionISONotices;
    BOOL first = [region persistTimeZoneName:@"Asia/Tokyo" forKey:@"timeSpoofLocationTimeZoneName"];
    BOOL second = [region persistTimeZoneName:@"Europe/Paris" forKey:@"timeSpoofIPAddressTimeZoneName"];
    BOOL third = [time persistLocationTimeZoneName:@"Asia/Ho_Chi_Minh"];
    CHECK(first && second && third && notices + 3 == gSettingsNotices && carriers == gRegionCarrierNotices && isos == gRegionISONotices &&
          [Load()[@"timeSpoofLocationTimeZoneName"] isEqual:@"Asia/Ho_Chi_Minh"] && [Load()[@"timeSpoofIPAddressTimeZoneName"] isEqual:@"Europe/Paris"] && [Load()[@"keep"] boolValue],
          "timezone adapters notify only after committed source and preserve unrelated values");
    notices = gSettingsNotices; attempts = atomic_load(&gAttempts);
    CHECK(![time persistLocationTimeZoneName:nil] && ![region persistTimeZoneName:@"" forKey:@"timeSpoofIPAddressTimeZoneName"] && notices == gSettingsNotices && attempts == atomic_load(&gAttempts),
          "empty timezone candidates do not write source or publish");
    gCheckMirror = NO; gRegionDefaults = nil;
}

static void TestClearMetricWriters(void) {
    NSError *error = nil; NSUInteger attempts = 91, successes = 92;
    CHECK(Seed(@{ @"keep": @"preserved" }), "clear metric baseline seeded");
    NSUInteger notices = gSettingsNotices, mirrors = gMirrors;
    __block NSUInteger commits = 0;
    gCheckMirror = YES;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"commit-written"]) commits++; };
    CHECK(PXRecordClearAttempt(NO, &attempts, &successes, &error) && !error && attempts == 1 && successes == 0 && commits == 1 &&
        gMirrors == mirrors + 2 && gSettingsNotices == notices && [Load()[@"keep"] isEqual:@"preserved"],
        "clear metric pair commits once before mirrors without runtime notifications");
    CHECK(gSuites[@"com.hydra.tlinkios.SecuritySettings"][@"clearAttemptCount"] == nil &&
        gSuites[@"com.hydra.tlinkios"][@"clearAttemptCount"] == nil,
        "clear metrics preserve canonical-only legacy mirror scope");
    CHECK(PXRecordClearAttempt(YES, &attempts, &successes, &error) && attempts == 2 && successes == 1,
        "first-attempt success increments both counters together");
    gStore.testCheckpoint = nil; gCheckMirror = NO;
    CHECK(Seed(@{ @"clearAttemptCount": @"  +7 ", @"clearFirstAttemptSuccessCount": @"3" }) &&
        PXRecordClearAttempt(YES, &attempts, &successes, &error) && attempts == 8 && successes == 4,
        "legacy decimal metric strings are accepted and canonicalized");
    CHECK(Seed(@{ @"clearAttemptCount": @YES, @"clearFirstAttemptSuccessCount": @NO }) &&
        PXRecordClearAttempt(NO, &attempts, &successes, &error) && attempts == 2 && successes == 0,
        "legacy numeric boolean metric conversion is preserved");
    CHECK(Seed(@{ @"clearAttemptCount": @4, @"clearFirstAttemptSuccessCount": @2, @"keep": @YES }), "metric fault baseline seeded");
    NSDictionary *before = Capture(); mirrors = gMirrors; attempts = 91; successes = 92;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"]) [NSException raise:@"fixture" format:@"metric source fault"]; };
    CHECK(!PXRecordClearAttempt(YES, &attempts, &successes, &error) && error && attempts == 91 && successes == 92 &&
        [before isEqual:Capture()] && gMirrors == mirrors && gSettingsNotices == notices,
        "metric source failure preserves bytes outputs mirrors and notifications"); gStore.testCheckpoint = nil;
    NSArray *badCounters = @[@(-1), @1.5, @"-1", @"1.5", @"1tail", @"", @[], @{}, @"18446744073709551615"];
    for (id value in badCounters) {
        CHECK(Seed(@{ @"clearAttemptCount": value }), "invalid metric counter baseline seeded");
        before = Capture(); mirrors = gMirrors; attempts = 91; successes = 92;
        CHECK(!PXRecordClearAttempt(NO, &attempts, &successes, &error) && error && attempts == 91 && successes == 92 &&
            [before isEqual:Capture()] && mirrors == gMirrors, "malformed metric counters fail without rewriting source or outputs");
    }
    unichar embeddedNull[] = { '1', 0, '2' };
    NSString *nullText = [[NSString alloc] initWithCharacters:embeddedNull length:3];
    CHECK(!PXClearMetricCount(nullText, &attempts), "embedded NUL metric text cannot truncate into a valid count");
    CHECK(Seed(@{ @"clearAttemptCount": @2, @"clearFirstAttemptSuccessCount": @3 }), "inconsistent metric baseline seeded"); before = Capture();
    CHECK(!PXRecordClearAttempt(NO, NULL, NULL, &error) && error && [before isEqual:Capture()], "inconsistent metric pair is preserved instead of silently repaired");
    CHECK(Seed(@{ @"clearAttemptCount": @(NSIntegerMax - 1), @"clearFirstAttemptSuccessCount": @(NSIntegerMax - 1) }) &&
        PXRecordClearAttempt(YES, &attempts, &successes, &error) && attempts == (NSUInteger)NSIntegerMax && successes == attempts,
        "metric boundary remains representable by legacy signed integer readers");
    before = Capture(); attempts = 91; successes = 92;
    CHECK(!PXRecordClearAttempt(NO, &attempts, &successes, &error) && error && attempts == 91 && successes == 92 && [before isEqual:Capture()],
        "exhausted metrics reject increment without integer wrap");
    CHECK([[@"bad security source" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:gPath atomically:YES], "corrupt metric source installed");
    before = Capture(); mirrors = gMirrors;
    CHECK(!PXRecordClearAttempt(NO, &attempts, &successes, &error) && error && [before isEqual:Capture()] && mirrors == gMirrors,
        "metric recording never replaces corrupt security root with empty defaults");
    CHECK([NSFileManager.defaultManager removeItemAtPath:gPath error:NULL] && Seed(@{ @"keep": @YES }), "concurrent metric baseline restored");
    dispatch_group_t group = dispatch_group_create(); NSMutableSet *returnedAttempts = [NSMutableSet new];
    static _Atomic NSUInteger metricFailures; atomic_store(&metricFailures, 0);
    for (NSUInteger worker = 0; worker < 4; worker++) dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            for (NSUInteger iteration = 0; iteration < 6; iteration++) {
                NSUInteger count = 0, first = 0; NSError *failure = nil;
                if (!PXRecordClearAttempt(worker % 2 == 0, &count, &first, &failure) || failure || first > count)
                    atomic_fetch_add(&metricFailures, 1);
                else @synchronized(returnedAttempts) { [returnedAttempts addObject:@(count)]; }
            }
        }
    });
    CHECK(dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC)) == 0 && !atomic_load(&metricFailures) &&
        returnedAttempts.count == 24 && [Load()[@"clearAttemptCount"] unsignedIntegerValue] == 24 &&
        [Load()[@"clearFirstAttemptSuccessCount"] unsignedIntegerValue] == 12 && [Load()[@"keep"] boolValue],
        "concurrent cooperating metric writers preserve all increments and paired totals");
}

static void TestSecurityScalarReaderTypes(void) {
    NSArray *invalid = @[@[], @{}, NSNull.null, NSDate.date, [NSData data], NSObject.new];
    for (id value in invalid) {
        gScalarReaderValue = value;
        CHECK(PXFixtureScalarBool(@"fixture", YES) && !PXFixtureScalarBool(@"fixture", NO) &&
            PXFixtureScalarInteger(@"fixture", 17) == 17 && PXFixtureScalarInteger(@"fixture", -3) == -3,
            "malformed security scalar types preserve supplied defaults without unsafe selectors");
    }
    for (id value in @[@0, @1, @(-3), @"0", @"YES", @"42", @"invalid"]) {
        gScalarReaderValue = value;
        CHECK(PXFixtureScalarBool(@"fixture", NO) == [value boolValue] && PXFixtureScalarInteger(@"fixture", 19) == [value integerValue],
            "valid security number and string conversions remain unchanged");
    }
    gScalarReaderValue = nil;
    CHECK(PXFixtureScalarBool(@"fixture", YES) && PXFixtureScalarInteger(@"fixture", 17) == 17, "missing scalar uses caller defaults");
#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    CHECK(Seed(@{ @"badBool": @[], @"badInteger": @{} }) && PXReadSecurityBool(@"badBool", YES) && PXReadSecurityInteger(@"badInteger", 23) == 23,
        "rootful live scalar reader rejects malformed on-disk field types");
#endif
}

static void TestDisplayPolicyWriters(void) {
    PXDisplayPolicyFixture *ui = [PXDisplayPolicyFixture new]; PXMonitorSwitch *sender = [PXMonitorSwitch new];
    ui.webCompatIOSRangeWarningLabel = [PXSecurityWarningLabel new];
    ui.webCompatIOSRangeWarningHeightConstraint = [PXSecurityWarningConstraint new];
    gDisplayPolicyVersion = @"17.0"; gCheckMirror = YES;
    for (NSUInteger policy = 0; policy < 2; policy++) {
        NSString *key = policy == 0 ? @"webCompatIOSRangeEnabled" : @"displayUIScaleSpoofEnabled";
        for (NSUInteger stored = 0; stored < 2; stored++) {
            NSDictionary *baseline = @{ key: @(stored), @"deviceSpoofingEnabled": @YES, @"keep": @"untouched" };
            CHECK(Seed(baseline), "display policy failure baseline seeded");
            NSDictionary *before = Capture(); NSUInteger notices = gSettingsNotices, mirrors = gMirrors, reads = gDisplayPolicyVersionReads;
            ui.webCompatIOSRangeWarningLabel.hidden = YES; ui.webCompatIOSRangeWarningHeightConstraint.constant = 7;
            sender.on = !stored; ui.toast = nil;
            gStore.testCheckpoint = ^(NSString *phase) {
                if ([phase isEqual:@"source-written"]) [NSException raise:@"fixture" format:@"display policy source failure"];
            };
            if (policy == 0) [ui webCompatIOSRangeToggleChanged:sender];
            else [ui displayUIScaleSpoofToggleChanged:sender];
            CHECK(sender.isOn == (BOOL)stored && [before isEqual:Capture()] && notices == gSettingsNotices && mirrors == gMirrors &&
                [ui.toast hasPrefix:@"Could not save"], "failed display policy write restores persisted switch without mirrors or notifications");
            CHECK(ui.webCompatIOSRangeWarningLabel.isHidden && ui.webCompatIOSRangeWarningHeightConstraint.constant == 7 && reads == gDisplayPolicyVersionReads,
                "failed display policy write leaves warning and version lookup untouched");
            gStore.testCheckpoint = nil;
        }
        // Missing keys keep legacy defaults (WebCompat OFF, configured UI Scale ON).
        CHECK(Seed(@{ @"keep": @YES }), "missing display policy key baseline seeded");
        sender.on = policy == 0;
        gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"]) [NSException raise:@"fixture" format:@"missing key fault"]; };
        if (policy == 0) [ui webCompatIOSRangeToggleChanged:sender]; else [ui displayUIScaleSpoofToggleChanged:sender];
        CHECK(sender.isOn == (policy == 1) && Load()[key] == nil, "failed display toggle preserves missing-key defaults and absence");
        gStore.testCheckpoint = nil;
        for (NSUInteger enabled = 0; enabled < 2; enabled++) {
            CHECK(Seed(@{ @"keep": @"untouched", @"deviceSpoofingEnabled": @YES }), "display policy success baseline seeded");
            NSUInteger attempts = atomic_load(&gAttempts), notices = gSettingsNotices, mirrors = gMirrors;
            __block NSUInteger commits = 0;
            gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"commit-written"]) commits++; };
            sender.on = (BOOL)enabled; ui.toast = nil;
            if (policy == 0) [ui webCompatIOSRangeToggleChanged:sender]; else [ui displayUIScaleSpoofToggleChanged:sender];
            CHECK([Load()[key] boolValue] == (BOOL)enabled && [Load()[@"keep"] isEqual:@"untouched"] &&
                atomic_load(&gAttempts) == attempts + 1 && commits == 1 && gSettingsNotices == notices + 1 && gMirrors == mirrors + 3 && !ui.toast,
                "display policy success commits once before all mirrors and one settings notification");
            gStore.testCheckpoint = nil;
        }
    }
    // Rollback follows source state even when sender is already stale/idempotent.
    CHECK(Seed(@{ @"webCompatIOSRangeEnabled": @YES }), "stale display sender baseline seeded"); sender.on = YES;
    gStore.testCheckpoint = ^(NSString *phase) { if ([phase isEqual:@"source-written"]) [NSException raise:@"fixture" format:@"stale sender fault"]; };
    [ui webCompatIOSRangeToggleChanged:sender]; CHECK(sender.isOn, "display rollback uses stored value rather than inverse sender state"); gStore.testCheckpoint = nil;

    NSArray *versions = @[@"16.3.1", @"16.3.2", @""];
    for (NSString *version in versions) {
        for (NSUInteger master = 0; master < 2; master++) {
            CHECK(Seed(@{ @"deviceSpoofingEnabled": @(master) }), "WebCompat warning baseline seeded");
            gDisplayPolicyVersion = version; sender.on = YES;
            [ui webCompatIOSRangeToggleChanged:sender];
            BOOL expected = master && [version isEqual:@"16.3.2"];
            CHECK(ui.webCompatIOSRangeWarningLabel.isHidden == !expected && ui.webCompatIOSRangeWarningHeightConstraint.constant == (expected ? 24 : 0),
                "WebCompat warning preserves strict version threshold and master dependency");
        }
    }
    ui.webCompatIOSRangeWarningHeightConstraint = nil; gDisplayPolicyVersion = nil;
    sender.on = YES; [ui webCompatIOSRangeToggleChanged:sender];
    CHECK(ui.webCompatIOSRangeWarningLabel.isHidden, "missing version and warning constraint are safe");
    __block NSUInteger controlsReturned = 0;
    for (NSUInteger policy = 0; policy < 2; policy++) {
        gDuringMirror = ^{ CHECK(NSThread.isMainThread, "background display action persists only after main handoff"); };
        sender.on = YES; NSUInteger notices = gSettingsNotices;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            if (policy == 0) [ui webCompatIOSRangeToggleChanged:sender]; else [ui displayUIScaleSpoofToggleChanged:sender];
            dispatch_async(dispatch_get_main_queue(), ^{ controlsReturned++; });
        });
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3];
        while (controlsReturned < policy + 1 && deadline.timeIntervalSinceNow > 0)
            @autoreleasepool { CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.005, YES); }
        CHECK(controlsReturned == policy + 1 && gSettingsNotices == notices + 1, "background display action completes on main without synchronous dispatch");
    }
    gDuringMirror = nil; gCheckMirror = NO; gDisplayPolicyVersion = nil;
}

int main(void) {
    @autoreleasepool {
        gRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        CHECK([NSFileManager.defaultManager createDirectoryAtPath:gRoot withIntermediateDirectories:YES attributes:nil error:NULL], "security test root created");
        gPath = [gRoot stringByAppendingPathComponent:@"security.plist"]; gMirrorGuard = NSObject.new; gSuites = NSMutableDictionary.new;
        gStore = [[PXRuntimeSourceStore alloc] initWithDirectory:[gRoot stringByAppendingPathComponent:@"control"] owner:geteuid() group:getegid()
            allowsPath:^BOOL(NSString *path) { return [path isEqual:gPath]; } error:NULL];
        CHECK(gStore != nil, "security source backend initialized");
        TestSecurityPackets(); TestNonceAndCanvas(); TestIPMonitorWriters(); TestRegionAndTimeZoneWriters(); TestClearMetricWriters(); TestSecurityScalarReaderTypes(); TestDisplayPolicyWriters();
        gStore = nil; [NSFileManager.defaultManager removeItemAtPath:gRoot error:NULL];
        printf("Runtime security writers: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
