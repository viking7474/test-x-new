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
static __thread BOOL gPXInsideNativeInstallPass;
static __thread BOOL gPXReadingNativeSymbol;

// Installation metadata is published as a complete immutable packet. Native
// patching itself is irreversible and remains serialized by the process once.
@interface PXNativeInstallMetadata : NSObject
@property (nonatomic, copy) NSSet<NSString *> *installed;
@property (nonatomic, copy) NSDictionary<NSString *, NSNumber *> *counts;
@property (nonatomic, copy) NSDictionary<NSString *, NSValue *> *originals;
@end
@implementation PXNativeInstallMetadata
@end

static NSString *PXNativeCanonicalSymbol(NSString *symbol) {
    NSString *frozen = nil;
    BOOL previous = gPXReadingNativeSymbol;
    @try {
        if (previous) return nil;
        gPXReadingNativeSymbol = YES;
        // Internal callers use these constants, including Storage's hot getter.
        // Pointer checks avoid copying/validating strings on that existing path.
        if (symbol == kPXNativeSymbolSysctl || symbol == kPXNativeSymbolSysctlByname ||
            symbol == kPXNativeSymbolSysctlNameToMIB || symbol == kPXNativeSymbolGethostname ||
            symbol == kPXNativeSymbolGetifaddrs || symbol == kPXNativeSymbolGethostuuid ||
            symbol == kPXNativeSymbolStatfs || symbol == kPXNativeSymbolStatfs64 ||
            symbol == kPXNativeSymbolGetfsstat || symbol == kPXNativeSymbolGetfsstat64 ||
            symbol == kPXNativeSymbolIORegistryEntryCreateCFProperty || symbol == kPXNativeSymbolIORegistryEntryCreateCFProperties ||
            symbol == kPXNativeSymbolIORegistryEntrySearchCFProperty || symbol == kPXNativeSymbolCFCopySystemVersionDictionary ||
            symbol == kPXNativeSymbolCNCopyCurrentNetworkInfo) return symbol;
        if (![symbol isKindOfClass:NSString.class] || !symbol.length) return nil;
        frozen = [[NSString alloc] initWithString:symbol];
        return frozen.length ? frozen : nil;
    } @catch (__unused NSException *exception) { return nil; }
    @finally { gPXReadingNativeSymbol = previous; symbol = nil; frozen = nil; }
}

// The five known images must stay loaded while installed trampolines use them.
// Cache one loader reference per image, including a failed first acquisition;
// do not reopen the same libSystem image for each missing base symbol.
static void *PXNativeInstallImage(NSUInteger index) {
    static const char *paths[] = {
        "/usr/lib/libSystem.B.dylib", "/usr/lib/system/libsystem_c.dylib",
        "/System/Library/Frameworks/IOKit.framework/IOKit",
        "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation",
        "/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration"
    };
    static void *handles[5];
    static dispatch_once_t tokens[5];
    if (index >= 5) return NULL;
    dispatch_once(&tokens[index], ^{
        @try {
            if (index < 2) handles[index] = dlopen(paths[index], RTLD_NOLOAD | RTLD_LAZY);
            if (!handles[index]) handles[index] = dlopen(paths[index], RTLD_NOW);
        } @catch (__unused NSException *exception) { handles[index] = NULL; }
    });
    return handles[index];
}

static void *PXNativeResolveInstallSymbol(NSString *symbol) {
    void *handle = NULL, *address = NULL;
    @try {
        if ([symbol isEqualToString:kPXNativeSymbolIORegistryEntryCreateCFProperty] ||
            [symbol isEqualToString:kPXNativeSymbolIORegistryEntryCreateCFProperties] ||
            [symbol isEqualToString:kPXNativeSymbolIORegistryEntrySearchCFProperty]) {
            handle = PXNativeInstallImage(2);
            return handle ? dlsym(handle, symbol.UTF8String) : NULL;
        }
        if ([symbol isEqualToString:kPXNativeSymbolCFCopySystemVersionDictionary]) {
            handle = PXNativeInstallImage(3);
            if (!handle) return NULL;
            address = dlsym(handle, "CFCopySystemVersionDictionary");
            return address ?: dlsym(handle, "_CFCopySystemVersionDictionary");
        }
        if ([symbol isEqualToString:kPXNativeSymbolCNCopyCurrentNetworkInfo]) {
            handle = PXNativeInstallImage(4);
            return handle ? dlsym(handle, symbol.UTF8String) : NULL;
        }
        address = dlsym(RTLD_DEFAULT, symbol.UTF8String);
        if (address) return address;
        for (NSUInteger index = 0; index < 2; index++) {
            handle = PXNativeInstallImage(index);
            if (handle) { address = dlsym(handle, symbol.UTF8String); if (address) return address; }
        }
        return NULL;
    } @finally { symbol = nil; }
}

