#import "PXRuntimeSnapshot.h"
// PXNativeHookCoordinator.m
// Single owner of MSHookFunction for multi-module native symbols.

#import "PXNativeHookCoordinator.h"
#import "TLinkIOSLogging.h"
#import <dlfcn.h>
#import <os/lock.h>
#import <string.h>
#import <uuid/uuid.h>

// Substrate
extern void MSHookFunction(void *symbol, void *replace, void **result);

NSString * const kPXNativeSymbolSysctl = @"sysctl";
NSString * const kPXNativeSymbolSysctlByname = @"sysctlbyname";
NSString * const kPXNativeSymbolSysctlNameToMIB = @"sysctlnametomib";
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

// Publish complete immutable collections; never mutate a published provider.
@interface PXNativeProviderState : NSObject
@property (nonatomic, copy) NSDictionary<NSString *, NSArray<PXNativeHookProvider *> *> *providers;
@property (nonatomic, copy) NSSet<NSString *> *providerIDs;
@end
@implementation PXNativeProviderState
@end
static __thread BOOL gPXPreparingNativeProvider;

@interface PXNativeHookCoordinator () {
    os_unfair_lock _lock; // Installation metadata is independent of hot readers.
    os_unfair_lock _registryLock;
    PXNativeProviderState *_providerState;
}
@property (nonatomic, strong) NSMutableSet<NSString *> *installedSymbols;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *installCounts;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSValue *> *originalPointers;
@end

@implementation PXNativeHookCoordinator

#pragma mark - Original function pointers (owned solely by coordinator)

static int (*g_orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t) = NULL;
static int (*g_orig_sysctlbyname)(const char *, void *, size_t *, void *, size_t) = NULL;
static int (*g_orig_sysctlnametomib)(const char *, int *, size_t *) = NULL;
static int (*g_orig_gethostname)(char *, size_t) = NULL;
static __thread BOOL g_inside_sysctlnametomib = NO;
static int (*g_orig_getifaddrs)(struct ifaddrs **) = NULL;
static CFTypeRef (*g_orig_IORegistryEntryCreateCFProperty)(io_registry_entry_t, CFStringRef, CFAllocatorRef, IOOptionBits) = NULL;
static IOReturn (*g_orig_IORegistryEntryCreateCFProperties)(io_registry_entry_t, CFMutableDictionaryRef *, CFAllocatorRef, IOOptionBits) = NULL;
static CFTypeRef (*g_orig_IORegistryEntrySearchCFProperty)(io_registry_entry_t, const io_name_t, CFStringRef, CFAllocatorRef, IOOptionBits) = NULL;
static CFDictionaryRef (*g_orig_CFCopySystemVersionDictionary)(void) = NULL;
static int (*g_orig_statfs)(const char *, struct statfs *) = NULL;
static int (*g_orig_statfs64)(const char *, PXStatfs64Buf *) = NULL;
static int (*g_orig_getfsstat)(struct statfs *, int, int) = NULL;
static int (*g_orig_getfsstat64)(PXStatfs64Buf *, int, int) = NULL;
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
        _registryLock = OS_UNFAIR_LOCK_INIT;
        _providerState = [PXNativeProviderState new];
        _providerState.providers = @{};
        _providerState.providerIDs = [NSSet set];
        _installedSymbols = [NSMutableSet set];
        _installCounts = [NSMutableDictionary dictionary];
        _originalPointers = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Registration

// Only owned-pointer capture/publication happens under the registry lock.
// String/block copies, sorting and retired-object destruction happen outside it.
- (PXNativeProviderState *)_captureProviderState {
    PXNativeProviderState *state = nil;
    os_unfair_lock_lock(&_registryLock);
    @try { state = _providerState; }
    @finally { os_unfair_lock_unlock(&_registryLock); }
    return state;
}

