#import "UserDefaultsUUIDManager.h"
#import "PXRuntimeScalarPreparation.h"
#import "PXIdentityValidator.h"
#import "TLinkIOSLogging.h"

@interface UserDefaultsUUIDManager ()
@property (nonatomic, strong) NSString *currentIdentifier;
@property (nonatomic, strong) NSError *error;
@end

@implementation UserDefaultsUUIDManager

+ (instancetype)sharedManager {
    static UserDefaultsUUIDManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (NSString *)generateUserDefaultsUUID {
    NSError *error = nil;
    NSString *prepared = PXPrepareRuntimeScalar(@"UserDefaultsUUID", &error);
    self.error = error;
    if (prepared) {
        self.currentIdentifier = [prepared copy];
    }
    return prepared;
}

- (NSString *)currentUserDefaultsUUID {
    return self.currentIdentifier;
}

- (void)setCurrentUserDefaultsUUID:(NSString *)uuid {
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
