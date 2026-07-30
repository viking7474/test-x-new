#ifndef INTERNAL_SECURITY_RESEARCH
#define INTERNAL_SECURITY_RESEARCH 0
#endif
#if !INTERNAL_SECURITY_RESEARCH
#error "PXLockdownObservability must never be compiled outside an Internal Research build"
#endif

#import "PXLockdownObservability.h"
#import "PXLockdownSoftwareModelProvider.h"
#import "PXLockdownDeviceIdentityProvider.h"
#import "PXLockdownSoCCellularProvider.h"

static NSString *const kPXObservedProviderSoftware = @"PXLockdownSoftwareModelProvider";
static NSString *const kPXObservedProviderDeviceIdentity = @"PXLockdownDeviceIdentityProvider";
static NSString *const kPXObservedProviderSoCCellular = @"PXLockdownSoCCellularProvider";

@interface PXLockdownObservedKey ()
@property (nonatomic, copy, readwrite) NSString *lockdownKey;
@property (nonatomic, readwrite) PXLockdownObservedDomain domain;
@property (nonatomic, copy, readwrite) NSString *sourceProvider;
@property (nonatomic, readwrite) Class expectedClass;
@property (nonatomic, readwrite, getter=isSensitive) BOOL sensitive;
@end

@implementation PXLockdownObservedKey
@end

static PXLockdownObservedKey *PXObserved(NSString *key,
                                         PXLockdownObservedDomain domain,
                                         NSString *provider,
                                         Class expectedClass,
                                         BOOL sensitive) {
    PXLockdownObservedKey *entry = [[PXLockdownObservedKey alloc] init];
    entry.lockdownKey = key;
    entry.domain = domain;
    entry.sourceProvider = provider;
    entry.expectedClass = expectedClass;
    entry.sensitive = sensitive;
    return entry;
}

NSArray<PXLockdownObservedKey *> *PXLockdownObservedKeyInventory(void) {
    static NSArray<PXLockdownObservedKey *> *inventory = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray<PXLockdownObservedKey *> *items = [NSMutableArray array];
        // L1 — software/presentation (Phase 5). Every key is a non-sensitive String.
        for (PXLockdownSoftwareModelEntry *entry in PXLockdownSoftwareModelEntries()) {
            [items addObject:PXObserved(entry.lockdownKey,
                                        PXLockdownObservedDomainSoftwareModel,
                                        kPXObservedProviderSoftware,
                                        [NSString class], NO)];
        }
        // L2 — device identity (Phase 6). UDID / serial / MLB are sensitive Strings.
        for (PXLockdownDeviceIdentityEntry *entry in PXLockdownDeviceIdentityEntries()) {
            [items addObject:PXObserved(entry.lockdownKey,
                                        PXLockdownObservedDomainDeviceIdentity,
                                        kPXObservedProviderDeviceIdentity,
                                        [NSString class], YES)];
        }
        // L3 — SoC/cellular (Phase 7). UniqueChipID is a redacted NSNumber ECID and
        // telephony identifiers are sensitive Strings; BasebandVersion is a
        // non-sensitive firmware string.
        for (PXLockdownSoCCellularEntry *entry in PXLockdownSoCCellularEntries()) {
            BOOL isChipID = entry.kind == PXLockdownSoCCellularKindUniqueChipID;
            BOOL isBaseband = entry.kind == PXLockdownSoCCellularKindBasebandVersion;
            Class expected = isChipID ? [NSNumber class] : [NSString class];
            [items addObject:PXObserved(entry.lockdownKey,
                                        PXLockdownObservedDomainSoCCellular,
                                        kPXObservedProviderSoCCellular,
                                        expected, !isBaseband)];
        }
        inventory = [items copy];
    });
    return inventory;
}

PXLockdownObservedKey *PXLockdownObservedKeyForLockdownKey(NSString *lockdownKey) {
    if (lockdownKey.length == 0) { return nil; }
    for (PXLockdownObservedKey *entry in PXLockdownObservedKeyInventory()) {
        if ([entry.lockdownKey isEqualToString:lockdownKey]) { return entry; }
    }
    return nil;
}

static NSString *PXObservedDomainName(PXLockdownObservedDomain domain) {
    switch (domain) {
        case PXLockdownObservedDomainSoftwareModel: return @"software-model";
        case PXLockdownObservedDomainDeviceIdentity: return @"device-identity";
        case PXLockdownObservedDomainSoCCellular: return @"soc-cellular";
    }
    return @"unknown";
}

BOOL PXLockdownObservabilityInventoryIsWellFormed(NSArray<NSString *> **outFailures) {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    NSArray<PXLockdownObservedKey *> *inventory = PXLockdownObservedKeyInventory();
    NSUInteger providerTotal = PXLockdownSoftwareModelEntries().count
        + PXLockdownDeviceIdentityEntries().count
        + PXLockdownSoCCellularEntries().count;
    if (inventory.count != providerTotal) {
        [failures addObject:[NSString stringWithFormat:@"inventory count %lu != provider total %lu",
                             (unsigned long)inventory.count, (unsigned long)providerTotal]];
    }
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (PXLockdownObservedKey *entry in inventory) {
        if (entry.lockdownKey.length == 0) { [failures addObject:@"empty lockdown key"]; continue; }
        if ([seen containsObject:entry.lockdownKey]) {
            [failures addObject:[NSString stringWithFormat:@"duplicate key %@", entry.lockdownKey]];
        }
        [seen addObject:entry.lockdownKey];
        if (entry.sourceProvider.length == 0) {
            [failures addObject:[NSString stringWithFormat:@"%@ missing source provider", entry.lockdownKey]];
        }
        if (entry.expectedClass == Nil) {
            [failures addObject:[NSString stringWithFormat:@"%@ missing expected class", entry.lockdownKey]];
        }
    }
    if (outFailures) { *outFailures = failures.count ? [failures copy] : nil; }
    return failures.count == 0;
}

