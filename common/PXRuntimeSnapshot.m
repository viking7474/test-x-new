#import "PXRuntimeSnapshot.h"
#import "PXJailbreakCompat.h"
#import "PXPaths.h"
#import "PXRuntimeSourceStore.h"
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#import <sys/stat.h>
#import <errno.h>
#import <string.h>
#import <unistd.h>
#import <notify.h>

static NSDictionary *PXRuntimeCapturedSource(void);

static PXRuntimeSnapshotReader *PXProcessRuntimeReader(void) {
    static PXRuntimeSnapshotReader *reader;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        reader = [[PXRuntimeSnapshotReader alloc] initWithLoader:^NSDictionary *{
            return PXRuntimeCapturedSource();
        } refreshInterval:5.0];
    });
    return reader;
}

PXRuntimeReadSnapshot *PXCaptureRuntimeSnapshot(void) {
    int savedErrno = errno;
    BOOL scoped = NO;
    PXRuntimeReadSnapshot *snapshot = PXRuntimeReadScopeCurrent(&scoped);
    if (!scoped) snapshot = [PXProcessRuntimeReader() capture];
    errno = savedErrno;
    return snapshot;
}

void PXBeginRuntimeSnapshotOperation(PXRuntimeReadScope *scope) {
    int savedErrno = errno;
    PXRuntimeReadScopeBegin(scope, PXProcessRuntimeReader());
    errno = savedErrno;
}

void PXRuntimeSnapshotRegisterPreparation(void (^handler)(PXRuntimeReadSnapshot *)) {
    [PXProcessRuntimeReader() setBootstrapPreparationHandler:handler];
}

void PXInvalidateRuntimeSnapshotReader(void) { [PXProcessRuntimeReader() invalidateAndRefresh]; }

BOOL PXPrimeRuntimeSnapshotReader(void) {
    return [PXProcessRuntimeReader() primeSynchronouslyIfIdle];
}

static void PXRuntimeReaderNotification(CFNotificationCenterRef center, void *observer,
                                       CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    @autoreleasepool { [PXProcessRuntimeReader() invalidateAndRefresh]; }
}

BOOL PXPrepareRuntimeSnapshotReader(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
        if (center) {
            for (NSString *name in @[@"com.hydra.tlinkios.runtimeSnapshotChanged",
                                     @"com.hydra.tlinkios.profileChanged",
                                     @"com.hydra.tlinkios.settings.changed",
                                     @"com.hydra.tlinkios.scopedAppsChanged",
                                     @"com.hydra.tlinkios.safariStackSpoofToggleChanged"]) {
                CFNotificationCenterAddObserver(center, NULL, PXRuntimeReaderNotification,
                    (__bridge CFStringRef)name, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
            }
        }
    });
    return [PXProcessRuntimeReader() primeSynchronouslyIfIdle];
}

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
    PXRuntimeReadSnapshot *view = [[PXRuntimeReadSnapshot alloc] initWithPropertyList:snapshot readerGeneration:0];
    return view.valid ? view.propertyList : @{};
}

NSDictionary *PXLoadRuntimeSnapshot(void) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    NSString *localPath = PXRuntimeSnapshotLocalContainerPath();
    NSDictionary *local = localPath.length ? PXValidatedRuntimeSnapshotAtPath(localPath) : @{};
    if (local.count) return local;
#endif
    return PXValidatedRuntimeSnapshotAtPath(PXRuntimeSnapshotPath());
}

static NSDictionary *PXRuntimeCapturedSource(void) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    NSString *local = PXRuntimeSnapshotLocalContainerPath();
    if (local.length && [[NSFileManager defaultManager] fileExistsAtPath:local]) {
        // A corrupt existing local file is a failed publication, not permission
        // to revive enablement from a different/older global source.
        return PXRuntimeDictionaryAtPath(local);
    }
#endif
    // Validation/deep freezing belongs to the reader. The legacy loader above
    // keeps its old schema contract until the remaining consumers migrate.
    return PXRuntimeDictionaryAtPath(PXRuntimeSnapshotPath());
}

static NSDictionary *PXRuntimeSnapshotDictionary(NSString *key) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    NSDictionary *snapshot = PXCaptureRuntimeSnapshot().propertyList;
#else
    NSDictionary *snapshot = PXLoadRuntimeSnapshot();
