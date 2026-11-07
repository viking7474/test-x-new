#import "StorageManager.h"
#import "PXRuntimeArtifactPreparation.h"
#import "ProfileManager.h"
#import "TLinkIOSLogging.h"
#import "PXPaths.h"
#import "PXProfileArtifactMutation.h"
#import "PXRuntimeSourceStore.h"
#import "DeviceModelManager.h"
#import "IPhoneModelDB.h"
#include <math.h>

// Constants for proper size calculations
// Use only marketing units (1000-based) as used by Apple
#define BYTES_PER_KB (1000ULL)
#define BYTES_PER_MB (1000ULL * 1000ULL)
#define BYTES_PER_GB (1000ULL * 1000ULL * 1000ULL)
#define BYTES_PER_TB (1000ULL * 1000ULL * 1000ULL * 1000ULL)

// Standard APFS block size
#define DEFAULT_BLOCK_SIZE (4096ULL)

// A storage record can contain legacy numeric scalars. Keep NSString APIs
// stable while rejecting container/date fields and malformed cache roots.
static NSString *PXStorageScalarField(id settings, NSString *key) {
    id value = nil;
    @try {
        if (![settings isKindOfClass:NSDictionary.class]) return nil;
        value = settings[key];
        if ([value isKindOfClass:NSString.class]) return value;
        return [value isKindOfClass:NSNumber.class] ? [value stringValue] : nil;
    } @finally { value = nil; settings = nil; key = nil; }
}
// Freeze owned scalar strings while keeping legacy numeric types and shallow
// metadata. All foreign copy/access work stays outside the cache monitor.
static NSDictionary *PXStorageFrozenRecord(id record) {
    NSMutableDictionary *candidate = nil;
    id value = nil;
    @try {
        if (![record isKindOfClass:NSDictionary.class]) return nil;
        candidate = [record mutableCopy];
        for (NSString *key in @[@"TotalStorage", @"FreeStorage", @"FilesystemType"]) {
            value = candidate[key];
            if ([value isKindOfClass:NSString.class]) candidate[key] = [value copy];
            value = nil;
        }
        return [candidate copy];
    } @finally { value = nil; candidate = nil; record = nil; }
}
static BOOL PXStorageSuperseded(NSError **error) {
    if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios.storage-display" code:3
        userInfo:@{NSLocalizedDescriptionKey: @"Storage cache operation was superseded"}];
    return NO;
}

@interface StorageManager ()
- (NSString *)randomizeStorageCapacityForProfile:(NSString *)profileID;
- (void)setDefaultStorageForProfile:(NSString *)profileID;
- (BOOL)persistStorageToProfile:(NSString *)profileID current:(BOOL)current error:(NSError **)error;
- (uint64_t)storageCacheRevision;
- (uint64_t)beginStorageCacheWorkIfRevision:(uint64_t)revision;
- (uint64_t)beginStorageCacheWork;
- (BOOL)storageCacheRevisionIsCurrent:(uint64_t)revision;
- (NSDictionary *)captureStorageCache:(uint64_t *)revision;
- (BOOL)publishStorageCache:(NSDictionary *)candidate revision:(uint64_t)revision;
- (void)setStorageScalar:(id)value key:(NSString *)key;
- (void)setDefaultStorageForProfile:(NSString *)profileID revision:(uint64_t)revision;
- (BOOL)loadFromProfile:(NSString *)profileId revision:(uint64_t)revision;
- (BOOL)persistStorageRecord:(NSDictionary *)record revision:(uint64_t)revision profileID:(NSString *)profileID current:(BOOL)current error:(NSError **)error;
@end

@implementation StorageManager {
    NSDictionary *_storageSettings;
    uint64_t _storageCacheRevision;
    BOOL _isEnabled;
    BOOL _storagePreferenceWriteInFlight;
}

+ (instancetype)sharedManager {
    static StorageManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _storageSettings = @{};
        
        // Load from settings
        NSUserDefaults *defaults = [[NSUserDefaults alloc] 
                                   initWithSuiteName:@"com.hydra.tlinkios.settings"];
        _isEnabled = [defaults boolForKey:@"StorageSystemEnabled"];
        
        // Load current profile
        [self loadFromCurrentProfile];
    }
    return self;
}

- (uint64_t)storageCacheRevision {
    @synchronized (self) { return _storageCacheRevision; }
}

