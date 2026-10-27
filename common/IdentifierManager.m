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
#import "PXRuntimeSourceStore.h"
#import "PXRuntimeIdentifierWriter.h"
#import "PXRuntimeScalarPreparation.h"
#import "PXRuntimeArtifactPreparation.h"
#import "PXRuntimeArtifactWriter.h"
#import "PXRuntimeGeneration.h"
#import "PXProfileLifecycleLease.h"
#import "PXProfileArtifactMutation.h"
#import "PXProfileDeletionJournal.h"
#import <Security/Security.h>
#import <sys/sysctl.h>

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
- (PXCommittedRuntimeGeneration *)ownedRuntimeGenerationForProfileID:(NSString *)profileID currentProfile:(BOOL)current networkArtifacts:(NSDictionary *)networkArtifacts deferSettings:(BOOL)deferSettings error:(NSError **)error;
- (BOOL)commitRuntimeGenerationAtIdentityDirectory:(NSString *)identityDir networkArtifacts:(NSDictionary *)networkArtifacts lifecycleLease:(PXProfileLifecycleLease *)lease deferSettings:(BOOL)deferSettings receipt:(PXCommittedRuntimeGeneration **)receipt error:(NSError **)error;
- (NSString *)existingGenerationIdentityForProfileID:(NSString *)profileID lifecycleLease:(PXProfileLifecycleLease *)lease error:(NSError **)error;
- (NSDictionary *)prepareCellularRefreshForDeviceIDs:(NSDictionary *)capturedIDs options:(NSDictionary *)options error:(NSError **)error;
- (void)publishRuntimeGeneration:(NSDictionary *)payload identityDirectory:(NSString *)identityDir model:(PXPreparedDeviceProfileGroup *)model;
- (PXPreparedDeviceProfileGroup *)prepareDeviceProfileGroupWithOptions:(NSDictionary *)options error:(NSError **)error;
- (void)publishPreparedDeviceProfileGroup:(PXPreparedDeviceProfileGroup *)prepared;
- (NSString *)generatePreparedIdentifierForType:(NSString *)type;
- (void)publishPreparedIdentifier:(NSString *)value type:(NSString *)type includeNameAndSerial:(BOOL)includeNameAndSerial;
- (BOOL)isValidIMEI:(NSString *)imei;
- (BOOL)isValidMEID:(NSString *)meid;
- (NSString *)prepareAndPersistTelephonyValue:(NSString *)value type:(NSString *)type generate:(BOOL)generate;
- (PXPreparedDeviceProfileGroup *)commitDeviceProfileGroupWithMutation:(PXProfileArtifactMutation *)mutation;
- (NSDictionary *)captureDeviceIDsAtIdentityDirectory:(NSString *)identityDir;
- (PXProfileArtifactMutation *)currentIdentifierMutation;
- (BOOL)validateCustomDeviceModel:(NSString *)value error:(NSError **)error;
- (PXPreparedDeviceProfileGroup *)prepareCustomDeviceModel:(NSString *)value error:(NSError **)error;
- (NSString *)generateUptimeCompatibilityForBootTime:(BOOL)isBoot;
- (BOOL)persistPreparedIdentifier:(NSString *)value type:(NSString *)type mutation:(PXProfileArtifactMutation *)mutation incrementGeneration:(BOOL)increment;
- (BOOL)migrateProfileSchemaAtIdentityDirectory:(NSString *)identityDir;
- (BOOL)migrateProfileSchemaAtIdentityDirectory:(NSString *)identityDir lifecycleLease:(PXProfileLifecycleLease *)lease;
- (BOOL)commitProfileSchemaWithMutation:(PXProfileArtifactMutation *)mutation;
- (NSString *)profileIdentityPathWithLifecycleLease:(PXProfileLifecycleLease *)lease;
- (NSString *)prepareProfileIdentityForProfileID:(NSString *)profileID lifecycleLease:(PXProfileLifecycleLease *)lease;
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

static BOOL PXIdentifierManagerIsManagerProcess(void) {
    return [NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.hydra.tlinkios"];
}

#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
#define PX_IDENTIFIER_RUNTIME_READ_OPERATION \
    PXRuntimeReadScope pxRuntimeOperationScope __attribute__((cleanup(PXRuntimeReadScopeEnd))) = {0}; \
    if (!PXIdentifierManagerIsManagerProcess()) PXBeginRuntimeSnapshotOperation(&pxRuntimeOperationScope)
#else
#define PX_IDENTIFIER_RUNTIME_READ_OPERATION ((void)0)
#endif

static BOOL PXRuntimeSnapshotImpliesIdentifierEnabled(NSString *type, PXRuntimeReadSnapshot *runtimeView) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    if (![type isKindOfClass:NSString.class] || !type.length) return NO;
    NSDictionary *ids = runtimeView.deviceIDs;
    NSDictionary *security = runtimeView.securitySettings;
    NSDictionary *tlink = runtimeView.tlinkSettings;

    if ([type isEqualToString:@"StorageSystem"]) {
        id explicitStorage = tlink[@"StorageSystemEnabled"];
        if ([explicitStorage respondsToSelector:@selector(boolValue)] && [explicitStorage boolValue]) return YES;
        NSDictionary *storage = [runtimeView profileArtifact:@"storage"];
        return storage[@"TotalStorage"] != nil && storage[@"FreeStorage"] != nil;
    }
    if ([type isEqualToString:@"Battery"]) {
        id secondary = security[@"batterySpoofEnabled"];
        if ([secondary respondsToSelector:@selector(boolValue)] && [secondary boolValue]) return YES;
        return [runtimeView profileArtifact:@"batteryInfo"].count > 0;
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

static NSArray<NSString *> *PXCellularManagedKeys(void) {
    return @[@"CellularCapable", @"AdvertisedSIMCount", @"BasebandFamily", @"BasebandVersion",
        @"IMEI", @"IMEI2", @"MEID", @"ICCID", @"IMSI"];
}
static NSDictionary *PXCellularPreparationDependencies(NSDictionary *ids) {
    NSArray *keys = [@[@"DeviceModel", @"RegulatoryModelNumber", @"IOSBuild"] arrayByAddingObjectsFromArray:PXCellularManagedKeys()];
    return PXRuntimeIdentifierDependencies(ids, keys);
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

static NSArray<NSString *> *PXDeviceProfileManagedKeys(void) {
    return @[
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
}

- (NSDictionary *)captureDeviceIDsAtIdentityDirectory:(NSString *)identityDir {
    __block NSDictionary *ids = nil;
    NSError *sourceError = nil;
    BOOL success = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        ids = [tx dictionaryAtPath:[identityDir stringByAppendingPathComponent:@"device_ids.plist"] error:error];
        return ids != nil;
    }, &sourceError);
    if (!success) self.error = sourceError;
    return success ? ids : nil;
}

- (NSString *)regenerateDeviceProfileGroup {
    PXProfileArtifactMutation *mutation = [self currentIdentifierMutation];
    if (!mutation) return nil;
    PXPreparedDeviceProfileGroup *prepared = nil;
    @try { prepared = [self commitDeviceProfileGroupWithMutation:mutation]; }
    @finally { [mutation invalidate]; }
    if (!prepared) return nil;
    [self publishPreparedDeviceProfileGroup:prepared];
    return prepared.updates[@"DeviceModel"];
}

- (PXPreparedDeviceProfileGroup *)commitDeviceProfileGroupWithMutation:(PXProfileArtifactMutation *)mutation {
    // The caller owns target lifetime and releases before compatibility callbacks.
    self.error = nil;
    if (!mutation) return nil;
    NSDictionary *options = @{ @"webCompat": @(PXWebCompatIOSRangeEnabled()),
        @"wantsIMEI": @([self isIdentifierEnabled:@"IMEI"]), @"wantsMEID": @([self isIdentifierEnabled:@"MEID"]) };
    NSError *sourceError = nil;
    PXPreparedDeviceProfileGroup *prepared = [self prepareDeviceProfileGroupWithOptions:options error:&sourceError];
    if (!prepared) { self.error = sourceError; return nil; }
    BOOL wrote = [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return PXStageRuntimeIdentifierReplacement(tx, mutation.identityDirectory, prepared.updates, prepared.replacedKeys, nil, YES, YES, error);
    } error:&sourceError];
    self.error = wrote ? nil : sourceError;
    return wrote ? prepared : nil;
}

- (void)publishPreparedDeviceProfileGroup:(PXPreparedDeviceProfileGroup *)prepared {
    NSDictionary *ids = prepared.updates;
    @try { [[IOSVersionInfo sharedManager] setCurrentIOSVersionInfo:prepared.versionInfo]; }
    @catch (__unused NSException *exception) {}
    @try { [[DeviceModelManager sharedManager] setCurrentDeviceModel:ids[@"DeviceModel"]]; }
    @catch (__unused NSException *exception) {}
    PXLog(@"[WeaponX] DeviceProfileGroup committed: %@ (%@) iOS %@ (%@)", ids[@"DeviceModel"], ids[@"DeviceModelName"], ids[@"IOSVersion"], ids[@"IOSBuild"]);
    PXDBLog(@"DeviceProfileGroup: device=%@ regulatory=%@ boardID=%@ hwModel=%@", ids[@"DeviceModel"], ids[@"RegulatoryModelNumber"], ids[@"BoardID"], ids[@"HwModel"]);
}

- (PXPreparedDeviceProfileGroup *)prepareDeviceProfileGroupWithOptions:(NSDictionary *)options error:(NSError **)error {
    if (error) *error = nil;
    if (![options isKindOfClass:NSDictionary.class]) {
        if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6020 userInfo:@{NSLocalizedDescriptionKey: @"Invalid model preparation options"}];
        return nil;
    }
    options = [options copy];
    for (NSString *key in @[@"webCompat", @"wantsIMEI", @"wantsMEID"]) {
        if (options[key] && ![options[key] isKindOfClass:NSNumber.class]) {
            if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6020 userInfo:@{NSLocalizedDescriptionKey: @"Invalid model preparation flag"}];
            return nil;
        }
    }
    NSError *dbErr = nil;
    IPhoneModelDB *modelDB = [IPhoneModelDB sharedManager];
    IOSBuildDB *buildDB = [IOSBuildDB sharedManager];
    if (![modelDB loadIfNeeded:&dbErr] || ![buildDB loadIfNeeded:&dbErr]) {
        if (error) *error = dbErr;
        PXLog(@"[WeaponX] ⚠️ DeviceProfileGroup: DB not available (%@)", dbErr.localizedDescription ?: @"unknown");
        PXDBLog(@"DeviceProfileGroup: DB not available err=%@", dbErr.localizedDescription ?: @"nil");
        return nil;
    }

    BOOL webCompat = [options[@"webCompat"] boolValue];

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
        if (error) *error = dbErr;
        PXLog(@"[WeaponX] ❌ DeviceProfileGroup: failed to pick model (%@)", dbErr.localizedDescription ?: @"unknown");
        PXDBLog(@"DeviceProfileGroup: failed to pick model err=%@", dbErr.localizedDescription ?: @"nil");
        return nil;
    }

    if (!productType.length || !maxIOS.length) {
        if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6002 userInfo:@{NSLocalizedDescriptionKey: @"Invalid model spec (missing productType/maxIOS)"}];
        PXDBLog(@"DeviceProfileGroup: invalid modelSpec missing productType/maxIOS spec=%@", modelSpec);
        return nil;
    }

    if (!iosMeta) {
        if (error) *error = dbErr ?: [NSError errorWithDomain:@"com.hydra.tlinkios" code:6005 userInfo:@{NSLocalizedDescriptionKey: @"No compatible iOS build found for chosen model"}];
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
        if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6003 userInfo:@{NSLocalizedDescriptionKey: @"Invalid iOS meta (missing required fields)"}];
        PXDBLog(@"DeviceProfileGroup: invalid iosMeta device=%@ meta=%@", productType, iosMeta);
        return nil;
    }

    // P0: versioned model data is authoritative for model-dependent hardware.
    // Do not reconstruct RAM/display/camera/storage from ProductType prefixes here.
    NSDictionary *hardwareSpecs = [modelDB canonicalHardwareSpecForProductType:productType];
    if (!hardwareSpecs.count) {
        if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6006 userInfo:@{NSLocalizedDescriptionKey: @"Canonical hardware metadata missing for model"}];
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
        if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6007 userInfo:@{NSLocalizedDescriptionKey: @"Canonical hardware variant missing for model"}];
        PXDBLog(@"DeviceProfileGroup: missing variant device=%@ spec=%@", productType, modelSpec);
        return nil;
    }

    // Regulatory A-number is selected from the exact same hardware variant.
    // Retail ModelNumber is a separate SKU identity and remains unset until
    // authoritative SKU data is available.
    NSString *regulatoryModelNumber = PXPickRegulatoryModelNumberFromModelSpec(modelSpec, pickedVariant);
    if ([pickedVariant[@"regulatoryModelNumbers"] isKindOfClass:[NSArray class]] &&
        [pickedVariant[@"regulatoryModelNumbers"] count] > 0 && !regulatoryModelNumber.length) {
        if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6008 userInfo:@{NSLocalizedDescriptionKey: @"Canonical regulatory model number missing for selected variant"}];
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
                if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios"
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

    // Prepare only owned fields. Merge against current IDs under the gate so
    // unrelated writers cannot be overwritten by a pre-generation file copy.
    NSMutableDictionary *deviceIds = [NSMutableDictionary dictionary];

    // Replace this ownership set against the latest IDs at commit time.
    NSArray<NSString *> *managedKeys = PXDeviceProfileManagedKeys();

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
                                             [options[@"wantsIMEI"] boolValue],
                                             [options[@"wantsMEID"] boolValue],
                                             &cellularError)) {
        if (error) *error = cellularError ?: [NSError errorWithDomain:@"com.hydra.tlinkios"
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

    deviceIds[@"CommittedAt"] = now;

    NSDictionary *version = @{ @"version": iosVersion, @"build": iosBuild, @"darwin": darwin,
        @"xnu": xnu, @"kernel_version": kernel, @"lastUpdated": now };
    return [[PXPreparedDeviceProfileGroup alloc] initWithUpdates:deviceIds replacedKeys:managedKeys versionInfo:version error:error];
}

- (NSString *)generateDeviceModel {
    // Compatibility API: DeviceModel is a dependency group, not an independent
    // random value. Route every caller through the canonical atomic generator.
    return [self regenerateDeviceProfileGroup];
}

- (BOOL)validateCustomDeviceModel:(NSString *)value error:(NSError **)error {
    if (error) *error = nil;
    BOOL isIPhone = [value isKindOfClass:[NSString class]] && [value hasPrefix:@"iPhone"];
    // P0 ownership rule: every iPhone must exist in the canonical model DB.
    // DeviceModelManager remains a compatibility source only for non-iPhone models.
    BOOL valid = isIPhone ? [[IPhoneModelDB sharedManager] containsProductType:value]
                          : [[DeviceModelManager sharedManager] isValidDeviceModel:value];
    if (!valid) {
        if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:2003 userInfo:@{NSLocalizedDescriptionKey: @"Invalid Device Model"}];
        return NO;
    }
    return YES;
}

