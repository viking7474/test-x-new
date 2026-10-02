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
        "aps-environment" not in daemon_entitlements and
        "com.apple.security.application-groups" not in daemon_entitlements,
        "WeaponXDaemon entitlements are not minimal launchd-service entitlements")
require("RootHide: preserving Theos-staged tweak binaries and filters" in makefile and
        "RootHide: preserving Theos-staged WeaponXDaemon" in makefile and
        "RootHide: preserving Theos-staged backup_helper" in makefile,
        "RootHide build still risks overwriting Theos-staged Mach-O products")
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
require('NSString *canonicalDir = PXJailbreakRootPath(@"/Library/MobileSubstrate/DynamicLibraries")' in view_controller and
        '@"daemon_sync_timeout"' in view_controller and
        'attempt < 60' in view_controller and
        '[NSThread sleepForTimeInterval:0.05]' in view_controller,
        "RootHide filter writer does not wait long enough for the privileged daemon fallback")
require('kCheckInterval = 0.5' in daemon and
        '- (NSString *)stagingFingerprint' in daemon and
        'lastStagingFingerprint' in daemon and
        '@"stagingFingerprint"' in daemon and
        '@"syncSequence"' in daemon,
        "WeaponXDaemon is missing change-gated fast fallback synchronization")
require('TLinkIOSTweak=%@%@' in view_controller and
        'KeychainBridge=%@%@' in view_controller and
        'daemonSync=%@ seq=%@ ts=%@' in view_controller,
        "Reset Data error does not surface per-filter daemon diagnostics")
require(view_controller.index('CFSTR("com.hydra.tlinkios.filterPlistChanged")') <
        view_controller.index('NSString *syncStatus = nil;'),
        "Filter writer still decides failure before notifying the root daemon")
require('return PXJailbreakRootPath(@"/Library/MobileSubstrate/DynamicLibraries");' in daemon,
        "RootHide daemon does not use the canonical randomized jbroot DynamicLibraries path")
require("if (![self syncHookScopeToResetApps])" in view_controller and
        "Không thể bật hook" in view_controller,
        "Reset Data does not stop safely when the injection filter cannot be installed")
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
require('brew update' not in workflow and
        workflow.count('HOMEBREW_NO_INSTALL_UPGRADE: "1"') == 2 and
        workflow.count('brew unlink openssl@1.1 || true') == 2 and
        workflow.count('find "$DPKG_PREFIX" -type f -name dpkg-deb') == 2,
        "GitHub Actions build dependencies are vulnerable to Homebrew OpenSSL link/upgrade churn")
for token in (
    'dpkg-deb -x "$PACKAGE_FILE" "$VERIFY_DIR"',
    'test -x "$VERIFY_DIR/Applications/TLinkIOS.app/TLinkIOS"',
    'test -x "$VERIFY_DIR/Library/WeaponX/WeaponXDaemon"',
    'test -x "$VERIFY_DIR/Library/WeaponX/backup_helper"',
    'test -f "$VERIFY_DIR/Library/MobileSubstrate/DynamicLibraries/TLinkIOSTweak.dylib"',
    'test -f "$VERIFY_DIR/Library/MobileSubstrate/DynamicLibraries/TLinkIOSTweak.plist"',
    "@loader_path/.jbroot/usr/lib/libroothide.dylib",
    "com.apple.private.security.storage.AppDataContainers",
):
    require(token in workflow, f"RootHide extracted-package verification missing: {token}")

print("RootHide build static contracts: PASS")
