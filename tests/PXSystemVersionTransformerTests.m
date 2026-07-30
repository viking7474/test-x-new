#import <Foundation/Foundation.h>
#import "PXSystemVersionTransformer.h"

// Compile/run this file with the iOS/macOS Foundation test harness. It intentionally
// uses assertions only so it can also be embedded in a small command-line target.
static PXSystemVersionProjection *PXTestProjection(void) {
    PXSystemVersionProjection *projection = [PXSystemVersionProjection new];
    [projection setValue:@"17.5.1" forKey:@"productVersion"];
    [projection setValue:@"21F90" forKey:@"productBuildVersion"];
    [projection setValue:@"User" forKey:@"releaseType"];
    [projection setValue:@7 forKey:@"generation"];
    return projection;
}

void PXRunSystemVersionTransformerTests(void) {
    PXSystemVersionProjection *projection = PXTestProjection();
    NSDictionary *source = @{
        @"ProductVersion": @"16.0",
        @"ProductBuildVersion": @"20A362",
        @"ReleaseType": @"Beta",
        @"UnknownKey": @"preserve-me"
    };

    NSDictionary *result = PXTransformSystemVersionDictionary(source, projection);
    NSCAssert(result != source, @"transform must publish a new immutable dictionary");
    NSCAssert([source[@"ProductVersion"] isEqual:@"16.0"], @"input must not mutate");
    NSCAssert([result[@"ProductVersion"] isEqual:@"17.5.1"], @"version mismatch");
    NSCAssert([result[@"ProductBuildVersion"] isEqual:@"21F90"], @"build mismatch");
    NSCAssert([result[@"ReleaseType"] isEqual:@"User"], @"release type mismatch");
    NSCAssert([result[@"UnknownKey"] isEqual:@"preserve-me"], @"unknown key lost");

    for (NSNumber *formatNumber in @[@(NSPropertyListXMLFormat_v1_0), @(NSPropertyListBinaryFormat_v1_0)]) {
        NSPropertyListFormat format = (NSPropertyListFormat)formatNumber.unsignedIntegerValue;
        NSData *encoded = [NSPropertyListSerialization dataWithPropertyList:source format:format options:0 error:nil];
        NSData *transformed = PXTransformSystemVersionData(encoded, projection);
        NSPropertyListFormat outputFormat = 0;
        NSDictionary *decoded = [NSPropertyListSerialization propertyListWithData:transformed options:0 format:&outputFormat error:nil];
        NSCAssert(outputFormat == format, @"plist format changed");
        NSCAssert([decoded[@"ProductVersion"] isEqual:@"17.5.1"], @"data version mismatch");
        NSCAssert([decoded[@"UnknownKey"] isEqual:@"preserve-me"], @"data unknown key lost");
    }

    NSData *invalid = [@"not a plist" dataUsingEncoding:NSUTF8StringEncoding];
    NSCAssert(PXTransformSystemVersionData(invalid, projection) == invalid, @"invalid data must fail open");
    NSCAssert(PXTransformSystemVersionDictionary(source, nil) == source, @"nil projection must fail open");

    NSCAssert(PXIsSystemVersionPlistPath(@"/System/Library/CoreServices/SystemVersion.plist"), @"canonical path rejected");
    NSCAssert(PXIsSystemVersionPlistPath(@"/var/jb/System/Library/CoreServices/SystemVersion.plist"), @"rootless path rejected");
    NSCAssert(!PXIsSystemVersionPlistPath(@"/tmp/SystemVersion.plist"), @"broad suffix accepted");
}