- (PXPreparedDeviceProfileGroup *)prepareCustomDeviceModel:(NSString *)value error:(NSError **)error {
    // The caller validates membership once before this side-effect-free builder.
    if (error) *error = nil;
    value = [value copy];
    DeviceModelManager *deviceManager = [DeviceModelManager sharedManager];
    IPhoneModelDB *modelDB = [IPhoneModelDB sharedManager];
    NSDictionary *modelSpec = [modelDB specForProductType:value];
    NSDictionary *dbHardwareSpecs = modelSpec ? [modelDB canonicalHardwareSpecForProductType:value] : nil;
    NSDictionary *legacySpecs = [deviceManager deviceSpecificationsForModel:value] ?: @{};
    NSDictionary *hardwareSpecs = dbHardwareSpecs.count ? dbHardwareSpecs : legacySpecs;

    // DB-backed iPhone models must resolve P0 hardware from canonical data. The
    // legacy manager is retained only for models not yet present in the DB.
    if (modelSpec && !dbHardwareSpecs.count) {
        if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:2004 userInfo:@{NSLocalizedDescriptionKey: @"Canonical hardware metadata missing for Device Model"}];
        return nil;
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
        if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:2005 userInfo:@{NSLocalizedDescriptionKey: @"Canonical hardware variant missing for Device Model"}];
        return nil;
    }
    if (!modelSpec) {
        boardID = PXProfileString(hardwareSpecs[@"boardID"]);
        hwModel = PXProfileString(hardwareSpecs[@"hwModel"]);
    }

    // Update the combined device_ids.plist
    NSMutableDictionary *deviceIds = [NSMutableDictionary dictionary];

    // Add all device specifications to the device_ids.plist
    deviceIds[@"DeviceModel"] = value ?: @"";
    deviceIds[@"DeviceModelName"] = deviceModelName ?: @"";
    deviceIds[@"ScreenResolution"] = screenResolution ?: @"";
    deviceIds[@"ViewportResolution"] = viewportResolution ?: @"";
    deviceIds[@"DevicePixelRatio"] = @(devicePixelRatio);
    if (nativeScale > 0.0) deviceIds[@"NativeScale"] = @(nativeScale);
    deviceIds[@"ScreenDensityPPI"] = @(screenDensity);
    deviceIds[@"CPUArchitecture"] = cpuArchitecture ?: @"";
    if (cpuProfileKey.length) deviceIds[@"CPUProfileKey"] = cpuProfileKey;
    deviceIds[@"DeviceMemory"] = @(deviceMemory);
    deviceIds[@"CPUCoreCount"] = @(cpuCoreCount);
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

    return [[PXPreparedDeviceProfileGroup alloc] initWithUpdates:deviceIds replacedKeys:PXDeviceProfileManagedKeys() versionInfo:@{} error:error];
}

- (BOOL)setCustomDeviceModel:(NSString *)value {
    if ([value isKindOfClass:NSString.class]) value = [value copy];
    NSError *error = nil;
    if (![self validateCustomDeviceModel:value error:&error]) { self.error = error; return NO; }
    PXProfileArtifactMutation *mutation = [self currentIdentifierMutation];
    if (!mutation) return NO;
    @try {
        PXPreparedDeviceProfileGroup *prepared = [self prepareCustomDeviceModel:value error:&error];
        if (!prepared) { self.error = error; return NO; }
        BOOL success = [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
            return PXStageRuntimeIdentifierReplacement(tx, mutation.identityDirectory, prepared.updates, prepared.replacedKeys, nil, NO, YES, writeError);
        } error:&error];
        self.error = success ? nil : error;
        if (!success) return NO;
    } @finally { [mutation invalidate]; }
    [[DeviceModelManager sharedManager] setCurrentDeviceModel:value];
    return YES;
}