- (uint64_t)beginStorageCacheWorkIfRevision:(uint64_t)revision {
    @synchronized (self) {
        if (revision != _storageCacheRevision) return 0;
        if (++_storageCacheRevision == 0) ++_storageCacheRevision;
        return _storageCacheRevision;
    }
}

- (uint64_t)beginStorageCacheWork {
    @synchronized (self) {
        if (++_storageCacheRevision == 0) ++_storageCacheRevision;
        return _storageCacheRevision;
    }
}

- (BOOL)storageCacheRevisionIsCurrent:(uint64_t)revision {
    @synchronized (self) { return revision == _storageCacheRevision; }
}

- (NSDictionary *)captureStorageCache:(uint64_t *)revision {
    NSDictionary *root = nil;
    @try {
        @synchronized (self) {
            root = _storageSettings;
            if (revision) *revision = _storageCacheRevision;
        }
        return root;
    } @finally { root = nil; }
}

- (BOOL)publishStorageCache:(NSDictionary *)candidate revision:(uint64_t)revision {
    __attribute__((objc_precise_lifetime)) NSDictionary *old = nil;
    @try {
        @synchronized (self) {
            if (revision != _storageCacheRevision) return NO;
            old = _storageSettings;
            _storageSettings = candidate;
        }
        return YES;
    } @finally { old = nil; candidate = nil; }
}

- (void)setStorageScalar:(id)value key:(NSString *)key {
    uint64_t observed = [self storageCacheRevision];
    NSDictionary *base = nil, *record = nil;
    NSMutableDictionary *candidate = nil;
    id frozen = nil;
    NSError *error = nil;
    @try {
        if (value && ![value isKindOfClass:NSString.class] && ![value isKindOfClass:NSNumber.class]) return;
        frozen = [value copy];
        uint64_t revision = [self beginStorageCacheWorkIfRevision:observed];
        if (!revision) return;
        base = [self currentStorageInfo];
        if (![self storageCacheRevisionIsCurrent:revision]) return;
        candidate = [base mutableCopy];
        candidate[key] = frozen; // Nil retains the legacy remove-and-autosave policy.
        record = PXStorageFrozenRecord(candidate);
        if (![self publishStorageCache:record revision:revision]) return;
        if (![self persistStorageRecord:record revision:revision profileID:nil current:YES error:&error])
            PXLog(@"[StorageManager] Failed to commit current storage: %@", error);
    } @finally { error = nil; frozen = nil; record = nil; candidate = nil; base = nil; value = nil; key = nil; }
}

- (void)setDefaultStorageForProfile:(NSString *)profileID revision:(uint64_t)revision {
    NSString *capacity = nil;
    id prepared = nil;
    NSDictionary *storageInfo = nil, *base = nil, *record = nil;
    NSMutableDictionary *candidate = nil;
    @try {
        if (![self storageCacheRevisionIsCurrent:revision]) return;
        capacity = [self randomizeStorageCapacityForProfile:profileID];
        if (![self storageCacheRevisionIsCurrent:revision]) return;
        prepared = [self generateStorageForCapacity:capacity];
        if (![self storageCacheRevisionIsCurrent:revision]) return;
        storageInfo = [prepared isKindOfClass:NSDictionary.class] ? prepared : nil;
        base = [self currentStorageInfo];
        candidate = [base mutableCopy];
        // Missing preparation clears these fields, preserving unrelated metadata.
        candidate[@"TotalStorage"] = storageInfo[@"TotalStorage"];
        candidate[@"FreeStorage"] = storageInfo[@"FreeStorage"];
        candidate[@"FilesystemType"] = storageInfo[@"FilesystemType"];
        record = PXStorageFrozenRecord(candidate);
        [self publishStorageCache:record revision:revision];
    } @finally { record = nil; candidate = nil; base = nil; storageInfo = nil; prepared = nil; capacity = nil; profileID = nil; }
}