- (BOOL)registerProviderID:(NSString *)providerID
                symbolName:(NSString *)symbolName
                  priority:(NSInteger)priority
                  preBlock:(id)preBlock
                 postBlock:(id)postBlock {
    __attribute__((objc_precise_lifetime)) PXNativeHookCoordinator *owner = self;
    NSString *frozenID = nil, *frozenSymbol = nil;
    PXNativeHookProvider *provider = nil;
    PXNativeProviderState *basis = nil, *candidate = nil, *retired = nil;
    NSMutableDictionary *lists = nil;
    NSMutableArray *list = nil;
    NSMutableSet *ids = nil;
    BOOL previous = gPXPreparingNativeProvider;
    @try {
        // Foreign string/copy methods can call back into registration.
        if (previous) return NO;
        gPXPreparingNativeProvider = YES;
        if (![providerID isKindOfClass:NSString.class] || ![symbolName isKindOfClass:NSString.class] ||
            !providerID.length || !symbolName.length || (!preBlock && !postBlock)) return NO;
        frozenID = [[NSString alloc] initWithString:providerID];
        frozenSymbol = [[NSString alloc] initWithString:symbolName];
        if (!frozenID.length || !frozenSymbol.length) return NO;
        provider = [PXNativeHookProvider new];
        provider.providerID = frozenID; provider.symbolName = frozenSymbol; provider.priority = priority;
        provider.preBlock = preBlock; provider.postBlock = postBlock;
        for (;;) {
            basis = [self _captureProviderState];
            if ([basis.providerIDs containsObject:frozenID]) {
                PXLog(@"[PXNativeHook] ❌ Rejected duplicate provider ID: %@", frozenID);
                return NO;
            }
            lists = [basis.providers mutableCopy];
            list = [lists[frozenSymbol] mutableCopy] ?: [NSMutableArray array];
            [list addObject:provider];
            [list sortUsingComparator:^NSComparisonResult(PXNativeHookProvider *a, PXNativeHookProvider *b) {
                if (a.priority < b.priority) return NSOrderedAscending;
                if (a.priority > b.priority) return NSOrderedDescending;
                return [a.providerID compare:b.providerID];
            }];
            lists[frozenSymbol] = [list copy];
            ids = [basis.providerIDs mutableCopy]; [ids addObject:frozenID];
            candidate = [PXNativeProviderState new];
            candidate.providers = lists; candidate.providerIDs = ids;
            BOOL published = NO;
            os_unfair_lock_lock(&_registryLock);
            @try {
                if (_providerState == basis) {
                    retired = _providerState; _providerState = candidate; published = YES;
                }
            } @finally { os_unfair_lock_unlock(&_registryLock); }
            retired = nil; candidate = nil; basis = nil; lists = nil; list = nil; ids = nil;
            if (published) {
                PXLog(@"[PXNativeHook] ✅ Registered provider %@ for %@ priority=%ld", frozenID, frozenSymbol, (long)priority);
                return YES;
            }
        }
    } @finally {
        gPXPreparingNativeProvider = previous;
        providerID = nil; symbolName = nil; preBlock = nil; postBlock = nil;
        frozenID = nil; frozenSymbol = nil; provider = nil;
        basis = nil; candidate = nil; retired = nil; lists = nil; list = nil; ids = nil;
        owner = nil;
    }
}

- (NSArray<PXNativeHookProvider *> *)_providersCopyForSymbol:(NSString *)symbol {
    PXNativeProviderState *state = nil;
    NSArray *list = nil;
    @try {
        state = [self _captureProviderState];
        list = state.providers[symbol] ?: @[];
        return list; // Retained immutable list, no per-dispatch array copy.
    } @finally { symbol = nil; state = nil; list = nil; }
}

#define PX_REG_TYPED(name, symbolConst, preT, postT) \
- (BOOL)name:(NSString *)providerID priority:(NSInteger)priority pre:(preT)pre post:(postT)post { \
    @try { return [self registerProviderID:providerID symbolName:symbolConst priority:priority preBlock:pre postBlock:post]; } \
    @finally { providerID = nil; pre = nil; post = nil; } \
}

