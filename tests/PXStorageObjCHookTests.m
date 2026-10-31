#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static NSUInteger gChecks, gFailures, gOriginalCalls, gByteReads, gOperations, gDecisionReads;
static BOOL gAllowed, gResult, gThrowOriginal, gThrowCompute;
static uint64_t gTotal, gFree;
static id gOriginalAttributes, gOriginalValues, gOriginalValue;
static unsigned long long gOriginalCapacity;
static NSError *gErrorToSet;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PX_RUNTIME_READ_OPERATION do { gOperations++; } while (0)
static BOOL shouldApplyStorageSpoofing(void) { gDecisionReads++; return gAllowed; }
static void getStorageValuesForApp(uint64_t *total, uint64_t *free) {
    gByteReads++;
    if (gThrowCompute) [NSException raise:@"fixture.compute" format:@"byte preparation failed"];
    *total = gTotal; *free = gFree;
}
#include "PXStorageObjCHelpers.inc"

static void Original(NSError **error) {
    gOriginalCalls++;
    if (gThrowOriginal) [NSException raise:@"fixture.original" format:@"original failed"];
    if (error && gErrorToSet) *error = gErrorToSet;
}
@interface PXStorageFileHookFixture : NSObject
- (NSDictionary *)fixtureAttributes:(NSString *)path error:(NSError **)error;
- (unsigned long long)fixtureCapacity:(NSURL *)url error:(NSError **)error;
#include "PXStorageFileManagerDeclarations.inc"
@end
@implementation PXStorageFileHookFixture
- (NSDictionary *)fixtureAttributes:(NSString *)path error:(NSError **)error { (void)path; Original(error); return gOriginalAttributes; }
- (unsigned long long)fixtureCapacity:(NSURL *)url error:(NSError **)error { (void)url; Original(error); return gOriginalCapacity; }
#include "PXStorageFileManagerMethods.inc"
@end
@interface PXStorageURLHookFixture : NSObject
- (BOOL)fixtureResource:(id *)value key:(NSURLResourceKey)key error:(NSError **)error;
- (NSDictionary *)fixtureResources:(NSArray *)keys error:(NSError **)error;
#include "PXStorageURLDeclarations.inc"
@end
@implementation PXStorageURLHookFixture
- (BOOL)fixtureResource:(id *)value key:(NSURLResourceKey)key error:(NSError **)error {
    (void)key; Original(error); if (value) *value = gOriginalValue; return gResult;
}
- (NSDictionary *)fixtureResources:(NSArray *)keys error:(NSError **)error { (void)keys; Original(error); return gOriginalValues; }
#include "PXStorageURLMethods.inc"
@end
static void Reset(void) {
    gOriginalCalls = 0; gByteReads = 0; gOperations = 0; gDecisionReads = 0;
    gAllowed = YES; gResult = YES; gThrowOriginal = NO; gThrowCompute = NO;
    gTotal = 100; gFree = 25; gOriginalCapacity = 888;
    gOriginalAttributes = @{ NSFileSystemSize: @999, NSFileSystemFreeSize: @777, @"owner": @"keep" };
    gOriginalValues = @{ NSURLVolumeTotalCapacityKey: @999, NSURLVolumeAvailableCapacityKey: @777, @"other": @"keep" };
    gOriginalValue = @999; gErrorToSet = nil;
}
static void TestURLHooks(void) {
    PXStorageURLHookFixture *url = [PXStorageURLHookFixture new]; id value = nil;
    Reset();
    CHECK([url getResourceValue:&value forKey:NSURLNameKey error:NULL] && value == gOriginalValue &&
          gOriginalCalls == 1 && !gByteReads && !gOperations && !gDecisionReads, "unrelated single URL key calls original once without storage work or operation capture");
    Reset();
    NSArray *unrelated = @[NSURLNameKey, @17];
    CHECK([url resourceValuesForKeys:unrelated error:NULL] == gOriginalValues && gOriginalCalls == 1 && !gByteReads && !gOperations && !gDecisionReads,
          "unrelated batch URL keys preserve original identity and avoid capture provider and copy work");
    Reset(); gResult = NO; gErrorToSet = [NSError errorWithDomain:@"fixture" code:7 userInfo:nil]; NSError *error = nil;
    CHECK(![url getResourceValue:&value forKey:NSURLVolumeTotalCapacityKey error:&error] && error == gErrorToSet && !gByteReads && gOriginalCalls == 1,
          "failed original URL query preserves BOOL error and value without computing fake bytes");
    NSArray *keys = @[NSURLVolumeTotalCapacityKey, NSURLVolumeAvailableCapacityKey,
        @"NSURLVolumeAvailableCapacityForImportantUsageKey", @"NSURLVolumeAvailableCapacityForOpportunisticUsageKey"];
    for (NSUInteger index = 0; index < keys.count; index++) {
        Reset(); gFree = 0;
        CHECK([url getResourceValue:&value forKey:keys[index] error:NULL] && [value isEqual:@(index == 0 ? 100 : 0)] &&
              gOriginalCalls == 1 && gByteReads == 1, "URL single capacity keys replace zero free space for a valid tuple");
    }
    for (id original in @[@"text", NSNull.null]) {
        Reset(); gOriginalValue = original;
        CHECK([url getResourceValue:&value forKey:NSURLVolumeTotalCapacityKey error:NULL] && value == original && !gByteReads,
              "unexpected nonnumeric original capacity values pass through without metadata work");
    }
    Reset();
    CHECK([url getResourceValue:NULL forKey:NSURLVolumeTotalCapacityKey error:NULL] && !gByteReads && gOriginalCalls == 1,
          "null output pointer is forwarded once and never dereferenced by replacement");
    Reset(); gTotal = 0; gFree = 0;
    CHECK([url getResourceValue:&value forKey:NSURLVolumeAvailableCapacityKey error:NULL] && value == gOriginalValue,
          "missing byte tuple does not turn original free capacity into fake zero");
    Reset(); gFree = 101;
    CHECK([url getResourceValue:&value forKey:NSURLVolumeAvailableCapacityKey error:NULL] && value == gOriginalValue,
          "inconsistent free greater than total preserves original capacity");
    Reset(); gTotal = UINT64_MAX; gFree = UINT64_MAX;
    CHECK([url getResourceValue:&value forKey:NSURLVolumeAvailableCapacityKey error:NULL] && [value unsignedLongLongValue] == UINT64_MAX,
          "full unsigned capacity range is preserved without signed narrowing");
    Reset(); gThrowCompute = YES;
    CHECK([url getResourceValue:&value forKey:NSURLVolumeTotalCapacityKey error:NULL] && value == gOriginalValue && gOriginalCalls == 1,
          "byte provider exception preserves original URL result");
    Reset(); gAllowed = NO;
    CHECK([url getResourceValue:&value forKey:NSURLVolumeAvailableCapacityKey error:NULL] && value == gOriginalValue && !gByteReads,
          "disabled process retains original capacity without provider reads");
    Reset(); gOriginalValues = @{ NSURLVolumeTotalCapacityKey: @999, NSURLVolumeAvailableCapacityKey: NSNull.null, @"other": @"keep" };
    gErrorToSet = [NSError errorWithDomain:@"fixture.partial" code:8 userInfo:nil]; error = nil;
    NSDictionary *result = [url resourceValuesForKeys:keys error:&error];
    CHECK([result[NSURLVolumeTotalCapacityKey] isEqual:@100] && result[NSURLVolumeAvailableCapacityKey] == NSNull.null &&
          !result[@"NSURLVolumeAvailableCapacityForImportantUsageKey"] && result.count == 3 && error == gErrorToSet &&
          [gOriginalValues[NSURLVolumeTotalCapacityKey] isEqual:@999], "partial batch keeps absent nonnumeric unrelated keys error and original dictionary intact");
    Reset(); gOriginalValues = @{ NSURLVolumeTotalCapacityKey: @100, NSURLVolumeAvailableCapacityKey: @25 };
    CHECK([url resourceValuesForKeys:keys error:NULL] == gOriginalValues, "equal batch capacity values retain original dictionary identity without copying");
    Reset(); gOriginalValues = @{ NSURLVolumeTotalCapacityKey: @"unsupported" };
    CHECK([url resourceValuesForKeys:keys error:NULL] == gOriginalValues && !gByteReads && !gDecisionReads, "batch without existing numeric capacity fields avoids byte provider work");
    Reset(); gFree = 0;
    result = [url resourceValuesForKeys:keys error:NULL];
    CHECK([result[NSURLVolumeAvailableCapacityKey] isEqual:@0] && gOriginalCalls == 1 && gByteReads == 1,
          "batch URL free capacity also overwrites physical zero-full-disk mismatch");
    Reset();
    result = [url resourceValuesForKeys:@[NSURLVolumeTotalCapacityKey, NSURLVolumeTotalCapacityKey] error:NULL];
    CHECK([result[NSURLVolumeTotalCapacityKey] isEqual:@100] && [result[NSURLVolumeAvailableCapacityKey] isEqual:@777] &&
          gOriginalCalls == 1 && gByteReads == 1, "duplicate requested keys neither repeat providers nor replace unrequested fields");
    Reset(); gOriginalValues = nil; gErrorToSet = [NSError errorWithDomain:@"fixture" code:10 userInfo:nil]; error = nil;
    CHECK([url resourceValuesForKeys:keys error:&error] == nil && error == gErrorToSet && !gByteReads && !gDecisionReads && gOriginalCalls == 1,
          "failed batch preserves nil and Foundation error without fake fields");
    Reset(); gThrowOriginal = YES; BOOL threw = NO;
    @try { (void)[url getResourceValue:&value forKey:NSURLNameKey error:NULL]; }
    @catch (NSException *exception) { (void)exception; threw = YES; }
    CHECK(threw && gOriginalCalls == 1 && !gByteReads, "original exceptions propagate instead of being swallowed by storage replacement");
    Reset(); gThrowOriginal = YES; threw = NO;
    @try { (void)[url getResourceValue:&value forKey:NSURLVolumeTotalCapacityKey error:NULL]; }
    @catch (NSException *exception) { (void)exception; threw = YES; }
    CHECK(threw && gOriginalCalls == 1 && !gByteReads && gOperations == 1,
          "relevant original exception also propagates before replacement catch");
}
static void TestFileHooks(void) {
    PXStorageFileHookFixture *manager = [PXStorageFileHookFixture new];
    Reset(); gFree = 0;
    NSDictionary *result = [manager attributesOfFileSystemForPath:@"/" error:NULL];
    CHECK([result[NSFileSystemSize] isEqual:@100] && [result[NSFileSystemFreeSize] isEqual:@0] &&
          [gOriginalAttributes[NSFileSystemFreeSize] isEqual:@777] && [result[@"owner"] isEqual:@"keep"] && gOriginalCalls == 1,
          "filesystem attributes replace full-disk free value without mutating original metadata");
    Reset(); gOriginalAttributes = @{ NSFileSystemSize: @100, NSFileSystemFreeSize: @25 };
    CHECK([manager attributesOfFileSystemForPath:@"/" error:NULL] == gOriginalAttributes, "equal filesystem attributes avoid mutable dictionary copy");
    Reset(); gOriginalAttributes = @{ @"owner": @"keep" };
    CHECK([manager attributesOfFileSystemForPath:@"/" error:NULL] == gOriginalAttributes && !gByteReads && !gDecisionReads,
          "filesystem attributes with absent capacity fields pass through without synthesizing unsupported metadata");
    Reset(); gOriginalAttributes = nil;
    CHECK([manager attributesOfFileSystemForPath:@"/missing" error:NULL] == nil && !gByteReads && !gDecisionReads && gOriginalCalls == 1,
          "failed filesystem attributes avoid spoof decisions as well as byte preparation");
    Reset(); gTotal = 0; gFree = 0;
    CHECK([manager attributesOfFileSystemForPath:@"/" error:NULL] == gOriginalAttributes, "unavailable tuple retains original attributes object");
    for (NSUInteger kind = 0; kind < 3; kind++) {
        Reset(); gFree = 0; NSError *error = nil;
        gErrorToSet = [NSError errorWithDomain:@"fixture" code:9 userInfo:nil];
        unsigned long long capacity = kind == 0 ? [manager volumeAvailableCapacityForImportantUsageForURL:nil error:&error] :
            (kind == 1 ? [manager volumeTotalCapacityForURL:nil error:&error] : [manager volumeAvailableCapacityForOpportunisticUsageForURL:nil error:&error]);
        CHECK(capacity == (kind == 1 ? 100 : 0) && gOriginalCalls == 1 && gByteReads == 1 && error == gErrorToSet,
              "compatibility capacity methods preserve orig and error while honoring zero free space");
    }
    Reset();
    CHECK([manager volumeAvailableCapacityForOpportunisticUsageForURL:nil error:NULL] == 22, "opportunistic capacity retains 90 percent double truncation policy");
}
static unsigned long long PXStorageABIStub(id self, SEL command, id url, NSError **error) {
    (void)self; (void)command; (void)url; (void)error; return 0;
}
static void TestCompatibilityABI(void) {
    SEL selector = @selector(volumeTotalCapacityForURL:error:);
    CHECK(!PXStorageCapacityCompatibilityMatches(Nil, selector) && !PXStorageCapacityCompatibilityMatches(NSObject.class, selector) &&
          !PXStorageCapacityCompatibilityMatches(PXStorageFileHookFixture.class, NULL), "absent class selector or method never initializes an optional hook");
    CHECK(PXStorageCapacityCompatibilityMatches(PXStorageFileHookFixture.class, selector), "compiled uint64 object error-pointer method passes ABI gate");
    NSArray *encodings = @[@"Q@:@^@", @"rQ@:r@o^@", @"q@:@^@", @"@@:@^@", @"Q@:q^@", @"Q@:@^v", @"Q@:@?^@", @"Q@:@@", @"Q@:@", @"Q@:@^@@"];
    for (NSUInteger index = 0; index < encodings.count; index++) {
        NSString *name = [NSString stringWithFormat:@"PXStorageCompatibilityFixture%lu", (unsigned long)index];
        Class cls = objc_allocateClassPair(NSObject.class, name.UTF8String, 0);
        CHECK(cls != Nil, "isolated compatibility runtime class allocated"); if (!cls) continue;
        CHECK(class_addMethod(cls, selector, (IMP)PXStorageABIStub, [encodings[index] UTF8String]), "runtime ABI candidate installed without invoking it");
        objc_registerClassPair(cls);
        CHECK(PXStorageCapacityCompatibilityMatches(cls, selector) == (index < 2), "runtime ABI gate checks return argument count object shape and error pointer qualifiers");
    }
}
int main(void) {
    @autoreleasepool {
        @try { TestURLHooks(); TestFileHooks(); TestCompatibilityABI(); }
        @catch (NSException *exception) { gFailures++; fprintf(stderr, "FAIL: unexpected storage-objc exception: %s\n", exception.description.UTF8String); }
        printf("Storage ObjC hooks: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
