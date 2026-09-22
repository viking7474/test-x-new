#import <Foundation/Foundation.h>
#import "PXPrivateIdentityWrapperProjection.h"

static NSDictionary *PXPrivateWrapperFixture(void) {
    return @{
        @"DeviceModel": @"iPhone15,3",
        @"DeviceModelName": @"iPhone 14 Pro Max",
        @"IOSVersion": @"17.5.1",
        @"IOSBuild": @"21F90",
        @"DeviceName": @"Research iPhone",
        @"SerialNumber": @"F2LLD9ABCD12",
        @"MLBSerialNumber": @"C02XY1234567890AB",
        @"UDID": @"a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0",
        @"IDFA": @"A1B2C3D4-E5F6-4789-ABCD-0123456789EF",
        @"IDFV": @"B2C3D4E5-F607-489A-BCDE-1234567890FA",
        @"ATTAuthorizationStatus": @3,
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
    NSMutableSet<NSString *> *launchServicesUUIDRules = [NSMutableSet set];
    for (NSDictionary *rule in rules) {
        NSString *className = rule[@"class"];
        NSString *selector = rule[@"selector"];
        BOOL classMethod = [rule[@"classMethod"] boolValue];
        BOOL keyed = [rule[@"keyedGetter"] boolValue];
        BOOL uuidResult = [rule[@"uuidResult"] boolValue];
        NSCAssert(className.length > 0 && selector.length > 0, @"empty private-wrapper rule");
        NSCAssert(![className isEqualToString:@"Device"], @"generic Device class must stay excluded");
        NSCAssert(![className hasPrefix:@"PK"] && ![className hasPrefix:@"NF"],
                  @"Secure Element / PassKit evidence class entered A-05 allowlist: %@", className);
        NSCAssert([selector rangeOfString:@"secureElement" options:NSCaseInsensitiveSearch].location == NSNotFound,
                  @"Secure Element selector entered A-05 allowlist: %@", selector);
        NSCAssert(!uuidResult || (!classMethod && !keyed),
                  @"NSUUID projection must remain a no-argument instance getter: %@/%@", className, selector);
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
        if ([className hasPrefix:@"LSApplication"] && uuidResult) {
            [launchServicesUUIDRules addObject:[NSString stringWithFormat:@"%@.%@", className, selector]];
        }
    }
    NSCAssert(sawUIDeviceKeyed, @"UIDevice deviceInfoForKey: rule missing");
    NSCAssert(sawAMSUserAgent, @"AMSUserAgent build wrapper rule missing");
    NSSet *expectedLaunchServicesRules = [NSSet setWithArray:@[
        @"LSApplicationWorkspace.deviceIdentifierForVendor",
        @"LSApplicationWorkspace.deviceIdentifierForAdvertising",
        @"LSApplicationProxy.deviceIdentifierForVendor",
        @"LSApplicationProxy.deviceIdentifierForAdvertising",
    ]];
    NSCAssert([launchServicesUUIDRules isEqualToSet:expectedLaunchServicesRules],
              @"LaunchServices UUID rule inventory drifted: %@", launchServicesUUIDRules);

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

    NSUUID *originalUUID = [[NSUUID alloc] initWithUUIDString:@"11111111-2222-4333-8444-555555555555"];
    NSUUID *projectedIDFA = PXPrivateIdentityWrapperProjectUUID(originalUUID,
                                                                @"deviceIdentifierForAdvertising",
                                                                ids);
    NSUUID *projectedIDFV = PXPrivateIdentityWrapperProjectUUID(originalUUID,
                                                                @"deviceIdentifierForVendor",
                                                                ids);
    NSCAssert([projectedIDFA isKindOfClass:[NSUUID class]] &&
              [projectedIDFA.UUIDString isEqualToString:ids[@"IDFA"]],
              @"LaunchServices advertising identifier must match canonical IDFA as NSUUID");
    NSCAssert([projectedIDFV isKindOfClass:[NSUUID class]] &&
              [projectedIDFV.UUIDString isEqualToString:ids[@"IDFV"]],
              @"LaunchServices vendor identifier must match canonical IDFV as NSUUID");
    NSMutableDictionary *deniedTracking = [ids mutableCopy];
    deniedTracking[@"ATTAuthorizationStatus"] = @2;
    NSUUID *deniedIDFA = PXPrivateIdentityWrapperProjectUUID(originalUUID,
                                                             @"deviceIdentifierForAdvertising",
                                                             deniedTracking);
    NSCAssert([deniedIDFA.UUIDString isEqualToString:@"00000000-0000-0000-0000-000000000000"],
              @"LaunchServices advertising identifier must honor denied ATT with zero UUID");
    NSMutableDictionary *invalidUUIDs = [ids mutableCopy];
    invalidUUIDs[@"IDFA"] = @"not-a-uuid";
    NSCAssert(PXPrivateIdentityWrapperProjectUUID(originalUUID,
                                                  @"deviceIdentifierForAdvertising",
                                                  invalidUUIDs) == originalUUID,
              @"invalid LaunchServices UUID must fail open");
    NSCAssert(PXPrivateIdentityWrapperProjectUUID(nil,
                                                  @"deviceIdentifierForAdvertising",
                                                  ids) == nil,
              @"nil LaunchServices original must not synthesize a selector result");
    NSString *wrongShape = @"original-string";
    NSCAssert(PXPrivateIdentityWrapperProjectUUID(wrongShape,
                                                  @"deviceIdentifierForVendor",
                                                  ids) == wrongShape,
              @"non-NSUUID LaunchServices result must fail open");

    NSDictionary<NSString *, NSString *> *additionalWrappers = @{
        @"uniqueDeviceId": @"UDID",
        @"hardwarePlatform": @"HwModel",
        @"ICCID": @"ICCID",
        @"IMSI": @"IMSI",
        @"marketingName": @"DeviceModelName",
    };
    for (NSString *selector in additionalWrappers) {
        id projected = PXPrivateIdentityWrapperProjectObject(@"original", selector, ids);
        NSCAssert([projected isEqual:ids[additionalWrappers[selector]]],
                  @"P0-02 private wrapper projection drifted for %@", selector);
    }

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
