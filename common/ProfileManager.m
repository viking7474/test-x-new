#import "ProfileManager.h"
#import <UIKit/UIKit.h>
#import "ContainerManager.h"
#import "PXPaths.h"
#import "PXRuntimeProfileSelection.h"
#import "PXRuntimeGeneration.h"
#import "NetworkManager.h"
#import <spawn.h>
#import <sys/wait.h>

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

@end

static NSSet<Class> *PXProfileArchiveClasses(void) {
    static NSSet *classes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ classes = [NSSet setWithArray:@[NSArray.class, NSDictionary.class,
        NSString.class, NSNumber.class, NSDate.class, NSData.class, Profile.class]]; });
    return classes;
}

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
        _name = [coder decodeObjectOfClass:[NSString class] forKey:@"name"];
        _shortDescription = [coder decodeObjectOfClass:[NSString class] forKey:@"shortDescription"];
        _iconName = [coder decodeObjectOfClass:[NSString class] forKey:@"iconName"];
        _createdAt = [coder decodeObjectOfClass:[NSDate class] forKey:@"createdAt"];
        _lastUsed = [coder decodeObjectOfClass:[NSDate class] forKey:@"lastUsed"];
        _settings = [coder decodeObjectOfClasses:PXProfileArchiveClasses() forKey:@"settings"];
        
        // If timestamps are missing, set them to current time
        if (!_createdAt) {
            NSLog(@"[WeaponX] Setting missing createdAt timestamp for profile: %@", _name);
            _createdAt = [NSDate date];
        }
        if (!_lastUsed) {
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

    NSLog(@"[WeaponX] 📝 Creating new profile: %@", profile.name);
    
    // Validate profile name
    if (![profile.name isKindOfClass:NSString.class] || profile.name.length == 0) {
        NSError *error = [NSError errorWithDomain:@"WeaponXProfileError" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Profile name cannot be empty"}];
        if (completion) completion(NO, error);
        return;
    }
    
    // Check for duplicate names
    for (Profile *existingProfile in self.mutableProfiles) {
        if ([existingProfile.name isEqualToString:profile.name]) {
            NSError *error = [NSError errorWithDomain:@"WeaponXProfileError" code:2 userInfo:@{NSLocalizedDescriptionKey: @"A profile with this name already exists"}];
            if (completion) completion(NO, error);
            return;
        }
    }
    
    // Generate a sequential profile ID instead of using UUID
    NSString *profileID = [self generateProfileID];
    
    // Set the generated ID
    // We need to use setValue:forKey: because profileId is readonly
    [profile setValue:profileID forKey:@"profileId"];
    
    // Set creation and last used dates with precise timestamps
    NSDate *now = [NSDate date];
    profile.createdAt = now;
    profile.lastUsed = now;
    
    // Create profile directory
    NSString *profileDir = [self.profilesDirectory stringByAppendingPathComponent:profile.profileId];
    if (!PXValidatedProfileID(profile.profileId) || [self.fileManager fileExistsAtPath:profileDir]) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:13
            userInfo:@{NSLocalizedDescriptionKey: @"New profile ID is invalid or its directory already exists"}]);
        return;
    }
    [self createDirectoryIfNeeded:profileDir];
    
    // Set the creation and modification dates explicitly on the directory
    NSDictionary *attributes = @{
        NSFileCreationDate: now,
        NSFileModificationDate: now
    };
    
    NSError *attributesError = nil;
    BOOL attributesSuccess = [self.fileManager setAttributes:attributes ofItemAtPath:profileDir error:&attributesError];
    
    if (!attributesSuccess) {
        NSLog(@"[WeaponX] ⚠️ Failed to set profile directory attributes: %@", attributesError);
    }
    
    // Create identity directory for device IDs
    NSString *identityDir = [profileDir stringByAppendingPathComponent:@"identity"];
    [self createDirectoryIfNeeded:identityDir];
    [self.fileManager setAttributes:@{NSFilePosixPermissions: @0755} ofItemAtPath:identityDir error:nil];
    
    // Create identifiers.plist (kept: used for profile display name in the UI)
    NSString *identifiersPath = [profileDir stringByAppendingPathComponent:@"identifiers.plist"];
    NSDictionary *identifiersDict = @{
        @"DisplayName": profile.name,
        @"Description": profile.shortDescription ?: [NSString stringWithFormat:@"Profile ID: %@", profile.profileId],
        @"Identifier": profile.profileId
    };
    BOOL identityIsDirectory = NO;
    if (![self.fileManager fileExistsAtPath:identityDir isDirectory:&identityIsDirectory] || !identityIsDirectory ||
        ![identifiersDict writeToFile:identifiersPath atomically:YES]) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:11
            userInfo:@{NSLocalizedDescriptionKey: @"Could not initialize the new profile directory"}]);
        return;
    }
    [self.fileManager setAttributes:@{NSFilePosixPermissions: @0644} ofItemAtPath:identifiersPath error:nil];
    
    // NOTE: appdata.plist (write-only, no reader) and per-profile scoped-apps.plist
    // (always empty; real scope lives in com.hydra.tlinkios.global_scope.plist) are
    // intentionally no longer created here.
    
    NSError *captureError = nil;
    NSDictionary *expected = [self captureProfileSelectionWithError:&captureError];
    if (!expected) { if (completion) completion(NO, captureError); return; }
    // No registration, selection, termination, cache publication or global
    // settings change until the inactive target is generated and saved.
    self.creationInProgress = YES;
    NSString *targetID = [profile.profileId copy];
    NSDictionary *networkOptions = [self captureProfileNetworkOptions];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            NSError *generationError = nil;
            PXCommittedRuntimeGeneration *generation = nil;
            @try {
                NSDictionary *network = [self prepareNetworkArtifactsWithOptions:networkOptions error:&generationError];
                IdentifierManager *manager = [IdentifierManager sharedManager];
                if (network && [manager respondsToSelector:@selector(commitRuntimeGenerationForProfileID:networkArtifacts:error:)])
                    generation = [manager commitRuntimeGenerationForProfileID:targetID networkArtifacts:network error:&generationError];
                if (!generation && !generationError) generationError = [NSError errorWithDomain:@"WeaponXProfileError" code:14
                    userInfo:@{NSLocalizedDescriptionKey: @"Inactive profile generation did not complete"}];
            } @catch (NSException *exception) {
                generationError = [NSError errorWithDomain:@"WeaponXProfileError" code:15
                    userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Profile generation raised an exception"}];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self finishProfileCreation:profile targetID:targetID generation:generation expectedSelection:expected error:generationError completion:completion];
            });
        }
    });
}

