#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <dispatch/dispatch.h>
#import "CarrierDB.h"
#include <stdatomic.h>
#include <stdio.h>

static NSUInteger gChecks, gFailures;
static _Atomic NSUInteger gReads, gPathCalls, gBuilds;
static NSDictionary *gBytes;
static NSArray *gPaths;
static BOOL gReadThrows;
static void (^gDuringIndex)(void);
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PXLog(...) do {} while (0)
static void Raise(void) { [NSException raise:@"fixture.carrier" format:@"controlled failure"]; }
static void RunIndexCallback(void) { void (^body)(void) = gDuringIndex; gDuringIndex = nil; @try { if (body) body(); } @finally { body = nil; } }
static NSArray *PXJailbreakPathCandidates(NSArray * __unsafe_unretained paths) { (void)paths; atomic_fetch_add(&gPathCalls, 1); return gPaths; }
@interface NSData (CarrierFiles)
+ (NSData *)px_carrierData:(NSString *)path options:(NSDataReadingOptions)options error:(NSError **)error;
@end
@implementation NSData (CarrierFiles)
+ (NSData *)px_carrierData:(NSString * __unsafe_unretained)path options:(NSDataReadingOptions)options error:(NSError **)error {
    (void)options; (void)error; atomic_fetch_add(&gReads, 1); if (gReadThrows) Raise(); return gBytes[path];
}
@end
@interface NSFileManager (CarrierFiles)
- (BOOL)px_carrierExists:(NSString *)path;
@end
@implementation NSFileManager (CarrierFiles)
- (BOOL)px_carrierExists:(NSString * __unsafe_unretained)path { return gBytes[path] != nil; }
@end
#define dataWithContentsOfFile px_carrierData
#define fileExistsAtPath px_carrierExists
#include "PXCarrierCatalog.inc"
#undef fileExistsAtPath
#undef dataWithContentsOfFile

