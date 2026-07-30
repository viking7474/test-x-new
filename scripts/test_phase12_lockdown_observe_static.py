#!/usr/bin/env python3
"""Host-independent contracts for the L0 Lockdown observe-only layer (plan §4.6)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require(path, needles):
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [needle for needle in needles if needle not in text]
    if missing:
        raise AssertionError(f"{path}: missing contracts: {missing}")


makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
if "research/PXLockdownObservability.m" not in makefile:
    raise AssertionError("L0 observability provider missing from the research allowlist")
if "$(wildcard research/*.m)" in makefile:
    raise AssertionError("Research source must use an explicit allowlist, not a wildcard")

provider = (ROOT / "research/PXLockdownObservability.m").read_text(encoding="utf-8")
require("research/PXLockdownObservability.m", [
    '#error "PXLockdownObservability must never be compiled outside an Internal Research build"',
    # consolidated inventory is derived from the three real providers
    "PXLockdownSoftwareModelEntries",
    "PXLockdownDeviceIdentityEntries",
    "PXLockdownSoCCellularEntries",
    "PXLockdownObservedKeyInventory",
    "PXLockdownObservedKeyForLockdownKey",
    "PXLockdownObservabilityInventoryIsWellFormed",
    # redacted observation record + provider/expected-type annotation
    "PXLockdownObservationRecord",
    '@"<redacted>"',
    '@"expectedType"',
    '@"sourceProvider"',
    '@"mode"',
    # forbidden pairing/certificate/private-key/escrow domains
    "PXLockdownObservationDomainIsForbidden",
    '@"pairrecord"',
    '@"certificate"',
    '@"privatekey"',
    '@"escrow"',
    # frequency / timeout / cache metrics
    "PXLockdownAccessMetrics",
    "recordAccessForKey",
    "timeoutCountForKey",
    "cacheHitCountForKey",
    "cacheMissCountForKey",
])

# Observe-only never resolves or mutates a Lockdown value: the active resolver
# entry points stay owned by the L1/L2/L3 providers.
for forbidden in ("PXLockdownSoftwareModelResolve", "PXLockdownDeviceIdentityResolve",
                  "PXLockdownSoCCellularResolve", "PXLockdownOriginalOrReplacement"):
    if forbidden in provider:
        raise AssertionError(f"L0 observe-only layer must not resolve/mutate values ({forbidden})")

# Research providers must never emit raw runtime values.
for sink in ("NSLog(", "PXLog(", "PXDBLog("):
    if sink in provider:
        raise AssertionError(f"L0 observability provider must not log runtime values ({sink})")

require("tests/PXLockdownObservabilityTests.m", [
    "inventory must represent every provider key exactly once",
    "UDID must be sensitive",
    "IMEI must be sensitive",
    "UniqueChipID must project as NSNumber",
    "sensitive payload must be redacted",
    "pair record domain must be forbidden",
    "escrow domain must be forbidden",
    "forbidden domain must produce no record",
    "unknown key must not produce a record",
    "frequency must accumulate",
    "timeouts must accumulate",
    "cache hits must accumulate",
    "cache misses must accumulate",
])

# Wired into the release regression and the forbidden-package scan.
hardening = (ROOT / "scripts/release_hardening.py").read_text(encoding="utf-8")
if "scripts/test_phase12_lockdown_observe_static.py" not in hardening:
    raise AssertionError("L0 static test is not wired into the release regression")
if 'b"PXLockdownObservability"' not in hardening:
    raise AssertionError("PXLockdownObservability is not in the forbidden package token list")

print("Phase-12 Lockdown observe-only (L0) contracts: PASS")
