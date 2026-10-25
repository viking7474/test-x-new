#import "DeviceNameManager.h"
#import "PXRuntimeScalarPreparation.h"
#import <Security/Security.h>
#import <time.h>

@interface DeviceNameManager ()
@property (nonatomic, strong) NSString *currentIdentifier;
@property (nonatomic, strong) NSError *error;
@end

@implementation DeviceNameManager

+ (instancetype)sharedManager {
    static DeviceNameManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (NSString *)generateDeviceName {
    NSError *error = nil;
    NSString *prepared = PXPrepareRuntimeScalar(@"DeviceName", &error);
    self.error = error;
    if (prepared) {
        self.currentIdentifier = [prepared copy];
    }
    return prepared;
}

- (NSString *)currentDeviceName {
    return self.currentIdentifier;
}

- (void)setCurrentDeviceName:(NSString *)deviceName {
    if ([self isValidDeviceName:deviceName]) {
        self.currentIdentifier = [deviceName copy];
    }
}

- (BOOL)isValidDeviceName:(NSString *)deviceName {
    if (!deviceName) return NO;
    
    // Basic validation - ensure it's not empty and not too long
    if (deviceName.length == 0 || deviceName.length > 50) {
        return NO;
    }
    
    // Ensure it doesn't contain any invalid characters
    NSCharacterSet *invalidChars = [NSCharacterSet characterSetWithCharactersInString:@"<>:\"/\\|?*"];
    if ([deviceName rangeOfCharacterFromSet:invalidChars].location != NSNotFound) {
        return NO;
    }
    
    return YES;
}

- (NSError *)lastError {
    return self.error;
}

@end
