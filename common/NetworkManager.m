#import "NetworkManager.h"
#import "CarrierDB.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#include <string.h>
#import "TLinkIOSLogging.h"
#import "PXPaths.h"
#import "PXRuntimeArtifactWriter.h"
#import "PXProfileArtifactMutation.h"

static NSString *PXNetworkString(id value) {
    @try { return [value isKindOfClass:NSString.class] ? value : nil; }
    @finally { value = nil; }
}
static NSString *PXNetworkCarrierScalar(id value) {
    @try {
        if ([value isKindOfClass:NSString.class]) return value;
        return [value isKindOfClass:NSNumber.class] ? [value stringValue] : nil;
    } @finally { value = nil; }
}
static NSDictionary *PXNetworkCarrierRecord(id raw, NSString *nameKey, NSString *mccKey, NSString *mncKey) {
    NSString *name = nil, *mcc = nil, *mnc = nil;
    @try {
        if (![raw isKindOfClass:NSDictionary.class]) return nil;
        name = [PXNetworkString(raw[nameKey]) copy];
        mcc = [PXNetworkCarrierScalar(raw[mccKey]) copy];
        mnc = [PXNetworkCarrierScalar(raw[mncKey]) copy];
        return name && mcc && mnc ? @{ @"name": name, @"mcc": mcc, @"mnc": mnc } : nil;
    } @finally { name = nil; mcc = nil; mnc = nil; raw = nil; nameKey = nil; mccKey = nil; mncKey = nil; }
}

@interface NetworkManager ()
+ (PXProfileArtifactMutation *)acquireMutationForIdentityDirectory:(NSString *)expected error:(NSError **)error;
+ (BOOL)saveAddresses:(NSString *)ipv4 ipv6:(NSString *)ipv6 inMutation:(PXProfileArtifactMutation *)mutation error:(NSError **)error;
+ (BOOL)saveSingleAddress:(NSString *)ipv4 inMutation:(PXProfileArtifactMutation *)mutation error:(NSError **)error;
+ (BOOL)saveCarrierDetails:(NSString *)name mcc:(NSString *)mcc mnc:(NSString *)mnc inMutation:(PXProfileArtifactMutation *)mutation error:(NSError **)error;
+ (NSString *)generateAndSaveAddressForIdentityDirectory:(NSString *)expected forceRefresh:(BOOL)forceRefresh;
+ (NSString *)generateAndSaveIPv6ForIdentityDirectory:(NSString *)expected;
+ (NSDictionary *)generateAndSaveCarrierForIdentityDirectory:(NSString *)expected;
@end

@implementation NetworkManager

