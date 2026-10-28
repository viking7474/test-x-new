#import "PXProfileMetadataWriter.h"
#import "PXProfileArtifactMutation.h"
#import "PXPaths.h"
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>

static BOOL PXMetadataError(NSError **error, NSString *message) {
    if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:28 userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}
static BOOL PXMetadataPOSIXError(NSError **error) {
    if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
    return NO;
}
BOOL PXWriteProfileDisplayMetadata(PXProfileLifecycleLease *lease, NSString *profileID, NSDictionary *fields, NSError **error) {
    if (error) *error = nil;
    NSString *targetID = PXValidatedProfileID(profileID);
    if (!targetID || ![fields isKindOfClass:NSDictionary.class] ||
        ![fields[@"Name"] isKindOfClass:NSString.class] || ![fields[@"Description"] isKindOfClass:NSString.class] ||
        ![fields[@"CreatedAt"] isKindOfClass:NSDate.class] || ![fields[@"LastUsed"] isKindOfClass:NSDate.class])
        return PXMetadataError(error, @"Invalid profile display metadata");
    NSString *name = [fields[@"Name"] copy], *description = [fields[@"Description"] copy];
    NSDate *created = [fields[@"CreatedAt"] copy], *lastUsed = [fields[@"LastUsed"] copy];
    NSDictionary *info = @{ @"Name": name, @"ProfileId": targetID, @"Description": description, @"CreatedAt": created, @"LastUsed": lastUsed };
    NSDictionary *appInfo = @{ @"ProfileName": name, @"ProfileID": targetID, @"ShortDescription": description, @"Creation": created, @"LastUsed": lastUsed };
    NSDictionary *identifiers = @{ @"DisplayName": name, @"Description": description, @"Identifier": targetID };
    PXProfileArtifactMutation *scope = [PXProfileArtifactMutation borrowWithLifecycleLease:lease profileID:targetID error:error];
    int rootFD = -1, appDataFD = -1;
    @try {
        if (!scope) return NO;
        rootFD = open(scope.profileDirectory.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
        if (rootFD < 0) return PXMetadataPOSIXError(error);
        // Keep legacy appdata preflight, but do not follow an appdata symlink or
        // recursively recreate a missing profile. Parent scope pins its identity.
        BOOL createdAppData = mkdirat(rootFD, "appdata", 0755) == 0;
        if (!createdAppData && errno != EEXIST) return PXMetadataPOSIXError(error);
        appDataFD = openat(rootFD, "appdata", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
        if (appDataFD < 0) return PXMetadataPOSIXError(error);
        if (createdAppData && fchmod(appDataFD, 0755) != 0) return PXMetadataPOSIXError(error);
        NSString *appDataPath = [scope.profileDirectory stringByAppendingPathComponent:@"appdata"];
        NSString *scopedPath = [scope.profileDirectory stringByAppendingPathComponent:@"scoped-apps.plist"];
        // The inner artifact operation supplies directory/journal validation.
        // The outer standalone operation prevents early success in a caller's
        // uncommitted transaction. There is one actual source commit.
        return PXPerformStandaloneRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
            (void)tx;
            return [scope performSourceWrite:^BOOL(PXRuntimeSourceTransaction *staging, NSError **stageError) {
                struct stat held, current;
                if (fstat(appDataFD, &held) != 0 || lstat(appDataPath.fileSystemRepresentation, &current) != 0)
                    return PXMetadataPOSIXError(stageError);
                if (!S_ISDIR(current.st_mode) || held.st_dev != current.st_dev || held.st_ino != current.st_ino)
                    return PXMetadataError(stageError, @"Profile appdata directory changed during metadata preparation");
                NSDictionary *existing = [staging dictionaryAtPath:scopedPath error:stageError];
                if (!existing) return NO;
                NSMutableDictionary *scoped = [existing mutableCopy];
                scoped[@"ProfileName"] = name; scoped[@"ProfileDescription"] = description;
                scoped[@"Description"] = description; // Legacy description editor alias.
                if (!scoped[@"Apps"]) scoped[@"Apps"] = @[];
                return [staging setDictionary:info atPath:[scope.profileDirectory stringByAppendingPathComponent:@"Info.plist"] error:stageError] &&
                    [staging setDictionary:appInfo atPath:[appDataPath stringByAppendingPathComponent:@"Info.plist"] error:stageError] &&
                    [staging setDictionary:identifiers atPath:[scope.profileDirectory stringByAppendingPathComponent:@"identifiers.plist"] error:stageError] &&
                    [staging setDictionary:scoped atPath:scopedPath error:stageError];
            } error:writeError];
        }, error);
    } @finally {
        if (appDataFD >= 0) close(appDataFD);
        if (rootFD >= 0) close(rootFD);
        [scope invalidate];
    }
}
