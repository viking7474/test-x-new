#import "PXTimeOffset.h"
#import <math.h>

NSString * const PXTimeOffsetEnabledKey = @"timeOffsetEnabled";
NSString * const PXTimeOffsetSecondsKey = @"timeOffsetSeconds";

// +/- 24h. Keeps the opt-in offset within a bounded, reviewable range.
const NSTimeInterval PXTimeOffsetMaxAbsoluteSeconds = 86400.0;

static BOOL PXTimeOffsetTruthy(id value) {
    return [value respondsToSelector:@selector(boolValue)] && [value boolValue];
}

BOOL PXTimeOffsetEnabledInSettings(NSDictionary *settings) {
    if (![settings isKindOfClass:[NSDictionary class]]) return NO;
    // Default OFF: absence of the key, or a falsey value, keeps the module disabled.
    return PXTimeOffsetTruthy(settings[PXTimeOffsetEnabledKey]);
}

NSTimeInterval PXResolvedTimeOffsetSeconds(NSDictionary *settings) {
    // Fail closed: any ambiguity yields a zero offset.
    if (!PXTimeOffsetEnabledInSettings(settings)) return 0.0;
    id raw = settings[PXTimeOffsetSecondsKey];
    if (![raw isKindOfClass:[NSNumber class]]) return 0.0;
    double seconds = [(NSNumber *)raw doubleValue];
    if (!isfinite(seconds)) return 0.0;
    if (seconds > PXTimeOffsetMaxAbsoluteSeconds) seconds = PXTimeOffsetMaxAbsoluteSeconds;
    if (seconds < -PXTimeOffsetMaxAbsoluteSeconds) seconds = -PXTimeOffsetMaxAbsoluteSeconds;
    return seconds;
}

NSDate *PXApplyTimeOffsetToDate(NSDate *baseDate, NSDictionary *settings) {
    if (![baseDate isKindOfClass:[NSDate class]]) return baseDate;
    NSTimeInterval offset = PXResolvedTimeOffsetSeconds(settings);
    if (offset == 0.0) return baseDate;
    return [baseDate dateByAddingTimeInterval:offset];
}
