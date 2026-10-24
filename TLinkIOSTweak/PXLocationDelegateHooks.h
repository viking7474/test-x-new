#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Process-lifetime functions, not capturing blocks. The provider must evaluate
// the live scope/toggle and return nil when projection is inactive.
typedef id _Nullable (*PXLocationDelegateSnapshotProvider)(BOOL advanceGeneration);
typedef void (*PXLocationDelegateSnapshotAttacher)(id _Nullable object, id snapshot);

// Call before the native manager setter so synchronous callbacks and capability
// caching see the same selector surface. No optional methods are fabricated.
// The first provider/attacher installed for a class/selector remains its policy.
// Returns the number of supported, ABI-compatible selectors observed.
FOUNDATION_EXPORT NSUInteger PXInstallLocationDelegateHooks(
    id _Nullable delegate,
    PXLocationDelegateSnapshotProvider provider,
    PXLocationDelegateSnapshotAttacher attacher);

NS_ASSUME_NONNULL_END