- (BOOL)applyDashboardPreview:(NSDictionary *)preview error:(NSError **)error {
    if (error) *error = nil;
    self.error = nil;
    if (![preview isKindOfClass:NSDictionary.class] || !preview.count) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios.dashboard" code:7001 userInfo:@{NSLocalizedDescriptionKey: @"Empty dashboard preview"}];
        if (error) *error = self.error; return NO;
    }
    NSArray *keys = @[ @"DeviceName", @"DeviceModel", @"DeviceModelName",
        @"IOSVersion", @"IOSBuild", @"Darwin", @"XNU", @"KernelVersion",
        @"CountryCode", @"CountryName", @"CarrierName", @"CarrierMCC", @"CarrierMNC",
        @"RegulatoryModelNumber", @"BoardID", @"HwModel", @"SerialNumber", @"MACAddress" ];
    NSMutableDictionary *resolved = [NSMutableDictionary dictionary];
    for (NSString *key in [keys arrayByAddingObject:@"IOSProductType"]) {
        id value = preview[key];
        if ([value isKindOfClass:NSString.class]) resolved[key] = [value copy];
    }
    PXProfileArtifactMutation *mutation = [self currentIdentifierMutation];
    BOOL committed = NO;
    NSString *model = nil;
    StorageManager *storageManager = nil;
    NSDictionary *storage = nil;
    @try {
        if (!mutation) return NO;
        NSDictionary *basis = [self captureDeviceIDsAtIdentityDirectory:mutation.identityDirectory];
        if (!basis) return NO;
        model = resolved[@"DeviceModel"];
        NSString *requestedVersion = resolved[@"IOSVersion"], *tupleProduct = resolved[@"IOSProductType"];
        NSString *targetProduct = model.length ? model : PXProfileString(basis[@"DeviceModel"]);
        if (!model.length && requestedVersion.length && tupleProduct.length) model = targetProduct = tupleProduct;
        BOOL complete = requestedVersion.length;
        for (NSString *key in @[@"IOSBuild", @"Darwin", @"XNU", @"KernelVersion"])
            complete = complete && [resolved[key] length] > 0;
        if (requestedVersion.length && targetProduct.length && (!complete || ![tupleProduct isEqualToString:targetProduct])) {
            NSError *tupleError = nil;
            NSDictionary *meta = [[IOSBuildDB sharedManager] randomMetaForDevice:targetProduct min:requestedVersion max:requestedVersion error:&tupleError];
            if (![meta isKindOfClass:NSDictionary.class]) meta = nil;
            NSArray *tupleKeys = @[@"IOSVersion", @"IOSBuild", @"Darwin", @"XNU", @"KernelVersion"];
            NSArray *metaKeys = @[@"version", @"build", @"darwin", @"xnu", @"kernel_version"];
            for (NSUInteger i = 0; i < tupleKeys.count; i++) {
                id value = meta[metaKeys[i]];
                resolved[tupleKeys[i]] = [value isKindOfClass:NSString.class] ? [value copy] : @"";
            }
            complete = meta != nil;
            for (NSString *key in tupleKeys) complete = complete && [resolved[key] length] > 0;
            if (!complete) {
                self.error = tupleError ?: [NSError errorWithDomain:@"com.hydra.tlinkios.dashboard" code:7002 userInfo:@{NSLocalizedDescriptionKey: @"Refusing partial iOS override"}];
                return NO;
            }
        }
        if (requestedVersion.length && (!targetProduct.length || !complete)) {
            self.error = [NSError errorWithDomain:@"com.hydra.tlinkios.dashboard" code:7002 userInfo:@{NSLocalizedDescriptionKey: @"Refusing partial iOS override without target model"}]; return NO;
        }
        NSString *name = resolved[@"DeviceName"], *serial = resolved[@"SerialNumber"];
        if (serial.length && serial.length < 8) {
            self.error = [NSError errorWithDomain:@"com.hydra.tlinkios.dashboard" code:7003 userInfo:@{NSLocalizedDescriptionKey: @"Invalid dashboard serial number"}]; return NO;
        }
        NSError *preparationError = nil;
        if (model.length && ![self validateCustomDeviceModel:model error:&preparationError]) { self.error = preparationError; return NO; }
        if (model.length && [self isIdentifierEnabled:@"StorageSystem"]) {
            storageManager = [StorageManager sharedManager];
            NSString *capacity = [storageManager randomizeStorageCapacityForDeviceModel:model];
            NSDictionary *generated = [storageManager generateStorageForCapacity:capacity];
            if (![generated[@"TotalStorage"] isKindOfClass:NSString.class] || ![generated[@"FreeStorage"] isKindOfClass:NSString.class]) {
                self.error = [NSError errorWithDomain:@"com.hydra.tlinkios.dashboard" code:7004 userInfo:@{NSLocalizedDescriptionKey: @"Dashboard storage preparation failed"}]; return NO;
            }
            NSMutableDictionary *merged = [[storageManager currentStorageInfo] mutableCopy];
            if (!merged) merged = [NSMutableDictionary dictionary];
            merged[@"TotalStorage"] = generated[@"TotalStorage"];
            merged[@"FreeStorage"] = generated[@"FreeStorage"];
            merged[@"FilesystemType"] = generated[@"FilesystemType"] ?: @"0x1A";
            storage = merged;
        }
        PXPreparedDeviceProfileGroup *preparedModel = model.length ? [self prepareCustomDeviceModel:model error:&preparationError] : nil;
        if (model.length && !preparedModel) { self.error = preparationError; return NO; }
        NSMutableDictionary *updates = [NSMutableDictionary dictionary];
        for (NSString *key in keys) if ([resolved[key] length]) updates[key] = resolved[key];
        if ([resolved[@"MACAddress"] length]) updates[@"WiFiAddress"] = resolved[@"MACAddress"];
        updates[@"CommittedAt"] = [NSDate date];
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:@{ @"updates": updates, @"storage": storage ?: @{} }
            format:NSPropertyListBinaryFormat_v1_0 options:0 error:&preparationError];
        NSDictionary *packet = data ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&preparationError] : nil;
        if (!packet) { self.error = preparationError; return NO; }
        if (storage) storage = packet[@"storage"];
        NSDictionary *expected = PXRuntimeIdentifierDependencies(basis, requestedVersion.length && !model.length ? @[@"DeviceModel"] : @[]);
        NSDate *timestamp = packet[@"updates"][@"CommittedAt"];
        NSError *writeError = nil;
        committed = [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **stageError) {
            NSString *identity = mutation.identityDirectory;
            if (!PXStageRuntimeIdentifierReplacement(tx, identity, @{}, @[], expected, NO, NO, stageError)) return NO;
            if (preparedModel && !PXStageRuntimeIdentifierReplacement(tx, identity, preparedModel.updates, preparedModel.replacedKeys, nil, NO, YES, stageError)) return NO;
            if (name.length && !PXStageRuntimeIdentifierValue(tx, identity, @"DeviceName", packet[@"updates"][@"DeviceName"], timestamp, YES, stageError)) return NO;
            if (serial.length && !PXStageRuntimeIdentifierValue(tx, identity, @"SerialNumber", packet[@"updates"][@"SerialNumber"], timestamp, YES, stageError)) return NO;
            if (!PXStageRuntimeIdentifierState(tx, identity, packet[@"updates"], @{}, YES, stageError)) return NO;
            return !storage || [tx setDictionary:storage atPath:[mutation.profileDirectory stringByAppendingPathComponent:@"storage.plist"] error:stageError];
        } error:&writeError];
        self.error = committed ? nil : writeError;
    } @finally {
        [mutation invalidate];
        if (!committed && error) *error = self.error;
    }
    if (!committed) return NO;
    // Commit acknowledgement is independent of best-effort cache publication.
    if (model.length) {
        @try { [[DeviceModelManager sharedManager] setCurrentDeviceModel:model]; }
        @catch (NSException *exception) { PXLog(@"[Dashboard] Source committed; model cache publication failed: %@", exception); }
    }
    if (storage) {
        @try { [storageManager adoptCommittedStorageInfo:storage]; }
        @catch (NSException *exception) { PXLog(@"[Dashboard] Source committed; storage cache publication failed: %@", exception); }
    }
    return YES;
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
    PX_IDENTIFIER_RUNTIME_READ_OPERATION;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    // The manager mutates the live active profile before the daemon has had a
    // chance to republish its runtime snapshot. Reading the snapshot here can
    // therefore redirect a reset/regeneration into the previously active
    // profile. Only injected hosts should prefer the sandbox-safe mirror.
    NSString *profileID = nil;
    if (!PXIdentifierManagerIsManagerProcess()) {
        return PXCaptureRuntimeSnapshot().profileID;
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
    NSString *profileID = [[self getActiveProfileId] copy];
    NSString *identityDir = PXProfileIdentityPath(profileID);
    if (!identityDir.length) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:2001 userInfo:@{NSLocalizedDescriptionKey: @"No valid active profile identity target"}];
        return nil;
    }
    // Current-schema readers retain the live-file fast path without ownership.
    NSDictionary *ids = [NSDictionary dictionaryWithContentsOfFile:[identityDir stringByAppendingPathComponent:@"device_ids.plist"]];
    id schema = ids[@"ProfileSchemaVersion"];
    if ([schema respondsToSelector:@selector(integerValue)] && [schema integerValue] >= 2) return identityDir;

    NSError *error = nil;
    PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:PXProfilesPath() error:&error];
    @try {
        if (!lease) { self.error = error; return nil; }
        // A reader observed the target before ownership; reject a selection move.
        if (![[self getActiveProfileId] isEqualToString:profileID]) {
            self.error = [NSError errorWithDomain:@"WeaponXProfileError" code:20 userInfo:@{NSLocalizedDescriptionKey: @"Profile selection changed before migration"}];
            return nil;
        }
        return [self prepareProfileIdentityForProfileID:profileID lifecycleLease:lease];
    } @finally { [lease invalidate]; }
}

- (NSString *)profileIdentityPathWithLifecycleLease:(PXProfileLifecycleLease *)lease {
    return [self prepareProfileIdentityForProfileID:[[self getActiveProfileId] copy] lifecycleLease:lease];
}

- (NSString *)prepareProfileIdentityForProfileID:(NSString *)profileID lifecycleLease:(PXProfileLifecycleLease *)lease {
    NSError *error = nil;
    if (![lease isKindOfClass:PXProfileLifecycleLease.class] || ![lease validateForDirectory:PXProfilesPath() error:&error] || !PXRequireNoPendingProfileDeletion(&error)) {
        self.error = error ?: [NSError errorWithDomain:@"WeaponXProfileError" code:25 userInfo:@{NSLocalizedDescriptionKey: @"Missing profile migration capability"}];
        return nil;
    }
    NSString *identityDir = PXProfileIdentityPath([profileID copy]);
    if (!identityDir.length) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:2001 userInfo:@{NSLocalizedDescriptionKey: @"No valid active profile identity target"}];
        return nil;
    }
    // Keep legacy directory repair, now after lifecycle/recovery preflight.
    if (![NSFileManager.defaultManager fileExistsAtPath:identityDir]) {
        NSDictionary *attributes = @{NSFilePosixPermissions: @0755, NSFileOwnerAccountName: @"mobile"};
        if (![NSFileManager.defaultManager createDirectoryAtPath:identityDir withIntermediateDirectories:YES attributes:attributes error:&error]) {
            self.error = error; return nil;
        }
    }
    NSDictionary *ids = [NSDictionary dictionaryWithContentsOfFile:[identityDir stringByAppendingPathComponent:@"device_ids.plist"]];
    id schema = ids[@"ProfileSchemaVersion"];
    if (![schema respondsToSelector:@selector(integerValue)] || [schema integerValue] < 2) {
        if (![self migrateProfileSchemaAtIdentityDirectory:identityDir lifecycleLease:lease]) return nil;
    }
    return identityDir;
}

#pragma mark - Identifier Management

- (PXProfileArtifactMutation *)currentIdentifierMutation {
    self.error = nil;
    NSError *error = nil;
    PXProfileArtifactMutation *mutation = [PXProfileArtifactMutation acquireWithIdentityResolverUsingLease:^NSString *(PXProfileLifecycleLease *lease) {
        return [self profileIdentityPathWithLifecycleLease:lease];
    } error:&error];
    if (!mutation && !self.error) self.error = error;
    return mutation;
}

- (BOOL)persistPreparedIdentifier:(NSString *)value type:(NSString *)type mutation:(PXProfileArtifactMutation *)mutation incrementGeneration:(BOOL)increment {
    if (!mutation) return NO;
    NSDate *timestamp = [NSDate date];
    NSError *writeError = nil;
    BOOL success = [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return PXStageRuntimeIdentifierValue(tx, mutation.identityDirectory, type, value, timestamp, increment, error);
    } error:&writeError];
    self.error = success ? nil : writeError;
    return success;
}

- (NSString *)generatePreparedIdentifierForType:(NSString *)type {
    type = [type copy];
    PXProfileArtifactMutation *mutation = [self currentIdentifierMutation];
    if (!mutation) return nil;
    NSString *value = nil;
    @try {
        NSError *prepareError = nil;
        if ([type isEqualToString:@"SerialNumber"]) {
            value = [[SerialNumberManager sharedManager] prepareSerialNumber];
            if (!value) prepareError = [[SerialNumberManager sharedManager] lastError];
        } else value = PXPrepareRuntimeScalar(type, &prepareError);
        if (!value) { self.error = prepareError; return nil; }
        if (![self persistPreparedIdentifier:value type:type mutation:mutation incrementGeneration:NO]) return nil;
    } @finally { [mutation invalidate]; }
    [self publishPreparedIdentifier:value type:type includeNameAndSerial:YES];
    if ([type hasSuffix:@"UUID"] || [type isEqualToString:@"UDID"]) PXLog(@"[IdentifierManager] Committed %@ for %@", type, mutation.identityDirectory);
    return value;
}

- (NSString *)generateIDFA {
    return [self generatePreparedIdentifierForType:@"IDFA"];
}

- (NSString *)generateIDFV {
    return [self generatePreparedIdentifierForType:@"IDFV"];
}

- (NSString *)generateDeviceName {
    return [self generatePreparedIdentifierForType:@"DeviceName"];
}

- (NSString *)generateSerialNumber {
    return [self generatePreparedIdentifierForType:@"SerialNumber"];
}

- (NSDictionary *)generateIOSVersion {
    PXProfileArtifactMutation *mutation = [self currentIdentifierMutation];
    if (!mutation) return nil;
    @try {
        NSString *identityDir = mutation.identityDirectory;
        NSDictionary *capturedIDs = [self captureDeviceIDsAtIdentityDirectory:identityDir];
        if (!capturedIDs) return nil;
        NSString *deviceModel = PXProfileString(capturedIDs[@"DeviceModel"]);
        if (!deviceModel.length) {
            // Compatibility API: when no model exists, seed the complete dependency
            // group instead of generating an orphan software identity.
            PXPreparedDeviceProfileGroup *prepared = [self commitDeviceProfileGroupWithMutation:mutation];
            if (!prepared) return nil;
            [mutation invalidate];
            [self publishPreparedDeviceProfileGroup:prepared];
            NSDictionary *deviceIds = [self captureDeviceIDsAtIdentityDirectory:identityDir];
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

        // Software identity changes also change build-specific baseband metadata.
        NSString *regulatory = PXProfileString(capturedIDs[@"RegulatoryModelNumber"]) ?: @"";
        NSDictionary *cellularSpec = [modelDB cellularSpecForProductType:deviceModel regulatoryModelNumber:regulatory];
        BOOL cellularEnabled = [cellularSpec[@"known"] isKindOfClass:NSNumber.class] && [cellularSpec[@"known"] boolValue] &&
            [cellularSpec[@"enabled"] isKindOfClass:NSNumber.class] && [cellularSpec[@"enabled"] boolValue];
        NSDictionary *basebandMeta = cellularEnabled ? [modelDB basebandMetaForProductType:deviceModel regulatoryModelNumber:regulatory iosBuild:iosBuild] : nil;
        NSMutableDictionary *deviceIds = [capturedIDs mutableCopy];
        NSError *cellularError = nil;
        if (!PXPopulateCanonicalCellularIdentity(deviceIds, cellularSpec, basebandMeta,
                [self isIdentifierEnabled:@"IMEI"], [self isIdentifierEnabled:@"MEID"], &cellularError)) {
            self.error = cellularError; return nil;
        }
        NSMutableDictionary *updates = [NSMutableDictionary dictionary];
        for (NSString *key in PXCellularManagedKeys()) if (deviceIds[key]) updates[key] = deviceIds[key];
        updates[@"IOSVersion"] = iosVersion;
        updates[@"IOSBuild"] = iosBuild;
        updates[@"Darwin"] = darwin;
        updates[@"XNU"] = xnu;
        updates[@"KernelVersion"] = kernel;
        NSArray *replacedKeys = [PXCellularManagedKeys() arrayByAddingObjectsFromArray:@[@"IOSVersion", @"IOSBuild", @"Darwin", @"XNU", @"KernelVersion"]];
        NSDictionary *expected = PXCellularPreparationDependencies(capturedIDs);
        NSError *sourceError = nil;
        BOOL success = [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
            return PXStageRuntimeIdentifierReplacement(tx, identityDir, updates, replacedKeys, expected, NO, YES, error);
        } error:&sourceError];
        self.error = success ? nil : sourceError;
        if (!success) return nil;

        [mutation invalidate];
        [[IOSVersionInfo sharedManager] setCurrentIOSVersionInfo:versionDict];
        PXLog(@"[WeaponX] ✅ Generated canonical iOS version for %@: %@ (%@)", deviceModel, iosVersion, iosBuild);
        return versionDict;
    } @finally { [mutation invalidate]; }
}

