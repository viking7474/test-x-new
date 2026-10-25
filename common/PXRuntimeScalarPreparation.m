#import "PXRuntimeScalarPreparation.h"
#import "PXIdentityValidator.h"
#import <Security/Security.h>
#import <dispatch/dispatch.h>
#include <time.h>
#include <stdlib.h>
#include <string.h>

static BOOL PXScalarUpperUUIDValid(NSString *idfa) {
    if (!idfa) return NO;

    // Check format using regex
    NSString *pattern = @"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                         options:0
                                                                           error:nil];
    NSUInteger matches = [regex numberOfMatchesInString:idfa
                                               options:0
                                                 range:NSMakeRange(0, idfa.length)];

    return matches == 1;
}

static BOOL PXScalarDeviceNameValid(NSString *deviceName) {
    if (!deviceName) return NO;

    // Basic validation - ensure it's not empty and not too long
    if (deviceName.length == 0 || deviceName.length > 50) {
        return NO;
    }

    // Ensure it doesn't contain any invalid characters
    NSCharacterSet *invalidChars = [NSCharacterSet characterSetWithCharactersInString:@"<>:\"/\\|?*"];
    if ([deviceName rangeOfCharacterFromSet:invalidChars].location != NSNotFound) {
        return NO;
    }

    return YES;
}

static BOOL PXScalarSerialFormatValid(NSString *serialNumber) {
    if (!serialNumber) return NO;


    // Check format using regex for various Apple device serial number formats
    // Pattern matches common prefixes followed by 7-8 alphanumeric characters
    NSString *pattern = @"^(C02|FVF|DLXJ|GG78|HC79)[0-9A-Z]{7,8}$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                         options:0
                                                                           error:nil];
    NSUInteger matches = [regex numberOfMatchesInString:serialNumber
                                               options:0
                                                 range:NSMakeRange(0, serialNumber.length)];

    return matches == 1;
}

static NSString *PXScalarIDFA(NSError **error) {

    // Generate a valid IDFA format (8-4-4-4-12)
    NSMutableString *idfa = [NSMutableString string];
    const char *chars = "0123456789ABCDEF";

    for (int i = 0; i < 32; i++) {
        if (i == 8 || i == 12 || i == 16 || i == 20) {
            [idfa appendString:@"-"];
        }
        uint32_t randomValue;
        if (SecRandomCopyBytes(kSecRandomDefault, sizeof(randomValue), (uint8_t *)&randomValue) == errSecSuccess) {
            [idfa appendFormat:@"%c", chars[randomValue % 16]];
        } else {
            if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                           code:1001
                                       userInfo:@{NSLocalizedDescriptionKey: @"Failed to generate secure random number"}];
            return nil;
        }
    }

    if (PXScalarUpperUUIDValid(idfa)) {
        return [idfa copy];
    }

    if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                   code:1002
                               userInfo:@{NSLocalizedDescriptionKey: @"Generated IDFA failed validation"}];
    return nil;
}

static NSString *PXScalarIDFV(NSError **error) {

    // Generate a valid IDFV format (8-4-4-4-12)
    NSMutableString *idfv = [NSMutableString string];
    const char *chars = "0123456789ABCDEF";

    for (int i = 0; i < 32; i++) {
        if (i == 8 || i == 12 || i == 16 || i == 20) {
            [idfv appendString:@"-"];
        }
        uint32_t randomValue;
        if (SecRandomCopyBytes(kSecRandomDefault, sizeof(randomValue), (uint8_t *)&randomValue) == errSecSuccess) {
            [idfv appendFormat:@"%c", chars[randomValue % 16]];
        } else {
            if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                           code:2001
                                       userInfo:@{NSLocalizedDescriptionKey: @"Failed to generate secure random number"}];
            return nil;
        }
    }

    if (PXScalarUpperUUIDValid(idfv)) {
        return [idfv copy];
    }

    if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                   code:2002
                               userInfo:@{NSLocalizedDescriptionKey: @"Generated IDFV failed validation"}];
    return nil;
}

