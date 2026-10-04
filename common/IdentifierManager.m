#import "IdentifierManager.h"
#import "DeviceModelManager.h"
#import "IDFAManager.h"
#import "IDFVManager.h"
#import "DeviceNameManager.h"
#import "SerialNumberManager.h"
#import "IOSVersionInfo.h"
#import "IOSBuildDB.h"
#import "IPhoneModelDB.h"
#import "DBDebugLogger.h"
#import "TLinkIOSLogging.h"
#import "VersionCompare.h"
#import "WiFiManager.h"
#import "StorageManager.h"
#import "BatteryManager.h"
#import "SystemUUIDManager.h"
#import "DyldCacheUUIDManager.h"
#import "PasteboardUUIDManager.h"
#import "KeychainUUIDManager.h"
#import "UserDefaultsUUIDManager.h"
#import "AppGroupUUIDManager.h"
#import "UptimeManager.h"
#import "CoreDataUUIDManager.h"
#import "AppInstallUUIDManager.h"
#import "AppContainerUUIDManager.h"
#import "PXPaths.h"
#import "PXSecuritySettingsStore.h"
#import "PXDeviceProfileSchema.h"
#import "PXIdentityValidator.h"
#import "PXIdentitySnapshot.h"
#import "PXRuntimeSnapshot.h"
#import <Security/Security.h>

@interface LSApplicationWorkspace
+ (id)defaultWorkspace;
- (NSArray *)allInstalledApplications;
@end

@interface LSApplicationProxy
+ (id)applicationProxyForIdentifier:(id)identifier;
@property(readonly) NSString *applicationIdentifier;
@property(readonly) NSString *localizedName;
@property(readonly) NSString *shortVersionString;
@property(readonly) NSString *bundleVersion;
@end

// Forward declare what we need from Profile
@interface Profile : NSObject
@property (nonatomic, strong, readonly) NSString *profileId;
@property (nonatomic, strong) NSString *name;
@end

@interface IdentifierManager ()
@property (nonatomic, strong) NSMutableDictionary *settings;
@property (nonatomic, strong) NSMutableDictionary *scopedApps;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSMutableDictionary *spoofCache;
- (BOOL)refreshCanonicalCellularIdentityForCurrentProfile;
@end

@implementation IdentifierManager

static NSSet<NSString *> *PXCanonicalIdentifierToggleKeys(void) {
    static NSSet<NSString *> *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = [NSSet setWithArray:@[
            @"IDFA", @"IDFV", @"DeviceName", @"DeviceModel", @"SerialNumber",
            @"UDID", @"IMEI", @"MEID", @"IOSVersion", @"WiFi",
            @"StorageSystem", @"Battery", @"SystemBootUUID", @"DyldCacheUUID",
            @"PasteboardUUID", @"KeychainUUID", @"UserDefaultsUUID", @"AppGroupUUID",
            @"CoreDataUUID", @"AppInstallUUID", @"AppContainerUUID", @"SystemUptime",
            @"BootTime", @"DeviceTheme"
        ]];
    });
    return keys;
}

static NSDictionary *PXSanitizedIdentifierSettings(NSDictionary *settings) {
    if (![settings isKindOfClass:NSDictionary.class]) return @{};
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSSet<NSString *> *allowed = PXCanonicalIdentifierToggleKeys();
    [settings enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        (void)stop;
        if (![key isKindOfClass:NSString.class] || ![allowed containsObject:key]) return;
        if ([value respondsToSelector:@selector(boolValue)]) result[key] = @([value boolValue]);
    }];
    return result;
}

#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
static BOOL PXIdentifierManagerIsManagerProcess(void) {
    return [NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.hydra.tlinkios"];
}
#endif

static BOOL PXRuntimeSnapshotImpliesIdentifierEnabled(NSString *type) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    if (![type isKindOfClass:NSString.class] || !type.length) return NO;
    NSDictionary *ids = PXRuntimeSnapshotDeviceIDs();
    NSDictionary *security = PXRuntimeSnapshotSecuritySettings();
    NSDictionary *tlink = PXRuntimeSnapshotTLinkSettings();

    if ([type isEqualToString:@"StorageSystem"]) {
        id explicitStorage = tlink[@"StorageSystemEnabled"];
        if ([explicitStorage respondsToSelector:@selector(boolValue)] && [explicitStorage boolValue]) return YES;
        NSDictionary *storage = PXRuntimeSnapshotProfileArtifact(@"storage");
        return storage[@"TotalStorage"] != nil && storage[@"FreeStorage"] != nil;
    }
    if ([type isEqualToString:@"Battery"]) {
        id secondary = security[@"batterySpoofEnabled"];
        if ([secondary respondsToSelector:@selector(boolValue)] && [secondary boolValue]) return YES;
        return PXRuntimeSnapshotProfileArtifact(@"batteryInfo").count > 0;
    }
    if ([type isEqualToString:@"WiFi"] || [type isEqualToString:@"WiFiAddress"]) {
        id secondary = security[@"wifiSpoofEnabled"];
        return [secondary respondsToSelector:@selector(boolValue)] && [secondary boolValue];
    }
    if ([type isEqualToString:@"DeviceTheme"]) {
        id secondary = security[@"deviceThemeSpoofEnabled"];
        return [secondary respondsToSelector:@selector(boolValue)] && [secondary boolValue];
    }

    // DeviceModel and IOSVersion are generated as a coherent baseline even
    // when only one dashboard option is requested, so mere value presence is
    // not proof of enablement. Dashboard Reset Data persists those toggles.
    NSDictionary<NSString *, NSArray<NSString *> *> *requiredKeys = @{
        @"IDFA": @[@"IDFA"], @"IDFV": @[@"IDFV"], @"DeviceName": @[@"DeviceName"],
        @"SerialNumber": @[@"SerialNumber"],
        @"UDID": @[@"UDID"], @"IMEI": @[@"IMEI"], @"MEID": @[@"MEID"],
        @"SystemBootUUID": @[@"SystemBootUUID"], @"DyldCacheUUID": @[@"DyldCacheUUID"],
        @"PasteboardUUID": @[@"PasteboardUUID"], @"KeychainUUID": @[@"KeychainUUID"],
        @"UserDefaultsUUID": @[@"UserDefaultsUUID"], @"AppGroupUUID": @[@"AppGroupUUID"],
        @"CoreDataUUID": @[@"CoreDataUUID"], @"AppInstallUUID": @[@"AppInstallUUID"],
        @"AppContainerUUID": @[@"AppContainerUUID"], @"SystemUptime": @[@"SystemUptime"],
        @"BootTime": @[@"BootTime"]
    };
    NSArray<NSString *> *required = requiredKeys[type];
    if (!required.count) return NO;
    for (NSString *key in required) {
        id value = ids[key];
        if ([value isKindOfClass:NSString.class] && [(NSString *)value length]) continue;
        if ([value isKindOfClass:NSNumber.class]) continue;
        return NO;
    }
    return YES;
#else
    (void)type;
    return NO;
#endif
}

static BOOL PXWebCompatIOSRangeEnabled(void) {
    NSUserDefaults *securitySettings = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
    return [securitySettings boolForKey:@"webCompatIOSRangeEnabled"];
}

static NSString *PXWebCompatMaxIOSForDeviceMaxIOS(NSString *deviceMaxIOS) {
    NSString *cap = @"16.3.1";
    if (![deviceMaxIOS isKindOfClass:[NSString class]] || deviceMaxIOS.length == 0) {
        return cap;
    }
    return (PXCompareVersions(deviceMaxIOS, cap) == NSOrderedAscending) ? deviceMaxIOS : cap;
}

static NSDictionary *PXPickFallbackIOSVersionInfoMax(NSString *maxIOSVersion) {
    IOSVersionInfo *mgr = [IOSVersionInfo sharedManager];
    NSArray *pairs = [mgr availableIOSVersions];
    if (![pairs isKindOfClass:[NSArray class]] || pairs.count == 0) return nil;

    NSMutableArray<NSDictionary *> *candidates = [NSMutableArray array];
    for (id item in pairs) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        NSString *v = item[@"version"];
        if (![v isKindOfClass:[NSString class]] || v.length == 0) continue;
        if (PXCompareVersions(v, maxIOSVersion) != NSOrderedDescending) {
            [candidates addObject:(NSDictionary *)item];
        }
    }

    if (candidates.count == 0) return nil;

    uint32_t r = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(r), (uint8_t *)&r) != errSecSuccess) {
        r = arc4random_uniform((uint32_t)candidates.count);
    }
    return candidates[(NSUInteger)(r % (uint32_t)candidates.count)];
}

#pragma mark - Device Model

static NSDictionary *PXScreenDictFromModelSpec(NSDictionary *modelSpec) {
    NSDictionary *screen = [modelSpec[@"screen"] isKindOfClass:[NSDictionary class]] ? modelSpec[@"screen"] : nil;
    return screen ?: @{};
}



static NSUInteger PXRandomIndex3(NSUInteger upperBoundExclusive) {
    if (upperBoundExclusive == 0) return 0;
    uint32_t r = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(r), (uint8_t *)&r) == errSecSuccess) {
        return (NSUInteger)(r % (uint32_t)upperBoundExclusive);
    }
    return (NSUInteger)arc4random_uniform((uint32_t)upperBoundExclusive);
}

static NSInteger PXMEIDLuhnCheckDigit(NSString *body);

static NSString *PXGenerateIMEIFromAuthoritativeTACs(NSArray *tacs) {
    if (![tacs isKindOfClass:[NSArray class]] || !tacs.count) return nil;
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSMutableArray<NSString *> *validTACs = [NSMutableArray array];
    for (id item in tacs) {
        if (![item isKindOfClass:[NSString class]]) continue;
        NSString *tac = (NSString *)item;
        if (tac.length == 8 && [tac rangeOfCharacterFromSet:nonDigits].location == NSNotFound) {
            [validTACs addObject:tac];
        }
    }
    if (!validTACs.count) return nil;

    NSString *tac = validTACs[PXRandomIndex3(validTACs.count)];
    NSMutableString *imei = [NSMutableString stringWithString:tac];
    // IMEI is 8-digit TAC + 6-digit serial + 1 Luhn check digit.
    for (NSUInteger i = 0; i < 6; i++) {
        [imei appendFormat:@"%u", arc4random_uniform(10)];
    }
    NSInteger sum = 0;
    for (NSUInteger i = 0; i < 14; i++) {
        NSInteger digit = [imei characterAtIndex:i] - '0';
        if (i % 2 == 1) digit *= 2;
        if (digit > 9) digit -= 9;
        sum += digit;
    }
    [imei appendFormat:@"%ld", (long)((10 - (sum % 10)) % 10)];
    return imei;
}

static NSString *PXGenerateMEIDFromAuthoritativePrefixes(NSArray *prefixes) {
    if (![prefixes isKindOfClass:[NSArray class]] || !prefixes.count) return nil;
    NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"];
    NSMutableArray<NSString *> *validPrefixes = [NSMutableArray array];
    for (id item in prefixes) {
        if (![item isKindOfClass:[NSString class]]) continue;
        NSString *prefix = [(NSString *)item uppercaseString];
        if (prefix.length == 6 &&
            [prefix rangeOfCharacterFromSet:[hex invertedSet]].location == NSNotFound) {
            [validPrefixes addObject:prefix];
        }
    }
    if (!validPrefixes.count) return nil;

    NSMutableString *body = [NSMutableString stringWithString:validPrefixes[PXRandomIndex3(validPrefixes.count)]];
    for (NSUInteger i = 0; i < 8; i++) {
        [body appendFormat:@"%X", arc4random_uniform(16)];
    }
    NSInteger checkDigit = PXMEIDLuhnCheckDigit(body);
    if (checkDigit < 0 || checkDigit > 15) return nil;
    [body appendFormat:@"%X", (unsigned int)checkDigit];
    return body;
}

static BOOL PXIdentityHasAllowedPrefix(NSString *value, NSArray *prefixes) {
    if (!value.length || ![prefixes isKindOfClass:[NSArray class]]) return NO;
    for (id item in prefixes) {
        if (![item isKindOfClass:[NSString class]]) continue;
        NSString *prefix = [(NSString *)item uppercaseString];
        if (prefix.length && [[value uppercaseString] hasPrefix:prefix]) return YES;
    }
    return NO;
}

static BOOL PXPopulateCanonicalCellularIdentity(NSMutableDictionary *deviceIds,
                                               NSDictionary *cellularSpec,
                                               NSDictionary *basebandMeta,
                                               BOOL wantsIMEI,
                                               BOOL wantsMEID,
                                               NSError **error) {
    if (![deviceIds isKindOfClass:[NSMutableDictionary class]]) return NO;

    NSString *existingIMEI = PXCanonicalIdentityValue(deviceIds[@"IMEI"], PXIdentityValueKindIMEI, NO);
    NSString *existingIMEI2 = PXCanonicalIdentityValue(deviceIds[@"IMEI2"], PXIdentityValueKindIMEI, NO);
    NSString *existingMEID = PXCanonicalIdentityValue(deviceIds[@"MEID"], PXIdentityValueKindMEID, NO);

    [deviceIds removeObjectsForKeys:@[
        @"CellularCapable", @"AdvertisedSIMCount", @"BasebandFamily", @"BasebandVersion",
        @"IMEI", @"IMEI2", @"MEID", @"ICCID", @"IMSI"
    ]];

    BOOL knownPresent = [cellularSpec[@"known"] isKindOfClass:[NSNumber class]];
    BOOL known = knownPresent && [cellularSpec[@"known"] boolValue];
    if (!known) return YES; // explicit unknown is a valid fail-closed state.

    BOOL enabled = [cellularSpec[@"enabled"] isKindOfClass:[NSNumber class]] &&
                   [cellularSpec[@"enabled"] boolValue];
    BOOL dualSIM = [cellularSpec[@"dualSIM"] isKindOfClass:[NSNumber class]] &&
                   [cellularSpec[@"dualSIM"] boolValue];
    BOOL cdma = [cellularSpec[@"cdma"] isKindOfClass:[NSNumber class]] &&
                [cellularSpec[@"cdma"] boolValue];

    deviceIds[@"CellularCapable"] = @(enabled);
    deviceIds[@"AdvertisedSIMCount"] = @(enabled ? (dualSIM ? 2 : 1) : 0);
    if (!enabled) return YES;

    NSString *basebandFamily = PXProfileString(basebandMeta[@"basebandFamily"]);
    NSString *basebandVersion = PXProfileString(basebandMeta[@"basebandVersion"]);
    if (!basebandFamily.length || !basebandVersion.length) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                         code:6010
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"Known cellular variant requires authoritative baseband family/version"}];
        }
        return NO;
    }
    deviceIds[@"BasebandFamily"] = basebandFamily;
    deviceIds[@"BasebandVersion"] = basebandVersion;

    if (wantsIMEI) {
        NSArray *tacs = [cellularSpec[@"imeiTACs"] isKindOfClass:[NSArray class]]
            ? cellularSpec[@"imeiTACs"] : nil;
        NSString *imei = PXIdentityHasAllowedPrefix(existingIMEI, tacs)
            ? existingIMEI : PXGenerateIMEIFromAuthoritativeTACs(tacs);
        if (!imei.length) {
            if (error) {
                *error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                             code:6011
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                        @"Canonical cellular variant is missing authoritative IMEI TAC data"}];
            }
            return NO;
        }
        deviceIds[@"IMEI"] = imei;

        if (dualSIM) {
            NSString *imei2 = (PXIdentityHasAllowedPrefix(existingIMEI2, tacs) &&
                               ![existingIMEI2 isEqualToString:imei]) ? existingIMEI2 : nil;
            for (NSUInteger attempt = 0; !imei2.length && attempt < 8; attempt++) {
                NSString *candidate = PXGenerateIMEIFromAuthoritativeTACs(tacs);
                if (candidate.length && ![candidate isEqualToString:imei]) {
                    imei2 = candidate;
                    break;
                }
            }
            if (!imei2.length) {
                if (error) {
                    *error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                                 code:6012
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                            @"Could not generate distinct canonical secondary IMEI"}];
                }
                return NO;
            }
            deviceIds[@"IMEI2"] = imei2;
        }
    }

    if (wantsMEID && cdma) {
        NSArray *prefixes = [cellularSpec[@"meidPrefixes"] isKindOfClass:[NSArray class]]
            ? cellularSpec[@"meidPrefixes"] : nil;
        NSString *meid = PXIdentityHasAllowedPrefix(existingMEID, prefixes)
            ? existingMEID : PXGenerateMEIDFromAuthoritativePrefixes(prefixes);
        if (!meid.length) {
            if (error) {
                *error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                             code:6013
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                        @"Canonical CDMA variant is missing authoritative MEID prefix data"}];
            }
            return NO;
        }
        deviceIds[@"MEID"] = meid;
    }
    return YES;
}

static void PXRemoveLegacyCellularFiles(NSString *identityDir) {
    if (!identityDir.length) return;
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *fileName in @[@"imei.plist", @"meid.plist"]) {
        NSString *path = [identityDir stringByAppendingPathComponent:fileName];
        if ([fm fileExistsAtPath:path]) [fm removeItemAtPath:path error:nil];
    }
}

static NSDictionary *PXPickHardwareVariantFromModelSpec(NSDictionary *modelSpec) {
    // Schema: variants: [ { boardID: "N71AP", hwModel: "N71AP" }, ... ]
    NSArray *variants = [modelSpec[@"variants"] isKindOfClass:[NSArray class]] ? modelSpec[@"variants"] : nil;
    if (!variants.count) return @{};

    NSMutableArray<NSDictionary *> *candidates = [NSMutableArray array];
    for (id v in variants) {
        if (![v isKindOfClass:[NSDictionary class]]) continue;
        NSString *boardID = PXProfileString(v[@"boardID"]);
        NSString *hwModel = PXProfileString(v[@"hwModel"]);
        if (!boardID.length && !hwModel.length) continue;
        [candidates addObject:(NSDictionary *)v];
    }

    if (!candidates.count) return @{};
    return candidates[PXRandomIndex3(candidates.count)];
}

static NSString *PXPickRegulatoryModelNumberFromModelSpec(NSDictionary *modelSpec, NSDictionary *pickedVariant) {
    // KMDevices.anumber is the regulatory A-number (for example A1901), not
    // MobileGestalt ModelNumber / IODeviceTree model-number (retail SKU).
    NSArray *nums = [pickedVariant[@"regulatoryModelNumbers"] isKindOfClass:[NSArray class]]
        ? pickedVariant[@"regulatoryModelNumbers"] : nil;
    if (!nums.count) {
        nums = [modelSpec[@"regulatoryModelNumbers"] isKindOfClass:[NSArray class]]
            ? modelSpec[@"regulatoryModelNumbers"] : nil;
    }
    if (!nums.count) return nil;

    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    for (id n in nums) {
        if ([n isKindOfClass:[NSString class]] && ((NSString *)n).length > 0) {
            [candidates addObject:(NSString *)n];
        }
    }
    if (!candidates.count) return nil;
    return candidates[PXRandomIndex3(candidates.count)];
}

