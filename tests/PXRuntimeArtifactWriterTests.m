#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "PXRuntimeArtifactWriter.h"
#import "PXRuntimePublisher.h"
#import "NetworkManager.h"
#import "PXPaths.h"
#import "TLinkIOSLogging.h"
#include <stdatomic.h>
#include <unistd.h>

static NSUInteger gChecks, gFailures;
static PXRuntimeSourceStore *gStore;
static NSString *gIdentity;
static _Atomic NSUInteger gSelections, gGenerations;
static void (^gDuringGeneration)(void);
#define CHECK(value, message) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", message); } } while (0)

// Storage/role and logging backend only. Production NetworkManager, stage helpers
// and the source engine are compiled unchanged. No duplicated merge/commit logic.
NSString *PXActiveProfileIdentityPath(void) { atomic_fetch_add(&gSelections, 1); return gIdentity; }
BOOL PXPerformRuntimeSourceWrite(BOOL (^body)(PXRuntimeSourceTransaction *, NSError **), NSError **error) {
    return [gStore performWrite:body error:error];
}
void PXLog(NSString *format, ...) { (void)format; }

@interface PXFixtureNetwork : NetworkManager
@end
@implementation PXFixtureNetwork
+ (NSString *)generateSpoofedLocalIPv6AddressFromCurrent {
    atomic_fetch_add(&gGenerations, 1);
    if (gDuringGeneration) gDuringGeneration();
    return @"2001:db8::candidate";
}
+ (NSString *)generateSpoofedLocalIPAddressFromCurrent {
    if (gDuringGeneration) gDuringGeneration();
    return @"192.0.2.20";
}
+ (NSDictionary *)getRandomCarrierForCountry:(NSString *)country {
    (void)country;
    if (gDuringGeneration) gDuringGeneration();
    return @{ @"name": @"Fixture", @"mcc": @"001", @"mnc": @"01" };
}
@end

