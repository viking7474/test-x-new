#import <Foundation/Foundation.h>
#import "PXManagedConfigurationIdentity.h"
#import "PXIdentitySurfaceRegistry.h"

static NSDictionary *PXMCFixture(NSString *serial, NSString *imei, NSString *version) {
    return @{
        @"IMEI": imei ?: @"",
        @"SerialNumber": serial ?: @"",
        @"IOSVersion": version ?: @"",
        @"IOSBuild": @"21F90",
        @"DeviceModel": @"iPhone15,3",
        @"UDID": @"a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0",
    };
}

void PXRunManagedConfigurationIdentityTests(void) {
    NSDictionary *ids = PXMCFixture(@"F2LLD9ABCD12", @"490154203237518", @"17.5.1");

    NSDictionary<NSString *, NSString *> *expected = @{
        @"MCCTIMEI": ids[@"IMEI"],
        @"MCIOSerialString": ids[@"SerialNumber"],
        @"MCProductVersion": ids[@"IOSVersion"],
        @"MCProductBuildVersion": ids[@"IOSBuild"],
        @"MCGestaltGetProductName": ids[@"DeviceModel"],
        @"MCGestaltGetDeviceUUID": ids[@"UDID"],
    };

    for (NSString *symbol in expected) {
        id resolved = PXManagedConfigurationResolveValue(symbol,
                                                         @"original",
                                                         ids,
                                                         YES,
                                                         YES);
        NSCAssert([resolved isEqual:expected[symbol]], @"%@ projected wrong value: %@", symbol, resolved);
    }

    NSCAssert([[PXManagedConfigurationResolveValue(@"MCIOSerialString", @"original", ids, NO, YES) description]
               isEqualToString:@"original"], @"scope-off must return original");
    NSCAssert([[PXManagedConfigurationResolveValue(@"MCIOSerialString", @"original", ids, YES, NO) description]
               isEqualToString:@"original"], @"toggle-off must return original");
    NSCAssert([[PXManagedConfigurationResolveValue(@"NotAManagedConfigurationGetter", @"original", ids, YES, YES) description]
               isEqualToString:@"original"], @"unknown symbol must return original");
    NSCAssert([[PXManagedConfigurationResolveValue(@"MCIOSerialString", @"original", nil, YES, YES) description]
               isEqualToString:@"original"], @"nil snapshot data must return original");

    NSMutableDictionary *missing = [ids mutableCopy];
    [missing removeObjectForKey:@"SerialNumber"];
    NSCAssert([[PXManagedConfigurationResolveValue(@"MCIOSerialString", @"original", missing, YES, YES) description]
               isEqualToString:@"original"], @"missing profile field must return original");

    NSMutableDictionary *empty = [ids mutableCopy];
    empty[@"SerialNumber"] = @"";
    NSCAssert([[PXManagedConfigurationResolveValue(@"MCIOSerialString", @"original", empty, YES, YES) description]
               isEqualToString:@"original"], @"empty profile field must return original");

    // Generation changes are represented by a new snapshot dictionary.  The pure
    // resolver must not cache a value between calls.
    NSDictionary *next = PXMCFixture(@"C02NEW123456", @"356938035643809", @"18.0");
    NSCAssert([[PXManagedConfigurationResolveValue(@"MCIOSerialString", @"old", next, YES, YES) description]
               isEqualToString:@"C02NEW123456"], @"new generation serial was stale");
    NSCAssert([[PXManagedConfigurationResolveValue(@"MCProductVersion", @"old", next, YES, YES) description]
               isEqualToString:@"18.0"], @"new generation version was stale");

    // Registry is the single mapping authority.
    for (NSString *symbol in expected) {
        PXIdentitySurfaceEntry *entry =
            PXIdentitySurfaceEntryForKey(symbol, PXIdentitySurfaceManagedConfiguration);
        NSCAssert(entry != nil && entry.expectedType == PXIdentityExpectedTypeString,
                  @"%@ registry entry missing/wrong type", symbol);
    }

    NSLog(@"[A-01] ManagedConfiguration identity resolver PASS");
}