- (BOOL)loadFromProfile:(NSString *)profileId revision:(uint64_t)revision {
    NSString *profileDir = nil, *storagePath = nil;
    NSDictionary *savedSettings = nil, *record = nil;
    @try {
        profileId = [PXValidatedProfileID(profileId) copy];
        if (!profileId || ![self storageCacheRevisionIsCurrent:revision]) return NO;
        profileDir = PXProfileRootPath(profileId);
        storagePath = [profileDir stringByAppendingPathComponent:@"storage.plist"];
        savedSettings = [NSDictionary dictionaryWithContentsOfFile:storagePath];
        if (![self storageCacheRevisionIsCurrent:revision]) return NO;
        if (savedSettings) {
            record = PXStorageFrozenRecord(savedSettings);
            return record && [self publishStorageCache:record revision:revision];
        }
        [self setDefaultStorageForProfile:profileId revision:revision];
        return NO;
    } @finally { record = nil; savedSettings = nil; storagePath = nil; profileDir = nil; profileId = nil; }
}

- (BOOL)persistStorageRecord:(NSDictionary *)record revision:(uint64_t)revision profileID:(NSString *)profileID current:(BOOL)current error:(NSError **)error {
    NSString *explicitID = nil, *storagePath = nil;
    NSString *(^resolver)(void) = nil;
    BOOL (^writeBody)(PXRuntimeSourceTransaction *, NSError **) = nil;
    PXProfileArtifactMutation *mutation = nil;
    NSDictionary *prepared = nil;
    @try {
        if (![self storageCacheRevisionIsCurrent:revision]) return PXStorageSuperseded(error);
        explicitID = [PXValidatedProfileID(profileID) copy];
        {
            resolver = ^NSString *{
                NSDictionary *selection = nil;
                @try {
                    if (!current) return explicitID;
                    selection = [NSDictionary dictionaryWithContentsOfFile:PXCurrentProfileInfoPath()];
                    return PXValidatedProfileID(selection[@"ProfileId"]);
                } @finally { selection = nil; }
            };
        }
        mutation = [PXProfileArtifactMutation acquireWithProfileIDResolver:resolver error:error];
        resolver = nil;
        @try {
            if (!mutation) return NO;
            if (![self storageCacheRevisionIsCurrent:revision]) return PXStorageSuperseded(error);
            storagePath = [mutation.profileDirectory stringByAppendingPathComponent:@"storage.plist"];
            // Copy the retained entry record, never a newer cache root after lookup.
            prepared = [record copy];
            if (![self storageCacheRevisionIsCurrent:revision]) return PXStorageSuperseded(error);
            {
                // Finish stack-literal capture cleanup before the source call can throw.
                // The named heap callback stays strong until the enclosing finally.
                writeBody = ^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
                    @try {
                        if (![self storageCacheRevisionIsCurrent:revision]) return PXStorageSuperseded(writeError);
                        return [tx setDictionary:prepared atPath:storagePath error:writeError];
                    } @finally { tx = nil; }
                };
            }
            return [mutation performSourceWrite:writeBody error:error];
        } @finally { [mutation invalidate]; }
    } @finally { writeBody = nil; resolver = nil; prepared = nil; mutation = nil; storagePath = nil; explicitID = nil; record = nil; profileID = nil; }
}

- (void)loadFromCurrentProfile {
    uint64_t revision = [self beginStorageCacheWork];
    NSDictionary *currentProfileInfo = nil;
    NSString *profileId = nil;
    @try {
        currentProfileInfo = [NSDictionary dictionaryWithContentsOfFile:PXCurrentProfileInfoPath()];
        profileId = [PXValidatedProfileID(currentProfileInfo[@"ProfileId"]) copy];
        if (profileId) [self loadFromProfile:profileId revision:revision];
        else { profileId = PXActiveProfileID(); [self setDefaultStorageForProfile:profileId revision:revision]; }
    } @finally { profileId = nil; currentProfileInfo = nil; }
}

- (void)setDefaultStorage {
    uint64_t revision = [self beginStorageCacheWork];
    NSString *target = nil;
    @try { target = PXActiveProfileID(); [self setDefaultStorageForProfile:target revision:revision]; }
    @finally { target = nil; }
}

- (void)setDefaultStorageForProfile:(NSString *)profileID {
    uint64_t revision = [self beginStorageCacheWork];
    @try { [self setDefaultStorageForProfile:profileID revision:revision]; }
    @finally { profileID = nil; }
}

- (NSString *)randomizeStorageCapacity {
    NSString *target = nil;
    @try { target = PXActiveProfileID(); return [self randomizeStorageCapacityForProfile:target]; }
    @finally { target = nil; }
}