+ (instancetype)sharedManager {
    static NetworkManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Carrier Methods (data-driven via CarrierDB)

+ (NSArray *)getCarriersForCountry:(NSString *)countryCode {
    @try { return [[CarrierDB sharedManager] carriersForCountry:countryCode]; }
    @finally { countryCode = nil; }
}

+ (NSDictionary *)getRandomCarrierForCountry:(NSString *)countryCode {
    @try { return [[CarrierDB sharedManager] randomCarrierForCountry:countryCode]; }
    @finally { countryCode = nil; }
}

// Legacy helpers — kept for call sites; backed by CarrierDB.
+ (NSArray *)getVietnamCarriers {
    return [[CarrierDB sharedManager] carriersForCountry:@"VN"];
}

+ (NSArray *)getUSCarriers {
    return [[CarrierDB sharedManager] carriersForCountry:@"US"];
}

+ (NSArray *)getIndiaCarriers {
    return [[CarrierDB sharedManager] carriersForCountry:@"IN"];
}

+ (NSArray *)getCanadaCarriers {
    return [[CarrierDB sharedManager] carriersForCountry:@"CA"];
}

#pragma mark - IP Address Methods

+ (NSString *)getCurrentLocalIPAddress {
    NSString *address = nil;
    struct ifaddrs *interfaces = NULL;
    @try {
        if (getifaddrs(&interfaces) == 0) {
            for (struct ifaddrs *entry = interfaces; entry; entry = entry->ifa_next) {
                if (!entry->ifa_addr || entry->ifa_addr->sa_family != AF_INET ||
                    !entry->ifa_name || strcmp(entry->ifa_name, "en0") != 0) continue;
                // Keep output independent of inet_ntoa storage and check failure.
                char buffer[INET_ADDRSTRLEN] = {0};
                struct sockaddr_in *ip = (struct sockaddr_in *)entry->ifa_addr;
                if (!inet_ntop(AF_INET, &ip->sin_addr, buffer, sizeof(buffer))) continue;
                address = [NSString stringWithUTF8String:buffer];
                if (address) break;
            }
        }
        return address;
    } @finally { if (interfaces) freeifaddrs(interfaces); address = nil; }
}

+ (NSString *)generateSpoofedLocalIPAddressFromCurrent {
    NSString *currentIP = nil, *spoofedIP = nil;
    NSArray<NSString *> *parts = nil;
    @try {
        currentIP = [PXNetworkString([self getCurrentLocalIPAddress]) copy];
        if (!currentIP.length) return nil;
        parts = [currentIP componentsSeparatedByString:@"."];
        if (parts.count == 4) {
            int lastOctet = [parts[3] intValue], newLastOctet = lastOctet, attempts = 0;
            while (newLastOctet == lastOctet && attempts < 10) {
                newLastOctet = 2 + arc4random_uniform(252);
                attempts++;
            }
            // Preserve the normal draws and bound; even repeated RNG values
            // must not return the original octet after the tenth attempt.
            if (newLastOctet == lastOctet) newLastOctet = 2 + ((lastOctet - 2 + 1) % 252);
            spoofedIP = [NSString stringWithFormat:@"%@.%@.%@.%d", parts[0], parts[1], parts[2], newLastOctet];
            return spoofedIP;
        }
        return currentIP;
    } @finally { spoofedIP = nil; parts = nil; currentIP = nil; }
}

+ (NSString *)generateSpoofedLocalIPv6AddressFromCurrent {
    NSString *address = nil, *last = nil, *spoofedLast = nil;
    NSArray *parts = nil;
    NSMutableArray *mutableParts = nil;
    struct ifaddrs *interfaces = NULL;
    @try {
        @try {
            if (getifaddrs(&interfaces) == 0) {
                for (struct ifaddrs *entry = interfaces; entry; entry = entry->ifa_next) {
                    if (!entry->ifa_addr || entry->ifa_addr->sa_family != AF_INET6 ||
                        !entry->ifa_name || strcmp(entry->ifa_name, "en0") != 0) continue;
                    char buffer[INET6_ADDRSTRLEN] = {0};
                    struct sockaddr_in6 *ip = (struct sockaddr_in6 *)entry->ifa_addr;
                    if (!inet_ntop(AF_INET6, &ip->sin6_addr, buffer, sizeof(buffer))) continue;
                    address = [NSString stringWithUTF8String:buffer];
                    if (address) break;
                }
            }
        } @finally { if (interfaces) { freeifaddrs(interfaces); interfaces = NULL; } }
        if (!address) address = @"fe80::1234:abcd:5678:9abc";
        parts = [address componentsSeparatedByString:@":"];
        if (parts.count >= 2) {
            mutableParts = [parts mutableCopy];
            last = parts.lastObject;
            spoofedLast = [NSString stringWithFormat:@"%x", arc4random_uniform(0xFFFF)];
            if (last.length > 0) mutableParts[mutableParts.count - 1] = spoofedLast;
            else if (mutableParts.count > 1) mutableParts[mutableParts.count - 2] = spoofedLast;
            return [mutableParts componentsJoinedByString:@":"];
        }
        return address;
    } @finally { spoofedLast = nil; last = nil; mutableParts = nil; parts = nil; address = nil; }
}

#pragma mark - Profile-based IP Storage

// Helper method to get the path to the current profile's identity directory
+ (NSString *)profileIdentityPath {
    NSString *identityPath = nil;
    @try {
        identityPath = PXNetworkString(PXActiveProfileIdentityPath());
        if (!identityPath.length) {
            PXLog(@"[WeaponX] Warning: No active profile identity path found for NetworkManager");
            return nil;
        }
        return identityPath;
    } @finally { identityPath = nil; }
}

+ (BOOL)saveLocalIPAddress:(NSString *)ipAddress ipv6Address:(NSString *)ipv6Address {
    NSError *error = nil;
    PXProfileArtifactMutation *mutation = nil;
    NSString *ipv4 = nil, *ipv6 = nil;
    @try {
        if ((ipAddress && ![ipAddress isKindOfClass:NSString.class]) || (ipv6Address && ![ipv6Address isKindOfClass:NSString.class])) return NO;
        ipv4 = [ipAddress copy]; ipv6 = [ipv6Address copy];
        mutation = [self acquireMutationForIdentityDirectory:nil error:&error];
        BOOL success = NO;
        @try { if (mutation) success = [self saveAddresses:ipv4 ipv6:ipv6 inMutation:mutation error:&error]; }
        @finally { [mutation invalidate]; }
        PXLog(@"[NetworkManager] IPv4/IPv6 save %@: %@", success ? @"committed" : @"failed", error ?: @"");
        return success;
    } @finally { mutation = nil; error = nil; ipv4 = nil; ipv6 = nil; ipAddress = nil; ipv6Address = nil; }
}

+ (PXProfileArtifactMutation *)acquireMutationForIdentityDirectory:(NSString *)expected error:(NSError **)error {
    NSString *(^resolver)(void) = nil;
    PXProfileArtifactMutation *mutation = nil;
    @try {
        if (expected && ![expected isKindOfClass:NSString.class]) return nil;
        expected = [expected copy];
        resolver = ^NSString *{
            NSString *current = nil;
            @try {
                current = [PXNetworkString([self profileIdentityPath]) copy];
                return !expected || [expected isEqual:current] ? current : nil;
            } @finally { current = nil; }
        };
        mutation = [PXProfileArtifactMutation acquireWithIdentityResolver:resolver error:error];
        return mutation;
    } @finally { resolver = nil; mutation = nil; expected = nil; }
}

+ (BOOL)saveAddresses:(NSString *)ipAddress ipv6:(NSString *)ipv6Address inMutation:(PXProfileArtifactMutation *)mutation error:(NSError **)error {
    NSDate *now = nil;
    BOOL (^sourceWrite)(PXRuntimeSourceTransaction *, NSError **) = nil;
    @try {
        if ((ipAddress && ![ipAddress isKindOfClass:NSString.class]) || (ipv6Address && ![ipv6Address isKindOfClass:NSString.class])) return NO;
        ipAddress = [ipAddress copy]; ipv6Address = [ipv6Address copy];
        now = NSDate.date;
        sourceWrite = ^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
            @try { return PXStageRuntimeAddresses(tx, mutation.identityDirectory, ipAddress, ipv6Address, NO, now, writeError); }
            @finally { tx = nil; }
        };
        return [mutation performSourceWrite:sourceWrite error:error];
    } @finally { sourceWrite = nil; now = nil; mutation = nil; ipAddress = nil; ipv6Address = nil; }
}

