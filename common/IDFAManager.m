#import "IDFAManager.h"
#import "PXRuntimeScalarPreparation.h"
#import <Security/Security.h>

@interface IDFAManager ()
@property (nonatomic, strong) NSString *currentIdentifier;
@property (nonatomic, strong) NSError *error;
@end

@implementation IDFAManager

+ (instancetype)sharedManager {
    static IDFAManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (NSString *)generateIDFA {
    NSError *error = nil;
    NSString *prepared = PXPrepareRuntimeScalar(@"IDFA", &error);
    self.error = error;
    if (prepared) {
        self.currentIdentifier = [prepared copy];
    }
    return prepared;
}

- (NSString *)currentIDFA {
    return self.currentIdentifier;
}

- (void)setCurrentIDFA:(NSString *)idfa {
    if ([self isValidIDFA:idfa]) {
        self.currentIdentifier = [idfa copy];
    }
}

- (BOOL)isValidIDFA:(NSString *)idfa {
    if (!idfa) return NO;
    
    // Check format using regex
    NSString *pattern = @"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                         options:0
                                                                           error:nil];
    NSUInteger matches = [regex numberOfMatchesInString:idfa
                                               options:0
                                                 range:NSMakeRange(0, idfa.length)];
    
    return matches == 1;
}

- (NSError *)lastError {
    return self.error;
}

@end
