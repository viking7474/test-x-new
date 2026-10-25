#import "PXRuntimeArtifactPreparation.h"
#include <math.h>
#include <stdlib.h>
#include <stdint.h>

NSDictionary *PXPrepareRuntimeWiFiInfo(void) {

    // Generate random US-style WiFi network information
    NSMutableDictionary *newWifiInfo = [NSMutableDictionary dictionary];

    // US ISP providers
    NSArray *usProviders = @[
        // Major national ISPs
        @"Xfinity", @"Spectrum", @"ATT", @"Verizon", @"CenturyLink", @"Cox", @"Frontier",
        @"Optimum", @"Suddenlink", @"WOW", @"Mediacom", @"Windstream", @"Sparklight",
        // Regional ISPs
        @"RCN", @"Grande", @"Wave", @"Armstrong", @"WideOpenWest", @"MetroNet", @"Ziply",
        @"Sonic", @"Earthlink", @"HughesNet", @"TDS", @"Consolidated", @"Fairpoint",
        // Cable providers
        @"Comcast", @"TimeWarner", @"Charter", @"BrightHouse", @"Cablevision", @"GCI",
        // Fiber/specialized providers
        @"GoogleFiber", @"FiOS", @"AT&T-Fiber", @"CenturyLink-Fiber", @"Webpass",
        // Mobile hotspot providers
        @"TMobile", @"Sprint", @"USCellular", @"Cricket", @"MetroPCS", @"Boost"
    ];

    // US WiFi suffixes and modifiers
    NSArray *usSuffixes = @[
        // Empty/standard
        @"", @"WiFi", @"WLAN", @"Net", @"Network", @"Internet",
        // Band identifiers
        @"-5G", @"-5GHz", @"-2G", @"-2.4", @"-2.4GHz", @"-6G", @"-6GHz", @"_5G", @"_2G",
        // Location/purpose
        @"-Home", @"-Office", @"-Guest", @"-IoT", @"-ExtWifi", @"-Mesh", @"-Basement",
        @"-Upstairs", @"-Kitchen", @"-Backyard", @"-Patio", @"-Garage", @"-Private",
        @"-Family", @"-Apartment", @"-Condo", @"-Suite", @"-Lobby",
        // Security identifiers
        @"_Secure", @"-Secure", @"-Protected", @"-WPA2", @"-WPA3", @"_EXT", @"-EXT",
        // Dynamic additions
        @"-MESH", @"-AP", @"-Hub", @"-NODE1", @"-POD", @"-REPEATER", @"-EXTENDER"
    ];

    // Router brand names popular in the US
    NSArray *routerBrands = @[
        @"NETGEAR", @"Linksys", @"TP-Link", @"ASUS", @"ORBI", @"Eero", @"Google-WiFi",
        @"Nest-WiFi", @"Nighthawk", @"Apple", @"Amazon", @"ARRIS", @"Motorola", @"Ubiquiti",
        @"AmpliFi", @"D-Link", @"Belkin", @"Buffalo", @"Cisco", @"EnGenius", @"Tenda"
    ];

    // Common US last names
    NSArray *commonLastNames = @[
        @"Smith", @"Johnson", @"Williams", @"Jones", @"Brown", @"Miller", @"Davis",
        @"Wilson", @"Anderson", @"Thomas", @"Taylor", @"Moore", @"White", @"Harris",
        @"Martin", @"Thompson", @"Garcia", @"Martinez", @"Robinson", @"Clark", @"Rodriguez",
        @"Lewis", @"Lee", @"Walker", @"Hall", @"Allen", @"Young", @"King", @"Wright",
        @"Scott", @"Green", @"Baker", @"Adams", @"Nelson", @"Hill", @"Ramirez", @"Campbell",
        @"Mitchell", @"Roberts", @"Carter", @"Phillips", @"Evans", @"Turner", @"Torres"
    ];

    // Creative network names popular in the US
    NSArray *creativeNames = @[
        @"HideYoKids", @"HideYoWiFi", @"ItHurtsWhenIP", @"PrettyFlyForAWiFi",
        @"WiFiAintGonnaBreadItself", @"ThePromisedLAN", @"WhyFi", @"WiFiDoYouLoveMe",
        @"LANDownUnder", @"TheLANBeforeTime", @"WuTangLAN", @"ThisLANIsMyLAN",
        @"BillWiTheScienceFi", @"TellMyWiFiLoveHer", @"NachoWiFi", @"GetOffMyLAN",
        @"TheInternetBox", @"Series-of-Tubes", @"FBI-Surveillance", @"NSA-Van",
        @"Area51", @"DEA-Monitoring", @"CIA-Spy-Van", @"NoWiFiForYou",
        @"Password123", @"NotTheWiFiYoureLookingFor", @"VirusInfectedWiFi",
        @"PayMeToConnect", @"ICanHearYouHavingSex", @"WifiSoFastUCantSeeThis",
        @"YourNeighborHasABetterRouter", @"WinternetIsComing", @"TwoGirlsOneRouter",
        @"DropItLikeItsHotspot", @"99ProblemsButWiFiAintOne", @"ThePasswordIsPASSWORD",
        @"Mom-Click-Here-For-Internet", @"ShoutingInTernetConspiracyTheories",
        @"AllYourBandwidthAreBelongToUs", @"NewEnglandClamRouter", @"RouterIHardlyKnowHer"
    ];

    // Generate random SSID using one of three methods
    NSString *ssid;
    int networkStyle = arc4random_uniform(100);

    if (networkStyle < 45) {
        // ISP style (45% chance)
        NSString *provider = usProviders[arc4random_uniform((uint32_t)usProviders.count)];
        NSString *suffix = usSuffixes[arc4random_uniform((uint32_t)usSuffixes.count)];

        if ([suffix length] > 0) {
            ssid = [NSString stringWithFormat:@"%@%@", provider, suffix];
        } else {
            ssid = provider;
        }

        // Sometimes add numbers for uniqueness
        if (arc4random_uniform(100) < 40) {
            ssid = [ssid stringByAppendingFormat:@"-%d", arc4random_uniform(999) + 1];
        }
    }
    else if (networkStyle < 70) {
        // Router brand style (25% chance)
        NSString *brand = routerBrands[arc4random_uniform((uint32_t)routerBrands.count)];
        NSString *suffix = usSuffixes[arc4random_uniform((uint32_t)usSuffixes.count)];

        if ([suffix length] > 0) {
            ssid = [NSString stringWithFormat:@"%@%@", brand, suffix];
        } else {
            ssid = brand;
        }

        // More likely to add model numbers for router brands
        if (arc4random_uniform(100) < 70) {
            // Different formats for model numbers
            int format = arc4random_uniform(5);
            if (format == 0) {
                ssid = [ssid stringByAppendingFormat:@"_%d", arc4random_uniform(1000)];
            } else if (format == 1) {
                ssid = [ssid stringByAppendingFormat:@"-%c%d", 'A' + arc4random_uniform(26), arc4random_uniform(100)];
            } else if (format == 2) {
                ssid = [ssid stringByAppendingFormat:@"_%dGHZ", (arc4random_uniform(2) == 0) ? 2 : 5];
            } else if (format == 3) {
                ssid = [ssid stringByAppendingFormat:@"-AC%d", 1000 + arc4random_uniform(9000)];
            } else {
                ssid = [ssid stringByAppendingFormat:@"_%X%X%X", arc4random_uniform(16), arc4random_uniform(16), arc4random_uniform(16)];
            }
        }
    }
    else {
        // Personal style (30% chance)
        int personalType = arc4random_uniform(100);
        NSString *base;

        if (personalType < 50) {
            // Family/Last name (50% of personal)
            base = commonLastNames[arc4random_uniform((uint32_t)commonLastNames.count)];

            // Add common variations
            int variation = arc4random_uniform(7);
            if (variation == 0) {
                base = [base stringByAppendingString:@"-Home"];
            } else if (variation == 1) {
                base = [base stringByAppendingString:@"-WiFi"];
            } else if (variation == 2) {
                base = [base stringByAppendingString:@"-Net"];
            } else if (variation == 3) {
                base = [base stringByAppendingString:@"Family"];
            } else if (variation == 4) {
                base = [base stringByAppendingString:@"House"];
            } else if (variation == 5) {
                base = [NSString stringWithFormat:@"The%@s", base];
            }
            // Otherwise leave as just the name
        } else {
            // Creative name (50% of personal)
            base = creativeNames[arc4random_uniform((uint32_t)creativeNames.count)];
        }

        // Sometimes add numbers for uniqueness
        if (arc4random_uniform(100) < 40) {
            ssid = [base stringByAppendingFormat:@"%d", arc4random_uniform(999) + 1];
        } else {
            ssid = base;
        }
    }

    // Generate random but valid BSSID (MAC address)
    // Common US router manufacturers OUIs (first 3 bytes)
    NSArray *commonOUIs = @[
        // Cisco/Linksys (popular in US)
        @"00:18:F8", // Cisco-Linksys
        @"00:1D:7E", // Cisco-Linksys
        @"00:23:69", // Cisco-Linksys
        @"E4:95:6E", // Cisco
        @"58:6D:8F", // Cisco-Linksys
        @"C8:BE:19", // Cisco-Linksys

        // NETGEAR (very popular in US market)
        @"00:14:6C", // NETGEAR
        @"00:26:F2", // NETGEAR
        @"08:BD:43", // NETGEAR
        @"20:E5:2A", // NETGEAR
        @"28:C6:8E", // NETGEAR
        @"3C:37:86", // NETGEAR
        @"D8:6C:63", // NETGEAR

        // Arris/Motorola (common in US cable modems)
        @"00:1A:DE", // Arris
        @"00:26:36", // Arris
        @"E4:64:E9", // Arris
        @"00:01:E3", // Motorola
        @"00:24:37", // Motorola

        // Comcast/Xfinity (US-specific)
        @"00:11:AE", // Xfinity
        @"00:14:6C", // Xfinity
        @"E4:64:E9", // Xfinity
        @"F8:F1:B6", // Xfinity

        // Charter/Spectrum (US-specific)
        @"68:A4:0E", // Spectrum
        @"00:FC:8D", // Spectrum

        // Apple (popular in US homes)
        @"00:1C:B3", // Apple WiFi
        @"88:41:FC", // Apple AirPort
        @"AC:BC:32", // Apple

        // Google/Nest (US market)
        @"F4:F5:D8", // Google WiFi
        @"F8:8F:CA", // Google Nest

        // Amazon/Eero (US market)
        @"04:F0:21", // Eero
        @"F8:BB:BF", // Eero
        @"FC:65:DE", // Amazon

        // TP-Link (common in US budget market)
        @"0C:80:63", // TP-Link
        @"54:A7:03", // TP-Link
        @"F8:1A:67", // TP-Link

        // ASUS (popular in US gaming/high-end)
        @"00:0C:6E", // ASUS
        @"30:85:A9", // ASUS
        @"AC:9E:17", // ASUS

        // Ubiquiti (popular for prosumers in US)
        @"44:E9:DD", // Ubiquiti
        @"78:8A:20", // Ubiquiti
        @"FC:EC:DA", // Ubiquiti

        // Belkin (common US brand)
        @"08:86:3B", // Belkin
        @"14:91:82", // Belkin
        @"94:10:3E", // Belkin

        // D-Link (budget US market)
        @"00:26:5A", // D-Link
        @"C0:A0:BB", // D-Link

        // Cable modems/gateways used by US ISPs
        @"00:90:D0", // Thomson/RCA (Spectrum)
        @"7C:BF:B1", // ARRIS (Comcast)
        @"00:15:63", // CableMatrix (various US cable)
        @"00:22:10"  // Motorola Solutions (US cable)
    ];

    // Select appropriate OUI based on SSID when possible
    NSString *oui = nil;

    // Match SSID provider with appropriate manufacturer
    if ([ssid containsString:@"Apple"] || [ssid containsString:@"Airport"]) {
        int appleIdx = 26 + arc4random_uniform(3);
        oui = commonOUIs[appleIdx]; // Apple OUIs
    }
    else if ([ssid containsString:@"Google"] || [ssid containsString:@"Nest"]) {
        int googleIdx = 29 + arc4random_uniform(2);
        oui = commonOUIs[googleIdx]; // Google OUIs
    }
    else if ([ssid containsString:@"Linksys"] || [ssid containsString:@"Cisco"]) {
        int ciscoIdx = arc4random_uniform(6);
        oui = commonOUIs[ciscoIdx]; // Cisco OUIs (indices 0-5)
    }
    else if ([ssid containsString:@"NETGEAR"] || [ssid containsString:@"Nighthawk"]) {
        int netgearIdx = 6 + arc4random_uniform(7);
        oui = commonOUIs[netgearIdx]; // NETGEAR OUIs (indices 6-12)
    }
    else if ([ssid containsString:@"Motorola"] || [ssid containsString:@"ARRIS"]) {
        int arrisIdx = 13 + arc4random_uniform(5);
        oui = commonOUIs[arrisIdx]; // Arris OUIs (indices 13-17)
    }
    else if ([ssid containsString:@"Xfinity"] || [ssid containsString:@"Comcast"]) {
        int xfinityIdx = 18 + arc4random_uniform(4);
        oui = commonOUIs[xfinityIdx]; // Xfinity OUIs (indices 18-21)
    }
    else if ([ssid containsString:@"Spectrum"] || [ssid containsString:@"Charter"]) {
        int spectrumIdx = 22 + arc4random_uniform(2);
        oui = commonOUIs[spectrumIdx]; // Spectrum OUIs (indices 22-23)
    }
    else if ([ssid containsString:@"Eero"] || [ssid containsString:@"Amazon"]) {
        int eeroIdx = 31 + arc4random_uniform(3);
        oui = commonOUIs[eeroIdx]; // Eero/Amazon OUIs (indices 31-33)
    }
    else if ([ssid containsString:@"TP-Link"] || [ssid containsString:@"TPLink"]) {
        int tplinkIdx = 34 + arc4random_uniform(3);
        oui = commonOUIs[tplinkIdx]; // TP-Link OUIs (indices 34-36)
    }
    else if ([ssid containsString:@"ASUS"]) {
        int asusIdx = 37 + arc4random_uniform(3);
        oui = commonOUIs[asusIdx]; // ASUS OUIs (indices 37-39)
    }
    else if ([ssid containsString:@"Ubiquiti"] || [ssid containsString:@"UBNT"] || [ssid containsString:@"AmpliFi"]) {
        int ubiquitiIdx = 40 + arc4random_uniform(3);
        oui = commonOUIs[ubiquitiIdx]; // Ubiquiti OUIs (indices 40-42)
    }
    else if ([ssid containsString:@"Belkin"]) {
        int belkinIdx = 43 + arc4random_uniform(3);
        oui = commonOUIs[belkinIdx]; // Belkin OUIs (indices 43-45)
    }
    else if ([ssid containsString:@"DLink"] || [ssid containsString:@"D-Link"]) {
        int dlinkIdx = 46 + arc4random_uniform(2);
        oui = commonOUIs[dlinkIdx]; // D-Link OUIs (indices 46-47)
    }
    // ISP-specific cases
    else if ([ssid containsString:@"ATT"] || [ssid containsString:@"AT&T"]) {
        // Use Arris or Cisco (common AT&T suppliers)
        oui = commonOUIs[arc4random_uniform(2) == 0 ? 2 : 14];
    }
    else if ([ssid containsString:@"Verizon"] || [ssid containsString:@"FiOS"]) {
        // Use Actiontec or Motorola (common Verizon suppliers)
        oui = commonOUIs[16 + arc4random_uniform(2)];
    }
    else if ([ssid containsString:@"Cox"]) {
        // Use ARRIS or Cisco (common Cox suppliers)
        oui = commonOUIs[arc4random_uniform(2) == 0 ? 4 : 15];
    }
    else {
        // For all other cases, choose a random OUI
        oui = commonOUIs[arc4random_uniform((uint32_t)commonOUIs.count)];
    }

    // Generate the random part of the MAC address
    NSString *bssid = [NSString stringWithFormat:@"%@:%02X:%02X:%02X",
                       oui,
                       arc4random_uniform(256),
                       arc4random_uniform(256),
                       arc4random_uniform(256)];

    // Set network type (usually "Infrastructure" for home networks)
    NSString *networkType = @"Infrastructure";

    // Set WiFi standard (802.11ac or 802.11ax most common in US now)
    NSArray *standards = @[@"802.11ax", @"802.11ac", @"802.11n"];
    NSString *wifiStandard = standards[arc4random_uniform(3)]; // Equally likely among the three

    // Set auto-join status (usually YES for home networks)
    BOOL autoJoin = YES;

    // Set last connection time (typically within the last day)
    NSDate *lastConnectionTime = [NSDate dateWithTimeIntervalSinceNow:-(NSTimeInterval)arc4random_uniform(86400)];

    // Store values
    newWifiInfo[@"ssid"] = ssid;
    newWifiInfo[@"bssid"] = bssid;
    newWifiInfo[@"networkType"] = networkType;
    newWifiInfo[@"wifiStandard"] = wifiStandard;
    newWifiInfo[@"autoJoin"] = @(autoJoin);
    newWifiInfo[@"lastConnectionTime"] = lastConnectionTime;

    return [newWifiInfo copy];
}

