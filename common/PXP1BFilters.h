// PXP1BFilters.h
// Pure, host-testable helpers for P1-B (hostname / app version / ATT).
// No global state, no I/O, no Objective-C runtime hooking. This keeps the
// exact algorithms used by the live hooks unit-testable with no drift.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

// --- App Version ---

/// Return an immutable copy of `original` with CFBundleShortVersionString /
/// CFBundleVersion overwritten when the matching argument is non-empty.
/// Never mutates `original` in place. Returns `original` unchanged when it is
/// not a dictionary or when a mutable copy cannot be made.
NSDictionary *PXAppVersionApplyToInfoDictionary(NSDictionary *original,
                                                NSString *_Nullable version,
                                                NSString *_Nullable build);

/// Map a bundle identifier to the profile per-app version plist filename, e.g.
/// `com.foo.bar` -> `com_foo_bar_version.plist`. Returns nil for empty input.
NSString *_Nullable PXAppVersionSafeBundleFilename(NSString *_Nullable bundleID);

// --- gethostname ---

/// Bounded, NUL-terminating copy of `value` into a caller buffer, matching the
/// gethostname provider contract:
///  - returns NO (leave buffer untouched) when name/value is NULL, namelen == 0,
///    or value is the empty string;
///  - otherwise copies min(strlen(value), namelen-1) bytes and always writes a
///    trailing NUL, returning YES.
BOOL PXGethostnameWriteValue(char *_Nullable name, size_t namelen, const char *_Nullable value);

// --- ATT ---

/// Zero IDFA returned when ATT status is not authorized.
extern NSString * const PXATTZeroIDFAUUIDString;

/// Clamp any integer to the valid ATT authorization range 0...3.
NSInteger PXATTClampStatus(NSInteger status);

/// YES only when the (already clamped) status is authorized (== 3).
/// Drives: legacy isAdvertisingTrackingEnabled and real-vs-zero IDFA selection.
BOOL PXATTStatusIsAuthorized(NSInteger status);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
