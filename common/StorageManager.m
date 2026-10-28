#import "StorageManager.h"
#import "PXRuntimeArtifactPreparation.h"
#import "ProfileManager.h"
#import "TLinkIOSLogging.h"
#import "PXPaths.h"
#import "PXProfileArtifactMutation.h"
#import "PXRuntimeSourceStore.h"
#import "DeviceModelManager.h"
#import "IPhoneModelDB.h"

// Constants for proper size calculations
// Use only marketing units (1000-based) as used by Apple
#define BYTES_PER_KB (1000ULL)
#define BYTES_PER_MB (1000ULL * 1000ULL)
#define BYTES_PER_GB (1000ULL * 1000ULL * 1000ULL)
#define BYTES_PER_TB (1000ULL * 1000ULL * 1000ULL * 1000ULL)

// Standard APFS block size
#define DEFAULT_BLOCK_SIZE (4096ULL)

@interface StorageManager ()
- (BOOL)persistStorageToProfile:(NSString *)profileID current:(BOOL)current error:(NSError **)error;
@end

@implementation StorageManager {
    NSMutableDictionary *_storageSettings;
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
        _storageSettings = [NSMutableDictionary dictionary];
        
        // Load from settings
        NSUserDefaults *defaults = [[NSUserDefaults alloc] 
                                   initWithSuiteName:@"com.hydra.tlinkios.settings"];
        _isEnabled = [defaults boolForKey:@"StorageSystemEnabled"];
        
        // Load current profile
        [self loadFromCurrentProfile];
    }
    return self;
}

- (void)loadFromCurrentProfile {
    // Get active profile ID
    NSString *profilesPath = PXCurrentProfileInfoPath();
    NSDictionary *currentProfileInfo = [NSDictionary dictionaryWithContentsOfFile:profilesPath];
    
    if (currentProfileInfo && currentProfileInfo[@"ProfileId"]) {
        NSString *profileId = currentProfileInfo[@"ProfileId"];
        [self loadFromProfile:profileId];
    } else {
        // Default values if no profile
        [self setDefaultStorage];
    }
}

- (void)setDefaultStorage {
    // Use the storage generation method to ensure consistent values
    NSString *capacity = [self randomizeStorageCapacity];
    NSDictionary *storageInfo = [self generateStorageForCapacity:capacity];
    
    _storageSettings[@"TotalStorage"] = storageInfo[@"TotalStorage"];
    _storageSettings[@"FreeStorage"] = storageInfo[@"FreeStorage"];
    _storageSettings[@"FilesystemType"] = storageInfo[@"FilesystemType"];
}

- (NSString *)randomizeStorageCapacity {
    NSString *profileID = PXActiveProfileID();
    NSDictionary *deviceIDs = profileID.length ?
        [NSDictionary dictionaryWithContentsOfFile:[PXProfileIdentityPath(profileID) stringByAppendingPathComponent:@"device_ids.plist"]] : nil;
    return [self randomizeStorageCapacityForDeviceModel:deviceIDs[@"DeviceModel"]];
}

- (NSString *)randomizeStorageCapacityForDeviceModel:(NSString *)deviceModel {
    IPhoneModelDB *modelDB = [IPhoneModelDB sharedManager];
    NSDictionary *modelSpec = [modelDB specForProductType:deviceModel];
    NSDictionary *specs = modelSpec ? [modelDB canonicalHardwareSpecForProductType:deviceModel] : nil;

    // Every iPhone is owned by the canonical model DB. Unknown/missing iPhone
    // records fail closed instead of falling back to ProductType-prefix heuristics.
    BOOL isIPhone = [deviceModel isKindOfClass:[NSString class]] && [deviceModel hasPrefix:@"iPhone"];
    if (isIPhone && (!modelSpec || !specs.count)) return nil;
    if (!specs.count) specs = [[DeviceModelManager sharedManager] deviceSpecificationsForModel:deviceModel];

    NSArray *rawCapacities = [specs[@"storageCapacitiesGB"] isKindOfClass:[NSArray class]]
        ? specs[@"storageCapacitiesGB"] : @[@64, @128, @256, @512];
    NSMutableArray<NSString *> *capacities = [NSMutableArray array];
    for (id raw in rawCapacities) {
        NSInteger value = [raw respondsToSelector:@selector(integerValue)] ? [raw integerValue] : 0;
        if (value > 0) [capacities addObject:[NSString stringWithFormat:@"%ld", (long)value]];
    }
    if (!capacities.count) [capacities addObjectsFromArray:@[@"64", @"128", @"256", @"512"]];

    NSString *previous = _storageSettings[@"TotalStorage"];
    NSMutableArray<NSString *> *candidates = [capacities mutableCopy];
    if (candidates.count > 1 && previous.length) [candidates removeObject:previous];
    if (!candidates.count) candidates = [capacities mutableCopy];
    return candidates[arc4random_uniform((uint32_t)candidates.count)];
}

