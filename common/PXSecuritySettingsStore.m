#import "PXSecuritySettingsStore.h"
#import "PXPaths.h"
#import "PXRuntimeSnapshot.h"
#import "PXRuntimeSourceStore.h"
#include <stdint.h>

static NSArray<NSString *> *PXSecuritySuiteNames(void) {
    static NSArray<NSString *> *names;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = @[
            @"com.weaponx.securitySettings",
            @"com.hydra.tlinkios.SecuritySettings",
            @"com.hydra.tlinkios"
        ];
    });
    return names;
}

id PXReadSecuritySetting(NSString *key) {
    if (key.length == 0) return nil;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.hydra.tlinkios"]) {
        return PXCaptureRuntimeSnapshot().securitySettings[key];
    }
#endif
    NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:PXSecuritySettingsPath()];
    id value = disk[key];
    if (value != nil) return value;

    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
    return [defaults objectForKey:key];
}

BOOL PXReadSecurityBool(NSString *key, BOOL defaultValue) {
    id value = PXReadSecuritySetting(key);
    return ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class]) ? [value boolValue] : defaultValue;
}

NSInteger PXReadSecurityInteger(NSString *key, NSInteger defaultValue) {
    id value = PXReadSecuritySetting(key);
    return ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class]) ? [value integerValue] : defaultValue;
}

static BOOL PXSecurityWriteError(NSError **error, NSString *message) {
    if (error) *error = [NSError errorWithDomain:@"com.hydra.tlinkios.security-settings" code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}

static void PXMirrorSecurityUpdates(NSDictionary *updates) {
    // Legacy domains still share physical files with defaults persistence. These
    // are post-commit compatibility effects, not a complete authority contract.
    for (NSString *suiteName in PXSecuritySuiteNames()) {
        @try {
            NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
            for (NSString *key in updates) [defaults setObject:updates[key] forKey:key];
            [defaults synchronize];
        } @catch (NSException *exception) {
            NSLog(@"[SecuritySettings] Source committed; mirror failed for %@: %@", suiteName, exception);
        }
    }
}

static BOOL PXCommitSecurityMutation(NSDictionary *(^makeUpdates)(NSDictionary *existing), NSError **error) {
    NSString *path = PXSecuritySettingsPath();
    __block NSDictionary *updates = nil;
    BOOL committed = PXPerformStandaloneRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        NSDictionary *existing = [tx dictionaryAtPath:path error:writeError];
        if (!existing) return NO; // Never replace a corrupt source with an empty dictionary.
        updates = makeUpdates(existing);
        NSMutableDictionary *candidate = [existing mutableCopy];
        [candidate addEntriesFromDictionary:updates];
        return [tx setDictionary:candidate atPath:path error:writeError];
    }, error);
    if (!committed) return NO;
    PXMirrorSecurityUpdates(updates);
    return YES;
}

BOOL PXWriteSecuritySettings(NSDictionary<NSString *, id> *values, NSError **error) {
    if (error) *error = nil;
    if (![values isKindOfClass:NSDictionary.class]) return PXSecurityWriteError(error, @"Invalid security update packet");
    for (id key in values)
        if (![key isKindOfClass:NSString.class] || ![key length]) return PXSecurityWriteError(error, @"Invalid security setting key");
    if (!values.count) return YES;
    NSError *serializationError = nil;
    NSDictionary *updates = nil;
    @try {
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:values format:NSPropertyListBinaryFormat_v1_0 options:0 error:&serializationError];
        updates = data ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&serializationError] : nil;
    } @catch (__unused NSException *exception) {
        return PXSecurityWriteError(error, @"Security update packet is not a property list");
    }
    if (!updates) {
        if (error) *error = serializationError;
        return NO;
    }
    return PXCommitSecurityMutation(^NSDictionary *(NSDictionary *existing) { (void)existing; return updates; }, error);
}

BOOL PXAdvanceSecurityNonce(NSString *key, uint32_t *committedValue, NSError **error) {
    if (error) *error = nil;
    if (![key isKindOfClass:NSString.class] || !key.length) return PXSecurityWriteError(error, @"Invalid security nonce key");
    key = [key copy];
    __block uint32_t next = 0;
    BOOL committed = PXCommitSecurityMutation(^NSDictionary *(NSDictionary *existing) {
        id previous = existing[key];
        uint32_t value = [previous respondsToSelector:@selector(unsignedIntValue)] ? [previous unsignedIntValue] : 0;
        next = value == UINT32_MAX ? 1 : value + 1;
        if (!next) next = 1;
        return @{key: @(next)};
    }, error);
    if (committed && committedValue) *committedValue = next;
    return committed;
}

BOOL PXWriteSecuritySetting(NSString *key, id value, NSError **error) {
    if (error) *error = nil;
    if (![key isKindOfClass:NSString.class] || !key.length || !value) return PXSecurityWriteError(error, @"Invalid security setting key/value");
    return PXWriteSecuritySettings(@{key: value}, error);
}

BOOL PXWriteSecurityBool(NSString *key, BOOL value, NSError **error) {
    return PXWriteSecuritySetting(key, @(value), error);
}

BOOL PXWriteSecurityInteger(NSString *key, NSInteger value, NSError **error) {
    return PXWriteSecuritySetting(key, @(value), error);
}