- (NSDictionary *)generateiOSVersion {
    return [self generateIOSVersion];
}

- (NSString *)generateSystemBootUUID {
    return [self generatePreparedIdentifierForType:@"SystemBootUUID"];
}

- (NSString *)generateDyldCacheUUID {
    return [self generatePreparedIdentifierForType:@"DyldCacheUUID"];
}

- (NSString *)generatePasteboardUUID {
    return [self generatePreparedIdentifierForType:@"PasteboardUUID"];
}

- (NSString *)generateKeychainUUID {
    return [self generatePreparedIdentifierForType:@"KeychainUUID"];
}

- (NSString *)generateUserDefaultsUUID {
    return [self generatePreparedIdentifierForType:@"UserDefaultsUUID"];
}

- (NSString *)generateAppGroupUUID {
    return [self generatePreparedIdentifierForType:@"AppGroupUUID"];
}

- (NSString *)generateCoreDataUUID {
    return [self generatePreparedIdentifierForType:@"CoreDataUUID"];
}

- (NSString *)generateSystemUptime {
    return [self generateUptimeCompatibilityForBootTime:NO];
}

- (NSString *)generateBootTime {
    return [self generateUptimeCompatibilityForBootTime:YES];
}

- (NSString *)generateUptimeCompatibilityForBootTime:(BOOL)isBoot {
    PXProfileArtifactMutation *mutation = [self currentIdentifierMutation];
    if (!mutation) return nil;
    UptimeManager *manager = nil;
    NSDictionary *prepared = nil;
    NSDate *bootTime = nil;
    NSTimeInterval uptime = 0;
    @try {
        manager = [UptimeManager sharedManager];
        NSString *identityDir = mutation.identityDirectory;
        if (isBoot) bootTime = [manager currentBootTimeForProfile:identityDir generateIfMissing:NO];
        else uptime = [manager currentUptimeForProfile:identityDir generateIfMissing:NO];
        if (isBoot ? !bootTime : uptime <= 0) {
            prepared = [manager prepareConsistentUptimeInfo];
            bootTime = prepared[@"boot"][@"value"];
            uptime = [prepared[@"seconds"] doubleValue];
            if (!bootTime || uptime <= 0) { self.error = [manager lastError]; return nil; }
        }
        NSString *type = isBoot ? @"BootTime" : @"SystemUptime";
        id value = isBoot ? (id)bootTime : [NSString stringWithFormat:@"%.0f", uptime];
        NSString *scalar = isBoot ? [NSString stringWithFormat:@"%.0f", bootTime.timeIntervalSince1970] : value;
        NSDictionary *info = @{ @"value": value, @"lastUpdated": [NSDate date] };
        NSString *file = isBoot ? @"boot_time.plist" : @"system_uptime.plist";
        NSError *writeError = nil;
        BOOL success = [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
            if (prepared && !PXStageRuntimeUptime(tx, identityDir, prepared[@"boot"], prepared[@"uptime"], prepared[@"boot"][@"lastUpdated"], error)) return NO;
            return PXStageRuntimeIdentifierState(tx, identityDir, @{type: scalar}, @{file: info}, NO, error);
        } error:&writeError];
        self.error = success ? nil : writeError;
        if (!success) return nil;
    } @finally { [mutation invalidate]; }
    if (prepared) [manager adoptCommittedUptimeInfo:prepared timestamp:prepared[@"boot"][@"lastUpdated"]];
    if (!isBoot) return [NSString stringWithFormat:@"%.2f hours", uptime / 3600.0];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterMediumStyle;
    return [formatter stringFromDate:bootTime];
}

- (NSString *)generateAppInstallUUID {
    return [self generatePreparedIdentifierForType:@"AppInstallUUID"];
}

- (NSString *)generateAppContainerUUID {
    return [self generatePreparedIdentifierForType:@"AppContainerUUID"];
}


- (NSDictionary *)prepareCellularRefreshForDeviceIDs:(NSDictionary *)capturedIDs options:(NSDictionary *)options error:(NSError **)error {
    NSMutableDictionary *deviceIds = [capturedIDs mutableCopy];
    NSString *productType = PXProfileString(deviceIds[@"DeviceModel"]);
    NSString *regulatoryModelNumber = PXProfileString(deviceIds[@"RegulatoryModelNumber"]);
    NSString *iosBuild = PXProfileString(deviceIds[@"IOSBuild"]);
    IPhoneModelDB *modelDB = [IPhoneModelDB sharedManager];
    NSDictionary *modelSpec = [modelDB specForProductType:productType];
    if ([productType hasPrefix:@"iPhone"] && !modelSpec) {
        if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                         code:6015
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"Canonical model data is required before cellular identity can be refreshed"}];
        return nil;
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
            if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                             code:6016
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                        @"Authoritative baseband metadata is unavailable for the current cellular tuple"}];
            return nil;
        }
    }

    NSError *cellularError = nil;
    if (!PXPopulateCanonicalCellularIdentity(deviceIds,
                                             cellularSpec,
                                             basebandMeta,
                                             [options[@"wantsIMEI"] boolValue],
                                             [options[@"wantsMEID"] boolValue],
                                             &cellularError)) {
        if (error) *error = cellularError;
        return nil;
    }

    NSMutableDictionary *updates = [NSMutableDictionary dictionary];
    for (NSString *key in PXCellularManagedKeys()) if (deviceIds[key]) updates[key] = deviceIds[key];
    updates[@"CommittedAt"] = [NSDate date];
    return @{ @"updates": updates, @"keys": PXCellularManagedKeys() };
}

- (BOOL)refreshCanonicalCellularIdentityForCurrentProfile {
    PXProfileArtifactMutation *mutation = [self currentIdentifierMutation];
    if (!mutation) return NO;
    @try {
        NSString *identityDir = mutation.identityDirectory;
        NSDictionary *capturedIDs = [self captureDeviceIDsAtIdentityDirectory:identityDir];
        if (!capturedIDs) return NO;
        if (!PXProfileString(capturedIDs[@"DeviceModel"]).length ||
            !PXProfileString(capturedIDs[@"RegulatoryModelNumber"]).length || !PXProfileString(capturedIDs[@"IOSBuild"]).length) {
            PXPreparedDeviceProfileGroup *prepared = [self commitDeviceProfileGroupWithMutation:mutation];
            [mutation invalidate];
            if (prepared) [self publishPreparedDeviceProfileGroup:prepared];
            return prepared != nil;
        }
        NSDictionary *options = @{ @"wantsIMEI": @([self isIdentifierEnabled:@"IMEI"]), @"wantsMEID": @([self isIdentifierEnabled:@"MEID"]) };
        NSError *sourceError = nil;
        NSDictionary *prepared = [self prepareCellularRefreshForDeviceIDs:capturedIDs options:options error:&sourceError];
        if (!prepared) { self.error = sourceError; return NO; }
        NSDictionary *expected = PXCellularPreparationDependencies(capturedIDs);
        BOOL success = [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
            return PXStageRuntimeIdentifierReplacement(tx, identityDir, prepared[@"updates"], prepared[@"keys"], expected, YES, YES, error);
        } error:&sourceError];
        self.error = success ? nil : sourceError;
        return success;
    } @finally { [mutation invalidate]; }
}

- (void)regenerateAllEnabledIdentifiers {
    NSError *error = nil;
    if (![self regenerateAllEnabledIdentifiersWithError:&error])
        PXLog(@"[IdentifierManager] Generation aborted: %@", error);
}

- (BOOL)regenerateAllEnabledIdentifiersWithError:(NSError **)error {
    PXCommittedRuntimeGeneration *receipt = [self ownedRuntimeGenerationForProfileID:nil currentProfile:YES networkArtifacts:nil deferSettings:NO error:error];
    if (!receipt) return NO;
    [self publishCommittedRuntimeGeneration:receipt]; // Ownership is released before compatibility callbacks.
    return YES;
}

- (PXCommittedRuntimeGeneration *)ownedRuntimeGenerationForProfileID:(NSString *)profileID currentProfile:(BOOL)current networkArtifacts:(NSDictionary *)networkArtifacts deferSettings:(BOOL)deferSettings error:(NSError **)error {
    if (error) *error = nil;
    NSError *failure = nil;
    PXCommittedRuntimeGeneration *receipt = nil;
    PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:PXProfilesPath() error:&failure];
    @try {
        if (lease && [lease validateForDirectory:PXProfilesPath() error:&failure] && PXRequireNoPendingProfileDeletion(&failure)) {
            NSString *identity = current ? [[self profileIdentityPathWithLifecycleLease:lease] copy] : [self existingGenerationIdentityForProfileID:profileID lifecycleLease:lease error:&failure];
            if (identity.length) [self commitRuntimeGenerationAtIdentityDirectory:identity networkArtifacts:networkArtifacts lifecycleLease:lease deferSettings:deferSettings receipt:&receipt error:&failure];
            else if (!failure) failure = self.error;
        }
    } @catch (NSException *exception) {
        failure = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6030 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Runtime generation preparation raised an exception"}];
    } @finally { [lease invalidate]; }
    if (!receipt && !failure) failure = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6030 userInfo:@{NSLocalizedDescriptionKey: @"Runtime generation did not complete under lifecycle ownership"}];
    self.error = receipt ? nil : failure;
    if (!receipt && error) *error = failure;
    return receipt;
}

- (NSString *)existingGenerationIdentityForProfileID:(NSString *)profileID lifecycleLease:(PXProfileLifecycleLease *)lease error:(NSError **)error {
    if (error) *error = nil;
    NSString *identityDir = PXProfileIdentityPath(PXValidatedProfileID(profileID));
    BOOL directory = NO;
    if (!identityDir.length || ![NSFileManager.defaultManager fileExistsAtPath:identityDir isDirectory:&directory] || !directory) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6001 userInfo:@{NSLocalizedDescriptionKey: @"Explicit profile identity directory does not exist"}];
        if (error) *error = self.error; return nil;
    }
    if (![self migrateProfileSchemaAtIdentityDirectory:identityDir lifecycleLease:lease]) { if (error) *error = self.error; return nil; }
    return identityDir;
}

- (BOOL)regenerateAllEnabledIdentifiersForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)networkArtifacts error:(NSError **)error {
    PXCommittedRuntimeGeneration *receipt = [self ownedRuntimeGenerationForProfileID:profileID currentProfile:NO networkArtifacts:networkArtifacts deferSettings:NO error:error];
    if (!receipt) return NO;
    [self publishCommittedRuntimeGeneration:receipt];
    return YES;
}

- (PXCommittedRuntimeGeneration *)commitRuntimeGenerationForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)networkArtifacts error:(NSError **)error {
    return [self ownedRuntimeGenerationForProfileID:profileID currentProfile:NO networkArtifacts:networkArtifacts deferSettings:YES error:error];
}

