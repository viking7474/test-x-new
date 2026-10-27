#!/usr/bin/env python3
"""Captured runtime reader wiring; --native runs the actual Objective-C reader."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def bootstrap_fragment() -> str:
    source = (ROOT / "common/PXRuntimeSnapshot.m").read_text(encoding="utf-8")
    start = source.index("static NSDictionary *PXRuntimeCapturedSource(void);")
    end = source.index("static NSDictionary *PXRuntimeDictionaryAtPath(", start)
    return source[start:end]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def source_contracts() -> None:
    header = (ROOT / "common/PXRuntimeSnapshotReader.h").read_text(encoding="utf-8")
    reader = (ROOT / "common/PXRuntimeSnapshotReader.m").read_text(encoding="utf-8")
    runtime = (ROOT / "common/PXRuntimeSnapshot.m").read_text(encoding="utf-8")
    boot = (ROOT / "TLinkIOSTweak/BootTimeHooks.x").read_text(encoding="utf-8")
    fixture = (ROOT / "tests/PXRuntimeSnapshotReaderTests.m").read_text(encoding="utf-8")
    for token in ("publisherEpoch", "uint64_t revision", "schemaVersion", "readerGeneration", "hasPublicationIdentity"):
        require(token in header, f"missing snapshot identity distinction: {token}")
    require("NSPropertyListImmutable" in reader and "NSPropertyListBinaryFormat_v1_0" in reader,
            "reader must detach/freeze the complete property-list graph")
    capture = reader.split("- (PXRuntimeReadSnapshot *)capture {", 1)[1].split("- (void)requestRefreshInvalidating:", 1)[0]
    require("_loader()" not in capture and "waitForPendingRefresh" not in capture and
            "dispatch_sync" not in capture and "contentsOfFile" not in capture,
            "capture must never parse or wait for disk")
    require("DISPATCH_QUEUE_SERIAL" in reader and "generation == _requestedGeneration" in reader and
            "_dirty || generation != _requestedGeneration" in reader,
            "serialized refresh must coalesce and discard invalidated in-flight results")
    require("if (invalidate) _snapshot = nil;" in reader and "initWithPropertyList:nil" in reader,
            "notification/failure must not serve last-good enabled fields to new captures")
    require("candidate.revision < _lastRevision" in reader and "isEqualToString:_lastEpoch" in reader,
            "revisions can be ordered only within the same publisher epoch")
    require("CLOCK_MONOTONIC" in reader and "!_queued && (!snapshot || now >= _nextRefresh)" in reader and
            "dispatch_source_create" not in reader and "NSTimer" not in reader,
            "fallback is monotonic/on-demand and must not restart an already running load")
    require("dispatch_get_specific" in reader and "return NO;" in reader,
            "bootstrap wait must reject calls from the loader queue")
    require("primeSynchronouslyIfIdle" in header and "PXRuntimeReaderIsDraining" in reader and
            "setBootstrapPreparationHandler:handler" in runtime and
            "waitForPendingRefresh:" not in runtime,
            "constructor bootstrap must not depend on worker progress or mark a timed-out load primed")
    require("objc_precise_lifetime" in reader and "errno = savedErrno;" in capture,
            "old snapshot destruction must occur outside publication lock; capture preserves errno")
    require("PXRuntimeCapturedSource" in runtime and "PXRuntimeReaderNotification" in runtime and
            "invalidateAndRefresh" in runtime and "refreshInterval:5.0" in runtime,
            "process reader must use real storage, canonical notifications and bounded fallback")
    require('PXRuntimeSnapshotProfileArtifact(@"bootTime")' not in boot and
            'PXRuntimeSnapshotProfileArtifact(@"systemUptime")' not in boot and
            '[snapshot profileArtifact:@"bootTime"]' in boot and
            '[snapshot profileArtifact:@"systemUptime"]' in boot,
            "RootHide boot/uptime must read the same captured view")
    require("PXCapturedBootValues(snapshot," in boot and "PXPrepareRuntimeSnapshotReader();" in boot,
            "BootTime must use captured getters and prime only during permitted bootstrap")
    require(boot.index("if (!allowed)") < boot.index("PXPrepareRuntimeSnapshotReader();"),
            "unscoped constructors must not start the reader")
    for token in ("deep immutable copy", "burst coalesced", "concurrent captures never combine",
                  "missing source does not retain", "epoch switch accepts lower revision",
                  "bootstrap requires no worker", "later refresh stays asynchronous",
                  "completed bootstrap is not success"):
        require(token in fixture, f"native reader contract missing: {token}")
    require("common/PXRuntimeSnapshotReader.m" in (ROOT / "Makefile").read_text(encoding="utf-8"),
            "explicit daemon target must link the new reader")
    fragment = bootstrap_fragment()
    require("PXPrimeRuntimeSnapshotReader" in fragment and "PXPrepareRuntimeSnapshotReader" in fragment and
            "primeSynchronouslyIfIdle" in fragment and "waitForPendingRefresh:" not in fragment,
            "cold integration fixture must extract the production bootstrap wrappers")
    cold = (ROOT / "tests/PXRootHideBootstrapTests.m").read_text(encoding="utf-8")
    require('__attribute__((constructor))' in cold and '../TLinkIOSTweak/PXScope.m' in cold and
            "disabled target remains denied" in cold and "disabled master remains denied" in cold,
            "RootHide constructor integration must cover actual scope and revocation")
    print("PASS: Runtime captured-reader source contracts (native runtime not implied)")


def native_tests() -> None:
    require(sys.platform == "darwin" and shutil.which("xcrun") is not None,
            "--native requires macOS Foundation/xcrun; it must not silently skip")
    with tempfile.TemporaryDirectory(prefix="px-runtime-reader-") as folder:
        binary = Path(folder) / "runtime-reader-tests"
        subprocess.run([
            "xcrun", "clang", "-fobjc-arc", "-fblocks", "-Wall", "-Wextra",
            "-Werror=implicit-function-declaration", "-I", str(ROOT / "common"),
            str(ROOT / "common/PXRuntimeSnapshotReader.m"),
            str(ROOT / "tests/PXRuntimeSnapshotReaderTests.m"),
            "-framework", "Foundation", "-framework", "CoreFoundation", "-o", str(binary),
        ], check=True, cwd=ROOT, timeout=60)
        for _ in range(3):
            subprocess.run([str(binary)], check=True, cwd=ROOT, timeout=45)
        (Path(folder) / "PXRuntimeBootstrap.inc").write_text(bootstrap_fragment(), encoding="utf-8")
        cold_binary = Path(folder) / "roothide-cold-bootstrap"
        subprocess.run([
            "xcrun", "clang", "-fobjc-arc", "-fblocks", "-fexceptions", "-fobjc-exceptions",
            "-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1", "-Wall", "-Wextra", "-Werror=implicit-function-declaration",
            "-I", str(ROOT / "common"), "-I", folder,
            str(ROOT / "common/PXRuntimeSnapshotReader.m"), str(ROOT / "common/PXRuntimeReadScope.m"),
            str(ROOT / "tests/PXRootHideBootstrapTests.m"),
            "-framework", "Foundation", "-framework", "CoreFoundation", "-o", str(cold_binary),
        ], check=True, cwd=ROOT, timeout=60)
        for _ in range(3):
            subprocess.run([str(cold_binary)], check=True, cwd=ROOT, timeout=45)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--native", action="store_true")
    options = parser.parse_args()
    source_contracts()
    if options.native:
        native_tests()
