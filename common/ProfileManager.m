#import "ProfileManager.h"
#import <UIKit/UIKit.h>
#import "ContainerManager.h"
#import "PXPaths.h"
#import "PXRuntimeProfileSelection.h"
#import "PXRuntimeGeneration.h"
#import "PXProfileCreationReservation.h"
#import "PXProfileLifecycleLease.h"
#import "PXProfileDeletionJournal.h"
#import "PXProfileMetadataWriter.h"
#import "PXDefaultProfileSeed.h"
#import "NetworkManager.h"
#import <spawn.h>
#import <sys/wait.h>
#include <errno.h>

// Forward declaration for app termination
@interface BottomButtons : NSObject
+ (instancetype)sharedInstance;
- (void)terminateApplicationWithBundleID:(NSString *)bundleID;
- (void)killAppViaExecutableName:(NSString *)bundleID;
@end

@interface SBSRelaunchAction : NSObject
+ (id)actionWithReason:(NSString *)reason options:(unsigned int)options targetURL:(NSURL *)targetURL;
@end

@interface FBSSystemService : NSObject
+ (id)sharedService;
- (void)sendActions:(NSSet *)actions withResult:(id)result;
@end

@interface IdentifierManager : NSObject
+ (instancetype)sharedManager;
- (BOOL)isApplicationEnabled:(NSString *)bundleID;
- (NSDictionary *)getApplicationInfo:(NSString *)bundleID;
- (BOOL)regenerateAllEnabledIdentifiersForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)networkArtifacts error:(NSError **)error;
- (PXCommittedRuntimeGeneration *)commitRuntimeGenerationForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)networkArtifacts error:(NSError **)error;
- (PXCommittedRuntimeGeneration *)commitRuntimeGenerationForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)networkArtifacts lifecycleLease:(PXProfileLifecycleLease *)lease error:(NSError **)error;
- (void)publishCommittedRuntimeGeneration:(PXCommittedRuntimeGeneration *)generation;
- (void)resetCanvasNoise;
@end

@interface LSApplicationProxy : NSObject
+ (id)applicationProxyForIdentifier:(id)identifier;
@property(readonly) NSString *bundleExecutable;
@end

@interface ProfileManager ()

@property (nonatomic, strong) NSMutableArray<Profile *> *mutableProfiles;
@property (nonatomic, strong) Profile *mutableCurrentProfile;
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) NSString *profilesDirectory;
// These entry points marshal mutations to main. The flag covers async creation;
// it is not a cross-process profile-directory transaction.
@property (nonatomic) BOOL creationInProgress;
@property (nonatomic, strong) PXProfileCreationReservation *creationReservation;
@property (nonatomic, strong) PXProfileLifecycleLease *lifecycleLease;
@property (nonatomic, copy) NSDictionary *registryRecord;
@property (nonatomic) BOOL deletionRecoveryNoticePending;
@property (nonatomic) BOOL didLoadCommittedProfiles;
@property (nonatomic) BOOL selectionUnavailable;
@property (nonatomic) BOOL registryUnavailable;
- (NSDictionary *)prepareNetworkArtifactsWithOptions:(NSDictionary *)options error:(NSError **)error;
- (NSDictionary *)captureProfileNetworkOptions;
- (BOOL)persistProfileSelectionInfo:(NSDictionary *)info error:(NSError **)error;
- (void)mirrorCurrentProfileID:(NSString *)profileID;
- (void)publishProfileChangedNotification;
- (NSDictionary *)captureProfileSelectionWithError:(NSError **)error;
- (NSString *)identityForActivationProfile:(Profile *)profile generation:(PXCommittedRuntimeGeneration *)generation error:(NSError **)error;
- (BOOL)bootstrapProfileSelectionWithError:(NSError **)error;
- (void)scheduleProfileMirrorForSelection:(NSDictionary *)expected;
- (BOOL)validateActivationForProfile:(Profile *)profile expectedSelection:(NSDictionary *)expected generation:(PXCommittedRuntimeGeneration *)generation error:(NSError **)error;
- (BOOL)activateProfile:(Profile *)profile expectedSelection:(NSDictionary *)expected generation:(PXCommittedRuntimeGeneration *)generation error:(NSError **)error;
- (void)finishProfileCreation:(Profile *)profile targetID:(NSString *)targetID generation:(PXCommittedRuntimeGeneration *)generation expectedSelection:(NSDictionary *)expected error:(NSError *)generationError completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (BOOL)beginProfileOperationWithError:(NSError **)error;
- (void)endProfileOperation;
- (NSArray<Profile *> *)decodeRegistryRecord:(NSDictionary *)record error:(NSError **)error;
- (NSDictionary *)preparedRegistryRecordForProfiles:(NSArray<Profile *> *)profiles error:(NSError **)error;
- (BOOL)validateDeletionArchives:(NSDictionary *)intent error:(NSError **)error;
- (BOOL)registryValue:(id)before matchesValue:(id)after seen:(NSMapTable *)seen;
- (BOOL)registryValue:(id)before matchesValue:(id)after seen:(NSMapTable *)seen allowLegacyDates:(BOOL)allowLegacyDates;
- (BOOL)activationProfile:(Profile *)profile matchesRegistry:(NSDictionary *)record error:(NSError **)error;
- (BOOL)updateProfileUnderLease:(Profile *)profile index:(NSUInteger)index error:(NSError **)error;
- (BOOL)createProfileZeroWithError:(NSError **)error;
- (Profile *)detachedProfileForCreation:(Profile *)profile expectedID:(NSString *)expectedID error:(NSError **)error;
- (BOOL)deleteRegisteredProfileID:(NSString *)targetID selectionChanged:(BOOL *)selectionChanged error:(NSError **)error;
- (void)loadProfilesUnderLeaseWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion;

@end

static NSSet<Class> *PXProfileArchiveClasses(void) {
    static NSSet *classes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ classes = [NSSet setWithArray:@[NSArray.class, NSDictionary.class,
        NSString.class, NSNumber.class, NSDate.class, NSData.class, Profile.class]]; });
    return classes;
}

@interface Profile ()
// Transient decode provenance; never encoded or exposed as profile settings.
@property (nonatomic) BOOL pxDecodedMissingCreatedAt;
@property (nonatomic) BOOL pxDecodedMissingLastUsed;
@end

@implementation Profile

@synthesize profileId = _profileId;

- (instancetype)initWithName:(NSString *)name iconName:(NSString *)iconName {
    self = [super init];
    if (self) {
        // UUID is no longer used, but will be set by ProfileManager via setter
        _profileId = [[NSUUID UUID] UUIDString];
        _name = name;
        _iconName = iconName;
        _createdAt = [NSDate date];
        _lastUsed = [NSDate date];
        _settings = @{};
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name shortDescription:(NSString *)shortDescription iconName:(NSString *)iconName {
    self = [super init];
    if (self) {
        // UUID is no longer used, but will be set by ProfileManager via setter
        _profileId = [[NSUUID UUID] UUIDString];
        _name = name;
        _shortDescription = shortDescription;
        _iconName = iconName;
        _createdAt = [NSDate date];
        _lastUsed = [NSDate date];
        _settings = @{};
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        _profileId = dictionary[@"profileId"];
        _name = dictionary[@"name"];
        _shortDescription = dictionary[@"shortDescription"];
        _iconName = dictionary[@"iconName"];
        _createdAt = dictionary[@"createdAt"];
        _lastUsed = dictionary[@"lastUsed"];
        _settings = dictionary[@"settings"] ?: @{};
        
        // If timestamps are missing, set them to current time
        NSDate *now = [NSDate date];
        if (!_createdAt) {
            NSLog(@"[WeaponX] Setting missing createdAt timestamp for profile: %@", _name);
            _createdAt = now;
        }
        if (!_lastUsed) {
            NSLog(@"[WeaponX] Setting missing lastUsed timestamp for profile: %@", _name);
            _lastUsed = now;
        }
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:@{
        @"profileId": self.profileId,
        @"name": self.name,
        @"iconName": self.iconName,
        @"createdAt": self.createdAt,
        @"lastUsed": self.lastUsed,
        @"settings": self.settings
    }];
    
    if (self.shortDescription) {
        dict[@"shortDescription"] = self.shortDescription;
    }
    
    return dict;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.profileId forKey:@"profileId"];
    [coder encodeObject:self.name forKey:@"name"];
    [coder encodeObject:self.shortDescription forKey:@"shortDescription"];
    [coder encodeObject:self.iconName forKey:@"iconName"];
    [coder encodeObject:self.createdAt forKey:@"createdAt"];
    [coder encodeObject:self.lastUsed forKey:@"lastUsed"];
    [coder encodeObject:self.settings forKey:@"settings"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _profileId = [coder decodeObjectOfClass:[NSString class] forKey:@"profileId"];
        // Some legacy keys are optional. Decoding an absent key can poison
        // the unarchiver, so apply existing nil/date/settings defaults without
        // issuing a decode request. Present invalid values still fail normally.
        _name = [coder decodeObjectOfClass:[NSString class] forKey:@"name"];
        _shortDescription = [coder containsValueForKey:@"shortDescription"] ? [coder decodeObjectOfClass:[NSString class] forKey:@"shortDescription"] : nil;
        _iconName = [coder decodeObjectOfClass:[NSString class] forKey:@"iconName"];
        _createdAt = [coder containsValueForKey:@"createdAt"] ? [coder decodeObjectOfClass:[NSDate class] forKey:@"createdAt"] : nil;
        _lastUsed = [coder containsValueForKey:@"lastUsed"] ? [coder decodeObjectOfClass:[NSDate class] forKey:@"lastUsed"] : nil;
        _settings = [coder containsValueForKey:@"settings"] ? [coder decodeObjectOfClasses:PXProfileArchiveClasses() forKey:@"settings"] : nil;
        // The outer allowed-classes set is intentionally broad for nested
        // settings. Check individual field types before applying legacy defaults.
        BOOL validFields = (!_name || [_name isKindOfClass:NSString.class]) &&
            (!_shortDescription || [_shortDescription isKindOfClass:NSString.class]) &&
            (!_iconName || [_iconName isKindOfClass:NSString.class]) &&
            (!_createdAt || [_createdAt isKindOfClass:NSDate.class]) &&
            (!_lastUsed || [_lastUsed isKindOfClass:NSDate.class]) &&
            (!_settings || [_settings isKindOfClass:NSDictionary.class]);
        if (!validFields) [coder failWithError:[NSError errorWithDomain:@"WeaponXProfileError" code:24
            userInfo:@{NSLocalizedDescriptionKey: @"Invalid encoded profile field type"}]];
        
        // If timestamps are missing, set them to current time
        if (!_createdAt) {
            _pxDecodedMissingCreatedAt = YES;
            NSLog(@"[WeaponX] Setting missing createdAt timestamp for profile: %@", _name);
            _createdAt = [NSDate date];
        }
        if (!_lastUsed) {
            _pxDecodedMissingLastUsed = YES;
            NSLog(@"[WeaponX] Setting missing lastUsed timestamp for profile: %@", _name);
            _lastUsed = [NSDate date];
        }
        
        // Ensure settings exists
        if (![_settings isKindOfClass:NSDictionary.class]) {
            _settings = @{};
        }
    }
    return self;
}

@end

@implementation ProfileManager

+ (instancetype)sharedManager {
    static ProfileManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[ProfileManager alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableProfiles = [NSMutableArray array];
        _registryUnavailable = YES;
        _fileManager = [NSFileManager defaultManager];
        
        // Use the specified jailbreak directory structure
        _profilesDirectory = PXProfilesPath();
        
        NSLog(@"[WeaponX] 📁 Using profiles directory: %@", _profilesDirectory);
        
        // Create main WeaponX directory if it doesn't exist
        NSString *weaponXDirectory = PXWeaponXBasePath();
        [self createDirectoryIfNeeded:weaponXDirectory];
        
        // Create profiles directory if it doesn't exist
        [self createDirectoryIfNeeded:_profilesDirectory];
        
        // Repair/create only profile 0's directory, never overwrite an existing
        // selection or reset an existing identity merely because 0 was missing.
        if (![_fileManager fileExistsAtPath:[_profilesDirectory stringByAppendingPathComponent:@"0"]])
            [self createProfileZeroImmediately];
        NSError *bootstrapError = nil;
        if (![self bootstrapProfileSelectionWithError:&bootstrapError]) NSLog(@"[ProfileManager] Bootstrap selection unavailable: %@", bootstrapError);
        [self loadProfilesWithCompletion:^(BOOL success, NSError *error) {
            if (!success) NSLog(@"[ProfileManager] Could not restore profiles: %@", error);
        }];
    }
    return self;
}

- (void)createDirectoryIfNeeded:(NSString *)directory {
    if (![_fileManager fileExistsAtPath:directory]) {
        NSError *error = nil;
        NSDictionary *attributes = @{
            NSFilePosixPermissions: @0755,
            NSFileOwnerAccountName: @"mobile",
            NSFileGroupOwnerAccountName: @"mobile"
        };
        
        [_fileManager createDirectoryAtPath:directory
               withIntermediateDirectories:YES
                                attributes:attributes
                                     error:&error];
        if (error) {
            NSLog(@"[WeaponX] ❌ Failed to create directory %@: %@", directory, error);
        } else {
            // Set permissions using NSFileManager
            [_fileManager setAttributes:@{NSFilePosixPermissions: @0755}
                         ofItemAtPath:directory
                              error:&error];
            if (error) {
                NSLog(@"[WeaponX] ⚠️ Failed to set directory permissions: %@", error);
            }
            NSLog(@"[WeaponX] ✅ Created directory: %@", directory);
        }
    }
}

#pragma mark - Public Properties

- (NSArray<Profile *> *)profiles {
    return [self.mutableProfiles copy];
}

- (Profile *)currentProfile {
    if (self.selectionUnavailable || self.registryUnavailable) return nil;
    if (self.mutableCurrentProfile) return self.mutableCurrentProfile;
    Profile *stored = [self loadCurrentProfileInfoFromCentralStore];
    if (stored) self.mutableCurrentProfile = stored;
    return stored; // A getter must not choose/write a fallback over committed state.
}

#pragma mark - Public Methods

- (BOOL)beginProfileOperationWithError:(NSError **)error {
    if (!NSThread.isMainThread || self.creationInProgress || self.lifecycleLease) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:12 userInfo:@{NSLocalizedDescriptionKey: @"Another profile operation is in progress"}]; return NO;
    }
    PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:self.profilesDirectory error:error];
    if (!lease || !PXRequireNoPendingProfileDeletion(error)) return NO;
    NSDictionary *observed = [lease readRegistryWithError:error];
    if (!observed) return NO;
    NSDictionary *expected = self.registryRecord ?: @{ @"exists": @NO };
    if (![expected isEqual:observed]) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:25 userInfo:@{NSLocalizedDescriptionKey: @"Profile registry changed; reload the list before changing profiles"}]; return NO;
    }
    self.registryRecord = observed;
    self.lifecycleLease = lease;
    self.creationInProgress = YES;
    return YES;
}

