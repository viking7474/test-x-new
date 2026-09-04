#import <Foundation/Foundation.h>
#import "PXCoreTelephonyServerIdentity.h"

static NSDictionary<NSString *, id> *PXCTFixtureRuntimeKeys(void) {
    return @{
        @"kCTMobileEquipmentInfoCurrentMobileId": @"runtime.current-mobile-id",
        @"kCTMobileEquipmentInfoIMEI": @"runtime.imei",
        @"kCTMobileEquipmentInfoIMSI": @"runtime.imsi",
        @"kCTMobileEquipmentInfoMEID": @"runtime.meid",
        @"kCTPostponementInfoIMEI": @"runtime.postponement-imei",
        @"kCTPostponementInfoMEID": @"runtime.postponement-meid",
    };
}

static NSDictionary *PXCTFixtureDeviceIDs(NSString *suffix) {
    return @{
        @"IMEI": [@"490154203237518" stringByAppendingString:suffix ?: @""],
        @"IMEI2": @"356938035643809",
        @"MEID": [@"A00000BEEF1234" stringByAppendingString:suffix ?: @""],
        @"IMSI": [@"310260123456789" stringByAppendingString:suffix ?: @""],
    };
}

static NSMutableDictionary *PXCTFullOriginalDictionary(void) {
    return [@{
        @"runtime.current-mobile-id": @"orig-current",
        @"runtime.imei": @"orig-imei",
        @"runtime.imsi": @"orig-imsi",
        @"runtime.meid": @"orig-meid",
        @"runtime.postponement-imei": @"orig-post-imei",
        @"runtime.postponement-meid": @"orig-post-meid",
        @"unknown-field": @"preserve-me",
    } mutableCopy];
}

