#import "PXRuntimeSnapshot.h"
#import "PXJailbreakCompat.h"
#import "PXPaths.h"
#import <sys/stat.h>
#import <errno.h>
#import <string.h>
#import <unistd.h>

static const NSInteger kPXRuntimeSnapshotSchemaVersion = 1;
static NSDictionary *gPXRuntimeSnapshotLastPublishStats = nil;

static NSDictionary *PXRuntimeDictionaryAtPath(NSString *path) {
    if (![path isKindOfClass:NSString.class] || !path.length) return @{};
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    return [dict isKindOfClass:NSDictionary.class] ? dict : @{};
}

NSString *PXRuntimeSnapshotPath(void) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    return PXJailbreakRootPath(@"/Library/WeaponX/Runtime/runtime_snapshot.plist");
#else
    // Non-RootHide builds keep the historical direct-rootfs readers. Returning
    // a package-owned path here makes the accessor harmless when no mirror exists.
    return @"/Library/WeaponX/Runtime/runtime_snapshot.plist";
#endif
}

NSString *PXRuntimeSnapshotLocalContainerPath(void) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    NSString *home = [NSHomeDirectory() stringByStandardizingPath];
    if (![home containsString:@"/Containers/Data/Application/"]) return nil;
    return [home stringByAppendingPathComponent:@"Library/Caches/com.hydra.tlinkios/runtime_snapshot.plist"];
#else
    return nil;
#endif
}

static NSDictionary *PXValidatedRuntimeSnapshotAtPath(NSString *path) {
    NSDictionary *snapshot = PXRuntimeDictionaryAtPath(path);
    NSNumber *schema = [snapshot[@"schemaVersion"] isKindOfClass:NSNumber.class]
        ? snapshot[@"schemaVersion"] : nil;
    return schema.integerValue == kPXRuntimeSnapshotSchemaVersion ? snapshot : @{};
}

NSDictionary *PXLoadRuntimeSnapshot(void) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    NSString *localPath = PXRuntimeSnapshotLocalContainerPath();
    NSDictionary *local = localPath.length ? PXValidatedRuntimeSnapshotAtPath(localPath) : @{};
    if (local.count) return local;
#endif
    return PXValidatedRuntimeSnapshotAtPath(PXRuntimeSnapshotPath());
}

NSDictionary *PXRuntimeSnapshotLastPublishStats(void) {
    @synchronized ([NSObject class]) {
        return [gPXRuntimeSnapshotLastPublishStats copy] ?: @{};
    }
}

