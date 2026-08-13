#import "PXPaths.h"
#import <CoreFoundation/CoreFoundation.h>

static NSString *PXFirstExistingPath(NSArray<NSString *> *paths, NSString *fallback) {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in paths) {
        if (path.length && [fm fileExistsAtPath:path]) {
            return path;
        }
    }
    return fallback;
}

NSString *PXMobileLibraryPath(void) {
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        path = PXFirstExistingPath(@[
            @"/var/mobile/Library",
            @"/private/var/mobile/Library",
            @"/var/jb/var/mobile/Library",
            @"/private/var/jb/var/mobile/Library"
        ], @"/var/mobile/Library");
    });
    return path;
}

NSString *PXPreferencesPath(void) {
    return [PXMobileLibraryPath() stringByAppendingPathComponent:@"Preferences"];
}

NSString *PXWeaponXBasePath(void) {
    return [PXMobileLibraryPath() stringByAppendingPathComponent:@"WeaponX"];
}

NSString *PXProfilesPath(void) {
    return [PXWeaponXBasePath() stringByAppendingPathComponent:@"Profiles"];
}

NSString *PXCurrentProfileInfoPath(void) {
    return [PXProfilesPath() stringByAppendingPathComponent:@"current_profile_info.plist"];
}

NSString *PXLegacyActiveProfileInfoPath(void) {
    return [PXWeaponXBasePath() stringByAppendingPathComponent:@"active_profile_info.plist"];
}

NSString *PXValidatedProfileID(id value) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *profileID = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!profileID.length || profileID.length > 128) return nil;
    if ([profileID caseInsensitiveCompare:@"Unknown"] == NSOrderedSame ||
        [profileID isEqualToString:@"."] ||
        [profileID isEqualToString:@".."] ||
        [profileID rangeOfString:@"/"].location != NSNotFound ||
        [profileID rangeOfString:@"\\"].location != NSNotFound ||
        ![[profileID lastPathComponent] isEqualToString:profileID]) {
        return nil;
    }
    return profileID;
}

NSString *PXActiveProfileID(void) {
    NSDictionary *currentInfo = [NSDictionary dictionaryWithContentsOfFile:PXCurrentProfileInfoPath()];
    NSString *profileID = PXValidatedProfileID(currentInfo[@"ProfileId"]);
    if (profileID.length) return profileID;

    NSDictionary *legacyInfo = [NSDictionary dictionaryWithContentsOfFile:PXLegacyActiveProfileInfoPath()];
    profileID = PXValidatedProfileID(legacyInfo[@"ProfileId"]);
    if (!profileID.length) profileID = PXValidatedProfileID(legacyInfo[@"currentProfileId"]);
    return profileID;
}

NSString *PXProfileRootPath(NSString *profileID) {
    NSString *validated = PXValidatedProfileID(profileID);
    return validated.length ? [PXProfilesPath() stringByAppendingPathComponent:validated] : nil;
}

NSString *PXProfileIdentityPath(NSString *profileID) {
    NSString *root = PXProfileRootPath(profileID);
    return root.length ? [root stringByAppendingPathComponent:@"identity"] : nil;
}

NSString *PXProfileDeviceIDsPath(NSString *profileID) {
    NSString *identity = PXProfileIdentityPath(profileID);
    return identity.length ? [identity stringByAppendingPathComponent:@"device_ids.plist"] : nil;
}

NSString *PXActiveProfileRootPath(void) {
    return PXProfileRootPath(PXActiveProfileID());
}

NSString *PXActiveProfileIdentityPath(void) {
    return PXProfileIdentityPath(PXActiveProfileID());
}

NSString *PXActiveProfileDeviceIDsPath(void) {
    return PXProfileDeviceIDsPath(PXActiveProfileID());
}

NSString *PXTLinkIOSSettingsPath(void) {
    return [PXPreferencesPath() stringByAppendingPathComponent:@"com.hydra.tlinkios.settings.plist"];
}

NSString *PXGlobalScopePath(void) {
    return [PXPreferencesPath() stringByAppendingPathComponent:@"com.hydra.tlinkios.global_scope.plist"];
}

NSString *PXSecuritySettingsPath(void) {
    return [PXPreferencesPath() stringByAppendingPathComponent:@"com.weaponx.securitySettings.plist"];
}

void PXPostSettingsChangedNotification(void) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         CFSTR("com.hydra.tlinkios.settings.changed"),
                                         NULL,
                                         NULL,
                                         true);
}
