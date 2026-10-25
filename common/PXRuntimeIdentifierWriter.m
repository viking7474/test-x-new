#import "PXRuntimeIdentifierWriter.h"
#import <dispatch/dispatch.h>

static NSDictionary<NSString *, NSString *> *PXIdentifierSidecarMap(void) {
    static NSDictionary *map;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        map = @{ @"IDFA": @"advertising_id.plist", @"IDFV": @"vendor_id.plist",
            @"DeviceName": @"device_name.plist", @"SerialNumber": @"serial_number.plist",
            @"IMEI": @"imei.plist", @"MEID": @"meid.plist", @"UDID": @"udid.plist",
            @"SystemBootUUID": @"system_boot_uuid.plist", @"DyldCacheUUID": @"dyld_cache_uuid.plist",
            @"PasteboardUUID": @"pasteboard_uuid.plist", @"KeychainUUID": @"keychain_uuid.plist",
            @"UserDefaultsUUID": @"userdefaults_uuid.plist", @"AppGroupUUID": @"appgroup_uuid.plist",
            @"CoreDataUUID": @"coredata_uuid.plist", @"AppInstallUUID": @"appinstall_uuid.plist",
            @"AppContainerUUID": @"appcontainer_uuid.plist" };
    });
    return map;
}
NSString *PXRuntimeIdentifierSidecar(NSString *type) {
    return [type isKindOfClass:NSString.class] ? PXIdentifierSidecarMap()[type] : nil;
}
NSSet<NSString *> *PXRuntimeIdentifierSidecars(void) {
    static NSSet *names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ names = [NSSet setWithArray:PXIdentifierSidecarMap().allValues]; });
    return names;
}
static BOOL PXIdentifierWriteFailure(NSString *message, NSError **error) {
    if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios.identifier-write" code:1
        userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}
BOOL PXAdvanceRuntimeIdentifierGeneration(NSMutableDictionary *ids, NSError **error) {
    id value = ids[@"GenerationCounter"];
    NSInteger generation = [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : 0;
    if (generation == NSIntegerMax) return PXIdentifierWriteFailure(@"Identifier generation exhausted", error);
    ids[@"GenerationCounter"] = @(generation + 1);
    return YES;
}
BOOL PXStageRuntimeIdentifierState(PXRuntimeSourceTransaction *tx, NSString *identity,
    NSDictionary *updates, NSDictionary<NSString *, NSDictionary *> *sidecars, BOOL increment, NSError **error) {
    NSString *idsPath = [identity stringByAppendingPathComponent:@"device_ids.plist"];
    NSMutableDictionary *ids = [[tx dictionaryAtPath:idsPath error:error] mutableCopy];
    if (!ids) return NO;
    [ids addEntriesFromDictionary:updates];
    if (increment && !PXAdvanceRuntimeIdentifierGeneration(ids, error)) return NO;
    for (NSString *file in sidecars) {
        if (![tx setDictionary:sidecars[file] atPath:[identity stringByAppendingPathComponent:file] error:error]) return NO;
    }
    return [tx setDictionary:ids atPath:idsPath error:error];
}
BOOL PXStageRuntimeIdentifierValue(PXRuntimeSourceTransaction *tx, NSString *identity,
    NSString *type, NSString *value, NSDate *timestamp, BOOL increment, NSError **error) {
    NSString *file = PXRuntimeIdentifierSidecar(type);
    if (!file || ![value isKindOfClass:NSString.class]) return PXIdentifierWriteFailure(@"Unsupported identifier value/type", error);
    return PXStageRuntimeIdentifierState(tx, identity, @{type: value},
        @{file: @{ @"value": value, @"lastUpdated": timestamp }}, increment, error);
}
