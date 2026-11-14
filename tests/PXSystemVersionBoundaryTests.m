#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <os/lock.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#import "PXSystemVersionTransformer.h"
#import "PXIdentitySnapshot.h"
#import "PXRuntimeOSCompatibility.h"
#import "AppVersionHooks.h"
#include <stdio.h>
#include <string.h>
static NSUInteger checks, failures, nativeCalls[7], scopes, appReads, snapshotReads, captures;
static BOOL enabled = YES, scoped = YES, absentManager, originalThrows, policyThrows, reportingThrows, nativeNil, appThrows;
static void (*duringSnapshot)(void), (*duringApp)(void);
static NSDictionary *nativeDictionary;
static NSData *nativeData;
static NSString *nativeString;
static id nativeGet;
static id appVersion = @"4.2", appBuild = @"42";
static NSString *gPXIOSVersionMainBundleID = @"fixture.app";
static __thread BOOL gPXInsideIOSVersionBundleInfoHook, gPXInsideIOSVersionCFBundleInfoHook;
#define CHECK(value, label) do { checks++; if (!(value)) { failures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PX_RUNTIME_READ_OPERATION do { captures++; } while (0)
#define PXScopeOptionAllowSafariAuthStack 1
#define PXHookDiagnosticStageSystemVersionObserved 1
#define PXHookDiagnosticResultSuccess 1
static BOOL CFMatches(CFTypeRef value, CFTypeRef expected) { return value && expected && CFEqual(value, expected); }
static void Raise(void) { [NSException raise:@"fixture" format:@"fault"]; }
static void PXFileDebugSignalHookDiagnostic(int stage, int result) { (void)stage; (void)result; }
static BOOL PXLogOnceClaim(NSString *__unsafe_unretained key, NSString *__unsafe_unretained signature) { (void)key; (void)signature; return NO; }
static void PXFixtureLog(NSString *__unsafe_unretained format, ...) { (void)format; }
#define PXLog(...) PXFixtureLog(__VA_ARGS__)

