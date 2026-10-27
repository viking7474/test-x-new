#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#import "PXSecuritySettingsStore.h"
#import "PXRuntimeSourceStore.h"
#import "PXRuntimeSnapshot.h"
#import "PXPaths.h"
#import "TLinkIOSLogging.h"
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
- (void)targetRegionFollowsIPToggleChanged:(PXMonitorSwitch *)sender;
@end
#define UISwitch PXMonitorSwitch
#define PXReadSecurityBool PXManagerReadSecurityBool
#define CFNotificationCenterGetDarwinNotifyCenter() ((CFNotificationCenterRef)(uintptr_t)1)
#define CFNotificationCenterPostNotification PXFixturePostDarwin
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
    [region targetRegionFollowsIPToggleChanged:sender];
    CHECK(!sender.isOn && [region.toast hasPrefix:@"Could not"] && [before isEqual:Capture()] && notices == gSettingsNotices && carriers == gRegionCarrierNotices && isos == gRegionISONotices,
          "region toggle rolls back failed persistence without publishing success");
    void (^faultCheckpoint)(NSString *) = gStore.testCheckpoint;
    gStore.testCheckpoint = nil;
    NSMutableDictionary *enabledLegacy = [legacy mutableCopy]; enabledLegacy[@"targetRegionFollowsIPEnabled"] = @YES;
    CHECK(Seed(enabledLegacy), "region failed disable baseline seeded"); before = Capture(); sender.on = NO;
    gStore.testCheckpoint = faultCheckpoint;
    [region targetRegionFollowsIPToggleChanged:sender];
    CHECK(sender.isOn && [before isEqual:Capture()] && notices == gSettingsNotices && carriers == gRegionCarrierNotices && isos == gRegionISONotices,
          "region toggle rolls back failed persistence without publishing success");
    gStore.testCheckpoint = nil;
    CHECK(Seed(legacy), "region successful toggles baseline seeded");
    sender.on = YES; [region targetRegionFollowsIPToggleChanged:sender];
    sender.on = NO; [region targetRegionFollowsIPToggleChanged:sender];
    CHECK(!sender.isOn && ![Load()[@"targetRegionFollowsIPEnabled"] boolValue] && notices + 2 == gSettingsNotices && carriers + 2 == gRegionCarrierNotices && isos + 2 == gRegionISONotices,
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

int main(void) {
    @autoreleasepool {
        gRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        CHECK([NSFileManager.defaultManager createDirectoryAtPath:gRoot withIntermediateDirectories:YES attributes:nil error:NULL], "security test root created");
        gPath = [gRoot stringByAppendingPathComponent:@"security.plist"]; gMirrorGuard = NSObject.new; gSuites = NSMutableDictionary.new;
        gStore = [[PXRuntimeSourceStore alloc] initWithDirectory:[gRoot stringByAppendingPathComponent:@"control"] owner:geteuid() group:getegid()
            allowsPath:^BOOL(NSString *path) { return [path isEqual:gPath]; } error:NULL];
        CHECK(gStore != nil, "security source backend initialized");
        TestSecurityPackets(); TestNonceAndCanvas(); TestIPMonitorWriters(); TestRegionAndTimeZoneWriters();
        gStore = nil; [NSFileManager.defaultManager removeItemAtPath:gRoot error:NULL];
        printf("Runtime security writers: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
