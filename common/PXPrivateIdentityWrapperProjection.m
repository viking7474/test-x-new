#import "PXPrivateIdentityWrapperProjection.h"
#import <string.h>

static NSDictionary *PXPrivateWrapperRule(NSString *className,
                                           NSString *selector,
                                           BOOL classMethod,
                                           BOOL keyedGetter) {
    return @{
        @"class": className,
        @"selector": selector,
        @"classMethod": @(classMethod),
        @"keyedGetter": @(keyedGetter),
    };
}

NSArray<NSDictionary<NSString *, id> *> *PXPrivateIdentityWrapperRuleDescriptors(void) {
    static NSArray<NSDictionary<NSString *, id> *> *rules = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rules = @[
            // Public/system device wrappers. UIDevice key dispatchers are handled
            // by a dedicated one-object-argument adapter.
            PXPrivateWrapperRule(@"UIDevice", @"sf_productType", NO, NO),
            PXPrivateWrapperRule(@"UIDevice", @"sf_serialNumber", NO, NO),
            PXPrivateWrapperRule(@"UIDevice", @"sf_udidString", NO, NO),
            PXPrivateWrapperRule(@"UIDevice", @"sf_uuidString", NO, NO),
            PXPrivateWrapperRule(@"UIDevice", @"deviceInfoForKey:", NO, YES),
            PXPrivateWrapperRule(@"UIDevice", @"_deviceInfoForKey:", NO, YES),
            PXPrivateWrapperRule(@"LSApplicationProxy", @"applicationDSID", NO, NO),

            // AppleMediaServices / Accounts / CoreTelephony private wrappers.
            PXPrivateWrapperRule(@"AMSDevice", @"productType", YES, NO),
            PXPrivateWrapperRule(@"AMSDevice", @"serialNumber", YES, NO),
            PXPrivateWrapperRule(@"AMSDevice", @"MLBSerialNumber", YES, NO),
            PXPrivateWrapperRule(@"AMSDevice", @"productVersion", YES, NO),
            PXPrivateWrapperRule(@"AMSDevice", @"buildVersion", YES, NO),
            PXPrivateWrapperRule(@"AMSDevice", @"deviceName", YES, NO),

            PXPrivateWrapperRule(@"AADeviceInfo", @"productType", NO, NO),
            PXPrivateWrapperRule(@"AADeviceInfo", @"internationalMobileEquipmentIdentity", NO, NO),
            PXPrivateWrapperRule(@"AADeviceInfo", @"mobileEquipmentIdentifier", NO, NO),
            PXPrivateWrapperRule(@"AADeviceInfo", @"serialNumber", NO, NO),
            PXPrivateWrapperRule(@"AADeviceInfo", @"productVersion", NO, NO),
            PXPrivateWrapperRule(@"AADeviceInfo", @"deviceName", NO, NO),
            PXPrivateWrapperRule(@"AADeviceInfo", @"serialNumber", YES, NO),
            PXPrivateWrapperRule(@"AADeviceInfo", @"productVersion", YES, NO),
            PXPrivateWrapperRule(@"AADeviceInfo", @"udid", YES, NO),

            PXPrivateWrapperRule(@"CTLocalDevice", @"deviceName", NO, NO),
            PXPrivateWrapperRule(@"CTRemoteDevice", @"deviceName", NO, NO),
            PXPrivateWrapperRule(@"ISDevice", @"deviceName", NO, NO),
            PXPrivateWrapperRule(@"ISDevice", @"serialNumber", NO, NO),
            PXPrivateWrapperRule(@"CTDeviceIdentifier", @"deviceName", NO, NO),
            PXPrivateWrapperRule(@"CTDeviceIdentifier", @"deviceName", YES, NO),
            PXPrivateWrapperRule(@"CTDeviceIdentifier", @"IMEI", NO, NO),
            PXPrivateWrapperRule(@"CTDeviceIdentifier", @"IMEI", YES, NO),
            PXPrivateWrapperRule(@"CTMobileEquipmentInfo", @"IMEI", NO, NO),
            PXPrivateWrapperRule(@"CTMobileEquipmentInfo", @"MEID", NO, NO),

            PXPrivateWrapperRule(@"AKDevice", @"internationalMobileEquipmentIdentity", NO, NO),
            PXPrivateWrapperRule(@"AKDevice", @"internationalMobileEquipmentIdentity2", NO, NO),
            PXPrivateWrapperRule(@"AKDevice", @"mobileEquipmentIdentifier", NO, NO),
            PXPrivateWrapperRule(@"AKDevice", @"serialNumber", NO, NO),
            PXPrivateWrapperRule(@"AKDevice", @"MLBSerialNumber", NO, NO),
            PXPrivateWrapperRule(@"AKDevice", @"uniqueDeviceIdentifier", NO, NO),

            PXPrivateWrapperRule(@"SSDevice", @"productVersion", NO, NO),
            PXPrivateWrapperRule(@"SSDevice", @"productType", NO, NO),
            PXPrivateWrapperRule(@"SSDevice", @"serialNumber", NO, NO),
            PXPrivateWrapperRule(@"SSDevice", @"internationalMobileEquipmentIdentity", NO, NO),
            PXPrivateWrapperRule(@"AATrustedDevice", @"osVersion", NO, NO),

            PXPrivateWrapperRule(@"ICDeviceInfo", @"deviceModel", NO, NO),
            PXPrivateWrapperRule(@"ICDeviceInfo", @"deviceModel", YES, NO),
            PXPrivateWrapperRule(@"ICDeviceInfo", @"serialNumber", NO, NO),
            PXPrivateWrapperRule(@"ICDeviceInfo", @"serialNumber", YES, NO),
            PXPrivateWrapperRule(@"ICDeviceInfo", @"productVersion", NO, NO),
            PXPrivateWrapperRule(@"ICDeviceInfo", @"productVersion", YES, NO),
            PXPrivateWrapperRule(@"ICDeviceInfo", @"buildVersion", NO, NO),
            PXPrivateWrapperRule(@"ICDeviceInfo", @"buildVersion", YES, NO),
            PXPrivateWrapperRule(@"ICDeviceInfo", @"name", NO, NO),
            PXPrivateWrapperRule(@"ICDeviceInfo", @"name", YES, NO),

            PXPrivateWrapperRule(@"DMFDevice", @"IMEI", NO, NO),
            PXPrivateWrapperRule(@"DMFDevice", @"MEID", NO, NO),
            PXPrivateWrapperRule(@"DMFDevice", @"serialNumber", NO, NO),
            PXPrivateWrapperRule(@"DMFDevice", @"hostName", NO, NO),
            PXPrivateWrapperRule(@"DMFDevice", @"localHostName", NO, NO),
            PXPrivateWrapperRule(@"DMFDevice", @"osVersion", NO, NO),
            PXPrivateWrapperRule(@"DMFDevice", @"buildVersion", NO, NO),

            PXPrivateWrapperRule(@"AMSUserAgent", @"_iOSComponentHardwarePlatform", NO, NO),
            PXPrivateWrapperRule(@"AMSUserAgent", @"_iOSComponentBuildVersion", NO, NO),
            PXPrivateWrapperRule(@"AMSUserAgent", @"_iOSComponentDeviceModel", NO, NO),
        ];
    });
    return rules;
}

