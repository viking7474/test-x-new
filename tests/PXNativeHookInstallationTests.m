#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdatomic.h>
#include <stdio.h>
#include <string.h>
static void *PXFixtureDlopen(const char *path, int mode);
static void *PXFixtureDlsym(void *handle, const char *name);
// Only this TU's coordinator loader calls are substituted; Foundation/dyld are
// not interposed. The production coordinator body is compiled without rewriting.
#define dlopen PXFixtureDlopen
#define dlsym PXFixtureDlsym
#import "../TLinkIOSTweak/PXNativeHookCoordinator.m"
#undef dlopen
#undef dlsym

static atomic_ulong checks, failures;
static const char *scenario;
static PXNativeHookCoordinator *coordinator;
static atomic_bool engineVisible, permitMissing, blockFirst;
static atomic_uint hooks[15], opens[5], noLoads[2], probes, aliasReads;
static dispatch_semaphore_t enteredHook, releaseHook;
static const char *names[] = {
    "sysctl", "sysctlbyname", "sysctlnametomib", "gethostname", "getifaddrs", "gethostuuid",
    "statfs", "statfs64", "getfsstat", "getfsstat64", "IORegistryEntryCreateCFProperty",
    "IORegistryEntryCreateCFProperties", "IORegistryEntrySearchCFProperty",
    "CFCopySystemVersionDictionary", "CNCopyCurrentNetworkInfo"
};
#define CHECK(value, label) do { checks++; if (!(value)) { failures++; fprintf(stderr,"FAIL: %s\n",label); } } while (0)
static BOOL Case(const char *name) { return strcmp(scenario,name) == 0; }
static void Raise(void) { [NSException raise:@"fixture" format:@"installation fault"]; }
static void *Address(NSUInteger index) { return (void *)(uintptr_t)(0x10000 + index * 256); }
static void *Original(NSUInteger index) { return (void *)(uintptr_t)(0x20000 + index * 256); }
static void *Handle(NSUInteger index) { return (void *)(uintptr_t)(0x30000 + index * 256); }
static NSInteger Index(const char *name) {
    if (!strcmp(name,"_CFCopySystemVersionDictionary")) return 13;
    for (NSUInteger index = 0; index < 15; index++) if (!strcmp(name,names[index])) return (NSInteger)index;
    return -1;
}
static void Probe(void) {
    atomic_fetch_add(&probes,1);
    [coordinator installOwnedSymbolsIfNeeded];
    NSDictionary *diagnostic = [coordinator diagnostics];
    CHECK(([diagnostic[@"owner"] isEqual:@"PXNativeHookCoordinator"]), "callback can read diagnostics without installation lock");
    PXNativeInstallMetadata *metadata = [coordinator _captureInstallationMetadata];
    CHECK((metadata.installed.count == metadata.counts.count && metadata.originals.count <= metadata.counts.count), "callback observes a coherent installed/count/original packet");
    for (NSString *symbol in metadata.installed) {
        CHECK(([metadata.counts[symbol] unsignedIntegerValue] == 1 && [coordinator isSymbolInstalled:symbol] && [coordinator originalForSymbol:symbol] == [metadata.originals[symbol] pointerValue]), "published symbol getters match the captured metadata");
    }
}
static void *PXFixtureDlopen(const char *path, int mode) {
    NSUInteger index = 99;
    if (!strcmp(path,"/usr/lib/libSystem.B.dylib")) index = 0;
    else if (!strcmp(path,"/usr/lib/system/libsystem_c.dylib")) index = 1;
    else if (strstr(path,"IOKit.framework")) index = 2;
    else if (strstr(path,"CoreFoundation.framework")) index = 3;
    else if (strstr(path,"SystemConfiguration.framework")) index = 4;
    CHECK(index < 5,"loader uses only the five existing image paths");
    if (index >= 5) return NULL;
    Probe();
    if (index < 2 && (mode & RTLD_NOLOAD)) {
        atomic_fetch_add(&noLoads[index],1);
        CHECK((mode & RTLD_LAZY),"NOLOAD explicitly preserves legacy lazy binding");
        return NULL;
    }
    atomic_fetch_add(&opens[index],1);
    CHECK((mode & RTLD_NOW),"fallback/framework acquisition retains NOW binding");
    if (Case("loader-throws") && index == 2) Raise();
    return Handle(index);
}
static void *PXFixtureDlsym(void *handle, const char *name) {
    if (!strcmp(name,"MSHookFunction")) {
        // Preflight itself reenters before once; a missing engine must not consume it.
        [coordinator installOwnedSymbolsIfNeeded];
        return atomic_load(&engineVisible) ? (void *)MSHookFunction : NULL;
    }
    NSInteger index = Index(name);
    if (index < 0) return NULL;
    Probe();
    if (Case("lookup-throws") && index == 3) Raise();
    if (Case("missing-symbol") && index == 7 && !atomic_load(&permitMissing)) return NULL;
    // Force both existing system-library fallback paths for the ten base symbols.
    if (index < 10) {
        if (handle == RTLD_DEFAULT) return NULL;
        if (index == 3) return handle == Handle(1) ? Address((NSUInteger)index) : NULL;
        return handle == Handle(0) ? Address((NSUInteger)index) : NULL;
    }
    if (index < 13) return handle == Handle(2) ? Address((NSUInteger)index) : NULL;
    if (index == 13) {
        if (handle != Handle(3) || !strcmp(name,"CFCopySystemVersionDictionary")) return NULL;
        atomic_fetch_add(&aliasReads,1); return Address(13);
    }
    return handle == Handle(4) ? Address(14) : NULL;
}
static void *Replacement(NSUInteger index) {
    void *values[] = {(void *)PXCoord_sysctl,(void *)PXCoord_sysctlbyname,(void *)PXCoord_sysctlnametomib,
        (void *)PXCoord_gethostname,(void *)PXCoord_getifaddrs,(void *)PXCoord_gethostuuid,
        (void *)PXCoord_statfs,(void *)PXCoord_statfs64,(void *)PXCoord_getfsstat,(void *)PXCoord_getfsstat64,
        (void *)PXCoord_IORegistryEntryCreateCFProperty,(void *)PXCoord_IORegistryEntryCreateCFProperties,
        (void *)PXCoord_IORegistryEntrySearchCFProperty,(void *)PXCoord_CFCopySystemVersionDictionary,(void *)PXCoord_CNCopyCurrentNetworkInfo};
    return values[index];
}
static void **OriginalSlot(NSUInteger index) {
    void **slots[] = {(void **)&g_orig_sysctl,(void **)&g_orig_sysctlbyname,(void **)&g_orig_sysctlnametomib,
        (void **)&g_orig_gethostname,(void **)&g_orig_getifaddrs,(void **)&g_orig_gethostuuid,
        (void **)&g_orig_statfs,(void **)&g_orig_statfs64,(void **)&g_orig_getfsstat,(void **)&g_orig_getfsstat64,
        (void **)&g_orig_IORegistryEntryCreateCFProperty,(void **)&g_orig_IORegistryEntryCreateCFProperties,
        (void **)&g_orig_IORegistryEntrySearchCFProperty,(void **)&g_orig_CFCopySystemVersionDictionary,(void **)&g_orig_CNCopyCurrentNetworkInfo};
    return slots[index];
}
void MSHookFunction(void *symbol, void *replace, void **result) {
    NSUInteger index = 99;
    for (NSUInteger i = 0; i < 15; i++) if (symbol == Address(i)) index = i;
    CHECK(index < 15,"every install targets an owned symbol");
    if (index >= 15) return;
    CHECK((replace == Replacement(index) && result == OriginalSlot(index)), "every symbol keeps its exact replacement and original slot");
    CHECK((atomic_fetch_add(&hooks[index],1) == 0),"no symbol is patched twice");
    NSString *name = [NSString stringWithUTF8String:names[index]];
    CHECK((![coordinator isSymbolInstalled:name] && ![coordinator originalForSymbol:name]), "in-progress callback cannot observe premature installed metadata");
    // This only simulates an engine's output; these addresses are never invoked.
    *result = Case("null-original") && index == 14 ? NULL : Original(index);
    if (atomic_exchange(&blockFirst,NO)) {
        dispatch_semaphore_signal(enteredHook);
        CHECK((dispatch_semaphore_wait(releaseHook,dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC)) == 0),"concurrent test releases the first install");
    }
    Probe();
    if (Case("hook-throws") && index == 10) Raise();
}
void PXLog(NSString *format, ...) {
    @try { (void)format; if (Case("logging-throws")) Raise(); Probe(); }
    @finally { format = nil; }
}
void PXBeginRuntimeSnapshotOperation(PXRuntimeReadScope *scope) { PXRuntimeReadScopeBegin(scope,(id)nil); }

