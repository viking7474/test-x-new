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
int main(void) {
    @autoreleasepool {
        gRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        CHECK([NSFileManager.defaultManager createDirectoryAtPath:gRoot withIntermediateDirectories:YES attributes:nil error:NULL], "security test root created");
        gPath = [gRoot stringByAppendingPathComponent:@"security.plist"]; gMirrorGuard = NSObject.new; gSuites = NSMutableDictionary.new;
        gStore = [[PXRuntimeSourceStore alloc] initWithDirectory:[gRoot stringByAppendingPathComponent:@"control"] owner:geteuid() group:getegid()
            allowsPath:^BOOL(NSString *path) { return [path isEqual:gPath]; } error:NULL];
        CHECK(gStore != nil, "security source backend initialized");
        TestSecurityPackets(); TestNonceAndCanvas();
        gStore = nil; [NSFileManager.defaultManager removeItemAtPath:gRoot error:NULL];
        printf("Runtime security writers: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
