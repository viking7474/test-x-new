// PXNativeHookCoordinator.m
// Single owner of MSHookFunction for multi-module native symbols.

#import "PXNativeHookCoordinator.h"
#import "ProjectXLogging.h"
#import <dlfcn.h>
#import <os/lock.h>
#import <string.h>
#import <uuid/uuid.h>

// Substrate
extern void MSHookFunction(void *symbol, void *replace, void **result);

NSString * const kPXNativeSymbolSysctl = @"sysctl";
NSString * const kPXNativeSymbolSysctlByname = @"sysctlbyname";
NSString * const kPXNativeSymbolGethostname = @"gethostname";
NSString * const kPXNativeSymbolGetifaddrs = @"getifaddrs";
NSString * const kPXNativeSymbolIORegistryEntryCreateCFProperty = @"IORegistryEntryCreateCFProperty";
NSString * const kPXNativeSymbolIORegistryEntryCreateCFProperties = @"IORegistryEntryCreateCFProperties";
NSString * const kPXNativeSymbolIORegistryEntrySearchCFProperty = @"IORegistryEntrySearchCFProperty";
NSString * const kPXNativeSymbolCFCopySystemVersionDictionary = @"CFCopySystemVersionDictionary";
NSString * const kPXNativeSymbolStatfs = @"statfs";
NSString * const kPXNativeSymbolStatfs64 = @"statfs64";
NSString * const kPXNativeSymbolGetfsstat = @"getfsstat";
NSString * const kPXNativeSymbolGetfsstat64 = @"getfsstat64";
NSString * const kPXNativeSymbolCNCopyCurrentNetworkInfo = @"CNCopyCurrentNetworkInfo";
NSString * const kPXNativeSymbolGethostuuid = @"gethostuuid";

@interface PXNativeHookProvider : NSObject
@property (nonatomic, copy) NSString *providerID;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, assign) NSInteger priority;
@property (nonatomic, copy, nullable) id preBlock;
@property (nonatomic, copy, nullable) id postBlock;
@end

@implementation PXNativeHookProvider
@end

@interface PXNativeHookCoordinator () {
    os_unfair_lock _lock;
}
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<PXNativeHookProvider *> *> *providersBySymbol;
@property (nonatomic, strong) NSMutableSet<NSString *> *globalProviderIDs;
@property (nonatomic, strong) NSMutableSet<NSString *> *installedSymbols;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *installCounts;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSValue *> *originalPointers;
@end

@implementation PXNativeHookCoordinator

#pragma mark - Original function pointers (owned solely by coordinator)

static int (*g_orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t) = NULL;
static int (*g_orig_sysctlbyname)(const char *, void *, size_t *, void *, size_t) = NULL;
static int (*g_orig_gethostname)(char *, size_t) = NULL;
static int (*g_orig_getifaddrs)(struct ifaddrs **) = NULL;
static CFTypeRef (*g_orig_IORegistryEntryCreateCFProperty)(io_registry_entry_t, CFStringRef, CFAllocatorRef, IOOptionBits) = NULL;
static IOReturn (*g_orig_IORegistryEntryCreateCFProperties)(io_registry_entry_t, CFMutableDictionaryRef *, CFAllocatorRef, IOOptionBits) = NULL;
static CFTypeRef (*g_orig_IORegistryEntrySearchCFProperty)(io_registry_entry_t, const io_name_t, CFStringRef, CFAllocatorRef, IOOptionBits) = NULL;
static CFDictionaryRef (*g_orig_CFCopySystemVersionDictionary)(void) = NULL;
static int (*g_orig_statfs)(const char *, struct statfs *) = NULL;
static int (*g_orig_statfs64)(const char *, struct statfs64 *) = NULL;
static int (*g_orig_getfsstat)(struct statfs *, int, int) = NULL;
static int (*g_orig_getfsstat64)(struct statfs64 *, int, int) = NULL;
static CFDictionaryRef (*g_orig_CNCopyCurrentNetworkInfo)(CFStringRef) = NULL;
static int (*g_orig_gethostuuid)(uuid_t, const struct timespec *) = NULL;

