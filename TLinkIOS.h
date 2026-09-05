#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

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

// Settings Management
- (void)setIdentifierEnabled:(BOOL)enabled forType:(NSString *)type;
- (BOOL)setIdentifierEnabledAndPersist:(BOOL)enabled forType:(NSString *)type;
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