- (NSString *)regenerateDeviceProfileGroup {
    self.error = nil;

    NSString *identityDir = [self profileIdentityPath];
    if (!identityDir.length) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6001 userInfo:@{NSLocalizedDescriptionKey: @"Could not resolve profile identity path"}];
        return nil;
    }

    NSError *dbErr = nil;
    IPhoneModelDB *modelDB = [IPhoneModelDB sharedManager];
    IOSBuildDB *buildDB = [IOSBuildDB sharedManager];
    if (![modelDB loadIfNeeded:&dbErr] || ![buildDB loadIfNeeded:&dbErr]) {
        self.error = dbErr;
        PXLog(@"[WeaponX] ⚠️ DeviceProfileGroup: DB not available (%@)", dbErr.localizedDescription ?: @"unknown");
        PXDBLog(@"DeviceProfileGroup: DB not available err=%@", dbErr.localizedDescription ?: @"nil");
        return nil;
    }

    BOOL webCompat = PXWebCompatIOSRangeEnabled();

    // Pick a random iPhone model that supports min iOS 13.0.
    // In WebCompat mode, we also require an iOS build <= 16.3.1 to exist for the chosen device.
    NSDictionary *modelSpec = nil;
    NSDictionary *iosMeta = nil;
    NSString *productType = nil;
    NSString *modelName = nil;
    NSString *maxIOS = nil;
    NSString *effectiveMaxIOS = nil;
    for (NSInteger attempt = 0; attempt < (webCompat ? 60 : 1); attempt++) {
        modelSpec = [modelDB randomModelMinIOS:@"13.0" error:&dbErr];
        if (!modelSpec) break;

        productType = [modelSpec[@"productType"] isKindOfClass:[NSString class]] ? modelSpec[@"productType"] : nil;
        modelName = [modelSpec[@"name"] isKindOfClass:[NSString class]] ? modelSpec[@"name"] : @"";
        maxIOS = [modelSpec[@"maxIOS"] isKindOfClass:[NSString class]] ? modelSpec[@"maxIOS"] : nil;
        if (!productType.length || !maxIOS.length) {
            continue;
        }

        effectiveMaxIOS = webCompat ? PXWebCompatMaxIOSForDeviceMaxIOS(maxIOS) : maxIOS;
        iosMeta = [buildDB randomMetaForDevice:productType min:@"13.0" max:effectiveMaxIOS error:&dbErr];
        if (iosMeta) break;
    }

    if (!modelSpec) {
        self.error = dbErr;
        PXLog(@"[WeaponX] ❌ DeviceProfileGroup: failed to pick model (%@)", dbErr.localizedDescription ?: @"unknown");
        PXDBLog(@"DeviceProfileGroup: failed to pick model err=%@", dbErr.localizedDescription ?: @"nil");
        return nil;
    }

    if (!productType.length || !maxIOS.length) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6002 userInfo:@{NSLocalizedDescriptionKey: @"Invalid model spec (missing productType/maxIOS)"}];
        PXDBLog(@"DeviceProfileGroup: invalid modelSpec missing productType/maxIOS spec=%@", modelSpec);
        return nil;
    }

    if (!iosMeta) {
        self.error = dbErr ?: [NSError errorWithDomain:@"com.hydra.tlinkios" code:6005 userInfo:@{NSLocalizedDescriptionKey: @"No compatible iOS build found for chosen model"}];
        PXLog(@"[WeaponX] ❌ DeviceProfileGroup: no compatible build for %@ (maxIOS=%@ effectiveMax=%@ webCompat=%@)", productType, maxIOS, effectiveMaxIOS ?: @"<nil>", webCompat ? @"YES" : @"NO");
        PXDBLog(@"DeviceProfileGroup: no compatible build device=%@ maxIOS=%@ effectiveMax=%@ webCompat=%@ err=%@", productType, maxIOS, effectiveMaxIOS ?: @"<nil>", webCompat ? @"YES" : @"NO", dbErr.localizedDescription ?: @"nil");
        return nil;
    }

    NSString *iosVersion = [iosMeta[@"version"] isKindOfClass:[NSString class]] ? iosMeta[@"version"] : nil;
    NSString *iosBuild = [iosMeta[@"build"] isKindOfClass:[NSString class]] ? iosMeta[@"build"] : nil;
    NSString *darwin = [iosMeta[@"darwin"] isKindOfClass:[NSString class]] ? iosMeta[@"darwin"] : nil;
    NSString *xnu = [iosMeta[@"xnu"] isKindOfClass:[NSString class]] ? iosMeta[@"xnu"] : nil;
    NSString *kernel = [iosMeta[@"kernel_version"] isKindOfClass:[NSString class]] ? iosMeta[@"kernel_version"] : nil;
    if (!iosVersion.length || !iosBuild.length || !darwin.length || !xnu.length || !kernel.length) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6003 userInfo:@{NSLocalizedDescriptionKey: @"Invalid iOS meta (missing required fields)"}];
        PXDBLog(@"DeviceProfileGroup: invalid iosMeta device=%@ meta=%@", productType, iosMeta);
        return nil;
    }

    // P0: versioned model data is authoritative for model-dependent hardware.
    // Do not reconstruct RAM/display/camera/storage from ProductType prefixes here.
    NSDictionary *hardwareSpecs = [modelDB canonicalHardwareSpecForProductType:productType];
    if (!hardwareSpecs.count) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6006 userInfo:@{NSLocalizedDescriptionKey: @"Canonical hardware metadata missing for model"}];
        PXDBLog(@"DeviceProfileGroup: missing canonical hardware metadata device=%@", productType);
        return nil;
    }
    NSString *screenResolution = PXProfileString(hardwareSpecs[@"screenResolution"]);
    NSString *viewportResolution = PXProfileString(hardwareSpecs[@"viewportResolution"]);
    NSNumber *scale = PXProfilePositiveNumber(hardwareSpecs[@"devicePixelRatio"]);
    NSNumber *nativeScale = PXProfilePositiveNumber(hardwareSpecs[@"nativeScale"]);
    NSNumber *ppi = PXProfilePositiveNumber(hardwareSpecs[@"screenDensity"]);
    NSString *cpuArchitecture = PXProfileString(hardwareSpecs[@"cpuArchitecture"]);
    NSString *cpuProfileKey = PXProfileString(hardwareSpecs[@"cpuProfileKey"]);
    NSNumber *deviceMemoryGB = PXProfilePositiveNumber(hardwareSpecs[@"deviceMemory"]);
    NSNumber *cpuCores = PXProfilePositiveNumber(hardwareSpecs[@"cpuCoreCount"]);

    // GPU/Metal/WebGL remain compatibility-only until the P1 GPU catalog is
    // authoritative. They must never overwrite P0 hardware fields above.
    NSDictionary *legacySpecs = [[DeviceModelManager sharedManager] deviceSpecificationsForModel:productType] ?: @{};
    NSString *gpuFamily = PXProfileString(legacySpecs[@"gpuFamily"]);
    NSString *metalFeatureSet = PXProfileString(legacySpecs[@"metalFeatureSet"]);

    // Hardware variant selection. BoardID/HwModel and A-number are one tuple.
    NSDictionary *pickedVariant = PXPickHardwareVariantFromModelSpec(modelSpec);
    NSString *boardID = PXProfileString(pickedVariant[@"boardID"]);
    NSString *hwModel = PXProfileString(pickedVariant[@"hwModel"]);
    if (!boardID.length || !hwModel.length) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6007 userInfo:@{NSLocalizedDescriptionKey: @"Canonical hardware variant missing for model"}];
        PXDBLog(@"DeviceProfileGroup: missing variant device=%@ spec=%@", productType, modelSpec);
        return nil;
    }

    // Regulatory A-number is selected from the exact same hardware variant.
    // Retail ModelNumber is a separate SKU identity and remains unset until
    // authoritative SKU data is available.
    NSString *regulatoryModelNumber = PXPickRegulatoryModelNumberFromModelSpec(modelSpec, pickedVariant);
    if ([pickedVariant[@"regulatoryModelNumbers"] isKindOfClass:[NSArray class]] &&
        [pickedVariant[@"regulatoryModelNumbers"] count] > 0 && !regulatoryModelNumber.length) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6008 userInfo:@{NSLocalizedDescriptionKey: @"Canonical regulatory model number missing for selected variant"}];
        return nil;
    }

    // P1: cellular/baseband is resolved from the exact ProductType + regulatory
    // A-number + IOSBuild tuple. Unknown regional data remains absent/fail-closed.
    NSDictionary *cellularSpec = [modelDB cellularSpecForProductType:productType
                                               regulatoryModelNumber:regulatoryModelNumber ?: @""];
    BOOL cellularKnown = [cellularSpec[@"known"] isKindOfClass:[NSNumber class]] &&
                          [cellularSpec[@"known"] boolValue];
    BOOL cellularEnabled = cellularKnown &&
                           [cellularSpec[@"enabled"] isKindOfClass:[NSNumber class]] &&
                           [cellularSpec[@"enabled"] boolValue];
    NSDictionary *basebandMeta = nil;
    if (cellularKnown) {
        if (cellularEnabled) {
            basebandMeta = [modelDB basebandMetaForProductType:productType
                                         regulatoryModelNumber:regulatoryModelNumber ?: @""
                                                      iosBuild:iosBuild];
            if (!basebandMeta.count) {
                self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                                 code:6009
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                            @"Known cellular variant is missing authoritative baseband metadata for selected iOS build"}];
                PXDBLog(@"DeviceProfileGroup: missing baseband device=%@ regulatory=%@ build=%@",
                        productType, regulatoryModelNumber ?: @"<nil>", iosBuild ?: @"<nil>");
                return nil;
            }
        }
    }

    NSDictionary *webGLInfo = PXWebGLInfoFromModelSpec(modelSpec);
    if (!webGLInfo.count) webGLInfo = PXWebGLInfoFromModelSpec(legacySpecs);

    NSDate *now = [NSDate date];

    // Update device_ids.plist (source of truth)
    NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
    NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: [NSMutableDictionary dictionary];
    NSInteger gen = [deviceIds[@"GenerationCounter"] respondsToSelector:@selector(integerValue)] ? [deviceIds[@"GenerationCounter"] integerValue] : 0;
    gen += 1;

    // Clear fields managed by the Device Profile group to avoid stale values.
    NSArray<NSString *> *managedKeys = @[
        @"DeviceModel", @"DeviceModelName",
        @"ScreenResolution", @"ViewportResolution", @"DevicePixelRatio", @"NativeScale", @"ScreenDensityPPI",
        @"CPUArchitecture", @"CPUProfileKey", @"DeviceMemory", @"CPUCoreCount", @"MetalFeatureSet", @"GPUFamily",
        @"WebGLVendor", @"WebGLRenderer", @"WebGLVersion",
        @"WebGLUnmaskedVendor", @"WebGLUnmaskedRenderer",
        @"WebGLMaxTextureSize", @"WebGLMaxRenderbufferSize", @"WebGLMaxRenderBufferSize",
        @"BoardID", @"HwModel", @"ModelNumber", @"RegulatoryModelNumber",
        @"FrontCameraMegapixels", @"RearCameraMegapixels", @"RearCameraCount",
        @"HasFrontCamera", @"HasRearCamera", @"HasPanoramaCamera",
        @"HasUltraWideCamera", @"HasTelephotoCamera", @"HasLiDARScanner",
        @"Supports4KVideo", @"StorageCapacitiesGB",
        @"CellularCapable", @"AdvertisedSIMCount", @"BasebandFamily", @"BasebandVersion",
        @"IMEI", @"IMEI2", @"MEID", @"ICCID", @"IMSI",
        @"IOSVersion", @"IOSBuild", @"Darwin", @"XNU", @"KernelVersion"
    ];
    for (NSString *k in managedKeys) {
        [deviceIds removeObjectForKey:k];
    }

    deviceIds[@"DeviceModel"] = productType;
    deviceIds[@"DeviceModelName"] = modelName ?: @"";
    deviceIds[@"ScreenResolution"] = screenResolution ?: @"";
    deviceIds[@"ViewportResolution"] = viewportResolution ?: @"";
    if (scale) deviceIds[@"DevicePixelRatio"] = scale;
    if (nativeScale) deviceIds[@"NativeScale"] = nativeScale;
    if (ppi) deviceIds[@"ScreenDensityPPI"] = ppi;
    deviceIds[@"CPUArchitecture"] = cpuArchitecture ?: @"";
    if (cpuProfileKey.length) deviceIds[@"CPUProfileKey"] = cpuProfileKey;
    if (deviceMemoryGB) deviceIds[@"DeviceMemory"] = deviceMemoryGB;
    if (cpuCores) deviceIds[@"CPUCoreCount"] = cpuCores;
    if (metalFeatureSet.length) deviceIds[@"MetalFeatureSet"] = metalFeatureSet;
    if (gpuFamily.length) deviceIds[@"GPUFamily"] = gpuFamily;
    PXWriteWebGLInfoToDeviceIDs(deviceIds, webGLInfo);
    PXWriteHardwareCapabilitiesToDeviceIDs(deviceIds, hardwareSpecs);
    if (boardID.length) deviceIds[@"BoardID"] = boardID;
    if (hwModel.length) deviceIds[@"HwModel"] = hwModel;
    if (regulatoryModelNumber.length) deviceIds[@"RegulatoryModelNumber"] = regulatoryModelNumber;

    NSError *cellularError = nil;
    if (!PXPopulateCanonicalCellularIdentity(deviceIds,
                                             cellularSpec,
                                             basebandMeta,
                                             [self isIdentifierEnabled:@"IMEI"],
                                             [self isIdentifierEnabled:@"MEID"],
                                             &cellularError)) {
        self.error = cellularError ?: [NSError errorWithDomain:@"com.hydra.tlinkios"
                                                           code:6014
                                                       userInfo:@{NSLocalizedDescriptionKey:
                                                                      @"Failed to populate canonical cellular identity"}];
        return nil;
    }

    // iOS fields (store normalized components)
    deviceIds[@"IOSVersion"] = iosVersion;
    deviceIds[@"IOSBuild"] = iosBuild;
    deviceIds[@"Darwin"] = darwin;
    deviceIds[@"XNU"] = xnu;
    deviceIds[@"KernelVersion"] = kernel;

    deviceIds[@"GenerationCounter"] = @(gen);
    deviceIds[@"CommittedAt"] = now;

    BOOL wrote = [deviceIds writeToFile:deviceIdsPath atomically:YES];
    if (!wrote) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6004 userInfo:@{NSLocalizedDescriptionKey: @"Failed to write device_ids.plist"}];
        return nil;
    }

    // The model/iOS/baseband dependency group owns telephony compatibility.
    // Remove legacy per-identifier files after the new generation commits so
    // currentValueForIdentifier cannot resurrect IMEI/MEID from an old model.
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *fileName in @[@"imei.plist", @"meid.plist"]) {
        NSString *path = [identityDir stringByAppendingPathComponent:fileName];
        if ([fm fileExistsAtPath:path]) [fm removeItemAtPath:path error:nil];
    }

    // Keep IOSVersionInfo in sync for processes that fall back to it.
    @try {
        NSDictionary *versionDict = @{
            @"version": iosVersion,
            @"build": iosBuild,
            @"darwin": darwin,
            @"xnu": xnu,
            @"kernel_version": kernel,
            @"lastUpdated": now
        };
        [[IOSVersionInfo sharedManager] setCurrentIOSVersionInfo:versionDict];
    } @catch (__unused NSException *e) {
    }

    // Keep DeviceModelManager in sync if present.
    @try {
        [[DeviceModelManager sharedManager] setCurrentDeviceModel:productType];
    } @catch (__unused NSException *e) {
    }

    PXLog(@"[WeaponX] ✅ DeviceProfileGroup: %@ (%@) iOS %@ (%@)", productType, modelName ?: @"", iosVersion, iosBuild);
    PXDBLog(@"DeviceProfileGroup: picked device=%@ regulatoryModelNumber=%@ boardID=%@ hwModel=%@", productType, regulatoryModelNumber ?: @"<nil>", boardID ?: @"<nil>", hwModel ?: @"<nil>");
    return productType;
}

- (NSString *)generateDeviceModel {
    // Compatibility API: DeviceModel is a dependency group, not an independent
    // random value. Route every caller through the canonical atomic generator.
    return [self regenerateDeviceProfileGroup];
}

- (BOOL)setCustomDeviceModel:(NSString *)value {
    BOOL isIPhone = [value isKindOfClass:[NSString class]] && [value hasPrefix:@"iPhone"];
    // P0 ownership rule: every iPhone must exist in the canonical model DB.
    // DeviceModelManager remains a compatibility source only for non-iPhone models.
    BOOL valid = isIPhone ? [[IPhoneModelDB sharedManager] containsProductType:value]
                          : [[DeviceModelManager sharedManager] isValidDeviceModel:value];
    if (!valid) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:2003 userInfo:@{NSLocalizedDescriptionKey: @"Invalid Device Model"}];
        return NO;
    }
    NSString *identityDir = [self profileIdentityPath];
    BOOL success = NO;
    
    DeviceModelManager *deviceManager = [DeviceModelManager sharedManager];
    IPhoneModelDB *modelDB = [IPhoneModelDB sharedManager];
    NSDictionary *modelSpec = [modelDB specForProductType:value];
    NSDictionary *dbHardwareSpecs = modelSpec ? [modelDB canonicalHardwareSpecForProductType:value] : nil;
    NSDictionary *legacySpecs = [deviceManager deviceSpecificationsForModel:value] ?: @{};
    NSDictionary *hardwareSpecs = dbHardwareSpecs.count ? dbHardwareSpecs : legacySpecs;

    // DB-backed iPhone models must resolve P0 hardware from canonical data. The
    // legacy manager is retained only for models not yet present in the DB.
    if (modelSpec && !dbHardwareSpecs.count) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:2004 userInfo:@{NSLocalizedDescriptionKey: @"Canonical hardware metadata missing for Device Model"}];
        return NO;
    }

    NSString *deviceModelName = PXProfileString(hardwareSpecs[@"name"]) ?: [deviceManager deviceModelNameForString:value];
    NSString *screenResolution = PXProfileString(hardwareSpecs[@"screenResolution"]);
    NSString *viewportResolution = PXProfileString(hardwareSpecs[@"viewportResolution"]);
    CGFloat devicePixelRatio = [hardwareSpecs[@"devicePixelRatio"] doubleValue];
    CGFloat nativeScale = [hardwareSpecs[@"nativeScale"] doubleValue];
    NSInteger screenDensity = [hardwareSpecs[@"screenDensity"] integerValue];
    NSString *cpuArchitecture = PXProfileString(hardwareSpecs[@"cpuArchitecture"]);
    NSString *cpuProfileKey = PXProfileString(hardwareSpecs[@"cpuProfileKey"]);
    NSInteger deviceMemory = [hardwareSpecs[@"deviceMemory"] integerValue];
    NSInteger cpuCoreCount = [hardwareSpecs[@"cpuCoreCount"] integerValue];

    // P1 GPU/Metal/WebGL still uses the compatibility table for now.
    NSString *gpuFamily = PXProfileString(legacySpecs[@"gpuFamily"]);
    NSDictionary *webGLInfo = [deviceManager webGLInfoForModel:value];
    NSString *metalFeatureSet = PXProfileString(legacySpecs[@"metalFeatureSet"]);

    NSDictionary *pickedVariant = modelSpec ? PXPickHardwareVariantFromModelSpec(modelSpec) : @{};
    NSString *boardID = PXProfileString(pickedVariant[@"boardID"]);
    NSString *hwModel = PXProfileString(pickedVariant[@"hwModel"]);
    NSString *regulatoryModelNumber = modelSpec ? PXPickRegulatoryModelNumberFromModelSpec(modelSpec, pickedVariant) : nil;
    if (modelSpec && (!boardID.length || !hwModel.length)) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:2005 userInfo:@{NSLocalizedDescriptionKey: @"Canonical hardware variant missing for Device Model"}];
        return NO;
    }
    if (!modelSpec) {
        boardID = PXProfileString(hardwareSpecs[@"boardID"]);
        hwModel = PXProfileString(hardwareSpecs[@"hwModel"]);
    }
    
    if (identityDir) {
        // Update the combined device_ids.plist
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: [NSMutableDictionary dictionary];
        
        // Add all device specifications to the device_ids.plist
        deviceIds[@"DeviceModel"] = value ?: @"";
        deviceIds[@"DeviceModelName"] = deviceModelName ?: @"";
        deviceIds[@"ScreenResolution"] = screenResolution ?: @"";
        deviceIds[@"ViewportResolution"] = viewportResolution ?: @"";
        deviceIds[@"DevicePixelRatio"] = @(devicePixelRatio);
        if (nativeScale > 0.0) deviceIds[@"NativeScale"] = @(nativeScale); else [deviceIds removeObjectForKey:@"NativeScale"];
        deviceIds[@"ScreenDensityPPI"] = @(screenDensity);
        deviceIds[@"CPUArchitecture"] = cpuArchitecture ?: @"";
        if (cpuProfileKey.length) deviceIds[@"CPUProfileKey"] = cpuProfileKey; else [deviceIds removeObjectForKey:@"CPUProfileKey"];
        deviceIds[@"DeviceMemory"] = @(deviceMemory);
        deviceIds[@"CPUCoreCount"] = @(cpuCoreCount);
        [deviceIds removeObjectsForKeys:@[
            @"MetalFeatureSet", @"GPUFamily", @"BoardID", @"HwModel", @"ModelNumber", @"RegulatoryModelNumber",
            @"IOSVersion", @"IOSBuild", @"Darwin", @"XNU", @"KernelVersion",
            @"CellularCapable", @"AdvertisedSIMCount", @"BasebandFamily", @"BasebandVersion",
            @"IMEI", @"IMEI2", @"MEID", @"ICCID", @"IMSI"
        ]];
        NSString *normalizedMetal = PXProfileString(metalFeatureSet);
        NSString *normalizedGPU = PXProfileString(gpuFamily);
        NSString *normalizedBoardID = PXProfileString(boardID);
        NSString *normalizedHwModel = PXProfileString(hwModel);
        if (normalizedMetal) deviceIds[@"MetalFeatureSet"] = normalizedMetal;
        if (normalizedGPU) deviceIds[@"GPUFamily"] = normalizedGPU;
        PXWriteWebGLInfoToDeviceIDs(deviceIds, webGLInfo);
        PXWriteHardwareCapabilitiesToDeviceIDs(deviceIds, hardwareSpecs);
        if (normalizedBoardID) deviceIds[@"BoardID"] = normalizedBoardID;
        if (normalizedHwModel) deviceIds[@"HwModel"] = normalizedHwModel;
        if (regulatoryModelNumber.length) deviceIds[@"RegulatoryModelNumber"] = regulatoryModelNumber;
        
        success = [deviceIds writeToFile:deviceIdsPath atomically:YES];
    }
    if (success) {
        // Model changes invalidate every old cellular identity file as well as
        // the in-plist tuple cleared above. A later coherent profile apply will
        // repopulate them from the selected A-number/build if authoritative.
        PXRemoveLegacyCellularFiles(identityDir);
        [[DeviceModelManager sharedManager] setCurrentDeviceModel:value];
    }
    return success;
}


+ (instancetype)sharedManager {
    static IdentifierManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
        [sharedManager loadSettings];
    });
    return sharedManager;
}

- (instancetype)init {
    if (self = [super init]) {
        _settings = [NSMutableDictionary dictionary];
        _scopedApps = [NSMutableDictionary dictionary];
        _spoofCache = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Profile Integration

- (NSString *)getActiveProfileId {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    // The manager mutates the live active profile before the daemon has had a
    // chance to republish its runtime snapshot. Reading the snapshot here can
    // therefore redirect a reset/regeneration into the previously active
    // profile. Only injected hosts should prefer the sandbox-safe mirror.
    NSString *profileID = nil;
    if (!PXIdentifierManagerIsManagerProcess()) {
        profileID = PXRuntimeSnapshotProfileID();
    }
    if (!profileID.length) profileID = PXActiveProfileID();
#else
    NSString *profileID = PXActiveProfileID();
#endif
    if (!profileID.length) {
        NSLog(@"[WeaponX] Error: Could not resolve active profile ID");
    }
    return profileID;
}

- (NSString *)profileIdentityPath {
    // Get current profile ID without directly using ProfileManager
    NSString *profileId = [self getActiveProfileId];
    if (!profileId) {
        NSLog(@"[WeaponX] Error: No active profile when getting identity path");
        return nil;
    }
    
    // Build the identity path through the shared profile resolver.
    NSString *identityDir = PXProfileIdentityPath(profileId);
    if (!identityDir.length) return nil;
    
    // Create the directory if it doesn't exist
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:identityDir]) {
        NSDictionary *attributes = @{NSFilePosixPermissions: @0755,
                                    NSFileOwnerAccountName: @"mobile"};
        
        NSError *dirError = nil;
        if (![fileManager createDirectoryAtPath:identityDir 
                    withIntermediateDirectories:YES 
                                     attributes:attributes
                                          error:&dirError]) {
            NSLog(@"[WeaponX] Error creating identity directory: %@", dirError);
            return nil;
        }
    }
    
    // Run profile schema migration once per load (reentrancy-safe)
    static BOOL sMigratingSchema = NO;
    if (!sMigratingSchema) {
        sMigratingSchema = YES;
        [self migrateProfileSchemaIfNeeded];
        sMigratingSchema = NO;
    }
    
    return identityDir;
}

#pragma mark - Identifier Management

- (NSString *)generateIDFA {
    NSString *idfa = [[IDFAManager sharedManager] generateIDFA];
    if (!idfa) {
        self.error = [[IDFAManager sharedManager] lastError];
        return nil;
    }
    
    // Save to profile-specific path
    NSString *identityDir = [self profileIdentityPath];
    if (identityDir) {
        NSDictionary *idfaDict = @{@"value": idfa, @"lastUpdated": [NSDate date]};
        NSString *idfaPath = [identityDir stringByAppendingPathComponent:@"advertising_id.plist"];
        [idfaDict writeToFile:idfaPath atomically:YES];
        
        // Also update the combined device_ids.plist
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: 
                                         [NSMutableDictionary dictionary];
        deviceIds[@"IDFA"] = idfa;
        [deviceIds writeToFile:deviceIdsPath atomically:YES];
    }
    
    return idfa;
}

