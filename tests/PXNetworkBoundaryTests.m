#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>
#include <stdio.h>

static NSUInteger gChecks, gFailures, gReads, gWrites, gAcquires, gProviders, gTxReads, gSets, gFailSetAt;
static _Atomic NSUInteger gGets, gFrees, gActiveLists, gConversions, gRNGCalls;
static int gIfMode = 4, gConvertMode;
static uint32_t gRNGValue;
static BOOL gHeld, gInsideSource, gThrowFormatting;
static NSString *gFault;
static id gIdentity, gRawIPv4, gRawIPv6, gRawCarrier;
static NSMutableDictionary *gFiles;
static void (^gDuringRead)(void), (^gDuringAcquire)(void), (^gDuringProvider)(void), (^gDuringSource)(void), (^gDuringTxRead)(void);
static NSHashTable *gCallbackRoots;
static __weak id gOwnerRoot, gTxRoot;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
static void Raise(void) { [NSException raise:@"fixture.network" format:@"controlled failure"]; }
static void Run(void (^ __strong *slot)(void)) { void (^body)(void) = *slot; *slot = nil; @try { if (body) body(); } @finally { body = nil; } }
static struct ifaddrs *Node(int family, const char *name, const char *ip) {
    struct ifaddrs *entry = calloc(1, sizeof(*entry)); if (!entry) abort();
    entry->ifa_name = name ? strdup(name) : NULL;
    if (family == AF_INET) {
        struct sockaddr_in *address = calloc(1, sizeof(*address)); if (!address) abort();
        address->sin_family = AF_INET; inet_pton(AF_INET, ip, &address->sin_addr); entry->ifa_addr = (struct sockaddr *)address;
    } else if (family == AF_INET6) {
        struct sockaddr_in6 *address = calloc(1, sizeof(*address)); if (!address) abort();
        address->sin6_family = AF_INET6; inet_pton(AF_INET6, ip, &address->sin6_addr); entry->ifa_addr = (struct sockaddr *)address;
    }
    return entry;
}
static int Fixture_getifaddrs(struct ifaddrs **result) {
    atomic_fetch_add(&gGets, 1); *result = NULL;
    if (gIfMode == 8) return 0;
    struct ifaddrs *head = Node(0, "en0", NULL), *tail = head;
    tail->ifa_next = Node(AF_INET, "pdp_ip0", "198.51.100.1"); tail = tail->ifa_next;
    tail->ifa_next = Node(AF_INET, NULL, "198.51.100.2"); tail = tail->ifa_next;
    int family = gIfMode == 6 ? AF_INET6 : AF_INET;
    tail->ifa_next = Node(family, "en0", family == AF_INET ? "192.0.2.2" : "2001:db8::10"); tail = tail->ifa_next;
    tail->ifa_next = Node(family, "en0", family == AF_INET ? "192.0.2.3" : "2001:db9::20");
    *result = head; atomic_fetch_add(&gActiveLists, 1);
    return gIfMode == 7 ? -1 : 0;
}
static void Fixture_freeifaddrs(struct ifaddrs *list) {
    atomic_fetch_add(&gFrees, 1); atomic_fetch_sub(&gActiveLists, 1);
    while (list) { struct ifaddrs *next = list->ifa_next; free(list->ifa_name); free(list->ifa_addr); free(list); list = next; }
}
static const char *Fixture_ntop(int family, const void *source, char *target, socklen_t size) {
    NSUInteger call = atomic_fetch_add(&gConversions, 1);
    if (gConvertMode == 1 || (gConvertMode == 2 && call == 0)) return NULL;
    return inet_ntop(family, source, target, size);
}
static uint32_t Fixture_random(uint32_t upper) { atomic_fetch_add(&gRNGCalls, 1); return upper ? gRNGValue % upper : 0; }
@interface NSString (NetworkFormatting)
+ (instancetype)px_networkUTF8:(const char *)value;
@end
@implementation NSString (NetworkFormatting)
+ (instancetype)px_networkUTF8:(const char *)value { if (gThrowFormatting) Raise(); return [self stringWithUTF8String:value]; }
@end
@interface NSDictionary (NetworkFiles)
+ (NSDictionary *)px_networkFile:(NSString *)path;
@end
@implementation NSDictionary (NetworkFiles)
+ (NSDictionary *)px_networkFile:(NSString * __unsafe_unretained)path {
    NSDictionary *record = gFiles[path]; gReads++;
    @try { if ([gFault isEqual:@"read"]) Raise(); Run(&gDuringRead); return record; }
    @finally { record = nil; }
}
@end
static NSString *PXActiveProfileIdentityPath(void) { return gIdentity; }
#define PXLog(...) do {} while (0)
@interface CarrierDB : NSObject
+ (instancetype)sharedManager;
- (NSArray *)carriersForCountry:(NSString *)country;
- (NSDictionary *)randomCarrierForCountry:(NSString *)country;
@end
@implementation CarrierDB
+ (instancetype)sharedManager { return [self new]; }
- (NSArray *)carriersForCountry:(NSString *)country { (void)country; return @[]; }
- (NSDictionary *)randomCarrierForCountry:(NSString *)country { (void)country; return gRawCarrier; }
@end
@interface PXRuntimeSourceTransaction : NSObject
@property (nonatomic, strong) NSMutableDictionary *staged;
- (NSDictionary *)dictionaryAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)setDictionary:(NSDictionary *)value atPath:(NSString *)path error:(NSError **)error;
@end
@implementation PXRuntimeSourceTransaction
- (NSDictionary *)dictionaryAtPath:(NSString * __unsafe_unretained)path error:(NSError **)error {
    (void)error; gTxReads++; if ([gFault isEqual:@"tx-read"]) Raise();
    Run(&gDuringTxRead);
    return self.staged[path] ?: gFiles[path] ?: @{};
}
- (BOOL)setDictionary:(NSDictionary * __unsafe_unretained)value atPath:(NSString * __unsafe_unretained)path error:(NSError **)error {
    (void)error; gSets++;
    if ([gFault isEqual:@"tx-set"] || (gFailSetAt && gSets == gFailSetAt)) Raise();
    if (!value || !path) return NO;
    if (!self.staged) self.staged = [NSMutableDictionary dictionary];
    self.staged[path] = [value copy]; return YES;
}
@end
@interface PXProfileArtifactMutation : NSObject
@property (nonatomic, copy) NSString *identityDirectory;
@property (nonatomic) BOOL active;
+ (instancetype)acquireWithIdentityResolver:(NSString *(^)(void))resolver error:(NSError **)error NS_RETURNS_RETAINED;
- (BOOL)performSourceWrite:(BOOL (^)(PXRuntimeSourceTransaction *, NSError **))body error:(NSError **)error;
- (void)invalidate;
@end
@implementation PXProfileArtifactMutation
+ (instancetype)acquireWithIdentityResolver:(NSString *(^ __unsafe_unretained)(void))resolver error:(NSError **)error {
    gAcquires++;
    if (gHeld) { if (error) *error = [NSError errorWithDomain:@"fixture.busy" code:12 userInfo:nil]; return nil; }
    PXProfileArtifactMutation *owner = [self new]; gOwnerRoot = owner;
    NSString *target = nil; BOOL handedOff = NO; owner.active = YES; gHeld = YES;
    @try {
        [gCallbackRoots addObject:resolver]; Run(&gDuringAcquire);
        if ([gFault isEqual:@"acquire"]) Raise();
        target = resolver(); if (!target.length) return nil;
        owner.identityDirectory = target; handedOff = YES; return owner;
    } @finally { if (!handedOff) [owner invalidate]; target = nil; owner = nil; }
}
- (BOOL)performSourceWrite:(BOOL (^ __unsafe_unretained)(PXRuntimeSourceTransaction *, NSError **))body error:(NSError **)error {
    PXRuntimeSourceTransaction *tx = [PXRuntimeSourceTransaction new]; gTxRoot = tx;
    @try {
        gInsideSource = YES; [gCallbackRoots addObject:body]; Run(&gDuringSource);
        BOOL success = body(tx, error);
        if (success && tx.staged.count) { [gFiles addEntriesFromDictionary:tx.staged]; gWrites++; }
        return success;
    } @finally { gInsideSource = NO; tx = nil; }
}
- (void)invalidate { if (self.active) { self.active = NO; gHeld = NO; } }
@end
#include "PXNetworkStages.inc"
#include "PXNetworkBoundaryHelpers.inc"
@interface NetworkManager : NSObject
#include "PXNetworkBoundaryDeclarations.inc"
@end
#define getifaddrs Fixture_getifaddrs
#define freeifaddrs Fixture_freeifaddrs
#define inet_ntop Fixture_ntop
#define arc4random_uniform Fixture_random
#define stringWithUTF8String px_networkUTF8
#define dictionaryWithContentsOfFile px_networkFile
@implementation NetworkManager
#include "PXNetworkBoundaryMethods.inc"
@end
#undef dictionaryWithContentsOfFile
#undef stringWithUTF8String
#undef arc4random_uniform
#undef inet_ntop
#undef freeifaddrs
#undef getifaddrs
@interface PXProviderNetwork : NetworkManager
@end
@implementation PXProviderNetwork
+ (NSString *)getCurrentLocalIPAddress { gProviders++; CHECK(!gInsideSource, "network provider stays outside source gate"); Run(&gDuringProvider); return gRawIPv4; }
+ (NSString *)generateSpoofedLocalIPAddressFromCurrent { return [self getCurrentLocalIPAddress]; }
+ (NSString *)generateSpoofedLocalIPv6AddressFromCurrent { gProviders++; CHECK(!gInsideSource, "IPv6 provider stays outside source gate"); Run(&gDuringProvider); return gRawIPv6; }
+ (NSDictionary *)getRandomCarrierForCountry:(NSString * __unsafe_unretained)country { (void)country; gProviders++; CHECK(!gInsideSource, "carrier provider stays outside source gate"); Run(&gDuringProvider); return gRawCarrier; }
@end
static NSString *File(NSString *name) { return [@"/profiles/a/identity" stringByAppendingPathComponent:name]; }
static void Reset(void) {
    gReads = gWrites = gAcquires = gProviders = gTxReads = gSets = gFailSetAt = 0;
    atomic_store(&gGets, 0); atomic_store(&gFrees, 0); atomic_store(&gConversions, 0); atomic_store(&gRNGCalls, 0);
    gIfMode = 4; gConvertMode = 0; gRNGValue = 0; gThrowFormatting = NO; gHeld = gInsideSource = NO; gFault = nil;
    gIdentity = @"/profiles/a/identity"; gRawIPv4 = @"192.0.2.2"; gRawIPv6 = @"2001:db8::20";
    gRawCarrier = @{ @"name": @"Fixture", @"mcc": @"001", @"mnc": @"01", @"extra": @YES };
    gFiles = [NSMutableDictionary dictionary]; gCallbackRoots = [NSHashTable weakObjectsHashTable];
    gDuringRead = nil; gDuringAcquire = nil; gDuringProvider = nil; gDuringSource = nil; gDuringTxRead = nil; gOwnerRoot = nil; gTxRoot = nil;
}
static void TestInterfaces(void) {
    Reset(); CHECK([[NetworkManager getCurrentLocalIPAddress] isEqual:@"192.0.2.2"], "IPv4 en0 selection skips missing address name and other interface");
    CHECK(atomic_load(&gFrees) == 1 && atomic_load(&gActiveLists) == 0, "IPv4 interface list released once on success");
    gConvertMode = 2; atomic_store(&gConversions, 0);
    CHECK([[NetworkManager getCurrentLocalIPAddress] isEqual:@"192.0.2.3"], "IPv4 failed conversion skips to next valid en0 address");
    gConvertMode = 1;
    CHECK(![NetworkManager getCurrentLocalIPAddress], "failed IPv4 conversion never invents an address");
    gIfMode = 6; gConvertMode = 0;
    CHECK([[NetworkManager generateSpoofedLocalIPv6AddressFromCurrent] isEqual:@"2001:db8::0"], "IPv6 retains detected prefix and legacy suffix generation");
    gConvertMode = 2; atomic_store(&gConversions, 0);
    CHECK([[NetworkManager generateSpoofedLocalIPv6AddressFromCurrent] isEqual:@"2001:db9::0"], "failed IPv6 conversion never reads its uninitialized buffer");
    gConvertMode = 1;
    CHECK([[NetworkManager generateSpoofedLocalIPv6AddressFromCurrent] isEqual:@"fe80::1234:abcd:5678:0"], "IPv6 conversion failure preserves existing fallback policy");
    gIfMode = 7;
    CHECK(![NetworkManager getCurrentLocalIPAddress] && !atomic_load(&gActiveLists), "getifaddrs failure releases any supplied list without using entries");
    for (NSNumber *mode in @[@4, @6]) {
        gIfMode = mode.intValue; gConvertMode = 0; gThrowFormatting = YES; BOOL threw = NO;
        @try { if (gIfMode == 4) [NetworkManager getCurrentLocalIPAddress]; else [NetworkManager generateSpoofedLocalIPv6AddressFromCurrent]; }
        @catch (NSException *exception) { threw = [exception.name isEqual:@"fixture.network"]; }
        CHECK(threw && !atomic_load(&gActiveLists), "interface list cleanup runs when Foundation formatting throws");
    }
    Reset();
    CHECK([[NetworkManager generateSpoofedLocalIPAddressFromCurrent] isEqual:@"192.0.2.3"] && atomic_load(&gRNGCalls) == 10,
          "IPv4 repeated RNG respects ten-draw bound and still changes original octet");
    __block _Atomic NSUInteger mismatches = 0;
    dispatch_apply(128, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
        (void)index; @autoreleasepool { if (![[NetworkManager getCurrentLocalIPAddress] isEqual:@"192.0.2.2"]) atomic_fetch_add(&mismatches, 1); }
    });
    CHECK(!atomic_load(&mismatches) && !atomic_load(&gActiveLists), "concurrent IPv4 detection uses independent conversion buffers and balanced lists");
}
static void TestReaders(void) {
    Reset();
    gFiles[File(@"network_settings.plist")] = @{ @"localIPAddress": @[], @"localIPv6Address": @42, @"carrierName": @"bad", @"mcc": @[], @"mnc": @"01" };
    gFiles[File(@"carrier_details.plist")] = @{ @"carrierName": @[], @"mcc": @"001", @"mnc": @"01" };
    gFiles[File(@"device_ids.plist")] = @{ @"LocalIPAddress": @"saved", @"LocalIPv6Address": @"saved-v6", @"CarrierName": @"Saved", @"CarrierMCC": @310, @"CarrierMNC": @7 };
    CHECK([[PXProviderNetwork getSavedLocalIPAddress] isEqual:@"saved"] && [[PXProviderNetwork getSavedLocalIPv6Address] isEqual:@"saved-v6"], "malformed primary IP fields fall through to typed IDs without generation");
    CHECK(([[PXProviderNetwork getSavedCarrierDetails] isEqual:@{ @"name": @"Saved", @"mcc": @"310", @"mnc": @"7" }]), "carrier readers fall through complete typed records preserving numeric legacy codes");
    CHECK(!gAcquires && !gProviders && !gWrites, "saved hits use no lifecycle provider or source work");
    gFiles[File(@"network_settings.plist")] = @{ @"localIPAddress": @"", @"localIPv6Address": @"" };
    CHECK([[PXProviderNetwork getSavedLocalIPAddress] isEqual:@""] && [[PXProviderNetwork getSavedLocalIPv6Address] isEqual:@""], "saved empty IP strings retain legacy read-hit policy");
    gIdentity = @""; NSUInteger reads = gReads;
    CHECK(![PXProviderNetwork getSavedLocalIPAddress] && ![PXProviderNetwork getSavedCarrierDetails] && gReads == reads, "empty identity never becomes a relative file read");
    Reset(); gDuringRead = ^{ gIdentity = @"/profiles/b/identity"; };
    CHECK(![PXProviderNetwork getSavedLocalIPAddress] && !gProviders && !gWrites, "read miss does not redirect its captured identity after selection changes");
}
static void TestFrozenWrites(void) {
    Reset(); NSMutableString *ip = [@"192.0.2.10" mutableCopy], *v6 = [@"2001:db8::10" mutableCopy];
    gDuringAcquire = ^{ [ip setString:@"changed"]; [v6 setString:@"changed"]; };
    CHECK([PXProviderNetwork saveLocalIPAddress:ip ipv6Address:v6] && [gFiles[File(@"network_settings.plist")][@"localIPAddress"] isEqual:@"192.0.2.10"] &&
          [gFiles[File(@"device_ids.plist")][@"LocalIPv6Address"] isEqual:@"2001:db8::10"], "paired save freezes both input strings before target resolution");
    Reset(); ip = [@"192.0.2.11" mutableCopy]; gDuringProvider = ^{ [ip setString:@"changed"]; };
    CHECK([PXProviderNetwork saveLocalIPAddress:ip] && [gFiles[File(@"device_ids.plist")][@"LocalIPAddress"] isEqual:@"192.0.2.11"] && gProviders == 1,
          "single save retains frozen IPv4 across optional IPv6 provider");
    Reset(); NSMutableString *name = [@"Frozen" mutableCopy], *mcc = [@"001" mutableCopy], *mnc = [@"01" mutableCopy];
    gDuringAcquire = ^{ [name setString:@"changed"]; [mcc setString:@"changed"]; [mnc setString:@"changed"]; };
    CHECK([PXProviderNetwork saveCarrierDetails:name mcc:mcc mnc:mnc] && [gFiles[File(@"carrier_details.plist")][@"carrierName"] isEqual:@"Frozen"] &&
          [gFiles[File(@"network_settings.plist")][@"mcc"] isEqual:@"001"] && [gFiles[File(@"device_ids.plist")][@"CarrierMNC"] isEqual:@"01"], "carrier save freezes one scalar tuple for all three files");
    Reset(); CHECK([PXProviderNetwork saveLocalIPAddress:nil ipv6Address:nil] && [PXProviderNetwork saveCarrierDetails:nil mcc:nil mnc:nil], "nil pair and nil carrier retain their legacy save semantics");
    Reset(); CHECK(![PXProviderNetwork saveLocalIPAddress:(id)@[]] && ![PXProviderNetwork saveLocalIPAddress:(id)@1 ipv6Address:nil] &&
          ![PXProviderNetwork saveCarrierDetails:(id)@[] mcc:nil mnc:nil] && !gAcquires, "unsupported explicit inputs stop before lifecycle or source work");
    Reset(); gRawIPv4 = @[]; gRawIPv6 = NSNull.null; gRawCarrier = @[];
    CHECK(![PXProviderNetwork getSavedLocalIPAddressWithForcedRefresh:YES] && ![PXProviderNetwork getSavedCarrierDetailsWithForcedRefresh:YES] && !gWrites && !gHeld,
          "malformed optional providers do not crash or persist malformed candidates");
    Reset(); CHECK([[PXProviderNetwork getSavedCarrierDetailsWithForcedRefresh:YES][@"extra"] boolValue], "generated carrier candidate retains unrelated provider metadata");
}
static void TestDirectStageSnapshots(void) {
    Reset(); PXRuntimeSourceTransaction *tx = [PXRuntimeSourceTransaction new];
    NSMutableString *identity = [@"/profiles/a/identity" mutableCopy], *ip = [@"192.0.2.10" mutableCopy], *ipv6 = [@"2001:db8::10" mutableCopy];
    gDuringTxRead = ^{ [identity setString:@"/profiles/b/identity"]; [ip setString:@"changed"]; [ipv6 setString:@"changed"]; };
    CHECK(PXStageRuntimeAddresses(tx, identity, ip, ipv6, NO, NSDate.date, NULL) &&
          [tx.staged[File(@"network_settings.plist")][@"localIPAddress"] isEqual:@"192.0.2.10"] && [tx.staged[File(@"device_ids.plist")][@"LocalIPv6Address"] isEqual:@"2001:db8::10"] && tx.staged.count == 2,
          "direct address staging freezes identity and inputs before transaction callbacks");
    Reset(); tx = [PXRuntimeSourceTransaction new]; identity = [@"/profiles/a/identity" mutableCopy];
    NSMutableString *name = [@"Frozen" mutableCopy], *mcc = [@"001" mutableCopy], *mnc = [@"01" mutableCopy];
    NSDictionary *carrier = @{ @"carrierName": name, @"mcc": mcc, @"mnc": mnc, @"keep": @YES };
    gDuringTxRead = ^{ [identity setString:@"/profiles/b/identity"]; [name setString:@"changed"]; [mcc setString:@"999"]; [mnc setString:@"99"]; };
    CHECK(PXStageRuntimeCarrier(tx, identity, carrier, NSDate.date, NULL) && [tx.staged[File(@"carrier_details.plist")][@"carrierName"] isEqual:@"Frozen"] &&
          [tx.staged[File(@"network_settings.plist")][@"mcc"] isEqual:@"001"] && [tx.staged[File(@"device_ids.plist")][@"CarrierMNC"] isEqual:@"01"] &&
          [tx.staged[File(@"carrier_details.plist")][@"keep"] boolValue] && tx.staged.count == 3 && !gAcquires && !gWrites,
          "direct carrier staging freezes mutable scalars once for all files without acquiring ownership or losing extras");
}
static void TestExceptionalOwnership(void) {
    for (NSString *fault in @[@"acquire", @"read", @"tx-read", @"tx-set", @"provider", @"second-write", @"carrier-third-write"]) {
        Reset(); __weak id weakInput = nil, weakToken = nil;
        @autoreleasepool {
            NSMutableString *input = [@"192.0.2.10" mutableCopy]; weakInput = input;
            id token = [NSObject new]; weakToken = token;
            gFiles[File(@"network_settings.plist")] = @{ @"keep": token };
            gFiles[File(@"device_ids.plist")] = @{ @"keep": token };
            gFault = fault;
            if ([fault isEqual:@"provider"]) gDuringProvider = ^{ Raise(); };
            if ([fault isEqual:@"second-write"]) gFailSetAt = 2;
            if ([fault isEqual:@"carrier-third-write"]) gFailSetAt = 3;
            BOOL threw = NO;
            @try {
                if ([fault isEqual:@"read"]) [PXProviderNetwork getSavedLocalIPAddress];
                else if ([fault isEqual:@"provider"]) [PXProviderNetwork getSavedLocalIPAddressWithForcedRefresh:YES];
                else if ([fault isEqual:@"carrier-third-write"]) [PXProviderNetwork saveCarrierDetails:@"Carrier" mcc:@"001" mnc:@"01"];
                else [PXProviderNetwork saveLocalIPAddress:input ipv6Address:@"2001:db8::10"];
            } @catch (NSException *exception) { threw = [exception.name isEqual:@"fixture.network"]; }
            CHECK(threw && !gHeld && !gInsideSource && !gWrites, "network exceptional exit propagates and releases ownership before any mock commit");
            [gFiles removeAllObjects]; input = nil; token = nil;
        }
        if (weakInput || weakToken || gOwnerRoot || gTxRoot || gCallbackRoots.allObjects.count)
            fprintf(stderr, "DETAIL: network fault=%s input=%d token=%d owner=%d tx=%d blocks=%lu\n", fault.UTF8String, weakInput != nil, weakToken != nil, gOwnerRoot != nil, gTxRoot != nil, (unsigned long)gCallbackRoots.allObjects.count);
        CHECK(!weakInput && !weakToken && !gOwnerRoot && !gTxRoot && !gCallbackRoots.allObjects.count, "network and exact staging helpers release retained inputs partial dictionaries and block captures after pool drain");
    }
}
int main(void) { @autoreleasepool {
    @try { TestInterfaces(); TestReaders(); TestFrozenWrites(); TestDirectStageSnapshots(); TestExceptionalOwnership(); }
    @catch (NSException *exception) { gFailures++; fprintf(stderr, "FAIL: unexpected network exception: %s\n", exception.description.UTF8String); }
    printf("Network boundaries: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
    return gFailures ? 1 : 0;
} }
