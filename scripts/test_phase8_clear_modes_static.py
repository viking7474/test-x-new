#!/usr/bin/env python3
"""Static Phase-8 Clear Data Quick/Full/Deep contracts."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def text(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")

def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)

def strip_objc_comments(source: str) -> str:
    """Remove // and /* */ comments while preserving Objective-C/C string contents."""
    out = []
    i = 0
    quote = None
    while i < len(source):
        ch = source[i]
        nxt = source[i + 1] if i + 1 < len(source) else ""
        if quote is not None:
            out.append(ch)
            if ch == "\\" and i + 1 < len(source):
                i += 1
                out.append(source[i])
            elif ch == quote:
                quote = None
        elif ch in ('\"', "'"):
            quote = ch
            out.append(ch)
        elif ch == "/" and nxt == "/":
            i += 2
            while i < len(source) and source[i] not in "\r\n":
                i += 1
            if i < len(source):
                out.append(source[i])
        elif ch == "/" and nxt == "*":
            i += 2
            while i + 1 < len(source) and not (source[i] == "*" and source[i + 1] == "/"):
                if source[i] in "\r\n":
                    out.append(source[i])
                i += 1
            i += 1
        else:
            out.append(ch)
        i += 1
    return "".join(out)

request_h = text("PXClearRequest.h")
request_m = text("PXClearRequest.m")
cleaner_h = text("AppDataCleaner.h")
cleaner_m = text("AppDataCleaner.m")
resolver_h = text("PXDataContainerResolver.h")
resolver_m = text("PXDataContainerResolver.m")
tlink_ui = text("TLinkIOSViewController.m")
ios_version_hooks = text("TLinkIOSTweak/IOSVersionHooks.x")

for symbol in ("PXClearModeQuick", "PXClearModeFull", "PXClearModeDeep"):
    require(symbol in request_h, f"missing mode: {symbol}")
require("mode:(PXClearMode)mode" in request_h, "typed mode initializer missing")
for symbol in ("PXClearOptionNone", "PXClearOptionICloudData", "PXClearOptionSafariSharedWebData", "PXClearOptionMailSharedStore", "PXClearOptionsKnownMask"):
    require(symbol in request_h, f"missing Clear option contract: {symbol}")
require("options:(PXClearOptions)options" in request_h,
        "immutable Clear options initializer missing")
require("options:PXClearOptionNone" in request_m,
        "legacy/default Clear requests must leave optional destructive policies OFF")
require("deepClean ? PXClearModeDeep : PXClearModeFull" in request_m,
        "compatibility deepClean mapping changed")
require("return _mode == PXClearModeDeep" in request_m,
        "deepClean compatibility getter changed")
require("mode:(PXClearMode)mode" in cleaner_h,
        "mode-aware public clear API missing")

mode_start = cleaner_m.index("- (void)clearDataForBundleID:(NSString *)bundleID\n                        mode:(PXClearMode)mode\n                  completion:(void (^)(BOOL, NSError *))completion {")
mode_end = cleaner_m.index("#pragma mark - Improved Rootless-Compatible App Data Wiping", mode_start)
mode_body = cleaner_m[mode_start:mode_end]
require("sync();" not in mode_body, "canonical mode-aware clear must not call global sync")
require("VACUUM" not in mode_body, "canonical entry point must not invoke VACUUM")
require("allCookies" not in mode_body, "canonical entry point must not delete global cookies")
require("plannedPassCount == 2" not in cleaner_m, "second Keychain pass remains")
require("plannedPassCount:(systemApplication ? 1u : 2u)" not in cleaner_m,
        "two-pass Keychain plan remains")
require("plannedPassCount:1u" in cleaner_m, "single Keychain plan missing")
require("plan.plannedPassCount != 1 || passResults.count != 1" in cleaner_m,
        "single-pass accounting guard missing")
require("Step 1: Planning and running single Keychain pass" in mode_body,
        "single Keychain execution log missing")
require("PXStopSafariDaemonsBestEffort" not in mode_body,
        "canonical worker must not stop shared Safari/WebKit helpers before explicit shared-data authorization")

aggregate_start = cleaner_m.index("- (PXClearResult *)_completeDataWipeForMigratedRequest:")
aggregate_end = cleaner_m.index("#pragma mark - Main Public Methods", aggregate_start)
aggregate_body = cleaner_m[aggregate_start:aggregate_end]
require("!PXClearModeIncludesExtendedContainers(request.mode)" in aggregate_body,
        "Quick aggregate branch missing")
for detail in ("Quick mode excludes extension-data containers",
               "Quick mode excludes App Group containers",
               "Quick mode excludes PluginKit containers"):
    require(detail in aggregate_body, f"Quick skip accounting missing: {detail}")

require("strategy=%@ passed=%d" in mode_body, "verification metric missing")
require("@\"component_manifest\"" in mode_body, "manifest verification missing")
require("@\"deep_residual_scan\"" in mode_body, "Deep verification strategy missing")
for step in ("step=kill", "step=keychain", "step=data_aggregate", "step=verification", "total_ms"):
    require(step in mode_body, f"instrumentation missing: {step}")

require("invalidateCachedContainerForIdentifier" in resolver_h,
        "resolver cache invalidation API missing")
require("PXResolverCachedContainerIsValid" in resolver_m,
        "cache-hit revalidation missing")
require("MCMMetadataIdentifier" in resolver_m and "PXResolverImmediateDirectoryIsValid" in resolver_m,
        "cache validation does not bind metadata and physical directory")
require("removeObjectForKey:cacheKey" in resolver_m,
        "invalid cache hit is not evicted")
require("invalidateCachedContainerForIdentifier:bundleID" in mode_body,
        "request-end cache invalidation missing")

app_wipe_start = cleaner_m.index("- (PXClearComponentResult *)_completeAppDataWipeForApplicationDataRequest:")
app_wipe_end = cleaner_m.index('    NSLog(@"[AppDataCleaner] Completed wipe for %@", bundleID);', app_wipe_start)
app_wipe_body = cleaner_m[app_wipe_start:app_wipe_end]
require("request.mode == PXClearModeDeep" in app_wipe_body,
        "Deep-only specialized cleanup guards missing")
require("request.options & PXClearOptionICloudData" in app_wipe_body,
        "iCloud cleanup is not gated by the immutable request option")
require("Clear iCloud Data policy OFF; skipping iCloud/Accounts cleanup" in app_wipe_body,
        "option-OFF iCloud skip path missing")
require("options:request.options" in aggregate_body,
        "derived ApplicationData request does not preserve immutable Clear options")
require('PXReadSecurityBool(@"clearICloudDataEnabled", NO)' in mode_body and
        'PXReadSecurityBool(@"clearSafariSharedWebDataEnabled", NO)' in mode_body and
        'PXReadSecurityBool(@"clearMailSharedStoreEnabled", NO)' in mode_body and
        mode_body.count("options:clearOptions") >= 2,
        "canonical Clear does not snapshot persisted destructive policies into both requests")
require("PXClearOptionSafariSharedWebData" in mode_body and
        '@"clearSafariSharedWebData"' in mode_body,
        "Safari shared-web policy is not journaled as part of the immutable request snapshot")
require("PXClearOptionMailSharedStore" in mode_body and
        '@"clearMailSharedStore"' in mode_body,
        "Mail shared-store policy is not journaled as part of the immutable request snapshot")
require('@"wouldClearMailSharedStore"' in cleaner_m and
        'PXReadSecurityBool(@"clearMailSharedStoreEnabled", NO)' in cleaner_m,
        "dry-run does not expose the explicit Mail shared-store policy")