- (void)finishProfileCreation:(Profile *)profile targetID:(NSString *)targetID generation:(PXCommittedRuntimeGeneration *)generation expectedSelection:(NSDictionary *)expected error:(NSError *)generationError completion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    NSError *failure = generationError;
    if (!generation || ![profile.profileId isEqualToString:targetID] ||
        ![self validateActivationForProfile:profile expectedSelection:expected generation:generation error:&failure]) {
        self.creationInProgress = NO;
        if (!failure) failure = [NSError errorWithDomain:@"WeaponXProfileError" code:21 userInfo:@{NSLocalizedDescriptionKey: @"Profile target changed during creation"}];
        if (completion) completion(NO, failure); return;
    }
    [self.mutableProfiles addObject:profile];
    [self saveProfilesWithCompletion:^(BOOL saved, NSError *saveError) {
        if (!saved) {
            [self.mutableProfiles removeObjectIdenticalTo:profile];
            self.creationInProgress = NO;
            if (completion) completion(NO, saveError); return;
        }
        NSError *activationError = nil; BOOL activated = NO;
        @try {
            if ([self validateActivationForProfile:profile expectedSelection:expected generation:generation error:&activationError]) {
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
        self.creationInProgress = NO;
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
    NSString *identity = PXProfileIdentityPath(PXValidatedProfileID(profile.profileId)); BOOL directory = NO;
    if (!identity.length || ![self.fileManager fileExistsAtPath:identity isDirectory:&directory] || !directory ||
        (generation && (![generation isKindOfClass:PXCommittedRuntimeGeneration.class] ||
                        ![identity isEqualToString:generation.identityDirectory] || ![generation.payload[@"deferSettings"] boolValue]))) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:21 userInfo:@{NSLocalizedDescriptionKey: @"Profile activation target is invalid or unavailable"}];
        return nil;
    }
    return identity;
}

- (BOOL)validateActivationForProfile:(Profile *)profile expectedSelection:(NSDictionary *)expected generation:(PXCommittedRuntimeGeneration *)generation error:(NSError **)error {
    if (![self identityForActivationProfile:profile generation:generation error:error]) return NO;
    return PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **readError) {
        return PXRuntimeProfileSelectionMatches(tx, expected, PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), readError) &&
            (!generation || PXRuntimeGenerationMatchesProof(tx, generation.proof, readError));
    }, error);
}

