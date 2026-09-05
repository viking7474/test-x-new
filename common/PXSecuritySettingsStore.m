#import "PXSecuritySettingsStore.h"
#import "PXPaths.h"
#import <fcntl.h>
#import <sys/file.h>
#import <unistd.h>

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

static int PXAcquireSecuritySettingsLock(NSString *settingsPath) {
    NSString *lockPath = [settingsPath stringByAppendingString:@".lock"];
    int fd = open(lockPath.fileSystemRepresentation, O_CREAT | O_RDWR, 0644);
    if (fd < 0) return -1;
    if (flock(fd, LOCK_EX) != 0) {
        close(fd);
        return -1;
    }
    return fd;
}

static void PXReleaseSecuritySettingsLock(int fd) {
    if (fd < 0) return;
    flock(fd, LOCK_UN);
    close(fd);
}

id PXReadSecuritySetting(NSString *key) {
    if (key.length == 0) return nil;
    NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:PXSecuritySettingsPath()];
    id value = disk[key];
    if (value != nil) return value;

    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
    return [defaults objectForKey:key];
}

BOOL PXReadSecurityBool(NSString *key, BOOL defaultValue) {
    id value = PXReadSecuritySetting(key);
    return value == nil ? defaultValue : [value boolValue];
}

NSInteger PXReadSecurityInteger(NSString *key, NSInteger defaultValue) {
    id value = PXReadSecuritySetting(key);
    return value == nil ? defaultValue : [value integerValue];
}

BOOL PXWriteSecuritySetting(NSString *key, id value, NSError **error) {
    if (key.length == 0 || value == nil) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.hydra.tlinkios.security-settings"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid security setting key/value"}];
        }
        return NO;
    }

    NSString *path = PXSecuritySettingsPath();
    int lockFD = PXAcquireSecuritySettingsLock(path);
    if (lockFD < 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.hydra.tlinkios.security-settings"
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey: @"Could not lock security settings for writing"}];
        }
        return NO;
    }

    BOOL success = NO;
    @try {
        NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithContentsOfFile:path];
        if (![settings isKindOfClass:[NSMutableDictionary class]]) {
            settings = [NSMutableDictionary dictionary];
        }
        settings[key] = value;

        NSError *serializationError = nil;
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:settings
                                                                   format:NSPropertyListXMLFormat_v1_0
                                                                  options:0
                                                                    error:&serializationError];
        if (!data) {
            if (error) *error = serializationError;
            return NO;
        }

        if (![data writeToFile:path options:NSDataWritingAtomic error:error]) {
            return NO;
        }
        success = YES;
    } @finally {
        PXReleaseSecuritySettingsLock(lockFD);
    }

    if (!success) return NO;

    // Mirrors are best-effort compatibility copies only. Runtime truth is the verified plist above.
    for (NSString *suiteName in PXSecuritySuiteNames()) {
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
        [defaults setObject:value forKey:key];
        [defaults synchronize];
    }
    return YES;
}

BOOL PXWriteSecurityBool(NSString *key, BOOL value, NSError **error) {
    return PXWriteSecuritySetting(key, @(value), error);
}

BOOL PXWriteSecurityInteger(NSString *key, NSInteger value, NSError **error) {
    return PXWriteSecuritySetting(key, @(value), error);
}
