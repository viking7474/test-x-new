#import "DyldCacheUUIDManager.h"
#import "PXRuntimeScalarPreparation.h"
#import "PXIdentityValidator.h"
#import "TLinkIOSLogging.h"

@interface DyldCacheUUIDManager ()
@property (nonatomic, strong) NSString *currentIdentifier;
@property (nonatomic, strong) NSError *error;
@end

@implementation DyldCacheUUIDManager

+ (instancetype)sharedManager {
    static DyldCacheUUIDManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (NSString *)generateDyldCacheUUID {
    NSError *error = nil;
    NSString *prepared = PXPrepareRuntimeScalar(@"DyldCacheUUID", &error);
    self.error = error;
    if (prepared) {
        self.currentIdentifier = [prepared copy];
    }
    return prepared;
}

- (NSString *)currentDyldCacheUUID {
    return self.currentIdentifier;
}

- (void)setCurrentDyldCacheUUID:(NSString *)uuid {
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
