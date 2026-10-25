#import "CoreDataUUIDManager.h"
#import "PXRuntimeScalarPreparation.h"
#import "PXIdentityValidator.h"
#import "TLinkIOSLogging.h"

@interface CoreDataUUIDManager ()
@property (nonatomic, strong) NSString *currentIdentifier;
@property (nonatomic, strong) NSError *error;
@end

@implementation CoreDataUUIDManager

+ (instancetype)sharedManager {
    static CoreDataUUIDManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (NSString *)generateCoreDataUUID {
    NSError *error = nil;
    NSString *prepared = PXPrepareRuntimeScalar(@"CoreDataUUID", &error);
    self.error = error;
    if (prepared) {
        self.currentIdentifier = [prepared copy];
    }
    return prepared;
}

- (NSString *)currentCoreDataUUID {
    return self.currentIdentifier;
}

- (void)setCurrentCoreDataUUID:(NSString *)uuid {
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
