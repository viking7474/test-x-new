#import "PXRuntimeSourceStore.h"
#import "PXPaths.h"
#import "PXRuntimeIdentifierWriter.h"
#import <dispatch/dispatch.h>

static PXRuntimeSourceStore *PXProcessSourceStore(NSError **error) {
    static NSObject *guard;
    static PXRuntimeSourceStore *store;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ guard = [NSObject new]; });
    @synchronized (guard) {
        if (!store) {
            // Store all canonical spellings up front. Resolving only /var's
            // system alias still rejects a per-profile/file symlink escape.
            NSSet<NSString *> *globalPaths = [NSSet setWithArray:@[
                PXCurrentProfileInfoPath(), PXLegacyActiveProfileInfoPath(), PXProfileDeletionJournalPath(),
                PXTLinkIOSSettingsPath(), PXGlobalScopePath(), PXSecuritySettingsPath(),
                PXProfileIndicatorPositionPath() ]];
            NSMutableDictionary<NSString *, NSString *> *canonicalGlobals = [NSMutableDictionary dictionary];
            for (NSString *path in globalPaths) {
                canonicalGlobals[path] = [path.stringByDeletingLastPathComponent.stringByResolvingSymlinksInPath
                    stringByAppendingPathComponent:path.lastPathComponent];
            }
            NSString *profiles = PXProfilesPath();
            NSString *canonicalProfiles = profiles.stringByResolvingSymlinksInPath;
            NSSet<NSString *> *artifacts = [[NSSet setWithArray:@[
                @"device_ids.plist", @"battery_info.plist", @"network_settings.plist", @"wifi_info.plist",
                @"carrier_details.plist", @"device_theme.plist", @"boot_time.plist", @"system_uptime.plist",
                @"system_boot_uuid.plist", @"dyld_cache_uuid.plist", @"pasteboard_uuid.plist", @"userdefaults_uuid.plist",
                @"tracking_info.plist" ]] setByAddingObjectsFromSet:PXRuntimeIdentifierSidecars()];
            BOOL (^allows)(NSString *) = ^BOOL(NSString *path) {
                NSString *expected = canonicalGlobals[path];
                if (expected) return [path.stringByResolvingSymlinksInPath isEqual:expected];
                NSString *prefix = [profiles stringByAppendingString:@"/"];
                if (![path hasPrefix:prefix]) return NO;
                NSArray<NSString *> *parts = [[path substringFromIndex:prefix.length] componentsSeparatedByString:@"/"];
                if (!parts.count || ![PXValidatedProfileID(parts[0]) isEqualToString:parts[0]]) return NO;
                BOOL valid = (parts.count == 2 && [@[@"settings.plist", @"storage.plist", @"battery_info.plist"] containsObject:parts[1]]) ||
                    (parts.count == 3 && [parts[1] isEqual:@"identity"] && [artifacts containsObject:parts[2]]);
                NSString *relative = [parts componentsJoinedByString:@"/"];
                return valid && [path.stringByResolvingSymlinksInPath isEqual:[canonicalProfiles stringByAppendingPathComponent:relative]];
            };
            store = [[PXRuntimeSourceStore alloc] initWithDirectory:[PXWeaponXBasePath() stringByAppendingPathComponent:@"RuntimeSource"]
                owner:501 group:501 allowsPath:allows error:error];
        }
        return store;
    }
}

BOOL PXPerformRuntimeSourceWrite(BOOL (^body)(PXRuntimeSourceTransaction *, NSError **), NSError **error) {
    return [PXProcessSourceStore(error) performWrite:body error:error];
}
BOOL PXPerformStandaloneRuntimeSourceWrite(BOOL (^body)(PXRuntimeSourceTransaction *, NSError **), NSError **error) {
    return [PXProcessSourceStore(error) performStandaloneWrite:body error:error];
}
NSDictionary *PXCaptureRuntimeSources(NSDictionary *(^loader)(NSError **), NSError **error) {
    return [PXProcessSourceStore(error) capture:loader error:error];
}