# Exact iCloud/Accounts authorization: no bundle-component/name fuzzy matching may
# cross the destructive boundary. Unsupported entitlement mappings fail closed.
accounts_start = cleaner_m.index("- (void)_clearExactAccountsOwnedByBundleIdentifier:(NSString *)bundleID {")
accounts_end = cleaner_m.index("- (void)_clearAuthorizedICloudDataForRequest:(PXClearRequest *)request {", accounts_start)
accounts_body = cleaner_m[accounts_start:accounts_end]
require("ZOWNINGBUNDLEID = ?" in accounts_body and "sqlite3_bind_text" in accounts_body,
        "Accounts3 authorization must bind an exact owning bundle id")
require('[bundleID hasPrefix:@"com.apple."]' in accounts_body and "BLOCKED for system app" in accounts_body,
        "Accounts3 exact path must keep system apps behind a separate blocked policy")
require("BEGIN IMMEDIATE" in accounts_body and "ROLLBACK" in accounts_body and "COMMIT" in accounts_body,
        "Accounts3 exact mutation is not transactional")
require("boundedSQLiteBusyTimeoutMs" in accounts_body and "remainingTime" in accounts_body,
        "Accounts3 SQLite lock waits are not bounded by the active Clear deadline")
require(accounts_body.count("isCancellationRequested") >= 4 and "cancelled before commit" in accounts_body,
        "Accounts3 transaction does not cooperatively cancel before/while mutating and before commit")
require("unrelatedBeforeSet" in accounts_body and "unrelatedAfterSet" in accounts_body and
        "isEqualToSet" in accounts_body,
        "Accounts3 mutation does not prove unrelated account PKs are unchanged")
for fuzzy in (" LIKE ", "%google%", "%gmail%", "NOT IN (SELECT Z_PK FROM ZACCOUNT)"):
    require(fuzzy not in accounts_body, f"fuzzy/global Accounts3 mutation remains: {fuzzy}")

icloud_start = cleaner_m.index("- (void)_clearAuthorizedICloudDataForRequest:(PXClearRequest *)request {")
icloud_end = cleaner_m.index("- (void)clearICloudData:(NSString *)bundleID", icloud_start)
icloud_body = cleaner_m[icloud_start:icloud_end]
require("com.apple.developer.ubiquity-container-identifiers" in icloud_body and
        "com.apple.developer.icloud-container-identifiers" in icloud_body,
        "iCloud authorization is not sourced from signed container entitlements")
require('[bundleID hasPrefix:@"com.apple."]' in icloud_body and "dedicated system-cloud policy required" in icloud_body,
        "iCloud exact path must fail closed for com.apple.* system targets")
require('hasPrefix:@"iCloud."' in icloud_body and
        'stringByReplacingOccurrencesOfString:@"." withString:@"~"' in icloud_body,
        "exact Mobile Documents container mapping missing")
require("stringByResolvingSymlinksInPath" in icloud_body and "stringByDeletingLastPathComponent" in icloud_body,
        "exact iCloud candidate does not enforce direct-child canonicalization")
for fuzzy in ("componentsSeparatedByString", "-iname", "CloudDocs", "Application Support/CloudKit", "LIKE"):
    require(fuzzy not in icloud_body, f"fuzzy iCloud authorization remains: {fuzzy}")
compat_icloud_start = cleaner_m.index("- (void)clearICloudData:(NSString *)bundleID")
compat_icloud_end = cleaner_m.index("- (void)fastWipeDirectoryContents:", compat_icloud_start)
compat_icloud_body = cleaner_m[compat_icloud_start:compat_icloud_end]
require("PXCurrentClearOperationContext" in compat_icloud_body and
        "no authorized request snapshot" in compat_icloud_body,
        "public clearICloudData compatibility selector does not fail closed without an immutable request")

safari_start = cleaner_m.index("- (void)_wipeMobileSafariSystemStoresForRequest:(PXClearRequest *)request {")
safari_end = cleaner_m.index("- (NSArray *)findExtensionDataContainersForBundleID", safari_start)
safari_body = cleaner_m[safari_start:safari_end]
require("shared Accounts3 mutation skipped (exact-ownership policy)" in safari_body,
        "MobileSafari must explicitly skip shared Accounts3 mutation")
for token in ("ZACCOUNT", "%google%", "%gmail%", 'PXKillallByName(@"accountsd"'):
    require(token not in safari_body, f"MobileSafari still mutates or targets shared Accounts3 state: {token}")

# Shared Safari/WebKit state is never implicit in Deep mode. It requires the
# immutable Safari-specific option in addition to exact MobileSafari + Deep gating.
require("PXClearOptionSafariSharedWebData" in app_wipe_body,
        "MobileSafari shared-store wipe lacks immutable option gate")
require('[bundleID isEqualToString:@"com.apple.mobilesafari"]' in app_wipe_body and
        "request.mode == PXClearModeDeep" in app_wipe_body and
        "Clear Safari Shared Web Data policy OFF; shared Safari/WebKit stores preserved" in app_wipe_body,
        "MobileSafari shared-store policy does not require Deep + exact target + explicit option")
require(app_wipe_body.count("[self _wipeMobileSafariSystemStoresForRequest:request]") == 1,
        "MobileSafari shared-store wipe must have exactly one gated call site")
require("request.mode != PXClearModeDeep" in safari_body and
        'request.bundleIdentifier isEqualToString:@"com.apple.mobilesafari"' in safari_body and
        "request.options & PXClearOptionSafariSharedWebData" in safari_body and
        "missing explicit immutable policy" in safari_body,
        "Safari shared-store helper does not independently enforce the immutable policy")
require('@"wouldClearSafariSharedWebData"' in cleaner_m and
        "PXClearOptionSafariSharedWebData" in cleaner_m,
        "dry-run does not expose Safari shared-store policy")
require("PXClearModeIncludesExtendedContainers(request.mode)" in app_wipe_body,
        "Quick residual-cleanup exclusion missing")

# Canonical Clear ownership boundary: global system refresh is quarantined.
require("[self refreshSystemServices]" not in app_wipe_body,
        "canonical ApplicationData wipe still invokes global refreshSystemServices")
refresh_start = cleaner_m.index("- (void)refreshSystemServices {")
refresh_end = cleaner_m.index("#pragma mark - Container Discovery Methods", refresh_start)
refresh_body = cleaner_m[refresh_start:refresh_end]
require("quarantined: no global mutations performed" in refresh_body,
        "refreshSystemServices compatibility selector is not explicitly quarantined")
for forbidden_global_mutation in (
    "drop_caches",
    'PXKillallByName(@"cfprefsd"',
    'PXKillallByName(@"nsurlsessiond"',
    "ApplicationState.db",
    "VACUUM",
    "sync;",
):
    require(forbidden_global_mutation not in refresh_body,
            f"quarantined refreshSystemServices still mutates global state: {forbidden_global_mutation}")

require("[self cleanSiriAnalyticsDatabase:bundleID]" not in app_wipe_body,
        "canonical Deep clear still mutates shared SiriAnalytics.db")
siri_start = cleaner_m.index("- (void)cleanSiriAnalyticsDatabase:(NSString *)bundleID {")
siri_end = cleaner_m.index("// NEW: Method to clean LaunchServices database", siri_start)
siri_body = cleaner_m[siri_start:siri_end]
require("cleanSiriAnalyticsDatabase quarantined" in siri_body,
        "Siri analytics compatibility selector is not explicitly quarantined")
for forbidden_siri_mutation in (
    "SiriAnalytics.db",
    "DELETE FROM",
    "LIKE",
    "VACUUM",
    "componentsSeparatedByString",
):
    require(forbidden_siri_mutation not in siri_body,
            f"quarantined Siri analytics selector still contains unsafe ownership/mutation logic: {forbidden_siri_mutation}")

