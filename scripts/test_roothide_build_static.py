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
require('HELPER_TOOL_PATH="${PX_SCRIPT_DIR}/backup_helper"' in keychain, "Keychain helper is not package-relative")
require("PX_JBROOT_PREFIX" in keychain, "Keychain dependencies do not support randomized jbroot")
require('"/rootfs/var/containers/Bundle/Application"' in keychain, "Keychain app discovery does not inspect RootHide rootfs")
require('const char *sbreload = "/usr/bin/sbreload"' not in view_controller,
        "Dashboard reset still bypasses RootHide-aware respring resolution")
require("[buttons killEnabledApps];" in view_controller and
        "[buttons performRespring]" in view_controller,
        "Dashboard reset does not route through the shared RootHide-aware process controller")
require("Không thể respring" in view_controller and "Respring thủ công" in view_controller,
        "Dashboard does not surface a RootHide respring failure to the user")
require("PXJailbreakPathCandidates" in bottom_buttons and
        "WIFEXITED(status) && WEXITSTATUS(status) == 0" in bottom_buttons,
        "RootHide respring does not validate resolved CLI execution")
require("static BOOL PXWriteSubstrateFilterPlists(void)" in view_controller and
        "return [syncStatus isEqualToString:@\"in_sync\"];" in view_controller,
        "Filter synchronization does not report whether the installed RootHide filters match")
require("if (![self syncHookScopeToResetApps])" in view_controller and
        "Không thể bật hook" in view_controller,
        "Reset Data does not stop safely when the injection filter cannot be installed")
require("PXRootHideBundlesMissingInjection" in view_controller and
        "destinationOfSymbolicLinkAtPath" in view_controller and
        "RootHide Bootstrap > App List" in view_controller,
        "Reset Data does not guard RootHide's independent per-app injection state")

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
for token in (
    'dpkg-deb -x "$PACKAGE_FILE" "$VERIFY_DIR"',
    'test -x "$VERIFY_DIR/Applications/TLinkIOS.app/TLinkIOS"',
    'test -x "$VERIFY_DIR/Library/WeaponX/WeaponXDaemon"',
    'test -x "$VERIFY_DIR/Library/WeaponX/backup_helper"',
):
    require(token in workflow, f"RootHide extracted-package verification missing: {token}")

print("RootHide build static contracts: PASS")
