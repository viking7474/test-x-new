#import <Foundation/Foundation.h>
#import "PXWiFiHookResolver.h"
#include <stdio.h>

static NSUInteger gChecks, gFailures, gReads, gStages, gSets, gAcquires, gReleases;
static BOOL gHeld;
static NSString *gFault;
static id gProvider;
static NSDictionary *gSourceWiFi, *gSourceIDs;
static NSHashTable *gSelectionRoots, *gDataRoots, *gFrozenRoots, *gPreparedRoots, *gCallbackRoots;
static __weak id gMutationRoot, gMergedRoot;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
static BOOL Fault(NSString *value) { return [gFault isEqual:value]; }
static void Raise(void) { [NSException raise:@"fixture.resolver" format:@"controlled collaborator failure"]; }

@interface PXResolverTransaction : NSObject
- (NSDictionary *)dictionaryAtPath:(NSString *)path exists:(BOOL *)exists error:(NSError **)error;
- (NSDictionary *)dictionaryAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)setDictionary:(NSDictionary *)value atPath:(NSString *)path error:(NSError **)error;
@end
@implementation PXResolverTransaction
- (NSDictionary *)dictionaryAtPath:(NSString * __unsafe_unretained)path exists:(BOOL *)exists error:(NSError **)error {
    (void)error; gReads++;
    if ((Fault(@"read") && gReads == 2) || (Fault(@"commit-read") && gReads == 3)) Raise();
    if (exists) *exists = YES;
    return [path.lastPathComponent isEqual:@"wifi_info.plist"] ? gSourceWiFi : gSourceIDs;
}
- (NSDictionary *)dictionaryAtPath:(NSString * __unsafe_unretained)path error:(NSError **)error {
    return [self dictionaryAtPath:path exists:NULL error:error];
}
- (BOOL)setDictionary:(NSDictionary * __unsafe_unretained)value atPath:(NSString * __unsafe_unretained)path error:(NSError **)error {
    (void)path; (void)error; gSets++; gMergedRoot = value;
    if (Fault(@"merge")) Raise();
    return YES;
}
@end
static PXResolverTransaction *gTransaction;
@interface PXResolverMutation : NSObject
@property (nonatomic, copy) NSString *identityDirectory;
@property (nonatomic) BOOL active;
+ (instancetype)acquireWithIdentityResolver:(NSString *(^)(void))resolver error:(NSError **)error NS_RETURNS_RETAINED;
- (BOOL)performSourceWrite:(BOOL (^)(PXResolverTransaction *, NSError **))body error:(NSError **)error;
- (void)invalidate;
@end
@implementation PXResolverMutation
+ (instancetype)acquireWithIdentityResolver:(NSString *(^ __unsafe_unretained)(void))resolver error:(NSError **)error {
    (void)error; gAcquires++;
    [gCallbackRoots addObject:resolver];
    if (Fault(@"acquire")) Raise();
    PXResolverMutation *mutation = [self new]; mutation.identityDirectory = resolver();
    mutation.active = YES; gHeld = YES; gMutationRoot = mutation; return mutation;
}
- (BOOL)performSourceWrite:(BOOL (^ __unsafe_unretained)(PXResolverTransaction *, NSError **))body error:(NSError **)error {
    CHECK(gHeld, "resolver source callback holds its fixture capability");
    // Observe the caller's heap block without owning it. Inline argument copies
    // can leak the block itself even if its __block capture slots are cleared.
    [gCallbackRoots addObject:body];
    return body(gTransaction, error);
}
- (void)invalidate { if (self.active) { self.active = NO; gHeld = NO; gReleases++; } }
@end
// All throwing collaborators borrow input parameters. The fixture verifies the
// production caller's ownership; it must not invent independent callee leaks.
static NSString *PXValidatedProfileID(NSString * __unsafe_unretained value) {
    return [value isKindOfClass:NSString.class] && [value isEqual:@"a"] ? value : nil;
}
static NSString *PXProfileIdentityPath(NSString * __unsafe_unretained value) { return value ? @"/fixture/a/identity" : nil; }
static NSString *PXCurrentProfileInfoPath(void) { return @"/fixture/selection.plist"; }
static NSString *PXLegacyActiveProfileInfoPath(void) { return @"/fixture/legacy.plist"; }
static BOOL PXPerformStandaloneRuntimeSourceWrite(BOOL (^ __unsafe_unretained body)(PXResolverTransaction *, NSError **), NSError **error) {
    if (Fault(@"admission")) Raise();
    return body(gTransaction, error);
}
static NSDictionary *PXReadRuntimeProfileSelection(PXResolverTransaction * __unsafe_unretained tx,
    NSString * __unsafe_unretained central, NSString * __unsafe_unretained legacy, NSError **error) {
    (void)tx; (void)error;
    NSMutableDictionary *value = [@{ central: @{ @"info": @{ @"ProfileId": @"a" } }, legacy: @{ @"info": @{} } } mutableCopy];
    [gSelectionRoots addObject:value]; return value;
}
static BOOL PXRuntimeProfileSelectionMatches(PXResolverTransaction * __unsafe_unretained tx,
    NSDictionary * __unsafe_unretained selection, NSString * __unsafe_unretained central, NSString * __unsafe_unretained legacy, NSError **error) {
    (void)tx; (void)selection; (void)central; (void)legacy; (void)error;
    if (Fault(@"selection-match")) Raise();
    return YES;
}
static BOOL PXStageRuntimeWiFi(PXResolverTransaction * __unsafe_unretained tx,
    NSString * __unsafe_unretained identity, NSDictionary * __unsafe_unretained info, NSError **error) {
    (void)tx; (void)identity; (void)info; (void)error; gStages++;
    if (Fault(@"stage")) Raise();
    return YES;
}
@interface PXResolverThrowingPair : NSObject
@end
@implementation PXResolverThrowingPair
- (BOOL)isKindOfClass:(Class)type { return type == NSDictionary.class || [super isKindOfClass:type]; }
- (id)objectForKeyedSubscript:(id __unsafe_unretained)key { (void)key; Raise(); return nil; }
@end
static NSDictionary *PXPrepareRuntimeWiFiInfo(void) {
    id value = Fault(@"prepared-pair") ? (id)[PXResolverThrowingPair new] :
        [@{ @"ssid": @"generated", @"bssid": @"02:11:22:33:44:55" } mutableCopy];
    [gPreparedRoots addObject:value]; return value;
}
@interface NSPropertyListSerialization (ResolverCodec)
+ (NSData *)px_resolverDataWithPropertyList:(id)plist format:(NSPropertyListFormat)format options:(NSUInteger)options error:(NSError **)error;
+ (id)px_resolverPropertyListWithData:(NSData *)data options:(NSUInteger)options format:(NSPropertyListFormat *)format error:(NSError **)error;
@end
@implementation NSPropertyListSerialization (ResolverCodec)
+ (NSData *)px_resolverDataWithPropertyList:(id __unsafe_unretained)plist format:(NSPropertyListFormat)format options:(NSUInteger)options error:(NSError **)error {
    NSData *data = [self dataWithPropertyList:plist format:format options:options error:error];
    if (data) [gDataRoots addObject:data]; return data;
}
+ (id)px_resolverPropertyListWithData:(NSData * __unsafe_unretained)data options:(NSUInteger)options format:(NSPropertyListFormat *)format error:(NSError **)error {
    if (Fault(@"decode")) Raise();
    id value = [self propertyListWithData:data options:options format:format error:error];
    if (value) [gFrozenRoots addObject:value]; return value;
}
@end
#define PXRuntimeSourceTransaction PXResolverTransaction
#define PXProfileArtifactMutation PXResolverMutation
#define dataWithPropertyList px_resolverDataWithPropertyList
#define propertyListWithData px_resolverPropertyListWithData
// Entire resolver region is exact source, including all helpers and TLS state.
#include "PXWiFiResolverLifetime.inc"
#undef propertyListWithData
#undef dataWithPropertyList
#undef PXProfileArtifactMutation
#undef PXRuntimeSourceTransaction

