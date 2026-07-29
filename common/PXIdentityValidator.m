#import "PXIdentityValidator.h"
#import <CoreFoundation/CoreFoundation.h>

NSString *const PXIdentityValidationErrorDomain = @"com.hydra.projectx.identity-validator";

@interface PXIdentityValidationResult ()
- (instancetype)initWithDeviceIDs:(NSDictionary *)deviceIDs
                           issues:(NSDictionary<NSString *, NSString *> *)issues
                       inputValid:(BOOL)inputValid;
@end

@implementation PXIdentityValidationResult
@synthesize deviceIDs = _deviceIDs;
@synthesize issues = _issues;
@synthesize inputValid = _inputValid;

- (instancetype)initWithDeviceIDs:(NSDictionary *)deviceIDs
                           issues:(NSDictionary<NSString *, NSString *> *)issues
                       inputValid:(BOOL)inputValid {
    self = [super init];
    if (self) {
        _deviceIDs = [deviceIDs copy] ?: @{};
        _issues = [issues copy] ?: @{};
        _inputValid = inputValid;
    }
    return self;
}
@end

static NSString *PXTrimmedIdentityString(id value) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *trimmed = [(NSString *)value stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length ||
        [trimmed caseInsensitiveCompare:@"Unknown"] == NSOrderedSame ||
        [trimmed caseInsensitiveCompare:@"(null)"] == NSOrderedSame) return nil;
    for (NSUInteger index = 0; index < trimmed.length; index++) {
        if ([trimmed characterAtIndex:index] == 0) return nil;
    }
    return trimmed;
}

static BOOL PXEntireStringMatches(NSString *value, NSString *pattern, NSRegularExpressionOptions options) {
    if (!value.length) return NO;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:options error:nil];
    if (!regex) return NO;
    NSTextCheckingResult *match = [regex firstMatchInString:value options:0 range:NSMakeRange(0, value.length)];
    return match && NSEqualRanges(match.range, NSMakeRange(0, value.length));
}