- (NSString *)randomizeStorageCapacityForProfile:(NSString *)profileID {
    NSString *target = nil, *path = nil;
    NSDictionary *deviceIDs = nil;
    @try {
        target = [PXValidatedProfileID(profileID) copy];
        if (profileID && !target) return nil;
        path = target.length ? [PXProfileIdentityPath(target) stringByAppendingPathComponent:@"device_ids.plist"] : nil;
        deviceIDs = path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
        return [self randomizeStorageCapacityForDeviceModel:deviceIDs[@"DeviceModel"]];
    } @finally { deviceIDs = nil; path = nil; target = nil; profileID = nil; }
}

- (NSString *)randomizeStorageCapacityForDeviceModel:(NSString *)deviceModel {
    IPhoneModelDB *modelDB = nil;
    id row = nil, canonical = nil, fallback = nil;
    NSDictionary *modelSpec = nil, *specs = nil, *cache = nil;
    NSArray *rawCapacities = nil;
    NSMutableArray<NSString *> *capacities = nil, *candidates = nil;
    NSString *previous = nil;
    @try {
        if (deviceModel && ![deviceModel isKindOfClass:NSString.class]) return nil;
        deviceModel = [deviceModel copy];
        modelDB = [IPhoneModelDB sharedManager];
        row = [modelDB specForProductType:deviceModel];
        modelSpec = [row isKindOfClass:NSDictionary.class] ? row : nil;
        canonical = modelSpec ? [modelDB canonicalHardwareSpecForProductType:deviceModel] : nil;
        specs = [canonical isKindOfClass:NSDictionary.class] ? canonical : nil;

        // Every iPhone is owned by the canonical model DB. Unknown/missing iPhone
        // records fail closed instead of falling back to ProductType-prefix heuristics.
        BOOL isIPhone = [deviceModel isKindOfClass:[NSString class]] && [deviceModel hasPrefix:@"iPhone"];
        if (isIPhone && (!modelSpec || !specs.count)) return nil;
        if (!specs.count) {
            fallback = [[DeviceModelManager sharedManager] deviceSpecificationsForModel:deviceModel];
            specs = [fallback isKindOfClass:NSDictionary.class] ? fallback : nil;
        }

        rawCapacities = [specs[@"storageCapacitiesGB"] isKindOfClass:[NSArray class]]
            ? specs[@"storageCapacitiesGB"] : @[@64, @128, @256, @512];
        capacities = [NSMutableArray array];
        for (id raw in rawCapacities) {
            NSInteger value = [raw respondsToSelector:@selector(integerValue)] ? [raw integerValue] : 0;
            if (value > 0) [capacities addObject:[NSString stringWithFormat:@"%ld", (long)value]];
        }
        if (!capacities.count) [capacities addObjectsFromArray:@[@"64", @"128", @"256", @"512"]];

        cache = [self currentStorageInfo];
        previous = PXStorageScalarField(cache, @"TotalStorage");
        candidates = capacities;
        if (capacities.count > 1 && previous.length) {
            candidates = [capacities mutableCopy];
            [candidates removeObject:previous];
            if (!candidates.count) candidates = capacities;
        }
        return candidates[arc4random_uniform((uint32_t)candidates.count)];
    } @finally {
        previous = nil; candidates = nil; capacities = nil; rawCapacities = nil; cache = nil;
        specs = nil; modelSpec = nil; fallback = nil; canonical = nil; row = nil; modelDB = nil; deviceModel = nil;
    }
}

- (NSDictionary *)generateStorageForCapacity:(NSString *)capacity {
    @try { return PXPrepareRuntimeStorage(capacity); }
    @finally { capacity = nil; }
}

- (NSDictionary *)currentStorageInfo {
    NSDictionary *root = nil, *snapshot = nil;
    @try {
        root = [self captureStorageCache:NULL];
        snapshot = [root copy];
        return [snapshot isKindOfClass:NSDictionary.class] ? snapshot : @{};
    } @finally { snapshot = nil; root = nil; }
}

- (void)adoptCommittedStorageInfo:(NSDictionary *)storageInfo {
    uint64_t observed = [self storageCacheRevision];
    NSDictionary *record = nil;
    @try {
        if (storageInfo && ![storageInfo isKindOfClass:NSDictionary.class]) return;
        record = PXStorageFrozenRecord(storageInfo);
        uint64_t revision = [self beginStorageCacheWorkIfRevision:observed];
        if (revision) [self publishStorageCache:record revision:revision];
    } @finally { record = nil; storageInfo = nil; }
}