static NSDictionary *PXRuntimeSnapshotDictionary(NSString *key) {
    NSDictionary *snapshot = PXLoadRuntimeSnapshot();
    id value = snapshot[key];
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

NSDictionary *PXRuntimeSnapshotGlobalScope(void) {
    return PXRuntimeSnapshotDictionary(@"globalScope");
}

NSDictionary *PXRuntimeSnapshotSecuritySettings(void) {
    return PXRuntimeSnapshotDictionary(@"securitySettings");
}

NSDictionary *PXRuntimeSnapshotTLinkSettings(void) {
    return PXRuntimeSnapshotDictionary(@"tlinkSettings");
}

NSString *PXRuntimeSnapshotProfileID(void) {
    id value = PXLoadRuntimeSnapshot()[@"profileID"];
    return [value isKindOfClass:NSString.class] && [value length] ? value : nil;
}

NSDictionary *PXRuntimeSnapshotProfileSettings(void) {
    return PXRuntimeSnapshotDictionary(@"profileSettings");
}

NSDictionary *PXRuntimeSnapshotDeviceIDs(void) {
    return PXRuntimeSnapshotDictionary(@"deviceIDs");
}

static BOOL PXWriteRuntimeSnapshotAtomically(NSDictionary *snapshot,
                                               NSString *path,
                                               uid_t owner,
                                               gid_t group,
                                               NSError **error) {
    if (![snapshot isKindOfClass:NSDictionary.class] || !path.length) return NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = path.stringByDeletingLastPathComponent;
    NSError *dirError = nil;
    if (![fm createDirectoryAtPath:dir
       withIntermediateDirectories:YES
                        attributes:@{NSFilePosixPermissions: @0755}
                             error:&dirError]) {
        if (error) *error = dirError;
        return NO;
    }
    chmod(dir.fileSystemRepresentation, 0755);
    chown(dir.fileSystemRepresentation, owner, group);

    NSString *tmp = [path stringByAppendingFormat:@".tmp.%d", getpid()];
    [fm removeItemAtPath:tmp error:nil];
    if (![snapshot writeToFile:tmp atomically:NO]) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.hydra.tlinkios.runtime-snapshot"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to serialize runtime snapshot"}];
        }
        return NO;
    }
    chmod(tmp.fileSystemRepresentation, 0644);
    chown(tmp.fileSystemRepresentation, owner, group);

    if (rename(tmp.fileSystemRepresentation, path.fileSystemRepresentation) != 0) {
        int errNo = errno;
        [fm removeItemAtPath:tmp error:nil];
        if (error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain
                                         code:errNo
                                     userInfo:@{NSLocalizedDescriptionKey:
                                         [NSString stringWithUTF8String:strerror(errNo)] ?: @"rename failed"}];
        }
        return NO;
    }
    chmod(path.fileSystemRepresentation, 0644);
    chown(path.fileSystemRepresentation, owner, group);
    return YES;
}

#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
static NSDictionary *PXMirrorRuntimeSnapshotIntoScopedContainers(NSDictionary *snapshot,
                                                                  NSDictionary *globalScope) {
    NSDictionary *scopedApps = [globalScope[@"ScopedApps"] isKindOfClass:NSDictionary.class]
        ? globalScope[@"ScopedApps"] : @{};
    NSMutableSet<NSString *> *enabledBundles = [NSMutableSet set];
    [scopedApps enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        (void)stop;
        if (![key isKindOfClass:NSString.class] || ![value isKindOfClass:NSDictionary.class]) return;
        if ([value[@"enabled"] boolValue]) [enabledBundles addObject:key];
    }];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *containerRoot = @"/var/mobile/Containers/Data/Application";
    NSArray<NSString *> *entries = [fm contentsOfDirectoryAtPath:containerRoot error:nil] ?: @[];
    NSMutableDictionary<NSString *, NSString *> *failures = [NSMutableDictionary dictionary];
    NSMutableSet<NSString *> *matchedBundles = [NSMutableSet set];
    NSUInteger mirroredContainers = 0;
    NSUInteger removedStaleMirrors = 0;

    for (NSString *entry in entries) {
        NSString *container = [containerRoot stringByAppendingPathComponent:entry];
        NSString *metadataPath = [container stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        NSString *bundleID = [metadata[@"MCMMetadataIdentifier"] isKindOfClass:NSString.class]
            ? metadata[@"MCMMetadataIdentifier"] : nil;
        if (!bundleID.length) continue;

        NSString *existingMirrorPath = [container stringByAppendingPathComponent:
            @"Library/Caches/com.hydra.tlinkios/runtime_snapshot.plist"];
        if (![enabledBundles containsObject:bundleID]) {
            if ([fm fileExistsAtPath:existingMirrorPath] && [fm removeItemAtPath:existingMirrorPath error:nil]) {
                removedStaleMirrors++;
            }
            continue;
        }
        [matchedBundles addObject:bundleID];

        // Reset Data may leave only the container root. Recreate the local
        // Library/Caches chain as mobile-owned so publishing as root never leaves
        // a root-owned parent that prevents the target app from using its cache.
        NSString *libraryDir = [container stringByAppendingPathComponent:@"Library"];
        NSString *cachesDir = [libraryDir stringByAppendingPathComponent:@"Caches"];
        NSString *mirrorDir = [cachesDir stringByAppendingPathComponent:@"com.hydra.tlinkios"];
        for (NSString *ownedDir in @[libraryDir, cachesDir, mirrorDir]) {
            [fm createDirectoryAtPath:ownedDir
          withIntermediateDirectories:YES
                           attributes:@{NSFilePosixPermissions: @0755}
                                error:nil];
            chmod(ownedDir.fileSystemRepresentation, 0755);
            chown(ownedDir.fileSystemRepresentation, 501, 501);
        }
        NSString *mirrorPath = [mirrorDir stringByAppendingPathComponent:@"runtime_snapshot.plist"];
        NSError *mirrorError = nil;
        if (PXWriteRuntimeSnapshotAtomically(snapshot, mirrorPath, 501, 501, &mirrorError)) {
            mirroredContainers++;
        } else {
            failures[bundleID] = mirrorError.localizedDescription ?: @"mirror-write-failed";
        }
    }

    NSMutableArray<NSString *> *missing = [enabledBundles.allObjects mutableCopy];
    [missing removeObjectsInArray:matchedBundles.allObjects];
    [missing sortUsingSelector:@selector(compare:)];
    return @{
        @"enabledBundleCount": @(enabledBundles.count),
        @"matchedBundleCount": @(matchedBundles.count),
        @"mirroredContainerCount": @(mirroredContainers),
        @"removedStaleMirrorCount": @(removedStaleMirrors),
        @"missingBundles": missing ?: @[],
        @"failures": failures ?: @{}
    };
}
#endif