# Exact-file deletion primitive refuses directories/symlinks and performs no shell/glob expansion.
exact_file_start = cleaner_m.index("static BOOL PXRemoveExactRegularNonSymlinkFile(NSString *path) {")
exact_file_end = cleaner_m.index("static NSString *PXExactInstalledApplicationBundlePathFromLaunchServices", exact_file_start)
exact_file_body = cleaner_m[exact_file_start:exact_file_end]
for token in ("lstat", "S_ISREG", "S_ISLNK", "unlink"):
    require(token in exact_file_body, f"exact-file primitive missing safety/execution token: {token}")
for token in ("rm -rf", "runCommandWithPrivileges", "removeItemAtPath", "findPathsMatchingPattern"):
    require(token not in exact_file_body, f"exact-file primitive unexpectedly expands into generic deletion: {token}")

# App-state cleanup keeps only exact bundle-derived files and uses the exact-file primitive.
app_state_start = cleaner_m.index("- (void)_internalClearAppStateData:(NSString *)bundleID {")
app_state_end = cleaner_m.index("// Helper to scan a directory and wipe files/folders matching a string", app_state_start)
app_state_body = cleaner_m[app_state_start:app_state_end]
require("ApplicationState/%@.plist" in app_state_body and
        "com.apple.UIKit.SplitView.%@.plist" in app_state_body and
        "PXStrictBundleIdentifierIsValid" in app_state_body and
        "PXRemoveExactRegularNonSymlinkFile" in app_state_body,
        "exact app-state file cleanup missing strict identity/exact deletion")
for fuzzy_state_token in ("FrontBoard", "LiveActivities", "RecentlyTerminatedAppState", "BackgroundTasks", "/TCC", "scanAndWipeInDirectory", "containsString", "securelyWipeFile"):
    require(fuzzy_state_token not in app_state_body,
            f"app-state cleanup still uses fuzzy/generic shared-directory deletion: {fuzzy_state_token}")
scan_start = cleaner_m.index("- (void)scanAndWipeInDirectory:(NSString *)directory matching:(NSString *)matchString {")
scan_end = cleaner_m.index("- (void)_wipeMobileMailSharedStoreForRequest:(PXClearRequest *)request {", scan_start)
scan_body = cleaner_m[scan_start:scan_end]
require("PXLogQuarantinedLegacyClearSelector(_cmd)" in scan_body,
        "fuzzy scanAndWipe helper is not quarantined")
for token in ("enumeratorAtURL", "containsString", "securelyWipeFile", "contentsOfDirectoryAtPath"):
    require(token not in scan_body,
            f"quarantined scanAndWipe helper still scans/mutates shared state: {token}")
require("Step 3: Clearing exact app state files" in mode_body,
        "canonical worker does not advertise exact-only app-state cleanup")

# Shared NSURLCredentialStorage ownership cannot be inferred from bundle-id components.
require("[strongSelf clearURLCredentialsForBundleID:bundleID]" not in mode_body,
        "canonical Full/Deep Clear still invokes fuzzy shared URL credential cleanup")
require("URL credential cleanup skipped (ownership boundary)" in mode_body,
        "canonical URL credential ownership-boundary skip log missing")
require('@"wouldClearURLCredentials": @NO' in cleaner_m,
        "dry-run still claims shared URL credential mutation")
urlcred_start = cleaner_m.index("- (void)clearURLCredentialsForBundleID:(NSString *)bundleID {")
urlcred_end = cleaner_m.index("- (void)cleanRootHideVarData:(NSString *)bundleID {", urlcred_start)
urlcred_body = cleaner_m[urlcred_start:urlcred_end]
require("PXLogQuarantinedLegacyClearSelector(_cmd)" in urlcred_body,
        "public URL credential selector is not quarantined")
for token in ("sharedCredentialStorage", "allCredentials", "componentsSeparatedByString", "containsString", "removeCredential"):
    require(token not in urlcred_body,
            f"quarantined URL credential selector still infers/mutates shared state: {token}")

# Remaining legacy helpers that mutate shared/global state stay source-compatible but fail closed.
root_hide_start = cleaner_m.index("- (void)cleanRootHideVarData:(NSString *)bundleID {")
root_hide_end = cleaner_m.index("- (void)clearPluginKitData:(NSString *)bundleID {", root_hide_start)
root_hide_body = cleaner_m[root_hide_start:root_hide_end]
require("PXLogQuarantinedLegacyClearSelector(_cmd)" in root_hide_body,
        "RootHide compatibility selector is not quarantined")
for token in ("findPathsMatchingPattern", "rm -rf", "WebKit/WebsiteData", "/Cookies/", "securelyWipeFile"):
    require(token not in root_hide_body,
            f"quarantined RootHide selector still scans/mutates shared state: {token}")

thumbnail_start = cleaner_m.index("- (void)clearThumbnailCaches:(NSString *)bundleID {")
thumbnail_end = cleaner_m.index("- (void)_clearExactAccountsOwnedByBundleIdentifier:", thumbnail_start)
thumbnail_body = cleaner_m[thumbnail_start:thumbnail_end]
require("PXLogQuarantinedLegacyClearSelector(_cmd)" in thumbnail_body,
        "thumbnail compatibility selector is not quarantined")
for token in ("thumbnailservices", "QuickLook.thumbnailcache", "findPathsMatchingPattern", "securelyWipeFile"):
    require(token not in thumbnail_body,
            f"quarantined thumbnail selector still scans/mutates shared state: {token}")

system_logs_start = cleaner_m.index("- (void)clearSystemLogs:(NSString *)bundleID {")
system_logs_end = cleaner_m.index("#pragma mark - Helper Methods", system_logs_start)
system_logs_body = cleaner_m[system_logs_start:system_logs_end]
system_logs_code = strip_objc_comments(system_logs_body)
require("PXLogQuarantinedLegacyClearSelector(_cmd)" in system_logs_code,
        "system-log compatibility selector is not quarantined")
for token in ("/var/log", "CrashReporter", "DiagnosticReports", "/ASL", "findPathsMatchingPattern", "securelyWipeFile"):
    require(token not in system_logs_code,
            f"quarantined system-log selector still scans/mutates shared state: {token}")

media_start = cleaner_m.index("- (void)clearMediaData:(NSString *)bundleID {")
media_end = cleaner_m.index("- (void)clearHealthData:(NSString *)bundleID {", media_start)
media_body = cleaner_m[media_start:media_end]
require("PXLogQuarantinedLegacyClearSelector(_cmd)" in media_body,
        "media compatibility selector is not quarantined")
for token in ("/var/mobile/Media", "SMS/Attachments", "enumeratorAtURL", "containsString", "securelyWipeFile"):
    require(token not in media_body,
            f"quarantined media selector still scans/mutates shared user data: {token}")

health_start = cleaner_m.index("- (void)clearHealthData:(NSString *)bundleID {")
health_end = cleaner_m.index("- (void)clearSafariData:(NSString *)bundleID {", health_start)
health_body = cleaner_m[health_start:health_end]
health_code = strip_objc_comments(health_body)
require("PXLogQuarantinedLegacyClearSelector(_cmd)" in health_code,
        "health compatibility selector is not quarantined")
for token in ("/Library/Health", "/HealthKit", "enumeratorAtURL", "containsString", "securelyWipeFile"):
    require(token not in health_code,
            f"quarantined health selector still scans/mutates shared protected data: {token}")