#pragma mark - Basic Storage Values

- (NSString *)totalStorageCapacity {
    return PXStorageScalarField([self currentStorageInfo], @"TotalStorage");
}

- (NSString *)freeStorageSpace {
    return PXStorageScalarField([self currentStorageInfo], @"FreeStorage");
}

- (NSString *)filesystemType {
    return PXStorageScalarField([self currentStorageInfo], @"FilesystemType");
}

#pragma mark - Advanced Storage Values

- (uint64_t)totalStorageCapacityInBinaryBytes {
    // For backward compatibility, convert using marketing units
    NSString *totalGB = [self totalStorageCapacity];
    return [self convertGBStringToBytes:totalGB];
}

- (uint64_t)totalStorageCapacityInMarketingBytes {
    NSString *totalGB = [self totalStorageCapacity];
    return [self convertGBStringToBytes:totalGB];
}

- (uint64_t)freeStorageSpaceInBinaryBytes {
    // For backward compatibility, convert using marketing units
    NSString *freeGB = [self freeStorageSpace];
    return [self convertGBStringToBytes:freeGB];
}

- (uint64_t)freeStorageSpaceInMarketingBytes {
    NSString *freeGB = [self freeStorageSpace];
    return [self convertGBStringToBytes:freeGB];
}

- (uint64_t)normalizedTotalStorageForDisplay:(BOOL)useMarketingUnits {
    // useMarketingUnits parameter kept for backward compatibility
    uint64_t rawBytes = [self totalStorageCapacityInMarketingBytes];
    return [self normalizeStorageBytes:rawBytes];
}

- (uint64_t)normalizedFreeStorageForDisplay:(BOOL)useMarketingUnits {
    // useMarketingUnits parameter kept for backward compatibility
    return [self freeStorageSpaceInMarketingBytes];
}

#pragma mark - Unit Conversion Helpers

- (uint64_t)convertGBStringToBytes:(id)gbString {
    if (![gbString isKindOfClass:NSString.class] && ![gbString isKindOfClass:NSNumber.class]) return 0;
    double gbValue = [gbString doubleValue];
    if (!isfinite(gbValue) || gbValue <= 0) return 0;
    double bytes = gbValue * BYTES_PER_GB;
    // UINT64_MAX rounds to 2^64 as double. Reject that exclusive limit before
    // conversion rather than comparing against a rounded inclusive maximum.
    if (!isfinite(bytes) || bytes >= 0x1p64) return 0;
    return (uint64_t)bytes;
}

- (uint64_t)normalizeStorageBytes:(uint64_t)bytes {
    if (bytes == 0) return 0;

    // Values at the very top of uint64_t can round to the exclusive 2^64
    // boundary when converted to double. Do not normalize from an already
    // out-of-domain floating representation; preserve the exact byte count.
    double inputBytes = (double)bytes;
    if (!isfinite(inputBytes) || inputBytes >= 0x1p64) return bytes;
    
    // For user-facing displays, iOS rounds to nice numbers
    // System capacity is often shown as 64GB, 128GB, etc.
    
    // Get the GB value
    double gbValue = inputBytes / BYTES_PER_GB;
    
    // Round to nearest common capacity
    if (gbValue > 1000) {
        // For 1TB+ devices, round to nearest 128GB
        gbValue = round(gbValue / 128.0) * 128.0;
    } else if (gbValue > 500) {
        // For 512GB devices, round to nearest 64GB
        gbValue = round(gbValue / 64.0) * 64.0;
    } else if (gbValue > 200) {
        // For 256GB devices, round to nearest 64GB
        gbValue = round(gbValue / 32.0) * 32.0;
    } else if (gbValue > 100) {
        // For 128GB devices, round to nearest 16GB
        gbValue = round(gbValue / 16.0) * 16.0;
    } else if (gbValue > 50) {
        // For 64GB devices, round to nearest 8GB
        gbValue = round(gbValue / 8.0) * 8.0;
    } else {
        // For 64GB devices, round to nearest 4GB
        gbValue = round(gbValue / 4.0) * 4.0;
    }
    
    // Convert back to bytes
    double normalized = gbValue * BYTES_PER_GB;
    if (!isfinite(normalized) || normalized >= 0x1p64) return bytes;
    return (uint64_t)normalized;
}