+ (instancetype)sharedCoordinator {
    static PXNativeHookCoordinator *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[PXNativeHookCoordinator alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lock = OS_UNFAIR_LOCK_INIT;
        _providersBySymbol = [NSMutableDictionary dictionary];
        _globalProviderIDs = [NSMutableSet set];
        _installedSymbols = [NSMutableSet set];
        _installCounts = [NSMutableDictionary dictionary];
        _originalPointers = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Registration

- (BOOL)registerProviderID:(NSString *)providerID
                symbolName:(NSString *)symbolName
                  priority:(NSInteger)priority
                  preBlock:(id)preBlock
                 postBlock:(id)postBlock {
    if (!providerID.length || !symbolName.length) return NO;
    if (!preBlock && !postBlock) return NO;

    os_unfair_lock_lock(&_lock);
    if ([self.globalProviderIDs containsObject:providerID]) {
        os_unfair_lock_unlock(&_lock);
        PXLog(@"[PXNativeHook] ❌ Rejected duplicate provider ID: %@", providerID);
        return NO;
    }

    PXNativeHookProvider *provider = [[PXNativeHookProvider alloc] init];
    provider.providerID = providerID;
    provider.symbolName = symbolName;
    provider.priority = priority;
    provider.preBlock = [preBlock copy];
    provider.postBlock = [postBlock copy];

    NSMutableArray *list = self.providersBySymbol[symbolName];
    if (!list) {
        list = [NSMutableArray array];
        self.providersBySymbol[symbolName] = list;
    }
    [list addObject:provider];
    [list sortUsingComparator:^NSComparisonResult(PXNativeHookProvider *a, PXNativeHookProvider *b) {
        if (a.priority < b.priority) return NSOrderedAscending;
        if (a.priority > b.priority) return NSOrderedDescending;
        return [a.providerID compare:b.providerID];
    }];
    [self.globalProviderIDs addObject:providerID];
    os_unfair_lock_unlock(&_lock);

    PXLog(@"[PXNativeHook] ✅ Registered provider %@ for %@ priority=%ld", providerID, symbolName, (long)priority);
    return YES;
}

- (NSArray<PXNativeHookProvider *> *)_providersCopyForSymbol:(NSString *)symbol {
    os_unfair_lock_lock(&_lock);
    NSArray *copy = [self.providersBySymbol[symbol] copy] ?: @[];
    os_unfair_lock_unlock(&_lock);
    return copy;
}

#define PX_REG_TYPED(name, symbolConst, preT, postT) \
- (BOOL)name:(NSString *)providerID priority:(NSInteger)priority pre:(preT)pre post:(postT)post { \
    return [self registerProviderID:providerID symbolName:symbolConst priority:priority preBlock:pre postBlock:post]; \
}

PX_REG_TYPED(registerSysctlProvider, kPXNativeSymbolSysctl, PXSysctlPreBlock, PXSysctlPostBlock)
PX_REG_TYPED(registerSysctlBynameProvider, kPXNativeSymbolSysctlByname, PXSysctlBynamePreBlock, PXSysctlBynamePostBlock)
PX_REG_TYPED(registerGethostnameProvider, kPXNativeSymbolGethostname, PXGethostnamePreBlock, PXGethostnamePostBlock)
PX_REG_TYPED(registerGetifaddrsProvider, kPXNativeSymbolGetifaddrs, PXGetifaddrsPreBlock, PXGetifaddrsPostBlock)
PX_REG_TYPED(registerIORegistryCreateCFPropertyProvider, kPXNativeSymbolIORegistryEntryCreateCFProperty, PXIORegCreateCFPropertyPreBlock, PXIORegCreateCFPropertyPostBlock)
PX_REG_TYPED(registerIORegistryCreateCFPropertiesProvider, kPXNativeSymbolIORegistryEntryCreateCFProperties, PXIORegCreateCFPropertiesPreBlock, PXIORegCreateCFPropertiesPostBlock)
PX_REG_TYPED(registerIORegistrySearchCFPropertyProvider, kPXNativeSymbolIORegistryEntrySearchCFProperty, PXIORegSearchCFPropertyPreBlock, PXIORegSearchCFPropertyPostBlock)
PX_REG_TYPED(registerCFCopySystemVersionDictionaryProvider, kPXNativeSymbolCFCopySystemVersionDictionary, PXCFCopySystemVersionDictPreBlock, PXCFCopySystemVersionDictPostBlock)
PX_REG_TYPED(registerCNCopyCurrentNetworkInfoProvider, kPXNativeSymbolCNCopyCurrentNetworkInfo, PXCNCopyNetworkInfoPreBlock, PXCNCopyNetworkInfoPostBlock)

- (BOOL)registerStatfsProvider:(NSString *)providerID priority:(NSInteger)priority post:(PXStatfsPostBlock)post {
    return [self registerProviderID:providerID symbolName:kPXNativeSymbolStatfs priority:priority preBlock:nil postBlock:post];
}
- (BOOL)registerStatfs64Provider:(NSString *)providerID priority:(NSInteger)priority post:(PXStatfs64PostBlock)post {
    return [self registerProviderID:providerID symbolName:kPXNativeSymbolStatfs64 priority:priority preBlock:nil postBlock:post];
}
- (BOOL)registerGetfsstatProvider:(NSString *)providerID priority:(NSInteger)priority post:(PXGetfsstatPostBlock)post {
    return [self registerProviderID:providerID symbolName:kPXNativeSymbolGetfsstat priority:priority preBlock:nil postBlock:post];
}
- (BOOL)registerGetfsstat64Provider:(NSString *)providerID priority:(NSInteger)priority post:(PXGetfsstat64PostBlock)post {
    return [self registerProviderID:providerID symbolName:kPXNativeSymbolGetfsstat64 priority:priority preBlock:nil postBlock:post];
}
- (BOOL)registerGethostuuidProvider:(NSString *)providerID priority:(NSInteger)priority pre:(PXGethostuuidPreBlock)pre {
    return [self registerProviderID:providerID symbolName:kPXNativeSymbolGethostuuid priority:priority preBlock:pre postBlock:nil];
}

#pragma mark - Dispatch helpers

static int PXCoord_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
    NSArray<PXNativeHookProvider *> *providers = [coord _providersCopyForSymbol:kPXNativeSymbolSysctl];
    for (PXNativeHookProvider *p in providers) {
        PXSysctlPreBlock pre = p.preBlock;
        if (!pre) continue;
        int result = 0;
        if (pre(name, namelen, oldp, oldlenp, newp, newlen, &result)) {
            return result;
        }
    }
    int result = g_orig_sysctl ? g_orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen) : -1;
    for (PXNativeHookProvider *p in providers) {
        PXSysctlPostBlock post = p.postBlock;
        if (post) post(name, namelen, oldp, oldlenp, newp, newlen, &result);
    }
    return result;
}