legacy_safari_start = cleaner_m.index("- (void)clearSafariData:(NSString *)bundleID {")
legacy_safari_end = cleaner_m.index("- (void)completelyWipeContainer:(NSString *)containerPath {", legacy_safari_start)
legacy_safari_body = cleaner_m[legacy_safari_start:legacy_safari_end]
require("PXLogQuarantinedLegacyClearSelector(_cmd)" in legacy_safari_body,
        "legacy Safari compatibility selector is not quarantined")
for token in ("/Library/Safari", "cleanDatabaseFile", "LIKE", "VACUUM", "enumeratorAtURL", "containsString"):
    require(token not in legacy_safari_body,
            f"quarantined legacy Safari selector still scans/mutates shared state: {token}")

clipboard_start = cleaner_m.index("- (void)clearClipboard {")
clipboard_end = cleaner_m.index("- (void)clearPasteboardData:(NSString *)bundleID", clipboard_start)
clipboard_body = cleaner_m[clipboard_start:clipboard_end]
require("PXLogQuarantinedLegacyClearSelector(_cmd)" in clipboard_body,
        "clipboard compatibility selector is not quarantined")
for token in ("UIPasteboard", "generalPasteboard", "setItems"):
    require(token not in clipboard_body,
            f"quarantined clipboard selector still mutates device-global pasteboard: {token}")

# Narrow-name legacy aliases must not transitively trigger a full application-data reset.
# Keep each selector locally fail-closed so a future change to another helper cannot revive it.
legacy_narrow_aliases = (
    "clearSharedContainers", "clearUserDefaults", "clearSQLiteDatabases", "clearPrivateVarData",
    "clearDeviceDatabase", "clearInstallationLogs", "clearNetworkConfigurations", "clearCarrierData",
    "clearNetworkData", "clearDNSCache", "clearCrashReports", "clearDiagnosticData",
    "clearBluetoothData", "clearPushNotificationData", "clearThumbnailCache", "clearWebCache",
    "clearGameData", "clearTemporaryFiles", "clearBinaryPlists", "clearEncryptedData",
    "clearJailbreakDetectionLogs", "clearSpotlightData", "clearSiriData", "clearSystemLoggerData",
    "clearASLLogs", "clearPasteboardData", "clearURLCache", "clearBackgroundAssets",
    "clearSharedStorage",
)
for selector in legacy_narrow_aliases:
    marker = f"- (void){selector}:(NSString *)bundleID {{"
    start = cleaner_m.index(marker)
    end = cleaner_m.find("\n- (void)", start + len(marker))
    require(end != -1, f"could not bound legacy alias implementation: {selector}")
    alias_code = strip_objc_comments(cleaner_m[start:end])
    require("PXLogQuarantinedLegacyClearSelector(_cmd)" in alias_code,
            f"legacy narrow alias is not locally quarantined: {selector}")
    for forbidden in ("completeAppDataWipe", "clearSystemLogs:", "clearClipboard", "clearThumbnailCaches:",
                      "clearAppWebKitData:", "_internalClearEncryptedData:", "cleanRootHideVarData:"):
        require(forbidden not in alias_code,
                f"legacy narrow alias still delegates/transitively mutates state: {selector} -> {forbidden}")

# Generic whole-data compatibility aliases remain explicit canonical data-wipe entry points.
for selector in ("performSecondaryCleanup", "clearAppData"):
    marker = f"- (void){selector}:(NSString *)bundleID {{"
    start = cleaner_m.index(marker)
    end = cleaner_m.find("\n- (void)", start + len(marker))
    require(end != -1 and "[self completeAppDataWipe:bundleID]" in cleaner_m[start:end],
            f"generic whole-data compatibility alias changed unexpectedly: {selector}")

# Canonical Clear must not scan/mutate ambiguous CrashReporter or Spotlight global state.
require("[self clearSpotlightIndexes:bundleID]" not in app_wipe_body,
        "canonical Clear still invokes ambiguous/global Spotlight cleanup")
require("[self removeCrashLogsForBundleID:bundleID]" not in app_wipe_body,
        "canonical Deep Clear still scans ambiguous CrashReporter state")
require("Spotlight cleanup skipped (ownership boundary)" in app_wipe_body and
        "CrashReporter cleanup skipped (ownership boundary)" in app_wipe_body,
        "canonical ownership-boundary skip logs missing for external system state")

crash_start = cleaner_m.index("- (void)removeCrashLogsForBundleID:(NSString *)bundleID {")
crash_end = cleaner_m.index("// NEW: Method to clear app store receipt data", crash_start)
crash_body = cleaner_m[crash_start:crash_end]
require("PXLogQuarantinedLegacyClearSelector(_cmd)" in crash_body,
        "CrashReporter compatibility selector is not quarantined")
for token in ("CrashReporter", "containsString", "contentsOfDirectoryAtPath", "fixPermissionsAndRemovePath"):
    require(token not in crash_body,
            f"quarantined CrashReporter selector still scans/mutates shared state: {token}")

spot_start = cleaner_m.index("- (void)clearSpotlightIndexes:(NSString *)bundleID {")
spot_end = cleaner_m.index("#pragma mark - UUID Finding Methods", spot_start)
spot_body = cleaner_m[spot_start:spot_end]
require("PXLogQuarantinedLegacyClearSelector(_cmd)" in spot_body,
        "Spotlight compatibility selector is not quarantined")
for token in ("CSSearchableIndex", "deleteSearchableItemsWithDomainIdentifiers", "com.apple.Spotlight", "findPathsMatchingPattern", "securelyWipeFile"):
    require(token not in spot_body,
            f"quarantined Spotlight selector still mutates global/ambiguous state: {token}")

# Legacy public global-state helpers remain source-compatible but are no-op quarantines.
icon_start = cleaner_m.index("- (void)cleanIconStatePlist:(NSString *)bundleID {")
icon_end = cleaner_m.index("// NEW: Method to clean SiriAnalytics database", icon_start)
icon_body = cleaner_m[icon_start:icon_end]
require("cleanIconStatePlist quarantined" in icon_body,
        "IconState compatibility selector is not quarantined")
for token in ("IconState.plist", "DefaultIconState.plist", "grep -v", "plutil", "runCommandWithPrivileges"):
    require(token not in icon_body, f"quarantined IconState selector still mutates global state: {token}")

ls_start = cleaner_m.index("- (void)cleanLaunchServicesDatabase:(NSString *)bundleID {")
ls_end = cleaner_m.index("// NEW: Method to refresh system services to apply changes", ls_start)
ls_body = cleaner_m[ls_start:ls_end]
require("cleanLaunchServicesDatabase quarantined" in ls_body,
        "LaunchServices compatibility selector is not quarantined")
for token in ("SBAppTagsFileManager", "SBIconModelCache.plist", "LaunchServices-*", "rm -rf", "findPathsMatchingPattern"):
    require(token not in ls_body, f"quarantined LaunchServices selector still mutates global state: {token}")

# Deep Mail shared-store policy + Accounts3 release safety block.
mail_start = app_wipe_body.index('if (request.mode == PXClearModeDeep && [bundleID isEqualToString:@"com.apple.mobilemail"])')
mail_end = app_wipe_body.index("    // Clear preferences and cookies only", mail_start)
mail_body = app_wipe_body[mail_start:mail_end]
require("request.options & PXClearOptionMailSharedStore" in mail_body and
        "Clear Mail Shared Store policy OFF; shared /var/mobile/Library/Mail preserved" in mail_body and
        "[self _wipeMobileMailSharedStoreForRequest:request]" in mail_body,
        "MobileMail shared store is not gated by Deep + exact target + explicit immutable option")
for implicit_mail_mutation in (
    "PXStopMailDaemonsBestEffort",
    'PXKillallByName(@"Mail"',
    "mailShell",
    "com.apple.mail.plist",
    "Mail.WeaponXTrash",
):
    require(implicit_mail_mutation not in mail_body,
            f"MobileMail canonical gate still performs shared mutation before authorization: {implicit_mail_mutation}")
