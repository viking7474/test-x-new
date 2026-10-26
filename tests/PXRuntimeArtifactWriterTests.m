#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "PXRuntimeArtifactWriter.h"
#import "PXProfileArtifactMutation.h"
#import "PXProfileLifecycleLease.h"
#import "PXRuntimePublisher.h"
#import "NetworkManager.h"
#import "PXPaths.h"
#import "TLinkIOSLogging.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

static NSUInteger gChecks, gFailures;
static PXRuntimeSourceStore *gStore;
static NSString *gIdentity, *gRoot;
static NSString *Path(NSString *root, NSString *name);
static void (^gAfterSelection)(void);
static void (^gDuringLog)(void);
static _Atomic NSUInteger gSelections, gGenerations, gProviders, gSourceEntries;
static void (^gDuringGeneration)(void);
#define CHECK(value, message) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", message); } } while (0)

// Storage/role and logging backend only. Production NetworkManager, stage helpers
// and the source engine are compiled unchanged. No duplicated merge/commit logic.
NSString *PXProfilesPath(void) { return Path(gRoot, @"profiles"); }
NSString *PXCurrentProfileInfoPath(void) { return Path(PXProfilesPath(), @"current_profile_info.plist"); }
NSString *PXLegacyActiveProfileInfoPath(void) { return Path(gRoot, @"active_profile_info.plist"); }
NSString *PXProfileDeletionJournalPath(void) { return Path(PXProfilesPath(), @".profile-delete-journal.plist"); }
NSString *PXValidatedProfileID(id value) {
    return [value isKindOfClass:NSString.class] && [value length] && ![value containsString:@"/"] &&
        ![value containsString:@"\\"] && ![value isEqual:@"."] && ![value isEqual:@".."] ? [value copy] : nil;
}
NSString *PXProfileIdentityPath(NSString *profile) { return PXValidatedProfileID(profile) ? Path(Path(PXProfilesPath(), profile), @"identity") : nil; }
NSString *PXActiveProfileIdentityPath(void) {
    atomic_fetch_add(&gSelections, 1);
    NSString *selected = [gIdentity copy];
    void (^callback)(void) = gAfterSelection; if (callback) { gAfterSelection = nil; callback(); }
    return selected;
}
BOOL PXPerformRuntimeSourceWrite(BOOL (^body)(PXRuntimeSourceTransaction *, NSError **), NSError **error) {
    atomic_fetch_add(&gSourceEntries, 1);
    return [gStore performWrite:body error:error];
}
void PXLog(NSString *format, ...) { (void)format; if (gDuringLog) gDuringLog(); }

