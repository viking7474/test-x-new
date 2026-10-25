#import "NetworkManager.h"
#import "CarrierDB.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#import "TLinkIOSLogging.h"
#import "PXPaths.h"
#import "PXRuntimeArtifactWriter.h"

@interface NetworkManager ()
+ (BOOL)saveLocalIPAddress:(NSString *)ipAddress ipv6Address:(NSString *)ipv6Address;
+ (BOOL)saveAddresses:(NSString *)ipv4 ipv6:(NSString *)ipv6 inIdentityDirectory:(NSString *)identityDir;
+ (BOOL)saveSingleAddress:(NSString *)ipv4 inIdentityDirectory:(NSString *)identityDir;
+ (BOOL)saveCarrier:(NSDictionary *)carrier inIdentityDirectory:(NSString *)identityDir;
+ (BOOL)saveCarrierDetails:(NSString *)name mcc:(NSString *)mcc mnc:(NSString *)mnc inIdentityDirectory:(NSString *)identityDir;
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
    NSString *identityDir = [self profileIdentityPath];
    if (!identityDir) {
        PXLog(@"[WeaponX] Error: Could not get profile identity path for NetworkManager");
        return NO;
    }

    return [self saveAddresses:ipAddress ipv6:ipv6Address inIdentityDirectory:identityDir];
}

+ (BOOL)saveAddresses:(NSString *)ipAddress ipv6:(NSString *)ipv6Address inIdentityDirectory:(NSString *)identityDir {
    NSDate *now = [NSDate date];
    NSError *error = nil;
    BOOL success = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return PXStageRuntimeAddresses(tx, identityDir, ipAddress, ipv6Address, NO, now, writeError);
    }, &error);
    PXLog(@"[WeaponX] %@ Local IP Address (IPv4/IPv6) saved to profile: %@ / %@",
          success ? @"✅" : @"❌",
          ipAddress ?: @"<unchanged>",
          ipv6Address ?: @"<unchanged>");
    return success;
}

+ (BOOL)saveLocalIPAddress:(NSString *)ipAddress {
    if (!ipAddress.length) {
        return NO;
    }

    NSString *identityDir = [self profileIdentityPath];
    return identityDir.length ? [self saveSingleAddress:ipAddress inIdentityDirectory:identityDir] : NO;
}

+ (BOOL)saveSingleAddress:(NSString *)ipAddress inIdentityDirectory:(NSString *)identityDir {
    // Recover before reading a possibly interrupted pair. Existing IPv6 commits
    // in one pass; interface enumeration/generation only happens outside the gate.
    __block BOOL needsIPv6 = NO;
    NSDate *now = [NSDate date];
    NSError *error = nil;
    BOOL success = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return PXStageRuntimeIPv4WithExistingPair(tx, identityDir, ipAddress, now, &needsIPv6, writeError);
    }, &error);
    if (success && needsIPv6) {
        NSString *candidateIPv6 = [self generateSpoofedLocalIPv6AddressFromCurrent];
        NSDate *preparedAt = [NSDate date];
        success = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
            // Another writer may have filled IPv6 during preparation. Preserve it.
            return PXStageRuntimeAddresses(tx, identityDir, ipAddress, candidateIPv6, YES, preparedAt, writeError);
        }, &error);
    }
    PXLog(@"[NetworkManager] %@ IPv4 update at %@: %@", success ? @"Committed" : @"Failed", identityDir, error ?: @"");
    return success;
}

+ (NSString *)getSavedLocalIPAddress {
    return [self getSavedLocalIPAddressWithForcedRefresh:NO];
}