// Logging is optional; it cannot interrupt patch bookkeeping or poison once.
static void PXNativeInstallReport(NSString *symbol, NSString *reason, void *original) {
    @try { PXLog(@"[PXNativeHook] %@: %@ (original=%p)", symbol, reason, original); }
    @catch (__unused NSException *exception) { }
    @finally { symbol = nil; reason = nil; }
}


@interface PXNativeHookCoordinator () {
    os_unfair_lock _lock; // Immutable installation-metadata pointer only.
    os_unfair_lock _registryLock;
    PXNativeProviderState *_providerState;
    PXNativeInstallMetadata *_installationMetadata;
}
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
        _installationMetadata = [PXNativeInstallMetadata new];
        _installationMetadata.installed = [NSSet set];
        _installationMetadata.counts = @{};
        _installationMetadata.originals = @{};
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

- (PXNativeInstallMetadata *)_captureInstallationMetadata {
    PXNativeInstallMetadata *metadata = nil;
    os_unfair_lock_lock(&_lock);
    @try { metadata = _installationMetadata; }
    @finally { os_unfair_lock_unlock(&_lock); }
    return metadata;
}

- (void)_markInstalled:(NSString *)symbol original:(void *)orig {
    PXNativeInstallMetadata *basis = nil, *candidate = nil, *retired = nil;
    NSMutableSet *installed = nil;
    NSMutableDictionary *counts = nil, *originals = nil;
    @try {
        for (;;) {
            basis = [self _captureInstallationMetadata];
            if ([basis.installed containsObject:symbol]) return;
            installed = [basis.installed mutableCopy]; [installed addObject:symbol];
            counts = [basis.counts mutableCopy]; counts[symbol] = @1;
            originals = [basis.originals mutableCopy];
            if (orig) originals[symbol] = [NSValue valueWithPointer:orig];
            candidate = [PXNativeInstallMetadata new];
            candidate.installed = installed; candidate.counts = counts; candidate.originals = originals;
            BOOL published = NO;
            os_unfair_lock_lock(&_lock);
            @try {
                if (_installationMetadata == basis) {
                    retired = _installationMetadata; _installationMetadata = candidate; published = YES;
                }
            } @finally { os_unfair_lock_unlock(&_lock); }
            retired = nil; basis = nil; candidate = nil; installed = nil; counts = nil; originals = nil;
            if (published) return;
        }
    } @finally { symbol = nil; basis = nil; candidate = nil; retired = nil; installed = nil; counts = nil; originals = nil; }
}

// Called only by the serialized install pass. A failed/throwing hook call may
// have patched code already; never infer rollback or retry from missing metadata.
- (BOOL)_installSymbol:(NSString *)symbolName replace:(void *)replace originalOut:(void **)originalOut {
    __attribute__((objc_precise_lifetime)) PXNativeHookCoordinator *owner = self;
    NSString *symbol = nil;
    PXNativeInstallMetadata *metadata = nil;
    @try {
        symbol = PXNativeCanonicalSymbol(symbolName);
        if (!symbol || !replace || !originalOut) return NO;
        metadata = [self _captureInstallationMetadata];
        if ([metadata.installed containsObject:symbol]) return YES;
        void *address = PXNativeResolveInstallSymbol(symbol);
        if (!address) { PXNativeInstallReport(symbol, @"Symbol not found; not installed", NULL); return NO; }
        // No coordinator lock spans loader, hook-library or logging callbacks.
        MSHookFunction(address, replace, originalOut);
        [self _markInstalled:symbol original:*originalOut];
        PXNativeInstallReport(symbol, @"Installed", *originalOut);
        return YES;
    } @catch (__unused NSException *exception) {
        PXNativeInstallReport(symbol ?: @"native symbol", @"Installation interrupted; no retry or rollback assumed", NULL);
        return NO;
    } @finally { symbolName = nil; symbol = nil; metadata = nil; owner = nil; }
}