static void Reset(NSString *fault) {
    gFault = fault; gHeld = NO;
    gReads = gStages = gSets = gAcquires = gReleases = 0;
    gSelectionRoots = [NSHashTable weakObjectsHashTable]; gDataRoots = [NSHashTable weakObjectsHashTable];
    gFrozenRoots = [NSHashTable weakObjectsHashTable]; gPreparedRoots = [NSHashTable weakObjectsHashTable];
    gMutationRoot = nil; gMergedRoot = nil;
    gCallbackRoots = [NSHashTable weakObjectsHashTable];
    gTransaction = [PXResolverTransaction new];
    gSourceWiFi = [@{ @"unused": @"wifi basis" } mutableCopy]; gSourceIDs = [@{ @"keep": @YES } mutableCopy];
    gProvider = Fault(@"provider-pair") ? (id)[PXResolverThrowingPair new] : nil;
    if (Fault(@"acquire") || Fault(@"decode")) gProvider = [@{ @"ssid": @"cached", @"bssid": @"mac" } mutableCopy];
}
static void TestFailure(NSString *fault) {
    Reset(fault);
    __weak id weakProvider = gProvider, weakWiFi = gSourceWiFi, weakIDs = gSourceIDs, weakTransaction = gTransaction;
    __weak id weakInput = nil, weakToken = nil;
    @autoreleasepool {
        NSMutableString *input = [@"a" mutableCopy]; weakInput = input;
        id token = [NSObject new]; weakToken = token;
        PXWiFiHookCacheReader reader = [^NSDictionary *(NSString * __unsafe_unretained target, NSError **error) {
            (void)target; (void)error; (void)[token class];
            CHECK(!gHeld, "resolver provider stays outside lifecycle capability"); return gProvider;
        } copy];
        NSError *error = nil; BOOL threw = NO;
        @try {
            NSDictionary *result = PXResolveHookWiFiInfo(input, reader, &error);
            CHECK(!result && error.code == 3023, "resolver preparation failure retains nil result and existing error code");
        } @catch (NSException *exception) { threw = [exception.name isEqual:@"fixture.resolver"]; }
        CHECK(threw == (Fault(@"admission") || Fault(@"acquire")), "resolver admission and acquisition exceptions retain propagation policy");
        CHECK(!gHeld && !gWiFiHookResolving && gReleases == gAcquires - (Fault(@"acquire") ? 1 : 0),
              "resolver failure releases owned capability and resets only its TLS admission");
        error = nil; reader = nil; token = nil; input = nil;
        gProvider = nil; gSourceWiFi = nil; gSourceIDs = nil; gTransaction = nil;
    }
    if (weakProvider || weakWiFi || weakIDs || weakTransaction || weakInput || weakToken || gMutationRoot || gMergedRoot ||
        gSelectionRoots.allObjects.count || gDataRoots.allObjects.count || gFrozenRoots.allObjects.count || gPreparedRoots.allObjects.count)
        fprintf(stderr, "DETAIL: resolver fault=%s provider=%d wifi=%d ids=%d tx=%d input=%d token=%d mutation=%d merged=%d selection=%lu data=%lu frozen=%lu prepared=%lu\n",
            fault.UTF8String, weakProvider != nil, weakWiFi != nil, weakIDs != nil, weakTransaction != nil, weakInput != nil,
            weakToken != nil, gMutationRoot != nil, gMergedRoot != nil, (unsigned long)gSelectionRoots.allObjects.count,
            (unsigned long)gDataRoots.allObjects.count, (unsigned long)gFrozenRoots.allObjects.count, (unsigned long)gPreparedRoots.allObjects.count);
    if (gCallbackRoots.allObjects.count)
        fprintf(stderr, "DETAIL: resolver fault=%s callbacks=%lu\n", fault.UTF8String, (unsigned long)gCallbackRoots.allObjects.count);
    CHECK(!gCallbackRoots.allObjects.count, "resolver exceptional exit releases its method argument blocks after pool drain");
    CHECK(!weakProvider && !weakWiFi && !weakIDs && !weakTransaction && !weakInput && !weakToken && !gMutationRoot && !gMergedRoot &&
          !gSelectionRoots.allObjects.count && !gDataRoots.allObjects.count && !gFrozenRoots.allObjects.count && !gPreparedRoots.allObjects.count,
          "resolver exceptional exit releases its retained inputs snapshots and block capture after pool drain");
}
static void TestSuccessAndNestedGuard(void) {
    Reset(nil);
    @autoreleasepool {
        __block BOOL nested = NO;
        NSDictionary *result = PXResolveHookWiFiInfo(@"a", ^NSDictionary *(NSString * __unsafe_unretained target, NSError **error) {
            (void)target; (void)error; NSError *failure = nil;
            nested = !PXResolveHookWiFiInfo(@"a", nil, &failure) && failure.code == 3025 && gWiFiHookResolving;
            return nil;
        }, NULL);
        CHECK(nested && [result[@"ssid"] isEqual:@"generated"] && gStages == 1 && gSets == 1 && !gHeld && !gWiFiHookResolving,
              "resolver nested rejection preserves outer guard and successful generated return ownership");
    }
    CHECK(!gCallbackRoots.allObjects.count, "resolver generated success releases method argument blocks after pool drain");
    gSourceWiFi = [@{ @"ssid": @"source", @"bssid": @"source-mac" } mutableCopy];
    @autoreleasepool {
        NSDictionary *source = PXResolveHookWiFiInfo(@"a", nil, NULL);
        CHECK(source == gSourceWiFi && !gHeld && !gWiFiHookResolving, "resolver existing source return survives snapshot cleanup without copying");
    }
    CHECK(!gCallbackRoots.allObjects.count, "resolver source hit releases method argument blocks after pool drain");
    Reset(nil); gProvider = [@{ @"ssid": @"cached", @"bssid": @"cache-mac" } mutableCopy];
    @autoreleasepool {
        NSDictionary *cached = PXResolveHookWiFiInfo(@"a", ^NSDictionary *(NSString * __unsafe_unretained target, NSError **error) {
            (void)target; (void)error; return gProvider;
        }, NULL);
        CHECK([cached[@"ssid"] isEqual:@"cached"] && !gStages && !gSets && gReleases == 1 && !gHeld && !gWiFiHookResolving,
              "resolver read-only cache return survives cleanup without seeding a write");
    }
    CHECK(!gCallbackRoots.allObjects.count, "resolver cache hit releases method argument blocks after pool drain");
    gProvider = nil; gSourceWiFi = nil; gSourceIDs = nil; gTransaction = nil;
}
int main(void) {
    @autoreleasepool {
        @try {
            for (NSString *fault in @[@"admission", @"acquire", @"provider-pair", @"decode", @"read", @"commit-read", @"selection-match", @"stage", @"merge", @"prepared-pair"])
                TestFailure(fault);
            TestSuccessAndNestedGuard();
        } @catch (NSException *exception) { gFailures++; fprintf(stderr, "FAIL: unexpected resolver exception: %s\n", exception.description.UTF8String); }
        printf("WiFi resolver lifetime: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
