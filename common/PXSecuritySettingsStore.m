#import "PXSecuritySettingsStore.h"
#import "PXPaths.h"
#import "PXRuntimeSnapshot.h"
#import "PXRuntimeSourceStore.h"
#include <stdint.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <float.h>

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

static void PXMirrorSecurityUpdates(NSDictionary *updates, NSArray<NSString *> *suiteNames) {
    // Legacy domains still share physical files with defaults persistence. These
    // are post-commit compatibility effects, not a complete authority contract.
    for (NSString *suiteName in suiteNames) {
        @try {
            NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
            for (NSString *key in updates) [defaults setObject:updates[key] forKey:key];
            [defaults synchronize];
        } @catch (NSException *exception) {
            NSLog(@"[SecuritySettings] Source committed; mirror failed for %@: %@", suiteName, exception);
        }
    }
}

static BOOL PXCommitSecurityMutation(NSDictionary *(^makeUpdates)(NSDictionary *existing, NSError **mutationError),
                                     NSArray<NSString *> *mirrorSuites, NSError **error) {
    NSString *path = PXSecuritySettingsPath();
    __block NSDictionary *updates = nil;
    BOOL committed = PXPerformStandaloneRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        NSDictionary *existing = [tx dictionaryAtPath:path error:writeError];
        if (!existing) return NO; // Never replace a corrupt source with an empty dictionary.
        updates = makeUpdates(existing, writeError);
        if (![updates isKindOfClass:NSDictionary.class]) {
            if (writeError && !*writeError) PXSecurityWriteError(writeError, @"Invalid security mutation packet");
            return NO;
        }
        NSMutableDictionary *candidate = [existing mutableCopy];
        [candidate addEntriesFromDictionary:updates];
        return [tx setDictionary:candidate atPath:path error:writeError];
    }, error);
    if (!committed) return NO;
    PXMirrorSecurityUpdates(updates, mirrorSuites);
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
    return PXCommitSecurityMutation(^NSDictionary *(NSDictionary *existing, NSError **mutationError) {
        (void)existing; (void)mutationError; return updates;
    }, PXSecuritySuiteNames(), error);
}

BOOL PXAdvanceSecurityNonce(NSString *key, uint32_t *committedValue, NSError **error) {
    if (error) *error = nil;
    if (![key isKindOfClass:NSString.class] || !key.length) return PXSecurityWriteError(error, @"Invalid security nonce key");
    key = [key copy];
    __block uint32_t next = 0;
    BOOL committed = PXCommitSecurityMutation(^NSDictionary *(NSDictionary *existing, NSError **mutationError) {
        (void)mutationError;
        id previous = existing[key];
        uint32_t value = [previous respondsToSelector:@selector(unsignedIntValue)] ? [previous unsignedIntValue] : 0;
        next = value == UINT32_MAX ? 1 : value + 1;
        if (!next) next = 1;
        return @{key: @(next)};
    }, PXSecuritySuiteNames(), error);
    if (committed && committedValue) *committedValue = next;
    return committed;
}

static BOOL PXClearMetricCount(id raw, NSUInteger *count) {
    if (!raw) { *count = 0; return YES; }
    NSString *text = nil;
    if ([raw isKindOfClass:NSNumber.class]) {
        const char *type = [raw objCType];
        if (!type || !type[0] || !strchr("BcCsSiIlLqQ", type[0])) return NO;
        text = [raw stringValue];
    } else if ([raw isKindOfClass:NSString.class]) {
        text = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    } else return NO;
    const char *start = text.UTF8String;
    const char *bytes = start;
    if (bytes && bytes[0] == '+') bytes++;
    if (!bytes || bytes[0] < '0' || bytes[0] > '9') return NO;
    int savedErrno = errno; errno = 0;
    char *end = NULL;
    unsigned long long value = strtoull(bytes, &end, 10);
    BOOL valid = errno != ERANGE && end && (NSUInteger)(end - start) == [text lengthOfBytesUsingEncoding:NSUTF8StringEncoding] &&
        value <= (unsigned long long)NSIntegerMax;
    errno = savedErrno;
    if (valid) *count = (NSUInteger)value;
    return valid;
}

BOOL PXRecordClearAttempt(BOOL firstAttemptSuccess, NSUInteger *totalAttempts, NSUInteger *firstAttemptSuccesses, NSError **error) {
    if (error) *error = nil;
    __block NSUInteger nextAttempts = 0, nextSuccesses = 0;
    // These legacy telemetry keys belonged only to the canonical suite. Do not
    // broaden their mirror domains or add extra defaults work on every clear.
    BOOL committed = PXCommitSecurityMutation(^NSDictionary *(NSDictionary *existing, NSError **mutationError) {
        NSUInteger attempts = 0, successes = 0;
        if (!PXClearMetricCount(existing[@"clearAttemptCount"], &attempts) ||
            !PXClearMetricCount(existing[@"clearFirstAttemptSuccessCount"], &successes) ||
            successes > attempts || attempts == (NSUInteger)NSIntegerMax) {
            PXSecurityWriteError(mutationError, @"Invalid or exhausted clear metric counters"); return nil;
        }
        nextAttempts = attempts + 1;
        nextSuccesses = successes + (firstAttemptSuccess ? 1 : 0);
        return @{ @"clearAttemptCount": @(nextAttempts), @"clearFirstAttemptSuccessCount": @(nextSuccesses) };
    }, @[@"com.weaponx.securitySettings"], error);
    if (committed) {
        if (totalAttempts) *totalAttempts = nextAttempts;
        if (firstAttemptSuccesses) *firstAttemptSuccesses = nextSuccesses;
    }
    return committed;
}

