#import <Foundation/Foundation.h>

@interface SerialNumberManager : NSObject

@property (nonatomic, readonly) NSError *lastError;

+ (instancetype)sharedManager;

// Core functionality
- (NSString *)generateSerialNumber;
// Checks environment/reserves a prefix without changing the cached identifier.
- (NSString *)prepareSerialNumber;
- (NSString *)currentSerialNumber;
- (void)setCurrentSerialNumber:(NSString *)serialNumber;

// Validation
- (BOOL)isValidSerialNumber:(NSString *)serialNumber;

// Security methods
- (void)clearSensitiveData;
- (BOOL)isEnvironmentSecure;

@end
