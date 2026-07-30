#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// TIME-01 (Phase 11): opt-in device time-offset module.
//
// Disabled by default. When disabled, every accessor is an identity / no-op so the module
// can never shift the device clock unless a scoped app operator explicitly opts in. The
// master toggle is stored in com.weaponx.securitySettings (key "timeOffsetEnabled", default NO),
// mirroring the opt-in safety gating introduced for the Phase 4 lockdown research surfaces.

FOUNDATION_EXPORT NSString * const PXTimeOffsetEnabledKey;
FOUNDATION_EXPORT NSString * const PXTimeOffsetSecondsKey;

// Safety clamp: the maximum absolute offset (in seconds) the module will ever honor.
FOUNDATION_EXPORT const NSTimeInterval PXTimeOffsetMaxAbsoluteSeconds;

// YES only when the master toggle is explicitly enabled in the supplied settings dictionary.
FOUNDATION_EXPORT BOOL PXTimeOffsetEnabledInSettings(NSDictionary * _Nullable settings);

// Resolved offset in seconds. Fails closed to 0 when disabled, when settings are missing,
// or when the configured value is not a finite, in-range number. The result is clamped to
// +/- PXTimeOffsetMaxAbsoluteSeconds.
FOUNDATION_EXPORT NSTimeInterval PXResolvedTimeOffsetSeconds(NSDictionary * _Nullable settings);

// Applies the resolved offset to a base date. Returns the same date (identity) when the
// module is disabled or the resolved offset is zero.
FOUNDATION_EXPORT NSDate *PXApplyTimeOffsetToDate(NSDate *baseDate, NSDictionary * _Nullable settings);

NS_ASSUME_NONNULL_END
