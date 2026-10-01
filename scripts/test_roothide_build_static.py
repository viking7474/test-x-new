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

for token in (
    "THEOS_PACKAGE_SCHEME=roothide",
    "ARCHS=arm64",
    "TARGET=iphone:clang:16.5:15.0",
    "_THEOS_DEB_PACKAGE_CONTROL_PATH=$(CURDIR)/control.roothide",
    "release-package-roothide",
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

for token in (
    "build-roothide:",
    "https://github.com/roothide/theos.git",
    "make release-package-roothide",
    "tlinkios-roothide-build",
):
    require(token in workflow, f"GitHub Actions missing RootHide lane token: {token}")

print("RootHide build static contracts: PASS")
