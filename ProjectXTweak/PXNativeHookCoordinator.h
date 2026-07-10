// PXNativeHookCoordinator.h
// Single owner of MSHookFunction for symbols that multiple modules previously hooked.

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import <sys/mount.h>
#import <sys/param.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <IOKit/IOKitLib.h>

NS_ASSUME_NONNULL_BEGIN

// Priority bands (lower runs first in pre; lower runs first in post after original).
typedef NS_ENUM(NSInteger, PXNativeHookPriority) {
    PXNativeHookPriorityScopeABI = 100,
    PXNativeHookPriorityIdentity = 200,       // model / iOS / SystemBoot / BootTime
    PXNativeHookPriorityNetworkStorage = 300, // network / storage transforms
    PXNativeHookPriorityJailbreakSanitize = 400,
};

// Pre-handler: return YES if fully handled (skip original + post). Set *outResult when YES.
// Post-handler: mutates result/buffers after original returns.

// --- sysctl ---
typedef BOOL (^PXSysctlPreBlock)(int *name, u_int namelen, void * _Nullable oldp, size_t * _Nullable oldlenp, void * _Nullable newp, size_t newlen, int *outResult);
typedef void (^PXSysctlPostBlock)(int *name, u_int namelen, void * _Nullable oldp, size_t * _Nullable oldlenp, void * _Nullable newp, size_t newlen, int *inoutResult);

// --- sysctlbyname ---
typedef BOOL (^PXSysctlBynamePreBlock)(const char *name, void * _Nullable oldp, size_t * _Nullable oldlenp, void * _Nullable newp, size_t newlen, int *outResult);
typedef void (^PXSysctlBynamePostBlock)(const char *name, void * _Nullable oldp, size_t * _Nullable oldlenp, void * _Nullable newp, size_t newlen, int *inoutResult);

// --- gethostname ---
typedef BOOL (^PXGethostnamePreBlock)(char * _Nullable name, size_t namelen, int *outResult);
typedef void (^PXGethostnamePostBlock)(char * _Nullable name, size_t namelen, int *inoutResult);

// --- getifaddrs ---
typedef BOOL (^PXGetifaddrsPreBlock)(struct ifaddrs **ifap, int *outResult);
typedef void (^PXGetifaddrsPostBlock)(struct ifaddrs **ifap, int *inoutResult);

// --- IOKit property ---
typedef BOOL (^PXIORegCreateCFPropertyPreBlock)(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options, CFTypeRef *outResult);
typedef void (^PXIORegCreateCFPropertyPostBlock)(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options, CFTypeRef *inoutResult);

typedef BOOL (^PXIORegCreateCFPropertiesPreBlock)(io_registry_entry_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, IOOptionBits options, IOReturn *outResult);
typedef void (^PXIORegCreateCFPropertiesPostBlock)(io_registry_entry_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, IOOptionBits options, IOReturn *inoutResult);

typedef BOOL (^PXIORegSearchCFPropertyPreBlock)(io_registry_entry_t entry, const io_name_t plane, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options, CFTypeRef *outResult);
typedef void (^PXIORegSearchCFPropertyPostBlock)(io_registry_entry_t entry, const io_name_t plane, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options, CFTypeRef *inoutResult);

// --- CFCopySystemVersionDictionary ---
typedef BOOL (^PXCFCopySystemVersionDictPreBlock)(CFDictionaryRef *outResult);
typedef void (^PXCFCopySystemVersionDictPostBlock)(CFDictionaryRef *inoutResult);

// --- statfs family ---
typedef void (^PXStatfsPostBlock)(const char * _Nullable path, struct statfs *buf, int *inoutResult);
typedef void (^PXStatfs64PostBlock)(const char * _Nullable path, struct statfs64 *buf, int *inoutResult);
typedef void (^PXGetfsstatPostBlock)(struct statfs * _Nullable buf, int bufsize, int flags, int *inoutResult);
typedef void (^PXGetfsstat64PostBlock)(struct statfs64 * _Nullable buf, int bufsize, int flags, int *inoutResult);

// --- CNCopyCurrentNetworkInfo ---
typedef BOOL (^PXCNCopyNetworkInfoPreBlock)(CFStringRef interfaceName, CFDictionaryRef *outResult);
typedef void (^PXCNCopyNetworkInfoPostBlock)(CFStringRef interfaceName, CFDictionaryRef *inoutResult);

// --- gethostuuid ---
typedef BOOL (^PXGethostuuidPreBlock)(uuid_t uuid, const struct timespec * _Nullable wait, int *outResult);

@interface PXNativeHookCoordinator : NSObject

+ (instancetype)sharedCoordinator;

/// Register a provider. Returns NO if providerID already registered for that symbol.
- (BOOL)registerProviderID:(NSString *)providerID
                symbolName:(NSString *)symbolName
                  priority:(NSInteger)priority
                  preBlock:(id _Nullable)preBlock
                 postBlock:(id _Nullable)postBlock;

