#import "PXDefaultProfileSeed.h"
#import "PXProfileLifecycleLease.h"
#import "PXProfileArtifactMutation.h"
#import "PXProfileDeletionJournal.h"
#import "PXPaths.h"
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

static BOOL PXDefaultSeedError(NSError **error, NSString *message) {
    if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:29 userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}
static BOOL PXDefaultSeedPOSIXError(NSError **error) {
    if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
    return NO;
}
static BOOL PXDefaultSeedDirectoryMatches(int fd, NSString *path, NSError **error) {
    struct stat held, current;
    if (fstat(fd, &held) != 0 || lstat(path.fileSystemRepresentation, &current) != 0) return PXDefaultSeedPOSIXError(error);
    if (!S_ISDIR(held.st_mode) || !S_ISDIR(current.st_mode) || held.st_dev != current.st_dev || held.st_ino != current.st_ino)
        return PXDefaultSeedError(error, @"Default profile directory changed during seed preparation");
    return YES;
}

BOOL PXSeedDefaultProfile(PXProfileLifecycleLease *lease, NSError **error) {
    if (error) *error = nil;
    if (![lease isKindOfClass:PXProfileLifecycleLease.class]) return PXDefaultSeedError(error, @"Default profile seed requires lifecycle ownership");
    if (![lease validateForDirectory:PXProfilesPath() error:error] || !PXRequireNoPendingProfileDeletion(error)) return NO;
    NSDictionary *proof = [lease directoryProofForProfileID:@"0" error:error];
    if (!proof) return NO;
    int rootFD = -1, profileFD = -1, identityFD = -1;
    PXProfileArtifactMutation *scope = nil;
    @try {
        // The configured root may use a system alias; child directories may not.
        rootFD = open(PXProfilesPath().fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        if (rootFD < 0) return PXDefaultSeedPOSIXError(error);
        BOOL createdProfile = ![proof[@"exists"] boolValue];
        if (createdProfile && mkdirat(rootFD, "0", 0755) != 0) return PXDefaultSeedPOSIXError(error);
        profileFD = openat(rootFD, "0", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
        if (profileFD < 0) return PXDefaultSeedPOSIXError(error);
        if (createdProfile && fchmod(profileFD, 0755) != 0) return PXDefaultSeedPOSIXError(error);
        struct stat profile;
        if (fstat(profileFD, &profile) != 0) return PXDefaultSeedPOSIXError(error);
        if (!createdProfile && (profile.st_dev != [proof[@"device"] unsignedLongLongValue] ||
            profile.st_ino != [proof[@"inode"] unsignedLongLongValue]))
            return PXDefaultSeedError(error, @"Default profile was replaced before directory preparation");
        struct stat identity;
        if (fstatat(profileFD, "identity", &identity, AT_SYMLINK_NOFOLLOW) != 0) {
            if (errno != ENOENT || mkdirat(profileFD, "identity", 0755) != 0) return PXDefaultSeedPOSIXError(error);
        } else if (!S_ISDIR(identity.st_mode)) return PXDefaultSeedError(error, @"Default identity is not a plain directory");
        identityFD = openat(profileFD, "identity", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
        if (identityFD < 0 || fchmod(identityFD, 0755) != 0) return PXDefaultSeedPOSIXError(error);
        NSString *profilePath = PXProfileRootPath(@"0"), *identityPath = PXProfileIdentityPath(@"0");
        scope = [PXProfileArtifactMutation borrowWithLifecycleLease:lease identityResolver:^NSString *{ return identityPath; } error:error];
        if (!scope) return NO;
        NSDictionary *display = @{ @"DisplayName": @"Default", @"Description": @"Default Profile", @"Identifier": @"0" };
        NSString *displayPath = [profilePath stringByAppendingPathComponent:@"identifiers.plist"];
        NSString *idsPath = [identityPath stringByAppendingPathComponent:@"device_ids.plist"];
        BOOL committed = PXPerformStandaloneRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
            (void)tx;
            return [scope performSourceWrite:^BOOL(PXRuntimeSourceTransaction *staging, NSError **stageError) {
                if (!PXDefaultSeedDirectoryMatches(profileFD, profilePath, stageError) ||
                    !PXDefaultSeedDirectoryMatches(identityFD, identityPath, stageError)) return NO;
                BOOL exists = NO;
                NSDictionary *ids = [staging dictionaryAtPath:idsPath exists:&exists error:stageError];
                return ids && [staging setDictionary:display atPath:displayPath error:stageError] &&
                    (exists || [staging setDictionary:@{} atPath:idsPath error:stageError]);
            } error:writeError];
        }, error);
        if (committed) {
            // Retain legacy display-file mode repair as a post-commit effect;
            // failure here cannot negate the acknowledged source commit.
            [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions: @0644} ofItemAtPath:displayPath error:NULL];
        }
        return committed;
    } @finally {
        [scope invalidate];
        if (identityFD >= 0) close(identityFD);
        if (profileFD >= 0) close(profileFD);
        if (rootFD >= 0) close(rootFD);
    }
}
