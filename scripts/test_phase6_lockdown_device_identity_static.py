#!/usr/bin/env python3
"""Host-independent Phase-6 Lockdown device-identity contracts."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require(path, needles):
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [needle for needle in needles if needle not in text]
    if missing:
        raise AssertionError(f"{path}: missing contracts: {missing}")


makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
if "research/PXLockdownDeviceIdentityProvider.m" not in makefile:
    raise AssertionError("Phase-6 provider missing from the research allowlist")
if "$(wildcard research/*.m)" in makefile:
    raise AssertionError("Research source must use an explicit allowlist, not a wildcard")

provider = (ROOT / "research/PXLockdownDeviceIdentityProvider.m").read_text(encoding="utf-8")
require("research/PXLockdownDeviceIdentityProvider.m", [
    '#error "PXLockdownDeviceIdentityProvider must never be compiled outside an Internal Research build"',
    "kLockdownUniqueDeviceIDKey",
    "kLockdownSerialNumberKey",
    "kLockdownMLBSerialNumberKey",
    "PXSurfacesAgree",
    "PXIdentitySurfaceResolveValue",
    "PXLockdownOriginalOrReplacement",
    "PXLockdownDeviceIdentityValueIsWellFormed",
    "PXLockdownDeviceIdentityStableAcrossGeneration",
    "[NSString class]",
])

# The identity trio must be one atomic switch, never per-key toggles.
if "lockdownDeviceIdentifiersEnabled" not in provider:
    raise AssertionError("device identity group must use one atomic settings flag")
for per_key in ("lockdownUDIDEnabled", "lockdownSerialEnabled", "lockdownMLBEnabled"):
    if per_key in provider:
        raise AssertionError(f"device identity keys must not toggle individually ({per_key})")

# Software/model and SoC/cellular keys must NOT be handled by the Phase-6 provider.
for forbidden in ("kLockdownProductTypeKey", "kLockdownDeviceNameKey", "kLockdownProductVersionKey",
                  "kLockdownBuildVersionKey", "kLockdownUniqueChipIDKey", "kLockdownIMEIKey",
                  "kLockdownBasebandVersionKey"):
    if forbidden in provider:
        raise AssertionError(f"Phase-6 provider must not handle out-of-scope key {forbidden}")

require("tests/PXLockdownDeviceIdentityTests.m", [
    "UDID must stay String",
    "SerialNumber must stay String",
    "out-of-scope key must return original",
    "identity group off must return original",
    "observe-only must return original",
    "malformed serial must return original",
    "missing snapshot value must return original",
    "identity changed within a generation must fail stability",
    "identity change across generations is allowed",
    "diverges from IOPlatformSerialNumber",
])

print("Phase-6 Lockdown device-identity contracts: PASS")
