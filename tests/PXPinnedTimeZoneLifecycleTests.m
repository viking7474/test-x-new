#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <dispatch/dispatch.h>
#include <math.h>
#import "PXPinnedTimeZoneLookup.h"

static NSUInteger gChecks, gFailures, gDeliveries;
#define CHECK(value, message) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", message); } } while (0)
@interface PXFakePlacemark : NSObject
@property (nonatomic, strong) NSTimeZone *timeZone;
@end
@implementation PXFakePlacemark
@end
@interface PXFakeGeocoder : NSObject
@property (nonatomic, copy) void (^completion)(NSArray<PXFakePlacemark *> *, NSError *);
@property (nonatomic, strong) CLLocation *location;
@property (nonatomic, assign) NSUInteger cancellations;
- (void)reverseGeocodeLocation:(CLLocation *)location completionHandler:(void (^)(NSArray<PXFakePlacemark *> *, NSError *))completion;
- (void)cancelGeocode;
@end
static NSMutableArray<PXFakeGeocoder *> *gGeocoders;
@implementation PXFakeGeocoder
- (instancetype)init { if ((self = [super init])) { CHECK(NSThread.isMainThread, "geocoder constructed on main"); [gGeocoders addObject:self]; } return self; }
- (void)reverseGeocodeLocation:(CLLocation *)location completionHandler:(void (^)(NSArray<PXFakePlacemark *> *, NSError *))completion {
    CHECK(NSThread.isMainThread, "geocoder request starts on main"); self.location = location; self.completion = completion;
}
- (void)cancelGeocode { CHECK(NSThread.isMainThread, "geocoder cancellation executes on main"); self.cancellations++; }
@end
// Pre-import SDK headers before replacing the backend types in actual source.
#define CLGeocoder PXFakeGeocoder
#define CLPlacemark PXFakePlacemark
#include "../common/PXPinnedTimeZoneLookup.m"
#undef CLPlacemark
#undef CLGeocoder

static NSInteger gMode = 2;
static NSDictionary *gPin;
NSInteger PXReadSecurityInteger(NSString *key, NSInteger fallback) { (void)key; (void)fallback; CHECK(NSThread.isMainThread, "mode check runs on main"); return gMode; }
@interface LocationSpoofingManager : NSObject
+ (instancetype)sharedManager;
- (NSDictionary *)loadSpoofingLocation;
@end
@implementation LocationSpoofingManager
+ (instancetype)sharedManager { static id manager; static dispatch_once_t once; dispatch_once(&once, ^{ manager = [self new]; }); return manager; }
- (NSDictionary *)loadSpoofingLocation { CHECK(NSThread.isMainThread, "pin check runs on main"); return gPin; }
@end
@interface PXTimeDetailFixture : NSObject
@property (nonatomic, strong) PXPinnedTimeZoneLookup *pinnedTimeZoneLookup;
@property (nonatomic, copy) NSString *savedZone;
@property (nonatomic, assign) NSUInteger saves;
- (BOOL)persistLocationTimeZoneName:(NSString *)name;
- (void)resolvePinnedLocationTimeZone;
@end
@implementation PXTimeDetailFixture
- (BOOL)persistLocationTimeZoneName:(NSString *)name { CHECK(NSThread.isMainThread, "timezone persistence handoff runs on main"); self.savedZone = name; self.saves++; return YES; }
#include "PXTimeZoneDetailAdapter.inc"
@end
@interface PXSecurityTimeFixture : NSObject
@property (nonatomic, strong) PXPinnedTimeZoneLookup *pinnedTimeZoneLookup;
- (void)getTimeZoneForLocation:(CLLocationCoordinate2D)coordinate completion:(void (^)(NSTimeZone *timeZone, NSString *timeZoneId))completion;
@end
@implementation PXSecurityTimeFixture
#include "PXSecurityTimeZoneAdapter.inc"
@end

