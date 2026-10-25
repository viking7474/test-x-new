#import "PXRuntimeArtifactWriter.h"

static NSString *PXArtifactPath(NSString *identity, NSString *file) {
    return [identity stringByAppendingPathComponent:file];
}
static NSString *PXArtifactIPv6(NSDictionary *network, NSDictionary *ids) {
    id value = network[@"localIPv6Address"];
    if (![value isKindOfClass:NSString.class] || ![value length]) value = ids[@"LocalIPv6Address"];
    return [value isKindOfClass:NSString.class] && [value length] ? value : nil;
}
static BOOL PXStageAddressDictionaries(PXRuntimeSourceTransaction *tx, NSString *identity,
    NSMutableDictionary *network, NSMutableDictionary *ids, NSString *ipv4, NSString *ipv6, NSDate *timestamp, NSError **error) {
    if (ipv4 != nil) { network[@"localIPAddress"] = ipv4; ids[@"LocalIPAddress"] = ipv4; }
    if (ipv6 != nil) { network[@"localIPv6Address"] = ipv6; ids[@"LocalIPv6Address"] = ipv6; }
    network[@"lastUpdated"] = timestamp;
    return [tx setDictionary:network atPath:PXArtifactPath(identity, @"network_settings.plist") error:error] &&
        [tx setDictionary:ids atPath:PXArtifactPath(identity, @"device_ids.plist") error:error];
}
BOOL PXStageRuntimeIPv4WithExistingPair(PXRuntimeSourceTransaction *tx, NSString *identity,
    NSString *ipv4, NSDate *timestamp, BOOL *needsIPv6, NSError **error) {
    *needsIPv6 = YES;
    NSMutableDictionary *network = [[tx dictionaryAtPath:PXArtifactPath(identity, @"network_settings.plist") error:error] mutableCopy];
    NSMutableDictionary *ids = network ? [[tx dictionaryAtPath:PXArtifactPath(identity, @"device_ids.plist") error:error] mutableCopy] : nil;
    if (!ids) return NO;
    NSString *ipv6 = PXArtifactIPv6(network, ids);
    if (!ipv6.length) return YES;
    *needsIPv6 = NO;
    return PXStageAddressDictionaries(tx, identity, network, ids, ipv4, ipv6, timestamp, error);
}
BOOL PXStageRuntimeAddresses(PXRuntimeSourceTransaction *tx, NSString *identity,
                            NSString *ipv4, NSString *ipv6, BOOL preserveIPv6, NSDate *timestamp, NSError **error) {
    NSMutableDictionary *network = [[tx dictionaryAtPath:PXArtifactPath(identity, @"network_settings.plist") error:error] mutableCopy];
    NSMutableDictionary *ids = network ? [[tx dictionaryAtPath:PXArtifactPath(identity, @"device_ids.plist") error:error] mutableCopy] : nil;
    if (!ids) return NO;
    if (preserveIPv6) ipv6 = PXArtifactIPv6(network, ids) ?: ipv6;
    return PXStageAddressDictionaries(tx, identity, network, ids, ipv4, ipv6, timestamp, error);
}
BOOL PXStageRuntimeCarrier(PXRuntimeSourceTransaction *tx, NSString *identity,
                          NSDictionary *carrier, NSDate *timestamp, NSError **error) {
    NSString *networkPath = PXArtifactPath(identity, @"network_settings.plist");
    NSString *idsPath = PXArtifactPath(identity, @"device_ids.plist");
    NSMutableDictionary *network = [[tx dictionaryAtPath:networkPath error:error] mutableCopy];
    NSMutableDictionary *ids = network ? [[tx dictionaryAtPath:idsPath error:error] mutableCopy] : nil;
    if (!ids) return NO;
    network[@"carrierName"] = carrier[@"carrierName"]; network[@"mcc"] = carrier[@"mcc"]; network[@"mnc"] = carrier[@"mnc"];
    network[@"lastUpdated"] = timestamp;
    ids[@"CarrierName"] = carrier[@"carrierName"]; ids[@"CarrierMCC"] = carrier[@"mcc"]; ids[@"CarrierMNC"] = carrier[@"mnc"];
    return [tx setDictionary:carrier atPath:PXArtifactPath(identity, @"carrier_details.plist") error:error] &&
        [tx setDictionary:network atPath:networkPath error:error] && [tx setDictionary:ids atPath:idsPath error:error];
}
BOOL PXStageRuntimeWiFi(PXRuntimeSourceTransaction *tx, NSString *identity, NSDictionary *wifi, NSError **error) {
    NSString *idsPath = PXArtifactPath(identity, @"device_ids.plist");
    NSMutableDictionary *ids = [[tx dictionaryAtPath:idsPath error:error] mutableCopy];
    if (!ids) return NO;
    // Preserve the old nil-removes-key semantics when a legacy payload lacks a field.
    ids[@"SSID"] = wifi[@"ssid"]; ids[@"BSSID"] = wifi[@"bssid"];
    return [tx setDictionary:wifi atPath:PXArtifactPath(identity, @"wifi_info.plist") error:error] &&
        [tx setDictionary:ids atPath:idsPath error:error];
}
BOOL PXStageRuntimeBattery(PXRuntimeSourceTransaction *tx, NSString *identity, NSDictionary *battery, NSError **error) {
    NSString *idsPath = PXArtifactPath(identity, @"device_ids.plist");
    BOOL exists = NO;
    NSMutableDictionary *ids = [[tx dictionaryAtPath:idsPath exists:&exists error:error] mutableCopy];
    if (!ids) return NO;
    if (![tx setDictionary:battery atPath:PXArtifactPath(identity, @"battery_info.plist") error:error]) return NO;
    // The original battery writer never created device_ids just for this update.
    if (!exists) return YES;
    ids[@"BatteryLevel"] = battery[@"BatteryLevel"]; ids[@"LowPowerMode"] = battery[@"LowPowerMode"];
    return [tx setDictionary:ids atPath:idsPath error:error];
}
BOOL PXStageRuntimeUptime(PXRuntimeSourceTransaction *tx, NSString *identity,
                         NSDictionary *boot, NSDictionary *uptime, NSDate *timestamp, NSError **error) {
    NSString *idsPath = PXArtifactPath(identity, @"device_ids.plist");
    NSMutableDictionary *ids = [[tx dictionaryAtPath:idsPath error:error] mutableCopy];
    if (!ids) return NO;
    ids[@"BootTime"] = [NSString stringWithFormat:@"%.0f", [boot[@"value"] timeIntervalSince1970]];
    ids[@"SystemUptime"] = uptime[@"value"]; ids[@"LastUpdated"] = timestamp;
    return [tx setDictionary:boot atPath:PXArtifactPath(identity, @"boot_time.plist") error:error] &&
        [tx setDictionary:uptime atPath:PXArtifactPath(identity, @"system_uptime.plist") error:error] &&
        [tx setDictionary:ids atPath:idsPath error:error];
}