#endif
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
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    return PXCaptureRuntimeSnapshot().profileID;
#else
    id value = PXLoadRuntimeSnapshot()[@"profileID"];
    return [value isKindOfClass:NSString.class] && [value length] ? value : nil;
#endif
}

NSDictionary *PXRuntimeSnapshotProfileSettings(void) {
    return PXRuntimeSnapshotDictionary(@"profileSettings");
}

NSDictionary *PXRuntimeSnapshotDeviceIDs(void) {
    return PXRuntimeSnapshotDictionary(@"deviceIDs");
}

NSDictionary *PXRuntimeSnapshotProfileArtifact(NSString *key) {
    if (![key isKindOfClass:NSString.class] || !key.length) return @{};
    NSDictionary *artifacts = PXRuntimeSnapshotDictionary(@"profileArtifacts");
    id value = artifacts[key];
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
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
    if (chmod(dir.fileSystemRepresentation, 0755) != 0 || chown(dir.fileSystemRepresentation, owner, group) != 0) {
        if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        return NO;
    }
    return PXRuntimeWritePropertyList(snapshot, path, owner, group, 0644, error);
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
        if (PXRuntimeReadBool(value[@"enabled"])) [enabledBundles addObject:key];
    }];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *containerRoot = @"/var/mobile/Containers/Data/Application";
    NSError *scanError = nil;
    NSArray<NSString *> *entries = [fm contentsOfDirectoryAtPath:containerRoot error:&scanError] ?: @[];
    NSMutableDictionary<NSString *, NSString *> *failures = [NSMutableDictionary dictionary];
    if (scanError) failures[@"containerScan"] = scanError.localizedDescription;
    NSMutableSet<NSString *> *matchedBundles = [NSMutableSet set];
    NSMutableSet<NSString *> *mirroredBundles = [NSMutableSet set];
    NSUInteger mirroredContainers = 0;
    NSUInteger removedStaleMirrors = 0;

    for (NSString *entry in entries) {
        NSString *container = [containerRoot stringByAppendingPathComponent:entry];
        NSString *metadataPath = [container stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        NSString *bundleID = [metadata[@"MCMMetadataIdentifier"] isKindOfClass:NSString.class]
            ? metadata[@"MCMMetadataIdentifier"] : nil;
        NSString *existingMirrorPath = [container stringByAppendingPathComponent:
            @"Library/Caches/com.hydra.tlinkios/runtime_snapshot.plist"];
        if (!bundleID.length) {
            if ([fm fileExistsAtPath:existingMirrorPath]) failures[entry] = @"Missing container owner metadata for existing mirror";
            continue;
        }
        if (![enabledBundles containsObject:bundleID]) {
            // Preserve removal policy for disabled targets. Global is already
            // committed; removal failure must remain an incomplete distribution.
            if ([fm fileExistsAtPath:existingMirrorPath]) {
                NSError *revocationError = nil;
                if ([fm removeItemAtPath:existingMirrorPath error:&revocationError]) removedStaleMirrors++;
                else failures[entry] = revocationError.localizedDescription ?: @"stale-mirror-removal-failed";
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
        NSError *parentError = nil;
        for (NSString *ownedDir in @[libraryDir, cachesDir, mirrorDir]) {
            if (![fm createDirectoryAtPath:ownedDir
          withIntermediateDirectories:YES
                           attributes:@{NSFilePosixPermissions: @0755}
                                error:&parentError]) break;
            if (chmod(ownedDir.fileSystemRepresentation, 0755) != 0 || chown(ownedDir.fileSystemRepresentation, 501, 501) != 0) {
                parentError = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil]; break;
            }
        }
        if (parentError) { failures[entry] = parentError.localizedDescription; continue; }
        NSString *mirrorPath = [mirrorDir stringByAppendingPathComponent:@"runtime_snapshot.plist"];
        NSError *mirrorError = nil;
        if (PXWriteRuntimeSnapshotAtomically(snapshot, mirrorPath, 501, 501, &mirrorError)) {
            mirroredContainers++;
            [mirroredBundles addObject:bundleID];
        } else {
            failures[entry] = mirrorError.localizedDescription ?: @"mirror-write-failed";
        }
    }

    NSMutableArray<NSString *> *missing = [enabledBundles.allObjects mutableCopy];
    [missing removeObjectsInArray:matchedBundles.allObjects];
    [missing sortUsingSelector:@selector(compare:)];
    NSArray<NSString *> *matched = [matchedBundles.allObjects sortedArrayUsingSelector:@selector(compare:)];
    NSArray<NSString *> *mirrored = [mirroredBundles.allObjects sortedArrayUsingSelector:@selector(compare:)];
    return @{
        @"enabledBundleCount": @(enabledBundles.count),
        @"matchedBundleCount": @(matchedBundles.count),
        @"mirroredContainerCount": @(mirroredContainers),
        @"matchedBundles": matched ?: @[],
        @"mirroredBundles": mirrored ?: @[],
        @"removedStaleMirrorCount": @(removedStaleMirrors),
        @"complete": @(failures.count == 0 && missing.count == 0),
        @"missingBundles": missing ?: @[],
        @"failures": failures ?: @{}
    };
}
#endif

static NSDictionary *PXCaptureRuntimeSnapshotCandidate(void) {
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

    NSString *identityRoot = PXProfileIdentityPath(profileID);
    NSMutableDictionary *profileArtifacts = [NSMutableDictionary dictionary];
    NSDictionary<NSString *, NSString *> *artifactPaths = @{
        @"storage": profileRoot.length ? [profileRoot stringByAppendingPathComponent:@"storage.plist"] : @"",
        @"batteryInfo": identityRoot.length ? [identityRoot stringByAppendingPathComponent:@"battery_info.plist"] : @"",
        @"networkSettings": identityRoot.length ? [identityRoot stringByAppendingPathComponent:@"network_settings.plist"] : @"",
        @"wifiInfo": identityRoot.length ? [identityRoot stringByAppendingPathComponent:@"wifi_info.plist"] : @"",
        @"carrierDetails": identityRoot.length ? [identityRoot stringByAppendingPathComponent:@"carrier_details.plist"] : @"",
        @"deviceTheme": identityRoot.length ? [identityRoot stringByAppendingPathComponent:@"device_theme.plist"] : @"",
        @"bootTime": identityRoot.length ? [identityRoot stringByAppendingPathComponent:@"boot_time.plist"] : @"",
        @"systemUptime": identityRoot.length ? [identityRoot stringByAppendingPathComponent:@"system_uptime.plist"] : @"",
        @"systemBootUUID": identityRoot.length ? [identityRoot stringByAppendingPathComponent:@"system_boot_uuid.plist"] : @"",
        @"dyldCacheUUID": identityRoot.length ? [identityRoot stringByAppendingPathComponent:@"dyld_cache_uuid.plist"] : @"",
        @"pasteboardUUID": identityRoot.length ? [identityRoot stringByAppendingPathComponent:@"pasteboard_uuid.plist"] : @"",
        @"userDefaultsUUID": identityRoot.length ? [identityRoot stringByAppendingPathComponent:@"userdefaults_uuid.plist"] : @""
    };
    [artifactPaths enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *path, BOOL *stop) {
        (void)stop;
        if (!path.length) return;
        NSDictionary *artifact = PXRuntimeDictionaryAtPath(path);
        if (artifact.count) profileArtifacts[key] = artifact;
    }];

    return @{
        @"timestamp": @([[NSDate date] timeIntervalSince1970]),
        @"profileID": profileID ?: @"",
        @"globalScope": globalScope ?: @{},
        @"securitySettings": securitySettings ?: @{},
        @"tlinkSettings": tlinkSettings ?: @{},
        @"profileSettings": profileSettings ?: @{},
        @"deviceIDs": deviceIDs ?: @{},
        @"profileArtifacts": profileArtifacts ?: @{}
    };

}

