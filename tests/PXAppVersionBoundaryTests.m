#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <os/lock.h>
#import <dispatch/dispatch.h>
#import "PXP1BFilters.h"
#include <stdatomic.h>
#include <stdio.h>
static NSString *root, *profileID = @"A";
static NSDictionary *nativeInfo, *nativeLocalized;
static BOOL scoped = YES, nativeThrows, nativeNil, scopeThrows, readThrows, nilTime, applyThrows;
static NSUInteger checks, failures, scopeReads, invalidations, nativeCalls[4];
static NSMutableDictionary *reads;
static dispatch_block_t duringRead, duringScope, duringStat;
static NSString *PXPreferencesPath(void) { return root; }
static NSString *PXSecuritySettingsPath(void) { return [root stringByAppendingPathComponent:@"security.plist"]; }
static NSString *PXActiveProfileID(void) { return profileID; }
static NSString *PXProfileRootPath(NSString *profile) { @try { return [[root stringByAppendingPathComponent:@"profiles"] stringByAppendingPathComponent:profile]; } @finally { profile=nil; } }
static void PXInvalidateScopeDecisionCache(void) { invalidations++; }
enum { PXScopeOptionNone = 0 };
static BOOL PXProcessIsAllowedForSpoofing(NSString *bundle,NSString *process,NSUInteger options);
static NSDictionary *PXNativeNS(NSBundle *bundle,NSUInteger index);
static NSFileManager *PXFixtureFiles(void);
static NSDictionary *PXFixtureRead(NSString *path);
static NSDictionary *PXFixtureApply(NSDictionary *original,NSString *version,NSString *build);
#include "PXAppVersionBoundaries.inc"
#define CHECK(value,label) do { checks++;if (!(value)) { failures++;fprintf(stderr,"FAIL: %s\n",label); } } while (0)
static void Raise(void) { [NSException raise:@"fixture" format:@"app version fault"]; }
static void Deliver(dispatch_block_t *slot) {
    dispatch_block_t callback = nil;@try { callback=*slot;*slot=nil;if (callback) callback(); } @finally { callback=nil; }
}
static BOOL PXProcessIsAllowedForSpoofing(NSString *bundle,NSString *process,NSUInteger options) {
    @try { (void)options;scopeReads++;Deliver(&duringScope);if (scopeThrows) Raise();return scoped; }
    @finally { bundle=nil;process=nil; }
}
static NSDictionary *PXNativeNS(NSBundle *bundle,NSUInteger index) {
    @try { (void)bundle;nativeCalls[index]++;if (nativeThrows) Raise();return nativeNil ? nil : (index ? nativeLocalized : nativeInfo); }
    @finally { bundle=nil; }
}
static CFDictionaryRef PXNativeCF(CFBundleRef bundle) { (void)bundle;nativeCalls[2]++;if (nativeThrows) Raise();return nativeNil ? NULL : (__bridge CFDictionaryRef)nativeInfo; }
static CFDictionaryRef PXNativeCFLocal(CFBundleRef bundle) { (void)bundle;nativeCalls[3]++;if (nativeThrows) Raise();return nativeNil ? NULL : (__bridge CFDictionaryRef)nativeLocalized; }
@interface PXAppVersionFiles : NSObject
- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error;
@end
@implementation PXAppVersionFiles
- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error {
    @try { Deliver(&duringStat);return nilTime ? nil : [[NSFileManager defaultManager] attributesOfItemAtPath:path error:error]; } @finally { path=nil; }
}
@end
static NSFileManager *PXFixtureFiles(void) { static PXAppVersionFiles *files;static dispatch_once_t once;dispatch_once(&once,^{files=[PXAppVersionFiles new];});return (id)files; }
static NSDictionary *PXFixtureRead(NSString *path) {
    NSDictionary *value=nil;
    @try {
        @synchronized(reads) { reads[path]=@([reads[path] unsignedIntegerValue]+1); }
        if (readThrows) Raise();value=[NSDictionary dictionaryWithContentsOfFile:path];
        if ([path hasSuffix:@"version_spoof.plist"]) Deliver(&duringRead);
        return value;
    } @finally { path=nil;value=nil; }
}
static NSString *GlobalPath(void) { return [root stringByAppendingPathComponent:@"com.hydra.tlinkios.version_spoof.plist"]; }
static void Write(NSString *path,NSDictionary *value) {
    @try { [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];CHECK([value writeToFile:path atomically:YES],"fixture plist seeded"); }
    @finally { path=nil;value=nil; }
}
static void Seed(NSString *version,NSString *build,BOOL enabled) {
    @try { NSMutableDictionary *entry=[@{@"spoofingEnabled":@(enabled)} mutableCopy];if (version) entry[@"spoofedVersion"]=version;if (build) entry[@"spoofedBuild"]=build;Write(GlobalPath(),@{@"SpoofedVersions":@{@"fixture.main":entry}}); }
    @finally { version=nil;build=nil; }
}
static NSDictionary *Call(NSUInteger route) {
    switch (route) {
        case 0:return PXHookNS0(NSBundle.mainBundle);
        case 1:return PXHookNS1(NSBundle.mainBundle);
        case 2:return (__bridge NSDictionary *)replaced_CFBundleGetInfoDictionary(CFBundleGetMainBundle());
        default:return (__bridge NSDictionary *)replaced_CFBundleGetLocalInfoDictionary(CFBundleGetMainBundle());
    }
}
static BOOL Version(NSDictionary *dict,NSString *expected) { @try { return [dict[@"CFBundleShortVersionString"] isEqual:expected]; } @finally { dict=nil;expected=nil; } }
static NSDictionary *PXFixtureApply(NSDictionary *original,NSString *version,NSString *build) {
    @try { if (applyThrows) Raise();return PXAppVersionApplyToInfoDictionary(original,version,build); }
    @finally { original=nil;version=nil;build=nil; }
}
// A length-only fault provider for the pure helper: it throws before any string
// is passed to Foundation. Real NSDictionary instances exercise clone cleanup.
@interface PXAppLengthFault : NSObject
@property (nonatomic,strong) NSObject *token;
@end
@implementation PXAppLengthFault
- (NSUInteger)length { Raise();return 0; }
@end
static void Boundaries(void) {
    Seed(@"2.0",@"20",YES);PXAppVersionHooksInvalidateCache();
    for (NSUInteger route=0;route<4;route++) {
        NSUInteger before=nativeCalls[route];NSDictionary *result=Call(route);
        CHECK((nativeCalls[route]==before+1 && Version(result,@"2.0") && [result[@"CFBundleVersion"] isEqual:@"20"] && [result[@"Unrelated"] isEqual:@"native"]),"four routes call native once and preserve unrelated metadata");
        CHECK(gPXAppVersionInfoRecursion==0,"normal route restores recursion");
        nativeThrows=YES;BOOL caught=NO;before=nativeCalls[route];@try { (void)Call(route); } @catch (__unused NSException *e) { caught=YES; }nativeThrows=NO;
        CHECK((caught && nativeCalls[route]==before+1 && !gPXAppVersionInfoRecursion),"native exception propagates once and cannot poison later calls");
        scopeThrows=YES;before=nativeCalls[route];CHECK((Call(route)==(route%2 ? nativeLocalized : nativeInfo) && nativeCalls[route]==before+1 && !gPXAppVersionInfoRecursion),"optional scope failure returns identical native result");scopeThrows=NO;
        nativeNil=YES;CHECK(Call(route)==nil,"nil native dictionaries remain nil");nativeNil=NO;
    }
    NSUInteger before=scopeReads;NSObject *foreign=[NSObject new];CHECK(PXHookNS0((id)foreign)==nativeInfo,"foreign NSBundle facade preserves native identity");CHECK(scopeReads==before,"foreign NSBundle skips scope and metadata work");
    scoped=NO;for (NSUInteger i=0;i<4;i++) CHECK(Call(i)==(i%2 ? nativeLocalized : nativeInfo),"unscoped paths retain native dictionary identity");scoped=YES;
    duringScope=^{ CHECK(PXHookNS0(NSBundle.mainBundle)==nativeInfo,"nested ObjC getter bypasses optional preparation");CHECK(replaced_CFBundleGetInfoDictionary(CFBundleGetMainBundle())==(__bridge CFDictionaryRef)nativeInfo,"cross-CF reentry bypasses optional preparation"); };
    CHECK(Version(Call(0),@"2.0"),"outer preparation survives independent native recursion");
    Write(PXSecuritySettingsPath(),@{@"appVersionSpoofingEnabled":@NO});CHECK(Call(0)==nativeInfo,"master OFF revokes projected value without stale cache hit");Write(PXSecuritySettingsPath(),@{@"appVersionSpoofingEnabled":@YES});
    original_CFBundleGetInfoDictionary=NULL;CHECK(Call(2)==nil,"missing CF original safely returns NULL");original_CFBundleGetInfoDictionary=PXNativeCF;
    original_CFBundleGetLocalInfoDictionary=NULL;CHECK(Call(3)==nil,"missing localized CF original safely returns NULL");original_CFBundleGetLocalInfoDictionary=PXNativeCFLocal;
    gMainBundleIDCached=nil;CHECK((Version(Call(0),@"2.0") && [gMainBundleIDCached isEqual:@"fixture.main"]),"lazy main identity uses original CF metadata without hooked bundleIdentifier recursion");
    NSString *aliasPath=[root stringByAppendingPathComponent:@"alias.bundle"];Write([aliasPath stringByAppendingPathComponent:@"Info.plist"],@{@"CFBundleIdentifier":@"fixture.main",@"CFBundlePackageType":@"BNDL",@"CFBundleVersion":@"1"});
    CFBundleRef alias=CFBundleCreate(kCFAllocatorDefault,(__bridge CFURLRef)[NSURL fileURLWithPath:aliasPath]);
    CHECK(alias!=NULL,"real alias CFBundle created for identity policy test");
    if (alias) {
        CHECK(Version((__bridge NSDictionary *)replaced_CFBundleGetInfoDictionary(alias),@"2.0"),"CF alias with the main identifier retains existing coverage");
        NSDictionary *saved=nativeInfo;nativeInfo=@{@"CFBundleIdentifier":@"fixture.other",@"Unrelated":@"foreign"};
        CHECK(replaced_CFBundleGetInfoDictionary(alias)==(__bridge CFDictionaryRef)nativeInfo,"different CF bundle identifier preserves identical native result");nativeInfo=saved;CFRelease(alias);
    }
}
static void SourceCaches(void) {
    NSString *__autoreleasing version=nil, *build=nil;
    PXAppVersionHooksInvalidateCache();Seed(@"3.0",@"30",YES);
    CHECK((PXGetSpoofedAppVersionForBundle(@"fixture.main",&version,&build) && [version isEqual:@"3.0"] && [build isEqual:@"30"]),"public output pair resolves enabled global fields");
    NSUInteger before=[reads[GlobalPath()] unsignedIntegerValue];CHECK(PXGetSpoofedAppVersionForBundle(@"fixture.main",NULL,NULL),"NULL output slots remain supported");CHECK([reads[GlobalPath()] unsignedIntegerValue]==before,"unchanged positive timestamp reuses parsed plist");
    // Guaranteed distinct metadata; no scheduler sleep or filesystem resolution assumption.
    Seed(@"4.0",@"40",YES);[[NSFileManager defaultManager] setAttributes:@{NSFileModificationDate:[NSDate dateWithTimeIntervalSince1970:1000]} ofItemAtPath:GlobalPath() error:NULL];
    CHECK(Version(Call(0),@"4.0"),"source change without notification invalidates projected version tuple");
    nativeInfo=@{@"CFBundleIdentifier":@"fixture.main",@"Unrelated":@"new-native",@"CFBundleShortVersionString":@"1.0"};
    CHECK([Call(0)[@"Unrelated"] isEqual:@"new-native"],"native dictionary changes are not hidden by generation-only caching");
    Seed(@"partial",nil,YES);PXAppVersionHooksInvalidateCache();Write([[PXProfileRootPath(@"A") stringByAppendingPathComponent:@"app_versions"] stringByAppendingPathComponent:@"fixture_main_version.plist"],@{@"spoofedBuild":@"A-build"});
    Write([[PXProfileRootPath(@"B") stringByAppendingPathComponent:@"app_versions"] stringByAppendingPathComponent:@"fixture_main_version.plist"],@{@"spoofedBuild":@"B-build"});
    CHECK((PXGetSpoofedAppVersionForBundle(@"fixture.main",&version,&build) && [version isEqual:@"partial"] && [build isEqual:@"A-build"]),"missing field falls back to active profile only");
    profileID=@"B";CHECK((PXGetSpoofedAppVersionForBundle(@"fixture.main",&version,&build) && [build isEqual:@"B-build"]),"new profile path does not reuse old profile fallback");profileID=@"A";
    Seed(@"disabled",@"disabled",NO);PXAppVersionHooksInvalidateCache();CHECK((!PXGetSpoofedAppVersionForBundle(@"fixture.main",&version,&build) && !version && !build),"disabled per-app record clears output slots");
    Write(GlobalPath(),@{@"SpoofedVersions":@{@"fixture.main":@{@"spoofingEnabled":@[]}}});PXAppVersionHooksInvalidateCache();CHECK(!PXGetSpoofedAppVersionForBundle(@"fixture.main",&version,&build),"malformed enabled scalar is contained");
    Write(PXSecuritySettingsPath(),@{@"appVersionSpoofingEnabled":@[]});CHECK(!PXAppVersionSpoofMasterEnabled(),"malformed master scalar is disabled");Write(PXSecuritySettingsPath(),@{@"appVersionSpoofingEnabled":@YES});
    Seed(@"uncached",@"50",YES);PXAppVersionHooksInvalidateCache();nilTime=YES;before=[reads[GlobalPath()] unsignedIntegerValue];(void)PXGetSpoofedAppVersionForBundle(@"fixture.main",NULL,NULL);(void)PXGetSpoofedAppVersionForBundle(@"fixture.main",NULL,NULL);nilTime=NO;
    CHECK([reads[GlobalPath()] unsignedIntegerValue]==before+2,"nil metadata cannot memoize positive data forever");
    readThrows=YES;CHECK((!PXGetSpoofedAppVersionForBundle(@"fixture.main",&version,&build) && !version && !build && !gPXAppVersionReading && !gPXAppVersionMasterReading),"provider exception clears outputs and releases admission");readThrows=NO;
}
static void Epochs(void) {
    Seed(@"epoch",@"60",YES);PXAppVersionHooksInvalidateCache();
    duringRead=^{ PXAppVersionHooksInvalidateCache(); };
    NSString *__autoreleasing version=nil,*build=nil;
    CHECK((!PXGetSpoofedAppVersionForBundle(@"fixture.main",&version,&build) && !version && !build && ![PXAppVersionCapture()[@"files"] count]),"invalidation during read cannot republish old files or acknowledge stale output");
    CHECK(Version(Call(0),@"epoch"),"a subsequent read converges after invalidation");
    duringScope=^{ PXAppVersionHooksInvalidateCache(); };
    CHECK(Call(0)==nativeInfo,"invalidation during scope work suppresses obsolete projection");
    NSDictionary *basis=PXAppVersionCapture();id epoch=basis[@"epoch"];
    CHECK(PXAppVersionStore(epoch,@"files",@"a",@{}),"same-epoch independent entry can publish");
    CHECK(PXAppVersionStore(epoch,@"files",@"b",@{}),"same-epoch merge preserves earlier entry");
    CHECK(([PXAppVersionCapture()[@"files"] objectForKey:@"a"] && [PXAppVersionCapture()[@"files"] objectForKey:@"b"]),"publication retains independent entries");
    PXAppVersionHooksInvalidateCache();CHECK(!PXAppVersionStore(epoch,@"files",@"stale",@{}),"obsolete epoch cannot write into new state");
    dispatch_group_t group=dispatch_group_create();__block atomic_uint wrong;atomic_init(&wrong,0);
    for (NSUInteger i=0;i<32;i++) dispatch_group_async(group,dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{ @autoreleasepool {
        if (!PXAppVersionStore(PXAppVersionCapture()[@"epoch"],@"files",[NSString stringWithFormat:@"parallel-%lu",(unsigned long)i],@{})) atomic_fetch_add(&wrong,1);
    }});
    CHECK((dispatch_group_wait(group,dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC))==0 && !atomic_load(&wrong) && [PXAppVersionCapture()[@"files"] count]==32),"concurrent immutable cache publications lose no entries");
}
static void Borrowed(void) {
    CFDictionaryRef borrowed=NULL;__weak NSDictionary *weakValue;
    @autoreleasepool { Seed(@"borrowed",@"70",YES);PXAppVersionHooksInvalidateCache();borrowed=replaced_CFBundleGetInfoDictionary(CFBundleGetMainBundle());weakValue=(__bridge NSDictionary *)borrowed; }
    PXAppVersionHooksInvalidateCache();
    CHECK((weakValue && Version((__bridge NSDictionary *)borrowed,@"borrowed")),"borrowed CF result stays alive across pool drain and invalidation without caller retain");
    CFRetain(borrowed);CFRelease(borrowed);CHECK(weakValue!=nil,"caller retain/release pair does not consume the process-owned borrowed value");
    NSUInteger count=gAppVersionBorrowedDictionaries.count;PXAppVersionHooksInvalidateCache();(void)replaced_CFBundleGetInfoDictionary(CFBundleGetMainBundle());CHECK(gAppVersionBorrowedDictionaries.count==count,"equal returned contents share one historical owner across epochs");
    nativeLocalized=@{@"Unrelated":@"localized-native"};NSDictionary *local=Call(3);CHECK([local[@"Unrelated"] isEqual:@"localized-native"],"localized CF projection retains independent native base");
    NSDictionary *basis=PXAppVersionCapture();(void)basis;
    __weak id weakInput;
    @autoreleasepool { NSMutableString *value=[@"temporary.bundle" mutableCopy];weakInput=value;readThrows=YES;(void)PXGetSpoofedAppVersionForBundle(value,NULL,NULL);readThrows=NO;value=nil; }
    CHECK((!weakInput && !gPXAppVersionReading),"failed source boundary releases detached caller input after pool drain");
    PXAppVersionHooksInvalidateCache();applyThrows=YES;
    CHECK((Call(0)==nativeInfo && !gPXAppVersionInfoRecursion),"projection factory exception preserves identical native dictionary and restores TLS");applyThrows=NO;
    __weak id weakFault,weakToken,weakDictionary;
    @autoreleasepool {
        PXAppLengthFault *fault=[PXAppLengthFault new];NSObject *token=[NSObject new];fault.token=token;NSDictionary *dictionary=@{@"token":token};weakFault=fault;weakToken=token;weakDictionary=dictionary;
        BOOL caught=NO;@try { (void)PXAppVersionApplyToInfoDictionary(dictionary,(id)fault,nil); } @catch (__unused NSException *e) { caught=YES; }
        CHECK(caught,"pure helper fault occurs after real mutable dictionary preparation");fault=nil;token=nil;dictionary=nil;
    }
    CHECK((!weakFault && !weakToken && !weakDictionary),"plain ARC pure projection failure releases input, partial clone and token after pool drain");
}
int main(void) {
    @autoreleasepool {
        root=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"px-app-version-" stringByAppendingString:NSUUID.UUID.UUIDString]];reads=[NSMutableDictionary dictionary];
        [[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:NO attributes:nil error:NULL];
        gMainBundleIDCached=@"fixture.main";original_CFBundleGetInfoDictionary=PXNativeCF;original_CFBundleGetLocalInfoDictionary=PXNativeCFLocal;
        nativeInfo=@{@"CFBundleIdentifier":@"fixture.main",@"CFBundleShortVersionString":@"1.0",@"CFBundleVersion":@"10",@"Unrelated":@"native"};nativeLocalized=nativeInfo;
        @try { Write(PXSecuritySettingsPath(),@{@"appVersionSpoofingEnabled":@YES});Boundaries();SourceCaches();Epochs();Borrowed(); }
        @finally { [[NSFileManager defaultManager] removeItemAtPath:root error:NULL];root=nil;reads=nil;nativeInfo=nil;nativeLocalized=nil;duringRead=nil;duringScope=nil;duringStat=nil; }
    }
    fprintf(stdout,"App-version boundaries: %lu/%lu checks passed\n",(unsigned long)(checks-failures),(unsigned long)checks);return failures ? 1 : 0;
}