- (void)endProfileOperation {
    self.creationReservation = nil;
    [self.lifecycleLease invalidate];
    self.lifecycleLease = nil;
    self.creationInProgress = NO;
}

- (Profile *)detachedProfileForCreation:(Profile *)profile expectedID:(NSString *)expectedID error:(NSError **)error {
    if (error) *error = nil;
    @try {
        if ([profile isKindOfClass:Profile.class]) {
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:profile requiringSecureCoding:YES error:error];
            if (!data) return nil;
            NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:error];
            if (!decoder) return nil;
            decoder.requiresSecureCoding = YES;
            id decoded = [decoder decodeObjectOfClasses:PXProfileArchiveClasses() forKey:NSKeyedArchiveRootObjectKey];
            [decoder finishDecoding];
            if (decoder.error) { if (error) *error = decoder.error; return nil; }
            if ([decoded isKindOfClass:Profile.class] && decoded != profile &&
                [[decoded profileId] isEqual:expectedID] && [[decoded name] isKindOfClass:NSString.class] && [[decoded name] length]) return decoded;
        }
    } @catch (NSException *exception) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:30 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Could not capture creation profile"}];
        return nil;
    }
    if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:30 userInfo:@{NSLocalizedDescriptionKey: @"Creation profile could not be detached or its target changed"}];
    return nil;
}

- (void)createProfile:(Profile *)profile completion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self createProfile:profile completion:completion]; });
        return;
    }
    if (self.selectionUnavailable || self.registryUnavailable) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:23 userInfo:@{NSLocalizedDescriptionKey: @"Reload a valid profile selection and registry before changing profiles"}]); return;
    }
    if (self.creationInProgress) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:12
            userInfo:@{NSLocalizedDescriptionKey: @"Profile creation is still in progress; retry when it completes"}]);
        return;
    }

    // Validate profile name
    if (![profile isKindOfClass:Profile.class] || ![profile.name isKindOfClass:NSString.class] || profile.name.length == 0) {
        NSError *error = [NSError errorWithDomain:@"WeaponXProfileError" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Profile name cannot be empty"}];
        if (completion) completion(NO, error);
        return;
    }
    NSLog(@"[WeaponX] 📝 Creating new profile: %@", profile.name);
    
    // Check for duplicate names
    for (Profile *existingProfile in self.mutableProfiles) {
        if ([existingProfile.name isEqualToString:profile.name]) {
            NSError *error = [NSError errorWithDomain:@"WeaponXProfileError" code:2 userInfo:@{NSLocalizedDescriptionKey: @"A profile with this name already exists"}];
            if (completion) completion(NO, error);
            return;
        }
    }
    
    NSError *operationError = nil;
    if (![self beginProfileOperationWithError:&operationError]) { if (completion) completion(NO, operationError); return; }
    PXProfileCreationReservation *reservation = nil;
    Profile *creationProfile = nil;
    NSDictionary *expected = nil, *networkOptions = nil;
    NSString *targetID = nil;
    NSError *preparationError = nil;
    @try {
        NSString *profileID = [self generateProfileID];
        [profile setValue:profileID forKey:@"profileId"];
        profile.createdAt = profile.lastUsed = NSDate.date;
        creationProfile = [self detachedProfileForCreation:profile expectedID:profileID error:&preparationError];
        // Do not reserve a path or start providers for an uncapturable model.
        if (creationProfile) {
            NSDictionary *identifiers = @{ @"DisplayName": creationProfile.name,
                @"Description": creationProfile.shortDescription ?: [NSString stringWithFormat:@"Profile ID: %@", profileID], @"Identifier": profileID };
            NSError *reservationError = nil;
            reservation = [PXProfileCreationReservation reserveProfileID:creationProfile.profileId
                inProfilesDirectory:self.profilesDirectory metadata:identifiers error:&reservationError];
            if (!reservation) {
                BOOL conflict = [reservationError.domain isEqualToString:@"WeaponXProfileDirectoryError"] &&
                    (reservationError.code == EEXIST || reservationError.code == EINVAL);
                NSMutableDictionary *info = [@{NSLocalizedDescriptionKey: conflict ?
                    @"New profile ID is invalid or its directory already exists" : @"Could not initialize the new profile directory"} mutableCopy];
                if (reservationError) info[NSUnderlyingErrorKey] = reservationError;
                preparationError = [NSError errorWithDomain:@"WeaponXProfileError" code:(conflict ? 13 : 11) userInfo:info];
            } else {
                expected = [self captureProfileSelectionWithError:&preparationError];
                if (expected) {
                    targetID = [creationProfile.profileId copy];
                    networkOptions = [self captureProfileNetworkOptions];
                }
            }
        }
    } @catch (NSException *exception) {
        preparationError = [NSError errorWithDomain:@"WeaponXProfileError" code:15 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Profile preparation raised an exception"}];
    }
    if (preparationError || !creationProfile || !reservation || !expected || !networkOptions || !targetID) {
        [self endProfileOperation];
        if (!preparationError) preparationError = [NSError errorWithDomain:@"WeaponXProfileError" code:11 userInfo:@{NSLocalizedDescriptionKey: @"Profile preparation did not complete"}];
        if (completion) completion(NO, preparationError); return;
    }
    // No registration/selection/cache effects until inactive generation commits.
    self.creationReservation = reservation;
    PXProfileLifecycleLease *generationLease = self.lifecycleLease;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            NSError *generationError = nil;
            PXCommittedRuntimeGeneration *generation = nil;
            @try {
                NSDictionary *network = [reservation validateWithError:&generationError] ?
                    [self prepareNetworkArtifactsWithOptions:networkOptions error:&generationError] : nil;
                IdentifierManager *manager = [IdentifierManager sharedManager];
                if (network && [reservation validateWithError:&generationError] &&
                    [manager respondsToSelector:@selector(commitRuntimeGenerationForProfileID:networkArtifacts:lifecycleLease:error:)])
                    generation = [manager commitRuntimeGenerationForProfileID:targetID networkArtifacts:network lifecycleLease:generationLease error:&generationError];
                if (!generation && !generationError) generationError = [NSError errorWithDomain:@"WeaponXProfileError" code:14
                    userInfo:@{NSLocalizedDescriptionKey: @"Inactive profile generation did not complete"}];
            } @catch (NSException *exception) {
                generationError = [NSError errorWithDomain:@"WeaponXProfileError" code:15
                    userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Profile generation raised an exception"}];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self finishProfileCreation:creationProfile targetID:targetID generation:generation expectedSelection:expected error:generationError completion:completion];
            });
        }
    });
}

- (void)finishProfileCreation:(Profile *)profile targetID:(NSString *)targetID generation:(PXCommittedRuntimeGeneration *)generation expectedSelection:(NSDictionary *)expected error:(NSError *)generationError completion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    NSError *failure = generationError;
    if (!generation || ![profile.profileId isEqualToString:targetID] ||
        ![self validateActivationForProfile:profile expectedSelection:expected generation:generation error:&failure]) {
        [self endProfileOperation];
        if (!failure) failure = [NSError errorWithDomain:@"WeaponXProfileError" code:21 userInfo:@{NSLocalizedDescriptionKey: @"Profile target changed during creation"}];
        if (completion) completion(NO, failure); return;
    }
    [self.mutableProfiles addObject:profile];
    [self saveProfilesWithCompletion:^(BOOL saved, NSError *saveError) {
        if (!saved) {
            [self.mutableProfiles removeObjectIdenticalTo:profile];
            [self endProfileOperation];
            if (completion) completion(NO, saveError); return;
        }
        NSError *activationError = nil; BOOL activated = NO;
        @try {
            if ([self activationProfile:profile matchesRegistry:self.registryRecord error:&activationError] &&
                [self validateActivationForProfile:profile expectedSelection:expected generation:generation error:&activationError]) {
                [self terminateEnabledScopedApps]; // Never hold a source lock across this adapter.
                activated = [self activateProfile:profile expectedSelection:expected generation:generation error:&activationError];
            }
        } @catch (NSException *exception) {
            activationError = [NSError errorWithDomain:@"WeaponXProfileError" code:22 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Profile activation failed"}];
        }
        // A ready inactive profile may remain registered if activation conflicts;
        // never compensate by overwriting another writer's selection or archive.
        if (activated) {
            @try { [self randomizeAppVersionsForProfile:targetID]; }
            @catch (NSException *exception) { NSLog(@"[ProfileManager] Activated profile; version adapter failed: %@", exception); }
            @try { [[IdentifierManager sharedManager] publishCommittedRuntimeGeneration:generation]; }
            @catch (NSException *exception) { NSLog(@"[ProfileManager] Activated profile; cache publication failed: %@", exception); PXPostSettingsChangedNotification(); }
            @try { [[IdentifierManager sharedManager] resetCanvasNoise]; }
            @catch (NSException *exception) { NSLog(@"[ProfileManager] Activated profile; canvas reset failed: %@", exception); }
        }
        [self endProfileOperation];
        if (activated) [self publishProfileChangedNotification];
        if (!activated && !activationError) activationError = [NSError errorWithDomain:@"WeaponXProfileError" code:22 userInfo:@{NSLocalizedDescriptionKey: @"Profile was saved but could not be activated"}];
        if (completion) completion(activated, activated ? nil : activationError);
    }];
}