/// Install MSHookFunction once per owned symbol. Safe to call multiple times.
- (void)installOwnedSymbolsIfNeeded;

/// Whether a given symbol has been installed by the coordinator.
- (BOOL)isSymbolInstalled:(NSString *)symbolName;

/// Original function pointer after install (NULL if not installed).
- (void * _Nullable)originalForSymbol:(NSString *)symbolName;

/// Diagnostics snapshot for logging.
- (NSDictionary *)diagnostics;

// Convenience typed registrars (providerID must be unique globally).
- (BOOL)registerSysctlProvider:(NSString *)providerID priority:(NSInteger)priority pre:(PXSysctlPreBlock _Nullable)pre post:(PXSysctlPostBlock _Nullable)post;
- (BOOL)registerSysctlBynameProvider:(NSString *)providerID priority:(NSInteger)priority pre:(PXSysctlBynamePreBlock _Nullable)pre post:(PXSysctlBynamePostBlock _Nullable)post;
- (BOOL)registerGethostnameProvider:(NSString *)providerID priority:(NSInteger)priority pre:(PXGethostnamePreBlock _Nullable)pre post:(PXGethostnamePostBlock _Nullable)post;
- (BOOL)registerGetifaddrsProvider:(NSString *)providerID priority:(NSInteger)priority pre:(PXGetifaddrsPreBlock _Nullable)pre post:(PXGetifaddrsPostBlock _Nullable)post;
- (BOOL)registerIORegistryCreateCFPropertyProvider:(NSString *)providerID priority:(NSInteger)priority pre:(PXIORegCreateCFPropertyPreBlock _Nullable)pre post:(PXIORegCreateCFPropertyPostBlock _Nullable)post;
- (BOOL)registerIORegistryCreateCFPropertiesProvider:(NSString *)providerID priority:(NSInteger)priority pre:(PXIORegCreateCFPropertiesPreBlock _Nullable)pre post:(PXIORegCreateCFPropertiesPostBlock _Nullable)post;
- (BOOL)registerIORegistrySearchCFPropertyProvider:(NSString *)providerID priority:(NSInteger)priority pre:(PXIORegSearchCFPropertyPreBlock _Nullable)pre post:(PXIORegSearchCFPropertyPostBlock _Nullable)post;
- (BOOL)registerCFCopySystemVersionDictionaryProvider:(NSString *)providerID priority:(NSInteger)priority pre:(PXCFCopySystemVersionDictPreBlock _Nullable)pre post:(PXCFCopySystemVersionDictPostBlock _Nullable)post;
- (BOOL)registerStatfsProvider:(NSString *)providerID priority:(NSInteger)priority post:(PXStatfsPostBlock)post;
- (BOOL)registerStatfs64Provider:(NSString *)providerID priority:(NSInteger)priority post:(PXStatfs64PostBlock)post;
- (BOOL)registerGetfsstatProvider:(NSString *)providerID priority:(NSInteger)priority post:(PXGetfsstatPostBlock)post;
- (BOOL)registerGetfsstat64Provider:(NSString *)providerID priority:(NSInteger)priority post:(PXGetfsstat64PostBlock)post;
- (BOOL)registerCNCopyCurrentNetworkInfoProvider:(NSString *)providerID priority:(NSInteger)priority pre:(PXCNCopyNetworkInfoPreBlock _Nullable)pre post:(PXCNCopyNetworkInfoPostBlock _Nullable)post;
- (BOOL)registerGethostuuidProvider:(NSString *)providerID priority:(NSInteger)priority pre:(PXGethostuuidPreBlock)pre;

@end

// Symbol name constants
FOUNDATION_EXPORT NSString * const kPXNativeSymbolSysctl;
FOUNDATION_EXPORT NSString * const kPXNativeSymbolSysctlByname;
FOUNDATION_EXPORT NSString * const kPXNativeSymbolGethostname;
FOUNDATION_EXPORT NSString * const kPXNativeSymbolGetifaddrs;
FOUNDATION_EXPORT NSString * const kPXNativeSymbolIORegistryEntryCreateCFProperty;
FOUNDATION_EXPORT NSString * const kPXNativeSymbolIORegistryEntryCreateCFProperties;
FOUNDATION_EXPORT NSString * const kPXNativeSymbolIORegistryEntrySearchCFProperty;
FOUNDATION_EXPORT NSString * const kPXNativeSymbolCFCopySystemVersionDictionary;
FOUNDATION_EXPORT NSString * const kPXNativeSymbolStatfs;
FOUNDATION_EXPORT NSString * const kPXNativeSymbolStatfs64;
FOUNDATION_EXPORT NSString * const kPXNativeSymbolGetfsstat;
FOUNDATION_EXPORT NSString * const kPXNativeSymbolGetfsstat64;
FOUNDATION_EXPORT NSString * const kPXNativeSymbolCNCopyCurrentNetworkInfo;
FOUNDATION_EXPORT NSString * const kPXNativeSymbolGethostuuid;

NS_ASSUME_NONNULL_END
