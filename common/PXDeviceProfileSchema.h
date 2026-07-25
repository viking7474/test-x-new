#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const PXDeviceSpecWebGLInfoKey;
FOUNDATION_EXPORT NSString *const PXWebGLVendorKey;
FOUNDATION_EXPORT NSString *const PXWebGLRendererKey;
FOUNDATION_EXPORT NSString *const PXWebGLVersionKey;
FOUNDATION_EXPORT NSString *const PXWebGLUnmaskedVendorKey;
FOUNDATION_EXPORT NSString *const PXWebGLUnmaskedRendererKey;
FOUNDATION_EXPORT NSString *const PXWebGLMaxTextureSizeKey;
FOUNDATION_EXPORT NSString *const PXWebGLMaxRenderbufferSizeKey;

FOUNDATION_EXPORT BOOL PXProfileValueIsMissing(id _Nullable value);
FOUNDATION_EXPORT NSString * _Nullable PXProfileString(id _Nullable value);
FOUNDATION_EXPORT NSNumber * _Nullable PXProfilePositiveNumber(id _Nullable value);

/// Normalize WebGL input from either model specs, runtime specs, or device_ids.plist.
/// Missing/"Unknown" values are omitted. Legacy maxRenderBuffer spellings are read
/// for migration but the returned dictionary always uses maxRenderbufferSize.
FOUNDATION_EXPORT NSDictionary *PXCanonicalWebGLInfo(id _Nullable source);
FOUNDATION_EXPORT NSDictionary *PXWebGLInfoFromModelSpec(NSDictionary * _Nullable modelSpec);
FOUNDATION_EXPORT NSDictionary *PXWebGLInfoFromDeviceIDs(NSDictionary * _Nullable deviceIDs);

/// Remove all managed WebGL fields, including legacy spellings, then write only
/// canonical fields that are actually present.
FOUNDATION_EXPORT void PXWriteWebGLInfoToDeviceIDs(NSMutableDictionary *deviceIDs,
                                                   NSDictionary * _Nullable webGLInfo);

/// Canonical runtime schema shared by IdentifierManager, DeviceModelManager and
/// DeviceSpecHooks. Unknown strings are omitted and HwModel never falls back to BoardID.
FOUNDATION_EXPORT NSDictionary * _Nullable PXDeviceSpecificationsFromDeviceIDs(NSDictionary * _Nullable deviceIDs);
FOUNDATION_EXPORT NSDictionary * _Nullable PXCanonicalDeviceSpecifications(NSDictionary * _Nullable specs,
                                                                            NSString * _Nullable modelIdentifier);

NS_ASSUME_NONNULL_END