- (NSDictionary *)captureProfileSelectionWithError:(NSError **)error {
    __block NSDictionary *expected = nil;
    BOOL ok = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **readError) {
        expected = PXReadRuntimeProfileSelection(tx, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), readError);
        return expected != nil;
    }, error);
    return ok ? expected : nil;
}

- (NSString *)identityForActivationProfile:(Profile *)profile generation:(PXCommittedRuntimeGeneration *)generation error:(NSError **)error {
    if (self.lifecycleLease && ![self.lifecycleLease validateWithError:error]) return nil;
    NSString *identity = PXProfileIdentityPath(PXValidatedProfileID(profile.profileId)); BOOL directory = NO;
    if (!identity.length || ![self.fileManager fileExistsAtPath:identity isDirectory:&directory] || !directory ||
        (generation && (![generation isKindOfClass:PXCommittedRuntimeGeneration.class] ||
                        ![identity isEqualToString:generation.identityDirectory] || ![generation.payload[@"deferSettings"] boolValue]))) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:21 userInfo:@{NSLocalizedDescriptionKey: @"Profile activation target is invalid or unavailable"}];
        return nil;
    }
    if (generation) {
        NSError *ownershipError = nil;
        if (![self.creationReservation.profileID isEqualToString:profile.profileId] ||
            ![self.creationReservation.identityDirectory isEqualToString:identity] || ![self.creationReservation validateWithError:&ownershipError]) {
            if (error) *error = ownershipError ?: [NSError errorWithDomain:@"WeaponXProfileError" code:21 userInfo:@{NSLocalizedDescriptionKey: @"Profile creation no longer owns its directory"}];
            return nil;
        }
    }
    return identity;
}

- (BOOL)validateActivationForProfile:(Profile *)profile expectedSelection:(NSDictionary *)expected generation:(PXCommittedRuntimeGeneration *)generation error:(NSError **)error {
    if (![self identityForActivationProfile:profile generation:generation error:error]) return NO;
    return PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **readError) {
        return (!generation || [self.creationReservation validateWithError:readError]) &&
            PXRuntimeProfileSelectionMatches(tx, expected, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), readError) &&
            (!generation || PXRuntimeGenerationMatchesProof(tx, generation.proof, readError));
    }, error);
}

- (BOOL)activateProfile:(Profile *)profile expectedSelection:(NSDictionary *)expected generation:(PXCommittedRuntimeGeneration *)generation error:(NSError **)error {
    if (!NSThread.isMainThread) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:23 userInfo:@{NSLocalizedDescriptionKey: @"Profile activation requires main"}]; return NO;
    }
    __attribute__((objc_precise_lifetime)) PXProfileLifecycleLease *lease = self.lifecycleLease ?: [PXProfileLifecycleLease acquireInDirectory:self.profilesDirectory error:error];
    if (!lease || ![lease validateWithError:error] || !PXRequireNoPendingProfileDeletion(error)) return NO;
    NSDictionary *observedRegistry = [lease readRegistryWithError:error];
    if (!observedRegistry) return NO;
    if (self.registryRecord && ![observedRegistry isEqual:self.registryRecord]) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:25 userInfo:@{NSLocalizedDescriptionKey: @"Profile registry changed before activation"}]; return NO;
    }
    if (![self activationProfile:profile matchesRegistry:observedRegistry error:error]) return NO;
    // Revalidate after any external termination callback. A preflight alone
    // cannot protect the later commit against reentry/another source writer.
    if (![self identityForActivationProfile:profile generation:generation error:error]) return NO;
    NSDictionary *info = @{ @"ProfileId": [profile.profileId copy], @"ProfileName": [profile.name copy] ?: @"",
        @"Description": [profile.shortDescription copy] ?: @"", @"LastSelected": NSDate.date, @"SelectionRevision": NSUUID.UUID.UUIDString };
    BOOL committed = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        if (generation && ![self.creationReservation validateWithError:writeError]) return NO;
        if (generation && !PXRuntimeGenerationMatchesProof(tx, generation.proof, writeError)) return NO;
        if (!PXStageRuntimeProfileSelectionIfUnchanged(tx, info, expected, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), writeError)) return NO;
        return !generation || PXStageRuntimeGenerationSettings(tx, generation.payload, writeError);
    }, error);
    if (!committed) return NO;
    self.mutableCurrentProfile = profile;
    @try { [self mirrorCurrentProfileID:info[@"ProfileId"]]; }
    @catch (NSException *exception) { NSLog(@"[ProfileManager] Activation committed; defaults mirror failed: %@", exception); }
    return YES;
}

- (void)publishProfileChangedNotification {
    @try { [[NSNotificationCenter defaultCenter] postNotificationName:@"com.hydra.tlinkios.profileChanged" object:nil]; }
    @catch (NSException *exception) { NSLog(@"[ProfileManager] Committed profile; notification observer failed: %@", exception); }
}

- (NSDictionary *)captureProfileNetworkOptions {
    NSUserDefaults *security = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
    return @{ @"enabled": @([security boolForKey:@"networkDataSpoofEnabled"]),
        @"connectionType": @([security integerForKey:@"networkConnectionType"]),
        @"country": [[security stringForKey:@"networkISOCountryCode"] copy] ?: @"us" };
}

- (NSDictionary *)prepareNetworkArtifactsWithOptions:(NSDictionary *)options error:(NSError **)error {
    if (error) *error = nil;
    NSMutableDictionary *artifacts = [NSMutableDictionary dictionary];
    NSInteger connection = [options[@"connectionType"] integerValue];
    if (connection == 0 || connection == 2) {
        NSDictionary *carrier = [NetworkManager getRandomCarrierForCountry:options[@"country"]];
        if (carrier) artifacts[@"carrier"] = @{ @"carrierName": carrier[@"name"] ?: @"",
            @"mcc": carrier[@"mcc"] ?: @"", @"mnc": carrier[@"mnc"] ?: @"", @"lastUpdated": [NSDate date] };
    }
    if ([options[@"enabled"] boolValue] && (connection == 0 || connection == 1 || connection == 2)) {
        NSString *ipv4 = [NetworkManager generateSpoofedLocalIPAddressFromCurrent];
        // Preserve the no-interface skip policy; never persist a real fallback IP.
        if (ipv4.length) {
            artifacts[@"ipv4"] = ipv4;
            NSString *ipv6 = [NetworkManager generateSpoofedLocalIPv6AddressFromCurrent];
            if (ipv6.length) artifacts[@"ipv6"] = ipv6;
        }
    }
    return [artifacts copy];
}

- (void)updateProfile:(Profile *)profile completion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self updateProfile:profile completion:completion]; });
        return;
    }
    if (self.selectionUnavailable || self.registryUnavailable) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:23 userInfo:@{NSLocalizedDescriptionKey: @"Reload a valid profile selection and registry before changing profiles"}]); return;
    }
    if (self.creationInProgress) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:12
            userInfo:@{NSLocalizedDescriptionKey: @"Profile creation is still in progress; retry when it completes"}]);
        return;
    }

    if (![profile.name isKindOfClass:NSString.class] || ![PXValidatedProfileID(profile.profileId) isEqualToString:profile.profileId]) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid profile name or ID"}]); return;
    }
    NSLog(@"[WeaponX] 🔄 Updating profile: %@", profile.name);
    
    // Find the profile to update
    NSUInteger index = [self.mutableProfiles indexOfObjectPassingTest:^BOOL(Profile *obj, NSUInteger idx, BOOL *stop) {
        return [obj.profileId isEqualToString:profile.profileId];
    }];
    
    if (index == NSNotFound) {
        NSError *error = [NSError errorWithDomain:@"WeaponXProfileError" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Profile not found"}];
        if (completion) completion(NO, error);
        return;
    }
    NSError *operationError = nil;
    if (![self beginProfileOperationWithError:&operationError]) { if (completion) completion(NO, operationError); return; }
    
    BOOL success = NO; NSError *failure = nil;
    @try { success = [self updateProfileUnderLease:profile index:index error:&failure]; }
    @catch (NSException *exception) {
        failure = [NSError errorWithDomain:@"WeaponXProfileError" code:17 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Profile update failed"}];
    } @finally { [self endProfileOperation]; }
    if (success) [self publishProfileChangedNotification];
    if (completion) completion(success, success ? nil : failure);
}

- (void)editProfileID:(NSString *)profileID name:(NSString *)name shortDescription:(NSString *)shortDescription completion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self editProfileID:profileID name:name shortDescription:shortDescription completion:completion]; }); return;
    }
    NSString *targetID = [PXValidatedProfileID(profileID) copy];
    if (![targetID isEqual:profileID] || (!name && !shortDescription) ||
        (name && (![name isKindOfClass:NSString.class] || !name.length)) ||
        (shortDescription && ![shortDescription isKindOfClass:NSString.class])) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid profile metadata edit"}]); return;
    }
    NSString *requestedName = [name copy], *requestedDescription = [shortDescription copy];
    if (self.selectionUnavailable || self.registryUnavailable) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:23 userInfo:@{NSLocalizedDescriptionKey: @"Reload a valid profile selection and registry before editing"}]); return;
    }
    NSUInteger index = NSNotFound;
    for (NSUInteger i = 0; i < self.mutableProfiles.count; i++)
        if ([self.mutableProfiles[i].profileId isEqual:targetID]) { index = i; break; }
    if (index == NSNotFound) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Profile not found"}]); return;
    }
    NSError *failure = nil;
    if (![self beginProfileOperationWithError:&failure]) { if (completion) completion(NO, failure); return; }
    BOOL success = NO, mirroredSelection = NO;
    @try {
        // Copy only this registered graph; dialog objects never mutate manager
        // slots before persistence. Keep the reader's legal nested class policy.
        NSArray *models = @[self.mutableProfiles[index]];
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:models requiringSecureCoding:YES error:&failure];
        NSDictionary *record = data ? @{ @"exists": @YES, @"bytes": data } : nil;
        Profile *edit = record ? [[self decodeRegistryRecord:record error:&failure] firstObject] : nil;
        if (edit) {
            if (requestedName) edit.name = requestedName;
            if (requestedDescription) edit.shortDescription = requestedDescription;
            NSDictionary *expected = [self captureProfileSelectionWithError:&failure];
            NSDictionary *central = expected[PXCurrentProfileInfoPath()], *legacy = expected[PXLegacyActiveProfileInfoPath()];
            NSDictionary *info = [central[@"exists"] boolValue] ? central[@"info"] : legacy[@"info"];
            NSString *selectedID = PXValidatedProfileID(info[@"ProfileId"] ?: info[@"currentProfileId"]);
            if (expected && selectedID && [edit.name isKindOfClass:NSString.class]) {
                success = [self updateProfileUnderLease:edit index:index error:&failure];
                if (success && [selectedID isEqual:targetID]) {
                    NSDictionary *label = @{ @"ProfileId": targetID, @"ProfileName": [edit.name copy],
                        @"Description": [edit.shortDescription copy] ?: @"", @"LastSelected": NSDate.date,
                        @"SelectionRevision": NSUUID.UUID.UUIDString };
                    // Registry persistence precedes labels. A conflict/fault here
                    // is partial failure, never compensation of a newer selection.
                    success = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
                        return PXStageRuntimeProfileSelectionIfUnchanged(tx, label, expected, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), writeError);
                    }, &failure);
                    mirroredSelection = success;
                    if (success) self.mutableCurrentProfile = edit;
                }
            }
        }
    } @catch (NSException *exception) {
        success = NO;
        failure = [NSError errorWithDomain:@"WeaponXProfileError" code:17 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Profile metadata edit failed"}];
    } @finally { [self endProfileOperation]; }
    if (!success && !failure) failure = [NSError errorWithDomain:@"WeaponXProfileError" code:23 userInfo:@{NSLocalizedDescriptionKey: @"Profile metadata edit could not complete; reload before retrying"}];
    if (mirroredSelection) {
        @try { [self mirrorCurrentProfileID:targetID]; }
        @catch (NSException *exception) { NSLog(@"[ProfileManager] Metadata committed; defaults mirror failed: %@", exception); }
    }
    if (success) [self publishProfileChangedNotification];
    if (completion) completion(success, success ? nil : failure);
}