+ (BOOL)saveLocalIPAddress:(NSString *)ipAddress {
    NSError *error = nil;
    NSString *frozen = nil;
    PXProfileArtifactMutation *mutation = nil;
    @try {
        if (![ipAddress isKindOfClass:NSString.class] || !ipAddress.length) return NO;
        frozen = [ipAddress copy];
        mutation = [self acquireMutationForIdentityDirectory:nil error:&error];
        BOOL success = NO;
        @try { if (mutation) success = [self saveSingleAddress:frozen inMutation:mutation error:&error]; }
        @finally { [mutation invalidate]; }
        PXLog(@"[NetworkManager] IPv4 save %@: %@", success ? @"committed" : @"failed", error ?: @"");
        return success;
    } @finally { mutation = nil; frozen = nil; error = nil; ipAddress = nil; }
}

+ (BOOL)saveSingleAddress:(NSString *)ipAddress inMutation:(PXProfileArtifactMutation *)mutation error:(NSError **)error {
    __block BOOL needsIPv6 = NO;
    NSDate *now = nil, *preparedAt = nil;
    NSString *candidateIPv6 = nil;
    BOOL (^sourceWrite)(PXRuntimeSourceTransaction *, NSError **) = nil;
    @try {
        ipAddress = [PXNetworkString(ipAddress) copy];
        if (!ipAddress.length) return NO;
        now = NSDate.date;
        sourceWrite = ^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
            @try { return PXStageRuntimeIPv4WithExistingPair(tx, mutation.identityDirectory, ipAddress, now, &needsIPv6, writeError); }
            @finally { tx = nil; }
        };
        BOOL success = [mutation performSourceWrite:sourceWrite error:error];
        sourceWrite = nil;
        if (success && needsIPv6) {
            candidateIPv6 = [PXNetworkString([self generateSpoofedLocalIPv6AddressFromCurrent]) copy];
            preparedAt = NSDate.date;
            sourceWrite = ^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
                @try { return PXStageRuntimeAddresses(tx, mutation.identityDirectory, ipAddress, candidateIPv6, YES, preparedAt, writeError); }
                @finally { tx = nil; }
            };
            success = [mutation performSourceWrite:sourceWrite error:error];
        }
        return success;
    } @finally { sourceWrite = nil; candidateIPv6 = nil; preparedAt = nil; now = nil; mutation = nil; ipAddress = nil; }
}

