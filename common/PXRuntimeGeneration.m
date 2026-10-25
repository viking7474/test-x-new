#import "PXRuntimeGeneration.h"
#import "PXRuntimeArtifactWriter.h"
#import <dispatch/dispatch.h>

NSArray<NSString *> *PXRuntimeGenerationScalarTypes(void) {
    static NSArray *types;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ types = @[@"IDFA", @"IDFV", @"DeviceName", @"SerialNumber", @"UDID",
        @"SystemBootUUID", @"DyldCacheUUID", @"PasteboardUUID", @"KeychainUUID", @"UserDefaultsUUID",
        @"AppGroupUUID", @"CoreDataUUID", @"AppInstallUUID", @"AppContainerUUID"]; });
    return types;
}
static BOOL PXGenerationFailure(NSString *message, NSError **error) {
    if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios.generation" code:1
        userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}
NSDictionary *PXDetachRuntimeGeneration(NSDictionary *payload, NSError **error) {
    if (![payload isKindOfClass:NSDictionary.class] || ![NSPropertyListSerialization propertyList:payload isValidForFormat:NSPropertyListBinaryFormat_v1_0]) {
        PXGenerationFailure(@"Invalid prepared generation", error); return nil;
    }
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:payload format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
    return data ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:error] : nil;
}
BOOL PXStageRuntimeGeneration(PXRuntimeSourceTransaction *tx, NSString *identity, NSDictionary *payload,
    NSDictionary<NSString *, NSDictionary *> *conditions, NSError **error) {
    // Validate every captured basis before staging anything. Field-level checks
    // preserve unrelated concurrent updates; absence participates in comparison.
    for (NSString *path in conditions) {
        BOOL exists = NO;
        NSDictionary *current = [tx dictionaryAtPath:path exists:&exists error:error];
        if (!current) return NO;
        NSDictionary *condition = conditions[path];
        if (condition[@"exists"] && exists != [condition[@"exists"] boolValue])
            return PXGenerationFailure(@"Generation source presence changed; retry operation", error);
        for (NSString *key in condition[@"values"])
            if (![(current[key] ?: NSNull.null) isEqual:condition[@"values"][key]])
                return PXGenerationFailure(@"Generation dependencies changed; retry operation", error);
    }
    NSDate *now = payload[@"timestamp"];
    NSDictionary *model = payload[@"model"];
    if (model && !PXStageRuntimeIdentifierReplacement(tx, identity, model[@"updates"], model[@"keys"], nil, YES, YES, error)) return NO;
    NSDictionary *cellular = payload[@"cellular"];
    if (cellular && !PXStageRuntimeIdentifierReplacement(tx, identity, cellular[@"updates"], cellular[@"keys"], nil, YES, YES, error)) return NO;
    NSDictionary *scalars = payload[@"scalars"];
    for (NSString *type in PXRuntimeGenerationScalarTypes())
        if (scalars[type] && !PXStageRuntimeIdentifierValue(tx, identity, type, scalars[type], now, NO, error)) return NO;
    NSString *theme = payload[@"theme"];
    if (theme && !PXStageRuntimeIdentifierState(tx, identity, @{ @"DeviceTheme": theme },
        @{ @"device_theme.plist": @{ @"value": theme, @"lastUpdated": now } }, NO, error)) return NO;
    if (!PXStageRuntimeWiFi(tx, identity, payload[@"wifi"], error)) return NO;
    NSDictionary *uptime = payload[@"uptime"];
    if (uptime && !PXStageRuntimeUptime(tx, identity, uptime[@"boot"], uptime[@"uptime"], now, error)) return NO;
    NSDictionary *battery = payload[@"battery"];
    if (battery && !PXStageRuntimeBattery(tx, identity, battery, error)) return NO;
    NSDictionary *network = payload[@"network"];
    if (network[@"carrier"] && !PXStageRuntimeCarrier(tx, identity, network[@"carrier"], now, error)) return NO;
    if (network[@"ipv4"] && !PXStageRuntimeAddresses(tx, identity, network[@"ipv4"], network[@"ipv6"], YES, now, error)) return NO;
    if (payload[@"storage"] && ![tx setDictionary:payload[@"storage"] atPath:[identity.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"storage.plist"] error:error]) return NO;
    return [payload[@"deferSettings"] boolValue] || PXStageRuntimeGenerationSettings(tx, payload, error);
}

