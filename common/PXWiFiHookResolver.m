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
    @try {
        return [info isKindOfClass:NSDictionary.class] && [info[@"ssid"] isKindOfClass:NSString.class] && [info[@"bssid"] isKindOfClass:NSString.class];
    } @finally { info = nil; }
}
static NSDictionary *PXWiFiHookFreeze(id info) {
    NSData *data = nil;
    id frozen = nil;
    @try {
        // Preserve predicate exceptions for the caller's provider/preparation catch.
        if (!PXWiFiHookHasPair(info)) return nil;
        @try {
            data = [NSPropertyListSerialization dataWithPropertyList:info format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
            frozen = data ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL] : nil;
            return PXWiFiHookHasPair(frozen) ? frozen : nil;
        } @catch (__unused NSException *exception) { return nil; }
    } @finally { frozen = nil; data = nil; info = nil; }
}
static NSDictionary *PXWiFiHookSourceInfo(NSDictionary *wifi, NSDictionary *ids) {
    NSString *value = nil, *ssid = nil, *bssid = nil;
    @try {
        if (PXWiFiHookHasPair(wifi)) return wifi;
        if ([ids[@"SSID"] isKindOfClass:NSString.class] && [ids[@"BSSID"] isKindOfClass:NSString.class])
            return @{ @"ssid": ids[@"SSID"], @"bssid": ids[@"BSSID"], @"networkType": @"Infrastructure" };
        value = [ids[@"WiFi"] isKindOfClass:NSString.class] ? ids[@"WiFi"] : nil;
        NSRange open = value.length ? [value rangeOfString:@"("] : NSMakeRange(NSNotFound, 0);
        NSRange close = value.length ? [value rangeOfString:@")" options:NSBackwardsSearch] : NSMakeRange(NSNotFound, 0);
        if (open.location != NSNotFound && close.location != NSNotFound && close.location > open.location + 1) {
            ssid = [[value substringToIndex:open.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            bssid = [value substringWithRange:NSMakeRange(open.location + 1, close.location - open.location - 1)];
            if (ssid.length && bssid.length) return @{ @"ssid": ssid, @"bssid": bssid, @"networkType": @"Infrastructure" };
        }
        return nil;
    } @finally { bssid = nil; ssid = nil; value = nil; ids = nil; wifi = nil; }
}
static NSDictionary *PXWiFiHookSelection(PXRuntimeSourceTransaction *tx, NSString *target, NSError **error) {
    NSDictionary *selection = nil, *legacy = nil;
    NSString *selected = nil;
    @try {
        selection = PXReadRuntimeProfileSelection(tx, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), error);
        if (!selection) return nil;
        selected = PXValidatedProfileID(selection[PXCurrentProfileInfoPath()][@"info"][@"ProfileId"]);
        legacy = selection[PXLegacyActiveProfileInfoPath()][@"info"];
        if (!selected) selected = PXValidatedProfileID(legacy[@"ProfileId"]) ?: PXValidatedProfileID(legacy[@"currentProfileId"]);
        if (![selected isEqualToString:target]) { PXWiFiHookError(error, 3021, @"WiFi requested profile is no longer active"); return nil; }
        return selection;
    } @finally { legacy = nil; selected = nil; selection = nil; target = nil; tx = nil; }
}

NSDictionary *PXResolveHookWiFiInfo(NSString *profileID, PXWiFiHookCacheReader cacheReader, NSError **error) {
    if (error) *error = nil;
    NSString *target = nil;
    BOOL (^admissionWrite)(PXRuntimeSourceTransaction *, NSError **) = nil;
    @try {
        target = [PXValidatedProfileID(profileID) copy];
        if (!target) { PXWiFiHookError(error, 3020, @"Invalid WiFi hook profile"); return nil; }
        // Standalone admission remains before the TLS check/provider so ignored
        // nested source staging still poisons its outer transaction.
        {
            admissionWrite = ^BOOL(PXRuntimeSourceTransaction *tx, NSError **failure) {
                @try { return PXWiFiHookSelection(tx, target, failure) != nil; }
                @finally { tx = nil; }
            };
        }
        BOOL admitted = PXPerformStandaloneRuntimeSourceWrite(admissionWrite, error);
        admissionWrite = nil;
        if (!admitted) return nil;
        if (gWiFiHookResolving) { PXWiFiHookError(error, 3025, @"WiFi hook resolution is already in progress"); return nil; }
        gWiFiHookResolving = YES;
        NSDictionary *cached = nil, *prepared = nil, *preparedInput = nil;
        id candidate = nil;
        NSError *cacheError = nil;
        PXProfileArtifactMutation *mutation = nil;
        // Own method-argument blocks in named slots. A temporary block
        // copy can otherwise retain captures when a callee throws under plain ARC.
        NSString *(^identityResolver)(void) = nil;
        BOOL (^sourceWrite)(PXRuntimeSourceTransaction *, NSError **) = nil;
        NSString *wifiPath = nil, *idsPath = nil;
        __block NSDictionary *selection = nil, *wifi = nil, *ids = nil, *resolved = nil;
        __block BOOL wifiExists = NO, idsExist = NO;
        @try {
            @try {
                candidate = cacheReader ? cacheReader(target, &cacheError) : nil;
                if (cacheError) { if (error) *error = cacheError; return nil; }
                cached = PXWiFiHookFreeze(candidate);
            } @catch (__unused NSException *exception) {
                PXWiFiHookError(error, 3023, @"WiFi cache provider failed"); return nil;
            } @finally { candidate = nil; cacheError = nil; }
            // Keep acquisition exceptions outside the preparation catch, as before.
            {
                identityResolver = ^NSString *{ return PXProfileIdentityPath(target); };
            }
            mutation = [PXProfileArtifactMutation acquireWithIdentityResolver:identityResolver error:error];
            identityResolver = nil;
            @try {
                if (!mutation) return nil;
                wifiPath = [mutation.identityDirectory stringByAppendingPathComponent:@"wifi_info.plist"];
                idsPath = [mutation.identityDirectory stringByAppendingPathComponent:@"device_ids.plist"];
                {
                    sourceWrite = ^BOOL(PXRuntimeSourceTransaction *tx, NSError **failure) {
                        @try {
                            selection = PXWiFiHookSelection(tx, target, failure);
                            if (!selection) return NO;
                            wifi = [tx dictionaryAtPath:wifiPath exists:&wifiExists error:failure];
                            ids = wifi ? [tx dictionaryAtPath:idsPath exists:&idsExist error:failure] : nil;
                            if (!ids) return NO;
                            resolved = PXWiFiHookSourceInfo(wifi, ids);
                            return YES;
                        } @finally { tx = nil; }
                    };
                }
                BOOL readSucceeded = [mutation performSourceWrite:sourceWrite error:error];
                sourceWrite = nil;
                if (!readSucceeded) return nil;
                if (resolved) return resolved;
                // Matching cache remains read-only and never seeds a source write.
                if (cached) return cached;
                preparedInput = PXPrepareRuntimeWiFiInfo();
                prepared = PXWiFiHookFreeze(preparedInput);
                preparedInput = nil; // The frozen packet is sufficient for commit.
                if (!prepared) { PXWiFiHookError(error, 3023, @"Invalid prepared WiFi hook record"); return nil; }
                {
                    sourceWrite = ^BOOL(PXRuntimeSourceTransaction *tx, NSError **failure) {
                        NSDictionary *currentWifi = nil, *currentIDs = nil;
                        NSMutableDictionary *merged = nil;
                        NSString *display = nil, *identity = nil;
                        NSDictionary *stagedIDs = nil;
                        @try {
                            if (!PXRuntimeProfileSelectionMatches(tx, selection, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), failure)) return NO;
                            BOOL nowWifi = NO, nowIDs = NO;
                            currentWifi = [tx dictionaryAtPath:wifiPath exists:&nowWifi error:failure];
                            currentIDs = currentWifi ? [tx dictionaryAtPath:idsPath exists:&nowIDs error:failure] : nil;
                            if (!currentIDs) return NO;
                            if (nowWifi != wifiExists || nowIDs != idsExist || ![currentWifi isEqual:wifi] || ![currentIDs isEqual:ids])
                                return PXWiFiHookError(failure, 3022, @"WiFi sources changed during preparation");
                            identity = mutation.identityDirectory;
                            if (!PXStageRuntimeWiFi(tx, identity, prepared, failure)) return NO;
                            stagedIDs = [tx dictionaryAtPath:idsPath error:failure];
                            merged = [stagedIDs mutableCopy];
                            if (!merged) return NO;
                            // Preserve the formatted display scalar in the paired commit.
                            display = [NSString stringWithFormat:@"%@ (%@)", prepared[@"ssid"], prepared[@"bssid"]];
                            merged[@"WiFi"] = display;
                            return [tx setDictionary:merged atPath:idsPath error:failure];
                        } @finally { stagedIDs = nil; identity = nil; display = nil; merged = nil; currentIDs = nil; currentWifi = nil; tx = nil; }
                    };
                }
                BOOL committed = [mutation performSourceWrite:sourceWrite error:error];
                sourceWrite = nil;
                return committed ? prepared : nil;
            } @catch (__unused NSException *exception) {
                PXWiFiHookError(error, 3023, @"WiFi hook preparation failed"); return nil;
            } @finally { [mutation invalidate]; }
        } @finally {
            // Release namespace ownership before dropping snapshots/callback roots.
            // Keep this thread's guard until cleanup finishes; nested calls must
            // never clear the outer resolver's guard.
            @try {
                sourceWrite = nil; identityResolver = nil;
                mutation = nil; resolved = nil; ids = nil; wifi = nil; selection = nil;
                prepared = nil; preparedInput = nil; idsPath = nil; wifiPath = nil; cached = nil;
            } @finally { gWiFiHookResolving = NO; }
        }
    } @finally { admissionWrite = nil; target = nil; cacheReader = nil; profileID = nil; }
}