static NSString *Path(NSString *root, NSString *name) { return [root stringByAppendingPathComponent:name]; }
static NSDictionary *Load(NSString *identity, NSString *file) {
    return [NSDictionary dictionaryWithContentsOfFile:Path(identity, file)] ?: @{};
}
static NSDictionary *View(NSString *identity) {
    return [gStore capture:^NSDictionary *(NSError **error) {
        (void)error;
        return @{ @"ids": Load(identity, @"device_ids.plist"), @"network": Load(identity, @"network_settings.plist"),
            @"carrier": Load(identity, @"carrier_details.plist"), @"wifi": Load(identity, @"wifi_info.plist"),
            @"battery": Load(identity, @"battery_info.plist"), @"boot": Load(identity, @"boot_time.plist"),
            @"uptime": Load(identity, @"system_uptime.plist") };
    } error:NULL];
}
static BOOL Seed(NSString *identity, NSDictionary *ids, NSDictionary *network) {
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx setDictionary:ids atPath:Path(identity, @"device_ids.plist") error:error] &&
            [tx setDictionary:network atPath:Path(identity, @"network_settings.plist") error:error];
    } error:NULL];
}
static void TestNetwork(NSString *a, NSString *b) {
    gIdentity = a;
    CHECK(Seed(a, @{ @"keep": @1, @"LocalIPv6Address": @"2001:db8::ids" },
                  @{ @"keep": @2, @"localIPv6Address": @"2001:db8::network" }), "network seeded");
    atomic_store(&gSelections, 0); atomic_store(&gGenerations, 0);
    CHECK([PXFixtureNetwork saveLocalIPAddress:@"192.0.2.1"], "single IPv4 commit");
    NSDictionary *view = View(a);
    CHECK(atomic_load(&gSelections) == 1 && atomic_load(&gGenerations) == 0, "existing IPv6 avoids generation and second profile lookup");
    CHECK([view[@"ids"][@"LocalIPv6Address"] isEqual:@"2001:db8::network"] &&
          [view[@"network"][@"localIPv6Address"] isEqual:@"2001:db8::network"], "network IPv6 precedence preserved");
    CHECK([view[@"ids"][@"keep"] isEqual:@1] && [view[@"network"][@"keep"] isEqual:@2], "address merge preserves unrelated fields");
    CHECK(Seed(a, @{ @"LocalIPv6Address": @"2001:db8::ids" }, @{ @"localIPv6Address": @"" }), "IPv6 fallback seeded");
    CHECK([PXFixtureNetwork saveLocalIPAddress:@"192.0.2.2"] &&
          [View(a)[@"network"][@"localIPv6Address"] isEqual:@"2001:db8::ids"], "device IDs IPv6 fallback retained");

    CHECK(Seed(a, @{}, @{}) && Seed(b, @{ @"untouched": @YES }, @{}), "profile switch fixtures seeded");
    atomic_store(&gSelections, 0); atomic_store(&gGenerations, 0);
    gDuringGeneration = ^{
        CHECK(View(a) != nil, "interface generation executes outside source gate");
        gIdentity = b;
    };
    CHECK([PXFixtureNetwork saveLocalIPAddress:@"192.0.2.3"], "missing IPv6 generated");
    gDuringGeneration = nil;
    CHECK(atomic_load(&gSelections) == 1 && atomic_load(&gGenerations) == 1 &&
          [View(a)[@"ids"][@"LocalIPAddress"] isEqual:@"192.0.2.3"] &&
          [View(b)[@"ids"][@"untouched"] boolValue], "profile switch during prepare cannot redirect original operation");
    CHECK(!View(b)[@"ids"][@"LocalIPAddress"], "new active profile not overwritten by previous operation");

    gIdentity = a;
    CHECK(Seed(a, @{}, @{}), "concurrent IPv6 fill fixture seeded");
    gDuringGeneration = ^{
        CHECK([gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
            return PXStageRuntimeAddresses(tx, a, nil, @"2001:db8::winner", NO, NSDate.date, error);
        } error:NULL], "second writer fills IPv6 during preparation");
    };
    CHECK([PXFixtureNetwork saveLocalIPAddress:@"192.0.2.4"], "single IPv4 recheck commit");
    gDuringGeneration = nil;
    CHECK([View(a)[@"ids"][@"LocalIPv6Address"] isEqual:@"2001:db8::winner"], "prepared candidate cannot overwrite newly committed IPv6");
    CHECK([PXFixtureNetwork saveLocalIPAddress:nil ipv6Address:nil], "nil address pair accepted as before");
    CHECK([View(a)[@"ids"][@"LocalIPAddress"] isEqual:@"192.0.2.4"], "nil address means unchanged");
    CHECK(![PXFixtureNetwork saveLocalIPAddress:@""], "empty single IPv4 rejected");

    atomic_store(&gSelections, 0);
    gDuringGeneration = ^{ gIdentity = b; };
    CHECK([[PXFixtureNetwork getSavedLocalIPAddressWithForcedRefresh:YES] isEqual:@"192.0.2.20"], "forced network refresh returns generated address");
    gDuringGeneration = nil;
    CHECK(atomic_load(&gSelections) == 1 && [View(a)[@"ids"][@"LocalIPAddress"] isEqual:@"192.0.2.20"], "forced refresh preserves captured target profile");
    gIdentity = a;
    atomic_store(&gSelections, 0);
    gDuringGeneration = ^{ gIdentity = b; };
    [PXFixtureNetwork getSavedCarrierDetailsWithForcedRefresh:YES];
    gDuringGeneration = nil;
    CHECK(atomic_load(&gSelections) == 1 && [View(a)[@"carrier"][@"carrierName"] isEqual:@"Fixture"] &&
          !View(b)[@"carrier"][@"carrierName"], "carrier refresh preserves captured target profile");
}
static void TestComposedStages(NSString *identity) {
    gIdentity = identity;
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:1000000];
    NSDictionary *battery = @{ @"BatteryLevel": @"0.5", @"LowPowerMode": @YES, @"LastUpdated": now };
    CHECK([gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        BOOL exists = YES;
        NSDictionary *ids = [tx dictionaryAtPath:Path(identity, @"device_ids.plist") exists:&exists error:error];
        return ids != nil && !exists && PXStageRuntimeBattery(tx, identity, battery, error);
    } error:NULL], "battery-only update stages absent IDs safely");
    CHECK(![NSFileManager.defaultManager fileExistsAtPath:Path(identity, @"device_ids.plist")], "battery does not create previously absent device IDs");
    NSDictionary *boot = @{ @"value": [NSDate dateWithTimeIntervalSince1970:900000], @"lastUpdated": now, @"version": @1 };
    NSDictionary *uptime = @{ @"value": @"100000", @"lastUpdated": now, @"version": @1 };
    NSDictionary *wifi = @{ @"ssid": @"Test", @"bssid": @"02:00:00:00:00:01", @"autoJoin": @YES };
    NSDictionary *carrier = @{ @"carrierName": @"Carrier", @"mcc": @"001", @"mnc": @"01", @"lastUpdated": now };
    atomic_store(&gSelections, 0);
    CHECK([gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return PXStageRuntimeWiFi(tx, identity, wifi, error) && PXStageRuntimeBattery(tx, identity, battery, error) &&
            PXStageRuntimeUptime(tx, identity, boot, uptime, now, error) && PXStageRuntimeCarrier(tx, identity, carrier, now, error) &&
            PXStageRuntimeAddresses(tx, identity, @"192.0.2.30", @"2001:db8::30", NO, now, error);
    } error:NULL], "all artifact stages compose in one source commit");
    NSDictionary *view = View(identity), *ids = view[@"ids"];
    CHECK(atomic_load(&gSelections) == 0, "staging helpers never resolve active profile");
    CHECK([ids[@"SSID"] isEqual:wifi[@"ssid"]] && [ids[@"BSSID"] isEqual:wifi[@"bssid"]] &&
          [ids[@"LowPowerMode"] boolValue] && [ids[@"BatteryLevel"] isEqual:@"0.5"], "WiFi and battery mappings preserved");
    CHECK([view[@"boot"][@"value"] isKindOfClass:NSDate.class] && [ids[@"BootTime"] isEqual:@"900000"] &&
          [ids[@"SystemUptime"] isEqual:uptime[@"value"]] && [view[@"uptime"][@"version"] isEqual:@1], "boot date uptime string and version schema preserved");
    CHECK([ids[@"CarrierName"] isEqual:carrier[@"carrierName"]] && [ids[@"CarrierMCC"] isEqual:carrier[@"mcc"]] &&
          [view[@"network"][@"localIPAddress"] isEqual:ids[@"LocalIPAddress"]], "composed stage merges do not lose earlier staged fields");
    CHECK([gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return PXStageRuntimeWiFi(tx, identity, @{}, error);
    } error:NULL] && !View(identity)[@"ids"][@"SSID"] && !View(identity)[@"ids"][@"BSSID"], "legacy WiFi missing fields still remove ID keys");
}
static void TestRollback(NSString *identity) {
    gIdentity = identity;
    CHECK(Seed(identity, @{ @"LocalIPAddress": @"192.0.2.1" }, @{ @"localIPAddress": @"192.0.2.1" }), "rollback fixture seeded");
    NSDictionary *before = View(identity);
    __block BOOL interrupted = NO;
    gStore.testCheckpoint = ^(NSString *stage) {
        if ([stage isEqual:@"source-written"] && !interrupted) {
            interrupted = YES; [NSException raise:@"fixture" format:@"interrupt artifact group"];
        }
    };
    CHECK(![PXFixtureNetwork saveLocalIPAddress:@"192.0.2.99" ipv6Address:@"2001:db8::99"], "manager reports atomic group failure");
    gStore.testCheckpoint = nil;
    CHECK([before isEqual:View(identity)], "artifact failure rolls back fields and source commit identity");
    [@"broken" writeToFile:Path(identity, @"network_settings.plist") atomically:YES encoding:NSUTF8StringEncoding error:nil];
    CHECK(![PXFixtureNetwork saveLocalIPAddress:@"192.0.2.100" ipv6Address:nil], "corrupt artifact is not silently replaced");
    CHECK([Load(identity, @"device_ids.plist") isEqual:before[@"ids"]], "malformed sibling cannot partially update device IDs");
}
static void TestConcurrent(NSString *identity) {
    gIdentity = identity;
    CHECK(Seed(identity, @{ @"keep": @YES }, @{}), "concurrent artifact fixture seeded");
    dispatch_group_t group = dispatch_group_create();
    static _Atomic NSUInteger errors;
    atomic_store(&errors, 0);
    for (NSUInteger i = 0; i < 24; ++i) dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            BOOL success = NO;
            for (NSUInteger attempt = 0; attempt < 3 && !success; attempt++) {
                success = i % 2 ? [PXFixtureNetwork saveLocalIPAddress:[NSString stringWithFormat:@"192.0.2.%lu", (unsigned long)i]
                        ipv6Address:[NSString stringWithFormat:@"2001:db8::%lu", (unsigned long)i]] :
                    [PXFixtureNetwork saveCarrierDetails:@"Carrier" mcc:@"001" mnc:@"01"];
                if (!success) usleep(20000); // Engine contention timeouts are part of its public contract.
            }
            if (!success) atomic_fetch_add(&errors, 1);
        }
    });
    NSUInteger mixed = 0;
    do {
        NSDictionary *view = View(identity);
        if (view && ![view[@"network"][@"localIPAddress"] isEqual:view[@"ids"][@"LocalIPAddress"]] && view[@"network"][@"localIPAddress"]) mixed++;
        usleep(1000);
    } while (dispatch_group_wait(group, DISPATCH_TIME_NOW) != 0);
    NSDictionary *view = View(identity);
    CHECK(atomic_load(&errors) == 0 && mixed == 0, "concurrent network captures remain paired");
    CHECK([view[@"ids"][@"keep"] boolValue] && [view[@"ids"][@"CarrierName"] isEqual:@"Carrier"] &&
          view[@"ids"][@"LocalIPAddress"] != nil, "concurrent disjoint artifact merges preserve all fields");
}
int main(void) {
    @autoreleasepool {
        NSString *root = Path(NSTemporaryDirectory(), NSUUID.UUID.UUIDString);
        NSMutableArray *targets = [NSMutableArray array];
        for (NSString *name in @[@"a", @"b", @"compose", @"rollback", @"concurrent"]) {
            NSString *directory = Path(root, name);
            [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
            [targets addObject:directory];
        }
        gStore = [[PXRuntimeSourceStore alloc] initWithDirectory:Path(root, @"control") owner:geteuid() group:getegid()
            allowsPath:^BOOL(NSString *path) {
                return [targets containsObject:path.stringByDeletingLastPathComponent] && [@[
                    @"device_ids.plist", @"network_settings.plist", @"carrier_details.plist", @"wifi_info.plist",
                    @"battery_info.plist", @"boot_time.plist", @"system_uptime.plist" ] containsObject:path.lastPathComponent];
            } error:NULL];
        CHECK(gStore != nil, "artifact source backend initialized");
        TestNetwork(targets[0], targets[1]); TestComposedStages(targets[2]);
        TestRollback(targets[3]); TestConcurrent(targets[4]);
        gStore = nil;
        [NSFileManager.defaultManager removeItemAtPath:root error:nil];
        printf("Runtime artifact writers: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