+ (NSString *)generateAndSaveAddressForIdentityDirectory:(NSString *)expected forceRefresh:(BOOL)forceRefresh {
    NSError *error = nil;
    PXProfileArtifactMutation *mutation = nil;
    NSString *localIP = nil, *ipv6 = nil;
    @try {
        mutation = [self acquireMutationForIdentityDirectory:expected error:&error];
        if (!mutation) { PXLog(@"[NetworkManager] Address refresh unavailable: %@", error); return nil; }
        @try {
            localIP = [PXNetworkString(forceRefresh ? [self generateSpoofedLocalIPAddressFromCurrent] : [self getCurrentLocalIPAddress]) copy];
            if (forceRefresh) {
                ipv6 = [PXNetworkString([self generateSpoofedLocalIPv6AddressFromCurrent]) copy];
                if (localIP.length) [self saveAddresses:localIP ipv6:ipv6 inMutation:mutation error:&error];
            } else if (localIP.length) [self saveSingleAddress:localIP inMutation:mutation error:&error];
            return localIP; // Candidate, not commit acknowledgement.
        } @finally { [mutation invalidate]; }
    } @finally { mutation = nil; error = nil; ipv6 = nil; localIP = nil; expected = nil; }
}

+ (NSString *)getSavedLocalIPAddress {
    return [self getSavedLocalIPAddressWithForcedRefresh:NO];
}

+ (NSString *)getSavedLocalIPAddressWithForcedRefresh:(BOOL)forceRefresh {
    NSString *identityDir = nil, *path = nil, *localIP = nil;
    NSDictionary *record = nil;
    @try {
        if (forceRefresh) return [self generateAndSaveAddressForIdentityDirectory:nil forceRefresh:YES];
        identityDir = [PXNetworkString([self profileIdentityPath]) copy];
        if (!identityDir.length) { PXLog(@"[WeaponX] Error: Could not get profile identity path for NetworkManager"); return nil; }
        path = [identityDir stringByAppendingPathComponent:@"network_settings.plist"];
        record = [NSDictionary dictionaryWithContentsOfFile:path];
        localIP = [record isKindOfClass:NSDictionary.class] ? PXNetworkString(record[@"localIPAddress"]) : nil;
        if (!localIP) {
            path = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
            record = [NSDictionary dictionaryWithContentsOfFile:path];
            localIP = [record isKindOfClass:NSDictionary.class] ? PXNetworkString(record[@"LocalIPAddress"]) : nil;
        }
        return localIP ?: [self generateAndSaveAddressForIdentityDirectory:identityDir forceRefresh:NO];
    } @finally { localIP = nil; record = nil; path = nil; identityDir = nil; }
}

