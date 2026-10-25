#import "AppInstallUUIDManager.h"
#import "PXRuntimeScalarPreparation.h"
#import "PXIdentityValidator.h"
#import "TLinkIOSLogging.h"

@interface AppInstallUUIDManager ()
@property (nonatomic, strong) NSString *currentIdentifier;
@property (nonatomic, strong) NSError *error;
@end

@implementation AppInstallUUIDManager

+ (instancetype)sharedManager {
    static AppInstallUUIDManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (NSString *)generateAppInstallUUID {
    NSError *error = nil;
    NSString *prepared = PXPrepareRuntimeScalar(@"AppInstallUUID", &error);
    self.error = error;
    if (prepared) {
        self.currentIdentifier = [prepared copy];
        PXLog(@"[WeaponX] Generated App Install UUID: %@", prepared);
    }
    return prepared;
}

- (NSString *)currentAppInstallUUID {
    return self.currentIdentifier;
}

- (void)setCurrentAppInstallUUID:(NSString *)uuid {
    if ([self isValidUUID:uuid]) {
        self.currentIdentifier = [uuid copy];
    }
}

- (BOOL)isValidUUID:(NSString *)uuid {
    return PXValidateIdentityValue(uuid, PXIdentityValueKindUUID, NO);
}

- (NSError *)lastError {
    return self.error;
}

@end