- (NSString *)generateIDFV {
    NSString *idfv = [[IDFVManager sharedManager] generateIDFV];
    if (!idfv) {
        self.error = [[IDFVManager sharedManager] lastError];
        return nil;
    }
    
    // Save to profile-specific path
    NSString *identityDir = [self profileIdentityPath];
    if (identityDir) {
        NSDictionary *idfvDict = @{@"value": idfv, @"lastUpdated": [NSDate date]};
        NSString *idfvPath = [identityDir stringByAppendingPathComponent:@"vendor_id.plist"];
        [idfvDict writeToFile:idfvPath atomically:YES];
        
        // Also update the combined device_ids.plist
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: 
                                         [NSMutableDictionary dictionary];
        deviceIds[@"IDFV"] = idfv;
        [deviceIds writeToFile:deviceIdsPath atomically:YES];
    }
    
    return idfv;
}

- (NSString *)generateDeviceName {
    NSString *deviceName = [[DeviceNameManager sharedManager] generateDeviceName];
    if (!deviceName) {
        self.error = [[DeviceNameManager sharedManager] lastError];
        return nil;
    }
    
    // Save to profile-specific path
    NSString *identityDir = [self profileIdentityPath];
    if (identityDir) {
        NSDictionary *deviceNameDict = @{@"value": deviceName, @"lastUpdated": [NSDate date]};
        NSString *deviceNamePath = [identityDir stringByAppendingPathComponent:@"device_name.plist"];
        [deviceNameDict writeToFile:deviceNamePath atomically:YES];
        
        // Also update the combined device_ids.plist
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: 
                                         [NSMutableDictionary dictionary];
        deviceIds[@"DeviceName"] = deviceName;
        [deviceIds writeToFile:deviceIdsPath atomically:YES];
    }
    
    return deviceName;
}

- (NSString *)generateSerialNumber {
    self.error = nil;
    
    NSString *serialNumber = [[SerialNumberManager sharedManager] generateSerialNumber];
    if (!serialNumber) {
        self.error = [[SerialNumberManager sharedManager] lastError];
        return nil;
    }
    
    // Save to profile-specific path
    NSString *identityDir = [self profileIdentityPath];
    if (identityDir) {
        NSDictionary *serialDict = @{@"value": serialNumber, @"lastUpdated": [NSDate date]};
        NSString *serialPath = [identityDir stringByAppendingPathComponent:@"serial_number.plist"];
        [serialDict writeToFile:serialPath atomically:YES];
        
        // Also update the combined device_ids.plist
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: 
                                         [NSMutableDictionary dictionary];
        deviceIds[@"SerialNumber"] = serialNumber;
        [deviceIds writeToFile:deviceIdsPath atomically:YES];
    }
    
    return serialNumber;
}

- (NSDictionary *)generateIOSVersion {
    self.error = nil;

    NSString *identityDir = [self profileIdentityPath];
    NSString *deviceModel = PXProfileString([self currentValueForIdentifier:@"DeviceModel"]);
    if (!identityDir.length || !deviceModel.length) {
        // Compatibility API: when no model exists, seed the complete dependency
        // group instead of generating an orphan software identity.
        NSString *generatedModel = [self regenerateDeviceProfileGroup];
        if (!generatedModel.length) return nil;
        NSString *deviceIdsPath = [[self profileIdentityPath] stringByAppendingPathComponent:@"device_ids.plist"];
        NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
        if (![deviceIds isKindOfClass:[NSDictionary class]]) return nil;
        return @{
            @"version": deviceIds[@"IOSVersion"] ?: @"",
            @"build": deviceIds[@"IOSBuild"] ?: @"",
            @"darwin": deviceIds[@"Darwin"] ?: @"",
            @"xnu": deviceIds[@"XNU"] ?: @"",
            @"kernel_version": deviceIds[@"KernelVersion"] ?: @"",
            @"lastUpdated": [NSDate date]
        };
    }

    NSError *dbErr = nil;
    IPhoneModelDB *modelDB = [IPhoneModelDB sharedManager];
    IOSBuildDB *buildDB = [IOSBuildDB sharedManager];
    if (![modelDB loadIfNeeded:&dbErr] || ![buildDB loadIfNeeded:&dbErr]) {
        self.error = dbErr ?: [NSError errorWithDomain:@"com.hydra.tlinkios"
                                                  code:6009
                                              userInfo:@{NSLocalizedDescriptionKey: @"Canonical iOS database unavailable"}];
        return nil;
    }

    NSDictionary *spec = [modelDB specForProductType:deviceModel];
    if (!spec) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                         code:6010
                                     userInfo:@{NSLocalizedDescriptionKey: @"Current Device Model is not in the canonical iOS database"}];
        return nil;
    }

    NSString *minIOS = [spec[@"minIOS"] isKindOfClass:[NSString class]] ? spec[@"minIOS"] : @"13.0";
    if (PXCompareVersions(minIOS, @"13.0") == NSOrderedAscending) minIOS = @"13.0";
    NSString *maxIOS = [spec[@"maxIOS"] isKindOfClass:[NSString class]] ? spec[@"maxIOS"] : nil;
    if (PXWebCompatIOSRangeEnabled()) {
        maxIOS = PXWebCompatMaxIOSForDeviceMaxIOS(maxIOS);
    }
    if (!maxIOS.length) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                         code:6011
                                     userInfo:@{NSLocalizedDescriptionKey: @"Canonical iOS range missing for current Device Model"}];
        return nil;
    }

    NSDictionary *meta = [buildDB randomMetaForDevice:deviceModel min:(minIOS ?: @"13.0") max:maxIOS error:&dbErr];
    if (!meta) {
        self.error = dbErr ?: [NSError errorWithDomain:@"com.hydra.tlinkios"
                                                  code:6012
                                              userInfo:@{NSLocalizedDescriptionKey: @"No compatible canonical iOS build for current Device Model"}];
        return nil;
    }

    NSString *iosVersion = PXProfileString(meta[@"version"]);
    NSString *iosBuild = PXProfileString(meta[@"build"]);
    NSString *darwin = PXProfileString(meta[@"darwin"]);
    NSString *xnu = PXProfileString(meta[@"xnu"]);
    NSString *kernel = PXProfileString(meta[@"kernel_version"]);
    if (!iosVersion.length || !iosBuild.length || !darwin.length || !xnu.length || !kernel.length) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                         code:6013
                                     userInfo:@{NSLocalizedDescriptionKey: @"Canonical iOS tuple is incomplete"}];
        return nil;
    }

    NSMutableDictionary *versionDict = [@{
        @"version": iosVersion,
        @"build": iosBuild,
        @"darwin": darwin,
        @"xnu": xnu,
        @"kernel_version": kernel,
        @"lastUpdated": [NSDate date]
    } mutableCopy];

    NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
    NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: [NSMutableDictionary dictionary];
    deviceIds[@"IOSVersion"] = iosVersion;
    deviceIds[@"IOSBuild"] = iosBuild;
    deviceIds[@"Darwin"] = darwin;
    deviceIds[@"XNU"] = xnu;
    deviceIds[@"KernelVersion"] = kernel;
    if (![deviceIds writeToFile:deviceIdsPath atomically:YES]) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                         code:6014
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to persist canonical iOS tuple"}];
        return nil;
    }

    [[IOSVersionInfo sharedManager] setCurrentIOSVersionInfo:versionDict];
    PXLog(@"[WeaponX] ✅ Generated canonical iOS version for %@: %@ (%@)", deviceModel, iosVersion, iosBuild);
    return versionDict;
}

- (NSDictionary *)generateiOSVersion {
    return [self generateIOSVersion];
}

- (NSString *)generateSystemBootUUID {
    NSString *bootUUID = [[SystemUUIDManager sharedManager] generateBootUUID];
    if (!bootUUID) {
        self.error = [[SystemUUIDManager sharedManager] lastError];
        return nil;
    }
    
    // Save to profile-specific path
    NSString *identityDir = [self profileIdentityPath];
    if (identityDir) {
        NSDictionary *uuidDict = @{@"value": bootUUID, @"lastUpdated": [NSDate date]};
        NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"system_boot_uuid.plist"];
        [uuidDict writeToFile:uuidPath atomically:YES];
        
        // Also update the combined device_ids.plist
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: 
                                         [NSMutableDictionary dictionary];
        deviceIds[@"SystemBootUUID"] = bootUUID;
        [deviceIds writeToFile:deviceIdsPath atomically:YES];
        
        PXLog(@"[WeaponX] 🆔 Generated System Boot UUID: %@", bootUUID);
    }
    
    return bootUUID;
}

- (NSString *)generateDyldCacheUUID {
    NSString *dyldUUID = [[DyldCacheUUIDManager sharedManager] generateDyldCacheUUID];
    if (!dyldUUID) {
        self.error = [[DyldCacheUUIDManager sharedManager] lastError];
        return nil;
    }
    
    // Save to profile-specific path
    NSString *identityDir = [self profileIdentityPath];
    if (identityDir) {
        NSDictionary *uuidDict = @{@"value": dyldUUID, @"lastUpdated": [NSDate date]};
        NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"dyld_cache_uuid.plist"];
        [uuidDict writeToFile:uuidPath atomically:YES];
        
        // Also update the combined device_ids.plist
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: 
                                         [NSMutableDictionary dictionary];
        deviceIds[@"DyldCacheUUID"] = dyldUUID;
        [deviceIds writeToFile:deviceIdsPath atomically:YES];
        
        PXLog(@"[WeaponX] 🆔 Generated Dyld Cache UUID: %@", dyldUUID);
    }
    
    return dyldUUID;
}

- (NSString *)generatePasteboardUUID {
    NSString *pasteboardUUID = [[PasteboardUUIDManager sharedManager] generatePasteboardUUID];
    if (!pasteboardUUID) {
        self.error = [[PasteboardUUIDManager sharedManager] lastError];
        return nil;
    }
    
    // Save to profile-specific path
    NSString *identityDir = [self profileIdentityPath];
    if (identityDir) {
        NSDictionary *uuidDict = @{@"value": pasteboardUUID, @"lastUpdated": [NSDate date]};
        NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"pasteboard_uuid.plist"];
        [uuidDict writeToFile:uuidPath atomically:YES];
        
        // Also update the combined device_ids.plist
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: 
                                         [NSMutableDictionary dictionary];
        deviceIds[@"PasteboardUUID"] = pasteboardUUID;
        [deviceIds writeToFile:deviceIdsPath atomically:YES];
        
        PXLog(@"[WeaponX] 🆔 Generated Pasteboard UUID: %@", pasteboardUUID);
    }
    
    return pasteboardUUID;
}

- (NSString *)generateKeychainUUID {
    NSString *keychainUUID = [[KeychainUUIDManager sharedManager] generateKeychainUUID];
    if (!keychainUUID) {
        self.error = [[KeychainUUIDManager sharedManager] lastError];
        return nil;
    }
    
    // Save to profile-specific path
    NSString *identityDir = [self profileIdentityPath];
    if (identityDir) {
        NSDictionary *uuidDict = @{@"value": keychainUUID, @"lastUpdated": [NSDate date]};
        NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"keychain_uuid.plist"];
        [uuidDict writeToFile:uuidPath atomically:YES];
        
        // Also update the combined device_ids.plist
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: 
                                         [NSMutableDictionary dictionary];
        deviceIds[@"KeychainUUID"] = keychainUUID;
        [deviceIds writeToFile:deviceIdsPath atomically:YES];
        
        PXLog(@"[WeaponX] 🔑 Generated Keychain UUID: %@", keychainUUID);
    }
    
    return keychainUUID;
}

- (NSString *)generateUserDefaultsUUID {
    NSString *userDefaultsUUID = [[UserDefaultsUUIDManager sharedManager] generateUserDefaultsUUID];
    if (!userDefaultsUUID) {
        self.error = [[UserDefaultsUUIDManager sharedManager] lastError];
        return nil;
    }
    
    // Save to profile-specific path
    NSString *identityDir = [self profileIdentityPath];
    if (identityDir) {
        NSDictionary *uuidDict = @{@"value": userDefaultsUUID, @"lastUpdated": [NSDate date]};
        NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"userdefaults_uuid.plist"];
        [uuidDict writeToFile:uuidPath atomically:YES];
        
        // Also update the combined device_ids.plist
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: 
                                         [NSMutableDictionary dictionary];
        deviceIds[@"UserDefaultsUUID"] = userDefaultsUUID;
        [deviceIds writeToFile:deviceIdsPath atomically:YES];
        
        PXLog(@"[WeaponX] 🔄 Generated UserDefaults UUID: %@", userDefaultsUUID);
    }
    
    return userDefaultsUUID;
}

- (NSString *)generateAppGroupUUID {
    NSString *appGroupUUID = [[AppGroupUUIDManager sharedManager] generateAppGroupUUID];
    if (!appGroupUUID) {
        self.error = [[AppGroupUUIDManager sharedManager] lastError];
        return nil;
    }
    
    // Save to profile-specific path
    NSString *identityDir = [self profileIdentityPath];
    if (identityDir) {
        NSDictionary *uuidDict = @{@"value": appGroupUUID, @"lastUpdated": [NSDate date]};
        NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"appgroup_uuid.plist"];
        [uuidDict writeToFile:uuidPath atomically:YES];
        
        // Also update the combined device_ids.plist
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: 
                                         [NSMutableDictionary dictionary];
        deviceIds[@"AppGroupUUID"] = appGroupUUID;
        [deviceIds writeToFile:deviceIdsPath atomically:YES];
        
        PXLog(@"[WeaponX] 👥 Generated App Group UUID: %@", appGroupUUID);
    }
    
    return appGroupUUID;
}

- (NSString *)generateCoreDataUUID {
    NSString *coreDataUUID = [[CoreDataUUIDManager sharedManager] generateCoreDataUUID];
    if (!coreDataUUID) {
        self.error = [[CoreDataUUIDManager sharedManager] lastError];
        return nil;
    }
    
    // Save to profile-specific path
    NSString *identityDir = [self profileIdentityPath];
    if (identityDir) {
        NSDictionary *uuidDict = @{@"value": coreDataUUID, @"lastUpdated": [NSDate date]};
        NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"coredata_uuid.plist"];
        [uuidDict writeToFile:uuidPath atomically:YES];
        
        // Also update the combined device_ids.plist
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: 
                                         [NSMutableDictionary dictionary];
        deviceIds[@"CoreDataUUID"] = coreDataUUID;
        [deviceIds writeToFile:deviceIdsPath atomically:YES];
        
        PXLog(@"[WeaponX] 📦 Generated Core Data UUID: %@", coreDataUUID);
    }
    
    return coreDataUUID;
}

- (NSString *)generateSystemUptime {
    NSString *profilePath = [self profileIdentityPath];
NSTimeInterval uptime = [[UptimeManager sharedManager] currentUptimeForProfile:profilePath];
    if (uptime <= 0) {
        self.error = [[UptimeManager sharedManager] lastError];
        return nil;
    }
    
    // Save to profile-specific path
    NSString *identityDir = [self profileIdentityPath];
    if (identityDir) {
        // Format uptime as string (in seconds)
        NSString *uptimeString = [NSString stringWithFormat:@"%.0f", uptime];
        NSDictionary *uptimeDict = @{@"value": uptimeString, @"lastUpdated": [NSDate date]};
        NSString *uptimePath = [identityDir stringByAppendingPathComponent:@"system_uptime.plist"];
        [uptimeDict writeToFile:uptimePath atomically:YES];
        
        // Also update the combined device_ids.plist
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: 
                                         [NSMutableDictionary dictionary];
        deviceIds[@"SystemUptime"] = uptimeString;
        [deviceIds writeToFile:deviceIdsPath atomically:YES];
        
        PXLog(@"[WeaponX] 🕒 Generated System Uptime: %.2f hours", uptime / 3600.0);
    }
    
    // Return formatted uptime string (in hours for display)
    return [NSString stringWithFormat:@"%.2f hours", uptime / 3600.0];
}

- (NSString *)generateBootTime {
    NSString *profilePath = [self profileIdentityPath];
NSDate *bootTime = [[UptimeManager sharedManager] currentBootTimeForProfile:profilePath];
    if (!bootTime) {
        self.error = [[UptimeManager sharedManager] lastError];
        return nil;
    }
    
    // Save to profile-specific path
    NSString *identityDir = [self profileIdentityPath];
    if (identityDir) {
        NSDictionary *bootTimeDict = @{@"value": bootTime, @"lastUpdated": [NSDate date]};
        NSString *bootTimePath = [identityDir stringByAppendingPathComponent:@"boot_time.plist"];
        [bootTimeDict writeToFile:bootTimePath atomically:YES];
        
        // Also update the combined device_ids.plist
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: 
                                         [NSMutableDictionary dictionary];
        
        // Store timestamp as a string for consistency
        NSString *bootTimeString = [NSString stringWithFormat:@"%.0f", [bootTime timeIntervalSince1970]];
        deviceIds[@"BootTime"] = bootTimeString;
        [deviceIds writeToFile:deviceIdsPath atomically:YES];
        
        PXLog(@"[WeaponX] 🕒 Generated Boot Time: %@", bootTime);
    }
    
    // Return formatted date for display
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterMediumStyle;
    return [formatter stringFromDate:bootTime];
}

- (NSString *)generateAppInstallUUID {
    NSString *appInstallUUID = [[AppInstallUUIDManager sharedManager] generateAppInstallUUID];
    if (!appInstallUUID) {
        self.error = [[AppInstallUUIDManager sharedManager] lastError];
        return nil;
    }
    
    // Save to profile-specific path
    NSString *identityDir = [self profileIdentityPath];
    if (identityDir) {
        NSDictionary *uuidDict = @{@"value": appInstallUUID, @"lastUpdated": [NSDate date]};
        NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"appinstall_uuid.plist"];
        [uuidDict writeToFile:uuidPath atomically:YES];
        
        // Also update the combined device_ids.plist
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: 
                                         [NSMutableDictionary dictionary];
        deviceIds[@"AppInstallUUID"] = appInstallUUID;
        [deviceIds writeToFile:deviceIdsPath atomically:YES];
        
        PXLog(@"[WeaponX] 📱 Generated App Install UUID: %@", appInstallUUID);
    }
    
    return appInstallUUID;
}

- (NSString *)generateAppContainerUUID {
    NSString *appContainerUUID = [[AppContainerUUIDManager sharedManager] generateAppContainerUUID];
    if (!appContainerUUID) {
        self.error = [[AppContainerUUIDManager sharedManager] lastError];
        return nil;
    }
    
    // Save to profile-specific path
    NSString *identityDir = [self profileIdentityPath];
    if (identityDir) {
        NSDictionary *uuidDict = @{@"value": appContainerUUID, @"lastUpdated": [NSDate date]};
        NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"appcontainer_uuid.plist"];
        [uuidDict writeToFile:uuidPath atomically:YES];
        
        // Also update the combined device_ids.plist
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: 
                                         [NSMutableDictionary dictionary];
        deviceIds[@"AppContainerUUID"] = appContainerUUID;
        [deviceIds writeToFile:deviceIdsPath atomically:YES];
        
        PXLog(@"[WeaponX] 📦 Generated App Container UUID: %@", appContainerUUID);
    }
    
    return appContainerUUID;
}


- (BOOL)refreshCanonicalCellularIdentityForCurrentProfile {
    NSString *identityDir = [self profileIdentityPath];
    if (!identityDir.length) return NO;

    NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
    NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?:
                                     [NSMutableDictionary dictionary];
    NSString *productType = PXProfileString(deviceIds[@"DeviceModel"]);
    NSString *regulatoryModelNumber = PXProfileString(deviceIds[@"RegulatoryModelNumber"]);
    NSString *iosBuild = PXProfileString(deviceIds[@"IOSBuild"]);

    // If no coherent baseline exists yet, seed the complete group once. That
    // path also populates/clears cellular identity according to the current
    // IMEI/MEID toggles.
    if (!productType.length || !regulatoryModelNumber.length || !iosBuild.length) {
        return [self regenerateDeviceProfileGroup].length > 0;
    }

    IPhoneModelDB *modelDB = [IPhoneModelDB sharedManager];
    NSDictionary *modelSpec = [modelDB specForProductType:productType];
    if ([productType hasPrefix:@"iPhone"] && !modelSpec) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                         code:6015
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"Canonical model data is required before cellular identity can be refreshed"}];
        return NO;
    }

    NSDictionary *cellularSpec = modelSpec
        ? [modelDB cellularSpecForProductType:productType
                       regulatoryModelNumber:regulatoryModelNumber]
        : nil;
    BOOL cellularKnown = [cellularSpec[@"known"] isKindOfClass:[NSNumber class]] &&
                          [cellularSpec[@"known"] boolValue];
    BOOL cellularEnabled = cellularKnown &&
                           [cellularSpec[@"enabled"] isKindOfClass:[NSNumber class]] &&
                           [cellularSpec[@"enabled"] boolValue];
    NSDictionary *basebandMeta = nil;
    if (cellularEnabled) {
        basebandMeta = [modelDB basebandMetaForProductType:productType
                                     regulatoryModelNumber:regulatoryModelNumber
                                                  iosBuild:iosBuild];
        if (!basebandMeta.count) {
            self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                             code:6016
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                        @"Authoritative baseband metadata is unavailable for the current cellular tuple"}];
            return NO;
        }
    }

    NSError *cellularError = nil;
    if (!PXPopulateCanonicalCellularIdentity(deviceIds,
                                             cellularSpec,
                                             basebandMeta,
                                             [self isIdentifierEnabled:@"IMEI"],
                                             [self isIdentifierEnabled:@"MEID"],
                                             &cellularError)) {
        self.error = cellularError;
        return NO;
    }

    NSInteger gen = [deviceIds[@"GenerationCounter"] respondsToSelector:@selector(integerValue)]
        ? [deviceIds[@"GenerationCounter"] integerValue] : 0;
    deviceIds[@"GenerationCounter"] = @(gen + 1);
    deviceIds[@"CommittedAt"] = [NSDate date];
    if (![deviceIds writeToFile:deviceIdsPath atomically:YES]) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                         code:6017
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"Failed to persist canonical cellular identity"}];
        return NO;
    }

    PXRemoveLegacyCellularFiles(identityDir);
    return YES;
}