require("Accounts3 destructive cleanup BLOCKED" in mail_body,
        "Deep Mail Accounts3 destructive cleanup release block missing")
require("PXSQLiteLogMailAccountsDiagnostic" in mail_body,
        "Deep Mail blocked path must emit read-only Accounts3 diagnostics for safe unblocking")
require('PXKillallByName(@"accountsd"' not in mail_body and 'PXKillallTermThenKill(@"accountsd"' not in mail_body,
        "Deep Mail blocked path must not disturb accountsd when Accounts3 is not mutated")
for destructive_token in (
    'sqlite3_open_v2(accountsDB.UTF8String, &db, SQLITE_OPEN_READWRITE, NULL)',
    'DELETE FROM ZACCOUNT WHERE ZACCOUNTTYPE IN',
    'DELETE FROM ZACCOUNTPROPERTY WHERE ZOWNER IN',
    'DELETE FROM ZCREDENTIALITEM WHERE ZOWNER IN',
):
    require(destructive_token not in mail_body,
            f"Deep Mail release path still contains blocked Accounts3 mutation: {destructive_token}")

mail_helper_start = cleaner_m.index("- (void)_wipeMobileMailSharedStoreForRequest:(PXClearRequest *)request {")
mail_helper_end = cleaner_m.index("// Override the existing clearAppStateData method", mail_helper_start)
mail_helper_body = cleaner_m[mail_helper_start:mail_helper_end]
require("request.mode != PXClearModeDeep" in mail_helper_body and
        'request.bundleIdentifier isEqualToString:@"com.apple.mobilemail"' in mail_helper_body and
        "request.options & PXClearOptionMailSharedStore" in mail_helper_body and
        "missing explicit immutable policy" in mail_helper_body,
        "MobileMail shared-store helper does not independently enforce immutable authorization")
require("PXStopMailDaemonsBestEffort" in mail_helper_body and
        "/var/mobile/Library/Mail" in mail_helper_body and
        "com.apple.mail.plist" in mail_helper_body and
        "Mail.WeaponXTrash" in mail_helper_body,
        "authorized MobileMail shared-store helper lost its intended destructive work")
require(mail_helper_body.count("isCancellationRequested") >= 3,
        "MobileMail shared-store helper lacks cancellation checkpoints")
for forbidden_account_mutation in ("Accounts3", "ZACCOUNT", 'PXKillallByName(@"accountsd"'):
    require(forbidden_account_mutation not in mail_helper_body,
            f"Mail shared-store option must not authorize Accounts3/accountsd mutation: {forbidden_account_mutation}")

# Encrypted preferences outside the app container use direct-directory enumeration plus
# exact bundle-id filename prefixes; no wildcard/find or generic delete helper participates.
encrypted_start = cleaner_m.index("- (void)_internalClearEncryptedDataOutsideMainApplicationContainer:(NSString *)bundleID\n                                                         deepClean:(BOOL)deepClean {")
encrypted_end = cleaner_m.index("- (void)_internalClearEncryptedData:(NSString *)bundleID", encrypted_start)
encrypted_body = cleaner_m[encrypted_start:encrypted_end]
require("PXStrictBundleIdentifierIsValid" in encrypted_body and
        "PXReadOnlyRealDirectoryAtPath" in encrypted_body and
        "contentsOfDirectoryAtPath" in encrypted_body and
        "stringByStandardizingPath" in encrypted_body and
        "stringByDeletingLastPathComponent" in encrypted_body and
        "PXRemoveExactRegularNonSymlinkFile" in encrypted_body,
        "encrypted preference cleanup lost exact-path authorization/deletion flow")
for base in ("/var/mobile/Library/Preferences", "/private/var/mobile/Library/Preferences",
             "/var/jb/var/mobile/Library/Preferences", "/private/var/jb/var/mobile/Library/Preferences"):
    require(base in encrypted_body, f"encrypted preference exact base missing: {base}")
for suffix in ('stringByAppendingString:@".enc"', 'stringByAppendingString:@".encrypted"', 'stringByAppendingString:@".secure"'):
    require(suffix in encrypted_body, f"encrypted preference exact filename prefix missing: {suffix}")
require("hasPrefix:prefix" in encrypted_body,
        "encrypted preference filename authorization is not prefix-bound to the exact bundle id")
for forbidden in ("findPathsMatchingPattern", "securelyWipeFile", "%@*.enc*", "%@.enc*", "rm -rf"):
    require(forbidden not in encrypted_body,
            f"encrypted preference cleanup still uses wildcard/generic deletion: {forbidden}")

diag_start = cleaner_m.index("static void PXSQLiteLogMailAccountsDiagnostic")
diag_end = cleaner_m.index("- (NSString *)_sqliteScalarAtPath", diag_start)
diag_body = cleaner_m[diag_start:diag_end]
require("SQLITE_OPEN_READONLY" in diag_body and "SQLITE_OPEN_READWRITE" not in diag_body,
        "Deep Mail Accounts3 diagnostic must remain read-only")
for mutation in ("DELETE FROM ", "UPDATE ", "INSERT INTO ", "REPLACE INTO "):
    require(mutation not in diag_body,
            f"Deep Mail Accounts3 diagnostic unexpectedly contains mutation SQL: {mutation}")

# MobileMail is a clear-only system target: selecting it for reset must not inject
# the full spoof stack into Mail when AppDataCleaner kills/relaunches the process.
require('if ([bundleID isEqualToString:@"com.apple.mobilemail"]) return NO;' in tlink_ui,
        "MobileMail reset target is not excluded from spoof/injection scope")
sync_start = tlink_ui.index("- (void)syncHookScopeToResetApps")
sync_end = tlink_ui.index("- (void)selectFakeTapped", sync_start)
sync_body = tlink_ui[sync_start:sync_end]
require("PXResetBundlesForSpoofScope" in sync_body,
        "reset-scope synchronization bypasses the clear-only system-app filter")
reset_start = tlink_ui.index("- (void)performResetAndPrepareNextProfileWithWarnings:")
reset_end = tlink_ui.index("- (void)backupApps:", reset_start)
reset_body = tlink_ui[reset_start:reset_end]
require("[self syncHookScopeToResetApps]" in reset_body,
        "reset must reconcile injection scope before destructive clear/relaunch")
require("[self clearApps:self.selectedResetAppIDs" in reset_body,
        "MobileMail must remain in reset selection for AppDataCleaner even when excluded from spoof scope")
setup_start = tlink_ui.index("- (void)setupDashboardUI")
setup_end = tlink_ui.index("- (UIView *)dashboardGroupCard", setup_start)
setup_body = tlink_ui[setup_start:setup_end]
require("[self syncHookScopeToResetApps]" in setup_body,
        "dashboard startup must repair stale persisted MobileMail injection scope from older builds")

# Dormant generic database/system-reference helpers remain source-compatible but fail closed.
legacy_db_start = cleaner_m.index("- (void)cleanDatabaseFile:(NSString *)dbPath bundleID:")
legacy_db_end = cleaner_m.index("// Helper method to check if directory exists", legacy_db_start)
legacy_db_body = strip_objc_comments(cleaner_m[legacy_db_start:legacy_db_end])
require("PXLogQuarantinedLegacyClearSelector(_cmd)" in legacy_db_body,
        "generic cleanDatabaseFile helper is not quarantined")
for token in ("DELETE FROM", " LIKE ", "VACUUM", "runCommandWithPrivileges", "rm -f", "sqlite3"):
    require(token not in legacy_db_body,
            f"quarantined generic database helper still mutates shared SQL/files: {token}")

