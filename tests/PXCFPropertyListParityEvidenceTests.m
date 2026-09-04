#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import "PXSystemVersionTransformer.h"

// C-02 evidence fixture.
//
// The production SystemVersion owner transforms path-qualified raw NSData before
// a caller reaches CFPropertyListCreateWithData. These tests exercise that exact
// consumer API without installing a parser hook, and also prove why a key-only
// global parser hook would be unsafe: an unrelated in-memory/app plist can have
// the same ProductVersion/ProductBuildVersion/ReleaseType key family.

static PXSystemVersionProjection *PXC02Projection(void) {
    PXSystemVersionProjection *projection = [PXSystemVersionProjection new];
    [projection setValue:@"17.5.1" forKey:@"productVersion"];
    [projection setValue:@"21F90" forKey:@"productBuildVersion"];
    [projection setValue:@"User" forKey:@"releaseType"];
    [projection setValue:@"c02-evidence" forKey:@"profileID"];
    [projection setValue:@42 forKey:@"generation"];
    return projection;
}

static NSDictionary *PXC02SourceDictionary(void) {
    return @{
        @"ProductVersion": @"16.0",
        @"ProductBuildVersion": @"20A362",
        @"ReleaseType": @"Beta",
        @"ProductName": @"iPhone OS",
        @"UnknownKey": @"preserve-me"
    };
}

// Mirrors IOSVersionHooks.x's path-qualified NSData boundary without duplicating
// any parser semantics. The production hook performs the same two decisions:
// exact SystemVersion provenance first, then PXTransformSystemVersionData.
static NSData *PXC02PathBoundRawRead(NSString *path,
                                     NSData *originalData,
                                     PXSystemVersionProjection *projection) {
    if (!originalData || !PXIsSystemVersionPlistPath(path)) return originalData;
    return PXTransformSystemVersionData(originalData, projection);
}

static NSDictionary *PXC02ParseWithExactCFAPI(NSData *data,
                                               BOOL *outHadError,
                                               CFPropertyListFormat *outFormat) {
    if (outHadError) *outHadError = NO;
    if (outFormat) *outFormat = 0;
    if (![data isKindOfClass:[NSData class]]) return nil;

    CFErrorRef error = NULL;
    CFPropertyListFormat format = 0;
    CFPropertyListRef root = CFPropertyListCreateWithData(kCFAllocatorDefault,
                                                          (__bridge CFDataRef)data,
                                                          kCFPropertyListImmutable,
                                                          &format,
                                                          &error);
    if (outHadError) *outHadError = (error != NULL);
    if (outFormat) *outFormat = format;
    if (error) CFRelease(error);
    if (!root) return nil;
    if (CFGetTypeID(root) != CFDictionaryGetTypeID()) {
        CFRelease(root);
        return nil;
    }
    return CFBridgingRelease(root);
}

static void PXC02AssertProjectedDictionary(NSDictionary *dictionary) {
    NSCAssert([dictionary[@"ProductVersion"] isEqual:@"17.5.1"], @"C-02 projected ProductVersion mismatch");
    NSCAssert([dictionary[@"ProductBuildVersion"] isEqual:@"21F90"], @"C-02 projected ProductBuildVersion mismatch");
    NSCAssert([dictionary[@"ReleaseType"] isEqual:@"User"], @"C-02 projected ReleaseType mismatch");
    NSCAssert([dictionary[@"UnknownKey"] isEqual:@"preserve-me"], @"C-02 unknown key was not preserved");
}

