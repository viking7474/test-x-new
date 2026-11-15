#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <os/lock.h>
#import "PXRuntimeSnapshot.h"
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
typedef NS_ENUM(NSInteger, UIUserInterfaceStyle) { UIUserInterfaceStyleUnspecified, UIUserInterfaceStyleLight, UIUserInterfaceStyleDark };
@class UITraitCollection;
static UIUserInterfaceStyle PXFixtureScalarGetter(id __unsafe_unretained self);
static UITraitCollection *PXFixtureViewTraits(id __unsafe_unretained self);
#include "PXThemeState.inc"
static NSUInteger checks, failures, files, paths, captures, readerCaptures, clocks, bundles, scopes, logs, styleFactories, merges, native[6];
static BOOL allowed, safari, policyThrows, logThrows, nativeThrows, scopeInvalidateThrows, gPXFixtureIOS17;
static int factoryFault;
static double nowValue;
static NSDictionary *IDs, *artifact, *settings, *security, *legacySettings;
static id suiteValue;
static BOOL modernExists, legacyExists, securityExists, modernUnreadable, legacyUnreadable, securityUnreadable, settingsThrow;
static BOOL defaultsThrow;
static __weak id weakDefaults;
static NSUInteger settingsReads, securityReads, suiteReads, probes, viewSettingsReads, viewSecurityReads, viewIDReads;
static id view, receiver;
static __weak id weakReceiver;
static BOOL inspectReceiver;
static __weak id weakStyleTrait;
static void (*scopeAction)(void), (*fileAction)(void), (*dataFileAction)(void), (*factoryAction)(void);
#define CHECK(value, label) do { checks++; if (!(value)) { failures++; fprintf(stderr,"FAIL: %s\n",label); } } while (0)
static void Raise(void) { [NSException raise:@"fixture" format:@"theme fault"]; }
@interface UITraitCollection : NSObject
@property (nonatomic) UIUserInterfaceStyle nativeStyle;
@property (nonatomic, strong) id other;
- (UIUserInterfaceStyle)userInterfaceStyle;
+ (instancetype)traitCollectionWithUserInterfaceStyle:(UIUserInterfaceStyle)style;
+ (instancetype)traitCollectionWithTraitsFromCollections:(NSArray *)collections;
@end
@implementation UITraitCollection
- (UIUserInterfaceStyle)userInterfaceStyle { return PXFixtureScalarGetter(self); }
+ (instancetype)traitCollectionWithUserInterfaceStyle:(UIUserInterfaceStyle)style {
    styleFactories++; void (*action)(void) = factoryAction; factoryAction = NULL; if (action) action();
    if (factoryFault == 1) Raise(); if (factoryFault == 2) return nil;
    UITraitCollection *result = [UITraitCollection new]; weakStyleTrait = result; result.nativeStyle = style; return result;
}
+ (instancetype)traitCollectionWithTraitsFromCollections:(NSArray *)collections {
    UITraitCollection *base = nil, *style = nil, *result = nil;
    @try {
        merges++; base = collections[0]; style = collections[1];
        if (factoryFault == 3) Raise(); if (factoryFault == 4) return nil;
        result = [UITraitCollection new]; result.nativeStyle = style.nativeStyle; result.other = base.other; return result;
    } @finally { collections = nil; base = nil; style = nil; result = nil; }
}
@end
static UITraitCollection *nativeTraits;
@interface PXThemeView : NSObject
@property (nonatomic, strong) NSDictionary *ids;
@property (nonatomic, strong) NSDictionary *info;
@property (nonatomic, strong) NSDictionary *settings;
@property (nonatomic, strong) NSDictionary *security;
- (NSDictionary *)tlinkSettings;
- (NSDictionary *)securitySettings;
- (NSDictionary *)deviceIDs;
- (NSDictionary *)profileArtifact:(NSString *)key;
@end
@implementation PXThemeView
- (NSDictionary *)deviceIDs { viewIDReads++;return self.ids; }
- (NSDictionary *)tlinkSettings { viewSettingsReads++;if (settingsThrow) { view = nil;IDs = artifact = settings = security = nil;Raise(); }return self.settings; }
- (NSDictionary *)securitySettings { viewSecurityReads++;return self.security; }
- (NSDictionary *)profileArtifact:(NSString *)key { @try { (void)key; return self.info; } @finally { key = nil; } }
@end
@interface PXThemeReader : NSObject
- (PXRuntimeReadSnapshot *)capture;
@end
@implementation PXThemeReader
- (PXRuntimeReadSnapshot *)capture { readerCaptures++; return view; }
@end
void PXBeginRuntimeSnapshotOperation(PXRuntimeReadScope *scope) {
    static PXThemeReader *reader;
    if (!reader) reader = [PXThemeReader new];
    PXRuntimeReadScopeBegin(scope,(id)reader);
}
PXRuntimeReadSnapshot *PXCaptureRuntimeSnapshot(void) {
    captures++; BOOL scoped = NO; PXRuntimeReadSnapshot *current = PXRuntimeReadScopeCurrent(&scoped);
    return scoped ? current : view;
}
@interface PXThemeBundle : NSObject
- (NSString *)bundleIdentifier;
@end
@implementation PXThemeBundle
- (NSString *)bundleIdentifier { bundles++; return @"fixture.app"; }
@end
static NSBundle *PXFixtureMainBundle(void) { static PXThemeBundle *bundle; if (!bundle) bundle = [PXThemeBundle new]; return (id)bundle; }
static NSString *PXFixtureProcessName(void) { return @"fixture"; }
typedef NSUInteger PXScopeOptions;
static const PXScopeOptions PXScopeOptionNone = 0;
static BOOL PXIsSafariStackProcess(NSString *bundle, NSString *process) { @try { (void)bundle;(void)process;return safari; } @finally { bundle = nil; process = nil; } }
static BOOL PXProcessIsAllowedForSpoofing(NSString *bundle, NSString *process, PXScopeOptions options) {
    @try { (void)options; scopes++; void (*action)(void) = scopeAction; scopeAction = NULL; if (action) action(); if (policyThrows) Raise(); return allowed; }
    @finally { bundle = nil; process = nil; }
}
static void PXInvalidateScopeDecisionCache(void) { if (scopeInvalidateThrows) Raise(); }
static BOOL PXLogOnceClaim(NSString *space, NSString *bundle) { @try { (void)space;(void)bundle;return YES; } @finally { space = nil;bundle = nil; } }
void PXLog(NSString *format, ...) { @try { (void)format;logs++;if (logThrows) Raise(); } @finally { format = nil; } }
static int PXFixtureThemeClock(clockid_t clock, struct timespec *ts) {
    (void)clock; clocks++; if (!isfinite(nowValue)) return -1;
    ts->tv_sec = (time_t)floor(nowValue); ts->tv_nsec = (long)((nowValue - floor(nowValue)) * 1000000000.0); return 0;
}
NSString *PXActiveProfileIdentityPath(void) { paths++; return @"/profiles/frozen/identity"; }
NSString *PXTLinkIOSSettingsPath(void) { return @"/prefs/settings.plist"; }
NSString *PXSecuritySettingsPath(void) { return @"/prefs/security.plist"; }
NSString *PXPreferencesPath(void) { return @"/prefs"; }
@interface PXThemeFileManager : NSObject
- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error;
@end
@implementation PXThemeFileManager
- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error {
    @try {
        probes++;BOOL exists = legacyExists, unreadable = legacyUnreadable;
        if ([path isEqual:@"/prefs/settings.plist"]) { exists = modernExists;unreadable = modernUnreadable; }
        if ([path isEqual:@"/prefs/security.plist"]) { exists = securityExists;unreadable = securityUnreadable; }
        if (exists && !unreadable) return @{NSFileType:NSFileTypeRegular};
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:unreadable ? NSFileReadNoPermissionError : NSFileReadNoSuchFileError userInfo:nil];
        return nil;
    } @finally { path = nil; }
}
@end
static NSFileManager *PXFixtureThemeFileManager(void) { static PXThemeFileManager *files;if (!files) files = [PXThemeFileManager new];return (id)files; }
@interface PXThemeDefaults : NSObject
- (id)objectForKey:(NSString *)key;
@end
@implementation PXThemeDefaults
- (id)objectForKey:(NSString *)key { @try { (void)key;suiteReads++;if (defaultsThrow) Raise();return suiteValue; } @finally { key = nil; } }
@end
static NSUserDefaults *PXFixtureThemeDefaults(void) { PXThemeDefaults *defaults = [PXThemeDefaults new];weakDefaults = defaults;return (id)defaults; }
static NSDictionary *PXFixtureThemeFile(NSString *path) {
    @try {
        files++;void (*action)(void) = fileAction;fileAction = NULL;if (action) action();
        if ([path isEqual:@"/prefs/settings.plist"]) { settingsReads++;return settings; }
        if ([path isEqual:@"/prefs/com.hydra.tlinkios.plist"]) { settingsReads++;return legacySettings; }
        if ([path isEqual:@"/prefs/security.plist"]) { securityReads++;return security; }
        action = dataFileAction;dataFileAction = NULL;if (action) action();
        return [path hasSuffix:@"device_ids.plist"] ? IDs : artifact;
    } @finally { path = nil; }
}
static UIUserInterfaceStyle PXNativeStyle(id __unsafe_unretained object, NSUInteger kind) {
    native[kind]++;
    if (inspectReceiver) CHECK(weakReceiver != nil,"adapter pins receiver through foreign policy callback");
    if (nativeThrows) Raise();
    return [object isKindOfClass:UITraitCollection.class] ? ((UITraitCollection *)object).nativeStyle : UIUserInterfaceStyleLight;
}
static UITraitCollection *PXNativeTraits(id __unsafe_unretained object, NSUInteger kind) { (void)object;native[kind]++;if (nativeThrows) Raise();return nativeTraits; }
static NSInteger lastScheme;
static void PXNativeScheme(id __unsafe_unretained object, NSInteger value) { (void)object;native[5]++;lastScheme = value;if (nativeThrows) Raise(); }
#include "PXThemeWork.inc"
#include "PXThemeAdapters.inc"

