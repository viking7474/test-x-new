#import <Foundation/Foundation.h>
#import "PXLockdownResearchSafety.h"

void PXRunLockdownResearchSafetyTests(void) {
    NSDate *t0 = [NSDate dateWithTimeIntervalSince1970:1000];

    PXLockdownResearchPolicy *defaultPolicy = [PXLockdownResearchPolicy policyFromSettings:@{}];
    NSCAssert(!defaultPolicy.masterEnabled, @"master must default OFF");
    PXLockdownResearchRuntime *defaultRuntime = [[PXLockdownResearchRuntime alloc] initWithPolicy:defaultPolicy];
    NSCAssert(![defaultRuntime activateAt:t0], @"default policy must not arm");

    NSDictionary *settings = @{
        @"lockdownResearchEnabled": @YES,
        @"lockdownResearchMode": @"profile-backed",
        @"lockdownResearchBundleAllowlist": @[@"com.example.fixture", @"*", @" padded "],
        @"lockdownResearchProcessAllowlist": @[@"Fixture"],
        @"lockdownResearchSessionSeconds": @900,
    };
    PXLockdownResearchPolicy *policy = [PXLockdownResearchPolicy policyFromSettings:settings];
    NSCAssert([policy.bundleAllowlist isEqualToSet:[NSSet setWithObject:@"com.example.fixture"]], @"allowlist must be exact");
    PXLockdownResearchRuntime *runtime = [[PXLockdownResearchRuntime alloc] initWithPolicy:policy];
    NSCAssert([runtime activateAt:t0], @"valid internal session did not arm");

    PXLockdownSafetyDecision *outside = [runtime decisionForBundleID:@"com.example.other" processName:@"Fixture" now:t0];
    NSCAssert(!outside.allowed && outside.reason == PXLockdownSafetyReasonNotAllowlisted, @"outside allowlist must fail closed");
    NSCAssert([PXLockdownOriginalOrReplacement(@"original", @"candidate", [NSString class], outside, YES) isEqual:@"original"],
              @"outside allowlist changed original");

    PXLockdownSafetyDecision *deniedDaemon = [runtime decisionForBundleID:@"com.example.fixture" processName:@"lockdownd" now:t0];
    NSCAssert(!deniedDaemon.allowed && deniedDaemon.reason == PXLockdownSafetyReasonProcessDenied,
              @"sensitive daemon must stay denied even when bundle is allowlisted");

    PXLockdownSafetyDecision *allowed = [runtime decisionForBundleID:@"com.example.fixture" processName:@"Fixture" now:t0];
    NSCAssert(allowed.allowed, @"allowlisted internal fixture denied");
    NSCAssert([PXLockdownOriginalOrReplacement(@"original", @"candidate", [NSString class], allowed, YES) isEqual:@"candidate"],
              @"profile-backed replacement failed");
    NSCAssert([PXLockdownOriginalOrReplacement(@"original", @42, [NSString class], allowed, YES) isEqual:@"original"],
              @"type mismatch did not return original");
    NSCAssert([PXLockdownOriginalOrReplacement(@"original", @"candidate", [NSString class], allowed, NO) isEqual:@"original"],
              @"validation failure did not return original");

    NSDictionary *event = PXLockdownRedactedAuditEvent(allowed, @"kLockdownUniqueDeviceIDKey", @"SECRET-UDID-1234");
    NSCAssert([event[@"value"] isEqual:@"<redacted>"], @"audit value not redacted");
    NSCAssert(![[event description] containsString:@"SECRET-UDID-1234"], @"audit leaked identifier");

    NSDate *expiredAt = [t0 dateByAddingTimeInterval:901];
    PXLockdownSafetyDecision *expired = [runtime decisionForBundleID:@"com.example.fixture" processName:@"Fixture" now:expiredAt];
    NSCAssert(!expired.allowed && expired.reason == PXLockdownSafetyReasonSessionExpired, @"TTL did not expire closed");

    NSCAssert([runtime activateAt:t0], @"session re-arm failed");
    [runtime disableAllAndClearSnapshot];
    PXLockdownSafetyDecision *killed = [runtime decisionForBundleID:@"com.example.fixture" processName:@"Fixture" now:t0];
    NSCAssert(!killed.allowed && killed.reason == PXLockdownSafetyReasonKillSwitch, @"kill switch did not fail closed");
    NSCAssert(![runtime activateAt:t0], @"kill switch must remain sticky for process lifetime");

    PXLockdownResearchPolicy *observePolicy = [PXLockdownResearchPolicy policyFromSettings:@{
        @"lockdownResearchEnabled": @YES,
        @"lockdownResearchBundleAllowlist": @[@"com.example.fixture"],
    }];
    PXLockdownResearchRuntime *observeRuntime = [[PXLockdownResearchRuntime alloc] initWithPolicy:observePolicy];
    NSCAssert([observeRuntime activateAt:t0], @"observe session did not arm");
    PXLockdownSafetyDecision *observe = [observeRuntime decisionForBundleID:@"com.example.fixture" processName:@"Fixture" now:t0];
    NSCAssert([PXLockdownOriginalOrReplacement(@"original", @"candidate", [NSString class], observe, YES) isEqual:@"original"],
              @"observe-only changed original");

    NSLog(@"[LOCK-07/08/09] Lockdown safety foundation PASS");
}