- (void)regenerateAllEnabledIdentifiers {
        // For WiFi info: Use the WiFiManager to generate
    Class wifiManagerClass = NSClassFromString(@"WiFiManager");
    if (wifiManagerClass && [wifiManagerClass respondsToSelector:@selector(sharedManager)]) {
        id wifiManager = [wifiManagerClass sharedManager];
        if (wifiManager && [wifiManager respondsToSelector:@selector(generateWiFiInfo)]) {
            // Generate WiFi info
            [wifiManager generateWiFiInfo];
            PXLog(@"[WeaponX] 📶 Generated WiFi information for current profile");
        }
    }
    
    // Continue with other identifiers
    if ([self isIdentifierEnabled:@"IDFA"]) {
        [self generateIDFA];
    }
    if ([self isIdentifierEnabled:@"IDFV"]) {
        [self generateIDFV];
    }
    if ([self isIdentifierEnabled:@"DeviceName"]) {
        [self generateDeviceName];
    }
    if ([self isIdentifierEnabled:@"SerialNumber"]) {
        [self generateSerialNumber];
    }
    if ([self isIdentifierEnabled:@"UDID"]) {
        [self generateUDID];
    }
    
    // Device profile group: DeviceModel + dependent specs + iOS version/build.
    // Only regenerate when at least one of the dependent identifiers is enabled.
    BOOL wantsDeviceProfileGroup = [self isIdentifierEnabled:@"DeviceModel"] || [self isIdentifierEnabled:@"IOSVersion"];
    BOOL regeneratedProfileGroup = NO;
    if (wantsDeviceProfileGroup) {
        NSString *newModel = [self regenerateDeviceProfileGroup];
        regeneratedProfileGroup = newModel.length > 0;
        if (!newModel) {
            // P0 is fail-closed: never replace a failed canonical model/build
            // resolution with independently randomized legacy model + iOS values.
            PXLog(@"[WeaponX] ❌ Device profile group generation failed; preserving the previous coherent generation");
        }
    } else {
        // Spec-dependent features (for example StorageSystem) still need a
        // coherent baseline. Seed it from the same canonical model/build group;
        // never create a hardware-only legacy model with no compatible iOS tuple.
        if (![self currentValueForIdentifier:@"DeviceModel"]) {
            regeneratedProfileGroup = [self regenerateDeviceProfileGroup].length > 0;
        }
    }

    // IMEI/MEID may be enabled even when DeviceModel/IOSVersion toggles are off.
    // Refresh against the existing tuple without selecting a new model/build.
    if (!wantsDeviceProfileGroup && !regeneratedProfileGroup &&
        ([self isIdentifierEnabled:@"IMEI"] || [self isIdentifierEnabled:@"MEID"])) {
        [self refreshCanonicalCellularIdentityForCurrentProfile];
    }
    
    // Always generate device theme if it doesn't exist
    if (![self currentValueForIdentifier:@"DeviceTheme"]) {
        NSString *deviceTheme = [self generateDeviceTheme];
        if (deviceTheme) {
            [self setCustomDeviceTheme:deviceTheme];
            PXLog(@"[WeaponX] 🎨 Generated device theme: %@", deviceTheme);
        }
    }
    
    // IOSVersion is handled by regenerateDeviceProfileGroup when enabled.
    if ([self isIdentifierEnabled:@"SystemBootUUID"]) {
        [self generateSystemBootUUID];
    }
    if ([self isIdentifierEnabled:@"DyldCacheUUID"]) {
        [self generateDyldCacheUUID];
    }
    if ([self isIdentifierEnabled:@"PasteboardUUID"]) {
        [self generatePasteboardUUID];
    }

    if ([self isIdentifierEnabled:@"KeychainUUID"]) {
        [self generateKeychainUUID];
    }
    if ([self isIdentifierEnabled:@"UserDefaultsUUID"]) {
        [self generateUserDefaultsUUID];
    }
    if ([self isIdentifierEnabled:@"AppGroupUUID"]) {
        [self generateAppGroupUUID];
    }
    if ([self isIdentifierEnabled:@"CoreDataUUID"]) {
        [self generateCoreDataUUID];
    }
    if ([self isIdentifierEnabled:@"SystemUptime"]) {
        NSString *profilePath = [self profileIdentityPath];
[[UptimeManager sharedManager] generateUptimeForProfile:profilePath];
    }
    if ([self isIdentifierEnabled:@"BootTime"]) {
        NSString *profilePath = [self profileIdentityPath];
[[UptimeManager sharedManager] generateBootTimeForProfile:profilePath];
    }
    // Even though we already generated WiFi info above, check if it's specifically enabled
    if ([self isIdentifierEnabled:@"WiFi"]) {
        // Use WiFiManager to generate new WiFi info
        id wifiManager = NSClassFromString(@"WiFiManager");
        if (wifiManager && [wifiManager respondsToSelector:@selector(sharedManager)]) {
            id sharedManager = [wifiManager sharedManager];
            if (sharedManager && [sharedManager respondsToSelector:@selector(generateWiFiInfo)]) {
                [sharedManager generateWiFiInfo];
                PXLog(@"Generated new WiFi information");
            }
        }
    }
    if ([self isIdentifierEnabled:@"StorageSystem"]) {
        // Use StorageManager to generate new storage info
        id storageManager = NSClassFromString(@"StorageManager");
        if (storageManager && [storageManager respondsToSelector:@selector(sharedManager)]) {
            id sharedManager = [storageManager sharedManager];
            if (sharedManager && [sharedManager respondsToSelector:@selector(generateStorageForCapacity:)]) {
                // Randomly choose between 64GB and 128GB
                NSString *capacity = [sharedManager respondsToSelector:@selector(randomizeStorageCapacity)] ? 
                                       [sharedManager randomizeStorageCapacity] : @"64";
                
                NSDictionary *storageInfo = [sharedManager generateStorageForCapacity:capacity];
                if (storageInfo) {
                    [sharedManager setTotalStorageCapacity:storageInfo[@"TotalStorage"]];
                    [sharedManager setFreeStorageSpace:storageInfo[@"FreeStorage"]];
                    [sharedManager setFilesystemType:storageInfo[@"FilesystemType"]];
                    PXLog(@"[WeaponX] 💾 Generated new storage information: %@ GB", storageInfo[@"TotalStorage"]);
                }
            }
        }
    }
    if ([self isIdentifierEnabled:@"Battery"]) {
        // Use BatteryManager to generate new battery info
        id batteryManager = NSClassFromString(@"BatteryManager");
        if (batteryManager && [batteryManager respondsToSelector:@selector(sharedManager)]) {
            id sharedManager = [batteryManager sharedManager];
            if (sharedManager && [sharedManager respondsToSelector:@selector(generateBatteryInfo)]) {
                NSDictionary *batteryInfo = [sharedManager generateBatteryInfo];
                if (batteryInfo) {
                    PXLog(@"[WeaponX] 🔋 Generated new battery information: %@%%", 
                         @([batteryInfo[@"BatteryLevel"] floatValue] * 100));
                }
            }
        }
    }
    // Add AppInstallUUID
    if ([self isIdentifierEnabled:@"AppInstallUUID"]) {
        [self generateAppInstallUUID];
    }
    // Add AppContainerUUID
    if ([self isIdentifierEnabled:@"AppContainerUUID"]) {
        [self generateAppContainerUUID];
    }
    // Add DeviceTheme
    if ([self isIdentifierEnabled:@"DeviceTheme"]) {
        [self generateDeviceTheme];
    }
    [self saveSettings];
}

#pragma mark - Settings Management

// Helper methods for file checks
- (BOOL)fileExistsAtPath:(NSString *)path {
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (NSDictionary *)dictionaryAtPath:(NSString *)path {
    return [NSDictionary dictionaryWithContentsOfFile:path];
}

- (void)setIdentifierEnabled:(BOOL)enabled forType:(NSString *)type {
    // Set the enabled state in settings
    self.settings[type] = @(enabled);

    // IMEI/MEID are members of the canonical cellular/baseband dependency
    // group. Refresh them against the current ProductType/A-number/IOSBuild
    // even when a legacy value already exists.
    BOOL canonicalCellularToggle = [type isEqualToString:@"IMEI"] || [type isEqualToString:@"MEID"];
    if (canonicalCellularToggle) {
        [self refreshCanonicalCellularIdentityForCurrentProfile];
    }
    
    // If enabling an identifier, check if we need to generate a value
    if (enabled) {
        // Check if a value exists
        NSString *currentValue = [self currentValueForIdentifier:type];
        if (!currentValue) {
            PXLog(@"No value exists for %@ - generating new value...", type);
            
            // Generate a value based on the identifier type
            if ([type isEqualToString:@"IDFA"]) {
                [self generateIDFA];
            } 
            else if ([type isEqualToString:@"IDFV"]) {
                [self generateIDFV];
            }
            else if ([type isEqualToString:@"DeviceName"]) {
                [self generateDeviceName];
            }
            else if ([type isEqualToString:@"SerialNumber"]) {
                [self generateSerialNumber];
            }
            else if ([type isEqualToString:@"IMEI"] || [type isEqualToString:@"MEID"]) {
                // Canonical cellular refresh above is the only production
                // generation path. Never fall back to generic TAC/MEID data.
                [self refreshCanonicalCellularIdentityForCurrentProfile];
            }
            else if ([type isEqualToString:@"UDID"]) {
                [self generateUDID];
            }
            else if ([type isEqualToString:@"IOSVersion"]) {
                // iOS version is part of the model/build/kernel dependency group.
                [self regenerateDeviceProfileGroup];
            }
            else if ([type isEqualToString:@"SystemBootUUID"]) {
                [self generateSystemBootUUID];
            }
            else if ([type isEqualToString:@"DyldCacheUUID"]) {
                [self generateDyldCacheUUID];
            }
            else if ([type isEqualToString:@"PasteboardUUID"]) {
                [self generatePasteboardUUID];
            }
            else if ([type isEqualToString:@"KeychainUUID"]) {
                [self generateKeychainUUID];
            }
            else if ([type isEqualToString:@"UserDefaultsUUID"]) {
                [self generateUserDefaultsUUID];
            }
            else if ([type isEqualToString:@"AppGroupUUID"]) {
                [self generateAppGroupUUID];
            }
            else if ([type isEqualToString:@"CoreDataUUID"]) {
                [self generateCoreDataUUID];
            }
            else if ([type isEqualToString:@"SystemUptime"]) {
                NSString *profilePath = [self profileIdentityPath];
[[UptimeManager sharedManager] generateUptimeForProfile:profilePath];
            }
            else if ([type isEqualToString:@"BootTime"]) {
                NSString *profilePath = [self profileIdentityPath];
[[UptimeManager sharedManager] generateBootTimeForProfile:profilePath];
            }
            else if ([type isEqualToString:@"WiFi"]) {
                // Use WiFiManager to generate new WiFi info
                id wifiManager = NSClassFromString(@"WiFiManager");
                if (wifiManager && [wifiManager respondsToSelector:@selector(sharedManager)]) {
                    id sharedManager = [wifiManager sharedManager];
                    if (sharedManager && [sharedManager respondsToSelector:@selector(generateWiFiInfo)]) {
                        [sharedManager generateWiFiInfo];
                        PXLog(@"Generated new WiFi information");
                    }
                }
            }
            else if ([type isEqualToString:@"StorageSystem"]) {
                // Use StorageManager to generate new storage info
                id storageManager = NSClassFromString(@"StorageManager");
                if (storageManager && [storageManager respondsToSelector:@selector(sharedManager)]) {
                    id sharedManager = [storageManager sharedManager];
                    if (sharedManager && [sharedManager respondsToSelector:@selector(generateStorageForCapacity:)]) {
                        // Randomly choose between 64GB and 128GB
                        NSString *capacity = [sharedManager respondsToSelector:@selector(randomizeStorageCapacity)] ? 
                                               [sharedManager randomizeStorageCapacity] : @"64";
                        
                        NSDictionary *storageInfo = [sharedManager generateStorageForCapacity:capacity];
                        if (storageInfo) {
                            [sharedManager setTotalStorageCapacity:storageInfo[@"TotalStorage"]];
                            [sharedManager setFreeStorageSpace:storageInfo[@"FreeStorage"]];
                            [sharedManager setFilesystemType:storageInfo[@"FilesystemType"]];
                            PXLog(@"[WeaponX] 💾 Generated new storage information: %@ GB", storageInfo[@"TotalStorage"]);
                        }
                    }
                }
            }
            else if ([type isEqualToString:@"Battery"]) {
                // Use BatteryManager to generate new battery info
                id batteryManager = NSClassFromString(@"BatteryManager");
                if (batteryManager && [batteryManager respondsToSelector:@selector(sharedManager)]) {
                    id sharedManager = [batteryManager sharedManager];
                    if (sharedManager && [sharedManager respondsToSelector:@selector(generateBatteryInfo)]) {
                        NSDictionary *batteryInfo = [sharedManager generateBatteryInfo];
                        if (batteryInfo) {
                            PXLog(@"[WeaponX] 🔋 Generated new battery information: %@%%", 
                                 @([batteryInfo[@"BatteryLevel"] floatValue] * 100));
                        }
                    }
                }
            }
            else if ([type isEqualToString:@"AppInstallUUID"]) {
                [self generateAppInstallUUID];
            }
            else if ([type isEqualToString:@"AppContainerUUID"]) {
                [self generateAppContainerUUID];
            }
            else if ([type isEqualToString:@"DeviceTheme"]) {
                NSString *theme = [self generateDeviceTheme];
                if (theme) {
                    PXLog(@"[WeaponX] 🎨 Generated device theme: %@", theme);
                }
            }
        }
    }
    
    // Always ensure a coherent canonical device profile exists. P0 must not
    // fall back to a hardware-only DeviceModel when model/build resolution fails.
    if (![self currentValueForIdentifier:@"DeviceModel"]) {
        [self regenerateDeviceProfileGroup];
    }
    
    // Persist the identifier state first. Secondary runtime settings are written only after
    // EnabledIdentifiers has been persisted, so callers never observe a secondary success
    // notification for an identifier state that failed to save.
    [self saveSettings];
    NSDictionary *persistedSettings = [NSDictionary dictionaryWithContentsOfFile:PXTLinkIOSSettingsPath()];
    NSDictionary *persistedIdentifiers = [persistedSettings[@"EnabledIdentifiers"] isKindOfClass:[NSDictionary class]]
        ? persistedSettings[@"EnabledIdentifiers"]
        : nil;
    id persistedState = persistedIdentifiers[type];
    if (persistedState == nil || [persistedState boolValue] != enabled) {
        PXLog(@"[WeaponX] Skipping secondary identifier state for %@ because EnabledIdentifiers did not persist", type);
        return;
    }

    NSString *secondaryKey = nil;
    CFStringRef notificationName = NULL;
    if ([type isEqualToString:@"WiFi"]) {
        secondaryKey = @"wifiSpoofEnabled";
        notificationName = CFSTR("com.hydra.tlinkios.toggleWifiSpoof");
    } else if ([type isEqualToString:@"Battery"]) {
        secondaryKey = @"batterySpoofEnabled";
        notificationName = CFSTR("com.hydra.tlinkios.toggleBatterySpoof");
    } else if ([type isEqualToString:@"DeviceTheme"]) {
        secondaryKey = @"deviceThemeSpoofEnabled";
        notificationName = CFSTR("com.hydra.tlinkios.toggleDeviceThemeSpoof");
    }

    if (secondaryKey) {
        NSError *secondaryError = nil;
        if (PXWriteSecurityBool(secondaryKey, enabled, &secondaryError)) {
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                               notificationName,
                                               NULL, NULL, YES);
        } else {
            self.error = secondaryError;
            PXLog(@"[WeaponX] Failed to persist secondary identifier state %@=%@: %@",
                  secondaryKey, enabled ? @"YES" : @"NO", secondaryError);
        }
    }
}

- (BOOL)setIdentifierEnabledAndPersist:(BOOL)enabled forType:(NSString *)type {
    if (![type isKindOfClass:[NSString class]] || type.length == 0) return NO;

    BOOL previous = [self.settings[type] boolValue];
    NSString *secondaryKey = nil;
    CFStringRef notificationName = NULL;
    if ([type isEqualToString:@"WiFi"]) {
        secondaryKey = @"wifiSpoofEnabled";
        notificationName = CFSTR("com.hydra.tlinkios.toggleWifiSpoof");
    } else if ([type isEqualToString:@"Battery"]) {
        secondaryKey = @"batterySpoofEnabled";
        notificationName = CFSTR("com.hydra.tlinkios.toggleBatterySpoof");
    } else if ([type isEqualToString:@"DeviceTheme"]) {
        secondaryKey = @"deviceThemeSpoofEnabled";
        notificationName = CFSTR("com.hydra.tlinkios.toggleDeviceThemeSpoof");
    }

    [self setIdentifierEnabled:enabled forType:type];

    NSDictionary *persistedSettings = [NSDictionary dictionaryWithContentsOfFile:PXTLinkIOSSettingsPath()];
    NSDictionary *enabledIdentifiers = [persistedSettings[@"EnabledIdentifiers"] isKindOfClass:[NSDictionary class]]
        ? persistedSettings[@"EnabledIdentifiers"]
        : nil;
    id persistedValue = enabledIdentifiers[type];
    BOOL primarySuccess = (persistedValue != nil && [persistedValue boolValue] == enabled);

    BOOL secondarySuccess = YES;
    if (secondaryKey) {
        id secondaryValue = PXReadSecuritySetting(secondaryKey);
        secondarySuccess = (secondaryValue != nil && [secondaryValue boolValue] == enabled);
    }

    if (primarySuccess && secondarySuccess) return YES;

    // Restore in-memory and persisted state. The rollback itself is verified best-effort;
    // callers still receive NO so the UI returns to the previously known state.
    self.settings[type] = @(previous);
    [self saveSettings];
    if (secondaryKey) {
        NSError *rollbackError = nil;
        if (PXWriteSecurityBool(secondaryKey, previous, &rollbackError)) {
            if (notificationName) {
                CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                                   notificationName,
                                                   NULL, NULL, YES);
            }
        } else {
            self.error = rollbackError;
            PXLog(@"[WeaponX] Failed to rollback secondary identifier state %@: %@", secondaryKey, rollbackError);
        }
    }

    PXLog(@"[WeaponX] Failed to persist identifier state %@=%@ (primary=%d secondary=%d); rolled back to %@",
          type, enabled ? @"YES" : @"NO", primarySuccess, secondarySuccess, previous ? @"YES" : @"NO");
    return NO;
}

- (BOOL)isIdentifierEnabled:(NSString *)type {
    if (![type isKindOfClass:NSString.class] || !type.length) return NO;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    if (!PXIdentifierManagerIsManagerProcess()) {
        // Injected host processes consume the daemon-published toggle map. A
        // persisted false remains authoritative. Only a genuinely missing key
        // may fall back to secondary flags/profile evidence to repair older
        // sparse/corrupted RootHide settings files.
        NSDictionary *runtimeSettings = PXRuntimeSnapshotTLinkSettings();
        NSDictionary *runtimeEnabled = [runtimeSettings[@"EnabledIdentifiers"] isKindOfClass:NSDictionary.class]
            ? runtimeSettings[@"EnabledIdentifiers"] : nil;
        NSString *lookupType = [type isEqualToString:@"WiFiAddress"] ? @"WiFi" : type;
        id runtimeValue = runtimeEnabled[lookupType];
        if (runtimeValue != nil) return [runtimeValue boolValue];
        return PXRuntimeSnapshotImpliesIdentifierEnabled(type);
    }
#endif
    // The TLinkIOS manager/UI process must use its live in-memory settings so a
    // just-toggled value cannot be masked by a not-yet-republished snapshot.
    NSString *lookupType = [type isEqualToString:@"WiFiAddress"] ? @"WiFi" : type;
    return [self.settings[lookupType] boolValue];
}

#pragma mark - Current Values