- (PXCommittedRuntimeGeneration *)commitRuntimeGenerationForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)networkArtifacts lifecycleLease:(PXProfileLifecycleLease *)lease error:(NSError **)error {
    if (error) *error = nil;
    NSError *failure = nil;
    PXCommittedRuntimeGeneration *receipt = nil;
    @try {
        BOOL validLease = [lease isKindOfClass:PXProfileLifecycleLease.class] && [lease validateForDirectory:PXProfilesPath() error:&failure];
        if (!validLease && !failure) failure = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6030 userInfo:@{NSLocalizedDescriptionKey: @"Creation generation requires its caller's lifecycle capability"}];
        if (validLease && PXRequireNoPendingProfileDeletion(&failure)) {
            NSString *identity = [self existingGenerationIdentityForProfileID:profileID lifecycleLease:lease error:&failure];
            if (identity) [self commitRuntimeGenerationAtIdentityDirectory:identity networkArtifacts:networkArtifacts lifecycleLease:lease deferSettings:YES receipt:&receipt error:&failure];
        }
    } @catch (NSException *exception) {
        failure = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6030 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Creation generation preparation raised an exception"}];
    }
    // The caller retains lifecycle ownership across generation/metadata/activation.
    if (!receipt && !failure) failure = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6030 userInfo:@{NSLocalizedDescriptionKey: @"Creation generation did not complete"}];
    self.error = receipt ? nil : failure;
    if (!receipt && error) *error = failure;
    return receipt;
}

- (void)publishCommittedRuntimeGeneration:(PXCommittedRuntimeGeneration *)generation {
    if (![generation isKindOfClass:PXCommittedRuntimeGeneration.class]) { PXPostSettingsChangedNotification(); return; }
    // Activation already checked the full proof. Recheck artifacts before
    // knowingly installing a stale candidate; defaults/scope were just advanced.
    NSMutableDictionary *artifactProof = [generation.proof mutableCopy];
    if ([generation.payload[@"deferSettings"] boolValue]) {
        [artifactProof removeObjectsForKeys:@[generation.payload[@"settingsPath"], generation.payload[@"scopePath"]]];
    }
    BOOL current = [generation isKindOfClass:PXCommittedRuntimeGeneration.class] && PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return PXRuntimeGenerationMatchesProof(tx, artifactProof, error);
    }, NULL);
    if (current) [self publishRuntimeGeneration:generation.payload identityDirectory:generation.identityDirectory model:generation.model];
    else PXPostSettingsChangedNotification(); // Wake readers for the latest committed state.
}

- (BOOL)commitRuntimeGenerationAtIdentityDirectory:(NSString *)identityDir networkArtifacts:(NSDictionary *)networkArtifacts lifecycleLease:(PXProfileLifecycleLease *)lease deferSettings:(BOOL)deferSettings receipt:(PXCommittedRuntimeGeneration **)receipt error:(NSError **)error {
    if (error) *error = nil;
    if (receipt) *receipt = nil;
    self.error = nil;
    identityDir = [identityDir copy];
    NSError *failure = nil;
    if (!identityDir.length) {
        failure = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6001 userInfo:@{NSLocalizedDescriptionKey: @"Could not resolve profile identity path"}];
        self.error = failure; if (error) *error = failure; return NO;
    }
    if (![lease isKindOfClass:PXProfileLifecycleLease.class] || ![lease validateForDirectory:PXProfilesPath() error:&failure] || !PXRequireNoPendingProfileDeletion(&failure)) {
        failure = failure ?: [NSError errorWithDomain:@"com.hydra.tlinkios" code:6030 userInfo:@{NSLocalizedDescriptionKey: @"Missing runtime generation lifecycle ownership"}];
        self.error = failure; if (error) *error = failure; return NO;
    }
    NSString *profileID = identityDir.stringByDeletingLastPathComponent.lastPathComponent;
    NSDictionary *directoryProof = [lease directoryProofForProfileID:profileID error:&failure];
    if (![PXProfileIdentityPath(PXValidatedProfileID(profileID)) isEqual:identityDir] || ![directoryProof[@"exists"] boolValue]) {
        failure = failure ?: [NSError errorWithDomain:@"com.hydra.tlinkios" code:6030 userInfo:@{NSLocalizedDescriptionKey: @"Runtime generation target directory is unavailable"}];
        self.error = failure; if (error) *error = failure; return NO;
    }
    // Freeze caller intent before any provider callback. Dirty in-memory options
    // still flush with this operation, as saveSettings did in the legacy flow.
    NSDictionary *scope = self.scopedApps;
    NSDictionary *intent = [scope isKindOfClass:NSDictionary.class] ?
        PXDetachRuntimeGeneration(@{ @"flags": PXSanitizedIdentifierSettings(self.settings), @"scope": scope,
            @"network": networkArtifacts ?: @{} }, &failure) : nil;
    if (!intent) {
        failure = failure ?: [NSError errorWithDomain:@"com.hydra.tlinkios" code:6024 userInfo:@{NSLocalizedDescriptionKey: @"Invalid generation scope"}];
        self.error = failure; if (error) *error = failure; return NO;
    }
    NSDictionary *flags = intent[@"flags"];
    NSDictionary *network = intent[@"network"];
    if (![network isKindOfClass:NSDictionary.class] ||
        (network[@"carrier"] && ![network[@"carrier"] isKindOfClass:NSDictionary.class]) ||
        (network[@"ipv4"] && ![network[@"ipv4"] isKindOfClass:NSString.class]) ||
        (network[@"ipv6"] && ![network[@"ipv6"] isKindOfClass:NSString.class])) {
        failure = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6025 userInfo:@{NSLocalizedDescriptionKey: @"Invalid prepared network artifacts"}];
        self.error = failure; if (error) *error = failure; return NO;
    }
    if (network[@"carrier"]) for (NSString *key in @[@"carrierName", @"mcc", @"mnc"])
        if (![network[@"carrier"][key] isKindOfClass:NSString.class]) {
            failure = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6025 userInfo:@{NSLocalizedDescriptionKey: @"Invalid prepared carrier fields"}];
            self.error = failure; if (error) *error = failure; return NO;
        }
    NSString *profileRoot = identityDir.stringByDeletingLastPathComponent;
    NSString *idsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
    NSString *settingsPath = PXTLinkIOSSettingsPath(), *scopePath = PXGlobalScopePath();
    NSString *storagePath = [profileRoot stringByAppendingPathComponent:@"storage.plist"];
    NSString *batteryPath = [identityDir stringByAppendingPathComponent:@"battery_info.plist"];
    NSString *legacyBatteryPath = [profileRoot stringByAppendingPathComponent:@"battery_info.plist"];
    NSString *securityPath = PXSecuritySettingsPath();
    NSString *networkPath = [identityDir stringByAppendingPathComponent:@"network_settings.plist"];
    __block NSMutableDictionary *basis = [NSMutableDictionary dictionary];
    __block NSMutableDictionary *present = [NSMutableDictionary dictionary];
    BOOL captured = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **readError) {
        NSMutableArray *paths = [@[idsPath, settingsPath, scopePath] mutableCopy];
        if (network.count) [paths addObject:networkPath];
        if ([flags[@"StorageSystem"] boolValue]) [paths addObject:storagePath];
        if ([flags[@"Battery"] boolValue]) [paths addObjectsFromArray:@[batteryPath, legacyBatteryPath]];
        for (NSString *path in paths) {
            BOOL exists = NO;
            NSDictionary *value = [tx dictionaryAtPath:path exists:&exists error:readError];
            if (!value) return NO;
            basis[path] = value; present[path] = @(exists);
        }
        NSDictionary *capturedIDs = basis[idsPath];
        BOOL needsModel = [flags[@"DeviceModel"] boolValue] || [flags[@"IOSVersion"] boolValue] ||
            !PXProfileString(capturedIDs[@"DeviceModel"]).length ||
            (([flags[@"IMEI"] boolValue] || [flags[@"MEID"] boolValue]) &&
             (!PXProfileString(capturedIDs[@"RegulatoryModelNumber"]).length || !PXProfileString(capturedIDs[@"IOSBuild"]).length));
        if (needsModel) {
            NSDictionary *security = [tx dictionaryAtPath:securityPath error:readError];
            if (!security) return NO;
            basis[securityPath] = security;
        }
        return YES;
    }, &failure);
    if (!captured) { self.error = failure; if (error) *error = failure; return NO; }
    NSDictionary *ids = basis[idsPath];
    BOOL wantsCellular = [flags[@"IMEI"] boolValue] || [flags[@"MEID"] boolValue];
    BOOL wantsDeviceProfileGroup = [flags[@"DeviceModel"] boolValue] || [flags[@"IOSVersion"] boolValue];
    BOOL needsBaseline = !PXProfileString(ids[@"DeviceModel"]).length ||
        (wantsCellular && (!PXProfileString(ids[@"RegulatoryModelNumber"]).length || !PXProfileString(ids[@"IOSBuild"]).length));
    NSDictionary *options = @{ @"webCompat": @((wantsDeviceProfileGroup || needsBaseline) && PXWebCompatIOSRangeEnabled()),
        @"wantsIMEI": flags[@"IMEI"] ?: @NO, @"wantsMEID": flags[@"MEID"] ?: @NO };
    NSDate *now = [NSDate date];
    NSMutableDictionary *candidate = [@{ @"timestamp": now, @"flags": flags, @"scope": intent[@"scope"],
        @"settingsPath": settingsPath, @"scopePath": scopePath, @"network": network, @"deferSettings": @(deferSettings) } mutableCopy];
    PXPreparedDeviceProfileGroup *model = nil;
    if (wantsDeviceProfileGroup || needsBaseline) {
        model = [self prepareDeviceProfileGroupWithOptions:options error:&failure];
        if (model) candidate[@"model"] = @{ @"updates": model.updates, @"keys": model.replacedKeys, @"version": model.versionInfo };
    } else if (wantsCellular) {
        NSDictionary *cellular = [self prepareCellularRefreshForDeviceIDs:ids options:options error:&failure];
        if (cellular) candidate[@"cellular"] = cellular;
    }
    if ((((wantsDeviceProfileGroup || needsBaseline) && !model) ||
         (wantsCellular && !model && !candidate[@"cellular"])) && !failure)
        failure = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6021 userInfo:@{NSLocalizedDescriptionKey: @"Model preparation failed"}];
    NSMutableDictionary *scalars = [NSMutableDictionary dictionary];
    for (NSString *type in PXRuntimeGenerationScalarTypes()) {
        if (failure || ![flags[type] boolValue]) continue;
        NSString *value;
        if ([type isEqualToString:@"SerialNumber"]) {
            SerialNumberManager *serial = [SerialNumberManager sharedManager];
            value = [serial prepareSerialNumber];
            if (!value) failure = [serial lastError];
        } else value = PXPrepareRuntimeScalar(type, &failure);
        if (!value && !failure) failure = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6022 userInfo:@{NSLocalizedDescriptionKey: @"Scalar preparation failed"}];
        if (value) scalars[type] = value;
    }
    candidate[@"scalars"] = scalars;
    // WiFi generation has always been unconditional in this entry point.
    if (!failure) candidate[@"wifi"] = PXPrepareRuntimeWiFiInfo();
    id theme = ids[@"DeviceTheme"];
    if ([flags[@"DeviceTheme"] boolValue] || (![theme isKindOfClass:NSString.class] && ![theme isKindOfClass:NSNumber.class]))
        candidate[@"theme"] = arc4random_uniform(2) == 0 ? @"Light" : @"Dark";
    if (!failure && ([flags[@"SystemUptime"] boolValue] || [flags[@"BootTime"] boolValue])) {
        struct timeval boot = {0}; size_t size = sizeof(boot); int mib[2] = {CTL_KERN, KERN_BOOTTIME};
        BOOL hasReal = sysctl(mib, 2, &boot, &size, NULL, 0) == 0;
        candidate[@"uptime"] = PXPrepareRuntimeUptime(now, hasReal ? now.timeIntervalSince1970 - boot.tv_sec : 0, hasReal);
    }
    if (!failure && [flags[@"StorageSystem"] boolValue]) {
        NSString *product = model ? model.updates[@"DeviceModel"] : PXProfileString(ids[@"DeviceModel"]);
        // The prepared model already owns a detached canonical hardware packet.
        NSDictionary *spec = model ? @{ @"storageCapacitiesGB": model.updates[@"StorageCapacitiesGB"] ?: @[] } : nil;
        if (!model) {
            IPhoneModelDB *db = [IPhoneModelDB sharedManager];
            spec = [db specForProductType:product] ? [db canonicalHardwareSpecForProductType:product] : nil;
        }
        if ([product hasPrefix:@"iPhone"] && !spec.count)
            failure = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6023 userInfo:@{NSLocalizedDescriptionKey: @"Canonical storage specification unavailable"}];
        else {
            if (!spec.count) spec = [[DeviceModelManager sharedManager] deviceSpecificationsForModel:product];
            NSString *capacity = PXChooseRuntimeStorageCapacity(spec[@"storageCapacitiesGB"], basis[storagePath][@"TotalStorage"]);
            NSDictionary *storage = PXPrepareRuntimeStorage(capacity);
            if (storage) candidate[@"storage"] = storage;
            else failure = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6023 userInfo:@{NSLocalizedDescriptionKey: @"Storage preparation failed"}];
        }
    }
    if (!failure && [flags[@"Battery"] boolValue]) {
        NSDictionary *battery = [present[batteryPath] boolValue] ? basis[batteryPath] :
            ([present[legacyBatteryPath] boolValue] ? basis[legacyBatteryPath] :
             [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.weaponx.battery.plist"]);
        id lowPowerMode = battery[@"LowPowerMode"];
        NSDictionary *info = PXPrepareRuntimeBatteryInfo([lowPowerMode respondsToSelector:@selector(boolValue)] && [lowPowerMode boolValue]);
        candidate[@"batteryUI"] = info;
        candidate[@"battery"] = @{ @"BatteryLevel": info[@"BatteryLevel"], @"LowPowerMode": info[@"LowPowerMode"], @"LastUpdated": now };
    }
    NSDictionary *payload = failure ? nil : PXDetachRuntimeGeneration(candidate, &failure);
    if (!payload) { self.error = failure; if (error) *error = failure; return NO; }
    // Only the dependencies used/replaced by this operation participate. A
    // concurrent network/carrier update and the latest generation counter merge.
    NSMutableSet *keys = [NSMutableSet setWithObject:@"DeviceModel"];
    if (model) [keys addObjectsFromArray:model.replacedKeys];
    else if (payload[@"cellular"]) [keys addObjectsFromArray:PXCellularPreparationDependencies(ids).allKeys];
    [keys addObjectsFromArray:scalars.allKeys];
    [keys addObjectsFromArray:@[@"SSID", @"BSSID", @"DeviceTheme", @"ProfileSchemaVersion"]];
    if (payload[@"uptime"]) [keys addObjectsFromArray:@[@"BootTime", @"SystemUptime"]];
    if (payload[@"battery"]) [keys addObjectsFromArray:@[@"BatteryLevel", @"LowPowerMode"]];
    NSMutableArray *networkKeys = [NSMutableArray array];
    if (network[@"carrier"]) {
        [keys addObjectsFromArray:@[@"CarrierName", @"CarrierMCC", @"CarrierMNC"]];
        [networkKeys addObjectsFromArray:@[@"carrierName", @"mcc", @"mnc"]];
    }
    if (network[@"ipv4"]) { [keys addObject:@"LocalIPAddress"]; [networkKeys addObject:@"localIPAddress"]; }
    NSMutableDictionary *conditions = [@{
        idsPath: @{ @"values": PXRuntimeIdentifierDependencies(ids, keys.allObjects) },
        settingsPath: @{ @"values": PXRuntimeIdentifierDependencies(basis[settingsPath], @[@"EnabledIdentifiers", @"StorageSystemEnabled"]) },
        scopePath: @{ @"values": PXRuntimeIdentifierDependencies(basis[scopePath], @[@"ScopedApps"]) }
    } mutableCopy];
    if (network.count) conditions[networkPath] = @{ @"values": PXRuntimeIdentifierDependencies(basis[networkPath], networkKeys) };
    if (basis[securityPath]) conditions[securityPath] = @{ @"values": PXRuntimeIdentifierDependencies(basis[securityPath], @[@"webCompatIOSRangeEnabled"]) };
    if (payload[@"storage"]) conditions[storagePath] = @{ @"values": PXRuntimeIdentifierDependencies(basis[storagePath], @[@"TotalStorage", @"FreeStorage", @"FilesystemType"]) };
    if (payload[@"battery"]) for (NSString *path in @[batteryPath, legacyBatteryPath])
        conditions[path] = @{ @"exists": present[path], @"values": PXRuntimeIdentifierDependencies(basis[path], @[@"LowPowerMode"]) };
    __block PXCommittedRuntimeGeneration *committedGeneration = nil;
    BOOL committed = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        if (![lease validateForDirectory:PXProfilesPath() error:writeError]) return NO;
        if (![[lease directoryProofForProfileID:profileID error:writeError] isEqual:directoryProof]) {
            if (writeError) *writeError = [NSError errorWithDomain:@"com.hydra.tlinkios" code:6030 userInfo:@{NSLocalizedDescriptionKey: @"Runtime generation target directory changed during preparation"}]; return NO;
        }
        BOOL deletionPending = NO;
        if (![tx dictionaryAtPath:PXProfileDeletionJournalPath() exists:&deletionPending error:writeError]) return NO;
        if (deletionPending) {
            if (writeError) *writeError = [NSError errorWithDomain:@"WeaponXProfileError" code:27 userInfo:@{NSLocalizedDescriptionKey: @"Deletion recovery started during runtime generation"}]; return NO;
        }
        if (!PXStageRuntimeGeneration(tx, identityDir, payload, conditions, writeError)) return NO;
        NSDictionary *proof = PXReadRuntimeGenerationProof(tx, identityDir, payload, writeError);
        if (!proof) return NO;
        // Receipt detachment must succeed before physical commit, so an error
        // cannot masquerade as an uncommitted generation after files changed.
        committedGeneration = [[PXCommittedRuntimeGeneration alloc] initWithIdentityDirectory:identityDir payload:payload proof:proof model:model error:writeError];
        return committedGeneration != nil;
    }, &failure);
    self.error = committed ? nil : failure;
    if (!committed) { if (error) *error = failure; return NO; }
    if (receipt) *receipt = committedGeneration;
    return YES;
}