NSString *PXPrepareRuntimeBatteryLevel(void) {
    // Algorithm for realistic battery level distribution:
    // - 60% chance of battery level between 30-80%
    // - 20% chance of battery level between 80-100%
    // - 15% chance of battery level between 15-30%
    // - 5% chance of battery level between 5-15%

    int randomValue = arc4random_uniform(100);
    float level;

    if (randomValue < 60) {
        // 30-80% range (most common)
        level = (30 + arc4random_uniform(51)) / 100.0f;
    } else if (randomValue < 80) {
        // 80-100% range (fully charged state)
        level = (80 + arc4random_uniform(21)) / 100.0f;
    } else if (randomValue < 95) {
        // 15-30% range (low battery state)
        level = (15 + arc4random_uniform(16)) / 100.0f;
    } else {
        // 5-15% range (battery danger zone)
        level = (5 + arc4random_uniform(11)) / 100.0f;
    }

    // Format with 2 decimal places
    NSString *levelStr = [NSString stringWithFormat:@"%.2f", level];

    return levelStr;
}

NSDictionary *PXPrepareRuntimeBatteryInfo(BOOL lowPowerMode) {
    NSString *level = PXPrepareRuntimeBatteryLevel();
    return @{ @"BatteryLevel": level, @"BatteryPercentage": @((int)(level.floatValue * 100)), @"LowPowerMode": @(lowPowerMode) };
}