@interface PXControlledCarrierDB : CarrierDB
@property (atomic, copy) NSDictionary *fixtureRoot;
@end
@implementation PXControlledCarrierDB
- (NSDictionary *)builtInFallbackDB { return self.fixtureRoot ?: [super builtInFallbackDB]; }
- (NSDictionary *)indexesForCountries:(NSDictionary *)countries {
    NSDictionary *indexes = nil;
    @try { atomic_fetch_add(&gBuilds, 1); indexes = [super indexesForCountries:countries]; RunIndexCallback(); return indexes; }
    @finally { indexes = nil; countries = nil; }
}
@end
static NSDictionary *Root(NSString *name, NSString *mcc, NSString *mnc) {
    return @{ @"schemaVersion": @1, @"tag": name,
        @"countries": @{ @"US": @{ @"iso": @"us", @"localeIdentifier": @"en_US", @"preferredLanguages": @[@"en-US"],
            @"carriers": @[@{ @"name": name, @"mcc": mcc, @"mnc": mnc }] } } };
}
static NSData *JSON(id value) {
    NSError *error = nil; NSData *bytes = [NSJSONSerialization dataWithJSONObject:value options:0 error:&error];
    CHECK(bytes && !error, "carrier JSON fixture encoded"); return bytes;
}
static void Reset(void) {
    atomic_store(&gReads, 0); atomic_store(&gPathCalls, 0); atomic_store(&gBuilds, 0);
    gPaths = @[]; gBytes = @{}; gReadThrows = NO; gDuringIndex = nil;
}
static void TestLoadAndQueries(void) {
    Reset(); gPaths = @[@"/fixture/bad", @"/fixture/good"];
    gBytes = @{ @"/fixture/bad": [@"not JSON" dataUsingEncoding:NSUTF8StringEncoding], @"/fixture/good": JSON(Root(@"Loaded", @"310", @"1")) };
    CarrierDB *db = [CarrierDB new]; NSError *error = nil;
    CHECK([db loadIfNeeded:&error] && !error && atomic_load(&gReads) == 2 && ![[db carrierCatalog][@"usedFallback"] boolValue], "carrier load preserves candidate path order and skips bad JSON before valid file");
    CHECK([[db carrierForMCC:@"310" mnc:@"01"][@"name"] isEqual:@"Loaded"] && [[db carrierForMCC:@"310" mnc:@"001"][@"mnc"] isEqual:@"1"], "carrier index preserves raw spelling and two three digit aliases");
    CHECK([[db randomCarrierForCountry:@" us "][@"name"] isEqual:@"Loaded"] && [[db regionDefaultsForCountryCode:@"US"][@"localeIdentifier"] isEqual:@"en_US"], "carrier random and region queries use complete loaded catalog");
    NSUInteger reads = atomic_load(&gReads), paths = atomic_load(&gPathCalls);
    for (NSUInteger index = 0; index < 20; index++) { (void)[db carrierForMCC:@"310" mnc:@"1"]; (void)[db availableCountryCodes]; (void)[db regionDefaultsForCountryCode:@"US"]; }
    CHECK(reads == atomic_load(&gReads) && paths == atomic_load(&gPathCalls), "warm carrier queries do not repeat file probes JSON reads or catalog construction");
    NSDictionary *row = [db carrierForMCC:@"310" mnc:@"1"];
    CHECK([row isEqual:[db carrierForMCC:@"310" mnc:@"001"]], "carrier aliases expose the same stable indexed row contents");
    Reset(); gPaths = @[@"/fixture/schema"]; gBytes = @{ @"/fixture/schema": JSON(@{ @"schemaVersion": @0, @"countries": @{} }) };
    db = [CarrierDB new]; error = nil;
    CHECK([db loadIfNeeded:&error] && error.code == 3 && [[db carrierCatalog][@"usedFallback"] boolValue] && [db availableCountryCodes].count >= 5,
          "unsupported schema retains successful built-in fallback and legacy error output");
    Reset(); db = [CarrierDB new];
    CHECK([[db carrierNameForMCC:@"310" mnc:@"260"] isEqual:@"T-Mobile"] && [[db carriersForCountry:@"unknown"] count] > 0, "missing JSON retains built-in US query fallback");
}
static void TestMalformedAndAliases(void) {
    Reset(); PXControlledCarrierDB *db = [PXControlledCarrierDB new];
    db.fixtureRoot = @{ @"schemaVersion": @1, @"countries": @{ @"US": @{ @"preferredLanguages": @[NSNull.null], @"carriers": @[
        @{ @"name": @"Valid", @"mcc": @310, @"mnc": @1 }, @{ @"name": @"ExactOnly", @"mcc": @"999", @"mnc": @"abc" },
        @{ @"name": @"Malformed", @"mcc": @[], @"mnc": @"1" }] } } };
    CHECK([[db carrierForMCC:(id)@310 mnc:(id)@1][@"name"] isEqual:@"Valid"] && [[db carrierForMCC:@"310" mnc:@" 001 "][@"mnc"] isEqual:@"1"], "numeric legacy carrier codes normalize without losing valid padded lookup");
    CHECK(![db carrierForMCC:@"310" mnc:@"1bad"] && ![db carrierForMCC:@"999" mnc:@"00"] && [[db carrierForMCC:@"999" mnc:@"abc"][@"name"] isEqual:@"ExactOnly"],
          "nonnumeric MNC retains exact key but cannot alias zero or a numeric prefix");
    CHECK(![db carrierForMCC:(id)@[] mnc:@"1"] && ![db carrierForMCC:@"310" mnc:(id)NSNull.null] && [db carriersForCountry:(id)@[]].count == 3,
          "unsupported carrier lookup inputs use typed miss or country fallback without selector crashes");
    NSDictionary *region = [db regionDefaultsForCountryCode:(id)NSNull.null];
    CHECK(([region[@"preferredLanguages"] isEqual:@[@"en-US"]]) && [region[@"carrierISO"] isEqual:@"us"], "malformed language members use safe legacy region defaults");
    db = [PXControlledCarrierDB new]; db.fixtureRoot = Root(@"TLinkIOS private", @"001", @"01");
    CHECK([[db carrierNameForMCC:@"001" mnc:@"01"] isEqual:@"T-Mobile"], "carrier name branding guard is preserved");
    db = [PXControlledCarrierDB new]; db.fixtureRoot = @{ @"schemaVersion": @1, @"countries": @{ @"US": @{ @"carriers": @[@{ @"name": @[], @"mcc": @1, @"mnc": @1 }] } } };
    CHECK(([[db randomCarrierForCountry:@"US"] isEqual:@{ @"name": @"T-Mobile", @"mcc": @"310", @"mnc": @"260" }]), "malformed selected carrier row uses established fallback instead of leaking containers");
}
static void TestConcurrentPublication(void) {
    Reset(); PXControlledCarrierDB *db = [PXControlledCarrierDB new]; db.fixtureRoot = Root(@"First", @"111", @"1");
    dispatch_group_t group = dispatch_group_create();
    dispatch_semaphore_t entered = dispatch_semaphore_create(0), proceed = dispatch_semaphore_create(0), secondDone = dispatch_semaphore_create(0);
    __block _Atomic BOOL waitedOut = NO;
    gDuringIndex = ^{
        dispatch_semaphore_signal(entered);
        if (dispatch_semaphore_wait(proceed, dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC)) != 0) atomic_store(&waitedOut, YES);
    };
    dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ @autoreleasepool { [db loadIfNeeded:NULL]; } });
    BOOL started = dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0;
    CHECK(started && ![db carrierCatalog], "carrier ready state remains absent while first index construction is paused");
    db.fixtureRoot = Root(@"Second", @"222", @"2");
    __block NSDictionary *secondRow = nil, *secondCatalog = nil;
    dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool { secondRow = [db carrierForMCC:@"222" mnc:@"02"]; secondCatalog = [db carrierCatalog]; }
        dispatch_semaphore_signal(secondDone);
    });
    BOOL completed = dispatch_semaphore_wait(secondDone, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0;
    dispatch_semaphore_signal(proceed); dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    CHECK(completed && !atomic_load(&waitedOut) && [secondRow[@"name"] isEqual:@"Second"], "concurrent carrier query can publish complete indexes without waiting on another builder monitor");
    CHECK([db carrierCatalog] == secondCatalog && [[db carrierCatalog][@"root"][@"tag"] isEqual:@"Second"] && ![db carrierForMCC:@"111" mnc:@"01"],
          "first complete carrier catalog wins and later stale builder cannot replace any component");
    __block _Atomic NSUInteger bad = 0;
    dispatch_apply(128, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
        (void)index; @autoreleasepool {
            NSDictionary *row = [db carrierForMCC:@"222" mnc:@"002"];
            if (![row[@"name"] isEqual:@"Second"] || ![[db availableCountryCodes] containsObject:@"US"]) atomic_fetch_add(&bad, 1);
        }
    });
    CHECK(!atomic_load(&bad) && atomic_load(&gBuilds) == 2, "concurrent warm queries observe one complete immutable catalog without rebuilds");
}
static void TestReentryAndLifetime(void) {
    Reset(); PXControlledCarrierDB *db = [PXControlledCarrierDB new]; db.fixtureRoot = Root(@"Outer", @"111", @"1");
    gDuringIndex = ^{ db.fixtureRoot = Root(@"Nested", @"222", @"2"); (void)[db loadIfNeeded:NULL]; };
    CHECK([db loadIfNeeded:NULL] && [[db carrierForMCC:@"222" mnc:@"02"][@"name"] isEqual:@"Nested"] && ![db carrierForMCC:@"111" mnc:@"01"],
          "carrier construction reentry publishes complete nested winner without deadlock or stale overwrite");
    for (NSNumber *readFailure in @[@NO, @YES]) {
        Reset(); __weak id weakDB = nil, weakToken = nil;
        @autoreleasepool {
            PXControlledCarrierDB *owner = [PXControlledCarrierDB new]; weakDB = owner;
            id token = [NSObject new]; weakToken = token;
            NSMutableDictionary *root = [Root(@"Lifetime", @"111", @"1") mutableCopy]; root[@"lifetime"] = token; owner.fixtureRoot = root;
            if (readFailure.boolValue) { gPaths = @[@"/fixture/read"]; gBytes = @{ @"/fixture/read": JSON(Root(@"File", @"111", @"1")) }; gReadThrows = YES; }
            else gDuringIndex = ^{ Raise(); };
            BOOL threw = NO;
            @try { [owner loadIfNeeded:NULL]; } @catch (NSException *exception) { threw = [exception.name isEqual:@"fixture.carrier"]; }
            CHECK(threw && ![owner carrierCatalog], "carrier exceptional construction never publishes partial ready state");
            owner = nil; root = nil; token = nil;
        }
        CHECK(!weakDB && !weakToken && !gDuringIndex, "carrier exceptional construction releases input root indexes and callback captures after pool drain");
    }
}
int main(void) { @autoreleasepool {
    @try { TestLoadAndQueries(); TestMalformedAndAliases(); TestConcurrentPublication(); TestReentryAndLifetime(); }
    @catch (NSException *exception) { gFailures++; fprintf(stderr, "FAIL: unexpected carrier exception: %s\n", exception.description.UTF8String); }
    printf("Carrier catalog: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
    return gFailures ? 1 : 0;
} }