static void SetData(NSDictionary *ids, NSDictionary *info) {
    @try { IDs = ids;artifact = info;PXThemeView *candidate = [PXThemeView new];candidate.ids = ids;candidate.info = info;candidate.settings = settings;candidate.security = security;view = candidate; }
    @finally { ids = nil;info = nil; }
}
static void SetSettings(NSDictionary *primary, NSDictionary *secondary) {
    @try { settings = primary;security = secondary;SetData(IDs,artifact); }
    @finally { primary = nil;secondary = nil; }
}
static void Fresh(void) {
    PXThemeInvalidateCache(); nowValue = 1000; allowed = YES;safari = policyThrows = logThrows = nativeThrows = scopeInvalidateThrows = NO;
    gPXFixtureIOS17 = YES;factoryFault = 0;scopeAction = fileAction = dataFileAction = factoryAction = NULL;inspectReceiver = NO;
    gPXThemePreparing = gPXThemeBypass = NO;gPXThemeTraitFactoriesAvailable = YES;
    receiver = [NSObject new];nativeTraits = [UITraitCollection new];nativeTraits.nativeStyle = UIUserInterfaceStyleLight;nativeTraits.other = @"other-traits";
    settings = @{@"EnabledIdentifiers":@{@"DeviceTheme":@YES}};security = @{};legacySettings = nil;suiteValue = nil;
    modernExists = securityExists = YES;legacyExists = settingsThrow = defaultsThrow = modernUnreadable = legacyUnreadable = securityUnreadable = NO;
    SetData(@{@"DeviceTheme":@"Dark"},nil);
    settingsReads = securityReads = suiteReads = probes = viewSettingsReads = viewSecurityReads = viewIDReads = 0;
    files = paths = captures = readerCaptures = clocks = bundles = scopes = logs = styleFactories = merges = 0;memset(native,0,sizeof(native));
}
static void CacheTests(void) {
    Fresh(); WeaponXThemeStyle style = WeaponXThemeStyleUnspecified;uint64_t ticket = 0;
    CHECK(!PXThemeCacheBegin(10,&style,&ticket),"cache miss claims a generation");uint64_t old = ticket;
    CHECK(PXThemeCachePublish(ticket,10,WeaponXThemeStyleDark, YES),"current candidate publishes");
    CHECK((PXThemeCacheBegin(310,&style,&ticket) && style == WeaponXThemeStyleDark),"300 second inclusive TTL boundary is preserved");
    CHECK(!PXThemeCacheBegin(310.001,&style,&ticket),"cache expires beyond TTL");
    CHECK(!PXThemeCachePublish(old,10,WeaponXThemeStyleLight, YES),"old cold candidate cannot overwrite newer miss");
    PXThemeInvalidateCache();CHECK(!PXThemeCachePublish(ticket,310.001,WeaponXThemeStyleLight, YES),"invalidation rejects pre-notification candidate");
    CHECK(!PXThemeCacheBegin(5,&style,&ticket),"fresh generation after invalidation");PXThemeCachePublish(ticket,5,WeaponXThemeStyleDark, YES);
    CHECK(!PXThemeCacheBegin(4,&style,&ticket),"clock rewind cannot keep a value fresh");PXThemeCachePublish(ticket,4,WeaponXThemeStyleDark, YES);
    CHECK(!PXThemeCacheBegin(NAN,&style,&ticket),"clock failure cannot reuse cache");PXThemeCachePublish(ticket,NAN,WeaponXThemeStyleDark, YES);
    CHECK(!PXThemeCacheBegin(5,&style,&ticket),"invalid timestamp never creates a fresh packet");
    PXThemeCachePublish(ticket,5,WeaponXThemeStyleUnspecified, YES);CHECK(!PXThemeCacheBegin(5,&style,&ticket),"unknown theme remains uncached");
    Fresh();CHECK(getThemeStyleFromProfile() == WeaponXThemeStyleDark,"primary theme is decoded");CHECK(getThemeStyleFromProfile() == WeaponXThemeStyleDark,"second profile read matches");
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    CHECK((captures == 2 && !clocks && !paths && !files),"RootHide uses one captured view per read and zero clock or live files");
#else
    CHECK((clocks == 2 && paths == 1 && files == 2 && settingsReads == 1 && !captures),"rootful warm read avoids repeated profile selection and file access");
#endif
    Fresh();SetData(@{@"DeviceTheme":@"Other"},@{@"value":@"Dark"});CHECK(getThemeStyleFromProfile() == WeaponXThemeStyleUnspecified,"unknown nonempty primary is not replaced by sidecar");
    Fresh();SetData(@{@"DeviceTheme":@12},@{@"value":@"Dark"});CHECK(getThemeStyleFromProfile() == WeaponXThemeStyleDark,"wrong primary type retains sidecar fallback");
    Fresh();SetData(@{@"DeviceTheme":@""},@{@"value":@"Light"});CHECK(getThemeStyleFromProfile() == WeaponXThemeStyleLight,"empty primary retains sidecar fallback");
    Fresh();SetData(nil,nil);CHECK(getThemeStyleFromProfile() == WeaponXThemeStyleLight,"absent data preserves legacy Light default");
    Fresh();SetData((id)@[],(id)@[]);CHECK(getThemeStyleFromProfile() == WeaponXThemeStyleLight,"malformed dictionaries preserve absent-data fallback");
}
static void DisableDuringScope(void) { SetSettings(@{@"EnabledIdentifiers":@{@"DeviceTheme":@NO}},@{@"deviceThemeSpoofEnabled":@YES}); }
static void DisableDuringData(void) { DisableDuringScope();PXThemeInvalidateCache(); }
static void ThrowFileRead(void) { Raise(); }
static void EnablementTests(void) {
    NSArray *primaryValues = @[@YES,@NO,@0,@2,@"YES",@"NO",@"1",@"0",@[],@{},NSNull.null];
    BOOL expected[] = {YES,NO,NO,YES,YES,NO,YES,NO,NO,NO,NO};
    for (NSUInteger index = 0; index < primaryValues.count; index++) {
        Fresh();SetSettings(@{@"EnabledIdentifiers":@{@"DeviceTheme":primaryValues[index]}},@{@"deviceThemeSpoofEnabled":@YES});
        CHECK((getThemeStyleFromProfile() == (expected[index] ? WeaponXThemeStyleDark : WeaponXThemeStyleUnspecified)),"present primary scalar decides even when secondary is true");
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        CHECK((!viewSecurityReads && !files && !paths && !suiteReads),"present captured primary never reads secondary or live sources");
#else
        CHECK((settingsReads == 1 && !securityReads && !suiteReads),"present rootful primary never reads secondary or defaults");
#endif
    }
    for (id bad in @[@{@"EnabledIdentifiers":@[]},@{@"EnabledIdentifiers":NSNull.null},@[],NSNull.null]) {
        Fresh();SetSettings(bad,@{@"deviceThemeSpoofEnabled":@YES});
        CHECK(getThemeStyleFromProfile() == WeaponXThemeStyleUnspecified,"malformed present primary root/map cannot infer enabled from secondary");
    }
    Fresh();SetSettings(@{},@{@"deviceThemeSpoofEnabled":@YES});CHECK(getThemeStyleFromProfile() == WeaponXThemeStyleDark,"missing primary can use secondary true");
    Fresh();SetSettings(@{@"EnabledIdentifiers":@{}},@{@"deviceThemeSpoofEnabled":@NO});CHECK(getThemeStyleFromProfile() == WeaponXThemeStyleUnspecified,"missing primary and secondary false stay off");
    Fresh();SetSettings(@{},@{@"deviceThemeSpoofEnabled":@[]});suiteValue = @YES;CHECK(getThemeStyleFromProfile() == WeaponXThemeStyleUnspecified,"invalid present secondary blocks any defaults fallback");
    Fresh();SetSettings(@{@"EnabledIdentifiers":@{@"DeviceTheme":@YES}},@{@"deviceThemeSpoofEnabled":@NO});CHECK(getThemeStyleFromProfile() == WeaponXThemeStyleDark,"primary true beats secondary false");
    Fresh();SetSettings(@{@"EnabledIdentifiers":@{@"DeviceTheme":@NO}},@{@"deviceThemeSpoofEnabled":@YES});
    CHECK((PXFixtureScalarGetter(receiver) == UIUserInterfaceStyleLight && PXFixtureEffectiveGetter(receiver) == UIUserInterfaceStyleLight),"both scalar getters return native when Theme is off");
    CHECK((PXFixtureScreenTraits(receiver) == nativeTraits && PXFixtureViewTraits(receiver) == nativeTraits && PXFixtureControllerTraits(receiver) == nativeTraits),"all three projection adapters preserve native objects when Theme is off");
    PXFixtureSetScheme(receiver,-9);CHECK((lastScheme == -9 && !styleFactories && !merges && !paths),"off private setter preserves raw value and no profile/factory work occurs");
    CHECK((native[0] == 1 && native[1] == 1 && native[2] == 1 && native[3] == 1 && native[4] == 1 && native[5] == 1),"all six off paths invoke native exactly once");
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    CHECK((!viewIDReads && !viewSecurityReads && !files && !clocks && !suiteReads),"off captured packet skips identity data without touching live state");
#else
    CHECK((settingsReads == 1 && files == 1 && gThemeCacheValid),"rootful off packet is cached across all six adapters");
#endif
    SetSettings(@{@"EnabledIdentifiers":@{@"DeviceTheme":@YES}},nil);
    themeSettingsChanged(NULL,NULL,CFSTR("toggle"),NULL,NULL);
    CHECK(PXFixtureScalarGetter(receiver) == UIUserInterfaceStyleDark,"already-installed Theme hooks enable after refreshed settings notification");
    SetSettings(@{@"EnabledIdentifiers":@{@"DeviceTheme":@NO}},@{@"deviceThemeSpoofEnabled":@YES});
    themeSettingsChanged(NULL,NULL,CFSTR("toggle"),NULL,NULL);
    CHECK(PXFixtureScalarGetter(receiver) == UIUserInterfaceStyleLight,"disable notification revokes a warm positive packet despite stale secondary true");
    Fresh();scopeAction = DisableDuringScope;UIUserInterfaceStyle current = PXFixtureScalarGetter(receiver);
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    CHECK((current == UIUserInterfaceStyleDark && readerCaptures == 1 && captures == 1),"captured enabled decision and theme use one view through a concurrent disable");
    CHECK(PXFixtureScalarGetter(receiver) == UIUserInterfaceStyleLight,"next captured operation observes disabled successor view");
    Fresh();settingsThrow = YES;CHECK((PXFixtureScalarGetter(receiver) == UIUserInterfaceStyleLight && !gPXThemePreparing),"captured settings exception falls back native and restores preparation guard");
#else
    CHECK(current == UIUserInterfaceStyleLight,"rootful operation observes live disable after scope preparation");
    Fresh();dataFileAction = DisableDuringData;
    CHECK((PXFixtureScalarGetter(receiver) == UIUserInterfaceStyleLight && !gThemeCacheValid),"disable during identity read rejects the old enabled candidate");
    CHECK((PXFixtureScalarGetter(receiver) == UIUserInterfaceStyleLight && gThemeCacheValid),"next cold read adopts a resolved off packet");
    Fresh();modernExists = NO;legacyExists = YES;legacySettings = @{@"EnabledIdentifiers":@{@"DeviceTheme":@YES}};
    CHECK(getThemeStyleFromProfile() == WeaponXThemeStyleDark,"legacy primary works only when modern source is absent");
    Fresh();modernUnreadable = YES;legacyExists = YES;legacySettings = @{@"EnabledIdentifiers":@{@"DeviceTheme":@YES}};suiteValue = @YES;
    CHECK((getThemeStyleFromProfile() == WeaponXThemeStyleUnspecified && !settingsReads && !suiteReads),"inaccessible modern source blocks legacy and defaults fallback");
    Fresh();modernExists = NO;legacyUnreadable = YES;suiteValue = @YES;
    CHECK((getThemeStyleFromProfile() == WeaponXThemeStyleUnspecified && !suiteReads),"inaccessible legacy source blocks secondary inference");
    Fresh();SetSettings(@{},@{});securityUnreadable = YES;suiteValue = @YES;
    CHECK((getThemeStyleFromProfile() == WeaponXThemeStyleUnspecified && !suiteReads),"inaccessible security source blocks defaults inference");
    Fresh();SetSettings(@{},@{});suiteValue = @YES;CHECK(getThemeStyleFromProfile() == WeaponXThemeStyleDark,"genuinely missing disk key retains legacy defaults fallback");
    Fresh();fileAction = ThrowFileRead;CHECK((PXFixtureScalarGetter(receiver) == UIUserInterfaceStyleLight && !gThemeCacheValid && !gPXThemePreparing),"throwing source read neither supplies an override nor poisons cache or TLS");
    CHECK(PXFixtureScalarGetter(receiver) == UIUserInterfaceStyleDark,"next operation recovers after a transient settings read exception");
#endif
    Fresh();WeaponXThemeStyle style = WeaponXThemeStyleDark;uint64_t ticket = 0;
    (void)PXThemeCacheBegin(10,&style,&ticket);PXThemeCachePublish(ticket,10,WeaponXThemeStyleDark,NO);
    CHECK((PXThemeCacheBegin(10,&style,&ticket) && style == WeaponXThemeStyleUnspecified),"a cacheable off packet can never expose its discarded style");
}
static void InvalidateDuringRead(void) { PXThemeInvalidateCache(); }
static void ReplaceDuringScope(void) { SetData(@{@"DeviceTheme":@"Light"},nil); }
static void PolicyTests(void) {
    Fresh();CHECK((PXFixtureScalarGetter(receiver) == UIUserInterfaceStyleDark && !native[0] && bundles == 1 && scopes == 1),"scalar override reads identity and scope once");
    allowed = NO;CHECK((PXFixtureScalarGetter(receiver) == UIUserInterfaceStyleLight && native[0] == 1),"scope revocation bypasses an otherwise warm theme");
    Fresh();safari = YES;CHECK((PXFixtureScalarGetter(receiver) == UIUserInterfaceStyleLight && !scopes && !files),"Safari exclusion precedes policy and profile work");
    Fresh();policyThrows = YES;CHECK((PXFixtureScalarGetter(receiver) == UIUserInterfaceStyleLight && native[0] == 1 && !gPXThemePreparing),"policy fault falls through to native and restores guard");
    Fresh();logThrows = YES;CHECK((PXFixtureScalarGetter(receiver) == UIUserInterfaceStyleDark && !native[0]),"diagnostic failure cannot negate a valid scalar override");
    PXThemeLogInstallation(@"constructor",nil);CHECK(!gPXThemePreparing,"constructor logging faults are optional");
    Fresh();gPXFixtureIOS17 = NO;CHECK((PXFixtureEffectiveGetter(receiver) == UIUserInterfaceStyleLight && native[1] == 1 && !scopes),"effective getter preserves pre-iOS17 native behavior");
    Fresh();PXFixtureSetScheme(receiver,-7);CHECK((lastScheme == 1 && native[5] == 1),"private setter keeps dark mapping");
    SetData(@{@"DeviceTheme":@"Light"},nil);PXThemeInvalidateCache();PXFixtureSetScheme(receiver,-7);CHECK(lastScheme == 0,"private setter keeps light mapping");
    allowed = NO;PXFixtureSetScheme(receiver,-7);CHECK(lastScheme == -7,"private setter forwards original raw value when unscoped");
    Fresh();scopeAction = ReplaceDuringScope;UIUserInterfaceStyle result = PXFixtureScalarGetter(receiver);
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    CHECK((result == UIUserInterfaceStyleDark && readerCaptures == 1 && captures == 1),"RootHide policy and theme inherit one original view despite replacement");
#else
    CHECK(result == UIUserInterfaceStyleLight,"rootful reads live profile sources after policy");
    Fresh();fileAction = InvalidateDuringRead;CHECK(PXFixtureScalarGetter(receiver) == UIUserInterfaceStyleLight,"invalidation during rootful read suppresses stale override");
    CHECK(!gThemeCacheValid,"invalidated candidate never repopulates cache");
#endif
}
static UIUserInterfaceStyle reenteredStyle;
static UITraitCollection *reenteredTraits;
static void FactoryReentry(void) { reenteredStyle = PXFixtureScalarGetter(nativeTraits);reenteredTraits = PXFixtureViewTraits(receiver); }
static void ProjectionTests(void) {
    Fresh();UITraitCollection *projected = PXFixtureScreenTraits(receiver);
    CHECK((projected != nativeTraits && projected.nativeStyle == UIUserInterfaceStyleDark && [projected.other isEqual:@"other-traits"]),"projection changes style while preserving unrelated traits");
    CHECK((native[2] == 1 && styleFactories == 1 && merges == 1 && !gPXThemePreparing && !gPXThemeBypass),"screen original runs once and preparation guards restore");
    Fresh();SetData(@{@"DeviceTheme":@"Light"},nil);
    CHECK((PXFixtureScreenTraits(receiver) == nativeTraits && PXFixtureViewTraits(receiver) == nativeTraits && PXFixtureControllerTraits(receiver) == nativeTraits && !styleFactories && !merges),"matching native style preserves native object without factories or merge array");
    Fresh();nativeTraits = nil;CHECK((PXFixtureViewTraits(receiver) == nil && native[3] == 1 && !scopes && !files),"nil native trait result never forms an array literal or enters policy");
    for (int fault = 1; fault <= 4; fault++) { Fresh();factoryFault = fault;CHECK((PXFixtureControllerTraits(receiver) == nativeTraits && native[4] == 1 && !gPXThemePreparing && !gPXThemeBypass),"throwing or nil factories preserve original and unwind guards"); }
    @autoreleasepool { Fresh();factoryFault = 3;(void)PXFixtureViewTraits(receiver); }
    CHECK(!weakStyleTrait,"failed merge releases partial style trait and input array after pool drain");
    Fresh();factoryAction = FactoryReentry;projected = PXFixtureViewTraits(receiver);
    CHECK((projected.nativeStyle == UIUserInterfaceStyleDark && reenteredStyle == UIUserInterfaceStyleLight && reenteredTraits == nativeTraits && styleFactories == 1 && merges == 1),"factory reentry returns native traits and scalar style without recursive projection");
    reenteredTraits = nil;
    Fresh();gPXThemeTraitFactoriesAvailable = NO;CHECK((PXFixtureViewTraits(receiver) == nativeTraits && !scopes && !styleFactories),"missing construction capability bypasses projection before providers");
    for (NSUInteger kind = 0; kind < 6; kind++) {
        Fresh();allowed = NO;nativeThrows = YES;BOOL caught = NO;
        @try { switch (kind) {case 0:(void)PXFixtureScalarGetter(receiver);break;case 1:(void)PXFixtureEffectiveGetter(receiver);break;case 2:(void)PXFixtureScreenTraits(receiver);break;case 3:(void)PXFixtureViewTraits(receiver);break;case 4:(void)PXFixtureControllerTraits(receiver);break;default:PXFixtureSetScheme(receiver,8);break;} }
        @catch (__unused NSException *e) { caught = YES; }
        CHECK((caught && native[kind] == 1 && !gPXThemePreparing && !gPXThemeBypass),"each native exception propagates once without replay");
    }
}
static void DropReceiverAndThrow(void) { receiver = nil;Raise(); }
static void DropInputsAndThrow(void) { view = nil;IDs = artifact = settings = security = nil;Raise(); }
static void LifecycleTests(void) {
    Fresh();(void)getThemeStyleFromProfile();scopeInvalidateThrows = logThrows = YES;
    themeSettingsChanged(NULL,NULL,CFSTR("fixture"),NULL,NULL);
    CHECK(!gThemeCacheValid,"notification invalidates first even if scope refresh and logging throw");
    __weak id owner;
    @autoreleasepool {
        Fresh();owner = receiver;weakReceiver = receiver;inspectReceiver = YES;scopeAction = DropReceiverAndThrow;
        CHECK(PXFixtureScalarGetter(receiver) == UIUserInterfaceStyleLight,"receiver survives scope fault until native fallback");
    }
    CHECK(!owner,"precise receiver pin is released after adapter return and pool drain");
    __weak id snapshot, token;
    @autoreleasepool {
        Fresh();NSObject *input = [NSObject new];token = input;SetData(@{@"DeviceTheme":@"Dark",@"token":input},nil);snapshot = view;input = nil;
        scopeAction = DropInputsAndThrow;(void)PXFixtureScalarGetter(receiver);
    }
    CHECK((!snapshot && !token),"faulting operation releases retained view and its inputs after pool drain");
    @autoreleasepool {
        Fresh();NSObject *input = [NSObject new];token = input;
        SetSettings(@{@"EnabledIdentifiers":@{@"DeviceTheme":@YES},@"token":input},nil);snapshot = view;input = nil;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        settingsThrow = YES;
#else
        fileAction = DropInputsAndThrow;
#endif
        CHECK(PXFixtureScalarGetter(receiver) == UIUserInterfaceStyleLight,"settings provider exceptional exit preserves native fallback");
    }
    CHECK((!snapshot && !token),"exceptional settings read releases captured snapshot and dictionary inputs after pool drain");
#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    @autoreleasepool {
        Fresh();SetSettings(@{},@{});defaultsThrow = YES;
        CHECK((PXFixtureScalarGetter(receiver) == UIUserInterfaceStyleLight && !gThemeCacheValid),"defaults failure supplies no override and cannot publish a positive cache");
    }
    CHECK(!weakDefaults,"plain ARC defaults failure releases the newly created defaults owner after pool drain");
