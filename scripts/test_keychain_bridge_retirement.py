#!/usr/bin/env python3
"""Bridge absence contracts and real /bin/sh migration tests on disposable trees."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BRIDGE = "WeaponXKeychainBridge"
INJECTORS = (
    "Library/MobileSubstrate/DynamicLibraries",
    "usr/lib/TweakInject",
    "var/jb/Library/MobileSubstrate/DynamicLibraries",
    "var/jb/usr/lib/TweakInject",
    "private/var/jb/Library/MobileSubstrate/DynamicLibraries",
    "private/var/jb/usr/lib/TweakInject",
)


def check_source_contracts() -> None:
    def read(path: str) -> str:
        return (ROOT / path).read_text(encoding="utf-8")

    assert not (ROOT / f"{BRIDGE}.plist").exists(), "retired injection plist returned"
    assert not (ROOT / BRIDGE / "Tweak.m").exists(), "retired request listener returned"
    makefile = read("Makefile")
    targets = next(line for line in makefile.splitlines() if line.startswith("TWEAK_NAME ="))
    assert targets.split("=", 1)[1].split() == ["TLinkIOSTweak"], targets
    assert f"{BRIDGE}_FILES" not in makefile
    assert "retire_keychain_bridge.sh" in makefile
    for injector in INJECTORS[:2]:
        for suffix in ("plist", "dylib"):
            assert f"$(THEOS_STAGING_DIR)/{injector}/{BRIDGE}.{suffix}" in makefile
    for path in (
        "TLinkIOSViewController.m", "WeaponXMountDaemon/WeaponXDaemon.m",
        "common/PXInjectionFilter.h", "common/PXInjectionFilter.m",
        "tests/PXInjectionFilterTests.m", "tests/PXPhaseBRegressionGateTests.m",
    ):
        source = read(path)
        for obsolete in (BRIDGE, "PXInjectionComputeBridgeBundles", "bridgeBundles"):
            assert obsolete not in source, f"{path} retains {obsolete}"
    cleaner = read("AppDataCleaner.m")
    backup = read("AppDataBackupManager.m")
    assert "method=resigned_helper noLaunch=1" in cleaner
    assert "Legacy in-app Keychain restore method migrated to resigned helper" in backup
    assert "restorePlan.keychainUsesInAppMethod" in backup
    for obsolete in ("weaponx_keychain_request", "PXWaitForKeychainBridgeResponse"):
        assert obsolete not in cleaner and obsolete not in backup
    postinst = read("DEBIAN/postinst")
    assert postinst.index("launchctl bootout system/com.hydra.weaponx.guardian") < postinst.index(
        '/bin/sh "$RETIRE_SCRIPT"') < postinst.index('WeaponXDaemon" --sync-once')
    for prefix in ("", "/var/jb", "/private/var/jb"):
        assert f"{prefix}/Library/WeaponX/retire_keychain_bridge.sh" in postinst
    preinst = read("DEBIAN/preinst")
    assert "pending-target-restart" in preinst and "runtimeVerified" in preinst
    assert "killall" not in preinst and "rm -rf" not in preinst


def check_package_tree(root: Path) -> None:
    if not root.is_dir():
        raise AssertionError(f"extracted package directory missing: {root}")
    forbidden = {f"{BRIDGE}.plist", f"{BRIDGE}.dylib"}
    leftovers = [str(p.relative_to(root)) for p in root.rglob("*") if p.name in forbidden]
    if leftovers:
        raise AssertionError(f"retired bridge in package: {leftovers}")
    for relative in ("DEBIAN/preinst", "Library/WeaponX/retire_keychain_bridge.sh"):
        if not (root / relative).is_file():
            raise AssertionError(f"retirement migration missing from package: {relative}")
    # A package scheme may rewrite the helper shebang; the migration body must match.
    if (root / "DEBIAN/preinst").read_text().splitlines()[1:] != (
        root / "Library/WeaponX/retire_keychain_bridge.sh"
    ).read_text().splitlines()[1:]:
        raise AssertionError("preinst and postinst retirement implementation differ")


def shell_path(path: Path) -> str:
    value = path.resolve().as_posix()
    if os.name == "nt":
        return f"/{value[0].lower()}{value[2:]}"
    return value


class RetirementTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if os.name == "nt":
            candidates = (Path("C:/Program Files/Git/bin/bash.exe"),
                          Path("C:/Program Files/Git/usr/bin/sh.exe"))
            cls.shell = next((str(p) for p in candidates if p.is_file()), None)
        else:
            cls.shell = shutil.which("sh")
        if cls.shell is None:
            raise RuntimeError("A POSIX shell is required for migration tests")

    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="px-bridge-retirement-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / ".px-bridge-retirement-fixture").touch()

    def run_migration(self, expected: int = 0) -> dict:
        result = subprocess.run(
            [self.shell, shell_path(ROOT / "DEBIAN/preinst"),
             "--fixture-root", shell_path(self.root)],
            capture_output=True, text=True, timeout=15,
        )
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        prefix = "rootfs/" if (self.root / "rootfs/var/mobile").is_dir() else ""
        status = self.root / f"{prefix}var/mobile/Library/Preferences/com.hydra.tlinkios.bridge-retirement.plist"
        return plistlib.loads(status.read_bytes())

    def artifact(self, path: str, content: bytes = b"legacy") -> Path:
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        return target

    def test_source_contracts(self) -> None:
        check_source_contracts()

    def test_fresh_install_does_not_claim_runtime_verification(self) -> None:
        status = self.run_migration()
        self.assertEqual(status["status"], "no-artifacts-detected")
        self.assertTrue(status["artifactsRemoved"])
        self.assertFalse(status["restartRequired"])
        self.assertFalse(status["runtimeVerified"])

    def test_upgrade_cleans_all_layouts_and_rerun_retains_restart_requirement(self) -> None:
        artifacts = [self.artifact(f"{base}/{BRIDGE}.{suffix}")
                     for base in INJECTORS for suffix in ("plist", "dylib")]
        artifacts += [self.artifact(f"var/mobile/Library/{name}/filter_plists/{BRIDGE}.plist")
                      for name in ("TLinkIOS", "ProjectX")]
        keep = self.artifact("Library/WeaponX/backup_helper", b"keep-helper")
        archive = self.artifact("var/mobile/Library/WeaponX/Profiles/fixture/keychain.plist", b"keep-backup")
        status = self.run_migration()
        self.assertTrue(all(not path.exists() for path in artifacts))
        self.assertEqual(keep.read_bytes(), b"keep-helper")
        self.assertEqual(archive.read_bytes(), b"keep-backup")
        self.assertEqual(status["status"], "pending-target-restart")
        self.assertTrue(status["restartRequired"])
        self.assertEqual(self.run_migration(), status)

    def test_roothide_routes_staging_and_status_to_rootfs(self) -> None:
        (self.root / "rootfs/var/mobile").mkdir(parents=True)
        staged = self.artifact(f"rootfs/var/mobile/Library/TLinkIOS/filter_plists/{BRIDGE}.plist")
        injector = self.artifact(f"usr/lib/TweakInject/{BRIDGE}.dylib")
        untouched = self.artifact("var/mobile/Library/TLinkIOS/unrelated.plist", b"keep")
        status = self.run_migration()
        self.assertFalse(staged.exists())
        self.assertFalse(injector.exists())
        self.assertEqual(untouched.read_bytes(), b"keep")
        self.assertTrue(status["restartRequired"])

    def test_directory_at_artifact_path_fails_without_recursive_removal(self) -> None:
        child = self.artifact(f"usr/lib/TweakInject/{BRIDGE}.plist/keep.txt", b"keep")
        status = self.run_migration(expected=1)
        self.assertEqual(child.read_bytes(), b"keep")
        self.assertEqual(status["status"], "cleanup-failed")
        self.assertFalse(status["artifactsRemoved"])

    def test_preinst_does_not_suppress_legacy_projectx_data_migration(self) -> None:
        profile = self.artifact("var/mobile/Library/ProjectX/Profiles/fixture/identity.plist", b"keep-profile")
        self.run_migration()
        self.assertFalse((self.root / "var/mobile/Library/TLinkIOS").exists())
        self.assertEqual(profile.read_bytes(), b"keep-profile")

    def test_leaf_symlink_is_unlinked_without_touching_target(self) -> None:
        keep = self.artifact("private-data/keep.plist", b"keep")
        link = self.root / f"usr/lib/TweakInject/{BRIDGE}.plist"
        link.parent.mkdir(parents=True)
        try:
            link.symlink_to(keep)
        except OSError as error:
            self.skipTest(f"host does not permit symlinks: {error}")
        self.run_migration()
        self.assertFalse(link.is_symlink())
        self.assertEqual(keep.read_bytes(), b"keep")

    def test_status_directory_aborts_before_artifact_removal(self) -> None:
        status_dir = self.root / "var/mobile/Library/Preferences/com.hydra.tlinkios.bridge-retirement.plist"
        status_dir.mkdir(parents=True)
        artifact = self.artifact(f"usr/lib/TweakInject/{BRIDGE}.dylib")
        result = subprocess.run([self.shell, shell_path(ROOT / "DEBIAN/preinst"),
                                 "--fixture-root", shell_path(self.root)],
                                capture_output=True, timeout=15)
        self.assertEqual(result.returncode, 1)
        self.assertTrue(artifact.is_file())
        self.assertEqual(list(status_dir.iterdir()), [])

    def test_refuses_host_root_as_fixture(self) -> None:
        for root in ("/", "//", "////", "/./"):
            with self.subTest(root=root):
                result = subprocess.run([self.shell, shell_path(ROOT / "DEBIAN/preinst"),
                                         "--fixture-root", root], capture_output=True, timeout=15)
                self.assertEqual(result.returncode, 64)

    def test_package_checker_rejects_each_retired_artifact(self) -> None:
        self.artifact("DEBIAN/preinst")
        self.artifact("Library/WeaponX/retire_keychain_bridge.sh")
        check_package_tree(self.root)
        for suffix in ("dylib", "plist"):
            path = self.artifact(f"usr/lib/TweakInject/{BRIDGE}.{suffix}")
            with self.assertRaises(AssertionError):
                check_package_tree(self.root)
            path.unlink()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--package-root", type=Path)
    args = parser.parse_args()
    if args.package_root:
        check_package_tree(args.package_root.resolve())
        print("Keychain Bridge extracted-package absence: PASS")
    else:
        unittest.main(argv=[sys.argv[0]], verbosity=2)
