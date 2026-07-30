#import <Foundation/Foundation.h>
#import "PXIdentitySurfaceRegistry.h"

void PXRunIdentitySurfaceRegistryTests(void) {
    NSArray<NSString *> *failures = nil;
    NSCAssert(PXIdentitySurfaceRegistryIsWellFormed(&failures), @"registry malformed: %@", failures);

    NSDictionary *ids = @{ @"DeviceModel": @"iPhone15,3", @"HwModel": @"D74AP", @"BoardID": @"0x2C", @"ModelNumber": @"A2894", @"IOSVersion": @"17.5.1", @"IOSBuild": @"21F90" };
    PXIdentitySurfaceEntry *mgAlias = PXIdentitySurfaceEntryForKey(@"HardwareModel", PXIdentitySurfaceMobileGestalt);
    NSCAssert([mgAlias.canonicalKey isEqualToString:@"HWModelStr"], @"MG alias did not canonicalize");
    NSCAssert([[PXIdentitySurfaceResolveValue(mgAlias, ids) description] isEqualToString:@"D74AP"], @"MG alias resolved wrong source");

    PXIdentitySurfaceEntry *ioData = PXIdentitySurfaceEntryForKey(@"device-model", PXIdentitySurfaceIORegistry);
    NSCAssert(ioData.expectedType == PXIdentityExpectedTypeData, @"device-tree ABI type must be CFData");
    NSCAssert([ioData.toggle isEqualToString:@"DeviceModel"], @"IORegistry alias has wrong toggle");

    PXIdentitySurfaceEntry *buildAlias = PXIdentitySurfaceEntryForKey(@"BuildVersion", PXIdentitySurfaceMobileGestalt);
    NSCAssert([[PXIdentitySurfaceResolveValue(buildAlias, ids) description] isEqualToString:@"21F90"], @"build alias drifted");
    NSCAssert(PXIdentitySurfaceEntryForKey(@"BuildVersion", PXIdentitySurfaceIORegistry) == nil, @"surface isolation failed");

    PXIdentitySurfaceEntry *release = PXIdentitySurfaceEntryForKey(@"ReleaseType", PXIdentitySurfaceMobileGestalt);
    NSCAssert([[PXIdentitySurfaceResolveValue(release, @{}) description] isEqualToString:@"User"], @"constant source failed");
    NSLog(@"[HOOK-02/03] identity surface registry PASS");
}
