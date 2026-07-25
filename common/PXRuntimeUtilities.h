#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Thread-safe process-lifetime log-once registry.
/// Returns YES exactly once for each namespace/key pair.
FOUNDATION_EXPORT BOOL PXLogOnceClaim(NSString *namespaceName, NSString *key);

/// Clears all claimed keys in one namespace. Intended for explicit lifecycle cleanup/tests.
FOUNDATION_EXPORT void PXLogOnceResetNamespace(NSString *namespaceName);

NS_ASSUME_NONNULL_END
