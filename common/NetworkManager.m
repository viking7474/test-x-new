#import "NetworkManager.h"
#import "CarrierDB.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#import "TLinkIOSLogging.h"
#import "PXPaths.h"

@interface NetworkManager ()
+ (BOOL)saveLocalIPAddress:(NSString *)ipAddress ipv6Address:(NSString *)ipv6Address;
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

    NSString *networkPath = [identityDir stringByAppendingPathComponent:@"network_settings.plist"];
    NSMutableDictionary *networkDict = [NSMutableDictionary dictionaryWithContentsOfFile:networkPath] ?: [NSMutableDictionary dictionary];
    if (ipAddress != nil) {
        networkDict[@"localIPAddress"] = ipAddress;
    }
    if (ipv6Address != nil) {
        networkDict[@"localIPv6Address"] = ipv6Address;
    }
    networkDict[@"lastUpdated"] = [NSDate date];

    BOOL success = [networkDict writeToFile:networkPath atomically:YES];
    if (success) {
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: [NSMutableDictionary dictionary];
        if (ipAddress != nil) {
            deviceIds[@"LocalIPAddress"] = ipAddress;
        }
        if (ipv6Address != nil) {
            deviceIds[@"LocalIPv6Address"] = ipv6Address;
        }
        success = [deviceIds writeToFile:deviceIdsPath atomically:YES];
    }

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

    // A single-address save must not regenerate an unrelated IPv6 value. Preserve the
    // profile's existing spoofed IPv6 and only generate it once when no paired value exists.
    NSString *ipv6Address = nil;
    NSString *identityDir = [self profileIdentityPath];
    if (identityDir.length) {
        NSString *networkPath = [identityDir stringByAppendingPathComponent:@"network_settings.plist"];
        NSDictionary *networkDict = [NSDictionary dictionaryWithContentsOfFile:networkPath];
        ipv6Address = [networkDict[@"localIPv6Address"] isKindOfClass:[NSString class]]
            ? networkDict[@"localIPv6Address"] : nil;
        if (!ipv6Address.length) {
            NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
            NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
            ipv6Address = [deviceIds[@"LocalIPv6Address"] isKindOfClass:[NSString class]]
                ? deviceIds[@"LocalIPv6Address"] : nil;
        }
    }
    if (!ipv6Address.length) {
        ipv6Address = [self generateSpoofedLocalIPv6AddressFromCurrent];
    }

    return [self saveLocalIPAddress:ipAddress ipv6Address:ipv6Address];
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
            [self saveLocalIPAddress:localIP ipv6Address:localIPv6];
            PXLog(@"[WeaponX] Forced refresh of local IP address pair completed");
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
            [self saveLocalIPAddress:localIP];
            PXLog(@"[WeaponX] No saved Local IP found, using current: %@", localIP);
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
            [self saveLocalIPAddress:currentIPv4 ipv6Address:ipv6];
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
    
    // Create carrier details dictionary
    NSDictionary *carrierDict = @{
        @"carrierName": carrierName ?: @"",
        @"mcc": mcc ?: @"",
        @"mnc": mnc ?: @"",
        @"lastUpdated": [NSDate date]
    };
    
    // Save to carrier_details.plist
    NSString *carrierPath = [identityDir stringByAppendingPathComponent:@"carrier_details.plist"];
    BOOL success = [carrierDict writeToFile:carrierPath atomically:YES];
    
    // Also update the network_settings.plist to keep all network data together
    if (success) {
        NSString *networkPath = [identityDir stringByAppendingPathComponent:@"network_settings.plist"];
        NSMutableDictionary *networkDict = [NSMutableDictionary dictionaryWithContentsOfFile:networkPath] ?: [NSMutableDictionary dictionary];
        
        networkDict[@"carrierName"] = carrierName ?: @"";
        networkDict[@"mcc"] = mcc ?: @"";
        networkDict[@"mnc"] = mnc ?: @"";
        [networkDict setObject:[NSDate date] forKey:@"lastUpdated"];
        
        success = [networkDict writeToFile:networkPath atomically:YES];
    }
    
    // Also update the combined device_ids.plist
    if (success) {
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: [NSMutableDictionary dictionary];
        
        deviceIds[@"CarrierName"] = carrierName ?: @"";
        deviceIds[@"CarrierMCC"] = mcc ?: @"";
        deviceIds[@"CarrierMNC"] = mnc ?: @"";
        
        success = [deviceIds writeToFile:deviceIdsPath atomically:YES];
    }
    
    PXLog(@"[WeaponX] %@ Carrier details saved to profile: %@ (%@-%@)", 
           success ? @"✅" : @"❌", carrierName ?: @"Unknown", mcc ?: @"", mnc ?: @"");
    
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
        [self saveCarrierDetails:carrierInfo[@"name"] mcc:carrierInfo[@"mcc"] mnc:carrierInfo[@"mnc"]];
        
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
    [self saveCarrierDetails:carrierInfo[@"name"] mcc:carrierInfo[@"mcc"] mnc:carrierInfo[@"mnc"]];
    
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
