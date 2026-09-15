#!/usr/bin/env python3
"""Static Phase-8 Clear Data Quick/Full/Deep contracts."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def text(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")

def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)

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

# App-state cleanup keeps only exact bundle-derived files; fuzzy recursive directory scans are quarantined.
app_state_start = cleaner_m.index("- (void)_internalClearAppStateData:(NSString *)bundleID {")
app_state_end = cleaner_m.index("// Helper to scan a directory and wipe files/folders matching a string", app_state_start)
app_state_body = cleaner_m[app_state_start:app_state_end]
require("ApplicationState/%@.plist" in app_state_body and
        "com.apple.UIKit.SplitView.%@.plist" in app_state_body and
        "securelyWipeFile" in app_state_body,
        "exact app-state file cleanup missing")
for fuzzy_state_token in ("FrontBoard", "LiveActivities", "RecentlyTerminatedAppState", "BackgroundTasks", "/TCC", "scanAndWipeInDirectory", "containsString"):
    require(fuzzy_state_token not in app_state_body,
            f"app-state cleanup still uses fuzzy shared-directory ownership: {fuzzy_state_token}")
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
require("PXLogQuarantinedLegacyClearSelector(_cmd)" in system_logs_body,
        "system-log compatibility selector is not quarantined")
for token in ("/var/log", "CrashReporter", "DiagnosticReports", "/ASL", "findPathsMatchingPattern", "securelyWipeFile"):
    require(token not in system_logs_body,
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
require("PXLogQuarantinedLegacyClearSelector(_cmd)" in health_body,
        "health compatibility selector is not quarantined")
for token in ("/Library/Health", "/HealthKit", "enumeratorAtURL", "containsString", "securelyWipeFile"):
    require(token not in health_body,
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

# Encrypted preferences outside the app container must have an exact bundle-id filename boundary.
encrypted_start = cleaner_m.index("- (void)_internalClearEncryptedDataOutsideMainApplicationContainer:(NSString *)bundleID\n                                                         deepClean:(BOOL)deepClean {")
encrypted_end = cleaner_m.index("- (void)_internalClearEncryptedData:(NSString *)bundleID", encrypted_start)
encrypted_body = cleaner_m[encrypted_start:encrypted_end]
for exact_pattern in ("%@.enc*", "%@.encrypted*", "%@.secure*"):
    require(exact_pattern in encrypted_body, f"missing exact encrypted preference boundary: {exact_pattern}")
for fuzzy_pattern in ("%@*.enc*", "%@*.encrypted*", "%@*.secure*"):
    require(fuzzy_pattern not in encrypted_body,
            f"encrypted preference scan can still match sibling bundle-id prefixes: {fuzzy_pattern}")
require("findPathsMatchingPattern" in encrypted_body and "securelyWipeFile" in encrypted_body,
        "encrypted preference cleanup unexpectedly lost bounded discovery/wipe flow")

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
