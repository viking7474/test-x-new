#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#include <stdarg.h>
#include <stdio.h>
#import "../TLinkIOSTweak/PXNativeHookCoordinator.m"

// Real coordinator source is compiled in this TU; only installation/logging and
// snapshot acquisition are facades. Real lexical scope cleanup is linked.
static NSUInteger checks, failures, nativeCalls, beginCalls;
static BOOL nativeThrows, logReenters;
static NSMutableArray<NSString *> *events;
static PXNativeHookCoordinator *fixtureCoordinator;
#define CHECK(value, label) do { checks++; if (!(value)) { failures++; fprintf(stderr,"FAIL: %s\n",label); } } while (0)
static void Raise(void) { [NSException raise:@"fixture" format:@"fault"]; }
void MSHookFunction(void *symbol, void *replace, void **result) { (void)symbol; (void)replace; if (result) *result = NULL; }
void PXLog(NSString *format, ...) {
    @try { (void)format; if (logReenters) (void)[fixtureCoordinator diagnostics]; }
    @finally { format = nil; }
}
void PXBeginRuntimeSnapshotOperation(PXRuntimeReadScope *scope) { beginCalls++; PXRuntimeReadScopeBegin(scope, (id)nil); }
static id FixtureShared(id object, SEL selector) { (void)object; (void)selector; return fixtureCoordinator; }
static void Native(void) { nativeCalls++; [events addObject:@"native"]; if (nativeThrows) Raise(); }
static CFDictionaryRef Answer(void) { return CFDictionaryCreate(NULL,NULL,NULL,0,&kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks); }
static void Fresh(void) {
    fixtureCoordinator = [PXNativeHookCoordinator new]; events = [NSMutableArray array];
    nativeCalls = beginCalls = 0; nativeThrows = NO; logReenters = YES;
}
static int Native_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) { (void)name; (void)namelen; (void)oldp; (void)oldlenp; (void)newp; (void)newlen; Native(); return 41; }
static int Native_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) { (void)name; (void)oldp; (void)oldlenp; (void)newp; (void)newlen; Native(); return 41; }
static int Native_sysctlnametomib(const char *name, int *mib, size_t *namelen) { (void)name; (void)mib; (void)namelen; Native(); return 41; }
static int Native_gethostname(char *name, size_t namelen) { (void)name; (void)namelen; Native(); return 41; }
static int Native_getifaddrs(struct ifaddrs **ifap) { (void)ifap; Native(); return 41; }
static CFTypeRef Native_IORegistryEntryCreateCFProperty(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options) { (void)entry; (void)key; (void)allocator; (void)options; Native(); return Answer(); }
static IOReturn Native_IORegistryEntryCreateCFProperties(io_registry_entry_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, IOOptionBits options) { (void)entry; (void)properties; (void)allocator; (void)options; Native(); if (properties) *properties = CFDictionaryCreateMutable(NULL,0,&kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks); return 41; }
static CFTypeRef Native_IORegistryEntrySearchCFProperty(io_registry_entry_t entry, const io_name_t plane, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options) { (void)entry; (void)plane; (void)key; (void)allocator; (void)options; Native(); return Answer(); }
static CFDictionaryRef Native_CFCopySystemVersionDictionary(void) {  Native(); return Answer(); }
static int Native_statfs(const char *path, struct statfs *buf) { (void)path; (void)buf; Native(); return 41; }
static int Native_statfs64(const char *path, PXStatfs64Buf *buf) { (void)path; (void)buf; Native(); return 41; }
static int Native_getfsstat(struct statfs *buf, int bufsize, int flags) { (void)buf; (void)bufsize; (void)flags; Native(); return 41; }
static int Native_getfsstat64(PXStatfs64Buf *buf, int bufsize, int flags) { (void)buf; (void)bufsize; (void)flags; Native(); return 41; }
static CFDictionaryRef Native_CNCopyCurrentNetworkInfo(CFStringRef interfaceName) { (void)interfaceName; Native(); return Answer(); }
static int Native_gethostuuid(uuid_t id, const struct timespec *wait) { (void)id; (void)wait; Native(); return 41; }
static void Originals(void) {
    g_orig_sysctl = Native_sysctl;
    g_orig_sysctlbyname = Native_sysctlbyname;
    g_orig_sysctlnametomib = Native_sysctlnametomib;
    g_orig_gethostname = Native_gethostname;
    g_orig_getifaddrs = Native_getifaddrs;
    g_orig_IORegistryEntryCreateCFProperty = Native_IORegistryEntryCreateCFProperty;
    g_orig_IORegistryEntryCreateCFProperties = Native_IORegistryEntryCreateCFProperties;
    g_orig_IORegistryEntrySearchCFProperty = Native_IORegistryEntrySearchCFProperty;
    g_orig_CFCopySystemVersionDictionary = Native_CFCopySystemVersionDictionary;
    g_orig_statfs = Native_statfs;
    g_orig_statfs64 = Native_statfs64;
    g_orig_getfsstat = Native_getfsstat;
    g_orig_getfsstat64 = Native_getfsstat64;
    g_orig_CNCopyCurrentNetworkInfo = Native_CNCopyCurrentNetworkInfo;
    g_orig_gethostuuid = Native_gethostuuid;
}
static void DispatchMatrix(void) {
    @autoreleasepool { Fresh(); Originals();
        CHECK(([fixtureCoordinator registerProviderID:@"matrix" symbolName:kPXNativeSymbolSysctl priority:10 preBlock:^BOOL(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen, int *result) { (void)name; (void)namelen; (void)oldp; (void)oldlenp; (void)newp; (void)newlen; (void)result; [events addObject:@"pre"]; return NO; } postBlock:^(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen, int *result) { (void)name; (void)namelen; (void)oldp; (void)oldlenp; (void)newp; (void)newlen; (void)result; [events addObject:@"post"]; }]), "sysctl typed registration");
        int value = PXCoord_sysctl(NULL,0,NULL,NULL,NULL,0);
        CHECK((nativeCalls == 1 && [events isEqualToArray:@[@"pre",@"native",@"post"]]), "sysctl pre/native/post ordering");
        CHECK((value == 41), "sysctl original result preserved");
        CHECK(([fixtureCoordinator registerProviderID:@"first" symbolName:kPXNativeSymbolSysctl priority:0 preBlock:^BOOL(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen, int *result) { (void)name; (void)namelen; (void)oldp; (void)oldlenp; (void)newp; (void)newlen; *result = 700; [events addObject:@"handled"]; return YES; } postBlock:nil]), "sysctl terminal registration");
        [events removeAllObjects]; nativeCalls = 0;
        value = PXCoord_sysctl(NULL,0,NULL,NULL,NULL,0);
        CHECK((nativeCalls == 0 && [events isEqualToArray:@[@"handled"]]), "sysctl terminal handling and sanitizer exception");
        CHECK((value == 700), "sysctl handled result preserved");
        Fresh(); g_orig_sysctl = NULL; value = PXCoord_sysctl(NULL,0,NULL,NULL,NULL,0);
        CHECK((value == -1 && nativeCalls == 0), "sysctl absent original fallback");
    }
    @autoreleasepool { Fresh(); Originals();
        CHECK(([fixtureCoordinator registerProviderID:@"matrix" symbolName:kPXNativeSymbolSysctlByname priority:10 preBlock:^BOOL(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen, int *result) { (void)name; (void)oldp; (void)oldlenp; (void)newp; (void)newlen; (void)result; [events addObject:@"pre"]; return NO; } postBlock:^(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen, int *result) { (void)name; (void)oldp; (void)oldlenp; (void)newp; (void)newlen; (void)result; [events addObject:@"post"]; }]), "sysctlbyname typed registration");
        int value = PXCoord_sysctlbyname("fixture",NULL,NULL,NULL,0);
        CHECK((nativeCalls == 1 && [events isEqualToArray:@[@"pre",@"native",@"post"]]), "sysctlbyname pre/native/post ordering");
        CHECK((value == 41), "sysctlbyname original result preserved");
        CHECK(([fixtureCoordinator registerProviderID:@"first" symbolName:kPXNativeSymbolSysctlByname priority:0 preBlock:^BOOL(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen, int *result) { (void)name; (void)oldp; (void)oldlenp; (void)newp; (void)newlen; *result = 700; [events addObject:@"handled"]; return YES; } postBlock:nil]), "sysctlbyname terminal registration");
        [events removeAllObjects]; nativeCalls = 0;
        value = PXCoord_sysctlbyname("fixture",NULL,NULL,NULL,0);
        CHECK((nativeCalls == 0 && [events isEqualToArray:@[@"handled"]]), "sysctlbyname terminal handling and sanitizer exception");
        CHECK((value == 700), "sysctlbyname handled result preserved");
        Fresh(); g_orig_sysctlbyname = NULL; value = PXCoord_sysctlbyname("fixture",NULL,NULL,NULL,0);
        CHECK((value == -1 && nativeCalls == 0), "sysctlbyname absent original fallback");
    }
    @autoreleasepool { Fresh(); Originals();
        CHECK(([fixtureCoordinator registerProviderID:@"matrix" symbolName:kPXNativeSymbolSysctlNameToMIB priority:10 preBlock:^BOOL(const char *name, int *mib, size_t *namelen, int *result) { (void)name; (void)mib; (void)namelen; (void)result; [events addObject:@"pre"]; return NO; } postBlock:^(const char *name, int *mib, size_t *namelen, int *result) { (void)name; (void)mib; (void)namelen; (void)result; [events addObject:@"post"]; }]), "sysctlnametomib typed registration");
        int value = PXCoord_sysctlnametomib("fixture",NULL,NULL);
        CHECK((nativeCalls == 1 && [events isEqualToArray:@[@"pre",@"native",@"post"]]), "sysctlnametomib pre/native/post ordering");
        CHECK((value == 41), "sysctlnametomib original result preserved");
        CHECK(([fixtureCoordinator registerProviderID:@"first" symbolName:kPXNativeSymbolSysctlNameToMIB priority:0 preBlock:^BOOL(const char *name, int *mib, size_t *namelen, int *result) { (void)name; (void)mib; (void)namelen; *result = 700; [events addObject:@"handled"]; return YES; } postBlock:nil]), "sysctlnametomib terminal registration");
        [events removeAllObjects]; nativeCalls = 0;
        value = PXCoord_sysctlnametomib("fixture",NULL,NULL);
        CHECK((nativeCalls == 0 && [events isEqualToArray:@[@"handled"]]), "sysctlnametomib terminal handling and sanitizer exception");
        CHECK((value == 700), "sysctlnametomib handled result preserved");
        Fresh(); g_orig_sysctlnametomib = NULL; value = PXCoord_sysctlnametomib("fixture",NULL,NULL);
        CHECK((value == -1 && nativeCalls == 0), "sysctlnametomib absent original fallback");
    }
    @autoreleasepool { Fresh(); Originals();
        CHECK(([fixtureCoordinator registerProviderID:@"matrix" symbolName:kPXNativeSymbolGethostname priority:10 preBlock:^BOOL(char *name, size_t namelen, int *result) { (void)name; (void)namelen; (void)result; [events addObject:@"pre"]; return NO; } postBlock:^(char *name, size_t namelen, int *result) { (void)name; (void)namelen; (void)result; [events addObject:@"post"]; }]), "gethostname typed registration");
        int value = PXCoord_gethostname(NULL,0);
        CHECK((nativeCalls == 1 && [events isEqualToArray:@[@"pre",@"native",@"post"]]), "gethostname pre/native/post ordering");
        CHECK((value == 41), "gethostname original result preserved");
        CHECK(([fixtureCoordinator registerProviderID:@"first" symbolName:kPXNativeSymbolGethostname priority:0 preBlock:^BOOL(char *name, size_t namelen, int *result) { (void)name; (void)namelen; *result = 700; [events addObject:@"handled"]; return YES; } postBlock:nil]), "gethostname terminal registration");
        [events removeAllObjects]; nativeCalls = 0;
        value = PXCoord_gethostname(NULL,0);
        CHECK((nativeCalls == 0 && [events isEqualToArray:@[@"handled"]]), "gethostname terminal handling and sanitizer exception");
        CHECK((value == 700), "gethostname handled result preserved");
        Fresh(); g_orig_gethostname = NULL; value = PXCoord_gethostname(NULL,0);
        CHECK((value == -1 && nativeCalls == 0), "gethostname absent original fallback");
    }
    @autoreleasepool { Fresh(); Originals();
        CHECK(([fixtureCoordinator registerProviderID:@"matrix" symbolName:kPXNativeSymbolGetifaddrs priority:10 preBlock:^BOOL(struct ifaddrs **ifap, int *result) { (void)ifap; (void)result; [events addObject:@"pre"]; return NO; } postBlock:^(struct ifaddrs **ifap, int *result) { (void)ifap; (void)result; [events addObject:@"post"]; }]), "getifaddrs typed registration");
        int value = PXCoord_getifaddrs(NULL);
        CHECK((nativeCalls == 1 && [events isEqualToArray:@[@"pre",@"native",@"post"]]), "getifaddrs pre/native/post ordering");
        CHECK((value == 41), "getifaddrs original result preserved");
        CHECK(([fixtureCoordinator registerProviderID:@"first" symbolName:kPXNativeSymbolGetifaddrs priority:0 preBlock:^BOOL(struct ifaddrs **ifap, int *result) { (void)ifap; *result = 700; [events addObject:@"handled"]; return YES; } postBlock:nil]), "getifaddrs terminal registration");
        [events removeAllObjects]; nativeCalls = 0;
        value = PXCoord_getifaddrs(NULL);
        CHECK((nativeCalls == 0 && [events isEqualToArray:@[@"handled",@"post"]]), "getifaddrs terminal handling and sanitizer exception");
        CHECK((value == 700), "getifaddrs handled result preserved");
        Fresh(); g_orig_getifaddrs = NULL; value = PXCoord_getifaddrs(NULL);
        CHECK((value == -1 && nativeCalls == 0), "getifaddrs absent original fallback");
    }
    @autoreleasepool { Fresh(); Originals();
        CHECK(([fixtureCoordinator registerProviderID:@"matrix" symbolName:kPXNativeSymbolIORegistryEntryCreateCFProperty priority:10 preBlock:^BOOL(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options, CFTypeRef *result) { (void)entry; (void)key; (void)allocator; (void)options; (void)result; [events addObject:@"pre"]; return NO; } postBlock:^(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options, CFTypeRef *result) { (void)entry; (void)key; (void)allocator; (void)options; (void)result; [events addObject:@"post"]; }]), "IORegistryEntryCreateCFProperty typed registration");
        CFTypeRef value = PXCoord_IORegistryEntryCreateCFProperty(0,NULL,NULL,0);
        CHECK((nativeCalls == 1 && [events isEqualToArray:@[@"pre",@"native",@"post"]]), "IORegistryEntryCreateCFProperty pre/native/post ordering");
        CHECK((value != NULL), "IORegistryEntryCreateCFProperty original result preserved"); if (value) CFRelease(value);
        CHECK(([fixtureCoordinator registerProviderID:@"first" symbolName:kPXNativeSymbolIORegistryEntryCreateCFProperty priority:0 preBlock:^BOOL(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options, CFTypeRef *result) { (void)entry; (void)key; (void)allocator; (void)options; *result = Answer(); [events addObject:@"handled"]; return YES; } postBlock:nil]), "IORegistryEntryCreateCFProperty terminal registration");
        [events removeAllObjects]; nativeCalls = 0;
        value = PXCoord_IORegistryEntryCreateCFProperty(0,NULL,NULL,0);
        CHECK((nativeCalls == 0 && [events isEqualToArray:@[@"handled"]]), "IORegistryEntryCreateCFProperty terminal handling and sanitizer exception");
        CHECK((value != NULL), "IORegistryEntryCreateCFProperty handled result preserved"); if (value) CFRelease(value);
        Fresh(); g_orig_IORegistryEntryCreateCFProperty = NULL; value = PXCoord_IORegistryEntryCreateCFProperty(0,NULL,NULL,0);
        CHECK((value == NULL && nativeCalls == 0), "IORegistryEntryCreateCFProperty absent original fallback");
    }
    @autoreleasepool { Fresh(); Originals(); CFMutableDictionaryRef properties = NULL;
        CHECK(([fixtureCoordinator registerProviderID:@"matrix" symbolName:kPXNativeSymbolIORegistryEntryCreateCFProperties priority:10 preBlock:^BOOL(io_registry_entry_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, IOOptionBits options, IOReturn *result) { (void)entry; (void)properties; (void)allocator; (void)options; (void)result; [events addObject:@"pre"]; return NO; } postBlock:^(io_registry_entry_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, IOOptionBits options, IOReturn *result) { (void)entry; (void)properties; (void)allocator; (void)options; (void)result; [events addObject:@"post"]; }]), "IORegistryEntryCreateCFProperties typed registration");
        IOReturn value = PXCoord_IORegistryEntryCreateCFProperties(0,&properties,NULL,0);
        CHECK((nativeCalls == 1 && [events isEqualToArray:@[@"pre",@"native",@"post"]]), "IORegistryEntryCreateCFProperties pre/native/post ordering");
        CHECK((value == 41), "IORegistryEntryCreateCFProperties original result preserved"); if (properties) CFRelease(properties); properties = NULL;
        CHECK(([fixtureCoordinator registerProviderID:@"first" symbolName:kPXNativeSymbolIORegistryEntryCreateCFProperties priority:0 preBlock:^BOOL(io_registry_entry_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, IOOptionBits options, IOReturn *result) { (void)entry; (void)properties; (void)allocator; (void)options; if (properties) *properties = CFDictionaryCreateMutable(NULL,0,&kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks); *result = 700; [events addObject:@"handled"]; return YES; } postBlock:nil]), "IORegistryEntryCreateCFProperties terminal registration");
        [events removeAllObjects]; nativeCalls = 0;
        value = PXCoord_IORegistryEntryCreateCFProperties(0,&properties,NULL,0);
        CHECK((nativeCalls == 0 && [events isEqualToArray:@[@"handled"]]), "IORegistryEntryCreateCFProperties terminal handling and sanitizer exception");
        CHECK((value == 700), "IORegistryEntryCreateCFProperties handled result preserved"); if (properties) CFRelease(properties); properties = NULL;
        Fresh(); g_orig_IORegistryEntryCreateCFProperties = NULL; value = PXCoord_IORegistryEntryCreateCFProperties(0,&properties,NULL,0);
        CHECK((value == kIOReturnError && nativeCalls == 0), "IORegistryEntryCreateCFProperties absent original fallback");
    }
    @autoreleasepool { Fresh(); Originals();
        CHECK(([fixtureCoordinator registerProviderID:@"matrix" symbolName:kPXNativeSymbolIORegistryEntrySearchCFProperty priority:10 preBlock:^BOOL(io_registry_entry_t entry, const io_name_t plane, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options, CFTypeRef *result) { (void)entry; (void)plane; (void)key; (void)allocator; (void)options; (void)result; [events addObject:@"pre"]; return NO; } postBlock:^(io_registry_entry_t entry, const io_name_t plane, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options, CFTypeRef *result) { (void)entry; (void)plane; (void)key; (void)allocator; (void)options; (void)result; [events addObject:@"post"]; }]), "IORegistryEntrySearchCFProperty typed registration");
        CFTypeRef value = PXCoord_IORegistryEntrySearchCFProperty(0,NULL,NULL,NULL,0);
        CHECK((nativeCalls == 1 && [events isEqualToArray:@[@"pre",@"native",@"post"]]), "IORegistryEntrySearchCFProperty pre/native/post ordering");
        CHECK((value != NULL), "IORegistryEntrySearchCFProperty original result preserved"); if (value) CFRelease(value);
        CHECK(([fixtureCoordinator registerProviderID:@"first" symbolName:kPXNativeSymbolIORegistryEntrySearchCFProperty priority:0 preBlock:^BOOL(io_registry_entry_t entry, const io_name_t plane, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options, CFTypeRef *result) { (void)entry; (void)plane; (void)key; (void)allocator; (void)options; *result = Answer(); [events addObject:@"handled"]; return YES; } postBlock:nil]), "IORegistryEntrySearchCFProperty terminal registration");
        [events removeAllObjects]; nativeCalls = 0;
        value = PXCoord_IORegistryEntrySearchCFProperty(0,NULL,NULL,NULL,0);
        CHECK((nativeCalls == 0 && [events isEqualToArray:@[@"handled"]]), "IORegistryEntrySearchCFProperty terminal handling and sanitizer exception");
        CHECK((value != NULL), "IORegistryEntrySearchCFProperty handled result preserved"); if (value) CFRelease(value);
        Fresh(); g_orig_IORegistryEntrySearchCFProperty = NULL; value = PXCoord_IORegistryEntrySearchCFProperty(0,NULL,NULL,NULL,0);
        CHECK((value == NULL && nativeCalls == 0), "IORegistryEntrySearchCFProperty absent original fallback");
    }
    @autoreleasepool { Fresh(); Originals();
        CHECK(([fixtureCoordinator registerProviderID:@"matrix" symbolName:kPXNativeSymbolCFCopySystemVersionDictionary priority:10 preBlock:^BOOL(CFDictionaryRef *result) {  (void)result; [events addObject:@"pre"]; return NO; } postBlock:^(CFDictionaryRef *result) {  (void)result; [events addObject:@"post"]; }]), "CFCopySystemVersionDictionary typed registration");
        CFDictionaryRef value = PXCoord_CFCopySystemVersionDictionary();
        CHECK((nativeCalls == 1 && [events isEqualToArray:@[@"pre",@"native",@"post"]]), "CFCopySystemVersionDictionary pre/native/post ordering");
        CHECK((value != NULL), "CFCopySystemVersionDictionary original result preserved"); if (value) CFRelease(value);
        CHECK(([fixtureCoordinator registerProviderID:@"first" symbolName:kPXNativeSymbolCFCopySystemVersionDictionary priority:0 preBlock:^BOOL(CFDictionaryRef *result) {  *result = Answer(); [events addObject:@"handled"]; return YES; } postBlock:nil]), "CFCopySystemVersionDictionary terminal registration");
        [events removeAllObjects]; nativeCalls = 0;
        value = PXCoord_CFCopySystemVersionDictionary();
        CHECK((nativeCalls == 0 && [events isEqualToArray:@[@"handled"]]), "CFCopySystemVersionDictionary terminal handling and sanitizer exception");
        CHECK((value != NULL), "CFCopySystemVersionDictionary handled result preserved"); if (value) CFRelease(value);
        Fresh(); g_orig_CFCopySystemVersionDictionary = NULL; value = PXCoord_CFCopySystemVersionDictionary();
        CHECK((value == NULL && nativeCalls == 0), "CFCopySystemVersionDictionary absent original fallback");
    }
    @autoreleasepool { Fresh(); Originals();
        CHECK(([fixtureCoordinator registerProviderID:@"matrix" symbolName:kPXNativeSymbolStatfs priority:10 preBlock:nil postBlock:^(const char *path, struct statfs *buf, int *result) { (void)path; (void)buf; (void)result; [events addObject:@"post"]; }]), "statfs typed registration");
        int value = PXCoord_statfs(NULL,NULL);
        CHECK((nativeCalls == 1 && [events isEqualToArray:@[@"native",@"post"]]), "statfs pre/native/post ordering");
        CHECK((value == 41), "statfs original result preserved");
        Fresh(); g_orig_statfs = NULL; value = PXCoord_statfs(NULL,NULL);
        CHECK((value == -1 && nativeCalls == 0), "statfs absent original fallback");
    }
    @autoreleasepool { Fresh(); Originals();
        CHECK(([fixtureCoordinator registerProviderID:@"matrix" symbolName:kPXNativeSymbolStatfs64 priority:10 preBlock:nil postBlock:^(const char *path, PXStatfs64Buf *buf, int *result) { (void)path; (void)buf; (void)result; [events addObject:@"post"]; }]), "statfs64 typed registration");
        int value = PXCoord_statfs64(NULL,NULL);
        CHECK((nativeCalls == 1 && [events isEqualToArray:@[@"native",@"post"]]), "statfs64 pre/native/post ordering");
        CHECK((value == 41), "statfs64 original result preserved");
        Fresh(); g_orig_statfs64 = NULL; value = PXCoord_statfs64(NULL,NULL);
        CHECK((value == -1 && nativeCalls == 0), "statfs64 absent original fallback");
    }
    @autoreleasepool { Fresh(); Originals();
        CHECK(([fixtureCoordinator registerProviderID:@"matrix" symbolName:kPXNativeSymbolGetfsstat priority:10 preBlock:nil postBlock:^(struct statfs *buf, int bufsize, int flags, int *result) { (void)buf; (void)bufsize; (void)flags; (void)result; [events addObject:@"post"]; }]), "getfsstat typed registration");
        int value = PXCoord_getfsstat(NULL,0,0);
        CHECK((nativeCalls == 1 && [events isEqualToArray:@[@"native",@"post"]]), "getfsstat pre/native/post ordering");
        CHECK((value == 41), "getfsstat original result preserved");
        Fresh(); g_orig_getfsstat = NULL; value = PXCoord_getfsstat(NULL,0,0);
        CHECK((value == -1 && nativeCalls == 0), "getfsstat absent original fallback");
    }
    @autoreleasepool { Fresh(); Originals();
        CHECK(([fixtureCoordinator registerProviderID:@"matrix" symbolName:kPXNativeSymbolGetfsstat64 priority:10 preBlock:nil postBlock:^(PXStatfs64Buf *buf, int bufsize, int flags, int *result) { (void)buf; (void)bufsize; (void)flags; (void)result; [events addObject:@"post"]; }]), "getfsstat64 typed registration");
        int value = PXCoord_getfsstat64(NULL,0,0);
        CHECK((nativeCalls == 1 && [events isEqualToArray:@[@"native",@"post"]]), "getfsstat64 pre/native/post ordering");
        CHECK((value == 41), "getfsstat64 original result preserved");
        Fresh(); g_orig_getfsstat64 = NULL; value = PXCoord_getfsstat64(NULL,0,0);
        CHECK((value == -1 && nativeCalls == 0), "getfsstat64 absent original fallback");
    }
    @autoreleasepool { Fresh(); Originals();
        CHECK(([fixtureCoordinator registerProviderID:@"matrix" symbolName:kPXNativeSymbolCNCopyCurrentNetworkInfo priority:10 preBlock:^BOOL(CFStringRef interfaceName, CFDictionaryRef *result) { (void)interfaceName; (void)result; [events addObject:@"pre"]; return NO; } postBlock:^(CFStringRef interfaceName, CFDictionaryRef *result) { (void)interfaceName; (void)result; [events addObject:@"post"]; }]), "CNCopyCurrentNetworkInfo typed registration");
        CFDictionaryRef value = PXCoord_CNCopyCurrentNetworkInfo(NULL);
        CHECK((nativeCalls == 1 && [events isEqualToArray:@[@"pre",@"native",@"post"]]), "CNCopyCurrentNetworkInfo pre/native/post ordering");
        CHECK((value != NULL), "CNCopyCurrentNetworkInfo original result preserved"); if (value) CFRelease(value);
        CHECK(([fixtureCoordinator registerProviderID:@"first" symbolName:kPXNativeSymbolCNCopyCurrentNetworkInfo priority:0 preBlock:^BOOL(CFStringRef interfaceName, CFDictionaryRef *result) { (void)interfaceName; *result = Answer(); [events addObject:@"handled"]; return YES; } postBlock:nil]), "CNCopyCurrentNetworkInfo terminal registration");
        [events removeAllObjects]; nativeCalls = 0;
        value = PXCoord_CNCopyCurrentNetworkInfo(NULL);
        CHECK((nativeCalls == 0 && [events isEqualToArray:@[@"handled"]]), "CNCopyCurrentNetworkInfo terminal handling and sanitizer exception");
        CHECK((value != NULL), "CNCopyCurrentNetworkInfo handled result preserved"); if (value) CFRelease(value);
        Fresh(); g_orig_CNCopyCurrentNetworkInfo = NULL; value = PXCoord_CNCopyCurrentNetworkInfo(NULL);
        CHECK((value == NULL && nativeCalls == 0), "CNCopyCurrentNetworkInfo absent original fallback");
    }
    @autoreleasepool { Fresh(); Originals(); uuid_t uuid = {0};
        CHECK(([fixtureCoordinator registerProviderID:@"matrix" symbolName:kPXNativeSymbolGethostuuid priority:10 preBlock:^BOOL(uuid_t id, const struct timespec *wait, int *result) { (void)id; (void)wait; (void)result; [events addObject:@"pre"]; return NO; } postBlock:nil]), "gethostuuid typed registration");
        int value = PXCoord_gethostuuid(uuid,NULL);
        CHECK((nativeCalls == 1 && [events isEqualToArray:@[@"pre",@"native"]]), "gethostuuid pre/native/post ordering");
        CHECK((value == 41), "gethostuuid original result preserved");
        CHECK(([fixtureCoordinator registerProviderID:@"first" symbolName:kPXNativeSymbolGethostuuid priority:0 preBlock:^BOOL(uuid_t id, const struct timespec *wait, int *result) { (void)id; (void)wait; *result = 700; [events addObject:@"handled"]; return YES; } postBlock:nil]), "gethostuuid terminal registration");
        [events removeAllObjects]; nativeCalls = 0;
        value = PXCoord_gethostuuid(uuid,NULL);
        CHECK((nativeCalls == 0 && [events isEqualToArray:@[@"handled"]]), "gethostuuid terminal handling and sanitizer exception");
        CHECK((value == 700), "gethostuuid handled result preserved");
        Fresh(); g_orig_gethostuuid = NULL; value = PXCoord_gethostuuid(uuid,NULL);
        CHECK((value == -1 && nativeCalls == 0), "gethostuuid absent original fallback");
    }
}

