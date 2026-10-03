#!/usr/bin/env python3
"""Static contracts for the RootHide build lane and randomized-jbroot paths."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


makefile = read("Makefile")
control = read("control.roothide")
compat = read("common/PXJailbreakCompat.h")
postinst = read("DEBIAN/postinst")
keychain = read("scripts/keychain_backup.sh")
workflow = read(".github/workflows/build-ios-arm.yml")
bottom_buttons = read("BottomButtons.m")
view_controller = read("TLinkIOSViewController.m")
daemon = read("WeaponXMountDaemon/WeaponXDaemon.m")
launchd_plist = read("com.hydra.weaponx.guardian.plist")
entitlements = read("ent.plist")
daemon_entitlements = read("daemon_ent.plist")
file_debug = read("TLinkIOSTweak/PXFileDebug.h")
tweak_main = read("TLinkIOSTweak/Tweak.x")
device_model_hooks = read("TLinkIOSTweak/DeviceModelHooks.x")
ios_version_hooks = read("TLinkIOSTweak/IOSVersionHooks.x")
scope = read("TLinkIOSTweak/PXScope.m")
runtime_snapshot = read("common/PXRuntimeSnapshot.m")
identity_snapshot = read("common/PXIdentitySnapshot.m")
storage_hooks = read("TLinkIOSTweak/StorageHooks.x")
battery_hooks = read("TLinkIOSTweak/BatteryHooks.x")
boot_time_hooks = read("TLinkIOSTweak/BootTimeHooks.x")
network_hooks = read("TLinkIOSTweak/NetworkConnectionTypeHooks.x")
theme_hooks = read("TLinkIOSTweak/ThemeHooks.x")
user_defaults_hooks = read("TLinkIOSTweak/UserDefaultsHooks.x")
pasteboard_hooks = read("TLinkIOSTweak/PasteboardHooks.x")
identifier_manager = read("common/IdentifierManager.m")

for token in (
    "THEOS_PACKAGE_SCHEME=roothide",
    "ARCHS=arm64",
    "TARGET=iphone:clang:16.5:15.0",
    "_THEOS_DEB_PACKAGE_CONTROL_PATH=$(CURDIR)/control.roothide",
    "release-package-roothide",
    "env -u _THEOS_TOP_INVOCATION_DONE",
    "-u THEOS_SCHEMA -u _THEOS_CLEANED_SCHEMA_SET",
):
    require(token in makefile, f"Makefile missing RootHide contract: {token}")

require("Architecture: iphoneos-arm64e" in control, "RootHide control architecture is wrong")
require("firmware (>= 15.0)" in control, "RootHide minimum firmware is missing")
require("com.apple.private.security.storage.AppBundles" in entitlements and
        "com.apple.private.security.storage.AppDataContainers" in entitlements,
        "RootHide app entitlements are missing documented container access")
require("WeaponXDaemon_CODESIGN_FLAGS = -Sdaemon_ent.plist" in makefile,
        "WeaponXDaemon still uses GUI application entitlements")
require("platform-application" in daemon_entitlements and
        "com.apple.private.security.no-sandbox" in daemon_entitlements and
        "com.apple.private.security.storage.AppBundles" in daemon_entitlements and
        "com.apple.private.security.storage.AppDataContainers" in daemon_entitlements and
        "com.apple.private.security.container-required" not in daemon_entitlements and
        "com.apple.private.security.no-container" not in daemon_entitlements and
        "aps-environment" not in daemon_entitlements and
        "com.apple.security.application-groups" not in daemon_entitlements,
        "WeaponXDaemon entitlements do not match RootHide's documented jailbreak-executable requirements")
require("RootHide: moving Theos-staged tweaks to ElleKit /usr/lib/TweakInject" in makefile and
        "RootHide: preserving Theos-staged WeaponXDaemon" in makefile and
        "RootHide: preserving Theos-staged backup_helper" in makefile and
        "mkdir -p $(THEOS_STAGING_DIR)/usr/lib/TweakInject" in makefile and
        "mv $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/TLinkIOSTweak.dylib $(THEOS_STAGING_DIR)/usr/lib/TweakInject/" in makefile and
        "mv $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/WeaponXKeychainBridge.dylib $(THEOS_STAGING_DIR)/usr/lib/TweakInject/" in makefile,
        "RootHide build does not relocate Theos-staged tweaks into ElleKit's canonical injector directory")
require("THEOS_PACKAGE_SCHEME_ROOTHIDE" in compat, "RootHide compile guard is missing")
require("jbroot(path)" in compat, "RootHide path conversion is missing")
require("rootfs(path)" in compat, "RootHide bootstrap argument conversion is missing")
require("PXBootstrapArguments" in compat, "RootHide CLI argument adapter is missing")

for relative in (
    "AppEntitlementsReader.m",
    "AppDataBackupManager.m",
    "AppDataCleaner.m",
    "WeaponXGuardian.m",
    "WeaponXMountDaemon/WeaponXDaemon.m",
):
    require("PXJailbreakCompat.h" in read(relative), f"{relative} does not import RootHide compatibility")

command_runner = read("CommandRunner.m")
require('PXJailbreakRootPath(@"/bin/bash")' in command_runner, "RootHide shell scripts are not routed through jbroot Bash")

require('ROOTFS_PREFIX="/rootfs"' in postinst, "postinst does not route user data to RootHide rootfs")
require('${ROOTFS_PREFIX}/var/mobile/Library' in postinst, "postinst still treats jbroot /var/mobile as user data")
require('launchd_postinst_debug.log' in postinst and
        'WeaponXDaemon" --sync-once' in postinst and
        'launchctl bootstrap system "$PLIST"' in postinst and
        'launchctl kickstart -k "system/$LABEL"' in postinst and
        'launchctl print "system/$LABEL"' in postinst,
        "RootHide postinst does not self-test/bootstrap/verify the privileged filter-sync daemon")
require('arrayWithObjects:@"TLinkIOS"' not in daemon and
        '- (void)startProcess:' not in daemon and
        '_protectedProcesses = [NSMutableArray array];' in daemon,
        "WeaponXDaemon must never respawn the TLinkIOS GUI")
require('--sync-once' in daemon and
        'daemon_runtime_status.plist' in daemon and
        'runOneShotSelfTest' in daemon,
        "WeaponXDaemon is missing the install-time executable self-test contract")
require('PX_TWEAK_LOAD_NOTIFY' in file_debug and
        'notify_set_state(token, (uint64_t)(uint32_t)getpid())' in file_debug and
        'PXFileDebugSignalTweakLoaded();' in tweak_main and
        'tweak_load_probe.plist' in daemon and
        'recordTweakLoadSignal' in daemon and
        'proc_pidpath' in daemon and
        'notify_get_state(self.tweakLoadNotifyToken, &state)' in daemon,
        "RootHide tweak-load diagnostics still depend on sandbox-local /tmp state")
require('PX_BOOTSTRAP_DECISION_NOTIFY' in file_debug and
        'PXFileDebugSignalBootstrapDecision' in tweak_main and
        'tweak_bootstrap_probe.plist' in daemon and
        '@"reasonName"' in daemon and '@"roleName"' in daemon and
        '@"bundleID"' in daemon and
        'notify_get_state(self.bootstrapDecisionNotifyToken, &state)' in daemon,
        "RootHide bootstrap diagnostics do not identify the denied/allowed target process")
require('PX_HOOK_DIAGNOSTIC_NOTIFY' in file_debug and
        'PXFileDebugSignalHookDiagnostic' in file_debug and
        'reachedMask |= (uint16_t)(1u << ((uint8_t)stage - 1u))' in file_debug and
        'notify_get_state(token, &previous)' in file_debug and
        'hook_install_probe.plist' in daemon and
        'recordHookDiagnosticSignal' in daemon and
        'notify_get_state(self.hookDiagnosticNotifyToken, &state)' in daemon and
        'notify_set_state(_hookDiagnosticNotifyToken, 0)' in daemon and
        'notify_set_state(self.hookDiagnosticNotifyToken, 0)' not in
            daemon.split('- (void)recordHookDiagnosticSignal', 1)[1].split('- (void)recordTweakLoadSignal', 1)[0] and
        '@"reachedStages"' in daemon and
        'PXHookDiagnosticStageIdentitySnapshot' in tweak_main and
        'PXHookDiagnosticStageNativeCoordinator' in tweak_main and
        'PXHookDiagnosticStageIdentifiersGroup' in tweak_main and
        'PXHookDiagnosticStageSysctlObserved' in tweak_main and
        'PXHookDiagnosticStageSysctlByNameObserved' in tweak_main and
        'PXHookDiagnosticStageMobileGestaltObserved' in tweak_main and
        'PXHookDiagnosticStageIOKitObserved' in tweak_main and
        'PXHookDiagnosticStageUnameObserved' in tweak_main and
        'PXHookDiagnosticStageSystemVersionObserved' in tweak_main and
        'PXHookDiagnosticStageDeviceModelHooks' in device_model_hooks and
        'PXHookDiagnosticStageIOSVersionHooks' in ios_version_hooks and
        'PXHookDiagnosticStageIOSVersionCFBundleHook' in ios_version_hooks,
        "RootHide hook-install telemetry must be cross-sandbox, cumulative, and cover native/profile surfaces")
require('common/PXPaths.m common/PXRuntimeSnapshot.m' in makefile and
        'PXJailbreakRootPath(@"/Library/WeaponX/Runtime/runtime_snapshot.plist")' in runtime_snapshot and
        'PXRuntimeSnapshotLocalContainerPath' in runtime_snapshot and
        'Library/Caches/com.hydra.tlinkios/runtime_snapshot.plist' in runtime_snapshot and
        '@"mirroredBundles"' in runtime_snapshot and
        '@"matchedBundles"' in runtime_snapshot and
        '/var/mobile/Containers/Data/Application' in runtime_snapshot and
        'MCMMetadataIdentifier' in runtime_snapshot and
        'PXPublishRuntimeSnapshot' in runtime_snapshot and
        'rename(tmp.fileSystemRepresentation, path.fileSystemRepresentation)' in runtime_snapshot and
        '@"globalScope"' in runtime_snapshot and '@"securitySettings"' in runtime_snapshot and
        '@"tlinkSettings"' in runtime_snapshot and '@"profileSettings"' in runtime_snapshot and
        '@"deviceIDs"' in runtime_snapshot and '@"profileArtifacts"' in runtime_snapshot and
        '@"storage"' in runtime_snapshot and '@"batteryInfo"' in runtime_snapshot and
        '@"bootTime"' in runtime_snapshot and '@"systemUptime"' in runtime_snapshot,
        "RootHide runtime mirror is missing profile artifacts or is not mirrored atomically into scoped app containers")
require('PXRuntimeSnapshotProfileArtifact(@"storage")' in storage_hooks and
        'PXRuntimeSnapshotTLinkSettings()' in storage_hooks and
        'PXRuntimeSnapshotProfileArtifact(@"batteryInfo")' in battery_hooks and
        'PXRuntimeSnapshotDeviceIDs()' in battery_hooks and
        'PXRuntimeSnapshotProfileArtifact(@"bootTime")' in boot_time_hooks and
        'PXRuntimeSnapshotProfileArtifact(@"systemUptime")' in boot_time_hooks and
        'PXRuntimeSnapshotProfileArtifact(@"networkSettings")' in network_hooks and
        'PXRuntimeSnapshotProfileArtifact(@"carrierDetails")' in network_hooks and
        'PXRuntimeSnapshotProfileArtifact(@"deviceTheme")' in theme_hooks and
        'PXRuntimeSnapshotProfileArtifact(@"userDefaultsUUID")' in user_defaults_hooks and
        'PXRuntimeSnapshotProfileArtifact(@"pasteboardUUID")' in pasteboard_hooks,
        "RootHide runtime hooks still depend on sandbox-inaccessible profile plist paths")
require('publishRuntimeSnapshotWithReason' in daemon and
        'runtime_snapshot_debug.plist' in daemon and
        'PXRuntimeSnapshotLastPublishStats()' in daemon and
        '@"publishStats"' in daemon and
        'runtimeStateFingerprint' in daemon and
        'runtime-fingerprint-changed' in daemon and
        'PXCurrentProfileInfoPath()' in daemon and
        'CFSTR("com.hydra.tlinkios.runtimeSnapshotChanged")' in daemon and
        'com.hydra.tlinkios.scopedAppsChanged' in daemon,
        "WeaponXDaemon does not publish/invalidate/diagnose/poll-fallback the RootHide runtime mirror")
require('PXRuntimeSnapshotSecuritySettings()' in scope and
        'PXRuntimeSnapshotGlobalScope()' in scope and
        'CFSTR("com.hydra.tlinkios.runtimeSnapshotChanged")' in scope,
        "PXScope still depends on sandbox-inaccessible rootfs settings on RootHide")
require('PXLoadRuntimeSnapshot()' in identity_snapshot and
        'roothide-runtime-mirror' in identity_snapshot and
        'com.hydra.tlinkios.runtimeSnapshotChanged' in identity_snapshot,
        "PXIdentitySnapshot does not consume/invalidate the RootHide runtime mirror")
require('PXRuntimeSnapshotTLinkSettings()' in identifier_manager and
        'runtimeSettings[@"EnabledIdentifiers"]' in identifier_manager and
        'runtimeEnabled[lookupType]' in identifier_manager and
        'PXRuntimeSnapshotImpliesIdentifierEnabled(type)' in identifier_manager and
        'isManagerProcess = [bundleID isEqualToString:@"com.hydra.tlinkios"]' in identifier_manager and
        'isManagerProcess = [currentBundleID isEqualToString:@"com.hydra.tlinkios"]' in identifier_manager and
        'PXRuntimeSnapshotGlobalScope()' in identifier_manager and
        'PXCurrentIdentitySnapshot()' in identifier_manager,
        "IdentifierManager does not separate live manager settings from RootHide injected-host snapshot settings")
require('PXCanonicalIdentifierToggleKeys' in identifier_manager and
        'PXSanitizedIdentifierSettings(self.settings)' in identifier_manager and
        'dictionaryWithContentsOfFile:prefsFile' in identifier_manager and
        'saveDict[@"EnabledIdentifiers"] = PXSanitizedIdentifierSettings(self.settings)' in identifier_manager and
        'updatedSettings[@"canvasNoiseSeedNonce"]' not in identifier_manager and
        'updatedSettings[@"canvasFingerprintingEnabled"]' not in identifier_manager,
        "Identifier settings persistence can still corrupt EnabledIdentifiers or clobber suite-level feature flags")
require('ensureDashboardFakeOptionsEnableRequiredIdentifiers' in view_controller and
        '[self ensureDashboardFakeOptionsEnableRequiredIdentifiers:fakeOptions];' in view_controller and
        view_controller.index('[self ensureDashboardFakeOptionsEnableRequiredIdentifiers:fakeOptions];') <
        view_controller.index('[self.manager regenerateAllEnabledIdentifiers];', view_controller.index('- (void)createNextProfileAndRandomizeWithWarnings:')),
        "Dashboard Reset Data does not persist fake-option identifier gates before profile regeneration")
require('primaryStorageEnabled != nil' in storage_hooks and
        'secondaryStorageEnabled != nil' in storage_hooks and
        'runtimeStorage[@"TotalStorage"] != nil && runtimeStorage[@"FreeStorage"] != nil' in storage_hooks and
        '@"TotalStorage": @"128"' in storage_hooks and '@"FreeStorage": @"38.4"' in storage_hooks,
        "RootHide storage still treats a missing sparse toggle/artifact differently from rootful fallback semantics")
require('@"enabledIdentifierMap"' in runtime_snapshot and
        '@"tlinkSettingsKeys"' in runtime_snapshot and
        '@"enabledIdentifierKeys"' in runtime_snapshot and
        '@"missingEnabledArtifacts"' in runtime_snapshot and
        '@"StorageSystem": @"storage"' in runtime_snapshot and
        '@"Battery": @"batteryInfo"' in runtime_snapshot,
        "RootHide runtime snapshot diagnostics do not expose raw/effective identifier settings and artifacts")
require('<key>UserName</key>' not in launchd_plist and
        '<key>GroupName</key>' not in launchd_plist and
        '<key>POSIXSpawnType</key>' not in launchd_plist and
        '<key>ProcessType</key>' not in launchd_plist and
        '<string>/Library/WeaponX/WeaponXDaemon</string>' in launchd_plist,
        "RootHide LaunchDaemon plist is not minimal/bootstrap-safe")
require('HELPER_TOOL_PATH="${PX_SCRIPT_DIR}/backup_helper"' in keychain, "Keychain helper is not package-relative")
require("PX_JBROOT_PREFIX" in keychain, "Keychain dependencies do not support randomized jbroot")
require('"/rootfs/var/containers/Bundle/Application"' in keychain, "Keychain app discovery does not inspect RootHide rootfs")
require('const char *sbreload = "/usr/bin/sbreload"' not in view_controller,
        "Dashboard reset still bypasses RootHide-aware respring resolution")
require("[buttons killEnabledApps];" in view_controller and
        "[buttons performRespring]" in view_controller,
        "Dashboard reset does not route through the shared RootHide-aware process controller")
require("Không thể respring" in view_controller and "Restart SpringBoard thủ công" in view_controller,
        "Dashboard does not surface a RootHide respring failure to the user")
require("PXJailbreakPathCandidates" in bottom_buttons and
        "WIFEXITED(status) && WEXITSTATUS(status) == 0" in bottom_buttons,
        "RootHide respring does not validate resolved CLI execution")
require("static BOOL PXWriteSubstrateFilterPlists(void)" in view_controller and
        "return [syncStatus isEqualToString:@\"in_sync\"];" in view_controller,
        "Filter synchronization does not report whether the installed RootHide filters match")
require('NSString *canonicalDir = PXJailbreakRootPath(@"/usr/lib/TweakInject")' in view_controller and
        '@"daemon_sync_timeout"' in view_controller and
        'attempt < 60' in view_controller and
        '[NSThread sleepForTimeInterval:0.05]' in view_controller,
        "RootHide filter writer does not verify ElleKit's canonical TweakInject directory")
require('kCheckInterval = 0.5' in daemon and
        '- (NSString *)stagingFingerprint' in daemon and
        'lastStagingFingerprint' in daemon and
        '@"stagingFingerprint"' in daemon and
        '@"syncSequence"' in daemon,
        "WeaponXDaemon is missing change-gated fast fallback synchronization")
require('TLinkIOSTweak=%@%@' in view_controller and
        'KeychainBridge=%@%@' in view_controller and
        'daemonSync=%@ seq=%@ ts=%@' in view_controller and
        'targetWrite=%@ (%@)' in view_controller,
        "Reset Data error does not surface daemon target-access/per-filter diagnostics")
require(view_controller.index('CFSTR("com.hydra.tlinkios.filterPlistChanged")') <
        view_controller.index('NSString *syncStatus = nil;'),
        "Filter writer still decides failure before notifying the root daemon")
require('return PXJailbreakRootPath(@"/usr/lib/TweakInject");' in daemon and
        '@"target-dir-missing"' in daemon and
        'ElleKit canonical /usr/lib/TweakInject is missing' in daemon,
        "RootHide daemon does not use/fail-closed on ElleKit's canonical TweakInject path")
require("if (![self syncHookScopeToResetApps])" in view_controller and
        "Không thể bật hook" in view_controller,
        "Reset Data does not stop safely when the injection filter cannot be installed")
reset_profile_tail = view_controller.split('[self applyFakePreviewToCurrentProfile:preview];', 1)[1][:1200]
require('CFSTR("com.hydra.tlinkios.profileChanged")' in reset_profile_tail and
        'CFNotificationCenterPostNotification' in reset_profile_tail,
        "Reset Data does not republish RootHide runtime mirrors after clearing app containers")
require("RootHide Bootstrap > App List" not in view_controller and
        "PXRootHideBundlesMissingInjection" not in view_controller,
        "Dopamine2-roothide must not be treated like the separate Bootstrap/AppEnabler product")

for token in (
    "build-roothide:",
    "https://github.com/roothide/theos.git",
    "make clean THEOS_PACKAGE_SCHEME=roothide",
    "make package THEOS_PACKAGE_SCHEME=roothide",
    "tlinkios-roothide-build",
):
    require(token in workflow, f"GitHub Actions missing RootHide lane token: {token}")

require("make release-package-roothide" not in workflow,
        "RootHide CI must not nest a top-level Theos build inside an initialized make")
require(workflow.index("make clean THEOS_PACKAGE_SCHEME=roothide") <
        workflow.index("make package THEOS_PACKAGE_SCHEME=roothide"),
        "RootHide CI must clean before starting the independent package invocation")
require('dpkg-deb -c "$PACKAGE_FILE" | grep -q' not in workflow,
        "RootHide package verification must not use a SIGPIPE-prone grep pipeline")
require('test ! -e "$VERIFY_DIR/Library/MobileSubstrate/DynamicLibraries/TLinkIOSTweak.dylib"' in workflow and
        'test ! -e "$VERIFY_DIR/Library/MobileSubstrate/DynamicLibraries/WeaponXKeychainBridge.dylib"' in workflow,
        "RootHide package verification still permits duplicate/dead legacy injector dylibs")
require('brew update' not in workflow and
        workflow.count('HOMEBREW_NO_INSTALL_UPGRADE: "1"') == 2 and
        workflow.count('brew unlink openssl@1.1 || true') == 2 and
        'find "$LDID_PREFIX"' not in workflow and
        workflow.count('LDID_DIR="$(brew --prefix ldid)/bin"') == 2 and
        workflow.count('DPKG_DIR="$(brew --prefix dpkg)/bin"') == 2 and
        workflow.count('command -v dpkg-deb') == 2,
        "GitHub Actions dependency setup is not protected from Homebrew OpenSSL/link-path regressions")
for token in (
    'dpkg-deb -x "$PACKAGE_FILE" "$VERIFY_DIR"',
    'test -x "$VERIFY_DIR/Applications/TLinkIOS.app/TLinkIOS"',
    'test -x "$VERIFY_DIR/Library/WeaponX/WeaponXDaemon"',
    'test -x "$VERIFY_DIR/Library/WeaponX/backup_helper"',
    'test -f "$VERIFY_DIR/usr/lib/TweakInject/TLinkIOSTweak.dylib"',
    'test -f "$VERIFY_DIR/usr/lib/TweakInject/TLinkIOSTweak.plist"',
    'test -f "$VERIFY_DIR/usr/lib/TweakInject/WeaponXKeychainBridge.dylib"',
    'test -f "$VERIFY_DIR/usr/lib/TweakInject/WeaponXKeychainBridge.plist"',
    "@loader_path/.jbroot/usr/lib/libroothide.dylib",
    "DAEMON_ENTITLEMENTS=\"$(ldid -e \"$VERIFY_DIR/Library/WeaponX/WeaponXDaemon\")\"",
    "com.apple.private.security.storage.AppBundles",
    "com.apple.private.security.storage.AppDataContainers",
):
    require(token in workflow, f"RootHide extracted-package verification missing: {token}")

print("RootHide build static contracts: PASS")