BOOL PXWriteProfileIndicatorPosition(double x, double y, NSError **error) {
    if (error) *error = nil;
    if (!isfinite(x) || !isfinite(y) || fabs(x) > FLT_MAX || fabs(y) > FLT_MAX)
        return PXSecurityWriteError(error, @"Invalid indicator position");
    // setFloat was the legacy fallback writer; retain that precision. The
    // preferred dedicated file keeps the original CGFloat/double coordinates.
    NSDictionary *updates = @{ @"ProfileIndicatorX": @((float)x), @"ProfileIndicatorY": @((float)y) };
    NSDictionary *position = @{ @"X": @(x), @"Y": @(y), @"Timestamp": [NSDate date] };
    NSString *settingsPath = PXSecuritySettingsPath();
    NSString *positionPath = PXProfileIndicatorPositionPath();
    if (![NSFileManager.defaultManager createDirectoryAtPath:positionPath.stringByDeletingLastPathComponent
        withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    BOOL committed = PXPerformStandaloneRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        NSDictionary *existing = [tx dictionaryAtPath:settingsPath error:writeError];
        if (!existing) return NO;
        NSMutableDictionary *candidate = [existing mutableCopy];
        [candidate addEntriesFromDictionary:updates];
        return [tx setDictionary:candidate atPath:settingsPath error:writeError] &&
               [tx setDictionary:position atPath:positionPath error:writeError];
    }, error);
    if (!committed) return NO;
    PXMirrorSecurityUpdates(updates, @[@"com.weaponx.securitySettings"]);
    return YES;
}

BOOL PXWriteSecuritySetting(NSString *key, id value, NSError **error) {
    if (error) *error = nil;
    if (![key isKindOfClass:NSString.class] || !key.length || !value) return PXSecurityWriteError(error, @"Invalid security setting key/value");
    return PXWriteSecuritySettings(@{key: value}, error);
}

BOOL PXWriteSecurityBool(NSString *key, BOOL value, NSError **error) {
    return PXWriteSecuritySetting(key, @(value), error);
}

BOOL PXWriteSecurityBoolWithRollbackAuthority(NSString *key, BOOL value, NSString *expectedIdentifier,
                                       NSString **rollbackIdentifier, NSError **error) {
    if (rollbackIdentifier) *rollbackIdentifier = nil;
    if (error) *error = nil;
    if (![key isKindOfClass:NSString.class] || !key.length ||
        ![expectedIdentifier isKindOfClass:NSString.class] || !expectedIdentifier.length)
        return PXSecurityWriteError(error, @"Invalid conditional security write");
    key = [key copy]; expectedIdentifier = [expectedIdentifier copy];
    NSString *path = PXSecuritySettingsPath();
    __block NSString *candidate = nil;
    BOOL success = PXPerformStandaloneRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **failure) {
        NSString *base = [tx baseCommitIdentifierWithError:failure];
        if (!base) return NO;
        BOOL ownsChain = [base isEqual:expectedIdentifier];
        NSDictionary *existing = [tx dictionaryAtPath:path error:failure];
        if (!existing) return NO;
        NSMutableDictionary *settings = [existing mutableCopy]; settings[key] = @(value);
        if (![tx setDictionary:settings atPath:path error:failure]) return NO;
        candidate = ownsChain ? [tx prospectiveCommitIdentifierWithError:failure] : nil;
        return !ownsChain || candidate != nil;
    }, error);
    if (!success) return NO;
    if (rollbackIdentifier) *rollbackIdentifier = candidate;
    PXMirrorSecurityUpdates(@{key: @(value)}, PXSecuritySuiteNames());
    return YES;
}
BOOL PXPublishSecurityBoolForSourceCommit(NSString *key, BOOL value, NSString *identifier) {
    if (![key isKindOfClass:NSString.class] || !key.length ||
        ![identifier isKindOfClass:NSString.class] || !identifier.length) return NO;
    key = [key copy]; identifier = [identifier copy];
    BOOL (^current)(PXRuntimeSourceTransaction *, NSError **) = ^BOOL(PXRuntimeSourceTransaction *tx, NSError **error) {
        return [tx requireBaseCommitIdentifier:identifier error:error];
    };
    if (!PXPerformStandaloneRuntimeSourceWrite(current, NULL)) return NO;
    PXMirrorSecurityUpdates(@{key: @(value)}, PXSecuritySuiteNames());
    return PXPerformStandaloneRuntimeSourceWrite(current, NULL);
}

BOOL PXWriteSecurityInteger(NSString *key, NSInteger value, NSError **error) {
    return PXWriteSecuritySetting(key, @(value), error);
}