static BOOL Register(PXNativeHookCoordinator *coordinator, NSString *name, NSInteger priority, id pre, id post) {
    @try { return [coordinator registerProviderID:name symbolName:kPXNativeSymbolSysctlByname priority:priority preBlock:pre postBlock:post]; }
    @finally { coordinator = nil; name = nil; pre = nil; post = nil; }
}
static BOOL Noop(const char *n, void *p, size_t *s, void *w, size_t z, int *r) { (void)n; (void)p; (void)s; (void)w; (void)z; (void)r; return NO; }
static void RegistryTests(void) {
    Fresh(); PXNativeHookCoordinator *co = fixtureCoordinator;
    PXSysctlBynamePreBlock noop = ^BOOL(const char *n, void *p, size_t *s, void *w, size_t z, int *r) { return Noop(n,p,s,w,z,r); };
    CHECK((Register(co,@"b",10,noop,nil) && Register(co,@"a",10,noop,nil) && Register(co,@"z",0,noop,nil)), "registration accepts multiple providers");
    NSArray<PXNativeHookProvider *> *before = [co _providersCopyForSymbol:kPXNativeSymbolSysctlByname];
    CHECK(([before valueForKey:@"providerID"] && [[before valueForKey:@"providerID"] isEqualToArray:@[@"z",@"a",@"b"]]), "priority then lexical ID order retained");
    CHECK((before == [co _providersCopyForSymbol:kPXNativeSymbolSysctlByname]), "warm reads reuse identical immutable list without copying");
    CHECK((![co registerProviderID:@"a" symbolName:kPXNativeSymbolStatfs priority:0 preBlock:noop postBlock:nil]), "duplicate IDs reject globally across symbols");
    NSMutableString *mutableID = [@"detached" mutableCopy], *symbol = [@"sysctlbyname" mutableCopy];
    CHECK(([co registerProviderID:mutableID symbolName:symbol priority:20 preBlock:noop postBlock:nil]), "mutable caller names accepted");
    [mutableID setString:@"changed"]; [symbol setString:@"changed"];
    NSArray *after = [co _providersCopyForSymbol:kPXNativeSymbolSysctlByname];
    CHECK((before.count == 3 && after.count == 4 && before != after && [[[after lastObject] providerID] isEqual:@"detached"]), "late registration detaches names and never mutates in-flight list");
    CHECK(([co _providersCopyForSymbol:@"absent"].count == 0), "unknown symbol returns an empty list");
    NSDictionary *diagnostic = [co diagnostics];
    CHECK(([[diagnostic objectForKey:@"owner"] isEqual:@"PXNativeHookCoordinator"] && [diagnostic[@"symbols"][@"sysctlbyname"][@"providers"] count] == 4), "diagnostics keeps schema and provider ordering");
    CHECK((![co registerProviderID:@"" symbolName:@"x" priority:0 preBlock:noop postBlock:nil] && ![co registerProviderID:@"empty" symbolName:@"x" priority:0 preBlock:nil postBlock:nil]), "invalid registration has no publication");
}
@interface PXRegistrationInput : NSObject
@property (nonatomic) BOOL throws;
@property (nonatomic) NSUInteger calls;
@end
@implementation PXRegistrationInput
- (BOOL)isKindOfClass:(Class)type {
    (void)type; self.calls++;
    if (self.throws) Raise();
    (void)[fixtureCoordinator registerProviderID:(id)self symbolName:@"sysctl" priority:0 preBlock:^{} postBlock:nil];
    return NO;
}
@end
@interface PXRegistrationCopy : NSObject <NSCopying>
@property (nonatomic) BOOL throws;
@property (nonatomic, strong) NSObject *token;
@end
@implementation PXRegistrationCopy
- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    // Both operations need the registry: a copy under that lock would deadlock.
    (void)[fixtureCoordinator _providersCopyForSymbol:@"sysctlbyname"];
    (void)[fixtureCoordinator diagnostics];
    if (self.throws) Raise();
    return [^BOOL(const char *n,void *p,size_t *s,void *w,size_t z,int *r) { return Noop(n,p,s,w,z,r); } copy];
}
@end
static void InputFaultTests(void) {
    Fresh(); PXRegistrationInput *input = [PXRegistrationInput new];
    CHECK((![fixtureCoordinator registerProviderID:(id)input symbolName:@"sysctl" priority:0 preBlock:^{} postBlock:nil] && input.calls == 1 && !gPXPreparingNativeProvider), "registration guard covers reentrant foreign input before lock");
    input.throws = YES; BOOL caught = NO;
    @try { [fixtureCoordinator registerProviderID:(id)input symbolName:@"sysctl" priority:0 preBlock:^{} postBlock:nil]; }
    @catch (__unused NSException *e) { caught = YES; }
    CHECK((caught && !gPXPreparingNativeProvider && [fixtureCoordinator _providersCopyForSymbol:@"sysctl"].count == 0), "input exception leaves registry unchanged and restores registration guard");
    CHECK(([fixtureCoordinator registerProviderID:@"after-fault" symbolName:@"sysctl" priority:0 preBlock:^{} postBlock:nil]), "registration and logging diagnostics remain usable after fault");
    __weak NSObject *weakToken;
    @autoreleasepool {
        Fresh(); NSObject *token = [NSObject new]; weakToken = token;
        PXRegistrationCopy *copy = [PXRegistrationCopy new]; copy.throws = YES; copy.token = token; token = nil;
        BOOL copyCaught = NO;
        @try { Register(fixtureCoordinator,@"copy-fault",0,copy,nil); }
        @catch (__unused NSException *e) { copyCaught = YES; }
        CHECK((copyCaught && !gPXPreparingNativeProvider && [fixtureCoordinator _providersCopyForSymbol:@"sysctlbyname"].count == 0), "throwing block copy performs unlocked reentrant reads without half registration");
        copy.throws = NO;
        CHECK((Register(fixtureCoordinator,@"copy-fault",0,copy,nil)), "failed copy never reserves ID and later copied callback can publish");
        copy = nil;
    }
    CHECK(!weakToken,"exceptional block copy releases its input owner after pool drain");
}
static void LateRegistrationTests(void) {
    Fresh(); Originals();
    PXSysctlBynamePreBlock late = ^BOOL(const char *n, void *p, size_t *s, void *w, size_t z, int *r) { (void)Noop(n,p,s,w,z,r); [events addObject:@"late"]; return NO; };
    // This scope ends before any dispatcher can throw; retained blocks own inputs.
    {
        PXSysctlBynamePreBlock captured = late;
        Register(fixtureCoordinator,@"first",0,^BOOL(const char *n, void *p, size_t *s, void *w, size_t z, int *r) {
            (void)Noop(n,p,s,w,z,r); [events addObject:@"first"];
            Register(fixtureCoordinator,@"late",10,captured,nil); return NO;
        },^(const char *n, void *p, size_t *s, void *w, size_t z, int *r) { (void)Noop(n,p,s,w,z,r); [events addObject:@"post"]; });
    }
    (void)PXCoord_sysctlbyname("fixture",NULL,NULL,NULL,0);
    CHECK(([events isEqualToArray:@[@"first",@"native",@"post"]]), "callback registration does not alter current pre/post snapshot");
    [events removeAllObjects];
    (void)PXCoord_sysctlbyname("fixture",NULL,NULL,NULL,0);
    CHECK(([events isEqualToArray:@[@"first",@"late",@"native",@"post"]]), "next dispatch observes callback registration in priority order");
}
static void ConcurrentTests(void) {
    Fresh(); PXNativeHookCoordinator *co = fixtureCoordinator;
    dispatch_group_t group = dispatch_group_create(); __block NSUInteger accepted = 0;
    for (NSUInteger i = 0; i < 64; i++) {
        dispatch_group_async(group,dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{ @autoreleasepool {
            NSString *name = [NSString stringWithFormat:@"provider-%03lu",(unsigned long)i];
            if ([co registerProviderID:name symbolName:@"parallel" priority:(NSInteger)(i % 4) preBlock:^{} postBlock:nil]) @synchronized(co) { accepted++; }
            (void)[co diagnostics];
        }});
    }
    CHECK((dispatch_group_wait(group,dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC)) == 0), "parallel independent registrations terminate");
    NSArray<PXNativeHookProvider *> *list = [co _providersCopyForSymbol:@"parallel"];
    CHECK((accepted == 64 && list.count == 64 && [[NSSet setWithArray:[list valueForKey:@"providerID"]] count] == 64), "publication retries preserve every concurrent unique provider");
    BOOL ordered = YES;
    for (NSUInteger i = 1; i < list.count; i++) {
        PXNativeHookProvider *a = list[i-1], *b = list[i];
        if (a.priority > b.priority || (a.priority == b.priority && [a.providerID compare:b.providerID] != NSOrderedAscending)) ordered = NO;
    }
    CHECK(ordered,"parallel publication retains total ordering");
    accepted = 0;
    for (NSUInteger i = 0; i < 32; i++) dispatch_group_async(group,dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{ @autoreleasepool {
        if ([co registerProviderID:@"same-id" symbolName:@"parallel" priority:0 preBlock:^{} postBlock:nil]) @synchronized(co) { accepted++; }
    }});
    CHECK((dispatch_group_wait(group,dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC)) == 0 && accepted == 1 && [co _providersCopyForSymbol:@"parallel"].count == 65), "competing duplicate registration has exactly one winner");
}
static void MapperTests(void) {
    Fresh(); Originals();
    [fixtureCoordinator registerSysctlNameToMIBProvider:@"pre-throws" priority:0 pre:^BOOL(const char *name,int *mib,size_t *length,int *result) {
        (void)name;(void)mib;(void)length;(void)result; Raise(); return NO;
    } post:^(const char *name,int *mib,size_t *length,int *result) { (void)name;(void)mib;(void)length;(void)result; [events addObject:@"unexpected-post"]; }];
    CHECK((PXCoord_sysctlnametomib("fixture",NULL,NULL) == 41 && nativeCalls == 1 && events.count == 1 && !g_inside_sysctlnametomib), "mapper pre fault falls back once and skips posts");
    Fresh(); Originals();
    [fixtureCoordinator registerSysctlNameToMIBProvider:@"post-throws" priority:0 pre:nil post:^(const char *name,int *mib,size_t *length,int *result) { (void)name;(void)mib;(void)length; *result = 99; Raise(); }];
    CHECK((PXCoord_sysctlnametomib("fixture",NULL,NULL) == 99 && nativeCalls == 1 && !g_inside_sysctlnametomib), "mapper post fault preserves current result without original replay");
    Fresh(); Originals(); nativeThrows = YES; BOOL caught = NO;
    @try { (void)PXCoord_sysctlnametomib("fixture",NULL,NULL); } @catch (__unused NSException *e) { caught = YES; }
    CHECK((caught && nativeCalls == 1 && !g_inside_sysctlnametomib), "mapper native exception propagates exactly once and clears TLS");
    Fresh(); Originals();
    [fixtureCoordinator registerSysctlNameToMIBProvider:@"nested" priority:0 pre:^BOOL(const char *name,int *mib,size_t *length,int *result) {
        *result = PXCoord_sysctlnametomib(name,mib,length); return YES;
    } post:nil];
    CHECK((PXCoord_sysctlnametomib("fixture",NULL,NULL) == 41 && nativeCalls == 1 && !g_inside_sysctlnametomib), "mapper nested dispatch reaches native without repeating provider");
    BOOL scoped = NO; (void)PXRuntimeReadScopeCurrent(&scoped); CHECK(!scoped,"RootHide lexical frame is gone after all mapper exits");
}
static void LifetimeTests(void) {
    for (int fault = 0; fault < 3; fault++) {
        __weak NSObject *weakToken; __weak PXNativeHookCoordinator *weakCoordinator;
        @autoreleasepool {
            Fresh(); Originals(); weakCoordinator = fixtureCoordinator;
            NSObject *token = [NSObject new]; weakToken = token;
            PXSysctlBynamePreBlock pre = nil; PXSysctlBynamePostBlock post = nil;
            {
                NSObject *capture = token; int capturedFault = fault;
                pre = ^BOOL(const char *n,void *p,size_t *s,void *w,size_t z,int *r) {
                    (void)Noop(n,p,s,w,z,r); (void)[capture class]; fixtureCoordinator = nil;
                    if (capturedFault == 0) Raise(); return NO;
                };
                post = ^(const char *n,void *p,size_t *s,void *w,size_t z,int *r) { (void)Noop(n,p,s,w,z,r); (void)[capture class]; if (capturedFault == 2) Raise(); };
            }
            Register(fixtureCoordinator,@"lifetime",0,pre,post); pre = nil; post = nil; token = nil;
            nativeThrows = fault == 1; BOOL caught = NO;
            @try { (void)PXCoord_sysctlbyname("fixture",NULL,NULL,NULL,0); }
            @catch (__unused NSException *e) { caught = YES; }
            CHECK((caught && nativeCalls == (fault == 0 ? 0 : 1)), "scalar provider/native exceptional exit preserves cardinality");
        }
        CHECK((!weakToken && !weakCoordinator), "plain ARC exceptional dispatch releases coordinator list provider and captures after pool drain");
        BOOL scoped = NO; (void)PXRuntimeReadScopeCurrent(&scoped); CHECK(!scoped,"exception releases real lexical operation frame");
    }
    for (int manual = 0; manual < 2; manual++) {
        __weak NSObject *weakToken;
        @autoreleasepool {
            Fresh(); NSObject *token = [NSObject new]; weakToken = token;
            PXRegistrationInput *input = [PXRegistrationInput new]; input.throws = YES;
            PXSysctlBynamePreBlock pre = nil; PXStatfsPostBlock post = nil;
            {
                NSObject *capture = token;
                pre = ^BOOL(const char *n,void *p,size_t *s,void *w,size_t z,int *r) { (void)[capture class]; return Noop(n,p,s,w,z,r); };
                post = ^(const char *path,struct statfs *buf,int *result) { (void)path;(void)buf;(void)result;(void)[capture class]; };
            }
            BOOL caught = NO;
            @try {
                if (manual) [fixtureCoordinator registerStatfsProvider:(id)input priority:0 post:post];
                else [fixtureCoordinator registerSysctlBynameProvider:(id)input priority:0 pre:pre post:nil];
            } @catch (__unused NSException *e) { caught = YES; }
            @finally { token = nil; pre = nil; post = nil; input = nil; }
            CHECK((caught && !gPXPreparingNativeProvider), "typed registration input exception preserves rejection and restores guard");
        }
        CHECK(!weakToken,"macro and explicit typed registrar release callback inputs after exceptional exit");
    }
}
int main(void) {
    Method shared = class_getClassMethod(PXNativeHookCoordinator.class,@selector(sharedCoordinator));
    IMP original = method_setImplementation(shared,(IMP)FixtureShared);
    @autoreleasepool { DispatchMatrix(); RegistryTests(); InputFaultTests(); LateRegistrationTests(); ConcurrentTests(); MapperTests(); LifetimeTests(); }
    fixtureCoordinator = nil; events = nil;
    method_setImplementation(shared,original);
    fprintf(stdout,"Native provider registry/dispatch: %lu/%lu checks passed\n",(unsigned long)(checks-failures),(unsigned long)checks);
    return failures ? 1 : 0;
}