static NSString *PXScalarDeviceName(NSError **error) {

    // List of iPhone models from 8 Plus to 15 Pro Max
    NSArray *iPhoneModels = @[
        @"iPhone 8 Plus",
        @"iPhone X",
        @"iPhone XR",
        @"iPhone XS",
        @"iPhone XS Max",
        @"iPhone 11",
        @"iPhone 11 Pro",
        @"iPhone 11 Pro Max",
        @"iPhone 12",
        @"iPhone 12 mini",
        @"iPhone 12 Pro",
        @"iPhone 12 Pro Max",
        @"iPhone 13",
        @"iPhone 13 mini",
        @"iPhone 13 Pro",
        @"iPhone 13 Pro Max",
        @"iPhone 14",
        @"iPhone 14 Plus",
        @"iPhone 14 Pro",
        @"iPhone 14 Pro Max",
        @"iPhone 15",
        @"iPhone 15 Plus",
        @"iPhone 15 Pro",
        @"iPhone 15 Pro Max"
    ];

    // Common first names in the USA
    NSArray *usaFirstNames = @[
        @"Michael", @"Christopher", @"Jessica", @"Matthew", @"Ashley", @"Jennifer",
        @"Joshua", @"Amanda", @"Daniel", @"David", @"James", @"Robert", @"John",
        @"Joseph", @"Andrew", @"Ryan", @"Brandon", @"Jason", @"Justin", @"Sarah",
        @"William", @"Jonathan", @"Stephanie", @"Brian", @"Nicole", @"Nicholas",
        @"Anthony", @"Heather", @"Eric", @"Elizabeth", @"Adam", @"Megan", @"Melissa",
        @"Kevin", @"Steven", @"Thomas", @"Timothy", @"Christina", @"Kyle", @"Rachel",
        @"Laura", @"Lauren", @"Amber", @"Brittany", @"Danielle", @"Richard", @"Kimberly",
        @"Jeffrey", @"Amy", @"Crystal", @"Michelle", @"Tiffany", @"Jeremy", @"Benjamin",
        @"Mark", @"Emily", @"Aaron", @"Charles", @"Rebecca", @"Jacob", @"Stephen",
        @"Patrick", @"Sean", @"Erin", @"Zachary", @"Jamie", @"Kelly", @"Samantha",
        @"Nathan", @"Sara", @"Dustin", @"Paul", @"Angela", @"Tyler", @"Scott",
        @"Katherine", @"Andrea", @"Gregory", @"Erica", @"Mary", @"Travis", @"Lisa",
        @"Kenneth", @"Bryan", @"Lindsey", @"Kristen", @"Jose", @"Alexander", @"Jesse",
        @"Katie", @"Lindsay", @"Shannon", @"Vanessa", @"Courtney", @"Christine",
        @"Alicia", @"Cody", @"Allison", @"Bradley", @"Samuel", @"Emma", @"Noah",
        @"Olivia", @"Liam", @"Ava", @"Ethan", @"Sophia", @"Isabella", @"Mason",
        @"Mia", @"Lucas", @"Charlotte", @"Aiden", @"Harper", @"Elijah", @"Amelia",
        @"Oliver", @"Abigail", @"Ella", @"Logan", @"Madison", @"Jackson", @"Lily",
        @"Avery", @"Carter", @"Chloe", @"Grayson", @"Evelyn", @"Leo", @"Sofia",
        @"Lincoln", @"Hannah", @"Henry", @"Aria", @"Gabriel", @"Grace", @"Owen",
        @"Victoria", @"Zoey", @"Isaac", @"Brooklyn", @"Levi", @"Zoe", @"Julian",
        @"Natalie", @"Caleb", @"Addison", @"Luke", @"Leah", @"Nathan", @"Aubrey",
        @"Jack", @"Aurora", @"Isaiah", @"Savannah", @"Eli", @"Audrey", @"Dylan"
    ];

    // Common last names in the USA
    NSArray *usaLastNames = @[
        @"Smith", @"Johnson", @"Williams", @"Jones", @"Brown", @"Davis", @"Miller",
        @"Wilson", @"Moore", @"Taylor", @"Anderson", @"Thomas", @"Jackson", @"White",
        @"Harris", @"Martin", @"Thompson", @"Garcia", @"Martinez", @"Robinson", @"Clark",
        @"Rodriguez", @"Lewis", @"Lee", @"Walker", @"Hall", @"Allen", @"Young", @"Hernandez",
        @"King", @"Wright", @"Lopez", @"Hill", @"Scott", @"Green", @"Adams", @"Baker",
        @"Gonzalez", @"Nelson", @"Carter", @"Mitchell", @"Perez", @"Roberts", @"Turner",
        @"Phillips", @"Campbell", @"Parker", @"Evans", @"Edwards", @"Collins", @"Stewart",
        @"Sanchez", @"Morris", @"Rogers", @"Reed", @"Cook", @"Morgan", @"Bell", @"Murphy",
        @"Bailey", @"Rivera", @"Cooper", @"Richardson", @"Cox", @"Howard", @"Ward", @"Torres",
        @"Peterson", @"Gray", @"Ramirez", @"James", @"Watson", @"Brooks", @"Kelly", @"Sanders",
        @"Price", @"Bennett", @"Wood", @"Barnes", @"Ross", @"Henderson", @"Coleman", @"Jenkins",
        @"Perry", @"Powell", @"Long", @"Patterson", @"Hughes", @"Flores", @"Washington", @"Butler",
        @"Simmons", @"Foster", @"Gonzales", @"Bryant", @"Alexander", @"Russell", @"Griffin",
        @"Diaz", @"Hayes"
    ];

    // Common US locations/states/cities for naming patterns
    NSArray *usaLocations = @[
        @"NYC", @"LA", @"Chicago", @"Houston", @"Phoenix", @"Philly", @"San Antonio",
        @"San Diego", @"Dallas", @"Austin", @"Seattle", @"Denver", @"Boston", @"Vegas",
        @"Miami", @"Oakland", @"Jersey", @"Portland", @"ATL", @"SF", @"NOLA", @"DC",
        @"Nashville", @"SLC", @"Detroit", @"Columbus", @"Indy", @"Charlotte", @"Memphis",
        @"AZ", @"CA", @"TX", @"FL", @"NY", @"PA", @"IL", @"OH", @"GA", @"NC", @"MI",
        @"NJ", @"VA", @"WA", @"MN", @"CO", @"AL", @"SC", @"LA", @"KY", @"OR", @"OK",
        @"CT", @"UT", @"IA", @"NV", @"AR", @"MS", @"KS", @"NE", @"WV", @"ID", @"HI",
        @"NH", @"ME", @"MT", @"DE", @"SD", @"ND", @"AK", @"VT", @"WY", @"Home", @"Work",
        @"Office"
    ];

    // Personalized descriptors
    NSArray *personalDescriptors = @[
        @"Personal", @"Pro", @"Work", @"Home", @"Main", @"Family", @"Mobile", @"Primary",
        @"New", @"Travel", @"Gaming", @"Backup", @"Private", @"", @"", @"", @"", @""
    ];

    // Generate a random device name
    NSMutableString *deviceName = [NSMutableString string];

    // Determine which naming pattern to use
    uint32_t patternSelector;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(patternSelector), (uint8_t *)&patternSelector) != errSecSuccess) {
        if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                       code:3001
                                   userInfo:@{NSLocalizedDescriptionKey: @"Failed to generate secure random number"}];
        return nil;
    }

    switch (patternSelector % 5) {
        case 0: {
            // Pattern: "[First Name]'s iPhone"
            uint32_t nameIndex;
            if (SecRandomCopyBytes(kSecRandomDefault, sizeof(nameIndex), (uint8_t *)&nameIndex) != errSecSuccess) {
                // Fall back to a simpler deterministic behavior on error
                nameIndex = (uint32_t)time(NULL);
            }
            NSString *firstName = usaFirstNames[nameIndex % usaFirstNames.count];
            [deviceName appendFormat:@"%@'s iPhone", firstName];
            break;
        }
        case 1: {
            // Pattern: "iPhone [First Name]" or "iPhone-[First Name]"
            uint32_t nameIndex;
            if (SecRandomCopyBytes(kSecRandomDefault, sizeof(nameIndex), (uint8_t *)&nameIndex) != errSecSuccess) {
                nameIndex = (uint32_t)time(NULL);
            }
            NSString *firstName = usaFirstNames[nameIndex % usaFirstNames.count];

            uint32_t dashOrSpace;
            if (SecRandomCopyBytes(kSecRandomDefault, sizeof(dashOrSpace), (uint8_t *)&dashOrSpace) != errSecSuccess) {
                dashOrSpace = (uint32_t)time(NULL);
            }

            if (dashOrSpace % 2 == 0) {
                [deviceName appendFormat:@"iPhone %@", firstName];
            } else {
                [deviceName appendFormat:@"iPhone-%@", firstName];
            }
            break;
        }
        case 2: {
            // Pattern: "[First Name] [Last Name]'s iPhone"
            uint32_t firstNameIndex, lastNameIndex;
            if (SecRandomCopyBytes(kSecRandomDefault, sizeof(firstNameIndex), (uint8_t *)&firstNameIndex) != errSecSuccess) {
                firstNameIndex = (uint32_t)time(NULL);
            }
            if (SecRandomCopyBytes(kSecRandomDefault, sizeof(lastNameIndex), (uint8_t *)&lastNameIndex) != errSecSuccess) {
                lastNameIndex = (uint32_t)(time(NULL) + 1);
            }

            NSString *firstName = usaFirstNames[firstNameIndex % usaFirstNames.count];
            NSString *lastName = usaLastNames[lastNameIndex % usaLastNames.count];

            [deviceName appendFormat:@"%@ %@'s iPhone", firstName, lastName];
            break;
        }
        case 3: {
            // Pattern: "iPhone [Location/State]"
            uint32_t locationIndex;
            if (SecRandomCopyBytes(kSecRandomDefault, sizeof(locationIndex), (uint8_t *)&locationIndex) != errSecSuccess) {
                locationIndex = (uint32_t)time(NULL);
            }
            NSString *location = usaLocations[locationIndex % usaLocations.count];

            [deviceName appendFormat:@"iPhone %@", location];
            break;
        }
        case 4: {
            // Pattern: "[Specific iPhone Model] [Descriptor]"
            uint32_t modelIndex, descriptorIndex;
            if (SecRandomCopyBytes(kSecRandomDefault, sizeof(modelIndex), (uint8_t *)&modelIndex) != errSecSuccess) {
                modelIndex = (uint32_t)time(NULL);
            }
            if (SecRandomCopyBytes(kSecRandomDefault, sizeof(descriptorIndex), (uint8_t *)&descriptorIndex) != errSecSuccess) {
                descriptorIndex = (uint32_t)(time(NULL) + 1);
            }

            NSString *model = iPhoneModels[modelIndex % iPhoneModels.count];
            NSString *descriptor = personalDescriptors[descriptorIndex % personalDescriptors.count];

            if ([descriptor length] > 0) {
                [deviceName appendFormat:@"%@ %@", model, descriptor];
            } else {
                // If we got an empty descriptor, just use the model
                [deviceName appendString:model];
            }
            break;
        }
    }

    if (PXScalarDeviceNameValid(deviceName)) {
        return [deviceName copy];
    }

    if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                   code:3002
                               userInfo:@{NSLocalizedDescriptionKey: @"Generated device name failed validation"}];
    return nil;
}