- (BOOL)updateProfileUnderLease:(Profile *)profile index:(NSUInteger)index error:(NSError **)error {
    if (error) *error = nil;
    NSString *targetID = PXValidatedProfileID(profile.profileId);
    if (!targetID || index >= self.mutableProfiles.count ||
        ![self.mutableProfiles[index].profileId isEqual:targetID]) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Profile update target changed"}];
        return NO;
    }
    // Freeze the archive before changing any display file or manager-owned slot.
    // Encoding/reader validation failure is preflight, not a partially saved edit.
    NSMutableArray<Profile *> *candidate = [self.mutableProfiles mutableCopy];
    candidate[index] = profile;
    NSDictionary *record = [self preparedRegistryRecordForProfiles:candidate error:error];
    if (!record) return NO;
    NSData *archive = record[@"bytes"];
    NSDictionary *fields = @{
        @"Name": profile.name,
        @"Description": profile.shortDescription ?: [NSString stringWithFormat:@"Profile ID: %@", targetID],
        @"CreatedAt": profile.createdAt ?: [NSDate date],
        @"LastUsed": profile.lastUsed ?: [NSDate date]
    };
    if (!PXWriteProfileDisplayMetadata(self.lifecycleLease, targetID, fields, error)) return NO;
    // The registry remains a separate CAS phase. Never report success or adopt
    // the candidate when it fails; committed display files are not rolled back.
    if (![self.lifecycleLease writeRegistryData:archive expected:self.registryRecord error:error]) return NO;
    self.registryRecord = record;
    self.mutableProfiles = candidate;
    if ([self.mutableCurrentProfile.profileId isEqual:targetID]) self.mutableCurrentProfile = profile;
    [self.fileManager setAttributes:@{NSFilePosixPermissions: @0644}
        ofItemAtPath:[self.profilesDirectory stringByAppendingPathComponent:@"profiles.plist"] error:NULL];
    NSLog(@"[WeaponX] Updated profile information and registry for %@", targetID);
    return YES;
}

- (void)deleteProfile:(Profile *)profile completion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self deleteProfile:profile completion:completion]; }); return;
    }
    if (self.selectionUnavailable || self.registryUnavailable) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:23 userInfo:@{NSLocalizedDescriptionKey: @"Reload a valid profile selection and registry before changing profiles"}]); return;
    }
    if (self.creationInProgress) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:12 userInfo:@{NSLocalizedDescriptionKey: @"Another profile change is in progress"}]); return;
    }
    NSString *targetID = [PXValidatedProfileID(profile.profileId) copy];
    Profile *registered = nil;
    for (Profile *candidate in self.mutableProfiles) if ([candidate.profileId isEqualToString:targetID]) { registered = candidate; break; }
    if (!registered || ![registered.profileId isEqualToString:profile.profileId]) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Profile not found"}]); return;
    }
    if (self.mutableProfiles.count <= 1) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Cannot delete the last profile"}]); return;
    }
    NSError *failure = nil;
    if (![self beginProfileOperationWithError:&failure]) { if (completion) completion(NO, failure); return; }
    BOOL success = NO, selectionChanged = NO;
    @try { success = [self deleteRegisteredProfileID:targetID selectionChanged:&selectionChanged error:&failure]; }
    @catch (NSException *exception) {
        self.registryUnavailable = YES;
        failure = [NSError errorWithDomain:@"WeaponXProfileError" code:26 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Profile deletion did not finish; reload the registry"}];
    } @finally { [self endProfileOperation]; }
    if (selectionChanged) PXPostSettingsChangedNotification();
    if (success) [self publishProfileChangedNotification];
    if (completion) completion(success, success ? nil : failure);
}

- (BOOL)deleteRegisteredProfileID:(NSString *)targetID selectionChanged:(BOOL *)selectionChanged error:(NSError **)error {
    NSArray *original = [self.mutableProfiles copy];
    NSDictionary *proof = [self.lifecycleLease directoryProofForProfileID:targetID error:error];
    NSDictionary *expected = proof ? [self captureProfileSelectionWithError:error] : nil;
    if (!expected) return NO;
    NSDictionary *central = expected[PXCurrentProfileInfoPath()], *legacy = expected[PXLegacyActiveProfileInfoPath()];
    NSDictionary *info = [central[@"exists"] boolValue] ? central[@"info"] : legacy[@"info"];
    NSString *selectedID = PXValidatedProfileID(info[@"ProfileId"] ?: info[@"currentProfileId"]);
    Profile *selected = nil, *fallback = nil;
    NSMutableArray *remaining = [NSMutableArray array];
    for (Profile *candidate in original) {
        if ([candidate.profileId isEqualToString:selectedID]) selected = candidate;
        if (![candidate.profileId isEqualToString:targetID]) {
            [remaining addObject:candidate];
            if (!fallback && [self identityForActivationProfile:candidate generation:nil error:NULL]) fallback = candidate;
        }
    }
    BOOL active = [selectedID isEqualToString:targetID];
    if (!selected || ![self identityForActivationProfile:selected generation:nil error:NULL] || !remaining.count || (active && !fallback)) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:21 userInfo:@{NSLocalizedDescriptionKey: @"A valid committed selection and fallback profile are required for deletion"}]; return NO;
    }
    // Encode/validate before changing selection: an encoding failure has no
    // committed decision to replay and must not change the active profile.
    NSData *afterBytes = nil;
    @try { afterBytes = [NSKeyedArchiver archivedDataWithRootObject:remaining requiringSecureCoding:YES error:error]; }
    @catch (NSException *exception) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:17 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Could not prepare deletion archive"}]; return NO;
    }
    if (!afterBytes) return NO;
    NSString *operationID = NSUUID.UUID.UUIDString;
    NSDictionary *afterSelection = expected;
    if (active) {
        NSDictionary *fallbackInfo = @{ @"ProfileId": fallback.profileId, @"ProfileName": fallback.name ?: @"",
            @"Description": fallback.shortDescription ?: @"", @"LastSelected": NSDate.date, @"SelectionRevision": operationID };
        NSDictionary *record = @{ @"exists": @YES, @"info": fallbackInfo };
        afterSelection = @{ PXCurrentProfileInfoPath(): record, PXLegacyActiveProfileInfoPath(): record };
    }
    NSDictionary *intent = @{ @"schemaVersion": @1, @"operation": @"delete", @"operationID": operationID,
        @"targetID": targetID, @"state": @"prepared", @"directoryProof": proof,
        @"registryBefore": self.registryRecord, @"registryAfter": @{ @"exists": @YES, @"bytes": afterBytes },
        @"selectionBefore": expected, @"selectionAfter": afterSelection };
    PXProfileDeletionArchiveValidator validator = ^BOOL(NSDictionary *candidate, NSError **failure) {
        return [self validateDeletionArchives:candidate error:failure];
    };
    if (!PXPrepareProfileDeletion(self.lifecycleLease, intent, validator, error)) return NO;
    PXProfileDeletionCheckpoint(@"prepared");
    if (!PXCommitProfileDeletion(self.lifecycleLease, intent, error)) return NO;
    *selectionChanged = active;
    PXProfileDeletionCheckpoint(@"committed");
    self.mutableCurrentProfile = active ? fallback : selected;
    if (active) {
        @try { [self mirrorCurrentProfileID:self.mutableCurrentProfile.profileId]; }
        @catch (NSException *exception) { NSLog(@"[ProfileManager] Delete committed; defaults mirror failed: %@", exception); }
    }
    if (![self.lifecycleLease writeRegistryData:afterBytes expected:intent[@"registryBefore"] error:error]) {
        self.registryUnavailable = YES; return NO; // Committed intent is retained for reload.
    }
    self.registryRecord = intent[@"registryAfter"];
    self.mutableProfiles = remaining;
    if (!PXMarkProfileDeletionArchiveWritten(self.lifecycleLease, intent, error)) { self.registryUnavailable = YES; return NO; }
    [self.fileManager setAttributes:@{NSFilePosixPermissions: @0644}
        ofItemAtPath:[self.profilesDirectory stringByAppendingPathComponent:@"profiles.plist"] error:NULL];
    PXProfileDeletionCheckpoint(@"archive-written");
    PXProfileDeletionResolution resolution;
    if (!PXRecoverProfileDeletion(self.lifecycleLease, validator, &resolution, error)) {
        self.registryUnavailable = YES; return NO;
    }
    if (resolution != PXProfileDeletionCompleted) {
        self.registryRecord = [self.lifecycleLease readRegistryWithError:NULL];
        self.mutableProfiles = [original mutableCopy];
        [self refreshCurrentProfileFromCommittedSelectionWithError:NULL];
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:20 userInfo:@{NSLocalizedDescriptionKey: @"Selection changed; deletion cancelled without removing files"}]; return NO;
    }
    PXProfileDeletionCheckpoint(@"settled");
    NSError *cleanupError = nil;
    @try {
        if (![self.lifecycleLease removeDirectoryForProfileID:targetID proof:proof error:&cleanupError])
            NSLog(@"[ProfileManager] Logical deletion committed; inactive cleanup incomplete: %@", cleanupError);
    } @catch (NSException *exception) {
        NSLog(@"[ProfileManager] Logical deletion committed; inactive cleanup raised: %@", exception);
    }
    // A reload replays registry decisions only. It never retries this path.
    return YES;
}

- (void)terminateEnabledScopedApps {
    NSLog(@"[WeaponX] 🔄 Terminating enabled scoped apps for profile switch");
    
    // Get the BottomButtons instance directly
    id bottomButtons = [NSClassFromString(@"BottomButtons") sharedInstance];
    if (!bottomButtons) {
        NSLog(@"[WeaponX] ⚠️ Could not get BottomButtons instance for app termination");
        return;
    }
    
    // Since the killEnabledApps method in BottomButtons works correctly,
    // directly invoke it to kill all enabled apps
    SEL killEnabledAppsSel = NSSelectorFromString(@"killEnabledApps");
    if ([bottomButtons respondsToSelector:killEnabledAppsSel]) {
        NSLog(@"[WeaponX] 🔪 Directly calling BottomButtons.killEnabledApps to terminate enabled apps");
        
        // Use NSInvocation to avoid ARC issues with performSelector
        NSMethodSignature *signature = [bottomButtons methodSignatureForSelector:killEnabledAppsSel];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:bottomButtons];
        [invocation setSelector:killEnabledAppsSel];
        [invocation invoke];
        
        NSLog(@"[WeaponX] ✅ Successfully called killEnabledApps method");
    } else {
        NSLog(@"[WeaponX] ❌ BottomButtons does not respond to killEnabledApps");
        
        // Fallback to using killAppViaExecutableName directly with all enabled apps
        id identifierManager = [NSClassFromString(@"IdentifierManager") sharedManager];
        if (!identifierManager) {
            NSLog(@"[WeaponX] ⚠️ Could not get IdentifierManager instance for app termination");
            return;
        }
        
        // Get all apps and filter by enabled
        NSDictionary *allApps = [identifierManager getApplicationInfo:nil];
        if (!allApps) {
            NSLog(@"[WeaponX] ⚠️ Could not retrieve app information");
            return;
        }
        
        NSLog(@"[WeaponX] Found %lu total apps to check", (unsigned long)allApps.count);
        
        // Create a safelist of apps that should NEVER be terminated
        NSArray *safeApps = @[
            @"com.hydra.tlinkios",      // The tweak itself
            @"com.apple.springboard",   // SpringBoard
            @"com.apple.backboardd",    // BackBoard
            @"com.apple.preferences",   // Settings
            @"com.apple.mobilephone",   // Phone
            @"com.apple.MobileSMS"      // Messages
        ];
        
        int terminatedCount = 0;
        for (NSString *bundleID in allApps) {
            // Skip apps in the safelist
            if ([safeApps containsObject:bundleID]) {
                NSLog(@"[WeaponX] 🛡️ Skipping termination of protected app: %@", bundleID);
                continue;
            }
            
            // Check if app is enabled
            if ([identifierManager isApplicationEnabled:bundleID]) {
                NSLog(@"[WeaponX] 🔄 Terminating enabled app: %@", bundleID);
                
                // Use killAppViaExecutableName method directly
                [bottomButtons killAppViaExecutableName:bundleID];
                terminatedCount++;
            }
        }
        
        NSLog(@"[WeaponX] ✅ Terminated %d enabled apps using fallback method", terminatedCount);
    }
}