BOOL PXStageRuntimeGenerationSettings(PXRuntimeSourceTransaction *tx, NSDictionary *payload, NSError **error) {
    NSString *settingsPath = payload[@"settingsPath"];
    NSMutableDictionary *settings = [[tx dictionaryAtPath:settingsPath error:error] mutableCopy];
    if (!settings) return NO;
    NSDictionary *flags = payload[@"flags"];
    settings[@"EnabledIdentifiers"] = flags;
    if (flags[@"StorageSystem"] != nil) settings[@"StorageSystemEnabled"] = flags[@"StorageSystem"];
    settings[@"SettingsInitialized"] = @YES;
    return [tx setDictionary:settings atPath:settingsPath error:error] &&
        [tx setDictionary:@{ @"ScopedApps": payload[@"scope"] } atPath:payload[@"scopePath"] error:error];
}

NSDictionary *PXReadRuntimeGenerationProof(PXRuntimeSourceTransaction *tx, NSString *identity, NSDictionary *payload, NSError **error) {
    NSMutableSet *paths = [NSMutableSet setWithArray:@[
        [identity stringByAppendingPathComponent:@"device_ids.plist"],
        [identity stringByAppendingPathComponent:@"wifi_info.plist"], payload[@"settingsPath"], payload[@"scopePath"] ]];
    for (NSString *type in payload[@"scalars"]) {
        NSString *file = PXRuntimeIdentifierSidecar(type);
        if (file) [paths addObject:[identity stringByAppendingPathComponent:file]];
    }
    if (payload[@"model"] || payload[@"cellular"]) for (NSString *file in @[@"imei.plist", @"meid.plist"])
        [paths addObject:[identity stringByAppendingPathComponent:file]];
    if (payload[@"theme"]) [paths addObject:[identity stringByAppendingPathComponent:@"device_theme.plist"]];
    if (payload[@"battery"]) [paths addObject:[identity stringByAppendingPathComponent:@"battery_info.plist"]];
    if (payload[@"uptime"]) for (NSString *file in @[@"boot_time.plist", @"system_uptime.plist"])
        [paths addObject:[identity stringByAppendingPathComponent:file]];
    if (payload[@"storage"]) [paths addObject:[identity.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"storage.plist"]];
    NSDictionary *network = payload[@"network"];
    if (network[@"carrier"]) [paths addObject:[identity stringByAppendingPathComponent:@"carrier_details.plist"]];
    if (network[@"carrier"] || network[@"ipv4"]) [paths addObject:[identity stringByAppendingPathComponent:@"network_settings.plist"]];
    NSMutableDictionary *proof = [NSMutableDictionary dictionary];
    for (NSString *path in paths) {
        BOOL exists = NO;
        NSDictionary *info = [tx dictionaryAtPath:path exists:&exists error:error];
        if (!info) return nil;
        proof[path] = @{ @"exists": @(exists), @"info": info };
    }
    return [proof copy];
}

BOOL PXRuntimeGenerationMatchesProof(PXRuntimeSourceTransaction *tx, NSDictionary *proof, NSError **error) {
    if (![proof isKindOfClass:NSDictionary.class] || !proof.count)
        return PXGenerationFailure(@"Missing generation proof", error);
    for (NSString *path in proof) {
        NSDictionary *record = proof[path]; BOOL exists = NO;
        if (![record isKindOfClass:NSDictionary.class] || ![record[@"exists"] isKindOfClass:NSNumber.class] ||
            ![record[@"info"] isKindOfClass:NSDictionary.class]) return PXGenerationFailure(@"Invalid generation proof", error);
        NSDictionary *current = [tx dictionaryAtPath:path exists:&exists error:error];
        if (!current) return NO;
        if (exists != [record[@"exists"] boolValue] || ![current isEqual:record[@"info"]])
            return PXGenerationFailure(@"Committed generation changed before activation; retry operation", error);
    }
    return YES;
}

@implementation PXCommittedRuntimeGeneration
- (instancetype)initWithIdentityDirectory:(NSString *)identity payload:(NSDictionary *)payload proof:(NSDictionary *)proof
    model:(PXPreparedDeviceProfileGroup *)model error:(NSError **)error {
    if (!(self = [super init])) return nil;
    if (![identity isKindOfClass:NSString.class] || !identity.isAbsolutePath ||
        ![payload isKindOfClass:NSDictionary.class] || ![proof isKindOfClass:NSDictionary.class] ||
        (model && ![model isKindOfClass:PXPreparedDeviceProfileGroup.class])) {
        PXGenerationFailure(@"Invalid committed generation receipt", error); return nil;
    }
    NSDictionary *detached = PXDetachRuntimeGeneration(@{ @"payload": payload, @"proof": proof }, error);
    if (!detached) return nil;
    _identityDirectory = [identity copy]; _payload = detached[@"payload"]; _proof = detached[@"proof"]; _model = model;
    return self;
}
@end