system_ref_start = cleaner_m.index("- (BOOL)hasSystemDatabaseReferencesForBundleID:(NSString *)bundleID {")
system_ref_end = cleaner_m.index("// NEW: Method to check if there are keychain items for a bundle ID", system_ref_start)
system_ref_body = strip_objc_comments(cleaner_m[system_ref_start:system_ref_end])
require("PXLogQuarantinedLegacyClearSelector(_cmd)" in system_ref_body and "return NO;" in system_ref_body,
        "fuzzy system-database reference probe is not fail-closed")
for token in ("componentsSeparatedByString", "runCommandAndGetOutput", "grep", "sqlite3", "containsString"):
    require(token not in system_ref_body,
            f"quarantined system-reference probe still performs fuzzy inspection: {token}")

# Standalone verification must use the same exact read-only authorities as canonical verification.
verify_start = cleaner_m.index("- (BOOL)verifyDataCleared:(NSString *)bundleID {")
verify_end = cleaner_m.index("- (void)verifyClearedPath:", verify_start)
verify_body = cleaner_m[verify_start:verify_end]
require("PXExactReadOnlyApplicationDataPathsForBundleID" in verify_body and
        "_exactApplicationGroupIdentifiersForBundleIdentifier" in verify_body and
        "resolveAllAppGroupContainersForGroupIdentifier" in verify_body and
        "_exactInstalledExtensionIdentifiersForApplicationIdentifier" in verify_body and
        "resolveDataContainerForIdentifier" in verify_body,
        "standalone verification lost exact application/group/extension resolution")
for token in ("findDataContainerUUID:bundleID", "findRootlessDataContainerUUID:bundleID",
              "findGroupContainerUUIDsForBundleID", "findExtensionDataContainersForBundleID",
              "optimized_findExtensionContainers"):
    require(token not in verify_body,
            f"standalone verification still uses legacy/fuzzy fallback: {token}")
require("Exact App Group entitlement discovery failed" in verify_body and
        "Exact installed-extension discovery failed" in verify_body,
        "standalone exact discovery failures do not fail verification conservatively")

# Read-only UI attribution must use exact ownership sources and never cause global side effects.
read_exact_start = cleaner_m.index("static NSArray<NSString *> *PXExactReadOnlyApplicationDataPathsForBundleID")
read_exact_end = cleaner_m.index("static ", read_exact_start + len("static NSArray<NSString *> *PXExactReadOnlyApplicationDataPathsForBundleID"))
read_exact_body = cleaner_m[read_exact_start:read_exact_end]
require("PXStrictBundleIdentifierIsValid" in read_exact_body and
        "resolveApplicationDataContainerForIdentifier" in read_exact_body and
        "PXResolvedContainerRootRootful" in read_exact_body and
        "PXResolvedContainerRootRootless" in read_exact_body and
        "PXReadOnlyRealDirectoryAtPath" in read_exact_body,
        "read-only application-data attribution is not exact-resolver based")

has_data_start = cleaner_m.index("- (BOOL)hasDataToClear:(NSString *)bundleID {")
has_data_end = cleaner_m.index("// --- Optimized lookup helpers", has_data_start)
has_data_body = cleaner_m[has_data_start:has_data_end]
require("PXExactReadOnlyApplicationDataPathsForBundleID" in has_data_body and
        has_data_body.count("_resolvedAppGroupUUIDsFromEntitlements") >= 2 and
        "PXReadOnlyRegularNonSymlinkFileAtPath" in has_data_body and
        "hasKeychainItemsForBundleID" in has_data_body,
        "hasDataToClear lost exact container/group/preference/keychain attribution")
for forbidden in ("runCommandWithPrivileges", '"sync"', "findDataContainerUUID:",
                  "findRootlessDataContainerUUID:", "findAppGroupUUIDs:",
                  "findRootlessAppGroupUUIDs:", "hasSystemDatabaseReferencesForBundleID"):
    require(forbidden not in has_data_body,
            f"hasDataToClear still performs global/fuzzy attribution: {forbidden}")

usage_start = cleaner_m.index("- (NSDictionary *)getDataUsage:(NSString *)bundleID {")
usage_end = cleaner_m.index("// Helper method for getDataUsage", usage_start)
usage_body = cleaner_m[usage_start:usage_end]
require("PXExactReadOnlyApplicationDataPathsForBundleID" in usage_body and
        "PXExactInstalledApplicationBundlePathFromLaunchServices" in usage_body and
        usage_body.count("_resolvedAppGroupUUIDsFromEntitlements") >= 2,
        "getDataUsage is not based on exact app/container/group ownership")
for forbidden in ("findDataContainerUUID:", "findRootlessDataContainerUUID:",
                  "findAppGroupUUIDs:", "findRootlessAppGroupUUIDs:", "findBundleUUID:"):
    require(forbidden not in usage_body,
            f"getDataUsage still uses aggressive/fuzzy ownership discovery: {forbidden}")

# Compatibility UUID resolvers used by metrics/entitlements must not re-enter legacy fuzzy scanners.
compat_data_start = cleaner_m.index("- (NSString *)findDataContainerUUIDForBundleID:(NSString *)bundleID {")
compat_data_end = cleaner_m.index("- (NSString *)findBundleContainerUUIDForBundleID:", compat_data_start)
compat_data_body = cleaner_m[compat_data_start:compat_data_end]
require("PXExactReadOnlyApplicationDataPathsForBundleID" in compat_data_body and
        "findDataContainerUUID:bundleID" not in compat_data_body,
        "data-container compatibility resolver still delegates to aggressive discovery")
compat_bundle_start = compat_data_end
compat_bundle_end = cleaner_m.index("- (NSArray *)findGroupContainerUUIDsForBundleID:", compat_bundle_start)
compat_bundle_body = cleaner_m[compat_bundle_start:compat_bundle_end]
require("PXExactInstalledApplicationBundlePathWithFilesystemFallback" in compat_bundle_body and
        "stringByDeletingLastPathComponent" in compat_bundle_body and
        "findBundleContainerUUID:bundleID" not in compat_bundle_body,
        "bundle-container compatibility resolver still delegates to fuzzy filesystem discovery")

bundle_fallback_start = cleaner_m.index("static NSString *PXExactInstalledApplicationBundlePathWithFilesystemFallback")
bundle_fallback_end = cleaner_m.index("static NSArray<NSString *> *PXExactReadOnlyApplicationDataPathsForBundleID", bundle_fallback_start)
bundle_fallback_body = cleaner_m[bundle_fallback_start:bundle_fallback_end]
require("PXExactInstalledApplicationBundlePathFromLaunchServices" in bundle_fallback_body and
        "PXStrictBundleIdentifierIsValid" in bundle_fallback_body and
        "PXReadOnlyRealDirectoryAtPath" in bundle_fallback_body and
        "PXReadOnlyRegularNonSymlinkFileAtPath" in bundle_fallback_body and
        'info[@"CFBundleIdentifier"]' in bundle_fallback_body and
        "[exactIdentifier isEqualToString:bundleIdentifier]" in bundle_fallback_body and
        "matches.count == 1" in bundle_fallback_body,
        "exact bundle filesystem fallback lost identity/path/ambiguity guards")
for token in ("hasPrefix:bundleIdentifier", "containsString:bundleIdentifier", "componentsSeparatedByString"):
    require(token not in bundle_fallback_body,
            f"exact bundle filesystem fallback introduced fuzzy identity logic: {token}")