- (void)publishRuntimeGeneration:(NSDictionary *)payload identityDirectory:(NSString *)identityDir model:(PXPreparedDeviceProfileGroup *)model {
    NSString *profileID = identityDir.stringByDeletingLastPathComponent.lastPathComponent;
    [self.spoofCache removeAllObjects];
    [_appEnabledCache removeAllObjects];
    @try {
        // Owned batches release lifecycle ownership before compatibility callbacks.
        // Avoid knowingly installing A's values if selection has since moved to B.
        if ([PXActiveProfileID() isEqualToString:profileID]) {
            if (model) [self publishPreparedDeviceProfileGroup:model];
            for (NSString *type in payload[@"scalars"]) {
                if (![PXActiveProfileID() isEqualToString:profileID]) break;
                [self publishPreparedIdentifier:payload[@"scalars"][type] type:type includeNameAndSerial:YES];
            }
            WiFiManager *wifi = [WiFiManager sharedManager];
            if ([PXActiveProfileID() isEqualToString:profileID]) [wifi adoptCommittedWiFiInfo:payload[@"wifi"] profileID:profileID];
            if (payload[@"storage"]) {
                StorageManager *storage = [StorageManager sharedManager];
                if ([PXActiveProfileID() isEqualToString:profileID]) [storage adoptCommittedStorageInfo:payload[@"storage"]];
            }
            if (payload[@"uptime"]) {
                UptimeManager *uptime = [UptimeManager sharedManager];
                if ([PXActiveProfileID() isEqualToString:profileID]) [uptime adoptCommittedUptimeInfo:payload[@"uptime"] timestamp:payload[@"timestamp"]];
            }
            if (payload[@"battery"]) {
                BatteryManager *battery = [BatteryManager sharedManager];
                if ([PXActiveProfileID() isEqualToString:profileID]) {
                    [battery adoptCommittedBatteryInfo:payload[@"batteryUI"]];
                    [battery publishCommittedBatteryInfo:payload[@"batteryUI"] timestamp:payload[@"timestamp"]];
                }
            }
        }
    } @catch (NSException *exception) {
        // A post-commit callback cannot roll back already committed sources.
        PXLog(@"[IdentifierManager] Sources committed; compatibility publication failed: %@", exception);
    }
    PXPostSettingsChangedNotification();
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
    PX_IDENTIFIER_RUNTIME_READ_OPERATION;
    if (![type isKindOfClass:NSString.class] || !type.length) return NO;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    if (!PXIdentifierManagerIsManagerProcess()) {
        // Injected host processes consume the daemon-published toggle map. A
        // persisted false remains authoritative. Only a genuinely missing key
        // may fall back to secondary flags/profile evidence to repair older
        // sparse/corrupted RootHide settings files.
        PXRuntimeReadSnapshot *runtimeView = PXCaptureRuntimeSnapshot();
        NSDictionary *runtimeSettings = runtimeView.tlinkSettings;
        NSDictionary *runtimeEnabled = [runtimeSettings[@"EnabledIdentifiers"] isKindOfClass:NSDictionary.class]
            ? runtimeSettings[@"EnabledIdentifiers"] : nil;
        NSString *lookupType = [type isEqualToString:@"WiFiAddress"] ? @"WiFi" : type;
        id runtimeValue = runtimeEnabled[lookupType];
        if (runtimeValue != nil) return PXRuntimeReadBool(runtimeValue);
        return PXRuntimeSnapshotImpliesIdentifierEnabled(type, runtimeView);
    }
#endif
    // The TLinkIOS manager/UI process must use its live in-memory settings so a
    // just-toggled value cannot be masked by a not-yet-republished snapshot.
    NSString *lookupType = [type isEqualToString:@"WiFiAddress"] ? @"WiFi" : type;
    return [self.settings[lookupType] boolValue];
}

#pragma mark - Current Values