- (void)switchToProfile:(Profile *)profile completion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self switchToProfile:profile completion:completion]; }); return;
    }
    if (self.selectionUnavailable || self.registryUnavailable) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:23 userInfo:@{NSLocalizedDescriptionKey: @"Reload a valid profile selection and registry before changing profiles"}]); return;
    }
    if (self.creationInProgress) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:12 userInfo:@{NSLocalizedDescriptionKey: @"Another profile change is in progress"}]); return;
    }
    NSString *rawID = [profile isKindOfClass:Profile.class] ? [profile.profileId copy] : nil;
    NSString *requestedID = PXValidatedProfileID(rawID);
    if (![requestedID isEqual:rawID]) requestedID = nil;
    Profile *registeredProfile = nil;
    for (Profile *candidate in self.mutableProfiles) if ([candidate.profileId isEqual:requestedID]) { registeredProfile = candidate; break; }
    if (!registeredProfile) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:21 userInfo:@{NSLocalizedDescriptionKey: @"Profile is not registered"}]); return;
    }
    // UI callers may pass the original create input or another alias. Only the
    // registered model may supply fields that are archived and activated.
    profile = registeredProfile;
    NSError *operationError = nil;
    if (![self beginProfileOperationWithError:&operationError]) { if (completion) completion(NO, operationError); return; }
    NSString *targetID = [profile.profileId copy];
    NSError *error = nil;
    NSDictionary *expected = [self captureProfileSelectionWithError:&error];
    if (!expected || ![self validateActivationForProfile:profile expectedSelection:expected generation:nil error:&error]) {
        [self endProfileOperation];
        if (completion) completion(NO, error); return;
    }
    NSString *observedID = PXValidatedProfileID(expected[PXCurrentProfileInfoPath()][@"info"][@"ProfileId"]);
    if (!observedID) observedID = PXValidatedProfileID(expected[PXLegacyActiveProfileInfoPath()][@"info"][@"ProfileId"] ?: expected[PXLegacyActiveProfileInfoPath()][@"info"][@"currentProfileId"]);
    BOOL same = [observedID isEqualToString:profile.profileId] && [self.mutableCurrentProfile.profileId isEqualToString:profile.profileId];
    NSDate *previousLastUsed = profile.lastUsed;
    profile.lastUsed = NSDate.date;
    [self saveProfilesWithCompletion:^(BOOL saved, NSError *saveError) {
        if (!saved) {
            profile.lastUsed = previousLastUsed;
            [self endProfileOperation];
            if (completion) completion(NO, saveError); return;
        }
        NSError *activationError = nil; BOOL activated = NO;
        @try {
            if ([self activationProfile:profile matchesRegistry:self.registryRecord error:&activationError] &&
                [self validateActivationForProfile:profile expectedSelection:expected generation:nil error:&activationError]) {
                if (!same) [self terminateEnabledScopedApps];
                if ([profile.profileId isEqualToString:targetID])
                    activated = [self activateProfile:profile expectedSelection:expected generation:nil error:&activationError];
                else activationError = [NSError errorWithDomain:@"WeaponXProfileError" code:21 userInfo:@{NSLocalizedDescriptionKey: @"Profile target changed during switch"}];
            }
        } @catch (NSException *exception) {
            activationError = [NSError errorWithDomain:@"WeaponXProfileError" code:22 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Profile switch failed"}];
        }
        if (activated) {
            if (!same) {
                @try { [self randomizeAppVersionsForProfile:profile.profileId]; }
                @catch (NSException *exception) { NSLog(@"[ProfileManager] Switched profile; version adapter failed: %@", exception); }
            }
            PXPostSettingsChangedNotification();
        }
        [self endProfileOperation];
        if (activated && !same) [self publishProfileChangedNotification];
        if (completion) completion(activated, activated ? nil : activationError);
    }];
}

// New method to randomize app versions for a profile
- (void)randomizeAppVersionsForProfile:(NSString *)profileId {
    NSLog(@"[WeaponX] 🎲 Randomizing app versions for profile: %@", profileId);
    
    // Try rootless path first for multi-version data
    NSString *prefsPath = @"/var/mobile/Library/Preferences";
    NSString *multiVersionFile = [prefsPath stringByAppendingPathComponent:@"com.hydra.tlinkios.multi_version_spoof.plist"];
    
    // Fallback to standard path if rootless path doesn't exist
    if (![self.fileManager fileExistsAtPath:prefsPath]) {
        // Try Dopamine 2 path
        prefsPath = @"/private/var/mobile/Library/Preferences";
        multiVersionFile = [prefsPath stringByAppendingPathComponent:@"com.hydra.tlinkios.multi_version_spoof.plist"];
        
        // Fallback to standard path if needed
        if (![self.fileManager fileExistsAtPath:prefsPath]) {
            prefsPath = @"/var/mobile/Library/Preferences";
            multiVersionFile = [prefsPath stringByAppendingPathComponent:@"com.hydra.tlinkios.multi_version_spoof.plist"];
        }
    }
    
    // Load multi-version data
    NSDictionary *multiVersionDict = [NSDictionary dictionaryWithContentsOfFile:multiVersionFile];
    NSDictionary *multiVersions = multiVersionDict[@"MultiVersions"];
    
    if (!multiVersions || multiVersions.count == 0) {
        NSLog(@"[WeaponX] ℹ️ No multi-version data found, skipping randomization");
        return;
    }
    
    // Load scoped apps info to get app names
    NSDictionary *scopedAppsInfo = [self loadScopedAppsInfo];
    
    // Create app_versions directory in the profile directory
    NSString *profileDir = [PXProfilesPath() stringByAppendingPathComponent:profileId];
    NSString *appVersionsDir = [profileDir stringByAppendingPathComponent:@"app_versions"];
    
    if (![self.fileManager fileExistsAtPath:appVersionsDir]) {
        NSError *dirError = nil;
        NSDictionary *attributes = @{NSFilePosixPermissions: @0755, NSFileOwnerAccountName: @"mobile"};
        if (![self.fileManager createDirectoryAtPath:appVersionsDir 
                           withIntermediateDirectories:YES 
                                            attributes:attributes 
                                                 error:&dirError]) {
            NSLog(@"[WeaponX] ❌ Failed to create app_versions directory: %@", dirError);
            return;
        }
    }
    
    // Process each app with multiple versions
    NSInteger randomizedCount = 0;
    for (NSString *bundleID in multiVersions) {
        NSArray *versions = multiVersions[bundleID];
        if (versions.count < 2) {
            // Skip apps with only one or zero versions
            continue; 
        }
        
        // Randomly select a version
        NSInteger randomIndex = arc4random_uniform((uint32_t)versions.count);
        NSDictionary *selectedVersion = versions[randomIndex];
        
        NSString *appName = scopedAppsInfo[bundleID][@"name"] ?: bundleID;
        NSString *spoofedVersion = selectedVersion[@"version"];
        NSString *spoofedBuild = selectedVersion[@"build"];
        NSString *displayName = selectedVersion[@"displayName"] ?: [NSString stringWithFormat:@"v%@", spoofedVersion];
        
        NSLog(@"[WeaponX] 🎲 Randomly selected version for %@: %@ (index %ld)", appName, displayName, (long)randomIndex);
        
        // Create and save the app version file
        NSString *safeFilename = [bundleID stringByReplacingOccurrencesOfString:@"." withString:@"_"];
        safeFilename = [safeFilename stringByAppendingString:@"_version.plist"];
        NSString *appVersionFile = [appVersionsDir stringByAppendingPathComponent:safeFilename];
        
        NSMutableDictionary *appVersionData = [NSMutableDictionary dictionary];
        appVersionData[@"bundleID"] = bundleID;
        appVersionData[@"name"] = appName;
        appVersionData[@"spoofedVersion"] = spoofedVersion;
        if (spoofedBuild) {
            appVersionData[@"spoofedBuild"] = spoofedBuild;
        }
        appVersionData[@"activeVersionIndex"] = @(randomIndex);
        appVersionData[@"spoofingEnabled"] = @YES;  // Enable spoofing by default for randomized versions
        appVersionData[@"lastUpdated"] = [NSDate date];
        
        BOOL success = [appVersionData writeToFile:appVersionFile atomically:YES];
        if (success) {
            randomizedCount++;
        } else {
            NSLog(@"[WeaponX] ❌ Failed to save randomized version for %@", appName);
        }
    }
    
    NSLog(@"[WeaponX] ✅ Randomized versions for %ld apps", (long)randomizedCount);
}

- (NSDictionary *)loadScopedAppsInfo {
    // Try to load scoped apps info from global scope file
    NSString *prefsPath = @"/var/mobile/Library/Preferences";
    NSString *scopedAppsFile = [prefsPath stringByAppendingPathComponent:@"com.hydra.tlinkios.global_scope.plist"];
    
    // Fallback to standard path if rootless path doesn't exist
    if (![self.fileManager fileExistsAtPath:prefsPath]) {
        // Try Dopamine 2 path
        prefsPath = @"/private/var/mobile/Library/Preferences";
        scopedAppsFile = [prefsPath stringByAppendingPathComponent:@"com.hydra.tlinkios.global_scope.plist"];
        
        // Fallback to standard path if needed
        if (![self.fileManager fileExistsAtPath:prefsPath]) {
            prefsPath = @"/var/mobile/Library/Preferences";
            scopedAppsFile = [prefsPath stringByAppendingPathComponent:@"com.hydra.tlinkios.global_scope.plist"];
        }
    }
    
    // Load scoped apps
    NSDictionary *scopedAppsDict = [NSDictionary dictionaryWithContentsOfFile:scopedAppsFile];
    return scopedAppsDict[@"ScopedApps"] ?: @{};
}

- (BOOL)bootstrapProfileSelectionWithError:(NSError **)error {
    __attribute__((objc_precise_lifetime)) PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:self.profilesDirectory error:error];
    if (!lease || !PXRequireNoPendingProfileDeletion(error)) { self.selectionUnavailable = YES; return NO; }
    NSDictionary *expected = [self captureProfileSelectionWithError:error];
    if (!expected) { self.selectionUnavailable = YES; return NO; }
    NSDictionary *central = expected[PXCurrentProfileInfoPath()], *legacy = expected[PXLegacyActiveProfileInfoPath()];
    NSDictionary *source = [central[@"exists"] boolValue] ? central[@"info"] : legacy[@"info"];
    BOOL hasSource = [central[@"exists"] boolValue] || [legacy[@"exists"] boolValue];
    NSString *profileID = PXValidatedProfileID(source[@"ProfileId"] ?: source[@"currentProfileId"]);
    if (hasSource && !profileID) {
        self.selectionUnavailable = YES;
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:23 userInfo:@{NSLocalizedDescriptionKey: @"Malformed committed profile selection"}];
        return NO;
    }
    if ([central[@"exists"] boolValue] && [legacy[@"exists"] boolValue] && [central[@"info"] isEqual:legacy[@"info"]]) {
        self.selectionUnavailable = NO; return YES;
    }
    NSMutableDictionary *info = hasSource ? [source mutableCopy] : [@{ @"ProfileName": @"Default", @"Description": @"Default Profile", @"LastSelected": NSDate.date } mutableCopy];
    info[@"ProfileId"] = profileID ?: @"0";
    info[@"SelectionRevision"] = NSUUID.UUID.UUIDString;
    BOOL ok = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return PXStageRuntimeProfileSelectionIfUnchanged(tx, info, expected, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), writeError);
    }, error);
    self.selectionUnavailable = !ok;
    return ok;
}