static int PXCoord_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
    NSArray<PXNativeHookProvider *> *providers = [coord _providersCopyForSymbol:kPXNativeSymbolSysctlByname];
    for (PXNativeHookProvider *p in providers) {
        PXSysctlBynamePreBlock pre = p.preBlock;
        if (!pre) continue;
        int result = 0;
        if (pre(name, oldp, oldlenp, newp, newlen, &result)) {
            return result;
        }
    }
    int result = g_orig_sysctlbyname ? g_orig_sysctlbyname(name, oldp, oldlenp, newp, newlen) : -1;
    for (PXNativeHookProvider *p in providers) {
        PXSysctlBynamePostBlock post = p.postBlock;
        if (post) post(name, oldp, oldlenp, newp, newlen, &result);
    }
    return result;
}

static int PXCoord_gethostname(char *name, size_t namelen) {
    PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
    NSArray<PXNativeHookProvider *> *providers = [coord _providersCopyForSymbol:kPXNativeSymbolGethostname];
    for (PXNativeHookProvider *p in providers) {
        PXGethostnamePreBlock pre = p.preBlock;
        if (!pre) continue;
        int result = 0;
        if (pre(name, namelen, &result)) {
            return result;
        }
    }
    int result = g_orig_gethostname ? g_orig_gethostname(name, namelen) : -1;
    for (PXNativeHookProvider *p in providers) {
        PXGethostnamePostBlock post = p.postBlock;
        if (post) post(name, namelen, &result);
    }
    return result;
}

