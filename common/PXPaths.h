#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *PXMobileLibraryPath(void);
FOUNDATION_EXPORT NSString *PXPreferencesPath(void);
FOUNDATION_EXPORT NSString *PXWeaponXBasePath(void);
FOUNDATION_EXPORT NSString *PXProfilesPath(void);
FOUNDATION_EXPORT NSString *PXCurrentProfileInfoPath(void);
FOUNDATION_EXPORT NSString *PXLegacyActiveProfileInfoPath(void);
FOUNDATION_EXPORT NSString * _Nullable PXValidatedProfileID(id _Nullable value);
FOUNDATION_EXPORT NSString * _Nullable PXActiveProfileID(void);
FOUNDATION_EXPORT NSString * _Nullable PXProfileRootPath(NSString * _Nullable profileID);
FOUNDATION_EXPORT NSString * _Nullable PXProfileIdentityPath(NSString * _Nullable profileID);
FOUNDATION_EXPORT NSString * _Nullable PXProfileDeviceIDsPath(NSString * _Nullable profileID);
FOUNDATION_EXPORT NSString * _Nullable PXActiveProfileRootPath(void);
FOUNDATION_EXPORT NSString * _Nullable PXActiveProfileIdentityPath(void);
FOUNDATION_EXPORT NSString * _Nullable PXActiveProfileDeviceIDsPath(void);
FOUNDATION_EXPORT NSString *PXProjectXSettingsPath(void);
FOUNDATION_EXPORT NSString *PXGlobalScopePath(void);
FOUNDATION_EXPORT NSString *PXSecuritySettingsPath(void);
FOUNDATION_EXPORT void PXPostSettingsChangedNotification(void);