BOOL PXPublishRuntimeSnapshot(NSError **error) {
    NSString *profileID = PXActiveProfileID();
    NSString *profileRoot = PXProfileRootPath(profileID);
    NSString *deviceIDsPath = PXProfileDeviceIDsPath(profileID);

    NSDictionary *globalScope = PXRuntimeDictionaryAtPath(PXGlobalScopePath());
    NSDictionary *securitySettings = PXRuntimeDictionaryAtPath(PXSecuritySettingsPath());
    NSDictionary *tlinkSettings = PXRuntimeDictionaryAtPath(PXTLinkIOSSettingsPath());
    NSDictionary *profileSettings = profileRoot.length
        ? PXRuntimeDictionaryAtPath([profileRoot stringByAppendingPathComponent:@"settings.plist"])
        : @{};
    NSDictionary *deviceIDs = deviceIDsPath.length
        ? PXRuntimeDictionaryAtPath(deviceIDsPath)
        : @{};

    NSDictionary *snapshot = @{
        @"schemaVersion": @(kPXRuntimeSnapshotSchemaVersion),
        @"timestamp": @([[NSDate date] timeIntervalSince1970]),
        @"profileID": profileID ?: @"",
        @"globalScope": globalScope ?: @{},
        @"securitySettings": securitySettings ?: @{},
        @"tlinkSettings": tlinkSettings ?: @{},
        @"profileSettings": profileSettings ?: @{},
        @"deviceIDs": deviceIDs ?: @{}
    };

    NSError *globalError = nil;
    BOOL globalSuccess = PXWriteRuntimeSnapshotAtomically(snapshot,
                                                           PXRuntimeSnapshotPath(),
                                                           0, 0,
                                                           &globalError);
    NSDictionary *mirrorStats = @{};
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    if (globalSuccess) {
        mirrorStats = PXMirrorRuntimeSnapshotIntoScopedContainers(snapshot, globalScope);
    }
#endif
    @synchronized ([NSObject class]) {
        gPXRuntimeSnapshotLastPublishStats = @{
            @"globalSuccess": @(globalSuccess),
            @"globalPath": PXRuntimeSnapshotPath() ?: @"",
            @"mirror": mirrorStats ?: @{}
        };
    }
    if (!globalSuccess && error) *error = globalError;
    return globalSuccess;
}