void PXRunCFPropertyListParityEvidenceTests(void) {
    PXSystemVersionProjection *projection = PXC02Projection();
    NSDictionary *source = PXC02SourceDictionary();
    NSString *canonicalPath = @"/System/Library/CoreServices/SystemVersion.plist";
    NSString *rootlessPath = @"/var/jb/System/Library/CoreServices/SystemVersion.plist";
    NSString *genericPath = @"/tmp/app-owned.plist";

    for (NSNumber *formatNumber in @[@(NSPropertyListXMLFormat_v1_0), @(NSPropertyListBinaryFormat_v1_0)]) {
        NSPropertyListFormat sourceFormat = (NSPropertyListFormat)formatNumber.unsignedIntegerValue;
        NSData *encoded = [NSPropertyListSerialization dataWithPropertyList:source
                                                                      format:sourceFormat
                                                                     options:0
                                                                       error:nil];
        NSCAssert(encoded.length > 0, @"C-02 fixture serialization failed");

        // Proven SystemVersion route: raw data is already projected before the
        // exact CF parser runs, so no CFPropertyListCreateWithData hook is needed.
        NSData *upstreamProjected = PXC02PathBoundRawRead(canonicalPath, encoded, projection);
        NSCAssert(upstreamProjected != encoded, @"C-02 canonical raw-data boundary did not transform");
        BOOL parserError = NO;
        CFPropertyListFormat parsedFormat = 0;
        NSDictionary *parsed = PXC02ParseWithExactCFAPI(upstreamProjected, &parserError, &parsedFormat);
        NSCAssert(!parserError && parsed != nil, @"C-02 exact CF parser rejected transformed SystemVersion data");
        NSCAssert(parsedFormat == sourceFormat, @"C-02 upstream transformer changed plist format");
        PXC02AssertProjectedDictionary(parsed);

        // Rootless/preboot-style suffix is the same proven provenance contract.
        NSData *rootlessProjected = PXC02PathBoundRawRead(rootlessPath, encoded, projection);
        NSCAssert(rootlessProjected != encoded, @"C-02 rootless SystemVersion path did not transform");
        NSDictionary *rootlessParsed = PXC02ParseWithExactCFAPI(rootlessProjected, NULL, NULL);
        PXC02AssertProjectedDictionary(rootlessParsed);

        // Same key family in a generic app plist must remain untouched. A global
        // parser hook driven only by ProductVersion/build keys would fail this.
        NSData *generic = PXC02PathBoundRawRead(genericPath, encoded, projection);
        NSCAssert(generic == encoded, @"C-02 generic app plist was rewritten without provenance");
        NSDictionary *genericParsed = PXC02ParseWithExactCFAPI(generic, &parserError, NULL);
        NSCAssert(!parserError && [genericParsed[@"ProductVersion"] isEqual:@"16.0"],
                  @"C-02 generic same-key plist did not preserve original version");
        NSCAssert([genericParsed[@"ProductBuildVersion"] isEqual:@"20A362"],
                  @"C-02 generic same-key plist did not preserve original build");

        // Direct dictionary and upstream-data routes must converge on the same
        // canonical values; the parser itself contributes no spoof policy.
        NSDictionary *direct = PXTransformSystemVersionDictionary(source, projection);
        NSCAssert([direct[@"ProductVersion"] isEqual:parsed[@"ProductVersion"]],
                  @"C-02 dictionary/data routes diverged on ProductVersion");
        NSCAssert([direct[@"ProductBuildVersion"] isEqual:parsed[@"ProductBuildVersion"]],
                  @"C-02 dictionary/data routes diverged on ProductBuildVersion");
        NSCAssert([direct[@"ReleaseType"] isEqual:parsed[@"ReleaseType"]],
                  @"C-02 dictionary/data routes diverged on ReleaseType");
    }

    // Malformed SystemVersion bytes fail open at the upstream transformer. The
    // exact CF parser is then allowed to report its native error unchanged.
    NSData *malformed = [@"not a property list" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *malformedProjected = PXC02PathBoundRawRead(canonicalPath, malformed, projection);
    NSCAssert(malformedProjected == malformed, @"C-02 malformed data must fail open before parser");
    BOOL malformedError = NO;
    NSDictionary *malformedResult = PXC02ParseWithExactCFAPI(malformedProjected, &malformedError, NULL);
    NSCAssert(malformedResult == nil && malformedError,
              @"C-02 malformed exact-CF parse must preserve native failure behavior");

    // A lookalike filename outside the canonical component suffix is not valid
    // provenance and therefore must not arm the SystemVersion transformer.
    NSCAssert(!PXIsSystemVersionPlistPath(@"/tmp/SystemVersion.plist"),
              @"C-02 broad filename-only provenance unexpectedly accepted");

    NSLog(@"[C-02] CFPropertyList evidence: upstream path transform covers exact parser route; global parser hook not justified");
}