static NSDictionary *PXDistributeRuntimeSnapshot(NSDictionary *snapshot) {
    NSDictionary *tlinkSettings = snapshot[@"tlinkSettings"];
    NSDictionary *deviceIDs = snapshot[@"deviceIDs"];
    NSDictionary *profileArtifacts = snapshot[@"profileArtifacts"];
    NSDictionary *mirrorStats = @{ @"complete": @YES };
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    mirrorStats = PXMirrorRuntimeSnapshotIntoScopedContainers(snapshot, snapshot[@"globalScope"]);
#endif
    NSDictionary *enabledIdentifiers = [tlinkSettings[@"EnabledIdentifiers"] isKindOfClass:NSDictionary.class]
        ? tlinkSettings[@"EnabledIdentifiers"] : @{};
    NSMutableArray<NSString *> *enabledIdentifierKeys = [NSMutableArray array];
    [enabledIdentifiers enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        (void)stop;
        if ([key isKindOfClass:NSString.class] && [value respondsToSelector:@selector(boolValue)] && [value boolValue]) {
            [enabledIdentifierKeys addObject:key];
        }
    }];
    [enabledIdentifierKeys sortUsingSelector:@selector(compare:)];

    NSDictionary<NSString *, NSString *> *artifactForIdentifier = @{
        @"StorageSystem": @"storage",
        @"Battery": @"batteryInfo",
        @"BootTime": @"bootTime",
        @"SystemUptime": @"systemUptime",
        @"DeviceTheme": @"deviceTheme",
        @"UserDefaultsUUID": @"userDefaultsUUID",
        @"SystemBootUUID": @"systemBootUUID",
        @"DyldCacheUUID": @"dyldCacheUUID",
        @"PasteboardUUID": @"pasteboardUUID",
        @"WiFi": @"wifiInfo"
    };
    NSMutableDictionary<NSString *, NSString *> *missingEnabledArtifacts = [NSMutableDictionary dictionary];
    [artifactForIdentifier enumerateKeysAndObjectsUsingBlock:^(NSString *identifier, NSString *artifactKey, BOOL *stop) {
        (void)stop;
        id enabledValue = enabledIdentifiers[identifier];
        if ([enabledValue respondsToSelector:@selector(boolValue)] && [enabledValue boolValue] &&
            ![profileArtifacts[artifactKey] isKindOfClass:NSDictionary.class]) {
            missingEnabledArtifacts[identifier] = artifactKey;
        }
    }];

    return @{
            @"complete": mirrorStats[@"complete"] ?: @NO,
            @"globalSuccess": @YES,
            @"globalPath": PXRuntimeSnapshotPath() ?: @"",
            @"deviceIDCount": @(deviceIDs.count),
            @"tlinkSettingsKeys": [[tlinkSettings allKeys] sortedArrayUsingSelector:@selector(compare:)],
            @"enabledIdentifierMap": enabledIdentifiers ?: @{},
            @"enabledIdentifierKeys": enabledIdentifierKeys,
            @"profileArtifactKeys": [[profileArtifacts allKeys] sortedArrayUsingSelector:@selector(compare:)],
            @"missingEnabledArtifacts": missingEnabledArtifacts,
            @"mirror": mirrorStats ?: @{}
    };
}