- (NSString *)currentValueForIdentifier:(NSString *)type {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    // Injected App Store processes cannot rely on direct rootfs access to
    // /var/mobile/Library. Consume the daemon-published jbroot snapshot first.
    // The manager must instead read the live profile being edited.
    if (!PXIdentifierManagerIsManagerProcess()) {
        PXIdentitySnapshot *runtimeSnapshot = PXCurrentIdentitySnapshot();
        if (runtimeSnapshot.valid) {
            id runtimeRawValue = runtimeSnapshot.deviceIDs[type];
            if ([runtimeRawValue isKindOfClass:NSString.class] && [(NSString *)runtimeRawValue length]) {
                return runtimeRawValue;
            }
            if ([runtimeRawValue isKindOfClass:NSNumber.class]) {
                return [(NSNumber *)runtimeRawValue stringValue];
            }
            if ([type isEqualToString:@"SystemBootUUID"]) {
                id legacy = runtimeSnapshot.deviceIDs[@"HardwareUUID"];
                if ([legacy isKindOfClass:NSString.class] && [(NSString *)legacy length]) return legacy;
            }
        }
    }
#endif
    // First try to get from profile-specific storage
    NSString *identityDir = [self profileIdentityPath];
    if (identityDir) {
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
        id rawValue = deviceIds[type];
        
        // Coerce NSNumber (e.g. LowPowerMode, ATT) to string for callers expecting NSString
        NSString *value = nil;
        if ([rawValue isKindOfClass:[NSString class]]) {
            value = (NSString *)rawValue;
        } else if ([rawValue isKindOfClass:[NSNumber class]]) {
            value = [(NSNumber *)rawValue stringValue];
        }
        
        if (value) {
            PXLog(@"Found %@ value in device_ids.plist: %@", type, value);
            return value;
        }
        
        // Canonical SystemBootUUID: one-way read fallback to legacy HardwareUUID
        if ([type isEqualToString:@"SystemBootUUID"]) {
            id legacyHW = deviceIds[@"HardwareUUID"];
            if ([legacyHW isKindOfClass:[NSString class]] && [(NSString *)legacyHW length] > 0) {
                PXLog(@"Found SystemBootUUID via legacy HardwareUUID alias (read-only): %@", legacyHW);
                return (NSString *)legacyHW;
            }
        }
        
        // If not found in combined file, try type-specific files
        if ([type isEqualToString:@"IDFA"]) {
            NSString *idfaPath = [identityDir stringByAppendingPathComponent:@"advertising_id.plist"];
            NSDictionary *idfaDict = [NSDictionary dictionaryWithContentsOfFile:idfaPath];
            if (idfaDict && idfaDict[@"value"]) {
                PXLog(@"Found IDFA in advertising_id.plist: %@", idfaDict[@"value"]);
                return idfaDict[@"value"];
            }
        } 
        else if ([type isEqualToString:@"IDFV"]) {
            NSString *idfvPath = [identityDir stringByAppendingPathComponent:@"vendor_id.plist"];
            NSDictionary *idfvDict = [NSDictionary dictionaryWithContentsOfFile:idfvPath];
            if (idfvDict && idfvDict[@"value"]) {
                PXLog(@"Found IDFV in vendor_id.plist: %@", idfvDict[@"value"]);
                return idfvDict[@"value"];
            }
        }
        else if ([type isEqualToString:@"SystemBootUUID"]) {
            NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"system_boot_uuid.plist"];
            NSDictionary *uuidDict = [NSDictionary dictionaryWithContentsOfFile:uuidPath];
            if (uuidDict && uuidDict[@"value"]) {
                PXLog(@"Found SystemBootUUID in system_boot_uuid.plist: %@", uuidDict[@"value"]);
                return uuidDict[@"value"];
            }
        }
        else if ([type isEqualToString:@"UDID"]) {
            NSString *udidPath = [identityDir stringByAppendingPathComponent:@"udid.plist"];
            NSDictionary *udidDict = [NSDictionary dictionaryWithContentsOfFile:udidPath];
            if (udidDict && udidDict[@"value"]) {
                PXLog(@"Found UDID in udid.plist: %@", udidDict[@"value"]);
                return udidDict[@"value"];
            }
        }
        else if ([type isEqualToString:@"ATTAuthorizationStatus"]) {
            NSString *trackingPath = [identityDir stringByAppendingPathComponent:@"tracking_info.plist"];
            NSDictionary *trackingDict = [NSDictionary dictionaryWithContentsOfFile:trackingPath];
            if (trackingDict && trackingDict[@"ATTAuthorizationStatus"] != nil) {
                NSString *statusStr = [trackingDict[@"ATTAuthorizationStatus"] description];
                PXLog(@"Found ATTAuthorizationStatus in tracking_info.plist: %@", statusStr);
                return statusStr;
            }
        }
        else if ([type isEqualToString:@"DyldCacheUUID"]) {
            NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"dyld_cache_uuid.plist"];
            NSDictionary *uuidDict = [NSDictionary dictionaryWithContentsOfFile:uuidPath];
            if (uuidDict && uuidDict[@"value"]) {
                PXLog(@"Found DyldCacheUUID in dyld_cache_uuid.plist: %@", uuidDict[@"value"]);
                return uuidDict[@"value"];
            }
        }
        else if ([type isEqualToString:@"PasteboardUUID"]) {
            NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"pasteboard_uuid.plist"];
            NSDictionary *uuidDict = [NSDictionary dictionaryWithContentsOfFile:uuidPath];
            if (uuidDict && uuidDict[@"value"]) {
                PXLog(@"Found PasteboardUUID in pasteboard_uuid.plist: %@", uuidDict[@"value"]);
                return uuidDict[@"value"];
            }
        }
        else if ([type isEqualToString:@"KeychainUUID"]) {
            NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"keychain_uuid.plist"];
            NSDictionary *uuidDict = [NSDictionary dictionaryWithContentsOfFile:uuidPath];
            if (uuidDict && uuidDict[@"value"]) {
                PXLog(@"Found KeychainUUID in keychain_uuid.plist: %@", uuidDict[@"value"]);
                return uuidDict[@"value"];
            }
        }
        else if ([type isEqualToString:@"UserDefaultsUUID"]) {
            NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"userdefaults_uuid.plist"];
            NSDictionary *uuidDict = [NSDictionary dictionaryWithContentsOfFile:uuidPath];
            if (uuidDict && uuidDict[@"value"]) {
                PXLog(@"Found UserDefaultsUUID in userdefaults_uuid.plist: %@", uuidDict[@"value"]);
                return uuidDict[@"value"];
            }
        }
        else if ([type isEqualToString:@"CoreDataUUID"]) {
            NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"coredata_uuid.plist"];
            NSDictionary *uuidDict = [NSDictionary dictionaryWithContentsOfFile:uuidPath];
            if (uuidDict && uuidDict[@"value"]) {
                PXLog(@"Found CoreDataUUID in coredata_uuid.plist: %@", uuidDict[@"value"]);
                return uuidDict[@"value"];
            }
        }
        else if ([type isEqualToString:@"AppInstallUUID"]) {
            NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"appinstall_uuid.plist"];
            NSDictionary *uuidDict = [NSDictionary dictionaryWithContentsOfFile:uuidPath];
            if (uuidDict && uuidDict[@"value"]) {
                PXLog(@"Found AppInstallUUID in appinstall_uuid.plist: %@", uuidDict[@"value"]);
                return uuidDict[@"value"];
            }
        }
        else if ([type isEqualToString:@"AppContainerUUID"]) {
            NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"appcontainer_uuid.plist"];
            NSDictionary *uuidDict = [NSDictionary dictionaryWithContentsOfFile:uuidPath];
            if (uuidDict && uuidDict[@"value"]) {
                PXLog(@"Found AppContainerUUID in appcontainer_uuid.plist: %@", uuidDict[@"value"]);
                return uuidDict[@"value"];
            }
        }
        else if ([type isEqualToString:@"AppGroupUUID"]) {
            NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"appgroup_uuid.plist"];
            NSDictionary *uuidDict = [NSDictionary dictionaryWithContentsOfFile:uuidPath];
            if (uuidDict && uuidDict[@"value"]) {
                PXLog(@"Found AppGroupUUID in appgroup_uuid.plist: %@", uuidDict[@"value"]);
                return uuidDict[@"value"];
            }
        }
        else if ([type isEqualToString:@"IMEI"]) {
            NSString *imeiPath = [identityDir stringByAppendingPathComponent:@"imei.plist"];
            NSDictionary *imeiDict = [NSDictionary dictionaryWithContentsOfFile:imeiPath];
            if (imeiDict && imeiDict[@"value"]) {
                PXLog(@"Found IMEI in imei.plist: %@", imeiDict[@"value"]);
                return imeiDict[@"value"];
            }
        }
        else if ([type isEqualToString:@"MEID"]) {
            NSString *meidPath = [identityDir stringByAppendingPathComponent:@"meid.plist"];
            NSDictionary *meidDict = [NSDictionary dictionaryWithContentsOfFile:meidPath];
            if (meidDict && meidDict[@"value"]) {
                PXLog(@"Found MEID in meid.plist: %@", meidDict[@"value"]);
                return meidDict[@"value"];
            }
        }
        else if ([type isEqualToString:@"DeviceName"]) {
            NSString *deviceNamePath = [identityDir stringByAppendingPathComponent:@"device_name.plist"];
            NSDictionary *deviceNameDict = [NSDictionary dictionaryWithContentsOfFile:deviceNamePath];
            if (deviceNameDict && deviceNameDict[@"value"]) {
                PXLog(@"Found DeviceName in device_name.plist: %@", deviceNameDict[@"value"]);
                return deviceNameDict[@"value"];
            }
        }
        else if ([type isEqualToString:@"SerialNumber"]) {
            NSString *serialPath = [identityDir stringByAppendingPathComponent:@"serial_number.plist"];
            NSDictionary *serialDict = [NSDictionary dictionaryWithContentsOfFile:serialPath];
            if (serialDict && serialDict[@"value"]) {
                PXLog(@"Found SerialNumber in serial_number.plist: %@", serialDict[@"value"]);
                return serialDict[@"value"];
            }
        }
        else if ([type isEqualToString:@"WiFi"]) {
            // Check for WiFi info in the profile
            NSString *wifiInfoPath = [identityDir stringByAppendingPathComponent:@"wifi_info.plist"];
            NSDictionary *wifiInfo = [NSDictionary dictionaryWithContentsOfFile:wifiInfoPath];
            if (wifiInfo && wifiInfo[@"ssid"] && wifiInfo[@"bssid"]) {
                NSString *formattedValue = [NSString stringWithFormat:@"%@ (%@)", wifiInfo[@"ssid"], wifiInfo[@"bssid"]];
                PXLog(@"Found WiFi info in wifi_info.plist: %@", formattedValue);
                return formattedValue;
            }
        }
        else if ([type isEqualToString:@"StorageSystem"]) {
            NSString *storagePath = [identityDir stringByAppendingPathComponent:@"storage.plist"];
            NSDictionary *storageDict = [NSDictionary dictionaryWithContentsOfFile:storagePath];
            if (storageDict && storageDict[@"TotalStorage"] && storageDict[@"FreeStorage"]) {
                NSString *formattedStorage = [NSString stringWithFormat:@"Total: %@ GB, Free: %@ GB", 
                                             storageDict[@"TotalStorage"], 
                                             storageDict[@"FreeStorage"]];
                PXLog(@"Found Storage info in storage.plist: %@", formattedStorage);
                return formattedStorage;
            }
        }
        else if ([type isEqualToString:@"BatteryLevel"] || [type isEqualToString:@"LowPowerMode"]) {
            NSString *batteryPath = [identityDir stringByAppendingPathComponent:@"battery_info.plist"];
            NSDictionary *batteryDict = [NSDictionary dictionaryWithContentsOfFile:batteryPath];
            if (batteryDict && batteryDict[type]) {
                PXLog(@"Found %@ in battery_info.plist: %@", type, batteryDict[type]);
                return batteryDict[type];
            }
        }
        else if ([type isEqualToString:@"SystemUptime"]) {
            NSString *profilePath = [self profileIdentityPath];
NSString *uptimePath = [profilePath stringByAppendingPathComponent:@"system_uptime.plist"];
NSDictionary *uptimeDict = [NSDictionary dictionaryWithContentsOfFile:uptimePath];
if (uptimeDict && uptimeDict[@"value"]) {
    NSTimeInterval uptime = [uptimeDict[@"value"] doubleValue];
    if (uptime > 0) {
        NSString *formattedUptime = [NSString stringWithFormat:@"%.2f hours", uptime / 3600.0];
        PXLog(@"[WeaponX] 📄 Showing SystemUptime from system_uptime.plist: %@", formattedUptime);
        return formattedUptime;
    }
}
return @"Not Set";
        }
        else if ([type isEqualToString:@"BootTime"]) {
            NSString *profilePath = [self profileIdentityPath];
NSString *bootTimePath = [profilePath stringByAppendingPathComponent:@"boot_time.plist"];
NSDictionary *bootTimeDict = [NSDictionary dictionaryWithContentsOfFile:bootTimePath];
if (bootTimeDict && bootTimeDict[@"value"]) {
    NSDate *bootTime = bootTimeDict[@"value"];
    if ([bootTime isKindOfClass:[NSDate class]]) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterMediumStyle;
        NSString *formattedBootTime = [formatter stringFromDate:bootTime];
        PXLog(@"[WeaponX] 📄 Showing BootTime from boot_time.plist: %@", formattedBootTime);
        return formattedBootTime;
    }
}
return @"Not Set";
        }
        
        PXLog(@"No %@ value found in profile-specific files", type);
    } else {
        PXLog(@"Could not access identity directory for profile");
    }
    
    // Special handling for IOS Version which returns a composite string
    if ([type isEqualToString:@"IOSVersion"]) {
        // First try to get from profile-specific storage
        NSString *identityDir = [self profileIdentityPath];
        if (identityDir) {
            // First try to get from device_ids.plist
            NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
            NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
            NSString *version = deviceIds[@"IOSVersion"];
            
            // If we have a pre-formatted version string, use it
            if (version && [version containsString:@"("]) {
                PXLog(@"[WeaponX] Found pre-formatted iOS version: %@", version);
                return version;
            }
            
            // If not pre-formatted, try to combine version and build
            NSString *build = deviceIds[@"IOSBuild"];
            if (version && build) {
                NSString *formattedVersion = [NSString stringWithFormat:@"%@ (%@)", version, build];
                PXLog(@"[WeaponX] Formatted iOS version from components: %@", formattedVersion);
                return formattedVersion;
            }
        }
        
        // Fall back to IOSVersionInfo if profile-specific value not found
        NSDictionary *currentVersion = [[IOSVersionInfo sharedManager] currentIOSVersionInfo];
        if (currentVersion && currentVersion[@"version"] && currentVersion[@"build"]) {
            NSString *formattedVersion = [NSString stringWithFormat:@"%@ (%@)", currentVersion[@"version"], currentVersion[@"build"]];
            PXLog(@"[WeaponX] Formatted iOS version from IOSVersionInfo: %@", formattedVersion);
            return formattedVersion;
        }
        
        PXLog(@"[WeaponX] No iOS version information found");
        return nil;
    }
    
    // Special handling for WiFi which needs the WiFiManager
    if ([type isEqualToString:@"WiFi"]) {
        // Try to get WiFi info from WiFiManager
        id wifiManager = NSClassFromString(@"WiFiManager");
        if (wifiManager && [wifiManager respondsToSelector:@selector(sharedManager)]) {
            id sharedManager = [wifiManager sharedManager];
            if (sharedManager) {
                // Get WiFi info based on available methods
                NSString *ssid = nil;
                NSString *bssid = nil;
                
                if ([sharedManager respondsToSelector:@selector(currentSSID)]) {
                    ssid = [sharedManager currentSSID];
                }
                
                if ([sharedManager respondsToSelector:@selector(currentBSSID)]) {
                    bssid = [sharedManager currentBSSID];
                }
                
                if (ssid && bssid) {
                    NSString *formattedValue = [NSString stringWithFormat:@"%@ (%@)", ssid, bssid];
                    PXLog(@"[WeaponX] WiFi info from WiFiManager: %@", formattedValue);
                    return formattedValue;
                } else if (ssid) {
                    PXLog(@"[WeaponX] WiFi SSID only from WiFiManager: %@", ssid);
                    return ssid;
                }
            }
        }
    }
    
    // Special handling for StorageSystem - try to get from StorageManager
    if ([type isEqualToString:@"StorageSystem"]) {
        id storageManager = NSClassFromString(@"StorageManager");
        if (storageManager && [storageManager respondsToSelector:@selector(sharedManager)]) {
            id sharedManager = [storageManager sharedManager];
            if (sharedManager) {
                NSString *totalStorage = nil;
                NSString *freeStorage = nil;
                
                if ([sharedManager respondsToSelector:@selector(totalStorageCapacity)]) {
                    totalStorage = [sharedManager totalStorageCapacity];
                }
                
                if ([sharedManager respondsToSelector:@selector(freeStorageSpace)]) {
                    freeStorage = [sharedManager freeStorageSpace];
                }
                
                if (totalStorage && freeStorage) {
                    NSString *formattedStorage = [NSString stringWithFormat:@"Total: %@ GB, Free: %@ GB", 
                                               totalStorage, freeStorage];
                    return formattedStorage;
                }
                
                // Try to generate new values if we couldn't get existing ones
                if ([sharedManager respondsToSelector:@selector(generateStorageForCapacity:)]) {
                    // Randomly choose between 64GB and 128GB
                    NSString *capacity = [sharedManager respondsToSelector:@selector(randomizeStorageCapacity)] ? 
                                           [sharedManager randomizeStorageCapacity] : @"64";
                    
                    NSDictionary *storageInfo = [sharedManager generateStorageForCapacity:capacity];
                    if (storageInfo) {
                        [sharedManager setTotalStorageCapacity:storageInfo[@"TotalStorage"]];
                        [sharedManager setFreeStorageSpace:storageInfo[@"FreeStorage"]];
                        [sharedManager setFilesystemType:storageInfo[@"FilesystemType"]];
                        
                        NSString *formattedStorage = [NSString stringWithFormat:@"Total: %@ GB, Free: %@ GB", 
                                                  storageInfo[@"TotalStorage"], 
                                                  storageInfo[@"FreeStorage"]];
                        return formattedStorage;
                    }
                }
            }
        }
        
        // Final fallback for storage - 40% chance for 64GB, 60% chance for 128GB
        BOOL use128GB = (arc4random_uniform(100) < 60);
        NSString *storageCapacity = use128GB ? @"128" : @"64";
        NSString *freeSpaceValue = use128GB ? @"38.4" : @"19.8";
        
        // Save these values to StorageManager to ensure consistency
        if (storageManager && [storageManager respondsToSelector:@selector(sharedManager)]) {
            id sharedManager = [storageManager sharedManager];
            if (sharedManager) {
                [sharedManager setTotalStorageCapacity:storageCapacity];
                [sharedManager setFreeStorageSpace:freeSpaceValue];
                [sharedManager setFilesystemType:@"0x1A"];
            }
        }
        
        return [NSString stringWithFormat:@"Total: %@ GB, Free: %@ GB", storageCapacity, freeSpaceValue];
    }
    
    // Special handling for Battery info - try to get from BatteryManager
    if ([type isEqualToString:@"BatteryLevel"] || [type isEqualToString:@"LowPowerMode"] || [type isEqualToString:@"Battery"]) {
        id batteryManager = NSClassFromString(@"BatteryManager");
        if (batteryManager && [batteryManager respondsToSelector:@selector(sharedManager)]) {
            id sharedManager = [batteryManager sharedManager];
            if (sharedManager) {
                // Force a reload from disk first to ensure fresh values
                if ([sharedManager respondsToSelector:@selector(loadBatteryInfoFromDisk)]) {
                    [sharedManager loadBatteryInfoFromDisk];
                }
                
                // Handle Battery identifier which includes both level and low power mode
                if ([type isEqualToString:@"Battery"]) {
                    if ([sharedManager respondsToSelector:@selector(batteryLevel)]) {
                        
                        // Use explicit cast to BatteryManager to avoid confusion with UIDevice method
                        NSString *level = [(BatteryManager *)sharedManager batteryLevel];
                        
                        if (level) {
                            float levelFloat = [level floatValue];
                            int percentage = (int)(levelFloat * 100);
                            
                            NSString *displayValue = [NSString stringWithFormat:@"%d%%", percentage];
                                 
                            PXLog(@"[WeaponX] 🔋 Battery info from BatteryManager: %@", displayValue);
                            return displayValue;
                        }
                    }
                    
                    // If we couldn't get both values, try to get a pre-formatted display value
                    if ([sharedManager respondsToSelector:@selector(generateBatteryInfo)]) {
                        NSDictionary *batteryInfo = [sharedManager generateBatteryInfo];
                        if (batteryInfo) {
                            // Check if we have a pre-formatted display value
                            if (batteryInfo[@"DisplayValue"]) {
                                return batteryInfo[@"DisplayValue"];
                            }
                            
                            // Otherwise, format it ourselves
                            NSString *level = batteryInfo[@"BatteryLevel"];
                            
                            if (level) {
                                float levelFloat = [level floatValue];
                                int percentage = (int)(levelFloat * 100);
                                
                                NSString *displayValue = [NSString stringWithFormat:@"%d%%", percentage];
                                     
                                PXLog(@"[WeaponX] 🔋 Generated battery info: %@", displayValue);
                                return displayValue;
                            }
                        }
                    }
                } 
                // Handle individual battery values
                else if ([type isEqualToString:@"BatteryLevel"] && [sharedManager respondsToSelector:@selector(batteryLevel)]) {
                    NSString *level = [(BatteryManager *)sharedManager batteryLevel];
                    if (level) {
                        PXLog(@"[WeaponX] 🔋 Battery level from BatteryManager: %@", level);
                        return level;
                    }
                }
                else if ([type isEqualToString:@"LowPowerMode"] && [sharedManager respondsToSelector:@selector(lowPowerModeEnabled)]) {
                    BOOL lpm = [(BatteryManager *)sharedManager lowPowerModeEnabled];
                    NSString *lpmStr = lpm ? @"1" : @"0";
                    PXLog(@"[WeaponX] 🔋 LowPowerMode from BatteryManager: %@", lpmStr);
                    return lpmStr;
                }
            }
        }
    }
    
    // Special handling for SystemUptime/BootTime
    if ([type isEqualToString:@"SystemUptime"]) {
        NSString *profilePath = [self profileIdentityPath];
NSTimeInterval uptime = [[UptimeManager sharedManager] currentUptimeForProfile:profilePath];
        NSString *result = [NSString stringWithFormat:@"%.2f hours", uptime / 3600.0];
        PXLog(@"Default SystemUptime value: %@", result);
        return result;
    }
    else if ([type isEqualToString:@"BootTime"]) {
        NSString *profilePath = [self profileIdentityPath];
NSDate *bootTime = [[UptimeManager sharedManager] currentBootTimeForProfile:profilePath];
        if (!bootTime) {
            PXLog(@"Default BootTime value: Not Set");
            return @"Not Set";
        }
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterMediumStyle;
        NSString *result = [formatter stringFromDate:bootTime];
        PXLog(@"Default BootTime value: %@", result);
        return result;
    }
    
    // Fallback to the original implementation if profile-specific value not found
    PXLog(@"Falling back to default implementation for %@", type);
    if ([type isEqualToString:@"IDFA"]) {
        NSString *result = [[IDFAManager sharedManager] currentIDFA];
        PXLog(@"Default IDFA value: %@", result ?: @"nil");
        return result;
    } else if ([type isEqualToString:@"IDFV"]) {
        NSString *result = [[IDFVManager sharedManager] currentIDFV];
        PXLog(@"Default IDFV value: %@", result ?: @"nil");
        return result;
    } else if ([type isEqualToString:@"SystemBootUUID"]) {
        NSString *result = [[SystemUUIDManager sharedManager] currentBootUUID];
        PXLog(@"Default SystemBootUUID value: %@", result ?: @"nil");
        return result;
    } else if ([type isEqualToString:@"DyldCacheUUID"]) {
        NSString *result = [[DyldCacheUUIDManager sharedManager] currentDyldCacheUUID];
        PXLog(@"Default DyldCacheUUID value: %@", result ?: @"nil");
        return result;
    } else if ([type isEqualToString:@"PasteboardUUID"]) {
        NSString *result = [[PasteboardUUIDManager sharedManager] currentPasteboardUUID];
        PXLog(@"Default PasteboardUUID value: %@", result ?: @"nil");
        return result;
    } else if ([type isEqualToString:@"KeychainUUID"]) {
        NSString *result = [[KeychainUUIDManager sharedManager] currentKeychainUUID];
        PXLog(@"Default KeychainUUID value: %@", result ?: @"nil");
        return result;
    } else if ([type isEqualToString:@"UserDefaultsUUID"]) {
        NSString *result = [[UserDefaultsUUIDManager sharedManager] currentUserDefaultsUUID];
        PXLog(@"Default UserDefaultsUUID value: %@", result ?: @"nil");
        return result;
    } else if ([type isEqualToString:@"AppGroupUUID"]) {
        NSString *result = [[AppGroupUUIDManager sharedManager] currentAppGroupUUID];
        PXLog(@"Default AppGroupUUID value: %@", result ?: @"nil");
        return result;
    } else if ([type isEqualToString:@"CoreDataUUID"]) {
        NSString *result = [[CoreDataUUIDManager sharedManager] currentCoreDataUUID];
        PXLog(@"Default CoreDataUUID value: %@", result ?: @"nil");
        return result;
    } else if ([type isEqualToString:@"AppInstallUUID"]) {
        NSString *result = [[AppInstallUUIDManager sharedManager] currentAppInstallUUID];
        PXLog(@"Default AppInstallUUID value: %@", result ?: @"nil");
        return result;
    } else if ([type isEqualToString:@"AppContainerUUID"]) {
        NSString *result = [[AppContainerUUIDManager sharedManager] currentAppContainerUUID];
        PXLog(@"Default AppContainerUUID value: %@", result ?: @"nil");
        return result;
    } else if ([type isEqualToString:@"DeviceName"]) {
        NSString *result = [[DeviceNameManager sharedManager] currentDeviceName];
        PXLog(@"Default DeviceName value: %@", result ?: @"nil");
        return result;
    } else if ([type isEqualToString:@"SerialNumber"]) {
        NSString *result = [[SerialNumberManager sharedManager] currentSerialNumber];
        PXLog(@"Default SerialNumber value: %@", result ?: @"nil");
        return result;
    }
    
    PXLog(@"No value found for %@", type);
    return nil;
}

