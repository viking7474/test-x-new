#import "DyldCacheUUIDManager.h"
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
    // Generate a valid UUID format (8-4-4-4-12)
    NSMutableString *uuid = [NSMutableString string];
    
    // Characters for hex values
    const char chars[] = "0123456789abcdef";
    
    // First section (8 chars)
    for (int i = 0; i < 8; i++) {
        int randomValue = arc4random() % 16;
        [uuid appendFormat:@"%c", chars[randomValue]];
    }
    
    [uuid appendString:@"-"];
    
    // Second section (4 chars)
    for (int i = 0; i < 4; i++) {
        int randomValue = arc4random() % 16;
        [uuid appendFormat:@"%c", chars[randomValue]];
    }
    
    [uuid appendString:@"-"];
    
    // Third section (4 chars) - version 4 UUID
    [uuid appendString:@"4"];
    for (int i = 0; i < 3; i++) {
        int randomValue = arc4random() % 16;
        [uuid appendFormat:@"%c", chars[randomValue]];
    }
    
    [uuid appendString:@"-"];
    
    // Fourth section (4 chars) - variant
    int randomValue = arc4random() % 4 + 8; // 8, 9, A, or B
    [uuid appendFormat:@"%c", chars[randomValue]];
    for (int i = 0; i < 3; i++) {
        randomValue = arc4random() % 16;
        [uuid appendFormat:@"%c", chars[randomValue]];
    }
    
    [uuid appendString:@"-"];
    
    // Fifth section (12 chars)
    for (int i = 0; i < 12; i++) {
        randomValue = arc4random() % 16;
        [uuid appendFormat:@"%c", chars[randomValue]];
    }
    
    // Validate and return
    if ([self isValidUUID:uuid]) {
        self.currentIdentifier = [uuid copy];
        return uuid;
    }
    
    // If validation failed, return error
    self.error = [NSError errorWithDomain:@"com.weaponx.DyldCacheUUIDManager" 
                                     code:1001 
                                 userInfo:@{NSLocalizedDescriptionKey: @"Generated Dyld Cache UUID failed validation"}];
    return nil;
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