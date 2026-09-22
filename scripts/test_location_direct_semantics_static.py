#!/usr/bin/env python3
"""Host-independent P0-03 Location direct-surface and callback contracts."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TWEAK = (ROOT / "TLinkIOSTweak" / "Tweak.x").read_text(encoding="utf-8")
HEADER = (ROOT / "common" / "LocationSpoofingManager.h").read_text(encoding="utf-8")
MANAGER = (ROOT / "common" / "LocationSpoofingManager.m").read_text(encoding="utf-8")


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

modern = re.search(
    r"didUpdateLocations:\(NSArray<CLLocation \*> \*\)locations \{(.*?)\n\}",
    TWEAK,
    re.S,
)
require(modern is not None, "modern location callback missing")
modern_body = modern.group(1)
require(modern_body.count("PXActiveLocationSnapshot(YES)") == 1,
        "modern callback must advance exactly one generation per batch")
require("for (CLLocation *location in locations)" in modern_body,
        "modern callback does not bind every original location to the batch snapshot")
require("%orig;" in modern_body and "%orig(manager," not in modern_body,
        "modern callback replaced arguments or changed forwarding semantics")
require("NSMutableArray" not in modern_body and "dispatch_" not in modern_body,
        "modern callback changed collection shape or callback queue")

legacy = re.search(
    r"didUpdateToLocation:\(CLLocation \*\)newLocation fromLocation:\(CLLocation \*\)oldLocation \{(.*?)\n\}",
    TWEAK,
    re.S,
)
require(legacy is not None, "legacy location callback missing")
legacy_body = legacy.group(1)
require(legacy_body.count("PXActiveLocationSnapshot(YES)") == 1,
        "legacy callback must advance exactly one generation")
require("PXAttachLocationSpoofSnapshot(newLocation, snapshot);" in legacy_body and
        "PXAttachLocationSpoofSnapshot(oldLocation, snapshot);" in legacy_body,
        "legacy new/old locations do not share one snapshot")
require("%orig;" in legacy_body and "%orig(manager," not in legacy_body,
        "legacy callback replaced original arguments")

for selector in ("didEnterRegion", "didExitRegion"):
    match = re.search(rf"{selector}:\(CLRegion \*\)region \{{(.*?)\n\}}", TWEAK, re.S)
    require(match is not None and "%orig;" in match.group(1),
            f"{selector} is still suppressed")

heading = re.search(
    r"didUpdateHeading:\(CLHeading \*\)newHeading \{(.*?)\n\}",
    TWEAK,
    re.S,
)
require(heading is not None, "heading callback missing")
require("PXAttachLocationSpoofSnapshot(newHeading, snapshot);" in heading.group(1),
        "heading callback is not bound to the shared snapshot")
require("%orig;" in heading.group(1) and "dispatch_" not in heading.group(1),
        "heading callback changed forwarding queue/arguments")

require("PXLocationSpoofSnapshot *currentSnapshot = PXActiveLocationSnapshot(NO);" in TWEAK,
        "object-attached snapshots are not gated by the current scope/toggle")
require(re.search(r"%hook MKUserLocation.*?PXActiveLocationSnapshot\(NO\).*?snapshot\.coordinate", TWEAK, re.S) is not None,
        "map user-location surface diverges from the shared snapshot")
require("initWithClientHeading:" not in TWEAK,
        "private CLHeading initializer must not be synthesized")

print("P0-03 Location direct surface + semantics static checks passed")