static int PXCoord_getifaddrs(struct ifaddrs **ifap) {
    PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
    NSArray<PXNativeHookProvider *> *providers = [coord _providersCopyForSymbol:kPXNativeSymbolGetifaddrs];
    for (PXNativeHookProvider *p in providers) {
        PXGetifaddrsPreBlock pre = p.preBlock;
        if (!pre) continue;
        int result = 0;
        if (pre(ifap, &result)) {
            return result;
        }
    }
    int result = g_orig_getifaddrs ? g_orig_getifaddrs(ifap) : -1;
    for (PXNativeHookProvider *p in providers) {
        PXGetifaddrsPostBlock post = p.postBlock;
        if (post) post(ifap, &result);
    }
    return result;
}

static CFTypeRef PXCoord_IORegistryEntryCreateCFProperty(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options) {
    PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
    NSArray<PXNativeHookProvider *> *providers = [coord _providersCopyForSymbol:kPXNativeSymbolIORegistryEntryCreateCFProperty];
    for (PXNativeHookProvider *p in providers) {
        PXIORegCreateCFPropertyPreBlock pre = p.preBlock;
        if (!pre) continue;
        CFTypeRef result = NULL;
        if (pre(entry, key, allocator, options, &result)) {
            return result;
        }
    }
    CFTypeRef result = g_orig_IORegistryEntryCreateCFProperty ? g_orig_IORegistryEntryCreateCFProperty(entry, key, allocator, options) : NULL;
    for (PXNativeHookProvider *p in providers) {
        PXIORegCreateCFPropertyPostBlock post = p.postBlock;
        if (post) post(entry, key, allocator, options, &result);
    }
    return result;
}

static IOReturn PXCoord_IORegistryEntryCreateCFProperties(io_registry_entry_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, IOOptionBits options) {
    PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
    NSArray<PXNativeHookProvider *> *providers = [coord _providersCopyForSymbol:kPXNativeSymbolIORegistryEntryCreateCFProperties];
    for (PXNativeHookProvider *p in providers) {
        PXIORegCreateCFPropertiesPreBlock pre = p.preBlock;
        if (!pre) continue;
        IOReturn result = kIOReturnSuccess;
        if (pre(entry, properties, allocator, options, &result)) {
            return result;
        }
    }
    IOReturn result = g_orig_IORegistryEntryCreateCFProperties ? g_orig_IORegistryEntryCreateCFProperties(entry, properties, allocator, options) : kIOReturnError;
    for (PXNativeHookProvider *p in providers) {
        PXIORegCreateCFPropertiesPostBlock post = p.postBlock;
        if (post) post(entry, properties, allocator, options, &result);
    }
    return result;
}

static CFTypeRef PXCoord_IORegistryEntrySearchCFProperty(io_registry_entry_t entry, const io_name_t plane, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options) {
    PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
    NSArray<PXNativeHookProvider *> *providers = [coord _providersCopyForSymbol:kPXNativeSymbolIORegistryEntrySearchCFProperty];
    for (PXNativeHookProvider *p in providers) {
        PXIORegSearchCFPropertyPreBlock pre = p.preBlock;
        if (!pre) continue;
        CFTypeRef result = NULL;
        if (pre(entry, plane, key, allocator, options, &result)) {
            return result;
        }
    }
    CFTypeRef result = g_orig_IORegistryEntrySearchCFProperty ? g_orig_IORegistryEntrySearchCFProperty(entry, plane, key, allocator, options) : NULL;
    for (PXNativeHookProvider *p in providers) {
        PXIORegSearchCFPropertyPostBlock post = p.postBlock;
        if (post) post(entry, plane, key, allocator, options, &result);
    }
    return result;
}

static CFDictionaryRef PXCoord_CFCopySystemVersionDictionary(void) {
    PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
    NSArray<PXNativeHookProvider *> *providers = [coord _providersCopyForSymbol:kPXNativeSymbolCFCopySystemVersionDictionary];
    for (PXNativeHookProvider *p in providers) {
        PXCFCopySystemVersionDictPreBlock pre = p.preBlock;
        if (!pre) continue;
        CFDictionaryRef result = NULL;
        if (pre(&result)) {
            return result;
        }
    }
    CFDictionaryRef result = g_orig_CFCopySystemVersionDictionary ? g_orig_CFCopySystemVersionDictionary() : NULL;
    for (PXNativeHookProvider *p in providers) {
        PXCFCopySystemVersionDictPostBlock post = p.postBlock;
        if (post) post(&result);
    }
    return result;
}

