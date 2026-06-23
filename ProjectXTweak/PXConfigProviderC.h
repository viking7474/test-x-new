// PXConfigProviderC.h
// C-wrapper for hooks to easily call without objective-C overhead where needed

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

NSString *PXGetSpoofedDeviceModel(void);
NSString *PXGetSpoofedBoardID(void);
NSString *PXGetSpoofedHwModel(void);
NSString *PXGetSpoofedDeviceName(void);
NSString *PXGetSpoofedIOSBuild(void);
NSString *PXGetSpoofedDarwin(void);
NSString *PXGetSpoofedKernelVersion(void);
NSDictionary *PXGetSpoofedSpecs(void);
NSString *PXGetSpoofedGPUFamily(void);
BOOL PXIsDeviceModelSpoofingEnabled(void);

NSString *PXGetSpoofedSystemBootUUID(void);
NSString *PXGetSpoofedDyldCacheUUID(void);
BOOL PXIsSystemBootUUIDSpoofingEnabled(void);
BOOL PXIsDyldCacheUUIDSpoofingEnabled(void);
NSString *PXGetSpoofedWiFiSSID(void);
NSString *PXGetSpoofedWiFiBSSID(void);
BOOL PXIsWiFiSpoofingEnabled(void);



#ifdef __cplusplus
}
#endif
