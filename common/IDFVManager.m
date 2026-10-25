#import "IDFVManager.h"
#import "PXRuntimeScalarPreparation.h"
#import <Security/Security.h>

@interface IDFVManager ()
@property (nonatomic, strong) NSString *currentIdentifier;
@property (nonatomic, strong) NSError *error;
@end

@implementation IDFVManager

+ (instancetype)sharedManager {
    static IDFVManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (NSString *)generateIDFV {
    NSError *error = nil;
    NSString *prepared = PXPrepareRuntimeScalar(@"IDFV", &error);
    self.error = error;
    if (prepared) {
        self.currentIdentifier = [prepared copy];
    }
    return prepared;
}

- (NSString *)currentIDFV {
    return self.currentIdentifier;
}

- (void)setCurrentIDFV:(NSString *)idfv {
    if ([self isValidIDFV:idfv]) {
        self.currentIdentifier = [idfv copy];
    }
}

- (BOOL)isValidIDFV:(NSString *)idfv {
    if (!idfv) return NO;
    
    // Check format using regex
    NSString *pattern = @"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                         options:0
                                                                           error:nil];
    NSUInteger matches = [regex numberOfMatchesInString:idfv
                                               options:0
                                                 range:NSMakeRange(0, idfv.length)];
    
    return matches == 1;
}

- (NSError *)lastError {
    return self.error;
}

@end
