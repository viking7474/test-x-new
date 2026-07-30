#!/usr/bin/env python3
"""Host-independent Phase-4 Lockdown safety contracts."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require(path, needles):
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [needle for needle in needles if needle not in text]
    if missing:
        raise AssertionError(f"{path}: missing contracts: {missing}")


makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
require("Makefile", [
    "INTERNAL_SECURITY_RESEARCH ?= 0",
    "research/PXLockdownResearchSafety.m",
    "-DINTERNAL_SECURITY_RESEARCH=1",
    "FINALPACKAGE",
])
if "$(wildcard research/*.m)" in makefile:
    raise AssertionError("Research source must use an explicit allowlist, not a wildcard")

require("research/PXLockdownResearchSafety.m", [
    '#error "PXLockdownResearchSafety must never be compiled outside an Internal Research build"',
    '@"lockdownResearchEnabled"',
    '@"lockdownResearchBundleAllowlist"',
    '@"lockdownResearchProcessAllowlist"',
    "PXLockdownMaximumTTL",
    "PXLockdownResearchModeObserveOnly",
    "PXLockdownSafetyReasonSessionExpired",
    "PXLockdownSafetyReasonNotAllowlisted",
    "disableAllAndClearSnapshot",
    'PXLockdownOriginalOrReplacement',
    '@"<redacted>"',
])
require("tests/PXLockdownResearchSafetyTests.m", [
    "master must default OFF",
    "outside allowlist must fail closed",
    "TTL did not expire closed",
    "audit leaked identifier",
    "kill switch did not fail closed",
    "kill switch must remain sticky for process lifetime",
    "sensitive daemon must stay denied even when bundle is allowlisted",
    "observe-only changed original",
])

# Release expansion must not contain the research source or research macro.
if "ProjectXTweak_FILES = $(wildcard ProjectXTweak/*.x) $(wildcard ProjectXTweak/*.m) $(wildcard common/*.m) research/" in makefile:
    raise AssertionError("Research module is unconditionally present in tweak sources")

print("Phase-4 Lockdown safety contracts: PASS")