#pragma mark - App Management

- (void)refreshScopedAppsInfoIfNeeded {
    // Iterate through all scoped apps and update their version/build info
    for (NSString *bundleID in self.scopedApps) {
        LSApplicationProxy *appProxy = [LSApplicationProxy applicationProxyForIdentifier:bundleID];
        if (appProxy) {
            NSString *currentVersion = appProxy.shortVersionString;
            NSString *currentBuild = appProxy.bundleVersion ?: @"";
            NSMutableDictionary *appInfo = self.scopedApps[bundleID];
            BOOL needsUpdate = ![appInfo[@"version"] isEqualToString:currentVersion] ||
                               ![appInfo[@"build"] isEqualToString:currentBuild];
            if (needsUpdate) {
                appInfo[@"version"] = currentVersion ?: @"";
                appInfo[@"build"] = currentBuild ?: @"";
            }
        }
    }
    [self saveSettings];
}

- (void)addApplicationToScope:(NSString *)bundleID {
    if (!bundleID.length) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                       code:3001 
                                   userInfo:@{NSLocalizedDescriptionKey: @"Invalid bundle ID"}];
        return;
    }
    
    // Prevent the WeaponX app itself from being added to the scope list
    if ([bundleID isEqualToString:@"com.hydra.tlinkios"]) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                       code:3003 
                                   userInfo:@{NSLocalizedDescriptionKey: @"Cannot add the WeaponX app itself to the scope list"}];
        PXLog(@"[WeaponX] ⚠️ Prevented attempt to add the WeaponX app to the scope list");
        return;
    }
    
    // Get app info using LSApplicationProxy
    LSApplicationProxy *appProxy = [LSApplicationProxy applicationProxyForIdentifier:bundleID];
    
    NSMutableDictionary *appInfo = [NSMutableDictionary dictionary];
    appInfo[@"name"] = appProxy.localizedName ?: bundleID;
    appInfo[@"version"] = appProxy.shortVersionString ?: (appProxy ? @"Unknown" : @"Helper/Extension");
    NSString *buildVersion = nil;
    if (appProxy) {
        id proxy = (id)appProxy;
        if ([proxy respondsToSelector:@selector(bundleVersion)]) {
            buildVersion = [proxy performSelector:@selector(bundleVersion)];
        } else if ([proxy respondsToSelector:@selector(valueForKey:)]) {
            buildVersion = [proxy valueForKey:@"bundleVersion"];
            if (!buildVersion) {
                buildVersion = [proxy valueForKey:@"CFBundleVersion"];
            }
        }
    }
    appInfo[@"build"] = buildVersion ?: @"Unknown";  // Add build number
    appInfo[@"installed"] = @YES;
    appInfo[@"enabled"] = @YES;
    
    // Store using the original case-sensitive bundle ID
    appInfo[@"bundleID"] = bundleID;
    appInfo[@"originalBundleID"] = bundleID;  // Store original case-sensitive version
    
    // Use the original case-sensitive bundle ID as the dictionary key
    self.scopedApps[bundleID] = appInfo;
    [self saveSettings];
}

- (void)removeApplicationFromScope:(NSString *)bundleID {
    [self.scopedApps removeObjectForKey:bundleID];
    [self saveSettings];
}

- (void)setApplication:(NSString *)bundleID enabled:(BOOL)enabled {
    NSMutableDictionary *appInfo = [self.scopedApps[bundleID] mutableCopy];
    if (appInfo) {
        appInfo[@"enabled"] = @(enabled);
        self.scopedApps[bundleID] = appInfo;
        [self saveSettings];
    }
}

- (BOOL)replaceApplicationScopeWithBundleIDs:(NSArray<NSString *> *)bundleIDs {
    self.error = nil;
    NSMutableOrderedSet<NSString *> *normalized = [NSMutableOrderedSet orderedSet];
    for (id value in bundleIDs ?: @[]) {
        if (![value isKindOfClass:NSString.class] || ![(NSString *)value length]) continue;
        NSString *bundleID = (NSString *)value;
        if ([bundleID isEqualToString:@"com.hydra.tlinkios"] ||
            [bundleID isEqualToString:@"com.hydra.weaponx"] ||
            [bundleID isEqualToString:@"com.hydra.projectx"]) continue;
        [normalized addObject:bundleID];
    }

    NSMutableDictionary *replacement = [NSMutableDictionary dictionaryWithCapacity:normalized.count];
    for (NSString *bundleID in normalized) {
        NSMutableDictionary *appInfo = [self.scopedApps[bundleID] mutableCopy];
        if (!appInfo) {
            LSApplicationProxy *proxy = [LSApplicationProxy applicationProxyForIdentifier:bundleID];
            // bundleVersion is part of the local private-framework declaration
            // above and is already used by refreshScopedAppsInfoIfNeeded. Calling
            // that typed property keeps RootHide's stricter compiler from trying
            // to resolve NSObject runtime/KVC selectors on a forward-only class.
            NSString *buildVersion = proxy.bundleVersion;
            appInfo = [@{
                @"name": proxy.localizedName ?: bundleID,
                @"version": proxy.shortVersionString ?: (proxy ? @"Unknown" : @"Helper/Extension"),
                @"build": buildVersion ?: @"Unknown",
                @"installed": @YES,
                @"bundleID": bundleID,
                @"originalBundleID": bundleID
            } mutableCopy];
        }
        appInfo[@"enabled"] = @YES;
        appInfo[@"bundleID"] = bundleID;
        appInfo[@"originalBundleID"] = bundleID;
        replacement[bundleID] = appInfo;
    }

    if ([self.scopedApps isEqualToDictionary:replacement]) return YES;
    self.scopedApps = replacement;
    [self saveScopedApps];
    return self.error == nil;
}

- (NSDictionary *)getApplicationInfo:(NSString *)bundleID {
    if (bundleID) {
        NSDictionary *appInfo = self.scopedApps[bundleID];
        if (appInfo) {
            return [appInfo mutableCopy];
        }
        return nil;
    }
    
    // Return all apps with their original case-preserved bundle IDs
    NSMutableDictionary *displayApps = [NSMutableDictionary dictionary];
    [self.scopedApps enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *appInfo, BOOL *stop) {
        NSMutableDictionary *displayInfo = [appInfo mutableCopy];
        NSString *originalBundleID = appInfo[@"originalBundleID"];
        if (originalBundleID) {
            // Use the original case-sensitive bundle ID
            displayInfo[@"bundleID"] = originalBundleID;
            displayApps[key] = displayInfo;
        } else {
            displayApps[key] = displayInfo;
        }
    }];
    return displayApps;
}

// Cache for application enabled status to reduce frequent lookups and logging
static NSMutableDictionary *_appEnabledCache = nil;
static NSTimeInterval _cacheExpirationTime = 30.0; // Cache results for 30 seconds

- (BOOL)isApplicationEnabled:(NSString *)bundleID {
    // Initialize cache if needed
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _appEnabledCache = [NSMutableDictionary dictionary];
    });
    
    // Check if we have a cached result that's still valid
    NSDictionary *cachedResult = _appEnabledCache[bundleID];
    if (cachedResult) {
        NSTimeInterval timestamp = [cachedResult[@"timestamp"] doubleValue];
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        
        // If the cache hasn't expired, use it
        if (now - timestamp < _cacheExpirationTime) {
            return [cachedResult[@"enabled"] boolValue];
        }
    }
    
    // Only log once every 30 seconds per app to avoid spamming logs
    static NSString *lastLoggedApp = nil;
    static NSTimeInterval lastLogTime = 0;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    BOOL shouldLog = ![lastLoggedApp isEqualToString:bundleID] || (now - lastLogTime > 30.0);
    
    if (shouldLog) {
        PXLog(@"[WeaponX] IdentifierManager DEBUG: Checking if app is enabled: %@", bundleID);
        lastLoggedApp = [bundleID copy];
        lastLogTime = now;
    }
    
    // Never consider the WeaponX app itself as enabled for spoofing
    if ([bundleID isEqualToString:@"com.hydra.tlinkios"]) {
        if (shouldLog) {
            PXLog(@"[WeaponX] IdentifierManager DEBUG: WeaponX app itself is never considered enabled for spoofing");
        }
        
        // Cache the result
        _appEnabledCache[bundleID] = @{@"enabled": @NO, @"timestamp": @(now)};
        return NO;
    }
    
    // Direct equality check first for performance
    if (self.scopedApps[bundleID]) {
        BOOL isEnabled = [self.scopedApps[bundleID][@"enabled"] boolValue];
        
        if (shouldLog) {
            PXLog(@"[WeaponX] IdentifierManager DEBUG: Found app %@ in scopedApps, enabled = %@", bundleID, isEnabled ? @"YES" : @"NO");
        }
        
        // Cache the result
        _appEnabledCache[bundleID] = @{@"enabled": @(isEnabled), @"timestamp": @(now)};
        return isEnabled;
    }
    
    // Ensure we have the latest scoped apps data
    // Only reload scoped apps if we haven't reloaded recently
    static NSTimeInterval lastReloadTime = 0;
    if (now - lastReloadTime > 60.0) { // Only reload every minute at most
        if (shouldLog) {
            PXLog(@"[WeaponX] IdentifierManager DEBUG: App not found directly, reloading scoped apps");
        }
        [self loadScopedApps];
        lastReloadTime = now;
    }
    
    // Check again after potentially reloading the scoped apps
    if (self.scopedApps[bundleID]) {
        BOOL isEnabled = [self.scopedApps[bundleID][@"enabled"] boolValue];
        
        if (shouldLog) {
            PXLog(@"[WeaponX] IdentifierManager DEBUG: Found app %@ after reload, enabled = %@", bundleID, isEnabled ? @"YES" : @"NO");
        }
        
        // Cache the result
        _appEnabledCache[bundleID] = @{@"enabled": @(isEnabled), @"timestamp": @(now)};
        return isEnabled;
    }
    
    // Fallback to case-insensitive comparison if needed (this is expensive, so only log if needed)
    if (shouldLog) {
        PXLog(@"[WeaponX] IdentifierManager DEBUG: App still not found, trying case-insensitive match");
    }
    
    NSString *lowercaseBundleID = [bundleID lowercaseString];
    for (NSString *key in self.scopedApps) {
        if ([[key lowercaseString] isEqualToString:lowercaseBundleID]) {
            BOOL isEnabled = [self.scopedApps[key][@"enabled"] boolValue];
            
            if (shouldLog) {
                PXLog(@"[WeaponX] IdentifierManager DEBUG: Found app %@ via case-insensitive match with %@, enabled = %@", 
                      bundleID, key, isEnabled ? @"YES" : @"NO");
            }
            
            // Cache the result using the original bundle ID
            _appEnabledCache[bundleID] = @{@"enabled": @(isEnabled), @"timestamp": @(now)};
            return isEnabled;
        }
    }
    
    // App not found, only log this information sparingly
    if (shouldLog) {
        // Limit the keys we log to avoid excessive memory usage
        NSArray *allKeys = [self.scopedApps allKeys];
        NSArray *limitedKeys = allKeys.count > 10 ? [allKeys subarrayWithRange:NSMakeRange(0, 10)] : allKeys;
        
        PXLog(@"[WeaponX] IdentifierManager DEBUG: App %@ not found in scoped apps list", bundleID);
        PXLog(@"[WeaponX] IdentifierManager DEBUG: First %lu scoped apps: %@", (unsigned long)limitedKeys.count, limitedKeys);
    }
    
    // Cache the negative result
    _appEnabledCache[bundleID] = @{@"enabled": @NO, @"timestamp": @(now)};
    
    return NO;
}

// New method to load scoped apps configuration explicitly
- (void)loadScopedApps {
    NSString *scopedAppsFile = PXGlobalScopePath();
    PXLog(@"[WeaponX] IdentifierManager DEBUG: Trying to load scoped apps from: %@", scopedAppsFile);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    PXLog(@"[WeaponX] IdentifierManager DEBUG: Loading scoped apps from: %@", scopedAppsFile);
    PXLog(@"[WeaponX] IdentifierManager DEBUG: File exists: %@", [fileManager fileExistsAtPath:scopedAppsFile] ? @"YES" : @"NO");
    
    // Load scoped apps from the global scope file
    NSDictionary *scopedAppsDict = [NSDictionary dictionaryWithContentsOfFile:scopedAppsFile];
    PXLog(@"[WeaponX] IdentifierManager DEBUG: Loaded dictionary: %@", scopedAppsDict ? @"YES" : @"NO");
    
    NSDictionary *savedApps = scopedAppsDict[@"ScopedApps"];
    PXLog(@"[WeaponX] IdentifierManager DEBUG: Scoped apps entry found in dictionary: %@", savedApps ? @"YES" : @"NO");
    
    if (savedApps) {
        PXLog(@"[WeaponX] IdentifierManager DEBUG: Number of scoped apps found: %lu", (unsigned long)savedApps.count);
        if (savedApps.count > 0) {
            PXLog(@"[WeaponX] IdentifierManager DEBUG: App list includes: %@", [savedApps allKeys]);
        }
        // Make sure we properly update the scoped apps dictionary
        if (!self.scopedApps) {
            self.scopedApps = [savedApps mutableCopy];
        } else {
            [self.scopedApps setDictionary:savedApps];
        }
        PXLog(@"[WeaponX] IdentifierManager: Loaded %lu scoped apps from %@", (unsigned long)savedApps.count, scopedAppsFile);
    } else {
        // Re-initialize the app list if loading failed
        if (!self.scopedApps) {
            self.scopedApps = [NSMutableDictionary dictionary];
        } else {
            [self.scopedApps removeAllObjects];
        }
        PXLog(@"[WeaponX] IdentifierManager: ⚠️ Failed to load scoped apps, using empty list");
    }
}

#pragma mark - Persistence

- (void)saveSettings {
    // Get the proper preferences path
    NSString *prefsPath = PXPreferencesPath();
    NSString *prefsFile = PXTLinkIOSSettingsPath();
    
    // Global settings file for scoped apps (universal across all profiles)
    NSString *scopedAppsFile = PXGlobalScopePath();
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Ensure preferences directory exists with proper permissions
    NSError *dirError = nil;
    
    // Create all intermediate directories with proper permissions
    if (![fileManager fileExistsAtPath:prefsPath]) {
        NSDictionary *attributes = @{NSFilePosixPermissions: @0755,
                                    NSFileOwnerAccountName: @"mobile"};
        
        if (![fileManager createDirectoryAtPath:prefsPath 
                    withIntermediateDirectories:YES 
                                     attributes:attributes
                                          error:&dirError]) {
            self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                            code:4004 
                                        userInfo:@{NSLocalizedDescriptionKey: 
                                                  [NSString stringWithFormat:@"Failed to create preferences directory: %@", 
                                                   dirError.localizedDescription]}];
            return;
        }
    }
    
    // Preserve top-level NSUserDefaults-backed feature flags (for example
    // StorageSystemEnabled) instead of replacing the whole suite plist. Only
    // the canonical identifier toggles belong under EnabledIdentifiers.
    NSMutableDictionary *saveDict = [NSMutableDictionary dictionaryWithContentsOfFile:prefsFile] ?: [NSMutableDictionary dictionary];
    saveDict[@"EnabledIdentifiers"] = PXSanitizedIdentifierSettings(self.settings);
    // Keep the legacy top-level storage flag synchronized in the same atomic
    // write. Rootful StorageManager and older RootHide snapshots still consult
    // this key, while current hooks prefer EnabledIdentifiers.StorageSystem.
    if (self.settings[@"StorageSystem"] != nil) {
        saveDict[@"StorageSystemEnabled"] = @([self.settings[@"StorageSystem"] boolValue]);
    }
    saveDict[@"SettingsInitialized"] = @YES;
    
    // Save main settings
    BOOL success = [saveDict writeToFile:prefsFile atomically:YES];
    if (!success) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                      code:4005 
                                  userInfo:@{NSLocalizedDescriptionKey: @"Failed to save settings"}];
        return;
    }
    
    // Save scoped apps separately in the global scope file
    NSDictionary *scopedAppsDict = @{@"ScopedApps": [self.scopedApps copy]};
    success = [scopedAppsDict writeToFile:scopedAppsFile atomically:YES];
    if (!success) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                      code:4006 
                                  userInfo:@{NSLocalizedDescriptionKey: @"Failed to save global scoped apps"}];
        PXLog(@"[WeaponX] ❌ Failed to save global scoped apps to: %@", scopedAppsFile);
        return;
    } else {
        PXLog(@"[WeaponX] ✅ Saved scoped apps to: %@", scopedAppsFile);
    }

    [self.spoofCache removeAllObjects];
    [_appEnabledCache removeAllObjects];
    PXPostSettingsChangedNotification();
}
    


- (void)loadSettings {
    PXLog(@"[WeaponX] Loading settings...");
    
    NSString *prefsFile = PXTLinkIOSSettingsPath();
    NSString *scopedAppsFile = PXGlobalScopePath();
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:prefsFile]) {
        PXLog(@"[WeaponX] Settings not found at default path: %@", prefsFile);
        NSString *legacyPrefsFile = [PXPreferencesPath() stringByAppendingPathComponent:@"com.hydra.tlinkios.plist"];
        if ([fileManager fileExistsAtPath:legacyPrefsFile]) {
            prefsFile = legacyPrefsFile;
            PXLog(@"[WeaponX] Checking fallback legacy path: %@", prefsFile);
        }
    }
    
    PXLog(@"[WeaponX] Final settings file path: %@", prefsFile);
    PXLog(@"[WeaponX] Final scoped apps file path: %@", scopedAppsFile);

    // Sandboxed injected apps consume the RootHide runtime mirror. The manager
    // app itself must read the live settings file so a freshly toggled value is
    // never masked by a not-yet-republished snapshot.
    NSDictionary *loadedDict = nil;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    if (!PXIdentifierManagerIsManagerProcess()) {
        NSDictionary *runtimeTLinkSettings = PXRuntimeSnapshotTLinkSettings();
        if (runtimeTLinkSettings.count) loadedDict = runtimeTLinkSettings;
    }
#endif
    if (!loadedDict) loadedDict = [NSDictionary dictionaryWithContentsOfFile:prefsFile];
    if (loadedDict) {
        PXLog(@"[WeaponX] Successfully loaded settings dictionary.");
    } else {
        PXLog(@"[WeaponX] Failed to load settings dictionary (file may imply empty or permission denied?)");
    }

    // Check if settings are initialized
    if (!loadedDict || ![loadedDict[@"SettingsInitialized"] boolValue]) {
        // Initialize with default values
        PXLog(@"[WeaponX] Settings not initialized, using defaults.");
        self.settings = [NSMutableDictionary dictionaryWithDictionary:@{
            @"IDFA": @NO,
            @"IDFV": @NO,
            @"DeviceName": @NO,
            @"SerialNumber": @NO,
            @"UDID": @NO,
            @"IMEI": @NO,
            @"MEID": @NO,
            @"IOSVersion": @NO,
            @"StorageSystem": @NO,
            @"SystemBootUUID": @NO,
            @"DyldCacheUUID": @NO,
            @"PasteboardUUID": @NO,
            @"KeychainUUID": @NO,
            @"UserDefaultsUUID": @NO,
            @"AppGroupUUID": @NO,
            @"CoreDataUUID": @NO,
            @"AppInstallUUID": @NO,
            @"AppContainerUUID": @NO
        }];
    } else {
        // ✅ FIX: Load from the EnabledIdentifiers key, not the entire dictionary
        NSDictionary *enabledIdentifiers = loadedDict[@"EnabledIdentifiers"];
        if ([enabledIdentifiers isKindOfClass:NSDictionary.class]) {
            NSMutableDictionary *normalized = [PXSanitizedIdentifierSettings(enabledIdentifiers) mutableCopy];
            if (!normalized) normalized = [NSMutableDictionary dictionary];
            if (normalized[@"IOSVersion"] == nil) {
                id legacyIOS = enabledIdentifiers[@"SystemVersion"] ?: enabledIdentifiers[@"BuildVersion"];
                if ([legacyIOS respondsToSelector:@selector(boolValue)]) {
                    normalized[@"IOSVersion"] = @([legacyIOS boolValue]);
                }
            }

            // One-way compatibility repair for settings written by older builds.
            // Only fill a missing primary key from an existing secondary flag;
            // never override an explicit false in EnabledIdentifiers.
            if (normalized[@"StorageSystem"] == nil) {
                id storageEnabled = loadedDict[@"StorageSystemEnabled"];
                if (storageEnabled == nil) {
                    NSUserDefaults *suite = [[NSUserDefaults alloc] initWithSuiteName:@"com.hydra.tlinkios.settings"];
                    storageEnabled = [suite objectForKey:@"StorageSystemEnabled"];
                }
                if ([storageEnabled respondsToSelector:@selector(boolValue)]) {
                    normalized[@"StorageSystem"] = @([storageEnabled boolValue]);
                }
            }
            NSDictionary<NSString *, NSString *> *secondaryKeys = @{
                @"WiFi": @"wifiSpoofEnabled",
                @"Battery": @"batterySpoofEnabled",
                @"DeviceTheme": @"deviceThemeSpoofEnabled"
            };
            [secondaryKeys enumerateKeysAndObjectsUsingBlock:^(NSString *primaryKey, NSString *secondaryKey, BOOL *stop) {
                (void)stop;
                if (normalized[primaryKey] != nil) return;
                id secondaryValue = PXReadSecuritySetting(secondaryKey);
                if ([secondaryValue respondsToSelector:@selector(boolValue)]) {
                    normalized[primaryKey] = @([secondaryValue boolValue]);
                }
            }];

            self.settings = normalized;
            PXLog(@"[WeaponX] ✅ Loaded %lu canonical identifier settings from EnabledIdentifiers", (unsigned long)self.settings.count);
        } else {
            PXLog(@"[WeaponX] ⚠️ EnabledIdentifiers key not found, using defaults");
            self.settings = [NSMutableDictionary dictionaryWithDictionary:@{
                @"IDFA": @NO,
                @"IDFV": @NO,
                @"DeviceName": @NO,
                @"SerialNumber": @NO,
                @"UDID": @NO,
                @"IMEI": @NO,
                @"MEID": @NO,
                @"IOSVersion": @NO
            }];
        }
    }
    
    // Load scoped apps from the same RootHide runtime publication when
    // available so scope and identity belong to one daemon-owned generation.
    NSDictionary *scopedAppsDict = nil;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    if (!PXIdentifierManagerIsManagerProcess()) {
        NSDictionary *runtimeScope = PXRuntimeSnapshotGlobalScope();
        if (runtimeScope.count) scopedAppsDict = runtimeScope;
    }