static BOOL PXIsAllZeroHex(NSString *value) {
    NSString *compact = [[[value stringByReplacingOccurrencesOfString:@"-" withString:@""]
        stringByReplacingOccurrencesOfString:@":" withString:@""] lowercaseString];
    if (!compact.length) return YES;
    return [compact rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0"] invertedSet]].location == NSNotFound;
}

static BOOL PXIMEILuhnValid(NSString *imei) {
    if (!PXEntireStringMatches(imei, @"[0-9]{15}", 0)) return NO;
    NSInteger sum = 0;
    for (NSUInteger i = 0; i < 14; i++) {
        NSInteger digit = [imei characterAtIndex:i] - '0';
        if ((i & 1u) != 0) { digit *= 2; if (digit > 9) digit -= 9; }
        sum += digit;
    }
    NSInteger check = (10 - (sum % 10)) % 10;
    return check == ([imei characterAtIndex:14] - '0');
}

static NSInteger PXHexValue(unichar c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    return -1;
}

static BOOL PXMEIDLuhnValid(NSString *meid) {
    if (!PXEntireStringMatches(meid, @"[0-9A-Fa-f]{15}", 0)) return NO;
    NSInteger sum = 0;
    for (NSUInteger i = 0; i < 14; i++) {
        NSInteger digit = PXHexValue([meid characterAtIndex:i]);
        if ((i & 1u) != 0) digit *= 2;
        sum += (digit / 16) + (digit % 16);
    }
    NSInteger expected = (16 - (sum % 16)) % 16;
    return expected == PXHexValue([meid characterAtIndex:14]);
}

NSString *PXCanonicalIdentityValue(id value, PXIdentityValueKind kind, BOOL allowZeroUUID) {
    if (kind == PXIdentityValueKindUnsignedDecimal && [value isKindOfClass:[NSNumber class]] &&
        CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID()) {
        double number = [value doubleValue];
        unsigned long long integer = [value unsignedLongLongValue];
        if (number >= 0.0 && number == (double)integer) return [value stringValue];
        return nil;
    }
    NSString *string = PXTrimmedIdentityString(value);
    if (!string) return nil;
    switch (kind) {
        case PXIdentityValueKindUUID: {
            NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:string];
            if (!uuid) return nil;
            NSString *canonical = [[uuid UUIDString] uppercaseString];
            return (!allowZeroUUID && PXIsAllZeroHex(canonical)) ? nil : canonical;
        }
        case PXIdentityValueKindUDID: {
            NSString *canonical = [string lowercaseString];
            return PXEntireStringMatches(canonical, @"[0-9a-f]{40}", 0) && !PXIsAllZeroHex(canonical) ? canonical : nil;
        }
        case PXIdentityValueKindIMEI:
            return PXIMEILuhnValid(string) && !PXIsAllZeroHex(string) ? string : nil;
        case PXIdentityValueKindMEID: {
            NSString *canonical = [string uppercaseString];
            return PXMEIDLuhnValid(canonical) && !PXIsAllZeroHex(canonical) ? canonical : nil;
        }
        case PXIdentityValueKindSerialNumber: {
            NSString *canonical = [string uppercaseString];
            return PXEntireStringMatches(canonical, @"[0-9A-Z]{8,14}", 0) && !PXIsAllZeroHex(canonical) ? canonical : nil;
        }
        case PXIdentityValueKindDeviceModel:
            return PXEntireStringMatches(string, @"(?:iPhone|iPad|iPod)[0-9]{1,2},[0-9]{1,2}", 0) ? string : nil;
        case PXIdentityValueKindMACAddress: {
            NSString *compact = [[string stringByReplacingOccurrencesOfString:@":" withString:@""]
                stringByReplacingOccurrencesOfString:@"-" withString:@""];
            if (!PXEntireStringMatches(compact, @"[0-9A-Fa-f]{12}", 0) || PXIsAllZeroHex(compact)) return nil;
            compact = [compact uppercaseString];
            NSMutableArray *parts = [NSMutableArray arrayWithCapacity:6];
            for (NSUInteger i = 0; i < 12; i += 2) [parts addObject:[compact substringWithRange:NSMakeRange(i, 2)]];
            return [parts componentsJoinedByString:@":"];
        }
        case PXIdentityValueKindSSID: {
            NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
            return data.length >= 1 && data.length <= 32 ? string : nil;
        }
        case PXIdentityValueKindDeviceName: {
            NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
            NSCharacterSet *controls = [NSCharacterSet controlCharacterSet];
            return data.length <= 255 && [string rangeOfCharacterFromSet:controls].location == NSNotFound ? string : nil;
        }
        case PXIdentityValueKindIOSVersion:
            return PXEntireStringMatches(string, @"[0-9]{1,2}\\.[0-9]{1,2}(?:\\.[0-9]{1,2})?", 0) ? string : nil;
        case PXIdentityValueKindIOSBuild: {
            NSString *canonical = [string uppercaseString];
            return PXEntireStringMatches(canonical, @"[0-9]{1,3}[A-Z][0-9A-Z]{1,5}", 0) ? canonical : nil;
        }
        case PXIdentityValueKindUnsignedDecimal:
            return PXEntireStringMatches(string, @"[0-9]+", 0) ? string : nil;
    }
    return nil;
}

BOOL PXValidateIdentityValue(id value, PXIdentityValueKind kind, BOOL allowZeroUUID) {
    return PXCanonicalIdentityValue(value, kind, allowZeroUUID) != nil;
}

static void PXValidateManagedField(NSMutableDictionary *result,
                                   NSMutableDictionary *issues,
                                   NSDictionary *source,
                                   NSString *key,
                                   PXIdentityValueKind kind,
                                   BOOL allowZeroUUID) {
    id raw = source[key];
    if (!raw || raw == [NSNull null]) return;
    NSString *canonical = PXCanonicalIdentityValue(raw, kind, allowZeroUUID);
    if (canonical) result[key] = canonical;
    else { [result removeObjectForKey:key]; issues[key] = @"invalid-format"; }
}

