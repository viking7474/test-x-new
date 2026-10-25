#import "AppContainerUUIDManager.h"
#import "PXRuntimeScalarPreparation.h"
#import "PXIdentityValidator.h"
#import "TLinkIOSLogging.h"

@interface AppContainerUUIDManager ()
@property (nonatomic, strong) NSString *currentIdentifier;
@property (nonatomic, strong) NSError *error;
@end

@implementation AppContainerUUIDManager

+ (instancetype)sharedManager {
    static AppContainerUUIDManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (NSString *)generateAppContainerUUID {
    NSError *error = nil;
    NSString *prepared = PXPrepareRuntimeScalar(@"AppContainerUUID", &error);
    self.error = error;
    if (prepared) {
        self.currentIdentifier = [prepared copy];
        PXLog(@"[WeaponX] Generated App Container UUID: %@", prepared);
    }
    return prepared;
}

- (NSString *)currentAppContainerUUID {
    return self.currentIdentifier;
}

- (void)setCurrentAppContainerUUID:(NSString *)uuid {
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
