#import "AppGroupUUIDManager.h"
#import "PXRuntimeScalarPreparation.h"
#import "PXIdentityValidator.h"
#import "TLinkIOSLogging.h"

@interface AppGroupUUIDManager ()
@property (nonatomic, strong) NSString *currentIdentifier;
@property (nonatomic, strong) NSError *error;
@end

@implementation AppGroupUUIDManager

+ (instancetype)sharedManager {
    static AppGroupUUIDManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (NSString *)generateAppGroupUUID {
    NSError *error = nil;
    NSString *prepared = PXPrepareRuntimeScalar(@"AppGroupUUID", &error);
    self.error = error;
    if (prepared) {
        self.currentIdentifier = [prepared copy];
    }
    return prepared;
}

- (NSString *)currentAppGroupUUID {
    return self.currentIdentifier;
}

- (void)setCurrentAppGroupUUID:(NSString *)uuid {
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