PX_REG_TYPED(registerSysctlProvider, kPXNativeSymbolSysctl, PXSysctlPreBlock, PXSysctlPostBlock)
PX_REG_TYPED(registerSysctlBynameProvider, kPXNativeSymbolSysctlByname, PXSysctlBynamePreBlock, PXSysctlBynamePostBlock)
PX_REG_TYPED(registerSysctlNameToMIBProvider, kPXNativeSymbolSysctlNameToMIB, PXSysctlNameToMIBPreBlock, PXSysctlNameToMIBPostBlock)
PX_REG_TYPED(registerGethostnameProvider, kPXNativeSymbolGethostname, PXGethostnamePreBlock, PXGethostnamePostBlock)
PX_REG_TYPED(registerGetifaddrsProvider, kPXNativeSymbolGetifaddrs, PXGetifaddrsPreBlock, PXGetifaddrsPostBlock)
PX_REG_TYPED(registerIORegistryCreateCFPropertyProvider, kPXNativeSymbolIORegistryEntryCreateCFProperty, PXIORegCreateCFPropertyPreBlock, PXIORegCreateCFPropertyPostBlock)
PX_REG_TYPED(registerIORegistryCreateCFPropertiesProvider, kPXNativeSymbolIORegistryEntryCreateCFProperties, PXIORegCreateCFPropertiesPreBlock, PXIORegCreateCFPropertiesPostBlock)
PX_REG_TYPED(registerIORegistrySearchCFPropertyProvider, kPXNativeSymbolIORegistryEntrySearchCFProperty, PXIORegSearchCFPropertyPreBlock, PXIORegSearchCFPropertyPostBlock)
PX_REG_TYPED(registerCFCopySystemVersionDictionaryProvider, kPXNativeSymbolCFCopySystemVersionDictionary, PXCFCopySystemVersionDictPreBlock, PXCFCopySystemVersionDictPostBlock)
PX_REG_TYPED(registerCNCopyCurrentNetworkInfoProvider, kPXNativeSymbolCNCopyCurrentNetworkInfo, PXCNCopyNetworkInfoPreBlock, PXCNCopyNetworkInfoPostBlock)

- (BOOL)registerStatfsProvider:(NSString *)providerID priority:(NSInteger)priority post:(PXStatfsPostBlock)post {
    @try { return [self registerProviderID:providerID symbolName:kPXNativeSymbolStatfs priority:priority preBlock:nil postBlock:post]; }
    @finally { providerID = nil; post = nil; }
}
- (BOOL)registerStatfs64Provider:(NSString *)providerID priority:(NSInteger)priority post:(PXStatfs64PostBlock)post {
    @try { return [self registerProviderID:providerID symbolName:kPXNativeSymbolStatfs64 priority:priority preBlock:nil postBlock:post]; }
    @finally { providerID = nil; post = nil; }
}
- (BOOL)registerGetfsstatProvider:(NSString *)providerID priority:(NSInteger)priority post:(PXGetfsstatPostBlock)post {
    @try { return [self registerProviderID:providerID symbolName:kPXNativeSymbolGetfsstat priority:priority preBlock:nil postBlock:post]; }
    @finally { providerID = nil; post = nil; }
}
- (BOOL)registerGetfsstat64Provider:(NSString *)providerID priority:(NSInteger)priority post:(PXGetfsstat64PostBlock)post {
    @try { return [self registerProviderID:providerID symbolName:kPXNativeSymbolGetfsstat64 priority:priority preBlock:nil postBlock:post]; }
    @finally { providerID = nil; post = nil; }
}
- (BOOL)registerGethostuuidProvider:(NSString *)providerID priority:(NSInteger)priority pre:(PXGethostuuidPreBlock)pre {
    @try { return [self registerProviderID:providerID symbolName:kPXNativeSymbolGethostuuid priority:priority preBlock:pre postBlock:nil]; }
    @finally { providerID = nil; pre = nil; }
}

#pragma mark - Dispatch helpers

static int PXCoord_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    PX_RUNTIME_READ_OPERATION;
    PXNativeHookCoordinator *coord = nil;
    NSArray<PXNativeHookProvider *> *providers = nil;
    @try {
        coord = [PXNativeHookCoordinator sharedCoordinator];
        providers = [coord _providersCopyForSymbol:kPXNativeSymbolSysctl];
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXSysctlPreBlock __unsafe_unretained pre = p.preBlock;
            if (!pre) continue;
            int result = 0;
            if (pre(name, namelen, oldp, oldlenp, newp, newlen, &result)) {
                return result;
            }
        }
        int result = g_orig_sysctl ? g_orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen) : -1;
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXSysctlPostBlock __unsafe_unretained post = p.postBlock;
            if (post) post(name, namelen, oldp, oldlenp, newp, newlen, &result);
        }
        return result;
    } @finally { providers = nil; coord = nil; }
}