static NSString *PXScalarLowerUUID(NSString *errorDomain, NSError **error) {
    // Generate a valid UUID format (8-4-4-4-12)
    NSMutableString *uuid = [NSMutableString string];

    // Characters for hex values
    const char chars[] = "0123456789abcdef";

    // First section (8 chars)
    for (int i = 0; i < 8; i++) {
        int randomValue = arc4random() % 16;
        [uuid appendFormat:@"%c", chars[randomValue]];
    }

    [uuid appendString:@"-"];

    // Second section (4 chars)
    for (int i = 0; i < 4; i++) {
        int randomValue = arc4random() % 16;
        [uuid appendFormat:@"%c", chars[randomValue]];
    }

    [uuid appendString:@"-"];

    // Third section (4 chars) - version 4 UUID
    [uuid appendString:@"4"];
    for (int i = 0; i < 3; i++) {
        int randomValue = arc4random() % 16;
        [uuid appendFormat:@"%c", chars[randomValue]];
    }

    [uuid appendString:@"-"];

    // Fourth section (4 chars) - variant
    int randomValue = arc4random() % 4 + 8; // 8, 9, A, or B
    [uuid appendFormat:@"%c", chars[randomValue]];
    for (int i = 0; i < 3; i++) {
        randomValue = arc4random() % 16;
        [uuid appendFormat:@"%c", chars[randomValue]];
    }

    [uuid appendString:@"-"];

    // Fifth section (12 chars)
    for (int i = 0; i < 12; i++) {
        randomValue = arc4random() % 16;
        [uuid appendFormat:@"%c", chars[randomValue]];
    }

    // Validate and return
    if (PXValidateIdentityValue(uuid, PXIdentityValueKindUUID, NO)) {
        return [uuid copy];
    }

    // If validation failed, return error
    if (error) *error = [NSError errorWithDomain:errorDomain
                                     code:1001
                                 userInfo:@{NSLocalizedDescriptionKey: @"Generated Boot UUID failed validation"}];
    return nil;
}