@interface PXIdentitySnapshot ()
@property (nonatomic, copy, readwrite) NSDictionary *deviceIDs;
@property (nonatomic, copy, readwrite) NSString *profileID;
@property (nonatomic, readwrite) uint64_t generation;
@property (nonatomic, strong, readwrite) NSNumber *generationNumber;
@property (nonatomic, readwrite, getter=isValid) BOOL valid;
@end
@implementation PXIdentitySnapshot
- (NSDictionary *)settings { return @{}; }
- (NSDictionary *)specs { return @{}; }
- (NSString *)deviceModel { return nil; }
- (NSString *)source { return @"fixture"; }
- (NSDictionary *)validationIssues { return @{}; }
@end
static PXIdentitySnapshot *snapshot;
PXIdentitySnapshot *PXCurrentIdentitySnapshot(void) {
    snapshotReads++;
    void (*callback)(void) = duringSnapshot; duringSnapshot = NULL; if (callback) callback();
    if (policyThrows) Raise(); return snapshot;
}
BOOL PXReportingIOSVersionBuildForBundle(NSString *v, NSString *b, NSString *bundle, NSString **outV, NSString **outB) {
    @try { if (outV) *outV = v; if (reportingThrows) Raise(); if (outB) *outB = b; return YES; }
    @finally { v = nil; b = nil; bundle = nil; }
}
BOOL PXNativeSafeIOSVersionBuild(NSString *v, NSString *b, NSString **outV, NSString **outB) {
    @try { if (outV) *outV = v; if (reportingThrows) Raise(); if (outB) *outB = b; return YES; }
    @finally { v = nil; b = nil; }
}
NSString *PXRealRuntimeIOSVersion(void) { return @"15.8.8"; }
BOOL PXGetSpoofedAppVersionForBundle(NSString *bundle, NSString **outV, NSString **outB) {
    @try {
        appReads++; void (*callback)(void) = duringApp; duringApp = NULL; if (callback) callback();
        if (outV) *outV = appVersion;
        if (appThrows) Raise();
        if (outB) *outB = appBuild; return YES;
    } @finally { bundle = nil; }
}
static BOOL shouldSpoofForBundle(NSString *__unsafe_unretained bundle) { (void)bundle; scopes++; return scoped; }
static BOOL PXProcessIsAllowedForSpoofing(NSString *__unsafe_unretained bundle, NSString *__unsafe_unretained process, NSUInteger option) {
    (void)bundle; (void)process; (void)option; scopes++; return scoped;
}
@interface IdentifierManager : NSObject
+ (instancetype)sharedManager;
- (BOOL)isIdentifierEnabled:(NSString *)key;
@end
@implementation IdentifierManager
+ (instancetype)sharedManager { static IdentifierManager *manager; if (!manager) manager = [IdentifierManager new]; return absentManager ? nil : manager; }
- (BOOL)isIdentifierEnabled:(NSString *)key { (void)key; if (policyThrows) Raise(); return enabled; }
@end
static Class PXFixtureManagerClass(void) { return absentManager ? Nil : IdentifierManager.class; }
@interface PXBundleFacade : NSObject
- (id)objectForInfoDictionaryKey:(NSString *)key;
@end
static PXBundleFacade *mainBundle;
static PXBundleFacade *PXFixtureMainBundle(void) { return mainBundle; }
static CFBundleRef PXFixtureCFMainBundle(void) { return (__bridge CFBundleRef)mainBundle; }
static NSString *PXFixtureBundleID(void) { return gPXIOSVersionMainBundleID; }
static NSString *PXFixtureProcess(void) { return @"Fixture"; }
static NSString *getCurrentBundleID(void) { return gPXIOSVersionMainBundleID; }
static id PXOriginalObjCInfo(id __unsafe_unretained object, NSString *__unsafe_unretained key) { (void)object; (void)key; nativeCalls[5]++; if (originalThrows) Raise(); return nativeGet; }
static NSData *NativeData(Class cls, SEL sel, NSString *__unsafe_unretained path) { (void)cls; (void)sel; (void)path; nativeCalls[0]++; if (originalThrows) Raise(); return nativeNil ? nil : nativeData; }
static NSDictionary *NativeDictionary(Class cls, SEL sel, NSString *__unsafe_unretained path) { (void)cls; (void)sel; (void)path; nativeCalls[1]++; if (originalThrows) Raise(); return nativeNil ? nil : nativeDictionary; }
static id NativeString(Class cls, SEL sel, NSString *__unsafe_unretained path, NSStringEncoding encoding, NSError **error) {
    (void)cls; (void)sel; (void)path; (void)encoding; nativeCalls[2]++;
    if (originalThrows) Raise(); if (error) *error = [NSError errorWithDomain:@"native.fixture" code:7 userInfo:nil]; return nativeNil ? nil : nativeString;
}
static CFDictionaryRef NativeCopy(void) { nativeCalls[3]++; if (originalThrows) Raise(); return nativeNil ? NULL : CFBridgingRetain(nativeDictionary); }
static CFTypeRef NativeGet(CFBundleRef bundle, CFStringRef key) { (void)bundle; (void)key; nativeCalls[6]++; if (originalThrows) Raise(); return (__bridge CFTypeRef)nativeGet; }
static NSData *(*original_NSData_dataWithContentsOfFile)(Class, SEL, NSString *) = NativeData;
static NSDictionary *(*original_NSDictionary_dictionaryWithContentsOfFile)(Class, SEL, NSString *) = NativeDictionary;
static id (*original_NSString_stringWithContentsOfFile)(Class, SEL, NSString *, NSStringEncoding, NSError **) = NativeString;
static CFDictionaryRef (*original_CFCopySystemVersionDictionary)(void) = NativeCopy;
static CFDictionaryRef (*CFCopySystemVersionDictionary_orig)(void) = NativeCopy;
static CFTypeRef (*original_CFBundleGetValueForInfoDictionaryKey)(CFBundleRef, CFStringRef) = NativeGet;
#include "PXSystemReadWork.inc"
@implementation PXBundleFacade
#include "PXBundleInfoMethod.inc"
@end
extern void PXRunSystemVersionTransformerTests(void);
static NSString *path = @"/System/Library/CoreServices/SystemVersion.plist";
static void Reset(void) {
    enabled = scoped = YES; absentManager = originalThrows = policyThrows = reportingThrows = nativeNil = appThrows = NO;
    gPXInsideIOSVersionBundleInfoHook = gPXInsideIOSVersionCFBundleInfoHook = NO;
    duringSnapshot = duringApp = NULL;
    snapshot = [PXIdentitySnapshot new]; snapshot.valid = YES; snapshot.deviceIDs = @{@"IOSVersion": @"17.5.1", @"IOSBuild": @"21F90"};
    snapshot.profileID = @"profile"; snapshot.generationNumber = @1;
    nativeDictionary = @{@"ProductVersion": @"15.8.8", @"ProductBuildVersion": @"19H1", @"ReleaseType": @"Beta", @"Unknown": @"keep"};
    nativeData = [NSPropertyListSerialization dataWithPropertyList:nativeDictionary format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
    nativeString = [[NSString alloc] initWithData:nativeData encoding:NSUTF8StringEncoding];
    nativeGet = @"native"; appVersion = @"4.2"; appBuild = @"42";
    original_NSData_dataWithContentsOfFile = NativeData; original_NSDictionary_dictionaryWithContentsOfFile = NativeDictionary;
    original_NSString_stringWithContentsOfFile = NativeString; original_CFCopySystemVersionDictionary = NativeCopy;
    CFCopySystemVersionDictionary_orig = NativeCopy; original_CFBundleGetValueForInfoDictionaryKey = NativeGet;
    memset(nativeCalls, 0, sizeof(nativeCalls)); scopes = appReads = snapshotReads = captures = 0;
}
static BOOL Projected(NSDictionary *d) { return [d[@"ProductVersion"] isEqual:@"17.5.1"] && [d[@"ProductBuildVersion"] isEqual:@"21F90"] && [d[@"Unknown"] isEqual:@"keep"]; }
static void FileTests(void) {
    Reset();
    CHECK(Projected(replaced_NSDictionary_dictionaryWithContentsOfFile(NSDictionary.class, NULL, path)) && nativeCalls[1] == 1, "dictionary file projects once and preserves unknown keys");
    for (NSNumber *fmt in @[@(NSPropertyListXMLFormat_v1_0), @(NSPropertyListBinaryFormat_v1_0)]) {
        nativeData = [NSPropertyListSerialization dataWithPropertyList:nativeDictionary format:fmt.unsignedIntegerValue options:0 error:nil];
        NSData *result = replaced_NSData_dataWithContentsOfFile(NSData.class, NULL, path); NSPropertyListFormat actual = 0;
        NSDictionary *decoded = [NSPropertyListSerialization propertyListWithData:result options:0 format:&actual error:nil];
        CHECK(Projected(decoded) && actual == fmt.unsignedIntegerValue, "data file preserves XML/binary format and projection tuple");
    }
    NSError *error = nil;
    NSString *string = replaced_NSString_stringWithContentsOfFile(NSString.class, NULL, path, NSUTF8StringEncoding, &error);
    NSDictionary *decoded = [NSPropertyListSerialization propertyListWithData:[string dataUsingEncoding:NSUTF8StringEncoding] options:0 format:NULL error:nil];
    CHECK(Projected(decoded) && error.code == 7 && [error.domain isEqual:@"native.fixture"], "string projection preserves original error output and logical plist");
    NSData *savedData = nativeData;
    nativeData = [@"not a property list" dataUsingEncoding:NSUTF8StringEncoding];
    CHECK(replaced_NSData_dataWithContentsOfFile(NSData.class, NULL, path) == nativeData, "malformed SystemVersion bytes survive the real file boundary unchanged");
    nativeData = savedData; savedData = nil;
    NSUInteger reads = snapshotReads, scope = scopes;
    CHECK(replaced_NSData_dataWithContentsOfFile(NSData.class, NULL, @"/tmp/ordinary.plist") == nativeData && snapshotReads == reads && scopes == scope, "generic file bytes remain native without projection providers");
    for (int fault = 0; fault < 3; fault++) {
        enabled = fault != 0; scoped = fault != 1; policyThrows = fault == 2;
        CHECK(replaced_NSData_dataWithContentsOfFile(NSData.class, NULL, path) == nativeData, "data off/scope/provider fault preserves native object");
        CHECK(replaced_NSDictionary_dictionaryWithContentsOfFile(NSDictionary.class, NULL, path) == nativeDictionary, "dictionary off/scope/provider fault preserves native object");
        CHECK(replaced_NSString_stringWithContentsOfFile(NSString.class, NULL, path, NSUTF8StringEncoding, NULL) == nativeString, "string off/scope/provider fault preserves native object");
        CHECK(!PXSystemVersionProjectionActive(), "file projection fault restores shared guard");
    }
    Reset(); originalThrows = YES;
    for (int route = 0; route < 3; route++) {
        NSUInteger before = nativeCalls[route]; BOOL caught = NO;
        @try {
            if (route == 0) (void)replaced_NSData_dataWithContentsOfFile(NSData.class, NULL, path);
            if (route == 1) (void)replaced_NSDictionary_dictionaryWithContentsOfFile(NSDictionary.class, NULL, path);
            if (route == 2) (void)replaced_NSString_stringWithContentsOfFile(NSString.class, NULL, path, NSUTF8StringEncoding, NULL);
        } @catch (__unused NSException *e) { caught = YES; }
        CHECK(caught && nativeCalls[route] == before + 1 && !PXSystemVersionProjectionActive(), "each file native exception propagates once");
    }
    Reset(); nativeNil = YES;
    CHECK(!replaced_NSData_dataWithContentsOfFile(NSData.class, NULL, path) && !replaced_NSDictionary_dictionaryWithContentsOfFile(NSDictionary.class, NULL, path) && !replaced_NSString_stringWithContentsOfFile(NSString.class, NULL, path, NSUTF8StringEncoding, NULL), "nil native file reads never synthesize success");
    original_NSData_dataWithContentsOfFile = NULL; original_NSDictionary_dictionaryWithContentsOfFile = NULL; original_NSString_stringWithContentsOfFile = NULL;
    CHECK(!replaced_NSData_dataWithContentsOfFile(NSData.class, NULL, path) && !replaced_NSDictionary_dictionaryWithContentsOfFile(NSDictionary.class, NULL, path) && !replaced_NSString_stringWithContentsOfFile(NSString.class, NULL, path, NSUTF8StringEncoding, NULL), "missing file original pointers are safe nil");
}
static void NestedRead(void) {
    NSUInteger before = snapshotReads;
    CHECK(replaced_NSDictionary_dictionaryWithContentsOfFile(NSDictionary.class, NULL, path) == nativeDictionary && snapshotReads == before, "projection provider reentry reads native without recursively preparing identity");
}
static void CopyTests(void) {
    for (int route = 0; route < 2; route++) {
        Reset(); duringSnapshot = NestedRead;
        CFDictionaryRef result = route ? CFCopySystemVersionDictionary_hook() : replaced_CFCopySystemVersionDictionary();
        CHECK(result && Projected((__bridge NSDictionary *)result) && nativeCalls[3] == 1 && !PXSystemVersionProjectionActive(), "both Copy providers project once and share reentry guard");
        if (result) CFRelease(result);
        policyThrows = YES; result = route ? CFCopySystemVersionDictionary_hook() : replaced_CFCopySystemVersionDictionary();
        CHECK(result == (__bridge CFDictionaryRef)nativeDictionary && !PXSystemVersionProjectionActive(), "Copy policy exception preserves exact native owned result"); if (result) CFRelease(result);
        policyThrows = NO; originalThrows = YES; BOOL caught = NO; NSUInteger before = nativeCalls[3];
        @try { if (route) (void)CFCopySystemVersionDictionary_hook(); else (void)replaced_CFCopySystemVersionDictionary(); }
        @catch (__unused NSException *e) { caught = YES; }
        CHECK(caught && nativeCalls[3] == before + 1 && !PXSystemVersionProjectionActive(), "both Copy original exceptions propagate without replay");
        Reset(); nativeNil = YES;
        result = route ? CFCopySystemVersionDictionary_hook() : replaced_CFCopySystemVersionDictionary();
        CHECK(result && [((__bridge NSDictionary *)result)[@"ProductVersion"] isEqual:@"17.5.1"], "nil native Copy retains the existing empty-base projection behavior");
        if (result) CFRelease(result);
        Reset(); CFDictionaryRef owned = NULL; __weak NSObject *weakToken;
        @autoreleasepool {
            NSObject *token = [NSObject new]; weakToken = token;
            NSMutableDictionary *dict = [nativeDictionary mutableCopy]; dict[@"Unknown"] = token; nativeDictionary = [dict copy];
            owned = route ? CFCopySystemVersionDictionary_hook() : replaced_CFCopySystemVersionDictionary();
            nativeDictionary = nil; token = nil; dict = nil;
        }
        CHECK(weakToken != nil && owned != NULL, "Copy output independently owns transformed unknown objects after source and pool release");
        if (owned) CFRelease(owned);
        CHECK(!weakToken, "caller CFRelease balances Copy output without original/result ownership leak");
    }
}
static void CrossBundleReentry(void) {
    CHECK([mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] == nativeGet, "CF preparation reentry into Objective-C bundle uses native value");
}
static void CrossCFReentry(void) {
    CHECK(replaced_CFBundleGetValueForInfoDictionaryKey(PXFixtureCFMainBundle(), CFSTR("CFBundleVersion")) == (__bridge CFTypeRef)nativeGet, "Objective-C preparation reentry into CF bundle uses native value");
}
static void BundleTests(void) {
    Reset();
    CHECK([[mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] isEqual:@"4.2"] && nativeCalls[5] == 0, "main Objective-C app-version projection avoids original on accepted override");
    CHECK(CFMatches(replaced_CFBundleGetValueForInfoDictionaryKey(PXFixtureCFMainBundle(), CFSTR("CFBundleVersion")), CFSTR("42")) && nativeCalls[6] == 0, "main CF app-build projection is borrowed and avoids original");
    NSUInteger reads = appReads, scope = scopes, cap = captures;
    CHECK([mainBundle objectForInfoDictionaryKey:@"MinimumOSVersion"] == nativeGet && appReads == reads && scopes == scope && captures == cap, "binary metadata Objective-C key bypasses all app projection work");
    CHECK(replaced_CFBundleGetValueForInfoDictionaryKey(PXFixtureCFMainBundle(), CFSTR("DTSDKName")) == (__bridge CFTypeRef)nativeGet && appReads == reads && scopes == scope && captures == cap, "binary metadata CF key bypasses all app projection work");
    PXBundleFacade *foreign = [PXBundleFacade new];
    CHECK([foreign objectForInfoDictionaryKey:@"CFBundleVersion"] == nativeGet && appReads == reads, "foreign Objective-C bundle remains native");
    CHECK(replaced_CFBundleGetValueForInfoDictionaryKey((__bridge CFBundleRef)foreign, CFSTR("CFBundleVersion")) == (__bridge CFTypeRef)nativeGet && appReads == reads, "foreign CF bundle remains native");
    duringApp = CrossBundleReentry; (void)replaced_CFBundleGetValueForInfoDictionaryKey(PXFixtureCFMainBundle(), CFSTR("CFBundleVersion"));
    duringApp = CrossCFReentry; (void)[mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    appThrows = YES;
    CHECK([mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] == nativeGet && !gPXInsideIOSVersionBundleInfoHook, "Objective-C partial app output exception falls back and restores guard");
    CHECK(replaced_CFBundleGetValueForInfoDictionaryKey(PXFixtureCFMainBundle(), CFSTR("CFBundleVersion")) == (__bridge CFTypeRef)nativeGet && !gPXInsideIOSVersionCFBundleInfoHook, "CF partial app output exception falls back and restores guard");
    appThrows = NO; scoped = NO; originalThrows = YES;
    for (int route = 0; route < 2; route++) {
        BOOL caught = NO; NSUInteger before = nativeCalls[route ? 6 : 5];
        @try { if (route) (void)replaced_CFBundleGetValueForInfoDictionaryKey(PXFixtureCFMainBundle(), CFSTR("CFBundleVersion")); else (void)[mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"]; }
        @catch (__unused NSException *e) { caught = YES; }
        CHECK(caught && nativeCalls[route ? 6 : 5] == before + 1 && !gPXInsideIOSVersionBundleInfoHook && !gPXInsideIOSVersionCFBundleInfoHook, "both bundle fallback originals throw once without replay or guard poisoning");
    }
    Reset(); original_CFBundleGetValueForInfoDictionaryKey = NULL;
    for (int admitted = 0; admitted < 2; admitted++) {
        scoped = admitted;
        CHECK(CFMatches(replaced_CFBundleGetValueForInfoDictionaryKey(PXFixtureCFMainBundle(), CFSTR("MinimumOSVersion")), CFSTR("15.8.8")), "missing-original MinimumOSVersion uses physical fallback for scoped and unscoped main bundle");
    }
    CHECK(!replaced_CFBundleGetValueForInfoDictionaryKey((__bridge CFBundleRef)foreign, CFSTR("MinimumOSVersion")) && !replaced_CFBundleGetValueForInfoDictionaryKey(NULL, CFSTR("CFBundleVersion")) && !replaced_CFBundleGetValueForInfoDictionaryKey(PXFixtureCFMainBundle(), NULL), "foreign/nil CF arguments preserve null fallback");
    Reset(); appVersion = @[]; appBuild = nil;
    CHECK([mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] == nativeGet && replaced_CFBundleGetValueForInfoDictionaryKey(PXFixtureCFMainBundle(), CFSTR("CFBundleVersion")) == (__bridge CFTypeRef)nativeGet, "malformed or absent app fields cannot produce unsafe projections");
    Reset(); __weak NSObject *weakNative;
    @autoreleasepool {
        nativeGet = [NSObject new]; weakNative = nativeGet;
        CFTypeRef borrowed = replaced_CFBundleGetValueForInfoDictionaryKey(PXFixtureCFMainBundle(), CFSTR("DTSDKName"));
        CHECK(borrowed == (__bridge CFTypeRef)nativeGet, "native Get result pointer is preserved"); nativeGet = nil;
    }
    CHECK(!weakNative, "native borrowed Get passthrough adds no ownership leak");
}
static BOOL observeHash, throwHash, hashUnlocked, hashNestedRejected;
@interface PXHashString : NSString
@property (nonatomic, copy) NSString *text;
@end
@implementation PXHashString
- (NSUInteger)length { return self.text.length; }
- (unichar)characterAtIndex:(NSUInteger)index { return [self.text characterAtIndex:index]; }
- (void)getCharacters:(unichar *)buffer range:(NSRange)range { [self.text getCharacters:buffer range:range]; }
- (id)copyWithZone:(NSZone *)zone { (void)zone; return self; }
- (NSUInteger)hash {
    if (observeHash) {
        BOOL acquired = os_unfair_lock_trylock(&gPXBorrowedInfoLock); hashUnlocked = hashUnlocked && acquired;
        if (acquired) os_unfair_lock_unlock(&gPXBorrowedInfoLock);
        hashNestedRejected = PXIOSVersionBorrowedInfoString(@"nested-interner") == NULL;
        if (throwHash) Raise();
    }
    return self.text.hash;
}
@end
static void InternTests(void) {
    Reset(); CFStringRef preserved = NULL;
    @autoreleasepool {
        NSMutableString *value = [@"borrowed-stable-v1" mutableCopy]; preserved = PXIOSVersionBorrowedInfoString(value); [value setString:@"mutated"];
        CHECK(preserved && CFMatches(preserved, CFSTR("borrowed-stable-v1")), "borrowed override detaches mutable caller string");
    }
    CHECK(CFMatches(preserved, CFSTR("borrowed-stable-v1")) && preserved == PXIOSVersionBorrowedInfoString(@"borrowed-stable-v1"), "borrowed result survives caller pool and reuses pointer identity");
    PXHashString *probe = class_createInstance(PXHashString.class, 0); probe.text = @"hash-outside-lock";
    observeHash = throwHash = YES; hashUnlocked = YES; BOOL caught = NO;
    @try { (void)PXIOSVersionBorrowedInfoString(probe); } @catch (__unused NSException *e) { caught = YES; }
    CHECK(caught && hashUnlocked && hashNestedRejected && !gPXInterningInfoString, "throwing/reentrant key hashing runs outside lock and restores interner TLS");
    throwHash = NO;
    CHECK(PXIOSVersionBorrowedInfoString(probe) != NULL && hashUnlocked && !gPXInterningInfoString, "interner recovers after key exception without poisoned lock");
    observeHash = NO; probe = nil;
    CFStringRef results[16] = {0}; CFStringRef *slots = results;
    dispatch_group_t group = dispatch_group_create();
    for (int i = 0; i < 16; i++) dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        @autoreleasepool { NSString *value = [NSString stringWithFormat:@"parallel-%d", i]; slots[i] = PXIOSVersionBorrowedInfoString(value); value = nil; }
    });
    CHECK(dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0, "concurrent immutable-cache publications complete");
    for (int i = 0; i < 16; i++) {
        NSString *key = [NSString stringWithFormat:@"parallel-%d", i];
        CHECK(results[i] && results[i] == PXIOSVersionBorrowedInfoString(key), "racing cache writers preserve each other's borrowed entries");
    }
    CHECK(CFMatches(preserved, CFSTR("borrowed-stable-v1")), "cache replacement never expires an older borrowed result");
}
static void LifetimeTests(void) {
    Reset(); BOOL a = PXSystemVersionProjectionEnter(), b = PXSystemVersionProjectionEnter();
    CHECK(PXSystemVersionProjectionActive() && !a && b, "shared projection scope nests"); PXSystemVersionProjectionLeave(b);
    CHECK(PXSystemVersionProjectionActive(), "nested scope restores outer active state"); PXSystemVersionProjectionLeave(a);
    CHECK(!PXSystemVersionProjectionActive(), "outer shared scope resets");
    a = PXSystemVersionProjectionEnter();
    __block BOOL workerInitiallyActive = YES, workerPrevious = YES;
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        workerInitiallyActive = PXSystemVersionProjectionActive();
        workerPrevious = PXSystemVersionProjectionEnter();
        PXSystemVersionProjectionLeave(workerPrevious);
        dispatch_semaphore_signal(finished);
    });
    CHECK(dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0 &&
        !workerInitiallyActive && !workerPrevious && PXSystemVersionProjectionActive(), "projection scopes are thread local and independent");
    PXSystemVersionProjectionLeave(a);
    for (int route = 0; route < 2; route++) {
        __weak PXIdentitySnapshot *weakSnapshot;
        __weak NSString *weakProfileID;
        @autoreleasepool {
            Reset(); weakSnapshot = snapshot;
            NSString *profile = [[NSString alloc] initWithFormat:@"profile-%@", [NSUUID UUID].UUIDString];
            snapshot.profileID = profile; weakProfileID = snapshot.profileID; profile = nil;
            reportingThrows = YES;
            @try { if (route) (void)PXCurrentNativeSafeSystemVersionProjection(); else (void)PXCurrentReportingSystemVersionProjectionForBundle(@"fixture.app"); }
            @catch (__unused NSException *e) { }
            snapshot = nil;
        }
        CHECK(!weakSnapshot && !weakProfileID, "reporting/native-safe faults release captured snapshot and profile identifier after pool drain");
    }
    Reset(); reportingThrows = YES;
    CHECK(replaced_NSDictionary_dictionaryWithContentsOfFile(NSDictionary.class, NULL, path) == nativeDictionary && !PXSystemVersionProjectionActive(), "reporting policy failure falls back at the actual file boundary");
}
int main(void) {
    mainBundle = [PXBundleFacade new];
    @autoreleasepool { PXRunSystemVersionTransformerTests(); FileTests(); }
    @autoreleasepool { CopyTests(); }
    @autoreleasepool { BundleTests(); }
    @autoreleasepool { InternTests(); }
    @autoreleasepool { LifetimeTests(); }
    snapshot = nil; nativeDictionary = nil; nativeData = nil; nativeString = nil; nativeGet = nil; mainBundle = nil;
    fprintf(stdout, "SystemVersion boundaries: %lu/%lu checks passed\n", (unsigned long)(checks - failures), (unsigned long)checks);
    return failures ? 1 : 0;
}
