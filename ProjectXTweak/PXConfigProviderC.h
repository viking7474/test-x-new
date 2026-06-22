// PXConfigProviderC.h
// C-wrapper for hooks to easily call without objective-C overhead where needed

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

NSString *PXGetSpoofedDeviceModel(void);
NSString *PXGetSpoofedGPUFamily(void);
BOOL PXIsDeviceModelSpoofingEnabled(void);

NSString *PXGetSpoofedSystemBootUUID(void);
NSString *PXGetSpoofedDyldCacheUUID(void);
BOOL PXIsSystemBootUUIDSpoofingEnabled(void);
BOOL PXIsDyldCacheUUIDSpoofingEnabled(void);


#ifdef __cplusplus
}
#endif
