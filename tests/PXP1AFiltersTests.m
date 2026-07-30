#import <Foundation/Foundation.h>
#import "PXP1AFilters.h"

// P1-A — UserDefaults / DeviceModel / Pasteboard pure-helper tests.
//
// Exercises the shared decision logic that the three Logos hooks delegate to
// (common/PXP1AFilters.m). Pure Foundation, host-runnable. Returns the number
// of failed checks.

static int gPass = 0;
static int gFail = 0;

#define PXT_ASSERT(cond, desc) do { \
    if (cond) { gPass++; } \
    else { gFail++; fprintf(stderr, "  FAIL: %s\n", desc); } \
} while (0)

static void PXTTestDeviceModelFamily(void) {
    PXT_ASSERT([PXDeviceModelUIDeviceFamily(@"iPhone15,3", @"iPhone") isEqualToString:@"iPhone"],
               "iPhone machine id -> iPhone family");
    PXT_ASSERT([PXDeviceModelUIDeviceFamily(@"iPad13,1", @"iPad") isEqualToString:@"iPad"],
               "iPad machine id -> iPad family");
    PXT_ASSERT([PXDeviceModelUIDeviceFamily(@"iPod9,1", @"iPhone") isEqualToString:@"iPod touch"],
               "iPod machine id -> iPod touch family");
    PXT_ASSERT([PXDeviceModelUIDeviceFamily(@"Watch6,3", @"iPhone") isEqualToString:@"iPhone"],
               "unknown prefix -> original UIDevice value");
    PXT_ASSERT([PXDeviceModelUIDeviceFamily(nil, @"iPhone") isEqualToString:@"iPhone"],
               "nil spoof -> original");
    PXT_ASSERT([PXDeviceModelUIDeviceFamily(@"", @"iPad") isEqualToString:@"iPad"],
               "empty spoof -> original");
    NSString *family = PXDeviceModelUIDeviceFamily(@"iPhone15,3", @"iPhone");
    PXT_ASSERT(![family isEqualToString:@"iPhone15,3"], "family never equals the machine id");
}

static void PXTTestUUIDKey(void) {
    PXT_ASSERT(PXUserDefaultsIsUUIDKey(@"uuid"), "exact uuid");
    PXT_ASSERT(PXUserDefaultsIsUUIDKey(@"UDID"), "exact udid, case-insensitive");
    PXT_ASSERT(PXUserDefaultsIsUUIDKey(@"idfa"), "exact idfa");
    PXT_ASSERT(PXUserDefaultsIsUUIDKey(@"device_uuid"), "device_uuid pattern");
    PXT_ASSERT(PXUserDefaultsIsUUIDKey(@"vendor-id"), "vendor-id pattern");
    PXT_ASSERT(PXUserDefaultsIsUUIDKey(@"com.acme.uuid"), "suffix .uuid");
    PXT_ASSERT(PXUserDefaultsIsUUIDKey(@"session-udid"), "suffix -udid");
    PXT_ASSERT(PXUserDefaultsIsUUIDKey(@"my_idfa"), "suffix _idfa");
    // Generic terms intentionally excluded.
    PXT_ASSERT(!PXUserDefaultsIsUUIDKey(@"token"), "token excluded");
    PXT_ASSERT(!PXUserDefaultsIsUUIDKey(@"tracking"), "tracking excluded");
    PXT_ASSERT(!PXUserDefaultsIsUUIDKey(@"device"), "device excluded");
    PXT_ASSERT(!PXUserDefaultsIsUUIDKey(@"identifier"), "identifier excluded");
    PXT_ASSERT(!PXUserDefaultsIsUUIDKey(@"uuidvalue"), "prefix-only not matched");
    PXT_ASSERT(!PXUserDefaultsIsUUIDKey(@"username"), "unrelated key not matched");
    PXT_ASSERT(!PXUserDefaultsIsUUIDKey(nil), "nil key -> NO");
}

static void PXTTestLooksLikeUUID(void) {
    PXT_ASSERT(PXUserDefaultsLooksLikeUUIDString(@"12345678-1234-1234-1234-123456789abc"),
               "valid dashed uuid");
    PXT_ASSERT(PXUserDefaultsLooksLikeUUIDString(@"ABCDEF0123456789ABCDEF0123456789"),
               "valid 32 hex, uppercase");
    PXT_ASSERT(!PXUserDefaultsLooksLikeUUIDString(@"not-a-uuid"), "short string -> NO");
    PXT_ASSERT(!PXUserDefaultsLooksLikeUUIDString(@"12345678-1234-1234-1234-1234567890zz"),
               "36 chars, wrong charset -> NO");
    NSString *g32 = [@"" stringByPaddingToLength:32 withString:@"g" startingAtIndex:0];
    PXT_ASSERT(!PXUserDefaultsLooksLikeUUIDString(g32), "32 non-hex chars -> NO");
    PXT_ASSERT(!PXUserDefaultsLooksLikeUUIDString(nil), "nil -> NO");
}

static void PXTTestPasteboardName(void) {
    NSString *uuid = @"abcd1234-5678-90ab-cdef-1234567890ab";
    PXT_ASSERT([PXPasteboardDeterministicName(@"com.acme.pb", uuid) isEqualToString:@"com.acme.abcd1234"],
               "replaces last dotted component with short uuid");
    PXT_ASSERT([PXPasteboardDeterministicName(@"com.acme.pb", uuid)
                isEqualToString:PXPasteboardDeterministicName(@"com.acme.pb", uuid)],
               "deterministic for identical inputs");
    PXT_ASSERT([PXPasteboardDeterministicName(@"single", uuid) isEqualToString:@"abcd1234"],
               "single component replaced by short uuid");
    PXT_ASSERT([PXPasteboardDeterministicName(@"com.acme.pb", @"") isEqualToString:@"com.acme.pb"],
               "empty uuid -> original name");
    PXT_ASSERT(PXPasteboardDeterministicName(@"", uuid).length == 0, "empty name -> original (empty)");
}

static void PXTTestTypeEncoding(void) {
    PXT_ASSERT(PXPasteboardTypeEncodingCompatible("@:", "@:"), "exact encoding match");
    PXT_ASSERT(PXPasteboardTypeEncodingCompatible("@16@0:8", "@24@0:8@16"), "same return type char");
    PXT_ASSERT(!PXPasteboardTypeEncodingCompatible("v16@0:8", "@16@0:8"), "different return type -> NO");
    PXT_ASSERT(!PXPasteboardTypeEncodingCompatible(NULL, "@:"), "NULL existing -> NO");
    PXT_ASSERT(!PXPasteboardTypeEncodingCompatible("@:", NULL), "NULL expected -> NO");
}

int PXRunP1AFiltersTests(void) {
    gPass = 0;
    gFail = 0;
    fprintf(stderr, "[P1-A] UserDefaults/DeviceModel/Pasteboard helper tests\n");
    PXTTestDeviceModelFamily();
    PXTTestUUIDKey();
    PXTTestLooksLikeUUID();
    PXTTestPasteboardName();
    PXTTestTypeEncoding();
    fprintf(stderr, "[P1-A] helpers: %d passed, %d failed\n", gPass, gFail);
    return gFail;
}
