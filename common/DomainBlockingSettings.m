#import "DomainBlockingSettings.h"
#import <os/lock.h>
#include <errno.h>

static NSString *const kDomainBlockingSettingsFile = @"/var/mobile/Library/Preferences/com.hydra.tlinkios.domainblocking.plist";
static NSString *const kDomainBlockingSettingsFileAlt1 = @"/private/var/mobile/Library/Preferences/com.hydra.tlinkios.domainblocking.plist";
static NSString *const kDomainBlockingSettingsFileAlt2 = @"/var/mobile/Library/Preferences/com.hydra.tlinkios.domainblocking.plist";
static NSString *const kIsEnabledKey = @"isEnabled";
static NSString *const kBlockedDomainsKey = @"blockedDomains";
static NSString *const kCustomDomainsKey = @"customDomains";
static __thread BOOL gPXDomainCreating;
static __thread BOOL gPXDomainMatching;

@interface PXDomainPolicy : NSObject
@property (nonatomic) BOOL enabled;
@property (nonatomic, copy) NSDictionary *statuses;
@property (nonatomic, copy) NSArray *domains;
@property (nonatomic, copy) NSSet *normalized;
@property (nonatomic, copy) NSArray *suffixes;
@end
@implementation PXDomainPolicy
@end

static BOOL PXDomainScalar(id value) { return [value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class]; }
// Preserve the existing policy: lowercase and remove exactly one trailing dot.
static NSString *PXDomainNormalized(NSString *domain) {
    NSString *lower = nil;
    @try { lower = [domain lowercaseString];return [lower hasSuffix:@"."] ? [lower substringToIndex:lower.length-1] : lower; }
    @finally { domain = nil;lower = nil; }
}
static PXDomainPolicy *PXDomainBuild(BOOL enabled, NSDictionary *statuses, NSArray *override) {
    NSMutableDictionary *detached = nil;
    NSMutableArray *domains = nil;
    NSMutableSet *normalized = nil;
    NSMutableArray *suffixes = nil;
    NSString *key = nil, *valueString = nil;
    id value = nil;
    PXDomainPolicy *policy = nil;
    @try {
        if (![statuses isKindOfClass:NSDictionary.class] || (override && ![override isKindOfClass:NSArray.class])) return nil;
        detached = [NSMutableDictionary dictionary];domains = [NSMutableArray array];normalized = [NSMutableSet set];suffixes = [NSMutableArray array];
        NSArray *keys = nil;
        @try {
            keys = [statuses allKeys];
            for (NSUInteger i = 0; i < keys.count; i++) {
                key = keys[i];value = statuses[key];
                if (![key isKindOfClass:NSString.class] || !key.length || !PXDomainScalar(value)) return nil;
                key = [[NSString alloc] initWithString:key];
                // Materialize booleans, so a mutable NSString value cannot mutate a published packet.
                BOOL active = [value boolValue];detached[key] = @(active);
                if (!override && active) [domains addObject:key];
            }
        } @finally { keys = nil; }
        if (override) for (NSUInteger i = 0; i < override.count; i++) {
            key = override[i];if (![key isKindOfClass:NSString.class] || !key.length) return nil;
            key = [[NSString alloc] initWithString:key];[domains addObject:key];
        }
        for (NSUInteger i = 0; i < domains.count; i++) { key = domains[i];valueString = PXDomainNormalized(key);if (!valueString) return nil;[normalized addObject:valueString];[suffixes addObject:[@"." stringByAppendingString:valueString]]; }
        policy = [PXDomainPolicy new];policy.enabled = enabled;policy.statuses = detached;policy.domains = domains;policy.normalized = normalized;policy.suffixes = suffixes;
        return policy;
    } @finally { statuses = nil;override = nil;detached = nil;domains = nil;normalized = nil;suffixes = nil;key = nil;value = nil;valueString = nil;policy = nil; }
}
// Only confirmed absence permits first-run creation or a later path fallback.
static BOOL PXDomainPathPresent(NSFileManager *files, NSString *path) {
    NSDictionary *attributes = nil;NSError *__autoreleasing error = nil;
    @try {
        attributes = [files attributesOfItemAtPath:path error:&error];if (attributes) return YES;
        if ([error.domain isEqualToString:NSCocoaErrorDomain] && (error.code == NSFileNoSuchFileError || error.code == NSFileReadNoSuchFileError)) return NO;
        if ([error.domain isEqualToString:NSPOSIXErrorDomain] && error.code == ENOENT) return NO;
        return YES;
    } @finally { files = nil;path = nil;attributes = nil; }
}
static NSString *getSettingsFilePath(void) {
    NSFileManager *files = nil;NSArray *paths = nil;NSString *path = nil;
    @try {
        files = [NSFileManager defaultManager];paths = @[kDomainBlockingSettingsFile,kDomainBlockingSettingsFileAlt1,kDomainBlockingSettingsFileAlt2];
        for (NSUInteger i = 0; i < paths.count; i++) { path = paths[i];if (PXDomainPathPresent(files,path)) return path; }
        return kDomainBlockingSettingsFile;
    } @finally { files = nil;paths = nil;path = nil; }
}