+ (NSString *)getSavedLocalIPv6Address {
    NSString *identityDir = nil, *path = nil, *ipv6 = nil;
    NSDictionary *record = nil;
    @try {
        identityDir = [PXNetworkString([self profileIdentityPath]) copy];
        if (!identityDir.length) return nil;
        path = [identityDir stringByAppendingPathComponent:@"network_settings.plist"];
        record = [NSDictionary dictionaryWithContentsOfFile:path];
        ipv6 = [record isKindOfClass:NSDictionary.class] ? PXNetworkString(record[@"localIPv6Address"]) : nil;
        if (!ipv6) {
            path = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
            record = [NSDictionary dictionaryWithContentsOfFile:path];
            ipv6 = [record isKindOfClass:NSDictionary.class] ? PXNetworkString(record[@"LocalIPv6Address"]) : nil;
        }
        return ipv6 ?: [self generateAndSaveIPv6ForIdentityDirectory:identityDir];
    } @finally { ipv6 = nil; record = nil; path = nil; identityDir = nil; }
}

+ (NSString *)generateAndSaveIPv6ForIdentityDirectory:(NSString *)expected {
    NSError *error = nil;
    PXProfileArtifactMutation *mutation = nil;
    NSString *ipv6 = nil, *ipv4 = nil;
    @try {
        mutation = [self acquireMutationForIdentityDirectory:expected error:&error];
        if (!mutation) { PXLog(@"[NetworkManager] IPv6 refresh unavailable: %@", error); return nil; }
        @try {
            ipv6 = [PXNetworkString([self generateSpoofedLocalIPv6AddressFromCurrent]) copy];
            if (ipv6.length) {
                ipv4 = [PXNetworkString([self getCurrentLocalIPAddress]) copy];
                [self saveAddresses:ipv4 ipv6:ipv6 inMutation:mutation error:&error];
            }
            return ipv6;
        } @finally { [mutation invalidate]; }
    } @finally { mutation = nil; error = nil; ipv4 = nil; ipv6 = nil; expected = nil; }
}

#pragma mark - Profile-based Carrier Storage

+ (BOOL)saveCarrierDetails:(NSString *)carrierName mcc:(NSString *)mcc mnc:(NSString *)mnc {
    NSError *error = nil;
    PXProfileArtifactMutation *mutation = nil;
    NSString *name = nil, *frozenMCC = nil, *frozenMNC = nil;
    @try {
        if ((carrierName && ![carrierName isKindOfClass:NSString.class]) || (mcc && ![mcc isKindOfClass:NSString.class]) || (mnc && ![mnc isKindOfClass:NSString.class])) return NO;
        name = [carrierName copy]; frozenMCC = [mcc copy]; frozenMNC = [mnc copy];
        mutation = [self acquireMutationForIdentityDirectory:nil error:&error];
        BOOL success = NO;
        @try { if (mutation) success = [self saveCarrierDetails:name mcc:frozenMCC mnc:frozenMNC inMutation:mutation error:&error]; }
        @finally { [mutation invalidate]; }
        PXLog(@"[NetworkManager] Carrier save %@: %@", success ? @"committed" : @"failed", error ?: @"");
        return success;
    } @finally { mutation = nil; error = nil; name = nil; frozenMCC = nil; frozenMNC = nil; carrierName = nil; mcc = nil; mnc = nil; }
}