@interface PXMetadataFaultCoordinator : PXNativeHookCoordinator @end
@implementation PXMetadataFaultCoordinator
- (void)_markInstalled:(NSString *)symbol original:(void *)original {
    @try {
        if ([symbol isEqualToString:kPXNativeSymbolCNCopyCurrentNetworkInfo]) Raise();
        [super _markInstalled:symbol original:original];
    } @finally { symbol = nil; }
}
@end
@interface PXFaultingInstallName : NSObject
@property (nonatomic) BOOL throws;
@property (nonatomic) NSUInteger reads;
@end
@implementation PXFaultingInstallName
- (BOOL)isKindOfClass:(Class)type {
    (void)type; self.reads++;
    CHECK((![coordinator isSymbolInstalled:(id)self] && ![coordinator originalForSymbol:(id)self]), "canonical-name guard bounds recursive input validation");
    if (self.throws) Raise(); return NO;
}
@end
static void Names(void) {
    __weak PXFaultingInstallName *weakName;
    @autoreleasepool {
        PXFaultingInstallName *name = [PXFaultingInstallName new]; weakName = name;
        CHECK((![coordinator isSymbolInstalled:(id)name] && ![coordinator originalForSymbol:(id)name] && name.reads == 2), "malformed input returns absent without recursive validation");
        name.throws = YES;
        CHECK((![coordinator isSymbolInstalled:(id)name] && ![coordinator originalForSymbol:(id)name] && !gPXReadingNativeSymbol), "throwing name validation restores guard and preserves absent outputs");
        name = nil;
    }
    CHECK(!weakName,"metadata getters release foreign input after exceptional exit");
    CHECK((PXNativeCanonicalSymbol(kPXNativeSymbolStatfs) == kPXNativeSymbolStatfs), "known hot-path constant is returned without string copying");
    NSMutableString *mutable = [@"sysctl" mutableCopy];
    NSString *frozen = PXNativeCanonicalSymbol(mutable); [mutable setString:@"changed"];
    CHECK(([frozen isEqual:@"sysctl"]),"dynamic metadata name is detached from caller mutation");
    CHECK((!PXNativeCanonicalSymbol(nil) && !PXNativeCanonicalSymbol((id)@[]) && !PXNativeCanonicalSymbol(@"")), "nil malformed and empty names preserve absent behavior");
    CHECK((PXNativeInstallImage(99) == NULL),"invalid private image index never touches loader");
}
static void Validate(NSUInteger expectedHooks, NSInteger missing) {
    NSUInteger total = 0;
    for (NSUInteger index = 0; index < 15; index++) {
        total += atomic_load(&hooks[index]);
        NSString *name = [NSString stringWithUTF8String:names[index]];
        BOOL installed = missing != (NSInteger)index;
        if (Case("loader-throws") && index >= 10 && index <= 12) installed = NO;
        CHECK(([coordinator isSymbolInstalled:name] == installed),"installed getter reflects recorded hook outcome");
        BOOL hasOriginal = installed && !(Case("null-original") && index == 14);
        CHECK(([coordinator originalForSymbol:name] == (hasOriginal ? Original(index) : NULL)),"original getter reflects the same recorded outcome");
    }
    CHECK(total == expectedHooks,"the pass attempts the expected number of hooks");
    PXNativeInstallMetadata *before = [coordinator _captureInstallationMetadata];
    [coordinator installOwnedSymbolsIfNeeded];
    CHECK((before == [coordinator _captureInstallationMetadata]),"completed once never repeats patching or replaces metadata");
    CHECK((!gPXInsideNativeInstallPass && !gPXReadingNativeSymbol),"install and symbol-read guards restore on all exits");
    for (NSUInteger index = 0; index < 5; index++) CHECK((atomic_load(&opens[index]) <= 1),"each image retains at most one successful/failing acquisition attempt");
    for (NSUInteger index = 0; index < 2; index++) CHECK((atomic_load(&noLoads[index]) <= 1),"NOLOAD is queried at most once per system image");
    CHECK(atomic_load(&aliasReads) == 1,"CF private alias is used only after canonical lookup fails");
    CHECK(atomic_load(&probes) > 15,"loader hook and logging callback reentry was exercised");
}
int main(int argc, const char *argv[]) {
    if (argc != 2) return 2;
    scenario = argv[1];
    atomic_store(&engineVisible,!Case("engine-late"));
    @autoreleasepool {
        coordinator = Case("metadata-throws") ? [PXMetadataFaultCoordinator new] : [PXNativeHookCoordinator new];
        if (Case("names")) Names();
        if (Case("engine-late")) {
            [coordinator installOwnedSymbolsIfNeeded];
            CHECK(([coordinator _captureInstallationMetadata].installed.count == 0 && !gPXInsideNativeInstallPass),"missing engine consumes no pass or metadata");
            atomic_store(&engineVisible,YES);
        }
        if (Case("concurrent")) {
            enteredHook = dispatch_semaphore_create(0); releaseHook = dispatch_semaphore_create(0);
            atomic_store(&blockFirst,YES);
            dispatch_group_t group = dispatch_group_create();
            dispatch_group_async(group,dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{ @autoreleasepool { [coordinator installOwnedSymbolsIfNeeded]; } });
            CHECK((dispatch_semaphore_wait(enteredHook,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC)) == 0),"first installer reaches the hook library");
            for (NSUInteger i = 0; i < 8; i++) dispatch_group_async(group,dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{ @autoreleasepool { [coordinator installOwnedSymbolsIfNeeded]; } });
            dispatch_semaphore_signal(releaseHook);
            CHECK((dispatch_group_wait(group,dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC)) == 0),"concurrent callers finish the same serialized pass");
        } else [coordinator installOwnedSymbolsIfNeeded];
        if (Case("missing-symbol")) {
            atomic_store(&permitMissing,YES);
            Validate(14,7); CHECK(atomic_load(&hooks[7]) == 0,"a missing individual symbol remains uninstalled after once, with no retry");
        } else if (Case("hook-throws")) Validate(15,10);
        else if (Case("metadata-throws")) Validate(15,14);
        else if (Case("loader-throws")) Validate(12,-1);
        else if (Case("lookup-throws")) Validate(14,3);
        else Validate(15,-1);
        if (Case("hook-throws") || Case("metadata-throws")) {
            NSUInteger index = Case("hook-throws") ? 10 : 14;
            CHECK((*OriginalSlot(index) == Original(index) && atomic_load(&hooks[index]) == 1),"uncertain outcome preserves engine output and is never blindly repatched");
        }
        if (Case("null-original")) {
            NSDictionary *row = [coordinator diagnostics][@"symbols"][@"CNCopyCurrentNetworkInfo"];
            CHECK(([row[@"originalPresent"] isEqual:@NO]),"nil trampoline remains explicitly absent in diagnostics");
        }
        coordinator = nil;
    }
    fprintf(stdout,"Native installation %s: %lu/%lu checks passed\n",scenario,(unsigned long)(checks-failures),(unsigned long)checks);
    return failures ? 1 : 0;
}
