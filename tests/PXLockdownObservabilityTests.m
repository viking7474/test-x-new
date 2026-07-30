#import <Foundation/Foundation.h>
#import "PXLockdownObservability.h"
#import "PXLockdownSoftwareModelProvider.h"
#import "PXLockdownDeviceIdentityProvider.h"
#import "PXLockdownSoCCellularProvider.h"

void PXRunLockdownObservabilityTests(void) {
    NSArray<NSString *> *structural = nil;
    // inventory must represent every provider key exactly once
    NSCAssert(PXLockdownObservabilityInventoryIsWellFormed(&structural),
              @"inventory malformed: %@", structural);
    NSUInteger providerTotal = PXLockdownSoftwareModelEntries().count
        + PXLockdownDeviceIdentityEntries().count
        + PXLockdownSoCCellularEntries().count;
    NSCAssert(PXLockdownObservedKeyInventory().count == providerTotal,
              @"inventory must cover every provider entry");

    // device identity and telephony identifiers must be flagged sensitive
    PXLockdownObservedKey *udid = PXLockdownObservedKeyForLockdownKey(@"kLockdownUniqueDeviceIDKey");
    NSCAssert(udid.isSensitive, @"UDID must be sensitive");
    PXLockdownObservedKey *imei = PXLockdownObservedKeyForLockdownKey(@"kLockdownIMEIKey");
    NSCAssert(imei.isSensitive, @"IMEI must be sensitive");
    PXLockdownObservedKey *chip = PXLockdownObservedKeyForLockdownKey(@"kLockdownUniqueChipIDKey");
    NSCAssert(chip.expectedClass == [NSNumber class], @"UniqueChipID must project as NSNumber");
    PXLockdownObservedKey *build = PXLockdownObservedKeyForLockdownKey(@"kLockdownBuildVersionKey");
    NSCAssert(build != nil && !build.isSensitive, @"presentation keys are non-sensitive");

    // sensitive identifiers must be redacted in the observation record
    NSDictionary *record = PXLockdownObservationRecord(@"Fixture", @"kLockdownUniqueDeviceIDKey",
                                                       @"00008101-000000000000001E", @"lockdown");
    NSCAssert([record[@"payload"] isEqual:@"<redacted>"], @"sensitive payload must be redacted");
    NSCAssert([record[@"sourceProvider"] isEqual:@"PXLockdownDeviceIdentityProvider"],
              @"record must name the source provider");
    NSCAssert([record[@"mode"] isEqual:@"observe"], @"observe-only mode must be recorded");

    // forbidden pairing/certificate/private-key/escrow domains must be refused
    NSCAssert(PXLockdownObservationDomainIsForbidden(@"com.apple.mobile.pairing.PairRecord"),
              @"pair record domain must be forbidden");
    NSCAssert(PXLockdownObservationDomainIsForbidden(@"EscrowBag"), @"escrow domain must be forbidden");
    NSCAssert(PXLockdownObservationRecord(@"Fixture", @"kLockdownSerialNumberKey",
                                          @"F2LABCDE1234", @"com.apple.certificate") == nil,
              @"forbidden domain must produce no record");

    // unknown key must not produce a record
    NSCAssert(PXLockdownObservationRecord(@"Fixture", @"kLockdownNotARealKey", @"x", @"lockdown") == nil,
              @"unknown key must not produce a record");

    // metrics must count accesses, timeouts and cache behavior
    PXLockdownAccessMetrics *metrics = [[PXLockdownAccessMetrics alloc] init];
    [metrics recordAccessForKey:@"kLockdownIMEIKey" timedOut:NO cacheHit:NO];
    [metrics recordAccessForKey:@"kLockdownIMEIKey" timedOut:YES cacheHit:YES];
    NSCAssert([metrics accessCountForKey:@"kLockdownIMEIKey"] == 2, @"frequency must accumulate");
    NSCAssert([metrics timeoutCountForKey:@"kLockdownIMEIKey"] == 1, @"timeouts must accumulate");
    NSCAssert([metrics cacheHitCountForKey:@"kLockdownIMEIKey"] == 1, @"cache hits must accumulate");
    NSCAssert([metrics cacheMissCountForKey:@"kLockdownIMEIKey"] == 1, @"cache misses must accumulate");
    NSCAssert([metrics totalAccessCount] == 2, @"total accesses must accumulate");

    NSLog(@"Lockdown observe-only (L0) contracts: PASS");
}
