#import "PXP1AFilters.h"
#import <string.h>

#pragma mark - DeviceModel

NSString *PXDeviceModelUIDeviceFamily(NSString *spoofedModel, NSString *original) {
    if (!spoofedModel.length) {
        return original;
    }

    if ([spoofedModel hasPrefix:@"iPhone"]) {
        return @"iPhone";
    }
    if ([spoofedModel hasPrefix:@"iPad"]) {
        return @"iPad";
    }
    if ([spoofedModel hasPrefix:@"iPod"]) {
        return @"iPod touch";
    }

    // Unknown prefix → keep original UIDevice value
    return original;
}

#pragma mark - UserDefaults

BOOL PXUserDefaultsLooksLikeUUIDString(NSString *str) {
    if (!str || str.length < 32) return NO;
    // Standard UUID format with dashes
    if (str.length == 36) {
        return [str rangeOfString:@"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
                          options:NSRegularExpressionSearch].location != NSNotFound;
    }
    // UUID without dashes (32 hex chars)
    if (str.length == 32) {
        return [str rangeOfString:@"^[0-9a-fA-F]{32}$"
                          options:NSRegularExpressionSearch].location != NSNotFound;
    }
    return NO;
}

BOOL PXUserDefaultsIsUUIDKey(NSString *key) {
    if (!key) return NO;

    NSString *lowercaseKey = [key lowercaseString];

    // Strict UUID-related key patterns only
    NSArray *uuidPatterns = @[
        @"uuid", @"udid",
        @"deviceuuid", @"device_uuid", @"device-uuid",
        @"uniqueid", @"unique-id", @"unique_id",
        @"vendorid", @"vendor-id", @"vendor_id",
        @"idfa", @"idfv", @"adid", @"advertisingid", @"advertising_id",
        @"installationid", @"installation_id"
    ];

    // Check for exact matches only
    for (NSString *pattern in uuidPatterns) {
        if ([lowercaseKey isEqualToString:pattern]) {
            return YES;
        }
    }

    // Check for common suffixes with separators
    NSArray *strictSuffixes = @[@"uuid", @"udid", @"idfv", @"idfa"];
    for (NSString *suffix in strictSuffixes) {
        if ([lowercaseKey hasSuffix:[@"." stringByAppendingString:suffix]] ||
            [lowercaseKey hasSuffix:[@"-" stringByAppendingString:suffix]] ||
            [lowercaseKey hasSuffix:[@"_" stringByAppendingString:suffix]]) {
            return YES;
        }
    }

    return NO;
}

#pragma mark - Pasteboard

NSString *PXPasteboardDeterministicName(NSString *originalName, NSString *uuidString) {
    if (!originalName.length || !uuidString.length) {
        return originalName;
    }

    NSString *shortUUID = [uuidString componentsSeparatedByString:@"-"].firstObject;
    if (!shortUUID.length) {
        return originalName;
    }

    NSArray *components = [originalName componentsSeparatedByString:@"."];
    if (components.count > 0) {
        NSMutableArray *newComponents = [NSMutableArray arrayWithArray:components];
        newComponents[newComponents.count - 1] = shortUUID;
        return [newComponents componentsJoinedByString:@"."];
    }

    return [NSString stringWithFormat:@"%@.%@", originalName, shortUUID];
}

BOOL PXPasteboardTypeEncodingCompatible(const char *existing, const char *expected) {
    if (!existing || !expected) return NO;
    if (strcmp(existing, expected) == 0) return YES;
    // Fall back to requiring first character (return type) match.
    return existing[0] == expected[0];
}