PXIdentityValidationResult *PXValidateDeviceIDs(NSDictionary *deviceIDs) {
    if (![deviceIDs isKindOfClass:[NSDictionary class]]) {
        return [[PXIdentityValidationResult alloc] initWithDeviceIDs:@{}
                                                              issues:@{@"$": @"not-a-dictionary"}
                                                          inputValid:NO];
    }
    NSMutableDictionary *result = [deviceIDs mutableCopy];
    NSMutableDictionary *issues = [NSMutableDictionary dictionary];

    NSArray *uuidKeys = @[@"IDFA", @"IDFV", @"SystemBootUUID", @"HardwareUUID", @"DyldCacheUUID",
                          @"PasteboardUUID", @"KeychainUUID", @"UserDefaultsUUID", @"AppGroupUUID",
                          @"CoreDataUUID", @"AppInstallUUID", @"AppContainerUUID"];
    for (NSString *key in uuidKeys) PXValidateManagedField(result, issues, deviceIDs, key, PXIdentityValueKindUUID, [key isEqualToString:@"IDFA"]);
    PXValidateManagedField(result, issues, deviceIDs, @"UDID", PXIdentityValueKindUDID, NO);
    PXValidateManagedField(result, issues, deviceIDs, @"IMEI", PXIdentityValueKindIMEI, NO);
    PXValidateManagedField(result, issues, deviceIDs, @"MEID", PXIdentityValueKindMEID, NO);
    for (NSString *key in @[@"SerialNumber", @"MLBSerialNumber"]) PXValidateManagedField(result, issues, deviceIDs, key, PXIdentityValueKindSerialNumber, NO);
    PXValidateManagedField(result, issues, deviceIDs, @"DeviceModel", PXIdentityValueKindDeviceModel, NO);
    for (NSString *key in @[@"WiFiAddress", @"BluetoothAddress", @"BSSID"]) PXValidateManagedField(result, issues, deviceIDs, key, PXIdentityValueKindMACAddress, NO);
    PXValidateManagedField(result, issues, deviceIDs, @"SSID", PXIdentityValueKindSSID, NO);
    PXValidateManagedField(result, issues, deviceIDs, @"DeviceName", PXIdentityValueKindDeviceName, NO);
    PXValidateManagedField(result, issues, deviceIDs, @"IOSVersion", PXIdentityValueKindIOSVersion, NO);
    PXValidateManagedField(result, issues, deviceIDs, @"IOSBuild", PXIdentityValueKindIOSBuild, NO);
    for (NSString *key in @[@"UniqueChipID", @"ECID"]) PXValidateManagedField(result, issues, deviceIDs, key, PXIdentityValueKindUnsignedDecimal, NO);

    id generation = deviceIDs[@"GenerationCounter"];
    if (generation) {
        double numericGeneration = [generation isKindOfClass:[NSNumber class]] ? [generation doubleValue] : -1.0;
        BOOL validGeneration = [generation isKindOfClass:[NSNumber class]] &&
            CFGetTypeID((__bridge CFTypeRef)generation) != CFBooleanGetTypeID() &&
            numericGeneration >= 0.0 && numericGeneration == (double)[generation unsignedLongLongValue];
        if (!validGeneration) { [result removeObjectForKey:@"GenerationCounter"]; issues[@"GenerationCounter"] = @"expected-nonnegative-integer"; }
    }
    id att = deviceIDs[@"ATTAuthorizationStatus"];
    if (att) {
        double numericATT = [att isKindOfClass:[NSNumber class]] ? [att doubleValue] : -1.0;
        BOOL validATT = [att isKindOfClass:[NSNumber class]] &&
            CFGetTypeID((__bridge CFTypeRef)att) != CFBooleanGetTypeID() &&
            numericATT >= 0.0 && numericATT <= 3.0 && numericATT == (double)[att integerValue];
        if (!validATT) { [result removeObjectForKey:@"ATTAuthorizationStatus"]; issues[@"ATTAuthorizationStatus"] = @"expected-integer-0-through-3"; }
        else if ([att integerValue] != 3) {
            NSString *idfa = result[@"IDFA"];
            if (idfa.length && !PXIsAllZeroHex(idfa)) {
                [result removeObjectForKey:@"IDFA"];
                issues[@"IDFA"] = @"nonzero-idfa-requires-authorized-att";
            }
        }
    }

    return [[PXIdentityValidationResult alloc] initWithDeviceIDs:[result copy]
                                                          issues:[issues copy]
                                                      inputValid:YES];
}
