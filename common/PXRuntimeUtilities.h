#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Thread-safe process-lifetime log-once registry.
/// Returns YES exactly once per namespace/key pair until that namespace resets.
/// Input strings are detached. Same-thread recursive preparation declines a claim;
/// invalid inputs return NO. Foreign input exceptions propagate after cleanup.
FOUNDATION_EXPORT BOOL PXLogOnceClaim(NSString *namespaceName, NSString *key);

/// Clears all claimed keys in one namespace. Intended for explicit lifecycle cleanup/tests.
FOUNDATION_EXPORT void PXLogOnceResetNamespace(NSString *namespaceName);

NS_ASSUME_NONNULL_END