BOOL PXLockdownObservationDomainIsForbidden(NSString *rawDomain) {
    if (rawDomain.length == 0) { return NO; }
    static NSArray<NSString *> *forbidden = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // pairing records, certificates, private keys and escrow material.
        forbidden = @[@"pairrecord", @"pairing", @"certificate", @"privatekey",
                      @"escrow", @"escrowbag"];
    });
    NSString *needle = rawDomain.lowercaseString;
    for (NSString *marker in forbidden) {
        if ([needle containsString:marker]) { return YES; }
    }
    return NO;
}

NSDictionary<NSString *, id> *PXLockdownObservationRecord(NSString *processName,
                                                          NSString *lockdownKey,
                                                          id sensitiveValue,
                                                          NSString *rawDomain) {
    // Never emit pairing/certificate/private-key/escrow material, even as metadata.
    if (PXLockdownObservationDomainIsForbidden(rawDomain)) { return nil; }
    PXLockdownObservedKey *entry = PXLockdownObservedKeyForLockdownKey(lockdownKey);
    if (!entry) { return nil; }
    // Observe-only records carry metadata only: the raw identifier is never copied
    // in. Sensitive keys are always "<redacted>"; non-sensitive presentation keys
    // expose only the value's class, never the value itself.
    NSString *payload = @"<redacted>";
    if (!entry.isSensitive) {
        payload = sensitiveValue ? NSStringFromClass([sensitiveValue class]) : @"<nil>";
    }
    return @{
        @"process": processName.length ? processName : @"<unknown>",
        @"key": entry.lockdownKey,
        @"expectedType": NSStringFromClass(entry.expectedClass),
        @"sourceProvider": entry.sourceProvider,
        @"domain": PXObservedDomainName(entry.domain),
        @"mode": @"observe",
        @"payload": payload,
    };
}

@implementation PXLockdownAccessMetrics {
    NSLock *_lock;
    NSMutableDictionary<NSString *, NSNumber *> *_accesses;
    NSMutableDictionary<NSString *, NSNumber *> *_timeouts;
    NSMutableDictionary<NSString *, NSNumber *> *_cacheHits;
    NSMutableDictionary<NSString *, NSNumber *> *_cacheMisses;
    NSUInteger _totalAccesses;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lock = [[NSLock alloc] init];
        _accesses = [NSMutableDictionary dictionary];
        _timeouts = [NSMutableDictionary dictionary];
        _cacheHits = [NSMutableDictionary dictionary];
        _cacheMisses = [NSMutableDictionary dictionary];
        _totalAccesses = 0;
    }
    return self;
}

static void PXBump(NSMutableDictionary<NSString *, NSNumber *> *table, NSString *key) {
    table[key] = @(table[key].unsignedIntegerValue + 1);
}

- (void)recordAccessForKey:(NSString *)lockdownKey timedOut:(BOOL)timedOut cacheHit:(BOOL)cacheHit {
    if (lockdownKey.length == 0) { return; }
    [_lock lock];
    PXBump(_accesses, lockdownKey);
    _totalAccesses += 1;
    if (timedOut) { PXBump(_timeouts, lockdownKey); }
    if (cacheHit) { PXBump(_cacheHits, lockdownKey); } else { PXBump(_cacheMisses, lockdownKey); }
    [_lock unlock];
}

- (NSUInteger)countIn:(NSMutableDictionary<NSString *, NSNumber *> *)table forKey:(NSString *)key {
    if (key.length == 0) { return 0; }
    [_lock lock];
    NSUInteger value = table[key].unsignedIntegerValue;
    [_lock unlock];
    return value;
}

- (NSUInteger)accessCountForKey:(NSString *)key { return [self countIn:_accesses forKey:key]; }
- (NSUInteger)timeoutCountForKey:(NSString *)key { return [self countIn:_timeouts forKey:key]; }
- (NSUInteger)cacheHitCountForKey:(NSString *)key { return [self countIn:_cacheHits forKey:key]; }
- (NSUInteger)cacheMissCountForKey:(NSString *)key { return [self countIn:_cacheMisses forKey:key]; }

- (NSUInteger)totalAccessCount {
    [_lock lock];
    NSUInteger value = _totalAccesses;
    [_lock unlock];
    return value;
}

- (NSDictionary<NSString *, id> *)redactedSnapshot {
    [_lock lock];
    NSDictionary *snapshot = @{
        @"totalAccesses": @(_totalAccesses),
        @"keysObserved": @(_accesses.count),
        @"accessesByKey": [_accesses copy],
        @"timeoutsByKey": [_timeouts copy],
        @"cacheHitsByKey": [_cacheHits copy],
        @"cacheMissesByKey": [_cacheMisses copy],
    };
    [_lock unlock];
    return snapshot;
}
@end