// For backward compatibility - these methods are kept but simplified
- (uint64_t)convertGBStringToBytes:(id)gbString useBinaryUnits:(BOOL)useBinary {
    return [self convertGBStringToBytes:gbString];
}

- (uint64_t)normalizeStorageBytes:(uint64_t)bytes useMarketingUnits:(BOOL)useMarketingUnits {
    return [self normalizeStorageBytes:bytes];
}

#pragma mark - Storage Settings

- (void)setTotalStorageCapacity:(NSString *)capacity {
    @try { [self setStorageScalar:capacity key:@"TotalStorage"]; }
    @finally { capacity = nil; }
}

- (void)setFreeStorageSpace:(NSString *)freeSpace {
    @try { [self setStorageScalar:freeSpace key:@"FreeStorage"]; }
    @finally { freeSpace = nil; }
}

- (void)setFilesystemType:(NSString *)fsType {
    @try { [self setStorageScalar:fsType key:@"FilesystemType"]; }
    @finally { fsType = nil; }
}

#pragma mark - Profile Management

- (void)saveToCurrentProfile {
    NSError *error = nil;
    @try {
        if (![self persistStorageToProfile:nil current:YES error:&error])
            PXLog(@"[StorageManager] Failed to commit current storage: %@", error);
    } @finally { error = nil; }
}

- (void)saveToProfile:(NSString *)profileId {
    NSError *error = nil;
    @try {
        if (!profileId) return;
        if (![self persistStorageToProfile:profileId current:NO error:&error])
            PXLog(@"[StorageManager] Failed to commit storage for %@: %@", profileId, error);
    } @finally { error = nil; profileId = nil; }
}

- (BOOL)commitDisplayStorageInfo:(NSDictionary *)values updateFilesystem:(BOOL)updateFilesystem error:(NSError **)error {
    if (error) *error = nil;
    uint64_t observed = [self storageCacheRevision];
    NSDictionary *input = nil, *base = nil;
    id rawTotal = nil, rawFree = nil, rawFilesystem = nil;
    NSString *total = nil, *free = nil, *filesystem = nil, *path = nil;
    NSMutableDictionary *candidate = nil;
    __block NSDictionary *adoptable = nil;
    PXProfileArtifactMutation *mutation = nil;
    NSString *(^resolver)(void) = nil;
    BOOL (^writeBody)(PXRuntimeSourceTransaction *, NSError **) = nil;
    @try {
        if (![values isKindOfClass:NSDictionary.class]) {
            if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios.storage-display" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid storage display values"}];
            return NO;
        }
        input = [values copy];
        rawTotal = input[@"TotalStorage"]; rawFree = input[@"FreeStorage"]; rawFilesystem = input[@"FilesystemType"];
        if (![rawTotal isKindOfClass:NSString.class] || ![rawFree isKindOfClass:NSString.class] ||
            (updateFilesystem && rawFilesystem && ![rawFilesystem isKindOfClass:NSString.class])) {
            if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios.storage-display" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid storage display scalar"}];
            return NO;
        }
        total = [rawTotal copy]; free = [rawFree copy];
        filesystem = updateFilesystem ? [rawFilesystem copy] : nil;
        if (!PXPerformStandaloneRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **admissionError) {
            @try { (void)tx; (void)admissionError; return YES; } @finally { tx = nil; }
        }, error)) return NO;
        if (![self storageCacheRevisionIsCurrent:observed]) return PXStorageSuperseded(error);
        {
            resolver = ^NSString *{
                NSDictionary *selection = nil;
                @try {
                    selection = [NSDictionary dictionaryWithContentsOfFile:PXCurrentProfileInfoPath()];
                    return PXValidatedProfileID(selection[@"ProfileId"]);
                } @finally { selection = nil; }
            };
        }
        mutation = [PXProfileArtifactMutation acquireWithProfileIDResolver:resolver error:error];
        resolver = nil;
        @try {
            if (!mutation) return NO;
            uint64_t revision = [self beginStorageCacheWorkIfRevision:observed];
            if (!revision) return PXStorageSuperseded(error);
            base = [self currentStorageInfo];
            if (![self storageCacheRevisionIsCurrent:revision]) return PXStorageSuperseded(error);
            if (![base isKindOfClass:NSDictionary.class]) {
                if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios.storage-display" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Invalid storage cache root"}];
                return NO;
            }
            candidate = [base mutableCopy];
            candidate[@"TotalStorage"] = total; candidate[@"FreeStorage"] = free;
            if (updateFilesystem) candidate[@"FilesystemType"] = filesystem;
            path = [mutation.profileDirectory stringByAppendingPathComponent:@"storage.plist"];
            {
                writeBody = ^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
                    NSDictionary *staged = nil;
                    @try {
                        if (![self storageCacheRevisionIsCurrent:revision]) return PXStorageSuperseded(writeError);
                        if (![tx setDictionary:candidate atPath:path error:writeError]) return NO;
                        staged = [tx dictionaryAtPath:path error:writeError];
                        if (!staged) return NO;
                        adoptable = PXStorageFrozenRecord(staged);
                        return adoptable != nil;
                    } @finally { staged = nil; tx = nil; }
                };
            }
            BOOL committed = [mutation performSourceWrite:writeBody error:error];
            if (!committed) return NO;
            // A newer cache intent cannot be undone by this acknowledged commit.
            [self publishStorageCache:adoptable revision:revision];
            return YES;
        } @finally { [mutation invalidate]; }
    } @finally {
        writeBody = nil; resolver = nil; mutation = nil; adoptable = nil; candidate = nil;
        path = nil; filesystem = nil; free = nil; total = nil;
        rawFilesystem = nil; rawFree = nil; rawTotal = nil; base = nil; input = nil; values = nil;
    }
}