static const char *PXSkipObjCTypeQualifiers(const char *type) {
    if (!type) return NULL;
    while (*type && strchr("rnNoORV", *type)) type++;
    return type;
}

BOOL PXPrivateIdentityWrapperMethodEncodingIsSupported(const char *types, BOOL keyedGetter) {
    if (!types || !types[0]) return NO;
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:types];
    if (!signature) return NO;

    const char *returnType = PXSkipObjCTypeQualifiers(signature.methodReturnType);
    if (!returnType || returnType[0] != '@') return NO;
    if (signature.numberOfArguments != (keyedGetter ? 3u : 2u)) return NO;

    const char *selfType = PXSkipObjCTypeQualifiers([signature getArgumentTypeAtIndex:0]);
    const char *cmdType = PXSkipObjCTypeQualifiers([signature getArgumentTypeAtIndex:1]);
    if (!selfType || selfType[0] != '@' || !cmdType || cmdType[0] != ':') return NO;
    if (keyedGetter) {
        const char *keyType = PXSkipObjCTypeQualifiers([signature getArgumentTypeAtIndex:2]);
        if (!keyType || keyType[0] != '@') return NO;
    }
    return YES;
}

static id PXPrivateWrapperProjectResolvedValue(id original,
                                                NSString *value,
                                                PXIdentityExpectedType expectedType) {
    if (![value isKindOfClass:[NSString class]] || value.length == 0) return original;
    if ([original isKindOfClass:[NSString class]]) return value;
    if ([original isKindOfClass:[NSData class]]) return [value dataUsingEncoding:NSUTF8StringEncoding];
    if (original != nil) return original;
    if (expectedType == PXIdentityExpectedTypeData) {
        return [value dataUsingEncoding:NSUTF8StringEncoding];
    }
    return value;
}

id PXPrivateIdentityWrapperProjectObject(id original,
                                         NSString *surfaceKey,
                                         NSDictionary *deviceIDs) {
    PXIdentitySurfaceEntry *entry =
        PXIdentitySurfaceEntryForKey(surfaceKey, PXIdentitySurfacePrivateWrapper);
    if (!entry) return original;
    NSString *value = PXIdentitySurfaceResolveValue(entry, deviceIDs);
    return PXPrivateWrapperProjectResolvedValue(original, value, entry.expectedType);
}

id PXPrivateIdentityWrapperProjectKeyedObject(id original,
                                              NSString *queriedKey,
                                              NSDictionary *deviceIDs,
                                              PXIdentitySurfaceEntry **outEntry) {
    if (outEntry) *outEntry = nil;
    if (![queriedKey isKindOfClass:[NSString class]] || queriedKey.length == 0) return original;

    PXIdentitySurfaceEntry *entry =
        PXIdentitySurfaceEntryForKey(queriedKey, PXIdentitySurfaceMobileGestalt);
    if (!entry) entry = PXIdentitySurfaceEntryForKey(queriedKey, PXIdentitySurfaceIORegistry);
    if (!entry) entry = PXIdentitySurfaceEntryForKey(queriedKey, PXIdentitySurfacePrivateWrapper);
    if (!entry) return original;
    if (outEntry) *outEntry = entry;

    NSString *value = PXIdentitySurfaceResolveValue(entry, deviceIDs);
    return PXPrivateWrapperProjectResolvedValue(original, value, entry.expectedType);
}
