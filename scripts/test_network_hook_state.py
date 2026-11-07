#!/usr/bin/env python3
"""Network hook signal/radio and typed read boundaries; native requires macOS."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from test_runtime_identifier_writers import method
from test_profile_creation_flow import check_macro_arity

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text(encoding="utf-8")
HOOK = "TLinkIOSTweak/NetworkConnectionTypeHooks.x"


def source_contracts():
    s = read(HOOK)
    state = s.split("#pragma mark - Signal cache state", 1)[1].split("#pragma mark - End signal cache state", 1)[0]
    assert "clock_gettime(CLOCK_MONOTONIC, &ts)" in state and "1000000000.0" in state
    assert "now >= then && now - then < ttl" in state and "isfinite(now) && isfinite(then)" in state
    assert "NSDate" not in state and "NSString" not in state
    assert "lastSignalUpdateTime" not in s
    invalidate = method(s, "static void PXNetworkInvalidateCaches(void)")
    assert "PXNetworkInvalidateSignalCachesLocked();" in invalidate
    reset = method(s, "static void PXNetworkInvalidateSignalCachesLocked(void)")
    for unit in ("gWiFiSignal", "gCellularSignal", "gNetworkRadio"):
        assert unit + ".revision++" in reset and unit + ".hasTime = NO" in reset
    for name, unit in (("getWiFiSignalStrength", "gWiFiSignal"), ("getCellularSignalBars", "gCellularSignal")):
        body = method(s, "static int " + name + "()")
        assert unit + ".revision == before.revision" in body
        assert "PXNetworkSignalFresh(now, before.updatedAt, before.hasTime, 30.0)" in body
        assert "getNetworkConnectionType()" in body and "arc4random_uniform" in body
        assert "NSDate" not in body and "PX_RUNTIME_READ_OPERATION;" in body
        # No policy lookup, Foundation or RNG in any signal/radio critical section.
    for signature in ("static int getWiFiSignalStrength()", "static int getCellularSignalBars()", "static NSString *getCurrentCellularNetworkType()"):
        body = method(s, signature)
        for section in body.split("os_unfair_lock_lock(&gNetworkCacheLock);")[1:]:
            critical = section.split("os_unfair_lock_unlock(&gNetworkCacheLock);", 1)[0]
            assert "[" not in critical and "arc4random_uniform" not in critical and "getNetworkConnectionType" not in critical
    radio = method(s, "static NSString *getCurrentCellularNetworkType()")
    assert "gNetworkRadio.revision == revision" in radio
    assert "arc4random_uniform(100) < 10" in radio and "arc4random_uniform(100) < 70" in radio
    assert "case PXNetworkRadioNRNSA: return @" in radio and "kMinNetworkTypeChangeDuration" in radio
    source = method(s, "static NSDictionary *PXNetworkCarrierSourceAtIdentity(NSString *identityDir)")
    assert "PXActiveProfile" not in source and all(name in source for name in ("carrier_details.plist", "network_settings.plist", "device_ids.plist"))
    device_path = method(read("common/PXPaths.m"), "NSString *PXProfileDeviceIDsPath(NSString *profileID)")
    assert "PXProfileIdentityPath(profileID)" in device_path and 'stringByAppendingPathComponent:@"device_ids.plist"' in device_path
    carrier = method(s, "static NSDictionary *getCarrierDetailsFromProfile()")
    assert "identityDir = getProfileIdentityPath();" in carrier and "source = PXNetworkCarrierSourceAtIdentity(identityDir);" in carrier
    assert "identityDir = nil;" in carrier and "identityDir = nil;" in source
    assert "PXNetworkCarrierSource(carrier, network, deviceIDs)" in carrier
    assert "operationView, &carrierResultKey" in carrier
    assert "PX_RUNTIME_READ_OPERATION;" in carrier and carrier.count("PXNetworkCarrierField(source,") == 3
    ip = method(s, "static NSString *getProfileStoredIPAddress(NSString *networkKey, NSString *deviceIDsKey)")
    assert ip.count("PXNetworkDictionary(networkDict)[networkKey]") == 2
    assert ip.count("PXNetworkDictionary(deviceIds)[deviceIDsKey]") == 2
    assert '[settings[@"targetRegionFollowsIPEnabled"] boolValue]' not in s
    assert '[settings[@"fullSpoofTestModeEnabled"] boolValue]' not in s
    assert "return PXNetworkDictionary(runtimeView.securitySettings) ?: @{};" in s
    assert 'scripts/test_network_hook_state.py --native' in read('.github/workflows/build-ios-arm.yml')
    assert 'scripts/test_network_hook_state.py' in read('scripts/release_hardening.py')
    check_macro_arity(read("tests/PXNetworkHookStateTests.m"), "network-hook-state")
    print("PASS: Network hook signal/radio and typed-read source contracts (native runtime not implied)")


def generate_native_fragments(folder):
    s = read(HOOK)
    enum = s[s.index("typedef NS_ENUM(NSInteger, NetworkConnectionType)"):s.index("// Path to security settings plist")]
    state = s.split("#pragma mark - Signal cache state", 1)[1].split("#pragma mark - End signal cache state", 1)[0]
    (folder / "PXNetworkSignalState.inc").write_text(enum + state, encoding="utf-8")
    signals = [method(s, signature) for signature in ("static int getWiFiSignalStrength()", "static int getCellularSignalBars()", "static NSString *getCurrentCellularNetworkType()")]
    (folder / "PXNetworkSignalWork.inc").write_text("\n\n".join(signals), encoding="utf-8")
    helpers = s[s.index("static NSDictionary *PXNetworkDictionary(id value)"):s.index("static NSDictionary *PXNetworkSecuritySettings(void)")]
    (folder / "PXNetworkTypedReads.inc").write_text(helpers + method(s, "static NSString *getProfileStoredIPAddress(NSString *networkKey, NSString *deviceIDsKey)"), encoding="utf-8")
    declarations = [line for line in s.splitlines() if line.startswith(("static NSString *const kFakeCarrier", "static NSString *const kFakeMobile", "static NSString *cachedCarrier", "static NSString *cachedMobile", "static NSDate *carrierDetailsCache", "static const NSTimeInterval kCarrierDetailsCache"))]
    (folder / "PXNetworkCarrierRead.inc").write_text("\n".join(declarations) + "\n" + method(s, "static BOOL shouldForceCarrierSpoof(void)") + "\n" + method(s, "static NSDictionary *getCarrierDetailsFromProfile()"), encoding="utf-8")
    (folder / "PXNetworkReadBool.inc").write_text(method(read('common/PXRuntimeSnapshotReader.m'), "BOOL PXRuntimeReadBool(id value)"), encoding="utf-8")


def native_tests():
    assert sys.platform == "darwin" and shutil.which("xcrun"), "--native requires macOS/xcrun; cannot silently skip"
    with tempfile.TemporaryDirectory(prefix="px-network-hook-state-") as temp:
        folder = Path(temp)
        generate_native_fragments(folder)
        for scheme, defines in (("rootful", []), ("roothide", ["-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1"])):
            for mode, arc_flag in (("plain-arc", "-fno-objc-arc-exceptions"), ("arc-eh", "-fobjc-arc-exceptions")):
                binary = folder / (scheme + "-" + mode)
                print("Network hook state native matrix:", scheme, mode, flush=True)
                subprocess.run(["xcrun", "clang", "-O0", "-fobjc-arc", "-fblocks", "-fexceptions", "-fobjc-exceptions", arc_flag,
                                "-Wall", "-Wextra", "-Werror=implicit-function-declaration", "-I", str(folder), *defines,
                                str(ROOT / "tests/PXNetworkHookStateTests.m"), "-framework", "Foundation", "-o", str(binary)],
                               cwd=ROOT, check=True, timeout=60)
                subprocess.run([str(binary)], cwd=ROOT, check=True, timeout=60)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--native", action="store_true")
    args = parser.parse_args()
    source_contracts()
    if args.native:
        native_tests()
