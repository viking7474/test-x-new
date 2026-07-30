#import <Foundation/Foundation.h>
#import "PXIdentityValidator.h"
#import "PXIdentityDependencyValidator.h"

static NSDictionary *PXPhase2BuildRoot(void) {
    NSString *kernel = @"Darwin Kernel Version 23.5.0: Wed May  1 20:35:37 PDT 2024; root:xnu-10063.121.3~2/RELEASE_ARM64_T8130";
    return @{
        @"buildToMeta": @{
            @"21F90": @{ @"version": @"17.5.1", @"darwin": @"23.5.0", @"xnu": @"10063.121.3~2", @"kernel_version": kernel }
        },
        @"deviceToBuilds": @{ @"iPhone15,3": @[@"21F90"], @"iPad14,1": @[@"21F90"] }
    };
}

static NSDictionary *PXPhase2ModelRoot(void) {
    return @{ @"models": @[
        @{ @"productType": @"iPhone15,3", @"hasCellular": @YES,
           @"variants": @[@{ @"boardID": @"0x2C", @"hwModel": @"D74AP" }] },
        @{ @"productType": @"iPad14,1", @"hasCellular": @NO,
           @"variants": @[@{ @"boardID": @"0x10", @"hwModel": @"J407AP" }] }
    ] };
}

static NSDictionary *PXPhase2CanonicalProfile(void) {
    return @{
        @"DeviceModel": @"iPhone15,3", @"BoardID": @"0x2C", @"HwModel": @"D74AP",
        @"IOSVersion": @"17.5.1", @"IOSBuild": @"21F90", @"Darwin": @"23.5.0",
        @"XNU": @"10063.121.3~2",
        @"KernelVersion": @"Darwin Kernel Version 23.5.0: Wed May  1 20:35:37 PDT 2024; root:xnu-10063.121.3~2/RELEASE_ARM64_T8130",
        @"GenerationCounter": @7
    };
}

void PXRunPhase2ValidatorTests(void) {
    NSDictionary *buildRoot = PXPhase2BuildRoot();
    NSDictionary *modelRoot = PXPhase2ModelRoot();

    PXIdentityValidationResult *format = PXValidateDeviceIDs(PXPhase2CanonicalProfile());
    NSCAssert(format.inputValid && format.issues.count == 0, @"canonical format rejected: %@", format.issues);
    PXIdentityDependencyValidationResult *dependencies = PXValidateIdentityDependencies(format.deviceIDs, buildRoot, modelRoot);
    NSCAssert(dependencies.valid, @"canonical dependencies rejected: %@", dependencies.issues);

    NSMutableDictionary *badVersion = [PXPhase2CanonicalProfile() mutableCopy];
    badVersion[@"IOSVersion"] = @"17.4.1";
    NSCAssert(!PXValidateIdentityDependencies(badVersion, buildRoot, modelRoot).valid,
              @"version/build mismatch was accepted");

    NSMutableDictionary *partial = [PXPhase2CanonicalProfile() mutableCopy];
    [partial removeObjectForKey:@"XNU"];
    NSCAssert(!PXValidateIdentityDependencies(partial, buildRoot, modelRoot).valid,
              @"partial software tuple was accepted");

    NSMutableDictionary *badHardware = [PXPhase2CanonicalProfile() mutableCopy];
    badHardware[@"HwModel"] = @"WRONGAP";
    NSCAssert(!PXValidateIdentityDependencies(badHardware, buildRoot, modelRoot).valid,
              @"invalid hardware variant was accepted");

    NSMutableDictionary *wifiOnly = [PXPhase2CanonicalProfile() mutableCopy];
    wifiOnly[@"DeviceModel"] = @"iPad14,1";
    wifiOnly[@"BoardID"] = @"0x10";
    wifiOnly[@"HwModel"] = @"J407AP";
    wifiOnly[@"IMEI"] = @"353918123456786";
    NSCAssert(!PXValidateIdentityDependencies(wifiOnly, buildRoot, modelRoot).valid,
              @"cellular value on Wi-Fi-only model was accepted");

    NSCAssert(!PXValidateIdentityDependencies(PXPhase2CanonicalProfile(), nil, nil).valid,
              @"profile requiring a database was accepted without one");

    NSLog(@"[PHASE-2] format + dependency validator tests passed");
}
