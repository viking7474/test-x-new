#import <Foundation/Foundation.h>
#import "PXLockdownResearchSafety.h"
#import "PXLockdownSoftwareModelProvider.h"

static PXLockdownSafetyDecision *PXAllowedDecision(PXLockdownResearchMode mode) {
    NSDictionary *settings = @{
        @"lockdownResearchEnabled": @YES,
        @"lockdownResearchMode": mode == PXLockdownResearchModeProfileBacked ? @"profile-backed" : @"observe-only",
        @"lockdownResearchBundleAllowlist": @[@"com.example.fixture"],
    };
    PXLockdownResearchPolicy *policy = [PXLockdownResearchPolicy policyFromSettings:settings];
    PXLockdownResearchRuntime *runtime = [[PXLockdownResearchRuntime alloc] initWithPolicy:policy];
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:1000];
    NSCAssert([runtime activateAt:now], @"fixture session did not arm");
    return [runtime decisionForBundleID:@"com.example.fixture" processName:@"Fixture" now:now];
}

void PXRunLockdownSoftwareModelTests(void) {
    NSArray<NSString *> *structural = nil;
    NSCAssert(PXLockdownSoftwareModelRegistryIsWellFormed(&structural),
              @"registry malformed: %@", structural);

    // A fully coherent software/model tuple.
    NSDictionary *goodIDs = @{
        @"IOSVersion": @"17.5.1",
        @"IOSBuild": @"21F90",
        @"Darwin": @"23.5.0",
        @"KernelVersion": @"Darwin Kernel Version 23.5.0",
        @"DeviceModel": @"iPhone15,3",
        @"HwModel": @"D74AP",
        @"BoardID": @"0x2C",
        @"ModelNumber": @"A2894",
        @"DeviceName": @"Research iPhone",
    };
    PXLockdownSoftwareModelOptions allOn = PXLockdownSoftwareModelOptionsFromSettings(@{
        @"lockdownSoftwareVersionEnabled": @YES,
        @"lockdownProductModelEnabled": @YES,
        @"lockdownDeviceNameEnabled": @YES,
    });
    PXLockdownSafetyDecision *allowed = PXAllowedDecision(PXLockdownResearchModeProfileBacked);
    NSArray<NSString *> *failures = nil;

    id product = PXLockdownSoftwareModelResolve(@"kLockdownProductVersionKey", @"orig", goodIDs, allOn, allowed, &failures);
    NSCAssert([product isEqual:@"17.5.1"], @"ProductVersion not projected");
    NSCAssert([product isKindOfClass:[NSString class]], @"ProductVersion must stay String");

    id build = PXLockdownSoftwareModelResolve(@"kLockdownBuildVersionKey", @"orig", goodIDs, allOn, allowed, &failures);
    NSCAssert([build isEqual:@"21F90"], @"BuildVersion not projected");

    id productType = PXLockdownSoftwareModelResolve(@"kLockdownProductTypeKey", @"orig", goodIDs, allOn, allowed, &failures);
    NSCAssert([productType isEqual:@"iPhone15,3"], @"ProductType not projected");

    id deviceName = PXLockdownSoftwareModelResolve(@"kLockdownDeviceNameKey", @"orig", goodIDs, allOn, allowed, &failures);
    NSCAssert([deviceName isEqual:@"Research iPhone"], @"DeviceName not projected");

    // Out-of-scope keys (device identity) must always pass through untouched.
    id serial = PXLockdownSoftwareModelResolve(@"kLockdownSerialNumberKey", @"orig-serial", goodIDs, allOn, allowed, &failures);
    NSCAssert([serial isEqual:@"orig-serial"], @"out-of-scope key must return original");

    // Grouped software toggle: build/version cannot flip on individually.
    PXLockdownSoftwareModelOptions modelOnly = PXLockdownSoftwareModelOptionsFromSettings(@{
        @"lockdownProductModelEnabled": @YES,
    });
    id gatedBuild = PXLockdownSoftwareModelResolve(@"kLockdownBuildVersionKey", @"orig", goodIDs, modelOnly, allowed, &failures);
    NSCAssert([gatedBuild isEqual:@"orig"], @"software group off must return original");
    id gatedProductType = PXLockdownSoftwareModelResolve(@"kLockdownProductTypeKey", @"orig", goodIDs, modelOnly, allowed, &failures);
    NSCAssert([gatedProductType isEqual:@"iPhone15,3"], @"model group on must still project");

    // Observe-only always returns original even when everything else allows.
    PXLockdownSafetyDecision *observe = PXAllowedDecision(PXLockdownResearchModeObserveOnly);
    id observed = PXLockdownSoftwareModelResolve(@"kLockdownProductVersionKey", @"orig", goodIDs, allOn, observe, &failures);
    NSCAssert([observed isEqual:@"orig"], @"observe-only must return original");

    // Missing snapshot value fails closed.
    NSMutableDictionary *missing = [goodIDs mutableCopy];
    [missing removeObjectForKey:@"DeviceName"];
    id missingName = PXLockdownSoftwareModelResolve(@"kLockdownDeviceNameKey", @"orig", missing, allOn, allowed, &failures);
    NSCAssert([missingName isEqual:@"orig"], @"missing snapshot value must return original");

    // Inconsistent tuple (build drift vs matrix) fails closed. IOSBuild is used
    // by both CFSystem/SystemVersion and sysctl surfaces, so a mismatch inside
    // the group is impossible; instead, a blank surface makes it partial.
    NSMutableDictionary *partial = [goodIDs mutableCopy];
    partial[@"IOSBuild"] = @""; // blanks the whole ProductBuildVersion group
    id partialBuild = PXLockdownSoftwareModelResolve(@"kLockdownBuildVersionKey", @"orig", partial, allOn, allowed, &failures);
    NSCAssert([partialBuild isEqual:@"orig"], @"inconsistent/partial group must return original");

    NSLog(@"[LOCK-03/05] Lockdown software/model provider PASS");
}