+ (BOOL)saveCarrierDetails:(NSString *)carrierName mcc:(NSString *)mcc mnc:(NSString *)mnc inMutation:(PXProfileArtifactMutation *)mutation error:(NSError **)error {
    NSDictionary *carrier = nil;
    NSDate *networkTimestamp = nil;
    NSString *name = nil, *frozenMCC = nil, *frozenMNC = nil;
    BOOL (^sourceWrite)(PXRuntimeSourceTransaction *, NSError **) = nil;
    @try {
        if ((carrierName && ![carrierName isKindOfClass:NSString.class]) || (mcc && ![mcc isKindOfClass:NSString.class]) || (mnc && ![mnc isKindOfClass:NSString.class])) return NO;
        name = [carrierName copy] ?: @""; frozenMCC = [mcc copy] ?: @""; frozenMNC = [mnc copy] ?: @"";
        carrier = @{ @"carrierName": name, @"mcc": frozenMCC, @"mnc": frozenMNC, @"lastUpdated": NSDate.date };
        networkTimestamp = NSDate.date;
        sourceWrite = ^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
            @try { return PXStageRuntimeCarrier(tx, mutation.identityDirectory, carrier, networkTimestamp, writeError); }
            @finally { tx = nil; }
        };
        return [mutation performSourceWrite:sourceWrite error:error];
    } @finally { sourceWrite = nil; carrier = nil; networkTimestamp = nil; name = nil; frozenMCC = nil; frozenMNC = nil; mutation = nil; carrierName = nil; mcc = nil; mnc = nil; }
}

+ (NSDictionary *)generateAndSaveCarrierForIdentityDirectory:(NSString *)expected {
    NSError *error = nil;
    PXProfileArtifactMutation *mutation = nil;
    NSString *countryCode = nil;
    id raw = nil;
    NSDictionary *fields = nil, *carrier = nil;
    NSMutableDictionary *candidate = nil;
    @try {
        mutation = [self acquireMutationForIdentityDirectory:expected error:&error];
        if (!mutation) { PXLog(@"[NetworkManager] Carrier refresh unavailable: %@", error); return nil; }
        @try {
            countryCode = [PXNetworkString([self getCurrentCountryCode]) copy] ?: @"us";
            raw = [self getRandomCarrierForCountry:countryCode];
            fields = PXNetworkCarrierRecord(raw, @"name", @"mcc", @"mnc");
            if (!fields) return nil;
            candidate = [raw mutableCopy]; [candidate addEntriesFromDictionary:fields]; carrier = [candidate copy];
            [self saveCarrierDetails:carrier[@"name"] mcc:carrier[@"mcc"] mnc:carrier[@"mnc"] inMutation:mutation error:&error];
            return carrier;
        } @finally { [mutation invalidate]; }
    } @finally { mutation = nil; error = nil; countryCode = nil; carrier = nil; candidate = nil; fields = nil; raw = nil; expected = nil; }
}

+ (NSDictionary *)getSavedCarrierDetails {
    return [self getSavedCarrierDetailsWithForcedRefresh:NO];
}

+ (NSDictionary *)getSavedCarrierDetailsWithForcedRefresh:(BOOL)forceRefresh {
    NSString *identityDir = nil, *path = nil;
    NSDictionary *record = nil, *carrier = nil;
    @try {
        if (forceRefresh) return [self generateAndSaveCarrierForIdentityDirectory:nil];
        identityDir = [PXNetworkString([self profileIdentityPath]) copy];
        if (!identityDir.length) { PXLog(@"[WeaponX] Error: Could not get profile identity path for carrier details"); return nil; }
        path = [identityDir stringByAppendingPathComponent:@"carrier_details.plist"];
        record = [NSDictionary dictionaryWithContentsOfFile:path];
        carrier = PXNetworkCarrierRecord(record, @"carrierName", @"mcc", @"mnc");
        if (carrier) return carrier;
        path = [identityDir stringByAppendingPathComponent:@"network_settings.plist"];
        record = [NSDictionary dictionaryWithContentsOfFile:path];
        carrier = PXNetworkCarrierRecord(record, @"carrierName", @"mcc", @"mnc");
        if (carrier) return carrier;
        path = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        record = [NSDictionary dictionaryWithContentsOfFile:path];
        carrier = PXNetworkCarrierRecord(record, @"CarrierName", @"CarrierMCC", @"CarrierMNC");
        return carrier ?: [self generateAndSaveCarrierForIdentityDirectory:identityDir];
    } @finally { carrier = nil; record = nil; path = nil; identityDir = nil; }
}

// Helper method to get current country code (can be extended in the future)
+ (NSString *)getCurrentCountryCode {
    // For now, we'll return nil which will default to "us" in the caller
    // In the future, this could be enhanced to detect the actual country
    return nil;
}

@end