#endif
    if (!scopedAppsDict) scopedAppsDict = [NSDictionary dictionaryWithContentsOfFile:scopedAppsFile];
    if (scopedAppsDict && scopedAppsDict[@"ScopedApps"]) {
        self.scopedApps = [scopedAppsDict[@"ScopedApps"] mutableCopy];
        PXLog(@"[WeaponX] Loaded Scoped Apps: %lu apps found.", (unsigned long)self.scopedApps.count);
        for (NSString *appID in self.scopedApps) {
            PXLog(@"[WeaponX] Scope App: %@ | Enabled: %@", appID, self.scopedApps[appID][@"enabled"]);
        }
    } else {
        PXLog(@"[WeaponX] No ScopedApps found or failed to load scoped apps file.");
        self.scopedApps = [NSMutableDictionary dictionary];
    }
}

#pragma mark - Error Handling

- (NSError *)lastError {
    return self.error;
}

- (NSString *)generateWiFiInformation {
    // Use WiFiManager to generate new WiFi info
    id wifiManager = NSClassFromString(@"WiFiManager");
    if (wifiManager && [wifiManager respondsToSelector:@selector(sharedManager)]) {
        id sharedManager = [wifiManager sharedManager];
        if (sharedManager && [sharedManager respondsToSelector:@selector(generateWiFiInfo)]) {
            NSDictionary *wifiInfo = [sharedManager generateWiFiInfo];
            if (wifiInfo && wifiInfo[@"ssid"] && wifiInfo[@"bssid"]) {
                NSString *formattedValue = [NSString stringWithFormat:@"%@ (%@)", wifiInfo[@"ssid"], wifiInfo[@"bssid"]];
                PXLog(@"Generated new WiFi information: %@", formattedValue);
                return formattedValue;
            }
        }
    }
    
    PXLog(@"Failed to generate WiFi information");
    return nil;
}

- (NSArray *)availableIdentifiers {
    // Return all available identifiers
    NSArray *identifiers = @[
        @"IDFA",
        @"IDFV",
        @"DeviceName",
        @"SerialNumber",
        @"UDID",
        @"IMEI",
        @"MEID",
        @"IOSVersion",
        @"WiFi",
        @"StorageSystem",
        @"Battery",
        @"SystemBootUUID",
        @"DyldCacheUUID",
        @"PasteboardUUID",
        @"KeychainUUID",
        @"UserDefaultsUUID",
        @"AppGroupUUID",
        @"CoreDataUUID",
        @"AppInstallUUID",
        @"AppContainerUUID",
        @"SystemUptime",
        @"BootTime"
    ];
    
    return identifiers;
}

- (void)addApplicationWithExtensionsToScope:(NSString *)bundleID {
    if (!bundleID || [bundleID isEqualToString:@"com.hydra.tlinkios"]) {
        return;
    }
    [self addApplicationToScope:bundleID];
    PXLog(@"[WeaponX] Added app to scope without wildcard extension pattern: %@", bundleID);
}

- (BOOL)isBundleIDMatch:(NSString *)targetBundleID withPattern:(NSString *)patternBundleID {
    if (!targetBundleID || !patternBundleID) return NO;
    
    // Convert pattern to regex, escaping all dots except the wildcard
    NSString *regexPattern = [patternBundleID stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
    regexPattern = [regexPattern stringByReplacingOccurrencesOfString:@"\\.*" withString:@".*"];
    regexPattern = [NSString stringWithFormat:@"^%@$", regexPattern];
    
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexPattern
                                                                         options:NSRegularExpressionCaseInsensitive
                                                                           error:&error];
    if (error) {
        PXLog(@"[WeaponX] Error creating regex for pattern %@: %@", patternBundleID, error);
        return NO;
    }
    
    NSRange range = NSMakeRange(0, targetBundleID.length);
    NSTextCheckingResult *match = [regex firstMatchInString:targetBundleID options:0 range:range];
    
    BOOL matches = (match != nil);
    if (matches) {
        PXLog(@"[WeaponX] Bundle ID: %@ matches pattern: %@", targetBundleID, patternBundleID);
    }
    
    return matches;
}

- (BOOL)shouldSpoofForBundle:(NSString *)bundleID {
    if (!bundleID) return NO;
    
    // Check cache first
    NSNumber *cachedDecision = self.spoofCache[bundleID];
    NSDate *cachedAt = self.spoofCache[[bundleID stringByAppendingString:@"_timestamp"]];
    if (cachedDecision && [cachedAt isKindOfClass:[NSDate class]] && [[NSDate date] timeIntervalSinceDate:cachedAt] < 30.0) {
        return [cachedDecision boolValue];
    }
    
    // Check if the app is directly in scope
    BOOL isInScope = self.scopedApps[bundleID] != nil;
    
    // If not directly in scope, check if it's an extension of a scoped app
    if (!isInScope) {
        isInScope = [self isExtensionEnabled:bundleID];
        
        // If it's an extension, log this for debugging
        if (isInScope) {
            PXLog(@"[WeaponX] Bundle ID %@ is enabled as an extension", bundleID);
        }
    } else {
        // If directly in scope, check if it's enabled
        isInScope = [self.scopedApps[bundleID][@"enabled"] boolValue];
        
        if (isInScope) {
            PXLog(@"[WeaponX] Bundle ID %@ is directly enabled in scope", bundleID);
        }
    }
    
    // Cache the decision with a timestamp
    self.spoofCache[bundleID] = @(isInScope);
    self.spoofCache[[bundleID stringByAppendingString:@"_timestamp"]] = [NSDate date];
    
    return isInScope;
}

- (void)saveScopedApps {
    // Get the proper preferences path
    NSString *prefsPath = PXPreferencesPath();
    NSString *scopedAppsFile = PXGlobalScopePath();
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:prefsPath]) {
        [fileManager createDirectoryAtPath:prefsPath withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0755} error:nil];
    }
    
    // Save scoped apps separately in the global scope file
    NSDictionary *scopedAppsDict = @{@"ScopedApps": [self.scopedApps copy]};
    BOOL success = [scopedAppsDict writeToFile:scopedAppsFile atomically:YES];
    if (!success) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                      code:4006 
                                  userInfo:@{NSLocalizedDescriptionKey: @"Failed to save global scoped apps"}];
        return;
    }
    
    // Set proper permissions for global scope file
    NSError *permError = nil;
    NSDictionary *fileAttributes = @{NSFilePosixPermissions: @0644,
                                   NSFileOwnerAccountName: @"mobile"};
    
    if (![fileManager setAttributes:fileAttributes
                      ofItemAtPath:scopedAppsFile
                             error:&permError]) {
        NSLog(@"[TLinkIOS] Warning: Failed to set global scope file permissions: %@", permError);
    }
    [self.spoofCache removeAllObjects];
    [_appEnabledCache removeAllObjects];
    PXPostSettingsChangedNotification();
}

- (BOOL)isExtensionEnabled:(NSString *)bundleID {
    if (!bundleID) return NO;
    
    // Never consider the WeaponX app itself or system apps
    if ([bundleID isEqualToString:@"com.hydra.tlinkios"] || [bundleID hasPrefix:@"com.apple."]) {
        return NO;
    }
    
    // Check each scoped app's extension pattern
    for (NSString *scopedBundleID in self.scopedApps) {
        NSDictionary *appInfo = self.scopedApps[scopedBundleID];
        NSString *extensionPattern = appInfo[@"extensionPattern"];
        
        if (extensionPattern && [self isBundleIDMatch:bundleID withPattern:extensionPattern]) {
            PXLog(@"[WeaponX] Bundle ID %@ matches extension pattern %@ from app %@", bundleID, extensionPattern, scopedBundleID);
            return [appInfo[@"enabled"] boolValue];
        }
    }
    
    return NO;
}

#pragma mark - Custom Values

- (BOOL)saveCustomValue:(NSString *)value forType:(NSString *)type {
    // Save to profile-specific path
    NSString *identityDir = [self profileIdentityPath];
    if (!identityDir) {
        PXLog(@"[WeaponX] ❌ Failed to get profile identity path");
        return NO;
    }
    
    // Create the dictionary with timestamp
    NSDictionary *valueDict = @{@"value": value, @"lastUpdated": [NSDate date]};
    
    // Determine the file path based on type
    NSString *filePath = nil;
    if ([type isEqualToString:@"IDFA"]) {
        filePath = [identityDir stringByAppendingPathComponent:@"advertising_id.plist"];
    } else if ([type isEqualToString:@"IDFV"]) {
        filePath = [identityDir stringByAppendingPathComponent:@"vendor_id.plist"];
    } else if ([type isEqualToString:@"DeviceName"]) {
        filePath = [identityDir stringByAppendingPathComponent:@"device_name.plist"];
    } else if ([type isEqualToString:@"SerialNumber"]) {
        filePath = [identityDir stringByAppendingPathComponent:@"serial_number.plist"];
    } else if ([type isEqualToString:@"IMEI"]) {
        filePath = [identityDir stringByAppendingPathComponent:@"imei.plist"];
    } else if ([type isEqualToString:@"MEID"]) {
        filePath = [identityDir stringByAppendingPathComponent:@"meid.plist"];
    } else if ([type isEqualToString:@"UDID"]) {
        filePath = [identityDir stringByAppendingPathComponent:@"udid.plist"];
    } else if ([type isEqualToString:@"SystemBootUUID"]) {
        // Canonical key only — never write HardwareUUID as a new key
        filePath = [identityDir stringByAppendingPathComponent:@"system_boot_uuid.plist"];
    } else if ([type isEqualToString:@"DyldCacheUUID"]) {
        filePath = [identityDir stringByAppendingPathComponent:@"dyld_cache_uuid.plist"];
    } else if ([type isEqualToString:@"PasteboardUUID"]) {
        filePath = [identityDir stringByAppendingPathComponent:@"pasteboard_uuid.plist"];
    } else if ([type isEqualToString:@"KeychainUUID"]) {
        filePath = [identityDir stringByAppendingPathComponent:@"keychain_uuid.plist"];
    } else if ([type isEqualToString:@"UserDefaultsUUID"]) {
        filePath = [identityDir stringByAppendingPathComponent:@"userdefaults_uuid.plist"];
    } else if ([type isEqualToString:@"AppGroupUUID"]) {
        filePath = [identityDir stringByAppendingPathComponent:@"appgroup_uuid.plist"];
    } else if ([type isEqualToString:@"CoreDataUUID"]) {
        filePath = [identityDir stringByAppendingPathComponent:@"coredata_uuid.plist"];
    } else if ([type isEqualToString:@"AppInstallUUID"]) {
        filePath = [identityDir stringByAppendingPathComponent:@"appinstall_uuid.plist"];
    } else if ([type isEqualToString:@"AppContainerUUID"]) {
        filePath = [identityDir stringByAppendingPathComponent:@"appcontainer_uuid.plist"];
    } else {
        PXLog(@"[WeaponX] ❌ Unknown identifier type: %@", type);
        return NO;
    }
    
    // Write the value to file
    BOOL success = [valueDict writeToFile:filePath atomically:YES];
    
    // Also update the combined device_ids.plist
    if (success) {
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: 
                                         [NSMutableDictionary dictionary];
        deviceIds[type] = value;
        NSInteger gen = [deviceIds[@"GenerationCounter"] respondsToSelector:@selector(integerValue)] ? [deviceIds[@"GenerationCounter"] integerValue] : 0;
        deviceIds[@"GenerationCounter"] = @(gen + 1);
        success = [deviceIds writeToFile:deviceIdsPath atomically:YES];
        
        PXLog(@"[WeaponX] ✅ Custom %@ saved: %@", type, value);
        
        // For specific types, also update the respective manager
        if ([type isEqualToString:@"IDFA"]) {
            [[IDFAManager sharedManager] setCurrentIDFA:value];
        } else if ([type isEqualToString:@"IDFV"]) {
            [[IDFVManager sharedManager] setCurrentIDFV:value];
        } else if ([type isEqualToString:@"SystemBootUUID"]) {
            [[SystemUUIDManager sharedManager] setCurrentBootUUID:value];
        } else if ([type isEqualToString:@"DyldCacheUUID"]) {
            [[DyldCacheUUIDManager sharedManager] setCurrentDyldCacheUUID:value];
        } else if ([type isEqualToString:@"PasteboardUUID"]) {
            [[PasteboardUUIDManager sharedManager] setCurrentPasteboardUUID:value];
        } else if ([type isEqualToString:@"KeychainUUID"]) {
            [[KeychainUUIDManager sharedManager] setCurrentKeychainUUID:value];
        } else if ([type isEqualToString:@"UserDefaultsUUID"]) {
            [[UserDefaultsUUIDManager sharedManager] setCurrentUserDefaultsUUID:value];
        } else if ([type isEqualToString:@"AppGroupUUID"]) {
            [[AppGroupUUIDManager sharedManager] setCurrentAppGroupUUID:value];
        } else if ([type isEqualToString:@"CoreDataUUID"]) {
            [[CoreDataUUIDManager sharedManager] setCurrentCoreDataUUID:value];
        } else if ([type isEqualToString:@"AppInstallUUID"]) {
            [[AppInstallUUIDManager sharedManager] setCurrentAppInstallUUID:value];
        } else if ([type isEqualToString:@"AppContainerUUID"]) {
            [[AppContainerUUIDManager sharedManager] setCurrentAppContainerUUID:value];
        }
    }
    
    return success;
}

- (BOOL)setCustomIDFA:(NSString *)value {
    // Validate UUID format
    if (![self validateUUID:value]) return NO;
    return [self saveCustomValue:value forType:@"IDFA"];
}

#pragma mark - IMEI/MEID Spoofing (kept strictly separate)

- (BOOL)setCustomIMEI:(NSString *)value {
    if (![self isValidIMEI:value]) return NO;

    // Once an exact regional cellular slot exists, manual IMEI writes are
    // governed by that slot too. known=false deliberately rejects a guessed TAC.
    NSString *identityDir = [self profileIdentityPath];
    NSDictionary *deviceIds = identityDir.length
        ? [NSDictionary dictionaryWithContentsOfFile:[identityDir stringByAppendingPathComponent:@"device_ids.plist"]]
        : nil;
    NSString *productType = PXProfileString(deviceIds[@"DeviceModel"]);
    NSString *regulatoryModelNumber = PXProfileString(deviceIds[@"RegulatoryModelNumber"]);
    if ([productType hasPrefix:@"iPhone"]) {
        if (!regulatoryModelNumber.length) return NO;
        NSDictionary *spec = [[IPhoneModelDB sharedManager] cellularSpecForProductType:productType
                                                                 regulatoryModelNumber:regulatoryModelNumber];
        BOOL known = [spec[@"known"] isKindOfClass:[NSNumber class]] && [spec[@"known"] boolValue];
        BOOL enabled = known && [spec[@"enabled"] isKindOfClass:[NSNumber class]] && [spec[@"enabled"] boolValue];
        NSArray *tacs = [spec[@"imeiTACs"] isKindOfClass:[NSArray class]] ? spec[@"imeiTACs"] : nil;
        if (!enabled || !PXIdentityHasAllowedPrefix(value, tacs)) return NO;
    }
    return [self saveCustomValue:value forType:@"IMEI"];
}

- (BOOL)setCustomMEID:(NSString *)value {
    if (![self isValidMEID:value]) return NO;

    NSString *identityDir = [self profileIdentityPath];
    NSDictionary *deviceIds = identityDir.length
        ? [NSDictionary dictionaryWithContentsOfFile:[identityDir stringByAppendingPathComponent:@"device_ids.plist"]]
        : nil;
    NSString *productType = PXProfileString(deviceIds[@"DeviceModel"]);
    NSString *regulatoryModelNumber = PXProfileString(deviceIds[@"RegulatoryModelNumber"]);
    if ([productType hasPrefix:@"iPhone"]) {
        if (!regulatoryModelNumber.length) return NO;
        NSDictionary *spec = [[IPhoneModelDB sharedManager] cellularSpecForProductType:productType
                                                                 regulatoryModelNumber:regulatoryModelNumber];
        BOOL known = [spec[@"known"] isKindOfClass:[NSNumber class]] && [spec[@"known"] boolValue];
        BOOL enabled = known && [spec[@"enabled"] isKindOfClass:[NSNumber class]] && [spec[@"enabled"] boolValue];
        BOOL cdma = enabled && [spec[@"cdma"] isKindOfClass:[NSNumber class]] && [spec[@"cdma"] boolValue];
        NSArray *prefixes = [spec[@"meidPrefixes"] isKindOfClass:[NSArray class]] ? spec[@"meidPrefixes"] : nil;
        if (!cdma || !PXIdentityHasAllowedPrefix(value, prefixes)) return NO;
    }
    return [self saveCustomValue:value forType:@"MEID"];
}

#pragma mark - UDID Spoofing

- (BOOL)isValidUDID:(NSString *)value {
    if (![value isKindOfClass:[NSString class]] || value.length != 40) {
        return NO;
    }
    // Canonical format: 40 lowercase hex characters only
    NSCharacterSet *nonLowerHex = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet];
    return [value rangeOfCharacterFromSet:nonLowerHex].location == NSNotFound;
}

- (NSString *)generateUDID {
    // 40 lowercase hex characters
    NSMutableString *udid = [NSMutableString stringWithCapacity:40];
    for (int i = 0; i < 40; i++) {
        [udid appendFormat:@"%x", arc4random_uniform(16)];
    }
    
    NSString *identityDir = [self profileIdentityPath];
    if (identityDir) {
        NSDictionary *udidDict = @{@"value": udid, @"lastUpdated": [NSDate date]};
        NSString *udidPath = [identityDir stringByAppendingPathComponent:@"udid.plist"];
        [udidDict writeToFile:udidPath atomically:YES];
        
        // Sync device_ids.plist["UDID"]
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?:
                                         [NSMutableDictionary dictionary];
        deviceIds[@"UDID"] = udid;
        [deviceIds writeToFile:deviceIdsPath atomically:YES];
        
        PXLog(@"[WeaponX] 🆔 Generated UDID: %@", udid);
    }
    
    return [udid copy];
}

- (BOOL)setCustomUDID:(NSString *)value {
    if (![value isKindOfClass:[NSString class]]) return NO;
    // Normalize to lowercase before validation
    NSString *normalized = [value lowercaseString];
    if (![self isValidUDID:normalized]) return NO;
    return [self saveCustomValue:normalized forType:@"UDID"];
}

#pragma mark - ATT Authorization Status

- (NSInteger)attAuthorizationStatus {
    NSString *identityDir = [self profileIdentityPath];
    if (!identityDir) {
        return 0; // notDetermined
    }
    
    // Prefer device_ids.plist
    NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
    NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
    if (deviceIds[@"ATTAuthorizationStatus"] != nil) {
        NSInteger status = [deviceIds[@"ATTAuthorizationStatus"] integerValue];
        if (status >= 0 && status <= 3) {
            return status;
        }
    }
    
    // Fall back to tracking_info.plist
    NSString *trackingPath = [identityDir stringByAppendingPathComponent:@"tracking_info.plist"];
    NSDictionary *trackingDict = [NSDictionary dictionaryWithContentsOfFile:trackingPath];
    if (trackingDict[@"ATTAuthorizationStatus"] != nil) {
        NSInteger status = [trackingDict[@"ATTAuthorizationStatus"] integerValue];
        if (status >= 0 && status <= 3) {
            return status;
        }
    }
    
    return 0; // notDetermined default
}

- (void)setATTAuthorizationStatus:(NSInteger)status {
    // Clamp to valid ATTrackingManagerAuthorizationStatus range 0...3
    if (status < 0) status = 0;
    if (status > 3) status = 3;
    
    NSString *identityDir = [self profileIdentityPath];
    if (!identityDir) {
        PXLog(@"[WeaponX] ❌ setATTAuthorizationStatus: no identity path");
        return;
    }
    
    NSDictionary *trackingDict = @{
        @"ATTAuthorizationStatus": @(status),
        @"lastUpdated": [NSDate date]
    };
    NSString *trackingPath = [identityDir stringByAppendingPathComponent:@"tracking_info.plist"];
    [trackingDict writeToFile:trackingPath atomically:YES];
    
    // Sync device_ids["ATTAuthorizationStatus"]
    NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
    NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?:
                                     [NSMutableDictionary dictionary];
    deviceIds[@"ATTAuthorizationStatus"] = @(status);
    [deviceIds writeToFile:deviceIdsPath atomically:YES];
    
    PXLog(@"[WeaponX] 📡 ATTAuthorizationStatus set to: %ld", (long)status);
}

#pragma mark - Profile Schema Migration (v1 → v2)

