#import <Foundation/Foundation.h>
#include <locale.h>

NS_ASSUME_NONNULL_BEGIN

/// Convert an NSLocale-style identifier to a conservative POSIX locale candidate.
/// Returns nil for empty/malformed input.
FOUNDATION_EXPORT NSString * _Nullable PXCanonicalCLocaleName(NSString * _Nullable localeIdentifier);

/// Standard locale categories for which a canonical target-region locale can be
/// projected. Unknown/private categories fail open.
FOUNDATION_EXPORT BOOL PXSetlocaleCategorySupportsProjection(int category);

/// We only replace the environment-derived `setlocale(category, "")` form.
/// Query (`locale == NULL`) and explicit non-empty locale requests stay original.
FOUNDATION_EXPORT BOOL PXSetlocaleShouldUseCanonicalInput(int category,
                                                          const char * _Nullable locale);

/// Project NSBundle.preferredLocalizations from the same canonical target-region
/// inputs used by LocaleTimeZoneHooks. Prefer the first configured preferred
/// language; otherwise use the language component of the locale identifier.
/// Invalid/partial input fails open to the exact original array object.
FOUNDATION_EXPORT NSArray<NSString *> * _Nullable PXPreferredLocalizationsProjection(
    NSArray<NSString *> * _Nullable originalLocalizations,
    NSArray<NSString *> * _Nullable preferredLanguages,
    NSString * _Nullable localeIdentifier,
    BOOL projectionEnabled);

NS_ASSUME_NONNULL_END