static BOOL Wait(BOOL (^condition)(void)) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3];
    while (!condition() && deadline.timeIntervalSinceNow > 0) {
        @autoreleasepool { CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.005, YES); }
    }
    return condition();
}
static void Reply(PXFakeGeocoder *geocoder, NSArray *placemarks, NSError *error) {
    NSUInteger delivered = gDeliveries;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        // Intentionally allow late and duplicate backend completions.
        geocoder.completion(placemarks, error);
        dispatch_async(dispatch_get_main_queue(), ^{ gDeliveries++; });
    });
    CHECK(Wait(^BOOL { return gDeliveries == delivered + 1; }), "backend and queued main completion drain with deadline");
}
static void ReplyZone(PXFakeGeocoder *geocoder, NSTimeZone *zone) {
    PXFakePlacemark *placemark = [PXFakePlacemark new]; placemark.timeZone = zone;
    Reply(geocoder, @[placemark], nil);
}
// MacTypes.h declares Point; fixture helpers must not reuse SDK type names.
static CLLocationCoordinate2D PXTimeZoneFixtureCoordinate(void) { return CLLocationCoordinate2DMake(10.75, 106.5); }
static NSDictionary *Pin(CLLocationCoordinate2D coordinate) { return @{ @"latitude": @(coordinate.latitude), @"longitude": @(coordinate.longitude) }; }