- (void)scheduleProfileMirrorForSelection:(NSDictionary *)expected {
    // Do not synchronously notify defaults observers from initialization.
    // Drop this queued main-thread mirror if activation has advanced.
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL current = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
            return PXRuntimeProfileSelectionMatches(tx, expected, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), error);
        }, NULL);
        if (!current) return;
        NSDictionary *info = expected[PXCurrentProfileInfoPath()][@"info"];
        NSString *profileID = PXValidatedProfileID(info[@"ProfileId"]);
        if (!profileID) profileID = PXValidatedProfileID(expected[PXLegacyActiveProfileInfoPath()][@"info"][@"ProfileId"] ?: expected[PXLegacyActiveProfileInfoPath()][@"info"][@"currentProfileId"]);
        @try { if (profileID) [self mirrorCurrentProfileID:profileID]; }
        @catch (NSException *exception) { NSLog(@"[ProfileManager] Deferred defaults mirror failed: %@", exception); }
    });
}

- (void)loadProfilesWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self loadProfilesWithCompletion:completion]; }); return;
    }
    if (self.creationInProgress) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:12 userInfo:@{NSLocalizedDescriptionKey: @"Cannot reload profiles during another profile operation"}]); return;
    }
    NSError *leaseError = nil;
    self.lifecycleLease = [PXProfileLifecycleLease acquireInDirectory:self.profilesDirectory error:&leaseError];
    if (!self.lifecycleLease) { if (completion) completion(NO, leaseError); return; }
    self.creationInProgress = YES;
    __block BOOL success = NO; __block NSError *failure = nil;
    @try {
        [self loadProfilesUnderLeaseWithCompletion:^(BOOL ok, NSError *error) { success = ok; failure = error; }];
    } @catch (NSException *exception) {
        self.registryUnavailable = YES;
        failure = [NSError errorWithDomain:@"WeaponXProfileError" code:24 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Could not reload profile registry"}];
    } @finally { [self endProfileOperation]; }
    if (self.deletionRecoveryNoticePending || (success && !self.didLoadCommittedProfiles)) {
        self.deletionRecoveryNoticePending = NO;
        // A process can exit after journal settlement but before notification.
        // First successful load requests publication even with no pending file.
        if (success) self.didLoadCommittedProfiles = YES;
        PXPostSettingsChangedNotification();
    }
    if (completion) completion(success, success ? nil : failure);
}

- (NSArray<Profile *> *)decodeRegistryRecord:(NSDictionary *)record error:(NSError **)error {
    if (![record isKindOfClass:NSDictionary.class] || ![record[@"exists"] isKindOfClass:NSNumber.class]) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:24 userInfo:@{NSLocalizedDescriptionKey: @"Invalid registry record"}]; return nil;
    }
    if (![record[@"exists"] boolValue]) return @[];
    @try {
        NSData *data = record[@"bytes"];
        NSError *failure = nil;
        NSKeyedUnarchiver *decoder = [data isKindOfClass:NSData.class] ? [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&failure] : nil;
        decoder.requiresSecureCoding = YES;
        id decoded = decoder ? [decoder decodeObjectOfClasses:PXProfileArchiveClasses() forKey:NSKeyedArchiveRootObjectKey] : nil;
        [decoder finishDecoding];
        failure = failure ?: decoder.error;
        BOOL valid = [decoded isKindOfClass:NSArray.class] && !failure;
        NSMutableSet *seen = [NSMutableSet set];
        if (valid) for (id profile in decoded) {
            if (![profile isKindOfClass:Profile.class] || ![PXValidatedProfileID([profile profileId]) isEqual:[profile profileId]] || [seen containsObject:[profile profileId]]) { valid = NO; break; }
            [seen addObject:[profile profileId]];
        }
        if (valid) return decoded;
        if (error) *error = failure ?: [NSError errorWithDomain:@"WeaponXProfileError" code:24 userInfo:@{NSLocalizedDescriptionKey: @"Invalid profile archive; preserving the existing file"}];
    } @catch (NSException *exception) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:24 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Could not decode profile registry"}];
    }
    return nil;
}

- (NSDictionary *)preparedRegistryRecordForProfiles:(NSArray<Profile *> *)profiles error:(NSError **)error {
    if (error) *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:profiles requiringSecureCoding:YES error:error];
    if (!data) return nil;
    NSDictionary *record = @{ @"exists": @YES, @"bytes": data };
    // Encoding only proves that the objects support coding. Before replacing a
    // readable registry, require these exact bytes to pass the load-time policy
    // too (typed fields, root members, valid unique IDs and legacy fallbacks).
    NSError *failure = nil; BOOL readable = NO;
    @autoreleasepool {
        readable = [self decodeRegistryRecord:record error:&failure] != nil;
    }
    if (!readable && error) *error = failure;
    return readable ? record : nil;
}

- (BOOL)registryValue:(id)before matchesValue:(id)after seen:(NSMapTable *)seen {
    // Deletion retains its directional legacy timestamp compatibility policy.
    return [self registryValue:before matchesValue:after seen:seen allowLegacyDates:YES];
}

- (BOOL)registryValue:(id)before matchesValue:(id)after seen:(NSMapTable *)seen allowLegacyDates:(BOOL)allowLegacyDates {
    if (before == after) return YES;
    if (!before || !after) return NO;
    BOOL arrays = [before isKindOfClass:NSArray.class] && [after isKindOfClass:NSArray.class];
    BOOL dictionaries = [before isKindOfClass:NSDictionary.class] && [after isKindOfClass:NSDictionary.class];
    BOOL profiles = [before isKindOfClass:Profile.class] && [after isKindOfClass:Profile.class];
    if (!arrays && !dictionaries && !profiles) return [before isEqual:after];
    // Private decoded graphs may share nodes or contain cycles. Track pairs by
    // pointer identity, without invoking a collection's recursive hash/isEqual.
    if (!seen) seen = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality
        valueOptions:NSPointerFunctionsStrongMemory];
    NSHashTable *matches = [seen objectForKey:before];
    if ([matches containsObject:after]) return YES;
    if (!matches) {
        matches = [NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality];
        [seen setObject:matches forKey:before];
    }
    [matches addObject:after];
    if (arrays) {
        NSArray *left = before, *right = after;
        if (left.count != right.count) return NO;
        for (NSUInteger index = 0; index < left.count; index++)
            if (![self registryValue:left[index] matchesValue:right[index] seen:seen allowLegacyDates:allowLegacyDates]) return NO;
        return YES;
    }
    if (dictionaries) {
        NSDictionary *left = before, *right = after;
        if (left.count != right.count) return NO;
        // Retain NSDictionary's key-equality policy; values include Profile,
        // which has no value-based isEqual implementation of its own.
        for (id key in left)
            if (!right[key] || ![self registryValue:left[key] matchesValue:right[key] seen:seen allowLegacyDates:allowLegacyDates]) return NO;
        return YES;
    }
    Profile *left = before, *right = after;
    NSArray *leftFields = @[left.profileId ?: NSNull.null, left.name ?: NSNull.null,
        left.shortDescription ?: NSNull.null, left.iconName ?: NSNull.null, left.settings ?: NSNull.null];
    NSArray *rightFields = @[right.profileId ?: NSNull.null, right.name ?: NSNull.null,
        right.shortDescription ?: NSNull.null, right.iconName ?: NSNull.null, right.settings ?: NSNull.null];
    if (![self registryValue:leftFields matchesValue:rightFields seen:seen allowLegacyDates:allowLegacyDates]) return NO;
    if (allowLegacyDates) return !right.pxDecodedMissingCreatedAt && !right.pxDecodedMissingLastUsed &&
        (left.pxDecodedMissingCreatedAt || [left.createdAt isEqual:right.createdAt]) &&
        (left.pxDecodedMissingLastUsed || [left.lastUsed isEqual:right.lastUsed]);
    // Activation compares persisted values. Decode provenance may remain set on
    // a loaded model even after saving its fallback dates into a valid archive.
    return [self registryValue:left.createdAt matchesValue:right.createdAt seen:seen allowLegacyDates:NO] &&
        [self registryValue:left.lastUsed matchesValue:right.lastUsed seen:seen allowLegacyDates:NO];
}

- (BOOL)activationProfile:(Profile *)profile matchesRegistry:(NSDictionary *)record error:(NSError **)error {
    if (error) *error = nil;
    // Callback boundaries can expose the registered model after archive commit.
    // Decode outside the source gate; a byte CAS alone cannot detect model edits.
    NSArray<Profile *> *committed = [self decodeRegistryRecord:record error:error];
    if (!committed) return NO;
    if ([profile isKindOfClass:Profile.class]) for (Profile *candidate in committed) {
        if ([candidate.profileId isEqual:profile.profileId] &&
            [self registryValue:profile matchesValue:candidate seen:nil allowLegacyDates:NO]) return YES;
    }
    if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:31
        userInfo:@{NSLocalizedDescriptionKey: @"Activation model changed after registry persistence; reload before retrying"}];
    return NO;
}

- (BOOL)validateDeletionArchives:(NSDictionary *)intent error:(NSError **)error {
    NSArray *before = [self decodeRegistryRecord:intent[@"registryBefore"] error:error];
    NSArray *after = before ? [self decodeRegistryRecord:intent[@"registryAfter"] error:error] : nil;
    if (!after) return NO;
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
    for (Profile *profile in before) records[profile.profileId] = profile;
    BOOL valid = before.count > 1 && after.count == before.count - 1 && records[intent[@"targetID"]] != nil;
    for (Profile *profile in after) {
        Profile *original = records[profile.profileId];
        if (!original || [profile.profileId isEqual:intent[@"targetID"]]) { valid = NO; break; }
        // toDictionary assumes non-nil historical fields. Compare nullable
        // legacy fields explicitly; NSNull is comparison-only, never persisted.
        NSArray *oldFields = @[original.name ?: NSNull.null, original.shortDescription ?: NSNull.null, original.iconName ?: NSNull.null,
            original.settings ?: NSNull.null];
        NSArray *newFields = @[profile.name ?: NSNull.null, profile.shortDescription ?: NSNull.null, profile.iconName ?: NSNull.null,
            profile.settings ?: NSNull.null];
        BOOL datesValid = !profile.pxDecodedMissingCreatedAt && !profile.pxDecodedMissingLastUsed &&
            (original.pxDecodedMissingCreatedAt || [original.createdAt isEqual:profile.createdAt]) &&
            (original.pxDecodedMissingLastUsed || [original.lastUsed isEqual:profile.lastUsed]);
        if (![self registryValue:oldFields matchesValue:newFields seen:nil] || !datesValid) { valid = NO; break; }
    }
    NSDictionary *pair = intent[@"selectionAfter"];
    NSDictionary *record = [pair[PXCurrentProfileInfoPath()][@"exists"] boolValue] ? pair[PXCurrentProfileInfoPath()] : pair[PXLegacyActiveProfileInfoPath()];
    NSString *selected = PXValidatedProfileID(record[@"info"][@"ProfileId"] ?: record[@"info"][@"currentProfileId"]);
    BOOL present = NO;
    for (Profile *profile in after) if ([profile.profileId isEqual:selected]) { present = YES; break; }
    valid = valid && present;
    if (!valid && error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:27 userInfo:@{NSLocalizedDescriptionKey: @"Deletion journal does not remove exactly one profile while preserving the others"}];
    return valid;
}

- (void)loadProfilesUnderLeaseWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    NSError *error = nil;
    PXProfileDeletionResolution resolution;
    BOOL recoveryOK = PXRecoverProfileDeletion(self.lifecycleLease, ^BOOL(NSDictionary *intent, NSError **failure) {
        return [self validateDeletionArchives:intent error:failure];
    }, &resolution, &error);
    if (!recoveryOK) { self.registryUnavailable = YES; if (completion) completion(NO, error); return; }
    if (resolution != PXProfileDeletionNoPendingIntent) self.deletionRecoveryNoticePending = YES;
    NSDictionary *selection = [self captureProfileSelectionWithError:&error];
    NSDictionary *central = selection[PXCurrentProfileInfoPath()], *legacy = selection[PXLegacyActiveProfileInfoPath()];
    NSDictionary *info = [central[@"exists"] boolValue] ? central[@"info"] : legacy[@"info"];
    NSString *selectedID = PXValidatedProfileID(info[@"ProfileId"] ?: info[@"currentProfileId"]);
    if (!selection || !selectedID) {
        self.selectionUnavailable = YES;
        if (!error) error = [NSError errorWithDomain:@"WeaponXProfileError" code:23 userInfo:@{NSLocalizedDescriptionKey: @"Committed profile selection is unavailable"}];
        if (completion) completion(NO, error); return;
    }
    BOOL selectedDirectory = NO; NSString *selectedIdentity = PXProfileIdentityPath(selectedID);
    if (!selectedIdentity || ![self.fileManager fileExistsAtPath:selectedIdentity isDirectory:&selectedDirectory] || !selectedDirectory) {
        self.selectionUnavailable = YES;
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:21 userInfo:@{NSLocalizedDescriptionKey: @"Selected profile directory is unavailable"}]); return;
    }
    NSDictionary *registry = [self.lifecycleLease readRegistryWithError:&error];
    if (!registry) { self.registryUnavailable = YES; if (completion) completion(NO, error); return; }
    NSArray *decoded = [self decodeRegistryRecord:registry error:&error];
    if (!decoded) { self.selectionUnavailable = YES; self.registryUnavailable = YES; if (completion) completion(NO, error); return; }
    NSMutableArray *profiles = [decoded mutableCopy];
    Profile *current = nil;
    for (Profile *candidate in profiles) if ([candidate.profileId isEqualToString:selectedID]) { current = candidate; break; }
    BOOL recovered = current == nil;
    if (!current) {
        BOOL directory = NO; NSString *identity = PXProfileIdentityPath(selectedID);
        if (!identity || ![self.fileManager fileExistsAtPath:identity isDirectory:&directory] || !directory) {
            self.selectionUnavailable = YES;
            if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:21 userInfo:@{NSLocalizedDescriptionKey: @"Selected profile directory is unavailable"}]); return;
        }
        NSString *name = [info[@"ProfileName"] isKindOfClass:NSString.class] ? info[@"ProfileName"] : selectedID;
        NSString *description = [info[@"Description"] isKindOfClass:NSString.class] ? info[@"Description"] : @"";
        current = [[Profile alloc] initWithName:name shortDescription:description iconName:@"default_profile"];
        [current setValue:selectedID forKey:@"profileId"];
        [profiles addObject:current];
    }
    self.registryRecord = registry;
    self.mutableProfiles = profiles;
    self.mutableCurrentProfile = current;
    self.registryUnavailable = NO;
    self.selectionUnavailable = NO;
    [self scheduleProfileMirrorForSelection:selection];
    if (recovered) [self saveProfilesWithCompletion:completion];
    else if (completion) completion(YES, nil);
}

- (void)setCurrentProfileToLastUsed {
    // Compatibility selector: committed selection remains authoritative.
    [self loadProfilesWithCompletion:nil];
}

#pragma mark - Private Methods

// Generates profile IDs in the sequence: 1, 2, ... 99, 100, ..., 999, A01, A02, ... A99, B01, ...
- (NSString *)generateProfileID {
    @try {
        // Get all existing profile IDs directly from the file system
        NSMutableArray *existingIDs = [NSMutableArray array];
        
        // Get profiles directory path
        NSString *profilesDirectory = PXProfilesPath();
        
        // Get file manager
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        // Check if directory exists
        if (![fileManager fileExistsAtPath:profilesDirectory]) {
            NSLog(@"[WeaponX] ⚠️ Profiles directory does not exist for ID generation!");
            return @"1";
        }
        
        // First try to get all profile IDs from profiles.plist
        NSString *profilesPath = [profilesDirectory stringByAppendingPathComponent:@"profiles.plist"];
        if ([fileManager fileExistsAtPath:profilesPath]) {
            NSLog(@"[WeaponX] Found profiles.plist at: %@ for ID generation", profilesPath);
            NSData *data = [NSData dataWithContentsOfFile:profilesPath];
            if (data) {
                NSError *error = nil;
                
                // Use the modern non-deprecated API for iOS 15+
                NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
                if (error) {
                    NSLog(@"[WeaponX] ❌ Failed to initialize unarchiver for ID generation: %@", error);
                } else {
                    unarchiver.requiresSecureCoding = YES;
                    NSArray *loadedProfiles = [unarchiver decodeObjectOfClasses:PXProfileArchiveClasses() forKey:NSKeyedArchiveRootObjectKey];
                    
                    if ([loadedProfiles isKindOfClass:NSArray.class]) {
                        for (Profile *profile in loadedProfiles) {
                            if ([profile isKindOfClass:Profile.class] && PXValidatedProfileID(profile.profileId)) {
                                [existingIDs addObject:profile.profileId];
                            }
                        }
                        NSLog(@"[WeaponX] ✅ Successfully loaded %lu profile IDs from plist", (unsigned long)existingIDs.count);
                    }
                }
            }
        }
        
        // If loading from plist failed or we got no IDs, scan directory for profile folders
        {
            NSError *error = nil;
            NSArray *contents = [fileManager contentsOfDirectoryAtPath:profilesDirectory error:&error];
            
            if (error) {
                NSLog(@"[WeaponX] ❌ Failed to read profiles directory for ID generation: %@", error);
                return @"1";
            }
            
            for (NSString *item in contents) {
                NSString *itemPath = [profilesDirectory stringByAppendingPathComponent:item];
                BOOL isDirectory = NO;
                
                // Skip non-directories and the profiles.plist file
                if (![fileManager fileExistsAtPath:itemPath isDirectory:&isDirectory] || !isDirectory || [item isEqualToString:@"profiles.plist"]) {
                    continue;
                }
                
                // Add profile ID to the list
                [existingIDs addObject:item];
            }
            
            NSLog(@"[WeaponX] ✅ Found %lu profile IDs from directory scan", (unsigned long)existingIDs.count);
        }
        
        // If no existing IDs, start with "1"
        if (existingIDs.count == 0) {
            return @"1";
        }
        
        // Find the highest numeric ID (for IDs that are just numbers)
        NSMutableArray *numericIDs = [NSMutableArray array];
        NSMutableArray *alphaIDs = [NSMutableArray array];
        
        for (NSString *profileId in existingIDs) {
            if (!profileId) continue; // Skip nil values
            
            if ([self isNumericString:profileId]) {
                [numericIDs addObject:profileId];
            } else if (profileId.length > 0) { // Make sure the string is not empty
                [alphaIDs addObject:profileId];
            }
        }
        
        // If we have numeric IDs and haven't reached 999 yet, increment the highest one
        if (numericIDs.count > 0) {
            NSArray *sortedNumericIDs = [numericIDs sortedArrayUsingComparator:^NSComparisonResult(NSString *id1, NSString *id2) {
                return [@([id1 intValue]) compare:@([id2 intValue])];
            }];
            
            NSString *highestID = [sortedNumericIDs lastObject];
            if (!highestID) return @"1"; // Safeguard
            
            int highestValue = [highestID intValue];
            
            // If we haven't reached 999 yet, increment
            if (highestValue < 999) {
                return [NSString stringWithFormat:@"%d", highestValue + 1];
            }
            // Otherwise we'll move to alpha IDs below
        }
        
        // If we've reached 999 or have no numeric IDs but have alpha IDs, find the highest alpha ID
        if (alphaIDs.count > 0) {
            // Sort alphabetically
            NSArray *sortedAlphaIDs = [alphaIDs sortedArrayUsingSelector:@selector(compare:)];
            NSString *highestID = [sortedAlphaIDs lastObject];
            if (!highestID || highestID.length < 3) return @"A01"; // Safeguard
            
            // Parse letter and number parts from the ID (e.g., "A01" -> "A" and 01)
            unichar letter = [highestID characterAtIndex:0];
            
            // Extract the number part safely
            NSString *numberPart = [highestID substringFromIndex:1];
            if (![self isNumericString:numberPart]) return @"A01"; // If not a valid format, reset
            
            int number = [numberPart intValue];
            
            // Increment (max 2 digits to keep total length at 3 chars)
            if (number < 99) {
                number++;
                return [NSString stringWithFormat:@"%c%02d", letter, number];
            } else {
                // Move to next letter and reset number to 01
                unichar nextLetter = letter + 1;
                return [NSString stringWithFormat:@"%c01", nextLetter];
            }
        }
        
        // If we've reached 999 and have no alpha IDs yet, start with "A01"
        return @"A01";
    }
    @catch (NSException *exception) {
        NSLog(@"[WeaponX] ❌ Exception in generateProfileID: %@", exception);
        return @"1"; // Safe fallback
    }
}

// Helper method to check if a string is numeric
- (BOOL)isNumericString:(NSString *)string {
    if (!string) return NO;
    NSCharacterSet *nonNumericSet = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    return [string rangeOfCharacterFromSet:nonNumericSet].location == NSNotFound;
}

- (void)createDefaultProfile {
    [self createProfile:[[Profile alloc] initWithName:@"Default" iconName:@"default_profile"] completion:nil];
}

- (void)saveProfilesWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    if (!NSThread.isMainThread) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:23 userInfo:@{NSLocalizedDescriptionKey: @"Registry writes require main"}]); return;
    }
    NSError *error = nil; BOOL success = NO;
    BOOL ownsOperation = self.lifecycleLease == nil;
    if (ownsOperation && ![self beginProfileOperationWithError:&error]) { if (completion) completion(NO, error); return; }
    @try {
        if (NSThread.isMainThread && [self.lifecycleLease validateWithError:&error] && PXRequireNoPendingProfileDeletion(&error)) {
            NSDictionary *record = [self preparedRegistryRecordForProfiles:self.mutableProfiles error:&error];
            success = record && [self.lifecycleLease writeRegistryData:record[@"bytes"] expected:self.registryRecord error:&error];
            if (success) {
                self.registryRecord = record;
                [self.fileManager setAttributes:@{NSFilePosixPermissions: @0644}
                    ofItemAtPath:[self.profilesDirectory stringByAppendingPathComponent:@"profiles.plist"] error:NULL];
            }
        }
    } @catch (NSException *exception) {
        error = [NSError errorWithDomain:@"WeaponXProfileError" code:17 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Could not save profiles"}];
    }
    if (!success && !error) error = [NSError errorWithDomain:@"WeaponXProfileError" code:16 userInfo:@{NSLocalizedDescriptionKey: @"Profile metadata did not persist"}];
    if (ownsOperation) [self endProfileOperation];
    if (completion) completion(success, success ? nil : error);
}

- (void)saveSettings:(NSDictionary *)settings {
    NSString *settingsPath = [PXWeaponXBasePath() stringByAppendingPathComponent:@"settings.plist"];
    
    BOOL success = [settings writeToFile:settingsPath atomically:YES];
    if (success) {
        [self.fileManager setAttributes:@{NSFilePosixPermissions: @0644}
                         ofItemAtPath:settingsPath
                              error:nil];
        NSLog(@"[WeaponX] ✅ Saved settings to %@", settingsPath);
    } else {
        NSLog(@"[WeaponX] ❌ Failed to write settings file");
    }
}