- (void)installOwnedSymbolsIfNeeded {
    BOOL previous = gPXInsideNativeInstallPass;
    if (previous) return; // Same-thread loader/hook reentry must never wait on once.
    __attribute__((objc_precise_lifetime)) PXNativeHookCoordinator *owner = self;
    gPXInsideNativeInstallPass = YES;
    @try {
        // Do not consume once if the hook engine is not yet visible. A later
        // explicit constructor call may try again, without a timer/worker/wait.
        if (!dlsym(RTLD_DEFAULT, "MSHookFunction")) {
            PXNativeInstallReport(@"coordinator", @"MSHookFunction unavailable; pass not started", NULL);
            return;
        }
        static dispatch_once_t onceToken;
        // Native callbacks are synchronous; the literal construction finishes
        // before entering once and its body never lets optional exceptions escape.
        dispatch_block_t installation = nil;
        @try {
            { installation = ^{
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
                [self _installSymbol:kPXNativeSymbolIORegistryEntryCreateCFProperty replace:(void *)PXCoord_IORegistryEntryCreateCFProperty originalOut:(void **)&g_orig_IORegistryEntryCreateCFProperty];
                [self _installSymbol:kPXNativeSymbolIORegistryEntryCreateCFProperties replace:(void *)PXCoord_IORegistryEntryCreateCFProperties originalOut:(void **)&g_orig_IORegistryEntryCreateCFProperties];
                [self _installSymbol:kPXNativeSymbolIORegistryEntrySearchCFProperty replace:(void *)PXCoord_IORegistryEntrySearchCFProperty originalOut:(void **)&g_orig_IORegistryEntrySearchCFProperty];
                [self _installSymbol:kPXNativeSymbolCFCopySystemVersionDictionary replace:(void *)PXCoord_CFCopySystemVersionDictionary originalOut:(void **)&g_orig_CFCopySystemVersionDictionary];
                [self _installSymbol:kPXNativeSymbolCNCopyCurrentNetworkInfo replace:(void *)PXCoord_CNCopyCurrentNetworkInfo originalOut:(void **)&g_orig_CNCopyCurrentNetworkInfo];
                @try { PXLog(@"[PXNativeHook] installOwnedSymbolsIfNeeded complete. diagnostics=%@", [self diagnostics]); }
                @catch (__unused NSException *exception) { }
            }; }
            dispatch_once(&onceToken, installation);
        } @finally { installation = nil; }
    } @catch (__unused NSException *exception) {
        PXNativeInstallReport(@"coordinator", @"Installation preflight interrupted", NULL);
    } @finally { gPXInsideNativeInstallPass = previous; owner = nil; }
}

- (BOOL)isSymbolInstalled:(NSString *)symbolName {
    __attribute__((objc_precise_lifetime)) PXNativeHookCoordinator *owner = self;
    NSString *symbol = nil;
    PXNativeInstallMetadata *metadata = nil;
    @try {
        symbol = PXNativeCanonicalSymbol(symbolName);
        if (!symbol) return NO;
        metadata = [self _captureInstallationMetadata];
        return [metadata.installed containsObject:symbol];
    } @finally { symbolName = nil; symbol = nil; metadata = nil; owner = nil; }
}

- (void *)originalForSymbol:(NSString *)symbolName {
    __attribute__((objc_precise_lifetime)) PXNativeHookCoordinator *owner = self;
    NSString *symbol = nil;
    PXNativeInstallMetadata *metadata = nil;
    NSValue *value = nil;
    @try {
        symbol = PXNativeCanonicalSymbol(symbolName);
        if (!symbol) return NULL;
        metadata = [self _captureInstallationMetadata];
        value = metadata.originals[symbol];
        return value ? value.pointerValue : NULL;
    } @finally { symbolName = nil; symbol = nil; metadata = nil; value = nil; owner = nil; }
}

- (NSDictionary *)diagnostics {
    PXNativeProviderState *state = nil;
    PXNativeInstallMetadata *metadata = nil;
    NSSet *installed = nil;
    NSDictionary *counts = nil, *originals = nil;
    NSMutableDictionary *out = nil, *symbols = nil;
    NSMutableArray *ids = nil;
    @try {
        state = [self _captureProviderState];
        metadata = [self _captureInstallationMetadata];
        installed = metadata.installed; counts = metadata.counts; originals = metadata.originals;
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
    } @finally { state = nil; metadata = nil; installed = nil; counts = nil; originals = nil; out = nil; symbols = nil; ids = nil; }
}

@end
