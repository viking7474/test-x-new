#!/usr/bin/env python3
"""Host-independent Phase-7 Lockdown SoC/cellular contracts."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require(path, needles):
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [needle for needle in needles if needle not in text]
    if missing:
        raise AssertionError(f"{path}: missing contracts: {missing}")


makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
if "research/PXLockdownSoCCellularProvider.m" not in makefile:
    raise AssertionError("Phase-7 provider missing from the research allowlist")
if "$(wildcard research/*.m)" in makefile:
    raise AssertionError("Research source must use an explicit allowlist, not a wildcard")

provider = (ROOT / "research/PXLockdownSoCCellularProvider.m").read_text(encoding="utf-8")
require("research/PXLockdownSoCCellularProvider.m", [
    '#error "PXLockdownSoCCellularProvider must never be compiled outside an Internal Research build"',
    "kLockdownUniqueChipIDKey",
    "kLockdownIMEIKey",
    "kLockdownSecondaryIMEIKey",
    "kLockdownMobileEquipmentIdentifierKey",
    "kLockdownBasebandVersionKey",
    "lockdownSoCIdentityEnabled",
    "lockdownCellularBasebandEnabled",
    "PXLockdownSoCCellularSchemaValidate",
    "PXLockdownSoCMatchesProductType",
    "PXLockdownBasebandFamilyMatchesProductType",
    "PXProductTypeIsCellularCapable",
    "PXLuhnValid",
    "PXSurfacesAgree",
    "PXIdentitySurfaceResolveValue",
    "PXLockdownOriginalOrReplacement",
    "expectedClass = original ? [original class]",
])

# Atomic option groups only: no individual sensitive-identifier toggles.
for per_key in ("lockdownChipIDEnabled", "lockdownIMEIEnabled", "lockdownIMEI2Enabled",
                "lockdownMEIDEnabled", "lockdownBasebandVersionEnabled"):
    if per_key in provider:
        raise AssertionError(f"Phase-7 keys must not toggle individually ({per_key})")

# Phase-5/6 ownership must remain separate.
for forbidden in ("kLockdownUniqueDeviceIDKey", "kLockdownSerialNumberKey",
                  "kLockdownMLBSerialNumberKey", "kLockdownProductTypeKey",
                  "kLockdownDeviceNameKey", "kLockdownProductVersionKey",
                  "kLockdownBuildVersionKey"):
    if forbidden in provider:
        raise AssertionError(f"Phase-7 provider must not handle out-of-scope key {forbidden}")

require("tests/PXLockdownSoCCellularTests.m", [
    "UniqueChipID must preserve original CFType",
    "IMEI must stay String",
    "out-of-scope key must return original",
    "SoC group off must return original",
    "cellular group off must return original",
    "observe-only must return original",
    "UniqueChipID type mismatch must return original",
    "malformed IMEI must fail schema validation",
    "dual-SIM schema missing IMEI2 must fail",
    "single-SIM schema exposing IMEI2 must fail",
    "Wi-Fi-only model must return original for IMEI",
    "Wi-Fi-only schema exposing cellular data must fail",
    "ChipID/SoC mismatch must fail schema validation",
    "baseband family mismatch must fail schema validation",
    "projected IMEI diverges from telephony surface",
])

print("Phase-7 Lockdown SoC/cellular contracts: PASS")
