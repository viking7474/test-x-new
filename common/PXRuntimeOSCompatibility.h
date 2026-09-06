#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Reads the physical runtime's ProductVersion/ProductBuildVersion without using
/// Foundation file convenience APIs that may themselves be hooked by WeaponX.
FOUNDATION_EXPORT NSDictionary<NSString *, NSString *> * _Nullable PXRealRuntimeOSInfo(void);
FOUNDATION_EXPORT NSString * _Nullable PXRealRuntimeIOSVersion(void);
FOUNDATION_EXPORT NSString * _Nullable PXRealRuntimeIOSBuild(void);
FOUNDATION_EXPORT BOOL PXRealRuntimeIOSVersionIsAtLeast(NSString *minimumVersion);

/// Returns YES only when the configured/profile iOS version is strictly newer
/// than the physical runtime. Unknown/malformed versions fail closed as NO here.
FOUNDATION_EXPORT BOOL PXConfiguredIOSVersionExceedsRealRuntime(NSString * _Nullable configuredVersion);

/// Legacy per-app compatibility override. When enabled and bundleID is selected in
/// fixVersionApps, only kern.osproductversion is allowed to fall through to the
/// physical runtime. Other configured OS/profile reporting surfaces stay spoofed.
FOUNDATION_EXPORT BOOL PXFixVersionAppliesToBundle(NSString * _Nullable bundleID);

/// Reporting projection used by UIDevice/NSProcessInfo/SystemVersion/MG/MC/private
/// ProductVersion surfaces. Always preserves the configured profile. Legacy Fix
/// Version is intentionally handled only at kern.osproductversion in Tweak.x.
FOUNDATION_EXPORT BOOL PXReportingIOSVersionBuildForBundle(NSString * _Nullable configuredVersion,
                                                            NSString * _Nullable configuredBuild,
                                                            NSString * _Nullable bundleID,
                                                            NSString * _Nullable * _Nullable outVersion,
                                                            NSString * _Nullable * _Nullable outBuild);

/// Convenience for canonical profile keys IOSVersion / IOSBuild using the same
/// per-app reporting policy. Other keys are returned unchanged.
FOUNDATION_EXPORT NSString * _Nullable PXReportingIOSValueForDeviceIDKey(NSString *key,
                                                                         NSDictionary *deviceIDs,
                                                                         NSString * _Nullable bundleID);

/// Produces the version/build pair used by physical/native compatibility policy.
/// Lower/equal spoofing is preserved; upward spoofing is clamped to the real
/// runtime pair. This is for kernel/runtime safety, not general reporting.
FOUNDATION_EXPORT BOOL PXNativeSafeIOSVersionBuild(NSString * _Nullable configuredVersion,
                                                    NSString * _Nullable configuredBuild,
                                                    NSString * _Nullable * _Nullable outVersion,
                                                    NSString * _Nullable * _Nullable outBuild);

/// YES only when the configured version/build pair may be exposed on Darwin/kernel
/// implementation surfaces. Upward profiles fail closed to the real runtime.
FOUNDATION_EXPORT BOOL PXNativeIOSProfileMayExposeKernelTuple(NSString * _Nullable configuredVersion,
                                                               NSString * _Nullable configuredBuild);

/// Default legacy kernel-reporting policy. Fix Version does not alter Darwin/kernel
/// profile values; selected apps only bypass kern.osproductversion. This helper
/// therefore accepts any well-formed configured version/build pair.
FOUNDATION_EXPORT BOOL PXKernelIOSProfileMayExposeTupleForBundle(NSString * _Nullable configuredVersion,
                                                                 NSString * _Nullable configuredBuild,
                                                                 NSString * _Nullable bundleID);

NS_ASSUME_NONNULL_END