# Legacy read-only container compatibility finders must no longer perform fuzzy filesystem attribution.
legacy_data_start = cleaner_m.index("- (NSString *)findDataContainerUUID:(NSString *)bundleID aggressive:(BOOL)aggressive {")
legacy_data_end = cleaner_m.index("- (NSString *)findRootlessDataContainerUUID:(NSString *)bundleID aggressive:(BOOL)aggressive {", legacy_data_start)
legacy_data_body = cleaner_m[legacy_data_start:legacy_data_end]
require("PXStrictBundleIdentifierIsValid" in legacy_data_body and
        "resolveApplicationDataContainerForIdentifier" in legacy_data_body and
        "PXResolvedContainerRootRootful" in legacy_data_body and
        "aggressive:NO" in legacy_data_body,
        "legacy rootful data finder is not an exact resolver compatibility wrapper")
for token in ("containsString", "listDirectoriesInPath", "MCMMetadataIdentifier", "company", "shortName"):
    require(token not in legacy_data_body,
            f"legacy rootful data finder still performs fuzzy attribution: {token}")

legacy_rootless_start = legacy_data_end
legacy_rootless_end = cleaner_m.index("- (NSArray *)findAppGroupUUIDs:(NSString *)bundleID aggressive:(BOOL)aggressive {", legacy_rootless_start)
legacy_rootless_body = cleaner_m[legacy_rootless_start:legacy_rootless_end]
require("resolveApplicationDataContainerForIdentifier" in legacy_rootless_body and
        "PXResolvedContainerRootRootless" in legacy_rootless_body and
        "aggressive:NO" in legacy_rootless_body,
        "legacy rootless data finder is not an exact resolver compatibility wrapper")
for token in ("containsString", "listDirectoriesInPath", "MCMMetadataIdentifier", "company", "shortName"):
    require(token not in legacy_rootless_body,
            f"legacy rootless data finder still performs fuzzy attribution: {token}")

legacy_group_start = legacy_rootless_end
legacy_group_end = cleaner_m.index("- (NSArray *)findRootlessAppGroupUUIDs:(NSString *)bundleID {", legacy_group_start)
legacy_group_body = cleaner_m[legacy_group_start:legacy_group_end]
require("_resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:NO" in legacy_group_body and
        "PXStrictBundleIdentifierIsValid" in legacy_group_body and
        "aggressive:NO" in legacy_group_body,
        "legacy App Group finder is not entitlement/exact-resolver based")
for token in ("containsString", "listDirectoriesInPath", "MCMMetadataIdentifier", "company", "shortName"):
    require(token not in legacy_group_body,
            f"legacy App Group finder still performs fuzzy attribution: {token}")

legacy_bundle_start = cleaner_m.index("- (NSString *)findBundleContainerUUID:(NSString *)bundleID {")
legacy_bundle_end = cleaner_m.index("- (void)clearMediaData:(NSString *)bundleID {", legacy_bundle_start)
legacy_bundle_body = cleaner_m[legacy_bundle_start:legacy_bundle_end]
require("findBundleContainerUUIDForBundleID:bundleID" in legacy_bundle_body,
        "legacy bundle UUID finder does not delegate to the exact public compatibility resolver")
for token in ("contentsOfDirectoryAtPath", "MCMMetadataIdentifier", "containsString", "PXExactInstalledApplicationBundlePathFromLaunchServices"):
    require(token not in legacy_bundle_body,
            f"legacy bundle UUID finder still owns/scans filesystem state instead of delegating exactly: {token}")

optimized_start = cleaner_m.index("- (NSString *)optimized_findDataContainerUUID:")
optimized_end = cleaner_m.index("// Helper method to create human-readable file sizes", optimized_start)
optimized_body = cleaner_m[optimized_start:optimized_end]
require(optimized_body.count("PXLogQuarantinedLegacyClearSelector(_cmd)") == 5,
        "orphan optimized fuzzy finder family is not fully quarantined")
for token in ("containsString", "dispatch_apply", "MCMMetadataIdentifier", "listDirectoriesInPath"):
    require(token not in optimized_body,
            f"quarantined optimized finder family still scans/fuzzily attributes state: {token}")

public_ext_start = cleaner_m.index("- (NSArray *)findExtensionDataContainersForBundleID:(NSString *)bundleID {")
public_ext_end = cleaner_m.index("- (void)cleanAppGroupContainers:(NSString *)bundleID {", public_ext_start)
public_ext_body = cleaner_m[public_ext_start:public_ext_end]
require("_exactInstalledExtensionIdentifiersForApplicationIdentifier" in public_ext_body and
        "resolveDataContainerForIdentifier" in public_ext_body and
        "PXResolvedContainerKindExtensionData" in public_ext_body and
        "PXResolvedContainerRootRootful" in public_ext_body and
        "PXReadOnlyRealDirectoryAtPath" in public_ext_body,
        "public extension-data finder is not backed by exact installed-extension/container resolution")
for token in ("baseIdentifier", "containsString", "hasPrefix:baseIdentifier", 'containsString:@".extension."',
              'containsString:@".appex."', 'containsString:@".plugin."'):
    require(token not in public_ext_body,
            f"public extension-data finder still uses naming/prefix heuristics: {token}")

# Dormant fuzzy verification/extension helper family stays fail-closed and cannot be revived transitively.
legacy_verify_keychain_start = cleaner_m.index("- (void)verifyKeychainClearedForBundleID:(NSString *)bundleID reportingTo:(NSMutableArray *)unclearedPaths {")
legacy_verify_keychain_end = cleaner_m.index("- (void)verifySQLiteReferencesCleared:(NSString *)bundleID reportingTo:(NSMutableArray *)unclearedPaths {", legacy_verify_keychain_start)
legacy_verify_keychain_body = cleaner_m[legacy_verify_keychain_start:legacy_verify_keychain_end]
require("PXLogQuarantinedLegacyClearSelector(_cmd)" in legacy_verify_keychain_body,
        "legacy fuzzy Keychain verifier is not quarantined")
for token in ("SecItemCopyMatching", "containsString", "componentsSeparatedByString", "kSecAttrService", "kSecAttrAccessGroup"):
    require(token not in legacy_verify_keychain_body,
            f"quarantined Keychain verifier still infers fuzzy ownership: {token}")

legacy_verify_sql_start = legacy_verify_keychain_end
legacy_verify_sql_end = cleaner_m.index("// Helper to run a command and get its output", legacy_verify_sql_start)
legacy_verify_sql_body = cleaner_m[legacy_verify_sql_start:legacy_verify_sql_end]
require("PXLogQuarantinedLegacyClearSelector(_cmd)" in legacy_verify_sql_body,
        "legacy shared-system SQL verifier is not quarantined")
for token in ("ApplicationHistory.sqlite", "SiriAnalytics.db", "IconState.plist", "containsString", "dictionaryWithContentsOfFile"):
    require(token not in legacy_verify_sql_body,
            f"quarantined shared-system verifier still inspects ambiguous global state: {token}")

legacy_ext_start = cleaner_m.index("- (NSArray *)findExtensionContainers:(NSString *)bundleID {")
legacy_ext_end = cleaner_m.index("// Method to clear extension containers", legacy_ext_start)
legacy_ext_body = cleaner_m[legacy_ext_start:legacy_ext_end]
require(legacy_ext_body.count("PXLogQuarantinedLegacyClearSelector(_cmd)") == 3 and
        "return @[];" in legacy_ext_body and legacy_ext_body.count("return nil;") == 2,
        "legacy extension finder family is not fully quarantined")
for token in ("MCMMetadataIdentifier", "hasPrefix:bundleID", "findPathsMatchingPattern", "listDirectoriesInPath", "containsString"):
    require(token not in legacy_ext_body,
            f"quarantined legacy extension finder family still scans/fuzzily attributes state: {token}")
