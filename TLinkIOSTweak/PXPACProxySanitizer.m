#import "PXPACProxySanitizer.h"
#import <CFNetwork/CFNetwork.h>
#import <dispatch/dispatch.h>

static NSString *PXPACProxyTypeKey(void) {
    return (__bridge NSString *)kCFProxyTypeKey;
}

static NSString *PXPACDirectType(void) {
    return (__bridge NSString *)kCFProxyTypeNone;
}

static NSArray<NSString *> *PXPACManagedProxyKeys(void) {
    static NSArray<NSString *> *keys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @[
            @"kCFProxyHostNameKey",
            @"kCFProxyPortNumberKey",
            @"kCFProxyAutoConfigurationURLKey",
            @"kCFProxyAutoConfigurationJavaScriptKey",
            @"kCFProxyUsernameKey",
            @"kCFProxyPasswordKey",
        ];
    });
    return keys;
}

id PXPACProjectedProxyValue(id originalValue, BOOL bypassEnabled) {
    if (!bypassEnabled || !originalValue) return originalValue;
    if (![originalValue isKindOfClass:[NSArray class]]) return originalValue;

    NSArray *originalArray = (NSArray *)originalValue;
    NSMutableArray *projected = [NSMutableArray arrayWithCapacity:originalArray.count];

    for (id entry in originalArray) {
        if (![entry isKindOfClass:[NSDictionary class]]) return originalValue;
        NSDictionary *dictionary = (NSDictionary *)entry;
        id type = dictionary[PXPACProxyTypeKey()];
        if (![type isKindOfClass:[NSString class]] || [(NSString *)type length] == 0) {
            return originalValue;
        }

        NSMutableDictionary *sanitized = [dictionary mutableCopy];
        sanitized[PXPACProxyTypeKey()] = PXPACDirectType();
        for (NSString *key in PXPACManagedProxyKeys()) {
            [sanitized removeObjectForKey:key];
        }
        [projected addObject:[sanitized copy]];
    }

    return [projected copy];
}