static BOOL PXIsNonZeroUUIDString(NSString *uuid) {
    if (![uuid isKindOfClass:[NSString class]] || uuid.length == 0) {
        return NO;
    }
    // Treat all-zero UUID as zero (case-insensitive)
    NSString *normalized = [[uuid stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString];
    for (NSUInteger i = 0; i < normalized.length; i++) {
        if ([normalized characterAtIndex:i] != '0') {
            return YES;
        }
    }
    return NO;
}

- (void)migrateProfileSchemaIfNeeded {
    // Resolve identity path without re-entering migration (caller may already guard)
    NSString *profileId = [self getActiveProfileId];
    if (!profileId) {
        return;
    }
    
    NSString *profileDir = [PXProfilesPath() stringByAppendingPathComponent:profileId];
    NSString *identityDir = [profileDir stringByAppendingPathComponent:@"identity"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:identityDir]) {
        return;
    }
    
    NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
    NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath];
    if (!deviceIds) {
        deviceIds = [NSMutableDictionary dictionary];
    }
    
    NSInteger schemaVersion = [deviceIds[@"ProfileSchemaVersion"] respondsToSelector:@selector(integerValue)]
        ? [deviceIds[@"ProfileSchemaVersion"] integerValue]
        : 0;
    
    if (schemaVersion >= 2) {
        return; // Already migrated
    }
    
    PXLog(@"[WeaponX] 🔄 Migrating profile schema v%ld → v2 for profile %@", (long)schemaVersion, profileId);
    
    // 1) HardwareUUID → SystemBootUUID if canonical missing (one-way; do not write HardwareUUID)
    NSString *systemBoot = nil;
    id existingBoot = deviceIds[@"SystemBootUUID"];
    if ([existingBoot isKindOfClass:[NSString class]] && [(NSString *)existingBoot length] > 0) {
        systemBoot = (NSString *)existingBoot;
    }
    if (!systemBoot.length) {
        NSString *bootPlistPath = [identityDir stringByAppendingPathComponent:@"system_boot_uuid.plist"];
        NSDictionary *bootPlist = [NSDictionary dictionaryWithContentsOfFile:bootPlistPath];
        if ([bootPlist[@"value"] isKindOfClass:[NSString class]] && [bootPlist[@"value"] length] > 0) {
            systemBoot = bootPlist[@"value"];
            deviceIds[@"SystemBootUUID"] = systemBoot;
        }
    }
    if (!systemBoot.length) {
        id legacyHW = deviceIds[@"HardwareUUID"];
        if ([legacyHW isKindOfClass:[NSString class]] && [(NSString *)legacyHW length] > 0) {
            systemBoot = (NSString *)legacyHW;
            deviceIds[@"SystemBootUUID"] = systemBoot;
            NSDictionary *bootDict = @{@"value": systemBoot, @"lastUpdated": [NSDate date]};
            [bootDict writeToFile:[identityDir stringByAppendingPathComponent:@"system_boot_uuid.plist"] atomically:YES];
            PXLog(@"[WeaponX] 🔄 Migrated HardwareUUID → SystemBootUUID: %@", systemBoot);
        }
    }
    
    // 2) Generate UDID if toggle enabled and value missing
    BOOL udidEnabled = [self.settings[@"UDID"] boolValue];
    NSString *existingUDID = nil;
    id udidRaw = deviceIds[@"UDID"];
    if ([udidRaw isKindOfClass:[NSString class]] && [(NSString *)udidRaw length] > 0) {
        existingUDID = (NSString *)udidRaw;
    }
    if (!existingUDID.length) {
        NSDictionary *udidPlist = [NSDictionary dictionaryWithContentsOfFile:[identityDir stringByAppendingPathComponent:@"udid.plist"]];
        if ([udidPlist[@"value"] isKindOfClass:[NSString class]] && [udidPlist[@"value"] length] > 0) {
            existingUDID = udidPlist[@"value"];
            deviceIds[@"UDID"] = existingUDID;
        }
    }
    if (udidEnabled && !existingUDID.length) {
        NSMutableString *udid = [NSMutableString stringWithCapacity:40];
        for (int i = 0; i < 40; i++) {
            [udid appendFormat:@"%x", arc4random_uniform(16)];
        }
        NSDictionary *udidDict = @{@"value": udid, @"lastUpdated": [NSDate date]};
        [udidDict writeToFile:[identityDir stringByAppendingPathComponent:@"udid.plist"] atomically:YES];
        deviceIds[@"UDID"] = [udid copy];
        PXLog(@"[WeaponX] 🔄 Migration generated UDID: %@", udid);
    }
    
    // 3) Init ATTAuthorizationStatus default
    if (deviceIds[@"ATTAuthorizationStatus"] == nil) {
        BOOL idfaEnabled = [self.settings[@"IDFA"] boolValue];
        NSString *idfa = nil;
        id idfaRaw = deviceIds[@"IDFA"];
        if ([idfaRaw isKindOfClass:[NSString class]]) {
            idfa = (NSString *)idfaRaw;
        }
        if (!idfa.length) {
            NSDictionary *idfaPlist = [NSDictionary dictionaryWithContentsOfFile:[identityDir stringByAppendingPathComponent:@"advertising_id.plist"]];
            if ([idfaPlist[@"value"] isKindOfClass:[NSString class]]) {
                idfa = idfaPlist[@"value"];
            }
        }
        
        // IDFA enabled + non-zero UUID → authorized (3); else notDetermined (0)
        NSInteger attStatus = (idfaEnabled && PXIsNonZeroUUIDString(idfa)) ? 3 : 0;
        deviceIds[@"ATTAuthorizationStatus"] = @(attStatus);
        
        NSDictionary *trackingDict = @{
            @"ATTAuthorizationStatus": @(attStatus),
            @"lastUpdated": [NSDate date]
        };
        [trackingDict writeToFile:[identityDir stringByAppendingPathComponent:@"tracking_info.plist"] atomically:YES];
        PXLog(@"[WeaponX] 🔄 Migration ATTAuthorizationStatus default: %ld", (long)attStatus);
    }
    
    // 4) Init LowPowerMode default = NO
    if (deviceIds[@"LowPowerMode"] == nil) {
        deviceIds[@"LowPowerMode"] = @NO;
        
        // Prefer identity battery_info.plist; also update profile-root path used by BatteryManager
        NSString *batteryPath = [identityDir stringByAppendingPathComponent:@"battery_info.plist"];
        NSMutableDictionary *batteryInfo = [NSMutableDictionary dictionaryWithContentsOfFile:batteryPath] ?:
                                           [NSMutableDictionary dictionary];
        if (batteryInfo[@"LowPowerMode"] == nil) {
            batteryInfo[@"LowPowerMode"] = @NO;
            [batteryInfo writeToFile:batteryPath atomically:YES];
        }
        
        NSString *profileBatteryPath = [profileDir stringByAppendingPathComponent:@"battery_info.plist"];
        NSMutableDictionary *profileBattery = [NSMutableDictionary dictionaryWithContentsOfFile:profileBatteryPath] ?:
                                              [NSMutableDictionary dictionary];
        if (profileBattery[@"LowPowerMode"] == nil) {
            profileBattery[@"LowPowerMode"] = @NO;
            if (profileBattery[@"BatteryLevel"] == nil && batteryInfo[@"BatteryLevel"] != nil) {
                profileBattery[@"BatteryLevel"] = batteryInfo[@"BatteryLevel"];
            }
            [profileBattery writeToFile:profileBatteryPath atomically:YES];
        }
        
        PXLog(@"[WeaponX] 🔄 Migration LowPowerMode default: NO");
    }
    
    // Mark schema v2 and bump GenerationCounter once for the whole migration
    deviceIds[@"ProfileSchemaVersion"] = @2;
    NSInteger gen = [deviceIds[@"GenerationCounter"] respondsToSelector:@selector(integerValue)]
        ? [deviceIds[@"GenerationCounter"] integerValue]
        : 0;
    deviceIds[@"GenerationCounter"] = @(gen + 1);
    
    BOOL wrote = [deviceIds writeToFile:deviceIdsPath atomically:YES];
    if (wrote) {
        PXLog(@"[WeaponX] ✅ Profile schema migrated to v2 (GenerationCounter=%ld)", (long)(gen + 1));
    } else {
        PXLog(@"[WeaponX] ⚠️ Failed to write device_ids.plist during schema migration");
    }
}

static NSInteger PXHexValue(unichar c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    return -1;
}

static unichar PXHexChar(NSInteger value) {
    static const char *digits = "0123456789ABCDEF";
    return digits[value & 0xF];
}

static NSInteger PXMEIDLuhnCheckDigit(NSString *body) {
    NSInteger sum = 0;
    BOOL doubleDigit = YES;
    for (NSInteger i = (NSInteger)body.length - 1; i >= 0; i--) {
        NSInteger value = PXHexValue([body characterAtIndex:(NSUInteger)i]);
        if (value < 0) return -1;
        if (doubleDigit) {
            value *= 2;
            value = (value / 16) + (value % 16);
        }
        sum += value;
        doubleDigit = !doubleDigit;
    }
    return (16 - (sum % 16)) % 16;
}

- (NSString *)generateIMEI {
    // Compatibility API, but generation is now canonical-only. Never fall back
    // to a generic TAC pool that can contradict ProductType/A-number.
    NSString *identityDir = [self profileIdentityPath];
    NSDictionary *deviceIds = identityDir.length
        ? [NSDictionary dictionaryWithContentsOfFile:[identityDir stringByAppendingPathComponent:@"device_ids.plist"]]
        : nil;
    NSString *productType = PXProfileString(deviceIds[@"DeviceModel"]);
    NSString *regulatoryModelNumber = PXProfileString(deviceIds[@"RegulatoryModelNumber"]);
    if (!productType.length || !regulatoryModelNumber.length) return nil;

    NSDictionary *spec = [[IPhoneModelDB sharedManager] cellularSpecForProductType:productType
                                                             regulatoryModelNumber:regulatoryModelNumber];
    BOOL known = [spec[@"known"] isKindOfClass:[NSNumber class]] && [spec[@"known"] boolValue];
    BOOL enabled = known && [spec[@"enabled"] isKindOfClass:[NSNumber class]] && [spec[@"enabled"] boolValue];
    NSArray *tacs = [spec[@"imeiTACs"] isKindOfClass:[NSArray class]] ? spec[@"imeiTACs"] : nil;
    if (!enabled) return nil;

    NSString *imei = PXGenerateIMEIFromAuthoritativeTACs(tacs);
    if (!imei.length || ![self setCustomIMEI:imei]) return nil;
    return imei;
}

- (NSString *)generateMEID {
    // MEID is available only when the exact regional capability is verified as
    // CDMA-capable and carries an authoritative prefix list.
    NSString *identityDir = [self profileIdentityPath];
    NSDictionary *deviceIds = identityDir.length
        ? [NSDictionary dictionaryWithContentsOfFile:[identityDir stringByAppendingPathComponent:@"device_ids.plist"]]
        : nil;
    NSString *productType = PXProfileString(deviceIds[@"DeviceModel"]);
    NSString *regulatoryModelNumber = PXProfileString(deviceIds[@"RegulatoryModelNumber"]);
    if (!productType.length || !regulatoryModelNumber.length) return nil;

    NSDictionary *spec = [[IPhoneModelDB sharedManager] cellularSpecForProductType:productType
                                                             regulatoryModelNumber:regulatoryModelNumber];
    BOOL known = [spec[@"known"] isKindOfClass:[NSNumber class]] && [spec[@"known"] boolValue];
    BOOL enabled = known && [spec[@"enabled"] isKindOfClass:[NSNumber class]] && [spec[@"enabled"] boolValue];
    BOOL cdma = enabled && [spec[@"cdma"] isKindOfClass:[NSNumber class]] && [spec[@"cdma"] boolValue];
    NSArray *prefixes = [spec[@"meidPrefixes"] isKindOfClass:[NSArray class]] ? spec[@"meidPrefixes"] : nil;
    if (!cdma) return nil;

    NSString *meid = PXGenerateMEIDFromAuthoritativePrefixes(prefixes);
    if (!meid.length || ![self setCustomMEID:meid]) return nil;
    return meid;
}

// IMEI policy is shared across all writers/readers; TAC is not region-locked.
- (BOOL)isValidIMEI:(NSString *)imei {
    return PXValidateIdentityValue(imei, PXIdentityValueKindIMEI, NO);
}

// MEID policy is shared across all writers/readers.
- (BOOL)isValidMEID:(NSString *)meid {
    return PXValidateIdentityValue(meid, PXIdentityValueKindMEID, NO);
}

- (BOOL)isAllDigits:(NSString *)string {
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    return ([string rangeOfCharacterFromSet:nonDigits].location == NSNotFound);
}

- (BOOL)setCustomIDFV:(NSString *)value {
    // Validate UUID format
    if (![self validateUUID:value]) return NO;
    return [self saveCustomValue:value forType:@"IDFV"];
}

- (BOOL)setCustomDeviceName:(NSString *)value {
    // No special validation for device name
    return [self saveCustomValue:value forType:@"DeviceName"];
}

- (BOOL)setCustomSerialNumber:(NSString *)value {
    // Serial numbers have specific format requirements
    // This is a simplified validation - implement appropriate validation for serial numbers
    if (!value || value.length < 8) return NO;
    return [self saveCustomValue:value forType:@"SerialNumber"];
}

- (BOOL)setCustomSystemBootUUID:(NSString *)value {
    // Validate UUID format
    if (![self validateUUID:value]) return NO;
    return [self saveCustomValue:value forType:@"SystemBootUUID"];
}

- (BOOL)setCustomDyldCacheUUID:(NSString *)value {
    // Validate UUID format
    if (![self validateUUID:value]) return NO;
    return [self saveCustomValue:value forType:@"DyldCacheUUID"];
}

- (BOOL)setCustomPasteboardUUID:(NSString *)value {
    // Validate UUID format
    if (![self validateUUID:value]) return NO;
    return [self saveCustomValue:value forType:@"PasteboardUUID"];
}

- (BOOL)setCustomKeychainUUID:(NSString *)value {
    // Validate UUID format
    if (![self validateUUID:value]) return NO;
    return [self saveCustomValue:value forType:@"KeychainUUID"];
}

- (BOOL)setCustomUserDefaultsUUID:(NSString *)value {
    // Validate UUID format
    if (![self validateUUID:value]) return NO;
    return [self saveCustomValue:value forType:@"UserDefaultsUUID"];
}

- (BOOL)setCustomAppGroupUUID:(NSString *)value {
    // Validate UUID format
    if (![self validateUUID:value]) return NO;
    return [self saveCustomValue:value forType:@"AppGroupUUID"];
}

- (BOOL)setCustomCoreDataUUID:(NSString *)value {
    // Validate UUID format
    if (![self validateUUID:value]) return NO;
    return [self saveCustomValue:value forType:@"CoreDataUUID"];
}

- (BOOL)setCustomAppInstallUUID:(NSString *)value {
    // Validate UUID format
    if (![self validateUUID:value]) return NO;
    return [self saveCustomValue:value forType:@"AppInstallUUID"];
}

- (BOOL)setCustomAppContainerUUID:(NSString *)value {
    // Validate UUID format
    if (![self validateUUID:value]) return NO;
    return [self saveCustomValue:value forType:@"AppContainerUUID"];
}

- (BOOL)validateUUID:(NSString *)uuid {
    return PXValidateIdentityValue(uuid, PXIdentityValueKindUUID, NO);
}

#pragma mark - Device Model Specifications

- (NSDictionary *)getDeviceModelSpecifications {
    NSString *deviceIdsPath = PXActiveProfileDeviceIDsPath();
    NSDictionary *deviceIds = deviceIdsPath.length
        ? [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath]
        : nil;
    NSDictionary *profileSpecs = PXDeviceSpecificationsFromDeviceIDs(deviceIds);
    if (profileSpecs.count) return profileSpecs;

    NSString *currentDeviceModel = PXProfileString([self currentValueForIdentifier:@"DeviceModel"]);
    if (!currentDeviceModel.length) return nil;
    IPhoneModelDB *modelDB = [IPhoneModelDB sharedManager];
    NSDictionary *modelSpec = [modelDB specForProductType:currentDeviceModel];
    NSDictionary *canonical = modelSpec ? [modelDB canonicalHardwareSpecForProductType:currentDeviceModel] : nil;
    if (canonical.count) return canonical;
    if ([currentDeviceModel hasPrefix:@"iPhone"]) return nil;
    return [[DeviceModelManager sharedManager] deviceSpecificationsForModel:currentDeviceModel];
}

- (NSString *)getScreenResolution {
    NSDictionary *specs = [self getDeviceModelSpecifications];
    return specs ? specs[@"screenResolution"] : @"Unknown";
}

- (NSString *)getViewportResolution {
    NSDictionary *specs = [self getDeviceModelSpecifications];
    return specs ? specs[@"viewportResolution"] : @"Unknown";
}

- (CGFloat)getDevicePixelRatio {
    NSDictionary *specs = [self getDeviceModelSpecifications];
    return specs ? [specs[@"devicePixelRatio"] floatValue] : 0.0;
}

- (NSInteger)getScreenDensity {
    NSDictionary *specs = [self getDeviceModelSpecifications];
    return specs ? [specs[@"screenDensity"] integerValue] : 0;
}

- (NSString *)getCPUArchitecture {
    NSDictionary *specs = [self getDeviceModelSpecifications];
    return specs ? specs[@"cpuArchitecture"] : @"Unknown";
}

- (NSInteger)getDeviceMemory {
    NSDictionary *specs = [self getDeviceModelSpecifications];
    return specs ? [specs[@"deviceMemory"] integerValue] : 0;
}

- (NSString *)getGPUFamily {
    NSDictionary *specs = [self getDeviceModelSpecifications];
    return specs ? specs[@"gpuFamily"] : @"Unknown";
}

- (NSDictionary *)getWebGLInfo {
    NSDictionary *specs = [self getDeviceModelSpecifications];
    return specs ? specs[@"webGLInfo"] : @{};
}

- (NSInteger)getCPUCoreCount {
    NSDictionary *specs = [self getDeviceModelSpecifications];
    return specs ? [specs[@"cpuCoreCount"] integerValue] : 0;
}

- (NSString *)getMetalFeatureSet {
    NSDictionary *specs = [self getDeviceModelSpecifications];
    return specs ? specs[@"metalFeatureSet"] : @"Unknown";
}

// Device Theme Methods
- (NSString *)generateDeviceTheme {
    // Generate a random theme (Light or Dark)
    NSArray *themes = @[@"Light", @"Dark"];
    NSInteger randomIndex = arc4random_uniform(2);
    NSString *theme = themes[randomIndex];
    
    // Save the theme to the profile
    [self setCustomDeviceTheme:theme];
    
    return theme;
}

- (NSString *)toggleDeviceTheme {
    // Get current theme
    NSString *currentTheme = [self currentValueForIdentifier:@"DeviceTheme"];
    
    // Toggle between Light and Dark
    NSString *newTheme;
    if ([currentTheme isEqualToString:@"Light"]) {
        newTheme = @"Dark";
    } else {
        newTheme = @"Light";
    }
    
    // Save the new theme
    [self setCustomDeviceTheme:newTheme];
    
    return newTheme;
}

- (BOOL)setCustomDeviceTheme:(NSString *)value {
    // Validate theme value
    if (![value isEqualToString:@"Light"] && ![value isEqualToString:@"Dark"]) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:2004 userInfo:@{NSLocalizedDescriptionKey: @"Invalid Device Theme (must be 'Light' or 'Dark')"}];
        return NO;
    }
    
    NSString *identityDir = [self profileIdentityPath];
    BOOL success = NO;
    
    if (identityDir) {
        // Create dictionary with theme value
        NSDictionary *themeDict = @{
            @"value": value,
            @"lastUpdated": [NSDate date]
        };
        
        // Save to device_theme.plist
        NSString *themePath = [identityDir stringByAppendingPathComponent:@"device_theme.plist"];
        success = [themeDict writeToFile:themePath atomically:YES];
        
        // Also update the combined device_ids.plist
        NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: [NSMutableDictionary dictionary];
        
        // Add theme to device_ids.plist
        deviceIds[@"DeviceTheme"] = value;
        
        success = [deviceIds writeToFile:deviceIdsPath atomically:YES];
    }
    
    return success;
}

#pragma mark - Canvas Fingerprinting Protection

- (BOOL)toggleCanvasFingerprintProtection {
    BOOL currentValue = [self isCanvasFingerprintProtectionEnabled];
    BOOL newValue = !currentValue;

    if (![self setCanvasFingerprintProtection:newValue]) {
        PXLog(@"[WeaponX] ❌ Canvas Fingerprint Protection toggle persistence failed; keeping %@",
              currentValue ? @"ENABLED" : @"DISABLED");
        return currentValue;
    }

    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.hydra.tlinkios.toggleCanvasFingerprint"),
        NULL, NULL, TRUE
    );

    PXLog(@"[WeaponX] 🎨 Canvas Fingerprint Protection %@", newValue ? @"ENABLED" : @"DISABLED");
    return newValue;
}

- (BOOL)isCanvasFingerprintProtectionEnabled {
    // Read directly from the plist file - SINGLE SOURCE OF TRUTH
    NSString *securitySettingsPath = PXSecuritySettingsPath();
    NSDictionary *settingsDict = [NSDictionary dictionaryWithContentsOfFile:securitySettingsPath];
    
    if (settingsDict) {
        if (settingsDict[@"canvasFingerprintingEnabled"] != nil) {
            return [settingsDict[@"canvasFingerprintingEnabled"] boolValue];
        }
        if (settingsDict[@"CanvasFingerprint"] != nil) {
            return [settingsDict[@"CanvasFingerprint"] boolValue];
        }
    }
    
    return NO; // Default to disabled if settings file doesn't exist
}

- (BOOL)setCanvasFingerprintProtection:(BOOL)enabled {
    NSString *securitySettingsPath = PXSecuritySettingsPath();
    NSMutableDictionary *settingsDict = [NSMutableDictionary dictionaryWithContentsOfFile:securitySettingsPath] ?: [NSMutableDictionary dictionary];

    settingsDict[@"canvasFingerprintingEnabled"] = @(enabled);
    settingsDict[@"CanvasFingerprint"] = @(enabled);

    BOOL success = [settingsDict writeToFile:securitySettingsPath atomically:YES];
    if (!success) {
        PXLog(@"[WeaponX] ❌ Failed to persist Canvas Fingerprint Protection at %@", securitySettingsPath);
        return NO;
    }

    NSUserDefaults *securityDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
    [securityDefaults setBool:enabled forKey:@"canvasFingerprintingEnabled"];
    [securityDefaults setBool:enabled forKey:@"CanvasFingerprint"];
    [securityDefaults synchronize];

    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.hydra.tlinkios.settings.changed"),
        NULL, NULL, TRUE
    );

    return YES;
}

- (BOOL)resetCanvasNoiseAndPersist {
    NSString *securitySettingsPath = PXSecuritySettingsPath();
    NSMutableDictionary *settingsDict = [NSMutableDictionary dictionaryWithContentsOfFile:securitySettingsPath] ?: [NSMutableDictionary dictionary];
    uint32_t nonce = [settingsDict[@"canvasNoiseSeedNonce"] unsignedIntValue];
    nonce = nonce == 0xFFFFFFFFu ? 1u : nonce + 1u;
    if (nonce == 0) nonce = 1u;
    settingsDict[@"canvasNoiseSeedNonce"] = @(nonce);

    BOOL success = [settingsDict writeToFile:securitySettingsPath atomically:YES];
    if (!success) {
        PXLog(@"[WeaponX] ❌ Failed to persist Canvas noise reset nonce at %@", securitySettingsPath);
        return NO;
    }

    NSUserDefaults *securityDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
    [securityDefaults setInteger:(NSInteger)nonce forKey:@"canvasNoiseSeedNonce"];
    [securityDefaults synchronize];

    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterPostNotification(center, CFSTR("com.hydra.tlinkios.settings.changed"), NULL, NULL, TRUE);
    CFNotificationCenterPostNotification(center, CFSTR("com.hydra.tlinkios.resetCanvasNoise"), NULL, NULL, TRUE);

    PXLog(@"[WeaponX] 🎨 Canvas Fingerprint Noise patterns reset (nonce=%u)", nonce);
    return YES;
}

- (void)resetCanvasNoise {
    [self resetCanvasNoiseAndPersist];
}

@end
