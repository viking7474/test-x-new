#import "PXIdentifierUUIDProjection.h"
#import <CoreFoundation/CoreFoundation.h>

static NSString *const kPXProjectedZeroIDFAUUID = @"00000000-0000-0000-0000-000000000000";

NSUUID *PXProjectIdentityUUID(NSUUID *original, id profileValue) {
    if (![original isKindOfClass:[NSUUID class]]) return original;
    if (![profileValue isKindOfClass:[NSString class]]) return original;
    NSString *value = (NSString *)profileValue;
    NSString *trimmed = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0 || ![trimmed isEqualToString:value]) return original;
    NSUUID *projected = [[NSUUID alloc] initWithUUIDString:value];
    return projected ?: original;
}

NSInteger PXIdentitySnapshotATTAuthorizationStatus(NSDictionary *deviceIDs) {
    if (![deviceIDs isKindOfClass:[NSDictionary class]]) return 0;
    id raw = deviceIDs[@"ATTAuthorizationStatus"];
    if (![raw isKindOfClass:[NSNumber class]]) return 0;
    if (CFGetTypeID((__bridge CFTypeRef)raw) == CFBooleanGetTypeID()) return 0;
    double numeric = [raw doubleValue];
    NSInteger status = [raw integerValue];
    if (numeric != (double)status || status < 0 || status > 3) return 0;
    return status;
}

NSUUID *PXProjectAdvertisingIdentityUUID(NSUUID *original, NSDictionary *deviceIDs) {
    if (![original isKindOfClass:[NSUUID class]]) return original;
    if (PXIdentitySnapshotATTAuthorizationStatus(deviceIDs) != 3) {
        return [[NSUUID alloc] initWithUUIDString:kPXProjectedZeroIDFAUUID];
    }
    return PXProjectIdentityUUID(original, deviceIDs[@"IDFA"]);
}