- (NSString *)currentValueForIdentifier:(NSString *)type {
    PX_IDENTIFIER_RUNTIME_READ_OPERATION;
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
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    if (!PXIdentifierManagerIsManagerProcess()) return nil;
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
    PX_IDENTIFIER_RUNTIME_READ_OPERATION;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    if (!PXIdentifierManagerIsManagerProcess()) {
        if (!bundleID.length || [bundleID isEqualToString:@"com.hydra.tlinkios"]) return NO;
        id scoped = PXCaptureRuntimeSnapshot().globalScope[@"ScopedApps"];
        if (![scoped isKindOfClass:NSDictionary.class]) return NO;
        id entry = scoped[bundleID];
        if (entry != nil) return [entry isKindOfClass:NSDictionary.class] && PXRuntimeReadBool(entry[@"enabled"]);
        for (NSString *key in scoped) {
            if ([key isKindOfClass:NSString.class] && [key caseInsensitiveCompare:bundleID] == NSOrderedSame) {
                id candidate = scoped[key];
                return [candidate isKindOfClass:NSDictionary.class] && PXRuntimeReadBool(candidate[@"enabled"]);
            }
        }
        return NO;
    }
#endif
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
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    if (!PXIdentifierManagerIsManagerProcess()) return;
#endif
    NSError *sourceError = nil;
    if (PXIdentifierManagerIsManagerProcess() && !PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        (void)tx; (void)error; return YES;
    }, &sourceError)) { self.error = sourceError; return; }
    NSString *scopedAppsFile = PXGlobalScopePath();
    PXLog(@"[WeaponX] IdentifierManager DEBUG: Trying to load scoped apps from: %@", scopedAppsFile);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    PXLog(@"[WeaponX] IdentifierManager DEBUG: Loading scoped apps from: %@", scopedAppsFile);
    PXLog(@"[WeaponX] IdentifierManager DEBUG: File exists: %@", [fileManager fileExistsAtPath:scopedAppsFile] ? @"YES" : @"NO");
    
    // Load scoped apps from the global scope file
    NSDictionary *scopedAppsDict;
    if (PXIdentifierManagerIsManagerProcess()) {
        NSDictionary *captured = PXCaptureRuntimeSources(^NSDictionary *(NSError **error) {
            (void)error; return @{ @"scope": [NSDictionary dictionaryWithContentsOfFile:scopedAppsFile] ?: @{} };
        }, &sourceError);
        if (!captured) { self.error = sourceError; return; }
        scopedAppsDict = captured[@"scope"];
    } else {
        scopedAppsDict = [NSDictionary dictionaryWithContentsOfFile:scopedAppsFile];
    }
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
    NSError *sourceError = nil;
    BOOL success = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *transaction, NSError **writeError) {
        NSDictionary *existing = [transaction dictionaryAtPath:prefsFile error:writeError];
        if (!existing) return NO;
        NSMutableDictionary *saveDict = [existing mutableCopy];
        saveDict[@"EnabledIdentifiers"] = PXSanitizedIdentifierSettings(self.settings);
        // Keep the legacy top-level storage flag synchronized in the same
        // transaction. Rootful StorageManager still consults this key.
        if (self.settings[@"StorageSystem"] != nil) {
            saveDict[@"StorageSystemEnabled"] = @([self.settings[@"StorageSystem"] boolValue]);
        }
        saveDict[@"SettingsInitialized"] = @YES;
        if (![transaction setDictionary:saveDict atPath:prefsFile error:writeError]) return NO;
        NSDictionary *scopedAppsDict = @{@"ScopedApps": [self.scopedApps copy]};
        return [transaction setDictionary:scopedAppsDict atPath:scopedAppsFile error:writeError];
    }, &sourceError);
    if (!success) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                      code:4006
                                  userInfo:@{NSLocalizedDescriptionKey: sourceError.localizedDescription ?: @"Failed to save settings and scope transaction"}];
        PXLog(@"[WeaponX] ❌ Failed to commit settings/scope: %@", sourceError);
        return;
    } else {
        PXLog(@"[WeaponX] ✅ Saved scoped apps to: %@", scopedAppsFile);
    }

    [self.spoofCache removeAllObjects];
    [_appEnabledCache removeAllObjects];
    PXPostSettingsChangedNotification();
}
    


- (void)loadSettings {
    PX_IDENTIFIER_RUNTIME_READ_OPERATION;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    if (!PXIdentifierManagerIsManagerProcess()) return;
#endif
    NSError *sourceError = nil;
    // Recovery precedes reading either source or choosing a legacy fallback.
    // Do not load a crashed transaction into mutable manager state, then save it.
    if (PXIdentifierManagerIsManagerProcess() && !PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        (void)tx; (void)error; return YES;
    }, &sourceError)) { self.error = sourceError; return; }
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

    NSDictionary *managerSources = nil;
    if (PXIdentifierManagerIsManagerProcess()) {
        managerSources = PXCaptureRuntimeSources(^NSDictionary *(NSError **error) {
            (void)error;
            return @{ @"settings": [NSDictionary dictionaryWithContentsOfFile:prefsFile] ?: @{},
                      @"scope": [NSDictionary dictionaryWithContentsOfFile:scopedAppsFile] ?: @{} };
        }, &sourceError);
        if (!managerSources) { self.error = sourceError; return; }
    }

    // Sandboxed injected apps consume the RootHide runtime mirror. The manager
    // app itself must read the live settings file so a freshly toggled value is
    // never masked by a not-yet-republished snapshot.
    NSDictionary *loadedDict = managerSources[@"settings"];
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    if (!PXIdentifierManagerIsManagerProcess()) {
        NSDictionary *runtimeTLinkSettings = PXCaptureRuntimeSnapshot().tlinkSettings;
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
    NSDictionary *scopedAppsDict = managerSources[@"scope"];
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    if (!PXIdentifierManagerIsManagerProcess()) {
        NSDictionary *runtimeScope = PXCaptureRuntimeSnapshot().globalScope;
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
    PX_IDENTIFIER_RUNTIME_READ_OPERATION;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    if (!PXIdentifierManagerIsManagerProcess()) {
        id scoped = PXCaptureRuntimeSnapshot().globalScope[@"ScopedApps"];
        id entry = [scoped isKindOfClass:NSDictionary.class] ? scoped[bundleID ?: @""] : nil;
        return entry != nil ? ([entry isKindOfClass:NSDictionary.class] && PXRuntimeReadBool(entry[@"enabled"]))
                            : [self isExtensionEnabled:bundleID];
    }
#endif
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
    NSError *sourceError = nil;
    BOOL success = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *transaction, NSError **writeError) {
        return [transaction setDictionary:scopedAppsDict atPath:scopedAppsFile error:writeError];
    }, &sourceError);
    if (!success) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                      code:4006 
                                  userInfo:@{NSLocalizedDescriptionKey: sourceError.localizedDescription ?: @"Failed to save global scoped apps"}];
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
    PX_IDENTIFIER_RUNTIME_READ_OPERATION;
    if (!bundleID) return NO;
    
    // Never consider the WeaponX app itself or system apps
    if ([bundleID isEqualToString:@"com.hydra.tlinkios"] || [bundleID hasPrefix:@"com.apple."]) {
        return NO;
    }
    
    // Check each scoped app's extension pattern
    NSDictionary *scopedApps = self.scopedApps;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    if (!PXIdentifierManagerIsManagerProcess()) {
        id scoped = PXCaptureRuntimeSnapshot().globalScope[@"ScopedApps"];
        scopedApps = [scoped isKindOfClass:NSDictionary.class] ? scoped : @{};
    }
#endif
    for (NSString *scopedBundleID in scopedApps) {
        NSDictionary *appInfo = scopedApps[scopedBundleID];
        if (![appInfo isKindOfClass:NSDictionary.class]) continue;
        NSString *extensionPattern = appInfo[@"extensionPattern"];
        
        if ([extensionPattern isKindOfClass:NSString.class] && [self isBundleIDMatch:bundleID withPattern:extensionPattern]) {
            PXLog(@"[WeaponX] Bundle ID %@ matches extension pattern %@ from app %@", bundleID, extensionPattern, scopedBundleID);
            return PXRuntimeReadBool(appInfo[@"enabled"]);
        }
    }
    
    return NO;
}

#pragma mark - Custom Values

- (void)publishPreparedIdentifier:(NSString *)value type:(NSString *)type includeNameAndSerial:(BOOL)includeNameAndSerial {
    if (includeNameAndSerial && [type isEqualToString:@"DeviceName"]) { [[DeviceNameManager sharedManager] setCurrentDeviceName:value]; return; }
    if (includeNameAndSerial && [type isEqualToString:@"SerialNumber"]) { [[SerialNumberManager sharedManager] setCurrentSerialNumber:value]; return; }
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

- (BOOL)saveCustomValue:(NSString *)value forType:(NSString *)type {
    value = [value copy]; type = [type copy];
    PXProfileArtifactMutation *mutation = [self currentIdentifierMutation];
    if (!mutation) return NO;
    BOOL success = NO;
    @try {
        if (!PXRuntimeIdentifierSidecar(type)) return NO;
        success = [self persistPreparedIdentifier:value type:type mutation:mutation incrementGeneration:YES];
    } @finally { [mutation invalidate]; }
    if (success) {
        PXLog(@"[WeaponX] Custom %@ committed for %@", type, mutation.identityDirectory);
        [self publishPreparedIdentifier:value type:type includeNameAndSerial:NO];
    }
    return success;
}

- (BOOL)setCustomIDFA:(NSString *)value {
    // Validate UUID format
    if (![self validateUUID:value]) return NO;
    return [self saveCustomValue:value forType:@"IDFA"];
}

#pragma mark - IMEI/MEID Spoofing (kept strictly separate)

- (NSString *)prepareAndPersistTelephonyValue:(NSString *)value type:(NSString *)type generate:(BOOL)generate {
    self.error = nil;
    type = [type copy];
    BOOL isIMEI = [type isEqualToString:@"IMEI"];
    if (!isIMEI && ![type isEqualToString:@"MEID"]) return nil;

    // Freeze manual input before validation/DB callbacks. Preserve its original
    // spelling (including accepted lowercase MEID), not a normalized replacement.
    NSString *prepared = [value isKindOfClass:NSString.class] ? [value copy] : nil;
    if (!generate && !(isIMEI ? [self isValidIMEI:prepared] : [self isValidMEID:prepared])) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios.telephony" code:1
            userInfo:@{NSLocalizedDescriptionKey: @"Invalid telephony identifier format"}];
        return nil;
    }
    PXProfileArtifactMutation *mutation = [self currentIdentifierMutation];
    if (!mutation) return nil;
    @try {
        NSString *identityDir = mutation.identityDirectory;
        NSDictionary *deviceIds = [self captureDeviceIDsAtIdentityDirectory:identityDir];
        if (!deviceIds) return nil;
        NSString *productType = PXProfileString(deviceIds[@"DeviceModel"]);
        NSString *regulatoryModelNumber = PXProfileString(deviceIds[@"RegulatoryModelNumber"]);

        // Generation always requires a canonical regional slot. Manual values keep
        // the existing non-iPhone compatibility policy; iPhone writes use the DB.
        if (generate || [productType hasPrefix:@"iPhone"]) {
            if (!productType.length || !regulatoryModelNumber.length) {
                self.error = [NSError errorWithDomain:@"com.hydra.tlinkios.telephony" code:2
                    userInfo:@{NSLocalizedDescriptionKey: @"Canonical model and regulatory slot are required"}];
                return nil;
            }
            NSDictionary *spec = [[IPhoneModelDB sharedManager] cellularSpecForProductType:productType
                                                                     regulatoryModelNumber:regulatoryModelNumber];
            BOOL known = [spec[@"known"] isKindOfClass:NSNumber.class] && [spec[@"known"] boolValue];
            BOOL enabled = known && [spec[@"enabled"] isKindOfClass:NSNumber.class] && [spec[@"enabled"] boolValue];
            BOOL cdma = enabled && [spec[@"cdma"] isKindOfClass:NSNumber.class] && [spec[@"cdma"] boolValue];
            NSArray *tacs = [spec[@"imeiTACs"] isKindOfClass:NSArray.class] ? spec[@"imeiTACs"] : nil;
            NSArray *prefixes = [spec[@"meidPrefixes"] isKindOfClass:NSArray.class] ? spec[@"meidPrefixes"] : nil;
            if (!enabled || (!isIMEI && !cdma)) {
                self.error = [NSError errorWithDomain:@"com.hydra.tlinkios.telephony" code:3
                    userInfo:@{NSLocalizedDescriptionKey: @"Regional cellular capability does not permit this identifier"}];
                return nil;
            }
            if (generate) prepared = isIMEI ? PXGenerateIMEIFromAuthoritativeTACs(tacs) : PXGenerateMEIDFromAuthoritativePrefixes(prefixes);
            if (!prepared.length || (generate && !(isIMEI ? [self isValidIMEI:prepared] : [self isValidMEID:prepared])) ||
                !(isIMEI ? PXIdentityHasAllowedPrefix(prepared, tacs) : PXIdentityHasAllowedPrefix(prepared, prefixes))) {
                self.error = [NSError errorWithDomain:@"com.hydra.tlinkios.telephony" code:4
                    userInfo:@{NSLocalizedDescriptionKey: @"Identifier does not match authoritative regional prefixes"}];
                return nil;
            }
        }
        NSDictionary *expected = PXCellularPreparationDependencies(deviceIds);
        NSDate *timestamp = [NSDate date];
        NSError *sourceError = nil;
        BOOL success = [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
            return PXStageRuntimeIdentifierValueWithDependencies(tx, identityDir, type, prepared, timestamp, expected, error);
        } error:&sourceError];
        self.error = success ? nil : sourceError;
        return success ? prepared : nil;
    } @finally { [mutation invalidate]; }
}