#endif
    BOOL has = NO;(void)PXRuntimeReadScopeCurrent(&has);CHECK(!has,"real lexical operation scope is gone after failure");
}
static NSInteger DummyGetter(id self, SEL cmd) { (void)self;(void)cmd;return 0; }
static void DummySetter(id self, SEL cmd, NSInteger value) { (void)self;(void)cmd;(void)value; }
static void ABITests(void) {
    CHECK(PXThemeMethodSupported(UITraitCollection.class,@selector(userInterfaceStyle),@encode(NSInteger),NULL),"real facade scalar ABI accepted");
    CHECK(PXThemeMethodSupported(object_getClass(UITraitCollection.class),@selector(traitCollectionWithUserInterfaceStyle:),@encode(id),@encode(NSInteger)),"class factory ABI accepted");
    Class cls = objc_allocateClassPair(NSObject.class,"PXThemeABI",0);
    class_addMethod(cls,@selector(qualified),(IMP)DummyGetter,"rq@:");class_addMethod(cls,@selector(wrong),(IMP)DummyGetter,"d@:");
    class_addMethod(cls,@selector(extra:),(IMP)DummyGetter,"q@:@");class_addMethod(cls,@selector(setStyle:),(IMP)DummySetter,"v@:q");
    class_addMethod(cls,@selector(block:),(IMP)DummySetter,"v@:@?");objc_registerClassPair(cls);
    CHECK((PXThemeMethodSupported(cls,@selector(qualified),@encode(NSInteger),NULL) && !PXThemeMethodSupported(cls,@selector(wrong),@encode(NSInteger),NULL)),"qualified integer accepted and incompatible scalar rejected");
    CHECK((!PXThemeMethodSupported(cls,@selector(extra:),@encode(NSInteger),NULL) && PXThemeMethodSupported(cls,@selector(setStyle:),@encode(void),@encode(NSInteger))),"argument arity and private setter scalar ABI checked");
    CHECK((!PXThemeMethodSupported(cls,@selector(block:),@encode(void),@encode(id)) && !PXThemeMethodSupported(cls,NSSelectorFromString(@"missing"),@encode(id),NULL) && !PXThemeMethodSupported(Nil,@selector(description),@encode(id),NULL)),"block object mismatch and missing method/class are rejected");
}
int main(void) {
    @autoreleasepool { CacheTests();EnablementTests();PolicyTests();ProjectionTests();LifecycleTests();ABITests(); }
    view = receiver = nativeTraits = nil;IDs = artifact = settings = security = legacySettings = nil;suiteValue = nil;reenteredTraits = nil;
    fprintf(stdout,"Theme boundaries: %lu/%lu checks passed\n",(unsigned long)(checks-failures),(unsigned long)checks);
    return failures ? 1 : 0;
}