- (BOOL)persistStorageToProfile:(NSString *)profileID current:(BOOL)current error:(NSError **)error {
    uint64_t revision = 0;
    NSDictionary *record = nil;
    @try {
        record = [self captureStorageCache:&revision];
        return [self persistStorageRecord:record revision:revision profileID:profileID current:current error:error];
    } @finally { record = nil; profileID = nil; }
}

- (BOOL)loadFromProfile:(NSString *)profileId {
    uint64_t revision = [self beginStorageCacheWork];
    @try { return [self loadFromProfile:profileId revision:revision]; }
    @finally { profileId = nil; }
}

#pragma mark - Status Control

- (BOOL)isStorageSpoofingEnabled {
    @synchronized (self) { return _isEnabled; }
}

- (void)setStorageSpoofingEnabled:(BOOL)enabled {
    NSError *error = nil;
    if (![self setStorageSpoofingEnabled:enabled error:&error])
        PXLog(@"[StorageManager] Failed to commit storage enable flag: %@", error);
}

- (BOOL)setStorageSpoofingEnabled:(BOOL)enabled error:(NSError **)error {
    if (error) *error = nil;
    // Admit one writer without holding an object monitor across source I/O or
    // compatibility callbacks. Reentry must fail instead of waiting on itself.
    @synchronized (self) {
        if (_storagePreferenceWriteInFlight) {
            if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios.storage-preference" code:1
                userInfo:@{NSLocalizedDescriptionKey: @"Storage preference write is busy"}];
            return NO;
        }
        _storagePreferenceWriteInFlight = YES;
    }
    @try {
        NSString *path = PXTLinkIOSSettingsPath();
        BOOL committed = PXPerformStandaloneRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
            NSDictionary *existing = [tx dictionaryAtPath:path error:writeError];
            if (!existing) return NO;
            NSMutableDictionary *candidate = [existing mutableCopy];
            candidate[@"StorageSystemEnabled"] = @(enabled);
            return [tx setDictionary:candidate atPath:path error:writeError];
        }, error);
        if (!committed) return NO;
        @synchronized (self) { _isEnabled = enabled; }
        // Preserve the old suite and key. A mirror exception cannot turn an
        // acknowledged primary commit into an aborted source operation.
        @try {
            NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.hydra.tlinkios.settings"];
            [defaults setBool:enabled forKey:@"StorageSystemEnabled"];
            [defaults synchronize];
        } @catch (NSException *exception) {
            PXLog(@"[StorageManager] Storage flag committed; defaults mirror failed: %@", exception);
        }
        return YES;
    } @finally {
        @synchronized (self) { _storagePreferenceWriteInFlight = NO; }
    }
}

@end