static int PXCoord_statfs(const char *path, struct statfs *buf) {
    int result = g_orig_statfs ? g_orig_statfs(path, buf) : -1;
    PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
    NSArray<PXNativeHookProvider *> *providers = [coord _providersCopyForSymbol:kPXNativeSymbolStatfs];
    for (PXNativeHookProvider *p in providers) {
        PXStatfsPostBlock post = p.postBlock;
        if (post) post(path, buf, &result);
    }
    return result;
}

static int PXCoord_statfs64(const char *path, struct statfs64 *buf) {
    int result = g_orig_statfs64 ? g_orig_statfs64(path, buf) : -1;
    PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
    NSArray<PXNativeHookProvider *> *providers = [coord _providersCopyForSymbol:kPXNativeSymbolStatfs64];
    for (PXNativeHookProvider *p in providers) {
        PXStatfs64PostBlock post = p.postBlock;
        if (post) post(path, buf, &result);
    }
    return result;
}

static int PXCoord_getfsstat(struct statfs *buf, int bufsize, int flags) {
    int result = g_orig_getfsstat ? g_orig_getfsstat(buf, bufsize, flags) : -1;
    PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
    NSArray<PXNativeHookProvider *> *providers = [coord _providersCopyForSymbol:kPXNativeSymbolGetfsstat];
    for (PXNativeHookProvider *p in providers) {
        PXGetfsstatPostBlock post = p.postBlock;
        if (post) post(buf, bufsize, flags, &result);
    }
    return result;
}

static int PXCoord_getfsstat64(struct statfs64 *buf, int bufsize, int flags) {
    int result = g_orig_getfsstat64 ? g_orig_getfsstat64(buf, bufsize, flags) : -1;
    PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
    NSArray<PXNativeHookProvider *> *providers = [coord _providersCopyForSymbol:kPXNativeSymbolGetfsstat64];
    for (PXNativeHookProvider *p in providers) {
        PXGetfsstat64PostBlock post = p.postBlock;
        if (post) post(buf, bufsize, flags, &result);
    }
    return result;
}

static CFDictionaryRef PXCoord_CNCopyCurrentNetworkInfo(CFStringRef interfaceName) {
    PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
    NSArray<PXNativeHookProvider *> *providers = [coord _providersCopyForSymbol:kPXNativeSymbolCNCopyCurrentNetworkInfo];
    for (PXNativeHookProvider *p in providers) {
        PXCNCopyNetworkInfoPreBlock pre = p.preBlock;
        if (!pre) continue;
        CFDictionaryRef result = NULL;
        if (pre(interfaceName, &result)) {
            return result;
        }
    }
    CFDictionaryRef result = g_orig_CNCopyCurrentNetworkInfo ? g_orig_CNCopyCurrentNetworkInfo(interfaceName) : NULL;
    for (PXNativeHookProvider *p in providers) {
        PXCNCopyNetworkInfoPostBlock post = p.postBlock;
        if (post) post(interfaceName, &result);
    }
    return result;
}

static int PXCoord_gethostuuid(uuid_t id, const struct timespec *wait) {
    PXNativeHookCoordinator *coord = [PXNativeHookCoordinator sharedCoordinator];
    NSArray<PXNativeHookProvider *> *providers = [coord _providersCopyForSymbol:kPXNativeSymbolGethostuuid];
    for (PXNativeHookProvider *p in providers) {
        PXGethostuuidPreBlock pre = p.preBlock;
        if (!pre) continue;
        int result = 0;
        if (pre(id, wait, &result)) {
            return result;
        }
    }
    return g_orig_gethostuuid ? g_orig_gethostuuid(id, wait) : -1;
}

#pragma mark - Installation

- (void)_markInstalled:(NSString *)symbol original:(void *)orig {
    [self.installedSymbols addObject:symbol];
    NSInteger count = [self.installCounts[symbol] integerValue] + 1;
    self.installCounts[symbol] = @(count);
    if (orig) {
        self.originalPointers[symbol] = [NSValue valueWithPointer:orig];
    }
}