NSString *PXPrepareRuntimeSerial(NSString *prefix, NSError **error) {
    if (error) *error = nil;
    if (![prefix isKindOfClass:NSString.class] || ![@[@"C02", @"FVF", @"DLXJ", @"GG78", @"HC79"] containsObject:prefix]) {
        if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:4002 userInfo:@{NSLocalizedDescriptionKey: @"Invalid serial generation prefix"}];
        return nil;
    }
    prefix = [prefix copy];
    // Create a mutable string with the prefix
    NSMutableString *serialNumber = [NSMutableString stringWithString:prefix];

    // Generate random alphanumeric characters for the rest
    // Skip I, O, 1, 0 to avoid confusion (common in Apple serial numbers)
    const char *chars = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
    NSInteger remainingLength = (prefix.length == 3) ? 8 : 7;

    for (int i = 0; i < remainingLength; i++) {
        uint32_t randomValue;
        if (SecRandomCopyBytes(kSecRandomDefault, sizeof(randomValue), (uint8_t *)&randomValue) == errSecSuccess) {
            [serialNumber appendFormat:@"%c", chars[randomValue % strlen(chars)]];
        } else {
            if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                           code:4001
                                       userInfo:@{NSLocalizedDescriptionKey: @"Failed to generate secure random number for serial"}];
            return nil;
        }
    }

    if (PXScalarSerialFormatValid(serialNumber)) return [serialNumber copy];
    if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:4002 userInfo:@{NSLocalizedDescriptionKey: @"Generated serial number failed validation"}];
    return nil;
}

