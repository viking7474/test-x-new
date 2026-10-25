#import "SerialNumberManager.h"
#import "PXRuntimeScalarPreparation.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <unistd.h>
#import <Security/Security.h>
#import <sys/sysctl.h>
#include <sys/proc.h>
#import <mach-o/dyld.h>

@interface SerialNumberManager ()
@property (nonatomic, strong) NSString *currentIdentifier;
@property (nonatomic, strong) NSError *error;
@end

@implementation SerialNumberManager

+ (instancetype)sharedManager {
    static SerialNumberManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

+ (void)initialize {
    if (self == [SerialNumberManager class]) {
        atexit_b(^{
            [[SerialNumberManager sharedManager] clearSensitiveData];
        });
    }
}

- (BOOL)isBeingDebugged {
    int name[4];
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    
    name[0] = CTL_KERN;
    name[1] = KERN_PROC;
    name[2] = KERN_PROC_PID;
    name[3] = getpid();
    
    if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) {
        return NO;
    }
    
    return ((info.kp_proc.p_flag & P_TRACED) != 0);
}

- (BOOL)isEnvironmentSecure {
    // Check for debugging
    if ([self isBeingDebugged]) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                       code:4003 
                                   userInfo:@{NSLocalizedDescriptionKey: @"Debug environment detected"}];
        return NO;
    }
    
    // Basic integrity check
    if (![self verifyCodeIntegrity]) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios"
                                       code:4004 
                                   userInfo:@{NSLocalizedDescriptionKey: @"Code integrity check failed"}];
        return NO;
    }
    
    return YES;
}

- (BOOL)verifyCodeIntegrity {
    // Basic dyld image count check
    uint32_t count = _dyld_image_count();
    if (count < 1) return NO;
    
    // You can add more integrity checks here
    return YES;
}

- (void)clearSensitiveData {
    // NSString owns its UTF8String buffer. Release our reference; writing through
    // that borrowed const pointer can corrupt immutable/shared or tagged storage.
    self.currentIdentifier = nil;
}

- (NSString *)prepareSerialNumber {
    if (![self isEnvironmentSecure]) return nil;
    self.error = nil;
    // Preserve the existing policy delay outside persistence/source locks.
    usleep(arc4random_uniform(50000));
    NSArray *prefixes = @[@"C02", @"FVF", @"DLXJ", @"GG78", @"HC79"];
    static atomic_uint patternIndex = 0;
    unsigned int previous = atomic_load_explicit(&patternIndex, memory_order_relaxed), next;
    do { next = (previous + 1) % (unsigned int)prefixes.count; }
    while (!atomic_compare_exchange_weak_explicit(&patternIndex, &previous, next, memory_order_relaxed, memory_order_relaxed));
    NSError *error = nil;
    NSString *prepared = PXPrepareRuntimeSerial(prefixes[next], &error);
    self.error = error;
    if (!prepared) return nil;
    if (![self isValidSerialNumber:prepared]) {
        self.error = [NSError errorWithDomain:@"com.hydra.tlinkios" code:4002
            userInfo:@{NSLocalizedDescriptionKey: @"Generated serial number failed validation"}];
        return nil;
    }
    return prepared;
}

- (NSString *)generateSerialNumber {
    NSString *prepared = [self prepareSerialNumber];
    if (!prepared) return nil;
    [self clearSensitiveData];
    self.currentIdentifier = [prepared copy];
    return self.currentIdentifier;
}

- (NSString *)currentSerialNumber {
    if (![self isEnvironmentSecure]) {
        return nil;
    }
    return self.currentIdentifier;
}

- (void)setCurrentSerialNumber:(NSString *)serialNumber {
    if (![self isEnvironmentSecure]) {
        return;
    }
    
    if ([self isValidSerialNumber:serialNumber]) {
        [self clearSensitiveData];  // Clear any previous value securely
        self.currentIdentifier = [serialNumber copy];
    }
}

- (BOOL)isValidSerialNumber:(NSString *)serialNumber {
    if (!serialNumber) return NO;
    
    if (![self isEnvironmentSecure]) {
        return NO;
    }
    
    // Check format using regex for various Apple device serial number formats
    // Pattern matches common prefixes followed by 7-8 alphanumeric characters
    NSString *pattern = @"^(C02|FVF|DLXJ|GG78|HC79)[0-9A-Z]{7,8}$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                         options:0
                                                                           error:nil];
    NSUInteger matches = [regex numberOfMatchesInString:serialNumber
                                               options:0
                                                 range:NSMakeRange(0, serialNumber.length)];
    
    return matches == 1;
}

- (NSError *)lastError {
    return self.error;
}

- (void)dealloc {
    [self clearSensitiveData];
}

@end