@interface PXFixtureNetwork : NetworkManager
@end
@implementation PXFixtureNetwork
+ (NSString *)getCurrentLocalIPAddress { return @"192.0.2.10"; }
+ (NSString *)generateSpoofedLocalIPv6AddressFromCurrent {
    atomic_fetch_add(&gGenerations, 1); atomic_fetch_add(&gProviders, 1);
    if (gDuringGeneration) gDuringGeneration();
    return @"2001:db8::candidate";
}
+ (NSString *)generateSpoofedLocalIPAddressFromCurrent {
    atomic_fetch_add(&gProviders, 1);
    if (gDuringGeneration) gDuringGeneration();
    return @"192.0.2.20";
}
+ (NSDictionary *)getRandomCarrierForCountry:(NSString *)country {
    atomic_fetch_add(&gProviders, 1);
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

static void CheckNetworkLeaseFree(void) {
    NSError *error = nil;
    PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:PXProfilesPath() error:&error];
    CHECK(lease && !error, "network operation releases lifecycle ownership before returning or logging");
    [lease invalidate];
}
static BOOL ClearNetworkIntent(void) {
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx removeDictionaryAtPath:PXProfileDeletionJournalPath() error:error];
    } error:NULL];
}
static BOOL ClearNetworkCarrier(NSString *identity) {
    return [gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx removeDictionaryAtPath:Path(identity, @"carrier_details.plist") error:error];
    } error:NULL];
}
static NSDictionary *NetworkFiles(void) {
    return [gStore capture:^NSDictionary *(NSError **error) {
        (void)error; NSMutableDictionary *files = [NSMutableDictionary dictionary];
        for (NSString *relative in [NSFileManager.defaultManager subpathsAtPath:PXProfilesPath()])
            if ([relative hasSuffix:@".plist"]) files[relative] = [NSData dataWithContentsOfFile:Path(PXProfilesPath(), relative)];
        return @{ @"files": files };
    } error:NULL];
}
static NSUInteger OpenDescriptorCount(void) {
    NSUInteger count = 0;
    for (int fd = 0; fd < 1024; fd++) if (fcntl(fd, F_GETFD) != -1) count++;
    return count;
}
static void TestNetworkLifecycle(NSString *a, NSString *b) {
    gIdentity = a;
    CHECK(Seed(a, @{}, @{}), "network lifecycle fixture seeded");
    CHECK([PXFixtureNetwork saveLocalIPAddress:@"192.0.2.8" ipv6Address:@"2001:db8::8"] &&
          [PXFixtureNetwork saveCarrierDetails:@"Saved" mcc:@"001" mnc:@"01"], "network read hits seeded");
    PXProfileLifecycleLease *owner = [PXProfileLifecycleLease acquireInDirectory:PXProfilesPath() error:NULL];
    CHECK(owner != nil, "external lifecycle owner acquired for network exclusion");
    NSUInteger selections = atomic_load(&gSelections), providers = atomic_load(&gProviders), entries = atomic_load(&gSourceEntries);
    NSDictionary *before = NetworkFiles();
    CHECK(![PXFixtureNetwork saveLocalIPAddress:@"192.0.2.9"] &&
          ![PXFixtureNetwork saveLocalIPAddress:@"192.0.2.9" ipv6Address:@"2001:db8::9"] &&
          ![PXFixtureNetwork saveCarrierDetails:@"Busy" mcc:@"002" mnc:@"02"] &&
          ![PXFixtureNetwork getSavedLocalIPAddressWithForcedRefresh:YES] &&
          ![PXFixtureNetwork getSavedCarrierDetailsWithForcedRefresh:YES] &&
          selections == atomic_load(&gSelections) && providers == atomic_load(&gProviders) && entries == atomic_load(&gSourceEntries) &&
          [before isEqual:NetworkFiles()], "busy network writers stop before target lookup providers and source gate");
    CHECK([[PXFixtureNetwork getSavedLocalIPAddress] isEqual:@"192.0.2.8"] &&
          [[PXFixtureNetwork getSavedLocalIPv6Address] isEqual:@"2001:db8::8"] &&
          [[PXFixtureNetwork getSavedCarrierDetails][@"name"] isEqual:@"Saved"] && entries == atomic_load(&gSourceEntries),
          "saved network read hits remain available without lifecycle or source lock");
    CHECK(Seed(a, @{}, @{}) && ClearNetworkCarrier(a), "read miss fixture seeded while external owner holds lifecycle");
    before = NetworkFiles();
    CHECK(![PXFixtureNetwork getSavedLocalIPAddress] && ![PXFixtureNetwork getSavedLocalIPv6Address] &&
          ![PXFixtureNetwork getSavedCarrierDetails] && providers == atomic_load(&gProviders) && [before isEqual:NetworkFiles()],
          "busy network read misses never generate or persist fallback values");
    [owner invalidate];
    CHECK([gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx setDictionary:@{ @"fixture": @YES } atPath:PXProfileDeletionJournalPath() error:error];
    } error:NULL], "pending delete journal seeded for network writers");
    selections = atomic_load(&gSelections); before = NetworkFiles();
    CHECK(![PXFixtureNetwork saveLocalIPAddress:@"192.0.2.10"] &&
          ![PXFixtureNetwork saveLocalIPAddress:nil ipv6Address:nil] &&
          ![PXFixtureNetwork saveCarrierDetails:nil mcc:nil mnc:nil] &&
          ![PXFixtureNetwork getSavedLocalIPAddressWithForcedRefresh:YES] &&
          ![PXFixtureNetwork getSavedCarrierDetailsWithForcedRefresh:YES] &&
          selections == atomic_load(&gSelections) && providers == atomic_load(&gProviders) && [before isEqual:NetworkFiles()],
          "pending delete blocks network writes before target lookup or generation");
    CHECK(ClearNetworkIntent(), "network pending intent cleared"); CheckNetworkLeaseFree();
    __block BOOL observed = NO;
    gDuringGeneration = ^{
        CHECK(View(a) != nil, "network provider runs outside source gate while lifecycle held");
        NSError *busy = nil;
        PXProfileLifecycleLease *other = [PXProfileLifecycleLease acquireInDirectory:PXProfilesPath() error:&busy];
        observed = !other && busy.code == 12; [other invalidate];
        CHECK(![PXFixtureNetwork saveCarrierDetails:@"reentry" mcc:nil mnc:nil], "network provider reentry fails busy without deadlock");
    };
    CHECK([PXFixtureNetwork saveLocalIPAddress:@"192.0.2.11"] && observed, "network holds lifecycle across IPv6 preparation and paired commit");
    gDuringGeneration = nil; CheckNetworkLeaseFree();
    gDuringLog = ^{ CheckNetworkLeaseFree(); };
    CHECK([PXFixtureNetwork saveCarrierDetails:@"after-release" mcc:nil mnc:nil], "network save logging occurs after ownership release");
    gDuringLog = nil;
    for (NSUInteger kind = 0; kind < 4; kind++) {
        CHECK(Seed(a, @{}, @{}) && ClearNetworkCarrier(a), "provider exception fixture seeded"); before = NetworkFiles();
        gDuringGeneration = ^{ [NSException raise:@"fixture" format:@"provider exception"]; };
        BOOL threw = NO;
        @try {
            if (kind == 0) [PXFixtureNetwork saveLocalIPAddress:@"192.0.2.12"];
            else if (kind == 1) [PXFixtureNetwork getSavedLocalIPAddressWithForcedRefresh:YES];
            else if (kind == 2) [PXFixtureNetwork getSavedLocalIPv6Address];
            else [PXFixtureNetwork getSavedCarrierDetailsWithForcedRefresh:YES];
        } @catch (NSException *exception) { (void)exception; threw = YES; }
        gDuringGeneration = nil;
        CHECK(threw && [before isEqual:NetworkFiles()], "network provider exception preserves source and releases owned scope");
        CheckNetworkLeaseFree();
    }
    // A miss can lose selection before it acquires ownership; never resurrect
    // that stale target or silently redirect its candidate into a new profile.
    for (NSUInteger kind = 0; kind < 3; kind++) {
        gIdentity = a; CHECK(Seed(a, @{}, @{}) && ClearNetworkCarrier(a), "selection gap fixture seeded");
        before = NetworkFiles(); providers = atomic_load(&gProviders);
        gAfterSelection = ^{ gIdentity = b; };
        id result = kind == 0 ? [PXFixtureNetwork getSavedLocalIPAddress] :
            kind == 1 ? [PXFixtureNetwork getSavedLocalIPv6Address] : [PXFixtureNetwork getSavedCarrierDetails];
        CHECK(!result && providers == atomic_load(&gProviders) && [before isEqual:NetworkFiles()],
              "network read miss rejects selection drift before generating at either target");
    }
    gIdentity = a;
    CHECK(Seed(a, @{}, @{}), "late journal fixture seeded");
    __block NSDictionary *competitor = nil;
    gDuringGeneration = ^{
        CHECK([gStore performWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
            return [tx setDictionary:@{ @"fixture": @YES } atPath:PXProfileDeletionJournalPath() error:error];
        } error:NULL], "bypass writer introduces deletion intent during network preparation");
        competitor = NetworkFiles();
    };
    CHECK(![PXFixtureNetwork saveLocalIPAddress:@"192.0.2.13"] && competitor && [competitor isEqual:NetworkFiles()],
          "late delete intent rejects network candidate before paired staging");
    gDuringGeneration = nil; CHECK(ClearNetworkIntent(), "late network journal fixture cleared"); CheckNetworkLeaseFree();
    for (NSUInteger kind = 0; kind < 3; kind++) {
        CHECK(Seed(a, @{}, @{}), "network namespace drift fixture seeded");
        NSString *oldIdentity = Path(a.stringByDeletingLastPathComponent, @"old-identity");
        __block BOOL moved = NO;
        competitor = nil;
        gDuringGeneration = ^{
            moved = [NSFileManager.defaultManager moveItemAtPath:a toPath:oldIdentity error:NULL];
            if (kind == 1) moved = moved && [NSFileManager.defaultManager createDirectoryAtPath:a withIntermediateDirectories:NO attributes:nil error:NULL];
            if (kind == 2) moved = moved && [NSFileManager.defaultManager createSymbolicLinkAtPath:a withDestinationPath:b error:NULL];
            competitor = NetworkFiles();
        };
        CHECK(![PXFixtureNetwork saveLocalIPAddress:@"192.0.2.14"] && moved && competitor && [competitor isEqual:NetworkFiles()],
              "network commit rejects missing replaced or symlink identity without recreating it");
        gDuringGeneration = nil;
        if (kind != 0) CHECK([NSFileManager.defaultManager removeItemAtPath:a error:NULL], "network replacement fixture removed");
        CHECK([NSFileManager.defaultManager moveItemAtPath:oldIdentity toPath:a error:NULL], "network original identity restored");
        CheckNetworkLeaseFree();
    }
    gIdentity = PXProfileIdentityPath(@"absent");
    providers = atomic_load(&gProviders); before = NetworkFiles();
    CHECK(![PXFixtureNetwork saveLocalIPAddress:@"192.0.2.15"] &&
          ![PXFixtureNetwork getSavedLocalIPAddressWithForcedRefresh:YES] &&
          providers == atomic_load(&gProviders) && [before isEqual:NetworkFiles()] &&
          ![NSFileManager.defaultManager fileExistsAtPath:gIdentity.stringByDeletingLastPathComponent],
          "network refuses missing profile before providers and never creates a retired target");
    gIdentity = a; CheckNetworkLeaseFree();
    before = NetworkFiles(); __block BOOL interrupted = NO;
    gStore.testCheckpoint = ^(NSString *stage) {
        if ([stage isEqual:@"source-written"] && !interrupted) {
            interrupted = YES; [NSException raise:@"fixture" format:@"refresh persistence failure"];
        }
    };
    NSString *candidate = [PXFixtureNetwork getSavedLocalIPAddressWithForcedRefresh:YES];
    gStore.testCheckpoint = nil;
    CHECK(interrupted && [candidate isEqual:@"192.0.2.20"] && [before isEqual:NetworkFiles()],
          "network getter preserves candidate return on persistence failure without partial source commit");
    CheckNetworkLeaseFree();
    // Exercise guard ownership directly without reimplementing its decisions.
    NSError *error = nil;
    PXProfileArtifactMutation *scope = [PXProfileArtifactMutation acquireWithIdentityResolver:^NSString *{ return a; } error:&error];
    CHECK(scope && !error, "artifact mutation capability acquired for native lifecycle checks");
    [scope invalidate]; __block BOOL entered = NO;
    CHECK(![scope performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        (void)tx; (void)writeError; entered = YES; return YES;
    } error:&error] && error && !entered, "invalidated artifact mutation never calls staging body");
    CheckNetworkLeaseFree();
    NSUInteger descriptors = OpenDescriptorCount();
    for (NSUInteger iteration = 0; iteration < 16; iteration++) {
        @autoreleasepool {
            scope = [PXProfileArtifactMutation acquireWithIdentityResolver:^NSString *{ return (id)@42; } error:&error];
            CHECK(!scope && error, "artifact mutation rejects malformed resolver target");
            BOOL threw = NO;
            @try { scope = [PXProfileArtifactMutation acquireWithIdentityResolver:^NSString *{ [NSException raise:@"fixture" format:@"resolver exception"]; return nil; } error:&error]; }
            @catch (NSException *exception) { (void)exception; threw = YES; }
            CHECK(threw, "artifact mutation releases lifecycle when target resolver throws");
            scope = [PXProfileArtifactMutation acquireWithIdentityResolver:^NSString *{ return a; } error:&error];
            CHECK(scope && !error, "artifact mutation reacquires after failures");
            [scope invalidate];
            // Dealloc fallback also releases the identity descriptor and lease.
            scope = [PXProfileArtifactMutation acquireWithIdentityResolver:^NSString *{ return a; } error:&error];
            CHECK(scope && !error, "artifact mutation supports dealloc ownership fallback"); scope = nil;
        }
    }
    CHECK(OpenDescriptorCount() == descriptors, "artifact mutation success failure exception and dealloc paths close every descriptor");
    CheckNetworkLeaseFree();
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
            for (NSUInteger attempt = 0; attempt < 200 && !success; attempt++) {
                success = i % 2 ? [PXFixtureNetwork saveLocalIPAddress:[NSString stringWithFormat:@"192.0.2.%lu", (unsigned long)i]
                        ipv6Address:[NSString stringWithFormat:@"2001:db8::%lu", (unsigned long)i]] :
                    [PXFixtureNetwork saveCarrierDetails:@"Carrier" mcc:@"001" mnc:@"01"];
                if (!success) usleep(10000 + arc4random_uniform(10000)); // Test caller retries nonblocking contention with a bounded budget.
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
        gRoot = Path(NSTemporaryDirectory(), NSUUID.UUID.UUIDString);
        NSString *root = gRoot;
        NSMutableArray *targets = [NSMutableArray array];
        for (NSString *name in @[@"a", @"b", @"compose", @"rollback", @"concurrent"]) {
            NSString *directory = PXProfileIdentityPath(name);
            [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
            [targets addObject:directory];
        }
        gStore = [[PXRuntimeSourceStore alloc] initWithDirectory:Path(root, @"control") owner:geteuid() group:getegid()
            allowsPath:^BOOL(NSString *path) {
                return [@[PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), PXProfileDeletionJournalPath()] containsObject:path] || ([targets containsObject:path.stringByDeletingLastPathComponent] && [@[
                    @"device_ids.plist", @"network_settings.plist", @"carrier_details.plist", @"wifi_info.plist",
                    @"battery_info.plist", @"boot_time.plist", @"system_uptime.plist" ] containsObject:path.lastPathComponent]);
            } error:NULL];
        CHECK(gStore != nil, "artifact source backend initialized");
        TestNetwork(targets[0], targets[1]); TestNetworkLifecycle(targets[0], targets[1]); TestComposedStages(targets[2]);
        TestRollback(targets[3]); TestConcurrent(targets[4]);
        gStore = nil;
        [NSFileManager.defaultManager removeItemAtPath:root error:nil];
        printf("Runtime artifact writers: %lu/%lu checks passed\n", (unsigned long)(gChecks - gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
