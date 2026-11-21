// AppVersionHooks.h

#import <Foundation/Foundation.h>

// Master toggle is stored in com.weaponx.securitySettings.
BOOL PXAppVersionSpoofMasterEnabled(void);

// Returns YES if per-app spoofing is enabled and at least one of version/build is available.
// Only provides values for the passed bundleID; caller decides scope (main-bundle-only, etc.).
BOOL PXGetSpoofedAppVersionForBundle(NSString *bundleID, NSString **outVersion, NSString **outBuild);

// Revoke cached reads/projections and pending candidates. Borrowed CF dictionary
// results keep process-owned lifetime across invalidation; they are not evicted.
void PXAppVersionHooksInvalidateCache(void);
