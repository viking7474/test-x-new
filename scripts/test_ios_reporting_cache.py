#!/usr/bin/env python3
"""Patch 5: exact iOS version reporting/cache fragments; --native needs macOS."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys
import tempfile
from test_runtime_identifier_writers import method
from test_profile_creation_flow import check_macro_arity

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text(encoding="utf-8")
HOOK = "TLinkIOSTweak/IOSVersionHooks.x"
SURFACES = [("- (NSString *)systemVersion", "PXFixtureOriginalVersion()"),
            ("- (NSOperatingSystemVersion)operatingSystemVersion", "PXFixtureOriginalStruct()"),
            ("- (NSString *)operatingSystemVersionString", "PXFixtureOriginalVersionString()")]


def source_contracts():
    s = read(HOOK)
    state = s.split("#pragma mark - Reporting cache state", 1)[1].split("#pragma mark - End reporting cache state", 1)[0]
    assert "clock_gettime(CLOCK_MONOTONIC, &instant)" in state and "1000000000.0" in state
    assert "now >= loadedAt && now - loadedAt < ttl" in state and "isfinite(now) && isfinite(loadedAt)" in state
    assert "kIOSSystemVersionCacheValidPeriod = 0.1" in state and "kIOSVersionCacheValidPeriod = 1800.0" in state
    assert "gIOSVersionIdentity == identity" in state and "storedInfo == info" in state and "[storedBundle isEqualToString:bundle]" in state
    assert "gIOSInfoRevision == revision" in state and "gIOSSystemRevision == revision" in state
    for section in state.split("os_unfair_lock_lock(&gIOSVersionCacheLock);")[1:]:
        locked = section.split("os_unfair_lock_unlock(&gIOSVersionCacheLock);", 1)[0]
        assert "[" not in locked and " copy]" not in locked
    invalidator = method(s, "static void PXIOSVersionInvalidateCache(void)")
    assert "gIOSInfoRevision++" in invalidator and "gIOSSystemRevision++" in invalidator
    assert "gIOSInfoHasTime = NO; gIOSSystemHasTime = NO;" in invalidator
    for root, type_name in (("oldInfo", "NSDictionary"), ("oldIdentity", "PXIdentitySnapshot"), ("oldResult", "NSString"), ("oldBundle", "NSString"), ("oldSystemInfo", "NSDictionary")):
        assert "__attribute__((objc_precise_lifetime)) " + type_name + " *" + root + " = nil;" in invalidator
    assert "lastSystemVersionCallTime" not in s and "cachedSystemVersionResult" not in s
    get_info = method(s, "static NSDictionary *getIOSVersionInfo()")
    assert "PX_RUNTIME_READ_OPERATION;" in get_info and "view, &kPXRuntimeIOSInfo" in get_info
    assert "PXIOSVersionCachedInfo(identity, now, NULL)" in get_info
    assert get_info.index("PXIOSVersionInfoEpoch()") < get_info.index("identity = PXCurrentIdentitySnapshot();")
    assert "if (currentIdentity == identity) PXIOSVersionPublishInfo(result, identity, now, revision);" in get_info
    assert "result = PXIOSVersionFreezeInfo(raw);" in get_info and "view = nil;" in get_info
    assert "if (gPXInsideIOSVersionInfo) return nil;" in get_info and "gPXInsideIOSVersionInfo = NO;" in get_info
    assert "dispatch_once" not in get_info and "[NSDate date]" not in get_info
    freeze = method(s, "static NSDictionary *PXIOSVersionFreezeInfo(id raw)")
    assert "[raw isKindOfClass:NSDictionary.class]" in freeze and "[field isKindOfClass:NSString.class]" in freeze
    assert "[field copy]" in freeze and "return [packet copy];" in freeze
    gate = method(s, "static BOOL PXIOSVersionReportingAllowedForBundle(NSString *bundleID)")
    assert 'isIdentifierEnabled:@"IOSVersion"' in gate and "PXProcessIsAllowedForSpoofing" in gate
    assert "PXScopeOptionAllowSafariAuthStack" in gate and "NSLog" not in gate
    for signature, _ in SURFACES:
        body = method(s, signature)
        assert "PXIOSVersionReportingAllowedForBundle(bundleID)" in body
        assert "if (gPXInsideIOSReportingHook) return %orig;" in body and "gPXInsideIOSReportingHook = NO;" in body
        assert "PXReportingIOSVersionBuildForBundle" in body and "@finally" in body
        assert "PXNativeSafeIOSVersionBuild" not in body
    uid = method(s, SURFACES[0][0])
    assert uid.index("PXIOSVersionSystemEpoch()") < uid.index("getIOSVersionInfo()")
    assert uid.index("PXIOSVersionReportingAllowedForBundle") < uid.index("PXIOSSystemCachedResult")
    assert 'PXIOSSystemPublishResult(reportedVersion, versionInfo, bundleID, now, revision)' in uid
    settings = method(s, "static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)")
    assert "PXIOSVersionInvalidateCache();" in settings
    assert "%dtor {\n    PXIOSVersionInvalidateCache();\n}" in s
    assert "scripts/test_ios_reporting_cache.py --native" in read(".github/workflows/build-ios-arm.yml")
    assert "scripts/test_ios_reporting_cache.py" in read("scripts/release_hardening.py")
    check_macro_arity(read("tests/PXIOSReportingCacheTests.m"), "ios-reporting-cache")
    print("PASS: iOS reporting/cache source contracts (native runtime not implied)")


def generate_native_fragments(folder):
    s = read(HOOK)
    state = s.split("#pragma mark - Reporting cache state", 1)[1].split("#pragma mark - End reporting cache state", 1)[0]
    (folder / "PXIOSReportingState.inc").write_text(state, encoding="utf-8")
    signatures = ["static NSDictionary *PXIOSVersionFreezeInfo(id raw)", "static BOOL PXIOSVersionReportingAllowedForBundle(NSString *bundleID)",
                  "static NSDictionary *getIOSVersionInfo()", "static NSOperatingSystemVersion getOperatingSystemVersion(NSString *versionString)"]
    (folder / "PXIOSReportingWork.inc").write_text("\n\n".join(method(s, sig) for sig in signatures), encoding="utf-8")
    methods = [method(s, signature) for signature, _ in SURFACES]
    (folder / "PXIOSReportingDeclarations.inc").write_text("\n".join(body.split(" {", 1)[0] + ";" for body in methods), encoding="utf-8")
    (folder / "PXIOSReportingMethods.inc").write_text("\n\n".join(body.replace("%orig", replacement) for body, (_, replacement) in zip(methods, SURFACES)), encoding="utf-8")
    compat = read("common/PXRuntimeOSCompatibility.m")
    pure = ["static NSString *PXRuntimeOSString(id value)", "static NSArray<NSNumber *> *PXRuntimeOSVersionComponents(NSString *version)",
            "BOOL PXReportingIOSVersionBuildForBundle(NSString *configuredVersion,\n                                         NSString *configuredBuild,\n                                         NSString *bundleID,\n                                         NSString **outVersion,\n                                         NSString **outBuild)"]
    (folder / "PXIOSReportingPolicy.inc").write_text("\n\n".join(method(compat, sig) for sig in pure), encoding="utf-8")


def native_tests():
    assert sys.platform == "darwin" and shutil.which("xcrun"), "--native requires macOS/xcrun; cannot silently skip"
    with tempfile.TemporaryDirectory(prefix="px-ios-reporting-cache-") as temp:
        folder = Path(temp); generate_native_fragments(folder)
        for scheme, defines in (("rootful", []), ("roothide", ["-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1"])):
            for mode, flag in (("plain-arc", "-fno-objc-arc-exceptions"), ("arc-eh", "-fobjc-arc-exceptions")):
                binary = folder / (scheme + "-" + mode)
                print("iOS reporting cache native matrix:", scheme, mode, flush=True)
                subprocess.run(["xcrun", "clang", "-O0", "-fobjc-arc", "-fblocks", "-fexceptions", "-fobjc-exceptions", flag,
                                "-Wall", "-Wextra", "-Werror=implicit-function-declaration", "-I", str(folder), *defines,
                                str(ROOT / "tests/PXIOSReportingCacheTests.m"), "-framework", "Foundation", "-o", str(binary)], cwd=ROOT, check=True, timeout=60)
                subprocess.run([str(binary)], cwd=ROOT, check=True, timeout=60)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(); parser.add_argument("--native", action="store_true"); args = parser.parse_args()
    source_contracts()
    if args.native: native_tests()