NSString *PXPrepareRuntimeScalar(NSString *type, NSError **error) {
    if (error) *error = nil;
    if (![type isKindOfClass:NSString.class]) {
        if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios.scalar-prepare" code:1
            userInfo:@{NSLocalizedDescriptionKey: @"Invalid scalar type"}];
        return nil;
    }
    type = [type copy];
    if ([type isEqualToString:@"IDFA"]) return PXScalarIDFA(error);
    if ([type isEqualToString:@"IDFV"]) return PXScalarIDFV(error);
    if ([type isEqualToString:@"DeviceName"]) return PXScalarDeviceName(error);
    if ([type isEqualToString:@"UDID"]) {
        NSMutableString *value = [NSMutableString stringWithCapacity:40];
        for (NSUInteger i = 0; i < 40; i++) [value appendFormat:@"%x", arc4random_uniform(16)];
        return [value copy];
    }
    static NSDictionary *domains;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ domains = @{
        @"SystemBootUUID": @"com.weaponx.SystemUUIDManager",
        @"DyldCacheUUID": @"com.weaponx.DyldCacheUUIDManager",
        @"PasteboardUUID": @"com.weaponx.PasteboardUUIDManager",
        @"KeychainUUID": @"com.weaponx.KeychainUUIDManager",
        @"UserDefaultsUUID": @"com.weaponx.UserDefaultsUUIDManager",
        @"AppGroupUUID": @"com.weaponx.AppGroupUUIDManager",
        @"CoreDataUUID": @"com.weaponx.CoreDataUUIDManager",
        @"AppInstallUUID": @"com.weaponx.AppInstallUUIDManager",
        @"AppContainerUUID": @"com.weaponx.AppContainerUUIDManager"
    }; });
    NSString *domain = [type isKindOfClass:NSString.class] ? domains[type] : nil;
    if (domain) return PXScalarLowerUUID(domain, error);
    if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios.scalar-prepare" code:1
        userInfo:@{NSLocalizedDescriptionKey: @"Unsupported scalar type; SerialNumber requires its policy adapter"}];
    return nil;
}
