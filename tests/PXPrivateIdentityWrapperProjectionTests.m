#import <Foundation/Foundation.h>
#import "PXPrivateIdentityWrapperProjection.h"

static NSDictionary *PXPrivateWrapperFixture(void) {
    return @{
        @"DeviceModel": @"iPhone15,3",
        @"IOSVersion": @"17.5.1",
        @"IOSBuild": @"21F90",
        @"DeviceName": @"Research iPhone",
        @"SerialNumber": @"F2LLD9ABCD12",
        @"MLBSerialNumber": @"C02XY1234567890AB",
        @"UDID": @"a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0",
        @"IDFA": @"A1B2C3D4-E5F6-4789-ABCD-0123456789EF",
        @"IMEI": @"490154203237518",
        @"IMEI2": @"356938035643809",
        @"MEID": @"A00000BEEF1234",
        @"ICCID": @"8901260123456789012",
        @"IMSI": @"310260123456789",
        @"HwModel": @"D74AP",
    };
}

void PXRunPrivateIdentityWrapperProjectionTests(void) {
    NSDictionary *ids = PXPrivateWrapperFixture();
    NSArray<NSDictionary<NSString *, id> *> *rules = PXPrivateIdentityWrapperRuleDescriptors();
    NSCAssert(rules.count > 20, @"private-wrapper rule inventory unexpectedly small");

    NSMutableSet<NSString *> *dedupe = [NSMutableSet set];
    BOOL sawUIDeviceKeyed = NO;
    BOOL sawAMSUserAgent = NO;
    for (NSDictionary *rule in rules) {
        NSString *className = rule[@"class"];
        NSString *selector = rule[@"selector"];
        BOOL classMethod = [rule[@"classMethod"] boolValue];
        BOOL keyed = [rule[@"keyedGetter"] boolValue];
        NSCAssert(className.length > 0 && selector.length > 0, @"empty private-wrapper rule");
        NSCAssert(![className isEqualToString:@"Device"], @"generic Device class must stay excluded");
        NSCAssert(![className hasPrefix:@"PK"] && ![className hasPrefix:@"NF"],
                  @"Secure Element / PassKit evidence class entered A-05 allowlist: %@", className);
        NSCAssert([selector rangeOfString:@"secureElement" options:NSCaseInsensitiveSearch].location == NSNotFound,
                  @"Secure Element selector entered A-05 allowlist: %@", selector);
        for (NSString *vendor in @[@"AppsFlyer", @"TikTok", @"JailbreakDetection", @"PIPO", @"Bugsnag"]) {
            NSCAssert([className rangeOfString:vendor options:NSCaseInsensitiveSearch].location == NSNotFound,
                      @"vendor anti-fraud class entered A-05 allowlist: %@", className);
        }
        if (!keyed) {
            NSCAssert(PXIdentitySurfaceEntryForKey(selector, PXIdentitySurfacePrivateWrapper) != nil,
                      @"A-05 selector has no private-wrapper registry mapping: %@/%@", className, selector);
        }
        NSString *token = [NSString stringWithFormat:@"%@|%@|%d", className, selector, classMethod];
        NSCAssert(![dedupe containsObject:token], @"duplicate A-05 rule: %@", token);
        [dedupe addObject:token];
        if ([className isEqualToString:@"UIDevice"] && [selector isEqualToString:@"deviceInfoForKey:"] && keyed) {
            sawUIDeviceKeyed = YES;
        }
        if ([className isEqualToString:@"AMSUserAgent"] &&
            [selector isEqualToString:@"_iOSComponentBuildVersion"] && !keyed) {
            sawAMSUserAgent = YES;
        }
    }
    NSCAssert(sawUIDeviceKeyed, @"UIDevice deviceInfoForKey: rule missing");
    NSCAssert(sawAMSUserAgent, @"AMSUserAgent build wrapper rule missing");

    NSCAssert(PXPrivateIdentityWrapperMethodEncodingIsSupported("@@:", NO), @"object getter encoding rejected");
    NSCAssert(PXPrivateIdentityWrapperMethodEncodingIsSupported("@@:@", YES), @"keyed object getter encoding rejected");
    NSCAssert(!PXPrivateIdentityWrapperMethodEncodingIsSupported("B@:", NO), @"scalar return encoding accepted");
    NSCAssert(!PXPrivateIdentityWrapperMethodEncodingIsSupported("@@:i", YES), @"scalar keyed argument encoding accepted");
    NSCAssert(!PXPrivateIdentityWrapperMethodEncodingIsSupported("@@:@", NO), @"wrong arity accepted as no-arg getter");

    id model = PXPrivateIdentityWrapperProjectObject(@"real-model", @"sf_productType", ids);
    NSCAssert([model isEqual:@"iPhone15,3"], @"sf_productType projection failed");
    id uuid = PXPrivateIdentityWrapperProjectObject(@"real-uuid", @"sf_uuidString", ids);
    NSCAssert([uuid isEqual:ids[@"IDFA"]], @"sf_uuidString must project canonical IDFA");
    id dsid = PXPrivateIdentityWrapperProjectObject(@"real-dsid", @"applicationDSID", ids);
    NSCAssert([dsid isEqual:ids[@"IDFA"]], @"applicationDSID must project canonical IDFA");

    NSData *originalData = [@"real" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *projectedData = PXPrivateIdentityWrapperProjectObject(originalData, @"serialNumber", ids);
    NSString *projectedSerial = [[NSString alloc] initWithData:projectedData encoding:NSUTF8StringEncoding];
    NSCAssert([projectedSerial isEqual:ids[@"SerialNumber"]], @"NSData shape projection failed");

    NSNumber *oddOriginal = @42;
    NSCAssert(PXPrivateIdentityWrapperProjectObject(oddOriginal, @"serialNumber", ids) == oddOriginal,
              @"unexpected object class must fail open");
    NSCAssert(PXPrivateIdentityWrapperProjectObject(@"real", @"secureElementIdentifier", ids) != nil,
              @"unknown/blocked surface must fail open");

    PXIdentitySurfaceEntry *keyEntry = nil;
    id keyedProduct = PXPrivateIdentityWrapperProjectKeyedObject(@"real", @"ProductType", ids, &keyEntry);
    NSCAssert([keyedProduct isEqual:ids[@"DeviceModel"]], @"keyed ProductType projection failed");
    NSCAssert(keyEntry != nil && [keyEntry.toggle isEqual:@"DeviceModel"], @"keyed entry ownership drifted");

    id unknown = PXPrivateIdentityWrapperProjectKeyedObject(@"keep-me", @"NotARealIdentityKey", ids, NULL);
    NSCAssert([unknown isEqual:@"keep-me"], @"unknown keyed lookup did not fail open");

    NSLog(@"[A-05] private identity wrapper projection/classification PASS");
}