- (BOOL)_installSymbol:(NSString *)symbolName replace:(void *)replace originalOut:(void **)originalOut {
    os_unfair_lock_lock(&_lock);
    if ([self.installedSymbols containsObject:symbolName]) {
        os_unfair_lock_unlock(&_lock);
        return YES;
    }
    os_unfair_lock_unlock(&_lock);

    if (!dlsym(RTLD_DEFAULT, "MSHookFunction")) {
        PXLog(@"[PXNativeHook] ❌ MSHookFunction unavailable; cannot install %@", symbolName);
        return NO;
    }
    void *sym = dlsym(RTLD_DEFAULT, symbolName.UTF8String);
    if (!sym) {
        const char *libs[] = {
            "/usr/lib/libSystem.B.dylib",
            "/usr/lib/system/libsystem_c.dylib",
            NULL
        };
        for (int i = 0; libs[i]; i++) {
            void *h = dlopen(libs[i], RTLD_NOLOAD);
            if (!h) h = dlopen(libs[i], RTLD_NOW);
            if (h) {
                sym = dlsym(h, symbolName.UTF8String);
                if (sym) break;
            }
        }
    }
    if (!sym) {
        PXLog(@"[PXNativeHook] ⚠️ Symbol not found: %@", symbolName);
        return NO;
    }
    MSHookFunction(sym, replace, originalOut);
    os_unfair_lock_lock(&_lock);
    [self _markInstalled:symbolName original:originalOut ? *originalOut : NULL];
    os_unfair_lock_unlock(&_lock);
    PXLog(@"[PXNativeHook] ✅ Installed %@ (original=%p)", symbolName, originalOut ? *originalOut : NULL);
    return YES;
}

- (void)installOwnedSymbolsIfNeeded {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self _installSymbol:kPXNativeSymbolSysctl replace:(void *)PXCoord_sysctl originalOut:(void **)&g_orig_sysctl];
        [self _installSymbol:kPXNativeSymbolSysctlByname replace:(void *)PXCoord_sysctlbyname originalOut:(void **)&g_orig_sysctlbyname];
        [self _installSymbol:kPXNativeSymbolGethostname replace:(void *)PXCoord_gethostname originalOut:(void **)&g_orig_gethostname];
        [self _installSymbol:kPXNativeSymbolGetifaddrs replace:(void *)PXCoord_getifaddrs originalOut:(void **)&g_orig_getifaddrs];
        [self _installSymbol:kPXNativeSymbolGethostuuid replace:(void *)PXCoord_gethostuuid originalOut:(void **)&g_orig_gethostuuid];
        [self _installSymbol:kPXNativeSymbolStatfs replace:(void *)PXCoord_statfs originalOut:(void **)&g_orig_statfs];
        [self _installSymbol:kPXNativeSymbolStatfs64 replace:(void *)PXCoord_statfs64 originalOut:(void **)&g_orig_statfs64];
        [self _installSymbol:kPXNativeSymbolGetfsstat replace:(void *)PXCoord_getfsstat originalOut:(void **)&g_orig_getfsstat];
        [self _installSymbol:kPXNativeSymbolGetfsstat64 replace:(void *)PXCoord_getfsstat64 originalOut:(void **)&g_orig_getfsstat64];

        // IOKit
        void *iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
        if (iokit) {
            void *p1 = dlsym(iokit, "IORegistryEntryCreateCFProperty");
            void *p2 = dlsym(iokit, "IORegistryEntryCreateCFProperties");
            void *p3 = dlsym(iokit, "IORegistryEntrySearchCFProperty");
            os_unfair_lock_lock(&self->_lock);
            if (p1 && ![self.installedSymbols containsObject:kPXNativeSymbolIORegistryEntryCreateCFProperty]) {
                MSHookFunction(p1, (void *)PXCoord_IORegistryEntryCreateCFProperty, (void **)&g_orig_IORegistryEntryCreateCFProperty);
                [self _markInstalled:kPXNativeSymbolIORegistryEntryCreateCFProperty original:(void *)g_orig_IORegistryEntryCreateCFProperty];
            }
            if (p2 && ![self.installedSymbols containsObject:kPXNativeSymbolIORegistryEntryCreateCFProperties]) {
                MSHookFunction(p2, (void *)PXCoord_IORegistryEntryCreateCFProperties, (void **)&g_orig_IORegistryEntryCreateCFProperties);
                [self _markInstalled:kPXNativeSymbolIORegistryEntryCreateCFProperties original:(void *)g_orig_IORegistryEntryCreateCFProperties];
            }
            if (p3 && ![self.installedSymbols containsObject:kPXNativeSymbolIORegistryEntrySearchCFProperty]) {
                MSHookFunction(p3, (void *)PXCoord_IORegistryEntrySearchCFProperty, (void **)&g_orig_IORegistryEntrySearchCFProperty);
                [self _markInstalled:kPXNativeSymbolIORegistryEntrySearchCFProperty original:(void *)g_orig_IORegistryEntrySearchCFProperty];
            }
            os_unfair_lock_unlock(&self->_lock);
        }

        // CoreFoundation
        void *cf = dlopen("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", RTLD_NOW);
        if (cf) {
            void *sym = dlsym(cf, "CFCopySystemVersionDictionary");
            if (!sym) sym = dlsym(cf, "_CFCopySystemVersionDictionary");
            if (sym) {
                os_unfair_lock_lock(&self->_lock);
                if (![self.installedSymbols containsObject:kPXNativeSymbolCFCopySystemVersionDictionary]) {
                    MSHookFunction(sym, (void *)PXCoord_CFCopySystemVersionDictionary, (void **)&g_orig_CFCopySystemVersionDictionary);
                    [self _markInstalled:kPXNativeSymbolCFCopySystemVersionDictionary original:(void *)g_orig_CFCopySystemVersionDictionary];
                }
                os_unfair_lock_unlock(&self->_lock);
            }
        }

        // SystemConfiguration CNCopyCurrentNetworkInfo
        void *sc = dlopen("/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration", RTLD_NOW);
        if (sc) {
            void *sym = dlsym(sc, "CNCopyCurrentNetworkInfo");
            if (sym) {
                os_unfair_lock_lock(&self->_lock);
                if (![self.installedSymbols containsObject:kPXNativeSymbolCNCopyCurrentNetworkInfo]) {
                    MSHookFunction(sym, (void *)PXCoord_CNCopyCurrentNetworkInfo, (void **)&g_orig_CNCopyCurrentNetworkInfo);
                    [self _markInstalled:kPXNativeSymbolCNCopyCurrentNetworkInfo original:(void *)g_orig_CNCopyCurrentNetworkInfo];
                }
                os_unfair_lock_unlock(&self->_lock);
            }
        }

        PXLog(@"[PXNativeHook] installOwnedSymbolsIfNeeded complete. diagnostics=%@", [self diagnostics]);
    });
}

