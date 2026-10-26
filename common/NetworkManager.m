#import "NetworkManager.h"
#import "CarrierDB.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#import "TLinkIOSLogging.h"
#import "PXPaths.h"
#import "PXRuntimeArtifactWriter.h"
#import "PXProfileArtifactMutation.h"

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
    return [[CarrierDB sharedManager] carriersForCountry:countryCode];
}

+ (NSDictionary *)getRandomCarrierForCountry:(NSString *)countryCode {
    return [[CarrierDB sharedManager] randomCarrierForCountry:countryCode];
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
    struct ifaddrs *temp_addr = NULL;
    
    // Retrieve the current interfaces - returns 0 on success
    if (getifaddrs(&interfaces) == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if (temp_addr->ifa_addr && temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on iOS
                if (temp_addr->ifa_name && [[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                    break;
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    if (interfaces) {
        freeifaddrs(interfaces);
    }
    
    return address;
}

+ (NSString *)generateSpoofedLocalIPAddressFromCurrent {
    NSString *currentIP = [self getCurrentLocalIPAddress];
    if (!currentIP.length) {
        return nil;
    }

    NSArray<NSString *> *parts = [currentIP componentsSeparatedByString:@"."];
    if (parts.count == 4) {
        // Change the last octet to a random value (2-253), not the original
        int lastOctet = [parts[3] intValue];
        int newLastOctet = lastOctet;
        int attempts = 0;
        while (newLastOctet == lastOctet && attempts < 10) {
            newLastOctet = 2 + arc4random_uniform(252); // 2-253
            attempts++;
        }
        NSString *spoofedIP = [NSString stringWithFormat:@"%@.%@.%@.%d", parts[0], parts[1], parts[2], newLastOctet];
        return spoofedIP;
    }

    // Preserve the detected address if parsing unexpectedly fails; never invent a local IPv4.
    return currentIP;
}

+ (NSString *)generateSpoofedLocalIPv6AddressFromCurrent {
    NSString *address = nil;
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    if (getifaddrs(&interfaces) == 0) {
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if (temp_addr->ifa_addr && temp_addr->ifa_addr->sa_family == AF_INET6) {
                if (temp_addr->ifa_name && [[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    char ip6[INET6_ADDRSTRLEN];
                    struct sockaddr_in6 *sin6 = (struct sockaddr_in6 *)temp_addr->ifa_addr;
                    inet_ntop(AF_INET6, &sin6->sin6_addr, ip6, sizeof(ip6));
                    address = [NSString stringWithUTF8String:ip6];
                    break;
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    if (interfaces) {
        freeifaddrs(interfaces);
    }
    if (!address) {
        address = @"fe80::1234:abcd:5678:9abc";
    }
    // Spoof last segment
    NSArray *parts = [address componentsSeparatedByString:@":"];
    if (parts.count >= 2) {
        NSMutableArray *mutableParts = [parts mutableCopy];
        NSString *last = parts.lastObject;
        NSString *spoofedLast = [NSString stringWithFormat:@"%x", arc4random_uniform(0xFFFF)];
        if ([last length] > 0) {
            mutableParts[mutableParts.count-1] = spoofedLast;
        } else if (mutableParts.count > 1) {
            mutableParts[mutableParts.count-2] = spoofedLast;
        }
        return [mutableParts componentsJoinedByString:@":"];
    }
    return address;
}

#pragma mark - Profile-based IP Storage

// Helper method to get the path to the current profile's identity directory
+ (NSString *)profileIdentityPath {
    NSString *identityPath = PXActiveProfileIdentityPath();
    if (!identityPath.length) {
        PXLog(@"[WeaponX] Warning: No active profile identity path found for NetworkManager");
    }
    return identityPath;
}

+ (BOOL)saveLocalIPAddress:(NSString *)ipAddress ipv6Address:(NSString *)ipv6Address {
    NSError *error = nil;
    PXProfileArtifactMutation *mutation = [self acquireMutationForIdentityDirectory:nil error:&error];
    BOOL success = NO;
    @try {
        if (mutation) success = [self saveAddresses:ipAddress ipv6:ipv6Address inMutation:mutation error:&error];
    } @finally { [mutation invalidate]; }
    PXLog(@"[NetworkManager] IPv4/IPv6 save %@: %@", success ? @"committed" : @"failed", error ?: @"");
    return success;
}

+ (PXProfileArtifactMutation *)acquireMutationForIdentityDirectory:(NSString *)expected error:(NSError **)error {
    expected = [expected copy];
    return [PXProfileArtifactMutation acquireWithIdentityResolver:^NSString *{
        NSString *current = [self profileIdentityPath];
        // Read hits stay lock-free. A miss may only persist to the same target
        // if it is still active after lifecycle ownership is acquired.
        return !expected || [expected isEqual:current] ? current : nil;
    } error:error];
}

+ (BOOL)saveAddresses:(NSString *)ipAddress ipv6:(NSString *)ipv6Address inMutation:(PXProfileArtifactMutation *)mutation error:(NSError **)error {
    NSDate *now = [NSDate date];
    return [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return PXStageRuntimeAddresses(tx, mutation.identityDirectory, ipAddress, ipv6Address, NO, now, writeError);
    } error:error];
}

+ (BOOL)saveLocalIPAddress:(NSString *)ipAddress {
    if (!ipAddress.length) return NO;
    NSError *error = nil;
    PXProfileArtifactMutation *mutation = [self acquireMutationForIdentityDirectory:nil error:&error];
    BOOL success = NO;
    @try {
        if (mutation) success = [self saveSingleAddress:ipAddress inMutation:mutation error:&error];
    } @finally { [mutation invalidate]; }
    PXLog(@"[NetworkManager] IPv4 save %@: %@", success ? @"committed" : @"failed", error ?: @"");
    return success;
}

+ (BOOL)saveSingleAddress:(NSString *)ipAddress inMutation:(PXProfileArtifactMutation *)mutation error:(NSError **)error {
    // Existing IPv6 commits in one pass. Hold lifecycle ownership across the
    // optional provider callback without holding the source gate.
    __block BOOL needsIPv6 = NO;
    NSDate *now = [NSDate date];
    BOOL success = [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return PXStageRuntimeIPv4WithExistingPair(tx, mutation.identityDirectory, ipAddress, now, &needsIPv6, writeError);
    } error:error];
    if (success && needsIPv6) {
        NSString *candidateIPv6 = [self generateSpoofedLocalIPv6AddressFromCurrent];
        NSDate *preparedAt = [NSDate date];
        success = [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
            // A bypass writer may have filled IPv6; retain its established value.
            return PXStageRuntimeAddresses(tx, mutation.identityDirectory, ipAddress, candidateIPv6, YES, preparedAt, writeError);
        } error:error];
    }
    return success;
}

+ (NSString *)generateAndSaveAddressForIdentityDirectory:(NSString *)expected forceRefresh:(BOOL)forceRefresh {
    NSError *error = nil;
    PXProfileArtifactMutation *mutation = [self acquireMutationForIdentityDirectory:expected error:&error];
    if (!mutation) { PXLog(@"[NetworkManager] Address refresh unavailable: %@", error); return nil; }
    @try {
        NSString *localIP = forceRefresh ? [self generateSpoofedLocalIPAddressFromCurrent] : [self getCurrentLocalIPAddress];
        if (forceRefresh) {
            NSString *ipv6 = [self generateSpoofedLocalIPv6AddressFromCurrent];
            if (localIP.length) [self saveAddresses:localIP ipv6:ipv6 inMutation:mutation error:&error];
        } else if (localIP.length) [self saveSingleAddress:localIP inMutation:mutation error:&error];
        // Legacy getters return the candidate even when its disk commit fails.
        return localIP;
    } @finally { [mutation invalidate]; }
}

+ (NSString *)getSavedLocalIPAddress {
    return [self getSavedLocalIPAddressWithForcedRefresh:NO];
}

+ (NSString *)getSavedLocalIPAddressWithForcedRefresh:(BOOL)forceRefresh {
    if (forceRefresh) return [self generateAndSaveAddressForIdentityDirectory:nil forceRefresh:YES];
    // Get path to current profile's identity directory
    NSString *identityDir = [[self profileIdentityPath] copy];
    if (!identityDir) {
        PXLog(@"[WeaponX] Error: Could not get profile identity path for NetworkManager");
        return nil;
    }
    
    // Try to read from network_settings.plist
    NSString *networkPath = [identityDir stringByAppendingPathComponent:@"network_settings.plist"];
    NSDictionary *networkDict = [NSDictionary dictionaryWithContentsOfFile:networkPath];
    
    NSString *localIP = networkDict[@"localIPAddress"];
    
    // If not found in dedicated file, try the combined device_ids.plist
    if (!localIP) {
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
        localIP = deviceIds[@"LocalIPAddress"];
    }
    
    if (!localIP) return [self generateAndSaveAddressForIdentityDirectory:identityDir forceRefresh:NO];

    return localIP;
}

+ (NSString *)getSavedLocalIPv6Address {
    NSString *identityDir = [[self profileIdentityPath] copy];
    if (!identityDir) return nil;
    NSDictionary *network = [NSDictionary dictionaryWithContentsOfFile:[identityDir stringByAppendingPathComponent:@"network_settings.plist"]];
    NSString *ipv6 = network[@"localIPv6Address"];
    if (!ipv6) {
        NSDictionary *ids = [NSDictionary dictionaryWithContentsOfFile:[identityDir stringByAppendingPathComponent:@"device_ids.plist"]];
        ipv6 = ids[@"LocalIPv6Address"];
    }
    return ipv6 ?: [self generateAndSaveIPv6ForIdentityDirectory:identityDir];
}

+ (NSString *)generateAndSaveIPv6ForIdentityDirectory:(NSString *)expected {
    NSError *error = nil;
    PXProfileArtifactMutation *mutation = [self acquireMutationForIdentityDirectory:expected error:&error];
    if (!mutation) { PXLog(@"[NetworkManager] IPv6 refresh unavailable: %@", error); return nil; }
    @try {
        NSString *ipv6 = [self generateSpoofedLocalIPv6AddressFromCurrent];
        if (ipv6.length) [self saveAddresses:[self getCurrentLocalIPAddress] ipv6:ipv6 inMutation:mutation error:&error];
        return ipv6;
    } @finally { [mutation invalidate]; }
}

#pragma mark - Profile-based Carrier Storage

+ (BOOL)saveCarrierDetails:(NSString *)carrierName mcc:(NSString *)mcc mnc:(NSString *)mnc {
    NSError *error = nil;
    PXProfileArtifactMutation *mutation = [self acquireMutationForIdentityDirectory:nil error:&error];
    BOOL success = NO;
    @try {
        if (mutation) success = [self saveCarrierDetails:carrierName mcc:mcc mnc:mnc inMutation:mutation error:&error];
    } @finally { [mutation invalidate]; }
    PXLog(@"[NetworkManager] Carrier save %@: %@", success ? @"committed" : @"failed", error ?: @"");
    return success;
}

+ (BOOL)saveCarrierDetails:(NSString *)carrierName mcc:(NSString *)mcc mnc:(NSString *)mnc inMutation:(PXProfileArtifactMutation *)mutation error:(NSError **)error {
    NSDictionary *carrier = @{ @"carrierName": carrierName ?: @"", @"mcc": mcc ?: @"", @"mnc": mnc ?: @"", @"lastUpdated": NSDate.date };
    NSDate *networkTimestamp = NSDate.date;
    return [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return PXStageRuntimeCarrier(tx, mutation.identityDirectory, carrier, networkTimestamp, writeError);
    } error:error];
}

+ (NSDictionary *)generateAndSaveCarrierForIdentityDirectory:(NSString *)expected {
    NSError *error = nil;
    PXProfileArtifactMutation *mutation = [self acquireMutationForIdentityDirectory:expected error:&error];
    if (!mutation) { PXLog(@"[NetworkManager] Carrier refresh unavailable: %@", error); return nil; }
    @try {
        NSString *countryCode = [self getCurrentCountryCode] ?: @"us";
        NSDictionary *carrier = [self getRandomCarrierForCountry:countryCode];
        [self saveCarrierDetails:carrier[@"name"] mcc:carrier[@"mcc"] mnc:carrier[@"mnc"] inMutation:mutation error:&error];
        return carrier;
    } @finally { [mutation invalidate]; }
}

+ (NSDictionary *)getSavedCarrierDetails {
    return [self getSavedCarrierDetailsWithForcedRefresh:NO];
}

+ (NSDictionary *)getSavedCarrierDetailsWithForcedRefresh:(BOOL)forceRefresh {
    if (forceRefresh) return [self generateAndSaveCarrierForIdentityDirectory:nil];
    // Get path to current profile's identity directory
    NSString *identityDir = [[self profileIdentityPath] copy];
    if (!identityDir) {
        PXLog(@"[WeaponX] Error: Could not get profile identity path for carrier details");
        return nil;
    }
    
    // Try to read from carrier_details.plist first
    NSString *carrierPath = [identityDir stringByAppendingPathComponent:@"carrier_details.plist"];
    NSDictionary *carrierDict = [NSDictionary dictionaryWithContentsOfFile:carrierPath];
    
    if (carrierDict && carrierDict[@"carrierName"] && carrierDict[@"mcc"] && carrierDict[@"mnc"]) {
        return @{
            @"name": carrierDict[@"carrierName"],
            @"mcc": carrierDict[@"mcc"],
            @"mnc": carrierDict[@"mnc"]
        };
    }
    
    // If not found, try reading from network_settings.plist
    NSString *networkPath = [identityDir stringByAppendingPathComponent:@"network_settings.plist"];
    NSDictionary *networkDict = [NSDictionary dictionaryWithContentsOfFile:networkPath];
    
    if (networkDict && networkDict[@"carrierName"] && networkDict[@"mcc"] && networkDict[@"mnc"]) {
        return @{
            @"name": networkDict[@"carrierName"],
            @"mcc": networkDict[@"mcc"],
            @"mnc": networkDict[@"mnc"]
        };
    }
    
    // If not found, try the combined device_ids.plist
    NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
    NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
    
    if (deviceIds && deviceIds[@"CarrierName"] && deviceIds[@"CarrierMCC"] && deviceIds[@"CarrierMNC"]) {
        return @{
            @"name": deviceIds[@"CarrierName"],
            @"mcc": deviceIds[@"CarrierMCC"],
            @"mnc": deviceIds[@"CarrierMNC"]
        };
    }
    
    return [self generateAndSaveCarrierForIdentityDirectory:identityDir];
}

// Helper method to get current country code (can be extended in the future)
+ (NSString *)getCurrentCountryCode {
    // For now, we'll return nil which will default to "us" in the caller
    // In the future, this could be enhanced to detect the actual country
    return nil;
}

@end