static int PXCoord_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    PX_RUNTIME_READ_OPERATION;
    PXNativeHookCoordinator *coord = nil;
    NSArray<PXNativeHookProvider *> *providers = nil;
    @try {
        coord = [PXNativeHookCoordinator sharedCoordinator];
        providers = [coord _providersCopyForSymbol:kPXNativeSymbolSysctlByname];
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXSysctlBynamePreBlock __unsafe_unretained pre = p.preBlock;
            if (!pre) continue;
            int result = 0;
            if (pre(name, oldp, oldlenp, newp, newlen, &result)) {
                return result;
            }
        }
        int result = g_orig_sysctlbyname ? g_orig_sysctlbyname(name, oldp, oldlenp, newp, newlen) : -1;
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXSysctlBynamePostBlock __unsafe_unretained post = p.postBlock;
            if (post) post(name, oldp, oldlenp, newp, newlen, &result);
        }
        return result;
    } @finally { providers = nil; coord = nil; }
}

static int PXCoord_sysctlnametomib(const char *name, int *mib, size_t *namelen) {
    PX_RUNTIME_READ_OPERATION;
    BOOL previous = g_inside_sysctlnametomib;
    if (previous) return g_orig_sysctlnametomib ? g_orig_sysctlnametomib(name, mib, namelen) : -1;
    PXNativeHookCoordinator *coord = nil;
    NSArray<PXNativeHookProvider *> *providers = nil;
    int result = -1;
    BOOL handled = NO;
    g_inside_sysctlnametomib = YES;
    @try {
        @try {
            coord = [PXNativeHookCoordinator sharedCoordinator];
            providers = [coord _providersCopyForSymbol:kPXNativeSymbolSysctlNameToMIB];
            for (NSUInteger index = 0, count = providers.count; index < count; index++) {
                PXNativeHookProvider * __unsafe_unretained p = providers[index];
                PXSysctlNameToMIBPreBlock __unsafe_unretained pre = p.preBlock;
                if (pre && pre(name, mib, namelen, &result)) { handled = YES; break; }
            }
        } @catch (__unused NSException *exception) {
            // Preserve pre-failure native fallback; skip later posts as before.
            providers = nil;
        }
        if (!handled) {
            result = g_orig_sysctlnametomib ? g_orig_sysctlnametomib(name, mib, namelen) : -1;
            @try {
                for (NSUInteger index = 0, count = providers.count; index < count; index++) {
                    PXNativeHookProvider * __unsafe_unretained p = providers[index];
                    PXSysctlNameToMIBPostBlock __unsafe_unretained post = p.postBlock;
                    if (post) post(name, mib, namelen, &result);
                }
            } @catch (__unused NSException *exception) { }
        }
        return result;
    } @finally { g_inside_sysctlnametomib = previous; providers = nil; coord = nil; }
}

static int PXCoord_gethostname(char *name, size_t namelen) {
    PX_RUNTIME_READ_OPERATION;
    PXNativeHookCoordinator *coord = nil;
    NSArray<PXNativeHookProvider *> *providers = nil;
    @try {
        coord = [PXNativeHookCoordinator sharedCoordinator];
        providers = [coord _providersCopyForSymbol:kPXNativeSymbolGethostname];
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXGethostnamePreBlock __unsafe_unretained pre = p.preBlock;
            if (!pre) continue;
            int result = 0;
            if (pre(name, namelen, &result)) {
                return result;
            }
        }
        int result = g_orig_gethostname ? g_orig_gethostname(name, namelen) : -1;
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXGethostnamePostBlock __unsafe_unretained post = p.postBlock;
            if (post) post(name, namelen, &result);
        }
        return result;
    } @finally { providers = nil; coord = nil; }
}