typedef NS_ENUM(NSUInteger, PXDomainEdit) { PXDomainAdd, PXDomainDisable, PXDomainToggle, PXDomainDelete, PXDomainReplace };
@interface DomainBlockingSettings () {
    os_unfair_lock _policyLock;
    PXDomainPolicy *_policy;
    BOOL _changing; // Access only under the recursive writer monitor; readers never take that monitor.
}
- (PXDomainPolicy *)capturedPolicy;
- (void)publishPolicy:(PXDomainPolicy *)policy;
- (BOOL)writePolicy:(PXDomainPolicy *)policy;
- (BOOL)changeDomain:(NSString *)domain replacement:(NSString *)replacement operation:(PXDomainEdit)operation enabled:(BOOL)enabled;
@end

@implementation DomainBlockingSettings
+ (instancetype)sharedSettings {
    static DomainBlockingSettings *sharedInstance;static dispatch_once_t onceToken;
    BOOL previous = gPXDomainCreating;
    @try {
        if (previous) return nil;gPXDomainCreating = YES;
        dispatch_once(&onceToken, ^{
            @try { sharedInstance = [[self alloc] init];[sharedInstance loadSettings]; }
            @catch (__unused NSException *exception) { }
        });
        return sharedInstance;
    } @finally { gPXDomainCreating = previous; }
}
- (instancetype)init {
    self = [super init];if (self) {
        _policyLock = (os_unfair_lock)OS_UNFAIR_LOCK_INIT;
        _policy = PXDomainBuild(YES,@{@"devicecheck.apple.com":@YES,@"appattest.apple.com":@YES},nil);
        if (!_policy) return nil;
    }return self;
}
- (PXDomainPolicy *)capturedPolicy {
    PXDomainPolicy *policy = nil;
    os_unfair_lock_lock(&_policyLock);
    @try { policy = _policy; } @finally { os_unfair_lock_unlock(&_policyLock); }
    return policy;
}
- (void)publishPolicy:(PXDomainPolicy *)policy {
    __attribute__((objc_precise_lifetime)) PXDomainPolicy *retired = nil;
    @try {
        os_unfair_lock_lock(&_policyLock);
        @try { retired = _policy;_policy = policy; }
        @finally { os_unfair_lock_unlock(&_policyLock); }
    } @finally { retired = nil;policy = nil; }
}
- (BOOL)isEnabled {
    PXDomainPolicy *policy = nil;@try { policy = [self capturedPolicy];return policy.enabled; } @finally { policy = nil; }
}
// Compatibility setter: in-memory only. Persisted UI edits use setEnabledAndSave:.
- (void)setIsEnabled:(BOOL)enabled {
    PXDomainPolicy *basis = nil, *candidate = nil;
    @synchronized (self) {
        BOOL previous = _changing;
        @try { if (previous) return;_changing = YES;basis = [self capturedPolicy];candidate = PXDomainBuild(enabled,basis.statuses,basis.domains);if (candidate) [self publishPolicy:candidate]; }
        @catch (__unused NSException *exception) { }
        @finally { _changing = previous;basis = nil;candidate = nil; }
    }
}
- (NSMutableArray<NSString *> *)blockedDomains {
    PXDomainPolicy *policy = nil;@try { policy = [self capturedPolicy];return [policy.domains mutableCopy]; } @finally { policy = nil; }
}
- (void)setBlockedDomains:(NSMutableArray<NSString *> *)domains {
    PXDomainPolicy *basis = nil, *candidate = nil;
    @synchronized (self) {
        BOOL previous = _changing;
        @try { if (previous) return;_changing = YES;if (![domains isKindOfClass:NSArray.class]) return;basis = [self capturedPolicy];candidate = PXDomainBuild(basis.enabled,basis.statuses,domains);if (candidate) [self publishPolicy:candidate]; }
        @catch (__unused NSException *exception) { }
        @finally { _changing = previous;domains = nil;basis = nil;candidate = nil; }
    }
}
- (BOOL)writePolicy:(PXDomainPolicy *)policy {
    NSString *path = nil, *directory = nil;NSFileManager *files = nil;NSDictionary *settings = nil;
    @try {
        path = getSettingsFilePath();files = [NSFileManager defaultManager];directory = [path stringByDeletingLastPathComponent];
        if (![files fileExistsAtPath:directory] && ![files createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL]) return NO;
        settings = @{kIsEnabledKey:@(policy.enabled),kBlockedDomainsKey:policy.domains,kCustomDomainsKey:policy.statuses};
        return [settings writeToFile:path atomically:YES];
    } @finally { policy = nil;path = nil;directory = nil;files = nil;settings = nil; }
}
- (BOOL)saveSettings {
    PXDomainPolicy *policy = nil;
    @synchronized (self) {
        BOOL previous = _changing;
        @try { if (previous) return NO;_changing = YES;policy = [self capturedPolicy];return [self writePolicy:policy]; }
        @catch (__unused NSException *exception) { return NO; }
        @finally { _changing = previous;policy = nil; }
    }
}
- (BOOL)setEnabledAndSave:(BOOL)enabled {
    PXDomainPolicy *basis = nil, *candidate = nil;
    @synchronized (self) {
        BOOL previous = _changing;
        @try {
            if (previous) return NO;_changing = YES;basis = [self capturedPolicy];candidate = PXDomainBuild(enabled,basis.statuses,basis.domains);
            if (!candidate || ![self writePolicy:candidate]) return NO;
            [self publishPolicy:candidate];return YES;
        } @catch (__unused NSException *exception) { return NO; }
        @finally { _changing = previous;basis = nil;candidate = nil; }
    }
}
- (BOOL)loadSettings {
    NSString *path = nil, *domain = nil;NSDictionary *settings = nil, *statuses = nil;
    NSArray *legacy = nil;NSMutableDictionary *migrated = nil;id flag = nil;
    PXDomainPolicy *basis = nil, *candidate = nil;NSFileManager *files = nil;
    @synchronized (self) {
        BOOL previous = _changing;
        @try {
            if (previous) return NO;_changing = YES;basis = [self capturedPolicy];path = getSettingsFilePath();files = [NSFileManager defaultManager];
            settings = [NSDictionary dictionaryWithContentsOfFile:path];
            if (!settings) {
                // A present corrupt/unreadable source must not be overwritten as first-run defaults.
                if (PXDomainPathPresent(files,path)) return NO;
                return [self writePolicy:basis];
            }
            flag = settings[kIsEnabledKey];if (flag && !PXDomainScalar(flag)) return NO;
            statuses = settings[kCustomDomainsKey];legacy = settings[kBlockedDomainsKey];
            if (statuses && ![statuses isKindOfClass:NSDictionary.class]) return NO;
            BOOL migration = !statuses && [legacy isKindOfClass:NSArray.class];
            if (!statuses) {
                migrated = [basis.statuses mutableCopy];
                if (migration) for (NSUInteger i = 0; i < legacy.count; i++) {
                    domain = legacy[i];if ([domain isKindOfClass:NSString.class] && domain.length) migrated[domain] = @YES;
                }
                statuses = migrated;
            }
            candidate = PXDomainBuild(flag ? [flag boolValue] : YES,statuses,nil);if (!candidate) return NO;
            if (migration && ![self writePolicy:candidate]) return NO;
            [self publishPolicy:candidate];return YES;
        } @catch (__unused NSException *exception) { return NO; }
        @finally { _changing = previous;path = nil;domain = nil;settings = nil;statuses = nil;legacy = nil;migrated = nil;flag = nil;basis = nil;candidate = nil;files = nil; }
    }
}
- (BOOL)changeDomain:(NSString *)domain replacement:(NSString *)replacement operation:(PXDomainEdit)operation enabled:(BOOL)enabled {
    PXDomainPolicy *basis = nil, *candidate = nil;NSMutableDictionary *statuses = nil;NSString *key = nil, *newKey = nil;NSNumber *old = nil;
    @synchronized (self) {
        BOOL previous = _changing;
        @try {
            if (previous) return NO;_changing = YES;
            if (![domain isKindOfClass:NSString.class] || !domain.length) return NO;
            key = [[NSString alloc] initWithString:domain];basis = [self capturedPolicy];old = basis.statuses[key];
            switch (operation) {
                case PXDomainAdd: if ([old boolValue]) return YES;break;
                case PXDomainDisable: if (!old || ![old boolValue]) return YES;break;
                case PXDomainToggle: if (!old) return NO;if ([old boolValue] == enabled) return YES;break;
                case PXDomainDelete: if (!old) return NO;break;
                case PXDomainReplace:
                    if (![replacement isKindOfClass:NSString.class] || !replacement.length) return NO;
                    newKey = [[NSString alloc] initWithString:replacement];if (!old || basis.statuses[newKey]) return NO;break;
            }
            statuses = [basis.statuses mutableCopy];
            switch (operation) {
                case PXDomainAdd: statuses[key] = @YES;break;
                case PXDomainDisable: statuses[key] = @NO;break;
                case PXDomainToggle: statuses[key] = @(enabled);break;
                case PXDomainDelete: [statuses removeObjectForKey:key];break;
                case PXDomainReplace: [statuses removeObjectForKey:key];statuses[newKey] = old;break;
            }
            candidate = PXDomainBuild(basis.enabled,statuses,nil);if (!candidate || ![self writePolicy:candidate]) return NO;
            [self publishPolicy:candidate];return YES;
        } @catch (__unused NSException *exception) { return NO; }
        @finally { _changing = previous;domain = nil;replacement = nil;basis = nil;candidate = nil;statuses = nil;key = nil;newKey = nil;old = nil; }
    }
}
- (BOOL)addDomain:(NSString *)domain { @try { return [self changeDomain:domain replacement:nil operation:PXDomainAdd enabled:YES]; } @finally { domain = nil; } }
- (BOOL)removeDomain:(NSString *)domain { @try { return [self changeDomain:domain replacement:nil operation:PXDomainDisable enabled:NO]; } @finally { domain = nil; } }
- (BOOL)setCustomDomainEnabled:(NSString *)domain enabled:(BOOL)enabled { @try { return [self changeDomain:domain replacement:nil operation:PXDomainToggle enabled:enabled]; } @finally { domain = nil; } }
- (BOOL)removeCustomDomain:(NSString *)domain { @try { return [self changeDomain:domain replacement:nil operation:PXDomainDelete enabled:NO]; } @finally { domain = nil; } }
- (BOOL)replaceCustomDomain:(NSString *)oldDomain withDomain:(NSString *)newDomain { @try { return [self changeDomain:oldDomain replacement:newDomain operation:PXDomainReplace enabled:NO]; } @finally { oldDomain = nil;newDomain = nil; } }
- (BOOL)isCustomDomain:(NSString *)domain {
    PXDomainPolicy *policy = nil;@try { if (![domain isKindOfClass:NSString.class]) return NO;policy = [self capturedPolicy];return policy.statuses[domain] != nil; }
    @catch (__unused NSException *exception) { return NO; } @finally { policy = nil;domain = nil; }
}
- (BOOL)isCustomDomainEnabled:(NSString *)domain {
    PXDomainPolicy *policy = nil;@try { if (![domain isKindOfClass:NSString.class]) return NO;policy = [self capturedPolicy];return [policy.statuses[domain] boolValue]; }
    @catch (__unused NSException *exception) { return NO; } @finally { policy = nil;domain = nil; }
}
- (NSArray<NSDictionary *> *)getCustomDomains {
    PXDomainPolicy *policy = nil;NSMutableArray *result = nil;NSArray *keys = nil;NSString *key = nil;
    @try {
        policy = [self capturedPolicy];keys = [[policy.statuses allKeys] sortedArrayUsingSelector:@selector(compare:)];result = [NSMutableArray array];
        for (NSUInteger i = 0; i < keys.count; i++) { key = keys[i];[result addObject:@{@"domain":key,@"enabled":policy.statuses[key]}]; }
        return [result copy];
    } @finally { policy = nil;result = nil;keys = nil;key = nil; }
}
- (NSArray<NSDictionary *> *)getAllDomains { return [self getCustomDomains]; }
- (BOOL)isDomainBlocked:(NSString *)domain {
    PXDomainPolicy *policy = nil;NSString *host = nil, *suffix = nil;
    BOOL previous = gPXDomainMatching;
    @try {
        if (previous) return NO;gPXDomainMatching = YES;
        if (![domain isKindOfClass:NSString.class] || !domain.length) return NO;
        policy = [self capturedPolicy];if (!policy.enabled) return NO;
        host = PXDomainNormalized(domain);if (!host) return NO;
        if ([policy.normalized containsObject:host]) return YES;
        // Keep NSString's existing hasSuffix semantics, including unusual and
        // Unicode inputs; only rule normalization/allocation moves to updates.
        for (NSUInteger i = 0; i < policy.suffixes.count; i++) { suffix = policy.suffixes[i];if ([host hasSuffix:suffix]) return YES; }
        return NO;
    } @catch (__unused NSException *exception) { return NO; }
    @finally { domain = nil;policy = nil;host = nil;suffix = nil;gPXDomainMatching = previous; }
}
@end
