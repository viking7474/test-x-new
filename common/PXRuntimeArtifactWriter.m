#import "PXRuntimeArtifactWriter.h"
#include <math.h>

static NSString *PXArtifactPath(NSString *identity, NSString *file) {
    @try { return [identity stringByAppendingPathComponent:file]; }
    @finally { identity = nil; file = nil; }
}
static NSString *PXArtifactIPv6(NSDictionary *network, NSDictionary *ids) {
    id value = nil;
    @try {
        value = network[@"localIPv6Address"];
        if (![value isKindOfClass:NSString.class] || ![value length]) value = ids[@"LocalIPv6Address"];
        return [value isKindOfClass:NSString.class] && [value length] ? value : nil;
    } @finally { value = nil; network = nil; ids = nil; }
}
static BOOL PXStageAddressDictionaries(PXRuntimeSourceTransaction *tx, NSString *identity,
    NSMutableDictionary *network, NSMutableDictionary *ids, NSString *ipv4, NSString *ipv6, NSDate *timestamp, NSError **error) {
    NSString *networkPath = nil, *idsPath = nil;
    @try {
        if (ipv4 != nil) { network[@"localIPAddress"] = ipv4; ids[@"LocalIPAddress"] = ipv4; }
        if (ipv6 != nil) { network[@"localIPv6Address"] = ipv6; ids[@"LocalIPv6Address"] = ipv6; }
        network[@"lastUpdated"] = timestamp;
        networkPath = PXArtifactPath(identity, @"network_settings.plist");
        if (![tx setDictionary:network atPath:networkPath error:error]) return NO;
        idsPath = PXArtifactPath(identity, @"device_ids.plist");
        return [tx setDictionary:ids atPath:idsPath error:error];
    } @finally { idsPath = nil; networkPath = nil; timestamp = nil; ipv6 = nil; ipv4 = nil; ids = nil; network = nil; identity = nil; tx = nil; }
}
BOOL PXStageRuntimeIPv4WithExistingPair(PXRuntimeSourceTransaction *tx, NSString *identity,
    NSString *ipv4, NSDate *timestamp, BOOL *needsIPv6, NSError **error) {
    *needsIPv6 = YES;
    NSDictionary *base = nil;
    NSMutableDictionary *network = nil, *ids = nil;
    NSString *networkPath = nil, *idsPath = nil, *ipv6 = nil;
    @try {
        identity = [identity copy];
        ipv4 = [ipv4 copy];
        networkPath = PXArtifactPath(identity, @"network_settings.plist");
        base = [tx dictionaryAtPath:networkPath error:error]; network = [base mutableCopy];
        if (network) { idsPath = PXArtifactPath(identity, @"device_ids.plist"); base = [tx dictionaryAtPath:idsPath error:error]; ids = [base mutableCopy]; }
        if (!ids) return NO;
        ipv6 = PXArtifactIPv6(network, ids);
        if (!ipv6.length) return YES;
        *needsIPv6 = NO;
        return PXStageAddressDictionaries(tx, identity, network, ids, ipv4, ipv6, timestamp, error);
    } @finally { ipv6 = nil; idsPath = nil; networkPath = nil; ids = nil; network = nil; base = nil; timestamp = nil; ipv4 = nil; identity = nil; tx = nil; }
}
BOOL PXStageRuntimeAddresses(PXRuntimeSourceTransaction *tx, NSString *identity,
                            NSString *ipv4, NSString *ipv6, BOOL preserveIPv6, NSDate *timestamp, NSError **error) {
    NSDictionary *base = nil;
    NSMutableDictionary *network = nil, *ids = nil;
    NSString *networkPath = nil, *idsPath = nil;
    @try {
        identity = [identity copy];
        ipv4 = [ipv4 copy]; ipv6 = [ipv6 copy];
        networkPath = PXArtifactPath(identity, @"network_settings.plist");
        base = [tx dictionaryAtPath:networkPath error:error]; network = [base mutableCopy];
        if (network) { idsPath = PXArtifactPath(identity, @"device_ids.plist"); base = [tx dictionaryAtPath:idsPath error:error]; ids = [base mutableCopy]; }
        if (!ids) return NO;
        if (preserveIPv6) ipv6 = PXArtifactIPv6(network, ids) ?: ipv6;
        return PXStageAddressDictionaries(tx, identity, network, ids, ipv4, ipv6, timestamp, error);
    } @finally { idsPath = nil; networkPath = nil; ids = nil; network = nil; base = nil; timestamp = nil; ipv6 = nil; ipv4 = nil; identity = nil; tx = nil; }
}
static NSDictionary *PXArtifactCarrierSnapshot(NSDictionary *carrier) {
    NSMutableDictionary *changed = nil;
    id value = nil, frozen = nil;
    @try {
        carrier = [carrier copy];
        NSString *keys[] = { @"carrierName", @"mcc", @"mnc" };
        for (NSUInteger index = 0; index < 3; index++) {
            value = carrier[keys[index]];
            if ([value isKindOfClass:NSString.class]) {
                frozen = [value copy];
                if (frozen != value) {
                    if (!changed) changed = [carrier mutableCopy];
                    changed[keys[index]] = frozen;
                }
            }
            frozen = nil; value = nil;
        }
        return changed ? [changed copy] : carrier;
    } @finally { frozen = nil; value = nil; changed = nil; carrier = nil; }
}
BOOL PXStageRuntimeCarrier(PXRuntimeSourceTransaction *tx, NSString *identity,
                          NSDictionary *carrier, NSDate *timestamp, NSError **error) {
    NSString *networkPath = nil, *idsPath = nil, *carrierPath = nil;
    NSDictionary *base = nil;
    NSMutableDictionary *network = nil, *ids = nil;
    @try {
        identity = [identity copy];
        carrier = PXArtifactCarrierSnapshot(carrier);
        networkPath = PXArtifactPath(identity, @"network_settings.plist"); idsPath = PXArtifactPath(identity, @"device_ids.plist");
        base = [tx dictionaryAtPath:networkPath error:error]; network = [base mutableCopy];
        if (network) { base = [tx dictionaryAtPath:idsPath error:error]; ids = [base mutableCopy]; }
        if (!ids) return NO;
        network[@"carrierName"] = carrier[@"carrierName"]; network[@"mcc"] = carrier[@"mcc"]; network[@"mnc"] = carrier[@"mnc"];
        network[@"lastUpdated"] = timestamp;
        ids[@"CarrierName"] = carrier[@"carrierName"]; ids[@"CarrierMCC"] = carrier[@"mcc"]; ids[@"CarrierMNC"] = carrier[@"mnc"];
        carrierPath = PXArtifactPath(identity, @"carrier_details.plist");
        return [tx setDictionary:carrier atPath:carrierPath error:error] &&
            [tx setDictionary:network atPath:networkPath error:error] && [tx setDictionary:ids atPath:idsPath error:error];
    } @finally { ids = nil; network = nil; base = nil; carrierPath = nil; idsPath = nil; networkPath = nil; timestamp = nil; carrier = nil; identity = nil; tx = nil; }
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
    NSString *idsPath = nil, *bootPath = nil, *uptimePath = nil;
    NSDictionary *base = nil;
    NSMutableDictionary *ids = nil, *bootCopy = nil, *uptimeCopy = nil;
    NSDate *date = nil;
    id value = nil;
    @try {
        identity = [identity copy]; boot = [boot copy]; uptime = [uptime copy];
        if (![boot isKindOfClass:NSDictionary.class] || ![uptime isKindOfClass:NSDictionary.class]) return NO;
        date = [boot[@"value"] isKindOfClass:NSDate.class] ? [boot[@"value"] copy] : nil;
        value = uptime[@"value"];
        if (!date || !isfinite(date.timeIntervalSince1970) ||
            (![value isKindOfClass:NSString.class] && ![value isKindOfClass:NSNumber.class]) || !isfinite([value doubleValue])) return NO;
        bootCopy = [boot mutableCopy]; bootCopy[@"value"] = date;
        if ([boot[@"lastUpdated"] isKindOfClass:NSDate.class]) bootCopy[@"lastUpdated"] = [boot[@"lastUpdated"] copy];
        uptimeCopy = [uptime mutableCopy]; uptimeCopy[@"value"] = [value copy];
        if ([uptime[@"lastUpdated"] isKindOfClass:NSDate.class]) uptimeCopy[@"lastUpdated"] = [uptime[@"lastUpdated"] copy];
        boot = [bootCopy copy]; uptime = [uptimeCopy copy];
        idsPath = PXArtifactPath(identity, @"device_ids.plist");
        base = [tx dictionaryAtPath:idsPath error:error]; ids = [base mutableCopy];
        if (!ids) return NO;
        ids[@"BootTime"] = [NSString stringWithFormat:@"%.0f", date.timeIntervalSince1970];
        ids[@"SystemUptime"] = uptime[@"value"]; ids[@"LastUpdated"] = timestamp;
        bootPath = PXArtifactPath(identity, @"boot_time.plist");
        if (![tx setDictionary:boot atPath:bootPath error:error]) return NO;
        uptimePath = PXArtifactPath(identity, @"system_uptime.plist");
        return [tx setDictionary:uptime atPath:uptimePath error:error] && [tx setDictionary:ids atPath:idsPath error:error];
    } @finally { value = nil; date = nil; uptimeCopy = nil; bootCopy = nil; ids = nil; base = nil; uptimePath = nil; bootPath = nil; idsPath = nil; timestamp = nil; uptime = nil; boot = nil; identity = nil; tx = nil; }
}