static int PXCoord_getifaddrs(struct ifaddrs **ifap) {
    PX_RUNTIME_READ_OPERATION;
    PXNativeHookCoordinator *coord = nil;
    NSArray<PXNativeHookProvider *> *providers = nil;
    @try {
        coord = [PXNativeHookCoordinator sharedCoordinator];
        providers = [coord _providersCopyForSymbol:kPXNativeSymbolGetifaddrs];
        int result = 0;
        BOOL handled = NO;
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXGetifaddrsPreBlock __unsafe_unretained pre = p.preBlock;
            if (!pre) continue;
            if (pre(ifap, &result)) {
                handled = YES;
                break;
            }
        }
        if (!handled) {
            result = g_orig_getifaddrs ? g_orig_getifaddrs(ifap) : -1;
        }
        // Post providers are composable sanitizers and must run even when a legacy
        // pre-provider supplied the base list.
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXGetifaddrsPostBlock __unsafe_unretained post = p.postBlock;
            if (post) post(ifap, &result);
        }
        return result;
    } @finally { providers = nil; coord = nil; }
}

static CFTypeRef PXCoord_IORegistryEntryCreateCFProperty(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options) {
    PX_RUNTIME_READ_OPERATION;
    PXNativeHookCoordinator *coord = nil;
    NSArray<PXNativeHookProvider *> *providers = nil;
    @try {
        coord = [PXNativeHookCoordinator sharedCoordinator];
        providers = [coord _providersCopyForSymbol:kPXNativeSymbolIORegistryEntryCreateCFProperty];
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXIORegCreateCFPropertyPreBlock __unsafe_unretained pre = p.preBlock;
            if (!pre) continue;
            CFTypeRef result = NULL;
            if (pre(entry, key, allocator, options, &result)) {
                return result;
            }
        }
        CFTypeRef result = g_orig_IORegistryEntryCreateCFProperty ? g_orig_IORegistryEntryCreateCFProperty(entry, key, allocator, options) : NULL;
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXIORegCreateCFPropertyPostBlock __unsafe_unretained post = p.postBlock;
            if (post) post(entry, key, allocator, options, &result);
        }
        return result;
    } @finally { providers = nil; coord = nil; }
}

static IOReturn PXCoord_IORegistryEntryCreateCFProperties(io_registry_entry_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, IOOptionBits options) {
    PX_RUNTIME_READ_OPERATION;
    PXNativeHookCoordinator *coord = nil;
    NSArray<PXNativeHookProvider *> *providers = nil;
    @try {
        coord = [PXNativeHookCoordinator sharedCoordinator];
        providers = [coord _providersCopyForSymbol:kPXNativeSymbolIORegistryEntryCreateCFProperties];
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXIORegCreateCFPropertiesPreBlock __unsafe_unretained pre = p.preBlock;
            if (!pre) continue;
            IOReturn result = kIOReturnSuccess;
            if (pre(entry, properties, allocator, options, &result)) {
                return result;
            }
        }
        IOReturn result = g_orig_IORegistryEntryCreateCFProperties ? g_orig_IORegistryEntryCreateCFProperties(entry, properties, allocator, options) : kIOReturnError;
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXIORegCreateCFPropertiesPostBlock __unsafe_unretained post = p.postBlock;
            if (post) post(entry, properties, allocator, options, &result);
        }
        return result;
    } @finally { providers = nil; coord = nil; }
}

static CFTypeRef PXCoord_IORegistryEntrySearchCFProperty(io_registry_entry_t entry, const io_name_t plane, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options) {
    PX_RUNTIME_READ_OPERATION;
    PXNativeHookCoordinator *coord = nil;
    NSArray<PXNativeHookProvider *> *providers = nil;
    @try {
        coord = [PXNativeHookCoordinator sharedCoordinator];
        providers = [coord _providersCopyForSymbol:kPXNativeSymbolIORegistryEntrySearchCFProperty];
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXIORegSearchCFPropertyPreBlock __unsafe_unretained pre = p.preBlock;
            if (!pre) continue;
            CFTypeRef result = NULL;
            if (pre(entry, plane, key, allocator, options, &result)) {
                return result;
            }
        }
        CFTypeRef result = g_orig_IORegistryEntrySearchCFProperty ? g_orig_IORegistryEntrySearchCFProperty(entry, plane, key, allocator, options) : NULL;
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXIORegSearchCFPropertyPostBlock __unsafe_unretained post = p.postBlock;
            if (post) post(entry, plane, key, allocator, options, &result);
        }
        return result;
    } @finally { providers = nil; coord = nil; }
}

