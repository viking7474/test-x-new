#!/usr/bin/env python3
"""Location source wiring gate; --native compiles/runs the production delegate adapter."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TWEAK = (ROOT / "TLinkIOSTweak" / "Tweak.x").read_text(encoding="utf-8")
HEADER = (ROOT / "common" / "LocationSpoofingManager.h").read_text(encoding="utf-8")
MANAGER = (ROOT / "common" / "LocationSpoofingManager.m").read_text(encoding="utf-8")
ADAPTER = (ROOT / "TLinkIOSTweak" / "PXLocationDelegateHooks.m").read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


for token in (
    "- (id)delegate",
    "- (CLLocation *)location",
    "- (CLHeading *)heading",
    "%hook CLLocationSourceInformation",
    "- (BOOL)isSimulatedBySoftware",
    "- (BOOL)isProducedByAccessory",
    "%hook CLHeading",
    "- (CLLocationDirection)magneticHeading",
    "- (CLLocationDirection)headingAccuracy",
    "- (CLLocationDirection)trueHeading",
    "%hook CLRegion",
    "- (CLLocationCoordinate2D)center",
    "- (BOOL)containsCoordinate:(CLLocationCoordinate2D)coordinate",
):
    require(token in TWEAK, f"missing P0-03 direct surface: {token}")

for token in (
    "PXLocationSpoofSnapshot",
    "currentSpoofSnapshot",
    "advanceSpoofSnapshotForUpdate",
    "PXAttachLocationSpoofSnapshot",
    "PXLocationSpoofSnapshotForObject",
    "PXLocationProjectionBypassActive",
    "PXLocationOriginalCoordinate",
    "PXLocationOriginalSpeed",
    "PXLocationOriginalCourse",
):
    require(token in HEADER and token in MANAGER, f"snapshot contract missing: {token}")

require("snapshot.generation = ++self.locationSpoofGeneration" in MANAGER,
        "snapshot generation is not monotonic")
require("if (!advance && sourceMatches) return cached;" in MANAGER,
        "direct getters do not reuse the current snapshot")
require("self.locationSpoofSnapshot = nil;" in MANAGER,
        "location state changes do not invalidate the snapshot")
require("_lastReportedSpeed = PXLocationOriginalSpeed(currentLoc);" in MANAGER and
        "_lastReportedCourse = PXLocationOriginalCourse(currentLoc);" in MANAGER,
        "path simulation reads projected speed/course back into canonical state")

require("%hook NSObject" not in TWEAK,
        "location optional callbacks must never be hooked/fabricated on NSObject")
setter = TWEAK.split("- (void)setDelegate:(id)delegate {", 1)[1].split("- (id)delegate", 1)[0]
installation = "PXInstallLocationDelegateHooks(delegate, PXLocationDelegateSnapshot, PXLocationDelegateAttachSnapshot);"
require(setter.count(installation) == 1 and setter.count("%orig;") == 1 and
        setter.index(installation) < setter.index("%orig;"),
        "observe concrete delegate before native assignment; original setter exactly once")
require("return PXActiveLocationSnapshot(advanceGeneration);" in TWEAK and
        "PXAttachLocationSpoofSnapshot(object, snapshot);" in TWEAK,
        "delegate adapter must use the existing live scoped snapshot/attachment pipeline")
for selector in (
    "locationManager:didUpdateLocations:", "locationManager:didUpdateToLocation:fromLocation:",
    "locationManager:didUpdateHeading:", "locationManager:didEnterRegion:", "locationManager:didExitRegion:",
):
    require(f'@"{selector}"' in ADAPTER, f"missing delegate adapter selector: {selector}")
require("method_getReturnType" in ADAPTER and "method_getNumberOfArguments" in ADAPTER and
        "method_getArgumentType" in ADAPTER and "PXLocationObjectType" in ADAPTER,
        "all return/argument ABI must be validated before installation")
require("class_addMethod(cls, selector, replacement" in ADAPTER and
        "cls == NSObject.class" in ADAPTER and "cls == NSProxy.class" in ADAPTER,
        "inherited methods must be isolated on concrete classes; never mutate root classes")
require("@property (atomic, assign) IMP original;" in ADAPTER and
        ADAPTER.index("hook.original = method_getImplementation(method)") < ADAPTER.index("imp_implementationWithBlock"),
        "original IMP must be safely published before the replacement is callable")
require("gPXLocationCallbackFrame = frame.previous;" in ADAPTER and "@finally" in ADAPTER and
        "class_getSuperclass(frame->owner)" in ADAPTER,
        "super-chain guard must unwind and preserve independent nested callbacks")
require("for (id location in locations) hook.attacher(location, snapshot);" in ADAPTER and
        "hook.attacher(first, snapshot);" in ADAPTER and "hook.attacher(second, snapshot);" in ADAPTER,
        "batch/legacy projection must attach shared snapshots to original objects")
require("hook.provider(NO)" in ADAPTER and "hook.kind == PXLocationCallbackHeading" in ADAPTER,
        "heading/region callbacks must read current generation without advancing")
require("delegate] != receiver" in ADAPTER,
        "replaced/nil delegate callbacks must not advance current projection")
require(not any(token in ADAPTER for token in ("dispatch_async", "dispatch_after", "NSMutableArray", "objc_setAssociatedObject")),
        "adapter must not redispatch/copy arrays or retain manager/delegate in associations")
require("OBJC_ASSOCIATION_RETAIN_NONATOMIC" not in MANAGER,
        "concurrent snapshot association readers must retain the value during replacement")

require("PXLocationSpoofSnapshot *currentSnapshot = PXActiveLocationSnapshot(NO);" in TWEAK,
        "object-attached snapshots are not gated by the current scope/toggle")
require(re.search(r"%hook MKUserLocation.*?PXActiveLocationSnapshot\(NO\).*?snapshot\.coordinate", TWEAK, re.S) is not None,
        "map user-location surface diverges from the shared snapshot")
require("initWithClientHeading:" not in TWEAK,
        "private CLHeading initializer must not be synthesized")

print("PASS: Location direct surfaces and delegate source contracts (native runtime not implied)")


def native_tests() -> None:
    require(sys.platform == "darwin" and shutil.which("xcrun") is not None,
            "--native requires macOS Foundation/xcrun and must not silently skip")
    with tempfile.TemporaryDirectory(prefix="px-location-delegate-") as folder:
        binary = Path(folder) / "location-delegate-tests"
        subprocess.run([
            "xcrun", "clang", "-fobjc-arc", "-fblocks", "-Wall", "-Wextra",
            "-Werror=implicit-function-declaration", "-I", str(ROOT / "TLinkIOSTweak"),
            str(ROOT / "TLinkIOSTweak/PXLocationDelegateHooks.m"),
            str(ROOT / "tests/PXLocationDelegateTests.m"),
            "-framework", "Foundation", "-framework", "CoreLocation", "-o", str(binary),
        ], cwd=ROOT, check=True, timeout=60)
        # New process each iteration, so concurrent first-install paths are
        # exercised again, rather than only reusing a warmed hook registry.
        for _ in range(3):
            subprocess.run([str(binary)], cwd=ROOT, check=True, timeout=45)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--native", action="store_true")
    if parser.parse_args().native:
        native_tests()