static void TestLatestLookup(void) {
    PXPinnedTimeZoneLookup *lookup = [PXPinnedTimeZoneLookup new];
    __block NSUInteger completions = 0; __block NSTimeZone *result = nil;
    NSTimeZone *zone = [NSTimeZone timeZoneForSecondsFromGMT:3600];
    PXPinnedTimeZoneCompletion completion = ^(NSTimeZone *value, NSError *error) {
        CHECK(NSThread.isMainThread && !error, "current geocoder success executes on main"); completions++; result = value;
    };
    [lookup resolveCoordinate:PXTimeZoneFixtureCoordinate() completion:completion]; PXFakeGeocoder *old = gGeocoders.lastObject;
    [lookup resolveCoordinate:PXTimeZoneFixtureCoordinate() completion:completion]; PXFakeGeocoder *current = gGeocoders.lastObject;
    ReplyZone(old, zone);
    CHECK(old.cancellations == 1 && completions == 0, "superseded and cancelled lookups drop late geocoder results");
    ReplyZone(current, zone); ReplyZone(current, zone);
    CHECK(completions == 1 && result == zone && current.cancellations == 0, "lookup delivers current zone once on main thread");
    [lookup cancel]; CHECK(current.cancellations == 0, "cancel after successful completion does not cancel finished request");
    [lookup resolveCoordinate:PXTimeZoneFixtureCoordinate() completion:completion]; current = gGeocoders.lastObject; [lookup cancel];
    Reply(current, nil, [NSError errorWithDomain:kCLErrorDomain code:kCLErrorGeocodeCanceled userInfo:nil]);
    CHECK(current.cancellations == 1 && completions == 1, "superseded and cancelled lookups drop late geocoder results");

    __weak PXPinnedTimeZoneLookup *weakLookup = lookup;
    [lookup resolveCoordinate:PXTimeZoneFixtureCoordinate() completion:^(NSTimeZone *value, NSError *error) {
        (void)value; (void)error; completions++;
        [weakLookup resolveCoordinate:PXTimeZoneFixtureCoordinate() completion:completion];
    }];
    old = gGeocoders.lastObject; ReplyZone(old, zone); current = gGeocoders.lastObject;
    CHECK(current != old && current.cancellations == 0, "consumer reentry preserves its newly started lookup");
    ReplyZone(current, zone); CHECK(completions == 3, "reentered lookup still delivers its own result");
}
static void TestFailureAndThreading(void) {
    PXPinnedTimeZoneLookup *lookup = [PXPinnedTimeZoneLookup new]; __block NSUInteger failures = 0;
    PXPinnedTimeZoneCompletion failure = ^(NSTimeZone *zone, NSError *error) { CHECK(NSThread.isMainThread && !zone && error, "lookup errors execute on main"); failures++; };
    [lookup resolveCoordinate:PXTimeZoneFixtureCoordinate() completion:failure];
    Reply(gGeocoders.lastObject, nil, [NSError errorWithDomain:kCLErrorDomain code:kCLErrorNetwork userInfo:nil]);
    [lookup resolveCoordinate:PXTimeZoneFixtureCoordinate() completion:failure]; Reply(gGeocoders.lastObject, @[], nil);
    [lookup resolveCoordinate:PXTimeZoneFixtureCoordinate() completion:failure]; Reply(gGeocoders.lastObject, @[NSNull.null], nil);
    NSUInteger geocoders = gGeocoders.count;
    [lookup resolveCoordinate:CLLocationCoordinate2DMake(NAN, 0) completion:failure];
    [lookup resolveCoordinate:PXTimeZoneFixtureCoordinate() completion:nil];
    CHECK(failures == 4 && geocoders == gGeocoders.count, "invalid coordinates and missing completion launch no geocoder");
    __block NSUInteger successes = 0;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [lookup resolveCoordinate:PXTimeZoneFixtureCoordinate() completion:^(NSTimeZone *zone, NSError *error) { (void)zone; (void)error; successes++; }];
    });
    CHECK(Wait(^BOOL { return gGeocoders.count == geocoders + 1; }), "background resolve starts backend on main");
    PXFakeGeocoder *pending = gGeocoders.lastObject;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ [lookup cancel]; });
    CHECK(Wait(^BOOL { return pending.cancellations == 1; }), "background controls reach main without synchronous dispatch");
    ReplyZone(pending, NSTimeZone.localTimeZone); CHECK(successes == 0, "background cancel fences queued response");
}
static void TestDetailAdapter(void) {
    PXTimeDetailFixture *detail = [PXTimeDetailFixture new]; gMode = 2; gPin = Pin(PXTimeZoneFixtureCoordinate());
    NSTimeZone *zone = [NSTimeZone timeZoneForSecondsFromGMT:7200];
    [detail resolvePinnedLocationTimeZone]; PXFakeGeocoder *pending = gGeocoders.lastObject;
    gPin = Pin(CLLocationCoordinate2DMake(11, 107)); ReplyZone(pending, zone);
    CHECK(detail.saves == 0, "time detail rejects result after pin or mode changes");
    [detail resolvePinnedLocationTimeZone]; pending = gGeocoders.lastObject; gMode = 0; ReplyZone(pending, zone);
    CHECK(detail.saves == 0, "time detail rejects result after pin or mode changes");
    gMode = 2; [detail resolvePinnedLocationTimeZone]; PXFakeGeocoder *old = gGeocoders.lastObject;
    [detail resolvePinnedLocationTimeZone]; pending = gGeocoders.lastObject; ReplyZone(old, zone); ReplyZone(pending, zone);
    CHECK(detail.saves == 1 && [detail.savedZone isEqual:zone.name] && old.cancellations == 1, "time detail persists only current valid lookup");
    NSUInteger geocoders = gGeocoders.count; gPin = @{}; [detail resolvePinnedLocationTimeZone];
    gPin = Pin(PXTimeZoneFixtureCoordinate()); gMode = 1; [detail resolvePinnedLocationTimeZone];
    CHECK(geocoders == gGeocoders.count, "missing pin or inactive location mode launches no lookup");
    gMode = 2;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ [detail resolvePinnedLocationTimeZone]; });
    CHECK(Wait(^BOOL { return gGeocoders.count == geocoders + 1; }), "background detail adapter routes pin and mode reads to main");
    ReplyZone(gGeocoders.lastObject, zone);
    CHECK(detail.saves == 2, "background detail caller still receives current persistence handoff");
}
static void TestSecurityAdapter(void) {
    PXSecurityTimeFixture *security = [PXSecurityTimeFixture new]; gPin = Pin(PXTimeZoneFixtureCoordinate());
    __block NSUInteger completions = 0; NSTimeZone *zone = [NSTimeZone timeZoneForSecondsFromGMT:3600];
    void (^completion)(NSTimeZone *, NSString *) = ^(NSTimeZone *value, NSString *name) {
        CHECK(NSThread.isMainThread && value == zone && [name isEqual:zone.name], "security consumer receives current zone on main"); completions++;
    };
    [security getTimeZoneForLocation:PXTimeZoneFixtureCoordinate() completion:completion]; PXFakeGeocoder *old = gGeocoders.lastObject;
    gPin = Pin(CLLocationCoordinate2DMake(11, 107)); ReplyZone(old, zone);
    CHECK(completions == 0, "security adapter rejects stale coordinates and delivers current result on main");
    gPin = Pin(PXTimeZoneFixtureCoordinate()); [security getTimeZoneForLocation:PXTimeZoneFixtureCoordinate() completion:completion]; ReplyZone(gGeocoders.lastObject, zone);
    CHECK(completions == 1, "security adapter rejects stale coordinates and delivers current result on main");
    NSUInteger geocoders = gGeocoders.count; [security getTimeZoneForLocation:PXTimeZoneFixtureCoordinate() completion:nil];
    CHECK(geocoders == gGeocoders.count, "missing security consumer launches no geocoder");
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ [security getTimeZoneForLocation:PXTimeZoneFixtureCoordinate() completion:completion]; });
    CHECK(Wait(^BOOL { return gGeocoders.count == geocoders + 1; }), "background security adapter starts lookup on main");
    ReplyZone(gGeocoders.lastObject, zone); CHECK(completions == 2, "background security caller receives consumer callback on main");
}
static void TestOwnerLifetime(void) {
    __weak PXPinnedTimeZoneLookup *releasedLookup; PXFakeGeocoder *pending = nil; __block NSUInteger completions = 0;
    @autoreleasepool {
        PXPinnedTimeZoneLookup *lookup = [PXPinnedTimeZoneLookup new]; releasedLookup = lookup;
        [lookup resolveCoordinate:PXTimeZoneFixtureCoordinate() completion:^(NSTimeZone *zone, NSError *error) { (void)zone; (void)error; completions++; }];
        pending = gGeocoders.lastObject;
    }
    CHECK(!releasedLookup && pending.cancellations == 1, "geocoder does not retain lookup or controller owner");
    ReplyZone(pending, NSTimeZone.localTimeZone); CHECK(completions == 0, "released lookup drops late completion");
    __block PXPinnedTimeZoneLookup *backgroundOwner = [PXPinnedTimeZoneLookup new];
    [backgroundOwner resolveCoordinate:PXTimeZoneFixtureCoordinate() completion:^(NSTimeZone *zone, NSError *error) { (void)zone; (void)error; completions++; }];
    PXFakeGeocoder *backgroundPending = gGeocoders.lastObject; __weak PXPinnedTimeZoneLookup *backgroundReleased = backgroundOwner;
    __block BOOL releasedOnBackground = NO;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        backgroundOwner = nil;
        dispatch_async(dispatch_get_main_queue(), ^{ releasedOnBackground = YES; });
    });
    CHECK(Wait(^BOOL { return releasedOnBackground; }) && !backgroundReleased && backgroundPending.cancellations == 1,
          "background owner release cancels backend on main without resurrecting owner");
    ReplyZone(backgroundPending, NSTimeZone.localTimeZone);
    __weak PXTimeDetailFixture *releasedDetail;
    gMode = 2; gPin = Pin(PXTimeZoneFixtureCoordinate());
    @autoreleasepool { PXTimeDetailFixture *detail = [PXTimeDetailFixture new]; releasedDetail = detail; [detail resolvePinnedLocationTimeZone]; pending = gGeocoders.lastObject; }
    CHECK(!releasedDetail && pending.cancellations == 1, "geocoder does not retain lookup or controller owner"); ReplyZone(pending, NSTimeZone.localTimeZone);
    __weak PXSecurityTimeFixture *releasedSecurity;
    @autoreleasepool {
        PXSecurityTimeFixture *security = [PXSecurityTimeFixture new]; releasedSecurity = security;
        [security getTimeZoneForLocation:PXTimeZoneFixtureCoordinate() completion:^(NSTimeZone *zone, NSString *name) { (void)zone; (void)name; completions++; }]; pending = gGeocoders.lastObject;
    }
    CHECK(!releasedSecurity && pending.cancellations == 1, "geocoder does not retain lookup or controller owner"); ReplyZone(pending, NSTimeZone.localTimeZone);
    CHECK(completions == 0, "released controller never receives late consumer callback");
}
int main(void) {
    @autoreleasepool {
        gGeocoders = [NSMutableArray array];
        TestLatestLookup(); TestFailureAndThreading(); TestDetailAdapter(); TestSecurityAdapter(); TestOwnerLifetime();
        NSDictionary *valid = Pin(PXTimeZoneFixtureCoordinate()), *wrong = @{ @"latitude": @"10.75", @"longitude": NSNull.null };
        CHECK(PXPinnedCoordinateMatchesLocation(PXTimeZoneFixtureCoordinate(), valid) && !PXPinnedCoordinateMatchesLocation(PXTimeZoneFixtureCoordinate(), wrong) &&
              !PXPinnedCoordinateMatchesLocation(PXTimeZoneFixtureCoordinate(), (id)@[]) && !PXPinnedCoordinateMatchesLocation(PXTimeZoneFixtureCoordinate(), nil), "coordinate comparison rejects malformed pin types");
        printf("Pinned timezone lifecycle: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