- (NSDictionary *)generateStorageForCapacity:(NSString *)capacity {
    return PXPrepareRuntimeStorage(capacity);
}

- (NSDictionary *)currentStorageInfo {
    return [_storageSettings copy] ?: @{};
}

- (void)adoptCommittedStorageInfo:(NSDictionary *)storageInfo {
    _storageSettings = [storageInfo mutableCopy];
}

#pragma mark - Basic Storage Values

- (NSString *)totalStorageCapacity {
    return _storageSettings[@"TotalStorage"];
}

- (NSString *)freeStorageSpace {
    // Get the base free space
    NSString *baseSpace = _storageSettings[@"FreeStorage"];
    
    // Return the exact value without random variations to ensure consistency
    return baseSpace;
}

- (NSString *)filesystemType {
    return _storageSettings[@"FilesystemType"];
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

- (uint64_t)convertGBStringToBytes:(NSString *)gbString {
    if (!gbString) return 0;
    
    double gbValue = [gbString doubleValue];
    if (gbValue <= 0) return 0;
    
    // Use only marketing (1000-based) conversion
    return (uint64_t)(gbValue * BYTES_PER_GB);
}

- (uint64_t)normalizeStorageBytes:(uint64_t)bytes {
    if (bytes == 0) return 0;
    
    // For user-facing displays, iOS rounds to nice numbers
    // System capacity is often shown as 64GB, 128GB, etc.
    
    // Get the GB value
    double gbValue = (double)bytes / BYTES_PER_GB;
    
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
    return (uint64_t)(gbValue * BYTES_PER_GB);
}

// For backward compatibility - these methods are kept but simplified
- (uint64_t)convertGBStringToBytes:(NSString *)gbString useBinaryUnits:(BOOL)useBinary {
    return [self convertGBStringToBytes:gbString];
}

- (uint64_t)normalizeStorageBytes:(uint64_t)bytes useMarketingUnits:(BOOL)useMarketingUnits {
    return [self normalizeStorageBytes:bytes];
}

#pragma mark - Storage Settings

- (void)setTotalStorageCapacity:(NSString *)capacity {
    _storageSettings[@"TotalStorage"] = capacity;
    [self saveToCurrentProfile];
}

- (void)setFreeStorageSpace:(NSString *)freeSpace {
    _storageSettings[@"FreeStorage"] = freeSpace;
    [self saveToCurrentProfile];
}

- (void)setFilesystemType:(NSString *)fsType {
    _storageSettings[@"FilesystemType"] = fsType;
    [self saveToCurrentProfile];
}

#pragma mark - Profile Management

- (void)saveToCurrentProfile {
    NSError *error = nil;
    if (![self persistStorageToProfile:nil current:YES error:&error])
        PXLog(@"[StorageManager] Failed to commit current storage: %@", error);
}

- (void)saveToProfile:(NSString *)profileId {
    if (!profileId) return;
    NSError *error = nil;
    if (![self persistStorageToProfile:profileId current:NO error:&error])
        PXLog(@"[StorageManager] Failed to commit storage for %@: %@", profileId, error);
}

- (BOOL)persistStorageToProfile:(NSString *)profileID current:(BOOL)current error:(NSError **)error {
    NSString *explicitID = PXValidatedProfileID(profileID);
    PXProfileArtifactMutation *mutation = [PXProfileArtifactMutation acquireWithProfileIDResolver:^NSString *{
        // Preserve the canonical selection-file authority of the old current
        // writer. Resolve once, only after lifecycle ownership is acquired.
        if (!current) return explicitID;
        NSDictionary *selection = [NSDictionary dictionaryWithContentsOfFile:PXCurrentProfileInfoPath()];
        return PXValidatedProfileID(selection[@"ProfileId"]);
    } error:error];
    @try {
        if (!mutation) return NO;
        NSString *storagePath = [mutation.profileDirectory stringByAppendingPathComponent:@"storage.plist"];
        NSDictionary *prepared = [_storageSettings copy];
        return [mutation performSourceWrite:^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
            return [tx setDictionary:prepared atPath:storagePath error:writeError];
        } error:error];
    } @finally { [mutation invalidate]; }
}

- (BOOL)loadFromProfile:(NSString *)profileId {
    if (!profileId) return NO;
    
    NSString *profileDir = PXProfileRootPath(profileId);
    NSString *storagePath = [profileDir stringByAppendingPathComponent:@"storage.plist"];
    
    NSDictionary *savedSettings = [NSDictionary dictionaryWithContentsOfFile:storagePath];
    if (savedSettings) {
        [_storageSettings removeAllObjects];
        [_storageSettings addEntriesFromDictionary:savedSettings];
        return YES;
    }
    
    // If no saved settings, use defaults
    [self setDefaultStorage];
    return NO;
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
