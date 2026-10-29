#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class PXCommittedRuntimeGeneration;
@class PXProfileLifecycleLease;

@interface IdentifierManager : NSObject

+ (instancetype)sharedManager;

// Identifier Management
- (NSString *)generateIDFA;
- (NSString *)generateIDFV;
- (NSString *)generateDeviceName;
- (NSString *)generateSerialNumber;
- (NSDictionary *)generateIOSVersion;
- (NSString *)generateWiFiInformation;
- (NSString *)generateSystemBootUUID;
- (NSString *)generateDyldCacheUUID;
- (NSString *)generatePasteboardUUID;
- (NSString *)generateKeychainUUID;
- (NSString *)generateUserDefaultsUUID;
- (NSString *)generateAppGroupUUID;
- (NSString *)generateCoreDataUUID;
- (NSString *)generateAppInstallUUID;
- (NSString *)generateAppContainerUUID;
- (NSString *)generateSystemUptime;
- (NSString *)generateBootTime;
- (NSString *)generateDeviceModel;
- (NSString *)generateUDID;
- (void)regenerateAllEnabledIdentifiers;
// Reports source commit failure. Compatibility cache/mirror effects are best effort after commit.
- (BOOL)regenerateAllEnabledIdentifiersWithError:(NSError **)error;
// Requires this profile to remain the active selection through source commit.
- (BOOL)regenerateAllEnabledIdentifiersForExpectedActiveProfileID:(NSString *)profileID error:(NSError **)error;
// Cold creation workflow: explicit existing profile directory, optional prepared
// network artifacts; never resolve the active profile as the write target.
- (BOOL)regenerateAllEnabledIdentifiersForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)networkArtifacts error:(NSError **)error;
// Creation: commit inactive artifacts, defer settings/scope and publication to activation.
- (PXCommittedRuntimeGeneration *)commitRuntimeGenerationForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)networkArtifacts error:(NSError **)error;
// Creation worker borrows the caller's existing lifecycle ownership. This API
// validates it and never invalidates/releases the caller's capability.
- (PXCommittedRuntimeGeneration *)commitRuntimeGenerationForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)networkArtifacts lifecycleLease:(PXProfileLifecycleLease *)lease error:(NSError **)error;
- (void)publishCommittedRuntimeGeneration:(PXCommittedRuntimeGeneration *)generation;

// Settings Management
- (void)setIdentifierEnabled:(BOOL)enabled forType:(NSString *)type;
- (BOOL)setIdentifierEnabledAndPersist:(BOOL)enabled forType:(NSString *)type;
// Reset preflight: enable only model/iOS/storage/name flags for the expected
// active profile. Never generate artifacts through the legacy toggle setters.
- (BOOL)enableRequiredIdentifiers:(NSArray<NSString *> *)types forExpectedActiveProfileID:(NSString *)profileID error:(NSError **)error;
- (BOOL)isIdentifierEnabled:(NSString *)type;

// Current Values
- (NSString *)currentValueForIdentifier:(NSString *)type;

// ATT Authorization Status (0...3: notDetermined, restricted, denied, authorized)
- (NSInteger)attAuthorizationStatus;
- (void)setATTAuthorizationStatus:(NSInteger)status;

// Profile schema migration (v1 → v2)
- (void)migrateProfileSchemaIfNeeded;

// Persistence
- (void)saveSettings;
- (void)loadSettings;

// Error Handling
- (NSError *)lastError;

@end

@interface TLinkIOSViewController : UIViewController

@property (nonatomic, strong) IdentifierManager *manager;

@end
