#!/usr/bin/env python3
"""Captured consumer wiring; --native exercises production lexical read scopes."""
from pathlib import Path
import argparse
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def source_contracts():
    runtime = read("common/PXRuntimeSnapshot.m")
    scope = read("TLinkIOSTweak/PXScope.m")
    identity = read("common/PXIdentitySnapshot.m")
    manager = read("common/IdentifierManager.m")
    header = read("common/PXRuntimeSnapshot.h")
    engine = read("common/PXRuntimeReadScope.m")
    legacy = re.compile(r"PXRuntimeSnapshot(?:GlobalScope|SecuritySettings|TLinkSettings|ProfileID|ProfileSettings|DeviceIDs|ProfileArtifact)\(")
    consumers = [
        "BatteryHooks.x", "BootTimeHooks.x", "NetworkConnectionTypeHooks.x", "StorageHooks.x",
        "ThemeHooks.x", "UserDefaultsHooks.x", "PasteboardHooks.x", "Tweak.x", "PXScope.m", "WiFiHook.x", "UUIDHooks.x",
    ]
    for file in consumers:
        source = read("TLinkIOSTweak/" + file)
        require(not legacy.search(source), f"legacy per-field file accessor remains: {file}")
        require("PX_RUNTIME_READ_OPERATION;" in source, f"missing operation boundary: {file}")
    require(not legacy.search(identity) and not legacy.search(manager), "common consumers still use legacy file getters")
    require("PXRuntimeReadScopeCurrent(&scoped)" in runtime and "if (!scoped)" in runtime,
            "capture must inherit the current operation, including a pending nil view")
    require("cleanup(PXRuntimeReadScopeEnd)" in header and "scope->previous = gPXRuntimeReadScope" in engine and
            "gPXRuntimeReadScope = scope->previous" in engine and "CFRelease" in engine,
            "lexical frames must own and unwind their retained view")
    require("objc_getAssociatedObject(runtime, &scopeKey)" in scope and "PXBuildSnapshot(runtime.readerGeneration)" in scope,
            "scope cache must be tied to the captured view, not TTL from another publication")
    require("PXPrimeRuntimeSnapshotReader();" in scope and "PXProcessSystemDaemon || gPXProcessRole == PXProcessUnknown" in scope,
            "classification must filter denied process roles before cold priming")
    require("return [PXWebKitMetadataReader() capture].profileID;" in scope and "PXPrimeWebKitMetadataReader();" in scope,
            "RootHide WebKit metadata must load on a worker after cold bootstrap, never parse on a hot lookup")
    require("PXIdentitySnapshotStartObserving();" in scope and "if (result.capabilities) {" in scope,
            "allowed WebKit helpers must prepare identity even when native-only ctors are denied")
    require("PXRuntimeSnapshotRegisterPreparation" in identity and "PXBuildIdentitySnapshot(runtime)" in identity and
            "objc_getAssociatedObject(runtime, &kPXRuntimeIdentityProjection)" in identity,
            "identity must be prepared before publication and read from the same captured view")
    current = identity.split("PXIdentitySnapshot *PXCurrentIdentitySnapshot(void)", 1)[1]
    captured = current.split("if (PXIdentityUsesCapturedRuntime())", 1)[1].split("os_unfair_lock_lock", 1)[0]
    require("PXReloadIdentitySnapshot" not in captured and "PXBuildIdentitySnapshot" not in captured,
            "injected identity getter must not build/parse on a hook thread")
    require("if (!usedRuntimeMirror && !PXIdentityUsesCapturedRuntime())" in identity,
            "unavailable injected data must not fall through to live files")
    require("PX_IDENTIFIER_RUNTIME_READ_OPERATION" in manager and "PXIdentifierManagerIsManagerProcess()" in manager and
            "return PXCaptureRuntimeSnapshot().profileID;" in manager and
            "PXRuntimeSnapshotImpliesIdentifierEnabled(type, runtimeView)" in manager,
            "manager live-writer bypass and captured enablement/profile must remain distinct")
    for file, key in (("UserDefaultsHooks.x", "UserDefaultsUUID"), ("PasteboardHooks.x", "PasteboardUUID")):
        source = read("TLinkIOSTweak/" + file)
        require("if (runtimeUUID.length) return runtimeUUID;\n    return nil;" in source,
                f"{key} must not generate/read another profile after captured lookup fails")
    require("return getSpoofedUserDefaultsUUID().length > 0;" in read("TLinkIOSTweak/UserDefaultsHooks.x") and
            "if (!spoofedUUID.length) return object;" in read("TLinkIOSTweak/UserDefaultsHooks.x"),
            "missing UUID must preserve the caller's dictionary/written values")
    require("operationView, &carrierResultKey" in read("TLinkIOSTweak/NetworkConnectionTypeHooks.x") and
            "view, &deviceSpecKey" in read("TLinkIOSTweak/DeviceSpecHooks.x") and
            "view, &kPXRuntimeIOSInfo" in read("TLinkIOSTweak/IOSVersionHooks.x"),
            "derived caches must use view identity rather than only profile generation/timestamps")
    require('PXRuntimeReadBool(PXCaptureRuntimeSnapshot().securitySettings[@"networkDataSpoofEnabled"])' in
            read("TLinkIOSTweak/NetworkConnectionTypeHooks.x"),
            "network gate must not reread a shared boolean from another concurrent operation")
    require("PXRuntimeShouldStageWebCapabilities" in read("TLinkIOSTweak/DeviceSpecHooks.x"),
            "web staging must reject stale controller generations and deduplicate unchanged values")
    fixture = read("tests/PXRuntimeReadScopeTests.m")
    for token in ("exception restores outer", "early returned field survives", "nested scope cannot resurrect",
                  "derived object is ready before view", "thread-local frames never leak"):
        require(token in fixture, f"native scope fixture missing: {token}")
    require("-fexceptions -fobjc-exceptions" in read("Makefile") and "common/PXRuntimeReadScope.m" in read("Makefile"),
            "production targets must compile exception cleanup and link the scope engine")
    print("PASS: Captured runtime consumer contracts (native runtime not implied)")


def native_tests():
    require(sys.platform == "darwin" and shutil.which("xcrun"), "--native requires macOS/xcrun; no silent skip")
    with tempfile.TemporaryDirectory(prefix="px-runtime-read-scope-") as folder:
        binary = Path(folder) / "read-scope-tests"
        subprocess.run([
            "xcrun", "clang", "-fobjc-arc", "-fblocks", "-fexceptions", "-fobjc-exceptions",
            "-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1", "-Wall", "-Wextra", "-Werror=implicit-function-declaration",
            "-I", str(ROOT / "common"), str(ROOT / "common/PXRuntimeSnapshotReader.m"),
            str(ROOT / "common/PXRuntimeReadScope.m"), str(ROOT / "tests/PXRuntimeReadScopeTests.m"),
            "-framework", "Foundation", "-framework", "CoreFoundation", "-o", str(binary),
        ], check=True, cwd=ROOT, timeout=60)
        for _ in range(3):
            subprocess.run([str(binary)], check=True, cwd=ROOT, timeout=45)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--native", action="store_true")
    options = parser.parse_args()
    source_contracts()
    if options.native:
        native_tests()