void PXRunCoreTelephonyServerIdentityTests(void) {
    NSDictionary<NSString *, id> *keys = PXCTFixtureRuntimeKeys();
    NSSet<NSString *> *allOn = [NSSet setWithArray:@[@"IMEI", @"IMSI", @"MEID"]];
    NSDictionary *ids = PXCTFixtureDeviceIDs(@"");

    NSMutableDictionary *full = PXCTFullOriginalDictionary();
    BOOL changed = PXCoreTelephonyServerApplyIdentityOverlay(full, keys, ids, allOn);
    NSCAssert(changed, @"full CTServer fixture was not changed");
    NSCAssert([full[@"runtime.imei"] isEqual:ids[@"IMEI"]], @"IMEI did not project");
    NSCAssert([full[@"runtime.postponement-imei"] isEqual:ids[@"IMEI"]], @"postponement IMEI did not share canonical IMEI");
    NSCAssert([full[@"runtime.imsi"] isEqual:ids[@"IMSI"]], @"IMSI did not project");
    NSCAssert([full[@"runtime.current-mobile-id"] isEqual:ids[@"MEID"]], @"CurrentMobileId did not map to MEID");
    NSCAssert([full[@"runtime.meid"] isEqual:ids[@"MEID"]], @"MEID did not project");
    NSCAssert([full[@"runtime.postponement-meid"] isEqual:ids[@"MEID"]], @"postponement MEID did not share canonical MEID");
    NSCAssert([full[@"unknown-field"] isEqual:@"preserve-me"], @"unknown field was modified");

    // Exact iFake parity: this six-field surface has no IMEI2 key. The canonical
    // IMEI2 fixture must not leak into any primary/postponement IMEI field.
    NSCAssert(![full[@"runtime.imei"] isEqual:ids[@"IMEI2"]], @"IMEI2 incorrectly collapsed into CTServer primary IMEI");

    // Missing eligible field stays absent; the transformer must never synthesize
    // dictionary shape that the original private API did not publish.
    NSMutableDictionary *missing = PXCTFullOriginalDictionary();
    [missing removeObjectForKey:@"runtime.meid"];
    PXCoreTelephonyServerApplyIdentityOverlay(missing, keys, ids, allOn);
    NSCAssert(missing[@"runtime.meid"] == nil, @"absent MEID field was synthesized");
    NSCAssert([missing[@"runtime.current-mobile-id"] isEqual:ids[@"MEID"]], @"existing MEID alias was not projected");

    // Toggle isolation: IMEI off leaves both IMEI aliases original while MEID/IMSI
    // still project from the same snapshot.
    NSMutableDictionary *imeiOff = PXCTFullOriginalDictionary();
    NSSet *withoutIMEI = [NSSet setWithArray:@[@"IMSI", @"MEID"]];
    PXCoreTelephonyServerApplyIdentityOverlay(imeiOff, keys, ids, withoutIMEI);
    NSCAssert([imeiOff[@"runtime.imei"] isEqual:@"orig-imei"], @"IMEI changed while toggle was off");
    NSCAssert([imeiOff[@"runtime.postponement-imei"] isEqual:@"orig-post-imei"], @"postponement IMEI changed while toggle was off");
    NSCAssert([imeiOff[@"runtime.imsi"] isEqual:ids[@"IMSI"]], @"IMSI was incorrectly coupled to IMEI toggle");

    // Partial/malformed profile values fail open field-by-field.
    NSMutableDictionary *partial = PXCTFullOriginalDictionary();
    NSDictionary *partialIDs = @{ @"IMEI": @"490154203237518", @"MEID": @42, @"IMSI": @"" };
    PXCoreTelephonyServerApplyIdentityOverlay(partial, keys, partialIDs, allOn);
    NSCAssert([partial[@"runtime.imei"] isEqual:@"490154203237518"], @"valid partial IMEI did not project");
    NSCAssert([partial[@"runtime.meid"] isEqual:@"orig-meid"], @"non-string MEID did not fail open");
    NSCAssert([partial[@"runtime.imsi"] isEqual:@"orig-imsi"], @"empty IMSI did not fail open");

    // V1/V2 share the same pure overlay semantics and therefore the same canonical
    // truth even when their runtime key objects differ.
    NSMutableDictionary *v1 = PXCTFullOriginalDictionary();
    NSMutableDictionary *v2 = [@{
        @"v2.current-mobile-id": @"old",
        @"v2.imei": @"old",
        @"v2.imsi": @"old",
        @"v2.meid": @"old",
        @"v2.post-imei": @"old",
        @"v2.post-meid": @"old",
    } mutableCopy];
    NSDictionary *v2Keys = @{
        @"kCTMobileEquipmentInfoCurrentMobileId": @"v2.current-mobile-id",
        @"kCTMobileEquipmentInfoIMEI": @"v2.imei",
        @"kCTMobileEquipmentInfoIMSI": @"v2.imsi",
        @"kCTMobileEquipmentInfoMEID": @"v2.meid",
        @"kCTPostponementInfoIMEI": @"v2.post-imei",
        @"kCTPostponementInfoMEID": @"v2.post-meid",
    };
    PXCoreTelephonyServerApplyIdentityOverlay(v1, keys, ids, allOn);
    PXCoreTelephonyServerApplyIdentityOverlay(v2, v2Keys, ids, allOn);
    NSCAssert([v1[@"runtime.imei"] isEqual:v2[@"v2.imei"]], @"V1/V2 IMEI diverged");
    NSCAssert([v1[@"runtime.imsi"] isEqual:v2[@"v2.imsi"]], @"V1/V2 IMSI diverged");
    NSCAssert([v1[@"runtime.meid"] isEqual:v2[@"v2.meid"]], @"V1/V2 MEID diverged");

    // No snapshot cache exists in this transformer: the next generation's values
    // are consumed immediately on the next call.
    NSMutableDictionary *nextGeneration = PXCTFullOriginalDictionary();
    NSDictionary *ids2 = PXCTFixtureDeviceIDs(@"9");
    PXCoreTelephonyServerApplyIdentityOverlay(nextGeneration, keys, ids2, allOn);
    NSCAssert([nextGeneration[@"runtime.imei"] isEqual:ids2[@"IMEI"]], @"generation swap returned stale IMEI");
    NSCAssert([nextGeneration[@"runtime.meid"] isEqual:ids2[@"MEID"]], @"generation swap returned stale MEID");

    NSCAssert(!PXCoreTelephonyServerApplyIdentityOverlay(nil, keys, ids, allOn), @"nil information must be a no-op");
    NSLog(@"[A-02] CoreTelephony server identity overlay PASS");
}