- (BOOL)activateProfile:(Profile *)profile expectedSelection:(NSDictionary *)expected generation:(PXCommittedRuntimeGeneration *)generation error:(NSError **)error {
    // Revalidate after any external termination callback. A preflight alone
    // cannot protect the later commit against reentry/another source writer.
    if (![self identityForActivationProfile:profile generation:generation error:error]) return NO;
    NSDictionary *info = @{ @"ProfileId": [profile.profileId copy], @"ProfileName": profile.name ?: @"",
        @"Description": profile.shortDescription ?: @"", @"LastSelected": NSDate.date, @"SelectionRevision": NSUUID.UUID.UUIDString };
    BOOL committed = PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
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
    
    // Get the profile directory
    NSString *profileDir = [self.profilesDirectory stringByAppendingPathComponent:profile.profileId];
    NSString *appDataDir = [profileDir stringByAppendingPathComponent:@"appdata"];
    
    // Make sure appdata directory exists
    [self createDirectoryIfNeeded:appDataDir];
    
    // Update Info.plist in profile directory
    NSString *infoPath = [profileDir stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *infoDict = @{
        @"Name": profile.name,
        @"ProfileId": profile.profileId,
        @"Description": profile.shortDescription ?: [NSString stringWithFormat:@"Profile ID: %@", profile.profileId],
        @"CreatedAt": profile.createdAt ?: [NSDate date],
        @"LastUsed": profile.lastUsed ?: [NSDate date]
    };
    [infoDict writeToFile:infoPath atomically:YES];
    
    // Update Info.plist in appdata directory
    NSString *appDataInfoPath = [appDataDir stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *appDataInfoDict = @{
        @"ProfileName": profile.name,
        @"ProfileID": profile.profileId,
        @"ShortDescription": profile.shortDescription ?: [NSString stringWithFormat:@"Profile ID: %@", profile.profileId],
        @"Creation": profile.createdAt ?: [NSDate date],
        @"LastUsed": profile.lastUsed ?: [NSDate date]
    };
    [appDataInfoDict writeToFile:appDataInfoPath atomically:YES];
    
    // Update identifiers.plist
    NSString *identifiersPath = [profileDir stringByAppendingPathComponent:@"identifiers.plist"];
    NSDictionary *identifiersDict = @{
        @"DisplayName": profile.name,
        @"Description": profile.shortDescription ?: [NSString stringWithFormat:@"Profile ID: %@", profile.profileId],
        @"Identifier": profile.profileId
    };
    [identifiersDict writeToFile:identifiersPath atomically:YES];
    
    // Update scoped-apps.plist
    NSString *scopedAppsPath = [profileDir stringByAppendingPathComponent:@"scoped-apps.plist"];
    
    // Try to preserve existing contents if the file exists
    NSMutableDictionary *scopedAppsDict;
    if ([self.fileManager fileExistsAtPath:scopedAppsPath]) {
        scopedAppsDict = [NSMutableDictionary dictionaryWithContentsOfFile:scopedAppsPath];
    } else {
        scopedAppsDict = [NSMutableDictionary dictionary];
    }
    
    // Update only the profile info fields
    [scopedAppsDict setObject:profile.name forKey:@"ProfileName"];
    [scopedAppsDict setObject:(profile.shortDescription ?: [NSString stringWithFormat:@"Profile ID: %@", profile.profileId]) forKey:@"ProfileDescription"];
    if (![scopedAppsDict objectForKey:@"Apps"]) {
        [scopedAppsDict setObject:@[] forKey:@"Apps"];
    }
    
    [scopedAppsDict writeToFile:scopedAppsPath atomically:YES];
    
    NSLog(@"[WeaponX] Updated profile information files in: %@", profileDir);
    
    // Update the profile
    self.mutableProfiles[index] = profile;
    
    // If this is the current profile, update it
    if ([self.mutableCurrentProfile.profileId isEqualToString:profile.profileId]) {
        self.mutableCurrentProfile = profile;
    }
    
    // Save to disk
    [self saveProfilesWithCompletion:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            NSLog(@"[WeaponX] ✅ Profile updated successfully: %@", profile.name);
            
            // Post notification that profile has changed - UI components should refresh
            dispatch_async(dispatch_get_main_queue(), ^{
                [self publishProfileChangedNotification];
            });
        } else {
            NSLog(@"[WeaponX] ❌ Failed to save profile: %@", error);
        }
        if (completion) completion(success, error);
    }];
}

