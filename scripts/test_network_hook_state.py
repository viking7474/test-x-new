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


def read_cache_contracts():
    s = read(HOOK)
    declarations = s.split("#pragma mark - Read cache declarations", 1)[1].split("#pragma mark - End read cache declarations", 1)[0]
    publication = s.split("#pragma mark - Read cache publication", 1)[1].split("#pragma mark - End read cache publication", 1)[0]
    assert "gNetworkReadStamps[PXNetworkReadCacheCount]" in declarations
    assert "static id gNetworkModeValue, gNetworkISOValue, gNetworkPinnedValue, gNetworkCarrierValue;" in declarations
    assert "gNetworkReadStamps[kind].revision == revision" in publication
    assert "gNetworkReadStamps[kind].revision++" in publication
    assert "retired = *slot;" in publication and "*slot = value;" in publication
    assert "objc_precise_lifetime" in publication and "retired = nil; value = nil;" in publication
    assert publication.index("retired = *slot;") < publication.index("*slot = value;")
    invalidator = method(s, "static void PXNetworkInvalidateCaches(void)")
    assert "gNetworkReadStamps[index].revision++" in invalidator and "gNetworkReadStamps[index].hasTime = NO" in invalidator
    assert invalidator.index("mode = gNetworkModeValue;") < invalidator.index("gNetworkModeValue = nil;")
    assert "mode = nil; iso = nil; pinned = nil; carrier = nil;" in invalidator
    for root in ("mode", "iso", "pinned", "carrier"):
        assert "__attribute__((objc_precise_lifetime)) id " + root + " = nil;" in invalidator
    for section in publication.split("os_unfair_lock_lock(&gNetworkCacheLock);")[1:]:
        critical = section.split("os_unfair_lock_unlock(&gNetworkCacheLock);", 1)[0]
        assert "[" not in critical.replace("gNetworkReadStamps[kind]", "stamp").replace("gNetworkReadStamps[index]", "stamp")
        assert " copy]" not in critical and "dictionaryWithContentsOfFile" not in critical
    for signature, kind, ttl in (("static NSString *getCurrentISOCountryCode()", "ISO", "kISOCountryCodeCacheValidDuration"),
                                 ("static NSDictionary *getTargetRegionPinnedOverrides(void)", "Pinned", "kTargetRegionCacheValidDuration"),
                                 ("static NetworkConnectionType getNetworkConnectionType()", "Mode", "kCacheValidDuration"),
                                 ("static NSDictionary *getCarrierDetailsFromProfile()", "Carrier", "kCarrierDetailsCacheValidDuration")):
        body = method(s, signature)
        assert "NSDate" not in body and "PX_RUNTIME_READ_OPERATION;" in body
        assert "PXNetworkReadCached(PXNetworkRead" + kind + ", now, " + ttl in body
        assert "PXNetworkPublishReadCache(PXNetworkRead" + kind in body
        assert "operationView = nil;" in body and "@finally" in body
        assert "objc_setAssociatedObject(operationView," in body
    pinned = method(s, "static NSDictionary *getTargetRegionPinnedOverrides(void)")
    assert "if (hit) return cached;" in pinned and "resolved ?: NSNull.null" in pinned
    carrier = method(s, "static NSDictionary *getCarrierDetailsFromProfile()")
    assert carrier.index("PXNetworkReadCached(PXNetworkReadCarrier") < carrier.index("pinned = getTargetRegionPinnedOverrides();")
    assert "if (hit) return cached;" in carrier and "PXNetworkCarrierPacket(sourceName, sourceMCC, sourceMNC)" in carrier
    packet = method(s, "static NSDictionary *PXNetworkCarrierPacket(NSString *name, NSString *mcc, NSString *mnc)")
    assert all("[" + key + " copy]" in packet for key in ("name", "mcc", "mnc"))
    mode = method(s, "static NetworkConnectionType getNetworkConnectionType()")
    assert "if (!PXNetworkPublishReadCache(PXNetworkReadMode, packet, now, revision)) {" in mode
    assert "packet = PXNetworkCurrentModePacket();" in mode and "return packet ? (NetworkConnectionType)packet.integerValue : (NetworkConnectionType)-1;" in mode
    assert "NSNumber *mode = gNetworkModeValue;" in publication and "mode.integerValue >= NetworkConnectionTypeAuto" in publication
    assert "cacheTimestamp" not in s and "cachedCarrierName" not in s and "[NSDate date]" not in s
    check_macro_arity(read("tests/PXNetworkReadCacheTests.m"), "network-read-cache")
    print("PASS: Network read-cache publication contracts (native runtime not implied)")