- (BOOL)isSymbolInstalled:(NSString *)symbolName {
    os_unfair_lock_lock(&_lock);
    BOOL yes = [self.installedSymbols containsObject:symbolName];
    os_unfair_lock_unlock(&_lock);
    return yes;
}

- (void *)originalForSymbol:(NSString *)symbolName {
    if (!symbolName.length) return NULL;
    os_unfair_lock_lock(&_lock);
    NSValue *v = self.originalPointers[symbolName];
    void *p = v ? v.pointerValue : NULL;
    os_unfair_lock_unlock(&_lock);
    return p;
}

- (NSDictionary *)diagnostics {
    os_unfair_lock_lock(&_lock);
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    out[@"owner"] = @"PXNativeHookCoordinator";
    NSMutableDictionary *symbols = [NSMutableDictionary dictionary];
    for (NSString *sym in self.providersBySymbol) {
        NSArray *list = self.providersBySymbol[sym];
        NSMutableArray *ids = [NSMutableArray array];
        for (PXNativeHookProvider *p in list) {
            [ids addObject:@{@"id": p.providerID ?: @"", @"priority": @(p.priority), @"hasPre": @(p.preBlock != nil), @"hasPost": @(p.postBlock != nil)}];
        }
        symbols[sym] = @{
            @"installed": @([self.installedSymbols containsObject:sym]),
            @"installCount": self.installCounts[sym] ?: @0,
            @"originalPresent": @(self.originalPointers[sym] != nil),
            @"providers": ids
        };
    }
    // Also include installed symbols with no providers yet
    for (NSString *sym in self.installedSymbols) {
        if (!symbols[sym]) {
            symbols[sym] = @{
                @"installed": @YES,
                @"installCount": self.installCounts[sym] ?: @1,
                @"originalPresent": @(self.originalPointers[sym] != nil),
                @"providers": @[]
            };
        }
    }
    out[@"symbols"] = symbols;
    os_unfair_lock_unlock(&_lock);
    return out;
}

@end