- (void)deleteProfile:(Profile *)profile completion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self deleteProfile:profile completion:completion]; });
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

    NSLog(@"[WeaponX] 🗑️ Deleting profile: %@", profile.name);
    
    // Don't allow deleting the last profile
    if (self.mutableProfiles.count <= 1) {
        NSError *error = [NSError errorWithDomain:@"WeaponXProfileError" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Cannot delete the last profile"}];
        if (completion) completion(NO, error);
        return;
    }
    
    // Remove profile directory
    NSString *profileDir = [self.profilesDirectory stringByAppendingPathComponent:profile.profileId];
    if ([self.fileManager fileExistsAtPath:profileDir]) {
        NSError *error = nil;
        [self.fileManager removeItemAtPath:profileDir error:&error];
        if (error) {
            NSLog(@"[WeaponX] ⚠️ Failed to remove profile directory: %@", error);
        }
    }
    
    // Remove from array
    [self.mutableProfiles removeObject:profile];
    
    // If this was the current profile, switch to another one
    if ([self.mutableCurrentProfile.profileId isEqualToString:profile.profileId]) {
        self.mutableCurrentProfile = self.mutableProfiles.firstObject;
    }
    
    // Save to disk
    [self saveProfilesWithCompletion:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            NSLog(@"[WeaponX] ✅ Profile deleted successfully: %@", profile.name);
            
            // Post notification that profile has changed - UI components should refresh
            dispatch_async(dispatch_get_main_queue(), ^{
                [self publishProfileChangedNotification];
            });
        } else {
            NSLog(@"[WeaponX] ❌ Failed to save profiles: %@", error);
        }
        if (completion) completion(success, error);
    }];
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
    BOOL registered = NO;
    for (Profile *candidate in self.mutableProfiles) if ([candidate.profileId isEqualToString:profile.profileId]) { registered = YES; break; }
    if (!registered) {
        if (completion) completion(NO, [NSError errorWithDomain:@"WeaponXProfileError" code:21 userInfo:@{NSLocalizedDescriptionKey: @"Profile is not registered"}]); return;
    }
    NSString *targetID = [profile.profileId copy];
    NSError *error = nil;
    NSDictionary *expected = [self captureProfileSelectionWithError:&error];
    if (!expected || ![self validateActivationForProfile:profile expectedSelection:expected generation:nil error:&error]) {
        if (completion) completion(NO, error); return;
    }
    NSString *observedID = PXValidatedProfileID(expected[PXCurrentProfileInfoPath()][@"info"][@"ProfileId"]);
    if (!observedID) observedID = PXValidatedProfileID(expected[PXLegacyActiveProfileInfoPath()][@"info"][@"ProfileId"] ?: expected[PXLegacyActiveProfileInfoPath()][@"info"][@"currentProfileId"]);
    BOOL same = [observedID isEqualToString:profile.profileId] && [self.mutableCurrentProfile.profileId isEqualToString:profile.profileId];
    NSDate *previousLastUsed = profile.lastUsed;
    profile.lastUsed = NSDate.date;
    self.creationInProgress = YES;
    [self saveProfilesWithCompletion:^(BOOL saved, NSError *saveError) {
        if (!saved) {
            profile.lastUsed = previousLastUsed;
            self.creationInProgress = NO;
            if (completion) completion(NO, saveError); return;
        }
        NSError *activationError = nil; BOOL activated = NO;
        @try {
            if ([self validateActivationForProfile:profile expectedSelection:expected generation:nil error:&activationError]) {
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
        self.creationInProgress = NO;
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
    NSError *error = nil;
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
    NSString *path = [self.profilesDirectory stringByAppendingPathComponent:@"profiles.plist"];
    NSMutableArray *profiles = [NSMutableArray array];
    if ([self.fileManager fileExistsAtPath:path]) {
        @try {
            NSData *data = [NSData dataWithContentsOfFile:path options:0 error:&error];
            NSKeyedUnarchiver *decoder = data ? [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error] : nil;
            decoder.requiresSecureCoding = YES;
            id decoded = decoder ? [decoder decodeObjectOfClasses:PXProfileArchiveClasses() forKey:NSKeyedArchiveRootObjectKey] : nil;
            [decoder finishDecoding];
            BOOL valid = [decoded isKindOfClass:NSArray.class] && !error;
            if (valid) for (id item in decoded) {
                if (![item isKindOfClass:Profile.class] || !PXValidatedProfileID([item profileId])) { valid = NO; break; }
            }
            if (valid) [profiles addObjectsFromArray:decoded];
            else if (!error) error = [NSError errorWithDomain:@"WeaponXProfileError" code:24 userInfo:@{NSLocalizedDescriptionKey: @"Invalid profile archive; preserving the existing file"}];
        } @catch (NSException *exception) {
            error = [NSError errorWithDomain:@"WeaponXProfileError" code:24 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Profile archive could not be decoded"}];
        }
        if (error) { self.selectionUnavailable = YES; self.registryUnavailable = YES; if (completion) completion(NO, error); return; }
    }
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
    self.mutableProfiles = profiles;
    self.mutableCurrentProfile = current;
    self.registryUnavailable = NO;
    self.selectionUnavailable = NO;
    [self scheduleProfileMirrorForSelection:selection];
    if (recovered) [self saveProfilesWithCompletion:completion];
    else if (completion) completion(YES, nil);
}

- (void)setCurrentProfileToLastUsed {
    // Find the most recently used profile
    Profile *lastUsedProfile = [self.mutableProfiles sortedArrayUsingComparator:^NSComparisonResult(Profile *obj1, Profile *obj2) {
        return [obj2.lastUsed compare:obj1.lastUsed];
    }].firstObject;
    
    if (lastUsedProfile) {
        self.mutableCurrentProfile = lastUsedProfile;
        NSLog(@"[WeaponX] ✅ Set current profile to last used: %@", lastUsedProfile.name);
        
        // Update shared defaults with the current profile ID
        NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.hydra.tlinkios.shared"];
        [sharedDefaults setObject:lastUsedProfile.profileId forKey:@"CurrentProfileID"];
        [sharedDefaults synchronize];
    } else if (self.mutableProfiles.count > 0) {
        // Fallback to first profile if no last used found
        self.mutableCurrentProfile = self.mutableProfiles.firstObject;
        NSLog(@"[WeaponX] ✅ Set current profile to first available: %@", self.mutableCurrentProfile.name);
        
        // Update shared defaults with the current profile ID
        NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.hydra.tlinkios.shared"];
        [sharedDefaults setObject:self.mutableCurrentProfile.profileId forKey:@"CurrentProfileID"];
        [sharedDefaults synchronize];
    }
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
    Profile *defaultProfile = [[Profile alloc] initWithName:@"Default" iconName:@"default_profile"];
    
    // Use our ID generation system
    NSString *profileID = [self generateProfileID];
    [defaultProfile setValue:profileID forKey:@"profileId"];
    
    [self.mutableProfiles addObject:defaultProfile];
    self.mutableCurrentProfile = defaultProfile;
    [self saveProfilesWithCompletion:nil];
}

- (void)saveProfilesWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    NSError *error = nil; BOOL success = NO;
    @try {
        [self createDirectoryIfNeeded:self.profilesDirectory];
        NSString *path = [self.profilesDirectory stringByAppendingPathComponent:@"profiles.plist"];
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.mutableProfiles requiringSecureCoding:YES error:&error];
        success = data && [data writeToFile:path options:NSDataWritingAtomic error:&error];
        if (success) [self.fileManager setAttributes:@{NSFilePosixPermissions: @0644} ofItemAtPath:path error:NULL];
        // Do not unlink the last good archive or use a process-wide temp name
        // after an atomic write failure. Preserve the original failure.
    } @catch (NSException *exception) {
        error = [NSError errorWithDomain:@"WeaponXProfileError" code:17 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Could not save profiles"}];
    }
    if (!success && !error) error = [NSError errorWithDomain:@"WeaponXProfileError" code:16 userInfo:@{NSLocalizedDescriptionKey: @"Profile metadata did not persist"}];
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
    // Find profile with matching name
    Profile *profileToRename = nil;
    for (Profile *profile in self.mutableProfiles) {
        if ([profile.name isEqualToString:oldName]) {
            profileToRename = profile;
            break;
        }
    }
    
    if (profileToRename) {
        profileToRename.name = newName;
        [self updateProfile:profileToRename completion:^(BOOL success, NSError * _Nullable error) {
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
    if (![info isKindOfClass:NSDictionary.class] || !PXValidatedProfileID(info[@"ProfileId"])) {
        if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:10 userInfo:@{NSLocalizedDescriptionKey: @"Invalid profile selection ID"}];
        return NO;
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
    // Create profile directory
    NSString *profileDir = [self.profilesDirectory stringByAppendingPathComponent:@"0"];
    [self createDirectoryIfNeeded:profileDir];
    
    // Create profile object
    Profile *defaultProfile = [[Profile alloc] initWithName:@"Default" iconName:@"default_profile"];
    [defaultProfile setValue:@"0" forKey:@"profileId"];
    
    NSDate *now = [NSDate date];
    defaultProfile.createdAt = now;
    defaultProfile.lastUsed = now;
    
    // Create identity directory for device IDs
    NSString *identityDir = [profileDir stringByAppendingPathComponent:@"identity"];
    [self createDirectoryIfNeeded:identityDir];
    [self.fileManager setAttributes:@{NSFilePosixPermissions: @0755} ofItemAtPath:identityDir error:nil];
    
    // Create identifiers.plist (kept: used for profile display name in the UI)
    NSString *identifiersPath = [profileDir stringByAppendingPathComponent:@"identifiers.plist"];
    NSDictionary *identifiersDict = @{
        @"DisplayName": defaultProfile.name,
        @"Description": @"Default Profile",
        @"Identifier": @"0"
    };
    [identifiersDict writeToFile:identifiersPath atomically:YES];
    [self.fileManager setAttributes:@{NSFilePosixPermissions: @0644} ofItemAtPath:identifiersPath error:nil];
    
    // NOTE: appdata.plist and per-profile scoped-apps.plist are intentionally no
    // longer created here (write-only / always-empty; scope lives in global_scope.plist).
    
    // Add to profiles array
    [self.mutableProfiles addObject:defaultProfile];
    self.mutableCurrentProfile = defaultProfile;
    
    // Save to profiles.plist
    [self saveProfilesWithCompletion:nil];
    
    // Update central profile info
    [self updateCurrentProfileInfoWithProfile:defaultProfile];
    
    // Also write directly to active_profile_info.plist as a backup
    NSString *activeInfoPath = PXLegacyActiveProfileInfoPath();
    NSDictionary *activeInfo = @{
        @"ProfileId": @"0",
        @"ProfileName": defaultProfile.name,
        @"LastSelected": now
    };
    [activeInfo writeToFile:activeInfoPath atomically:YES];
    
    NSLog(@"[WeaponX] ✅ Created and set profile '0' as the default profile");
}

// Immediate profile creation without waiting for loadProfiles
- (void)createProfileZeroImmediately {
    // Create profile directory
    NSString *profileDir = [self.profilesDirectory stringByAppendingPathComponent:@"0"];
    [self createDirectoryIfNeeded:profileDir];
    
    // Create identity directory for device IDs
    NSString *identityDir = [profileDir stringByAppendingPathComponent:@"identity"];
    [self createDirectoryIfNeeded:identityDir];
    [self.fileManager setAttributes:@{NSFilePosixPermissions: @0755} ofItemAtPath:identityDir error:nil];
    
    // Create profile object for internal use
    Profile *defaultProfile = [[Profile alloc] initWithName:@"Default" iconName:@"default_profile"];
    [defaultProfile setValue:@"0" forKey:@"profileId"];
    
    NSDate *now = [NSDate date];
    defaultProfile.createdAt = now;
    defaultProfile.lastUsed = now;
    
    // Create identifiers.plist (kept: used for profile display name in the UI)
    NSString *identifiersPath = [profileDir stringByAppendingPathComponent:@"identifiers.plist"];
    NSDictionary *identifiersDict = @{
        @"DisplayName": @"Default",
        @"Description": @"Default Profile",
        @"Identifier": @"0"
    };
    [identifiersDict writeToFile:identifiersPath atomically:YES];
    [self.fileManager setAttributes:@{NSFilePosixPermissions: @0644} ofItemAtPath:identifiersPath error:nil];
    
    // NOTE: appdata.plist and per-profile scoped-apps.plist are intentionally no
    // longer created here (write-only / always-empty; scope lives in global_scope.plist).
    
    // Create device_ids.plist in identity directory for immediate identifier storage
    NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
    NSError *seedError = nil;
    if (!PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        BOOL exists = NO;
        NSDictionary *ids = [tx dictionaryAtPath:deviceIdsPath exists:&exists error:error];
        return ids && (exists || [tx setDictionary:@{} atPath:deviceIdsPath error:error]);
    }, &seedError)) NSLog(@"[ProfileManager] Profile 0 seed failed: %@", seedError);
    
    NSLog(@"[WeaponX] ✅ Immediately created profile '0' directory structure");
}

@end