- (BOOL)setCustomIMEI:(NSString *)value {
    return [self prepareAndPersistTelephonyValue:value type:@"IMEI" generate:NO] != nil;
}

- (BOOL)setCustomMEID:(NSString *)value {
    return [self prepareAndPersistTelephonyValue:value type:@"MEID" generate:NO] != nil;
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
    return [self generatePreparedIdentifierForType:@"UDID"];
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
    if (status < 0) status = 0;
    if (status > 3) status = 3;
    PXProfileArtifactMutation *mutation = [self currentIdentifierMutation];
    if (!mutation) return;
    BOOL success = NO;
    @try {
        NSDictionary *tracking = @{ @"ATTAuthorizationStatus": @(status), @"lastUpdated": [NSDate date] };
        NSDictionary *updates = @{ @"ATTAuthorizationStatus": @(status) };
        NSError *writeError = nil;
        success = [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
            return PXStageRuntimeIdentifierState(tx, mutation.identityDirectory, updates, @{ @"tracking_info.plist": tracking }, NO, error);
        } error:&writeError];
        self.error = success ? nil : writeError;
    } @finally { [mutation invalidate]; }
    if (success) PXLog(@"[WeaponX] ATTAuthorizationStatus committed: %ld", (long)status);
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
    self.error = nil;
    NSError *error = nil;
    PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:PXProfilesPath() error:&error];
    @try {
        if (!lease || ![lease validateForDirectory:PXProfilesPath() error:&error] || !PXRequireNoPendingProfileDeletion(&error)) { self.error = error; return; }
        NSString *identityDir = PXProfileIdentityPath([[self getActiveProfileId] copy]);
        if (!identityDir.length || ![NSFileManager.defaultManager fileExistsAtPath:identityDir]) return;
        (void)[self migrateProfileSchemaAtIdentityDirectory:identityDir lifecycleLease:lease];
    } @finally { [lease invalidate]; }
}

- (BOOL)migrateProfileSchemaAtIdentityDirectory:(NSString *)identityDir {
    self.error = nil;
    identityDir = [identityDir copy];
    NSError *error = nil;
    PXProfileArtifactMutation *mutation = [PXProfileArtifactMutation acquireWithIdentityResolver:^NSString *{ return identityDir; } error:&error];
    if (!mutation) { self.error = error; return NO; }
    @try { return [self commitProfileSchemaWithMutation:mutation]; }
    @finally { [mutation invalidate]; }
}

- (BOOL)migrateProfileSchemaAtIdentityDirectory:(NSString *)identityDir lifecycleLease:(PXProfileLifecycleLease *)lease {
    NSError *error = nil;
    identityDir = [identityDir copy];
    PXProfileArtifactMutation *mutation = [PXProfileArtifactMutation borrowWithLifecycleLease:lease identityResolver:^NSString *{ return identityDir; } error:&error];
    if (!mutation) { self.error = error; return NO; }
    @try { return [self commitProfileSchemaWithMutation:mutation]; }
    @finally { [mutation invalidate]; }
}

- (BOOL)commitProfileSchemaWithMutation:(PXProfileArtifactMutation *)mutation {
    NSString *identityDir = mutation.identityDirectory;
    NSString *profileDir = identityDir.stringByDeletingLastPathComponent;
    NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
    BOOL udidEnabled = [self.settings[@"UDID"] boolValue];
    BOOL idfaEnabled = [self.settings[@"IDFA"] boolValue];
    NSDate *now = [NSDate date];
    __block BOOL migrated = NO;
    __block NSInteger previousSchema = 0;
    NSError *writeError = nil;
    BOOL success = [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        NSMutableDictionary *deviceIds = [[tx dictionaryAtPath:deviceIdsPath error:error] mutableCopy];
        if (!deviceIds) return NO;
        NSInteger schemaVersion = [deviceIds[@"ProfileSchemaVersion"] respondsToSelector:@selector(integerValue)]
            ? [deviceIds[@"ProfileSchemaVersion"] integerValue]
            : 0;

        previousSchema = schemaVersion;
        if (schemaVersion >= 2) {
            return YES; // Already migrated
        }

        // 1) HardwareUUID → SystemBootUUID if canonical missing (one-way; do not write HardwareUUID)
        NSString *systemBoot = nil;
        id existingBoot = deviceIds[@"SystemBootUUID"];
        if ([existingBoot isKindOfClass:[NSString class]] && [(NSString *)existingBoot length] > 0) {
            systemBoot = (NSString *)existingBoot;
        }
        if (!systemBoot.length) {
            NSString *bootPlistPath = [identityDir stringByAppendingPathComponent:@"system_boot_uuid.plist"];
            NSDictionary *bootPlist = [tx dictionaryAtPath:bootPlistPath error:error];
            if (!bootPlist) return NO;
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
                NSDictionary *bootDict = @{@"value": systemBoot, @"lastUpdated": now};
                if (![tx setDictionary:bootDict atPath:[identityDir stringByAppendingPathComponent:@"system_boot_uuid.plist"] error:error]) return NO;
            }
        }

        // 2) Generate UDID if toggle enabled and value missing
        NSString *existingUDID = nil;
        id udidRaw = deviceIds[@"UDID"];
        if ([udidRaw isKindOfClass:[NSString class]] && [(NSString *)udidRaw length] > 0) {
            existingUDID = (NSString *)udidRaw;
        }
        if (!existingUDID.length) {
            NSDictionary *udidPlist = [tx dictionaryAtPath:[identityDir stringByAppendingPathComponent:@"udid.plist"] error:error];
            if (!udidPlist) return NO;
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
            NSDictionary *udidDict = @{@"value": udid, @"lastUpdated": now};
            if (![tx setDictionary:udidDict atPath:[identityDir stringByAppendingPathComponent:@"udid.plist"] error:error]) return NO;
            deviceIds[@"UDID"] = [udid copy];
        }

        // 3) Init ATTAuthorizationStatus default
        if (deviceIds[@"ATTAuthorizationStatus"] == nil) {
            NSString *idfa = nil;
            id idfaRaw = deviceIds[@"IDFA"];
            if ([idfaRaw isKindOfClass:[NSString class]]) {
                idfa = (NSString *)idfaRaw;
            }
            if (!idfa.length) {
                NSDictionary *idfaPlist = [tx dictionaryAtPath:[identityDir stringByAppendingPathComponent:@"advertising_id.plist"] error:error];
                if (!idfaPlist) return NO;
                if ([idfaPlist[@"value"] isKindOfClass:[NSString class]]) {
                    idfa = idfaPlist[@"value"];
                }
            }

            // IDFA enabled + non-zero UUID → authorized (3); else notDetermined (0)
            NSInteger attStatus = (idfaEnabled && PXIsNonZeroUUIDString(idfa)) ? 3 : 0;
            deviceIds[@"ATTAuthorizationStatus"] = @(attStatus);

            NSDictionary *trackingDict = @{
                @"ATTAuthorizationStatus": @(attStatus),
                @"lastUpdated": now
            };
            if (![tx setDictionary:trackingDict atPath:[identityDir stringByAppendingPathComponent:@"tracking_info.plist"] error:error]) return NO;
        }

        // 4) Init LowPowerMode default = NO
        if (deviceIds[@"LowPowerMode"] == nil) {
            deviceIds[@"LowPowerMode"] = @NO;

            // Prefer identity battery_info.plist; also update profile-root path used by BatteryManager
            NSString *batteryPath = [identityDir stringByAppendingPathComponent:@"battery_info.plist"];
            NSMutableDictionary *batteryInfo = [[tx dictionaryAtPath:batteryPath error:error] mutableCopy];
            if (!batteryInfo) return NO;

            if (batteryInfo[@"LowPowerMode"] == nil) {
                batteryInfo[@"LowPowerMode"] = @NO;
                if (![tx setDictionary:batteryInfo atPath:batteryPath error:error]) return NO;
            }

            NSString *profileBatteryPath = [profileDir stringByAppendingPathComponent:@"battery_info.plist"];
            NSMutableDictionary *profileBattery = [[tx dictionaryAtPath:profileBatteryPath error:error] mutableCopy];
            if (!profileBattery) return NO;

            if (profileBattery[@"LowPowerMode"] == nil) {
                profileBattery[@"LowPowerMode"] = @NO;
                if (profileBattery[@"BatteryLevel"] == nil && batteryInfo[@"BatteryLevel"] != nil) {
                    profileBattery[@"BatteryLevel"] = batteryInfo[@"BatteryLevel"];
                }
                if (![tx setDictionary:profileBattery atPath:profileBatteryPath error:error]) return NO;
            }
        }

        // Mark schema v2 and bump GenerationCounter once for the whole migration
        deviceIds[@"ProfileSchemaVersion"] = @2;
        if (!PXAdvanceRuntimeIdentifierGeneration(deviceIds, error)) return NO;
        if (![tx setDictionary:deviceIds atPath:deviceIdsPath error:error]) return NO;
        migrated = YES;
        return YES;
    } error:&writeError];
    self.error = success ? nil : writeError;
    if (success && migrated) PXLog(@"[IdentifierManager] Schema v%ld -> v2 committed at %@", (long)previousSchema, identityDir);
    return success;
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
    return [self prepareAndPersistTelephonyValue:nil type:@"IMEI" generate:YES];
}

- (NSString *)generateMEID {
    return [self prepareAndPersistTelephonyValue:nil type:@"MEID" generate:YES];
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
    value = [value copy];
    if (![value isEqualToString:@"Light"] && ![value isEqualToString:@"Dark"]) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:2004 userInfo:@{NSLocalizedDescriptionKey: @"Invalid Device Theme (must be 'Light' or 'Dark')"}];
        return NO;
    }
    PXProfileArtifactMutation *mutation = [self currentIdentifierMutation];
    if (!mutation) return NO;
    BOOL success = NO;
    @try {
        NSDictionary *theme = @{ @"value": value, @"lastUpdated": [NSDate date] };
        NSError *writeError = nil;
        success = [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
            return PXStageRuntimeIdentifierState(tx, mutation.identityDirectory, @{ @"DeviceTheme": value }, @{ @"device_theme.plist": theme }, NO, error);
        } error:&writeError];
        self.error = success ? nil : writeError;
    } @finally { [mutation invalidate]; }
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
    NSError *error = nil;
    if (!PXWriteSecuritySettings(@{ @"canvasFingerprintingEnabled": @(enabled), @"CanvasFingerprint": @(enabled) }, &error)) {
        PXLog(@"[WeaponX] Failed to persist Canvas protection: %@", error);
        return NO;
    }
    PXPostSettingsChangedNotification();
    return YES;
}

- (BOOL)resetCanvasNoiseAndPersist {
    uint32_t nonce = 0;
    NSError *error = nil;
    if (!PXAdvanceSecurityNonce(@"canvasNoiseSeedNonce", &nonce, &error)) {
        PXLog(@"[WeaponX] Failed to persist Canvas noise reset: %@", error);
        return NO;
    }
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterPostNotification(center, CFSTR("com.hydra.tlinkios.settings.changed"), NULL, NULL, TRUE);
    CFNotificationCenterPostNotification(center, CFSTR("com.hydra.tlinkios.resetCanvasNoise"), NULL, NULL, TRUE);
    PXLog(@"[WeaponX] Canvas noise reset committed (nonce=%u)", nonce);
    return YES;
}

- (void)resetCanvasNoise {
    [self resetCanvasNoiseAndPersist];
}

@end