def generate_native_fragments(folder):
    s = read(HOOK)
    enum = s[s.index("typedef NS_ENUM(NSInteger, NetworkConnectionType)"):s.index("// Path to security settings plist")]
    state = s.split("#pragma mark - Signal cache state", 1)[1].split("#pragma mark - End signal cache state", 1)[0]
    (folder / "PXNetworkSignalState.inc").write_text(enum + state, encoding="utf-8")
    signals = [method(s, signature) for signature in ("static int getWiFiSignalStrength()", "static int getCellularSignalBars()", "static NSString *getCurrentCellularNetworkType()")]
    (folder / "PXNetworkSignalWork.inc").write_text("\n\n".join(signals), encoding="utf-8")
    helpers = s[s.index("static NSDictionary *PXNetworkDictionary(id value)"):s.index("static NSDictionary *PXNetworkSecuritySettings(void)")]
    (folder / "PXNetworkTypedReads.inc").write_text(helpers + method(s, "static NSString *getProfileStoredIPAddress(NSString *networkKey, NSString *deviceIDsKey)"), encoding="utf-8")
    declarations = [line for line in s.splitlines() if line.startswith(("static NSString *const kFakeCarrier", "static NSString *const kFakeMobile"))]
    (folder / "PXNetworkCarrierRead.inc").write_text("\n".join(declarations) + "\n" + method(s, "static BOOL shouldForceCarrierSpoof(void)") + "\n" + method(s, "static NSDictionary *PXNetworkCarrierPacket(NSString *name, NSString *mcc, NSString *mnc)") + "\n" + method(s, "static NSDictionary *getCarrierDetailsFromProfile()"), encoding="utf-8")
    declarations = s.split("#pragma mark - Read cache declarations", 1)[1].split("#pragma mark - End read cache declarations", 1)[0]
    publication = s.split("#pragma mark - Read cache publication", 1)[1].split("#pragma mark - End read cache publication", 1)[0]
    # Gate requires the snapshot facade to be declared before this include.
    (folder / "PXNetworkReadCacheState.inc").write_text(declarations + publication, encoding="utf-8")
    (folder / "PXNetworkReadBool.inc").write_text(method(read('common/PXRuntimeSnapshotReader.m'), "BOOL PXRuntimeReadBool(id value)"), encoding="utf-8")
    consumers = [method(s, signature) for signature in ("static NSString *getCurrentISOCountryCode()",
                 "static NSDictionary *getTargetRegionPinnedOverrides(void)", "static NetworkConnectionType getNetworkConnectionType()")]
    (folder / "PXNetworkConsumerReads.inc").write_text("\n\n".join(consumers), encoding="utf-8")



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
                cache_binary = folder / ("read-cache-" + scheme + "-" + mode)
                print("Network read-cache native matrix:", scheme, mode, flush=True)
                subprocess.run(["xcrun", "clang", "-O0", "-fobjc-arc", "-fblocks", "-fexceptions", "-fobjc-exceptions", arc_flag,
                                "-Wall", "-Wextra", "-Werror=implicit-function-declaration", "-I", str(folder), *defines,
                                str(ROOT / "tests/PXNetworkReadCacheTests.m"), "-framework", "Foundation", "-o", str(cache_binary)],
                               cwd=ROOT, check=True, timeout=60)
                subprocess.run([str(cache_binary)], cwd=ROOT, check=True, timeout=60)



if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--native", action="store_true")
    args = parser.parse_args()
    source_contracts()
    read_cache_contracts()
    if args.native:
        native_tests()