+ (NSString *)getSavedLocalIPAddressWithForcedRefresh:(BOOL)forceRefresh {
    // Get path to current profile's identity directory
    NSString *identityDir = [self profileIdentityPath];
    if (!identityDir) {
        PXLog(@"[WeaponX] Error: Could not get profile identity path for NetworkManager");
        return nil;
    }
    
    // Forced refresh creates the complete spoofed pair once, then persists that exact pair.
    if (forceRefresh) {
        NSString *localIP = [self generateSpoofedLocalIPAddressFromCurrent];
        NSString *localIPv6 = [self generateSpoofedLocalIPv6AddressFromCurrent];
        if (localIP.length) {
            BOOL saved = [self saveAddresses:localIP ipv6:localIPv6 inIdentityDirectory:identityDir];
            PXLog(@"[WeaponX] Forced refresh of local IP address pair %@", saved ? @"committed" : @"failed to persist");
        } else {
            PXLog(@"[WeaponX] Forced refresh skipped: no current local IPv4 address is available");
        }
        return localIP;
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
    
    // If still not found, use the real current IPv4 when available.
    if (!localIP) {
        localIP = [self getCurrentLocalIPAddress];
        if (localIP.length) {
            BOOL saved = [self saveSingleAddress:localIP inIdentityDirectory:identityDir];
            PXLog(@"[WeaponX] No saved Local IP found, using current: %@ (persisted=%@)", localIP, saved ? @"YES" : @"NO");
        } else {
            PXLog(@"[WeaponX] No saved Local IP found and no current local IPv4 address is available");
        }
    }
    
    return localIP;
}

+ (NSString *)getSavedLocalIPv6Address {
    NSString *identityDir = [self profileIdentityPath];
    if (!identityDir) return nil;
    NSString *networkPath = [identityDir stringByAppendingPathComponent:@"network_settings.plist"];
    NSDictionary *networkDict = [NSDictionary dictionaryWithContentsOfFile:networkPath];
    NSString *ipv6 = networkDict[@"localIPv6Address"];
    if (!ipv6) {
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
        ipv6 = deviceIds[@"LocalIPv6Address"];
    }
    if (!ipv6) {
        ipv6 = [self generateSpoofedLocalIPv6AddressFromCurrent];
        if (ipv6.length) {
            NSString *currentIPv4 = [self getCurrentLocalIPAddress];
            [self saveAddresses:currentIPv4 ipv6:ipv6 inIdentityDirectory:identityDir];
        }
    }
    return ipv6;
}

#pragma mark - Profile-based Carrier Storage

+ (BOOL)saveCarrierDetails:(NSString *)carrierName mcc:(NSString *)mcc mnc:(NSString *)mnc {
    // Get path to current profile's identity directory
    NSString *identityDir = [self profileIdentityPath];
    if (!identityDir) {
        PXLog(@"[WeaponX] Error: Could not get profile identity path for carrier details");
        return NO;
    }
    return [self saveCarrierDetails:carrierName mcc:mcc mnc:mnc inIdentityDirectory:identityDir];
}

+ (BOOL)saveCarrierDetails:(NSString *)carrierName mcc:(NSString *)mcc mnc:(NSString *)mnc inIdentityDirectory:(NSString *)identityDir {
    // Create carrier details dictionary
    NSDictionary *carrierDict = @{
        @"carrierName": carrierName ?: @"",
        @"mcc": mcc ?: @"",
        @"mnc": mnc ?: @"",
        @"lastUpdated": [NSDate date]
    };
    
    return [self saveCarrier:carrierDict inIdentityDirectory:identityDir];
}

+ (BOOL)saveCarrier:(NSDictionary *)carrierDict inIdentityDirectory:(NSString *)identityDir {
    NSDate *networkTimestamp = [NSDate date];
    NSError *error = nil;
    BOOL success = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return PXStageRuntimeCarrier(tx, identityDir, carrierDict, networkTimestamp, writeError);
    }, &error);
    PXLog(@"[WeaponX] %@ Carrier details saved to profile: %@ (%@-%@)", 
           success ? @"✅" : @"❌", carrierDict[@"carrierName"] ?: @"Unknown", carrierDict[@"mcc"] ?: @"", carrierDict[@"mnc"] ?: @"");
    
    return success;
}

+ (NSDictionary *)getSavedCarrierDetails {
    return [self getSavedCarrierDetailsWithForcedRefresh:NO];
}

+ (NSDictionary *)getSavedCarrierDetailsWithForcedRefresh:(BOOL)forceRefresh {
    // Get path to current profile's identity directory
    NSString *identityDir = [self profileIdentityPath];
    if (!identityDir) {
        PXLog(@"[WeaponX] Error: Could not get profile identity path for carrier details");
        return nil;
    }
    
    // If forced refresh is requested, always generate new carrier details
    if (forceRefresh) {
        NSString *countryCode = [self getCurrentCountryCode] ?: @"us";
        NSDictionary *carrierInfo = [self getRandomCarrierForCountry:countryCode];
        
        // Save the generated carrier info
        [self saveCarrierDetails:carrierInfo[@"name"] mcc:carrierInfo[@"mcc"] mnc:carrierInfo[@"mnc"] inIdentityDirectory:identityDir];
        
        PXLog(@"[WeaponX] Forced refresh of carrier details: %@ (%@-%@)", 
              carrierInfo[@"name"], carrierInfo[@"mcc"], carrierInfo[@"mnc"]);
        
        return carrierInfo;
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
    
    // If still not found, generate default values based on country code (US as fallback)
    NSString *countryCode = [self getCurrentCountryCode] ?: @"us";
    NSDictionary *carrierInfo = [self getRandomCarrierForCountry:countryCode];
    
    // Save the generated carrier info for future use
    [self saveCarrierDetails:carrierInfo[@"name"] mcc:carrierInfo[@"mcc"] mnc:carrierInfo[@"mnc"] inIdentityDirectory:identityDir];
    
    PXLog(@"[WeaponX] No saved carrier details found, generated: %@ (%@-%@)", 
          carrierInfo[@"name"], carrierInfo[@"mcc"], carrierInfo[@"mnc"]);
    
    return carrierInfo;
}

// Helper method to get current country code (can be extended in the future)
+ (NSString *)getCurrentCountryCode {
    // For now, we'll return nil which will default to "us" in the caller
    // In the future, this could be enhanced to detect the actual country
    return nil;
}

@end