legacy_extension_signatures = (
    ("- (NSArray *)findExtensionContainers:(NSString *)bundleID {", "[self findExtensionContainers:"),
    ("- (NSString *)findBundleUUIDForExtension:(NSString *)extensionBundleID {", "[self findBundleUUIDForExtension:"),
    ("- (NSString *)findRootlessBundleUUIDForExtension:(NSString *)extensionBundleID {", "[self findRootlessBundleUUIDForExtension:"),
)
for signature, send in legacy_extension_signatures:
    require(cleaner_m.count(signature) == 1 and send not in cleaner_m,
            f"legacy extension helper unexpectedly has a caller/duplicate implementation: {signature}")

# Process-kill fallback must stay exact even when LaunchServices executable lookup is unavailable.
kill_start = cleaner_m.index("static void PXKillAppProcessBestEffort(AppDataCleaner *selfRef, NSString *bundleID) {")
kill_end = cleaner_m.index("static void PXStopMailDaemonsBestEffort", kill_start)
kill_body = cleaner_m[kill_start:kill_end]
require("findBundleContainerUUIDForBundleID:bundleID" in kill_body and
        "PXReadOnlyRealDirectoryAtPath" in kill_body and
        "PXReadOnlyRegularNonSymlinkFileAtPath" in kill_body and
        'info[@"CFBundleIdentifier"]' in kill_body and
        "[exactBundleID isEqualToString:bundleID]" in kill_body,
        "process-kill fallback lost exact bundle/path identity validation")
for forbidden in ("findBundleContainerUUID:bundleID", "containsString:bundleID", "hasPrefix:bundleID"):
    require(forbidden not in kill_body,
            f"process-kill fallback re-entered legacy/fuzzy bundle discovery: {forbidden}")
require("static BOOL PXReadOnlyRealDirectoryAtPath(NSString *path);" in cleaner_m[:kill_start] and
        "static BOOL PXReadOnlyRegularNonSymlinkFileAtPath(NSString *path);" in cleaner_m[:kill_start],
        "process-kill fallback is missing compile-order validator declarations")

# P0 Clear operation coordination: one serialized destructive worker, cancellation-first timeout,
# monotonic deadline clamping, and operation-local canonical verification state.
require('dispatch_queue_create("com.weaponx.app-data-cleaner.clear-coordinator", DISPATCH_QUEUE_SERIAL)' in cleaner_m,
        "P0 serialized Clear coordinator missing")
require("dispatch_async(PXClearCoordinatorQueue()" in mode_body,
        "P0 canonical Clear is not running on the serialized coordinator")
require("dispatch_sync(PXClearCoordinatorQueue()" in cleaner_m,
        "P0 synchronous destructive compatibility entry bypasses the serialized coordinator")
require('requestCancellationWithReason:@"deadline"' in mode_body,
        "P0 watchdog does not request cancellation")
watchdog_start = mode_body.index("dispatch_source_set_event_handler(watchdogTimer")
watchdog_end = mode_body.index("dispatch_resume(watchdogTimer)", watchdog_start)
watchdog_body = mode_body[watchdog_start:watchdog_end]
require("safeCompletion(" not in watchdog_body,
        "P0 watchdog must not complete/unfreeze before worker quiescence")
require('requestCancellationWithReason:@"background-expiration"' in mode_body,
        "P0 background expiration does not cancel the active operation")
require("clampedTimeoutForStepLimit" in cleaner_m and "MIN(normalizedStep, remaining)" in cleaner_m,
        "P0 child timeout is not clamped to remaining operation deadline")
require("PXCurrentClearOperationContext" in cleaner_m,
        "P0 operation context is not threaded through canonical helpers")
require("operationContext.applicationDataCanonicalPaths" in app_wipe_body,
        "P0 ApplicationData canonical paths are not operation-local")
require("operationContext.extensionDataCanonicalPaths" in aggregate_body and
        "operationContext.appGroupCanonicalPaths" in aggregate_body and
        "operationContext.pluginKitDataCanonicalPaths" in aggregate_body,
        "P0 exact-scope canonical paths are not operation-local")
require("useOperationContext || useWipeCache" in cleaner_m,
        "P0 verifier does not prefer operation-local canonical state")

# NSBundle/CFBundle recursion hardening. Foundation bundleIdentifier may resolve via
# infoDictionary, so Info.plist hook bodies must use the constructor-cached identity.
objc_info_start = ios_version_hooks.index("- (id)objectForInfoDictionaryKey:(NSString *)key")
objc_info_end = ios_version_hooks.index("%end", objc_info_start)
objc_info_body = ios_version_hooks[objc_info_start:objc_info_end]
require("gPXInsideIOSVersionBundleInfoHook" in objc_info_body,
        "IOSVersion NSBundle Info.plist hook is missing its re-entry guard")
require("gPXIOSVersionMainBundleID" in objc_info_body,
        "IOSVersion NSBundle Info.plist hook does not use cached main-bundle identity")
require("[self bundleIdentifier]" not in objc_info_body,
        "IOSVersion NSBundle Info.plist hook re-enters bundleIdentifier")

cf_info_start = ios_version_hooks.index("CFTypeRef replaced_CFBundleGetValueForInfoDictionaryKey")
cf_info_end = ios_version_hooks.index("#pragma mark - Notification Handling", cf_info_start)
cf_info_body = ios_version_hooks[cf_info_start:cf_info_end]
require("gPXInsideIOSVersionCFBundleInfoHook" in cf_info_body,
        "IOSVersion CFBundle Info.plist hook is missing its re-entry guard")
require("gPXIOSVersionMainBundleID" in cf_info_body,
        "IOSVersion CFBundle Info.plist hook does not use cached main-bundle identity")
require("CFBundleGetIdentifier(bundle)" not in cf_info_body,
        "IOSVersion CFBundle Info.plist hook re-enters bundle identity resolution")
require('gPXIOSVersionMainBundleID = [[[NSBundle mainBundle] bundleIdentifier] copy];' in ios_version_hooks,
        "IOSVersion constructor no longer captures bundle identity before hook installation")

# CLEAR-01: dry-run + transaction journal (Phase 14)
require("dryRun:(BOOL)dryRun" not in cleaner_h, "CLEAR-01 dry-run must stay off the public 25-selector header")
require("dryRun:(BOOL)dryRun" in cleaner_m, "CLEAR-01 dry-run implementation missing")
require("PXClearWriteJournal(" in cleaner_m, "CLEAR-01 journal writer missing")
require("dry_run_plan" in cleaner_m, "CLEAR-01 dry-run plan journal phase missing")
require("dry_run_commit" in cleaner_m, "CLEAR-01 dry-run commit journal phase missing")
require("no destructive operations" in cleaner_m, "CLEAR-01 dry-run guard log missing")

# 7.4: granular Clear metrics (Phase 14)
for field in ("step=resolve_container", "resolve_container_ms=", "sqlite_ms=",
              "shell_processes=", "paths_scanned=", "timeout_fallback_count=",
              "first_attempt_success_pct="):
    require(field in cleaner_m, f"7.4 metric field missing: {field}")
for counter in ("gPXClearShellProcessCount", "gPXClearPathsScannedCount", "gPXClearSqliteNanos"):
    require(counter in cleaner_m, f"7.4 metric counter missing: {counter}")

# CLEAR-09: dead brand-specific iOS15 clear path removed (Phase 14)
require("clearAppIssuesForIOS15" not in cleaner_m, "CLEAR-09 dead method still present")
for brand in ("lyft", "zimride", "helix"):
    require(brand not in cleaner_m, f"CLEAR-09 residual brand token present: {brand}")

print("Phase 8 Clear Data static contracts: PASS")
