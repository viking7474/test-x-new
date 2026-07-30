#!/usr/bin/env python3
"""Host-independent Phase-5 Lockdown software/model contracts."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require(path, needles):
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [needle for needle in needles if needle not in text]
    if missing:
        raise AssertionError(f"{path}: missing contracts: {missing}")


makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
if "research/PXLockdownSoftwareModelProvider.m" not in makefile:
    raise AssertionError("Phase-5 provider missing from the research allowlist")
if "$(wildcard research/*.m)" in makefile:
    raise AssertionError("Research source must use an explicit allowlist, not a wildcard")

require("research/PXLockdownSoftwareModelProvider.m", [
    '#error "PXLockdownSoftwareModelProvider must never be compiled outside an Internal Research build"',
    "kLockdownProductVersionKey",
    "kLockdownBuildVersionKey",
    "kLockdownProductTypeKey",
    "kLockdownDeviceNameKey",
    "PXGroupProjectsValue",
    "PXConsistencyResolveEntryValue",
    "PXLockdownOriginalOrReplacement",
    "[NSString class]",
])
# Device identity / SoC / cellular keys must NOT be handled by the Phase-5 provider.
provider = (ROOT / "research/PXLockdownSoftwareModelProvider.m").read_text(encoding="utf-8")
for forbidden in ("kLockdownUniqueDeviceIDKey", "kLockdownSerialNumberKey",
                  "kLockdownUniqueChipIDKey", "kLockdownIMEIKey", "kLockdownBasebandVersionKey"):
    if forbidden in provider:
        raise AssertionError(f"Phase-5 provider must not handle out-of-scope key {forbidden}")

require("tests/PXLockdownSoftwareModelTests.m", [
    "ProductVersion must stay String",
    "out-of-scope key must return original",
    "software group off must return original",
    "observe-only must return original",
    "missing snapshot value must return original",
    "inconsistent/partial group must return original",
])

print("Phase-5 Lockdown software/model contracts: PASS")