static CFDictionaryRef PXCoord_CFCopySystemVersionDictionary(void) {
    PX_RUNTIME_READ_OPERATION;
    PXNativeHookCoordinator *coord = nil;
    NSArray<PXNativeHookProvider *> *providers = nil;
    @try {
        coord = [PXNativeHookCoordinator sharedCoordinator];
        providers = [coord _providersCopyForSymbol:kPXNativeSymbolCFCopySystemVersionDictionary];
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXCFCopySystemVersionDictPreBlock __unsafe_unretained pre = p.preBlock;
            if (!pre) continue;
            CFDictionaryRef result = NULL;
            if (pre(&result)) {
                return result;
            }
        }
        CFDictionaryRef result = g_orig_CFCopySystemVersionDictionary ? g_orig_CFCopySystemVersionDictionary() : NULL;
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXCFCopySystemVersionDictPostBlock __unsafe_unretained post = p.postBlock;
            if (post) post(&result);
        }
        return result;
    } @finally { providers = nil; coord = nil; }
}

static int PXCoord_statfs(const char *path, struct statfs *buf) {
    PX_RUNTIME_READ_OPERATION;
    PXNativeHookCoordinator *coord = nil;
    NSArray<PXNativeHookProvider *> *providers = nil;
    @try {
        int result = g_orig_statfs ? g_orig_statfs(path, buf) : -1;
        coord = [PXNativeHookCoordinator sharedCoordinator];
        providers = [coord _providersCopyForSymbol:kPXNativeSymbolStatfs];
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXStatfsPostBlock __unsafe_unretained post = p.postBlock;
            if (post) post(path, buf, &result);
        }
        return result;
    } @finally { providers = nil; coord = nil; }
}

static int PXCoord_statfs64(const char *path, PXStatfs64Buf *buf) {
    PX_RUNTIME_READ_OPERATION;
    PXNativeHookCoordinator *coord = nil;
    NSArray<PXNativeHookProvider *> *providers = nil;
    @try {
        int result = g_orig_statfs64 ? g_orig_statfs64(path, buf) : -1;
        coord = [PXNativeHookCoordinator sharedCoordinator];
        providers = [coord _providersCopyForSymbol:kPXNativeSymbolStatfs64];
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXStatfs64PostBlock __unsafe_unretained post = p.postBlock;
            if (post) post(path, buf, &result);
        }
        return result;
    } @finally { providers = nil; coord = nil; }
}

static int PXCoord_getfsstat(struct statfs *buf, int bufsize, int flags) {
    PX_RUNTIME_READ_OPERATION;
    PXNativeHookCoordinator *coord = nil;
    NSArray<PXNativeHookProvider *> *providers = nil;
    @try {
        int result = g_orig_getfsstat ? g_orig_getfsstat(buf, bufsize, flags) : -1;
        coord = [PXNativeHookCoordinator sharedCoordinator];
        providers = [coord _providersCopyForSymbol:kPXNativeSymbolGetfsstat];
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXGetfsstatPostBlock __unsafe_unretained post = p.postBlock;
            if (post) post(buf, bufsize, flags, &result);
        }
        return result;
    } @finally { providers = nil; coord = nil; }
}

static int PXCoord_getfsstat64(PXStatfs64Buf *buf, int bufsize, int flags) {
    PX_RUNTIME_READ_OPERATION;
    PXNativeHookCoordinator *coord = nil;
    NSArray<PXNativeHookProvider *> *providers = nil;
    @try {
        int result = g_orig_getfsstat64 ? g_orig_getfsstat64(buf, bufsize, flags) : -1;
        coord = [PXNativeHookCoordinator sharedCoordinator];
        providers = [coord _providersCopyForSymbol:kPXNativeSymbolGetfsstat64];
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXGetfsstat64PostBlock __unsafe_unretained post = p.postBlock;
            if (post) post(buf, bufsize, flags, &result);
        }
        return result;
    } @finally { providers = nil; coord = nil; }
}