#pragma mark - Convenience Methods

- (void)removeProfile:(NSString *)profileName {
    // Find profile with matching name
    Profile *profileToDelete = nil;
    for (Profile *profile in self.mutableProfiles) {
        if ([profile.name isEqualToString:profileName]) {
            profileToDelete = profile;
            break;
        }
    }
    
    if (profileToDelete) {
        [self deleteProfile:profileToDelete completion:^(BOOL success, NSError * _Nullable error) {
            if (!success) {
                NSLog(@"[WeaponX] ❌ Failed to delete profile %@: %@", profileName, error);
            }
        }];
    }
}

- (void)renameProfile:(NSString *)oldName to:(NSString *)newName {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self renameProfile:oldName to:newName]; }); return;
    }
    // Find profile with matching name
    Profile *profileToRename = nil;
    for (Profile *profile in self.mutableProfiles) {
        if ([profile.name isEqualToString:oldName]) {
            profileToRename = profile;
            break;
        }
    }
    
    if (profileToRename) {
        [self editProfileID:profileToRename.profileId name:newName shortDescription:nil completion:^(BOOL success, NSError * _Nullable error) {
            if (!success) {
                NSLog(@"[WeaponX] ❌ Failed to rename profile from %@ to %@: %@", oldName, newName, error);
            }
        }];
    }
}

- (void)addProfile:(NSString *)profileName {
    Profile *newProfile = [[Profile alloc] initWithName:profileName iconName:@"default_profile"];
    [self createProfile:newProfile completion:^(BOOL success, NSError * _Nullable error) {
        if (!success) {
            NSLog(@"[WeaponX] ❌ Failed to add profile %@: %@", profileName, error);
        }
    }];
}

- (void)addProfileWithName:(NSString *)profileName shortDescription:(NSString *)shortDescription {
    Profile *newProfile = [[Profile alloc] initWithName:profileName shortDescription:shortDescription iconName:@"default_profile"];
    [self createProfile:newProfile completion:^(BOOL success, NSError * _Nullable error) {
        if (!success) {
            NSLog(@"[WeaponX] ❌ Failed to add profile %@: %@", profileName, error);
        }
    }];
}

#pragma mark - Current Profile Central Management

- (NSString *)centralProfileInfoPath {
    return PXCurrentProfileInfoPath();
}

- (BOOL)saveCentralProfileInfo:(NSDictionary *)infoDict {
    NSError *error = nil;
    BOOL success = [self persistProfileSelectionInfo:infoDict error:&error];
    if (!success) NSLog(@"[ProfileManager] Selection pair failed: %@", error);
    return success;
}

- (BOOL)persistProfileSelectionInfo:(NSDictionary *)info error:(NSError **)error {
    if (!NSThread.isMainThread) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:23 userInfo:@{NSLocalizedDescriptionKey: @"Profile selection writes require main"}]; return NO;
    }
    __attribute__((objc_precise_lifetime)) PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:self.profilesDirectory error:error];
    if (!lease || !PXRequireNoPendingProfileDeletion(error)) return NO;
    if (![info isKindOfClass:NSDictionary.class] || !PXValidatedProfileID(info[@"ProfileId"])) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:10 userInfo:@{NSLocalizedDescriptionKey: @"Invalid profile selection ID"}];
        return NO;
    }
    BOOL directory = NO; NSString *identity = PXProfileIdentityPath(info[@"ProfileId"]);
    if (!identity || ![self.fileManager fileExistsAtPath:identity isDirectory:&directory] || !directory) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:21 userInfo:@{NSLocalizedDescriptionKey: @"Selection target directory is unavailable"}]; return NO;
    }
    NSMutableDictionary *revisioned = [info mutableCopy];
    revisioned[@"SelectionRevision"] = NSUUID.UUID.UUIDString;
    return PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        return PXStageRuntimeProfileSelection(tx, revisioned, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), writeError);
    }, error);
}

- (BOOL)refreshCurrentProfileFromCommittedSelectionWithError:(NSError **)error {
    if (error) *error = nil;
    if (!NSThread.isMainThread || self.selectionUnavailable || self.registryUnavailable) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:23 userInfo:@{NSLocalizedDescriptionKey: @"A valid registry and main-thread refresh are required"}]; return NO;
    }
    NSDictionary *selection = [self captureProfileSelectionWithError:error];
    NSDictionary *central = selection[PXCurrentProfileInfoPath()], *legacy = selection[PXLegacyActiveProfileInfoPath()];
    NSDictionary *info = [central[@"exists"] boolValue] ? central[@"info"] : legacy[@"info"];
    NSString *profileID = PXValidatedProfileID(info[@"ProfileId"] ?: info[@"currentProfileId"]);
    if (!selection || !profileID) {
        self.selectionUnavailable = YES;
        if (error && !*error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:23 userInfo:@{NSLocalizedDescriptionKey: @"Committed selection cannot be refreshed"}]; return NO;
    }
    Profile *current = nil;
    for (Profile *candidate in self.mutableProfiles) if ([candidate.profileId isEqualToString:profileID]) { current = candidate; break; }
    if (!current) {
        NSString *name = [info[@"ProfileName"] isKindOfClass:NSString.class] ? info[@"ProfileName"] : profileID;
        NSString *description = [info[@"Description"] isKindOfClass:NSString.class] ? info[@"Description"] : @"";
        current = [[Profile alloc] initWithName:name shortDescription:description iconName:@"default_profile"];
        [current setValue:profileID forKey:@"profileId"];
    }
    self.mutableCurrentProfile = current;
    [self scheduleProfileMirrorForSelection:selection];
    return YES;
}

- (NSDictionary *)loadCentralProfileInfo {
    // Common UI read needs only the canonical record. Load legacy lazily, while
    // retaining the same recovery gate; full two-record capture is for CAS.
    __block NSDictionary *info = nil;
    BOOL ok = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        BOOL exists = NO;
        info = [tx dictionaryAtPath:PXCurrentProfileInfoPath() exists:&exists error:error];
        if (!info) return NO;
        if (!exists) info = [tx dictionaryAtPath:PXLegacyActiveProfileInfoPath() error:error];
        return info != nil;
    }, NULL);
    if (!ok || !PXValidatedProfileID(info[@"ProfileId"] ?: info[@"currentProfileId"])) { self.selectionUnavailable = YES; return nil; }
    self.selectionUnavailable = NO; // Does not clear registryUnavailable.
    if (info[@"ProfileId"]) return info;
    NSMutableDictionary *normalized = [info mutableCopy]; normalized[@"ProfileId"] = info[@"currentProfileId"];
    return [normalized copy];
}

- (void)updateCurrentProfileInfoWithProfile:(Profile *)profile {
    NSError *error = nil;
    if (![self updateCurrentProfileInfoWithProfile:profile error:&error]) NSLog(@"[ProfileManager] Selection update failed: %@", error);
}

- (BOOL)updateCurrentProfileInfoWithProfile:(Profile *)profile error:(NSError **)error {
    if (!NSThread.isMainThread) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:23 userInfo:@{NSLocalizedDescriptionKey: @"Profile selection writes require main"}]; return NO;
    }
    __attribute__((objc_precise_lifetime)) PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:self.profilesDirectory error:error];
    if (!lease || !PXRequireNoPendingProfileDeletion(error)) return NO;
    if (error) *error = nil;
    if (!profile || !PXValidatedProfileID(profile.profileId)) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:10 userInfo:@{NSLocalizedDescriptionKey: @"Invalid current profile metadata"}]; return NO;
    }
    NSDictionary *info = @{ @"ProfileId": [profile.profileId copy], @"ProfileName": profile.name ?: @"",
        @"Description": profile.shortDescription ?: @"", @"LastSelected": NSDate.date, @"SelectionRevision": NSUUID.UUID.UUIDString };
    BOOL committed = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        NSDictionary *expected = PXReadRuntimeProfileSelection(tx, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), writeError);
        if (!expected) return NO;
        NSDictionary *central = expected[PXCurrentProfileInfoPath()], *legacy = expected[PXLegacyActiveProfileInfoPath()];
        NSDictionary *current = [central[@"exists"] boolValue] ? central[@"info"] : legacy[@"info"];
        NSString *observed = PXValidatedProfileID(current[@"ProfileId"] ?: current[@"currentProfileId"]);
        BOOL present = [central[@"exists"] boolValue] || [legacy[@"exists"] boolValue];
        if (present && ![observed isEqualToString:info[@"ProfileId"]]) {
            if (writeError) *writeError = [NSError errorWithDomain:@"WeaponXProfileError" code:20 userInfo:@{NSLocalizedDescriptionKey: @"Current profile changed before metadata update"}]; return NO;
        }
        return PXStageRuntimeProfileSelectionIfUnchanged(tx, info, expected, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), writeError);
    }, error);
    if (!committed) return NO;
    @try { [self mirrorCurrentProfileID:info[@"ProfileId"]]; }
    @catch (NSException *exception) { NSLog(@"[ProfileManager] Metadata committed; defaults mirror failed: %@", exception); }
    return YES;
}

- (void)mirrorCurrentProfileID:(NSString *)profileID {
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:@"com.hydra.tlinkios.shared"];
    [shared setObject:profileID forKey:@"CurrentProfileID"];
    [shared synchronize];
}

- (Profile *)loadCurrentProfileInfoFromCentralStore {
    // Load info from central store
    NSDictionary *infoDict = [self loadCentralProfileInfo];
    
    if (!infoDict || !infoDict[@"ProfileId"]) {
        NSLog(@"[WeaponX] No valid current profile info found in central store");
        return nil;
    }
    
    // Try to find the profile in our profiles array
    NSString *profileId = infoDict[@"ProfileId"];
    
    for (Profile *profile in self.mutableProfiles) {
        if ([profile.profileId isEqualToString:profileId]) {
            NSLog(@"[WeaponX] Found current profile from central store: %@ (ID: %@)", profile.name, profile.profileId);
            return profile;
        }
    }
    
    // If we couldn't find the profile in our array, create a temporary one
    // This could happen if the profiles haven't been fully loaded yet
    NSLog(@"[WeaponX] Profile from central store not found in profiles array, creating temporary");
    
    NSString *name = [infoDict[@"ProfileName"] isKindOfClass:NSString.class] ? infoDict[@"ProfileName"] : profileId;
    NSString *description = [infoDict[@"Description"] isKindOfClass:NSString.class] ? infoDict[@"Description"] : @"";
    Profile *tempProfile = [[Profile alloc] initWithName:name
                                        shortDescription:description
                                               iconName:@"default_profile"];
    [tempProfile setValue:profileId forKey:@"profileId"];
    
    return tempProfile;
}

// New method to create profile "0"
- (void)createProfileZero {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self createProfileZero]; }); return; }
    if (self.creationInProgress) return;
    NSError *error = nil;
    if (![self createProfileZeroWithError:&error]) { NSLog(@"[ProfileManager] Profile zero seed deferred: %@", error); return; }
    if ([self bootstrapProfileSelectionWithError:&error]) [self loadProfilesWithCompletion:nil];
    else NSLog(@"[ProfileManager] Legacy bootstrap deferred: %@", error);
}

// Retain the synchronous compatibility entry for init and legacy callers.
- (void)createProfileZeroImmediately {
    NSError *error = nil;
    if (![self createProfileZeroWithError:&error]) NSLog(@"[ProfileManager] Profile zero seed deferred: %@", error);
}

- (BOOL)createProfileZeroWithError:(NSError **)error {
    if (error) *error = nil;
    __attribute__((objc_precise_lifetime)) PXProfileLifecycleLease *lease = [PXProfileLifecycleLease acquireInDirectory:self.profilesDirectory error:error];
    if (!lease) return NO;
    @try {
        if (!PXSeedDefaultProfile(lease, error)) return NO;
    } @finally { [lease invalidate]; }
    NSLog(@"[WeaponX] Default profile display and identity seed committed");
    return YES;
}

@end