PXRuntimePublisher *PXCreateRuntimeSnapshotPublisher(void (^completion)(NSDictionary *), NSError **error) {
    NSString *directory = [PXRuntimeSnapshotPath().stringByDeletingLastPathComponent stringByAppendingPathComponent:@"publisher"];
    return [[PXRuntimePublisher alloc] initWithDirectory:directory loader:^NSDictionary *(NSError **loadError) {
        return PXCaptureRuntimeSources(^NSDictionary *(NSError **captureError) {
            (void)captureError;
            NSMutableDictionary *candidate = [PXCaptureRuntimeSnapshotCandidate() mutableCopy];
            // Incremental enrollment: legacy profile/identifier/security writers
            // still bypass this gate. Source identity is not full coverage.
            candidate[@"sourceContractCoverage"] = @"settings-scope-manager-artifacts-identifier-telephony-partial";
            return candidate;
        }, loadError);
    } writer:^BOOL(NSDictionary *snapshot, NSError **writeError) {
        return PXWriteRuntimeSnapshotAtomically(snapshot, PXRuntimeSnapshotPath(), 0, 0, writeError);
    } distributor:^NSDictionary *(NSDictionary *snapshot) {
        return PXDistributeRuntimeSnapshot(snapshot);
    } notifier:^BOOL(NSError **notifyError) {
        uint32_t status = notify_post("com.hydra.tlinkios.runtimeSnapshotChanged");
        if (status != NOTIFY_STATUS_OK && notifyError) {
            *notifyError = [NSError errorWithDomain:@"com.hydra.tlinkios.notify" code:status userInfo:nil];
        }
        return status == NOTIFY_STATUS_OK;
    } completion:completion error:error];
}