static CFDictionaryRef PXCoord_CNCopyCurrentNetworkInfo(CFStringRef interfaceName) {
    PX_RUNTIME_READ_OPERATION;
    PXNativeHookCoordinator *coord = nil;
    NSArray<PXNativeHookProvider *> *providers = nil;
    @try {
        coord = [PXNativeHookCoordinator sharedCoordinator];
        providers = [coord _providersCopyForSymbol:kPXNativeSymbolCNCopyCurrentNetworkInfo];
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXCNCopyNetworkInfoPreBlock __unsafe_unretained pre = p.preBlock;
            if (!pre) continue;
            CFDictionaryRef result = NULL;
            if (pre(interfaceName, &result)) {
                return result;
            }
        }
        CFDictionaryRef result = g_orig_CNCopyCurrentNetworkInfo ? g_orig_CNCopyCurrentNetworkInfo(interfaceName) : NULL;
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXCNCopyNetworkInfoPostBlock __unsafe_unretained post = p.postBlock;
            if (post) post(interfaceName, &result);
        }
        return result;
    } @finally { providers = nil; coord = nil; }
}

static int PXCoord_gethostuuid(uuid_t id, const struct timespec *wait) {
    PX_RUNTIME_READ_OPERATION;
    PXNativeHookCoordinator *coord = nil;
    NSArray<PXNativeHookProvider *> *providers = nil;
    @try {
        coord = [PXNativeHookCoordinator sharedCoordinator];
        providers = [coord _providersCopyForSymbol:kPXNativeSymbolGethostuuid];
        for (NSUInteger index = 0, count = providers.count; index < count; index++) {
            PXNativeHookProvider * __unsafe_unretained p = providers[index];
            PXGethostuuidPreBlock __unsafe_unretained pre = p.preBlock;
            if (!pre) continue;
            int result = 0;
            if (pre(id, wait, &result)) {
                return result;
            }
        }
        return g_orig_gethostuuid ? g_orig_gethostuuid(id, wait) : -1;
    } @finally { providers = nil; coord = nil; }
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
        [self _installSymbol:kPXNativeSymbolSysctlNameToMIB replace:(void *)PXCoord_sysctlnametomib originalOut:(void **)&g_orig_sysctlnametomib];
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
    PXNativeProviderState *state = nil;
    NSSet *installed = nil;
    NSDictionary *counts = nil, *originals = nil;
    NSMutableDictionary *out = nil, *symbols = nil;
    NSMutableArray *ids = nil;
    @try {
        state = [self _captureProviderState];
        os_unfair_lock_lock(&_lock);
        @try { installed = [_installedSymbols copy]; counts = [_installCounts copy]; originals = [_originalPointers copy]; }
        @finally { os_unfair_lock_unlock(&_lock); }
        out = [NSMutableDictionary dictionary]; out[@"owner"] = @"PXNativeHookCoordinator";
        symbols = [NSMutableDictionary dictionary];
        for (NSString *sym in state.providers) {
            ids = [NSMutableArray array];
            for (PXNativeHookProvider *p in state.providers[sym]) {
                [ids addObject:@{@"id": p.providerID ?: @"", @"priority": @(p.priority), @"hasPre": @(p.preBlock != nil), @"hasPost": @(p.postBlock != nil)}];
            }
            symbols[sym] = @{@"installed": @([installed containsObject:sym]), @"installCount": counts[sym] ?: @0,
                @"originalPresent": @(originals[sym] != nil), @"providers": ids};
        }
        for (NSString *sym in installed) {
            if (!symbols[sym]) symbols[sym] = @{@"installed": @YES, @"installCount": counts[sym] ?: @1,
                @"originalPresent": @(originals[sym] != nil), @"providers": @[]};
        }
        out[@"symbols"] = symbols;
        return out;
    } @finally { state = nil; installed = nil; counts = nil; originals = nil; out = nil; symbols = nil; ids = nil; }
}

@end
