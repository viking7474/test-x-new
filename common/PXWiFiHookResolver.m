#import "PXWiFiHookResolver.h"
#import "PXPaths.h"
#import "PXProfileArtifactMutation.h"
#import "PXRuntimeArtifactPreparation.h"
#import "PXRuntimeArtifactWriter.h"
#import "PXRuntimeProfileSelection.h"

static __thread BOOL gWiFiHookResolving = NO;

static BOOL PXWiFiHookError(NSError **error, NSInteger code, NSString *message) {
    if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios.wifi-hook" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}
static BOOL PXWiFiHookHasPair(id info) {
    return [info isKindOfClass:NSDictionary.class] && [info[@"ssid"] isKindOfClass:NSString.class] && [info[@"bssid"] isKindOfClass:NSString.class];
}
static NSDictionary *PXWiFiHookFreeze(id info) {
    if (!PXWiFiHookHasPair(info)) return nil;
    @try {
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:info format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
        id frozen = data ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL] : nil;
        return PXWiFiHookHasPair(frozen) ? frozen : nil;
    } @catch (NSException *exception) { (void)exception; return nil; }
}
static NSDictionary *PXWiFiHookSourceInfo(NSDictionary *wifi, NSDictionary *ids) {
    if (PXWiFiHookHasPair(wifi)) return wifi;
    if ([ids[@"SSID"] isKindOfClass:NSString.class] && [ids[@"BSSID"] isKindOfClass:NSString.class])
        return @{ @"ssid": ids[@"SSID"], @"bssid": ids[@"BSSID"], @"networkType": @"Infrastructure" };
    NSString *value = [ids[@"WiFi"] isKindOfClass:NSString.class] ? ids[@"WiFi"] : nil;
    NSRange open = value.length ? [value rangeOfString:@"("] : NSMakeRange(NSNotFound, 0);
    NSRange close = value.length ? [value rangeOfString:@")" options:NSBackwardsSearch] : NSMakeRange(NSNotFound, 0);
    if (open.location != NSNotFound && close.location != NSNotFound && close.location > open.location + 1) {
        NSString *ssid = [[value substringToIndex:open.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *bssid = [value substringWithRange:NSMakeRange(open.location + 1, close.location - open.location - 1)];
        if (ssid.length && bssid.length) return @{ @"ssid": ssid, @"bssid": bssid, @"networkType": @"Infrastructure" };
    }
    return nil;
}
static NSDictionary *PXWiFiHookSelection(PXRuntimeSourceTransaction *tx, NSString *target, NSError **error) {
    NSDictionary *selection = PXReadRuntimeProfileSelection(tx, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), error);
    if (!selection) return nil;
    NSString *selected = PXValidatedProfileID(selection[PXCurrentProfileInfoPath()][@"info"][@"ProfileId"]);
    NSDictionary *legacy = selection[PXLegacyActiveProfileInfoPath()][@"info"];
    if (!selected) selected = PXValidatedProfileID(legacy[@"ProfileId"]) ?: PXValidatedProfileID(legacy[@"currentProfileId"]);
    if (![selected isEqualToString:target]) { PXWiFiHookError(error, 3021, @"WiFi requested profile is no longer active"); return nil; }
    return selection;
}

NSDictionary *PXResolveHookWiFiInfo(NSString *profileID, PXWiFiHookCacheReader cacheReader, NSError **error) {
    if (error) *error = nil;
    NSString *target = [PXValidatedProfileID(profileID) copy];
    if (!target) { PXWiFiHookError(error, 3020, @"Invalid WiFi hook profile"); return nil; }
    // Reject nested staging before optional singleton/provider work. This also
    // rejects an already-stale request before warming any provider.
    if (!PXPerformStandaloneRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **failure) {
        return PXWiFiHookSelection(tx, target, failure) != nil;
    }, error)) return nil;
    // A singleton initializer can reenter a hook before it owns lifecycle.
    // Keep standalone admission first so nested source staging still poisons.
    if (gWiFiHookResolving) { PXWiFiHookError(error, 3025, @"WiFi hook resolution is already in progress"); return nil; }
    gWiFiHookResolving = YES;
    @try {
        NSDictionary *cached = nil;
        @try {
            NSError *cacheError = nil;
            id candidate = cacheReader ? cacheReader(target, &cacheError) : nil;
            if (cacheError) { if (error) *error = cacheError; return nil; }
            cached = PXWiFiHookFreeze(candidate);
        } @catch (NSException *exception) {
            (void)exception; PXWiFiHookError(error, 3023, @"WiFi cache provider failed"); return nil;
        }
        PXProfileArtifactMutation *mutation = [PXProfileArtifactMutation acquireWithIdentityResolver:^NSString *{
            return PXProfileIdentityPath(target);
        } error:error];
        @try {
            if (!mutation) return nil;
            NSString *wifiPath = [mutation.identityDirectory stringByAppendingPathComponent:@"wifi_info.plist"];
            NSString *idsPath = [mutation.identityDirectory stringByAppendingPathComponent:@"device_ids.plist"];
            __block NSDictionary *selection = nil, *wifi = nil, *ids = nil, *resolved = nil;
            __block BOOL wifiExists = NO, idsExist = NO;
            if (![mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **failure) {
                selection = PXWiFiHookSelection(tx, target, failure);
                if (!selection) return NO;
                wifi = [tx dictionaryAtPath:wifiPath exists:&wifiExists error:failure];
                ids = wifi ? [tx dictionaryAtPath:idsPath exists:&idsExist error:failure] : nil;
                if (!ids) return NO;
                resolved = PXWiFiHookSourceInfo(wifi, ids);
                return YES;
            } error:error]) return nil;
            if (resolved) return resolved;
            // Preserve the old same-profile, read-only cache fallback. A candidate
            // is not a persistence acknowledgement and is never staged as a seed.
            if (cached) return cached;
            NSDictionary *prepared = PXWiFiHookFreeze(PXPrepareRuntimeWiFiInfo());
            if (!prepared) { PXWiFiHookError(error, 3023, @"Invalid prepared WiFi hook record"); return nil; }
            BOOL committed = [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **failure) {
                if (!PXRuntimeProfileSelectionMatches(tx, selection, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), failure)) return NO;
                BOOL nowWifi = NO, nowIDs = NO;
                NSDictionary *currentWifi = [tx dictionaryAtPath:wifiPath exists:&nowWifi error:failure];
                NSDictionary *currentIDs = currentWifi ? [tx dictionaryAtPath:idsPath exists:&nowIDs error:failure] : nil;
                if (!currentIDs) return NO;
                if (nowWifi != wifiExists || nowIDs != idsExist || ![currentWifi isEqual:wifi] || ![currentIDs isEqual:ids])
                    return PXWiFiHookError(failure, 3022, @"WiFi sources changed during preparation");
                if (!PXStageRuntimeWiFi(tx, mutation.identityDirectory, prepared, failure)) return NO;
                NSMutableDictionary *merged = [[tx dictionaryAtPath:idsPath error:failure] mutableCopy];
                if (!merged) return NO;
                // Retain the display scalar written by the former hook fallback.
                merged[@"WiFi"] = [NSString stringWithFormat:@"%@ (%@)", prepared[@"ssid"], prepared[@"bssid"]];
                return [tx setDictionary:merged atPath:idsPath error:failure];
            } error:error];
            return committed ? prepared : nil;
        } @catch (NSException *exception) {
            (void)exception; PXWiFiHookError(error, 3023, @"WiFi hook preparation failed"); return nil;
        } @finally { [mutation invalidate]; }
    } @finally { gWiFiHookResolving = NO; }
}
