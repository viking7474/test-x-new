from pathlib import Path

p = Path('scripts/test_phase8_clear_modes_static.py')
s = p.read_text(encoding='utf-8')
anchor = '''for token in ("sharedCredentialStorage", "allCredentials", "componentsSeparatedByString", "containsString", "removeCredential"):\n    require(token not in urlcred_body,\n            f"quarantined URL credential selector still infers/mutates shared state: {token}")\n\n'''
if anchor not in s:
    raise SystemExit('test insertion anchor missing')
block = r'''# Remaining legacy helpers that mutate shared/global state stay source-compatible but fail closed.
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

'''
s = s.replace(anchor, anchor + block, 1)
p.write_text(s, encoding='utf-8')
print('added legacy global-helper quarantine regressions')