NSDictionary *PXPrepareRuntimeStorage(NSString *capacity) {
    if (![capacity isKindOfClass:NSString.class]) return nil;
    capacity = [capacity copy];
    double parsedCapacity = [capacity doubleValue];
    if (!isfinite(parsedCapacity) || parsedCapacity <= 0 || parsedCapacity >= (double)UINT64_MAX / 1e9) return nil;
    NSMutableDictionary *storage = [NSMutableDictionary dictionary];

    double totalGB = parsedCapacity;
    double freePercent;

    // Calculate realistic free space based on capacity
    if (totalGB <= 64) {
        // 64GB devices typically have less free space (15-30%)
        freePercent = (arc4random_uniform(15) + 15) / 100.0;
    } else {
        // 128GB devices (25-40%)
        freePercent = (arc4random_uniform(15) + 25) / 100.0;
    }

    double freeGB = totalGB * freePercent;

    // Add some variability to the decimal points
    double decimalVariation = (arc4random_uniform(10) / 10.0);
    freeGB = freeGB + decimalVariation;

    // Round to one decimal place
    freeGB = round(freeGB * 10) / 10;
    if (!isfinite(freeGB) || freeGB > totalGB) return nil;

    storage[@"TotalStorage"] = capacity;
    storage[@"FreeStorage"] = [NSString stringWithFormat:@"%.1f", freeGB];
    storage[@"FilesystemType"] = @"0x1A"; // APFS for modern iOS

    return [storage copy];
}

NSDictionary *PXPrepareRuntimeUptime(NSDate *now, NSTimeInterval realUptime, BOOL hasRealUptime) {
    NSTimeInterval minUptime = 12 * 3600;
    NSTimeInterval maxUptime = 48 * 3600;
    NSTimeInterval uptimeRange = maxUptime - minUptime;
    NSTimeInterval randomPart = arc4random_uniform((uint32_t)uptimeRange);
    NSTimeInterval extraSeconds = arc4random_uniform(60 * 45);
    NSTimeInterval uptime = minUptime + randomPart + extraSeconds;
    if (hasRealUptime) {
        if (uptime > realUptime - 60) uptime = realUptime - 60;
        if (uptime < minUptime) uptime = minUptime;
    }
    NSDate *bootTime = [now dateByAddingTimeInterval:-uptime];
    NSDictionary *boot = @{ @"value": bootTime, @"lastUpdated": now, @"version": @1 };
    NSDictionary *elapsed = @{ @"value": [NSString stringWithFormat:@"%.0f", uptime], @"lastUpdated": now, @"version": @1 };
    return @{ @"boot": boot, @"uptime": elapsed, @"seconds": @(uptime) };
}
